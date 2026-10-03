-- The Block V2: "+1 Hood Evolution", World 1, built from the team's concept sheet (hoodw1), stretched so every
-- look on the sheet is three full stages:
--   spawn plaza (blue spawn circle, TRAIN HERE bar with three bags, the EVOLVE booth)
--   stages 1-3 The Block (red brick), 4-6 Shop Street (barber, grocery and more shops), 7-9 The Courts,
--   10-12 The Apartments (tan, balconies), 13-15 The Yards (warehouses, containers)
--   the boss yard (Champ Ring, the BOSS pad)
-- Every stage starts with a gate that needs more power than the last (V2.StagePower), and a stronger
-- training bag waits every two stages from stage 6. Buildings stand shoulder to shoulder down both sides,
-- fronts to the middle; a ring road with trees and parked cars runs round the outside.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on and applies
-- the Front-page Day lighting (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). Each stage's pad is tagged HoodFightPad
-- (Fight = stage, 16 = the boss) for the fight system to come; the EVOLVE booth is tagged HoodEvolve and its
-- EvolvePoint is where looks are equipped. Training bars hold the nine Training_<Id> stations.
--
-- Layout (local studs, floor top at y = 0, players walk toward -Z):
--   spawn plaza   x -40..40, z 76..0
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
local SPAWN_W, SPAWN_TOP = 40, 76 -- spawn plaza x -40..40, z 0..76
local BOSS_TOP = -STAGES * SLEN -- -960
local BOSS_END = BOSS_TOP - 96 -- the boss yard runs to -1056
local SPAWN = V(0, 0, 40)
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end -- 1..5: three stages share a look
local function trioOf(i) return (i - 1) % 3 + 1 end -- 1..3: place within the look
local function gateZ(i) return stageTop(i) end -- gate i opens stage i (16 opens the boss yard)
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each stage, and into the boss yard (16). Each step is a bit harder than the last, and
-- the next training bag waits in stages 6, 8, 10, 12 and 14 (the Champ Ring in the boss yard), usable the
-- moment you can get in.
local STAGE_POWER = { 10, 30, 60, 150, 300, 500, 750, 1000, 1800, 3000, 5000, 8000, 12500, 20000, 32000, 50000 }
local ROUTE_TRAINING = { [6] = 'Heavy', [8] = 'Speed', [10] = 'DoubleEnd', [12] = 'Pro', [14] = 'Gold' }
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop
V2.RouteTraining = ROUTE_TRAINING

-- Every stage's pad in walking order, then the boss: the fight system can read them straight from here.
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
table.insert(V2.Fights, { Fight = 16, Stage = 16, Look = 6, X = 0, Z = BOSS_END + 22, Boss = true })
-- TRAIN HERE bags at the spawn: station id, bag colour, offset along the bar.
-- (Offsets run along the bar's own X axis, which points west when the bar faces the spawn: red reads left.)
V2.TrainHere = { { Id = 'Starter', Color = C(226, 52, 48), Offset = 5 }, { Id = 'Tape', Color = C(40, 100, 226), Offset = 0 }, { Id = 'Street', Color = C(250, 204, 40), Offset = -5 } }
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
---------------------------------------------------------------------------------------------- ground
-- Light grey paving in 8-stud slabs over the whole walk, a darker cross-street band at every district
-- line, grass behind the buildings, the low boundary wall and the ring road with its cars and trees.
local function invisibleWall(c, a, b)
	local w = c:box('Boundary', a, b, P.white, M.SmoothPlastic)
	w.Transparency = 1
	w.CastShadow = false
	return w
end
local function buildGround(ctx)
	local g = ctx:group('Ground')
	-- Paving: the spawn plaza is wider than the stages.
	local function pave(x0, x1, z0, z1)
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - z0) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-SPAWN_W, SPAWN_W, 0, SPAWN_TOP)
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
	-- Grass behind the buildings and round the spawn plaza, inside the low boundary wall.
	local zIn0, zIn1 = BOSS_END - 6, SPAWN_TOP + 6
	for _, s in { -1, 1 } do
		g:box('Grass', V(s * (FRONT + DEPTH), -1, BOSS_END), V(s * WALL_X, 0.4, 0), P.grass, M.Grass)
		g:box('Grass', V(s * SPAWN_W, -1, 0), V(s * WALL_X, 0.4, SPAWN_TOP), P.grass, M.Grass)
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
	-- Keep players on the walk where no building closes it.
	for _, s in { -1, 1 } do
		invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 30, SPAWN_TOP))
		invisibleWall(g, V(s * FRONT, 0, 0), V(s * SPAWN_W, 30, 1))
	end
	invisibleWall(g, V(-SPAWN_W, 0, SPAWN_TOP), V(SPAWN_W, 30, SPAWN_TOP + 1))
	invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
	return g
end

---------------------------------------------------------------------------------------------- spawn plaza
-- Training bar: two dark posts, a beam with a blue sign, bags on chains. Each bag is a training station
-- (Training_<Id> with its mat in front, its sign and its punch point). The spawn's TRAIN HERE bar holds the
-- Tire, Duct Tape and Street bags (red, blue, yellow); single-bag bars along the route hold the rest.
-- Front (the mats) faces -Z in its frame.
local function trainingBar(ctx, skins, bags, title, half)
	half = half or 9
	local t = ctx:group('TrainHere')
	for _, x in { -half, half } do
		t:box('GantryPost', V(x - 0.8, 0, -0.8), V(x + 0.8, 14, 0.8), C(56, 60, 70), M.Metal)
		t:box('GantryFoot', V(x - 1.3, 0, -1.3), V(x + 1.3, 0.8, 1.3), C(40, 42, 50), M.Metal)
	end
	t:box('GantryBeam', V(-half - 1.4, 14, -0.8), V(half + 1.4, 15.4, 0.8), C(56, 60, 70), M.Metal)
	local sw = math.max(5.5, half - 1.5)
	local sign = t:box('TrainSign', V(-sw, 15.6, -0.4), V(sw, 19.2, 0.4), C(40, 82, 196), M.SmoothPlastic)
	decor(t:box('TrainSignBorder', V(-sw - 0.3, 15.4, -0.3), V(sw + 0.3, 19.4, 0.3), P.white, M.SmoothPlastic))
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do line(surface(sign, face, 20), 'Text', title, P.white, FONT.loud, 0.14, 0.72, C(16, 30, 80), 3) end
	for _, b in bags do
		local s = skins.StationById[b.Id]
		local st, model = t:group('Training_' .. b.Id)
		local eq = st:group('Equipment')
		local x = b.Offset
		eq:box('Chain', V(x - 0.12, 9.6, -0.12), V(x + 0.12, 14, 0.12), C(80, 84, 92), M.Metal)
		eq:post('BagCap', 1.0, 0.5, V(x, 9.1, 0), b.Color:Lerp(P.black, 0.35), M.SmoothPlastic)
		eq:post('Bag', 1.35, 5, V(x, 4.1, 0), b.Color, M.SmoothPlastic)
		eq:post('BagBottom', 1.1, 0.5, V(x, 3.6, 0), b.Color:Lerp(P.black, 0.35), M.SmoothPlastic)
		local zone = st:box('TrainingZone', V(x - 2.3, 0, -6), V(x + 2.3, 0.06, -0.2), P.white, M.SmoothPlastic)
		zone.Transparency, zone.CanCollide, zone.CastShadow = 1, false, false
		local label = billboard(st, V(x, 2.2, -3.2), 4.6, 1.5, {
			{ 'Title', 'x' .. s.Multiplier .. ' POWER', P.white, FONT.loud, 0, 0.55 },
			{ 'Detail', s.Required == 0 and 'FREE' or compact(s.Required) .. ' POWER', P.white, FONT.title, 0.57, 0.4 },
		})
		label.Name = 'Sign'
		label.WorldLabel.MaxDistance = 40
		model:SetAttribute('Tier', s.Multiplier)
		model:SetAttribute('HitPoint', st:world(CFrame.new(x, 6.6, 0)).Position)
		model:SetAttribute('HitColor', b.Color)
	end
	return t
end
-- EVOLVE booth: a blue kiosk with a yellow-framed sign, a glowing doorway with a big white arrow, poster
-- panels either side and a floating arrow on the roof. Front faces -Z in its frame.
local function evolveBooth(ctx)
	local e, model = ctx:group('Evolve')
	local w, h, d = 18, 15, 10
	e:box('BoothBody', V(-w / 2, -0.5, 0), V(w / 2, h, d), P.evolveBlue, M.SmoothPlastic)
	e:box('BoothRoof', V(-w / 2 - 0.5, h, -0.5), V(w / 2 + 0.5, h + 0.8, d + 0.5), P.evolveBlue:Lerp(P.black, 0.3), M.SmoothPlastic)
	e:box('BoothStep', V(-6, 0, -2.6), V(6, 0.5, 0), C(170, 172, 180), M.Concrete)
	e:box('BoothStep', V(-6, 0.5, -1.3), V(6, 1, 0), C(170, 172, 180), M.Concrete)
	e:box('SignFrame', V(-w / 2 - 0.4, h - 4.4, -0.8), V(w / 2 + 0.4, h + 0.4, 0.2), P.evolveYellow, M.SmoothPlastic)
	local sign = e:box('EvolveSign', V(-w / 2 + 0.4, h - 3.8, -1), V(w / 2 - 0.4, h - 0.2, 0), P.evolveBlue, M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Front, 20), 'Text', 'EVOLVE', P.evolveYellow, FONT.loud, 0.1, 0.8, C(20, 30, 70), 4)
	e:box('DoorFrame', V(-5, 1, -0.6), V(5, 10.4, 0), P.evolveBlue:Lerp(P.black, 0.35), M.SmoothPlastic)
	local glow = decor(e:box('DoorGlow', V(-4.2, 1, -0.7), V(4.2, 9.8, -0.5), C(70, 170, 255), M.Neon))
	light(glow, C(90, 180, 255), 2, 18)
	-- The arrow: a shaft and a head, white neon on the door.
	decor(e:box('ArrowShaft', V(-1, 2.4, -0.8), V(1, 6.2, -0.7), P.white, M.Neon))
	decor(e:wedge('ArrowHead', V(0.1, 3, 2.6), CFrame.new(-1.3, 7.5, -0.75) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0), P.white, M.Neon))
	decor(e:wedge('ArrowHead', V(0.1, 3, 2.6), CFrame.new(1.3, 7.5, -0.75) * CFrame.Angles(0, -math.pi / 2, 0), P.white, M.Neon))
	for _, x in { -7.2, 7.2 } do
		e:box('PosterPanel', V(x - 1.6, 1.6, -0.5), V(x + 1.6, 9.4, 0), P.evolveBlue:Lerp(P.black, 0.25), M.SmoothPlastic)
		local poster = decor(e:box('Poster', V(x - 1.3, 2.2, -0.6), V(x + 1.3, 8.8, -0.5), C(236, 240, 250), M.SmoothPlastic))
		line(surface(poster, Enum.NormalId.Front, 30), 'Text', 'EVOLVE\n+1\nPOWER', C(40, 88, 210), FONT.loud, 0.12, 0.76)
	end
	-- Floating arrow over the roof, bobbing.
	local a, arrowModel = e:group('RoofArrow')
	a:box('ArrowShaft', V(-1.2, h + 2.2, d / 2 - 0.6), V(1.2, h + 5, d / 2 + 0.6), C(60, 150, 255), M.Neon)
	a:wedge('ArrowHead', V(1.2, 3, 3), CFrame.new(-1.5, h + 6.5, d / 2) * CFrame.Angles(0, math.pi / 2, 0), C(60, 150, 255), M.Neon)
	a:wedge('ArrowHead', V(1.2, 3, 3), CFrame.new(1.5, h + 6.5, d / 2) * CFrame.Angles(0, -math.pi / 2, 0), C(60, 150, 255), M.Neon)
	arrowModel:SetAttribute('Bob', 0.8)
	arrowModel:SetAttribute('Spin', 40)
	arrowModel:AddTag('HoodMotion')
	arrowModel.WorldPivot = e:world(CFrame.new(0, h + 4.5, d / 2))
	-- Where you stand to evolve (LobbyService checks the distance to this point).
	ghost(e:box('EvolvePoint', V(-2, 0, -4), V(2, 0.2, -2), P.white))
	model:AddTag('HoodEvolve')
	return e
end
local function buildSpawn(ctx, skins)
	local sp = ctx:group('SpawnPlaza')
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
	spawn.Parent = sp.parent
	-- The blue spawn circle and its floating label.
	decor(sp:part('SpawnRing', V(0.12, 15, 15), CFrame.new(SPAWN + V(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2), P.spawnBlue, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	decor(sp:part('SpawnDisc', V(0.16, 12, 12), CFrame.new(SPAWN + V(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(110, 206, 255), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	billboard(sp, SPAWN + V(0, 9, 0), 9, 2.4, { { 'Title', 'SPAWN', P.white, FONT.loud, 0, 1 } }).WorldLabel.MaxDistance = 120
	trainingBar(sp:at(CFrame.lookAt(V(-22, 0, 38), V(-18, 0, 80))), skins, V2.TrainHere, 'TRAIN HERE', 9)
	evolveBooth(sp:at(CFrame.lookAt(V(24, 0, 34), V(16, 0, 76))))
	-- South edge: planters with hedges, benches looking north, lamps.
	for _, s in { -1, 1 } do
		hedge(sp, s * 34, s * 12, 70, 1.8)
		bench(sp, V(s * 20, 0, 64), V(0, 0, -1))
		bench(sp, V(s * 30, 0, 64), V(0, 0, -1))
		lantern(sp, V(s * 10, 0, 60))
		tree(sp, V(s * 35, 0, 58), 300 + s, 1)
		tree(sp, V(s * 35, 0, 16), 310 + s, 1)
		-- North edge: hedge planters either side of the way into stage 1.
		hedge(sp, s * 34, s * 14, 8, 1.8)
		lantern(sp, V(s * 10, 0, 12))
	end
	railing(sp, V(-31, 0, 18), V(-13, 0, 18), 3.2)
	-- Back to where you got to, for returning players.
	teleportPad(sp, 'FurthestPad', 0, 22, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
	trashCan(sp, V(34, 0, 32))
	trashCan(sp, V(34, 0, 36))
	tree(sp, V(-36, 0, 26), 321, 1.05)
	return sp
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
	local station = ROUTE_TRAINING[i]
	if station then
		local s = SKINS.StationById[station]
		local bar = d:at(CFrame.lookAt(V(-25, 0, top - 46), V(0, 0, top - 46)))
		trainingBar(bar, SKINS, { { Id = station, Color = s.Color, Offset = 0 } }, 'TRAIN x' .. s.Multiplier, 5)
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
	Props.ring(b:at(CFrame.new(0, 0, BOSS_TOP - 34) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id), PROPS_KIT, ring, 7)
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
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 fifteen stages 1')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN)
	root:SetAttribute('MorphStand', false) -- evolving happens at the EVOLVE booth, not on a stand
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
