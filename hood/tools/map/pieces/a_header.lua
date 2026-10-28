-- The Block V2: "+1 Hood Evolution", World 1, copied from the user's reference pictures:
--   the lobby hall (spawn, the 8 shooting ranges, the ARMORY)
--   stages 1-15, each the reference street (ref1_street.png): a studded asphalt road with a yellow dashed line,
--     studded sidewalks and grass, plank fences, stacked-cube trees, tall steel-blue lamps (BRIEF23 LIGHT3: lighter road and lamps so the streets read bright), two-storey red brick
--     buildings, and end buildings that close in round the next stage's wall
--   the boss yard (Champ Ring, the BOSS pad)
-- Every stage starts with a gate that needs more power than the last (V2.StagePower); every range trains in
-- the lobby. A ring road with trees and parked cars runs round the outside.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on and applies
-- the bright, slightly softened lighting (HoodLighting HoodSoft) (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). Each stage's pad is tagged HoodFightPad
-- (Fight = stage, 16 = the boss) for the fight system to come. The lobby's Morphs stand is where looks are
-- equipped; Training_<Id> stations (8 in the lobby, the Ring in the boss yard) train.
--
-- Layout (local studs, floor top at y = 0, players walk toward -Z):
--   lobby         x -67..67, z 6..157 (a warehouse; its north door opens onto stage 1)
--   stage i       x -36..36, z -(i-1)*64 .. -i*64, gate on its first line; buildings x ±36..±64 (±22 for the
--                 last 8 studs, round the next gate)
--   boss yard     x -36..36, z -960..-1056
--   ring road     outside a low wall at x ±70 (and past both ends)
local V2 = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local S = Enum.SurfaceType
local Props, PROPS_KIT, SKINS -- HoodProps (the Champ Ring), the helpers it borrows, Config.Skins: set in Build
-- Config/Features (Oct 27: the World Boss is off for now): true when the game has that feature on (on when unknown).
function V2.feature(name)
	local ok, f = pcall(function() return require(ReplicatedStorage.Shared.Config.Features) end)
	if not ok or type(f) ~= 'table' or f[name] == nil then return true end
	return f[name] == true
end

V2.Origin = CFrame.new(2400, 0, 0)
-- The map's root model name in Workspace (World 2's city assembly, tools/map/city, sets 'TheCity' and V2.World = 2)
V2.Name = 'TheBlockV2'

-- Palette, taken from the concept: bold, simple, one look per district.
local P = {
	-- Ground.
	tileA = C(206, 208, 213), tileB = C(193, 196, 202), band = C(146, 149, 156), bandLine = C(236, 236, 238),
	kerb = C(222, 222, 226), wall = C(214, 214, 218), grass = C(104, 178, 72), asphalt = C(70, 72, 78), roadLine = C(240, 240, 240),
	court = C(236, 142, 58), courtLine = C(250, 246, 236),
	-- Buildings.
	brick = C(176, 74, 58), brickDark = C(150, 64, 52), brickPink = C(198, 112, 92), slate = C(62, 68, 84), stone = C(158, 158, 164),
	tan = C(224, 184, 128), tanLight = C(238, 208, 160), tanDark = C(178, 150, 112),
	glass = C(48, 68, 100), frame = C(214, 214, 220), door = C(42, 118, 78), doorDark = C(48, 52, 62),
	barberBlue = C(38, 72, 168), groceryGreen = C(38, 148, 62), groceryYellow = C(250, 204, 48), shopBlue = C(52, 92, 196),
	warehouse = C(40, 90, 190), warehouseDark = C(30, 66, 146), rollDoor = C(72, 76, 84),
	-- Props.
	leaf = C(112, 192, 62), leafDark = C(96, 176, 52), hedge = C(80, 168, 62), trunk = C(122, 82, 52), planter = C(196, 196, 202),
	iron = C(36, 38, 44), lampGlow = C(255, 214, 120), wood = C(196, 128, 68), woodDark = C(150, 96, 52), crate = C(206, 148, 76),
	dumpster = C(44, 132, 72), black = C(28, 30, 34), white = C(250, 250, 250),
	containerRed = C(196, 52, 42), containerBlue = C(44, 96, 186),
	-- Fight pads and banners.
	padRed = C(230, 52, 52), padBlue = C(40, 104, 232), padGreen = C(44, 192, 82), bossRing = C(80, 255, 120),
	spawnBlue = C(60, 190, 255), evolveBlue = C(40, 88, 210), evolveYellow = C(252, 206, 52),
	district = { C(222, 52, 52), C(132, 62, 212), C(240, 132, 30), C(214, 116, 40), C(42, 104, 222) },
	-- The stage street, sampled from ref1_street.png (lit faces; every surface studded like the picture), then set so
	-- a render13 preview (Roblox's light model) under the game's HoodSun lighting reads the picture's RGB on the sunlit
	-- ground and facades (HoodSun v4: sun (0.50, 0.80, 0.33); vertical faces are lifted more than the picture's own
	-- Color3s would be, since this sun is higher than the picture's).
	st = {
		-- (Oct 28, the owner: "too many shades ... make this cartoony"; ref_W01's path is a light lavender stone between
		-- bright grass) the road the ref path's lavender, not a mid blue-grey; the sidewalks a paler cut of it
		road = C(172, 168, 208), dash = C(255, 243, 50), walk = C(210, 212, 232), grass = C(38, 212, 92),
		brick = C(218, 120, 80), trim = C(236, 214, 200), band = C(190, 206, 236), roof = C(92, 150, 222),
		glassA = C(162, 204, 250), glassB = C(190, 218, 243), mullion = C(44, 86, 142),
		fence = { C(229, 122, 63), C(204, 104, 66), C(229, 122, 63), C(204, 104, 66) }, -- (Oct 28: two flat tones, no dark planks)
		lamp = C(70, 128, 220), lampGlow = C(255, 244, 196),
		leaf = C(32, 250, 56), trunk = C(97, 90, 103), hedge = C(26, 196, 70), dumpster = C(14, 190, 78),
		petal = C(30, 70, 156), petalEye = C(250, 232, 70), stem = C(40, 180, 82), garbage = C(230, 130, 46),
		-- Second and third tones. (Oct 28, the owner: "there are too many shades ... remove the shades": each colour is
		-- now one flat tone, or a lighter cut of it; the darker cuts that shaded every surface are gone.)
		brickDark = C(218, 120, 80), brickDeep = C(218, 120, 80), brickLight = C(230, 140, 96), sill = C(240, 222, 212),
		trimDark = C(236, 214, 200), roofDark = C(92, 150, 222),
		gutter = C(172, 168, 208), roadDark = C(172, 168, 208), kerbStone = C(228, 230, 242), walkJoint = C(196, 198, 222),
		grassDark = C(38, 212, 92), grassEdge = C(38, 212, 92), leafDark = C(32, 250, 56), lampDark = C(70, 128, 220),
		lampLight = C(120, 168, 236), plankDark = C(192, 100, 64), dumpsterDark = C(14, 190, 78), manhole = C(150, 154, 176),
	},
	-- Its cross-section, measured from the picture (studs from the centre line, heights from the road top):
	-- road |x| < road, sidewalk to road + walk (top at kerb), grass to front, the plank fence at fence, building
	-- fronts at front; the last SLEN - endZ studs of each stage narrow to |x| = open, framing the next gate's wall.
	street = { road = 8.5, walk = 8, kerb = 0.6, front = 36, open = 22, fence = 34.5, endZ = 56, eave = 30, band = 15, sills = { 4, 19 }, winH = 8.5 },
}
