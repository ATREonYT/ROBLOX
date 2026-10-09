--!strict
-- Rebirths: pure rules shared by RebirthService (which decides), the HUD's Rebirth window, Lobby.client and the tests.
--   A rebirth needs your Power to reach need(n) (n = rebirths you have). It resets Power to 0 and keeps everything
--   else (Cash, guns, shoes, stage clears, cleared waves, goals). Your rebirth multiplier goes from multiplier(n) to
--   multiplier(n + 1): 1x, 2x, 3x ... ("Rebirth 3 -> Rebirth 4, 4x -> 5x"), and every shot's Power is multiplied by it.
--   Lanes unlock by rebirths (Config/Skins.Stations[i].Rebirths): BAY 1 at once, then 2, 4 ... 14, the Champ Ring at 16.
--   Each rebirth also walks half a stud a second faster (Balance.Walk), up to 24.
local Balance = require(script.Parent.Config.Balance)
local Skins = require(script.Parent.Config.Skins)

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

-- Power needed for the rebirth from n to n + 1.
function RebirthRules.need(n: any): number
	local k = RebirthRules.count(n)
	return Balance.round(Balance.RebirthBase * Balance.RebirthGrowth ^ k * RebirthRules.multiplier(k))
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

-- A lane's rebirths needed (0 for an unknown one).
function RebirthRules.laneNeed(station: any): number
	return type(station) == 'table' and type(station.Rebirths) == 'number' and station.Rebirths or 0
end

-- Is lane `station` (a Skins.Stations row) open with n rebirths?
function RebirthRules.laneOpen(station: any, n: any): boolean
	return type(station) == 'table' and RebirthRules.count(n) >= RebirthRules.laneNeed(station)
end

-- The best lane open with n rebirths (the Skins.Stations row).
function RebirthRules.bestLane(n: any)
	local best = Skins.Stations[1]
	for _, s in Skins.Stations do
		if RebirthRules.laneOpen(s, n) and s.Multiplier >= best.Multiplier then best = s end
	end
	return best
end

-- The lane the next rebirth (n -> n + 1) opens, or nil.
function RebirthRules.nextUnlock(n: any)
	local k = RebirthRules.count(n) + 1
	for _, s in Skins.Stations do
		if s.Rebirths == k then return s end
	end
	return nil
end

-- The next lane still locked with n rebirths, or nil when every lane is open.
function RebirthRules.nextLane(n: any)
	for _, s in Skins.Stations do
		if not RebirthRules.laneOpen(s, n) then return s end
	end
	return nil
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
