-- The Block V2: "+1 Hood Evolution", World 1, built from the team's concept sheet (hoodw1), stretched so every
-- look on the sheet is three full stages:
--   the warehouse lobby (spawn, the 8 bag stations, 3 treadmills, the EVOLUTIONS podium, the ARMORY)
--   stages 1-3 The Block (red brick), 4-6 Shop Street (barber, grocery and more shops), 7-9 The Courts,
--   10-12 The Apartments (tan, balconies), 13-15 The Yards (warehouses, containers)
--   the boss yard (Champ Ring, the BOSS pad)
-- Every stage starts with a gate that needs more power than the last (V2.StagePower); every bag trains in
-- the lobby. Buildings stand shoulder to shoulder down both sides,
-- fronts to the middle; a ring road with trees and parked cars runs round the outside.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on and applies
-- the Front-page Day lighting (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). Each stage's pad is tagged HoodFightPad
-- (Fight = stage, 16 = the boss) for the fight system to come. The lobby's Morphs stand is where looks are
-- equipped; Training_<Id> stations (8 in the lobby, the Ring in the boss yard) and Treadmill_<Id> train.
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
local SPAWN = V(0, 1.2, 60) -- the spawn badge where the lobby's walkways cross (on the 1.2-stud deck)
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
		decor(k:box('TailLight', V(x, 2.1, 5.2), V(x + 0.9, 2.6, 5.25), C(220, 40, 40), M.SmoothPlastic))
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

-- Fight pad: a glowing coloured square with a white border and its number painted on top.
local function fightPad(c, n, pos, color, district, size, label)
	size = size or PAD_SIZE
	local h = size / 2
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	pad:box('PadBorder', V(-h - 0.5, 0, -h - 0.5), V(h + 0.5, 0.3, h + 0.5), P.white, M.SmoothPlastic)
	local top = pad:box('Pad', V(-h + 0.3, 0, -h + 0.3), V(h - 0.3, 0.36, h - 0.3), color, M.SmoothPlastic)
	decor(pad:box('PadGlow', V(-h, 0.3, -h), V(h, 0.33, h), color:Lerp(P.white, 0.35), M.Neon)).CastShadow = false
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), P.white, FONT.loud, 0.18, 0.64, C(20, 24, 40), 6)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color, 1.2, 10, 120
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
		pcall(function() g.MaxDistance = 300 end)
		line(g, 'Title', text, P.white, FONT.loud, 0.1, 0.8, color:Lerp(P.black, 0.55), 5)
	end
	return b
end

-- Teleport pad: a flat glowing tile with a prompt (StageService handles targets 'Lobby' and 'Furthest').
local function teleportPad(g, name, x, z, color, target, label)
	local pad = g:box(name, V(x - 3.5, 0, z - 2), V(x + 3.5, 0.35, z + 2), color, M.SmoothPlastic)
	decor(g:box(name .. 'Glow', V(x - 3, 0.35, z - 1.5), V(x + 3, 0.42, z + 1.5), color, M.Neon)).CastShadow = false
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
	billboard(g, V(x, 3.2, z), 6, 1.4, { { 'Title', label, P.white, FONT.title, 0, 1 } }).WorldLabel.MaxDistance = 50
	return pad
end
---------------------------------------------------------------------------------------------- training stations
-- Punching-bag stations, one to one with the lobby reference (ref_bags): a long flat mat (7 x 18) in a low
-- two-tone rim with stepped pixel corners, a gallows at the outer end (a solid light truss post with thin dark
-- grooves on a stamped foot, a truss arm reaching back toward the aisle, a long diagonal brace, a short strap)
-- and a tall eight-sided barrel bag (a flat-topped capsule with two dark bands). Every block face carries the
-- reference's embossed X (a Texture; see Stations.stamp). Floating labels: a Power chip (FREE / 💪 N),
-- Unlocked or Locked (the client writes it) and a big outlined "xN Power" in the theme colour.
-- One theme per tier, flat saturated colours, the effects belong to the material (HoodVFX.theme):
--   1 slate + brown barrel   2 red rain   3 lava fire carpet   4 magenta/purple comets   5 cyan ice + snow
--   6 neon toxic pit + dark streaks   7 shadow black + smoke   8 lemon gold nuggets + glints
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included), parts up to
-- y ~13.3, labels float to ~17. The front (-Z) faces the aisle: players walk on from -Z, stand on the aisle
-- half and punch toward +Z; the post stands at the outer end (z +6) and the bag hangs at z +1.5.
-- opts.vfx = false skips effects, opts.tier overrides the tier (opts.side is accepted but not needed: the
-- station is symmetric across its X axis).
-- Contract (Lobby.client, Punch.client, LobbyRules): Training_<Id> > TrainingZone (the mat top, invisible),
-- Equipment (Hinge + Swing = strap and bag, + Gallows), Sign (BillboardGui with Chip + TextLabels Cost,
-- Detail, Power), attributes Tier, HitPoint (fist height on the bag's aisle face), HitColor. Locked stations
-- keep their colours (lead sign-off, bags round 3): the client only writes Locked/Unlocked and halves the
-- effects' rate.
local Stations = {}

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (stamped band, studded lip; rimTopMat Neon = a
-- glowing lip without studs); mat: the inset surface; frame (+frameMat): the gallows; bag/band (+bagMat): the
-- barrel; text: the "xN Power" colour; glow: hit sparks; edge: a thin neon line inside the rim (shadow).
-- Colours sampled from the reference and checked on the calibrated preview renderer.
Stations.Themes = {
	{ name = 'stone', rim = C(62, 78, 118), rimTop = C(82, 104, 150), mat = C(115, 132, 172), frame = C(113, 131, 170),
		bag = C(165, 95, 78), band = C(40, 32, 66), text = C(255, 255, 255), glow = C(255, 236, 200), sleeve = true },
	{ name = 'red', rim = C(26, 30, 70), rimTop = C(40, 46, 92), mat = C(250, 45, 85), frame = C(36, 42, 86), trim = C(240, 40, 70),
		bag = C(226, 36, 56), band = C(36, 30, 66), text = C(255, 70, 100), glow = C(255, 70, 100) },
	{ name = 'lava', rim = C(225, 100, 35), rimTop = C(255, 150, 50), mat = C(255, 140, 20), frame = C(250, 140, 36),
		bag = C(252, 140, 34), band = C(230, 120, 30), text = C(255, 170, 48), glow = C(255, 150, 40) },
	{ name = 'arcane', rim = C(150, 40, 130), rimTop = C(240, 80, 190), mat = C(190, 70, 208), frame = C(170, 80, 220),
		bag = C(166, 76, 222), band = C(70, 30, 110), text = C(214, 120, 255), glow = C(230, 120, 255) },
	{ name = 'frost', rim = C(60, 180, 230), rimTop = C(160, 244, 255), mat = C(132, 246, 248), matMat = M.SmoothPlastic, frame = C(80, 215, 250),
		bag = C(120, 225, 255), bagTransparency = 0.2, bagReflectance = 0.15, band = C(90, 200, 245), block = true, stampAlpha = 0.4,
		text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', rim = C(10, 170, 44), rimTop = C(20, 255, 60), rimTopMat = M.Neon, mat = C(0, 60, 60), frame = C(20, 255, 60), frameMat = M.Neon,
		bag = C(20, 255, 60), bagMat = M.Neon, band = C(24, 30, 70), text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'shadow', rim = C(70, 40, 110), rimTop = C(92, 56, 140), mat = C(44, 24, 70), frame = C(14, 12, 20),
		bag = C(14, 12, 20), band = C(60, 34, 100), text = C(198, 164, 255), glow = C(176, 120, 255), edge = C(150, 70, 255) },
	{ name = 'gold', rim = C(230, 180, 0), rimTop = C(255, 236, 60), mat = C(255, 215, 0), frame = C(255, 232, 50),
		bag = C(255, 236, 80), band = C(255, 205, 0), text = C(255, 222, 50), glow = C(255, 222, 80), flaredFoot = true },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.POST_Z = 6.0 -- post centre, toward the outer end
Stations.POST_W = 1.7
Stations.ARM_Y = 11.4 -- underside of the arm (the hinge); the post top lands at ~13
Stations.ARM_W = 1.2
Stations.BAG_Z = 1.5 -- the bag hangs 4.5 studs in from the post
Stations.BAG_TOP = 10.0 -- (a 1.4 strap up to the arm)
Stations.BAG_H = 6.6
Stations.HIT_Y = 4.8 -- fist height of a player standing on the mat
Stations.StampId = '' -- set from HoodVFX.Textures.stamp at build time ('' until the PNG is uploaded)

-- The reference's embossed X on a block face: a Texture tiled every su x sv studs. The PNG carries both the
-- dark groove and its light edge, so Color3 stays white and it works on any colour. With no uploaded id the
-- Texture draws nothing in Studio; the offline renderer draws hood/art/vfx/stamp.png (PreviewTexture).
function Stations.stamp(part, faces, su, sv, alpha)
	for _, face in faces do
		local t = Instance.new('Texture')
		t.Name = 'Stamp'
		t.Face = face
		t.Texture = Stations.StampId
		t.StudsPerTileU, t.StudsPerTileV = su or 2, sv or 2
		t.Transparency = 1 - (alpha or 1)
		t.Color3 = C(255, 255, 255)
		t:SetAttribute('PreviewTexture', 'stamp')
		t.Parent = part
	end
end
Stations.SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Regular octagonal prism (apothem a, y0..y1) from four slabs turned 45 degrees apart: the low-poly round.
-- Returns the slabs; each slab's Front and Back faces are two of the eight facets.
function Stations.octagon(c, name, x, z, a, y0, y1, color, material)
	local w, slabs = 2 * a * math.tan(math.pi / 8), {}
	for k = 0, 3 do table.insert(slabs, c:part(name, V(w, y1 - y0, 2 * a), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 4, 0), color, material)) end
	return slabs, w
end

-- A truss beam along the local +Y of `cf` (cf = centre of the base), len long, w x d thick, like the
-- reference's: a solid light beam in the frame colour with thin dark grooves cut into it, a tie line every
-- `cell` studs and an X in every cell of the faces listed in `faces` ('-x', '+x', '-z', '+z' in cf's frame).
-- The grooves stand only 0.02 proud, so from a distance the post reads as one solid block.
function Stations.truss(c, name, cf, len, w, d, color, groove, cell, faces, material)
	c:part(name .. 'Core', V(w, len, d), cf * CFrame.new(0, len / 2, 0), color, material)
	local n = math.max(1, math.floor(len / cell + 0.5))
	local seg, g = len / n, 0.12
	for _, f in faces do
		local onX = f:sub(2) == 'x'
		local s = f:sub(1, 1) == '-' and -1 or 1
		local span = (onX and d or w) - 0.3 -- grooves stop short of the corners
		local off = (onX and w or d) / 2 + 0.01 -- 0.02 proud of the face
		local L = math.sqrt(span * span + seg * seg)
		local ang = math.atan2(span, seg)
		for k = 0, n do
			-- Tie line across this face at every cell joint (and the two ends).
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

-- The gallows: a stamped foot (a tall sleeve on the starter, a flared block on gold), the truss post, a truss
-- arm running from the post back toward the aisle to just past the strap, a long diagonal brace, a cap and the
-- hook plate.
function Stations.gallows(g, t, tier)
	local Y, pz, bz = Stations.MAT_Y, Stations.POST_Z, Stations.BAG_Z
	local W, AW, A0 = Stations.POST_W, Stations.ARM_W, Stations.ARM_Y
	local frame, fm = t.frame, t.frameMat or M.SmoothPlastic
	local groove = t.frame:Lerp(C(0, 0, 0), 0.3)
	local foot = t.frame:Lerp(C(0, 0, 0), 0.12)
	local base
	if t.sleeve then
		-- The starter's post sits in a 2.2-wide sleeve for its bottom 3 studs, on a low plate.
		Stations.stamp(g:box('Foot', V(-1.4, Y, pz - 1.4), V(1.4, Y + 0.4, pz + 1.4), foot), Stations.SIDES, 1.4, 0.4)
		Stations.stamp(g:box('Sleeve', V(-1.1, Y + 0.4, pz - 1.1), V(1.1, Y + 3, pz + 1.1), frame), Stations.SIDES, 2.2, 2.6)
		base = Y + 3
	elseif t.flaredFoot then
		-- Gold: a block flaring from 3.2 at the floor to 2.2 at the top, 1.5 tall (a core and four wedges).
		local h, r0, r1 = 1.5, 1.6, 1.1
		Stations.stamp(g:box('Foot', V(-r1, Y, pz - r1), V(r1, Y + h, pz + r1), frame, fm), Stations.SIDES, 2.2, 1.5)
		for k = 0, 3 do
			local cf = CFrame.new(0, Y + h / 2, pz) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -(r1 + (r0 - r1) / 2))
			g:wedge('FootFlare', V(2 * r1, h, r0 - r1), cf, frame, fm) -- (a wedge's tall face is its +Z side)
		end
		base = Y + h
	else
		Stations.stamp(g:box('Foot', V(-1.3, Y, pz - 1.3), V(1.3, Y + 1.2, pz + 1.3), foot, fm), Stations.SIDES, 1.3, 1.2)
		base = Y + 1.2
	end
	local postTop = A0 + AW + 0.4
	Stations.truss(g, 'Post', CFrame.new(0, base, pz), postTop - base, W, W, frame, groove, 1.9, { '-z', '-x', '+x', '+z' }, fm)
	g:box('PostCap', V(-1.0, postTop, pz - 1.0), V(1.0, postTop + 0.3, pz + 1.0), frame, fm)
	-- Arm: a truss lying along -Z from the post's outer face to 0.3 past the strap (rotated so its +Y runs
	-- toward the aisle; both sides and the top carry grooves).
	local a0, a1 = pz + W / 2, bz - 0.3
	local armCf = CFrame.new(0, A0 + AW / 2, a0) * CFrame.Angles(-math.pi / 2, 0, 0)
	Stations.truss(g, 'Arm', armCf, a0 - a1, AW, AW, frame, groove, 1.5, { '-x', '+x', '+z', '-z' }, fm)
	-- Diagonal brace: from 2.7 below the arm on the post's aisle face out to the arm 3.3 from the post.
	local b0, b1 = V(0, A0 - 2.7, pz - W / 2 + 0.1), V(0, A0 + 0.1, pz - 3.3)
	g:bar('Brace', b0, b1, 0.7, frame, fm)
	g:bar('BraceGroove', b0 + V(0.36, 0, 0), b1 + V(0.36, 0, 0), 0.12, groove, M.SmoothPlastic)
	g:bar('BraceGroove', b0 - V(0.36, 0, 0), b1 - V(0.36, 0, 0), 0.12, groove, M.SmoothPlastic)
	g:box('HookPlate', V(-0.45, A0 - 0.15, bz - 0.45), V(0.45, A0, bz + 0.45), C(36, 38, 52), M.Metal)
	if t.trim then
		-- The red station's navy gallows carries a red stripe up the post's aisle face and along the arm.
		decor(g:box('PostTrim', V(-0.2, base + 0.2, pz - W / 2 - 0.08), V(0.2, postTop - 0.2, pz - W / 2 - 0.03), t.trim))
		for _, sx in { -1, 1 } do
			decor(g:box('ArmTrim', V(sx * (AW / 2 + 0.03), A0 + AW / 2 - 0.15, a1 + 0.3), V(sx * (AW / 2 + 0.08), A0 + AW / 2 + 0.15, a0 - 0.3), t.trim))
		end
	end
end

-- The barrel bag: a flat-topped capsule of eight-sided sections (three short steps to a flat top at ~2/3 the
-- body width, a straight body between two dark bands standing 0.13 proud, three steps at the bottom), one
-- embossed X per facet per section, hung on one dark strap. Ice is a glassy straight block with chamfered
-- ends, faint bands and a white shine. Everything but the hinge goes in Swing so the client can sway it.
-- Returns the Swing context and a belly slab (for effects that ride the bag).
function Stations.bag(eq, t, tier, x, z)
	local hingeY, top, h = Stations.ARM_Y, Stations.BAG_TOP, Stations.BAG_H
	ghost(eq:part('Hinge', V(0.2, 0.2, 0.2), CFrame.new(x, hingeY, z), P.white))
	local sw = eq:group('Swing')
	sw:box('Strap', V(x - 0.25, top - 0.1, z - 0.12), V(x + 0.25, hingeY + 0.02, z + 0.12), C(30, 28, 44))
	local y = function(f) return top - f * h end
	-- Profile, top to bottom: { from, to (fractions of h), apothem, role } ('band' = the dark rings).
	local profile = t.block and {
		{ 0, 0.05, 1.45, 'cap' }, { 0.05, 0.25, 1.7, 'body' }, { 0.25, 0.32, 1.74, 'band' }, { 0.32, 0.7, 1.7, 'body' },
		{ 0.7, 0.77, 1.74, 'band' }, { 0.77, 0.95, 1.7, 'body' }, { 0.95, 1, 1.45, 'cap' },
	} or {
		{ 0, 0.035, 1.3, 'cap' }, { 0.035, 0.07, 1.55, 'cap' }, { 0.07, 0.11, 1.75, 'cap' }, { 0.11, 0.25, 1.95, 'body' },
		{ 0.25, 0.32, 2.08, 'band' }, { 0.32, 0.7, 1.95, 'body' }, { 0.7, 0.77, 2.08, 'band' }, { 0.77, 0.89, 1.95, 'body' },
		{ 0.89, 0.93, 1.75, 'cap' }, { 0.93, 0.965, 1.5, 'cap' }, { 0.965, 1, 1.2, 'cap' },
	}
	local belly
	for _, s in profile do
		local band = s[4] == 'band'
		local col = band and t.band or t.bag
		local slabs, w = Stations.octagon(sw, band and 'BagBand' or 'Bag', x, z, s[3], y(s[2]), y(s[1]), col, (not band and t.bagMat) or M.SmoothPlastic)
		if s[4] == 'body' then
			for _, p in slabs do Stations.stamp(p, { Enum.NormalId.Front, Enum.NormalId.Back }, w, (s[2] - s[1]) * h, t.stampAlpha) end
			if s[1] == 0.32 then belly = slabs[1] end
		end
	end
	if t.block then
		-- White diagonal shine on two facets of the glassy bag.
		for _, k in { 0, 1 } do
			local face = CFrame.new(x, y(0.5), z) * CFrame.Angles(0, -math.pi / 8 - k * math.pi / 4, 0) * CFrame.new(0, 0, -1.72)
			decor(sw:part('Shine', V(0.15, 2.5, 0.04), face * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255), M.SmoothPlastic)).Transparency = 0.4
		end
	end
	for _, p in sw.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			decor(p).CastShadow = true
			if p.Name:sub(1, 3) == 'Bag' then
				if t.bagTransparency then p.Transparency = t.bagTransparency end
				if t.bagReflectance then p.Reflectance = t.bagReflectance end
			end
		end
	end
	return sw, belly
end

-- The ring the mat sits in: a lower band (its outer faces stamped with a row of X's) under a lighter studded
-- lip (a glowing neon lip on toxic), both with two-step pixel corners.
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
			if top and not material then studs(p) elseif not top and b[3] then Stations.stamp(p, { b[3] }, (y1 - y0) * 2.4, y1 - y0) end
		end
	end
	ring('RimBase', 0, 0.45, 0, t.rim, false)
	ring('Rim', 0.45, Stations.RIM_Y, 0.12, t.rimTop, true, t.rimTopMat)
end

-- Gold nuggets like the reference's: a low lump with sides sloping 45 degrees down to the sand (a core box
-- with a wedge on each side) and a smaller raised lump on top, deep yellow against the pale mat.
function Stations.nugget(c, x, z, s, turn)
	local Y, col = Stations.MAT_Y, C(255, 212, 0)
	local cf = CFrame.new(x, Y, z) * CFrame.Angles(0, turn or 0, 0)
	local function lump(at, w, h, d, slope)
		local p = c:part('Nugget', V(w, h, d), at * CFrame.new(0, h / 2, 0), col)
		p.Reflectance = 0.15
		-- Four wedges, each sloping from the lump's top edge down to its foot (`slope` wide).
		for k = 0, 3 do
			local len = (k % 2 == 0) and w or d
			local out = (k % 2 == 0) and d / 2 or w / 2
			local wcf = at * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h / 2, -(out + slope / 2))
			c:wedge('NuggetSlope', V(len, h, slope), wcf, col).Reflectance = 0.15
		end
	end
	lump(cf, 1.6 * s, 0.55 * s, 1.3 * s, 0.5 * s)
	lump(cf * CFrame.new(0.25 * s, 0.55 * s, -0.15 * s), 1.0 * s, 0.4 * s, 0.8 * s, 0.35 * s)
end

-- Floating labels over the bag (the reference's three rows): the Power chip, Unlocked/Locked and the big
-- "xN Power". The client rewrites Detail; all three rows show at every distance, like the reference.
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
	text('Detail', open and 'Unlocked' or 'Locked', open and C(20, 235, 70) or C(235, 25, 50), 0.1, 0.28, 0.8, 0.27, 3)
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

	-- Base: the rim, the flat inset mat, a thin neon line inside the rim on shadow.
	Stations.rim(st, t)
	local Y, MX, MZ = Stations.MAT_Y, Stations.HALF_X - 1, Stations.HALF_Z - 1
	local mat = st:box('Mat', V(-MX, 0, -MZ), V(MX, Y, MZ), t.mat, t.matMat or M.Plastic)
	if mat.Material == M.Plastic then studs(mat) end
	if t.edge then
		for _, b in { { V(-MX, Y, -MZ), V(MX, Y + 0.14, -MZ + 0.08) }, { V(-MX, Y, MZ - 0.08), V(MX, Y + 0.14, MZ) }, { V(-MX, Y, -MZ), V(-MX + 0.08, Y + 0.14, MZ) }, { V(MX - 0.08, Y, -MZ), V(MX, Y + 0.14, MZ) } } do
			decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.Neon)).CastShadow = false
		end
	end
	if t.name == 'gold' then
		-- Four flat nuggets like the reference: one under the bag, two at the front corner, one front-centre.
		local d = st:group('Nuggets')
		Stations.nugget(d, 0.3, Stations.BAG_Z + 0.3, 1.25, 0.3)
		Stations.nugget(d, 1.3, -6.3, 1.15, 1.2)
		Stations.nugget(d, -1.5, -7.7, 1.05, 2.1)
		Stations.nugget(d, -1.0, -3.1, 1.1, 0.7)
	end
	-- Where the player stands to train: the whole mat (its top is the floor you stand on).
	local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -MZ), V(MX, Y, MZ), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false

	-- Equipment: the gallows and the bag (only Swing sways).
	local eq = st:group('Equipment')
	Stations.gallows(eq:group('Gallows'), t, tier)
	local _, belly = Stations.bag(eq, t, tier, 0, Stations.BAG_Z)

	-- Labels one and a half studs over the post top, above the bag.
	Stations.labels(st, s, t, V(0, Y + 14.7, Stations.BAG_Z))

	model:SetAttribute('Tier', tier)
	model:SetAttribute('HitPoint', st:world(CFrame.new(0, Stations.HIT_Y, Stations.BAG_Z - 1.95)).Position)
	model:SetAttribute('HitColor', t.glow)
	if opts.vfx ~= false and VFX then
		if VFX.theme then
			VFX.theme(mat, t.name, V(2 * MX, 12, 2 * MZ), { parent = model, tier = tier, color = t.glow, bag = belly })
		else
			VFX.station(mat, tier, t.glow, V(2 * MX, 12, 2 * MZ), { parent = model })
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- armory
-- The ARMORY: the gun ladder on hexagonal pedestals, two rows like a tool shop. Guns 1-5 stand in the front
-- row on the floor, 6-10 on a raised studded step behind, under an ARMORY sign. Each pedestal glows in its
-- state colour (pink locked, blue owned, green equipped; Armory.client repaints them), has a LOCKED / OWNED /
-- EQUIPPED strip on its front, the gun floating and turning above it, and a billboard with the name, the
-- multiplier and the price.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun with attributes GunId, Tier,
-- Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part in front of the pedestal: prompt anchor and buy-distance point
--   StateTop/StateGlow the coloured top (parts, several each), StateStrip (part) with SurfaceGui > TextLabel State
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Spin, Bob) with the gun inside
-- Local frame: origin at the centre front of the display on the ground, front faces -Z (players stand at -Z
-- looking +Z), footprint x -24..24, z -2..18, at most 16 tall.
local Armory = {}

Armory.Floor = 0.4 -- floor plate top
Armory.Step = 4.4 -- back platform top: four 1-stud steps up from the floor
Armory.StepDepth = 0.9
Armory.Rows = { { z = 3.4, y = 0.4 }, { z = 14, y = 4.4 } }
Armory.Spacing = 9.4
Armory.Radius = 3 -- pedestal apothem (centre to a flat side)
Armory.Spin, Armory.Bob = 40, 0.3

-- Optional modules made by other builders (Shared.HoodVFX, Shared.Models.GunModels / IconModels): nil when
-- they are not there yet or fail to load.
function Armory.optional(name)
	local shared = ReplicatedStorage:FindFirstChild('Shared')
	local models = shared and shared:FindFirstChild('Models')
	local m = shared and (shared:FindFirstChild(name) or (models and models:FindFirstChild(name)))
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end

-- Hexagonal plinth: three boxes turned 60 degrees apart (flat sides face +-Z), each width 2r*tan(30).
function Armory.hex(c, name, x, z, r, y0, y1, color, material)
	local w = 2 * r * math.tan(math.pi / 6)
	local parts = {}
	for k = 0, 2 do
		table.insert(parts, c:part(name, V(w, y1 - y0, 2 * r), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 3, 0), color, material))
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
-- muzzle toward -Z, up +Y; a pistol is about 1.6 long). Longer guns get a stock; the colour runs down a stripe.
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
	add('Stripe', V(0.36, 0.12, len * 0.7), CFrame.new(0, 0.38, front / 2 + 0.2), gun.Color, M.Neon)
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

-- The display gun: GunModels.build when it exists (else the stand-in), scaled up for the pedestal. Small guns
-- are blown up more than big ones (display size ~ natural size^0.55) so a pistol still reads from the street
-- while the long guns stay longer, and each tier gets 3% more on top, up to 6.6 studs.
function Armory.gun(gun)
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
	local length = math.min(6.6, 2.9 * longest ^ 0.55 * (1 + 0.03 * (gun.Tier - 1)))
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- Effects that grow with tier (`part` is a box round the gun, which sizes them). HoodVFX.item when the VFX
-- module is there; otherwise a light from tier 2,
-- sparkles from tier 3, rising glow from tier 6 and big star glints for the last two.
function Armory.effects(part, tier, color)
	if tier < 2 then return end -- the free pistol stays plain, like the basic tool in the reference
	local vfx = Armory.optional('HoodVFX')
	if vfx and vfx.item then
		local ok = pcall(vfx.item, part, tier, color)
		if ok then return end
	end
	light(part, color, 0.5 + tier * 0.12, 7 + tier * 0.4)
	local function emitter(name, texture, rate, life, speed, size, transparency)
		local e = Instance.new('ParticleEmitter')
		e.Name = name
		e.Texture = texture
		e.Rate = rate
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Speed = NumberRange.new(speed[1], speed[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = size
		e.Transparency = transparency
		e.Color = ColorSequence.new(color:Lerp(P.white, 0.35), color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = part
		return e
	end
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	if tier >= 3 then
		emitter('Sparkles', 'rbxasset://textures/particles/sparkles_main.dds', 2 + tier * 1.5, { 0.8, 1.5 }, { 0.4, 1.4 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 + tier * 0.03), NumberSequenceKeypoint.new(1, 0) }), fade)
	end
	if tier >= 6 then
		local glow = emitter('Glow', 'rbxasset://textures/particles/fire_main.dds', 3 + tier, { 0.9, 1.6 }, { 0.6, 1.4 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 + tier * 0.06), NumberSequenceKeypoint.new(1, 0.1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }))
		glow.EmissionDirection = Enum.NormalId.Top
		glow.SpreadAngle = Vector2.new(25, 25)
		glow.Acceleration = V(0, 1.5, 0)
	end
	if tier >= 9 then
		local star = emitter('Glints', 'rbxasset://textures/particles/sparkles_main.dds', 3, { 1.2, 2 }, { 0.2, 0.6 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) }),
			NumberSequence.new(0.1))
		star:SetAttribute('PreviewTexture', 'star')
	end
end

-- The floating label: name in the gun's colour, the multiplier and the price, each row with an icon
-- (IconModels.Images when uploaded, else a text glyph kept in the label's Glyph attribute).
-- Labels show only within 30 studs: from the walkway the wall reads clean, they appear as you step on the deck.
function Armory.label(c, pos, gun)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	g.Size = UDim2.fromScale(8, 2.9)
	g.MaxDistance = 30
	g.LightInfluence = 0
	g.Parent = anchor
	line(g, 'Name', gun.Name, gun.Color:Lerp(P.white, 0.15), FONT.loud, 0, 0.44, C(24, 22, 40), 3)
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.loud, y, 0.28, C(24, 22, 40), 2.5)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.14, y)
			i.Size = UDim2.fromScale(0.12, 0.28)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.28, y)
			t.Size = UDim2.fromScale(0.6, 0.28)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local a = Instance.new('UIAspectRatioConstraint')
			a.Parent = i
			i.Parent = g
			t:SetAttribute('Glyph', '')
		else
			t.Text = glyph .. ' ' .. text
			t:SetAttribute('Glyph', glyph)
		end
		return t
	end
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier .. ' POWER', P.white, 0.45)
	row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), C(255, 228, 92), 0.73)
	return anchor
end

-- One gun on its pedestal. (x, z) is the pedestal centre, y the floor it stands on.
function Armory.slot(c, gun, x, z, y, colors)
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local r = Armory.Radius
	-- Pale base, the coloured top with a lighter glowing inlay, a dark rim under the top.
	Armory.hex(s, 'PedestalBase', x, z, r, y, y + 0.6, C(232, 234, 242), M.SmoothPlastic)
	Armory.hex(s, 'PedestalRim', x, z, r - 0.12, y + 0.6, y + 0.7, C(70, 72, 92), M.SmoothPlastic)
	Armory.hex(s, 'StateTop', x, z, r - 0.3, y + 0.7, y + 1.0, look.Top, M.SmoothPlastic)
	local glow = Armory.hex(s, 'StateGlow', x, z, r - 0.95, y + 1.0, y + 1.05, look.Glow, M.Neon)
	for _, p in glow do decor(p).CastShadow = false end
	light(glow[1], look.Top, 1.4, 9)
	-- Soft haze rising off the top in the state colour (the client recolours it with the pedestal).
	local hazeSource = ghost(s:part('StateHazeSource', V(r * 1.3, 0.2, r * 1.3), CFrame.new(x, y + 1.15, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 5
	haze.Lifetime = NumberRange.new(1.2, 1.8)
	haze.Speed = NumberRange.new(0.8, 1.4)
	haze.SpreadAngle = Vector2.new(8, 8)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 2.6) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.78), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	local top = y + 1.05
	-- Front strip with the state word.
	local strip = s:box('StateStrip', V(x - 1.55, y + 0.08, z - r - 0.08), V(x + 1.55, y + 0.52, z - r + 0.02), look.Strip, M.SmoothPlastic)
	local sg = surface(strip, Enum.NormalId.Front, 50)
	sg.Name = 'StateGui'
	line(sg, 'State', string.upper(state), P.white, FONT.loud, 0.08, 0.84, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun, floating side-on (muzzle to the viewer's right), slowly turning and bobbing.
	local d, display = s:group('Display')
	local g = Armory.gun(gun)
	local pivot = Armory.pivotOf(g)
	local lo, hi = Armory.extents(g, pivot)
	local mid = (lo + hi) / 2
	local length = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
	local centre = V(x, top + 1.0 + (hi.Y - lo.Y) / 2, z)
	local pose = CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(8), 0, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:SetAttribute('Spin', Armory.Spin)
	display:SetAttribute('Bob', Armory.Bob)
	display:SetAttribute('BobPeriod', 2.4)
	display:AddTag('HoodMotion')
	local core = ghost(s:part('FxCore', V(length * 0.55, length * 0.32, length * 0.55), CFrame.new(centre), gun.Color))
	core.CastShadow = false
	Armory.effects(core, gun.Tier, gun.Color)
	local labelY = centre.Y + (hi.Y - lo.Y) / 2 + 1.7
	Armory.label(s, V(x, labelY, z), gun)
	-- Where the prompt sits and the server measures buying distance from.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.5, top + 0.6, z - r - 1.1), V(x + 0.5, top + 1.6, z - r - 0.1), P.white))
	point.CastShadow = false
	return model
end

-- The counter banner: a red studded frame on two posts, a gold board with one line of red text (the lobby's
-- ARMORY mural on the wall above carries the name).
function Armory.header(c, y)
	local h = c:group('ArmorySign')
	local post = C(150, 156, 172)
	for _, x in { -14.1, 14.1 } do
		studs(h:box('SignPost', V(x - 0.8, y, 16.8), V(x + 0.8, 12.8, 18.2), post, M.Plastic), true)
		h:box('SignFoot', V(x - 1.3, y, 16.3), V(x + 1.3, y + 0.8, 18.6), post:Lerp(P.black, 0.25), M.Plastic)
	end
	studs(h:box('SignFrame', V(-16, 12.6, 16.9), V(16, 15.5, 18.1), C(222, 52, 52), M.Plastic))
	studs(h:box('SignCap', V(-16.4, 15.5, 16.8), V(16.4, 16, 18.2), C(250, 206, 52), M.Plastic))
	local board = h:box('SignBoard', V(-15.3, 12.85, 16.7), V(15.3, 15.3, 17), C(250, 206, 52), M.SmoothPlastic)
	local g = surface(board, Enum.NormalId.Front, 20)
	-- What a gun does, in one line.
	line(g, 'Subtitle', 'BETTER GUN = MORE POWER PER PUNCH', C(120, 20, 20), FONT.loud, 0.2, 0.6, C(255, 240, 200), 2)
	for _, x in { -16.2, 16.2 } do
		decor(h:box('SignLamp', V(x - 0.25, 12.8, 16.6), V(x + 0.25, 15.3, 16.9), C(255, 120, 200), M.Neon)).CastShadow = false
	end
	return h
end

-- The floor, the steps up to the back row and the back platform, all studded.
function Armory.base(c)
	local b = c:group('ArmoryBase')
	local floor, stepColor, edge = C(214, 218, 228), C(196, 201, 214), C(150, 156, 172)
	studs(b:box('ArmoryFloor', V(-24, 0, -2), V(24, Armory.Floor, 12), floor, M.Plastic))
	studs(b:box('ArmoryKerb', V(-24, 0, -2), V(24, Armory.Floor + 0.12, -1.2), edge, M.Plastic))
	local rises = math.round(Armory.Step - Armory.Floor)
	local z0 = Armory.Rows[2].z - Armory.Radius - 0.8 - (rises - 1) * Armory.StepDepth
	for i = 1, rises - 1 do
		local z = z0 + (i - 1) * Armory.StepDepth
		studs(b:box('ArmoryStep', V(-24, 0, z), V(24, Armory.Floor + i, z + Armory.StepDepth), i % 2 == 1 and stepColor or floor, M.Plastic), true)
		-- A thin pink neon line under each step nose: reads as a display, and shows the edge at night.
		decor(b:box('StepGlow', V(-24, Armory.Floor + i - 0.16, z - 0.04), V(24, Armory.Floor + i - 0.06, z), C(255, 120, 200), M.Neon)).CastShadow = false
	end
	local zp = z0 + (rises - 1) * Armory.StepDepth
	studs(b:box('ArmoryPlatform', V(-24, 0, zp), V(24, Armory.Step, 18), floor, M.Plastic), true)
	-- Colour on the deck: a red runner with gold edges from the walkway to the front row, a pink rubber strip
	-- under each row of pedestals.
	local front = Armory.Rows[1].z - Armory.Radius - 0.3
	b:box('ArmoryRunner', V(-5, Armory.Floor, -2), V(5, Armory.Floor + 0.05, front), C(222, 44, 52), M.Fabric)
	for _, x in { -5.4, 5 } do decor(b:box('ArmoryRunnerEdge', V(x, Armory.Floor, -2), V(x + 0.4, Armory.Floor + 0.07, front), C(255, 204, 48), M.SmoothPlastic)) end
	for _, row in Armory.Rows do
		decor(b:box('ArmoryStrip', V(-23.6, row.y, row.z - 1.5), V(23.6, row.y + 0.04, row.z + 1.5), C(255, 120, 200), M.Fabric))
	end
	decor(b:box('StepGlow', V(-24, Armory.Step - 0.16, zp - 0.04), V(24, Armory.Step - 0.06, zp), C(255, 120, 200), M.Neon)).CastShadow = false
	return b
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local colors = require(ReplicatedStorage.Shared.GunRules).Colors
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.base(a)
	Armory.header(a, Armory.Step)
	for i, gun in guns do
		local row = Armory.Rows[(i - 1) // 5 + 1]
		if not row then break end
		local col = (i - 1) % 5
		-- Gun 1 stands on the viewer's left: their left is +X when they look toward +Z.
		Armory.slot(a, gun, 2 * Armory.Spacing - col * Armory.Spacing, row.z, row.y, colors)
	end
	return model
end
---------------------------------------------------------------------------------------------- treadmills
-- SPEED treadmills after the reference's treadmills (ref_16 "x1 Aura" / "x2" / "x6", ref_15 x999): a pale studded
-- plinth, a navy deck, a belt of solid white V's on a dark striped field, slim studded side rails, a tilted
-- glowing screen with faint LCD text, handrails ending in chunky grips, a veil of mist on the belt, and one
-- floating line "x1 Speed" (the price chip and "Locked" over it only while it is locked).
-- Each tier has its own machine, like the reference's ladder (one screen on x1, two on x2..x18, three on x999):
--   Jog     steel and navy, one cyan screen on two uprights leaning back (the reference's x1)
--   Run     the x2: the Jog's steel body with glowing lemon rails, lemon grips, two yellow screens, warm mist
--   Sprint  the black x999 gate: a thick studded black deck with a white neon tube down each side, two square
--           posts and a header beam framing a bank of three pale screens, white neon strips up the posts, a crown
--           of two chunky black horns round a pale gable with a glowing diamond, white neon "ladder" grips, a
--           plain black belt with two big V's, grey smoke with white curls, magenta glints and speed streaks
-- Local frame: origin on the floor at the middle, footprint x -3.5..3.5, z -7..7, parts up to y ~10.9 (the
-- Sprint horns lean out past x 3.5 above the header, like the reference's), labels float above. The runner stands on the belt
-- facing +Z, toward the screen; walk on from -Z.
-- Contract (TreadmillService, Treadmill.client): Treadmill_<Id> > TreadmillZone (invisible, the belt's top),
-- Belt (the walking surface; attributes describe the scrolling pattern), Slat / Chevron parts (attributes Z0,
-- Side) that the client scrolls, Screen (SurfaceGui with TextLabels Title and Detail; ScreenSide panels beside
-- it on Run and Sprint), Sign (BillboardGui Label with Chip, Cost, Detail, Speed; Config/Treadmills.layoutLabel
-- switches it), emitter BeltMist (attribute BaseRate), PointLight ScreenLight; attributes Tier, TreadmillId,
-- Multiplier, Required; tag HoodTreadmill.
local Treadmills = {}

-- Per tier: frame/frameDark (rails, uprights; rail sides), baseRim (the plinth's edge), deck (under the belt,
-- the caps), slat/gap (belt stripes and the belt between them), screen/screenText/bezel and how many panels,
-- grip/bar (handrails), mist (belt veil from/to), edge (floor haze), rail (a glowing rail cap instead of the
-- studded steel one), tube (neon on the deck), rearY (belt height at the back: Sprint stands on a thick deck).
Treadmills.Looks = {
	{ name = 'steel', frame = C(172, 190, 220), frameDark = C(92, 108, 138), baseRim = C(138, 154, 182), deck = C(22, 36, 68),
		slat = C(20, 32, 62), gap = C(118, 138, 176), screen = C(30, 225, 245), screenText = C(10, 120, 140), bezel = C(24, 120, 150),
		panels = 1, grip = C(45, 125, 210), bar = C(26, 40, 70), mist = { C(214, 232, 255), C(150, 195, 255) }, edge = C(165, 190, 235), rearY = 0.8 },
	{ name = 'lemon', frame = C(172, 190, 220), frameDark = C(92, 108, 138), baseRim = C(138, 154, 182), deck = C(22, 36, 68),
		slat = C(20, 32, 62), gap = C(118, 138, 176), screen = C(255, 232, 40), screenText = C(150, 120, 0), bezel = C(26, 40, 70),
		panels = 2, grip = C(255, 214, 40), bar = C(26, 40, 70), mist = { C(255, 246, 220), C(255, 222, 150) }, edge = C(240, 220, 170),
		rail = C(255, 240, 80), rearY = 0.8 },
	{ name = 'black', frame = C(26, 26, 32), frameDark = C(14, 14, 18), baseRim = C(30, 30, 36), deck = C(16, 16, 22),
		slat = C(18, 18, 24), gap = C(18, 18, 24), screen = C(200, 250, 255), screenText = C(40, 130, 140), bezel = C(18, 18, 24),
		panels = 3, grip = C(245, 245, 255), bar = C(26, 26, 32), mist = { C(235, 235, 245), C(170, 170, 185) }, edge = C(150, 150, 165),
		tube = C(245, 245, 255), rearY = 1.4 },
}
Treadmills.Chevron = C(236, 242, 252)
-- The belt, in the treadmill's frame: from (y rearY, z RearZ) up to (y rearY + Rise, z RearZ + Run).
Treadmills.Belt = { RearZ = -5.8, Run = 10.3, Rise = 0.45 }

-- Until HoodVFX's textures are uploaded, an emitter falls back to a Roblox built-in (a soft smoke blob or a
-- sparkle), which can't draw curls or a thin veil. Like HoodVFX's own FALLBACK_FADE, the stand-in is kept faint
-- (opacity times the fade) or switched off where a blob would read as cotton; `fallback` (props applied only
-- then) tunes a single emitter.
Treadmills.FallbackFade = { wisp = 0, mist = 0.5 }

-- An emitter with a Roblox built-in texture (or HoodVFX's uploaded one, with its flipbook, when it has it),
-- named for the offline previewer. Acceleration comes in `frame`'s axes and is turned into world space here.
function Treadmills.emitter(parent, name, tex, frame, props, fallback)
	local builtin = { mist = 'rbxasset://textures/particles/smoke_main.dds', aura = 'rbxasset://textures/particles/smoke_main.dds',
		wisp = 'rbxasset://textures/particles/smoke_main.dds', glitter = 'rbxasset://textures/particles/sparkles_main.dds',
		streak = 'rbxasset://textures/particles/sparkles_main.dds', softglow = 'rbxasset://textures/glow.png' }
	local flip = { aura = { Enum.ParticleFlipbookLayout.Grid2x2, Enum.ParticleFlipbookMode.Loop, NumberRange.new(0), true },
		wisp = { Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookMode.OneShot } }
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	local ok, VFX = pcall(function() return require(ReplicatedStorage.Shared.HoodVFX) end)
	local uploaded = ok and type(VFX) == 'table' and VFX.Textures and VFX.Textures[tex]
	uploaded = type(uploaded) == 'string' and uploaded ~= '' and uploaded
	e.Texture = uploaded or builtin[tex]
	if uploaded and flip[tex] then
		local f = flip[tex]
		e.FlipbookLayout, e.FlipbookMode = f[1], f[2]
		if f[3] then e.FlipbookFramerate, e.FlipbookStartRandom = f[3], f[4] end
	end
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do
		if k == 'Acceleration' then v = frame:VectorToWorldSpace(v) end
		e[k] = v
	end
	if not uploaded then
		for k, v in fallback or {} do e[k] = v end
		local f = Treadmills.FallbackFade[tex]
		if f == 0 then
			e.Enabled = false -- no built-in looks like it: better nothing than a white cumulus
		elseif f then
			local kps = {}
			for _, kp in e.Transparency.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * f, kp.Envelope * f)) end
			e.Transparency = NumberSequence.new(kps)
		end
	end
	e:SetAttribute('PreviewTexture', tex)
	e.Parent = parent
	return e
end
function Treadmills.seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end

-- The floating label, in the bag stations' inks (FredokaOne, dark outline): "x1 Speed" in the near-white tier
-- tint, plus a see-through chip with the price (FREE / 💪 150) and "Locked" while it is locked
-- (Config/Treadmills.layoutLabel; Treadmill.client switches it per player). `bottom` is the label's bottom edge.
function Treadmills.labels(tm, row, bottom, cfg)
	local sign = ghost(tm:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(bottom), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
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
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.Position, chip.Size = UDim2.fromScale(0.3, 0), UDim2.fromScale(0.4, 0.26)
	chip.BackgroundColor3, chip.BackgroundTransparency = C(20, 22, 34), 0.55
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = chip
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = C(0, 0, 0), 2
	edge.Parent = chip
	chip.Parent = g
	local free = row.Required == 0
	text('Cost', free and 'FREE' or ('💪 ' .. compact(row.Required)), P.white, 0.32, 0.035, 0.36, 0.19, 2)
	text('Detail', free and 'Unlocked' or 'Locked', free and C(20, 235, 70) or C(235, 25, 50), 0.14, 0.29, 0.72, 0.21, 3)
	text('Speed', 'x' .. row.Multiplier .. ' Speed', row.Label or row.Color, 0, 0.52, 1, 0.46, 3)
	cfg.layoutLabel(g, not free)
	return sign
end

-- A glowing screen panel with faint LCD text (Title, and Detail on the main one).
function Treadmills.panel(tm, name, size, cf, k, row, detail)
	local p = decor(tm:part(name, size, cf, k.screen, M.Neon))
	p.CastShadow = false
	local sg = surface(p, Enum.NormalId.Front, 40)
	local wide = size.X > 3
	local title = line(sg, 'Title', 'x' .. row.Multiplier .. (wide and ' SPEED' or '\nSPEED'), k.screenText, FONT.loud, wide and 0.16 or 0.14, wide and 0.32 or 0.5)
	title.TextTransparency = 0.5
	if detail then
		local d = line(sg, 'Detail', row.Required == 0 and 'FREE' or compact(row.Required) .. ' POWER', k.screenText, FONT.loud, wide and 0.6 or 0.7, 0.2)
		d.TextTransparency = 0.5
	end
	return p
end

-- Build treadmill `id` (a Config/Treadmills id) in ctx (frame above). opts.vfx = false skips the effects;
-- opts.variant picks the props (default: from where it stands, so neighbours differ).
function Treadmills.build(ctx, id, opts)
	opts = opts or {}
	local cfg = require(ReplicatedStorage.Shared.Config.Treadmills)
	local row = assert(cfg.ById[id], 'unknown treadmill ' .. tostring(id))
	local tier = math.clamp(opts.tier or row.Tier, 1, 3)
	local k = Treadmills.Looks[tier]
	local black = tier == 3
	local tm, model = ctx:group('Treadmill_' .. id)
	local at = ctx:world(CFrame.new()).Position
	local variant = opts.variant or (math.floor(at.X / 3) * 7 + math.floor(at.Z / 3) * 13) % 6

	-- Plinth: one pale slab (a slightly darker rim under a studded top), a hazard strip on the step-on lip.
	studs(tm:box('BaseRim', V(-3.5, 0, -7), V(3.5, 0.22, 7), k.baseRim))
	studs(tm:box('Base', V(-3.32, 0.22, -6.82), V(3.32, 0.42, 6.82), k.frame))
	decor(tm:box('Hazard', V(-3.1, 0.42, -6.78), V(3.1, 0.46, -6.48), C(250, 204, 40)))
	for i = 0, 7 do
		decor(tm:part('HazardStripe', V(0.18, 0.05, 0.38), CFrame.new(-2.8 + i * 0.8, 0.445, -6.63) * CFrame.Angles(0, math.rad(40), 0), C(30, 30, 34)))
	end

	-- Belt frame: origin on the middle of the belt's top face, +Z up the gentle incline toward the screen.
	local B = Treadmills.Belt
	local rearY = k.rearY
	local incline = math.atan2(B.Rise, B.Run)
	local L = math.sqrt(B.Run * B.Run + B.Rise * B.Rise)
	local b = tm:at(CFrame.new(0, rearY + B.Rise / 2, B.RearZ + B.Run / 2) * CFrame.Angles(-incline, 0, 0))
	local pat = cfg.patternFor and cfg.patternFor(tier) or cfg.Pattern
	local hw, sp = pat.HalfWidth, pat.Spacing
	local pieceLen = sp + 0.01 -- a hair longer than the spacing, so neighbouring pieces overlap with no seam
	-- The deck reaches down to the floor everywhere; Sprint's is a thick studded black block.
	local deck = b:box('Deck', V(-3.1, -(rearY + B.Rise), -L / 2 - 0.7), V(3.1, -0.26, L / 2 + 0.4), k.deck)
	if black then studs(deck, true) end
	local belt = b:box('Belt', V(-hw, -0.26, -L / 2), V(hw, 0, L / 2), k.gap)
	-- Dark slats across the belt; each carries two white chevron pieces as long as the slat spacing, so a V is one
	-- solid white field (the client scrolls them all; every other slat's pieces sit 0.002 higher, so overlapping
	-- neighbours never flicker). They run from under the rear cap to under the front cap, so the ones that hop
	-- are always hidden.
	local slatY, chevY, hideY = 0.02, 0.03, -0.13
	local n = math.ceil((L - 0.24) / sp) + 1
	local first, last = -L / 2 - 0.1, -L / 2 - 0.1 + (n - 1) * sp
	for j = 0, n - 1 do
		local z0 = first + j * sp
		local slat = decor(b:part('Slat', V(2 * hw, 0.04, pat.Depth), CFrame.new(0, slatY, z0), k.slat))
		slat.CastShadow = false
		slat:SetAttribute('Z0', z0)
		local x, w = cfg.chevron(z0, pat)
		local lift = (j % 2) * 0.002
		for _, side in { -1, 1 } do
			local cf = x and CFrame.new(side * x, chevY + lift, z0) or CFrame.new(side, hideY, z0)
			local piece = decor(b:part('Chevron', V(w or 1, 0.04, pieceLen), cf, Treadmills.Chevron, M.Plastic))
			piece.CastShadow = false
			piece:SetAttribute('Z0', z0)
			piece:SetAttribute('Side', side)
			piece:SetAttribute('Lift', lift)
		end
	end
	for key, v in { SlatSpacing = sp, SlatY = slatY + 0.13, ChevronY = chevY + 0.13, HideY = hideY + 0.13, ScrollSpeed = cfg.Scroll[tier],
		ChevronPeriod = pat.Period, ChevronStroke = pat.Stroke, ChevronSlope = pat.Slope, HalfWidth = hw } do
		belt:SetAttribute(key, v) -- Y values are from the Belt part's centre (its top is 0.13 above it)
	end
	-- Where the runner stands: the belt's top, between the end caps.
	local zone = b:box('TreadmillZone', V(-hw, -0.06, -L / 2 + 0.2), V(hw, 0, L / 2 - 0.55), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
	-- Roller caps at both ends, low like the reference. A piece reaches half a spacing either side of its slat: the
	-- rear cap covers the first slat's piece even after it rolls a whole spacing back, the front cap begins where
	-- the last slat's piece begins (so the slat that hops in is hidden and the belt never shows a gap).
	b:box('RearCap', V(-hw, -0.4, first - sp - pieceLen / 2 - 0.05), V(hw, 0.1, first + pieceLen / 2), k.deck)
	b:box('FrontCap', V(-hw, -0.4, last - pieceLen / 2), V(hw, 0.1, L / 2 + 0.35), k.deck)
	b:rod('RearRoller', 0.3, 2 * hw + 0.1, CFrame.new(0, -0.25, -L / 2 - 0.72), k.frameDark, M.Metal)

	-- Slim side rails: a studded cap on a darker body, 0.35 above the belt; on Run the cap glows lemon (the x2).
	for _, sx in { -1, 1 } do
		b:box('RailBody', V(sx * hw, -0.15, -L / 2 - 0.7), V(sx * 3.1, 0.15, L / 2 + 0.4), k.frameDark)
		local cap = b:box('Rail', V(sx * hw, 0.15, -L / 2 - 0.7), V(sx * 3.1, 0.35, L / 2 + 0.4), k.rail or k.frame, k.rail and M.Neon or nil)
		if not k.rail then studs(cap) end
		if black then
			-- The x999's long white neon tube down the middle of each deck side.
			local faceY = (-0.15 + (0.42 - rearY - B.Rise / 2)) / 2
			decor(b:part('DeckTube', V(0.3, 0.3, 8.5), CFrame.new(sx * 3.2, faceY, 0), k.tube, M.Neon)).CastShadow = false
		end
	end

	local screen, screenTop
	if not black then
		-- Jog / Run: a tilted screen on two uprights rising from the rails' front ends and leaning back.
		local tilt = CFrame.new(0, 6.0, 3.9) * CFrame.Angles(math.rad(25), 0, 0)
		local foot, topY, topZ = 4.75, 6.0, 3.9
		for _, sx in { -1, 1 } do
			local x = sx * 2.85
			tm:bar('Upright', V(x, 1.5, foot), V(x, topY + 0.3, topZ - 0.05), 0.45, k.frame, M.SmoothPlastic)
			-- Handrail back toward the runner, about 0.9 below the screen, ending in a chunky grip.
			tm:bar('Handrail', V(x, 4.05, 4.28), V(x, 4.0, 2.75), 0.3, k.bar, M.SmoothPlastic)
			tm:box('Grip', V(x - 0.35, 3.76, 2.05), V(x + 0.35, 4.26, 2.95), k.grip, M.SmoothPlastic)
		end
		tm:part('ScreenFrame', V(5.3, 2.16, 0.3), tilt, k.frame)
		tm:part('ScreenBezel', V(5.24, 2.1, 0.06), tilt * CFrame.new(0, 0, -0.17), k.bezel)
		if k.panels == 1 then
			screen = Treadmills.panel(tm, 'Screen', V(5.0, 1.9, 0.06), tilt * CFrame.new(0, 0, -0.2), k, row, true)
		else
			-- Two panels with a bezel seam between them, like the reference's x2..x18.
			screen = Treadmills.panel(tm, 'Screen', V(2.45, 1.9, 0.06), tilt * CFrame.new(-1.275, 0, -0.2), k, row, true)
			Treadmills.panel(tm, 'ScreenSide', V(2.45, 1.9, 0.06), tilt * CFrame.new(1.275, 0, -0.2), k, row, false)
		end
		decor(tm:part('ScreenLed', V(0.18, 0.18, 0.06), tilt * CFrame.new(0, -1.02, -0.2), C(255, 70, 110), M.Neon)).CastShadow = false
		screenTop = 7.05
	else
		-- Sprint: the x999 gate. Two square posts and a header beam as wide as the plinth frame a bank of three
		-- pale screens; white neon strips run up the posts' inner front edges.
		for _, sx in { -1, 1 } do
			tm:box('Post', V(sx * 2.65, 0.42, 4.6), V(sx * 3.45, 7.6, 5.4), k.frame)
			decor(tm:part('PostNeon', V(0.15, 6.6, 0.15), CFrame.new(sx * 2.62, 4.1, 4.57), k.tube, M.Neon)).CastShadow = false
			-- Handrails start at the posts and end in the x999's white neon "ladder" (three stacked bars).
			tm:bar('Handrail', V(sx * 3.05, 4.65, 4.6), V(sx * 3.05, 4.6, 2.75), 0.3, k.bar, M.SmoothPlastic)
			for i = 0, 2 do
				decor(tm:part('Ladder', V(0.8, 0.2, 0.5), CFrame.new(sx * 3.05, 4.26 + i * 0.34, 2.55), k.grip, M.Neon)).CastShadow = false
			end
		end
		tm:box('Header', V(-3.5, 7.6, 4.55), V(3.5, 8.4, 5.45), k.frame)
		local bank = CFrame.new(0, 6.6, 5.0) * CFrame.Angles(math.rad(10), 0, 0)
		tm:part('ScreenFrame', V(5.3, 1.9, 0.3), bank, k.bezel)
		for i, px in { -1.77, 0, 1.77 } do
			local p = Treadmills.panel(tm, i == 2 and 'Screen' or 'ScreenSide', V(1.65, 1.5, 0.06), bank * CFrame.new(px, 0, -0.17), k, row, i == 2)
			if i == 2 then screen = p end
		end
		decor(tm:part('ScreenLed', V(0.16, 0.16, 0.06), bank * CFrame.new(0, -0.86, -0.17), C(255, 70, 110), M.Neon)).CastShadow = false
		-- Crown: two chunky plain black horns on the header's ends leaning out past the frame, a pale gable "^"
		-- between them and a glowing diamond inside it.
		for _, sx in { -1, 1 } do
			local base = CFrame.new(sx * 2.85, 8.4, 5.0) * CFrame.Angles(0, 0, -sx * math.rad(20))
			tm:part('Horn', V(1.3, 2.6, 0.9), base * CFrame.new(0, 1.3, 0), k.frame)
			tm:bar('Gable', V(sx * 2.0, 8.45, 5.0), V(0, 10.0, 5.0), 0.45, C(205, 210, 222), M.SmoothPlastic)
		end
		decor(tm:part('Diamond', V(1.1, 1.1, 0.5), CFrame.new(0, 9.2, 4.9) * CFrame.Angles(0, 0, math.pi / 4), k.tube, M.Neon)).CastShadow = false
		screenTop = 11.05
	end
	light(screen, k.screen, 1.2, 10).Name = 'ScreenLight'

	-- Story props, never the same twice: a towel over one handrail (side and colour from the variant), a
	-- water bottle in a cup on the right upright (Jog and Run).
	if not black then
		if variant % 3 ~= 2 then
			local sx = variant % 2 == 0 and -1 or 1
			local cloth = ({ C(240, 242, 246), C(206, 214, 228), C(150, 196, 240) })[variant % 3 + 1]
			decor(tm:part('Towel', V(0.6, 0.08, 0.6), CFrame.new(sx * 2.85, 4.23, 3.45), cloth, M.Fabric))
			decor(tm:part('Towel', V(0.08, 1.3, 0.6), CFrame.new(sx * 3.06, 3.58, 3.45) * CFrame.Angles(0, 0, sx * math.rad(-4)), cloth, M.Fabric))
			decor(tm:part('TowelStripe', V(0.09, 0.14, 0.61), CFrame.new(sx * 3.09, 3.12, 3.45) * CFrame.Angles(0, 0, sx * math.rad(-4)), row.Color, M.Fabric))
		end
		if tier >= 2 or variant % 3 == 2 then
			decor(tm:post('BottleCup', 0.25, 0.3, V(3.25, 3.2, 4.4), k.bar, M.SmoothPlastic))
			decor(tm:post('Bottle', 0.19, 0.72, V(3.25, 3.32, 4.4), row.Color:Lerp(P.white, 0.4), M.Glass)).Transparency = 0.2
			decor(tm:post('BottleCap', 0.12, 0.16, V(3.25, 4.04, 4.4), P.white, M.SmoothPlastic))
		end
	else
		-- A black towel over the left handrail.
		decor(tm:part('Towel', V(0.6, 0.08, 0.6), CFrame.new(-3.05, 4.83, 3.6), C(40, 40, 46), M.Fabric))
		decor(tm:part('Towel', V(0.08, 1.2, 0.6), CFrame.new(-3.26, 4.23, 3.6) * CFrame.Angles(0, 0, math.rad(4)), C(40, 40, 46), M.Fabric))
	end

	-- The label: its bottom 0.8 stud over the screen (over the crown on Sprint).
	Treadmills.labels(tm, row, V(0, screenTop + (black and 0.35 or 0.8), 4.4), cfg)

	model:SetAttribute('Tier', tier)
	model:SetAttribute('TreadmillId', id)
	model:SetAttribute('Multiplier', row.Multiplier)
	model:SetAttribute('Required', row.Required)
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end) -- the client scrolls it whole
	model:AddTag('HoodTreadmill')

	if opts.vfx ~= false then
		local seq = Treadmills.seq
		local beltWorld = belt.CFrame
		-- A veil of mist lying on the belt (the reference's misty treadmills), drifting back a little.
		local fx = ghost(b:part('MistBelt', V(2 * hw, 0.3, L - 1.2), CFrame.new(0, 0.2, -0.3), P.white))
		-- (Built-in fallback: a third of the rate at half the opacity, so smoke blobs never pile over the V's.)
		local mist = Treadmills.emitter(fx, 'BeltMist', 'mist', beltWorld, {
			Rate = 12, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(60, 60),
			Acceleration = V(0, 0.1, -0.8), Drag = 0.6, RotSpeed = NumberRange.new(-15, 15), ZOffset = -0.5,
			Size = seq({ { 0, 2.5 }, { 1, 4.5 } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.9 }, { 0.7, 0.92 }, { 1, 1 } }),
			Color = ColorSequence.new(k.mist[1], k.mist[2]), LightEmission = 0,
		}, { Rate = 4 })
		mist:SetAttribute('BaseRate', mist.Rate) -- the client doubles this while someone runs
		-- A faint tint on the floor in front of the step-on end (the reference's blue haze round the x1s), not in
		-- the gap between neighbours.
		local edge = ghost(tm:part('MistEdge', V(7, 0.3, 0.6), CFrame.new(0, 0.25, -7.6), P.white))
		Treadmills.emitter(edge, 'EdgeMist', 'aura', CFrame.new(), {
			Rate = 1, Lifetime = NumberRange.new(2.6, 3.6), Speed = NumberRange.new(0.1, 0.3), SpreadAngle = Vector2.new(70, 70),
			Acceleration = V(0, 0.05, 0), Drag = 0.5, RotSpeed = NumberRange.new(-10, 10), ZOffset = -1,
			Size = seq({ { 0, 3 }, { 1, 5 } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.88 }, { 0.7, 0.9 }, { 1, 1 } }),
			Color = ColorSequence.new(k.edge), LightEmission = 0,
		})
		-- The screen's halo behind the shell (Roblox blooms Neon a little; this reads from across the room).
		local halo = Instance.new('Attachment')
		halo.Name = 'Halo'
		halo.CFrame = CFrame.new(0, 0, 0.7)
		halo.Parent = screen
		Treadmills.emitter(halo, 'ScreenGlow', 'softglow', CFrame.new(), {
			Rate = 0.8, Lifetime = NumberRange.new(2.5), Speed = NumberRange.new(0), Rotation = NumberRange.new(0),
			Size = seq({ { 0, 6.4 }, { 1, 6.8 } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.68 }, { 0.6, 0.68 }, { 1, 1 } }),
			Color = ColorSequence.new(k.screen), LightEmission = 1, ZOffset = -1,
		}, {
			-- The built-in glow.png is a harder, wider disc than the softglow sheet: smaller and fainter.
			Size = seq({ { 0, 4.4 }, { 1, 4.7 } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.84 }, { 0.6, 0.84 }, { 1, 1 } }),
		})
		if tier >= 2 then
			Treadmills.emitter(fx, 'Glints', 'glitter', beltWorld, {
				Rate = tier == 2 and 4 or 7, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(30, 30),
				Size = seq({ { 0, 0 }, { 0.3, 0.6, 0.2 }, { 1, 0 } }), Color = ColorSequence.new(P.white, row.Color), LightEmission = 1, Brightness = 2, ZOffset = 1,
			})
		end
		if black then
			-- The x999's smoke: a dark grey body wrapping the machine below the screen bank (the column is a little
			-- wider than the plinth and stops 2 studs short of the bank), white curls rising through it. The bank
			-- and the crown stay clear.
			local column = ghost(tm:part('AuraColumn', V(7.4, 1, 9), CFrame.new(0, 2.0, -1.6), P.white))
			Treadmills.emitter(column, 'Aura', 'aura', CFrame.new(), {
				Rate = 30, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1.2, 1.8), SpreadAngle = Vector2.new(20, 20),
				Acceleration = V(0, 0.1, 0), Drag = 0.4, RotSpeed = NumberRange.new(-20, 20), ZOffset = -1,
				Size = seq({ { 0, 3.5 }, { 1, 5.5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 0.7, 0.66 }, { 1, 1 } }),
				Color = ColorSequence.new(C(110, 110, 122), C(40, 40, 48)), LightEmission = 0,
			})
			Treadmills.emitter(column, 'Wisps', 'wisp', CFrame.new(), {
				Rate = 24, Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(1.6, 2.8), SpreadAngle = Vector2.new(25, 25),
				Acceleration = V(0, 0.8, 0), Drag = 0.6, RotSpeed = NumberRange.new(-30, 30),
				Size = seq({ { 0, 4 }, { 1, 6 } }), Transparency = seq({ { 0, 0.75 }, { 0.2, 0.5 }, { 0.8, 0.6 }, { 1, 1 } }),
				Color = ColorSequence.new(P.white, C(205, 205, 220)), LightEmission = 0.1,
			})
			-- Low, slow smoke along both sides wraps the posts, the ladders and the deck tubes; it stops in front of
			-- the bank and stays under it, so the screens stay clear.
			for _, sx in { -1, 1 } do
				local side = ghost(tm:part('AuraSide', V(0.9, 1, 8), CFrame.new(sx * 3.3, 2.4, -0.4), P.white))
				Treadmills.emitter(side, 'AuraLow', 'aura', CFrame.new(), {
					Rate = 12, Lifetime = NumberRange.new(2.2, 3), Speed = NumberRange.new(0.8, 1.3), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.15, 0), Drag = 0.5, RotSpeed = NumberRange.new(-15, 15), ZOffset = -1,
					Size = seq({ { 0, 3.5 }, { 1, 5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.5 }, { 0.7, 0.62 }, { 1, 1 } }),
					Color = ColorSequence.new(C(110, 110, 122), C(40, 40, 48)), LightEmission = 0,
				})
				Treadmills.emitter(side, 'WispsLow', 'wisp', CFrame.new(), {
					Rate = 8, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.6, 1.2), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.3, 0), Drag = 0.6, RotSpeed = NumberRange.new(-30, 30),
					Size = seq({ { 0, 3 }, { 1, 4.5 } }), Transparency = seq({ { 0, 0.75 }, { 0.2, 0.5 }, { 0.8, 0.6 }, { 1, 1 } }),
					Color = ColorSequence.new(P.white, C(205, 205, 220)), LightEmission = 0.1,
				})
			end
			-- Speed streaks shooting back off the belt.
			Treadmills.emitter(fx, 'Streaks', 'streak', beltWorld, {
				Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
				Rate = 9, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(14, 20), SpreadAngle = Vector2.new(4, 4),
				Size = seq({ { 0, 0.18 }, { 1, 0.05 } }), Squash = seq({ { 0, 3 }, { 1, 3 } }),
				Transparency = seq({ { 0, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(P.white, row.Color), LightEmission = 1, Brightness = 2,
			})
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- evolutions podium
-- The EVOLUTIONS podium, the lobby's morph stand, after the reference's east side: a stepped pyramid of three
-- studded slate-grey tiers (5 / 5 / 4 looks, cheapest at the front and bottom) on glowing pads whose colour is
-- the rarity band, corner stairs on every tier plus two flights up the walkway flank (+X), and the Kingpin
-- apart on a red featured plinth at the back corner on the walkway side, turning and bobbing over a cyan inset.
-- Warehouse dress: a neon EVOLUTIONS marquee across the first tier, two short galvanised light towers on the
-- front corners, a blue corrugated backdrop with footlights and neon bars, a VIP corner on the front apron
-- (velvet ropes, a dressing mirror, a bench, a NEXT LOOK floor arrow), speakers and the "next jackets" rail.
-- Alive: motes rising off every pad, sparkles and haze on the top tier, chasing marquee bulbs, colour-cycling
-- arrows; the client makes unlocked looks breathe, turns the one you wear and paints locked looks in shadow.
--
-- Contract (Lobby.client, LobbyService): a Model `Morphs` (Persistent) holding one Model `Skin_<Id>` per look:
--   Interact     invisible part just in front of the pad: the prompt sits on it and the server measures the
--                14-stud equip distance to it (from the level in front it is ~3 studs away)
--   LabelAnchor  BillboardGui WorldLabel > TextLabels Title (name), Price, Gain (+N/sec) and Detail
--                (EQUIPPED / EQUIP / LOCKED, written by the client, which also shows the label only near you)
--   Display      the figure (SkinArt); the client paints it in a band-tinted shadow while locked
--   Lock         a small gold padlock on the pad's front edge, shown while locked
--   Turntable    a disc under the figure, shown for the look you wear
-- and attributes Look, Index, Required, Band, BandColor, Column (+ Showcase on the Kingpin: always in colour).
-- Effects marked UnlockedOnly (or held by a part marked so) are switched off by the client while locked.
-- The map root still needs MorphStand = true (g_build).
-- Local frame: origin = centre of the front edge on the floor, the front faces -Z (players walk up from -Z),
-- the walkway is on the +X side, footprint x -28..28, z 0..32, at most 20 tall (labels float above).
local Evolutions = {}

Evolutions.Base = 0.4 -- floor slab top
Evolutions.Apron = 5 -- front apron depth (the VIP corner and the NEXT LOOK arrow)
Evolutions.Rise = 3.6 -- per tier: four 0.9 steps
Evolutions.Steps = 4
Evolutions.Flight = 3 -- corner stair width (tiers 1-2 step in by this much at the front corners)
Evolutions.CentreStair = 1.2 -- the top tier's stair runs up the middle, between its two inner pads (half width)
Evolutions.Pitch = 8.1 -- tier front to tier front: tread, pad, a 2.6-stud walk behind the pads
Evolutions.Back = 30 -- tiers end here, the backdrop stands behind
Evolutions.Spacing = 7
Evolutions.Pad = 4.4
Evolutions.PadH = 1.1
Evolutions.Tiers = {}
for k, hw in { 25.4, 22.4, 14.5 } do
	local front = Evolutions.Apron + (k - 1) * Evolutions.Pitch
	Evolutions.Tiers[k] = { top = Evolutions.Base + Evolutions.Rise * k, front = front, hw = hw, row = front + 1.1 + Evolutions.Pad / 2, centre = k == 3 }
end
-- One pad colour per tier (height is the rarity on the podium; the rarity band stays on the label outline).
-- `glow` is the Neon inset, about 0.65 of the colour: Neon renders brighter than its Color3 and the full
-- colour burns out to white (judge in Studio with bloom; drop toward 0.55 if the centre clips).
Evolutions.TierColors = {
	{ color = C(0, 190, 255), glow = C(0, 124, 166) },
	{ color = C(150, 70, 255), glow = C(80, 8, 176) },
	{ color = C(255, 180, 0), glow = C(166, 117, 0) },
}
-- Columns per row (x, viewer's left = +X first). The top row has four, in the gaps of the row below.
Evolutions.Columns = { { 14, 7, 0, -7, -14 }, { 14, 7, 0, -7, -14 }, { 10.7, 3.7, -3.7, -10.7 } }
-- Flights up the walkway flank: slab to tier 1 on the apron, tier 1's landing into tier 2.
Evolutions.SideFlights = { { tier = 1, z0 = 12, z1 = 18 }, { tier = 2, z0 = 17.1, z1 = 23.1 } }
-- Rarity bands (three looks each, the order the overhead tag uses): the outline of the look's name.
Evolutions.Bands = {
	{ name = 'COMMON', color = C(0, 190, 255) },
	{ name = 'UNCOMMON', color = C(40, 230, 90) },
	{ name = 'RARE', color = C(40, 110, 255) },
	{ name = 'EPIC', color = C(170, 60, 255) },
	{ name = 'LEGENDARY', color = C(255, 180, 0) },
}
-- Pose per look (SkinArt.Poses), so neighbours never stand the same way.
Evolutions.Poses = {
	CornerKid = 'wave', Pickpocket = 'swagger', Lookout = 'point', Bandit = 'hips', Hustler = 'cheer',
	Crook = 'swagger', GetawayDriver = 'flex', Enforcer = 'hips', StreetBoss = 'boss', Gangster = 'point',
	Capo = 'hips', Consigliere = 'easy', Underboss = 'swagger', TheDon = 'boss', Kingpin = 'cheer',
}
-- The featured look: its own plinth at the back corner on the walkway side (where the reference has its
-- featured figure), on tier 2 beside the narrow top tier.
Evolutions.Featured = 'Kingpin'
Evolutions.FeaturedAt = V(19.2, 0, 27)
Evolutions.FeaturedScale = 1.15
Evolutions.Scale = 1.12 -- the other figures: a bit over player size, so they fill their pads like the reference
Evolutions.TowerX = 26.6 -- the light tower on the far front corner of the slab (-X)
Evolutions.Colors = {
	top = C(178, 188, 210), cap = C(164, 174, 198), riser = C(104, 120, 152), rim = C(84, 88, 102), steel = C(120, 128, 146),
	kick = C(90, 100, 124), hazard = C(255, 200, 40), ink = C(26, 26, 32), pad = C(232, 236, 244), shutter = C(126, 134, 152),
	slat = C(104, 112, 130), galvanised = C(150, 156, 170), plinth = C(210, 40, 60), rim2 = C(200, 240, 255),
}

function Evolutions.band(index) return Evolutions.Bands[math.clamp(math.ceil(index / 3), 1, #Evolutions.Bands)] end

-- Optional shared modules (HoodVFX, SkinArt): nil when missing or broken.
function Evolutions.optional(name)
	local shared = ReplicatedStorage:FindFirstChild('Shared')
	local m = shared and shared:FindFirstChild(name)
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end
-- A particle texture: the uploaded HoodVFX sheet when there is one, else a Roblox built-in. The preview
-- renderer reads the PreviewTexture attribute.
function Evolutions.texture(name)
	local vfx = Evolutions.optional('HoodVFX')
	local id = vfx and vfx.Textures and vfx.Textures[name]
	if type(id) == 'string' and id ~= '' then return id end
	return ({ dust = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png', shaft = 'rbxasset://textures/glow.png',
		glitter = 'rbxasset://textures/particles/sparkles_main.dds', ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
		ray = 'rbxasset://textures/glow.png', mist = 'rbxasset://textures/particles/smoke_main.dds' })[name] or 'rbxasset://textures/particles/sparkles_main.dds'
end
-- True once the HoodVFX sheet `name` is uploaded. Until then the built-in stand-ins are soft blobs (and
-- smoke_main is a white cumulus), so the effects that only work with the real sheet stay off.
function Evolutions.uploaded(name)
	local vfx = Evolutions.optional('HoodVFX')
	local id = vfx and vfx.Textures and vfx.Textures[name]
	return type(id) == 'string' and id ~= ''
end
-- NumberSequence from { {time, value, envelope?}, ... }.
function Evolutions.seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
function Evolutions.emitter(parent, name, tex, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Texture = Evolutions.texture(tex)
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do (e :: any)[k] = v end
	e:SetAttribute('PreviewTexture', tex)
	e.Parent = parent
	return e
end
function Evolutions.attach(part, name, pos)
	local a = Instance.new('Attachment')
	a.Name = name
	a.CFrame = CFrame.new(pos)
	a.Parent = part
	return a
end
-- Soft sheet of light between two attachments (turns to face the camera).
function Evolutions.beam(part, name, a0, a1, w0, w1, color, t0)
	local b = Instance.new('Beam')
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = Evolutions.texture('shaft')
	b:SetAttribute('PreviewTexture', 'shaft')
	b.TextureMode, b.TextureLength, b.TextureSpeed = Enum.TextureMode.Stretch, 1, 0.2
	b.Width0, b.Width1 = w0, w1
	b.FaceCamera, b.Segments = true, 1
	b.LightEmission, b.LightInfluence, b.Brightness = 1, 0, 1.2
	b.Color = ColorSequence.new(color)
	b.Transparency = Evolutions.seq({ { 0, t0 }, { 0.6, 1 - (1 - t0) * 0.45 }, { 1, 1 } })
	b.Parent = part
	return b
end
-- Lowest and highest corner of a model's visible parts in `frame` space.
function Evolutions.extents(model, frame)
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
	return lo, hi
end

---------------------------------------------------------------------------------------------- truss
-- Square lattice truss along +Y of `cf` (origin at the bottom centre): four chords, rungs and a zigzag of
-- braces on every face (the light towers).
function Evolutions.truss(c, cf, w, len, color)
	local t = c:at(cf)
	local h = w / 2
	local corners = { V(-h, 0, -h), V(h, 0, -h), V(h, 0, h), V(-h, 0, h) }
	for _, k in corners do t:bar('TrussChord', k, k + V(0, len, 0), 0.3, color, M.Metal) end
	local n = math.max(1, math.round(len / (w * 1.25)))
	local seg = len / n
	for i = 0, n do
		local y = i * seg
		for f = 1, 4 do
			local a, b = corners[f], corners[f % 4 + 1]
			decor(t:bar('TrussRung', a + V(0, y, 0), b + V(0, y, 0), 0.18, color, M.Metal))
			if i < n then
				local flip = (i + f) % 2 == 0
				decor(t:bar('TrussBrace', (flip and a or b) + V(0, y, 0), (flip and b or a) + V(0, y + seg, 0), 0.14, color, M.Metal))
			end
		end
	end
	return t
end

---------------------------------------------------------------------------------------------- podium
-- One stair flight climbing toward the frame's +Z, `run` deep, between x0 and x1, from y0 to y1, starting at
-- z0. Studded treads, a darker nose on every step; only the bottom nose is hazard-striped.
function Evolutions.flight(c, x0, x1, z0, y0, y1, run)
	local col = Evolutions.Colors
	local n = Evolutions.Steps
	local rise, depth = (y1 - y0) / n, run / n
	local f = c:group('Stairs')
	for i = 1, n do
		local z = z0 + (i - 1) * depth
		local top = y0 + i * rise
		studs(f:box('Step', V(x0, y0, z), V(x1, top, z + depth), i % 2 == 0 and col.top or col.cap, M.Plastic))
		if i == 1 then
			local w = (x1 - x0) / 5
			for j = 0, 4 do
				decor(f:box('HazardNose', V(x0 + j * w, top - 0.14, z - 0.06), V(x0 + (j + 1) * w, top + 0.04, z + 0.3), j % 2 == 0 and col.hazard or col.ink, M.SmoothPlastic))
			end
		else
			decor(f:box('StepNose', V(x0, top - 0.14, z - 0.06), V(x1, top + 0.03, z + 0.3), col.galvanised, M.SmoothPlastic))
		end
	end
	return f
end

-- One tier: slate-blue studded body, light studded cap with a dark studded band along its open edges (the
-- reference's two-tone rim), a dark band under the lip with a yellow safety line, diamond-plate kick plates,
-- steel ribs between the pads. Stairs: corner flights at the front (tiers 1-2) or one flight up the middle
-- (the narrow top tier, between its two inner pads), plus side notches on +X given in `notches` ({ z0, z1 },
-- each filled by a flight climbing in from +X).
function Evolutions.tier(p, k, t, below, notches)
	local col = Evolutions.Colors
	local fl, back = Evolutions.Flight, Evolutions.Back
	local tier = p:group('Tier' .. k)
	-- Body blocks { x0, x1, z0, z1, outer = side whose outer edge is open, front = x-range of the open front }.
	local blocks, fronts, flights = {}, {}, {}
	if t.centre then
		local sw = Evolutions.CentreStair
		-- (the front blocks reach 0.55 into the rear one so their caps meet the rear cap edge to edge)
		table.insert(blocks, { -t.hw, -sw, t.front, t.front + fl + 0.55, outer = -1 })
		table.insert(blocks, { sw, t.hw, t.front, t.front + fl + 0.55, outer = 1 })
		table.insert(blocks, { -t.hw, t.hw, t.front + fl, back, outer = 0, front = { -sw, sw } })
		fronts = { { -t.hw, -sw }, { sw, t.hw } }
		flights = { { -sw, sw } }
	else
		local inner = t.hw - fl
		table.insert(blocks, { -inner, inner, t.front, back })
		for _, s in { -1, 1 } do
			local z = t.front + fl
			for _, n in (s == 1 and notches or {}) do
				table.insert(blocks, { math.min(s * inner, s * t.hw), math.max(s * inner, s * t.hw), z, n[1], outer = s })
				z = n[2]
			end
			table.insert(blocks, { math.min(s * inner, s * t.hw), math.max(s * inner, s * t.hw), z, back, outer = s })
		end
		fronts = { { -inner, inner } }
		flights = { { -t.hw, -inner }, { inner, t.hw } }
	end
	for _, b in blocks do
		local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
		if z1 - z0 > 0.05 then
			studs(tier:box('Riser', V(x0, below, z0), V(x1, t.top - 0.3, z1), col.riser, M.Plastic), true)
			local outs = b.outer == 0 and { -1, 1 } or b.outer and { b.outer } or {}
			local cx0, cx1 = x0, x1
			for _, o in outs do
				if o == 1 then cx1 = x1 - 0.55 else cx0 = x0 + 0.55 end
			end
			local fz = 0.55
			studs(tier:box('Cap', V(cx0, t.top - 0.3, z0 + fz), V(cx1, t.top, z1), col.top, M.Plastic))
			-- Dark band along the open front edge (all of it, or just the stair opening) and the outer sides.
			local f0, f1 = x0, x1
			if b.front then f0, f1 = b.front[1], b.front[2] end
			studs(tier:box('EdgeRim', V(f0 - (b.outer == -1 and 0.15 or 0), t.top - 0.3, z0 - 0.15), V(f1 + (b.outer == 1 and 0.15 or 0), t.top, z0 + 0.55), col.rim, M.Plastic))
			for _, o in outs do
				local edge = o == 1 and t.hw or -t.hw
				local r0, r1 = edge - o * 0.55, edge + o * 0.15
				studs(tier:box('EdgeRim', V(math.min(r0, r1), t.top - 0.3, z0 + fz), V(math.max(r0, r1), t.top, z1), col.rim, M.Plastic))
				studs(tier:box('SideRim', V(math.min(edge + o * 0.1, edge + o * 0.25), t.top - 0.75, z0), V(math.max(edge + o * 0.1, edge + o * 0.25), t.top - 0.3, z1), col.rim, M.Plastic))
				tier:box('SideKick', V(math.min(edge, edge + o * 0.13), below, z0), V(math.max(edge, edge + o * 0.13), below + 0.5, z1), col.kick, M.DiamondPlate)
			end
		end
	end
	for _, f in fronts do
		studs(tier:box('FrontRim', V(f[1], t.top - 0.75, t.front - 0.25), V(f[2], t.top - 0.3, t.front), col.rim, M.Plastic))
		decor(tier:box('SafetyLine', V(f[1], t.top - 0.22, t.front - 0.2), V(f[2], t.top - 0.08, t.front - 0.14), col.hazard, M.SmoothPlastic))
		tier:box('KickPlate', V(f[1], below, t.front - 0.12), V(f[2], below + 0.5, t.front), col.kick, M.DiamondPlate)
	end
	-- Steel ribs between the pads (tier 1 carries the sign in the middle instead).
	local cols = Evolutions.Columns[k]
	for i = 1, #cols - 1 do
		local x = (cols[i] + cols[i + 1]) / 2
		if not (k == 1 and math.abs(x) < 15) and math.abs(x) > Evolutions.CentreStair + 0.6 then
			tier:box('Rib', V(x - 0.3, below + 0.5, t.front - 0.18), V(x + 0.3, t.top - 0.75, t.front), col.steel, M.Metal)
		end
	end
	for _, f in flights do
		Evolutions.flight(tier, f[1], f[2], t.front, below, t.top, fl)
		for _, x in { f[1], f[2] } do
			if math.abs(math.abs(x) - t.hw) > 0.1 then
				tier:box('StairCheek', V(x - 0.2, below, t.front), V(x + 0.2, t.top - 0.3, t.front + fl), col.steel, M.Metal)
			end
		end
	end
	for _, n in notches do
		-- In a frame turned so its +Z points to -X: the flight climbs from the side face in.
		local f = tier:at(CFrame.new(t.hw, 0, (n[1] + n[2]) / 2) * CFrame.Angles(0, -math.pi / 2, 0))
		Evolutions.flight(f, -(n[2] - n[1]) / 2, (n[2] - n[1]) / 2, 0, below, t.top, fl)
	end
	return tier
end

function Evolutions.podium(c)
	local col = Evolutions.Colors
	local B = Evolutions.Base
	local p = c:group('Podium')
	-- Floor slab with a darker studded rim (the reference's two-tone edge).
	studs(p:box('Slab', V(-28, 0, 0), V(28, B, 32), col.top, M.Plastic))
	for _, r in { { V(-28, 0, 0), V(28, B + 0.12, 0.9) }, { V(-28, 0, 31.1), V(28, B + 0.12, 32) }, { V(-28, 0, 0.9), V(-27.1, B + 0.12, 31.1) }, { V(27.1, 0, 0.9), V(28, B + 0.12, 31.1) } } do
		studs(p:box('SlabRim', r[1], r[2], col.rim, M.Plastic))
	end
	local below = B
	for k, t in Evolutions.Tiers do
		local notches = {}
		for _, sf in Evolutions.SideFlights do
			if sf.tier == k and k > 1 then table.insert(notches, { sf.z0, sf.z1 }) end
		end
		Evolutions.tier(p, k, t, below, notches)
		below = t.top
	end
	-- Tier 1's side flight stands on the slab outside the tier (the apron is exactly one flight wide).
	for _, sf in Evolutions.SideFlights do
		if sf.tier == 1 then
			local t = Evolutions.Tiers[1]
			local f = p:at(CFrame.new(27.9, 0, (sf.z0 + sf.z1) / 2) * CFrame.Angles(0, -math.pi / 2, 0))
			Evolutions.flight(f, -(sf.z1 - sf.z0) / 2, (sf.z1 - sf.z0) / 2, 0, B, t.top, 27.9 - t.hw)
		end
	end
	return p
end

---------------------------------------------------------------------------------------------- looks
-- The label over a figure: the name in white outlined in the rarity band's colour, then one yellow line with
-- the power needed and the gain, then the action chip. Lobby.client shows it only near you (and on your next
-- look when you are near it). Beside it, off until the client switches it on for your next look from afar: the
-- NextMarker, a big ▼ in the pad's colour.
function Evolutions.label(c, pos, s, band, markColor)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(4.8, 1.9)
	g.MaxDistance = 70
	g.LightInfluence = 0
	g.Parent = anchor
	local function text(name, value, color, x, y, w, h, stroke, thickness, align)
		local t = Instance.new('TextLabel')
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(x, y)
		t.Size = UDim2.fromScale(w, h)
		t.Font = FONT.loud
		t.Text = value
		t.TextColor3 = color
		t.TextScaled = true
		t.TextStrokeTransparency = 1
		if align then t.TextXAlignment = align end
		local st = Instance.new('UIStroke')
		st.Color = stroke
		st.Thickness = thickness or 2
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = g
		return t
	end
	local ink, yellow = C(24, 22, 40), C(255, 222, 70)
	text('Title', s.Name, P.white, 0, 0, 1, 0.42, band.color:Lerp(C(0, 0, 0), 0.35), 3)
	text('Price', '💪 ' .. (s.Required == 0 and 'FREE' or compact(s.Required)), yellow, 0.04, 0.44, 0.47, 0.25, ink, 2, Enum.TextXAlignment.Right)
	text('Gain', '+' .. s.Gain .. '/sec', yellow, 0.55, 0.44, 0.41, 0.25, ink, 2, Enum.TextXAlignment.Left)
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.BackgroundColor3 = ink
	chip.BackgroundTransparency = 0.2
	chip.BorderSizePixel = 0
	chip.Position = UDim2.fromScale(0.27, 0.72)
	chip.Size = UDim2.fromScale(0.46, 0.28)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = chip
	chip.Parent = g
	-- A new player's view; Lobby.client rewrites it (EQUIPPED / EQUIP / LOCKED).
	text('Detail', s.Required == 0 and 'EQUIPPED' or 'LOCKED', s.Required == 0 and C(120, 220, 255) or C(255, 90, 90), 0.27, 0.73, 0.46, 0.26, ink, 2)
	local mark = Instance.new('BillboardGui')
	mark.Name = 'NextMarker'
	mark.Size = UDim2.fromScale(2.2, 2.2)
	mark.StudsOffset = Vector3.new(0, 0.4, 0)
	mark.MaxDistance = 120
	mark.LightInfluence = 0
	mark.Enabled = false
	mark.Parent = anchor
	local arrow = Instance.new('TextLabel')
	arrow.Name = 'Arrow'
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = FONT.loud
	arrow.Text = '▼'
	arrow.TextColor3 = (markColor or band.color):Lerp(P.white, 0.25)
	arrow.TextScaled = true
	arrow.TextStrokeTransparency = 1
	local st = Instance.new('UIStroke')
	st.Color, st.Thickness, st.LineJoinMode = C(0, 0, 0), 2, Enum.LineJoinMode.Round
	st.Parent = arrow
	arrow.Parent = mark
	return anchor
end

-- Small gold padlock sitting on the pad's front edge (the client hides it once the look unlocks).
function Evolutions.padlock(c, pos, scale)
	local l, model = c:group('Lock')
	local k = scale or 1
	local gold, steel = C(255, 200, 48), C(206, 212, 222)
	l:box('LockBody', pos + V(-0.6, -0.5, -0.24) * k, pos + V(0.6, 0.45, 0.24) * k, gold, M.SmoothPlastic)
	l:box('LockRim', pos + V(-0.64, 0.3, -0.27) * k, pos + V(0.64, 0.45, 0.27) * k, gold:Lerp(C(150, 90, 10), 0.35), M.SmoothPlastic)
	for _, x in { -0.38, 0.38 } do l:box('Shackle', pos + V(x - 0.11, 0.45, -0.11) * k, pos + V(x + 0.11, 1.0, 0.11) * k, steel, M.Metal) end
	l:box('Shackle', pos + V(-0.49, 1.0, -0.11) * k, pos + V(0.49, 1.2, 0.11) * k, steel, M.Metal)
	l:part('Keyhole', V(0.22, 0.22, 0.06) * k, CFrame.new(pos + V(0, 0.02, -0.25) * k), C(40, 26, 10), M.SmoothPlastic, Enum.PartType.Ball)
	l:box('Keyhole', pos + V(-0.05, -0.28, -0.27) * k, pos + V(0.05, 0, -0.23) * k, C(40, 26, 10), M.SmoothPlastic)
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then decor(d).CastShadow = false end
	end
	return model
end

-- Glowing pad, like the reference's: a white block with a dark bevel, a neon inset over most of its top in
-- the tier's colour with a bright inner rim, a neon band round the block's sides (what you see of the pad at
-- player height), the glow falling off round it onto the tier (an inner pool and a faint outer one, so stone
-- shows between neighbours), a coloured light above and motes rising off it. `tint` = { color, glow }.
function Evolutions.pad(c, x, y, z, tint, size, clip)
	local col = Evolutions.Colors
	local h, top = size / 2, y + Evolutions.PadH
	c:box('PadBlock', V(x - h, y, z - h), V(x + h, top, z + h), col.pad, M.SmoothPlastic)
	for _, ring in { { 'PadHalo', 0.35, 0.35, 0.05 }, { 'PadHaloOuter', 0.8, 0.82, 0.03 } } do
		local o = ring[2]
		-- (clip: keep the glow off a stair opening that runs up |x| < clip)
		local x0, x1 = x - h - o, x + h + o
		if clip and x > 0 then x0 = math.max(x0, clip) elseif clip then x1 = math.min(x1, -clip) end
		local halo = decor(c:box(ring[1], V(x0, y, z - h - o), V(x1, y + ring[4], z + h + o), tint.glow, M.Neon))
		halo.Transparency, halo.CastShadow = ring[3], false
	end
	c:box('PadBevel', V(x - h - 0.06, top - 0.32, z - h - 0.06), V(x + h + 0.06, top - 0.22, z + h + 0.06), col.rim, M.SmoothPlastic)
	decor(c:box('PadBand', V(x - h - 0.04, top - 0.35 - 0.3, z - h - 0.04), V(x + h + 0.04, top - 0.35, z + h + 0.04), tint.glow, M.Neon)).CastShadow = false
	local g = h - 0.45
	local glow = decor(c:box('PadGlow', V(x - g, top, z - g), V(x + g, top + 0.08, z + g), tint.glow, M.Neon))
	glow.CastShadow = false
	-- Bright inner rim round the inset (the ref's white-hot edge).
	local rim = c:group('PadRim')
	for _, e in { { V(x - g, 0, z - g), V(x + g, 0, z - g + 0.14) }, { V(x - g, 0, z + g - 0.14), V(x + g, 0, z + g) },
		{ V(x - g, 0, z - g + 0.14), V(x - g + 0.14, 0, z + g - 0.14) }, { V(x + g - 0.14, 0, z - g + 0.14), V(x + g, 0, z + g - 0.14) } } do
		decor(rim:box('PadRimStrip', e[1] + V(0, top + 0.08, 0), e[2] + V(0, top + 0.12, 0), col.rim2, M.Neon)).CastShadow = false
	end
	-- The light hangs a little above the pad: a coloured pool on the tier and up the figure's legs.
	local bulb = ghost(c:part('PadLight', V(0.2, 0.2, 0.2), CFrame.new(x, top + 3, z), tint.color))
	bulb.CastShadow = false
	light(bulb, tint.color, 0.5, 9)
	-- A soft sheet of light standing on the pad (unlocked pads only) and motes drifting up through it.
	local up0 = Evolutions.attach(glow, 'GlowBase', V(0, 0.05, 0))
	local up1 = Evolutions.attach(glow, 'GlowTop', V(0, 3.4, 0))
	Evolutions.beam(glow, 'PadGlowSheet', up0, up1, size - 1.1, size - 0.6, tint.glow, 0.7):SetAttribute('UnlockedOnly', true)
	Evolutions.emitter(glow, 'PadMotes', 'dust', {
		Rate = 3, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(0.8, 1.8), SpreadAngle = Vector2.new(8, 8),
		EmissionDirection = Enum.NormalId.Top, Acceleration = V(0, 0.4, 0), LightEmission = 1,
		Size = Evolutions.seq({ { 0, 0 }, { 0.2, 0.28, 0.08 }, { 1, 0 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.2, 0.15 }, { 1, 1 } }),
		Color = ColorSequence.new(tint.color:Lerp(P.white, 0.5), tint.color),
	})
	return top + 0.08
end

-- The featured plinth (the reference's red featured pad): a red frame with cyan corner lights, a cyan inset,
-- and on it the turntable with a colour-cycling gold ring; halo, glitter and rays round the figure.
function Evolutions.plinth(c, x, y, z, band)
	local red, cyan, gold = Evolutions.Colors.plinth, Evolutions.TierColors[1].glow, band.color
	local h, top = 3, y + 1.6
	studs(c:box('PlinthFrame', V(x - h, y, z - h), V(x + h, top, z + h), red, M.Plastic), true)
	c:box('PlinthLip', V(x - h - 0.1, top - 0.3, z - h - 0.1), V(x + h + 0.1, top, z + h + 0.1), red:Lerp(C(0, 0, 0), 0.25), M.SmoothPlastic)
	local inset = decor(c:box('PlinthInset', V(x - h + 0.6, top, z - h + 0.6), V(x + h - 0.6, top + 0.06, z + h - 0.6), cyan, M.Neon))
	inset.CastShadow = false
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			decor(c:box('CornerLight', V(x + cx * (h - 0.05) - 0.35, y + 0.25, z + cz * (h - 0.05) - 0.35), V(x + cx * (h - 0.05) + 0.35, y + 0.75, z + cz * (h - 0.05) + 0.35), cyan, M.Neon)).CastShadow = false
		end
	end
	local halo = decor(c:box('PlinthHalo', V(x - h - 0.5, y, z - h - 0.5), V(x + h + 0.5, y + 0.05, z + h + 0.5), cyan, M.Neon))
	halo.Transparency, halo.CastShadow = 0.4, false
	c:part('Turntable', V(0.3, 3.2, 3.2), CFrame.new(x, top + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2), C(232, 232, 240), M.Metal, Enum.PartType.Cylinder)
	local ring = decor(c:part('TurntableRing', V(0.12, 3.6, 3.6), CFrame.new(x, top + 0.12, z) * CFrame.Angles(0, 0, math.pi / 2), gold, M.Neon, Enum.PartType.Cylinder))
	ring.CastShadow = false
	ring:SetAttribute('Hue', 14)
	ring:AddTag('HoodMotion')
	local bulb = ghost(c:part('PlinthLight', V(0.2, 0.2, 0.2), CFrame.new(x, top + 3.5, z - 2), gold))
	bulb.CastShadow = false
	light(bulb, gold, 0.8, 12)
	-- Effects: a warm halo, star glints and glitter, rising rays, a ring pulsing out over the plinth.
	local feet = top + 0.35 + 0.25
	local core = ghost(c:part('FeaturedFx', V(3.4, 6, 2.4), CFrame.new(x, feet + 3.4, z), gold))
	core.CastShadow = false
	Evolutions.emitter(core, 'Halo', 'softglow', {
		Rate = 1, Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), Rotation = NumberRange.new(0), ZOffset = -2, LightEmission = 1,
		Size = Evolutions.seq({ { 0, 5 }, { 1, 5.5 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.4, 0.62 }, { 0.6, 0.62 }, { 1, 1 } }), Color = ColorSequence.new(gold),
	})
	Evolutions.emitter(core, 'Glitter', 'glitter', {
		Rate = 9, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		RotSpeed = NumberRange.new(-90, 90), Size = Evolutions.seq({ { 0, 0 }, { 0.4, 0.9, 0.3 }, { 1, 0 } }), Color = ColorSequence.new(P.white, gold), ZOffset = 1,
	})
	local base = ghost(c:part('FeaturedRays', V(4, 0.2, 4), CFrame.new(x, top + 0.4, z), gold))
	base.CastShadow = false
	if Evolutions.uploaded('ray') then Evolutions.emitter(base, 'Rays', 'ray', {
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1.2, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.1),
		Rotation = NumberRange.new(0), LightEmission = 1, Size = Evolutions.seq({ { 0, 4.5 }, { 1, 5 } }),
		Transparency = Evolutions.seq({ { 0, 1 }, { 0.4, 0.55 }, { 0.6, 0.55 }, { 1, 1 } }), Color = ColorSequence.new(gold:Lerp(P.white, 0.4)), ZOffset = -1,
	}) end
	Evolutions.emitter(base, 'GroundRing', 'ring', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Rate = 0.8, Lifetime = NumberRange.new(1.6),
		Speed = NumberRange.new(0.01), LightEmission = 1, Size = Evolutions.seq({ { 0, 1 }, { 1, 5 } }), Transparency = Evolutions.seq({ { 0, 0.3 }, { 1, 1 } }),
		Color = ColorSequence.new(gold),
	})
	return feet
end

-- One look: pad (or the featured plinth), posed figure, turntable disc, padlock, label and the equip point,
-- all in Morphs/Skin_<Id>. Returns the model and the height the figure stands at.
function Evolutions.look(c, s, art, x, y, z, opts)
	local band = Evolutions.band(s.Index)
	local st, model = c:group('Skin_' .. s.Id)
	model:SetAttribute('Look', s.Id)
	model:SetAttribute('Index', s.Index)
	model:SetAttribute('Required', s.Required)
	local tint = opts.tint or Evolutions.TierColors[1]
	model:SetAttribute('Band', band.name)
	model:SetAttribute('BandColor', tint.color) -- the pad's colour: the client tints the locked figure with it
	model:SetAttribute('Column', opts.column or 1)
	local featured = opts.featured
	-- The featured look stays in colour while locked (only the padlock says so): it is the goal on show.
	if featured then model:SetAttribute('Showcase', true) end
	local scale = featured and Evolutions.FeaturedScale or Evolutions.Scale
	local feet = featured and Evolutions.plinth(st, x, y, z, band) or Evolutions.pad(st, x, y, z, tint, Evolutions.Pad, opts.clip)
	local half = featured and 3 or Evolutions.Pad / 2
	-- The disc the look you wear turns on (shown by the client).
	if not featured then
		local disc = st:group('Turntable')
		-- (its top 0.14 over the inset and 0.1 over the rim strips, so nothing z-fights)
		decor(disc:part('TurntableDisc', V(0.16, 3.2, 3.2), CFrame.new(x, feet + 0.06, z) * CFrame.Angles(0, 0, math.pi / 2), C(232, 232, 240), M.Metal, Enum.PartType.Cylinder))
		decor(disc:part('TurntableRim', V(0.12, 3.45, 3.45), CFrame.new(x, feet + 0.04, z) * CFrame.Angles(0, 0, math.pi / 2), tint.color:Lerp(P.white, 0.35), M.Neon, Enum.PartType.Cylinder))
		for _, p in disc.parent:GetChildren() do p.Transparency, p.CastShadow = 1, false end
	end
	-- The figure (SkinArt; the stand still works without it), turned a few degrees so the row doesn't read
	-- as copies. The featured one turns and bobs (HoodMotion, client side).
	local labelY = feet + 5.6 * scale + 1.3
	if art then
		local yaw = math.rad(opts.yaw or 0)
		local poseFn = art.posed or function(parent, cf, look, k) return art.mannequin(parent, cf, look, k) end
		local fig = poseFn(st.parent, st:world(CFrame.new(x, feet, z) * CFrame.Angles(0, yaw, 0)), s, scale, Evolutions.Poses[s.Id])
		fig.Name = 'Display'
		for _, d in fig:GetDescendants() do
			if d:IsA('BasePart') then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
		end
		fig.WorldPivot = st:world(CFrame.new(x, feet, z))
		if featured then
			fig:SetAttribute('Spin', 24)
			fig:SetAttribute('Bob', 0.25)
			fig:SetAttribute('BobPeriod', 3)
			fig:AddTag('HoodMotion')
		end
		-- Label clear of the tallest hat.
		local _, hi = Evolutions.extents(fig, st:world(CFrame.new()))
		labelY = hi.Y + 1.3 + (featured and 0.3 or 0)
	end
	-- A few glints round an unlocked figure (the client switches them off while it is locked).
	local glints = ghost(st:part('UnlockedFx', V(3 * scale, 5 * scale, 1.6 * scale), CFrame.new(x, feet + 2.8 * scale, z), band.color))
	glints.CastShadow = false
	glints:SetAttribute('UnlockedOnly', true)
	Evolutions.emitter(glints, 'Glints', 'glitter', {
		Rate = 1.6, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0), LightEmission = 1, RotSpeed = NumberRange.new(-60, 60),
		Size = Evolutions.seq({ { 0, 0 }, { 0.35, 0.6, 0.15 }, { 1, 0 } }), Color = ColorSequence.new(P.white, tint.color:Lerp(P.white, 0.5)), ZOffset = 1,
	})
	Evolutions.padlock(st, V(x, feet + 0.5, z - half - 0.1), 0.75)
	if s.Required == 0 then
		for _, d in model.Lock:GetDescendants() do
			if d:IsA('BasePart') then d.Transparency = 1 end
		end
	end
	Evolutions.label(st, V(x, labelY, z), s, band, featured and Evolutions.TierColors[1].color or tint.color)
	-- Equip point at knee height just in front of the pad (prompt + server distance check).
	local front = z - half - 0.5
	ghost(st:box('Interact', V(x - 0.6, y + 0.6, front - 0.6), V(x + 0.6, y + 1.8, front + 0.6), P.white)).CastShadow = false
	return model, feet
end

-- Sparkle glints around a top-tier figure, locked or not: the top tier is the lure.
function Evolutions.sparkle(c, x, feet, z, color)
	local fx = ghost(c:part('TopSparkle', V(3, 5.4, 2), CFrame.new(x, feet + 2.8, z), color))
	fx.CastShadow = false
	Evolutions.emitter(fx, 'Glints', 'glitter', {
		Rate = 3, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0), LightEmission = 1, RotSpeed = NumberRange.new(-60, 60),
		Size = Evolutions.seq({ { 0, 0 }, { 0.35, 0.8, 0.2 }, { 1, 0 } }), Color = ColorSequence.new(P.white, color:Lerp(P.white, 0.4)), ZOffset = 1,
	})
	return fx
end

---------------------------------------------------------------------------------------------- stagecraft
-- Spotlights: two on a short galvanised truss tower on the far front corner of the slab (-X, out of every
-- approach), two hung off the walkway-side wing's cap (+X), all aimed at the two lower rows, each with a soft
-- flare on its lens and an amber beacon on the tower. targets: { { side = -1 | 1, at = Vector3 } }.
function Evolutions.lights(c, targets)
	local col = Evolutions.Colors
	local g = c:group('LightTowers')
	local top = 11
	local x = -Evolutions.TowerX
	g:box('TowerFoot', V(x - 1.2, Evolutions.Base, 0.1), V(x + 1.2, Evolutions.Base + 0.5, 2.5), col.galvanised, M.DiamondPlate)
	Evolutions.truss(g, CFrame.new(x, Evolutions.Base + 0.5, 1.3), 2, top - Evolutions.Base - 0.5, col.galvanised)
	g:box('LampBar', V(x - 1, top, 0.9), V(x + 2.2, top + 0.35, 1.7), col.galvanised, M.Metal)
	decor(g:box('BeaconBase', V(x - 0.35, top + 0.35, 1.0), V(x + 0.35, top + 0.55, 1.6), col.ink, M.Metal))
	decor(g:part('Beacon', V(0.6, 0.5, 0.5), CFrame.new(x, top + 0.8, 1.3), C(255, 140, 40), M.Neon)).CastShadow = false
	local wingTop = Evolutions.Tiers[2].top + 7.4 + 0.4
	local n = { [-1] = 0, [1] = 0 }
	for _, t in targets do
		n[t.side] += 1
		local lamp = g:group('Spotlight')
		local pos
		if t.side == -1 then
			local lx = -(Evolutions.TowerX - (n[-1] == 1 and 0.2 or 1.6))
			pos = V(lx, top + 1.1, 1.3)
			lamp:box('LampYoke', V(lx - 0.12, top + 0.35, 1.1), V(lx + 0.12, top + 0.9, 1.5), col.ink, M.Metal)
		else
			-- Clamped to the front edge of the wing cap, hanging below it.
			local lx = n[1] == 1 and 22.6 or 24.6
			local z = Evolutions.Back - 0.4
			pos = V(lx, wingTop - 1.1, z - 0.3)
			lamp:box('LampClamp', V(lx - 0.25, wingTop - 0.55, z - 0.35), V(lx + 0.25, wingTop, z + 0.15), col.ink, M.Metal)
			lamp:box('LampYoke', V(lx - 0.1, wingTop - 0.95, z - 0.4), V(lx + 0.1, wingTop - 0.55, z - 0.2), col.ink, M.Metal)
		end
		local aim = CFrame.lookAt(pos, t.at)
		decor(lamp:part('LampCan', V(0.7, 0.7, 1.0), aim, C(150, 156, 170), M.Metal))
		decor(lamp:part('LampBack', V(0.5, 0.5, 0.2), aim * CFrame.new(0, 0, 0.55), C(52, 54, 62), M.Metal))
		local lens = decor(lamp:part('LampLens', V(0.58, 0.58, 0.1), aim * CFrame.new(0, 0, -0.52), C(255, 244, 214), M.Neon))
		lens.CastShadow = false
		local spot = Instance.new('SpotLight')
		spot.Face, spot.Color, spot.Brightness, spot.Range, spot.Angle, spot.Shadows = Enum.NormalId.Front, C(255, 236, 200), 2, 40, 35, false
		spot.Parent = lens
		Evolutions.emitter(Evolutions.attach(lens, 'Flare', V(0, 0, -0.15)), 'LensFlare', 'softglow', {
			Rate = 1, Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), Rotation = NumberRange.new(0), LightEmission = 1, ZOffset = 0.5,
			Size = Evolutions.seq({ { 0, 2.2 }, { 1, 2.4 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.5 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 240, 200)),
		})
	end
	-- Dust drifting over the podium, caught by the light.
	local dust = ghost(g:part('StageDust', V(40, 8, 20), CFrame.new(0, 10, 16), P.white))
	Evolutions.emitter(dust, 'Dust', 'dust', {
		Rate = 6, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6,
		Size = Evolutions.seq({ { 0, 0 }, { 0.3, 0.14, 0.05 }, { 1, 0 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 240, 210)),
	})
	return g
end

-- A chain hoist over the featured look ("just delivered"): a post up from the wing cap, an I-beam running
-- forward over the plinth, a chain down to a hook just above the crown.
function Evolutions.hoist(c, x, z, hookY)
	local col = Evolutions.Colors
	local h = c:group('ChainHoist')
	local wingTop = Evolutions.Tiers[2].top + 7.4 + 0.4
	local beamY = math.min(19.2, math.max(hookY + 1.5, wingTop + 1.5))
	local zb = Evolutions.Back + 0.6
	h:box('HoistPost', V(x - 0.3, wingTop, zb - 0.3), V(x + 0.3, beamY + 0.7, zb + 0.3), C(120, 128, 146), M.Metal)
	h:box('HoistBeam', V(x - 0.3, beamY, z - 1.2), V(x + 0.3, beamY + 0.7, zb + 0.3), C(120, 128, 146), M.Metal)
	for _, y in { beamY, beamY + 0.56 } do h:box('HoistFlange', V(x - 0.45, y, z - 1.2), V(x + 0.45, y + 0.14, zb + 0.3), C(104, 112, 130), M.Metal) end
	h:box('HoistBlock', V(x - 0.4, beamY - 0.5, z - 0.35), V(x + 0.4, beamY, z + 0.35), C(255, 200, 40), M.SmoothPlastic)
	local yTop, i = beamY - 0.5, 0
	while yTop - 0.4 > hookY + 0.3 do
		h:box('ChainLink', V(x - (i % 2 == 0 and 0.06 or 0.16), yTop - 0.42, z - (i % 2 == 0 and 0.16 or 0.06)), V(x + (i % 2 == 0 and 0.06 or 0.16), yTop, z + (i % 2 == 0 and 0.16 or 0.06)), C(150, 156, 170), M.Metal)
		yTop -= 0.36
		i += 1
	end
	h:box('HookShank', V(x - 0.1, hookY, z - 0.1), V(x + 0.1, yTop, z + 0.1), C(52, 54, 62), M.Metal)
	h:box('HookBend', V(x - 0.1, hookY - 0.1, z - 0.1), V(x + 0.1, hookY + 0.1, z + 0.45), C(52, 54, 62), M.Metal)
	h:box('HookTip', V(x - 0.1, hookY - 0.1, z + 0.3), V(x + 0.1, hookY + 0.35, z + 0.5), C(52, 54, 62), M.Metal)
	return h
end

-- The EVOLUTIONS marquee across the front of the first tier: a dark board in a cyan neon frame, yellow
-- letters outlined pink, and a ring of bulbs round it, every other one cycling colour so the frame chases.
function Evolutions.sign(c)
	local g = c:group('Sign')
	local t = Evolutions.Tiers[1]
	local w, y0, y1, z = 13.5, Evolutions.Base + 0.6, t.top - 0.95, t.front - 0.32
	local board = g:box('SignBoard', V(-w, y0, z), V(w, y1, t.front - 0.1), C(24, 24, 36), M.SmoothPlastic)
	local tube = C(80, 220, 255)
	for _, y in { y0 - 0.12, y1 } do
		decor(g:box('SignTube', V(-w - 0.15, y, z - 0.08), V(w + 0.15, y + 0.12, z + 0.05), tube, M.Neon)).CastShadow = false
	end
	for _, x in { -w - 0.15, w } do
		decor(g:box('SignTube', V(x, y0 - 0.12, z - 0.08), V(x + 0.15, y1 + 0.12, z + 0.05), tube, M.Neon)).CastShadow = false
	end
	local face = surface(board, Enum.NormalId.Front, 30)
	line(face, 'Title', '▲ EVOLUTIONS ▲', C(255, 230, 90), FONT.loud, 0.02, 0.96, C(255, 60, 150), 3)
	light(board, C(255, 200, 150), 1, 10)
	-- Marquee bulbs: along the top and bottom edges and up the two ends.
	local spots = {}
	for x = -w, w + 0.01, 1.5 do
		table.insert(spots, V(x, y1 + 0.42, z - 0.12))
		table.insert(spots, V(x, y0 - 0.42, z - 0.12))
	end
	for y = y0, y1 + 0.01, (y1 - y0) / 2 do
		table.insert(spots, V(-w - 0.55, y, z - 0.12))
		table.insert(spots, V(w + 0.55, y, z - 0.12))
	end
	for i, p in spots do
		local bulb = decor(g:part('MarqueeBulb', V(0.45, 0.45, 0.45), CFrame.new(p), i % 2 == 0 and C(255, 220, 120) or C(255, 90, 200), M.Neon, Enum.PartType.Ball))
		bulb.CastShadow = false
		if i % 2 == 0 then
			bulb:SetAttribute('Hue', 2.5)
			bulb:AddTag('HoodMotion')
		end
	end
	return g
end

-- Backdrop: a loading-bay wall of light roller shutters behind the tiers, tall behind the top tier and lower
-- on the wings (horizontal slats, a dark bottom rail, a galvanised drum housing along the top), galvanised
-- posts with neon edges splitting the middle into three bays behind the top row, DOCK stencils on the
-- wings, neon footlights along the base and colour-cycling up-arrows (evolving = going up) on the far wing.
function Evolutions.backdrop(c)
	local col = Evolutions.Colors
	local d = c:group('Backdrop')
	local z0, z1 = Evolutions.Back, Evolutions.Back + 1.2
	local t2, t3 = Evolutions.Tiers[2], Evolutions.Tiers[3]
	local wing = t2.top + 7.4
	-- { x0, x1, top, where the tiers in front stop hiding it }
	local panels = { { -t3.hw, t3.hw, 19.4, t3.top }, { -25.4, -t3.hw, wing, t2.top }, { t3.hw, 25.4, wing, t2.top } }
	for _, pnl in panels do
		local x0, x1, top, seen = pnl[1], pnl[2], pnl[3], pnl[4]
		d:box('Shutter', V(x0, Evolutions.Base, z0 + 0.3), V(x1, top - 0.9, z1), col.shutter, M.Plastic)
		for y = seen + 0.7, top - 1.3, 0.55 do
			decor(d:box('ShutterSlat', V(x0 + 0.05, y, z0 + 0.18), V(x1 - 0.05, y + 0.16, z0 + 0.3), col.slat, M.Plastic)).CastShadow = false
		end
		d:box('ShutterRail', V(x0, seen, z0 + 0.15), V(x1, seen + 0.45, z0 + 0.32), col.rim, M.Plastic)
		d:box('ShutterDrum', V(x0 - 0.1, top - 0.9, z0 - 0.3), V(x1 + 0.1, top, z1 + 0.1), col.galvanised, M.Plastic)
		studs(d:box('WallCap', V(x0 - 0.2, top, z0 - 0.3), V(x1 + 0.2, top + 0.4, z1 + 0.2), col.steel, M.Plastic))
	end
	-- Footlights back-lighting the figures: cyan behind the top tier, violet behind the wings.
	decor(d:box('Footlight', V(-t3.hw, t3.top + 0.1, z0 - 0.1), V(t3.hw, t3.top + 0.4, z0 + 0.1), C(80, 220, 255), M.Neon)).CastShadow = false
	for _, s in { -1, 1 } do
		decor(d:box('Footlight', V(math.min(s * t3.hw, s * t2.hw), t2.top + 0.1, z0 - 0.1), V(math.max(s * t3.hw, s * t2.hw), t2.top + 0.4, z0 + 0.1), C(186, 96, 255), M.Neon)).CastShadow = false
	end
	-- Bay posts: between the top-row figures and at the ends of the middle panel.
	local cols = Evolutions.Columns[3]
	for i, x in { (cols[1] + cols[2]) / 2, (cols[3] + cols[4]) / 2, t3.hw - 0.35, -t3.hw + 0.35 } do
		d:box('BayPost', V(x - 0.35, t3.top, z0 - 0.3), V(x + 0.35, 19.4, z0 + 0.3), col.galvanised, M.Plastic)
		decor(d:box('BayPostNeon', V(x - 0.12, t3.top + 0.5, z0 - 0.36), V(x + 0.12, 18.4, z0 - 0.3), i <= 2 and C(186, 96, 255) or C(80, 220, 255), M.Neon)).CastShadow = false
	end
	-- DOCK stencils on the wings.
	for _, w in { { -(t3.hw + 25.4) / 2, t2.top + 0.75, 'DOCK 03' }, { 23, t2.top + 4.9, 'DOCK 04' } } do
		local card = ghost(d:box('Stencil', V(w[1] - 2.2, w[2], z0 - 0.02), V(w[1] + 2.2, w[2] + 1.4, z0 + 0.1), P.white))
		line(surface(card, Enum.NormalId.Front, 30), 'Text', w[3], C(255, 200, 40), Enum.Font.Oswald, 0, 1, nil)
	end
	local arrows, model = d:group('UpArrows')
	model:SetAttribute('Hue', 12)
	model:AddTag('HoodMotion')
	local cx = -(t3.hw + 25.4) / 2
	for i = 0, 2 do
		local y = t2.top + 2.8 + i * 1.5
		local glow = C(255, 192, 44):Lerp(P.white, i * 0.15)
		for _, s in { -1, 1 } do
			local a = V(cx, y + 1.0, z0 - 0.06)
			local b = V(cx + s * 2.0, y, z0 - 0.06)
			local mid = (a + b) / 2
			decor(arrows:part('Chevron', V((b - a).Magnitude + 0.4, 0.45, 0.16), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(b.Y - a.Y, b.X - a.X)), glow, M.Neon)).CastShadow = false
		end
	end
	return d
end

-- Clutter in two clusters. Walkway flank (tier 1's +X landing, beside the side flights where it is seen): a
-- clothes rail of the next jackets, a road case with a coffee, shoe boxes. Far side: speaker stacks.
function Evolutions.props(c)
	local col = Evolutions.Colors
	local pr = c:group('Props')
	local t1, t2 = Evolutions.Tiers[1], Evolutions.Tiers[2]
	local lx = (t1.hw + t2.hw) / 2 -- middle of tier 1's side landing
	local y = t1.top
	for _, z in { 20.2, 24.6 } do
		pr:box('RailFoot', V(lx - 0.8, y, z - 0.2), V(lx + 0.8, y + 0.2, z + 0.2), col.steel, M.Metal)
		pr:box('RailPost', V(lx - 0.1, y + 0.2, z - 0.1), V(lx + 0.1, y + 4.4, z + 0.1), C(200, 204, 212), M.Metal)
	end
	pr:box('RailBar', V(lx - 0.1, y + 4.3, 20.1), V(lx + 0.1, y + 4.5, 24.7), C(200, 204, 212), M.Metal)
	for i, jc in { C(146, 75, 185), C(201, 175, 124), C(221, 62, 66), C(56, 67, 106), C(240, 190, 40) } do
		local z = 20.3 + i * 0.68
		pr:box('Hanger', V(lx - 0.05, y + 4.0, z - 0.25), V(lx + 0.05, y + 4.3, z + 0.25), C(150, 110, 70), M.Wood)
		pr:box('Jacket', V(lx - 0.7, y + 1.8, z - 0.22), V(lx + 0.7, y + 4.05, z + 0.22), jc, M.Fabric)
	end
	pr:box('RoadCase', V(lx - 1.2, y, 25.6), V(lx + 1.2, y + 1.6, 28.2), C(40, 110, 220), M.SmoothPlastic)
	for _, z in { 25.62, 28.18 } do pr:box('CaseEdge', V(lx - 1.25, y, z - 0.06), V(lx + 1.25, y + 1.65, z + 0.06), C(236, 238, 242), M.SmoothPlastic) end
	pr:box('CaseLatch', V(lx - 1.26, y + 1.1, 26.6), V(lx + 1.26, y + 1.3, 27.2), C(236, 238, 242), M.SmoothPlastic)
	pr:post('Coffee', 0.18, 0.42, V(lx + 0.5, y + 1.6, 26.4), C(250, 250, 250), M.SmoothPlastic)
	pr:post('CoffeeLid', 0.2, 0.08, V(lx + 0.5, y + 2.02, 26.4), C(60, 40, 30), M.SmoothPlastic)
	for i, sb in { C(230, 70, 60), C(250, 250, 250), C(255, 160, 40) } do
		local y0 = y + (i - 1) * 0.7
		pr:box('ShoeBox', V(lx - 1 + i * 0.08, y0, 28.6 + i * 0.06), V(lx + 1 + i * 0.08, y0 + 0.7, 29.8), sb, M.SmoothPlastic)
	end
	-- Far side, kept low so tier 2's shoulder stays bare stone (the taper): a delivery on tier 1's landing (a
	-- pallet of kraft boxes under shrink-wrap, NEW STOCK), one loose crate, a yellow pallet jack on the slab.
	local fx = -lx
	local pal = pr:at(CFrame.new(fx, y, 26.4) * CFrame.Angles(0, math.rad(6), 0))
	for _, px in { -1, 0, 1 } do pal:box('PalletBlock', V(px - 0.15, 0, -1.2), V(px + 0.15, 0.35, 1.2), C(120, 86, 52), M.Wood) end
	for pz = -1, 1, 0.5 do pal:box('PalletSlat', V(-1.2, 0.35, pz - 0.2), V(1.2, 0.5, pz + 0.2), C(150, 110, 70), M.WoodPlanks) end
	for i, b in { { -0.55, -0.5, 1.1 }, { 0.55, -0.45, 1.0 }, { 0, 0.55, 1.2 } } do
		pal:box('KraftBox', V(b[1] - 0.55, 0.5, b[2] - 0.5), V(b[1] + 0.55, 0.5 + b[3], b[2] + 0.5), C(196, 160, 110), M.Cardboard)
		decor(pal:box('BoxTape', V(b[1] - 0.56, 0.5 + b[3] - 0.02, b[2] - 0.08), V(b[1] + 0.56, 0.5 + b[3] + 0.01, b[2] + 0.08), C(170, 130, 80), M.SmoothPlastic))
	end
	local wrap = decor(pal:box('ShrinkWrap', V(-1.15, 0.5, -1.1), V(1.15, 1.85, 1.15), P.white, M.SmoothPlastic))
	wrap.Transparency, wrap.CastShadow = 0.6, false
	local tag = pal:box('StockTag', V(-0.5, 1.0, -1.18), V(0.5, 1.45, -1.13), C(255, 200, 40), M.SmoothPlastic)
	line(surface(tag, Enum.NormalId.Front, 60), 'Text', 'NEW STOCK', C(26, 26, 32), FONT.loud, 0.1, 0.8, nil)
	crate(pr, CFrame.new(fx, y, 23.4) * CFrame.Angles(0, math.rad(-5), 0), 2.2)
	local jack = pr:at(CFrame.new(-26.65, Evolutions.Base, 24.5) * CFrame.Angles(0, math.rad(4), 0))
	for _, jx in { -0.45, 0.45 } do jack:box('JackFork', V(jx - 0.2, 0.05, -1.6), V(jx + 0.2, 0.3, 1.2), C(255, 200, 40), M.Metal) end
	jack:box('JackBody', V(-0.75, 0.05, 1.0), V(0.75, 0.9, 1.6), C(255, 200, 40), M.Metal)
	jack:part('JackWheel', V(0.3, 0.5, 0.5), CFrame.new(0, 0.25, 1.3), C(40, 40, 48), M.SmoothPlastic, Enum.PartType.Cylinder)
	jack:bar('JackHandle', V(0, 0.9, 1.35), V(0, 2.9, 1.8), 0.14, C(40, 40, 48), M.Metal)
	jack:box('JackGrip', V(-0.4, 2.85, 1.7), V(0.4, 3.05, 1.9), C(40, 40, 48), M.SmoothPlastic)
	-- Work fan on a stand: the blades turn (HoodMotion).
	local fan = pr:at(CFrame.new(fx, y, 20.6) * CFrame.Angles(0, math.rad(-150), 0))
	fan:box('FanFoot', V(-0.7, 0, -0.7), V(0.7, 0.2, 0.7), C(40, 40, 48), M.Metal)
	fan:box('FanPole', V(-0.08, 0.2, -0.08), V(0.08, 3.2, 0.08), C(150, 156, 170), M.Metal)
	fan:part('FanCage', V(0.3, 2.4, 2.4), CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.pi / 2, 0), C(150, 156, 170), M.Metal, Enum.PartType.Cylinder).Transparency = 0.6
	local blades, bm = fan:group('FanBlades')
	for k = 0, 2 do blades:part('FanBlade', V(0.5, 1.05, 0.12), CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(k * 120)) * CFrame.new(0, 0.55, 0), C(255, 196, 40), M.SmoothPlastic) end
	-- (the pivot's Y axis runs along the fan's axis, so Spin turns the blades)
	bm.WorldPivot = fan:world(CFrame.new(0, 3.4, 0) * CFrame.Angles(math.pi / 2, 0, 0))
	bm:SetAttribute('Spin', 360)
	bm:AddTag('HoodMotion')
	return pr
end

-- The VIP corner on the front apron at the walkway side, between the first pad and the corner stairs (the
-- spots in front of the pads stay clear): an L of chrome stanchions with red velvet ropes round a padded
-- bench and a full-length dressing mirror with bulbs; a yellow NEXT LOOK arrow painted up the corner stairs
-- and a sandwich board beside the light tower.
function Evolutions.apron(c)
	local a = c:group('VipCorner')
	local B = Evolutions.Base
	local t1 = Evolutions.Tiers[1]
	local chrome, velvet = C(214, 220, 230), C(190, 20, 40)
	local x0, x1 = Evolutions.Columns[1][1] + Evolutions.Pad / 2 + 0.6, t1.hw - Evolutions.Flight - 0.2
	local posts = { V(x0, B, Evolutions.Apron - 0.8), V(x0, B, 0.8), V((x0 + x1) / 2, B, 0.8), V(x1, B, 0.8) }
	for _, p in posts do
		a:post('StanchionBase', 0.5, 0.18, p, chrome, M.Metal)
		a:post('Stanchion', 0.13, 2.1, p + V(0, 0.18, 0), chrome, M.Metal)
		a:part('StanchionTop', V(0.42, 0.42, 0.42), CFrame.new(p + V(0, 2.4, 0)), C(255, 210, 70), M.Metal, Enum.PartType.Ball)
	end
	-- Velvet ropes hanging between the posts, each in three sagging pieces.
	for i = 1, #posts - 1 do
		local p0, p1 = posts[i] + V(0, 2.22, 0), posts[i + 1] + V(0, 2.22, 0)
		local pts = { p0, p0:Lerp(p1, 0.33) - V(0, 0.42, 0), p0:Lerp(p1, 0.67) - V(0, 0.42, 0), p1 }
		for j = 1, 3 do decor(a:bar('VelvetRope', pts[j], pts[j + 1], 0.2, velvet, M.Fabric)).CastShadow = false end
	end
	-- Padded bench inside the ropes.
	local b = a:at(CFrame.new((x0 + x1) / 2 - 0.4, B, 2.1))
	for _, x in { -1.3, 1.3 } do b:box('BenchLeg', V(x - 0.15, 0, -0.4), V(x + 0.15, 1.1, 0.4), chrome, M.Metal) end
	b:box('BenchFrame', V(-1.7, 1.1, -0.5), V(1.7, 1.3, 0.5), C(40, 40, 48), M.Metal)
	b:box('BenchPad', V(-1.6, 1.3, -0.45), V(1.6, 1.75, 0.45), velvet, M.Fabric)
	-- Dressing mirror against the riser between the first pad and the stairs (out of the sight lines from the
	-- walkway to the front row), a ring of bulbs round the glass.
	local m = a:at(CFrame.new((Evolutions.Columns[1][1] + Evolutions.Pad / 2 + t1.hw - Evolutions.Flight) / 2, B, Evolutions.Apron - 0.55) * CFrame.Angles(0, math.rad(-12), 0))
	m:box('MirrorFoot', V(-1.2, 0, -0.45), V(1.2, 0.3, 0.45), C(40, 40, 48), M.Metal)
	m:box('MirrorFrame', V(-1.05, 0.3, -0.16), V(1.05, 5, 0.16), C(255, 196, 60), M.SmoothPlastic)
	local glass = m:box('MirrorGlass', V(-0.82, 0.55, -0.22), V(0.82, 4.75, -0.16), C(196, 226, 246), M.Glass)
	glass.Reflectance, glass.Transparency = 0.35, 0.1
	for _, y in { 1.2, 2.4, 3.6, 4.6 } do
		for _, x in { -0.92, 0.92 } do decor(m:part('MirrorBulb', V(0.28, 0.28, 0.28), CFrame.new(x, y, -0.26), C(255, 236, 190), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	end
	-- NEXT LOOK: a yellow arrow painted on the apron up the walkway-side corner stairs, and a sandwich board.
	local mid = t1.hw - Evolutions.Flight / 2
	decor(a:box('ArrowShaft', V(mid - 0.6, B, 0.5), V(mid + 0.6, B + 0.04, 3.3), C(255, 210, 40), M.SmoothPlastic))
	for _, s in { -1, 1 } do
		decor(a:part('ArrowHead', V(0.6, 0.04, 2), CFrame.new(mid + s * 0.62, B + 0.02, 3.85) * CFrame.Angles(0, s * math.rad(40), 0), C(255, 210, 40), M.SmoothPlastic))
	end
	local sb = a:at(CFrame.new(Evolutions.TowerX, B, 3.8) * CFrame.Angles(0, math.rad(-35), 0))
	for _, side in { -1, 1 } do
		sb:at(CFrame.new(0, 0, side * 0.35) * CFrame.Angles(side * math.rad(12), 0, 0)):box('BoardLeg', V(-0.75, 0, -0.06), V(0.75, 2.3, 0.06), C(40, 40, 48), M.Wood)
	end
	local face = sb:at(CFrame.new(0, 0, -0.35) * CFrame.Angles(math.rad(-12), 0, 0)):box('BoardFace', V(-0.68, 0.5, -0.1), V(0.68, 2.2, -0.07), C(24, 24, 36), M.SmoothPlastic)
	local g = surface(face, Enum.NormalId.Front, 60)
	line(g, 'Top', 'NEXT LOOK', C(255, 222, 70), FONT.loud, 0.08, 0.42, C(120, 30, 20), 2)
	line(g, 'Bottom', 'UP HERE ▲', P.white, FONT.loud, 0.55, 0.36, C(20, 20, 40), 2)
	return a
end

-- Low stage haze rolling over the top tier.
function Evolutions.fog(c)
	if not Evolutions.uploaded('mist') then return nil end
	local t3 = Evolutions.Tiers[3]
	local f = ghost(c:part('StageFog', V(30, 0.4, 3), CFrame.new(0, t3.top + 0.4, Evolutions.Back - 1.6), P.white))
	f.CastShadow = false
	Evolutions.emitter(f, 'Haze', 'mist', {
		Rate = 2, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(70, 10),
		EmissionDirection = Enum.NormalId.Front, Acceleration = V(0, -0.05, 0), RotSpeed = NumberRange.new(-10, 10), LightEmission = 0.3,
		Size = Evolutions.seq({ { 0, 2 }, { 1, 3.5 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.25, 0.88 }, { 0.7, 0.9 }, { 1, 1 } }),
		Color = ColorSequence.new(C(226, 232, 255)),
	})
	return f
end

---------------------------------------------------------------------------------------------- build
-- Builds the podium in ctx's frame and returns the Evolutions model. opts.skins / opts.art override
-- Config.Skins and Shared.SkinArt (without SkinArt the stands are built without figures).
function Evolutions.build(ctx, opts)
	opts = opts or {}
	local skins = opts.skins or require(ReplicatedStorage.Shared.Config.Skins)
	local art = opts.art or Evolutions.optional('SkinArt')
	local e, model = ctx:group('Evolutions')
	model:AddTag('HoodEvolutions')
	Evolutions.podium(e)
	Evolutions.backdrop(e)
	Evolutions.props(e)
	Evolutions.apron(e)
	local m, morphs = e:group('Morphs')
	-- The stand is small and every client needs all of it (prompts, labels, the guide arrow).
	pcall(function() morphs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	local wobble = { -5, 3, -2, 4, -4 }
	local placed = { 0, 0, 0 }
	for _, s in skins.List do
		if s.Id == Evolutions.Featured then
			local at = Evolutions.FeaturedAt
			local stand, feet = Evolutions.look(m, s, art, at.X, Evolutions.Tiers[2].top, at.Z, { featured = true, column = 1 })
			-- The hoist's hook hangs just clear of the crown (and its bob).
			local display = stand:FindFirstChild('Display')
			local crown = display and select(2, Evolutions.extents(display, e:world(CFrame.new()))).Y or feet + 7.4
			Evolutions.hoist(e, at.X, at.Z, crown + 0.7)
		else
			-- Fill the rows in price order: 5, 5, then the rest on the narrow top tier.
			local row = placed[1] < 5 and 1 or placed[2] < 5 and 2 or 3
			local cols = Evolutions.Columns[row]
			placed[row] += 1
			local column = placed[row]
			local t = Evolutions.Tiers[row]
			if cols[column] then
				local stand, feet = Evolutions.look(m, s, art, cols[column], t.top, t.row, {
					column = column, yaw = wobble[(column - 1) % 5 + 1], tint = Evolutions.TierColors[row],
					clip = t.centre and Evolutions.CentreStair or nil,
				})
				if row == 3 then Evolutions.sparkle(m:into(stand), cols[column], feet, t.row, Evolutions.TierColors[3].color) end
			end
		end
	end
	-- The built state is a new player's view (Lobby.client takes over at once): no full labels, the marker
	-- over the first look to unlock.
	local goal = skins.nextSkin and skins.nextSkin(0)
	for _, stand in morphs:GetChildren() do
		local anchor = stand:FindFirstChild('LabelAnchor')
		if anchor then
			anchor.WorldLabel.Enabled = false
			anchor.NextMarker.Enabled = goal ~= nil and stand.Name == 'Skin_' .. goal.Id
		end
	end
	-- Spotlights on the two lower rows: the far tower lights the far half, the wing lamps the walkway half.
	local t1, t2 = Evolutions.Tiers[1], Evolutions.Tiers[2]
	local chest = Evolutions.PadH + 3 * Evolutions.Scale
	Evolutions.lights(e, {
		{ side = 1, at = V(10.5, t1.top + chest, t1.row) },
		{ side = 1, at = V(10.5, t2.top + chest, t2.row) },
		{ side = -1, at = V(-14, t1.top + chest, t1.row) },
		{ side = -1, at = V(-7, t1.top + chest, t1.row) },
	})
	Evolutions.fog(e)
	Evolutions.sign(e)
	return model
end
---------------------------------------------------------------------------------------------- buildings
-- Building frame: origin at the front-left corner on the ground, +X along the walk, +Z out of the facade
-- toward the middle. One builder serves both sides of the map.
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

-- Window: light frame, dark blue glass with a mullion, a sill.
local function window(c, x, y, o)
	o = o or {}
	local w, h = o.w or 3.2, o.h or 4.6
	local frame = o.frame or P.frame
	decor(c:box('WindowFrame', V(x - w / 2 - 0.35, y - 0.35, 0), V(x + w / 2 + 0.35, y + h + 0.35, 0.2), frame, M.SmoothPlastic))
	decor(c:box('Glass', V(x - w / 2, y, 0), V(x + w / 2, y + h, 0.28), P.glass, M.SmoothPlastic)).Reflectance = 0.15
	decor(c:box('Mullion', V(x - 0.12, y, 0), V(x + 0.12, y + h, 0.34), frame, M.SmoothPlastic))
	decor(c:box('Sill', V(x - w / 2 - 0.6, y - 0.75, 0), V(x + w / 2 + 0.6, y - 0.35, 0.7), o.sill or P.stone, M.Concrete))
end
-- Street door with two steps and a small slate awning.
local function door(c, x, color, awning)
	c:box('Step', V(x - 2.6, 0, 0), V(x + 2.6, 0.4, 2.0), P.stone, M.Concrete)
	c:box('Step', V(x - 2.6, 0.4, 0), V(x + 2.6, 0.8, 1.0), P.stone, M.Concrete)
	decor(c:box('DoorFrame', V(x - 2.3, 0.8, 0), V(x + 2.3, 8.6, 0.22), P.frame, M.SmoothPlastic))
	c:box('Door', V(x - 1.7, 0.8, 0), V(x + 1.7, 8.0, 0.45), color or P.door, M.SmoothPlastic)
	decor(c:box('DoorKnob', V(x + 1.0, 4.2, 0.45), V(x + 1.3, 4.5, 0.6), P.lampGlow, M.Metal))
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
local function roofCap(c, w, roof, color)
	c:box('RoofCap', V(0, roof, -DEPTH), V(w, roof + 1.2, 0.7), color, M.SmoothPlastic)
	decor(c:box('RoofVent', V(w * 0.3 - 1.5, roof + 1.2, -12), V(w * 0.3 + 1.5, roof + 3.2, -8), color:Lerp(P.black, 0.3), M.Metal))
end

-- Red brick walk-up (the concept's asset kit): stone base, slate roof cap, framed windows, green door.
local function brickBuilding(ctx, w, o)
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local roof = roofOf(o.floors)
	c:box('Wall', V(0, -1, -DEPTH), V(w, roof, 0), o.wall or P.brick, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 1.6, 0.35), P.stone, M.Concrete)
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
	model:SetAttribute('Floors', o.floors)
	return c, model
end

-- Tan apartment block: buff walls, light corner piers and floor bands, a cornice, balconies with black
-- railings on the upper floors.
local function balcony(c, x, y)
	decor(c:box('BalconySlab', V(x - 3.2, y - 0.5, 0), V(x + 3.2, y, 2.8), P.tanLight, M.Concrete))
	decor(c:box('BalconyRail', V(x - 3.2, y + 2.6, 2.5), V(x + 3.2, y + 2.85, 2.8), P.iron, M.Metal))
	for _, sx in { -3.2, 2.95 } do decor(c:box('BalconyRail', V(x + sx, y + 2.6, 0), V(x + sx + 0.25, y + 2.85, 2.8), P.iron, M.Metal)) end
	for k = 0, 8 do
		local bx = x - 3.05 + k * 6.1 / 8
		decor(c:box('BalconyBar', V(bx - 0.07, y, 2.55), V(bx + 0.07, y + 2.6, 2.7), P.iron, M.Metal))
	end
end
local function tanBuilding(ctx, w, o)
	local c, model = ctx:group(o.name or 'TanApartments')
	local roof = roofOf(o.floors)
	c:box('Wall', V(0, -1, -DEPTH), V(w, roof, 0), o.wall or P.tan, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 2, 0.35), P.tanDark, M.Concrete)
	for _, x in { 0, w - 1 } do decor(c:box('Pier', V(x, 2, 0), V(x + 1, roof, 0.3), P.tanLight, M.SmoothPlastic)) end
	for f = 2, o.floors do decor(c:box('FloorBand', V(1, storeyY(f) - 0.4, 0), V(w - 1, storeyY(f) + 0.2, 0.25), P.tanLight, M.SmoothPlastic)) end
	c:box('Cornice', V(0, roof - 1.2, 0), V(w, roof + 0.6, 0.9), P.tanLight, M.SmoothPlastic)
	c:box('RoofTop', V(0, roof, -DEPTH), V(w, roof + 0.6, 0), P.tanDark, M.Concrete)
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

-- Barber: pink brick, blue band and sign, red-white-blue striped awning, the pole by the door.
local function barberShop(ctx, w)
	local c = brickBuilding(ctx, w, { name = 'Barber', floors = 2, wall = P.brickPink, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), P.barberBlue, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), P.barberBlue, M.SmoothPlastic)
	end })
	stripedAwning(c, 1.5, w - 1.5, 9.4, { C(220, 44, 44), P.white, C(220, 44, 44), P.white, P.barberBlue })
	local sign = c:box('ShopSign', V(w / 2 - 7, 10.2, 0), V(w / 2 + 7, 13.6, 0.8), P.barberBlue, M.SmoothPlastic)
	decor(c:box('ShopSignBorder', V(w / 2 - 7.3, 9.9, 0), V(w / 2 + 7.3, 13.9, 0.7), P.white, M.SmoothPlastic))
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'BARBER', P.white, FONT.loud, 0.12, 0.76, C(16, 30, 80), 3)
	-- The pole by the door, turning.
	local pole, poleModel = c:group('BarberPole')
	local p0 = V(w - 0.9, 2, 1.2)
	pole:post('PoleBody', 0.55, 5, p0, P.white, M.SmoothPlastic)
	for k = 0, 4 do
		pole:part('PoleStripe', V(0.35, 1.15, 1.15), CFrame.new(p0 + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(22), 0, 0), k % 2 == 0 and C(220, 44, 44) or P.barberBlue, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, y in { -0.3, 5 } do pole:post('PoleCap', 0.7, 0.4, p0 + V(0, y, 0), P.barberBlue, M.Metal) end
	pole:box('PoleBracket', p0 + V(-0.15, 2.4, -1.2), p0 + V(0.15, 2.7, -0.5), P.iron, M.Metal)
	poleModel:SetAttribute('Spin', 60)
	poleModel:AddTag('HoodMotion')
	poleModel.WorldPivot = c:world(CFrame.new(p0 + V(0, 2.5, 0)))
	return c
end

-- Grocery: yellow shop floor under a green upper floor, a big dark green sign, green-yellow awning,
-- a produce stand and crates out front.
local function grocery(ctx, w)
	local c, model = ctx:group('Grocery')
	local roof = roofOf(2)
	c:box('Wall', V(0, -1, -DEPTH), V(w, 12, 0), P.groceryYellow, M.SmoothPlastic)
	c:box('WallUpper', V(0, 12, -DEPTH), V(w, roof, 0), P.groceryGreen, M.SmoothPlastic)
	roofCap(c, w, roof, C(24, 104, 44))
	for _, x in bays(w, 3) do window(c, x, storeyY(2) + 3, { frame = P.white }) end
	c:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
	for x = 2 + (w - 9) / 3, w - 7.5, (w - 9) / 3 do decor(c:box('ShopMullion', V(x - 0.2, 1, 0), V(x + 0.2, 7.4, 0.4), C(24, 104, 44), M.SmoothPlastic)) end
	c:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), C(24, 104, 44), M.SmoothPlastic)
	c:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
	local sign = c:box('ShopSign', V(1, 9.8, 0), V(w - 1, 13.8, 0.9), C(24, 104, 44), M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'GROCERY', P.groceryYellow, FONT.loud, 0.12, 0.76, C(10, 50, 20), 3)
	stripedAwning(c, 0.5, w - 0.5, 9.4, { P.groceryGreen, P.groceryYellow }, 4)
	-- Produce stand and crates.
	c:box('StandTable', V(2.5, 2.4, 1), V(9.5, 2.8, 4), P.wood, M.WoodPlanks)
	for _, x in { 3, 9 } do c:box('StandLeg', V(x - 0.2, 0, 1.3), V(x + 0.2, 2.4, 3.7), P.woodDark, M.Wood) end
	local fruit = { C(230, 60, 50), C(250, 150, 40), C(120, 200, 60), C(250, 210, 60) }
	for k = 0, 3 do
		local x = 3.2 + k * 1.6
		c:box('ProduceBox', V(x - 0.7, 2.8, 1.4), V(x + 0.7, 3.4, 3.6), P.crate, M.WoodPlanks)
		decor(c:box('Produce', V(x - 0.55, 3.4, 1.55), V(x + 0.55, 3.8, 3.45), fruit[k + 1], M.SmoothPlastic))
	end
	crate(c, CFrame.new(w - 9, 0, 2.4), 2.4)
	crate(c, CFrame.new(w - 9, 2.4, 2.4) * CFrame.Angles(0, 0.3, 0), 2)
	model:SetAttribute('Floors', 2)
	return c
end

-- Blue corner shop (behind the grocery in the concept).
local function blueShop(ctx, w, label)
	local c = brickBuilding(ctx, w, { name = 'BlueShop', floors = 2, wall = P.shopBlue, ground = function(c2)
		c2:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		c2:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
		c2:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), P.white, M.SmoothPlastic)
	end })
	local sign = c:box('ShopSign', V(2, 9.6, 0), V(w - 2, 12.6, 0.6), C(22, 36, 90), M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', label, P.white, FONT.loud, 0.14, 0.72)
	decor(c:wedge('Awning', V(w - 4, 1.4, 3), CFrame.new(w / 2, 8.6, 1.5) * CFrame.Angles(0, math.pi, 0), C(30, 56, 140), M.Fabric))
	return c
end

-- Blue corrugated warehouse with a roll-up door, a light bar and a side door.
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
	decor(c:box('LightBar', V(dx - 3, 16, 0), V(dx + 3, 16.6, 0.6), C(255, 210, 60), M.Neon))
	c:box('SideDoorFrame', V(w - 8.6, 0, 0), V(w - 3.4, 9, 0.35), P.warehouseDark, M.Metal)
	c:box('SideDoor', V(w - 8, 0, 0), V(w - 4, 8.2, 0.45), C(30, 56, 120), M.Metal)
	local lampBox = c:box('WallLamp', V(w - 7, 10.6, 0), V(w - 5, 11.4, 1.2), P.iron, M.Metal)
	decor(c:box('WallLampGlow', V(w - 6.8, 10.4, 0.2), V(w - 5.2, 10.6, 1.1), C(255, 230, 160), M.Neon))
	light(lampBox, C(255, 230, 160), 1, 12)
	model:SetAttribute('Floors', 2)
	return c
end

-- Shop with a striped awning and a framed sign (the barber's look, reused down Shop Street).
-- o: sign, signColor, textColor, wall, trim, stripes, floors, extra ('crates' | 'pole')
local function shopBuilding(ctx, w, o)
	local trim = o.trim or o.signColor
	local c = brickBuilding(ctx, w, { name = 'Shop_' .. o.sign:gsub('%W', ''), floors = o.floors or 2, wall = o.wall or P.brick, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), trim, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), trim, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), trim, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), trim, M.SmoothPlastic)
	end })
	stripedAwning(c, 1.5, w - 1.5, 9.4, o.stripes)
	local sw = math.min(w / 2 - 1.5, 2.5 + #o.sign * 0.85)
	local sign = c:box('ShopSign', V(w / 2 - sw, 10.2, 0), V(w / 2 + sw, 13.6, 0.8), o.signColor, M.SmoothPlastic)
	decor(c:box('ShopSignBorder', V(w / 2 - sw - 0.3, 9.9, 0), V(w / 2 + sw + 0.3, 13.9, 0.7), P.white, M.SmoothPlastic))
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', o.sign, o.textColor or P.white, FONT.loud, 0.12, 0.76, o.signColor:Lerp(P.black, 0.6), 3)
	if o.extra == 'crates' then
		crate(c, CFrame.new(3.5, 0, 2.6), 2.4)
		crate(c, CFrame.new(3.5, 2.4, 2.6) * CFrame.Angles(0, 0.3, 0), 2)
	end
	return c
end

-- A lot of stacked shipping containers behind a low wall, crates out front (the yards' side "buildings").
local function containerLot(ctx, w, seed)
	local c = ctx:group('ContainerLot')
	c:box('LotFloor', V(0, -1, -DEPTH), V(w, 0.06, 0), C(176, 178, 184), M.Concrete)
	c:box('LotWall', V(0, -1, -DEPTH), V(w, 6, -DEPTH + 2), P.wall, M.Concrete)
	local colors = { P.containerBlue, P.containerRed, C(60, 150, 90), P.containerRed }
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
---------------------------------------------------------------------------------------------- warehouse lobby
-- World 1's spawn: the HOOD BOXING CLUB, an old warehouse at the south end of the street, painted bright: sky-
-- blue corrugated walls on red steel columns, white trusses with yellow chords under a glass-and-white roof,
-- gym-turf yards, pallet racks and containers round the edges, and a raised studded deck in a cross: the big
-- north door (out to Stage 1) down to the ARMORY platform, the spawn badge where it crosses the training
-- aisle. West: the training platform (two bands of four bag stations facing a red runner, the cardio corner
-- with three treadmills on a raised bump at the west end). East: the EVOLUTIONS podium. By the door: reward
-- crates. South-west: the WORLD 2 garage, south-east: the champ statue and three leaderboards. Murals on the
-- walls, marquee bulbs round the club signs, a giant glove over the ridge.
-- Builders from other files (Stations, Treadmills, Evolutions, Armory) fill the slots; a missing or failing
-- one leaves a labelled placeholder box of the slot's size.
-- Map frame (studs): interior x -66..66, z 6..156 (north wall z 5..6, the Stage 1 gate at z = 0 stays
-- outside), floor top y = 0, deck top y = Lobby.Deck. North = -Z.
-- Lobby.Slots: name -> CFrame in the map frame (V2.Origin * cf is the world), filled by Lobby.build.
-- Colour rule (critic): nothing bigger than ~10 studs² darker than luminance 0.2 except screens; no Metal on
-- big surfaces (it renders dark grey indoors).
local Lobby = {}

Lobby.W = 66 -- interior half width (walls x ±66..±67)
Lobby.N, Lobby.S = 6, 156 -- interior north and south faces
Lobby.Eave, Lobby.Ridge = 30, 38
Lobby.Deck = SPAWN.Y -- walkway and platform top (1.2)
Lobby.Walk = 4.5 -- the N-S walkway's half width
Lobby.CrossZ = SPAWN.Z -- the crossing (E-W band z ±6 round it)
Lobby.Door, Lobby.DoorH = 12, 20 -- north door half width and height
Lobby.Bay = 15 -- column / truss spacing along z, from z = 6
Lobby.PlatZ = { 28, 92 } -- training and podium decks run z 28..92
Lobby.Slots = {}
Lobby.Colors = {
	floor = C(214, 190, 150), deck = C(212, 215, 221), rim = C(80, 84, 98), groove = C(110, 116, 130),
	wall = C(108, 180, 236), facade = C(124, 194, 242), ridge = C(165, 220, 250), block = C(226, 226, 230), hazard = C(250, 196, 32),
	column = C(240, 84, 66), truss = C(58, 62, 72), frame = C(236, 238, 242), chord = C(255, 190, 30),
	glass = C(186, 224, 246), roofGlass = C(200, 236, 255), steel = C(200, 204, 212),
	rackPost = C(40, 92, 196), rackBeam = C(244, 124, 34),
	turf = C(88, 190, 70), turfEdge = C(60, 150, 50), plinth = C(150, 156, 168), plinthRim = C(96, 102, 116),
	warm = C(255, 196, 120), cool = C(80, 220, 255), pink = C(255, 70, 170), lime = C(150, 255, 70),
	gold = C(255, 204, 48), red = C(222, 44, 52), blue = C(40, 110, 220),
	containerRed = C(224, 72, 60), containerBlue = C(70, 140, 230),
}
-- Training: two bands of four long bag stations (9 x 20 slots, 10.5 apart) facing each other across the
-- aisle; walking order from the spawn end: north band Starter..Heavy, south band Gold..Speed (gold nearest the
-- spawn on the south band). Treadmills 8.5 apart on the cardio bump at the aisle's west end, belts facing the
-- west wall.
Lobby.Bags = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.RowX = { -12.25, -22.75, -33.25, -43.75 }
Lobby.RowZ = { 39, 81 }
Lobby.Treadmills = { 'Jog', 'Run', 'Sprint' }
Lobby.TreadZ = { 51.5, 60, 68.5 }
Lobby.TreadX = -57
Lobby.CardioTop = 0.6 -- the cardio plinth's height over the deck

---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top.
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
-- Neon tube round a board (cf as in Lobby.board), slightly in front of it.
function Lobby.neonFrame(c, cf, w, h, color, t)
	t = t or 0.3
	local z = -0.25
	for _, e in { { 0, h / 2, w + t, t }, { 0, -h / 2, w + t, t }, { -w / 2, 0, t, h + t }, { w / 2, 0, t, h + t } } do
		decor(c:part('SignNeon', V(e[3], e[4], t), cf * CFrame.new(e[1], e[2], z), color, M.Neon)).CastShadow = false
	end
end
-- Neon sign: a board in a deep tint of the tube colour, glowing text, neon tube border.
function Lobby.neonSign(c, cf, w, h, text, color, sub)
	local rows = { { 'Title', text, color:Lerp(P.white, 0.35), FONT.loud, sub and 0.06 or 0.12, sub and 0.6 or 0.76, color:Lerp(P.black, 0.5), 4 } }
	if sub then table.insert(rows, { 'Sub', sub, P.white, FONT.title, 0.68, 0.26, P.black, 2 }) end
	local b = Lobby.board(c, 'NeonSign', cf, w, h, color:Lerp(P.black, 0.72), rows, 14)
	Lobby.neonFrame(c, cf, w, h, color)
	return b
end
-- Marquee bulbs round a board (cf as in Lobby.board): gold and pink in turn, cycling hue (HoodMotion Hue).
function Lobby.marquee(c, cf, w, h, step)
	local g, model = c:group('Marquee')
	local pts = {}
	local hw, hh = w / 2 + 0.9, h / 2 + 0.9
	for x = -hw, hw, step do table.insert(pts, V(x, hh, 0)); table.insert(pts, V(x, -hh, 0)) end
	for y = -hh + step, hh - step / 2, step do table.insert(pts, V(-hw, y, 0)); table.insert(pts, V(hw, y, 0)) end
	for k, p in pts do
		decor(g:part('Bulb', V(0.7, 0.7, 0.7), cf * CFrame.new(p.X, p.Y, -0.45), k % 2 == 0 and Lobby.Colors.gold or C(255, 80, 170), M.Neon, Enum.PartType.Ball)).CastShadow = false
	end
	model:SetAttribute('Hue', 2.5)
	model:AddTag('HoodMotion')
	return model
end
-- Poster: a coloured sheet with lines { text, color, font, y, h } (cf as in Lobby.board).
function Lobby.poster(c, cf, w, h, bg, rows)
	local list = {}
	for i, r in rows do list[i] = { 'Line' .. i, r[1], r[2], r[3], r[4], r[5], r[6] or P.black, 2 } end
	local p = decor(Lobby.board(c, 'Poster', cf, w, h, bg, list, 24))
	decor(c:part('PosterTape', V(w * 0.3, 0.5, 0.32), cf * CFrame.new(0, h / 2 - 0.1, 0) * CFrame.Angles(0, 0, 0.12), C(236, 230, 200), M.SmoothPlastic))
	return p
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
-- Soft light pillar over a showpiece (a tall see-through neon cylinder).
function Lobby.pillar(c, pos, h, color)
	local p = decor(c:part('LightPillar', V(h, 2.4, 2.4), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, M.Neon, Enum.PartType.Cylinder))
	p.Transparency, p.CastShadow = 0.55, false
	local ring = decor(c:part('LightHalo', V(0.2, 7, 7), CFrame.new(pos + V(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, M.Neon, Enum.PartType.Cylinder))
	ring.Transparency, ring.CastShadow = 0.35, false
	return p
end

---------------------------------------------------------------------------------------------- shell
-- Floor, walls, columns, door, roof. Roof parts are all named Roof* (the plan views hide them).
function Lobby.shell(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.Eave
	local s = L:group('Warehouse')
	-- Floor: one studded slab of warm sand epoxy.
	Lobby.slab(s, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.floor)

	-- A wall run: core, block wainscot with a hazard band, corrugated upper panel (light ridges between
	-- columns). f(u, y, w): u along the wall, w = distance into the room from the interior face.
	local function run(f, u0, u1, y0, y1, ridgesOut, color)
		s:box('Wall', f(u0, y0, -1), f(u1, y1, 0), color or K.wall, M.SmoothPlastic)
		if y0 < 7 then
			s:box('WallBlock', f(u0, y0, 0), f(u1, math.min(7, y1), 0.3), K.block, M.Concrete)
			s:box('WallBand', f(u0, 6.9, 0), f(u1, 7.5, 0.42), K.hazard, M.SmoothPlastic)
			s:box('WallBand', f(u0, 0, 0), f(u1, 0.6, 0.42), K.rim, M.SmoothPlastic)
		end
		local lo = math.max(y0, 7.5)
		for u = u0 + 2, u1 - 1, 4 do
			local du = (u - Lobby.N) % Lobby.Bay
			if du > 1.4 and du < Lobby.Bay - 1.4 then
				decor(s:box('WallRidge', f(u - 0.3, lo, 0), f(u + 0.3, y1 - 0.4, 0.3), K.ridge, M.SmoothPlastic))
				if ridgesOut then decor(s:box('WallRidge', f(u - 0.3, lo, -1.3), f(u + 0.3, y1 - 0.4, -1), K.ridge, M.SmoothPlastic)) end
			end
		end
	end
	local function side(x, dir) return function(u, y, w) return V(x - dir * w, y, u) end end
	local function finish(z, dir) return function(u, y, w) return V(u, y, z + dir * w) end end
	local west, east = side(-W, -1), side(W, 1)
	local north, south = finish(N, 1), finish(S, -1)
	run(west, N - 1, S + 1, 0, H)
	run(east, N - 1, S + 1, 0, H)
	run(south, -W, W, 0, H, false, K.facade)
	-- The end walls (the street facade and the south wall) get the low sun only at an angle: a lighter blue
	-- so they don't read as dark slabs.
	run(north, -W, -Lobby.Door, 0, H, true, K.facade)
	run(north, Lobby.Door, W, 0, H, true, K.facade)
	run(north, -Lobby.Door, Lobby.Door, Lobby.DoorH, H, true, K.facade)
	-- Gable ends up to the ridge.
	for _, z in { N - 0.5, S + 0.5 } do
		for _, sx in { -1, 1 } do
			s:wedge('RoofGable', V(1, Lobby.Ridge - H, W + 1), CFrame.new(sx * (W + 1) / 2, (H + Lobby.Ridge) / 2, z) * CFrame.Angles(0, -sx * math.pi / 2, 0), K.facade, M.SmoothPlastic)
		end
	end
	-- Columns on the side walls (and two wind columns on each end wall), hazard-wrapped feet.
	local function column(f, u)
		s:box('Column', f(u - 0.8, 0, 0), f(u + 0.8, H + 0.6, 1.2), K.column, M.SmoothPlastic)
		s:box('ColumnFoot', f(u - 1.0, 0, 0), f(u + 1.0, 2.6, 1.4), K.hazard, M.SmoothPlastic)
		decor(s:box('ColumnStripe', f(u - 1.05, 1.0, 0), f(u + 1.05, 1.5, 1.45), P.black, M.SmoothPlastic))
	end
	for z = N, S, Lobby.Bay do
		column(west, z == N and N + 0.8 or z == S and S - 0.8 or z)
		column(east, z == N and N + 0.8 or z == S and S - 0.8 or z)
	end
	for _, x in { -33, 33 } do column(north, x); column(south, x) end
	-- Clerestory windows high on the side walls, in the bays the signs, murals and fans leave free.
	for _, e in { { west, { 28.5, 88.5, 118.5 } }, { east, { 28.5, 88.5 } } } do
		for _, zc in e[2] do
			local f = e[1]
			s:box('WindowFrame', f(zc - 5.4, 20.6, -1.15), f(zc + 5.4, 27.4, 0.35), K.frame, M.SmoothPlastic)
			local g = decor(s:box('Window', f(zc - 4.9, 21.1, -1.25), f(zc + 4.9, 26.9, 0.45), K.glass, M.Glass))
			g.Transparency = 0.25
			for _, du in { -1.6, 1.6 } do decor(s:box('WindowBar', f(zc + du - 0.15, 21.1, -1.3), f(zc + du + 0.15, 26.9, 0.5), K.frame, M.SmoothPlastic)) end
		end
	end
	-- The north door: rolled-up door drum, guide rails, a yellow frame round the opening on both faces,
	-- hazard-striped jambs, floor stripes outside.
	local d = s:group('NorthDoor')
	d:box('DoorDrum', V(-Lobby.Door - 1, Lobby.DoorH, N), V(Lobby.Door + 1, Lobby.DoorH + 2.6, N + 2.4), K.steel, M.SmoothPlastic)
	d:box('DoorLip', V(-Lobby.Door, Lobby.DoorH - 0.6, N), V(Lobby.Door, Lobby.DoorH, N + 1.6), C(150, 154, 162), M.SmoothPlastic)
	for _, z in { N - 1.5, N + 0.05 } do
		d:box('DoorFrame', V(-Lobby.Door - 1.6, Lobby.DoorH, z), V(Lobby.Door + 1.6, Lobby.DoorH + 1.4, z + 0.45), K.gold, M.SmoothPlastic)
		for _, sx in { -1, 1 } do d:box('DoorFrame', V(sx * Lobby.Door - 0.8, 0, z), V(sx * Lobby.Door + sx * 1.6, Lobby.DoorH, z + 0.45), K.gold, M.SmoothPlastic) end
	end
	for _, sx in { -1, 1 } do
		local x = sx * Lobby.Door
		d:box('DoorRail', V(x - 0.5, 0, N + 0.5), V(x + 0.5, Lobby.DoorH, N + 1.4), K.steel, M.SmoothPlastic)
		for k = 0, 4 do
			d:box('JambStripe', V(x - 0.8 * sx - 0.6, k * 4, N - 1.4), V(x - 0.8 * sx + 0.6, k * 4 + 2, N + 0.1), k % 2 == 0 and K.hazard or P.black, M.SmoothPlastic)
		end
	end
	for x = -Lobby.Door + 1.5, Lobby.Door - 1.5, 3 do
		decor(d:part('DoorHazard', V(1.2, 0.05, 3.2), CFrame.new(x, 0.02, N - 2.4) * CFrame.Angles(0, math.rad(35), 0), K.hazard, M.SmoothPlastic))
	end
	-- Wing walls from the gate posts to the warehouse: the forecourt is closed on both sides.
	for _, sx in { -1, 1 } do
		s:box('WingWall', V(sx * 34.4, 0, 0.6), V(sx * 36, 12, N - 1), K.block, M.Concrete)
		s:box('WingCap', V(sx * 34.2, 12, 0.6), V(sx * 36.2, 12.6, N - 1), K.hazard, M.SmoothPlastic)
		local pole = s:box('WingLamp', V(sx * 35.2 - 0.4, 12.6, 2), V(sx * 35.2 + 0.4, 13.4, 3.4), K.steel, M.SmoothPlastic)
		light(pole, K.warm, 0.8, 14)
	end

	-- Roof: white trusses with yellow bottom chords on every inner column line, white purlins, all glass
	-- above them (the eaves and a long skylight down the middle). The glass casts no shadow, so the sun
	-- reaches the floor through the trusses.
	local function topY(x) return H + 0.3 + (Lobby.Ridge - H - 0.3) * (1 - math.abs(x) / W) end
	local r = L:group('Roof')
	for z = N + Lobby.Bay, S - Lobby.Bay, Lobby.Bay do
		r:box('RoofChord', V(-W, H - 0.6, z - 0.3), V(W, H, z + 0.3), K.chord, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			r:bar('RoofTop', V(sx * W, H, z), V(0, Lobby.Ridge, z), 0.7, K.frame, M.SmoothPlastic)
			for _, x in { 16.5, 33, 49.5 } do
				r:box('RoofWeb', V(sx * x - 0.2, H, z - 0.2), V(sx * x + 0.2, topY(x), z + 0.2), K.frame, M.SmoothPlastic)
				r:bar('RoofWeb', V(sx * x, H - 0.3, z), V(sx * (x - 16.5), topY(x - 16.5) - 0.2, z), 0.35, K.frame, M.SmoothPlastic)
			end
		end
		r:box('RoofWeb', V(-0.25, H, z - 0.25), V(0.25, Lobby.Ridge, z + 0.25), K.frame, M.SmoothPlastic)
	end
	for _, x in { -49.5, -33, -16.5, 0, 16.5, 33, 49.5 } do
		r:box('RoofPurlin', V(x - 0.3, topY(x), N - 1), V(x + 0.3, topY(x) + 0.6, S + 1), K.frame, M.SmoothPlastic)
	end
	for _, sx in { -1, 1 } do
		local a, b = V(sx * (W + 1.5), H + 0.6, (N + S) / 2), V(sx * 33, topY(33) + 0.6, (N + S) / 2)
		local sheet = r:part('RoofSheet', V(S - N + 3, 0.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), K.roofGlass, M.Glass)
		sheet.Transparency, sheet.CastShadow = 0.7, false
		local a2, b2 = V(sx * 33, topY(33) + 0.6, (N + S) / 2), V(0, Lobby.Ridge + 0.6, (N + S) / 2)
		local glass = r:part('RoofSkylight', V(S - N + 3, 0.3, (b2 - a2).Magnitude), CFrame.lookAt((a2 + b2) / 2, b2), K.roofGlass, M.Glass)
		glass.Transparency, glass.CastShadow = 0.7, false
		r:box('RoofGutter', V(sx * W - 1.6, H, N - 1.5), V(sx * W + 1.6, H + 0.8, S + 1.5), K.frame, M.SmoothPlastic).CastShadow = false
	end
	r:box('RoofRidgeCap', V(-1.2, Lobby.Ridge + 0.4, N - 1.5), V(1.2, Lobby.Ridge + 1.2, S + 1.5), K.frame, M.SmoothPlastic).CastShadow = false
	return s
end

---------------------------------------------------------------------------------------------- deck
-- The raised studded deck: walkways and platforms in light tiles, darker rims on every outside edge, grooves
-- where the walkway passes the platforms, two low steps down to the floor. The training deck has the
-- reference's bump: the cardio corner sticks out west between the station bands.
function Lobby.deck(L)
	local K, D, w = Lobby.Colors, Lobby.Deck, Lobby.Walk
	local d = L:group('Deck')
	local cz = Lobby.CrossZ
	local z0, z1 = Lobby.PlatZ[1], Lobby.PlatZ[2]
	local function top(name, x0, x1, za, zb) return Lobby.slab(d, name, V(x0, 0, za), V(x1, D, zb), K.deck) end
	local function rim(a, b) return Lobby.slab(d, 'DeckRim', a, b, K.rim) end
	local RW = 0.8
	-- Rims: n/s run along x at z, w/e run along z at x (the rim lies inside the region's edge).
	local function rimN(x0, x1, z) rim(V(x0, 0, z), V(x1, D + 0.04, z + RW)) end
	local function rimS(x0, x1, z) rim(V(x0, 0, z - RW), V(x1, D + 0.04, z)) end
	local function rimW(za, zb, x) rim(V(x, 0, za), V(x + RW, D + 0.04, zb)) end
	local function rimE(za, zb, x) rim(V(x - RW, 0, za), V(x, D + 0.04, zb)) end
	local walkS = 117
	-- N-S walkway, the crossing band, the training deck and its bump, the podium deck, the armory platform.
	top('Walkway', -w, w, Lobby.N + 1.2, walkS)
	top('Crossing', -6, 6, cz - 6, cz + 6)
	top('TrainingDeck', -49, -6, z0, z1)
	top('TrainingBump', -65.5, -49, 42, 78)
	top('PodiumDeck', 6, 65.5, z0, z1)
	top('ArmoryDeck', -30, 30, walkS, 147)
	rimW(Lobby.N + 1.2, cz - 6, -w); rimW(cz + 6, walkS, -w)
	rimE(Lobby.N + 1.2, cz - 6, w); rimE(cz + 6, walkS, w)
	rimN(-49, -6, z0); rimS(-49, -6, z1)
	rimE(z0, cz - 6, -6); rimE(cz + 6, z1, -6)
	rimW(z0, 42, -49); rimW(78, z1, -49)
	rimN(-65.5, -49, 42); rimS(-65.5, -49, 78); rimW(42, 78, -65.5)
	rimN(6, 65.5, z0); rimS(6, 65.5, z1)
	rimW(z0, cz - 6, 6); rimW(cz + 6, z1, 6); rimE(z0, z1, 65.5)
	for _, sx in { -1, 1 } do
		local g0, g1 = math.min(sx * w, sx * 6), math.max(sx * w, sx * 6)
		d:box('DeckGroove', V(g0, 0, z0), V(g1, D - 0.35, cz - 6), K.groove, M.SmoothPlastic)
		d:box('DeckGroove', V(g0, 0, cz + 6), V(g1, D - 0.35, z1), K.groove, M.SmoothPlastic)
		local q0, q1 = math.min(sx * w, sx * 30), math.max(sx * w, sx * 30)
		rimN(q0, q1, walkS)
	end
	rimW(walkS, 147, -30); rimE(walkS, 147, 30); rimS(-30, 30, 147)
	-- Stairs: two low steps in front of the deck edge where people come up from the floor.
	local function stairX(x0, x1, z, dir) -- deck edge along x at z, the floor toward dir (-1 north, 1 south)
		for k = 1, 2 do
			local za, zb = z + dir * (k - 1) * 1.2, z + dir * k * 1.2
			Lobby.slab(d, 'DeckStep', V(x0, 0, math.min(za, zb)), V(x1, D * (3 - k) / 3, math.max(za, zb)), K.rim)
		end
	end
	local function stairZ(za, zb, x, dir) -- deck edge along z at x, the floor toward dir (-1 west, 1 east)
		for k = 1, 2 do
			local xa, xb = x + dir * (k - 1) * 1.2, x + dir * k * 1.2
			Lobby.slab(d, 'DeckStep', V(math.min(xa, xb), 0, za), V(math.max(xa, xb), D * (3 - k) / 3, zb), K.rim)
		end
	end
	stairX(-w, w, Lobby.N + 1.2, -1) -- the door end of the walkway
	stairZ(13, 23, -w, -1); stairZ(13, 23, w, 1) -- to the reward crates
	stairZ(98, 110, -w, -1); stairZ(98, 110, w, 1) -- to the WORLD 2 garage and the statue
	stairX(30, 42, z0, -1); stairX(14, 26, z1, 1) -- the podium deck's north and south sides
	stairZ(126, 138, -30, -1); stairZ(126, 138, 30, 1) -- armory platform ends (the reference's side stairs)
	-- Yellow kerb paint along the walkway where it runs on its own (north and south of the platforms).
	for _, seg in { { Lobby.N + 2, z0 - 1 }, { z1 + 1, walkS - 1 } } do
		for _, sx in { -1, 1 } do
			decor(d:box('KerbPaint', V(sx * (w + 0.05) - 0.06, 0.15, seg[1]), V(sx * (w + 0.05) + 0.06, D - 0.15, seg[2]), K.hazard, M.SmoothPlastic))
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- spawn badge
-- Our logo at the crossing: a royal-blue plate, a slowly turning gold eight-point star, a red "+1" disc in a cyan
-- neon ring. The spawn faces 25° west of north, so the first frame is the north bag band and the door.
function Lobby.badge(L)
	local D, cz = Lobby.Deck, Lobby.CrossZ
	local b = L:at(CFrame.new(0, D, cz)):group('SpawnBadge')
	b:box('BadgePlate', V(-5.6, 0, -5.6), V(5.6, 0.06, 5.6), C(56, 104, 226), M.SmoothPlastic)
	decor(b:part('BadgeRing', V(0.1, 10.6, 10.6), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Lobby.Colors.cool, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	decor(b:part('BadgeInner', V(0.12, 9.6, 9.6), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), C(56, 104, 226), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	local st, star = b:group('BadgeSpin')
	for k = 0, 1 do
		decor(st:part('BadgeStar', V(6.4, 0.14, 6.4), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.pi / 8 + k * math.pi / 4, 0), Lobby.Colors.gold, M.SmoothPlastic)).CastShadow = false
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		decor(st:part('BadgeRay', V(0.5, 0.13, 2), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -5.0), Lobby.Colors.gold, M.Neon)).CastShadow = false
	end
	Lobby.motion(star, CFrame.new(0, D, cz), 12)
	local disc = decor(b:part('BadgeDisc', V(0.2, 4.6, 4.6), CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.pi / 2), C(222, 44, 52), M.SmoothPlastic, Enum.PartType.Cylinder))
	disc.CastShadow = false
	local face = ghost(b:box('BadgeText', V(-2.1, 0.24, -2.1), V(2.1, 0.26, 2.1), P.white))
	face.CastShadow = false
	local g = surface(face, Enum.NormalId.Top, 40)
	line(g, 'Text', '+1', P.white, FONT.loud, 0.12, 0.76, C(90, 10, 20), 4)
	-- Rising glints round the ring (a soft "you are here").
	local fxBox = Lobby.emitBox(b, 'BadgeFx', V(-5, 0.2, -5), V(5, 0.6, 5))
	Lobby.fx(fxBox, 'BadgeGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(1.5, 3),
		Size = Lobby.seq({ { 0, 0.5 }, { 1, 0 } }), Transparency = Lobby.seq({ { 0, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(C(140, 230, 255)),
		LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10) })
	-- The spawn point itself (StageService and SetActive use it).
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.3, 0)) * CFrame.Angles(0, math.rad(25), 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = b.parent
	-- Back to where you got to, for returning players: on the walkway just north of the badge.
	teleportPad(L:at(CFrame.new(0, D, 0)), 'FurthestPad', 0, cz - 13, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
	return b
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
function Lobby.slots(L, skins)
	local D, K = Lobby.Deck, Lobby.Colors
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	-- Bags: the north band faces south (turned round), the south band faces north, both into the aisle.
	for i, id in Lobby.Bags do
		local north = i <= 4
		local x = Lobby.RowX[north and i or 9 - i]
		local cf = CFrame.new(x, D, Lobby.RowZ[north and 1 or 2]) * (north and CFrame.Angles(0, math.pi, 0) or CFrame.new())
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Bag_' .. id, cf, { X = 9, Y = 12, Z0 = -10, Z1 = 10 }, string.upper(s and s.Name or id), C(90, 200, 120),
			Stations and function(c) Stations.build(c, id, {}) end)
	end
	-- Cardio corner: a light studded concrete plinth on the bump, three treadmills facing the west wall.
	local cardio = L:group('CardioCorner')
	local top = D + Lobby.CardioTop
	Lobby.slab(cardio, 'CardioPlinth', V(-64.7, 0, 44), V(-48.5, top, 76), K.plinth)
	for _, e in { { V(-64.7, 0, 44), V(-48.5, top + 0.04, 44.8) }, { V(-64.7, 0, 75.2), V(-48.5, top + 0.04, 76) }, { V(-49.3, 0, 44.8), V(-48.5, top + 0.04, 75.2) } } do
		Lobby.slab(cardio, 'CardioRim', e[1], e[2], K.plinthRim)
	end
	decor(cardio:box('CardioEdge', V(-48.6, D + 0.1, 44.8), V(-48.3, top - 0.1, 75.2), K.lime, M.Neon)).CastShadow = false
	for i, id in Lobby.Treadmills do
		local cf = CFrame.new(Lobby.TreadX, top, Lobby.TreadZ[i]) * CFrame.Angles(0, -math.pi / 2, 0)
		Lobby.place(L, training, 'Treadmill_' .. id, cf, { X = 7, Y = 6, Z0 = -7, Z1 = 7 }, 'TREADMILL ' .. string.upper(id), C(80, 170, 255),
			Treadmills and function(c) Treadmills.build(c, id, {}) end)
	end
	-- Evolutions podium on the east platform, front to the south like the reference (rows rise toward the
	-- north wall); its back gets the EVOLVE hoarding that faces the street door.
	Lobby.place(L, L.parent, 'Evolutions', CFrame.new(36, D, Lobby.CrossZ + 16) * CFrame.Angles(0, math.pi, 0), { X = 56, Y = 8, Z0 = 0, Z1 = 32 }, 'EVOLUTIONS', C(80, 220, 255),
		Evolutions and function(c) Evolutions.build(c, {}) end)
	-- Armory on the south platform, front to the walkway.
	Lobby.place(L, L.parent, 'Armory', CFrame.new(0, D, 123), { X = 48, Y = 6, Z0 = -2, Z1 = 18 }, 'ARMORY', C(255, 90, 160),
		Armory and function(c) Armory.build(c, {}) end)
end

-- The training aisle: a wide red runner with gold borders from the crossing to the cardio corner, two
-- painted gold gloves on it, white tape lanes in front of the station bands.
function Lobby.aisle(L)
	local K, D = Lobby.Colors, Lobby.Deck
	local a = L:group('TrainingAisle')
	local z0, z1 = Lobby.CrossZ - 7, Lobby.CrossZ + 7
	a:box('Runner', V(-48.5, D, z0), V(-6, D + 0.06, z1), C(232, 60, 68), M.Fabric)
	for _, z in { z0, z1 - 0.7 } do decor(a:box('RunnerBorder', V(-48.5, D, z), V(-6, D + 0.08, z + 0.7), K.gold, M.SmoothPlastic)).CastShadow = false end
	local word = ghost(a:box('RunnerWord', V(-36, D + 0.1, z0 + 1.5), V(-18, D + 0.12, z1 - 1.5), P.white))
	line(surface(word, Enum.NormalId.Top, 10), 'Text', 'TRAIN  •  +1', C(255, 230, 230), FONT.loud, 0.1, 0.8)
	-- Painted gloves: a fist, a thumb and a white cuff, flat on the runner, punching toward the crossing.
	for _, x in { -43, -11 } do
		local g = a:group('RunnerGlove')
		for _, e in { { 'GlovePaint', V(x - 2.2, D, -2.4), V(x + 2.4, D + 0.1, 2.4), K.gold }, { 'GlovePaint', V(x - 1.2, D, 2.4), V(x + 1.6, D + 0.1, 3.6), K.gold },
			{ 'GloveCuffPaint', V(x - 4.2, D, -2), V(x - 2.2, D + 0.1, 2), P.white } } do
			decor(g:box(e[1], e[2] + V(0, 0, Lobby.CrossZ), e[3] + V(0, 0, Lobby.CrossZ), e[4], M.SmoothPlastic)).CastShadow = false
		end
	end
	for _, z in { z0 - 3.2, z1 + 2.8 } do decor(a:box('TapeLane', V(-48, D, z), V(-7, D + 0.05, z + 0.4), P.white, M.SmoothPlastic)).CastShadow = false end
	return a
end

---------------------------------------------------------------------------------------------- props
-- Pallet rack along cf's +X: blue uprights, orange beams, three decks of mixed stock. Front faces -Z.
function Lobby.rack(c, cf, bays, seed)
	local K = Lobby.Colors
	local r = c:at(cf):group('PalletRack')
	local bw, dep, levels = 7.5, 4.2, { 0.3, 4.8, 9.3 }
	local len = bays * bw
	local rnd = Random.new(seed)
	for k = 0, bays do
		for _, z in { 0, dep - 0.4 } do r:box('RackPost', V(k * bw - 0.2, 0, z), V(k * bw + 0.2, 13.6, z + 0.4), K.rackPost, M.SmoothPlastic) end
	end
	for _, y in levels do
		if y > 1 then
			for _, z in { -0.1, dep - 0.3 } do r:box('RackBeam', V(0, y - 0.5, z), V(len, y, z + 0.4), K.rackBeam, M.SmoothPlastic) end
			r:box('RackDeck', V(0, y - 0.1, 0.2), V(len, y, dep - 0.2), C(150, 156, 168), M.DiamondPlate)
		end
		for k = 0, bays - 1 do
			local x0 = k * bw + 0.6
			local kind = rnd:NextInteger(1, 4)
			if kind == 1 then -- boxes on a pallet
				r:box('RackPallet', V(x0, y, 0.5), V(x0 + 6.2, y + 0.5, dep - 0.5), P.woodDark, M.Wood)
				r:box('RackBoxes', V(x0 + 0.3, y + 0.5, 0.7), V(x0 + 3.2, y + 3.2, dep - 0.7), P.crate, M.Cardboard)
				r:box('RackBoxes', V(x0 + 3.3, y + 0.5, 0.9), V(x0 + 5.9, y + 2.4, dep - 0.6), P.crate:Lerp(P.white, 0.15), M.Cardboard)
			elseif kind == 2 then -- drums
				for j = 0, 2 do r:post('RackDrum', 0.95, 2.9, V(x0 + 1.1 + j * 2.05, y, dep / 2), ({ C(40, 110, 200), C(206, 50, 44), C(60, 150, 80) })[rnd:NextInteger(1, 3)], M.SmoothPlastic) end
			elseif kind == 3 then -- tyres
				for j = 0, 1 do
					for t = 0, rnd:NextInteger(1, 3) do r:part('RackTyre', V(0.7, 2.6, 2.6), CFrame.new(x0 + 1.6 + j * 3.1, y + 0.35 + t * 0.7, dep / 2) * CFrame.Angles(0, 0, math.pi / 2), C(44, 44, 50), M.SmoothPlastic, Enum.PartType.Cylinder) end
				end
			else -- sacks and a crate
				r:box('RackSacks', V(x0 + 0.2, y, 0.6), V(x0 + 3.4, y + 1.6, dep - 0.6), C(214, 200, 160), M.Fabric)
				r:box('RackCrate', V(x0 + 3.6, y, 0.5), V(x0 + 6.2, y + 2.8, dep - 0.5), C(70, 150, 80), M.WoodPlanks)
			end
		end
	end
	return r
end
-- A stack of tyres.
function Lobby.tyres(c, pos, n)
	local t = c:group('Tyres')
	for k = 0, n - 1 do
		t:part('Tyre', V(0.8, 3, 3), CFrame.new(pos + V(k % 2 * 0.25, 0.4 + k * 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(44, 44, 50), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	return t
end
-- Oil drum with two bands.
function Lobby.drum(c, pos, color)
	local t = c:group('Drum')
	t:post('Drum', 1.1, 3.2, pos, color, M.SmoothPlastic)
	for _, y in { 0.9, 2.2 } do decor(t:post('DrumBand', 1.16, 0.18, pos + V(0, y, 0), color:Lerp(P.white, 0.35), M.SmoothPlastic)) end
	return t
end
-- Clutter cluster: a pallet with crates, drums, a tyre stack (seeded so neighbours differ).
function Lobby.cluster(c, cf, seed)
	local g = c:at(cf):group('Clutter')
	local rnd = Random.new(seed)
	pallet(g, CFrame.new(0, 0, 0) * CFrame.Angles(0, rnd:NextNumber(-0.2, 0.2), 0))
	crate(g, CFrame.new(-0.6, 0.8, 0.2) * CFrame.Angles(0, rnd:NextNumber(-0.3, 0.3), 0), 2.8)
	crate(g, CFrame.new(0.9, 0.8, -0.4) * CFrame.Angles(0, rnd:NextNumber(-0.3, 0.3), 0), 2.2)
	local drumColors = { C(40, 110, 200), C(206, 50, 44), C(60, 150, 80), C(240, 180, 40) }
	Lobby.drum(g, V(3.6, 0, 1.2), drumColors[rnd:NextInteger(1, 4)])
	Lobby.drum(g, V(4.2, 0, -1.3), drumColors[rnd:NextInteger(1, 4)])
	Lobby.tyres(g, V(-3.8, 0, 1.6), rnd:NextInteger(2, 4))
	return g
end
-- Shipping container with a graffiti tag on its long side (d_kit's container is 8 x 8.6 x 19.6).
function Lobby.container(c, cf, color, tag, tagColor, face)
	local k = container(c, cf, color)
	if tag then
		local x = face == 'Left' and -4.3 or 4.3
		local p = ghost(k:box('Graffiti', V(x - 0.05, 1.2, -7), V(x + 0.05, 7.6, 7), P.white))
		local g = surface(p, face == 'Left' and Enum.NormalId.Left or Enum.NormalId.Right, 12)
		line(g, 'Tag', tag, tagColor, FONT.tag, 0.1, 0.8, P.black, 3)
	end
	return k
end
-- Hanging lamp: a chain from the truss, a cream enamel shade with a yellow rim, a warm bulb. Named Roof* for the plan views.
function Lobby.lamp(c, pos, color)
	local K = Lobby.Colors
	local l = c:group('RoofLamp')
	l:box('RoofLampChain', pos + V(-0.08, 1.3, -0.08), V(pos.X + 0.08, Lobby.Eave - 0.6, pos.Z + 0.08), K.truss, M.Metal)
	l:post('RoofLampCap', 0.45, 0.6, pos + V(0, 1.0, 0), K.steel, M.SmoothPlastic)
	l:post('RoofLampShade', 1.5, 0.5, pos + V(0, 0.5, 0), C(236, 232, 220), M.SmoothPlastic)
	l:post('RoofLampSkirt', 2.0, 0.35, pos + V(0, 0.15, 0), K.chord, M.SmoothPlastic)
	local bulb = decor(l:post('RoofLampBulb', 1.2, 0.25, pos + V(0, -0.05, 0), color, M.Neon))
	bulb.CastShadow = false
	light(bulb, color, 1.1, 26)
	return l
end
-- Big ceiling fan under a truss (spins via HoodMotion).
function Lobby.ceilingFan(c, x, z, rate)
	local K = Lobby.Colors
	local y = Lobby.Eave - 6
	local f, model = c:group('RoofFan')
	f:box('RoofFanRod', V(x - 0.15, y + 0.5, z - 0.15), V(x + 0.15, Lobby.Eave - 0.6, z + 0.15), K.steel, M.SmoothPlastic)
	f:post('RoofFanHub', 1.0, 1.0, V(x, y - 0.2, z), C(230, 230, 236), M.SmoothPlastic)
	for k = 0, 4 do
		f:part('RoofFanBlade', V(1.4, 0.15, 7), CFrame.new(x, y + 0.2, z) * CFrame.Angles(0, k * 2 * math.pi / 5, 0) * CFrame.new(0, 0, -4.3) * CFrame.Angles(0, 0, 0.12), C(245, 245, 245), M.SmoothPlastic)
	end
	return Lobby.motion(model, CFrame.new(x, y, z), rate)
end
-- Wall exhaust fan (blades spin round the wall's normal: the pivot's Y axis is turned to point along it).
function Lobby.wallFan(c, pos, normal, rate)
	local K = Lobby.Colors
	local cf = CFrame.lookAt(pos, pos + normal)
	local h = c:group('WallFan')
	h:part('FanHousing', V(6, 6, 0.8), cf * CFrame.new(0, 0, 0.1), K.steel, M.SmoothPlastic)
	decor(h:part('FanDark', V(5.2, 5.2, 0.1), cf * CFrame.new(0, 0, -0.32), C(60, 74, 100), M.SmoothPlastic))
	for _, e in { { 0, 2.55, 5.4, 0.3 }, { 0, -2.55, 5.4, 0.3 }, { 2.55, 0, 0.3, 5.4 }, { -2.55, 0, 0.3, 5.4 } } do
		h:part('FanGuard', V(e[3], e[4], 0.2), cf * CFrame.new(e[1], e[2], -0.5), K.hazard, M.SmoothPlastic)
	end
	local b, model = h:group('FanBlades')
	local hub = cf * CFrame.new(0, 0, -0.42)
	b:part('FanHub', V(0.9, 0.9, 0.3), hub, P.white, M.SmoothPlastic)
	for k = 0, 3 do b:part('FanBlade', V(0.9, 2.3, 0.08), hub * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0.35, 0), P.white, M.SmoothPlastic) end
	-- Spin axis = the wall normal: the pivot's Y axis must point along it.
	return Lobby.motion(model, hub * CFrame.Angles(-math.pi / 2, 0, 0), rate)
end
-- Forklift (front, the forks, toward cf's -Z) carrying a pallet of crates; its beacon turns.
function Lobby.forklift(c, cf)
	local f = c:at(cf):group('Forklift')
	local yellow, dark, mid = C(250, 190, 30), C(36, 38, 44), C(84, 90, 104)
	for _, x in { -2.1, 2.1 } do
		f:part('Wheel', V(1.0, 2.4, 2.4), CFrame.new(x, 1.2, -1.6), dark, M.SmoothPlastic, Enum.PartType.Cylinder)
		f:part('Wheel', V(1.0, 1.9, 1.9), CFrame.new(x, 0.95, 2.6), dark, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	f:box('Chassis', V(-2, 0.6, -2.8), V(2, 2.6, 3.6), yellow, M.SmoothPlastic)
	f:box('Counterweight', V(-2.1, 0.5, 2.6), V(2.1, 4.2, 4.2), mid, M.SmoothPlastic)
	f:box('Seat', V(-1.1, 2.6, 0.6), V(1.1, 3.4, 2.2), mid, M.SmoothPlastic)
	f:box('SeatBack', V(-1.1, 3.4, 1.9), V(1.1, 5, 2.3), mid, M.SmoothPlastic)
	for _, x in { -1.9, 1.9 } do
		for _, z in { -2.4, 2.4 } do f:box('CagePost', V(x - 0.15, 2.6, z - 0.15), V(x + 0.15, 7.6, z + 0.15), mid, M.SmoothPlastic) end
		f:box('Mast', V(x * 0.8 - 0.3, 0.4, -3.4), V(x * 0.8 + 0.3, 8.8, -2.9), mid, M.SmoothPlastic)
		f:box('Fork', V(x * 0.5 - 0.3, 0.9, -7.6), V(x * 0.5 + 0.3, 1.1, -3.0), mid, M.SmoothPlastic)
	end
	f:box('CageRoof', V(-2.1, 7.6, -2.6), V(2.1, 7.9, 2.6), yellow, M.SmoothPlastic)
	f:box('SteeringWheel', V(-0.6, 3.6, -1.6), V(0.6, 3.75, -0.6), dark, M.SmoothPlastic)
	local bc, beacon = f:group('Beacon')
	bc:box('BeaconBase', V(-0.35, 7.9, 0.55), V(0.35, 8.1, 1.25), mid, M.SmoothPlastic)
	decor(bc:box('BeaconLamp', V(-0.3, 8.1, 0.6), V(0.3, 8.6, 1.2), C(255, 140, 20), M.Neon))
	decor(bc:box('BeaconFlap', V(-0.05, 8.1, 0.5), V(0.05, 8.6, 1.3), C(255, 220, 120), M.Neon))
	Lobby.motion(beacon, cf * CFrame.new(0, 8.3, 0.9), 300)
	decor(f:box('Stripe', V(-2.02, 1.4, -2.6), V(2.02, 1.8, 3.4), P.black, M.SmoothPlastic))
	pallet(f, CFrame.new(0, 1.1, -5.3))
	crate(f, CFrame.new(-0.6, 1.9, -5.3) * CFrame.Angles(0, 0.08, 0), 2.6)
	crate(f, CFrame.new(1.1, 1.9, -5.0) * CFrame.Angles(0, -0.12, 0), 1.9)
	return f
end
-- Searchlight: a yellow drum head with a white front ring on a red yoke, on a red base; a soft Beam fans out
-- from the lens. The head and the beam turn (HoodMotion).
function Lobby.searchlight(c, pos, yaw, rate)
	local K = Lobby.Colors
	local g = c:group('Searchlight')
	Lobby.slab(g, 'SearchBase', pos + V(-1.4, 0, -1.4), pos + V(1.4, 1.2, 1.4), K.red)
	g:post('SearchPost', 0.4, 1.6, pos + V(0, 1.2, 0), K.frame, M.SmoothPlastic)
	local h, head = g:group('SearchHead')
	local pivot = CFrame.new(pos + V(0, 4.4, 0)) * CFrame.Angles(0, yaw, 0)
	for _, sx in { -1, 1 } do h:part('SearchYoke', V(0.4, 3, 2.8), pivot * CFrame.new(sx * 1.6, -0.6, 0), K.red, M.SmoothPlastic) end
	h:part('SearchYokeBase', V(3.6, 0.4, 1.6), pivot * CFrame.new(0, -1.9, 0), K.red, M.SmoothPlastic)
	local aim = pivot * CFrame.Angles(math.rad(50), 0, 0)
	h:part('SearchLamp', V(3.2, 2.6, 2.6), aim * CFrame.Angles(0, math.pi / 2, 0), C(255, 190, 30), M.SmoothPlastic, Enum.PartType.Cylinder)
	h:part('SearchRing', V(0.3, 2.9, 2.9), aim * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, math.pi / 2, 0), C(245, 245, 245), M.SmoothPlastic, Enum.PartType.Cylinder)
	local lens = decor(h:part('SearchLens', V(0.2, 2.2, 2.2), aim * CFrame.new(0, 0, -1.72) * CFrame.Angles(0, math.pi / 2, 0), C(255, 250, 220), M.Neon, Enum.PartType.Cylinder))
	lens.CastShadow = false
	local a0 = Instance.new('Attachment')
	a0.Name = 'BeamStart'
	a0.CFrame = CFrame.new(0.2, 0, 0)
	a0.Parent = lens
	local a1 = Instance.new('Attachment')
	a1.Name = 'BeamEnd'
	a1.CFrame = CFrame.new(18, 0, 0)
	a1.Parent = lens
	local beam = Instance.new('Beam')
	beam.Name = 'SearchBeam'
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 1.6, 7
	beam.FaceCamera = true
	beam.LightEmission, beam.LightInfluence = 1, 0
	beam.Color = ColorSequence.new(C(255, 250, 225))
	beam.Transparency = NumberSequence.new(0.75, 1)
	beam.Texture = 'rbxasset://textures/glow.png'
	beam:SetAttribute('PreviewTexture', 'softglow')
	beam.Parent = lens
	return Lobby.motion(head, CFrame.new(pos + V(0, 4.4, 0)), rate)
end
-- Heavy bag on a wall bracket, gently bouncing on its chain (HoodMotion Bob).
function Lobby.wallBag(c, pos)
	local K = Lobby.Colors
	local g = c:group('WallBag')
	g:box('BagBracket', V(-Lobby.W, pos.Y + 7.6, pos.Z - 0.3), V(pos.X + 0.3, pos.Y + 8.2, pos.Z + 0.3), K.red, M.SmoothPlastic)
	g:box('BagBrace', V(-Lobby.W, pos.Y + 5.4, pos.Z - 0.25), V(-Lobby.W + 0.5, pos.Y + 8.2, pos.Z + 0.25), K.red, M.SmoothPlastic)
	local b, bag = g:group('Bag')
	b:box('BagChain', pos + V(-0.1, 5.4, -0.1), pos + V(0.1, 7.6, 0.1), K.steel, M.SmoothPlastic)
	b:post('BagBody', 1.4, 5, pos + V(0, 0.4, 0), K.red, M.SmoothPlastic)
	for _, y in { 1.0, 4.6 } do b:post('BagBand', 1.48, 0.4, pos + V(0, y, 0), P.white, M.SmoothPlastic) end
	b:post('BagCap', 1.0, 0.4, pos + V(0, 5.4, 0), K.gold, M.SmoothPlastic)
	return Lobby.motion(bag, CFrame.new(pos + V(0, 3, 0)), nil, 0.3, 1.3)
end

---------------------------------------------------------------------------------------------- set pieces
-- Reward crates by the door: a red DAILY crate (north-west), the lucky gold glove and the VIP safe (north-
-- east), each with a light pillar. Decor with "coming soon" prompts.
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
function Lobby.rewardBase(r, w, d, color, k)
	Lobby.slab(r, 'RewardBase', V(-w / 2, 0, -d / 2), V(w / 2, 0.8 * k, d / 2), color:Lerp(P.black, 0.2))
	Lobby.slab(r, 'RewardTop', V(-w / 2 + 0.6, 0, -d / 2 + 0.6), V(w / 2 - 0.6, 1.2 * k, d / 2 - 0.6), color)
	for _, e in { { -w / 2, w / 2, -d / 2 - 0.1, -d / 2 + 0.1 }, { -w / 2, w / 2, d / 2 - 0.1, d / 2 + 0.1 }, { -w / 2 - 0.1, -w / 2 + 0.1, -d / 2, d / 2 }, { w / 2 - 0.1, w / 2 + 0.1, -d / 2, d / 2 } } do
		decor(r:box('RewardGlow', V(e[1], 0.2, e[3]), V(e[2], 0.6 * k, e[4]), color:Lerp(P.white, 0.4), M.Neon)).CastShadow = false
	end
end
Lobby.RewardAt = {
	DailyCrate = CFrame.new(-27, 0, 19) * CFrame.Angles(0, math.rad(14), 0),
	LuckyGlove = CFrame.new(17, 0, 17),
	VipSafe = CFrame.new(31, 0, 19) * CFrame.Angles(0, math.rad(-10), 0),
}
function Lobby.rewards(L)
	local gold = Lobby.Colors.gold
	-- DAILY CRATE (x1.4): a studded red crate with gold corners and a padlock.
	local k = 1.4
	local r = L:at(Lobby.RewardAt.DailyCrate):group('DailyCrate')
	local function B(c, name, a, b, color, mat) return c:box(name, a * k, b * k, color, mat or M.SmoothPlastic) end
	Lobby.rewardBase(r, 11 * k, 9 * k, C(250, 196, 40), k)
	local red = C(226, 44, 44)
	local body = studs(B(r, 'CrateBody', V(-4, 1.2, -3), V(4, 5.6, 3), red, M.Plastic), true)
	-- A treasure-chest lid: a half-round drum over the body, gold straps round it, a gold hasp in front.
	r:part('CrateLid', V(8.4, 6.4, 6.4) * k, CFrame.new(V(0, 5.8, 0) * k), red:Lerp(P.white, 0.08), M.SmoothPlastic, Enum.PartType.Cylinder)
	for _, x in { -3.4, 3.4 } do r:part('CrateStrap', V(0.6, 6.6, 6.6) * k, CFrame.new(V(x, 5.8, 0) * k), gold, M.SmoothPlastic, Enum.PartType.Cylinder) end
	for _, x in { -4.1, 3.5 } do for _, z in { -3.1, 2.5 } do B(r, 'CrateCorner', V(x, 1.2, z), V(x + 0.6, 5.9, z + 0.6), gold) end end
	B(r, 'CrateBand', V(-4.15, 5.3, -3.15), V(4.15, 5.8, 3.15), gold)
	B(r, 'CrateHasp', V(-0.7, 4.4, -3.5), V(0.7, 6.4, -3.0), gold)
	Lobby.prompt(body, 'Open', 'Daily Crate')
	billboard(r, V(0, 13 * k, 0), 7, 2.2, { { 'Title', 'DAILY CRATE', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 90
	Lobby.fx(Lobby.emitBox(r, 'CrateFx', V(-4, 2, -3) * k, V(4, 7.5, 3) * k), 'CrateGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.9 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 120)), LightEmission = 1 })
	Lobby.pillar(r, V(0, 9.2 * k, 0), 12, C(255, 210, 80))
	-- LUCKY GLOVE (x1.8): a gold boxing glove turning over a black-and-gold stand.
	k = 1.8
	local g = L:at(Lobby.RewardAt.LuckyGlove):group('LuckyGlove')
	Lobby.rewardBase(g, 6 * k, 6 * k, C(250, 196, 40), k)
	local function Pt(c, name, rad, h, y, color) return c:post(name, rad * k, h * k, V(0, y * k, 0), color, M.SmoothPlastic) end
	Pt(g, 'StandBase', 2.1, 1.2, 1.2, Lobby.Colors.blue)
	Pt(g, 'StandBand', 1.8, 0.5, 2.4, gold)
	Pt(g, 'StandNeck', 1.4, 2.0, 2.9, Lobby.Colors.blue)
	Pt(g, 'StandBand', 1.9, 0.4, 4.9, gold)
	local gl, glove = g:group('Glove')
	local gold2 = C(255, 200, 50)
	B(gl, 'GloveFist', V(-1.5, 6.4, -1.6), V(1.5, 9.6, 1.4), gold2)
	B(gl, 'GloveKnuckle', V(-1.4, 7.0, -2.2), V(1.4, 9.4, -1.6), gold2:Lerp(P.white, 0.25))
	gl:part('GloveCap', V(2.8, 2.8, 2.8) * k, CFrame.new(V(0, 8.3, -1.9) * k), gold2:Lerp(P.white, 0.35), M.SmoothPlastic, Enum.PartType.Ball)
	B(gl, 'GloveThumb', V(1.5, 6.8, -1.4), V(2.2, 8.6, 0.6), C(240, 170, 30))
	B(gl, 'GloveCuff', V(-1.3, 5.3, -1.2), V(1.3, 6.4, 1.2), P.white)
	B(gl, 'GloveLace', V(-0.2, 6.6, 1.4), V(0.2, 9.2, 1.5), P.white)
	Lobby.motion(glove, Lobby.RewardAt.LuckyGlove * CFrame.new(0, 7.5 * k, 0), 50, 0.4)
	Lobby.prompt(ghost(g:box('GloveHit', V(-2, 1.2, -2) * k, V(2, 5, 2) * k, P.white)), 'Spin', 'Lucky Glove')
	billboard(g, V(0, 11.6 * k, 0), 6, 2, { { 'Title', 'LUCKY GLOVE', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 90
	local glow = Lobby.emitBox(g, 'GloveFx', V(-2, 6, -2) * k, V(2, 10, 2) * k)
	Lobby.fx(glow, 'GloveGlitter', 'glitter', { Rate = 10, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.5, 2),
		Size = Lobby.seq({ { 0, 0.5 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 220, 90)), LightEmission = 1 })
	light(glow, C(255, 210, 90), 1.2, 16)
	Lobby.pillar(g, V(0, 10.2 * k, 0), 10, C(255, 210, 80))
	-- VIP SAFE (x1.4): a purple safe with a gold dial and handle.
	k = 1.4
	local v = L:at(Lobby.RewardAt.VipSafe):group('VipSafe')
	Lobby.rewardBase(v, 9 * k, 8 * k, C(190, 90, 255), k)
	local purple = C(150, 64, 220)
	local safe = studs(B(v, 'SafeBody', V(-3.4, 1.2, -2.6), V(3.4, 8.4, 2.6), purple, M.Plastic))
	B(v, 'SafeDoor', V(-2.8, 1.8, -2.9), V(2.8, 7.8, -2.6), purple:Lerp(P.white, 0.12))
	v:part('SafeDial', V(0.4, 2.2, 2.2) * k, CFrame.new(V(-0.8, 5.4, -3.0) * k) * CFrame.Angles(0, math.pi / 2, 0), gold, M.SmoothPlastic, Enum.PartType.Cylinder)
	B(v, 'SafeHandle', V(1.2, 4.0, -3.4), V(1.6, 6.8, -2.9), gold)
	B(v, 'SafeTrim', V(-3.5, 8.4, -2.7), V(3.5, 8.9, 2.7), gold)
	Lobby.prompt(safe, 'Open', 'VIP Safe')
	billboard(v, V(0, 11.5 * k, 0), 6, 2, { { 'Title', 'VIP SAFE', C(225, 160, 255), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 90
	Lobby.pillar(v, V(0, 9.2 * k, 0), 14, C(200, 120, 255))
end

-- The WORLD 2 garage (x1.25): a bright blue studded frame, the roll-up door half open over a spinning cyan
-- and purple swirl, light and mist spilling out, a solid glowing pad in front.
function Lobby.portal(L, cf)
	local k = 1.25
	local p = L:at(cf):group('World2Portal')
	local blue, corner, cyan, purple = C(44, 120, 235), C(130, 200, 255), C(80, 230, 255), C(170, 90, 255)
	local function B(name, a, b, color, mat) return p:box(name, a * k, b * k, color, mat or M.SmoothPlastic) end
	for _, sx in { -1, 1 } do
		studs(B('PortalPillar', V(sx * 8 - 2, 0, -1.6), V(sx * 8 + 2, 17, 1.6), blue, M.Plastic), true)
		studs(B('PortalFoot', V(sx * 8 - 2.6, 0, -2.2), V(sx * 8 + 2.6, 1.4, 2.2), blue:Lerp(P.white, 0.25), M.Plastic), true)
		for j = 0, 3 do B('PortalChevron', V(sx * 8 - 2.05, 2 + j * 3.4, -1.7), V(sx * 8 + 2.05, 3.6 + j * 3.4, -1.6), j % 2 == 0 and Lobby.Colors.hazard or P.white) end
		studs(B('PortalCorner', V(sx * 6 - 1.6, 14.6, -1.9), V(sx * 6 + 1.6, 17, 1.9), corner, M.Plastic), true)
	end
	studs(B('PortalHeader', V(-10.6, 17, -1.8), V(10.6, 20.4, 1.8), blue, M.Plastic), true)
	for _, x in { -9.8, -6, 6, 9.8 } do studs(B('PortalMerlon', V(x - 1, 20.4, -1.6), V(x + 1, 21.6, 1.6), corner, M.Plastic)) end
	-- The door, rolled half up, with a hazard lip, KEEP OUT and a padlocked chain.
	B('PortalDoor', V(-6, 9, -0.6), V(6, 17, 0.2), C(205, 214, 228))
	for y = 9.6, 16.4, 1.2 do decor(B('PortalSlat', V(-6, y, -0.75), V(6, y + 0.2, -0.6), C(170, 182, 200))) end
	for j = 0, 5 do B('PortalDoorLip', V(-6 + j * 2, 8.6, -0.85), V(-4 + j * 2, 9.4, 0.3), j % 2 == 0 and Lobby.Colors.hazard or P.black) end
	local tag = ghost(B('PortalTag', V(-5.6, 11.6, -0.9), V(5.6, 15.4, -0.8), P.white))
	line(surface(tag, Enum.NormalId.Front, 14), 'Tag', 'KEEP OUT', C(230, 40, 60), FONT.tag, 0.05, 0.9, P.white, 2)
	decor(p:part('PortalChain', V(0.35, 0.35, 12.4) * k, CFrame.new(V(0, 10.2, -1.0) * k) * CFrame.Angles(0, math.pi / 2, 0), C(200, 204, 212), M.SmoothPlastic))
	B('PortalLock', V(-1.1, 9.1, -1.6), V(1.1, 11.2, -1.0), Lobby.Colors.gold)
	-- The opening below the door: a purple glow plate, a cyan one in front, a spinning swirl.
	local back = decor(B('PortalGlowBack', V(-6, 0, 0), V(6, 9, 0.3), purple, M.Neon))
	back.CastShadow = false
	local front = decor(B('PortalGlow', V(-6, 0, -0.35), V(6, 9, -0.25), cyan, M.Neon))
	front.Transparency, front.CastShadow = 0.15, false
	light(front, cyan, 3, 28)
	local sw, swirl = p:group('PortalSwirl')
	local hub = CFrame.new(V(0, 4.6, -0.6) * k)
	for j = 0, 5 do
		decor(sw:part('SwirlArm', V(0.7, 4.2, 0.12) * k, hub * CFrame.Angles(0, 0, j * math.pi / 3) * CFrame.new(0, 2.2 * k, 0) * CFrame.Angles(0, 0, 0.5), j % 2 == 0 and purple or C(255, 80, 200), M.Neon)).CastShadow = false
	end
	decor(sw:part('SwirlEye', V(1.6, 1.6, 0.14) * k, hub, P.white, M.Neon)).CastShadow = false
	Lobby.motion(swirl, cf * hub * CFrame.Angles(-math.pi / 2, 0, 0), 120)
	-- The sign over it and a solid glowing pad in front.
	local sign = Lobby.neonSign(p, CFrame.new(V(0, 18.7, -1.95) * k), 13 * k, 2.8 * k, 'WORLD 2', cyan)
	sign.Name = 'World2Sign'
	local fill = decor(B('PortalPad', V(-5.6, 0, -9.6), V(5.6, 0.1, -4), cyan, M.Neon))
	fill.Transparency, fill.CastShadow = 0.5, false
	for _, e in { { V(-5.6, 0, -9.6), V(5.6, 0.16, -9.2) }, { V(-5.6, 0, -4.4), V(5.6, 0.16, -4) }, { V(-5.6, 0, -9.6), V(-5.2, 0.16, -4) }, { V(5.2, 0, -9.6), V(5.6, 0.16, -4) } } do
		decor(B('PortalPadEdge', e[1], e[2], cyan, M.Neon)).CastShadow = false
	end
	local zone = B('World2Gate', V(-6, 0, -3), V(6, 0.2, -1), cyan)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	-- Status just over the merlons (the neon sign below already says WORLD 2).
	billboard(p, V(0, 28.6, 0), 8, 1.8, { { 'Title', 'LOCKED', C(255, 90, 90), FONT.loud, 0, 0.55 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.58, 0.42 } }).WorldLabel.MaxDistance = 120
	-- Particles: mist creeping out under the door, sparks spiralling into the swirl.
	local mist = Lobby.emitBox(p, 'PortalFx', V(-6, 0.2, -2) * k, V(6, 1.2, -0.6) * k)
	Lobby.fx(mist, 'PortalMist', 'mist', { Rate = 12, Lifetime = NumberRange.new(1.8, 3), Speed = NumberRange.new(1, 2.5),
		Size = Lobby.seq({ { 0, 1.6 }, { 1, 4 } }), Transparency = Lobby.seq({ { 0, 0.5 }, { 1, 1 } }), Color = ColorSequence.new(C(130, 230, 255)),
		LightEmission = 0.8, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 10), Drag = 1 })
	local spiral = Lobby.emitBox(p, 'PortalSpiralFx', V(-5.5, 0.5, -1.4) * k, V(5.5, 8.5, -1) * k)
	Lobby.fx(spiral, 'PortalSpiral', 'sparkle', { Rate = 16, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 2),
		Size = Lobby.seq({ { 0, 0.6 }, { 1, 0 } }), Color = ColorSequence.new(C(200, 160, 255), C(120, 240, 255)), LightEmission = 1,
		EmissionDirection = Enum.NormalId.Back, RotSpeed = NumberRange.new(180, 360) })
	-- Cones and blue-glowing crates beside it.
	-- (all on the +x side: the -x side runs into the training deck once the garage faces the walkway)
	for j, x in { 11.4, 12.6, 13.8 } do
		p:post('Cone', 0.9 * k, 0.3 * k, V(x, 0, -3 + j) * k, C(250, 250, 250), M.SmoothPlastic)
		p:part('Cone', V(2.2, 1.2, 1.2) * k, CFrame.new(V(x, 1.4, -3 + j) * k) * CFrame.Angles(0, 0, math.pi / 2), C(255, 120, 30), M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(p:part('ConeBand', V(0.4, 1.3, 1.3) * k, CFrame.new(V(x, 1.5, -3 + j) * k) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	for j = 0, 2 do
		B('GlowCrate', V(12.9 - j * 0.4, j * 2.2, 1 - j * 0.5), V(15.5 - j * 0.4, 2.2 + j * 2.2, 3.6 - j * 0.5), C(60, 150, 255))
		decor(B('GlowCrateBand', V(12.8 - j * 0.4, 0.9 + j * 2.2, 0.9 - j * 0.5), V(15.6 - j * 0.4, 1.3 + j * 2.2, 3.7 - j * 0.5), cyan, M.Neon)).CastShadow = false
	end
	return p
end

-- A SkinArt figure (Art.posed) in the map, with boxing gloves on both hands: a fist block, a ball knuckle
-- cap, a thumb on the inner side and a white lace. Returns the figure model, or nil without SkinArt.
-- Poses for people in the gym, in SkinArt.Poses' shape: {out, forward} per limb (forward = toward the front).
Lobby.Poses = {
	guard = { LeftArm = { -8, 125 }, RightArm = { -8, 110 }, LeftLeg = { 5, 14 }, RightLeg = { 5, -10 } },
	jab = { LeftArm = { -8, 125 }, RightArm = { 0, 88 }, LeftLeg = { 5, 14 }, RightLeg = { 5, -12 } },
	coach = { LeftArm = { 20, -8 }, RightArm = { 12, 60 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 } },
}
function Lobby.figure(parent, cf, skin, scale, pose, glove)
	local ok, Art = pcall(function() return require(ReplicatedStorage.Shared.SkinArt) end)
	if not ok or type(Art) ~= 'table' or not Art.posed then return nil end
	local built, fig = pcall(Art.posed, parent, cf, skin, scale, pose)
	if not built or not fig then return nil end
	if glove then
		for _, arm in { 'LeftArm', 'RightArm' } do
			local a = fig:FindFirstChild(arm)
			if a then
				local side = arm == 'LeftArm' and 1 or -1 -- toward the body
				local hand = a.CFrame * CFrame.new(0, -1.15 * scale, 0)
				for _, e in {
					{ 'Glove', V(1.45, 1.3, 1.45), CFrame.new(), glove },
					{ 'GloveCap', V(1.4, 1.4, 1.4), CFrame.new(0, -0.45, -0.12), glove:Lerp(P.white, 0.12), Enum.PartType.Ball },
					{ 'GloveThumb', V(0.45, 0.8, 0.5), CFrame.new(side * 0.8, 0.05, -0.3), glove },
					{ 'GloveCuff', V(1.2, 0.35, 1.2), CFrame.new(0, 0.6, 0), P.white },
					{ 'GloveLace', V(0.15, 0.9, 0.06), CFrame.new(0, 0.05, 0.74), P.white },
				} do
					local q = Lobby.worldPart(fig, e[1], e[2] * scale, hand * CFrame.new(e[3].Position * scale), e[4])
					q.CanCollide, q.CanQuery, q.CanTouch = false, false, false
					if e[5] then q.Shape = e[5] end
				end
			end
		end
	end
	return fig
end

-- The champ: a giant gold figure (SkinArt's top look, both fists up) on a ring-corner plinth (red base, white
-- top, gold trim) with a cyan uplight. Two-tone gold (suit and a pale shirt, tie and lapels), a dark face so
-- the eyes and shades read, red boxing gloves and a red-and-gold title belt with cyan gems. Falls back to a
-- block-built champ without SkinArt.
function Lobby.statue(L, cf, skins)
	local K = Lobby.Colors
	local s, model = L:at(cf):group('ChampStatue')
	local head, suit, pale, ink = C(255, 200, 50), C(240, 170, 30), C(255, 232, 150), C(90, 50, 10)
	Lobby.slab(s, 'Plinth', V(-7, 0, -7), V(7, 1.6, 7), K.red)
	decor(s:box('PlinthTrim', V(-7.1, 1.4, -7.1), V(7.1, 1.8, 7.1), K.gold, M.SmoothPlastic))
	Lobby.slab(s, 'PlinthTop', V(-6, 0, -6), V(6, 3.6, 6), C(245, 245, 245))
	for _, e in { { -6.1, 6.1, -6.2, -6.05 }, { -6.1, 6.1, 6.05, 6.2 }, { -6.2, -6.05, -6.1, 6.1 }, { 6.05, 6.2, -6.1, 6.1 } } do
		decor(s:box('PlinthGlow', V(e[1], 3.3, e[3]), V(e[2], 3.6, e[4]), K.cool, M.Neon)).CastShadow = false
	end
	local plaque = s:box('Plaque', V(-3.8, 1.9, -6.2), V(3.8, 3.2, -6.05), K.gold, M.SmoothPlastic)
	line(surface(plaque, Enum.NormalId.Front, 30), 'Text', 'THE CHAMP', K.red, FONT.loud, 0.1, 0.8, P.white, 2)
	local top, scale = 3.6, 4.5
	local base = V2.Origin * s.cf * CFrame.new(0, top, 0)
	local fig = Lobby.figure(model, base, skins.List[#skins.List], scale, 'cheer', K.red)
	if fig then
		fig.Name = 'ChampFigure'
		local paleParts = { DressShirt = true, TailoredLapel = true, Tie = true, TieKnot = true, ShirtCuff = true }
		local face = { EyeWhite = true, Iris = true, Pupil = true, EyeGlint = true, Eyebrow = true, Eyelid = true, Nose = true, Smile = true, SmileTeeth = true,
			Mouth = true, Moustache = true, SunglassesFrame = true, SunglassesLens = true, LensReflection = true, GlassesBridge = true, RoundSpectacleRim = true }
		for _, d in fig:GetDescendants() do
			if d:IsA('BasePart') and not d.Name:find('^Glove') then
				d.Material = M.SmoothPlastic
				d.Color = face[d.Name] and ink or paleParts[d.Name] and pale or d.Name == 'Head' and head or suit
				d.CastShadow = true
			elseif d:IsA('Decal') then
				d.Color3 = ink
			end
		end
		-- The title belt at the waist.
		local waist = base * CFrame.new(0, 2.22 * scale, 0)
		Lobby.worldPart(model, 'BeltBand', V(2.14, 0.45, 1.14) * scale, waist, K.red)
		Lobby.worldPart(model, 'BeltPlate', V(1.4, 0.9, 0.12) * scale, waist * CFrame.new(0, 0, -0.6 * scale), C(255, 220, 80))
		for _, x in { -0.45, 0.45 } do
			local gem = Lobby.worldPart(model, 'BeltGem', V(0.28, 0.28, 0.28) * scale, waist * CFrame.new(x * scale, 0, -0.68 * scale), C(80, 230, 255), M.Neon)
			gem.Shape = Enum.PartType.Ball
		end
	else
		local function b(name, x0, y0, z0, x1, y1, z1, color) return s:box(name, V(x0, top + y0, z0), V(x1, top + y1, z1), color or head, M.SmoothPlastic) end
		for _, sx in { -1, 1 } do
			local function bx(name, a, y0, z0, c2, y1, z1, color) return b(name, math.min(sx * a, sx * c2), y0, z0, math.max(sx * a, sx * c2), y1, z1, color) end
			bx('Leg', 0.3, 0, -1.2, 3.5, 8, 1.4, suit)
			bx('UpperArm', 5.8, 14.6, -1.1, 9.6, 16.8, 1.1)
			bx('ForeArm', 7.8, 16.8, -1.0, 9.6, 20.6, 1.0)
			bx('Glove', 7.0, 20.2, -1.7, 10.4, 23.8, 1.7, K.red)
		end
		b('Belt', -3.6, 7, -1.8, 3.6, 10, 2, K.red)
		b('Chest', -4.4, 10, -2, 4.4, 16, 2, suit)
		b('Head', -2, 16.4, -2, 2, 20.4, 2)
	end
	-- Cyan uplight and glints.
	local lamp = Lobby.emitBox(s, 'StatueFx', V(-6, 6, -3), V(6, 28, 3))
	light(lamp, K.cool, 1.6, 26)
	Lobby.fx(lamp, 'StatueGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 0.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 1.1 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 240, 200)), LightEmission = 1 })
	return s
end

-- People in the gym (SkinArt figures): a sparring pair bouncing on a painted square in the south-west yard,
-- their coach with a towel at a corner, and a boxer working the wall bag by the cardio corner.
function Lobby.people(L, skins)
	local K = Lobby.Colors
	local g, model = L:group('People')
	local cx, cz, half = -46, 132, 6
	-- The square: white lines on the turf, a red and a blue corner triangle.
	for _, e in { { V(cx - half, 0.12, cz - half), V(cx + half, 0.17, cz - half + 0.4) }, { V(cx - half, 0.12, cz + half - 0.4), V(cx + half, 0.17, cz + half) },
		{ V(cx - half, 0.12, cz - half), V(cx - half + 0.4, 0.17, cz + half) }, { V(cx + half - 0.4, 0.12, cz - half), V(cx + half, 0.17, cz + half) } } do
		decor(g:box('SparLine', e[1], e[2], P.white, M.SmoothPlastic)).CastShadow = false
	end
	for _, e in { { cx - half + 2.2, cz - half + 2.2, math.pi, K.red }, { cx + half - 2.2, cz + half - 2.2, 0, K.blue } } do
		decor(g:wedge('SparCorner', V(0.06, 4, 4), CFrame.new(e[1], 0.16, e[2]) * CFrame.Angles(0, e[3], 0) * CFrame.Angles(0, 0, math.pi / 2), e[4], M.SmoothPlastic)).CastShadow = false
	end
	local function boxer(name, skinId, color, pos, look, pose, bob)
		local base = skins.ById[skinId] or skins.List[1]
		local skin = table.clone(base)
		skin.Id, skin.Color, skin.Pants = name, color, color:Lerp(P.black, 0.25)
		local cf = V2.Origin * CFrame.lookAt(pos, look)
		local fig = Lobby.figure(model, cf, skin, 1.1, pose, color:Lerp(P.white, 0.05))
		if fig and bob then Lobby.motion(fig, CFrame.lookAt(pos, look), nil, bob, 0.55) end
		return fig
	end
	boxer('SparRed', 'Enforcer', K.red, V(cx - 2.5, 0.12, cz), V(cx + 3, 0.12, cz), Lobby.Poses.guard, 0.25)
	boxer('SparBlue', 'Enforcer', K.blue, V(cx + 2.5, 0.12, cz), V(cx - 3, 0.12, cz), Lobby.Poses.guard, 0.25)
	-- The coach: no gloves, a white towel on his shoulder, watching from the corner.
	local coach = Lobby.figure(model, V2.Origin * CFrame.lookAt(V(cx - half - 1.5, 0.12, cz + half + 0.5), V(cx, 0.12, cz)), skins.ById.Crook or skins.List[1], 1.05, Lobby.Poses.coach)
	if coach then
		local torso = coach:FindFirstChild('Torso')
		if torso then
			local towel = Lobby.worldPart(coach, 'Towel', V(0.7, 0.25, 1.3) * 1.05, torso.CFrame * CFrame.new(-0.7 * 1.05, 1.05 * 1.05, 0), P.white, M.Fabric)
			towel.CanCollide = false
		end
	end
	-- A boxer on the wall bag in the north-west notch.
	boxer('BagWorker', 'Pickpocket', C(255, 170, 40), V(-60, 0, 33.5), V(-64, 0, 33.5), Lobby.Poses.jab)
	return g
end

-- Leaderboard (about 19 x 22): posts and frame in the board's accent, a gold cap trim, a navy screen with
-- a header; `live` makes it the ServerLeaderboard LobbyService writes into (a TextLabel named TextLabel)
-- and puts a bobbing gold crown on top.
function Lobby.leaderboard(L, cf, title, accent, live)
	local K = Lobby.Colors
	local b, model = L:at(cf):group(live and 'ServerLeaderboard' or 'Leaderboard')
	local rim = accent:Lerp(P.black, 0.3)
	for _, sx in { -1, 1 } do
		studs(b:box('BoardPost', V(sx * 8.4 - 1, 0, -1), V(sx * 8.4 + 1, 21, 1), accent, M.Plastic), true)
		studs(b:box('BoardFoot', V(sx * 8.4 - 1.6, 0, -1.9), V(sx * 8.4 + 1.6, 1, 1.9), rim, M.Plastic))
	end
	studs(b:box('BoardFrame', V(-7.4, 2.6, -0.6), V(7.4, 20.4, 0.6), rim, M.Plastic))
	studs(b:box('BoardCap', V(-9.8, 21, -1.2), V(9.8, 22, 1.2), accent, M.Plastic))
	b:box('BoardTrim', V(-10, 20.6, -1.3), V(10, 21, 1.3), K.gold, M.SmoothPlastic)
	local header = b:box('BoardHeader', V(-7, 17.2, -0.72), V(7, 19.9, -0.6), accent:Lerp(P.white, 0.15), M.SmoothPlastic)
	line(surface(header, Enum.NormalId.Front, 20), 'Title', title, P.white, FONT.loud, 0.08, 0.84, accent:Lerp(P.black, 0.6), 3)
	local screen = b:box('BoardScreen', V(-7, 3.1, -0.72), V(7, 16.9, -0.6), C(26, 40, 92), M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	if live then
		local t = line(g, 'TextLabel', 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, FONT.body, 0.05, 0.9, P.black, 1)
		t.TextYAlignment = Enum.TextYAlignment.Top
	else
		-- Not wired yet: a season teaser instead of empty rows.
		line(g, 'Crowns', '👑 👑 👑 👑 👑', K.gold, FONT.loud, 0.1, 0.22, P.black, 1)
		line(g, 'Rows', 'SEASON 1', K.gold, FONT.loud, 0.38, 0.24, P.black, 2)
		line(g, 'Soon', 'TOP 5 SOON', P.white, FONT.loud, 0.66, 0.2, P.black, 2)
	end
	decor(b:box('BoardGlow', V(-7.2, 2.8, -0.76), V(7.2, 3.1, -0.6), accent:Lerp(P.white, 0.3), M.Neon)).CastShadow = false
	if live then
		local cr, crown = b:group('Crown')
		cr:box('CrownBand', V(-2, 23.2, -2), V(2, 24.4, 2), K.gold, M.SmoothPlastic)
		for _, e in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
			cr:part('CrownPoint', V(0.9, 1.8, 0.9), CFrame.new(e[1], 25.2, e[2]) * CFrame.Angles(0, math.pi / 4, 0), K.gold, M.SmoothPlastic)
			decor(cr:part('CrownGem', V(0.6, 0.6, 0.6), CFrame.new(e[1], 26.2, e[2]), C(255, 60, 90), M.Neon, Enum.PartType.Ball))
		end
		Lobby.motion(crown, cf * CFrame.new(0, 24.4, 0), 45, 0.5)
	end
	return model
end

-- A string of pennants from a to b sagging by `sag` in the middle (each pennant a thin wedge, tip down).
function Lobby.bunting(c, a, b, sag, colors)
	local g = c:group('RoofBunting')
	local n = math.floor((b - a).Magnitude / 3)
	local prev
	for k = 0, n do
		local t = k / n
		local p = a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0)
		if prev then
			local mid = (prev + p) / 2
			decor(g:part('RoofBuntingFlag', V(0.08, 1.7, (p - prev).Magnitude * 0.82), CFrame.lookAt(mid, p) * CFrame.new(0, -0.85, 0) * CFrame.Angles(0, 0, math.pi), colors[k % #colors + 1], M.Fabric)).CastShadow = false
		end
		prev = p
	end
	return g
end

-- Gym-turf insert on the floor: a darker 1-stud edge, white sled-lane lines every 8 studs, painted numbers.
function Lobby.turf(c, x0, x1, z0, z1, numbers)
	local K = Lobby.Colors
	local t = c:group('Turf')
	studs(t:box('TurfEdge', V(x0 - 1, -0.05, z0 - 1), V(x1 + 1, 0.08, z1 + 1), K.turfEdge, M.Plastic))
	studs(t:box('TurfTop', V(x0, -0.05, z0), V(x1, 0.12, z1), K.turf, M.Plastic))
	local n = 0
	for z = z0 + 8, z1 - 3, 8 do
		decor(t:box('TurfLine', V(x0 + 0.5, 0.12, z - 0.2), V(x1 - 0.5, 0.15, z + 0.2), P.white, M.SmoothPlastic)).CastShadow = false
		n += 1
		if numbers then
			local label = ghost(t:box('TurfNumber', V(x0 + 1.5, 0.15, z + 0.6), V(x0 + 5.5, 0.17, z + 3.6), P.white))
			line(surface(label, Enum.NormalId.Top, 20), 'Number', tostring(n * 10), P.white, FONT.loud, 0.05, 0.9)
		end
	end
	return t
end

---------------------------------------------------------------------------------------------- murals
-- Three painted murals: ARMORY with crossed pistols behind the armory, TOP OF THE BLOCK with a crown behind
-- the leaderboards, a giant red glove punching through the corrugation by the WORLD 2 garage.
function Lobby.murals(dr)
	local K, W, S = Lobby.Colors, Lobby.W, Lobby.S
	-- ARMORY (south gable, over the armory's counter banner): purple with a white border, gold letters, two gold
	-- pistols crossed.
	local am = Lobby.onWall(V(0, 25, S - 0.45), V(0, 0, -1))
	decor(dr:part('MuralBorder', V(29.2, 16.2, 0.2), am * CFrame.new(0, 0, 0.1), C(245, 245, 245), M.SmoothPlastic))
	Lobby.board(dr, 'Mural', am, 28, 15, C(130, 60, 220), { { 'Title', 'ARMORY', C(255, 214, 60), FONT.loud, 0.04, 0.52, C(150, 20, 90), 6 } }, 12)
	for _, sx in { -1, 1 } do
		local gun = am * CFrame.new(0, -3.4, -0.3) * CFrame.Angles(0, 0, sx * math.rad(32))
		decor(dr:part('MuralPistol', V(9, 1.3, 0.2), gun * CFrame.new(sx * 1.2, 0.6, 0), K.gold, M.SmoothPlastic))
		decor(dr:part('MuralPistol', V(3.4, 1.9, 0.22), gun * CFrame.new(sx * -2.2, 0.2, 0), K.gold, M.SmoothPlastic))
		decor(dr:part('MuralPistolGrip', V(1.5, 3.2, 0.24), gun * CFrame.new(sx * -3.4, -1.6, 0) * CFrame.Angles(0, 0, sx * -0.3), C(196, 120, 60), M.SmoothPlastic))
	end
	-- TOP OF THE BLOCK (east wall): a blue splash with a white burst, gold letters and a gold crown.
	local tb = Lobby.onWall(V(W - 0.45, 19, 107.5), V(-1, 0, 0))
	Lobby.board(dr, 'Mural', tb, 27, 14, K.blue, { { 'Title', 'TOP OF THE BLOCK', K.gold, FONT.loud, 0.48, 0.34, C(20, 40, 110), 5 } }, 12)
	for k = 0, 1 do decor(dr:part('MuralBurst', V(8, 8, 0.1), tb * CFrame.new(0, 3, -0.2) * CFrame.Angles(0, 0, k * math.pi / 4), P.white, M.SmoothPlastic)) end
	decor(dr:part('MuralCrown', V(6, 1.6, 0.2), tb * CFrame.new(0, 1.6, -0.35), K.gold, M.SmoothPlastic))
	for _, x in { -2.4, 0, 2.4 } do
		decor(dr:part('MuralCrown', V(1.5, 1.5, 0.2), tb * CFrame.new(x, 3.2, -0.35) * CFrame.Angles(0, 0, math.pi / 4), K.gold, M.SmoothPlastic))
		decor(dr:part('MuralGem', V(0.7, 0.7, 0.22), tb * CFrame.new(x, 1.6, -0.45), C(255, 60, 90), M.Neon))
	end
	-- POW (west wall): a white burst, torn light corrugation, and a red glove coming out of the wall.
	local pw = Lobby.onWall(V(-W + 0.45, 14, 101.5), V(1, 0, 0))
	local burst = decor(dr:part('MuralBurst', V(11, 11, 0.1), pw * CFrame.new(0, 0, -0.05), C(245, 245, 245), M.SmoothPlastic))
	decor(dr:part('MuralBurst', V(11, 11, 0.1), pw * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, math.pi / 4), C(245, 245, 245), M.SmoothPlastic))
	line(surface(burst, Enum.NormalId.Front, 16), 'Pow', 'POW!', C(255, 220, 60), FONT.loud, 0.02, 0.24, K.red, 4)
	for j, e in { { -4.6, 3.6, 0.5 }, { 4.4, 3, -0.6 }, { -4, -3.8, 2.4 }, { 4.6, -3.4, -2.2 } } do
		decor(dr:part('MuralShard', V(1.4, 3.2, 0.3), pw * CFrame.new(e[1], e[2], -0.3 - j * 0.05) * CFrame.Angles(0.3, 0, e[3]), K.ridge, M.SmoothPlastic))
	end
	dr:part('MuralGlove', V(5, 4.4, 4.4), pw * CFrame.new(0.4, 0, -3.4), K.red, M.SmoothPlastic)
	dr:part('MuralGlove', V(4.6, 3.6, 1.2), pw * CFrame.new(0.4, 0.2, -6.0), C(236, 60, 64), M.SmoothPlastic)
	dr:part('MuralGlove', V(1.6, 2.2, 3), pw * CFrame.new(2.9, -1.1, -3.2), K.red, M.SmoothPlastic)
	dr:part('MuralCuff', V(4.2, 3.8, 1.4), pw * CFrame.new(0.4, 0, -0.8), P.white, M.SmoothPlastic)
end

---------------------------------------------------------------------------------------------- dressing
-- Signs, posters, racks, containers, clutter, lamps, fans, particles: the life.
function Lobby.dressing(L)
	local K, W, N, S, D = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.Deck
	local dr = L:group('Dressing')
	local inN, inS, inW, inE = V(0, 0, 1), V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0)
	-- The club name over the door inside and out (marquee bulbs round both), the exit and training signs.
	local clubIn = Lobby.onWall(V(0, 26, N + 0.5), inN)
	Lobby.neonSign(dr, clubIn, 30, 6.4, 'HOOD BOXING CLUB', K.pink, 'EST. 1987  •  EVERY PUNCH +1')
	Lobby.marquee(dr, clubIn, 30, 6.4, 2.6)
	local clubOut = Lobby.onWall(V(0, 31.6, N - 1.5), -inN)
	Lobby.neonSign(dr, clubOut, 30, 5.4, 'HOOD BOXING CLUB', K.pink)
	Lobby.marquee(dr, clubOut, 30, 5.4, 2.6)
	Lobby.poster(dr, Lobby.onWall(V(-24, 12, N - 1.45), -inN), 7, 9, C(250, 204, 48), { { 'TRAIN', P.black, FONT.loud, 0.06, 0.24, P.white }, { 'HERE', C(214, 40, 40), FONT.loud, 0.3, 0.24, P.white }, { 'x2 POWER\nFREE BAGS', P.black, FONT.title, 0.6, 0.3 } })
	Lobby.poster(dr, Lobby.onWall(V(24, 12, N - 1.45), -inN), 7, 9, C(214, 40, 40), { { 'FIGHT', P.white, FONT.loud, 0.06, 0.24 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.3, 0.24 }, { 'EVERY\nSATURDAY', P.white, FONT.title, 0.6, 0.3 } })
	Lobby.neonSign(dr, Lobby.onWall(V(0, 21.3, N + 2.6), inN), 12, 1.8, 'EXIT  •  STAGE 1', C(80, 255, 120))
	-- The CARDIO sign's bottom clears the tallest treadmill label (top ~16.1) by a stud; TRAINING sits above it.
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 22.9, 60), inW), 26, 5.2, 'TRAINING', K.warm, 'PUNCH THE BAGS  •  RUN THE BELTS')
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 18.6, 60), inW), 12, 2.6, 'CARDIO', K.lime)
	-- Mirror wall behind the treadmills.
	local mirror = dr:box('Mirror', V(-W, 3, 47), V(-W + 0.35, 10, 73), C(200, 226, 240), M.Glass)
	mirror.Reflectance = 0.35
	dr:box('MirrorFrame', V(-W, 2.6, 46.6), V(-W + 0.3, 10.4, 73.4), K.frame, M.SmoothPlastic)
	-- Posters: fight nights, rules, motivation; slightly crooked, taped.
	local posters = {
		{ V(-40, 11, N + 0.45), inN, 5, 7, C(214, 40, 40), { { 'FIGHT', P.white, FONT.loud, 0.04, 0.2 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.24, 0.2 }, { 'KID BLOCK\nvs\nTHE CHAMP', P.white, FONT.title, 0.48, 0.36 }, { 'SAT 9PM', C(255, 220, 60), FONT.body, 0.86, 0.1 } } },
		{ V(-47, 11, N + 0.45), inN, 4.4, 6, C(250, 204, 48), { { 'TRAIN\nHARD', P.black, FONT.loud, 0.08, 0.5, P.white }, { 'NO PAIN\nNO POWER', C(160, 30, 30), FONT.title, 0.62, 0.3, P.white } } },
		{ V(40, 11, N + 0.45), inN, 5, 7, C(40, 80, 200), { { 'WANTED', P.white, FONT.loud, 0.04, 0.2 }, { 'THE\nCHAMP', C(255, 220, 60), FONT.loud, 0.3, 0.4 }, { 'REWARD 💪 50K', P.white, FONT.body, 0.8, 0.12 } } },
		{ V(47.5, 10, N + 0.45), inN, 4, 5, P.white, { { 'NO\nSPITTING', C(200, 30, 30), FONT.loud, 0.1, 0.55 }, { 'wipe the bags!', P.black, FONT.tag, 0.7, 0.2 } } },
		{ V(-36, 11, S - 0.45), inS, 5, 6.5, C(130, 50, 200), { { 'WORLD 2', P.white, FONT.loud, 0.05, 0.22 }, { 'COMING\nSOON', C(140, 230, 255), FONT.loud, 0.35, 0.4 }, { '???', P.white, FONT.title, 0.8, 0.14 } } },
		{ V(-20, 11, S - 0.45), inS, 5, 7, C(120, 40, 160), { { 'GOLD', C(255, 204, 48), FONT.loud, 0.06, 0.2 }, { 'GLOVES', C(255, 204, 48), FONT.loud, 0.26, 0.2 }, { 'TOURNAMENT', P.white, FONT.title, 0.52, 0.14 }, { 'SIGN UP INSIDE', C(255, 190, 230), FONT.body, 0.76, 0.12 } } },
		{ V(20, 11, S - 0.45), inS, 4.6, 6, C(60, 180, 90), { { 'GUNS\nIN\nSTOCK', P.white, FONT.loud, 0.08, 0.66 }, { '→ ARMORY', C(255, 240, 120), FONT.title, 0.78, 0.16 } } },
	}
	for k, p in posters do
		local cf = Lobby.onWall(p[1], p[2]) * CFrame.Angles(0, 0, math.rad((k % 3 - 1) * 3))
		Lobby.poster(dr, cf, p[3], p[4], p[5], p[6])
	end
	-- Fight-night scoreboard on the north wall, west of the door.
	Lobby.board(dr, 'Scoreboard', Lobby.onWall(V(-23, 15, N + 0.6), inN), 12, 6, C(24, 36, 84), {
		{ 'Round', 'ROUND 3', C(255, 220, 60), FONT.loud, 0.04, 0.26, P.black },
		{ 'Score', 'HOOD 7  :  5 CHAMP', C(255, 90, 90), FONT.loud, 0.34, 0.34, P.black },
		{ 'Clock', '2:59', C(80, 255, 120), FONT.body, 0.72, 0.24, P.black },
	}, 18)
	Lobby.neonFrame(dr, Lobby.onWall(V(-23, 15, N + 0.6), inN), 12, 6, C(255, 220, 60), 0.25)
	Lobby.murals(dr)

	-- Gym-turf yards round the deck (painted lanes and numbers), leaving concrete by the walls and walkway.
	Lobby.turf(dr, -46, -8, 9.5, 26.5, true)
	Lobby.turf(dr, 8, 37, 11, 26.5)
	Lobby.turf(dr, -58, -8, 95, 114.5, true)
	Lobby.turf(dr, -56, -36, 116.5, 145)
	Lobby.turf(dr, 8, 62, 95, 114.5)
	Lobby.turf(dr, 36, 56, 116.5, 145, true)

	-- Edges: racks and containers where the reference has its cliffs, clutter in clusters.
	local tags = { 'HOOD', 'TBC', 'ON THE BLOCK', 'CHAMP' }
	Lobby.container(dr, CFrame.new(-55, 0, N + 4.4) * CFrame.Angles(0, math.pi / 2, 0), Lobby.Colors.containerRed, tags[1], C(255, 220, 60), 'Left')
	Lobby.container(dr, CFrame.new(-53.5, 8.6, N + 4.6) * CFrame.Angles(0, math.pi / 2 + 0.04, 0), Lobby.Colors.containerBlue)
	Lobby.rack(dr, CFrame.new(-W + 4.4, 0, N + 9) * CFrame.Angles(0, -math.pi / 2, 0), 2, 11)
	Lobby.rack(dr, CFrame.new(56, 0, N + 4.4) * CFrame.Angles(0, math.pi, 0), 2, 12)
	Lobby.container(dr, CFrame.new(W - 4.2, 0, 20), C(60, 150, 90), tags[3], P.white, 'Left')
	Lobby.container(dr, CFrame.new(W - 4.4, 8.6, 19.2) * CFrame.Angles(0, -0.05, 0), C(240, 160, 40))
	Lobby.rack(dr, CFrame.new(-W + 4.4, 0, 110) * CFrame.Angles(0, -math.pi / 2, 0), 2, 13)
	Lobby.container(dr, CFrame.new(-W + 4.2, 0, 135), C(60, 150, 90), tags[2], C(255, 90, 160), 'Right')
	Lobby.container(dr, CFrame.new(-50, 0, S - 4.4) * CFrame.Angles(0, math.pi / 2, 0), Lobby.Colors.containerBlue, nil)
	Lobby.container(dr, CFrame.new(-51, 8.6, S - 4.3) * CFrame.Angles(0, math.pi / 2 - 0.05, 0), Lobby.Colors.containerRed)
	Lobby.rack(dr, CFrame.new(-7.5, 0, S - 4.4), 2, 14)
	Lobby.container(dr, CFrame.new(51, 0, S - 4.4) * CFrame.Angles(0, math.pi / 2, 0), C(240, 160, 40), tags[4], P.black, 'Right')
	Lobby.container(dr, CFrame.new(52.5, 8.6, S - 4.6) * CFrame.Angles(0, math.pi / 2 + 0.04, 0), C(60, 150, 90))
	Lobby.container(dr, CFrame.new(W - 4.2, 0, 132), Lobby.Colors.containerBlue)
	Lobby.container(dr, CFrame.new(W - 4.0, 8.6, 133), Lobby.Colors.containerRed)
	Lobby.cluster(dr, CFrame.new(-51, 0, 20) * CFrame.Angles(0, 0.4, 0), 21)
	Lobby.cluster(dr, CFrame.new(37, 0, 150) * CFrame.Angles(0, -0.7, 0), 22)
	Lobby.forklift(dr, CFrame.lookAt(V(47, 0, 24), V(49, 0, 0)))
	-- Its working bay in front of the racks, painted on the floor.
	for _, e in { { 39, 57, 11.6, 12 }, { 39, 39.4, 12, 27.4 }, { 56.6, 57, 12, 27.4 } } do
		decor(dr:box('BayPaint', V(e[1], 0, e[3]), V(e[2], 0.04, e[4]), K.hazard, M.SmoothPlastic))
	end
	-- Story props: vending machine by the door, a bench with a towel and a gym bag, a coffee cup steaming on a
	-- crate, a broom, a heavy bag on a wall hook by the cardio corner.
	local vend = dr:group('Vending')
	vend:box('VendBody', V(14, 0, N + 0.5), V(18.5, 8.4, N + 4), C(220, 40, 50), M.SmoothPlastic)
	local glass = decor(vend:box('VendGlass', V(14.6, 2.4, N + 4), V(17, 7.6, N + 4.12), C(255, 240, 200), M.Neon))
	light(glass, C(255, 230, 190), 0.6, 10)
	vend:box('VendSlot', V(17.3, 3.5, N + 4), V(18.1, 6.2, N + 4.15), C(60, 62, 72), M.SmoothPlastic)
	line(surface(vend:box('VendTop', V(14, 7.6, N + 4), V(18.5, 8.4, N + 4.15), C(255, 255, 255), M.SmoothPlastic), Enum.NormalId.Back, 30), 'Text', 'ENERGY', C(200, 30, 40), FONT.loud, 0.05, 0.9)
	bench(dr, V(-44, 0, 25), V(0, 0, -1))
	decor(dr:box('Towel', V(-45.6, 1.72, 24.6), V(-43.8, 1.9, 25.7), P.white, M.Fabric))
	decor(dr:box('GymBag', V(-41.6, 1.72, 24.5), V(-39.4, 3.1, 25.8), C(40, 110, 220), M.Fabric))
	crate(dr, CFrame.new(-60, 0, 113) * CFrame.Angles(0, 0.3, 0), 3)
	local cup = dr:post('CoffeeCup', 0.3, 0.7, V(-60.2, 3, 112.8), P.white, M.SmoothPlastic)
	Lobby.fx(cup, 'CoffeeSteam', 'smoke', { Rate = 3, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.6, 1.2),
		Size = Lobby.seq({ { 0, 0.3 }, { 1, 1.1 } }), Transparency = Lobby.seq({ { 0, 0.6 }, { 1, 1 } }), Color = ColorSequence.new(P.white), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8) })
	dr:part('BroomStick', V(0.25, 6, 0.25), CFrame.new(20, 3, 7.4) * CFrame.Angles(math.rad(-10), 0, 0), P.wood, M.Wood)
	dr:box('BroomHead', V(19.3, 0, 7.6), V(20.7, 0.7, 9), C(220, 180, 60), M.Fabric)
	Lobby.wallBag(dr, V(-63.4, 0.4, 33.5))
	-- Steam vent in the north-east corner.
	dr:post('VentPipe', 0.8, 9, V(W - 2, 0, N + 2), K.steel, M.SmoothPlastic)
	dr:post('VentCap', 1.1, 0.6, V(W - 2, 9, N + 2), K.hazard, M.SmoothPlastic)
	local steam = Lobby.emitBox(dr, 'VentFx', V(W - 2.6, 9.6, N + 1.4), V(W - 1.4, 10, N + 2.6))
	Lobby.fx(steam, 'VentSteam', 'smoke', { Rate = 8, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(2, 4),
		Size = Lobby.seq({ { 0, 1 }, { 1, 5 } }), Transparency = Lobby.seq({ { 0, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(235, 238, 245)), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Drag = 0.6 })

	-- The podium's back, facing the street door: a plywood hoarding with graffiti and posters; two searchlights
	-- sweep over its front.
	local hb = Lobby.onWall(V(36, D + 7.2, Lobby.CrossZ - 17), inS)
	Lobby.board(dr, 'Hoarding', hb, 50, 12, C(214, 168, 116), {
		{ 'Tag', 'EVOLVE', C(255, 80, 170), FONT.tag, 0.06, 0.62, P.white, 4 },
		{ 'Sub', 'new look = more power', P.white, FONT.tag, 0.7, 0.2, C(40, 110, 220), 3 },
	}, 10, M.WoodPlanks)
	for _, x in { 12.5, 59.5 } do dr:box('HoardingPost', V(x - 0.4, D, Lobby.CrossZ - 17.6), V(x + 0.4, D + 13.6, Lobby.CrossZ - 16.6), K.gold, M.SmoothPlastic) end
	for k, e in { { 14.5, C(40, 110, 220), 'THE\nKINGPIN', 'top row' }, { 57.5, C(222, 44, 52), 'CORNER\nKID', 'free look' } } do
		Lobby.poster(dr, hb * CFrame.new(e[1] - 36, -0.6, -0.2) * CFrame.Angles(0, 0, math.rad(k == 1 and 4 or -3)), 5, 7, e[2], { { e[3], P.white, FONT.loud, 0.1, 0.5 }, { e[4], C(255, 230, 120), FONT.tag, 0.7, 0.2 } })
	end
	-- Behind the podium (facing the hoarding): a blue rubber warm-up mat with white lane lines.
	dr:box('WarmupMat', V(8, D, 30.2), V(64, D + 0.05, 42.6), C(40, 130, 230), M.Fabric)
	for x = 15, 57, 7 do decor(dr:box('WarmupLine', V(x - 0.2, D, 30.6), V(x + 0.2, D + 0.07, 42.2), P.white, M.SmoothPlastic)).CastShadow = false end
	-- Round the armory: the lobby's deck margin in red rubber with a gold edge.
	for _, e in { { V(-29.2, D, 117.8), V(-24.2, D + 0.05, 146.2) }, { V(24.2, D, 117.8), V(29.2, D + 0.05, 146.2) }, { V(-24.2, D, 141.2), V(24.2, D + 0.05, 146.2) } } do
		dr:box('ArmoryMargin', e[1], e[2], C(190, 40, 60), M.Fabric)
	end
	-- Walk of fame on the podium apron: a purple carpet with a gold edge and five gold stars.
	dr:box('FameCarpet', V(12, D, 77.5), V(60, D + 0.05, 88), C(150, 60, 220), M.Fabric)
	for _, e in { { V(12, D, 77.5), V(60, D + 0.07, 78.1) }, { V(12, D, 87.4), V(60, D + 0.07, 88) }, { V(12, D, 77.5), V(12.6, D + 0.07, 88) }, { V(59.4, D, 77.5), V(60, D + 0.07, 88) } } do
		decor(dr:box('FameEdge', e[1], e[2], K.gold, M.SmoothPlastic)).CastShadow = false
	end
	for x = 18, 54, 9 do
		for j = 0, 1 do decor(dr:part('FameStar', V(3, 0.06, 3), CFrame.new(x, D + 0.08, 82.75) * CFrame.Angles(0, math.pi / 8 + j * math.pi / 4, 0), K.gold, M.SmoothPlastic)).CastShadow = false end
	end
	-- The armory's red runner starts here, where the walkway meets its platform.
	dr:box('ArmoryRunner', V(-5, D, 117), V(5, D + 0.05, 121.2), C(222, 44, 52), M.Fabric)
	for _, x in { -5.4, 5 } do decor(dr:box('ArmoryRunnerEdge', V(x, D, 117), V(x + 0.4, D + 0.07, 121.2), K.gold, M.SmoothPlastic)).CastShadow = false end
	Lobby.searchlight(dr, V(9.5, D, 89), math.rad(-30), 28)
	Lobby.searchlight(dr, V(62.5, D, 89), math.rad(30), -28)
	-- Taped X marks and seams across the walkway.
	for _, e in { { 30, 28 }, { -16, 94 } } do
		for _, a in { 45, -45 } do decor(dr:part('TapeX', V(0.5, 0.04, 3), CFrame.new(e[1], 0.02, e[2]) * CFrame.Angles(0, math.rad(a), 0), K.hazard, M.SmoothPlastic)).CastShadow = false end
	end
	-- Wayfinding down the walkway: a blue centre lane with gold chevrons, pointing to the street door north of
	-- the badge and to the armory south of it.
	for _, seg in { { 9, 44.5, -1 }, { 67, 116.5, 1 } } do
		decor(dr:box('WalkLane', V(-1.4, D, seg[1]), V(1.4, D + 0.04, seg[2]), K.blue, M.SmoothPlastic)).CastShadow = false
		for z = seg[1] + 4, seg[2] - 2, 8 do
			for _, sx in { -1, 1 } do
				local tip = V(0, D + 0.06, z + seg[3] * 0.9)
				local tail = V(sx * 1.1, D + 0.06, z - seg[3] * 0.4)
				decor(dr:part('WalkChevron', V(0.5, 0.04, (tip - tail).Magnitude + 0.3), CFrame.lookAt((tip + tail) / 2, tip), K.gold, M.SmoothPlastic)).CastShadow = false
			end
		end
	end
	-- Bunting over the training aisle and the podium apron, cloth banners on the walls.
	local flags = { C(222, 44, 52), C(255, 204, 48), C(40, 110, 220), P.white }
	for _, z in { 55, 65 } do Lobby.bunting(dr, V(-48, 25.5, z), V(-7, 25.5, z), 2.6, flags) end
	for _, z in { 81, 87 } do Lobby.bunting(dr, V(7, 25.5, z), V(64, 25.5, z), 3.2, { C(80, 220, 255), P.white, C(180, 100, 255), C(255, 204, 48) }) end
	for _, e in { { V(W - 0.5, 15, 81), inE, C(222, 44, 52), 'CHAMP' }, { V(-27, 20, S - 0.5), inS, C(222, 44, 52), 'HOOD' }, { V(27, 20, S - 0.5), inS, C(255, 204, 48), 'TBC' } } do
		local cf = Lobby.onWall(e[1], e[2])
		Lobby.board(dr, 'WallBanner', cf, 4, 10, e[3], { { 'Text', e[4], P.white, FONT.loud, 0.3, 0.4, e[3]:Lerp(P.black, 0.5) } }, 16, M.Fabric)
		decor(dr:part('BannerRod', V(5, 0.3, 0.3), cf * CFrame.new(0, 5.1, -0.2), K.steel, M.SmoothPlastic))
	end
	-- Lamps: warm over the training deck and the walkway, cool over the podium.
	-- (none over the cardio corner: they would hang in front of the TRAINING and CARDIO signs)
	for _, x in { -14, -36 } do
		for _, z in { 51, 66 } do Lobby.lamp(dr, V(x, 19, z), K.warm) end
	end
	for _, x in { -11, 11 } do Lobby.lamp(dr, V(x, 20, 36), K.warm) end
	Lobby.lamp(dr, V(0, 20, 111), K.warm)
	for _, x in { -16, 16 } do Lobby.lamp(dr, V(x, 20, 126), K.warm) end
	for _, x in { 22, 50 } do Lobby.lamp(dr, V(x, 21, 81), C(150, 230, 255)) end
	-- Fans: two big ceiling fans over the walkway, exhaust fans high on the side walls.
	Lobby.ceilingFan(dr, 0, 36, 70)
	Lobby.ceilingFan(dr, 0, 96, -60)
	for _, z in { 13.5, 143.5 } do
		Lobby.wallFan(dr, V(-W + 0.4, 23.5, z), inW, 160)
		Lobby.wallFan(dr, V(W - 0.4, 23.5, z), inE, -160)
	end
	-- Dust drifting in the sun under the skylight, thicker over the walkway.
	for _, z in { 30, 75, 120 } do
		local box = Lobby.emitBox(dr, 'DustFx', V(-24, 6, z - 20), V(24, 26, z + 20))
		Lobby.fx(box, 'Dust', 'dust', { Rate = 14, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.1, 0.4),
			Size = Lobby.seq({ { 0, 0 }, { 0.2, 0.22 }, { 0.8, 0.22 }, { 1, 0 } }), Transparency = Lobby.seq({ { 0, 0.4 }, { 1, 0.6 } }),
			Color = ColorSequence.new(C(255, 240, 210)), LightEmission = 1, SpreadAngle = Vector2.new(180, 180) })
	end
	-- The landmark from the street: a giant red glove bobbing over the north gable.
	local gg, glove = dr:group('RoofGlove')
	local gp = V(0, 45.6, N - 0.5)
	gg:box('RoofGloveFist', gp + V(-3.6, -3, -3.2), gp + V(3.6, 3.4, 3.2), C(240, 66, 72), M.SmoothPlastic)
	gg:box('RoofGloveKnuckle', gp + V(-3.3, -1.8, -4.2), gp + V(3.3, 3, -3.2), C(240, 70, 74), M.SmoothPlastic)
	gg:box('RoofGloveThumb', gp + V(3.6, -2.4, -3.0), gp + V(5, 1.4, 1), C(240, 66, 72), M.SmoothPlastic)
	gg:box('RoofGloveCuff', gp + V(-3, -5.6, -2.6), gp + V(3, -3, 2.6), P.white, M.SmoothPlastic)
	gg:box('RoofGloveLace', gp + V(-0.4, -2.6, 3.2), gp + V(0.4, 3, 3.5), P.white, M.SmoothPlastic)
	Lobby.motion(glove, CFrame.new(gp), 20, 0.6, 3)
	return dr
end

---------------------------------------------------------------------------------------------- build
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.shell(L)
	Lobby.deck(L)
	Lobby.badge(L)
	Lobby.slots(L, skins)
	Lobby.aisle(L)
	Lobby.rewards(L)
	Lobby.Slots.World2Portal = CFrame.new(-42, 0, 106) * CFrame.Angles(0, math.rad(-115), 0)
	Lobby.portal(L, Lobby.Slots.World2Portal)
	Lobby.Slots.Statue = CFrame.lookAt(V(25, 0, 104), V(0, 0, 112))
	Lobby.statue(L, Lobby.Slots.Statue, skins)
	Lobby.Slots.Spawn = CFrame.new(SPAWN) * CFrame.Angles(0, math.rad(25), 0)
	Lobby.Slots.FurthestPad = CFrame.new(0, Lobby.Deck, Lobby.CrossZ - 13)
	for name, cf in Lobby.RewardAt do Lobby.Slots[name] = cf end
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	local boards = L:group('Leaderboards')
	for k, e in { { V(46, 0, 101), V(14, 0, 110), 'TOP CASH', C(44, 170, 80) }, { V(57, 0, 114), V(18, 0, 116), 'TOP REBIRTHS', C(132, 62, 212) }, { V(47, 0, 129), V(12, 0, 122), 'TOP POWER', C(222, 52, 52), true } } do
		local cf = CFrame.lookAt(e[1], e[2])
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[3], e[4], e[5])
	end
	Lobby.dressing(L)
	Lobby.people(L, skins)
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
	local carColors = { C(252, 204, 40), P.white, C(214, 52, 52), C(52, 102, 214), C(252, 204, 40), C(230, 230, 232) }
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
-- The spawn is the warehouse lobby (e2_lobby): stations, treadmills, the EVOLUTIONS podium, the armory,
-- the spawn badge, FurthestPad and the leaderboards are all built there.
local function buildSpawn(ctx, skins)
	return Lobby.build(ctx, skins)
end
---------------------------------------------------------------------------------------------- stage gates
-- A gate at the start of every stage (and the boss yard): two posts at the building line, a header with
-- the stage number, and a see-through wall in the look's colour showing the power it takes. HoodClient/
-- Stages makes the wall solid while you're short, turns it green when you can pass and clears it once
-- you have; StageService records the clear and pays the reward.
local LOOK_NAMES = { 'THE BLOCK', 'SHOP STREET', 'THE COURTS', 'THE APARTMENTS', 'THE YARDS', 'BOSS YARD' }
local BOSS_RED = C(214, 44, 44)
local function lookColor(i) return i > STAGES and BOSS_RED or P.district[lookOf(i)] end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local color = lookColor(i)
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	for _, s in { -1, 1 } do g:box('GatePost', V(s * 34.4, 0, -0.6), V(s * 36, 24.8, 0.6), color:Lerp(P.black, 0.3), M.SmoothPlastic) end
	local header = g:box('GateHeader', V(-35.6, 21, -1), V(35.6, 25, 1), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local hg = surface(header, face, 16)
		pcall(function() hg.MaxDistance = 400 end)
		line(hg, 'Name', i > STAGES and 'BOSS YARD' or ('STAGE ' .. i .. '  •  ' .. LOOK_NAMES[lookOf(i)]), P.white, FONT.loud, 0.12, 0.76, color:Lerp(P.black, 0.6), 4)
	end
	local barrier = g:box('Barrier', V(-34.4, 0, -0.3), V(34.4, 21, 0.3), color, M.SmoothPlastic)
	barrier.Transparency = 0.62
	barrier.CastShadow = false
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local bg = surface(barrier, face, 12)
		pcall(function() bg.MaxDistance = 260 end)
		line(bg, 'Power', '💪 ' .. compact(req), P.white, FONT.loud, 0.16, 0.34, color:Lerp(P.black, 0.6), 6)
		line(bg, 'Sub', 'POWER TO ENTER', P.white, FONT.title, 0.5, 0.12, color:Lerp(P.black, 0.6), 3)
		line(bg, 'Status', 'NEED 💪 ' .. compact(req), P.white, FONT.loud, 0.68, 0.1, color:Lerp(P.black, 0.6), 2)
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
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, C(255, 222, 40)), ColorSequenceKeypoint.new(1, P.white) })
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
	model:SetAttribute('Light', color)
	model:AddTag('HoodStageGate')
	return model
end

---------------------------------------------------------------------------------------------- stages
-- Fifteen stages, three to a look (the concept's "1-3", "4-6"... groups). Stages that share a look share
-- their kit and colours but not their layout: building order, heights, shops and props change each time.
local TRIO_COLORS = { P.padRed, P.padBlue, P.padGreen }
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
	if trioOf(i) == 1 then
		local k = lookOf(i)
		banner(d, 'DISTRICT ' .. k .. '  •  ' .. (3 * k - 2) .. ' - ' .. (3 * k), V(0, 7, top - 50), P.district[k], 40)
	end
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

-- 4-6 Shop Street: the barber and the grocery, then more shops under striped awnings.
local SHOPS = {
	{ sign = 'PIZZA', signColor = C(206, 40, 40), textColor = C(255, 220, 80), stripes = { C(206, 40, 40), P.white }, wall = P.brickPink },
	{ sign = 'SNEAKERS', signColor = C(28, 30, 36), textColor = P.white, stripes = { C(40, 40, 46), P.white }, wall = P.brick },
	{ sign = 'ICE CREAM', signColor = C(236, 90, 160), textColor = P.white, stripes = { C(250, 150, 200), P.white }, wall = C(244, 226, 200) },
	{ sign = 'ARCADE', signColor = C(120, 50, 200), textColor = C(255, 220, 60), stripes = { C(130, 60, 210), C(255, 214, 60) }, wall = P.brickDark },
	{ sign = 'BAKERY', signColor = C(150, 96, 52), textColor = P.white, stripes = { C(200, 140, 80), P.white }, wall = P.tan, extra = 'crates' },
	{ sign = 'PHONES', signColor = C(40, 120, 220), textColor = P.white, stripes = { C(40, 120, 220), P.white }, wall = P.brick },
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

-- 7-9 The Courts: a fenced court across the walk in each, basketball, then a blue court, then a green
-- five-a-side cage with goals.
local COURTS = { { P.court, 'hoops' }, { C(60, 120, 210), 'hoops' }, { C(70, 170, 90), 'goals' } }
local function courtStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local floor, kind = COURTS[t][1], COURTS[t][2]
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
	arc(-FRONT + 4, 14, -math.pi / 2, math.pi / 2, 12)
	arc(FRONT - 4, 14, math.pi / 2, math.pi * 1.5, 12)
	for _, s in { -1, 1 } do
		if kind == 'hoops' then
			local h = d:at(CFrame.lookAt(V(s * (FRONT - 3), 0, zc), V(0, 0, zc))):group('Hoop')
			h:post('HoopPole', 0.35, 11, V(0, 0, 0.6), C(60, 64, 72), M.Metal)
			h:box('HoopArm', V(-0.25, 10.4, -1.2), V(0.25, 10.8, 0.6), C(60, 64, 72), M.Metal)
			h:box('Backboard', V(-2.6, 9.4, -1.6), V(2.6, 12.6, -1.3), P.white, M.SmoothPlastic)
			decor(h:box('BoardSquare', V(-1, 10.0, -1.65), V(1, 11.2, -1.6), C(220, 60, 50), M.SmoothPlastic))
			for q = 0, 7 do
				local a = q / 8 * math.pi * 2
				decor(h:part('Rim', V(0.7, 0.12, 0.14), CFrame.new(math.cos(a) * 0.85, 10, -2.6 + math.sin(a) * 0.85) * CFrame.Angles(0, -a + math.pi / 2, 0), C(240, 100, 40), M.Metal))
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
	local floors = { { { 3, 3, 3 }, { 3, 3, 3 } }, { { 3, 4, 3 }, { 4, 3, 3 } }, { { 4, 3, 4 }, { 3, 4, 4 } } }
	local widths = { { 24, 20, 20 }, { 20, 24, 20 }, { 20, 20, 24 } }
	for k, s in { -1, 1 } do
		local f3 = floors[t][k]
		local lots = {}
		for q = 1, 3 do
			local wall = ((q + k + t) % 2 == 0) and light or P.tan
			table.insert(lots, { widths[t][q], function(f, w) tanBuilding(f, w, { floors = f3[q], wall = wall }) end })
		end
		sideRow(d, s, top, lots)
	end
	standardDressing(d, top, i, { { 'bench', -34, 4 } }, { { 'can', -36, 3 } })
end

-- 13-15 The Yards: warehouses and container lots between the last apartments, fences toward the boss.
local function yardStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local grey = C(132, 140, 156)
	local plans = {
		{ L = { { 40, 'warehouse' }, { 24, 'tan4' } }, R = { { 24, 'tan3' }, { 40, 'containers' } } },
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
-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end.
local function bossYard(ctx)
	local b = ctx:group('BossYard')
	b:box('YardSlab', V(-FRONT, 0, BOSS_END), V(FRONT, 0.06, BOSS_TOP - 4), C(176, 178, 184), M.Concrete)
	sideRow(b, -1, BOSS_TOP, {
		{ 56, function(f, w) warehouse(f, w) end },
		{ 40, function(f, w) brickBuilding(f, w, { floors = 2, wall = P.warehouse:Lerp(P.black, 0.1), bays = 4 }) end },
	})
	sideRow(b, 1, BOSS_TOP, { { 96, function(f, w) containerLot(f, w, 3) end } })
	car(b, CFrame.new(-26, 0, BOSS_TOP - 70) * CFrame.Angles(0, math.rad(80), 0), P.white)
	local ring = SKINS.StationById.Ring
	local ringCtx, ringModel = b:at(CFrame.new(0, 0, BOSS_TOP - 34) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id)
	Props.ring(ringCtx, PROPS_KIT, ring, 7)
	-- The champion aura (tier 9) on the canvas, like the stations along the way.
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	if canvas and vfx then vfx.station(canvas, 9, nil, V(14, 12, 14)) end
	local bz = BOSS_END + 22
	local _, pad = fightPad(b, 16, V(0, 0, bz), P.padRed, 6, 14, 'BOSS')
	local model = pad.parent
	model.Name = 'BossPad'
	model:SetAttribute('Boss', true)
	local glow = decor(b:part('BossRing', V(0.1, 22, 22), CFrame.new(0, 0.05, bz) * CFrame.Angles(0, 0, math.pi / 2), P.bossRing, M.Neon, Enum.PartType.Cylinder))
	glow.Transparency, glow.CastShadow = 0.25, false
	decor(b:part('BossRingInner', V(0.11, 18.4, 18.4), CFrame.new(0, 0.06, bz) * CFrame.Angles(0, 0, math.pi / 2), C(176, 178, 184), M.Concrete, Enum.PartType.Cylinder)).CastShadow = false
	banner(b, 'BOSS', V(0, 13, bz - 4), BOSS_RED, 16)
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
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 warehouse lobby 2')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN)
	root:SetAttribute('MorphStand', true) -- the lobby's EVOLUTIONS podium holds the Morphs stands
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	buildStages(ctx)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('FrontPage') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn in the hood; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
