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
-- Punching-bag stations after the lobby reference (ref_bags): a themed mat inset in a raised, studded,
-- two-tone rim with stepped corners; a lattice-truss gallows (square truss post with X bracing on a stepped
-- foot, a truss arm, a diagonal brace, a short chain) and a chunky eight-sided barrel bag (wide belly, dark
-- bands near the top and bottom, stepped caps). Floating labels: a Power chip (FREE / 💪 N), Unlocked or
-- Locked (the client writes it) and a big outlined "xN Power" in the theme colour.
-- One theme per tier, each richer than the last (material, trim, props and effects all step up):
--   1 stone + wooden barrel   2 red rain   3 lava   4 arcane purple   5 ice   6 toxic   7 shadow   8 gold
-- Effects are HoodVFX.theme on the mat (flames on lava, frost on ice, dark wisps on toxic...).
-- Local frame: origin = mat centre on the floor, footprint x -7..7, z -6..6, parts up to y ~13.5, labels float
-- to ~17. The front faces -Z: players walk on from -Z, stand on the mat and punch the bag toward +Z.
-- opts.side = -1 mirrors the gallows (post on -X) for the other side of a walkway; default +1 (post on +X,
-- the left of a camera looking at the front). opts.vfx = false skips effects, opts.tier overrides the tier.
-- Contract (Lobby.client, Punch.client, LobbyRules): Training_<Id> > TrainingZone (the mat top, invisible),
-- Equipment (Hinge + Swing = chain and bag, + Gallows; all painted black while locked), Sign (BillboardGui
-- with TextLabels Cost, Detail, Power), attributes Tier, HitPoint, HitColor.
local Stations = {}

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (dark band, studded top); mat: the inset surface;
-- frame: the gallows; bag/band/cap: the barrel; text: the "xN Power" colour; glow: accents and hit sparks;
-- edge: neon strip round the inside of the rim (tiers 3+).
Stations.Themes = {
	{ name = 'stone', rim = C(70, 74, 92), rimTop = C(104, 110, 130), mat = C(150, 155, 170), matMat = M.Plastic,
		frame = C(150, 158, 178), bag = C(150, 92, 56), bagMat = M.WoodPlanks, band = C(36, 40, 70), text = C(255, 255, 255), glow = C(255, 236, 200) },
	{ name = 'red', rim = C(26, 28, 58), rimTop = C(40, 44, 84), mat = C(226, 34, 52), matMat = M.Plastic,
		frame = C(40, 44, 82), trim = C(236, 44, 60), bag = C(222, 36, 50), bagMat = M.Fabric, band = C(36, 30, 60), tape = C(196, 200, 210), text = C(255, 84, 96), glow = C(255, 70, 80) },
	{ name = 'lava', rim = C(46, 30, 30), rimTop = C(76, 50, 44), mat = C(255, 72, 0), matMat = M.Neon,
		frame = C(250, 140, 36), bag = C(250, 136, 30), bagMat = M.Fabric, band = C(80, 32, 20), text = C(255, 170, 48), glow = C(255, 140, 30), edge = C(255, 190, 60) },
	{ name = 'arcane', rim = C(60, 30, 98), rimTop = C(96, 54, 150), mat = C(140, 70, 222), matMat = M.Plastic,
		frame = C(158, 86, 230), bag = C(150, 72, 220), bagMat = M.Fabric, band = C(52, 24, 90), text = C(206, 132, 255), glow = C(196, 120, 255), edge = C(176, 84, 255) },
	{ name = 'frost', rim = C(120, 170, 210), rimTop = C(226, 242, 255), mat = C(92, 206, 255), matMat = M.Ice,
		frame = C(80, 206, 246), bag = C(176, 236, 255), bagMat = M.Glass, band = C(40, 116, 180), text = C(128, 236, 255), glow = C(150, 236, 255), edge = C(170, 240, 255) },
	{ name = 'toxic', rim = C(30, 120, 30), rimTop = C(84, 226, 62), mat = C(22, 34, 28), matMat = M.Slate,
		frame = C(72, 200, 58), bag = C(64, 196, 64), bagMat = M.Fabric, band = C(22, 56, 28), text = C(130, 255, 90), glow = C(120, 255, 80), edge = C(120, 255, 70) },
	{ name = 'shadow', rim = C(20, 18, 28), rimTop = C(46, 42, 60), mat = C(24, 22, 32), matMat = M.Slate,
		frame = C(40, 38, 52), trim = C(170, 110, 255), bag = C(34, 32, 44), bagMat = M.Fabric, band = C(170, 110, 255), bandMat = M.Neon, text = C(198, 164, 255), glow = C(176, 120, 255), edge = C(170, 110, 255) },
	{ name = 'gold', rim = C(214, 140, 20), rimTop = C(255, 206, 40), mat = C(250, 214, 96), matMat = M.Plastic,
		frame = C(255, 210, 44), bag = C(255, 206, 46), bagMat = M.SmoothPlastic, band = C(222, 146, 18), text = C(255, 218, 64), glow = C(255, 214, 80), edge = C(255, 236, 140) },
}

Stations.MAT_Y = 0.65 -- mat top (where players stand)
Stations.RIM_Y = 0.9 -- rim top
Stations.POST = V(4.6, 0, 1.0) -- post centre (x is mirrored by opts.side)
Stations.BAG_X = 0.3 -- the bag hangs just off centre, toward the post
Stations.ARM_Y = 8.9 -- underside of the arm (the hinge)
Stations.BAG_TOP = 8.15
Stations.BAG_H = 5.8

-- Regular octagonal prism (apothem a, y0..y1) from four slabs turned 45 degrees apart: the low-poly round.
function Stations.octagon(c, name, x, z, a, y0, y1, color, material)
	local w = 2 * a * math.tan(math.pi / 8)
	for k = 0, 3 do c:part(name, V(w, y1 - y0, 2 * a), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 4, 0), color, material) end
end

-- Square lattice truss along the local +Y of `cf` (cf = centre of the base), len long, w x d thick: a dark
-- core, four light corner rails, a tie at every cell joint and an X brace in every cell of the faces listed
-- in `faces` ('-x', '+x', '-z', '+z' in cf's frame), so it reads as an open steel lattice.
function Stations.truss(c, name, cf, len, w, d, color, dark, cell, faces)
	local r = math.min(w, d) * 0.2
	c:part(name .. 'Core', V(w * 0.64, len, d * 0.64), cf * CFrame.new(0, len / 2, 0), dark)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do c:part(name .. 'Rail', V(r, len, r), cf * CFrame.new(sx * (w - r) / 2, len / 2, sz * (d - r) / 2), color) end
	end
	local n = math.max(1, math.floor(len / cell + 0.5))
	local seg = len / n
	for k = 1, n - 1 do c:part(name .. 'Tie', V(w - 0.04, 0.16, d - 0.04), cf * CFrame.new(0, k * seg, 0), color) end
	local t = r * 0.75
	for _, f in faces do
		local onX = f:sub(2) == 'x'
		local s = f:sub(1, 1) == '-' and -1 or 1
		local span = (onX and d or w) - r
		local L = math.sqrt(span * span + seg * seg)
		local ang = math.atan2(span, seg)
		for k = 0, n - 1 do
			for _, dir in { -1, 1 } do
				local at = CFrame.new(onX and s * ((w - t) / 2) or 0, (k + 0.5) * seg, onX and 0 or s * ((d - t) / 2))
				local turn = onX and CFrame.Angles(dir * ang, 0, 0) or CFrame.Angles(0, 0, dir * ang)
				c:part(name .. 'Brace', V(t, L, t), cf * at * turn, color)
			end
		end
	end
end

-- The gallows: stepped foot, truss post, truss arm reaching over the bag, a diagonal brace, a cap and a
-- hook plate. `sd` = side (+1/-1). Returns nothing; parts go in `g`.
function Stations.gallows(g, t, tier, sd)
	local Y, P0 = Stations.MAT_Y, Stations.POST
	local px, pz = sd * P0.X, P0.Z
	local frame, dark = t.frame, t.frame:Lerp(C(0, 0, 0), 0.45)
	local foot = t.frame:Lerp(C(0, 0, 0), 0.2)
	-- Stepped foot (two blocks, the lower one darker).
	g:box('Foot', V(px - 1.2, Y, pz - 1.2), V(px + 1.2, Y + 0.5, pz + 1.2), foot)
	g:box('Foot', V(px - 0.95, Y + 0.5, pz - 0.95), V(px + 0.95, Y + 1.0, pz + 0.95), frame)
	-- Anchor bolts in the corners of the lower foot.
	for _, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		g:box('Bolt', V(px + c.X * 1.08 - 0.13, Y + 0.5, pz + c.Z * 1.08 - 0.13), V(px + c.X * 1.08 + 0.13, Y + 0.68, pz + c.Z * 1.08 + 0.13), C(48, 50, 62), M.Metal)
	end
	-- Post: from the foot to just above the arm.
	local postTop = Stations.ARM_Y + 1.15
	local inner = sd > 0 and '-x' or '+x'
	local outer = sd > 0 and '+x' or '-x'
	Stations.truss(g, 'Post', CFrame.new(px, Y + 1.0, pz), postTop - Y - 1.0, 1.4, 1.4, frame, dark, 1.7, { '-z', inner, outer })
	g:box('PostCap', V(px - 0.85, postTop, pz - 0.85), V(px + 0.85, postTop + 0.3, pz + 0.85), foot)
	-- Arm: a truss lying along X from the post's outer face to just past the bag (rotated so its +Y runs toward
	-- the bag; its front and top faces carry the X bracing).
	local bx = sd * Stations.BAG_X
	local a0, a1 = px + sd * 0.7, bx - sd * 0.9
	local armLen = math.abs(a1 - a0)
	local armCf = CFrame.new(a0, Stations.ARM_Y + 0.55, pz) * CFrame.Angles(0, 0, sd * math.pi / 2)
	Stations.truss(g, 'Arm', armCf, armLen, 1.1, 1.1, frame, dark, 1.4, { '-z', sd > 0 and '+x' or '-x' })
	g:box('ArmCap', V(a1 - 0.18, Stations.ARM_Y - 0.08, pz - 0.65), V(a1 + 0.18, Stations.ARM_Y + 1.18, pz + 0.65), foot)
	-- Diagonal brace from the post to the arm, with a darker spine.
	local b0, b1 = V(px - sd * 0.7, Stations.ARM_Y - 2.6, pz), V(px - sd * 3.0, Stations.ARM_Y, pz)
	g:bar('Brace', b0, b1, 0.6, frame, M.SmoothPlastic)
	g:bar('BraceSpine', b0 + V(0, 0, -0.22), b1 + V(0, 0, -0.22), 0.2, dark, M.SmoothPlastic)
	-- Hook plate under the arm, where the chain hangs.
	g:box('HookPlate', V(bx - 0.45, Stations.ARM_Y - 0.15, pz - 0.45), V(bx + 0.45, Stations.ARM_Y, pz + 0.45), C(44, 46, 60), M.Metal)
	-- From tier 4 a gem turns slowly over the post (HoodMotion: clients spin and bob it), bigger and brighter
	-- every tier: amethyst, ice, toxic orb, void orb, gold star.
	if tier >= 4 then
		local tg, top = g:group('Topper'), postTop + 0.3
		local k = (tier - 4) / 4
		local gem = t.edge or t.glow
		tg:box('TopperBase', V(px - 0.5, top, pz - 0.5), V(px + 0.5, top + 0.25, pz + 0.5), dark)
		local cy, sz = top + 1.05 + 0.15 * k, 0.8 + 0.35 * k
		if tier == 8 then
			-- A chunky five-point-ish star: two crossed slabs and a gem in the middle.
			tg:part('Star', V(sz * 1.5, sz * 0.5, 0.3), CFrame.new(px, cy, pz), C(255, 214, 40), M.SmoothPlastic)
			tg:part('Star', V(sz * 0.5, sz * 1.5, 0.3), CFrame.new(px, cy, pz), C(255, 214, 40), M.SmoothPlastic)
			tg:part('Star', V(sz * 1.2, sz * 0.45, 0.28), CFrame.new(px, cy, pz) * CFrame.Angles(0, 0, math.pi / 4), C(255, 196, 30), M.SmoothPlastic)
			tg:part('Star', V(sz * 1.2, sz * 0.45, 0.28), CFrame.new(px, cy, pz) * CFrame.Angles(0, 0, -math.pi / 4), C(255, 196, 30), M.SmoothPlastic)
			tg:part('StarGem', V(0.45, 0.45, 0.4), CFrame.new(px, cy, pz) * CFrame.Angles(0, 0, math.pi / 4), C(255, 250, 220), M.Neon)
		else
			-- An eight-faced gem: a cube stood on its corner, a neon core inside the glass.
			local cf = CFrame.new(px, cy, pz) * CFrame.Angles(math.rad(45), 0, math.rad(35.26))
			tg:part('Gem', V(sz, sz, sz), cf, gem, M.Glass).Transparency = 0.25
			tg:part('GemCore', V(sz * 0.55, sz * 0.55, sz * 0.55), cf, gem, M.Neon)
		end
		for _, p in tg.parent:GetDescendants() do
			if p:IsA('BasePart') then decor(p) end
		end
		tg.parent.WorldPivot = tg:world(CFrame.new(px, cy, pz))
		tg.parent:SetAttribute('Spin', 45 + 15 * k)
		tg.parent:SetAttribute('Bob', 0.25)
		tg.parent:SetAttribute('BobPeriod', 2.2)
		tg.parent:AddTag('HoodMotion')
	end
	-- Trim that climbs with the tier: a coloured strip up the post front (red, shadow), neon on higher tiers.
	if t.trim then
		decor(g:box('PostTrim', V(px - 0.18, Y + 1.2, pz - 0.74), V(px + 0.18, postTop - 0.2, pz - 0.7), t.trim, tier >= 7 and M.Neon or M.SmoothPlastic))
		decor(g:box('ArmTrim', V(math.min(a0, a1) + 0.3, Stations.ARM_Y + 0.37, pz - 0.6), V(math.max(a0, a1) - 0.3, Stations.ARM_Y + 0.73, pz - 0.56), t.trim, tier >= 7 and M.Neon or M.SmoothPlastic))
	end
end

-- The barrel bag: eight-sided sections stepping out from a small top cap to a wide belly and back in, with
-- dark bands proud of the body near the top and bottom, hung on a short chain. Everything but the hinge goes
-- in Swing so the client can sway it. Returns the Equipment model's context and the bag's belly radius.
function Stations.bag(eq, t, tier, x, z)
	local hingeY, top = Stations.ARM_Y, Stations.BAG_TOP
	ghost(eq:part('Hinge', V(0.2, 0.2, 0.2), CFrame.new(x, hingeY, z), P.white))
	local sw = eq:group('Swing')
	local metal = tier == 8 and C(255, 200, 60) or C(52, 54, 70)
	-- Chain: alternating flat links down to the cap's eye.
	for i = 0, 1 do
		local y = hingeY - 0.3 - i * 0.42
		sw:part('ChainLink', i % 2 == 0 and V(0.16, 0.5, 0.42) or V(0.42, 0.5, 0.16), CFrame.new(x, y, z), metal, M.Metal)
	end
	local body, band, cap = t.bag, t.band, t.band
	local bm, bandMat = t.bagMat or M.SmoothPlastic, t.bandMat or M.SmoothPlastic
	-- Profile, top to bottom: { y0, y1, apothem, role }.
	local h = Stations.BAG_H
	local y = function(f) return top - f * h end
	local profile = {
		{ y(0.04), y(0), 0.8, 'cap' }, { y(0.08), y(0.04), 1.2, 'body' }, { y(0.13), y(0.08), 1.52, 'body' },
		{ y(0.25), y(0.13), 1.8, 'body' }, { y(0.32), y(0.25), 2.0, 'band' }, { y(0.68), y(0.32), 1.95, 'body' },
		{ y(0.75), y(0.68), 2.0, 'band' }, { y(0.87), y(0.75), 1.8, 'body' }, { y(0.93), y(0.87), 1.5, 'body' },
		{ y(0.97), y(0.93), 1.15, 'body' }, { y(1), y(0.97), 0.8, 'cap' },
	}
	for _, s in profile do
		local col, mat = body, bm
		if s[4] == 'band' then col, mat = band, bandMat elseif s[4] == 'cap' then col, mat = cap, M.SmoothPlastic end
		Stations.octagon(sw, s[4] == 'body' and 'Bag' or (s[4] == 'band' and 'BagBand' or 'BagCap'), x, z, s[3], s[1], s[2], col, mat)
	end
	if t.tape then
		-- Duct tape: a silver wrap across the belly and a loose torn strip.
		Stations.octagon(sw, 'Tape', x, z, 1.98, y(0.47), y(0.4), t.tape, M.Foil)
		sw:part('TapeEnd', V(0.55, 0.9, 0.08), CFrame.new(x + 0.5, y(0.5), z - 1.98) * CFrame.Angles(0, 0, 0.3), t.tape, M.Foil)
	end
	if tier >= 4 then
		-- Glowing seam rings on the higher bags (thin, inside the bands so the silhouette stays the same).
		local glow = t.edge or t.glow
		Stations.octagon(sw, 'BagGlow', x, z, 2.03, y(0.295), y(0.275), glow, M.Neon)
		Stations.octagon(sw, 'BagGlow', x, z, 2.03, y(0.725), y(0.705), glow, M.Neon)
	end
	if tier == 8 then
		-- Gold: a gem set in the belly front.
		sw:part('Gem', V(0.8, 0.8, 0.2), CFrame.new(x, y(0.5), z - 1.98) * CFrame.Angles(0, 0, math.pi / 4), C(255, 250, 220), M.Neon)
	end
	for _, p in sw.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then decor(p).CastShadow = true end
	end
	if t.bagMat == M.Glass then
		for _, p in sw.parent:GetDescendants() do
			if p:IsA('BasePart') and p.Material == M.Glass then p.Transparency = 0.25 end
		end
	end
	return sw, y(0.5)
end

-- The ring the mat sits in: a dark lower band and a lighter studded top inset from it (a two-tone bevel),
-- each with two-step "pixel" corners.
function Stations.rim(st, t)
	local function ring(name, y0, y1, inset, color, stud)
		local X, Z = 7 - inset, 6 - inset
		local parts = {
			{ V(-X + 1, y0, -Z), V(X - 1, y1, -5) }, { V(-X + 1, y0, 5), V(X - 1, y1, Z) },
			{ V(-X, y0, -Z + 1), V(-6, y1, Z - 1) }, { V(6, y0, -Z + 1), V(X, y1, Z - 1) },
		}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				-- Corner step: half way out from the inner corner.
				table.insert(parts, { V(sx * 6, y0, sz * 5), V(sx * (X - 0.5), y1, sz * (Z - 0.5)) })
			end
		end
		for _, b in parts do
			local p = st:box(name, b[1], b[2], color)
			if stud then studs(p) end
		end
	end
	ring('RimBase', 0, 0.45, 0, t.rim, false)
	ring('Rim', 0.45, Stations.RIM_Y, 0.12, t.rimTop, true)
end

-- Theme props on the mat. `rnd` is a seeded Random so every build looks the same.
Stations.Props = {}
function Stations.rock(c, name, pos, size, color, material, rnd, tilt)
	tilt = tilt or 12
	return c:part(name, size, CFrame.new(pos) * CFrame.Angles(math.rad(rnd:NextNumber(-tilt, tilt)), rnd:NextNumber(0, math.pi), math.rad(rnd:NextNumber(-tilt, tilt))), color, material)
end
-- A faceted nugget: a squat block with a second one turned 45 degrees through it (eight-sided from above).
function Stations.nugget(c, pos, sz, color, rnd)
	local cf = CFrame.new(pos) * CFrame.Angles(math.rad(rnd:NextNumber(-10, 10)), rnd:NextNumber(0, math.pi), math.rad(rnd:NextNumber(-10, 10)))
	c:part('Nugget', V(sz, sz * 0.55, sz * 0.8), cf, color, M.SmoothPlastic)
	c:part('Nugget', V(sz * 0.8, sz * 0.7, sz * 0.62), cf * CFrame.new(0, sz * 0.06, 0) * CFrame.Angles(0, math.pi / 4, math.rad(8)), color:Lerp(C(255, 255, 255), 0.12), M.SmoothPlastic)
end
function Stations.Props.stone(c, t, sd, rnd)
	-- Worn flagstones (a shade lighter or darker), pebbles by the rim and an old tyre leaning on the post.
	for _, f in { { -4.2, -3.1, 2.2 }, { -1.4, -3.6, 1.8 }, { 2.6, -2.2, 2 }, { -3.6, 0.6, 1.6 }, { 0.8, 0.2, 1.4 }, { -4.6, 3.3, 1.8 } } do
		local col = t.mat:Lerp(rnd:NextNumber() < 0.5 and C(0, 0, 0) or C(255, 255, 255), rnd:NextNumber(0.06, 0.12))
		studs(c:box('Flagstone', V(f[1] * sd - f[3] / 2, Stations.MAT_Y, f[2] - f[3] / 2), V(f[1] * sd + f[3] / 2, Stations.MAT_Y + 0.05, f[2] + f[3] / 2), col))
	end
	for _, p in { V(-5.3, 0, -4.2), V(-4.6, 0, -4.5), V(5.2, 0, -4.4) } do
		Stations.rock(c, 'Pebble', V(p.X * sd, Stations.MAT_Y + 0.2, p.Z), V(0.7, 0.45, 0.6), C(120, 124, 136), M.Slate, rnd)
	end
	-- Two old tyres stacked by the post (the "Tire Bag" starter), the top one knocked askew.
	for i = 0, 1 do
		local at = CFrame.new(sd * (4.7 - i * 0.25), Stations.MAT_Y + 0.3 + i * 0.6, -3.3 + i * 0.15) * CFrame.Angles(0, i * 0.5, i * math.rad(4))
		c:part('Tyre', V(0.6, 2.3, 2.3), at * CFrame.Angles(0, 0, math.pi / 2), C(34, 34, 40), M.Rubber, Enum.PartType.Cylinder)
		decor(c:part('TyreHole', V(0.62, 1.1, 1.1), at * CFrame.Angles(0, 0, math.pi / 2), C(70, 72, 82), M.SmoothPlastic, Enum.PartType.Cylinder))
	end
end
function Stations.Props.red(c, t, sd, rnd)
	-- Wet sheen: glossy puddles and a darker inner border, like a rain-soaked mat.
	for _, f in { { -3.8, -2.6, 1.8, 1.0 }, { 2.2, -3.6, 1.2, 0.7 }, { -4.4, 2.8, 1.0, 0.7 } } do
		decor(c:box('Puddle', V(f[1] * sd - f[3] / 2, Stations.MAT_Y, f[2] - f[4] / 2), V(f[1] * sd + f[3] / 2, Stations.MAT_Y + 0.04, f[2] + f[4] / 2), C(176, 16, 36), M.Glass)).Transparency = 0.15
	end
	for _, b in { { V(-6, 0, -5), V(6, 0, -4.7) }, { V(-6, 0, 4.7), V(6, 0, 5) }, { V(-6, 0, -4.7), V(-5.7, 0, 4.7) }, { V(5.7, 0, -4.7), V(6, 0, 4.7) } } do
		decor(c:box('Border', b[1] + V(0, Stations.MAT_Y, 0), b[2] + V(0, Stations.MAT_Y + 0.03, 0), C(150, 18, 34)))
	end
end
function Stations.Props.lava(c, t, sd, rnd)
	-- Cooled crust floating on the lava: dark cracked rocks of different sizes, a few tilted.
	for _, f in { { -4.6, -3.6, 1.4 }, { 2.6, -3.8, 1.1 }, { -4.8, 3.6, 1.2 }, { 3.4, 3.6, 0.9 }, { -1.6, -4.2, 0.8 } } do
		Stations.rock(c, 'Crust', V(f[1] * sd, Stations.MAT_Y, f[2]), V(f[3], rnd:NextNumber(0.25, 0.4), f[3] * rnd:NextNumber(0.7, 1)), C(64, 40, 34), M.CrackedLava, rnd, 6)
	end
end
function Stations.Props.arcane(c, t, sd, rnd)
	-- A rune circle glowing in the mat round the training spot, four rune stones and crystal clusters.
	local cx, cz, R = 0, -1.2, 3.3
	for k = 0, 11 do
		local a = k * math.pi / 6
		local len = 2 * R * math.tan(math.pi / 12) + 0.1
		decor(c:part('Rune', V(len, 0.06, 0.22), CFrame.new(cx + R * math.cos(a), Stations.MAT_Y + 0.03, cz + R * math.sin(a)) * CFrame.Angles(0, -a + math.pi / 2, 0), t.edge, M.Neon))
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		decor(c:part('RuneMark', V(0.6, 0.06, 0.6), CFrame.new(cx + (R - 1) * math.cos(a), Stations.MAT_Y + 0.03, cz + (R - 1) * math.sin(a)) * CFrame.Angles(0, math.pi / 4, 0), t.edge, M.Neon))
	end
	for _, at in { V(-5.1 * sd, 0, -4.1), V(-4.9 * sd, 0, 4.0) } do
		for i = 1, 3 do
			local hgt = rnd:NextNumber(1.2, 2.4) * (i == 1 and 1.3 or 1)
			local p = at + V(rnd:NextNumber(-0.5, 0.5), Stations.MAT_Y + hgt / 2 - 0.1, rnd:NextNumber(-0.4, 0.4))
			decor(Stations.rock(c, 'Crystal', p, V(0.55, hgt, 0.55), C(190, 120, 255), M.Glass, rnd, 18)).Transparency = 0.15
		end
	end
end
function Stations.Props.frost(c, t, sd, rnd)
	-- Snow drifts along the back and the far side, ice crystals in two corners, frost patches on the ice.
	for _, f in { { -4.8, 4.2, 2.4, 0.5 }, { -2.2, 4.4, 2.0, 0.35 }, { 4.6, -4.2, 1.6, 0.35 }, { -5.2, -1.0, 1.0, 0.3 } } do
		c:box('Snow', V(f[1] * sd - f[3] / 2, Stations.MAT_Y, f[2] - 0.6), V(f[1] * sd + f[3] / 2, Stations.MAT_Y + f[4], f[2] + 0.6), C(240, 248, 255), M.Snow)
	end
	for _, at in { V(-5.0 * sd, 0, -4.0), V(5.1 * sd, 0, -3.6) } do
		for i = 1, 4 do
			local hgt = rnd:NextNumber(1.0, 2.6) * (i == 1 and 1.25 or 1)
			local p = at + V(rnd:NextNumber(-0.6, 0.6), Stations.MAT_Y + hgt / 2 - 0.1, rnd:NextNumber(-0.5, 0.5))
			decor(Stations.rock(c, 'IceCrystal', p, V(0.5, hgt, 0.5), C(170, 236, 255), M.Glass, rnd, 22)).Transparency = 0.1
		end
	end
end
function Stations.Props.toxic(c, t, sd, rnd)
	-- Glowing ooze puddles on the dark mat and a leaking drum in the corner.
	for _, f in { { -3.4, -2.8, 2.4, 1.6 }, { 1.6, -3.6, 1.6, 1.1 }, { -4.6, 1.4, 1.4, 2.0 }, { 0.6, 0.0, 1.2, 0.9 }, { 3.6, -0.8, 1.0, 1.2 } } do
		local x, z, w, d = f[1] * sd, f[2], f[3], f[4]
		decor(c:box('Ooze', V(x - w / 2, Stations.MAT_Y, z - d / 2), V(x + w / 2, Stations.MAT_Y + 0.06, z + d / 2), C(40, 184, 24), M.Neon))
		decor(c:box('Ooze', V(x - w / 2 - 0.35, Stations.MAT_Y, z - d / 2 + 0.3), V(x + w / 2 + 0.35, Stations.MAT_Y + 0.05, z + d / 2 - 0.3), C(40, 184, 24), M.Neon))
	end
	local dx, dz = -5.0 * sd, -4.1
	c:post('Drum', 0.85, 2.0, V(dx, Stations.MAT_Y, dz), C(230, 196, 40), M.Metal).CastShadow = true
	decor(c:post('DrumBand', 0.88, 0.25, V(dx, Stations.MAT_Y + 1.3, dz), C(30, 30, 34), M.SmoothPlastic))
	decor(c:post('DrumOoze', 0.7, 0.12, V(dx, Stations.MAT_Y + 2.0, dz), C(64, 214, 36), M.Neon))
end
function Stations.Props.shadow(c, t, sd, rnd)
	-- Violet cracks running through the black mat and obsidian shards in the corners.
	local cracks = { { V(-5.6, 0, -4.6), V(-3.2, 0, -2.4), V(-3.6, 0, -0.4), V(-1.2, 0, 1.0) }, { V(5.4, 0, -4.4), V(3.4, 0, -3.0), V(1.4, 0, -3.6), V(0.2, 0, -1.6) }, { V(-5.6, 0, 4.4), V(-3.6, 0, 2.6) } }
	for _, line in cracks do
		for i = 1, #line - 1 do
			local a, b = V(line[i].X * sd, Stations.MAT_Y + 0.02, line[i].Z), V(line[i + 1].X * sd, Stations.MAT_Y + 0.02, line[i + 1].Z)
			local mid = (a + b) / 2
			decor(c:part('Crack', V(0.16, 0.05, (b - a).Magnitude + 0.1), CFrame.lookAt(mid, b), t.edge, M.Neon))
		end
	end
	for _, at in { V(-5.0 * sd, 0, -4.0), V(5.0 * sd, 0, -4.1) } do
		for i = 1, 3 do
			local hgt = rnd:NextNumber(1.2, 2.8) * (i == 1 and 1.2 or 1)
			local p = at + V(rnd:NextNumber(-0.5, 0.5), Stations.MAT_Y + hgt / 2 - 0.1, rnd:NextNumber(-0.4, 0.4))
			Stations.rock(c, 'Obsidian', p, V(0.6, hgt, 0.5), C(30, 26, 44), M.Glass, rnd, 20).Reflectance = 0.2
		end
	end
end
function Stations.Props.gold(c, t, sd, rnd)
	-- Chunky gold nuggets in clusters (one at the bag's foot), a stack of bars and a few coins on the sand.
	local tones = { C(255, 204, 28), C(255, 222, 70), C(250, 186, 20) }
	for _, at in { V(-4.0, 0, -2.8, 1.8), V(0.4, 0, -0.6), V(-3.2, 0, 2.6), V(3.0, 0, -3.6) } do
		local n = rnd:NextInteger(2, 3)
		for i = 1, n do
			local sz = (i == 1 and 2.1 or 1.0) * rnd:NextNumber(0.85, 1.15)
			local p = V(at.X * sd + (i == 1 and 0 or rnd:NextNumber(-1, 1)), Stations.MAT_Y + sz * 0.28, at.Z + (i == 1 and 0 or rnd:NextNumber(-0.8, 0.8)))
			Stations.nugget(c, p, sz, tones[rnd:NextInteger(1, 3)], rnd)
		end
	end
	for i = 0, 2 do
		local bx, bz = 5.2 * sd, -4.0
		local yy = Stations.MAT_Y + (i < 2 and 0 or 0.45)
		local off = i < 2 and (i - 0.5) * 0.75 or 0
		c:part('GoldBar', V(0.7, 0.45, 1.4), CFrame.new(bx + off, yy + 0.225, bz) * CFrame.Angles(0, math.rad(8), 0), C(255, 196, 40), M.SmoothPlastic)
	end
	for _, p in { V(-1.6, 0, -2.2), V(2.0, 0, -1.4), V(-1.2, 0, 1.4), V(4.0, 0, 2.4) } do
		decor(c:part('Coin', V(0.12, 0.8, 0.8), CFrame.new(p.X * sd, Stations.MAT_Y + 0.06, p.Z) * CFrame.Angles(0, rnd:NextNumber(0, 3), math.pi / 2), C(255, 214, 60), M.SmoothPlastic, Enum.PartType.Cylinder))
	end
end

-- Floating labels over the station (the reference's three rows): the Power chip, Unlocked/Locked and the big
-- "xN Power". `at` is the anchor position; the client rewrites Detail (text and colour).
function Stations.labels(st, s, t, at)
	local sign = ghost(st:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(at), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
	g.Size = UDim2.fromScale(8, 5)
	g.MaxDistance = 110
	g.LightInfluence = 0
	g.Parent = sign
	local ink = C(22, 20, 40)
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
	-- Chip: a dark translucent pill with the price (FREE for the starter).
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.Position, chip.Size = UDim2.fromScale(0.27, 0), UDim2.fromScale(0.46, 0.27)
	chip.BackgroundColor3, chip.BackgroundTransparency = C(24, 26, 40), 0.3
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = chip
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness, edge.Transparency = C(10, 10, 20), 2, 0.2
	edge.Parent = chip
	chip.Parent = g
	text('Cost', s.Required == 0 and 'FREE' or ('💪 ' .. compact(s.Required)), s.Required == 0 and C(120, 255, 140) or P.white, 0.29, 0.035, 0.42, 0.2, 2)
	local open = s.Required == 0
	text('Detail', open and 'Unlocked' or 'Locked', open and C(86, 240, 110) or C(255, 72, 86), 0.12, 0.29, 0.76, 0.22, 2.5)
	text('Power', 'x' .. s.Multiplier .. ' Power', t.text, 0, 0.52, 1, 0.46, 3.5)
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
	local sd = (opts.side == -1) and -1 or 1
	local rnd = Random.new(tier * 7919)
	local st, model = ctx:group('Training_' .. stationId)
	model:SetAttribute('Theme', t.name)

	-- Base: rim ring, the inset mat, a neon edge round the inside from tier 3, the theme's props.
	Stations.rim(st, t)
	local Y = Stations.MAT_Y
	local mat = st:box('Mat', V(-6, 0, -5), V(6, Y, 5), t.mat, t.matMat)
	if t.matMat == M.Plastic or t.matMat == M.Snow or t.matMat == M.Sand then studs(mat) end
	if t.edge then
		for _, b in { { V(-6, Y, -5), V(6, Y + 0.16, -4.94) }, { V(-6, Y, 4.94), V(6, Y + 0.16, 5) }, { V(-6, Y, -4.94), V(-5.94, Y + 0.16, 4.94) }, { V(5.94, Y, -4.94), V(6, Y + 0.16, 4.94) } } do
			decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.Neon)).CastShadow = false
		end
	end
	local props = st:group('Decor')
	if Stations.Props[t.name] then Stations.Props[t.name](props, t, sd, rnd) end
	-- Where the player stands to train: the whole mat (its top is the floor you stand on).
	local zone = st:box('TrainingZone', V(-6, Y - 0.06, -5), V(6, Y, 5), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false

	-- Equipment: the gallows and the bag (both go black while locked; only Swing sways).
	local eq = st:group('Equipment')
	Stations.gallows(eq:group('Gallows'), t, tier, sd)
	local bagX, bagZ = sd * Stations.BAG_X, Stations.POST.Z
	local _, bellyY = Stations.bag(eq, t, tier, bagX, bagZ)

	-- Labels float over the bag, nudged away from the post so the tier gem stays clear of the text.
	Stations.labels(st, s, t, V(bagX - sd * 0.8, 12.9, bagZ))

	model:SetAttribute('Tier', tier)
	model:SetAttribute('HitPoint', st:world(CFrame.new(bagX, bellyY, bagZ - 2.0)).Position)
	model:SetAttribute('HitColor', t.glow)
	if opts.vfx ~= false then
		local vfxModule = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('HoodVFX')
		local ok, VFX = pcall(require, vfxModule)
		if ok and VFX and VFX.theme then
			VFX.theme(mat, t.name, V(12, 12, 10), { parent = model, tier = tier, color = t.glow })
		elseif ok and VFX then
			VFX.station(mat, tier, t.glow, V(12, 12, 10), { parent = model })
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
function Armory.label(c, pos, gun)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	g.Size = UDim2.fromScale(8, 2.9)
	g.MaxDistance = 80
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

-- The ARMORY header: a red studded frame on two posts, a dark board with the word in gold.
function Armory.header(c, y)
	local h = c:group('ArmorySign')
	local post = C(150, 156, 172)
	for _, x in { -14.1, 14.1 } do
		studs(h:box('SignPost', V(x - 0.8, y, 16.8), V(x + 0.8, 12.8, 18.2), post, M.Plastic), true)
		h:box('SignFoot', V(x - 1.3, y, 16.3), V(x + 1.3, y + 0.8, 18.6), post:Lerp(P.black, 0.25), M.Plastic)
	end
	studs(h:box('SignFrame', V(-16, 12.6, 16.9), V(16, 15.5, 18.1), C(222, 52, 52), M.Plastic))
	studs(h:box('SignCap', V(-16.4, 15.5, 16.8), V(16.4, 16, 18.2), C(250, 206, 52), M.Plastic))
	local board = h:box('SignBoard', V(-15.3, 12.85, 16.7), V(15.3, 15.3, 17), C(30, 32, 48), M.SmoothPlastic)
	local g = surface(board, Enum.NormalId.Front, 20)
	line(g, 'Title', 'ARMORY', C(255, 210, 60), FONT.loud, 0.02, 0.72, C(120, 30, 20), 5)
	-- What a gun does, in one line under the name.
	line(g, 'Subtitle', 'BETTER GUN = MORE POWER PER PUNCH', P.white, FONT.loud, 0.74, 0.22, C(40, 10, 10), 2)
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
-- SPEED treadmills (the reference's "x1 Aura" treadmills, Hood-style): a studded grey base, a dark deck with
-- an inclined black belt striped with slats and bold white chevrons, studded side rails, a low motor hood, two
-- uprights leaning back to a slim console with grips and a big glowing screen ("x1 SPEED"), mist rolling off
-- the belt. Every tier has its own accent (Config/Treadmills: cyan Jog, orange Run, magenta Sprint) and the
-- effects grow with it: Run adds glints, Sprint a gunmetal frame, glowing chevrons and speed streaks.
-- Local frame: origin on the floor at the middle, footprint x -3.5..3.5, z -7..7, height <= 12 (the label
-- floats at ~9). The runner stands on the belt facing +Z, toward the console; walk on from -Z.
-- Contract (TreadmillService, Treadmill.client): Treadmill_<Id> > TreadmillZone (invisible, the belt's top),
-- Belt (the walking surface; attributes describe the scrolling pattern), Slat / Chevron parts (attributes Z0,
-- Side) that the client scrolls, Screen (SurfaceGui with TextLabels Title and Detail: the client writes
-- UNLOCKED / LOCKED), attributes Tier, TreadmillId, Multiplier, Required, tag HoodTreadmill.
local Treadmills = {}

Treadmills.Colors = {
	frame = C(176, 180, 194), frameDark = C(120, 125, 140), deck = C(40, 48, 72), belt = C(16, 16, 20),
	slat = C(70, 72, 84), chevron = C(248, 249, 252), iron = C(44, 46, 56),
	-- Sprint's gunmetal frame.
	frameSprint = C(78, 82, 98), frameSprintDark = C(44, 46, 58),
}
-- The belt, in the treadmill's frame: from (y RearY, z RearZ) up to (y RearY + Rise, z RearZ + Run).
Treadmills.Belt = { RearY = 1.1, RearZ = -5.9, Run = 10.3, Rise = 0.72 }

-- An emitter with a Roblox built-in texture (or HoodVFX's uploaded one when it has it), named for the offline
-- previewer. Acceleration comes in `frame`'s axes and is turned into world space here.
function Treadmills.emitter(parent, name, tex, frame, props)
	local builtin = { mist = 'rbxasset://textures/particles/smoke_main.dds', aura = 'rbxasset://textures/particles/smoke_main.dds',
		glitter = 'rbxasset://textures/particles/sparkles_main.dds', streak = 'rbxasset://textures/particles/sparkles_main.dds',
		dust = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png' }
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	local ok, VFX = pcall(function() return require(ReplicatedStorage.Shared.HoodVFX) end)
	local uploaded = ok and type(VFX) == 'table' and VFX.Textures and VFX.Textures[tex]
	e.Texture = (type(uploaded) == 'string' and uploaded ~= '') and uploaded or builtin[tex]
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do
		if k == 'Acceleration' then v = frame:VectorToWorldSpace(v) end
		e[k] = v
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

-- Build treadmill `id` (a Config/Treadmills id) in ctx (frame above). opts.vfx = false skips the effects.
function Treadmills.build(ctx, id, opts)
	opts = opts or {}
	local cfg = require(ReplicatedStorage.Shared.Config.Treadmills)
	local row = assert(cfg.ById[id], 'unknown treadmill ' .. tostring(id))
	local tier = math.clamp(opts.tier or row.Tier, 1, 3)
	local accent = row.Color
	local K = Treadmills.Colors
	local sprint = tier >= 3
	local frame, frameDark = sprint and K.frameSprint or K.frame, sprint and K.frameSprintDark or K.frameDark
	local tm, model = ctx:group('Treadmill_' .. id)

	-- Neighbours never match: a variant (opts.variant, else from where it stands) picks the props' sides
	-- and colours.
	local at = ctx:world(CFrame.new()).Position
	local variant = opts.variant or (math.floor(at.X / 3) * 7 + math.floor(at.Z / 3) * 13) % 6

	-- Base plate: a darker rim under a studded top, so its edge reads as a bevel; a hazard strip on the lip
	-- behind the belt, where you step on.
	studs(tm:box('BaseRim', V(-3.5, 0, -7), V(3.5, 0.22, 7), frameDark))
	studs(tm:box('Base', V(-3.32, 0.22, -6.82), V(3.32, 0.42, 6.82), frame))
	decor(tm:box('Hazard', V(-3.1, 0.42, -6.74), V(3.1, 0.46, -6.42), C(250, 204, 40)))
	for i = 0, 7 do
		decor(tm:part('HazardStripe', V(0.18, 0.05, 0.4), CFrame.new(-2.8 + i * 0.8, 0.445, -6.58) * CFrame.Angles(0, math.rad(40), 0), C(30, 30, 34)))
	end

	-- Belt frame: origin on the middle of the belt's top face, +Z up the incline toward the console.
	local B = Treadmills.Belt
	local incline = math.atan2(B.Rise, B.Run)
	local L = math.sqrt(B.Run * B.Run + B.Rise * B.Rise)
	local b = tm:at(CFrame.new(0, B.RearY + B.Rise / 2, B.RearZ + B.Run / 2) * CFrame.Angles(-incline, 0, 0))
	local pat = cfg.Pattern
	local hw = pat.HalfWidth
	b:box('Deck', V(-3.1, -1.5, -L / 2 - 0.5), V(3.1, -0.26, L / 2 + 0.3), K.deck)
	for _, sx in { -1, 1 } do b:box('DeckSkirt', V(sx * 3.1, -0.95, -L / 2 - 0.3), V(sx * 3.14, -0.8, L / 2), K.deck:Lerp(P.white, 0.25)) end
	local belt = b:box('Belt', V(-hw, -0.26, -L / 2), V(hw, 0, L / 2), K.belt)
	-- Slats across the belt, each carrying its two white chevron pieces (the client scrolls them all).
	local slatY, chevY, hideY = 0.03, 0.05, -0.13
	local slatColor = sprint and C(58, 56, 70) or K.slat
	local chevColor = sprint and K.chevron:Lerp(accent, 0.2) or K.chevron
	local n = math.floor((L - 0.5) / pat.Spacing) + 1
	for j = 0, n - 1 do
		local z0 = -L / 2 + 0.25 + j * pat.Spacing
		local slat = decor(b:part('Slat', V(2 * hw, 0.06, pat.Depth), CFrame.new(0, slatY, z0), slatColor))
		slat.CastShadow = false
		slat:SetAttribute('Z0', z0)
		local x, w = cfg.chevron(z0, pat)
		for _, side in { -1, 1 } do
			local cf = x and CFrame.new(side * x, chevY, z0) or CFrame.new(side * hw / 2, hideY, z0)
			local piece = decor(b:part('Chevron', V(w or 1, 0.06, pat.Depth), cf, chevColor, sprint and M.Neon or M.SmoothPlastic))
			piece.CastShadow = false
			piece:SetAttribute('Z0', z0)
			piece:SetAttribute('Side', side)
		end
	end
	for k, v in { SlatSpacing = pat.Spacing, SlatY = slatY + 0.13, ChevronY = chevY + 0.13, HideY = hideY + 0.13, ScrollSpeed = cfg.Scroll[tier] } do
		belt:SetAttribute(k, v) -- Y values are from the Belt part's centre (its top is 0.13 above it)
	end
	-- Where the runner stands: the belt's top, between the rear cap and the motor hood.
	local zone = b:box('TreadmillZone', V(-hw, -0.06, -L / 2 + 0.2), V(hw, 0, L / 2 - 0.8), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false

	-- Side rails: a darker body under a studded cap, an accent strip down the outside, end caps.
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * hw, sx * 3.1
		b:box('RailBody', V(x0, -0.42, -L / 2 - 0.4), V(x1, 0.12, L / 2 + 0.1), frameDark)
		studs(b:box('Rail', V(x0, 0.12, -L / 2 - 0.4), V(x1, 0.36, L / 2 + 0.1), frame))
		decor(b:box('RailNeon', V(sx * 3.1, -0.24, -L / 2 + 0.2), V(sx * 3.16, -0.1, L / 2 - 0.4), accent, M.Neon)).CastShadow = false
	end
	-- Rear roller under a lip (it hides the slats as they roll under).
	b:box('RearCap', V(-hw, -0.5, -L / 2 - 0.45), V(hw, 0.1, -L / 2 + 0.06), C(54, 58, 72))
	b:rod('RearRoller', 0.34, 2 * hw + 0.1, CFrame.new(0, -0.3, -L / 2 - 0.5), C(96, 100, 114), M.Metal)

	-- Low motor hood at the front, where the belt runs in: dark body, studded lid, vents, an accent stripe.
	tm:box('MotorHood', V(-3.1, 0.42, 3.6), V(3.1, 1.98, 5.9), frameDark)
	studs(tm:box('HoodLid', V(-3.22, 1.98, 3.5), V(3.22, 2.2, 6.0), frame))
	for i = 0, 1 do tm:box('HoodVent', V(-1.4, 0.95 + i * 0.32, 3.54), V(1.4, 1.11 + i * 0.32, 3.6), K.iron) end
	decor(tm:box('HoodNeon', V(-2.9, 1.7, 3.53), V(2.9, 1.82, 3.6), accent, M.Neon)).CastShadow = false
	for _, sx in { -1, 1 } do tm:box('HoodBolt', V(sx * 2.55 - 0.14, 1.1, 3.54), V(sx * 2.55 + 0.14, 1.38, 3.6), K.frame) end
	-- Power cable out of the hood's nose, along the floor.
	tm:bar('Cable', V(1.6, 0.9, 5.9), V(1.9, 0.5, 6.5), 0.2, K.iron, M.SmoothPlastic)
	tm:bar('Cable', V(1.9, 0.5, 6.5), V(3.0, 0.5, 6.7), 0.2, K.iron, M.SmoothPlastic)

	-- Uprights: two slim posts leaning back from the hood to the console.
	local footZ, topY, topZ = 5.3, 5.15, 4.35
	for _, sx in { -1, 1 } do
		local x = sx * 2.75
		tm:bar('Upright', V(x, 2.1, footZ), V(x, topY, topZ), 0.46, frame, M.SmoothPlastic)
		tm:box('UprightFoot', V(x - 0.38, 2.2, footZ - 0.42), V(x + 0.38, 2.46, footZ + 0.42), frameDark)
		-- Handrail back toward the runner with a grip in the accent colour.
		tm:bar('Handrail', V(x, 4.55, 4.5), V(x, 4.35, 2.1), 0.3, K.iron, M.SmoothPlastic)
		tm:part('Grip', V(0.46, 0.46, 1.0), CFrame.new(x, 4.39, 2.55) * CFrame.Angles(math.rad(-4), 0, 0), accent:Lerp(P.black, 0.12), M.SmoothPlastic)
		tm:box('GripCap', V(x - 0.25, 4.15, 1.95), V(x + 0.25, 4.63, 2.06), K.iron)
	end
	-- Slim console bar between the posts: accent keys and a red stop button.
	tm:box('Console', V(-2.5, 4.66, 4.05), V(2.5, 5.03, 4.6), K.iron)
	for i, bx in { -1.7, -1.2, 1.2, 1.7 } do
		decor(tm:box('Key', V(bx - 0.18, 4.75, 4.0), V(bx + 0.18, 4.94, 4.05), i % 2 == 0 and accent or accent:Lerp(P.white, 0.45), M.Neon)).CastShadow = false
	end
	tm:part('StopButton', V(0.24, 0.42, 0.42), CFrame.new(0, 4.85, 3.98) * CFrame.Angles(0, math.pi / 2, 0), C(226, 44, 52), M.SmoothPlastic, Enum.PartType.Cylinder)

	-- The screen: a light shell tilted back toward the runner, a thin glowing rim, the bright panel with the
	-- multiplier, a visor; a soft halo emitter stands in for bloom.
	local tilt = CFrame.new(0, 6.32, 4.9) * CFrame.Angles(math.rad(22), 0, 0)
	tm:part('ScreenFrame', V(5.5, 2.75, 0.34), tilt, frame)
	decor(tm:part('ScreenRim', V(5.22, 2.47, 0.06), tilt * CFrame.new(0, 0, -0.19), accent:Lerp(P.white, 0.55), M.Neon)).CastShadow = false
	local screen = decor(tm:part('Screen', V(4.96, 2.2, 0.06), tilt * CFrame.new(0, 0, -0.22), accent:Lerp(P.black, 0.2), M.Neon))
	screen.CastShadow = false
	local sg = surface(screen, Enum.NormalId.Front, 40)
	line(sg, 'Title', 'x' .. row.Multiplier .. ' SPEED', P.white, FONT.loud, 0.12, 0.5, accent:Lerp(P.black, 0.62), 3)
	line(sg, 'Detail', row.Required == 0 and 'FREE' or compact(row.Required) .. ' POWER', P.white, FONT.loud, 0.64, 0.24, accent:Lerp(P.black, 0.62), 2)
	tm:part('ScreenVisor', V(5.5, 0.2, 0.62), tilt * CFrame.new(0, 1.47, -0.14), frameDark)
	decor(tm:part('ScreenLed', V(0.16, 0.16, 0.06), tilt * CFrame.new(2.0, -1.22, -0.2), C(255, 70, 90), M.Neon)).CastShadow = false
	light(screen, accent, 1.2, 9).Name = 'ScreenLight'
	for _, sx in { -1, 1 } do tm:bar('ScreenArm', V(sx * 2.75, 5.0, topZ), V(sx * 2.62, 5.6, 4.72), 0.38, frame, M.SmoothPlastic) end

	-- Story props, never the same twice: a towel over one handrail (side and colour from the variant), a
	-- water bottle in a cup on the right upright, a stopwatch hanging off Sprint's screen.
	if variant % 3 ~= 2 or tier == 3 then
		local sx = variant % 2 == 0 and -1 or 1
		local cloth = ({ C(240, 242, 246), C(206, 210, 218), accent:Lerp(P.white, 0.55) })[variant % 3 + 1]
		if tier == 3 then cloth = C(40, 40, 46) end
		decor(tm:part('Towel', V(0.62, 0.08, 0.55), CFrame.new(sx * 2.75, 4.54, 3.2), cloth, M.Fabric))
		decor(tm:part('Towel', V(0.08, 1.35, 0.55), CFrame.new(sx * 3.07, 3.89, 3.2) * CFrame.Angles(0, 0, sx * math.rad(-4)), cloth, M.Fabric))
		decor(tm:part('TowelStripe', V(0.09, 0.14, 0.56), CFrame.new(sx * 3.1, 3.41, 3.2) * CFrame.Angles(0, 0, sx * math.rad(-4)), accent, M.Fabric))
	end
	if tier >= 2 or variant % 3 == 2 then
		decor(tm:post('BottleCup', 0.27, 0.3, V(3.22, 3.4, 4.9), K.iron, M.SmoothPlastic))
		decor(tm:post('Bottle', 0.2, 0.75, V(3.22, 3.52, 4.9), accent:Lerp(P.white, 0.45), M.Glass)).Transparency = 0.2
		decor(tm:post('BottleCap', 0.13, 0.16, V(3.22, 4.27, 4.9), P.white, M.SmoothPlastic))
	end
	if tier == 3 then
		decor(tm:part('Stopwatch', V(0.16, 0.66, 0.66), CFrame.new(-2.9, 5.55, 4.7) * CFrame.Angles(0, 0, math.pi / 2), C(250, 210, 60), M.SmoothPlastic, Enum.PartType.Cylinder))
		decor(tm:part('StopwatchFace', V(0.17, 0.5, 0.5), CFrame.new(-2.94, 5.55, 4.7) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	end

	-- Floating label just over the screen, like the reference's "x1 Aura".
	billboard(tm, V(0, 8.7, 5.2), 6.2, 1.55, { { 'Title', 'x' .. row.Multiplier .. ' SPEED', P.white, FONT.loud, 0, 1 } })

	model:SetAttribute('Tier', tier)
	model:SetAttribute('TreadmillId', id)
	model:SetAttribute('Multiplier', row.Multiplier)
	model:SetAttribute('Required', row.Required)
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end) -- the client scrolls it whole
	model:AddTag('HoodTreadmill')

	if opts.vfx ~= false then
		local seq = Treadmills.seq
		local beltWorld = belt.CFrame
		-- Mist rolling back off the belt (the reference's misty treadmills), thicker every tier, a little tinted.
		local fx = ghost(b:part('MistBelt', V(2 * hw, 0.3, L - 1.5), CFrame.new(0, 0.2, -0.6), P.white))
		Treadmills.emitter(fx, 'BeltMist', 'mist', beltWorld, {
			Rate = 5 + 2 * tier, Lifetime = NumberRange.new(1.8, 2.8), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(50, 50),
			Acceleration = V(0, 0.2, -2.2 - tier * 0.6), Drag = 0.6, RotSpeed = NumberRange.new(-20, 20), ZOffset = -0.5,
			Size = seq({ { 0, 1.6 }, { 0.5, 2.8 }, { 1, 3.8 } }), Transparency = seq({ { 0, 1 }, { 0.25, 0.76 - 0.04 * tier }, { 0.7, 0.84 }, { 1, 1 } }),
			Color = ColorSequence.new(P.white, P.white:Lerp(accent, 0.4)), LightEmission = 0.1,
		})
		-- Low haze round the base edges.
		for _, e in { { V(-3.6, 0.5, 0), V(0.5, 0.3, 13) }, { V(3.6, 0.5, 0), V(0.5, 0.3, 13) }, { V(0, 0.5, -7.1), V(7, 0.3, 0.5) } } do
			local edge = ghost(tm:part('MistEdge', e[2], CFrame.new(e[1]), P.white))
			Treadmills.emitter(edge, 'EdgeMist', 'aura', CFrame.new(), {
				Rate = 1 + 0.5 * tier, Lifetime = NumberRange.new(2.4, 3.4), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(70, 70),
				Acceleration = V(0, 0.12, 0), Drag = 0.5, RotSpeed = NumberRange.new(-10, 10), ZOffset = -1,
				Size = seq({ { 0, 1.6 }, { 0.5, 3 }, { 1, 3.8 } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.78 - 0.04 * tier }, { 1, 1 } }),
				Color = ColorSequence.new(P.white, P.white:Lerp(accent, 0.3)), LightEmission = 0.05,
			})
		end
		-- The screen's halo (Roblox blooms Neon a little; this makes the glow read from across the room).
		local halo = Instance.new('Attachment')
		halo.Name = 'Halo'
		halo.CFrame = CFrame.new(0, 0, 0.7) -- behind the shell: it glows round the edges
		halo.Parent = screen
		Treadmills.emitter(halo, 'ScreenGlow', 'softglow', CFrame.new(), {
			Rate = 0.8, Lifetime = NumberRange.new(2.5), Speed = NumberRange.new(0), Rotation = NumberRange.new(0),
			Size = seq({ { 0, 7.2 }, { 1, 7.6 } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.6 }, { 0.6, 0.6 }, { 1, 1 } }),
			Color = ColorSequence.new(accent), LightEmission = 1, ZOffset = -1,
		})
		if tier >= 2 then
			Treadmills.emitter(fx, 'Glints', 'glitter', beltWorld, {
				Rate = 3 + 3 * (tier - 2), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(30, 30),
				Size = seq({ { 0, 0 }, { 0.3, 0.6, 0.2 }, { 1, 0 } }), Color = ColorSequence.new(P.white, accent), LightEmission = 1, Brightness = 2, ZOffset = 1,
			})
		end
		if tier >= 3 then
			-- Speed streaks shooting back off the belt.
			Treadmills.emitter(fx, 'Streaks', 'streak', beltWorld, {
				Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
				Rate = 9, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(14, 20), SpreadAngle = Vector2.new(4, 4),
				Size = seq({ { 0, 0.18 }, { 1, 0.05 } }), Squash = seq({ { 0, 3 }, { 1, 3 } }),
				Transparency = seq({ { 0, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(P.white, accent), LightEmission = 1, Brightness = 2,
			})
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- evolutions podium
-- The EVOLUTIONS podium, the lobby's morph stand: a three-tier stepped stage in studded concrete and steel,
-- with stair flights cut into the front corners of every tier (hazard-striped noses), the 15 looks on
-- glowing pads in three rows of five (cheapest at the front and bottom; the pad colour is the rarity band),
-- and the Kingpin turning and bobbing on a gold-trimmed throne in the middle of the top row. A neon
-- EVOLUTIONS sign runs across the first tier, lattice light towers with spotlights stand on the front
-- corners, a corrugated backdrop with neon bars and colour-cycling up-arrows closes the back, with speaker
-- stacks, a road case, shoe boxes and a clothes rail in the back corners. Alive: motes rising off every pad,
-- glints round unlocked figures, sparkles and haze on the top tier, halo, glitter and rays round the Kingpin.
--
-- Contract (Lobby.client, LobbyService): a Model `Morphs` (Persistent) holding one Model `Skin_<Id>` per look:
--   Interact     invisible part just in front of the pad: the prompt sits on it and the server measures the
--                14-stud equip distance to it (from the tread / the level in front it is ~3 studs away)
--   LabelAnchor  BillboardGui WorldLabel > TextLabels Title (name), Price (power needed), Gain (+N/sec) and
--                Detail (EQUIPPED / EQUIP / BUY, written by the client)
--   Display      the figure (SkinArt); the client paints it as a dark silhouette while the look is locked
--   Lock         a gold padlock in front of the figure, shown while locked
-- and attributes Look, Index, Required, Band (+ Showcase on the Kingpin: it keeps its colours while locked).
-- Effects marked UnlockedOnly (or held by a part marked so) are switched off by the client while locked.
-- The map root still needs MorphStand = true (g_build).
-- Local frame: origin = centre of the front edge on the floor, the front faces -Z (players walk up from -Z),
-- footprint x -28..28, z 0..32, at most 20 tall (labels float above).
local Evolutions = {}

Evolutions.Base = 0.4 -- floor slab top
Evolutions.Rise = 3.4 -- per tier: four 0.85 steps (enough that each row's heads clear the row in front)
Evolutions.Steps = 4
Evolutions.Flight = 3 -- stair width; each tier is this much narrower on both sides than the one below
Evolutions.Back = 30 -- tiers end here, the backdrop stands behind
Evolutions.Spacing = 7
Evolutions.Pad = 4.2
Evolutions.Tiers = {}
for k = 1, 3 do
	local front = 1.6 + (k - 1) * 9
	Evolutions.Tiers[k] = { top = Evolutions.Base + Evolutions.Rise * k, front = front, hw = 25.4 - (k - 1) * Evolutions.Flight, row = front + 3.3 }
end
-- Rarity bands (three looks each); the overhead tag uses the same order. Commons glow cyan like the reference.
Evolutions.Bands = {
	{ name = 'COMMON', color = C(96, 222, 255) },
	{ name = 'UNCOMMON', color = C(86, 232, 112) },
	{ name = 'RARE', color = C(70, 136, 255) },
	{ name = 'EPIC', color = C(186, 96, 255) },
	{ name = 'LEGENDARY', color = C(255, 192, 44) },
}
-- Pose per look (SkinArt.Poses), so neighbours never stand the same way.
Evolutions.Poses = {
	CornerKid = 'wave', Pickpocket = 'swagger', Lookout = 'point', Bandit = 'hips', Hustler = 'cheer',
	Crook = 'swagger', GetawayDriver = 'flex', Enforcer = 'hips', StreetBoss = 'boss', Gangster = 'point',
	Capo = 'hips', Consigliere = 'easy', Underboss = 'swagger', TheDon = 'boss', Kingpin = 'cheer',
}
Evolutions.Featured = 'Kingpin'
Evolutions.TowerX = 26.6 -- light towers on the front corners of the slab
Evolutions.FeaturedScale = 1.2
Evolutions.Scale = 1.12 -- the other figures: a bit over player size, so they fill their pads like the reference
Evolutions.Colors = {
	top = C(206, 209, 216), cap = C(184, 188, 198), riser = C(150, 155, 167), rim = C(84, 88, 102), steel = C(92, 98, 112),
	kick = C(118, 122, 134), hazard = C(255, 200, 40), ink = C(26, 26, 32), pad = C(232, 236, 244), backdrop = C(46, 54, 80),
	truss = C(64, 68, 80),
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

---------------------------------------------------------------------------------------------- truss
-- Square lattice truss along +Y of `cf` (origin at the bottom centre): four chords, rungs and a zigzag of
-- braces on every face (the light towers).
function Evolutions.truss(c, cf, w, len, color)
	local t = c:at(cf)
	local h = w / 2
	local corners = { V(-h, 0, -h), V(h, 0, -h), V(h, 0, h), V(-h, 0, h) }
	for _, k in corners do t:bar('TrussChord', k, k + V(0, len, 0), 0.32, color, M.Metal) end
	local n = math.max(1, math.round(len / (w * 1.25)))
	local seg = len / n
	for i = 0, n do
		local y = i * seg
		for f = 1, 4 do
			local a, b = corners[f], corners[f % 4 + 1]
			decor(t:bar('TrussRung', a + V(0, y, 0), b + V(0, y, 0), 0.2, color, M.Metal))
			if i < n then
				local flip = (i + f) % 2 == 0
				decor(t:bar('TrussBrace', (flip and a or b) + V(0, y, 0), (flip and b or a) + V(0, y + seg, 0), 0.16, color, M.Metal))
			end
		end
	end
	return t
end

---------------------------------------------------------------------------------------------- podium
-- One stair flight in the frame's +Z direction: `steps` steps from y0 to y1 between x0 and x1, starting at
-- z0, with hazard-striped noses and steel cheeks.
function Evolutions.flight(c, x0, x1, z0, y0, y1)
	local col = Evolutions.Colors
	local n = Evolutions.Steps
	local rise, run = (y1 - y0) / n, Evolutions.Flight / n
	local f = c:group('Stairs')
	for i = 1, n do
		local z = z0 + (i - 1) * run
		studs(f:box('Step', V(x0, y0, z), V(x1, y0 + i * rise, z + run), i % 2 == 0 and col.top or col.cap, M.Plastic))
		-- Hazard nose: yellow and black blocks along the front edge.
		local w = (x1 - x0) / 5
		for j = 0, 4 do
			decor(f:box('HazardNose', V(x0 + j * w, y0 + i * rise - 0.14, z - 0.06), V(x0 + (j + 1) * w, y0 + i * rise + 0.04, z + 0.32), (j + i) % 2 == 0 and col.hazard or col.ink, M.SmoothPlastic))
		end
	end
	return f
end

function Evolutions.podium(c)
	local col = Evolutions.Colors
	local B, back = Evolutions.Base, Evolutions.Back
	local p = c:group('Podium')
	-- Floor slab with a darker studded rim (the reference's two-tone edge).
	studs(p:box('Slab', V(-28, 0, 0), V(28, B, 32), col.top, M.Plastic))
	for _, r in { { V(-28, 0, 0), V(28, B + 0.12, 0.9) }, { V(-28, 0, 31.1), V(28, B + 0.12, 32) }, { V(-28, 0, 0.9), V(-27.1, B + 0.12, 31.1) }, { V(27.1, 0, 0.9), V(28, B + 0.12, 31.1) } } do
		studs(p:box('SlabRim', r[1], r[2], col.rim, M.Plastic))
	end
	local below = B
	for k, t in Evolutions.Tiers do
		local fl = Evolutions.Flight
		local inner = t.hw - fl
		local tier = p:group('Tier' .. k)
		-- Body in riser grey; the centre runs to the front, the two sides stop behind the corner stairs.
		studs(tier:box('Riser', V(-inner, below, t.front), V(inner, t.top - 0.3, back), col.riser, M.Plastic), true)
		for _, s in { -1, 1 } do
			studs(tier:box('Riser', V(s * inner, below, t.front + fl), V(s * t.hw, t.top - 0.3, back), col.riser, M.Plastic), true)
		end
		-- Studded cap with a lip over the riser and a dark studded band along its open edges (the reference's
		-- two-tone rim), a dark band under the lip with a yellow safety line on its face, diamond-plate kick plates.
		studs(tier:box('Cap', V(-inner, t.top - 0.3, t.front + 0.55), V(inner, t.top, back), col.top, M.Plastic))
		studs(tier:box('EdgeRim', V(-inner, t.top - 0.3, t.front - 0.15), V(inner, t.top, t.front + 0.55), col.rim, M.Plastic))
		for _, s in { -1, 1 } do
			studs(tier:box('Cap', V(s * inner, t.top - 0.3, t.front + fl + 0.55), V(s * (t.hw - 0.55), t.top, back), col.top, M.Plastic))
			studs(tier:box('EdgeRim', V(s * inner, t.top - 0.3, t.front + fl - 0.15), V(s * (t.hw + 0.15), t.top, t.front + fl + 0.55), col.rim, M.Plastic))
			studs(tier:box('EdgeRim', V(s * (t.hw - 0.55), t.top - 0.3, t.front + fl + 0.55), V(s * (t.hw + 0.15), t.top, back), col.rim, M.Plastic))
			studs(tier:box('SideRim', V(s * (t.hw + 0.1), t.top - 0.75, t.front + fl), V(s * (t.hw + 0.25), t.top - 0.3, back), col.rim, M.Plastic))
			tier:box('SideKick', V(s * (t.hw + 0.05), below, t.front + fl), V(s * (t.hw + 0.18), below + 0.5, back), col.kick, M.DiamondPlate)
		end
		studs(tier:box('FrontRim', V(-inner, t.top - 0.75, t.front - 0.25), V(inner, t.top - 0.3, t.front), col.rim, M.Plastic))
		decor(tier:box('SafetyLine', V(-inner, t.top - 0.22, t.front - 0.2), V(inner, t.top - 0.08, t.front - 0.14), col.hazard, M.SmoothPlastic))
		tier:box('KickPlate', V(-inner, below, t.front - 0.12), V(inner, below + 0.5, t.front), col.kick, M.DiamondPlate)
		-- Steel ribs on the riser between the pads.
		for x = -17.5, 17.5, Evolutions.Spacing do
			-- (tier 1 carries the sign in the middle instead)
			if math.abs(x) < inner - 0.6 and not (k == 1 and math.abs(x) < 14) then
				tier:box('Rib', V(x - 0.3, below + 0.5, t.front - 0.18), V(x + 0.3, t.top - 0.75, t.front), col.steel, M.Metal)
			end
		end
		-- Corner stairs up from the level below.
		for _, s in { -1, 1 } do
			local a, b = s * inner, s * t.hw
			Evolutions.flight(tier, math.min(a, b), math.max(a, b), t.front, below, t.top)
			tier:box('StairCheek', V(s * inner - 0.2, below, t.front), V(s * inner + 0.2, t.top - 0.3, t.front + fl), col.steel, M.Metal)
		end
		below = t.top
	end
	return p
end

---------------------------------------------------------------------------------------------- looks
-- The label over a figure: name in the band colour, power needed and gain on one line, the action chip.
function Evolutions.label(c, pos, s, band)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(4.6, 1.95)
	g.MaxDistance = 42
	g.LightInfluence = 0
	g.Parent = anchor
	local function text(name, value, color, x, y, w, h, thickness)
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
		local st = Instance.new('UIStroke')
		st.Color = C(24, 22, 40)
		st.Thickness = thickness or 2
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = g
		return t
	end
	text('Title', s.Name, band.color:Lerp(P.white, 0.3), 0, 0, 1, 0.4, 3)
	text('Price', s.Required == 0 and 'FREE' or compact(s.Required) .. ' POWER', C(255, 222, 70), 0.02, 0.42, 0.52, 0.26)
	text('Gain', '+' .. s.Gain .. '/sec', C(126, 255, 171), 0.56, 0.42, 0.42, 0.26)
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.BackgroundColor3 = C(24, 22, 40)
	chip.BackgroundTransparency = 0.25
	chip.BorderSizePixel = 0
	chip.Position = UDim2.fromScale(0.3, 0.71)
	chip.Size = UDim2.fromScale(0.4, 0.28)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = chip
	chip.Parent = g
	-- A new player's view; Lobby.client rewrites it (EQUIPPED / EQUIP / BUY).
	text('Detail', s.Required == 0 and 'EQUIPPED' or 'BUY', s.Required == 0 and C(255, 126, 119) or P.white, 0.3, 0.72, 0.4, 0.26)
	return anchor
end

-- Gold padlock floating in front of a locked figure's chest (the client hides it once the look unlocks).
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

-- Glowing pad: a pale steel block with a dark bevel under the top, a neon inset in the band colour with a
-- brighter core, the band's name on a dark strip at the front, a light and motes rising off it.
function Evolutions.pad(c, x, y, z, band, size)
	local col = Evolutions.Colors
	local h = size / 2
	c:box('PadBlock', V(x - h, y, z - h), V(x + h, y + 0.7, z + h), col.pad, M.SmoothPlastic)
	-- Glow spilling onto the floor round the block.
	local halo = decor(c:box('PadHalo', V(x - h - 0.6, y, z - h - 0.6), V(x + h + 0.6, y + 0.04, z + h + 0.6), band.color, M.Neon))
	halo.Transparency, halo.CastShadow = 0.72, false
	c:box('PadBevel', V(x - h - 0.06, y + 0.5, z - h - 0.06), V(x + h + 0.06, y + 0.62, z + h + 0.06), col.rim, M.SmoothPlastic)
	local glow = decor(c:box('PadGlow', V(x - h + 0.28, y + 0.7, z - h + 0.28), V(x + h - 0.28, y + 0.78, z + h - 0.28), band.color, M.Neon))
	glow.CastShadow = false
	decor(c:box('PadCore', V(x - h + 0.95, y + 0.78, z - h + 0.95), V(x + h - 0.95, y + 0.8, z + h - 0.95), band.color:Lerp(P.white, 0.3), M.Neon)).CastShadow = false
	local strip = c:box('BandStrip', V(x - h + 0.4, y + 0.08, z - h - 0.08), V(x + h - 0.4, y + 0.46, z - h + 0.02), col.ink, M.SmoothPlastic)
	line(surface(strip, Enum.NormalId.Front, 50), 'Band', band.name, band.color:Lerp(P.white, 0.2), FONT.loud, 0.06, 0.88, C(10, 10, 16), 1)
	light(glow, band.color, 1.1, 9)
	-- A soft sheet of light standing on the pad and motes drifting up through it.
	local up0 = Evolutions.attach(glow, 'GlowBase', V(0, 0.05, 0))
	local up1 = Evolutions.attach(glow, 'GlowTop', V(0, 3.4, 0))
	-- (the sheet of light only stands on unlocked pads: the client switches it off while locked)
	Evolutions.beam(glow, 'PadGlowSheet', up0, up1, size - 0.9, size - 0.4, band.color, 0.6):SetAttribute('UnlockedOnly', true)
	Evolutions.emitter(glow, 'PadMotes', 'dust', {
		Rate = 3, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(0.8, 1.8), SpreadAngle = Vector2.new(8, 8),
		EmissionDirection = Enum.NormalId.Top, Acceleration = V(0, 0.4, 0), LightEmission = 1,
		Size = Evolutions.seq({ { 0, 0 }, { 0.2, 0.28, 0.08 }, { 1, 0 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.2, 0.15 }, { 1, 1 } }),
		Color = ColorSequence.new(band.color:Lerp(P.white, 0.5), band.color),
	})
	return glow
end

-- One look: pad, posed figure, padlock, label and the equip point, all in Morphs/Skin_<Id>.
function Evolutions.look(c, s, art, x, y, z, opts)
	local band = Evolutions.band(s.Index)
	local st, model = c:group('Skin_' .. s.Id)
	model:SetAttribute('Look', s.Id)
	model:SetAttribute('Index', s.Index)
	model:SetAttribute('Required', s.Required)
	model:SetAttribute('Band', band.name)
	-- The featured look stays in colour while locked (only the padlock says so): it is the goal on show.
	if opts.featured then model:SetAttribute('Showcase', true) end
	local featured = opts.featured
	local scale = featured and Evolutions.FeaturedScale or Evolutions.Scale
	local feet = y + 0.8
	if featured then
		feet = Evolutions.throne(st, x, y, z, band)
	else
		Evolutions.pad(st, x, y, z, band, Evolutions.Pad)
	end
	-- The figure (SkinArt; the stand still works without it), turned a few degrees so the row doesn't read
	-- as copies. The featured one turns and bobs (HoodMotion, client side).
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
	end
	local height = 5.6 * scale
	-- A few glints round an unlocked figure (the client switches them off while it is locked).
	local glints = ghost(st:part('UnlockedFx', V(3 * scale, 5 * scale, 1.6 * scale), CFrame.new(x, feet + 2.8 * scale, z), band.color))
	glints.CastShadow = false
	glints:SetAttribute('UnlockedOnly', true)
	Evolutions.emitter(glints, 'Glints', 'glitter', {
		Rate = 1.6, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0), LightEmission = 1, RotSpeed = NumberRange.new(-60, 60),
		Size = Evolutions.seq({ { 0, 0 }, { 0.35, 0.6, 0.15 }, { 1, 0 } }), Color = ColorSequence.new(P.white, band.color:Lerp(P.white, 0.5)), ZOffset = 1,
	})
	Evolutions.padlock(st, V(x, feet + 2.9 * scale, z - 1.15 * scale), scale)
	if s.Required == 0 then
		for _, d in model.Lock:GetDescendants() do
			if d:IsA('BasePart') then d.Transparency = 1 end
		end
	end
	Evolutions.label(st, V(x, feet + height + (featured and 1.7 or 1.25), z), s, band)
	-- Equip point at knee height just in front of the pad (prompt + server distance check).
	local front = z - (featured and 3.1 or Evolutions.Pad / 2) - 0.5
	ghost(st:box('Interact', V(x - 0.6, y + 0.6, front - 0.6), V(x + 0.6, y + 1.8, front + 0.6), P.white)).CastShadow = false
	return model, feet, height
end

-- The Kingpin's throne: a low studded dark plinth with a gold trim, a turntable with a colour-cycling neon ring,
-- halo, glitter and rays. Returns the height the figure floats at.
function Evolutions.throne(c, x, y, z, band)
	local gold, dark = band.color, C(36, 36, 46)
	local h = 2.8
	studs(c:box('ThroneBase', V(x - h, y, z - h), V(x + h, y + 0.7, z + h), dark, M.Plastic), true)
	c:box('ThroneTrim', V(x - h - 0.08, y + 0.55, z - h - 0.08), V(x + h + 0.08, y + 0.72, z + h + 0.08), gold, M.Foil)
	c:part('Turntable', V(0.3, 4.6, 4.6), CFrame.new(x, y + 0.85, z) * CFrame.Angles(0, 0, math.pi / 2), C(232, 232, 240), M.Metal, Enum.PartType.Cylinder)
	local ring = decor(c:part('TurntableRing', V(0.12, 5, 5), CFrame.new(x, y + 0.78, z) * CFrame.Angles(0, 0, math.pi / 2), gold, M.Neon, Enum.PartType.Cylinder))
	ring.CastShadow = false
	ring:SetAttribute('Hue', 14)
	ring:AddTag('HoodMotion')
	local strip = c:box('BandStrip', V(x - 2.2, y + 0.08, z - h - 0.1), V(x + 2.2, y + 0.5, z - h + 0.02), C(20, 18, 26), M.SmoothPlastic)
	line(surface(strip, Enum.NormalId.Front, 40), 'Band', 'LEGENDARY • THE TOP LOOK', gold:Lerp(P.white, 0.2), FONT.loud, 0.08, 0.84, C(40, 20, 0), 1)
	light(ring, gold, 1.6, 12)
	-- Effects around the figure: a warm halo, star glints and glitter, rising rays.
	local core = ghost(c:part('FeaturedFx', V(3.4, 6, 2.4), CFrame.new(x, y + 1.0 + 3.4, z), gold))
	core.CastShadow = false
	Evolutions.emitter(core, 'Halo', 'softglow', {
		Rate = 1, Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), Rotation = NumberRange.new(0), ZOffset = -2, LightEmission = 1,
		Size = Evolutions.seq({ { 0, 8 }, { 1, 9 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.4, 0.62 }, { 0.6, 0.62 }, { 1, 1 } }), Color = ColorSequence.new(gold),
	})
	Evolutions.emitter(core, 'Glitter', 'glitter', {
		Rate = 9, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		RotSpeed = NumberRange.new(-90, 90), Size = Evolutions.seq({ { 0, 0 }, { 0.4, 0.9, 0.3 }, { 1, 0 } }), Color = ColorSequence.new(P.white, gold), ZOffset = 1,
	})
	local base = ghost(c:part('FeaturedRays', V(4, 0.2, 4), CFrame.new(x, y + 1.05, z), gold))
	base.CastShadow = false
	Evolutions.emitter(base, 'Rays', 'ray', {
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1.2, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.1),
		Rotation = NumberRange.new(0), LightEmission = 1, Size = Evolutions.seq({ { 0, 7 }, { 1, 8 } }),
		Transparency = Evolutions.seq({ { 0, 1 }, { 0.4, 0.55 }, { 0.6, 0.55 }, { 1, 1 } }), Color = ColorSequence.new(gold:Lerp(P.white, 0.4)), ZOffset = -1,
	})
	Evolutions.emitter(base, 'GroundRing', 'ring', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Rate = 0.8, Lifetime = NumberRange.new(1.6),
		Speed = NumberRange.new(0.01), LightEmission = 1, Size = Evolutions.seq({ { 0, 1 }, { 1, 5 } }), Transparency = Evolutions.seq({ { 0, 0.3 }, { 1, 1 } }),
		Color = ColorSequence.new(gold),
	})
	return y + 1.0 + 0.25
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
-- Light towers on the front corners of the slab (outside the rows, so nothing hides a figure from above):
-- a lattice truss with a hazard wrap, a lamp bar on top with an amber beacon and two spotlights each, aimed
-- down at the rows. targets: { { side = -1 | 1, at = Vector3 } }.
function Evolutions.lights(c, targets)
	local col = Evolutions.Colors
	local g = c:group('LightTowers')
	local top = 17.8
	for _, s in { -1, 1 } do
		local x = s * Evolutions.TowerX
		g:box('TowerFoot', V(x - 1.2, Evolutions.Base, 0.1), V(x + 1.2, Evolutions.Base + 0.5, 2.5), col.rim, M.DiamondPlate)
		Evolutions.truss(g, CFrame.new(x, Evolutions.Base + 0.5, 1.3), 2, top - Evolutions.Base - 0.5, col.truss)
		for i = 0, 3 do
			decor(g:box('TowerHazard', V(x - 1.08, Evolutions.Base + 0.5 + i * 0.5, 0.22), V(x + 1.08, Evolutions.Base + 1 + i * 0.5, 2.38), i % 2 == 0 and col.hazard or col.ink, M.SmoothPlastic))
		end
		g:box('LampBar', V(x - s * 2.2, top, 0.9), V(x + s * 1, top + 0.35, 1.7), col.steel, M.Metal)
		decor(g:box('BeaconBase', V(x - 0.35, top + 0.35, 1.0), V(x + 0.35, top + 0.55, 1.6), col.ink, M.Metal))
		local beacon = decor(g:part('Beacon', V(0.6, 0.5, 0.5), CFrame.new(x, top + 0.8, 1.3), C(255, 140, 40), M.Neon))
		beacon.CastShadow = false
	end
	for i, t in targets do
		local lamp = g:group('Spotlight')
		-- (both lamps sit on the inner half of the bar, so the heads stay inside the footprint)
		local x = t.side * (Evolutions.TowerX - (i % 2 == 0 and 0.2 or 1.6))
		local pos = V(x, top + 1.1, 1.3)
		lamp:box('LampYoke', V(x - 0.12, top + 0.35, 1.1), V(x + 0.12, top + 0.9, 1.5), col.ink, M.Metal)
		local aim = CFrame.lookAt(pos, t.at)
		decor(lamp:part('LampCan', V(0.95, 0.95, 1.3), aim, C(30, 30, 36), M.Metal))
		decor(lamp:part('LampBarnDoor', V(1.3, 0.1, 0.45), aim * CFrame.new(0, 0.55, -0.75) * CFrame.Angles(math.rad(-25), 0, 0), C(30, 30, 36), M.Metal))
		local lens = decor(lamp:part('LampLens', V(0.78, 0.78, 0.1), aim * CFrame.new(0, 0, -0.67), C(255, 244, 214), M.Neon))
		lens.CastShadow = false
		local spot = Instance.new('SpotLight')
		spot.Face, spot.Color, spot.Brightness, spot.Range, spot.Angle, spot.Shadows = Enum.NormalId.Front, C(255, 236, 200), 2, 40, 28, false
		spot.Parent = lens
		-- A soft flare on the lens so the lamp reads as switched on.
		Evolutions.emitter(Evolutions.attach(lens, 'Flare', V(0, 0, -0.15)), 'LensFlare', 'softglow', {
			Rate = 1, Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), Rotation = NumberRange.new(0), LightEmission = 1, ZOffset = 0.5,
			Size = Evolutions.seq({ { 0, 2.6 }, { 1, 2.8 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.3, 0.45 }, { 0.7, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 240, 200)),
		})
	end
	-- Dust drifting over the podium, caught by the light.
	local dust = ghost(g:part('StageDust', V(40, 8, 20), CFrame.new(0, 10, 16), P.white))
	Evolutions.emitter(dust, 'Dust', 'dust', {
		Rate = 8, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6,
		Size = Evolutions.seq({ { 0, 0 }, { 0.3, 0.14, 0.05 }, { 1, 0 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 240, 210)),
	})
	return g
end

-- The EVOLUTIONS sign across the front of the first tier: a dark board framed by neon tubes, yellow
-- letters with a pink outline, an arrow-up glyph at each end.
function Evolutions.sign(c)
	local g = c:group('Sign')
	local t = Evolutions.Tiers[1]
	local w, y0, y1, z = 13.5, Evolutions.Base + 0.45, t.top - 0.85, t.front - 0.32
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
	return g
end

-- Backdrop behind the tiers: corrugated steel, tall behind the top row and lower on the wings, hazard
-- tape under the cap, neon bars between the top-row figures and stacks of up-arrows (evolving = going up)
-- on the wings that cycle through the colours.
function Evolutions.backdrop(c)
	local col = Evolutions.Colors
	local d = c:group('Backdrop')
	local z0, z1 = Evolutions.Back, Evolutions.Back + 1.2
	local t2, t3 = Evolutions.Tiers[2], Evolutions.Tiers[3]
	local wing = t2.top + 8
	local panels = { { -t3.hw, t3.hw, 19.4 }, { -25.4, -t3.hw, wing }, { t3.hw, 25.4, wing } }
	for _, pnl in panels do
		local x0, x1, top = pnl[1], pnl[2], pnl[3]
		d:box('BackWall', V(x0, Evolutions.Base, z0 + 0.3), V(x1, top, z1), col.backdrop, M.Metal)
		for x = x0 + 0.5, x1 - 0.4, 1.1 do
			decor(d:box('Corrugation', V(x, Evolutions.Base, z0 + 0.12), V(x + 0.45, top - 0.4, z0 + 0.32), col.backdrop:Lerp(P.white, 0.1), M.Metal))
		end
		studs(d:box('WallCap', V(x0 - 0.2, top, z0), V(x1 + 0.2, top + 0.5, z1 + 0.2), col.steel, M.Plastic))
		for i = 0, math.floor((x1 - x0) / 1.2) - 1 do
			decor(d:box('CapHazard', V(x0 + i * 1.2, top - 0.4, z0 - 0.02), V(x0 + i * 1.2 + 1.2, top, z0 + 0.12), i % 2 == 0 and col.hazard or col.ink, M.SmoothPlastic))
		end
	end
	local bars = { C(96, 222, 255), C(186, 96, 255), C(186, 96, 255), C(96, 222, 255) }
	for i, x in { -17.5, -10.5, 10.5, 17.5 } do
		decor(d:box('NeonBar', V(x - 0.25, t3.top + 0.6, z0 - 0.05), V(x + 0.25, 18.6, z0 + 0.12), bars[i], M.Neon)).CastShadow = false
	end
	for _, side in { -1, 1 } do
		local arrows, model = d:group('UpArrows')
		model:SetAttribute('Hue', 12)
		model:AddTag('HoodMotion')
		local cx = side * 22.4
		for i = 0, 2 do
			local y = t2.top + 2.6 + i * 1.6
			local glow = C(255, 192, 44):Lerp(P.white, i * 0.15)
			for _, s in { -1, 1 } do
				local a = V(cx, y + 1.0, z0 - 0.06)
				local b = V(cx + s * 2.0, y, z0 - 0.06)
				local mid = (a + b) / 2
				decor(arrows:part('Chevron', V((b - a).Magnitude + 0.4, 0.45, 0.16), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(b.Y - a.Y, b.X - a.X)), glow, M.Neon)).CastShadow = false
			end
		end
	end
	return d
end

-- Back-corner clutter on the dead-end side landings: speaker stacks, road cases, a clothes rail with the
-- next jackets, shoe boxes, a coffee on a case.
function Evolutions.props(c)
	local col = Evolutions.Colors
	local pr = c:group('Props')
	local t1, t2 = Evolutions.Tiers[1], Evolutions.Tiers[2]
	-- Speaker stacks on tier 1's side landings.
	for _, s in { -1, 1 } do
		local x = s * (t2.hw + 1.5)
		for i, h in { 2.6, 2.2 } do
			local y0 = t1.top + (i - 1) * 2.6
			local w = i == 1 and 2.4 or 2.1
			pr:box('Speaker', V(x - w / 2 + (i - 1) * 0.1 * s, y0, 26.4 - w / 2), V(x + w / 2, y0 + h, 26.4 + w / 2), C(30, 30, 34), M.SmoothPlastic)
			pr:part('SpeakerCone', V(0.2, h * 0.55, h * 0.55), CFrame.new(x, y0 + h * 0.4, 26.4 - w / 2 - 0.05) * CFrame.Angles(0, math.pi / 2, 0), C(60, 60, 66), M.Metal, Enum.PartType.Cylinder)
			pr:part('Tweeter', V(0.2, h * 0.22, h * 0.22), CFrame.new(x, y0 + h * 0.82, 26.4 - w / 2 - 0.05) * CFrame.Angles(0, math.pi / 2, 0), C(90, 90, 98), M.Metal, Enum.PartType.Cylinder)
		end
		-- Road case with a coffee cup on it, one side; a stack of shoe boxes the other.
		if s == 1 then
			pr:box('RoadCase', V(x - 1.3, t1.top, 20.6), V(x + 1.3, t1.top + 1.6, 23.2), C(46, 48, 56), M.SmoothPlastic)
			for _, z in { 20.62, 23.18 } do pr:box('CaseEdge', V(x - 1.35, t1.top, z - 0.06), V(x + 1.35, t1.top + 1.65, z + 0.06), C(190, 194, 204), M.Metal) end
			pr:post('Coffee', 0.18, 0.42, V(x + 0.6, t1.top + 1.6, 21.4), C(250, 250, 250), M.SmoothPlastic)
			pr:post('CoffeeLid', 0.2, 0.08, V(x + 0.6, t1.top + 2.02, 21.4), C(60, 40, 30), M.SmoothPlastic)
		else
			for i, sb in { { 0, C(230, 70, 60) }, { 1, C(250, 250, 250) }, { 2, C(255, 160, 40) } } do
				local y0 = t1.top + sb[1] * 0.7
				pr:box('ShoeBox', V(x - 1 + i * 0.08, y0, 20.8 + i * 0.1), V(x + 1 + i * 0.08, y0 + 0.7, 22.2 + i * 0.1), sb[2], M.SmoothPlastic)
			end
		end
	end
	-- Clothes rail on the left landing of tier 2 (viewer's left = +X): the jackets you are working toward.
	local x = t2.hw - 1.5
	local y = t2.top
	for _, z in { 22.6, 27.4 } do
		pr:box('RailFoot', V(x - 0.8, y, z - 0.2), V(x + 0.8, y + 0.2, z + 0.2), col.steel, M.Metal)
		pr:box('RailPost', V(x - 0.1, y + 0.2, z - 0.1), V(x + 0.1, y + 4.6, z + 0.1), C(200, 204, 212), M.Metal)
	end
	pr:box('RailBar', V(x - 0.1, y + 4.5, 22.5), V(x + 0.1, y + 4.7, 27.5), C(200, 204, 212), M.Metal)
	for i, jc in { C(146, 75, 185), C(201, 175, 124), C(221, 62, 66), C(56, 67, 106), C(44, 45, 52) } do
		local z = 22.9 + i * 0.7
		pr:box('Hanger', V(x - 0.05, y + 4.2, z - 0.25), V(x + 0.05, y + 4.5, z + 0.25), C(150, 110, 70), M.Wood)
		pr:box('Jacket', V(x - 0.7, y + 1.9, z - 0.22), V(x + 0.7, y + 4.25, z + 0.22), jc, M.Fabric)
	end
	return pr
end

-- Low stage haze rolling over the top tier and spilling down the front of the throne.
function Evolutions.fog(c)
	local t3 = Evolutions.Tiers[3]
	local f = ghost(c:part('StageFog', V(34, 0.4, 4), CFrame.new(0, t3.top + 0.4, t3.row + 4.6), P.white))
	f.CastShadow = false
	Evolutions.emitter(f, 'Haze', 'mist', {
		Rate = 5, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(70, 10),
		EmissionDirection = Enum.NormalId.Front, Acceleration = V(0, -0.05, 0), RotSpeed = NumberRange.new(-10, 10), LightEmission = 0.3,
		Size = Evolutions.seq({ { 0, 2.5 }, { 1, 5.5 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.25, 0.82 }, { 0.7, 0.86 }, { 1, 1 } }),
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
	local m, morphs = e:group('Morphs')
	-- The stand is small and every client needs all of it (prompts, labels, the guide arrow).
	pcall(function() morphs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	local wobble = { -5, 3, -2, 4, -4 }
	for i, s in skins.List do
		local row = (i - 1) // 5 + 1
		local t = Evolutions.Tiers[row]
		if not t then break end
		local colIndex = (i - 1) % 5 + 1
		-- Top row: the Kingpin takes the middle and the other four close up around it.
		if row == 3 then colIndex = ({ 1, 2, 4, 5, 3 })[colIndex] end
		local x = (3 - colIndex) * Evolutions.Spacing
		local featured = s.Id == Evolutions.Featured
		local stand, feet = Evolutions.look(m, s, art, x, t.top, t.row, { featured = featured, yaw = featured and 0 or wobble[(i - 1) % 5 + 1] })
		if row == 3 and not featured then Evolutions.sparkle(m:into(stand), x, feet, t.row, Evolutions.band(s.Index).color) end
	end
	-- Each tower lights the near side of the two lower rows (steep enough to read as stage light).
	local t1, t2 = Evolutions.Tiers[1], Evolutions.Tiers[2]
	local chest = 0.8 + 3 * Evolutions.Scale
	Evolutions.lights(e, {
		{ side = 1, at = V(14, t1.top + chest, t1.row) },
		{ side = 1, at = V(7, t2.top + chest, t2.row) },
		{ side = -1, at = V(-14, t1.top + chest, t1.row) },
		{ side = -1, at = V(-7, t2.top + chest, t2.row) },
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
-- World 1's spawn: the HOOD BOXING CLUB, an old warehouse at the south end of the street. Corrugated walls on
-- red steel columns, open trusses under a skylit roof, pallet racks and containers round the edges, and a
-- raised studded deck in a cross: the big north door (out to Stage 1) down to the ARMORY platform, the spawn
-- badge where it crosses the training aisle. West: the training platform (two rows of four bags facing a wide
-- aisle, the cardio corner with three treadmills at its far end). East: the EVOLUTIONS podium. By the door:
-- reward crates. South-west: the locked WORLD 2 garage, south-east: the champ statue and three leaderboards.
-- Builders from other files (Stations, Treadmills, Evolutions, Armory) fill the slots; a missing or failing
-- one leaves a labelled placeholder box of the slot's size.
-- Map frame (studs): interior x -66..66, z 6..156 (north wall z 5..6, the Stage 1 gate at z = 0 stays
-- outside), floor top y = 0, deck top y = Lobby.Deck. North = -Z.
-- Lobby.Slots: name -> CFrame in the map frame (V2.Origin * cf is the world), filled by Lobby.build.
local Lobby = {}

Lobby.W = 66 -- interior half width (walls x ±66..±67)
Lobby.N, Lobby.S = 6, 156 -- interior north and south faces
Lobby.Eave, Lobby.Ridge = 30, 38
Lobby.Deck = SPAWN.Y -- walkway and platform top (1.2)
Lobby.Walk = 4.5 -- the N-S walkway's half width
Lobby.CrossZ = SPAWN.Z -- the crossing (E-W band z ±6 round it)
Lobby.Door, Lobby.DoorH = 12, 20 -- north door half width and height
Lobby.Bay = 15 -- column / truss spacing along z, from z = 6
Lobby.Slots = {}
Lobby.Colors = {
	floor = C(112, 106, 100), deck = C(212, 215, 221), rim = C(80, 84, 98), groove = C(44, 46, 54),
	wall = C(54, 108, 146), ridge = C(72, 132, 172), block = C(170, 170, 174), hazard = C(250, 196, 32),
	column = C(196, 64, 46), truss = C(58, 62, 72), roof = C(146, 152, 160), glass = C(186, 224, 246),
	rackPost = C(40, 92, 196), rackBeam = C(244, 124, 34), rubber = C(40, 42, 48),
	warm = C(255, 196, 120), cool = C(80, 220, 255), pink = C(255, 70, 170), lime = C(150, 255, 70),
}
-- Training: bag stations in walking order (north row east to west facing the aisle, then the south row back
-- east), treadmills in the cardio corner (west end of the aisle, belts facing the west wall).
Lobby.Bags = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.RowX = { -14, -28.5, -43, -57.5 }
Lobby.RowZ = { 37, 83 }
Lobby.Treadmills = { 'Jog', 'Run', 'Sprint' }
Lobby.TreadZ = { 52, 60, 68 }

---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top.
function Lobby.slab(c, name, a, b, color)
	return studs(c:box(name, a, b, color, M.Plastic))
end
-- A ParticleEmitter with a built-in texture (the renderer reads PreviewTexture for the intended look).
function Lobby.fx(part, name, tex, props)
	local builtin = { dust = 'rbxasset://textures/particles/sparkles_main.dds', smoke = 'rbxasset://textures/particles/smoke_main.dds',
		mist = 'rbxasset://textures/particles/smoke_main.dds', glitter = 'rbxasset://textures/particles/sparkles_main.dds',
		sparkle = 'rbxasset://textures/particles/sparkles_main.dds', ray = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png' }
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
function Lobby.motion(model, pivot, spin, bob)
	model.WorldPivot = V2.Origin * pivot
	if spin then model:SetAttribute('Spin', spin) end
	if bob then model:SetAttribute('Bob', bob) end
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
-- Neon sign: dark board, glowing text, neon tube border.
function Lobby.neonSign(c, cf, w, h, text, color, sub)
	local rows = { { 'Title', text, color:Lerp(P.white, 0.35), FONT.loud, sub and 0.06 or 0.12, sub and 0.6 or 0.76, color:Lerp(P.black, 0.5), 4 } }
	if sub then table.insert(rows, { 'Sub', sub, P.white, FONT.title, 0.68, 0.26, P.black, 2 }) end
	local b = Lobby.board(c, 'NeonSign', cf, w, h, C(24, 26, 34), rows, 14)
	Lobby.neonFrame(c, cf, w, h, color)
	return b
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

---------------------------------------------------------------------------------------------- shell
-- Floor, walls, columns, door, roof. Roof parts are all named Roof* (the plan views hide them).
function Lobby.shell(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.Eave
	local s = L:group('Warehouse')
	-- Floor: one studded concrete slab, darker expansion joints every bay.
	Lobby.slab(s, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.floor)
	for z = N + Lobby.Bay, S - 1, Lobby.Bay do decor(s:box('FloorJoint', V(-W, 0, z - 0.12), V(W, 0.03, z + 0.12), K.floor:Lerp(P.black, 0.3), M.SmoothPlastic)) end
	for _, x in { -33, 33 } do decor(s:box('FloorJoint', V(x - 0.12, 0, N), V(x + 0.12, 0.03, S), K.floor:Lerp(P.black, 0.3), M.SmoothPlastic)) end

	-- A wall run: core, block wainscot with a hazard band, corrugated upper panel (ridges between columns).
	-- f(u, y, w): u along the wall, w = distance into the room from the interior face.
	local function run(f, u0, u1, y0, y1, ridgesOut)
		s:box('Wall', f(u0, y0, -1), f(u1, y1, 0), K.wall, M.SmoothPlastic)
		if y0 < 7 then
			s:box('WallBlock', f(u0, y0, 0), f(u1, math.min(7, y1), 0.3), K.block, M.Concrete)
			s:box('WallBand', f(u0, 6.9, 0), f(u1, 7.5, 0.42), K.hazard, M.SmoothPlastic)
			s:box('WallBand', f(u0, 0, 0), f(u1, 0.6, 0.42), K.rim, M.SmoothPlastic)
		end
		local lo = math.max(y0, 7.5)
		for u = u0 + 1.5, u1 - 1, 3 do
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
	run(south, -W, W, 0, H)
	run(north, -W, -Lobby.Door, 0, H, true)
	run(north, Lobby.Door, W, 0, H, true)
	run(north, -Lobby.Door, Lobby.Door, Lobby.DoorH, H, true)
	-- Gable ends up to the ridge.
	for _, z in { N - 0.5, S + 0.5 } do
		for _, sx in { -1, 1 } do
			s:wedge('RoofGable', V(1, Lobby.Ridge - H, W + 1), CFrame.new(sx * (W + 1) / 2, (H + Lobby.Ridge) / 2, z) * CFrame.Angles(0, -sx * math.pi / 2, 0), K.wall, M.SmoothPlastic)
		end
	end
	-- Columns on the side walls (and two wind columns on each end wall), hazard-wrapped feet.
	local function column(f, u)
		s:box('Column', f(u - 0.8, 0, 0), f(u + 0.8, H + 0.6, 1.2), K.column, M.Metal)
		s:box('ColumnFoot', f(u - 1.0, 0, 0), f(u + 1.0, 2.6, 1.4), K.hazard, M.SmoothPlastic)
		decor(s:box('ColumnStripe', f(u - 1.05, 1.0, 0), f(u + 1.05, 1.5, 1.45), P.black, M.SmoothPlastic))
	end
	for z = N, S, Lobby.Bay do
		column(west, z == N and N + 0.8 or z == S and S - 0.8 or z)
		column(east, z == N and N + 0.8 or z == S and S - 0.8 or z)
	end
	for _, x in { -33, 33 } do column(north, x); column(south, x) end
	-- Clerestory windows high on the side walls, in the bays the big signs and fans leave free.
	for _, zc in { 28.5, 88.5, 118.5 } do
		for _, f in { west, east } do
			s:box('WindowFrame', f(zc - 5.4, 20.6, -1.15), f(zc + 5.4, 27.4, 0.35), K.truss, M.Metal)
			local g = decor(s:box('Window', f(zc - 4.9, 21.1, -1.25), f(zc + 4.9, 26.9, 0.45), K.glass, M.Glass))
			g.Transparency = 0.25
			for _, du in { -1.6, 1.6 } do decor(s:box('WindowBar', f(zc + du - 0.15, 21.1, -1.3), f(zc + du + 0.15, 26.9, 0.5), K.truss, M.Metal)) end
		end
	end
	-- The north door: rolled-up door drum, guide rails, hazard-striped jambs, floor stripes outside.
	local d = s:group('NorthDoor')
	d:box('DoorDrum', V(-Lobby.Door - 1, Lobby.DoorH, N), V(Lobby.Door + 1, Lobby.DoorH + 2.6, N + 2.4), K.truss, M.Metal)
	d:box('DoorLip', V(-Lobby.Door, Lobby.DoorH - 0.6, N), V(Lobby.Door, Lobby.DoorH, N + 1.6), C(150, 154, 162), M.Metal)
	for _, sx in { -1, 1 } do
		local x = sx * Lobby.Door
		d:box('DoorRail', V(x - 0.5, 0, N), V(x + 0.5, Lobby.DoorH, N + 1.4), K.truss, M.Metal)
		for k = 0, 4 do
			d:box('JambStripe', V(x - 0.8 * sx - 0.6, k * 4, N - 1.4), V(x - 0.8 * sx + 0.6, k * 4 + 2, N + 0.1), k % 2 == 0 and K.hazard or P.black, M.SmoothPlastic)
		end
	end
	-- Floor hazard stripes across the doorway.
	for x = -Lobby.Door + 1.5, Lobby.Door - 1.5, 3 do
		decor(d:part('DoorHazard', V(1.2, 0.05, 3.2), CFrame.new(x, 0.02, N - 2.4) * CFrame.Angles(0, math.rad(35), 0), K.hazard, M.SmoothPlastic))
	end
	-- Wing walls from the gate posts to the warehouse: the forecourt is closed on both sides.
	for _, sx in { -1, 1 } do
		s:box('WingWall', V(sx * 34.4, 0, 0.6), V(sx * 36, 12, N - 1), K.block, M.Concrete)
		s:box('WingCap', V(sx * 34.2, 12, 0.6), V(sx * 36.2, 12.6, N - 1), K.hazard, M.SmoothPlastic)
		local pole = s:box('WingLamp', V(sx * 35.2 - 0.4, 12.6, 2), V(sx * 35.2 + 0.4, 13.4, 3.4), K.truss, M.Metal)
		light(pole, K.warm, 0.8, 14)
	end

	-- Roof: trusses on every inner column line, purlins, metal sheets down the eaves and a long skylight
	-- down the middle. Sheets and glass cast no shadow, so the sun reaches the floor through the trusses.
	local function topY(x) return H + 0.3 + (Lobby.Ridge - H - 0.3) * (1 - math.abs(x) / W) end
	local r = L:group('Roof')
	for z = N + Lobby.Bay, S - Lobby.Bay, Lobby.Bay do
		r:box('RoofChord', V(-W, H - 0.6, z - 0.3), V(W, H, z + 0.3), K.truss, M.Metal)
		for _, sx in { -1, 1 } do
			r:bar('RoofTop', V(sx * W, H, z), V(0, Lobby.Ridge, z), 0.7, K.truss, M.Metal)
			for _, x in { 16.5, 33, 49.5 } do
				r:box('RoofWeb', V(sx * x - 0.2, H, z - 0.2), V(sx * x + 0.2, topY(x), z + 0.2), K.truss, M.Metal)
				r:bar('RoofWeb', V(sx * x, H - 0.3, z), V(sx * (x - 16.5), topY(x - 16.5) - 0.2, z), 0.35, K.truss, M.Metal)
			end
		end
		r:box('RoofWeb', V(-0.25, H, z - 0.25), V(0.25, Lobby.Ridge, z + 0.25), K.truss, M.Metal)
	end
	for _, x in { -49.5, -33, -16.5, 0, 16.5, 33, 49.5 } do
		r:box('RoofPurlin', V(x - 0.3, topY(x), N - 1), V(x + 0.3, topY(x) + 0.6, S + 1), K.truss, M.Metal)
	end
	for _, sx in { -1, 1 } do
		local a, b = V(sx * (W + 1.5), H + 0.6, (N + S) / 2), V(sx * 33, topY(33) + 0.6, (N + S) / 2)
		local sheet = r:part('RoofSheet', V(S - N + 3, 0.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) , K.roof, M.Metal)
		sheet.CastShadow = false
		local a2, b2 = V(sx * 33, topY(33) + 0.6, (N + S) / 2), V(0, Lobby.Ridge + 0.6, (N + S) / 2)
		local glass = r:part('RoofSkylight', V(S - N + 3, 0.3, (b2 - a2).Magnitude), CFrame.lookAt((a2 + b2) / 2, b2), K.glass, M.Glass)
		glass.Transparency, glass.CastShadow = 0.55, false
		r:box('RoofGutter', V(sx * W - 1.6, H, N - 1.5), V(sx * W + 1.6, H + 0.8, S + 1.5), K.truss, M.Metal).CastShadow = false
	end
	r:box('RoofRidgeCap', V(-1.2, Lobby.Ridge + 0.4, N - 1.5), V(1.2, Lobby.Ridge + 1.2, S + 1.5), K.truss, M.Metal).CastShadow = false
	return s
end

---------------------------------------------------------------------------------------------- deck
-- The raised studded deck: walkways and platforms in light tiles, darker rims on every outside edge, dark
-- grooves where the walkway passes the platforms, half-height steps down to the floor.
function Lobby.deck(L)
	local K, D, w = Lobby.Colors, Lobby.Deck, Lobby.Walk
	local d = L:group('Deck')
	local cz = Lobby.CrossZ
	local function top(name, x0, x1, z0, z1) return Lobby.slab(d, name, V(x0, 0, z0), V(x1, D, z1), K.deck) end
	local function rim(a, b) return Lobby.slab(d, 'DeckRim', a, b, K.rim) end
	local RW = 0.8
	-- Rims: n/s run along x at z, w/e run along z at x (the rim lies inside the region's edge).
	local function rimN(x0, x1, z) rim(V(x0, 0, z), V(x1, D + 0.04, z + RW)) end
	local function rimS(x0, x1, z) rim(V(x0, 0, z - RW), V(x1, D + 0.04, z)) end
	local function rimW(z0, z1, x) rim(V(x, 0, z0), V(x + RW, D + 0.04, z1)) end
	local function rimE(z0, z1, x) rim(V(x - RW, 0, z0), V(x, D + 0.04, z1)) end
	local walkS = 117
	-- N-S walkway, the crossing band, the two platforms, the armory platform.
	top('Walkway', -w, w, Lobby.N + 1.2, walkS)
	top('Crossing', -6, 6, cz - 6, cz + 6)
	top('TrainingDeck', -65.5, -6, 30, 90)
	top('PodiumDeck', 6, 65.5, 30, 90)
	top('ArmoryDeck', -30, 30, walkS, 147)
	for _, sx in { -1, 1 } do
		local function rx(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		-- Walkway edges (outside the crossing), platform edges, the grooves between.
		if sx < 0 then rimW(Lobby.N + 1.2, cz - 6, -w); rimW(cz + 6, walkS, -w) else rimE(Lobby.N + 1.2, cz - 6, w); rimE(cz + 6, walkS, w) end
		local p0, p1 = rx(6, 65.5)
		rimN(p0, p1, 30)
		rimS(p0, p1, 90)
		if sx < 0 then rimE(30, cz - 6, -6); rimE(cz + 6, 90, -6); rimW(30, 90, -65.5) else rimW(30, cz - 6, 6); rimW(cz + 6, 90, 6); rimE(30, 90, 65.5) end
		local g0, g1 = rx(w, 6)
		d:box('DeckGroove', V(g0, 0, 30), V(g1, D - 0.35, cz - 6), K.groove, M.SmoothPlastic)
		d:box('DeckGroove', V(g0, 0, cz + 6), V(g1, D - 0.35, 90), K.groove, M.SmoothPlastic)
		-- Armory platform rims (the walkway joins its north edge).
		local q0, q1 = rx(w, 30)
		rimN(q0, q1, walkS)
		if sx < 0 then rimW(walkS, 147, -30) else rimE(walkS, 147, 30) end
	end
	rimS(-30, 30, 147)
	-- Stairs: two low steps in front of the deck edge where people come up from the floor.
	local function stairX(x0, x1, z, dir) -- deck edge along x at z, the floor toward dir (-1 north, 1 south)
		for k = 1, 2 do
			local za, zb = z + dir * (k - 1) * 1.2, z + dir * k * 1.2
			Lobby.slab(d, 'DeckStep', V(x0, 0, math.min(za, zb)), V(x1, D * (3 - k) / 3, math.max(za, zb)), K.rim)
		end
	end
	local function stairZ(z0, z1, x, dir) -- deck edge along z at x, the floor toward dir (-1 west, 1 east)
		for k = 1, 2 do
			local xa, xb = x + dir * (k - 1) * 1.2, x + dir * k * 1.2
			Lobby.slab(d, 'DeckStep', V(math.min(xa, xb), 0, z0), V(math.max(xa, xb), D * (3 - k) / 3, z1), K.rim)
		end
	end
	stairX(-w, w, Lobby.N + 1.2, -1) -- the door end of the walkway
	stairZ(13, 23, -w, -1); stairZ(13, 23, w, 1) -- to the reward crates
	stairZ(98, 110, -w, -1); stairZ(98, 110, w, 1) -- to the WORLD 2 garage and the statue
	stairX(30, 42, 30, -1); stairX(14, 26, 90, 1) -- the podium deck's north and south sides
	stairZ(126, 138, -30, -1); stairZ(126, 138, 30, 1) -- armory platform ends (the reference's side stairs)
	-- Yellow kerb paint along the walkway where it runs on its own (north and south of the platforms).
	for _, seg in { { Lobby.N + 2, 29 }, { 91, walkS - 1 } } do
		for _, sx in { -1, 1 } do
			decor(d:box('KerbPaint', V(sx * (w + 0.05) - 0.06, 0.15, seg[1]), V(sx * (w + 0.05) + 0.06, D - 0.15, seg[2]), K.hazard, M.SmoothPlastic))
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- spawn badge
-- Our logo at the crossing: a navy plate, a gold eight-point star, a red "+1" disc in a cyan neon ring.
function Lobby.badge(L)
	local D, cz = Lobby.Deck, Lobby.CrossZ
	local b = L:at(CFrame.new(0, D, cz)):group('SpawnBadge')
	b:box('BadgePlate', V(-5.6, 0, -5.6), V(5.6, 0.06, 5.6), C(28, 34, 66), M.SmoothPlastic)
	decor(b:part('BadgeRing', V(0.1, 10.6, 10.6), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Lobby.Colors.cool, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	decor(b:part('BadgeInner', V(0.12, 9.6, 9.6), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), C(28, 34, 66), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	for k = 0, 1 do
		decor(b:part('BadgeStar', V(6.4, 0.14, 6.4), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.pi / 8 + k * math.pi / 4, 0), C(255, 204, 48), M.SmoothPlastic)).CastShadow = false
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		decor(b:part('BadgeRay', V(0.5, 0.13, 2), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -5.0), C(255, 204, 48), M.Neon)).CastShadow = false
	end
	local disc = decor(b:part('BadgeDisc', V(0.2, 4.6, 4.6), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), C(222, 44, 52), M.SmoothPlastic, Enum.PartType.Cylinder))
	disc.CastShadow = false
	local face = ghost(b:box('BadgeText', V(-2.1, 0.22, -2.1), V(2.1, 0.24, 2.1), P.white))
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
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.3, 0))
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
	local D = Lobby.Deck
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	-- Bags: north row faces south (turned round), south row faces north, both into the aisle.
	for i, id in Lobby.Bags do
		local north = i <= 4
		local x = Lobby.RowX[north and i or 9 - i]
		local cf = CFrame.new(x, D, Lobby.RowZ[north and 1 or 2]) * (north and CFrame.Angles(0, math.pi, 0) or CFrame.new())
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Bag_' .. id, cf, { X = 14, Y = 12, Z0 = -6, Z1 = 6 }, string.upper(s and s.Name or id), C(90, 200, 120),
			Stations and function(c) Stations.build(c, id, {}) end)
	end
	-- Cardio corner: a rubber mat at the aisle's west end, three treadmills facing the west wall.
	local K = Lobby.Colors
	local mat = L:group('CardioCorner')
	mat:box('CardioMat', V(-65.5 + 0.8, D, 45), V(-47.5, D + 0.1, 75), K.rubber, M.Fabric)
	decor(mat:box('CardioEdge', V(-47.8, D, 45), V(-47.4, D + 0.16, 75), K.lime, M.Neon)).CastShadow = false
	for _, z in { 45, 75 } do decor(mat:box('CardioEdge', V(-64.7, D, z - 0.2), V(-47.4, D + 0.16, z + 0.2), K.lime, M.Neon)).CastShadow = false end
	for i, id in Lobby.Treadmills do
		local cf = CFrame.new(-56.5, D + 0.1, Lobby.TreadZ[i]) * CFrame.Angles(0, -math.pi / 2, 0)
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

---------------------------------------------------------------------------------------------- props
-- Pallet rack along cf's +X: blue uprights, orange beams, three decks of mixed stock. Front faces -Z.
function Lobby.rack(c, cf, bays, seed)
	local K = Lobby.Colors
	local r = c:at(cf):group('PalletRack')
	local bw, dep, levels = 7.5, 4.2, { 0.3, 4.8, 9.3 }
	local len = bays * bw
	local rnd = Random.new(seed)
	for k = 0, bays do
		for _, z in { 0, dep - 0.4 } do r:box('RackPost', V(k * bw - 0.2, 0, z), V(k * bw + 0.2, 13.6, z + 0.4), K.rackPost, M.Metal) end
	end
	for _, y in levels do
		if y > 1 then
			for _, z in { -0.1, dep - 0.3 } do r:box('RackBeam', V(0, y - 0.5, z), V(len, y, z + 0.4), K.rackBeam, M.Metal) end
			r:box('RackDeck', V(0, y - 0.1, 0.2), V(len, y, dep - 0.2), C(90, 94, 104), M.DiamondPlate)
		end
		for k = 0, bays - 1 do
			local x0 = k * bw + 0.6
			local kind = rnd:NextInteger(1, 4)
			if kind == 1 then -- boxes on a pallet
				r:box('RackPallet', V(x0, y, 0.5), V(x0 + 6.2, y + 0.5, dep - 0.5), P.woodDark, M.Wood)
				r:box('RackBoxes', V(x0 + 0.3, y + 0.5, 0.7), V(x0 + 3.2, y + 3.2, dep - 0.7), P.crate, M.Cardboard)
				r:box('RackBoxes', V(x0 + 3.3, y + 0.5, 0.9), V(x0 + 5.9, y + 2.4, dep - 0.6), P.crate:Lerp(P.white, 0.15), M.Cardboard)
			elseif kind == 2 then -- drums
				for j = 0, 2 do r:post('RackDrum', 0.95, 2.9, V(x0 + 1.1 + j * 2.05, y, dep / 2), ({ C(40, 110, 200), C(206, 50, 44), C(60, 150, 80) })[rnd:NextInteger(1, 3)], M.Metal) end
			elseif kind == 3 then -- tyres
				for j = 0, 1 do
					for t = 0, rnd:NextInteger(1, 3) do r:part('RackTyre', V(0.7, 2.6, 2.6), CFrame.new(x0 + 1.6 + j * 3.1, y + 0.35 + t * 0.7, dep / 2) * CFrame.Angles(0, 0, math.pi / 2), C(30, 30, 34), M.SmoothPlastic, Enum.PartType.Cylinder) end
				end
			else -- sacks and a crate
				r:box('RackSacks', V(x0 + 0.2, y, 0.6), V(x0 + 3.4, y + 1.6, dep - 0.6), C(214, 200, 160), M.Fabric)
				r:box('RackCrate', V(x0 + 3.6, y, 0.5), V(x0 + 6.2, y + 2.8, dep - 0.5), C(70, 120, 70), M.WoodPlanks)
			end
		end
	end
	return r
end
-- A stack of tyres.
function Lobby.tyres(c, pos, n)
	local t = c:group('Tyres')
	for k = 0, n - 1 do
		t:part('Tyre', V(0.8, 3, 3), CFrame.new(pos + V(k % 2 * 0.25, 0.4 + k * 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(30, 30, 34), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	return t
end
-- Oil drum with two bands.
function Lobby.drum(c, pos, color)
	local t = c:group('Drum')
	t:post('Drum', 1.1, 3.2, pos, color, M.Metal)
	for _, y in { 0.9, 2.2 } do decor(t:post('DrumBand', 1.16, 0.18, pos + V(0, y, 0), color:Lerp(P.black, 0.35), M.Metal)) end
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
-- Hanging lamp: a chain from the truss, a green enamel shade, a warm bulb. Named Roof* for the plan views.
function Lobby.lamp(c, pos, color)
	local K = Lobby.Colors
	local l = c:group('RoofLamp')
	l:box('RoofLampChain', pos + V(-0.08, 1.3, -0.08), V(pos.X + 0.08, Lobby.Eave - 0.6, pos.Z + 0.08), K.truss, M.Metal)
	l:post('RoofLampCap', 0.45, 0.6, pos + V(0, 1.0, 0), K.truss, M.Metal)
	l:post('RoofLampShade', 1.5, 0.5, pos + V(0, 0.5, 0), C(40, 96, 70), M.Metal)
	l:post('RoofLampSkirt', 2.0, 0.35, pos + V(0, 0.15, 0), C(40, 96, 70), M.Metal)
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
	f:box('RoofFanRod', V(x - 0.15, y + 0.5, z - 0.15), V(x + 0.15, Lobby.Eave - 0.6, z + 0.15), K.truss, M.Metal)
	f:post('RoofFanHub', 1.0, 1.0, V(x, y - 0.2, z), C(230, 230, 236), M.Metal)
	for k = 0, 4 do
		f:part('RoofFanBlade', V(1.4, 0.15, 7), CFrame.new(x, y + 0.2, z) * CFrame.Angles(0, k * 2 * math.pi / 5, 0) * CFrame.new(0, 0, -4.3) * CFrame.Angles(0, 0, 0.12), C(236, 186, 40), M.SmoothPlastic)
	end
	return Lobby.motion(model, CFrame.new(x, y, z), rate)
end
-- Wall exhaust fan (blades spin round the wall's normal: the pivot's Y axis is turned to point along it).
function Lobby.wallFan(c, pos, normal, rate)
	local K = Lobby.Colors
	local cf = CFrame.lookAt(pos, pos + normal)
	local h = c:group('WallFan')
	h:part('FanHousing', V(6, 6, 0.8), cf * CFrame.new(0, 0, 0.1), K.truss, M.Metal)
	decor(h:part('FanDark', V(5.2, 5.2, 0.1), cf * CFrame.new(0, 0, -0.32), C(20, 22, 28), M.SmoothPlastic))
	for _, e in { { 0, 2.55, 5.4, 0.3 }, { 0, -2.55, 5.4, 0.3 }, { 2.55, 0, 0.3, 5.4 }, { -2.55, 0, 0.3, 5.4 } } do
		h:part('FanGuard', V(e[3], e[4], 0.2), cf * CFrame.new(e[1], e[2], -0.5), C(150, 154, 162), M.Metal)
	end
	local b, model = h:group('FanBlades')
	local hub = cf * CFrame.new(0, 0, -0.42)
	b:part('FanHub', V(0.9, 0.9, 0.3), hub, C(200, 200, 206), M.Metal)
	for k = 0, 3 do b:part('FanBlade', V(0.9, 2.3, 0.08), hub * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0.35, 0), C(200, 200, 206), M.Metal) end
	-- Spin axis = the wall normal: the pivot's Y axis must point along it.
	return Lobby.motion(model, hub * CFrame.Angles(-math.pi / 2, 0, 0), rate)
end
-- Forklift (front, the forks, toward cf's -Z) carrying a pallet of crates.
function Lobby.forklift(c, cf)
	local f = c:at(cf):group('Forklift')
	local yellow, dark = C(250, 190, 30), C(36, 38, 44)
	for _, x in { -2.1, 2.1 } do
		f:part('Wheel', V(1.0, 2.4, 2.4), CFrame.new(x, 1.2, -1.6), dark, M.SmoothPlastic, Enum.PartType.Cylinder)
		f:part('Wheel', V(1.0, 1.9, 1.9), CFrame.new(x, 0.95, 2.6), dark, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	f:box('Chassis', V(-2, 0.6, -2.8), V(2, 2.6, 3.6), yellow, M.SmoothPlastic)
	f:box('Counterweight', V(-2.1, 0.5, 2.6), V(2.1, 4.2, 4.2), dark, M.Metal)
	f:box('Seat', V(-1.1, 2.6, 0.6), V(1.1, 3.4, 2.2), dark, M.SmoothPlastic)
	f:box('SeatBack', V(-1.1, 3.4, 1.9), V(1.1, 5, 2.3), dark, M.SmoothPlastic)
	for _, x in { -1.9, 1.9 } do
		for _, z in { -2.4, 2.4 } do f:box('CagePost', V(x - 0.15, 2.6, z - 0.15), V(x + 0.15, 7.6, z + 0.15), dark, M.Metal) end
		f:box('Mast', V(x * 0.8 - 0.3, 0.4, -3.4), V(x * 0.8 + 0.3, 8.8, -2.9), C(60, 62, 70), M.Metal)
		f:box('Fork', V(x * 0.5 - 0.3, 0.9, -7.6), V(x * 0.5 + 0.3, 1.1, -3.0), C(60, 62, 70), M.Metal)
	end
	f:box('CageRoof', V(-2.1, 7.6, -2.6), V(2.1, 7.9, 2.6), dark, M.Metal)
	f:box('Wheel', V(-0.6, 3.6, -1.6), V(0.6, 3.75, -0.6), dark, M.SmoothPlastic)
	local bc, beacon = f:group('Beacon')
	bc:box('BeaconBase', V(-0.35, 7.9, 0.55), V(0.35, 8.1, 1.25), C(40, 40, 46), M.Metal)
	decor(bc:box('BeaconLamp', V(-0.3, 8.1, 0.6), V(0.3, 8.6, 1.2), C(255, 140, 20), M.Neon))
	decor(bc:box('BeaconFlap', V(-0.05, 8.1, 0.5), V(0.05, 8.6, 1.3), C(255, 220, 120), M.Neon))
	Lobby.motion(beacon, cf * CFrame.new(0, 8.3, 0.9), 300)
	decor(f:box('Stripe', V(-2.02, 1.4, -2.6), V(2.02, 1.8, 3.4), P.black, M.SmoothPlastic))
	pallet(f, CFrame.new(0, 1.1, -5.3))
	crate(f, CFrame.new(-0.6, 1.9, -5.3) * CFrame.Angles(0, 0.08, 0), 2.6)
	crate(f, CFrame.new(1.1, 1.9, -5.0) * CFrame.Angles(0, -0.12, 0), 1.9)
	return f
end

---------------------------------------------------------------------------------------------- set pieces
-- Reward crates by the door: a red DAILY crate (north-west), the lucky gold glove and the VIP safe (north-
-- east). Decor with "coming soon" prompts.
function Lobby.prompt(part, action, object)
	local p = Instance.new('ProximityPrompt')
	p.Name = 'ComingSoon'
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute('ComingSoon', true)
	p.Parent = part
	return p
end
function Lobby.rewardBase(r, w, d, color)
	Lobby.slab(r, 'RewardBase', V(-w / 2, 0, -d / 2), V(w / 2, 0.8, d / 2), color:Lerp(P.black, 0.25))
	Lobby.slab(r, 'RewardTop', V(-w / 2 + 0.6, 0, -d / 2 + 0.6), V(w / 2 - 0.6, 1.2, d / 2 - 0.6), color)
	for _, e in { { -w / 2, w / 2, -d / 2 - 0.1, -d / 2 + 0.1 }, { -w / 2, w / 2, d / 2 - 0.1, d / 2 + 0.1 }, { -w / 2 - 0.1, -w / 2 + 0.1, -d / 2, d / 2 }, { w / 2 - 0.1, w / 2 + 0.1, -d / 2, d / 2 } } do
		decor(r:box('RewardGlow', V(e[1], 0.2, e[3]), V(e[2], 0.5, e[4]), color:Lerp(P.white, 0.4), M.Neon)).CastShadow = false
	end
end
function Lobby.rewards(L)
	-- DAILY CRATE: a studded red crate with gold corners and a padlock.
	local r = L:at(CFrame.new(-27, 0, 19) * CFrame.Angles(0, math.rad(14), 0)):group('DailyCrate')
	Lobby.rewardBase(r, 11, 9, C(250, 196, 40))
	local red, gold = C(214, 40, 40), C(255, 204, 48)
	local body = studs(r:box('CrateBody', V(-4, 1.2, -3), V(4, 5.6, 3), red, M.Plastic), true)
	studs(r:box('CrateLid', V(-4.2, 5.6, -3.2), V(4.2, 7.2, 3.2), red:Lerp(P.black, 0.12), M.Plastic))
	for _, x in { -4.1, 3.5 } do for _, z in { -3.1, 2.5 } do r:box('CrateCorner', V(x, 1.2, z), V(x + 0.6, 7.3, z + 0.6), gold, M.SmoothPlastic) end end
	r:box('CrateBand', V(-4.15, 5.3, -3.15), V(4.15, 5.8, 3.15), gold, M.SmoothPlastic)
	r:box('CrateLock', V(-0.7, 4.0, -3.5), V(0.7, 5.6, -3.0), gold, M.Metal)
	Lobby.prompt(body, 'Open', 'Daily Crate')
	billboard(r, V(0, 10, 0), 7, 2.2, { { 'Title', 'DAILY CRATE', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 80
	Lobby.fx(Lobby.emitBox(r, 'CrateFx', V(-4, 2, -3), V(4, 7.5, 3)), 'CrateGlints', 'sparkle', { Rate = 5, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 120)), LightEmission = 1 })
	-- LUCKY GLOVE: a gold boxing glove turning over a black-and-gold stand.
	local g = L:at(CFrame.new(16, 0, 15)):group('LuckyGlove')
	Lobby.rewardBase(g, 6, 6, C(250, 196, 40))
	g:post('StandBase', 2.1, 1.2, V(0, 1.2, 0), C(36, 36, 42), M.Metal)
	g:post('StandBand', 1.8, 0.5, V(0, 2.4, 0), C(255, 204, 48), M.Metal)
	g:post('StandNeck', 1.4, 2.0, V(0, 2.9, 0), C(36, 36, 42), M.Metal)
	g:post('StandBand', 1.9, 0.4, V(0, 4.9, 0), C(255, 204, 48), M.Metal)
	local gl, glove = g:group('Glove')
	local gold2 = C(255, 196, 40)
	gl:box('GloveFist', V(-1.5, 6.4, -1.6), V(1.5, 9.6, 1.4), gold2, M.Metal)
	gl:box('GloveKnuckle', V(-1.4, 7.0, -2.2), V(1.4, 9.4, -1.6), gold2:Lerp(P.white, 0.2), M.Metal)
	gl:box('GloveThumb', V(1.5, 6.8, -1.4), V(2.2, 8.6, 0.6), gold2:Lerp(P.black, 0.08), M.Metal)
	gl:box('GloveCuff', V(-1.3, 5.3, -1.2), V(1.3, 6.4, 1.2), P.white, M.SmoothPlastic)
	gl:box('GloveLace', V(-0.2, 6.6, 1.4), V(0.2, 9.2, 1.5), P.white, M.SmoothPlastic)
	Lobby.motion(glove, CFrame.new(16, 7.5, 15), 50, 0.35)
	Lobby.prompt(ghost(g:box('GloveHit', V(-2, 1.2, -2), V(2, 5, 2), P.white)), 'Spin', 'Lucky Glove')
	billboard(g, V(0, 12, 0), 6, 2, { { 'Title', 'LUCKY GLOVE', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 80
	local glow = Lobby.emitBox(g, 'GloveFx', V(-2, 6, -2), V(2, 10, 2))
	Lobby.fx(glow, 'GloveGlitter', 'glitter', { Rate = 8, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.5, 2),
		Size = Lobby.seq({ { 0, 0.4 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 220, 90)), LightEmission = 1 })
	light(glow, C(255, 210, 90), 1, 12)
	-- VIP SAFE: a purple safe with a gold dial and handle.
	local v = L:at(CFrame.new(29, 0, 19) * CFrame.Angles(0, math.rad(-10), 0)):group('VipSafe')
	Lobby.rewardBase(v, 9, 8, C(190, 90, 255))
	local purple = C(128, 52, 196)
	local safe = studs(v:box('SafeBody', V(-3.4, 1.2, -2.6), V(3.4, 8.4, 2.6), purple, M.Plastic))
	v:box('SafeDoor', V(-2.8, 1.8, -2.9), V(2.8, 7.8, -2.6), purple:Lerp(P.black, 0.2), M.SmoothPlastic)
	v:part('SafeDial', V(0.4, 2.2, 2.2), CFrame.new(-0.8, 5.4, -3.0) * CFrame.Angles(0, math.pi / 2, 0), C(255, 204, 48), M.Metal, Enum.PartType.Cylinder)
	v:box('SafeHandle', V(1.2, 4.0, -3.4), V(1.6, 6.8, -2.9), C(255, 204, 48), M.Metal)
	v:box('SafeTrim', V(-3.5, 8.4, -2.7), V(3.5, 8.9, 2.7), C(255, 204, 48), M.SmoothPlastic)
	Lobby.prompt(safe, 'Open', 'VIP Safe')
	billboard(v, V(0, 11.5, 0), 6, 2, { { 'Title', 'VIP SAFE', C(225, 160, 255), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 80
end

-- The WORLD 2 garage: a studded concrete frame, a roll-up door chained shut with light spilling under it.
function Lobby.portal(L, cf)
	local p = L:at(cf):group('World2Portal')
	local concrete, blue = C(70, 92, 150), C(60, 200, 255)
	for _, sx in { -1, 1 } do
		studs(p:box('PortalPillar', V(sx * 8 - 2, 0, -1.6), V(sx * 8 + 2, 17, 1.6), concrete, M.Plastic), true)
		studs(p:box('PortalFoot', V(sx * 8 - 2.6, 0, -2.2), V(sx * 8 + 2.6, 1.4, 2.2), concrete:Lerp(P.black, 0.25), M.Plastic), true)
		for k = 0, 3 do p:box('PortalChevron', V(sx * 8 - 2.05, 2 + k * 3.4, -1.7), V(sx * 8 + 2.05, 3.6 + k * 3.4, -1.6), k % 2 == 0 and Lobby.Colors.hazard or P.black, M.SmoothPlastic) end
	end
	studs(p:box('PortalHeader', V(-10.6, 17, -1.8), V(10.6, 20.4, 1.8), concrete:Lerp(P.black, 0.1), M.Plastic), true)
	for _, x in { -9.8, -6, 6, 9.8 } do studs(p:box('PortalMerlon', V(x - 1, 20.4, -1.6), V(x + 1, 21.6, 1.6), concrete, M.Plastic)) end
	-- Door: slats, raised a little; cyan glow from the gap underneath.
	p:box('PortalDoor', V(-6, 3, -0.6), V(6, 17, 0.2), C(126, 140, 162), M.Metal)
	for y = 3.6, 16.4, 1.2 do decor(p:box('PortalSlat', V(-6, y, -0.75), V(6, y + 0.2, -0.6), C(92, 104, 124), M.Metal)) end
	for k = 0, 5 do p:box('PortalDoorLip', V(-6 + k * 2, 2.6, -0.85), V(-4 + k * 2, 3.4, 0.3), k % 2 == 0 and Lobby.Colors.hazard or P.black, M.SmoothPlastic) end
	for _, sx in { -1, 1 } do studs(p:box('PortalCorner', V(sx * 6 - 1.6, 14.6, -1.9), V(sx * 6 + 1.6, 17, 1.9), concrete:Lerp(P.white, 0.12), M.Plastic), true) end
	local tag = ghost(p:box('PortalTag', V(-5.6, 5, -0.9), V(5.6, 9, -0.8), P.white))
	line(surface(tag, Enum.NormalId.Front, 14), 'Tag', 'KEEP OUT', C(255, 70, 70), FONT.tag, 0.05, 0.9, P.black, 2)
	local gap = decor(p:box('PortalGlow', V(-6, 0, -0.4), V(6, 2.6, 0.2), blue, M.Neon))
	gap.CastShadow = false
	light(gap, blue, 3, 24)
	-- Chains across the door and the padlock.
	for _, s in { -1, 1 } do
		decor(p:part('PortalChain', V(0.35, 0.35, 15.2), CFrame.new(0, 10, -1.0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(s * math.rad(36), 0, 0), C(160, 164, 172), M.Metal))
	end
	p:box('PortalLock', V(-1.1, 8.7, -1.6), V(1.1, 11.0, -1.0), C(255, 204, 48), M.Metal)
	-- The sign over it and a glowing dashed pad in front.
	local sign = Lobby.neonSign(p, CFrame.new(0, 18.7, -1.95), 13, 2.8, 'WORLD 2', blue)
	sign.Name = 'World2Sign'
	for k = -3, 3 do
		decor(p:box('PortalPad', V(k * 2.2 - 0.7, 0, -9.4), V(k * 2.2 + 0.7, 0.12, -9), blue, M.Neon)).CastShadow = false
	end
	for k = 0, 3 do
		for _, sx in { -1, 1 } do decor(p:box('PortalPad', V(sx * 7.4 - 0.2, 0, -8.2 + k * 2), V(sx * 7.4 + 0.2, 0.12, -7.2 + k * 2), blue, M.Neon)).CastShadow = false end
	end
	local zone = p:box('World2Gate', V(-6, 0, -3), V(6, 0.2, -1), blue, M.SmoothPlastic)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	billboard(p, V(0, 25, 0), 9, 2.4, { { 'Title', 'WORLD 2', C(140, 230, 255), FONT.loud, 0, 0.6 }, { 'Detail', 'LOCKED  •  COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 120
	-- Mist creeping out under the door.
	local fxBox = Lobby.emitBox(p, 'PortalFx', V(-6, 0.2, -2), V(6, 1.2, -0.6))
	Lobby.fx(fxBox, 'PortalMist', 'mist', { Rate = 10, Lifetime = NumberRange.new(1.8, 3), Speed = NumberRange.new(1, 2.5),
		Size = Lobby.seq({ { 0, 1.4 }, { 1, 3.6 } }), Transparency = Lobby.seq({ { 0, 0.55 }, { 1, 1 } }), Color = ColorSequence.new(C(110, 220, 255)),
		LightEmission = 0.8, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 10), Drag = 1 })
	-- Hazard barrier, cones and blue-glowing crates beside it.
	for k, x in { -12.5, 12.2, 13.6 } do
		p:post('Cone', 0.9, 0.3, V(x, 0, -3 + k), P.black, M.SmoothPlastic)
		p:part('Cone', V(2.2, 1.2, 1.2), CFrame.new(x, 1.4, -3 + k) * CFrame.Angles(0, 0, math.pi / 2), C(255, 120, 30), M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(p:part('ConeBand', V(0.4, 1.3, 1.3), CFrame.new(x, 1.5, -3 + k) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	for k = 0, 2 do
		p:box('GlowCrate', V(-15.5 + k * 0.4, k * 2.2, 1 - k * 0.5), V(-12.9 + k * 0.4, 2.2 + k * 2.2, 3.6 - k * 0.5), C(40, 70, 120), M.SmoothPlastic)
		decor(p:box('GlowCrateBand', V(-15.6 + k * 0.4, 0.9 + k * 2.2, 0.9 - k * 0.5), V(-12.8 + k * 0.4, 1.3 + k * 2.2, 3.7 - k * 0.5), blue, M.Neon)).CastShadow = false
	end
	return p
end

-- The champ: a giant gold boxer in a double-biceps flex, red gloves, title belt, on a studded plinth with a
-- cyan uplight.
function Lobby.statue(L, cf)
	local s = L:at(cf):group('ChampStatue')
	local gold, shade, red = C(236, 182, 60), C(198, 140, 40), C(214, 40, 40)
	Lobby.slab(s, 'Plinth', V(-6, 0, -6), V(6, 1.2, 6), C(52, 58, 76))
	Lobby.slab(s, 'Plinth', V(-5, 0, -5), V(5, 3.4, 5), C(84, 92, 116))
	local plaque = s:box('Plaque', V(-3.4, 1.2, -5.15), V(3.4, 3.0, -5), C(30, 34, 46), M.SmoothPlastic)
	line(surface(plaque, Enum.NormalId.Front, 30), 'Text', 'THE CHAMP', C(255, 214, 80), FONT.loud, 0.1, 0.8, P.black, 2)
	for _, e in { { -5.1, 5.1, -5.2, -5.05 }, { -5.1, 5.1, 5.05, 5.2 }, { -5.2, -5.05, -5.1, 5.1 }, { 5.05, 5.2, -5.1, 5.1 } } do
		decor(s:box('PlinthGlow', V(e[1], 3.1, e[3]), V(e[2], 3.4, e[4]), Lobby.Colors.cool, M.Neon)).CastShadow = false
	end
	local y = 3.4
	local function b(name, x0, y0, z0, x1, y1, z1, color, mat) return s:box(name, V(x0, y + y0, z0), V(x1, y + y1, z1), color or gold, mat or M.Metal) end
	for _, sx in { -1, 1 } do
		local function bx(name, a, y0, z0, c, y1, z1, color, mat) return b(name, math.min(sx * a, sx * c), y0, z0, math.max(sx * a, sx * c), y1, z1, color, mat) end
		bx('Boot', 0.4, 0, -1.6, 2.9, 1.8, 1.6, shade)
		bx('Leg', 0.5, 1.8, -1.0, 2.7, 7.6, 1.2)
		bx('Delt', 3.8, 14.2, -1.3, 6.2, 16.8, 1.3, shade)
		bx('UpperArm', 5.6, 14.4, -1.0, 9.4, 16.4, 1.0)
		bx('ForeArm', 7.6, 16.4, -0.9, 9.4, 20.2, 0.9)
		bx('Glove', 7.0, 19.8, -1.5, 10.0, 23.2, 1.5, red, M.SmoothPlastic)
		bx('GloveCuff', 7.3, 19.4, -1.2, 9.7, 20.0, 1.2, P.white, M.SmoothPlastic)
		bx('BeltSide', 1.6, 8.6, -2.05, 3.5, 10.2, 2.05, red, M.SmoothPlastic)
		bx('Ear', 1.6, 17.8, -0.4, 1.9, 18.8, 0.4, shade)
	end
	b('Trunks', -3.2, 6.6, -1.6, 3.2, 9.6, 1.8, shade)
	b('Belt', -1.6, 8.6, -2.0, 1.6, 10.2, 2.0, C(255, 220, 90))
	b('BeltPlate', -1.5, 8.2, -2.4, 1.5, 10.6, -2.0, C(255, 240, 170))
	b('Waist', -2.8, 10.2, -1.4, 2.8, 12.4, 1.6)
	b('Chest', -4.2, 12.2, -1.8, 4.2, 15.8, 1.8)
	b('PecLine', -0.15, 12.8, -1.9, 0.15, 15.4, -1.8, shade)
	b('Neck', -1.1, 15.8, -0.9, 1.1, 16.6, 0.9)
	b('Head', -1.6, 16.6, -1.6, 1.6, 20, 1.6)
	b('Jaw', -1.2, 16.4, -1.8, 1.2, 17.6, -1.4)
	b('Brow', -1.4, 18.8, -1.75, 1.4, 19.3, -1.6, shade)
	b('Nose', -0.3, 17.8, -1.9, 0.3, 18.7, -1.6, shade)
	b('Hair', -1.7, 19.6, -1.7, 1.7, 20.4, 1.7, shade)
	-- Cyan uplight and glints.
	local lamp = Lobby.emitBox(s, 'StatueFx', V(-6, y + 4, -3), V(6, y + 24, 3))
	light(lamp, Lobby.Colors.cool, 1.6, 24)
	Lobby.fx(lamp, 'StatueGlints', 'sparkle', { Rate = 5, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 0.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 1.0 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 240, 200)), LightEmission = 1 })
	return s
end

-- Leaderboard: two studded posts, a frame and a screen with a header; `live` makes it the ServerLeaderboard
-- LobbyService writes into (a TextLabel named TextLabel).
function Lobby.leaderboard(L, cf, title, accent, live)
	local b, model = L:at(cf):group(live and 'ServerLeaderboard' or 'Leaderboard')
	local frame = C(54, 66, 98)
	for _, sx in { -1, 1 } do
		studs(b:box('BoardPost', V(sx * 6.4 - 0.8, 0, -0.8), V(sx * 6.4 + 0.8, 15.6, 0.8), frame, M.Plastic), true)
		studs(b:box('BoardFoot', V(sx * 6.4 - 1.3, 0, -1.6), V(sx * 6.4 + 1.3, 0.8, 1.6), frame:Lerp(P.black, 0.3), M.Plastic))
	end
	studs(b:box('BoardFrame', V(-5.8, 3, -0.5), V(5.8, 15, 0.5), frame:Lerp(P.black, 0.15), M.Plastic))
	studs(b:box('BoardCap', V(-7.4, 15.6, -0.9), V(7.4, 16.4, 0.9), frame, M.Plastic))
	local header = b:box('BoardHeader', V(-5.4, 12.6, -0.62), V(5.4, 14.6, -0.5), accent, M.SmoothPlastic)
	line(surface(header, Enum.NormalId.Front, 20), 'Title', title, P.white, FONT.loud, 0.08, 0.84, accent:Lerp(P.black, 0.6), 3)
	local screen = b:box('BoardScreen', V(-5.4, 3.4, -0.62), V(5.4, 12.4, -0.5), C(18, 26, 52), M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	local text = live and 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!' or '1. ---\n2. ---\n3. ---\n4. ---\n5. ---'
	local t = line(g, live and 'TextLabel' or 'Rows', text, P.white, FONT.body, 0.05, 0.9, P.black, 1)
	t.TextYAlignment = Enum.TextYAlignment.Top
	if not live then t.TextXAlignment = Enum.TextXAlignment.Left end
	decor(b:box('BoardGlow', V(-5.6, 3.2, -0.66), V(5.6, 3.4, -0.5), accent, M.Neon)).CastShadow = false
	return model
end

-- A string of pennants from a to b sagging by `sag` in the middle (each pennant a thin wedge, tip down).
function Lobby.bunting(c, a, b, sag, colors)
	local g = c:group('RoofBunting')
	local n = math.floor((b - a).Magnitude / 2.4)
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
-- The training aisle: a red runner from the crossing to the cardio corner, gym kit along its edges.
function Lobby.aisle(L)
	local K, D = Lobby.Colors, Lobby.Deck
	local a = L:group('TrainingAisle')
	local z0, z1 = Lobby.CrossZ - 5, Lobby.CrossZ + 5
	a:box('Runner', V(-47.4, D, z0), V(-6, D + 0.06, z1), C(176, 34, 42), M.Fabric)
	for _, z in { z0 + 0.5, z1 - 0.9 } do decor(a:box('RunnerLine', V(-47.4, D, z), V(-6, D + 0.08, z + 0.4), P.white, M.SmoothPlastic)) end
	local word = ghost(a:box('RunnerWord', V(-40, D + 0.1, z0 + 1), V(-14, D + 0.12, z1 - 1), P.white))
	line(surface(word, Enum.NormalId.Top, 10), 'Text', 'TRAIN  •  +1  •  TRAIN', C(255, 220, 220), FONT.loud, 0.1, 0.8)
	-- Kettlebells, medicine balls, a dumbbell rack, water bottles: small things in clusters off the runner.
	local function kettlebell(x, z, color)
		a:blob('Kettlebell', V(1.1, 1.0, 1.1), V(x, D + 0.5, z), color, M.SmoothPlastic)
		a:box('KettlebellGrip', V(x - 0.35, D + 0.95, z - 0.08), V(x + 0.35, D + 1.3, z + 0.08), color, M.Metal)
	end
	kettlebell(-31, z0 - 2.2, C(36, 36, 42)); kettlebell(-29.6, z0 - 2.6, C(214, 40, 40)); kettlebell(-30.2, z0 - 1.2, C(40, 110, 220))
	for k, col in { C(214, 40, 40), C(40, 42, 50), C(255, 190, 40) } do a:blob('MedBall', V(1.6, 1.6, 1.6), V(-21 + k * 1.7, D + 0.8, z1 + 2.4 + (k % 2) * 0.6), col, M.SmoothPlastic) end
	local rack = a:group('DumbbellRack')
	rack:box('RackFrame', V(-43, D, z1 + 1.6), V(-37, D + 2.2, z1 + 3.2), K.truss, M.Metal)
	for k = 0, 4 do
		local x = -42.4 + k * 1.2
		rack:part('Dumbbell', V(1.2, 0.5, 0.5), CFrame.new(x, D + 2.45, z1 + 2.4) * CFrame.Angles(0, math.pi / 2, 0), C(30, 30, 34), M.Metal, Enum.PartType.Cylinder)
	end
	for k = 0, 2 do a:post('Bottle', 0.22, 0.9, V(-12.4 + k * 0.6, D, z0 - 2 - (k % 2) * 0.4), C(80, 180, 255), M.Glass) end
	decor(a:box('Towel', V(-13.6, D, z0 - 3.6), V(-11.8, D + 0.12, z0 - 2.6), P.white, M.Fabric))
	return a
end

---------------------------------------------------------------------------------------------- dressing
-- Signs, posters, racks, containers, clutter, lamps, fans, particles: the life.
function Lobby.dressing(L)
	local K, W, N, S, D = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.Deck
	local dr = L:group('Dressing')
	local inN, inS, inW, inE = V(0, 0, 1), V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0)
	-- Neon signs: the club name over the door (inside and out), the areas on their walls.
	Lobby.neonSign(dr, Lobby.onWall(V(0, 26, N + 0.5), inN), 30, 6.4, 'HOOD BOXING CLUB', K.pink, 'EST. 1987  •  EVERY PUNCH +1')
	Lobby.neonSign(dr, Lobby.onWall(V(0, 31.6, N - 1.5), -inN), 30, 5.4, 'HOOD BOXING CLUB', K.pink)
	Lobby.poster(dr, Lobby.onWall(V(-24, 12, N - 1.45), -inN), 7, 9, C(250, 204, 48), { { 'TRAIN', P.black, FONT.loud, 0.06, 0.24, P.white }, { 'HERE', C(214, 40, 40), FONT.loud, 0.3, 0.24, P.white }, { 'x2 POWER\nFREE BAGS', P.black, FONT.title, 0.6, 0.3 } })
	Lobby.poster(dr, Lobby.onWall(V(24, 12, N - 1.45), -inN), 7, 9, C(214, 40, 40), { { 'FIGHT', P.white, FONT.loud, 0.06, 0.24 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.3, 0.24 }, { 'EVERY\nSATURDAY', P.white, FONT.title, 0.6, 0.3 } })
	Lobby.neonSign(dr, Lobby.onWall(V(0, 21.3, N + 2.6), inN), 12, 1.8, 'EXIT  •  STAGE 1', C(80, 255, 120))
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 17.5, 60), inW), 26, 5.2, 'TRAINING', K.warm, 'PUNCH THE BAGS  •  RUN THE BELTS')
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 12.2, 60), inW), 12, 2.6, 'CARDIO', K.lime)
	Lobby.neonSign(dr, Lobby.onWall(V(W - 1.5, 24, 60), inE), 30, 6, 'EVOLUTIONS', K.cool, 'NEW LOOK  •  MORE POWER')
	Lobby.neonSign(dr, Lobby.onWall(V(W - 1.5, 18, 112), inE), 22, 4.4, 'TOP OF THE BLOCK', C(255, 210, 60))
	-- Mirror wall behind the treadmills.
	local mirror = dr:box('Mirror', V(-W, 3, 47), V(-W + 0.35, 10, 73), C(200, 226, 240), M.Glass)
	mirror.Reflectance = 0.35
	dr:box('MirrorFrame', V(-W, 2.6, 46.6), V(-W + 0.3, 10.4, 73.4), K.truss, M.Metal)
	-- Posters: fight nights, rules, motivation; slightly crooked, taped.
	local posters = {
		{ V(-40, 11, N + 0.45), inN, 5, 7, C(214, 40, 40), { { 'FIGHT', P.white, FONT.loud, 0.04, 0.2 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.24, 0.2 }, { 'KID BLOCK\nvs\nTHE CHAMP', P.white, FONT.title, 0.48, 0.36 }, { 'SAT 9PM', C(255, 220, 60), FONT.body, 0.86, 0.1 } } },
		{ V(-47, 11, N + 0.45), inN, 4.4, 6, C(250, 204, 48), { { 'TRAIN\nHARD', P.black, FONT.loud, 0.08, 0.5, P.white }, { 'NO PAIN\nNO POWER', C(160, 30, 30), FONT.title, 0.62, 0.3, P.white } } },
		{ V(40, 11, N + 0.45), inN, 5, 7, C(40, 80, 200), { { 'WANTED', P.white, FONT.loud, 0.04, 0.2 }, { 'THE\nCHAMP', C(255, 220, 60), FONT.loud, 0.3, 0.4 }, { 'REWARD 💪 50K', P.white, FONT.body, 0.8, 0.12 } } },
		{ V(47.5, 10, N + 0.45), inN, 4, 5, P.white, { { 'NO\nSPITTING', C(200, 30, 30), FONT.loud, 0.1, 0.55 }, { 'wipe the bags!', P.black, FONT.tag, 0.7, 0.2 } } },
		{ V(-36, 11, S - 0.45), inS, 5, 6.5, C(130, 50, 200), { { 'WORLD 2', P.white, FONT.loud, 0.05, 0.22 }, { 'COMING\nSOON', C(140, 230, 255), FONT.loud, 0.35, 0.4 }, { '???', P.white, FONT.title, 0.8, 0.14 } } },
		{ V(W - 0.45, 11, 96), inE, 5, 6.5, C(250, 204, 48), { { '+1', C(200, 30, 30), FONT.loud, 0.05, 0.4, P.white }, { 'POWER\nEVERY\nPUNCH', P.black, FONT.loud, 0.46, 0.48 } } },
		{ V(-20, 11, S - 0.45), inS, 5, 7, C(30, 30, 36), { { 'GOLD', C(255, 204, 48), FONT.loud, 0.06, 0.2 }, { 'GLOVES', C(255, 204, 48), FONT.loud, 0.26, 0.2 }, { 'TOURNAMENT', P.white, FONT.title, 0.52, 0.14 }, { 'SIGN UP INSIDE', C(255, 90, 160), FONT.body, 0.76, 0.12 } } },
		{ V(20, 11, S - 0.45), inS, 4.6, 6, C(60, 180, 90), { { 'GUNS\nIN\nSTOCK', P.white, FONT.loud, 0.08, 0.66 }, { '→ ARMORY', C(255, 240, 120), FONT.title, 0.78, 0.16 } } },
	}
	for k, p in posters do
		local cf = Lobby.onWall(p[1], p[2]) * CFrame.Angles(0, 0, math.rad((k % 3 - 1) * 3))
		Lobby.poster(dr, cf, p[3], p[4], p[5], p[6])
	end
	-- Fight-night scoreboard on the north wall, west of the door.
	Lobby.board(dr, 'Scoreboard', Lobby.onWall(V(-23, 15, N + 0.6), inN), 12, 6, C(20, 22, 28), {
		{ 'Round', 'ROUND 3', C(255, 220, 60), FONT.loud, 0.04, 0.26, P.black },
		{ 'Score', 'HOOD 7  :  5 CHAMP', C(255, 70, 70), FONT.loud, 0.34, 0.34, P.black },
		{ 'Clock', '2:59', C(80, 255, 120), FONT.body, 0.72, 0.24, P.black },
	}, 18)
	Lobby.neonFrame(dr, Lobby.onWall(V(-23, 15, N + 0.6), inN), 12, 6, C(255, 220, 60), 0.25)

	-- Edges: racks and containers where the reference has its cliffs, clutter in clusters.
	local tags = { 'HOOD', 'TBC', 'ON THE BLOCK', 'CHAMP' }
	Lobby.container(dr, CFrame.new(-55, 0, N + 4.4) * CFrame.Angles(0, math.pi / 2, 0), P.containerRed, tags[1], C(255, 220, 60), 'Left')
	Lobby.container(dr, CFrame.new(-53.5, 8.6, N + 4.6) * CFrame.Angles(0, math.pi / 2 + 0.04, 0), P.containerBlue)
	Lobby.rack(dr, CFrame.new(-W + 4.4, 0, N + 9) * CFrame.Angles(0, -math.pi / 2, 0), 2, 11)
	Lobby.rack(dr, CFrame.new(56, 0, N + 4.4) * CFrame.Angles(0, math.pi, 0), 2, 12)
	Lobby.container(dr, CFrame.new(W - 4.2, 0, 20), C(60, 150, 90), tags[3], P.white, 'Left')
	Lobby.container(dr, CFrame.new(W - 4.4, 8.6, 19.2) * CFrame.Angles(0, -0.05, 0), C(240, 160, 40))
	Lobby.rack(dr, CFrame.new(-W + 4.4, 0, 94) * CFrame.Angles(0, -math.pi / 2, 0), 4, 13)
	Lobby.container(dr, CFrame.new(-W + 4.2, 0, 135), C(60, 150, 90), tags[2], C(255, 90, 160), 'Right')
	Lobby.container(dr, CFrame.new(-50, 0, S - 4.4) * CFrame.Angles(0, math.pi / 2, 0), P.containerBlue, nil)
	Lobby.container(dr, CFrame.new(-51, 8.6, S - 4.3) * CFrame.Angles(0, math.pi / 2 - 0.05, 0), P.containerRed)
	Lobby.rack(dr, CFrame.new(-15, 0, S - 4.4), 4, 14)
	Lobby.container(dr, CFrame.new(51, 0, S - 4.4) * CFrame.Angles(0, math.pi / 2, 0), C(240, 160, 40), tags[4], P.black, 'Right')
	Lobby.container(dr, CFrame.new(52.5, 8.6, S - 4.6) * CFrame.Angles(0, math.pi / 2 + 0.04, 0), C(60, 150, 90))
	Lobby.container(dr, CFrame.new(W - 4.2, 0, 132), P.containerBlue)
	Lobby.container(dr, CFrame.new(W - 4.0, 8.6, 133), P.containerRed)
	Lobby.cluster(dr, CFrame.new(-51, 0, 20) * CFrame.Angles(0, 0.4, 0), 21)
	Lobby.cluster(dr, CFrame.new(37, 0, 150) * CFrame.Angles(0, -0.7, 0), 22)
	Lobby.cluster(dr, CFrame.new(-52, 0, 112) * CFrame.Angles(0, 1.2, 0), 23)
	Lobby.cluster(dr, CFrame.new(-41, 0, 141) * CFrame.Angles(0, 0.2, 0), 24)
	Lobby.cluster(dr, CFrame.new(41, 0, 140) * CFrame.Angles(0, -0.3, 0), 25)
	Lobby.forklift(dr, CFrame.lookAt(V(47, 0, 24), V(49, 0, 0)))
	-- Its working bay in front of the racks, painted on the floor.
	for _, e in { { 39, 57, 11.6, 12 }, { 39, 39.4, 12, 30 }, { 56.6, 57, 12, 29 } } do
		decor(dr:box('BayPaint', V(e[1], 0, e[3]), V(e[2], 0.04, e[4]), K.hazard, M.SmoothPlastic))
	end
	-- Story props: vending machine and water cooler by the door, a bench with towels by the training deck,
	-- a coffee cup steaming on a crate, a broom against the wall.
	local vend = dr:group('Vending')
	vend:box('VendBody', V(14, 0, N + 0.5), V(18.5, 8.4, N + 4), C(200, 30, 40), M.SmoothPlastic)
	local glass = decor(vend:box('VendGlass', V(14.6, 2.4, N + 4), V(17, 7.6, N + 4.12), C(255, 240, 200), M.Neon))
	light(glass, C(255, 230, 190), 0.6, 10)
	vend:box('VendSlot', V(17.3, 3.5, N + 4), V(18.1, 6.2, N + 4.15), C(30, 30, 34), M.Metal)
	line(surface(vend:box('VendTop', V(14, 7.6, N + 4), V(18.5, 8.4, N + 4.15), C(255, 255, 255), M.SmoothPlastic), Enum.NormalId.Back, 30), 'Text', 'ENERGY', C(200, 30, 40), FONT.loud, 0.05, 0.9)
	local cooler = dr:group('WaterCooler')
	cooler:box('CoolerBody', V(-47, 0, 26.2), V(-45, 3.6, 28), C(230, 232, 236), M.SmoothPlastic)
	cooler:post('CoolerJug', 0.8, 2, V(-46, 3.6, 27.1), C(120, 190, 240), M.Glass).Transparency = 0.3
	bench(dr, V(-40, 0, 27), V(0, 0, -1))
	decor(dr:box('Towel', V(-41.6, 1.72, 26.6), V(-39.8, 1.9, 27.7), P.white, M.Fabric))
	decor(dr:box('GymBag', V(-37.6, 1.72, 26.5), V(-35.4, 3.1, 27.8), C(30, 30, 36), M.Fabric))
	crate(dr, CFrame.new(-60, 0, 113) * CFrame.Angles(0, 0.3, 0), 3)
	local cup = dr:post('CoffeeCup', 0.3, 0.7, V(-60.2, 3, 112.8), P.white, M.SmoothPlastic)
	Lobby.fx(cup, 'CoffeeSteam', 'smoke', { Rate = 3, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.6, 1.2),
		Size = Lobby.seq({ { 0, 0.3 }, { 1, 1.1 } }), Transparency = Lobby.seq({ { 0, 0.6 }, { 1, 1 } }), Color = ColorSequence.new(P.white), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8) })
	dr:part('BroomStick', V(0.25, 6, 0.25), CFrame.new(20, 3, 7.4) * CFrame.Angles(math.rad(-10), 0, 0), P.wood, M.Wood)
	dr:box('BroomHead', V(19.3, 0, 7.6), V(20.7, 0.7, 9), C(220, 180, 60), M.Fabric)
	-- Steam vent in the north-east corner.
	dr:post('VentPipe', 0.8, 9, V(W - 2, 0, N + 2), C(150, 154, 162), M.Metal)
	dr:post('VentCap', 1.1, 0.6, V(W - 2, 9, N + 2), K.truss, M.Metal)
	local steam = Lobby.emitBox(dr, 'VentFx', V(W - 2.6, 9.6, N + 1.4), V(W - 1.4, 10, N + 2.6))
	Lobby.fx(steam, 'VentSteam', 'smoke', { Rate = 8, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(2, 4),
		Size = Lobby.seq({ { 0, 1 }, { 1, 5 } }), Transparency = Lobby.seq({ { 0, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(235, 238, 245)), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Drag = 0.6 })

	-- The podium's back, facing the street door: a plywood hoarding with graffiti and posters.
	local hb = Lobby.onWall(V(36, D + 7.2, Lobby.CrossZ - 17), inS)
	Lobby.board(dr, 'Hoarding', hb, 50, 12, C(196, 150, 100), {
		{ 'Tag', 'EVOLVE', C(255, 80, 170), FONT.tag, 0.06, 0.62, P.black, 4 },
		{ 'Sub', 'new look = more power', P.white, FONT.tag, 0.7, 0.2, P.black, 3 },
	}, 10, M.WoodPlanks)
	for _, x in { 12.5, 59.5 } do dr:box('HoardingPost', V(x - 0.4, D, Lobby.CrossZ - 17.6), V(x + 0.4, D + 13.6, Lobby.CrossZ - 16.6), K.truss, M.Metal) end
	for k, e in { { 14.5, C(40, 110, 220), 'THE\nKINGPIN', 'top row' }, { 57.5, C(222, 44, 52), 'CORNER\nKID', 'free look' } } do
		Lobby.poster(dr, hb * CFrame.new(e[1] - 36, -0.6, -0.2) * CFrame.Angles(0, 0, math.rad(k == 1 and 4 or -3)), 5, 7, e[2], { { e[3], P.white, FONT.loud, 0.1, 0.5 }, { e[4], C(255, 230, 120), FONT.tag, 0.7, 0.2 } })
	end
	-- Floor life: oil stains, drains, taped X marks, seams across the walkway.
	for _, e in { { -20, 40.5, 2.6 }, { 40, 102, 3.4 }, { -54, 98, 2.2 }, { 22, 12, 1.8 }, { -14, 148, 2.8 } } do
		decor(dr:part('OilStain', V(0.06, e[3] * 2, e[3] * 1.4), CFrame.new(e[1], 0.02, e[2]) * CFrame.Angles(0, 0.6, math.pi / 2), C(64, 60, 58), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
	for _, e in { { -12, 26 }, { 12, 104 }, { -40, 114 } } do
		decor(dr:box('Drain', V(e[1] - 1, 0, e[2] - 1), V(e[1] + 1, 0.05, e[2] + 1), C(50, 52, 58), M.DiamondPlate)).CastShadow = false
	end
	for _, e in { { 30, 28 }, { -16, 94 } } do
		for _, a in { 45, -45 } do decor(dr:part('TapeX', V(0.5, 0.04, 3), CFrame.new(e[1], 0.02, e[2]) * CFrame.Angles(0, math.rad(a), 0), K.hazard, M.SmoothPlastic)).CastShadow = false end
	end
	for z = 15, 111, 8 do
		if math.abs(z - Lobby.CrossZ) > 7 and math.abs(z - (Lobby.CrossZ - 13)) > 3 then
			decor(dr:box('WalkSeam', V(-Lobby.Walk + 0.8, D - 0.02, z - 0.08), V(Lobby.Walk - 0.8, D + 0.03, z + 0.08), K.deck:Lerp(P.black, 0.18), M.SmoothPlastic)).CastShadow = false
		end
	end
	-- Bunting over the training aisle and the podium apron, cloth banners on the side walls.
	local flags = { C(222, 44, 52), C(255, 204, 48), C(40, 110, 220), P.white }
	for _, z in { 55, 65 } do Lobby.bunting(dr, V(-64, 25.5, z), V(-7, 25.5, z), 3.2, flags) end
	for _, z in { 81, 87 } do Lobby.bunting(dr, V(7, 25.5, z), V(64, 25.5, z), 3.2, { C(80, 220, 255), P.white, C(180, 100, 255), C(255, 204, 48) }) end
	for _, e in { { V(W - 0.5, 15, 81), inE, C(222, 44, 52), 'CHAMP' }, { V(-W + 0.5, 19, 103.5), inW, C(40, 110, 220), '+1' }, { V(-27, 20, S - 0.5), inS, C(222, 44, 52), 'HOOD' }, { V(27, 20, S - 0.5), inS, C(255, 204, 48), 'TBC' } } do
		local cf = Lobby.onWall(e[1], e[2])
		Lobby.board(dr, 'WallBanner', cf, 4, 10, e[3], { { 'Text', e[4], P.white, FONT.loud, 0.3, 0.4, e[3]:Lerp(P.black, 0.5) } }, 16, M.Fabric)
		decor(dr:part('BannerRod', V(5, 0.3, 0.3), cf * CFrame.new(0, 5.1, -0.2), K.truss, M.Metal))
	end
	-- Lamps: warm over the training deck and the walkway, cool over the podium.
	for _, x in { -14, -36, -58 } do
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
	Lobby.portal(L, CFrame.new(-36, 0, 104) * CFrame.Angles(0, math.rad(-62), 0))
	Lobby.Slots.World2Portal = CFrame.new(-36, 0, 104) * CFrame.Angles(0, math.rad(-62), 0)
	Lobby.statue(L, CFrame.lookAt(V(25, 0, 104), V(0, 0, 70)))
	Lobby.Slots.Statue = CFrame.lookAt(V(25, 0, 104), V(0, 0, 70))
	Lobby.Slots.Spawn = CFrame.new(SPAWN)
	Lobby.Slots.FurthestPad = CFrame.new(0, Lobby.Deck, Lobby.CrossZ - 13)
	Lobby.Slots.DailyCrate = CFrame.new(-27, 0, 19) * CFrame.Angles(0, math.rad(14), 0)
	Lobby.Slots.LuckyGlove = CFrame.new(16, 0, 15)
	Lobby.Slots.VipSafe = CFrame.new(29, 0, 19) * CFrame.Angles(0, math.rad(-10), 0)
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	local boards = L:group('Leaderboards')
	for k, e in { { V(46, 0, 97), V(14, 0, 108), 'TOP POWER', C(222, 52, 52), true }, { V(57, 0, 111), V(18, 0, 114), 'TOP REBIRTHS', C(132, 62, 212) }, { V(47, 0, 126), V(12, 0, 120), 'TOP CASH', C(44, 170, 80) } } do
		local cf = CFrame.lookAt(e[1], e[2])
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[3], e[4], e[5])
	end
	Lobby.dressing(L)
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
	barrier.Transparency = 0.45
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
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 warehouse lobby 1')
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
