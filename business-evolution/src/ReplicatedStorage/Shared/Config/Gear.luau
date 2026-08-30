--!strict
-- The three parallel gear ladders (§8). Multipliers are exact from the brief;
-- base Wins costs are INVENTED (flagged in Balance.luau's header note) and sit
-- so the first keyboard is affordable after ~3-4 rival defeats.

export type GearTier = {
	Name: string,
	Value: number, -- meaning depends on the ladder (see below)
	BaseCost: number, -- Wins; actual cost = BaseCost * 1.12 ^ tiersOwnedOnLadder
	Color: { number }, -- {r,g,b} 0-255, used by shop UI and desk props
}

export type Ladder = {
	Id: string,
	DisplayName: string,
	Effect: string, -- one-liner for the shop UI
	Tiers: { GearTier },
}

local Ladders: { Ladder } = {
	{
		Id = "Keyboard",
		DisplayName = "Keyboards",
		Effect = "Multiplies Productivity per click",
		-- Value = click multiplier (brief-exact: 1.2 / 1.5 / 2 / 3 / 5)
		Tiers = {
			{ Name = "Membrane", Value = 1.2, BaseCost = 25, Color = { 190, 190, 190 } },
			{ Name = "Mechanical", Value = 1.5, BaseCost = 90, Color = { 120, 130, 150 } },
			{ Name = "Ergonomic", Value = 2, BaseCost = 300, Color = { 250, 250, 250 } },
			{ Name = "RGB", Value = 3, BaseCost = 1000, Color = { 170, 0, 255 } },
			{ Name = "Quantum", Value = 5, BaseCost = 3500, Color = { 0, 255, 200 } },
		},
	},
	{
		Id = "Chair",
		DisplayName = "Chairs",
		Effect = "Earns Productivity every second, even idle",
		-- Value = idle Productivity/sec before multipliers (INVENTED)
		Tiers = {
			{ Name = "Folding", Value = 1, BaseCost = 40, Color = { 160, 160, 160 } },
			{ Name = "Task", Value = 4, BaseCost = 150, Color = { 60, 120, 220 } },
			{ Name = "Ergonomic", Value = 12, BaseCost = 500, Color = { 40, 40, 40 } },
			{ Name = "Executive", Value = 35, BaseCost = 1600, Color = { 90, 50, 20 } },
			{ Name = "Throne", Value = 100, BaseCost = 5000, Color = { 255, 200, 0 } },
		},
	},
	{
		Id = "Coffee",
		DisplayName = "Coffee",
		Effect = "Shortens the pause between clicks",
		-- Value = cooldown multiplier applied to BaseClickCooldown (INVENTED;
		-- 20/sec server cap in Balance.luau still always applies)
		Tiers = {
			{ Name = "Instant", Value = 0.85, BaseCost = 30, Color = { 140, 100, 60 } },
			{ Name = "Drip", Value = 0.72, BaseCost = 110, Color = { 110, 75, 40 } },
			{ Name = "Espresso", Value = 0.60, BaseCost = 380, Color = { 70, 45, 25 } },
			{ Name = "Cold Brew", Value = 0.48, BaseCost = 1200, Color = { 50, 35, 25 } },
			{ Name = "Nitro", Value = 0.35, BaseCost = 4200, Color = { 30, 25, 20 } },
		},
	},
}

local GearModule = {}

GearModule.Ladders = Ladders

local byId: { [string]: Ladder } = {}
for _, ladder in Ladders do
	byId[ladder.Id] = ladder
end

function GearModule.getLadder(id: string): Ladder?
	return byId[id]
end

-- Cost of the NEXT tier on a ladder given how many tiers are already owned.
-- Returns nil when the ladder is maxed out.
function GearModule.nextTierCost(ladderId: string, owned: number): number?
	local ladder = byId[ladderId]
	if not ladder or owned >= #ladder.Tiers then
		return nil
	end
	local growth = 1.12 -- mirrored in Balance.GearCostGrowth; kept literal here so
	-- this module stays dependency-free for the offline pacing simulation
	local tier = ladder.Tiers[owned + 1]
	return math.floor(tier.BaseCost * growth ^ owned + 0.5)
end

-- Click multiplier from the owned keyboard tier (1 when none owned).
function GearModule.keyboardMultiplier(owned: number): number
	local ladder = byId.Keyboard
	local tier = ladder.Tiers[math.clamp(owned, 0, #ladder.Tiers)]
	return if owned > 0 and tier then tier.Value else 1
end

-- Idle Productivity/sec from the owned chair tier (0 when none owned).
function GearModule.chairIdleRate(owned: number): number
	local ladder = byId.Chair
	local tier = ladder.Tiers[math.clamp(owned, 0, #ladder.Tiers)]
	return if owned > 0 and tier then tier.Value else 0
end

-- Cooldown multiplier from the owned coffee tier (1 when none owned).
function GearModule.coffeeCooldownMultiplier(owned: number): number
	local ladder = byId.Coffee
	local tier = ladder.Tiers[math.clamp(owned, 0, #ladder.Tiers)]
	return if owned > 0 and tier then tier.Value else 1
end

return GearModule
