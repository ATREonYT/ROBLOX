--!strict
-- Shooting at the ranges and the stage goons: what a shot pays and when it counts. Pure functions, so LobbyService
-- and WaveService (which pay), Shoot.client and Waves.client (which show the "+N" before the server answers) and the
-- unit tests all agree.
--   One shot pays  ShotBase x the lane's Multiplier x the rebirth multiplier x boosts  (perShot; a stage goon is a
--   x1 lane; boosts = x2 with the 2x Power pass, times a running timed boost)  x the gun's multiplier  x the shoes'
--   multiplier. Only in an open lane's shooter's box (a locked lane pays nothing) or at a stage goon.
--   At the ranges the gun fires on its own (brief 18): while you stand in an open lane the server pays AutoRate shots a
--   second (LobbyService, on its own clock: nobody clicks) and Shoot.client shows them. At the goons you hold the
--   trigger (or the Auto Fight pass fires for you): Cooldown between shots on the client, the server's token bucket
--   (Burst, PerSecond) a little looser.
--   The server publishes perShot for where you stand as the player attribute ShotBase (LobbyService).
local Balance = require(script.Parent.Config.Balance)
local RebirthRules = require(script.Parent.RebirthRules)

local ShotRules = {}
ShotRules.AutoRate = 5 -- shots a second the gun fires by itself in an open lane (paid by the server's clock)
ShotRules.Burst = 6 -- shots at goons the server lets through at once
ShotRules.PerSecond = 6 -- and the rate it refills at
ShotRules.Cooldown = 0.2 -- seconds between shots at goons on the client (5 a second: a little under the server's rate)
ShotRules.MaxBoost = 10 -- sanity cap on pass x timed boost
ShotRules.MaxShoeMultiplier = 100 -- sanity cap (three Secrets from the top box give about x25)

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- The boost factor from the player's pass and timed boost (attributes the store sets on the server): x2 with the 2x
-- Power pass, times PowerBoost (1..10).
function ShotRules.boost(doublePass: any, timedBoost: any): number
	local b = (doublePass == true and 2 or 1) * math.clamp(number(timedBoost, 1), 1, ShotRules.MaxBoost)
	return math.min(b, ShotRules.MaxBoost)
end

-- Power one shot pays before the gun and the shoes: ShotBase x lane x rebirth multiplier x boost (lane 1 for a stage
-- target; a locked lane's 0 stays 0).
function ShotRules.perShot(lane: any, rebirths: any, boost: any?): number
	local l = math.max(0, number(lane, 1))
	return Balance.ShotBase * l * RebirthRules.multiplier(rebirths) * math.clamp(number(boost, 1), 1, ShotRules.MaxBoost)
end

-- Power one shot pays: max(1, floor(perShot)) x the gun's multiplier (junk counts as 1; a perShot of 0 or less, a locked
-- lane's, pays 0), times the equipped shoes' multiplier when one is given (ShoeMultiplier, 1 + their bonus / 100;
-- Shared/ShoeRules). With `carry` (a table kept per player, {} to start) the shoes' fraction carries over to the next
-- shot, so a +10% pays exactly 10% more over time even while a shot pays 1 or 2; without it the shoes' result is rounded.
function ShotRules.pay(perShot: any, gunMultiplier: any, shoeMultiplier: any?, carry: any?): number
	local per = number(perShot, 1)
	if per <= 0 then return 0 end
	local gun = math.max(1, number(gunMultiplier, 1))
	local base = math.max(1, math.floor(per + 1e-7)) * gun
	local shoes = math.clamp(number(shoeMultiplier, 1), 1, ShotRules.MaxShoeMultiplier)
	if shoes == 1 then return base end
	local exact = base * shoes
	if type(carry) ~= 'table' then return math.floor(exact + 0.5) end
	exact += math.clamp(number(carry.Shoes, 0), 0, 0.999999)
	local paid = math.floor(exact + 1e-7) -- (so 25 x 0.04 counts as a whole 1)
	carry.Shoes = math.max(0, exact - paid)
	return paid
end

-- True when a shot from a player standing at `station` (the TrainingStation attribute: '' = not on a range,
-- 'Locked:<Id>' = on a lane that needs more rebirths) pays.
function ShotRules.counts(station: any): boolean
	return type(station) == 'string' and station ~= '' and string.find(station, 'Locked:', 1, true) == nil
end

-- The auto-fire clock: `carry` ({} per player) gathers dt x AutoRate; returns the whole shots due now (at most `cap`,
-- default 3: a long server hitch never pays a burst) and keeps the fraction. In a locked lane or off the ranges the
-- clock stops and primes itself, so stepping into a lane fires (and pays) on the very next tick.
ShotRules.AutoPrime = 0.8
function ShotRules.autoShots(carry: any, dt: any, station: any, cap: number?): number
	if type(carry) ~= 'table' then return 0 end
	if not ShotRules.counts(station) then
		carry.Auto = ShotRules.AutoPrime
		return 0
	end
	local acc = math.max(0, number(carry.Auto, ShotRules.AutoPrime)) + math.clamp(number(dt, 0), 0, 1) * ShotRules.AutoRate
	local shots = math.min(math.floor(acc + 1e-7), cap or 3)
	carry.Auto = math.min(acc - shots, 1)
	return shots
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
