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
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). The streets have no fight pads; only the
-- boss yard keeps one (HoodFightPad, Fight = 16) under its sign. Looks are equipped from the HUD's EVOLVE
-- menu; Training_<Id> stations (8 in the lobby, the Ring in the boss yard) train.
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
-- (V2.Fights, the list of the 15 street fight rings plus the boss, went with the street rings on 2026-10-08: no game
-- code read it. The boss yard's BOSS pad still carries its HoodFightPad tag and Fight = 16.)
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

-- Fight pad: a small boxing ring. Only the boss yard's BOSS pad uses it now; the 15 street rings were removed
-- (the user's call, 2026-10-08: the street and its gate are the stage). A dark base, a cream apron, the mat in the
-- pad's colour with its label, a dark post at each corner under a padded cushion, and two cream ropes on three sides.
-- The side players walk up from (+Z) stays open; the ropes don't collide. 17 parts, no neon.
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

-- Teleport pad, built as a bus stop (Brief 9 and 10: a transit point by its shape, small and quiet). A boarding spot
-- on the pavement (a grey disc in a thin rim of the stop's colour) and, behind it, a short pole with a small white
-- flag reaching back over the spot. Only the flag's pictogram is in colour, built from parts that show on both faces:
-- a house for SPAWN, a fast-forward double chevron for FURTHEST STAGE. The label under it is the only text. Each target
-- keeps one hue everywhere: SPAWN rose, FURTHEST amber; anything else takes `color`. The disc keeps the pad's name and
-- the prompt (StageService handles targets 'Lobby' and 'Furthest'); it is low enough to walk onto.
-- opts.side (1 unless given): the pole stands behind the spot on that side (+X or -X) and the flag reaches from it
-- toward the spot. opts.pole = false leaves the pole out: the gates' two stops share one pole (f2_stages gateStop).
-- The lobby's FurthestPad is this same unit with its own pole, so it reads as the stops on the street do.
local function teleportPad(g, name, x, z, color, target, label, opts)
	opts = opts or {}
	local main = ({ Lobby = C(204, 92, 158), Furthest = C(214, 150, 44) })[target] or color
	local white, pole, grey = C(244, 242, 238), C(70, 74, 84), C(150, 152, 158)
	local side = opts.side or 1
	local o = V(x, 0, z)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- (cylinders lie along X; this stands them up)
	g:part(name .. 'Kerb', V(0.3, 3.6, 3.6), CFrame.new(o + V(0, 0.15, 0)) * up, main, M.SmoothPlastic, Enum.PartType.Cylinder)
	local pad = g:part(name, V(0.12, 3.0, 3.0), CFrame.new(o + V(0, 0.36, 0)) * up, grey, M.SmoothPlastic, Enum.PartType.Cylinder)
	-- the pole behind the spot (+Z: players come from -Z, the slot rule), off to its side; the flag between them
	local px, pz = x + side * 2.2, z + 2.3
	if opts.pole ~= false then g:box(name .. 'Pole', V(px - 0.16, 0, pz - 0.16), V(px + 0.16, 5.6, pz + 0.16), pole, M.SmoothPlastic) end
	local fx = px - side * 1.06 -- (the flag's centre)
	local face = g:box(name .. 'Sign', V(fx - 0.9, 3.8, pz - 0.14), V(fx + 0.9, 5.3, pz + 0.14), white, M.SmoothPlastic)
	local iy = 4.85 -- (the pictogram's middle)
	if target == 'Lobby' then -- a house: a block with a square turned 45 degrees for its roof
		g:box(name .. 'Icon', V(fx - 0.3, iy - 0.42, pz - 0.21), V(fx + 0.3, iy, pz + 0.21), main, M.SmoothPlastic)
		g:part(name .. 'Icon', V(0.56, 0.56, 0.42), CFrame.new(fx, iy, pz) * CFrame.Angles(0, 0, math.pi / 4), main, M.SmoothPlastic)
	else -- fast forward: two chevrons pointing to the reader's right on the stop's front (-X here)
		for _, tx in { fx - 0.36, fx + 0.06 } do
			for _, s in { 1, -1 } do
				g:part(name .. 'Icon', V(0.64, 0.17, 0.42), CFrame.new(tx + 0.17, iy + s * 0.17, pz) * CFrame.Angles(0, 0, s * math.pi / 4), main, M.SmoothPlastic)
			end
		end
	end
	for _, f in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = surface(face, f, 32)
		pcall(function() sg.MaxDistance = 60 end)
		line(sg, 'Title', target == 'Furthest' and 'FURTHEST' or label, main:Lerp(P.black, 0.35), FONT.loud, 0.66, 0.3)
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
-- Shooting-range lanes, the numbered bays (Brief 10: a bay reads as SHOOTING with every sign hidden). Every lane is
-- the same shooting booth; only its floor and one hero prop change from bay to bay:
--   entrance   two short posts at the aisle end. The left (-X) one carries the bay's plaque at waist height (BAY n,
--              xN POWER, the Power it needs, open or locked); a rope hangs between them while the lane is locked;
--   booth      a plywood partition at the firing line on the lane's +X side (bay 1 has one each side), so the row
--              reads as a range's shooting stalls;
--   bench      a waist-high counter across the firing line: a pistol on a foam rest and spent brass;
--   target     one painted target at the far end with bullet holes in it (never glowing), its centre 5.8 to 6.3 over
--              the mat and a little off the lane's axis (each bay its own spot), where every shot lands. The higher
--              the bay, the tighter the group;
--   backstop   a concrete wall across the outer end, a little taller every tier, with a stray hole or two;
--   lamp       a hidden spot over the lane on the target: bright while the lane is open, dim while it is locked.
-- The tier shows in the mat (the bay's floor) and ONE hero prop, never glow, so each bay reads a little better
-- than the last:
--   1 stone   blue rubber mat, a plywood bullseye on a stake, a stack of old tyres (the humble start)
--   2 red     red painted floor, a red and white board, a striped police barrier
--   3 lava    terracotta tiles, a steel plate with orange rings, a fire barrel (a still painted flame, no effect)
--   4 arcane  violet carpet, a carnival spinner, a bunch of balloons
--   5 shadow  obsidian floor, a dark plate with violet rings, one violet crystal
--   6 frost   an ice floor, an ice-blue bullseye, a block of ice
--   7 toxic   a diamond-plate floor, a lime and navy plate, a toxic drum
--   8 gold    a gold floor, a gold gong that rings when hit (with a few glints)
-- Cartoon targets only: boards, plates, a spinner, a gong. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~9.8 (gold's
-- gong stand on its 9-stud backstop). opts.vfx = false skips effects, opts.tier overrides the tier.
-- Contract (Lobby.client, Shoot.client, LobbyRules): Training_<Id> > TrainingZone (the shooter's box,
-- invisible), Equipment > Targets > Target1 (Hinge = the pivot part, Swing = the parts that move; attributes
-- Knock = Tip | Swing | Spin, Hit = the sound it makes, Aim = world centre where shots land, Main = true),
-- Equipment > Gear (the stand and the hero prop), Sign (the plaque part: SurfaceGui Label with TextLabels Bay,
-- Power, Cost, Detail; the client writes Detail), LockRope parts (the client hides them once the lane is open),
-- TargetLamp (an invisible part with a SpotLight whose Open/Locked attributes are its two brightnesses; the client
-- sets it with the rope), attributes Tier,
-- HitPoint (the target's centre), HitColor, TextColor. Equipment has no Hinge of its own: Shoot.client knocks the
-- target back when a shot lands on it.
local Stations = {}

-- What every bay shares: a dark kerb, concrete backstop, plywood partition, grey bench, the gear on it.
Stations.Common = {
	rim = C(62, 66, 76), post = C(48, 51, 60),
	back = C(150, 152, 158), backCap = C(122, 124, 132),
	partition = C(176, 140, 100),
	benchBody = C(84, 88, 100), benchTop = C(214, 180, 136),
	slide = C(44, 46, 54), grip = C(132, 84, 50), rest = C(196, 200, 206),
	brass = C(236, 186, 76), hole = C(28, 28, 32), splash = C(206, 208, 214),
	lamp = C(255, 240, 215),
}
-- Per tier (Skins.Stations order). mat (+matMat): the bay's floor, the one surface in its colour; stand
-- (+standMat): the target's stake or stand; text: the plaque's "xN POWER" (and the HUD hint); glow: hit sparks;
-- fx: the bay has a HoodVFX theme effect (only the top bay: glints round the gold gong).
-- Brief 8 volume: big surfaces stay at HSV saturation 0.6 or less.
Stations.Themes = {
	{ name = 'stone', mat = C(115, 132, 172), stand = C(150, 100, 66), standMat = M.Wood, text = C(255, 255, 255), glow = C(255, 236, 200) },
	{ name = 'red', mat = C(196, 86, 96), matMat = M.Concrete, stand = C(38, 44, 88), text = C(255, 110, 130), glow = C(255, 70, 100) },
	{ name = 'lava', mat = C(196, 124, 96), matMat = M.Slate, stand = C(70, 66, 76), standMat = M.Metal, text = C(255, 170, 48), glow = C(255, 150, 40) },
	{ name = 'arcane', mat = C(150, 96, 178), matMat = M.Fabric, stand = C(120, 72, 170), text = C(224, 150, 255), glow = C(230, 120, 255) },
	{ name = 'shadow', mat = C(58, 40, 86), matMat = M.Slate, stand = C(30, 24, 40), standMat = M.Metal, text = C(198, 164, 255), glow = C(176, 120, 255) },
	{ name = 'frost', mat = C(160, 222, 236), matMat = M.Ice, stand = C(70, 124, 192), text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', mat = C(70, 104, 84), matMat = M.DiamondPlate, stand = C(26, 64, 60), standMat = M.Metal, text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'gold', mat = C(226, 196, 104), stand = C(232, 180, 70), text = C(255, 222, 50), glow = C(255, 222, 80), fx = true },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.BOX_Z = -3.2 -- the shooter's box runs from the aisle end to here
Stations.BENCH_Z = -2.75 -- the bench's centre line (its top is 1.1 deep)
Stations.BENCH_H = 2.3 -- bench top over the mat: waist height, under the held gun
Stations.FIELD_Z0, Stations.FIELD_Z1 = -1.9, 8.4 -- the target field (effects fill it)
Stations.BACK_Z = 8.5 -- the backstop's front face
Stations.TARGET = V(0, 0.4 + 5.8, 6.0) -- the target centre (where shots land) before each bay's shift
-- Each bay's target stands a little off the line (sideways and up, never lower: it stays over the shooter's head
-- in the follow camera), so the row's bullseyes are not one ruled line. Stations.aimOf(tier) is where shots land.
Stations.TargetShift = { V(0.45, 0, 0), V(-0.4, 0.3, 0), V(0.3, 0.5, 0), V(-0.45, 0.1, 0), V(0.4, 0.4, 0), V(-0.3, 0.2, 0), V(0.45, 0.5, 0), V(0, 0, 0) }
function Stations.aimOf(tier) return Stations.TARGET + (Stations.TargetShift[tier] or V(0, 0, 0)) end
Stations.ENTRY_Z = -9.5 -- the entrance posts' centre line
Stations.LAMP = V(0, 10.2, 0.6) -- the hidden lane lamp (over the field, aimed at the target)
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
function Stations.ringFace(i) return 0.02 - (0.08 + 0.035 * i) end -- ring i's front face (z in the bullseye's frame)
function Stations.bullseye(c, cf, r, colors, material)
	local n, outer = #colors, nil
	for i, col in colors do
		local th = 0.08 + 0.035 * i
		local p = Stations.disc(c, 'Ring', cf * CFrame.new(0, 0, 0.02 - th / 2), r * (n - i + 1) / n, th, col, type(material) == 'table' and material[i] or material)
		outer = outer or p
	end
	return outer
end
-- Bullet holes in a bullseye of radius r and n rings (the frame `cf` passed to Stations.bullseye): `count`
-- holes spread round the centre out to `spread` x r (a golden-angle walk from `seed`, so no two targets share
-- a pattern), each sitting on the face of the ring it falls in. color: dark holes in paper and wood, light lead
-- splashes on steel.
function Stations.holes(c, cf, r, n, count, spread, seed, color)
	for i = 1, count do
		local a = math.rad(seed * 47 + i * 137.5)
		local rho = r * spread * (0.25 + 0.75 * ((seed * 0.37 + i * 0.618) % 1))
		local ring = math.clamp(n - math.floor(rho / (r / n)), 1, n)
		local z = Stations.ringFace(ring) - 0.025
		decor(Stations.disc(c, 'BulletHole', cf * CFrame.new(rho * math.cos(a), rho * math.sin(a), z), 0.15, 0.05, color or Stations.Common.hole))
	end
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
-- The bench pistol (the Rusty Pistol's blocky profile): dark slide, brown grip raked back, trigger guard, in a frame
-- where the profile lies in XY facing -Z, the muzzle toward +X and the grip down; `cf` is the slide's underside at
-- the grip. About 2.1 long at scale 1.
function Stations.pistol(c, cf, k)
	local K = Stations.Common
	k = k or 1
	decor(c:part('PistolSlide', V(2.1, 0.46, 0.32) * k, cf * CFrame.new(0.5 * k, 0.23 * k, 0), K.slide))
	decor(c:part('PistolGrip', V(0.54, 1.05, 0.3) * k, cf * CFrame.new(-0.36 * k, -0.46 * k, 0) * CFrame.Angles(0, 0, math.rad(-14)), K.grip, M.Wood))
	decor(c:part('PistolGuard', V(0.7, 0.1, 0.16) * k, cf * CFrame.new(0.36 * k, -0.42 * k, 0), K.slide))
end

---------------------------------------------------------------------------------------------- target
-- The lane's one target, the client can knock it: Equipment > Targets > Target1 with a Hinge (the pivot, a ghost
-- part at `pivot`) and a Swing model (build the visible target into the returned context). knock: 'Tip' (tips
-- back about the hinge's X axis with a little hop), 'Swing' (swings on its hanger), 'Spin' (spins about the
-- hinge's Y axis). Shots land on its centre (k.aim, Stations.aimOf); `hit` names the sound (Ding steel, Tock wood, Ice).
function Stations.target(k, pivot, knock, hit)
	local tc, model = k.targets:group('Target1')
	ghost(tc:part('Hinge', V(0.2, 0.2, 0.2), pivot, P.white))
	local sw = tc:group('Swing')
	model:SetAttribute('Knock', knock)
	model:SetAttribute('Hit', hit or 'Ding')
	model:SetAttribute('Aim', tc:world(CFrame.new(k.aim)).Position)
	model:SetAttribute('Main', true)
	if knock == 'Tip' then model:SetAttribute('TipMin', 0) end -- (rocks back off its stand, never into the shooter)
	k.main = model
	return sw, model
end
-- A stake behind the target at x: a foot block on the mat and a post up to `top`, its front 0.3 behind the target.
function Stations.stake(g, t, top, x)
	local Y, z = Stations.MAT_Y, Stations.TARGET.Z
	x = x or 0
	g:box('StandFoot', V(x - 0.75, Y, z + 0.1), V(x + 0.75, Y + 0.3, z + 1.5), t.stand:Lerp(C(0, 0, 0), 0.25), t.standMat)
	g:box('StandPost', V(x - 0.24, Y + 0.3, z + 0.32), V(x + 0.24, top, z + 0.8), t.stand, t.standMat)
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
-- A round board or plate (backing disc `board` plus painted rings) on a stake, with bullet holes; it tips back
-- when hit. `holes` = { count, spread, color }.
function Stations.board(k, t, r, board, rings, hit, boardMat, holes)
	local c = k.aim
	Stations.stake(k.gear, t, c.Y - 0.6, c.X)
	local sw = Stations.target(k, CFrame.new(c.X, c.Y - r - 0.1, c.Z + 0.25), 'Tip', hit or 'Tock')
	Stations.disc(sw, 'Board', CFrame.new(c.X, c.Y, c.Z + 0.12), r + 0.12, 0.2, board, boardMat)
	local cf = CFrame.new(c.X, c.Y, c.Z + 0.03)
	Stations.bullseye(sw, cf, r, rings)
	Stations.holes(sw, cf, r, #rings, holes[1], holes[2], k.tier, holes[3])
	return sw
end

---------------------------------------------------------------------------------------------- lane pieces
-- The base: a low studded kerb round the mat (one course, the same dark grey on every bay) and the bay's floor.
function Stations.base(st, t)
	local X, Z, MX, MZ, Y = Stations.HALF_X, Stations.HALF_Z, Stations.HALF_X - 1, Stations.HALF_Z - 1, Stations.MAT_Y
	for _, b in { { V(-X, 0, -Z), V(X, Stations.RIM_Y, -MZ) }, { V(-X, 0, MZ), V(X, Stations.RIM_Y, Z) }, { V(-X, 0, -MZ), V(-MX, Stations.RIM_Y, MZ) }, { V(MX, 0, -MZ), V(X, Stations.RIM_Y, MZ) } } do
		studs(st:box('Rim', b[1], b[2], Stations.Common.rim))
	end
	local mat = st:box('Mat', V(-MX, 0, -MZ), V(MX, Y, MZ), t.mat, t.matMat or M.Plastic)
	if mat.Material == M.Plastic then studs(mat) end
end

-- The booth: a plywood partition at the firing line on the +X kerb (bay 1, the row's end, also gets one on -X).
function Stations.booth(st, tier)
	local g = st:group('Booth')
	for _, sx in tier == 1 and { 1, -1 } or { 1 } do
		g:box('Partition', V(sx * 4.05, 0, -4.9), V(sx * 4.45, Stations.MAT_Y + 4.0, -0.8), Stations.Common.partition, M.Wood)
	end
end

-- The firing line: a waist-high counter across the lane (a grey body under a wood top that overhangs it a little),
-- and on it a pistol lying on a pale foam rest, with a spent casing beside it and another on the floor. The pistol
-- moves along the bench from bay to bay (no two neighbours match).
Stations.BenchLayouts = { -1.3, 1.1, -0.4, 1.6, -1.7, 0.5, -1.0, 1.4 } -- pistol x (its muzzle points to the middle)
function Stations.bench(st, tier)
	local K = Stations.Common
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	g:box('BenchBody', V(-3.4, Y, z - 0.42), V(3.4, Y + h - 0.3, z + 0.42), K.benchBody, M.SmoothPlastic)
	g:box('BenchTop', V(-3.6, Y + h - 0.3, z - 0.62), V(3.6, Y + h, z + 0.5), K.benchTop, M.Wood)
	local d = st:group('BenchProps')
	local y = Y + h
	local px = Stations.BenchLayouts[(tier - 1) % #Stations.BenchLayouts + 1]
	local muzzle = px < 0 and 1 or -1 -- (+1: the muzzle points +X, toward the lane's middle)
	local rest = CFrame.new(px, y, z - 0.02) * CFrame.Angles(0, math.rad(-16 * muzzle), 0) -- (turned a little down the lane)
	-- The pistol lies on its side on a 45-degree foam wedge (its slope faces up and toward the shooter), so its
	-- profile shows from the box, from the aisle and from the hall; its middle sits on the slope's middle.
	local slope = rest * CFrame.new(0, 0.5, 0)
	decor(d:wedge('PistolRest', V(2.3, 1.0, 1.0), slope, K.rest, M.Fabric))
	Stations.pistol(d, slope * CFrame.Angles(math.rad(45), 0, 0) * CFrame.new(0, 0.3, -0.16) * CFrame.Angles(0, muzzle < 0 and math.pi or 0, 0) * CFrame.new(-0.5, 0, 0))
	decor(d:part('Shell', V(0.34, 0.15, 0.15), CFrame.new(px - 1.45 * muzzle, y + 0.075, z - 0.2) * CFrame.Angles(0, 0.4 + tier, 0), K.brass, M.Metal, Enum.PartType.Cylinder))
	decor(d:part('Shell', V(0.34, 0.15, 0.15), CFrame.new(px * 0.6 + 0.5 * muzzle, Y + 0.075, z - 1.35) * CFrame.Angles(0, 1.1 + tier * 0.7, 0), K.brass, M.Metal, Enum.PartType.Cylinder))
end

-- The entrance at the aisle end: the plaque post (left) and a rope post (right) on the kerb, with a rope between
-- them while the lane is locked (the first paint is a new player's view: only bay 1 open; Lobby.client repaints
-- it), and the bay's one plaque on the left post at waist height, tilted back a little: BAY n, xN POWER, the Power
-- it needs (FREE on bay 1) and its state, readable up close (hidden past 60 studs), below the eye line in the lane.
function Stations.entrance(st, s, t, tier)
	local z, y0 = Stations.ENTRY_Z, Stations.RIM_Y
	local post = Stations.Common.post
	local g = st:group('Entrance')
	g:box('PlaquePost', V(-4.22, y0, z - 0.2), V(-3.82, y0 + 1.75, z + 0.2), post)
	g:box('RopePost', V(3.84, y0, z - 0.18), V(4.2, y0 + 1.95, z + 0.18), post)
	g:box('RopePostCap', V(3.78, y0 + 1.95, z - 0.24), V(4.26, y0 + 2.15, z + 0.24), post)
	local a, m, b = V(-3.82, y0 + 1.6, z), V(0, y0 + 1.25, z), V(3.84, y0 + 1.8, z)
	for _, seg in { { a, m }, { m, b } } do
		local rope = decor(g:bar('LockRope', seg[1], seg[2], 0.16, C(186, 52, 60), M.SmoothPlastic))
		rope.CastShadow = false
		rope.Transparency = tier == 1 and 1 or 0
	end
	-- The plaque: a small board (1.35 x 1.62) in a deep shade of the bay's floor colour on the post's top (it belongs
	-- to the bay, and with the text hidden it is a small coloured tab), its text on a SurfaceGui. Its top is 3.6 over
	-- the deck: under the eye line of a player standing in the lane.
	local sign = decor(g:part('Sign', V(1.35, 1.62, 0.16), CFrame.new(-3.8, y0 + 2.06, z - 0.12) * CFrame.Angles(math.rad(10), 0, 0), t.mat:Lerp(C(10, 10, 16), 0.55)))
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

-- The backstop: one concrete wall across the outer end, `h` over the mat, under a darker cap (a lip proud of the
-- front), and `misses` stray holes in its face round the target. Returns the cap's top.
function Stations.backstop(st, tier, misses, c)
	local K = Stations.Common
	local Y, z0, z1, h = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1, Stations.wallHeight(tier)
	local back = st:group('Backstop')
	back:box('Backstop', V(-4.3, 0, z0), V(4.3, Y + h, z1), K.back, M.Concrete)
	back:box('BackstopCap', V(-4.4, Y + h, z0 - 0.12), V(4.4, Y + h + 0.4, z1 + 0.05), K.backCap, M.Concrete)
	for i = 1, misses do
		local a = math.rad(tier * 71 + i * 151)
		local r = 2.45 + 0.5 * ((tier * 0.29 + i * 0.41) % 1)
		local x, y = c.X + r * math.cos(a) * 1.3, math.min(c.Y + r * math.sin(a) * 0.8, Y + h - 0.6)
		decor(Stations.disc(back, 'BulletHole', CFrame.new(math.clamp(x, -3.8, 3.8), y, z0 - 0.025), 0.15, 0.05, K.hole))
	end
	return Y + h + 0.4
end

-- The hidden lane lamp: an invisible part over the field with a SpotLight aimed at the target (critic 9 lighting
-- notes). Bright while the lane is open, dim while it is locked: Lobby.client sets Brightness to the light's Open
-- or Locked attribute with the rope. BAY 1, a new player's first lane, is warm; the rest are a cool white. The
-- first paint is a new player's view: bay 1 open.
function Stations.lamp(st, tier, aim)
	local p = ghost(st:part('TargetLamp', V(0.3, 0.3, 0.3), CFrame.lookAt(Stations.LAMP + V(aim.X, 0, 0), aim), P.white))
	p.CastShadow = false
	local l = Instance.new('SpotLight')
	l.Name = 'LaneLight'
	l.Face = Enum.NormalId.Front
	l.Color = tier == 1 and Stations.Common.lamp or C(235, 242, 255)
	l.Range, l.Angle, l.Shadows = 16, 60, false
	l:SetAttribute('Open', tier == 1 and 1.4 or 1.1)
	l:SetAttribute('Locked', 0.4)
	l.Brightness = l:GetAttribute(tier == 1 and 'Open' or 'Locked')
	l.Parent = p
	return p
end

---------------------------------------------------------------------------------------------- lanes
-- One builder per theme: the target on its stand and the bay's one hero prop. `k` holds st (the station),
-- gear (Equipment > Gear), targets (Equipment > Targets), t, tier, aim (the target centre) and burners (the hero part that carries an
-- effect, if any).
Stations.Lanes = {}
local WHITE, RED = C(250, 250, 245), C(226, 56, 60)

-- 1 Stone: a plywood bullseye on a wooden stake; a stack of old tyres by the backstop (holes all over: the first
-- bay).
function Stations.Lanes.stone(k)
	Stations.board(k, k.t, 1.55, C(206, 160, 110), { WHITE, RED, WHITE, RED }, 'Tock', nil, { 4, 0.9 })
	local tyre, hole = C(46, 46, 52), C(18, 18, 20)
	local tc = k.gear:group('Tyres')
	local Y = Stations.MAT_Y
	for i, o in { { -2.55, 7.35 }, { -2.4, 7.25 }, { -2.62, 7.4 } } do
		Stations.can(tc, 'Tyre', V(o[1], Y + (i - 1) * 0.62, o[2]), 1.0, 0.6, tyre)
	end
	decor(Stations.can(tc, 'TyreHole', V(-2.62, Y + 1.86, 7.4), 0.5, 0.04, hole))
end

-- 2 Red: a red and white bullseye on a navy board and stake; a striped police barrier at the side of the field.
function Stations.Lanes.red(k)
	Stations.board(k, k.t, 1.6, C(38, 44, 88), { WHITE, C(235, 35, 60), WHITE, C(235, 35, 60), C(255, 214, 40) }, 'Tock', nil, { 4, 0.8 })
	local bc = k.gear:group('Barrier')
	local Y = Stations.MAT_Y
	local at = CFrame.new(2.35, Y, 3.4) * CFrame.Angles(0, math.rad(-16), 0)
	for _, sx in { -1, 1 } do
		bc:part('BarrierLeg', V(0.18, 2.3, 0.7), at * CFrame.new(sx * 1.2, 1.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 8)), C(40, 44, 70), M.SmoothPlastic)
	end
	bc:part('BarrierBoard', V(3.0, 0.55, 0.12), at * CFrame.new(0, 1.95, -0.1), WHITE, M.SmoothPlastic)
	for _, x in { -0.75, 0.75 } do
		decor(bc:part('BarrierStripe', V(0.6, 0.57, 0.14), at * CFrame.new(x, 1.95, -0.1), C(226, 50, 56), M.SmoothPlastic))
	end
end

-- 3 Lava: a steel plate with orange rings on a steel stake; a fire barrel at the backstop's foot (its flame is two
-- painted wedges: the row has no fire effects and no lights but the lane lamps).
function Stations.Lanes.lava(k)
	local Y = Stations.MAT_Y
	Stations.board(k, k.t, 1.6, C(96, 90, 102), { C(240, 120, 40), WHITE, C(240, 120, 40), C(255, 196, 80) }, 'Ding', M.Metal, { 4, 0.75 })
	local pos = V(3.1, Y, 7.35)
	Stations.drum(k.gear, pos, 0.62, 1.75, C(150, 50, 32), C(70, 34, 28), C(40, 24, 22), M.Metal)
	k.gear:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.77, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(214, 104, 48), M.Slate, Enum.PartType.Cylinder)
	-- A still, low-poly flame out of its top (two painted wedges, no light, no particles).
	local f = CFrame.new(pos + V(0, 1.8, 0)) * CFrame.Angles(0, math.rad(30), 0)
	decor(k.gear:wedge('Flame', V(0.5, 1.2, 0.7), f * CFrame.new(0, 0.6, 0), C(244, 138, 44)))
	decor(k.gear:wedge('Flame', V(0.4, 0.8, 0.5), f * CFrame.Angles(0, math.pi, 0) * CFrame.new(0.05, 0.4, 0.05), C(255, 206, 80)))
end

-- 4 Arcane: a carnival spinner (pink, violet and white rings) on a violet post that turns slowly and spins when
-- hit; a bunch of three balloons tied by the post, bobbing.
function Stations.Lanes.arcane(k)
	local Y, c = Stations.MAT_Y, k.aim
	Stations.stake(k.gear, k.t, c.Y, c.X)
	local sw = Stations.target(k, CFrame.new(c), 'Spin', 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(c.X, c.Y, c.Z + 0.12), 1.72, 0.16, k.t.stand)
	local cf = CFrame.new(c.X, c.Y, c.Z + 0.03)
	Stations.bullseye(sw, cf, 1.6, { WHITE, C(255, 100, 200), WHITE, C(150, 60, 220), C(255, 220, 60) })
	Stations.holes(sw, cf, 1.6, 5, 3, 0.7, k.tier)
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

-- 5 Shadow: a dark steel plate with violet and lavender rings on a black stake; one tall violet crystal by the
-- backstop.
function Stations.Lanes.shadow(k)
	local Y = Stations.MAT_Y
	local violet, dark = C(170, 110, 255), C(40, 30, 60)
	Stations.board(k, k.t, 1.6, dark, { violet, C(214, 190, 255), violet, C(214, 190, 255), violet }, 'Ding', M.Metal, { 3, 0.6 })
	-- The crystal: a tall square prism turned 45 degrees with a ridged point (a cube on its edge), leaning a little.
	local at = CFrame.new(-2.85, Y, 7.55) * CFrame.Angles(0, 0, math.rad(8)) * CFrame.Angles(0, math.rad(45), 0)
	local cr = k.gear:part('Crystal', V(1.2, 3.0, 1.2), at * CFrame.new(0, 1.5, 0), violet, M.Glass)
	local tip = k.gear:part('CrystalTip', V(0.85, 0.85, 1.2), at * CFrame.new(0, 3.0, 0) * CFrame.Angles(0, 0, math.rad(45)), violet, M.Glass)
	cr.Transparency, tip.Transparency = 0.12, 0.12
end

-- 6 Frost: an ice-blue bullseye on a steel-blue stake; a block of ice at the side of the field.
function Stations.Lanes.frost(k)
	local Y = Stations.MAT_Y
	local snow, deep = C(248, 252, 255), C(25, 120, 235)
	Stations.board(k, k.t, 1.6, C(90, 200, 245), { snow, deep, snow, deep, WHITE }, 'Ice', nil, { 3, 0.55 })
	local ice = k.gear:part('IceBlock', V(2.0, 1.9, 1.7), CFrame.new(-2.45, Y + 0.95, 4.6) * CFrame.Angles(0, math.rad(-12), 0), C(170, 228, 250), M.Ice)
	ice.Transparency, ice.Reflectance = 0.15, 0.1
end

-- 7 Toxic: a lime and navy bullseye on a dark plate and stake; a lime toxic drum at the backstop's foot.
function Stations.Lanes.toxic(k)
	local Y = Stations.MAT_Y
	local lime, navy = C(110, 220, 90), C(24, 30, 70)
	Stations.board(k, k.t, 1.6, navy, { WHITE, navy, lime, navy, lime }, 'Ding', M.Metal, { 3, 0.5 })
	Stations.drum(k.gear, V(-3.0, Y, 7.3), 0.7, 2.0, lime, navy, C(40, 120, 50))
end

-- 8 Gold: a gold gong with a crimson ring and a ruby on a gold gong stand (the top bay's hero and its target);
-- a tight group of lead splashes round the ruby.
function Stations.Lanes.gold(k)
	local c = k.aim
	local gold, deep, velvet = C(255, 222, 40), C(245, 190, 0), C(150, 46, 64)
	local y1 = Stations.gongStand(k.gear, k.t)
	local sw = Stations.target(k, CFrame.new(c.X, y1, c.Z), 'Swing', 'Ding')
	local r = 1.85
	Stations.disc(sw, 'GongRim', CFrame.new(c.X, c.Y, c.Z + 0.03), r, 0.24, deep)
	Stations.disc(sw, 'Gong', CFrame.new(c.X, c.Y, c.Z - 0.02), r - 0.22, 0.28, gold)
	local cf = CFrame.new(c.X, c.Y, c.Z - 0.14)
	Stations.bullseye(sw, cf, (r - 0.22) * 0.68, { velvet, gold })
	sw:part('GongRuby', V(0.5, 0.5, 0.3), CFrame.new(c + V(0, 0, -0.32)) * CFrame.Angles(0, 0, math.pi / 4), C(235, 30, 70), M.Glass)
	Stations.holes(sw, cf, (r - 0.22) * 0.68, 2, 3, 0.75, k.tier, Stations.Common.splash)
	for _, sx in { -1, 1 } do
		sw:box('GongStrap', V(sx * 0.6 - 0.08, c.Y + r - 0.25, c.Z - 0.06), V(sx * 0.6 + 0.08, y1, c.Z + 0.06), C(52, 54, 66))
	end
end

-- Stray holes in each backstop (misses), fewer up the row.
Stations.Misses = { 2, 2, 1, 1, 1, 0, 1, 0 }

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
	Stations.booth(st, tier)
	Stations.bench(st, tier)
	Stations.entrance(st, s, t, tier)
	local aim = Stations.aimOf(tier)
	Stations.backstop(st, tier, Stations.Misses[tier] or 0, aim)
	Stations.lamp(st, tier, aim)

	-- Equipment: the stand and the hero prop (Gear) and the knockable target (Targets).
	local eq = st:group('Equipment')
	local k = { st = st, gear = eq:group('Gear'), targets = eq:group('Targets'), t = t, tier = tier, aim = aim, burners = {} }
	local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
	lane(k)
	-- The target and small gear never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(aim)).Position)
	model:SetAttribute('HitColor', t.glow)
	if t.fx and opts.vfx ~= false and VFX and VFX.theme then
		-- The theme's effect (only the top bay has one: glints round the gold gong).
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
-- o: floors, wall, bays, doorBay, door, depth, noUnit, cornice (S1, Brief 10: a deep tenement cornice along the
-- roofline, one part, so the Block's skyline differs from Shop Street's flat parapets)
function Street.walkup(ctx, w, o)
	local c, model = brickBuilding(ctx, w, { name = 'WalkUp', floors = o.floors, wall = o.wall, bays = o.bays, depth = o.depth, noUnit = o.noUnit, ground = function(c, _, list)
		local doorX = list[o.doorBay or 1]
		for _, x in list do if math.abs(x - doorX) > 3 then window(c, x, 4.2, {}) end end
		Street.stoop(c, doorX, o.door)
	end })
	if o.cornice then
		local roof = roofOf(o.floors)
		c:box('Cornice', V(-0.3, roof - 1.7, 0), V(w + 0.3, roof + 0.5, 1.6), C(214, 204, 188), M.SmoothPlastic)
	end
	return c, model
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
-- The Block's laundromat (stage 2's landmark, S1 Brief 10): one tall storey of pale tiles. Through a big shop window
-- you see a white bank of front-loaders, two rows of round doors, so it reads as a laundromat with no sign. The name
-- goes on a plain fascia; two dryer vent stacks stand on the roof. Facade-local like the buildings above, the door at
-- the left end (x 0). o: depth, wall, trim, corner (true: it stands on a corner, so the shop band and fascia wrap round
-- its left side, which gets a window and a service door). Returns the context, the model and the fascia (for the name).
function Street.laundromat(ctx, w, o)
	o = o or {}
	local c, model = ctx:group('Laundromat')
	local depth, H = o.depth or DEPTH, 12.4
	local wall, trim = o.wall or C(200, 214, 222), o.trim or C(66, 112, 146)
	-- The shop front is recessed 1.6 between two piers, so the machines can stand behind the glass.
	c:box('Wall', V(0, -1, -depth), V(w, H, -1.6), wall, M.SmoothPlastic)
	for _, x in { 0, w - 1.2 } do c:box('Pier', V(x, -1, -1.6), V(x + 1.2, H, 0.3), wall, M.SmoothPlastic) end
	c:box('ShopBase', V(1.2, -1, -1.6), V(w - 1.2, 1.2, 0.3), trim, M.SmoothPlastic)
	local fascia = c:box('ShopSign', V(0, 8.6, -1.6), V(w, 11.2, 0.5), trim, M.SmoothPlastic)
	c:box('Parapet', V(-0.2, H, -depth - 0.2), V(w + 0.2, H + 0.9, 0.6), trim:Lerp(P.black, 0.35), M.SmoothPlastic)
	c:box('ShopDoorFrame', V(1.2, 0, -0.6), V(5.2, 8.6, 0.3), P.white, M.SmoothPlastic)
	c:box('ShopDoor', V(1.7, 0, 0.3), V(4.7, 7.9, 0.45), P.glass, M.SmoothPlastic)
	local glass = decor(c:box('ShopGlass', V(5.2, 1.2, 0.05), V(w - 1.2, 8.6, 0.2), C(176, 204, 220), M.Glass))
	glass.Transparency, glass.CastShadow = 0.6, false
	-- The machines: one white bank, two rows of round doors (a chrome ring round a dark porthole).
	c:box('Machines', V(5.6, 0, -1.6), V(w - 1.6, 8.0, -0.7), P.white, M.SmoothPlastic)
	local n = math.max(2, math.floor((w - 7.6) / 3.3))
	local pitch = (w - 7.6) / n
	for k = 0, n - 1 do
		local x = 5.9 + pitch * (k + 0.5)
		for _, y in { 2.3, 5.7 } do
			local cf = CFrame.new(x, y, -0.6) * CFrame.Angles(0, math.pi / 2, 0)
			decor(c:rod('DrumRing', 1.25, 0.2, cf, C(196, 200, 208), M.SmoothPlastic))
			decor(c:rod('DrumDoor', 0.9, 0.3, cf, C(44, 56, 74), M.SmoothPlastic))
		end
	end
	for k, x in { w * 0.3, w * 0.62 } do c:post('VentStack', 0.55, 2.6 + k * 0.8, V(x, H + 0.9, -depth * 0.55), C(176, 180, 188), M.Metal) end
	if o.corner then
		c:box('ShopSignSide', V(-0.4, 8.6, -depth + 1.2), V(0, 11.2, 0.5), trim, M.SmoothPlastic)
		c:box('ShopBaseSide', V(-0.4, -1, -depth + 1.2), V(0, 1.2, 0.3), trim, M.SmoothPlastic)
		-- (on the side wall, facing -X: a framed window toward the front, a service door toward the back)
		local side = c:at(CFrame.new(0, 0, -depth) * CFrame.Angles(0, -math.pi / 2, 0))
		window(side, depth - 5, 3.2, {})
		side:box('SideDoorFrame', V(2.2, 0, 0), V(5.8, 8.2, 0.25), P.white, M.SmoothPlastic)
		side:box('SideDoor', V(2.6, 0, 0), V(5.4, 7.8, 0.4), P.doorDark, M.SmoothPlastic)
	end
	model:SetAttribute('Floors', 1)
	return c, model, fascia
end

-- ==== S2 kit BEGIN: Shop Street and Courts pieces (builder S2, Brief 10; add-only) ====
-- Shop Street's own facade (critic 13: it must not read as the Block's brick walk-up with a shop at the bottom). A low
-- painted front (smooth render, pale warm colours) of one to three storeys, wide shop-flat windows upstairs (one per bay,
-- no sills or mullions), a cream cornice over the shop, and a parapet with a coping instead of a slate roof, its middle
-- stepped up on some ("false front"). Ground floor: a shop window, a glass door at one end, a band, the awning and the
-- name on a plain fascia. Facade-local like the buildings (+X along the facade, +Z out to the street).
-- o: sign, signColor, textColor, trim, wall, stripes, floors (1-3, default 2), bays (upper windows per floor), depth,
--    stripe, awningDepth, step (the stepped parapet), doorLeft, pole (a barber's pole by the door), name,
--    arcade (the ground floor set back this far under the upper floors: the street builds the columns; the name then
--    sits on the beam over the columns, no awning)
function Street.shopfront(ctx, w, o)
	local c, model = ctx:group(o.name or ('Shop_' .. string.gsub(o.sign or 'Front', '%W', '')))
	local floors = o.floors or 2
	local roof = 13 + (floors - 1) * 9
	local depth = o.depth or DEPTH
	local wall = o.wall or P.tanLight
	local trim = o.trim or o.signColor or C(120, 110, 100)
	local rec = o.arcade or 0
	if rec > 0 then
		c:box('Wall', V(0, -1, -depth), V(w, 11, -rec), wall, M.SmoothPlastic)
		c:box('Wall', V(0, 11, -depth), V(w, roof, 0), wall, M.SmoothPlastic)
	else
		c:box('Wall', V(0, -1, -depth), V(w, roof, 0), wall, M.SmoothPlastic)
	end
	c:box('RoofTop', V(0, roof, -depth), V(w, roof + 0.3, -0.9), C(176, 178, 184), M.Concrete)
	c:box('Parapet', V(0, roof, -0.9), V(w, roof + 1.7, 0.25), wall, M.SmoothPlastic)
	c:box('Coping', V(-0.25, roof + 1.7, -1.1), V(w + 0.25, roof + 2.2, 0.5), P.cream, M.SmoothPlastic)
	if o.step then
		local sw = math.min(w * 0.42, 9)
		c:box('ParapetStep', V(w / 2 - sw / 2, roof + 2.2, -0.9), V(w / 2 + sw / 2, roof + 4.2, 0.3), wall, M.SmoothPlastic)
		c:box('Coping', V(w / 2 - sw / 2 - 0.25, roof + 4.2, -1.1), V(w / 2 + sw / 2 + 0.25, roof + 4.7, 0.5), P.cream, M.SmoothPlastic)
	end
	-- the shop, at the front or at the back of the arcade
	local g = c:at(CFrame.new(0, 0, -rec))
	local dl = o.doorLeft
	local gx0, gx1 = dl and 6.2 or 1.4, dl and w - 1.4 or w - 6.2
	local dx = dl and 1.2 or w - 5.4
	g:box('ShopBase', V(gx0 - 0.4, 0, 0), V(gx1 + 0.4, 1.1, 0.35), trim, M.SmoothPlastic)
	decor(g:box('ShopGlass', V(gx0, 1.1, 0), V(gx1, 7.6, 0.3), P.glass, M.SmoothPlastic)).Reflectance = 0.15
	if gx1 - gx0 > 9 then decor(g:box('ShopMullion', V((gx0 + gx1) / 2 - 0.2, 1.1, 0), V((gx0 + gx1) / 2 + 0.2, 7.6, 0.42), trim, M.SmoothPlastic)) end
	g:box('ShopDoorFrame', V(dx, 0, 0), V(dx + 4.2, 8.2, 0.3), trim, M.SmoothPlastic)
	decor(g:box('ShopDoor', V(dx + 0.5, 0, 0), V(dx + 3.7, 7.6, 0.45), P.glass, M.SmoothPlastic))
	g:box('ShopBand', V(0, 8.2, 0), V(w, 9.4, 0.4), trim, M.SmoothPlastic)
	local sign
	if rec > 0 then
		if o.sign then sign = c:box('ShopSign', V(0.3, 11.3, 0), V(w - 0.3, 12.9, 0.35), o.signColor, M.SmoothPlastic) end
	else
		if o.stripes then stripedAwning(c, 1.2, w - 1.2, 9.4, o.stripes, o.awningDepth, o.stripe) end
		if o.sign then sign = Street.fascia(c, w, o.signColor) end
		decor(c:box('Cornice', V(-0.2, 12.5, 0), V(w + 0.2, 13.1, 0.8), P.cream, M.SmoothPlastic))
	end
	if sign then line(surface(sign, Enum.NormalId.Back, 20), 'Text', o.sign, o.textColor or P.white, FONT.loud, 0.12, 0.76, o.signColor:Lerp(P.black, 0.6), 3) end
	-- upstairs: one wide window per bay
	local n = o.bays or math.max(1, math.floor(w / 9))
	for f = 2, floors do
		local y0 = 13 + (f - 2) * 9 + 2.4
		for k = 1, n do
			local cx, hw = w * (k - 0.5) / n, math.min(w / n / 2 - 1.6, 3.2)
			decor(c:box('WindowFrame', V(cx - hw - 0.4, y0 - 0.4, 0), V(cx + hw + 0.4, y0 + 4.6, 0.25), P.cream, M.SmoothPlastic))
			decor(c:box('Glass', V(cx - hw, y0, 0), V(cx + hw, y0 + 4.2, 0.32), P.glass, M.SmoothPlastic)).Reflectance = 0.15
		end
	end
	if o.pole then Street.barberPole(c, V(dl and 0.9 or w - 0.9, 2, 1.2)) end
	model:SetAttribute('Floors', floors)
	return c, model
end
-- The barber's turning pole (the same pole barberShop hangs by its door), standing on p0 in c's frame.
function Street.barberPole(c, p0)
	local pole, poleModel = c:group('BarberPole')
	pole:post('PoleBody', 0.55, 5, p0, P.white, M.SmoothPlastic)
	for k = 0, 4 do
		pole:part('PoleStripe', V(0.35, 1.15, 1.15), CFrame.new(p0 + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(22), 0, 0), k % 2 == 0 and C(208, 74, 66) or P.barberBlue, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, y in { -0.3, 5 } do pole:post('PoleCap', 0.7, 0.4, p0 + V(0, y, 0), P.barberBlue, M.Metal) end
	pole:box('PoleBracket', p0 + V(-0.15, 2.4, -1.2), p0 + V(0.15, 2.7, -0.5), P.iron, M.Metal)
	poleModel:SetAttribute('Spin', 60)
	poleModel:AddTag('HoodMotion')
	poleModel.WorldPivot = c:world(CFrame.new(p0 + V(0, 2.5, 0)))
	return pole
end
-- A small shopping mall (Shop Street's last stage): a wide three-storey block in light render, a tall glazed atrium
-- standing proud of the front over a pair of dark doors, a flat canopy on two posts in front of them, one long ribbon
-- window per floor on each wing, a shop window either side of the doors, a coloured parapet. Facade-local.
-- o: depth, wall, band (the trim colour), atrium (its centre along the facade)
function Street.mall(ctx, w, o)
	o = o or {}
	local c, model = ctx:group('Mall')
	local roof, depth = 31, o.depth or DEPTH
	local wall, band = o.wall or C(228, 226, 222), o.band or C(112, 100, 140)
	c:box('Wall', V(0, -1, -depth), V(w, roof, 0), wall, M.SmoothPlastic)
	c:box('RoofTop', V(0, roof, -depth), V(w, roof + 0.3, -0.9), C(176, 178, 184), M.Concrete)
	c:box('Parapet', V(-0.2, roof, -0.9), V(w + 0.2, roof + 1.6, 0.3), band, M.SmoothPlastic)
	decor(c:box('StringCourse', V(0, 9.8, 0), V(w, 10.6, 0.5), band, M.SmoothPlastic))
	local ax = o.atrium or w / 2
	c:box('AtriumFrame', V(ax - 7.4, 0, 0), V(ax + 7.4, roof + 2.5, 1.6), band, M.SmoothPlastic)
	decor(c:box('AtriumGlass', V(ax - 6.4, 0, 1.6), V(ax + 6.4, roof + 1.5, 1.75), P.glass, M.SmoothPlastic)).Reflectance = 0.2
	for _, y in { 11.5, 21.5 } do decor(c:box('AtriumTransom', V(ax - 6.4, y, 1.6), V(ax + 6.4, y + 0.5, 1.95), wall, M.SmoothPlastic)) end
	decor(c:box('AtriumMullion', V(ax - 0.25, 0, 1.6), V(ax + 0.25, roof + 1.5, 1.95), wall, M.SmoothPlastic))
	c:box('MallDoors', V(ax - 3.4, 0, 1.75), V(ax + 3.4, 8.4, 2.0), C(40, 46, 58), M.SmoothPlastic)
	c:box('Canopy', V(ax - 6, 9.6, 1.6), V(ax + 6, 10.4, 8.0), wall, M.SmoothPlastic)
	decor(c:box('CanopyEdge', V(ax - 6.1, 9.3, 7.6), V(ax + 6.1, 10.6, 8.1), band, M.SmoothPlastic))
	for _, x in { ax - 5.4, ax + 5.4 } do c:box('CanopyPost', V(x - 0.3, 0, 7.2), V(x + 0.3, 9.6, 7.8), P.iron, M.Metal) end
	for _, wing in { { 1.6, ax - 8.4 }, { ax + 8.4, w - 1.6 } } do
		if wing[2] - wing[1] > 3 then
			for _, y in { 13.6, 23.2 } do decor(c:box('Ribbon', V(wing[1], y, 0), V(wing[2], y + 3.6, 0.3), P.glass, M.SmoothPlastic)).Reflectance = 0.15 end
			decor(c:box('ShopGlass', V(wing[1] + 0.6, 1.2, 0), V(wing[2] - 0.6, 7.8, 0.3), P.glass, M.SmoothPlastic)).Reflectance = 0.15
		end
	end
	return c, model
end
-- The five-a-side clubhouse: one storey, white, a team-colour band and a pent roof that rises to the front, a veranda
-- along the front on three posts with a bench under it, a roller shutter (the kit store), a door and a window.
-- Facade-local. o: depth, wall, team (the club's colour)
function Street.clubhouse(ctx, w, o)
	o = o or {}
	local c, model = ctx:group('Clubhouse')
	local depth, h = o.depth or 9, 8
	local wall, team = o.wall or C(236, 236, 230), o.team or C(66, 116, 212)
	c:box('Wall', V(0, -1, -depth), V(w, h, 0), wall, M.SmoothPlastic)
	c:box('Plinth', V(-0.1, -1, -depth - 0.1), V(w + 0.1, 0.9, 0.25), C(150, 152, 158), M.Concrete)
	c:box('TeamBand', V(-0.1, h - 1.6, -depth - 0.1), V(w + 0.1, h, 0.3), team, M.SmoothPlastic)
	c:wedge('Roof', V(w + 1.2, 2.2, depth + 1.4), CFrame.new(w / 2, h + 1.1, -depth / 2 + 0.2), Craft.dark(team), M.SmoothPlastic)
	c:box('Veranda', V(-0.4, h - 0.5, 0.3), V(w + 0.4, h, 4.4), Craft.dark(team), M.SmoothPlastic)
	for _, x in { 0.5, w * 0.46, w - 0.5 } do c:box('VerandaPost', V(x - 0.25, 0, 3.6), V(x + 0.25, h - 0.5, 4.1), wall, M.SmoothPlastic) end
	c:box('ShutterFrame', V(1.6, 0, 0), V(9.4, 6.6, 0.3), C(120, 124, 132), M.Metal)
	c:box('RollShutter', V(2.1, 0, 0.3), V(8.9, 6.1, 0.45), C(170, 174, 182), M.Metal)
	for y = 1.6, 5.2, 1.8 do decor(c:box('DoorSlat', V(2.1, y, 0.45), V(8.9, y + 0.15, 0.52), C(130, 134, 142), M.Metal)) end
	decor(c:box('DoorFrame', V(w - 7.2, 0, 0), V(w - 3.2, 7.4, 0.22), P.cream, M.SmoothPlastic))
	c:box('Door', V(w - 6.7, 0, 0), V(w - 3.7, 6.9, 0.4), team, M.SmoothPlastic)
	decor(c:box('WindowFrame', V(11.6, 2.6, 0), V(w - 9.4, 6.4, 0.22), P.cream, M.SmoothPlastic))
	decor(c:box('Glass', V(12.0, 3.0, 0), V(w - 9.8, 6.0, 0.3), P.glass, M.SmoothPlastic)).Reflectance = 0.15
	c:box('BenchSeat', V(12.4, 1.4, 1.0), V(w - 10.2, 1.75, 2.3), P.wood, M.WoodPlanks)
	for _, x in { 12.8, w - 10.6 } do c:box('BenchLeg', V(x - 0.25, 0, 1.2), V(x + 0.25, 1.4, 2.1), P.iron, M.Metal) end
	return c, model
end
-- A newspaper kiosk: a green hut with a counter hatch to the front (+Z), papers on the counter, a magazine rack on each
-- side, a stepped roof with a lip.
function Street.kiosk(c, cf, color)
	local k = c:at(cf):group('Kiosk')
	local dark = Craft.dark(color)
	k:box('KioskBase', V(-2.4, 0, -2.0), V(2.4, 0.6, 2.0), dark, M.SmoothPlastic)
	k:box('KioskBody', V(-2.2, 0.6, -1.8), V(2.2, 6.6, 1.8), color, M.SmoothPlastic)
	decor(k:box('KioskHatch', V(-1.6, 3.2, 1.8), V(1.6, 5.8, 1.9), C(40, 44, 54), M.SmoothPlastic))
	k:box('KioskCounter', V(-1.9, 2.9, 1.8), V(1.9, 3.2, 2.7), P.cream, M.SmoothPlastic)
	decor(k:box('Papers', V(-1.5, 3.2, 1.95), V(-0.2, 3.65, 2.6), P.white, M.SmoothPlastic))
	decor(k:box('Papers', V(0.2, 3.2, 1.95), V(1.5, 3.5, 2.6), C(232, 228, 210), M.SmoothPlastic))
	for _, s in { -1, 1 } do decor(k:box('MagazineRack', V(s * 2.2, 1.4, -1.3), V(s * 2.45, 4.6, 1.3), s < 0 and C(214, 108, 128) or C(96, 150, 206), M.SmoothPlastic)) end
	k:box('KioskRoof', V(-2.9, 6.6, -2.5), V(2.9, 7.1, 2.5), dark, M.SmoothPlastic)
	k:box('KioskRoof', V(-2.0, 7.1, -1.6), V(2.0, 7.8, 1.6), color, M.SmoothPlastic)
	k:box('KioskRoof', V(-0.9, 7.8, -0.7), V(0.9, 8.3, 0.7), dark, M.SmoothPlastic)
	return k
end
-- ==== S2 kit END ====
---------------------------------------------------------------------------------------------- lobby hall
-- World 1's spawn: the BLOCK RANGE hall, a bright grey warehouse hall (studded walls between slate pillars with
-- white strips, big windows, box trusses with rows of fluorescent bars, a studded grey floor). Brief 9: every place
-- in it reads by its shape and where it stands, with at most one sign each. Brief 10: the middle of the hall is a
-- place too (a plaza round the hub's one landmark), and the floor says who stands where.
--   Spawn: a low pad on a short white walk just inside the exit, facing west down a blue runner that climbs BAY 1's
--     front steps into the lane (the free lane, the first thing to do); the exit to Stage 1 is the big door north.
--   West wall: the 8 shooting ranges as one stepped red terrace, Starter lowest by the exit, Gold highest at the back;
--     at its foot, mid-terrace, a rubber mat with two benches and a water cooler: where you wait for a lane.
--   Middle: the KINGPIN plaza, a paved octagon with the giant gold statue on a red plinth whose low stone ledge all
--     round is a seat (the place to meet), facing north to the spawn and the door.
--   North wall: the stage door in the middle (a glazed transom over it, a small monitor), the fast-travel pad west of
--     it, the locked WORLD 2 arch east of it, a roller loading door in each corner (deliveries on pallets inside the
--     west one; the site office's bins by the east one).
--   East: the site office (a prefab cabin with a window band) and two vending machines by it, the rewards just east
--     of the spawn (the chest and the safe on one low stand, the prize wheel on its own), the ARMORY (builder D)
--     further south with its customers' plank floor in front of the counter.
--   South wall: the sneaker shop (cubby wall of shoe boxes, try-on benches, a counter); the street-ball court with a
--     bench beside it in the south-west; the hall of fame in the south-east (a winners' podium with three players on
--     it, the trophy held high, the two leaderboards as one board on the wall behind them).
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
-- The floor: one studded grey; a short lighter walk (x -SpineW..SpineW) from the stage door to just past the spawn
-- (z N..WalkZ1); the blue runner (z CrossZ ± RunnerW) from the spawn pad west up BAY 1's front steps to the lane's
-- mouth; and three zones, each under the place it serves: the plaza's paving round the statue, the spectators' mat
-- at the terrace's foot, the customers' planks in front of the armory counter. No kerbed panels, no lines.
Lobby.SpineW, Lobby.RunnerW = 7, 4.5
Lobby.WalkZ1 = 40
Lobby.RunnerColor = C(104, 126, 176) -- the spawn top's and BAY 1's blue: "from here to that lane"
-- The KINGPIN plaza in the middle of the hall: the statue's centre, the paving's and the seat ledge's flat-to-flat.
Lobby.Plaza = { X = -4, Z = 92, Paving = 34, Ledge = 20, LedgeH = 1.2 } -- (a little west of the hall's axis: the middle between the terrace's front and the armory's, and the exit door stays in view past it from the sneaker shop's east half)
-- The spectators' spot at the terrace's foot, between the Heavy lane's side stair and Gold's grand stair.
Lobby.Spectators = { X0 = -34, X1 = -24, Z0 = 74, Z1 = 96 }
-- The armory customers' floor: from a few studs out on the hall floor to under the counter's front.
Lobby.CustomerFloor = { X0 = 29, X1 = 41.4, Z0 = 78.2, Z1 = 134.2 }
-- The hall of fame in the south-east: the podium's centre (its front faces north) and the board on the south wall.
Lobby.Fame = { X = 40.5, Z = 147.8 }
-- The lobby's fast-travel pad (FurthestPad): the other way out, west of the stage door, its front to the door's walk.
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
-- A big window on a wall: white outer frame, a navy inner frame with a mullion, very light blue glass. (No glint
-- streak or glowing lamp plate any more: fewer parts, and the lighting pass lights the places, not the walls.)
-- f(u, y, w) maps (along the wall, height, out from the wall) to the map.
function Lobby.window(c, f, u, y0, y1)
	local K = Lobby.Colors
	c:box('WindowFrame', f(u - 5.4, y0 - 0.6, 0), f(u + 5.4, y1 + 0.6, 0.35), K.frame, M.SmoothPlastic)
	c:box('WindowInner', f(u - 4.9, y0, 0.3), f(u + 4.9, y1, 0.45), K.winFrame, M.SmoothPlastic)
	c:box('WindowGlass', f(u - 4.4, y0 + 0.5, 0.4), f(u + 4.4, y1 - 0.5, 0.5), K.winGlass, M.SmoothPlastic)
	local ym = y1 - (y1 - y0) * 0.36
	c:box('WindowMullion', f(u - 4.4, ym - 0.25, 0.4), f(u + 4.4, ym + 0.25, 0.56), K.winFrame, M.SmoothPlastic)
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
-- A hall sign that still reads with every word hidden: a round plate whose pictogram is built from parts (kind
-- 'target': a red and white bullseye; 'gun': a white pistol in profile on a slate disc) and, beside it (toward the
-- sign's local +X, or -X when side is -1), the area's name on a slim pale plate. One per area; nothing glows.
function Lobby.roundelSign(c, name, pos, normal, title, kind, side)
	side = side or 1
	local cf = CFrame.lookAt(pos, pos + normal) -- -Z = into the hall
	local flat = CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's axis along the sign's normal)
	local function disc(n, dia, z0, z1, col)
		return c:part(n, V(z1 - z0, dia, dia), cf * CFrame.new(0, 0, -(z0 + z1) / 2) * flat, col, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local D = 6.4
	if kind == 'target' then
		disc(name, D, 0, 0.4, C(204, 66, 62))
		disc(name .. 'Ring', D * 0.68, 0.4, 0.5, C(244, 244, 246))
		disc(name .. 'Eye', D * 0.34, 0.5, 0.6, C(204, 66, 62))
	else
		disc(name, D, 0, 0.4, C(52, 62, 92))
		local w = C(244, 244, 246)
		c:part(name .. 'Slide', V(3.8, 1.05, 0.2), cf * CFrame.new(0.45, 0.6, -0.5), w, M.SmoothPlastic)
		c:part(name .. 'Grip', V(1.15, 2.3, 0.2), cf * CFrame.new(-0.9, -0.7, -0.5) * CFrame.Angles(0, 0, math.rad(-14)), w, M.SmoothPlastic)
		c:part(name .. 'Guard', V(1.0, 0.28, 0.2), cf * CFrame.new(0.2, -0.45, -0.5), w, M.SmoothPlastic)
	end
	local pw = math.max(8, #title * 1.02 + 1.2)
	Lobby.board(c, name .. 'Plate', cf * CFrame.new(side * (D / 2 + 0.8 + pw / 2), 0, -0.15), pw, 2.6, C(226, 228, 234),
		{ { 'Title', title, C(52, 60, 86), FONT.loud, 0.12, 0.76, P.white, 3 } }, 14)
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
	-- (the south wall's bay at x 40.5 holds the hall of fame's board instead of a window; the north wall gets one
	-- each side of the stage door, so the corners over the loading doors are not one blank wall)
	for _, x in { -55.5, -40.5, 55.5 } do Lobby.window(h, south, x, 14, 27) end
	for _, x in { -31.5, 40.5 } do Lobby.window(h, north, x, 14, 27) end
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
	-- The stage door, the hall's way out to Stage 1: two red pillars and a red header round the 24 x 20 opening; over
	-- the header a glazed transom (the street's daylight shows through it: the door reads by its light, not by a
	-- board) split by two dark mullions, with a small monitor standing on the header between them (STAGE 1 and gate
	-- 1's state, which HoodClient/Stages rewrites); a light cap tying the pillar tops. Gate 1 fills the opening.
	local d = h:group('ExitDoor')
	do
		local red = C(186, 78, 70)
		local dark, trim = red:Lerp(P.black, 0.38), C(238, 236, 232)
		local x1, top = Dw + 3.2, 31
		for _, sx in { -1, 1 } do
			d:box('DoorPillar', V(math.min(sx * Dw, sx * x1), 0, N), V(math.max(sx * Dw, sx * x1), top, N + 2.6), red, M.SmoothPlastic)
		end
		d:box('DoorHeader', V(-Dw, DH, N), V(Dw, DH + 2.6, N + 2.6), red, M.SmoothPlastic)
		local glass = d:box('DoorTransom', V(-Dw, DH + 2.6, N + 0.9), V(Dw, top, N + 1.3), C(196, 226, 246), M.Glass)
		glass.Transparency, glass.CastShadow = 0.45, false
		for _, x in { -6.75, 6.75 } do d:box('TransomMullion', V(x - 0.35, DH + 2.6, N + 0.7), V(x + 0.35, top, N + 1.6), dark, M.SmoothPlastic) end
		d:box('MonitorBezel', V(-6.4, DH + 2.6, N + 1.4), V(6.4, DH + 6.6, N + 2.4), dark, M.SmoothPlastic)
		local screen = d:box('ExitMonitor', V(-6, DH + 2.95, N + 2.4), V(6, DH + 6.25, N + 2.6), C(54, 100, 190), M.SmoothPlastic)
		local sg = surface(screen, Enum.NormalId.Back, 20)
		line(sg, 'Title', 'STAGE 1  •  THE BLOCK', P.white, FONT.loud, 0.06, 0.36, C(14, 26, 70), 2)
		-- (HoodClient/Stages rewrites ExitStatus from gate 1's state: train first / you can go / cleared)
		line(sg, 'ExitStatus', '🎯 TRAIN AT THE RANGE FIRST', C(255, 214, 90), FONT.loud, 0.5, 0.42, C(40, 24, 0), 2)
		d:box('DoorCap', V(-x1 - 0.3, top, N), V(x1 + 0.3, top + 0.8, N + 3), trim, M.SmoothPlastic)
	end
	-- The two big areas' signs on the steel band: a round plate whose pictogram is built from parts (a bullseye, a
	-- pistol), so it still says "range" and "gun shop" with every word hidden, and the name on a slim plate beside it.
	local signs = h:group('WallSigns')
	Lobby.roundelSign(signs, 'RangeSign', V(-W + 2.4, 31.8, 59), V(1, 0, 0), 'SHOOTING RANGE', 'target')
	Lobby.roundelSign(signs, 'ArmorySign', V(W - 2.4, 31.8, Lobby.ArmoryZ - 6), V(-1, 0, 0), 'ARMORY', 'gun', -1)

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
-- The overhead crane at z 126 (under a cross truss, south of the plaza so nothing hangs over the statue), in the
-- structure greys (it is building, not an object): a box-girder bridge hung from the long trusses (its runways) on
-- two end trucks, darker flanges, a trolley parked over the east side. Nothing hangs over the floor.
function Lobby.crane(r)
	local K, H = Lobby.Colors, Lobby.H
	local z, y = 126, 33
	r:box('RoofCraneBridge', V(-40, y - 1, z - 1.2), V(40, y + 1, z + 1.2), K.pillar, M.SmoothPlastic)
	for _, fy in { y - 1.3, y + 1 } do r:box('RoofCraneFlange', V(-40, fy, z - 1.5), V(40, fy + 0.3, z + 1.5), K.pillarDark, M.SmoothPlastic) end
	for _, x in { -40, 40 } do r:box('RoofCraneTruck', V(x - 1.6, y - 1.4, z - 2.2), V(x + 1.6, H - 2.2, z + 2.2), K.truss, M.SmoothPlastic) end
	local tx = 22
	r:box('RoofCraneTrolley', V(tx - 1.6, y - 2.2, z - 1.8), V(tx + 1.6, y - 1, z + 1.8), K.pillarDark, M.SmoothPlastic)
end

---------------------------------------------------------------------------------------------- floor
-- The floor: one studded grey slab; a lighter studded walk 0.12 over it from the stage door to just past the spawn
-- pad (the way out, and no further: south of the spawn the floor is the plaza's); the blue runner, a smooth rubber
-- mat a touch higher, from the spawn pad west to BAY 1's front steps (it carries on up the treads and across the
-- promenade into the lane, Lobby.rangeRow): the first walk, read by its colour (the spawn's and BAY 1's blue) and its
-- straight line, not by arrows. Two zones belong to the places beside them: the spectators' dark rubber mat at the
-- terrace's foot and the customers' warm planks in front of the armory counter (the plaza's paving is laid with the
-- statue). Nothing else is painted on the floor.
Lobby.ShopZ = 138 -- the sneaker shop's wood floor starts here
function Lobby.floorPlan(L)
	local K, N = Lobby.Colors, Lobby.N
	local f = L:group('FloorPlan')
	local sw, rw, z = Lobby.SpineW, Lobby.RunnerW, Lobby.CrossZ
	Lobby.slab(f, 'Walkway', V(-sw, 0, N), V(sw, 0.12, Lobby.WalkZ1), K.walk).CastShadow = false
	local x0 = Lobby.TerraceX + Lobby.Bay1Steps
	f:box('Runner', V(x0, 0, z - rw), V(-sw + 2, 0.16, z + rw), Lobby.RunnerColor, M.SmoothPlastic).CastShadow = false
	local sp, cu = Lobby.Spectators, Lobby.CustomerFloor
	f:box('SpectatorMat', V(sp.X0, 0, sp.Z0), V(sp.X1, 0.08, sp.Z1), C(70, 74, 84), M.SmoothPlastic).CastShadow = false
	f:box('CustomerFloor', V(cu.X0, 0, cu.Z0), V(cu.X1, 0.08, cu.Z1), C(150, 120, 92), M.WoodPlanks).CastShadow = false
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
	-- BAY 1's front steps: straight off the promenade onto the blue runner, as wide as the runner, so the walk from the
	-- spawn ends on them. The runner climbs with you: a strip on every tread and across the promenade to the lane's
	-- mouth (BAY 1's own blue mat starts there), so the one blue line runs from the spawn pad into the free lane.
	local z1, rw = Lobby.RangeZ0, Lobby.RunnerW
	local tr = Lobby.terraceStair(t, 'TerraceStair', XF, XF + Lobby.Bay1Steps, z1 - rw, z1 + rw, rise, 'x', 1)
	local ra, rb = z1 - rw + 0.6, z1 + rw - 0.6
	for k = 1, Lobby.Bay1Steps do
		local hk = rise - k * tr
		t:box('RunnerTread', V(XF + k - 1, hk, ra), V(XF + k - 0.25, hk + 0.05, rb), Lobby.RunnerColor, M.SmoothPlastic).CastShadow = false
	end
	t:box('RunnerTread', V(XS + 0.1, rise, ra), V(XF - 0.25, rise + 0.05, rb), Lobby.RunnerColor, M.SmoothPlastic).CastShadow = false
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
-- The terrace's vertical rhythm: white seams at the tier joints on its front. (No glass stall fins or posts between
-- the lanes any more: each lane carries its own plywood booth partition at the firing line, builder R.) The lanes
-- carry their own small BAY plaques (Stations.plaque) at their entrances; nothing else is written on the terrace.
function Lobby.terraceDressing(t, skins, XS, XF, zN, zS, sz, n, rise)
	local pitch = Lobby.RangePitch
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
	-- the shop's sign: a giant high-top standing side on along the top of the cubby wall (the shop's shape from across
	-- the hall, words or no words) and the name on a slim plate on the wall beside it
	-- (the shoe stands at the west end, the plate at the east end, so from the spawn neither hides behind the statue)
	Lobby.sneaker(d, CFrame.new(-10.2, top + 0.6, S - 1.6) * CFrame.Angles(0, math.rad(90), 0), 3.2, C(222, 58, 66), P.white)
	local scf = CFrame.lookAt(V(8, top + 2.4, S - 0.5), V(8, top + 2.4, 0))
	Lobby.board(d, 'ShoeBoxSign', scf, 11, 2.4, C(236, 232, 226), { { 'Title', 'SHOE BOXES', C(196, 70, 96), FONT.loud, 0.1, 0.8, P.white, 3 } }, 16)
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
-- The rewards just east of the spawn (where you land is where you claim), each turned to face the spawn pad: the
-- LUCKY SHOT prize wheel (four coloured spokes on a white wheel in a gold rim, a pointer on top, turning slowly on
-- an A-frame) on its own round base nearest the pad, and the DAILY CRATE (a red treasure chest with gold bands) and
-- the VIP SAFE (a purple safe with a dial and a handle) on one low studded stand further east. From the spawn's walk
-- WORLD 2's arch stands clear behind them, and from the pad the armory's till (the counter's north end, about 45
-- degrees south of east) shows past their south side. No signs or glow: their shapes say what they are. Decor with
-- "coming soon" prompts.
Lobby.RewardStand = { 23.2, 38.8, 44.4, 55.2 } -- x0, x1, z0, z1 (the chest and the safe)
Lobby.WheelBase = V(19, 0, 44) -- the prize wheel's round base
do
	local face = V(0, 0.6, Lobby.CrossZ) -- (the spawn pad)
	Lobby.RewardAt = {
		DailyCrate = CFrame.lookAt(V(27.6, 0.6, 50.6), face),
		LuckyShot = CFrame.lookAt(V(19, 0.6, 44), face),
		VipSafe = CFrame.lookAt(V(34.8, 0.6, 48.4), face),
	}
end
function Lobby.rewards(L)
	local st = Lobby.RewardStand
	local stand = L:group('RewardStand')
	Lobby.slab(stand, 'RewardStand', V(st[1], 0, st[3]), V(st[2], 0.6, st[4]), C(206, 196, 168))
	Lobby.disc(stand, 'WheelBase', 6.4, 0, 0.6, Lobby.WheelBase.X, Lobby.WheelBase.Z, C(206, 196, 168))
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
	local blue = open and signBlue or signBlue:Lerp(C(150, 152, 160), 0.15) -- (a landmark keeps most of its colour, locked or not)
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

-- The KINGPIN plaza, the middle of the hall: a paved octagon (warm pavers inside a darker kerb ring) round the hub's
-- one landmark, the statue, so the empty floor between the stations is a square with something at its heart: the
-- place to meet, to sit on the plinth's ledge and look at the range, the gun shop and the door. Lobby.Slots.Statue
-- is its centre, facing north (the spawn and the door).
function Lobby.plaza(L, cf, skins)
	local P0 = Lobby.Plaza
	local p = L:at(cf):group('Plaza')
	Lobby.poly(p, 'PlazaKerb', 8, P0.Paving + 1.6, 0, 0.07, C(160, 120, 94))
	for _, q in Lobby.poly(p, 'PlazaPaving', 8, P0.Paving, 0, 0.1, C(200, 158, 122)) do
		studs(q).CastShadow = false
	end
	return Lobby.statue(L, cf, skins)
end
-- The KINGPIN: a giant gold figure (SkinArt's top look: crown, suit, chain) holding a gold deagle high, on a
-- plinth (red block, cream top) on a wide low stone octagon, a ledge to sit on all round, with a warm light. Two-tone
-- gold (suit and a pale shirt, tie and lapels) with a dark face so the eyes and shades read. Falls back to a block
-- figure without SkinArt.
function Lobby.statue(L, cf, skins)
	local K = Lobby.Colors
	local s, model = L:at(cf):group('KingpinStatue')
	-- Three golds (research: one hue, three tones): M for the body, D for the cape, ermine back, tie and shoes,
	-- L for the crown, cuffs, ermine trim, lapels, chain and shirt; the head a touch lighter than the body.
	local head, suit, pale, deep, ink = C(232, 190, 98), C(224, 178, 80), C(246, 216, 140), C(170, 124, 48), C(90, 50, 10)
	-- The plinth: a pale stone octagon seat ledge (sitting height), a red block, a cream top. (No plaque: a giant
	-- gold figure on a plinth reads as the champion without one.)
	local P0 = Lobby.Plaza
	local red, cream = C(184, 96, 92), C(238, 234, 226)
	Lobby.poly(s, 'SeatLedge', 8, P0.Ledge, 0, P0.LedgeH, C(220, 214, 202))
	s:box('Plinth', V(-6.2, P0.LedgeH, -6.2), V(6.2, 3.6, 6.2), red, M.SmoothPlastic)
	s:box('PlinthTop', V(-5.9, 3.6, -5.9), V(5.9, 4.1, 5.9), cream, M.SmoothPlastic)
	local top, scale = 4.1, 4.5
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

-- The hall of fame in the south-east, between the sneaker shop and the armory's end wall: a winners' podium with
-- three players on it (the champion holding the trophy over his head) and, on the wall behind them where a window
-- was, the two live leaderboards as one board: a slate frame under a gold cap, two navy screens side by side (TOP
-- POWER on the left as you face it, TOP CASH on the right). The podium says "ranking" with every word hidden; the
-- board only holds the names.
function Lobby.hallOfFame(L)
	local F, S = Lobby.Fame, Lobby.S
	local boards = L:group('Leaderboards')
	local x0, x1, y0, y1 = F.X - 5.6, F.X + 5.6, 10, 17.4
	local zf = S - 1.15 -- the frame's front face (its back sits on the brick wainscot's cap)
	boards:box('FameBoard', V(x0, y0, zf), V(x1, y1, S - 0.55), C(52, 56, 70), M.SmoothPlastic)
	boards:box('FameBoardCap', V(x0 - 0.3, y1, zf - 0.2), V(x1 + 0.3, y1 + 0.8, S - 0.55), C(226, 186, 84), M.SmoothPlastic)
	for k, e in { { F.X - 2.75, 'TOP CASH', 'CashLeaderboard' }, { F.X + 2.75, 'TOP POWER', 'ServerLeaderboard' } } do
		local cf = CFrame.lookAt(V(e[1], (y0 + y1) / 2, zf - 0.2), V(e[1], (y0 + y1) / 2, 0))
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[2], e[3])
	end
	Lobby.Slots.Podium = CFrame.lookAt(V(F.X, 0, F.Z), V(F.X, 0, 0))
	Lobby.podium(boards, Lobby.Slots.Podium)
	return boards
end
-- One leaderboard screen centred on cf, its face toward cf's look: a navy screen (5.2 x 6.2) with its title on top,
-- the live list under it, and down the list's left edge three small rank chips (gold, silver, bronze) on the rows of
-- the first three names, so the board reads as a ranking even with every word hidden. `live` names the model
-- LobbyService writes into (a TextLabel named TextLabel): ServerLeaderboard (top Power) or CashLeaderboard (top Cash).
function Lobby.leaderboard(L, cf, title, live)
	local b, model = L:at(cf):group(live)
	local w, h = 5.2, 6.2
	local screen = b:box('BoardScreen', V(-w / 2, -h / 2, -0.2), V(w / 2, h / 2, 0.2), C(32, 42, 74), M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 24)
	line(g, 'Title', title, C(255, 214, 90), FONT.loud, 0.03, 0.14, C(40, 24, 0), 2)
	local text = line(g, 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, FONT.body, 0.2, 0.76, P.black, 1)
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Position, text.Size = UDim2.fromScale(0.16, 0.2), UDim2.fromScale(0.8, 0.76)
	-- the chips: the list's lines 3-5 of 7 (two header lines, then the names); the gui's left edge is the part's +X
	local gx = w / 2 - 0.08 * w
	for k, col in { C(236, 192, 74), C(200, 204, 214), C(196, 136, 92) } do
		local gy = 0.2 + (k + 1.5) * 0.76 / 7
		b:box('RankChip', V(gx - 0.26, h / 2 - gy * h - 0.26, -0.26), V(gx + 0.26, h / 2 - gy * h + 0.26, -0.2), col, M.SmoothPlastic)
	end
	return model
end
-- A blocky player (the classic build, 5.2 tall) standing on cf, facing -Z: dark legs, a shirt, yellow head and arms.
-- pose 'champ': both arms straight up, a gold trophy held over the head; 'wave': one arm up; anything else: arms down.
function Lobby.player(c, cf, shirt, pants, pose)
	local f = c:at(cf):group('Winner')
	local skin = C(245, 205, 72)
	for _, x in { -1, 0.05 } do f:box('WinnerLeg', V(x, 0, -0.5), V(x + 0.95, 2, 0.5), pants, M.SmoothPlastic) end
	f:box('WinnerTorso', V(-1, 2, -0.5), V(1, 4, 0.5), shirt, M.SmoothPlastic)
	f:box('WinnerHead', V(-0.6, 4, -0.6), V(0.6, 5.2, 0.6), skin, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local up = pose == 'champ' or (pose == 'wave' and sx > 0)
		local y = up and 4 or 2
		f:box('WinnerArm', V(math.min(sx, sx * 2), y, -0.5), V(math.max(sx, sx * 2), y + 2, 0.5), skin, M.SmoothPlastic)
	end
	if pose == 'champ' then
		local gold = C(236, 192, 74)
		f:box('TrophyBase', V(-0.7, 5.3, -0.7), V(0.7, 5.7, 0.7), C(70, 56, 40), M.SmoothPlastic)
		Lobby.disc(f, 'TrophyCup', 2, 5.7, 7.5, 0, 0, gold)
		f:box('TrophyHandle', V(-1.05, 6.2, -0.2), V(1.05, 6.8, 0.2), gold, M.SmoothPlastic)
	end
	return f
end
-- The winners' podium (local: front toward -Z): three studded blocks, 2-1-3 as you face it, in silver, gold and
-- bronze, each with its player.
function Lobby.podium(L, cf)
	local p = L:at(cf):group('Podium')
	local pants = C(56, 62, 86)
	for _, e in { { 5, 1.8, C(200, 204, 214), C(64, 120, 206), 'wave' }, { 0, 2.6, C(226, 186, 84), C(206, 70, 64), 'champ' }, { -5, 1.2, C(196, 136, 92), C(72, 160, 98), 'clap' } } do
		Lobby.slab(p, 'PodiumStep', V(e[1] - 2.5, 0, -2.2), V(e[1] + 2.5, e[2], 2.2), e[3])
		Lobby.player(p, CFrame.new(e[1], e[2], 0.2), e[4], pants, e[5])
	end
	return p
end

---------------------------------------------------------------------------------------------- hood life
-- The hood in the hall as small groups, each with a reason to be where it is, never on the walks: the street-ball
-- court in the south-west (a bench beside it, a boombox on a milk crate by the bench); deliveries on pallets and a
-- hand truck inside the west loading door; the site office in the north-east (bins and bags beside its side door by
-- the east loading door, two vending machines south of it); the spectators' spot at the terrace's foot (two benches
-- facing the lanes, a water cooler). Kid-friendly: no gang signs, nothing aimed at anyone, only snacks and soda.
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

-- The street-ball court (the south-west corner, south of Gold's grand stair; it has the corner to itself since the
-- statue moved to the plaza): a hoop on the south wall over a full-width painted half court with its key (the
-- south wall's pillars stand in its back edge), a ball by the hoop, BLOCK BALLERS on the brick under the hoop (the
-- court's one piece of writing), and on the court's east side a bench facing it with a boombox on a milk crate.
function Lobby.courtCorner(c)
	local K, T, S = Lobby.Colors, Lobby.Tag, Lobby.S
	local g = c:group('StreetCourt')
	local x0, x1, z0, z1 = -55, -26, 128.6, S - 0.4
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

-- The site office in the north-east: a prefab cabin against the east wall between two pillars (pale panels on a
-- dark kick, a window band and a door to the hall, a flat roof with a lip): the warehouse's own office, not a street
-- shop. Its side door opens north into the corner by the east loading door: two wheelie bins and a pile of bin bags
-- beside it. Two vending machines (a red drinks machine, a blue snack machine) stand against the east wall just
-- south of it: the hall's snack stop, a few steps from the spawn and the rewards.
Lobby.Store = { X0 = 56, Z0 = 22.6, Z1 = 33.6, H = 10 }
Lobby.Vending = { 40.2, 43.8 } -- the machines' centres along the east wall
-- A vending machine (local: front toward -Z, 3.2 wide, 2.6 deep, 7.2 tall): the body in its brand colour, a pale
-- glass front with three rows of goods, a dark coin panel beside it, the pick-up slot low down, a white header band.
function Lobby.vendingMachine(c, cf, body, goods)
	local v = c:at(cf):group('VendingMachine')
	v:box('VendBody', V(-1.6, 0, -1.3), V(1.6, 7.2, 1.3), body, M.SmoothPlastic)
	v:box('VendGlass', V(-1.35, 2.3, -1.42), V(0.55, 6.3, -1.3), C(226, 236, 244), M.SmoothPlastic)
	for k, col in goods do
		local y = 2.55 + (k - 1) * 1.25
		v:box('VendGoods', V(-1.2, y, -1.5), V(0.4, y + 0.7, -1.4), col, M.SmoothPlastic)
	end
	v:box('VendPanel', V(0.75, 3.0, -1.42), V(1.35, 5.9, -1.3), C(52, 56, 64), M.SmoothPlastic)
	v:box('VendSlot', V(-1.2, 0.7, -1.42), V(0.4, 1.6, -1.3), C(36, 38, 44), M.SmoothPlastic)
	v:box('VendHeader', V(-1.6, 6.55, -1.42), V(1.6, 7.2, -1.3), C(244, 244, 246), M.SmoothPlastic)
	return v
end
function Lobby.cornerStore(c)
	local W = Lobby.W
	local st = Lobby.Store
	local x0, z0, z1, ht = st.X0, st.Z0, st.Z1, st.H
	local g = c:group('SiteOffice')
	local panel, kick, trim = C(232, 228, 218), C(70, 84, 104), C(196, 198, 204)
	g:box('OfficeBody', V(x0, 0, z0), V(W, ht, z1), panel, M.SmoothPlastic)
	g:box('OfficeKick', V(x0 - 0.2, 0, z0), V(W, 1.2, z1 + 0.2), kick, M.SmoothPlastic)
	g:box('OfficeRoof', V(x0 - 0.5, ht, z0 - 0.5), V(W, ht + 0.6, z1 + 0.5), trim, M.SmoothPlastic)
	g:box('OfficeWindowFrame', V(x0 - 0.2, 3.2, z0 + 3.8), V(x0, 7.8, z1 - 0.8), kick, M.SmoothPlastic)
	g:box('OfficeWindow', V(x0 - 0.3, 3.5, z0 + 4.1), V(x0 - 0.1, 7.5, z1 - 1.1), C(160, 214, 248), M.SmoothPlastic)
	local zm = (z0 + 4.1 + z1 - 1.1) / 2
	g:box('OfficeMullion', V(x0 - 0.4, 3.5, zm - 0.15), V(x0 - 0.1, 7.5, zm + 0.15), kick, M.SmoothPlastic)
	g:box('OfficeDoor', V(x0 - 0.2, 0, z0 + 0.7), V(x0 + 0.1, 7.6, z0 + 3.1), C(84, 120, 176), M.SmoothPlastic)
	-- the side door into the corner by the loading door, bins and bags beside it
	local sx = x0 + 6.2
	g:box('StoreSideDoor', V(sx - 1.3, 0, z0 - 0.2), V(sx + 1.3, 7.6, z0), C(60, 74, 80), M.SmoothPlastic)
	g:box('StoreSideStep', V(sx - 1.8, 0, z0 - 1.2), V(sx + 1.8, 0.4, z0), C(150, 152, 160), M.SmoothPlastic)
	Lobby.wheelieBin(g, CFrame.new(sx - 4, 0, z0 - 1.9) * CFrame.Angles(0, math.rad(4), 0), C(56, 120, 84))
	Lobby.wheelieBin(g, CFrame.new(sx - 6.7, 0, z0 - 2.2) * CFrame.Angles(0, math.rad(-7), 0), C(60, 84, 140))
	trashBags(g, V(sx + 2.4, 0, z0 - 7))
	-- the vending machines against the wall south of the office, fronts to the hall
	local goods = {
		{ C(204, 62, 58), { C(246, 206, 72), C(84, 168, 232), C(120, 200, 92) } },
		{ C(56, 98, 192), { C(240, 150, 62), C(222, 74, 84), C(250, 222, 96) } },
	}
	for k, z in Lobby.Vending do
		Lobby.vendingMachine(g, CFrame.lookAt(V(W - 1.9, 0, z), V(0, 0, z)), goods[k][1], goods[k][2])
	end
	return g
end

-- The spectators' spot at the terrace's foot, mid-terrace (between the Heavy lane's side stair and Gold's grand
-- stair): a dark rubber mat on the floor (Lobby.floorPlan), two plain benches facing the lanes at different gaps and
-- offsets, and a water cooler at the mat's south end. People waiting for a lane, watching the others shoot.
function Lobby.spectators(c)
	local sp = Lobby.Spectators
	local g = c:group('Spectators')
	bench(g, V(sp.X1 - 4.2, 0, sp.Z0 + 5.6), V(-1, 0, 0))
	bench(g, V(sp.X1 - 5.4, 0, sp.Z0 + 15.8), V(-1, 0, 0))
	-- the water cooler: a white cabinet, a dark tap on its north face, a blue bottle upside down on top
	local x, z = sp.X1 - 2, sp.Z1 - 1.8
	g:box('CoolerBody', V(x - 0.75, 0.08, z - 0.75), V(x + 0.75, 3.1, z + 0.75), C(232, 234, 238), M.SmoothPlastic)
	g:box('CoolerTap', V(x - 0.3, 2.1, z - 0.95), V(x + 0.3, 2.6, z - 0.75), C(52, 56, 64), M.SmoothPlastic)
	Lobby.disc(g, 'CoolerBottle', 1.25, 3.1, 4.9, x, z, C(110, 176, 232))
	return g
end

function Lobby.hood(L)
	local h = L:group('Hood')
	Lobby.courtCorner(h)
	Lobby.deliveries(h)
	Lobby.cornerStore(h)
	Lobby.spectators(h)
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
-- The street face: the hall's landmark from the street, a giant gold deagle turning slowly on a red mast on the roof
-- over the door (a giant bullseye if the gun models aren't there). (No board on the facade: the gun on the roof and
-- the open door with the hall's light in it say what the building is.)
function Lobby.dressing(L)
	local K, N = Lobby.Colors, Lobby.N
	local dr = L:group('Dressing')
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
	'Plaza', 'KingpinStatue', 'Leaderboards', 'Dressing', 'Hood' }
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

---------------------------------------------------------------------------------------------- light anchors
-- Where the lighting pass (builder L) hangs its pools: invisible, non-colliding anchor parts in a LightAnchors folder,
-- each where its light goes, its front (-Z) aimed at what it lights, carrying the light it asks for as attributes:
-- Pool (what it lights), Kind (Spot / Surface / Point), Face (the face a Spot or Surface light uses), Color,
-- Brightness, Range, Angle, Rank (1 = the brightest patch in the hall). No Light instances here: L adds and tunes
-- them (and retires the nine spine PointLights on the RoofLampTubes in Lobby.hall). The ranges' per-bay spots (2-8)
-- belong on R's own parts, BAY 1's included (R's TargetLamp per lane; Lobby.client paints their state).
-- { pool, at, aim, kind, color, brightness, range, angle, rank }
Lobby.LightPools = {
	{ 'ArmoryCounterNorth', V(39.5, 18, 87.5), V(41.5, 3.4, 87.5), 'Spot', C(255, 226, 184), 1.0, 18, 75, 2 },
	{ 'ArmoryCounterMid', V(39.5, 18, 104), V(41.5, 3.4, 104), 'Spot', C(255, 226, 184), 1.0, 18, 75, 2 },
	{ 'ArmoryCounterSouth', V(39.5, 18, 127), V(41.5, 3.4, 127), 'Spot', C(255, 226, 184), 1.0, 18, 75, 2 }, -- (over D's glass case)
	{ 'ArmoryGunWall', V(47.5, 13.4, 106.2), V(49.4, 6, 106.2), 'Surface', C(245, 245, 250), 0.7, 10, 120, 2 },
	{ 'Spawn', V(0, 16, 34), V(0, 0, 34), 'Spot', C(255, 236, 210), 0.9, 18, 70, 3 },
	{ 'Statue', V(Lobby.Plaza.X, 20, Lobby.Plaza.Z - 16), V(Lobby.Plaza.X, 14, Lobby.Plaza.Z), 'Spot', C(255, 222, 160), 1.0, 26, 45, 4 },
	{ 'ShoeCubbies', V(0, 12.4, Lobby.S - 1.6), V(0, 0, Lobby.S - 1.6), 'Surface', C(255, 232, 200), 0.8, 8, 120, 5 },
	{ 'HallOfFame', V(Lobby.Fame.X, 16, Lobby.Fame.Z - 7), V(Lobby.Fame.X, 6, Lobby.Fame.Z), 'Spot', C(255, 226, 184), 0.8, 14, 40, 6 },
	{ 'VendingMachines', V(Lobby.W - 4.2, 4.5, (Lobby.Vending[1] + Lobby.Vending[2]) / 2), V(0, 4.5, (Lobby.Vending[1] + Lobby.Vending[2]) / 2), 'Point', C(235, 245, 255), 0.4, 8, 0, 8 },
	{ 'LoadingDoorWest', V(Lobby.LoadDoors[1], 6, Lobby.N + 0.7), V(Lobby.LoadDoors[1], 6, 40), 'Surface', C(220, 232, 255), 0.5, 10, 120, 9 },
	{ 'LoadingDoorEast', V(Lobby.LoadDoors[2], 6, Lobby.N + 0.7), V(Lobby.LoadDoors[2], 6, 40), 'Surface', C(220, 232, 255), 0.5, 10, 120, 9 },
}
function Lobby.lightAnchors(L)
	local folder = Instance.new('Folder')
	folder.Name = 'LightAnchors'
	folder.Parent = L.parent
	local c = L:into(folder)
	for _, e in Lobby.LightPools do
		local dir = (e[3] - e[2]).Unit
		local up = math.abs(dir.Y) > 0.95 and V(0, 0, -1) or V(0, 1, 0) -- (a light aimed straight down needs another up)
		local p = c:part('LightAnchor_' .. e[1], V(0.4, 0.4, 0.4), CFrame.lookAt(e[2], e[3], up), P.white)
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
		p:SetAttribute('Pool', e[1])
		p:SetAttribute('Kind', e[4])
		p:SetAttribute('Face', 'Front')
		p:SetAttribute('Color', e[5])
		p:SetAttribute('Brightness', e[6])
		p:SetAttribute('Range', e[7])
		p:SetAttribute('Angle', e[8])
		p:SetAttribute('Rank', e[9])
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
	-- the KINGPIN plaza in the middle of the hall, the statue facing north (the spawn and the door)
	Lobby.Slots.Statue = CFrame.lookAt(V(Lobby.Plaza.X, 0, Lobby.Plaza.Z), V(Lobby.Plaza.X, 0, 0))
	Lobby.plaza(L, Lobby.Slots.Statue, skins)
	Lobby.Slots.Spawn = CFrame.new(SPAWN + V(0, Lobby.SpawnTop, 0)) * CFrame.Angles(0, Lobby.SpawnYaw, 0)
	Lobby.Slots.FurthestPad = Lobby.FurthestAt
	for name, cf in Lobby.RewardAt do Lobby.Slots[name] = cf end
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	Lobby.hallOfFame(L)
	Lobby.dressing(L)
	Lobby.hood(L)
	Lobby.guideNodes(L)
	Lobby.lightAnchors(L)
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
-- two short concrete posts, a sliding yard gate (a braced frame on a floor track) shuts the opening. It is cream,
-- not steel (Brief 10): from down the street a shut gate is a pale bar across the dark railing line, an open one a
-- gap. While you're short, a chain and padlock hold it shut. A small dark plaque hangs on its brace with the Power
-- number and your progress.
-- HoodClient/Stages slides the gate open behind the west railing once you have the Power (the chain and padlock
-- drop away, the plaque turns green). The field (Barrier) is what really stops you: it is solid for you while
-- you're short, and invisible until you walk up to a gate you can't pass yet. StageService records the clear and
-- pays the reward.
-- Every gate after the first has a bus stop on its approach side (d_kit's teleportPad: back to spawn, on to your
-- furthest stage), wherever that street has room for it (GATE_STOPS).
local LOOK_NAMES = { 'THE BLOCK', 'SHOP STREET', 'THE COURTS', 'THE APARTMENTS', 'THE YARDS', 'BOSS YARD' }
local BOSS_RED = C(214, 44, 44)
local function lookColor(i) return i > STAGES and BOSS_RED or P.district[lookOf(i)] end
-- Where each gate's bus stop stands (Brief 10: each street puts it where its own plan has room, so it never stands at
-- the same spot twice; agreed with the street builders in brief/out10/notes_streets.md). In the gate's frame: x is
-- the stop's centre, dz how far before the gate line (toward the lobby), yaw turns it (0 faces the approach, 90 faces
-- west, -90 east), y lifts it onto a raised pavement, and bench adds a bench on its outer side (only where the street
-- has none of its own close by). Not nearer than dz 7.1: the cross street's kerb runs at 3.5..4.5.
-- A stage builder may set GATE_STOPS[n] for the gate at its own far end: the stages are built before the gates.
local GATE_STOPS = {
	[2] = { x = 18.5, dz = 7.6, bench = true }, -- the Block: the cross street's east corner
	[3] = { x = -17, dz = 8.6 }, -- the end of the bend, west
	[4] = { x = 11.2, dz = 19, yaw = 90, y = 0.3 }, -- on the east pavement by the park fence, facing the road (gate 4 is in an archway)
	[5] = { x = 13.4, dz = 7.3, bench = true }, -- Shop Street: east, close in
	[6] = { x = -15, dz = 8.8, bench = true }, -- the colonnade's end
	[7] = { x = 21.5, dz = 7.8 }, -- under the viaduct
	[8] = { x = 19, dz = 8.2, bench = true }, -- the Courts: the houses' side (the cage fills the park side)
	[9] = { x = -16, dz = 7.4, bench = true }, -- by the skate plaza's houses
	[10] = { x = 16, dz = 9.0 }, -- east, across from the clubhouse
	[11] = { x = 19, dz = 8, bench = true }, -- the Apartments: east (the courtyard and bin store are west)
	[12] = { x = -19, dz = 8.4, bench = true }, -- west (the car park is east)
	[13] = { x = 14, dz = 7.6 }, -- east, past the tower's lawn (the tree's ring bench is close)
	[14] = { x = 23.5, dz = 8, bench = true }, -- the Yards: by the yard fence's end, out past the floodlight's foot
	[15] = { x = -22, dz = 8.8 }, -- in front of the boiler house
	[16] = { x = 20, dz = 7.6 }, -- just outside the funnel's mouth to the boss yard
}
-- The bus stop: one short pole with two small flags, a boarding spot in front of each (house: back to spawn; fast
-- forward: on to your furthest stage), and the bench if the street wants one.
local function gateStop(g, i)
	local s = GATE_STOPS[i]
	if not s then return end
	local turn = math.pi - math.rad(s.yaw or 0) -- (a stop's front is its -Z; players come from +Z)
	local c = g:at(CFrame.new(s.x, s.y or 0, s.dz) * CFrame.Angles(0, turn, 0))
	teleportPad(c, 'LobbyPad', -2.2, 0, P.padRed, 'Lobby', 'SPAWN', { side = 1 })
	teleportPad(c, 'FurthestPad', 2.2, 0, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE', { side = -1, pole = false })
	if s.bench then
		-- beside the stop on the side away from the middle of the street, facing the same way
		local k = math.abs(math.cos(turn)) > 0.5 and ((math.cos(turn) * s.x > 0) and 1 or -1) or 1
		local a, b = k * 4.6, k * 8.2
		local wood, steel = C(186, 134, 90), C(72, 76, 86)
		c:box('StopBench', V(a, 1.35, -0.7), V(b, 1.7, 0.7), wood)
		c:box('StopBench', V(a, 1.7, 0.65), V(b, 3.0, 0.95), wood)
		for _, x in { a + k * 0.3, b - k * 0.3 } do c:box('StopBenchLeg', V(x - 0.15, 0, -0.6), V(x + 0.15, 1.35, 0.6), steel) end
	end
end
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
	-- (on the west side none stands where the open gate's plaque parks, x -18.3..-14.1).
	for _, side in { { -1, { 21.0, 27.6, 34.1 } }, { 1, { 15.0, 23.6, 34.1 } } } do
		local s = side[1]
		local a0, a1 = math.min(s * (PX + 0.9), s * 34.4), math.max(s * (PX + 0.9), s * 34.4)
		g:box('GateFooting', V(a0, 0, -0.6), V(a1, 0.5, 0.6), concrete)
		g:box('GateRail', V(a0, 1.8, -0.15), V(a1, 2.1, 0.15), steel)
		g:box('GateRail', V(a0, 3.3, -0.2), V(a1, 3.7, 0.2), steel)
		for _, px in side[2] do g:box('GateRailPost', V(s * px - 0.25, 0.5, -0.25), V(s * px + 0.25, 3.7, 0.25), steel) end
	end
	-- The sliding gate, shut: a cream frame with a diagonal brace and two pickets, on the stage side of the posts.
	-- Everything in GateSlide moves with it (the client slides the model by the gate's SlideOffset).
	local sg = g:group('GateSlide')
	local ZB, ZF = -1.55, -1.05 -- its back face and its approach face
	local x0, x1 = -OW - 0.6, OW + 0.4
	sg:box('GateSlideFrame', V(x0, 0.35, ZB), V(x1, 0.85, ZF), cap)
	sg:box('GateSlideFrame', V(x0, 4.6, ZB), V(x1, 5.1, ZF), cap)
	for _, x in { x0, x1 - 0.6 } do sg:box('GateSlideFrame', V(x, 0.85, ZB), V(x + 0.6, 4.6, ZF), cap) end
	sg:bar('GateSlideBrace', V(x0 + 0.6, 0.85, ZB + 0.25), V(x1 - 0.6, 4.6, ZB + 0.25), 0.4, cap, M.SmoothPlastic)
	for _, x in { -5.1, 5.1 } do sg:box('GateSlidePicket', V(x - 0.2, 0.85, ZB + 0.08), V(x + 0.2, 4.6, ZF - 0.08), cap) end
	-- The plaque hung on the brace (4.2 x 2.4, Brief 10: no longer the biggest thing on the gate): the Power number
	-- and, under it, your progress (the client sizes Fill and writes Count and Status).
	local plaque = sg:box('GatePlaque', V(-2.1, 1.7, ZF), V(2.1, 4.1, ZF + 0.12), C(48, 52, 62))
	local pg = surface(plaque, Enum.NormalId.Back, 40)
	pcall(function() pg.MaxDistance = i == 1 and 220 or 100 end) -- (gate 1 reads through the warehouse door)
	line(pg, 'Power', '💪 ' .. compact(req), P.white, FONT.loud, 0.06, 0.52, ink, 3)
	line(pg, 'Status', '', P.white, FONT.loud, 0.62, 0.28, ink, 2)
	local track = Instance.new('Frame')
	track.Name = 'Track'
	track.BorderSizePixel, track.BackgroundColor3, track.BackgroundTransparency, track.ZIndex = 0, P.white, 0.6, 1
	track.Position, track.Size = UDim2.fromScale(0.1, 0.63), UDim2.fromScale(0.8, 0.26)
	track.Parent = pg
	local fill = Instance.new('Frame')
	fill.Name = 'Fill'
	fill.BorderSizePixel, fill.BackgroundColor3, fill.ZIndex = 0, C(118, 216, 146), 2
	fill.Position, fill.Size = UDim2.fromScale(0.1, 0.63), UDim2.fromScale(0, 0.26)
	fill.Parent = pg
	local count = line(pg, 'Count', '0 / ' .. compact(req), P.white, FONT.loud, 0.645, 0.23, ink, 2)
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
	gateStop(g, i)
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
	-- (No fight ring any more: the user removed the street rings on 2026-10-08. The street and its gate are the stage.)
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
	if Street.custom[i] then return (i == 2 and Street.bend or i == 3 and Street.deadEnd or Street.block)(ctx, i) end
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
	if Street.custom[i] then return ({ Street.shops, Street.arcade, Street.trucks })[trioOf(i)](ctx, i) end
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
	if Street.custom[i] then return ({ Street.courts, Street.skate, Street.fives })[trioOf(i)](ctx, i) end
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
	if Street.custom[i] then return Street.apartments(ctx, i) end
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
	if Street.custom[i] then return Street.yards(ctx, i) end
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
-- The stage group. No fight ring (the user removed the 15 street rings on 2026-10-08: the street and its gate are the
-- stage) and no district banner: the street itself says where you are. Grass fills in behind the set-back buildings
-- (just under any paving laid over it), so no hole shows from a high camera.
function Street.core(ctx, i)
	local d = ctx:group('Stage' .. i)
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
	-- (The pole stops under the blade, which sits on a small cap on top: critic 9 r1 item 10, the pole no longer
	-- cuts through the name.)
	c:post('SignPole', 0.2, 9.0, pos, P.iron, M.Metal)
	c:box('SignPoleCap', pos + V(-0.35, 9.0, -0.2), pos + V(0.35, 9.2, 0.2), P.iron, M.Metal)
	local blade = c:box('StreetName', pos + V(-2.8, 9.2, -0.12), pos + V(2.8, 10.3, 0.12), green, M.SmoothPlastic)
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
	Street.walkup(Street.lot(d, -1, 23, Z(-8), 15), 15, { floors = 4, bays = 2, doorBay = 2, noUnit = true, cornice = true })
	Street.walkup(Street.lot(d, -1, 27, Z(-23), 17), 17, { floors = 3, bays = 3, doorBay = 3, wall = P.brickDark, noUnit = true, cornice = true })
	local store = Street.cornerStore(Street.lot(d, -1, 21, Z(-40), 14), 14)
	Street.waterTower(store, 10, roofOf(2) + 1.2, -5.5) -- (on the low store, near its street corner, so it shows at the end of the street)
	Street.walkup(Street.lot(d, 1, 20, Z(-8), 20), 20, { floors = 3, bays = 3, doorBay = 2, wall = P.brickPink, noUnit = true, cornice = true })
	-- (the tall one stands 3 forward of its neighbour, so its side door and the bins show down the alley)
	Street.walkup(Street.lot(d, 1, 17, Z(-35), 17.4), 17.4, { floors = 4, bays = 2, doorBay = 1, noUnit = true, cornice = true })
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
	-- At the kerb: two parked cars, a hydrant, two lamps where they're needed (by a stoop, at
	-- the alley mouth), one street tree in the deeper front of the middle walk-up, the bike rack by the store.
	car(d, CFrame.new(-11.6, 0, Z(-14.5)) * CFrame.Angles(0, math.pi, 0), C(86, 112, 146))
	car(d, CFrame.new(6.3, 0, Z(-46)), C(228, 228, 232))
	Street.hydrant(d, V(10.3, 0.3, Z(-24)))
	lantern(d, V(-15.5, 0.3, Z(-22.5)))
	lantern(d, V(10.5, 0.3, Z(-37)))
	tree(d, V(-23.6, 0.3, Z(-29.5)), 31, 0.85)
	Street.bikeRack(d, CFrame.new(-18.2, 0.3, Z(-45.5)) * CFrame.Angles(0, math.pi / 2, 0), C(70, 120, 190))
	-- The district's one street sign, at the corner where you turn into the Block from the warehouse door (critic 9 r1
	-- item 10: off the store's green awning, so it isn't green on green).
	Street.nameSign(d, V(9.8, 0.3, Z(-7.8)), 'THE BLOCK')
	-- The cross streets end at yard walls just past the gate's railing.
	for _, s in { -1, 1 } do
		for _, zz in { { -8, 0 }, { -SLEN, s < 0 and -54 or -52.4 } } do
			d:box('YardWall', V(s * 36, -1, Z(zz[1])), V(s * 37.4, 10, Z(zz[2])), P.brickDark, M.Brick)
			d:box('YardWallCap', V(s * 35.8, 10, Z(zz[1])), V(s * 37.6, 10.6, Z(zz[2])), P.stone, M.Concrete)
		end
	end
	Street.seal(d, top)
end

---------------------------------------------------------------------------------------------- the Block, stages 2 and 3
-- S1, Brief 10: the rest of The Block, from the rollout plan (brief/out9_S/S_rollout.md). The same section as stage 1
-- (an asphalt road between raised pavements, brick walk-ups with stoops at varied setbacks), but each street has its
-- own shape. Stage 2 bends round a laundromat that stands across the axis. Stage 3 is a dead end with a pocket park,
-- closed by a building with the gate to Shop Street in its archway. Each one closes the long view, so nobody looks
-- down a straight line of gates.
Street.custom[2], Street.custom[3] = true, true

-- A laundry cart: a wire basket on a wheeled skid, washing piled in it, a hanging rail at its local -Z side.
function Street.laundryCart(c, cf, load)
	local k = c:at(cf):group('LaundryCart')
	local chrome = C(186, 190, 198)
	k:box('CartSkid', V(-1.3, 0, -0.9), V(1.3, 0.6, 0.9), P.iron, M.Metal) -- (the casters, as one dark block)
	k:box('CartBasket', V(-1.2, 0.6, -0.8), V(1.2, 2.6, 0.8), chrome, M.DiamondPlate)
	k:box('CartLoad', V(-1.0, 2.6, -0.6), V(1.0, 3.0, 0.6), load, M.Fabric)
	for _, x in { -1.2, 1.05 } do k:box('CartPost', V(x, 2.6, -0.95), V(x + 0.15, 4.6, -0.8), chrome, M.Metal) end
	k:box('CartRail', V(-1.2, 4.45, -0.95), V(1.2, 4.6, -0.8), chrome, M.Metal)
end
-- An old sofa put out at the kerb on moving day: a base, a back, two arms. It faces local -Z.
function Street.sofa(c, cf, color)
	local k = c:at(cf):group('Sofa')
	k:box('SofaBase', V(-2.8, 0, -1.2), V(2.8, 1.5, 1.2), color, M.Fabric)
	k:box('SofaBack', V(-2.8, 1.5, 0.4), V(2.8, 3.4, 1.2), color, M.Fabric)
	for _, x in { -2.8, 2.1 } do k:box('SofaArm', V(x, 1.5, -1.2), V(x + 0.7, 2.4, 0.4), color:Lerp(P.black, 0.18), M.Fabric) end
end
-- A wheelie bin, the handle and wheels at its local +Z side.
function Street.wheelieBin(c, cf, color)
	local k = c:at(cf):group('WheelieBin')
	k:box('Bin', V(-0.95, 0.3, -1.0), V(0.95, 3.4, 1.0), color, M.SmoothPlastic)
	k:box('BinLid', V(-1.05, 3.4, -1.1), V(1.05, 3.7, 1.25), Craft.dark(color), M.SmoothPlastic)
	k:box('BinWheels', V(-1.0, 0, 0.45), V(1.0, 0.75, 1.1), P.black, M.SmoothPlastic)
end
-- A pram: a deep body on a dark frame, its hood up at the back (+Z), a push handle. It faces local -Z.
function Street.stroller(c, cf, color)
	local k = c:at(cf):group('Stroller')
	k:box('PramWheels', V(-0.8, 0, -1.0), V(0.8, 0.9, 1.0), P.iron, M.SmoothPlastic)
	k:box('PramBody', V(-0.75, 0.9, -1.0), V(0.75, 2.4, 1.0), color, M.Fabric)
	k:wedge('PramHood', V(1.6, 1.4, 1.3), CFrame.new(0, 3.1, 0.35), color:Lerp(P.black, 0.25), M.Fabric)
	k:bar('PramHandle', V(0, 2.4, 1.0), V(0, 3.9, 1.9), 0.22, P.iron, M.Metal)
end
-- A playground slide: a deck on four posts under a little pitched roof, a ladder up the back (+X), a wide chute down
-- the front (-X). cf: the deck's centre, on the ground.
function Street.slide(c, cf)
	local k = c:at(cf):group('Slide')
	local post, roof, chute = C(70, 110, 170), C(204, 88, 74), C(236, 186, 76)
	for _, x in { -1.6, 1.6 } do for _, z in { -1.6, 1.6 } do k:box('SlidePost', V(x - 0.25, 0, z - 0.25), V(x + 0.25, 9.6, z + 0.25), post, M.SmoothPlastic) end end
	k:box('SlideDeck', V(-1.9, 4.6, -1.9), V(1.9, 5.1, 1.9), P.wood, M.WoodPlanks)
	-- (two wedges back to back make the ridge, along X)
	k:wedge('SlideRoof', V(4.6, 1.7, 2.3), CFrame.new(0, 10.45, 1.15) * CFrame.Angles(0, math.pi, 0), roof, M.SmoothPlastic)
	k:wedge('SlideRoof', V(4.6, 1.7, 2.3), CFrame.new(0, 10.45, -1.15), roof, M.SmoothPlastic)
	plank(k, 'SlideChute', V(-1.9, 4.9, 0), V(-9.6, 0.5, 0), 2.2, 0.3, chute)
	for _, z in { -1.15, 1.15 } do plank(k, 'SlideLip', V(-1.9, 5.3, z), V(-9.6, 0.9, z), 0.25, 0.9, chute:Lerp(P.black, 0.2)) end
	for _, z in { -0.75, 0.75 } do k:bar('LadderRail', V(3.7, 0, z), V(1.9, 5.1, z), 0.25, post, M.SmoothPlastic) end
	for q = 1, 3 do
		local t = q / 4
		k:box('LadderRung', V(3.7 - 1.8 * t - 0.15, 5.1 * t - 0.1, -0.75), V(3.7 - 1.8 * t + 0.15, 5.1 * t + 0.1, 0.75), post, M.SmoothPlastic)
	end
end
-- A swing frame: an A-frame at each end, a top beam along local X, two seats on chains.
function Street.swings(c, cf)
	local k = c:at(cf):group('Swings')
	local frame = C(70, 110, 170)
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2.3, 2.3 } do k:bar('SwingLeg', V(x, 0, z), V(x, 8.3, 0), 0.4, frame, M.SmoothPlastic) end
	end
	k:box('SwingBeam', V(-4.9, 8.0, -0.25), V(4.9, 8.5, 0.25), frame, M.SmoothPlastic)
	for _, x in { -2.3, 2.0 } do
		for _, dx in { -0.7, 0.7 } do decor(k:box('SwingChain', V(x + dx - 0.06, 2.2, -0.06), V(x + dx + 0.06, 8.0, 0.06), P.iron, M.Metal)) end
		k:box('SwingSeat', V(x - 0.9, 1.9, -0.45), V(x + 0.9, 2.2, 0.45), C(204, 88, 74), M.SmoothPlastic)
	end
end
-- A mural painted on a blank wall that faces local +Z: a sun coming up behind a green hill, a few big flat shapes (paint,
-- not a sign). cf: the bottom-left corner of the painted area on the wall; w by h.
function Street.mural(c, cf, w, h)
	local k = c:at(cf):group('Mural')
	-- (the sun and the hills break out past the sky's edges, so it reads as paint on the wall, not a board or a window)
	decor(k:box('MuralSky', V(0, 0, 0), V(w, h, 0.12), C(150, 190, 218), M.SmoothPlastic))
	decor(k:rod('MuralSun', h * 0.22, 0.12, CFrame.new(w * 0.74, h * 0.9, 0.18) * CFrame.Angles(0, math.pi / 2, 0), C(238, 198, 104), M.SmoothPlastic))
	-- (a wedge turned a quarter round lies flat on the wall, tall at its +X end; a pair back to back is a hill)
	local function slope(name, x0, x1, hh, y0, color, z)
		local up = x1 > x0
		local cx = (x0 + x1) / 2
		decor(k:wedge(name, V(0.12, hh, math.abs(x1 - x0)), CFrame.new(cx, y0 + hh / 2, z) * CFrame.Angles(0, up and math.pi / 2 or -math.pi / 2, 0), color, M.SmoothPlastic))
	end
	slope('MuralHill', -3, w * 0.4, h * 0.56, h * 0.16, C(104, 168, 98), 0.24)
	slope('MuralHill', w * 0.86, w * 0.4, h * 0.56, h * 0.16, C(104, 168, 98), 0.24)
	slope('MuralHill', w * 0.48, w + 3, h * 0.34, h * 0.16, C(78, 140, 96), 0.3)
	decor(k:box('MuralGround', V(-3, -1, 0.12), V(w + 3, h * 0.16, 0.36), C(78, 140, 96), M.SmoothPlastic))
end

-- The Block, stage 2 ("the bend"): the street jogs. A one-storey laundromat stands across the axis with its round-door
-- machines facing the gate, so the street ends in it. The road bends west round it, past a vacant lot behind a chain-link
-- fence, then comes back east to the next gate. The groups: laundry carts and a bench outside the laundromat, bins behind
-- its back door, a car with its hood up at the lot's kerb, and an old sofa and boxes put out by the last stoop.
function Street.bend(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Road', V(-FRONT, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.asphalt, M.Asphalt)
	-- Raised pavements, and the kerbs along their road edges (along z at x, or along x at z).
	local function pave(x0, x1, z0, z1)
		d:box('Pavement', V(x0, -1, Z(z0)), V(x1, 0.3, Z(z1)), P.tileA, M.SmoothPlastic)
	end
	local function kerbX(x, z0, z1) d:box('Kerb', V(x - 0.45, -1, Z(z0)), V(x + 0.45, 0.34, Z(z1)), P.kerb, M.Concrete) end
	local function kerbZ(z, x0, x1) d:box('Kerb', V(x0, -1, Z(z) - 0.45), V(x1, 0.34, Z(z) + 0.45), P.kerb, M.Concrete) end
	-- West: in front of the first walk-up (kerb -13), along the lot (kerb -26), in front of the last walk-up (kerb -17).
	pave(-30, -13, -7, -20)
	pave(-34, -26, -20, -42)
	pave(-30, -17, -42, -53)
	kerbX(-13, -7.45, -20)
	kerbX(-26, -20, -42)
	kerbX(-17, -42, -53)
	kerbZ(-20, -26, -13)
	kerbZ(-42, -26, -17)
	-- East: the first walk-up (kerb 11), the laundromat's forecourt and its west side (kerb -6.5), its back, the last
	-- walk-up (kerb 9).
	pave(11, 20, -7, -24)
	pave(-6.5, 17, -20, -24)
	pave(-6.5, -4, -24, -44)
	pave(-6.5, 16, -41, -44)
	pave(9, 18, -44, -54)
	kerbX(11, -7.45, -20)
	kerbZ(-20, -6.95, 11)
	kerbX(-6.5, -20, -44)
	kerbZ(-44, -6.95, 9)
	kerbX(9, -44, -54)
	-- Buildings. West: a tall narrow walk-up, the lot, a walk-up. East: a walk-up, the laundromat across the axis (its
	-- front at z -24, x -4..17), a tall walk-up.
	Street.walkup(Street.lot(d, -1, 19, Z(-8), 12), 12, { floors = 4, bays = 2, doorBay = 1, noUnit = true, wall = P.brickDark, cornice = true })
	Street.walkup(Street.lot(d, -1, 23, Z(-42), 11), 11, { floors = 3, bays = 2, doorBay = 2, noUnit = true, cornice = true })
	Street.walkup(Street.lot(d, 1, 17, Z(-8), 16), 16, { floors = 3, bays = 2, doorBay = 1, noUnit = true, wall = P.brickPink, cornice = true })
	Street.walkup(Street.lot(d, 1, 15, Z(-41), 13), 13, { floors = 4, bays = 2, doorBay = 2, noUnit = true, cornice = true })
	local _, _, fascia = Street.laundromat(d:at(CFrame.new(-4, 0, Z(-24))), 21, { depth = 17, corner = true })
	line(surface(fascia, Enum.NormalId.Back, 20), 'Text', 'LAUNDROMAT', P.white, FONT.loud, 0.14, 0.72, C(20, 40, 60), 3)
	-- The vacant lot: bare ground behind a chain-link fence, weeds and one scrappy tree; the walk-ups' blank side walls
	-- face it.
	d:box('LotGround', V(-60, -1, Z(-42)), V(-32, 0.2, Z(-20)), C(150, 132, 104), M.Ground)
	chainLink(d, V(-32, 0.3, Z(-20.3)), V(-32, 0.3, Z(-41.7)), 7, nil, 0.5)
	for _, w in { { -38, -24, 3.2, 1.4 }, { -45, -37, 2.4, 1.0 } } do d:box('Weeds', V(w[1] - w[3], 0.2, Z(w[2]) - w[3] * 0.7), V(w[1] + w[3], 0.2 + w[4], Z(w[2]) + w[3] * 0.7), P.hedge:Lerp(P.trunk, 0.25), M.Grass) end
	d:box('Trunk', V(-44.4, 0.2, Z(-29.6)), V(-43.4, 9.5, Z(-28.6)), P.trunk, M.Wood)
	d:part('Crown', V(7.5, 5.5, 7.5), CFrame.new(-44, 11.4, Z(-29)) * CFrame.Angles(0, math.rad(30), 0), P.leaf:Lerp(P.leafDark, 0.7), M.SmoothPlastic)
	d:part('Crown', V(5, 4.4, 5), CFrame.new(-45, 13.6, Z(-30)) * CFrame.Angles(math.rad(25), math.rad(10), math.rad(-20)), P.leaf, M.SmoothPlastic)
	-- Outside the laundromat: two carts by the door, a bench under the window. Its back door, with the bins.
	Street.laundryCart(d, CFrame.new(3.2, 0.3, Z(-21.7)) * CFrame.Angles(0, 0.25, 0), C(226, 232, 240))
	Street.laundryCart(d, CFrame.new(6.8, 0.3, Z(-22.3)) * CFrame.Angles(0, -0.15, 0), C(170, 196, 226))
	bench(d, V(12.2, 0.3, Z(-22.4)), V(0, 0, 1))
	d:box('BackDoor', V(4.5, 0.3, Z(-41.15)), V(7.5, 7.6, Z(-40.85)), P.doorDark, M.SmoothPlastic)
	trashCan(d, V(9.4, 0.3, Z(-42.6)))
	trashBags(d, V(1.6, 0.3, Z(-42.7)))
	-- A car with its hood up at the lot's kerb, a toolbox on the pavement by its nose.
	car(d, CFrame.new(-23.3, 0, Z(-31)), C(196, 160, 84))
	d:part('CarHood', V(4.3, 0.25, 3.3), CFrame.new(-23.3, 0, Z(-31)) * CFrame.new(0, 2.7, -1.9) * CFrame.Angles(math.rad(62), 0, 0) * CFrame.new(0, 0, -1.6), C(196, 160, 84), M.SmoothPlastic)
	d:box('Toolbox', V(-28.6, 0.3, Z(-36.4)), V(-27.0, 1.3, Z(-35.6)), C(196, 70, 62), M.SmoothPlastic)
	-- Moving day at the last walk-up: the old sofa and two boxes put out on the pavement beside its stoop.
	Street.sofa(d, CFrame.new(-21.4, 0.3, Z(-45)) * CFrame.Angles(0, -math.pi / 2, 0), C(120, 136, 112))
	d:box('Carton', V(-19.6, 0.3, Z(-42.6)), V(-17.9, 1.8, Z(-44.2)), P.crate:Lerp(P.white, 0.15), M.SmoothPlastic)
	crate(d, CFrame.new(-18.8, 0.3, Z(-46.6)) * CFrame.Angles(0, 0.2, 0), 1.8)
	-- Two lamps where the light is needed: the bend, beside the laundromat, and the last walk-up's stoop.
	lantern(d, V(-5.3, 0.3, Z(-33.6)))
	lantern(d, V(10, 0.3, Z(-51.6)))
	-- The cross streets end at yard walls past the gate's railing.
	for _, s in { -1, 1 } do
		for _, zz in { { -8, 0 }, { -SLEN, s < 0 and -53 or -54 } } do
			d:box('YardWall', V(s * 36, -1, Z(zz[1])), V(s * 37.4, 10.6, Z(zz[2])), P.brickDark, M.Brick)
		end
	end
	Street.seal(d, top)
end

-- The Block, stage 3 ("the dead end"): the last street of the district. The tallest walk-ups on the west; on the east, after
-- one walk-up, a small fenced park with a slide and swings. The road stops at a turning head, and a four-storey building
-- closes the whole end of the street with the gate to Shop Street in its archway (critic 11: a district edge you can
-- see). The park's back is that building's blank end wall, painted with a mural. Groups: a bench and a pram by the park
-- gate, recycling bins by the last stoop.
function Street.deadEnd(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Road', V(-FRONT, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.asphalt, M.Asphalt)
	d:box('Pavement', V(-30, -1, Z(-52)), V(-11, 0.3, Z(-7)), P.tileA, M.SmoothPlastic)
	d:box('Pavement', V(7, -1, Z(-52)), V(16, 0.3, Z(-7)), P.tileA, M.SmoothPlastic)
	d:box('Pavement', V(-11, -1, Z(-62.1)), V(7, 0.3, Z(-46)), P.tileA, M.SmoothPlastic) -- (the turning head and the passage)
	d:box('Kerb', V(-11.45, -1, Z(-46)), V(-10.55, 0.34, Z(-7.45)), P.kerb, M.Concrete)
	d:box('Kerb', V(6.55, -1, Z(-46)), V(7.45, 0.34, Z(-7.45)), P.kerb, M.Concrete)
	d:box('Kerb', V(-11.45, -1, Z(-46.45)), V(7.45, 0.34, Z(-45.55)), P.kerb, M.Concrete)
	-- West: the tallest walk-ups. East: one walk-up, then the park.
	Street.walkup(Street.lot(d, -1, 19, Z(-8), 17), 17, { floors = 5, bays = 2, doorBay = 2, noUnit = true, cornice = true })
	Street.walkup(Street.lot(d, -1, 23, Z(-25), 14), 14, { floors = 4, bays = 2, doorBay = 1, noUnit = true, wall = P.brickDark, cornice = true })
	Street.walkup(Street.lot(d, -1, 20, Z(-39), 13), 13, { floors = 4, bays = 2, doorBay = 2, noUnit = true, wall = P.brickPink, cornice = true })
	Street.walkup(Street.lot(d, 1, 15, Z(-8), 13), 13, { floors = 3, bays = 2, doorBay = 1, noUnit = true, cornice = true })
	-- The building across the end: two wings and a block over the arch (x -8..8, 12 high), a stone surround on the
	-- street side, a lamp in the passage. Its back face stops 1.9 short of the gate's line.
	local z0, z1, AW, AH, PH = Z(-52), Z(-62.1), 8, 12, roofOf(4) -- (back face 1.9 short of the gate line: G's padlock)
	local brick = P.brick:Lerp(P.brickDark, 0.5)
	d:box('ArchWing', V(-48, -1, z1), V(-AW, PH, z0), brick, M.Brick)
	d:box('ArchWing', V(AW, -1, z1), V(46, PH, z0), brick, M.Brick)
	d:box('ArchSpan', V(-AW, AH, z1), V(AW, PH, z0), brick, M.Brick)
	d:box('ArchRoof', V(-48.3, PH, z1 - 0.4), V(46.3, PH + 1.4, z0 + 0.8), P.slate, M.SmoothPlastic)
	d:box('ArchBase', V(-20, -1, z0), V(-AW - 1.3, 1.6, z0 + 0.35), P.stone, M.Concrete)
	d:box('ArchBase', V(AW + 1.3, -1, z0), V(46, 1.6, z0 + 0.35), P.stone, M.Concrete)
	for _, x in { -AW - 1.3, AW } do d:box('ArchJamb', V(x, 0.3, z0), V(x + 1.3, AH, z0 + 0.45), P.stone, M.Concrete) end
	d:box('ArchLintel', V(-AW - 1.3, AH, z0), V(AW + 1.3, AH + 1.7, z0 + 0.45), P.stone, M.Concrete)
	light(d:box('ArchLamp', V(-0.7, AH - 0.5, Z(-57.6)), V(0.7, AH, Z(-56.6)), P.lampGlow, M.Neon), P.lampGlow, 0.8, 14)
	local front, back = d:at(CFrame.new(0, 0, z0)), d:at(CFrame.new(0, 0, z1) * CFrame.Angles(0, math.pi, 0))
	for f = 2, 4 do
		for _, x in { -14, 0 } do window(front, x, storeyY(f) + 3, {}) end
		window(back, 0, storeyY(f) + 3, {})
	end
	for _, x in { -24, 24 } do window(back, x, storeyY(3) + 3, {}) end
	-- The mural on the end wall above the park.
	Street.mural(d, CFrame.new(19.5, 9, z0), 22, 20)
	-- The park: a lawn behind a low green fence with its gate opposite the road, safety surfacing under the slide and
	-- the swings, a tree, a hedge at the back.
	d:box('ParkLawn', V(16, -1, Z(-52)), V(46, 0.4, Z(-21)), P.grass, M.Grass)
	d:box('PlaySurface', V(18.8, 0.4, Z(-49.5)), V(34.5, 0.5, Z(-41)), C(184, 112, 92), M.SmoothPlastic)
	d:box('PlaySurface', V(21, 0.4, Z(-34.5)), V(33, 0.5, Z(-25.5)), C(184, 112, 92), M.SmoothPlastic)
	chainLink(d, V(16.2, 0.3, Z(-21.2)), V(16.2, 0.3, Z(-51.8)), 4.2, { { 3.5, 7.5 } }, 0.55, C(58, 104, 80))
	hedgeZ(d, 44.5, Z(-51.8), Z(-21.2), 2.4)
	Street.slide(d, CFrame.new(29.6, 0.5, Z(-45.2)))
	Street.swings(d, CFrame.new(27, 0.5, Z(-30)))
	tree(d, V(39.6, 0.4, Z(-37)), 33, 0.95)
	-- Beside the park gate (z -24.7..-28.7): a bench facing the play area and a pram parked by it.
	bench(d, V(18.4, 0.4, Z(-32.6)), V(1, 0, 0))
	Street.stroller(d, CFrame.new(18.8, 0.4, Z(-37.4)) * CFrame.Angles(0, math.pi / 2, 0), C(96, 128, 168))
	lantern(d, V(-11.9, 0.3, Z(-36.8)))
	-- Recycling bins by the last stoop.
	Street.wheelieBin(d, CFrame.new(-13.4, 0.3, Z(-41.2)) * CFrame.Angles(0, -math.pi / 2, 0), C(66, 112, 176))
	Street.wheelieBin(d, CFrame.new(-13.4, 0.3, Z(-43.6)) * CFrame.Angles(0, -math.pi / 2, 0), C(70, 140, 92))
	-- Bollards across the turning head: no cars into the passage.
	for _, x in { -6.4, -2.1, 2.1, 6.4 } do d:post('Bollard', 0.35, 3.0, V(x, 0.3, Z(-48.4)), C(64, 66, 74), M.Metal) end
	-- The cross street at the start ends at yard walls past the gate's railing.
	for _, s in { -1, 1 } do d:box('YardWall', V(s * 36, -1, Z(-8)), V(s * 37.4, 10.6, Z(0)), P.brickDark, M.Brick) end
	Street.seal(d, top)
end

-- ==== S2 BEGIN: Shop Street and the Courts, stages 4-9 (builder S2, Brief 10) ====
-- Every stage of the two districts has its own street plan. With the rings gone, each street's centre has its own
-- purpose, and that object also closes the long view down the axis, the walk bending round it (critic 11): the market
-- stalls (4), the clock square with its kiosk (5), the food trucks (6), the big tree at the court gate (7), the quarter
-- pipe (8) and the clubhouse at the end of the pitch (9). A rail viaduct over gate 7 is the edge between the districts.
-- Shop Street (4-6) has its own facade kit (Street.shopfront: low, painted, wide windows, parapets), not the Block's
-- brick walk-ups; the Courts (7-9) are built on one side only, the other side open (park, skate plaza, pitch).
-- In the builders below, Z(z) is relative to the stage's gate line: 0 at this gate, -64 at the next.
for _, k in { 4, 5, 6, 7, 8, 9 } do Street.custom[k] = true end
Street.PAVE, Street.SETTS = C(212, 198, 178), C(190, 174, 154) -- Shop Street's warm paving and its market setts

-- A raised pavement (0.3) with a kerb stone along the street edge, in front of each lot of a one-sided Courts street.
-- s: the side (-1 west, 1 east); segs: { { xFront, z0, z1 } } in map z.
function Street.pavement(d, s, segs, wide)
	wide = wide or 4.5
	for _, g in segs do
		local xa, xb = s * g[1], s * (g[1] - wide)
		d:box('Pavement', V(xa, -1, g[2]), V(xb, 0.3, g[3]), P.tileB, M.SmoothPlastic)
		d:box('Kerb', V(xb - 0.45, -1, g[2]), V(xb + 0.45, 0.34, g[3]), P.kerb, M.Concrete)
	end
end
-- A big plane tree on a stone planter with a wooden seat ledge round it: the Courts' meeting point at the park gate.
function Street.shadeTree(c, pos, seed)
	local r = Random.new(seed)
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber(0, math.pi / 2), 0)):group('ShadeTree')
	t:box('Planter', V(-3, 0, -3), V(3, 1.1, 3), P.stone, M.Concrete)
	t:box('PlanterSeat', V(-3.5, 1.1, -3.5), V(3.5, 1.45, 3.5), P.wood, M.WoodPlanks)
	t:box('Trunk', V(-0.85, 1.45, -0.85), V(0.85, 10.5, 0.85), P.trunk, M.Wood)
	local s = 1.4
	t:part('Crown', V(7, 6.4, 7) * s, CFrame.new(0, 13.4, 0) * CFrame.Angles(0, math.rad(45), 0), P.leaf:Lerp(P.leafDark, r:NextNumber(0, 0.5)), M.SmoothPlastic)
	t:part('Crown', V(6.2, 6.2, 6.2) * s, CFrame.new(1.1, 14.4, -0.8) * CFrame.Angles(math.rad(38), math.rad(20), math.rad(34)), P.leaf:Lerp(P.leafDark, 0.6), M.SmoothPlastic)
	t:part('Crown', V(4.6, 4.6, 4.6) * s, CFrame.new(-0.6, 17.0, 0.4) * CFrame.Angles(math.rad(20), math.rad(60), math.rad(-25)), P.leaf, M.SmoothPlastic)
	return t
end
-- A street clock on a post (the arcade's square): a dark green post on a plinth, a four-faced clock head, a cap.
function Street.streetClock(c, pos)
	local k = c:at(CFrame.new(pos)):group('StreetClock')
	local green, face, ink = C(46, 92, 72), C(244, 240, 228), C(36, 40, 48)
	k:box('ClockPlinth', V(-1, 0, -1), V(1, 1.4, 1), green:Lerp(P.black, 0.25), M.SmoothPlastic)
	k:post('ClockPost', 0.38, 9.4, V(0, 1.4, 0), green, M.Metal)
	k:box('ClockHead', V(-1.4, 10.8, -1.4), V(1.4, 13.6, 1.4), green, M.SmoothPlastic)
	decor(k:box('ClockFace', V(-1.15, 11.05, -1.5), V(1.15, 13.35, 1.5), face, M.SmoothPlastic))
	decor(k:box('ClockFace', V(-1.5, 11.05, -1.15), V(1.5, 13.35, 1.15), face, M.SmoothPlastic))
	decor(k:box('ClockHand', V(-0.09, 12.2, -1.56), V(0.09, 13.0, 1.56), ink, M.SmoothPlastic))
	decor(k:box('ClockHand', V(-0.09, 12.11, -1.56), V(0.75, 12.29, 1.56), ink, M.SmoothPlastic))
	decor(k:box('ClockHand', V(-1.56, 12.2, -0.09), V(1.56, 13.0, 0.09), ink, M.SmoothPlastic))
	decor(k:box('ClockHand', V(-1.56, 12.11, -0.75), V(1.56, 12.29, 0.09), ink, M.SmoothPlastic))
	k:box('ClockCap', V(-1.6, 13.6, -1.6), V(1.6, 14.0, 1.6), green:Lerp(P.black, 0.25), M.SmoothPlastic)
	k:box('ClockCap', V(-0.9, 14.0, -0.9), V(0.9, 14.6, 0.9), green, M.SmoothPlastic)
	k:part('ClockFinial', V(0.8, 0.8, 0.8), CFrame.new(0, 14.95, 0), C(214, 176, 96), M.SmoothPlastic, Enum.PartType.Ball)
	return k
end
-- A food truck: the box van with a serving hatch down its +X side (the flap propped up as an awning, a counter under
-- it) and its dish as a big chunky model on the roof ('burger' or 'drink'), so it reads with no sign.
function Street.foodTruck(c, cf, color, awn, dish)
	Street.boxTruck(c, cf, color)
	local k = c:at(cf):group('FoodTruck')
	decor(k:box('Hatch', V(2.7, 3.4, -1.6), V(2.82, 6.4, 4.8), C(44, 46, 54), M.SmoothPlastic))
	k:box('HatchCounter', V(2.7, 3.2, -1.8), V(3.7, 3.5, 5.0), P.cream, M.SmoothPlastic)
	k:part('HatchFlap', V(2.4, 0.25, 6.8), CFrame.new(3.9, 7.0, 1.6) * CFrame.Angles(0, 0, math.rad(18)), awn, M.SmoothPlastic)
	decor(k:box('RearDoorSeam', V(-0.09, 1.9, 6.5), V(0.09, 8.3, 6.62), C(150, 150, 152), M.SmoothPlastic))
	for _, x in { -2.3, 1.7 } do decor(k:box('TailLight', V(x, 2.0, 6.4), V(x + 0.6, 2.8, 6.6), C(200, 70, 64), M.SmoothPlastic)) end
	local up = CFrame.Angles(0, 0, math.pi / 2) -- (cylinders lie along X; this stands them up)
	if dish == 'burger' then
		for _, l in { { 8.6, 0.9, 2.0, C(222, 160, 84) }, { 9.5, 0.6, 2.25, C(120, 72, 52) }, { 10.1, 0.25, 2.35, C(110, 176, 76) }, { 10.35, 1.0, 2.05, C(222, 160, 84) }, { 11.35, 0.5, 1.4, C(230, 172, 96) } } do
			k:part('Burger', V(l[2], l[3] * 2, l[3] * 2), CFrame.new(0, l[1] + l[2] / 2, 1.6) * up, l[4], M.SmoothPlastic, Enum.PartType.Cylinder)
		end
	else
		k:part('Cup', V(3.4, 2.8, 2.8), CFrame.new(0, 10.3, 1.6) * up, P.white, M.SmoothPlastic, Enum.PartType.Cylinder)
		k:part('CupBand', V(1.1, 2.9, 2.9), CFrame.new(0, 10.4, 1.6) * up, color, M.SmoothPlastic, Enum.PartType.Cylinder)
		k:part('CupLid', V(0.35, 3.1, 3.1), CFrame.new(0, 12.15, 1.6) * up, P.cream, M.SmoothPlastic, Enum.PartType.Cylinder)
		k:bar('Straw', V(0.3, 12.2, 1.4), V(0.9, 14.4, 1.0), 0.3, C(214, 84, 74), M.SmoothPlastic)
	end
	return k
end
-- A picnic table: a plank top, a bench each side, a solid leg frame at each end.
function Street.picnicTable(c, cf)
	local k = c:at(cf):group('PicnicTable')
	k:box('TableTop', V(-2.8, 2.5, -1.2), V(2.8, 2.8, 1.2), P.wood, M.WoodPlanks)
	for _, z in { -2.1, 2.1 } do k:box('TableSeat', V(-2.8, 1.4, z - 0.5), V(2.8, 1.65, z + 0.5), P.wood, M.WoodPlanks) end
	for _, x in { -2.0, 2.0 } do k:box('TableFrame', V(x - 0.2, 0, -2.6), V(x + 0.2, 2.5, 2.6), P.woodDark, M.Wood) end
	return k
end
-- A rail viaduct across the map at a district edge, just on the near side of the gate line z0: steel plate girders on
-- brick piers that stand in the gap between the building lots (|x| 38..43, out of the street), abutments over the lots'
-- backs. Its underside is at 13.6, clear of the gate (6.7) and of the bus stops.
function Street.viaduct(c, z0)
	local v = c:group('Viaduct')
	local steel, deep, brick = C(78, 96, 116), C(56, 66, 80), C(150, 86, 72)
	local zf, zb = z0 + 0.6, z0 + 7.2
	v:box('ViaductDeck', V(-62, 14.2, zf), V(62, 15.4, zb), deep, M.Metal)
	for _, zz in { zf, zb - 0.6 } do v:box('ViaductGirder', V(-62, 13.6, zz), V(62, 18.2, zz + 0.6), steel, M.Metal) end
	for _, x in { -27.5, -15.5, -5, 7, 18.5, 29 } do decor(v:box('GirderRib', V(x - 0.3, 13.6, zb), V(x + 0.3, 18.2, zb + 0.25), deep, M.Metal)) end
	for _, x in { -1.2, 1.2 } do decor(v:box('Rail', V(-62, 15.4, (zf + zb) / 2 + x - 0.15), V(62, 15.75, (zf + zb) / 2 + x + 0.15), P.iron, M.Metal)) end
	for _, s in { -1, 1 } do
		v:box('ViaductPier', V(s * 38, -1, zf + 0.8), V(s * 43, 13.6, zb - 0.8), brick, M.Brick)
		v:box('PierCap', V(s * 37.6, 12.9, zf + 0.4), V(s * 43.4, 13.6, zb - 0.4), P.stone, M.Concrete)
		v:box('Abutment', V(s * 56, -1, zf), V(s * 62.5, 14.2, zb), brick, M.Brick)
	end
	return v
end
-- Skate park pieces in light and mid concrete. A quarter pipe facing local +Z: a two-wedge curve (shallow at the foot,
-- steep at the lip), a deck behind with a metal coping on the lip and a rail along the deck's back. w wide, h high.
Street.RAMP, Street.RAMPSIDE, Street.COPING = C(80, 128, 204), C(72, 82, 102), C(200, 204, 212) -- (painted ramps on a darker frame)
function Street.quarterPipe(c, cf, w, h)
	local k = c:at(cf):group('QuarterPipe')
	local ramp, side = Street.RAMP, Street.RAMPSIDE
	local h1, l1, l2 = h * 0.4, h * 1.15, h * 0.42
	-- (a wedge rises toward its +Z; turned round, these rise toward the back)
	k:wedge('RampFoot', V(w, h1, l1), CFrame.new(0, h1 / 2, -l1 / 2) * CFrame.Angles(0, math.pi, 0), ramp, M.Concrete)
	k:box('RampBody', V(-w / 2, 0, -l1 - l2), V(w / 2, h1, -l1), side, M.Concrete)
	k:wedge('RampLip', V(w, h - h1, l2), CFrame.new(0, h1 + (h - h1) / 2, -l1 - l2 / 2) * CFrame.Angles(0, math.pi, 0), ramp, M.Concrete)
	k:box('RampDeck', V(-w / 2, 0, -l1 - l2 - 2.6), V(w / 2, h, -l1 - l2), side, M.Concrete)
	k:rod('Coping', 0.26, w, CFrame.new(0, h, -l1 - l2), Street.COPING, M.Metal)
	local back = -l1 - l2 - 2.6
	k:box('DeckRail', V(-w / 2, h + 2.6, back), V(w / 2, h + 2.9, back + 0.3), P.iron, M.Metal)
	for _, x in { -w / 2, w / 2 - 0.3 } do k:box('DeckRailPost', V(x, h, back), V(x + 0.3, h + 2.6, back + 0.3), P.iron, M.Metal) end
	return k
end
-- A fun box: a low concrete box with a ramp at each end (along local Z) and a grind rail along one edge.
function Street.funBox(c, cf)
	local k = c:at(cf):group('FunBox')
	local ramp, side = Street.RAMP, Street.RAMPSIDE
	k:box('FunBoxTop', V(-3, 0, -3.5), V(3, 1.8, 3.5), side, M.Concrete)
	k:wedge('FunBoxRamp', V(6, 1.8, 4.5), CFrame.new(0, 0.9, 5.75) * CFrame.Angles(0, math.pi, 0), ramp, M.Concrete)
	k:wedge('FunBoxRamp', V(6, 1.8, 4.5), CFrame.new(0, 0.9, -5.75), ramp, M.Concrete)
	k:rod('GrindRail', 0.2, 7.4, CFrame.new(2.4, 2.35, 0) * CFrame.Angles(0, math.pi / 2, 0), Street.COPING, M.Metal)
	for _, z in { -3.2, 3.2 } do k:box('RailLeg', V(2.3, 1.8, z - 0.1), V(2.5, 2.35, z + 0.1), P.iron, M.Metal) end
	return k
end
-- A five-a-side goal: white posts and bar, a see-through net box behind (local +Z); the mouth faces local -Z.
function Street.goal(c, cf)
	local gl = c:at(cf):group('Goal')
	for _, x in { -4, 4 } do gl:box('GoalPost', V(x - 0.25, 0, -0.25), V(x + 0.25, 5, 0.25), P.white, M.SmoothPlastic) end
	gl:box('GoalBar', V(-4.25, 5, -0.25), V(4.25, 5.5, 0.25), P.white, M.SmoothPlastic)
	local net = gl:box('GoalNet', V(-4, 0.2, 0.3), V(4, 4.9, 3), C(220, 224, 230), M.Fabric)
	net.Transparency = 0.5
	return gl
end
-- A drinking fountain: a stone pillar, a steel bowl, a spout.
function Street.fountain(c, pos)
	local k = c:group('DrinkFountain')
	k:post('FountainPost', 0.5, 3.0, pos, P.stone, M.Concrete)
	k:post('FountainBowl', 0.95, 0.5, pos + V(0, 3.0, 0), C(176, 180, 188), M.Metal)
	k:box('FountainSpout', pos + V(-0.12, 3.5, -0.12), pos + V(0.12, 3.9, 0.12), P.iron, M.Metal)
	return k
end
-- A kick scooter standing along local Z (its stem at -Z).
function Street.kickScooter(c, cf, color)
	local k = c:at(cf):group('KickScooter')
	k:box('ScooterDeck', V(-0.4, 0.35, -1.5), V(0.4, 0.55, 1.4), color, M.SmoothPlastic)
	for _, z in { -1.55, 1.45 } do k:part('ScooterWheel', V(0.3, 0.7, 0.7), CFrame.new(0, 0.35, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	k:bar('ScooterStem', V(0, 0.55, -1.5), V(0, 3.6, -1.75), 0.2, P.iron, M.Metal)
	k:box('ScooterBar', V(-0.9, 3.5, -1.85), V(0.9, 3.75, -1.65), P.iron, M.Metal)
	return k
end
-- A traffic cone: a square foot and a tapering body (two steps), orange with a white band.
function Street.cone(c, pos)
	local orange = C(232, 120, 64)
	c:box('ConeFoot', pos + V(-0.55, 0, -0.55), pos + V(0.55, 0.15, 0.55), orange, M.SmoothPlastic)
	c:post('Cone', 0.36, 0.7, pos + V(0, 0.15, 0), orange, M.SmoothPlastic)
	c:post('ConeTop', 0.22, 0.65, pos + V(0, 0.85, 0), P.white, M.SmoothPlastic)
end

-- Shop Street (stage 4): a wide pedestrian strip, no road, low painted shopfronts at different setbacks under deep
-- striped awnings (the barber on the corner, the fishmonger, the café three storeys by the next gate; the sneaker shop, the
-- grocery set back, the delivery bay, the one-storey ice-cream parlour). The centre is the market: three stalls on
-- darker setts in the middle of the strip, one facing the gate you come in by, one facing each walk, crates between
-- them; the walk splits round it. Café tables in the café's forecourt, the van at the loading door.
function Street.shops(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Paving', V(-42, -1, Z(-SLEN)), V(40, 0, Z(0)), Street.PAVE, M.SmoothPlastic)
	d:box('Frontage', V(-42, -1, Z(-63.5)), V(-29, 0.03, Z(-42.5)), C(192, 176, 156), M.SmoothPlastic) -- (the café's forecourt)
	d:box('MarketSetts', V(-16.5, -1, Z(-44)), V(5.5, 0.02, Z(-20)), Street.SETTS, M.SmoothPlastic)
	-- West: the barber on the corner, the fishmonger, the café set back (three storeys) by the next gate.
	Street.shopfront(Street.lot(d, -1, 36, Z(0), 20), 20, { name = 'Barber', sign = 'BARBER', signColor = P.barberBlue, stripes = { C(208, 74, 66), P.white, C(208, 74, 66), P.white, P.barberBlue }, wall = C(232, 190, 176), stripe = 3, pole = true })
	Street.shopfront(Street.lot(d, -1, 38, Z(-20), 22), 22, { sign = 'FISH', signColor = C(52, 96, 150), stripes = { C(72, 128, 190), P.white }, wall = C(236, 204, 150), stripe = 3.2, step = true, doorLeft = true })
	Street.shopfront(Street.lot(d, -1, 42, Z(-42), 22), 22, { sign = 'CAFE', signColor = C(150, 98, 66), stripes = { C(198, 126, 76), P.cream }, wall = C(232, 214, 186), floors = 3, depth = 24, stripe = 3.2, awningDepth = 6 })
	-- East: the sneaker shop (narrow, three storeys), the grocery set back, the delivery bay, the ice-cream parlour.
	Street.shopfront(Street.lot(d, 1, 36, Z(0), 16), 16, { sign = 'SNEAKERS', signColor = C(44, 48, 58), stripes = { C(58, 62, 72), P.white }, wall = C(184, 204, 190), floors = 3, bays = 2, stripe = 3.2, doorLeft = true })
	grocery(Street.lot(d, 1, 40, Z(-16), 20), 20, { depth = 26, stripe = 3.2, fascia = true, noCrates = true })
	Street.shopfront(Street.lot(d, 1, 36, Z(-50), 14), 14, { sign = 'ICE CREAM', signColor = C(206, 116, 150), stripes = { C(226, 140, 176), P.white }, wall = C(244, 206, 214), floors = 1, step = true, stripe = 3 })
	-- The delivery bay (z -36 to -50): the van backed up to the loading door, a pallet of crates beside it, a hand
	-- truck at the dock.
	d:box('BayFloor', V(36, -1, Z(-50)), V(52, 0.04, Z(-36)), C(168, 170, 176), M.Concrete)
	Street.loadingDock(Street.lot(d, 1, 52, Z(-36), 14), 14, { depth = 14 })
	Street.boxTruck(d, CFrame.new(42.6, 0.04, Z(-43)) * CFrame.Angles(0, math.pi / 2, 0), C(84, 140, 104))
	pallet(d, CFrame.new(44.5, 0.04, Z(-38.4)))
	crate(d, CFrame.new(43.6, 0.84, Z(-38.4)), 2.4)
	crate(d, CFrame.new(45.9, 0.84, Z(-38.2)) * CFrame.Angles(0, 0.25, 0), 2)
	Street.handTruck(d, CFrame.new(48.9, 0.04, Z(-48.6)) * CFrame.Angles(0, -math.pi / 2, 0))
	-- The market: the big stall faces the gate you arrive by, the other two face the walks either side, their stock in
	-- crates between them and a bin at the far corner.
	local red, green, orange = C(204, 84, 72), C(70, 140, 96), C(222, 150, 70)
	Street.stall(d, CFrame.new(-6.6, 0.02, Z(-24.8)), 8, 4.4, { red, P.cream, red, P.cream, red }, { C(214, 76, 64), C(236, 150, 66), C(124, 186, 78), C(214, 76, 64) })
	Street.stall(d, CFrame.new(-12.6, 0.02, Z(-36.4)) * CFrame.Angles(0, -math.pi / 2, 0), 6.4, 4, { green, P.cream, green }, { C(236, 204, 90), C(124, 186, 78) })
	Street.stall(d, CFrame.new(1.6, 0.02, Z(-37.6)) * CFrame.Angles(0, math.pi / 2, 0), 5.2, 3.6, { orange, P.cream, orange }, { C(236, 150, 66), C(214, 76, 64), C(236, 204, 90) })
	crate(d, CFrame.new(-6.4, 0.02, Z(-35.8)) * CFrame.Angles(0, 0.2, 0), 2.4)
	crate(d, CFrame.new(-6.2, 2.42, Z(-35.7)) * CFrame.Angles(0, 0.55, 0), 1.9)
	crate(d, CFrame.new(-3.4, 0.02, Z(-39.4)) * CFrame.Angles(0, -0.25, 0), 2.1)
	trashCan(d, V(-10.4, 0.02, Z(-42.6)))
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

-- The arcade (stage 5): the west shops stand behind a colonnade, their upper floors carried over the walk on square
-- cream columns, so that side is a shaded arcade; the east shops are open fronts at three setbacks. The centre is a
-- small square of pale stone a little east of the axis: the street clock, the newspaper kiosk on the axis and one tree.
-- Groups: the kiosk by the clock, bread crates by the bakery's side door, scooters at a rack by the phone shop, a
-- flower stand at the corner florist.
function Street.arcade(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Paving', V(-38, -1, Z(-SLEN)), V(38, 0, Z(0)), Street.PAVE, M.SmoothPlastic)
	d:box('ArcadeFloor', V(-38, -1, Z(-53)), V(-30.6, 0.03, Z(-2)), Street.SETTS, M.SmoothPlastic)
	-- West: the colonnade, three fronts over one row of columns (the columns at an even pitch: it's one building line).
	local W = { { -2, 16, 'BOOKS', C(58, 118, 92), C(234, 214, 160), 2, false }, { -18, 17, 'GIFTS', C(140, 84, 150), C(222, 182, 150), 3, true }, { -35, 18, 'TOYS', C(196, 92, 84), C(236, 222, 196), 2, false } }
	for _, s in W do
		Street.shopfront(Street.lot(d, -1, 31, Z(s[1]), s[2]), s[2], { sign = s[3], signColor = s[4], wall = s[5], floors = s[6], step = s[7], arcade = 7, bays = 2 })
	end
	for _, z in { -3, -10.5, -18, -25.5, -33, -40.5, -48, -52.6 } do
		d:box('Column', V(-32.6, 0, Z(z) - 0.75), V(-31.1, 11, Z(z) + 0.75), P.cream, M.SmoothPlastic)
		d:box('ColumnBase', V(-32.85, 0, Z(z) - 1.0), V(-30.85, 0.7, Z(z) + 1.0), P.stone, M.Concrete)
	end
	-- The corner florist past the colonnade (by the next gate's bus stop), its flower stand out front.
	Street.shopfront(Street.lot(d, -1, 36, Z(-53), 11), 11, { sign = 'FLOWERS', signColor = C(92, 146, 92), stripes = { C(112, 170, 108), P.cream }, wall = C(214, 226, 200), floors = 2, bays = 1, step = true, stripe = 3, doorLeft = true })
	d:box('FlowerStand', V(-35.6, 0, Z(-61.4)), V(-33.2, 1.6, Z(-56.6)), P.wood, M.WoodPlanks)
	for k, col in { C(222, 96, 128), C(240, 200, 84), C(186, 112, 196) } do
		decor(d:box('Flowers', V(-35.4, 1.6, Z(-56.6) - k * 1.55 + 0.1), V(-33.4, 2.5, Z(-56.6) - (k - 1) * 1.55 - 0.1), col, M.SmoothPlastic))
	end
	-- East: the phone shop, the bakery standing forward (its side door and the bread crates face you), the toy shop.
	Street.shopfront(Street.lot(d, 1, 38, Z(0), 18), 18, { sign = 'PHONES', signColor = C(62, 112, 196), stripes = { C(66, 120, 206), P.white }, wall = C(206, 216, 228), floors = 2, stripe = 3, doorLeft = true })
	Street.shopfront(Street.lot(d, 1, 32, Z(-18), 18), 18, { sign = 'BAKERY', signColor = C(150, 104, 70), stripes = { C(210, 140, 78), P.white }, wall = C(236, 204, 150), floors = 2, step = true, stripe = 3.2 })
	Street.shopfront(Street.lot(d, 1, 38, Z(-36), 28), 28, { sign = 'PIZZA', signColor = C(198, 70, 60), stripes = { C(208, 78, 66), P.white }, wall = C(236, 200, 176), floors = 3, bays = 3, stripe = 3.4 })
	-- The bakery's side door (in its north wall, facing the way you come) and its bread crates.
	d:box('SideDoorFrame', V(34.2, 0, Z(-18.25)), V(37.8, 8.2, Z(-17.9)), P.frame, M.SmoothPlastic)
	d:box('SideDoor', V(34.7, 0, Z(-18.1)), V(37.3, 7.6, Z(-17.7)), C(150, 104, 70), M.SmoothPlastic)
	for k, p in { V(32.9, 0, -16.8), V(32.95, 1.0, -16.85), V(32.7, 0, -14.9) } do
		d:box('BreadCrate', V(p.X - 0.9, p.Y, Z(p.Z) - 0.7), V(p.X + 0.9, p.Y + 1.0, Z(p.Z) + 0.7), k == 3 and C(196, 92, 78) or C(70, 120, 186), M.SmoothPlastic)
		decor(d:box('Bread', V(p.X - 0.7, p.Y + 1.0, Z(p.Z) - 0.5), V(p.X + 0.7, p.Y + 1.3, Z(p.Z) + 0.5), C(216, 156, 88), M.SmoothPlastic))
	end
	-- Scooters at a low rack by the phone shop.
	d:box('ScooterRack', V(33.6, 0.9, Z(-12.6)), V(33.9, 1.2, Z(-6.4)), P.iron, M.Metal)
	for _, z in { -12.8, -6.2 } do d:box('ScooterRackLeg', V(33.6, 0, Z(z) - 0.15), V(33.9, 0.9, Z(z) + 0.15), P.iron, M.Metal) end
	Street.kickScooter(d, CFrame.new(32.6, 0, Z(-8.2)) * CFrame.Angles(0, math.pi / 2, 0), C(96, 196, 150))
	Street.kickScooter(d, CFrame.new(32.7, 0, Z(-10.9)) * CFrame.Angles(0, math.pi / 2 + 0.12, 0), C(96, 196, 150))
	-- The clock square: an octagon of pale stone, one step up; the kiosk on the axis facing the way you come, the clock
	-- beside it, a tree behind, a bench facing the kiosk, a bin.
	Craft.octagon(d:at(CFrame.new(5, 0, Z(-38))), 'ClockSquare', 17, -1, 0.25, C(228, 218, 200))
	Street.kiosk(d, CFrame.new(0.6, 0.25, Z(-34.6)), C(58, 112, 84))
	Street.streetClock(d, V(8.6, 0.25, Z(-36.4)))
	tree(d, V(3.4, 0.25, Z(-42.6)), 55, 0.95)
	bench(d, V(11.8, 0.25, Z(-31.8)), V(-1, 0, -0.35))
	trashCan(d, V(-3.4, 0.25, Z(-36.4)))
	lantern(d, V(-29.8, 0, Z(-56.5)))
	lantern(d, V(12.4, 0.25, Z(-43.6)))
	Street.seal(d, top)
end

-- Food trucks (stage 6): the last of Shop Street. Two food trucks park at an angle in the middle of the strip on a patch
-- of setts, hatches to opposite sides, picnic tables in front of each with a bin; gas bottles and crates behind them.
-- West: noodles, the games arcade (three storeys), the deli; east: a small mall with a glazed atrium and a canopy. Past
-- the trucks the strip narrows between two corner shops, and a rail viaduct crosses right over gate 7: the edge of
-- Shop Street and the way into the Courts.
function Street.trucks(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Paving', V(-38, -1, Z(-SLEN)), V(38, 0, Z(0)), Street.PAVE, M.SmoothPlastic)
	d:box('TruckSetts', V(-15, -1, Z(-51)), V(17, 0.02, Z(-13)), Street.SETTS, M.SmoothPlastic)
	-- West.
	Street.shopfront(Street.lot(d, -1, 38, Z(0), 18), 18, { sign = 'NOODLES', signColor = C(204, 104, 56), stripes = { C(222, 128, 70), P.cream }, wall = C(238, 206, 170), floors = 2, step = true, stripe = 3 })
	Street.shopfront(Street.lot(d, -1, 33, Z(-18), 20), 20, { sign = 'ARCADE', signColor = C(118, 76, 188), textColor = C(255, 232, 170), stripes = { C(130, 86, 200), C(240, 228, 196) }, wall = C(214, 206, 226), floors = 3, bays = 2, stripe = 3.2, doorLeft = true })
	Street.shopfront(Street.lot(d, -1, 26, Z(-38), 16), 16, { sign = 'DELI', signColor = C(52, 110, 80), stripes = { C(64, 132, 92), P.cream }, wall = C(220, 230, 204), floors = 1, step = true, stripe = 3.2 })
	-- East: the mall, then the corner shop that narrows the strip.
	Street.mall(Street.lot(d, 1, 36, Z(-2), 36), 36, { atrium = 20 })
	Street.shopfront(Street.lot(d, 1, 22, Z(-38), 14), 14, { sign = 'MUSIC', signColor = C(50, 116, 128), stripes = { C(60, 130, 144), P.white }, wall = C(204, 222, 222), floors = 2, bays = 2, stripe = 3.2, doorLeft = true })
	-- The food court.
	Street.foodTruck(d, CFrame.new(1.4, 0.02, Z(-24)) * CFrame.Angles(0, -0.45, 0), C(196, 82, 70), C(236, 196, 92), 'burger')
	Street.foodTruck(d, CFrame.new(-2.2, 0.02, Z(-42.6)) * CFrame.Angles(0, math.pi + 0.4, 0), C(70, 132, 176), C(240, 238, 232), 'drink')
	Street.picnicTable(d, CFrame.new(11.2, 0.02, Z(-19.5)) * CFrame.Angles(0, 0.12, 0))
	Street.picnicTable(d, CFrame.new(12.6, 0.02, Z(-30.2)) * CFrame.Angles(0, -0.18, 0))
	trashCan(d, V(16.8, 0.02, Z(-25.4)))
	Street.picnicTable(d, CFrame.new(-11.6, 0.02, Z(-38.6)) * CFrame.Angles(0, 0.2, 0))
	Street.picnicTable(d, CFrame.new(-13, 0.02, Z(-47.2)) * CFrame.Angles(0, -0.1, 0))
	trashCan(d, V(-15.6, 0.02, Z(-43.6)))
	for _, p in { V(-4.4, 0.02, -21.6), V(-5.5, 0.02, -23.0) } do d:post('GasBottle', 0.6, 2.6, V(p.X, p.Y, Z(p.Z)), C(196, 92, 78), M.SmoothPlastic) end
	crate(d, CFrame.new(4.6, 0.02, Z(-44.2)) * CFrame.Angles(0, 0.3, 0), 2.4)
	crate(d, CFrame.new(4.9, 0.02, Z(-47.1)) * CFrame.Angles(0, -0.1, 0), 2)
	lantern(d, V(-24.6, 0, Z(-31.5)))
	lantern(d, V(18.6, 0, Z(-46.5)))
	-- The viaduct over gate 7.
	Street.viaduct(d, Z(-SLEN))
	Street.seal(d, top)
end

-- The Courts (stage 7): buildings on the east side only, the west opens into a park, and the park comes to the street
-- (critic 2). The lawn reaches x -6, three street trees stand on its edge, a paved apron runs from the court's gate to
-- the axis with a drinking fountain and the big shade tree with a seat round it (the meeting point, and what closes the
-- view down the street). The court's street-side fence is low, so the court and both hoops read from the street. The
-- middle house stands forward; all three have a raised pavement.
function Street.courts(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Promenade', V(-3, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-4.5)), V(-3, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-SLEN)), V(-3, 0, Z(-59.5)), P.tileA, M.SmoothPlastic)
	d:box('Lawn', V(-FRONT, -1, Z(-59.5)), V(-3, 0.12, Z(-4.5)), P.grass, M.Grass)
	d:box('Lawn', V(-64, -1, Z(-SLEN)), V(-FRONT, 0.12, Z(0)), P.grass, M.Grass)
	for _, e in { { -4.5, -26.5 }, { -45.5, -59.5 } } do d:box('LawnEdge', V(-3.5, -1, Z(e[2])), V(-2.9, 0.25, Z(e[1])), P.kerb, M.Concrete) end
	d:box('Apron', V(-14, -1, Z(-45.5)), V(6, 0.18, Z(-26.5)), P.tileB, M.SmoothPlastic)
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
	-- The cage round it, green-coated and see-through; the run along the street is low (4) so the court shows, its gate
	-- opposite the apron.
	local x0, x1, z0, z1, cage = -42, -14, Z(-56), Z(-12), C(58, 104, 80)
	chainLink(d, V(x0, 0.12, z1), V(x1, 0.12, z1), 8, nil, 0.7, cage)
	chainLink(d, V(x0, 0.12, z0), V(x1, 0.12, z0), 8, nil, 0.7, cage)
	chainLink(d, V(x0, 0.12, z0), V(x0, 0.12, z1), 8, nil, 0.7, cage)
	chainLink(d, V(x1, 0.12, z1), V(x1, 0.12, z0), 4, { { 17, 23 } }, 0.7, cage)
	Street.floodlight(d, V(-44.5, 0.12, Z(-10.5)), V(cx, 0, cz))
	Street.floodlight(d, V(-12.2, 0.12, Z(-58)), V(cx, 0, cz))
	-- Bleachers outside the far sideline; the bench and bin by the court gate; the fountain and the shade tree on the
	-- apron; street trees on the lawn edge at uneven spacing; trees and a tall hedge at the back.
	Street.bleachers(d, CFrame.new(-44.6, 0.12, cz) * CFrame.Angles(0, math.pi / 2, 0), 22)
	bench(d, V(-12.2, 0.18, Z(-39.2)), V(1, 0, 0))
	trashCan(d, V(-12.2, 0.18, Z(-43.6)))
	Street.fountain(d, V(-4.6, 0.18, Z(-29.6)))
	Street.shadeTree(d, V(1.2, 0.18, Z(-38.4)), 77)
	for k, z in { -21.4, -51.2 } do tree(d, V(-8.6, 0.12, Z(z)), 73 + k, 0.82 + k * 0.04) end
	tree(d, V(-55, 0.12, Z(-11)), 71, 1.0)
	tree(d, V(-49, 0.12, Z(-60)), 79, 1.0)
	hedgeZ(d, -62.8, Z(-62), Z(-2), 5)
	-- East: three houses, the middle one standing forward (the street narrows to 28 there), a raised pavement in front.
	tanBuilding(Street.lot(d, 1, 36, Z(0), 20), 20, { floors = 3, balconies = false, noUnit = true })
	brickBuilding(Street.lot(d, 1, 22, Z(-20), 24), 24, { floors = 3, wall = P.brickDark, bays = 3, noUnit = true })
	brickBuilding(Street.lot(d, 1, 36, Z(-44), 20), 20, { floors = 2, wall = P.brick, bays = 3, noUnit = true })
	Street.pavement(d, 1, { { 36, Z(-20), Z(-8) }, { 22, Z(-44), Z(-20) }, { 36, Z(-54), Z(-44) } })
	lantern(d, V(-12.6, 0.18, Z(-27.6)))
	lantern(d, V(19.6, 0.3, Z(-40.5)))
	Street.seal(d, top)
end

-- Skate park (stage 8): the open side swaps to the east. Houses on the west behind a raised pavement (the near corner
-- left as a pocket of grass with a tree); the east is a concrete skate plaza that starts at the axis: a fun box with a
-- grind rail, a kicker, a long quarter pipe along the back, a light mast, and a big quarter pipe across the far end on
-- the axis (the landmark: its curve faces you as you come in). Skateboards on the bench at the plaza's edge, a drinking
-- fountain.
function Street.skate(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Promenade', V(-FRONT, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('SkatePlaza', V(2, -1, Z(-56)), V(64, 0.06, Z(-8)), C(182, 186, 194), M.Concrete)
	d:box('SkatePlaza', V(-7, -1, Z(-56)), V(2, 0.06, Z(-38)), C(182, 186, 194), M.Concrete)
	d:box('Lawn', V(-64, -1, Z(-8)), V(-36, 0.12, Z(0)), P.grass, M.Grass)
	-- West: the houses (forward, back, back again), each with its piece of raised pavement.
	tanBuilding(Street.lot(d, -1, 24, Z(-8), 20), 20, { floors = 3, balconies = false, noUnit = true, wall = P.tan:Lerp(P.tanLight, 0.4), sideAt = 0 })
	brickBuilding(Street.lot(d, -1, 31, Z(-28), 22), 22, { floors = 2, wall = P.brick, bays = 3, noUnit = true })
	tanBuilding(Street.lot(d, -1, 36, Z(-50), 14), 14, { floors = 4, balconies = false, noUnit = true, bays = 2 })
	Street.pavement(d, -1, { { 24, Z(-28), Z(-8) }, { 31, Z(-50), Z(-28) }, { 36, Z(-54), Z(-50) } })
	tree(d, V(-31, 0.12, Z(-5)), 81, 0.9)
	-- The skate plaza.
	Street.quarterPipe(d, CFrame.new(5, 0.06, Z(-39.6)), 22, 7.5)
	Street.quarterPipe(d, CFrame.new(51, 0.06, Z(-31)) * CFrame.Angles(0, -math.pi / 2, 0), 26, 5)
	Street.funBox(d, CFrame.new(15.5, 0.06, Z(-23.5)) * CFrame.Angles(0, 0.08, 0))
	d:box('Ledge', V(25, 0.06, Z(-14.6)), V(38, 1.4, Z(-12.6)), Street.RAMPSIDE, M.Concrete)
	d:box('LedgeEdge', V(24.9, 1.4, Z(-14.7)), V(38.1, 1.6, Z(-12.5)), Street.COPING, M.Metal)
	d:wedge('Kicker', V(5, 1.8, 5.5), CFrame.new(32, 0.96, Z(-34)) * CFrame.Angles(0, math.rad(160), 0), Street.RAMP, M.Concrete)
	Street.floodlight(d, V(46, 0.06, Z(-54.2)), V(28, 0, Z(-30)))
	bench(d, V(3.4, 0.06, Z(-34.4)), V(1, 0, 0))
	for k, col in { C(214, 84, 74), C(72, 128, 206) } do
		d:part('Skateboard', V(0.8, 0.22, 3.0), CFrame.new(2.8 + k * 0.1, 1.86, Z(-34.4 + (k - 1.5) * 2.4)) * CFrame.Angles(0, 0.1 * k, 0), col, M.SmoothPlastic)
	end
	Street.fountain(d, V(3.6, 0.06, Z(-30.5)))
	tree(d, V(58.5, 0.06, Z(-11.5)), 83, 0.95)
	tree(d, V(59, 0.06, Z(-50.5)), 84, 0.85)
	hedgeZ(d, 63.4, Z(-56), Z(-8), 3)
	lantern(d, V(-21, 0.3, Z(-17.5)))
	lantern(d, V(-28.4, 0.3, Z(-44)))
	Street.seal(d, top)
end

-- Five-a-side (stage 9): the west opens again, onto a five-a-side cage right on the walk: its touchline is the street's
-- west edge (white kickboards, dark netting high behind the goals and along the back), its gate in the middle with the
-- team bench and a cooler beside it. Across the far end of the pitch stands the clubhouse (one storey, a pent roof in
-- the club's colour, a veranda, the kit store's roller shutter), its east end just short of the axis, so the gate's
-- middle stays in view; kit bags and cones by its door. Houses on the east behind a raised pavement.
function Street.fives(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	d:box('Promenade', V(-6, -1, Z(-SLEN)), V(FRONT, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-8)), V(-6, 0, Z(0)), P.tileA, M.SmoothPlastic)
	d:box('Promenade', V(-FRONT, -1, Z(-SLEN)), V(-6, 0, Z(-44)), P.tileA, M.SmoothPlastic)
	d:box('Lawn', V(-64, -1, Z(-SLEN)), V(-32, 0.12, Z(-8)), P.grass, M.Grass)
	d:box('Lawn', V(-64, -1, Z(-8)), V(-FRONT, 0.12, Z(0)), P.grass, M.Grass)
	-- The pitch: turf with mown stripes, white lines, kickboards round it (a gate in the street side), goals at the ends.
	local px0, px1, pz0, pz1, turf = -32, -6, Z(-44), Z(-9), C(92, 168, 104)
	d:box('Pitch', V(px0, -1, pz0), V(px1, 0.14, pz1), turf, M.SmoothPlastic)
	for _, z in { -13, -25, -37 } do decor(d:box('PitchStripe', V(px0, 0.14, Z(z) - 3), V(px1, 0.16, Z(z) + 3), C(112, 184, 122), M.SmoothPlastic)) end
	for _, e in { { V(px0 + 1, 0.14, Z(-26.65)), V(px1 - 1, 0.18, Z(-26.35)) }, { V(px0 + 1, 0.14, pz1 - 1.3), V(px1 - 1, 0.18, pz1 - 1) }, { V(px0 + 1, 0.14, pz0 + 1), V(px1 - 1, 0.18, pz0 + 1.3) },
		{ V(px0 + 1, 0.14, pz0 + 1), V(px0 + 1.3, 0.18, pz1 - 1) }, { V(px1 - 1.3, 0.14, pz0 + 1), V(px1 - 1, 0.18, pz1 - 1) } } do
		decor(d:box('PitchLine', e[1], e[2], P.courtLine, M.SmoothPlastic))
	end
	local board = C(236, 236, 232)
	d:box('Kickboard', V(px0, 0, pz1 - 0.4), V(px1, 1.2, pz1), board, M.SmoothPlastic)
	d:box('Kickboard', V(px0, 0, pz0), V(px1, 1.2, pz0 + 0.4), board, M.SmoothPlastic)
	d:box('Kickboard', V(px0, 0, pz0), V(px0 + 0.4, 1.2, pz1), board, M.SmoothPlastic)
	d:box('Kickboard', V(px1 - 0.4, 0, Z(-29.5)), V(px1, 1.2, pz1), board, M.SmoothPlastic)
	d:box('Kickboard', V(px1 - 0.4, 0, pz0), V(px1, 1.2, Z(-24.5)), board, M.SmoothPlastic)
	local net = C(54, 66, 96)
	chainLink(d, V(px0, 1.2, pz1 - 0.2), V(px1, 1.2, pz1 - 0.2), 7, nil, 0.6, net)
	chainLink(d, V(px0, 1.2, pz0 + 0.2), V(px1, 1.2, pz0 + 0.2), 7, nil, 0.6, net)
	chainLink(d, V(px0 + 0.2, 1.2, pz0), V(px0 + 0.2, 1.2, pz1), 7, nil, 0.6, net)
	Street.goal(d, CFrame.new(-19, 0.14, Z(-12.6)))
	Street.goal(d, CFrame.new(-19, 0.14, Z(-40.4)) * CFrame.Angles(0, math.pi, 0))
	d:part('Ball', V(1.4, 1.4, 1.4), CFrame.new(-15.5, 0.84, Z(-30.5)), P.white, M.SmoothPlastic, Enum.PartType.Ball)
	-- The team bench and the cooler by the pitch gate, on the walk side.
	bench(d, V(-3.9, 0, Z(-20.2)), V(-1, 0, 0))
	d:box('Cooler', V(-4.9, 0, Z(-33.6)), V(-3.1, 1.5, Z(-31.4)), C(70, 120, 186), M.SmoothPlastic)
	d:box('CoolerLid', V(-5.0, 1.5, Z(-33.7)), V(-3.0, 1.85, Z(-31.3)), P.white, M.SmoothPlastic)
	-- The clubhouse across the pitch's end, its front to the pitch and the way you come; kit bags and cones by its door.
	Street.clubhouse(d:at(CFrame.lookAt(V(-30, 0, Z(-48.2)), V(-30, 0, Z(-49.2)))), 27, { team = C(66, 116, 212) })
	for k, p in { V(-4.6, 0, -46.9), V(-1.4, 0, -45.3) } do d:blob('KitBag', V(2.6, 1.3, 1.4), V(p.X, 0.65, Z(p.Z)), k == 1 and C(66, 116, 212) or C(40, 46, 58), M.Fabric) end
	Street.cone(d, V(3.6, 0, Z(-50.8)))
	Street.cone(d, V(-9.6, 0, Z(-46.4)))
	tree(d, V(-45.5, 0.12, Z(-17)), 91, 1.0)
	tree(d, V(-51, 0.12, Z(-38.5)), 92, 0.9)
	-- East: three houses (a low corner one, a tall one standing forward, a long one), a raised pavement in front.
	brickBuilding(Street.lot(d, 1, 36, Z(0), 14), 14, { floors = 2, wall = P.brickPink, bays = 2, noUnit = true })
	tanBuilding(Street.lot(d, 1, 27, Z(-14), 24), 24, { floors = 4, balconies = false, noUnit = true })
	brickBuilding(Street.lot(d, 1, 36, Z(-38), 26), 26, { floors = 3, wall = P.brickDark, bays = 3, noUnit = true })
	Street.pavement(d, 1, { { 36, Z(-14), Z(-8) }, { 27, Z(-38), Z(-14) }, { 36, Z(-54), Z(-38) } })
	lantern(d, V(-3.6, 0, Z(-36.5)))
	lantern(d, V(23.4, 0.3, Z(-27)))
	Street.seal(d, top)
end
-- ==== S2 END ====

---------------------------------------------------------------------------------------------- the Apartments and the Yards
-- S3, Brief 10: stages 10-12 (The Apartments) and 13-15 (The Yards) get their own street sections from the rollout plan
-- (brief/out9_S/S_rollout.md), and the end of stage 15 becomes the walk-in to the boss yard.
-- The Apartments: tall, thin slab blocks stand back behind lawns, every flat's balcony in a grid of cross walls; a light
-- estate road runs round something in the middle of each street (a planted median, a parking strip, a garden square).
-- The Yards: no houses at all. Wide dark asphalt, container stacks, high fences, a crane, loading docks and a railway.
-- Each stage has its own landmark and its own centre, and the two district edges close the long view: two tall blocks
-- joined by a sky bridge just past gate 10, and a gantry crane across the yard past gate 13.
-- In the builders below, Z(z) is relative to the stage's gate line, as above. No new top-level locals: everything
-- hangs off Street.
for i = 10, 15 do Street.custom[i] = true end

-- The Apartments' kit. -------------------------------------------------------------------------------------------------
-- An estate slab block: tall and thin. Its flats show as a grid: a cross wall (fin) between every two flats through all
-- floors, a balcony in front of each flat on every upper floor (or one gallery right across), and a glass ribbon behind
-- them. A stair tower stands out of the front with the entrance under a flat canopy and an intercom post by the door.
-- Facade-local like the buildings (+X along the front, +Z out to the street, the block runs back to -depth).
-- o: floors, depth, wall, band (balconies), fin, flats (across), core (x of the stair tower, or nil), coreColor, gallery,
-- accent (a colour, or a list the accents take in turn) and accents ({ {flat, floor}, ... } with a coloured balcony front), dishes ({ {flat, floor}, ... }: a satellite
-- dish on that balcony), back (glass ribbons on the back too), name.
function Street.slab(ctx, w, o)
	local c, model = ctx:group(o.name or 'Slab')
	local floors, dp = o.floors or 5, o.depth or 12
	local roof = roofOf(floors)
	local wall, band = o.wall or P.tanLight, o.band or P.cream
	local fin = o.fin or wall:Lerp(P.black, 0.14)
	local n = o.flats or math.max(2, math.floor(w / 8 + 0.5))
	local accent, pal = {}, type(o.accent) == 'table' and o.accent or { o.accent or P.district[4] }
	for q, a in o.accents or {} do accent[a[1] .. ':' .. a[2]] = pal[(q - 1) % #pal + 1] end
	c:box('Wall', V(0, -1, -dp), V(w, roof, 0), wall, M.SmoothPlastic)
	c:box('Plinth', V(-0.2, -1, 0), V(w + 0.2, 1.2, 0.5), fin, M.Concrete)
	for f = 1, floors do
		local y = storeyY(f)
		decor(c:box('Glass', V(0.6, f == 1 and 1.8 or y + 2.6, 0), V(w - 0.6, f == 1 and 7.6 or y + 7.6, 0.3), P.glass, M.SmoothPlastic))
		if o.back then decor(c:box('Glass', V(0.6, f == 1 and 1.8 or y + 2.6, -dp - 0.3), V(w - 0.6, f == 1 and 7.6 or y + 7.6, -dp), P.glass, M.SmoothPlastic)) end
		if f > 1 then
			if o.gallery then
				c:box('Gallery', V(0.2, y - 0.5, 0), V(w - 0.2, y + 2.6, 2.6), band, M.SmoothPlastic)
			else
				for k = 1, n do
					local col = accent[k .. ':' .. f] or band
					c:box('Balcony', V(w * (k - 1) / n + 0.8, y - 0.5, 0), V(w * k / n - 0.8, y + 2.5, 2.4), col, M.SmoothPlastic)
				end
			end
		end
	end
	-- the cross walls between the flats, up through every floor (the two ends close the balconies off)
	for k = 0, n do
		local x = w * k / n
		c:box('Fin', V(x - 0.4, 0, 0), V(x + 0.4, roof, 3.0), fin, M.SmoothPlastic)
	end
	c:box('RoofCap', V(-0.5, roof, -dp - 0.4), V(w + 0.5, roof + 0.9, 3.2), fin, M.SmoothPlastic)
	for _, dsh in o.dishes or {} do
		local x, y = w * (dsh[1] - 0.5) / n + 1.6, storeyY(dsh[2]) + 3.6
		decor(c:part('Dish', V(0.3, 1.7, 1.7), CFrame.new(x, y, 1.6) * CFrame.Angles(0, -1.2, 0.35), P.frame, M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	if o.core then
		local cx, cc = o.core, o.coreColor or band
		c:box('StairTower', V(cx - 3, -1, 0), V(cx + 3, roof + 3.5, 3.6), cc, M.SmoothPlastic)
		decor(c:box('StairGlass', V(cx - 1, 9.5, 3.6), V(cx + 1, roof + 1.5, 3.85), P.glass, M.SmoothPlastic))
		c:box('Entrance', V(cx - 1.8, 0, 3.6), V(cx + 1.8, 7.4, 3.9), P.glass, M.SmoothPlastic)
		c:box('Canopy', V(cx - 4.6, 8.2, 3.6), V(cx + 4.6, 8.9, 8.2), Craft.dark(cc), M.SmoothPlastic)
		for _, x in { cx - 4.1, cx + 4.1 } do c:box('CanopyPost', V(x - 0.2, 0, 7.4), V(x + 0.2, 8.2, 7.8), P.iron, M.Metal) end
		c:box('Intercom', V(cx + 5.4, 0, 5.4), V(cx + 6.0, 4.2, 6.0), P.iron, M.Metal)
		decor(c:box('IntercomPanel', V(cx + 5.3, 2.8, 5.3), V(cx + 6.1, 3.9, 6.1), C(150, 152, 160), M.SmoothPlastic))
	end
	model:SetAttribute('Floors', floors)
	return c, model
end
-- A tree on open grass (no planter): a trunk under a faceted crown of two turned cubes.
function Street.lawnTree(c, pos, seed, scale)
	local r = Random.new(seed)
	local s = scale or 1
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0)):group('Tree')
	t:box('Trunk', V(-0.55 * s, 0, -0.55 * s), V(0.55 * s, 7 * s, 0.55 * s), P.trunk, M.Wood)
	t:part('Crown', V(6.6, 6, 6.6) * s, CFrame.new(0, 9.6 * s, 0) * CFrame.Angles(0, math.rad(45), 0), P.leaf:Lerp(P.leafDark, r:NextNumber(0, 0.5)), M.SmoothPlastic)
	t:part('Crown', V(4.8, 4.8, 4.8) * s, CFrame.new(0, 12 * s, 0) * CFrame.Angles(math.rad(30), math.rad(50), math.rad(-20)), P.leaf, M.SmoothPlastic)
	return t
end
-- A kerbed island in the middle of an estate road, from corner a to corner b (x and z), its top a lawn or `top`.
function Street.island(c, a, b, top)
	c:box('IslandKerb', V(a.X, -1, a.Z), V(b.X, 0.5, b.Z), P.kerb, M.Concrete)
	c:box(top and 'IslandPaving' or 'IslandLawn', V(a.X + 0.6, 0.5, a.Z + 0.6), V(b.X - 0.6, 0.56, b.Z - 0.6), top or P.grass, top and M.SmoothPlastic or M.Grass)
end
-- The courtyard's climbing frame: a rocket (the old estate playground kind) on three fins over a round rubber mat,
-- portholes up the side that faces local +Z, a slide out of its middle (+X) and a ladder up the back (-X). cf: its foot.
function Street.rocket(c, cf)
	local k = c:at(cf):group('Rocket')
	local red, white, blue, yellow = C(206, 84, 72), P.cream, C(70, 110, 170), C(236, 186, 76)
	k:post('PlayMat', 7, 0.2, V(0, 0, 0), C(72, 150, 196), M.Rubber)
	k:post('RocketBody', 2.2, 10.4, V(0, 2.6, 0), white, M.SmoothPlastic)
	for _, y in { 5.2, 9.6 } do k:post('RocketBand', 2.32, 1.1, V(0, y, 0), red, M.SmoothPlastic) end
	k:post('RocketNose', 1.7, 1.5, V(0, 13.0, 0), red, M.SmoothPlastic)
	k:post('RocketNose', 1.0, 1.4, V(0, 14.5, 0), red, M.SmoothPlastic)
	k:post('RocketNose', 0.4, 1.2, V(0, 15.9, 0), red, M.SmoothPlastic)
	for q = 0, 2 do
		local a = q * math.pi * 2 / 3 + math.pi / 3
		local out = V(math.sin(a), 0, math.cos(a))
		-- (a wedge is tallest at its +Z end: looking outward, its +Z end is at the body)
		k:wedge('RocketFin', V(0.5, 5.6, 2.8), CFrame.lookAt(out * 3.5 + V(0, 2.8, 0), out * 5 + V(0, 2.8, 0)), red, M.SmoothPlastic)
	end
	for _, y in { 7.6, 11.4 } do decor(k:part('Porthole', V(0.3, 1.3, 1.3), CFrame.new(0, y, 2.15) * CFrame.Angles(0, math.pi / 2, 0), P.glass, M.SmoothPlastic, Enum.PartType.Cylinder)) end
	plank(k, 'RocketSlide', V(2.0, 6.6, 0), V(9.2, 0.4, 0), 2.0, 0.3, yellow)
	for _, z in { -1.05, 1.05 } do plank(k, 'RocketSlideLip', V(2.0, 7.0, z), V(9.2, 0.8, z), 0.25, 0.8, yellow:Lerp(P.black, 0.2)) end
	for _, z in { -0.7, 0.7 } do k:bar('RocketLadder', V(-4.6, 0, z), V(-2.1, 6.6, z), 0.3, blue, M.SmoothPlastic) end
	for q = 1, 2 do
		local t = q / 3
		k:box('RocketRung', V(-4.6 + 2.5 * t - 0.15, 6.6 * t - 0.12, -0.7), V(-4.6 + 2.5 * t + 0.15, 6.6 * t + 0.12, 0.7), blue, M.SmoothPlastic)
	end
end
-- A bin store: a low brick enclosure, open at its front (local -Z), with two big communal bins in it, lids shut.
function Street.binStore(c, cf, wall)
	local k = c:at(cf):group('BinStore')
	wall = wall or P.tanDark
	k:box('BinStoreWall', V(-4.6, 0, 1.8), V(4.6, 4.2, 2.4), wall, M.Brick)
	for _, x in { -4.6, 4.0 } do k:box('BinStoreWall', V(x, 0, -2.2), V(x + 0.6, 4.2, 2.4), wall, M.Brick) end
	for q, x in { -1.9, 1.7 } do
		local col = q == 1 and C(70, 112, 92) or C(120, 124, 132)
		k:box('BigBin', V(x - 1.6, 0.4, -1.2), V(x + 1.6, 3.4, 1.4), col, M.SmoothPlastic)
		k:box('BigBinLid', V(x - 1.7, 3.4, -1.3), V(x + 1.7, 3.8, 1.5), Craft.dark(col), M.SmoothPlastic)
	end
end
-- A bike shed by a block's door: a back screen, a flat roof on two front posts, bikes parked nose to the back (+Z), each
-- two wheels and a frame. cf: the middle of its front edge.
function Street.bikeShed(c, cf, colors)
	local k = c:at(cf):group('BikeShed')
	local n = #colors
	local w = n * 2.2 + 1.2
	local steel = C(84, 88, 98)
	k:box('ShedBack', V(-w / 2, 0, 2.6), V(w / 2, 5.0, 2.9), C(160, 164, 172), M.Metal)
	k:box('ShedRoof', V(-w / 2 - 0.3, 5.0, -0.4), V(w / 2 + 0.3, 5.4, 3.1), steel, M.Metal)
	for _, x in { -w / 2 + 0.2, w / 2 - 0.2 } do k:box('ShedPost', V(x - 0.15, 0, -0.2), V(x + 0.15, 5.0, 0.1), steel, M.Metal) end
	for q, col in colors do
		local x = -w / 2 + 0.6 + (q - 0.5) * 2.2
		for _, z in { 0.4, 2.2 } do k:part('BikeWheel', V(0.25, 1.9, 1.9), CFrame.new(x, 0.95, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
		k:box('BikeFrame', V(x - 0.13, 1.2, 0.4), V(x + 0.13, 2.4, 2.2), col, M.SmoothPlastic)
	end
end
-- A car seen from further off (on a deck, across a lot): the body, a glass cabin and the roof, the wheels as two dark
-- blocks. Front toward local -Z. 5 parts.
function Street.carLite(c, cf, color)
	local k = c:at(cf):group('Car')
	for _, z in { -3.3, 3.3 } do k:box('Wheels', V(-2.2, 0, z - 1), V(2.2, 1.9, z + 1), P.black, M.SmoothPlastic) end
	k:box('CarBody', V(-2.3, 0.8, -5.3), V(2.3, 2.6, 5.3), color, M.SmoothPlastic)
	decor(k:box('CarGlass', V(-2.05, 2.6, -2.2), V(2.05, 3.9, 2.8), P.glass, M.SmoothPlastic))
	k:box('CarRoof', V(-2.15, 3.9, -1.9), V(2.15, 4.35, 2.6), color, M.SmoothPlastic)
	return k
end
-- A delivery scooter on its stand by a block's door: two small wheels, the leg shield and handlebars, the seat and a big
-- insulated box on the back. Faces local -Z.
function Street.scooter(c, cf, color)
	local k = c:at(cf):group('Scooter')
	for _, z in { -1.7, 1.5 } do k:part('Wheel', V(0.45, 1.3, 1.3), CFrame.new(0, 0.65, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	k:box('ScooterBody', V(-0.65, 0.7, -0.8), V(0.65, 2.1, 2.0), color, M.SmoothPlastic)
	k:box('ScooterShield', V(-0.55, 0.6, -2.2), V(0.55, 3.5, -1.4), color, M.SmoothPlastic)
	k:box('Handlebar', V(-1.1, 3.5, -2.0), V(1.1, 3.75, -1.7), P.iron, M.Metal)
	k:box('ScooterSeat', V(-0.55, 2.1, -0.2), V(0.55, 2.5, 1.2), P.black, M.SmoothPlastic)
	k:box('DeliveryBox', V(-1.05, 2.5, 1.0), V(1.05, 4.6, 2.7), C(226, 128, 70), M.SmoothPlastic)
end
-- A small greenhouse: a low brick base, glass walls, a pitched glass roof on a white frame (ridge and corner posts), the
-- door at its local +Z end. cf: the middle of its floor; w across (X), d long (Z).
function Street.greenhouse(c, cf, w, d)
	local k = c:at(cf):group('Greenhouse')
	local glass, frame, eave, rh = C(198, 228, 222), P.white, 5.6, 3.0
	k:box('GreenhouseBase', V(-w / 2, 0, -d / 2), V(w / 2, 1.4, d / 2), P.brick, M.Brick)
	local g = k:box('GreenhouseGlass', V(-w / 2 + 0.15, 1.4, -d / 2 + 0.15), V(w / 2 - 0.15, eave, d / 2 - 0.15), glass, M.Glass)
	g.Transparency = 0.35
	for _, s in { -1, 1 } do
		-- (a wedge is tallest at its +Z end; turned so that end meets the ridge)
		local r = k:wedge('GreenhouseRoof', V(d, rh, w / 2), CFrame.new(s * w / 4, eave + rh / 2, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), glass, M.Glass)
		r.Transparency = 0.35
		for _, z in { -d / 2, d / 2 } do k:box('GreenhouseFrame', V(s * w / 2 - 0.2, 1.4, z - 0.2), V(s * w / 2 + 0.2, eave, z + 0.2), frame, M.SmoothPlastic) end
	end
	k:box('GreenhouseRidge', V(-0.25, eave + rh - 0.1, -d / 2 - 0.1), V(0.25, eave + rh + 0.3, d / 2 + 0.1), frame, M.SmoothPlastic)
	k:box('GreenhouseDoor', V(-1.3, 1.4, d / 2 - 0.1), V(1.3, eave, d / 2 + 0.1), frame, M.SmoothPlastic).Transparency = 0.2
	-- tomato plants inside, seen through the glass
	decor(k:box('GreenhousePlants', V(-w / 2 + 0.8, 1.4, -d / 2 + 0.8), V(w / 2 - 0.8, 3.6, d / 2 - 2.4), C(84, 150, 70), M.Grass))
end
-- A raised vegetable bed: a plank box of soil with rows of greens and one row of a crop colour. Long along local X.
function Street.raisedBed(c, cf, w, d, crop)
	local k = c:at(cf):group('RaisedBed')
	k:box('BedFrame', V(-w / 2, 0, -d / 2), V(w / 2, 1.5, d / 2), P.wood, M.WoodPlanks)
	k:box('BedSoil', V(-w / 2 + 0.35, 1.5, -d / 2 + 0.35), V(w / 2 - 0.35, 1.62, d / 2 - 0.35), C(98, 72, 54), M.Ground)
	decor(k:box('BedGreens', V(-w / 2 + 0.7, 1.62, -d / 2 + 0.6), V(w / 2 - 0.7, 2.5, -0.2), C(92, 162, 76), M.Grass))
	decor(k:box('BedCrop', V(-w / 2 + 0.7, 1.62, 0.3), V(w / 2 - 0.7, 2.2, d / 2 - 0.6), crop, M.SmoothPlastic))
end
-- A wheelbarrow with its handles toward local +Z: the tub, the wheel at the front, two legs, a load of soil.
function Street.wheelbarrow(c, cf, color)
	local k = c:at(cf):group('Wheelbarrow')
	k:part('BarrowWheel', V(0.4, 1.4, 1.4), CFrame.new(0, 0.7, -1.6), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
	k:box('BarrowTub', V(-1.1, 1.1, -1.4), V(1.1, 2.3, 1.0), color, M.Metal)
	decor(k:box('BarrowLoad', V(-0.9, 2.3, -1.2), V(0.9, 2.55, 0.8), C(98, 72, 54), M.Ground))
	for _, x in { -0.8, 0.8 } do
		k:bar('BarrowHandle', V(x, 1.4, -1.0), V(x, 2.0, 2.8), 0.2, P.iron, M.Metal)
		k:box('BarrowLeg', V(x - 0.1, 0, 0.6), V(x + 0.1, 1.2, 0.8), P.iron, M.Metal)
	end
end

-- The Yards' kit. ------------------------------------------------------------------------------------------------------
-- The yard's colours. Whole walls of containers and the crane are big surfaces, so the blue, green and the crane's ochre
-- stay under HSV S 0.57; the red boxes and the small machines (forklift amber, reach stacker rust) keep their punch.
Street.yardColors = {
	red = C(198, 92, 74), blue = C(86, 120, 180), green = C(82, 150, 106), cream = C(222, 214, 196), grey = C(140, 146, 156),
	crane = C(206, 168, 92), forklift = C(224, 168, 66), stacker = C(204, 96, 68),
}
-- A stack of shipping containers cheap enough to wall a yard with: each one a coloured box with a darker rim on top
-- (19.6 long along local Z, 8 wide, 8.6 high). With `ridged`, the containers' +X faces get the ribs and corner posts
-- (the side you see from the street). cf: the stack's foot, centred; colors bottom to top.
function Street.stack(c, cf, colors, ridged)
	local k = c:at(cf):group('ContainerStack')
	local H = 8.6
	for q, col in colors do
		local y = (q - 1) * H
		local dark = col:Lerp(P.black, 0.28)
		k:box('ContainerBody', V(-4, y, -9.8), V(4, y + H - 0.35, 9.8), col, M.SmoothPlastic)
		k:box('ContainerRim', V(-4.1, y + H - 0.35, -9.9), V(4.1, y + H, 9.9), dark, M.SmoothPlastic)
		if ridged then
			for z = -6.6, 6.7, 3.3 do k:box('ContainerRidge', V(4, y + 0.4, z - 0.45), V(4.2, y + H - 0.6, z + 0.45), col:Lerp(P.black, 0.14), M.SmoothPlastic) end
			for _, z in { -9.8, 9.2 } do k:box('ContainerCorner', V(3.7, y, z), V(4.25, y + H, z + 0.6), dark, M.SmoothPlastic) end
		end
	end
	return k
end
-- An open container on the ground, its doors swung back toward the street: the box, a dark inside, the two doors, ribs
-- on its long sides, cartons stacked just inside. Its open end faces local +Z. cf: its foot, centred.
function Street.openContainer(c, cf, color)
	local k = c:at(cf):group('OpenContainer')
	local dark = color:Lerp(P.black, 0.28)
	k:box('ContainerBody', V(-4, 0, -9.8), V(4, 8.25, 9.6), color, M.SmoothPlastic)
	k:box('ContainerRim', V(-4.1, 8.25, -9.9), V(4.1, 8.6, 9.9), dark, M.SmoothPlastic)
	decor(k:box('ContainerInside', V(-3.5, 0.3, 9.6), V(3.5, 8.0, 9.75), C(40, 42, 48), M.SmoothPlastic))
	for _, s in { -1, 1 } do
		k:box('ContainerCorner', V(s * 4.2 - 0.35, 0, 9.4), V(s * 4.2 + 0.35, 8.6, 10.0), dark, M.SmoothPlastic)
		-- each door swung right back against the side wall
		k:box('ContainerDoor', V(s * 4.25 - 0.15 + s * 0.2, 0.3, 6.0), V(s * 4.25 + 0.15 + s * 0.2, 8.1, 9.9), dark, M.SmoothPlastic)
		for z = -7.4, 3.0, 3.4 do k:box('ContainerRidge', V(s * 4.05 - 0.1, 0.4, z - 0.45), V(s * 4.05 + 0.1, 7.9, z + 0.45), color:Lerp(P.black, 0.14), M.SmoothPlastic) end
	end
	k:box('Carton', V(-3.2, 0.3, 6.0), V(-0.4, 3.0, 9.0), P.crate, M.Cardboard)
	k:box('Carton', V(-3.0, 3.0, 6.4), V(-0.8, 5.0, 8.8), P.crate:Lerp(P.white, 0.15), M.Cardboard)
	k:box('Carton', V(0.4, 0.3, 4.8), V(3.2, 2.6, 8.2), P.crate, M.Cardboard)
	return k
end
-- A rail-mounted gantry crane: at each end two legs on a bogie sill and a tie near the top, two girders across the top
-- (along local X, from x0 to x1, underside at h), the trolley at hx with the operator's cab under it, and a container
-- hanging from the spreader with its foot at hy. cf: the crane's centre on the ground; the legs stand at z ±5.2.
function Street.gantryCrane(c, cf, x0, x1, h, color, hx, hy, load)
	local k = c:at(cf):group('GantryCrane')
	local dark = Craft.dark(color)
	for _, x in { x0, x1 } do
		k:box('CraneSill', V(x - 1.3, 0, -7), V(x + 1.3, 1.8, 7), dark, M.SmoothPlastic)
		for _, z in { -5.2, 5.2 } do k:box('CraneLeg', V(x - 0.9, 1.8, z - 0.9), V(x + 0.9, h, z + 0.9), color, M.SmoothPlastic) end
		k:box('CraneTie', V(x - 0.7, h - 4.4, -5.2), V(x + 0.7, h - 2.8, 5.2), color, M.SmoothPlastic)
	end
	for _, z in { -5.2, 5.2 } do k:box('CraneGirder', V(x0 - 2.4, h, z - 1.2), V(x1 + 2.4, h + 3.2, z + 1.2), color, M.SmoothPlastic) end
	k:box('CraneTrolley', V(hx - 3.4, h + 3.2, -6.6), V(hx + 3.4, h + 5.4, 6.6), P.cream, M.SmoothPlastic)
	k:box('CraneCab', V(hx + 3.6, h - 4.2, -1.8), V(hx + 7.0, h, 1.8), P.cream, M.SmoothPlastic)
	decor(k:box('CraneCabGlass', V(hx + 3.5, h - 3.6, -1.9), V(hx + 7.1, h - 1.6, 1.9), P.glass, M.SmoothPlastic))
	local sy = hy + 8.6
	for _, z in { -3.4, 3.4 } do decor(k:box('CraneRope', V(hx - 0.12, sy + 1, z - 0.12), V(hx + 0.12, h, z + 0.12), P.iron, M.Metal)) end
	k:box('CraneSpreader', V(hx - 4.2, sy, -10.2), V(hx + 4.2, sy + 1.0, 10.2), dark, M.SmoothPlastic)
	if load then Street.stack(k, CFrame.new(hx, hy, 0), { load }) end
	return k
end
-- A forklift with its forks toward local -Z, carrying a pallet of cartons: the body and counterweight, the seat under an
-- overhead guard, the mast and forks.
function Street.forklift(c, cf, color)
	local k = c:at(cf):group('Forklift')
	for _, z in { -1.3, 1.7 } do k:box('Wheels', V(-1.6, 0, z - 0.7), V(1.6, 1.4, z + 0.7), P.black, M.SmoothPlastic) end
	k:box('ForkliftBody', V(-1.4, 0.6, -1.7), V(1.4, 2.6, 2.4), color, M.SmoothPlastic)
	k:box('Counterweight', V(-1.5, 0.6, 2.2), V(1.5, 3.4, 3.1), Craft.dark(color), M.SmoothPlastic)
	k:box('ForkliftSeat', V(-0.7, 2.6, 0.6), V(0.7, 3.6, 1.7), P.black, M.SmoothPlastic)
	for _, x in { -1.25, 1.25 } do k:box('GuardPost', V(x - 0.12, 2.6, -1.5), V(x + 0.12, 6.1, -1.25), P.iron, M.Metal) end
	k:box('GuardRoof', V(-1.4, 6.1, -1.6), V(1.4, 6.4, 2.3), P.iron, M.Metal)
	for _, x in { -0.9, 0.9 } do k:box('Mast', V(x - 0.2, 0.3, -2.3), V(x + 0.2, 6.8, -1.9), P.iron, M.Metal) end
	for _, x in { -0.7, 0.7 } do k:box('Fork', V(x - 0.2, 1.0, -5.2), V(x + 0.2, 1.2, -2.3), P.iron, M.Metal) end
	k:box('PalletLoad', V(-1.9, 1.2, -5.4), V(1.9, 1.7, -2.4), P.woodDark, M.Wood)
	k:box('Carton', V(-1.6, 1.7, -5.1), V(1.6, 3.9, -2.6), P.crate, M.Cardboard)
end
-- A reach stacker parked with its boom down: a long chassis on big wheels, the counterweight at the back, the cab off to
-- one side, the boom from the back over the front, the spreader across its nose. Front toward local -Z.
function Street.reachStacker(c, cf, color)
	local k = c:at(cf):group('ReachStacker')
	local dark = Craft.dark(color)
	for _, z in { -3.6, 3.8 } do k:box('Wheels', V(-2.9, 0, z - 1.5), V(2.9, 3.0, z + 1.5), P.black, M.SmoothPlastic) end
	k:box('StackerChassis', V(-2.6, 1.2, -5.8), V(2.6, 3.4, 6.2), color, M.SmoothPlastic)
	k:box('StackerWeight', V(-2.7, 1.2, 5.6), V(2.7, 4.8, 7.4), dark, M.SmoothPlastic)
	k:box('StackerCab', V(-2.5, 3.4, 1.4), V(0.2, 7.6, 4.6), color, M.SmoothPlastic)
	decor(k:box('StackerGlass', V(-2.6, 4.8, 1.3), V(0.3, 7.0, 4.7), P.glass, M.SmoothPlastic))
	k:bar('StackerBoom', V(1.3, 4.4, 5.2), V(1.3, 8.6, -7.6), 1.7, color, M.SmoothPlastic)
	k:box('StackerSpreader', V(-5.6, 7.2, -8.6), V(5.6, 8.4, -7.0), dark, M.SmoothPlastic)
end
-- A site office: a portable cabin (window strip, door) with a second one stacked on it and an outside stair up to the
-- top one along its +X end. cf: the lower cabin's front-left corner, the fronts toward local +Z; w long.
function Street.siteOffice(c, cf, w, color)
	local k = c:at(cf):group('SiteOffice')
	local trim = Craft.dark(color)
	for q = 0, 1 do
		local y = q * 6.2
		k:box('Cabin', V(0, y, -6), V(w, y + 6.0, 0), color, M.SmoothPlastic)
		k:box('CabinRoof', V(-0.2, y + 6.0, -6.2), V(w + 0.2, y + 6.2, 0.2), trim, M.SmoothPlastic)
		decor(k:box('CabinWindows', V(1.2, y + 2.6, 0), V(w - 5, y + 4.6, 0.15), P.glass, M.SmoothPlastic))
		k:box('CabinDoor', V(w - 3.8, y + 0.2, 0), V(w - 1.6, y + 5.2, 0.15), trim, M.SmoothPlastic)
	end
	plank(k, 'OfficeStair', V(w + 1.4, 0.2, 3.6), V(w + 1.4, 6.2, -1.2), 2.2, 0.4, P.iron, M.Metal)
	k:box('OfficeLanding', V(w - 4.2, 6.0, 0), V(w + 2.6, 6.3, 2.2), P.iron, M.Metal)
end
-- A railway track laid flush in a yard, from a to b on the ground: a ballast bed, two rails and sleepers every 4.5 studs.
function Street.track(c, a, b)
	local len = (b - a).Magnitude
	local k = c:at(CFrame.lookAt(a, b)):group('Track')
	k:box('TrackBed', V(-3.3, -1, -len), V(3.3, 0.04, 0), C(124, 116, 108), M.Pebble)
	for t = 2.2, len - 1, 4.5 do k:box('Sleeper', V(-3, 0.04, -t - 0.6), V(3, 0.14, -t + 0.6), C(98, 80, 64), M.Wood) end
	for _, x in { -2.2, 2.2 } do k:box('Rail', V(x - 0.2, 0.04, -len), V(x + 0.2, 0.3, 0), C(156, 158, 166), M.Metal) end
	return k
end
-- A railway boxcar standing on the track (long along local Z): two bogies, the deck, a tall body with a sliding door on
-- each side and a rounded roof.
function Street.boxcar(c, cf, color)
	local k = c:at(cf):group('Boxcar')
	local dark = color:Lerp(P.black, 0.3)
	for _, z in { -9.5, 9.5 } do k:box('Bogie', V(-2.4, 0.3, z - 3), V(2.4, 2.2, z + 3), P.black, M.Metal) end
	k:box('BoxcarDeck', V(-3.2, 2.2, -14), V(3.2, 3.0, 14), P.iron, M.Metal)
	k:box('BoxcarBody', V(-3.0, 3.0, -13.6), V(3.0, 10.6, 13.6), color, M.SmoothPlastic)
	k:rod('BoxcarRoof', 3.0, 27.4, CFrame.new(0, 10.0, 0) * CFrame.Angles(0, math.pi / 2, 0), color:Lerp(P.white, 0.1), M.SmoothPlastic)
	for _, s in { -1, 1 } do
		k:box('BoxcarDoor', V(s * 3.0 - 0.2, 3.4, -3.4), V(s * 3.0 + 0.2, 10.0, 3.4), dark, M.SmoothPlastic)
		k:box('BoxcarDoorRail', V(s * 3.0 - 0.3, 10.0, -7), V(s * 3.0 + 0.3, 10.4, 7), P.iron, M.Metal)
	end
	for _, z in { -14.3, 14.3 } do k:box('BoxcarCoupler', V(-0.4, 1.4, z - 0.7), V(0.4, 2.2, z + 0.7), P.iron, M.Metal) end
end
-- A level-crossing signal facing local +Z: a post on a foot, the white crossbuck, a black board with two red lamps and,
-- beside it, the barrier arm standing up (raised: the line is clear), red and white.
function Street.crossing(c, cf)
	local k = c:at(cf):group('LevelCrossing')
	k:box('CrossingFoot', V(-0.7, 0, -0.7), V(0.7, 0.6, 0.7), C(150, 152, 158), M.Concrete)
	k:post('CrossingPost', 0.22, 8.4, V(0, 0.6, 0), P.iron, M.Metal)
	for _, a in { 35, -35 } do k:part('Crossbuck', V(4.0, 0.7, 0.15), CFrame.new(0, 8.0, 0.3) * CFrame.Angles(0, 0, math.rad(a)), P.white, M.SmoothPlastic) end
	k:box('CrossingBoard', V(-1.8, 5.0, 0.15), V(1.8, 6.2, 0.4), P.black, M.SmoothPlastic)
	for _, x in { -1.1, 1.1 } do decor(k:part('CrossingLamp', V(0.2, 0.9, 0.9), CFrame.new(x, 5.6, 0.45) * CFrame.Angles(0, math.pi / 2, 0), C(214, 70, 60), M.SmoothPlastic, Enum.PartType.Cylinder)) end
	k:box('BarrierPivot', V(0.8, 1.8, -0.6), V(2.0, 3.2, 0.6), P.iron, M.Metal)
	k:box('BarrierArm', V(1.15, 3.2, -0.22), V(1.65, 13.2, 0.22), P.white, M.SmoothPlastic)
	for _, y in { 5.0, 8.6 } do decor(k:box('BarrierStripe', V(1.1, y, -0.27), V(1.7, y + 1.8, 0.27), C(206, 70, 62), M.SmoothPlastic)) end
end
-- An articulated lorry, front toward local -Z: the tractor (cab with its windscreen, chassis, wheels) and a tall box
-- trailer on its own wheels.
function Street.lorry(c, cf, color, box)
	local k = c:at(cf):group('Lorry')
	for _, z in { -11, -4, 8.8, 11.6 } do k:box('Wheels', V(-2.5, 0, z - 1.1), V(2.5, 2.2, z + 1.1), P.black, M.SmoothPlastic) end
	k:box('TractorChassis', V(-2.3, 1.2, -13.4), V(2.3, 2.4, -2), P.iron, M.SmoothPlastic)
	k:box('TractorCab', V(-2.6, 2.0, -13.6), V(2.6, 8.6, -8.4), color, M.SmoothPlastic)
	decor(k:box('TractorScreen', V(-2.3, 5.4, -13.75), V(2.3, 7.8, -13.5), P.glass, M.SmoothPlastic))
	k:box('TractorBumper', V(-2.7, 1.0, -13.9), V(2.7, 2.0, -13.4), P.frame, M.SmoothPlastic)
	decor(k:box('TractorGrille', V(-1.3, 2.4, -13.75), V(1.3, 4.6, -13.55), P.iron, M.SmoothPlastic))
	for _, x in { -2.2, 1.5 } do decor(k:box('Headlight', V(x, 2.4, -13.75), V(x + 0.7, 3.0, -13.55), C(255, 244, 214), M.SmoothPlastic)) end
	k:box('TrailerBox', V(-2.8, 2.6, -7.6), V(2.8, 12.4, 13.6), box, M.SmoothPlastic)
	k:box('TrailerBand', V(-2.85, 9.8, -7.5), V(2.85, 10.8, 13.5), color, M.SmoothPlastic)
	k:box('TrailerChassis', V(-2.2, 1.6, -7.4), V(2.2, 2.6, 13.4), P.iron, M.SmoothPlastic)
end
-- A brick chimney on a square foot: tall, with two dark bands near the top and a cap.
function Street.chimney(c, pos, h)
	local k = c:group('Chimney')
	local brick = C(170, 92, 76)
	k:box('ChimneyFoot', pos + V(-3.4, 0, -3.4), pos + V(3.4, 6, 3.4), brick:Lerp(P.black, 0.15), M.Brick)
	k:post('Chimney', 2.4, h - 6, pos + V(0, 6, 0), brick, M.Brick)
	for _, y in { h - 6, h - 2.6 } do k:post('ChimneyBand', 2.6, 0.8, pos + V(0, y, 0), C(62, 60, 64), M.SmoothPlastic) end
	k:post('ChimneyCap', 2.7, 0.6, pos + V(0, h - 0.6, 0), C(62, 60, 64), M.SmoothPlastic)
	return k
end
-- The two sections' ground. ---------------------------------------------------------------------------------------------
-- The Apartments: paving across both gates' cross streets, an estate road (a lighter asphalt than the Block's) from x0 to
-- x1 between raised pavements, lawns out to the plots' backs. Everything stops at -53, so the far cross street's paving
-- is deep enough for the next gate's bus stop to stand flat (G, notes 16:30).
function Street.estateGround(d, top, x0, x1)
	local function Z(z) return top + z end
	for _, zz in { { -8, 0 }, { -SLEN, -53 } } do d:box('CrossPaving', V(-FRONT, -1, Z(zz[1])), V(FRONT, 0, Z(zz[2])), P.tileA, M.SmoothPlastic) end
	d:box('EstateRoad', V(x0, -1, Z(-53)), V(x1, 0, Z(-8)), C(108, 110, 118), M.Asphalt)
	for _, pv in { { x0 - 4, x0 }, { x1, x1 + 4 } } do
		d:box('Pavement', V(pv[1], -1, Z(-53)), V(pv[2], 0.3, Z(-8)), P.tileA, M.SmoothPlastic)
		local kx = pv[1] == x0 - 4 and x0 or x1
		d:box('Kerb', V(kx - 0.45, -1, Z(-53)), V(kx + 0.45, 0.34, Z(-8)), P.kerb, M.Concrete)
	end
	d:box('Lawn', V(-64, -1, Z(-53)), V(x0 - 4, 0.12, Z(-8)), P.grass, M.Grass)
	d:box('Lawn', V(x1 + 4, -1, Z(-53)), V(64, 0.12, Z(-8)), P.grass, M.Grass)
end
-- The Yards: dark asphalt everywhere, concrete across both gates' cross streets.
function Street.yardGround(d, top)
	local function Z(z) return top + z end
	local concrete = C(168, 170, 176)
	for _, zz in { { -8, 0 }, { -SLEN, -56 } } do d:box('CrossConcrete', V(-FRONT, -1, Z(zz[1])), V(FRONT, 0, Z(zz[2])), concrete, M.Concrete) end
	d:box('YardAsphalt', V(-FRONT, -1, Z(-56)), V(FRONT, 0, Z(-8)), P.asphalt, M.Asphalt)
	for _, s in { -1, 1 } do d:box('YardAsphalt', V(s * FRONT, -1, Z(-SLEN)), V(s * 64, 0, Z(0)), P.asphalt, M.Asphalt) end
end

-- The Apartments. -------------------------------------------------------------------------------------------------------
-- Stage 10, "the courtyard". The district's edge: right past gate 10 two tall slabs stand end-on to the street, joined
-- high up by a glazed sky bridge, so the long view from the Courts ends in the estate's front door. Beyond them the
-- estate opens: a planted median with three trees splits the road, a block on the west wraps a courtyard that opens to
-- the street, and in it stands the rocket, the old climbing frame, with a parent's bench and a pram facing it. On the
-- east, a slab behind its lawn: two cars in a parking court, the bike shed by its door. The bin store waits by the road.
function Street.courtyard(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	Street.estateGround(d, top, -12, 12)
	Street.island(d, V(-4, 0, Z(-48)), V(5, 0, Z(-22)))
	d:box('MedianHedge', V(-3.2, 0.5, Z(-24.8)), V(4.2, 1.7, Z(-22.8)), P.hedge, M.Grass)
	Street.lawnTree(d, V(0.8, 0.56, Z(-31.5)), 1002, 0.85)
	Street.lawnTree(d, V(-0.2, 0.56, Z(-43.4)), 1003, 0.95)
	-- The gateway pair: end-on to the street, fronts toward the gate (+Z), joined by the sky bridge at the 4th floor. (Not a
	-- mirror pair: the east block is wider and a storey taller.)
	local north = function(x0, zf) return d:at(CFrame.lookAt(V(x0, 0, Z(zf)), V(x0, 0, Z(zf) - 1))) end
	Street.slab(north(-64, -11), 44, { name = 'GatewayWest', floors = 6, wall = P.tanLight, band = P.cream, flats = 5, back = true,
		accents = { { 2, 3 }, { 4, 5 }, { 1, 6 } }, accent = C(214, 150, 84), dishes = { { 3, 4 }, { 5, 2 } } })
	Street.slab(north(16, -11), 48, { name = 'GatewayEast', floors = 7, wall = P.tan, band = P.cream, flats = 5, back = true,
		accents = { { 3, 2 }, { 1, 4 }, { 4, 6 }, { 5, 3 } }, accent = { C(214, 124, 78), C(222, 150, 70) }, dishes = { { 2, 5 } } })
	local bridge = d:group('SkyBridge')
	bridge:box('BridgeBody', V(-20.4, 31.4, Z(-21)), V(16.4, 41.6, Z(-13)), P.cream, M.SmoothPlastic)
	for _, z in { -13, -21 } do decor(bridge:box('BridgeGlass', V(-20.4, 33.6, Z(z) - 0.15), V(16.4, 39.4, Z(z) + 0.15), P.glass, M.SmoothPlastic)) end
	bridge:box('BridgeCap', V(-20.6, 41.6, Z(-21.3)), V(16.6, 42.4, Z(-12.7)), P.tanDark, M.SmoothPlastic)
	-- The courtyard block (west): its back slab faces the street across the courtyard, its south arm closes it.
	Street.slab(Street.lot(d, -1, 50, Z(-23), 39), 39, { name = 'CourtyardBack', floors = 5, wall = P.cream, band = P.tan, flats = 5, core = 12,
		accents = { { 1, 3 }, { 3, 2 }, { 5, 4 }, { 4, 2 }, { 2, 5 } }, accent = { C(222, 150, 70), C(92, 156, 150), C(204, 96, 78) }, dishes = { { 2, 3 }, { 4, 5 } } })
	Street.slab(north(-50, -50), 14, { name = 'CourtyardArm', floors = 4, wall = P.tanLight, band = P.cream, flats = 2,
		accents = { { 1, 2 }, { 2, 4 } }, accent = { C(222, 150, 70), C(204, 96, 78) } })
	d:box('CourtPath', V(-50, -1, Z(-36)), V(-16, 0.16, Z(-32)), P.tileB, M.SmoothPlastic)
	Street.rocket(d, CFrame.new(-28, 0.12, Z(-44)) * CFrame.Angles(0, math.pi / 2, 0))
	bench(d, V(-18.8, 0.12, Z(-40.2)), V(-1, 0, 0))
	Street.stroller(d, CFrame.new(-18.6, 0.12, Z(-43.6)) * CFrame.Angles(0, math.pi / 2, 0), C(70, 110, 170))
	Street.binStore(d, CFrame.new(-20.6, 0.12, Z(-50.6)))
	-- The east slab behind its lawn: the path to its door, the bike shed beside it, the parking court by the road.
	Street.slab(Street.lot(d, 1, 36, Z(-26), 34), 34, { name = 'EastSlab', floors = 5, wall = C(232, 196, 160), band = P.cream, core = 14, flats = 4,
		accents = { { 1, 2 }, { 4, 3 }, { 2, 4 }, { 3, 5 }, { 4, 5 } }, accent = { C(204, 96, 78), C(222, 150, 70) }, dishes = { { 3, 3 } } })
	d:box('EastPath', V(16, -1, Z(-48.5)), V(36, 0.16, Z(-44.5)), P.tileB, M.SmoothPlastic)
	Street.bikeShed(d, CFrame.new(28.6, 0.12, Z(-39.6)) * CFrame.Angles(0, math.pi / 2, 0), { C(206, 84, 72), C(70, 110, 170), C(236, 186, 76) })
	d:box('ParkingCourt', V(16, -1, Z(-36)), V(30, 0.14, Z(-24)), C(108, 110, 118), M.Asphalt)
	for _, z in { -24.4, -30, -35.6 } do decor(d:box('BayLine', V(17, 0.14, Z(z) - 0.15), V(29, 0.17, Z(z) + 0.15), P.roadLine, M.SmoothPlastic)) end
	car(d, CFrame.new(23.4, 0.14, Z(-27.2)) * CFrame.Angles(0, -math.pi / 2, 0), C(206, 84, 72))
	car(d, CFrame.new(23.0, 0.14, Z(-32.8)) * CFrame.Angles(0, -math.pi / 2, 0), C(226, 226, 230))
	lantern(d, V(-17.6, 0.12, Z(-27)))
	lantern(d, V(14.2, 0.3, Z(-50)))
	Street.nameSign(d, V(13.8, 0.3, Z(-9.4)), 'THE APARTMENTS')
	-- Gate 11's bus stop: on the east side of the cross street, a bench beside it.
	Street.seal(d, top)
end

-- Stage 11, "the car park". The road runs either side of a parking strip down the middle (cars along both kerbs of a
-- paved island, a pay machine at its head, one car being washed, a bucket and a wet patch by it). The landmark is the
-- multi-storey car park on the east: open decks with cars on them, a ramp up its north end with a car climbing it and a
-- barrier arm at its foot. On the west a long slab close to the road, a delivery scooter by its door.
function Street.carPark(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	Street.estateGround(d, top, -15, 15)
	Street.island(d, V(-2, 0, Z(-49)), V(2, 0, Z(-15)), P.tileB)
	for _, s in { -1, 1 } do
		for _, z in { -15, -26.5, -38, -49 } do decor(d:box('BayLine', V(s * 2, 0.02, Z(z) - 0.15), V(s * 7.2, 0.05, Z(z) + 0.15), P.roadLine, M.SmoothPlastic)) end
		decor(d:box('BayLine', V(s * 7.05, 0.02, Z(-49)), V(s * 7.35, 0.05, Z(-15)), P.roadLine, M.SmoothPlastic))
	end
	car(d, CFrame.new(-4.7, 0, Z(-20.8)), C(70, 110, 170))
	car(d, CFrame.new(-4.7, 0, Z(-43.4)) * CFrame.Angles(0, math.pi, 0), C(236, 186, 76))
	car(d, CFrame.new(4.7, 0, Z(-32.2)), C(206, 84, 72))
	d:post('Bucket', 0.6, 1.1, V(8.4, 0, Z(-29.6)), C(70, 140, 196), M.SmoothPlastic)
	decor(d:post('WetPatch', 3.4, 0.03, V(7.6, 0, Z(-32)), C(80, 92, 110), M.SmoothPlastic)).Transparency = 0.3
	d:box('PayMachine', V(-0.7, 0.56, Z(-16.6)), V(0.7, 4.0, Z(-15.8)), C(70, 110, 170), M.SmoothPlastic)
	decor(d:box('PayMachineFace', V(-0.5, 2.4, Z(-15.85)), V(0.5, 3.4, Z(-15.7)), P.cream, M.SmoothPlastic))
	-- The multi-storey car park: three decks on columns behind low parapets, a stair tower at its south-west corner, a
	-- dark back wall so the floors read as open.
	local cp = d:group('CarPark')
	local grey, deep = C(178, 180, 186), C(62, 64, 72)
	cp:box('CarParkFloor', V(36, -1, Z(-62)), V(64, 0.06, Z(-22)), C(108, 110, 118), M.Asphalt)
	cp:box('CarParkBack', V(62.6, 0, Z(-62)), V(63.4, 27, Z(-22)), deep, M.SmoothPlastic)
	for _, y in { 8.4, 17.4, 26.4 } do
		cp:box('CarParkDeck', V(36, y, Z(-62)), V(64, y + 0.6, Z(-22)), grey, M.Concrete)
		cp:box('CarParkParapet', V(35.6, y + 0.6, Z(-62)), V(36.4, y + 3.2, Z(-22)), grey, M.Concrete)
		cp:box('CarParkParapet', V(36, y + 0.6, Z(-22.4)), V(64, y + 3.2, Z(-21.6)), grey, M.Concrete)
	end
	for _, z in { -22, -35.5, -49 } do cp:box('CarParkColumn', V(35.8, 0, Z(z) - 0.6), V(37.0, 26.4, Z(z) + 0.6), grey:Lerp(P.black, 0.12), M.Concrete) end
	cp:box('StairTower', V(36, 0, Z(-62)), V(42.4, 33, Z(-55.6)), C(150, 154, 162), M.Concrete)
	decor(cp:box('StairGlass', V(35.8, 3, Z(-60.6)), V(36.0, 31, Z(-57)), P.glass, M.SmoothPlastic))
	Street.carLite(cp, CFrame.new(44, 9.0, Z(-31)) * CFrame.Angles(0, -math.pi / 2, 0), P.white)
	Street.carLite(cp, CFrame.new(46, 18.0, Z(-43)) * CFrame.Angles(0, math.pi / 2, 0), C(96, 150, 132))
	Street.carLite(cp, CFrame.new(42, 27.0, Z(-38)) * CFrame.Angles(0, -math.pi / 2, 0), C(206, 84, 72))
	Street.carLite(cp, CFrame.new(50, 0.06, Z(-46)) * CFrame.Angles(0, math.pi / 2, 0), C(70, 110, 170))
	-- The ramp up to the first deck along the north end (from the cross street's side, outside x 36), its parapets, a car
	-- halfway up and the barrier arm down across its foot.
	local slope = math.atan2(9, 16)
	cp:wedge('CarParkRamp', V(8, 9, 16), CFrame.new(42, 4.5, Z(-14)) * CFrame.Angles(0, math.pi, 0), grey, M.Concrete)
	for _, x in { 38.2, 45.8 } do plank(cp, 'RampParapet', V(x, 1.4, Z(-6)), V(x, 10.4, Z(-22)), 0.5, 1.6, grey:Lerp(P.black, 0.08), M.Concrete) end
	Street.carLite(cp, CFrame.new(42, 4.8, Z(-14.6)) * CFrame.Angles(slope, 0, 0), C(236, 186, 76))
	cp:box('BarrierPost', V(46.4, 0, Z(-5.4)), V(47.4, 3.6, Z(-4.4)), C(236, 186, 76), M.SmoothPlastic)
	cp:box('BarrierArm', V(38.2, 2.9, Z(-5.1)), V(46.4, 3.3, Z(-4.7)), P.white, M.SmoothPlastic)
	decor(cp:box('BarrierStripe', V(40.6, 2.85, Z(-5.15)), V(42.4, 3.35, Z(-4.65)), C(206, 70, 62), M.SmoothPlastic))
	-- The west slab, close to the road, its door with a delivery scooter on its stand.
	Street.slab(Street.lot(d, -1, 27, Z(-9), 44), 44, { name = 'WestSlab', floors = 6, wall = C(236, 206, 176), band = P.white, flats = 5, core = 26, depth = 13,
		accents = { { 2, 2 }, { 5, 3 }, { 3, 5 }, { 1, 6 }, { 4, 2 } }, accent = { C(214, 124, 78), C(222, 150, 70) }, dishes = { { 1, 3 }, { 4, 4 }, { 2, 6 } } })
	d:box('WestPath', V(-27, -1, Z(-37.4)), V(-19, 0.16, Z(-33.4)), P.tileB, M.SmoothPlastic)
	Street.scooter(d, CFrame.new(-21.6, 0.16, Z(-28.2)) * CFrame.Angles(0, math.pi / 2, 0), C(70, 140, 196))
	lantern(d, V(-17.4, 0.3, Z(-48)))
	lantern(d, V(17.2, 0.3, Z(-20)))
	Street.seal(d, top)
end

-- Stage 12, "the community garden". The estate's last street has no road: a square of paving where the residents grow
-- vegetables. Raised beds inside a low fence, the greenhouse at the garden's far corner (its pitched glass roof is the
-- landmark), a wheelbarrow, sacks and a water butt by the beds. The one big tree stands in the square with a bench
-- under it. East, the estate's tallest block; west, a lower slab behind the garden.
function Street.garden(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	for _, zz in { { -8, 0 }, { -SLEN, -53 } } do d:box('CrossPaving', V(-FRONT, -1, Z(zz[1])), V(FRONT, 0, Z(zz[2])), P.tileA, M.SmoothPlastic) end
	d:box('Square', V(-30, -1, Z(-53)), V(17, 0.06, Z(-8)), C(214, 204, 188), M.SmoothPlastic)
	d:box('Lawn', V(-64, -1, Z(-53)), V(-30, 0.12, Z(-8)), P.grass, M.Grass)
	d:box('Lawn', V(17, -1, Z(-53)), V(64, 0.12, Z(-8)), P.grass, M.Grass)
	-- The garden: a soil-and-grass plot inside a low plank fence, a gap toward the square.
	local gx0, gx1, gz0, gz1 = -30, -7, Z(-52), Z(-20)
	d:box('GardenPlot', V(gx0, 0.06, gz0), V(gx1, 0.14, gz1), C(132, 168, 92), M.Grass)
	local fence, fh = C(176, 136, 96), 2.4
	d:box('GardenFence', V(gx0, 0, gz1 - 0.3), V(gx1, fh, gz1), fence, M.WoodPlanks)
	d:box('GardenFence', V(gx1 - 0.3, 0, gz0), V(gx1, fh, Z(-30)), fence, M.WoodPlanks)
	d:box('GardenFence', V(gx1 - 0.3, 0, Z(-25)), V(gx1, fh, gz1), fence, M.WoodPlanks)
	d:box('GardenFence', V(gx0, 0, gz0), V(gx1, fh, gz0 + 0.3), fence, M.WoodPlanks)
	Street.raisedBed(d, CFrame.new(-21, 0.14, Z(-25)), 12, 3.4, C(206, 84, 72))
	Street.raisedBed(d, CFrame.new(-23, 0.14, Z(-31.5)), 10, 3.4, C(236, 186, 76))
	Street.raisedBed(d, CFrame.new(-20, 0.14, Z(-38)), 14, 3.4, C(150, 96, 160))
	Street.greenhouse(d, CFrame.new(-16.5, 0.14, Z(-46)) * CFrame.Angles(0, math.pi / 2, 0), 8, 12)
	Street.wheelbarrow(d, CFrame.new(-10.6, 0.14, Z(-33.6)) * CFrame.Angles(0, 0.5, 0), C(206, 84, 72))
	for q, p in { V(-27.4, 0.14, Z(-44.0)), V(-26.0, 0.14, Z(-45.2)) } do d:blob('CompostSack', V(1.6, 1.7, 1.3), p + V(0, 0.85, 0), q == 1 and C(70, 120, 84) or C(186, 160, 118), M.Fabric) end
	d:post('WaterButt', 1.2, 3.0, V(-27.6, 0.14, Z(-48.4)), C(70, 120, 84), M.SmoothPlastic)
	d:post('WaterButtLid', 1.3, 0.3, V(-27.6, 3.14, Z(-48.4)), Craft.dark(C(70, 120, 84)), M.SmoothPlastic)
	-- The one tree in the square, a bench under it facing the garden.
	d:box('TreeBed', V(8.6, 0.06, Z(-43.4)), V(14.8, 0.4, Z(-37.2)), C(98, 72, 54), M.Ground)
	Street.lawnTree(d, V(11.7, 0.4, Z(-40.3)), 1201, 1.35)
	bench(d, V(7.0, 0.06, Z(-40.4)), V(-1, 0, 0))
	-- East: the estate's tallest block, its door toward the square. West: a lower slab behind the garden.
	Street.slab(Street.lot(d, 1, 33, Z(-14), 30), 30, { name = 'TowerBlock', floors = 8, wall = P.cream, band = P.tanLight, flats = 3, core = 15, depth = 18,
		accents = { { 1, 3 }, { 3, 5 }, { 2, 7 }, { 1, 8 }, { 3, 2 }, { 2, 4 } }, accent = { C(222, 150, 70), C(92, 156, 150), C(204, 96, 78) }, dishes = { { 2, 4 }, { 3, 6 } } })
	d:box('TowerPath', V(17, -1, Z(-31)), V(33, 0.16, Z(-27)), P.tileB, M.SmoothPlastic)
	Street.slab(Street.lot(d, -1, 40, Z(-14), 40), 40, { name = 'GardenSlab', floors = 4, wall = P.tan, band = P.cream, flats = 5, core = 22, gallery = true })
	lantern(d, V(14.6, 0.06, Z(-50.5)))
	Street.seal(d, top)
end

-- The Yards. ------------------------------------------------------------------------------------------------------------
-- Stage 13, "the container yard". The whole west side is container stacks, one to three high in uneven steps. A gantry
-- crane straddles the stacks and the yard (the tallest thing since the estate), a container hanging from it. In the
-- middle of the yard one container stands open with its doors back, cartons inside, and a forklift brings a pallet to
-- it; the walk passes either side. East, behind a high fence: the site office (two cabins stacked) and more stacks; the
-- reach stacker is parked on the apron in front of it.
function Street.containerYard(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	Street.yardGround(d, top)
	local Y = Street.yardColors
	local red, blue, green, cream, grey = Y.red, Y.blue, Y.green, Y.cream, Y.grey
	local cols = {
		{ -24, { { red }, { blue, green } } },
		{ -32.6, { { green, cream }, { grey, red } } },
		{ -41.2, { { blue, red, cream }, { red } } },
		{ -49.8, { { cream, grey }, { blue, cream, red } } },
		{ -58.4, { { red, blue, green }, { green, grey } } },
	}
	for k, col in cols do
		for b, zc in { -21, -43.4 } do Street.stack(d, CFrame.new(col[1], 0, Z(zc)), col[2][b], k == 1) end
	end
	Street.gantryCrane(d, CFrame.new(0, 0, Z(-45)), -64.2, 40, 28, Y.crane, -41.2, 12.6, blue)
	Street.openContainer(d, CFrame.new(0.4, 0, Z(-41.6)), blue)
	Street.forklift(d, CFrame.new(8.6, 0, Z(-27.4)) * CFrame.Angles(0, math.pi / 2, 0), Y.forklift)
	Street.nameSign(d, V(-12.4, 0, Z(-9.4)), 'THE YARDS')
	pallet(d, CFrame.new(-6.6, 0, Z(-29.4)))
	d:box('Carton', V(-8.2, 0.8, Z(-30.8)), V(-5.0, 3.4, Z(-28.0)), P.crate, M.Cardboard)
	-- East: the fence along the yard, the office behind it, more stacks, the reach stacker on the apron.
	chainLink(d, V(34, 0, Z(-8.5)), V(34, 0, Z(-33)), 9, nil, 0.5, C(70, 74, 82))
	Street.siteOffice(d, CFrame.new(40, 0, Z(-26)) * CFrame.Angles(0, -math.pi / 2, 0), 14, C(232, 232, 236))
	for _, s in { { 50.4, -44, { green, red } }, { 59, -44, { blue } } } do Street.stack(d, CFrame.new(s[1], 0, Z(s[2])), s[3], false) end
	Street.reachStacker(d, CFrame.new(24, 0, Z(-24)), Y.stacker)
	Street.floodlight(d, V(30, 0, Z(-51)), V(0, 0, Z(-30)))
	Street.seal(d, top)
end

-- Stage 14, "the depot". A long shed on the east with three loading docks in three states: shut; open, with pallet
-- racks inside and pallets and a hand truck on the dock; and a van backed up to the third. In the middle of the yard a
-- lorry stands on the weighbridge, the walk going round it. West: the gatehouse with its fuel pump under a canopy, a
-- high fence, and the boiler house whose tall brick chimney is the landmark.
function Street.depot(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	Street.yardGround(d, top)
	-- The shed: corrugated walls (a rib every 4.8), a low-pitched roof, the dock platform along its front.
	local shed = d:group('DepotShed')
	local wall, ribC, roofC = C(186, 192, 200), C(170, 176, 186), C(96, 104, 120)
	shed:box('ShedWall', V(36.4, -1, Z(-62)), V(64, 18, Z(-6)), wall, M.SmoothPlastic)
	for z = -8.4, -60, -4.8 do decor(shed:box('ShedRib', V(36.1, 0.6, Z(z) - 0.35), V(36.4, 17.4, Z(z) + 0.35), ribC, M.SmoothPlastic)) end
	shed:box('ShedRoof', V(35.6, 18, Z(-62.6)), V(64.4, 19.2, Z(-5.4)), roofC, M.SmoothPlastic)
	shed:box('ShedBand', V(36.0, 13.4, Z(-62)), V(36.5, 15.0, Z(-6)), C(62, 108, 196), M.SmoothPlastic)
	shed:box('DockPlatform', V(32.8, 0, Z(-54)), V(36.4, 1.3, Z(-8)), C(150, 152, 158), M.Concrete)
	d:box('Apron', V(18, 0, Z(-54)), V(32.8, 0.05, Z(-8)), C(156, 158, 164), M.Concrete)
	for k, zc in { -15, -31, -47 } do
		local z0, z1 = Z(zc - 4.6), Z(zc + 4.6)
		shed:box('DockFrame', V(35.9, 1.3, z0 - 0.6), V(36.5, 12.0, z1 + 0.6), P.warehouseDark, M.Metal)
		for _, zz in { z0 - 0.3, z1 + 0.3 } do shed:box('DockBumper', V(32.4, 0.4, zz - 0.4), V(32.8, 1.6, zz + 0.4), P.black, M.SmoothPlastic) end
		if k == 2 then
			-- open: the dark inside with a pallet rack (two uprights, two beams, a pallet of cartons on each level)
			decor(shed:box('DockInside', V(35.8, 1.3, z0), V(36.1, 11.4, z1), C(36, 38, 44), M.SmoothPlastic))
			for _, z in { z0 + 0.8, z1 - 0.8 } do shed:box('RackUpright', V(33.2, 1.3, z - 0.25), V(33.6, 10.6, z + 0.25), C(220, 120, 60), M.Metal) end
			for _, y in { 5.4, 9.6 } do
				shed:box('RackBeam', V(33.1, y, z0 + 0.6), V(33.7, y + 0.5, z1 - 0.6), C(70, 110, 170), M.Metal)
				shed:box('RackLoad', V(33.0, y + 0.5, z0 + 1.4), V(35.6, y + 3.0, z1 - 1.4), P.crate, M.Cardboard)
			end
		else
			shed:box('RollDoor', V(35.8, 1.3, z0), V(36.2, 11.4, z1), P.rollDoor, M.Metal)
			for y = 3, 10.5, 2.5 do decor(shed:box('DoorSlat', V(35.65, y, z0), V(35.8, y + 0.2, z1), P.rollDoor:Lerp(P.black, 0.35), M.Metal)) end
		end
	end
	Street.boxTruck(d, CFrame.new(25.6, 0.05, Z(-47)) * CFrame.Angles(0, math.pi / 2, 0), C(206, 84, 72))
	pallet(d, CFrame.new(30.2, 0.05, Z(-34.6)))
	crate(d, CFrame.new(30.0, 0.85, Z(-34.6)), 2.6)
	pallet(d, CFrame.new(29.8, 0.05, Z(-25.8)) * CFrame.Angles(0, 0.2, 0))
	Street.handTruck(d, CFrame.new(34.4, 1.3, Z(-29.4)) * CFrame.Angles(0, -math.pi / 2, 0))
	-- The weighbridge in the middle of the yard with a lorry on it.
	d:box('Weighbridge', V(-6.4, 0, Z(-50)), V(8.4, 0.1, Z(-20)), C(120, 124, 132), M.DiamondPlate)
	Street.lorry(d, CFrame.new(1, 0.1, Z(-35.5)) * CFrame.Angles(0, math.pi + 0.32, 0), C(62, 108, 196), C(232, 232, 236))
	-- West: the gatehouse and its fuel pump, a high fence, the boiler house and its chimney.
	d:box('FuelIsland', V(-28, 0, Z(-26)), V(-22, 0.4, Z(-17)), P.kerb, M.Concrete)
	d:box('FuelPump', V(-26.0, 0.4, Z(-22.6)), V(-24.0, 5.0, Z(-20.4)), C(206, 84, 72), M.SmoothPlastic)
	decor(d:box('FuelPumpFace', V(-23.95, 2.6, Z(-22.2)), V(-23.85, 4.0, Z(-20.8)), P.cream, M.SmoothPlastic))
	for _, z in { -18, -25 } do d:box('CanopyPost', V(-25.3, 0.4, Z(z) - 0.3), V(-24.7, 9.4, Z(z) + 0.3), P.frame, M.SmoothPlastic) end
	d:box('FuelCanopy', V(-31, 9.4, Z(-28)), V(-19, 10.6, Z(-15)), P.white, M.SmoothPlastic)
	decor(d:box('FuelCanopyBand', V(-31.1, 9.6, Z(-28.1)), V(-18.9, 10.3, Z(-14.9)), C(206, 84, 72), M.SmoothPlastic))
	Street.siteOffice(d, CFrame.new(-36, 0, Z(-10)) * CFrame.Angles(0, math.pi / 2, 0), 10, C(150, 186, 168))
	chainLink(d, V(-34, 0, Z(-30)), V(-34, 0, Z(-44)), 9, nil, 0.5, C(70, 74, 82))
	local boiler = d:group('BoilerHouse')
	boiler:box('BoilerWall', V(-60, -1, Z(-62)), V(-38, 12, Z(-46)), C(178, 98, 80), M.Brick)
	boiler:box('BoilerRoof', V(-60.4, 12, Z(-62.4)), V(-37.6, 13, Z(-45.6)), P.slate, M.SmoothPlastic)
	boiler:box('BoilerDoor', V(-38.2, 0, Z(-56)), V(-37.8, 9, Z(-50)), P.rollDoor, M.Metal)
	decor(boiler:box('BoilerWindows', V(-38.1, 6, Z(-61)), V(-37.9, 10, Z(-57.4)), P.glass, M.SmoothPlastic))
	Street.chimney(d, V(-46, 0, Z(-58)), 40)
	Street.floodlight(d, V(-14, 0, Z(-12)), V(0, 0, Z(-34)))
	Street.seal(d, top)
end

-- Stage 15, "the rail spur", and the walk-in to the boss yard. A railway crosses the yard on the slant, flush with the
-- asphalt; a boxcar stands on it on the west side and a level-crossing signal stands at each side of the walk. Past the
-- line, high fences close in from both sides like a funnel and floodlight masts at its mouth light the way through gate
-- 16 to the Champ Ring. Behind the fences, containers on the west and a parked trailer on the east.
function Street.railSpur(ctx, i)
	local d, top = Street.core(ctx, i)
	local function Z(z) return top + z end
	Street.yardGround(d, top)
	local a, b = V(-64, 0, Z(-38)), V(64, 0, Z(-12))
	Street.track(d, a, b)
	local dir = (b - a).Unit
	local function onTrack(x) return a + dir * ((x - a.X) / dir.X) end
	local p = onTrack(-27)
	Street.boxcar(d, CFrame.lookAt(p, p + dir), C(150, 86, 66))
	for _, x in { 13, -11 } do Street.crossing(d, CFrame.new(onTrack(x) + V(0, 0, 6))) end
	-- The funnel: high fences closing in toward gate 16, with gaps nowhere; floodlights at its mouth aimed at the ring.
	local cage = C(70, 74, 82)
	chainLink(d, V(-36, 0, Z(-40)), V(-13, 0, Z(-53)), 10, nil, 0.5, cage)
	chainLink(d, V(36, 0, Z(-36)), V(13, 0, Z(-53)), 10, nil, 0.5, cage)
	for _, x in { -36, 36 } do chainLink(d, V(x, 0, Z(-SLEN + 0.8)), V(x, 0, Z(x < 0 and -40 or -36)), 10, nil, 0.5, cage) end
	for _, x in { -10.6, 10.6 } do Street.floodlight(d, V(x, 0, Z(-51.4)), V(0, 0, BOSS_TOP - 34)) end
	local Y = Street.yardColors
	Street.stack(d, CFrame.new(-44, 0, Z(-52)), { Y.green, Y.red }, false)
	Street.stack(d, CFrame.new(-52.6, 0, Z(-52)), { Y.blue }, false)
	Street.stack(d, CFrame.new(-61.2, 0, Z(-52)), { Y.cream, Y.blue }, false)
	Street.lorry(d, CFrame.new(50, 0, Z(-48)) * CFrame.Angles(0, math.pi, 0), C(206, 84, 72), C(140, 146, 156))
	Street.seal(d, top)
end

-- Dispatch from the district builders.
function Street.apartments(ctx, i)
	return ({ [10] = Street.courtyard, [11] = Street.carPark, [12] = Street.garden })[i](ctx, i)
end
function Street.yards(ctx, i)
	return ({ [13] = Street.containerYard, [14] = Street.depot, [15] = Street.railSpur })[i](ctx, i)
end

-- (end of the Apartments and the Yards)

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
