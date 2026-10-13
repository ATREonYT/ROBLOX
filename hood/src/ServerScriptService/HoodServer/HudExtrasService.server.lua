-- The HUD extras (brief 30, HUD): the spin wheel, the Playtime Rewards, the Missions and the Starter Pack. The rules are
-- Shared/HudExtrasRules, the profile changes HoodServer/HudExtras; this is the glue:
--   * a visit starts: the playtime session carries on (a short drop) or starts again; three missions are dealt; a box won
--     on the wheel but not opened yet (the player left while it turned) is opened now
--   * once a second: playtime ticks for every player with a loaded profile; the Shots missions count the range's auto-fire
--     (ShotRules.AutoRate shots a second while you stand in an open lane: LobbyService's TrainingStation)
--   * the missions count what the server already knows, never a number a client sends: goons (WaveService's WaveLeft
--     falling in the same stage), stage crews beaten (WaveLeft reaching 0), boxes opened (ShoesOpened rising), cash pads
--     (CashOuts rising) and spins
--   * attributes for the HUD: SpinFree, SpinNext (os.time of the next free spin), SpinExtra; PlaytimeSeconds (this
--     session), PlaytimeReady (gifts waiting); MissionsReady (tasks finished, waiting for their Claim); StarterOwned
--   * the HudExtras RemoteFunction: 'State', 'Spin', 'ClaimGift' (i), 'ClaimMission' (i). The answer is always
--     { Ok, Text, State } (Spin adds Wedge, the index the wheel stops on, and Guaranteed: it was the pity-guaranteed big
--     prize, Shared/PityRules; State.Spin.Pity = { Left, Every } is the counter the window prints). A spin's prize is in the profile at once, but
--     the screen hears of it (Cash / Power attributes, the notice, a won box's opening) only once the wheel has stopped
--     (a won boost starts at once: StoreService publishes the profile's boosts every second).
-- Kid-safe: nothing here opens a window or a purchase prompt by itself; a finished mission is told with one notice, never
-- during a new player's quiet start (OnboardingQuiet).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local HudExtras = require(script.Parent.HudExtras)
local Retention = require(script.Parent.Retention)
local RateLimiter = require(script.Parent.RateLimiter)
local Rules = require(RS.Shared.HudExtrasRules)
local Pity = require(RS.Shared.PityRules)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)

local function optional(module)
	if not module then return nil end
	local ok, result = pcall(require, module)
	return ok and type(result) == 'table' and result or nil
end
local Shoes = optional(RS.Shared.Config:FindFirstChild('Shoes'))
local ShotRules = optional(RS.Shared:FindFirstChild('ShotRules'))
local ShoeOpening = optional(script.Parent:FindFirstChild('ShoeOpening'))
local Products = optional(RS.Shared.Config:FindFirstChild('Products'))

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end -- (Bootstrap made the remotes)

local limit = RateLimiter.new(6, 3)
local rng = Random.new()
local joined = {} -- [player] = true once the visit is set up
local carry = {} -- [player] = fraction of a range shot not counted yet
local seen = {} -- [player] = { WaveStage, WaveLeft, ShoesOpened, CashOuts } as last seen
local revealAt = {} -- [player] = os.clock() before which a spin's prize stays hidden

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function pick(n) return rng:NextInteger(1, math.max(1, n)) end
local function allowed(player)
	return function(kind)
		if kind == 'Boxes' then return RS:GetAttribute('ShoeBoxes') == true end
		if kind == 'Goons' or kind == 'Clears' then return type(player:GetAttribute('WaveCleared')) == 'number' end
		if kind == 'Shots' then return ShotRules ~= nil end
		return true
	end
end
local function boxName(id)
	local box = Shoes and Shoes.BoxById[id]
	return box and box.Name or (tostring(id) .. ' Box')
end
local function lines(reward) return Rules.lines(reward, Format.compact, boxName) end

local function publish(player, profile)
	local data = HudExtras.tables(profile.Data)
	local st = Rules.spinState(data.Spin, os.time())
	set(player, 'SpinFree', st.Free)
	set(player, 'SpinNext', data.Spin.NextFree)
	set(player, 'SpinExtra', st.Extra)
	set(player, 'PlaytimeSeconds', math.floor(data.Playtime.Seconds))
	local _, ready = Rules.playtimeState(data.Playtime)
	set(player, 'PlaytimeReady', ready)
	set(player, 'MissionsReady', Rules.missionsReady(data.Missions))
	set(player, 'MissionsDone', data.Missions.Done)
	set(player, 'StarterOwned', data.StarterPack == true)
end
-- Cash and Power on the screen from the profile (after a reward)
local function showMoney(player, profile)
	set(player, 'Cash', profile.Data.Cash)
	set(player, 'Power', profile.Data.Rep)
end
local function notice(player, text) pcall(function() Net.get('Notice'):FireClient(player, text) end) end
local function quiet(player) return player:GetAttribute('OnboardingQuiet') == true end

-- A won box: opened now (the unboxing moment plays). A failure is logged and the box dropped, never retried forever.
local function openPending(player, profile)
	local data = HudExtras.tables(profile.Data)
	local id = data.Spin.PendingBox
	if id == '' then return end
	data.Spin.PendingBox = ''
	if not (Shoes and ShoeOpening and Shoes.BoxById[id]) then
		warn('[HudExtrasService] no box ' .. tostring(id) .. ' to open')
		return
	end
	local ok, err = pcall(ShoeOpening.openMany, player, profile, id, 1)
	if not ok then warn('[HudExtrasService] box: ' .. tostring(err)) end
end

---------------------------------------------------------------------------------------------- the client's view
local function stateOf(player, profile)
	local data = HudExtras.tables(profile.Data)
	local now = os.time()
	local st = Rules.spinState(data.Spin, now)
	local wedges = {}
	for i, w in Rules.Wedges do
		local r = HudExtras.reward(profile, w)
		wedges[i] = { Id = w.Id, Lines = lines(r), Icon = Rules.iconOf(r), Chance = Rules.chanceText(i), Color = w.Color }
	end
	local gifts, ready = Rules.playtimeState(data.Playtime)
	for i, g in gifts do
		local r = HudExtras.reward(profile, Rules.Gifts[i])
		g.Lines, g.Icon = lines(r), Rules.iconOf(r)
	end
	local tasks = {}
	for i, t in data.Missions.List do
		local r = HudExtras.reward(profile, Rules.taskReward(t.Kind, t.Step))
		tasks[i] = { Kind = t.Kind, Text = Rules.taskText(t.Kind, t.Goal), Goal = t.Goal, Have = t.Have, Lines = lines(r), Icon = Rules.iconOf(r) }
	end
	local starter
	do
		local boxId = Shoes and HudExtras.starterBox(Shoes, Shoes.ActiveWorld)
		local parts = HudExtras.starterParts(profile, boxId)
		starter = {
			Owned = data.StarterPack == true, Box = boxId, BoxName = boxId and boxName(boxId) or '',
			Lines = { '+' .. Format.compact(parts.Cash) .. ' Cash', '2x Power ' .. math.floor(#parts.Boosts * parts.Seconds / 60 + 0.5) .. ' min', boxId and ('1 ' .. boxName(boxId)) or nil },
			Price = Products and Products.ByKey.StarterPack and Products.ByKey.StarterPack.Price or 0,
		}
	end
	return {
		-- (brief 30) Pity: spins until the guaranteed big prize (1 = the next spin); the window prints it, the server enforces it
		Spin = { Free = st.Free, Wait = st.Wait, Extra = st.Extra, Total = st.Total, Wedges = wedges, FreeEvery = Rules.Spin.FreeEvery, Pack = Rules.Spin.PackSpins,
			Pity = { Left = Pity.wheelLeft(data.Pity), Every = Pity.Wheel.Every } },
		Playtime = { Seconds = data.Playtime.Seconds, Gifts = gifts, Ready = ready },
		Missions = { List = tasks, Done = data.Missions.Done, Ready = Rules.missionsReady(data.Missions) },
		Starter = starter,
	}
end

local function setup(player, profile)
	if joined[player] then return end
	joined[player] = true
	local data = HudExtras.tables(profile.Data)
	HudExtras.playtimeJoin(profile, os.time())
	Rules.fillMissions(data.Missions, pick, allowed(player))
	-- (a box won just before the player left last time)
	if data.Spin.PendingBox ~= '' then task.delay(4, function()
		local p = Data.get(player)
		if p then
			openPending(player, p)
			Data.push(player)
		end
	end) end
	publish(player, profile)
end

-- A finished task: one short notice (none in a new player's quiet start: the HUD's counter says it).
local function finished(player, profile, done)
	if #done == 0 then return end
	publish(player, profile)
	if quiet(player) then return end
	local t = profile.Data.Missions.List[done[1]]
	if t then notice(player, 'Mission done: ' .. Rules.taskText(t.Kind, t.Goal) .. '! Claim it in Missions.') end
end
local function count(player, kind, n)
	local profile = Data.get(player)
	if not profile or not joined[player] then return end
	finished(player, profile, HudExtras.count(profile, kind, n))
end

---------------------------------------------------------------------------------------------- requests
local function reply(player, profile, ok, text)
	publish(player, profile)
	if type(text) == 'string' and text ~= '' then notice(player, text) end
	return { Ok = ok, Text = text, State = stateOf(player, profile) }
end
local function answer(player, action, arg)
	if not limit.allow(player) then return { Ok = false, Text = 'Slow down a little!' } end
	local profile = Data.get(player)
	if not profile then return { Ok = false, Text = 'Still loading...' } end
	setup(player, profile)
	local now = os.time()
	if action == 'Spin' then
		if os.clock() < (revealAt[player] or 0) then return reply(player, profile, false, '') end
		local ok, i, reward, guaranteed = HudExtras.spin(profile, rng:NextNumber(), now)
		if not ok then
			return reply(player, profile, false, i == 'busy' and '' or 'No spins right now. A free one comes back soon!')
		end
		count(player, 'Spins', 1)
		-- the prize shows once the wheel has stopped: Cash / Power, the notice, a won box's opening
		revealAt[player] = os.clock() + Rules.Spin.SpinSeconds
		task.delay(Rules.Spin.SpinSeconds, function()
			local p = Data.get(player)
			if not p then return end
			showMoney(player, p)
			notice(player, 'You won ' .. table.concat(lines(reward), ' + ') .. '!')
			openPending(player, p)
			publish(player, p)
			Data.push(player)
		end)
		local res = reply(player, profile, true, '')
		res.Wedge = i
		res.Guaranteed = guaranteed == true -- (brief 30: this spin was the guaranteed big prize: the window tags it)
		res.Lines = lines(reward)
		return res
	elseif action == 'ClaimGift' then
		local ok, reward = HudExtras.claimGift(profile, arg, now)
		if not ok then
			return reply(player, profile, false, reward == 'early' and 'Keep playing: that gift is not open yet!' or reward == 'taken' and 'You already took that gift.' or '')
		end
		showMoney(player, profile)
		openPending(player, profile)
		Data.push(player)
		return reply(player, profile, true, 'Playtime gift: ' .. table.concat(lines(reward), ' + ') .. '!')
	elseif action == 'ClaimMission' then
		local ok, reward = HudExtras.claimMission(profile, arg, now, pick, allowed(player))
		if not ok then return reply(player, profile, false, reward == 'notdone' and 'Finish that mission first!' or '') end
		showMoney(player, profile)
		Data.push(player)
		return reply(player, profile, true, 'Mission reward: ' .. table.concat(lines(reward), ' + ') .. '!')
	end
	return reply(player, profile, true, '')
end
local function invoked(player, action, arg)
	local ok, result = pcall(answer, player, action, arg)
	if ok and type(result) == 'table' then return result end
	warn('[HudExtrasService] ' .. tostring(result))
	return { Ok = false, Text = 'Something went wrong. Try again.' }
end
local okHook, why = pcall(function() Net.get('HudExtras').OnServerInvoke = invoked end)
if not okHook then warn('[HudExtrasService] no HudExtras remote: ' .. tostring(why)) end

---------------------------------------------------------------------------------------------- what the missions count
local function watch(player)
	seen[player] = {}
	local function grab(name) return player:GetAttribute(name) end
	-- goons and crews: WaveLeft falls in the same stage (a stage left mid-fight changes WaveStage first, a fresh crew
	-- raises WaveLeft: neither counts)
	player:GetAttributeChangedSignal('WaveLeft'):Connect(function()
		local s = seen[player]
		if not s then return end
		local stage, left = grab('WaveStage'), grab('WaveLeft')
		if type(left) == 'number' and type(s.WaveLeft) == 'number' and stage == s.WaveStage and type(stage) == 'number' and stage > 0 and left < s.WaveLeft then
			count(player, 'Goons', s.WaveLeft - left)
			if left == 0 then count(player, 'Clears', 1) end
		end
		s.WaveStage, s.WaveLeft = stage, left
	end)
	player:GetAttributeChangedSignal('WaveStage'):Connect(function()
		local s = seen[player]
		if s then s.WaveStage, s.WaveLeft = grab('WaveStage'), grab('WaveLeft') end
	end)
	for _, name in { 'ShoesOpened', 'CashOuts' } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local s = seen[player]
			if not s then return end
			local v = grab(name)
			if type(v) == 'number' and type(s[name]) == 'number' and v > s[name] then count(player, name == 'ShoesOpened' and 'Boxes' or 'CashOuts', v - s[name]) end
			s[name] = v
		end)
		seen[player][name] = grab(name)
	end
	seen[player].WaveStage, seen[player].WaveLeft = grab('WaveStage'), grab('WaveLeft')
end
Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do watch(p) end
Players.PlayerRemoving:Connect(function(player)
	local profile = Data.get(player)
	if profile then pcall(Rules.playtimeTick, HudExtras.tables(profile.Data).Playtime, 0, os.time()) end
	limit.remove(player)
	joined[player], carry[player], seen[player], revealAt[player] = nil, nil, nil, nil
end)

---------------------------------------------------------------------------------------------- the clock
local last = os.clock()
while true do
	task.wait(1)
	local dt = math.clamp(os.clock() - last, 0, 5)
	last = os.clock()
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			if not joined[player] then
				local ok, err = pcall(setup, player, profile)
				if not ok then warn('[HudExtrasService] ' .. tostring(err)) end
			else
				HudExtras.playtimeTick(profile, dt, os.time())
				-- the range's auto-fire: AutoRate shots a second in an open lane
				local station = player:GetAttribute('TrainingStation')
				if ShotRules and type(station) == 'string' and station ~= '' and not station:find('^Locked:') then
					local c = (carry[player] or 0) + dt * (ShotRules.AutoRate or 2)
					local n = math.floor(c)
					carry[player] = c - n
					if n > 0 then count(player, 'Shots', n) end
				end
				-- (the prize of a spin still turning stays hidden: no publish of Cash or the spin state until it stops)
				if os.clock() >= (revealAt[player] or 0) then publish(player, profile) end
			end
		end
	end
end
