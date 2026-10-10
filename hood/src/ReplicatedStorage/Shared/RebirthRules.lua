--!strict
-- Rebirths: pure rules shared by RebirthService (which decides), the HUD's Rebirth window, Lobby.client and the tests.
--   A rebirth needs your Power to reach need(n) (n = rebirths you have). It resets Power to 0 and keeps everything
--   else (Cash, guns, shoes, stage clears, cleared waves, goals). Your rebirth multiplier goes from multiplier(n) to
--   multiplier(n + 1): 1x, 2x, 3x ... ("Rebirth 3 -> Rebirth 4, 4x -> 5x"), and every shot's Power is multiplied by it.
--   Lanes (Config/Skins.Stations, brief 23): rebirth lanes open at their Rebirths (BAY 1 at once, then 2, 4 ... 10, the
--   Champ Ring at 12); the two Robux lanes (Pass set) open with their game pass only. Functions that ask about lanes
--   take an optional `owns`: the player (its Pass_<Key> attributes), a table { [key] = true } or a function (key) ->
--   bool. Without it a Robux lane counts as closed.
--   Each rebirth also walks half a stud a second faster (Balance.Walk), up to 24.
local Balance = require(script.Parent.Config.Balance)
local Skins = require(script.Parent.Config.Skins)
local Products = require(script.Parent.Config.Products)

local RebirthRules = {}
RebirthRules.Cooldown = 2 -- seconds between rebirth requests the server lets through
RebirthRules.Max = Balance.MaxRebirths

-- A rebirth count from anywhere (saves, attributes): a whole number 0..Max (junk is 0).
function RebirthRules.count(n: any): number
	if type(n) ~= 'number' or n ~= n or n == math.huge or n == -math.huge then return 0 end
	return math.clamp(math.floor(n), 0, RebirthRules.Max)
end

-- The Power multiplier you have with n rebirths.
function RebirthRules.multiplier(n: any): number
	return 1 + RebirthRules.count(n) * Balance.RebirthMultiplierPerLevel
end

-- Power needed for the rebirth from n to n + 1 (brief 24): Balance.RebirthNeed[n + 1] (600, 4.5K, 30K ... quick at
-- first, each rebirth then taking longer than the last); past the list, each one RebirthGrowth times the last, times the
-- multiplier step (n + 1) / n, in two significant figures. Capped at NeedCap (no inf or NaN for absurd counts).
RebirthRules.NeedCap = 1e15
function RebirthRules.need(n: any): number
	local k = RebirthRules.count(n)
	local list = Balance.RebirthNeed
	if k < #list then return list[k + 1] end
	local last = #list - 1
	local v = list[#list] * Balance.RebirthGrowth ^ math.min(k - last, 60) * RebirthRules.multiplier(k) / RebirthRules.multiplier(last)
	return Balance.round(math.min(v, RebirthRules.NeedCap))
end

function RebirthRules.canRebirth(power: any, n: any): boolean
	if type(power) ~= 'number' or power ~= power then return false end
	return RebirthRules.count(n) < RebirthRules.Max and power >= RebirthRules.need(n)
end

-- The rebirth itself, on a profile's data (RebirthService saves and announces it): Power (Rep) back to 0 and one more
-- rebirth; Cash, Guns, Shoes, ClearedWalls, Waves and Goals are left as they are. free = true skips the Power check
-- (a paid skip). Returns true, or false and why: 'power' (not enough), 'max'.
function RebirthRules.apply(data: any, free: boolean?): (boolean, string?)
	local n = RebirthRules.count(data.Rebirths)
	if n >= RebirthRules.Max then return false, 'max' end
	if not free and not RebirthRules.canRebirth(data.Rep, n) then return false, 'power' end
	data.Rep = 0
	data.Rebirths = n + 1
	return true, nil
end

-- How full the bar to the next rebirth is, 0..1.
function RebirthRules.progress(power: any, n: any): number
	if type(power) ~= 'number' or power ~= power then return 0 end
	return math.clamp(power / RebirthRules.need(n), 0, 1)
end

-- A lane's rebirths needed (0 for an unknown one, and for a Robux lane: it needs its pass instead).
function RebirthRules.laneNeed(station: any): number
	if type(station) ~= 'table' or RebirthRules.lanePass(station) then return 0 end
	return type(station.Rebirths) == 'number' and station.Rebirths or 0
end

-- The game-pass key a Robux lane needs (Config/Products.Passes), or nil for a rebirth lane.
function RebirthRules.lanePass(station: any): string?
	local key = type(station) == 'table' and station.Pass
	return (type(key) == 'string' and key ~= '') and key or nil
end

-- Does `owns` hold pass `key`? owns: a player (Instance: its Pass_<Key> attribute is true), a table { [key] = true }, or
-- a function (key) -> boolean. Anything else owns nothing.
function RebirthRules.hasPass(owns: any, key: any): boolean
	if type(key) ~= 'string' or key == '' then return false end
	if typeof(owns) == 'Instance' then return (owns :: any):GetAttribute('Pass_' .. key) == true end
	if type(owns) == 'table' then return owns[key] == true end
	if type(owns) == 'function' then return owns(key) == true end
	return false
end

-- Is lane `station` (a Skins.Stations row) open with n rebirths (and the passes in `owns`)?
function RebirthRules.laneOpen(station: any, n: any, owns: any?): boolean
	if type(station) ~= 'table' then return false end
	local key = RebirthRules.lanePass(station)
	if key then return RebirthRules.hasPass(owns, key) end
	return RebirthRules.count(n) >= RebirthRules.laneNeed(station)
end

-- The best lane open with n rebirths (and the passes in `owns`): the Skins.Stations row.
function RebirthRules.bestLane(n: any, owns: any?)
	local best = Skins.Stations[1]
	for _, s in Skins.Stations do
		if RebirthRules.laneOpen(s, n, owns) and s.Multiplier >= best.Multiplier then best = s end
	end
	return best
end

-- The rebirth lane the next rebirth (n -> n + 1) opens, or nil (never a Robux lane).
function RebirthRules.nextUnlock(n: any)
	local k = RebirthRules.count(n) + 1
	for _, s in Skins.Stations do
		if not RebirthRules.lanePass(s) and s.Rebirths == k then return s end
	end
	return nil
end

-- The next rebirth lane still locked with n rebirths (the one with the fewest rebirths), or nil when every rebirth lane is
-- open. Robux lanes are never "next": they open with their pass.
function RebirthRules.nextLane(n: any)
	local best
	for _, s in Skins.Stations do
		if not RebirthRules.lanePass(s) and not RebirthRules.laneOpen(s, n) and (not best or s.Rebirths < best.Rebirths) then best = s end
	end
	return best
end

-- A lane's label lines, like the reference's stack: top, state, power, price.
--   top    a rebirth lane: its rebirths ('2'); a Robux lane: RobuxMark .. RobuxPrice ('⏣99' on screen: RobuxMark is
--          U+E002, Roblox fonts' Robux sign, so a terminal shows only '99')
--   state  'Unlocked' / 'Locked'
--   power  'x4 Power'
--   price  a Robux lane's RobuxPrice (99), nil on a rebirth lane: for a label that draws its own Robux icon image
RebirthRules.RobuxMark = Products.RobuxMark
function RebirthRules.laneLabel(station: any, open: boolean?): (string, string, string, number?)
	if type(station) ~= 'table' then return '', '', '', nil end
	local robux = RebirthRules.lanePass(station) ~= nil and type(station.RobuxPrice) == 'number'
	local top = robux and (RebirthRules.RobuxMark .. tostring(station.RobuxPrice)) or tostring(RebirthRules.laneNeed(station))
	return top, open and 'Unlocked' or 'Locked', 'x' .. tostring(station.Multiplier) .. ' Power', robux and station.RobuxPrice or nil
end

-- Walk speed with n rebirths.
function RebirthRules.walkSpeed(n: any): number
	local w = Balance.Walk
	return math.min(w.Top, w.Base + RebirthRules.count(n) * w.PerRebirth)
end

-- "Rebirth 3 -> Rebirth 4", "4x -> 5x" (the Rebirth window's two boxes).
function RebirthRules.labels(n: any): (string, string)
	local k = RebirthRules.count(n)
	local function x(v: number): string return (v % 1 == 0 and tostring(v) or string.format('%.1f', v)) .. 'x' end
	return 'Rebirth ' .. k .. ' → Rebirth ' .. (k + 1), x(RebirthRules.multiplier(k)) .. ' → ' .. x(RebirthRules.multiplier(k + 1))
end

return RebirthRules
