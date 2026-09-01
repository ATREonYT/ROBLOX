--!strict
-- The world: one HUB plus a line of STAGES running outward from it.
--
-- Shape copied from the genre leader (hub with training pads + shop + eggs,
-- then numbered stages you fight through), reskinned to the business theme.
-- Every stage is a visually distinct location so the walk out never reads as
-- copy-paste: a business park, then downtown, then the financial district...
--
-- Footprints follow ART Part 4.1: the starting area is ~90x90 (target 80,
-- hard cap 100) and stages are tight enough to cross in about ten seconds.
-- Shrink the ground, never the props — big props in a small space is the
-- mechanism that makes a world feel dense rather than empty.
--
-- Stage rules:
--   * You may always ENTER stage 1. Entering stage N+1 requires clearing N.
--   * "Clearing" = defeating the stage's enemy quota once.
--   * Enemy health scales per stage; RecommendedPower is the honest hint
--     printed on the entry arch so nobody wastes ten minutes on a wall.

export type Theme = {
	Ground: { number }, -- grass/asphalt/marble underfoot
	Cliff: { number }, -- the canyon walls boxing the stage in
	CliffTop: { number }, -- the grass/roof lip on top of the cliffs
	Plaza: { number }, -- tiled walkway
	Accent: { number }, -- signage + trim
	Prop: { number }, -- the stage's signature building colour
}

export type Stage = {
	Id: string,
	Number: number, -- 0 = hub
	DisplayName: string,
	Blurb: string, -- flavour on the arch
	-- Where this stage's slab is centred. Stages march out along +X.
	Origin: { number },
	Size: { number }, -- {width along X, depth along Z}
	Theme: Theme,
	-- Combat
	EnemyName: string,
	EnemyCount: number,
	EnemyHealth: number,
	EnemyPowerReward: number, -- Productivity per kill
	WinsReward: number, -- Wins for touching the 1x pad after clearing
	RecommendedPower: number,
}

local Stages: { Stage } = {
	{
		Id = "Hub",
		Number = 0,
		DisplayName = "HQ Plaza",
		Blurb = "Where every career starts.",
		Origin = { 0, 0, 0 },
		Size = { 90, 90 },
		Theme = {
			Ground = { 124, 196, 84 }, -- bright lawn
			Cliff = { 176, 106, 68 }, -- warm brick
			CliffTop = { 108, 178, 76 },
			Plaza = { 226, 228, 232 },
			Accent = { 255, 196, 40 },
			Prop = { 92, 148, 224 },
		},
		EnemyName = "",
		EnemyCount = 0,
		EnemyHealth = 0,
		EnemyPowerReward = 0,
		WinsReward = 0,
		RecommendedPower = 0,
	},
	{
		Id = "BusinessPark",
		Number = 1,
		DisplayName = "Business Park",
		Blurb = "Low-rise offices and lower expectations.",
		Origin = { 180, 0, 0 },
		Size = { 190, 150 },
		Theme = {
			Ground = { 132, 200, 90 },
			Cliff = { 176, 106, 68 },
			CliffTop = { 108, 178, 76 },
			Plaza = { 222, 224, 228 },
			Accent = { 90, 200, 255 },
			Prop = { 210, 214, 220 },
		},
		EnemyName = "Temp Worker",
		EnemyCount = 6,
		EnemyHealth = 60,
		EnemyPowerReward = 8,
		WinsReward = 1,
		RecommendedPower = 10,
	},
	{
		Id = "Downtown",
		Number = 2,
		DisplayName = "Downtown",
		Blurb = "Coffee carts, gridlock, and ambition.",
		Origin = { 405, 0, 0 },
		Size = { 190, 150 },
		Theme = {
			Ground = { 96, 98, 104 }, -- asphalt
			Cliff = { 138, 96, 84 },
			CliffTop = { 92, 150, 70 },
			Plaza = { 196, 198, 202 },
			Accent = { 255, 168, 40 },
			Prop = { 168, 92, 76 }, -- brownstone
		},
		EnemyName = "Rival Commuter",
		EnemyCount = 7,
		EnemyHealth = 220,
		EnemyPowerReward = 26,
		WinsReward = 3,
		RecommendedPower = 50,
	},
	{
		Id = "FinancialDistrict",
		Number = 3,
		DisplayName = "Financial District",
		Blurb = "Glass, marble, and other people's money.",
		Origin = { 635, 0, 0 },
		Size = { 200, 160 },
		Theme = {
			Ground = { 178, 180, 188 }, -- polished stone
			Cliff = { 120, 128, 148 },
			CliffTop = { 156, 176, 196 },
			Plaza = { 236, 238, 242 },
			Accent = { 64, 220, 160 }, -- ticker green
			Prop = { 128, 176, 214 }, -- blue glass
		},
		EnemyName = "Junior Broker",
		EnemyCount = 8,
		EnemyHealth = 900,
		EnemyPowerReward = 90,
		WinsReward = 8,
		RecommendedPower = 250,
	},
	{
		Id = "Docks",
		Number = 4,
		DisplayName = "Import Docks",
		Blurb = "Containers, cranes, and creative accounting.",
		Origin = { 870, 0, 0 },
		Size = { 200, 160 },
		Theme = {
			Ground = { 108, 112, 118 },
			Cliff = { 92, 100, 110 },
			CliffTop = { 76, 128, 112 },
			Plaza = { 152, 156, 160 },
			Accent = { 255, 120, 60 },
			Prop = { 196, 84, 64 }, -- rust-red containers
		},
		EnemyName = "Dock Foreman",
		EnemyCount = 8,
		EnemyHealth = 3600,
		EnemyPowerReward = 320,
		WinsReward = 18,
		RecommendedPower = 1200,
	},
	{
		Id = "TechCampus",
		Number = 5,
		DisplayName = "Tech Campus",
		Blurb = "Free snacks. No windows that open.",
		Origin = { 1105, 0, 0 },
		Size = { 200, 160 },
		Theme = {
			Ground = { 142, 196, 148 },
			Cliff = { 150, 158, 172 },
			CliffTop = { 118, 190, 140 },
			Plaza = { 244, 246, 248 },
			Accent = { 130, 90, 255 },
			Prop = { 92, 214, 208 },
		},
		EnemyName = "Growth Hacker",
		EnemyCount = 9,
		EnemyHealth = 14000,
		EnemyPowerReward = 1100,
		WinsReward = 40,
		RecommendedPower = 5000,
	},
	{
		Id = "Skyline",
		Number = 6,
		DisplayName = "The Skyline",
		Blurb = "Rooftops, helipads, and thin air.",
		Origin = { 1340, 0, 0 },
		Size = { 200, 160 },
		Theme = {
			Ground = { 198, 200, 206 }, -- rooftop gravel
			Cliff = { 88, 96, 118 },
			CliffTop = { 150, 160, 190 },
			Plaza = { 240, 236, 226 },
			Accent = { 255, 210, 90 },
			Prop = { 76, 92, 128 },
		},
		EnemyName = "Vice President",
		EnemyCount = 9,
		EnemyHealth = 52000,
		EnemyPowerReward = 3800,
		WinsReward = 90,
		RecommendedPower = 20000,
	},
	{
		Id = "Boardroom",
		Number = 7,
		DisplayName = "The Boardroom",
		Blurb = "Nine chairs. Eight of them are taken.",
		Origin = { 1580, 0, 0 },
		Size = { 210, 170 },
		Theme = {
			Ground = { 74, 52, 38 }, -- deep wood
			Cliff = { 58, 48, 44 },
			CliffTop = { 96, 72, 52 },
			Plaza = { 210, 186, 150 },
			Accent = { 226, 178, 66 }, -- gold
			Prop = { 122, 84, 56 },
		},
		EnemyName = "Board Member",
		EnemyCount = 10,
		EnemyHealth = 190000,
		EnemyPowerReward = 13000,
		WinsReward = 200,
		RecommendedPower = 80000,
	},
	{
		Id = "Orbital",
		Number = 8,
		DisplayName = "Orbital HQ",
		Blurb = "Synergy, at escape velocity.",
		Origin = { 1820, 0, 0 },
		Size = { 210, 170 },
		Theme = {
			Ground = { 52, 60, 78 },
			Cliff = { 38, 44, 60 },
			CliffTop = { 60, 200, 230 },
			Plaza = { 178, 190, 204 },
			Accent = { 60, 232, 255 },
			Prop = { 34, 40, 58 },
		},
		EnemyName = "Shareholder",
		EnemyCount = 10,
		EnemyHealth = 700000,
		EnemyPowerReward = 45000,
		WinsReward = 450,
		RecommendedPower = 300000,
	},
}

local StagesModule = {}

StagesModule.List = Stages

-- Touching the magenta pad instead of the yellow one pays this multiple, the
-- push-your-luck reward the reference game uses on every stage.
StagesModule.BigPadMultiplier = 10

local byId: { [string]: Stage } = {}
local byNumber: { [number]: Stage } = {}
for _, stage in Stages do
	byId[stage.Id] = stage
	byNumber[stage.Number] = stage
end

function StagesModule.get(id: string): Stage?
	return byId[id]
end

function StagesModule.byNumber(number: number): Stage?
	return byNumber[number]
end

function StagesModule.count(): number
	return #Stages - 1 -- excluding the hub
end

-- A stage is enterable once the previous one has been cleared. Stage 1 and the
-- hub are always open, so a new player is never staring at a locked door.
function StagesModule.canEnter(stageNumber: number, clearedStages: { number }): (boolean, string?)
	if stageNumber <= 1 then
		return true, nil
	end
	local previous = stageNumber - 1
	if table.find(clearedStages, previous) then
		return true, nil
	end
	local prevStage = byNumber[previous]
	local name = if prevStage then prevStage.DisplayName else ("Stage " .. previous)
	return false, ("Clear %s first"):format(name)
end

return StagesModule
