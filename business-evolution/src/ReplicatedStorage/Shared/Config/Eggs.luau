--!strict
-- Briefcases — this game's eggs. You spend Wins (the trophy currency) to pop
-- one open and an intern comes out to follow you around and earn Productivity
-- per second. The roster itself lives in Config/Interns.luau; this file only
-- decides which briefcase rolls from which slice of it, and at what odds.
--
-- Every briefcase publishes its exact odds in the UI and they MUST sum to 100.
-- There is a unit check for that. Wins are never sold for Robux, which is what
-- keeps this outside the paid-random-item rules — do not add a Robux path here.

local Interns = require(script.Parent.Interns)

export type Egg = {
	Id: string,
	Name: string,
	Cost: number, -- Wins
	Flavour: string,
	Color: { number },
	-- Rarity odds in %, summing to exactly 100. Rarities absent from a
	-- briefcase simply cannot drop from it.
	Odds: { [string]: number },
}

local Eggs: { Egg } = {
	{
		Id = "Cardboard",
		Name = "Cardboard Box",
		Cost = 25,
		Flavour = "Somebody's desk, in a box. Now it's yours.",
		Color = { 196, 152, 92 },
		Odds = { Common = 75, Uncommon = 22, Rare = 3 },
	},
	{
		Id = "Leather",
		Name = "Leather Briefcase",
		Cost = 250,
		Flavour = "Smells like a promotion.",
		Color = { 122, 74, 44 },
		Odds = { Common = 45, Uncommon = 35, Rare = 16, Epic = 4 },
	},
	{
		Id = "Aluminium",
		Name = "Aluminium Case",
		Cost = 2500,
		Flavour = "Handcuffed to somebody important.",
		Color = { 198, 204, 212 },
		Odds = { Uncommon = 40, Rare = 38, Epic = 19, Legendary = 3 },
	},
	{
		Id = "Golden",
		Name = "Golden Briefcase",
		Cost = 25000,
		Flavour = "The clasps alone cost more than your first car.",
		Color = { 255, 196, 40 },
		Odds = { Rare = 34, Epic = 48, Legendary = 18 },
	},
}

local EggsModule = {}

EggsModule.List = Eggs

local byId: { [string]: Egg } = {}
for _, egg in Eggs do
	byId[egg.Id] = egg
end

function EggsModule.get(id: string): Egg?
	return byId[id]
end

-- Every rarity a briefcase can roll, in the roster's rarity order, so the odds
-- board always lists them best-last instead of in random table order.
function EggsModule.rarityOrderFor(egg: Egg): { string }
	local ordered: { string } = {}
	for _, rarity in Interns.RarityOrder do
		if egg.Odds[rarity] ~= nil then
			table.insert(ordered, rarity)
		end
	end
	return ordered
end

-- Roll a rarity for one open. `roll` is a 0-1 number supplied by the caller so
-- the server owns randomness and this stays a pure, testable function.
function EggsModule.rollRarity(egg: Egg, roll: number): string
	local cursor = 0
	local last = "Common"
	for _, rarity in EggsModule.rarityOrderFor(egg) do
		local chance = egg.Odds[rarity]
		cursor += chance / 100
		last = rarity
		if roll <= cursor then
			return rarity
		end
	end
	-- Floating-point slop at the very top of the range lands here.
	return last
end

return EggsModule
