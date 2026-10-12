--!strict
-- The soldier game's HUD extras the user chose for brief 30 (bible §2.5 "Boosts/products", §2.7): the spin wheel, the
-- Playtime Rewards, the Missions and the Starter Pack. Pure rules, so the server (HoodServer/HudExtras and
-- HudExtrasService), the client (HoodClient/Extras.client) and the unit tests all agree.
-- Honest by design (kids' game): every timer is real (a free spin really comes back after FreeEvery; a playtime gift
-- really opens after its minutes of play); every chance the wheel shows is the chance it rolls with; every number a card
-- shows is the number that is granted. Nothing is "limited".
--   Rewards are tables { Cash, Power, Boost (level), Seconds, Spins, Box (a box id) }; a missing part is absent. Cash
--   scales with your best stage (like the Cash Packs), Power is a share of your next rebirth's need (worth the same at
--   every point of the game).
local Balance = require(script.Parent.Config.Balance)

local R = {}

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end
local function whole(v: any, lo: number, hi: number): number
	return math.clamp(math.floor(number(v, lo)), lo, hi)
end
-- Round to two significant figures, at least `floor`.
local function nice(n: number, floor: number): number
	n = math.max(floor, n)
	local p = 10 ^ math.max(0, math.floor(math.log10(n)) - 1)
	return math.floor(n / p + 0.5) * p
end
R.nice = nice
-- How much a stage's Cash is worth next to stage 1's (the Cash Packs' scale): (pad Cash / stage 1's) ^ 0.6.
function R.stageScale(stage: any): number
	local pads = Balance.PadCash
	local n = math.clamp(math.floor(number(stage, 1)), 1, #pads)
	return (pads[n] / pads[1]) ^ 0.6
end

-- A reward spec ({ Cash, PowerShare, Boost, Seconds, Spins, Box }) made real for this player: need = the Power the next
-- rebirth needs, stage = the best stage.
function R.make(spec: any, need: any, stage: any): { [string]: any }
	local out: { [string]: any } = {}
	if type(spec) ~= 'table' then return out end
	if spec.Cash then out.Cash = nice(spec.Cash * R.stageScale(stage), spec.Cash) end
	if spec.PowerShare then out.Power = nice(math.max(100, number(need, 1000)) * spec.PowerShare, 100) end
	if spec.Boost then
		out.Boost = spec.Boost
		out.Seconds = spec.Seconds or 600
	end
	if spec.Spins then out.Spins = spec.Spins end
	if spec.Box then out.Box = spec.Box end
	return out
end
-- The reward's short lines: { '+300 Cash', '2x Power 10 min', '+1 Spin', 'Street Box' }. fmt formats numbers;
-- boxName(id) names a box (optional).
function R.lines(reward: any, fmt: (number) -> string, boxName: ((string) -> string)?): { string }
	local lines = {}
	if type(reward) ~= 'table' then return lines end
	if reward.Cash then table.insert(lines, '+' .. fmt(reward.Cash) .. ' Cash') end
	if reward.Power then table.insert(lines, '+' .. fmt(reward.Power) .. ' Power') end
	if reward.Boost then table.insert(lines, reward.Boost .. 'x Power ' .. math.floor(number(reward.Seconds, 600) / 60) .. ' min') end
	if reward.Spins then table.insert(lines, '+' .. reward.Spins .. (reward.Spins == 1 and ' Spin' or ' Spins')) end
	if reward.Box then table.insert(lines, boxName and boxName(reward.Box) or (reward.Box .. ' Box')) end
	return lines
end
-- The icon a reward's card shows (an IconModels id).
function R.iconOf(reward: any): string
	if type(reward) ~= 'table' then return 'Rewards' end
	if reward.Box then return 'Box_' .. reward.Box end
	if reward.Spins then return 'SpinWheel' end
	if reward.Boost then return reward.Boost >= 3 and 'PotionGold' or 'PotionRed' end
	if reward.Power then return 'Power' end
	if reward.Cash then
		local c = number(reward.Cash, 0)
		return c >= 3000 and 'CashMedium' or c >= 900 and 'CashSmall' or 'CashTiny'
	end
	return 'Rewards'
end

---------------------------------------------------------------------------------------------- spin wheel
-- One free spin every FreeEvery seconds (wall clock: it comes back while you are away too), and any number of bought or
-- won extra spins (Extra, up to MaxExtra). A spin uses the free one first. The wheel's eight wedges, clockwise from the
-- top (the picture SpinWheel's wedge colours), each with its Weight out of 100: the wheel shows these as its odds.
R.Spin = {
	FreeEvery = 4 * 3600,
	MaxExtra = 999,
	SpinSeconds = 4.2, -- the wheel's turn on screen; the server shows the prize after it
	PackSpins = 3, -- the Robux product SpinPack gives this many
}
R.Wedges = {
	{ Id = 'Cash1', Weight = 24, Cash = 400, Color = '#FF2238' },
	{ Id = 'Power1', Weight = 20, PowerShare = 0.03, Color = '#FF8A10' },
	{ Id = 'Boost2', Weight = 14, Boost = 2, Seconds = 600, Color = '#FFD814' },
	{ Id = 'Cash2', Weight = 12, Cash = 1500, Color = '#30C42A' },
	{ Id = 'Power2', Weight = 10, PowerShare = 0.08, Color = '#12C0EC' },
	{ Id = 'Boost3', Weight = 8, Boost = 3, Seconds = 600, Color = '#2258EE' },
	{ Id = 'Box', Weight = 9, Box = 'Graffiti', Color = '#8A34EC' },
	{ Id = 'Jackpot', Weight = 3, Cash = 6000, Spins = 1, Color = '#EC2CC0' },
}
R.WedgeTotal = 0
for _, w in R.Wedges do R.WedgeTotal += w.Weight end

-- The wedge a roll r in [0, 1) lands on: its index.
function R.pick(r: any): number
	local x = math.clamp(number(r, 0), 0, 0.999999) * R.WedgeTotal
	local acc = 0
	for i, w in R.Wedges do
		acc += w.Weight
		if x < acc then return i end
	end
	return #R.Wedges
end
-- A wedge's chance as text ('24%', '3%').
function R.chanceText(i: number): string
	local w = R.Wedges[i]
	if not w then return '' end
	local p = math.floor(w.Weight / R.WedgeTotal * 1000 + 0.5) / 10
	return (p % 1 == 0 and string.format('%d', p) or string.format('%.1f', p)) .. '%'
end
-- The angle (degrees, clockwise from the top) of wedge i's centre on the wheel.
function R.wedgeAngle(i: number): number
	return (i - 1) * 360 / #R.Wedges
end

R.SpinTemplate = { NextFree = 0, Extra = 0, Spins = 0, PendingBox = '' }
function R.sanitizeSpin(t: any): { [string]: any }
	local out = { NextFree = 0, Extra = 0, Spins = 0, PendingBox = '' }
	if type(t) ~= 'table' then return out end
	out.NextFree = whole(t.NextFree, 0, 1e11)
	out.Extra = whole(t.Extra, 0, R.Spin.MaxExtra)
	out.Spins = whole(t.Spins, 0, 1e9)
	out.PendingBox = type(t.PendingBox) == 'string' and #t.PendingBox <= 40 and t.PendingBox or ''
	return out
end
-- { Free (a free spin is ready), Wait (seconds to the next free one, 0 when ready), Extra, Total (spins you can use now) }
function R.spinState(t: any, now: any): { [string]: any }
	local s = R.sanitizeSpin(t)
	local wait = math.max(0, s.NextFree - number(now, 0))
	local free = wait <= 0
	return { Free = free, Wait = wait, Extra = s.Extra, Total = (free and 1 or 0) + s.Extra }
end
-- Uses one spin: true and 'free' / 'extra', or false and 'none'. The free spin's clock restarts from now.
function R.takeSpin(t: any, now: any): (boolean, string)
	local st = R.spinState(t, now)
	if st.Free then
		t.NextFree = math.floor(number(now, 0)) + R.Spin.FreeEvery
		t.Spins = whole(t.Spins, 0, 1e9) + 1
		return true, 'free'
	end
	if st.Extra > 0 then
		t.Extra = st.Extra - 1
		t.Spins = whole(t.Spins, 0, 1e9) + 1
		return true, 'extra'
	end
	return false, 'none'
end
function R.addSpins(t: any, n: any)
	t.Extra = math.min(R.Spin.MaxExtra, whole(t.Extra, 0, R.Spin.MaxExtra) + whole(n, 0, R.Spin.MaxExtra))
end

---------------------------------------------------------------------------------------------- playtime rewards
-- Six gifts that open with your playtime this session (a session survives a short drop: away for less than SessionGap,
-- the clock and the gifts you took carry on; longer, a new session starts at 0). Claimed one by one.
R.Playtime = { SessionGap = 15 * 60, MaxSeconds = 4 * 3600 }
R.Gifts = {
	{ Minutes = 5, Cash = 300 },
	{ Minutes = 10, PowerShare = 0.03 },
	{ Minutes = 15, Boost = 2, Seconds = 600 },
	{ Minutes = 25, Cash = 1200 },
	{ Minutes = 40, Spins = 1 },
	{ Minutes = 60, Box = 'Graffiti', PowerShare = 0.06 },
}
R.PlaytimeTemplate = { Seconds = 0, Claimed = 0, LastSeen = 0 }
-- Claimed is a bit set: gift i taken = bit i - 1.
function R.sanitizePlaytime(t: any): { [string]: any }
	local out = { Seconds = 0, Claimed = 0, LastSeen = 0 }
	if type(t) ~= 'table' then return out end
	out.Seconds = whole(t.Seconds, 0, R.Playtime.MaxSeconds)
	out.Claimed = whole(t.Claimed, 0, 2 ^ #R.Gifts - 1)
	out.LastSeen = whole(t.LastSeen, 0, 1e11)
	return out
end
function R.giftTaken(t: any, i: number): boolean
	return bit32.btest(whole(type(t) == 'table' and t.Claimed or 0, 0, 2 ^ #R.Gifts - 1), 2 ^ (i - 1))
end
-- A visit starts: a new session unless the last one ended less than SessionGap ago.
function R.playtimeJoin(t: any, now: any)
	local last = whole(t.LastSeen, 0, 1e11)
	if last <= 0 or number(now, 0) - last >= R.Playtime.SessionGap then
		t.Seconds, t.Claimed = 0, 0
	end
	t.LastSeen = math.floor(number(now, 0))
end
-- Playing for dt more seconds.
function R.playtimeTick(t: any, dt: any, now: any)
	t.Seconds = math.min(R.Playtime.MaxSeconds, number(t.Seconds, 0) + math.clamp(number(dt, 0), 0, 60))
	t.LastSeen = math.floor(number(now, 0))
end
-- Per gift: { Minutes, Ready (open and not taken), Taken, Left (seconds of play still to go) }, and how many are ready.
function R.playtimeState(t: any): ({ { [string]: any } }, number)
	local s = R.sanitizePlaytime(t)
	local list, ready = {}, 0
	for i, g in R.Gifts do
		local taken = R.giftTaken(s, i)
		local left = math.max(0, g.Minutes * 60 - s.Seconds)
		local open = left <= 0 and not taken
		if open then ready += 1 end
		list[i] = { Minutes = g.Minutes, Ready = open, Taken = taken, Left = left }
	end
	return list, ready
end
-- Takes gift i: true, or false and why ('unknown', 'taken', 'early').
function R.takeGift(t: any, i: any): (boolean, string?)
	local n = math.floor(number(i, 0))
	local g = R.Gifts[n]
	if not g then return false, 'unknown' end
	if R.giftTaken(t, n) then return false, 'taken' end
	if number(t.Seconds, 0) < g.Minutes * 60 then return false, 'early' end
	t.Claimed = whole(t.Claimed, 0, 2 ^ #R.Gifts - 1) + 2 ^ (n - 1)
	return true, nil
end

---------------------------------------------------------------------------------------------- missions
-- Three small tasks at a time. Each counts something the server sees for itself (never a number the client sends):
--   Goons     goons defeated in the stages (WaveService's WaveLeft falling in the same stage)
--   Shots     shots fired by your gun at an open range (LobbyService's auto-fire: AutoRate shots a second in an open lane)
--   Boxes     shoe boxes opened (the profile's Shoes.Opened)
--   Clears    stage crews beaten (WaveLeft reaching 0 in a stage)
--   CashOuts  cash pads stepped on (StageService's CashOuts)
--   Spins     spins of the wheel
-- A finished task waits for its Claim; claiming pays it and a new task takes its place (never one of the two still
-- open). Goals grow a little with the tasks you have finished (Done), up to the last step.
R.Missions = { Slots = 3 }
R.Tasks = {
	Goons = { Text = 'Defeat %d goons', Goals = { 10, 20, 35, 50 }, Cash = 250 },
	Shots = { Text = 'Shoot %d times at a range', Goals = { 150, 250, 400, 600 }, Cash = 200 },
	Boxes = { Text = 'Open %d shoe boxes', One = 'Open a shoe box', Goals = { 1, 2, 3, 5 }, Cash = 300 },
	Clears = { Text = 'Beat %d stage crews', One = 'Beat a stage crew', Goals = { 1, 2, 3, 4 }, Cash = 350 },
	CashOuts = { Text = 'Step on %d cash pads', One = 'Step on a cash pad', Goals = { 1, 2, 3, 4 }, Cash = 250 },
	Spins = { Text = 'Spin the wheel %d times', One = 'Spin the wheel', Goals = { 1, 1, 2, 2 }, Cash = 200 },
}
R.TaskOrder = { 'Goons', 'Shots', 'Boxes', 'Clears', 'CashOuts', 'Spins' }
R.MissionTemplate = { List = {}, Done = 0 }
-- The step (1..4) the goals are at after `done` finished tasks.
function R.taskStep(done: any): number
	return math.clamp(1 + math.floor(number(done, 0) / 6), 1, 4)
end
-- A task's text ('Defeat 20 goons', 'Open a shoe box').
function R.taskText(kind: any, goal: any): string
	local t = R.Tasks[kind]
	if not t then return '' end
	local g = math.floor(number(goal, 1))
	if g == 1 and t.One then return t.One end
	return string.format(t.Text, g)
end
-- The reward spec of a task (its Cash grows with the step: x1, x1.5, x2, x3).
function R.taskReward(kind: any, step: any): { [string]: any }
	local t = R.Tasks[kind]
	local mult = ({ 1, 1.5, 2, 3 })[whole(step, 1, 4)]
	return { Cash = (t and t.Cash or 200) * mult }
end
function R.sanitizeMissions(m: any): { [string]: any }
	local out = { List = {}, Done = 0 }
	if type(m) ~= 'table' then return out end
	out.Done = whole(m.Done, 0, 1e9)
	if type(m.List) == 'table' then
		for _, t in m.List do
			if #out.List >= R.Missions.Slots then break end
			if type(t) == 'table' and R.Tasks[t.Kind] then
				local goal = whole(t.Goal, 1, 1e6)
				table.insert(out.List, { Kind = t.Kind, Goal = goal, Have = whole(t.Have, 0, goal), Step = whole(t.Step, 1, 4) })
			end
		end
	end
	return out
end
-- Fills the list up to Slots tasks. pick(n) returns a whole number in 1..n (the server's Random; tests pass their own).
-- allowed(kind) says whether this map can count that kind (no shoe boxes, no stages: skipped). skip = a kind to avoid
-- (the one just claimed) while another is free.
function R.fillMissions(m: any, pick: (number) -> number, allowed: ((string) -> boolean)?, skip: string?)
	local step = R.taskStep(m.Done)
	while #m.List < R.Missions.Slots do
		local open = {}
		for _, kind in R.TaskOrder do
			local used = false
			for _, t in m.List do
				if t.Kind == kind then used = true end
			end
			if not used and (not allowed or allowed(kind)) then table.insert(open, kind) end
		end
		if #open > 1 and skip then
			local i = table.find(open, skip)
			if i then table.remove(open, i) end
		end
		if #open == 0 then break end
		local kind = open[math.clamp(pick(#open), 1, #open)]
		table.insert(m.List, { Kind = kind, Goal = R.Tasks[kind].Goals[step], Have = 0, Step = step })
	end
end
-- Counts n more of `kind` on every open task of that kind. Returns the tasks that just finished (indexes).
function R.countMission(m: any, kind: string, n: any): { number }
	local done = {}
	local add = math.floor(number(n, 0))
	if add <= 0 then return done end
	for i, t in m.List do
		if t.Kind == kind and t.Have < t.Goal then
			t.Have = math.min(t.Goal, t.Have + add)
			if t.Have >= t.Goal then table.insert(done, i) end
		end
	end
	return done
end
-- How many tasks are finished and waiting for their Claim (the HUD's "1/3").
function R.missionsReady(m: any): number
	local n = 0
	for _, t in (type(m) == 'table' and type(m.List) == 'table' and m.List or {}) do
		if type(t) == 'table' and number(t.Have, 0) >= number(t.Goal, 1) then n += 1 end
	end
	return n
end
-- Claims task i: true and the claimed task, or false and why ('unknown', 'notdone'). The caller pays it and refills.
function R.claimMission(m: any, i: any): (boolean, any)
	local n = math.floor(number(i, 0))
	local t = m.List[n]
	if not t then return false, 'unknown' end
	if t.Have < t.Goal then return false, 'notdone' end
	table.remove(m.List, n)
	m.Done = whole(m.Done, 0, 1e9) + 1
	return true, t
end

---------------------------------------------------------------------------------------------- starter pack
-- A one-time Robux bundle for a new player (Products 'StarterPack'): Cash (it scales with your best stage, like the Cash
-- Packs), two 2x Power boosts (30 minutes) and one of the world's Robux boxes, opened at once. Shown until it is bought,
-- then gone from the HUD. Its parts are listed on the card exactly as granted.
R.Starter = { Cash = 5000, Boosts = { 2, 2 }, BoostSeconds = 900, Boxes = 1 }

return R
