--!strict
-- The six floors of the tower. Gates are Restructure-count (or early-game rank)
-- so the whole economy can be rebalanced without ever touching this table (§3).
--
-- Origin is where the floor's geometry is centred. Floors are stacked far apart
-- vertically so each one feels like its own world and never renders into another.
-- (Numbers here are stud offsets, NOT stored in player data.)

export type FloorGate = {
	MinRank: number?, -- rank needed (early floors)
	MinRestructures: number?, -- restructure count needed (later floors)
	RequiresBossOf: string?, -- previous floor whose boss must have been beaten
}

export type Floor = {
	Id: string,
	DisplayName: string,
	FloorLabel: string, -- what the elevator panel shows: "B1", "3", "40"...
	Gate: FloorGate,
	Origin: { number }, -- {x, y, z} of the floor centre
	Tagline: string, -- flavour line on the elevator panel
}

local Floors: { Floor } = {
	{
		Id = "Mailroom",
		DisplayName = "The Mailroom",
		FloorLabel = "B1",
		Gate = {},
		Origin = { 0, 0, 0 },
		Tagline = "Where careers begin. And some end.",
	},
	{
		Id = "CubicleFarm",
		DisplayName = "Cubicle Farm",
		FloorLabel = "3",
		Gate = { MinRank = 4, RequiresBossOf = "Mailroom" },
		Origin = { 0, 512, 0 },
		Tagline = "Partitions to the horizon.",
	},
	{
		Id = "OpenPlan",
		DisplayName = "Open Plan",
		FloorLabel = "12",
		Gate = { MinRestructures = 2, RequiresBossOf = "CubicleFarm" },
		Origin = { 0, 1024, 0 },
		Tagline = "The ping-pong table is decorative.",
	},
	{
		Id = "Executive",
		DisplayName = "Executive Floor",
		FloorLabel = "40",
		Gate = { MinRestructures = 8, RequiresBossOf = "OpenPlan" },
		Origin = { 0, 1536, 0 },
		Tagline = "Glass walls. Real wood. Fake smiles.",
	},
	{
		Id = "Penthouse",
		DisplayName = "The Penthouse",
		FloorLabel = "88",
		Gate = { MinRestructures = 16, RequiresBossOf = "Executive" },
		Origin = { 0, 2200, 0 },
		Tagline = "The infinity pool is a business expense.",
	},
	{
		Id = "OrbitalHQ",
		DisplayName = "Orbital HQ",
		FloorLabel = "???",
		Gate = { MinRestructures = 30, RequiresBossOf = "Penthouse" },
		Origin = { 0, 6000, 0 },
		Tagline = "Synergy, at escape velocity.",
	},
}

local FloorsModule = {}

FloorsModule.List = Floors

local byId: { [string]: Floor } = {}
for _, floor in Floors do
	byId[floor.Id] = floor
end

function FloorsModule.get(id: string): Floor?
	return byId[id]
end

-- Single gate check used by the server (authoritative) and by the client
-- (to grey out elevator buttons). Boss progress arrives as an array of ids.
function FloorsModule.canEnter(floorId: string, rank: number, restructures: number, bossesDefeated: { string }): (boolean, string?)
	local floor = byId[floorId]
	if not floor then
		return false, "Unknown floor"
	end
	if floor.Gate.MinRank and rank < floor.Gate.MinRank then
		return false, ("Reach rank %d"):format(floor.Gate.MinRank)
	end
	if floor.Gate.MinRestructures and restructures < floor.Gate.MinRestructures then
		return false, ("%d Restructures needed"):format(floor.Gate.MinRestructures)
	end
	if floor.Gate.RequiresBossOf then
		local beaten = table.find(bossesDefeated, floor.Gate.RequiresBossOf) ~= nil
		if not beaten then
			local previous = byId[floor.Gate.RequiresBossOf]
			local name = if previous then previous.DisplayName else floor.Gate.RequiresBossOf
			return false, ("Defeat the %s boss"):format(name)
		end
	end
	return true, nil
end

return FloorsModule
