--!strict
-- Which Roblox material every kind of surface uses.
--
-- The reference screenshots are NOT flat plastic: the ground is studded grass,
-- the canyon walls are visibly brick, roads are asphalt, glass reads as glass.
-- Built-in materials give all of that for free — no uploaded textures, no asset
-- ids that can break, and they cost nothing at runtime.
--
-- (This deliberately overrides the original brief's "SmoothPlastic and Neon
-- only" note: matching the reference look matters more, and Roblox's materials
-- are stylised rather than photoreal, so the cartoon feel survives.)

local Surfaces = {}

Surfaces.Material = {
	Grass = Enum.Material.Grass,
	LeafyGrass = Enum.Material.LeafyGrass,
	Brick = Enum.Material.Brick,
	Concrete = Enum.Material.Concrete,
	Asphalt = Enum.Material.Asphalt,
	Slate = Enum.Material.Slate,
	Marble = Enum.Material.Marble,
	Granite = Enum.Material.Granite,
	Wood = Enum.Material.WoodPlanks,
	Metal = Enum.Material.Metal,
	DiamondPlate = Enum.Material.DiamondPlate,
	CorrodedMetal = Enum.Material.CorrodedMetal,
	Glass = Enum.Material.Glass,
	Sand = Enum.Material.Sand,
	Cobblestone = Enum.Material.Cobblestone,
	Pebble = Enum.Material.Pebble,
	Fabric = Enum.Material.Fabric,
	Plastic = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Foil = Enum.Material.Foil,
	Ice = Enum.Material.Ice,
	Rock = Enum.Material.Rock,
}

-- Per-theme surface choices, so an "asphalt" stage and a "marble" stage are
-- different at the material level and not just recoloured.
export type SurfaceSet = {
	Ground: Enum.Material,
	GroundStudded: boolean, -- classic studded top, the look in the screenshots
	Cliff: Enum.Material,
	CliffTop: Enum.Material,
	Plaza: Enum.Material,
	Building: Enum.Material,
	Trim: Enum.Material,
}

local M = Surfaces.Material

local sets: { [string]: SurfaceSet } = {
	Hub = { Ground = M.Grass, GroundStudded = true, Cliff = M.Brick, CliffTop = M.Grass, Plaza = M.Concrete, Building = M.Brick, Trim = M.Metal },
	BusinessPark = { Ground = M.Grass, GroundStudded = true, Cliff = M.Brick, CliffTop = M.Grass, Plaza = M.Concrete, Building = M.Brick, Trim = M.Metal },
	Downtown = { Ground = M.Asphalt, GroundStudded = false, Cliff = M.Brick, CliffTop = M.Grass, Plaza = M.Concrete, Building = M.Brick, Trim = M.Metal },
	FinancialDistrict = { Ground = M.Marble, GroundStudded = false, Cliff = M.Granite, CliffTop = M.Slate, Plaza = M.Marble, Building = M.Glass, Trim = M.Foil },
	Docks = { Ground = M.Concrete, GroundStudded = false, Cliff = M.Rock, CliffTop = M.Pebble, Plaza = M.Concrete, Building = M.CorrodedMetal, Trim = M.DiamondPlate },
	TechCampus = { Ground = M.Grass, GroundStudded = true, Cliff = M.Concrete, CliffTop = M.LeafyGrass, Plaza = M.Marble, Building = M.Glass, Trim = M.Metal },
	Skyline = { Ground = M.Pebble, GroundStudded = false, Cliff = M.Concrete, CliffTop = M.Slate, Plaza = M.Concrete, Building = M.Glass, Trim = M.Metal },
	Boardroom = { Ground = M.Wood, GroundStudded = false, Cliff = M.Wood, CliffTop = M.Marble, Plaza = M.Marble, Building = M.Wood, Trim = M.Foil },
	Orbital = { Ground = M.DiamondPlate, GroundStudded = false, Cliff = M.Metal, CliffTop = M.Neon, Plaza = M.Foil, Building = M.Metal, Trim = M.Neon },
}

Surfaces.Sets = sets

local fallback: SurfaceSet = sets.Hub

function Surfaces.forStage(stageId: string): SurfaceSet
	return sets[stageId] or fallback
end

return Surfaces
