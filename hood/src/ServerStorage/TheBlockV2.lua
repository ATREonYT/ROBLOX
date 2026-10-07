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

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (stamped band, studded lip; rimTopMat Neon = a
-- glowing lip without studs); mat: the inset surface; frame (+frameMat): bench, gantry and stands; groove:
-- the stamped X's colour (nil = a darker shade of the face); text: the "xN Power" colour; glow: hit sparks;
-- edge: a thin neon line inside the rim (shadow). Colours from the bag stations the critics signed off.
-- Tiers 5-7 follow the reference's right row: shadow (x8), frost (x12), toxic (x18).
Stations.Themes = {
	{ name = 'stone', rim = C(62, 78, 118), rimTop = C(82, 104, 150), mat = C(115, 132, 172), frame = C(165, 95, 78),
		text = C(255, 255, 255), glow = C(255, 236, 200) },
	{ name = 'red', rim = C(26, 30, 70), rimTop = C(40, 46, 92), mat = C(250, 45, 85), frame = C(36, 42, 86), trim = C(240, 40, 70),
		text = C(255, 70, 100), glow = C(255, 70, 100) },
	{ name = 'lava', rim = C(225, 100, 35), rimTop = C(255, 150, 50), mat = C(255, 140, 20), frame = C(250, 140, 36), groove = C(215, 90, 10),
		text = C(255, 170, 48), glow = C(255, 150, 40) },
	{ name = 'arcane', rim = C(150, 40, 130), rimTop = C(240, 80, 190), mat = C(190, 70, 208), frame = C(170, 80, 220),
		text = C(214, 120, 255), glow = C(230, 120, 255) },
	{ name = 'shadow', rim = C(70, 40, 110), rimTop = C(92, 56, 140), mat = C(44, 24, 70), frame = C(22, 18, 32),
		text = C(198, 164, 255), glow = C(176, 120, 255), edge = C(150, 70, 255) },
	{ name = 'frost', rim = C(60, 180, 230), rimTop = C(160, 244, 255), mat = C(132, 246, 248), matMat = M.SmoothPlastic, frame = C(80, 215, 250),
		groove = C(60, 190, 235), text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', rim = C(10, 170, 44), rimTop = C(20, 255, 60), rimTopMat = M.Neon, mat = C(0, 60, 60), frame = C(20, 255, 60), frameMat = M.Neon,
		groove = C(5, 150, 35), text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'gold', rim = C(230, 180, 0), rimTop = C(255, 236, 60), mat = C(252, 242, 88), frame = C(245, 192, 0), groove = C(205, 140, 0),
		trim = C(175, 18, 48), text = C(255, 222, 50), glow = C(255, 222, 80) },
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
	local Y, col = Stations.MAT_Y, C(255, 228, 0)
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
	local body, deep, white = C(245, 190, 0), C(222, 150, 0), C(255, 252, 235)
	Stations.ring8(cc, 'CrownRim', at, 1.42, 0.3, 0.22, white)
	Stations.ring8(cc, 'CrownBand', at * CFrame.new(0, 0.2, 0), 1.35, 0.3, 0.75, body)
	for k = 0, 7 do
		local face = at * CFrame.Angles(0, k * math.pi / 4, 0)
		local tall = k % 2 == 0
		local s = tall and 0.78 or 0.52
		local cy = 0.95 + s * 0.25
		cc:part('CrownPoint', V(s, s, 0.24), face * CFrame.new(0, cy, -1.22) * CFrame.Angles(0, 0, math.pi / 4), tall and body or deep)
		if tall then cc:part('CrownTip', V(0.3, 0.3, 0.3), face * CFrame.new(0, cy + s * 0.71, -1.22), white, M.SmoothPlastic, Enum.PartType.Ball) end
		cc:part('CrownGem', V(0.3, 0.3, 0.16), face * CFrame.new(0, 0.58, -1.36) * CFrame.Angles(0, 0, math.pi / 4), tall and C(235, 30, 70) or C(50, 110, 255), M.Glass)
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
	decor(d:box('AmmoStripe', V(2.13, y + 0.3, z - 0.32), V(3.07, y + 0.38, z + 0.24), C(250, 200, 40)))
	decor(d:box('AmmoHandle', V(2.45, y + 0.48, z - 0.08), V(2.75, y + 0.56, z), C(40, 44, 40)))
	-- A few brass shells lying about.
	for i, s in { { 1.45, -0.15, 0.3 }, { 1.7, 0.05, 1.4 }, { 1.25, 0.12, 2.2 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(s[1], y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), i == 2 and C(232, 176, 72) or C(244, 194, 80), M.Metal, Enum.PartType.Cylinder))
	end
	-- Ear muffs: two dark cups under a yellow arch.
	local yellow = C(255, 210, 50)
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
	decor(st:box('FiringLine', V(-3.5, Y, -3.9), V(3.5, Y + 0.03, -3.5), C(255, 214, 30), M.SmoothPlastic)).CastShadow = false
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
function Stations.wall(c, t, color, material, h)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	h = h or 5.6
	local groove = Stations.grooveFor(t, color)
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
-- truss beam across, capped. Hanging targets hang from its underside (GANTRY_Y) on its centre line. neon: lines
-- on the posts' front edges and under the beam (shadow, gold, frost).
function Stations.gantry(g, t, neon)
	local Y, z, y0 = Stations.MAT_Y, Stations.GANTRY_Z, Stations.GANTRY_Y
	local W = 0.8
	local frame, fm = t.frame, t.frameMat or M.SmoothPlastic
	local groove = Stations.grooveFor(t, frame)
	local foot = frame:Lerp(C(0, 0, 0), 0.12)
	for _, sx in { -1, 1 } do
		local x = sx * 3.9
		Stations.stamp(g:box('GantryFoot', V(x - 0.55, 0.05, z - 0.6), V(x + 0.55, Y + 0.75, z + 0.6), fm == M.Neon and t.rim or foot), Stations.SIDES, 1.1, Y + 0.7, groove)
		Stations.truss(g, 'GantryPost', CFrame.new(x, Y + 0.75, z), y0 - Y - 0.75, W, W, frame, groove, 1.55, { '-z', '-x', '+x' }, fm)
		g:box('GantryCap', V(x - 0.55, y0 + W, z - 0.55), V(x + 0.55, y0 + W + 0.25, z + 0.55), fm == M.Neon and t.rim or frame)
		-- A small gusset under each end of the beam.
		g:wedge('GantryGusset', V(0.5, 0.8, 0.8), CFrame.new(x - sx * 0.8, y0 - 0.4, z) * CFrame.Angles(0, sx * math.pi / 2, 0), frame, fm)
		if neon then
			for _, ex in { 3.5, 4.3 } do
				decor(g:box('GantryNeon', V(sx * ex - 0.07, Y + 0.8, z - 0.47), V(sx * ex + 0.07, y0 + 0.75, z - 0.33), neon, M.Neon)).CastShadow = false
			end
		end
	end
	Stations.truss(g, 'GantryBeam', CFrame.new(-4.35, y0 + W / 2, z) * CFrame.Angles(0, 0, -math.pi / 2), 8.7, W, W, frame, groove, 1.45, { '-z' }, fm)
	if neon then decor(g:box('GantryNeon', V(-3.5, y0 - 0.07, z - 0.47), V(3.5, y0 + 0.07, z - 0.33), neon, M.Neon)).CastShadow = false end
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
	Stations.bullseye(back, CFrame.new(0, Y + 6.95, z0 - 0.02), 1.15, { C(250, 250, 245), C(230, 50, 50), C(250, 250, 245), C(230, 50, 50) })
	for i, s in { { -2.9, 0, 1.9 }, { -0.95, 0, 1.9 }, { 0.95, 0, 1.9 }, { 2.9, 0, 1.9 }, { -1.9, 0.62, 1.8 }, { 1.95, 0.62, 1.8 } } do
		back:blob('Sandbag', V(s[3], 0.72, 1.05), V(s[1], Y + 0.34 + s[2], z0 - 0.6), i % 2 == 0 and C(158, 146, 120) or C(140, 130, 106), M.Fabric)
	end
	-- Bunting between two poles over the planks: little flags in turn red, yellow, blue, white (they bob).
	for _, sx in { -1, 1 } do back:box('BuntingPole', V(sx * 4.1 - 0.13, Y, z0 - 0.45), V(sx * 4.1 + 0.13, Y + 9.15, z0 - 0.19), wood:Lerp(C(0, 0, 0), 0.25)) end
	local flags = { C(235, 55, 60), C(255, 210, 50), C(60, 140, 240), C(250, 250, 245) }
	local bc, bunting = back:group('Bunting')
	bc:box('BuntingLine', V(-4.0, Y + 8.92, z0 - 0.35), V(4.0, Y + 8.97, z0 - 0.29), C(250, 250, 245))
	for i = 0, 9 do
		local sag = 0.15 * math.sin((i + 0.5) / 10 * math.pi)
		bc:wedge('Flag', V(0.06, 0.55, 0.62), CFrame.new(-3.6 + i * 0.8, Y + 8.64 - sag, z0 - 0.33) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), flags[i % 4 + 1])
	end
	for _, p in bunting:GetDescendants() do if p:IsA('BasePart') then decor(p).CastShadow = false end end
	bunting.WorldPivot = bc:world(CFrame.new(0, Y + 8.9, z0 - 0.3))
	bunting:SetAttribute('Bob', 0.08)
	bunting:SetAttribute('BobPeriod', 1.6)
	bunting:AddTag('HoodMotion')
	-- The shelf: two posts, two rails and a deep top rail at chest height the targets stand on.
	local fz, top = 5.0, Y + 4.4
	for _, sx in { -1, 1 } do g:box('FencePost', V(sx * 3.05 - 0.28, Y, fz - 0.28), V(sx * 3.05 + 0.28, top + 0.15, fz + 0.28), wood:Lerp(C(0, 0, 0), 0.15)) end
	for _, ry in { 1.3, 2.9 } do g:box('FenceRail', V(-3.45, Y + ry, fz - 0.15), V(3.45, Y + ry + 0.35, fz + 0.15), wood) end
	g:box('FenceShelf', V(-3.5, top - 0.25, fz - 0.95), V(3.5, top, fz + 0.95), wood:Lerp(C(255, 255, 255), 0.08))
	-- Targets, left to right: soda bottle, can, the big cola can with a bullseye (main), can, bottle. Bottles
	-- shatter, cans fly off.
	local items = {
		{ -2.75, 'bottle', soda.orange, 1.25, nil, C(255, 255, 255) }, { -1.5, 'tin', soda.blue, 0.55, 1.25 }, { 0, 'tin', soda.red, 0.88, 2.0, true },
		{ 1.5, 'tin', soda.lime, 0.55, 1.25 }, { 2.75, 'bottle', soda.blue, 1.25, nil, C(255, 214, 40) },
	}
	for _, it in items do
		local base = V(it[1], top, fz)
		local h = it[2] == 'bottle' and 1.5 * it[4] or it[5]
		local bottle = it[2] == 'bottle'
		local sw = Stations.target(k, CFrame.new(base + V(0, 0, 0.2)), base + V(0, h / 2, 0), bottle and 'Shatter' or 'Fly', it[6] == true, bottle and 'Glass' or 'Tin', it[3])
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

-- 2 Red: three bullseye boards on navy easels (the main one up high); a navy board backstop with red trim and a
-- little target sign.
function Stations.Lanes.red(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local back = k.st:group('Backstop')
	local h = 6.6
	Stations.wall(back, t, t.frame, M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.trim, M.SmoothPlastic, 0.3)
	Stations.bullseye(back, CFrame.new(0, Y + h + 1.1, Stations.BACK_Z + 0.28), 0.45, { C(250, 250, 245), t.trim, C(250, 250, 245) })
	local rings = { C(250, 250, 245), C(235, 35, 60), C(250, 250, 245), C(235, 35, 60), C(255, 214, 40) }
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
	Stations.bullseye(g, lean * CFrame.new(0, 0, -0.08), 0.85, { C(250, 250, 245), C(235, 35, 60), C(250, 250, 245) })
end

-- 3 Lava: hot plates swinging from the gantry (a big gong is the main), burning barrels at the sides, a basalt
-- berm with lava cracks and a hot pool on top, nearly as tall as the gantry.
function Stations.Lanes.lava(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local rock, rock2, hot = C(62, 44, 48), C(84, 58, 58), C(255, 110, 20)
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
	decor(back:box('LavaPool', V(-1.8, Y + 7.38, z0 + 0.4), V(1.7, Y + 7.5, Stations.HALF_Z - 0.3), C(255, 170, 30), M.Neon)).CastShadow = false
	-- Plates: a big round gong (main) between two square plates, all hanging from the beam.
	local function gong(sw, x, cy, r)
		Stations.disc(sw, 'GongRim', CFrame.new(x, cy, Stations.GANTRY_Z), r, 0.25, C(70, 66, 76), M.Metal)
		Stations.disc(sw, 'GongHot', CFrame.new(x, cy, Stations.GANTRY_Z - 0.05), r * 0.8, 0.3, C(255, 120, 20), M.Neon)
		Stations.disc(sw, 'GongCore', CFrame.new(x, cy, Stations.GANTRY_Z - 0.1), r * 0.42, 0.34, C(255, 225, 90), M.Neon)
		Stations.chains(sw, x, cy + r - 0.1, r * 0.45)
	end
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, 6.2, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	gong(sw, 0, 6.2, 1.62)
	for _, p in { { -2.65, 4.3, 1.4 }, { 2.65, 4.9, 1.35 } } do
		local s2 = Stations.target(k, CFrame.new(p[1], Stations.GANTRY_Y, Stations.GANTRY_Z), V(p[1], p[2], Stations.GANTRY_Z), 'Swing', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], p[2], Stations.GANTRY_Z), p[3], C(64, 60, 70), C(255, 120, 20), M.Neon, C(255, 220, 80))
		Stations.chains(s2, p[1], p[2] + p[3] / 2, p[3] * 0.32)
	end
	-- Burning barrels (flames come from HoodVFX on their open tops).
	for _, b in { { -2.85, 1.9 }, { 2.9, 3.1 } } do
		local pos = V(b[1], Y, b[2])
		Stations.drum(g, pos, 0.62, 1.7, C(150, 50, 32), C(70, 34, 28), C(40, 24, 22), M.Metal)
		local coal = decor(g:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
		table.insert(k.burners, coal)
	end
end

-- 4 Arcane: a big spinner disc up high (main), two balloons to pop, balloon bunches bobbing on the gantry posts,
-- a deep violet wall with a pink starburst behind the spinner and white sparkle diamonds.
function Stations.Lanes.arcane(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(90, 30, 140), M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.rimTop, M.SmoothPlastic, 0.18)
	local z = Stations.BACK_Z
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 3.7, 0.16, t.rimTop)
	for _, s in { { -3.3, 6.6 }, { 3.2, 2.0 }, { -3.1, 1.6 }, { 3.35, 6.4 }, { -2.6, 4.0 }, { 2.8, 4.6 } } do
		decor(back:part('Sparkle', V(0.42, 0.42, 0.1), CFrame.new(s[1], Y + s[2], z - 0.06) * CFrame.Angles(0, 0, math.pi / 4), C(255, 240, 255), M.Neon)).CastShadow = false
	end
	-- Spinner: a chunky post with a big ringed disc on a hub; it turns slowly and spins when hit.
	local sz = 6.0
	g:box('SpinnerPost', V(-0.2, Y, sz + 0.3), V(0.2, Y + 5.8, sz + 0.7), t.frame)
	g:box('SpinnerFoot', V(-0.75, Y, sz - 0.2), V(0.75, Y + 0.35, sz + 1.2), t.frame:Lerp(C(0, 0, 0), 0.25))
	local sw = Stations.target(k, CFrame.new(0, Y + 5.8, sz), V(0, Y + 5.8, sz), 'Spin', true, 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(0, Y + 5.8, sz + 0.12), 1.72, 0.16, t.frame)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, sz + 0.03), 1.62, { C(255, 255, 255), C(255, 100, 200), C(255, 255, 255), C(150, 60, 220), C(255, 220, 60) })
	-- Balloons to pop, tied to little weights.
	for _, b in { { -2.6, 4.4, Y + 4.2, C(255, 90, 170) }, { 2.65, 5.1, Y + 4.9, C(80, 200, 255) } } do
		local pos = V(b[1], b[3], b[2])
		g:box('BalloonWeight', V(b[1] - 0.22, Y, b[2] - 0.22), V(b[1] + 0.22, Y + 0.35, b[2] + 0.22), C(255, 214, 60))
		local s2 = Stations.target(k, CFrame.new(pos), pos, 'Pop', false, 'Pop', b[4])
		Stations.balloon(s2, pos, 0.62, b[4], V(b[1], Y + 0.35, b[2]))
	end
	-- Bunches of three on each gantry post (they bob; not targets).
	for _, sx in { -1, 1 } do
		local bc, bunch = g:group('BalloonBunch')
		local foot = V(sx * 3.9, Stations.GANTRY_Y + 1.05, Stations.GANTRY_Z)
		for i, c in { C(255, 90, 170), C(255, 220, 60), C(120, 220, 255) } do
			local a = (i - 2) * 0.6
			Stations.balloon(bc, foot + V(math.sin(a) * 1.0 - sx * 0.15, 2.0 + math.cos(a) * 0.5, -0.2 * i), 0.6, c, foot)
		end
		for _, p in bunch:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
		bunch.WorldPivot = bc:world(CFrame.new(foot))
		bunch:SetAttribute('Bob', 0.18)
		bunch:SetAttribute('BobPeriod', 2.6 + sx * 0.3)
		bunch:AddTag('HoodMotion')
	end
end

-- 5 Shadow: dark plates with violet neon rims (a big hanging one is the main, haloed by a neon ring on the
-- obsidian wall), violet neon on the gantry and along the wall's steps.
function Stations.Lanes.shadow(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local violet, dark = C(160, 80, 255), C(40, 30, 60)
	Stations.gantry(g, t, violet)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(30, 20, 44), M.SmoothPlastic, h)
	Stations.wallLines(back, h, violet, M.Neon, 0.12)
	local z = Stations.BACK_Z
	Stations.bullseye(back, CFrame.new(0, Y + 5.8, z - 0.02), 2.5, { violet, C(20, 14, 30), violet, C(20, 14, 30), violet }, { M.Neon, M.SmoothPlastic, M.Neon, M.SmoothPlastic, M.Neon })
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

-- 6 Frost: an ice bullseye on a tall ice pillar (main), small ice blocks on ice pedestals, a four-course ice
-- wall with a snow top, icicles and a neon ice line, icicles, snow and a neon line on the gantry.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, glow, deep = C(248, 252, 255), C(150, 225, 250), C(120, 205, 240), C(140, 240, 255), C(25, 120, 235)
	Stations.gantry(g, t)
	g:box('BeamSnow', V(-4.4, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.45), V(4.4, Stations.GANTRY_Y + 1.0, Stations.GANTRY_Z + 0.45), snow)
	decor(g:box('BeamGlow', V(-3.5, Stations.GANTRY_Y - 0.06, Stations.GANTRY_Z - 0.42), V(3.5, Stations.GANTRY_Y + 0.06, Stations.GANTRY_Z - 0.3), glow, M.Neon)).CastShadow = false
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
	decor(back:box('SnowGlow', V(-4.4, top - 0.12, z0 - 0.2), V(4.4, top, z0 - 0.08), glow, M.Neon)).CastShadow = false
	for _, d in { { -2.6, 1.6, 0.5 }, { 0.6, 2.0, 0.7 }, { 2.9, 1.2, 0.4 } } do back:box('SnowDrift', V(d[1] - d[2] / 2, top + 0.4, z0 + 0.1), V(d[1] + d[2] / 2, top + 0.4 + d[3], z1 - 0.1), snow) end
	for i = 0, 9 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-3.9 + i * 0.86, top - 0.1, z0 - 0.12), len, 0.34)
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	g:box('IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), iceB)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, C(90, 200, 245))
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, mz + 0.03), 1.72, { snow, deep, snow, deep, C(255, 255, 255) })
	-- Ice blocks on pedestals at the sides.
	for _, b in { { -2.6, 4.5, 2.6, 0.95 }, { 2.6, 5.0, 3.2, 0.9 } } do
		local ped = g:box('IcePedestal', V(b[1] - 0.55, Y, b[2] - 0.55), V(b[1] + 0.55, Y + b[3], b[2] + 0.55), iceB)
		ped.Reflectance = 0.15
		g:box('IcePedestalCap', V(b[1] - 0.6, Y + b[3] - 0.08, b[2] - 0.6), V(b[1] + 0.6, Y + b[3], b[2] + 0.6), snow)
		local cy = Y + b[3] + b[4] / 2
		local s2 = Stations.target(k, CFrame.new(b[1], Y + b[3], b[2] + 0.2), V(b[1], cy, b[2]), 'Tip', false, 'Ice')
		Stations.ice(s2, 'IceBlock', CFrame.new(b[1], cy, b[2]) * CFrame.Angles(0, math.rad(b[1] > 0 and 20 or -15), 0), b[4])
	end
end

-- 7 Toxic: a big toxic barrel with a target face on a pallet and two crates (main), green bottles on a shelf
-- under a hanging hazard sign, a second barrel, glowing puddles, a dark container wall with ribs, a hazard
-- stripe and a neon drip sign.
function Stations.Lanes.toxic(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, dark, navy = C(60, 255, 90), C(20, 64, 58), C(24, 30, 70)
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.0
	Stations.wall(back, t, dark, M.SmoothPlastic, h)
	for i = 0, 7 do
		local x = -3.7 + i * 1.06
		back:box('Rib', V(x - 0.14, 0.6, z - 0.12), V(x + 0.14, Y + h - 0.75, z + 0.1), dark:Lerp(C(255, 255, 255), 0.12))
	end
	-- Hazard band: yellow with black slanted bars.
	back:box('HazardBand', V(-4.3, Y + h - 0.7, z - 0.16), V(4.3, Y + h - 0.1, z + 0.1), C(255, 214, 30))
	for i = 0, 7 do
		decor(back:part('HazardBar', V(0.35, 0.82, 0.05), CFrame.new(-3.75 + i * 1.07, Y + h - 0.4, z - 0.18) * CFrame.Angles(0, 0, math.rad(40)), C(30, 30, 36)))
	end
	-- The drip sign (a neon drop on a dark plate), off to the right of the barrel stack.
	local sx, sy = 2.45, Y + 4.4
	Stations.disc(back, 'SignPlate', CFrame.new(sx, sy, z - 0.2), 1.25, 0.14, navy)
	Stations.disc(back, 'Drip', CFrame.new(sx, sy - 0.25, z - 0.32), 0.75, 0.14, neon, M.Neon)
	decor(back:part('DripTip', V(1.06, 1.06, 0.14), CFrame.new(sx, sy + 0.18, z - 0.32) * CFrame.Angles(0, 0, math.pi / 4), neon, M.Neon))
	Stations.disc(back, 'DripShine', CFrame.new(sx - 0.24, sy - 0.05, z - 0.42), 0.18, 0.08, C(220, 255, 220), M.Neon)
	-- Hazard diamond hanging from the beam over the bottle shelf (decor).
	local hx = -2.6
	for _, ox in { -0.5, 0.5 } do g:box('SignChain', V(hx + ox - 0.08, Stations.GANTRY_Y - 0.8, Stations.GANTRY_Z - 0.08), V(hx + ox + 0.08, Stations.GANTRY_Y, Stations.GANTRY_Z + 0.08), C(52, 54, 66)) end
	g:part('HazardSign', V(1.25, 1.25, 0.12), CFrame.new(hx, Stations.GANTRY_Y - 1.5, Stations.GANTRY_Z) * CFrame.Angles(0, 0, math.pi / 4), C(255, 214, 30))
	g:part('HazardSignMark', V(0.22, 0.6, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.4, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	g:part('HazardSignDot', V(0.22, 0.22, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.9, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	-- Main: a big toxic barrel with a target face, on a pallet and two stamped crates.
	local mz = 6.0
	g:box('Pallet', V(-1.05, Y, mz - 1.05), V(1.05, Y + 0.35, mz + 1.05), C(150, 105, 60))
	local crate = g:box('Crate', V(-0.95, Y + 0.35, mz - 0.95), V(0.95, Y + 2.35, mz + 0.95), navy)
	Stations.stamp(crate, Stations.SIDES, 1.9, 2.0, C(5, 150, 35))
	local crate2 = g:part('Crate', V(1.6, 1.8, 1.6), CFrame.new(0.05, Y + 3.25, mz) * CFrame.Angles(0, math.rad(8), 0), dark)
	Stations.stamp(crate2, Stations.SIDES, 1.6, 1.8, C(5, 150, 35))
	local base = Y + 4.15
	local sw = Stations.target(k, CFrame.new(0, base, mz + 0.5), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	Stations.drum(sw, V(0, base, mz), 0.95, 2.5, neon, navy, C(10, 90, 30), M.Neon)
	Stations.bullseye(sw, CFrame.new(0, base + 1.25, mz - 1.02), 0.75, { C(255, 255, 255), navy, neon }, { M.SmoothPlastic, M.SmoothPlastic, M.Neon })
	-- Green bottles on a little shelf (they shatter), and a barrel on the floor.
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), navy) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), navy)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', neon)
		Stations.bottle(s2, b, 0.95, C(60, 220, 90), { label = navy, stripe = neon, material = M.Neon })
	end
	local s3 = Stations.target(k, CFrame.new(2.7, Y, 5.0), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, neon, navy, C(10, 90, 30), M.Neon)
	-- Glowing puddles on the dark mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), neon, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane: a big gold gong (main) on crimson velvet in a deep-gold wall with cream trim and orange
-- rays, golden neon on the gantry, a turning crown on the beam, gold bottles on a gold shelf, a gold plate on a
-- post, lemon nuggets on the sand and a velvet band on the bench (a VIP counter).
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, cream = C(255, 222, 40), C(245, 190, 0), C(255, 252, 235), C(235, 30, 70), C(255, 248, 220)
	Stations.gantry(g, t, C(255, 240, 120))
	g:box('CrownPlinth', V(-0.5, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.4), V(0.5, Stations.GANTRY_Y + 0.95, Stations.GANTRY_Z + 0.4), deep)
	Stations.crown(g, CFrame.new(0, Stations.GANTRY_Y + 0.95, Stations.GANTRY_Z))
	-- Wall: deep gold with cream trim, orange rays behind a gold-rimmed crimson velvet disc, two gems.
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.4
	Stations.wall(back, t, C(240, 180, 0), M.SmoothPlastic, h)
	Stations.wallLines(back, h, cream, M.SmoothPlastic, 0.3)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.08), 4.2, 0.12, C(255, 150, 0))
	Stations.disc(back, 'VelvetRim', CFrame.new(0, Y + 5.8, z - 0.2), 2.62, 0.14, C(255, 236, 80))
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 5.8, z - 0.26), 2.4, 0.14, C(175, 18, 48))
	for _, s in { { -3.45, 1.2, C(60, 140, 255) }, { 3.45, 1.2, C(60, 220, 120) } } do
		back:part('Gem', V(0.42, 0.42, 0.25), CFrame.new(s[1], Y + s[2], z - 0.08) * CFrame.Angles(0, 0, math.pi / 4), s[3], M.Glass)
	end
	-- Main: the gong.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	Stations.disc(sw, 'GongRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.03), 2.0, 0.22, deep)
	Stations.disc(sw, 'Gong', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.75, 0.28, gold)
	Stations.disc(sw, 'GongRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 1.08, 0.32, deep)
	Stations.disc(sw, 'GongBoss', CFrame.new(0, cy, Stations.GANTRY_Z - 0.1), 0.78, 0.36, gold)
	sw:part('GongRuby', V(0.52, 0.52, 0.3), CFrame.new(0, cy, Stations.GANTRY_Z - 0.3) * CFrame.Angles(0, 0, math.pi / 4), ruby, M.Glass)
	Stations.chains(sw, 0, cy + 1.9, 0.8)
	-- Gold bottles on a gold shelf (left) and a gold plate on a post (right).
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), deep) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), deep)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', gold)
		Stations.bottle(s2, b, 0.95, gold, { label = white, stripe = ruby, cap = ruby })
	end
	g:box('PlatePost', V(2.4, Y, 5.15), V(2.8, Y + 3.0, 5.55), deep)
	local s3 = Stations.target(k, CFrame.new(2.6, Y + 3.0, 5.15), V(2.6, Y + 3.65, 5.05), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(2.6, Y + 3.65, 5.05), 1.3, gold, deep, M.SmoothPlastic, white)
	-- Lemon nuggets on the sand, well apart.
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

	Stations.labels(st, s, t, Stations.LABEL)
	model:SetAttribute('Tier', tier)
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
	line(g, 'Subtitle', 'BETTER GUN = MORE POWER PER SHOT', C(120, 20, 20), FONT.loud, 0.2, 0.6, C(255, 240, 200), 2)
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
--           plain black belt with two big V's and a white neon tube across its step-on end, a cyan-white screen
--           bank lit by teal trims, dark smoke climbing past the horns with thin white strands and eight swaying
--           smoke lines (textureless Beams, so they work before any upload), magenta glints and speed streaks
-- Local frame: origin on the floor at the middle, footprint x -3.5..3.5, z -7..7, parts up to y ~10.9 (the
-- Sprint horns lean out past x 3.5 above the header, like the reference's), labels float above. The runner stands on the belt
-- facing +Z, toward the screen; walk on from -Z.
-- Contract (TreadmillService, Treadmill.client): Treadmill_<Id> > TreadmillZone (invisible, the belt's top),
-- Belt (the walking surface; attributes describe the scrolling pattern), Slat / Chevron parts (attributes Z0,
-- Side) that the client scrolls, Screen (SurfaceGui with TextLabels Title and Detail; ScreenSide panels beside
-- it on Run and Sprint), Sign (BillboardGui Label with Chip, Cost, Detail, Speed; Config/Treadmills.layoutLabel
-- switches it), emitter BeltMist (attribute BaseRate), PointLight ScreenLight, Sprint's SmokeLine1..98 Beams
-- (attributes BaseCurve0/1, Sway, Period, Phase; their Attachment1 has BaseY) that the client sways; attributes Tier,
-- TreadmillId, Multiplier, Required; tag HoodTreadmill.
local Treadmills = {}

-- Per tier: frame/frameDark (rails, uprights; rail sides), baseRim (the plinth's edge), deck (under the belt,
-- the caps), slat/gap (belt stripes and the belt between them), screen/screenText/bezel and how many panels,
-- grip/bar (handrails), mist (belt veil from/to), edge (floor haze), rail (a glowing rail cap instead of the
-- studded steel one), tube (neon on the deck), rearY (belt height at the back: Sprint stands on a thick deck),
-- textT (the LCD text's transparency), trim (Neon round the screen bank).
Treadmills.Looks = {
	{ name = 'steel', frame = C(172, 190, 220), frameDark = C(92, 108, 138), baseRim = C(138, 154, 182), deck = C(22, 36, 68),
		slat = C(20, 32, 62), gap = C(118, 138, 176), screen = C(30, 225, 245), screenText = C(10, 120, 140), bezel = C(24, 120, 150),
		panels = 1, grip = C(45, 125, 210), bar = C(26, 40, 70), mist = { C(214, 232, 255), C(150, 195, 255) }, edge = C(165, 190, 235), rearY = 0.8 },
	{ name = 'lemon', frame = C(172, 190, 220), frameDark = C(92, 108, 138), baseRim = C(138, 154, 182), deck = C(22, 36, 68),
		slat = C(20, 32, 62), gap = C(118, 138, 176), screen = C(255, 232, 40), screenText = C(150, 120, 0), bezel = C(26, 40, 70),
		panels = 2, grip = C(255, 214, 40), bar = C(26, 40, 70), mist = { C(255, 246, 220), C(255, 222, 150) }, edge = C(240, 220, 170),
		rail = C(255, 240, 80), rearY = 0.8 },
	{ name = 'black', frame = C(26, 26, 32), frameDark = C(14, 14, 18), baseRim = C(30, 30, 36), deck = C(16, 16, 22),
		slat = C(18, 18, 24), gap = C(18, 18, 24), screen = C(172, 235, 242), screenText = C(40, 130, 140), bezel = C(18, 18, 24),
		panels = 3, textT = 0.65, trim = C(100, 165, 170), grip = C(245, 245, 255), bar = C(26, 26, 32),
		mist = { C(235, 235, 245), C(170, 170, 185) }, edge = C(150, 150, 165),
		tube = C(245, 245, 255), rearY = 1.4 },
}
Treadmills.Chevron = C(236, 242, 252)
-- The belt, in the treadmill's frame: from (y rearY, z RearZ) up to (y rearY + Rise, z RearZ + Run).
Treadmills.Belt = { RearZ = -5.8, Run = 10.3, Rise = 0.45 }

-- Until HoodVFX's textures are uploaded, an emitter falls back to a Roblox built-in (a soft smoke blob or a
-- sparkle), which can't draw curls or a thin veil. Like HoodVFX's own FALLBACK_FADE, the stand-in is kept faint
-- (opacity times the fade) or switched off where a blob would read as cotton; `fallback` (props applied only
-- then) tunes a single emitter. Screen halos go too: the game's Bloom already glows the Neon, and the built-in
-- glow draws a round balloon.
Treadmills.FallbackFade = { wisp = 0, wispline = 0, softglow = 0, mist = 0.5 }

-- An emitter with a Roblox built-in texture (or HoodVFX's uploaded one, with its flipbook, when it has it),
-- named for the offline previewer. Acceleration comes in `frame`'s axes and is turned into world space here.
-- The uploaded id for a HoodVFX texture key: HoodVFX.Textures first, then the treadmills' own
-- (Config/Treadmills.Textures); false until it is uploaded.
function Treadmills.uploaded(tex)
	local ok, VFX = pcall(function() return require(ReplicatedStorage.Shared.HoodVFX) end)
	local okCfg, cfg = pcall(function() return require(ReplicatedStorage.Shared.Config.Treadmills) end)
	local id = ok and type(VFX) == 'table' and VFX.Textures and VFX.Textures[tex]
	if not (type(id) == 'string' and id ~= '') and okCfg and type(cfg.Textures) == 'table' then id = cfg.Textures[tex] end
	return type(id) == 'string' and id ~= '' and id
end

function Treadmills.emitter(parent, name, tex, frame, props, fallback)
	local builtin = { mist = 'rbxasset://textures/particles/smoke_main.dds', aura = 'rbxasset://textures/particles/smoke_main.dds',
		wisp = 'rbxasset://textures/particles/smoke_main.dds', wispline = 'rbxasset://textures/particles/smoke_main.dds',
		glitter = 'rbxasset://textures/particles/sparkles_main.dds',
		streak = 'rbxasset://textures/particles/sparkles_main.dds', softglow = 'rbxasset://textures/glow.png',
		linebit = 'rbxasset://textures/particles/sparkles_main.dds' }
	local flip = { aura = { Enum.ParticleFlipbookLayout.Grid2x2, Enum.ParticleFlipbookMode.Loop, NumberRange.new(0), true },
		wisp = { Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookMode.OneShot },
		-- 16 different static strands: one random frame per particle (the aura recipe).
		wispline = { Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookMode.Loop, NumberRange.new(0), true } }
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	local uploaded = Treadmills.uploaded(tex)
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
	title.TextTransparency = k.textT or 0.5
	if detail then
		local d = line(sg, 'Detail', row.Required == 0 and 'FREE' or compact(row.Required) .. ' POWER', k.screenText, FONT.loud, wide and 0.6 or 0.7, 0.2)
		d.TextTransparency = k.textT or 0.5
	end
	return p
end

-- Thin smoke lines on the x999 (Sprint): textureless Beams, so they draw before any texture is uploaded.
-- Ninety-six short arcs run across and through the whole cloud (sixteen of them in the doorway under the bank):
-- half C-arcs, half S-curves, each with its own strength. Two longer lines climb outside the posts from the bank
-- to the horns (curving outward only, so they never cross the screens). Treadmill.client sways them: CurveSize0/1
-- around BaseCurve0/1 by Sway, Attachment1 bobbing round BaseY.
Treadmills.LineColor = ColorSequence.new(C(228, 242, 244), C(160, 182, 188)) -- teal-white, like the bank's light
function Treadmills.smokeLines(tm, B, rearY)
	local holder = ghost(tm:part('SmokeLines', V(0.2, 0.2, 0.2), CFrame.new(0, 0.5, 0), P.white))
	local hcf = holder.CFrame
	local rnd = Random.new(9990)
	local function attach(name, cf)
		local a = Instance.new('Attachment')
		a.Name = name
		a.CFrame = hcf:ToObjectSpace(tm:world(cf))
		a.Parent = holder
		return a
	end
	local function beam(i, a0, a1, c0, c1, props)
		local b = Instance.new('Beam')
		b.Name = 'SmokeLine' .. i
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = ''
		b.FaceCamera, b.Segments = true, props.segments
		b.Width0, b.Width1 = props.w0, props.w1
		b.Color = Treadmills.LineColor
		if props.gaps then
			-- Broken like the reference's lines: fades in, holds `mid`, breaks `gaps` times (each break a tenth to a
			-- seventh of the length), fades out.
			local mid, pts = props.mid, { { 0, 1 }, { 0.12, props.mid } }
			local centres = props.gaps == 1 and { 0.5 + rnd:NextNumber(-0.15, 0.15) } or { 0.36 + rnd:NextNumber(-0.03, 0.03), 0.64 + rnd:NextNumber(-0.03, 0.03) }
			for _, c in centres do
				local half = rnd:NextNumber(0.05, 0.07)
				for _, kp in { { c - half - 0.02, mid }, { c - half, 1 }, { c + half, 1 }, { c + half + 0.02, mid } } do table.insert(pts, kp) end
			end
			table.insert(pts, { 0.88, math.min(1, mid + 0.1) })
			table.insert(pts, { 1, 1 })
			b.Transparency = Treadmills.seq(pts)
		else
			b.Transparency = Treadmills.seq({ { 0, 1 }, { 0.15, props.mid }, { 0.75, math.min(1, props.mid + 0.1) }, { 1, 1 } })
		end
		b.LightEmission, b.LightInfluence = props.emission, 0
		b.CurveSize0, b.CurveSize1 = c0, c1
		b:SetAttribute('BaseCurve0', c0)
		b:SetAttribute('BaseCurve1', c1)
		b:SetAttribute('Sway', props.sway)
		b:SetAttribute('Period', rnd:NextNumber(2.4, 3.6))
		b:SetAttribute('Phase', rnd:NextNumber(0, 2 * math.pi))
		a1:SetAttribute('BaseY', a1.CFrame.Position.Y)
		b.Parent = holder
	end
	local deckTop = function(z) return rearY + B.Rise * (z - B.RearZ) / B.Run + 0.35 end
	local bankBottom = 5.65
	local arcs = 96
	for i = 1, arcs do
		local p0
		if i <= 16 then
			-- In the doorway, just under the bank.
			p0 = V(rnd:NextNumber(-2.3, 2.3), bankBottom - rnd:NextNumber(0.5, 1.5), rnd:NextNumber(3.9, 4.5))
		else
			local z = rnd:NextNumber(-6.2, 4.6)
			p0 = V(rnd:NextNumber(-3, 3), rnd:NextNumber(deckTop(z) + 0.4, bankBottom - 0.3), z)
		end
		-- Across, not up: within 60 degrees of horizontal, 0.8-1.6 studs long.
		local yaw, pitch = rnd:NextNumber(0, 2 * math.pi), math.rad(rnd:NextNumber(-60, 60))
		local d = V(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local p1 = p0 + d * rnd:NextNumber(0.8, 1.6)
		-- Bend in the plane holding the chord and the vertical, turned up to 60 degrees about the chord.
		local up = V(0, 1, 0)
		local perp = (up - d * up:Dot(d)).Unit
		perp = CFrame.fromAxisAngle(d, math.rad(rnd:NextNumber(-60, 60))):VectorToWorldSpace(perp)
		-- Attachment0's X axis is perp and Attachment1's is -perp, so same-sign curve sizes bow both control points
		-- the same way (a C-arc) and opposite signs make an S.
		local a0 = attach('LineFoot' .. i, CFrame.fromMatrix(p0, perp, d))
		local a1 = attach('LineTip' .. i, CFrame.fromMatrix(p1, -perp, d))
		local k0 = rnd:NextNumber(0.3, 0.6) * (rnd:NextNumber() < 0.5 and -1 or 1)
		local k1 = rnd:NextNumber(0.3, 0.6) * (i % 2 == 0 and 1 or -1) * (k0 > 0 and 1 or -1)
		beam(i, a0, a1, k0, k1, { segments = 24, w0 = 0.16, w1 = 0.06, mid = rnd:NextNumber(0, 0.2), emission = 0.8, sway = 0.35,
			gaps = i % 4 == 0 and 2 or 1 })
	end
	for j, sx in { -1, 1 } do
		-- X axes point outward, so both control points sit outside the post.
		local yaw = sx > 0 and 0 or math.pi
		local p0 = V(sx * 3.7, 6.6, 4.8)
		local tip = p0 + V(sx * 0.4, rnd:NextNumber(3, 4), 0.2)
		beam(arcs + j, attach('LineFoot' .. arcs + j, CFrame.new(p0) * CFrame.Angles(0, yaw, 0)), attach('LineTip' .. arcs + j, CFrame.new(tip) * CFrame.Angles(0, yaw, 0)),
			rnd:NextNumber(1, 1.8), -rnd:NextNumber(0.8, 1.4), { segments = 24, w0 = 0.12, w1 = 0.03, mid = 0.3, emission = 0.1, sway = 1.2 })
	end
	return holder
end

-- Build treadmill `id` (a Config/Treadmills id) in ctx (frame above). opts.vfx = false skips the effects.
function Treadmills.build(ctx, id, opts)
	opts = opts or {}
	local cfg = require(ReplicatedStorage.Shared.Config.Treadmills)
	local row = assert(cfg.ById[id], 'unknown treadmill ' .. tostring(id))
	local tier = math.clamp(opts.tier or row.Tier, 1, 3)
	local k = Treadmills.Looks[tier]
	local black = tier == 3
	local tm, model = ctx:group('Treadmill_' .. id)

	-- Plinth: one pale slab (a slightly darker rim under a studded top).
	studs(tm:box('BaseRim', V(-3.5, 0, -7), V(3.5, 0.22, 7), k.baseRim))
	studs(tm:box('Base', V(-3.32, 0.22, -6.82), V(3.32, 0.42, 6.82), k.frame))

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
			if sx == 1 then
				-- And one across the step-on end of the deck, at the same height.
				decor(b:part('TubeEnd', V(5.6, 0.22, 0.22), CFrame.new(0, faceY, -L / 2 - 0.78), k.tube, M.Neon)).CastShadow = false
			end
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
		-- The bank lights its own frame, like the reference's: teal dividers between the panels, lips along the
		-- top and bottom, and a lip under the header's front edge.
		for _, dx in { -0.885, 0.885 } do
			decor(tm:part('BankTrim', V(0.14, 1.5, 0.05), bank * CFrame.new(dx, 0, -0.19), k.trim, M.Neon)).CastShadow = false
		end
		for _, dy in { -0.81, 0.81 } do
			decor(tm:part('BankTrim', V(5.2, 0.12, 0.05), bank * CFrame.new(0, dy, -0.19), k.trim, M.Neon)).CastShadow = false
		end
		decor(tm:box('BankTrim', V(-2.65, 7.5, 4.55), V(2.65, 7.6, 4.85), k.trim, M.Neon)).CastShadow = false
		-- The header's face catches the bank's light: a bright band fading upward (two strips).
		decor(tm:box('BankTrim', V(-2.65, 7.6, 4.51), V(2.65, 7.8, 4.55), k.trim, M.Neon)).CastShadow = false
		decor(tm:box('BankTrim', V(-2.65, 7.8, 4.51), V(2.65, 7.98, 4.55), k.trim:Lerp(P.black, 0.35), M.Neon)).CastShadow = false
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
		}, { Enabled = false }) -- smoke_main draws hard white blobs on the floor: wait for the aura upload
		-- The screen's halo behind the shell (Roblox blooms Neon a little; this reads from across the room).
		local halo = Instance.new('Attachment')
		halo.Name = 'Halo'
		-- Straight behind the screen's centre in world space (not along the tilted panel's own axis, which would
		-- drop the glow below the screen).
		local back = -screen.CFrame.LookVector
		halo.CFrame = CFrame.new(screen.CFrame:VectorToObjectSpace(V(back.X, 0, back.Z).Unit * 0.7))
		halo.Parent = screen
		-- Squashed to the screen's shape (width / height 2^1.1 = 2.1, like the 5.0 x 1.9 screen) with an even margin;
		-- Rotation stays 0 so the squash stays horizontal. Off until softglow is uploaded (FallbackFade). The
		-- Sprint has none: its bank sits in a black gate, so a halo only lands on the wall beside it; its teal trims
		-- light the frame instead.
		local glow = Treadmills.emitter(halo, 'ScreenGlow', 'softglow', CFrame.new(), {
			Rate = 0.8, Lifetime = NumberRange.new(2.5), Speed = NumberRange.new(0), Rotation = NumberRange.new(0),
			Size = seq({ { 0, 4.5 }, { 1, 4.7 } }), Squash = NumberSequence.new(-1.1),
			Transparency = seq({ { 0, 1 }, { 0.4, 0.68 }, { 0.6, 0.68 }, { 1, 1 } }),
			Color = ColorSequence.new(k.screen), LightEmission = 1, ZOffset = -1,
		})
		if black then glow.Enabled = false end
		if tier >= 2 then
			Treadmills.emitter(fx, 'Glints', 'glitter', beltWorld, {
				Rate = tier == 2 and 4 or 7, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(30, 30),
				Size = seq({ { 0, 0 }, { 0.3, 0.6, 0.2 }, { 1, 0 } }), Color = ColorSequence.new(P.white, row.Color), LightEmission = 1, Brightness = 2, ZOffset = 1,
			})
		end
		if black then
			-- The x999's smoke, after ref_15: a teal-grey body with near-black puffs and pale haze in it, thin teal-white
			-- strands and arcs running through all of it. It buries the gate's lower half (the column reaches the
			-- bank, the side strips rise to the bank's middle, smoke climbs behind the posts past the horns); only
			-- the bank's lit panels stay clear.
			local column = ghost(tm:part('AuraColumn', V(7.4, 1, 9), CFrame.new(0, 2.0, -1.1), P.white))
			local smokeDark = ColorSequence.new(C(74, 88, 94), C(30, 36, 40))
			local lines = Treadmills.LineColor
			local strandT = seq({ { 0, 0.75 }, { 0.2, 0.45 }, { 0.8, 0.6 }, { 1, 1 } })
			-- Before the upload smoke_main stands in for the cloud sheet with no strands over it: thinner and darker,
			-- in patches, so the smoke lines (beams) show between the puffs.
			local thinSmoke = { Color = ColorSequence.new(C(44, 52, 56), C(16, 19, 22)),
				Transparency = seq({ { 0, 1 }, { 0.2, 0.7 }, { 0.7, 0.78 }, { 1, 1 } }) }
			local patchySmoke = { Color = thinSmoke.Color, Transparency = seq({ { 0, 1 }, { 0.2, 0.64 }, { 0.7, 0.74 }, { 1, 1 } }), Rate = 12 }
			local patchyLow = { Color = thinSmoke.Color, Transparency = thinSmoke.Transparency, Rate = 12 }
			Treadmills.emitter(column, 'Aura', 'aura', CFrame.new(), {
				Rate = 30, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1.2, 1.8), SpreadAngle = Vector2.new(20, 20),
				Acceleration = V(0, 0.1, 0), Drag = 0.4, RotSpeed = NumberRange.new(-20, 20), ZOffset = -1,
				Size = seq({ { 0, 3.5 }, { 1, 5.5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.7 }, { 0.7, 0.78 }, { 1, 1 } }),
				Color = smokeDark, LightEmission = 0,
			}, patchySmoke)
			-- Near-black puffs in front of the body, and a pale haze behind it.
			Treadmills.emitter(column, 'Puffs', 'aura', CFrame.new(), {
				Rate = 24, Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(1.2, 2.0), SpreadAngle = Vector2.new(25, 25),
				Acceleration = V(0, 0.1, 0), Drag = 0.4, RotSpeed = NumberRange.new(-20, 20), ZOffset = 0,
				Size = seq({ { 0, 1.6 }, { 1, 2.8 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.15 }, { 0.7, 0.3 }, { 1, 1 } }),
				Color = ColorSequence.new(C(16, 19, 22)), LightEmission = 0,
			}, { Rate = 13, Transparency = seq({ { 0, 1 }, { 0.2, 0.1 }, { 0.7, 0.25 }, { 1, 1 } }) })
			-- Before the upload the cloud's gaps show the belt's stair edges: a low dark veil lies on the deck then.
			local veil = ghost(tm:part('DeckVeil', V(7.4, 0.4, 10), CFrame.new(0, rearY + 0.9, -0.6), P.white))
			Treadmills.emitter(veil, 'DeckVeil', 'aura', CFrame.new(), {
				Enabled = false, Rate = 20, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.1, 0.3), SpreadAngle = Vector2.new(30, 30),
				Drag = 0.5, RotSpeed = NumberRange.new(-10, 10), ZOffset = -0.5,
				Size = seq({ { 0, 2.5 }, { 1, 3.5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.45 }, { 0.7, 0.55 }, { 1, 1 } }),
				Color = thinSmoke.Color, LightEmission = 0,
			}, { Enabled = true })
			-- The doorway under the bank: small near-black puffs and strands just under the bank's bottom edge, drifting
			-- across the posts, so the gate's lower half sits in smoke while the panels stay readable.
			local door = ghost(tm:part('DoorSmoke', V(6.4, 0.6, 1.4), CFrame.new(0, 4.3, 3.9), P.white))
			Treadmills.emitter(door, 'DoorPuffs', 'aura', CFrame.new(), {
				Rate = 8, Lifetime = NumberRange.new(1.6, 2.2), Speed = NumberRange.new(0.2, 0.4), SpreadAngle = Vector2.new(20, 20),
				Drag = 0.6, RotSpeed = NumberRange.new(-20, 20), ZOffset = 0,
				Size = seq({ { 0, 0.8 }, { 1, 1.5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.35 }, { 0.7, 0.5 }, { 1, 1 } }),
				Color = ColorSequence.new(C(16, 19, 22)), LightEmission = 0,
			})
			Treadmills.emitter(door, 'WispsDoor', 'wispline', CFrame.new(), {
				Rate = 8, Lifetime = NumberRange.new(1.4, 2.0), Speed = NumberRange.new(0.2, 0.5), SpreadAngle = Vector2.new(25, 25),
				Drag = 0.6, Rotation = NumberRange.new(-35, 35), RotSpeed = NumberRange.new(-12, 12),
				Size = seq({ { 0, 1.0 }, { 1, 1.8 } }), Transparency = strandT, Color = lines, LightEmission = 0,
			})
			-- Pale haze rising from the back two thirds of the deck (kept off the doorway and the panels).
			local hazeBox = ghost(tm:part('HazeColumn', V(7.4, 2, 6), CFrame.new(0, 2.5, -2.6), P.white))
			Treadmills.emitter(hazeBox, 'Haze', 'aura', CFrame.new(), {
				Rate = 5, Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.6, 0.9), SpreadAngle = Vector2.new(30, 30),
				Acceleration = V(0, 0.1, 0), Drag = 0.4, RotSpeed = NumberRange.new(-12, 12), ZOffset = -2,
				Size = seq({ { 0, 5 }, { 1, 7.5 } }), Transparency = seq({ { 0, 1 }, { 0.25, 0.66 }, { 0.75, 0.76 }, { 1, 1 } }),
				Color = ColorSequence.new(C(176, 196, 202)), LightEmission = 0.15,
			}, { Rate = 2.5, Transparency = seq({ { 0, 1 }, { 0.25, 0.86 }, { 0.75, 0.9 }, { 1, 1 } }) }) -- smoke_main reads as white cumulus
			-- Thin teal-white strands (wispline: 16 different static strands, one per particle) flowing up and
			-- across through the smoke; they grow instead of animating frames, and turn only a little.
			Treadmills.emitter(column, 'Wisps', 'wispline', CFrame.new(), {
				Rate = 50, Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(1.6, 2.8), SpreadAngle = Vector2.new(25, 25),
				Acceleration = V(0, 0.8, 0), Drag = 0.6, Rotation = NumberRange.new(-35, 35), RotSpeed = NumberRange.new(-12, 12),
				Size = seq({ { 0, 2.0 }, { 1, 4.2 } }), Transparency = strandT, Color = lines, LightEmission = 0,
			})
			-- Smoke along both sides wraps the ladders and the deck tubes; a strip outside each post rises to the
			-- bank's middle and wraps the posts (small puffs, so they stop at the panels' outer edges).
			for _, sx in { -1, 1 } do
				local post = ghost(tm:part('PostSmoke', V(0.8, 3.6, 1.6), CFrame.new(sx * 4.2, 4.4, 5.0), P.white))
				Treadmills.emitter(post, 'AuraPost', 'aura', CFrame.new(), {
					Rate = 6, Lifetime = NumberRange.new(2, 2.8), Speed = NumberRange.new(0.3, 0.6), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.1, 0), Drag = 0.5, RotSpeed = NumberRange.new(-15, 15), ZOffset = -1,
					Size = seq({ { 0, 2 }, { 1, 3.2 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 0.7, 0.66 }, { 1, 1 } }),
					Color = smokeDark, LightEmission = 0,
				}, thinSmoke)
				Treadmills.emitter(post, 'WispsPost', 'wispline', CFrame.new(), {
					Rate = 5, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.2, 0), Drag = 0.6, Rotation = NumberRange.new(-35, 35), RotSpeed = NumberRange.new(-12, 12),
					Size = seq({ { 0, 1.4 }, { 1, 2.2 } }), Transparency = strandT, Color = lines, LightEmission = 0,
				})
				local side = ghost(tm:part('AuraSide', V(0.9, 1, 8), CFrame.new(sx * 3.3, 2.4, -0.4), P.white))
				Treadmills.emitter(side, 'AuraLow', 'aura', CFrame.new(), {
					Rate = 12, Lifetime = NumberRange.new(2.2, 3), Speed = NumberRange.new(0.8, 1.3), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.15, 0), Drag = 0.5, RotSpeed = NumberRange.new(-15, 15), ZOffset = -1,
					Size = seq({ { 0, 3.5 }, { 1, 5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.5 }, { 0.7, 0.62 }, { 1, 1 } }),
					Color = smokeDark, LightEmission = 0,
				}, patchyLow)
				Treadmills.emitter(side, 'WispsLow', 'wispline', CFrame.new(), {
					Rate = 14, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.6, 1.2), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, 0.3, 0), Drag = 0.6, Rotation = NumberRange.new(-35, 35), RotSpeed = NumberRange.new(-12, 12),
					Size = seq({ { 0, 1.8 }, { 1, 3.2 } }), Transparency = strandT, Color = lines, LightEmission = 0,
				})
			end
			-- Smoke climbing up behind the gate's posts past the horns, with strands in it.
			for _, sx in { -1, 1 } do
				local back = ghost(tm:part('AuraHighBase', V(1.2, 1, 2.4), CFrame.new(sx * 5.0, 5.4, 5.8), P.white))
				Treadmills.emitter(back, 'AuraHigh', 'aura', CFrame.new(), {
					Rate = 6, Lifetime = NumberRange.new(2.6, 3.4), Speed = NumberRange.new(1.5, 2.2), SpreadAngle = Vector2.new(15, 15),
					Acceleration = V(0, 0.2, 0), Drag = 0.3, RotSpeed = NumberRange.new(-15, 15), ZOffset = -1,
					Size = seq({ { 0, 4.5 }, { 1, 8 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.7 }, { 0.7, 0.8 }, { 1, 1 } }),
					Color = smokeDark, LightEmission = 0,
				}, { Color = thinSmoke.Color, Rate = 12, Size = seq({ { 0, 5 }, { 1, 8.5 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.91 }, { 0.7, 0.95 }, { 1, 1 } }) })
				Treadmills.emitter(back, 'WispsHigh', 'wispline', CFrame.new(), {
					Rate = 20, Lifetime = NumberRange.new(2.0, 2.8), Speed = NumberRange.new(1.4, 2.0), SpreadAngle = Vector2.new(20, 20),
					Acceleration = V(0, 0.3, 0), Drag = 0.4, Rotation = NumberRange.new(-35, 35), RotSpeed = NumberRange.new(-12, 12),
					Size = seq({ { 0, 2.4 }, { 1, 4.0 } }), Transparency = strandT, Color = lines, LightEmission = 0,
				})
			end
			Treadmills.smokeLines(tm, B, rearY)
			-- Before wispline is uploaded: short broken strokes all through the cloud, the built-in sparkle squashed
			-- into a thin needle (soft, tapered, brightest in the middle) and turned within 60 degrees of
			-- horizontal. They are particles, so they sort with the smoke (beams always draw under it).
			local bits = Treadmills.emitter(column, 'LineBits', 'linebit', CFrame.new(), {
				Rate = 190, Lifetime = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(0.8, 1.6), SpreadAngle = Vector2.new(40, 40),
				Acceleration = V(0, 0.4, 0), Drag = 0.5, Rotation = NumberRange.new(60, 120), RotSpeed = NumberRange.new(-15, 15),
				Size = seq({ { 0, 0.48, 0.12 }, { 1, 0.62, 0.12 } }), Squash = seq({ { 0, 2.6 }, { 1, 2.6 } }), ZOffset = 0.5,
				Transparency = seq({ { 0, 1 }, { 0.15, 0.25, 0.2 }, { 0.8, 0.4, 0.2 }, { 1, 1 } }), Color = lines, LightEmission = 0.15,
			})
			local doorBits = bits:Clone()
			doorBits.Name, doorBits.Rate, doorBits.Speed = 'DoorBits', 24, NumberRange.new(0.2, 0.5)
			doorBits.Parent = door
			for _, e in { bits, doorBits } do
				e.Enabled = not Treadmills.uploaded('wispline')
				e:SetAttribute('PreviewTexture', nil)
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
-- The EVOLUTIONS podium, the lobby's morph stand, after the reference's east side and laid out for room: a
-- stepped pyramid of three studded slate-grey tiers (5 / 5 / 4 looks, cheapest at the front and bottom, 9 studs
-- apart, row 2 half a pitch over so every figure stands in a gap of the row in front, each look with its own
-- standing spot on the level in front: the apron, or the 4-stud walk behind the row below). The walkway side
-- (+X) has the wide stair: 6-wide flights with a yellow nose on every step and a red carpet from the slab edge
-- up to the Kingpin on his red plinth at tier 2's back corner, before a red velvet panel; a 4-wide flight on the
-- far side. Warehouse dress, kept to a few big pieces: the neon EVOLUTIONS marquee across the first tier, the
-- standing WARDROBE on the walkway-side front corner (garment rack, mirror, lightbox; its prompt opens the
-- EVOLVE board: every look, equip from there), roller-shutter loading bays behind (light behind the top row,
-- blue on the wings), the DOCK stencil, lamps on the wing caps, a NEW STOCK pallet by the walkway stair.
-- Alive: motes rising off every pad, sparkles on the top tier, chasing marquee bulbs, colour-cycling arrows,
-- warm underglow under the tier lips; the client makes unlocked looks breathe, turns the one you wear and paints
-- locked looks in shadow, and marks your next look with a ▼ over its hat and a NEXT tag on its pad.
--
-- Contract (Lobby.client, LobbyService): a Model `Morphs` (Persistent) holding one Model `Skin_<Id>` per look:
--   Interact     invisible part just in front of the pad: the prompt sits on it (short range, so neighbours'
--                prompts never overlap) and the server measures the 14-stud equip distance to it
--   LabelAnchor  BillboardGui WorldLabel > TextLabels Title (name), Price, Gain (+N/sec) and Detail
--                (EQUIPPED / EQUIP / LOCKED, written by the client, which also shows the label only near you)
--                and BillboardGui NextMarker (the ▼, tip just over the hat)
--   Display      the figure (SkinArt); the client paints it in a band-tinted shadow while locked
--   Lock         a small gold padlock on the pad's front edge, shown while locked
--   Turntable    a disc under the figure, shown for the look you wear
--   NextTag      a yellow NEXT tag hanging off the pad's front lip, shown on your next look
-- and attributes Look, Index, Required, Band, BandColor, Column, LockShade (+ Showcase on the Kingpin).
-- Effects marked UnlockedOnly (or held by a part marked so) are switched off by the client while locked.
-- Beside Morphs: `WardrobePoint` (the standing WARDROBE's prompt part; the server lets you equip any unlocked look
-- from the EVOLVE panel within 30 studs of it). The map root still needs MorphStand = true (g_build).
-- Local frame: origin = centre of the front edge on the floor, the front faces -Z (players walk up from -Z),
-- the walkway is on the +X side, footprint x -28..28, z 0..32, at most 20 tall (labels float above).
local Evolutions = {}

Evolutions.Base = 0.4 -- floor slab top
Evolutions.Apron = 5 -- front apron depth: row 1's standing spots
Evolutions.StepRise = 0.9 -- at most, per step
Evolutions.Run = 1.1 -- per step (40 degrees)
Evolutions.Lip = 1 -- tier front to pad front
Evolutions.Pitch = 9.5 -- tier front to tier front: lip, pad, a 4.1-stud walk behind the pads (the next row's spots)
Evolutions.Back = 30.5 -- tiers end here, the backdrop stands behind
Evolutions.Spacing = 9 -- figure to figure along a row
Evolutions.Pad = 4.4
Evolutions.PadH = 1.1
-- Rows (x of each look, viewer's left = +X = the walkway side first): row 1 round x = -1, row 2 shifted half a
-- pitch so each of its figures stands in a gap of row 1, row 3 back on row 1's lines two tiers up; the top tier
-- leaves tier 2's walkway corner to the Kingpin.
Evolutions.Columns = { { 17, 8, -1, -10, -19 }, { 12.5, 3.5, -5.5, -14.5, -23.5 }, { 8, -1, -10, -19 } }
-- Tiers: x0..x1 at their own heights (a tier is a block from the slab up, so its ends can differ), front and
-- the flights cut into its front edge ({ x0, x1 }); tier 3 has none (its front is a 1-stud lip, nobody climbs
-- it). The walkway side gets the wide stair: a 6-wide flight up the +X face from the slab (SideFlight), then a
-- 6-wide flight from tier 1's walk to tier 2 by the Kingpin, carpeted all the way; the far side a 4-wide one.
-- Tier 2 rises a step more than tier 1 (4.5: row 2's heads clear row 1's from the walkway camera even where
-- perspective lines a figure up behind one in front); tier 3, which nobody climbs, the rest (2.7).
Evolutions.Tiers = {}
for k, spec in { { 4.0, -26.2, 22.2, { { -26.2, -22.2 } } }, { 8.5, -26.2, 22.2, { { 16.2, 22.2, walkway = true } } }, { 11.2, -21.7, 10.7, {} } } do
	local front = Evolutions.Apron + (k - 1) * Evolutions.Pitch
	Evolutions.Tiers[k] = {
		top = spec[1], front = front, x0 = spec[2], x1 = spec[3], flights = spec[4],
		row = front + Evolutions.Lip + Evolutions.Pad / 2,
	}
end
-- Steps for a climb of h, and the run of that flight.
function Evolutions.steps(h) return math.max(1, math.ceil(h / Evolutions.StepRise - 1e-6)) end
function Evolutions.runFor(h) return Evolutions.steps(h) * Evolutions.Run end
Evolutions.SideFlight = { z0 = 8.4, z1 = 14.4 } -- slab up to tier 1 along its +X face, climbing toward -X
-- One pad colour per tier (height is the rarity on the podium; the rarity band stays on the label outline).
-- `glow` is the Neon inset, about 0.65 of the colour: Neon renders brighter than its Color3 and the full
-- colour burns out to white (judge in Studio with bloom; drop toward 0.55 if the centre clips). `pale` is the
-- pedestal block round it (the reference's lit pale-blue frame), `shade` how far the client pulls a locked
-- figure toward the dark pad colour (gold reads as gold statues at 0.35, sepia at 0.6).
Evolutions.TierColors = {
	{ color = C(0, 190, 255), glow = C(0, 124, 166), pale = C(178, 204, 246), shade = 0.6 },
	{ color = C(150, 70, 255), glow = C(80, 8, 176), pale = C(204, 186, 246), shade = 0.6 },
	{ color = C(255, 180, 0), glow = C(166, 117, 0), pale = C(240, 214, 162), shade = 0.35 },
}
-- Rarity bands (three looks each, the order the overhead tag uses): the outline of the look's name.
Evolutions.Bands = {
	{ name = 'COMMON', color = C(0, 190, 255) },
	{ name = 'UNCOMMON', color = C(40, 230, 90) },
	{ name = 'RARE', color = C(40, 110, 255) },
	{ name = 'EPIC', color = C(170, 60, 255) },
	{ name = 'LEGENDARY', color = C(255, 180, 0) },
}
-- The featured look: its red plinth on tier 2's back corner on the walkway side (where the reference has its
-- featured figure), at the top of the carpeted stair, an upper stage lifting him over the row in front, a red
-- velvet panel in a gold frame behind him.
Evolutions.Featured = 'Kingpin'
Evolutions.FeaturedAt = V(19.2, 0, 27.2)
Evolutions.FeaturedRise = 1.1 -- the upper stage
Evolutions.FeaturedScale = 1.15
Evolutions.Scale = 1.12 -- the other figures: a bit over player size, so they fill their pads like the reference
Evolutions.Colors = {
	top = C(178, 188, 210), cap = C(164, 174, 198), riser = C(104, 120, 152), rim = C(84, 88, 102), steel = C(120, 128, 146),
	kick = C(90, 100, 124), hazard = C(255, 200, 40), ink = C(26, 26, 32), pad = C(232, 236, 244), shutter = C(126, 134, 152),
	slat = C(104, 112, 130), galvanised = C(150, 156, 170), plinth = C(210, 40, 60), rim2 = C(200, 240, 255),
	wing = C(40, 110, 220), wingSlat = C(70, 140, 235), cheek = C(222, 44, 52), yellow = C(255, 200, 40),
	carpet = C(176, 22, 44), gold = C(255, 196, 60), amber = C(255, 170, 80),
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

---------------------------------------------------------------------------------------------- stairs
-- One stair flight climbing toward the frame's +Z, `run` deep, between x0 and x1, from y0 to y1, starting at
-- z0: each step a dark riser under a light studded tread with a yellow nose, so every step reads from afar.
-- carpet = { x0, x1 }: a red runner up the treads (behind the noses).
function Evolutions.flight(c, x0, x1, z0, y0, y1, run, carpet)
	local col = Evolutions.Colors
	local n = Evolutions.steps(y1 - y0)
	local rise, depth = (y1 - y0) / n, run / n
	local f = c:group('Stairs')
	for i = 1, n do
		local z = z0 + (i - 1) * depth
		local top = y0 + i * rise
		f:box('Step', V(x0, y0, z), V(x1, top - 0.16, z + depth), col.rim, M.Plastic)
		studs(f:box('Tread', V(x0, top - 0.16, z), V(x1, top, z + depth), col.top, M.Plastic))
		decor(f:box('StepNose', V(x0, top - 0.2, z - 0.04), V(x1, top + 0.03, z + 0.3), col.yellow, M.SmoothPlastic))
		if carpet then
			decor(f:box('StairCarpet', V(carpet[1], top, z + 0.3), V(carpet[2], top + 0.04, z + depth), col.carpet, M.Fabric))
		end
	end
	return f
end

-- One tier: slate-blue studded body (split round the flights cut into its front), light studded cap with a
-- dark studded band along its open edges (the reference's two-tone rim), a dark band under the lip with a
-- yellow safety line and a warm amber glow under it, diamond-plate kick plates, steel ribs between the pads,
-- and its flights with a red cheek on their inner side.
function Evolutions.tier(p, k, t, below)
	local col = Evolutions.Colors
	local back, run = Evolutions.Back, Evolutions.runFor(t.top - below)
	local tier = p:group('Tier' .. k)
	-- Split x0..x1 at the flights: { x0, x1, flight }.
	local cuts = table.clone(t.flights)
	table.sort(cuts, function(a, b) return a[1] < b[1] end)
	local segs, x = {}, t.x0
	for _, f in cuts do
		if f[1] > x + 0.05 then table.insert(segs, { x, f[1] }) end
		table.insert(segs, { f[1], f[2], flight = f })
		x = f[2]
	end
	if t.x1 > x + 0.05 then table.insert(segs, { x, t.x1 }) end
	for _, s in segs do
		local x0, x1 = s[1], s[2]
		local z0 = s.flight and t.front + run or t.front
		local open0, open1 = math.abs(x0 - t.x0) < 0.05, math.abs(x1 - t.x1) < 0.05
		studs(tier:box('Riser', V(x0, below, z0), V(x1, t.top - 0.3, back), col.riser, M.Plastic), true)
		studs(tier:box('Cap', V(open0 and x0 + 0.55 or x0, t.top - 0.3, z0 + 0.55), V(open1 and x1 - 0.55 or x1, t.top, back), col.top, M.Plastic))
		studs(tier:box('EdgeRim', V(x0 - (open0 and 0.15 or 0), t.top - 0.3, z0 - 0.15), V(x1 + (open1 and 0.15 or 0), t.top, z0 + 0.55), col.rim, M.Plastic))
		for o, open in { [-1] = open0, [1] = open1 } do
			if open then
				local edge = o == 1 and x1 or x0
				local r0, r1 = edge - o * 0.55, edge + o * 0.15
				studs(tier:box('EdgeRim', V(math.min(r0, r1), t.top - 0.3, z0 + 0.55), V(math.max(r0, r1), t.top, back), col.rim, M.Plastic))
				studs(tier:box('SideRim', V(math.min(edge + o * 0.1, edge + o * 0.25), t.top - 0.75, z0), V(math.max(edge + o * 0.1, edge + o * 0.25), t.top - 0.3, back), col.rim, M.Plastic))
				tier:box('SideKick', V(math.min(edge, edge + o * 0.13), below, z0), V(math.max(edge, edge + o * 0.13), below + 0.5, back), col.kick, M.DiamondPlate)
			end
		end
		if s.flight then
			local f = s.flight
			local carpet = f.walkway and { (x0 + x1) / 2 - 1.2, (x0 + x1) / 2 + 1.2 } or nil
			Evolutions.flight(tier, x0, x1, t.front, below, t.top, run, carpet)
			-- (the cheek on the side that faces the tier's front wall)
			for _, cx in { x0, x1 } do
				if math.abs(cx - t.x0) > 0.05 and math.abs(cx - t.x1) > 0.05 then
					tier:box('StairCheek', V(cx - 0.2, below, t.front), V(cx + 0.2, t.top - 0.3, t.front + run), col.cheek, M.SmoothPlastic)
				end
			end
		else
			studs(tier:box('FrontRim', V(x0, t.top - 0.75, t.front - 0.25), V(x1, t.top - 0.3, t.front), col.rim, M.Plastic))
			decor(tier:box('SafetyLine', V(x0, t.top - 0.22, t.front - 0.2), V(x1, t.top - 0.08, t.front - 0.14), col.hazard, M.SmoothPlastic))
			local glow = decor(tier:box('Underglow', V(x0 + 0.2, t.top - 0.92, t.front - 0.2), V(x1 - 0.2, t.top - 0.77, t.front - 0.1), col.amber, M.Neon))
			glow.Transparency, glow.CastShadow = 0.3, false
			tier:box('KickPlate', V(x0, below, t.front - 0.12), V(x1, below + 0.5, t.front), col.kick, M.DiamondPlate)
		end
	end
	-- Steel ribs between the pads (tier 1 carries the sign in the middle instead).
	local cols = Evolutions.Columns[k]
	for i = 1, #cols - 1 do
		local rx = (cols[i] + cols[i + 1]) / 2
		local onFlight = false
		for _, f in t.flights do onFlight = onFlight or (rx > f[1] - 0.5 and rx < f[2] + 0.5) end
		if not (k == 1 and math.abs(rx - Evolutions.Columns[1][3]) < 15) and not onFlight then
			tier:box('Rib', V(rx - 0.3, below + 0.5, t.front - 0.18), V(rx + 0.3, t.top - 0.75, t.front), col.steel, M.Metal)
		end
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
		Evolutions.tier(p, k, t, below)
		below = t.top
	end
	-- The walkway stair: up tier 1's +X face from the slab, 6 wide, carpeted (its frame's +Z points to -X).
	local t1, sf = Evolutions.Tiers[1], Evolutions.SideFlight
	local run = Evolutions.runFor(t1.top - B)
	local w = (sf.z1 - sf.z0) / 2
	local f = p:at(CFrame.new(t1.x1 + run, 0, (sf.z0 + sf.z1) / 2) * CFrame.Angles(0, -math.pi / 2, 0))
	Evolutions.flight(f, -w, w, 0, B, t1.top, run, { -1.2, 1.2 })
	return p
end

---------------------------------------------------------------------------------------------- looks
-- The label over a figure: the name in white outlined in the rarity band's colour, then one yellow line with
-- the power needed and the gain, then the action chip. Lobby.client shows it only near you (and on your next
-- look when you are near it). Beside it, off until the client switches it on for your next look from afar: the
-- NextMarker, a big yellow ▼ (the goal colour, as on the NEXT LOOK board and the floor arrow) whose tip sits
-- just over the figure's hat (tipY), so from a low camera it can't land on the figure behind.
Evolutions.GoalColor = C(255, 214, 40)
Evolutions.MarkSize = 2.2
Evolutions.MarkTip = 0.12 -- the ▼'s tip above the bottom of its box, in box heights (TextYAlignment Bottom)
function Evolutions.label(c, pos, s, band, tipY)
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
	local ms = Evolutions.MarkSize
	mark.Size = UDim2.fromScale(ms, ms)
	mark.StudsOffset = Vector3.new(0, (tipY or pos.Y) - pos.Y + ms * (0.5 - Evolutions.MarkTip), 0)
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
	arrow.TextColor3 = Evolutions.GoalColor
	arrow.TextScaled = true
	arrow.TextYAlignment = Enum.TextYAlignment.Bottom
	arrow.TextStrokeTransparency = 1
	local st = Instance.new('UIStroke')
	st.Color, st.Thickness, st.LineJoinMode = C(0, 0, 0), 3, Enum.LineJoinMode.Round
	st.Parent = arrow
	arrow.Parent = mark
	return anchor
end

-- The stock tag: a yellow NEXT tag on a short string from the stand's front lip (lipY at its top edge,
-- faceZ its front face). Every stand has one, hidden; the client shows it on your next look (it hangs under
-- the figure, so no camera can read it as belonging to another).
function Evolutions.tag(c, x, lipY, faceZ)
	local g, model = c:group('NextTag')
	local w, h = 1.8, 0.85
	local z = faceZ - 0.1
	g:box('TagString', V(x - 0.05, lipY - 0.2, z - 0.05), V(x + 0.05, lipY + 0.02, z + 0.05), C(26, 26, 32), M.SmoothPlastic)
	local t = g:part('Tag', V(w, h, 0.08), CFrame.new(x, lipY - 0.2 - h / 2, z - 0.02) * CFrame.Angles(0, 0, math.rad(-4)), Evolutions.GoalColor, M.SmoothPlastic)
	g:part('TagHole', V(0.16, 0.16, 0.1), CFrame.new(x, lipY - 0.28, z - 0.02), C(26, 26, 32), M.SmoothPlastic)
	local gui = surface(t, Enum.NormalId.Front, 60)
	line(gui, 'Text', 'NEXT', C(20, 20, 26), FONT.loud, 0.16, 0.8, nil)
	gui.Enabled = false
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then decor(d).CastShadow, d.Transparency = false, 1 end
	end
	return model
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

-- Glowing pad, like the reference's: a pedestal block lit in a pale tint of the tier's colour (what you see of
-- the pad at player height), a neon inset over most of its top in the tier's colour with one white rim round
-- it, the glow falling off round it onto the tier (an inner pool and a faint outer one, so stone shows between
-- neighbours), a coloured light above and motes rising off it. `tint` = { color, glow, pale }.
function Evolutions.pad(c, x, y, z, tint, size, clip)
	local col = Evolutions.Colors
	local h, top = size / 2, y + Evolutions.PadH
	c:box('PadBlock', V(x - h, y, z - h), V(x + h, top, z + h), tint.pale or col.pad, M.SmoothPlastic)
	for _, ring in { { 'PadHalo', 0.35, 0.5, 0.05 }, { 'PadHaloOuter', 0.8, 0.82, 0.03 } } do
		local o = ring[2]
		-- (clip: keep the glow off a stair opening that runs up |x| < clip)
		local x0, x1 = x - h - o, x + h + o
		if clip and x > 0 then x0 = math.max(x0, clip) elseif clip then x1 = math.min(x1, -clip) end
		local halo = decor(c:box(ring[1], V(x0, y, z - h - o), V(x1, y + ring[4], z + h + o), tint.glow, M.Neon))
		halo.Transparency, halo.CastShadow = ring[3], false
	end
	local g = h - 0.32
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

-- The featured plinth (the reference's red featured pad), two stages: a red frame with cyan corner lights (its
-- outer part, past tier 2's edge, rises from tier 1's landing as a red tower up the flank), and on it a red
-- upper stage with a cyan inset carrying the turntable and its colour-cycling gold ring; halo, glitter and a
-- ground ring round the figure. Returns the height the figure stands at and the stage top.
function Evolutions.plinth(c, x, y, z, band)
	local red, cyan, gold = Evolutions.Colors.plinth, Evolutions.TierColors[1].glow, band.color
	local h, top = 3, y + 1.6
	local t1, t2 = Evolutions.Tiers[1], Evolutions.Tiers[2]
	-- (where it stands past tier 2's edge it rises from the level below: tier 1, or the slab)
	local foot = x + h <= t2.x1 and y or x + h <= t1.x1 and t1.top or Evolutions.Base
	studs(c:box('PlinthFrame', V(x - h, foot, z - h), V(x + h, top, z + h), red, M.Plastic), true)
	c:box('PlinthLip', V(x - h - 0.1, top - 0.3, z - h - 0.1), V(x + h + 0.1, top, z + h + 0.1), red:Lerp(C(0, 0, 0), 0.25), M.SmoothPlastic)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			decor(c:box('CornerLight', V(x + cx * (h - 0.05) - 0.35, top - 0.85, z + cz * (h - 0.05) - 0.35), V(x + cx * (h - 0.05) + 0.35, top - 0.35, z + cz * (h - 0.05) + 0.35), cyan, M.Neon)).CastShadow = false
		end
	end
	-- The glow round its foot, on each level it stands on.
	for i, g in { { x - h - 0.5, math.min(x + h + 0.5, t2.x1), y }, { math.max(x - h - 0.5, t2.x1), x + h + 0.5, foot } } do
		if g[2] - g[1] > 0.2 and (i == 1 or foot < y) then
			local halo = decor(c:box('PlinthHalo', V(g[1], g[3], z - h - 0.5), V(g[2], g[3] + 0.05, z + h + 0.5), cyan, M.Neon))
			halo.Transparency, halo.CastShadow = 0.4, false
		end
	end
	-- KINGPIN in gold across the frame's front.
	local card = ghost(c:box('PlinthSign', V(x - h + 0.4, top - 1.45, z - h - 0.06), V(x + h - 0.4, top - 0.35, z - h - 0.02), P.white))
	line(surface(card, Enum.NormalId.Front, 40), 'Name', 'KINGPIN', C(255, 206, 60), FONT.loud, 0.02, 0.96, C(110, 16, 30), 3)
	-- The upper stage.
	local sh, stop = 2.3, top + Evolutions.FeaturedRise
	studs(c:box('PlinthStage', V(x - sh, top, z - sh), V(x + sh, stop, z + sh), red, M.Plastic), true)
	c:box('StageLip', V(x - sh - 0.08, stop - 0.25, z - sh - 0.08), V(x + sh + 0.08, stop, z + sh + 0.08), red:Lerp(C(0, 0, 0), 0.25), M.SmoothPlastic)
	c:box('StageTrim', V(x - sh - 0.05, top, z - sh - 0.05), V(x + sh + 0.05, top + 0.18, z + sh + 0.05), C(255, 196, 60), M.SmoothPlastic)
	local inset = decor(c:box('PlinthInset', V(x - sh + 0.45, stop, z - sh + 0.45), V(x + sh - 0.45, stop + 0.06, z + sh - 0.45), cyan, M.Neon))
	inset.CastShadow = false
	top = stop
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
	return feet, top
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
	model:SetAttribute('LockShade', tint.shade or 0.6)
	local feet, lipY, lipHalf
	if featured then
		feet, lipY = Evolutions.plinth(st, x, y, z, band)
		lipHalf = 2.3
	else
		feet = Evolutions.pad(st, x, y, z, tint, Evolutions.Pad, opts.clip)
		lipY, lipHalf = y + Evolutions.PadH, Evolutions.Pad / 2
	end
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
	local hatY = feet + 6.3 * scale
	if art then
		local yaw = math.rad(opts.yaw or 0)
		local poseFn = art.posed or function(parent, cf, look, k) return art.mannequin(parent, cf, look, k) end
		local fig = poseFn(st.parent, st:world(CFrame.new(x, feet, z) * CFrame.Angles(0, yaw, 0)), s, scale, nil)
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
		hatY = hi.Y
	end
	-- A few glints round an unlocked figure (the client switches them off while it is locked).
	local glints = ghost(st:part('UnlockedFx', V(3 * scale, 5 * scale, 1.6 * scale), CFrame.new(x, feet + 2.8 * scale, z), band.color))
	glints.CastShadow = false
	glints:SetAttribute('UnlockedOnly', true)
	Evolutions.emitter(glints, 'Glints', 'glitter', {
		Rate = 1.6, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0), LightEmission = 1, RotSpeed = NumberRange.new(-60, 60),
		Size = Evolutions.seq({ { 0, 0 }, { 0.35, 0.6, 0.15 }, { 1, 0 } }), Color = ColorSequence.new(P.white, tint.color:Lerp(P.white, 0.5)), ZOffset = 1,
	})
	Evolutions.padlock(st, V(x, feet + 0.5, z - lipHalf - 0.1), 0.75)
	if s.Required == 0 then
		for _, d in model.Lock:GetDescendants() do
			if d:IsA('BasePart') then d.Transparency = 1 end
		end
	end
	Evolutions.label(st, V(x, labelY, z), s, band, hatY + 0.3)
	Evolutions.tag(st, x, lipY, z - lipHalf)
	-- Equip point at knee height just in front of the pad (prompt + server distance check).
	local front = z - half - 0.5
	local ix = x
	local fy = opts.floor or y
	ghost(st:box('Interact', V(ix - 0.6, fy + 0.6, front - 0.6), V(ix + 0.6, fy + 1.8, front + 0.6), P.white)).CastShadow = false
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
-- Spotlights clamped under the front edge of the two wing caps (out of every approach), aimed at the two
-- lower rows, each with a soft flare on its lens. targets: { { x = lamp x, at = Vector3 } }.
function Evolutions.lights(c, targets)
	local col = Evolutions.Colors
	local g = c:group('Lights')
	local wingTop = Evolutions.Tiers[2].top + 7.4 + 0.4
	local z = Evolutions.Back - 0.4
	for _, t in targets do
		local lamp = g:group('Spotlight')
		local lx = t.x
		local pos = V(lx, wingTop - 1.1, z - 0.3)
		lamp:box('LampClamp', V(lx - 0.25, wingTop - 0.55, z - 0.35), V(lx + 0.25, wingTop, z + 0.15), col.ink, M.SmoothPlastic)
		lamp:box('LampYoke', V(lx - 0.1, wingTop - 0.95, z - 0.4), V(lx + 0.1, wingTop - 0.55, z - 0.2), col.ink, M.SmoothPlastic)
		local aim = CFrame.lookAt(pos, t.at)
		decor(lamp:part('LampCan', V(0.7, 0.7, 1.0), aim, C(150, 156, 170), M.SmoothPlastic))
		decor(lamp:part('LampBack', V(0.5, 0.5, 0.2), aim * CFrame.new(0, 0, 0.55), C(52, 54, 62), M.SmoothPlastic))
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
	local dust = ghost(g:part('StageDust', V(40, 8, 20), CFrame.new(Evolutions.Columns[1][3], 10, 16), P.white))
	Evolutions.emitter(dust, 'Dust', 'dust', {
		Rate = 6, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6,
		Size = Evolutions.seq({ { 0, 0 }, { 0.3, 0.14, 0.05 }, { 1, 0 } }), Transparency = Evolutions.seq({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 240, 210)),
	})
	return g
end

-- Behind the Kingpin: a red velvet panel in a gold frame standing on his plinth's back edge, gold neon tubes
-- down its sides and a row of gold studs along its foot (a stage set, not a frame round him: nothing crosses
-- over his head; its top stays under his crown).
function Evolutions.kingpinPanel(c, x, z)
	local col = Evolutions.Colors
	local g = c:group('KingpinPanel')
	local y0, y1 = Evolutions.Tiers[2].top + 1.6, 17.5
	local x0, x1, zf = x - 3, x + 3, z + 3 - 0.25
	g:box('Velvet', V(x0, y0, zf), V(x1, y1, zf + 0.2), col.carpet, M.Fabric)
	for _, e in { { V(x0 - 0.3, y0, zf - 0.05), V(x0, y1 + 0.3, zf + 0.25) }, { V(x1, y0, zf - 0.05), V(x1 + 0.3, y1 + 0.3, zf + 0.25) }, { V(x0, y1, zf - 0.05), V(x1, y1 + 0.3, zf + 0.25) } } do
		g:box('PanelFrame', e[1], e[2], col.gold, M.SmoothPlastic)
	end
	for _, tx in { x0 + 0.45, x1 - 0.45 } do
		decor(g:box('PanelTube', V(tx - 0.1, y0 + 0.5, zf - 0.12), V(tx + 0.1, y1 - 0.4, zf - 0.02), col.gold, M.Neon)).CastShadow = false
	end
	for sx = x0 + 1.2, x1 - 1.1, 0.95 do
		decor(g:part('PanelStud', V(0.3, 0.3, 0.3), CFrame.new(sx, y0 + 0.6, zf - 0.12), col.gold, M.Neon, Enum.PartType.Ball)).CastShadow = false
	end
	return g
end

-- The EVOLUTIONS marquee across the front of the first tier: a dark board in a cyan neon frame, yellow
-- letters outlined pink, and a ring of bulbs round it, every other one cycling colour so the frame chases.
function Evolutions.sign(c)
	local g = c:at(CFrame.new(Evolutions.Columns[1][3], 0, 0)):group('Sign')
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

-- Backdrop: a loading-bay wall of roller shutters behind the tiers, tall and light behind the top tier (it backs
-- the figures), lower and blue on the wings (horizontal slats, a dark bottom rail, a galvanised drum housing
-- along the top), galvanised
-- posts with neon edges splitting the middle into three bays behind the top row, DOCK stencils on the
-- wings, neon footlights along the base and colour-cycling up-arrows (evolving = going up) on the far wing.
function Evolutions.backdrop(c)
	local col = Evolutions.Colors
	local d = c:group('Backdrop')
	local z0, z1 = Evolutions.Back, Evolutions.Back + 1.2
	local t1, t2, t3 = Evolutions.Tiers[1], Evolutions.Tiers[2], Evolutions.Tiers[3]
	local wing = t2.top + 7.4
	-- { x0, x1, top, where the tiers in front stop hiding it, blue }: behind the top tier, then the wings out to
	-- the stack's -X edge and, on +X, on behind the Kingpin to the slab's end.
	local panels = { { t3.x0, t3.x1, 19.4, t3.top }, { t1.x0, t3.x0, wing, t2.top, true }, { t3.x1, 26.8, wing, t2.top, true } }
	for _, pnl in panels do
		local x0, x1, top, seen, blue = pnl[1], pnl[2], pnl[3], pnl[4], pnl[5]
		d:box('Shutter', V(x0, Evolutions.Base, z0 + 0.3), V(x1, top - 0.9, z1), blue and col.wing or col.shutter, M.Plastic)
		for y = seen + 0.7, top - 1.3, 0.55 do
			decor(d:box('ShutterSlat', V(x0 + 0.05, y, z0 + 0.18), V(x1 - 0.05, y + 0.16, z0 + 0.3), blue and col.wingSlat or col.slat, M.Plastic)).CastShadow = false
		end
		d:box('ShutterRail', V(x0, seen, z0 + 0.15), V(x1, seen + 0.45, z0 + 0.32), col.rim, M.Plastic)
		d:box('ShutterDrum', V(x0 - 0.1, top - 0.9, z0 - 0.3), V(x1 + 0.1, top, z1 + 0.1), col.galvanised, M.Plastic)
		studs(d:box('WallCap', V(x0 - 0.2, top, z0 - 0.3), V(x1 + 0.2, top + 0.4, z1 + 0.2), col.steel, M.Plastic))
	end
	-- Footlights back-lighting the figures: cyan behind the top tier, violet behind the wings.
	decor(d:box('Footlight', V(t3.x0, t3.top + 0.1, z0 - 0.1), V(t3.x1, t3.top + 0.4, z0 + 0.1), C(80, 220, 255), M.Neon)).CastShadow = false
	for _, w in { { t2.x0, t3.x0 }, { t3.x1, Evolutions.FeaturedAt.X - 3.8 } } do
		decor(d:box('Footlight', V(w[1], t2.top + 0.1, z0 - 0.1), V(w[2], t2.top + 0.4, z0 + 0.1), C(186, 96, 255), M.Neon)).CastShadow = false
	end
	-- Bay posts: between the top-row figures and at the ends of the middle panel.
	local cols = Evolutions.Columns[3]
	for i, x in { (cols[1] + cols[2]) / 2, (cols[3] + cols[4]) / 2, t3.x1 - 0.35, t3.x0 + 0.35 } do
		d:box('BayPost', V(x - 0.35, t3.top, z0 - 0.3), V(x + 0.35, 19.4, z0 + 0.3), col.galvanised, M.Plastic)
		decor(d:box('BayPostNeon', V(x - 0.12, t3.top + 0.5, z0 - 0.36), V(x + 0.12, 18.4, z0 - 0.3), i <= 2 and C(186, 96, 255) or C(80, 220, 255), M.Neon)).CastShadow = false
	end
	-- The DOCK stencil on the far wing.
	local wx = (t1.x0 + t3.x0) / 2
	for _, w in { { wx, t2.top + 0.75, 'DOCK 03', 1.9 } } do
		local card = ghost(d:box('Stencil', V(w[1] - w[4], w[2], z0 - 0.02), V(w[1] + w[4], w[2] + w[4] * 0.64, z0 + 0.1), P.white))
		line(surface(card, Enum.NormalId.Front, 30), 'Text', w[3], C(255, 200, 40), Enum.Font.Oswald, 0, 1, nil)
	end
	local arrows, model = d:group('UpArrows')
	model:SetAttribute('Hue', 12)
	model:AddTag('HoodMotion')
	for i = 0, 2 do
		local y = t2.top + 2.8 + i * 1.5
		local glow = C(255, 192, 44):Lerp(P.white, i * 0.15)
		for _, s in { -1, 1 } do
			local a = V(wx, y + 1.0, z0 - 0.06)
			local b = V(wx + s * 1.8, y, z0 - 0.06)
			local mid = (a + b) / 2
			decor(arrows:part('Chevron', V((b - a).Magnitude + 0.4, 0.45, 0.16), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(b.Y - a.Y, b.X - a.X)), glow, M.Neon)).CastShadow = false
		end
	end
	return d
end

-- One delivery where the walkway sees it: on the slab behind the walkway stair, against tier 1's +X face, a
-- pallet of kraft boxes under shrink-wrap with a NEW STOCK tag, the yellow jack still under it.
function Evolutions.props(c)
	local pr = c:group('Props')
	local t1, sf = Evolutions.Tiers[1], Evolutions.SideFlight
	local px = t1.x1 + 2.6
	local pal = pr:at(CFrame.new(px, Evolutions.Base, sf.z1 + 3.2) * CFrame.Angles(0, math.rad(-96), 0))
	for _, bx in { -1, 0, 1 } do pal:box('PalletBlock', V(bx - 0.15, 0, -1.2), V(bx + 0.15, 0.35, 1.2), C(120, 86, 52), M.Wood) end
	for pz = -1, 1, 0.5 do pal:box('PalletSlat', V(-1.2, 0.35, pz - 0.2), V(1.2, 0.5, pz + 0.2), C(150, 110, 70), M.WoodPlanks) end
	for _, b in { { -0.55, -0.5, 1.1 }, { 0.55, -0.45, 1.0 }, { 0, 0.55, 1.2 } } do
		pal:box('KraftBox', V(b[1] - 0.55, 0.5, b[2] - 0.5), V(b[1] + 0.55, 0.5 + b[3], b[2] + 0.5), C(196, 160, 110), M.Cardboard)
		decor(pal:box('BoxTape', V(b[1] - 0.56, 0.5 + b[3] - 0.02, b[2] - 0.08), V(b[1] + 0.56, 0.5 + b[3] + 0.01, b[2] + 0.08), C(170, 130, 80), M.SmoothPlastic))
	end
	local wrap = decor(pal:box('ShrinkWrap', V(-1.15, 0.5, -1.1), V(1.15, 1.85, 1.15), P.white, M.SmoothPlastic))
	wrap.Transparency, wrap.CastShadow = 0.6, false
	local tag = pal:box('StockTag', V(-0.5, 1.0, -1.18), V(0.5, 1.45, -1.13), C(255, 200, 40), M.SmoothPlastic)
	line(surface(tag, Enum.NormalId.Front, 60), 'Text', 'NEW STOCK', C(26, 26, 32), FONT.loud, 0.1, 0.8, nil)
	-- The jack: forks between the pallet's blocks, body and handle out in front.
	local yellow = C(255, 200, 40)
	for _, jx in { -0.45, 0.45 } do pal:box('JackFork', V(jx - 0.2, 0.05, -1.0), V(jx + 0.2, 0.3, 1.1), yellow, M.SmoothPlastic) end
	pal:box('JackBody', V(-0.75, 0.05, -1.75), V(0.75, 0.9, -1.2), yellow, M.SmoothPlastic)
	pal:part('JackWheel', V(0.3, 0.5, 0.5), CFrame.new(0, 0.25, -1.5), C(40, 40, 48), M.SmoothPlastic, Enum.PartType.Cylinder)
	pal:bar('JackHandle', V(0, 0.9, -1.5), V(0, 2.7, -1.95), 0.14, C(40, 40, 48), M.SmoothPlastic)
	pal:box('JackGrip', V(-0.4, 2.65, -2.05), V(0.4, 2.85, -1.85), C(40, 40, 48), M.SmoothPlastic)
	return pr
end

-- The WARDROBE, standing on the walkway side's front corner of the apron (the first thing you reach from the
-- walkway): a chrome garment rack of suit bags in the tiers' colours on a low dark base, a full-length mirror
-- ringed with bulbs, a lightbox sign over them (WARDROBE in 1.3-stud letters, CHANGE YOUR LOOK under it), and a
-- gold ring on the floor in front with the WardrobePoint over it: Lobby.client's one big prompt (it opens the
-- EVOLVE board; the server equips any unlocked look within 30 studs of it). Kept low enough that the walkway's
-- sight lines to row 1 pass over the sign.
-- The Kingpin's carpet: a red runner with gold edges from the slab edge up the walkway stair, across tier 1's
-- walk and up the tier-2 flight to his plinth (the stair steps carry their own pieces).
function Evolutions.apron(c)
	local col = Evolutions.Colors
	local a = c:group('Wardrobe')
	local B = Evolutions.Base
	local t1, t2, sf = Evolutions.Tiers[1], Evolutions.Tiers[2], Evolutions.SideFlight
	local x0, x1 = t1.x1 + 0.9, 27.0 -- 22.6 .. 27.0
	local zr = 5.9 -- the rack's line
	local chrome, ink = C(214, 220, 230), C(28, 26, 44)
	a:box('WardrobeBase', V(x0, B, zr - 0.8), V(x1, B + 0.3, zr + 0.8), ink, M.SmoothPlastic)
	-- Rack: two posts, a top bar, four suit bags on hangers.
	for _, px in { x0 + 0.4, x1 - 0.4 } do
		a:box('RackPost', V(px - 0.1, B + 0.3, zr - 0.1), V(px + 0.1, B + 4.6, zr + 0.1), chrome, M.SmoothPlastic)
	end
	a:box('RackBar', V(x0 + 0.3, B + 4.4, zr - 0.08), V(x1 - 0.3, B + 4.56, zr + 0.08), chrome, M.SmoothPlastic)
	local bags = { Evolutions.TierColors[1].color, Evolutions.TierColors[2].color, Evolutions.TierColors[3].color, col.plinth }
	local span = (x1 - x0 - 1.4) / #bags
	for i, bc in bags do
		local bx = x0 + 0.7 + (i - 0.5) * span
		a:box('Hanger', V(bx - 0.04, B + 4.1, zr - 0.04), V(bx + 0.04, B + 4.45, zr + 0.04), chrome, M.SmoothPlastic)
		a:box('SuitBag', V(bx - 0.45, B + 1.5, zr - 0.2), V(bx + 0.45, B + 4.1, zr + 0.2), bc, M.Fabric)
		a:box('Lapel', V(bx - 0.18, B + 3.2, zr - 0.24), V(bx + 0.18, B + 4.05, zr - 0.2), P.white, M.SmoothPlastic)
	end
	-- Mirror at the rack's inner end, turned a little toward the front.
	local m = a:at(CFrame.new(x0 - 0.2, B, zr - 1.4) * CFrame.Angles(0, math.rad(-25), 0))
	m:box('MirrorFrame', V(-0.75, 0, -0.12), V(0.75, 4.6, 0.12), col.gold, M.SmoothPlastic)
	local glass = m:box('MirrorGlass', V(-0.55, 0.25, -0.18), V(0.55, 4.35, -0.12), C(196, 226, 246), M.Glass)
	glass.Reflectance, glass.Transparency = 0.35, 0.1
	for _, y in { 0.8, 1.9, 3.0, 4.1 } do
		for _, bx in { -0.62, 0.62 } do decor(m:part('MirrorBulb', V(0.24, 0.24, 0.24), CFrame.new(bx, y, -0.2), C(255, 236, 190), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	end
	-- The lightbox on two legs behind the rack.
	local sy0, sy1 = B + 4.8, B + 6.8
	for _, px in { x0 + 0.6, x1 - 0.6 } do a:box('SignLeg', V(px - 0.1, B + 0.3, zr + 0.45), V(px + 0.1, sy0, zr + 0.65), ink, M.SmoothPlastic) end
	local board = a:box('WardrobeSign', V(x0 - 0.2, sy0, zr + 0.4), V(x1 + 0.1, sy1, zr + 0.7), ink, M.SmoothPlastic)
	local g = surface(board, Enum.NormalId.Front, 40)
	line(g, 'Title', 'WARDROBE', Evolutions.GoalColor, Enum.Font.Oswald, 0.02, 0.68, C(90, 40, 0), 3)
	line(g, 'Sub', 'CHANGE YOUR LOOK', P.white, FONT.loud, 0.7, 0.24, C(20, 20, 40), 2)
	for _, y in { sy0 - 0.1, sy1 } do decor(a:box('SignTube', V(x0 - 0.3, y, zr + 0.32), V(x1 + 0.2, y + 0.1, zr + 0.42), C(255, 90, 200), M.Neon)).CastShadow = false end
	light(board, C(255, 210, 120), 0.8, 9)
	-- The ring and the prompt point in front.
	local px, pz = (x0 + x1) / 2, 2.6
	decor(a:part('PromptRing', V(0.1, 3.2, 3.2), CFrame.new(px, B + 0.06, pz) * CFrame.Angles(0, 0, math.pi / 2), Evolutions.GoalColor, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	a:part('PromptDisc', V(0.14, 2.7, 2.7), CFrame.new(px, B + 0.08, pz) * CFrame.Angles(0, 0, math.pi / 2), C(40, 40, 52), M.SmoothPlastic, Enum.PartType.Cylinder)
	local point = ghost(a:part('WardrobePoint', V(1.2, 1.2, 1.2), CFrame.new(px, B + 1.6, pz), P.white))
	point.CastShadow = false
	-- Carpet: slab edge to the stair's foot, tier 1's walk to the tier-2 flight, tier 2 to the plinth.
	local zc = (sf.z0 + sf.z1) / 2
	local fl = t2.flights[1]
	local cx = (fl[1] + fl[2]) / 2
	local run, run2 = Evolutions.runFor(t1.top - B), Evolutions.runFor(t2.top - t1.top)
	local f = Evolutions.FeaturedAt
	local runs = {
		{ V(t1.x1 + run, B, zc - 1.2), V(27.1, B + 0.05, zc + 1.2) },
		{ V(cx - 1.2, t1.top, zc - 1.2), V(t1.x1, t1.top + 0.05, zc + 1.2) },
		{ V(cx - 1.2, t1.top, zc + 1.2), V(cx + 1.2, t1.top + 0.05, t2.front) },
		{ V(cx - 1.2, t2.top, t2.front + run2), V(cx + 1.2, t2.top + 0.05, f.Z - 3.5) },
	}
	for _, r in runs do
		decor(a:box('Carpet', r[1], r[2], col.carpet, M.Fabric))
	end
	return a, point
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
	local _, wardrobe = Evolutions.apron(e)
	local m, morphs = e:group('Morphs')
	-- The stand is small and every client needs all of it (prompts, labels, the guide arrow).
	pcall(function() morphs.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	wardrobe.Parent = model -- (beside Morphs: the server and the client find it by name)
	local wobble = { -5, 3, -2, 4, -4 }
	local placed = { 0, 0, 0 }
	for _, s in skins.List do
		if s.Id == Evolutions.Featured then
			local at = Evolutions.FeaturedAt
			Evolutions.look(m, s, art, at.X, Evolutions.Tiers[2].top, at.Z, { featured = true, column = 1 })
			Evolutions.kingpinPanel(e, at.X, at.Z)
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
				})
				if row == 3 then Evolutions.sparkle(m:into(stand), cols[column], feet, t.row, Evolutions.TierColors[3].color) end
			end
		end
	end
	-- The built state is a new player's view (Lobby.client takes over at once): no full labels, the marker
	-- and the NEXT tag on the first look to unlock.
	local goal = skins.nextSkin and skins.nextSkin(0)
	for _, stand in morphs:GetChildren() do
		local isGoal = goal ~= nil and stand.Name == 'Skin_' .. goal.Id
		local anchor = stand:FindFirstChild('LabelAnchor')
		if anchor then
			anchor.WorldLabel.Enabled = false
			anchor.NextMarker.Enabled = isGoal
		end
		local tag = stand:FindFirstChild('NextTag')
		for _, d in (tag and isGoal and tag:GetDescendants() or {}) do
			if d:IsA('BasePart') then d.Transparency = 0 elseif d:IsA('SurfaceGui') then d.Enabled = true end
		end
	end
	-- Spotlights from the wing caps on the two lower rows: the -X wing lights the far half, the +X wing (between
	-- the top tier and the Kingpin's panel) the walkway half.
	local t1, t2, t3 = Evolutions.Tiers[1], Evolutions.Tiers[2], Evolutions.Tiers[3]
	local chest = Evolutions.PadH + 3 * Evolutions.Scale
	local c1, c2 = Evolutions.Columns[1], Evolutions.Columns[2]
	Evolutions.lights(e, {
		{ x = t3.x1 + 0.9, at = V((c1[1] + c1[2]) / 2, t1.top + chest, t1.row) },
		{ x = t3.x1 + 2.4, at = V(c2[2], t2.top + chest, t2.row) },
		{ x = t1.x0 + 0.8, at = V((c1[4] + c1[5]) / 2, t1.top + chest, t1.row) },
		{ x = t3.x0 - 0.9, at = V(c2[4], t2.top + chest, t2.row) },
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
-- World 1's spawn: the BLOCK RANGE, an old warehouse at the south end of the street, painted bright: sky-
-- blue corrugated walls on red steel columns, white trusses with yellow chords under a glass-and-white roof,
-- gym-turf yards, pallet racks and containers round the edges, and a raised studded deck in a cross: the big
-- north door (out to Stage 1) down to the ARMORY platform, the spawn badge where it crosses the training
-- aisle. West: the training platform (two bands of four shooting ranges facing a red runner, the cardio corner
-- with three treadmills on a raised bump at the west end). East: the EVOLUTIONS podium. By the door: reward
-- crates. South-west: the WORLD 2 garage and a practice lane, south-east: the gold KINGPIN statue and three
-- leaderboards. Murals on the walls, marquee bulbs round the club signs, a giant gold deagle over the ridge.
-- Kid-friendly: every target is a bullseye, bottle, can or plate, never a person.
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
-- Training: two bands of four long shooting ranges (9 x 20 slots, 10.5 apart) facing each other across the
-- aisle, as in the reference: looking down the aisle from the spawn, the left (south) band runs Starter..Heavy
-- and the right (north) band Gold..Speed, gold nearest the spawn. Treadmills 8.5 apart on the cardio bump at the aisle's west end, belts facing the
-- west wall.
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
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
	-- Columns on the side walls (and two wind columns on each end wall), yellow feet.
	local function column(f, u)
		s:box('Column', f(u - 0.8, 0, 0), f(u + 0.8, H + 0.6, 1.2), K.column, M.SmoothPlastic)
		s:box('ColumnFoot', f(u - 1.0, 0, 0), f(u + 1.0, 2.6, 1.4), K.hazard, M.SmoothPlastic)
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
		decor(d:part('DoorHazard', V(1.2, 0.1, 3.2), CFrame.new(x, 0.05, N - 2.4) * CFrame.Angles(0, math.rad(35), 0), K.hazard, M.SmoothPlastic))
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
-- neon ring. The spawn faces 25° west of north, so the first frame is the north range band and the door.
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
	-- Ranges: Starter..Heavy on the south band (z 81, facing north, no turn), Gold..Speed on the north band
	-- (z 39, turned round to face south); both fronts face the aisle.
	for i, id in Lobby.Ranges do
		local north = i > 4
		local x = Lobby.RowX[north and 9 - i or i]
		local cf = CFrame.new(x, D, Lobby.RowZ[north and 1 or 2]) * (north and CFrame.Angles(0, math.pi, 0) or CFrame.new())
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Range_' .. id, cf, { X = 9, Y = 12, Z0 = -10, Z1 = 10 }, string.upper(s and s.Name or id), C(90, 200, 120),
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

-- The training aisle, floor paint 0.12 thick (thinner paint flickers at distance): a 4-stud checker in two
-- pale blues with a 2-stud dark rail along both range bands and across the spawn end (a T where the aisle meets
-- the crossing), the red AIM runner with gold borders down the middle, two painted bullseyes on it.
-- The runner stops 4 studs short of the cardio steps, where the range officer stands.
function Lobby.aisle(L)
	local K, D = Lobby.Colors, Lobby.Deck
	local a = L:group('TrainingAisle')
	local cz = Lobby.CrossZ
	local x0, x1 = -48.5, -8 -- checker and runner run x0..x1; the rail T fills x1..-6
	local z0, z1 = cz - 5, cz + 5 -- the runner
	local rail = C(90, 100, 125)
	local function paint(name, a0, b0, color, mat, h)
		local p = a:box(name, V(a0.X, D, a0.Z), V(b0.X, D + (h or 0.12), b0.Z), color, mat or M.SmoothPlastic)
		p.CastShadow = false
		return p
	end
	-- Rails: along both band fronts and down the spawn end (either side of the runner).
	paint('AisleRail', V(x0, 0, cz - 11), V(-6, 0, cz - 9), rail)
	paint('AisleRail', V(x0, 0, cz + 9), V(-6, 0, cz + 11), rail)
	paint('AisleRail', V(x1, 0, cz - 9), V(-6, 0, z0), rail)
	paint('AisleRail', V(x1, 0, z1), V(-6, 0, cz + 9), rail)
	-- Checker: one row of 4-stud tiles each side of the runner.
	local k = 0
	for x = x0, x1 - 0.01, 4 do
		local xe = math.min(x + 4, x1)
		for j, zz in { { cz - 9, z0 }, { z1, cz + 9 } } do
			paint('AisleTile', V(x, 0, zz[1]), V(xe, 0, zz[2]), (k + j) % 2 == 0 and C(225, 228, 238) or C(197, 210, 230))
		end
		k += 1
	end
	paint('AisleTile', V(x0, 0, z0), V(-44.5, 0, z1), C(225, 228, 238)) -- where the range officer stands
	-- The runner and its borders (borders 0.04 proud), the word and the painted bullseyes on top.
	paint('Runner', V(-44.5, 0, z0), V(x1, 0, z1), C(232, 60, 68), M.Fabric)
	for _, z in { z0, z1 - 0.7 } do paint('RunnerBorder', V(-44.5, 0, z), V(x1, 0, z + 0.7), K.gold, nil, 0.16) end
	local word = ghost(a:box('RunnerWord', V(-34, D + 0.13, z0 + 1), V(-18, D + 0.15, z1 - 1), P.white))
	line(surface(word, Enum.NormalId.Top, 10), 'Text', 'AIM  •  +1', C(255, 230, 230), FONT.loud, 0.1, 0.8)
	-- Painted bullseyes: white, red and gold rings stacked 0.04 apart.
	for _, x in { -40, -12 } do
		for j, e in { { 8.2, P.white }, { 6.2, K.blue }, { 4.2, P.white }, { 2.2, K.gold } } do
			local y = D + 0.12 + (j - 1) * 0.04
			decor(a:part('BullseyePaint', V(0.04, e[1], e[1]), CFrame.new(x, y + 0.02, cz) * CFrame.Angles(0, 0, math.pi / 2), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		end
	end
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
	h:part('FanGuard', V(0.3, 5.4, 0.2), cf * CFrame.new(0, 0, -0.5), K.hazard, M.SmoothPlastic)
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
-- Hanging steel target on a wall bracket: a round plate painted as a bullseye, swinging on two chains
-- (HoodMotion Bob), as if it had just been hit.
function Lobby.wallTarget(c, pos)
	local K = Lobby.Colors
	local g = c:group('WallTarget')
	g:box('TargetBracket', V(-Lobby.W, pos.Y + 7.6, pos.Z - 1.6), V(pos.X + 0.3, pos.Y + 8.2, pos.Z + 1.6), K.red, M.SmoothPlastic)
	g:box('TargetBrace', V(-Lobby.W, pos.Y + 5.4, pos.Z - 0.25), V(-Lobby.W + 0.5, pos.Y + 8.2, pos.Z + 0.25), K.red, M.SmoothPlastic)
	local b, plate = g:group('Plate')
	for _, dz in { -1.2, 1.2 } do b:box('TargetChain', pos + V(-0.08, 4.4, dz - 0.08), pos + V(0.08, 7.6, dz + 0.08), K.steel, M.SmoothPlastic) end
	local face = CFrame.new(pos + V(0, 2.6, 0)) * CFrame.Angles(0, 0, 0)
	for j, e in { { 4.4, K.steel }, { 3.6, K.red }, { 2.4, P.white }, { 1.2, K.red } } do
		b:part('TargetRing', V(0.3 + j * 0.05, e[1], e[1]), face * CFrame.new(j * 0.03, 0, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	return Lobby.motion(plate, CFrame.new(pos + V(0, 4, 0)), nil, 0.3, 1.3)
end

---------------------------------------------------------------------------------------------- set pieces
-- Reward crates by the door: a red DAILY crate (north-west), the LUCKY SHOT target and the VIP safe (north-
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
	LuckyShot = CFrame.new(17, 0, 17),
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
	billboard(r, V(0, 13 * k, 0), 7, 2.2, { { 'Title', 'DAILY CRATE', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 45
	Lobby.fx(Lobby.emitBox(r, 'CrateFx', V(-4, 2, -3) * k, V(4, 7.5, 3) * k), 'CrateGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.9 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 120)), LightEmission = 1 })
	Lobby.pillar(r, V(0, 9.2 * k, 0), 12, C(255, 210, 80))
	-- LUCKY SHOT (x1.8): a gold-rimmed bullseye turning on a blue-and-gold stand, a gold star in the middle.
	k = 1.8
	local g = L:at(Lobby.RewardAt.LuckyShot):group('LuckyShot')
	Lobby.rewardBase(g, 6 * k, 6 * k, C(250, 196, 40), k)
	local function Pt(c, name, rad, h, y, color) return c:post(name, rad * k, h * k, V(0, y * k, 0), color, M.SmoothPlastic) end
	Pt(g, 'StandBase', 2.1, 1.2, 1.2, Lobby.Colors.blue)
	Pt(g, 'StandBand', 1.8, 0.5, 2.4, gold)
	Pt(g, 'StandNeck', 0.5, 2.6, 2.9, Lobby.Colors.blue)
	local tg, target = g:group('Target')
	-- (cylinders lie along X, so the disc faces the walkway (-X) and shows its face and edge in turn)
	for j, e in { { 6.4, gold }, { 5.4, Lobby.Colors.red }, { 4, P.white }, { 2.6, Lobby.Colors.red } } do
		tg:part('TargetRing', V(0.4 + j * 0.08, e[1], e[1]) * k, CFrame.new(0, 8.6 * k, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for a = 0, 1 do
		tg:part('TargetStar', V(0.9, 1.3, 1.3) * k, CFrame.new(0, 8.6 * k, 0) * CFrame.Angles(math.pi / 4 * a, 0, 0), C(255, 236, 140), M.Neon)
	end
	Lobby.motion(target, Lobby.RewardAt.LuckyShot * CFrame.new(0, 8.6 * k, 0), 30, 0.4)
	Lobby.prompt(ghost(g:box('TargetHit', V(-2, 1.2, -2) * k, V(2, 5, 2) * k, P.white)), 'Spin', 'Lucky Shot')
	billboard(g, V(0, 13 * k, 0), 6, 2, { { 'Title', 'LUCKY SHOT', C(255, 220, 80), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 45
	local glow = Lobby.emitBox(g, 'TargetFx', V(-2, 6, -2) * k, V(2, 11, 2) * k)
	Lobby.fx(glow, 'TargetGlitter', 'glitter', { Rate = 10, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.5, 2),
		Size = Lobby.seq({ { 0, 0.5 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 220, 90)), LightEmission = 1 })
	light(glow, C(255, 210, 90), 1.2, 16)
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
	billboard(v, V(0, 11.5 * k, 0), 6, 2, { { 'Title', 'VIP SAFE', C(225, 160, 255), FONT.loud, 0, 0.6 }, { 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.4 } }).WorldLabel.MaxDistance = 45
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
	front.Transparency, front.CastShadow = 0.55, false
	light(front, cyan, 3, 28)
	-- The vortex: three glowing discs, darker at the rim and bright in the core, each 0.1 in front of the last,
	-- and six bent arms turning in front of them.
	local hub = CFrame.new(V(0, 4.6, -0.6) * k)
	for j, e in { { 8.4, purple }, { 5.6, cyan }, { 3, C(255, 80, 200) } } do
		decor(p:part('PortalDisc', V(0.08, e[1] * k, e[1] * k), hub * CFrame.new(0, 0, -(j - 1) * 0.1 * k) * CFrame.Angles(0, math.pi / 2, 0), e[2], M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
	local sw, swirl = p:group('PortalSwirl')
	local front0 = hub * CFrame.new(0, 0, -0.4 * k)
	for j = 0, 5 do
		local color = j % 2 == 0 and C(200, 140, 255) or C(255, 120, 220)
		local arm = front0 * CFrame.Angles(0, 0, j * math.pi / 3)
		decor(sw:part('SwirlArm', V(1.1, 2.2, 0.12) * k, arm * CFrame.new(0, 1.5 * k, 0), color, M.Neon)).CastShadow = false
		decor(sw:part('SwirlArm', V(1.1, 2.0, 0.12) * k, arm * CFrame.new(0, 2.5 * k, 0) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0, 1.0 * k, 0), color, M.Neon)).CastShadow = false
	end
	decor(sw:part('SwirlEye', V(1.6, 1.6, 0.14) * k, front0, P.white, M.Neon)).CastShadow = false
	Lobby.motion(swirl, cf * front0 * CFrame.Angles(-math.pi / 2, 0, 0), 120)
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

-- People in the range are SkinArt figures (Art.posed). Poses in SkinArt.Poses' shape: {out, forward} per limb
-- (forward = toward the figure's front).
Lobby.Poses = {
	-- Two-handed aim straight ahead: the right arm level, the left arm crossing in under it.
	aim = { LeftArm = { -22, 84 }, RightArm = { -4, 90 }, LeftLeg = { 5, 10 }, RightLeg = { 5, -8 } },
	-- The kingpin: a gold pistol raised high (the near arm, tilted toward the walkway), the other hand on the hip.
	kingpin = { LeftArm = { 160, 25 }, RightArm = { 26, -8 }, LeftLeg = { 6, 0 }, RightLeg = { 6, 0 } },
}
function Lobby.figure(parent, cf, skin, scale, pose)
	local ok, Art = pcall(function() return require(ReplicatedStorage.Shared.SkinArt) end)
	if not ok or type(Art) ~= 'table' or not Art.posed then return nil end
	local built, fig = pcall(Art.posed, parent, cf, skin, scale, pose)
	if not built or not fig then return nil end
	return fig
end
-- A small block pistol in a figure's hand, the muzzle along the arm (cheap: grip, slide, barrel).
function Lobby.handGun(fig, arm, scale, color)
	local a = fig:FindFirstChild(arm)
	if not a then return end
	local hand = a.CFrame * CFrame.new(0, -1.05 * scale, 0)
	for _, e in { { 'GunGrip', V(0.3, 0.6, 0.3), CFrame.new(0, 0, 0.15) }, { 'GunSlide', V(0.32, 0.3, 1.1), CFrame.new(0, -0.35, -0.3) * CFrame.Angles(math.pi / 2, 0, 0) } } do
		local q = Lobby.worldPart(fig, e[1], e[2] * scale, hand * CFrame.new(e[3].Position * scale) * (e[3] - e[3].Position), color)
		q.CanCollide, q.CanQuery, q.CanTouch = false, false, false
	end
end

-- The KINGPIN: a giant gold figure (SkinArt's top look: crown, suit, chain) holding a gold deagle high, on a
-- plinth (red base, white top, gold trim) with a cyan uplight. Two-tone gold (suit and a pale
-- shirt, tie and lapels) with a dark face so the eyes and shades read. Falls back to a block figure without
-- SkinArt.
function Lobby.statue(L, cf, skins)
	local K = Lobby.Colors
	local s, model = L:at(cf):group('KingpinStatue')
	local head, suit, pale, ink = C(255, 200, 50), C(240, 170, 30), C(255, 232, 150), C(90, 50, 10)
	Lobby.slab(s, 'Plinth', V(-7, 0, -7), V(7, 1.6, 7), K.red)
	decor(s:box('PlinthTrim', V(-7.1, 1.4, -7.1), V(7.1, 1.8, 7.1), K.gold, M.SmoothPlastic))
	Lobby.slab(s, 'PlinthTop', V(-6, 0, -6), V(6, 3.6, 6), C(245, 245, 245))
	for _, e in { { -6.1, 6.1, -6.2, -6.05 }, { -6.1, 6.1, 6.05, 6.2 }, { -6.2, -6.05, -6.1, 6.1 }, { 6.05, 6.2, -6.1, 6.1 } } do
		decor(s:box('PlinthGlow', V(e[1], 3.3, e[3]), V(e[2], 3.6, e[4]), K.cool, M.Neon)).CastShadow = false
	end
	local plaque = s:box('Plaque', V(-4.2, 1.9, -6.2), V(4.2, 3.2, -6.05), K.gold, M.SmoothPlastic)
	line(surface(plaque, Enum.NormalId.Front, 30), 'Text', 'THE KINGPIN', K.red, FONT.loud, 0.1, 0.8, P.white, 2)
	local top, scale = 3.6, 4.5
	local base = V2.Origin * s.cf * CFrame.new(0, top, 0)
	local kingpin = skins.ById.Kingpin or skins.List[#skins.List]
	local fig = Lobby.figure(model, base, kingpin, scale, Lobby.Poses.kingpin)
	if fig then
		fig.Name = 'KingpinFigure'
		local paleParts = { DressShirt = true, TailoredLapel = true, Tie = true, TieKnot = true, ShirtCuff = true }
		local face = { EyeWhite = true, Iris = true, Pupil = true, EyeGlint = true, Eyebrow = true, Eyelid = true, Nose = true, Smile = true, SmileTeeth = true,
			Mouth = true, Moustache = true, Beard = true, SunglassesFrame = true, SunglassesLens = true, LensReflection = true, GlassesBridge = true, RoundSpectacleRim = true }
		for _, d in fig:GetDescendants() do
			if d:IsA('BasePart') then
				d.Material = M.SmoothPlastic
				d.Color = face[d.Name] and ink or paleParts[d.Name] and pale or d.Name == 'Head' and head or suit
				d.CastShadow = true
			elseif d:IsA('Decal') then
				d.Color3 = ink
			end
		end
		-- The gold deagle (GunModels) in the raised hand, muzzle up along the arm.
		local arm = fig:FindFirstChild('LeftArm')
		local okGun, Guns = pcall(function() return require(ReplicatedStorage.Shared.Models.GunModels) end)
		if arm and okGun and Guns and Guns.build then
			local okBuild, gun = pcall(Guns.build, 'Deagle', scale)
			if okBuild and gun then
				gun.Name = 'GoldDeagle'
				gun:PivotTo(arm.CFrame * CFrame.new(0, -1.05 * scale, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
				gun.Parent = model
			end
		elseif arm then
			Lobby.handGun(fig, 'LeftArm', scale, K.gold)
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
		b('Crown', -2.2, 20.4, -2.2, 2.2, 22, 2.2, K.gold)
	end
	-- Cyan uplight and glints.
	local lamp = Lobby.emitBox(s, 'StatueFx', V(-6, 6, -3), V(6, 28, 3))
	light(lamp, K.cool, 1.6, 26)
	Lobby.fx(lamp, 'StatueGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 0.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 1.1 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 240, 200)), LightEmission = 1 })
	return s
end

-- People: two regulars on the practice lane in the south-west yard (aiming at bottles, cans and a bullseye
-- board on a plank fence), the range officer in a hi-vis vest and ear defenders at the runner's west end, and
-- a kid hanging out by the Daily Crate, waving at the spawn.
function Lobby.people(L, skins)
	local K = Lobby.Colors
	local g, model = L:group('People')
	local function person(name, skinId, color, pos, look, pose, bob, period)
		local base = skins.ById[skinId] or skins.List[1]
		local skin = table.clone(base)
		skin.Id = name
		if color then skin.Color = color end
		local frame = CFrame.lookAt(pos, look)
		local fig = Lobby.figure(model, V2.Origin * frame, skin, 1.1, pose)
		if fig and bob then Lobby.motion(fig, frame, nil, bob, period or 2) end
		return fig
	end
	-- The practice lane: a counter, the shooters behind it, a plank fence with bottles and cans and a bullseye
	-- board 14 studs down-range. All targets are things, never people.
	local lx, z0, z1 = -42.5, 125, 141
	Lobby.slab(g, 'LaneCounter', V(lx - 1, 0.12, z0), V(lx + 0.2, 3.2, z1), C(150, 96, 52))
	g:box('LaneCounterTop', V(lx - 1.3, 3.2, z0 - 0.3), V(lx + 0.5, 3.6, z1 + 0.3), K.gold, M.SmoothPlastic)
	local fx = -55
	for _, z in { 126.5, 134, 141.5 } do g:box('FencePost', V(fx - 0.3, 0.12, z - 0.3), V(fx + 0.3, 4.2, z + 0.3), C(150, 96, 52), M.Wood) end
	g:box('FenceRail', V(fx - 0.6, 3.6, 126), V(fx + 0.6, 4, 142), C(196, 128, 68), M.WoodPlanks)
	local cols = { C(60, 200, 90), C(80, 170, 255), C(255, 190, 40), C(222, 44, 52) }
	for k2, z in { 127.5, 129.5, 131.5, 136.5, 138.5, 140.5 } do
		if k2 % 2 == 1 then
			g:post('Bottle', 0.35, 1.3, V(fx, 4, z), cols[k2 % 4 + 1], M.Glass)
		else
			g:post('Can', 0.4, 0.8, V(fx, 4, z), cols[k2 % 4 + 1], M.SmoothPlastic)
		end
	end
	local board = CFrame.new(fx - 1.5, 6.2, 134)
	for j, e in { { 6, P.white }, { 4.6, K.red }, { 3.2, P.white }, { 1.8, K.red } } do
		g:part('BoardRing', V(0.3 + j * 0.06, e[1], e[1]), board * CFrame.new(j * 0.03, 0, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	g:box('BoardLeg', V(fx - 1.9, 0.12, 133.7), V(fx - 1.3, 4, 134.3), C(150, 96, 52), M.Wood)
	for _, z in { 129, 138 } do
		local fig = person('Shooter' .. z, z == 129 and 'Hustler' or 'GetawayDriver', nil, V(lx + 2.2, 0.12, z), V(fx, 0.12, z), Lobby.Poses.aim)
		if fig then Lobby.handGun(fig, 'RightArm', 1.1, C(60, 64, 76)) end
	end
	-- The range officer: hi-vis orange with ear defenders, pointing down the aisle at the targets.
	local D = Lobby.Deck
	local officer = person('RangeOfficer', 'Enforcer', C(255, 150, 30), V(-46.5, D, Lobby.CrossZ), V(0, D, Lobby.CrossZ), 'point', 0.12, 2.4)
	if officer then
		local head = officer:FindFirstChild('Head')
		if head then
			for _, sx in { -1, 1 } do
				Lobby.worldPart(officer, 'EarCup', V(0.35, 0.8, 0.8) * 1.1, head.CFrame * CFrame.new(sx * 0.82 * 1.1, 0, 0), C(40, 110, 220)).CanCollide = false
			end
			Lobby.worldPart(officer, 'EarBand', V(1.9, 0.18, 0.3) * 1.1, head.CFrame * CFrame.new(0, 0.82 * 1.1, 0), C(40, 110, 220)).CanCollide = false
		end
	end
	-- A kid hanging out by the Daily Crate, waving at the spawn.
	person('Waver', 'CornerKid', C(40, 180, 90), V(-12, 0.12, 21), V(0, 0.12, 60), 'wave', 0.15, 1.6)
	return g
end

-- Leaderboard (about 19 x 22): posts and frame in the board's accent, a gold cap trim, a navy screen with
-- a header. `live` names the model LobbyService writes into (a TextLabel named TextLabel): ServerLeaderboard
-- (top Power, with a bobbing gold crown) or CashLeaderboard. Without it the board shows a season teaser.
function Lobby.leaderboard(L, cf, title, accent, live)
	local K = Lobby.Colors
	local b, model = L:at(cf):group(live or 'Leaderboard')
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
		local t = line(g, 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, FONT.body, 0.05, 0.9, P.black, 1)
		t.TextYAlignment = Enum.TextYAlignment.Top
	else
		-- Not wired yet: a season teaser instead of empty rows.
		line(g, 'Crowns', '👑 👑 👑 👑 👑', K.gold, FONT.loud, 0.1, 0.22, P.black, 1)
		line(g, 'Rows', 'SEASON 1', K.gold, FONT.loud, 0.38, 0.24, P.black, 2)
		line(g, 'Soon', 'TOP 5 SOON', P.white, FONT.loud, 0.66, 0.2, P.black, 2)
	end
	decor(b:box('BoardGlow', V(-7.2, 2.8, -0.76), V(7.2, 3.1, -0.6), accent:Lerp(P.white, 0.3), M.Neon)).CastShadow = false
	if live == 'ServerLeaderboard' then
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
	local n = math.floor((b - a).Magnitude / 3.6)
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
		decor(t:box('TurfLine', V(x0 + 0.5, 0.12, z - 0.2), V(x1 - 0.5, 0.18, z + 0.2), P.white, M.SmoothPlastic)).CastShadow = false
		n += 1
		if numbers then
			local label = ghost(t:box('TurfNumber', V(x0 + 1.5, 0.19, z + 0.6), V(x0 + 5.5, 0.21, z + 3.6), P.white))
			line(surface(label, Enum.NormalId.Top, 20), 'Number', tostring(n * 10), P.white, FONT.loud, 0.05, 0.9)
		end
	end
	return t
end

---------------------------------------------------------------------------------------------- murals
-- Three painted murals: ARMORY with crossed pistols behind the armory, TOP OF THE BLOCK with a crown behind
-- the leaderboards, a giant BULLSEYE! target with a white burst by the WORLD 2 garage.
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
	-- BULLSEYE (west wall): a white burst behind a big painted target, gold BULLSEYE! across the top.
	local pw = Lobby.onWall(V(-W + 0.45, 14, 101.5), V(1, 0, 0))
	local burst = decor(dr:part('MuralBurst', V(13, 13, 0.1), pw * CFrame.new(0, 0, -0.05), C(245, 245, 245), M.SmoothPlastic))
	decor(dr:part('MuralBurst', V(13, 13, 0.1), pw * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, math.pi / 4), C(245, 245, 245), M.SmoothPlastic))
	line(surface(burst, Enum.NormalId.Front, 16), 'Hit', 'BULLSEYE!', K.gold, FONT.loud, 0.0, 0.2, K.red, 4)
	for j, e in { { 9, K.red }, { 7, P.white }, { 5, K.red }, { 3, P.white }, { 1.4, K.gold } } do
		decor(dr:part('MuralRing', V(0.1, e[1], e[1]), pw * CFrame.new(0, -0.8, -0.12 - j * 0.05) * CFrame.Angles(0, math.pi / 2, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end

---------------------------------------------------------------------------------------------- dressing
-- Signs, posters, racks, containers, clutter, lamps, fans, particles: the life.
function Lobby.dressing(L)
	local K, W, N, S, D = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.Deck
	local dr = L:group('Dressing')
	local inN, inS, inW, inE = V(0, 0, 1), V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0)
	-- The club name over the door inside and out (marquee bulbs round both), the exit and training signs.
	local clubIn = Lobby.onWall(V(0, 26, N + 0.5), inN)
	Lobby.neonSign(dr, clubIn, 30, 6.4, 'BLOCK RANGE', K.pink, 'EST. 1987  •  EVERY SHOT +1')
	Lobby.marquee(dr, clubIn, 30, 6.4, 3.6)
	local clubOut = Lobby.onWall(V(0, 31.6, N - 1.5), -inN)
	Lobby.neonSign(dr, clubOut, 30, 5.4, 'BLOCK RANGE', K.pink)
	Lobby.marquee(dr, clubOut, 30, 5.4, 3.6)
	Lobby.poster(dr, Lobby.onWall(V(-24, 12, N - 1.45), -inN), 7, 9, C(250, 204, 48), { { 'SHOOT', P.black, FONT.loud, 0.06, 0.24, P.white }, { 'HERE', C(214, 40, 40), FONT.loud, 0.3, 0.24, P.white }, { 'x2 POWER\nFREE RANGE', P.black, FONT.title, 0.6, 0.3 } })
	Lobby.poster(dr, Lobby.onWall(V(24, 12, N - 1.45), -inN), 7, 9, C(214, 40, 40), { { 'TARGET', P.white, FONT.loud, 0.06, 0.24 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.3, 0.24 }, { 'EVERY\nSATURDAY', P.white, FONT.title, 0.6, 0.3 } })
	Lobby.neonSign(dr, Lobby.onWall(V(0, 21.3, N + 2.6), inN), 12, 1.8, 'EXIT  •  STAGE 1', C(80, 255, 120))
	-- The CARDIO sign's bottom clears the tallest treadmill label (top ~16.1) by a stud; TRAINING sits above it.
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 22.9, 60), inW), 26, 5.2, 'TRAINING', K.warm, 'HIT THE TARGETS  •  RUN THE BELTS')
	Lobby.neonSign(dr, Lobby.onWall(V(-W + 1.5, 18.6, 60), inW), 12, 2.6, 'CARDIO', K.lime)
	-- Mirror wall behind the treadmills.
	local mirror = dr:box('Mirror', V(-W, 3, 47), V(-W + 0.35, 10, 73), C(200, 226, 240), M.Glass)
	mirror.Reflectance = 0.35
	dr:box('MirrorFrame', V(-W, 2.6, 46.6), V(-W + 0.3, 10.4, 73.4), K.frame, M.SmoothPlastic)
	-- Posters: target nights, range rules, motivation; slightly crooked, taped.
	local posters = {
		{ V(-40, 11, N + 0.45), inN, 5, 7, C(214, 40, 40), { { 'SHARP', P.white, FONT.loud, 0.04, 0.2 }, { 'SHOOTER', C(255, 220, 60), FONT.loud, 0.24, 0.2 }, { 'CUP\n10 LANES\nBIG PRIZES', P.white, FONT.title, 0.48, 0.36 }, { 'SAT 9PM', C(255, 220, 60), FONT.body, 0.86, 0.1 } } },
		{ V(-47, 11, N + 0.45), inN, 4.4, 6, C(250, 204, 48), { { 'AIM\nHIGH', P.black, FONT.loud, 0.08, 0.5, P.white }, { 'EVERY SHOT\n+1 POWER', C(160, 30, 30), FONT.title, 0.62, 0.3, P.white } } },
		{ V(40, 11, N + 0.45), inN, 5, 7, C(40, 80, 200), { { 'WANTED', P.white, FONT.loud, 0.04, 0.2 }, { 'THE\nKINGPIN', C(255, 220, 60), FONT.loud, 0.3, 0.4 }, { 'REWARD 💪 50K', P.white, FONT.body, 0.8, 0.12 } } },
		{ V(47.5, 10, N + 0.45), inN, 4, 5, P.white, { { 'EARS\n& EYES', C(200, 30, 30), FONT.loud, 0.1, 0.55 }, { 'safety first!', P.black, FONT.tag, 0.7, 0.2 } } },
		{ V(-36, 11, S - 0.45), inS, 5, 6.5, C(130, 50, 200), { { 'WORLD 2', P.white, FONT.loud, 0.05, 0.22 }, { 'COMING\nSOON', C(140, 230, 255), FONT.loud, 0.35, 0.4 }, { '???', P.white, FONT.title, 0.8, 0.14 } } },
		{ V(-20, 11, S - 0.45), inS, 5, 7, C(120, 40, 160), { { 'GOLD', C(255, 204, 48), FONT.loud, 0.06, 0.2 }, { 'TARGET', C(255, 204, 48), FONT.loud, 0.26, 0.2 }, { 'TOURNAMENT', P.white, FONT.title, 0.52, 0.14 }, { 'SIGN UP INSIDE', C(255, 190, 230), FONT.body, 0.76, 0.12 } } },
		{ V(20, 11, S - 0.45), inS, 4.6, 6, C(60, 180, 90), { { 'GUNS\nIN\nSTOCK', P.white, FONT.loud, 0.08, 0.66 }, { '→ ARMORY', C(255, 240, 120), FONT.title, 0.78, 0.16 } } },
	}
	for k, p in posters do
		local cf = Lobby.onWall(p[1], p[2]) * CFrame.Angles(0, 0, math.rad((k % 3 - 1) * 3))
		Lobby.poster(dr, cf, p[3], p[4], p[5], p[6])
	end
	-- The range scoreboard on the north wall, west of the door.
	Lobby.board(dr, 'Scoreboard', Lobby.onWall(V(-23, 15, N + 0.6), inN), 12, 6, C(24, 36, 84), {
		{ 'Round', 'LANE 3', C(255, 220, 60), FONT.loud, 0.04, 0.26, P.black },
		{ 'Score', 'BEST  9,850 PTS', C(255, 90, 90), FONT.loud, 0.34, 0.34, P.black },
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
	local tags = { 'HOOD', 'BLOCK RANGE', 'ON THE BLOCK', 'BULLSEYE' }
	Lobby.container(dr, CFrame.new(-55, 0, N + 4.4) * CFrame.Angles(0, math.pi / 2, 0), Lobby.Colors.containerRed, tags[1], C(255, 220, 60), 'Left')
	Lobby.container(dr, CFrame.new(-53.5, 8.6, N + 4.6) * CFrame.Angles(0, math.pi / 2 + 0.04, 0), Lobby.Colors.containerBlue)
	Lobby.rack(dr, CFrame.new(-W + 4.4, 0, N + 9) * CFrame.Angles(0, -math.pi / 2, 0), 2, 11)
	Lobby.rack(dr, CFrame.new(56, 0, N + 4.4) * CFrame.Angles(0, math.pi, 0), 2, 12)
	Lobby.container(dr, CFrame.new(W - 4.2, 0, 20), C(60, 150, 90), tags[3], P.white, 'Left')
	Lobby.container(dr, CFrame.new(W - 4.4, 8.6, 19.2) * CFrame.Angles(0, -0.05, 0), C(240, 160, 40))
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
		decor(dr:box('BayPaint', V(e[1], 0, e[3]), V(e[2], 0.1, e[4]), K.hazard, M.SmoothPlastic)).CastShadow = false
	end
	-- Story props: vending machine by the door, a bench with a towel and a gym bag, a coffee cup steaming on a
	-- crate, a broom, a steel target swinging on a wall bracket by the cardio corner.
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
	Lobby.wallTarget(dr, V(-63.4, 0.4, 33.5))
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
	dr:box('WarmupMat', V(8, D, 30.2), V(64, D + 0.12, 42.6), C(40, 130, 230), M.Fabric).CastShadow = false
	for x = 15, 57, 7 do decor(dr:box('WarmupLine', V(x - 0.2, D + 0.12, 30.6), V(x + 0.2, D + 0.16, 42.2), P.white, M.SmoothPlastic)).CastShadow = false end
	-- Round the armory: the lobby's deck margin in red rubber with a gold edge.
	for _, e in { { V(-29.2, D, 117.8), V(-24.2, D + 0.05, 146.2) }, { V(24.2, D, 117.8), V(29.2, D + 0.05, 146.2) }, { V(-24.2, D, 141.2), V(24.2, D + 0.05, 146.2) } } do
		dr:box('ArmoryMargin', e[1], e[2] + V(0, 0.07, 0), C(190, 40, 60), M.Fabric).CastShadow = false
	end
	-- Walk of fame on the podium apron: a purple carpet with a gold edge and five gold stars.
	dr:box('FameCarpet', V(12, D, 77.5), V(60, D + 0.12, 88), C(150, 60, 220), M.Fabric).CastShadow = false
	for _, e in { { V(12, D, 77.5), V(60, D + 0.16, 78.1) }, { V(12, D, 87.4), V(60, D + 0.16, 88) }, { V(12, D, 77.5), V(12.6, D + 0.16, 88) }, { V(59.4, D, 77.5), V(60, D + 0.16, 88) } } do
		decor(dr:box('FameEdge', e[1], e[2], K.gold, M.SmoothPlastic)).CastShadow = false
	end
	for x = 18, 54, 9 do
		for j = 0, 1 do decor(dr:part('FameStar', V(3, 0.08, 3), CFrame.new(x, D + 0.16, 82.75) * CFrame.Angles(0, math.pi / 8 + j * math.pi / 4, 0), K.gold, M.SmoothPlastic)).CastShadow = false end
	end
	-- The armory's red runner starts here, where the walkway meets its platform.
	dr:box('ArmoryRunner', V(-5, D, 117), V(5, D + 0.12, 121.2), C(222, 44, 52), M.Fabric).CastShadow = false
	for _, x in { -5.4, 5 } do decor(dr:box('ArmoryRunnerEdge', V(x, D, 117), V(x + 0.4, D + 0.16, 121.2), K.gold, M.SmoothPlastic)).CastShadow = false end
	Lobby.searchlight(dr, V(9.5, D, 89), math.rad(-30), 28)
	Lobby.searchlight(dr, V(62.5, D, 89), math.rad(30), -28)
	-- Taped X marks and seams across the walkway.
	for _, e in { { 30, 28 }, { -16, 94 } } do
		for _, a in { 45, -45 } do decor(dr:part('TapeX', V(0.5, 0.1, 3), CFrame.new(e[1], 0.05, e[2]) * CFrame.Angles(0, math.rad(a), 0), K.hazard, M.SmoothPlastic)).CastShadow = false end
	end
	-- Wayfinding down the walkway: a blue centre lane with gold chevrons, pointing to the street door north of
	-- the badge and to the armory south of it.
	for _, seg in { { 9, 44.5, -1 }, { 67, 116.5, 1 } } do
		decor(dr:box('WalkLane', V(-1.4, D, seg[1]), V(1.4, D + 0.12, seg[2]), K.blue, M.SmoothPlastic)).CastShadow = false
		for z = seg[1] + 4, seg[2] - 2, 8 do
			for _, sx in { -1, 1 } do
				local tip = V(0, D + 0.15, z + seg[3] * 0.9)
				local tail = V(sx * 1.1, D + 0.15, z - seg[3] * 0.4)
				decor(dr:part('WalkChevron', V(0.5, 0.06, (tip - tail).Magnitude + 0.3), CFrame.lookAt((tip + tail) / 2, tip), K.gold, M.SmoothPlastic)).CastShadow = false
			end
		end
	end
	-- Bunting over the training aisle and the podium apron, cloth banners on the walls.
	local flags = { C(222, 44, 52), C(255, 204, 48), C(40, 110, 220), P.white }
	for _, z in { 55, 65 } do Lobby.bunting(dr, V(-48, 25.5, z), V(-7, 25.5, z), 2.6, flags) end
	for _, z in { 81, 87 } do Lobby.bunting(dr, V(7, 25.5, z), V(64, 25.5, z), 3.2, { C(80, 220, 255), P.white, C(180, 100, 255), C(255, 204, 48) }) end
	-- Over the south-west yard (the practice lane and the WORLD 2 garage).
	Lobby.bunting(dr, V(-64, 25.5, 111), V(-7, 25.5, 111), 3, { C(255, 204, 48), C(222, 44, 52), P.white, C(40, 110, 220) })
	for _, e in { { V(W - 0.5, 15, 81), inE, C(222, 44, 52), 'AIM' }, { V(-27, 20, S - 0.5), inS, C(222, 44, 52), 'HOOD' }, { V(27, 20, S - 0.5), inS, C(255, 204, 48), 'RANGE' } } do
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
	-- The landmark from the street: a giant gold deagle (GunModels) turning slowly over the north gable; a giant
	-- bullseye if the gun models aren't there.
	local gp = V(0, 45.6, N - 0.5)
	local okGun, Guns = pcall(function() return require(ReplicatedStorage.Shared.Models.GunModels) end)
	local landmark
	if okGun and Guns and Guns.build and Guns.Meta and Guns.Meta.Deagle then
		local scale = 5
		local okBuild, gun = pcall(Guns.build, 'Deagle', scale)
		if okBuild and gun then
			gun.Name = 'RoofDeagle'
			-- Side on to the street (it turns in game; this is how it rests before the client spins it).
			gun:PivotTo(V2.Origin * CFrame.new(gp) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-Guns.Meta.Deagle.Center * scale))
			gun.Parent = dr.parent
			landmark = gun
		end
	end
	if not landmark then
		local bg, target = dr:group('RoofBullseye')
		for j, e in { { 11, K.red }, { 8, P.white }, { 5, K.red }, { 2, K.gold } } do
			bg:part('RoofRing', V(0.8 + j * 0.1, e[1], e[1]), CFrame.new(gp) * CFrame.Angles(0, math.pi / 2, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
		end
		landmark = target
	end
	Lobby.motion(landmark, CFrame.new(gp), 20, 0.6, 3)
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
	for k, e in { { V(46, 0, 101), V(14, 0, 110), 'TOP CASH', C(44, 170, 80), 'CashLeaderboard' }, { V(57, 0, 114), V(18, 0, 116), 'TOP REBIRTHS', C(132, 62, 212) }, { V(47, 0, 129), V(12, 0, 122), 'TOP POWER', C(222, 52, 52), 'ServerLeaderboard' } } do
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
	-- Stage 1's barrier fills the warehouse door, so it is fainter; the client keeps each gate's own base.
	barrier.Transparency = i == 1 and 0.8 or 0.62
	barrier:SetAttribute('BaseTransparency', barrier.Transparency)
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
