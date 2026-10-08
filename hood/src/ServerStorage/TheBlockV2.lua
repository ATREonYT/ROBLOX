-- The Block V2: "+1 Hood Evolution", World 1, built from the team's concept sheet (hoodw1), stretched so every
-- look on the sheet is three full stages:
--   the warehouse lobby (spawn, the 8 shooting ranges, the EVOLUTIONS podium, the ARMORY)
--   stages 1-3 The Block (red brick), 4-6 Shop Street (barber, grocery and more shops), 7-9 The Courts,
--   10-12 The Apartments (tan, balconies), 13-15 The Yards (warehouses, containers)
--   the boss yard (Champ Ring, the BOSS pad)
-- Every stage starts with a gate that needs more power than the last (V2.StagePower); every range trains in
-- the lobby. Buildings stand shoulder to shoulder down both sides,
-- fronts to the middle; a ring road with trees and parked cars runs round the outside.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on and applies
-- the calm warm lighting (HoodLighting HoodCalm) (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). Each stage's pad is tagged HoodFightPad
-- (Fight = stage, 16 = the boss) for the fight system to come. The lobby's Morphs stand is where looks are
-- equipped; Training_<Id> stations (8 in the lobby, the Ring in the boss yard) train.
--
-- Layout (local studs, floor top at y = 0, players walk toward -Z):
--   lobby         x -67..67, z 6..157 (a warehouse; its north door opens onto stage 1)
--   stage i       x -36..36, z -(i-1)*64 .. -i*64, gate on its first line; buildings x ±36..±64
--   boss yard     x -36..36, z -960..-1056
--   ring road     outside a low wall at x ±70 (and past both ends)
local V2 = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local S = Enum.SurfaceType
local Props, PROPS_KIT, SKINS -- HoodProps (the Champ Ring), the helpers it borrows, Config.Skins: set in Build

V2.Origin = CFrame.new(2400, 0, 0)

-- Palette: a calm, sunny hood street (research/street_palette.md, BRIEF6's lobby palette). Warm-grey paving,
-- brick, buff and cream walls, charcoal metal, wood, muted leaves; ONE muted accent per district (S <= 0.55).
-- The colour belongs to the gameplay (gates, fight pads), the signs, the cars and the players, not the walls.
local P = {
	-- Ground.
	tileA = C(204, 199, 190), tileB = C(192, 186, 176), band = C(132, 130, 128), bandLine = C(232, 226, 212),
	kerb = C(214, 208, 198), wall = C(206, 200, 190), grass = C(112, 146, 84), asphalt = C(68, 70, 74), roadLine = C(232, 226, 212),
	court = C(148, 144, 138), courtLine = C(236, 230, 216), courtSlate = C(118, 126, 134), courtTurf = C(98, 128, 88), courtKey = C(168, 98, 80),
	-- Buildings.
	brick = C(154, 102, 85), brickDark = C(134, 90, 76), brickPink = C(170, 118, 100), slate = C(60, 66, 76), stone = C(180, 174, 164),
	tan = C(206, 184, 152), tanLight = C(228, 216, 194), tanDark = C(164, 146, 122),
	glass = C(86, 100, 111), frame = C(226, 218, 204), door = C(63, 125, 110), doorDark = C(48, 52, 62),
	barberBlue = C(74, 96, 128), groceryGreen = C(63, 112, 92), groceryYellow = C(227, 169, 63), shopBlue = C(98, 114, 134),
	warehouse = C(104, 118, 134), warehouseDark = C(62, 72, 86), rollDoor = C(84, 88, 94),
	-- Props.
	leaf = C(94, 140, 74), leafDark = C(78, 120, 64), hedge = C(84, 124, 68), trunk = C(110, 84, 64), planter = C(190, 184, 174),
	iron = C(40, 43, 48), lampGlow = C(255, 227, 179), wood = C(165, 122, 88), woodDark = C(126, 92, 66), crate = C(176, 138, 100),
	dumpster = C(58, 96, 80), black = C(28, 30, 34), white = C(250, 250, 250),
	containerRed = C(128, 62, 54), containerBlue = C(78, 98, 120), containerTeal = C(63, 112, 100), containerCream = C(214, 204, 186),
	-- Sign system (one for the whole map): charcoal boards with cream text, or cream boards with charcoal text;
	-- gold only for the key word; charcoal steel for frames, posts and kerbs.
	ink = C(43, 47, 54), cream = C(240, 232, 216), gold = C(227, 169, 63), metal = C(60, 66, 76), oxblood = C(150, 62, 60),
	-- Gameplay markers: muted, still the most saturated things on the street (S <= 0.6).
	padRed = C(200, 96, 84), padBlue = C(86, 126, 178), padGreen = C(80, 160, 112), bossRing = C(214, 118, 100),
	spawnBlue = C(96, 150, 180), evolveBlue = C(74, 96, 128), evolveYellow = C(227, 169, 63),
	-- One accent per district: brick red, dusty violet, teal, amber, slate blue (neighbours >= 95 degrees apart).
	district = { C(160, 84, 74), C(122, 96, 148), C(60, 128, 118), C(196, 153, 90), C(84, 110, 150) },
}
---------------------------------------------------------------------------------------------- build context
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, cf) return setmetatable({ parent = parent, cf = cf }, Ctx) end
function Ctx:at(cf) return newCtx(self.parent, self.cf * cf) end
function Ctx:into(parent) return newCtx(parent, self.cf) end
function Ctx:group(name, class)
	local g = Instance.new(class or 'Model')
	g.Name = name
	g.Parent = self.parent
	return newCtx(g, self.cf), g
end
function Ctx:world(cf) return V2.Origin * self.cf * cf end
local function smooth(p)
	for _, face in { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' } do p[face] = S.Smooth end
end
function Ctx:part(name, size, cf, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	if shape then p.Shape = shape end
	p.Parent = self.parent
	return p
end
-- Axis-aligned box between two corners (in this context's frame).
function Ctx:box(name, a, b, color, material)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end
-- Upright cylinder standing on pos.
function Ctx:post(name, radius, height, pos, color, material)
	return self:part(name, V(height, radius * 2, radius * 2), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Cylinder lying along the X axis of cf.
function Ctx:rod(name, radius, length, cf, color, material)
	return self:part(name, V(length, radius * 2, radius * 2), cf, color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Square bar from a to b.
function Ctx:bar(name, a, b, width, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	return self:part(name, V(width, width, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material or M.Metal)
end
function Ctx:blob(name, size, pos, color, material)
	local p = self:part(name, size, CFrame.new(pos), color, material)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Ctx:wedge(name, size, cf, color, material)
	local p = Instance.new('WedgePart')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	p.Parent = self.parent
	return p
end

-- Classic Roblox studs on the top (and optionally the sides) of a part.
local function studs(p, sides)
	p.Material = M.Plastic
	p.TopSurface = S.Studs
	if sides then
		p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = S.Studs, S.Studs, S.Studs, S.Studs
	end
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end
local function ghost(p)
	decor(p).Transparency = 1
	return p
end
local function light(p, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
	return l
end

---------------------------------------------------------------------------------------------- text
local FONT = { title = Enum.Font.FredokaOne, loud = Enum.Font.LuckiestGuy, body = Enum.Font.GothamBlack, tag = Enum.Font.PermanentMarker }
local function surface(p, face, ppS)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 0
	g.Parent = p
	return g
end
-- One line of text in a band of the gui (y and h are 0-1), with a clean outline.
local function line(gui, name, value, color, font, y, h, outline, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Font = font
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextStrokeTransparency = 1
	if outline then
		local s = Instance.new('UIStroke')
		s.Color = outline
		s.Thickness = thickness or 2
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	t.Parent = gui
	return t
end
local function billboard(ctx, pos, w, h, rows)
	local a = ghost(ctx:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.Parent = a
	for _, r in rows do line(g, r[1], r[2], r[3], r[4], r[5], r[6], P.black, 2) end
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

---------------------------------------------------------------------------------------------- layout
local FRONT = 36 -- building fronts at x = ±36, facing the middle
local DEPTH = 28 -- buildings run back to x = ±64
local WALL_X = 70 -- the low boundary wall
local SLEN = 64 -- one stage
local STAGES = 15
local SPAWN_W, SPAWN_TOP = 67, 157 -- the warehouse lobby's outside walls: x -67..67, z 5..157 (Lobby, e2_lobby)
local BOSS_TOP = -STAGES * SLEN -- -960
local BOSS_END = BOSS_TOP - 96 -- the boss yard runs to -1056
local SPAWN = V(0, 0, 66) -- the spawn badge where the lobby hall's walkways cross (on the floor)
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end -- 1..5: three stages share a look
local function trioOf(i) return (i - 1) % 3 + 1 end -- 1..3: place within the look
local function gateZ(i) return stageTop(i) end -- gate i opens stage i (16 opens the boss yard)
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each stage, and into the boss yard (16). Each step is a bit harder than the last. Every
-- bag trains in the lobby (the Champ Ring is in the boss yard), so players come back between pushes.
local STAGE_POWER = { 10, 30, 60, 150, 300, 500, 750, 1000, 1800, 3000, 5000, 8000, 12500, 20000, 32000, 50000 }
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop

-- Every stage's pad in walking order, then the boss: the fight system can read them straight from here.
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
table.insert(V2.Fights, { Fight = 16, Stage = 16, Look = 6, X = 0, Z = BOSS_END + 22, Boss = true })
---------------------------------------------------------------------------------------------- asset kit
-- The concept's "Asset Kit (simple Roblox parts)". All positions are in the given context's frame.
local function plank(c, name, a, b, width, thick, color, material)
	return c:part(name, V(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or M.SmoothPlastic)
end

-- Low-poly tree: a brown trunk under a faceted crown (two cubes turned against each other), standing in a
-- concrete planter with a hedge top.
local function tree(c, pos, seed, scale)
	scale = scale or 1
	local r = Random.new(seed)
	local s = scale
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0)):group('Tree')
	t:box('Planter', V(-2.6, 0, -2.6), V(2.6, 1, 2.6), P.planter, M.Concrete)
	t:box('PlanterHedge', V(-2.2, 1, -2.2), V(2.2, 2, 2.2), P.hedge, M.Grass)
	t:box('Trunk', V(-0.6 * s, 1, -0.6 * s), V(0.6 * s, 7.5 * s, 0.6 * s), P.trunk, M.Wood)
	local y = 7 * s + 3.4 * s
	local k = r:NextNumber(0, 1)
	t:part('Crown', V(7, 6.4, 7) * s, CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(45), 0), P.leaf:Lerp(P.leafDark, k * 0.5), M.SmoothPlastic)
	t:part('Crown', V(6.2, 6.2, 6.2) * s, CFrame.new(0, y + 0.6 * s, 0) * CFrame.Angles(math.rad(38), math.rad(20), math.rad(34)), P.leaf:Lerp(P.leafDark, 0.6), M.SmoothPlastic)
	t:part('Crown', V(4.6, 4.6, 4.6) * s, CFrame.new(0, y + 2.6 * s, 0) * CFrame.Angles(math.rad(20), math.rad(60), math.rad(-25)), P.leaf, M.SmoothPlastic)
	return t
end
-- Hedge on a concrete curb, along the frame's X axis.
local function hedge(c, x0, x1, z, height)
	height = height or 2
	local h = c:group('Hedge')
	h:box('HedgeCurb', V(x0, 0, z - 1.4), V(x1, 0.6, z + 1.4), P.planter, M.Concrete)
	h:box('Hedge', V(x0 + 0.2, 0.6, z - 1.1), V(x1 - 0.2, 0.6 + height, z + 1.1), P.hedge, M.Grass)
	return h
end
-- Same, along Z.
local function hedgeZ(c, x, z0, z1, height)
	height = height or 2
	local h = c:group('Hedge')
	h:box('HedgeCurb', V(x - 1.4, 0, z0), V(x + 1.4, 0.6, z1), P.planter, M.Concrete)
	h:box('Hedge', V(x - 1.1, 0.6, z0 + 0.2), V(x + 1.1, 0.6 + height, z1 - 0.2), P.hedge, M.Grass)
	return h
end
-- Black lantern street lamp with a warm glass.
local function lantern(c, pos)
	local l = c:group('Lamp')
	l:box('LampBase', pos + V(-0.7, 0, -0.7), pos + V(0.7, 0.8, 0.7), P.iron, M.Metal)
	l:post('LampPole', 0.22, 8.4, pos + V(0, 0.8, 0), P.iron, M.Metal)
	l:box('LampCollar', pos + V(-0.5, 9.0, -0.5), pos + V(0.5, 9.4, 0.5), P.iron, M.Metal)
	l:box('LampFrame', pos + V(-0.75, 9.4, -0.75), pos + V(0.75, 11.2, 0.75), P.iron, M.Metal)
	local glass = decor(l:box('LampGlass', pos + V(-0.8, 9.6, -0.6), pos + V(0.8, 11.0, 0.6), P.lampGlow, M.Neon))
	decor(l:box('LampGlass', pos + V(-0.6, 9.6, -0.8), pos + V(0.6, 11.0, 0.8), P.lampGlow, M.Neon))
	l:box('LampCap', pos + V(-0.95, 11.2, -0.95), pos + V(0.95, 11.6, 0.95), P.iron, M.Metal)
	l:box('LampTop', pos + V(-0.4, 11.6, -0.4), pos + V(0.4, 12.1, 0.4), P.iron, M.Metal)
	light(glass, P.lampGlow, 0.8, 14)
	return l
end
local function bench(c, pos, facing)
	local b = c:at(CFrame.lookAt(pos, pos + facing)):group('Bench')
	for _, x in { -2.4, 2.4 } do
		b:box('BenchLeg', V(x - 0.2, 0, -0.8), V(x + 0.2, 1.5, 0.8), P.iron, M.Metal)
		b:box('BenchBackPost', V(x - 0.2, 1.5, 0.6), V(x + 0.2, 3.4, 0.8), P.iron, M.Metal)
	end
	for k = -1, 1 do b:box('BenchSlat', V(-3, 1.5, k * 0.52 - 0.22), V(3, 1.72, k * 0.52 + 0.22), P.wood, M.WoodPlanks) end
	for k = 0, 1 do b:box('BenchBackSlat', V(-3, 2.2 + k * 0.6, 0.8), V(3, 2.6 + k * 0.6, 1.0), P.wood, M.WoodPlanks) end
	return b
end
local function trashCan(c, pos)
	local t = c:group('TrashCan')
	t:post('Can', 0.9, 2.6, pos, C(64, 68, 76), M.Metal)
	t:post('CanLid', 0.98, 0.25, pos + V(0, 2.6, 0), P.black, M.Metal)
	return t
end
local function trashBags(c, pos)
	local t = c:group('TrashBags')
	t:blob('TrashBag', V(2.2, 1.9, 2.2), pos + V(0, 0.95, 0), P.black, M.SmoothPlastic)
	t:blob('TrashBag', V(1.8, 1.6, 1.8), pos + V(1.4, 0.8, 0.9), P.black, M.SmoothPlastic)
	t:blob('TrashBag', V(1.9, 1.7, 1.9), pos + V(0.5, 2.2, 0.4), P.black, M.SmoothPlastic)
	return t
end
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	d:box('DumpsterBody', V(-3, 0.5, -2), V(3, 4, 2), P.dumpster, M.Metal)
	d:box('DumpsterLid', V(-3.15, 4, -2.15), V(3.15, 4.4, 2.15), P.black, M.Plastic)
	d:box('DumpsterLip', V(-3.1, 3.2, -2.2), V(3.1, 3.5, 2.2), P.dumpster:Lerp(P.black, 0.25), M.Metal)
	for _, x in { -2.4, 2.4 } do for _, z in { -1.5, 1.5 } do d:part('Caster', V(0.3, 0.5, 0.5), CFrame.new(x, 0.25, z), P.black, M.Metal, Enum.PartType.Cylinder) end end
	return d
end
-- Wooden crate with darker edge planks; pallets for under them.
local function crate(c, cf, size)
	size = size or 3
	local h = size / 2
	local k = c:at(cf):group('Crate')
	k:box('Crate', V(-h, 0, -h), V(h, size, h), P.crate, M.WoodPlanks)
	for _, y in { 0.15, size - 0.45 } do k:box('CrateBand', V(-h - 0.05, y, -h - 0.05), V(h + 0.05, y + 0.3, h + 0.05), P.woodDark, M.Wood) end
	for _, x in { -h - 0.05, h - 0.25 } do k:box('CrateEdge', V(x, 0, -h - 0.05), V(x + 0.3, size, -h + 0.25), P.woodDark, M.Wood) end
	return k
end
local function pallet(c, cf)
	local p = c:at(cf):group('Pallet')
	for _, x in { -1.6, 0, 1.6 } do p:box('PalletBlock', V(x - 0.3, 0, -1.6), V(x + 0.3, 0.5, 1.6), P.woodDark, M.Wood) end
	for z = -1.6, 1.6, 0.8 do p:box('PalletSlat', V(-2, 0.5, z - 0.3), V(2, 0.8, z + 0.3), P.crate, M.WoodPlanks) end
	return p
end
-- Shipping container (19.6 long along local Z) with ridges down both long sides and door bars at one end.
local function container(c, cf, color)
	local k = c:at(cf):group('Container')
	k:box('ContainerBody', V(-4, 0, -9.8), V(4, 8.6, 9.8), color, M.SmoothPlastic)
	for z = -8, 8.1, 3.2 do
		for _, x in { -4.15, 4 } do k:box('ContainerRidge', V(x, 0.4, z - 0.4), V(x + 0.15, 8.2, z + 0.4), color:Lerp(P.black, 0.15), M.SmoothPlastic) end
	end
	k:box('ContainerTopRim', V(-4.1, 8.4, -9.85), V(4.1, 8.7, 9.85), color:Lerp(P.black, 0.2), M.SmoothPlastic)
	for _, x in { -1.4, 1.4 } do k:box('ContainerDoorBar', V(x - 0.12, 0.6, 9.8), V(x + 0.12, 8, 9.95), color:Lerp(P.black, 0.3), M.SmoothPlastic) end
	return k
end
-- Low-poly sedan (front toward -Z).
local function car(c, cf, color)
	local k = c:at(cf):group('Car')
	for _, x in { -2.1, 2.1 } do
		for _, z in { -3.3, 3.3 } do
			k:part('Wheel', V(0.8, 2, 2), CFrame.new(x, 1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(k:part('Hubcap', V(0.84, 1, 1), CFrame.new(x, 1, z), P.frame, M.Metal, Enum.PartType.Cylinder))
		end
	end
	k:box('CarBody', V(-2.3, 1, -5.2), V(2.3, 2.9, 5.2), color, M.SmoothPlastic)
	k:box('CarCabin', V(-2.0, 2.9, -2.0), V(2.0, 4.6, 2.8), color, M.SmoothPlastic)
	decor(k:box('CarGlass', V(-2.05, 3.1, -2.05), V(2.05, 4.4, 2.85), P.glass, M.SmoothPlastic))
	for _, z in { -5.4, 5.1 } do k:box('Bumper', V(-2.35, 0.9, z), V(2.35, 1.6, z + 0.3), P.frame, M.Metal) end
	for _, x in { -1.9, 1.0 } do
		decor(k:box('Headlight', V(x, 2.1, -5.25), V(x + 0.9, 2.6, -5.2), C(255, 244, 200), M.Neon))
		decor(k:box('TailLight', V(x, 2.1, 5.2), V(x + 0.9, 2.6, 5.25), C(178, 64, 58), M.SmoothPlastic))
	end
	return k
end
-- Chain-link fence along a straight line, with optional gaps { from, to } (distance along the line).
local function chainLink(c, a, b, h, gaps)
	local dir = b - a
	local len = dir.Magnitude
	local u = dir.Unit
	local n = math.max(1, math.ceil(len / 8))
	local posts = {}
	for k = 0, n do
		local t = len * k / n
		local open = false
		for _, g in gaps or {} do if t > g[1] - 1 and t < g[2] + 1 then open = true end end
		if not open then table.insert(posts, t) end
	end
	for _, g in gaps or {} do table.insert(posts, g[1]); table.insert(posts, g[2]) end
	for _, t in posts do c:post('FencePost', 0.25, h + 0.2, a + u * t, P.iron, M.Metal) end
	local pieces = { { 0, len } }
	for _, g in gaps or {} do
		local nextPieces = {}
		for _, p in pieces do
			if g[2] <= p[1] or g[1] >= p[2] then table.insert(nextPieces, p)
			else
				if g[1] > p[1] then table.insert(nextPieces, { p[1], g[1] }) end
				if g[2] < p[2] then table.insert(nextPieces, { g[2], p[2] }) end
			end
		end
		pieces = nextPieces
	end
	for _, p in pieces do
		if p[2] - p[1] > 0.3 then
			local p0, p1 = a + u * p[1], a + u * p[2]
			local mid, up = (p0 + p1) / 2, V(0, (h - 0.4) / 2 + 0.2, 0)
			local mesh = c:part('ChainLink', V(0.1, h - 0.4, (p1 - p0).Magnitude), CFrame.lookAt(mid + up, p1 + up), C(70, 74, 82), M.DiamondPlate)
		mesh.Name = 'ChainLink'
			mesh.Transparency = 0.45
			mesh.CastShadow = false
			decor(plank(c, 'FenceRail', p0 + V(0, h, 0), p1 + V(0, h, 0), 0.25, 0.25, P.iron, M.Metal))
		end
	end
end
-- Short black railing (the decorative metal fences in the concept).
local function railing(c, a, b, h)
	local dir = b - a
	local u = dir.Unit
	local g = c:group('Railing')
	decor(plank(g, 'RailTop', a + V(0, h, 0), b + V(0, h, 0), 0.3, 0.3, P.iron, M.Metal))
	decor(plank(g, 'RailMid', a + V(0, h * 0.35, 0), b + V(0, h * 0.35, 0), 0.2, 0.2, P.iron, M.Metal))
	for t = 0, dir.Magnitude, 0.9 do
		local p = a + u * t
		g:box('RailBar', p + V(-0.09, 0, -0.09), p + V(0.09, h, 0.09), P.iron, M.Metal)
	end
	for _, p in { a, b } do g:box('RailPost', p + V(-0.3, 0, -0.3), p + V(0.3, h + 0.5, 0.3), P.iron, M.Metal) end
	return g
end

-- Fight pad: a framed stone plinth (charcoal kerb, stone step, warm stone top) with a thin ring in the stage's
-- colour set into the top and its number in charcoal: the colour is a line, not a glowing square.
local function fightPad(c, n, pos, color, district, size, label)
	size = size or PAD_SIZE
	local h = size / 2
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	pad:box('PadBorder', V(-h - 0.6, 0, -h - 0.6), V(h + 0.6, 0.3, h + 0.6), C(60, 66, 76), M.Metal)
	pad:box('PadStep', V(-h - 0.2, 0.3, -h - 0.2), V(h + 0.2, 0.5, h + 0.2), C(169, 161, 148), M.Concrete)
	local top = pad:box('Pad', V(-h + 0.2, 0.5, -h + 0.2), V(h - 0.2, 0.7, h - 0.2), C(214, 206, 192), M.SmoothPlastic)
	-- The ring: four thin strips just inside the top's edge (PadGlow keeps the old name for the clients).
	local r, t = h - 1.1, 0.5
	for _, e in { { V(-r, 0, -r), V(r, 0, -r + t) }, { V(-r, 0, r - t), V(r, 0, r) }, { V(-r, 0, -r + t), V(-r + t, 0, r - t) }, { V(r - t, 0, -r + t), V(r, 0, r - t) } } do
		decor(pad:box('PadGlow', e[1] + V(0, 0.7, 0), e[2] + V(0, 0.76, 0), color, M.Neon)).CastShadow = false
	end
	-- Corner posts like a boxing ring's, capped in the stage colour, so the pad reads from down the street.
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local p = V(cx * (h + 0.25), 0.3, cz * (h + 0.25))
			decor(pad:box('PadPost', p + V(-0.3, 0, -0.3), p + V(0.3, 1.9, 0.3), C(60, 66, 76), M.Metal))
			decor(pad:box('PadPostCap', p + V(-0.38, 1.9, -0.38), p + V(0.38, 2.3, 0.38), color, M.SmoothPlastic))
		end
	end
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), C(43, 47, 54), FONT.loud, 0.24, 0.52)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color:Lerp(P.white, 0.5), 0.5, 8, 120
	glow.Parent = top
	model:SetAttribute('Fight', n)
	model:SetAttribute('District', district)
	model:AddTag('HoodFightPad')
	return model, pad
end
-- District banner: a solid coloured sign floating over the walk, readable from both sides.
local function banner(c, text, pos, color, w)
	w = w or 24
	local b = c:at(CFrame.new(pos)):group('DistrictBanner')
	local sign = b:box('Banner', V(-w / 2, 0, -0.8), V(w / 2, 7, 0.8), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local g = surface(sign, face, 20)
		pcall(function() g.MaxDistance = 80 end) -- (a stage ahead at most, so banners don't stack through the lobby door)
		line(g, 'Title', text, P.white, FONT.loud, 0.1, 0.8, color:Lerp(P.black, 0.55), 5)
	end
	return b
end

-- Teleport pad (the gates' LOBBY and FURTHEST pads; StageService handles targets 'Lobby' and 'Furthest'): a neutral
-- round plinth (BRIEF6) - a charcoal base with a chamfer step, a thin low-glow ring in the destination's accent
-- (teal back to the lobby, gold on to the furthest stage) and a cream disc - with its label floating over it.
-- `color` is ignored (the pads were loud tiles); "SPAWN" reads "LOBBY".
local function teleportPad(g, name, x, z, color, target, label)
	if label == 'SPAWN' then label = 'LOBBY' end
	local ring = target == 'Lobby' and C(120, 196, 176) or C(255, 194, 77)
	local function disc(n, d, h, y, c3, mat)
		return g:part(n, V(h, d, d), CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), c3, mat or M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local pad = disc(name, 7, 0.35, 0, C(60, 66, 76))
	disc(name .. 'Step', 6.4, 0.15, 0.35, C(98, 104, 114))
	decor(disc(name .. 'Glow', 5.6, 0.02, 0.5, ring, M.Neon)).CastShadow = false
	decor(disc(name .. 'Disc', 5.0, 0.035, 0.5, C(229, 220, 203))).CastShadow = false
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'Teleport'
	prompt.ActionText = 'Teleport'
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', target)
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	billboard(g, V(x, 3.2, z), 6, 1.4, { { 'Title', label, C(242, 234, 216), FONT.title, 0, 1 } }).WorldLabel.MaxDistance = 50
	return pad
end
---------------------------------------------------------------------------------------------- training stations
-- Shooting-range lanes (the game trains with guns). Each lane keeps the bag stations' frame and themes: a long
-- flat studded mat (7 x 18) in a low two-tone rim with stepped pixel corners and a stamped row of X's on the
-- aisle face. The aisle end of the mat is the shooter's box (the TrainingZone); a waist-high bench marks the
-- firing line; the targets stand in the far half in front of a backstop at the outer end, and from tier 3 a
-- grooved truss gantry (the old gallows' truss) spans the lane over them. Every tier keeps its theme and its
-- effects and adds one new thing, so each lane reads as better than the last:
--   1 stone   soda bottles and cans on a plank shelf, a plank backstop with a painted bullseye, bunting
--   2 red     three bullseye boards on easels, a navy board with red trim (rain behind the boards)
--   3 lava    hot plates swinging from a truss gantry, burning barrels, a basalt berm with lava cracks (fire)
--   4 arcane  a spinner disc, balloons to pop, a violet starburst wall (comets above the targets)
--   5 shadow  dark plates with violet neon rims, neon on the gantry, an obsidian wall with a neon ring
--   6 frost   ice blocks and an ice bullseye, an ice-block wall with icicles, ice-blue neon (snow, sparkles)
--   7 toxic   a toxic barrel stack with a target face, green bottles, a container wall with hazard stripes
--   8 gold    a big gold gong on crimson velvet, golden neon, a turning crown, a velvet VIP bench (glints)
-- Every main target's centre sits ~5.8 over the mat, above the shooter's head from the follow camera.
-- Cartoon targets only: bottles, cans, bullseyes, plates, balloons, ice, barrels. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~11.5,
-- labels float to ~16. opts.vfx = false skips effects, opts.tier overrides the tier (opts.side is ignored).
-- Contract (Lobby.client, Shoot.client, LobbyRules): Training_<Id> > TrainingZone (the shooter's box,
-- invisible), Equipment > Targets > Target<i> (Hinge = the pivot part, Swing = the parts that move; attributes
-- Knock = Tip | Swing | Spin | Pop | Shatter | Fly, Hit = the sound it makes, ShardColor, Aim = world centre
-- where shots land, Main on the HitPoint target),
-- Equipment > Gear (stands, fence, gantry), Sign (BillboardGui with Chip + TextLabels Cost, Detail, Power),
-- attributes Tier, HitPoint (the main target's centre), HitColor. Equipment has no Hinge of its own, so
-- nothing sways while you stand there: Shoot.client knocks each target back when a shot lands on it.
local Stations = {}

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (stamped band, studded lip); mat: the inset surface;
-- frame (+frameMat): bench, gantry and stands; groove: the stamped X's colour (nil = a darker shade of the face);
-- trim: the bench band; text: the "xN Power" colour; glow: hit sparks; edge: a thin neon line inside the rim
-- (shadow); labelLift: the label stack sits this much higher (gold's crown).
-- The calm pass (BRIEF6): the structure is neutral and climbs by material, not hue (concrete and wood, then
-- charcoal steel, black steel, brass); mats stay at or under 50% saturation; the theme colour lives on the
-- targets and the effects; the "xN Power" text follows the lobby's plaque ramp (bronze, silver, gold, diamond).
Stations.Kit = {
	concrete = C(150, 144, 134), concreteLight = C(189, 181, 168), cream = C(229, 220, 203),
	steel = C(60, 66, 76), steelLight = C(92, 98, 108), black = C(38, 41, 48), blackLight = C(62, 64, 74),
	wood = C(165, 122, 88), walnut = C(96, 68, 48), brass = C(160, 124, 66), brassLight = C(212, 176, 108),
	oxblood = C(110, 43, 43), muted = C(216, 180, 74), -- (#D8B44A: the only yellow, on real edges)
	bronze = C(205, 150, 104), silver = C(206, 212, 220), gold = C(232, 182, 80), diamond = C(176, 222, 236),
}
Stations.Themes = {
	{ name = 'stone', rim = Stations.Kit.concrete, rimTop = Stations.Kit.concreteLight, mat = C(120, 128, 146), frame = Stations.Kit.wood, trim = Stations.Kit.wood:Lerp(C(0, 0, 0), 0.2),
		text = Stations.Kit.bronze, glow = C(255, 236, 200) },
	{ name = 'red', rim = Stations.Kit.concrete, rimTop = Stations.Kit.concreteLight, mat = C(164, 102, 98), frame = Stations.Kit.steel, trim = Stations.Kit.wood,
		text = Stations.Kit.bronze, glow = C(236, 120, 120) },
	{ name = 'lava', rim = Stations.Kit.steel, rimTop = Stations.Kit.steelLight, mat = C(148, 96, 78), frame = Stations.Kit.steel, groove = C(40, 44, 52), trim = Stations.Kit.steelLight,
		text = Stations.Kit.silver, glow = C(240, 140, 70) },
	{ name = 'arcane', rim = Stations.Kit.steel, rimTop = Stations.Kit.steelLight, mat = C(126, 108, 140), frame = Stations.Kit.steel, groove = C(40, 44, 52), trim = Stations.Kit.steelLight,
		text = Stations.Kit.silver, glow = C(220, 160, 230) },
	{ name = 'shadow', rim = Stations.Kit.black, rimTop = Stations.Kit.blackLight, mat = C(54, 50, 64), frame = Stations.Kit.black, trim = Stations.Kit.blackLight,
		text = Stations.Kit.gold, glow = C(170, 150, 230), edge = C(96, 80, 140) },
	{ name = 'frost', rim = Stations.Kit.black, rimTop = C(176, 184, 190), mat = C(184, 202, 208), matMat = M.SmoothPlastic, frame = Stations.Kit.steel, trim = C(176, 184, 190),
		groove = C(150, 172, 186), text = Stations.Kit.gold, glow = C(180, 220, 240) },
	{ name = 'toxic', rim = Stations.Kit.black, rimTop = Stations.Kit.steelLight, mat = C(58, 74, 68), frame = Stations.Kit.steel, groove = C(40, 44, 52), trim = Stations.Kit.brass,
		text = Stations.Kit.diamond, glow = C(160, 210, 130) },
	{ name = 'gold', rim = Stations.Kit.brass, rimTop = Stations.Kit.brassLight, mat = C(204, 186, 148), frame = Stations.Kit.walnut, groove = C(120, 92, 50),
		trim = Stations.Kit.oxblood, text = Stations.Kit.diamond, glow = C(255, 222, 130), labelLift = 0.3 },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.BOX_Z = -3.2 -- the shooter's box runs from the aisle end to here
Stations.BENCH_Z = -2.75 -- the bench's centre line (it is 0.9 deep)
Stations.BENCH_H = 2.3 -- bench top over the mat: waist height, under the held gun
Stations.FIELD_Z0, Stations.FIELD_Z1 = -1.9, 8.4 -- the target field (effects fill it)
Stations.BACK_Z = 8.5 -- the backstop's front face
Stations.GANTRY_Z = 6.4 -- the gantry's centre line (hanging targets hang from it)
Stations.GANTRY_Y = 8.6 -- underside of the gantry beam
Stations.LABEL = V(0, 13.8, 3.6) -- the label stack, over the target field
Stations.StampId = '' -- set from HoodVFX.Textures.stamp at build time ('' until the PNG is uploaded)

---------------------------------------------------------------------------------------------- stamp and X
-- The groove colour on a face: the theme's own, or the face colour darkened (critic: grooves keep the face's
-- hue, so gold stays lemon and never turns olive).
function Stations.grooveFor(t, base) return t.groove or base:Lerp(C(0, 0, 0), 0.45) end

-- The reference's embossed X on a block face: a Texture tiled every su x sv studs (one X per panel). stamp.png
-- draws the groove in white and Color3 tints it. With no uploaded id the Texture draws nothing in Studio; the
-- offline renderer draws hood/art/vfx/stamp.png (PreviewTexture), and barX cuts the X in geometry meanwhile.
function Stations.stamp(part, faces, su, sv, tint, alpha)
	for _, face in faces do
		local t = Instance.new('Texture')
		t.Name = 'Stamp'
		t.Face = face
		t.Texture = Stations.StampId
		t.StudsPerTileU, t.StudsPerTileV = su or 2, sv or 2
		t.Transparency = 1 - (alpha or 1)
		t.Color3 = tint or part.Color:Lerp(C(0, 0, 0), 0.45)
		t:SetAttribute('PreviewTexture', 'stamp')
		t.Parent = part
	end
end
Stations.SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Before stamp.png is uploaded a Texture draws nothing, so the X is cut in geometry on the faces players see
-- most (the rim's aisle face, the bench front, the backstop front): two thin bars per X, 0.02 proud, in the
-- groove colour. Skipped once the id is set. `cf` is the face centre with -Z out of the face; w x h is one X.
function Stations.barX(c, cf, w, h, color)
	local ang, L = math.atan2(w, h), math.sqrt(w * w + h * h) - 0.08
	for _, dir in { -1, 1 } do
		decor(c:part('StampBar', V(0.12, L, 0.04), cf * CFrame.new(0, 0, -0.01) * CFrame.Angles(0, 0, dir * ang), color, M.SmoothPlastic)).CastShadow = false
	end
end
-- n X's side by side across a face `w` wide and `h` tall centred on `cf` (stamp + geometry fallback).
function Stations.panelX(c, part, cf, w, h, n, tint)
	Stations.stamp(part, { Enum.NormalId.Front }, w / n, h, tint)
	if Stations.StampId == '' then
		for k = 0, n - 1 do Stations.barX(c, cf * CFrame.new(-w / 2 + (k + 0.5) * w / n, 0, 0), w / n - 0.12, h - 0.12, tint) end
	end
end

-- A truss beam along the local +Y of `cf` (cf = centre of the base), len long, w x d thick: a solid beam in the
-- frame colour with thin grooves 0.02 proud (a tie line every `cell` studs and an X in every cell) on the faces
-- listed ('-x', '+x', '-z', '+z' in cf's frame), so from a distance it reads as one solid block.
function Stations.truss(c, name, cf, len, w, d, color, groove, cell, faces, material)
	c:part(name .. 'Core', V(w, len, d), cf * CFrame.new(0, len / 2, 0), color, material)
	local n = math.max(1, math.floor(len / cell + 0.5))
	local seg, g = len / n, 0.12
	for _, f in faces do
		local onX = f:sub(2) == 'x'
		local s = f:sub(1, 1) == '-' and -1 or 1
		local span = (onX and d or w) - 0.24 -- grooves stop short of the corners
		local off = (onX and w or d) / 2 + 0.01
		local L = math.sqrt(span * span + seg * seg)
		local ang = math.atan2(span, seg)
		for k = 0, n do
			local y = math.clamp(k * seg, g / 2 + 0.05, len - g / 2 - 0.05)
			c:part(name .. 'Tie', onX and V(0.04, g, span) or V(span, g, 0.04), cf * CFrame.new(onX and s * off or 0, y, onX and 0 or s * off), groove)
		end
		for k = 0, n - 1 do
			for _, dir in { -1, 1 } do
				local at = CFrame.new(onX and s * off or 0, (k + 0.5) * seg, onX and 0 or s * off)
				local turn = onX and CFrame.Angles(dir * ang, 0, 0) or CFrame.Angles(0, 0, dir * ang)
				c:part(name .. 'Groove', onX and V(0.04, L, g) or V(g, L, 0.04), cf * at * turn, groove)
			end
		end
	end
end

---------------------------------------------------------------------------------------------- shapes
-- Round disc facing -Z (a cylinder lying along the frame's Z): centre `cf`, radius r, thickness th.
function Stations.disc(c, name, cf, r, th, color, material)
	return c:part(name, V(th, 2 * r, 2 * r), cf * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Upright cylinder standing on `pos`.
function Stations.can(c, name, pos, r, h, color, material)
	return c:part(name, V(h, 2 * r, 2 * r), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Bullseye whose back sits on the plane z = 0 of `cf` (facing -Z): rings outer to inner from `colors`, each a
-- little prouder than the last so no two share a face. Returns the outer ring.
function Stations.bullseye(c, cf, r, colors, material)
	local n, outer = #colors, nil
	for i, col in colors do
		local th = 0.08 + 0.035 * i
		local p = Stations.disc(c, 'Ring', cf * CFrame.new(0, 0, 0.02 - th / 2), r * (n - i + 1) / n, th, col, type(material) == 'table' and material[i] or material)
		outer = outer or p
	end
	return outer
end
-- Two squares turned 45 degrees: an eight-point starburst facing -Z, centred on `cf`.
function Stations.starburst(c, cf, s, th, color, material)
	c:part('Burst', V(s, s, th), cf, color, material)
	c:part('Burst', V(s, s, th + 0.02), cf * CFrame.Angles(0, 0, math.pi / 4), color, material)
end
-- Soda bottle (a body with a white label and a coloured stripe, a shoulder, a neck and a cap) standing on `pos`,
-- scale s (1.5 tall). opts: label, stripe, cap colours and the body material.
function Stations.bottle(c, pos, s, color, opts)
	opts = opts or {}
	Stations.can(c, 'Bottle', pos, 0.3 * s, 0.9 * s, color, opts.material)
	Stations.can(c, 'BottleLabel', pos + V(0, 0.22 * s, 0), 0.315 * s, 0.36 * s, opts.label or C(255, 255, 255))
	Stations.can(c, 'BottleStripe', pos + V(0, 0.36 * s, 0), 0.325 * s, 0.07 * s, opts.stripe or color)
	Stations.can(c, 'BottleShoulder', pos + V(0, 0.9 * s, 0), 0.22 * s, 0.16 * s, color, opts.material)
	Stations.can(c, 'BottleNeck', pos + V(0, 1.06 * s, 0), 0.11 * s, 0.34 * s, color, opts.material)
	Stations.can(c, 'BottleCap', pos + V(0, 1.4 * s, 0), 0.14 * s, 0.1 * s, opts.cap or C(255, 255, 255))
	return 1.5 * s
end
-- Soda can (silver lips, a wide white label band) standing on `pos`; r wide, h tall. face: radius of a red and
-- white bullseye sticker on its front (-Z), for the can you are meant to hit.
function Stations.tin(c, pos, r, h, color, band, face)
	Stations.can(c, 'Can', pos, r, h, color)
	Stations.can(c, 'CanLabel', pos + V(0, h * 0.3, 0), r + 0.015, h * 0.4, band or C(255, 255, 255))
	for _, y in { 0, h - 0.07 } do Stations.can(c, 'CanLip', pos + V(0, y, 0), r + 0.03, 0.07, C(214, 220, 230), M.Metal) end
	if face then Stations.bullseye(c, CFrame.new(pos + V(0, h * 0.5, -r - 0.04)), face, { C(230, 50, 50), C(255, 255, 255), C(230, 50, 50) }) end
end
-- Drum (two proud bands and a lid) standing on `pos`.
function Stations.drum(c, pos, r, h, color, band, lid, material)
	Stations.can(c, 'Drum', pos, r, h, color, material)
	for _, y in { 0.22, 0.7 } do Stations.can(c, 'DrumBand', pos + V(0, h * y - 0.09, 0), r + 0.05, 0.18, band) end
	Stations.can(c, 'DrumLid', pos + V(0, h, 0), r - 0.06, 0.06, lid or band)
end
-- Party balloon (an egg, a knot, a shine) with its string down to `foot`.
function Stations.balloon(c, pos, r, color, foot)
	c:blob('Balloon', V(2 * r, 2.3 * r, 2 * r), pos, color, M.SmoothPlastic)
	c:blob('BalloonShine', V(0.5 * r, 0.7 * r, 0.3 * r), pos + V(0.45 * r, 0.5 * r, -0.85 * r), C(255, 255, 255), M.SmoothPlastic)
	c:part('BalloonKnot', V(0.25 * r, 0.25 * r, 0.25 * r), CFrame.new(pos - V(0, 1.2 * r, 0)) * CFrame.Angles(0, 0, math.pi / 4), color)
	if foot then c:bar('BalloonString', pos - V(0, 1.25 * r, 0), foot, 0.06, C(250, 250, 250), M.SmoothPlastic) end
end
-- Easel: two chunky front legs and a back leg on darker feet, under a ledge `y` up that a board stands on.
function Stations.easel(c, x, z, y, w, color)
	local Y = Stations.MAT_Y
	local foot = color:Lerp(C(0, 0, 0), 0.35)
	for _, sx in { -1, 1 } do
		local a = V(x + sx * (w / 2 + 0.3), Y + 0.25, z + 0.2)
		c:bar('EaselLeg', a, V(x + sx * w / 3, y + 0.1, z + 0.12), 0.4, color, M.SmoothPlastic)
		c:box('EaselFoot', a - V(0.32, 0.25, 0.32), a + V(0.32, 0.05, 0.32), foot)
	end
	local back = V(x, Y + 0.25, z + 1.2 + (y - Y) * 0.12)
	c:bar('EaselLeg', back, V(x, y + 0.35, z + 0.2), 0.36, color, M.SmoothPlastic)
	c:box('EaselFoot', back - V(0.3, 0.25, 0.3), back + V(0.3, 0.05, 0.3), foot)
	c:box('EaselLedge', V(x - w / 2 - 0.15, y - 0.25, z - 0.15), V(x + w / 2 + 0.15, y, z + 0.35), color)
end
-- Ice cube: pale glassy block, a snow cap and a white diagonal shine on its front.
function Stations.ice(c, name, cf, s, color)
	local p = c:part(name, V(s, s, s), cf, color or C(170, 236, 255), M.SmoothPlastic)
	p.Transparency, p.Reflectance = 0.12, 0.15
	c:part('IceCap', V(s - 0.12, 0.1, s - 0.12), cf * CFrame.new(0, s / 2 + 0.04, 0), C(250, 254, 255))
	c:part('IceShine', V(0.12, s * 0.7, 0.04), cf * CFrame.new(-s * 0.18, 0, -s / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	return p
end
-- Icicle hanging from `top` (the centre of its top edge): a wedge turned so its triangle faces -Z, wide at
-- the top, its point at the bottom.
function Stations.icicle(c, top, len, w, color)
	return decor(c:wedge('Icicle', V(0.2, len, w), CFrame.new(top - V(0, len / 2, 0)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), color or C(205, 246, 255)))
end
-- Steel plate (square, a hot or neon border and a centre spot) facing -Z, centred on `cf`.
function Stations.plate(c, cf, w, face, edge, edgeMat, spot)
	c:part('Plate', V(w, w, 0.22), cf, face, M.Metal)
	for _, e in { { 0, w / 2 - 0.08, w, 0.16 }, { 0, -w / 2 + 0.08, w, 0.16 }, { w / 2 - 0.08, 0, 0.16, w - 0.32 }, { -w / 2 + 0.08, 0, 0.16, w - 0.32 } } do
		c:part('PlateEdge', V(e[3], e[4], 0.26), cf * CFrame.new(e[1], e[2], -0.03), edge, edgeMat)
	end
	if spot then Stations.disc(c, 'PlateSpot', cf * CFrame.new(0, 0, -0.1), w * 0.2, 0.1, spot, edgeMat) end
end
-- Gold nugget like the reference's: a flat bevelled slab (a low core with sloping wedges round it) with a
-- smaller centred lump on top, lemon gold, never an amber pile.
function Stations.nugget(c, x, z, s, turn)
	local Y, col = Stations.MAT_Y, C(232, 182, 80)
	local cf = CFrame.new(x, Y, z) * CFrame.Angles(0, turn or 0, 0)
	local function lump(at, w, h, d, slope)
		c:part('Nugget', V(w, h, d), at * CFrame.new(0, h / 2, 0), col)
		for k = 0, 3 do
			local len = (k % 2 == 0) and w or d
			local out = (k % 2 == 0) and d / 2 or w / 2
			c:wedge('NuggetSlope', V(len, h, slope), at * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h / 2, -(out + slope / 2)), col)
		end
	end
	lump(cf, 1.3 * s, 0.32 * s, 1.0 * s, 0.4 * s)
	lump(cf * CFrame.new(0, 0.32 * s, 0), 0.75 * s, 0.18 * s, 0.55 * s, 0.25 * s)
end
-- A ring of eight slabs (outer apothem a, slab thickness th, height h) standing on `cf` (the base centre).
function Stations.ring8(c, name, cf, a, th, h, color, material)
	local w = 2 * a * math.tan(math.pi / 8) + 0.02
	for k = 0, 7 do c:part(name, V(w, h, th), cf * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, h / 2, -a + th / 2), color, material) end
end
-- The gold lane's crown on the gantry: a deep-gold band of eight slabs on a white rim, tall and short points
-- (white tips on the tall ones), ruby and sapphire gems round the band; ~2.8 wide, ~1.9 tall. It turns slowly.
function Stations.crown(g, at)
	local cc, crown = g:group('Crown')
	local body, deep, white = C(227, 169, 63), C(184, 134, 58), C(244, 236, 220)
	Stations.ring8(cc, 'CrownRim', at, 1.42, 0.3, 0.22, white)
	Stations.ring8(cc, 'CrownBand', at * CFrame.new(0, 0.2, 0), 1.35, 0.3, 0.75, body)
	for k = 0, 7 do
		local face = at * CFrame.Angles(0, k * math.pi / 4, 0)
		local tall = k % 2 == 0
		local s = tall and 0.78 or 0.52
		local cy = 0.95 + s * 0.25
		cc:part('CrownPoint', V(s, s, 0.24), face * CFrame.new(0, cy, -1.22) * CFrame.Angles(0, 0, math.pi / 4), tall and body or deep)
		if tall then cc:part('CrownTip', V(0.3, 0.3, 0.3), face * CFrame.new(0, cy + s * 0.71, -1.22), white, M.SmoothPlastic, Enum.PartType.Ball) end
		cc:part('CrownGem', V(0.3, 0.3, 0.16), face * CFrame.new(0, 0.58, -1.36) * CFrame.Angles(0, 0, math.pi / 4), tall and C(168, 52, 60) or C(70, 110, 170), M.Glass)
	end
	for _, p in crown:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	crown.WorldPivot = cc:world(at)
	crown:SetAttribute('Spin', 40)
	crown:AddTag('HoodMotion')
	return crown
end
-- A blocky painted digit (seven segments, 1.3 x h) lying on the mat at `z0` (its foot, nearest the aisle),
-- readable from the aisle end: its top points down the lane.
Stations.DIGITS = { [1] = 'bc', [2] = 'abged', [3] = 'abgcd', [4] = 'fgbc', [5] = 'afgcd', [6] = 'afgedc', [7] = 'abc', [8] = 'abcdefg', [9] = 'abcdfg' }
function Stations.digit(c, n, z0, h, color)
	local Y, W, t = Stations.MAT_Y, 1.3, 0.34
	local seg = {
		a = { -W / 2, W / 2, h - t, h }, g = { -W / 2, W / 2, h / 2 - t / 2, h / 2 + t / 2 }, d = { -W / 2, W / 2, 0, t },
		f = { -W / 2, -W / 2 + t, h / 2, h }, e = { -W / 2, -W / 2 + t, 0, h / 2 }, b = { W / 2 - t, W / 2, h / 2, h }, c = { W / 2 - t, W / 2, 0, h / 2 },
	}
	for ch in string.gmatch(Stations.DIGITS[n] or '', '.') do
		local s = seg[ch]
		-- Digit space (u right, v up) seen from the aisle: u = -x, v = z - z0.
		local p = decor(c:box('LaneDigit', V(-s[2], Y, z0 + s[3]), V(-s[1], Y + 0.03, z0 + s[4]), color, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.15
	end
end

---------------------------------------------------------------------------------------------- targets
-- A target the client can knock: Equipment > Targets > Target<i> with a Hinge (the pivot, a ghost part at
-- `pivot`) and a Swing model (build the visible target into the returned context). knock: 'Tip' (tips back about
-- the hinge's X axis with a little hop), 'Swing' (swings on its hanger), 'Spin' (spins about the hinge's Y axis),
-- 'Pop' (bursts into confetti and grows back), 'Shatter' (bursts into shards and grows back), 'Fly' (flies off
-- spinning and pops back). `aim` is where shots land (local), `main` marks the HitPoint target, `hit` names the
-- sound it makes (Ding steel, Tock wood, Glass, Tin, Pop, Ice, Barrel), `shard` colours its shards/confetti.
function Stations.target(k, pivot, aim, knock, main, hit, shard)
	local n = #k.list + 1
	local tc, model = k.targets:group('Target' .. n)
	ghost(tc:part('Hinge', V(0.2, 0.2, 0.2), pivot, P.white))
	local sw = tc:group('Swing')
	model:SetAttribute('Knock', knock)
	model:SetAttribute('Hit', hit or 'Ding')
	if shard then model:SetAttribute('ShardColor', shard) end
	model:SetAttribute('Aim', tc:world(CFrame.new(aim)).Position)
	if main then
		model:SetAttribute('Main', true)
		k.main = model
		k.mainAim = aim
	end
	table.insert(k.list, model)
	return sw, model
end

---------------------------------------------------------------------------------------------- frame pieces
-- The ring the mat sits in: a lower band (its aisle face stamped with a row of X's) under a lighter studded lip
-- (a glowing neon lip on toxic), both with two-step pixel corners.
function Stations.rim(st, t)
	local MX, MZ = Stations.HALF_X - 1, Stations.HALF_Z - 1
	local function ring(name, y0, y1, inset, color, top, material)
		local X, Z = Stations.HALF_X - inset, Stations.HALF_Z - inset
		local bars = {
			{ V(-MX, y0, -Z), V(MX, y1, -MZ), Enum.NormalId.Front }, { V(-MX, y0, MZ), V(MX, y1, Z), Enum.NormalId.Back },
			{ V(-X, y0, -MZ), V(-MX, y1, MZ), Enum.NormalId.Left }, { V(MX, y0, -MZ), V(X, y1, MZ), Enum.NormalId.Right },
		}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do table.insert(bars, { V(sx * MX, y0, sz * MZ), V(sx * (X - 0.5), y1, sz * (Z - 0.5)) }) end
		end
		for _, b in bars do
			local p = st:box(name, b[1], b[2], color, material)
			if top and not material then studs(p) elseif not top and b[3] then Stations.stamp(p, { b[3] }, (y1 - y0) * 2.4, y1 - y0, Stations.grooveFor(t, color)) end
		end
	end
	ring('RimBase', 0, 0.45, 0, t.rim, false)
	ring('Rim', 0.45, Stations.RIM_Y, 0.12, t.rimTop, true, t.rimTopMat)
	if Stations.StampId == '' then
		local bar = Stations.grooveFor(t, t.rim)
		for k = 0, 5 do
			Stations.barX(st, CFrame.new(-MX + (k + 0.5) * (2 * MX / 6), 0.225, -Stations.HALF_Z), 2 * MX / 6 - 0.1, 0.37, bar)
		end
	end
end

-- The shooter's end: a waist-high bench across the lane (a dark kick plate, a stamped front with four X's, a
-- band in the theme's trim colour, a studded top in the lip colour) with an ammo box, a few shells and ear
-- muffs on it; in front of it a yellow and black hazard stripe (the firing line); in the box two shoe prints and
-- the lane's number in big blocky digits, readable from the aisle.
function Stations.bench(st, t, tier)
	local K = Stations.Kit
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	local body = t.frame
	local mat = t.frameMat == M.Neon and M.SmoothPlastic or (t.frameMat or M.SmoothPlastic)
	if t.frameMat == M.Neon then body = t.rim end -- a neon bench would glare: toxic gets its rim green
	local kick = body:Lerp(C(0, 0, 0), 0.35)
	g:box('BenchKick', V(-3.45, Y, z - 0.47), V(3.45, Y + 0.32, z + 0.4), kick)
	local front = g:box('BenchFront', V(-3.4, Y + 0.32, z - 0.42), V(3.4, Y + h - 0.62, z + 0.42), body, mat)
	Stations.panelX(g, front, CFrame.new(0, Y + 0.32 + (h - 0.94) / 2, z - 0.42), 6.8, h - 0.94, 4, Stations.grooveFor(t, body))
	g:box('BenchBand', V(-3.42, Y + h - 0.62, z - 0.46), V(3.42, Y + h - 0.3, z + 0.3), t.trim or t.rimTop, t.trim and M.SmoothPlastic or t.rimTopMat)
	local top = g:box('BenchTop', V(-3.6, Y + h - 0.3, z - 0.62), V(3.6, Y + h, z + 0.5), t.rimTop, t.rimTopMat)
	if not t.rimTopMat then studs(top) end
	local d = st:group('BenchProps')
	local y = Y + h
	-- Ammo box (olive, a yellow stripe and a handle).
	decor(d:box('AmmoBox', V(2.15, y, z - 0.3), V(3.05, y + 0.48, z + 0.22), C(86, 104, 58)))
	decor(d:box('AmmoStripe', V(2.13, y + 0.3, z - 0.32), V(3.07, y + 0.38, z + 0.24), K.muted))
	decor(d:box('AmmoHandle', V(2.45, y + 0.48, z - 0.08), V(2.75, y + 0.56, z), C(40, 44, 40)))
	-- A few brass shells lying about.
	for i, s in { { 1.45, -0.15, 0.3 }, { 1.7, 0.05, 1.4 }, { 1.25, 0.12, 2.2 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(s[1], y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), i == 2 and C(232, 176, 72) or C(244, 194, 80), M.Metal, Enum.PartType.Cylinder))
	end
	-- Ear muffs: two dark cups under a muted yellow arch.
	local yellow = K.muted
	for _, sx in { -1, 1 } do
		decor(d:blob('EarCup', V(0.5, 0.55, 0.55), V(-2.6 + sx * 0.42, y + 0.28, z - 0.05), C(50, 52, 60), M.SmoothPlastic))
		decor(d:box('EarArchSide', V(-2.6 + sx * 0.4 - 0.05, y + 0.5, z - 0.1), V(-2.6 + sx * 0.4 + 0.05, y + 0.84, z), yellow))
	end
	decor(d:box('EarArch', V(-3.05, y + 0.76, z - 0.1), V(-2.15, y + 0.86, z), yellow))
	-- Painted on the mat: the box outline (white on dark mats, the groove colour on pale ones), the hazard
	-- stripe, two shoe prints and the lane number.
	local m = t.mat
	local pale = 0.299 * m.R + 0.587 * m.G + 0.114 * m.B > 0.7
	local edge = pale and Stations.grooveFor(t, m) or C(250, 250, 245)
	local x0, x1, b0, b1, w = -3.25, 3.25, -8.75, -3.9, 0.14
	for _, b in { { V(x0, Y, b0), V(x1, Y + 0.03, b0 + w) }, { V(x0, Y, b0), V(x0 + w, Y + 0.03, b1) }, { V(x1 - w, Y, b0), V(x1, Y + 0.03, b1) } } do
		local p = decor(st:box('BoxLine', b[1], b[2], edge, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.2
	end
	decor(st:box('FiringLine', V(-3.5, Y, -3.9), V(3.5, Y + 0.03, -3.5), K.muted, M.SmoothPlastic)).CastShadow = false
	for i = 0, 8 do
		decor(st:part('FiringStripe', V(0.24, 0.02, 0.44), CFrame.new(-3.2 + i * 0.8, Y + 0.035, -3.7) * CFrame.Angles(0, math.rad(40), 0), C(30, 30, 36))).CastShadow = false
	end
	for _, sx in { -1, 1 } do
		local x = sx * 0.45
		local sole = decor(st:box('ShoePrint', V(x - 0.3, Y, -5.1), V(x + 0.3, Y + 0.03, -4.0), edge, M.SmoothPlastic))
		local heel = decor(st:box('ShoePrint', V(x - 0.25, Y, -5.8), V(x + 0.25, Y + 0.03, -5.35), edge, M.SmoothPlastic))
		sole.CastShadow, heel.CastShadow, sole.Transparency, heel.Transparency = false, false, 0.25, 0.25
	end
	Stations.digit(st, tier, -8.5, 2.3, edge)
end

-- The backstop's body: a wall across the outer end with a stepped top (two steps each side, like the rim's
-- pixel corners), its front stamped with X's. Returns the three blocks (base, step, top).
function Stations.wall(c, t, color, material, h, groove)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	h = h or 5.6
	groove = groove or Stations.grooveFor(t, color)
	local base = c:box('Backstop', V(-4.3, 0, z0), V(4.3, Y + h, z1), color, material)
	local step = c:box('BackstopStep', V(-2.9, Y + h, z0 + 0.15), V(2.9, Y + h + 0.8, z1), color, material)
	local top = c:box('BackstopTop', V(-1.5, Y + h + 0.8, z0 + 0.3), V(1.5, Y + h + 1.4, z1), color, material)
	if material ~= M.Neon then
		Stations.panelX(c, base, CFrame.new(0, (Y + h) / 2, z0), 8.6, Y + h, 5, groove)
		Stations.panelX(c, step, CFrame.new(0, Y + h + 0.4, z0 + 0.15), 5.8, 0.8, 4, groove)
	end
	return base, step, top
end
-- Thin lines along the wall's front: up both sides and along the top edge of each step (trim or neon).
function Stations.wallLines(c, h, color, material, th)
	local Y, z = Stations.MAT_Y, Stations.BACK_Z
	th = th or 0.14
	local lines = {
		{ V(-4.3, 0.6, z - 0.06), V(-4.3 + th, Y + h, z + 0.05) }, { V(4.3 - th, 0.6, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-4.3, Y + h - th, z - 0.06), V(-2.9, Y + h, z + 0.05) }, { V(2.9, Y + h - th, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-2.9, Y + h + 0.8 - th, z + 0.09), V(-1.5, Y + h + 0.8, z + 0.2) }, { V(1.5, Y + h + 0.8 - th, z + 0.09), V(2.9, Y + h + 0.8, z + 0.2) },
		{ V(-1.5, Y + h + 1.4 - th, z + 0.24), V(1.5, Y + h + 1.4, z + 0.35) },
	}
	for _, b in lines do
		local p = decor(c:box('WallLine', b[1], b[2], color, material))
		if material == M.Neon then p.CastShadow = false end
	end
end

-- The truss gantry over the targets: two grooved truss posts on stamped feet at the lane's edges and a grooved
-- truss beam across, capped. Hanging targets hang from its underside (GANTRY_Y) on its centre line. neon: strip
-- lights on the posts' front edges and under the beam (shadow, frost, toxic, gold); look.width (default 0.14),
-- look.backing (a dark strip 0.34 wide just behind each line, so it reads without bloom on a bright frame) and
-- look.cap (the feet and caps in another metal: brass on the top two tiers).
function Stations.gantry(g, t, neon, look)
	look = look or {}
	local nw, back = look.width or 0.14, look.backing
	local nz0, nz1 = back and 0.49 or 0.47, back and 0.35 or 0.33
	local Y, z, y0 = Stations.MAT_Y, Stations.GANTRY_Z, Stations.GANTRY_Y
	local W = 0.8
	local frame, fm = t.frame, t.frameMat or M.SmoothPlastic
	local groove = Stations.grooveFor(t, frame)
	local foot = look.cap or frame:Lerp(C(0, 0, 0), 0.12) -- (look.cap: metal feet and caps, a step up the material ladder)
	for _, sx in { -1, 1 } do
		local x = sx * 3.9
		Stations.stamp(g:box('GantryFoot', V(x - 0.55, 0.05, z - 0.6), V(x + 0.55, Y + 0.75, z + 0.6), fm == M.Neon and t.rim or foot), Stations.SIDES, 1.1, Y + 0.7, groove)
		Stations.truss(g, 'GantryPost', CFrame.new(x, Y + 0.75, z), y0 - Y - 0.75, W, W, frame, groove, 1.55, { '-z', '-x', '+x' }, fm)
		g:box('GantryCap', V(x - 0.55, y0 + W, z - 0.55), V(x + 0.55, y0 + W + 0.25, z + 0.55), fm == M.Neon and t.rim or look.cap or frame)
		-- A small gusset under each end of the beam.
		g:wedge('GantryGusset', V(0.5, 0.8, 0.8), CFrame.new(x - sx * 0.8, y0 - 0.4, z) * CFrame.Angles(0, sx * math.pi / 2, 0), frame, fm)
		if neon then
			for _, ex in { 3.5, 4.3 } do
				if back then decor(g:box('GantryNeonBack', V(sx * ex - 0.17, Y + 0.76, z - 0.47), V(sx * ex + 0.17, y0 + 0.79, z - 0.31), back)).CastShadow = false end
				decor(g:box('GantryNeon', V(sx * ex - nw / 2, Y + 0.8, z - nz0), V(sx * ex + nw / 2, y0 + 0.75, z - nz1), neon, M.Neon)).CastShadow = false
			end
		end
	end
	Stations.truss(g, 'GantryBeam', CFrame.new(-4.35, y0 + W / 2, z) * CFrame.Angles(0, 0, -math.pi / 2), 8.7, W, W, frame, groove, 1.45, { '-z' }, fm)
	if neon then
		if back then decor(g:box('GantryNeonBack', V(-3.55, y0 - 0.17, z - 0.47), V(3.55, y0 + 0.17, z - 0.31), back)).CastShadow = false end
		decor(g:box('GantryNeon', V(-3.5, y0 - nw / 2, z - nz0), V(3.5, y0 + nw / 2, z - nz1), neon, M.Neon)).CastShadow = false
	end
end

-- Hang a target from the gantry's underside at x: two short chains down to the target's top `top`.
function Stations.chains(c, x, top, span)
	local y0 = Stations.GANTRY_Y
	for _, sx in { -1, 1 } do
		c:box('Chain', V(x + sx * span - 0.08, top - 0.05, Stations.GANTRY_Z - 0.08), V(x + sx * span + 0.08, y0 + 0.02, Stations.GANTRY_Z + 0.08), C(52, 54, 66))
	end
	c:box('Hook', V(x - span - 0.15, y0 - 0.14, Stations.GANTRY_Z - 0.15), V(x + span + 0.15, y0, Stations.GANTRY_Z + 0.15), C(52, 54, 66))
end

---------------------------------------------------------------------------------------------- lanes
-- One builder per theme: the backstop's dressing, the stands and the targets. `k` holds st (the station),
-- gear (Equipment > Gear), targets (Equipment > Targets), list, t, tier and burners (parts that get flames).
-- Every main target's centre sits ~5.8 over the mat (local y ~6.2): above the shooter's head from the follow
-- camera, so the thing you shoot is never hidden behind your own avatar.
Stations.Lanes = {}
Stations.SODA = { red = C(235, 55, 60), orange = C(255, 150, 30), blue = C(60, 140, 240), lime = C(130, 220, 60) }

-- 1 Stone: soda bottles and cans on a tall plank shelf; a rough plank backstop with a painted bullseye high up,
-- sandbags, bunting that flutters; a crate of spare sodas and a tyre stack.
function Stations.Lanes.stone(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local wood, soda = t.frame, Stations.SODA
	local z0 = Stations.BACK_Z
	local back = k.st:group('Backstop')
	for i, h in { 7.4, 7.9, 8.25, 8.45, 8.3, 7.95, 7.3 } do
		local x = -4.2 + (i - 0.5) * 1.2
		local p = back:box('Plank', V(x - 0.58, 0, z0 + (i % 2) * 0.05), V(x + 0.58, Y + h, z0 + 0.45), i % 2 == 0 and wood:Lerp(C(0, 0, 0), 0.12) or wood)
		Stations.stamp(p, { Enum.NormalId.Front }, 1.16, Y + h, Stations.grooveFor(t, wood), 0.35)
	end
	for _, y in { 1.2, 6.6 } do back:box('Batten', V(-4.3, Y + y, z0 + 0.5), V(4.3, Y + y + 0.45, z0 + 0.85), wood:Lerp(C(0, 0, 0), 0.2)) end
	Stations.bullseye(back, CFrame.new(0, Y + 6.8, z0 - 0.02), 1.15, { C(236, 228, 214), C(178, 74, 64), C(236, 228, 214), C(178, 74, 64) })
	for i, s in { { -2.9, 0, 1.9 }, { -0.95, 0, 1.9 }, { 0.95, 0, 1.9 }, { 2.9, 0, 1.9 }, { -1.9, 0.62, 1.8 }, { 1.95, 0.62, 1.8 } } do
		back:blob('Sandbag', V(s[3], 0.72, 1.05), V(s[1], Y + 0.34 + s[2], z0 - 0.6), i % 2 == 0 and C(158, 146, 120) or C(140, 130, 106), M.Fabric)
	end
	-- Bunting between two poles over the planks: two strands of little flags (cream, teal, gold, brick), each on
	-- its own string, bobbing at different rates, so the pair ripples and no flag ever leaves its line.
	for _, sx in { -1, 1 } do back:box('BuntingPole', V(sx * 4.1 - 0.13, Y, z0 - 0.45), V(sx * 4.1 + 0.13, Y + 9.15, z0 - 0.19), wood:Lerp(C(0, 0, 0), 0.25)) end
	local flags = { C(229, 220, 203), C(63, 125, 110), C(227, 169, 63), C(154, 102, 85) }
	for strand, at in { { 8.95, 1.3, -0.33 }, { 8.62, 1.7, -0.27 } } do
		local bc, bunting = back:group('Bunting')
		local y, period, dz = at[1], at[2], at[3]
		bc:box('BuntingLine', V(-4.0, Y + y - 0.03, z0 + dz - 0.03), V(4.0, Y + y + 0.03, z0 + dz + 0.03), C(250, 250, 245))
		for i = strand - 1, 9, 2 do
			local sag = 0.15 * math.sin((i + 0.5) / 10 * math.pi)
			bc:wedge('Flag', V(0.06, 0.55, 0.62), CFrame.new(-3.6 + i * 0.8, Y + y - 0.3 - sag, z0 + dz) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), flags[i % 4 + 1])
			bc:box('FlagTie', V(-3.6 + i * 0.8 - 0.025, Y + y - 0.05 - sag, z0 + dz - 0.02), V(-3.6 + i * 0.8 + 0.025, Y + y, z0 + dz + 0.02), C(250, 250, 245))
		end
		for _, p in bunting:GetDescendants() do if p:IsA('BasePart') then decor(p).CastShadow = false end end
		bunting.WorldPivot = bc:world(CFrame.new(0, Y + y, z0 + dz))
		bunting:SetAttribute('Bob', 0.13)
		bunting:SetAttribute('BobPeriod', period)
		bunting:AddTag('HoodMotion')
	end
	-- The shelf: two posts, two rails and a deep top rail at chest height the targets stand on.
	local fz, top = 5.0, Y + 4.4
	for _, sx in { -1, 1 } do g:box('FencePost', V(sx * 3.05 - 0.28, Y, fz - 0.28), V(sx * 3.05 + 0.28, top + 0.15, fz + 0.28), wood:Lerp(C(0, 0, 0), 0.15)) end
	for _, ry in { 1.3, 2.9 } do g:box('FenceRail', V(-3.45, Y + ry, fz - 0.15), V(3.45, Y + ry + 0.35, fz + 0.15), wood) end
	g:box('FenceShelf', V(-3.5, top - 0.25, fz - 0.95), V(3.5, top, fz + 0.95), wood:Lerp(C(255, 255, 255), 0.08))
	-- Targets, left to right: soda bottle, can, the big cola can with a bullseye (main), can, bottle. Bottles
	-- shatter, small cans fly off; the big can rocks back on its back edge and stays (it is the one you shoot
	-- every other shot, so it is always there).
	local items = {
		{ -2.75, 'bottle', soda.orange, 1.25, nil, C(255, 255, 255) }, { -1.5, 'tin', soda.blue, 0.55, 1.25 }, { 0, 'tin', soda.red, 0.88, 2.0, true },
		{ 1.5, 'tin', soda.lime, 0.55, 1.25 }, { 2.75, 'bottle', soda.blue, 1.25, nil, C(255, 214, 40) },
	}
	for _, it in items do
		local base = V(it[1], top, fz)
		local h = it[2] == 'bottle' and 1.5 * it[4] or it[5]
		local bottle = it[2] == 'bottle'
		local main = it[6] == true
		local hinge = main and V(0, 0, it[4]) or V(0, 0, 0.2)
		local sw, model = Stations.target(k, CFrame.new(base + hinge), base + V(0, h / 2, 0), bottle and 'Shatter' or (main and 'Tip' or 'Fly'), main, bottle and 'Glass' or 'Tin', it[3])
		if main then model:SetAttribute('TipMin', 0) end
		if bottle then Stations.bottle(sw, base, it[4], it[3], { stripe = it[3], cap = it[6] })
		else Stations.tin(sw, base, it[4], it[5], it[3], C(255, 255, 255), it[6] and 0.75 or nil) end
	end
	-- Story props: a crate of spare sodas, a stack of old tyres, a can that already fell.
	local crate = g:box('Crate', V(-3.3, Y, 1.3), V(-1.7, Y + 1.1, 2.7), C(196, 140, 80))
	Stations.stamp(crate, Stations.SIDES, 1.6, 1.1, C(150, 98, 52))
	local colors = { soda.red, soda.orange, soda.blue, soda.lime, soda.blue, soda.red }
	local n = 0
	for _, x in { -2.95, -2.5, -2.05 } do
		for _, z in { 1.7, 2.3 } do
			n += 1
			Stations.bottle(g, V(x, Y + 1.1, z), 0.55, colors[n])
		end
	end
	for i, y in { 0, 0.5 } do
		local at = CFrame.new(2.55 + i * 0.12, Y + y + 0.25, 1.9) * CFrame.Angles(0, 0, math.pi / 2)
		g:part('Tyre', V(0.5, 1.7, 1.7), at, C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('TyreHub', V(0.52, 0.8, 0.8), at, C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
	end
	g:part('FallenCan', V(0.95, 0.84, 0.84), CFrame.new(1.2, Y + 0.42, 3.2) * CFrame.Angles(0, 0.6, 0), soda.blue, M.SmoothPlastic, Enum.PartType.Cylinder)
end

-- 2 Red: three red-and-cream bullseye boards on charcoal easels (the main one up high); a charcoal board backstop
-- with wood trim and a little target sign.
function Stations.Lanes.red(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local back = k.st:group('Backstop')
	local h = 6.6
	Stations.wall(back, t, t.frame, M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.trim, M.SmoothPlastic, 0.3)
	local cream, red = C(236, 228, 214), C(192, 66, 62)
	Stations.bullseye(back, CFrame.new(0, Y + h + 1.1, Stations.BACK_Z + 0.28), 0.45, { cream, red, cream })
	local rings = { cream, red, cream, red, C(227, 169, 63) }
	-- Boards: big centre (main), two small at the sides, at different depths and heights.
	for _, b in { { 0, 6.0, 4.0, 1.78, true }, { -2.55, 4.5, 1.5, 1.0 }, { 2.6, 4.1, 2.15, 1.0 } } do
		local x, bz, ledge, r = b[1], b[2], Y + b[3], b[4]
		Stations.easel(g, x, bz, ledge, r * 1.6, t.frame)
		local sw = Stations.target(k, CFrame.new(x, ledge, bz + 0.1), V(x, ledge + r, bz), 'Tip', b[5], 'Tock')
		Stations.disc(sw, 'Board', CFrame.new(x, ledge + r, bz + 0.12), r + 0.12, 0.18, t.frame)
		Stations.bullseye(sw, CFrame.new(x, ledge + r, bz + 0.03), r, rings)
	end
	-- A spare board leaning on the backstop.
	local lean = CFrame.new(3.35, Y + 1.05, Stations.BACK_Z - 0.45) * CFrame.Angles(math.rad(-12), math.rad(-8), 0)
	Stations.disc(g, 'Board', lean, 0.95, 0.15, t.frame)
	Stations.bullseye(g, lean * CFrame.new(0, 0, -0.08), 0.85, { cream, red, cream })
end

-- 3 Lava (ember): hot plates swinging from a charcoal gantry (a big gong is the main), burning barrels at the
-- sides, a basalt berm with ember cracks and a glowing pool on top, nearly as tall as the gantry.
function Stations.Lanes.lava(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local rock, rock2, hot = C(62, 50, 50), C(80, 64, 62), C(196, 82, 40) -- (ember: a glow, not a blaze)
	local z0 = Stations.BACK_Z
	local blocks = {
		{ -4.3, -1.5, 0, 3.1, 0.0, rock, 3 }, { -1.6, 1.5, 0, 3.5, -0.15, rock2, -2 }, { 1.4, 4.3, 0, 2.9, 0.05, rock, 4 },
		{ -3.9, -0.1, 3.0, 6.0, 0.1, rock2, -3 }, { -0.2, 4.0, 2.8, 6.3, -0.05, rock, 2 }, { -2.0, 1.8, 5.9, 7.6, 0.2, rock2, -4 },
	}
	for _, b in blocks do
		local cx, cy = (b[1] + b[2]) / 2, (b[3] + b[4]) / 2 + Y / 2
		back:part('Basalt', V(b[2] - b[1], b[4] - b[3] + (b[3] == 0 and Y or 0), Stations.HALF_Z - 0.1 - z0 - b[5]),
			CFrame.new(cx, cy, (z0 + b[5] + Stations.HALF_Z - 0.1) / 2) * CFrame.Angles(0, 0, math.rad(b[7])), b[6], M.Slate)
	end
	-- Glowing cracks along the joints and a hot pool on top.
	for _, c in { { -4.2, 4.2, Y + 3.05 }, { -3.6, 3.8, Y + 6.0 } } do
		decor(back:box('LavaCrack', V(c[1], c[3] - 0.08, z0 - 0.3), V(c[2], c[3] + 0.08, z0 + 0.4), hot, M.Neon)).CastShadow = false
	end
	for _, x in { -1.5, 1.4 } do decor(back:box('LavaCrack', V(x - 0.08, 0.5, z0 - 0.25), V(x + 0.08, Y + 3.05, z0 + 0.4), hot, M.Neon)).CastShadow = false end
	decor(back:box('LavaPool', V(-1.8, Y + 7.38, z0 + 0.4), V(1.7, Y + 7.5, Stations.HALF_Z - 0.3), C(206, 112, 56), M.Neon)).CastShadow = false
	-- Plates: a big round gong (main) between two square plates, all hanging from the beam.
	local function gong(sw, x, cy, r)
		Stations.disc(sw, 'GongRim', CFrame.new(x, cy, Stations.GANTRY_Z), r, 0.25, C(70, 66, 76), M.Metal)
		Stations.disc(sw, 'GongHot', CFrame.new(x, cy, Stations.GANTRY_Z - 0.05), r * 0.8, 0.3, C(206, 92, 44), M.Neon)
		Stations.disc(sw, 'GongCore', CFrame.new(x, cy, Stations.GANTRY_Z - 0.1), r * 0.42, 0.34, C(244, 176, 108), M.Neon)
		Stations.chains(sw, x, cy + r - 0.1, r * 0.45)
	end
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, 6.2, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	gong(sw, 0, 6.2, 1.62)
	for _, p in { { -2.65, 4.3, 1.4 }, { 2.65, 4.9, 1.35 } } do
		local s2 = Stations.target(k, CFrame.new(p[1], Stations.GANTRY_Y, Stations.GANTRY_Z), V(p[1], p[2], Stations.GANTRY_Z), 'Swing', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], p[2], Stations.GANTRY_Z), p[3], C(64, 60, 70), C(206, 92, 44), M.Neon, C(244, 176, 108))
		Stations.chains(s2, p[1], p[2] + p[3] / 2, p[3] * 0.32)
	end
	-- Burning barrels (flames come from HoodVFX on their open tops).
	for _, b in { { -2.85, 1.9 }, { 2.9, 3.1 } } do
		local pos = V(b[1], Y, b[2])
		Stations.drum(g, pos, 0.62, 1.7, C(122, 66, 48), C(70, 44, 36), C(40, 30, 28), M.Metal)
		local coal = decor(g:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(220, 112, 52), M.Neon, Enum.PartType.Cylinder))
		table.insert(k.burners, coal)
	end
end

-- 4 Arcane: a big spinner disc up high (main), two balloons to pop, balloon bunches bobbing on the gantry posts,
-- a dark plum wall with a muted plum starburst behind the spinner and pale sparkle diamonds.
function Stations.Lanes.arcane(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(58, 52, 70), M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.rimTop, M.SmoothPlastic, 0.18)
	local z = Stations.BACK_Z
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 3.7, 0.16, C(118, 92, 132))
	for _, s in { { -3.3, 6.6 }, { 3.2, 2.0 }, { -3.1, 1.6 }, { 3.35, 6.4 }, { -2.6, 4.0 }, { 2.8, 4.6 } } do
		decor(back:part('Sparkle', V(0.42, 0.42, 0.1), CFrame.new(s[1], Y + s[2], z - 0.06) * CFrame.Angles(0, 0, math.pi / 4), C(214, 200, 226), M.SmoothPlastic)).CastShadow = false
	end
	-- Spinner: a chunky post with a big ringed disc on a hub; it turns slowly and spins when hit.
	local sz = 6.0
	g:box('SpinnerPost', V(-0.2, Y, sz + 0.3), V(0.2, Y + 5.8, sz + 0.7), t.frame)
	g:box('SpinnerFoot', V(-0.75, Y, sz - 0.2), V(0.75, Y + 0.35, sz + 1.2), t.frame:Lerp(C(0, 0, 0), 0.25))
	local sw = Stations.target(k, CFrame.new(0, Y + 5.8, sz), V(0, Y + 5.8, sz), 'Spin', true, 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(0, Y + 5.8, sz + 0.12), 1.72, 0.16, t.frame)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, sz + 0.03), 1.62, { C(236, 228, 214), C(206, 112, 164), C(236, 228, 214), C(128, 96, 176), C(227, 169, 63) })
	-- Balloons to pop, tied to little weights.
	for _, b in { { -2.6, 4.4, Y + 4.2, C(214, 112, 160) }, { 2.65, 5.1, Y + 4.9, C(120, 176, 214) } } do
		local pos = V(b[1], b[3], b[2])
		g:box('BalloonWeight', V(b[1] - 0.22, Y, b[2] - 0.22), V(b[1] + 0.22, Y + 0.35, b[2] + 0.22), C(216, 180, 74))
		local s2 = Stations.target(k, CFrame.new(pos), pos, 'Pop', false, 'Pop', b[4])
		Stations.balloon(s2, pos, 0.62, b[4], V(b[1], Y + 0.35, b[2]))
	end
	-- Bunches of three on each gantry post (they bob; not targets).
	for _, sx in { -1, 1 } do
		local bc, bunch = g:group('BalloonBunch')
		local foot = V(sx * 3.9, Stations.GANTRY_Y + 1.05, Stations.GANTRY_Z) -- (on the post's cap)
		for i, c in { C(214, 112, 160), C(227, 169, 63), C(120, 176, 214) } do
			local a = (i - 2) * 0.6
			Stations.balloon(bc, foot + V(math.sin(a) * 1.0 - sx * 0.15, 0.95 + math.cos(a) * 0.35, -0.2 * i), 0.6, c, foot)
		end
		for _, p in bunch:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
		bunch.WorldPivot = bc:world(CFrame.new(foot))
		bunch:SetAttribute('Bob', 0.14)
		bunch:SetAttribute('BobPeriod', 2.6 + sx * 0.3)
		bunch:AddTag('HoodMotion')
	end
end

-- 5 Shadow: dark plates with violet neon rims (a big hanging one is the main, haloed by a dim neon ring on the
-- black wall), dim violet neon on the gantry and along the wall's steps.
function Stations.Lanes.shadow(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	-- (Dim violet on the structure, a brighter violet only on the targets.)
	local dim, violet, dark = C(96, 80, 140), C(136, 108, 204), C(44, 40, 54)
	Stations.gantry(g, t, dim)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(34, 33, 42), M.SmoothPlastic, h)
	Stations.wallLines(back, h, dim, M.Neon, 0.1)
	local z = Stations.BACK_Z
	Stations.bullseye(back, CFrame.new(0, Y + 5.8, z - 0.02), 2.5, { dim, C(26, 26, 34), dim, C(26, 26, 34), dim }, { M.Neon, M.SmoothPlastic, M.Neon, M.SmoothPlastic, M.Neon })
	-- Main: a round dark plate with neon rings, hanging from the beam.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	Stations.disc(sw, 'PlateRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.04), 1.72, 0.2, violet, M.Neon)
	Stations.disc(sw, 'Plate', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.5, 0.26, dark, M.Metal)
	Stations.disc(sw, 'PlateRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 0.95, 0.3, violet, M.Neon)
	Stations.disc(sw, 'PlateInner', CFrame.new(0, cy, Stations.GANTRY_Z - 0.1), 0.8, 0.34, dark, M.Metal)
	Stations.disc(sw, 'PlateSpot', CFrame.new(0, cy, Stations.GANTRY_Z - 0.14), 0.32, 0.38, violet, M.Neon)
	Stations.chains(sw, 0, cy + 1.62, 0.65)
	-- Two square plates on chunky posts at the sides.
	for _, p in { { -2.6, 4.6, 2.6, 1.3 }, { 2.6, 4.1, 3.2, 1.2 } } do
		g:box('PlatePost', V(p[1] - 0.2, Y, p[2] + 0.12), V(p[1] + 0.2, Y + p[3], p[2] + 0.52), t.frame)
		local s2 = Stations.target(k, CFrame.new(p[1], Y + p[3], p[2] + 0.1), V(p[1], Y + p[3] + p[4] / 2, p[2]), 'Tip', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], Y + p[3] + p[4] / 2, p[2]), p[4], dark, violet, M.Neon, violet)
	end
end

-- 6 Frost: an ice bullseye on a tall ice pillar (main), small ice blocks on charcoal pedestals, a four-course
-- frosted ice wall with a snow top, icicles and one soft icy glow under it, slate-blue snowflakes, and a charcoal
-- gantry with a thin icy line: pale ice in a dark frame.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, deep = C(244, 246, 248), C(196, 218, 228), C(176, 202, 214), C(64, 112, 170)
	local glow, slate = C(170, 206, 228), C(96, 132, 170) -- (one soft icy glow; slate-blue paint for the graphics)
	Stations.gantry(g, t, C(214, 232, 240), { width = 0.1 })
	g:box('BeamSnow', V(-4.4, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.45), V(4.4, Stations.GANTRY_Y + 1.0, Stations.GANTRY_Z + 0.45), snow)
	for i = 0, 6 do
		local len = 0.5 + ((i * 37) % 5) * 0.12
		Stations.icicle(g, V(-3.1 + i * 1.05, Stations.GANTRY_Y - 0.06, Stations.GANTRY_Z - 0.2), len, 0.3)
	end
	-- Wall: four courses of ice blocks, offset like bricks, a snow top with drifts and icicles along its front.
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	for row = 0, 3 do
		local y0, y1 = row == 0 and 0 or Y + row * 1.9, Y + (row + 1) * 1.9
		local xs = row % 2 == 0 and { -4.3, -2.2, -0.1, 2.0, 4.3 } or { -4.3, -3.2, -1.1, 1.0, 3.1, 4.3 }
		for i = 1, #xs - 1 do
			local p = back:box('IceWall', V(xs[i] + 0.03, y0, z0 + ((i + row) % 2) * 0.08), V(xs[i + 1] - 0.03, y1 - 0.04, z1), (i + row) % 2 == 0 and iceA or iceB)
			p.Reflectance = 0.15
		end
	end
	local top = Y + 7.6
	studs(back:box('SnowTop', V(-4.4, top, z0 - 0.1), V(4.4, top + 0.4, z1), snow))
	decor(back:box('SnowGlow', V(-4.4, top - 0.28, z0 - 0.22), V(4.4, top - 0.06, z0 - 0.1), glow, M.Neon)).CastShadow = false
	for _, d in { { -2.6, 1.6, 0.5 }, { 0.6, 2.0, 0.7 }, { 2.9, 1.2, 0.4 } } do back:box('SnowDrift', V(d[1] - d[2] / 2, top + 0.4, z0 + 0.1), V(d[1] + d[2] / 2, top + 0.4 + d[3], z1 - 0.1), snow) end
	for i = 0, 9 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-3.9 + i * 0.86, top - 0.1, z0 - 0.12), len, 0.34)
	end
	-- Two slate-blue snowflakes high on the wall either side of the main target (six arms with twin branches;
	-- clear of the bullseye, the gantry posts and the icicles), and slate lines up the wall's edges: the lane's dark
	-- graphic, like shadow's rings.
	for _, sx0 in { -1, 1 } do
		local fc = CFrame.new(sx0 * 2.66, Y + 6.5, z0 - 0.08) * CFrame.Angles(0, 0, math.rad(15))
		for a = 0, 2 do
			local arm = fc * CFrame.Angles(0, 0, a * math.pi / 3)
			decor(back:part('Snowflake', V(1.6, 0.3, 0.1), arm, slate, M.SmoothPlastic)).CastShadow = false
			for _, sx in { -1, 1 } do
				for _, sb in { -1, 1 } do
					local at = arm * CFrame.new(sx * 0.48, 0, -0.01) * CFrame.Angles(0, 0, sx * sb * math.pi / 3) * CFrame.new(sx * 0.17, 0, 0)
					decor(back:part('Snowflake', V(0.36, 0.2, 0.1), at, slate, M.SmoothPlastic)).CastShadow = false
				end
			end
		end
	end
	for _, sx in { -1, 1 } do
		decor(back:box('WallNeon', V(sx * 4.3 - 0.11, 0.6, z0 - 0.07), V(sx * 4.3 + 0.11, top - 0.34, z0 + 0.04), slate, M.SmoothPlastic)).CastShadow = false
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	g:box('IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), t.frame)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, C(150, 190, 214))
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, mz + 0.03), 1.72, { snow, deep, snow, deep, C(255, 255, 255) })
	-- Ice blocks on pedestals at the sides.
	for _, b in { { -2.6, 4.5, 2.6, 0.95 }, { 2.6, 5.0, 3.2, 0.9 } } do
		-- (Deep-blue pedestals under pale ice: the field's dark-light structure.)
		g:box('IcePedestal', V(b[1] - 0.55, Y, b[2] - 0.55), V(b[1] + 0.55, Y + b[3], b[2] + 0.55), t.frame)
		g:box('IcePedestalCap', V(b[1] - 0.62, Y + b[3] - 0.14, b[2] - 0.62), V(b[1] + 0.62, Y + b[3], b[2] + 0.62), snow)
		local cy = Y + b[3] + b[4] / 2
		-- (Hinged on the block's back edge and never rocking forward, so it tips off its cap, never into it.)
		local s2, block = Stations.target(k, CFrame.new(b[1], Y + b[3], b[2] + 0.6), V(b[1], cy, b[2]), 'Tip', false, 'Ice')
		block:SetAttribute('TipMin', 0)
		Stations.ice(s2, 'IceBlock', CFrame.new(b[1], cy, b[2]) * CFrame.Angles(0, math.rad(b[1] > 0 and 20 or -15), 0), b[4])
	end
end

-- 7 Toxic: a big toxic barrel with a target face on a pallet and two crates (main), green bottles on a shelf
-- under a hanging hazard sign, a second barrel, glassy puddles, a dark container wall with ribs, a muted
-- hazard stripe and a drip sign.
function Stations.Lanes.toxic(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local green, dark, navy = C(112, 170, 92), C(46, 60, 58), C(43, 47, 54) -- (a muted toxic green, no neon)
	-- (Brass feet and caps and thin warm work lights: a step up from frost's steel, a step below gold's walnut.)
	Stations.gantry(g, t, C(255, 227, 179), { width = 0.08, cap = Stations.Kit.brass })
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.0
	Stations.wall(back, t, dark, M.SmoothPlastic, h)
	for i = 0, 7 do
		local x = -3.7 + i * 1.06
		back:box('Rib', V(x - 0.14, 0.6, z - 0.12), V(x + 0.14, Y + h - 0.75, z + 0.1), dark:Lerp(C(255, 255, 255), 0.12))
	end
	-- Hazard band: yellow with black slanted bars.
	back:box('HazardBand', V(-4.3, Y + h - 0.7, z - 0.16), V(4.3, Y + h - 0.1, z + 0.1), C(216, 180, 74))
	for i = 0, 7 do
		decor(back:part('HazardBar', V(0.35, 0.82, 0.05), CFrame.new(-3.75 + i * 1.07, Y + h - 0.4, z - 0.18) * CFrame.Angles(0, 0, math.rad(40)), C(30, 30, 36)))
	end
	-- The drip sign (a green drop on a dark plate), off to the right of the barrel stack.
	local sx, sy = 2.45, Y + 4.4
	Stations.disc(back, 'SignPlate', CFrame.new(sx, sy, z - 0.2), 1.25, 0.14, navy)
	Stations.disc(back, 'Drip', CFrame.new(sx, sy - 0.25, z - 0.32), 0.75, 0.14, green, M.SmoothPlastic)
	decor(back:part('DripTip', V(1.06, 1.06, 0.14), CFrame.new(sx, sy + 0.18, z - 0.32) * CFrame.Angles(0, 0, math.pi / 4), green, M.SmoothPlastic))
	Stations.disc(back, 'DripShine', CFrame.new(sx - 0.24, sy - 0.05, z - 0.42), 0.18, 0.08, C(222, 236, 214), M.SmoothPlastic)
	-- Hazard diamond hanging from the beam over the bottle shelf (decor).
	local hx = -2.6
	for _, ox in { -0.5, 0.5 } do g:box('SignChain', V(hx + ox - 0.08, Stations.GANTRY_Y - 0.8, Stations.GANTRY_Z - 0.08), V(hx + ox + 0.08, Stations.GANTRY_Y, Stations.GANTRY_Z + 0.08), C(52, 54, 66)) end
	g:part('HazardSign', V(1.25, 1.25, 0.12), CFrame.new(hx, Stations.GANTRY_Y - 1.5, Stations.GANTRY_Z) * CFrame.Angles(0, 0, math.pi / 4), C(216, 180, 74))
	g:part('HazardSignMark', V(0.22, 0.6, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.4, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	g:part('HazardSignDot', V(0.22, 0.22, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.9, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	-- Main: a big toxic barrel with a target face, on a pallet and two stamped crates.
	local mz = 6.0
	g:box('Pallet', V(-1.05, Y, mz - 1.05), V(1.05, Y + 0.35, mz + 1.05), C(150, 105, 60))
	local crate = g:box('Crate', V(-0.95, Y + 0.35, mz - 0.95), V(0.95, Y + 2.35, mz + 0.95), navy)
	Stations.stamp(crate, Stations.SIDES, 1.9, 2.0, C(70, 104, 72))
	local crate2 = g:part('Crate', V(1.6, 1.8, 1.6), CFrame.new(0.05, Y + 3.25, mz) * CFrame.Angles(0, math.rad(8), 0), dark)
	Stations.stamp(crate2, Stations.SIDES, 1.6, 1.8, C(70, 104, 72))
	local base = Y + 4.15
	local sw, drum = Stations.target(k, CFrame.new(0, base, mz + 0.95), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	drum:SetAttribute('TipMin', 0) -- (rocks back on its back edge, never into the crate)
	Stations.drum(sw, V(0, base, mz), 0.95, 2.5, green, navy, C(64, 96, 62), M.SmoothPlastic)
	Stations.bullseye(sw, CFrame.new(0, base + 1.25, mz - 1.02), 0.75, { C(236, 228, 214), navy, green }, { M.SmoothPlastic, M.SmoothPlastic, M.SmoothPlastic })
	-- Green bottles on a little shelf (they shatter), and a barrel on the floor.
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), navy) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), navy)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', green)
		Stations.bottle(s2, b, 0.95, C(126, 184, 110), { label = navy, stripe = green, material = M.Glass })
	end
	local s3, floorDrum = Stations.target(k, CFrame.new(2.7, Y, 5.26), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	floorDrum:SetAttribute('TipMin', 0)
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, green, navy, C(64, 96, 62), M.SmoothPlastic)
	-- Glassy green puddles on the dark mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), C(118, 166, 98), M.Glass, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane: a big gold gong with an oxblood ring (main) in a brass ring on an oxblood-velvet walnut
-- backstop with brass trim and brass rays (the gold reads off the dark velvet), warm-white strip lights on
-- oxblood up the gantry, a turning crown on the beam, gold bottles on a brass shelf, a gold plate on a post,
-- gold nuggets on a camel rug and a velvet band on the bench (a quiet VIP lounge rather than a gold blast).
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, brass = C(227, 169, 63), C(184, 134, 58), C(244, 236, 220), C(168, 52, 60), Stations.Kit.brass
	local velvet, rays = Stations.Kit.oxblood, Stations.Kit.brassLight
	Stations.gantry(g, t, C(255, 227, 179), { width = 0.16, backing = velvet, cap = Stations.Kit.brass })
	g:box('CrownPlinth', V(-0.5, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.4), V(0.5, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z + 0.4), velvet)
	Stations.crown(g, CFrame.new(0, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z))
	-- Wall: a walnut body with an oxblood velvet field on the shooter's face, brass trim, brass rays behind a
	-- brass ring round a darker velvet disc, two small gems.
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.4
	Stations.wall(back, t, Stations.Kit.walnut, M.Wood, h)
	local groove = C(78, 30, 32)
	for _, f in { { 4.05, 0.6, Y + h - 0.25, 0.04 }, { 2.65, Y + h + 0.12, Y + h + 0.62, -0.11 }, { 1.25, Y + h + 0.92, Y + h + 1.22, -0.26 } } do
		local face = back:box('Velvet', V(-f[1], f[2], z - f[4]), V(f[1], f[3], z - f[4] + 0.1), velvet, M.Fabric)
		Stations.panelX(back, face, CFrame.new(0, (f[2] + f[3]) / 2, z - f[4]), 2 * f[1], f[3] - f[2], f[1] > 3 and 5 or 4, groove)
	end
	Stations.wallLines(back, h, rays, M.SmoothPlastic, 0.3)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 4.2, 0.12, rays)
	local ring = Stations.disc(back, 'VelvetRim', CFrame.new(0, Y + 5.8, z - 0.22), 2.62, 0.14, rays)
	ring.Reflectance = 0.2
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 5.8, z - 0.28), 2.4, 0.14, C(84, 34, 36), M.Fabric)
	for _, s in { { -3.45, 1.2, C(70, 110, 170) }, { 3.45, 1.2, C(70, 140, 100) } } do
		back:part('Gem', V(0.42, 0.42, 0.25), CFrame.new(s[1], Y + s[2], z - 0.08) * CFrame.Angles(0, 0, math.pi / 4), s[3], M.Glass)
	end
	-- Main: the gong.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	-- (A little reflectance on the brass rim: a metal glint in Studio light; the oxblood ring ties it to the velvet.)
	Stations.disc(sw, 'GongRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.03), 2.0, 0.22, deep).Reflectance = 0.2
	Stations.disc(sw, 'Gong', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.75, 0.28, gold)
	Stations.disc(sw, 'GongRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 1.08, 0.32, velvet)
	Stations.disc(sw, 'GongBoss', CFrame.new(0, cy, Stations.GANTRY_Z - 0.1), 0.78, 0.36, gold)
	sw:part('GongRuby', V(0.52, 0.52, 0.3), CFrame.new(0, cy, Stations.GANTRY_Z - 0.3) * CFrame.Angles(0, 0, math.pi / 4), ruby, M.Glass)
	Stations.chains(sw, 0, cy + 1.9, 0.8)
	-- Gold bottles on a brass shelf (left) and a gold plate on a post (right).
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), brass) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), Stations.Kit.walnut, M.Wood)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', gold)
		Stations.bottle(s2, b, 0.95, gold, { label = white, stripe = ruby, cap = ruby })
	end
	g:box('PlatePost', V(2.4, Y, 5.15), V(2.8, Y + 3.0, 5.55), brass)
	local s3 = Stations.target(k, CFrame.new(2.6, Y + 3.0, 5.15), V(2.6, Y + 3.65, 5.05), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(2.6, Y + 3.65, 5.05), 1.3, gold, deep, M.SmoothPlastic, white)
	-- A camel rug with a velvet border over the target field (so the gold nuggets read), and the nuggets on it.
	local rug = studs(g:box('Rug', V(-3.3, Y, 0.4), V(3.3, Y + 0.04, 8.2), C(150, 116, 80), M.Fabric))
	rug.CanCollide = false
	for _, b in { { V(-3.3, Y, 0.4), V(3.3, Y + 0.05, 0.6) }, { V(-3.3, Y, 8.0), V(3.3, Y + 0.05, 8.2) }, { V(-3.3, Y, 0.4), V(-3.1, Y + 0.05, 8.2) }, { V(3.1, Y, 0.4), V(3.3, Y + 0.05, 8.2) } } do
		decor(g:box('RugBorder', b[1], b[2], velvet, M.Fabric)).CastShadow = false
	end
	local d = g:group('Nuggets')
	Stations.nugget(d, -1.9, 1.6, 1.0, 0.4)
	Stations.nugget(d, 1.3, 2.9, 0.9, 1.3)
	Stations.nugget(d, -0.9, 7.7, 0.85, 2.2)
	Stations.nugget(d, 2.9, 7.4, 0.8, 0.9)
end

-- Floating labels over the targets (the reference's three rows): the Power chip, Unlocked/Locked and the big
-- "xN Power". The client rewrites Detail and hides middle-of-row stacks from afar (Lobby.client).
function Stations.labels(st, s, t, at)
	local sign = ghost(st:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(at), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
	g.Size = UDim2.fromScale(8, 4.6)
	g.MaxDistance = 70
	g.LightInfluence = 0
	g.Parent = sign
	local ink = C(15, 15, 25)
	local function text(name, value, color, x, y, w, h, stroke)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		l.Font = FONT.title
		l.Text = value
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 1
		local u = Instance.new('UIStroke')
		u.Color, u.Thickness, u.LineJoinMode = ink, stroke, Enum.LineJoinMode.Round
		u.Parent = l
		l.Parent = g
		return l
	end
	-- Chip: a see-through dark pill with a black outline and the price in white (FREE for the starter).
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.Position, chip.Size = UDim2.fromScale(0.25, 0), UDim2.fromScale(0.5, 0.27)
	chip.BackgroundColor3, chip.BackgroundTransparency = C(20, 22, 34), 0.55
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = chip
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = C(0, 0, 0), 2
	edge.Parent = chip
	chip.Parent = g
	text('Cost', s.Required == 0 and 'FREE' or ('💪 ' .. compact(s.Required)), P.white, 0.27, 0.035, 0.46, 0.2, 2)
	local open = s.Required == 0
	text('Detail', open and 'Unlocked' or 'Locked', open and C(140, 206, 120) or C(217, 119, 106), 0.1, 0.28, 0.8, 0.27, 3)
	text('Power', 'x' .. s.Multiplier .. ' Power', t.text, 0, 0.56, 1, 0.44, 3)
	return sign
end

-- Build station `stationId` (a Skins.Stations id; not Ring) in ctx (see the frame above). Returns the model.
function Stations.build(ctx, stationId, opts)
	opts = opts or {}
	local skins = SKINS or require(ReplicatedStorage.Shared.Config.Skins)
	local s = assert(skins.StationById[stationId], 'unknown station ' .. tostring(stationId))
	local tier = opts.tier
	if not tier then
		for i, row in skins.Stations do if row.Id == stationId then tier = i end end
	end
	tier = math.clamp(tier, 1, #Stations.Themes)
	local t = Stations.Themes[tier]
	local vfxModule = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('HoodVFX')
	local okVfx, VFX = pcall(require, vfxModule)
	if not okVfx then VFX = nil end
	Stations.StampId = VFX and VFX.Textures and VFX.Textures.stamp or ''
	local st, model = ctx:group('Training_' .. stationId)
	model:SetAttribute('Theme', t.name)

	-- Base: the rim, the flat inset mat, a thin plastic inlay inside the rim on shadow (no floor neon).
	Stations.rim(st, t)
	local Y, MX, MZ = Stations.MAT_Y, Stations.HALF_X - 1, Stations.HALF_Z - 1
	local mat = st:box('Mat', V(-MX, 0, -MZ), V(MX, Y, MZ), t.mat, t.matMat or M.Plastic)
	if mat.Material == M.Plastic then studs(mat) end
	if t.edge then
		for _, b in { { V(-MX, Y, -MZ), V(MX, Y + 0.14, -MZ + 0.08) }, { V(-MX, Y, MZ - 0.08), V(MX, Y + 0.14, MZ) }, { V(-MX, Y, -MZ), V(-MX + 0.08, Y + 0.14, MZ) }, { V(MX - 0.08, Y, -MZ), V(MX, Y + 0.14, MZ) } } do
			decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.SmoothPlastic)).CastShadow = false
		end
	end
	-- Where the player stands to train: the shooter's box, from the aisle edge to just short of the bench.
	local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
	Stations.bench(st, t, tier)

	-- Equipment: the stands and gantry (Gear) and the knockable targets (Targets).
	local eq = st:group('Equipment')
	local gear = eq:group('Gear')
	local k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
	local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
	lane(k)
	-- Small things on the gear and every target never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	Stations.labels(st, s, t, Stations.LABEL + V(0, t.labelLift or 0, 0))
	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(k.mainAim or V(0, 4.2, 6))).Position)
	model:SetAttribute('HitColor', t.glow)
	if opts.vfx ~= false and VFX then
		-- The theme's effects fill the target field (not the shooter's box), from the bench to the backstop.
		local z0, z1 = Stations.FIELD_Z0, Stations.FIELD_Z1
		local field = ghost(st:box('Field', V(-MX, Y - 0.05, z0), V(MX, Y, z1), P.white))
		field.CanCollide = false
		local mainPart = k.main and k.main:FindFirstChild('Swing') and k.main.Swing:FindFirstChildWhichIsA('BasePart', true)
		if VFX.theme then
			VFX.theme(field, t.name, V(2 * MX, 10, z1 - z0), { parent = model, tier = tier, color = t.glow, bag = mainPart, burners = k.burners })
		else
			VFX.station(field, tier, t.glow, V(2 * MX, 10, z1 - z0), { parent = model })
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- armory
-- The ARMORY: a calm gun showroom. Ten guns float in profile over dark hexagonal plinths, five on the deck and
-- five on a raised terrace behind them, the back row offset half a pitch so every back gun shows between two
-- front guns, stepping up toward the Diamond Cannon, which sits highest. A cream riser behind the front row and
-- a brick back wall behind the back row (both mid-tone, so dark and light guns both read); a charcoal canopy
-- over the back row hides the downlights. The tier shows in the plinth material (concrete 1-3, black steel 4-5,
-- dark wood and brass 6-7, a gold-framed glass case 8-10), not in colour. The state shows only on a thin ring
-- round the plinth top and on a plate (front row: the plinth's front; back row: the riser, where you buy it).
-- Armory.client paints the states (GunRules.Colors): LOCKED no ring, a padlock, a dimmer gun; NEXT UP the next
-- gun to buy (amber ring, brighter spot and a slow bob once you can afford it); OWNED steel blue; EQUIPPED sage,
-- the only glowing ring. Effects only on 8-10, one small step per gun.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun (Atomic) with attributes GunId,
-- Tier, Cost, Multiplier, Row (1 front, 2 back), holding
--   GunPoint_<Id>  invisible part where you stand to buy: the prompt anchor and the server's distance point
--   StateRing      ring parts (the client colours them; LOCKED paints them the cap colour)
--   StateStrip     the state plate: SurfaceGui StateGui > TextLabel State, Frames NextBar (track) and NextFill
--   StateLock      the padlock parts (hidden unless LOCKED)
--   StateSpot      the downlight (SpotLight) over the gun; StateGlow the soft PointLight under it (EQUIPPED)
--   LabelAnchor    BillboardGui GunLabel > TextLabels Tier (LEGENDARY on 8-10), Name, Multiplier, Price
--                  (+ ImageLabel PriceIcon once the Cash icon is uploaded; Price's Glyph attribute = text icon)
--   Display        Model tagged HoodMotion with the gun (Model Gun) inside; the client sets Bob on it
-- The Armory model is tagged HoodArmory.
-- Local frame: origin at the centre of the front step's foot on the hall floor, front faces -Z (players stand
-- at -Z looking +Z), footprint x -29.4..29.4, z 0..31.2 (Armory.HalfWidth, Armory.Depth), at most 21 tall.
local Armory = {}

Armory.HalfWidth, Armory.Depth = 29.4, 31.2
Armory.Pitch = 11.2 -- gun to gun along a row; the back row sits half a pitch over
Armory.Floor = 0.6 -- deck top (two 0.3 rises up from the hall floor)
Armory.Terrace = 7.0 -- back terrace top
Armory.RiserZ, Armory.WallZ = 10.6, 19.5 -- the terrace's front face, the back wall's face
Armory.Rows = {
	{ z = 5.8, y = 0.6, plinth = 1.4, scale = 1, displayH = 3.4, step = 0 },
	{ z = 14.5, y = 7.0, plinth = 1.8, scale = 1.12, displayH = 3.6, step = 0.5 },
}
Armory.Radius = 3.2 -- plinth apothem (centre to a flat side); flats face -Z
Armory.Float = 0.6 -- gap between a plinth top and its gun
Armory.MaxLength = 6.8
Armory.Tilt, Armory.Yaw = 12, 12 -- degrees: muzzle up, and turned away from the walkway (a 3/4 view)
Armory.CanopyY = 19.2
Armory.LabelH = 2.7
Armory.Font = Enum.Font.GothamBlack

-- BRIEF6 palette (plus the darker tones the plinths need).
Armory.K = {
	charcoal = C(60, 66, 76), ink = C(43, 47, 54), graphite = C(52, 54, 58), cream = C(229, 220, 203),
	brick = C(146, 96, 80), wood = C(165, 122, 88), woodDark = C(92, 64, 46), deck = C(166, 158, 146),
	concrete = C(128, 123, 116), steel = C(78, 84, 94), chrome = C(188, 192, 198), brass = C(176, 138, 70),
	gold = C(227, 169, 63), black = C(34, 37, 42), glass = C(206, 222, 228), warm = C(255, 227, 179),
	spot = C(255, 228, 196), outline = C(28, 30, 36), white = C(246, 243, 237), power = C(255, 212, 110),
}

-- Plinth looks per tier band: the material carries the tier, colour stays for the state.
function Armory.tierLook(tier)
	local K = Armory.K
	if tier <= 3 then
		return { name = 'Street', body = K.concrete, bodyMat = M.Concrete, trim = K.charcoal, trimMat = M.Metal }
	elseif tier <= 5 then
		return { name = 'Pro', body = K.steel, bodyMat = M.DiamondPlate, trim = K.chrome, trimMat = M.Metal } -- (gunmetal, not black: no voids in the row)
	elseif tier <= 7 then
		return { name = 'Elite', body = K.woodDark, bodyMat = M.Wood, trim = K.brass, trimMat = M.Metal }
	end
	return { name = 'Legendary', body = K.black, bodyMat = M.SmoothPlastic, trim = K.gold, trimMat = M.Metal, case = true }
end

-- Optional modules made by other builders (Shared.Models.GunModels / IconModels): nil when missing or broken.
function Armory.optional(name)
	local shared = ReplicatedStorage:FindFirstChild('Shared')
	local models = shared and shared:FindFirstChild('Models')
	local m = shared and (shared:FindFirstChild(name) or (models and models:FindFirstChild(name)))
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end

-- Hexagonal prism (flat sides facing ±Z): three boxes turned 60 degrees apart, each 2r*tan(30) wide.
function Armory.hex(c, name, x, z, r, y0, y1, color, material)
	local w = 2 * r * math.tan(math.pi / 6)
	local parts = {}
	for k = 0, 2 do
		table.insert(parts, c:part(name, V(w, y1 - y0, 2 * r), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 3, 0), color, material))
	end
	return parts
end
-- Six bars along a hexagon's sides, outer edge at apothem a, `w` wide (a ring or a frame).
function Armory.hexRing(c, name, x, z, a, y0, y1, w, color, material)
	local side = 2 * a * math.tan(math.pi / 6)
	local parts = {}
	for k = 0, 5 do
		local cf = CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0, -(a - w / 2))
		table.insert(parts, c:part(name, V(side, y1 - y0, w), cf, color, material))
	end
	return parts
end

-- Box of a model's visible parts in `frame` space: lo, hi corners.
function Armory.extents(model, frame)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, y, z, a, b, cc, d, e, f, g, h, i = frame:ToObjectSpace(p.CFrame):GetComponents()
			local s = p.Size
			local hx = (math.abs(a) * s.X + math.abs(b) * s.Y + math.abs(cc) * s.Z) / 2
			local hy = (math.abs(d) * s.X + math.abs(e) * s.Y + math.abs(f) * s.Z) / 2
			local hz = (math.abs(g) * s.X + math.abs(h) * s.Y + math.abs(i) * s.Z) / 2
			lo = V(math.min(lo.X, x - hx), math.min(lo.Y, y - hy), math.min(lo.Z, z - hz))
			hi = V(math.max(hi.X, x + hx), math.max(hi.Y, y + hy), math.max(hi.Z, z + hz))
		end
	end
	if lo.X == math.huge then return V(-0.5, -0.5, -0.5), V(0.5, 0.5, 0.5) end
	return lo, hi
end

-- A model's pivot without relying on GetPivot (works the same in Studio and the preview harness).
function Armory.pivotOf(model)
	local pp = model.PrimaryPart
	if pp then return pp.CFrame * pp.PivotOffset end
	local ok, pivot = pcall(function() return model.WorldPivot end)
	return ok and pivot or CFrame.new()
end
-- Moves every part so the model's pivot lands on `target`.
function Armory.place(model, target)
	local delta = target * Armory.pivotOf(model):Inverse()
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end
	end
	if not model.PrimaryPart then model.WorldPivot = target end
end

-- Stand-in gun while GunModels is missing: a chunky blocky gun in the contract's frame (grip at the origin,
-- muzzle toward -Z, up +Y; a pistol is about 1.6 long). Longer guns get a stock.
function Armory.placeholder(gun, scale)
	local s = scale or 1
	local model = Instance.new('Model')
	model.Name = gun.Id
	local long = ({ Shotgun = 3.4, Tommy = 3.2, AK = 3.4, Minigun = 3.8, Blaster = 2.8, Diamond = 4 })[gun.Id]
	local len = long or (gun.Id == 'Uzi' and 2 or gun.Id == 'Deagle' and 1.9 or 1.6)
	local dark, metal = C(62, 66, 78), C(150, 156, 168)
	local function add(name, size, cf, color, material, shape)
		local p = Instance.new('Part')
		p.Name = name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Size = size * s
		p.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		p.Color = color
		p.Material = material or M.SmoothPlastic
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end
	local front = -len + 0.35
	local grip = add('Grip', V(0.3, 0.75, 0.42), CFrame.new(0, -0.22, 0.12) * CFrame.Angles(math.rad(-14), 0, 0), long and C(132, 82, 48) or dark, long and M.Wood or M.SmoothPlastic)
	add('Body', V(0.34, 0.44, len), CFrame.new(0, 0.32, front / 2 + 0.3), dark)
	add('Stripe', V(0.36, 0.12, len * 0.7), CFrame.new(0, 0.38, front / 2 + 0.2), gun.Color, M.SmoothPlastic)
	add('Barrel', V(0.34, 0.2, 0.2), CFrame.new(0, 0.3, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0), metal, M.Metal, Enum.PartType.Cylinder)
	add('Guard', V(0.12, 0.22, 0.36), CFrame.new(0, -0.02, -0.22), dark)
	add('Sight', V(0.1, 0.1, 0.16), CFrame.new(0, 0.58, front + 0.12), metal, M.Metal)
	if long then
		add('Stock', V(0.3, 0.5, 0.9), CFrame.new(0, 0.18, 0.8), C(132, 82, 48), M.Wood)
		add('Mag', V(0.26, 0.6, 0.3), CFrame.new(0, -0.12, front / 2 + 0.2), dark)
	end
	model.PrimaryPart = grip
	grip.PivotOffset = grip.CFrame:Inverse() -- the model's pivot is the origin, as GunModels promises
	return model
end

-- The display gun (GunModels.build, else the stand-in), scaled up to read across the hall: small guns grow more
-- than big ones (display length ~ natural length^0.5), 3% more per tier, at most MaxLength (x the row's scale):
-- a pistol about 4.5 studs, the long guns 6.8.
function Armory.gun(gun, shrink)
	local models = Armory.optional('GunModels')
	local function make(scale)
		if models and models.build then
			local ok, model = pcall(models.build, gun.Id, scale)
			if ok and model then return model end
		end
		return Armory.placeholder(gun, scale)
	end
	local model = make(1)
	local lo, hi = Armory.extents(model, Armory.pivotOf(model))
	local size = hi - lo
	local longest = math.max(size.X, size.Y, size.Z, 0.1)
	local length = math.min(Armory.MaxLength, 3.7 * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.CastShadow = false -- (a floating gun's shadow on its own plinth only reads as a dark blot)
		end
	end
	return model
end

---------------------------------------------------------------------------------------------- labels
-- One line of label text: one font (GothamBlack) for everything, a dark outline, no wrapping (so a long name
-- shrinks instead of breaking onto two lines).
function Armory.text(gui, name, value, color, y, h, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0, y)
	t.Size = UDim2.fromScale(1, h)
	t.Font = Armory.Font
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = false
	t.TextStrokeTransparency = 1
	local s = Instance.new('UIStroke')
	s.Color = Armory.K.outline
	s.Thickness = thickness or 2.5
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	t.Parent = gui
	return t
end

-- The nameplate over a gun: a small gold LEGENDARY on the top three, the name in white, "xN POWER" in warm
-- yellow almost as big, then the price (soft red until you can afford it, green after; the client swaps in
-- OWNED / EQUIPPED once it's yours). The plate is as wide as its name needs, so every name prints at one size.
-- `bottom` is where the plate's bottom edge sits.
function Armory.label(c, x, bottom, z, gun, state)
	local H = Armory.LabelH
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(x, bottom + H / 2, z), P.white))
	anchor.CastShadow = false
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	g.Size = UDim2.fromScale(math.max(5.6, 0.58 * #gun.Name), H)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Parent = anchor
	local K = Armory.K
	Armory.text(g, 'Tier', gun.Tier >= 8 and 'LEGENDARY' or '', K.gold, 0, 0.15, 2)
	Armory.text(g, 'Name', gun.Name, K.white, 0.16, 0.32, 3)
	Armory.text(g, 'Multiplier', 'x' .. gun.Multiplier .. ' POWER', K.power, 0.5, 0.27, 3)
	local icons = Armory.optional('IconModels')
	local image = icons and icons.Images and icons.Images.Cash
	local colors = Armory.colors
	local word = state == 'Equipped' and 'EQUIPPED' or state == 'Owned' and 'OWNED' or compact(gun.Cost)
	local color = (state == 'Equipped' or state == 'Owned') and colors[state].Text or colors.Price.Short
	local price = Armory.text(g, 'Price', word, color, 0.79, 0.21, 2.5)
	if type(image) == 'string' and image ~= '' then
		-- The uploaded Cash icon on the left, the words left-aligned beside it (the client hides it once owned).
		local i = Instance.new('ImageLabel')
		i.Name = 'PriceIcon'
		i.BackgroundTransparency = 1
		i.Image = image
		i.Position = UDim2.fromScale(0.3, 0.79)
		i.Size = UDim2.fromScale(0.12, 0.21)
		i.Visible = state ~= 'Equipped' and state ~= 'Owned'
		local a = Instance.new('UIAspectRatioConstraint')
		a.Parent = i
		i.Parent = g
		price.Position = UDim2.fromScale(0.42, 0.79)
		price.Size = UDim2.fromScale(0.5, 0.21)
		price.TextXAlignment = Enum.TextXAlignment.Left
		price:SetAttribute('Glyph', '')
	else
		price:SetAttribute('Glyph', '💵')
		if state ~= 'Equipped' and state ~= 'Owned' then price.Text = '💵 ' .. word end
	end
	return anchor
end

---------------------------------------------------------------------------------------------- the state plate
-- A charcoal enamel plate with the state word, a padlock (LOCKED) and a thin fill bar (NEXT UP: your Cash
-- against the price). `cf` is the plate's centre, its front facing -Z.
function Armory.plate(c, cf, width, look, word)
	local K = Armory.K
	local strip = c:part('StateStrip', V(width, 0.62, 0.08), cf, look.Strip, M.SmoothPlastic)
	decor(strip).CastShadow = false
	local sg = surface(strip, Enum.NormalId.Front, 60)
	sg.Name = 'StateGui'
	local t = Instance.new('TextLabel')
	t.Name = 'State'
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.2, 0.12)
	t.Size = UDim2.fromScale(0.72, 0.62)
	t.Font = Armory.Font
	t.Text = word
	t.TextColor3 = look.Text
	t.TextScaled = true
	t.Parent = sg
	local bar = Instance.new('Frame')
	bar.Name = 'NextBar'
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = K.charcoal:Lerp(K.ink, 0.5)
	bar.Position = UDim2.fromScale(0.2, 0.8)
	bar.Size = UDim2.fromScale(0.72, 0.1)
	bar.Visible = word == 'NEXT UP'
	bar.Parent = sg
	-- (the fill lies over the track as its sibling: the client sets its width to Cash / price of the track's)
	local fill = Instance.new('Frame')
	fill.Name = 'NextFill'
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Armory.colors.Next.Top
	fill.Position = bar.Position
	fill.Size = UDim2.fromScale(0, 0.1)
	fill.Visible = bar.Visible
	fill.ZIndex = 2
	fill.Parent = sg
	-- The padlock, part-built on the plate's left (it reads on low graphics too).
	local lockCf = cf * CFrame.new(width / 2 - 0.36, -0.04, -0.06) -- (+X is the viewer's left)
	local grey = C(150, 153, 158)
	local shown = word == 'LOCKED' and 0 or 1
	for _, d in { { V(0.34, 0.26, 0.06), CFrame.new(0, -0.02, 0) }, { V(0.05, 0.16, 0.05), CFrame.new(-0.11, 0.17, 0) },
		{ V(0.05, 0.16, 0.05), CFrame.new(0.11, 0.17, 0) }, { V(0.27, 0.05, 0.05), CFrame.new(0, 0.25, 0) } } do
		local p = decor(c:part('StateLock', d[1], lockCf * d[2], grey, M.Metal))
		p.CastShadow = false
		p.Transparency = shown
	end
	return strip
end

---------------------------------------------------------------------------------------------- one slot
-- One gun on its plinth: `x` along the row, `row` one of Armory.Rows (its z, deck height, plinth height, gun size),
-- `lift` raises a back-row plinth (the ladder steps up toward #10), `rowIndex` 1 front / 2 back.
function Armory.slot(c, gun, x, row, lift, rowIndex)
	local K = Armory.K
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	model:SetAttribute('Row', rowIndex)
	-- First paint = a new player's view (the pistol equipped, the revolver next); the client repaints.
	local state = gun.Cost == 0 and 'Equipped' or (gun.Tier == 2 and 'Next' or 'Locked')
	local colors = Armory.colors
	local look = colors[state]
	local tier = Armory.tierLook(gun.Tier)
	local z, r = row.z, Armory.Radius
	local y0 = row.y + lift
	local top = y0 + row.plinth
	-- The plinth: a dark foot, the tier body, a trim band, a matte graphite cap with a lip, the state ring inlaid in
	-- the cap (and, on the raised back row, a thin band round the cap's edge too, so it reads from below).
	if lift > 0 then
		Armory.hex(s, 'PlinthRiser', x, z, r + 0.1, row.y, y0, K.charcoal, M.Metal)
	end
	Armory.hex(s, 'PlinthFoot', x, z, r + 0.18, y0, y0 + 0.18, K.ink, M.SmoothPlastic)
	Armory.hex(s, 'PlinthBody', x, z, r, y0 + 0.18, top - 0.36, tier.body, tier.bodyMat)
	Armory.hex(s, 'PlinthTrim', x, z, r + 0.04, top - 0.36, top - 0.2, tier.trim, tier.trimMat)
	Armory.hex(s, 'PlinthCap', x, z, r + 0.12, top - 0.2, top, K.graphite, M.Slate)
	local ringColor = state == 'Locked' and K.graphite or look.Top
	local ringMat = state == 'Equipped' and M.Neon or M.SmoothPlastic
	local ring = Armory.hexRing(s, 'StateRing', x, z, r - 0.25, top - 0.02, top + 0.05, 0.3, ringColor, ringMat)
	if rowIndex == 2 then
		for _, p in Armory.hex(s, 'StateRing', x, z, r + 0.15, top - 0.17, top - 0.05, ringColor, ringMat) do table.insert(ring, p) end
	end
	for _, p in ring do decor(p).CastShadow = false end
	-- The gun floating over the plinth in profile to the hall (muzzle to the viewer's right), tilted up a little
	-- and turned a little away from the walkway; still, unless the client makes it bob (NEXT UP, EQUIPPED).
	local d, display = s:group('Display')
	local tilt, yaw = math.rad(Armory.Tilt), math.rad(Armory.Yaw)
	local function measure(m)
		local lo, hi = Armory.extents(m, Armory.pivotOf(m))
		return lo, hi, (hi.Y - lo.Y) * math.cos(tilt) + (hi.Z - lo.Z) * math.sin(tilt)
	end
	local k = row.scale * (gun.Tier >= 8 and 1 + 0.04 * (gun.Tier - 8) or 1)
	local g = Armory.gun(gun, k)
	local lo, hi, tall = measure(g)
	if tall > row.displayH then
		-- a deep gun (the Uzi's long magazine) stands too tall when tilted: a size smaller, under the nameplate
		g:Destroy()
		g = Armory.gun(gun, k * row.displayH / tall)
		lo, hi, tall = measure(g)
	end
	local mid = (lo + hi) / 2
	local centre = V(x, top + Armory.Float + tall / 2, z)
	local pose = CFrame.new(centre) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, -tilt) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:AddTag('HoodMotion')
	if state == 'Equipped' then
		display:SetAttribute('Bob', 0.15)
		display:SetAttribute('BobPeriod', 4.5)
	end
	-- The soft glow under the equipped gun (the client switches it), and the downlight over the gun: on the back
	-- row hidden in the canopy straight above, on the front row a small spot on the canopy's edge aimed at it.
	local glow = ghost(s:part('StateGlowSource', V(0.2, 0.2, 0.2), CFrame.new(x, top + 0.3, z), P.white))
	glow.CastShadow = false
	local pl = light(glow, look.Glow, 0.5, 7)
	pl.Name = 'StateGlow'
	pl.Enabled = state == 'Equipped'
	local aim = V(x, centre.Y, z)
	local from = rowIndex == 2 and V(x, Armory.CanopyY - 0.25, z) or V(x, Armory.CanopyY - 0.45, Armory.RiserZ + 0.75)
	-- (straight down for the back row: lookAt is undefined along the up axis, so turn the front face down by hand)
	local aimCf = rowIndex == 2 and CFrame.new(from) * CFrame.Angles(-math.pi / 2, 0, 0) or CFrame.lookAt(from, aim)
	local fixture = s:part('StateSpotFixture', V(0.42, 0.42, 0.5), aimCf, K.charcoal, M.Metal)
	decor(fixture).CastShadow = false
	if rowIndex == 2 then fixture.Transparency = 1 end
	local spot = Instance.new('SpotLight')
	spot.Name = 'StateSpot'
	spot.Face = Enum.NormalId.Front
	spot.Color = K.spot
	spot.Brightness = state == 'Locked' and 0.6 or 1
	spot.Range = (from - aim).Magnitude + 6
	spot.Angle = 40
	spot.Shadows = false
	spot.Parent = fixture
	if rowIndex == 1 then
		-- the fixture's warm lens
		local lens = decor(s:part('StateSpotLens', V(0.3, 0.3, 0.04), aimCf * CFrame.new(0, 0, -0.26), K.warm, M.Neon))
		lens.CastShadow = false
	end
	-- Legendary: a gold-framed glass case on the plinth, then one more small step per gun.
	local caseTop = tier.case and Armory.case(s, gun, x, z, top, tall) or top
	-- The nameplate: one height per row (stepping with the back-row plinths), above the tallest gun a row allows
	-- (and above a case's gold rim).
	Armory.label(s, x, math.max(top + Armory.Float + row.displayH + 0.45, caseTop + 0.35), z, gun, state)
	-- The state plate and the buy point. Front row: the plate on the plinth's front, you stand before it. Back row:
	-- the plate on the riser under the gun, at the end of the aisle between two front plinths, where you buy it.
	local word = state == 'Equipped' and 'EQUIPPED' or state == 'Next' and 'NEXT UP' or 'LOCKED'
	local point
	if rowIndex == 1 then
		Armory.plate(s, CFrame.new(x, y0 + 0.18 + (row.plinth - 0.54) / 2, z - r - 0.04), 2.9, look, word)
		point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.5, Armory.Floor + 0.5, z - r - 1.6), V(x + 0.5, Armory.Floor + 1.5, z - r - 0.6), P.white))
	else
		-- (seated on the riser's wood rail at the aisle's end: all ten plates make one low band under the nameplates)
		local pz, py = Armory.RiserZ, Armory.Floor + 1.66
		Armory.plate(s, CFrame.new(x, py, pz - 0.15), 3.2, look, word)
		-- a charcoal bracket round the plate, so it reads as a fitted tag, not a sticker
		decor(s:box('StateStripFrame', V(x - 1.72, py - 0.39, pz - 0.16), V(x + 1.72, py + 0.39, pz), K.charcoal, M.Metal)).CastShadow = false
		point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.5, Armory.Floor + 0.8, pz - 1.4), V(x + 0.5, Armory.Floor + 1.8, pz - 0.4), P.white))
	end
	point.CastShadow = false
	return model
end

-- The top three's glass case: gold edges and rings, six glass sides, then their small steps up: #9 a few slow
-- gold sparkles, #10 also a faint shaft of light from the canopy.
function Armory.case(s, gun, x, z, top, tall)
	local K = Armory.K
	local a, h = Armory.Radius - 0.1, Armory.Float + tall + 0.5
	local side = 2 * a * math.tan(math.pi / 6)
	for k = 0, 5 do
		local rot = CFrame.new(x, top, z) * CFrame.Angles(0, k * math.pi / 3, 0)
		local pane = decor(s:part('CaseGlass', V(side - 0.1, h - 0.2, 0.06), rot * CFrame.new(0, h / 2, -a + 0.1), K.glass, M.Glass))
		pane.Transparency = 0.78
		pane.CastShadow = false
		-- a gold edge at each corner
		local corner = rot * CFrame.Angles(0, math.pi / 6, 0) * CFrame.new(0, h / 2, -(a / math.cos(math.pi / 6)) + 0.08)
		decor(s:part('CaseFrame', V(0.14, h, 0.14), corner, K.gold, M.Metal)).CastShadow = false
	end
	for _, p in Armory.hexRing(s, 'CaseFrame', x, z, a + 0.02, top + h - 0.12, top + h, 0.16, K.gold, M.Metal) do decor(p).CastShadow = false end
	for _, p in Armory.hexRing(s, 'CaseFrame', x, z, a + 0.02, top, top + 0.12, 0.16, K.gold, M.Metal) do decor(p).CastShadow = false end
	if gun.Tier >= 9 then
		local src = ghost(s:part('CaseSparkles', V(a * 1.2, tall, a * 0.8), CFrame.new(x, top + Armory.Float + tall / 2, z), K.gold))
		src.CastShadow = false
		local e = Instance.new('ParticleEmitter')
		e.Name = 'Sparkle'
		e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
		e.Rate = gun.Tier >= 10 and 4 or 2.5
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(0.1, 0.4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.28), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.15)
		e.Color = ColorSequence.new(C(255, 236, 170), K.gold)
		e.LightEmission = 0.4
		e.LightInfluence = 0
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Parent = src
	end
	if gun.Tier >= 10 then
		local hi = ghost(s:part('CaseShaftTop', V(0.2, 0.2, 0.2), CFrame.new(x, Armory.CanopyY - 0.1, z), P.white))
		local lo = ghost(s:part('CaseShaftBottom', V(0.2, 0.2, 0.2), CFrame.new(x, top + 0.2, z), P.white))
		hi.CastShadow, lo.CastShadow = false, false
		local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
		a0.Parent, a1.Parent = hi, lo
		local b = Instance.new('Beam')
		b.Name = 'Shaft'
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = 2.2, 4.6
		b.FaceCamera = true
		b.Segments = 1
		b.LightEmission = 0.6
		b.LightInfluence = 0
		b.Color = ColorSequence.new(C(255, 238, 200))
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.96), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 0.9) })
		b.Parent = hi
	end
	return top + h
end

---------------------------------------------------------------------------------------------- the room
-- The deck (warm grey, a wood-nosed half step in front, a charcoal kerb), the terrace (a cream riser with a
-- charcoal skirting and a wood cap), the brick back wall with charcoal pilasters between the back bays, the
-- charcoal canopy over the back row with a warm LED strip under its edge, and two slim posts at its corners.
function Armory.base(c)
	local K = Armory.K
	local b = c:group('ArmoryBase')
	local X, D, F, T = Armory.HalfWidth, Armory.Depth, Armory.Floor, Armory.Terrace
	local RZ, WZ, CY = Armory.RiserZ, Armory.WallZ, Armory.CanopyY
	-- deck: a half step (wood tread, charcoal face) then the deck itself
	b:box('ArmoryStep', V(-X, 0, 0), V(X, F / 2 - 0.08, 0.9), K.charcoal, M.Metal)
	b:box('ArmoryStepTread', V(-X, F / 2 - 0.08, 0), V(X, F / 2, 0.9), K.wood, M.Wood)
	b:box('ArmoryDeckFace', V(-X, 0, 0.9), V(X, F - 0.08, RZ), K.charcoal, M.Metal)
	b:box('ArmoryDeck', V(-X + 0.3, F - 0.08, 0.9), V(X - 0.3, F, RZ), K.deck, M.SmoothPlastic)
	b:box('ArmoryDeckEdge', V(-X, F - 0.08, 0.9), V(X, F + 0.02, 1.15), K.wood, M.Wood)
	for _, sx in { -1, 1 } do
		b:box('ArmoryDeckEdge', V(sx * X, F - 0.08, 0.9), V(sx * (X - 0.3), F + 0.02, RZ), K.charcoal, M.Metal)
	end
	-- terrace: charcoal skirting, cream riser, a wood cap with a small lip; cream ends with charcoal corners
	b:box('TerraceSkirt', V(-X, F, RZ - 0.1), V(X, F + 0.45, WZ), K.charcoal, M.Metal)
	b:box('TerraceRiser', V(-X, F + 0.45, RZ), V(X, T - 0.3, WZ), K.cream, M.SmoothPlastic)
	b:box('TerraceCap', V(-X, T - 0.3, RZ - 0.2), V(X, T, WZ), K.wood, M.Wood)
	b:box('TerraceGap', V(-X, T - 0.42, RZ - 0.03), V(X, T - 0.3, RZ), K.charcoal, M.SmoothPlastic)
	b:box('TerraceRail', V(-X, F + 1.0, RZ - 0.12), V(X, F + 1.25, RZ), K.wood, M.Wood)
	b:box('TerraceTop', V(-X + 0.2, T, RZ + 0.1), V(X - 0.2, T + 0.02, WZ), K.deck, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		b:box('TerraceCorner', V(sx * (X - 0.35), F, RZ - 0.15), V(sx * (X + 0.05), T - 0.3, RZ + 0.25), K.charcoal, M.Metal)
	end
	-- back wall: brick from the terrace to the canopy (a solid block back to the hall wall)
	b:box('BackWall', V(-X, 0, WZ), V(X, CY, D), K.brick, M.Brick)
	b:box('BackWallBase', V(-X, T, WZ - 0.15), V(X, T + 0.5, WZ), K.charcoal, M.Metal)
	-- pilasters between the back bays (at the front guns' x) and at the ends
	local p = Armory.Pitch
	for k = 0, 4 do
		local px = 2.25 * p - k * p
		b:box('BackPilaster', V(px - 0.4, T, WZ - 0.35), V(px + 0.4, CY, WZ), K.charcoal, M.Metal)
	end
	for _, sx in { -1, 1 } do
		b:box('BackPilaster', V(sx * (X - 0.8), T, WZ - 0.35), V(sx * X, CY, WZ), K.charcoal, M.Metal)
	end
	-- the narrow bay past the back row's start: a small cream board saying where Cash comes from
	local bx0, bx1 = 2.25 * p + 0.4, X - 0.8
	local bc = (bx0 + bx1) / 2
	b:box('CashBoardFrame', V(bx0 + 0.1, T + 3.0, WZ - 0.25), V(bx1 - 0.1, T + 8.2, WZ), K.charcoal, M.Metal)
	local board = b:box('CashBoard', V(bx0 + 0.25, T + 3.15, WZ - 0.32), V(bx1 - 0.25, T + 8.05, WZ - 0.25), K.cream, M.SmoothPlastic)
	local sg = surface(board, Enum.NormalId.Front, 40)
	local function words(name, text, color, y, h)
		local t = Instance.new('TextLabel')
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.08, y)
		t.Size = UDim2.fromScale(0.84, h)
		t.Font = Armory.Font
		t.Text = text
		t.TextColor3 = color
		t.TextScaled = true
		t.Parent = sg
	end
	-- (big stacked words: the board is narrow and read from the hall)
	words('Line1', 'CLEAR', K.ink, 0.06, 0.2)
	words('Line2', 'GATES', K.ink, 0.27, 0.2)
	words('Line3', 'FOR', K.charcoal, 0.5, 0.13)
	words('Line4', 'CASH', K.gold, 0.66, 0.24)
	-- canopy over the back row and the wall, with a fascia and a warm LED strip under its front edge
	b:box('Canopy', V(-X, CY, RZ + 0.4), V(X, CY + 0.5, D), K.charcoal, M.Metal)
	b:box('CanopyFascia', V(-X, CY - 0.5, RZ + 0.4), V(X, CY + 0.7, RZ + 0.75), K.charcoal, M.Metal)
	b:box('CanopySoffit', V(-X, CY - 0.06, RZ + 0.75), V(X, CY, WZ), K.ink, M.SmoothPlastic)
	decor(b:box('CanopyLED', V(-X, CY - 0.62, RZ + 0.62), V(X, CY - 0.5, RZ + 0.78), K.warm, M.Neon)).CastShadow = false
	for _, sx in { -1, 1 } do
		b:box('CanopyPost', V(sx * (X - 0.55), T, RZ + 0.45), V(sx * (X - 0.05), CY - 0.5, RZ + 0.95), K.charcoal, M.Metal)
	end
	for _, part in b.parent:GetDescendants() do
		if part:IsA('BasePart') and (part.Name:match('^Canopy') or part.Name == 'TerraceTop') then part.CastShadow = false end
	end
	return b
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local rules = require(ReplicatedStorage.Shared.GunRules)
	-- (falls back to the plain three states if GunRules has no NEXT UP / price colours yet)
	local colors = rules.Colors
	Armory.colors = {
		Locked = colors.Locked, Owned = colors.Owned, Equipped = colors.Equipped,
		Next = colors.Next or colors.Locked,
		Price = colors.Price or { Afford = C(126, 214, 155), Short = C(224, 112, 112) },
	}
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.base(a)
	local p = Armory.Pitch
	for i, gun in guns do
		local rowIndex = (i - 1) // 5 + 1
		local row = Armory.Rows[rowIndex]
		if not row then break end
		local col = (i - 1) % 5
		-- Gun 1 stands on the viewer's left (+X when looking toward +Z); the back row sits half a pitch to the
		-- right, so #6 shows between #1 and #2 ... and #10 stands past #5, the last and highest step.
		local x = 2.25 * p - col * p - (rowIndex - 1) * p / 2
		Armory.slot(a, gun, x, row, row.step * col, rowIndex)
	end
	return model
end
---------------------------------------------------------------------------------------------- buildings
-- Building frame: origin at the front-left corner on the ground, +X along the walk, +Z out of the facade
-- toward the middle. One builder serves both sides of the map.
-- Streets: the street kit's shared helpers (signs, the calm shop recipe), also used by the stages (f2).
local Streets = {}
local function lotFrame(ctx, s, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-FRONT, 0, za), V(-FRONT - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(FRONT, 0, za - w), V(FRONT + 1, 0, za - w)))
end
local function storeyY(f) return f == 1 and 0 or 12 + (f - 2) * 10 end
local function roofOf(floors) return 12 + (floors - 1) * 10 end
local function bays(w, n)
	local t = {}
	for k = 1, n do table.insert(t, w * (k - 0.5) / n) end
	return t
end

-- Window: cream frame, dark blue-grey glass (a deep "hole") with a mullion, a sill. Some life by position, so
-- neighbours differ and the two sides of the street don't mirror: about 1 in 8 lit warm, 1 in 5 with a cream
-- blind part way down.
local function window(c, x, y, o)
	o = o or {}
	local w, h = o.w or 3.2, o.h or 4.6
	local frame = o.frame or P.frame
	decor(c:box('WindowFrame', V(x - w / 2 - 0.35, y - 0.35, 0), V(x + w / 2 + 0.35, y + h + 0.35, 0.2), frame, M.SmoothPlastic))
	local glass = decor(c:box('Glass', V(x - w / 2, y, 0), V(x + w / 2, y + h, 0.28), P.glass, M.SmoothPlastic))
	glass.Reflectance = 0.15
	local wp = c:world(CFrame.new(x, y, 0)).Position
	local k = (math.sin(wp.X * 12.9898 + wp.Y * 78.233 + wp.Z * 37.719) * 43758.5453) % 1
	if k < 0.12 then glass.Color, glass.Reflectance = C(226, 204, 160), 0
	elseif k < 0.32 then decor(c:box('Blind', V(x - w / 2 + 0.1, y + h * (0.45 + k), 0), V(x + w / 2 - 0.1, y + h, 0.31), P.frame, M.SmoothPlastic)) end
	decor(c:box('Mullion', V(x - 0.12, y, 0), V(x + 0.12, y + h, 0.34), frame, M.SmoothPlastic))
	decor(c:box('Sill', V(x - w / 2 - 0.6, y - 0.75, 0), V(x + w / 2 + 0.6, y - 0.35, 0.7), o.sill or P.stone, M.Concrete))
end
-- Street door with two steps and a small slate awning.
local function door(c, x, color, awning)
	c:box('Step', V(x - 2.6, 0, 0), V(x + 2.6, 0.4, 2.0), P.stone, M.Concrete)
	c:box('Step', V(x - 2.6, 0.4, 0), V(x + 2.6, 0.8, 1.0), P.stone, M.Concrete)
	decor(c:box('DoorFrame', V(x - 2.3, 0.8, 0), V(x + 2.3, 8.6, 0.22), P.frame, M.SmoothPlastic))
	c:box('Door', V(x - 1.7, 0.8, 0), V(x + 1.7, 8.0, 0.45), color or P.door, M.SmoothPlastic)
	decor(c:box('DoorKnob', V(x + 1.0, 4.2, 0.45), V(x + 1.3, 4.5, 0.6), C(196, 160, 96), M.Metal))
	if awning ~= false then
		decor(c:box('DoorAwning', V(x - 3, 9.0, 0), V(x + 3, 9.5, 2.4), awning or P.slate, M.SmoothPlastic))
		decor(c:box('DoorAwningLip', V(x - 3, 8.5, 2.2), V(x + 3, 9.0, 2.4), awning or P.slate, M.SmoothPlastic))
	end
end
-- Windows on a side wall that faces open ground (the spawn plaza). sideAt is 0 or w.
local function sideWindows(c, sideAt, floors, frame)
	local s = c:at(CFrame.new(sideAt, 0, 0) * CFrame.Angles(0, sideAt == 0 and -math.pi / 2 or math.pi / 2, 0))
	local sign = sideAt == 0 and -1 or 1
	for f = 1, floors do
		for _, d in { 7, 15, 23 } do window(s, sign * d, storeyY(f) + 3.4, { frame = frame }) end
	end
end
-- Striped awning from x0 to x1 with its top at y, alternating two colours.
local function stripedAwning(c, x0, x1, y, colors, depth)
	depth = depth or 3.6
	local n = math.max(2, math.floor((x1 - x0) / 1.6))
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		local col = colors[k % #colors + 1]
		decor(c:wedge('Awning', V(b - a, 1.8, depth), CFrame.new((a + b) / 2, y - 0.9, depth / 2) * CFrame.Angles(0, math.pi, 0), col, M.Fabric))
		decor(c:box('AwningValance', V(a, y - 2.9, depth - 0.2), V(b, y - 1.8, depth), col, M.Fabric))
	end
end
-- Flat roof: a grey tar deck behind a parapet with a dark coping along the front (the street sees the crisp
-- dark line, the high views a calm grey roof instead of a black slab).
local function roofCap(c, w, roof, color)
	c:box('RoofCap', V(0, roof, -DEPTH), V(w, roof + 1.0, -0.4), C(128, 126, 122), M.Concrete)
	c:box('RoofCoping', V(0, roof, -0.4), V(w, roof + 1.5, 0.7), color, M.SmoothPlastic)
	decor(c:box('RoofVent', V(w * 0.3 - 1.5, roof + 1.0, -12), V(w * 0.3 + 1.5, roof + 3.0, -8), color:Lerp(P.black, 0.3), M.Metal))
end

-- Zig-zag fire escape over bay x (the hood's signature facade): a diamond-plate landing at every upper floor
-- with a rail and a see-through guard, a stair up to the next landing on alternate sides, a drop ladder.
function Streets.fireEscape(c, x, floors)
	local g = c:group('FireEscape')
	for f = 2, floors do
		local y = storeyY(f)
		decor(g:box('EscapeDeck', V(x - 3.6, y - 0.25, 0.2), V(x + 3.6, y, 2.6), P.iron, M.DiamondPlate))
		decor(g:box('EscapeRail', V(x - 3.6, y + 2.8, 2.45), V(x + 3.6, y + 3.0, 2.65), P.iron, M.Metal))
		for _, sx in { -3.6, 3.4 } do decor(g:box('EscapeRail', V(x + sx, y + 2.8, 0.2), V(x + sx + 0.2, y + 3.0, 2.65), P.iron, M.Metal)) end
		decor(g:box('EscapeGuard', V(x - 3.5, y, 2.5), V(x + 3.5, y + 2.8, 2.55), P.iron, M.DiamondPlate)).Transparency = 0.55
		if f < floors then
			local s = f % 2 == 0 and 1 or -1
			decor(g:bar('EscapeStair', V(x - s * 2.6, y, 1.4), V(x + s * 2.0, storeyY(f + 1), 1.4), 0.45, P.iron, M.Metal))
		end
	end
	decor(g:box('EscapeLadder', V(x + 2.6, storeyY(2) - 4.5, 2.2), V(x + 3.2, storeyY(2) - 0.25, 2.35), P.iron, M.Metal))
	return g
end

-- Red brick walk-up (the concept's asset kit): stone base, slate roof cap, framed windows, green door; about
-- half the walk-ups of three floors or more carry a fire escape.
local function brickBuilding(ctx, w, o)
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local roof = roofOf(o.floors)
	c:box('Wall', V(0, -1, -DEPTH), V(w, roof, 0), o.wall or P.brick, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 1.6, 0.35), P.stone, M.Concrete)
	-- Stone string course over the shop floor and a cornice under the roof: the facade gets a top and a waist.
	decor(c:box('StringCourse', V(0, 11.3, 0), V(w, 11.9, 0.3), P.stone, M.Concrete))
	decor(c:box('Cornice', V(0, roof - 1.1, 0), V(w, roof - 0.3, 0.5), P.stone, M.Concrete))
	roofCap(c, w, roof, P.slate)
	local list = bays(w, o.bays or 3)
	for f = 2, o.floors do for _, x in list do window(c, x, storeyY(f) + 3, {}) end end
	local doorX = o.doorX or list[#list // 2 + 1]
	if o.ground then o.ground(c, w, list)
	else
		for _, x in list do if math.abs(x - doorX) > 3 then window(c, x, 3.4, {}) end end
		door(c, doorX, o.door)
	end
	if o.sideAt then sideWindows(c, o.sideAt, o.floors) end
	if o.floors >= 3 then
		local wp = c:world(CFrame.new(w / 2, 0, 0)).Position
		if (math.sin(wp.X * 3.17 + wp.Z * 0.731) * 9631.7) % 1 < 0.55 then Streets.fireEscape(c, list[1], o.floors) end
	end
	model:SetAttribute('Floors', o.floors)
	return c, model
end

-- Tan apartment block: buff walls, light corner piers and floor bands, a cornice, balconies with black
-- railings on the upper floors.
local function balcony(c, x, y)
	decor(c:box('BalconySlab', V(x - 3.2, y - 0.5, 0), V(x + 3.2, y, 2.8), P.tanLight, M.Concrete))
	decor(c:box('BalconyRail', V(x - 3.2, y + 2.6, 2.5), V(x + 3.2, y + 2.85, 2.8), P.iron, M.Metal))
	for _, sx in { -3.2, 2.95 } do decor(c:box('BalconyRail', V(x + sx, y + 2.6, 0), V(x + sx + 0.25, y + 2.85, 2.8), P.iron, M.Metal)) end
	for k = 0, 6 do
		local bx = x - 3.05 + k * 6.1 / 6
		decor(c:box('BalconyBar', V(bx - 0.07, y, 2.55), V(bx + 0.07, y + 2.6, 2.7), P.iron, M.Metal))
	end
end
local function tanBuilding(ctx, w, o)
	local c, model = ctx:group(o.name or 'TanApartments')
	local roof = roofOf(o.floors)
	c:box('Wall', V(0, -1, -DEPTH), V(w, roof, 0), o.wall or P.tan, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 2, 0.35), P.tanDark, M.Concrete)
	if o.stone then
		-- A pale stone ground storey (the Apartments district): it reads cleaner and richer than the walk-ups.
		decor(c:box('GroundStone', V(0, 2, 0), V(w, 11.4, 0.15), C(214, 206, 192), M.Concrete))
		decor(c:box('GroundStoneCap', V(0, 11.4, 0), V(w, 12, 0.45), P.tanLight, M.SmoothPlastic))
	end
	for _, x in { 0, w - 1 } do decor(c:box('Pier', V(x, 2, 0), V(x + 1, roof, 0.3), P.tanLight, M.SmoothPlastic)) end
	for f = 2, o.floors do decor(c:box('FloorBand', V(1, storeyY(f) - 0.4, 0), V(w - 1, storeyY(f) + 0.2, 0.25), P.tanLight, M.SmoothPlastic)) end
	c:box('Cornice', V(0, roof - 1.2, 0), V(w, roof + 0.6, 0.9), P.tanLight, M.SmoothPlastic)
	c:box('RoofTop', V(0, roof, -DEPTH), V(w, roof + 0.6, 0), C(150, 146, 140), M.Concrete) -- a grey tar roof
	decor(c:box('RoofVent', V(w * 0.7 - 1.5, roof + 0.6, -12), V(w * 0.7 + 1.5, roof + 2.6, -8), P.slate, M.Metal))
	local list = bays(w, o.bays or 3)
	local mid = (#list + 1) // 2
	for f = 2, o.floors do
		for k, x in list do
			if k == mid and (o.balconies ~= false) then
				window(c, x, storeyY(f) + 0.4, { h = 7.2, frame = P.tanLight, sill = P.tanLight })
				balcony(c, x, storeyY(f) + 0.4)
			else
				window(c, x, storeyY(f) + 3, { frame = P.tanLight, sill = P.tanLight })
			end
		end
	end
	local doorX = list[mid]
	for _, x in list do if math.abs(x - doorX) > 3 then window(c, x, 3.6, { frame = P.tanLight, sill = P.tanLight }) end end
	door(c, doorX, P.doorDark, P.tanDark)
	if o.sideAt then sideWindows(c, o.sideAt, o.floors, P.tanLight) end
	model:SetAttribute('Floors', o.floors)
	return c, model
end

-- Barber: light brick, a slate shopfront, a charcoal framed sign, the red-cream-slate awning and the pole by the door.
local function barberShop(ctx, w)
	local c = brickBuilding(ctx, w, { name = 'Barber', floors = 2, wall = P.brickPink, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), P.barberBlue, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), P.barberBlue, M.SmoothPlastic)
	end })
	local barberRed = C(176, 76, 68)
	stripedAwning(c, 1.5, w - 1.5, 9.4, { barberRed, P.cream, barberRed, P.cream, P.barberBlue })
	Streets.shopSign(c, w / 2 - 7, w / 2 + 7, 'BARBER', P.ink, P.cream)
	-- The pole by the door, turning.
	local pole, poleModel = c:group('BarberPole')
	local p0 = V(w - 0.9, 2, 1.2)
	pole:post('PoleBody', 0.55, 5, p0, P.cream, M.SmoothPlastic)
	for k = 0, 4 do
		pole:part('PoleStripe', V(0.35, 1.15, 1.15), CFrame.new(p0 + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(22), 0, 0), k % 2 == 0 and barberRed or P.barberBlue, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, y in { -0.3, 5 } do pole:post('PoleCap', 0.7, 0.4, p0 + V(0, y, 0), P.metal, M.Metal) end
	pole:box('PoleBracket', p0 + V(-0.15, 2.4, -1.2), p0 + V(0.15, 2.7, -0.5), P.iron, M.Metal)
	poleModel:SetAttribute('Spin', 60)
	poleModel:AddTag('HoodMotion')
	poleModel.WorldPivot = c:world(CFrame.new(p0 + V(0, 2.5, 0)))
	return c
end

-- Grocery: a cream shop floor under a brick upper floor, a deep-green framed sign with the name in gold, a
-- green-cream awning, a produce stand (the fruit is the colour, kept small) and crates out front.
local function grocery(ctx, w)
	local c, model = ctx:group('Grocery')
	local roof = roofOf(2)
	local deep = P.groceryGreen:Lerp(P.black, 0.3)
	c:box('Wall', V(0, -1, -DEPTH), V(w, 12, 0), P.frame, M.SmoothPlastic)
	c:box('WallUpper', V(0, 12, -DEPTH), V(w, roof, 0), P.brickDark, M.Brick)
	decor(c:box('StringCourse', V(0, 11.3, 0), V(w, 12.1, 0.3), P.stone, M.Concrete))
	roofCap(c, w, roof, P.slate)
	for _, x in bays(w, 3) do window(c, x, storeyY(2) + 3, {}) end
	c:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
	for x = 2 + (w - 9) / 3, w - 7.5, (w - 9) / 3 do decor(c:box('ShopMullion', V(x - 0.2, 1, 0), V(x + 0.2, 7.4, 0.4), deep, M.SmoothPlastic)) end
	c:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), deep, M.SmoothPlastic)
	c:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
	c:box('ShopBase', V(1, 0, 0), V(w - 6.4, 1, 0.4), deep, M.SmoothPlastic)
	Streets.shopSign(c, 2, w - 2, 'GROCERY', P.groceryGreen, P.gold)
	stripedAwning(c, 0.5, w - 0.5, 9.4, { P.groceryGreen, P.cream }, 4)
	-- Produce stand and crates.
	c:box('StandTable', V(2.5, 2.4, 1), V(9.5, 2.8, 4), P.wood, M.WoodPlanks)
	for _, x in { 3, 9 } do c:box('StandLeg', V(x - 0.2, 0, 1.3), V(x + 0.2, 2.4, 3.7), P.woodDark, M.Wood) end
	-- The fruit keeps its colour (it's an item) but only as small mounds inside the crates.
	local fruit = { C(196, 82, 66), C(214, 140, 70), C(138, 168, 88), C(222, 194, 100) }
	for k = 0, 3 do
		local x = 3.2 + k * 1.6
		c:box('ProduceBox', V(x - 0.7, 2.8, 1.4), V(x + 0.7, 3.5, 3.6), P.crate, M.WoodPlanks)
		decor(c:box('Produce', V(x - 0.5, 3.35, 1.7), V(x + 0.5, 3.65, 3.3), fruit[k + 1], M.SmoothPlastic))
	end
	crate(c, CFrame.new(w - 9, 0, 2.4), 2.4)
	crate(c, CFrame.new(w - 9, 2.4, 2.4) * CFrame.Angles(0, 0.3, 0), 2)
	model:SetAttribute('Floors', 2)
	return c
end

-- Painted corner shop (slate blue, behind the grocery in the concept): cream door frame, a charcoal framed
-- sign, a slate awning.
local function blueShop(ctx, w, label)
	local c = brickBuilding(ctx, w, { name = 'BlueShop', floors = 2, wall = P.shopBlue, ground = function(c2)
		c2:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		c2:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
		c2:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), P.frame, M.SmoothPlastic)
	end })
	Streets.shopSign(c, 2, w - 2, label, P.ink, P.cream)
	decor(c:wedge('Awning', V(w - 4, 1.4, 3), CFrame.new(w / 2, 8.6, 1.5) * CFrame.Angles(0, math.pi, 0), P.shopBlue:Lerp(P.black, 0.3), M.Fabric))
	return c
end

-- Corrugated steel warehouse (slate blue-grey) with a roll-up door, a warm light bar and a side door.
local function warehouse(ctx, w, color)
	color = color or P.warehouse
	local c, model = ctx:group('Warehouse')
	local h = 22
	c:box('Wall', V(0, -1, -DEPTH), V(w, h, 0), color, M.SmoothPlastic)
	for x = 1.2, w - 1, 2.4 do decor(c:box('Ridge', V(x - 0.35, 0.5, 0), V(x + 0.35, h - 0.6, 0.25), color:Lerp(P.white, 0.14), M.SmoothPlastic)) end
	local roofBlue = color:Lerp(P.white, 0.25)
	c:box('Roof', V(-0.6, h, -DEPTH - 0.6), V(w + 0.6, h + 1, 1.2), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH / 4 + 0.15) * CFrame.Angles(0, math.pi, 0), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH * 3 / 4 - 0.15), roofBlue, M.SmoothPlastic)
	local dx = w * 0.42
	c:box('DoorFrame', V(dx - 8, 0, 0), V(dx + 8, 15.2, 0.4), P.warehouseDark, M.Metal)
	c:box('RollDoor', V(dx - 7, 0, 0), V(dx + 7, 14, 0.5), P.rollDoor, M.Metal)
	for y = 1, 13.5, 1.1 do decor(c:box('DoorSlat', V(dx - 7, y, 0.5), V(dx + 7, y + 0.14, 0.58), P.rollDoor:Lerp(P.black, 0.35), M.Metal)) end
	decor(c:box('LightBar', V(dx - 3, 16, 0), V(dx + 3, 16.6, 0.6), P.lampGlow, M.Neon))
	c:box('SideDoorFrame', V(w - 8.6, 0, 0), V(w - 3.4, 9, 0.35), P.warehouseDark, M.Metal)
	c:box('SideDoor', V(w - 8, 0, 0), V(w - 4, 8.2, 0.45), P.warehouseDark:Lerp(P.black, 0.2), M.Metal)
	local lampBox = c:box('WallLamp', V(w - 7, 10.6, 0), V(w - 5, 11.4, 1.2), P.iron, M.Metal)
	decor(c:box('WallLampGlow', V(w - 6.8, 10.4, 0.2), V(w - 5.2, 10.6, 1.1), P.lampGlow, M.Neon))
	light(lampBox, P.lampGlow, 1, 12)
	model:SetAttribute('Floors', 2)
	return c
end

-- The one sign recipe for the street: a board (charcoal with cream text, or cream with charcoal text; the
-- grocery's is its deep green with the name in gold) in a charcoal steel frame, fixed flat over the shopfront.
function Streets.shopSign(c, x0, x1, text, board, ink)
	decor(c:box('ShopSignFrame', V(x0 - 0.35, 9.85, 0), V(x1 + 0.35, 13.95, 0.65), P.metal, M.Metal))
	local sign = c:box('ShopSign', V(x0, 10.2, 0), V(x1, 13.6, 0.8), board, M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', text, ink, FONT.loud, 0.14, 0.72)
	return sign
end

-- Shop with a striped awning and a framed sign (the barber's look, reused down Shop Street). ONE accent per
-- shop: the awning stripes (accent and cream) and the painted shopfront (the accent, deepened).
-- o: sign, accent, board, text, wall, floors, extra ('crates')
local function shopBuilding(ctx, w, o)
	local trim = o.accent:Lerp(P.black, 0.25)
	local c = brickBuilding(ctx, w, { name = 'Shop_' .. o.sign:gsub('%W', ''), floors = o.floors or 2, wall = o.wall or P.brick, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), trim, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), trim, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), trim, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), trim, M.SmoothPlastic)
	end })
	stripedAwning(c, 1.5, w - 1.5, 9.4, { o.accent, P.cream })
	local sw = math.min(w / 2 - 1.5, 2.5 + #o.sign * 0.85)
	Streets.shopSign(c, w / 2 - sw, w / 2 + sw, o.sign, o.board, o.text)
	if o.extra == 'crates' then
		crate(c, CFrame.new(3.5, 0, 2.6), 2.4)
		crate(c, CFrame.new(3.5, 2.4, 2.6) * CFrame.Angles(0, 0.3, 0), 2)
	end
	return c
end

-- A lot of stacked shipping containers behind a low wall, crates out front (the yards' side "buildings").
local function containerLot(ctx, w, seed)
	local c = ctx:group('ContainerLot')
	c:box('LotFloor', V(0, -1, -DEPTH), V(w, 0.06, 0), C(178, 172, 162), M.Concrete)
	c:box('LotWall', V(0, -1, -DEPTH), V(w, 6, -DEPTH + 2), P.wall, M.Concrete)
	local colors = { P.containerBlue, P.containerRed, P.containerTeal, P.containerCream }
	local n = math.floor(w / 20)
	for k = 0, n - 1 do
		local x = (w - n * 20) / 2 + 10 + k * 20
		local h = (seed or 0) + k
		container(c, CFrame.new(x, 0.06, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[h % 4 + 1])
		if h % 2 == 0 then container(c, CFrame.new(x, 8.66, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 1) % 4 + 1]) end
		container(c, CFrame.new(x, 0.06, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 2) % 4 + 1])
		container(c, CFrame.new(x, 8.66, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 3) % 4 + 1])
	end
	for k, x in { 4, w * 0.45, w - 5 } do
		pallet(c, CFrame.new(x, 0.06, -3))
		crate(c, CFrame.new(x, 0.86, -3), 3)
		if k == 2 then crate(c, CFrame.new(x + 0.3, 3.86, -3.2) * CFrame.Angles(0, 0.25, 0), 2.6) end
	end
	-- Chain-link along the front with a gap, so it reads as a yard and not a wall.
	chainLink(c, V(0.3, 0.06, 0.3), V(w - 0.3, 0.06, 0.3), 8, { { w * 0.5 - 3, w * 0.5 + 3 } })
	return c
end
---------------------------------------------------------------------------------------------- lobby hall
-- World 1's spawn: the BLOCK RANGE hall, a calm, warm warehouse (BRIEF6 / lobby_art_direction.md). A warm concrete
-- floor with a smooth cross walkway and studded island panels behind charcoal kerbs, cream walls over a brick
-- wainscot, charcoal steel pillars, trusses and frames, warm fixtures. About 60% warm neutrals, 30% materials
-- (brick, wood, charcoal steel) and 10% accents: gold means money, +1 and upgrades; teal means open and go. The
-- colour lives on the guns, shoes, avatars, targets and two hero signs.
--   Centre: the round stone spawn dais at the crossing, facing the free lane and the exit (north-west).
--   North (-Z): the exit to Stage 1 (the hero: framed, warm-lit, one sign), the quiet locked WORLD 2 door west of
--     it, the FAST TRAVEL bus stop east of it, DOCK 1 and DOCK 2 in the corners.
--   West: the 8 shooting ranges on one stepped terrace (concrete risers, wood treads, charcoal rails, frosted glass).
--   East: the ARMORY (d3_armory) and the corner store. South: the SHOE BOX dais and the street-ball court.
--   The four panels between the walkway's arms are calm islands (planters, trees, benches on rugs, warm lamps);
--   the free daily rewards stand on the north-east one, the VIP safe on the south-east one.
-- Builders from other files (Stations, Armory) fill the slots; a missing or failing one leaves a labelled
-- placeholder box of the slot's size.
-- Map frame (studs): interior x -66..66, z 6..156 (north wall z 5..6, the Stage 1 gate at z = 0 stays outside),
-- floor top y = 0. North = -Z. Lobby.Slots: name -> CFrame in the map frame, filled by Lobby.build.
-- Neon only where a real light is: fixtures, bulbs, two hero signs and the interactable rings. Kid-friendly: every
-- target is a thing, never a person.
local Lobby = {}

Lobby.W = 66 -- interior half width (walls x ±66..±67)
Lobby.N, Lobby.S = 6, 156 -- interior north and south faces
Lobby.H = 40 -- ceiling height
Lobby.Deck = SPAWN.Y -- the floor (0)
Lobby.CrossZ = SPAWN.Z -- where the walkways cross (the spawn dais)
Lobby.Door, Lobby.DoorH = 12, 20 -- north door half width and height
Lobby.Bay = 15 -- pillar spacing along the side walls, from z = 6
Lobby.SpawnYaw = math.rad(25) -- the spawn faces north-north-west: the free lane (BAY 1) left, the exit right
Lobby.DaisTop = 1.1 -- the spawn dais's walking surface (its cream top)
Lobby.Slots = {}
-- The palette (BRIEF6): the only base colours in the hall. Floor and walls stay under 12% saturation, brick and
-- wood under 50%, accents under 75%. The big neutrals (floor, walkway, panels, walls, concrete, ceiling) carry the
-- palette's hues at about half its saturation: HoodCalm's warm sun, ambient and grade add the rest, so they still
-- read warm in game but measure neutral (rendered S about 0.12 instead of 0.18).
Lobby.Colors = {
	floor = C(189, 185, 179), walk = C(211, 207, 199), panel = C(169, 166, 160), wall = C(229, 224, 216),
	brick = C(154, 102, 85), metal = C(60, 63, 68), wood = C(165, 122, 88), gold = C(227, 169, 63), teal = C(63, 125, 110),
	bulb = C(255, 227, 179), goldNeon = C(255, 194, 77), glass = C(143, 167, 179), ink = C(43, 47, 54), leaf = C(94, 140, 74),
	edge = C(216, 180, 74), cream = C(237, 228, 207),
	-- the same hues in other values
	concrete = C(198, 194, 187), ceiling = C(172, 168, 161), metalLight = C(98, 101, 106), woodDark = C(132, 96, 68),
	brickDark = C(126, 82, 68), stone = C(169, 166, 160), leafDark = C(78, 118, 62), rugTerra = C(164, 104, 82),
	rugTeal = C(74, 118, 108), rugSand = C(196, 178, 148), oxblood = C(110, 43, 43),
}
-- Sign text: cream on ink boards (ink on cream boards), gold for the one key word, a dark stroke.
Lobby.T = { cream = C(242, 234, 216), ink = C(43, 47, 54), gold = C(236, 180, 72), teal = C(132, 196, 176), stroke = C(22, 24, 28) }
Lobby.F = { display = FONT.title, plain = FONT.body } -- the hall's two fonts
-- Tier plaques along the terrace: bronze, silver, gold, diamond (two lanes each).
Lobby.TierColors = { C(178, 122, 80), C(178, 122, 80), C(200, 204, 210), C(200, 204, 210), C(227, 169, 63), C(227, 169, 63), C(178, 218, 230), C(178, 218, 230) }
-- The ranges climb the west wall as one terrace: Starter (tier 1) by the exit, Gold (tier 8) at the back, 10.5
-- apart, each 1.2 higher than the last. A lane's front (shooter's box) faces the hall; its targets face the wall.
-- In front of the lanes runs one promenade with a straight front edge at TerraceX.
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.RangeZ0, Lobby.RangePitch, Lobby.RangeRise = 34, 10.5, 1.2
Lobby.RangeX = -53 -- lane centres; the shooter's end is at x -43, the backstops at x -63
Lobby.TerraceX = -37 -- the promenade's front edge
Lobby.SideStair = 4 -- the lane whose side stair comes down to the cross walkway
Lobby.LoadDoors = { -55, 55 } -- the north wall's two closed roll-up dock doors (centres; 14 wide, 12 tall)
-- The terrace's height at z (0 off its ends).
function Lobby.terraceHeight(z)
	local i = math.floor((z - (Lobby.RangeZ0 - Lobby.RangePitch / 2)) / Lobby.RangePitch) + 1
	return (i >= 1 and i <= #Lobby.Ranges) and i * Lobby.RangeRise or 0
end
-- The ARMORY on the east side: its front step's foot at x ArmoryX, centred on z ArmoryZ, facing the hall (-X).
-- It spans z ArmorySpan (Armory.HalfWidth 29.4 each way) and x ArmoryX..65.6 (Armory.Depth 31.2).
Lobby.ArmoryX, Lobby.ArmoryZ = 34.4, 106.2
Lobby.ArmorySpan = { 76.8, 135.6 }
-- The floor's island panels (x0, x1, z0, z1) between the arms of the cross walkway (16-wide arms).
Lobby.Panels = { { -30, -8, 16, 58 }, { 8, 30, 16, 58 }, { -30, -8, 74, 121 }, { 8, 30, 74, 121 } }


---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top (floor panels and small props only).
function Lobby.slab(c, name, a, b, color)
	return studs(c:box(name, a, b, color, M.Plastic))
end
-- A ParticleEmitter with a built-in texture (the renderer reads PreviewTexture for the intended look).
function Lobby.fx(part, name, tex, props)
	local builtin = { dust = 'rbxasset://textures/particles/sparkles_main.dds', smoke = 'rbxasset://textures/particles/smoke_main.dds',
		mist = 'rbxasset://textures/particles/smoke_main.dds', glitter = 'rbxasset://textures/particles/sparkles_main.dds',
		sparkle = 'rbxasset://textures/particles/sparkles_main.dds', ray = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png',
		swirl = 'rbxasset://textures/particles/explosion01_shockwave_main.dds' }
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Texture = builtin[tex] or builtin.softglow
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do (e :: any)[k] = v end
	e:SetAttribute('PreviewTexture', tex)
	e.Parent = part
	return e
end
function Lobby.seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
-- Invisible box particles spawn in.
function Lobby.emitBox(c, name, a, b)
	local p = ghost(c:box(name, a, b, P.white))
	p.CastShadow = false
	return p
end
-- Spinning / bobbing decor for WorldMotion.client (tag HoodMotion): spins round pivot's Y axis.
function Lobby.motion(model, pivot, spin, bob, period)
	model.WorldPivot = V2.Origin * pivot
	if spin then model:SetAttribute('Spin', spin) end
	if bob then model:SetAttribute('Bob', bob) end
	if period then model:SetAttribute('BobPeriod', period) end
	model:AddTag('HoodMotion')
	return model
end
-- A flat board whose front faces cf's LookVector, with text lines { name, text, color, font, y, h, stroke }.
function Lobby.board(c, name, cf, w, h, color, rows, ppS, mat)
	local b = c:part(name, V(w, h, 0.3), cf, color, mat or M.SmoothPlastic)
	local g = surface(b, Enum.NormalId.Front, ppS or 16)
	for _, r in rows or {} do line(g, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] or 3) end
	return b, g
end
-- Shaded stripes painted on one face of a part (corrugated ribs, roll-up door slats, awning stripes): every
-- `pitch` studs a stripe `width` wide, vertical or horizontal, in color at transparency alpha. len and ht are the
-- face's width and height in studs. Returns the SurfaceGui (text can go on it too).
function Lobby.stripes(part, face, len, ht, pitch, width, vertical, alpha, color)
	local g = surface(part, face, 8)
	g.Name = 'Stripes'
	local span = vertical and len or ht
	for k = 0, math.floor(span / pitch) - 1 do
		local f = Instance.new('Frame')
		f.Name = 'Stripe'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color or P.black
		f.BackgroundTransparency = alpha or 0.8
		local a, w = (k * pitch + (pitch - width) / 2) / span, width / span
		if vertical then f.Position, f.Size = UDim2.fromScale(a, 0), UDim2.fromScale(w, 1)
		else f.Position, f.Size = UDim2.fromScale(0, a), UDim2.fromScale(1, w) end
		f.Parent = g
	end
	return g
end
-- CFrame on a wall face: the wall's interior face plane, pos on it, facing into the room along `normal`.
function Lobby.onWall(pos, normal)
	return CFrame.lookAt(pos, pos + normal)
end
-- A part placed by a world CFrame (for pieces built round another builder's model).
function Lobby.worldPart(parent, name, size, cf, color, material)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- An upright disc (cylinder) of diameter d and height h standing on pos.
function Lobby.disc(c, name, d, h, pos, color, mat)
	return c:part(name, V(h, d, d), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, mat or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- A flat ring of outer diameter d and width w at height y (a disc in `color` with a disc of `fill` inside, the
-- fill a hair higher): inlays and interactable rings. Returns the ring part.
function Lobby.ring(c, name, d, w, pos, h, color, mat, fill, fillMat)
	local r = decor(Lobby.disc(c, name, d, h, pos, color, mat))
	r.CastShadow = false
	if fill then decor(Lobby.disc(c, name .. 'Fill', d - 2 * w, h + 0.01, pos, fill, fillMat)).CastShadow = false end
	return r
end
-- A warm SpotLight on a part, pointing out of `face` (hero lights: spawn, exit; accent spots: lowrider, shoe dais).
function Lobby.spot(part, face, angle, range, brightness)
	local s = Instance.new('SpotLight')
	s.Face, s.Angle, s.Range, s.Brightness = face or Enum.NormalId.Bottom, angle or 50, range or 30, brightness or 2
	s.Color, s.Shadows = C(255, 224, 180), true
	s.Parent = part
	return s
end

---------------------------------------------------------------------------------------------- sign system
-- One sign system (lobby_art_direction §3d): a board in one of two colourways (ink with cream text, or cream with
-- ink text; gold for the one key word), in a 0.4 frame of wood or charcoal steel set 0.2 behind it, on a real mount.
-- cf: the board's centre, its front (-Z) toward the reader. rows: { name, text, color, font, y, h [, x, w] } in
-- the board's 0-1 space (x, w: a cell of the width, for a key word beside the rest). o.style 'ink' | 'cream';
-- o.frame 'wood' | 'steel' | a Color3; o.mount 'brackets' (two steel arms back to a wall `o.depth` behind),
-- 'chains' (two chains up to height o.top, in the context's frame), or nil (flat on its backing); o.rim: the
-- frame's border (0.4); o.tube: a thin neon tube round the frame (the hero signs only).
function Lobby.sign(c, name, cf, w, h, rows, o)
	o = o or {}
	local K, T = Lobby.Colors, Lobby.T
	local frameColor = typeof(o.frame) == 'Color3' and o.frame or (o.frame == 'steel' and K.metal or K.woodDark)
	local frameMat = (o.frame == nil or o.frame == 'wood') and M.Wood or M.SmoothPlastic
	local rim = o.rim or 0.4
	local f = c:part(name .. 'Frame', V(w + 2 * rim, h + 2 * rim, 0.4), cf * CFrame.new(0, 0, 0.32), frameColor, frameMat)
	local b = c:part(name, V(w, h, 0.3), cf, o.style == 'cream' and K.wall or K.ink, M.SmoothPlastic)
	local g = surface(b, Enum.NormalId.Front, o.ppS or 20)
	for _, r in rows do
		local t = line(g, r[1], r[2], r[3], r[4], r[5], r[6], o.style == 'cream' and nil or T.stroke, 2)
		if r[7] then t.Position, t.Size = UDim2.fromScale(r[7], r[5]), UDim2.fromScale(r[8], r[6]) end
	end
	if o.mount == 'brackets' then
		local d = o.depth or 1
		for _, sx in { -1, 1 } do
			c:part(name .. 'Bracket', V(0.25, 0.25, d), cf * CFrame.new(sx * (w / 2 - 0.6), h / 2 - 0.4, 0.5 + d / 2), K.metal, M.SmoothPlastic)
		end
	elseif o.mount == 'chains' then
		for _, sx in { -1, 1 } do
			local a = (cf * CFrame.new(sx * (w / 2 - 0.5), h / 2 + 0.4, 0.3)).Position
			decor(c:bar(name .. 'Chain', a, V(a.X, o.top, a.Z), 0.12, K.metal, M.SmoothPlastic)).CastShadow = false
		end
	end
	if o.tube then
		local t, z = 0.22, -0.05
		local W2, H2 = w / 2 + 0.25, h / 2 + 0.25
		for _, e in { { 0, H2, 2 * W2 + t, t }, { 0, -H2, 2 * W2 + t, t }, { -W2, 0, t, 2 * H2 }, { W2, 0, t, 2 * H2 } } do
			decor(c:part(name .. 'Tube', V(e[3], e[4], t), cf * CFrame.new(e[1], e[2], z), o.tube, M.Neon)).CastShadow = false
		end
	end
	return b, g, f
end
-- The one SOON tag: a small ink plate with cream SOON in a thin gold frame (World 2, the shoe boxes).
function Lobby.soon(c, name, cf, w)
	w = w or 3.2
	return Lobby.sign(c, name, cf, w, w * 0.36, { { 'Soon', 'SOON', Lobby.T.cream, Lobby.F.display, 0.1, 0.8 } }, { frame = Lobby.Colors.gold, ppS = 40 })
end
-- A painted floor arrow (flush cream paint, about 3.5 long) at pos pointing along dir (a unit vector on the floor).
function Lobby.arrow(c, pos, dir)
	local K = Lobby.Colors
	local cf = CFrame.lookAt(pos, pos + dir)
	decor(c:part('FloorArrow', V(0.55, 0.02, 3.0), cf * CFrame.new(0, 0, 0.1), K.cream, M.SmoothPlastic)).CastShadow = false
	for _, sx in { -1, 1 } do -- the head: two strokes back from the tip (z -1.75), 35 degrees off the shaft
		decor(c:part('FloorArrow', V(0.55, 0.02, 1.7), cf * CFrame.new(sx * 0.46, 0, -1.05) * CFrame.Angles(0, sx * math.rad(35), 0), K.cream, M.SmoothPlastic)).CastShadow = false
	end
end

---------------------------------------------------------------------------------------------- hall
-- A TrussPart lattice beam from a to b (Roblox and the previewer both take its long axis on Y).
function Lobby.truss(c, name, a, b, color)
	local t = Instance.new('TrussPart')
	t.Name = name
	t.Anchored = true
	t.Size = V(2, (b - a).Magnitude, 2)
	local mid = (a + b) / 2
	t.CFrame = V2.Origin * c.cf * CFrame.lookAt(mid, b) * CFrame.Angles(-math.pi / 2, 0, 0)
	t.Color = color
	t.Material = M.SmoothPlastic
	t.CastShadow = false
	t.Parent = c.parent
	return t
end
-- A charcoal steel wall pillar standing on the floor at pos (on the wall's inner face), its front along normal:
-- a concrete plinth with a cap, a deep lower part, a slanted step (a wedge) and a slimmer upper part. kind 'range'
-- is shallower (the lanes' backstops are 3 studs off the wall) and stands on the terrace at height y; kind 'above'
-- is only the upper part, from y 20.6 (over the armory's back).
Lobby.PillarKink = { 11, 14.5 } -- the slant runs from y 11 to y 14.5
Lobby.PillarDepth = { full = { 3.0, 1.8, 3.4 }, range = { 2.6, 1.8, 2.8 }, above = { 1.8, 1.8, 0 } }
function Lobby.wallPillar(c, pos, normal, kind, y)
	local K, H = Lobby.Colors, Lobby.H
	local y0, y1 = table.unpack(Lobby.PillarKink)
	local d0, d1, db = table.unpack(Lobby.PillarDepth[kind or 'full'])
	local f = CFrame.lookAt(pos, pos + normal) -- -Z = into the hall
	local w = 3.6
	local function B(name, x0, ya, z0, x1, yb, z1, color, mat)
		return c:part(name, V(x1 - x0, yb - ya, z1 - z0), f * CFrame.new((x0 + x1) / 2, (ya + yb) / 2, (z0 + z1) / 2), color, mat or M.SmoothPlastic)
	end
	if kind == 'above' then
		B('Pillar', -w / 2, 20.6, -d1, w / 2, H - 1.4, 0, K.metal)
		return
	end
	local yb = y or 0
	local bt = math.min(yb + 1.6, y0 - 0.3)
	B('PillarBase', -w / 2 - 0.3, yb, -db, w / 2 + 0.3, bt, 0, K.stone)
	B('PillarBaseCap', -w / 2 - 0.4, bt, -db - 0.1, w / 2 + 0.4, bt + 0.25, 0, K.concrete)
	B('Pillar', -w / 2, bt + 0.25, -d0, w / 2, y0, 0, K.metal)
	B('Pillar', -w / 2, y0, -d1, w / 2, H - 1.4, 0, K.metal)
	-- The slant: a wedge whose slope runs from the lower part's front top edge up to the upper part's face.
	c:wedge('PillarKink', V(w, y1 - y0, d0 - d1), f * CFrame.new(0, (y0 + y1) / 2, -(d0 + d1) / 2), K.metal, M.SmoothPlastic)
end
-- A big window on a wall: a concrete sill, a charcoal steel frame with a mullion and a transom, soft blue-grey
-- glass with a lighter streak. f(u, y, w) maps (along the wall, height, out from the wall) to the map. noSill:
-- no sill (behind the armory's back wall).
function Lobby.window(c, f, u, y0, y1, noSill)
	local K = Lobby.Colors
	if not noSill then c:box('WindowSill', f(u - 5.7, y0 - 1.1, 0), f(u + 5.7, y0 - 0.5, 0.75), K.concrete, M.SmoothPlastic) end
	c:box('WindowFrame', f(u - 5.2, y0 - 0.5, 0), f(u + 5.2, y1 + 0.5, 0.3), K.metal, M.SmoothPlastic)
	c:box('WindowGlass', f(u - 4.7, y0, 0.25), f(u + 4.7, y1, 0.35), K.glass, M.SmoothPlastic)
	local ym = y1 - (y1 - y0) * 0.36
	c:box('WindowMullion', f(u - 0.18, y0, 0.25), f(u + 0.18, y1, 0.5), K.metal, M.SmoothPlastic)
	c:box('WindowMullion', f(u - 4.7, ym - 0.18, 0.25), f(u + 4.7, ym + 0.18, 0.5), K.metal, M.SmoothPlastic)
	decor(c:box('WindowGlint', f(u - 3.9, y0 + 0.6, 0.35), f(u - 2.9, ym - 0.4, 0.4), K.glass:Lerp(P.white, 0.45), M.SmoothPlastic)).CastShadow = false
end
-- A closed roll-up dock door in the north wall at x: charcoal jambs and drum housing, warm grey slats (painted
-- stripes) with a stencilled number, a charcoal bottom rail and a concrete apron. ("BAY" is only for the lanes.)
function Lobby.dockDoor(c, x, label)
	local K, N = Lobby.Colors, Lobby.N
	local d = c:group('DockDoor')
	local w, ht = 7, 12
	for _, sx in { -1, 1 } do
		local a, b = x + sx * w, x + sx * (w + 1)
		d:box('DockDoorPost', V(math.min(a, b), 0, N), V(math.max(a, b), ht + 1.4, N + 0.9), K.metal, M.SmoothPlastic)
	end
	d:box('DockDoorDrum', V(x - w - 1, ht, N), V(x + w + 1, ht + 2, N + 1.4), K.metal, M.SmoothPlastic)
	local panel = d:box('DockDoorPanel', V(x - w, 0.5, N), V(x + w, ht, N + 0.45), C(178, 172, 162), M.SmoothPlastic)
	local g = Lobby.stripes(panel, Enum.NormalId.Back, 2 * w, ht - 0.5, 0.76, 0.16, false, 0.7, K.ink)
	line(g, 'Stencil', label, Lobby.T.ink, Lobby.F.plain, 0.36, 0.16, nil)
	d:box('DockDoorRail', V(x - w, 0, N), V(x + w, 0.5, N + 0.55), K.metal, M.SmoothPlastic)
	d:box('DockApron', V(x - w - 1, 0, N), V(x + w + 1, 0.08, N + 3.5), K.stone, M.SmoothPlastic).CastShadow = false
	return d
end
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	-- The floor: warm concrete. The walkway, panels and kerbs go on top of it (Lobby.floorPlan).
	h:box('Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.floor, M.SmoothPlastic)
	local function wall(a, b) return h:box('Wall', a, b, K.wall, M.SmoothPlastic) end
	wall(V(-W - 1, 0, N - 1), V(-W, H, S + 1))
	wall(V(W, 0, N - 1), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, S), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, N - 1), V(-Dw, H, N))
	wall(V(Dw, 0, N - 1), V(W + 1, H, N))
	wall(V(-Dw, DH, N - 1), V(Dw, H, N))
	-- Inner faces: a charcoal skirting, exposed brick to y 11 under a concrete cap, cream painted wall above, a
	-- warm grey corrugated clerestory band on a concrete ledge, a charcoal cornice. f(u, y, w): u along the wall,
	-- w out from it into the hall.
	local west = function(u, y, w) return V(-W + w, y, u) end
	local east = function(u, y, w) return V(W - w, y, u) end
	local south = function(u, y, w) return V(u, y, S - w) end
	local north = function(u, y, w) return V(u, y, N + w) end
	-- (on the north wall the runs stop at the exit's pilasters, the dock doors and the WORLD 2 door)
	local runs = { { west, N, S }, { east, N, S }, { south, -W, W } }
	for _, seg in { { -W, -63 }, { -47, -37.7 }, { -22.3, -Dw - 5.2 }, { Dw + 5.2, 47 }, { 63, W } } do table.insert(runs, { north, seg[1], seg[2] }) end
	for _, r in runs do
		local f, u0, u1 = r[1], r[2], r[3]
		h:box('WallBase', f(u0, 0, 0), f(u1, 0.8, 0.3), K.metal, M.SmoothPlastic)
		h:box('WallBrick', f(u0, 0.8, 0), f(u1, 11, 0.25), K.brick, M.Brick)
		h:box('WallBrickCap', f(u0, 11, 0), f(u1, 11.6, 0.55), K.concrete, M.SmoothPlastic)
		h:box('WallCornice', f(u0, H - 1.4, 0), f(u1, H, 0.8), K.metal, M.SmoothPlastic)
	end
	for _, r in { { west, N, S, Enum.NormalId.Right }, { east, N, S, Enum.NormalId.Left }, { south, -W, W, Enum.NormalId.Front }, { north, -W, W, Enum.NormalId.Back } } do
		local f, u0, u1 = r[1], r[2], r[3]
		local band = h:box('WallSteel', f(u0, 28, 0), f(u1, H - 1.4, 0.2), C(206, 202, 195), M.SmoothPlastic)
		Lobby.stripes(band, r[4], u1 - u0, H - 29.4, 1.5, 0.5, true, 0.82, K.ink)
		h:box('WallSteelLedge', f(u0, 27.6, 0), f(u1, 28, 0.6), K.concrete, M.SmoothPlastic)
	end
	for z = N + Lobby.Bay / 2, S - 1, Lobby.Bay do
		Lobby.window(h, west, z, 14, 26)
		Lobby.window(h, east, z, 14, 26, z + 5.7 > Lobby.ArmorySpan[1] and z - 5.7 < Lobby.ArmorySpan[2]) -- (no sill behind the armory's back wall)
	end
	for _, x in { -55.5, -40.5, 40.5, 55.5 } do Lobby.window(h, south, x, 14, 26) end
	-- Pillars: every bay on the side walls, flanking the windows on the south wall. Behind the ranges the pillars are
	-- shallower; behind the ARMORY only their tops show.
	local r0 = Lobby.RangeZ0 - Lobby.RangePitch / 2
	local r1 = Lobby.RangeZ0 + (#Lobby.Ranges - 0.5) * Lobby.RangePitch
	for k = 0, 10 do
		local z = math.clamp(N + k * Lobby.Bay, N + 2.1, S - 2.1)
		local onTerrace = z > r0 - 2 and z < r1 + 2
		Lobby.wallPillar(h, V(-W, 0, z), V(1, 0, 0), onTerrace and 'range' or 'full', onTerrace and Lobby.terraceHeight(z - 1.8) or nil)
		Lobby.wallPillar(h, V(W, 0, z), V(-1, 0, 0), (z > Lobby.ArmorySpan[1] - 2 and z < Lobby.ArmorySpan[2] + 2) and 'above' or 'full')
	end
	for _, x in { -63.9, -48, -33, 33, 48, 63.9 } do Lobby.wallPillar(h, V(x, 0, S), V(0, 0, -1)) end
	for k, x in Lobby.LoadDoors do Lobby.dockDoor(h, x, 'DOCK ' .. k) end
	Lobby.exitDoor(h)
	-- The hall's three zone signs (one system: ink boards, cream words, the key line in gold, wood frames on
	-- brackets on the clerestory band).
	local signs = h:group('WallSigns')
	local T, F = Lobby.T, Lobby.F
	Lobby.sign(signs, 'RangeSign', CFrame.lookAt(V(-W + 2.6, 32.6, 73.5), V(0, 32.6, 73.5)), 26, 5.4, {
		{ 'Title', 'SHOOTING RANGE', T.cream, F.display, 0.08, 0.56 },
		{ 'Sub', 'SHOOT TO GAIN 💪 POWER', T.gold, F.plain, 0.68, 0.22 },
	}, { mount = 'brackets', depth = 1.9 }) -- (in front of the pillars; the brackets clear them)
	Lobby.sign(signs, 'ArmorySign', CFrame.lookAt(V(W - 2.6, 32.6, Lobby.ArmoryZ), V(0, 32.6, Lobby.ArmoryZ)), 26, 5.4, {
		{ 'Title', 'ARMORY', T.cream, F.display, 0.08, 0.56 },
		{ 'Sub', 'BETTER GUN = MORE 💪 PER SHOT', T.gold, F.plain, 0.68, 0.22 },
	}, { mount = 'brackets', depth = 1.9 })
	Lobby.sign(signs, 'ShoeBoxSign', CFrame.lookAt(V(0, 19.6, S - 1.3), V(0, 19.6, 0)), 20, 4.6, {
		{ 'Title', 'SHOE BOXES', T.cream, F.display, 0.08, 0.58 },
		{ 'Sub', 'UNBOX FRESH KICKS', T.gold, F.plain, 0.7, 0.2 },
	}, { mount = 'brackets', depth = 0.8 })
	Lobby.soon(signs, 'ShoeBoxSoon', CFrame.lookAt(V(8.2, 16.1, S - 0.55), V(8.2, 16.1, 0)) * CFrame.Angles(0, 0, math.rad(-4)), 3.4)

	-- Roof: a warm grey ceiling (darker than the walls), charcoal trusses (two along the hall, one across every
	-- bay), two frosted skylight strips, rows of warm strip lights on wires with warm SurfaceLights. Everything up
	-- here is named Roof* (the plan view hides it).
	local r = L:group('Roof')
	local cx = { -W - 1, -16.5, -10.5, 10.5, 16.5, W + 1 }
	for k = 1, 5, 2 do
		local ceil = r:box('RoofCeiling', V(cx[k], H, N - 1), V(cx[k + 1], H + 0.4, S + 1), K.ceiling, M.SmoothPlastic)
		ceil.CastShadow = false
		Lobby.stripes(ceil, Enum.NormalId.Bottom, cx[k + 1] - cx[k], S - N + 2, 1.5, 0.5, true, 0.8, K.ink)
	end
	for k = 2, 4, 2 do
		local x0, x1 = cx[k], cx[k + 1]
		local glass = r:box('RoofSkylight', V(x0, H + 0.05, N - 1), V(x1, H + 0.35, S + 1), C(240, 236, 228), M.SmoothPlastic)
		glass.Transparency, glass.CastShadow = 0.12, false -- (frosted: daylight, not sky)
		for _, x in { x0, x1 - 0.3 } do r:box('RoofSkylightFrame', V(x, H - 0.3, N - 1), V(x + 0.3, H + 0.05, S + 1), K.metal, M.SmoothPlastic).CastShadow = false end
		for z = N + Lobby.Bay, S - 1, Lobby.Bay do r:box('RoofSkylightFrame', V(x0, H - 0.3, z - 0.15), V(x1, H + 0.05, z + 0.15), K.metal, M.SmoothPlastic).CastShadow = false end
	end
	for _, x in { -40, 40 } do Lobby.truss(r, 'RoofTruss', V(x, H - 1.2, N), V(x, H - 1.2, S), K.metal) end
	for z = N + Lobby.Bay, S - 1, Lobby.Bay do Lobby.truss(r, 'RoofTruss', V(-W, H - 3.2, z), V(W, H - 3.2, z), K.metal) end
	-- the fixtures: three rows of long warm strip lights running down the hall, in two-bay runs between the cross
	-- trusses' drops, each on two wires, with a warm SurfaceLight
	for _, x in { -27, 0, 27 } do
		for zc = N + Lobby.Bay, S - 1, 2 * Lobby.Bay do
			local y, z0, z1 = H - 8, zc - 13, zc + 13
			r:box('RoofLampBar', V(x - 0.7, y, z0), V(x + 0.7, y + 0.5, z1), K.metal, M.SmoothPlastic).CastShadow = false
			local tube = decor(r:box('RoofLampTube', V(x - 0.5, y - 0.2, z0 + 0.2), V(x + 0.5, y, z1 - 0.2), K.bulb, M.Neon))
			tube.CastShadow = false
			for _, dz in { -9, 9 } do r:box('RoofLampWire', V(x - 0.06, y + 0.5, zc + dz - 0.06), V(x + 0.06, H - 0.1, zc + dz + 0.06), K.metal, M.SmoothPlastic).CastShadow = false end
			local sl = Instance.new('SurfaceLight')
			sl.Face, sl.Color, sl.Angle, sl.Range, sl.Brightness, sl.Shadows = Enum.NormalId.Bottom, C(255, 232, 200), 100, 20, 1.2, false
			sl.Parent = tube
		end
	end
	return h
end
-- The exit to Stage 1, the hall's hero: a charcoal steel portal round the door on brick pilasters with concrete
-- caps and two warm lanterns, the rolled-up door's drum under a steel lintel, ONE sign over it ("STAGE 1 • 💪 10",
-- the only place the hall says it) with a thin gold neon tube, and a warm spotlight on the threshold.
function Lobby.exitDoor(h)
	local K, T, F, N = Lobby.Colors, Lobby.T, Lobby.F, Lobby.N
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local d = h:group('ExitDoor')
	local Fw = Dw + 2.4
	for _, sx in { -1, 1 } do
		local function X(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		local a, b = X(Dw, Fw)
		d:box('DoorFrame', V(a, 0, N), V(b, DH + 1.6, N + 1.2), K.metal, M.SmoothPlastic)
		local pa, pb = X(Fw, Fw + 2.8)
		d:box('DoorPilaster', V(pa, 0.8, N), V(pb, DH + 1.6, N + 0.7), K.brick, M.Brick)
		d:box('DoorPilasterBase', V(pa, 0, N), V(pb, 0.8, N + 0.9), K.metal, M.SmoothPlastic)
		local ca, cb = X(Fw - 0.1, Fw + 3)
		d:box('DoorPilasterCap', V(ca, DH + 1.6, N), V(cb, DH + 2.2, N + 1.0), K.concrete, M.SmoothPlastic)
		-- a warm lantern on each pilaster
		local lx = sx * (Fw + 1.4)
		d:box('DoorLanternBack', V(lx - 0.6, 12.2, N + 0.7), V(lx + 0.6, 14.6, N + 0.9), K.metal, M.SmoothPlastic)
		local lamp = decor(d:box('DoorLantern', V(lx - 0.4, 12.5, N + 0.9), V(lx + 0.4, 14.3, N + 1.5), K.bulb, M.Neon))
		lamp.CastShadow = false
		d:box('DoorLanternCap', V(lx - 0.6, 14.3, N + 0.7), V(lx + 0.6, 14.6, N + 1.7), K.metal, M.SmoothPlastic)
		light(lamp, C(255, 214, 150), 0.6, 12)
	end
	d:box('DoorHeader', V(-Fw, DH, N), V(Fw, DH + 1.6, N + 1.2), K.metal, M.SmoothPlastic)
	d:box('DoorDrum', V(-Dw, DH - 1.4, N - 0.6), V(Dw, DH, N + 0.6), K.metalLight, M.SmoothPlastic)
	d:box('DoorSill', V(-Dw, 0, N - 1), V(Dw, 0.1, N + 1.6), K.stone, M.SmoothPlastic).CastShadow = false
	local sy = DH + 4.6
	Lobby.sign(d, 'ExitSign', CFrame.lookAt(V(0, sy, N + 0.9), V(0, sy, 100)), 19, 3.8, {
		{ 'Stage', 'STAGE 1  •', T.cream, F.display, 0.12, 0.76, 0.04, 0.6 },
		{ 'Power', '💪 10', T.gold, F.display, 0.12, 0.76, 0.62, 0.34 },
	}, { frame = 'steel', tube = K.goldNeon })
	-- the hero light: a lamp on a bracket over the sign, aimed at the threshold
	local lampAt = V(0, sy + 3.6, N + 2.4)
	d:bar('ExitLampArm', V(0, sy + 3.6, N + 0.25), lampAt, 0.3, K.metal, M.SmoothPlastic)
	local housing = d:part('ExitLamp', V(2.6, 1.0, 1.4), CFrame.lookAt(lampAt, V(0, 0, N + 14)), K.metal, M.SmoothPlastic)
	Lobby.spot(housing, Enum.NormalId.Front, 50, 30, 2.2)
	return d
end

---------------------------------------------------------------------------------------------- floor
-- The cross walkway by material and value: smooth light concrete arms 16 wide (0.1 proud of the floor) from the
-- exit to the shoe dais and from the terrace's side stair to the corner store; the four panels between the arms
-- are studded mid concrete behind a 1-stud charcoal kerb. No floor neon, no repeating chevrons: one cream arrow
-- per destination at the junction (Lobby.spawnDais).
function Lobby.floorPlan(L)
	local K, W, N = Lobby.Colors, Lobby.W, Lobby.N
	local f = L:group('FloorPlan')
	local z0 = Lobby.ShoeDais.Z0 - 1.2
	local function walk(a, b) f:box('Walkway', a, b, K.walk, M.SmoothPlastic).CastShadow = false end
	walk(V(-8, 0, N + 1.6), V(8, 0.1, 58)) -- north arm (from the door sill)
	walk(V(-8, 0, 58), V(8, 0.1, 74)) -- the crossing (under the spawn dais)
	walk(V(-8, 0, 74), V(8, 0.1, z0)) -- south arm, to the shoe dais
	walk(V(8, 0, 58), V(W - 1.6, 0.1, 74)) -- east arm, to the corner store
	local sz = Lobby.RangeZ0 + (Lobby.SideStair - 1) * Lobby.RangePitch
	walk(V(-32, 0, 58), V(-8, 0.1, 74)) -- west arm, from the terrace's side stair (its cheeks reach x -32)
	walk(V(-37, 0, 58), V(-32, 0.1, sz - 3.4))
	walk(V(-37, 0, sz + 3.4), V(-32, 0.1, 74))
	walk(V(-33, 0, sz - 3), V(-32, 0.1, sz + 3))
	for _, p in Lobby.Panels do
		local x0, x1, pz0, pz1 = p[1], p[2], p[3], p[4]
		Lobby.slab(f, 'Panel', V(x0 + 1, 0, pz0 + 1), V(x1 - 1, 0.06, pz1 - 1), K.panel).CastShadow = false
		for _, e in { { V(x0, 0, pz0), V(x1, 0.18, pz0 + 1) }, { V(x0, 0, pz1 - 1), V(x1, 0.18, pz1) },
			{ V(x0, 0, pz0 + 1), V(x0 + 1, 0.18, pz1 - 1) }, { V(x1 - 1, 0, pz0 + 1), V(x1, 0.18, pz1 - 1) } } do
			f:box('Kerb', e[1], e[2], K.metal, M.SmoothPlastic).CastShadow = false
		end
	end
	return f
end

---------------------------------------------------------------------------------------------- spawn dais
-- The spawn at the crossing: a round layered stone dais 16 across (a concrete base with a chamfer step, a cream
-- top, a gold inlay ring in plastic, a charcoal medallion with a raised gold "+1" built from parts), four warm
-- bollard lamps on its diagonals, one warm pendant spotlight over it, and one cream arrow on the walkway toward
-- each destination. The SpawnLocation is invisible, has no decal and no force field, and faces the free lane and
-- the exit (Lobby.SpawnYaw).
function Lobby.spawnDais(L)
	local K, D, cz = Lobby.Colors, Lobby.Deck, Lobby.CrossZ
	local yaw = Lobby.SpawnYaw
	local s = L:at(CFrame.new(0, D + 0.1, cz)):group('SpawnDais')
	Lobby.disc(s, 'DaisBase', 16, 0.4, V(0, 0, 0), K.stone)
	Lobby.disc(s, 'DaisChamfer', 15.2, 0.2, V(0, 0.4, 0), K.concrete)
	Lobby.disc(s, 'DaisTop', 14, 0.4, V(0, 0.6, 0), K.wall)
	Lobby.ring(s, 'DaisInlay', 12, 0.4, V(0, 1.0, 0), 0.02, K.gold, M.SmoothPlastic, K.wall)
	decor(Lobby.disc(s, 'MedallionRim', 6.4, 0.05, V(0, 1.0, 0), K.gold)).CastShadow = false
	decor(Lobby.disc(s, 'Medallion', 6, 0.07, V(0, 1.0, 0), K.ink)).CastShadow = false
	-- "+1", raised 0.12, reading upright from the arrival camera (its top toward the spawn's facing)
	local g = s:at(CFrame.new(0, 1.07, 0) * CFrame.Angles(0, yaw, 0))
	local function bar(x, z, w, l, a)
		decor(g:part('PlusOne', V(w, 0.12, l), CFrame.new(x, 0.06, z) * CFrame.Angles(0, a or 0, 0), K.gold, M.SmoothPlastic)).CastShadow = false
	end
	bar(-1.05, 0, 1.9, 0.55) -- the plus
	bar(-1.05, 0, 0.55, 1.9)
	bar(1.15, 0.05, 0.6, 2.9) -- the one: its stem, its flag at the top (-Z), its foot
	bar(0.72, -1.05, 0.5, 1.05, math.rad(-50))
	bar(1.15, 1.45, 1.6, 0.45)
	-- bollard lamps on the diagonals (just inside the crossing's corners)
	for _, e in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local p = V(e[1] * 7.3, 0, e[2] * 7.3)
		s:box('BollardFoot', p + V(-0.55, 0, -0.55), p + V(0.55, 0.3, 0.55), K.stone, M.SmoothPlastic)
		s:box('Bollard', p + V(-0.35, 0.3, -0.35), p + V(0.35, 2.2, 0.35), K.metal, M.SmoothPlastic)
		local lens = decor(s:box('BollardLamp', p + V(-0.3, 2.2, -0.3), p + V(0.3, 2.7, 0.3), K.bulb, M.Neon))
		lens.CastShadow = false
		s:box('BollardCap', p + V(-0.45, 2.7, -0.45), p + V(0.45, 2.95, 0.45), K.metal, M.SmoothPlastic)
		light(lens, C(255, 214, 150), 0.5, 10)
	end
	-- the pendant spotlight, hung from the cross truss over the crossing
	local H = Lobby.H
	local py = 25
	s:bar('SpawnPendantRod', V(0, H - 3.3 - D - 0.1, 0), V(0, py + 1.4, 0), 0.15, K.metal, M.SmoothPlastic).CastShadow = false
	Lobby.disc(s, 'SpawnPendantCap', 1.2, 0.5, V(0, py + 1.0, 0), K.metal)
	Lobby.disc(s, 'SpawnPendant', 3.2, 1.2, V(0, py - 0.2, 0), K.metal)
	Lobby.disc(s, 'SpawnPendantRim', 3.4, 0.2, V(0, py - 0.3, 0), K.gold)
	local lamp = decor(Lobby.disc(s, 'SpawnPendantLamp', 2.6, 0.06, V(0, py - 0.36, 0), K.bulb, M.Neon))
	lamp.CastShadow = false
	Lobby.spot(lamp, Enum.NormalId.Bottom, 45, 28, 1.5)
	-- one arrow per destination on the walkway round the dais
	for _, e in { { V(0, 0, -10.5), V(0, 0, -1) }, { V(0, 0, 10.5), V(0, 0, 1) }, { V(-10.5, 0, 0), V(-1, 0, 0) }, { V(10.5, 0, 0), V(1, 0, 0) } } do
		Lobby.arrow(s, e[1] + V(0, 0.01, 0), e[2])
	end
	-- the spawn point (StageService and SetActive use it)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(9, 0.2, 9)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, Lobby.DaisTop + 0.1, 0)) * CFrame.Angles(0, yaw, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CastShadow = false
	for _, d in spawn:GetChildren() do if d:IsA('Decal') then d:Destroy() end end
	spawn.Parent = s.parent
	return s
end

---------------------------------------------------------------------------------------------- fast travel
-- FAST TRAVEL: a bus-stop shelter east of the exit, off the main walk. Charcoal posts and a flat roof with a wood
-- fascia, frosted glass sides, a framed route board on the roof, a subway-style roundel on a pole, a warm strip
-- light under the roof, and under it the pad (FurthestPad: to the furthest stage you cleared): a charcoal
-- plinth with a chamfer step, a thin gold status ring and a cream disc.
function Lobby.kiosk(L)
	local K, T, F, N = Lobby.Colors, Lobby.T, Lobby.F, Lobby.N
	local k = L:group('FastTravel')
	local x0, x1, z0, z1, rh = 18.4, 28.4, N + 0.6, N + 7.8, 9
	local cx, cz = (x0 + x1) / 2, N + 4.6
	for _, x in { x0 + 0.25, x1 - 0.25 } do
		for _, z in { z0 + 0.25, z1 - 0.25 } do k:box('ShelterPost', V(x - 0.25, 0, z - 0.25), V(x + 0.25, rh, z + 0.25), K.metal, M.SmoothPlastic) end
		-- frosted glass side panel in a thin frame
		local glass = k:box('ShelterGlass', V(x - 0.08, 1.2, z0 + 0.6), V(x + 0.08, rh - 1.2, z1 - 1.6), C(214, 220, 220), M.Glass)
		glass.Transparency, glass.CastShadow = 0.45, false
		k:box('ShelterRail', V(x - 0.15, 1.0, z0 + 0.5), V(x + 0.15, 1.2, z1 - 1.5), K.metal, M.SmoothPlastic)
		k:box('ShelterRail', V(x - 0.15, rh - 1.2, z0 + 0.5), V(x + 0.15, rh - 1.0, z1 - 1.5), K.metal, M.SmoothPlastic)
	end
	k:box('ShelterRoof', V(x0 - 0.4, rh, z0), V(x1 + 0.4, rh + 0.45, z1 + 0.6), K.metal, M.SmoothPlastic)
	k:box('ShelterFascia', V(x0 - 0.45, rh - 0.35, z1 + 0.6), V(x1 + 0.45, rh + 0.5, z1 + 0.85), K.wood, M.Wood)
	local strip = decor(k:box('ShelterLight', V(x0 + 1, rh - 0.12, cz - 0.2), V(x1 - 1, rh, cz + 0.2), K.bulb, M.Neon))
	strip.CastShadow = false
	light(strip, C(255, 214, 150), 0.8, 14)
	-- the route board on the roof's front edge
	Lobby.sign(k, 'FastTravelSign', CFrame.lookAt(V(cx, rh + 1.95, z1 + 0.3), V(cx, rh + 1.95, 100)), 9.2, 2.2, {
		{ 'Title', 'FAST TRAVEL', T.cream, F.display, 0.08, 0.5 },
		{ 'Sub', '▸ YOUR FURTHEST STAGE', T.gold, F.plain, 0.64, 0.26 },
	}, { frame = 'steel', ppS = 30 })
	-- the pad
	local pad = Lobby.disc(k, 'FurthestPad', 7.6, 0.4, V(cx, 0, cz), K.metal)
	Lobby.disc(k, 'FurthestPadStep', 7.0, 0.2, V(cx, 0.4, cz), K.metalLight)
	decor(Lobby.disc(k, 'FurthestPadRing', 6.2, 0.02, V(cx, 0.6, cz), K.goldNeon, M.Neon)).CastShadow = false
	decor(Lobby.disc(k, 'FurthestPadDisc', 5.6, 0.035, V(cx, 0.6, cz), K.wall)).CastShadow = false
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'Teleport'
	prompt.ActionText = 'Fast travel'
	prompt.ObjectText = 'Furthest stage'
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', 'Furthest')
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	-- the stop's roundel on a pole beside the shelter (teal = go)
	local px, pz = x1 + 1.4, z1 - 0.4
	k:post('StopPole', 0.16, 10.4, V(px, 0, pz), K.metal, M.SmoothPlastic)
	local face = CFrame.new(px, 9.4, pz) * CFrame.Angles(0, math.pi / 2, 0)
	k:part('StopRoundel', V(0.2, 2.6, 2.6), face, K.teal, M.SmoothPlastic, Enum.PartType.Cylinder)
	k:part('StopRoundel', V(0.24, 1.7, 1.7), face, K.wall, M.SmoothPlastic, Enum.PartType.Cylinder)
	k:part('StopRoundelBar', V(2.9, 0.55, 0.3), CFrame.new(px, 9.4, pz), K.ink, M.SmoothPlastic)
	Lobby.Slots.FurthestPad = CFrame.new(cx, 0, cz)
	return k
end

---------------------------------------------------------------------------------------------- world 2
-- WORLD 2, locked and quiet: a closed roll-up garage door in a charcoal frame in the north wall west of the exit,
-- warm grey slats, a padlocked hasp, a small framed WORLD 2 board over it and the one SOON tag. Its prompt says
-- it is coming soon.
function Lobby.world2(L, x)
	local K, T, F, N = Lobby.Colors, Lobby.T, Lobby.F, Lobby.N
	local g = L:group('World2Door')
	local w, ht = 6.5, 13
	for _, sx in { -1, 1 } do
		local a, b = x + sx * w, x + sx * (w + 1.2)
		g:box('World2Jamb', V(math.min(a, b), 0, N), V(math.max(a, b), ht + 1.6, N + 1.1), K.metal, M.SmoothPlastic)
	end
	g:box('World2Header', V(x - w - 1.2, ht, N), V(x + w + 1.2, ht + 1.6, N + 1.1), K.metal, M.SmoothPlastic)
	local door = g:box('World2Slats', V(x - w, 0.5, N), V(x + w, ht, N + 0.5), C(166, 160, 150), M.SmoothPlastic)
	Lobby.stripes(door, Enum.NormalId.Back, 2 * w, ht - 0.5, 0.8, 0.16, false, 0.72, K.ink)
	g:box('World2Rail', V(x - w, 0, N), V(x + w, 0.5, N + 0.6), K.metal, M.SmoothPlastic)
	-- the hasp and padlock at the door's foot
	g:box('World2Hasp', V(x - 0.9, 0.5, N + 0.5), V(x + 0.9, 1.0, N + 0.7), K.metalLight, M.SmoothPlastic)
	g:box('Padlock', V(x - 0.45, 0.2, N + 0.7), V(x + 0.45, 0.95, N + 1.05), C(150, 116, 64), M.SmoothPlastic)
	g:part('PadlockShackle', V(0.12, 0.8, 0.8), CFrame.new(x, 1.05, N + 0.88) * CFrame.Angles(0, math.pi / 2, 0), K.metalLight, M.SmoothPlastic, Enum.PartType.Cylinder)
	Lobby.sign(g, 'World2Sign', CFrame.lookAt(V(x, ht + 3.1, N + 0.75), V(x, ht + 3.1, 100)), 8, 2, {
		{ 'Title', 'WORLD 2', T.cream, F.display, 0.12, 0.76 },
	}, { frame = 'steel', ppS = 30 })
	Lobby.soon(g, 'World2Soon', CFrame.lookAt(V(x + 6.0, ht + 3.1, N + 0.75), V(x + 6.0, ht + 3.1, 100)) * CFrame.Angles(0, 0, math.rad(-5)), 2.6)
	local zone = g:box('World2Gate', V(x - w, 0, N + 0.6), V(x + w, 0.2, N + 3.2), K.wall)
	zone.Transparency, zone.CanCollide, zone.CastShadow = 1, false, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	Lobby.Slots.World2Portal = CFrame.new(x, 0, N) * CFrame.Angles(0, math.pi, 0)
	return g
end

---------------------------------------------------------------------------------------------- islands
-- The four panels between the walkway's arms become calm islands: brick planters with hedges, small trees in
-- round planters, wood benches facing each other on a rug, a floor lamp's warm pool of light. The walkways stay
-- clear. Small props (benches, lamps, planters) cast no shadow (no visible change, fewer casters).
-- A brick planter box (w along x, d along z, on the floor at pos) with a wood cap and a hedge in it.
function Lobby.planter(c, pos, w, d, ht)
	local K = Lobby.Colors
	local g = c:group('Planter')
	ht = ht or 1.4
	g:box('PlanterBox', pos + V(-w / 2, 0, -d / 2), pos + V(w / 2, ht, d / 2), K.brick, M.Brick)
	g:box('PlanterCap', pos + V(-w / 2 - 0.15, ht, -d / 2 - 0.15), pos + V(w / 2 + 0.15, ht + 0.2, d / 2 + 0.15), K.wood, M.Wood)
	local n = math.max(1, math.floor(w / 1.9 + 0.5))
	for k = 1, n do
		local x = -w / 2 + (k - 0.5) * w / n
		local tone = k % 2 == 0 and K.leaf or K.leafDark:Lerp(K.leaf, 0.5)
		g:blob('Hedge', V(w / n + 0.5, 1.5 + (k % 3) * 0.2, d - 0.2), pos + V(x, ht + 0.6, 0), tone, M.SmoothPlastic)
	end
	return g
end
-- A small tree (about 8 tall) in a round brick planter with a wood rim.
function Lobby.tree(c, pos, turn)
	local K = Lobby.Colors
	local g = c:group('Tree')
	Lobby.disc(g, 'TreePlanter', 3.6, 1.3, pos, K.brick, M.Brick)
	Lobby.disc(g, 'TreePlanterRim', 3.9, 0.2, pos + V(0, 1.3, 0), K.wood, M.Wood)
	Lobby.disc(g, 'TreeSoil', 3.2, 0.06, pos + V(0, 1.5, 0), C(92, 72, 58))
	Lobby.disc(g, 'TreeTrunk', 0.6, 3.6, pos + V(0, 1.5, 0), K.woodDark, M.Wood)
	local a = turn or 0
	local function off(x, z) return V(x * math.cos(a) - z * math.sin(a), 0, x * math.sin(a) + z * math.cos(a)) end
	g:bar('TreeBranch', pos + V(0, 4.0, 0), pos + off(0.9, 0.3) + V(0, 5.2, 0), 0.3, K.woodDark, M.Wood)
	g:blob('TreeCrown', V(4.2, 3.4, 4.2), pos + V(0, 6.0, 0), K.leaf, M.SmoothPlastic)
	g:blob('TreeCrown', V(3.2, 2.8, 3.2), pos + off(0.9, 0.4) + V(0, 7.2, 0), K.leaf:Lerp(P.white, 0.06), M.SmoothPlastic)
	g:blob('TreeCrown', V(3.0, 2.4, 3.0), pos + off(-1.1, -0.5) + V(0, 5.4, 0), K.leafDark, M.SmoothPlastic)
	return g
end
-- A park bench (6 long on local x, the sitter facing local -Z): charcoal side frames, three wood seat slats, a
-- two-slat backrest.
function Lobby.bench(c, cf)
	local K = Lobby.Colors
	local b = c:at(cf):group('Bench')
	for _, x in { -2.5, 2.5 } do
		b:box('BenchFrame', V(x - 0.15, 0, -0.75), V(x + 0.15, 1.6, 0.75), K.metal, M.SmoothPlastic)
		b:box('BenchBackPost', V(x - 0.12, 1.6, 0.55), V(x + 0.12, 3.5, 0.79), K.metal, M.SmoothPlastic)
	end
	for _, z in { -0.55, 0, 0.55 } do b:box('BenchSlat', V(-3.1, 1.6, z - 0.22), V(3.1, 1.78, z + 0.22), K.wood, M.Wood) end
	for _, y in { 2.4, 3.1 } do b:part('BenchBack', V(6.2, 0.45, 0.16), CFrame.new(0, y, 0.82) * CFrame.Angles(math.rad(-8), 0, 0), K.wood, M.Wood) end
	return b
end
-- A rug on an island (x0..x1, z0..z1): a field, a darker border band and a thin cream line inside it.
function Lobby.rug(c, x0, z0, x1, z1, color)
	local K = Lobby.Colors
	local y0 = 0.06
	decor(c:box('Rug', V(x0, y0, z0), V(x1, y0 + 0.04, z1), color, M.Fabric)).CastShadow = false
	local dark = color:Lerp(K.ink, 0.25)
	for _, e in { { x0, z0, x1, z0 + 0.7 }, { x0, z1 - 0.7, x1, z1 }, { x0, z0 + 0.7, x0 + 0.7, z1 - 0.7 }, { x1 - 0.7, z0 + 0.7, x1, z1 - 0.7 } } do
		decor(c:box('RugBorder', V(e[1], y0 + 0.04, e[2]), V(e[3], y0 + 0.05, e[4]), dark, M.Fabric)).CastShadow = false
	end
	local i = 1.1
	for _, e in { { x0 + i, z0 + i, x1 - i, z0 + i + 0.18 }, { x0 + i, z1 - i - 0.18, x1 - i, z1 - i }, { x0 + i, z0 + i, x0 + i + 0.18, z1 - i }, { x1 - i - 0.18, z0 + i, x1 - i, z1 - i } } do
		decor(c:box('RugLine', V(e[1], y0 + 0.04, e[2]), V(e[3], y0 + 0.05, e[4]), K.cream, M.Fabric)).CastShadow = false
	end
end
-- A floor lamp: a charcoal pole on a stone foot, a cream drum shade, a warm bulb under it (a pool of light).
function Lobby.floorLamp(c, pos)
	local K = Lobby.Colors
	local g = c:group('FloorLamp')
	Lobby.disc(g, 'LampFoot', 1.5, 0.25, pos, K.stone)
	Lobby.disc(g, 'LampPole', 0.3, 6.6, pos + V(0, 0.25, 0), K.metal)
	Lobby.disc(g, 'LampShade', 2.4, 1.5, pos + V(0, 6.4, 0), K.cream, M.Fabric)
	local bulb = decor(Lobby.disc(g, 'LampBulb', 1.8, 0.08, pos + V(0, 6.34, 0), K.bulb, M.Neon))
	bulb.CastShadow = false
	light(bulb, C(255, 214, 150), 0.9, 16)
	return g
end
-- A seating corner: two benches facing each other across a rug (centre cx, cz; the benches along x).
function Lobby.lounge(c, cx, cz, color, along)
	local w, d = along == 'z' and 9 or 12, along == 'z' and 12 or 9
	Lobby.rug(c, cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, color)
	if along == 'z' then
		Lobby.bench(c, CFrame.new(cx - 3.1, 0.06, cz) * CFrame.Angles(0, -math.pi / 2, 0))
		Lobby.bench(c, CFrame.new(cx + 3.1, 0.06, cz) * CFrame.Angles(0, math.pi / 2, 0))
	else
		Lobby.bench(c, CFrame.new(cx, 0.06, cz - 3.1) * CFrame.Angles(0, math.pi, 0))
		Lobby.bench(c, CFrame.new(cx, 0.06, cz + 3.1))
	end
end
function Lobby.islands(L)
	local K = Lobby.Colors
	local g = L:group('Islands')
	local y = 0.06 -- the panels' top
	-- NW (the arrival frame's foreground): low in front, the trees and the hedge at its far (north) end.
	Lobby.planter(g, V(-19, y, 18.7), 10, 2.4)
	Lobby.tree(g, V(-26.4, y, 19.6), 0.4)
	Lobby.tree(g, V(-11.6, y, 19.6), 2.1)
	Lobby.lounge(g, -19, 37, K.rugTerra, 'z')
	Lobby.floorLamp(g, V(-27.2, y, 29.5))
	-- NE: the DAILY CRATE (Lobby.rewards) by the walk to the exit, a lounge, a tree, a hedge and a lamp.
	Lobby.planter(g, V(16.5, y, 18.7), 9, 2.4)
	Lobby.lounge(g, 19, 29, K.rugSand, 'z')
	Lobby.tree(g, V(26.6, y, 19.8), 1.2)
	Lobby.tree(g, V(26.6, y, 55.2), 3.0)
	Lobby.floorLamp(g, V(11.4, y, 39.8))
	-- SW: a quiet corner, low on the terrace side (the ranges' view), trees along the south arm.
	Lobby.lounge(g, -20, 90, K.rugTeal, 'x')
	Lobby.tree(g, V(-11.4, y, 77.8), 0.8)
	Lobby.tree(g, V(-11.4, y, 117.2), 2.6)
	Lobby.planter(g, V(-19.5, y, 118.6), 9, 2.2)
	Lobby.floorLamp(g, V(-12.2, y, 96.5))
	-- SE: the VIP SAFE and LUCKY SHOT (Lobby.rewards) by the armory, a lounge, trees by the south arm.
	Lobby.lounge(g, 19.5, 110, K.rugTerra, 'x')
	Lobby.tree(g, V(11.4, y, 117.2), 1.7)
	Lobby.planter(g, V(21, y, 118.6), 10, 2.2)
	Lobby.floorLamp(g, V(26.8, y, 96.5))
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Size.X * p.Size.Y * p.Size.Z < 40 then p.CastShadow = false end
	end
	return g
end

---------------------------------------------------------------------------------------------- ranges
-- The ranges stand on one stepped terrace along the west wall: each lane's base runs from the wall to the
-- promenade's straight front edge (x -37), 1.2 higher than the lane before; along the promenade each tier starts
-- with a half step. Concrete risers, wood treads on the promenade, a muted yellow nosing only on real edges,
-- charcoal guard rails along the front (BAY 1's front is a wide step, open to the floor), frosted glass dividers
-- between the lanes, and one charcoal enamel plaque per BAY with its requirement, its frame running bronze, silver,
-- gold, diamond up the tiers. Stairs: two treads up to Starter at the north end and across its front, a side stair
-- from the Heavy lane down to the cross walkway, and a grand stair off Gold's south end; charcoal cheeks and rails.
-- Stair treads from the landing at `top` down to the floor, running along axis ('x' or 'z') in direction sign;
-- (x0..x1, z0..z1) is the whole stair's footprint. Concrete bodies, wood treads, a muted yellow nosing.
function Lobby.terraceStair(t, name, x0, x1, z0, z1, top, axis, sign)
	local K = Lobby.Colors
	local run = axis == 'x' and (x1 - x0) or (z1 - z0)
	local n = math.max(1, math.floor(run + 0.5))
	local rise = top / (n + 1)
	for k = 1, n do
		local hgt = top - k * rise
		local a = sign > 0 and (k - 1) or (n - k)
		local lo = (axis == 'x' and x0 or z0) + a * run / n
		local hi = lo + run / n
		local A = axis == 'x' and V(lo, 0, z0) or V(x0, 0, lo)
		local B = axis == 'x' and V(hi, hgt - 0.2, z1) or V(x1, hgt - 0.2, hi)
		t:box(name, A, B, K.concrete, M.SmoothPlastic)
		t:box(name .. 'Tread', axis == 'x' and V(lo, hgt - 0.2, z0) or V(x0, hgt - 0.2, lo), axis == 'x' and V(hi, hgt, z1) or V(x1, hgt, hi), K.wood, M.Wood)
		-- the nosing on the tread's leading edge (the side facing down the stair)
		local e = sign > 0 and hi or lo
		local d = sign > 0 and -0.3 or 0.3
		local na = axis == 'x' and V(e, hgt - 0.02, z0) or V(x0, hgt - 0.02, e)
		local nb = axis == 'x' and V(e + d, hgt + 0.02, z1) or V(x1, hgt + 0.02, e + d)
		decor(t:box('StairNosing', na, nb, K.edge, M.SmoothPlastic)).CastShadow = false
	end
	return rise
end
-- A charcoal sloped cheek (a wedge) on a stair's open side, from `top` at a down to 0 at b, u0..u1 thick, with a
-- charcoal handrail on two posts above it.
function Lobby.stairCheek(t, axis, u0, u1, a, b, top)
	local K = Lobby.Colors
	local len = math.abs(b - a)
	local mid = (a + b) / 2
	local u = (u0 + u1) / 2
	if axis == 'z' then
		t:wedge('TerraceCheek', V(math.abs(u1 - u0), top, len), CFrame.new(u, top / 2, mid) * CFrame.Angles(0, b > a and math.pi or 0, 0), K.metal, M.SmoothPlastic)
	else
		t:wedge('TerraceCheek', V(math.abs(u1 - u0), top, len), CFrame.new(mid, top / 2, u) * CFrame.Angles(0, b > a and -math.pi / 2 or math.pi / 2, 0), K.metal, M.SmoothPlastic)
	end
	local function P3(along, y) return axis == 'z' and V(u, y, along) or V(along, y, u) end
	local s = b > a and 1 or -1
	local pa, pb = a + s * 0.4, b - s * 0.6
	local ha = top * (1 - math.abs(pa - a) / len) + 3
	local hb = top * (1 - math.abs(pb - a) / len) + 3
	t:bar('StairRailPost', P3(pa, 0), P3(pa, ha), 0.25, K.metal, M.SmoothPlastic)
	t:bar('StairRailPost', P3(pb, 0), P3(pb, hb), 0.25, K.metal, M.SmoothPlastic)
	t:bar('StairRail', P3(pa, ha), P3(pb, hb), 0.3, K.metal, M.SmoothPlastic)
end
-- A run of guard rail along the promenade's front edge at x, from z0 to z1 at deck height h: posts every ~5
-- studs, a top rail at h + 3 and a mid rail.
function Lobby.guardRail(t, x, z0, z1, h)
	local K = Lobby.Colors
	local n = math.max(1, math.ceil((z1 - z0) / 5))
	for k = 0, n do
		local z = z0 + (z1 - z0) * k / n
		t:box('GuardPost', V(x - 0.14, h, z - 0.14), V(x + 0.14, h + 3, z + 0.14), K.metal, M.SmoothPlastic)
	end
	t:box('GuardRail', V(x - 0.18, h + 3, z0 - 0.14), V(x + 0.18, h + 3.25, z1 + 0.14), K.metal, M.SmoothPlastic)
	t:box('GuardRail', V(x - 0.08, h + 1.5, z0), V(x + 0.08, h + 1.66, z1), K.metal, M.SmoothPlastic)
end
function Lobby.rangeRow(L, skins)
	local K, W = Lobby.Colors, Lobby.W
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	local t = L:group('RangeTerrace')
	local XS, XF = Lobby.RangeX + 10, Lobby.TerraceX -- the shooter's end (-43) and the promenade's front (-37)
	local hz, rise, n = Lobby.RangePitch / 2, Lobby.RangeRise, #Lobby.Ranges
	local function nose(a, b) decor(t:box('TerraceNosing', a, b, K.edge, M.SmoothPlastic)).CastShadow = false end
	local zN = Lobby.RangeZ0 - hz -- the terrace's north end (28.75)
	local zS = Lobby.RangeZ0 + (n - 0.5) * Lobby.RangePitch -- its south end (112.75)
	local si = Lobby.SideStair
	local sz, sh = Lobby.RangeZ0 + (si - 1) * Lobby.RangePitch, si * rise
	for i, id in Lobby.Ranges do
		local z = Lobby.RangeZ0 + (i - 1) * Lobby.RangePitch
		local h = i * rise
		local z0, z1 = z - hz, z + hz
		-- the body under the lane (concrete) and the promenade in front of it (concrete with a wood deck)
		local zp = i == 1 and z0 or z0 + 1
		t:box('TerraceBase', V(-W, 0, z0), V(XS, h, z1), K.concrete, M.SmoothPlastic)
		t:box('TerraceBase', V(XS, 0, zp), V(XF, h - 0.2, z1), K.concrete, M.SmoothPlastic)
		t:box('TerraceDeck', V(XS, h - 0.2, zp), V(XF, h, z1), K.wood, M.Wood)
		if i > 1 then
			-- the half step up from the tier before
			t:box('TerraceStep', V(XS, 0, z0), V(XF, h - rise / 2 - 0.2, z0 + 1), K.concrete, M.SmoothPlastic)
			t:box('TerraceStepTread', V(XS, h - rise / 2 - 0.2, z0), V(XF, h - rise / 2, z0 + 1), K.wood, M.Wood)
			nose(V(XS, h - rise / 2 - 0.02, z0), V(XF - 0.02, h - rise / 2 + 0.02, z0 + 0.3))
			nose(V(XS, h - 0.02, z0 + 1), V(XF - 0.02, h + 0.02, z0 + 1.3))
		end
		-- the promenade's front edge
		nose(V(XF - 0.3, h - 0.02, zp), V(XF, h + 0.02, z1))
		local cf = CFrame.new(Lobby.RangeX, h, z) * CFrame.Angles(0, -math.pi / 2, 0)
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Range_' .. id, cf, { X = 9, Y = 12, Z0 = -10, Z1 = 10 }, string.upper(s and s.Name or id), C(140, 150, 140),
			Stations and function(c) Stations.build(c, id, {}) end)
	end
	-- Gold's south face toward the armory: nosing along its top.
	nose(V(-W, n * rise - 0.02, zS - 0.3), V(XS, n * rise + 0.02, zS))
	-- North stair to Starter across the terrace's whole width, and BAY 1's front as a wide step down to the floor.
	Lobby.terraceStair(t, 'TerraceStair', -W, XF, zN - 2, zN, rise, 'z', -1)
	Lobby.terraceStair(t, 'TerraceStair', XF, XF + 2, zN, zN + Lobby.RangePitch, rise, 'x', 1)
	-- Side stair from the Heavy lane down to the cross walkway (6 wide), cheeks and rails both sides.
	Lobby.terraceStair(t, 'TerraceStair', XF, XF + 4, sz - 3, sz + 3, sh, 'x', 1)
	for _, u in { sz - 3.4, sz + 3 } do Lobby.stairCheek(t, 'x', u, u + 0.4, XF, XF + 5, sh) end
	-- Grand stair off Gold's south end (x -43..-37), cheeks and rails both sides.
	Lobby.terraceStair(t, 'TerraceStair', XS + 0.4, XF - 0.4, zS, zS + 9, n * rise, 'z', 1)
	for _, u in { XS, XF - 0.4 } do Lobby.stairCheek(t, 'z', u, u + 0.4, zS, zS + 10, n * rise) end
	Lobby.terraceDressing(t, skins, XS, XF, zN, zS, n, rise)
end
-- Frosted neutral glass dividers between the lanes (stepping up 1.2 a tier) on charcoal posts with a charcoal cap,
-- and one plaque per BAY on two charcoal posts at the promenade's front: ink enamel with "BAY n" in cream and its
-- requirement (FREE in teal on BAY 1), framed in its tier's metal.
function Lobby.terraceDressing(t, skins, XS, XF, zN, zS, n, rise)
	local K, T, F = Lobby.Colors, Lobby.T, Lobby.F
	local pitch = Lobby.RangePitch
	local fins = { zN + 0.25 }
	for k = 1, n - 1 do table.insert(fins, zN + k * pitch - 0.45) end
	table.insert(fins, zS - 0.35)
	local postX = XS - 0.6
	for _, fz in fins do
		local tier = math.clamp(math.floor((fz - zN) / pitch) + 1, 1, n)
		local base, top = tier * rise, tier * rise + 7
		local glass = t:box('StallFin', V(-52, base, fz - 0.2), V(postX - 0.6, top, fz + 0.2), C(226, 228, 226), M.Glass)
		glass.Transparency, glass.CastShadow = 0.5, false
		t:box('StallFinCap', V(-52, top, fz - 0.25), V(postX, top + 0.3, fz + 0.25), K.metal, M.SmoothPlastic)
		t:box('StallPost', V(postX - 0.6, base, fz - 0.3), V(postX, top, fz + 0.3), K.metal, M.SmoothPlastic)
	end
	-- Per lane: the guard rail along the front (broken for its plaque and, on the Heavy lane, for the side stair)
	-- and its plaque: set into the rail, on two posts at BAY 1's open front, on a gateway over the side stair.
	local si = Lobby.SideStair
	local sz = Lobby.RangeZ0 + (si - 1) * pitch
	local x = XF - 0.35
	for i, id in Lobby.Ranges do
		local h = i * rise
		local z = Lobby.RangeZ0 + (i - 1) * pitch
		local zp, z1 = i == 1 and z - pitch / 2 or z - pitch / 2 + 1, z + pitch / 2
		local s = skins.StationById[id]
		local req = i == 1 and 'FREE' or ('💪 ' .. compact(s and s.Required or 0))
		local py, pz = h + 2.25, i == 1 and z - pitch / 2 + 2.2 or z -- (BAY 1's sits at its front step's north end)
		if i == si then
			py = h + 7.5
			for _, dz in { -3.25, 3.25 } do t:box('GatePost', V(x - 0.2, h, sz + dz - 0.2), V(x + 0.2, h + 6.25, sz + dz + 0.2), K.metal, M.SmoothPlastic) end
			t:box('GateBeam', V(x - 0.25, h + 6, sz - 3.45), V(x + 0.25, h + 6.3, sz + 3.45), K.metal, M.SmoothPlastic)
			Lobby.guardRail(t, x, zp + 0.2, sz - 3.45, h)
			Lobby.guardRail(t, x, sz + 3.45, z1 - 0.2, h)
		else
			for _, dz in { -1.25, 1.25 } do t:box('PlaquePost', V(x - 0.14, h, pz + dz - 0.14), V(x + 0.14, h + 1.0, pz + dz + 0.14), K.metal, M.SmoothPlastic) end
			if i > 1 then
				Lobby.guardRail(t, x, zp + 0.2, pz - 2.05, h)
				Lobby.guardRail(t, x, pz + 2.05, z1 - 0.2, h)
			end
		end
		Lobby.sign(t, 'BayPlaque', CFrame.lookAt(V(x + 0.3, py, pz), V(100, py, pz)), 3.2, 1.7, {
			{ 'Bay', 'BAY ' .. i, T.cream, F.display, 0.06, 0.5 },
			{ 'Req', req, i == 1 and T.teal or T.gold, F.display, 0.56, 0.38 },
		}, { frame = Lobby.TierColors[i], ppS = 40 })
	end
end

---------------------------------------------------------------------------------------------- shoe box dais
-- The back wall's centre: a stepped wood-and-cream podium rising to the centre (0.6, 1.2, 2.4, 3.6): wood risers
-- under cream tops with a lip, a teal carpet runner with gold stair rods up its middle to the legendary box, big
-- cartoon shoe boxes turning over cream pedestals - COMMON and RARE up the left, the LEGENDARY on top (lid ajar, a
-- high-top peeking out), EPIC on the right, a stack of plain boxes on the right foot - each named on a small ink
-- plate on its pedestal. The boxes carry the colour. One warm pendant spotlight over it; the SHOE BOXES sign and
-- the one SOON tag on the wall above (Lobby.hall). One ComingSoon prompt ("Shoe Boxes"); no unboxing yet.
-- Lobby.Slots.ShoeBoxes is the dais's front centre on the floor, facing the hall; Lobby.SlotSizes.ShoeBoxes its
-- size (local x -19..19, y up to 14, z 0..17.2).
Lobby.ShoeDais = { X = 19, Z0 = 138.8 }
Lobby.SlotSizes = {}
Lobby.ShoeBoxes = {
	{ Name = 'COMMON', Color = C(150, 158, 176), Trim = C(236, 238, 244), X = 15.8, Z = 144, Level = 1 },
	{ Name = 'RARE', Color = C(50, 130, 240), Trim = C(170, 214, 255), X = 8.4, Z = 147.2, Level = 2 },
	{ Name = 'LEGENDARY', Color = C(250, 190, 30), Trim = C(255, 240, 160), X = 0, Z = 149.6, Level = 3, Hero = true },
	{ Name = 'EPIC', Color = C(150, 80, 230), Trim = C(220, 180, 255), X = -8.4, Z = 147.2, Level = 2 },
}
-- One shoe box (local: centre bottom at the origin, front -Z): a body in the rarity colour with two slanted side
-- stripes and the rarity word on the front, tissue paper showing over the rim, a white lid that overhangs and sits
-- a little lifted, a band of the rarity colour round it and a 👟 on its top. ajar: the lid tips open at the back
-- and a high-top peeks out.
function Lobby.shoeBox(c, b, scale, ajar)
	local k = scale or 1
	local function B(name, lo, hi, color, mat) return c:box(name, lo * k, hi * k, color, mat or M.SmoothPlastic) end
	B('ShoeBoxBody', V(-2.5, 0, -1.7), V(2.5, 2.3, 1.7), b.Color)
	for _, sx in { -1, 1 } do
		local x = sx * 2.53
		c:part('ShoeBoxFlash', V(0.06, 0.42, 2.6) * k, CFrame.new(V(x, 1.4, 0.1) * k) * CFrame.Angles(math.rad(-18), 0, 0), b.Trim, M.SmoothPlastic)
		c:part('ShoeBoxFlash', V(0.06, 0.26, 1.8) * k, CFrame.new(V(x, 0.7, -0.3) * k) * CFrame.Angles(math.rad(-18), 0, 0), b.Trim, M.SmoothPlastic)
	end
	local face = ghost(c:part('ShoeBoxFace', V(4.6, 1.8, 0.05) * k, CFrame.new(V(0, 1.1, -1.75) * k), P.white))
	line(surface(face, Enum.NormalId.Front, 20), 'Rarity', b.Name, P.white, Lobby.F.display, 0.2, 0.6, b.Color:Lerp(P.black, 0.5), 2)
	for j = -1, 1 do
		c:part('ShoeBoxTissue', V(1.7, 0.5, 3.0) * k, CFrame.new(V(j * 1.55, 2.4, 0) * k) * CFrame.Angles(0, 0, math.rad(j * 9)), C(248, 240, 228), M.SmoothPlastic)
	end
	local lc = ajar and (CFrame.new(V(0, 2.75, 1.85) * k) * CFrame.Angles(math.rad(32), 0, 0) * CFrame.new(V(0, 0, -1.9) * k)) or CFrame.new(V(0, 2.75, 0) * k)
	local lid = c:part('ShoeBoxLid', V(5.4, 0.7, 3.8) * k, lc * CFrame.new(V(0, 0.35, 0) * k), C(246, 244, 240), M.SmoothPlastic)
	c:part('ShoeBoxLidBand', V(5.44, 0.14, 3.84) * k, lc * CFrame.new(V(0, 0.07, 0) * k), b.Color:Lerp(P.white, 0.1), M.SmoothPlastic)
	line(surface(lid, Enum.NormalId.Top, 16), 'Logo', '👟', P.white, Lobby.F.display, 0.12, 0.76)
	line(surface(lid, Enum.NormalId.Front, 20), 'Brand', 'KICKS', b.Color:Lerp(P.black, 0.25), Lobby.F.display, 0.04, 0.68)
	if ajar then
		local s = c:at(CFrame.new(V(0.2, 2.2, -0.2) * k) * CFrame.Angles(math.rad(-30), math.rad(20), 0))
		local function S(name, lo, hi, color) s:box(name, lo * k, hi * k, color, M.SmoothPlastic) end
		S('PeekSole', V(-0.6, 0, -1.5), V(0.6, 0.3, 1.5), P.white)
		S('PeekUpper', V(-0.55, 0.3, -1.2), V(0.55, 1.2, 1.4), C(230, 40, 52))
		S('PeekToe', V(-0.55, 0.3, -1.5), V(0.55, 0.8, -1.2), P.white)
		S('PeekCollar', V(-0.45, 1.2, 0.5), V(0.45, 1.7, 1.4), C(255, 210, 40))
		S('PeekStripe', V(-0.58, 0.55, -0.6), V(0.58, 0.85, 1.0), P.white)
	end
end
function Lobby.shoeDais(L)
	local K, T, F, S = Lobby.Colors, Lobby.T, Lobby.F, Lobby.S
	local d0 = Lobby.ShoeDais
	local X, z0 = d0.X, d0.Z0
	local d = L:group('ShoeBoxDais')
	-- the podium: each level a wood body under a cream top with a 0.2 lip
	local levels = { { X - 2, z0 - 1.2, 0.6 }, { X, z0, 1.2 }, { 11.2, z0 + 4.6, 2.4 }, { 3.8, z0 + 7.4, 3.6 } }
	for i, l in levels do
		d:box(i == 1 and 'ShoeDaisStep' or 'ShoeDais', V(-l[1], 0, l[2]), V(l[1], l[3] - 0.25, S), K.wood, M.Wood)
		d:box('ShoeDaisTop', V(-l[1] - 0.2, l[3] - 0.25, l[2] - 0.2), V(l[1] + 0.2, l[3], S), K.wall, M.SmoothPlastic)
	end
	-- the carpet runner up the middle, with gold rods at the foot of each riser
	local rw = 2.6
	for i, l in levels do
		local nextZ = levels[i + 1] and levels[i + 1][2] - 0.2 or z0 + 9.2
		decor(d:box('ShoeRunner', V(-rw, l[3], l[2] - 0.2), V(rw, l[3] + 0.03, nextZ), K.teal, M.Fabric)).CastShadow = false
		local below = i > 1 and levels[i - 1][3] or 0
		decor(d:box('ShoeRunner', V(-rw, below, l[2] - 0.23), V(rw, l[3], l[2] - 0.2), K.teal, M.Fabric)).CastShadow = false
		local foot = i > 1 and below + 0.03 or 0.1
		decor(d:box('ShoeRunnerRod', V(-rw - 0.1, foot, l[2] - 0.5), V(rw + 0.1, foot + 0.12, l[2] - 0.38), K.gold, M.SmoothPlastic)).CastShadow = false
	end
	-- the boxes on their pedestals
	for i, b in Lobby.ShoeBoxes do
		local ly = levels[b.Level + 1][3]
		local base = V(b.X, ly, b.Z)
		Lobby.disc(d, 'ShoeBoxPedestalFoot', 3.6, 0.2, base, K.wood, M.Wood)
		Lobby.disc(d, 'ShoeBoxPedestal', 3.2, 0.6, base + V(0, 0.2, 0), K.wall)
		Lobby.disc(d, 'ShoeBoxPedestalBand', 3.26, 0.12, base + V(0, 0.55, 0), b.Color)
		local k = b.Hero and 1.6 or 1.15
		local hover = base + V(0, 0.8 + 0.7, 0)
		local bc, box = d:at(CFrame.new(hover) * CFrame.Angles(0, math.rad(b.Hero and 0 or (b.X > 0 and 14 or -14)), 0)):group('ShoeBox')
		Lobby.shoeBox(bc, b, k, b.Hero)
		Lobby.motion(box, CFrame.new(hover), b.Hero and nil or 10, 0.2, 2.4 + i * 0.2)
		-- its name on a small ink plate on the pedestal's front
		Lobby.sign(d, 'ShoeBoxPlate', CFrame.lookAt(base + V(0, 0.45, -1.78), base + V(0, 0.45, -10)), 2.2, 0.42, {
			{ 'Name', b.Name, b.Color:Lerp(P.white, 0.35), F.display, 0.08, 0.84 },
		}, { frame = 'steel', ppS = 60, rim = 0.08 })
		if b.Hero then
			local fx = Lobby.emitBox(d, 'ShoeBoxFx', hover + V(-4, 0.5, -3), hover + V(4, 6, 3))
			Lobby.fx(fx, 'ShoeBoxGlints', 'sparkle', { Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1),
				Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 150)), LightEmission = 1 })
		end
	end
	-- the stock: a stack of plain closed boxes on the right foot
	local st = d:at(CFrame.new(-14.6, 1.2, 145) * CFrame.Angles(0, math.rad(8), 0))
	for j, e in { { V(-1.6, 0, 0), C(226, 210, 184) }, { V(1.7, 0, 0.3), C(214, 198, 172) }, { V(0, 1.9, 0.1), C(232, 218, 192) } } do
		local sc = st:at(CFrame.new(e[1]) * CFrame.Angles(0, math.rad(j * 7 - 10), 0))
		sc:box('StockBox', V(-1.5, 0, -1.05), V(1.5, 1.5, 1.05), e[2], M.SmoothPlastic)
		sc:box('StockBoxLid', V(-1.6, 1.5, -1.12), V(1.6, 1.9, 1.12), C(244, 240, 232), M.SmoothPlastic)
		sc:box('StockBoxStripe', V(-1.62, 1.55, -0.25), V(1.62, 1.92, 0.25), ({ K.teal, K.brick, K.gold })[j], M.SmoothPlastic)
	end
	-- the one spotlight: a lamp on an arm from the wall over the sign, aimed down at the legendary box
	local lampAt = V(0, 23.4, S - 2.6) -- (just over the sign, under the overview camera's sight line)
	d:bar('ShoeLampArm', V(0, 23.4, S), lampAt, 0.3, K.metal, M.SmoothPlastic)
	local housing = d:part('ShoeLamp', V(2.4, 1.0, 1.3), CFrame.lookAt(lampAt, V(0, 3, 147)), K.metal, M.SmoothPlastic)
	Lobby.spot(housing, Enum.NormalId.Front, 50, 30, 1.6)
	-- the prompt (coming soon), on the dais's front edge
	local hit = ghost(d:box('ShoeBoxPrompt', V(-4, 1.2, z0 + 0.4), V(4, 4.2, z0 + 2), P.white))
	Lobby.prompt(hit, 'Open', 'Shoe Boxes').MaxActivationDistance = 14
	Lobby.Slots.ShoeBoxes = CFrame.new(0, 0, z0 - 1.2)
	Lobby.SlotSizes.ShoeBoxes = V(2 * X, 14, S - z0 + 1.2)
	return d
end

---------------------------------------------------------------------------------------------- slots
-- Run a builder into its own folder; on a missing builder or an error, a labelled box of the slot's size.
function Lobby.place(L, parent, name, cf, size, label, color, build)
	Lobby.Slots[name] = cf
	local holder = Instance.new('Folder')
	holder.Name = name
	holder.Parent = parent
	local c = L:at(cf):into(holder)
	if build then
		local ok, err = pcall(build, c)
		if ok then return holder end
		warn('[Lobby] ' .. name .. ' builder failed, placeholder used: ' .. tostring(err))
		holder:ClearAllChildren()
	end
	local box = c:box('Placeholder', V(-size.X / 2, 0, size.Z0), V(size.X / 2, size.Y, size.Z1), color, M.SmoothPlastic)
	box.Transparency = 0.35
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front } do line(surface(box, face, 10), 'Text', label, P.white, FONT.loud, 0.2, 0.6, P.black, 2) end
	return holder
end

---------------------------------------------------------------------------------------------- set pieces
-- The rewards: the free DAILY CRATE on the north-east island (on the way to the exit, in view from the spawn),
-- LUCKY SHOT and the VIP SAFE on the south-east island by the armory. Each stands on a layered plinth (a
-- concrete base, a chamfer step, a cream top) with its name on an ink plate on the object. "Coming soon" prompts.
function Lobby.prompt(part, action, object)
	local p = Instance.new('ProximityPrompt')
	p.Name = 'ComingSoon'
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p:SetAttribute('ComingSoon', true)
	p.Parent = part
	return p
end
function Lobby.rewardBase(r, w, d, k)
	local K = Lobby.Colors
	r:box('RewardBase', V(-w / 2, 0, -d / 2), V(w / 2, 0.5 * k, d / 2), K.stone, M.SmoothPlastic)
	r:box('RewardChamfer', V(-w / 2 + 0.25, 0.5 * k, -d / 2 + 0.25), V(w / 2 - 0.25, 0.7 * k, d / 2 - 0.25), K.concrete, M.SmoothPlastic)
	r:box('RewardTop', V(-w / 2 + 0.6, 0.7 * k, -d / 2 + 0.6), V(w / 2 - 0.6, 1.2 * k, d / 2 - 0.6), K.wall, M.SmoothPlastic)
	r:box('RewardTrim', V(-w / 2 + 0.55, 1.1 * k, -d / 2 + 0.55), V(w / 2 - 0.55, 1.18 * k, d / 2 - 0.55), K.gold, M.SmoothPlastic)
end
-- A name plate (ink, gold-framed, cream and gold words) at cf on an object.
function Lobby.namePlate(c, name, cf, w, h, a, b)
	local T, F = Lobby.T, Lobby.F
	return Lobby.sign(c, name, cf, w, h, {
		{ 'A', a, T.gold, F.display, 0.12, 0.76, 0.04, 0.44 },
		{ 'B', b, T.cream, F.display, 0.12, 0.76, 0.5, 0.46 },
	}, { frame = Lobby.Colors.gold, ppS = 40, rim = 0.12 })
end
function Lobby.rewards(L)
	local K = Lobby.Colors
	local gold = K.gold
	-- DAILY CRATE (x0.9): a wooden treasure chest with gold straps, corners and a hasp, a soft glint.
	local k = 0.9
	local r = L:at(Lobby.RewardAt.DailyCrate):group('DailyCrate')
	Lobby.rewardBase(r, 11 * k, 9 * k, k)
	local function Bc(name, a, b, color, mat) return r:box(name, a * k, b * k, color, mat or M.SmoothPlastic) end
	local woodC, lidC = C(146, 98, 62), C(164, 114, 74)
	local body = Bc('CrateBody', V(-4, 1.2, -3), V(4, 5.6, 3), woodC, M.Wood)
	r:part('CrateLid', V(8.4, 6.4, 6.4) * k, CFrame.new(V(0, 5.8, 0) * k), lidC, M.Wood, Enum.PartType.Cylinder)
	for _, x in { -3.4, 3.4 } do r:part('CrateStrap', V(0.6, 6.6, 6.6) * k, CFrame.new(V(x, 5.8, 0) * k), gold, M.SmoothPlastic, Enum.PartType.Cylinder) end
	for _, x in { -4.1, 3.5 } do for _, z in { -3.1, 2.5 } do Bc('CrateCorner', V(x, 1.2, z), V(x + 0.6, 5.9, z + 0.6), gold) end end
	Bc('CrateBand', V(-4.15, 5.3, -3.15), V(4.15, 5.8, 3.15), gold)
	Bc('CrateHasp', V(-0.7, 4.4, -3.5), V(0.7, 6.4, -3.0), gold)
	Lobby.namePlate(r, 'CratePlate', CFrame.new(V(0, 2.6, -3.0) * k - V(0, 0, 0.18)), 5.2 * k, 1.1, 'DAILY', 'CRATE')
	Lobby.prompt(body, 'Open', 'Daily Crate')
	local glint = Lobby.emitBox(r, 'CrateFx', V(-4, 2, -3) * k, V(4, 8.5, 3) * k)
	Lobby.fx(glint, 'CrateGlints', 'sparkle', { Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1),
		Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 150)), LightEmission = 1 })
	light(glint, C(255, 214, 150), 0.7, 12)
	-- LUCKY SHOT (x1.3): a bullseye (gold, cream, ink rings) turning slowly on a charcoal stand.
	k = 1.3
	local g = L:at(Lobby.RewardAt.LuckyShot):group('LuckyShot')
	Lobby.rewardBase(g, 6 * k, 6 * k, k)
	local function Pt(name, rad, h, y, color) return g:post(name, rad * k, h * k, V(0, y * k, 0), color, M.SmoothPlastic) end
	Pt('StandBase', 2.0, 0.8, 1.2, K.metal)
	Pt('StandBand', 1.7, 0.3, 2.0, gold)
	Pt('StandNeck', 0.45, 3.3, 2.3, K.metal)
	local tg, target = g:group('Target')
	for j, e in { { 6.4, gold }, { 5.6, K.cream }, { 4.2, K.ink }, { 2.8, K.cream }, { 1.5, gold } } do
		tg:part('TargetRing', V(0.4 + j * 0.08, e[1], e[1]) * k, CFrame.new(0, 8.6 * k, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	Lobby.motion(target, Lobby.RewardAt.LuckyShot * CFrame.new(0, 8.6 * k, 0), 20)
	Lobby.namePlate(g, 'LuckyPlate', CFrame.new(0, 4.6 * k, -0.45 * k - 0.2), 5.4, 1.1, 'LUCKY', 'SHOT')
	Lobby.prompt(ghost(g:box('TargetHit', V(-2, 1.2, -2) * k, V(2, 5, 2) * k, P.white)), 'Spin', 'Lucky Shot')
	-- VIP SAFE (x1.2): a charcoal safe with a gold dial, handle and trim.
	k = 1.2
	local v = L:at(Lobby.RewardAt.VipSafe):group('VipSafe')
	Lobby.rewardBase(v, 9 * k, 8 * k, k)
	local function B(name, a, b, color, mat) return v:box(name, a * k, b * k, color, mat or M.SmoothPlastic) end
	local safe = B('SafeBody', V(-3.4, 1.2, -2.6), V(3.4, 8.4, 2.6), K.ink)
	B('SafeDoor', V(-2.8, 1.8, -2.9), V(2.8, 7.8, -2.6), K.metal)
	v:part('SafeDial', V(0.4, 2.2, 2.2) * k, CFrame.new(V(-0.8, 6.0, -3.0) * k) * CFrame.Angles(0, math.pi / 2, 0), gold, M.SmoothPlastic, Enum.PartType.Cylinder)
	B('SafeHandle', V(1.2, 4.6, -3.4), V(1.6, 7.2, -2.9), gold)
	B('SafeTrim', V(-3.5, 8.4, -2.7), V(3.5, 8.9, 2.7), gold)
	B('SafeFoot', V(-3.5, 1.2, -2.7), V(3.5, 1.6, 2.7), K.metal)
	Lobby.namePlate(v, 'SafePlate', CFrame.new(V(0, 3.3, -2.9) * k - V(0, 0, 0.18)), 5, 1.1, 'VIP', 'SAFE')
	Lobby.prompt(safe, 'Open', 'VIP Safe')
end

-- People in the hall are SkinArt figures (Art.posed: block R15 parts, each look carrying its own prop in its
-- left hand). Poses in SkinArt.Poses' shape: {out, forward, elbow bend, twist} per limb (forward = toward the
-- figure's front).
Lobby.Poses = {
	-- The kingpin: a gold pistol raised high (the near arm, tilted toward the walkway), the other hand on the hip.
	kingpin = { LeftArm = { 160, 25 }, RightArm = { 30, -10, 70, 80 }, LeftLeg = { 6, 0 }, RightLeg = { 6, 0 } },
	-- A kid holding an ice pop up in front of him.
	icePop = { LeftArm = { 6, 0 }, RightArm = { 12, 60, 70 }, LeftLeg = { 3, 0 }, RightLeg = { 3, 0 }, Head = 8 },
}
function Lobby.figure(parent, cf, skin, scale, pose)
	local ok, Art = pcall(function() return require(ReplicatedStorage.Shared.SkinArt) end)
	if not ok or type(Art) ~= 'table' or not Art.posed then return nil end
	local built, fig = pcall(Art.posed, parent, cf, skin, scale, pose)
	if not built or not fig then return nil end
	return fig
end
-- A body part by its R15 name, falling back to the old R6 name (nil when neither is there).
function Lobby.limb(fig, r15, r6)
	return fig:FindFirstChild(r15) or (r6 and fig:FindFirstChild(r6)) or nil
end
-- Remove the look's hand prop (cash stack, sceptre, keys...): every recipe piece on the left hand, plus the known
-- prop names when the recipe isn't readable.
function Lobby.stripProp(fig, skin)
	local names = { CashStack = true, CashBand = true, CashEdge = true }
	local ok, Art = pcall(function() return require(ReplicatedStorage.Shared.SkinArt) end)
	if ok and type(Art) == 'table' and Art.recipe then
		local okR, recipe = pcall(Art.recipe, skin)
		if okR and recipe and recipe.pieces then
			for _, pc in recipe.pieces do if pc.seg == 'LeftHand' then names[pc.name] = true end end
		end
	end
	for _, d in fig:GetDescendants() do
		if d:IsA('BasePart') and (names[d.Name] or d.Name:match('^Sceptre')) then d:Destroy() end
	end
end
-- Recolour a GunModels gun in one metal (gold for the roof landmark, bronze for the statue): SmoothPlastic body,
-- a deeper grip (and frame, when frame is given).
function Lobby.goldGun(gun, body, frame, deep)
	deep = deep or C(222, 150, 28)
	for _, d in gun:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency < 1 then
			if d.Name == 'Gem' then
				d.Material = M.SmoothPlastic
			elseif d.Name:match('^Grip') or d.Name == 'Hammer' or d.Name == 'Trigger' then
				d.Material, d.Color = M.SmoothPlastic, deep
			elseif frame and (d.Name == 'Frame' or d.Name:match('^Guard') or d.Name:match('^Barrel')) then
				d.Material, d.Color = M.SmoothPlastic, frame
			elseif d.Name ~= 'Bore' then
				d.Material, d.Color = M.SmoothPlastic, body
			end
		end
	end
	return gun
end
-- A GunModels pistol in a figure's hand, the muzzle out along the arm; nil without GunModels.
-- roll: turn the gun about its barrel (the statue's raised pistol shows its side to the front).
function Lobby.handGun(fig, side, scale, id, roll)
	local hand = Lobby.limb(fig, side .. 'Hand', side .. 'Arm')
	if not hand then return nil end
	local grip = hand.Name:find('Hand') and hand.CFrame or hand.CFrame * CFrame.new(0, -1.05 * scale, 0)
	local at = grip * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, 0, roll or 0)
	local okGun, Guns = pcall(function() return require(ReplicatedStorage.Shared.Models.GunModels) end)
	if okGun and Guns and Guns.build then
		local okBuild, gun = pcall(Guns.build, id or 'Pistol', scale)
		if okBuild and gun then
			gun:PivotTo(at)
			gun.Parent = fig
			return gun
		end
	end
	return nil
end

-- The KINGPIN: a giant bronze figure (SkinArt's top look: crown, suit, chain) holding a bronze deagle high, on a
-- layered plinth (a concrete base and chamfer, a cream block, a bronze plaque) under a warm uplight. Two bronze
-- tones (the suit, and a paler shirt, tie and lapels) with a dark face so the eyes and shades read. Falls back to a
-- block figure without SkinArt.
function Lobby.statue(L, cf, skins)
	local K, T, F = Lobby.Colors, Lobby.T, Lobby.F
	local s, model = L:at(cf):group('KingpinStatue')
	local head, suit, pale, ink = C(166, 114, 72), C(144, 96, 60), C(216, 170, 112), C(48, 34, 26)
	s:box('Plinth', V(-7, 0, -7), V(7, 1.2, 7), K.stone, M.SmoothPlastic)
	s:box('PlinthChamfer', V(-6.6, 1.2, -6.6), V(6.6, 1.5, 6.6), K.concrete, M.SmoothPlastic)
	s:box('PlinthTop', V(-6, 1.5, -6), V(6, 3.4, 6), K.wall, M.SmoothPlastic)
	s:box('PlinthCap', V(-6.2, 3.4, -6.2), V(6.2, 3.6, 6.2), K.concrete, M.SmoothPlastic)
	local plaque = s:box('Plaque', V(-3.6, 1.9, -6.12), V(3.6, 3.05, -6.0), C(150, 104, 64), M.SmoothPlastic)
	line(surface(plaque, Enum.NormalId.Front, 30), 'Text', 'THE KINGPIN', T.ink, F.display, 0.12, 0.76)
	local top, scale = 3.6, 4.5
	local base = V2.Origin * s.cf * CFrame.new(0, top, 0)
	local kingpin = skins.ById.Kingpin or skins.List[#skins.List]
	local fig = Lobby.figure(model, base, kingpin, scale, Lobby.Poses.kingpin)
	if fig then
		fig.Name = 'KingpinFigure'
		Lobby.stripProp(fig, kingpin)
		local paleParts = { DressShirt = true, TailoredLapel = true, Tie = true, TieKnot = true, ShirtCuff = true, ShadesGlint = true, EyeGlint = true }
		local face = { EyeWhite = true, Iris = true, Pupil = true, Eyebrow = true, Eyelid = true, Nose = true, Smile = true, SmileTeeth = true,
			Mouth = true, Moustache = true, Beard = true, SunglassesFrame = true, SunglassesLens = true, LensReflection = true, GlassesBridge = true, RoundSpectacleRim = true,
			Eye = true, Brow = true, MouthCorner = true, Teeth = true, ShadesLens = true, ShadesBar = true }
		for _, d in fig:GetDescendants() do
			if d:IsA('BasePart') then
				d.Material = M.SmoothPlastic
				d.Color = face[d.Name] and ink or paleParts[d.Name] and pale or d.Name:match('^Head') and head or suit
				d.CastShadow = true
			elseif d:IsA('Decal') then
				d.Color3 = ink
			end
		end
		local gun = Lobby.handGun(fig, 'Left', scale * 1.35, 'Deagle', math.pi / 2)
		if gun then
			gun.Name = 'BronzeDeagle'
			Lobby.goldGun(gun, C(196, 146, 96), C(120, 80, 48), C(132, 88, 52))
		end
	else
		local function b(name, x0, y0, z0, x1, y1, z1, color) return s:box(name, V(x0, top + y0, z0), V(x1, top + y1, z1), color or head, M.SmoothPlastic) end
		for _, sx in { -1, 1 } do
			local function bx(name, a, y0, z0, c2, y1, z1, color) return b(name, math.min(sx * a, sx * c2), y0, z0, math.max(sx * a, sx * c2), y1, z1, color) end
			bx('Leg', 0.3, 0, -1.2, 3.5, 8, 1.4, suit)
			bx('Arm', 4.4, 10, -1.1, 6.4, 16, 1.1, suit)
		end
		b('Chest', -4.4, 8, -2, 4.4, 16, 2, suit)
		b('Head', -2, 16.4, -2, 2, 20.4, 2)
		b('Crown', -2.2, 20.4, -2.2, 2.2, 22, 2.2, pale)
	end
	-- a warm uplight from the plinth's front
	local lamp = s:box('StatueLamp', V(-0.8, 3.6, -5.9), V(0.8, 4.0, -5.1), K.metal, M.SmoothPlastic)
	light(lamp, C(255, 214, 150), 1.2, 24)
	return s
end

-- Leaderboard (16 x 21), one design for all three: charcoal steel posts on concrete feet, an ink header board with
-- "TOP" in cream and its word in gold, an ink screen in a charcoal surround with cream text, a charcoal cap over a
-- gold line. `live` names the model LobbyService writes into (a TextLabel named TextLabel): ServerLeaderboard (top
-- Power, with a small gold crown on its cap) or CashLeaderboard. Without it the board shows a season teaser.
function Lobby.leaderboard(L, cf, word, live)
	local K, T, F = Lobby.Colors, Lobby.T, Lobby.F
	local b, model = L:at(cf):group(live or 'Leaderboard')
	for _, sx in { -1, 1 } do
		b:box('BoardPost', V(sx * 7.6 - 0.4, 0, -0.4), V(sx * 7.6 + 0.4, 20, 0.4), K.metal, M.SmoothPlastic)
		b:box('BoardFoot', V(sx * 7.6 - 0.9, 0, -1.1), V(sx * 7.6 + 0.9, 0.7, 1.1), K.stone, M.SmoothPlastic)
	end
	b:box('BoardFrame', V(-7.2, 2.2, -0.3), V(7.2, 15.6, 0.3), K.metal, M.SmoothPlastic)
	b:box('BoardCap', V(-8.4, 20, -0.8), V(8.4, 20.6, 0.8), K.metal, M.SmoothPlastic)
	b:box('BoardTrim', V(-8.5, 19.8, -0.85), V(8.5, 20, 0.85), K.gold, M.SmoothPlastic)
	Lobby.sign(b, 'BoardHeader', CFrame.new(0, 17.7, -0.15), 13, 2.6, {
		{ 'Top', 'TOP', T.cream, F.display, 0.14, 0.72, 0.04, 0.3 },
		{ 'Word', word, T.gold, F.display, 0.14, 0.72, 0.34, 0.62 },
	}, { frame = 'steel', ppS = 30 })
	local screen = b:box('BoardScreen', V(-6.6, 2.8, -0.42), V(6.6, 15.0, -0.3), K.ink, M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	if live then
		local t = line(g, 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', T.cream, F.plain, 0.05, 0.9, T.stroke, 1)
		t.TextYAlignment = Enum.TextYAlignment.Top
	else
		line(g, 'Rows', 'SEASON 1', T.gold, F.display, 0.3, 0.2, T.stroke, 2)
		line(g, 'Soon', 'TOP 5 COMING SOON', T.cream, F.plain, 0.56, 0.1, T.stroke, 1)
	end
	if live == 'ServerLeaderboard' then
		local cr, crown = b:group('Crown')
		cr:box('CrownBand', V(-1.6, 20.6, -1.2), V(1.6, 21.5, 1.2), K.gold, M.SmoothPlastic)
		for _, x in { -1.2, 0, 1.2 } do
			cr:part('CrownPoint', V(0.7, 1.2, 0.7), CFrame.new(x, 22, 0) * CFrame.Angles(0, math.pi / 4, 0), K.gold, M.SmoothPlastic)
		end
		Lobby.motion(crown, cf * CFrame.new(0, 21, 0), nil, 0.3, 3)
	end
	return model
end

---------------------------------------------------------------------------------------------- hood life
-- The hood lives in the hall as materials and a few calm props, each once: the street-ball court in the south-west
-- under the hall's ONE mural wall (teal, gold, cream and ink), the docks' dumpster pen, sneakers on a wire, the
-- corner store (cream-and-green awning, a CORNER STORE lightbox, the one neon OPEN), a hand-painted ghost sign on the
-- brick in the south-east, and an oxblood lowrider turning under one spotlight. Warm-white string lights.
-- Kid-friendly: no gang signs, nothing aimed at anyone, only snacks and soda.
-- A painted mural: shapes and words on a panel in front of a wall. pieces = { {kind, ...}, ... } in 0-1 space:
--   { 'fill', x, y, w, h, color [, alpha] }    a painted rectangle
--   { 'word', text, x, y, w, h, color, stroke [, alpha] }  lettering (the hall's display font)
function Lobby.mural(c, name, cf, w, h, pieces, ppS)
	local panel = ghost(c:part(name, V(w, h, 0.1), cf, P.white))
	panel.CastShadow = false
	local g = surface(panel, Enum.NormalId.Front, ppS or 16)
	g.Name = 'Mural'
	g.LightInfluence = 0.8
	for _, p in pieces do
		if p[1] == 'fill' then
			local f = Instance.new('Frame')
			f.Name = 'Paint'
			f.BorderSizePixel = 0
			f.Position, f.Size = UDim2.fromScale(p[2], p[3]), UDim2.fromScale(p[4], p[5])
			f.BackgroundColor3, f.BackgroundTransparency = p[6], p[7] or 0
			f.Parent = g
		else
			local t = line(g, 'Word', p[2], p[7], Lobby.F.display, p[4], p[6], p[8], p[8] and 4 or nil)
			t.Position, t.Size = UDim2.fromScale(p[3], p[4]), UDim2.fromScale(p[5], p[6])
			if p[9] then t.TextTransparency = p[9] end
		end
	end
	return panel
end
-- Basketball (r 0.9 at scale 1) with its seams.
function Lobby.ball(c, pos, s)
	s = s or 1
	c:part('Basketball', V(1.8, 1.8, 1.8) * s, CFrame.new(pos), C(214, 112, 52), M.SmoothPlastic, Enum.PartType.Ball)
	for _, r in { CFrame.Angles(0, 0, 0), CFrame.Angles(0, 0, math.pi / 2) } do
		decor(c:part('BallSeam', V(0.06, 1.84, 1.84) * s, CFrame.new(pos) * r * CFrame.Angles(0, math.rad(30), 0), C(40, 24, 18), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end
-- The street-ball court (south-west, between the KINGPIN statue and the shoe dais): a grey half court with cream
-- lines and a teal key, a hoop on the south wall, balls, a boombox on a milk crate, three kids, warm bulbs over it,
-- and the hall's one mural behind it.
function Lobby.courtCorner(c, skins)
	local K, S = Lobby.Colors, Lobby.S
	local g = c:group('StreetCourt')
	local x0, x1, z0, z1 = -46.6, -29.6, 132.6, S - 0.4
	local xc = -40.5
	decor(g:box('CourtPaint', V(x0, 0, z0), V(x1, 0.05, z1), C(152, 148, 142), M.SmoothPlastic)).CastShadow = false
	local function lineBox(a, b) decor(g:box('CourtLine', a, b, K.cream, M.SmoothPlastic)).CastShadow = false end
	lineBox(V(x0, 0.05, z0), V(x1, 0.07, z0 + 0.4))
	lineBox(V(x0, 0.05, z0), V(x0 + 0.4, 0.07, z1))
	lineBox(V(x1 - 0.4, 0.05, z0), V(x1, 0.07, z1))
	local kz = S - 9.4 -- the free-throw line
	decor(g:box('CourtKey', V(xc - 3.6, 0.05, kz), V(xc + 3.6, 0.06, z1), K.teal, M.SmoothPlastic)).CastShadow = false
	lineBox(V(xc - 3.6, 0.06, kz - 0.4), V(xc + 3.6, 0.08, kz))
	lineBox(V(xc - 3.8, 0.06, kz), V(xc - 3.4, 0.08, z1))
	lineBox(V(xc + 3.4, 0.06, kz), V(xc + 3.8, 0.08, z1))
	for k = 0, 4 do
		local a0, a1 = math.pi + k * math.pi / 5, math.pi + (k + 1) * math.pi / 5
		local p0 = V(xc + 3.4 * math.cos(a0), 0.07, kz + 3.4 * math.sin(a0))
		local p1 = V(xc + 3.4 * math.cos(a1), 0.07, kz + 3.4 * math.sin(a1))
		decor(g:part('CourtLine', V(0.4, 0.02, (p1 - p0).Magnitude + 0.2), CFrame.lookAt((p0 + p1) / 2, p1), K.cream, M.SmoothPlastic)).CastShadow = false
	end
	-- the hoop: charcoal arms, a cream backboard with an ink square, an orange rim, a white net
	local bz = S - 3.4
	for _, x in { xc - 2, xc + 2 } do g:bar('HoopArm', V(x, 10.6, S - 0.3), V(x, 10.6, bz), 0.35, K.metal, M.SmoothPlastic) end
	local board = g:box('Backboard', V(xc - 3, 8.6, bz - 0.25), V(xc + 3, 12.6, bz), K.wall, M.SmoothPlastic)
	local bg = surface(board, Enum.NormalId.Front, 16)
	for _, e in { { 0, 0, 1, 0.05 }, { 0, 0.95, 1, 0.05 }, { 0, 0, 0.03, 1 }, { 0.97, 0, 0.03, 1 },
		{ 0.35, 0.5, 0.3, 0.05 }, { 0.35, 0.9, 0.3, 0.05 }, { 0.35, 0.5, 0.03, 0.45 }, { 0.62, 0.5, 0.03, 0.45 } } do
		local f = Instance.new('Frame')
		f.BorderSizePixel, f.BackgroundColor3 = 0, K.ink
		f.Position, f.Size = UDim2.fromScale(e[1], e[2]), UDim2.fromScale(e[3], e[4])
		f.Parent = bg
	end
	local rr, ry = 1.15, 9.4
	local rc = V(xc, ry, bz - 1.5)
	g:box('RimBracket', V(xc - 0.3, ry - 0.2, bz - 0.5), V(xc + 0.3, ry + 0.1, bz - 0.25), K.metal, M.SmoothPlastic)
	for k = 0, 7 do
		local a0, a1 = k * math.pi / 4, (k + 1) * math.pi / 4
		g:bar('Rim', rc + V(rr * math.cos(a0), 0, rr * math.sin(a0)), rc + V(rr * math.cos(a1), 0, rr * math.sin(a1)), 0.16, C(206, 104, 52), M.SmoothPlastic)
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		local top = rc + V(rr * math.cos(a), -0.08, rr * math.sin(a))
		local bot = rc + V(0.7 * math.cos(a + 0.4), -1.7, 0.7 * math.sin(a + 0.4))
		decor(g:bar('Net', top, bot, 0.07, P.white, M.SmoothPlastic)).CastShadow = false
	end
	Lobby.ball(g, V(-36.4, 0.05 + 0.9, 151.4))
	Lobby.ball(g, V(xc + 0.3, 7.9, 140.9))
	-- the boombox on a milk crate at the court's north-west corner, its speakers bouncing
	local bf = CFrame.lookAt(V(-44.8, 0, 134.6), V(-20, 0, 120))
	local bb = g:at(bf)
	Lobby.milkCrate(bb, CFrame.new(0, 0, 0), K.teal)
	local box, boom = bb:group('Boombox')
	box:box('BoomboxBody', V(-1.5, 1.7, -0.5), V(1.5, 3.3, 0.5), K.ink, M.SmoothPlastic)
	box:box('BoomboxHandle', V(-1.1, 3.3, -0.1), V(1.1, 3.6, 0.1), K.metalLight, M.SmoothPlastic)
	for _, x in { -0.85, 0.85 } do
		box:part('BoomboxSpeaker', V(0.1, 1.1, 1.1), CFrame.new(x, 2.5, -0.55) * CFrame.Angles(0, math.pi / 2, 0), K.metalLight, M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(box:part('BoomboxCone', V(0.12, 0.5, 0.5), CFrame.new(x, 2.5, -0.58) * CFrame.Angles(0, math.pi / 2, 0), K.cream, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
	decor(box:box('BoomboxDial', V(-0.3, 2.95, -0.56), V(0.3, 3.15, -0.5), K.gold, M.SmoothPlastic)).CastShadow = false
	Lobby.motion(boom, bf * CFrame.new(0, 2.5, 0), nil, 0.08, 0.5)
	Lobby.kid(c, skins, 'Baller', 'CornerKid', nil, V(xc, 0.05, 141.4), V(xc, 0.05, S), 'cheer')
	Lobby.kid(c, skins, 'Dancer', 'Lookout', nil, V(-41.6, 0.05, 135.6), V(-10, 0.05, 110), 'swagger', 0.18, 0.9)
	Lobby.kid(c, skins, 'Rebounder', 'Hustler', nil, V(-35.2, 0.05, 146.8), V(xc, 0.05, S - 4), 'point', 0.14, 1.2)
	Lobby.stringLights(g, V(-47, 21.5, S - 2), V(-34, 21.5, S - 2), 2.2, 6)
	-- the one mural wall behind the court, between the south pillars under the window: a gold panel framing the
	-- backboard, THE BLOCK in cream on teal, an ink band with BALL IS LIFE
	local K2 = Lobby.Colors
	Lobby.mural(g, 'MuralWall', CFrame.lookAt(V(xc, 6.7, S - 0.6), V(xc, 6.7, 0)), 11, 11.8, {
		{ 'fill', 0, 0, 1, 1, K2.teal },
		{ 'fill', 0.14, 0.03, 0.72, 0.36, K2.gold },
		{ 'fill', 0.18, 0.06, 0.64, 0.3, K2.cream },
		{ 'word', 'THE BLOCK', 0.04, 0.42, 0.92, 0.28, K2.cream, K2.ink },
		{ 'fill', 0, 0.74, 1, 0.03, K2.gold },
		{ 'fill', 0, 0.77, 1, 0.23, K2.ink },
		{ 'word', 'BALL IS LIFE', 0.08, 0.81, 0.84, 0.14, K2.cream },
	}, 12)
end
-- A plastic milk crate (2 x 1.6 x 2) with its grid painted on.
function Lobby.milkCrate(c, cf, color)
	local p = c:part('MilkCrate', V(2, 1.6, 2), cf * CFrame.new(0, 0.8, 0), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		Lobby.stripes(p, face, 2, 1.6, 0.4, 0.16, true, 0.6)
	end
	return p
end
-- A traffic cone (muted orange with a cream band on a charcoal foot).
function Lobby.cone(c, pos)
	local K = Lobby.Colors
	local k = c:group('Cone')
	k:box('ConeBase', pos + V(-0.8, 0, -0.8), pos + V(0.8, 0.2, 0.8), K.ink, M.SmoothPlastic)
	k:post('Cone', 0.55, 1.0, pos + V(0, 0.2, 0), C(206, 116, 66), M.SmoothPlastic)
	decor(k:post('ConeBand', 0.42, 0.45, pos + V(0, 1.2, 0), K.cream, M.SmoothPlastic))
	k:post('Cone', 0.28, 0.6, pos + V(0, 1.65, 0), C(206, 116, 66), M.SmoothPlastic)
	return k
end
-- A fire hydrant (silver with a charcoal cap).
function Lobby.hydrant(c, pos)
	local K = Lobby.Colors
	local silver = C(184, 186, 184)
	local k = c:group('Hydrant')
	k:post('HydrantBase', 0.75, 0.4, pos, K.metal, M.SmoothPlastic)
	k:post('Hydrant', 0.55, 2.2, pos + V(0, 0.4, 0), silver, M.SmoothPlastic)
	k:post('HydrantRing', 0.65, 0.2, pos + V(0, 2.0, 0), K.metal, M.SmoothPlastic)
	k:part('HydrantCap', V(1.1, 0.8, 1.1), CFrame.new(pos + V(0, 2.6, 0)), K.metal, M.SmoothPlastic, Enum.PartType.Ball)
	k:rod('HydrantNozzle', 0.25, 1.7, CFrame.new(pos + V(0, 1.6, 0)), silver, M.SmoothPlastic)
	return k
end
-- A chain-link fence panel from a to b (on the floor), ht tall: steel posts, a top rail, see-through mesh.
function Lobby.chainLink(c, a, b, ht)
	local K = Lobby.Colors
	local f = c:group('ChainLink')
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local n = math.max(1, math.ceil(len / 4.5))
	for k = 0, n do f:post('FencePost', 0.15, ht, a + (b - a) * (k / n), K.metalLight, M.SmoothPlastic) end
	f:part('FenceRail', V(0.2, 0.2, len), cf * CFrame.new(0, ht - 0.1, 0), K.metalLight, M.SmoothPlastic)
	local mesh = f:part('FenceMesh', V(0.05, ht - 0.4, len), cf * CFrame.new(0, (ht - 0.4) / 2 + 0.1, 0), C(190, 192, 192), M.SmoothPlastic)
	mesh.Transparency = 0.75
	mesh.CastShadow = false
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local g = Lobby.stripes(mesh, face, len, ht - 0.4, 0.5, 0.06, true, 0.2, C(150, 152, 154))
		for k = 0, math.floor((ht - 0.4) / 0.5) - 1 do
			local s = Instance.new('Frame')
			s.BorderSizePixel, s.BackgroundColor3, s.BackgroundTransparency = 0, C(150, 152, 154), 0.2
			s.Position, s.Size = UDim2.fromScale(0, (k + 0.5) / ((ht - 0.4) / 0.5)), UDim2.fromScale(1, 0.06 / (ht - 0.4))
			s.Parent = g
		end
	end
	return f
end
-- A dumpster (7 long on local Z, 4.4 deep, 5 tall): a deep green body, charcoal lids (one propped open), sleeves,
-- casters.
function Lobby.dumpster(c, cf)
	local K = Lobby.Colors
	local d = c:at(cf):group('Dumpster')
	local green = C(62, 98, 84)
	d:box('DumpsterBody', V(-2.2, 0.5, -3.5), V(2.2, 5, 3.5), green, M.SmoothPlastic)
	d:box('DumpsterRim', V(-2.35, 4.7, -3.6), V(2.35, 5.1, 3.6), green:Lerp(P.black, 0.25), M.SmoothPlastic)
	d:box('DumpsterLid', V(-2.3, 5.1, 0), V(2.3, 5.3, 3.5), K.ink, M.SmoothPlastic)
	d:part('DumpsterLid', V(4.6, 0.2, 3.5), CFrame.new(0.4, 6.0, -1.9) * CFrame.Angles(math.rad(-28), 0, 0), K.ink, M.SmoothPlastic)
	for _, z in { -3.6, 3.6 } do d:box('DumpsterSleeve', V(-1.6, 2.6, z - 0.25), V(1.6, 3.2, z + 0.25), green:Lerp(P.black, 0.35), M.SmoothPlastic) end
	for _, x in { -1.6, 1.6 } do for _, z in { -2.8, 2.8 } do d:box('DumpsterWheel', V(x - 0.3, 0, z - 0.3), V(x + 0.3, 0.5, z + 0.3), K.ink, M.SmoothPlastic) end end
	return d
end
-- The docks on the north wall: in the NW a dumpster behind a chain-link fence with milk crates, a cone and a
-- hydrant; in the NE a cone, a hydrant and a crate stack.
function Lobby.docks(c)
	local K, W = Lobby.Colors, Lobby.W
	local g = c:group('Docks')
	Lobby.dumpster(g, CFrame.new(-W + 2.6, 0, 14.6))
	Lobby.chainLink(g, V(-57.6, 0, 11.8), V(-57.6, 0, 20.2), 6.5)
	Lobby.milkCrate(g, CFrame.new(-59.9, 0, 13.4) * CFrame.Angles(0, 0.2, 0), K.brick)
	Lobby.milkCrate(g, CFrame.new(-59.9, 1.6, 13.4) * CFrame.Angles(0, -0.15, 0), K.teal)
	Lobby.milkCrate(g, CFrame.new(-59.9, 0, 15.8) * CFrame.Angles(0, 0.4, 0), K.cream)
	Lobby.cone(g, V(-52.5, 0, 15.2))
	Lobby.hydrant(g, V(-56, 0, 22.4))
	Lobby.cone(g, V(54.5, 0, 15.8))
	Lobby.hydrant(g, V(W - 2.2, 0, 17.2))
	Lobby.milkCrate(g, CFrame.new(W - 2.4, 0, 12.6) * CFrame.Angles(0, 0.1, 0), K.teal)
	Lobby.milkCrate(g, CFrame.new(W - 2.4, 1.6, 12.6) * CFrame.Angles(0, -0.2, 0), K.cream)
	return g
end
-- Sneakers on a wire: a sagging wire north-south over the east aisle (x 36), hung from the roof by two hanger
-- cables, three pairs of big cartoon high-tops (x1.5) dangling toe-down by their laces.
function Lobby.sneakerWire(c)
	local K, H = Lobby.Colors, Lobby.H
	local g = c:group('SneakerWire')
	local a, b, sag = V(36, 22.5, 20), V(36, 22.5, 62), 2.2
	local function at(t) return a + (b - a) * t - V(0, sag * 4 * t * (1 - t), 0) end
	local n = 8
	for k = 0, n - 1 do decor(g:bar('Wire', at(k / n), at((k + 1) / n), 0.12, C(30, 30, 36), M.SmoothPlastic)).CastShadow = false end
	for _, e in { a, b } do decor(g:bar('WireHanger', e, V(e.X, H - 0.1, e.Z), 0.1, C(30, 30, 36), M.SmoothPlastic)).CastShadow = false end
	local k = 1.5
	local pairs = { { 0.3, K.cream, K.teal }, { 0.5, K.ink, K.gold }, { 0.7, K.brick, K.cream } }
	for _, pr in pairs do
		local top = at(pr[1])
		for side = -1, 1, 2 do
			local hang = top + V(side * 0.75, -2.4, 0)
			decor(g:bar('Laces', top, top + (hang + V(0, 1.2 * k, 0) - top).Unit * 1.6, 0.07, P.white, M.SmoothPlastic)).CastShadow = false
			local s = g:at(CFrame.new(hang) * CFrame.Angles(0, math.rad(90 + 15 * side), 0) * CFrame.Angles(math.rad(-75), 0, 0))
			local function S(name, lo, hi, color) decor(s:box(name, lo * k, hi * k, color, M.SmoothPlastic)).CastShadow = false end
			S('SneakerSole', V(-0.55, -0.15, -1.4), V(0.55, 0.15, 1.4), P.white)
			S('SneakerUpper', V(-0.5, 0.15, -1.1), V(0.5, 0.95, 1.3), pr[2])
			S('SneakerToe', V(-0.5, 0.15, -1.4), V(0.5, 0.6, -1.1), P.white)
			S('SneakerStripe', V(-0.53, 0.35, -0.6), V(0.53, 0.6, 0.9), pr[3])
			S('SneakerCollar', V(-0.4, 0.95, 0.5), V(0.4, 1.25, 1.3), pr[3])
		end
	end
	return g
end
-- The corner store at the end of the cross walkway's east arm, on the east wall: a brick shopfront with a cream
-- cornice, a big warm-lit window (SNACKS • SODA • ICE POPS in ink) with the one neon OPEN in teal, a wood door, a
-- cream-and-green striped awning, a CORNER STORE lightbox over it, warm bulbs along the wall, the sidewalk display
-- (an ice-pop freezer, a soda cooler, milk crates, a kid with an ice pop) and the BLOCK AVE / HOOD ST sign.
function Lobby.cornerStore(c, skins)
	local K, T, F, W = Lobby.Colors, Lobby.T, Lobby.F, Lobby.W
	local g = c:group('CornerStore')
	local z0, z1 = 68.4, 75.6
	local x = W - 1.0 -- the shopfront's face (in front of the wall's trims)
	g:box('StoreFront', V(x, 0, z0), V(W - 0.6, 13.3, z1), K.brick, M.Brick)
	g:box('StoreFrontCap', V(x - 0.3, 12.9, z0 - 0.2), V(W - 0.6, 13.5, z1 + 0.2), K.wall, M.SmoothPlastic)
	g:box('StoreFrontBase', V(x - 0.15, 0, z0), V(x, 0.8, z1), K.metal, M.SmoothPlastic)
	g:box('StoreWindowFrame', V(x - 0.25, 2.0, z0 + 0.3), V(x, 11.4, z1 - 2.2), K.metal, M.SmoothPlastic)
	local win = g:box('StoreWindow', V(x - 0.35, 2.3, z0 + 0.6), V(x - 0.25, 11.1, z1 - 2.5), C(250, 234, 200), M.SmoothPlastic)
	local wg = surface(win, Enum.NormalId.Left, 24)
	line(wg, 'Snacks', 'SNACKS', T.ink, F.display, 0.06, 0.16)
	line(wg, 'Soda', 'SODA', T.ink, F.display, 0.25, 0.16)
	line(wg, 'IcePops', 'ICE POPS', T.ink, F.display, 0.44, 0.16)
	light(win, C(255, 220, 170), 0.8, 14)
	-- the one neon OPEN, in the window
	local openCf = CFrame.lookAt(V(x - 0.45, 3.9, (z0 + z1 - 1.9) / 2), V(0, 3.9, (z0 + z1 - 1.9) / 2))
	g:part('OpenBoard', V(3.4, 1.4, 0.1), openCf * CFrame.new(0, 0, 0.05), K.ink, M.SmoothPlastic)
	local open = decor(g:part('OpenNeon', V(3.0, 1.0, 0.08), openCf * CFrame.new(0, 0, -0.06), K.teal:Lerp(P.white, 0.25), M.Neon))
	open.Transparency = 1
	local og = surface(open, Enum.NormalId.Front, 40)
	og.LightInfluence = 0
	line(og, 'Open', 'OPEN', C(150, 240, 214), F.display, 0.04, 0.92, C(40, 110, 96), 3)
	decor(g:part('OpenTube', V(3.2, 0.12, 0.1), openCf * CFrame.new(0, -0.62, -0.08), C(150, 240, 214), M.Neon)).CastShadow = false
	decor(g:part('OpenTube', V(3.2, 0.12, 0.1), openCf * CFrame.new(0, 0.62, -0.08), C(150, 240, 214), M.Neon)).CastShadow = false
	g:box('StoreDoor', V(x - 0.3, 0, z1 - 2.0), V(x, 9.2, z1 - 0.3), K.wood, M.Wood)
	decor(g:box('StoreDoorGlass', V(x - 0.35, 4.6, z1 - 1.7), V(x - 0.3, 8.6, z1 - 0.6), K.glass, M.SmoothPlastic)).CastShadow = false
	g:box('StoreDoorHandle', V(x - 0.5, 4.2, z1 - 1.9), V(x - 0.3, 4.6, z1 - 1.75), K.gold, M.SmoothPlastic)
	local awning = g:part('StoreAwning', V(3.0, 0.2, z1 - z0 + 0.6), CFrame.new(x - 1.35, 12.0, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.rad(22)), K.cream, M.Fabric)
	Lobby.stripes(awning, Enum.NormalId.Top, 3.0, z1 - z0 + 0.6, 1.2, 0.6, false, 0, K.teal)
	local valance = g:part('StoreValance', V(0.12, 0.6, z1 - z0 + 0.6), CFrame.new(x - 2.75, 11.15, (z0 + z1) / 2), K.teal, M.Fabric)
	valance.CastShadow = false
	-- the CORNER STORE lightbox: a cream face with ink words in a charcoal box, lit from inside
	local lcf = CFrame.lookAt(V(x - 0.9, 16.2, (z0 + z1) / 2), V(0, 16.2, (z0 + z1) / 2))
	g:part('LightboxCase', V(z1 - z0 + 0.6, 3.4, 1.0), lcf * CFrame.new(0, 0, 0.35), K.metal, M.SmoothPlastic)
	local face = g:part('Lightbox', V(z1 - z0, 2.8, 0.2), lcf * CFrame.new(0, 0, -0.2), C(252, 244, 226), M.SmoothPlastic)
	local lg = surface(face, Enum.NormalId.Front, 24)
	line(lg, 'Corner', 'CORNER', C(176, 120, 40), F.display, 0.08, 0.42)
	line(lg, 'Store', 'STORE', T.ink, F.display, 0.5, 0.42)
	light(face, C(255, 226, 180), 0.7, 10)
	for _, dz in { -2.6, 2.6 } do g:bar('LightboxArm', (lcf * CFrame.new(dz, 1.0, 0.85)).Position, V(W, 17.2, (z0 + z1) / 2 - dz), 0.2, K.metal, M.SmoothPlastic) end
	Lobby.stringLights(g, V(W - 2, 21.5, 66.6), V(W - 2, 21.5, 77.4), 1.8, 4)
	-- the sidewalk display (x 59..63.6, z 70..75.6: the arm keeps z 58..70 clear)
	local fz = 71.9
	g:box('FreezerBody', V(60.6, 0.1, fz - 1.8), V(63.0, 2.6, fz + 1.8), C(244, 242, 236), M.SmoothPlastic)
	g:box('FreezerBand', V(60.55, 0.4, fz - 1.85), V(63.05, 0.8, fz + 1.85), K.teal, M.SmoothPlastic)
	local lid = g:box('FreezerLid', V(60.7, 2.6, fz - 1.7), V(62.9, 2.85, fz + 1.7), C(200, 222, 226), M.Glass)
	lid.Transparency = 0.3
	for j, col in { C(236, 120, 150), C(240, 200, 90), C(150, 200, 120), C(180, 150, 220) } do
		decor(g:box('IcePop', V(61.3 + (j % 2) * 0.8, 2.3, fz - 1.3 + j * 0.55), V(61.7 + (j % 2) * 0.8, 2.8, fz - 1.0 + j * 0.55), col, M.SmoothPlastic)).CastShadow = false
	end
	local cz = 74.0
	local cooler = g:box('SodaCooler', V(61.8, 0.1, cz - 1.0), V(63.8, 4.0, cz + 1.0), K.ink, M.SmoothPlastic)
	line(surface(cooler, Enum.NormalId.Left, 24), 'Text', 'SODA', T.cream, F.display, 0.04, 0.2, T.stroke, 2)
	decor(g:box('SodaCoolerGlass', V(61.75, 0.6, cz - 0.8), V(61.8, 3.0, cz + 0.8), C(206, 222, 226), M.SmoothPlastic)).CastShadow = false
	for j = 0, 2 do
		for i, col in { C(186, 70, 64), C(70, 130, 170), C(220, 170, 70) } do
			decor(g:box('SodaCan', V(61.85, 0.8 + j * 0.75, cz - 0.95 + i * 0.45), V(62.05, 1.3 + j * 0.75, cz - 0.65 + i * 0.45), col, M.SmoothPlastic)).CastShadow = false
		end
	end
	Lobby.milkCrate(g, CFrame.new(59.5, 0.1, 73.8) * CFrame.Angles(0, 0.25, 0), K.teal)
	Lobby.milkCrate(g, CFrame.new(59.5, 1.7, 73.8) * CFrame.Angles(0, -0.1, 0), K.cream)
	local kid = Lobby.kid(c, skins, 'IcePopKid', 'Pickpocket', nil, V(58.8, 0.1, 71.2), V(0, 0.1, 66), Lobby.Poses.icePop, 0.1, 1.4)
	local hand = kid and Lobby.limb(kid, 'RightHand', 'Right Arm')
	if hand then
		local at = hand.CFrame.Position + V(0, 0.75, 0)
		local stick = Lobby.worldPart(kid, 'IcePopStick', V(0.14, 0.6, 0.14), CFrame.new(at - V(0, 0.45, 0)), C(230, 200, 150))
		local pop = Lobby.worldPart(kid, 'IcePop', V(0.5, 0.9, 0.3), CFrame.new(at + V(0, 0.25, 0)), C(236, 120, 150))
		for _, q in { stick, pop } do q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = false, false, false, false end
	end
	-- the street sign on the store's corner, a hydrant at its foot
	local pole = V(61.8, 0.1, 66.6)
	g:post('SignPole', 0.2, 20.4, pole, K.metal, M.SmoothPlastic)
	local function blade(name, text, cf)
		local bl = Lobby.board(g, name, cf, 6.4, 1.3, K.teal, { { 'Text', text, T.cream, F.display, 0.12, 0.76 } }, 24)
		line(surface(bl, Enum.NormalId.Back, 24), 'Text', text, T.cream, F.display, 0.12, 0.76)
	end
	blade('StreetSign', 'BLOCK AVE', CFrame.new(pole + V(0, 19.6, -3.3)) * CFrame.Angles(0, math.pi / 2, 0))
	blade('StreetSign', 'HOOD ST', CFrame.new(pole + V(-3.3, 18.2, 0)) * CFrame.Angles(0, math.pi, 0))
	Lobby.hydrant(g, V(60.2, 0.1, 65.4))
	return g
end
-- A string of warm-white bulbs from a to b sagging by sag, n bulbs; a soft PointLight on every other bulb.
function Lobby.stringLights(c, a, b, sag, n)
	local K = Lobby.Colors
	local g = c:group('StringLights')
	local function at(t) return a + (b - a) * t - V(0, sag * 4 * t * (1 - t), 0) end
	local m = 8
	for k = 0, m - 1 do decor(g:bar('LightWire', at(k / m), at((k + 1) / m), 0.08, C(30, 30, 36), M.SmoothPlastic)).CastShadow = false end
	for k = 1, n do
		local p = at(k / (n + 1)) - V(0, 0.45, 0)
		local bulb = decor(g:part('Bulb', V(0.55, 0.7, 0.55), CFrame.new(p), K.bulb, M.Neon, Enum.PartType.Ball))
		bulb.CastShadow = false
		if k % 2 == 1 then light(bulb, C(255, 214, 150), 0.4, 8) end
	end
	return g
end
-- A lowrider turning slowly on a showroom turntable in the north-east: oxblood, a cream roof, gold wire wheels with
-- white walls, chrome bumpers; it sits low and bounces on its hydraulics, under one warm spotlight.
function Lobby.lowrider(c, pos)
	local K = Lobby.Colors
	local g = c:group('Lowrider')
	Lobby.disc(g, 'TurntableBase', 16.8, 0.25, pos, K.stone)
	Lobby.disc(g, 'TurntableRing', 16.2, 0.1, pos + V(0, 0.25, 0), K.metal)
	Lobby.disc(g, 'TurntableTop', 15.6, 0.12, pos + V(0, 0.25, 0), K.concrete, M.DiamondPlate)
	local frame = CFrame.new(pos + V(0, 0.37, 0)) * CFrame.Angles(0, math.rad(-35), 0)
	local cc, car = g:at(frame):group('LowriderCar')
	local paint, roof, chrome = K.oxblood, K.cream, C(214, 216, 218)
	cc:box('CarBody', V(-7.4, 1.0, -2.7), V(7.4, 2.5, 2.7), paint, M.SmoothPlastic)
	cc:box('CarHood', V(-7.4, 2.5, -2.5), V(-3.0, 2.8, 2.5), paint, M.SmoothPlastic)
	cc:box('CarTrunk', V(3.4, 2.5, -2.5), V(7.4, 2.8, 2.5), paint, M.SmoothPlastic)
	cc:box('CarCabin', V(-3.0, 2.5, -2.4), V(3.4, 3.4, 2.4), paint, M.SmoothPlastic)
	cc:box('CarRoof', V(-1.8, 4.5, -2.3), V(3.0, 4.8, 2.3), roof, M.SmoothPlastic)
	cc:box('CarWindows', V(-1.7, 3.4, -2.35), V(2.9, 4.5, 2.35), C(52, 60, 72), M.SmoothPlastic)
	cc:wedge('CarWindshield', V(4.6, 1.1, 1.2), CFrame.new(-2.4, 3.95, 0) * CFrame.Angles(0, -math.pi / 2, 0), C(70, 84, 100), M.SmoothPlastic)
	for _, z in { -2.75, 2.75 } do
		decor(cc:box('CarPinstripe', V(-7.2, 2.2, z - 0.03), V(7.2, 2.35, z + 0.03), K.gold, M.SmoothPlastic)).CastShadow = false
	end
	for _, x in { -7.6, 7.6 } do cc:box('CarBumper', V(x - 0.3, 1.0, -2.8), V(x + 0.3, 1.7, 2.8), chrome, M.SmoothPlastic) end
	cc:box('CarGrille', V(-7.55, 1.75, -1.6), V(-7.4, 2.4, 1.6), chrome, M.SmoothPlastic)
	for _, z in { -2.0, 2.0 } do
		decor(cc:box('CarHeadlight', V(-7.5, 1.9, z - 0.45), V(-7.4, 2.35, z + 0.45), C(255, 244, 214), M.Neon)).CastShadow = false
		decor(cc:box('CarTaillight', V(7.4, 1.9, z - 0.45), V(7.5, 2.35, z + 0.45), C(150, 40, 40), M.SmoothPlastic)).CastShadow = false
	end
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2.55, 2.55 } do
			cc:part('CarTyre', V(0.8, 2.2, 2.2), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(cc:part('CarWhitewall', V(0.82, 1.6, 1.6), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), C(240, 236, 228), M.SmoothPlastic, Enum.PartType.Cylinder))
			decor(cc:part('CarRim', V(0.86, 1.1, 1.1), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), K.gold, M.SmoothPlastic, Enum.PartType.Cylinder))
		end
	end
	Lobby.motion(car, frame, 6, 0.3, 1.4)
	-- the spotlight over it, on a rod from the roof
	local H = Lobby.H
	local lp = pos + V(0, 22, 0)
	g:bar('CarLampRod', V(lp.X, H - 0.2, lp.Z), lp + V(0, 0.8, 0), 0.15, K.metal, M.SmoothPlastic).CastShadow = false
	Lobby.disc(g, 'CarLamp', 2.2, 0.9, lp - V(0, 0.1, 0), K.metal)
	local lens = decor(Lobby.disc(g, 'CarLampLens', 1.7, 0.06, lp - V(0, 0.16, 0), K.bulb, M.Neon))
	lens.CastShadow = false
	Lobby.spot(lens, Enum.NormalId.Bottom, 50, 28, 1.3)
	return g
end
-- One display kid (SkinArt, scale 1.1), its look's hand prop removed; optionally bobbing.
function Lobby.kid(c, skins, name, skinId, color, pos, look, pose, bob, period)
	local base = skins.ById[skinId] or skins.List[1]
	local ok, skin = pcall(table.clone, base)
	if not ok or not skin then return nil end
	skin.Id = name
	if color then skin.Color = color end
	local frame = CFrame.lookAt(pos, look)
	local fig = Lobby.figure(c.parent, V2.Origin * c.cf * frame, skin, 1.1, pose)
	if fig then
		Lobby.stripProp(fig, base)
		if bob then Lobby.motion(fig, frame, nil, bob, period or 2) end
	end
	return fig
end
-- The ghost sign: an old hand-painted advert, faded into the brick of the south-east wall.
function Lobby.ghostSign(c)
	local K, S = Lobby.Colors, Lobby.S
	local cream = C(232, 220, 196)
	Lobby.mural(c, 'GhostSign', CFrame.lookAt(V(55.95, 5.9, S - 0.3), V(55.95, 5.9, 0)), 12, 8.6, {
		{ 'fill', 0.02, 0.04, 0.96, 0.92, cream, 0.84 },
		{ 'word', 'HOOD SUPPLY CO.', 0.05, 0.1, 0.9, 0.34, cream, nil, 0.3 },
		{ 'fill', 0.08, 0.48, 0.84, 0.025, cream, 0.45 },
		{ 'word', 'TOOLS • PAINT • HARDWARE', 0.06, 0.55, 0.88, 0.16, cream, nil, 0.35 },
		{ 'word', 'EST. 1979', 0.3, 0.75, 0.4, 0.15, cream, nil, 0.35 },
	}, 14).Name = 'GhostSign'
end
function Lobby.hood(L, skins)
	local h = L:group('Hood')
	Lobby.courtCorner(h, skins)
	Lobby.docks(h)
	Lobby.sneakerWire(h)
	Lobby.cornerStore(h, skins)
	Lobby.ghostSign(h)
	-- the lowrider showroom in the NE, its owner waving at the spawn
	Lobby.lowrider(h, V(48, 0, 40))
	Lobby.kid(h, skins, 'RideOwner', 'GetawayDriver', nil, V(40.4, 0, 30.2), V(0, 0, 66), 'wave', 0.12, 1.8)
	-- small props cast no shadows (cones, crates, hydrants, sneakers, the boombox...): no visible change, fewer casters
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Size.X * p.Size.Y * p.Size.Z < 30 then p.CastShadow = false end
	end
	return h
end

---------------------------------------------------------------------------------------------- slots
function Lobby.slots(L)
	local D = Lobby.Deck
	-- The ARMORY on the east side, its front to the hall (west).
	local ax, az = Lobby.ArmoryX, Lobby.ArmoryZ
	Lobby.place(L, L.parent, 'Armory', CFrame.lookAt(V(ax, D, az), V(0, D, az)), { X = 58.8, Y = 21, Z0 = 0, Z1 = 31.2 }, 'ARMORY', C(200, 196, 186),
		Armory and function(c) Armory.build(c, {}) end)
end

---------------------------------------------------------------------------------------------- dressing
-- The street face: the BLOCK RANGE sign (an ink board, cream letters, a warm-white tube) and the landmark from the
-- street, a giant gold deagle turning slowly on a charcoal mast over the door under a warm light.
function Lobby.dressing(L)
	local K, T, F, N = Lobby.Colors, Lobby.T, Lobby.F, Lobby.N
	local dr = L:group('Dressing')
	Lobby.sign(dr, 'ClubSign', Lobby.onWall(V(0, 31, N - 1.6), V(0, 0, -1)), 28, 5.4, {
		{ 'Block', 'BLOCK', T.cream, F.display, 0.12, 0.76, 0.04, 0.5 },
		{ 'Range', 'RANGE', T.gold, F.display, 0.12, 0.76, 0.52, 0.44 },
	}, { frame = 'steel', tube = K.bulb })
	local ridge = Lobby.H + 0.3
	local mast = dr:group('RoofMast')
	mast:part('MastPlinth', V(1.2, 6, 6), CFrame.new(0, ridge + 0.6, N - 0.5) * CFrame.Angles(0, 0, math.pi / 2), K.metal, M.SmoothPlastic, Enum.PartType.Cylinder)
	mast:post('MastPole', 0.5, 7.2, V(0, ridge + 1.2, N - 0.5), K.metal, M.SmoothPlastic)
	local gp = V(0, ridge + 9.4, N - 0.5)
	local okGun, Guns = pcall(function() return require(ReplicatedStorage.Shared.Models.GunModels) end)
	local landmark
	if okGun and Guns and Guns.build and Guns.Meta and Guns.Meta.Deagle then
		local scale = 7.5
		local okBuild, gun = pcall(Guns.build, 'Deagle', scale)
		if okBuild and gun then
			gun.Name = 'RoofDeagle'
			Lobby.goldGun(gun, K.gold)
			-- Side on to the street (it turns in game; this is how it rests before the client spins it).
			gun:PivotTo(V2.Origin * CFrame.new(gp) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-Guns.Meta.Deagle.Center * scale))
			gun.Parent = dr.parent
			landmark = gun
		end
	end
	if not landmark then
		local bg, target = dr:group('RoofBullseye')
		for j, e in { { 11, K.gold }, { 8, K.cream }, { 5, K.ink }, { 2, K.gold } } do
			bg:part('RoofRing', V(0.8 + j * 0.1, e[1], e[1]), CFrame.new(gp) * CFrame.Angles(0, math.pi / 2, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
		end
		landmark = target
	end
	Lobby.motion(landmark, CFrame.new(gp), 20, 0.6, 3)
	local shine = Lobby.emitBox(mast, 'RoofGunFx', gp + V(-6, -4, -6), gp + V(6, 4, 6))
	light(shine, C(255, 214, 150), 1.6, 30)
	return dr
end

---------------------------------------------------------------------------------------------- guide nodes
-- Waypoints for the new-player guide (Lobby.client): a GuideNodes folder of small invisible parts whose bottoms
-- sit on the walkable floor, each with Links (the nodes you can walk to from it in a straight line). Nodes at the
-- spawn, the walkway junctions, every stair's foot and top, each lane's promenade landing; Goal = 'Exit' just
-- inside the stage-1 door. Lobby.GuideNodes: { name, x, floor y, z }; Lobby.GuideLinks: walkable pairs.
Lobby.GuideNodes = {
	{ 'Spawn', 0, Lobby.DaisTop, 66 },
	{ 'CrossN', 0, 0.1, 54.5 }, { 'CrossS', 0, 0.1, 77.5 }, { 'CrossW', -11.5, 0.1, 66 }, { 'CrossE', 11.5, 0.1, 66 },
	{ 'NorthJunction', 0, 0.1, 13 }, { 'Exit', 0, 0.1, 9 }, { 'Kiosk', 23.4, 0, 15.2 }, { 'NWApron', -33.5, 0, 12.5 },
	{ 'NStairFoot', -40, 0, 25.3 }, { 'NStairTop', -40, 1.2, 30.2 }, { 'Bay1Front', -34, 0, 36 },
	{ 'WestAisleN', -34, 0.1, 59.5 }, { 'WestAisleS', -34, 0.1, 71.5 }, { 'SideStairFoot', -31, 0.1, 65.5 }, { 'SideStairTop', -38.5, 4.8, 65.5 },
	{ 'AisleSW', -33.5, 0, 124.5 }, { 'GrandStairFoot', -40, 0, 123.8 }, { 'GrandStairTop', -40, 9.6, 111 },
	{ 'EastArm', 40, 0.1, 66 }, { 'SouthArm', 0, 0.1, 128 },
}
for i = 1, #Lobby.Ranges do
	table.insert(Lobby.GuideNodes, { 'Bay' .. i, -40, i * Lobby.RangeRise, Lobby.RangeZ0 + (i - 1) * Lobby.RangePitch + (i == 1 and 1.5 or 0) })
end
Lobby.GuideLinks = {
	{ 'Spawn', 'CrossN' }, { 'Spawn', 'CrossS' }, { 'Spawn', 'CrossW' }, { 'Spawn', 'CrossE' },
	{ 'CrossN', 'NorthJunction' }, { 'CrossN', 'Exit' }, { 'NorthJunction', 'Exit' }, { 'NorthJunction', 'Kiosk' }, { 'NorthJunction', 'NWApron' },
	{ 'NWApron', 'NStairFoot' }, { 'NStairFoot', 'NStairTop' }, { 'NStairTop', 'Bay1' },
	{ 'CrossW', 'WestAisleN' }, { 'CrossW', 'WestAisleS' }, { 'CrossW', 'SideStairFoot' },
	{ 'WestAisleN', 'Bay1Front' }, { 'Bay1Front', 'Bay1' },
	{ 'SideStairFoot', 'SideStairTop' }, { 'SideStairTop', 'Bay4' },
	{ 'WestAisleS', 'AisleSW' }, { 'AisleSW', 'GrandStairFoot' }, { 'GrandStairFoot', 'GrandStairTop' }, { 'GrandStairTop', 'Bay8' },
	{ 'CrossE', 'EastArm' }, { 'CrossS', 'SouthArm' },
}
for i = 1, #Lobby.Ranges - 1 do table.insert(Lobby.GuideLinks, { 'Bay' .. i, 'Bay' .. (i + 1) }) end
function Lobby.guideNodes(L)
	local folder = Instance.new('Folder')
	folder.Name = 'GuideNodes'
	folder.Parent = L.parent
	local c = L:into(folder)
	local links = {}
	for _, l in Lobby.GuideLinks do
		for _, e in { { l[1], l[2] }, { l[2], l[1] } } do
			links[e[1]] = links[e[1]] or {}
			table.insert(links[e[1]], e[2])
		end
	end
	for _, n in Lobby.GuideNodes do
		local p = c:part(n[1], V(1, 1, 1), CFrame.new(n[2], n[3] + 0.5, n[4]), P.white)
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
		p:SetAttribute('Links', table.concat(links[n[1]] or {}, ','))
		if n[1] == 'Exit' then p:SetAttribute('Goal', 'Exit') end
	end
	return folder
end

---------------------------------------------------------------------------------------------- build
Lobby.RewardAt = {
	DailyCrate = CFrame.lookAt(V(17.5, 0, 49), V(0, 0, 49)), -- NE island, beside the walk to the exit, facing it
	LuckyShot = CFrame.lookAt(V(15.5, 0, 96), V(0, 0, 96)), -- SE island, facing the south arm (the target turns)
	VipSafe = CFrame.lookAt(V(19.5, 0, 82), V(19.5, 0, 60)), -- SE island, facing the east arm, by the armory
}
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.hall(L)
	Lobby.floorPlan(L)
	Lobby.spawnDais(L)
	Lobby.kiosk(L)
	Lobby.world2(L, -30)
	Lobby.rangeRow(L, skins)
	Lobby.shoeDais(L)
	Lobby.slots(L)
	Lobby.islands(L)
	Lobby.rewards(L)
	Lobby.Slots.Statue = CFrame.lookAt(V(-54, 0, 144), V(-54, 0, 0)) -- the SW corner, facing north, square to the hall
	Lobby.statue(L, Lobby.Slots.Statue, skins)
	Lobby.Slots.Spawn = CFrame.new(SPAWN) * CFrame.Angles(0, Lobby.SpawnYaw, 0)
	for name, cf in Lobby.RewardAt do Lobby.Slots[name] = cf end
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	local boards = L:group('Leaderboards')
	for k, e in { { V(-60.5, 0, 124), V(0, 0, 124), 'CASH', 'CashLeaderboard' }, { V(38.6, 0, 9.6), V(38.6, 0, 60), 'REBIRTHS' }, { V(38, 0, 150.5), V(38, 0, 100), 'POWER', 'ServerLeaderboard' } } do
		local cf = CFrame.lookAt(e[1], e[2])
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[3], e[4])
	end
	Lobby.dressing(L)
	Lobby.hood(L, skins)
	Lobby.guideNodes(L)
	return model
end
---------------------------------------------------------------------------------------------- ground
-- Light grey paving in 8-stud slabs over the whole walk, a darker cross-street band at every district
-- line, grass behind the buildings, the low boundary wall and the ring road with its cars and trees. The
-- warehouse lobby (e2_lobby) lays its own floor; out here there's only the forecourt between its door and
-- the Stage 1 gate, and grass round the building.
local function invisibleWall(c, a, b)
	local w = c:box('Boundary', a, b, P.white, M.SmoothPlastic)
	w.Transparency = 1
	w.CastShadow = false
	return w
end
local function buildGround(ctx)
	assert(Lobby, 'TheBlockV2: e2_lobby.lua (the warehouse lobby) is missing from the assembly')
	local g = ctx:group('Ground')
	-- Paving: the stages, and the forecourt in front of the warehouse door.
	local function pave(x0, x1, z0, z1)
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - z0) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-FRONT, FRONT, 0, Lobby.N - 1)
	pave(-FRONT, FRONT, BOSS_END, 0)
	-- A darker cross-street band where every stage starts; its gate stands in the middle of it.
	for i = 1, STAGES + 1 do
		local z = stageTop(i)
		g:box('CrossStreet', V(-FRONT, -1, z - 4), V(FRONT, 0.02, z + 4), P.band, M.Asphalt)
		for x = -FRONT + 3, FRONT - 3, 6 do
			decor(g:box('CrossLine', V(x - 1.2, 0.02, z + 3.1), V(x + 1.2, 0.05, z + 3.5), P.bandLine, M.SmoothPlastic))
			decor(g:box('CrossLine', V(x - 1.2, 0.02, z - 3.5), V(x + 1.2, 0.05, z - 3.1), P.bandLine, M.SmoothPlastic))
		end
	end
	-- Sidewalks along both building lines (lighter slabs and a kerb line, flush so nothing trips) so the walk
	-- reads as a street: pavement, kerb, the middle. The lamps stand at the kerb, trees and benches on the pavement.
	for i = 1, STAGES do
		local z = stageTop(i)
		for _, s in { -1, 1 } do
			decor(g:box('Sidewalk', V(s * (FRONT - 8), 0, z - 60), V(s * FRONT, 0.03, z - 4), P.kerb, M.Pavement))
			decor(g:box('Kerb', V(s * (FRONT - 8.4), 0, z - 60), V(s * (FRONT - 8), 0.06, z - 4), P.band, M.Concrete))
		end
	end
	-- Grass behind the buildings and round the warehouse, inside the low boundary wall.
	local zIn0, zIn1 = BOSS_END - 6, SPAWN_TOP + 6
	for _, s in { -1, 1 } do
		g:box('Grass', V(s * (FRONT + DEPTH), -1, BOSS_END), V(s * WALL_X, 0.4, 0), P.grass, M.Grass)
		g:box('Grass', V(s * SPAWN_W, -1, 0), V(s * WALL_X, 0.4, SPAWN_TOP), P.grass, M.Grass)
		g:box('Grass', V(s * FRONT, -1, 0), V(s * SPAWN_W, 0.4, Lobby.N - 1), P.grass, M.Grass)
		g:box('Wall', V(s * WALL_X, -1, zIn0 - 1.4), V(s * (WALL_X + 1.4), 3, zIn1 + 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(s * (WALL_X - 0.2), 3, zIn0 - 1.6), V(s * (WALL_X + 1.6), 3.5, zIn1 + 1.6), P.kerb, M.Concrete)
	end
	g:box('Grass', V(-WALL_X, -1, SPAWN_TOP), V(WALL_X, 0.4, zIn1), P.grass, M.Grass)
	g:box('Grass', V(-FRONT - DEPTH, -1, zIn0), V(FRONT + DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(-WALL_X, -1, zIn0), V(-FRONT - DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(FRONT + DEPTH, -1, zIn0), V(WALL_X, 0.4, BOSS_END), P.grass, M.Grass)
	for _, e in { { zIn1, 1 }, { zIn0, -1 } } do
		g:box('Wall', V(-WALL_X, -1, e[1]), V(WALL_X, 3, e[1] + e[2] * 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(-WALL_X + 0.2, 3, e[1] - e[2] * 0.2), V(WALL_X - 0.2, 3.5, e[1] + e[2] * 1.6), P.kerb, M.Concrete)
	end
	-- Ring road outside the wall: kerb, two lanes with a dashed centre line, kerb, a grass verge with
	-- trees. Each band runs down both long sides and across both ends; the ends take the corners.
	local road = ctx:group('RingRoad')
	local W0 = WALL_X + 1.4
	local zTop, zBot = zIn1 + 1.4, zIn0 - 1.4
	for _, band in { { 0, 4, P.kerb, M.Concrete, 0.4 }, { 4, 20, P.asphalt, M.Asphalt, 0 }, { 20, 24, P.kerb, M.Concrete, 0.4 }, { 24, 32, P.grass, M.Grass, 0.4 } } do
		local a, b, color, mat, top = band[1], band[2], band[3], band[4], band[5]
		for _, s in { -1, 1 } do road:box('Road', V(s * (W0 + a), -1, zBot - a), V(s * (W0 + b), top, zTop + a), color, mat) end
		road:box('Road', V(-(W0 + b), -1, zTop + a), V(W0 + b, top, zTop + b), color, mat)
		road:box('Road', V(-(W0 + b), -1, zBot - b), V(W0 + b, top, zBot - a), color, mat)
	end
	for _, s in { -1, 1 } do
		for z = zBot, zTop - 5, 10 do decor(road:box('RoadDash', V(s * (W0 + 11.8), 0, z), V(s * (W0 + 12.2), 0.04, z + 5), P.roadLine, M.SmoothPlastic)) end
	end
	for x = -(W0 + 8), W0 + 3, 10 do
		decor(road:box('RoadDash', V(x, 0, zTop + 11.8), V(x + 5, 0.04, zTop + 12.2), P.roadLine, M.SmoothPlastic))
		decor(road:box('RoadDash', V(x, 0, zBot - 12.2), V(x + 5, 0.04, zBot - 11.8), P.roadLine, M.SmoothPlastic))
	end
	-- Trees on the verge and behind the buildings, cars parked at the kerb.
	local seed = 900
	for _, s in { -1, 1 } do
		for z = zBot - 20, zTop + 20, 22 do
			seed += 1
			tree(road, V(s * (W0 + 28), 0.4, z), seed, 1.0)
		end
		for z = BOSS_END + 20, -10, 30 do
			seed += 1
			tree(road, V(s * (FRONT + DEPTH + 3), 0.4, z), seed, 0.85)
		end
	end
	for x = -(W0 + 20), W0 + 20, 22 do
		seed += 1
		tree(road, V(x, 0.4, zTop + 28), seed, 1.0)
		tree(road, V(x, 0.4, zBot - 28), seed + 50, 1.0)
	end
	local carColors = { C(110, 43, 43), C(226, 218, 200), C(63, 125, 110), C(60, 66, 76), C(98, 114, 134), C(236, 234, 228) }
	local spots = { { -1, 40 }, { -1, -110 }, { -1, -300 }, { -1, -520 }, { -1, -760 }, { -1, -980 }, { 1, 10 }, { 1, -190 }, { 1, -370 }, { 1, -610 }, { 1, -850 }, { 1, -1040 } }
	for k, sp in spots do
		car(road, CFrame.new(sp[1] * (W0 + 7.5), 0, sp[2]) * CFrame.Angles(0, sp[1] < 0 and math.pi or 0, 0), carColors[(k - 1) % #carColors + 1])
	end
	-- Keep players on the walk where no building closes it: round the warehouse (its walls already do, these
	-- go up past the eaves) and over the forecourt's wing walls.
	for _, s in { -1, 1 } do
		invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		invisibleWall(g, V(s * 34.4, 0, 0.6), V(s * FRONT, 60, Lobby.N))
	end
	invisibleWall(g, V(-SPAWN_W, 0, SPAWN_TOP), V(SPAWN_W, 60, SPAWN_TOP + 1))
	invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
	return g
end

---------------------------------------------------------------------------------------------- spawn
-- The spawn is the warehouse lobby (e2_lobby): shooting ranges, the EVOLUTIONS podium, the armory,
-- the spawn badge, FurthestPad and the leaderboards are all built there.
local function buildSpawn(ctx, skins)
	return Lobby.build(ctx, skins)
end
---------------------------------------------------------------------------------------------- stage gates
-- A gate at the start of every stage (and the boss yard): charcoal steel posts on stone plinths at the
-- building line, a framed header board in the district accent with cream lettering, and a see-through wall in
-- a soft wash of that accent showing the power it takes (big cream number). HoodClient/Stages makes the wall
-- solid while you're short, turns it sage when you can pass and clears it once you have; StageService records
-- the clear and pays the reward.
local LOOK_NAMES = { 'THE BLOCK', 'SHOP STREET', 'THE COURTS', 'THE APARTMENTS', 'THE YARDS', 'BOSS YARD' }
local BOSS_RED = P.oxblood
local function lookColor(i) return i > STAGES and BOSS_RED or P.district[lookOf(i)] end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local color = lookColor(i)
	-- The wall is a soft wash of the accent, not a saturated sheet; its lettering is cream on a deep stroke.
	-- (Stage 1's sits in the lobby's exit door, so it is paler still: the exit sign there is the hero.)
	local tint = color:Lerp(P.cream, i == 1 and 0.7 or 0.4)
	local deep = color:Lerp(P.black, 0.6)
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	for _, s in { -1, 1 } do
		g:box('GatePlinth', V(s * 34.1, 0, -1), V(s * 36.3, 1.4, 1), P.stone, M.Concrete)
		g:box('GatePost', V(s * 34.4, 1.4, -0.6), V(s * 36, 24.8, 0.6), P.metal, M.Metal)
		g:box('GatePostCap', V(s * 34.2, 25.4, -0.8), V(s * 36.2, 26, 0.8), P.metal, M.Metal)
	end
	decor(g:box('GateSill', V(-34.4, 0, -0.5), V(34.4, 0.12, 0.5), P.metal, M.Metal))
	-- The header: a board in the district accent inside a charcoal steel frame.
	g:box('GateHeaderFrame', V(-36.2, 20.6, -0.8), V(36.2, 25.4, 0.8), P.metal, M.Metal)
	local header = g:box('GateHeader', V(-35.4, 21.1, -1), V(35.4, 24.9, 1), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local hg = surface(header, face, 16)
		pcall(function() hg.MaxDistance = i == 1 and 400 or 100 end)
		line(hg, 'Name', i > STAGES and 'BOSS YARD' or ('STAGE ' .. i .. '  •  ' .. LOOK_NAMES[lookOf(i)]), P.cream, FONT.loud, 0.14, 0.72, deep, 3)
	end
	local barrier = g:box('Barrier', V(-34.4, 0, -0.3), V(34.4, 21, 0.3), tint, M.SmoothPlastic)
	-- Stage 1's barrier fills the warehouse door, so it is fainter; the client keeps each gate's own base.
	barrier.Transparency = i == 1 and 0.8 or 0.68
	barrier:SetAttribute('BaseTransparency', barrier.Transparency)
	barrier.CastShadow = false
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local bg = surface(barrier, face, 12)
		-- Every gate's wall text shows only as you walk up (stage 1's not from inside the lobby, where the exit sign
		-- already says it; later gates' don't stack behind stage 1's through the warehouse door).
		pcall(function() bg.MaxDistance = i == 1 and 35 or 90 end)
		line(bg, 'Power', '💪 ' .. compact(req), P.cream, FONT.loud, 0.16, 0.34, deep, 6)
		line(bg, 'Sub', 'POWER TO ENTER', P.cream, FONT.title, 0.5, 0.12, deep, 3)
		line(bg, 'Status', 'NEED 💪 ' .. compact(req), P.cream, FONT.loud, 0.68, 0.1, deep, 2)
	end
	-- Pads on the approach side: back to spawn, and on to your furthest stage.
	if i > 1 then
		teleportPad(g, 'LobbyPad', -26, 7, P.padRed:Lerp(C(255, 40, 255), 0.6), 'Lobby', 'SPAWN')
		teleportPad(g, 'FurthestPad', 26, 7, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
	end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-15, 18, -1), V(15, 19, 1), P.white))
	local fx = Instance.new('ParticleEmitter')
	fx.Name = 'PassFX'
	fx.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	fx:SetAttribute('PreviewTexture', 'confetti')
	fx.Enabled = false
	fx.Rate = 0
	fx.Lifetime, fx.Speed = NumberRange.new(1.6, 2.6), NumberRange.new(8, 18)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Acceleration = V(0, -18, 0)
	fx.Drag = 1.2
	fx.Size = NumberSequence.new(0.5)
	fx.RotSpeed, fx.Rotation = NumberRange.new(-260, 260), NumberRange.new(0, 360)
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, P.gold), ColorSequenceKeypoint.new(1, P.cream) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', 'HoodW1Stage' .. i)
	model:SetAttribute('Required', req)
	model:SetAttribute('Reward', math.max(10, math.floor(req * 0.2)))
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + 7)
	model:SetAttribute('HalfWidth', FRONT)
	model:SetAttribute('Color', color)
	model:SetAttribute('Light', tint)
	model:AddTag('HoodStageGate')
	return model
end

---------------------------------------------------------------------------------------------- stages
-- Fifteen stages, three to a look (the concept's "1-3", "4-6"... groups). Stages that share a look share
-- their kit and colours but not their layout: building order, heights, shops and props change each time.
local TRIO_COLORS = { P.padRed, P.padBlue, P.padGreen }
-- District sign: a framed board on two charcoal posts at the kerb just past the district's first gate, in the
-- district accent with cream lettering and a cream plate hung under it (it replaces the floating banner,
-- which hid the next gate's number).
function Streets.districtSign(ctx, k, top)
	local s = k % 2 == 1 and -1 or 1
	local lo, hi = math.min(s * 19.5, s * 30.5), math.max(s * 19.5, s * 30.5)
	local zc = top - 5
	local g = ctx:group('DistrictSign')
	for _, x in { s * 20.5, s * 29.5 } do
		g:box('SignPostFoot', V(x - 0.6, 0, zc - 0.6), V(x + 0.6, 0.5, zc + 0.6), P.stone, M.Concrete)
		g:box('SignPost', V(x - 0.3, 0.5, zc - 0.3), V(x + 0.3, 11.4, zc + 0.3), P.metal, M.Metal)
		g:box('SignPostCap', V(x - 0.45, 11.4, zc - 0.45), V(x + 0.45, 11.7, zc + 0.45), P.metal, M.Metal)
	end
	g:box('SignFrame', V(lo - 0.3, 6.8, zc - 0.25), V(hi + 0.3, 11.1, zc + 0.25), P.metal, M.Metal)
	local board = g:box('SignBoard', V(lo, 7.1, zc - 0.4), V(hi, 10.8, zc + 0.4), P.district[k], M.SmoothPlastic)
	local plate = g:box('SignPlate', V(lo + 1.6, 5.3, zc - 0.3), V(hi - 1.6, 6.5, zc + 0.3), P.cream, M.SmoothPlastic)
	for _, x in { lo + 2.2, hi - 2.2 } do decor(g:box('PlateHanger', V(x - 0.06, 6.5, zc - 0.06), V(x + 0.06, 6.8, zc + 0.06), P.metal, M.Metal)) end
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		line(surface(board, face, 20), 'Title', LOOK_NAMES[k], P.cream, FONT.loud, 0.16, 0.68, P.district[k]:Lerp(P.black, 0.6), 2)
		line(surface(plate, face, 20), 'Stages', 'STAGES ' .. (3 * k - 2) .. ' - ' .. (3 * k), P.ink, FONT.title, 0.12, 0.76)
	end
	return g
end
local function sideRow(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1])
		z -= lot[1]
	end
end
-- Kerbside dressing in front of the buildings: lamps, trees in planters, hedges, benches, bins.
local function dressing(ctx, top, s, items)
	for _, it in items do
		local kind, zl = it[1], it[2]
		local x = s * (FRONT - (it[3] or 4))
		local p = V(x, 0, top + zl)
		if kind == 'lamp' then lantern(ctx, p)
		elseif kind == 'tree' then tree(ctx, p, math.floor(top + zl * 7 + s * 3), 0.95)
		elseif kind == 'hedge' then hedgeZ(ctx, x, top + zl - 4, top + zl + 4, 1.8)
		elseif kind == 'bench' then bench(ctx, p, V(-s, 0, 0))
		elseif kind == 'can' then trashCan(ctx, p)
		elseif kind == 'bags' then trashBags(ctx, p)
		elseif kind == 'dumpster' then dumpster(ctx, CFrame.new(p) * CFrame.Angles(0, math.pi / 2, 0))
		elseif kind == 'crates' then
			pallet(ctx, CFrame.new(p))
			crate(ctx, CFrame.new(p + V(0, 0.8, 0)), 2.6)
			crate(ctx, CFrame.new(p + V(0, 0.8, 3.2)) * CFrame.Angles(0, 0.2, 0), 2.4)
		end
	end
end
-- The usual kerb dressing, mirrored a little differently each stage so repeats don't line up.
local function standardDressing(ctx, top, i, extraL, extraR)
	local flip = i % 2 == 0
	dressing(ctx, top, -1, { { 'lamp', -14, 7 }, { flip and 'hedge' or 'tree', -26 }, { 'lamp', -44, 7 }, { flip and 'tree' or 'bench', -54, 4 }, table.unpack(extraL or {}) })
	dressing(ctx, top, 1, { { 'lamp', -14, 7 }, { flip and 'tree' or 'hedge', -26 }, { 'lamp', -44, 7 }, { flip and 'bench' or 'tree', -56, 4 }, table.unpack(extraR or {}) })
end
local function stageCore(ctx, i)
	local top = stageTop(i)
	local d = ctx:group('Stage' .. i)
	local _, pad = fightPad(d, i, V(0, 0, padZ(i)), TRIO_COLORS[trioOf(i)], lookOf(i))
	pad.parent:SetAttribute('Stage', i)
	if trioOf(i) == 1 then Streets.districtSign(d, lookOf(i), top) end
	-- Flush street furniture in the paving (worn-but-cared-for detail): a manhole cover and two kerb drains.
	decor(d:part('Manhole', V(0.06, 3.2, 3.2), CFrame.new(i % 2 == 0 and 9 or -11, 0.03, top - 47) * CFrame.Angles(0, 0, math.pi / 2), P.metal, M.DiamondPlate, Enum.PartType.Cylinder))
	for _, s in { -1, 1 } do decor(d:box('Drain', V(s * 27.4, 0, top - 22 - s * 6), V(s * 28.2, 0.07, top - 19 - s * 6), P.iron, M.DiamondPlate)) end
	return d, top
end

-- 1-3 The Block: red brick walk-ups, dumpsters, bags and crates.
local function brickStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local rows = {
		{ L = { { 24, 2, P.brick }, { 20, 3, P.brickDark }, { 20, 2, P.brick } }, R = { { 24, 2, P.brick }, { 20, 3, P.brick }, { 20, 2, P.brickDark } } },
		{ L = { { 20, 3, P.brickDark }, { 24, 2, P.brickPink }, { 20, 3, P.brick } }, R = { { 20, 2, P.brickDark }, { 20, 3, P.brick }, { 24, 3, P.brickPink } } },
		{ L = { { 16, 2, P.brick }, { 24, 3, P.brick }, { 24, 2, P.brickDark } }, R = { { 24, 3, P.brickDark }, { 16, 2, P.brickPink }, { 24, 3, P.brick } } },
	}
	local row = rows[t]
	for _, side in { { -1, row.L }, { 1, row.R } } do
		local lots = {}
		for k, b in side[2] do
			table.insert(lots, { b[1], function(f, w)
				brickBuilding(f, w, { floors = b[2], wall = b[3], bays = w <= 16 and 2 or 3, sideAt = (i == 1 and k == 1) and (side[1] < 0 and 0 or w) or nil })
			end })
		end
		sideRow(d, side[1], top, lots)
	end
	local extras = {
		{ { { 'dumpster', -36 }, { 'bags', -40, 3 } }, { { 'crates', -34, 4 } } },
		{ { { 'crates', -36, 4 } }, { { 'dumpster', -38 }, { 'bags', -33, 3 } } },
		{ { { 'bags', -36, 3 }, { 'can', -40, 3 } }, { { 'dumpster', -36 } } },
	}
	standardDressing(d, top, i, extras[t][1], extras[t][2])
end

-- 4-6 Shop Street: the barber and the grocery, then more shops under striped awnings. Each shop has ONE
-- muted accent (awning stripes and shopfront paint) and a framed board from the street's one sign system.
local SHOPS = {
	{ sign = 'PIZZA', accent = C(170, 80, 66), board = P.ink, text = P.cream, wall = P.brickPink },
	{ sign = 'SNEAKERS', accent = C(70, 76, 86), board = P.cream, text = P.ink, wall = P.brick },
	{ sign = 'ICE CREAM', accent = C(190, 132, 140), board = P.cream, text = C(150, 86, 98), wall = C(232, 222, 204) },
	{ sign = 'ARCADE', accent = C(112, 92, 142), board = P.ink, text = P.gold, wall = P.brickDark },
	{ sign = 'BAKERY', accent = C(150, 106, 72), board = P.cream, text = C(112, 74, 48), wall = P.tan, extra = 'crates' },
	{ sign = 'PHONES', accent = C(84, 110, 150), board = P.ink, text = P.cream, wall = P.brick },
}
local function shopStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	if t == 1 then
		sideRow(d, -1, top, {
			{ 20, function(f, w) brickBuilding(f, w, { floors = 3 }) end },
			{ 24, function(f, w) barberShop(f, w) end },
			{ 20, function(f, w) tanBuilding(f, w, { floors = 3, balconies = false }) end },
		})
		sideRow(d, 1, top, {
			{ 20, function(f, w) blueShop(f, w, 'LAUNDRY') end },
			{ 24, function(f, w) grocery(f, w) end },
			{ 20, function(f, w) brickBuilding(f, w, { floors = 3, wall = P.brickDark }) end },
		})
	else
		local a, b = SHOPS[(t - 2) * 3 + 1], SHOPS[(t - 2) * 3 + 2]
		local c3 = SHOPS[(t - 2) * 3 + 3]
		sideRow(d, -1, top, {
			{ 24, function(f, w) shopBuilding(f, w, a) end },
			{ 20, function(f, w) brickBuilding(f, w, { floors = 3, wall = t == 2 and P.brickDark or P.brick }) end },
			{ 20, function(f, w) shopBuilding(f, w, c3) end },
		})
		sideRow(d, 1, top, {
			{ 20, function(f, w) tanBuilding(f, w, { floors = 3, balconies = false }) end },
			{ 24, function(f, w) shopBuilding(f, w, b) end },
			{ 20, function(f, w) blueShop(f, w, t == 2 and 'LAUNDRY' or 'DELI') end },
		})
	end
	standardDressing(d, top, i, { { 'bench', -34, 4 } }, { { 'can', -34, 3 } })
end

-- 7-9 The Courts: a fenced court across the walk in each: a grey basketball court with teal keys, a slate
-- court with terracotta keys, then a turf five-a-side cage with goals (most real courts are grey; the colour is
-- in the keys).
local COURTS = { { P.court, 'hoops', P.district[3] }, { P.courtSlate, 'hoops', P.courtKey }, { P.courtTurf, 'goals' } }
local function courtStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local floor, kind, key = COURTS[t][1], COURTS[t][2], COURTS[t][3]
	local z0, z1 = top - 58, top - 10
	d:box('Court', V(-FRONT + 4, 0, z0), V(FRONT - 4, 0.12, z1), floor, M.SmoothPlastic)
	local function stripe(a, b) decor(d:box('CourtLine', a, b, P.courtLine, M.SmoothPlastic)) end
	stripe(V(-FRONT + 4, 0.12, z1 - 0.4), V(FRONT - 4, 0.16, z1))
	stripe(V(-FRONT + 4, 0.12, z0), V(FRONT - 4, 0.16, z0 + 0.4))
	stripe(V(-FRONT + 4, 0.12, z0), V(-FRONT + 4.4, 0.16, z1))
	stripe(V(FRONT - 4.4, 0.12, z0), V(FRONT - 4, 0.16, z1))
	stripe(V(-0.2, 0.12, z0), V(0.2, 0.16, z1))
	local zc = (z0 + z1) / 2
	local function arc(cx, r, a0, a1, n)
		for q = 0, n - 1 do
			local t0, t1 = a0 + (a1 - a0) * q / n, a0 + (a1 - a0) * (q + 1) / n
			local p0, p1 = V(cx + math.cos(t0) * r, 0.14, zc + math.sin(t0) * r), V(cx + math.cos(t1) * r, 0.14, zc + math.sin(t1) * r)
			decor(d:part('CourtArc', V(0.4, 0.04, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), P.courtLine, M.SmoothPlastic))
		end
	end
	arc(0, 6, 0, math.pi * 2, 16)
	if key then
		-- The keys (the painted lanes under each hoop), framed by court line.
		for _, s in { -1, 1 } do
			local x0, x1 = s * (FRONT - 4), s * (FRONT - 16)
			decor(d:box('CourtKey', V(x0, 0.12, zc - 5), V(x1, 0.15, zc + 5), key, M.SmoothPlastic))
			stripe(V(x1 - 0.2, 0.12, zc - 5), V(x1 + 0.2, 0.16, zc + 5))
		end
	end
	arc(-FRONT + 4, 14, -math.pi / 2, math.pi / 2, 12)
	arc(FRONT - 4, 14, math.pi / 2, math.pi * 1.5, 12)
	for _, s in { -1, 1 } do
		if kind == 'hoops' then
			local h = d:at(CFrame.lookAt(V(s * (FRONT - 3), 0, zc), V(0, 0, zc))):group('Hoop')
			h:post('HoopPole', 0.35, 11, V(0, 0, 0.6), C(60, 64, 72), M.Metal)
			h:box('HoopArm', V(-0.25, 10.4, -1.2), V(0.25, 10.8, 0.6), C(60, 64, 72), M.Metal)
			h:box('Backboard', V(-2.6, 9.4, -1.6), V(2.6, 12.6, -1.3), P.frame, M.SmoothPlastic)
			decor(h:box('BoardSquare', V(-1, 10.0, -1.65), V(1, 11.2, -1.6), key or P.metal, M.SmoothPlastic))
			for q = 0, 7 do
				local a = q / 8 * math.pi * 2
				decor(h:part('Rim', V(0.7, 0.12, 0.14), CFrame.new(math.cos(a) * 0.85, 10, -2.6 + math.sin(a) * 0.85) * CFrame.Angles(0, -a + math.pi / 2, 0), C(184, 110, 76), M.Metal))
				decor(h:bar('Net', V(math.cos(a) * 0.82, 9.95, -2.6 + math.sin(a) * 0.82), V(math.cos(a) * 0.45, 8.9, -2.6 + math.sin(a) * 0.45), 0.07, P.white, M.Fabric))
			end
		else
			-- Small goal: white frame and a dark net box behind it.
			local gl = d:at(CFrame.lookAt(V(s * (FRONT - 6), 0, zc), V(0, 0, zc))):group('Goal')
			for _, x in { -4, 4 } do gl:box('GoalPost', V(x - 0.25, 0, -0.25), V(x + 0.25, 5, 0.25), P.white, M.SmoothPlastic) end
			gl:box('GoalBar', V(-4.25, 5, -0.25), V(4.25, 5.5, 0.25), P.white, M.SmoothPlastic)
			local net = gl:box('GoalNet', V(-4, 0.2, 0.3), V(4, 4.9, 3), C(220, 224, 230), M.Fabric)
			net.Transparency = 0.5
			gl:part('Ball', V(1.4, 1.4, 1.4), CFrame.new(1.5, 0.82, -6), P.white, M.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	for _, z in { z1 + 1.5, z0 - 1.5 } do chainLink(d, V(-FRONT + 1, 0, z), V(FRONT - 1, 0, z), 9, { { FRONT - 1 - 8, FRONT - 1 + 8 } }) end
	local rows = {
		{ L = { 'tan3', 'brick3', 'tan2' }, R = { 'brickD2', 'tan3', 'brick3' } },
		{ L = { 'brick3', 'tan3', 'brickD2' }, R = { 'tan2', 'brick3', 'tan3' } },
		{ L = { 'tan2', 'brickD3', 'tan3' }, R = { 'brick3', 'tan3', 'brickD2' } },
	}
	local function build(kind, f, w)
		if kind:sub(1, 3) == 'tan' then tanBuilding(f, w, { floors = tonumber(kind:sub(4)), balconies = false })
		else brickBuilding(f, w, { floors = tonumber(kind:sub(-1)), wall = kind:sub(1, 6) == 'brickD' and P.brickDark or P.brick }) end
	end
	for _, side in { { -1, rows[t].L }, { 1, rows[t].R } } do
		local widths = { 24, 20, 20 }
		local lots = {}
		for k, kind in side[2] do table.insert(lots, { widths[k], function(f, w) build(kind, f, w) end }) end
		sideRow(d, side[1], top, lots)
	end
	for _, s in { -1, 1 } do
		bench(d, V(s * (FRONT - 2.4), 0, top - 6), V(-s, 0, 0))
		lantern(d, V(s * (FRONT - 7), 0, top - 61))
	end
end

-- 10-12 The Apartments: tan blocks with balconies, hedges and benches.
local function apartmentStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local light = P.tan:Lerp(P.tanLight, 0.35)
	-- Towers, taller each stage: the district reads as "the apartments" from the gate.
	local floors = { { { 5, 6, 5 }, { 6, 5, 5 } }, { { 6, 5, 6 }, { 5, 6, 6 } }, { { 6, 7, 6 }, { 7, 6, 6 } } }
	local widths = { { 24, 20, 20 }, { 20, 24, 20 }, { 20, 20, 24 } }
	for k, s in { -1, 1 } do
		local f3 = floors[t][k]
		local lots = {}
		for q = 1, 3 do
			local wall = ((q + k + t) % 2 == 0) and light or P.tan
			table.insert(lots, { widths[t][q], function(f, w) tanBuilding(f, w, { floors = f3[q], wall = wall, stone = true }) end })
		end
		sideRow(d, s, top, lots)
	end
	standardDressing(d, top, i, { { 'bench', -34, 4 } }, { { 'can', -36, 3 } })
end

-- 13-15 The Yards: warehouses and container lots between the last apartments, fences toward the boss.
local function yardStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local grey = C(150, 146, 140)
	local plans = {
		{ L = { { 32, 'warehouse' }, { 32, 'containers' } }, R = { { 32, 'containers' }, { 32, 'greyhouse' } } }, -- (all industrial: the district's first look)
		{ L = { { 24, 'tan4' }, { 40, 'greyhouse' } }, R = { { 40, 'containers' }, { 24, 'tan4' } } },
		{ L = { { 32, 'containers' }, { 32, 'tan4' } }, R = { { 32, 'tan3' }, { 32, 'warehouse' } } },
	}
	for _, side in { { -1, plans[t].L }, { 1, plans[t].R } } do
		local lots = {}
		for _, lot in side[2] do
			local kind = lot[2]
			table.insert(lots, { lot[1], function(f, w)
				if kind == 'warehouse' then warehouse(f, w)
				elseif kind == 'greyhouse' then warehouse(f, w, grey)
				elseif kind == 'containers' then containerLot(f, w, i)
				else tanBuilding(f, w, { floors = tonumber(kind:sub(4)), wall = P.tanDark:Lerp(P.tan, 0.5) }) end
			end })
		end
		sideRow(d, side[1], top, lots)
	end
	standardDressing(d, top, i, { { 'crates', -34, 4 } }, { { 'bags', -36, 3 } })
	if t == 3 then chainLink(d, V(-FRONT + 1, 0, top - 60), V(FRONT - 1, 0, top - 60), 9, { { FRONT - 1 - 9, FRONT - 1 + 9 } }) end
end

---------------------------------------------------------------------------------------------- boss yard
-- The Champ Ring comes from HoodProps (shared with the old map, not edited here) and is built loud; the boss
-- yard tones its parts into the street palette after building it: brass instead of yellow, oxblood and slate
-- instead of signal red and royal blue, warm-white neon, a calmer crowd, and red-cream-slate ropes that hold
-- still (no rainbow, no neon paint).
function Streets.calmRing(model)
	local red, brass = C(160, 70, 66), C(196, 156, 86)
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency < 1 then
			local h, s, v = d.Color:ToHSV()
			local deg = h * 360
			if d.Name == 'Rope' then
				-- (rows by height: oxblood, cream, slate, cream from the bottom)
				local row = math.floor((d.CFrame.Position.Y - V2.Origin.Position.Y - 3.4) / 1.15 + 0.5)
				d.Color, d.Material = ({ red, P.cream, P.district[5], P.cream })[math.clamp(row, 1, 4)], M.SmoothPlastic
			elseif s > 0.45 and v > 0.3 then
				if d.Material == M.Neon then d.Color = P.lampGlow
				elseif deg >= 30 and deg < 70 then d.Color = brass
				elseif deg < 15 or deg >= 340 then d.Color = red
				elseif deg >= 200 and deg < 250 then d.Color = P.district[5]
				else d.Color = Color3.fromHSV(h, math.min(s, 0.42), math.min(v, 0.78)) end
			end
		elseif d:IsA('TextLabel') then
			local h, s, v = d.TextColor3:ToHSV()
			if s > 0.45 then d.TextColor3 = Color3.fromHSV(h, 0.45, math.min(v, 0.92)) end
		elseif d:IsA('ParticleEmitter') and d.Name == 'Confetti' then
			d.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.gold), ColorSequenceKeypoint.new(0.5, P.cream), ColorSequenceKeypoint.new(1, red) })
		end
	end
	local ropes = model:FindFirstChild('Ropes', true)
	if ropes then ropes:SetAttribute('Hue', nil) end
end

-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end.
local function bossYard(ctx)
	local b = ctx:group('BossYard')
	b:box('YardSlab', V(-FRONT, 0, BOSS_END), V(FRONT, 0.06, BOSS_TOP - 4), C(178, 172, 162), M.Concrete)
	sideRow(b, -1, BOSS_TOP, {
		{ 56, function(f, w) warehouse(f, w) end },
		{ 40, function(f, w) brickBuilding(f, w, { floors = 2, wall = P.warehouse:Lerp(P.black, 0.1), bays = 4 }) end },
	})
	sideRow(b, 1, BOSS_TOP, { { 96, function(f, w) containerLot(f, w, 3) end } })
	car(b, CFrame.new(-26, 0, BOSS_TOP - 70) * CFrame.Angles(0, math.rad(80), 0), P.frame)
	local ring = SKINS.StationById.Ring
	local ringCtx, ringModel = b:at(CFrame.new(0, 0, BOSS_TOP - 34) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id)
	Props.ring(ringCtx, PROPS_KIT, ring, 7)
	Streets.calmRing(ringModel)
	-- The champion aura on the canvas, in a warm pale gold (the tier-9 rainbow was the loudest thing in the yard).
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	if canvas and vfx then vfx.station(canvas, 8, C(236, 206, 150), V(14, 12, 14)) end
	local bz = BOSS_END + 22
	local _, pad = fightPad(b, 16, V(0, 0, bz), P.bossRing, 6, 14, 'BOSS')
	local model = pad.parent
	model.Name = 'BossPad'
	model:SetAttribute('Boss', true)
	local glow = decor(b:part('BossRing', V(0.1, 22, 22), CFrame.new(0, 0.05, bz) * CFrame.Angles(0, 0, math.pi / 2), P.bossRing, M.Neon, Enum.PartType.Cylinder))
	glow.Transparency, glow.CastShadow = 0.25, false
	decor(b:part('BossRingInner', V(0.11, 20.8, 20.8), CFrame.new(0, 0.06, bz) * CFrame.Angles(0, 0, math.pi / 2), C(178, 172, 162), M.Concrete, Enum.PartType.Cylinder)).CastShadow = false
	-- The BOSS board: oxblood in a charcoal frame, hung on chains from a steel gantry behind the pad.
	local gz = bz - 9
	for _, x in { -9, 9 } do
		b:box('GantryFoot', V(x - 0.9, 0, gz - 0.9), V(x + 0.9, 0.8, gz + 0.9), P.stone, M.Concrete)
		b:box('GantryPost', V(x - 0.45, 0.8, gz - 0.45), V(x + 0.45, 17.4, gz + 0.45), P.metal, M.Metal)
	end
	b:box('GantryBeam', V(-9.6, 17.4, gz - 0.6), V(9.6, 18.4, gz + 0.6), P.metal, M.Metal)
	for _, x in { -5.5, 5.5 } do decor(b:box('GantryChain', V(x - 0.08, 15.9, gz - 0.08), V(x + 0.08, 17.4, gz + 0.08), P.iron, M.Metal)) end
	b:box('BossSignFrame', V(-8.3, 10.7, gz - 0.3), V(8.3, 15.9, gz + 0.3), P.metal, M.Metal)
	local board = b:box('BossSign', V(-7.9, 11.1, gz - 0.45), V(7.9, 15.5, gz + 0.45), BOSS_RED, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		line(surface(board, face, 20), 'Title', 'BOSS', P.cream, FONT.loud, 0.12, 0.76, BOSS_RED:Lerp(P.black, 0.6), 3)
	end
	for x = -30, 30, 15 do tree(b, V(x, 0, BOSS_END + 4), 600 + x, 1) end
	return b
end

local STAGE_BUILDERS = { brickStage, shopStage, courtStage, apartmentStage, yardStage }
local function buildStages(ctx)
	for i = 1, STAGES do STAGE_BUILDERS[lookOf(i)](ctx, i) end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do stageGate(gates, i) end
	bossYard(ctx)
end
---------------------------------------------------------------------------------------------- play here
-- Make The Block V2 the map the game runs on (players spawn here; gameplay services and the HUD use it),
-- or hand the game back to the original Block. Other spawn points are switched off, never deleted: each
-- remembers it was on (attribute HoodSpawnWasEnabled), and SetActive(false) switches it back on.
function V2.SetActive(on)
	local root = workspace:FindFirstChild('TheBlockV2')
	assert(root, 'Build The Block V2 first: require(game.ServerStorage.TheBlockV2).Build()')
	for _, d in workspace:GetDescendants() do
		if d:IsA('SpawnLocation') and not d:IsDescendantOf(root) then
			if on and d.Enabled then
				d:SetAttribute('HoodSpawnWasEnabled', true)
				d.Enabled = false
			elseif not on and d:GetAttribute('HoodSpawnWasEnabled') then
				d.Enabled = true
				d:SetAttribute('HoodSpawnWasEnabled', nil)
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA('SpawnLocation') then d.Enabled = on end
	end
	root:SetAttribute('Active', on)
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 active ' .. tostring(on)) end)
	print(on and '[TheBlockV2] Active: press Play to spawn here. SetActive(false) gives the game back to the original Block.'
		or '[TheBlockV2] Inactive: the original Block is the game map again.')
end
---------------------------------------------------------------------------------------------- build
-- The warehouse lobby's builder; V2.Lobby.Slots (name -> CFrame in the map frame) is filled by Build.
V2.Lobby = Lobby
function V2.Build()
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	SKINS = skins
	Props = require(game:GetService('ServerStorage').HoodProps)
	PROPS_KIT = { studs = studs, decor = decor, ghost = ghost, light = light, surface = surface, line = line, billboard = billboard, compact = compact, FONT = FONT }

	local old = workspace:FindFirstChild('TheBlockV2')
	if old then
		local backup = Instance.new('Folder')
		backup.Name = 'TheBlockV2_Before_' .. os.date('!%Y%m%d_%H%M%S')
		backup.Parent = game:GetService('ServerStorage')
		old.Parent = backup
	end
	local root = Instance.new('Model')
	root.Name = 'TheBlockV2'
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 lobby calm (BRIEF6)')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN + V(0, Lobby.DaisTop, 0)) -- on the spawn dais's top
	root:SetAttribute('LobbySpawnYaw', Lobby.SpawnYaw) -- the way the spawn faces (radians about Y)
	root:SetAttribute('MorphStand', false) -- no Morphs stands in the world any more: looks are equipped from the HUD's EVOLVE menu
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	buildStages(ctx)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('HoodCalm') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn in the hood; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
