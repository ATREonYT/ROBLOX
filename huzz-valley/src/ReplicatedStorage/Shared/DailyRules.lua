--!strict
-- Daily quests, pure (tests/DailyRules.spec.luau; quests and timings in Config/DailyQuests). The server saves one
-- small table per player (data.Daily) and calls add() from ProgressService.addStat and claim() from ActionService
-- "ClaimDaily"; the window (UI/Screens/DailyQuests) calls view() with the server's clock to show the same thing.
--   data.Daily = { Day = 20380, Slot = 244560, Q = { D1 = { Id, Have, Done }, D2 = {...}, S = {...} } }
-- Which quests a day (or a 2-hour slot) has follows from its number alone (no randomness at run time), so each
-- day's pair is new, the pools come round again (recycled), and every server agrees.
local DailyQuests = require(script.Parent.Config.DailyQuests)

local DailyRules = {}

DailyRules.Keys = { "S", "D1", "D2" } -- the window's order (his picture d): the 2-hour spin quest, then the two daily quests

function DailyRules.day(now: number): number return now // DailyQuests.DayLength end
function DailyRules.slot(now: number): number return now // DailyQuests.SlotLength end

-- Seconds until the next daily reset (00:00 UTC) and until the next spin quest.
function DailyRules.resetIn(now: number): number return (DailyRules.day(now) + 1) * DailyQuests.DayLength - now end
function DailyRules.slotIn(now: number): number return (DailyRules.slot(now) + 1) * DailyQuests.SlotLength - now end

-- The pool in a fixed shuffled order for this seed (a small LCG: the same seed always gives the same order).
local function shuffled(n: number, seed: number): { number }
	local order = {}
	for i = 1, n do order[i] = i end
	-- (MINSTD: every product stays below 2^53, so it is exact and the same on every machine)
	local s = (seed % 2147483646) + 1
	for _ = 1, 3 do s = (s * 48271) % 2147483647 end
	for i = n, 2, -1 do
		s = (s * 48271) % 2147483647
		local j = (s // 7) % i + 1
		order[i], order[j] = order[j], order[i]
	end
	return order
end

-- The daily pool runs in cycles: each cycle is the whole pool in a shuffled order cut into pairs (two different
-- stats each), one pair a day, so every quest comes once per cycle and then again (recycled). The last pair of a
-- cycle never moves, and the next cycle's first pair is swapped with a later one if it shares a quest with it, so
-- no day repeats yesterday's quests.
local function cyclePairs(cycle: number): { { string } }
	local pool = DailyQuests.Daily
	local per = DailyQuests.PerDay
	local pairs
	for t = 0, 40 do
		local order = shuffled(#pool, cycle * 41 + t)
		local ok = true
		pairs = {}
		for i = 1, #order - per + 1, per do
			local pair, stats = {}, {}
			for k = 0, per - 1 do
				local q = pool[order[i + k]]
				if stats[q.Stat] then ok = false end
				stats[q.Stat] = true
				table.insert(pair, q.Id)
			end
			table.insert(pairs, pair)
		end
		if ok then break end
	end
	return pairs
end

local function fixedPairs(cycle: number): { { string } }
	local pairs = cyclePairs(cycle)
	local before = cyclePairs(cycle - 1)
	local last = before[#before]
	local function clash(pair: { string }): boolean
		for _, id in pair do
			if table.find(last, id) then return true end
		end
		return false
	end
	if clash(pairs[1]) then
		for k = 2, #pairs - 1 do
			if not clash(pairs[k]) then
				pairs[1], pairs[k] = pairs[k], pairs[1]
				break
			end
		end
	end
	return pairs
end

-- The day's quest ids (two, with different stats).
function DailyRules.picks(day: number): { string }
	local perCycle = #DailyQuests.Daily // DailyQuests.PerDay
	local pairs = fixedPairs(day // perCycle)
	return table.clone(pairs[day % perCycle + 1])
end

-- The spin quests that day's two daily quests don't already count (no "Make 3 crossings" over "Make 10 crossings").
local function spinChoices(slot: number): { any }
	local day = (slot * DailyQuests.SlotLength) // DailyQuests.DayLength
	local taken = {}
	for _, id in DailyRules.picks(day) do
		local q = DailyQuests.get(id)
		if q then taken[q.Stat] = true end
	end
	local out = {}
	for _, q in DailyQuests.Spin do
		if not taken[q.Stat] then table.insert(out, q) end
	end
	return if #out > 0 then out else DailyQuests.Spin
end

-- The 2-hour slot's spin quest id: in turn through the spin quests whose stat today's daily quests don't use, and
-- never the same one back to back (at midnight the list changes: then it skips ahead two).
function DailyRules.slotPick(slot: number): string
	local list = spinChoices(slot)
	local id = list[slot % #list + 1].Id
	local before = spinChoices(slot - 1)
	if before[(slot - 1) % #before + 1].Id == id and #list >= 3 then
		id = list[(slot + 2) % #list + 1].Id
	end
	return id
end

-- Brings a saved table up to `now`: a new day gives new daily quests, a new slot a new spin quest (progress 0).
function DailyRules.roll(state: any, now: number): any
	state = if type(state) == "table" then state else {}
	state.Q = if type(state.Q) == "table" then state.Q else {}
	local day, slot = DailyRules.day(now), DailyRules.slot(now)
	if state.Day ~= day then
		state.Day = day
		local p = DailyRules.picks(day)
		state.Q.D1 = { Id = p[1], Have = 0, Done = false }
		state.Q.D2 = { Id = p[2], Have = 0, Done = false }
	end
	if state.Slot ~= slot then
		state.Slot = slot
		state.Q.S = { Id = DailyRules.slotPick(slot), Have = 0, Done = false }
	end
	return state
end

-- A stat went up by n: every open quest on that stat moves (capped at its target).
function DailyRules.add(state: any, stat: string, n: number, now: number): any
	state = DailyRules.roll(state, now)
	for _, key in DailyRules.Keys do
		local e = state.Q[key]
		local q = e and DailyQuests.get(e.Id)
		if q and q.Stat == stat and not e.Done then
			e.Have = math.min(q.Target, (e.Have or 0) + n)
		end
	end
	return state
end

-- Claims a finished quest once. Returns the reward to give, or nil and why not.
function DailyRules.claim(state: any, key: any, now: number): (any, string?)
	DailyRules.roll(state, now)
	if type(key) ~= "string" or not table.find(DailyRules.Keys, key) then return nil, "Unknown quest." end
	local e = state.Q[key]
	local q = e and DailyQuests.get(e.Id)
	if not q then return nil, "Unknown quest." end
	if e.Done then return nil, "Already claimed." end
	if (e.Have or 0) < q.Target then return nil, "Not finished yet." end
	e.Done = true
	return q.Reward, nil
end

-- What the window shows at `now` (a copy: the saved table isn't changed): each quest with its progress.
function DailyRules.view(saved: any, now: number): { { key: string, quest: any, have: number, done: boolean } }
	local copy = { Day = saved and saved.Day, Slot = saved and saved.Slot, Q = {} }
	if saved and type(saved.Q) == "table" then
		for k, e in saved.Q do copy.Q[k] = { Id = e.Id, Have = e.Have, Done = e.Done } end
	end
	DailyRules.roll(copy, now)
	local out = {}
	for _, key in DailyRules.Keys do
		local e = copy.Q[key]
		local q = DailyQuests.get(e.Id)
		if q then table.insert(out, { key = key, quest = q, have = math.min(e.Have or 0, q.Target), done = e.Done == true }) end
	end
	return out
end

-- How many quests can be claimed right now (the HUD's dot).
function DailyRules.ready(saved: any, now: number): number
	local n = 0
	for _, v in DailyRules.view(saved, now) do
		if not v.done and v.have >= v.quest.Target then n += 1 end
	end
	return n
end

-- "9h 28m" / "28m" / "45s"
function DailyRules.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then return string.format("%dh %02dm", h, m) end
	if m > 0 then return string.format("%dm", m) end
	return string.format("%ds", seconds)
end

return DailyRules
