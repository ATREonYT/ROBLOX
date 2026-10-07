--!strict
-- Shooting at the ranges: what a shot pays and when it counts. Pure functions, so LobbyService (which pays),
-- Shoot.client (which shows the "+N" before the server answers) and the unit tests all agree.
--   A shot pays a tenth of your per-second gain (at least 1) times your gun's multiplier, only while you stand
--   in an unlocked range's shooter's box (the TrainingStation attribute LobbyService keeps), about 7 a second.
local ShotRules = {}
ShotRules.Burst = 8 -- shots the server lets through at once
ShotRules.PerSecond = 7 -- and the rate it refills at
ShotRules.Cooldown = 0.14 -- seconds between shots on the client (a little under the server's rate)

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- Power one shot pays: max(1, floor(PowerRate * 0.1)) * GunMultiplier (bad inputs count as 1).
function ShotRules.pay(powerRate: any, gunMultiplier: any): number
	local rate = math.max(0, number(powerRate, 1))
	local gun = math.max(1, number(gunMultiplier, 1))
	return math.max(1, math.floor(rate * 0.1)) * gun
end

-- True when a shot from a player standing at `station` (the TrainingStation attribute: '' = not on a range,
-- 'Locked:<Id>' = on a range you can't use yet) counts.
function ShotRules.counts(station: any): boolean
	return type(station) == 'string' and station ~= '' and string.find(station, 'Locked:', 1, true) == nil
end

return ShotRules
