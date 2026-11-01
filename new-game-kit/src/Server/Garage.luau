--!strict
-- New Game Kit: Garage (vault "Realistic City RP/03 Vehicles - Driving, Dealership, Garage and Fuel")
-- Install: ServerScriptService/Kit/Garage (ModuleScript). Pure logic: no Instances, no remotes.
-- Spawning, the server cap and the cooldown stay in Roleplay.CanSpawnVehicle; this module owns
-- what you OWN and what it COSTS to keep it running.
--
--   Garage.CanBuy(catalog, owned, id, level)       -> ok, reason, price   (dealership)
--   Garage.Burn(fuel, studs, tank, throttle01)     -> new fuel            (server, from the car's real travel)
--   Garage.RefuelCost(fuel, tank, pricePerUnit)    -> units, cost         (gas station pump)
--   Garage.RepairCost(price, health01)             -> cost                (mechanic)
--   Garage.ImpoundFee(price)                       -> fee                 (towed / wrecked / left in the road)
--   Garage.SellBack(price)                         -> refund              (dealer buys it back at 60%)
-- The server measures distance from the car's own position each tick, never from the client.
-- Status: covered by tests/Garage.spec.luau (offline).

local Garage = {}

Garage.Rules = {
	unitsPer1000Studs = 6, -- a 60-unit tank goes ~10,000 studs: about 6-8 minutes of city driving
	idleBurnFraction = 0.25, -- coasting still burns a quarter
	minRefuelCost = 5,
	repairFraction = 0.25, -- a full repair of a wreck costs 25% of the car's price
	impoundFraction = 0.05,
	impoundMin = 50,
	sellBackFraction = 0.6,
	maxOwned = 12, -- garage slots before a gamepass (a pass may add slots, never cars)
}

export type Car = { price: number, level: number?, pass: boolean? }

function Garage.CanBuy(catalog: { [string]: Car }, owned: { [string]: boolean }, id: string, level: number, hasPass: boolean?): (boolean, string, number)
	local car = catalog[id]
	if not car then
		return false, "Unknown", 0
	end
	if owned[id] then
		return false, "Owned", 0
	end
	if car.pass and not hasPass then
		return false, "NeedsPass", car.price
	end
	if (car.level or 0) > level then
		return false, "Level", car.price
	end
	local count = 0
	for _ in owned do
		count += 1
	end
	if count >= Garage.Rules.maxOwned then
		return false, "GarageFull", car.price
	end
	return true, "Ok", car.price
end

function Garage.Burn(fuel: number, studs: number, tank: number, throttle01: number?): number
	if studs ~= studs or studs <= 0 then
		return fuel
	end
	local t = math.clamp(throttle01 or 1, 0, 1)
	local factor = Garage.Rules.idleBurnFraction + (1 - Garage.Rules.idleBurnFraction) * t
	local used = studs / 1000 * Garage.Rules.unitsPer1000Studs * factor
	return math.clamp(fuel - used, 0, tank)
end

function Garage.RefuelCost(fuel: number, tank: number, pricePerUnit: number): (number, number)
	local units = math.max(0, math.ceil(tank - fuel))
	if units == 0 then
		return 0, 0
	end
	return units, math.max(Garage.Rules.minRefuelCost, units * pricePerUnit)
end

function Garage.RepairCost(price: number, health01: number): number
	local damage = 1 - math.clamp(health01, 0, 1)
	return math.floor(price * Garage.Rules.repairFraction * damage + 0.5)
end

function Garage.ImpoundFee(price: number): number
	return math.max(Garage.Rules.impoundMin, math.floor(price * Garage.Rules.impoundFraction))
end

function Garage.SellBack(price: number): number
	return math.floor(price * Garage.Rules.sellBackFraction)
end

return Garage
