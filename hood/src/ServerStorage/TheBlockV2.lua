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
-- the bright, slightly softened lighting (HoodLighting HoodSoft) (both reversible: SetActive(false), HoodLighting.Restore()).
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

-- Palette, taken from the concept: bold, simple, one look per district. The same hues as ever, a notch
-- quieter (Brief 8): big surfaces (walls, ground, courts) at HSV S <= 0.45, objects (pads, boards, props) at
-- S <= 0.7; small accents may stay bright.
local P = {
	-- Ground.
	tileA = C(206, 208, 213), tileB = C(193, 196, 202), band = C(146, 149, 156), bandLine = C(236, 236, 238),
	kerb = C(222, 222, 226), wall = C(214, 214, 218), grass = C(122, 172, 96), asphalt = C(70, 72, 78), roadLine = C(240, 240, 240),
	court = C(214, 166, 130), courtKey = C(190, 120, 90), courtLine = C(250, 246, 236),
	-- Buildings.
	brick = C(176, 108, 98), brickDark = C(148, 90, 82), brickPink = C(200, 130, 114), slate = C(62, 68, 84), stone = C(158, 158, 164),
	tan = C(222, 188, 138), tanLight = C(238, 212, 168), tanDark = C(176, 150, 116),
	glass = C(54, 72, 102), frame = C(214, 214, 220), door = C(52, 120, 86), doorDark = C(48, 52, 62),
	barberBlue = C(62, 92, 168), groceryGreen = C(100, 154, 104), groceryYellow = C(238, 214, 148), shopBlue = C(100, 130, 182),
	warehouse = C(100, 130, 182), warehouseDark = C(56, 80, 136), rollDoor = C(72, 76, 84),
	-- Props.
	leaf = C(112, 178, 80), leafDark = C(94, 160, 68), hedge = C(86, 152, 72), trunk = C(122, 82, 52), planter = C(196, 196, 202),
	iron = C(36, 38, 44), lampGlow = C(255, 220, 140), wood = C(186, 134, 90), woodDark = C(142, 100, 68), crate = C(198, 152, 98),
	dumpster = C(66, 134, 92), black = C(28, 30, 34), white = C(250, 250, 250), cream = C(240, 236, 226),
	containerRed = C(186, 88, 74), containerBlue = C(72, 112, 176), containerGreen = C(84, 150, 108),
	-- Fight pads and district signs (gameplay colours: the loudest things on the street, but not neon-loud).
	padRed = C(214, 84, 74), padBlue = C(66, 116, 212), padGreen = C(64, 176, 104), bossRing = C(110, 230, 140), boss = C(184, 76, 70),
	spawnBlue = C(60, 190, 255), evolveBlue = C(40, 88, 210), evolveYellow = C(252, 206, 52),
	-- Districts: brick red, violet, court orange, apartment amber-gold (kept apart from the orange), yards blue.
	district = { C(200, 92, 82), C(132, 94, 196), C(216, 140, 88), C(220, 172, 92), C(82, 124, 198) },
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
-- Street craft kit (Brief 8 research recipes): every object is one hue in three tones, M (main), D (dark base and
-- frame backs) and L (cream trim), built from a few chunky layers. One table so the module keeps its locals.
local Craft = {}
-- One icon per district for the district signs' badges (block, shops, courts, apartments, yards).
Craft.icons = { '🧱', '🛒', '🏀', '🏢', '📦' }
function Craft.dark(color) return color:Lerp(P.black, 0.38) end
-- A framed board between x0..x1 and y0..y1, centred on z = 0 and readable from both sides: a dark back, a cream
-- frame and the coloured face, each layer standing a little proud of the last, and a cream cap on top.
-- Returns the face (put the SurfaceGuis on it).
function Craft.board(b, x0, y0, x1, y1, color, depth)
	local d = (depth or 0.9) / 2
	local D = Craft.dark(color)
	b:box('BoardBack', V(x0, y0, -d), V(x1, y1, d), D, M.SmoothPlastic)
	b:box('BoardFrame', V(x0 + 0.3, y0 + 0.3, -d - 0.1), V(x1 - 0.3, y1 - 0.3, d + 0.1), P.cream, M.SmoothPlastic)
	local face = b:box('BoardFace', V(x0 + 0.75, y0 + 0.75, -d - 0.2), V(x1 - 0.75, y1 - 0.75, d + 0.2), color, M.SmoothPlastic)
	b:box('BoardCap', V(x0 - 0.2, y1, -d - 0.15), V(x1 + 0.2, y1 + 0.45, d + 0.15), P.cream, M.SmoothPlastic)
	return face
end
-- Title and subtitle on both faces of a board face.
function Craft.words(face, title, sub, color, ppS)
	for _, side in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local g = surface(face, side, ppS or 20)
		line(g, 'Title', title, P.white, FONT.loud, sub and 0.06 or 0.12, sub and 0.58 or 0.76, Craft.dark(color):Lerp(P.black, 0.4), 4)
		if sub then line(g, 'Sub', sub, P.cream, FONT.title, 0.66, 0.28, Craft.dark(color):Lerp(P.black, 0.4), 2) end
	end
end
-- A round badge facing along Z (dark ring, cream disc) with an icon or a short label on both sides.
function Craft.badge(b, pos, dia, text, color)
	local turn = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0)
	b:part('BadgeRing', V(1.5, dia, dia), turn, Craft.dark(color), M.SmoothPlastic, Enum.PartType.Cylinder)
	local disc = b:part('BadgeDisc', V(1.75, dia - 0.7, dia - 0.7), turn, P.cream, M.SmoothPlastic, Enum.PartType.Cylinder)
	for _, side in { Enum.NormalId.Right, Enum.NormalId.Left } do
		line(surface(disc, side, 24), 'Label', text, Craft.dark(color), FONT.loud, 0.16, 0.68)
	end
end
-- Rooftop AC unit (in place of a plain dark vent box): a dark skid, a pale grey body, a dark fan disc on top.
function Craft.acUnit(c, x, y, z)
	decor(c:box('RoofVent', V(x - 1.7, y, z - 2.2), V(x + 1.7, y + 0.3, z + 2.2), C(84, 88, 98), M.SmoothPlastic))
	decor(c:box('RoofUnit', V(x - 1.5, y + 0.3, z - 2), V(x + 1.5, y + 2.2, z + 2), C(184, 188, 196), M.SmoothPlastic))
	decor(c:part('RoofFan', V(0.25, 2.2, 2.2), CFrame.new(x, y + 2.3, z + 0.6) * CFrame.Angles(0, 0, math.pi / 2), C(70, 74, 84), M.SmoothPlastic, Enum.PartType.Cylinder))
end
-- A regular octagon slab (4 boxes turned 45 degrees apart), flat-to-flat f, from y0 to y1.
function Craft.octagon(b, name, f, y0, y1, color, material)
	for k = 0, 3 do
		b:part(name, V(f, y1 - y0, f * 0.4142), CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, k * math.pi / 4, 0), color, material or M.SmoothPlastic)
	end
end

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
	-- One glass block, a little wider than the frame so it reads as panes on all four sides.
	local glass = decor(l:box('LampGlass', pos + V(-0.82, 9.65, -0.82), pos + V(0.82, 10.95, 0.82), P.lampGlow, M.Neon))
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
-- City bin: a dark base ring, a green body with a lighter band, a domed lid with a knob.
local function trashCan(c, pos)
	local t = c:group('TrashCan')
	local body = C(70, 112, 92)
	t:post('CanBase', 1.0, 0.4, pos, Craft.dark(body), M.SmoothPlastic)
	t:post('Can', 0.9, 2.3, pos + V(0, 0.4, 0), body, M.SmoothPlastic)
	t:post('CanBand', 0.96, 0.35, pos + V(0, 1.9, 0), body:Lerp(P.white, 0.3), M.SmoothPlastic)
	t:post('CanLid', 1.02, 0.3, pos + V(0, 2.7, 0), Craft.dark(body), M.SmoothPlastic)
	t:post('CanKnob', 0.35, 0.35, pos + V(0, 3.0, 0), Craft.dark(body), M.SmoothPlastic)
	return t
end
-- Three chunky bin bags, each tied off on top.
local function trashBags(c, pos)
	local t = c:group('TrashBags')
	local bag = C(52, 56, 64)
	for _, b in { { V(2.2, 1.9, 2.2), V(0, 0.95, 0) }, { V(1.8, 1.6, 1.8), V(1.4, 0.8, 0.9) }, { V(1.9, 1.7, 1.9), V(0.5, 2.2, 0.4) } } do
		t:blob('TrashBag', b[1], pos + b[2], bag, M.SmoothPlastic)
		t:part('TrashBagTie', V(0.45, 0.5, 0.45), CFrame.new(pos + b[2] + V(0, b[1].Y / 2 + 0.1, 0)) * CFrame.Angles(0, math.rad(30), 0), bag:Lerp(P.black, 0.3), M.SmoothPlastic)
	end
	return t
end
-- Dumpster: a green steel body on a dark skid, a lip round the top, a black lid sloping to the front, lift
-- pockets on the sides and a pale stencil panel, on four casters.
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local dark = Craft.dark(P.dumpster)
	d:box('DumpsterSkid', V(-2.8, 0.45, -1.8), V(2.8, 0.85, 1.8), dark, M.SmoothPlastic)
	d:box('DumpsterBody', V(-3, 0.85, -2), V(3, 3.9, 2), P.dumpster, M.SmoothPlastic)
	d:box('DumpsterLip', V(-3.2, 3.6, -2.2), V(3.2, 4.1, 2.2), dark, M.SmoothPlastic)
	d:wedge('DumpsterLid', V(6.2, 0.7, 4.2), CFrame.new(0, 4.45, 0), P.black, M.SmoothPlastic) -- (low edge at the front, -Z)
	for _, x in { -3.25, 3.25 } do d:box('DumpsterPocket', V(x - 0.25, 1.6, -1.2), V(x + 0.25, 2.6, 1.2), dark, M.SmoothPlastic) end
	d:box('DumpsterPanel', V(-1.6, 1.5, -2.15), V(1.6, 3.0, -1.95), P.dumpster:Lerp(P.white, 0.45), M.SmoothPlastic)
	for _, x in { -2.3, 2.3 } do for _, z in { -1.4, 1.4 } do d:part('Caster', V(0.4, 0.6, 0.6), CFrame.new(x, 0.3, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end end
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
	-- Chunky corner posts, so it reads as a container and not a coloured box.
	for _, x in { -1, 1 } do for _, z in { -1, 1 } do k:box('ContainerCorner', V(x * 4.2 - 0.35, 0, z * 9.95 - 0.35), V(x * 4.2 + 0.35, 8.7, z * 9.95 + 0.35), color:Lerp(P.black, 0.3), M.SmoothPlastic) end end
	return k
end
-- Low-poly sedan (front toward -Z): a two-tone body on a dark sill, a glass greenhouse with sloped windscreens
-- front and back under a roof in the body colour, a grille, bumpers and lamps.
local function car(c, cf, color)
	local k = c:at(cf):group('Car')
	for _, x in { -2.1, 2.1 } do
		for _, z in { -3.3, 3.3 } do
			k:part('Wheel', V(0.8, 2, 2), CFrame.new(x, 1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(k:part('Hubcap', V(0.84, 1, 1), CFrame.new(x, 1, z), P.frame, M.SmoothPlastic, Enum.PartType.Cylinder))
		end
	end
	k:box('CarSill', V(-2.35, 0.8, -4.6), V(2.35, 1.3, 4.6), Craft.dark(color), M.SmoothPlastic)
	k:box('CarBody', V(-2.3, 1.1, -5.3), V(2.3, 2.6, 5.3), color, M.SmoothPlastic)
	decor(k:box('CarGlass', V(-2.05, 2.6, -1.9), V(2.05, 3.9, 2.6), P.glass, M.SmoothPlastic))
	decor(k:wedge('CarScreen', V(4.1, 1.3, 1.3), CFrame.new(0, 3.25, -2.55), P.glass, M.SmoothPlastic))
	decor(k:wedge('CarScreen', V(4.1, 1.3, 1.0), CFrame.new(0, 3.25, 3.1) * CFrame.Angles(0, math.pi, 0), P.glass, M.SmoothPlastic))
	k:box('CarRoof', V(-2.15, 3.9, -1.9), V(2.15, 4.35, 2.6), color, M.SmoothPlastic)
	decor(k:box('CarGrille', V(-1.0, 1.5, -5.4), V(1.0, 2.3, -5.25), Craft.dark(color):Lerp(P.black, 0.4), M.SmoothPlastic))
	for _, z in { -5.6, 5.3 } do k:box('Bumper', V(-2.4, 0.9, z), V(2.4, 1.5, z + 0.3), P.frame, M.SmoothPlastic) end
	for _, x in { -1.95, 1.1 } do
		decor(k:box('Headlight', V(x, 1.7, -5.4), V(x + 0.85, 2.3, -5.25), C(255, 244, 214), M.SmoothPlastic))
		decor(k:box('TailLight', V(x, 1.7, 5.25), V(x + 0.85, 2.3, 5.4), C(200, 70, 64), M.SmoothPlastic))
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
	for _, t in posts do c:post('FencePost', 0.32, h + 0.2, a + u * t, P.iron, M.Metal) end
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

-- Fight pad: a street boxing-ring mat (research recipe j). A dark base, a cream lip, the mat in the pad's
-- colour with its number, and four corner posts with padded cushions and small lit caps (the pad's only glow).
-- No ropes, so it stays open to walk onto from every side. A small plate on the front-left post names the fight.
local function fightPad(c, n, pos, color, district, size, label)
	size = size or PAD_SIZE
	local h = size / 2
	local D = Craft.dark(color)
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	pad:box('PadBase', V(-h - 1.4, 0, -h - 1.4), V(h + 1.4, 0.3, h + 1.4), C(96, 100, 110), M.SmoothPlastic)
	pad:box('PadBorder', V(-h - 0.7, 0.3, -h - 0.7), V(h + 0.7, 0.55, h + 0.7), P.cream, M.SmoothPlastic)
	local top = pad:box('Pad', V(-h, 0.3, -h), V(h, 0.75, h), color, M.SmoothPlastic)
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), P.white, FONT.loud, 0.2, 0.6, D:Lerp(P.black, 0.45), 6)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local p = V(x * (h + 0.55), 0, z * (h + 0.55))
			pad:box('PostFoot', p + V(-0.8, 0.55, -0.8), p + V(0.8, 0.9, 0.8), D, M.SmoothPlastic)
			pad:post('CornerPost', 0.45, 3.6, p + V(0, 0.9, 0), P.cream, M.SmoothPlastic)
			-- The padded corner cushion, turned so a flat face looks at the middle of the mat.
			pad:part('CornerPad', V(1.3, 1.7, 1.3), CFrame.new(p + V(0, 3.35, 0)) * CFrame.Angles(0, math.pi / 4, 0), color, M.SmoothPlastic)
			decor(pad:post('PostLight', 0.55, 0.5, p + V(0, 4.5, 0), color:Lerp(P.white, 0.25), M.Neon)).CastShadow = false
		end
	end
	-- Name plate on the front-left post (players arrive from +Z).
	local plate = pad:at(CFrame.new(-h - 0.55, 0, h + 1.15))
	plate:box('PlateBack', V(-0.7, 1.3, -0.2), V(4.6, 2.9, 0.2), D, M.SmoothPlastic)
	local face = plate:box('PlateFace', V(-0.45, 1.5, -0.3), V(4.35, 2.7, 0.3), P.cream, M.SmoothPlastic)
	line(surface(face, Enum.NormalId.Back, 30), 'Title', n >= 16 and 'BOSS FIGHT' or ('FIGHT ' .. n), D:Lerp(P.black, 0.3), FONT.title, 0.1, 0.8)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color, 0.6, 8, 120
	glow.Parent = top
	model:SetAttribute('Fight', n)
	model:SetAttribute('District', district)
	model:AddTag('HoodFightPad')
	return model, pad
end
-- District sign: a framed board hanging from a cantilever post at the kerb (a hood street-sign gantry), so it
-- names the district without hiding the street or the next gate. cf: the post's foot, +X toward the middle of
-- the street; the board reads from both directions along Z.
local function banner(c, cf, title, sub, badge, color)
	local D = Craft.dark(color)
	local b = c:at(cf):group('DistrictSign')
	b:box('SignPlinth', V(-1.3, 0, -1.3), V(1.3, 1.0, 1.3), C(150, 152, 160), M.Concrete)
	b:box('SignPlinthCap', V(-1.05, 1.0, -1.05), V(1.05, 1.3, 1.05), P.cream, M.SmoothPlastic)
	b:box('SignPost', V(-0.5, 1.3, -0.5), V(0.5, 17.4, 0.5), D, M.SmoothPlastic)
	b:box('SignPostCap', V(-0.8, 17.4, -0.8), V(0.8, 17.9, 0.8), P.cream, M.SmoothPlastic)
	b:box('SignArm', V(0.5, 16.2, -0.4), V(18.2, 17.0, 0.4), D, M.SmoothPlastic)
	b:box('SignArmEnd', V(18.2, 15.9, -0.55), V(19.0, 17.3, 0.55), P.cream, M.SmoothPlastic)
	b:bar('SignBrace', V(0.5, 13.4, 0), V(2.5, 16.2, 0), 0.6, D, M.SmoothPlastic)
	for _, x in { 4.8, 15.4 } do b:box('SignHanger', V(x - 0.3, 15.6, -0.3), V(x + 0.3, 16.2, 0.3), D, M.SmoothPlastic) end
	local face = Craft.board(b, 2.6, 8.6, 17.4, 15.6, color)
	Craft.words(face, title, sub, color)
	-- The district number on a round badge at the street end, breaking the board's outline.
	Craft.badge(b, V(17.6, 12.1, 0), 4.2, badge, color)
	return b
end

-- Teleport pad: a small teleport booth (research recipe c). A round pad in three steps (a dark octagon base, a
-- cream rim, the coloured top with a glowing ring and an icon in the middle) under a little arch: two posts and a
-- framed sign naming where it goes, readable from both sides. The top keeps the pad's name and the prompt
-- (StageService handles targets 'Lobby' and 'Furthest'). Each target has its own hue so a pad reads the same
-- everywhere: SPAWN rose, FURTHEST gold; anything else takes `color`. Steps stay low enough to walk onto.
local function teleportPad(g, name, x, z, color, target, label)
	local main = ({ Lobby = C(200, 88, 154), Furthest = C(214, 172, 80) })[target] or color
	local dark, trim, glow = main:Lerp(P.black, 0.38), C(238, 236, 232), main:Lerp(P.white, 0.3)
	local o = V(x, 0, z)
	-- base: an octagon from four boxes turned 45 degrees apart (flat to flat 7.8)
	for k = 0, 3 do
		g:part(name .. 'Base', V(7.8, 0.3, 3.24), CFrame.new(o + V(0, 0.15, 0)) * CFrame.Angles(0, k * math.pi / 4, 0), dark, M.SmoothPlastic)
	end
	local up = CFrame.Angles(0, 0, math.pi / 2) -- (cylinders lie along X; this stands them up)
	g:part(name .. 'Rim', V(0.22, 7, 7), CFrame.new(o + V(0, 0.41, 0)) * up, trim, M.SmoothPlastic, Enum.PartType.Cylinder)
	local pad = g:part(name, V(0.16, 6.2, 6.2), CFrame.new(o + V(0, 0.6, 0)) * up, main, M.SmoothPlastic, Enum.PartType.Cylinder)
	local ring = decor(g:part(name .. 'Ring', V(0.06, 5, 5), CFrame.new(o + V(0, 0.71, 0)) * up, glow, M.Neon, Enum.PartType.Cylinder))
	ring.CastShadow = false
	decor(g:part(name .. 'Core', V(0.08, 4, 4), CFrame.new(o + V(0, 0.73, 0)) * up, main, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	local icon = ghost(g:part(name .. 'Icon', V(3, 0.05, 3), CFrame.new(o + V(0, 0.78, 0)), P.white))
	line(surface(icon, Enum.NormalId.Top, 30), 'Icon', target == 'Lobby' and '🏠' or '🏁', P.white, FONT.loud, 0.1, 0.8)
	light(ring, glow, 0.8, 9)
	-- the arch: two posts on the base, a framed sign between their tops, a cap in the pad's colour
	for _, sx in { -1, 1 } do
		g:part(name .. 'Post', V(8.1, 0.8, 0.8), CFrame.new(o + V(sx * 3.6, 0.3 + 4.05, 0)) * up, dark, M.SmoothPlastic, Enum.PartType.Cylinder)
		g:box(name .. 'PostFoot', o + V(sx * 3.6 - 0.6, 0.3, -0.6), o + V(sx * 3.6 + 0.6, 0.9, 0.6), trim, M.SmoothPlastic)
	end
	g:box(name .. 'SignBack', o + V(-4.2, 6.6, -0.25), o + V(4.2, 8.8, 0.25), dark, M.SmoothPlastic)
	local face = decor(g:box(name .. 'Sign', o + V(-3.85, 6.85, -0.36), o + V(3.85, 8.55, 0.36), trim, M.SmoothPlastic))
	for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = surface(face, f, 24)
		pcall(function() sg.MaxDistance = 70 end)
		line(sg, 'Title', label, main:Lerp(P.black, 0.45), FONT.loud, 0.14, 0.72, P.white, 1)
	end
	g:box(name .. 'SignCap', o + V(-4.6, 8.8, -0.45), o + V(4.6, 9.35, 0.45), main, M.SmoothPlastic)
	-- a few soft sparks rising off the ring
	local fx = ghost(g:part(name .. 'Fx', V(5, 0.2, 5), CFrame.new(o + V(0, 0.9, 0)), P.white))
	local e = Instance.new('ParticleEmitter')
	e.Name = 'PadSparks'
	e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	e:SetAttribute('PreviewTexture', 'sparkle')
	e.Rate, e.Lifetime, e.Speed = 4, NumberRange.new(1, 1.4), NumberRange.new(2, 3)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Color, e.LightEmission, e.LightInfluence = ColorSequence.new(glow), 0.6, 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = fx
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
-- edge: a thin neon line inside the rim (shadow); labelLift: the label stack sits this much higher (gold's crown). Colours from the bag stations the critics signed off.
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
	{ name = 'frost', rim = C(30, 110, 210), rimTop = C(160, 244, 255), mat = C(132, 246, 248), matMat = M.SmoothPlastic, frame = C(30, 110, 210),
		groove = C(60, 190, 235), text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', rim = C(10, 170, 44), rimTop = C(20, 255, 60), rimTopMat = M.Neon, mat = C(0, 60, 60), frame = C(20, 255, 60), frameMat = M.Neon,
		groove = C(5, 150, 35), text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'gold', rim = C(230, 180, 0), rimTop = C(255, 236, 60), mat = C(252, 242, 88), frame = C(245, 192, 0), groove = C(205, 140, 0),
		trim = C(175, 18, 48), text = C(255, 222, 50), glow = C(255, 222, 80), labelLift = 0.3 },
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
-- truss beam across, capped. Hanging targets hang from its underside (GANTRY_Y) on its centre line. neon: lines
-- on the posts' front edges and under the beam (shadow, gold, frost); look.width (default 0.14) and look.backing
-- (a dark strip 0.34 wide just behind each line, so it reads without bloom on a bright frame).
function Stations.gantry(g, t, neon, look)
	look = look or {}
	local nw, back = look.width or 0.14, look.backing
	local nz0, nz1 = back and 0.49 or 0.47, back and 0.35 or 0.33
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
	Stations.bullseye(back, CFrame.new(0, Y + 6.8, z0 - 0.02), 1.15, { C(250, 250, 245), C(230, 50, 50), C(250, 250, 245), C(230, 50, 50) })
	for i, s in { { -2.9, 0, 1.9 }, { -0.95, 0, 1.9 }, { 0.95, 0, 1.9 }, { 2.9, 0, 1.9 }, { -1.9, 0.62, 1.8 }, { 1.95, 0.62, 1.8 } } do
		back:blob('Sandbag', V(s[3], 0.72, 1.05), V(s[1], Y + 0.34 + s[2], z0 - 0.6), i % 2 == 0 and C(158, 146, 120) or C(140, 130, 106), M.Fabric)
	end
	-- Bunting between two poles over the planks: two strands of little flags (red, yellow, blue, white), each on
	-- its own string, bobbing at different rates, so the pair ripples and no flag ever leaves its line.
	for _, sx in { -1, 1 } do back:box('BuntingPole', V(sx * 4.1 - 0.13, Y, z0 - 0.45), V(sx * 4.1 + 0.13, Y + 9.15, z0 - 0.19), wood:Lerp(C(0, 0, 0), 0.25)) end
	local flags = { C(235, 55, 60), C(255, 210, 50), C(60, 140, 240), C(250, 250, 245) }
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
		local foot = V(sx * 3.9, Stations.GANTRY_Y + 1.05, Stations.GANTRY_Z) -- (on the post's cap)
		for i, c in { C(255, 90, 170), C(255, 220, 60), C(120, 220, 255) } do
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
-- wall with a snow top, icicles and a deep-blue neon line, and a deep-blue gantry with deep-blue neon on navy
-- strips: pale ice in a dark frame, as rich as shadow's neon on black.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, deep = C(248, 252, 255), C(150, 225, 250), C(120, 205, 240), C(25, 120, 235)
	local glow, navy = C(40, 150, 255), C(12, 40, 100) -- deep-blue neon on navy strips (reads without bloom)
	Stations.gantry(g, t, glow, { width = 0.22, backing = navy })
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
	decor(back:box('SnowGlowBack', V(-4.4, top - 0.34, z0 - 0.18), V(4.4, top, z0 - 0.06), navy)).CastShadow = false
	decor(back:box('SnowGlow', V(-4.4, top - 0.28, z0 - 0.22), V(4.4, top - 0.06, z0 - 0.1), glow, M.Neon)).CastShadow = false
	for _, d in { { -2.6, 1.6, 0.5 }, { 0.6, 2.0, 0.7 }, { 2.9, 1.2, 0.4 } } do back:box('SnowDrift', V(d[1] - d[2] / 2, top + 0.4, z0 + 0.1), V(d[1] + d[2] / 2, top + 0.4 + d[3], z1 - 0.1), snow) end
	for i = 0, 9 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-3.9 + i * 0.86, top - 0.1, z0 - 0.12), len, 0.34)
	end
	-- Two deep-blue neon snowflakes high on the wall either side of the main target (six arms with twin branches;
	-- clear of the bullseye, the gantry posts and the icicles), and neon lines up the wall's edges: the lane's dark
	-- graphic, like shadow's rings.
	for _, sx0 in { -1, 1 } do
		local fc = CFrame.new(sx0 * 2.66, Y + 6.5, z0 - 0.08) * CFrame.Angles(0, 0, math.rad(15))
		for a = 0, 2 do
			local arm = fc * CFrame.Angles(0, 0, a * math.pi / 3)
			decor(back:part('Snowflake', V(1.6, 0.3, 0.1), arm, glow, M.Neon)).CastShadow = false
			for _, sx in { -1, 1 } do
				for _, sb in { -1, 1 } do
					local at = arm * CFrame.new(sx * 0.48, 0, -0.01) * CFrame.Angles(0, 0, sx * sb * math.pi / 3) * CFrame.new(sx * 0.17, 0, 0)
					decor(back:part('Snowflake', V(0.36, 0.2, 0.1), at, glow, M.Neon)).CastShadow = false
				end
			end
		end
	end
	for _, sx in { -1, 1 } do
		decor(back:box('WallNeon', V(sx * 4.3 - 0.11, 0.6, z0 - 0.07), V(sx * 4.3 + 0.11, top - 0.34, z0 + 0.04), glow, M.Neon)).CastShadow = false
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	g:box('IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), t.frame)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, C(90, 200, 245))
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
	local sw, drum = Stations.target(k, CFrame.new(0, base, mz + 0.95), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	drum:SetAttribute('TipMin', 0) -- (rocks back on its back edge, never into the crate)
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
	local s3, floorDrum = Stations.target(k, CFrame.new(2.7, Y, 5.26), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	floorDrum:SetAttribute('TipMin', 0)
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, neon, navy, C(10, 90, 30), M.Neon)
	-- Glowing puddles on the dark mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), neon, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane: a big gold gong with a crimson ring (main) in a gold ring on a velvet-faced gold backstop with cream trim
-- and gold rays (the gold pops off the dark velvet the way toxic's neon pops off its container), white-hot neon
-- on crimson strips up the gantry, a turning crown on the beam, gold bottles on a gold shelf, a gold plate on
-- a post, lemon nuggets on the sand and a velvet band on the bench (a VIP counter).
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, cream = C(255, 222, 40), C(245, 190, 0), C(255, 252, 235), C(235, 30, 70), C(255, 248, 220)
	local velvet, rays = C(150, 15, 40), C(255, 200, 40)
	Stations.gantry(g, t, C(255, 255, 235), { width = 0.22, backing = velvet })
	g:box('CrownPlinth', V(-0.5, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.4), V(0.5, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z + 0.4), velvet)
	Stations.crown(g, CFrame.new(0, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z))
	-- Wall: a gold body (its sides, back and top read gold from the aisle) with a crimson velvet field framed in
	-- gold on the shooter's face, cream trim, gold rays behind a gold ring round a darker velvet disc, two gems.
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.4
	Stations.wall(back, t, C(235, 170, 0), M.SmoothPlastic, h)
	local groove = C(112, 8, 30)
	for _, f in { { 4.05, 0.6, Y + h - 0.25, 0.04 }, { 2.65, Y + h + 0.12, Y + h + 0.62, -0.11 }, { 1.25, Y + h + 0.92, Y + h + 1.22, -0.26 } } do
		local face = back:box('Velvet', V(-f[1], f[2], z - f[4]), V(f[1], f[3], z - f[4] + 0.1), velvet, M.Fabric)
		Stations.panelX(back, face, CFrame.new(0, (f[2] + f[3]) / 2, z - f[4]), 2 * f[1], f[3] - f[2], f[1] > 3 and 5 or 4, groove)
	end
	Stations.wallLines(back, h, cream, M.SmoothPlastic, 0.3)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 4.2, 0.12, rays)
	local ring = Stations.disc(back, 'VelvetRim', CFrame.new(0, Y + 5.8, z - 0.22), 2.62, 0.14, rays)
	ring.Reflectance = 0.2
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 5.8, z - 0.28), 2.4, 0.14, C(105, 8, 30), M.Fabric)
	for _, s in { { -3.45, 1.2, C(60, 140, 255) }, { 3.45, 1.2, C(60, 220, 120) } } do
		back:part('Gem', V(0.42, 0.42, 0.25), CFrame.new(s[1], Y + s[2], z - 0.08) * CFrame.Angles(0, 0, math.pi / 4), s[3], M.Glass)
	end
	-- Main: the gong.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	-- (A little reflectance on the gold rim: a metal glint in Studio light; the crimson ring ties it to the velvet.)
	Stations.disc(sw, 'GongRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.03), 2.0, 0.22, deep).Reflectance = 0.2
	Stations.disc(sw, 'Gong', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.75, 0.28, gold)
	Stations.disc(sw, 'GongRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 1.08, 0.32, velvet)
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
	-- An amber rug with a velvet border over the target field (so the lemon nuggets read), and the nuggets on it.
	local rug = studs(g:box('Rug', V(-3.3, Y, 0.4), V(3.3, Y + 0.04, 8.2), C(210, 140, 0)))
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
-- The ARMORY, after the user's item-shop reference: the gun ladder as big guns floating in profile over big
-- glowing hexagonal pads, two rows. Guns 1-5 stand on the front platform (a low studded deck with a step along its front),
-- guns 6-10 on a raised studded terrace behind it, reached by a stair at each end. Each pad has a light rim and a
-- glowing face in its state colour (pink locked, blue owned, green equipped; Armory.client repaints them), a glow
-- skirt on the deck around it, and a plate on its front edge saying LOCKED / OWNED / EQUIPPED. Over each gun a
-- nameplate stack: the name in the gun's colour, the multiplier, the price (or the state word).
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun with attributes GunId, Tier,
-- Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part in front of the pad: prompt anchor and buy-distance point
--   StateTop/StateGlow the coloured face and glow (parts, several each; a PointLight under a StateGlow),
--                      StateStrip (part) with SurfaceGui > TextLabel State, StateHaze (ParticleEmitter)
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Bob) with the gun inside, horizontal, in profile to the hall
-- The Armory model is tagged HoodArmory; each slot streams Atomic.
-- Local frame: origin at the centre of the front step's foot on the hall floor, front faces -Z (players stand
-- at -Z looking +Z), footprint x -29.4..29.4, z 0..31.2 (Armory.HalfWidth, Armory.Depth), at most 20 tall.
local Armory = {}

Armory.HalfWidth, Armory.Depth = 29.4, 31.2
Armory.Floor = 1.6 -- front platform top (one 0.8 step up from the hall floor)
Armory.Step = 11.6 -- back terrace top: the front row's nameplates sit on its wall, the back row stands above them
Armory.TerraceZ = 17.4 -- where the terrace's front wall stands
Armory.Rows = { { z = 8.6, y = 1.6, label = 1.3, scale = 1 }, { z = 24.9, y = 11.6, label = 1.6, scale = 1.15 } }
Armory.Spacing = 10.3
Armory.Radius = 3.6 -- pad apothem (centre to a flat side); flats face -Z
Armory.PadHeight = 0.95
Armory.MaxLength = 6.5
Armory.Tilt = 17 -- degrees the muzzle points up
Armory.DisplayH = 4.6 -- the tallest a tilted gun may stand (taller ones are scaled down; nameplates sit over it)
Armory.Bob, Armory.BobPeriod = 0.35, 2.6

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

-- The display gun: GunModels.build when it exists (else the stand-in), scaled up to read across the hall over its
-- pad. Small guns are blown up more than big ones (display length ~ natural length^0.5), so a pistol is about 4.3
-- studs and the long guns about 6.5, and each tier gets 3% more on top, up to 6.5 studs.
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
	local length = math.min(Armory.MaxLength, 3.5 * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- Effects that grow with tier (`part` is a box round the gun, which sizes them): a soft light for the front row,
-- then for the back row HoodVFX.item when the VFX module is there, otherwise a light, sparkles, rising glow and
-- big star glints for the last two.
function Armory.effects(part, tier, color)
	if tier < 2 then return end -- the free pistol stays plain, like the basic tool in the reference
	-- The front row (tiers 2-5) gets only a soft light: like the reference, effects are for the better items.
	if tier < 6 then
		light(part, color, 0.5 + tier * 0.12, 7 + tier * 0.4)
		return
	end
	local vfx = Armory.optional('HoodVFX')
	if vfx and vfx.item then
		local ok, made = pcall(vfx.item, part, tier, color)
		if ok then
			-- A shop display keeps only the small effects: no halo, rays, arcs or glitter (they white out the terrace,
			-- worst with built-in textures), the rest capped at 2.5 studs and rising slowly so they stay under the
			-- nameplate.
			local kill = { ItemGlow = true, ItemRays = true, ItemArcs = true, ItemGlitter = true }
			for _, e in (type(made) == 'table' and made or {}) do
				if typeof(e) == 'Instance' and kill[e.Name] then
					e:Destroy()
				elseif typeof(e) == 'Instance' and e:IsA('ParticleEmitter') then
					pcall(function()
						local most = 0
						for _, kp in e.Size.Keypoints do most = math.max(most, kp.Value + kp.Envelope) end
						if most > 2.5 then
							local f, keys = 2.5 / most, {}
							for _, kp in e.Size.Keypoints do table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * f, kp.Envelope * f)) end
							e.Size = NumberSequence.new(keys)
						end
						if e.Name == 'ItemWisps' or e.Name == 'ItemFlames' or e.Name == 'ItemMotes' then
							e.Speed = NumberRange.new(e.Speed.Min * 0.5, e.Speed.Max * 0.5)
							e.Acceleration = e.Acceleration * 0.4
						end
					end)
				end
			end
			return
		end
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

-- The nameplate stack over a gun, like the reference's: the name big in the gun's colour, the multiplier and
-- the price (or the state word, painted by Armory.client), each row with an icon (IconModels.Images when uploaded,
-- else a text glyph kept in the label's Glyph attribute). Readable from 30 studs, shown up to 80, so the whole
-- shop reads from the hall walkway like the reference's.
function Armory.label(c, pos, gun)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	-- as wide as the name needs, so every name (even Diamond Cannon) fills its row's full height: one name size
	g.Size = UDim2.fromScale(math.max(6.2, 0.6 * #gun.Name), 2.4)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Parent = anchor
	-- (a grey gun's name would fade on the pale hall: it gets a rust orange instead)
	local _, sat = gun.Color:ToHSV()
	local nameColor = sat < 0.25 and C(240, 150, 90) or gun.Color:Lerp(P.white, 0.1)
	line(g, 'Name', gun.Name, nameColor, FONT.loud, 0, 0.42, C(24, 22, 40), 3)
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.loud, y, 0.27, C(24, 22, 40), 3)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = name == 'Price' and 'PriceIcon' or 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.3, y)
			i.Size = UDim2.fromScale(0.12, 0.27)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.42, y)
			t.Size = UDim2.fromScale(0.5, 0.27)
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
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier, P.white, 0.45)
	row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), C(255, 228, 92), 0.73)
	return anchor
end

-- One gun on its pad. (x, z) is the pad centre, y the deck it stands on.
function Armory.slot(c, gun, x, z, y, colors, lift, scale)
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local r, ph = Armory.Radius, Armory.PadHeight
	-- The glow skirt on the deck round the pad (recoloured with the glow; it carries the pad's light), the pale
	-- chunky pad with a lighter lip, the glowing face in the state colour set into it.
	local skirt = Armory.hex(s, 'StateGlow', x, z, r + 0.5, y, y + 0.04, look.Glow, M.Neon)
	for _, p in skirt do
		decor(p).CastShadow = false
		p.Transparency = 0.45
	end
	light(skirt[1], look.Top, 1.6, 12)
	Armory.hex(s, 'PadBase', x, z, r, y, y + ph - 0.2, C(228, 230, 240), M.SmoothPlastic)
	Armory.hex(s, 'PadLip', x, z, r, y + ph - 0.2, y + ph, C(244, 245, 250), M.SmoothPlastic)
	-- a glowing band round the pad's side in the state colour, so the state reads from the hall floor
	local band = Armory.hex(s, 'StateTop', x, z, r + 0.03, y + 0.22, y + ph - 0.32, look.Top, M.Neon)
	for _, p in band do decor(p).CastShadow = false end
	local tops = Armory.hex(s, 'StateTop', x, z, r - 0.55, y + ph - 0.05, y + ph + 0.05, look.Top, M.Neon)
	for _, p in tops do decor(p).CastShadow = false end
	-- Soft haze rising off the face in the state colour (the client recolours it with the pad).
	local top = y + ph + 0.05
	local hazeSource = ghost(s:part('StateHazeSource', V(r * 1.3, 0.2, r * 1.3), CFrame.new(x, top + 0.1, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 1.2
	haze.Lifetime = NumberRange.new(1.2, 1.8)
	haze.Speed = NumberRange.new(0.8, 1.4)
	haze.SpreadAngle = Vector2.new(8, 8)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 3.4) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.93), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	-- The plate on the pad's front edge with the state word.
	local strip = s:box('StateStrip', V(x - 1.9, y + 0.1, z - r - 0.06), V(x + 1.9, y + ph - 0.25, z - r + 0.02), look.Strip, M.SmoothPlastic)
	local sg = surface(strip, Enum.NormalId.Front, 50)
	sg.Name = 'StateGui'
	line(sg, 'State', string.upper(state), P.white, FONT.loud, 0.06, 0.88, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun floating over the pad in profile to the hall (muzzle to the viewer's right), tilted up a little,
	-- bobbing; never turning, so it is never seen end-on.
	local d, display = s:group('Display')
	local tilt = math.rad(Armory.Tilt)
	local function measure(model)
		local lo, hi = Armory.extents(model, Armory.pivotOf(model))
		return lo, hi, (hi.Y - lo.Y) * math.cos(tilt) + (hi.Z - lo.Z) * math.sin(tilt)
	end
	local k = scale or 1 -- the back row a size bigger, so it reads as big as the front row from the hall
	local g = Armory.gun(gun, k)
	local lo, hi, tall = measure(g)
	if tall > Armory.DisplayH * k then
		-- a deep gun (an Uzi's long magazine) stands too tall tilted: a size smaller, under the nameplates
		g:Destroy()
		g = Armory.gun(gun, k * Armory.DisplayH * k / tall)
		lo, hi, tall = measure(g)
	end
	local mid = (lo + hi) / 2
	local length = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
	local centre = V(x, top + 1.0 + tall / 2, z)
	local pose = CFrame.new(centre) * CFrame.Angles(0, 0, -tilt) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:SetAttribute('Bob', Armory.Bob)
	display:SetAttribute('BobPeriod', Armory.BobPeriod)
	display:AddTag('HoodMotion')
	local core = ghost(s:part('FxCore', V(length * 0.5, math.max(tall * 0.7, length * 0.25), length * 0.2), CFrame.new(centre), gun.Color))
	core.CastShadow = false
	Armory.effects(core, gun.Tier, gun.Color)
	-- (every label in a row at one height, over the tallest gun, like the reference's nameplates)
	Armory.label(s, V(x, y + ph + 1.0 + Armory.DisplayH * k + (lift or 0.8), z), gun)
	-- On the front row, a display backboard standing right behind the pad (so the gun is always seen in front of
	-- its own board, not a neighbour's): a panel in the state colour (the client repaints it) in a pale glowing rim
	-- on a white stand, under the nameplate.
	if y < Armory.Step - 1 then
		local bz, bw, b0, b1 = z + Armory.Radius + 0.8, 3.7, y + 0.9, y + 6.4
		s:box('StateTop', V(x - bw, b0, bz - 0.06), V(x + bw, b1, bz), look.Top, M.SmoothPlastic)
		s:box('BoardStand', V(x - bw - 0.3, y, bz), V(x + bw + 0.3, b1 + 0.3, bz + 0.35), C(236, 238, 246), M.SmoothPlastic)
		for _, e in { { V(x - bw - 0.3, b1, bz - 0.12), V(x + bw + 0.3, b1 + 0.3, bz) }, { V(x - bw - 0.3, b0 - 0.3, bz - 0.12), V(x + bw + 0.3, b0, bz) },
			{ V(x - bw - 0.3, b0, bz - 0.12), V(x - bw, b1, bz) }, { V(x + bw, b0, bz - 0.12), V(x + bw + 0.3, b1, bz) } } do
			decor(s:box('StateGlow', e[1], e[2], look.Glow, M.Neon)).CastShadow = false
		end
	end
	-- Where the prompt sits and the server measures buying distance from: on the deck at the pad's front.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.5, y + 0.6, z - r - 1.6), V(x + 0.5, y + 1.6, z - r - 0.6), P.white))
	point.CastShadow = false
	return model
end

-- The deck: a step along the front, the studded front platform with a lip of studs at its edge, the raised
-- studded terrace behind it (its front wall studded too), a stair up at each end, neon edges.
function Armory.base(c)
	local b = c:group('ArmoryBase')
	local X, Dp, F, T, TZ = Armory.HalfWidth, Armory.Depth, Armory.Floor, Armory.Step, Armory.TerraceZ
	local deck, wall, step = C(218, 222, 234), C(190, 196, 214), C(200, 205, 222)
	studs(b:box('ArmoryStep', V(-X, 0, 0), V(X, F / 2, 1.2), step, M.Plastic), true)
	studs(b:box('ArmoryFloor', V(-X, 0, 1.2), V(X, F, TZ), deck, M.Plastic), true)
	studs(b:box('ArmoryLip', V(-X, F, 1.2), V(X, F + 0.12, 1.8), wall, M.Plastic))
	studs(b:box('ArmoryTerrace', V(-X, 0, TZ), V(X, T, Dp), wall, M.Plastic), true)
	studs(b:box('ArmoryTerraceTop', V(-X, T, TZ), V(X, T + 0.01, Dp), deck, M.Plastic))
	-- a stair at each end, from the platform up to the terrace (rises of 0.8 or less, 1.2 treads), white nosing
	local n = math.ceil((T - F) / 0.8) - 1
	local rise = (T - F) / (n + 1)
	for _, sx in { -1, 1 } do
		local a, bx = sx * (X - 4.4), sx * X
		for k = 1, n do
			local z0 = TZ - (n + 1 - k) * 1.2
			local h = F + k * rise
			studs(b:box('ArmoryStair', V(math.min(a, bx), F, z0), V(math.max(a, bx), h, TZ), k % 2 == 1 and step or deck, M.Plastic), true)
			decor(b:box('StairNosing', V(math.min(a, bx), h - 0.02, z0 - 0.02), V(math.max(a, bx), h + 0.03, z0 + 0.3), C(255, 212, 40), M.Neon)).CastShadow = false
		end
	end
	-- an UP chevron painted on the deck at each stair's foot
	for _, sx in { -1, 1 } do
		local cx = sx * (X - 2)
		local z1 = TZ - n * 1.2 - 0.1 -- just in front of the first tread
		for _, side in { -1, 1 } do
			local tip, tail = V(cx, F + 0.03, z1), V(cx + side * 1.1, F + 0.03, z1 - 1.2)
			decor(b:part('StairChevron', V(0.5, 0.05, (tip - tail).Magnitude + 0.3), CFrame.lookAt((tip + tail) / 2, tip), C(255, 212, 40), M.Neon)).CastShadow = false
		end
	end
	-- neon edges: cyan along the platform's front, white along the terrace's top edge
	local cyan = C(60, 232, 255)
	decor(b:box('ArmoryEdge', V(-X, F / 2 - 0.26, -0.06), V(X, F / 2 - 0.04, 0), cyan, M.Neon)).CastShadow = false
	decor(b:box('ArmoryEdge', V(-X, F - 0.26, 1.14), V(X, F - 0.04, 1.2), cyan, M.Neon)).CastShadow = false
	decor(b:box('ArmoryEdge', V(-X + 4.4, T - 0.3, TZ - 0.06), V(X - 4.4, T - 0.06, TZ + 0.02), P.white, M.Neon)).CastShadow = false
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
	for i, gun in guns do
		local row = Armory.Rows[(i - 1) // 5 + 1]
		if not row then break end
		local col = (i - 1) % 5
		-- Gun 1 stands on the viewer's left: their left is +X when they look toward +Z.
		Armory.slot(a, gun, 2 * Armory.Spacing - col * Armory.Spacing, row.z, row.y, colors, row.label, row.scale)
	end
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
	Craft.acUnit(c, w * 0.3, roof + 1.2, -10)
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

-- Tan apartment block: buff walls, light corner piers and floor bands, a cornice, chunky balconies on the
-- upper floors.
-- Balcony: a slab with a solid cream parapet (front and sides) under a darker cap: one chunky low-poly box,
-- no thin railings.
local function balcony(c, x, y)
	decor(c:box('BalconySlab', V(x - 3.3, y - 0.6, 0), V(x + 3.3, y, 2.9), P.tanDark, M.SmoothPlastic))
	decor(c:box('BalconyFront', V(x - 3.2, y, 2.4), V(x + 3.2, y + 2.3, 2.85), P.cream, M.SmoothPlastic))
	for _, sx in { -3.2, 2.75 } do decor(c:box('BalconySide', V(x + sx, y, 0), V(x + sx + 0.45, y + 2.3, 2.4), P.cream, M.SmoothPlastic)) end
	decor(c:box('BalconyCap', V(x - 3.35, y + 2.3, 2.3), V(x + 3.35, y + 2.75, 3.0), P.tanDark, M.SmoothPlastic))
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
	Craft.acUnit(c, w * 0.7, roof + 0.6, -10)
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
	stripedAwning(c, 1.5, w - 1.5, 9.4, { C(200, 82, 76), P.white, C(200, 82, 76), P.white, P.barberBlue })
	local sign = c:box('ShopSign', V(w / 2 - 7, 10.2, 0), V(w / 2 + 7, 13.6, 0.8), P.barberBlue, M.SmoothPlastic)
	decor(c:box('ShopSignBorder', V(w / 2 - 7.4, 9.8, 0), V(w / 2 + 7.4, 14.0, 0.7), P.cream, M.SmoothPlastic))
	decor(c:box('ShopSignCap', V(w / 2 - 7.7, 14.0, 0), V(w / 2 + 7.7, 14.4, 0.9), Craft.dark(P.barberBlue), M.SmoothPlastic))
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'BARBER', P.white, FONT.loud, 0.12, 0.76, C(16, 30, 80), 3)
	-- The pole by the door, turning.
	local pole, poleModel = c:group('BarberPole')
	local p0 = V(w - 0.9, 2, 1.2)
	pole:post('PoleBody', 0.55, 5, p0, P.white, M.SmoothPlastic)
	for k = 0, 4 do
		pole:part('PoleStripe', V(0.35, 1.15, 1.15), CFrame.new(p0 + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(22), 0, 0), k % 2 == 0 and C(200, 82, 76) or P.barberBlue, M.SmoothPlastic, Enum.PartType.Cylinder)
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
	roofCap(c, w, roof, C(58, 108, 70))
	for _, x in bays(w, 3) do window(c, x, storeyY(2) + 3, { frame = P.white }) end
	c:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
	for x = 2 + (w - 9) / 3, w - 7.5, (w - 9) / 3 do decor(c:box('ShopMullion', V(x - 0.2, 1, 0), V(x + 0.2, 7.4, 0.4), C(46, 100, 62), M.SmoothPlastic)) end
	c:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), C(46, 100, 62), M.SmoothPlastic)
	c:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
	decor(c:box('ShopSignBorder', V(0.7, 9.5, 0), V(w - 0.7, 14.1, 0.7), P.cream, M.SmoothPlastic))
	local sign = c:box('ShopSign', V(1.2, 10.0, 0), V(w - 1.2, 13.6, 0.9), C(46, 100, 62), M.SmoothPlastic)
	decor(c:box('ShopSignCap', V(0.5, 14.1, 0), V(w - 0.5, 14.5, 1.0), C(36, 78, 50), M.SmoothPlastic))
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'GROCERY', C(250, 230, 160), FONT.loud, 0.12, 0.76, C(18, 44, 26), 3)
	stripedAwning(c, 0.5, w - 0.5, 9.4, { C(76, 140, 88), C(244, 232, 196) }, 4)
	-- Produce stand and crates.
	c:box('StandTable', V(2.5, 2.4, 1), V(9.5, 2.8, 4), P.wood, M.WoodPlanks)
	for _, x in { 3, 9 } do c:box('StandLeg', V(x - 0.2, 0, 1.3), V(x + 0.2, 2.4, 3.7), P.woodDark, M.Wood) end
	local fruit = { C(214, 76, 64), C(236, 150, 66), C(124, 186, 78), C(236, 204, 90) }
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
	decor(c:box('ShopSignBorder', V(1.7, 9.3, 0), V(w - 1.7, 12.9, 0.5), P.cream, M.SmoothPlastic))
	local sign = c:box('ShopSign', V(2, 9.6, 0), V(w - 2, 12.6, 0.7), C(40, 54, 96), M.SmoothPlastic)
	decor(c:box('ShopSignCap', V(1.5, 12.9, 0), V(w - 1.5, 13.3, 0.8), C(30, 40, 72), M.SmoothPlastic))
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', label, P.white, FONT.loud, 0.14, 0.72, C(16, 22, 44), 2)
	decor(c:wedge('Awning', V(w - 4, 1.4, 3), CFrame.new(w / 2, 8.6, 1.5) * CFrame.Angles(0, math.pi, 0), C(66, 90, 146), M.Fabric))
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
	decor(c:box('LightBar', V(dx - 3, 16, 0), V(dx + 3, 16.6, 0.6), C(255, 232, 186), M.Neon))
	c:box('SideDoorFrame', V(w - 8.6, 0, 0), V(w - 3.4, 9, 0.35), P.warehouseDark, M.Metal)
	c:box('SideDoor', V(w - 8, 0, 0), V(w - 4, 8.2, 0.45), C(64, 84, 126), M.Metal)
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
	decor(c:box('ShopSignBorder', V(w / 2 - sw - 0.4, 9.8, 0), V(w / 2 + sw + 0.4, 14.0, 0.7), P.cream, M.SmoothPlastic))
	decor(c:box('ShopSignCap', V(w / 2 - sw - 0.7, 14.0, 0), V(w / 2 + sw + 0.7, 14.4, 0.9), Craft.dark(o.signColor), M.SmoothPlastic))
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
	local colors = { P.containerBlue, P.containerRed, P.containerGreen, P.containerRed }
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
-- World 1's spawn: the BLOCK RANGE hall, a bright clean warehouse hall after the user's two references
-- (ref_hall_a / ref_hall_b): light aqua studded walls between slate pillars with white neon strips, big
-- blue windows in white frames, navy box trusses with rows of white fluorescent bars under a slate ceiling, a
-- lavender studded floor with a wide cross walkway and deeper panels between its arms outlined in cyan neon.
--   North (-Z): the exit to Stage 1 with a monitor over it, the WORLD 2 garage door beside it.
--   West wall: the 8 shooting ranges as a stepped row, Starter lowest by the exit, Gold highest at the back,
--     each lane on its own studded base with stairs down to the floor; the targets are by the wall.
--   South (back) centre: the SHOE BOX dais (a small podium with big sneaker boxes, COMING SOON) under its sign.
--   East: the ARMORY (two rows of big guns over glowing hex pads, front platform and raised terrace) facing
--     the hall under a big ARMORY sign; the corner store at the end of the cross's east arm.
--   Leaderboards, the gold KINGPIN statue and the reward crates stand along the walls.
-- Builders from other files (Stations, Armory) fill the slots; a missing or failing one leaves a labelled
-- placeholder box of the slot's size.
-- Map frame (studs): interior x -66..66, z 6..156 (north wall z 5..6, the Stage 1 gate at z = 0 stays outside),
-- floor top y = 0. North = -Z. Lobby.Slots: name -> CFrame in the map frame, filled by Lobby.build.
-- Colour rule: nothing bigger than ~10 studs² darker than luminance 0.2 except screens; no Metal on big
-- surfaces. Kid-friendly: every target is a thing, never a person.
local Lobby = {}

Lobby.W = 66 -- interior half width (walls x ±66..±67)
Lobby.N, Lobby.S = 6, 156 -- interior north and south faces
Lobby.H = 40 -- ceiling height
Lobby.Deck = SPAWN.Y -- the floor (0): the spawn stands on it
Lobby.CrossZ = SPAWN.Z -- where the walkways cross
Lobby.Door, Lobby.DoorH = 12, 20 -- north door half width and height
Lobby.Bay = 15 -- pillar spacing along the side walls, from z = 6
Lobby.Slots = {}
-- Brief 8: the shell is clean neutral grey (floor, walkway, panels, walls, pillars, trusses, ceiling; S <= 0.08);
-- the colour comes from what stands in the hall. Big coloured surfaces stay at S <= 0.45, objects <= 0.7.
Lobby.Colors = {
	floor = C(196, 198, 204), walk = C(214, 216, 220), panel = C(176, 178, 186), panelRim = C(162, 164, 172), kerb = C(234, 235, 238), cyan = C(60, 232, 255),
	wall = C(205, 207, 212), wallLow = C(166, 168, 175), pillar = C(106, 108, 114), pillarDark = C(88, 90, 96),
	neon = C(236, 246, 255), frame = C(240, 241, 244), winFrame = C(80, 82, 88), winGlass = C(160, 214, 248), truss = C(96, 98, 104),
	lamp = C(92, 94, 100), ceiling = C(156, 158, 164), lampPlate = C(250, 252, 255),
	step = C(190, 192, 198), stepDark = C(162, 164, 170), carpet = C(188, 104, 108), carpetDark = C(146, 76, 82), carpetLip = C(236, 214, 210), dais = C(208, 210, 216),
	steel = C(198, 200, 206), brick = C(170, 86, 72), screen = C(70, 160, 255),
	hazard = C(250, 196, 32), warm = C(255, 196, 120), cool = C(96, 210, 236), pink = C(236, 96, 170),
	gold = C(248, 200, 70), red = C(212, 66, 66), blue = C(66, 120, 206), rackPost = C(40, 90, 190), rackBeam = C(240, 120, 30),
	band = C(188, 190, 196), doorSteel = C(150, 154, 162), brickWall = C(180, 112, 99), cap = C(204, 206, 210), safety = C(255, 212, 40), plate = C(214, 216, 222),
}
-- The ranges climb the west wall as one red terrace: Starter (tier 1) by the exit, Gold (tier 8) at the back,
-- 10.5 apart, each 1.2 higher than the last. A lane's front (shooter's box) faces the hall; its targets face the
-- wall. In front of the lanes runs one promenade with a straight front edge at TerraceX.
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.RangeZ0, Lobby.RangePitch, Lobby.RangeRise = 34, 10.5, 1.2
Lobby.RangeX = -53 -- lane centres; the shooter's end is at x -43, the backstops at x -63
Lobby.TerraceX = -37 -- the promenade's front edge
Lobby.SideStair = 4 -- the lane whose side stair comes down to the cross walkway
Lobby.LoadDoors = { -55, 55 } -- the north wall's two closed roll-up loading doors (centres; 14 wide, 12 tall)
-- The terrace's height at z (0 off its ends).
function Lobby.terraceHeight(z)
	local i = math.floor((z - (Lobby.RangeZ0 - Lobby.RangePitch / 2)) / Lobby.RangePitch) + 1
	return (i >= 1 and i <= #Lobby.Ranges) and i * Lobby.RangeRise or 0
end
-- The ARMORY on the east side: its front step's foot at x ArmoryX, centred on z ArmoryZ, facing the hall (-X).
-- It spans z ArmorySpan (Armory.HalfWidth 29.4 each way) and x ArmoryX..65.6 (Armory.Depth 31.2).
Lobby.ArmoryX, Lobby.ArmoryZ = 34.4, 106.2
Lobby.ArmorySpan = { 76.8, 135.6 }
-- The floor's recessed panels (x0, x1, z0, z1) between the arms of the cross walkway.
Lobby.Panels = { { -30, -8, 16, 58 }, { 8, 30, 16, 58 }, { -30, -8, 74, 121 }, { 8, 30, 74, 121 } } -- 16-wide arms, 22-wide panels
-- The lobby's fast-travel pad (FurthestPad): off the walk on the south-east panel's corner by the crossing, front to
-- the walkway (west).
Lobby.FurthestAt = CFrame.lookAt(V(14.5, 0, 81), V(0, 0, 81))


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
-- Shaded stripes painted on one face of a part (the corrugated band's ribs, a roll-up door's slats, hazard
-- blocks): every `pitch` studs a stripe `width` wide, vertical or horizontal, in color at transparency alpha.
-- len and ht are the face's width and height in studs. Returns the SurfaceGui (text can go on it too).
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
-- A square slate wall pillar standing on the floor at pos (on the wall's inner face), its front along normal,
-- with the reference's kink: a deep lower part, a slanted step (a wedge), a slimmer upper part, white neon strips
-- up both front edges following the kink. kind 'range' is shallower (the lanes' backstops are 3 studs off the
-- wall) and stands on the terrace at height y (it is built round the pillar); kind 'above' is only the upper
-- part, from y 20.6 (over the EVOLUTIONS podium's back).
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
	local function neon(x, ya, yb, d)
		decor(B('PillarNeon', x - 0.14, ya, -d - 0.08, x + 0.14, yb, -d + 0.02, K.neon, M.Neon)).CastShadow = false
	end
	local xs = { -w / 2 + 0.3, w / 2 - 0.3 }
	if kind == 'above' then
		B('Pillar', -w / 2, 20.6, -d1, w / 2, H - 1.4, 0, K.pillar)
		for _, x in xs do neon(x, 21, H - 1.6, d1) end
		return
	end
	local yb = y or 0
	-- A darker grey plinth with a bevelled top (no hazard collar), the deep lower part with a lighter inset
	-- panel, the slant, and the slim upper part carrying the two white strips (the hall's light fixtures).
	local pt = math.min(yb + 1.6, y0)
	B('PillarBase', -w / 2 - 0.3, yb, -db, w / 2 + 0.3, pt, 0, K.pillarDark)
	c:wedge('PillarBaseBevel', V(w + 0.6, 0.45, db - d0), f * CFrame.new(0, pt + 0.225, -(db + d0) / 2), K.pillarDark, M.SmoothPlastic)
	B('Pillar', -w / 2, yb, -d0, w / 2, y0, 0, K.pillar)
	B('PillarInset', -w / 2 + 0.6, pt + 0.8, -d0 - 0.12, w / 2 - 0.6, y0 - 0.8, -d0 + 0.05, K.pillar:Lerp(P.white, 0.18))
	B('Pillar', -w / 2, y0, -d1, w / 2, H - 1.4, 0, K.pillar)
	-- The slant: a wedge whose slope runs from the lower part's front top edge up to the upper part's face.
	c:wedge('PillarKink', V(w, y1 - y0, d0 - d1), f * CFrame.new(0, (y0 + y1) / 2, -(d0 + d1) / 2), K.pillar, M.SmoothPlastic)
	for _, x in xs do neon(x, y1, H - 1.6, d1) end
end
-- A big window on a wall: white outer frame, a navy inner frame with a mullion, very light blue glass with a
-- lighter streak, and a small white lamp plate under it. f(u, y, w) maps (along the wall, height, out from
-- the wall) to the map.
function Lobby.window(c, f, u, y0, y1)
	local K = Lobby.Colors
	c:box('WindowFrame', f(u - 5.4, y0 - 0.6, 0), f(u + 5.4, y1 + 0.6, 0.35), K.frame, M.SmoothPlastic)
	c:box('WindowInner', f(u - 4.9, y0, 0.3), f(u + 4.9, y1, 0.45), K.winFrame, M.SmoothPlastic)
	c:box('WindowGlass', f(u - 4.4, y0 + 0.5, 0.4), f(u + 4.4, y1 - 0.5, 0.5), K.winGlass, M.SmoothPlastic)
	local ym = y1 - (y1 - y0) * 0.36
	c:box('WindowMullion', f(u - 4.4, ym - 0.25, 0.4), f(u + 4.4, ym + 0.25, 0.56), K.winFrame, M.SmoothPlastic)
	decor(c:box('WindowGlint', f(u - 3.8, y0 + 0.5, 0.45), f(u - 2.4, ym - 0.25, 0.55), K.winGlass:Lerp(P.white, 0.55), M.SmoothPlastic)).CastShadow = false
	decor(c:box('WallLamp', f(u - 0.9, y0 - 1.5, 0), f(u + 0.9, y0 - 0.9, 0.3), K.lampPlate, M.Neon)).CastShadow = false
end
-- A closed roll-up loading door in the north wall at x: grey steel jambs on dark plinths with bevelled caps,
-- grey slats (painted as stripes) with a red stencil, a dark bottom rail, a drum housing with a red beacon over it.
-- (no hazard paint, nothing on the floor)
function Lobby.loadingDoor(c, x, label)
	local K, N = Lobby.Colors, Lobby.N
	local d = c:group('LoadingDoor')
	local w, ht = 7, 12
	for _, sx in { -1, 1 } do
		local a, b = x + sx * w, x + sx * (w + 1.2)
		local lo, hi = math.min(a, b), math.max(a, b)
		d:box('LoadDoorPost', V(lo, 0, N), V(hi, ht + 1.4, N + 0.9), K.pillar, M.SmoothPlastic)
		d:box('LoadDoorPostFoot', V(lo - 0.2, 0, N), V(hi + 0.2, 1.4, N + 1.2), K.pillarDark, M.SmoothPlastic)
		d:box('LoadDoorPostTrim', V(lo + 0.35, 1.4, N + 0.9), V(hi - 0.35, ht + 0.6, N + 1.0), K.pillar:Lerp(P.white, 0.25), M.SmoothPlastic)
	end
	d:box('LoadDoorDrum', V(x - w - 1.4, ht, N), V(x + w + 1.4, ht + 2, N + 1.5), K.cap, M.SmoothPlastic)
	d:box('LoadDoorDrumLip', V(x - w - 1.5, ht - 0.25, N), V(x + w + 1.5, ht, N + 1.65), K.pillar, M.SmoothPlastic)
	local panel = d:box('LoadDoorPanel', V(x - w, 0.6, N), V(x + w, ht, N + 0.5), K.doorSteel, M.SmoothPlastic)
	local g = Lobby.stripes(panel, Enum.NormalId.Back, 2 * w, ht - 0.6, 0.76, 0.18, false, 0.6)
	line(g, 'Stencil', label, C(206, 70, 64), FONT.loud, 0.34, 0.2, P.white, 2)
	d:box('LoadDoorRail', V(x - w, 0, N), V(x + w, 0.6, N + 0.7), K.pillarDark, M.SmoothPlastic)
	-- the beacon
	d:box('LoadDoorBeaconBase', V(x - 0.6, ht + 2, N + 0.4), V(x + 0.6, ht + 2.4, N + 1.4), K.pillarDark, M.SmoothPlastic)
	local beacon = decor(d:part('LoadDoorBeacon', V(1.1, 1.1, 1.1), CFrame.new(x, ht + 2.9, N + 0.9), C(240, 70, 60), M.Neon, Enum.PartType.Ball))
	beacon.CastShadow = false
	return d
end
-- A big hall sign (sign recipe i, hero size), layered: a dark grey back plate, a white frame with chunky corner
-- blocks, a light cap strip on top, a pale studded board with a deep slate title and a red sub-line, and an icon
-- medallion (a dark ring round a red disc) on its left end. No neon: the hall's lamps light it.
function Lobby.wallSign(c, name, pos, normal, w, ht, title, sub, icon)
	local K = Lobby.Colors
	local cf = CFrame.lookAt(pos, pos + normal)
	c:part(name .. 'Back', V(w + 3.6, ht + 2.8, 0.4), cf * CFrame.new(0, 0, 0.55), K.pillarDark, M.SmoothPlastic)
	c:part(name .. 'Frame', V(w + 2.2, ht + 1.6, 0.5), cf * CFrame.new(0, 0, 0.3), K.frame, M.SmoothPlastic)
	c:part(name .. 'Cap', V(w + 4.2, 0.6, 1.3), cf * CFrame.new(0, ht / 2 + 1.7, 0.1), K.frame, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			if not (icon and sx < 0) then
				c:part(name .. 'Corner', V(1.6, 1.6, 0.8), cf * CFrame.new(sx * (w / 2 + 1.1), sy * (ht / 2 + 0.8), 0.1), K.pillar, M.SmoothPlastic)
			end
		end
	end
	if icon then
		local m = cf * CFrame.new(-(w / 2 + 3.2), 0, -0.3) -- (just past the board's end, so it never covers the text)
		c:part(name .. 'Medal', V(0.8, ht + 1.4, ht + 1.4), m * CFrame.Angles(0, math.pi / 2, 0), K.pillar, M.SmoothPlastic, Enum.PartType.Cylinder)
		c:part(name .. 'MedalFace', V(1.0, ht - 0.2, ht - 0.2), m * CFrame.Angles(0, math.pi / 2, 0), C(196, 90, 86), M.SmoothPlastic, Enum.PartType.Cylinder)
		local ic = ghost(c:part(name .. 'MedalIcon', V(ht - 1.6, ht - 1.6, 0.1), m * CFrame.new(0, 0, -0.56), P.white))
		line(surface(ic, Enum.NormalId.Front, 16), 'Icon', icon, P.white, FONT.loud, 0.04, 0.92, C(90, 20, 20), 3)
	end
	local rows = { { 'Title', title, C(52, 60, 86), FONT.loud, 0.06, sub and 0.58 or 0.8, P.white, 5 } }
	if sub then table.insert(rows, { 'Sub', sub, C(196, 60, 62), FONT.loud, 0.66, 0.28, P.white, 3 }) end
	studs(Lobby.board(c, name, cf, w, ht, C(226, 228, 234), rows, 12))
end
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	-- The floor is the panels' lavender; the walkways are painted over it (Lobby.floorPlan).
	Lobby.slab(h, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.panel)
	local function wall(a, b) return studs(h:box('Wall', a, b, K.wall, M.Plastic)) end
	wall(V(-W - 1, 0, N - 1), V(-W, H, S + 1))
	wall(V(W, 0, N - 1), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, S), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, N - 1), V(-Dw, H, N))
	wall(V(Dw, 0, N - 1), V(W + 1, H, N))
	wall(V(-Dw, DH, N - 1), V(Dw, H, N))
	-- Inner faces: a darker grey lower band capped by a light rail, a white cornice with a grey lip under it,
	-- windows between the pillars. f(u, y, w): u along the wall, w out from it into the hall.
	local west = function(u, y, w) return V(-W + w, y, u) end
	local east = function(u, y, w) return V(W - w, y, u) end
	local south = function(u, y, w) return V(u, y, S - w) end
	local north = function(u, y, w) return V(u, y, N + w) end
	for _, r in { { west, N, S }, { east, N, S }, { south, -W, W }, { north, -W, -Dw - 2.4 }, { north, Dw + 2.4, W } } do
		local f, u0, u1 = r[1], r[2], r[3]
		h:box('WallBase', f(u0, 0, 0), f(u1, 3, 0.3), K.wallLow, M.SmoothPlastic)
		h:box('WallBaseRail', f(u0, 3, 0), f(u1, 3.4, 0.5), K.cap, M.SmoothPlastic)
		h:box('WallCornice', f(u0, H - 1.4, 0), f(u1, H, 0.8), K.frame, M.SmoothPlastic)
		h:box('WallCorniceLip', f(u0, H - 1.7, 0), f(u1, H - 1.4, 0.55), K.band, M.SmoothPlastic)
	end
	-- The warehouse in the bones (kept light): a corrugated-steel band under the cornice on every wall (its ribs are
	-- shaded stripes) on a concrete ledge, and brick wainscots on the end walls (phase B's graffiti canvases)
	-- under a concrete cap.
	for _, r in { { west, N, S, Enum.NormalId.Right }, { east, N, S, Enum.NormalId.Left }, { south, -W, W, Enum.NormalId.Front }, { north, -W, W, Enum.NormalId.Back } } do
		local f, u0, u1 = r[1], r[2], r[3]
		local band = h:box('WallSteel', f(u0, 28, 0), f(u1, H - 1.6, 0.25), K.band, M.SmoothPlastic)
		Lobby.stripes(band, r[4], u1 - u0, H - 29.6, 1.5, 0.5, true, 0.68)
		h:box('WallSteelLedge', f(u0, 27.6, 0), f(u1, 28, 0.6), K.cap, M.SmoothPlastic)
	end
	for _, r in { { south, -W, W }, { north, -W, -Dw - 5.2 }, { north, Dw + 5.2, W } } do
		local f, u0, u1 = r[1], r[2], r[3]
		h:box('WallBrick', f(u0, 3.3, 0), f(u1, 12, 0.35), K.brickWall, M.Brick)
		h:box('WallBrickCap', f(u0, 12, 0), f(u1, 12.6, 0.55), K.cap, M.SmoothPlastic)
	end
	for z = N + Lobby.Bay / 2, S - 1, Lobby.Bay do
		Lobby.window(h, west, z, 14, 27)
		Lobby.window(h, east, z, 14, 27)
	end
	for _, x in { -55.5, -40.5, 40.5, 55.5 } do Lobby.window(h, south, x, 14, 27) end
	Lobby.window(h, north, 40.5, 14, 27)
	-- Pillars: every bay on the side walls, flanking the windows on the end walls.
	-- Behind the ranges the pillars are shallower; behind the ARMORY only their tops show.
	local r0 = Lobby.RangeZ0 - Lobby.RangePitch / 2
	local r1 = Lobby.RangeZ0 + (#Lobby.Ranges - 0.5) * Lobby.RangePitch
	for k = 0, 10 do
		local z = math.clamp(N + k * Lobby.Bay, N + 2.1, S - 2.1)
		local onTerrace = z > r0 - 2 and z < r1 + 2
		Lobby.wallPillar(h, V(-W, 0, z), V(1, 0, 0), onTerrace and 'range' or 'full', onTerrace and Lobby.terraceHeight(z - 1.8) or nil)
		Lobby.wallPillar(h, V(W, 0, z), V(-1, 0, 0), (z > Lobby.ArmorySpan[1] - 2 and z < Lobby.ArmorySpan[2] + 2) and 'above' or 'full')
	end
	for _, x in { -63.9, -48, -33, 33, 48, 63.9 } do Lobby.wallPillar(h, V(x, 0, S), V(0, 0, -1)) end
	-- (The north wall's pillars give way to the loading doors, the portal and TOP REBIRTHS.)
	for k, x in Lobby.LoadDoors do Lobby.loadingDoor(h, x, 'LOADING BAY ' .. (k + 1)) end
	-- The exit bay (the reference's exit, research recipe a): a framed red stage door. Two pillars on dark plinths
	-- (cream lip, cream inset panels, a lantern each, capitals at the top) frame the door and the monitor over it;
	-- a header with a cream cap, dark corbels in the opening's top corners and a cream keystone between the door
	-- and the monitor; a top beam and cap tie the pillars together; a low concrete sill with ramps under the door.
	-- One hue (Stage 1's red) in three tones; the monitor is a blue screen in a dark bezel.
	local d = h:group('ExitDoor')
	do
		local red = C(188, 72, 66)
		local dark, trim, sill = red:Lerp(P.black, 0.38), C(238, 236, 232), C(150, 152, 158)
		local x0, x1 = Dw + 0.4, Dw + 4.4 -- the pillar shafts (each side)
		local top = 33.8 -- shaft top
		d:box('DoorSill', V(-x1 - 0.2, 0, N - 1), V(x1 + 0.2, 0.3, N + 3), sill, M.SmoothPlastic)
		for _, e in { { N + 3.5, math.pi }, { N - 1.5, 0 } } do -- (a wedge is tallest at its +Z end)
			d:wedge('DoorSillRamp', V(2 * x1 + 0.4, 0.3, 1), CFrame.new(0, 0.15, e[1]) * CFrame.Angles(0, e[2], 0), sill, M.SmoothPlastic)
		end
		for _, sx in { -1, 1 } do
			local function B(name, a, b, y0, y1, z0, z1, color, mat)
				return d:box(name, V(math.min(sx * a, sx * b), y0, N + z0), V(math.max(sx * a, sx * b), y1, N + z1), color, mat or M.SmoothPlastic)
			end
			B('DoorPlinth', Dw, x1 + 0.2, 0.3, 2.6, 0, 4.4, dark) -- (stops short of the WORLD 2 portal's step)
			B('DoorPlinthLip', Dw + 0.2, x1, 2.6, 3.1, 0, 4.1, trim)
			B('DoorPillar', x0, x1, 3.1, top, 0, 3.4, red)
			B('DoorLiner', Dw - 0.4, x0, 0.3, 19.6, 0, 3.2, trim)
			local c0, c1 = (x0 + x1) / 2 - 0.6, (x0 + x1) / 2 + 0.6
			B('DoorInset', c0, c1, 4.4, 12.2, 3.4, 3.6, trim)
			B('DoorInset', c0, c1, 24.6, 32.4, 3.4, 3.6, trim)
			-- a chunky lantern: dark housing, warm bulb, cream cap
			B('DoorLantern', c0 - 0.2, c1 + 0.2, 13.4, 15.8, 3.4, 4.4, dark)
			decor(B('DoorLanternBulb', c0 + 0.15, c1 - 0.15, 13.9, 15.3, 4.4, 4.6, C(255, 214, 156), M.Neon)).CastShadow = false
			B('DoorLanternCap', c0 - 0.4, c1 + 0.4, 15.8, 16.2, 3.4, 4.8, trim)
			B('DoorCapital', x0 - 0.4, x1 + 0.2, top, top + 1, 0, 3.8, trim)
			-- a bracket holding the monitor off the pillar
			B('MonitorBracket', Dw - 0.9, x0, 28.4, 29.6, 0.5, 1.5, dark)
		end
		-- The header over the door, its corbels and keystone.
		d:box('DoorHeaderTrim', V(-Dw, 19.6, N), V(Dw, 20, N + 2.6), dark, M.SmoothPlastic)
		d:box('DoorHeader', V(-x0, 20, N), V(x0, 23.8, N + 3), red, M.SmoothPlastic)
		d:box('DoorHeaderCap', V(-x0, 23.8, N), V(x0, 24.4, N + 3.4), trim, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			d:wedge('DoorCorbel', V(2.6, 2.4, 2.4), CFrame.new(sx * (Dw - 1.2), 19.6 - 1.2, N + 1.3) * CFrame.Angles(0, sx * math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), dark, M.SmoothPlastic)
		end
		d:box('DoorKeystone', V(-1.6, 19.2, N), V(1.6, 24.9, N + 3.8), trim, M.SmoothPlastic)
		-- The monitor in the bay above: a dark bezel, a blue screen, a red "live" light.
		d:box('MonitorBezel', V(-Dw + 0.9, 24.9, N + 0.4), V(Dw - 0.9, 33.0, N + 1.6), dark, M.SmoothPlastic)
		local screen = d:box('ExitMonitor', V(-Dw + 1.6, 25.6, N + 1.6), V(Dw - 1.6, 32.3, N + 1.8), C(44, 84, 160), M.SmoothPlastic)
		local sg = surface(screen, Enum.NormalId.Back, 16)
		line(sg, 'Title', 'STAGE 1  •  THE BLOCK', P.white, FONT.loud, 0.1, 0.36, C(14, 26, 70), 3)
		line(sg, 'Sub', '💪 ' .. compact(STAGE_POWER[1]) .. ' POWER TO ENTER', C(255, 214, 90), FONT.loud, 0.54, 0.32, C(40, 24, 0), 3)
		decor(d:part('MonitorLive', V(0.7, 0.7, 0.7), CFrame.new(Dw - 1.9, 32.5, N + 1.8), C(255, 80, 70), M.Neon, Enum.PartType.Ball)).CastShadow = false
		-- The top beam and its cap across the pillars.
		d:box('DoorTopBeam', V(-x0, top - 0.6, N), V(x0, top + 1, N + 3), red, M.SmoothPlastic)
		d:box('DoorTopCap', V(-x1 - 0.2, top + 1, N), V(x1 + 0.2, top + 1.6, N + 4.2), trim, M.SmoothPlastic)
	end
	-- The hall's big signs on the steel band, like the reference's PETS and CLONE MACHINE.
	local signs = h:group('WallSigns')
	Lobby.wallSign(signs, 'RangeSign', V(-W + 2.4, 32.5, 70), V(1, 0, 0), 44, 7, 'SHOOTING RANGE', 'SHOOT TO GAIN 💪 POWER', '🎯')
	Lobby.wallSign(signs, 'ArmorySign', V(W - 2.4, 32.5, Lobby.ArmoryZ), V(-1, 0, 0), 38, 7, 'ARMORY', 'BETTER GUN = MORE POWER PER SHOT', '⭐')
	Lobby.wallSign(signs, 'ShoeBoxSign', V(0, 20.2, S - 0.9), V(0, 0, -1), 29, 7, 'SHOE BOXES', 'UNBOX FRESH KICKS • SOON', '👟')

	-- Roof: a slate ceiling, steel-blue box trusses (two along the hall, one across every bay), rows of fluorescent
	-- bars (a dark housing over a white tube) hung on wires under them. Everything up here is named Roof* (the
	-- plan view hides it).
	local r = L:group('Roof')
	-- the deck: three slate spans, their undersides ribbed (N-S), with two glass skylight strips between them
	local cx = { -W - 1, -16.5, -10.5, 10.5, 16.5, W + 1 }
	for k = 1, 5, 2 do
		local ceil = r:box('RoofCeiling', V(cx[k], H, N - 1), V(cx[k + 1], H + 0.4, S + 1), K.ceiling, M.SmoothPlastic)
		ceil.CastShadow = false
		Lobby.stripes(ceil, Enum.NormalId.Bottom, cx[k + 1] - cx[k], S - N + 2, 1.5, 0.5, true, 0.7)
	end
	for k = 2, 4, 2 do
		local x0, x1 = cx[k], cx[k + 1]
		local glass = r:box('RoofSkylight', V(x0, H + 0.05, N - 1), V(x1, H + 0.35, S + 1), C(214, 236, 255), M.Glass)
		glass.Transparency, glass.CastShadow = 0.3, false
		for _, x in { x0, x1 - 0.3 } do r:box('RoofSkylightFrame', V(x, H - 0.3, N - 1), V(x + 0.3, H + 0.05, S + 1), P.white, M.SmoothPlastic).CastShadow = false end
		for z = N + Lobby.Bay, S - 1, Lobby.Bay do r:box('RoofSkylightFrame', V(x0, H - 0.3, z - 0.15), V(x1, H + 0.05, z + 0.15), P.white, M.SmoothPlastic).CastShadow = false end
	end
	for _, x in { -40, 40 } do Lobby.truss(r, 'RoofTruss', V(x, H - 1.2, N), V(x, H - 1.2, S), K.truss) end
	for z = N + Lobby.Bay, S - 1, Lobby.Bay do Lobby.truss(r, 'RoofTruss', V(-W, H - 3.2, z), V(W, H - 3.2, z), K.truss) end
	local first = true
	for z = N + Lobby.Bay / 2, S - 1, Lobby.Bay do
		for _, x in { -27, 0, 27 } do
			-- The first row's centre bar would sit in front of the exit monitor; that row has only its side bars.
			if not (first and x == 0) then
				local y = H - 8
				r:box('RoofLampBar', V(x - 9, y, z - 0.7), V(x + 9, y + 0.5, z + 0.7), K.lamp, M.SmoothPlastic).CastShadow = false
				local tube = decor(r:box('RoofLampTube', V(x - 8.8, y - 0.2, z - 0.55), V(x + 8.8, y, z + 0.55), K.neon, M.Neon))
				tube.CastShadow = false
				for _, dx in { -7, 7 } do r:box('RoofLampWire', V(x + dx - 0.12, y + 0.5, z - 0.12), V(x + dx + 0.12, H - 0.1, z + 0.12), K.truss, M.SmoothPlastic).CastShadow = false end
				if x == 0 then light(tube, C(235, 245, 255), 0.8, 26) end
			end
		end
		first = false
	end
	Lobby.crane(r)
	Lobby.banners(r)
	return h
end
-- The yellow overhead crane at z 96: a box-girder bridge hung from the long trusses (its runways) on two end
-- trucks, hazard bands down both faces, a trolley, a chain, a red hook block with a 5 TON plate, and (phase B)
-- a pallet of crates hanging off the hook over the south-east floor panel.
function Lobby.crane(r)
	local K, H = Lobby.Colors, Lobby.H
	local z, y = 96, 33
	local yellow = C(230, 202, 104)
	r:box('RoofCraneBridge', V(-40, y - 1, z - 1.2), V(40, y + 1, z + 1.2), yellow, M.SmoothPlastic)
	-- a girder: darker flanges top and bottom (no hazard paint)
	for _, fy in { y - 1.3, y + 1 } do r:box('RoofCraneFlange', V(-40, fy, z - 1.5), V(40, fy + 0.3, z + 1.5), yellow:Lerp(P.black, 0.22), M.SmoothPlastic) end
	for _, x in { -40, 40 } do r:box('RoofCraneTruck', V(x - 1.6, y - 1.4, z - 2.2), V(x + 1.6, H - 2.2, z + 2.2), yellow:Lerp(P.black, 0.18), M.SmoothPlastic) end
	local tx = 22 -- over the south-east panel's showroom: clear of the exit, WORLD 2 and STAY GOLD sight lines
	r:box('RoofCraneTrolley', V(tx - 1.6, y - 2.2, z - 1.8), V(tx + 1.6, y - 1, z + 1.8), C(70, 76, 92), M.SmoothPlastic)
	r:bar('RoofCraneChain', V(tx, y - 2.2, z), V(tx, 28.6, z), 0.25, C(60, 62, 70), M.SmoothPlastic)
	-- the load (hook block, slings, a pallet with two crates) turns slowly on its swivel and bobs on the chain
	local ld, load = r:group('RoofCraneLoad')
	local hook = ld:box('RoofCraneHook', V(tx - 0.8, 26.8, z - 0.7), V(tx + 0.8, 28.6, z + 0.7), C(222, 44, 52), M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(hook, face, 24), 'Text', '5 TON', P.white, FONT.loud, 0.25, 0.5, C(60, 0, 0), 2) end
	local py = 22.4
	for _, dx in { -1.7, 1.7 } do
		for _, dz in { -1.5, 1.5 } do decor(ld:bar('RoofCraneSling', V(tx, 26.8, z), V(tx + dx, py + 0.8, z + dz), 0.22, C(60, 62, 70), M.SmoothPlastic)).CastShadow = false end
	end
	local pl = ld:at(CFrame.new(tx, py, z))
	pallet(pl:group('RoofCranePallet'), CFrame.new())
	crate(pl, CFrame.new(-0.9, 0.8, 0) * CFrame.Angles(0, 0.15, 0), 2.4)
	crate(pl, CFrame.new(1.1, 0.8, 0.3) * CFrame.Angles(0, -0.2, 0), 1.8)
	Lobby.motion(load, CFrame.new(tx, py, z), 6, 0.25, 3.5)
end
-- Pennant banners hanging from the cross trusses over the side aisles (never over the walkway): district
-- colours, one icon and word each.
function Lobby.banners(r)
	local H = Lobby.H
	for _, b in { { -40, 51, C(204, 76, 76), '💪', 'POWER' }, { 44.5, 51, C(66, 120, 206), '🎯', 'AIM' }, { -40, 81, C(140, 88, 206), '👑', 'BOSS' }, { 28, 81, C(224, 180, 70), '⭐', 'STAR' } } do
		local x, z = b[1], b[2]
		local panel = r:box('RoofBanner', V(x - 1.6, 23.6, z - 0.08), V(x + 1.6, 31.6, z + 0.08), b[3], M.SmoothPlastic) -- (bottoms above the sneaker wire's line)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = surface(panel, face, 16)
			line(g, 'Icon', b[4], P.white, FONT.loud, 0.06, 0.4, nil)
			line(g, 'Word', b[5], P.white, FONT.loud, 0.52, 0.2, b[3]:Lerp(P.black, 0.5), 2)
			local f = Instance.new('Frame')
			f.BorderSizePixel, f.BackgroundColor3, f.BackgroundTransparency = 0, P.white, 0
			f.Position, f.Size = UDim2.fromScale(0, 0.88), UDim2.fromScale(1, 0.04)
			f.Parent = g
		end
		r:box('RoofBannerRod', V(x - 2, 31.6, z - 0.2), V(x + 2, 32, z + 0.2), Lobby.Colors.steel, M.SmoothPlastic)
		r:box('RoofBannerWeight', V(x - 1.8, 23.3, z - 0.2), V(x + 1.8, 23.7, z + 0.2), b[3]:Lerp(P.black, 0.35), M.SmoothPlastic)
		for _, dx in { -1.8, 1.8 } do decor(r:bar('RoofBannerWire', V(x + dx, 32, z), V(x + dx, H - 4.2, z), 0.2, C(70, 72, 78), M.SmoothPlastic)).CastShadow = false end
	end
end

---------------------------------------------------------------------------------------------- floor
-- The cross walkway and its panels: the floor slab is the panels' darker studded grey; the walkway arms and the
-- side aisles are studded paint 0.12 thick over everything outside the panels (the walkway a shade lighter), so
-- the panels read recessed behind a raised white kerb. No lines, chevrons or neon on the floor.
function Lobby.floorPlan(L)
	local K, W, N, S = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S
	local f = L:group('FloorPlan')
	local xs, zs = { -W, W }, { N, S }
	for _, p in Lobby.Panels do
		table.insert(xs, p[1]); table.insert(xs, p[2]); table.insert(zs, p[3]); table.insert(zs, p[4])
	end
	local function uniq(t)
		table.sort(t)
		local out = {}
		for _, v in t do if out[#out] ~= v then table.insert(out, v) end end
		return out
	end
	xs, zs = uniq(xs), uniq(zs)
	local function inPanel(x, z)
		for _, p in Lobby.Panels do if x > p[1] and x < p[2] and z > p[3] and z < p[4] then return true end end
		return false
	end
	-- One paint strip per run of same-kind cells in each row of the grid: the cross walkway's arms (x -8..8 and z
	-- 58..74) in the light walkway grey, the side aisles in the floor grey, both 0.12 over the slab.
	local function kind(x, z)
		if inPanel(x, z) then return nil end
		return (math.abs(x) < 8 or (z > 58 and z < 74)) and 'Walkway' or 'Aisle'
	end
	for j = 1, #zs - 1 do
		local z0, z1 = zs[j], zs[j + 1]
		local run0, runKind = nil, nil
		for i = 1, #xs do
			local k = i < #xs and kind((xs[i] + xs[i + 1]) / 2, (z0 + z1) / 2) or nil
			if run0 and k ~= runKind then
				Lobby.slab(f, runKind, V(run0, 0, z0), V(xs[i], 0.12, z1), runKind == 'Walkway' and K.walk or K.floor).CastShadow = false
				run0 = nil
			end
			if k and not run0 then run0, runKind = xs[i], k end
		end
	end
	-- Each panel reads recessed: a raised white kerb (0.5 wide, 0.18 over the walkway) round its edge and a
	-- darker grey band just inside it. No neon on the floor.
	for _, p in Lobby.Panels do
		local x0, x1, z0, z1 = p[1], p[2], p[3], p[4]
		local o = 0.5
		for _, e in { { V(x0 - o, 0, z0 - o), V(x1 + o, 0.3, z0) }, { V(x0 - o, 0, z1), V(x1 + o, 0.3, z1 + o) },
			{ V(x0 - o, 0, z0), V(x0, 0.3, z1) }, { V(x1, 0, z0), V(x1 + o, 0.3, z1) } } do
			f:box('PanelKerb', e[1], e[2], K.kerb, M.SmoothPlastic).CastShadow = false
		end
		for _, e in { { V(x0, 0, z0), V(x1, 0.1, z0 + 0.9) }, { V(x0, 0, z1 - 0.9), V(x1, 0.1, z1) },
			{ V(x0, 0, z0 + 0.9), V(x0 + 0.9, 0.1, z1 - 0.9) }, { V(x1 - 0.9, 0, z0 + 0.9), V(x1, 0.1, z1 - 0.9) } } do
			decor(f:box('PanelRim', e[1], e[2], K.panelRim, M.SmoothPlastic)).CastShadow = false
		end
	end
	return f
end

---------------------------------------------------------------------------------------------- ranges
-- The ranges stand on one stepped red terrace along the west wall (the reference's capsule terrace): each lane's
-- studded base runs from the wall to the promenade's straight front edge (x -37), 1.2 higher than the lane
-- before; along the promenade each tier starts with a half step. A white (non-glowing) lip on every edge, a
-- darker red skirting along its foot. Light grey stairs: two treads up to Starter at the north end, a side stair
-- from the Heavy lane down to the cross walkway, and a grand stair off Gold's south end toward the armory, each
-- with red cheeks capped by a white rail (no stepped side profiles).
function Lobby.terraceStair(t, name, x0, x1, z0, z1, top, axis, sign)
	-- Treads from the landing at `top` down to the floor, running along axis ('x' or 'z') in direction sign;
	-- (x0..x1, z0..z1) is the whole stair's footprint. Returns the treads' rise.
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
		local B = axis == 'x' and V(hi, hgt, z1) or V(x1, hgt, hi)
		Lobby.slab(t, name, A, B, K.step)
		-- nosing on the tread's leading edge (the side facing down the stair)
		local e = sign > 0 and hi or lo
		local na = axis == 'x' and V(e - 0.25, hgt - 0.02, z0) or V(x0, hgt - 0.02, e - 0.25)
		local nb = axis == 'x' and V(e + 0.02, hgt + 0.03, z1) or V(x1, hgt + 0.03, e + 0.02)
		if sign < 0 then
			na = axis == 'x' and V(e - 0.02, hgt - 0.02, z0) or V(x0, hgt - 0.02, e - 0.02)
			nb = axis == 'x' and V(e + 0.25, hgt + 0.03, z1) or V(x1, hgt + 0.03, e + 0.25)
		end
		decor(t:box('TerraceNosing', na, nb, K.kerb, M.SmoothPlastic)).CastShadow = false
	end
	return rise
end
-- A red sloped cheek (a wedge) on a stair's open side: from `top` at z (or x) a down to 0 at b, t thick, at u.
function Lobby.stairCheek(t, axis, u0, u1, a, b, top)
	local K = Lobby.Colors
	local len = math.abs(b - a)
	local mid = (a + b) / 2
	local cf
	if axis == 'z' then
		-- slope falls toward +z when b > a: the wedge's high back edge must face a
		cf = CFrame.new((u0 + u1) / 2, top / 2, mid) * CFrame.Angles(0, b > a and math.pi or 0, 0)
		t:wedge('TerraceCheek', V(math.abs(u1 - u0), top, len), cf, K.carpet, M.Plastic)
	else
		cf = CFrame.new(mid, top / 2, (u0 + u1) / 2) * CFrame.Angles(0, b > a and -math.pi / 2 or math.pi / 2, 0)
		t:wedge('TerraceCheek', V(math.abs(u1 - u0), top, len), cf, K.carpet, M.Plastic)
	end
	-- a white rail capping the cheek's sloped top edge
	local p0 = axis == 'z' and V((u0 + u1) / 2, top + 0.08, a) or V(a, top + 0.08, (u0 + u1) / 2)
	local p1 = axis == 'z' and V((u0 + u1) / 2, 0.12, b) or V(b, 0.12, (u0 + u1) / 2)
	decor(t:part('TerraceNosing', V(0.6, 0.2, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), K.kerb, M.SmoothPlastic)).CastShadow = false
end
function Lobby.rangeRow(L, skins)
	local K, W = Lobby.Colors, Lobby.W
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	local t = L:group('RangeTerrace')
	local XS, XF = Lobby.RangeX + 10, Lobby.TerraceX -- the shooter's end (-43) and the promenade's front (-37)
	local hz, rise, n = Lobby.RangePitch / 2, Lobby.RangeRise, #Lobby.Ranges
	local function nose(a, b) decor(t:box('TerraceNosing', a, b, K.kerb, M.SmoothPlastic)).CastShadow = false end
	local zN = Lobby.RangeZ0 - hz -- the terrace's north end (28.75)
	local zS = Lobby.RangeZ0 + (n - 0.5) * Lobby.RangePitch -- its south end (112.75)
	for i, id in Lobby.Ranges do
		local z = Lobby.RangeZ0 + (i - 1) * Lobby.RangePitch
		local h = i * rise
		local z0, z1 = z - hz, z + hz
		if i == 1 then
			Lobby.slab(t, 'TerraceBase', V(-W, 0, z0), V(XF, h, z1), K.carpet)
		else
			-- under the lane, full height; on the promenade the first stud is a half step
			Lobby.slab(t, 'TerraceBase', V(-W, 0, z0), V(XS, h, z1), K.carpet)
			Lobby.slab(t, 'TerraceBase', V(XS, 0, z0 + 1), V(XF, h, z1), K.carpet)
			Lobby.slab(t, 'TerraceStep', V(XS, 0, z0), V(XF, h - rise / 2, z0 + 1), K.carpet)
			nose(V(XS, h - rise / 2 - 0.02, z0 - 0.02), V(XF, h - rise / 2 + 0.03, z0 + 0.25))
			nose(V(XS, h - 0.02, z0 + 0.98), V(XF, h + 0.03, z0 + 1.25))
		end
		-- the promenade's front edge
		nose(V(XF - 0.25, h - 0.02, i == 1 and z0 or z0 + 1), V(XF + 0.02, h + 0.03, z1))
		local cf = CFrame.new(Lobby.RangeX, h, z) * CFrame.Angles(0, -math.pi / 2, 0)
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Range_' .. id, cf, { X = 9, Y = 12, Z0 = -10, Z1 = 10 }, string.upper(s and s.Name or id), C(90, 200, 120),
			Stations and function(c) Stations.build(c, id, {}) end)
	end
	-- Gold's south face toward the armory: nosing along its top.
	nose(V(-W, n * rise - 0.02, zS - 0.02), V(XS, n * rise + 0.03, zS + 0.25))
	-- North stair to Starter, across the terrace's whole width.
	Lobby.terraceStair(t, 'TerraceStair', -W, XF, zN - 2, zN, rise, 'z', -1)
	-- Side stair from the Heavy lane down to the cross walkway (6 wide), red cheeks both sides.
	local si = Lobby.SideStair
	local sz, sh = Lobby.RangeZ0 + (si - 1) * Lobby.RangePitch, si * rise
	Lobby.terraceStair(t, 'TerraceStair', XF, XF + 4, sz - 3, sz + 3, sh, 'x', 1)
	for _, u in { sz - 3.4, sz + 3 } do Lobby.stairCheek(t, 'x', u, u + 0.4, XF, XF + 5, sh) end
	-- Grand stair off Gold's south end (x -43..-37), red cheeks both sides.
	Lobby.terraceStair(t, 'TerraceStair', XS + 0.4, XF - 0.4, zS, zS + 9, n * rise, 'z', 1)
	for _, u in { XS, XF - 0.4 } do Lobby.stairCheek(t, 'z', u, u + 0.4, zS, zS + 10, n * rise) end
	-- A darker red skirting along the terrace's foot (broken by the side stair): the terrace's base course.
	for _, seg in { { zN, sz - 3.4 }, { sz + 3.4, zS } } do
		t:box('TerraceSkirt', V(XF - 0.2, 0, seg[1]), V(XF + 0.25, 0.55, seg[2]), K.carpetDark, M.SmoothPlastic).CastShadow = false
	end
	Lobby.terraceDressing(t, skins, XS, XF, zN, zS, sz, n, rise)
end
-- The terrace's vertical rhythm and its faces: red glass stall dividers between the lanes (the reference's
-- capsules as booth partitions, stepping up 1.2 a tier), each on a steel front post with a dark foot; a
-- BAY n stencil plate on every tier's front (with its Power requirement from tier 3 up) and white seams at the
-- tier joints; a BAY 8 • GOLD plate on the grand stair's east cheek. (No floor chevrons or hazard paint.)
function Lobby.terraceDressing(t, skins, XS, XF, zN, zS, sz, n, rise)
	local K = Lobby.Colors
	local pitch = Lobby.RangePitch
	local fins = { zN + 0.25 }
	for k = 1, n - 1 do table.insert(fins, zN + k * pitch - 0.45) end
	table.insert(fins, zS - 0.35)
	local postX = XS - 0.6
	for _, fz in fins do
		local tier = math.clamp(math.floor((fz - zN) / pitch) + 1, 1, n)
		local base, top = tier * rise, tier * rise + 7
		local glass = t:box('StallFin', V(-52, base, fz - 0.2), V(postX - 0.6, top, fz + 0.2), C(218, 92, 92), M.Glass)
		glass.Transparency, glass.CastShadow = 0.45, false
		t:box('StallFinCap', V(-52, top, fz - 0.25), V(postX, top + 0.35, fz + 0.25), P.white, M.SmoothPlastic)
		t:box('StallPost', V(postX - 0.6, base, fz - 0.3), V(postX, top, fz + 0.3), K.steel, M.SmoothPlastic)
		decor(t:box('StallPostFoot', V(postX - 0.65, base, fz - 0.35), V(postX + 0.05, base + 0.6, fz + 0.35), K.pillarDark, M.SmoothPlastic)).CastShadow = false
	end
	-- BAY plates and tier seams on the front face
	for i, id in Lobby.Ranges do
		local h = i * rise
		local z = Lobby.RangeZ0 + (i - 1) * pitch
		local ph = math.min(h - 0.4, 2.2)
		local y1 = h - 0.35
		local s = skins.StationById[id]
		local rows
		if i >= 3 and s and s.Required then
			rows = { { 'Bay', 'BAY ' .. i, P.white, FONT.loud, 0.04, 0.5, C(90, 10, 20), 2 }, { 'Req', '💪 ' .. compact(s.Required), K.gold, FONT.loud, 0.54, 0.42, C(60, 20, 0), 2 } }
		else
			rows = { { 'Bay', 'BAY ' .. i, P.white, FONT.loud, 0.06, 0.88, C(90, 10, 20), 2 } }
		end
		local cy = y1 - ph / 2
		local pcf = CFrame.lookAt(V(XF + 0.45, cy, z), V(XF + 10, cy, z))
		local pw = i >= 3 and 6.4 or 5
		t:part('BayPlateBack', V(pw + 0.5, math.min(ph + 0.4, h - 0.1), 0.25), pcf * CFrame.new(0, 0, 0.2), K.carpetDark:Lerp(P.black, 0.25), M.SmoothPlastic)
		Lobby.board(t, 'BayPlate', pcf, pw, ph, C(150, 62, 64), rows, 20)
		if i == 1 then
			Lobby.board(t, 'FreeChip', CFrame.lookAt(V(XF + 0.45, cy, z + 3.9), V(XF + 10, cy, z + 3.9)), 2.6, ph, C(72, 166, 96), { { 'Text', 'FREE', P.white, FONT.loud, 0.06, 0.88, C(10, 70, 20), 2 } }, 20)
		end
		if i >= 2 then
			local z0 = z - pitch / 2
			decor(t:box('TerraceSeam', V(XF - 0.05, 0, z0 + 0.85), V(XF + 0.06, h - 0.3, z0 + 1.15), P.white, M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the grand stair's east cheek: a BAY 8 plate at its tall end
	Lobby.board(t, 'BayPlate', CFrame.lookAt(V(XF + 0.12, 3.6, zS + 2.6), V(XF + 10, 3.6, zS + 2.6)), 4.2, 1.6, C(150, 62, 64),
		{ { 'Bay', 'BAY 8 • GOLD', K.gold, FONT.loud, 0.1, 0.8, C(60, 20, 0), 2 } }, 24)
end

---------------------------------------------------------------------------------------------- shoe box dais
-- The back wall's centre (the reference's PETS / egg dais): a stepped studded podium rising to the centre (1.2,
-- 2.4, 3.6) with cyan neon edges and a COMING SOON plate across its riser, big cartoon shoe boxes floating and
-- turning over pedestals - COMMON and RARE up the left, the LEGENDARY on top (lid ajar, a high-top peeking out, a
-- warm light), EPIC on the right, a stack of plain boxes on the right foot - each with a nameplate, the SHOE BOXES
-- sign on the wall just above (made in Lobby.hall). One ComingSoon prompt ("Shoe Boxes"); no unboxing yet.
-- Lobby.Slots.ShoeBoxes is the dais's front centre on the floor, facing the hall; Lobby.SlotSizes.ShoeBoxes its
-- size (local x -19..19, y up to 14, z 0..17.2).
Lobby.ShoeDais = { X = 19, Z0 = 138.8 }
Lobby.SlotSizes = {}
Lobby.ShoeBoxes = {
	{ Name = 'COMMON', Color = C(150, 158, 176), Trim = C(236, 238, 244), X = 15.8, Z = 144, Level = 1 },
	{ Name = 'RARE', Color = C(72, 132, 220), Trim = C(176, 212, 250), X = 8.4, Z = 147.2, Level = 2 },
	{ Name = 'LEGENDARY', Color = C(240, 190, 60), Trim = C(255, 240, 170), X = 0, Z = 149.6, Level = 3, Hero = true },
	{ Name = 'EPIC', Color = C(146, 96, 214), Trim = C(220, 186, 250), X = -8.4, Z = 147.2, Level = 2 },
}
-- One shoe box (local: centre bottom at the origin, front -Z): a body in the rarity colour with two slanted side
-- stripes and the rarity word on the front, pink tissue paper showing over the rim, a white lid that overhangs and
-- sits a little lifted, a band of the rarity colour round it and a big 👟 on its top. ajar: the lid tips open at
-- the back and a high-top peeks out.
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
	line(surface(face, Enum.NormalId.Front, 20), 'Rarity', b.Name, P.white, FONT.loud, 0.2, 0.6, b.Color:Lerp(P.black, 0.5), 2)
	-- tissue paper peeking over the rim, crinkled into three puffs
	for j = -1, 1 do
		c:part('ShoeBoxTissue', V(1.7, 0.5, 3.0) * k, CFrame.new(V(j * 1.55, 2.4, 0) * k) * CFrame.Angles(0, 0, math.rad(j * 9)), C(255, 222, 236), M.SmoothPlastic)
	end
	local lc = ajar and (CFrame.new(V(0, 2.75, 1.85) * k) * CFrame.Angles(math.rad(32), 0, 0) * CFrame.new(V(0, 0, -1.9) * k)) or CFrame.new(V(0, 2.75, 0) * k)
	local lid = c:part('ShoeBoxLid', V(5.4, 0.7, 3.8) * k, lc * CFrame.new(V(0, 0.35, 0) * k), C(246, 246, 250), M.SmoothPlastic)
	c:part('ShoeBoxLidBand', V(5.44, 0.14, 3.84) * k, lc * CFrame.new(V(0, 0.07, 0) * k), b.Color:Lerp(P.white, 0.1), M.SmoothPlastic)
	local top = surface(lid, Enum.NormalId.Top, 16)
	line(top, 'Logo', '👟', P.white, FONT.loud, 0.12, 0.76)
	line(surface(lid, Enum.NormalId.Front, 20), 'Brand', 'KICKS', b.Color:Lerp(P.black, 0.25), FONT.loud, 0.04, 0.68)
	if ajar then
		-- a high-top peeking out under the open lid
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
	local K, S = Lobby.Colors, Lobby.S
	local d0 = Lobby.ShoeDais
	local X, z0 = d0.X, d0.Z0
	local d = L:group('ShoeBoxDais')
	-- the stepped podium: a dark 0.6 step, the base (1.2), the middle riser (2.4), the top block (3.6), light
	-- grey studded tops with a pink lip (not neon) along every tier's top edge
	local pink = C(212, 122, 166)
	local pinkD = pink:Lerp(P.black, 0.35)
	studs(d:box('ShoeDaisStep', V(-X + 2, 0, z0 - 1.2), V(X - 2, 0.6, z0), K.stepDark, M.Plastic))
	local levels = { { X, z0, 1.2 }, { 11.2, z0 + 4.6, 2.4 }, { 3.8, z0 + 7.4, 3.6 } }
	-- each tier: a pastel pink riser under a light grey studded top, a white lip along its top edges
	local riser = C(214, 152, 184)
	for i, l in levels do
		d:box('ShoeDais', V(-l[1], 0, l[2]), V(l[1], l[3] - 0.3, S), riser, M.SmoothPlastic)
		studs(d:box('ShoeDaisTop', V(-l[1], l[3] - 0.3, l[2]), V(l[1], l[3], S), i == 2 and K.dais:Lerp(P.white, 0.25) or K.dais, M.Plastic))
		local n0, n1 = l[3] - 0.35, l[3] + 0.05
		if i == 2 then n0 = l[3] - 0.12 end -- (a thinner lip: the COMING SOON plate sits under it)
		d:box('ShoeDaisLip', V(-l[1] - 0.2, n0, l[2] - 0.25), V(l[1] + 0.2, n1, l[2] + 0.4), K.kerb, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			local a, b = sx * (l[1] - 0.4), sx * (l[1] + 0.2)
			d:box('ShoeDaisLip', V(math.min(a, b), l[3] - 0.35, l[2]), V(math.max(a, b), l[3] + 0.05, S), K.kerb, M.SmoothPlastic)
		end
	end
	-- COMING SOON across the middle riser's face, under the boxes: a framed pink plate
	local rz = levels[2][2]
	local pcf = CFrame.lookAt(V(0, 1.77, rz - 0.3), V(0, 1.77, 0))
	d:part('ShoeSoonBack', V(16.8, 1.15, 0.3), pcf * CFrame.new(0, 0, 0.12), pinkD, M.SmoothPlastic)
	Lobby.board(d, 'ShoeSoonPlate', pcf * CFrame.new(0, 0, -0.08), 16, 0.95, pink,
		{ { 'Text', 'COMING SOON', P.white, FONT.loud, 0.04, 0.92, pinkD:Lerp(P.black, 0.4), 2 } }, 30)
	-- the boxes on their pedestals (a hex foot in the rarity's dark, a white rim, a top in the rarity colour with a
	-- glowing ring inset)
	for i, b in Lobby.ShoeBoxes do
		local ly = levels[b.Level][3]
		local base = V(b.X, ly, b.Z)
		local pd = d:at(CFrame.new(base))
		Lobby.poly(pd, 'ShoeBoxPedestal', 6, 6.6, 0, 0.3, b.Color:Lerp(P.black, 0.35))
		Lobby.disc(pd, 'ShoeBoxPedestal', 6, 0.3, 0.5, 0, 0, C(238, 240, 244))
		Lobby.disc(pd, 'ShoeBoxPedestal', 5.4, 0.5, 0.66, 0, 0, b.Color)
		decor(Lobby.disc(pd, 'ShoeBoxPedestalRing', 4.4, 0.66, 0.7, 0, 0, b.Color:Lerp(P.white, 0.35), M.Neon)).CastShadow = false
		Lobby.disc(pd, 'ShoeBoxPedestal', 3.6, 0.66, 0.72, 0, 0, b.Color)
		local k = b.Hero and 1.6 or 1.15 -- (the turning boxes keep clear of each other and of the legendary)
		local hover = base + V(0, 0.72 + 0.6, 0)
		local bc, box = d:at(CFrame.new(hover) * CFrame.Angles(0, math.rad(b.Hero and 0 or (b.X > 0 and 14 or -14)), 0)):group('ShoeBox')
		Lobby.shoeBox(bc, b, k, b.Hero)
		Lobby.motion(box, CFrame.new(hover), b.Hero and nil or 12, 0.25, 2.4 + i * 0.2)
		-- the nameplate, in the armory's style
		local nb = billboard(d, hover + V(0, 3.4 * k + 1.6, 0), 5, 1.6, {
			{ 'Name', b.Name, b.Color:Lerp(P.white, 0.15), FONT.loud, 0, 0.62 },
			{ 'Soon', 'SOON', P.white, FONT.loud, 0.62, 0.38 },
		})
		nb.WorldLabel.MaxDistance = 80
		if b.Hero then
			local fx = Lobby.emitBox(d, 'ShoeBoxFx', hover + V(-4, 0.5, -3), hover + V(4, 6, 3))
			Lobby.fx(fx, 'ShoeBoxGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1),
				Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.8 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 120)), LightEmission = 1 })
			light(fx, C(255, 210, 90), 1.6, 16)
			-- a soft gold beam rising out of the open box (short, so it stays under the SHOE BOXES sign)
			local beam = decor(d:part('ShoeBoxBeam', V(5, 3.4, 3.4), CFrame.new(hover + V(0, 3.2 * k + 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 226, 120), M.Neon, Enum.PartType.Cylinder))
			beam.Transparency, beam.CastShadow = 0.72, false
		end
	end
	-- the display frame: two grey pillars at the dais's back corners (dark plinth, pink inset, light capital) and a
	-- header beam under the SHOE BOXES sign, so the dais reads as one framed booth against the wall
	for _, sx in { -1, 1 } do
		local x = sx * 17.6
		d:box('ShoeFramePlinth', V(x - 1.4, 1.2, S - 3.2), V(x + 1.4, 2.6, S), K.pillarDark, M.SmoothPlastic)
		d:box('ShoeFramePillar', V(x - 1, 2.6, S - 2.8), V(x + 1, 13.4, S), K.pillar, M.SmoothPlastic)
		d:box('ShoeFrameInset', V(x - 0.4, 3.6, S - 2.95), V(x + 0.4, 12.4, S - 2.75), pink, M.SmoothPlastic)
		d:box('ShoeFrameCapital', V(x - 1.4, 13.4, S - 3.2), V(x + 1.4, 14, S), K.cap, M.SmoothPlastic)
	end
	-- (the SHOE BOXES sign sits on this beam)
	d:box('ShoeFrameHeader', V(-19, 14, S - 2.8), V(19, 15, S), K.pillar, M.SmoothPlastic)
	d:box('ShoeFrameHeaderTrim', V(-16.6, 13.7, S - 2.6), V(16.6, 14, S - 0.2), pink, M.SmoothPlastic)
	-- the stock: a stack of plain closed boxes on the right foot
	local st = d:at(CFrame.new(-14.6, 1.2, 145) * CFrame.Angles(0, math.rad(8), 0))
	for j, e in { { V(-1.6, 0, 0), C(232, 214, 186) }, { V(1.7, 0, 0.3), C(222, 204, 176) }, { V(0, 1.9, 0.1), C(236, 220, 192) } } do
		local sc = st:at(CFrame.new(e[1]) * CFrame.Angles(0, math.rad(j * 7 - 10), 0))
		sc:box('StockBox', V(-1.5, 0, -1.05), V(1.5, 1.5, 1.05), e[2], M.SmoothPlastic)
		sc:box('StockBoxLid', V(-1.6, 1.5, -1.12), V(1.6, 1.9, 1.12), C(246, 246, 250), M.SmoothPlastic)
		sc:box('StockBoxStripe', V(-1.62, 1.55, -0.25), V(1.62, 1.92, 0.25), ({ C(230, 40, 52), C(50, 130, 240), C(255, 190, 30) })[j], M.SmoothPlastic)
	end
	-- the prompt (coming soon), on the dais's front edge
	local hit = ghost(d:box('ShoeBoxPrompt', V(-4, 1.2, z0 + 0.4), V(4, 4.2, z0 + 2), P.white))
	Lobby.prompt(hit, 'Open', 'Shoe Boxes').MaxActivationDistance = 14
	Lobby.Slots.ShoeBoxes = CFrame.new(0, 0, z0 - 1.2)
	Lobby.SlotSizes.ShoeBoxes = V(2 * X, 14, S - z0 + 1.2)
	return d
end

---------------------------------------------------------------------------------------------- spawn badge
-- A crisp regular polygon slab (n = 6 or 8) from n/2 boxes turned about the centre: flat-to-flat F, from y0 to
-- y1, centred on the context's origin; flats face the context's axes. The research's faceted low-poly pad.
function Lobby.poly(c, name, n, F, y0, y1, color, mat)
	local side = F * math.tan(math.pi / n)
	local parts = {}
	for k = 0, n / 2 - 1 do
		table.insert(parts, c:part(name, V(F, y1 - y0, side), CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, k * 2 * math.pi / n, 0), color, mat or M.SmoothPlastic))
	end
	return parts
end
-- An upright cylinder (a disc when flat) of diameter d from y0 to y1 at pos (x, z) in a context.
function Lobby.disc(c, name, d, y0, y1, x, z, color, mat)
	return c:part(name, V(y1 - y0, d, d), CFrame.new(x or 0, (y0 + y1) / 2, z or 0) * CFrame.Angles(0, 0, math.pi / 2), color, mat or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- The spawn (research recipe e, "block-party stage"): a three-tier octagon dais at the crossing (dark grey base,
-- white lip, a muted-blue top), our medallion on it (white ring, deep-blue disc, a slowly turning gold star and the
-- red "+1" core), four lamp bollards on the diagonals, a bevelled step toward the exit and one small arrow on the
-- top pointing to Stage 1. The spawn faces south down the hall (a little toward the ranges).
function Lobby.badge(L)
	local D, cz = Lobby.Deck, Lobby.CrossZ
	local b = L:at(CFrame.new(0, D, cz)):group('SpawnBadge')
	local dark, pale, blue = C(122, 124, 132), C(232, 233, 237), C(104, 130, 184)
	local blueD, gold, red = C(70, 88, 132), C(232, 184, 64), C(196, 74, 72)
	Lobby.poly(b, 'SpawnTier', 8, 20, 0, 0.6, dark)
	Lobby.poly(b, 'SpawnTier', 8, 18.4, 0.6, 1.0, pale)
	Lobby.poly(b, 'SpawnTier', 8, 17, 1.0, 1.3, blue)
	-- the bevelled step on the exit side (north, -Z)
	b:wedge('SpawnStep', V(6, 0.6, 1.4), CFrame.new(0, 0.3, -10.7), pale, M.SmoothPlastic)
	-- the medallion
	decor(Lobby.disc(b, 'BadgeRing', 8.4, 1.3, 1.42, 0, 0, pale)).CastShadow = false
	decor(Lobby.disc(b, 'BadgeInner', 7, 1.3, 1.5, 0, 0, blueD)).CastShadow = false
	local st, star = b:group('BadgeSpin')
	for k = 0, 1 do
		decor(st:part('BadgeStar', V(5.2, 0.14, 5.2), CFrame.new(0, 1.55, 0) * CFrame.Angles(0, math.pi / 8 + k * math.pi / 4, 0), gold, M.SmoothPlastic)).CastShadow = false
	end
	Lobby.motion(star, CFrame.new(0, D + 1.55, cz), 12)
	decor(Lobby.disc(b, 'BadgeDisc', 3.6, 1.5, 1.72, 0, 0, red)).CastShadow = false
	local face = ghost(b:part('BadgeText', V(3.2, 0.02, 3.2), CFrame.new(0, 1.76, 0) * CFrame.Angles(0, math.pi, 0), P.white)) -- its up points south: upright from the spawn camera
	face.CastShadow = false
	line(surface(face, Enum.NormalId.Top, 40), 'Text', '+1', P.white, FONT.loud, 0.12, 0.76, C(90, 10, 20), 4)
	-- one small arrow on the top, by the exit side, pointing to Stage 1
	local arrow = ghost(b:part('SpawnArrow', V(2.2, 0.02, 1.8), CFrame.new(0, 1.32, -6.6), P.white))
	line(surface(arrow, Enum.NormalId.Top, 30), 'Arrow', '▲', pale, FONT.loud, 0.02, 0.96, blueD, 3)
	-- lamp bollards on the diagonals: a dark post, a white collar, a warm bulb
	for _, a in { 45, 135, 225, 315 } do
		local x, z = 9.3 * math.cos(math.rad(a)), 9.3 * math.sin(math.rad(a))
		Lobby.disc(b, 'SpawnBollard', 1.3, 0.6, 3.0, x, z, dark)
		Lobby.disc(b, 'SpawnBollardCollar', 1.6, 3.0, 3.3, x, z, pale)
		decor(Lobby.disc(b, 'SpawnBollardBulb', 1.1, 3.3, 3.95, x, z, C(255, 236, 200), M.Neon)).CastShadow = false
	end
	-- Rising glints off the medallion (a soft "you are here") and a warm light over it.
	local fxBox = Lobby.emitBox(b, 'BadgeFx', V(-3.8, 1.6, -3.8), V(3.8, 2, 3.8))
	Lobby.fx(fxBox, 'BadgeGlints', 'sparkle', { Rate = 4, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1.5, 2.5),
		Size = Lobby.seq({ { 0, 0.45 }, { 1, 0 } }), Transparency = Lobby.seq({ { 0, 0.3 }, { 1, 1 } }), Color = ColorSequence.new(C(255, 236, 170)),
		LightEmission = 0.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10) })
	light(ghost(b:part('SpawnLight', V(0.4, 0.4, 0.4), CFrame.new(0, 9, 0), P.white)), C(255, 238, 210), 0.9, 18)
	-- The spawn point itself (StageService and SetActive use it).
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(12, 0.2, 12)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 1.42, 0)) * CFrame.Angles(0, math.pi - math.rad(12), 0) -- on the dais top (1.3)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = b.parent
	-- Back to where you got to, for returning players: off the main walk, on the south-east floor panel's corner
	-- by the crossing, on its own low octagon stop (a dark kerb under a light apron), its arch walked through from
	-- the walkway (west); the pad's look is d_kit's teleportPad.
	local stop = L:at(Lobby.FurthestAt):group('FurthestStop')
	Lobby.poly(stop, 'FurthestStopKerb', 8, 11.6, 0, 0.22, C(150, 152, 160))
	Lobby.poly(stop, 'FurthestStopApron', 8, 10.8, 0.22, 0.3, C(226, 227, 231))
	teleportPad(L:at(Lobby.FurthestAt * CFrame.new(0, 0.3, 0)), 'FurthestPad', 0, 0, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
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
	l:box('RoofLampChain', pos + V(-0.08, 1.3, -0.08), V(pos.X + 0.08, Lobby.H - 0.6, pos.Z + 0.08), K.truss, M.Metal)
	l:post('RoofLampCap', 0.45, 0.6, pos + V(0, 1.0, 0), K.steel, M.SmoothPlastic)
	l:post('RoofLampShade', 1.5, 0.5, pos + V(0, 0.5, 0), C(236, 232, 220), M.SmoothPlastic)
	l:post('RoofLampSkirt', 2.0, 0.35, pos + V(0, 0.15, 0), K.truss, M.SmoothPlastic)
	local bulb = decor(l:post('RoofLampBulb', 1.2, 0.25, pos + V(0, -0.05, 0), color, M.Neon))
	bulb.CastShadow = false
	light(bulb, color, 1.1, 26)
	return l
end
-- Big ceiling fan under a truss (spins via HoodMotion).
function Lobby.ceilingFan(c, x, z, rate)
	local K = Lobby.Colors
	local y = Lobby.H - 6
	local f, model = c:group('RoofFan')
	f:box('RoofFanRod', V(x - 0.15, y + 0.5, z - 0.15), V(x + 0.15, Lobby.H - 0.6, z + 0.15), K.steel, M.SmoothPlastic)
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
	for j, e in { { 4.4, K.gold }, { 3.6, K.red }, { 2.4, P.white }, { 1.2, K.red } } do
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
-- A reward stand's plinth (research recipe h): a dark base, a light lip, the top in the reward's hue with bevel
-- wedges on its four edges, and a thin glowing ring inset on the top (claimable). w square; returns the top y.
function Lobby.rewardBase(r, w, hue, glow)
	local Dk, Lt = hue:Lerp(P.black, 0.35), hue:Lerp(P.white, 0.6)
	r:box('RewardBase', V(-w / 2, 0, -w / 2), V(w / 2, 0.8, w / 2), Dk, M.SmoothPlastic)
	r:box('RewardLip', V(-w / 2 + 0.3, 0.8, -w / 2 + 0.3), V(w / 2 - 0.3, 1.1, w / 2 - 0.3), Lt, M.SmoothPlastic)
	local tw = w - 1.6
	r:box('RewardTop', V(-tw / 2, 1.1, -tw / 2), V(tw / 2, 1.6, tw / 2), hue, M.SmoothPlastic)
	for k = 0, 3 do
		-- a bevel on each top edge: the wedge's slope runs from the lip up to the top's face
		r:wedge('RewardBevel', V(tw, 0.5, 0.5), CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 1.35, -tw / 2 - 0.25), hue, M.SmoothPlastic)
	end
	local gw, o = tw - 1.2, 0.4
	for _, e in { { -gw / 2, gw / 2, -gw / 2, -gw / 2 + o }, { -gw / 2, gw / 2, gw / 2 - o, gw / 2 }, { -gw / 2, -gw / 2 + o, -gw / 2 + o, gw / 2 - o }, { gw / 2 - o, gw / 2, -gw / 2 + o, gw / 2 - o } } do
		decor(r:box('RewardGlow', V(e[1], 1.6, e[3]), V(e[2], 1.68, e[4]), glow or hue:Lerp(P.white, 0.45), M.Neon)).CastShadow = false
	end
	return 1.6
end
-- A framed hue board on two posts (sign recipe i): dark back, the face in the hue with white text, a light cap.
-- cf: the board's centre, front along its LookVector; posts drop from it to y = base (in the same frame).
function Lobby.rewardSign(r, cf, w, h, hue, title, sub, base)
	local Dk, Lt = hue:Lerp(P.black, 0.35), hue:Lerp(P.white, 0.6)
	r:part('RewardSignBack', V(w + 0.6, h + 0.6, 0.5), cf * CFrame.new(0, 0, 0.3), Dk, M.SmoothPlastic)
	local rows = { { 'Title', title, P.white, FONT.loud, sub and 0.04 or 0.1, sub and 0.6 or 0.8, Dk:Lerp(P.black, 0.4), 3 } }
	if sub then table.insert(rows, { 'Status', sub, C(170, 255, 170), FONT.loud, 0.64, 0.32, Dk:Lerp(P.black, 0.4), 2 }) end
	Lobby.board(r, 'RewardSign', cf, w, h, hue, rows, 24)
	r:part('RewardSignCap', V(w + 1, 0.4, 0.9), cf * CFrame.new(0, h / 2 + 0.5, 0.25), Lt, M.SmoothPlastic)
	if base then
		local yTop = (cf * CFrame.new(0, -h / 2 - 0.3, 0)).Y
		for _, sx in { -1, 1 } do
			local p = cf * CFrame.new(sx * (w / 2 - 0.8), 0, 0.6)
			r:box('RewardSignPost', V(p.X - 0.3, base, p.Z - 0.3), V(p.X + 0.3, yTop, p.Z + 0.3), Dk, M.SmoothPlastic)
		end
	end
end
-- Reward stands by the walls (decor with "coming soon" prompts), each on a reward plinth with a framed sign:
-- the DAILY CRATE (a red treasure chest with a peaked lid and gold bands, on a gold plinth), LUCKY SHOT (a
-- bullseye wheel turning in a blue frame under its header board) and the VIP SAFE (a purple safe on feet with a
-- dial, a handle and a gold VIP plate). Each has one soft light and a few glints; no light pillars.
-- A context that builds everything k times bigger about its origin (sizes and offsets; rotations kept).
function Lobby.scaled(c, k)
	local o = {}
	local function sc(cf) return cf - cf.Position + cf.Position * k end
	function o:box(name, a, b, ...) return c:box(name, a * k, b * k, ...) end
	function o:part(name, size, cf, ...) return c:part(name, size * k, sc(cf), ...) end
	function o:wedge(name, size, cf, ...) return c:wedge(name, size * k, sc(cf), ...) end
	return o
end
function Lobby.rewards(L)
	local goldTrim = C(226, 182, 72)
	-- DAILY CRATE (x1.25 on a 12.5 plinth)
	local k = 1.25
	local r = L:at(Lobby.RewardAt.DailyCrate):group('DailyCrate')
	local top = Lobby.rewardBase(r, 10 * k, C(222, 178, 84), C(255, 232, 160))
	local red = C(200, 84, 76)
	local c = Lobby.scaled(r:at(CFrame.new(0, top, 0.4)), k)
	local body = c:box('CrateBody', V(-3.6, 0, -2.4), V(3.6, 3.6, 2.4), red, M.SmoothPlastic)
	c:box('CrateLid', V(-3.75, 3.6, -2.55), V(3.75, 4.6, 2.55), red:Lerp(P.white, 0.08), M.SmoothPlastic)
	c:wedge('CrateLidSlope', V(7.5, 1.2, 2.55), CFrame.new(0, 5.2, -1.275), red:Lerp(P.white, 0.08), M.SmoothPlastic)
	c:wedge('CrateLidSlope', V(7.5, 1.2, 2.55), CFrame.new(0, 5.2, 1.275) * CFrame.Angles(0, math.pi, 0), red:Lerp(P.white, 0.08), M.SmoothPlastic)
	for _, x in { -2.3, 2.3 } do
		c:box('CrateBand', V(x - 0.4, -0.05, -2.55), V(x + 0.4, 3.6, 2.55), goldTrim, M.SmoothPlastic)
		c:box('CrateBand', V(x - 0.4, 3.6, -2.7), V(x + 0.4, 4.7, 2.7), goldTrim, M.SmoothPlastic)
	end
	c:box('CrateSeam', V(-3.85, 3.35, -2.65), V(3.85, 3.85, 2.65), goldTrim, M.SmoothPlastic)
	c:box('CrateLock', V(-0.75, 2.6, -2.95), V(0.75, 4.3, -2.5), goldTrim, M.SmoothPlastic)
	c:box('CrateKeyhole', V(-0.22, 3.0, -3.0), V(0.22, 3.6, -2.9), red:Lerp(P.black, 0.5), M.SmoothPlastic)
	Lobby.prompt(body, 'Open', 'Daily Crate')
	Lobby.rewardSign(r, CFrame.new(0, top + 7.8 * k, 3.7 * k), 8 * k, 2.4 * k, red, 'DAILY CRATE', 'COMING SOON', top)
	local fx = Lobby.emitBox(c, 'CrateFx', V(-3.4, 3.4, -2.6), V(3.4, 4.4, 2.6))
	Lobby.fx(fx, 'CrateGlints', 'sparkle', { Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.8 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 230, 140)), LightEmission = 0.6 })
	light(fx, C(255, 214, 120), 1, 12)
	-- LUCKY SHOT (x1.2): a bullseye wheel turning between two posts under a header board, a gold pointer over it
	k = 1.2
	local g = L:at(Lobby.RewardAt.LuckyShot):group('LuckyShot')
	local blue = C(88, 128, 200)
	local bD, bL = blue:Lerp(P.black, 0.35), blue:Lerp(P.white, 0.6)
	top = Lobby.rewardBase(g, 10 * k, blue)
	local gc = Lobby.scaled(g:at(CFrame.new(0, top, 0)), k)
	for _, sx in { -1, 1 } do
		gc:box('WheelPostFoot', V(sx * 4.3 - 1, 0, -1), V(sx * 4.3 + 1, 1, 1), bD, M.SmoothPlastic)
		gc:box('WheelPost', V(sx * 4.3 - 0.6, 1, -0.6), V(sx * 4.3 + 0.6, 10.4, 0.6), blue, M.SmoothPlastic)
	end
	gc:box('WheelHeaderBack', V(-5.8, 10.4, -0.8), V(5.8, 13.2, 0.8), bD, M.SmoothPlastic)
	local hb = gc:box('WheelHeader', V(-5.4, 10.7, -1.0), V(5.4, 12.9, 1.0), blue, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(hb, face, 24), 'Title', 'LUCKY SHOT', P.white, FONT.loud, 0.1, 0.8, bD:Lerp(P.black, 0.4), 3) end
	gc:box('WheelHeaderCap', V(-6.2, 13.2, -1.1), V(6.2, 13.7, 1.1), bL, M.SmoothPlastic)
	local hub = CFrame.new(0, 5.6, 0)
	gc:part('WheelAxle', V(8, 0.8, 0.8), hub, bD, M.SmoothPlastic, Enum.PartType.Cylinder)
	local tgc, target = g:at(CFrame.new(0, top, 0)):group('Target')
	local tg = Lobby.scaled(tgc, k)
	for j, e in { { 7.2, goldTrim }, { 6, C(204, 74, 70) }, { 4.4, P.white }, { 2.8, C(204, 74, 70) } } do
		tg:part('TargetRing', V(0.5 + j * 0.1, e[1], e[1]), hub * CFrame.Angles(0, math.pi / 2, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for a = 0, 1 do
		decor(tg:part('TargetStar', V(1.2, 1.2, 1.1), hub * CFrame.Angles(0, 0, math.pi / 4 * a), C(255, 232, 150), M.Neon)).CastShadow = false
	end
	-- (the wheel turns in its own plane: the pivot's Y axis along the axle's normal, Z)
	Lobby.motion(target, Lobby.RewardAt.LuckyShot * CFrame.new(0, top + 5.6 * k, 0) * CFrame.Angles(math.pi / 2, 0, 0), 30)
	gc:part('WheelPointer', V(1.1, 1.1, 1.2), CFrame.new(0, 9.9, 0) * CFrame.Angles(0, 0, math.pi / 4), goldTrim, M.SmoothPlastic) -- a diamond, tip down
	Lobby.prompt(ghost(gc:box('TargetHit', V(-3.6, 0, -1.5), V(3.6, 9, 1.5), P.white)), 'Spin', 'Lucky Shot')
	local glow = Lobby.emitBox(gc, 'TargetFx', V(-3, 2.5, -1), V(3, 8.5, 1))
	Lobby.fx(glow, 'TargetGlitter', 'glitter', { Rate = 5, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0.5 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 224, 120)), LightEmission = 0.6 })
	light(glow, C(255, 214, 120), 0.9, 12)
	-- VIP SAFE (x1.2): a purple safe on four feet, a light door frame, a dial, a three-part handle, a framed sign
	local v = L:at(Lobby.RewardAt.VipSafe):group('VipSafe')
	local purple = C(140, 100, 200)
	local pD, pL = purple:Lerp(P.black, 0.35), purple:Lerp(P.white, 0.6)
	top = Lobby.rewardBase(v, 10.6, purple) -- (between TOP REBIRTHS' foot and the loading door's jamb)
	local vc = Lobby.scaled(v:at(CFrame.new(0, top, 0)), k)
	for _, x in { -2.3, 2.3 } do for _, z in { -1.8, 1.8 } do vc:box('SafeFoot', V(x - 0.5, 0, z - 0.5), V(x + 0.5, 0.6, z + 0.5), pD, M.SmoothPlastic) end end
	local y0 = 0.6
	local safe = vc:box('SafeBody', V(-3, y0, -2.5), V(3, y0 + 6.4, 2.5), purple, M.SmoothPlastic)
	vc:box('SafeCap', V(-3.25, y0 + 6.4, -2.75), V(3.25, y0 + 6.9, 2.75), pL, M.SmoothPlastic)
	vc:box('SafeDoorFrame', V(-2.5, y0 + 0.6, -2.7), V(2.5, y0 + 5.8, -2.5), pL, M.SmoothPlastic)
	vc:box('SafeDoor', V(-2.1, y0 + 1, -2.85), V(2.1, y0 + 5.4, -2.6), purple:Lerp(P.white, 0.12), M.SmoothPlastic)
	vc:part('SafeDial', V(0.4, 2.2, 2.2), CFrame.new(-0.6, y0 + 3.6, -3.0) * CFrame.Angles(0, math.pi / 2, 0), pD, M.SmoothPlastic, Enum.PartType.Cylinder)
	vc:part('SafeDialFace', V(0.5, 1.5, 1.5), CFrame.new(-0.6, y0 + 3.6, -3.05) * CFrame.Angles(0, math.pi / 2, 0), goldTrim, M.SmoothPlastic, Enum.PartType.Cylinder)
	for _, y in { 2.4, 4.8 } do vc:box('SafeHandleArm', V(1.2, y0 + y - 0.3, -3.3), V(1.8, y0 + y + 0.3, -2.8), pD, M.SmoothPlastic) end
	vc:box('SafeHandle', V(1.2, y0 + 2.1, -3.7), V(1.8, y0 + 5.1, -3.2), goldTrim, M.SmoothPlastic)
	Lobby.prompt(safe, 'Open', 'VIP Safe')
	Lobby.rewardSign(v, CFrame.new(0, top + (y0 + 8.9) * k, 0.6 * k), 6.4 * k, 2 * k, purple, '👑 VIP SAFE', nil, top + (y0 + 6.9) * k)
	local vf = Lobby.emitBox(vc, 'SafeFx', V(-3, y0 + 1, -3.4), V(3, y0 + 6, -3))
	light(vf, C(214, 180, 255), 0.8, 10)
end

-- The WORLD 2 portal (research recipes a and b), locked: a blue block-stone arch. A two-step base with bevelled
-- nosing, two pillars on dark plinths (cream lip, inset panel, a lantern each, two-tone capitals), seven arch stones
-- in two blues round a cream keystone, a framed WORLD 2 board on top. Inside: a cream liner round a glowing cyan
-- face with a slowly turning violet swirl, crossed by two chunky chain bars with a gold padlock, and a framed
-- COMING SOON board on legs in front. One hue (blue) in three tones; neon only on the face, the swirl and the bulbs.
function Lobby.portal(L, cf)
	cf = cf * CFrame.new(1, 0, 0) -- (1 stud west of the slot: clear of the exit door's pillar and the LUCKY SHOT base)
	local p = L:at(cf):group('World2Portal')
	local blue = C(70, 120, 198)
	local dark, trim, stone, grey = blue:Lerp(P.black, 0.38), C(238, 236, 232), blue:Lerp(P.white, 0.16), C(112, 114, 122)
	local face, violet = C(108, 168, 222), C(136, 98, 204) -- (face kept at S ~0.5: neon brightens it a lot)
	local function B(name, a, b, color, mat) return p:box(name, a, b, color, mat or M.SmoothPlastic) end
	local function glow(part, t)
		decor(part).CastShadow = false
		part.Transparency = t or 0
		return part
	end
	local along = CFrame.Angles(0, math.pi / 2, 0) -- (cylinders lie along X; this turns them to face the hall)
	-- base: two steps with bevelled fronts, up against the wall (the nosing stops at the floor panel's kerb)
	B('PortalStep', V(-11.2, 0, -3.9), V(11.2, 0.6, 4.8), grey)
	B('PortalStep', V(-10.2, 0.6, -3.3), V(10.2, 1.2, 4.8), trim)
	p:wedge('PortalNosing', V(22.4, 0.6, 0.6), CFrame.new(0, 0.3, -4.2), grey, M.SmoothPlastic)
	p:wedge('PortalNosing', V(20.4, 0.6, 0.6), CFrame.new(0, 0.9, -3.6), trim, M.SmoothPlastic)
	-- pillars
	for _, sx in { -1, 1 } do
		local function X(name, a, b, y0, y1, z0, z1, color, mat)
			return B(name, V(math.min(sx * a, sx * b), y0, z0), V(math.max(sx * a, sx * b), y1, z1), color, mat)
		end
		X('PortalPlinth', 6.2, 11, 1.2, 3.4, -2.4, 2.4, dark)
		X('PortalPlinthLip', 6.4, 10.8, 3.4, 3.9, -2.2, 2.2, trim)
		X('PortalPillar', 6.8, 10.4, 3.9, 17.2, -1.8, 1.8, blue)
		X('PortalInset', 8, 9.2, 5, 9.6, -2, -1.8, trim)
		X('PortalLantern', 7.9, 9.3, 10.4, 12.8, -2.8, -1.8, dark)
		glow(X('PortalLanternBulb', 8.25, 8.95, 10.9, 12.3, -3.0, -2.8, C(130, 196, 236), M.Neon))
		X('PortalLanternCap', 7.7, 9.5, 12.8, 13.2, -3.2, -1.8, trim)
		X('PortalCapital', 6.4, 10.8, 15.6, 16.6, -2.2, 2.2, trim)
		X('PortalCapital', 6.2, 11, 16.6, 17.2, -2.4, 2.4, dark)
	end
	-- the arch: seven stones on a half circle (inner radius 6.8, outer 10.4), the keystone bigger and cream
	local hub, R0, R1 = V(0, 17.2, 0), 6.8, 10.4
	for j = 0, 6 do
		local a = math.pi * (j + 0.5) / 7
		local key = j == 3
		local rm = key and (R0 + 2.2) or (R0 + R1) / 2
		local size = key and V(5.2, 4.4, 4.6) or V(4.7, R1 - R0, 4)
		p:part(key and 'PortalKeystone' or 'PortalArch', size, CFrame.new(hub + V(math.cos(a) * rm, math.sin(a) * rm, 0)) * CFrame.Angles(0, 0, a - math.pi / 2),
			key and trim or (j % 2 == 0 and blue or stone), M.SmoothPlastic)
	end
	-- the face: a cream liner, the glowing face in front of it (a box plus a disc for the round top)
	B('PortalLiner', V(-R0, 1.2, 0.6), V(R0, 17.2, 1.0), trim)
	p:part('PortalLiner', V(0.4, 2 * R0, 2 * R0), CFrame.new(0, 17.2, 0.8) * along, trim, M.SmoothPlastic, Enum.PartType.Cylinder)
	local glowFace = glow(B('PortalGlow', V(-R0 + 0.7, 1.2, 0.2), V(R0 - 0.7, 17.2, 0.6), face, M.Neon))
	glow(p:part('PortalGlow', V(0.4, 2 * R0 - 1.4, 2 * R0 - 1.4), CFrame.new(0, 17.2, 0.4) * along, face, M.Neon, Enum.PartType.Cylinder))
	light(glowFace, face, 1.2, 18)
	-- the swirl: a violet disc, a bright core, four bent arms turning slowly (HoodMotion)
	local sw, swirl = p:group('PortalSwirl')
	local mid = CFrame.new(0, 11, 0)
	glow(sw:part('SwirlDisc', V(0.1, 10, 10), mid * CFrame.new(0, 0, 0.05) * along, violet, M.Neon, Enum.PartType.Cylinder), 0.1)
	glow(sw:part('SwirlEye', V(0.12, 3, 3), mid * CFrame.new(0, 0, -0.08) * along, C(236, 246, 255), M.Neon, Enum.PartType.Cylinder))
	for j = 0, 3 do
		local arm = mid * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, j * math.pi / 2)
		glow(sw:part('SwirlArm', V(1.1, 2.4, 0.14), arm * CFrame.new(0, 2.1, 0), C(214, 190, 255), M.Neon), 0.15)
		glow(sw:part('SwirlArm', V(1.0, 2.0, 0.14), arm * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(40)) * CFrame.new(0, 0.9, 0), C(214, 190, 255), M.Neon), 0.15)
	end
	Lobby.motion(swirl, cf * mid * CFrame.Angles(-math.pi / 2, 0, 0), 60)
	-- locked: two chain bars crossed over the face and a gold padlock where they cross
	local steel = C(150, 156, 170)
	for _, sx in { -1, 1 } do
		local a, b = V(sx * -5.6, 2.6, -1), V(sx * 5.6, 19.4, -1)
		decor(p:part('PortalChain', V(0.9, 0.9, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), steel, M.SmoothPlastic))
	end
	local gold = C(226, 182, 76)
	B('PortalLock', V(-1.6, 9.2, -2.3), V(1.6, 12.2, -1.1), gold)
	B('PortalLock', V(-0.3, 10.0, -2.4), V(0.3, 11.1, -2.25), gold:Lerp(P.black, 0.55))
	for _, sx in { -1, 1 } do B('PortalLockShackle', V(sx * 1.05 - 0.3, 12.2, -1.95), V(sx * 1.05 + 0.3, 13.6, -1.45), steel) end
	B('PortalLockShackle', V(-1.35, 13.6, -1.95), V(1.35, 14.2, -1.45), steel)
	-- the COMING SOON board on two legs on the top step
	for _, sx in { -1, 1 } do B('PortalPlateLeg', V(sx * 3.4 - 0.3, 1.2, -3.0), V(sx * 3.4 + 0.3, 2.4, -2.4), dark) end
	B('PortalPlateBack', V(-4.8, 2.4, -3.1), V(4.8, 5.4, -2.3), dark)
	local plate = B('PortalPlate', V(-4.4, 2.75, -3.25), V(4.4, 5.05, -3.1), trim)
	local pg = surface(plate, Enum.NormalId.Front, 20)
	line(pg, 'Title', '🔒 COMING SOON', dark, FONT.loud, 0.16, 0.68, P.white, 2)
	B('PortalPlateCap', V(-5.1, 5.4, -3.25), V(5.1, 5.8, -2.15), blue)
	-- the WORLD 2 board on the keystone
	local top = 17.2 + R0 + 4.4 - 0.4
	B('World2SignBack', V(-7.6, top, -0.5), V(7.6, top + 4.6, 0.5), dark)
	local sign = B('World2Sign', V(-7, top + 0.4, -0.8), V(7, top + 4.2, -0.5), blue)
	sign.Name = 'World2Sign'
	line(surface(sign, Enum.NormalId.Front, 16), 'Title', 'WORLD 2', P.white, FONT.loud, 0.1, 0.8, dark, 4)
	B('World2SignCap', V(-8, top + 4.6, -0.9), V(8, top + 5.1, 0.7), trim)
	-- the prompt (HUD toasts "World 2 is coming soon!")
	local zone = B('World2Gate', V(-6, 1.2, -3.9), V(6, 1.4, -1), face)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	-- Particles: a little mist creeping out under the face, sparks drifting off it.
	local mist = Lobby.emitBox(p, 'PortalFx', V(-6, 1.4, -2), V(6, 2.2, -0.6))
	Lobby.fx(mist, 'PortalMist', 'mist', { Rate = 8, Lifetime = NumberRange.new(1.8, 3), Speed = NumberRange.new(0.8, 2),
		Size = Lobby.seq({ { 0, 1.4 }, { 1, 3.4 } }), Transparency = Lobby.seq({ { 0, 0.6 }, { 1, 1 } }), Color = ColorSequence.new(C(160, 220, 245)),
		LightEmission = 0.5, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 10), Drag = 1 })
	local spiral = Lobby.emitBox(p, 'PortalSpiralFx', V(-5, 3, -0.6), V(5, 18, -0.2))
	Lobby.fx(spiral, 'PortalSpiral', 'sparkle', { Rate = 8, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5),
		Size = Lobby.seq({ { 0, 0.5 }, { 1, 0 } }), Color = ColorSequence.new(C(210, 190, 255), C(170, 230, 255)), LightEmission = 0.6,
		EmissionDirection = Enum.NormalId.Front })
	return p
end

-- People in the range are SkinArt figures (Art.posed: block R15 parts, each look carrying its own prop in its
-- left hand). Poses in SkinArt.Poses' shape: {out, forward, elbow bend, twist} per limb (forward = toward the
-- figure's front).
Lobby.Poses = {
	-- Two-handed aim straight ahead: the right arm level, the left arm crossing in under it.
	aim = { LeftArm = { -22, 80, 10 }, RightArm = { -4, 90 }, LeftLeg = { 5, 10 }, RightLeg = { 5, -8 } },
	-- The kingpin: a gold pistol raised high (the near arm, tilted toward the walkway), the other hand on the hip.
	kingpin = { LeftArm = { 160, 25 }, RightArm = { 30, -10, 70, 80 }, LeftLeg = { 6, 0 }, RightLeg = { 6, 0 } },
	-- The range officer: one arm pointing across at the ranges, the other at his side.
	officer = { LeftArm = { 4, 0 }, RightArm = { 70, 30 }, LeftLeg = { 3, 0 }, RightLeg = { 3, 0 }, Head = -10 },
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
-- Recolour a GunModels gun gold (its Foil renders olive indoors): SmoothPlastic body, a deeper grip (and frame,
-- when frame is given), neon gems.
function Lobby.goldGun(gun, body, frame)
	local deep = C(222, 150, 28)
	for _, d in gun:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency < 1 then
			if d.Name == 'Gem' then
				d.Material = M.Neon
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
-- A GunModels pistol in a figure's hand, the muzzle out along the arm; a 3-part block pistol without GunModels.
-- roll: turn the gun about its barrel (the statue's raised pistol shows its side to the front).
function Lobby.handGun(fig, side, scale, id, light, roll)
	local hand = Lobby.limb(fig, side .. 'Hand', side .. 'Arm')
	if not hand then return nil end
	local grip = hand.Name:find('Hand') and hand.CFrame or hand.CFrame * CFrame.new(0, -1.05 * scale, 0)
	-- The gun's -Z (muzzle) along the hand's -Y (out of the fist).
	local at = grip * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, 0, roll or 0)
	local okGun, Guns = pcall(function() return require(ReplicatedStorage.Shared.Models.GunModels) end)
	if okGun and Guns and Guns.build then
		local okBuild, gun = pcall(Guns.build, id or 'Pistol', scale)
		if okBuild and gun then
			gun:PivotTo(at)
			if light then
				for _, d in gun:GetDescendants() do
					if d:IsA('BasePart') and (d.Name == 'Slide' or d.Name == 'Frame' or d.Name == 'Barrel' or d.Name == 'Serration') then d.Material, d.Color = M.SmoothPlastic, light end
				end
			end
			gun.Parent = fig
			return gun
		end
	end
	for _, e in { { 'GunGrip', V(0.3, 0.6, 0.3), CFrame.new(0, 0, 0.15) }, { 'GunSlide', V(0.32, 0.3, 1.1), CFrame.new(0, -0.35, -0.3) * CFrame.Angles(math.pi / 2, 0, 0) } } do
		local q = Lobby.worldPart(fig, e[1], e[2] * scale, grip * CFrame.new(e[3].Position * scale) * (e[3] - e[3].Position), light or C(200, 204, 212))
		q.CanCollide, q.CanQuery, q.CanTouch = false, false, false
	end
	return nil
end

-- The KINGPIN: a giant gold figure (SkinArt's top look: crown, suit, chain) holding a gold deagle high, on a
-- plinth (red base, white top, gold trim) with a cyan uplight. Two-tone gold (suit and a pale
-- shirt, tie and lapels) with a dark face so the eyes and shades read. Falls back to a block figure without
-- SkinArt.
function Lobby.statue(L, cf, skins)
	local K = Lobby.Colors
	local s, model = L:at(cf):group('KingpinStatue')
	local head, suit, pale, ink = C(246, 206, 106), C(232, 182, 84), C(250, 234, 180), C(90, 50, 10)
	-- The plinth, layered: a dark grey octagon base, a red block with a gold lip, a cream top with a dark lip, a
	-- framed gold plaque on the front and two warm uplights on the base's front corners.
	local red, trim, cream = C(184, 96, 92), C(226, 182, 72), C(238, 234, 226)
	Lobby.poly(s, 'PlinthBase', 8, 15.4, 0, 0.8, C(118, 120, 128))
	s:box('Plinth', V(-6.2, 0.8, -6.2), V(6.2, 2.8, 6.2), red, M.SmoothPlastic)
	s:box('PlinthTrim', V(-6.5, 2.8, -6.5), V(6.5, 3.1, 6.5), trim, M.SmoothPlastic)
	s:box('PlinthTop', V(-5.9, 3.1, -5.9), V(5.9, 3.6, 5.9), cream, M.SmoothPlastic)
	s:box('PlaqueBack', V(-4.4, 1.0, -6.45), V(4.4, 2.6, -6.2), red:Lerp(P.black, 0.4), M.SmoothPlastic)
	local plaque = s:box('Plaque', V(-4.1, 1.15, -6.6), V(4.1, 2.45, -6.45), trim, M.SmoothPlastic)
	line(surface(plaque, Enum.NormalId.Front, 30), 'Text', 'THE KINGPIN', C(150, 50, 46), FONT.loud, 0.1, 0.8, P.white, 2)
	for _, sx in { -1, 1 } do
		s:box('UplightHousing', V(sx * 5.2 - 0.7, 0.8, -6.9), V(sx * 5.2 + 0.7, 1.5, -5.7), C(80, 82, 90), M.SmoothPlastic)
		decor(s:box('UplightLens', V(sx * 5.2 - 0.55, 1.5, -6.75), V(sx * 5.2 + 0.55, 1.6, -5.85), C(255, 236, 200), M.Neon)).CastShadow = false
	end
	local top, scale = 3.6, 4.5
	local base = V2.Origin * s.cf * CFrame.new(0, top, 0)
	local kingpin = skins.ById.Kingpin or skins.List[#skins.List]
	local fig = Lobby.figure(model, base, kingpin, scale, Lobby.Poses.kingpin)
	if fig then
		fig.Name = 'KingpinFigure'
		-- No sceptre: the gold deagle goes in that hand.
		Lobby.stripProp(fig, kingpin)
		local paleParts = { DressShirt = true, TailoredLapel = true, Tie = true, TieKnot = true, ShirtCuff = true, ShadesGlint = true, EyeGlint = true }
		-- Face features stay dark so the eyes, shades and smirk read (old and new SkinArt names).
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
		-- The gold deagle (GunModels) in the raised hand, muzzle up along the arm, pale gold against the suit.
		-- (a size up from the hand, so it reads at the statue's scale; pale slide over a bronze frame so it reads
		-- against both the gold suit and the sky)
		local gun = Lobby.handGun(fig, 'Left', scale * 1.35, 'Deagle', nil, math.pi / 2)
		if gun then
			gun.Name = 'GoldDeagle'
			Lobby.goldGun(gun, C(255, 232, 150), C(190, 110, 20))
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
	-- A warm uplight and glints.
	local lamp = Lobby.emitBox(s, 'StatueFx', V(-6, 6, -3), V(6, 28, 3))
	light(lamp, C(255, 222, 160), 1.2, 24)
	Lobby.fx(lamp, 'StatueGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 0.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 1.1 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 240, 200)), LightEmission = 1 })
	return s
end

-- People: two regulars on the practice lane in the south-west yard (aiming pistols at bottles, cans and a
-- bullseye board on a plank fence), the range officer in hi-vis at the runner's west end, and a kid by the
-- walkway stairs waving at the spawn. Nobody stands downrange of a lane.
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
	for _, z in { 126.5, 134, 141.5 } do g:box('FencePost', V(fx - 0.3, 0.12, z - 0.3), V(fx + 0.3, 4.2, z + 0.3), C(150, 96, 52), M.SmoothPlastic) end
	g:box('FenceRail', V(fx - 0.6, 3.6, 126), V(fx + 0.6, 4, 142), C(196, 128, 68), M.SmoothPlastic)
	local cols = { C(60, 200, 90), C(80, 170, 255), C(255, 190, 40), C(222, 44, 52) }
	for k2, z in { 127.5, 129.5, 131.5, 136.5, 138.5, 140.5 } do
		if k2 % 2 == 1 then
			g:post('Bottle', 0.35, 1.3, V(fx, 4, z), cols[k2 % 4 + 1], M.Glass)
		else
			g:post('Can', 0.4, 0.8, V(fx, 4, z), cols[k2 % 4 + 1], M.SmoothPlastic)
		end
	end
	local board = CFrame.new(fx - 1.5, 6.2, 130.5)
	for j, e in { { 6, P.white }, { 4.6, K.red }, { 3.2, P.white }, { 1.8, K.red } } do
		g:part('BoardRing', V(0.3 + j * 0.06, e[1], e[1]), board * CFrame.new(j * 0.03, 0, 0), e[2], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	g:box('BoardLeg', V(fx - 1.9, 0.12, 130.2), V(fx - 1.3, 4, 130.8), C(150, 96, 52), M.SmoothPlastic)
	for _, z in { 129, 138 } do
		local id = z == 129 and 'Hustler' or 'GetawayDriver'
		local fig = person('Shooter' .. z, id, nil, V(lx + 2.2, 0.12, z), V(fx, 0.12, z), Lobby.Poses.aim)
		if fig then
			Lobby.stripProp(fig, skins.ById[id] or skins.List[1])
			Lobby.handGun(fig, 'Right', 1.3, 'Pistol', C(200, 204, 212))
		end
	end
	-- The range officer: the Runner look (his headphones read as ear defenders) in a lime hi-vis jacket with two
	-- white reflective bands and a whistle on a lanyard; he smiles and points across at the ranges.
	local D = Lobby.Deck
	local base = skins.ById.Pickpocket or skins.List[1]
	local okc, oskin = pcall(table.clone, base)
	if okc and oskin then
		oskin.Id, oskin.Color, oskin.Expression = 'RangeOfficer', C(196, 230, 96), 'happy'
		local frame = CFrame.lookAt(V(-46.5, D, Lobby.CrossZ), V(0, D, Lobby.CrossZ))
		local officer = Lobby.figure(model, V2.Origin * frame, oskin, 1.1, Lobby.Poses.officer)
		if officer then
			Lobby.stripProp(officer, oskin)
			local torso = Lobby.limb(officer, 'UpperTorso', 'Torso')
			if torso then
				for _, y in { 0.15, -0.35 } do
					local band = Lobby.worldPart(officer, 'ReflectiveBand', V(2.08, 0.18, 1.08) * 1.1, torso.CFrame * CFrame.new(0, y * 1.1, 0), P.white)
					band.CanCollide, band.CanQuery, band.CanTouch = false, false, false
				end
				local cord = Lobby.worldPart(officer, 'Lanyard', V(0.08, 0.7, 0.06) * 1.1, torso.CFrame * CFrame.new(0, 0.3 * 1.1, -0.53 * 1.1), K.red)
				cord.CanCollide = false
				local whistle = Lobby.worldPart(officer, 'Whistle', V(0.3, 0.2, 0.2) * 1.1, torso.CFrame * CFrame.new(0, -0.1 * 1.1, -0.58 * 1.1), K.gold)
				whistle.CanCollide = false
			end
			Lobby.motion(officer, frame, nil, 0.12, 2.4)
		end
	end
	-- A kid hanging out by the Daily Crate, waving at the spawn.
	-- (beside the walkway stairs on the north-east turf: in the spawn frame, in no lane's line of fire)
	person('Waver', 'CornerKid', C(72, 168, 104), V(7.5, 0.12, 25), V(0, 0.12, 60), 'wave', 0.15, 1.6)
	return g
end

-- Leaderboard (research recipe g, "billboard on legs", about 18 x 27): two dark legs on feet with wedge braces
-- behind, the board leaning back 6 degrees between them: a dark back slab, a white frame face with chunky corner
-- blocks, a navy screen, a header plate in the board's one hue under a light cap, capped posts, and a medallion
-- with the board's icon breaking the top line. `live` names the model LobbyService writes into (a TextLabel named
-- TextLabel): ServerLeaderboard (top Power, a bobbing gold crown for its topper) or CashLeaderboard. Without it
-- the board shows a season teaser.
function Lobby.leaderboard(L, cf, title, accent, live, icon)
	local b, model = L:at(cf):group(live or 'Leaderboard')
	local M0, Dk, Lt = accent, accent:Lerp(P.black, 0.35), accent:Lerp(P.white, 0.55)
	local face, navy = C(236, 237, 240), C(32, 42, 74)
	local px = 7.9
	for _, sx in { -1, 1 } do
		b:box('BoardFoot', V(sx * px - 1.3, 0, -1.4), V(sx * px + 1.3, 0.6, 3.4), Dk, M.SmoothPlastic)
		b:wedge('BoardBrace', V(1.2, 3, 2.4), CFrame.new(sx * px, 2.1, 2.0) * CFrame.Angles(0, math.pi, 0), Dk, M.SmoothPlastic)
	end
	-- the leaning board (pivot on the feet)
	local t = b:at(CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(6), 0, 0))
	for _, sx in { -1, 1 } do
		t:box('BoardPost', V(sx * px - 0.7, -0.6, -0.7), V(sx * px + 0.7, 22, 0.7), Dk, M.SmoothPlastic)
		t:box('BoardPostCap', V(sx * px - 1, 22, -1), V(sx * px + 1, 22.6, 1), Lt, M.SmoothPlastic)
	end
	t:box('BoardBack', V(-7.6, 2.6, -0.4), V(7.6, 19.4, 0.6), Dk, M.SmoothPlastic)
	t:box('BoardFrame', V(-7.1, 3, -0.7), V(7.1, 19, -0.4), face, M.SmoothPlastic)
	local screen = t:box('BoardScreen', V(-6.3, 3.8, -0.9), V(6.3, 16.6, -0.7), navy, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, y in { 3.6, 18.4 } do t:box('BoardCorner', V(sx * 6.7 - 0.8, y - 0.8, -1.3), V(sx * 6.7 + 0.8, y + 0.8, -0.4), Lt, M.SmoothPlastic) end
	end
	local header = t:box('BoardHeader', V(-8.6, 19.4, -1.1), V(8.6, 22.4, 0.6), M0, M.SmoothPlastic)
	line(surface(header, Enum.NormalId.Front, 20), 'Title', title, P.white, FONT.loud, 0.1, 0.8, Dk:Lerp(P.black, 0.45), 3)
	t:box('BoardHeaderCap', V(-9, 22.4, -1.4), V(9, 22.9, 0.9), Lt, M.SmoothPlastic)
	t:box('BoardHeaderTrim', V(-8.3, 19.1, -1.3), V(8.3, 19.4, 0.4), Dk, M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	if live then
		local text = line(g, 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, FONT.body, 0.05, 0.9, P.black, 1)
		text.TextYAlignment = Enum.TextYAlignment.Top
	else
		-- Not wired yet: a season teaser instead of empty rows.
		line(g, 'Crowns', '👑 👑 👑 👑 👑', Lobby.Colors.gold, FONT.loud, 0.1, 0.22, P.black, 1)
		line(g, 'Rows', 'SEASON 1', Lobby.Colors.gold, FONT.loud, 0.38, 0.24, P.black, 2)
		line(g, 'Soon', 'TOP 5 SOON', P.white, FONT.loud, 0.66, 0.2, P.black, 2)
	end
	if live == 'ServerLeaderboard' then
		-- the topper: a gold crown turning and bobbing over the header
		local cr, crown = b:group('Crown')
		local gold = Lobby.Colors.gold
		local top = CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(6), 0, 0) * CFrame.new(0, 24.4, -0.3)
		cr:part('CrownBand', V(6, 1.8, 6), top, gold, M.SmoothPlastic)
		cr:part('CrownBandLip', V(6.4, 0.5, 6.4), top * CFrame.new(0, -0.9, 0), gold:Lerp(P.black, 0.25), M.SmoothPlastic)
		for _, e in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
			cr:part('CrownPoint', V(1.3, 2.6, 1.3), top * CFrame.new(e[1], 2.1, e[2]) * CFrame.Angles(0, math.pi / 4, 0), gold, M.SmoothPlastic)
			decor(cr:part('CrownGem', V(1, 1, 1), top * CFrame.new(e[1], 3.6, e[2]), C(236, 80, 104), M.Neon, Enum.PartType.Ball))
		end
		Lobby.motion(crown, cf * top, 45, 0.5)
	else
		-- the topper: a medallion (light ring, a disc in the board's hue) with the board's icon
		local m = t:at(CFrame.new(0, 24.4, -0.3))
		m:part('BoardMedal', V(0.9, 4.6, 4.6), CFrame.Angles(0, math.pi / 2, 0), Lt, M.SmoothPlastic, Enum.PartType.Cylinder)
		m:part('BoardMedalFace', V(1.1, 3.6, 3.6), CFrame.Angles(0, math.pi / 2, 0), M0, M.SmoothPlastic, Enum.PartType.Cylinder)
		local ic = ghost(m:part('BoardMedalIcon', V(2.8, 2.8, 0.1), CFrame.new(0, 0, -0.62), P.white))
		line(surface(ic, Enum.NormalId.Front, 30), 'Icon', icon or '★', P.white, FONT.loud, 0.02, 0.96, Dk, 2)
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

---------------------------------------------------------------------------------------------- hood life
-- Phase B: the hood moves into the clean hall in clusters, never on the walkways. A street-ball corner in the
-- south-west (wall hoop, painted court and key, balls, two kids and a boombox), graffiti on the loading doors,
-- the brick wainscot and the terrace's Gold end, sneakers hanging off a wire across the hall over the spawn,
-- the loading bays (a dumpster behind a chain-link fence, milk crates, cones, hydrants), a BLOCK AVE street
-- sign at the exit, a corner store in the south-east, and a lowrider turning on a showroom turntable in the
-- south-east floor panel. Kid-friendly: no gang signs, nothing aimed at anyone, only snacks and soda.
Lobby.Tag = {
	pink = C(236, 100, 176), cyan = C(84, 206, 236), lime = C(148, 212, 84), orange = C(240, 152, 68),
	purple = C(146, 102, 236), yellow = C(246, 212, 78), white = C(255, 255, 255), ink = C(30, 24, 48),
}
-- A graffiti piece on a ghost panel in front of a wall: pieces = { {kind, ...}, ... } in the panel's 0-1 space.
--   { 'splash', x, y, w, h, color, alpha }            a spray-fill rectangle
--   { 'word', text, x, y, w, h, color, outline, font }  bubble letters with a thick outline
--   { 'drips', x, y, w, n, len, color }                n drips hanging from y across x..x+w
function Lobby.mural(c, name, cf, w, h, pieces)
	local panel = ghost(c:part(name, V(w, h, 0.1), cf, P.white))
	panel.CastShadow = false
	local g = surface(panel, Enum.NormalId.Front, 16)
	g.Name = 'Graffiti'
	g.LightInfluence = 0.6
	for _, p in pieces do
		if p[1] == 'splash' or p[1] == 'drips' then
			local n = p[1] == 'drips' and p[5] or 1
			for k = 1, n do
				local f = Instance.new('Frame')
				f.Name = 'Spray'
				f.BorderSizePixel = 0
				if p[1] == 'splash' then
					f.Position, f.Size = UDim2.fromScale(p[2], p[3]), UDim2.fromScale(p[4], p[5])
					f.BackgroundColor3, f.BackgroundTransparency = p[6], p[7] or 0.25
				else
					local x = p[2] + (k - 0.5) / n * p[4]
					local len = p[6] * (0.5 + ((k * 37) % 10) / 20)
					f.Position, f.Size = UDim2.fromScale(x, p[3]), UDim2.fromScale(0.012, len)
					f.BackgroundColor3, f.BackgroundTransparency = p[7], 0.1
				end
				f.Parent = g
			end
		elseif p[1] == 'word' then
			local t = line(g, 'Tag', p[2], p[7], p[9] or FONT.tag, p[4], p[6], p[8] or Lobby.Tag.ink, 6)
			t.Position, t.Size = UDim2.fromScale(p[3], p[4]), UDim2.fromScale(p[5], p[6])
		end
	end
	return panel
end

-- Basketball (r 0.9 at scale 1) with its black seams.
function Lobby.ball(c, pos, s)
	s = s or 1
	c:part('Basketball', V(1.8, 1.8, 1.8) * s, CFrame.new(pos), C(240, 116, 36), M.SmoothPlastic, Enum.PartType.Ball)
	for _, r in { CFrame.Angles(0, 0, 0), CFrame.Angles(0, 0, math.pi / 2) } do
		decor(c:part('BallSeam', V(0.06, 1.84, 1.84) * s, CFrame.new(pos) * r * CFrame.Angles(0, math.rad(30), 0), C(40, 24, 18), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- The street-ball court (south-west, between the KINGPIN statue and the armory dais, in view down the hall): a
-- hoop on the south wall over a painted half court with its key, a ball on the court and one in a kid's hands, a
-- boombox on a milk crate with a second kid dancing by it, party bulbs strung along the wall, BLOCK BALLERS on the
-- brick under the hoop and STAY GOLD up on the steel band above the court (it flags the court from the spawn).
function Lobby.courtCorner(c, skins)
	local K, T, S = Lobby.Colors, Lobby.Tag, Lobby.S
	local g = c:group('StreetCourt')
	local x0, x1, z0, z1 = -46.6, -29.6, 132.6, S - 0.4
	local xc = -40.5
	-- the court: blue sport paint, white boundary, a red key with a free-throw line and a half circle
	decor(g:box('CourtPaint', V(x0, 0.12, z0), V(x1, 0.15, z1), C(108, 140, 196), M.SmoothPlastic)).CastShadow = false
	local function lineBox(a, b) decor(g:box('CourtLine', a, b, P.white, M.SmoothPlastic)).CastShadow = false end
	lineBox(V(x0, 0.15, z0), V(x1, 0.17, z0 + 0.4))
	lineBox(V(x0, 0.15, z0), V(x0 + 0.4, 0.17, z1))
	lineBox(V(x1 - 0.4, 0.15, z0), V(x1, 0.17, z1))
	local kz = S - 9.4 -- the free-throw line
	decor(g:box('CourtKey', V(xc - 3.6, 0.15, kz), V(xc + 3.6, 0.16, z1), C(200, 116, 108), M.SmoothPlastic)).CastShadow = false
	lineBox(V(xc - 3.6, 0.16, kz - 0.4), V(xc + 3.6, 0.18, kz))
	lineBox(V(xc - 3.8, 0.16, kz), V(xc - 3.4, 0.18, z1))
	lineBox(V(xc + 3.4, 0.16, kz), V(xc + 3.8, 0.18, z1))
	for k = 0, 4 do
		local a0, a1 = math.pi + k * math.pi / 5, math.pi + (k + 1) * math.pi / 5
		local p0 = V(xc + 3.4 * math.cos(a0), 0.17, kz + 3.4 * math.sin(a0))
		local p1 = V(xc + 3.4 * math.cos(a1), 0.17, kz + 3.4 * math.sin(a1))
		decor(g:part('CourtLine', V(0.4, 0.02, (p1 - p0).Magnitude + 0.2), CFrame.lookAt((p0 + p1) / 2, p1), P.white, M.SmoothPlastic)).CastShadow = false
	end
	-- the hoop on the south wall: arms, a white backboard with the red square, an orange rim, a white net
	local bz = S - 3.4
	for _, x in { xc - 2, xc + 2 } do g:bar('HoopArm', V(x, 10.6, S - 0.3), V(x, 10.6, bz), 0.35, K.steel, M.SmoothPlastic) end
	local board = g:box('Backboard', V(xc - 3, 8.6, bz - 0.25), V(xc + 3, 12.6, bz), P.white, M.SmoothPlastic)
	local bg = surface(board, Enum.NormalId.Front, 16)
	for _, e in { { 0, 0, 1, 0.05 }, { 0, 0.95, 1, 0.05 }, { 0, 0, 0.03, 1 }, { 0.97, 0, 0.03, 1 },
		{ 0.35, 0.5, 0.3, 0.05 }, { 0.35, 0.9, 0.3, 0.05 }, { 0.35, 0.5, 0.03, 0.45 }, { 0.62, 0.5, 0.03, 0.45 } } do
		local f = Instance.new('Frame')
		f.BorderSizePixel, f.BackgroundColor3 = 0, C(222, 44, 52)
		f.Position, f.Size = UDim2.fromScale(e[1], e[2]), UDim2.fromScale(e[3], e[4])
		f.Parent = bg
	end
	local rr, ry = 1.15, 9.4
	local rc = V(xc, ry, bz - 1.5)
	g:box('RimBracket', V(xc - 0.3, ry - 0.2, bz - 0.5), V(xc + 0.3, ry + 0.1, bz - 0.25), C(240, 110, 30), M.SmoothPlastic)
	for k = 0, 7 do
		local a0, a1 = k * math.pi / 4, (k + 1) * math.pi / 4
		g:bar('Rim', rc + V(rr * math.cos(a0), 0, rr * math.sin(a0)), rc + V(rr * math.cos(a1), 0, rr * math.sin(a1)), 0.3, C(230, 120, 52), M.SmoothPlastic)
	end
	-- the net: one chunky see-through white drum under the rim (no thin strings)
	local net = decor(g:part('Net', V(1.5, 2.0, 2.0), CFrame.new(rc - V(0, 0.85, 0)) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	net.Transparency, net.CastShadow = 0.35, false
	-- balls: one on the court, one in the shooter's hands
	Lobby.ball(g, V(-36.4, 0.15 + 0.9, 151.4))
	Lobby.ball(g, V(xc + 0.3, 7.9, 140.9))
	-- the boombox on a milk crate at the court's north-west corner, its speakers bouncing
	local bf = CFrame.lookAt(V(-44.8, 0, 134.6), V(-20, 0, 120))
	local bb = g:at(bf)
	Lobby.milkCrate(bb, CFrame.new(0, 0, 0), C(40, 110, 220))
	local box, boom = bb:group('Boombox')
	box:box('BoomboxBody', V(-1.5, 1.7, -0.5), V(1.5, 3.3, 0.5), C(40, 42, 54), M.SmoothPlastic)
	box:box('BoomboxHandle', V(-1.1, 3.3, -0.1), V(1.1, 3.6, 0.1), K.steel, M.SmoothPlastic)
	for _, x in { -0.85, 0.85 } do
		box:part('BoomboxSpeaker', V(0.1, 1.1, 1.1), CFrame.new(x, 2.5, -0.55) * CFrame.Angles(0, math.pi / 2, 0), C(90, 96, 110), M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(box:part('BoomboxCone', V(0.12, 0.5, 0.5), CFrame.new(x, 2.5, -0.58) * CFrame.Angles(0, math.pi / 2, 0), T.cyan, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
	decor(box:box('BoomboxDial', V(-0.3, 2.95, -0.56), V(0.3, 3.15, -0.5), T.pink, M.Neon)).CastShadow = false
	Lobby.motion(boom, bf * CFrame.new(0, 2.5, 0), nil, 0.08, 0.5)
	-- the kids: one shooting at the hoop, one dancing by the boombox
	Lobby.kid(c, skins, 'Baller', 'CornerKid', nil, V(xc, 0.15, 141.4), V(xc, 0.15, S), 'cheer')
	Lobby.kid(c, skins, 'Dancer', 'Lookout', nil, V(-41.6, 0.15, 135.6), V(-10, 0.15, 110), 'swagger', 0.18, 0.9)
	Lobby.kid(c, skins, 'Rebounder', 'Hustler', C(232, 150, 80), V(-35.2, 0.15, 146.8), V(xc, 0.15, S - 4), 'point', 0.14, 1.2)
	-- party bulbs along the south wall between the pillars over the hoop
	Lobby.stringLights(g, V(-46, 22, S - 2), V(-35, 22, S - 2), 2.2, 7)
	-- BLOCK BALLERS under the hoop, STAY GOLD up on the steel band
	Lobby.mural(g, 'MuralBallers', CFrame.lookAt(V(xc, 5.9, S - 0.45), V(xc, 5.9, 0)), 10.4, 4.8, {
		{ 'splash', 0.02, 0.1, 0.96, 0.78, T.purple, 0.35 },
		{ 'word', 'BLOCK BALLERS', 0.03, 0.12, 0.84, 0.66, T.orange, T.ink },
		{ 'word', '🏀', 0.82, 0.1, 0.16, 0.5, T.white, T.ink },
		{ 'drips', 0.1, 0.84, 0.8, 7, 0.14, T.orange },
	})
	Lobby.mural(g, 'MuralGold', CFrame.lookAt(V(-40.5, 31.5, S - 0.4), V(-40.5, 31.5, 0)), 11, 5.2, {
		{ 'splash', 0.04, 0.16, 0.92, 0.64, T.purple, 0.4 },
		{ 'word', 'STAY', 0.08, 0.1, 0.6, 0.38, T.white, T.ink },
		{ 'word', 'GOLD', 0.08, 0.46, 0.84, 0.44, T.yellow, T.ink },
		{ 'word', '👑', 0.68, 0.06, 0.28, 0.34, T.white, T.ink },
		{ 'drips', 0.1, 0.88, 0.8, 6, 0.08, T.yellow },
	})
end

-- A plastic milk crate (2 x 1.6 x 2) with its grid painted on.
function Lobby.milkCrate(c, cf, color)
	local p = c:part('MilkCrate', V(2, 1.6, 2), cf * CFrame.new(0, 0.8, 0), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		Lobby.stripes(p, face, 2, 1.6, 0.4, 0.16, true, 0.6)
	end
	return p
end
-- A traffic cone: a black base, a stepped orange cone with a white band.
function Lobby.cone(c, pos)
	local k = c:group('Cone')
	k:box('ConeBase', pos + V(-0.8, 0, -0.8), pos + V(0.8, 0.2, 0.8), C(36, 36, 40), M.SmoothPlastic)
	k:post('Cone', 0.55, 1.0, pos + V(0, 0.2, 0), C(255, 120, 30), M.SmoothPlastic)
	decor(k:post('ConeBand', 0.42, 0.45, pos + V(0, 1.2, 0), P.white, M.SmoothPlastic))
	k:post('Cone', 0.28, 0.6, pos + V(0, 1.65, 0), C(255, 120, 30), M.SmoothPlastic)
	return k
end
-- A fire hydrant (red with a yellow cap).
function Lobby.hydrant(c, pos)
	local k = c:group('Hydrant')
	k:post('HydrantBase', 0.75, 0.4, pos, C(206, 36, 44), M.SmoothPlastic)
	k:post('Hydrant', 0.55, 2.2, pos + V(0, 0.4, 0), C(222, 44, 52), M.SmoothPlastic)
	k:post('HydrantRing', 0.65, 0.2, pos + V(0, 2.0, 0), C(255, 206, 40), M.SmoothPlastic)
	k:part('HydrantCap', V(1.1, 0.8, 1.1), CFrame.new(pos + V(0, 2.6, 0)), C(255, 206, 40), M.SmoothPlastic, Enum.PartType.Ball)
	k:rod('HydrantNozzle', 0.25, 1.7, CFrame.new(pos + V(0, 1.6, 0)), C(255, 206, 40), M.SmoothPlastic)
	return k
end
-- A chain-link fence panel from a to b (on the floor), ht tall: steel posts, a top rail, see-through mesh (a
-- painted diamond-ish grid on a faint panel).
function Lobby.chainLink(c, a, b, ht)
	local K = Lobby.Colors
	local f = c:group('ChainLink')
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) -- -Z along the fence
	local n = math.max(1, math.ceil(len / 4.5))
	for k = 0, n do f:post('FencePost', 0.3, ht, a + (b - a) * (k / n), K.steel, M.SmoothPlastic) end
	f:part('FenceRail', V(0.4, 0.4, len), cf * CFrame.new(0, ht - 0.2, 0), K.steel, M.SmoothPlastic)
	local mesh = f:part('FenceMesh', V(0.05, ht - 0.4, len), cf * CFrame.new(0, (ht - 0.4) / 2 + 0.1, 0), C(190, 196, 206), M.SmoothPlastic)
	mesh.Transparency = 0.75
	mesh.CastShadow = false
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local g = Lobby.stripes(mesh, face, len, ht - 0.4, 0.5, 0.06, true, 0.2, C(150, 156, 170))
		for k = 0, math.floor((ht - 0.4) / 0.5) - 1 do
			local s = Instance.new('Frame')
			s.BorderSizePixel, s.BackgroundColor3, s.BackgroundTransparency = 0, C(150, 156, 170), 0.2
			s.Position, s.Size = UDim2.fromScale(0, (k + 0.5) / ((ht - 0.4) / 0.5)), UDim2.fromScale(1, 0.06 / (ht - 0.4))
			s.Parent = g
		end
	end
	return f
end
-- A dumpster (7 long on local Z, 4.4 deep, 5 tall): green body, black lids (one propped open), side sleeves,
-- casters, stickers on the long side facing local +X.
function Lobby.dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local green = C(40, 150, 90)
	d:box('DumpsterBody', V(-2.2, 0.5, -3.5), V(2.2, 5, 3.5), green, M.SmoothPlastic)
	d:box('DumpsterRim', V(-2.35, 4.7, -3.6), V(2.35, 5.1, 3.6), green:Lerp(P.black, 0.25), M.SmoothPlastic)
	d:box('DumpsterLid', V(-2.3, 5.1, 0), V(2.3, 5.3, 3.5), C(40, 42, 50), M.SmoothPlastic)
	d:part('DumpsterLid', V(4.6, 0.2, 3.5), CFrame.new(0.4, 6.0, -1.9) * CFrame.Angles(math.rad(-28), 0, 0), C(40, 42, 50), M.SmoothPlastic)
	for _, z in { -3.6, 3.6 } do d:box('DumpsterSleeve', V(-1.6, 2.6, z - 0.25), V(1.6, 3.2, z + 0.25), green:Lerp(P.black, 0.35), M.SmoothPlastic) end
	for _, x in { -1.6, 1.6 } do for _, z in { -2.8, 2.8 } do d:box('DumpsterWheel', V(x - 0.3, 0, z - 0.3), V(x + 0.3, 0.5, z + 0.3), C(36, 36, 40), M.SmoothPlastic) end end
	local T = Lobby.Tag
	Lobby.mural(d, 'DumpsterStickers', CFrame.new(2.26, 2.7, 0) * CFrame.Angles(0, -math.pi / 2, 0), 6.4, 3.6, {
		{ 'splash', 0.05, 0.15, 0.22, 0.4, T.yellow, 0.05 },
		{ 'word', '☺', 0.05, 0.12, 0.22, 0.46, T.ink, T.yellow },
		{ 'splash', 0.32, 0.5, 0.3, 0.35, T.pink, 0.05 },
		{ 'word', '+1', 0.32, 0.48, 0.3, 0.4, T.white, T.ink },
		{ 'word', '★', 0.68, 0.08, 0.28, 0.5, T.cyan, T.ink },
		{ 'word', 'THE BLOCK', 0.3, 0.06, 0.4, 0.34, T.white, T.ink },
	})
	return d
end

-- The loading bays on the north wall: tags sprayed on both roll-up doors; in the NW a dumpster behind a
-- chain-link fence with milk crates, cones and a hydrant; in the NE cones, a hydrant and a crate stack.
function Lobby.loadingBays(c)
	local K, T, N, W = Lobby.Colors, Lobby.Tag, Lobby.N, Lobby.W
	local g = c:group('LoadingBays')
	-- tags on the doors (a ghost panel just in front of each slatted door)
	local dx = Lobby.LoadDoors
	-- (low and wide, under each door's stencil, so they read past the LUCKY SHOT stand and the VIP SAFE)
	Lobby.mural(g, 'DoorTag', CFrame.lookAt(V(dx[1], 3.2, N + 0.62), V(dx[1], 3.2, 100)), 14, 4.8, {
		{ 'splash', 0.02, 0.1, 0.96, 0.72, T.pink, 0.3 },
		{ 'word', 'GOOD VIBES', 0.04, 0.08, 0.8, 0.72, T.yellow, T.ink },
		{ 'word', '★', 0.84, 0.06, 0.14, 0.5, T.cyan, T.ink },
		{ 'drips', 0.08, 0.8, 0.84, 8, 0.16, T.pink },
	})
	Lobby.mural(g, 'DoorTag', CFrame.lookAt(V(dx[2] + 1, 3.2, N + 0.62), V(dx[2] + 1, 3.2, 100)), 12, 4.8, {
		{ 'splash', 0.02, 0.1, 0.96, 0.72, T.lime, 0.35 },
		{ 'word', 'DREAM BIG', 0.18, 0.08, 0.8, 0.72, T.purple, T.white },
		{ 'word', '+1', 0.02, 0.06, 0.16, 0.5, T.pink, T.white },
		{ 'drips', 0.08, 0.8, 0.84, 8, 0.16, T.lime },
	})
	-- NW: the dumpster in the corner between the west pillars, a chain-link fence screening it from the hall,
	-- milk crates beside it, cones and a hydrant on the apron
	Lobby.dumpster(g, CFrame.new(-W + 2.6, 0, 14.6))
	Lobby.chainLink(g, V(-57.6, 0, 11.8), V(-57.6, 0, 20.2), 6.5)
	Lobby.milkCrate(g, CFrame.new(-59.9, 0, 13.4) * CFrame.Angles(0, 0.2, 0), C(222, 44, 52))
	Lobby.milkCrate(g, CFrame.new(-59.9, 1.6, 13.4) * CFrame.Angles(0, -0.15, 0), C(40, 110, 220))
	Lobby.milkCrate(g, CFrame.new(-59.9, 0, 15.8) * CFrame.Angles(0, 0.4, 0), C(255, 196, 40))
	for _, p in { V(-55.6, 0, 13.2), V(-54.2, 0, 16.4), V(-53.4, 0, 11.2) } do Lobby.cone(g, p) end
	Lobby.hydrant(g, V(-56, 0, 22.4))
	-- NE: cones, a hydrant between the east pillars, a stack of milk crates by the door post
	for _, p in { V(50.5, 0, 14.4), V(54.5, 0, 15.8), V(58.4, 0, 14.2) } do Lobby.cone(g, p) end
	Lobby.hydrant(g, V(W - 2.2, 0, 17.2))
	Lobby.milkCrate(g, CFrame.new(W - 2.4, 0, 12.6) * CFrame.Angles(0, 0.1, 0), C(40, 170, 90))
	Lobby.milkCrate(g, CFrame.new(W - 2.4, 1.6, 12.6) * CFrame.Angles(0, -0.2, 0), C(222, 44, 52))
	return g
end

-- Sneakers on a wire: a sagging black wire running north-south over the east aisle (x 36, between the NE floor
-- panel and the feature pads, above every board), hung from the roof deck by two hanger cables, three pairs of
-- big cartoon high-tops (x1.5) dangling toe-down from it by their laces.
function Lobby.sneakerWire(c)
	local H = Lobby.H
	local g = c:group('SneakerWire')
	local a, b, sag = V(36, 22.5, 20), V(36, 22.5, 62), 2.2
	local function at(t) return a + (b - a) * t - V(0, sag * 4 * t * (1 - t), 0) end
	local n = 8
	for k = 0, n - 1 do decor(g:bar('Wire', at(k / n), at((k + 1) / n), 0.25, C(52, 54, 60), M.SmoothPlastic)).CastShadow = false end
	for _, e in { a, b } do decor(g:bar('WireHanger', e, V(e.X, H - 0.1, e.Z), 0.22, C(52, 54, 60), M.SmoothPlastic)).CastShadow = false end
	local k = 1.5
	local pairs = { { 0.3, C(230, 40, 52), P.white }, { 0.5, C(60, 200, 255), C(150, 80, 240) }, { 0.7, C(255, 210, 40), C(36, 36, 44) } }
	for _, pr in pairs do
		local top = at(pr[1])
		for side = -1, 1, 2 do
			local hang = top + V(side * 0.75, -2.4, 0)
			decor(g:bar('Laces', top, top + (hang + V(0, 1.2 * k, 0) - top).Unit * 1.6, 0.18, P.white, M.SmoothPlastic)).CastShadow = false
			-- a high-top hanging toe-down, turned a little
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

-- The corner store at the end of the cross walkway's east arm, on the east wall between the pillar and the
-- podium: a tall teal shopfront, a big glowing window (SNACKS / SODA / ICE POPS and an OPEN neon), a blue door, a
-- striped awning, a CORNER STORE neon board above the feature pads' boards, party bulbs along the wall, and the
-- sidewalk display out front (an ice-pop freezer, a SODA cooler, milk crates, a kid with an ice pop). The BLOCK
-- AVE / HOOD ST street sign stands on its corner.
function Lobby.cornerStore(c, skins)
	local K, W, T = Lobby.Colors, Lobby.W, Lobby.Tag
	local g = c:group('CornerStore')
	local z0, z1 = 68.4, 75.6
	local x = W - 0.3
	g:box('StoreFront', V(x - 0.25, 0, z0), V(W, 13.3, z1), C(86, 160, 152), M.SmoothPlastic)
	g:box('StoreFrontCap', V(x - 0.55, 12.9, z0), V(x - 0.25, 13.3, z1), P.white, M.SmoothPlastic)
	-- a darker kick plate along the foot and a white frame with a sill round the window (layers, not a flat wall)
	g:box('StoreKick', V(x - 0.5, 0, z0), V(x - 0.25, 1.4, z1 - 2.5), C(56, 104, 100), M.SmoothPlastic)
	g:box('StoreWindowFrame', V(x - 0.4, 1.8, z0 + 0.1), V(x - 0.25, 11.6, z1 - 2.0), P.white, M.SmoothPlastic)
	g:box('StoreWindowSill', V(x - 0.9, 1.6, z0), V(x - 0.25, 2.0, z1 - 1.9), P.white, M.SmoothPlastic)
	g:box('StoreDoorFrame', V(x - 0.4, 0, z1 - 2.5), V(x - 0.25, 9.6, z1 + 0.1), P.white, M.SmoothPlastic)
	local win = g:box('StoreWindow', V(x - 0.45, 2.2, z0 + 0.5), V(x - 0.25, 11.2, z1 - 2.4), C(255, 236, 170), M.SmoothPlastic)
	local wg = surface(win, Enum.NormalId.Left, 24)
	line(wg, 'Snacks', 'SNACKS', C(214, 50, 40), FONT.loud, 0.04, 0.2, P.white, 3)
	line(wg, 'Soda', 'SODA', C(40, 110, 220), FONT.loud, 0.25, 0.2, P.white, 3)
	line(wg, 'IcePops', 'ICE POPS', C(200, 60, 200), FONT.loud, 0.46, 0.2, P.white, 3)
	line(wg, 'Open', 'OPEN', C(255, 50, 90), FONT.loud, 0.7, 0.24, C(40, 120, 255), 4)
	g:box('StoreDoor', V(x - 0.45, 0, z1 - 2.1), V(x - 0.25, 9.2, z1 - 0.3), C(40, 90, 200), M.SmoothPlastic) -- (the cooler stands beside it)
	decor(g:box('StoreDoorGlass', V(x - 0.5, 4.6, z1 - 1.8), V(x - 0.45, 8.6, z1 - 0.6), C(170, 220, 255), M.SmoothPlastic)).CastShadow = false
	local awning = g:part('StoreAwning', V(2.8, 0.2, z1 - z0 + 0.6), CFrame.new(x - 1.3, 12.1, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.rad(22)), C(226, 44, 52), M.SmoothPlastic)
	Lobby.stripes(awning, Enum.NormalId.Top, 2.8, z1 - z0 + 0.6, 1.2, 0.6, false, 0, P.white)
	local cf = CFrame.lookAt(V(x - 0.55, 16.4, (z0 + z1) / 2), V(0, 16.4, (z0 + z1) / 2))
	Lobby.board(g, 'StoreSign', cf, z1 - z0, 4.4, C(28, 30, 60), {
		{ 'Corner', 'CORNER', C(255, 120, 200), FONT.loud, 0.06, 0.44, C(255, 255, 255), 3 },
		{ 'Store', 'STORE', C(255, 220, 60), FONT.loud, 0.5, 0.44, C(255, 255, 255), 3 },
	}, 20)
	Lobby.neonFrame(g, cf, z1 - z0, 4.4, C(80, 230, 255), 0.25)
	light(win, C(255, 220, 160), 0.8, 14)
	Lobby.stringLights(g, V(W - 2, 21.5, 67.9), V(W - 2, 21.5, 75.4), 1.8, 5)
	-- the sidewalk display (x 59..63.6, z 70..75.6: the arm keeps z 58..70 clear)
	local fz = 71.9
	g:box('FreezerBody', V(61.2, 0, fz - 1.8), V(63.6, 2.5, fz + 1.8), C(246, 248, 252), M.SmoothPlastic)
	g:box('FreezerBand', V(61.15, 0.3, fz - 1.85), V(63.65, 0.7, fz + 1.85), C(60, 200, 255), M.SmoothPlastic)
	local lid = g:box('FreezerLid', V(61.3, 2.5, fz - 1.7), V(63.5, 2.75, fz + 1.7), C(120, 230, 255), M.Glass)
	lid.Transparency = 0.25
	for j, col in { C(255, 90, 140), C(255, 200, 40), C(120, 220, 90), C(160, 110, 255) } do
		decor(g:box('IcePop', V(61.9 + (j % 2) * 0.8, 2.2, fz - 1.3 + j * 0.55), V(62.3 + (j % 2) * 0.8, 2.7, fz - 1.0 + j * 0.55), col, M.SmoothPlastic)).CastShadow = false
	end
	local sticker = ghost(g:part('FreezerSticker', V(0.05, 2.0, 3.2), CFrame.new(61.12, 1.45, fz), P.white))
	local sg = surface(sticker, Enum.NormalId.Left, 24)
	line(sg, 'Pop', '🍭', P.white, FONT.loud, 0.0, 0.5)
	line(sg, 'Text', 'ICE POPS', C(255, 70, 150), FONT.loud, 0.52, 0.42, P.white, 2)
	local cz = 74.0
	local cooler = g:box('SodaCooler', V(62.2, 0, cz - 1.0), V(64.2, 3.9, cz + 1.0), C(214, 40, 44), M.SmoothPlastic)
	line(surface(cooler, Enum.NormalId.Left, 24), 'Text', 'SODA', P.white, FONT.loud, 0.04, 0.2, C(90, 0, 10), 2)
	decor(g:box('SodaCoolerGlass', V(62.15, 0.5, cz - 0.8), V(62.2, 2.9, cz + 0.8), C(190, 230, 255), M.SmoothPlastic)).CastShadow = false
	for j = 0, 2 do
		for i, col in { C(230, 40, 52), C(60, 170, 255), C(255, 200, 40) } do
			decor(g:box('SodaCan', V(62.25, 0.7 + j * 0.75, cz - 0.95 + i * 0.45), V(62.45, 1.2 + j * 0.75, cz - 0.65 + i * 0.45), col, M.SmoothPlastic)).CastShadow = false
		end
	end
	Lobby.milkCrate(g, CFrame.new(59.9, 0, 73.8) * CFrame.Angles(0, 0.25, 0), C(40, 110, 220))
	Lobby.milkCrate(g, CFrame.new(59.9, 1.6, 73.8) * CFrame.Angles(0, -0.1, 0), C(255, 196, 40))
	-- the kid with an ice pop, facing the spawn
	local kid = Lobby.kid(c, skins, 'IcePopKid', 'Pickpocket', C(232, 132, 184), V(59.2, 0.15, 71.2), V(0, 0.15, 66), Lobby.Poses.icePop, 0.1, 1.4)
	local hand = kid and Lobby.limb(kid, 'RightHand', 'Right Arm')
	if hand then
		local at = hand.CFrame.Position + V(0, 0.75, 0)
		local stick = Lobby.worldPart(kid, 'IcePopStick', V(0.14, 0.6, 0.14), CFrame.new(at - V(0, 0.45, 0)), C(230, 200, 150))
		local pop = Lobby.worldPart(kid, 'IcePop', V(0.5, 0.9, 0.3), CFrame.new(at + V(0, 0.25, 0)), C(255, 90, 160))
		for _, q in { stick, pop } do q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = false, false, false, false end
	end
	-- the street sign on the store's corner, a hydrant at its foot
	local pole = V(61.8, 0, 66.6)
	g:post('SignPole', 0.2, 20.4, pole, C(70, 120, 80), M.SmoothPlastic)
	local function blade(name, text, cf)
		local bl = Lobby.board(g, name, cf, 6.4, 1.3, C(20, 120, 70), { { 'Text', text, P.white, FONT.title, 0.12, 0.76 } }, 24)
		line(surface(bl, Enum.NormalId.Back, 24), 'Text', text, P.white, FONT.title, 0.12, 0.76)
	end
	blade('StreetSign', 'BLOCK AVE', CFrame.new(pole + V(0, 19.6, -3.3)) * CFrame.Angles(0, math.pi / 2, 0))
	blade('StreetSign', 'HOOD ST', CFrame.new(pole + V(-3.3, 18.2, 0)) * CFrame.Angles(0, math.pi, 0))
	Lobby.hydrant(g, V(60.2, 0, 65.4))
	return g
end
-- A string of round party bulbs from a to b sagging by sag, n bulbs in turning colours.
function Lobby.stringLights(c, a, b, sag, n)
	local g = c:group('StringLights')
	local cols = { C(255, 80, 120), C(255, 220, 60), C(80, 230, 255), C(140, 240, 90), C(200, 120, 255) }
	local function at(t) return a + (b - a) * t - V(0, sag * 4 * t * (1 - t), 0) end
	local m = 8
	for k = 0, m - 1 do decor(g:bar('LightWire', at(k / m), at((k + 1) / m), 0.2, C(52, 54, 60), M.SmoothPlastic)).CastShadow = false end
	for k = 1, n do
		local p = at(k / (n + 1)) - V(0, 0.45, 0)
		decor(g:part('Bulb', V(0.6, 0.75, 0.6), CFrame.new(p), cols[(k - 1) % #cols + 1], M.Neon, Enum.PartType.Ball)).CastShadow = false
	end
	return g
end

-- A lowrider turning slowly on a showroom turntable in the north-east (the old feature-pad floor): candy purple, white roof,
-- gold wire wheels with white walls, chrome bumpers, cyan underglow; it sits low and bounces on its hydraulics.
function Lobby.lowrider(c, pos)
	local K = Lobby.Colors
	local g = c:group('Lowrider')
	-- the turntable: a dark faceted base, a white rim and a light top (no neon ring on the floor)
	local tt = g:at(CFrame.new(pos))
	Lobby.poly(tt, 'TurntableBase', 8, 17.4, 0, 0.3, C(120, 122, 130))
	Lobby.disc(tt, 'TurntableRim', 16.4, 0.3, 0.5, 0, 0, C(236, 237, 240))
	Lobby.disc(tt, 'TurntableTop', 15.4, 0.3, 0.6, 0, 0, C(204, 206, 212))
	local frame = CFrame.new(pos + V(0, 0.6, 0)) * CFrame.Angles(0, math.rad(-35), 0)
	local cc, car = g:at(frame):group('LowriderCar')
	local paint, roof, chrome = C(150, 50, 210), C(246, 246, 252), C(220, 226, 236)
	cc:box('CarBody', V(-7.4, 1.0, -2.7), V(7.4, 2.5, 2.7), paint, M.SmoothPlastic)
	cc:box('CarHood', V(-7.4, 2.5, -2.5), V(-3.0, 2.8, 2.5), paint, M.SmoothPlastic)
	cc:box('CarTrunk', V(3.4, 2.5, -2.5), V(7.4, 2.8, 2.5), paint, M.SmoothPlastic)
	cc:box('CarCabin', V(-3.0, 2.5, -2.4), V(3.4, 3.4, 2.4), paint, M.SmoothPlastic)
	cc:box('CarRoof', V(-1.8, 4.5, -2.3), V(3.0, 4.8, 2.3), roof, M.SmoothPlastic)
	cc:box('CarWindows', V(-1.7, 3.4, -2.35), V(2.9, 4.5, 2.35), C(40, 60, 100), M.SmoothPlastic)
	cc:wedge('CarWindshield', V(4.6, 1.1, 1.2), CFrame.new(-2.4, 3.95, 0) * CFrame.Angles(0, -math.pi / 2, 0), C(70, 100, 150), M.SmoothPlastic)
	for _, z in { -2.75, 2.75 } do
		decor(cc:box('CarPinstripe', V(-7.2, 2.2, z - 0.03), V(7.2, 2.35, z + 0.03), K.gold, M.SmoothPlastic)).CastShadow = false
	end
	for _, x in { -7.6, 7.6 } do cc:box('CarBumper', V(x - 0.3, 1.0, -2.8), V(x + 0.3, 1.7, 2.8), chrome, M.SmoothPlastic) end
	cc:box('CarGrille', V(-7.55, 1.75, -1.6), V(-7.4, 2.4, 1.6), chrome, M.SmoothPlastic)
	for _, z in { -2.0, 2.0 } do
		decor(cc:box('CarHeadlight', V(-7.5, 1.9, z - 0.45), V(-7.4, 2.35, z + 0.45), C(255, 250, 220), M.Neon)).CastShadow = false
		decor(cc:box('CarTaillight', V(7.4, 1.9, z - 0.45), V(7.5, 2.35, z + 0.45), C(255, 40, 60), M.Neon)).CastShadow = false
	end
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2.55, 2.55 } do
			cc:part('CarTyre', V(0.8, 2.2, 2.2), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(cc:part('CarWhitewall', V(0.82, 1.6, 1.6), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
			decor(cc:part('CarRim', V(0.86, 1.1, 1.1), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.pi / 2, 0), K.gold, M.SmoothPlastic, Enum.PartType.Cylinder))
		end
	end
	decor(cc:box('CarUnderglow', V(-6.6, 0.55, -2.2), V(6.6, 0.75, 2.2), C(80, 230, 255), M.Neon)).CastShadow = false
	Lobby.motion(car, frame, 6, 0.3, 1.4)
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

-- The terrace's Gold end (facing the armory and TOP CASH): a big LEVEL UP piece with targets and +1s.
function Lobby.terraceMural(c)
	local T = Lobby.Tag
	local zS = Lobby.RangeZ0 + (#Lobby.Ranges - 0.5) * Lobby.RangePitch
	local top = #Lobby.Ranges * Lobby.RangeRise
	return Lobby.mural(c, 'MuralLevelUp', CFrame.lookAt(V(-54.6, top / 2, zS + 0.08), V(-54.6, top / 2, 200)), 21, top - 1.2, {
		{ 'splash', 0.03, 0.2, 0.94, 0.56, T.yellow, 0.25 },
		{ 'word', 'LEVEL UP!', 0.06, 0.14, 0.74, 0.46, T.yellow, T.ink },
		{ 'word', '🎯', 0.78, 0.1, 0.2, 0.4, T.white, T.ink },
		{ 'word', '+1  +1  +1', 0.08, 0.6, 0.6, 0.28, T.cyan, T.ink },
		{ 'word', '★', 0.72, 0.56, 0.2, 0.34, T.pink, T.white },
		{ 'drips', 0.08, 0.86, 0.66, 8, 0.1, T.yellow },
	})
end

function Lobby.hood(L, skins)
	local h = L:group('Hood')
	Lobby.courtCorner(h, skins)
	Lobby.loadingBays(h)
	Lobby.sneakerWire(h)
	Lobby.cornerStore(h, skins)
	Lobby.terraceMural(h)
	-- the lowrider showroom in the NE (where the feature pads were), its owner waving at the spawn
	Lobby.lowrider(h, V(48, 0, 40))
	Lobby.kid(h, skins, 'RideOwner', 'GetawayDriver', nil, V(40.4, 0.15, 30.2), V(0, 0.15, 66), 'wave', 0.12, 1.8)
	-- small props cast no shadows (cones, crates, hydrants, sneakers, the boombox...): no visible change, fewer casters
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Size.X * p.Size.Y * p.Size.Z < 30 then p.CastShadow = false end
	end
	return h
end

---------------------------------------------------------------------------------------------- slots
function Lobby.slots(L)
	local D = Lobby.Deck
	-- The ARMORY on the east side, its front to the hall (west). (No floor line in front of it.)
	local ax, az = Lobby.ArmoryX, Lobby.ArmoryZ
	Lobby.place(L, L.parent, 'Armory', CFrame.lookAt(V(ax, D, az), V(0, D, az)), { X = 58.8, Y = 21, Z0 = 0, Z1 = 31.2 }, 'ARMORY', C(255, 90, 160),
		Armory and function(c) Armory.build(c, {}) end)
end

---------------------------------------------------------------------------------------------- dressing
-- The street face: the club sign with marquee bulbs, two posters, the gold deagle on its mast over the door.
function Lobby.dressing(L)
	local K, N = Lobby.Colors, Lobby.N
	local dr = L:group('Dressing')
	local clubOut = Lobby.onWall(V(0, 31, N - 1.5), V(0, 0, -1))
	Lobby.neonSign(dr, clubOut, 30, 5.4, 'BLOCK RANGE', K.pink)
	Lobby.marquee(dr, clubOut, 30, 5.4, 5.4)
	Lobby.poster(dr, Lobby.onWall(V(-24, 12, N - 1.45), V(0, 0, -1)), 7, 9, C(250, 204, 48), { { 'SHOOT', P.black, FONT.loud, 0.06, 0.24, P.white }, { 'HERE', C(214, 40, 40), FONT.loud, 0.3, 0.24, P.white }, { 'x2 POWER\nFREE RANGE', P.black, FONT.title, 0.6, 0.3 } })
	Lobby.poster(dr, Lobby.onWall(V(24, 12, N - 1.45), V(0, 0, -1)), 7, 9, C(214, 40, 40), { { 'TARGET', P.white, FONT.loud, 0.06, 0.24 }, { 'NIGHT', C(255, 220, 60), FONT.loud, 0.3, 0.24 }, { 'EVERY\nSATURDAY', P.white, FONT.title, 0.6, 0.3 } })
	-- The landmark from the street: a giant gold deagle (GunModels, recoloured gold) turning slowly on a red
	-- turntable mast on the roof over the door, a cyan neon ring under it, a warm light and glints; a giant bullseye if
	-- the gun models aren't there.
	local ridge = Lobby.H + 0.3
	local mast = dr:group('RoofMast')
	mast:part('MastPlinth', V(1.2, 6, 6), CFrame.new(0, ridge + 0.6, N - 0.5) * CFrame.Angles(0, 0, math.pi / 2), K.red, M.SmoothPlastic, Enum.PartType.Cylinder)
	decor(mast:part('MastRing', V(0.3, 6.6, 6.6), CFrame.new(0, ridge + 1.15, N - 0.5) * CFrame.Angles(0, 0, math.pi / 2), K.cool, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	mast:post('MastPole', 0.5, 7.2, V(0, ridge + 1.2, N - 0.5), K.red, M.SmoothPlastic)
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
			local slide = gun:FindFirstChild('Slide')
			if slide then
				-- A thin neon line down each side of the slide.
				for _, sx in { -1, 1 } do
					local glow = Lobby.worldPart(gun, 'SlideGlow', V(0.1, 0.3, slide.Size.Z * 0.85), slide.CFrame * CFrame.new(sx * (slide.Size.X / 2 + 0.05), 0, 0), C(255, 236, 140), M.Neon)
					glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = false, false, false, false
				end
			end
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
	local shine = Lobby.emitBox(mast, 'RoofGunFx', gp + V(-6, -4, -6), gp + V(6, 4, 6))
	light(shine, C(255, 210, 90), 2, 30)
	Lobby.fx(shine, 'RoofGunGlints', 'sparkle', { Rate = 6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0, 0.5),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 1.4 }, { 1, 0 } }), Color = ColorSequence.new(C(255, 240, 200)), LightEmission = 1 })
	return dr
end

---------------------------------------------------------------------------------------------- volume
-- Brief 8's volume rule as a last pass over the lobby's own groups (never the other builders' models: the ranges,
-- the armory, the exit door, the WORLD 2 portal, the fast-travel pad): in the shell groups (Lobby.Shell) a part
-- whose biggest face is 60 studs² or more keeps HSV saturation <= 0.45; any other solid part <= 0.7 (its value a
-- touch lower when cut). Neon, glass, hidden parts and small parts (biggest face under 4 studs²) keep their
-- colour: accents may stay bright.
Lobby.Mine = { 'Hall', 'Roof', 'FloorPlan', 'SpawnBadge', 'FurthestStop', 'RangeTerrace', 'ShoeBoxDais', 'DailyCrate', 'LuckyShot', 'VipSafe',
	'KingpinStatue', 'Leaderboards', 'Dressing', 'Hood', 'People' }
Lobby.NotMine = { ExitDoor = true, World2Portal = true }
Lobby.Shell = { Hall = true, Roof = true, FloorPlan = true, RangeTerrace = true }
function Lobby.tame(model)
	for _, name in Lobby.Mine do
		for _, g in model:GetChildren() do
			if g.Name == name then
				for _, d in g:GetDescendants() do
					if d:IsA('BasePart') and d.Material ~= M.Neon and d.Material ~= M.Glass and d.Transparency < 1 then
						local skip = false
						local a = d.Parent
						while a and a ~= g do
							if Lobby.NotMine[a.Name] then skip = true break end
							a = a.Parent
						end
						local sz = d.Size
						local face = math.max(sz.X * sz.Y, sz.Y * sz.Z, sz.X * sz.Z)
						if not skip and face >= 4 then
							local h, sat, val = d.Color:ToHSV()
							local cap = (face >= 60 and Lobby.Shell[name]) and 0.45 or 0.7
							if sat > cap then d.Color = Color3.fromHSV(h, cap, val * 0.96) end
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------- build
Lobby.RewardAt = {
	DailyCrate = CFrame.lookAt(V(56.2, 0, 145), V(0, 0, 145)), -- SE corner past the armory's south end, hasp to the hall
	LuckyShot = CFrame.lookAt(V(-45.5, 0, 20.6), V(0, 0, 20.6)), -- NW apron, between the WORLD 2 portal and the terrace's north stair, wheel to the walk
	VipSafe = CFrame.lookAt(V(41.1, 0, 12.4), V(41.1, 0, 60)), -- north wall, between TOP REBIRTHS and the NE loading door (x 36..46)
}
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.hall(L)
	Lobby.floorPlan(L)
	Lobby.badge(L)
	Lobby.rangeRow(L, skins)
	Lobby.shoeDais(L)
	Lobby.slots(L)
	Lobby.rewards(L)
	Lobby.Slots.World2Portal = CFrame.new(-27, 0, 11) * CFrame.Angles(0, math.pi, 0)
	Lobby.portal(L, Lobby.Slots.World2Portal)
	Lobby.Slots.Statue = CFrame.lookAt(V(-54, 0, 144), V(-54, 0, 0)) -- the SW corner, facing north, square to the hall
	Lobby.statue(L, Lobby.Slots.Statue, skins)
	Lobby.Slots.Spawn = CFrame.new(SPAWN) * CFrame.Angles(0, math.pi - math.rad(12), 0)
	Lobby.Slots.FurthestPad = Lobby.FurthestAt
	for name, cf in Lobby.RewardAt do Lobby.Slots[name] = cf end
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	local boards = L:group('Leaderboards')
	for k, e in { { V(-60.5, 0, 124), V(0, 0, 124), 'TOP CASH', C(84, 172, 108), 'CashLeaderboard', '💵' }, { V(26.4, 0, 9.5), V(26.4, 0, 60), 'TOP REBIRTHS', C(66, 166, 176), nil, '🔄' }, { V(38, 0, 148.4), V(38, 0, 100), 'TOP POWER', C(210, 92, 88), 'ServerLeaderboard' } } do
		local cf = CFrame.lookAt(e[1], e[2])
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[3], e[4], e[5], e[6])
	end
	Lobby.dressing(L)
	Lobby.hood(L, skins)
	Lobby.tame(model)
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
	-- A darker cross-street band where every stage starts; its gate stands in the middle of it. No painted lines:
	-- a low stone kerb on each edge frames it instead.
	for i = 1, STAGES + 1 do
		local z = stageTop(i)
		g:box('CrossStreet', V(-FRONT, -1, z - 4), V(FRONT, 0.02, z + 4), P.band, M.Asphalt)
		for _, e in { -1, 1 } do g:box('CrossKerb', V(-FRONT, -1, z + e * 4 - 0.5), V(FRONT, 0.14, z + e * 4 + 0.5), P.kerb, M.Concrete) end
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
	local carColors = { C(226, 190, 96), P.white, C(192, 84, 74), C(78, 114, 184), C(96, 150, 132), C(230, 230, 232) }
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
-- A gate at the start of every stage (and the boss yard), built like a simulator zone gate (research recipe d):
-- two towers on dark plinths (cream lip, bands and inset panels, a capital and a state lamp on top) carrying a
-- sign-bridge with the stage's name, a round number medallion breaking the skyline, and a see-through field in
-- the look's colour showing the power it takes, with a padlock and a progress bar. One hue per gate in three
-- tones (main, a darker base, cream trim). HoodClient/Stages makes the field solid while you're short (red lamps,
-- padlock on), turns it green when you can pass (the padlock and red lamp shells hide, the green lamps show) and
-- clears it once you have; StageService records the clear and pays the reward.
local LOOK_NAMES = { 'THE BLOCK', 'SHOP STREET', 'THE COURTS', 'THE APARTMENTS', 'THE YARDS', 'BOSS YARD' }
local BOSS_RED = C(214, 44, 44)
local function lookColor(i) return i > STAGES and BOSS_RED or P.district[lookOf(i)] end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local color = lookColor(i)
	local req = STAGE_POWER[i]
	local hue, sat, val = color:ToHSV()
	local main = Color3.fromHSV(hue, math.min(sat, 0.56), math.min(val, 0.8))
	local dark, trim, ink = main:Lerp(P.black, 0.38), C(238, 236, 232), main:Lerp(P.black, 0.6)
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	local TX, TW, TOP = 34.6, 1.7, 26 -- tower centre, shaft half width, shaft top
	for _, s in { -1, 1 } do
		local x = s * TX
		local function B(name, w, y0, y1, d, c, mat) return g:box(name, V(x - w, y0, -d), V(x + w, y1, d), c, mat or M.SmoothPlastic) end
		B('GatePlinth', 2.3, 0, 2.4, 2.7, dark)
		B('GatePlinthLip', 2.05, 2.4, 2.9, 2.4, trim)
		B('GatePost', TW, 2.9, TOP, TW, main)
		for _, y in { 8.6, 15.2 } do B('GateBand', TW + 0.25, y, y + 0.8, TW + 0.25, trim) end
		-- inset panels between the bands, front and back
		for _, sz in { -1, 1 } do
			g:box('GateInset', V(x - 0.65, 9.9, sz * TW), V(x + 0.65, 14.6, sz * (TW + 0.18)), dark, M.SmoothPlastic)
			g:box('GateInset', V(x - 0.65, 16.5, sz * TW), V(x + 0.65, 18.8, sz * (TW + 0.18)), dark, M.SmoothPlastic)
		end
		B('GateCapital', TW + 0.6, TOP, TOP + 1.2, TW + 0.6, trim)
		B('GateLampSeat', TW - 0.2, TOP + 1.2, TOP + 1.9, TW - 0.2, dark)
		-- The state lamp, a globe on the tower: a red shell (named Lock, so the client hides it once you can pass)
		-- round a green core.
		local lamp = CFrame.new(x, TOP + 3.3, 0)
		decor(g:part('GateLamp', V(2.5, 2.5, 2.5), lamp, C(84, 214, 124), M.Neon, Enum.PartType.Ball)).CastShadow = false
		decor(g:part('Lock', V(2.9, 2.9, 2.9), lamp, C(230, 74, 62), M.Neon, Enum.PartType.Ball)).CastShadow = false
	end
	-- The sign-bridge between the towers: a dark underside trim, the coloured board, a cream cap; dark corbels in
	-- the top corners of the opening so it reads as a gate, not a rectangle.
	local inner = TX - TW
	g:box('GateHeaderTrim', V(-inner, 19.0, -1.0), V(inner, 19.6, 1.0), dark, M.SmoothPlastic)
	g:box('GateHeader', V(-inner, 19.6, -1.3), V(inner, 23.6, 1.3), main, M.SmoothPlastic)
	g:box('GateHeaderCap', V(-inner - 0.2, 23.6, -1.6), V(inner + 0.2, 24.2, 1.6), trim, M.SmoothPlastic)
	for _, s in { -1, 1 } do
		g:wedge('GateCorbel', V(2, 2.6, 2.6), CFrame.new(s * (inner - 1.3), 19.0 - 1.3, 0) * CFrame.Angles(0, s * math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), dark, M.SmoothPlastic)
	end
	-- The name on a framed cream plate in the middle of the bridge (a dark back, the plate a little proud of it).
	local pw = i > STAGES and 11 or 18
	g:box('GatePlateBack', V(-pw - 0.5, 19.75, -1.45), V(pw + 0.5, 23.45, 1.45), dark, M.SmoothPlastic)
	local plate = g:box('GatePlate', V(-pw, 20.05, -1.6), V(pw, 23.15, 1.6), trim, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local hg = surface(plate, face, 16)
		pcall(function() hg.MaxDistance = i == 1 and 400 or 100 end)
		line(hg, 'Name', i > STAGES and 'BOSS YARD' or ('STAGE ' .. i .. '  •  ' .. LOOK_NAMES[lookOf(i)]), ink, FONT.loud, 0.06, 0.88, trim, 1)
	end
	-- The number medallion on top of the bridge: a dark ring round a cream disc. (Not on stage 1: the warehouse's
	-- BLOCK RANGE sign hangs right behind that one.)
	local up = CFrame.Angles(0, math.pi / 2, 0) -- (cylinders lie along X; this turns them to face the street)
	if i > 1 then
		g:part('GateMedal', V(1.7, 7.4, 7.4), CFrame.new(0, 27.3, 0) * up, dark, M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('GateMedalFace', V(2.1, 6.2, 6.2), CFrame.new(0, 27.3, 0) * up, trim, M.SmoothPlastic, Enum.PartType.Cylinder)
		local num = ghost(g:box('GateMedalText', V(-2.6, 24.7, -1.1), V(2.6, 29.9, 1.1), P.white))
		for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
			local ng = surface(num, face, 20)
			pcall(function() ng.MaxDistance = 120 end)
			line(ng, 'Number', i > STAGES and '👑' or tostring(i), main, FONT.loud, 0.12, 0.76, P.white, 3)
		end
	end
	-- The field. Stage 1's fills the warehouse door, so it is fainter; the client keeps each gate's own base.
	local barrier = g:box('Barrier', V(-34.4, 0, -0.3), V(34.4, 19.2, 0.3), main, M.SmoothPlastic)
	barrier.Transparency = i == 1 and 0.8 or 0.62
	barrier:SetAttribute('BaseTransparency', barrier.Transparency)
	barrier.CastShadow = false
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local bg = surface(barrier, face, 12)
		-- Only stage 1's wall text reads from the lobby; later gates show theirs as you walk up, so they don't stack
		-- behind stage 1's through the warehouse door.
		pcall(function() bg.MaxDistance = i == 1 and 260 or 90 end)
		line(bg, 'Power', '💪 ' .. compact(req), P.white, FONT.loud, 0.25, 0.3, ink, 6)
		line(bg, 'Sub', 'POWER TO ENTER', P.white, FONT.title, 0.555, 0.1, ink, 3)
		line(bg, 'Status', 'NEED 💪 ' .. compact(req), P.white, FONT.loud, 0.665, 0.11, ink, 3)
		-- Your progress toward the number (the client sizes Fill and writes Count).
		local fill = Instance.new('Frame')
		fill.Name = 'Fill'
		fill.BorderSizePixel, fill.BackgroundColor3, fill.ZIndex = 0, C(118, 216, 146), 2
		fill.Position, fill.Size = UDim2.fromScale(0.19, 0.8), UDim2.fromScale(0, 0.09)
		fill.Parent = bg
		local track = Instance.new('Frame')
		track.Name = 'Track'
		track.BorderSizePixel, track.BackgroundColor3, track.BackgroundTransparency, track.ZIndex = 0, P.white, 0.55, 1
		track.Position, track.Size = UDim2.fromScale(0.19, 0.8), UDim2.fromScale(0.62, 0.09)
		track.Parent = bg
		local count = line(bg, 'Count', '0 / ' .. compact(req), ink, FONT.loud, 0.802, 0.086, P.white, 2)
		count.ZIndex = 3
	end
	-- The padlock hanging from the bridge over the number (every part named Lock: shown only while you're short).
	local gold = C(226, 182, 76)
	decor(g:box('Lock', V(-1.5, 14.9, -0.6), V(1.5, 17.5, 0.6), gold, M.SmoothPlastic))
	decor(g:box('Lock', V(-0.25, 15.6, -0.66), V(0.25, 16.6, 0.66), gold:Lerp(P.black, 0.55), M.SmoothPlastic))
	for _, sx in { -1, 1 } do decor(g:box('Lock', V(sx * 1.0 - 0.3, 17.5, -0.3), V(sx * 1.0 + 0.3, 18.6, 0.3), C(176, 180, 190), M.SmoothPlastic)) end
	decor(g:box('Lock', V(-1.3, 18.6, -0.3), V(1.3, 19.1, 0.3), C(176, 180, 190), M.SmoothPlastic))
	-- Pads on the approach side: back to spawn, and on to your furthest stage.
	if i > 1 then
		teleportPad(g, 'LobbyPad', -26, 7, P.padRed:Lerp(C(255, 40, 255), 0.6), 'Lobby', 'SPAWN')
		teleportPad(g, 'FurthestPad', 26, 7, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
	end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-15, 17.5, -1), V(15, 18.5, 1), P.white))
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
	model:SetAttribute('Light', main)
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
		elseif kind == 'dumpster' then dumpster(ctx, CFrame.new(p) * CFrame.Angles(0, -s * math.pi / 2, 0)) -- (front to the street)
		elseif kind == 'crates' then
			pallet(ctx, CFrame.new(p))
			crate(ctx, CFrame.new(p + V(0, 0.8, 0)), 2.6)
			crate(ctx, CFrame.new(p + V(0, 0.8, 3.2)) * CFrame.Angles(0, 0.2, 0), 2.4)
		end
	end
end
-- The usual kerb dressing, mirrored a little differently each stage so repeats don't line up. A district's
-- first stage has its district sign where the left lamp at -44 would stand.
local function standardDressing(ctx, top, i, extraL, extraR)
	local flip = i % 2 == 0
	local leftLamp = trioOf(i) == 1 and { 'none', -44 } or { 'lamp', -44, 7 }
	dressing(ctx, top, -1, { { 'lamp', -14, 7 }, { flip and 'hedge' or 'tree', -26 }, leftLamp, { flip and 'tree' or 'bench', -54, 4 }, table.unpack(extraL or {}) })
	dressing(ctx, top, 1, { { 'lamp', -14, 7 }, { flip and 'tree' or 'hedge', -26 }, { 'lamp', -44, 7 }, { flip and 'bench' or 'tree', -56, 4 }, table.unpack(extraR or {}) })
end
local function stageCore(ctx, i)
	local top = stageTop(i)
	local d = ctx:group('Stage' .. i)
	local _, pad = fightPad(d, i, V(0, 0, padZ(i)), TRIO_COLORS[trioOf(i)], lookOf(i))
	pad.parent:SetAttribute('Stage', i)
	if trioOf(i) == 1 then
		-- The district's name on a sign hung from a post at the left kerb (not over the walk, so the next gate
		-- stays in view).
		-- (Its badge shows the district's icon, not a number, so it can't be mistaken for the gates' stage numbers.)
		local k = lookOf(i)
		banner(d, CFrame.new(-FRONT + 1.6, 0, top - 44), LOOK_NAMES[k], 'STAGES ' .. (3 * k - 2) .. ' - ' .. (3 * k), Craft.icons[k], P.district[k])
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
-- Each shop keeps its colour, a notch quieter: strawberry instead of hot pink, a cream-gold instead of lemon.
local SHOPS = {
	{ sign = 'PIZZA', signColor = C(190, 74, 66), textColor = C(255, 230, 160), stripes = { C(196, 84, 74), P.white }, wall = P.brickPink },
	{ sign = 'SNEAKERS', signColor = C(44, 48, 58), textColor = P.white, stripes = { C(58, 62, 72), P.white }, wall = P.brick },
	{ sign = 'ICE CREAM', signColor = C(206, 116, 150), textColor = P.white, stripes = { C(228, 164, 188), P.white }, wall = C(240, 226, 206) },
	{ sign = 'ARCADE', signColor = C(116, 82, 176), textColor = C(255, 232, 170), stripes = { C(128, 94, 184), C(240, 228, 196) }, wall = P.brickDark },
	{ sign = 'BAKERY', signColor = C(150, 104, 70), textColor = P.white, stripes = { C(196, 146, 98), P.white }, wall = P.tan, extra = 'crates' },
	{ sign = 'PHONES', signColor = C(70, 118, 188), textColor = P.white, stripes = { C(76, 124, 192), P.white }, wall = P.brick },
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
-- five-a-side cage with goals. Each court is a soft field colour with deeper-toned keys and centre circle
-- (inlaid, flush with the lines), so it reads as a court without one loud orange sheet.
local COURTS = {
	{ P.court, P.courtKey, 'hoops' },
	{ C(104, 136, 186), C(78, 106, 160), 'hoops' },
	{ C(108, 166, 116), C(126, 182, 132), 'goals' },
}
local function courtStage(ctx, i)
	local d, top = stageCore(ctx, i)
	local t = trioOf(i)
	local floor, key, kind = COURTS[t][1], COURTS[t][2], COURTS[t][3]
	local z0, z1 = top - 58, top - 10
	d:box('Court', V(-FRONT + 4, 0, z0), V(FRONT - 4, 0.12, z1), floor, M.SmoothPlastic)
	local zm = (z0 + z1) / 2
	if kind == 'hoops' then
		for _, s in { -1, 1 } do d:box('CourtKey', V(s * (FRONT - 4), 0, zm - 5), V(s * (FRONT - 17), 0.13, zm + 5), key, M.SmoothPlastic) end
		Craft.octagon(d:at(CFrame.new(0, 0, zm)), 'CourtCircle', 11.6, 0, 0.13, key)
	else
		-- Mown stripes across the turf.
		for k = 0, 2 do d:box('CourtStripe', V(-FRONT + 4, 0, z0 + 4 + k * 16), V(FRONT - 4, 0.13, z0 + 12 + k * 16), key, M.SmoothPlastic) end
	end
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
			-- Chunky low-poly hoop: a padded pole on a foot, an arm, a framed backboard, a square rim over a
			-- see-through net block.
			local h = d:at(CFrame.lookAt(V(s * (FRONT - 3), 0, zc), V(0, 0, zc))):group('Hoop')
			local steel = C(70, 76, 88)
			h:box('HoopFoot', V(-0.9, 0, -0.3), V(0.9, 0.5, 1.5), steel, M.SmoothPlastic)
			h:post('HoopPole', 0.45, 11, V(0, 0.5, 0.6), steel, M.SmoothPlastic)
			h:box('HoopPad', V(-0.6, 0.5, 0.0), V(0.6, 5.0, 1.2), key, M.SmoothPlastic)
			h:box('HoopArm', V(-0.3, 10.3, -1.2), V(0.3, 10.9, 0.6), steel, M.SmoothPlastic)
			h:box('BackboardFrame', V(-2.8, 9.2, -1.5), V(2.8, 12.8, -1.25), steel, M.SmoothPlastic)
			h:box('Backboard', V(-2.5, 9.5, -1.65), V(2.5, 12.5, -1.3), P.white, M.SmoothPlastic)
			decor(h:box('BoardSquare', V(-1, 10.0, -1.75), V(1, 11.2, -1.6), key, M.SmoothPlastic))
			local rim = C(222, 116, 66)
			for _, e in { { V(-0.95, 9.85, -3.55), V(0.95, 10.15, -3.3) }, { V(-0.95, 9.85, -1.9), V(0.95, 10.15, -1.65) }, { V(-0.95, 9.85, -3.55), V(-0.7, 10.15, -1.65) }, { V(0.7, 9.85, -3.55), V(0.95, 10.15, -1.65) } } do
				decor(h:box('Rim', e[1], e[2], rim, M.SmoothPlastic))
			end
			local net = decor(h:box('Net', V(-0.75, 8.9, -3.35), V(0.75, 9.85, -1.85), P.white, M.SmoothPlastic))
			net.Transparency, net.CastShadow = 0.35, false
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
	-- Low court-side fences across the walk (waist-high, so the next gate's power board reads over them).
	for _, z in { z1 + 1.5, z0 - 1.5 } do chainLink(d, V(-FRONT + 1, 0, z), V(FRONT - 1, 0, z), 4.5, { { FRONT - 1 - 8, FRONT - 1 + 8 } }) end
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
	if t == 3 then chainLink(d, V(-FRONT + 1, 0, top - 60), V(FRONT - 1, 0, top - 60), 4.5, { { FRONT - 1 - 9, FRONT - 1 + 9 } }) end
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
	-- A notch quieter than the shared prop builds it: gold trims in plastic instead of neon, a deep red skirt,
	-- softer rope colours (they still cycle) and a crowd in less hot shirts.
	local gold = C(226, 184, 84)
	for _, p in ringModel:GetDescendants() do
		if not p:IsA('BasePart') then continue end
		if p.Name == 'ApronTrim' or p.Name == 'SignNeon' or p.Name == 'CanvasLogo' or p.Name == 'BleacherNose' then
			p.Color, p.Material = gold, p.Name == 'CanvasLogo' and M.Fabric or M.SmoothPlastic
		elseif p.Name == 'Skirt' then
			p.Color = P.boss
		elseif p.Name == 'Rope' or p.Name == 'FanBody' then
			local h, s, v = p.Color:ToHSV()
			p.Color = Color3.fromHSV(h, s * 0.7, v * 0.92)
			if p.Name == 'Rope' then p.Material = M.SmoothPlastic end
		end
	end
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	-- A warm gold champion's aura (tier 8) instead of the tier-9 rainbow: still the best glow on the map, not a
	-- pink-and-rainbow cloud.
	if canvas and vfx then vfx.station(canvas, 8, C(236, 184, 84), V(14, 10, 14)) end
	local bz = BOSS_END + 22
	-- The boss pad on a two-step octagon dais (dark base, cream lip): the stage's one raised platform.
	local dais = b:at(CFrame.new(0, 0, bz))
	Craft.octagon(dais, 'BossDais', 26.4, 0, 0.3, C(96, 100, 110))
	Craft.octagon(dais, 'BossDaisLip', 25, 0.3, 0.5, P.cream)
	local _, pad = fightPad(b, 16, V(0, 0.5, bz), P.boss, 6, 14, 'BOSS')
	local model = pad.parent
	model.Name = 'BossPad'
	model:SetAttribute('Boss', true)
	-- The boss's sign: a framed board on a two-post gantry behind the pad, a gold crown on the beam.
	local sg = b:at(CFrame.new(0, 0, bz - 11.5)):group('BossSign')
	local bossD = Craft.dark(P.boss)
	for _, x in { -10.2, 10.2 } do
		sg:box('GantryFoot', V(x - 1.3, 0, -1.3), V(x + 1.3, 1.0, 1.3), C(150, 152, 160), M.Concrete)
		sg:box('GantryPost', V(x - 0.6, 1.0, -0.6), V(x + 0.6, 16.6, 0.6), bossD, M.SmoothPlastic)
		sg:box('GantryCap', V(x - 0.9, 17.8, -0.9), V(x + 0.9, 18.3, 0.9), P.cream, M.SmoothPlastic)
	end
	sg:box('GantryBeam', V(-11.1, 16.6, -0.6), V(11.1, 17.8, 0.6), bossD, M.SmoothPlastic)
	for _, x in { -6, 6 } do sg:box('SignHanger', V(x - 0.3, 15.6, -0.3), V(x + 0.3, 16.6, 0.3), bossD, M.SmoothPlastic) end
	local face = Craft.board(sg, -8.6, 8.4, 8.6, 15.2, P.boss)
	Craft.words(face, 'BOSS', 'THE FINAL FIGHT', P.boss)
	local gold = C(226, 184, 84)
	sg:box('CrownBand', V(-2.4, 17.8, -0.7), V(2.4, 19.0, 0.7), gold, M.SmoothPlastic)
	for _, x in { -1.8, 0, 1.8 } do
		local k = x == 0 and 1.35 or 1
		sg:part('CrownPoint', V(1.1, 1.1, 1.1) * k, CFrame.new(x, 19.1 + (k - 1) * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 4), gold, M.SmoothPlastic)
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
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 lobby C3 armory backboards, shoe dais text')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN)
	root:SetAttribute('MorphStand', false) -- no Morphs stands in the world any more: looks are equipped from the HUD's EVOLVE menu
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	buildStages(ctx)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('HoodSoft') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn in the hood; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
