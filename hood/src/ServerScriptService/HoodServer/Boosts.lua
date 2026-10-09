-- What a player's passes and timed boosts multiply, read from the attributes the store sets on the server (UI's
-- StoreService: Pass_DoubleRep, Pass_DoubleCash, Pass_VIP, PowerBoost). Attributes a client sets on itself never reach the
-- server, so these can't be faked. Used by LobbyService and WaveService (Power per shot) and StageService, WaveService
-- and GoalService (Cash).
--
-- Timed Power boosts (brief 22; StoreService grants them, these are the pure rules): a profile keeps
--   Passes.Boost = { Level, Until, Next = { { Level, Until }, ... } }
-- the running boost (x Level until os.time Until) and the ones waiting behind it, each starting when the one before it
-- ends (all on the wall clock, like before: a boost runs while you're away). Every level keeps its own time: the
-- strongest runs first and a weaker one waits its turn, so no bought minute is ever lost or merged into another level.
-- Buying adds that level's minutes (Boosts.add). A save from before brief 22 ({ Level, Until } only) reads the same.
local RS = game:GetService('ReplicatedStorage')
local ShotRules = require(RS.Shared.ShotRules)

local Boosts = {}
Boosts.MaxLevel = 10 -- (ShotRules.boost clamps PowerBoost to 1..10 too)
Boosts.MaxSeconds = 30 * 86400 -- sanity cap per level (a month: far past anything bought)

-- x2 with the 2x Power pass, times a running timed boost (PowerBoost, 1..10).
function Boosts.power(player)
	return ShotRules.boost(player:GetAttribute('Pass_DoubleRep'), player:GetAttribute('PowerBoost'))
end

-- x2 with the x2 Cash pass, x1.5 with VIP (both: x3).
function Boosts.cash(player)
	return (player:GetAttribute('Pass_DoubleCash') == true and 2 or 1) * (player:GetAttribute('Pass_VIP') == true and 1.5 or 1)
end

-- Cash for a reward, with the pass (whole Cash).
function Boosts.cashFor(player, amount)
	return math.floor(math.max(0, amount) * Boosts.cash(player))
end

---------------------------------------------------------------------------------------------- timed boosts
local function finite(v)
	return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end

-- The boosts still to run at `now`, in run order: { { Level, Until, Left } } (Left = seconds of it still to come).
-- Ended ones and broken entries are dropped.
function Boosts.queue(boost, now)
	local list = {}
	if type(boost) ~= 'table' then return list end
	local raw = { boost }
	if type(boost.Next) == 'table' then
		for _, s in boost.Next do table.insert(raw, s) end
	end
	local prev = -math.huge -- (each one starts when the one before it ends)
	for _, s in raw do
		if type(s) == 'table' and finite(s.Level) and finite(s.Until) then
			local left = s.Until - math.max(now, prev)
			if left > 0 then
				table.insert(list, { Level = math.clamp(math.floor(s.Level), 1, Boosts.MaxLevel), Until = s.Until, Left = left })
			end
			prev = math.max(prev, s.Until)
		end
	end
	return list
end

-- Seconds left per level at `now`: { [level] = seconds } (levels above 1 only).
function Boosts.bank(boost, now)
	local bank = {}
	for _, s in Boosts.queue(boost, now) do
		if s.Level > 1 then bank[s.Level] = (bank[s.Level] or 0) + s.Left end
	end
	return bank
end

-- A Boost table from a bank, strongest first, the first one starting `now`; nil when there is no time left.
function Boosts.fromBank(bank, now)
	local levels = {}
	for level, seconds in bank do
		if seconds > 0 then table.insert(levels, level) end
	end
	if #levels == 0 then return nil end
	table.sort(levels, function(a, b) return a > b end)
	local t = now
	local boost
	for _, level in levels do
		t += math.min(bank[level], Boosts.MaxSeconds)
		if not boost then
			boost = { Level = level, Until = t, Next = {} }
		else
			table.insert(boost.Next, { Level = level, Until = t })
		end
	end
	return boost
end

-- The Boost table after buying `seconds` of x`level` at `now` (the old table is not changed). Every level's time left is
-- kept; the new minutes add to that level's share.
function Boosts.add(boost, level, seconds, now)
	assert(finite(level) and level % 1 == 0 and level >= 2 and level <= Boosts.MaxLevel, 'bad boost level ' .. tostring(level))
	assert(finite(seconds) and seconds > 0, 'bad boost time ' .. tostring(seconds))
	local bank = Boosts.bank(boost, now)
	bank[level] = (bank[level] or 0) + seconds
	return Boosts.fromBank(bank, now)
end

-- The boost running at `now`: its level (1 when none) and the os.time it ends (0 when none).
function Boosts.running(boost, now)
	local first = Boosts.queue(boost, now)[1]
	if not first then return 1, 0 end
	return first.Level, first.Until
end

-- Seconds of boosts left in all (every level).
function Boosts.total(boost, now)
	local n = 0
	for _, s in Boosts.queue(boost, now) do n += s.Left end
	return n
end

-- The BoostQueue attribute: 'Level:Until,...' in run order ('' when none), e.g. '3:1760001800,2:1760003600'.
function Boosts.queueString(boost, now)
	local parts = {}
	for _, s in Boosts.queue(boost, now) do table.insert(parts, s.Level .. ':' .. math.floor(s.Until)) end
	return table.concat(parts, ',')
end

return Boosts
