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

-- Which target a shot goes to. Every other shot the main one, the others take turns; a target that is away (a
-- popped balloon, a shattered bottle, a flown can, until it grows back) is skipped for the next one that is
-- there. Returns the target and whether it is there: with nothing there at all, (main, false) (the shot still
-- flies at the main target's spot and pays; nothing is hit). `state` keeps the turns ({} to start).
function ShotRules.pick(state: any, targets: { any }, main: any, present: (any) -> boolean): (any, boolean)
	state.Turn = (state.Turn or 0) + 1
	local others = {}
	for _, t in targets do
		if t ~= main then table.insert(others, t) end
	end
	if (state.Turn % 2 == 1 or #others == 0) and present(main) then return main, true end
	state.Walk = state.Walk or 0
	for _ = 1, #others do
		state.Walk = state.Walk % #others + 1
		local t = others[state.Walk]
		if present(t) then return t, true end
	end
	if present(main) then return main, true end
	return main, false
end

return ShotRules
