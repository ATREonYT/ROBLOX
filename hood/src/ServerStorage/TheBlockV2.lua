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
-- quieter (Brief 8): big surfaces (walls, ground, courts) at about HSV S 0.45-0.55 in mid-tones, objects (pads,
-- boards, props) at S <= 0.7; small accents may stay bright. (Critic round 1: not too dull either; the streets
-- should sit at about 4-6% loud pixels.)
local P = {
	-- Ground.
	tileA = C(206, 208, 213), tileB = C(193, 196, 202), band = C(146, 149, 156), bandLine = C(236, 236, 238),
	kerb = C(222, 222, 226), wall = C(214, 214, 218), grass = C(116, 178, 86), asphalt = C(70, 72, 78), roadLine = C(240, 240, 240),
	court = C(214, 166, 130), courtKey = C(190, 120, 90), courtLine = C(250, 246, 236),
	-- Buildings.
	brick = C(190, 102, 84), brickDark = C(160, 84, 70), brickPink = C(210, 124, 100), slate = C(62, 68, 84), stone = C(158, 158, 164),
	tan = C(228, 184, 120), tanLight = C(238, 212, 168), tanDark = C(176, 150, 116),
	glass = C(54, 72, 102), frame = C(214, 214, 220), door = C(46, 128, 86), doorDark = C(48, 52, 62),
	barberBlue = C(56, 92, 182), groceryGreen = C(100, 154, 104), groceryYellow = C(238, 214, 148), shopBlue = C(88, 124, 192),
	warehouse = C(88, 124, 192), warehouseDark = C(56, 80, 136), rollDoor = C(72, 76, 84),
	-- Props.
	leaf = C(104, 186, 70), leafDark = C(90, 168, 60), hedge = C(78, 160, 64), trunk = C(122, 82, 52), planter = C(196, 196, 202),
	iron = C(36, 38, 44), lampGlow = C(255, 220, 140), wood = C(186, 134, 90), woodDark = C(142, 100, 68), crate = C(198, 152, 98),
	dumpster = C(58, 140, 90), black = C(28, 30, 34), white = C(250, 250, 250), cream = C(240, 236, 226),
	containerRed = C(196, 82, 66), containerBlue = C(64, 108, 192), containerGreen = C(74, 158, 102),
	-- Fight pads and district signs (gameplay colours: the loudest things on the street, but not neon-loud).
	padRed = C(214, 84, 74), padBlue = C(66, 116, 212), padGreen = C(64, 176, 104), bossRing = C(110, 230, 140), boss = C(184, 76, 70),
	spawnBlue = C(60, 190, 255), evolveBlue = C(40, 88, 210), evolveYellow = C(252, 206, 52),
	-- Districts: brick red, violet, court orange, apartment amber-gold (kept apart from the orange), yards blue.
	district = { C(206, 84, 72), C(130, 84, 212), C(220, 136, 78), C(224, 172, 84), C(74, 122, 208) },
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
local SPAWN = V(0, 0, 34) -- the lobby's spawn pad on the hall's spine, level with BAY 1 (the free lane) to its west
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
-- CornerWedgePart (its high corner at local +X, -Z) in the context's frame.
function Craft.cornerWedge(c, name, size, cf, color)
	local p = Instance.new('CornerWedgePart')
	p.Name, p.Anchored, p.Size, p.Color, p.Material = name, true, size, color, M.SmoothPlastic
	p.CFrame = V2.Origin * c.cf * cf
	p.Parent = c.parent
	return p
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
-- Chain-link fence along a straight line, with optional gaps { from, to } (distance along the line). see: the mesh's
-- transparency (0.45 by default; a court cage uses more, so the court reads through it). tint: the posts, rails and
-- mesh in one coating colour instead of black iron and grey mesh.
local function chainLink(c, a, b, h, gaps, see, tint)
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
	for _, t in posts do c:post('FencePost', 0.32, h + 0.2, a + u * t, tint or P.iron, M.Metal) end
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
			local mesh = c:part('ChainLink', V(0.1, h - 0.4, (p1 - p0).Magnitude), CFrame.lookAt(mid + up, p1 + up), tint or C(70, 74, 82), M.DiamondPlate)
			mesh.Transparency = see or 0.45
			mesh.CastShadow = false
			decor(plank(c, 'FenceRail', p0 + V(0, h, 0), p1 + V(0, h, 0), 0.25, 0.25, tint or P.iron, M.Metal))
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

-- Fight pad: a small street boxing ring (Brief 9: it must read as a place to fight, in the same language as the boss
-- yard's Champ Ring, not as a "stand here" mat). A dark base, a cream apron, the mat in the pad's colour with its
-- number, a dark post at each corner under a padded cushion, and two cream ropes on three sides. The side players
-- walk up from (+Z) stays open, so you step into it; the ropes don't collide. No name plate. 17 parts, no neon.
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
	local r = h + 0.35 -- (the posts stand on the apron, just outside the mat)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local p = V(x * r, 0.55, z * r)
			pad:post('CornerPost', 0.35, 4.3, p, D, M.SmoothPlastic)
			pad:box('CornerPad', p + V(-0.5, 2.3, -0.5), p + V(0.5, 4.1, 0.5), color, M.SmoothPlastic)
		end
	end
	-- The ropes, at two heights on the back (-Z) and both sides.
	for _, y in { 3.15, 4.3 } do
		decor(pad:box('Rope', V(-r, y - 0.16, -r - 0.16), V(r, y + 0.16, -r + 0.16), P.cream, M.SmoothPlastic))
		for _, x in { -1, 1 } do decor(pad:box('Rope', V(x * r - 0.16, y - 0.16, -r), V(x * r + 0.16, y + 0.16, r), P.cream, M.SmoothPlastic)) end
	end
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

-- Teleport pad, built as a bus stop (Brief 9: a transit point by its shape, small and plain), 7 parts. A round
-- boarding spot on the pavement (a grey kerb ring round a disc in the stop's colour) and, at its back edge, a pole
-- with a flag sign in the same colour. The sign carries a white pictogram that pokes through both faces: a house
-- for SPAWN, a flag for FURTHEST STAGE. The label under it is the only text. Each target keeps one hue everywhere:
-- SPAWN rose, FURTHEST gold; anything else takes `color`. The disc keeps the pad's name and the prompt (StageService
-- handles targets 'Lobby' and 'Furthest'). The disc is low enough to walk onto.
local function teleportPad(g, name, x, z, color, target, label)
	local main = ({ Lobby = C(204, 92, 158), Furthest = C(226, 184, 84) })[target] or color
	local white, pole = C(244, 242, 238), C(70, 74, 84)
	local o = V(x, 0, z)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- (cylinders lie along X; this stands them up)
	g:part(name .. 'Kerb', V(0.3, 4.8, 4.8), CFrame.new(o + V(0, 0.15, 0)) * up, C(150, 152, 158), M.SmoothPlastic, Enum.PartType.Cylinder)
	local pad = g:part(name, V(0.16, 4.0, 4.0), CFrame.new(o + V(0, 0.38, 0)) * up, main, M.SmoothPlastic, Enum.PartType.Cylinder)
	-- the pole at the back edge of the spot (+Z: players come from -Z, the slot rule); its sign faces both ways
	local pz = z + 2.6
	g:box(name .. 'Pole', V(x - 0.22, 0, pz - 0.22), V(x + 0.22, 7.0, pz + 0.22), pole, M.SmoothPlastic)
	g:box(name .. 'SignRim', V(x - 1.55, 4.2, pz - 0.2), V(x + 1.55, 7.3, pz + 0.2), white, M.SmoothPlastic)
	local face = g:box(name .. 'Sign', V(x - 1.35, 4.4, pz - 0.26), V(x + 1.35, 7.1, pz + 0.26), main, M.SmoothPlastic)
	if target == 'Lobby' then -- a house: a block with a square turned 45 degrees for its roof
		g:box(name .. 'Icon', V(x - 0.6, 5.6, pz - 0.32), V(x + 0.6, 6.35, pz + 0.32), white, M.SmoothPlastic)
		g:part(name .. 'Icon', V(0.9, 0.9, 0.64), CFrame.new(x, 6.35, pz) * CFrame.Angles(0, 0, math.pi / 4), white, M.SmoothPlastic)
	else -- a flag on its staff
		g:box(name .. 'Icon', V(x - 0.62, 5.45, pz - 0.32), V(x - 0.44, 6.9, pz + 0.32), white, M.SmoothPlastic)
		g:box(name .. 'Icon', V(x - 0.44, 6.05, pz - 0.32), V(x + 0.7, 6.85, pz + 0.32), white, M.SmoothPlastic)
	end
	for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = surface(face, f, 32)
		pcall(function() sg.MaxDistance = 60 end)
		line(sg, 'Title', target == 'Furthest' and 'FURTHEST' or label, white, FONT.loud, 0.6, 0.3, main:Lerp(P.black, 0.55), 2)
	end
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
-- Shooting-range lanes, the numbered bays (Brief 9: a clear bench, target and backstop, nothing on top). Every
-- lane has the same pieces in the same places, so the row reads as one designed series:
--   entrance  two short posts at the aisle end, in the lane's kerb colour. The left (-X) one carries the bay's plaque (BAY n, xN POWER, the
--             Power it needs, open or locked); a rope hangs between them while the lane is locked;
--   bench     a waist-high counter across the firing line with ear muffs, an ammo box and a couple of casings
--             (the cues that say "shooting range" with no words);
--   target    one painted target at the far end (never glowing), its centre 5.8 over the mat, where every
--             shot lands (above the shooter's head from the follow camera);
--   backstop  a wall across the outer end, a little taller every tier.
-- The tier shows in materials and one hero prop, never glow, so each bay reads a little better than the last:
--   1 stone   raw planks, a plywood bullseye on a stake (the humble start, no effects)
--   2 red     a fence of even boards painted navy under a red cap, a red and white board on a navy stake
--   3 lava    a basalt berm, a steel gong on a gong stand, one burning barrel (the lane's only fire)
--   4 arcane  a carnival booth's violet curtain under a pink pelmet, a spinner on a post, a bunch of balloons
--   5 shadow  obsidian blocks, a dark steel plate with violet rings, a cluster of violet crystals (low fog)
--   6 frost   an ice-block wall with a snow cap and icicles, an ice bullseye on an ice pillar (light snow)
--   7 toxic   a ribbed container wall, a lime and navy plate, a toxic drum (bubbles)
--   8 gold    a gold wall with a velvet panel, a gold gong on a gold stand, a crown on the wall (glints)
-- Cartoon targets only: boards, plates, gongs, a spinner. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~11.3 (gold's
-- crown on its 9-stud backstop). opts.vfx = false skips effects, opts.tier overrides the tier (opts.side is ignored).
-- Contract (Lobby.client, Shoot.client, LobbyRules): Training_<Id> > TrainingZone (the shooter's box,
-- invisible), Equipment > Targets > Target1 (Hinge = the pivot part, Swing = the parts that move; attributes
-- Knock = Tip | Swing | Spin, Hit = the sound it makes, Aim = world centre where shots land, Main = true),
-- Equipment > Gear (the stand and the hero prop), Sign (the plaque part: SurfaceGui Label with TextLabels Bay,
-- Power, Cost, Detail; the client writes Detail), LockRope parts (the client hides them once the lane is open),
-- attributes Tier, HitPoint (the target's centre), HitColor, TextColor. Equipment has no Hinge of its own:
-- Shoot.client knocks the target back when a shot lands on it.
local Stations = {}

-- Per tier (Skins.Stations order). rim: the kerb round the mat; mat (+matMat): the inset surface; body/top
-- (+bodyMat, topMat): the bench; stand (+standMat): the target's stake or stand; text: the plaque's "xN POWER"
-- (and the HUD hint); glow: hit sparks. Brief 8 volume: big surfaces stay at HSV saturation 0.6 or less.
Stations.Themes = {
	{ name = 'stone', rim = C(62, 78, 118), mat = C(115, 132, 172), body = C(150, 100, 66), top = C(198, 152, 104),
		stand = C(150, 100, 66), text = C(255, 255, 255), glow = C(255, 236, 200) },
	{ name = 'red', rim = C(30, 34, 70), mat = C(204, 82, 98), body = C(38, 44, 88), top = C(214, 74, 96),
		stand = C(38, 44, 88), text = C(255, 110, 130), glow = C(255, 70, 100) },
	{ name = 'lava', rim = C(160, 92, 64), mat = C(204, 128, 98), body = C(70, 66, 76), bodyMat = M.Metal, top = C(236, 162, 104),
		stand = C(70, 66, 76), standMat = M.Metal, text = C(255, 170, 48), glow = C(255, 150, 40) },
	{ name = 'arcane', rim = C(136, 66, 126), mat = C(168, 100, 192), body = C(120, 72, 170), top = C(214, 120, 188),
		stand = C(120, 72, 170), text = C(224, 150, 255), glow = C(230, 120, 255) },
	{ name = 'shadow', rim = C(72, 46, 110), mat = C(46, 30, 72), body = C(30, 24, 40), top = C(104, 62, 168),
		stand = C(30, 24, 40), standMat = M.Metal, text = C(198, 164, 255), glow = C(176, 120, 255) },
	{ name = 'frost', rim = C(78, 132, 196), mat = C(150, 232, 240), matMat = M.SmoothPlastic, body = C(70, 124, 192), top = C(240, 248, 255),
		stand = C(170, 230, 250), text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', rim = C(60, 150, 84), mat = C(26, 62, 58), body = C(26, 64, 60), top = C(90, 206, 116),
		stand = C(26, 64, 60), standMat = M.Metal, text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'gold', rim = C(208, 166, 84), mat = C(240, 224, 118), body = C(130, 52, 68), bodyMat = M.Fabric, top = C(240, 200, 90),
		stand = C(232, 180, 70), text = C(255, 222, 50), glow = C(255, 222, 80) },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.BOX_Z = -3.2 -- the shooter's box runs from the aisle end to here
Stations.BENCH_Z = -2.75 -- the bench's centre line (it is 0.9 deep)
Stations.BENCH_H = 2.3 -- bench top over the mat: waist height, under the held gun
Stations.FIELD_Z0, Stations.FIELD_Z1 = -1.9, 8.4 -- the target field (effects fill it)
Stations.BACK_Z = 8.5 -- the backstop's front face
Stations.TARGET = V(0, 0.4 + 5.8, 6.0) -- every lane's target centre (where shots land)
Stations.ENTRY_Z = -9.5 -- the entrance posts' centre line
-- The backstop's height over the mat: a little taller every tier, so the row climbs toward gold.
function Stations.wallHeight(tier) return 7.0 + 0.25 * tier end
-- The plaque's state colours (Lobby.client paints the same ones).
Stations.StateColors = { open = C(140, 206, 120), locked = C(217, 119, 106) }

---------------------------------------------------------------------------------------------- shapes
-- Round disc facing -Z (a cylinder lying along the frame's Z): centre `cf`, radius r, thickness th.
function Stations.disc(c, name, cf, r, th, color, material)
	return c:part(name, V(th, 2 * r, 2 * r), cf * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Upright cylinder standing on `pos`.
function Stations.can(c, name, pos, r, h, color, material)
	return c:part(name, V(h, 2 * r, 2 * r), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Bullseye whose back sits on the plane z = 0 of `cf` (facing -Z): painted rings outer to inner from `colors`,
-- each a little prouder than the last so no two share a face. Returns the outer ring.
function Stations.bullseye(c, cf, r, colors, material)
	local n, outer = #colors, nil
	for i, col in colors do
		local th = 0.08 + 0.035 * i
		local p = Stations.disc(c, 'Ring', cf * CFrame.new(0, 0, 0.02 - th / 2), r * (n - i + 1) / n, th, col, type(material) == 'table' and material[i] or material)
		outer = outer or p
	end
	return outer
end
-- Drum (two proud bands and a lid) standing on `pos`. Returns the lid.
function Stations.drum(c, pos, r, h, color, band, lid, material)
	Stations.can(c, 'Drum', pos, r, h, color, material)
	for _, y in { 0.22, 0.7 } do Stations.can(c, 'DrumBand', pos + V(0, h * y - 0.09, 0), r + 0.05, 0.18, band) end
	return Stations.can(c, 'DrumLid', pos + V(0, h, 0), r - 0.06, 0.06, lid or band)
end
-- Party balloon (an egg and a knot) with its string down to `foot`.
function Stations.balloon(c, pos, r, color, foot)
	c:blob('Balloon', V(2 * r, 2.3 * r, 2 * r), pos, color, M.SmoothPlastic)
	c:part('BalloonKnot', V(0.25 * r, 0.25 * r, 0.25 * r), CFrame.new(pos - V(0, 1.2 * r, 0)) * CFrame.Angles(0, 0, math.pi / 4), color)
	if foot then c:bar('BalloonString', pos - V(0, 1.25 * r, 0), foot, 0.06, C(250, 250, 250), M.SmoothPlastic) end
end
-- Icicle hanging from `top` (the centre of its top edge): a wedge turned so its triangle faces -Z, wide at
-- the top, its point at the bottom.
function Stations.icicle(c, top, len, w, color)
	return decor(c:wedge('Icicle', V(0.2, len, w), CFrame.new(top - V(0, len / 2, 0)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), color or C(205, 246, 255)))
end

---------------------------------------------------------------------------------------------- target
-- The lane's one target, the client can knock it: Equipment > Targets > Target1 with a Hinge (the pivot, a ghost
-- part at `pivot`) and a Swing model (build the visible target into the returned context). knock: 'Tip' (tips
-- back about the hinge's X axis with a little hop), 'Swing' (swings on its hanger), 'Spin' (spins about the
-- hinge's Y axis). Shots land on its centre (Stations.TARGET); `hit` names the sound (Ding steel, Tock wood, Ice).
function Stations.target(k, pivot, knock, hit)
	local tc, model = k.targets:group('Target1')
	ghost(tc:part('Hinge', V(0.2, 0.2, 0.2), pivot, P.white))
	local sw = tc:group('Swing')
	model:SetAttribute('Knock', knock)
	model:SetAttribute('Hit', hit or 'Ding')
	model:SetAttribute('Aim', tc:world(CFrame.new(Stations.TARGET)).Position)
	model:SetAttribute('Main', true)
	if knock == 'Tip' then model:SetAttribute('TipMin', 0) end -- (rocks back off its stand, never into the shooter)
	k.main = model
	return sw, model
end
-- A stake behind the target: a foot block on the mat and a post up to `top`, its front 0.3 behind the target.
function Stations.stake(g, t, top)
	local Y, z = Stations.MAT_Y, Stations.TARGET.Z
	g:box('StandFoot', V(-0.75, Y, z + 0.1), V(0.75, Y + 0.3, z + 1.5), t.stand:Lerp(C(0, 0, 0), 0.25), t.standMat)
	g:box('StandPost', V(-0.24, Y + 0.3, z + 0.32), V(0.24, top, z + 0.8), t.stand, t.standMat)
end
-- A gong stand: two posts on feet either side of the target and a bar across the top it hangs from. Returns
-- the bar's underside.
function Stations.gongStand(g, t)
	local Y, z = Stations.MAT_Y, Stations.TARGET.Z
	local y1 = Y + 7.9
	local foot = t.stand:Lerp(C(0, 0, 0), 0.25)
	for _, sx in { -1, 1 } do
		g:box('StandFoot', V(sx * 2.25 - 0.45, Y, z - 0.6), V(sx * 2.25 + 0.45, Y + 0.3, z + 0.6), foot, t.standMat)
		g:box('StandPost', V(sx * 2.25 - 0.2, Y + 0.3, z - 0.2), V(sx * 2.25 + 0.2, y1 + 0.4, z + 0.2), t.stand, t.standMat)
	end
	g:box('StandBar', V(-2.55, y1, z - 0.24), V(2.55, y1 + 0.42, z + 0.24), t.stand, t.standMat)
	return y1
end
-- A round board (backing disc `board` plus painted rings) on a stake; it tips back when hit.
function Stations.board(k, t, r, board, rings, hit, boardMat)
	local c = Stations.TARGET
	Stations.stake(k.gear, t, c.Y - 0.6)
	local sw = Stations.target(k, CFrame.new(c.X, c.Y - r - 0.1, c.Z + 0.25), 'Tip', hit or 'Tock')
	Stations.disc(sw, 'Board', CFrame.new(c.X, c.Y, c.Z + 0.12), r + 0.12, 0.2, board, boardMat)
	Stations.bullseye(sw, CFrame.new(c.X, c.Y, c.Z + 0.03), r, rings)
	return sw
end
-- A gong (rim, face, painted rings: rim/face colours and materials) hanging on two short straps from a gong stand; it swings when hit.
function Stations.gong(k, t, r, rim, rimMat, face, faceMat, rings)
	local c = Stations.TARGET
	local y1 = Stations.gongStand(k.gear, t)
	local sw = Stations.target(k, CFrame.new(c.X, y1, c.Z), 'Swing', 'Ding')
	Stations.disc(sw, 'GongRim', CFrame.new(c.X, c.Y, c.Z + 0.03), r, 0.24, rim, rimMat)
	Stations.disc(sw, 'Gong', CFrame.new(c.X, c.Y, c.Z - 0.02), r - 0.22, 0.28, face, faceMat)
	Stations.bullseye(sw, CFrame.new(c.X, c.Y, c.Z - 0.14), (r - 0.22) * 0.68, rings)
	for _, sx in { -1, 1 } do
		sw:box('GongStrap', V(sx * 0.6 - 0.08, c.Y + r - 0.25, c.Z - 0.06), V(sx * 0.6 + 0.08, y1, c.Z + 0.06), C(52, 54, 66))
	end
	return sw
end

---------------------------------------------------------------------------------------------- lane pieces
-- The base: a low studded kerb round the mat (one course) and the flat inset mat.
function Stations.base(st, t)
	local X, Z, MX, MZ, Y = Stations.HALF_X, Stations.HALF_Z, Stations.HALF_X - 1, Stations.HALF_Z - 1, Stations.MAT_Y
	for _, b in { { V(-X, 0, -Z), V(X, Stations.RIM_Y, -MZ) }, { V(-X, 0, MZ), V(X, Stations.RIM_Y, Z) }, { V(-X, 0, -MZ), V(-MX, Stations.RIM_Y, MZ) }, { V(MX, 0, -MZ), V(X, Stations.RIM_Y, MZ) } } do
		studs(st:box('Rim', b[1], b[2], t.rim))
	end
	local mat = st:box('Mat', V(-MX, 0, -MZ), V(MX, Y, MZ), t.mat, t.matMat or M.Plastic)
	if mat.Material == M.Plastic then studs(mat) end
end

-- The firing line: a waist-high counter across the lane (a body and a top that overhangs it a little), and on it
-- ear muffs, an ammo box and two casings. Even bays mirror the props, so neighbours never match.
function Stations.bench(st, t, tier)
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	g:box('BenchBody', V(-3.4, Y, z - 0.42), V(3.4, Y + h - 0.3, z + 0.42), t.body, t.bodyMat or M.SmoothPlastic)
	g:box('BenchTop', V(-3.6, Y + h - 0.3, z - 0.62), V(3.6, Y + h, z + 0.5), t.top, t.topMat or M.SmoothPlastic)
	local d = st:group('BenchProps')
	local y, flip = Y + h, tier % 2 == 0 and -1 or 1
	-- Ear muffs: two dark cups under a yellow band.
	local mx = -2.5 * flip
	for _, sx in { -1, 1 } do
		decor(d:blob('EarCup', V(0.5, 0.55, 0.55), V(mx + sx * 0.4, y + 0.28, z - 0.05), C(50, 52, 60), M.SmoothPlastic))
	end
	decor(d:box('EarBand', V(mx - 0.5, y + 0.5, z - 0.12), V(mx + 0.5, y + 0.64, z + 0.02), C(255, 210, 50)))
	-- Ammo box (olive, a yellow stripe) and two brass casings beside it.
	local ax = 2.5 * flip
	decor(d:box('AmmoBox', V(ax - 0.45, y, z - 0.3), V(ax + 0.45, y + 0.48, z + 0.22), C(86, 104, 58)))
	decor(d:box('AmmoStripe', V(ax - 0.47, y + 0.3, z - 0.32), V(ax + 0.47, y + 0.38, z + 0.24), C(250, 200, 40)))
	for _, s in { { -0.85, -0.18, 0.3 }, { -1.15, 0.12, 1.6 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(ax + s[1] * flip, y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), C(236, 186, 76), M.Metal, Enum.PartType.Cylinder))
	end
end

-- The entrance at the aisle end: the plaque post (left) and a rope post (right) on the kerb, with a rope between
-- them while the lane is locked (the first paint is a new player's view: only bay 1 open; Lobby.client repaints
-- it), and the bay's one plaque on the left post, tilted back a little for the camera: BAY n, xN POWER, the Power
-- it needs (FREE on bay 1) and its state, readable up close (hidden past 60 studs).
function Stations.entrance(st, s, t, tier)
	local z, y0 = Stations.ENTRY_Z, Stations.RIM_Y
	local post = t.rim:Lerp(C(0, 0, 0), 0.2) -- (the lane's own kerb colour: the posts belong to the bay)
	local g = st:group('Entrance')
	g:box('PlaquePost', V(-4.22, y0, z - 0.2), V(-3.82, y0 + 2.5, z + 0.2), post)
	g:box('RopePost', V(3.84, y0, z - 0.18), V(4.2, y0 + 1.95, z + 0.18), post)
	g:box('RopePostCap', V(3.78, y0 + 1.95, z - 0.24), V(4.26, y0 + 2.15, z + 0.24), post)
	local a, m, b = V(-3.82, y0 + 1.8, z), V(0, y0 + 1.4, z), V(3.84, y0 + 1.8, z)
	for _, seg in { { a, m }, { m, b } } do
		local rope = decor(g:bar('LockRope', seg[1], seg[2], 0.16, C(186, 52, 60), M.SmoothPlastic))
		rope.CastShadow = false
		rope.Transparency = tier == 1 and 1 or 0
	end
	-- The plaque: a small board (1.5 x 1.8) in a deep shade of the lane's kerb colour on the post's top (it belongs to the
	-- bay, and with the text hidden it is a small coloured tab, not a black board), its text on a SurfaceGui.
	local sign = decor(g:part('Sign', V(1.5, 1.8, 0.16), CFrame.new(-3.6, y0 + 3.2, z - 0.12) * CFrame.Angles(math.rad(10), 0, 0), t.rim:Lerp(C(10, 10, 16), 0.45)))
	sign.CastShadow = false
	local gui = surface(sign, Enum.NormalId.Front, 60)
	gui.Name = 'Label'
	gui.MaxDistance = 60
	local ink = C(15, 15, 25)
	local open = s.Required == 0
	line(gui, 'Bay', string.upper(s.Name or ('BAY ' .. tier)), P.white, FONT.loud, 0.05, 0.3, ink, 2)
	line(gui, 'Power', 'x' .. s.Multiplier .. ' POWER', t.text, FONT.title, 0.37, 0.2, ink, 2)
	line(gui, 'Cost', open and 'FREE' or ('💪 ' .. compact(s.Required)), P.white, FONT.title, 0.6, 0.17, ink, 2)
	line(gui, 'Detail', open and 'OPEN' or 'LOCKED', Stations.StateColors[open and 'open' or 'locked'], FONT.title, 0.79, 0.15, ink, 2)
	return sign
end

-- The backstop's body: one wall across the outer end, `h` over the mat, and a cap on it (a lip proud of the
-- front). Returns the wall and the cap's top.
function Stations.wall(c, h, color, material, cap, capMat)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	local wall = c:box('Backstop', V(-4.3, 0, z0), V(4.3, Y + h, z1), color, material)
	if cap then c:box('BackstopCap', V(-4.4, Y + h, z0 - 0.12), V(4.4, Y + h + 0.4, z1 + 0.05), cap, capMat) end
	return wall, Y + h + (cap and 0.4 or 0)
end
-- A backstop of n upright boards side by side across the outer end, `h` over the mat (plus dh[i] each),
-- alternating `colors`, every other one set back `step`: raw planks, painted boards, a curtain's folds.
function Stations.boards(c, name, h, n, colors, dh, material, step)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	local w = 8.6 / n
	for i = 1, n do
		local x = -4.3 + (i - 1) * w
		c:box(name, V(x + 0.03, 0, z0 + (i % 2) * (step or 0.08)), V(x + w - 0.03, Y + h + (dh and dh[i] or 0), z1), colors[(i - 1) % #colors + 1], material)
	end
end
-- The cap along a backstop's top (a lip proud of the front), `h` over the mat.
function Stations.cap(c, h, color, material)
	local Y = Stations.MAT_Y
	return c:box('BackstopCap', V(-4.4, Y + h, Stations.BACK_Z - 0.16), V(4.4, Y + h + 0.4, Stations.HALF_Z - 0.05), color, material)
end

---------------------------------------------------------------------------------------------- lanes
-- One builder per theme: the backstop, the target on its stand and the hero prop. `k` holds st (the station),
-- gear (Equipment > Gear), targets (Equipment > Targets), t, tier and burners (hero parts that carry the
-- theme's effect: the barrel's coals, the drum's lid).
Stations.Lanes = {}
local WHITE, RED = C(250, 250, 245), C(226, 56, 60)

-- 1 Stone: a fence of raw planks of uneven height, a plywood bullseye on a wooden stake.
function Stations.Lanes.stone(k)
	local h = Stations.wallHeight(k.tier)
	local back = k.st:group('Backstop')
	Stations.boards(back, 'Plank', h, 6, { C(176, 124, 82), C(150, 102, 66) }, { -0.35, 0.1, -0.2, 0.2, -0.3, 0.05 })
	Stations.board(k, k.t, 1.55, C(206, 160, 110), { WHITE, RED, WHITE, RED })
end

-- 2 Red: a fence of even boards painted navy under a red cap (the raw planks, done properly); a red and white
-- bullseye on a navy board and stake.
function Stations.Lanes.red(k)
	local h = Stations.wallHeight(k.tier)
	local back = k.st:group('Backstop')
	Stations.boards(back, 'Board', h, 5, { C(46, 52, 100), C(38, 44, 88) }, nil, M.SmoothPlastic, 0.05)
	Stations.cap(back, h, k.t.top)
	Stations.board(k, k.t, 1.6, C(38, 44, 88), { WHITE, C(235, 35, 60), WHITE, C(235, 35, 60), C(255, 214, 40) })
end

-- 3 Lava: a basalt berm (a base and two tilted boulders on it, a jagged top), a dark steel gong with painted orange rings on a steel gong stand, and
-- one burning barrel at the berm's foot (HoodVFX sets its coals on fire: the lane's only flame).
function Stations.Lanes.lava(k)
	local Y, h, z0, z1 = Stations.MAT_Y, Stations.wallHeight(k.tier), Stations.BACK_Z, Stations.HALF_Z - 0.1
	local back = k.st:group('Backstop')
	local rock, rock2 = C(62, 44, 48), C(84, 58, 58)
	local zc = (z0 + z1) / 2
	back:part('Basalt', V(8.6, Y + h * 0.55, z1 - z0), CFrame.new(0, (Y + h * 0.55) / 2, zc), rock, M.Slate)
	back:part('Basalt', V(4.8, h * 0.42, z1 - z0 - 0.3), CFrame.new(-1.6, Y + h * 0.7, zc) * CFrame.Angles(0, math.rad(3), math.rad(9)), rock2, M.Slate)
	back:part('Basalt', V(3.8, h * 0.34, z1 - z0 - 0.3), CFrame.new(2.0, Y + h * 0.66, zc) * CFrame.Angles(0, math.rad(-3), math.rad(-12)), rock, M.Slate)
	Stations.gong(k, k.t, 1.62, C(70, 66, 76), M.Metal, C(96, 90, 102), M.Metal, { C(240, 120, 40), C(96, 90, 102), C(255, 196, 80) })
	local pos = V(3.15, Y, 7.3)
	Stations.drum(k.gear, pos, 0.6, 1.7, C(150, 50, 32), C(70, 34, 28), C(40, 24, 22), M.Metal)
	table.insert(k.burners, k.gear:part('Coals', V(0.08, 0.98, 0.98), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 40), M.SmoothPlastic, Enum.PartType.Cylinder))
end

-- 4 Arcane: a carnival booth's violet curtain (seven folds) under a pink pelmet, a spinner (pink, violet and white rings) on a violet post that turns
-- slowly and spins when hit, and a bunch of three balloons tied by the post, bobbing.
function Stations.Lanes.arcane(k)
	local Y, c = Stations.MAT_Y, Stations.TARGET
	local h = Stations.wallHeight(k.tier)
	local back = k.st:group('Backstop')
	Stations.boards(back, 'Curtain', h, 7, { C(112, 66, 158), C(90, 52, 132) }, nil, M.Fabric, 0.14)
	Stations.cap(back, h, k.t.top)
	Stations.stake(k.gear, k.t, c.Y)
	local sw = Stations.target(k, CFrame.new(c), 'Spin', 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(c.X, c.Y, c.Z + 0.12), 1.72, 0.16, k.t.body)
	Stations.bullseye(sw, CFrame.new(c.X, c.Y, c.Z + 0.03), 1.6, { WHITE, C(255, 100, 200), WHITE, C(150, 60, 220), C(255, 220, 60) })
	local bc, bunch = k.gear:group('BalloonBunch')
	local foot = V(2.7, Y + 0.3, 6.6)
	bc:box('BalloonWeight', foot - V(0.25, 0.3, 0.25), foot + V(0.25, 0.05, 0.25), C(255, 214, 60))
	for i, col in { C(255, 90, 170), C(255, 220, 60), C(120, 220, 255) } do
		Stations.balloon(bc, foot + V((i - 2) * 0.75, 4.2 + (i % 2) * 0.6, (i - 2) * 0.2), 0.6, col, foot)
	end
	for _, p in bunch:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	bunch.WorldPivot = bc:world(CFrame.new(foot))
	bunch:SetAttribute('Bob', 0.14)
	bunch:SetAttribute('BobPeriod', 2.6)
	bunch:AddTag('HoodMotion')
end

-- 5 Shadow: a wall of big obsidian blocks (two courses, offset) under a violet cap, a dark steel plate with
-- painted violet and lavender rings on a black stake, and a cluster of violet crystals at the wall's foot.
function Stations.Lanes.shadow(k)
	local Y, h, z0, z1 = Stations.MAT_Y, Stations.wallHeight(k.tier), Stations.BACK_Z, Stations.HALF_Z - 0.1
	local violet, dark = C(170, 110, 255), C(40, 30, 60)
	local back = k.st:group('Backstop')
	for row = 0, 1 do
		local ya, yb = row == 0 and 0 or Y + h * 0.55, row == 0 and Y + h * 0.55 or Y + h
		local xs = row == 0 and { -4.3, 0.7, 4.3 } or { -4.3, -1.5, 4.3 }
		for i = 1, 2 do
			back:box('Obsidian', V(xs[i] + 0.04, ya, z0 + ((i + row) % 2) * 0.1), V(xs[i + 1] - 0.04, yb - 0.04, z1), (i + row) % 2 == 0 and C(34, 24, 50) or C(26, 18, 40), M.Slate)
		end
	end
	Stations.cap(back, h, k.t.top)
	Stations.board(k, k.t, 1.6, dark, { violet, dark, C(214, 190, 255), dark, violet }, 'Ding', M.Metal)
	local cc = k.gear:group('Crystals')
	for _, s in { { 2.9, 7.5, 1.1, 3.2, 8 }, { 2.05, 7.9, 0.85, 2.2, -14 }, { 3.6, 7.0, 0.75, 1.6, 20 } } do
		local p = cc:part('Crystal', V(s[3], s[4], s[3]), CFrame.new(s[1], Y + s[4] / 2 - 0.1, s[2]) * CFrame.Angles(0, math.rad(45), math.rad(s[5])), violet, M.Glass)
		p.Transparency = 0.15
	end
end

-- 6 Frost: a wall of four big ice blocks under a studded snow cap with icicles, an ice bullseye (white and deep
-- blue) on an ice pillar.
function Stations.Lanes.frost(k)
	local Y, h, z0, z1 = Stations.MAT_Y, Stations.wallHeight(k.tier), Stations.BACK_Z, Stations.HALF_Z - 0.1
	local snow, iceA, iceB, deep = C(248, 252, 255), C(150, 225, 250), C(120, 205, 240), C(25, 120, 235)
	local back = k.st:group('Backstop')
	for row = 0, 1 do
		local ya, yb = row == 0 and 0 or Y + h / 2, row == 0 and Y + h / 2 or Y + h
		local xs = row == 0 and { -4.3, 0.4, 4.3 } or { -4.3, -1.2, 4.3 }
		for i = 1, 2 do
			local p = back:box('IceWall', V(xs[i] + 0.04, ya, z0 + ((i + row) % 2) * 0.1), V(xs[i + 1] - 0.04, yb - 0.04, z1), (i + row) % 2 == 0 and iceA or iceB)
			p.Reflectance = 0.15
		end
	end
	studs(back:box('SnowTop', V(-4.4, Y + h, z0 - 0.12), V(4.4, Y + h + 0.45, z1 + 0.05), snow))
	for i, len in { 0.9, 0.6, 1.1, 0.7 } do Stations.icicle(back, V(-3.3 + (i - 1) * 2.2, Y + h, z0 - 0.06), len, 0.36) end
	local c = Stations.TARGET
	local pillar = k.gear:box('IcePillar', V(-0.55, Y, c.Z + 0.3), V(0.55, c.Y - 1.5, c.Z + 1.3), C(170, 230, 250))
	pillar.Reflectance = 0.15
	local sw = Stations.target(k, CFrame.new(c.X, c.Y - 1.72, c.Z + 0.25), 'Tip', 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(c.X, c.Y, c.Z + 0.12), 1.72, 0.2, C(90, 200, 245))
	Stations.bullseye(sw, CFrame.new(c.X, c.Y, c.Z + 0.03), 1.6, { snow, deep, snow, deep, WHITE })
end

-- 7 Toxic: a dark ribbed container wall, a lime and navy bullseye on a dark plate and stake, and a lime toxic drum
-- at the wall's foot (HoodVFX bubbles out of its lid).
function Stations.Lanes.toxic(k)
	local Y, h, z0 = Stations.MAT_Y, Stations.wallHeight(k.tier), Stations.BACK_Z
	local lime, navy, dark = C(110, 220, 90), C(24, 30, 70), C(26, 64, 60)
	local back = k.st:group('Backstop')
	Stations.wall(back, h, dark, M.Metal, k.t.rim)
	for _, x in { -2.9, 0, 2.9 } do back:box('Rib', V(x - 0.2, 0.6, z0 - 0.16), V(x + 0.2, Y + h, z0 + 0.1), dark:Lerp(C(255, 255, 255), 0.14), M.Metal) end
	Stations.board(k, k.t, 1.6, navy, { WHITE, navy, lime, navy, lime }, 'Ding', M.Metal)
	table.insert(k.burners, Stations.drum(k.gear, V(-3.0, Y, 7.3), 0.7, 2.0, lime, navy, C(40, 120, 50)))
end

-- 8 Gold: a gold wall with a crimson velvet panel and a cream cap, a gold gong with a velvet ring and a ruby on a
-- gold gong stand, and a crown on the wall's cap that turns slowly (the top bay's hero).
function Stations.Lanes.gold(k)
	local Y, h, z0 = Stations.MAT_Y, Stations.wallHeight(k.tier), Stations.BACK_Z
	local gold, deep, velvet = C(255, 222, 40), C(245, 190, 0), C(130, 52, 68)
	local back = k.st:group('Backstop')
	local _, top = Stations.wall(back, h, C(220, 180, 90), M.SmoothPlastic, C(255, 248, 220))
	back:box('Velvet', V(-3.6, 1.2, z0 - 0.08), V(3.6, Y + h - 0.6, z0 + 0.1), velvet, M.Fabric)
	local sw = Stations.gong(k, k.t, 1.8, deep, M.SmoothPlastic, gold, M.SmoothPlastic, { velvet, gold })
	sw:part('GongRuby', V(0.5, 0.5, 0.3), CFrame.new(Stations.TARGET + V(0, 0, -0.32)) * CFrame.Angles(0, 0, math.pi / 4), C(235, 30, 70), M.Glass)
	-- The crown: a gold band on a cream rim with five points and a ruby, on the cap's middle.
	local at = CFrame.new(0, top, Stations.HALF_Z - 1.05) -- (on the cap, inside the slot's back edge)
	local cc, crown = back:group('Crown')
	cc:part('CrownRim', V(0.24, 2.1, 2.1), at * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), C(255, 252, 235), M.SmoothPlastic, Enum.PartType.Cylinder)
	cc:part('CrownBand', V(0.7, 1.85, 1.85), at * CFrame.new(0, 0.59, 0) * CFrame.Angles(0, 0, math.pi / 2), deep, M.SmoothPlastic, Enum.PartType.Cylinder)
	for i = 0, 4 do
		cc:part('CrownPoint', V(0.62, 0.62, 0.3), at * CFrame.Angles(0, i * 2 * math.pi / 5, 0) * CFrame.new(0, 1.05, -0.78) * CFrame.Angles(0, 0, math.pi / 4), gold)
	end
	cc:part('CrownGem', V(0.36, 0.36, 0.2), at * CFrame.new(0, 0.6, -0.97) * CFrame.Angles(0, 0, math.pi / 4), C(235, 30, 70), M.Glass)
	for _, p in crown:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	crown.WorldPivot = cc:world(at)
	crown:SetAttribute('Spin', 30)
	crown:AddTag('HoodMotion')
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
	local st, model = ctx:group('Training_' .. stationId)
	model:SetAttribute('Theme', t.name)

	Stations.base(st, t)
	local Y, MX = Stations.MAT_Y, Stations.HALF_X - 1
	-- Where the player stands to train: the shooter's box, from the aisle edge to just short of the bench.
	local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
	Stations.bench(st, t, tier)
	Stations.entrance(st, s, t, tier)

	-- Equipment: the stand and the hero prop (Gear) and the knockable target (Targets).
	local eq = st:group('Equipment')
	local k = { st = st, gear = eq:group('Gear'), targets = eq:group('Targets'), t = t, tier = tier, burners = {} }
	local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
	lane(k)
	-- The target and small gear never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(Stations.TARGET)).Position)
	model:SetAttribute('HitColor', t.glow)
	if opts.vfx ~= false and VFX and VFX.theme then
		-- The theme's effect comes off its hero prop (the barrel, the drum) or fills the target field lightly.
		local z0, z1 = Stations.FIELD_Z0, Stations.FIELD_Z1
		local field = ghost(st:box('Field', V(-MX, Y - 0.05, z0), V(MX, Y, z1), P.white))
		field.CanCollide = false
		local mainPart = k.main and k.main:FindFirstChild('Swing') and k.main.Swing:FindFirstChildWhichIsA('BasePart', true)
		VFX.theme(field, t.name, V(2 * MX, 10, z1 - z0), { parent = model, tier = tier, color = t.glow, bag = mainPart, burners = k.burners })
	end
	return model
end
---------------------------------------------------------------------------------------------- armory
-- The ARMORY as a gun shop (Brief 9: it must read as a shop with every sign hidden; Brief 10: no grid, quiet
-- padlocks, a rarity order you can read). A booth in the warehouse: a wood counter facing the hall with the till
-- at the end the customers come from, a lift flap, then a tall glass case; a slat wall behind with the guns hung
-- by kind, the mount itself climbing with the price from the till end:
--   handguns on pegs (bronze)  ->  rifles standing in a rack (silver)  ->  the top shelf (gold)
--   ->  the glass case (diamond, the two best guns on risers)
-- Colour lives only on small parts at each gun: a card behind it in the state colour (a plain grey card while
-- locked, blue owned, green equipped; Armory.client repaints it), a small brass padlock hanging under its tag
-- while it is locked, and the tag's top band in the gun's rarity metal (GunRules.Rarity: bronze, silver, gold,
-- diamond). The equipped gun is taken off its mount (it is in your hands); the mount and the green card stay.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun with attributes GunId, Tier,
-- Cost, Multiplier, streaming Atomic, holding
--   GunPoint_<Id>  invisible part on the counter's (or the case's) front edge in front of the gun: the prompt
--                  anchor and the point GunService measures buying distance from (GunRules.Range)
--   parts the client paints by name from GunRules.Colors[state]: StatePanel (Top: the card behind the gun);
--                  StateLock parts (the padlock) show only while the gun is locked
--   GunTag         SurfaceGui GunLabel on the tag > TextLabels Name, Multiplier, Price (Glyph attribute = icon
--                  text); the client writes the price or the state word into Price
--   Display        Model with the gun (the client hides it while equipped)
-- The Armory model is tagged HoodArmory.
-- Local frame: origin at the middle of the slot's front edge on the hall floor, front faces -Z (customers stand
-- at -Z looking +Z; +X is their left, the north end toward the spawn), footprint x -29.4..29.4, z 0..31.2
-- (Armory.HalfWidth, Armory.Depth), 13.6 tall.
local Armory = {}

Armory.HalfWidth, Armory.Depth = 29.4, 31.2
-- The counter line: front face z0, back z1, counter top height. Along x (north +): the wood counter from the
-- north end to the lift flap, the flap, then the glass case to the south wall.
Armory.Counter = { z0 = 6.5, z1 = 9.5, top = 3.4, north = 29.4, flap = -10.4, case = -13.4, south = -28.6 }
-- The slat wall's face, its thickness and height; the back room behind it runs to the slot's back.
Armory.Wall = { z = 15, t = 0.8, top = 13 }
Armory.TagW, Armory.TagH = 2.7, 1.05
Armory.GunLen, Armory.GunH = 6.8, 3.3 -- the longest and tallest a shown gun may be
-- The mounts. Rack: the rifles' butts stand on a wood rest (top `rest`, front face z `front`), a bar across
-- them at `bar`. Shelf: a wood shelf (top y, front face z) on two brackets. Case: plinth top (the deck), glass
-- top, its front and back glass.
Armory.Rack = { x0 = 10.0, x1 = -1.4, rest = 4.0, front = 12.9, bar = 9.0 }
Armory.Shelf = { x0 = -2.6, x1 = -15.6, y = 7.4, front = 12.3 }
Armory.Case = { deck = 2.0, top = 6.9, front = 6.6, back = 9.45 }
Armory.Till = 27.4 -- the till's x on the counter (at the north end, where customers arrive)
-- Where each gun goes: its mount and its x along the shop (the cheap end, by the till, first); pegs also give
-- the height of the tag's top edge, case risers their height. Each x is its own, so every gun has its own prompt
-- spot along the counter; the gaps follow the guns' lengths, not a fixed pitch.
Armory.Place = {
	Pistol = { mount = 'peg', x = 23.0, y = 4.4 },
	Revolver = { mount = 'peg', x = 17.8, y = 6.7 },
	Uzi = { mount = 'peg', x = 12.9, y = 4.7 },
	Shotgun = { mount = 'rack', x = 7.9 },
	Tommy = { mount = 'rack', x = 4.5 },
	AK = { mount = 'rack', x = 0.9 },
	Deagle = { mount = 'shelf', x = -5.4 },
	Minigun = { mount = 'shelf', x = -11.8 },
	Blaster = { mount = 'case', x = -17.6, rise = 0.3 },
	Diamond = { mount = 'case', x = -24.5, rise = 0.75 },
}
-- Pegs for guns the shop doesn't know yet (opts.guns), high on the north wall; more than these are not hung.
Armory.Spare = { { mount = 'peg', x = 24.4, y = 9.4 }, { mount = 'peg', x = 13.4, y = 9.6 } }
-- The shop's own tones: the hall's greys for the cap, a blue-grey slat wall, a dark-wood counter with a light
-- top, hood brick, plain wood for the rack and shelf, a dark velvet deck in the case, brass.
Armory.Paint = {
	slat = C(92, 98, 112), groove = C(66, 70, 82), skirt = C(70, 72, 80), cap = C(204, 206, 210),
	counter = C(132, 94, 66), counterTop = C(226, 228, 232), kick = C(44, 46, 52), brick = P.brick,
	wood = C(176, 128, 86), velvet = C(54, 52, 64), glass = C(206, 228, 238),
	tag = C(46, 48, 56), peg = C(196, 200, 206), lock = C(170, 140, 70), lockDark = C(118, 96, 48),
}

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

-- The shown gun: GunModels.build when it exists (else the stand-in), at about 3 x its hand size for a pistol and
-- less for the long ones (length ~ hand length ^ 0.5), never longer than GunLen or taller than GunH.
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
	local length = math.max(hi.Z - lo.Z, 0.1)
	local k = math.min(3.7 * length ^ 0.5, Armory.GunLen) / length
	k = math.min(k, Armory.GunH / math.max(hi.Y - lo.Y, 0.1))
	if math.abs(k - 1) > 0.02 then
		model:Destroy()
		model = make(k)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- The gun's rarity metal (GunRules.Rarity by tier; the gun's own colour if GunRules has no bands).
function Armory.rarity(gun)
	local ok, rules = pcall(require, ReplicatedStorage.Shared.GunRules)
	local band = ok and rules.rarity and rules.rarity(gun.Tier)
	return band and band.Color or gun.Color
end

-- A small brass padlock (body and shackle) hanging under the tag's left end at `cf` (its front faces -Z).
function Armory.padlock(s, cf)
	local G = Armory.Paint
	decor(s:part('StateLock', V(0.45, 0.35, 0.18), cf, G.lock))
	decor(s:part('StateLock', V(0.28, 0.24, 0.08), cf * CFrame.new(0, 0.29, 0), G.lockDark))
end

-- The tag: a small dark label with a band in the gun's rarity metal along its top, the name over the multiplier
-- and the price (the client writes the price or the state word); `y` is its top edge, `z` its face. Read at the
-- counter; from across the hall it is only the metal band. The padlock hangs under its left end.
function Armory.tag(s, x, y, z, gun, look, metal)
	local G = Armory.Paint
	local w, h = Armory.TagW, Armory.TagH
	local tag = decor(s:part('GunTag', V(w, h, 0.12), CFrame.new(x, y - h / 2, z), G.tag))
	decor(s:part('GunRarity', V(w + 0.3, 0.34, 0.2), CFrame.new(x, y - 0.17, z - 0.04), metal))
	local g = surface(tag, Enum.NormalId.Front, 80)
	g.Name = 'GunLabel'
	local ink = C(20, 22, 28)
	line(g, 'Name', string.upper(gun.Name), P.white, FONT.title, 0.33, 0.28, ink, 1.5)
	local m = line(g, 'Multiplier', 'x' .. gun.Multiplier, P.white, FONT.loud, 0.63, 0.33, ink, 1.5)
	m.Position, m.Size = UDim2.fromScale(0.06, 0.63), UDim2.fromScale(0.3, 0.33)
	m.TextXAlignment = Enum.TextXAlignment.Left
	local icons = Armory.optional('IconModels')
	local image = icons and icons.Images and icons.Images.Cash
	local p = line(g, 'Price', gun.Cost == 0 and 'FREE' or compact(gun.Cost), look.Text, FONT.loud, 0.63, 0.33, ink, 1.5)
	p.Position, p.Size = UDim2.fromScale(0.34, 0.63), UDim2.fromScale(0.6, 0.33)
	p.TextXAlignment = Enum.TextXAlignment.Right
	if type(image) == 'string' and image ~= '' then
		local i = Instance.new('ImageLabel')
		i.Name = 'PriceIcon'
		i.BackgroundTransparency = 1
		i.Image = image
		i.Position, i.Size = UDim2.fromScale(0.36, 0.63), UDim2.fromScale(0.14, 0.33)
		local a = Instance.new('UIAspectRatioConstraint')
		a.Parent = i
		i.Parent = g
		p:SetAttribute('Glyph', '')
	else
		p.Text = '💵 ' .. p.Text
		p:SetAttribute('Glyph', '💵')
	end
	Armory.padlock(s, CFrame.new(x + w / 2 - 0.45, y - h - 0.32, z))
	return tag
end

-- One gun on its mount: the card behind it, the gun, the mount's own bits (pegs, a stand, a riser), its tag and
-- padlock, and its point on the counter.
function Armory.slot(c, gun, spot, colors)
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, tag and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local G, C0, R, Sh, Ca = Armory.Paint, Armory.Counter, Armory.Rack, Armory.Shelf, Armory.Case
	local x, wz = spot.x, Armory.Wall.z
	local g = Armory.gun(gun)
	local lo, hi = Armory.extents(g, Armory.pivotOf(g))
	local len, tall, thick = hi.Z - lo.Z, hi.Y - lo.Y, hi.X - lo.X
	local mid = (lo + hi) / 2
	-- Rifles stand muzzle up; everything else is shown level in profile, muzzle to the customer's right. w, h:
	-- the gun's outline as the customer sees it.
	local upright = spot.mount == 'rack'
	local w, h = upright and tall or len, upright and len or tall
	local back, gy, tagY, tagZ -- the card's back face, the gun's centre height, the tag's top edge and face
	if spot.mount == 'rack' then
		back, gy, tagY, tagZ = wz, R.rest + 0.05 + h / 2, R.rest - 0.1, R.front - 0.07
	elseif spot.mount == 'shelf' then
		back, gy, tagY, tagZ = wz, Sh.y + 0.3 + h / 2, Sh.y, Sh.front - 0.07
	elseif spot.mount == 'case' then
		back, gy, tagY, tagZ = Ca.back - 0.1, Ca.deck + 0.1 + spot.rise + 0.25 + h / 2, Ca.deck - 0.1, C0.z0 - 0.07
	else
		back, gy, tagY, tagZ = wz, spot.y + 0.2 + h / 2, spot.y, wz - 0.38
	end
	-- the card in the state colour, a little smaller than the gun (the gun overhangs it, so the wall reads as
	-- guns on mounts, not as framed pictures)
	local cw, ch = w * 0.72 + 0.4, h * 0.72 + 0.4
	decor(s:box('StatePanel', V(x - cw / 2, gy - ch / 2, back - 0.3), V(x + cw / 2, gy + ch / 2, back), look.Top))
	local gz = back - 0.3 - 0.25 - thick / 2
	local d, display = s:group('Display')
	local pose = CFrame.new(x, gy, gz) * (upright and CFrame.Angles(0, 0, -math.pi / 2) or CFrame.new()) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(x, gy, gz))
	local bottom = gy - h / 2
	if spot.mount == 'peg' then
		-- two short pegs under it
		for _, px in { x - len * 0.28, x + len * 0.28 } do
			decor(s:box('Peg', V(px - 0.12, bottom - 0.24, gz - 0.2), V(px + 0.12, bottom, wz - 0.3), G.peg))
		end
	elseif spot.mount == 'shelf' or spot.mount == 'case' then
		-- a short dark stand under it (in the case, on a velvet riser)
		local foot = spot.mount == 'shelf' and Sh.y or Ca.deck + 0.1
		if spot.mount == 'case' then
			decor(s:box('Riser', V(x - 1.2, foot, gz - 0.7), V(x + 1.2, foot + spot.rise, gz + 0.7), G.velvet))
			foot += spot.rise
		end
		decor(s:box('Stand', V(x - 0.45, foot, gz - 0.25), V(x + 0.45, bottom, gz + 0.25), G.kick))
	end
	Armory.tag(s, x, tagY, tagZ, gun, look, Armory.rarity(gun))
	if state ~= 'Locked' then
		for _, p in model:GetDescendants() do if p.Name == 'StateLock' then p.Transparency = 1 end end
	end
	-- The point: on the counter's (or the case's) front edge straight in front of the gun.
	ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.5, C0.top, C0.z0 - 0.2), V(x + 0.5, C0.top + 1, C0.z0 + 0.8), P.white)).CastShadow = false
	return model
end

-- The booth: the slat wall with its back room, brick side walls, the wood counter with the till and a stool,
-- the lift flap, the glass case, the rifle rack and the top shelf.
function Armory.shop(c)
	local b = c:group('ArmoryShop')
	local G, X, D, Wl, C0 = Armory.Paint, Armory.HalfWidth, Armory.Depth, Armory.Wall, Armory.Counter
	local R, Sh, Ca = Armory.Rack, Armory.Shelf, Armory.Case
	local wz, top = Wl.z, Wl.top
	-- the slat wall: a blue-grey board with dark grooves every 1.1 studs and a dark skirting
	b:box('SlatWall', V(-X + 0.8, 0, wz), V(X - 0.8, top, wz + Wl.t), G.slat, M.SmoothPlastic)
	for y = 1.6, top - 0.6, 1.1 do
		b:box('SlatGroove', V(-X + 0.8, y, wz - 0.06), V(X - 0.8, y + 0.16, wz + 0.1), G.groove, M.SmoothPlastic)
	end
	b:box('SlatSkirt', V(-X + 0.8, 0, wz - 0.15), V(X - 0.8, 0.9, wz + 0.1), G.skirt, M.SmoothPlastic)
	-- the wall's light cap runs back as the back room's roof (to the warehouse wall)
	b:box('BackRoof', V(-X + 0.9, top, wz - 0.3), V(X - 0.9, top + 0.5, D), G.cap, M.SmoothPlastic)
	-- brick side walls: the north one starts behind the counter, so the counter's end and the till show to
	-- customers coming from the spawn; the south one runs to the counter's front and closes the case's end
	b:box('SideWall', V(X - 0.8, 0, C0.z1), V(X, top, D), G.brick, M.Brick)
	b:box('SideWallCap', V(X - 0.9, top, C0.z1 - 0.1), V(X + 0.1, top + 0.6, D), G.cap, M.SmoothPlastic)
	b:box('SideWall', V(-X, 0, C0.z0), V(-X + 0.8, top, D), G.brick, M.Brick)
	b:box('SideWallCap', V(-X - 0.1, top, C0.z0 - 0.1), V(-X + 0.9, top + 0.6, D), G.cap, M.SmoothPlastic)
	-- the wood counter: dark-wood body on a darker kick plate, a light top with a lip over the front and the end
	local xn, xf = C0.north, C0.flap
	b:box('Counter', V(xf, 0.5, C0.z0 + 0.15), V(xn, C0.top - 0.3, C0.z1), G.counter, M.SmoothPlastic)
	b:box('CounterKick', V(xf, 0, C0.z0 + 0.4), V(xn - 0.25, 0.5, C0.z1 - 0.1), G.kick, M.SmoothPlastic)
	b:box('CounterTop', V(xf, C0.top - 0.3, C0.z0 - 0.15), V(xn + 0.1, C0.top, C0.z1 + 0.15), G.counterTop, M.SmoothPlastic)
	-- the lift flap: a set-back half door under a plain wood flap, the clerk's way out
	b:box('FlapDoor', V(C0.case, 0.3, C0.z1 - 1.3), V(xf, C0.top - 0.3, C0.z1 - 1.1), G.counter, M.SmoothPlastic)
	b:box('Flap', V(C0.case + 0.08, C0.top - 0.3, C0.z0 - 0.15), V(xf - 0.08, C0.top, C0.z1 + 0.15), G.wood, M.SmoothPlastic)
	-- the till at the north end: a dark base with a lighter drawer front, a sloped key block toward the clerk,
	-- the screen on a short post facing the customer
	local tx, tz = Armory.Till, C0.z0 + 1.6
	local t = C0.top
	b:box('Till', V(tx - 1.4, t, tz - 1.0), V(tx + 1.4, t + 0.9, tz + 1.1), G.kick, M.SmoothPlastic)
	b:box('TillDrawer', V(tx - 1.2, t + 0.15, tz - 1.1), V(tx + 1.2, t + 0.6, tz - 0.9), C(70, 74, 84), M.SmoothPlastic)
	b:wedge('TillKeys', V(2.6, 0.6, 1.2), CFrame.new(tx, t + 1.2, tz + 0.45) * CFrame.Angles(0, math.pi, 0), C(70, 74, 84))
	b:box('TillPost', V(tx - 0.15, t + 0.9, tz - 0.3), V(tx + 0.15, t + 2.0, tz), G.kick, M.SmoothPlastic)
	b:box('TillScreen', V(tx - 0.8, t + 1.85, tz - 0.45), V(tx + 0.8, t + 2.7, tz - 0.1), C(70, 150, 120), M.SmoothPlastic)
	-- the clerk's stool behind the till
	local sx, sz = tx - 0.8, C0.z1 + 1.6
	b:post('StoolFoot', 0.75, 0.2, V(sx, 0, sz), G.kick, M.SmoothPlastic)
	b:post('StoolPost', 0.16, 2.3, V(sx, 0.2, sz), G.peg, M.Metal)
	b:post('StoolSeat', 0.85, 0.32, V(sx, 2.5, sz), C(168, 62, 58), M.SmoothPlastic)
	-- the glass case: a dark-wood plinth with a velvet deck, glass on four sides, a light top
	local c0, c1 = C0.south, C0.case
	b:box('CasePlinth', V(c0, 0.45, C0.z0), V(c1, Ca.deck, C0.z1 + 0.1), G.counter, M.SmoothPlastic)
	b:box('CaseKick', V(c0, 0, C0.z0 + 0.25), V(c1 - 0.25, 0.45, C0.z1), G.kick, M.SmoothPlastic)
	b:box('CaseDeck', V(c0, Ca.deck, C0.z0 + 0.1), V(c1 - 0.1, Ca.deck + 0.1, C0.z1), G.velvet, M.SmoothPlastic)
	local function glass(name, a, z)
		local p = decor(b:box(name, a, z, G.glass, M.Glass))
		p.Transparency = 0.72
		p.CastShadow = false
		p.CanCollide = true
	end
	glass('CaseGlass', V(c0, Ca.deck + 0.1, Ca.front - 0.1), V(c1, Ca.top, Ca.front + 0.05))
	glass('CaseGlass', V(c0, Ca.deck + 0.1, Ca.back), V(c1, Ca.top, Ca.back + 0.15))
	glass('CaseGlass', V(c1 - 0.15, Ca.deck + 0.1, Ca.front + 0.05), V(c1, Ca.top, Ca.back))
	b:box('CasePost', V(c1 - 0.25, Ca.deck + 0.1, Ca.front - 0.15), V(c1 + 0.05, Ca.top, Ca.front + 0.15), G.kick, M.SmoothPlastic)
	b:box('CaseTop', V(c0, Ca.top, C0.z0 - 0.05), V(c1 + 0.1, Ca.top + 0.3, C0.z1 + 0.2), G.counterTop, M.SmoothPlastic)
	-- the rifle rack: a wood rest the butts stand on and a bar across the barrels, held off the wall by two arms
	b:box('RackRest', V(R.x1, 0, R.front), V(R.x0, R.rest, wz), G.wood, M.SmoothPlastic)
	b:box('RackBar', V(R.x1, R.bar, R.front + 0.2), V(R.x0, R.bar + 0.4, R.front + 0.5), G.wood, M.SmoothPlastic)
	for _, ax in { R.x1, R.x0 - 0.3 } do
		b:box('RackArm', V(ax, R.bar, R.front + 0.2), V(ax + 0.3, R.bar + 0.4, wz), G.wood, M.SmoothPlastic)
	end
	-- the top shelf on two brackets
	b:box('Shelf', V(Sh.x1, Sh.y - 0.3, Sh.front), V(Sh.x0, Sh.y, wz), G.wood, M.SmoothPlastic)
	for _, bx in { Sh.x1 + 0.8, Sh.x0 - 1.05 } do
		b:wedge('ShelfBracket', V(0.25, 0.9, 1.6), CFrame.new(bx + 0.125, Sh.y - 0.75, wz - 0.8) * CFrame.Angles(0, 0, math.pi), G.wood)
	end
	return b
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local colors = require(ReplicatedStorage.Shared.GunRules).Colors
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.shop(a)
	local spare = 0
	for _, gun in guns do
		local spot = Armory.Place[gun.Id]
		if not spot then
			spare += 1
			spot = Armory.Spare[spare]
		end
		if spot then Armory.slot(a, gun, spot, colors) end
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
-- Brief 9: the first stage of each of the first three districts has its own street plan (The Block, Shop Street, The
-- Courts) instead of the shared corridor. Street holds those plans and the pieces only they use (f2_stages fills in
-- the stage builders and props); `custom` tells the ground which stages lay their own paving.
local Street = { custom = { [1] = true, [4] = true, [7] = true } }
-- A shop's name painted on a plain fascia band across the front above the awning (no framed board, so with the text
-- hidden it is still just a shopfront). Returns the band for the text.
function Street.fascia(c, w, color)
	return c:box('ShopSign', V(0.4, 9.9, 0), V(w - 0.4, 12.5, 0.5), color, M.SmoothPlastic)
end
-- The same frame with the facade at x = ±xFront instead of ±FRONT, so setbacks can differ lot by lot.
function Street.lot(ctx, s, xFront, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-xFront, 0, za), V(-xFront - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(xFront, 0, za - w), V(xFront + 1, 0, za - w)))
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
-- Striped awning from x0 to x1 with its top at y, alternating two colours. stripe: the stripe width (1.6 by default;
-- wider stripes mean fewer parts).
local function stripedAwning(c, x0, x1, y, colors, depth, stripe)
	depth = depth or 3.6
	local n = math.max(2, math.floor((x1 - x0) / (stripe or 1.6)))
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		local col = colors[k % #colors + 1]
		decor(c:wedge('Awning', V(b - a, 1.8, depth), CFrame.new((a + b) / 2, y - 0.9, depth / 2) * CFrame.Angles(0, math.pi, 0), col, M.Fabric))
		decor(c:box('AwningValance', V(a, y - 2.9, depth - 0.2), V(b, y - 1.8, depth), col, M.Fabric))
	end
end
-- depth: how far the building runs back (DEPTH by default); noUnit: no rooftop AC unit.
local function roofCap(c, w, roof, color, depth, noUnit)
	c:box('RoofCap', V(0, roof, -(depth or DEPTH)), V(w, roof + 1.2, 0.7), color, M.SmoothPlastic)
	if not noUnit then Craft.acUnit(c, w * 0.3, roof + 1.2, -10) end
end

-- Red brick walk-up (the concept's asset kit): stone base, slate roof cap, framed windows, green door.
-- o: floors, wall, bays, doorX, door, ground(c, w, bayXs), sideAt, name, depth, noUnit
local function brickBuilding(ctx, w, o)
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local roof = roofOf(o.floors)
	c:box('Wall', V(0, -1, -(o.depth or DEPTH)), V(w, roof, 0), o.wall or P.brick, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 1.6, 0.35), P.stone, M.Concrete)
	roofCap(c, w, roof, P.slate, o.depth, o.noUnit)
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
	local depth = o.depth or DEPTH
	c:box('Wall', V(0, -1, -depth), V(w, roof, 0), o.wall or P.tan, M.Brick)
	c:box('Base', V(0, -1, 0), V(w, 2, 0.35), P.tanDark, M.Concrete)
	for _, x in { 0, w - 1 } do decor(c:box('Pier', V(x, 2, 0), V(x + 1, roof, 0.3), P.tanLight, M.SmoothPlastic)) end
	for f = 2, o.floors do decor(c:box('FloorBand', V(1, storeyY(f) - 0.4, 0), V(w - 1, storeyY(f) + 0.2, 0.25), P.tanLight, M.SmoothPlastic)) end
	c:box('Cornice', V(0, roof - 1.2, 0), V(w, roof + 0.6, 0.9), P.tanLight, M.SmoothPlastic)
	c:box('RoofTop', V(0, roof, -depth), V(w, roof + 0.6, 0), P.tanDark, M.Concrete)
	if not o.noUnit then Craft.acUnit(c, w * 0.7, roof + 0.6, -10) end
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
-- o (optional): depth, stripe (awning stripe width), awningDepth, noUnit, fascia (the name painted on a plain band, no
-- framed board)
local function barberShop(ctx, w, o)
	o = o or {}
	local c = brickBuilding(ctx, w, { name = 'Barber', floors = 2, wall = P.brickPink, depth = o.depth, noUnit = o.noUnit, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), P.barberBlue, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), P.barberBlue, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), P.barberBlue, M.SmoothPlastic)
	end })
	stripedAwning(c, 1.5, w - 1.5, 9.4, { C(208, 74, 66), P.white, C(208, 74, 66), P.white, P.barberBlue }, o.awningDepth, o.stripe)
	local sign = o.fascia and Street.fascia(c, w, P.barberBlue) or c:box('ShopSign', V(w / 2 - 7, 10.2, 0), V(w / 2 + 7, 13.6, 0.8), P.barberBlue, M.SmoothPlastic)
	if not o.fascia then
		decor(c:box('ShopSignBorder', V(w / 2 - 7.4, 9.8, 0), V(w / 2 + 7.4, 14.0, 0.7), P.cream, M.SmoothPlastic))
		decor(c:box('ShopSignCap', V(w / 2 - 7.7, 14.0, 0), V(w / 2 + 7.7, 14.4, 0.9), Craft.dark(P.barberBlue), M.SmoothPlastic))
	end
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'BARBER', P.white, FONT.loud, 0.12, 0.76, C(16, 30, 80), 3)
	-- The pole by the door, turning.
	local pole, poleModel = c:group('BarberPole')
	local p0 = V(w - 0.9, 2, 1.2)
	pole:post('PoleBody', 0.55, 5, p0, P.white, M.SmoothPlastic)
	for k = 0, 4 do
		pole:part('PoleStripe', V(0.35, 1.15, 1.15), CFrame.new(p0 + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(22), 0, 0), k % 2 == 0 and C(208, 74, 66) or P.barberBlue, M.SmoothPlastic, Enum.PartType.Cylinder)
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
-- o (optional): depth, stripe (awning stripe width), noUnit, fascia, noCrates
local function grocery(ctx, w, o)
	o = o or {}
	local c, model = ctx:group('Grocery')
	local roof = roofOf(2)
	local depth = o.depth or DEPTH
	c:box('Wall', V(0, -1, -depth), V(w, 12, 0), P.groceryYellow, M.SmoothPlastic)
	c:box('WallUpper', V(0, 12, -depth), V(w, roof, 0), P.groceryGreen, M.SmoothPlastic)
	roofCap(c, w, roof, C(58, 108, 70), depth, o.noUnit)
	for _, x in bays(w, 3) do window(c, x, storeyY(2) + 3, { frame = P.white }) end
	c:box('ShopGlass', V(2, 1, 0), V(w - 7, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
	for x = 2 + (w - 9) / 3, w - 7.5, (w - 9) / 3 do decor(c:box('ShopMullion', V(x - 0.2, 1, 0), V(x + 0.2, 7.4, 0.4), C(46, 100, 62), M.SmoothPlastic)) end
	c:box('ShopDoorFrame', V(w - 6, 0, 0), V(w - 1.6, 8, 0.3), C(46, 100, 62), M.SmoothPlastic)
	c:box('ShopDoor', V(w - 5.4, 0, 0), V(w - 2.2, 7.4, 0.4), P.glass, M.SmoothPlastic)
	local sign
	if o.fascia then sign = Street.fascia(c, w, C(46, 100, 62))
	else
		decor(c:box('ShopSignBorder', V(0.7, 9.5, 0), V(w - 0.7, 14.1, 0.7), P.cream, M.SmoothPlastic))
		sign = c:box('ShopSign', V(1.2, 10.0, 0), V(w - 1.2, 13.6, 0.9), C(46, 100, 62), M.SmoothPlastic)
		decor(c:box('ShopSignCap', V(0.5, 14.1, 0), V(w - 0.5, 14.5, 1.0), C(36, 78, 50), M.SmoothPlastic))
	end
	line(surface(sign, Enum.NormalId.Back, 20), 'Text', 'GROCERY', C(250, 230, 160), FONT.loud, 0.12, 0.76, C(18, 44, 26), 3)
	stripedAwning(c, 0.5, w - 0.5, 9.4, { C(64, 154, 84), C(244, 232, 196) }, 4, o.stripe)
	-- Produce stand and crates.
	c:box('StandTable', V(2.5, 2.4, 1), V(9.5, 2.8, 4), P.wood, M.WoodPlanks)
	for _, x in { 3, 9 } do c:box('StandLeg', V(x - 0.2, 0, 1.3), V(x + 0.2, 2.4, 3.7), P.woodDark, M.Wood) end
	local fruit = { C(214, 76, 64), C(236, 150, 66), C(124, 186, 78), C(236, 204, 90) }
	for k = 0, 3 do
		local x = 3.2 + k * 1.6
		c:box('ProduceBox', V(x - 0.7, 2.8, 1.4), V(x + 0.7, 3.4, 3.6), P.crate, M.WoodPlanks)
		decor(c:box('Produce', V(x - 0.55, 3.4, 1.55), V(x + 0.55, 3.8, 3.45), fruit[k + 1], M.SmoothPlastic))
	end
	if not o.noCrates then
		crate(c, CFrame.new(w - 9, 0, 2.4), 2.4)
		crate(c, CFrame.new(w - 9, 2.4, 2.4) * CFrame.Angles(0, 0.3, 0), 2)
	end
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
	decor(c:wedge('Awning', V(w - 4, 1.4, 3), CFrame.new(w / 2, 8.6, 1.5) * CFrame.Angles(0, math.pi, 0), C(58, 92, 168), M.Fabric))
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
-- o: sign, signColor, textColor, wall, trim, stripes, floors, extra ('crates' | 'pole'), depth, stripe, awningDepth, noUnit,
-- fascia, bays
local function shopBuilding(ctx, w, o)
	local trim = o.trim or o.signColor
	local c = brickBuilding(ctx, w, { name = 'Shop_' .. o.sign:gsub('%W', ''), floors = o.floors or 2, wall = o.wall or P.brick, bays = o.bays, depth = o.depth, noUnit = o.noUnit, ground = function(c2)
		c2:box('ShopBase', V(1, 0, 0), V(w - 1, 1.2, 0.4), trim, M.SmoothPlastic)
		c2:box('ShopGlass', V(2, 1.2, 0), V(w - 8, 7.4, 0.3), P.glass, M.SmoothPlastic).Reflectance = 0.15
		for x = 2 + (w - 10) / 3, w - 8.5, (w - 10) / 3 do decor(c2:box('ShopMullion', V(x - 0.2, 1.2, 0), V(x + 0.2, 7.4, 0.4), trim, M.SmoothPlastic)) end
		c2:box('ShopDoorFrame', V(w - 7, 0, 0), V(w - 2.6, 8, 0.3), trim, M.SmoothPlastic)
		c2:box('ShopDoor', V(w - 6.4, 0, 0), V(w - 3.2, 7.4, 0.5), P.glass, M.SmoothPlastic)
		c2:box('ShopBand', V(0, 8, 0), V(w, 9.6, 0.4), trim, M.SmoothPlastic)
	end })
	stripedAwning(c, 1.5, w - 1.5, 9.4, o.stripes, o.awningDepth, o.stripe)
	local sw = math.min(w / 2 - 1.5, 2.5 + #o.sign * 0.85)
	local sign
	if o.fascia then sign = Street.fascia(c, w, o.signColor)
	else
		sign = c:box('ShopSign', V(w / 2 - sw, 10.2, 0), V(w / 2 + sw, 13.6, 0.8), o.signColor, M.SmoothPlastic)
		decor(c:box('ShopSignBorder', V(w / 2 - sw - 0.4, 9.8, 0), V(w / 2 + sw + 0.4, 14.0, 0.7), P.cream, M.SmoothPlastic))
		decor(c:box('ShopSignCap', V(w / 2 - sw - 0.7, 14.0, 0), V(w / 2 + sw + 0.7, 14.4, 0.9), Craft.dark(o.signColor), M.SmoothPlastic))
	end
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

-- Street pieces (Brief 9). Facade-local like the buildings above: +X along the facade, +Z out to the street.
-- A brownstone stoop: the ground floor sits 2.4 up, reached by three chunky steps between sloped cheek walls, the
-- door on the landing. 10 parts. x: the door's centre along the facade.
function Street.stoop(c, x, door)
	local H, stone, cheek = 2.4, P.stone, P.stone:Lerp(P.black, 0.18)
	c:box('StoopLanding', V(x - 2.4, 0, 0), V(x + 2.4, H, 2.2), stone, M.Concrete)
	for k = 1, 3 do c:box('StoopStep', V(x - 1.85, 0, 1.2 + k), V(x + 1.85, H - k * 0.6, 2.2 + k), stone, M.Concrete) end
	for _, sx in { -1, 1 } do
		local cx = x + sx * 2.15
		c:box('StoopCheek', V(cx - 0.3, 0, 0), V(cx + 0.3, H + 0.9, 2.2), cheek, M.Concrete)
		-- (a wedge is tallest at its +Z end; turned round, the cheek falls from the landing to the pavement)
		c:wedge('StoopCheek', V(0.6, H + 0.9, 3), CFrame.new(cx, (H + 0.9) / 2, 3.7) * CFrame.Angles(0, math.pi, 0), cheek, M.Concrete)
	end
	decor(c:box('DoorFrame', V(x - 1.9, H, 0), V(x + 1.9, H + 7.6, 0.22), P.frame, M.SmoothPlastic))
	c:box('Door', V(x - 1.4, H, 0), V(x + 1.4, H + 7.0, 0.45), door or P.door, M.SmoothPlastic)
end
-- A walk-up on The Block: brick, a raised ground floor with its stoop in bay `doorBay`, framed windows.
-- o: floors, wall, bays, doorBay, door, depth, noUnit
function Street.walkup(ctx, w, o)
	return brickBuilding(ctx, w, { name = 'WalkUp', floors = o.floors, wall = o.wall, bays = o.bays, depth = o.depth, noUnit = o.noUnit, ground = function(c, _, list)
		local doorX = list[o.doorBay or 1]
		for _, x in list do if math.abs(x - doorX) > 3 then window(c, x, 4.2, {}) end end
		Street.stoop(c, doorX, o.door)
	end })
end
-- The corner store at the end of The Block, its landmark: low (two storeys) and light among the brick walk-ups, a
-- dark green shop band with glass that turns the corner, the door at the corner end, one green awning wrapped round
-- both faces. No sign board: the shape says shop. The corner is at local x = w.
function Street.cornerStore(ctx, w, o)
	o = o or {}
	local c, model = ctx:group('CornerStore')
	local depth, roof = o.depth or DEPTH, roofOf(2)
	local band, awn = C(48, 92, 70), C(60, 132, 90)
	c:box('Wall', V(0, -1, -depth), V(w, roof, 0), o.wall or C(232, 222, 202), M.Brick)
	c:box('ShopBand', V(0.3, -1, -12), V(w + 0.35, 9.4, 0.35), band, M.SmoothPlastic) -- (one block: front and 12 of the side)
	decor(c:box('ShopGlass', V(1.4, 1.2, 0.3), V(w - 5.4, 7.6, 0.5), P.glass, M.SmoothPlastic)).Reflectance = 0.15
	decor(c:box('ShopMullion', V((w - 4) / 2 - 0.2, 1.2, 0.3), V((w - 4) / 2 + 0.2, 7.6, 0.6), band:Lerp(P.black, 0.3), M.SmoothPlastic))
	c:box('ShopDoor', V(w - 4.4, 0, 0.3), V(w - 1.2, 7.8, 0.55), P.glass, M.SmoothPlastic)
	decor(c:box('SideGlass', V(w + 0.3, 1.2, -10.5), V(w + 0.5, 7.6, -1.6), P.glass, M.SmoothPlastic)).Reflectance = 0.15
	-- The awning: a sloped canopy on each face (wedges turned so they're tallest at the wall), a darker valance.
	local L = w + 3.6
	c:wedge('Awning', V(L - 0.4, 1.6, 3.6), CFrame.new(L / 2 + 0.2, 10.2, 2.15) * CFrame.Angles(0, math.pi, 0), awn, M.Fabric)
	decor(c:box('AwningValance', V(0.4, 8.7, 3.6), V(L, 9.4, 3.95), Craft.dark(awn), M.Fabric))
	c:wedge('Awning', V(12, 1.6, 3.6), CFrame.new(w + 2.15, 10.2, -6) * CFrame.Angles(0, -math.pi / 2, 0), awn, M.Fabric)
	decor(c:box('AwningValance', V(w + 3.6, 8.7, -12), V(w + 3.95, 9.4, 3.95), Craft.dark(awn), M.Fabric))
	for _, x in bays(w, 2) do window(c, x, storeyY(2) + 3, {}) end
	window(c:at(CFrame.new(w, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)), 6.5, storeyY(2) + 3, {})
	roofCap(c, w, roof, C(110, 104, 96), depth, true)
	model:SetAttribute('Floors', 2)
	return c, model
end
-- The back of the shops behind Shop Street's delivery bay: a plain service wall with a roll-up loading door over a
-- concrete dock, a rubber bumper each side of it.
function Street.loadingDock(ctx, w, o)
	local c = ctx:group('LoadingDock')
	local h, depth, wall = o.height or 15, o.depth or 14, o.wall or C(176, 172, 166)
	c:box('Wall', V(0, -1, -depth), V(w, h, 0), wall, M.Concrete)
	c:box('Parapet', V(-0.2, h, -depth), V(w + 0.2, h + 0.8, 0.4), wall:Lerp(P.black, 0.2), M.Concrete)
	local dx = w / 2
	c:box('Dock', V(dx - 5, 0, 0), V(dx + 5, 1.2, 2.4), C(150, 152, 158), M.Concrete)
	c:box('DoorFrame', V(dx - 4.4, 1.2, 0), V(dx + 4.4, 10.4, 0.3), P.warehouseDark, M.Metal)
	c:box('RollDoor', V(dx - 3.8, 1.2, 0), V(dx + 3.8, 9.8, 0.45), P.rollDoor, M.Metal)
	for y = 2.4, 9, 1.6 do decor(c:box('DoorSlat', V(dx - 3.8, y, 0.45), V(dx + 3.8, y + 0.16, 0.55), P.rollDoor:Lerp(P.black, 0.35), M.Metal)) end
	for _, sx in { -1, 1 } do c:box('DockBumper', V(dx + sx * 4.6 - 0.4, 0.3, 2.4), V(dx + sx * 4.6 + 0.4, 1.5, 2.8), P.black, M.SmoothPlastic) end
	return c
end
-- A rooftop water tank on legs: The Block's mark on the skyline. Stands on (x, y, z) in the context's frame.
function Street.waterTower(c, x, y, z)
	local wood, steel = C(156, 112, 78), C(70, 70, 76)
	local t = c:group('WaterTower')
	for _, dx in { -1.9, 1.9 } do
		for _, dz in { -1.9, 1.9 } do t:box('TowerLeg', V(x + dx - 0.3, y, z + dz - 0.3), V(x + dx + 0.3, y + 4.4, z + dz + 0.3), steel, M.Metal) end
	end
	t:box('TowerDeck', V(x - 3, y + 4.4, z - 3), V(x + 3, y + 4.9, z + 3), steel, M.Metal)
	t:post('Tank', 2.9, 6.4, V(x, y + 4.9, z), wood, M.WoodPlanks)
	for _, hh in { 1.2, 4.7 } do t:post('TankHoop', 3.0, 0.4, V(x, y + 4.9 + hh, z), steel, M.Metal) end
	t:post('TankRoof', 3.2, 0.6, V(x, y + 11.3, z), steel, M.SmoothPlastic)
	t:post('TankRoof', 2.2, 0.7, V(x, y + 11.9, z), steel, M.SmoothPlastic)
	t:post('TankRoof', 1.1, 0.7, V(x, y + 12.6, z), steel, M.SmoothPlastic)
	return t
end
---------------------------------------------------------------------------------------------- lobby hall
-- World 1's spawn: the BLOCK RANGE hall, a bright grey warehouse hall (studded walls between slate pillars with
-- white strips, big windows, box trusses with rows of fluorescent bars, a studded grey floor). Brief 9: every place
-- in it reads by its shape and where it stands, with at most one sign each.
--   Spawn: a low pad on the hall's spine just inside the exit, facing west down a red runner to BAY 1's front steps
--     (the free lane, the first thing to do); the exit to Stage 1 is the big door at the spine's north end.
--   West wall: the 8 shooting ranges as one stepped red terrace, Starter lowest by the exit, Gold highest at the back.
--   North wall: the stage door in the middle, the fast-travel pad west of it, the locked WORLD 2 arch east of it, a
--     roller loading door in each corner (deliveries on pallets inside the west one; the corner store's back yard,
--     bins and a soda delivery by the east one).
--   East: the corner store (a small shop box with its side door and bins), the ARMORY (builder D) further south.
--   By the spawn: the three rewards (a chest, a prize wheel, a safe) on one low stand.
--   South wall: the sneaker shop (cubby wall of shoe boxes, try-on benches, a counter); the street-ball court with a
--     bench beside it and the gold KINGPIN statue in the south-west; the two leaderboards behind a 1-2-3 podium in
--     the south-east.
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
Lobby.CrossZ = SPAWN.Z -- the spawn's row: the runner to BAY 1 runs west along it
Lobby.Door, Lobby.DoorH = 12, 20 -- north door half width and height
Lobby.Bay = 15 -- pillar spacing along the side walls, from z = 6
Lobby.Slots = {}
-- Brief 8: the shell is clean neutral grey (floor, walkway, walls, pillars, trusses, ceiling; S <= 0.08); the colour
-- comes from what stands in the hall. Big coloured surfaces stay at mid-tones (the terrace a brick red, the runner),
-- objects <= 0.7.
Lobby.Colors = {
	floor = C(196, 198, 204), walk = C(224, 226, 230), panel = C(166, 168, 176), panelRim = C(152, 154, 162), kerb = C(234, 235, 238), cyan = C(60, 232, 255),
	wall = C(205, 207, 212), wallLow = C(166, 168, 175), pillar = C(106, 108, 114), pillarDark = C(88, 90, 96),
	neon = C(236, 246, 255), frame = C(240, 241, 244), winFrame = C(80, 82, 88), winGlass = C(160, 214, 248), truss = C(96, 98, 104),
	lamp = C(92, 94, 100), ceiling = C(156, 158, 164), lampPlate = C(250, 252, 255),
	step = C(190, 192, 198), stepDark = C(162, 164, 170), carpet = C(166, 90, 84), carpetDark = C(124, 66, 62), carpetLip = C(236, 214, 210), dais = C(208, 210, 216),
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
Lobby.SideStair = 4 -- the lane whose side stair comes down to the floor in mid-terrace
Lobby.Bay1Steps = 3 -- how far BAY 1's front steps reach out from the promenade (onto the red runner)
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
-- The floor: one studded grey, a lighter spine (x -SpineW..SpineW) from the stage door to the sneaker shop, and the
-- red runner (z CrossZ ± RunnerW) from the spawn pad west to BAY 1's front steps. No kerbed panels.
Lobby.SpineW, Lobby.RunnerW = 7, 4.5
-- The lobby's fast-travel pad (FurthestPad): the other way out, west of the stage door, its front to the spine.
Lobby.FurthestAt = CFrame.lookAt(V(-23, 0, 15), V(0, 0, 15))


---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top.
function Lobby.slab(c, name, a, b, color)
	return studs(c:box(name, a, b, color, M.Plastic))
end
-- An invisible box (a light's holder).
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
-- A closed roll-up loading door in the north wall at x: grey steel jambs on dark plinths, grey slats (painted as
-- stripes), a dark bottom rail, a drum housing over it. (No beacon: deliveries in front of it say what it is.)
function Lobby.loadingDoor(c, x)
	local K, N = Lobby.Colors, Lobby.N
	local d = c:group('LoadingDoor')
	local w, ht = 7, 12
	for _, sx in { -1, 1 } do
		local a, b = x + sx * w, x + sx * (w + 1.2)
		local lo, hi = math.min(a, b), math.max(a, b)
		d:box('LoadDoorPost', V(lo, 0, N), V(hi, ht + 1.4, N + 0.9), K.pillar, M.SmoothPlastic)
		d:box('LoadDoorPostFoot', V(lo - 0.2, 0, N), V(hi + 0.2, 1.4, N + 1.2), K.pillarDark, M.SmoothPlastic)
	end
	d:box('LoadDoorDrum', V(x - w - 1.4, ht, N), V(x + w + 1.4, ht + 2, N + 1.5), K.cap, M.SmoothPlastic)
	d:box('LoadDoorDrumLip', V(x - w - 1.5, ht - 0.25, N), V(x + w + 1.5, ht, N + 1.65), K.pillar, M.SmoothPlastic)
	local panel = d:box('LoadDoorPanel', V(x - w, 0.6, N), V(x + w, ht, N + 0.5), K.doorSteel, M.SmoothPlastic)
	Lobby.stripes(panel, Enum.NormalId.Back, 2 * w, ht - 0.6, 0.76, 0.18, false, 0.6) -- (no stencil: a plain roller door)
	d:box('LoadDoorRail', V(x - w, 0, N), V(x + w, 0.6, N + 0.7), K.pillarDark, M.SmoothPlastic)
	return d
end
-- A hall sign: one pale studded board with the area's name in deep slate on a darker grey back plate. One per
-- area, no medallions or frames on frames; the hall's lamps light it.
function Lobby.wallSign(c, name, pos, normal, w, ht, title)
	local K = Lobby.Colors
	local cf = CFrame.lookAt(pos, pos + normal)
	c:part(name .. 'Back', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, 0.4), K.pillarDark, M.SmoothPlastic)
	studs(Lobby.board(c, name, cf, w, ht, C(226, 228, 234), { { 'Title', title, C(52, 60, 86), FONT.loud, 0.1, 0.8, P.white, 5 } }, 12))
end
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	-- The floor slab (the spine and the runner are laid over it in Lobby.floorPlan).
	Lobby.slab(h, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.floor)
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
	for _, x in Lobby.LoadDoors do Lobby.loadingDoor(h, x) end
	-- The stage door, the hall's way out to Stage 1: two red pillars and a red header round the 24 x 20 opening, the
	-- monitor in the bay over the header (a dark bezel round a blue screen: STAGE 1 and gate 1's state, which
	-- HoodClient/Stages rewrites), a light cap tying the pillar tops. One hue in two tones; gate 1 fills the opening.
	local d = h:group('ExitDoor')
	do
		local red = C(186, 78, 70)
		local dark, trim = red:Lerp(P.black, 0.38), C(238, 236, 232)
		local x1, top = Dw + 3.2, 31
		for _, sx in { -1, 1 } do
			d:box('DoorPillar', V(math.min(sx * Dw, sx * x1), 0, N), V(math.max(sx * Dw, sx * x1), top, N + 2.6), red, M.SmoothPlastic)
		end
		d:box('DoorHeader', V(-Dw, DH, N), V(Dw, DH + 2.6, N + 2.6), red, M.SmoothPlastic)
		d:box('MonitorBezel', V(-Dw, DH + 2.6, N + 0.4), V(Dw, top, N + 1.8), dark, M.SmoothPlastic)
		local screen = d:box('ExitMonitor', V(-Dw + 0.8, DH + 3.3, N + 1.8), V(Dw - 0.8, top - 0.7, N + 2.0), C(54, 100, 190), M.SmoothPlastic)
		local sg = surface(screen, Enum.NormalId.Back, 16)
		line(sg, 'Title', 'STAGE 1  •  THE BLOCK', P.white, FONT.loud, 0.1, 0.36, C(14, 26, 70), 3)
		-- (HoodClient/Stages rewrites ExitStatus from gate 1's state: train first / you can go / cleared)
		line(sg, 'ExitStatus', '🎯 TRAIN AT THE RANGE FIRST', C(255, 214, 90), FONT.loud, 0.56, 0.28, C(40, 24, 0), 3)
		d:box('DoorCap', V(-x1 - 0.3, top, N), V(x1 + 0.3, top + 0.8, N + 3), trim, M.SmoothPlastic)
	end
	-- The two big areas' names on the steel band (one sign each; the sneaker shop and the corner store carry
	-- their own fascia boards).
	local signs = h:group('WallSigns')
	Lobby.wallSign(signs, 'RangeSign', V(-W + 2.4, 31.8, 70), V(1, 0, 0), 24, 4.4, 'SHOOTING RANGE')
	Lobby.wallSign(signs, 'ArmorySign', V(W - 2.4, 31.8, Lobby.ArmoryZ), V(-1, 0, 0), 15, 4.4, 'ARMORY')

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
	return h
end
-- The overhead crane at z 96, in the structure greys (it is building, not an object): a box-girder bridge hung
-- from the long trusses (its runways) on two end trucks, darker flanges, a trolley parked over the east side.
-- Nothing hangs over the floor.
function Lobby.crane(r)
	local K, H = Lobby.Colors, Lobby.H
	local z, y = 96, 33
	r:box('RoofCraneBridge', V(-40, y - 1, z - 1.2), V(40, y + 1, z + 1.2), K.pillar, M.SmoothPlastic)
	for _, fy in { y - 1.3, y + 1 } do r:box('RoofCraneFlange', V(-40, fy, z - 1.5), V(40, fy + 0.3, z + 1.5), K.pillarDark, M.SmoothPlastic) end
	for _, x in { -40, 40 } do r:box('RoofCraneTruck', V(x - 1.6, y - 1.4, z - 2.2), V(x + 1.6, H - 2.2, z + 2.2), K.truss, M.SmoothPlastic) end
	local tx = 22
	r:box('RoofCraneTrolley', V(tx - 1.6, y - 2.2, z - 1.8), V(tx + 1.6, y - 1, z + 1.8), K.pillarDark, M.SmoothPlastic)
end

---------------------------------------------------------------------------------------------- floor
-- The floor: one studded grey slab; a lighter studded spine 0.12 over it from the stage door south to the sneaker
-- shop's wood floor; and the red runner, a smooth rubber mat a touch higher, from the spawn pad west to the foot of
-- BAY 1's front steps: the first walk, read by its colour (the terrace's red) and its straight line, not by arrows.
-- Nothing else is painted on the floor.
Lobby.ShopZ = 138 -- the sneaker shop's wood floor starts here (the spine stops at it)
function Lobby.floorPlan(L)
	local K, N = Lobby.Colors, Lobby.N
	local f = L:group('FloorPlan')
	local sw, rw, z = Lobby.SpineW, Lobby.RunnerW, Lobby.CrossZ
	Lobby.slab(f, 'Walkway', V(-sw, 0, N), V(sw, 0.12, Lobby.ShopZ), K.walk).CastShadow = false
	local x0 = Lobby.TerraceX + Lobby.Bay1Steps
	f:box('Runner', V(x0, 0, z - rw), V(-sw + 2, 0.16, z + rw), C(176, 104, 98), M.SmoothPlastic).CastShadow = false
	return f
end

---------------------------------------------------------------------------------------------- ranges
-- The ranges stand on one stepped red terrace along the west wall (the reference's capsule terrace): each lane's
-- studded base runs from the wall to the promenade's straight front edge (x -37), 1.2 higher than the lane
-- before; along the promenade each tier starts with a half step. A white (non-glowing) lip on every edge, a
-- darker red skirting along its foot. Light grey stairs: two treads up to Starter at the north end, BAY 1's front
-- steps at the end of the red runner, a side stair from the Heavy lane down to the floor, and a grand stair off
-- Gold's south end toward the armory (the last two with red cheeks capped by a white rail).
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
	-- BAY 1's front steps: straight off the promenade onto the red runner, as wide as the runner, so the walk from the
	-- spawn ends on them.
	local z1, rw = Lobby.RangeZ0, Lobby.RunnerW
	Lobby.terraceStair(t, 'TerraceStair', XF, XF + Lobby.Bay1Steps, z1 - rw, z1 + rw, rise, 'x', 1)
	-- Side stair from the Heavy lane down to the floor (6 wide), red cheeks both sides.
	local si = Lobby.SideStair
	local sz, sh = Lobby.RangeZ0 + (si - 1) * Lobby.RangePitch, si * rise
	Lobby.terraceStair(t, 'TerraceStair', XF, XF + 4, sz - 3, sz + 3, sh, 'x', 1)
	for _, u in { sz - 3.4, sz + 3 } do Lobby.stairCheek(t, 'x', u, u + 0.4, XF, XF + 5, sh) end
	-- Grand stair off Gold's south end (x -43..-37), red cheeks both sides.
	Lobby.terraceStair(t, 'TerraceStair', XS + 0.4, XF - 0.4, zS, zS + 9, n * rise, 'z', 1)
	for _, u in { XS, XF - 0.4 } do Lobby.stairCheek(t, 'z', u, u + 0.4, zS, zS + 10, n * rise) end
	-- A darker red skirting along the terrace's foot (broken by the stairs): the terrace's base course.
	for _, seg in { { z1 + rw, sz - 3.4 }, { sz + 3.4, zS } } do
		t:box('TerraceSkirt', V(XF - 0.2, 0, seg[1]), V(XF + 0.25, 0.55, seg[2]), K.carpetDark, M.SmoothPlastic).CastShadow = false
	end
	Lobby.terraceDressing(t, skins, XS, XF, zN, zS, sz, n, rise)
end
-- The terrace's vertical rhythm: red glass stall dividers between the lanes (booth partitions, stepping up 1.2 a
-- tier), each on a steel front post, and white seams at the tier joints. The lanes carry their own small BAY plaques
-- (builder R, Stations.plaque) at their entrances; nothing else is written on the terrace.
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
		t:box('StallPost', V(postX - 0.6, base, fz - 0.3), V(postX, top + 0.35, fz + 0.3), K.steel, M.SmoothPlastic)
	end
	for i = 2, #Lobby.Ranges do
		local z0 = Lobby.RangeZ0 + (i - 1) * pitch - pitch / 2
		decor(t:box('TerraceSeam', V(XF - 0.05, 0, z0 + 0.85), V(XF + 0.06, i * rise - 0.3, z0 + 1.15), P.white, M.SmoothPlastic)).CastShadow = false
	end
end

---------------------------------------------------------------------------------------------- sneaker shop
-- The back wall's centre: the SHOE BOXES feature as a sneaker shop, read by its shape. A wood floor marks the shop
-- off the concrete; a cubby wall of stacked shoe boxes (a few sneakers on show, a gold box in the middle) fills the
-- back wall under the shop's one fascia board; a padded try-on bench and a pouf stand in the middle with an open
-- box and a pair of sneakers on the floor in front of them; the counter with a till by the east side. One ComingSoon
-- prompt ("Open Shoe Boxes") at the counter; no unboxing yet. Lobby.Slots.ShoeBoxes is the shop's front centre on the
-- floor, facing the hall; Lobby.SlotSizes.ShoeBoxes its size.
Lobby.SlotSizes = {}
Lobby.Shop = { X = 18, CubbyX = 15, Cols = 6, Rows = 4, CubbyH = 12.6 }
-- A cartoon high-top in a context (local: sole centre at the origin, toe toward -Z), k times a hand size: a white sole,
-- the toe cap, the vamp sloping up from it (a wedge), the upper, and the ankle collar standing up at the heel.
function Lobby.sneaker(c, cf, k, color, trim)
	local s = c:at(cf)
	local function S(name, lo, hi, col) s:box(name, lo * k, hi * k, col, M.SmoothPlastic) end
	S('SneakerSole', V(-0.5, 0, -1.2), V(0.5, 0.3, 1.2), P.white)
	S('SneakerToe', V(-0.45, 0.3, -1.2), V(0.45, 0.6, -0.6), trim or P.white)
	s:wedge('SneakerVamp', V(0.9, 0.5, 0.7) * k, CFrame.new(V(0, 0.85, -0.25) * k), color, M.SmoothPlastic)
	S('SneakerUpper', V(-0.45, 0.3, 0.1), V(0.45, 1.1, 1.2), color)
	S('SneakerCollar', V(-0.4, 1.1, 0.5), V(0.4, 1.55, 1.2), trim or P.white)
end
function Lobby.shoeShop(L)
	local K, S = Lobby.Colors, Lobby.S
	local sh = Lobby.Shop
	local X, z0 = sh.X, Lobby.ShopZ
	local d = L:group('SneakerShop')
	d:box('ShopFloor', V(-X, 0, z0), V(X, 0.14, S), C(178, 140, 104), M.WoodPlanks).CastShadow = false
	-- the cubby wall: a white unit on a dark plinth, 6 x 4 cubbies, each with two stacked boxes end-on (or a sneaker)
	local cx, top = sh.CubbyX, sh.CubbyH
	local zf, white = S - 3, C(240, 240, 242)
	d:box('CubbyBack', V(-cx, 0, S - 0.4), V(cx, top, S), C(226, 226, 230), M.SmoothPlastic)
	d:box('CubbyPlinth', V(-cx, 0, zf), V(cx, 0.8, S), K.pillarDark, M.SmoothPlastic)
	d:box('CubbyTop', V(-cx - 0.4, top, zf - 0.2), V(cx + 0.4, top + 0.6, S), white, M.SmoothPlastic)
	local inner = 2 * cx - 0.6
	local cw, ch = inner / sh.Cols, (top - 0.8) / sh.Rows
	for _, x in { -cx, cx - 0.3 } do d:box('CubbySide', V(x, 0.8, zf), V(x + 0.3, top, S), white, M.SmoothPlastic) end
	for k = 1, sh.Cols - 1 do
		local x = -cx + 0.3 + k * cw
		d:box('CubbyDivider', V(x - 0.12, 0.8, zf), V(x + 0.12, top, S), white, M.SmoothPlastic)
	end
	for r = 1, sh.Rows - 1 do d:box('CubbyShelf', V(-cx, 0.8 + r * ch - 0.12, zf), V(cx, 0.8 + r * ch + 0.12, S), white, M.SmoothPlastic) end
	-- box colours (classic shoe-box orange, white, black, red, blue, teal...), gold ones in the middle; the eye-level
	-- shelf (row 3) shows one sneaker per cubby, side on
	local cols = { C(232, 128, 48), C(236, 236, 240), C(52, 54, 62), C(206, 64, 60), C(64, 120, 210), C(70, 170, 160), C(150, 100, 210), C(240, 196, 70) }
	local kicks = { C(230, 50, 60), C(60, 140, 240), C(250, 200, 40), C(120, 200, 90), C(150, 90, 220), C(240, 240, 244) }
	for col = 1, sh.Cols do
		for row = 1, sh.Rows do
			local x = -cx + 0.3 + (col - 0.5) * cw
			local y = 0.8 + (row - 1) * ch + 0.12
			local key = col .. ',' .. row
			if row == 3 then
				Lobby.sneaker(d, CFrame.new(x, y, zf + 1.3) * CFrame.Angles(0, math.rad(col % 2 == 0 and 90 or -90), 0), 1.7, kicks[col], col == 6 and C(52, 54, 62) or P.white)
			elseif key ~= '4,1' then
				local gold = key == '3,2' or key == '4,2'
				local a = gold and cols[8] or cols[(col * 5 + row * 3) % 7 + 1]
				local b = gold and cols[8] or cols[(col * 3 + row * 7 + 2) % 7 + 1]
				local bw = cw - 0.9 - ((col + row) % 2) * 0.3
				d:box('ShoeBox', V(x - bw / 2, y, zf + 0.25), V(x + bw / 2, y + 1.2, S - 0.5), a, M.SmoothPlastic)
				d:box('ShoeBox', V(x - bw / 2 + 0.15, y + 1.2, zf + 0.35), V(x + bw / 2 - 0.15, y + 2.35, S - 0.5), b, M.SmoothPlastic)
			end
		end
	end
	-- the shop's one sign, over the cubby wall
	local scf = CFrame.lookAt(V(0, top + 2.6, S - 0.5), V(0, top + 2.6, 0))
	d:part('ShoeBoxSignBack', V(17.2, 3.6, 0.3), scf * CFrame.new(0, 0, 0.2), K.pillarDark, M.SmoothPlastic)
	Lobby.board(d, 'ShoeBoxSign', scf, 16, 2.8, C(236, 232, 226), { { 'Title', 'SHOE BOXES', C(196, 70, 96), FONT.loud, 0.1, 0.8, P.white, 3 } }, 16)
	-- the try-on seats: a long padded bench and a round pouf, an open box and a pair of sneakers on the floor
	local seat, base = C(70, 132, 150), C(76, 78, 86)
	d:box('TryOnBenchBase', V(-9.4, 0.14, 145.3), V(0.4, 1.0, 147.1), base, M.SmoothPlastic)
	d:box('TryOnBench', V(-9.8, 1.0, 145), V(0.8, 1.9, 147.4), seat, M.SmoothPlastic)
	Lobby.disc(d, 'TryOnPouf', 2.6, 0.14, 1.8, 4.2, 144.2, seat:Lerp(P.white, 0.2))
	d:box('OpenBox', V(-6.2, 0.14, 142.2), V(-3.6, 1.1, 143.8), C(232, 128, 48), M.SmoothPlastic)
	d:part('OpenBoxLid', V(2.8, 0.25, 1.8), CFrame.new(-7.6, 0.6, 142.9) * CFrame.Angles(0, 0, math.rad(70)), C(236, 236, 240), M.SmoothPlastic)
	for _, e in { { -2.2, 142.6, 12 }, { -1.0, 143.2, -6 } } do
		Lobby.sneaker(d, CFrame.new(e[1], 0.14, e[2]) * CFrame.Angles(0, math.rad(e[3]), 0), 1.1, C(230, 50, 60), P.white)
	end
	-- the counter and till on the east side, its front to the hall
	d:box('ShopCounter', V(11, 0.14, 140.6), V(16.6, 3.4, 145.4), C(58, 112, 128), M.SmoothPlastic)
	d:box('ShopCounterTop', V(10.7, 3.4, 140.3), V(16.9, 3.75, 145.7), white, M.SmoothPlastic)
	d:box('Till', V(13.2, 3.75, 142.2), V(15.2, 4.75, 143.8), C(52, 54, 62), M.SmoothPlastic)
	d:box('ShoppingBag', V(11.4, 3.75, 144.2), V(12.8, 5.3, 145.2), C(232, 128, 48), M.SmoothPlastic)
	local hit = ghost(d:box('ShoeBoxPrompt', V(10.5, 0.14, 139.6), V(17, 5, 146), P.white))
	Lobby.prompt(hit, 'Open', 'Shoe Boxes').MaxActivationDistance = 14
	Lobby.Slots.ShoeBoxes = CFrame.new(0, 0, z0)
	Lobby.SlotSizes.ShoeBoxes = V(2 * X, 16, S - z0)
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
-- The spawn: a low pad on the spine, level with BAY 1 (barely raised: a dark kerb, a white rim, a muted-blue top
-- with the game's red "+1" disc set in it), facing west down the red runner to BAY 1's front steps
-- (Lobby.SpawnYaw); g_build writes the yaw to LobbySpawnYaw so the LOBBY teleport faces the same way, and lands on
-- the pad's top (Lobby.SpawnTop).
Lobby.SpawnYaw = math.rad(90)
Lobby.SpawnTop = 0.3
Lobby.SpawnPad = 11 -- across the flats
function Lobby.badge(L)
	local D, cz, F = Lobby.Deck, Lobby.CrossZ, Lobby.SpawnPad
	local b = L:at(CFrame.new(0, D, cz)):group('SpawnBadge')
	Lobby.poly(b, 'SpawnKerb', 8, F, 0, 0.18, C(122, 124, 132))
	Lobby.poly(b, 'SpawnRim', 8, F - 0.8, 0.18, 0.26, C(232, 233, 237))
	Lobby.poly(b, 'SpawnTop', 8, F - 1.6, 0.18, 0.3, C(104, 130, 184))
	decor(Lobby.disc(b, 'BadgeDisc', 4, 0.3, 0.34, 0, 0, C(196, 74, 72))).CastShadow = false
	local face = ghost(b:part('BadgeText', V(3.4, 0.02, 3.4), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, Lobby.SpawnYaw, 0), P.white)) -- (upright from the spawn camera)
	face.CastShadow = false
	line(surface(face, Enum.NormalId.Top, 40), 'Text', '+1', P.white, FONT.loud, 0.12, 0.76, C(90, 10, 20), 4)
	-- The spawn point itself (StageService and SetActive use it).
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, Lobby.SpawnTop + 0.12, 0)) * CFrame.Angles(0, Lobby.SpawnYaw, 0) -- on the pad top
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = b.parent
	-- Back to where you got to, for returning players: the fast-travel pad west of the stage door (the hall's other
	-- way out), straight on the floor; its look is d_kit's teleportPad.
	teleportPad(L:at(Lobby.FurthestAt), 'FurthestPad', 0, 0, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
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
-- A hand truck (sack barrow) standing tipped back on its wheels, its nose plate on the floor (local: wheels' axle at
-- the origin, the nose toward -Z, the handles up and back toward +Z).
function Lobby.handTruck(c, cf)
	local t = c:at(cf):group('HandTruck')
	local frame, dark = C(206, 64, 60), C(44, 44, 50)
	local lean = CFrame.Angles(math.rad(-14), 0, 0) -- (tipped back onto its wheels)
	for _, x in { -0.9, 0.9 } do
		t:part('HandTruckRail', V(0.25, 4.6, 0.25), lean * CFrame.new(x, 2.4, 0.1), frame, M.SmoothPlastic)
		t:part('HandTruckWheel', V(0.4, 1.2, 1.2), CFrame.new(x * 1.25, 0.6, 0.35), dark, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	t:part('HandTruckNose', V(2.2, 0.15, 1.1), CFrame.new(0, 0.08, -0.45), frame:Lerp(P.black, 0.3), M.SmoothPlastic)
	t:part('HandTruckBar', V(2, 0.25, 0.25), lean * CFrame.new(0, 4.6, 0.1), frame, M.SmoothPlastic)
	return t
end
-- A wheelie bin (local: front toward -Z), lid shut.
function Lobby.wheelieBin(c, cf, color)
	local t = c:at(cf):group('WheelieBin')
	t:box('BinBody', V(-1.1, 0.3, -1.1), V(1.1, 3.4, 1.1), color, M.SmoothPlastic)
	t:box('BinLid', V(-1.25, 3.4, -1.25), V(1.25, 3.7, 1.3), color:Lerp(P.black, 0.3), M.SmoothPlastic)
	t:part('BinWheels', V(2.4, 0.6, 0.6), CFrame.new(0, 0.3, 0.9) * CFrame.Angles(0, 0, 0), C(44, 44, 50), M.SmoothPlastic)
	return t
end

---------------------------------------------------------------------------------------------- set pieces
-- A "coming soon" prompt (the HUD toasts "<object> is coming soon!").
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
-- The rewards, together on one low studded stand just east of the spawn (where you land is where you claim): the
-- DAILY CRATE (a red treasure chest with gold bands), the LUCKY SHOT prize wheel (four coloured spokes on a white
-- wheel in a gold rim, a pointer on top, turning slowly on an A-frame) and the VIP SAFE (a purple safe with a dial
-- and a handle). No signs, plinths or glow: their shapes say what they are. Decor with "coming soon" prompts.
Lobby.RewardStand = { 13, 21, 38, 62 } -- x0, x1, z0, z1 (fronts face west, to the spine; clear of WORLD 2's approach)
Lobby.RewardAt = {
	DailyCrate = CFrame.lookAt(V(17, 0.6, 42), V(0, 0.6, 42)),
	LuckyShot = CFrame.lookAt(V(17.4, 0.6, 50.5), V(0, 0.6, 50.5)),
	VipSafe = CFrame.lookAt(V(17, 0.6, 58), V(0, 0.6, 58)),
}
function Lobby.rewards(L)
	local st = Lobby.RewardStand
	local stand = L:group('RewardStand')
	Lobby.slab(stand, 'RewardStand', V(st[1], 0, st[3]), V(st[2], 0.6, st[4]), C(206, 196, 168))
	local goldTrim = C(226, 182, 72)
	-- DAILY CRATE
	local c = L:at(Lobby.RewardAt.DailyCrate):group('DailyCrate')
	local red = C(200, 84, 76)
	local lid = red:Lerp(P.white, 0.08)
	local body = c:box('CrateBody', V(-3.2, 0, -2.1), V(3.2, 3.2, 2.1), red, M.SmoothPlastic)
	c:box('CrateLid', V(-3.35, 3.2, -2.25), V(3.35, 4.1, 2.25), lid, M.SmoothPlastic)
	c:wedge('CrateLidSlope', V(6.7, 1.1, 2.25), CFrame.new(0, 4.65, -1.125), lid, M.SmoothPlastic)
	c:wedge('CrateLidSlope', V(6.7, 1.1, 2.25), CFrame.new(0, 4.65, 1.125) * CFrame.Angles(0, math.pi, 0), lid, M.SmoothPlastic)
	for _, x in { -2, 2 } do c:box('CrateBand', V(x - 0.35, -0.05, -2.3), V(x + 0.35, 4.2, 2.3), goldTrim, M.SmoothPlastic) end
	c:box('CrateLock', V(-0.65, 2.3, -2.6), V(0.65, 3.8, -2.15), goldTrim, M.SmoothPlastic)
	Lobby.prompt(body, 'Open', 'Daily Crate')
	-- LUCKY SHOT: a prize wheel on an A-frame
	local g = L:at(Lobby.RewardAt.LuckyShot):group('LuckyShot')
	local legC = C(76, 78, 86)
	for _, sx in { -1, 1 } do
		g:part('WheelLeg', V(0.6, 7.6, 0.8), CFrame.new(sx * 1.6, 3.6, 0.9) * CFrame.Angles(0, 0, sx * math.rad(12)), legC, M.SmoothPlastic)
	end
	local hubCf = CFrame.new(0, 6.6, 0)
	g:part('WheelAxle', V(1.6, 0.7, 0.7), hubCf * CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.pi / 2, 0), legC, M.SmoothPlastic, Enum.PartType.Cylinder)
	local wc, wheel = g:group('Wheel')
	wc:part('WheelRim', V(0.5, 8, 8), hubCf * CFrame.Angles(0, math.pi / 2, 0), goldTrim, M.SmoothPlastic, Enum.PartType.Cylinder)
	wc:part('WheelFace', V(0.6, 7, 7), hubCf * CFrame.Angles(0, math.pi / 2, 0), C(240, 240, 242), M.SmoothPlastic, Enum.PartType.Cylinder)
	for j, col in { C(214, 70, 66), C(66, 130, 214), C(240, 196, 70), C(84, 176, 104) } do
		wc:part('WheelSpoke', V(1.3, 3.3, 0.7), hubCf * CFrame.Angles(0, 0, (j - 1) * math.pi / 2) * CFrame.new(0, 1.85, -0.05), col, M.SmoothPlastic)
	end
	wc:part('WheelHub', V(0.8, 1.4, 1.4), hubCf * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.pi / 2, 0), goldTrim, M.SmoothPlastic, Enum.PartType.Cylinder)
	-- (the wheel turns in its own plane: the pivot's Y axis along the axle, Z)
	Lobby.motion(wheel, Lobby.RewardAt.LuckyShot * hubCf * CFrame.Angles(math.pi / 2, 0, 0), 30)
	g:part('WheelPointer', V(1.1, 1.1, 0.8), CFrame.new(0, 10.9, -0.5) * CFrame.Angles(0, 0, math.pi / 4), C(214, 70, 66), M.SmoothPlastic) -- (a diamond, tip down onto the rim)
	Lobby.prompt(ghost(g:box('WheelHit', V(-3.6, 0, -1.5), V(3.6, 10.6, 1.5), P.white)), 'Spin', 'Lucky Shot')
	-- VIP SAFE
	local v = L:at(Lobby.RewardAt.VipSafe):group('VipSafe')
	local purple = C(140, 100, 200)
	local safe = v:box('SafeBody', V(-2.7, 0, -2.3), V(2.7, 5.8, 2.3), purple, M.SmoothPlastic)
	v:box('SafeDoor', V(-2.1, 0.6, -2.5), V(2.1, 5.2, -2.3), purple:Lerp(P.white, 0.2), M.SmoothPlastic)
	v:part('SafeDial', V(0.4, 1.8, 1.8), CFrame.new(-0.5, 3.3, -2.6) * CFrame.Angles(0, math.pi / 2, 0), goldTrim, M.SmoothPlastic, Enum.PartType.Cylinder)
	v:box('SafeHandle', V(1.0, 1.9, -3.0), V(1.5, 4.5, -2.5), purple:Lerp(P.black, 0.4), M.SmoothPlastic)
	Lobby.prompt(safe, 'Open', 'VIP Safe')
end

-- The WORLD 2 portal, locked: a blue stone arch (two plain pillars, five arch stones) on one low step against the
-- north wall, a dim blue face inside, crossed by two chain bars with a gold padlock where they cross, and the WORLD 2
-- board on top (its one sign). While WORLD 2 is locked the stone holds its colour back; set open to true when it opens.
function Lobby.portal(L, cf)
	cf = cf * CFrame.new(1, 0, 0) -- (1 stud off the slot, toward the door: clear of the loading door's jamb)
	local p = L:at(cf):group('World2Portal')
	local open = false
	local signBlue = C(70, 120, 198)
	local blue = open and signBlue or signBlue:Lerp(C(150, 152, 160), 0.3)
	local dark, stone, grey = blue:Lerp(P.black, 0.38), blue:Lerp(P.white, 0.16), C(150, 152, 160)
	local face = C(108, 168, 222):Lerp(C(150, 152, 160), 0.25)
	local function B(name, a, b, color, mat) return p:box(name, a, b, color, mat or M.SmoothPlastic) end
	local along = CFrame.Angles(0, math.pi / 2, 0) -- (cylinders lie along X; this turns them to face the hall)
	B('PortalStep', V(-11.2, 0, -3.4), V(11.2, 0.6, 4.8), grey)
	local hub, R0, R1 = V(0, 17.2, 0), 6.8, 10.4
	for _, sx in { -1, 1 } do
		B('PortalPillar', V(math.min(sx * R0, sx * R1), 0.6, -1.8), V(math.max(sx * R0, sx * R1), 17.2, 1.8), blue)
	end
	for j = 0, 4 do
		local a = math.pi * (j + 0.5) / 5
		local rm = (R0 + R1) / 2
		p:part('PortalArch', V(5.6, R1 - R0, 3.6), CFrame.new(hub + V(math.cos(a) * rm, math.sin(a) * rm, 0)) * CFrame.Angles(0, 0, a - math.pi / 2),
			j % 2 == 0 and blue or stone, M.SmoothPlastic)
	end
	-- the face: a box plus a disc for the round top, dim while locked
	local glowFace = B('PortalGlow', V(-R0, 0.6, 0.2), V(R0, 17.2, 0.6), face, M.Neon)
	local disc = p:part('PortalGlow', V(0.4, 2 * R0, 2 * R0), CFrame.new(0, 17.2, 0.4) * along, face, M.Neon, Enum.PartType.Cylinder)
	for _, q in { glowFace, disc } do
		decor(q).CastShadow = false
		q.Transparency = 0.3
	end
	-- locked: two chain bars crossed over the face and a gold padlock where they cross
	local steel = C(150, 156, 170)
	for _, sx in { -1, 1 } do
		local a, b = V(sx * -5.6, 2.2, -1), V(sx * 5.6, 19.4, -1)
		decor(p:part('PortalChain', V(0.9, 0.9, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), steel, M.SmoothPlastic))
	end
	local gold = C(226, 182, 76)
	B('PortalLock', V(-1.6, 9.2, -2.3), V(1.6, 12.2, -1.1), gold)
	B('PortalLockShackle', V(-1.35, 12.2, -1.95), V(1.35, 13.9, -1.45), steel)
	-- the WORLD 2 board on top of the arch
	local top = 17.2 + R1 + 0.2
	local sign = B('World2Sign', V(-6.5, top, -0.6), V(6.5, top + 3.6, 0.6), signBlue)
	line(surface(sign, Enum.NormalId.Front, 16), 'Title', 'WORLD 2', P.white, FONT.loud, 0.1, 0.8, dark, 4)
	-- the prompt (HUD toasts "World 2 is coming soon!")
	local zone = B('World2Gate', V(-6, 0.6, -3.4), V(6, 0.8, -1), face)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	return p
end

-- People in the range are SkinArt figures (Art.posed: block R15 parts, each look carrying its own prop in its
-- left hand). Poses in SkinArt.Poses' shape: {out, forward, elbow bend, twist} per limb (forward = toward the
-- figure's front).
Lobby.Poses = {
	-- The kingpin: a gold pistol raised high (the near arm, tilted toward the walkway), the other hand on the hip.
	kingpin = { LeftArm = { 160, 25 }, RightArm = { 30, -10, 70, 80 }, LeftLeg = { 6, 0 }, RightLeg = { 6, 0 } },
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
-- plinth (red block, cream top) with a warm light. Two-tone gold (suit and a pale
-- shirt, tie and lapels) with a dark face so the eyes and shades read. Falls back to a block figure without
-- SkinArt.
function Lobby.statue(L, cf, skins)
	local K = Lobby.Colors
	local s, model = L:at(cf):group('KingpinStatue')
	-- Three golds (research: one hue, three tones): M for the body, D for the cape, ermine back, tie and shoes,
	-- L for the crown, cuffs, ermine trim, lapels, chain and shirt; the head a touch lighter than the body.
	local head, suit, pale, deep, ink = C(232, 190, 98), C(224, 178, 80), C(246, 216, 140), C(170, 124, 48), C(90, 50, 10)
	-- The plinth: a dark grey octagon base, a red block, a cream top. (No plaque: a giant gold figure on a plinth
	-- reads as the champion without one.)
	local red, cream = C(184, 96, 92), C(238, 234, 226)
	Lobby.poly(s, 'PlinthBase', 8, 15.4, 0, 0.8, C(118, 120, 128))
	s:box('Plinth', V(-6.2, 0.8, -6.2), V(6.2, 3.1, 6.2), red, M.SmoothPlastic)
	s:box('PlinthTop', V(-5.9, 3.1, -5.9), V(5.9, 3.6, 5.9), cream, M.SmoothPlastic)
	local top, scale = 3.6, 4.5
	local base = V2.Origin * s.cf * CFrame.new(0, top, 0)
	local kingpin = skins.ById.Kingpin or skins.List[#skins.List]
	local fig = Lobby.figure(model, base, kingpin, scale, Lobby.Poses.kingpin)
	if fig then
		fig.Name = 'KingpinFigure'
		-- No sceptre: the gold deagle goes in that hand.
		Lobby.stripProp(fig, kingpin)
		local paleParts = { DressShirt = true, TailoredLapel = true, ShirtCuff = true, ShadesGlint = true, EyeGlint = true, Shirt = true, Collar = true,
			CrownBand = true, CrownPoint = true, CrownTip = true, CrownGlow = true, CapeCrownBand = true, CapeCrownPoint = true, GoldCuff = true,
			Ermine = true, ErmineLapel = true, ErmineShoulder = true, ErmineTail = true, Lapel = true, LapelNotch = true, GoldChain = true,
			Medallion = true, Stud = true, Diamond = true, Gem = true }
		local deepParts = { Cape = true, CapeLining = true, ErmineBack = true, Shoe = true, ShoeToe = true, Sole = true, CrownVelvet = true,
			HairShell = true, Waistcoat = true, Tie = true, TieKnot = true, TieTip = true, JacketSkirt = true }
		-- Face features stay dark so the eyes, shades and smirk read (old and new SkinArt names).
		local face = { EyeWhite = true, Iris = true, Pupil = true, Eyebrow = true, Eyelid = true, Nose = true, Smile = true, SmileTeeth = true,
			Mouth = true, Moustache = true, Beard = true, SunglassesFrame = true, SunglassesLens = true, LensReflection = true, GlassesBridge = true, RoundSpectacleRim = true,
			Eye = true, Brow = true, MouthCorner = true, Teeth = true, ShadesLens = true, ShadesBar = true }
		for _, d in fig:GetDescendants() do
			if d:IsA('BasePart') then
				d.Material = M.SmoothPlastic
				d.Color = face[d.Name] and ink or paleParts[d.Name] and pale or deepParts[d.Name] and deep or d.Name:match('^Head') and head or suit
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
			Lobby.goldGun(gun, pale, deep)
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
	-- A warm light on it.
	light(Lobby.emitBox(s, 'StatueFx', V(-6, 6, -3), V(6, 28, 3)), C(255, 222, 160), 1.2, 24)
	return s
end

-- The leaderboards, together in the south-east as the hall of fame: two plain scoreboards (TOP CASH, TOP POWER)
-- either side of a winners' podium. A board: two dark posts, a navy screen under a header strip in its one hue
-- (its title), standing square. `live` names the model LobbyService writes into (a TextLabel named TextLabel):
-- ServerLeaderboard (top Power) or CashLeaderboard (top Cash).
function Lobby.leaderboard(L, cf, title, accent, live)
	local b, model = L:at(cf):group(live)
	local Dk = accent:Lerp(P.black, 0.35)
	local hw = 5.6
	-- (the screen starts above the podium and its trophy, so neither ever covers a row)
	for _, sx in { -1, 1 } do b:box('BoardPost', V(sx * hw - 0.6, 0, -0.6), V(sx * hw + 0.6, 17.4, 0.6), Dk, M.SmoothPlastic) end
	local screen = b:box('BoardScreen', V(-hw + 0.6, 7.8, -0.4), V(hw - 0.6, 17.4, 0.4), C(32, 42, 74), M.SmoothPlastic)
	local header = b:box('BoardHeader', V(-hw - 0.8, 17.4, -0.8), V(hw + 0.8, 20.2, 0.8), accent, M.SmoothPlastic)
	line(surface(header, Enum.NormalId.Front, 20), 'Title', title, P.white, FONT.loud, 0.12, 0.76, Dk:Lerp(P.black, 0.45), 3)
	local text = line(surface(screen, Enum.NormalId.Front, 20), 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, FONT.body, 0.05, 0.9, P.black, 1)
	text.TextYAlignment = Enum.TextYAlignment.Top
	return model
end
-- The winners' podium (local: front toward -Z): three studded blocks, 2-1-3, in silver, gold and bronze, and a gold
-- trophy on the top step.
function Lobby.podium(L, cf)
	local p = L:at(cf):group('Podium')
	for _, e in { { -5, 2.4, C(200, 204, 214) }, { 0, 3.6, C(226, 186, 84) }, { 5, 1.4, C(196, 136, 92) } } do
		Lobby.slab(p, 'PodiumStep', V(e[1] - 2.5, 0, -2.2), V(e[1] + 2.5, e[2], 2.2), e[3])
	end
	local gold = C(236, 192, 74)
	p:box('TrophyBase', V(-0.9, 3.6, -0.9), V(0.9, 4.2, 0.9), C(70, 56, 40), M.SmoothPlastic)
	Lobby.disc(p, 'TrophyStem', 0.6, 4.2, 5.2, 0, 0, gold)
	Lobby.disc(p, 'TrophyCup', 2.2, 5.2, 7.2, 0, 0, gold)
	for _, x in { -1.7, 1.0 } do p:box('TrophyHandle', V(x, 5.6, -0.2), V(x + 0.7, 6.9, 0.2), gold, M.SmoothPlastic) end
	return p
end

---------------------------------------------------------------------------------------------- hood life
-- The hood in the hall as small groups, each with a reason to be where it is, never on the walks: the street-ball
-- court in the south-west (a bench beside it, a boombox on a milk crate by the bench); deliveries on pallets and a
-- hand truck inside the west loading door; the corner store in the north-east with its back yard by the east
-- loading door (bins and bags beside its side door, a pallet of soda crates just in). Kid-friendly: no gang signs,
-- nothing aimed at anyone, only snacks and soda.
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

-- The street-ball court (south-west, between the KINGPIN statue and the spine): a hoop on the south wall over a
-- painted half court with its key, a ball by the hoop, BLOCK BALLERS on the brick under the hoop (the court's one
-- piece of writing), and on the court's east side a bench facing it with a boombox on a milk crate beside it.
function Lobby.courtCorner(c)
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
	local net = decor(g:part('Net', V(1.5, 2.0, 2.0), CFrame.new(rc - V(0, 0.85, 0)) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	net.Transparency, net.CastShadow = 0.35, false
	Lobby.ball(g, V(-37.6, 0.15 + 0.9, 150.6))
	-- the bench beside the court (facing it, across the east line) and the boombox on a milk crate at its end
	bench(g, V(x1 + 2.6, 0, 141.5), V(-1, 0, 0))
	local bb = g:at(CFrame.lookAt(V(x1 + 2.8, 0, 146.2), V(x0, 0, 146.2)))
	Lobby.milkCrate(bb, CFrame.new(0, 0, 0), C(40, 110, 220))
	local box, boom = bb:group('Boombox')
	box:box('BoomboxBody', V(-1.5, 1.7, -0.5), V(1.5, 3.3, 0.5), C(40, 42, 54), M.SmoothPlastic)
	box:box('BoomboxHandle', V(-1.1, 3.3, -0.1), V(1.1, 3.6, 0.1), K.steel, M.SmoothPlastic)
	for _, x in { -0.85, 0.85 } do
		box:part('BoomboxSpeaker', V(0.1, 1.1, 1.1), CFrame.new(x, 2.5, -0.55) * CFrame.Angles(0, math.pi / 2, 0), C(90, 96, 110), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	Lobby.motion(boom, bb.cf * CFrame.new(0, 2.5, 0), nil, 0.08, 0.5)
	Lobby.mural(g, 'MuralBallers', CFrame.lookAt(V(xc, 5.9, S - 0.45), V(xc, 5.9, 0)), 10.4, 4.8, {
		{ 'splash', 0.02, 0.1, 0.96, 0.78, T.purple, 0.35 },
		{ 'word', 'BLOCK BALLERS', 0.03, 0.12, 0.84, 0.66, T.orange, T.ink },
		{ 'drips', 0.1, 0.84, 0.8, 7, 0.14, T.orange },
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
-- Deliveries just inside the west loading door: a pallet of taped cardboard boxes, a pallet with two crates, and
-- the hand truck that brought them, parked by the door's east jamb.
function Lobby.deliveries(c)
	local N, x = Lobby.N, Lobby.LoadDoors[1]
	local g = c:group('Deliveries')
	local card, tape = C(196, 158, 112), C(226, 206, 170)
	local a = g:at(CFrame.new(x - 3.2, 0, N + 4.6) * CFrame.Angles(0, math.rad(6), 0))
	pallet(a, CFrame.new())
	for _, e in { { V(-1, 0.8, -0.7), V(2, 1.8, 1.8) }, { V(1.1, 0.8, -0.4), V(1.8, 1.6, 2.2) }, { V(-0.2, 2.6, -0.3), V(2.2, 1.4, 1.8) }, { V(0.2, 0.8, 1.1), V(3.4, 1.2, 1.2) } } do
		local p = a:box('Parcel', e[1] - V(e[2].X / 2, 0, e[2].Z / 2), e[1] + V(e[2].X / 2, e[2].Y, e[2].Z / 2), card, M.Cardboard)
		a:box('ParcelTape', e[1] + V(-0.2, e[2].Y, -e[2].Z / 2), e[1] + V(0.2, e[2].Y + 0.04, e[2].Z / 2), tape, M.SmoothPlastic).CastShadow = false
	end
	local b = g:at(CFrame.new(x + 2.6, 0, N + 5.4) * CFrame.Angles(0, math.rad(-9), 0))
	pallet(b, CFrame.new())
	crate(b, CFrame.new(-0.7, 0.8, 0.1) * CFrame.Angles(0, 0.1, 0), 2.4)
	crate(b, CFrame.new(1.1, 0.8, -0.3) * CFrame.Angles(0, -0.15, 0), 1.8)
	Lobby.handTruck(g, CFrame.new(x + 7.8, 0, N + 3.2) * CFrame.Angles(0, math.rad(200), 0))
	return g
end

-- The corner store in the north-east: a small teal shop box built against the east wall between two pillars, its
-- front to the hall (a warm shop window, a blue door, a striped awning and the CORNER STORE fascia, its one sign), an
-- ice-pop freezer out front. Its side door opens north into the back yard by the east loading door: two wheelie
-- bins and a pile of bin bags beside the side door, a pallet of soda crates just in from the loading door.
Lobby.Store = { X0 = 54.6, Z0 = 23.4, Z1 = 33.6, H = 14 }
function Lobby.cornerStore(c)
	local W, N = Lobby.W, Lobby.N
	local st = Lobby.Store
	local x0, z0, z1, ht = st.X0, st.Z0, st.Z1, st.H
	local g = c:group('CornerStore')
	local teal = C(86, 160, 152)
	g:box('StoreBody', V(x0, 0, z0), V(W, ht, z1), teal, M.SmoothPlastic)
	g:box('StoreRoof', V(x0 - 0.4, ht, z0 - 0.3), V(W, ht + 0.7, z1 + 0.3), P.white, M.SmoothPlastic)
	g:box('StoreKick', V(x0 - 0.3, 0, z0), V(x0, 1.4, z1), teal:Lerp(P.black, 0.3), M.SmoothPlastic)
	local win = g:box('StoreWindow', V(x0 - 0.2, 2, z0 + 0.8), V(x0, 8.6, z1 - 3.6), C(255, 232, 170), M.SmoothPlastic)
	g:box('StoreWindowSill', V(x0 - 0.7, 1.6, z0 + 0.6), V(x0, 2, z1 - 3.4), P.white, M.SmoothPlastic)
	g:box('StoreDoor', V(x0 - 0.2, 0, z1 - 2.9), V(x0, 8.6, z1 - 0.6), C(40, 90, 200), M.SmoothPlastic)
	local awning = g:part('StoreAwning', V(2.8, 0.2, z1 - z0), CFrame.new(x0 - 1.3, 9.6, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.rad(22)), C(226, 44, 52), M.SmoothPlastic)
	Lobby.stripes(awning, Enum.NormalId.Top, 2.8, z1 - z0, 1.2, 0.6, false, 0, P.white)
	local cf = CFrame.lookAt(V(x0 - 0.2, 12, (z0 + z1) / 2), V(0, 12, (z0 + z1) / 2))
	Lobby.board(g, 'StoreSign', cf, 8.6, 2.2, C(36, 40, 70), { { 'Text', 'CORNER STORE', C(255, 220, 90), FONT.loud, 0.12, 0.76, C(20, 20, 40), 2 } }, 24)
	light(win, C(255, 220, 160), 0.8, 14)
	-- the freezer out front, by the window
	local fz = z0 + 2.4
	g:box('FreezerBody', V(x0 - 3.4, 0, fz - 1.6), V(x0 - 1.0, 2.5, fz + 1.6), C(246, 248, 252), M.SmoothPlastic)
	g:box('FreezerBand', V(x0 - 3.45, 0.3, fz - 1.65), V(x0 - 0.95, 0.7, fz + 1.65), C(60, 200, 255), M.SmoothPlastic)
	local lid = g:box('FreezerLid', V(x0 - 3.3, 2.5, fz - 1.5), V(x0 - 1.1, 2.75, fz + 1.5), C(120, 230, 255), M.Glass)
	lid.Transparency = 0.25
	-- the back yard: the side door, bins and bags beside it, the soda delivery by the loading door
	local sx = x0 + 6.2
	g:box('StoreSideDoor', V(sx - 1.3, 0, z0 - 0.2), V(sx + 1.3, 8, z0), C(60, 74, 80), M.SmoothPlastic)
	g:box('StoreSideStep', V(sx - 1.8, 0, z0 - 1.2), V(sx + 1.8, 0.4, z0), C(150, 152, 160), M.SmoothPlastic)
	Lobby.wheelieBin(g, CFrame.new(sx - 4, 0, z0 - 1.9) * CFrame.Angles(0, math.rad(4), 0), C(56, 120, 84))
	Lobby.wheelieBin(g, CFrame.new(sx - 6.7, 0, z0 - 2.2) * CFrame.Angles(0, math.rad(-7), 0), C(60, 84, 140))
	trashBags(g, V(sx + 2.4, 0, z0 - 7))
	local sp = g:at(CFrame.new(Lobby.LoadDoors[2] - 3.4, 0, N + 4.4) * CFrame.Angles(0, math.rad(-5), 0))
	pallet(sp, CFrame.new())
	for k, e in { V(-1, 0.8, -1), V(1, 0.8, -1), V(-1, 0.8, 1), V(1, 0.8, 1), V(0, 2.4, 0) } do
		Lobby.milkCrate(sp, CFrame.new(e) * CFrame.Angles(0, (k % 2) * 0.12, 0), C(206, 58, 58))
	end
	return g
end

function Lobby.hood(L)
	local h = L:group('Hood')
	Lobby.courtCorner(h)
	Lobby.deliveries(h)
	Lobby.cornerStore(h)
	-- small props cast no shadows (crates, bins, the boombox...): no visible change, fewer casters
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
-- The street face: the BLOCK RANGE board over the door, and the hall's landmark from the street, a giant gold deagle
-- turning slowly on a red mast on the roof over the door (a giant bullseye if the gun models aren't there).
function Lobby.dressing(L)
	local K, N = Lobby.Colors, Lobby.N
	local dr = L:group('Dressing')
	local clubOut = Lobby.onWall(V(0, 31, N - 1.5), V(0, 0, -1))
	dr:part('ClubSignBack', V(31.2, 6.6, 0.4), clubOut * CFrame.new(0, 0, 0.35), K.pillarDark, M.SmoothPlastic)
	Lobby.board(dr, 'ClubSign', clubOut, 30, 5.4, C(66, 30, 52), { { 'Title', 'BLOCK RANGE', C(250, 170, 210), FONT.loud, 0.12, 0.76, C(90, 20, 50), 4 } }, 14)
	local ridge = Lobby.H + 0.3
	local mast = dr:group('RoofMast')
	mast:part('MastPlinth', V(1.2, 6, 6), CFrame.new(0, ridge + 0.6, N - 0.5) * CFrame.Angles(0, 0, math.pi / 2), K.red, M.SmoothPlastic, Enum.PartType.Cylinder)
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

---------------------------------------------------------------------------------------------- volume
-- Brief 8's volume rule as a last pass over the lobby's own groups (never the other builders' models: the ranges,
-- the armory, the exit door, the WORLD 2 portal, the fast-travel pad): in the shell groups (Lobby.Shell) a part
-- whose biggest face is 60 studs² or more keeps HSV saturation <= 0.45; any other solid part <= 0.7 (its value a
-- touch lower when cut). Neon, glass, hidden parts and small parts (biggest face under 4 studs²) keep their
-- colour: accents may stay bright.
Lobby.Mine = { 'Hall', 'Roof', 'FloorPlan', 'SpawnBadge', 'RangeTerrace', 'SneakerShop', 'RewardStand', 'DailyCrate', 'LuckyShot', 'VipSafe',
	'KingpinStatue', 'Leaderboards', 'Dressing', 'Hood' }
Lobby.NotMine = { ExitDoor = true, World2Portal = true }
Lobby.Shell = { Hall = true, Roof = true, FloorPlan = true } -- (the terrace is set by hand: a brick red at S 0.49)
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

---------------------------------------------------------------------------------------------- guide nodes
-- Waypoints for the new-player guide (Lobby.client): a GuideNodes folder of small invisible parts whose bottoms sit
-- on the walkable floor, each with Links (the nodes you can walk to from it in a straight line). The first walk is
-- the red runner: spawn pad, the foot of BAY 1's front steps, the promenade at their top; the exit trail ends just
-- inside the stage door (Goal = 'Exit'). Lobby.GuideNodes: { name, x, floor y, z }; Lobby.GuideLinks: walkable pairs.
Lobby.GuideNodes = {
	{ 'Spawn', 0, Lobby.SpawnTop, Lobby.CrossZ },
	{ 'Bay1Foot', Lobby.TerraceX + Lobby.Bay1Steps + 1, 0.16, Lobby.CrossZ },
	{ 'Bay1Top', Lobby.TerraceX - 1.5, Lobby.RangeRise, Lobby.CrossZ },
	{ 'Exit', 0, 0.12, Lobby.N + 3 },
}
Lobby.GuideLinks = { { 'Spawn', 'Bay1Foot' }, { 'Bay1Foot', 'Bay1Top' }, { 'Spawn', 'Exit' }, { 'Bay1Foot', 'Exit' } }
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
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.hall(L)
	Lobby.floorPlan(L)
	Lobby.badge(L)
	Lobby.rangeRow(L, skins)
	Lobby.shoeShop(L)
	Lobby.slots(L)
	Lobby.rewards(L)
	Lobby.Slots.World2Portal = CFrame.new(29, 0, 11) * CFrame.Angles(0, math.pi, 0)
	Lobby.portal(L, Lobby.Slots.World2Portal)
	Lobby.Slots.Statue = CFrame.lookAt(V(-54, 0, 144), V(-54, 0, 0)) -- the SW corner, facing north, square to the hall
	Lobby.statue(L, Lobby.Slots.Statue, skins)
	Lobby.Slots.Spawn = CFrame.new(SPAWN + V(0, Lobby.SpawnTop, 0)) * CFrame.Angles(0, Lobby.SpawnYaw, 0)
	Lobby.Slots.FurthestPad = Lobby.FurthestAt
	for name, cf in Lobby.RewardAt do Lobby.Slots[name] = cf end
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	-- the hall of fame in the south-east, in the nook between the sneaker shop and the armory's end wall: TOP CASH and
	-- TOP POWER side by side against the south wall, the winners' podium in front of them
	local boards = L:group('Leaderboards')
	for k, e in { { 28.4, 'TOP CASH', C(84, 172, 108), 'CashLeaderboard' }, { 41.2, 'TOP POWER', C(210, 92, 88), 'ServerLeaderboard' } } do
		local cf = CFrame.lookAt(V(e[1], 0, 150.6), V(e[1], 0, 0))
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[2], e[3], e[4])
	end
	Lobby.Slots.Podium = CFrame.lookAt(V(34.8, 0, 144.6), V(34.8, 0, 0))
	Lobby.podium(boards, Lobby.Slots.Podium)
	Lobby.dressing(L)
	Lobby.hood(L)
	Lobby.guideNodes(L)
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
	-- Paving: the stages, and the forecourt in front of the warehouse door. (zo: where the checker starts counting, so
	-- the stage-by-stage paving lines up as one pattern.) Stages with their own street plan (Street.custom, Brief 9)
	-- lay their own ground.
	local function pave(x0, x1, z0, z1, zo)
		zo = zo or z0
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - zo) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-FRONT, FRONT, 0, Lobby.N - 1)
	pave(-FRONT, FRONT, BOSS_END, BOSS_TOP)
	for i = 1, STAGES do
		if not Street.custom[i] then pave(-FRONT, FRONT, stageTop(i) - SLEN, stageTop(i), BOSS_END) end
	end
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
-- One plain checkpoint at the start of every stage and the boss yard, the same for all 16 (Brief 9: the street
-- itself carries each stage's identity, so the gate has no district colour, no tower, no name board, no number).
-- It stays low, under 7 studs. A steel railing on a concrete footing runs from kerb to kerb. In the middle, between
-- two short concrete posts, a sliding yard gate (a braced steel frame on a floor track) shuts the opening. While
-- you're short, a chain and padlock hold it shut. A small dark plaque hangs on it with the Power number and your
-- progress.
-- HoodClient/Stages slides the gate open behind the west railing once you have the Power (the chain and padlock
-- drop away, the plaque turns green). The field (Barrier) is what really stops you: it is solid for you while
-- you're short, and invisible until you walk up to a gate you can't pass yet. StageService records the clear and
-- pays the reward.
-- Beside every gate after the first, on the east pavement, stands a bus stop: two stops (d_kit's teleportPad: back
-- to spawn, on to your furthest stage) with a bench between them.
local LOOK_NAMES = { 'THE BLOCK', 'SHOP STREET', 'THE COURTS', 'THE APARTMENTS', 'THE YARDS', 'BOSS YARD' }
local BOSS_RED = C(214, 44, 44)
local function lookColor(i) return i > STAGES and BOSS_RED or P.district[lookOf(i)] end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end) -- (the client moves the gate whole)
	local concrete, post, cap = C(150, 152, 158), C(198, 200, 206), C(238, 236, 232)
	local steel, ink = C(72, 76, 86), C(30, 34, 44)
	local OW, PX = 7, 7.9 -- the opening's half width; the posts' centres
	local SLIDE = -16.2 -- how far the gate slides open (west, behind the railing)
	-- The two posts: a concrete plinth, the shaft, a cream cap.
	for _, s in { -1, 1 } do
		local x = s * PX
		g:box('GatePostBase', V(x - 1.15, 0, -1.15), V(x + 1.15, 0.8, 1.15), concrete)
		g:box('GatePost', V(x - 0.9, 0.8, -0.9), V(x + 0.9, 6.2, 0.9), post)
		g:box('GatePostCap', V(x - 1.1, 6.2, -1.1), V(x + 1.1, 6.7, 1.1), cap)
	end
	-- The railing from the posts to the kerbs: a footing, two rails, three steel posts per side at uneven spacing
	-- (on the west side none stands where the open gate's plaque parks, x -19.9..-12.5).
	for _, side in { { -1, { 21.0, 27.6, 34.1 } }, { 1, { 15.0, 23.6, 34.1 } } } do
		local s = side[1]
		local a0, a1 = math.min(s * (PX + 0.9), s * 34.4), math.max(s * (PX + 0.9), s * 34.4)
		g:box('GateFooting', V(a0, 0, -0.6), V(a1, 0.5, 0.6), concrete)
		g:box('GateRail', V(a0, 1.8, -0.15), V(a1, 2.1, 0.15), steel)
		g:box('GateRail', V(a0, 3.3, -0.2), V(a1, 3.7, 0.2), steel)
		for _, px in side[2] do g:box('GateRailPost', V(s * px - 0.25, 0.5, -0.25), V(s * px + 0.25, 3.7, 0.25), steel) end
	end
	-- The sliding gate, shut: a steel frame with a diagonal brace and two pickets, on the stage side of the posts.
	-- Everything in GateSlide moves with it (the client slides the model by the gate's SlideOffset).
	local sg = g:group('GateSlide')
	local ZB, ZF = -1.55, -1.05 -- its back face and its approach face
	local x0, x1 = -OW - 0.6, OW + 0.4
	sg:box('GateSlideFrame', V(x0, 0.35, ZB), V(x1, 0.85, ZF), steel)
	sg:box('GateSlideFrame', V(x0, 4.6, ZB), V(x1, 5.1, ZF), steel)
	for _, x in { x0, x1 - 0.6 } do sg:box('GateSlideFrame', V(x, 0.85, ZB), V(x + 0.6, 4.6, ZF), steel) end
	sg:bar('GateSlideBrace', V(x0 + 0.6, 0.85, ZB + 0.25), V(x1 - 0.6, 4.6, ZB + 0.25), 0.4, steel, M.SmoothPlastic)
	for _, x in { -5.1, 5.1 } do sg:box('GateSlidePicket', V(x - 0.2, 0.85, ZB + 0.08), V(x + 0.2, 4.6, ZF - 0.08), steel) end
	-- The plaque hung on the gate: a cream frame round a dark face; the Power number and, under it, your progress
	-- (the client sizes Fill and writes Count and Status).
	sg:box('GatePlaqueFrame', V(-3.65, 1.05, ZF), V(3.65, 4.65, ZF + 0.2), cap)
	local plaque = sg:box('GatePlaque', V(-3.4, 1.25, ZF + 0.2), V(3.4, 4.45, ZF + 0.3), C(48, 52, 62))
	local pg = surface(plaque, Enum.NormalId.Back, 40)
	pcall(function() pg.MaxDistance = i == 1 and 220 or 100 end) -- (gate 1 reads through the warehouse door)
	line(pg, 'Power', '💪 ' .. compact(req), P.white, FONT.loud, 0.07, 0.5, ink, 3)
	line(pg, 'Status', '', P.white, FONT.loud, 0.63, 0.26, ink, 2)
	local track = Instance.new('Frame')
	track.Name = 'Track'
	track.BorderSizePixel, track.BackgroundColor3, track.BackgroundTransparency, track.ZIndex = 0, P.white, 0.6, 1
	track.Position, track.Size = UDim2.fromScale(0.12, 0.64), UDim2.fromScale(0.76, 0.24)
	track.Parent = pg
	local fill = Instance.new('Frame')
	fill.Name = 'Fill'
	fill.BorderSizePixel, fill.BackgroundColor3, fill.ZIndex = 0, C(118, 216, 146), 2
	fill.Position, fill.Size = UDim2.fromScale(0.12, 0.64), UDim2.fromScale(0, 0.24)
	fill.Parent = pg
	local count = line(pg, 'Count', '0 / ' .. compact(req), P.white, FONT.loud, 0.655, 0.21, ink, 2)
	count.ZIndex = 3
	-- The floor track it runs on.
	decor(g:box('GateTrack', V(x0 + SLIDE - 0.1, 0, ZB - 0.05), V(x1 + 0.2, 0.12, ZF + 0.05), steel))
	-- The chain wrapped twice round the east post and the gate's end, and the padlock hooked over it (every part
	-- named Lock: shown only while you're short).
	local gold, chain, shackle = C(226, 182, 76), C(64, 68, 78), C(184, 188, 196)
	local lock = {
		g:box('Lock', V(PX - 1.0, 0.9, 1.0), V(PX + 1.0, 2.6, 1.65), gold),
		g:box('Lock', V(PX - 0.17, 1.35, 1.65), V(PX + 0.17, 2.0, 1.72), gold:Lerp(P.black, 0.55)),
		g:box('Lock', V(PX - 0.75, 3.25, 1.15), V(PX + 0.75, 3.5, 1.45), shackle),
	}
	for _, y in { 2.75, 3.6 } do table.insert(lock, g:box('Lock', V(OW - 0.55, y, ZB - 0.17), V(PX + 1.02, y + 0.4, 1.02), chain)) end
	for _, sx in { -1, 1 } do table.insert(lock, g:box('Lock', V(PX + sx * 0.6 - 0.15, 2.6, 1.15), V(PX + sx * 0.6 + 0.15, 3.25, 1.45), shackle)) end
	for _, p in lock do decor(p) end
	-- The field: invisible until you walk up while you're short (BaseTransparency is how it shows then).
	local barrier = g:box('Barrier', V(-34.4, 0, -0.25), V(34.4, 14, 0.25), C(176, 214, 246), M.SmoothPlastic)
	barrier.Transparency = 1
	barrier:SetAttribute('BaseTransparency', 0.7)
	barrier.CastShadow = false
	-- The bus stop on the east pavement, just past the cross street's kerb (z 4.5): back to spawn, on to your
	-- furthest stage, a bench between them with its back to the gate.
	if i > 1 then
		local back = CFrame.Angles(0, math.pi, 0) -- (a stop's front is its -Z; here players come from +Z)
		teleportPad(g:at(CFrame.new(12.4, 0, 7.8) * back), 'LobbyPad', 0, 0, P.padRed, 'Lobby', 'SPAWN')
		teleportPad(g:at(CFrame.new(21.4, 0, 7.8) * back), 'FurthestPad', 0, 0, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
		local wood = C(186, 134, 90)
		g:box('StopBench', V(15.0, 1.35, 4.9), V(18.8, 1.7, 6.3), wood)
		g:box('StopBench', V(15.0, 1.7, 4.85), V(18.8, 3.0, 5.15), wood)
		for _, x in { 15.3, 18.2 } do g:box('StopBenchLeg', V(x, 0, 5.0), V(x + 0.3, 1.35, 6.2), steel) end
	end
	-- Confetti the client fires when you walk through.
	local shell = ghost(g:box('PassShell', V(-OW, 5.4, -0.6), V(OW, 6.2, 0.6), P.white))
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
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, lookColor(i)), ColorSequenceKeypoint.new(0.5, C(255, 222, 40)), ColorSequenceKeypoint.new(1, P.white) })
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
	model:SetAttribute('Color', lookColor(i)) -- (the HUD's STAGE CLEARED banner and the confetti, not the gate)
	model:SetAttribute('Light', barrier.Color) -- the field's colour
	model:SetAttribute('SlideOffset', V(SLIDE, 0, 0)) -- (map frame)
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
	if Street.custom[i] then return Street.block(ctx, i) end
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
	{ sign = 'PIZZA', signColor = C(198, 70, 60), textColor = C(255, 230, 160), stripes = { C(208, 78, 66), P.white }, wall = P.brickPink },
	{ sign = 'SNEAKERS', signColor = C(44, 48, 58), textColor = P.white, stripes = { C(58, 62, 72), P.white }, wall = P.brick },
	{ sign = 'ICE CREAM', signColor = C(206, 116, 150), textColor = P.white, stripes = { C(226, 140, 176), P.white }, wall = C(240, 226, 206) },
	{ sign = 'ARCADE', signColor = C(118, 76, 188), textColor = C(255, 232, 170), stripes = { C(130, 86, 200), C(240, 228, 196) }, wall = P.brickDark },
	{ sign = 'BAKERY', signColor = C(150, 104, 70), textColor = P.white, stripes = { C(210, 140, 78), P.white }, wall = P.tan, extra = 'crates' },
	{ sign = 'PHONES', signColor = C(62, 112, 196), textColor = P.white, stripes = { C(66, 120, 206), P.white }, wall = P.brick },
}
local function shopStage(ctx, i)
	if Street.custom[i] then return Street.shops(ctx, i) end
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
	if Street.custom[i] then return Street.courts(ctx, i) end
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
			Street.hoop(d, CFrame.lookAt(V(s * (FRONT - 3), 0, zc), V(0, 0, zc)), key)
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
	-- (No fences across the walk any more: the gates' railings end each street; Brief 9.)
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
end

---------------------------------------------------------------------------------------------- three street plans
-- Brief 9: stages 1 (The Block), 4 (Shop Street) and 7 (The Courts) each get their own street plan, so the place
-- reads from its shape with every sign hidden (brief/research/readable_places.md). The gameplay stays: the gate on
-- the stage line (the cross street at each end keeps the gate's full width, and the bus stop by the next gate on the
-- east side stays clear), the fight pad at (0, padZ), a clear walk from gate to gate, and a sealed edge.
-- In the builders below, Z(z) is relative to the stage's gate line: 0 at this gate, -64 at the next.

-- Invisible walls round a stage whose plan opens past the old building line, so nobody walks round a gate: down
-- both long sides at |x| 66, and along both gate lines from |x| 35 outward (the gate's Barrier covers |x| <= 34.4).
function Street.seal(d, top)
	for _, s in { -1, 1 } do
		invisibleWall(d, V(s * 66, -1, top - SLEN), V(s * 67, 60, top))
		for _, z in { top, top - SLEN } do invisibleWall(d, V(s * 35, -1, z - 0.5), V(s * 67, 60, z + 0.5)) end
	end
end
-- The stage group and its fight pad. No district banner: the street itself says where you are. Grass fills in behind
-- the set-back buildings (just under any paving laid over it), so no hole shows from a high camera.
function Street.core(ctx, i)
	local d = ctx:group('Stage' .. i)
	local model = fightPad(d, i, V(0, 0, padZ(i)), TRIO_COLORS[trioOf(i)], lookOf(i))
	model:SetAttribute('Stage', i)
	local top = stageTop(i)
	for _, s in { -1, 1 } do d:box('Backfill', V(s * FRONT, -1.2, top - SLEN), V(s * (FRONT + DEPTH), -0.05, top), P.grass, M.Grass) end
	return d, top
end

-- Props with a job (each one belongs to something next to it).
-- A fire hydrant at the kerb.
function Street.hydrant(c, pos)
	local red = C(196, 72, 62)
	c:post('HydrantFoot', 0.6, 0.3, pos, Craft.dark(red), M.SmoothPlastic)
	c:post('Hydrant', 0.45, 1.7, pos + V(0, 0.3, 0), red, M.SmoothPlastic)
	c:post('HydrantCap', 0.55, 0.35, pos + V(0, 2.0, 0), Craft.dark(red), M.SmoothPlastic)
	c:box('HydrantNozzle', pos + V(-0.8, 1.1, -0.25), pos + V(0.8, 1.6, 0.25), red, M.SmoothPlastic)
end
-- A bike rack (an inverted U) with a bike locked to it, the bike along the rack's local X.
function Street.bikeRack(c, cf, color)
	local k = c:at(cf):group('BikeRack')
	for _, x in { -1.2, 1.2 } do k:box('RackLeg', V(x - 0.15, 0, -0.15), V(x + 0.15, 2.6, 0.15), P.iron, M.Metal) end
	k:box('RackTop', V(-1.35, 2.6, -0.15), V(1.35, 2.9, 0.15), P.iron, M.Metal)
	for _, x in { -1.6, 1.6 } do k:part('BikeWheel', V(0.25, 2.2, 2.2), CFrame.new(x, 1.1, 0.55) * CFrame.Angles(0, math.pi / 2, 0), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	k:bar('BikeFrame', V(-1.6, 1.1, 0.55), V(-0.3, 2.4, 0.55), 0.26, color, M.SmoothPlastic)
	k:bar('BikeFrame', V(-0.4, 2.3, 0.55), V(1.2, 2.5, 0.55), 0.26, color, M.SmoothPlastic)
	k:bar('BikeFrame', V(1.2, 2.6, 0.55), V(1.6, 1.1, 0.55), 0.22, color, M.SmoothPlastic)
	k:box('BikeSeat', V(-0.8, 2.5, 0.3), V(0.1, 2.75, 0.8), P.black, M.SmoothPlastic)
end
-- A street-name blade on a post: the district's one small sign. It reads from the street's approach (+Z).
function Street.nameSign(c, pos, text)
	local green = C(46, 112, 72)
	c:post('SignPole', 0.2, 10.4, pos, P.iron, M.Metal)
	local blade = c:box('StreetName', pos + V(-2.8, 9.0, -0.12), pos + V(2.8, 10.1, 0.12), green, M.SmoothPlastic)
	for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = surface(blade, f, 24)
		pcall(function() g.MaxDistance = 80 end)
		line(g, 'Name', text, P.white, FONT.title, 0.12, 0.76)
	end
end
-- A café table: a round top on a post and two stools; with `parasol` (a colour), a parasol through it.
function Street.cafeTable(c, pos, turn, stool, parasol)
	local k = c:at(CFrame.new(pos) * CFrame.Angles(0, turn, 0)):group('CafeTable')
	k:post('TablePost', 0.25, 2.5, V(0, 0, 0), P.iron, M.Metal)
	k:post('TableTop', 1.35, 0.2, V(0, 2.5, 0), P.cream, M.SmoothPlastic)
	for _, x in { -2, 2 } do k:post('Stool', 0.55, 1.6, V(x, 0, 0), stool, M.SmoothPlastic) end
	if parasol then
		k:post('ParasolPole', 0.15, 4.4, V(0, 2.7, 0), P.iron, M.Metal)
		k:post('Parasol', 2.9, 0.4, V(0, 7.1, 0), parasol, M.Fabric)
		k:post('Parasol', 1.6, 0.5, V(0, 7.5, 0), parasol, M.Fabric)
	end
end
-- A market stall: a plank counter, four posts and a sloped striped canopy (tallest at the back), produce trays on
-- the counter. The customers' side is toward local +Z.
function Street.stall(c, cf, w, dpt, stripes, fruit)
	local k = c:at(cf):group('MarketStall')
	local hw, hd = w / 2, dpt / 2
	k:box('StallCounter', V(-hw, 0, hd - 1.5), V(hw, 3.0, hd), P.wood, M.WoodPlanks)
	for _, x in { -hw, hw - 0.3 } do
		k:box('StallPost', V(x, 0, hd - 0.3), V(x + 0.3, 7.2, hd), P.woodDark, M.Wood)
		k:box('StallPost', V(x, 0, -hd), V(x + 0.3, 8.4, -hd + 0.3), P.woodDark, M.Wood)
	end
	local n, cw = #stripes, (w + 0.6) / #stripes
	for q = 0, n - 1 do
		k:wedge('StallCanopy', V(cw, 1.2, dpt + 1.2), CFrame.new(-hw - 0.3 + cw * (q + 0.5), 7.8, 0) * CFrame.Angles(0, math.pi, 0), stripes[q + 1], M.Fabric)
	end
	for q, col in fruit do
		local x = -hw + 0.4 + (q - 0.5) * (w - 0.8) / #fruit
		decor(k:box('Produce', V(x - 0.7, 3.0, hd - 1.3), V(x + 0.7, 3.5, hd - 0.2), col, M.SmoothPlastic))
	end
end
-- A small box van (front toward local -Z): a cab with a windscreen, a tall cargo box, four wheels with hubs.
function Street.boxTruck(c, cf, color)
	local k = c:at(cf):group('BoxTruck')
	for _, x in { -2.3, 2.3 } do
		for _, z in { -4.3, 3.7 } do
			k:part('Wheel', V(0.9, 2.2, 2.2), CFrame.new(x, 1.1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(k:part('Hubcap', V(0.95, 1.1, 1.1), CFrame.new(x, 1.1, z), P.frame, M.SmoothPlastic, Enum.PartType.Cylinder))
		end
	end
	k:box('TruckChassis', V(-2.4, 1.0, -6.4), V(2.4, 1.7, 6.3), P.iron, M.SmoothPlastic)
	k:box('TruckCab', V(-2.5, 1.7, -6.6), V(2.5, 5.8, -2.7), color, M.SmoothPlastic)
	decor(k:box('TruckScreen', V(-2.2, 3.9, -6.7), V(2.2, 5.4, -6.3), P.glass, M.SmoothPlastic))
	k:box('TruckBox', V(-2.7, 1.7, -2.5), V(2.7, 8.6, 6.5), P.cream, M.SmoothPlastic)
	k:box('TruckBoxBand', V(-2.75, 6.6, -2.4), V(2.75, 7.4, 6.4), color, M.SmoothPlastic)
	k:box('Bumper', V(-2.5, 0.8, -6.9), V(2.5, 1.5, -6.5), P.frame, M.SmoothPlastic)
	for _, x in { -1.9, 1.2 } do decor(k:box('Headlight', V(x, 2.4, -6.75), V(x + 0.7, 3.0, -6.6), C(255, 244, 214), M.SmoothPlastic)) end
end
-- A hand truck (sack barrow) leaning back on its wheels, two cartons on it; the nose toward local -Z.
function Street.handTruck(c, cf)
	local k = c:at(cf):group('HandTruck')
	for _, x in { -0.8, 0.8 } do k:part('Wheel', V(0.3, 1, 1), CFrame.new(x, 0.5, 0.3), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	k:box('HandTruckNose', V(-0.9, 0, -1.0), V(0.9, 0.15, 0.2), P.iron, M.Metal)
	local lean = CFrame.new(0, 0, 0.2) * CFrame.Angles(math.rad(14), 0, 0)
	k:part('HandTruckFrame', V(1.7, 4.4, 0.25), lean * CFrame.new(0, 2.2, 0), C(200, 64, 56), M.Metal)
	k:part('Carton', V(1.6, 1.3, 1.2), lean * CFrame.new(0, 0.85, -0.75), P.crate, M.SmoothPlastic)
	k:part('Carton', V(1.4, 1.1, 1.1), lean * CFrame.new(0.05, 2.05, -0.7) * CFrame.Angles(0, 0.2, 0), P.crate:Lerp(P.white, 0.2), M.SmoothPlastic)
end
-- A court floodlight mast: a concrete foot, a tall pole, a lamp head tipped down toward `aim`.
function Street.floodlight(c, pos, aim)
	local steel = C(84, 88, 98)
	c:box('MastFoot', pos + V(-0.9, 0, -0.9), pos + V(0.9, 0.8, 0.9), C(150, 152, 158), M.Concrete)
	c:post('Mast', 0.35, 17.6, pos + V(0, 0.8, 0), steel, M.Metal)
	local head = CFrame.lookAt(pos + V(0, 18.6, 0), aim)
	c:part('MastHead', V(3.8, 1.8, 0.9), head, steel, M.SmoothPlastic)
	decor(c:part('MastLamp', V(3.3, 1.3, 0.2), head * CFrame.new(0, 0, -0.5), C(250, 246, 232), M.SmoothPlastic))
end
-- Bleachers: three concrete tiers `len` long, the low front edge on cf's origin, facing its +Z and rising toward -Z,
-- a wooden seat on the front of each tier.
function Street.bleachers(c, cf, len)
	local b = c:at(cf):group('Bleachers')
	for k = 0, 2 do
		local y = 1.1 * (k + 1)
		b:box('Bleacher', V(-len / 2, 0, -6), V(len / 2, y, -2 * k), C(176, 178, 186), M.Concrete)
		b:box('BleacherSeat', V(-len / 2 + 0.3, y, -2 * k - 1.3), V(len / 2 - 0.3, y + 0.3, -2 * k), P.wood, M.WoodPlanks)
	end
end
-- A chunky low-poly basketball hoop: a padded pole on a foot, an arm, a framed backboard, a square rim over a
-- see-through net block. cf: the pole's foot, the board toward its -Z.
function Street.hoop(c, cf, key)
	local h = c:at(cf):group('Hoop')
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
	return h
end

-- The Block (stage 1): a narrow residential street. Brick walk-ups with stoops stand close on both sides at
-- different setbacks (fronts at x -23, -27 and +20, +17), an asphalt road with raised pavements between them, two
-- cars at the kerb, a dead-end alley with the bins by a side door, and the corner store at the far corner where the
-- street meets the next gate's cross street, a water tank on its roof marking the end of the street.
function Street.block(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	-- Asphalt the full width (the cross streets at both ends keep the gate's 72), raised pavements along the block
	-- with a kerb stone at the road edge.
	d:box('Road', V(-FRONT, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.asphalt, M.Asphalt)
	for _, pv in { { -27, -14, -14, -55 }, { 9, 21, 9, -52.6 } } do -- (the east one stops short of the next gate's bus stop)
		d:box('Pavement', V(pv[1], -1, Z(pv[4])), V(pv[2], 0.3, Z(-7)), P.tileA, M.SmoothPlastic)
		d:box('Kerb', V(pv[3] - 0.45, -1, Z(pv[4])), V(pv[3] + 0.45, 0.34, Z(-7)), P.kerb, M.Concrete)
	end
	-- West: two walk-ups, then the corner store with the water tank. East: a walk-up, the alley, a taller walk-up.
	Street.walkup(Street.lot(d, -1, 23, Z(-8), 15), 15, { floors = 4, bays = 2, doorBay = 2, noUnit = true })
	Street.walkup(Street.lot(d, -1, 27, Z(-23), 17), 17, { floors = 3, bays = 3, doorBay = 3, wall = P.brickDark })
	local store = Street.cornerStore(Street.lot(d, -1, 21, Z(-40), 14), 14)
	Street.waterTower(store, 10, roofOf(2) + 1.2, -5.5) -- (on the low store, near its street corner, so it shows at the end of the street)
	Street.walkup(Street.lot(d, 1, 20, Z(-8), 20), 20, { floors = 3, bays = 3, doorBay = 2, wall = P.brickPink })
	-- (the tall one stands 3 forward of its neighbour, so its side door and the bins show down the alley)
	Street.walkup(Street.lot(d, 1, 17, Z(-35), 17.4), 17.4, { floors = 4, bays = 2, doorBay = 1, noUnit = true })
	-- The alley (z -28 to -35): a dead end at a brick wall. The tall walk-up's side door with its bin and bags beside
	-- it, a lamp over the door, the dumpster against the other wall.
	d:box('AlleyFloor', V(20.6, -1, Z(-35)), V(41, 0.04, Z(-28)), C(98, 100, 106), M.Asphalt)
	d:box('AlleyWall', V(40, -1, Z(-35)), V(41.4, 13, Z(-28)), P.brickDark, M.Brick)
	d:box('SideDoorFrame', V(22.6, 0, Z(-35)), V(26.4, 8.3, Z(-34.75)), P.frame, M.SmoothPlastic)
	d:box('SideDoor', V(23.1, 0, Z(-35)), V(25.9, 7.8, Z(-34.55)), P.doorDark, M.SmoothPlastic)
	light(d:box('SideDoorLamp', V(24.1, 9.0, Z(-35)), V(24.9, 9.8, Z(-34.2)), P.iron, M.Metal), P.lampGlow, 0.6, 10)
	trashCan(d, V(21.9, 0.04, Z(-33.7)))
	trashBags(d, V(27.6, 0.04, Z(-33.4)))
	dumpster(d, CFrame.new(34, 0.04, Z(-30.3)))
	-- At the kerb: two parked cars (not near the ring), a hydrant, two lamps where they're needed (by a stoop, at
	-- the alley mouth), one street tree in the deeper front of the middle walk-up, the bike rack by the store.
	car(d, CFrame.new(-11.6, 0, Z(-14.5)) * CFrame.Angles(0, math.pi, 0), C(86, 112, 146))
	car(d, CFrame.new(6.3, 0, Z(-46)), C(228, 228, 232))
	Street.hydrant(d, V(10.3, 0.3, Z(-24)))
	lantern(d, V(-15.5, 0.3, Z(-22.5)))
	lantern(d, V(10.5, 0.3, Z(-37)))
	tree(d, V(-23.6, 0.3, Z(-29.5)), 31, 0.85)
	Street.bikeRack(d, CFrame.new(-18.2, 0.3, Z(-45.5)) * CFrame.Angles(0, math.pi / 2, 0), C(70, 120, 190))
	Street.nameSign(d, V(-15.2, 0.3, Z(-54.3)), 'THE BLOCK')
	-- The cross streets end at yard walls just past the gate's railing.
	for _, s in { -1, 1 } do
		for _, zz in { { -8, 0 }, { -SLEN, s < 0 and -54 or -52.4 } } do
			d:box('YardWall', V(s * 36, -1, Z(zz[1])), V(s * 37.4, 10, Z(zz[2])), P.brickDark, M.Brick)
			d:box('YardWallCap', V(s * 35.8, 10, Z(zz[1])), V(s * 37.6, 10.6, Z(zz[2])), P.stone, M.Concrete)
		end
	end
	Street.seal(d, top)
end

-- Shop Street (stage 4): a wide pedestrian strip, no road. Low shopfronts at different setbacks (the café 6 back, the
-- grocery 4) under deep striped awnings, names on plain fascias. The fight pad stands in a square of darker paving;
-- past it, a market island on the axis that the walk splits round, with café tables in the café's forecourt on one
-- side and a delivery bay on the other (a van, a pallet of crates and a hand truck at a loading door).
function Street.shops(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Paving', V(-42, -1, Z(-SLEN)), V(40, 0, Z(0)), C(212, 198, 178), M.SmoothPlastic)
	d:box('Frontage', V(-42, -1, Z(-63.5)), V(-29, 0.03, Z(-42.5)), C(192, 176, 156), M.SmoothPlastic) -- (the café's forecourt)
	d:box('PadSquare', V(-11, -1, Z(-43)), V(11, 0.02, Z(-21)), C(198, 184, 164), M.SmoothPlastic)
	-- West: the barber on the corner, the bakery, the café set back (three storeys) by the next gate.
	barberShop(Street.lot(d, -1, 36, Z(0), 20), 20, { stripe = 3, fascia = true, noUnit = true })
	shopBuilding(Street.lot(d, -1, 38, Z(-20), 22), 22, { sign = 'BAKERY', signColor = C(150, 104, 70), stripes = { C(210, 140, 78), P.white }, wall = P.tan, stripe = 3.2, fascia = true })
	shopBuilding(Street.lot(d, -1, 42, Z(-42), 22), 22, { sign = 'CAFE', signColor = C(150, 98, 66), stripes = { C(198, 126, 76), P.cream }, wall = P.brick, floors = 3, depth = 24, stripe = 3.2, awningDepth = 6, fascia = true, noUnit = true })
	-- East: the sneaker shop (narrow, three storeys), the grocery set back, the delivery bay, the ice-cream shop.
	shopBuilding(Street.lot(d, 1, 36, Z(0), 16), 16, { sign = 'SNEAKERS', signColor = C(44, 48, 58), stripes = { C(58, 62, 72), P.white }, wall = P.brickDark, floors = 3, bays = 2, stripe = 3.2, fascia = true, noUnit = true })
	grocery(Street.lot(d, 1, 40, Z(-16), 20), 20, { depth = 26, stripe = 3.2, fascia = true, noCrates = true })
	shopBuilding(Street.lot(d, 1, 36, Z(-50), 14), 14, { sign = 'ICE CREAM', signColor = C(206, 116, 150), stripes = { C(226, 140, 176), P.white }, wall = C(240, 226, 206), bays = 2, stripe = 3, fascia = true, noUnit = true })
	-- The delivery bay (z -36 to -50): the van backed up to the loading door, a pallet of crates beside it, a hand
	-- truck at the dock.
	d:box('BayFloor', V(36, -1, Z(-50)), V(52, 0.04, Z(-36)), C(168, 170, 176), M.Concrete)
	Street.loadingDock(Street.lot(d, 1, 52, Z(-36), 14), 14, { depth = 14 })
	Street.boxTruck(d, CFrame.new(42.6, 0.04, Z(-43)) * CFrame.Angles(0, math.pi / 2, 0), C(84, 140, 104))
	pallet(d, CFrame.new(44.5, 0.04, Z(-38.4)))
	crate(d, CFrame.new(43.6, 0.84, Z(-38.4)), 2.4)
	crate(d, CFrame.new(45.9, 0.84, Z(-38.2)) * CFrame.Angles(0, 0.25, 0), 2)
	Street.handTruck(d, CFrame.new(48.9, 0.04, Z(-48.6)) * CFrame.Angles(0, -math.pi / 2, 0))
	-- The market island on the axis past the fight pad: two stalls of different sizes, their stock in a crate, and a
	-- tree, on a kerbed island the walk splits round.
	d:box('IslandKerb', V(-13, -1, Z(-53)), V(7, 0.6, Z(-44.5)), P.stone, M.Concrete)
	Street.stall(d, CFrame.new(-7.9, 0.6, Z(-48.6)), 7.6, 4.2, { C(204, 84, 72), P.cream, C(204, 84, 72), P.cream, C(204, 84, 72) }, { C(214, 76, 64), C(236, 150, 66), C(124, 186, 78), C(214, 76, 64) })
	Street.stall(d, CFrame.new(-1.2, 0.6, Z(-49.4)), 4.4, 3.4, { C(70, 140, 96), P.cream, C(70, 140, 96) }, { C(236, 204, 90), C(124, 186, 78) })
	crate(d, CFrame.new(-12.0, 0.6, Z(-51.4)) * CFrame.Angles(0, 0.3, 0), 1.8)
	tree(d, V(4.2, 0.6, Z(-48.8)), 47, 0.8)
	-- Café tables (two under the awning, one out in the sun with a parasol), the bike rack by the grocery door, two
	-- lamps.
	local stool = C(196, 126, 76)
	Street.cafeTable(d, V(-38.8, 0.03, Z(-46.6)), 0.3, stool)
	Street.cafeTable(d, V(-38.4, 0.03, Z(-53.2)), 1.2, stool)
	Street.cafeTable(d, V(-32.4, 0.03, Z(-50.2)), -0.3, stool, C(198, 126, 76))
	Street.bikeRack(d, CFrame.new(37.4, 0, Z(-24)) * CFrame.Angles(0, math.pi / 2, 0), C(206, 116, 150))
	lantern(d, V(-35.4, 0, Z(-40.5)))
	lantern(d, V(33.8, 0, Z(-13.5)))
	Street.seal(d, top)
end

-- The Courts (stage 7): buildings on the east side only; the west side opens into a park. A fenced basketball court
-- runs along the street, its gate facing the fight pad across a short footpath, a floodlight mast at two corners,
-- bleachers on the far side, a bench and a bin beside the court gate, trees and a tall hedge at the back.
function Street.courts(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	-- The promenade (the old paving's colour) and the cross streets at both gates; the lawn.
	d:box('Promenade', V(-10, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-4.5)), V(-10, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-SLEN)), V(-10, 0, Z(-59.5)), P.tileA, M.SmoothPlastic)
	d:box('Lawn', V(-FRONT, -1, Z(-59.5)), V(-10, 0.12, Z(-4.5)), P.grass, M.Grass)
	d:box('Lawn', V(-64, -1, Z(-SLEN)), V(-FRONT, 0.12, Z(0)), P.grass, M.Grass)
	d:box('LawnEdge', V(-10.5, -1, Z(-59.5)), V(-9.9, 0.25, Z(-4.5)), P.kerb, M.Concrete)
	d:box('Footpath', V(-14, -1, Z(-35)), V(-10.5, 0.16, Z(-29)), P.tileB, M.SmoothPlastic)
	-- The court, along the street: keys at both ends, a centre circle and line, the edge lines; hoops at both ends.
	local cx, cz = -28, Z(-34)
	d:box('Court', V(-40, -1, Z(-53)), V(-16, 0.2, Z(-15)), P.court, M.SmoothPlastic)
	for _, s in { -1, 1 } do d:box('CourtKey', V(cx - 4, 0.2, cz + s * 19), V(cx + 4, 0.22, cz + s * 12), P.courtKey, M.SmoothPlastic) end
	d:post('CourtCircle', 3.4, 0.02, V(cx, 0.2, cz), P.courtKey, M.SmoothPlastic)
	for _, e in { { V(-40, 0.2, cz - 0.2), V(-16, 0.23, cz + 0.2) }, { V(-40, 0.2, Z(-15.4)), V(-16, 0.23, Z(-15)) }, { V(-40, 0.2, Z(-53)), V(-16, 0.23, Z(-52.6)) },
		{ V(-40, 0.2, Z(-53)), V(-39.6, 0.23, Z(-15)) }, { V(-16.4, 0.2, Z(-53)), V(-16, 0.23, Z(-15)) } } do
		decor(d:box('CourtLine', e[1], e[2], P.courtLine, M.SmoothPlastic))
	end
	Street.hoop(d, CFrame.lookAt(V(cx, 0, Z(-13.6)), V(cx, 0, Z(-80))), P.courtKey)
	Street.hoop(d, CFrame.lookAt(V(cx, 0, Z(-54.4)), V(cx, 0, Z(20))), P.courtKey)
	-- The cage round it, green-coated and see-through enough to show the court; its gate on the street side opposite
	-- the fight pad.
	local x0, x1, z0, z1, cage = -42, -14, Z(-56), Z(-12), C(58, 104, 80)
	chainLink(d, V(x0, 0.12, z1), V(x1, 0.12, z1), 8, nil, 0.7, cage)
	chainLink(d, V(x0, 0.12, z0), V(x1, 0.12, z0), 8, nil, 0.7, cage)
	chainLink(d, V(x0, 0.12, z0), V(x0, 0.12, z1), 8, nil, 0.7, cage)
	chainLink(d, V(x1, 0.12, z1), V(x1, 0.12, z0), 8, { { 17, 23 } }, 0.7, cage)
	Street.floodlight(d, V(-44.5, 0.12, Z(-10.5)), V(cx, 0, cz))
	Street.floodlight(d, V(-12.2, 0.12, Z(-58)), V(cx, 0, cz))
	-- Bleachers outside the far sideline, facing the court and the street; the bench and bin by the court gate.
	Street.bleachers(d, CFrame.new(-44.6, 0.12, cz) * CFrame.Angles(0, math.pi / 2, 0), 22)
	bench(d, V(-12.2, 0.12, Z(-39.2)), V(1, 0, 0))
	trashCan(d, V(-12.2, 0.12, Z(-43.6)))
	tree(d, V(-55, 0.12, Z(-11)), 71, 1.0)
	tree(d, V(-56.5, 0.12, Z(-50)), 72, 0.9)
	tree(d, V(-24, 0.12, Z(-59)), 73, 1.05)
	hedgeZ(d, -62.8, Z(-62), Z(-2), 5)
	-- East: three buildings, the middle one standing forward.
	tanBuilding(Street.lot(d, 1, 36, Z(0), 20), 20, { floors = 3, balconies = false, noUnit = true })
	brickBuilding(Street.lot(d, 1, 31, Z(-20), 24), 24, { floors = 4, wall = P.brickDark, bays = 3 })
	brickBuilding(Street.lot(d, 1, 36, Z(-44), 20), 20, { floors = 2, wall = P.brick, bays = 3, noUnit = true })
	lantern(d, V(-8.8, 0, Z(-46)))
	lantern(d, V(28.6, 0, Z(-42.5)))
	Street.seal(d, top)
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
	-- A notch quieter than the shared prop builds it, in one red family: red and cream ropes (no more hue cycling),
	-- a deep red skirt and apron trim, cream bleacher noses, and a crowd in less hot shirts. Gold stays on the
	-- sign frame and the canvas logo only.
	local gold = C(226, 184, 84)
	local ropes = ringModel:FindFirstChild('Ropes')
	if ropes then ropes:SetAttribute('Hue', nil) ropes:RemoveTag('HoodMotion') end
	for _, p in ringModel:GetDescendants() do
		if not p:IsA('BasePart') then continue end
		if p.Name == 'SignNeon' or p.Name == 'CanvasLogo' then
			p.Color, p.Material = gold, p.Name == 'CanvasLogo' and M.Fabric or M.SmoothPlastic
		elseif p.Name == 'ApronTrim' then
			p.Color, p.Material = Craft.dark(P.boss), M.SmoothPlastic
		elseif p.Name == 'BleacherNose' then
			p.Color = P.cream
		elseif p.Name == 'Skirt' then
			p.Color = P.boss
		elseif p.Name == 'Rope' then
			-- Rows 1 and 3 red, 2 and 4 cream (rope row = height above the canvas in 1.15 steps).
			local row = math.floor((p.CFrame.Y - V2.Origin.Y - 3.4) / 1.15 + 0.5)
			p.Color, p.Material = row % 2 == 1 and P.boss or P.cream, M.SmoothPlastic
		elseif p.Name == 'FanBody' then
			local h, s, v = p.Color:ToHSV()
			p.Color = Color3.fromHSV(h, s * 0.7, v * 0.92)
		end
	end
	-- The ring's falling confetti in the same family (gold, cream, red) and a little thinner, so its trail doesn't
	-- read as a cyan streak across the BOSS board behind the ring.
	local confetti = ringModel:FindFirstChild('Confetti', true)
	if confetti and confetti:IsA('ParticleEmitter') then
		confetti.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, gold), ColorSequenceKeypoint.new(0.5, P.cream), ColorSequenceKeypoint.new(1, P.boss) })
		confetti.Rate = 6
	end
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	-- A warm gold champion's aura (tier 8) instead of the tier-9 rainbow, kept low and inside the ropes (10 x 4 x 10)
	-- so the BOSS board behind the ring reads from the yard entrance.
	if canvas and vfx then vfx.station(canvas, 8, C(236, 184, 84), V(10, 4, 10)) end
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
	-- (Raised so the board's title clears the Champ Ring's belt hologram when seen from the yard entrance.)
	local sg = b:at(CFrame.new(0, 0, bz - 11.5)):group('BossSign')
	local bossD = Craft.dark(P.boss)
	local up = 5.8 -- (any higher and the ring truss's far beam crosses the title from the entrance)
	for _, x in { -10.2, 10.2 } do
		sg:box('GantryFoot', V(x - 1.3, 0, -1.3), V(x + 1.3, 1.0, 1.3), C(150, 152, 160), M.Concrete)
		sg:box('GantryPost', V(x - 0.6, 1.0, -0.6), V(x + 0.6, 16.6 + up, 0.6), bossD, M.SmoothPlastic)
		sg:box('GantryCap', V(x - 0.9, 17.8 + up, -0.9), V(x + 0.9, 18.3 + up, 0.9), P.cream, M.SmoothPlastic)
	end
	sg:box('GantryBeam', V(-11.1, 16.6 + up, -0.6), V(11.1, 17.8 + up, 0.6), bossD, M.SmoothPlastic)
	for _, x in { -6, 6 } do sg:box('SignHanger', V(x - 0.3, 15.6 + up, -0.3), V(x + 0.3, 16.6 + up, 0.3), bossD, M.SmoothPlastic) end
	local face = Craft.board(sg, -8.6, 8.4 + up, 8.6, 15.2 + up, P.boss)
	Craft.words(face, 'BOSS', 'THE FINAL FIGHT', P.boss)
	local gold = C(226, 184, 84)
	sg:box('CrownBand', V(-2.4, 17.8 + up, -0.7), V(2.4, 19.0 + up, 0.7), gold, M.SmoothPlastic)
	for _, x in { -1.8, 0, 1.8 } do
		local k = x == 0 and 1.35 or 1
		sg:part('CrownPoint', V(1.1, 1.1, 1.1) * k, CFrame.new(x, 19.1 + up + (k - 1) * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 4), gold, M.SmoothPlastic)
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
	root:SetAttribute('LobbySpawn', SPAWN + Vector3.new(0, Lobby.SpawnTop or 0, 0)) -- the low spawn pad's top (the LOBBY teleport lands 3 above it)
	if Lobby.SpawnYaw then root:SetAttribute('LobbySpawnYaw', Lobby.SpawnYaw) end -- the way the spawn faces (radians about Y): west, down the runner to BAY 1
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
