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
		road = C(120, 126, 142), dash = C(255, 243, 50), walk = C(160, 172, 190), grass = C(38, 212, 92),
		brick = C(203, 118, 85), trim = C(199, 177, 175), band = C(182, 196, 222), roof = C(102, 136, 180),
		glassA = C(162, 204, 250), glassB = C(190, 218, 243), mullion = C(44, 86, 142),
		fence = { C(229, 122, 63), C(143, 79, 71), C(192, 100, 64), C(143, 79, 71) }, -- light, dark, mid, dark
		lamp = C(74, 104, 160), lampGlow = C(255, 244, 196),
		leaf = C(32, 250, 56), trunk = C(97, 90, 103), hedge = C(26, 196, 70), dumpster = C(14, 190, 78),
		petal = C(30, 70, 156), petalEye = C(250, 232, 70), stem = C(40, 180, 82), garbage = C(230, 130, 46),
		-- Second and third tones (developer-level shading: every surface in 2-3 shades of its colour).
		brickDark = C(166, 97, 71), brickDeep = C(187, 102, 71), brickLight = C(217, 136, 95), sill = C(233, 210, 200),
		trimDark = C(159, 141, 142), roofDark = C(76, 100, 138),
		gutter = C(110, 118, 136), roadDark = C(100, 106, 122), kerbStone = C(184, 192, 206), walkJoint = C(132, 142, 160),
		grassDark = C(28, 176, 76), grassEdge = C(24, 160, 70), leafDark = C(26, 214, 48), lampDark = C(56, 80, 130),
		lampLight = C(104, 138, 194), plankDark = C(104, 56, 48), dumpsterDark = C(10, 150, 60), manhole = C(70, 74, 84),
	},
	-- Its cross-section, measured from the picture (studs from the centre line, heights from the road top):
	-- road |x| < road, sidewalk to road + walk (top at kerb), grass to front, the plank fence at fence, building
	-- fronts at front; the last SLEN - endZ studs of each stage narrow to |x| = open, framing the next gate's wall.
	street = { road = 8.5, walk = 8, kerb = 0.6, front = 36, open = 22, fence = 34.5, endZ = 56, eave = 30, band = 15, sills = { 4, 19 }, winH = 8.5 },
}
---------------------------------------------------------------------------------------------- World 2: Business District (city)
-- TheCity: World 2's map (hood/docs/WORLD2.md; the owner, Oct 27: "make the second world more advanced ... more of a
-- city, not the hood, as they are escaping the hood"). Assembled by tools/map/city_assemble.sh from World 1's shared
-- pieces (the kit, the lobby's zone builders, the stage gates, the look pass, the build) plus the city's own:
--   city/c_layout.lua   the layout constants: World 1's size, 15 stages and the rooftop (Stage 16)
--   city/e5_plaza.lua   the lobby's zones and slots (World 1's plan), the city kit, business district round the lobby
--   city/e6_hall.lua    the lobby's hall: the owner's "C" (the Oct 10 indoor hall) in place of the warehouse
--   city/f4_districts.lua  the five districts' props (the owner's Oct 27 mockup)
--   city/f5_avenue.lua  the stages: a business district avenue (asphalt, lane lines, crosswalks, sidewalks, towers on shop
--                       podiums taller up the track, five districts), the rooftop, the city round it
--   city/x2_look.lua    the hall's faint studs on its pillars and bands, after the look pass
-- The crews' hangouts are World 1's (pieces/f3_waves).
-- Same contracts as TheBlockV2 (the root's Active / Origin / LobbySpawn / LobbySpawnYaw, Training_<Id> stations,
-- HoodStageGate models, HoodStagePad parts, HoodFightPad markers, the lobby slots), the root named TheCity with
-- HoodWorld = 2. Command Bar:  require(game.ServerStorage.TheCity).Build()
V2.Name, V2.World, V2.Where = 'TheCity', 2, 'city'
-- This place is World 2: say so before anything reads the economy (the helpers' Robux text loads Config/Products and
-- with it Config/Balance), so the pads' Cash and the gates' Power are World 2's from the very first build.
pcall(function() workspace:SetAttribute('HoodWorld', 2) end)

-- The avenue's colours (the bright reference palette: light clean stone, mid asphalt, white lines) over the hood
-- street's: f_areas' ground and the gate builders read P.st.
P.st.road, P.st.roadDark, P.st.dash = C(98, 104, 122), C(84, 90, 106), C(250, 250, 250)
P.st.walk, P.st.kerbStone, P.st.walkJoint = C(232, 226, 214), C(246, 244, 238), C(210, 202, 188)
P.st.grass, P.st.grassDark, P.st.grassEdge = C(222, 212, 194), C(206, 194, 174), C(196, 184, 164)
P.st.gutter, P.st.manhole = C(120, 126, 142), C(92, 98, 114)

-- The city's own builders and colours (city/e5_plaza.lua and city/f5_avenue.lua fill it): one table, so the chunk keeps
-- its spare locals (check_locals).
local City = {
	-- the plaza's warm sand pavers (two tones), its edge stone, the planters' terracotta and the hedges on them
	paverA = C(238, 212, 168), paverB = C(232, 204, 158), edge = C(222, 186, 140), edgeCap = C(246, 232, 206),
	clay = C(214, 140, 102), clayCap = C(240, 206, 168), hedge = C(76, 186, 84), hedgeTop = C(112, 210, 100),
	walk = P.st.walk, kerb = P.st.kerbStone, road = P.st.road, line = C(250, 250, 250), yellow = C(255, 206, 40),
	-- glass towers: sky-blue, teal and violet-blue glass, white mullions, warm stone bases, steel-blue roofs
	glass = { C(126, 196, 248), C(108, 214, 226), C(150, 168, 250), C(134, 224, 206) },
	base = { C(228, 180, 130), C(216, 140, 104), C(242, 218, 176), C(206, 160, 118) },
	mullion = C(244, 247, 252), roof = C(96, 112, 156), roofDark = C(78, 92, 132), doorGlass = C(46, 70, 108),
	taxiYellow = C(255, 204, 32), steel = C(150, 162, 186), steelDark = C(96, 108, 136),
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
-- (brief 28) Every sign is set in the references' Montserrat (Shared/Fonts: its Black for names, numbers and signs; was
-- FredokaOne, LuckiestGuy, Gotham Black and PermanentMarker). The keys stay for the builders and HoodProps.
local FONT = (function()
	local F = require(game:GetService('ReplicatedStorage').Shared.Fonts)
	return { title = F.Title, loud = F.Title, body = F.Title, tag = F.Title, number = F.Number, small = F.Body }
end)()
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
-- One line of text in a band of the gui (y and h are 0-1), with a clean outline. font: a Font (FONT's), or an Enum.Font
-- (the gate's pixel "Power: X" line).
local function line(gui, name, value, color, font, y, h, outline, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	if typeof(font) == 'EnumItem' then t.Font = font else t.FontFace = font or FONT.title end
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
-- (B31, rule 27: "make the text font way better") The references' drop shadow under floating words: a near-black twin of
-- each TextLabel, 0.09 x 0.12 studs down-right and under it (ZIndex), its outline the same ink. gw, gh: the BillboardGui's
-- size in studs (its Size is fromScale in studs). HoodClient/LabelFade keeps a twin's text, place and visibility on its
-- label's, whatever writes them (attribute ShadowOf = the label's name). Billboards only, never the stage gates' signs.
local SHADOW_INK = Color3.fromRGB(11, 11, 20)
-- (ROBUX, brief 31) Robux prices in the world: RobuxText.fmt(n) = the Robux sign (U+E002) and the number with commas.
local RobuxText = (function()
	local ok, m = pcall(function() return require(ReplicatedStorage.Shared.RobuxText) end)
	if ok and type(m) == 'table' and m.fmt then return m end
	local mark = utf8.char(0xE002)
	return { Mark = mark, fmt = function(n) return mark .. tostring(n or '') end, commas = function(n) return tostring(n or '') end }
end)()
local function dropShadow(label, gw, gh)
	if not label.Parent or label:GetAttribute('ShadowOf') or label.Parent:FindFirstChild(label.Name .. 'Shadow') then return nil end
	local sh = label:Clone()
	for _, k in sh:GetChildren() do if k:IsA('UIGradient') then k:Destroy() end end
	sh.Name = label.Name .. 'Shadow'
	sh.TextColor3 = SHADOW_INK
	sh.TextTransparency = 0.15
	local dx, dy = 0.09 / math.max(gw, 0.5), 0.12 / math.max(gh, 0.5)
	sh.Position = label.Position + UDim2.fromScale(dx, dy)
	sh:SetAttribute('ShadowOf', label.Name)
	sh:SetAttribute('ShadowDX', dx)
	sh:SetAttribute('ShadowDY', dy)
	label.ZIndex, sh.ZIndex = 2, 1
	local parent = label.Parent
	label.Parent = nil
	sh.Parent = parent
	label.Parent = parent
	return sh
end
local function shadowAll(gui)
	if not (gui and gui:IsA('BillboardGui')) then return gui end
	local w, h = gui.Size.X.Scale, gui.Size.Y.Scale
	for _, t in gui:GetChildren() do
		if t:IsA('TextLabel') and not t:GetAttribute('ShadowOf') then dropShadow(t, w, h) end
	end
	return gui
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
	shadowAll(g)
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

---------------------------------------------------------------------------------------------- layout (World 2: the city)
-- World 1's layout (pieces/c_layout.lua), World 1's size (Oct 27 round 3, the owner: "make it the size of the first
-- world"): 15 avenue stages of 64 studs, gate 16 onto the rooftop (the boss yard, Stage 16: The CEO's crew), 96 deep.
-- The lobby's plan is World 1's (the same zones and slots, e3_plaza), so the shared builders read the same constants.
local FRONT = 36 -- tower fronts at x = ±36, facing the avenue
local DEPTH = 28 -- the avenue's towers run back to x = ±64
local WALL_X = 124 -- the low boundary wall (f_areas), hidden under the skyline towers that stand over it
local SLEN = 64 -- one stage
local STAGES = 15 -- the avenue's stages; gate 16 opens the rooftop
local SPAWN_W, SPAWN_TOP = 74, 123 -- (World 1's legacy hall extents: f_areas' ground and e2's legacy builders read them)
local BOSS_TOP = -STAGES * SLEN -- -960: gate 16, onto the rooftop
local BOSS_END = BOSS_TOP - 96 -- the rooftop runs to -1056
local SPAWN = V(0, 0, 42) -- the plaza's crossing, the same as World 1's
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end
local function trioOf(i) return (i - 1) % 3 + 1 end
local function gateZ(i) return stageTop(i) end
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each of World 2's stages. WORLD2.md: "World 2's Stage 1 asks for about World 1's boss Power". The
-- numbers are the economy's (Config/Balance.Worlds[2].StagePower, the Oct 27 pacing pass); without
-- them, a stand-in that starts at World 1's boss Power and grows 1.55x a stage.
local STAGE_POWER = {}
do
	local ok, Balance = pcall(function() return require(ReplicatedStorage.Shared.Config.Balance) end)
	local w2 = ok and type(Balance) == 'table' and Balance.Worlds and Balance.Worlds[2] and Balance.Worlds[2].StagePower
	if type(w2) == 'table' and #w2 >= STAGES + 1 then
		STAGE_POWER = table.clone(w2)
	else
		local base = ok and type(Balance) == 'table' and type(Balance.StagePower) == 'table' and Balance.StagePower[16] or 220000
		for i = 1, 16 do STAGE_POWER[i] = math.floor(base * 1.55 ^ (i - 1) / 1000 + 0.5) * 1000 end
	end
end
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop

-- Every stage's pad in walking order, then the rooftop's (The CEO), as World 1's.
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
table.insert(V2.Fights, { Fight = 16, Stage = 16, Look = 6, X = 0, Z = BOSS_END + 22, Boss = true })
---------------------------------------------------------------------------------------------- asset kit
-- The concept's "Asset Kit (simple Roblox parts)". All positions are in the given context's frame.
local function plank(c, name, a, b, width, thick, color, material)
	return c:part(name, V(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or M.SmoothPlastic)
end

-- The reference street's props (ref1_street.png): chunky blocks, studded on every face, sized from the picture.
-- A studded box between two corners (the street kit's only brick).
local function sbox(c, name, a, b, color, isDecor)
	local p = studs(c:box(name, a, b, color, M.Plastic), true)
	if isDecor then decor(p) end
	return p
end
-- Tree of stacked green cubes on a short grey trunk, measured from the picture (top ~15.8 above the grass, crown
-- ~7 wide and ~12 tall, trunk ~3 wide and ~3.8 tall): three tiers that step in and wander a little, darker below and
-- lighter toward the sunlit top, a cap, a thin side block, and a soil pit round the trunk. seed varies it; yaw
-- (degrees) turns it (the picture's trees stand at an angle to the street).
local function tree(c, pos, seed, scale, yaw, simple)
	local r = Random.new(seed)
	local s = scale or 1
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or r:NextInteger(0, 3) * 90), 0)):group('Tree')
	local leaf, dark = P.st.leaf, P.st.leafDark
	local function B(name, a, b, col) return sbox(t, name, a * s, b * s, col) end
	local function off() return r:NextInteger(-1, 1) * 0.5 end
	if not simple then -- (simple: the ring road's trees behind the buildings skip the small parts)
		decor(sbox(t, 'TreePit', V(-2.4, -0.05, -2.4) * s, V(2.4, 0.15, 2.4) * s, C(110, 84, 64)))
		B('TrunkRing', V(-1.7, 0, -1.7), V(1.7, 0.7, 1.7), P.st.trunk:Lerp(P.black, 0.2))
	end
	B('Trunk', V(-1.5, 0, -1.5), V(1.5, 3.8, 1.5), P.st.trunk)
	B('Crown', V(-3.5, 3.8, -3.5), V(3.5, 8.6, 3.5), dark)
	local x2, z2 = off(), off()
	B('Crown', V(-3 + x2, 8.6, -3 + z2), V(3 + x2, 12.4, 3 + z2), leaf)
	local x3, z3 = x2 + off(), z2 + off()
	B('Crown', V(-2.2 + x3, 12.4, -2.2 + z3), V(2.2 + x3, 14.8, 2.2 + z3), leaf:Lerp(P.white, 0.1))
	B('CrownTop', V(-1.3 + x3, 14.8, -1.3 + z3), V(1.3 + x3, 15.8, 1.3 + z3), leaf:Lerp(P.white, 0.16))
	if not simple then B('CrownSide', V(3.5, 6.6, -1.5), V(4.3, 10.6, 1.5), dark:Lerp(P.black, 0.08)) end
	return t
end
-- Low hedge of two stacked green blocks (the ones on the reference's grass), long along Z: a darker lower block on a
-- dark green foot, a lighter top block.
local function hedge(c, pos, len)
	len = len or 6
	local h = c:at(CFrame.new(pos)):group('Hedge')
	decor(sbox(h, 'HedgeFoot', V(-1.8, -0.05, -len / 2 - 0.2), V(1.8, 0.3, len / 2 + 0.2), P.st.grassEdge))
	sbox(h, 'Hedge', V(-1.6, 0, -len / 2), V(1.6, 2.2, len / 2), P.st.hedge:Lerp(P.black, 0.08))
	sbox(h, 'Hedge', V(-1.2, 2.2, -len / 2), V(1.2, 3.8, len / 2 - 2), P.st.hedge:Lerp(P.st.leaf, 0.5):Lerp(P.white, 0.06))
	return h
end
-- Wooden plank fence along Z at x from z0 to z1 (the picture's front-yard fence, ~8 tall): 2-stud planks, 1 thick,
-- alternating light / dark wood (the light ones in two tones), every other plank stepped toward the street (side = the
-- street's direction, +1 or -1), each capped with a steep wedge that slopes down toward the street, heights jittered;
-- a dark post with a light cap every four planks. gaps = { { za, zb } } (world z) leave gateways: a tall post either
-- side and a plank gate standing open into the yard.
local function fence(c, x, z0, z1, side, h, gaps)
	h = h or 6.8
	local f = c:group('Fence')
	local n = math.max(1, math.floor(math.abs(z1 - z0) / 2 + 0.5))
	local w = (z1 - z0) / n
	local function inGap(za, zb)
		for _, g in gaps or {} do
			if math.max(za, zb) > math.min(g[1], g[2]) + 0.05 and math.min(za, zb) < math.max(g[1], g[2]) - 0.05 then return true end
		end
		return false
	end
	-- (Oct 27 review) an invisible keep-in cap over each run of planks, from just under their tops to 40 up (like
	-- City.court's): nobody stands on the fence and drops into a yard strip behind it that has no way back out (World 1's
	-- Stage 1, the strip between the right fence and the house; tools/checks/city_reach.luau with REACH_MAP)
	local runA, runB = nil, nil
	local function cap()
		if not runA then return end
		local lo, hi = x - 0.9 + math.min(0, side * 0.5), x + 0.9 + math.max(0, side * 0.5)
		local p = f:box('Boundary', V(lo, h - 0.6, math.min(runA, runB)), V(hi, 40, math.max(runA, runB)), P.white, M.SmoothPlastic)
		p.Transparency = 1
		p.CastShadow = false
		runA = nil
	end
	for k = 0, n - 1 do
		local za, zb = z0 + k * w, z0 + (k + 1) * w
		if inGap(za, zb) then cap() else runA, runB = runA or za, zb end
		if not inGap(za, zb) then
			local col = P.st.fence[k % #P.st.fence + 1]
			local xm = x + (k % 2 == 1 and side * 0.5 or 0)
			local hk = h + ((k * 7) % 3 - 1) * 0.4
			sbox(f, 'FencePlank', V(xm - 0.5, 0, za), V(xm + 0.5, hk, zb), col)
			-- (a wedge rises toward its local +Z: turn that away from the street)
			studs(f:wedge('FencePlankTop', V(math.abs(w), 1.8, 1), CFrame.new(xm, hk + 0.9, (za + zb) / 2) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0), col, M.Plastic), true)
			if k % 4 == 0 and k > 0 and not inGap(za - 1, za + 1) then
				local p0, p1 = x - 0.7 + math.min(0, side * 0.5), x + 0.7 + math.max(0, side * 0.5)
				sbox(f, 'FencePost', V(p0, 0, za - 0.7), V(p1, h + 2.2, za + 0.7), P.st.plankDark)
				sbox(f, 'FencePostCap', V(p0 - 0.2, h + 2.2, za - 0.9), V(p1 + 0.2, h + 2.7, za + 0.9), P.st.fence[1], true)
			end
		end
	end
	cap()
	for _, g in gaps or {} do
		local ga, gb = math.min(g[1], g[2]), math.max(g[1], g[2])
		for _, zp in { ga, gb } do
			sbox(f, 'GatePost', V(x - 0.8, 0, zp - 0.8), V(x + 0.8, h + 3, zp + 0.8), P.st.plankDark)
			sbox(f, 'GatePostCap', V(x - 1.0, h + 3, zp - 1.0), V(x + 1.0, h + 3.6, zp + 1.0), P.st.fence[1], true)
		end
		-- the gate leaf, hinged on the far post and swung ~70 degrees into the yard
		local leaf = f:at(CFrame.new(x, 0, gb - 0.8) * CFrame.Angles(0, side * math.rad(70), 0))
		local len = gb - ga - 1.8
		sbox(leaf, 'GateLeaf', V(-0.3, 0.8, -len), V(0.3, h - 0.4, 0), P.st.fence[3], true)
		for _, y in { 2, h - 1.8 } do sbox(leaf, 'GateBatten', V(-0.45, y, -len + 0.2), V(0.45, y + 0.6, -0.2), P.st.plankDark, true) end
	end
	return f
end
-- Low white picket fence along Z (a front-garden boundary): pointed pickets on two rails, square posts with caps every
-- ~6 studs; gaps = { { za, zb } } leave gateways between posts. side = the street's direction.
local function picketFence(c, x, z0, z1, side, gaps)
	local f = c:group('PicketFence')
	local white, rail = C(240, 240, 234), C(206, 206, 200)
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local function inGap(z)
		for _, g in gaps or {} do if z > math.min(g[1], g[2]) - 0.6 and z < math.max(g[1], g[2]) + 0.6 then return true end end
		return false
	end
	-- rails run between gaps
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			for _, y in { 1.4, 3.2 } do decor(f:box('PicketRail', V(x - side * 0.25 - 0.2, y, a), V(x - side * 0.25 + 0.2, y + 0.4, b), rail, M.Plastic)) end
			for z = a, b + 0.01, math.max(1, (b - a) / math.max(1, math.floor((b - a) / 6 + 0.5))) do
				sbox(f, 'PicketPost', V(x - 0.5, 0, z - 0.5), V(x + 0.5, 4.8, z + 0.5), white)
				sbox(f, 'PicketPostCap', V(x - 0.65, 4.8, z - 0.65), V(x + 0.65, 5.2, z + 0.65), rail, true)
			end
		end
	end
	for z = za + 0.9, zb - 0.6, 1.25 do
		if not inGap(z) then
			sbox(f, 'Picket', V(x - 0.2, 0, z - 0.35), V(x + 0.2, 3.9, z + 0.35), white)
			f:wedge('PicketTip', V(0.4, 0.6, 0.7), CFrame.new(x, 4.2, z) * CFrame.Angles(0, math.pi / 2, 0), white, M.SmoothPlastic)
		end
	end
	return f
end
-- Low brick garden wall along Z with a stone coping and an iron railing on top; brick piers with stone caps and ball
-- finials at its ends and either side of each gateway (gaps = { { za, zb } }). side = the street's direction.
local function gardenWall(c, x, z0, z1, side, gaps)
	local f = c:group('GardenWall')
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			sbox(f, 'GardenWall', V(x - 0.6, 0, a), V(x + 0.6, 3.0, b), P.st.brickDark)
			sbox(f, 'GardenCoping', V(x - 0.85, 3.0, a), V(x + 0.85, 3.45, b), P.st.trim)
			for z = a + 1, b - 0.9, 1.6 do decor(f:box('GardenRailBar', V(x - 0.1, 3.45, z - 0.1), V(x + 0.1, 5.4, z + 0.1), P.iron, M.Plastic)) end
			decor(f:box('GardenRail', V(x - 0.15, 5.2, a), V(x + 0.15, 5.5, b), P.iron, M.Plastic))
		end
	end
	for _, z in cuts do
		sbox(f, 'GardenPier', V(x - 1.0, 0, z - 1.0), V(x + 1.0, 4.4, z + 1.0), P.st.brick)
		sbox(f, 'GardenPierCap', V(x - 1.2, 4.4, z - 1.2), V(x + 1.2, 4.9, z + 1.2), P.st.trim, true)
		decor(f:part('GardenFinial', V(1.1, 1.1, 1.1), CFrame.new(x, 5.45, z), P.st.trim, M.Plastic, Enum.PartType.Ball))
	end
	return f
end
-- Tall street lamp (~27 studs) in three navy tones: a dark plinth, a studded base block with a lighter service
-- door, a square pole with two dark collars, a cap and finial, and a 1-stud arm out over the sidewalk (a rising strut,
-- then level) ending in a small head with a lighter rim and a thin warm light under its tip. dir points at the road.
local function lantern(c, pos, dir)
	dir = dir or V(1, 0, 0)
	local l = c:at(CFrame.lookAt(pos, pos - dir)):group('Lamp') -- (lookAt's -Z points away from the road: the arm runs along local +Z)
	local col, dark, lite = P.st.lamp, P.st.lampDark, P.st.lampLight
	sbox(l, 'LampPlinth', V(-2.1, -0.2, -2.1), V(2.1, 0.7, 2.1), dark)
	sbox(l, 'LampBase', V(-1.7, 0.7, -1.7), V(1.7, 2.8, 1.7), col)
	sbox(l, 'LampDoor', V(-0.7, 1.0, 1.7), V(0.7, 2.4, 1.85), lite, true)
	sbox(l, 'LampPole', V(-0.9, 2.8, -0.9), V(0.9, 26.4, 0.9), col)
	for _, y in { 6, 21.6 } do sbox(l, 'LampCollar', V(-1.15, y, -1.15), V(1.15, y + 0.6, 1.15), dark, true) end
	sbox(l, 'LampCap', V(-1.2, 26.4, -1.2), V(1.2, 27.4, 1.2), dark)
	sbox(l, 'LampFinial', V(-0.5, 27.4, -0.5), V(0.5, 28.2, 0.5), col, true)
	studs(decor(l:bar('LampStrut', V(0, 22.4, 0.6), V(0, 25.2, 4), 1, col, M.Plastic)), true)
	sbox(l, 'LampArm', V(-0.5, 24.7, 3.4), V(0.5, 25.7, 10.4), col, true)
	sbox(l, 'LampHead', V(-0.7, 24.6, 8.2), V(0.7, 25.9, 10.9), col, true)
	sbox(l, 'LampHeadRim', V(-0.8, 24.25, 8.0), V(0.8, 24.6, 11.1), lite, true)
	decor(l:box('LampGlow', V(-0.45, 24.1, 9.4), V(0.45, 24.25, 10.7), P.st.lampGlow, M.Neon)).CastShadow = false
	return l
end
-- Small flower: a green stem and four dark blue petals round a yellow eye (~2 wide, 2.6 tall).
local function flower(c, pos, seed)
	local r = Random.new(seed or 1)
	local f = c:at(CFrame.new(pos) * CFrame.Angles(math.rad(r:NextNumber(-8, 8)), math.rad(r:NextNumber(0, 90)), math.rad(r:NextNumber(-8, 8)))):group('Flower')
	decor(f:box('Stem', V(-0.25, 0, -0.25), V(0.25, 2.1, 0.25), P.st.stem, M.Plastic))
	decor(f:box('Leaf', V(0.25, 0.7, -0.2), V(0.9, 1.0, 0.2), P.st.stem, M.Plastic))
	decor(f:box('Petal', V(-1.1, 2.1, -0.4), V(1.1, 2.5, 0.4), P.st.petal, M.Plastic))
	decor(f:box('Petal', V(-0.4, 2.1, -1.1), V(0.4, 2.5, 1.1), P.st.petal, M.Plastic))
	decor(f:box('Eye', V(-0.3, 2.5, -0.3), V(0.3, 2.7, 0.3), P.st.petalEye, M.Plastic))
	return f
end
-- Tuft of grass blades (three thin green sticks).
local function tuft(c, pos, seed)
	local r = Random.new(seed or 1)
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(r:NextNumber(0, 180)), 0)):group('Tuft')
	for k, d in { V(-0.5, 0, 0), V(0.1, 0, 0.3), V(0.6, 0, -0.2) } do
		local hgt = 1.0 + k * 0.25
		decor(t:part('Blade', V(0.28, hgt, 0.28), CFrame.new(d + V(0, hgt / 2, 0)) * CFrame.Angles(math.rad(r:NextNumber(-12, 12)), 0, math.rad(r:NextNumber(-12, 12))), P.st.grass:Lerp(P.black, 0.18), M.Plastic))
	end
	return t
end
-- The reference's big green dumpster (8 long along Z, 5 deep, 6 tall), studded, in three greens: the body, two
-- darker ribs down the front and a darker rim; side bars, black wheels, rubbish heaped over it in small orange, brown
-- and dark bits, and its lid flung open from the back (+X) edge, leaning out over the street side. The front, the
-- street side, faces local -X.
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local col, dark = P.st.dumpster, P.st.dumpsterDark
	sbox(d, 'DumpsterBody', V(-2.5, 0.7, -4), V(2.5, 5.6, 4), col)
	sbox(d, 'DumpsterRim', V(-2.8, 5.2, -4.3), V(2.8, 6.0, 4.3), dark, true)
	for _, z in { -1.6, 1.6 } do sbox(d, 'DumpsterRib', V(-2.75, 0.9, z - 0.4), V(-2.5, 5.2, z + 0.4), dark, true) end
	for _, z in { -4.25, 4.0 } do sbox(d, 'DumpsterBar', V(-1.6, 3.6, z), V(1.6, 4.1, z + 0.25), P.st.gutter, true) end
	for _, x in { -1.8, 1.8 } do
		for _, z in { -3.2, 3.2 } do decor(d:part('DumpsterWheel', V(0.6, 1.1, 1.1), CFrame.new(x, 0.55, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	decor(d:box('DumpsterInside', V(-2.3, 5.5, -3.8), V(2.3, 5.9, 3.8), C(52, 44, 40), M.Plastic))
	local r = Random.new(7)
	local bits = { P.st.garbage, P.st.garbage, C(120, 76, 46), C(60, 56, 54), C(250, 170, 60) }
	for k = 1, 14 do
		local x, z, sz = r:NextNumber(-1.9, 1.6), r:NextNumber(-3.3, 3.0), r:NextNumber(0.6, 1.1)
		decor(d:box('Rubbish', V(x, 5.8, z), V(x + sz, 5.9 + r:NextNumber(0.3, 0.9), z + sz), bits[k % #bits + 1], M.Plastic)).CastShadow = false
	end
	-- the lid, hinged on the back top edge, leaning ~25 degrees past upright toward the street
	local lid = d:at(CFrame.new(2.8, 6.0, 0) * CFrame.Angles(0, 0, math.rad(-65)))
	sbox(lid, 'DumpsterLid', V(-5.4, 0, -4.3), V(0, 0.5, 4.3), dark, true)
	sbox(lid, 'DumpsterLidRib', V(-4.6, 0.5, -3.6), V(-0.6, 0.8, 3.6), col, true)
	return d
end
-- Hood street furniture, in the same chunky studded style. Fire hydrant: red barrel on a darker foot, collar and cap,
-- side nozzles and a silver front cap.
local function hydrant(c, pos)
	local h = c:at(CFrame.new(pos)):group('Hydrant')
	local red, dark = C(226, 56, 48), C(168, 36, 34)
	sbox(h, 'HydrantFoot', V(-1, 0, -1), V(1, 0.5, 1), dark)
	sbox(h, 'HydrantBody', V(-0.7, 0.5, -0.7), V(0.7, 2.6, 0.7), red)
	sbox(h, 'HydrantCollar', V(-0.85, 2.6, -0.85), V(0.85, 2.9, 0.85), dark)
	sbox(h, 'HydrantCap', V(-0.5, 2.9, -0.5), V(0.5, 3.5, 0.5), red)
	sbox(h, 'HydrantNozzles', V(-1.1, 1.5, -0.35), V(1.1, 2.1, 0.35), dark, true)
	sbox(h, 'HydrantFront', V(-0.35, 1.45, -1.05), V(0.35, 2.15, -0.7), C(206, 208, 214), true)
	return h
end
-- A heap of black trash bags: lumpy studded blocks, each tied off with a small knot.
local function trashBags(c, cf, n)
	local t = c:at(cf):group('TrashBags')
	local spots = { { 0, 0, 0, 2.2, 1.8 }, { 1.7, 0, 0.9, 1.8, 1.5 }, { 0.6, 1.6, 0.4, 1.7, 1.4 }, { -1.5, 0, 0.6, 1.6, 1.4 } }
	for k = 1, n or 3 do
		local s = spots[k]
		local b = t:at(CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, k * 0.7, (k % 2 - 0.5) * 0.25))
		sbox(b, 'TrashBag', V(-s[4] / 2, 0, -s[4] / 2), V(s[4] / 2, s[5], s[4] / 2), C(44, 46, 54))
		sbox(b, 'TrashBagKnot', V(-0.3, s[5], -0.3), V(0.3, s[5] + 0.5, 0.3), C(30, 32, 38), true)
	end
	return t
end
-- Wheelie bin: a dark green studded body on two wheels with a darker lid and handle (front = local -X).
local function wheelieBin(c, cf, color)
	local b = c:at(cf):group('WheelieBin')
	color = color or C(40, 120, 70)
	sbox(b, 'BinBody', V(-1.2, 0.5, -1.3), V(1.2, 3.8, 1.3), color)
	sbox(b, 'BinLid', V(-1.4, 3.8, -1.4), V(1.5, 4.2, 1.4), color:Lerp(P.black, 0.25))
	sbox(b, 'BinHandle', V(1.2, 3.4, -1.0), V(1.6, 3.8, 1.0), C(30, 32, 36), true)
	for _, z in { -0.9, 0.9 } do decor(b:part('BinWheel', V(0.5, 1, 1), CFrame.new(1.0, 0.5, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	return b
end
-- A boombox (the hood touch on a crate): black case, two silver-rimmed speakers, a handle on top (front = local -Z).
local function boombox(c, cf)
	local b = c:at(cf):group('Boombox')
	sbox(b, 'BoomboxCase', V(-1.5, 0, -0.5), V(1.5, 1.5, 0.5), C(36, 38, 44))
	for _, x in { -0.8, 0.8 } do
		decor(b:part('BoomboxSpeaker', V(0.12, 1.0, 1.0), CFrame.new(x, 0.75, -0.55) * CFrame.Angles(0, math.pi / 2, 0), C(190, 194, 202), M.Plastic, Enum.PartType.Cylinder))
		decor(b:part('BoomboxCone', V(0.14, 0.6, 0.6), CFrame.new(x, 0.75, -0.6) * CFrame.Angles(0, math.pi / 2, 0), C(60, 62, 70), M.Plastic, Enum.PartType.Cylinder))
	end
	sbox(b, 'BoomboxHandle', V(-1.1, 1.5, -0.15), V(1.1, 1.9, 0.15), C(190, 194, 202), true)
	return b
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
-- A parked bike leaning on its stand (along local Z): black wheels with silver hubs, a coloured frame (two tubes and
-- the fork), a black seat and silver handlebar.
local function bike(c, cf, color)
	local k = c:at(cf * CFrame.Angles(0, 0, math.rad(8))):group('Bike')
	color = color or C(230, 60, 60)
	for _, z in { -1.7, 1.7 } do
		decor(k:part('BikeWheel', V(0.3, 2.3, 2.3), CFrame.new(0, 1.15, z), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder))
		decor(k:part('BikeHub', V(0.36, 0.6, 0.6), CFrame.new(0, 1.15, z), C(200, 204, 210), M.Plastic, Enum.PartType.Cylinder))
	end
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.4, -0.2), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 2.4, -0.2), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, -1.7), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.9, 1.2), 0.25, color, M.Plastic))
	decor(k:box('BikeSeat', V(-0.3, 2.5, 1.0), V(0.3, 2.75, 1.7), C(30, 30, 34), M.Plastic))
	decor(k:box('BikeBars', V(-0.9, 2.9, -1.45), V(0.9, 3.1, -1.25), C(200, 204, 210), M.Plastic))
	decor(k:bar('BikeStem', V(0, 2.5, -1.3), V(0, 2.95, -1.35), 0.25, C(200, 204, 210), M.Plastic))
	return k
end
-- Corner-store produce crates on a pallet: open wooden crates (studded, darker rims) heaped with fruit blocks.
local function storeCrates(c, cf, n)
	local k = c:at(cf):group('StoreCrates')
	pallet(k, CFrame.new())
	local fruit = { C(236, 64, 52), C(255, 170, 40), C(130, 210, 60), C(255, 222, 70) }
	local spots = { { -1.1, 0.8, -0.2 }, { 1.1, 0.8, 0.1 }, { 0, 2.4, 0 } }
	for j = 1, n or 3 do
		local p = spots[j]
		local b = k:at(CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, (j - 2) * 0.12, 0))
		sbox(b, 'Crate', V(-1.0, 0, -1.3), V(1.0, 1.6, 1.3), P.crate)
		sbox(b, 'CrateRim', V(-1.05, 1.3, -1.35), V(1.05, 1.65, 1.35), P.woodDark, true)
		for q = 0, 3 do
			local fx, fz = (q % 2) * 0.9 - 0.45, (q // 2) * 1.1 - 0.55
			decor(b:box('Fruit', V(fx - 0.4, 1.55, fz - 0.45), V(fx + 0.4, 2.1, fz + 0.45), fruit[(j + q) % #fruit + 1], M.Plastic))
		end
	end
	return k
end
-- A plywood board with a spray-painted tag, leaning back against whatever is behind it (front = local -Z):
-- the board, two darker battens and the tag.
local function graffitiBoard(c, cf, text, color)
	local k = c:at(cf * CFrame.Angles(math.rad(-10), 0, 0)):group('GraffitiBoard')
	local board = sbox(k, 'Board', V(-3, 0, -0.15), V(3, 4.6, 0.15), C(214, 172, 116))
	for _, y in { 0.8, 3.8 } do sbox(k, 'Batten', V(-3.1, y - 0.25, 0.15), V(3.1, y + 0.25, 0.4), C(160, 118, 72), true) end
	local g = surface(board, Enum.NormalId.Front, 20)
	line(g, 'Tag', text, color, FONT.tag, 0.12, 0.76, P.black, 3).Rotation = -8
	return k
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

-- Fight pad: a glowing coloured square with a white border and its number painted on top. hidden: only an
-- invisible marker with the same model, tag and attributes (the reference street's road has no pad on it).
local function fightPad(c, n, pos, color, district, size, label, hidden)
	size = size or PAD_SIZE
	local h = size / 2
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	model:SetAttribute('Fight', n)
	model:SetAttribute('District', district)
	model:AddTag('HoodFightPad')
	if hidden then
		local marker = ghost(pad:box('PadMarker', V(-h, 0, -h), V(h, 0.2, h), color, M.SmoothPlastic))
		marker.CastShadow = false
		return model, pad
	end
	pad:box('PadBorder', V(-h - 0.5, 0, -h - 0.5), V(h + 0.5, 0.3, h + 0.5), P.white, M.SmoothPlastic)
	local top = pad:box('Pad', V(-h + 0.3, 0, -h + 0.3), V(h - 0.3, 0.36, h - 0.3), color, M.SmoothPlastic)
	decor(pad:box('PadGlow', V(-h, 0.3, -h), V(h, 0.33, h), color:Lerp(P.white, 0.35), M.Neon)).CastShadow = false
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), P.white, FONT.loud, 0.18, 0.64, C(20, 24, 40), 6)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color, 1.2, 10, 120
	glow.Parent = top
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

-- A pad's slab, as on the reference street: a flat slab (opts: w, d (size; default 7 x 4), y (the floor it sits on), h
-- (thickness), material (default Neon), base (colour of a thin dark plate under it, showing as a rim), shade + rim (the
-- slab's sides take the darker shade and the top gets a neon edge in rim around an inset top in the pad's colour),
-- sparkle (a few rising sparkles), arrow (+1/-1: two glowing chevrons on the top pointing along Z)). Returns the slab
-- (the only solid part) and every part it made; each carries BaseTransparency, BaseColor and BaseMaterial for the clients
-- (HoodClient/Stages dims a pad that can't pay yet).
local function padSlab(g, name, x, z, color, opts)
	local w, d, y, h = opts.w or 7, opts.d or 4, opts.y or 0, opts.h or 0.42
	local parts = {}
	if opts.base then
		table.insert(parts, decor(g:box(name .. 'Base', V(x - w / 2 - 0.3, y, z - d / 2 - 0.3), V(x + w / 2 + 0.3, y + 0.15, z + d / 2 + 0.3), opts.base, M.SmoothPlastic)))
		y += 0.15
	end
	local pad = g:box(name, V(x - w / 2, y, z - d / 2), V(x + w / 2, y + h, z + d / 2), opts.shade or color, opts.material or M.Neon)
	table.insert(parts, pad)
	if opts.rim then
		local rim = decor(g:box(name .. 'Rim', V(x - w / 2, y + h, z - d / 2), V(x + w / 2, y + h + 0.05, z + d / 2), opts.rim, M.Neon))
		rim.CastShadow = false
		local top = decor(g:box(name .. 'Top', V(x - w / 2 + 0.35, y + h + 0.05, z - d / 2 + 0.35), V(x + w / 2 - 0.35, y + h + 0.1, z + d / 2 - 0.35), color, opts.material or M.Neon))
		table.insert(parts, rim)
		table.insert(parts, top)
		-- Two glowing chevrons on the top pointing where the pad sends you (opts.arrow: +1 toward +Z, -1 toward -Z).
		if opts.arrow then
			local f = opts.arrow
			for _, za in { z + f * 0.4, z + f * 2.2 } do
				for _, sx in { -1, 1 } do
					local c = V(x + sx * 0.5, y + h + 0.12, za - f * 0.5)
					local bar = decor(g:part(name .. 'Chevron', V(0.4, 0.05, 1.5), CFrame.lookAt(c, c + V(sx, 0, -f)), opts.rim, M.Neon))
					bar.CastShadow = false
					table.insert(parts, bar)
				end
			end
		end
		if opts.sparkle then
			local sp = Instance.new('ParticleEmitter')
			sp.Name = 'PadSparkles'
			sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
			sp.Rate = 5
			sp.Lifetime, sp.Speed = NumberRange.new(0.8, 1.4), NumberRange.new(1.5, 3)
			sp.SpreadAngle = Vector2.new(12, 12)
			sp.EmissionDirection = Enum.NormalId.Top
			sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			sp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			sp.Color = ColorSequence.new(opts.rim)
			sp.LightEmission = 1
			sp.Parent = top
		end
	end
	for _, p in parts do
		p:SetAttribute('BaseTransparency', 0)
		p:SetAttribute('BaseColor', p.Color)
		p:SetAttribute('BaseMaterial', p.Material.Name)
	end
	return pad, parts, y + h
end
-- Teleport pad (a slab with a prompt; StageService handles the targets StageRules.travelTarget knows). opts as padSlab's,
-- plus title + sub (a floating label read up close, sub in labelColor, both in font) or bare (no floating label).
local function teleportPad(g, name, x, z, color, target, label, opts)
	opts = opts or {}
	local pad, _, topY = padSlab(g, name, x, z, color, opts)
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
	if opts.title then
		-- Read up close only: HoodClient/LabelFade fades it with the distance (kind Pad) and sets MaxDistance itself.
		local anchor = ghost(g:part(name .. 'Label', V(0.2, 0.2, 0.2), CFrame.new(x, topY + 4.6, z), P.white))
		anchor:SetAttribute('BaseTransparency', 1)
		local gui = Instance.new('BillboardGui')
		gui.Name = 'WorldLabel'
		gui.Size = UDim2.fromScale(9.5, 3.1)
		gui.MaxDistance = 45
		gui.LightInfluence = 0
		gui.Parent = anchor
		-- (the world's text face, the references' Montserrat Black, with a near-black outline)
		line(gui, 'Title', opts.title, C(240, 242, 248), opts.font or FONT.title, 0, 0.58, C(16, 18, 30), 3)
		line(gui, 'Sub', opts.sub or '', opts.labelColor or color, opts.font or FONT.title, 0.6, 0.36, C(16, 18, 30), 2)
	elseif not opts.bare then
		billboard(g, V(x, topY + 3, z), 6, 1.4, { { 'Title', label, P.white, opts.font or FONT.title, 0, 1 } }).WorldLabel.MaxDistance = 50
	end
	return pad
end
-- A stage pad (brief 23, the reference's two pads before every gate): step on it, no prompt. The slab is tagged
-- HoodStagePad with attributes Stage (the crew stage it pays for) and Kind ('Return': yellow, + the stage's Cash and back
-- to the lobby; 'TenX': magenta, 10x that with the 10x Cash pass); StageService pays and HoodClient/Stages paints it
-- (dim until the crew is down, then lit) and writes its label. opts as padSlab's, plus label: { big, small, price,
-- color } (the label's first words; the client keeps them current) and font.
-- The label (the reference's "2M Wins / 10x Wins"): a BillboardGui WorldLabel on the anchor <name>Label, big words in
-- the pad's colour over small white ones (and the pass's Robux price on the magenta pad), a thick dark outline; it fades
-- and pops with the distance (HoodClient/LabelFade, kind Pad: FadeNear / FadeFar below).
-- (CRITIC3 r2: "+10 Cash" reads from the gate you came in by, ~60 studs, as the reference's pad words read down the
-- corridor; the next stage's pads, 64 further, stay hidden)
-- (Px: a few pixels on top of the studs, so far away the words keep a readable size on screen; up close the studs rule.)
-- (brief 28: the pads stand just in front of their gate, so the label's top meets the gate sign's foot (7.4 studs up)
-- seen from the stage's entry: it sits a stud lower, with fewer extra pixels, and HoodClient/Stages lifts a far sign a
-- little, so "+100 Cash", the sign's lines and "+10 Cash" each read on their own.)
local PAD_LABEL = { W = 11, H = 4.6, PxW = 72, PxH = 22, Up = 3.4, Near = 60, Far = 80, Ink = C(26, 14, 38) }
local function stagePad(g, name, x, z, color, stage, kind, opts)
	local pad, parts, topY = padSlab(g, name, x, z, color, opts)
	pad.CanTouch = true
	pad:SetAttribute('Stage', stage)
	pad:SetAttribute('Kind', kind)
	pad:AddTag('HoodStagePad')
	local label = opts.label or {}
	local anchor = ghost(g:part(name .. 'Label', V(0.2, 0.2, 0.2), CFrame.new(x, topY + PAD_LABEL.Up, z), P.white))
	anchor:SetAttribute('BaseTransparency', 1)
	local gui = Instance.new('BillboardGui')
	gui.Name = 'WorldLabel'
	gui.Size = UDim2.new(PAD_LABEL.W, PAD_LABEL.PxW, PAD_LABEL.H, PAD_LABEL.PxH)
	gui.MaxDistance = PAD_LABEL.Far + 15
	gui.LightInfluence = 0
	gui:SetAttribute('FadeNear', PAD_LABEL.Near)
	gui:SetAttribute('FadeFar', PAD_LABEL.Far)
	gui.Parent = anchor
	local font = opts.font or FONT.title
	local big = line(gui, 'Title', label.big or '', label.color or color, font, 0, 0.52, PAD_LABEL.Ink, 3.5)
	big:SetAttribute('BaseColor', big.TextColor3)
	local small = line(gui, 'Sub', label.small or '', P.white, font, 0.5, 0.29, PAD_LABEL.Ink, 2.5)
	small:SetAttribute('BaseColor', small.TextColor3)
	local price = line(gui, 'Price', label.price or '', C(120, 236, 96), font, 0.78, 0.22, PAD_LABEL.Ink, 2)
	price.Visible = label.price ~= nil and label.price ~= ''
	return pad, parts
end
---------------------------------------------------------------------------------------------- training stations
-- Shooting-range lanes (the game trains with guns). Each lane keeps the bag stations' frame and themes: a long
-- flat studded mat (7 x 18) in a low two-tone rim with stepped pixel corners and a stamped row of X's on the
-- aisle face. The aisle end of the mat is the shooter's box (the TrainingZone); a waist-high bench marks the
-- firing line; the targets stand in the far half in front of a backstop at the outer end, and from tier 3 a
-- grooved truss gantry (the old gallows' truss) spans the lane over them. Every tier keeps its theme and its
-- effects and adds one new thing, so each lane reads as better than the last:
--   1 stone   a crate stack (3-2-1) with a painted bullseye; soda bottles and cans on a plank shelf
--   2 red     a carnival booth (bulb pillars, striped awning, roof sign); bullseye boards pop up on spring posts (rain)
--   3 lava    a forge with a glowing mouth and a burning chimney; a gong and plates under an L gallows (fire)
--   4 arcane  a billboard on legs (marquee bulbs, spotlights, starburst); a spinner disc, balloons (comets)
--   5 shadow  a pixel arch with a dark neon-lit opening; neon plates, the main one swinging from the keystone
--   6 frost   an ice castle (turrets, battlements, icicles); an ice bullseye on a pillar, ice blocks (snow, sparkles)
--   7 toxic   stacked shipping containers with a hazard sign; a toxic barrel stack with a target face, bottles
--   8 gold    a winners' podium (1-2-3) with a rayed backdrop; a giant trophy (main), the turning crown, gold bottles
-- Every main target's centre sits ~5.8 over the mat, above the shooter's head from the follow camera.
-- Cartoon targets only: bottles, cans, bullseyes, plates, balloons, ice, barrels. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~11.5,
-- labels float to ~16. opts.vfx = false skips effects, opts.tier overrides the tier, opts.labelLift raises the
-- label stack (the lobby staggers neighbouring stacks); opts.side is ignored.
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
-- (Oct 27, the owner: "make the colors the same also as the references ... make it feel more cartoony";
-- ref_STILL_training_lanes_superhero.png) every bay is ONE bright hue: the mat in it, the gantry and stands in it, a
-- darker cut of it as the outline rim, a lighter one on the lip. Eight hues like the reference's (grey, red, orange,
-- purple, blue, cyan, green, yellow), each the one its theme's props and effects already suit (the name picks them),
-- so the colour alone tells the bays apart from across the hall.
local function hue(name, base, text)
	return { name = name, rim = base:Lerp(C(0, 0, 0), 0.45), rimTop = base:Lerp(C(255, 255, 255), 0.35), mat = base,
		frame = base:Lerp(C(0, 0, 0), 0.12), groove = base:Lerp(C(0, 0, 0), 0.22), trim = base:Lerp(C(0, 0, 0), 0.45),
		wallCap = base:Lerp(C(255, 255, 255), 0.5), text = text or base:Lerp(C(255, 255, 255), 0.2), glow = base:Lerp(C(255, 255, 255), 0.3) }
end
Stations.Themes = {
	(function() local t = hue('stone', C(150, 158, 178), C(255, 255, 255)) t.glow = C(255, 236, 200) return t end)(), -- BAY 1 x1: grey
	hue('red', C(240, 40, 44), C(255, 80, 80)), -- BAY 2 x4: red (red rain)
	hue('lava', C(255, 134, 22)), -- BAY 3 x10: orange (fire)
	hue('arcane', C(160, 64, 240), C(200, 130, 255)), -- BAY 4 x20: purple
	hue('shadow', C(40, 112, 250), C(110, 170, 255)), -- BAY 5 x35: blue
	hue('frost', C(36, 206, 250)), -- BAY 6 x50: cyan (snow)
	hue('toxic', C(56, 214, 64), C(110, 255, 100)), -- PRO BAY x100: green
	(function() local t = hue('gold', C(255, 214, 24), C(255, 222, 50)) t.trim = C(175, 18, 48) t.labelLift = 0.3 return t end)(), -- GOLD BAY x250: yellow
	-- (B30) 9: the HEAD LANE, the gold lane's kit in a richer cut (a crimson rim under a gold lip, a pale-gold mat) and its
	-- label in the reference's 250x cyan (#2EC8E0, ref_W06.5_train_aisle_endcap_250x.jpg)
	{ name = 'gold', rim = C(178, 22, 52), rimTop = C(255, 222, 60), mat = C(255, 240, 150), frame = C(245, 192, 0), groove = C(214, 160, 30),
		trim = C(175, 18, 48), wallCap = C(255, 244, 200), text = C(46, 200, 224), glow = C(255, 230, 110), labelLift = 0.3 },
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
Stations.LABEL = V(0, 12.6, 4.4) -- the label stack, over the dummy (B30: about an avatar's height over its head, the reference's)
Stations.Style = 'themed' -- (B31) 'themed': the old themed bays without side walls; 'soldier': B30's soldier pads
Stations.THEMED_LABEL = V(0, 14.4, 3.6) -- the themed bays' label stack, over their gear (as before 39b16b0)
Stations.StampId = '' -- set from HoodVFX.Textures.stamp at build time ('' until the PNG is uploaded)
-- (B35, the owner: "make the layout of the shooting ranges better ... way more optimal") the compact bay: each themed lane
-- is built at its full 20 and then pulled together along its length (Stations.compact) to what shooting needs, 13 deep:
-- the shooter's box shrinks to 3 studs at the bench, and the empty strip between the bench and the targets goes. Pieces
-- in front of `Front1` move back by Front, the bench and its marks (up to `Cut`) by Bench, everything past it forward by
-- Back; a straight piece that spans a cut (the rim, the mat, the box, the effects field) is stretched between its ends.
Stations.Compact = { Front = 3.5, Back = 3.5, Bench = -0.3, Cut = -1.5, Front1 = -7 }
-- (Oct 27, the owner: "make the shooting ranges longer") the bays in the rows keep their full 20; only the head lane,
-- which closes the aisle against the west wall, is still pulled together (CompactOnly).
Stations.CompactOnly = { Head = true }
Stations.LaneHalf = Stations.HALF_Z -- a row bay's half length (10); the lobby lays out on it
Stations.HeadHalf = Stations.HALF_Z - Stations.Compact.Back -- the compact head lane's half length (6.5)

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
	local seg, g = len / n, 0.16
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
	-- a glowing strip along the lip's aisle face in the lane's hit colour: the lane's interactive outline, where you
	-- step on (toxic's lip glows already)
	if t.rimTopMat ~= M.Neon then
		decor(st:box('RimGlow', V(-MX + 0.1, 0.47, -Stations.HALF_Z + 0.07), V(MX - 0.1, 0.57, -Stations.HALF_Z + 0.14), t.edge or t.glow, M.Neon)).CastShadow = false
	end
end

-- The shooter's end: a waist-high bench across the lane (a dark kick plate, a stamped front with four X's, a
-- band in the theme's trim colour, a studded top in the lip colour) with an ammo box, a few shells and ear
-- muffs on it; in front of it a yellow and black hazard stripe (the firing line); in the box two shoe prints and
-- (brief 29: no number painted on the mat).
function Stations.bench(st, t, tier)
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	local body = t.frame
	local mat = t.frameMat == M.Neon and M.SmoothPlastic or (t.frameMat or M.SmoothPlastic)
	if t.frameMat == M.Neon then body = t.rim end -- a neon bench would glare: toxic gets its rim green
	local kick = body:Lerp(C(0, 0, 0), 0.35)
	g:box('BenchKick', V(-3.45, Y, z - 0.47), V(3.45, Y + 0.32, z + 0.4), kick)
	local front = g:box('BenchFront', V(-3.4, Y + 0.32, z - 0.42), V(3.4, Y + h - 0.62, z + 0.42), body, mat)
	Stations.panelX(g, front, CFrame.new(0, Y + 0.32 + (h - 0.94) / 2, z - 0.42), 6.8, h - 0.94, 3, Stations.grooveFor(t, body))
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
	for i, s in { { 1.45, -0.15, 0.3 }, { 1.7, 0.08, 1.4 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(s[1], y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), i == 2 and C(232, 176, 72) or C(244, 194, 80), M.Metal, Enum.PartType.Cylinder))
	end
	-- Ear muffs: two dark cups joined by a yellow band.
	local yellow = C(255, 210, 50)
	for _, sx in { -1, 1 } do
		decor(d:blob('EarCup', V(0.5, 0.55, 0.55), V(-2.6 + sx * 0.42, y + 0.28, z - 0.05), C(50, 52, 60), M.SmoothPlastic))
	end
	decor(d:box('EarArch', V(-3.0, y + 0.5, z - 0.12), V(-2.2, y + 0.64, z + 0.02), yellow)) -- (resting on the cups)
	-- Painted on the mat: the box outline (white on dark mats, the groove colour on pale ones), the hazard
	-- stripe and two shoe prints.
	local m = t.mat
	local pale = 0.299 * m.R + 0.587 * m.G + 0.114 * m.B > 0.7
	local edge = pale and Stations.grooveFor(t, m) or C(250, 250, 245)
	local x0, x1, b0, b1, w = -3.25, 3.25, -8.75, -3.9, 0.14
	for _, b in { { V(x0, Y, b0), V(x1, Y + 0.03, b0 + w) }, { V(x0, Y, b0), V(x0 + w, Y + 0.03, b1) }, { V(x1 - w, Y, b0), V(x1, Y + 0.03, b1) } } do
		local p = decor(st:box('BoxLine', b[1], b[2], edge, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.2
	end
	local fire = decor(st:box('FiringLine', V(-3.5, Y, -3.9), V(3.5, Y + 0.03, -3.5), C(255, 214, 30), M.SmoothPlastic))
	fire.CastShadow = false
	local fg = surface(fire, Enum.NormalId.Top, 20)
	for i = 0, 8 do
		local f = Instance.new('Frame')
		f.Name = 'FiringStripe'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = C(30, 30, 36)
		f.Position, f.Size = UDim2.fromScale((i + 0.2) / 9, 0), UDim2.fromScale(0.5 / 9, 1)
		f.Parent = fg
	end
	for _, sx in { -1, 1 } do
		local x = sx * 0.45
		local sole = decor(st:box('ShoePrint', V(x - 0.3, Y, -5.1), V(x + 0.3, Y + 0.03, -4.0), edge, M.SmoothPlastic))
		sole.CastShadow, sole.Transparency = false, 0.25
	end
	-- (brief 29: no lane number painted on the mat any more; the label says what the lane is)
end

-- The lane's side walls, like the video's lanes walled at the sides (ours hood walls, not sandbags): a low wall on
-- each long side of the rim from just inside the aisle end to the backstop, a dark plinth, the body and a pale
-- studded cap (base, body, cap), a gate pier with a taller cap at the aisle end. Each theme its own wall: brick
-- with a concrete cap (stone), navy block (red), basalt (lava), painted block (arcane), obsidian (shadow), ice with
-- snow (frost), a container's teal steel with a hazard cap (toxic), cream stone on velvet with gold (gold).
-- Walls break round the gantry feet (lanes with a gantry).
Stations.Walls = {
	stone = { body = C(178, 86, 68), base = C(118, 58, 48), cap = C(216, 212, 204), course = C(214, 200, 188), courses = 2 },
	red = { body = C(48, 54, 100), base = C(26, 30, 66), cap = C(240, 62, 86) },
	lava = { body = C(78, 56, 60), base = C(48, 34, 38), cap = C(255, 150, 50) },
	arcane = { body = C(124, 52, 172), base = C(80, 30, 112), cap = C(240, 124, 212) },
	shadow = { body = C(44, 32, 62), base = C(22, 16, 34), cap = C(96, 60, 146) },
	frost = { body = C(150, 222, 248), base = C(30, 110, 210), cap = C(248, 252, 255) },
	toxic = { body = C(26, 72, 66), base = C(14, 42, 40), cap = C(255, 214, 30) },
	gold = { body = C(255, 244, 216), base = C(150, 15, 40), cap = C(255, 214, 40) },
}
Stations.WALL_TOP = 2.55 -- the walls' top over the deck (the bench is 2.7)
function Stations.walls(st, t)
	local w = Stations.Walls[t.name] or Stations.Walls.stone
	local g = st:group('Walls')
	local top, z0, z1 = Stations.WALL_TOP, -8.5, Stations.BACK_Z
	local runs = { { z0 + 0.9, z1 } }
	if t.name ~= 'stone' and t.name ~= 'red' then
		runs = { { z0 + 0.9, Stations.GANTRY_Z - 0.62 }, { Stations.GANTRY_Z + 0.62, z1 } }
	end
	for _, sx in { -1, 1 } do
		local function X(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		for _, r in runs do
			local a0, a1 = X(3.66, 4.5)
			local b0, b1 = X(3.76, 4.42)
			g:box('WallBase', V(a0, Stations.RIM_Y, r[1]), V(a1, 1.0, r[2]), w.base)
			g:box('Wall', V(b0, 1.0, r[1]), V(b1, top - 0.3, r[2]), w.body)
			-- a course line half way up (mortar on brick, a seam on the rest)
			local nc = w.courses or 1
			for k = 1, nc do
				local my = 1.0 + (top - 1.3) * k / (nc + 1)
				decor(g:box('WallCourse', V(b0 - 0.04, my - 0.07, r[1] + 0.05), V(b1 + 0.04, my + 0.07, r[2] - 0.05), w.course or w.base)).CastShadow = false
			end
			studs(g:box('WallCap', V(a0, top - 0.3, r[1]), V(a1, top, r[2]), w.cap))
		end
		-- the gate pier at the aisle end
		local p0, p1 = X(3.62, 4.5)
		g:box('WallPier', V(p0, Stations.RIM_Y, z0), V(p1, top + 0.35, z0 + 0.9), w.base)
		studs(g:box('WallPierCap', V(p0, top + 0.35, z0 - 0.06), V(p1, top + 0.7, z0 + 0.96), w.cap))
	end
	-- a hood prop on the left pier's cap, the lane's own
	local prop = Stations.Hood[t.name]
	if prop then prop(g, CFrame.new(-4.08, top + 0.7, z0 + 0.45)) end
end

-- Small hood props (chunky, a few parts each) standing on `cf` (its top centre of the surface they sit on, -Z out
-- toward the aisle): a traffic cone, a boombox, a milk crate of sodas, a sneaker box, spray cans, a cooler.
Stations.Hood = {}
function Stations.cone(g, cf, color)
	color = color or C(255, 120, 30)
	g:part('ConeFoot', V(0.85, 0.12, 0.85), cf * CFrame.new(0, 0.06, 0), C(40, 40, 46))
	for i, e in { { 0.62, 0.35, color }, { 0.46, 0.3, C(250, 250, 245) }, { 0.32, 0.32, color }, { 0.18, 0.16, color } } do
		local y = 0.12 + (i == 1 and 0 or i == 2 and 0.35 or i == 3 and 0.65 or 0.97)
		g:part('Cone', V(e[1], e[2], e[1]), cf * CFrame.new(0, y + e[2] / 2, 0), e[3])
	end
end
function Stations.boombox(g, cf, body, trim)
	body, trim = body or C(40, 42, 50), trim or C(235, 50, 60)
	g:part('Boombox', V(1.05, 0.55, 0.5), cf * CFrame.new(0, 0.3, 0), body)
	g:part('BoomboxBand', V(1.07, 0.12, 0.52), cf * CFrame.new(0, 0.5, 0), trim)
	local face = CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's axis turned to face -Z, the aisle)
	for _, dx in { -0.27, 0.27 } do
		g:part('BoomboxSpeaker', V(0.06, 0.4, 0.4), cf * CFrame.new(dx, 0.27, -0.26) * face, C(20, 20, 24), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('BoomboxCone', V(0.08, 0.18, 0.18), cf * CFrame.new(dx, 0.27, -0.27) * face, C(150, 156, 170), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	g:part('BoomboxHandle', V(0.8, 0.12, 0.12), cf * CFrame.new(0, 0.72, 0), C(20, 20, 24))
end
function Stations.milkcrate(g, cf, color, sodas)
	g:part('MilkCrate', V(0.86, 0.6, 0.86), cf * CFrame.new(0, 0.3, 0), color)
	g:part('MilkCrateRim', V(0.9, 0.12, 0.9), cf * CFrame.new(0, 0.6, 0), color:Lerp(C(255, 255, 255), 0.25))
	for i, c in sodas or {} do
		local x = (i - (#sodas + 1) / 2) * 0.3
		g:part('Soda', V(0.18, 0.42, 0.18), cf * CFrame.new(x, 0.75, 0.05 * i), c)
		g:part('SodaCap', V(0.1, 0.08, 0.1), cf * CFrame.new(x, 1.0, 0.05 * i), C(250, 250, 245))
	end
end
function Stations.sneakerBox(g, cf, color)
	g:part('ShoeBox', V(0.62, 0.42, 0.98), cf * CFrame.new(0, 0.21, 0), color)
	g:part('ShoeBoxLid', V(0.66, 0.12, 1.02), cf * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(-8)), C(250, 250, 245))
	g:part('Sneaker', V(0.36, 0.22, 0.8), cf * CFrame.new(0.05, 0.65, 0), C(250, 250, 245))
	g:part('SneakerSole', V(0.38, 0.08, 0.82), cf * CFrame.new(0.05, 0.52, 0), color:Lerp(C(0, 0, 0), 0.3))
	g:part('SneakerSwoosh', V(0.37, 0.07, 0.42), cf * CFrame.new(0.05, 0.66, 0.08), color)
end
function Stations.sprayCans(g, cf, colors)
	for i, c in colors do
		local at = cf * CFrame.new((i - 2) * 0.27, 0, (i % 2) * 0.18 - 0.09)
		g:part('SprayCan', V(0.48, 0.24, 0.24), at * CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.pi / 2), c, M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('SprayCap', V(0.12, 0.2, 0.2), at * CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.pi / 2), C(250, 250, 245), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
end
function Stations.cooler(g, cf, color)
	g:part('Cooler', V(0.8, 0.5, 1.0), cf * CFrame.new(0, 0.25, 0), color)
	g:part('CoolerLid', V(0.84, 0.14, 1.04), cf * CFrame.new(0, 0.57, 0), C(250, 250, 245))
	g:part('CoolerHandle', V(0.12, 0.1, 0.6), cf * CFrame.new(0, 0.69, 0), C(40, 44, 54))
end
Stations.Hood.stone = function(g, cf) Stations.cone(g, cf) end
Stations.Hood.red = function(g, cf) Stations.boombox(g, cf) end
Stations.Hood.lava = function(g, cf) Stations.milkcrate(g, cf, C(240, 110, 30), { C(235, 55, 60), C(60, 140, 240) }) end
Stations.Hood.arcane = function(g, cf) Stations.sneakerBox(g, cf, C(240, 90, 180)) end
Stations.Hood.shadow = function(g, cf) Stations.sprayCans(g, cf, { C(160, 80, 255), C(30, 28, 40), C(255, 90, 200) }) end
Stations.Hood.frost = function(g, cf) Stations.cooler(g, cf, C(40, 130, 230)) end
Stations.Hood.toxic = function(g, cf) Stations.milkcrate(g, cf, C(30, 160, 60), { C(60, 220, 90), C(60, 220, 90) }) end
Stations.Hood.gold = function(g, cf) Stations.boombox(g, cf, C(245, 196, 30), C(150, 15, 40)) end

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
		Stations.panelX(c, base, CFrame.new(0, (Y + h) / 2, z0), 8.6, Y + h, 3, groove)
		-- caps over every exposed top, a lighter tone a little proud of the front (finished edges)
		local cap = t.wallCap or t.trim or t.rimTop
		for _, b in { { -4.36, -2.9, Y + h, z0 - 0.08 }, { 2.9, 4.36, Y + h, z0 - 0.08 }, { -2.96, -1.5, Y + h + 0.8, z0 + 0.07 },
			{ 1.5, 2.96, Y + h + 0.8, z0 + 0.07 }, { -1.56, 1.56, Y + h + 1.4, z0 + 0.22 } } do
			c:box('BackstopCap', V(b[1], b[3], b[4]), V(b[2], b[3] + 0.16, z1 + 0.02), cap, M.SmoothPlastic)
		end
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
		Stations.truss(g, 'GantryPost', CFrame.new(x, Y + 0.75, z), y0 - Y - 0.75, W, W, frame, groove, 3.9, { '-z' }, fm)
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
	Stations.truss(g, 'GantryBeam', CFrame.new(-4.35, y0 + W / 2, z) * CFrame.Angles(0, 0, -math.pi / 2), 8.7, W, W, frame, groove, 4.35, { '-z' }, fm)
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
-- (Oct 27, the owner: "make different shooting ranges, follow same concepts of how you made these, but change them up,
-- make different designs") each bay has its own backstop silhouette and its own kind of target, all built from chunky
-- blocks in the bay's one hue with a dark outline (Stations.chunk), like the reference's frames: a crate stack (stone),
-- a carnival booth (red), a forge with a chimney under a gallows (lava), a billboard on legs (arcane), a pixel arch
-- (shadow), an ice castle (frost), stacked shipping containers (toxic), a winners' podium (gold).
Stations.Lanes = {}
Stations.SODA = { red = C(235, 55, 60), orange = C(255, 150, 30), blue = C(60, 140, 240), lime = C(130, 220, 60) }

-- A chunky block with a dark outline: the box a..b in `color`, and just behind its front face (-Z, toward the aisle) a
-- plate `o` bigger all round in `edge`, so from the aisle and from above the block reads with a thick dark rim, the
-- reference's outlined frames. Returns the block.
function Stations.chunk(c, name, a, b, color, edge, material, o)
	o = o or 0.16
	local p = c:box(name, a, b, color, material)
	c:box(name .. 'Edge', V(a.X - o, math.max(0, a.Y - o), a.Z + 0.08), V(b.X + o, b.Y + o, math.min(b.Z - 0.02, a.Z + 0.4)), edge)
	return p
end
-- A blocky digit standing on a face (seven segments, h tall), `cf` the centre of its foot on the face, -Z out of it:
-- readable from the aisle.
function Stations.faceDigit(c, n, cf, h, color)
	local W, th = h * 0.6, h * 0.2
	local seg = {
		a = { -W / 2, W / 2, h - th, h }, g = { -W / 2, W / 2, h / 2 - th / 2, h / 2 + th / 2 }, d = { -W / 2, W / 2, 0, th },
		f = { -W / 2, -W / 2 + th, h / 2, h }, e = { -W / 2, -W / 2 + th, 0, h / 2 }, b = { W / 2 - th, W / 2, h / 2, h }, c = { W / 2 - th, W / 2, 0, h / 2 },
	}
	for ch in string.gmatch(Stations.DIGITS[n] or '', '.') do
		local s = seg[ch]
		-- (u runs to the viewer's right, which is -x for someone at the aisle looking down the lane)
		decor(c:part('Digit', V(s[2] - s[1], s[4] - s[3], 0.1), cf * CFrame.new(-(s[1] + s[2]) / 2, (s[3] + s[4]) / 2, -0.05), color, M.SmoothPlastic)).CastShadow = false
	end
end

-- 1 Stone (grey): a CRATE STACK, six chunky stamped crates in a 3-2-1 pyramid with a painted bullseye on the top one;
-- soda bottles and cans on a plank shelf in front of it; a crate of spare sodas and a tyre stack.
function Stations.Lanes.stone(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local wood, soda, edge = t.frame, Stations.SODA, t.trim
	local back = k.st:group('Backstop')
	local z1 = Stations.HALF_Z - 0.1
	local crates = {
		{ -4.3, -1.5, 0, Y + 2.6, 8.5 }, { -1.4, 1.4, 0, Y + 2.6, 8.3 }, { 1.5, 4.3, 0, Y + 2.6, 8.6 },
		{ -2.85, -0.05, Y + 2.6, Y + 5.2, 8.75 }, { 0.05, 2.85, Y + 2.6, Y + 5.2, 8.6 },
		{ -1.4, 1.4, Y + 5.2, Y + 7.8, 8.9 },
	}
	for i, b in crates do
		local col = i % 2 == 0 and t.rimTop or t.frame:Lerp(C(0, 0, 0), 0.08)
		local p = Stations.chunk(back, 'Crate', V(b[1], b[3], b[5]), V(b[2], b[4] - 0.3, z1), col, edge)
		studs(back:box('CrateLid', V(b[1] - 0.04, b[4] - 0.3, b[5] - 0.04), V(b[2] + 0.04, b[4], z1), t.wallCap))
		local h = b[4] - 0.3 - b[3]
		Stations.panelX(back, p, CFrame.new((b[1] + b[2]) / 2, b[3] + h / 2, b[5]), b[2] - b[1] - 0.5, h - 0.4, 1, Stations.grooveFor(t, col))
	end
	Stations.bullseye(back, CFrame.new(0, Y + 6.4, 8.86), 1.0, { C(250, 250, 245), C(230, 50, 50), C(250, 250, 245), C(230, 50, 50) })
	-- The shelf: two posts, two rails and a deep top rail at chest height the targets stand on.
	local fz, top = 5.0, Y + 4.4
	for _, sx in { -1, 1 } do Stations.chunk(g, 'FencePost', V(sx * 3.05 - 0.28, Y, fz - 0.28), V(sx * 3.05 + 0.28, top + 0.15, fz + 0.28), wood:Lerp(C(0, 0, 0), 0.15), edge, nil, 0.1) end
	for _, ry in { 1.3, 2.9 } do g:box('FenceRail', V(-3.45, Y + ry, fz - 0.15), V(3.45, Y + ry + 0.35, fz + 0.15), wood) end
	Stations.chunk(g, 'FenceShelf', V(-3.5, top - 0.25, fz - 0.95), V(3.5, top, fz + 0.95), t.rimTop, edge, nil, 0.1)
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
	local crate = Stations.chunk(g, 'Crate', V(-3.3, Y, 1.3), V(-1.7, Y + 1.1, 2.7), t.rimTop, edge, nil, 0.1)
	Stations.stamp(crate, Stations.SIDES, 1.6, 1.1, Stations.grooveFor(t, t.rimTop))
	local colors = { soda.red, soda.orange, soda.blue, soda.lime }
	for n, x in { -2.95, -2.5, -2.05 } do Stations.bottle(g, V(x, Y + 1.1, 1.8 + (n % 2) * 0.45), 0.55, colors[n]) end
	for i, y in { 0, 0.5 } do
		local at = CFrame.new(2.55 + i * 0.12, Y + y + 0.25, 1.9) * CFrame.Angles(0, 0, math.pi / 2)
		g:part('Tyre', V(0.5, 1.7, 1.7), at, C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('TyreHub', V(0.52, 0.8, 0.8), at, C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
	end
	g:part('FallenCan', V(0.95, 0.84, 0.84), CFrame.new(1.2, Y + 0.42, 3.2) * CFrame.Angles(0, 0.6, 0), soda.blue, M.SmoothPlastic, Enum.PartType.Cylinder)
end

-- 2 Red: a CARNIVAL BOOTH, two chunky pillars with lit bulbs under a header with a scalloped red-and-white awning and a
-- round bullseye sign on the roof, a darker red back wall; three bullseye boards pop up on spring posts, the two small
-- ones from a striped counter, the big one (main) from the floor behind it.
function Stations.Lanes.red(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge, white, gold = t.trim, C(250, 250, 245), C(255, 214, 40)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	back:box('BoothBack', V(-3.45, 0, z0 + 0.7), V(3.45, Y + 8.0, z1), t.groove)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 3.4, sx * 4.4), math.max(sx * 3.4, sx * 4.4)
		Stations.chunk(back, 'BoothPillar', V(a, 0, z0), V(b, Y + 8.0, z1), t.frame, edge)
		-- three bulbs up the pillar's front, always lit (nothing blinks)
		for i = 1, 3 do decor(back:part('Bulb', V(0.4, 0.4, 0.4), CFrame.new(sx * 3.9, Y + 1.9 * i, z0 - 0.12), C(255, 240, 190), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	end
	Stations.chunk(back, 'BoothHeader', V(-4.45, Y + 8.0, z0 - 0.9), V(4.45, Y + 9.1, z1), t.mat, edge)
	studs(back:box('BoothRoof', V(-4.45, Y + 9.1, z0 - 0.9), V(4.45, Y + 9.35, z1), t.rimTop))
	-- the awning: eight flaps in turn white and red, each with a stepped (pixel) scallop at its foot
	local fz = z0 - 1.0
	for i = 0, 7 do
		local x = -4.45 + (i + 0.5) * 8.9 / 8
		local col = i % 2 == 0 and white or t.mat
		back:box('Awning', V(x - 0.556, Y + 7.3, fz - 0.1), V(x + 0.556, Y + 8.05, fz + 0.1), col)
		back:box('AwningTip', V(x - 0.34, Y + 6.95, fz - 0.1), V(x + 0.34, Y + 7.3, fz + 0.1), col)
	end
	-- the roof sign: a round bullseye on a short post
	back:box('SignPost', V(-0.25, Y + 9.35, z0 + 0.3), V(0.25, Y + 10.0, z0 + 0.8), edge)
	Stations.disc(back, 'SignBoard', CFrame.new(0, Y + 10.9, z0 + 0.55), 1.2, 0.3, edge)
	Stations.bullseye(back, CFrame.new(0, Y + 10.9, z0 + 0.4), 1.05, { white, t.mat, white, gold })
	-- the counter (striped, studded top) the small boards pop up from
	local cz0, cz1, ch = 3.6, 4.5, Y + 1.5
	Stations.chunk(g, 'Counter', V(-3.8, Y, cz0), V(3.8, ch, cz1), t.frame, edge)
	g:box('CounterStripe', V(-3.84, Y + 0.6, cz0 - 0.04), V(3.84, Y + 0.95, cz1 + 0.04), white)
	studs(g:box('CounterTop', V(-3.9, ch, cz0 - 0.1), V(3.9, ch + 0.2, cz1 + 0.05), t.rimTop))
	local rings = { white, t.mat, white, t.mat, gold }
	-- A spring post: a chunky post with a coil (dark and silver bands) under the board.
	local function spring(x, z, y0, y1)
		Stations.chunk(g, 'SpringPost', V(x - 0.22, y0, z - 0.22), V(x + 0.22, y1 - 0.6, z + 0.22), edge, edge:Lerp(C(0, 0, 0), 0.4), nil, 0.08)
		for i = 0, 2 do g:box('Spring', V(x - 0.3, y1 - 0.6 + i * 0.2, z - 0.3), V(x + 0.3, y1 - 0.48 + i * 0.2, z + 0.3), i % 2 == 0 and C(200, 206, 216) or C(50, 52, 60)) end
	end
	for _, b in { { 0, 6.0, Y, Y + 4.0, 1.78, true }, { -2.55, 4.05, ch + 0.2, ch + 2.1, 1.0 }, { 2.55, 4.05, ch + 0.2, ch + 1.7, 1.0 } } do
		local x, bz, ledge, r = b[1], b[2], b[4], b[5]
		spring(x, bz + 0.3, b[3], ledge)
		local sw = Stations.target(k, CFrame.new(x, ledge, bz + 0.1), V(x, ledge + r, bz), 'Tip', b[6], 'Tock')
		Stations.disc(sw, 'Board', CFrame.new(x, ledge + r, bz + 0.12), r + 0.14, 0.18, edge)
		Stations.bullseye(sw, CFrame.new(x, ledge + r, bz + 0.03), r, rings)
	end
end

-- 3 Lava (orange): a FORGE, a brick furnace with a glowing arched mouth, a stepped left shoulder and a tall chimney on
-- the right that burns at the top; a chunky L-shaped gallows (the reference's frame) hangs a hot gong (main) and a hot
-- plate; a second plate on a post and a burning barrel.
function Stations.Lanes.lava(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge, hot, core, soot = t.trim, C(255, 110, 20), C(255, 225, 90), C(70, 36, 22)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local h = Y + 5.6
	Stations.chunk(back, 'Furnace', V(-4.3, 0, z0), V(4.3, h, z1), t.frame, edge)
	for _, y in { 1.8, 3.6 } do decor(back:box('Course', V(-4.26, Y + y - 0.07, z0 - 0.04), V(4.26, Y + y + 0.07, z0 + 0.1), t.groove)).CastShadow = false end
	studs(back:box('FurnaceCap', V(-4.36, h, z0 - 0.06), V(4.36, h + 0.3, z1), t.rimTop))
	-- the mouth: a dark stepped arch with the fire inside
	back:box('Mouth', V(-1.7, Y + 0.2, z0 - 0.06), V(1.7, Y + 2.7, z0 + 0.3), soot)
	back:box('MouthArch', V(-1.1, Y + 2.7, z0 - 0.06), V(1.1, Y + 3.2, z0 + 0.3), soot)
	decor(back:box('MouthFire', V(-1.35, Y + 0.2, z0 - 0.1), V(1.35, Y + 1.7, z0 + 0.1), hot, M.Neon)).CastShadow = false
	decor(back:box('MouthCoals', V(-1.5, Y + 0.2, z0 - 0.14), V(1.5, Y + 0.6, z0 + 0.1), core, M.Neon)).CastShadow = false
	for _, c in { { -4.2, -2.1, Y + 4.4 }, { 2.3, 4.2, Y + 1.2 } } do
		decor(back:box('LavaCrack', V(c[1], c[3] - 0.08, z0 - 0.08), V(c[2], c[3] + 0.08, z0 + 0.1), hot, M.Neon)).CastShadow = false
	end
	-- the left shoulder and the chimney (it burns at the top: HoodVFX's flames on the coals)
	Stations.chunk(back, 'Shoulder', V(-4.3, h + 0.3, z0 + 0.4), V(-1.4, h + 1.4, z1), t.mat, edge)
	Stations.chunk(back, 'Chimney', V(1.9, h + 0.3, z0 + 0.4), V(3.9, Y + 10.4, z1), t.mat, edge)
	back:box('ChimneyBand', V(1.8, Y + 8.2, z0 + 0.3), V(4.0, Y + 8.5, z1 + 0.04), edge)
	Stations.chunk(back, 'ChimneyTop', V(1.7, Y + 10.4, z0 + 0.25), V(4.1, Y + 10.9, z1), edge, soot)
	local coal = decor(back:part('Coals', V(0.08, 0.9, 0.9), CFrame.new(2.9, Y + 10.93, (z0 + 0.4 + z1) / 2) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
	table.insert(k.burners, coal)
	-- The gallows: a post on a foot at the left edge, an arm across the lane at the gantry's height, a brace.
	local z, top = Stations.GANTRY_Z, Stations.GANTRY_Y
	Stations.chunk(g, 'GallowsFoot', V(-4.45, Y, z - 0.8), V(-3.25, Y + 0.6, z + 0.8), edge, soot, nil, 0.1)
	Stations.chunk(g, 'GallowsPost', V(-4.3, Y + 0.6, z - 0.45), V(-3.4, top + 0.9, z + 0.45), t.frame, edge)
	Stations.chunk(g, 'GallowsArm', V(-3.4, top, z - 0.45), V(3.5, top + 0.9, z + 0.45), t.frame, edge)
	g:box('GallowsCap', V(-4.4, top + 0.9, z - 0.55), V(3.6, top + 1.15, z + 0.55), t.rimTop)
	g:bar('GallowsBrace', V(-3.45, top - 1.7, z), V(-1.9, top + 0.05, z), 0.5, t.frame, M.SmoothPlastic)
	-- Plates: a big round gong (main) and a square plate under the arm.
	local function gong(sw, x, cy, r)
		Stations.disc(sw, 'GongRim', CFrame.new(x, cy, z), r, 0.25, edge)
		Stations.disc(sw, 'GongHot', CFrame.new(x, cy, z - 0.05), r * 0.8, 0.3, hot, M.Neon)
		Stations.disc(sw, 'GongCore', CFrame.new(x, cy, z - 0.1), r * 0.42, 0.34, core, M.Neon)
		Stations.chains(sw, x, cy + r - 0.1, r * 0.45)
	end
	local sw = Stations.target(k, CFrame.new(0, top, z), V(0, 6.2, z), 'Swing', true, 'Ding')
	gong(sw, 0, 6.2, 1.62)
	local s2 = Stations.target(k, CFrame.new(2.5, top, z), V(2.5, 4.9, z), 'Swing', false, 'Ding')
	Stations.plate(s2, CFrame.new(2.5, 4.9, z), 1.3, edge, hot, M.Neon, core)
	Stations.chains(s2, 2.5, 4.9 + 0.65, 0.42)
	-- a plate on a post at the left, in front of the gallows
	g:box('PlatePost', V(-2.6, Y, 4.4), V(-2.2, Y + 2.6, 4.8), edge)
	local s3 = Stations.target(k, CFrame.new(-2.4, Y + 2.6, 4.4), V(-2.4, Y + 3.25, 4.25), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(-2.4, Y + 3.25, 4.25), 1.3, edge, hot, M.Neon, core)
	-- A burning barrel (flames come from HoodVFX on its open top).
	local pos = V(2.9, Y, 2.6)
	Stations.drum(g, pos, 0.62, 1.7, t.frame, edge, soot)
	local coals = decor(g:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
	table.insert(k.burners, coals)
end

-- 4 Arcane (purple): a BILLBOARD up on two legs over a catwalk, marquee bulbs along its top, two spotlights leaning
-- over it, a pale starburst behind a big spinner disc (main) on a post; two balloons to pop and bobbing balloon bunches
-- on the board's top corners.
function Stations.Lanes.arcane(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge = t.trim
	local back = k.st:group('Backstop')
	local z0 = Stations.BACK_Z
	local b0, b1 = Y + 3.2, Y + 9.6 -- the board's foot and top
	for _, sx in { -1, 1 } do
		Stations.chunk(back, 'BillboardLeg', V(sx * 2.7 - 0.45, 0, z0 + 0.5), V(sx * 2.7 + 0.45, b0, z0 + 1.35), t.frame, edge)
	end
	studs(back:box('Catwalk', V(-4.4, b0 - 0.3, z0 - 0.3), V(4.4, b0, z0 + 1.35), t.rimTop))
	Stations.chunk(back, 'Billboard', V(-4.4, b0, z0 + 0.3), V(4.4, b1, z0 + 1.2), t.groove, edge, nil, 0.12)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z0 + 0.22), 4.2, 0.16, t.rimTop)
	-- marquee bulbs along the top (always lit) and two spotlights on arms over the board
	for i = 0, 7 do decor(back:part('Bulb', V(0.36, 0.36, 0.36), CFrame.new(-3.85 + i * 1.1, b1 - 0.35, z0 + 0.16), C(255, 240, 200), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	for _, sx in { -1, 1 } do
		back:bar('LampArm', V(sx * 2.9, b1, z0 + 0.8), V(sx * 2.9, b1 + 0.9, z0 - 0.2), 0.22, edge, M.SmoothPlastic)
		local lamp = CFrame.new(sx * 2.9, b1 + 0.75, z0 - 0.5) * CFrame.Angles(math.rad(35), 0, 0)
		back:part('Lamp', V(0.7, 0.6, 0.8), lamp, edge)
		decor(back:part('LampGlow', V(0.5, 0.06, 0.6), lamp * CFrame.new(0, -0.31, 0), C(255, 250, 220), M.Neon)).CastShadow = false
	end
	-- Spinner: a chunky post with a big ringed disc on a hub; it turns slowly and spins when hit.
	local sz = 6.0
	Stations.chunk(g, 'SpinnerPost', V(-0.22, Y, sz + 0.3), V(0.22, Y + 5.8, sz + 0.75), t.frame, edge, nil, 0.1)
	g:box('SpinnerFoot', V(-0.75, Y, sz - 0.2), V(0.75, Y + 0.35, sz + 1.2), edge)
	local sw = Stations.target(k, CFrame.new(0, Y + 5.8, sz), V(0, Y + 5.8, sz), 'Spin', true, 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(0, Y + 5.8, sz + 0.12), 1.8, 0.16, edge)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, sz + 0.03), 1.66, { C(255, 255, 255), C(255, 100, 200), C(255, 255, 255), t.mat, C(255, 220, 60) })
	-- Balloons to pop, tied to little weights.
	for _, b in { { -2.6, 4.4, Y + 4.2, C(255, 90, 170) }, { 2.65, 5.1, Y + 4.9, C(80, 200, 255) } } do
		local pos = V(b[1], b[3], b[2])
		g:box('BalloonWeight', V(b[1] - 0.22, Y, b[2] - 0.22), V(b[1] + 0.22, Y + 0.35, b[2] + 0.22), C(255, 214, 60))
		local s2 = Stations.target(k, CFrame.new(pos), pos, 'Pop', false, 'Pop', b[4])
		Stations.balloon(s2, pos, 0.62, b[4], V(b[1], Y + 0.35, b[2]))
	end
	-- Bunches of three on the board's top corners (they bob; not targets).
	for _, sx in { -1, 1 } do
		local bc, bunch = g:group('BalloonBunch')
		local foot = V(sx * 3.9, b1, z0 + 0.75)
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

-- 5 Shadow (blue): a PIXEL ARCH, two chunky piers under a stepped lintel and crown with stepped inner corners and a pale
-- keystone, a dark navy void inside, neon along the opening; the main plate (dark, neon rings) swings from a
-- bracket out of the keystone; two square plates on posts.
function Stations.Lanes.shadow(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, dark, void = C(120, 200, 255), C(20, 30, 74), C(12, 20, 54)
	local edge = t.trim
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local open = Y + 7.6 -- the opening's top
	back:box('ArchVoid', V(-2.5, 0, z1 - 0.5), V(2.5, open, z1), void)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 2.5, sx * 4.3), math.max(sx * 2.5, sx * 4.3)
		Stations.chunk(back, 'ArchPier', V(a, 0, z0), V(b, open, z1), t.frame, edge)
		-- the stepped corners of the opening
		local c0, c1 = math.min(sx * 1.6, sx * 2.5), math.max(sx * 1.6, sx * 2.5)
		Stations.chunk(back, 'ArchStep', V(c0, open - 1.0, z0 + 0.1), V(c1, open, z1), t.frame, edge, nil, 0.1)
		decor(back:box('ArchNeon', V(sx * 2.5 - 0.09, Y, z0 - 0.06), V(sx * 2.5 + 0.09, open - 1.0, z0 + 0.04), neon, M.Neon)).CastShadow = false
		decor(back:box('ArchNeon', V(c0, open - 1.09, z0 + 0.04), V(c1, open - 0.91, z0 + 0.14), neon, M.Neon)).CastShadow = false
	end
	-- the lintel and a narrower crown over it (the arch's stepped outer curve), a pale keystone through both
	Stations.chunk(back, 'ArchLintel', V(-4.3, open, z0), V(4.3, open + 0.9, z1), t.frame, edge)
	decor(back:box('ArchNeon', V(-1.6, open - 0.09, z0 + 0.04), V(1.6, open + 0.09, z0 + 0.14), neon, M.Neon)).CastShadow = false
	studs(back:box('ArchCap', V(-4.36, open + 0.9, z0 - 0.06), V(4.36, open + 1.15, z1), t.rimTop))
	Stations.chunk(back, 'ArchCrown', V(-2.9, open + 1.15, z0 + 0.15), V(2.9, open + 1.9, z1), t.frame, edge)
	studs(back:box('ArchCap', V(-2.96, open + 1.9, z0 + 0.09), V(2.96, open + 2.15, z1), t.rimTop))
	Stations.chunk(back, 'Keystone', V(-0.85, open + 0.2, z0 - 0.2), V(0.85, open + 2.9, z1), t.rimTop, edge)
	-- The bracket out of the keystone the main plate hangs from.
	Stations.chunk(g, 'Bracket', V(-0.4, Stations.GANTRY_Y, Stations.GANTRY_Z - 0.4), V(0.4, Stations.GANTRY_Y + 0.8, z0), t.frame, edge, nil, 0.1)
	-- Main: a round dark plate with neon rings.
	local cy, gz = 6.2, Stations.GANTRY_Z
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, gz), V(0, cy, gz), 'Swing', true, 'Ding')
	Stations.disc(sw, 'PlateRim', CFrame.new(0, cy, gz + 0.04), 1.72, 0.2, neon, M.Neon)
	Stations.disc(sw, 'Plate', CFrame.new(0, cy, gz - 0.02), 1.5, 0.26, dark, M.Metal)
	Stations.disc(sw, 'PlateRing', CFrame.new(0, cy, gz - 0.06), 0.95, 0.3, neon, M.Neon)
	Stations.disc(sw, 'PlateInner', CFrame.new(0, cy, gz - 0.1), 0.8, 0.34, dark, M.Metal)
	Stations.disc(sw, 'PlateSpot', CFrame.new(0, cy, gz - 0.14), 0.32, 0.38, neon, M.Neon)
	Stations.chains(sw, 0, cy + 1.62, 0.65)
	-- Two square plates on chunky posts at the sides.
	for _, p in { { -2.6, 4.6, 2.6, 1.3 }, { 2.6, 4.1, 3.2, 1.2 } } do
		Stations.chunk(g, 'PlatePost', V(p[1] - 0.22, Y, p[2] + 0.12), V(p[1] + 0.22, Y + p[3], p[2] + 0.56), t.frame, edge, nil, 0.08)
		local s2 = Stations.target(k, CFrame.new(p[1], Y + p[3], p[2] + 0.1), V(p[1], Y + p[3] + p[4] / 2, p[2]), 'Tip', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], Y + p[3] + p[4] / 2, p[2]), p[4], dark, neon, M.Neon, neon)
	end
end

-- 6 Frost (cyan): an ICE CASTLE, a curtain wall of offset ice blocks with crenellations and icicles between two chunky
-- cyan turrets (white battlements, dark arrow slits, a deep-blue neon snowflake on each); an ice bullseye on a tall ice
-- pillar (main) and ice blocks on pedestals.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, deep = C(248, 252, 255), C(170, 232, 252), C(130, 212, 245), C(25, 120, 235)
	local glow, navy, edge = C(40, 150, 255), C(12, 40, 100), t.trim
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local wallTop = Y + 5.2
	for row, xs in { { -2.8, -0.95, 0.95, 2.8 }, { -2.8, -1.9, 0, 1.9, 2.8 } } do
		local y0, y1 = row == 1 and 0 or Y + 2.6, row == 1 and Y + 2.6 or wallTop
		for i = 1, #xs - 1 do
			local p = back:box('IceWall', V(xs[i] + 0.03, y0, z0 + 0.3 + ((i + row) % 2) * 0.08), V(xs[i + 1] - 0.03, y1 - 0.04, z1), (i + row) % 2 == 0 and iceA or iceB)
			p.Reflectance = 0.15
		end
	end
	studs(back:box('WallSnow', V(-2.85, wallTop, z0 + 0.25), V(2.85, wallTop + 0.25, z1), snow))
	for _, x in { -2.1, -0.7, 0.7, 2.1 } do studs(back:box('Merlon', V(x - 0.4, wallTop + 0.25, z0 + 0.35), V(x + 0.4, wallTop + 1.05, z1), iceA)) end
	for i = 0, 5 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-2.5 + i * 1.0, wallTop - 0.02, z0 + 0.22), len, 0.34)
	end
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 2.8, sx * 4.4), math.max(sx * 2.8, sx * 4.4)
		Stations.chunk(back, 'Turret', V(a, 0, z0), V(b, Y + 7.6, z1), t.frame, edge)
		studs(back:box('TurretCap', V(a - 0.15, Y + 7.6, z0 - 0.15), V(b + 0.15, Y + 8.1, z1), snow))
		for _, m in { 0.2, 1.05 } do
			local x0 = math.min(sx * (2.8 + m), sx * (2.8 + m + 0.55))
			studs(back:box('Merlon', V(x0, Y + 8.1, z0), V(x0 + 0.55, Y + 8.9, z1), snow))
		end
		back:box('ArrowSlit', V(sx * 3.6 - 0.16, Y + 5.3, z0 - 0.04), V(sx * 3.6 + 0.16, Y + 6.8, z0 + 0.1), navy)
		-- a deep-blue neon snowflake on the turret (six arms, a twin branch on each)
		local fc = CFrame.new(sx * 3.6, Y + 2.9, z0 - 0.08) * CFrame.Angles(0, 0, math.rad(15))
		for a2 = 0, 2 do
			local arm = fc * CFrame.Angles(0, 0, a2 * math.pi / 3)
			decor(back:part('Snowflake', V(1.4, 0.26, 0.1), arm, glow, M.Neon)).CastShadow = false
			for _, s in { -1, 1 } do
				local at = arm * CFrame.new(s * 0.42, 0, -0.01) * CFrame.Angles(0, 0, s * math.pi / 3) * CFrame.new(s * 0.15, 0, 0)
				decor(back:part('Snowflake', V(0.32, 0.18, 0.1), at, glow, M.Neon)).CastShadow = false
			end
		end
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	Stations.chunk(g, 'IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), t.frame, edge, nil, 0.1)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, edge)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, mz + 0.03), 1.72, { snow, deep, snow, deep, C(255, 255, 255) })
	-- Ice blocks on pedestals at the sides.
	for _, b in { { -2.6, 4.5, 2.6, 0.95 }, { 2.6, 5.0, 3.2, 0.9 } } do
		Stations.chunk(g, 'IcePedestal', V(b[1] - 0.5, Y, b[2] - 0.5), V(b[1] + 0.5, Y + b[3] - 0.14, b[2] + 0.5), t.frame, edge, nil, 0.1)
		g:box('IcePedestalCap', V(b[1] - 0.62, Y + b[3] - 0.14, b[2] - 0.62), V(b[1] + 0.62, Y + b[3], b[2] + 0.62), snow)
		local cy = Y + b[3] + b[4] / 2
		-- (Hinged on the block's back edge and never rocking forward, so it tips off its cap, never into it.)
		local s2, block = Stations.target(k, CFrame.new(b[1], Y + b[3], b[2] + 0.6), V(b[1], cy, b[2]), 'Tip', false, 'Ice')
		block:SetAttribute('TipMin', 0)
		Stations.ice(s2, 'IceBlock', CFrame.new(b[1], cy, b[2]) * CFrame.Angles(0, math.rad(b[1] > 0 and 20 or -15), 0), b[4])
	end
end

-- 7 Toxic (green): SHIPPING CONTAINERS, a long ribbed container across the back with locking bars on its doors and a
-- shorter one stacked on it off to the left (a hazard band, a neon drip sign), a hazard diamond on a pole on the free
-- end; a big toxic barrel with a target face on a pallet and two crates (main), green bottles on a shelf, a barrel on
-- the floor and glowing puddles.
function Stations.Lanes.toxic(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, edge, yellow, ink = C(150, 255, 80), t.trim, C(255, 214, 30), C(30, 30, 36)
	local deep = t.trim:Lerp(C(0, 0, 0), 0.25)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	-- the bottom container
	local h1 = Y + 3.6
	Stations.chunk(back, 'Container', V(-4.4, 0, z0 - 0.3), V(4.4, h1, z1), t.frame, edge)
	for i = 0, 4 do
		local x = -3.7 + i * 1.15
		back:box('Rib', V(x - 0.16, 0.35, z0 - 0.42), V(x + 0.16, h1 - 0.3, z0 - 0.28), t.mat)
	end
	back:box('DoorSeam', V(2.85, 0.3, z0 - 0.36), V(2.95, h1 - 0.25, z0 - 0.28), edge)
	for _, x in { 2.2, 3.6 } do
		back:box('LockBar', V(x - 0.09, 0.4, z0 - 0.5), V(x + 0.09, h1 - 0.35, z0 - 0.3), C(205, 212, 220))
		back:box('LockHandle', V(x - 0.09, Y + 1.3, z0 - 0.62), V(x + 0.34, Y + 1.5, z0 - 0.42), C(205, 212, 220))
	end
	-- the top container, set back and off to the left
	local h2 = h1 + 3.0
	Stations.chunk(back, 'Container', V(-4.2, h1, z0 + 0.15), V(1.5, h2, z1), t.rimTop, edge)
	for i = 0, 3 do
		local x = -3.5 + i * 1.3
		back:box('Rib', V(x - 0.15, h1 + 0.3, z0 + 0.03), V(x + 0.15, h2 - 0.75, z0 + 0.17), t.mat)
	end
	back:box('HazardBand', V(-4.2, h2 - 0.6, z0 + 0.02), V(1.5, h2 - 0.1, z0 + 0.17), yellow)
	for i = 0, 5 do
		decor(back:part('HazardBar', V(0.33, 0.7, 0.05), CFrame.new(-3.75 + i * 0.95, h2 - 0.35, z0 + 0.0) * CFrame.Angles(0, 0, math.rad(40)), ink))
	end
	-- the drip sign on the top container (a neon drop on a dark plate), left of the barrel stack
	local sx, sy = -2.9, h1 + 1.2
	Stations.disc(back, 'SignPlate', CFrame.new(sx, sy, z0 + 0.0), 1.0, 0.14, deep)
	Stations.disc(back, 'Drip', CFrame.new(sx, sy - 0.2, z0 - 0.1), 0.6, 0.14, neon, M.Neon)
	decor(back:part('DripTip', V(0.85, 0.85, 0.14), CFrame.new(sx, sy + 0.14, z0 - 0.1) * CFrame.Angles(0, 0, math.pi / 4), neon, M.Neon))
	-- the hazard diamond on a pole on the bottom container's free end
	local px = 3.0
	back:box('SignPole', V(px - 0.12, h1, z0 + 0.7), V(px + 0.12, h1 + 2.6, z0 + 0.94), edge)
	back:part('HazardSign', V(1.3, 1.3, 0.14), CFrame.new(px, h1 + 3.1, z0 + 0.6) * CFrame.Angles(0, 0, math.pi / 4), yellow)
	back:part('HazardSignMark', V(0.22, 0.6, 0.06), CFrame.new(px, h1 + 3.2, z0 + 0.5), ink)
	back:part('HazardSignDot', V(0.22, 0.22, 0.06), CFrame.new(px, h1 + 2.7, z0 + 0.5), ink)
	-- Main: a big toxic barrel with a target face, on a pallet and two stamped crates.
	local mz = 6.0
	g:box('Pallet', V(-1.05, Y, mz - 1.05), V(1.05, Y + 0.35, mz + 1.05), C(150, 105, 60))
	local crate = Stations.chunk(g, 'Crate', V(-0.95, Y + 0.35, mz - 0.95), V(0.95, Y + 2.35, mz + 0.95), deep, ink, nil, 0.1)
	Stations.stamp(crate, Stations.SIDES, 1.9, 2.0, t.frame)
	local crate2 = g:part('Crate', V(1.6, 1.8, 1.6), CFrame.new(0.05, Y + 3.25, mz) * CFrame.Angles(0, math.rad(8), 0), t.frame)
	Stations.stamp(crate2, Stations.SIDES, 1.6, 1.8, edge)
	local base = Y + 4.15
	local sw, drum = Stations.target(k, CFrame.new(0, base, mz + 0.95), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	drum:SetAttribute('TipMin', 0) -- (rocks back on its back edge, never into the crate)
	Stations.drum(sw, V(0, base, mz), 0.95, 2.5, neon, deep, edge, M.Neon)
	Stations.bullseye(sw, CFrame.new(0, base + 1.25, mz - 1.02), 0.75, { C(255, 255, 255), deep, neon }, { M.SmoothPlastic, M.SmoothPlastic, M.Neon })
	-- Green bottles on a little shelf (they shatter), and a barrel on the floor.
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), edge) end
	Stations.chunk(g, 'Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), t.rimTop, edge, nil, 0.08)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', neon)
		Stations.bottle(s2, b, 0.95, C(90, 220, 110), { label = deep, stripe = neon, material = M.Neon })
	end
	local s3, floorDrum = Stations.target(k, CFrame.new(2.7, Y, 5.26), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	floorDrum:SetAttribute('TipMin', 0)
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, neon, deep, edge, M.Neon)
	-- Glowing puddles on the mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), neon, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane (yellow): a WINNERS' PODIUM, three gold steps (1 in the middle, 2 on the left, 3 on the right)
-- with crimson numbers and cream caps, a tall stepped gold backdrop with rays and a velvet disc behind step 1; a giant
-- gold trophy with a bullseye on its cup (main) stands on step 1, the turning crown on step 2, gold bottles on step 3;
-- a gold plate on a post, lemon nuggets on an amber rug.
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, cream = C(255, 222, 40), C(245, 190, 0), C(255, 252, 235), C(235, 30, 70), C(255, 248, 220)
	local velvet, rays = t.trim, C(255, 238, 130)
	local back = k.st:group('Backstop')
	local z1 = Stations.HALF_Z - 0.1
	-- the backdrop
	Stations.chunk(back, 'Backdrop', V(-2.7, 0, 9.2), V(2.7, Y + 8.6, z1), deep, velvet)
	Stations.chunk(back, 'BackdropTop', V(-1.5, Y + 8.6, 9.35), V(1.5, Y + 9.6, z1), deep, velvet)
	Stations.starburst(back, CFrame.new(0, Y + 6.2, 9.12), 4.4, 0.12, rays)
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 6.2, 9.0), 2.0, 0.14, velvet, M.Fabric)
	back:part('Gem', V(0.55, 0.55, 0.25), CFrame.new(0, Y + 9.1, 9.25) * CFrame.Angles(0, 0, math.pi / 4), ruby, M.Glass)
	-- the steps: { x0, x1, top, front z, number }
	local steps = { { -1.5, 1.5, Y + 3.0, 7.1, 1 }, { -4.4, -1.5, Y + 2.0, 7.5, 2 }, { 1.5, 4.4, Y + 1.2, 7.7, 3 } }
	for _, s in steps do
		Stations.chunk(back, 'Podium', V(s[1], 0, s[4]), V(s[2], s[3], 9.2 + (s[5] == 1 and 0 or 0.7)), s[5] == 1 and gold or deep, velvet)
		studs(back:box('PodiumCap', V(s[1] - 0.05, s[3], s[4] - 0.05), V(s[2] + 0.05, s[3] + 0.25, 9.2 + (s[5] == 1 and 0 or 0.7)), cream))
		local dh = math.min(1.7, s[3] - 0.5)
		Stations.faceDigit(back, s[5], CFrame.new((s[1] + s[2]) / 2, (s[3] - dh) / 2, s[4]), dh, velvet)
	end
	-- Main: the trophy on step 1 (rocks back on its back edge when hit).
	local T, tz = Y + 3.25, 8.15
	local sw, trophy = Stations.target(k, CFrame.new(0, T, 8.8), V(0, T + 2.6, tz - 0.7), 'Tip', true, 'Ding')
	trophy:SetAttribute('TipMin', 0)
	sw:box('TrophyBase', V(-0.95, T, tz - 0.6), V(0.95, T + 0.5, tz + 0.6), velvet)
	sw:box('TrophyStem', V(-0.3, T + 0.5, tz - 0.25), V(0.3, T + 1.2, tz + 0.25), deep)
	sw:box('TrophyKnot', V(-0.55, T + 1.2, tz - 0.35), V(0.55, T + 1.45, tz + 0.35), gold)
	sw:box('TrophyFoot', V(-0.9, T + 1.45, tz - 0.5), V(0.9, T + 1.85, tz + 0.5), deep)
	sw:box('TrophyCup', V(-1.3, T + 1.85, tz - 0.7), V(1.3, T + 3.4, tz + 0.7), gold).Reflectance = 0.15
	sw:box('TrophyRim', V(-1.45, T + 3.4, tz - 0.8), V(1.45, T + 3.7, tz + 0.8), deep)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 1.3, sx * 1.95), math.max(sx * 1.3, sx * 1.95)
		local o0, o1 = math.min(sx * 1.65, sx * 1.95), math.max(sx * 1.65, sx * 1.95)
		sw:box('TrophyHandle', V(a, T + 3.0, tz - 0.15), V(b, T + 3.3, tz + 0.15), deep)
		sw:box('TrophyHandle', V(o0, T + 2.1, tz - 0.15), V(o1, T + 3.0, tz + 0.15), deep)
		sw:box('TrophyHandle', V(a, T + 2.1, tz - 0.15), V(b, T + 2.4, tz + 0.15), deep)
	end
	Stations.bullseye(sw, CFrame.new(0, T + 2.6, tz - 0.72), 0.7, { white, velvet, white, ruby })
	-- The crown turns on step 2; gold bottles stand on step 3 (they shatter).
	Stations.crown(g, CFrame.new(-2.95, Y + 2.25, 8.6))
	for _, x in { 2.35, 3.55 } do
		local b = V(x, Y + 1.45, 8.4)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', gold)
		Stations.bottle(s2, b, 0.95, gold, { label = white, stripe = ruby, cap = ruby })
	end
	-- A gold plate on a post at the front left.
	g:box('PlatePost', V(-2.8, Y, 5.15), V(-2.4, Y + 3.0, 5.55), velvet)
	local s3 = Stations.target(k, CFrame.new(-2.6, Y + 3.0, 5.15), V(-2.6, Y + 3.65, 5.05), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(-2.6, Y + 3.65, 5.05), 1.3, gold, deep, M.SmoothPlastic, white)
	-- An amber rug with a velvet border over the target field (so the lemon nuggets read), and the nuggets on it.
	local rug = studs(g:box('Rug', V(-3.3, Y, 0.4), V(3.3, Y + 0.04, 6.8), C(210, 140, 0)))
	rug.CanCollide = false
	for _, b in { { V(-3.3, Y, 0.4), V(3.3, Y + 0.05, 0.6) }, { V(-3.3, Y, 6.6), V(3.3, Y + 0.05, 6.8) }, { V(-3.3, Y, 0.4), V(-3.1, Y + 0.05, 6.8) }, { V(3.1, Y, 0.4), V(3.3, Y + 0.05, 6.8) } } do
		decor(g:box('RugBorder', b[1], b[2], velvet, M.Fabric)).CastShadow = false
	end
	local d = g:group('Nuggets')
	Stations.nugget(d, -1.9, 1.6, 1.0, 0.4)
	Stations.nugget(d, 1.3, 2.9, 0.9, 1.3)
	Stations.nugget(d, 0.6, 5.6, 0.8, 2.2)
end

-- Floating labels over the targets, the superhero game's training lanes (BRIEF23, ref_lanes_spread.png and
-- ref_training_lanes.png), three rows top to bottom: "Unlocked" (green) or "Locked" (red), small; the rebirth icon and the
-- rebirths the lane needs (a Robux lane: the Robux icon and its price); the big "Nx Power" in the lane's own colour
-- (the theme's text tint) with a dark outline. The words come from Shared/RebirthRules.laneLabel (ECON's Skins.Stations
-- fields: Rebirths, Multiplier, Pass, RobuxPrice). The icon is IconModels.Images.Rebirth / .Robux; until one is uploaded
-- the number's text carries a glyph instead (the Glyph attribute). The client repaints Detail as you rebirth or buy the
-- lane, and Cost and Power from the config (Lobby.client).
-- LOBBY6 (BRIEF24): every row in the references' Montserrat Black with a dark outline. A Robux lane's stack is bigger
-- (16 x 10.4 studs) with its price in lime; the best lane (the highest multiplier, opts.best) also wears a tilted BEST!
-- at its top right.
-- (B30: the lanes stand on a 10.4 pitch now, the soldier plaza's; a stack no wider than its lane's pitch, so neighbours
-- don't run into each other, ref_STILL_lanes_spread_soldier.png; a Robux lane's a little bigger)
Stations.LabelSize, Stations.PromoLabelSize = V(10.2, 6.8, 0), V(11.6, 7.8, 0)
---------------------------------------------------------------------------------------------- the soldier lane
-- (B30, the user: "make it like the references ... how the boxes look etc."; bible 2.2, ref_STILL_1x_lane_pad_zoom.jpg,
-- ref_STILL_lanes_spread_soldier.png, ref_W13.5_south_row_labels_zoom.jpg) Every lane is the soldier game's training
-- pad, in its tier's colour: a chunky studded pad with a stepped, notched edge (the outer rim a shade darker, ragged
-- with blocks that stick out and gaps that don't; an inner raised panel the player stands on, notched at the aisle end),
-- a straw dummy with a bullseye on its chest on a post in a round sandy base near the far end, sandbags piled behind
-- it, a couple of small things lying on the pad (a little ammo chest, a brick, spent shells). No walls, no bench, no
-- gantry: the black silhouettes of the locked lanes read like the reference's. A Robux lane adds a soft gold haze rising
-- off its pad and a glowing halo ring over its dummy's head.
-- Stations.Pads[tier] = { pad, rim } (the reference: 1x terracotta, then a colour per tier; Robux lanes in their own).
Stations.Pads = {
	{ C(204, 94, 43), C(150, 62, 30) }, -- 1 BAY 1 x1: the reference's terracotta
	{ C(156, 160, 176), C(108, 112, 128) }, -- 2 BAY 2 x4: grey
	{ C(120, 174, 214), C(68, 114, 164) }, -- 3 BAY 3 x10: light blue
	{ C(156, 98, 200), C(104, 60, 142) }, -- 4 BAY 4 x20: purple
	{ C(220, 124, 54), C(158, 82, 36) }, -- 5 BAY 5 x35: orange
	{ C(196, 236, 226), C(126, 184, 176) }, -- 6 BAY 6 x50: mint white
	{ C(56, 174, 178), C(32, 118, 122) }, -- 7 PRO BAY x100: teal (Skins)
	{ C(236, 190, 72), C(182, 132, 40) }, -- 8 GOLD BAY x250: gold
	{ C(255, 226, 124), C(178, 22, 52) }, -- 9 HEAD LANE x500: pale gold on crimson
}
Stations.DUMMY_Z = 5.4 -- the dummy's post (z), on its round base
function Stations.soldier(st, k, tier, paid)
	local pad, rim = table.unpack(Stations.Pads[tier] or Stations.Pads[1])
	local HX, HZ, Y = Stations.HALF_X, Stations.HALF_Z, Stations.MAT_Y
	local r = Random.new(tier * 31 + 7)
	-- the rim: a darker studded slab under the whole pad, its edge stepped (blocks out, notches in) along the sides
	local rx, rz = HX - 0.45, HZ - 0.45
	studs(st:box('Rim', V(-rx, 0, -rz + 0.9), V(rx, Y - 0.12, rz), rim, M.Plastic), true)
	-- (B30 final, ref_STILL_1x_lane_pad_zoom: the aisle end steps down and out: a lower studded tongue in the middle, the
	-- corners cut back a stud)
	local tw, to = r:NextNumber(1.9, 2.6), r:NextNumber(-0.5, 0.5)
	studs(st:box('RimTongue', V(to - tw, 0, -rz), V(to + tw, Y - 0.22, -rz + 0.9), rim:Lerp(C(0, 0, 0), 0.1), M.Plastic), true)
	for _, sx in { -1, 1 } do
		local z = -rz + 0.6
		while z < rz - 1.2 do
			local len = r:NextNumber(1.2, 2.6)
			if r:NextNumber() < 0.55 then
				local a, b = sx * (rx - 0.05), sx * (rx + r:NextNumber(0.3, 0.6))
				studs(st:box('RimStep', V(math.min(a, b), 0, z), V(math.max(a, b), Y - 0.2 - r:NextNumber(0, 0.08), math.min(z + len, rz - 0.6)), rim:Lerp(C(0, 0, 0), 0.06), M.Plastic), true)
			end
			z += len + r:NextNumber(0.3, 0.9)
		end
	end
	for _, sz in { -1, 1 } do
		local x = -rx + 0.5
		while x < rx - 1 do
			local len = r:NextNumber(1.0, 2.2)
			if r:NextNumber() < 0.5 then
				local a, b = sz * (rz - 0.05), sz * (rz + r:NextNumber(0.3, 0.6))
				studs(st:box('RimStep', V(x, 0, math.min(a, b)), V(math.min(x + len, rx - 0.5), Y - 0.2 - r:NextNumber(0, 0.08), math.max(a, b)), rim:Lerp(C(0, 0, 0), 0.06), M.Plastic), true)
			end
			x += len + r:NextNumber(0.3, 0.8)
		end
	end
	-- the inner raised panel (where you stand), in two pieces either side of the notch at the aisle end
	local px, pz0, pz1 = HX - 1.15, -HZ + 1.05, HZ - 1.1
	studs(st:box('Mat', V(-px, Y - 0.12, pz0 + 1.0), V(px, Y, pz1), pad, M.Plastic))
	studs(st:box('Mat', V(-px, Y - 0.12, pz0), V(-1.0, Y, pz0 + 1.0), pad, M.Plastic))
	studs(st:box('Mat', V(1.0, Y - 0.12, pz0), V(px, Y, pz0 + 1.0), pad, M.Plastic))
	-- a paler line of blocks along the panel's sides (its stepped edge catching the light)
	for _, sx in { -1, 1 } do
		local a, b = sx * (px - 0.35), sx * px
		st:box('MatEdge', V(math.min(a, b), Y, pz0 + 0.4), V(math.max(a, b), Y + 0.06, pz1 - 0.4), pad:Lerp(P.white, 0.18), M.SmoothPlastic)
	end
	-- the dummy's round sandy base and its post (gear: never moves)
	local dz = Stations.DUMMY_Z
	local sand, sandDark, wood = C(222, 186, 118), C(186, 148, 88), C(92, 64, 40)
	studs(k.gear:part('DummyBase', V(0.28, 2.8, 2.8), CFrame.new(0, Y + 0.14, dz) * CFrame.Angles(0, 0, math.pi / 2), sand, M.Plastic, Enum.PartType.Cylinder))
	k.gear:part('DummyBaseRim', V(0.2, 3.1, 3.1), CFrame.new(0, Y + 0.08, dz) * CFrame.Angles(0, 0, math.pi / 2), sandDark, M.SmoothPlastic, Enum.PartType.Cylinder)
	k.gear:box('DummyPost', V(-0.26, Y + 0.25, dz - 0.26), V(0.26, Y + 3.0, dz + 0.26), wood, M.SmoothPlastic)
	-- the dummy (the target: it sways back on its post when a shot lands): a chunky straw body as wide as a player, a
	-- head, a burlap band, the bullseye on its chest facing the shooter
	local pivot = CFrame.new(0, Y + 2.8, dz)
	local aim = V(0, Y + 4.5, dz - 0.75)
	local sw = Stations.target(k, pivot, aim, 'Swing', true, 'Ding', C(214, 186, 120))
	local straw, strawDark, burlap = C(214, 186, 120), C(176, 146, 84), C(150, 116, 74)
	studs(sw:box('DummyBody', V(-1.25, Y + 3.0, dz - 0.62), V(1.25, Y + 5.8, dz + 0.62), straw, M.Plastic), true)
	sw:box('DummyBand', V(-1.3, Y + 3.0, dz - 0.67), V(1.3, Y + 3.45, dz + 0.67), burlap, M.SmoothPlastic)
	sw:box('DummyShoulders', V(-1.6, Y + 5.2, dz - 0.5), V(1.6, Y + 5.8, dz + 0.5), strawDark, M.SmoothPlastic)
	studs(sw:box('DummyHead', V(-0.72, Y + 5.8, dz - 0.62), V(0.72, Y + 7.15, dz + 0.62), straw, M.Plastic), true)
	sw:box('DummyStraw', V(-0.5, Y + 7.15, dz - 0.4), V(0.5, Y + 7.45, dz + 0.4), strawDark, M.SmoothPlastic)
	Stations.bullseye(sw, CFrame.new(0, Y + 4.5, dz - 0.64), 1.0, { P.white, C(230, 40, 50), P.white, C(230, 40, 50) }, M.SmoothPlastic)
	k.mainAim = aim
	-- sandbags walled behind the dummy (B30 final, ref_STILL_1x_lane_pad_zoom: a pillow wall the pad's width, wrapping its
	-- back corners): a row of five, four on top, two on top of those, and one turned at each back corner
	local bag = C(167, 136, 107)
	local function sandbag(x, y, z, yaw, tone)
		k.gear:at(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)):blob('Sandbag', V(2.1, 1.05, 1.45), V(0, 0, 0), tone, M.SmoothPlastic)
	end
	local bz = HZ - 1.75
	for n = 0, 4 do sandbag(-3.7 + n * 1.85, Y + 0.52, bz + r:NextNumber(-0.12, 0.12), r:NextNumber(-6, 6), n % 2 == 0 and bag or bag:Lerp(P.white, 0.08)) end
	for n = 0, 3 do sandbag(-2.78 + n * 1.85, Y + 1.5, bz + 0.05, r:NextNumber(-8, 8), n % 2 == 1 and bag or bag:Lerp(C(0, 0, 0), 0.06)) end
	for n = 0, 1 do sandbag(-0.93 + n * 1.85, Y + 2.45, bz + 0.1, r:NextNumber(-8, 8), bag:Lerp(P.white, 0.05 * n)) end
	for _, sx in { -1, 1 } do sandbag(sx * (HX - 0.6), Y + 0.52, bz - 1.8, 90 + r:NextNumber(-8, 8), bag:Lerp(C(0, 0, 0), 0.04)) end
	-- (B30 final: the reference's tufts and cactus on the pad, as warehouse debris: a traffic cone and a small crate)
	local side = r:NextNumber() < 0.5 and -1 or 1
	local function prop(p) p.CanCollide, p.CanQuery, p.CastShadow = false, false, false return p end
	local cx0, cz0 = side * (px - 0.75), -HZ + 3.2 + r:NextNumber(0, 1.5)
	prop(k.gear:box('ConeFoot', V(cx0 - 0.5, Y, cz0 - 0.5), V(cx0 + 0.5, Y + 0.14, cz0 + 0.5), C(40, 40, 46), M.SmoothPlastic))
	for n, t in { { 0.38, 0.32, C(240, 110, 30) }, { 0.3, 0.26, P.white }, { 0.22, 0.3, C(240, 110, 30) } } do
		local y0 = Y + 0.14 + (n - 1) * 0.29
		prop(k.gear:post('Cone', t[1], t[2], V(cx0, y0, cz0), t[3], M.SmoothPlastic))
	end
	local bx, bz2 = -side * (px - 0.9), -HZ + 6.5 + r:NextNumber(0, 2)
	prop(k.gear:box('Crate', V(bx - 0.6, Y, bz2 - 0.6), V(bx + 0.6, Y + 1.0, bz2 + 0.6), C(176, 132, 80), M.WoodPlanks))
	prop(k.gear:box('CrateBand', V(bx - 0.62, Y + 0.42, bz2 - 0.62), V(bx + 0.62, Y + 0.58, bz2 + 0.62), C(120, 86, 50), M.SmoothPlastic))
	-- small things on the pad: a little ammo chest, a loose brick, a few spent shells
	local cx, cz = (r:NextNumber() < 0.5 and -1 or 1) * 2.4, 2.2
	k.gear:box('AmmoChest', V(cx - 0.7, Y, cz - 0.45), V(cx + 0.7, Y + 0.7, cz + 0.45), C(96, 112, 64), M.SmoothPlastic)
	k.gear:box('AmmoChestLid', V(cx - 0.74, Y + 0.7, cz - 0.49), V(cx + 0.74, Y + 0.86, cz + 0.49), C(76, 90, 50), M.SmoothPlastic)
	k.gear:box('AmmoChestLatch', V(cx - 0.12, Y + 0.45, cz - 0.52), V(cx + 0.12, Y + 0.75, cz - 0.46), C(214, 186, 92), M.SmoothPlastic)
	k.gear:box('Brick', V(-cx * 0.9 - 0.4, Y, 0.6), V(-cx * 0.9 + 0.4, Y + 0.32, 1.0), C(170, 80, 60), M.SmoothPlastic)
	for n = 1, 3 do
		local sx, szz = r:NextNumber(-2.6, 2.6), r:NextNumber(-1, 3.8)
		k.gear:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(sx, Y + 0.07, szz) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), C(232, 186, 70), M.SmoothPlastic)
	end
	if paid then
		-- the Robux lane: a soft gold haze rising off the pad, a glowing halo ring over the dummy's head (in the swing, so it
		-- sways with the dummy), and a light
		local hz = ghost(st:box('LaneHaze', V(-px + 0.4, Y, pz0 + 0.6), V(px - 0.4, Y + 0.1, pz1 - 0.6), P.white))
		hz.CastShadow = false
		local e = Instance.new('ParticleEmitter')
		e.Name = 'LaneHaze'
		e.Texture = 'rbxasset://textures/particles/smoke_main.dds'
		e:SetAttribute('PreviewTexture', 'mist')
		e.LightInfluence, e.LightEmission = 0, 0.35
		e.Rate = 3
		e.Lifetime = NumberRange.new(1.8, 2.8)
		e.Speed = NumberRange.new(0.8, 1.6)
		e.SpreadAngle = Vector2.new(10, 10)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = V(0, 0.4, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(0.5, 3.0), NumberSequenceKeypoint.new(1, 3.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.66), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(255, 236, 150), C(255, 196, 50))
		e.ZOffset = -1
		e.Parent = hz
		local l = Instance.new('PointLight')
		l.Color, l.Brightness, l.Range, l.Shadows = C(255, 210, 90), 1, 12, false
		l.Parent = hz
		for n = 0, 7 do
			local a = n * math.pi / 4
			decor(sw:part('Halo', V(0.72, 0.18, 0.22), CFrame.new(math.cos(a) * 0.95, Y + 8.0, dz + math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), C(255, 226, 90), M.Neon)).CastShadow = false
		end
	end
end

function Stations.labelText(s, open)
	local okR, Rules = pcall(function() return require(ReplicatedStorage.Shared.RebirthRules) end)
	if okR and type(Rules) == 'table' and Rules.laneLabel then
		local okL, top, state, power = pcall(Rules.laneLabel, s, open)
		if okL then return top, state, power, Rules.RobuxMark end
	end
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	return paid and RobuxText.fmt(s.RobuxPrice) or tostring(s.Rebirths or 0), open and 'Unlocked' or 'Locked', tostring(s.Multiplier) .. 'x Power', nil
end
-- (brief 29, the user: "floating text with no board, like the reference") Three rows of plain outlined text, no pill and
-- no chip: a small "Locked" (red) / "Unlocked" (green), the rebirth icon with the rebirths the lane needs (a Robux lane:
-- the Robux icon and its price, in lime), and the big "Nx Power" in the lane's own colour. The icon and its number sit
-- as one pair, centred. Names: Icon, Cost, Detail, Power (and Best), so Lobby.client and LabelFade treat it like the rest.
-- (B30, the user: "the fonts ... like the references"; ref_W13.5_south_row_labels_zoom.jpg) The fills: a vertical gradient on
-- every word (the client sets the hue of Locked/Unlocked; the gradient only shades it), the multiplier in its tier's pair.
Stations.TextGrad = {
	white = { C(255, 255, 255), C(217, 222, 232) }, lime = { C(232, 255, 74), C(78, 224, 32) }, -- (B31: TextStyle's white and price presets)
	-- the multiplier's fill per tier (Skins order): x1 white, x4 white, x10 light blue, x20 purple (#B050DF), x35 orange
	-- (#EF7C20), x50 mint white, PRO x100 teal, GOLD x250 gold to orange, HEAD x500 cyan (#2EC8E0)
	tiers = {
		{ C(255, 255, 255), C(206, 210, 222) }, { C(255, 255, 255), C(196, 200, 214) }, { C(200, 240, 255), C(100, 180, 255) },
		{ C(222, 160, 255), C(176, 80, 223) }, { C(255, 196, 110), C(239, 124, 32) }, { C(236, 255, 246), C(160, 236, 210) },
		{ C(170, 250, 250), C(40, 200, 210) }, { C(255, 236, 110), C(255, 150, 30) }, { C(170, 244, 255), C(46, 200, 224) },
	},
}
function Stations.fill(label, pair)
	local g = Instance.new('UIGradient')
	g.Color = ColorSequence.new(pair[1], pair[2])
	g.Rotation = 90
	g.Parent = label
	return g
end
function Stations.labels(st, s, t, at, opts)
	opts = opts or {}
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	local sign = ghost(st:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(at), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
	local size = paid and Stations.PromoLabelSize or Stations.LabelSize
	g.Size = UDim2.fromScale(size.X, size.Y) -- (a lane pitch wide: the row's labels read from the hall's spine)
	g.MaxDistance = paid and 44 or 34 -- (B31 PLAZA, critic 3: a lane's stack reads up close, 24 -> 34 studs, a Robux lane 30 -> 44;
	-- the next lane to open from 65 to 105 (Lobby.client's bands; HoodClient/LabelFade sets MaxDistance itself))
	g:SetAttribute('FadeNear', paid and 30 or 24)
	g:SetAttribute('FadeFar', paid and 44 or 34)
	g.LightInfluence = 0
	g.Parent = sign
	local ink = C(14, 12, 22)
	local function text(name, value, color, x, y, w, h, stroke, grad)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		l.FontFace = FONT.title -- (the references' Montserrat Black)
		l.Text = value
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 1
		local u = Instance.new('UIStroke')
		u.Color, u.Thickness, u.LineJoinMode = ink, stroke, Enum.LineJoinMode.Round
		u.Parent = l
		if grad then Stations.fill(l, grad) end
		l.Parent = g
		return l
	end
	local open = not paid and (s.Rebirths or 0) == 0
	local top, state, power, mark = Stations.labelText(s, open)
	-- the number alone (the icon says what it counts)
	local number = paid and tostring(s.RobuxPrice or '') or tostring(s.Rebirths or 0)
	local okI, icons = pcall(function() return require(ReplicatedStorage.Shared.Models.IconModels) end)
	-- (ROBUX / B31: a Robux lane's price is one string, the Robux sign and the number in the same lime fill and outline)
	local image = not paid and okI and type(icons) == 'table' and icons.Images and icons.Images.Rebirth
	local rowY, rowH = 0.2, 0.27
	-- (a Robux lane: "ONLY <Robux> 99" in lime, the reference's paid lanes; the pair sits right of the word)
	local pairX0 = paid and 0.46 or nil
	if paid then text('Only', 'ONLY', P.white, 0.1, rowY + 0.02, 0.34, rowH - 0.04, 3, Stations.TextGrad.lime).TextXAlignment = Enum.TextXAlignment.Right end
	local numberColor = P.white
	local cost
	if type(image) == 'string' and image ~= '' then
		-- the pair: a square icon the row's height, then the number, centred together
		local iconW = rowH * size.Y / size.X
		local numW = 0.085 * math.max(1, #number) + 0.03
		local x0 = pairX0 or (0.5 - (iconW + 0.015 + numW) / 2)
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.BackgroundTransparency = 1
		icon.Image = image
		icon.Position, icon.Size = UDim2.fromScale(x0, rowY), UDim2.fromScale(iconW, rowH)
		local a = Instance.new('UIAspectRatioConstraint')
		a.Parent = icon
		icon.Parent = g
		cost = text('Cost', number, numberColor, x0 + iconW + 0.015, rowY + 0.01, numW, rowH - 0.02, 3, paid and Stations.TextGrad.lime or Stations.TextGrad.white)
		cost.TextXAlignment = Enum.TextXAlignment.Left
		cost:SetAttribute('Glyph', '')
	else
		-- no icon yet: the glyph in the text (the Robux sign Roblox's fonts draw, or the rebirth arrows)
		cost = text('Cost', paid and RobuxText.fmt(s.RobuxPrice) or ('\u{1F504} ' .. number), numberColor, paid and 0.46 or 0.25, rowY + 0.01, paid and 0.4 or 0.5, rowH - 0.02, 3, paid and Stations.TextGrad.lime or Stations.TextGrad.white)
		if paid then cost.TextXAlignment = Enum.TextXAlignment.Left end
		cost:SetAttribute('Glyph', paid and RobuxText.Mark or '\u{1F504}')
	end
	local _ = top
	-- the state word, the smallest (the client sets its hue: salmon Locked, green Unlocked; the gradient shades it)
	text('Detail', state, open and C(40, 235, 90) or C(232, 106, 106), 0.25, 0.02, 0.5, 0.16, 3, { C(255, 255, 255), C(214, 214, 222) })
	-- the multiplier, the biggest, in its tier's gradient
	local tier = 1
	local skins = SKINS or require(ReplicatedStorage.Shared.Config.Skins)
	for i, row in skins.Stations do if row.Id == s.Id then tier = i end end
	local tg = Stations.TextGrad.tiers[math.clamp(tier, 1, #Stations.TextGrad.tiers)]
	if s.Id == 'Head' then tg = Stations.TextGrad.tiers[9] end
	text('Power', power, P.white, 0, 0.5, 1, 0.5, paid and 4 or 3.5, tg)
	if opts.best then
		-- BEST!: plain tilted words over the top right corner (brief 29: no red tag behind them), yellow with a deep red outline
		local best = text('Best', 'BEST!', C(255, 236, 72), 0.72, 0.02, 0.26, 0.17, 3.5)
		best.Rotation = 10
		best:FindFirstChildOfClass('UIStroke').Color = C(110, 10, 20)
	end
	shadowAll(g)
	return sign
end

-- The Robux lanes' promotion (LOBBY6, BRIEF24: "remove the VIP structure over the vip shooting ranges ... and promote
-- it better"; the green x250 lane of ref_training_lanes.png and user_33.png): no gate, no posts, no plate. The lane
-- glows in its own colour like the reference's best lane: a neon frame hugging the rim's foot, a soft halo strip on the
-- floor outside it, bright streaks rising off the whole mat (the reference's rising green streaks) and sparkles in the
-- lane's colour over the target field. Its label (Stations.labels) is the big one, with the Robux icon and price and, on the best
-- lane, BEST!. Built only for a lane with a Pass. Budget: streaks 9/s x ~1.9 s + sparkles 6/s x ~1.7 s, about 27 live
-- particles a lane, all small; no PointLight of its own (the theme's is the one).
function Stations.promo(st, t, s, VFX)
	local g = st:group('Promo')
	local X, Z = Stations.HALF_X, Stations.HALF_Z
	local glow = t.glow or t.text or P.white
	local function frame(name, o, w, h, alpha)
		for _, b in { { V(-X - o - w, 0, -Z - o - w), V(X + o + w, h, -Z - o) }, { V(-X - o - w, 0, Z + o), V(X + o + w, h, Z + o + w) },
			{ V(-X - o - w, 0, -Z - o), V(-X - o, h, Z + o) }, { V(X + o, 0, -Z - o), V(X + o + w, h, Z + o) } } do
			local p = decor(g:box(name, b[1], b[2], glow, M.Neon))
			p.CastShadow, p.Transparency = false, alpha
		end
	end
	-- (B30, the user: "tone down the glow like the reference"; bible M4: a paid lane is its pad's colour and a soft sparkle,
	-- ref_W13.5_train_row_south_25_4_10_100.jpg: no neon frame, no halo, no rising streaks)
	local _ = frame
	local field = ghost(g:box('PromoAuraField', V(-X + 1, Stations.MAT_Y, -Z + 1.2), V(X - 1, Stations.MAT_Y + 0.2, Z - 1.2), P.white))
	field.CastShadow = false
	local function seq(points)
		local k = {}
		for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
		return NumberSequence.new(k)
	end
	local _f, _s = field, seq
	-- sparkles over the target field in the lane's colour
	local box = ghost(g:box('PromoSparkleBox', V(-X + 1, Stations.MAT_Y, -2), V(X - 1, Stations.MAT_Y + 0.2, Z - 1.5), P.white))
	box.CastShadow = false
	local sp = Instance.new('ParticleEmitter')
	sp.Name = 'PromoSparkles'
	sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sp:SetAttribute('PreviewTexture', 'sparkle')
	sp.Color = ColorSequence.new(P.white, glow)
	sp.LightEmission, sp.LightInfluence = 1, 0
	sp.Rate = 6
	sp.Lifetime = NumberRange.new(1.2, 2.2)
	sp.Speed = NumberRange.new(1, 2.4)
	sp.SpreadAngle = Vector2.new(20, 20)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Size = seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } })
	sp.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
	sp.Rotation = NumberRange.new(0, 360)
	sp.Parent = box
	local _ = s
	return g
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
	model:SetAttribute('Silhouette', true) -- (Lobby.client blacks the whole lane out while it is locked)

	local Y, MX, MZ = Stations.MAT_Y, Stations.HALF_X - 1, Stations.HALF_Z - 1
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	local eq, gear, k
	if Stations.Style == 'soldier' then
		-- (B30) the soldier game's training pad (Stations.soldier): the pad, the dummy target, the sandbags, the bits
		local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
		zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
		eq = st:group('Equipment')
		gear = eq:group('Gear')
		k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
		Stations.soldier(st, k, tier, paid)
	else
		-- (B31 LOOK, the user: "bring back the old shooting ranges just with the side barriers removed, they look better")
		-- the themed bays as they were before 39b16b0 ($S/diag_ranges.jpg): the stepped rim, the flat inset mat with its
		-- darker border, the waist-high bench, each theme's kit (Stations.Lanes) and effects. No side walls
		-- (Stations.walls is not built), so a bay is open at both long sides.
		Stations.rim(st, t)
		local mat = st:box('Mat', V(-MX + 0.45, 0, -MZ + 0.45), V(MX - 0.45, Y, MZ - 0.45), t.mat, t.matMat or M.Plastic)
		if mat.Material == M.Plastic then studs(mat) end
		local ring = t.mat:Lerp(C(0, 0, 0), 0.2)
		for _, b in { { V(-MX, 0, -MZ), V(MX, Y, -MZ + 0.45) }, { V(-MX, 0, MZ - 0.45), V(MX, Y, MZ) },
			{ V(-MX, 0, -MZ + 0.45), V(-MX + 0.45, Y, MZ - 0.45) }, { V(MX - 0.45, 0, -MZ + 0.45), V(MX, Y, MZ - 0.45) } } do
			local p = st:box('MatBorder', b[1], b[2], ring, t.matMat or M.Plastic)
			if p.Material == M.Plastic then studs(p) end
		end
		if t.edge then
			for _, b in { { V(-MX, Y, -MZ), V(MX, Y + 0.14, -MZ + 0.08) }, { V(-MX, Y, MZ - 0.08), V(MX, Y + 0.14, MZ) },
				{ V(-MX, Y, -MZ), V(-MX + 0.08, Y + 0.14, MZ) }, { V(MX - 0.08, Y, -MZ), V(MX, Y + 0.14, MZ) } } do
				decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.Neon)).CastShadow = false
			end
		end
		local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
		zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
		Stations.bench(st, t, tier)
		eq = st:group('Equipment')
		gear = eq:group('Gear')
		k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
		local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
		lane(k)
	end
	-- Small things on the gear and every target never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	-- (LOBBY6) the best lane: the highest multiplier of all (Gold Bay, x250) wears BEST! on its label
	local best = true
	for _, row in skins.Stations do
		if row ~= s and (row.Multiplier or 0) >= (s.Multiplier or 0) then best = false end
	end
	local labelAt = Stations.Style == 'soldier' and Stations.LABEL or Stations.THEMED_LABEL
	Stations.labels(st, s, t, labelAt + V(0, (t.labelLift or 0) + (opts.labelLift or 0), 0), { best = best })
	if paid then
		if Stations.Style ~= 'soldier' then Stations.promo(st, t, s, VFX) end
		model:SetAttribute('Pass', s.Pass) -- (a Robux lane: Lobby.client keeps it in colour while locked)
	end
	if best then model:SetAttribute('Best', true) end
	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(k.mainAim or (Stations.Style == 'soldier' and V(0, 4.6, Stations.DUMMY_Z) or V(0, 4.2, 6)))).Position)
	model:SetAttribute('HitColor', t.glow)
	if Stations.Style ~= 'soldier' and opts.vfx ~= false and VFX then
		-- the theme's effects fill the target field (not the shooter's box), from the bench to the backstop
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
	if Stations.Compact and Stations.Style ~= 'soldier' and (not Stations.CompactOnly or Stations.CompactOnly[stationId]) then Stations.compact(model, st:world(CFrame.new())) end
	return model
end

-- Pull a built lane together along its length (Stations.Compact): `frame` is the lane's frame in the world. Moves every
-- part, the models' pivots (the bobbing bunting, the crown) and the world points the client reads (Aim, HitPoint).
function Stations.compact(model, frame)
	local K = Stations.Compact
	local function f(z)
		if z < K.Front1 then return z + K.Front end
		if z < K.Cut then return z + K.Bench end
		return z - K.Back
	end
	local function shiftOf(z) return f(z) - z end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = frame:ToObjectSpace(p.CFrame)
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
			local s = p.Size
			local hz = (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) / 2
			local z0, z1 = rel.Z - hz, rel.Z + hz
			-- which of the part's own axes runs along the lane (only a straight piece is stretched)
			local axis = (math.abs(r20) > 0.999 and 'X') or (math.abs(r21) > 0.999 and 'Y') or (math.abs(r22) > 0.999 and 'Z') or nil
			local spans = axis and z1 - z0 > 2.5 and ((z0 < K.Cut and z1 > K.Cut) or (z0 < K.Front1 and z1 > K.Front1))
			if spans then
				local a, b = f(z0), f(z1)
				if b - a > 0.2 then
					local len = b - a
					p.Size = axis == 'X' and V(len, s.Y, s.Z) or (axis == 'Y' and V(s.X, len, s.Z) or V(s.X, s.Y, len))
					p.CFrame = frame * (CFrame.new(rel.X, rel.Y, (a + b) / 2) * rel.Rotation)
				else
					p.CFrame = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel
				end
			else
				p.CFrame = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel
			end
		end
	end
	for _, m in model:GetDescendants() do
		if m:IsA('Model') then
			local ok, pivot = pcall(function() return m.WorldPivot end)
			if ok and pivot and not m.PrimaryPart then
				local rel = frame:ToObjectSpace(pivot)
				pcall(function() m.WorldPivot = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel end)
			end
		end
	end
	for _, inst in { model, table.unpack(model:GetDescendants()) } do
		for _, name in { 'Aim', 'HitPoint' } do
			local v = inst:GetAttribute(name)
			if typeof(v) == 'Vector3' then
				local rel = frame:PointToObjectSpace(v)
				inst:SetAttribute(name, frame:PointToWorldSpace(V(rel.X, rel.Y, f(rel.Z))))
			end
		end
	end
end
---------------------------------------------------------------------------------------------- armory
-- The ARMORY, LOBBY5 (BRIEF23: "the armory, we need to make it like in the superhero game. It looks way better
-- smaller"): ref_lobby.png's EVOLUTIONS 3 TIERS stand. Square pads in tight rows on three tiers, each gun floating in
-- profile over its own pad, a compact island (35 x 24 studs, was 61 x 33 plus a back block to the wall):
--   Island  a low studded apron (0.4) in the stand's pale tone inside a dark kerb, the walkway round it.
--   Tiers   three studded decks 3.2 apart (1.2, 4.4, 7.6; four 0.8 risers each), 6.5 deep, the whole width; guns 1-3 on
--           the front deck, 4-7 on the middle tier, 8-10 on the top tier, each row standing between the guns of the row
--           in front (so every gun and nameplate shows between the ones below it); a stair at each end climbs tier to
--           tier; a low backdrop with pilasters and corner posts closes the top tier.
--   Slot    the reference's white-framed square: a white rim round a studded mat in the state's soft tone, the 4-stud pad
--           on it (a dark plinth, a pale body with a state-coloured line, a light lip, the face: a dark rim, the glowing
--           state colour, a light core) and a plate on its front (LOCKED / BUY / OWNED / EQUIPPED). The gun floats over
--           it in profile (3-4 studs, CRITIC3 r1: "specks" at 1.4-3.1), tilted a little, bobbing; over the gun the
--           soldier stand's plate: one big "xN Power" and under it the price (red locked, yellow BUY) or the state.
-- Step onto a pad (its front half) for the Buy / Equip prompt. Neon only on the pad faces; saturated colour only on
-- the pads, the guns and their nameplates. State colours (GunRules.Colors; Armory.client repaints): pink locked,
-- blue owned, green equipped.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun (a direct child of the Armory model)
-- with attributes GunId, Tier, Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part on the pad's front half: prompt anchor and buy-distance point
--   StateTop           parts in the state colour (the pad face and its side line)
--   StateGlow          the face's light core, with the pad's PointLight under it
--   StateShade         the face's dark rim (the state's dark tone)
--   StateMat           the slot's studded mat round the pad (the state's soft tone)
--   StateStrip         the front plate, with SurfaceGui > TextLabel State; StateHaze (ParticleEmitter)
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Bob) with the gun inside, horizontal, in profile to the hall
-- The Armory model is tagged HoodArmory; each slot streams Atomic.
-- Local frame: origin at the centre of the island's front edge on the hall floor, front faces -Z (players stand at
-- -Z looking +Z); footprint x -Armory.ApronHalf..ApronHalf, z 0..Armory.Depth; the backdrop's top at Armory.Top
-- (nameplates float to about 11.5).
local Armory = {}

Armory.Apron = { y = 0.4, front = 2.0, side = 1.6, back = 1.0, kerb = 0.8 } -- the island round the stand
Armory.HalfWidth = 18.4 -- the stand's half width (the stairs' outer edges) (B31 PLAZA: the whole stand 1.15x, read from the spawn)
Armory.ApronHalf = Armory.HalfWidth + Armory.Apron.side
-- the tiers: each one's deck top and the z of its front wall (the first is the front deck, one riser over the apron)
Armory.Tiers = { { y = 1.2, z = 2.0 }, { y = 4.4, z = 9.5 }, { y = 7.6, z = 17.0 } }
Armory.TierDepth = 7.5
Armory.BackZ = 24.5 -- the top tier's back (the backdrop stands behind it)
Armory.BackT, Armory.BackH = 1.2, 3.4 -- the backdrop's thickness and its height over the top tier
Armory.Depth = Armory.BackZ + Armory.BackT + Armory.Apron.back
Armory.Top = Armory.Tiers[3].y + Armory.BackH
-- the rows, front to back: the tier each stands on and x of each gun in Spacing units from the viewer's left (+X) to
-- the right; each row stands between the guns of the row in front
Armory.Rows = {
	{ tier = 1, xs = { 1, 0, -1 } },
	{ tier = 2, xs = { 1.5, 0.5, -0.5, -1.5 } },
	{ tier = 3, xs = { 1, 0, -1 } },
}
Armory.Spacing = 7.6 -- the pitch along a row (a pad and a 1.4-stud gap between the mats)
Armory.RowInset = 4.25 -- a row's pad centre behind its tier's front wall (1.2 of free deck in front of the mats)
Armory.Pad = 4.6 -- the pad's side (square)
Armory.Mat, Armory.MatDepth = 6.0, 5.75 -- the slot's white-framed tile round the pad
Armory.MaxLength = 4.6
Armory.GunK = 3.0 -- display length = GunK x sqrt(natural length), +3% a tier, up to MaxLength (3-4 studs)
Armory.Tilt = 17 -- degrees the muzzle points up
Armory.Float = 0.8 -- the gun's lowest point over the pad
Armory.DisplayH = 3.45 -- the tallest a tilted gun may stand (taller ones are scaled down; nameplates sit over it)
Armory.Bob, Armory.BobPeriod = 0.18, 2.6
Armory.StairW = 3.0 -- the stairs at each end, x +-(HalfWidth - StairW .. HalfWidth)
Armory.StairRun = 1.0 -- tread depth
Armory.LabelW, Armory.LabelH = 6.0, 2.7 -- the nameplate's size (B31: the price line over a stud tall)
-- Tones, two or three per surface: a lit body, a darker band at the foot and under every cap, a light trim on
-- every top edge, in the hall floor's lavender family.
Armory.Tone = {
	-- (B34 fix round: warm greys and cream instead of the cold lavender, on the east quadrant's green field)
	deck = C(214, 204, 190), tread = C(222, 212, 198), trim = C(240, 232, 220), face = C(150, 132, 118),
	kick = C(118, 102, 92), riser = C(178, 164, 150), wall = C(176, 160, 146), band = C(136, 118, 104),
	pilaster = C(222, 212, 198), pad = C(228, 220, 208), padLip = C(244, 238, 228), plinth = C(130, 112, 100),
	apron = C(196, 188, 176), kerb = C(98, 86, 78), kerbTop = C(132, 116, 104),
	matRim = C(244, 246, 255),
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

-- The dark tone of a state (GunRules.Colors[state].Shade, or the plate colour darkened when an older GunRules has none).
function Armory.shade(look)
	return look.Shade or look.Strip:Lerp(C(0, 0, 0), 0.35)
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

-- The display gun: GunModels.build when it exists (else the stand-in), sized for its small pad (LOBBY5: the
-- superhero stand's small items). Small guns are scaled up more than big ones (display length ~ natural length^0.5),
-- so a pistol is about 2 studs and the long guns about 3, and each tier gets 3% more on top, up to MaxLength.
function Armory.gun(gun, shrink)
	local models = Armory.optional('GunModels')
	local function make(scale)
		if models and models.build then
			local ok, model = pcall(models.build, gun.Id, scale)
			if ok and model then return model end
		end
		return Armory.placeholder(gun, scale)
	end
	-- (B31 PLAZA) through ItemMeshes (GunStand_<Id>, the user's own gun designs when they land), the Part gun as the
	-- fallback: the mesh is fitted to the Part gun's display length, its pivot at its centre
	local IM = Armory.optional('ItemMeshes')
	if IM and IM.has and IM.place and IM.has('GunStand_' .. gun.Id) then
		local probe = make(1)
		local plo, phi = Armory.extents(probe, Armory.pivotOf(probe))
		probe:Destroy()
		local pl = math.max(phi.X - plo.X, phi.Y - plo.Y, phi.Z - plo.Z, 0.1)
		local len = math.min(Armory.MaxLength, Armory.GunK * pl ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
		local ok, m = pcall(IM.place, 'GunStand_' .. gun.Id, CFrame.new(), len, nil, function() return nil end, { center = true })
		if ok and m then
			m.Name = gun.Id
			pcall(function() m.WorldPivot = CFrame.new() end)
			for _, p in m:GetDescendants() do
				if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
			end
			return m
		end
	end
	local model = make(1)
	local lo, hi = Armory.extents(model, Armory.pivotOf(model))
	local size = hi - lo
	local longest = math.max(size.X, size.Y, size.Z, 0.1)
	local length = math.min(Armory.MaxLength, Armory.GunK * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- Effects that grow with tier (`part` is a box round the gun, which sizes them): a soft light for tiers 2-5, then
-- HoodVFX.item when the VFX module is there, otherwise a light, sparkles, rising glow and star glints for the last
-- two. All of it sized for the small stand: short lights, particles at most 1.1 studs.
function Armory.effects(part, tier, color)
	if tier < 2 then return end -- the free pistol stays plain, like the basic tool in the reference
	-- Tiers 2-5 get only a soft light: like the reference, effects are for the better items.
	if tier < 6 then
		light(part, color, 0.4 + tier * 0.08, 4 + tier * 0.3)
		return
	end
	local vfx = Armory.optional('HoodVFX')
	if vfx and vfx.item then
		local ok, made = pcall(vfx.item, part, tier, color)
		if ok then
			-- A shop display keeps only the small effects: no halo, rays, arcs or glitter (they white out the stand,
			-- worst with built-in textures), the rest capped at 1.1 studs and rising slowly so they stay under the
			-- nameplate.
			local kill = { ItemGlow = true, ItemRays = true, ItemArcs = true, ItemGlitter = true }
			for _, e in (type(made) == 'table' and made or {}) do
				if typeof(e) == 'Instance' and kill[e.Name] then
					e:Destroy()
				elseif typeof(e) == 'Instance' and e:IsA('ParticleEmitter') then
					pcall(function()
						local most = 0
						for _, kp in e.Size.Keypoints do most = math.max(most, kp.Value + kp.Envelope) end
						if most > 1.1 then
							local f, keys = 1.1 / most, {}
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
	light(part, color, 0.4 + tier * 0.08, 4 + tier * 0.3)
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
		emitter('Sparkles', 'rbxasset://textures/particles/sparkles_main.dds', 2 + tier, { 0.8, 1.5 }, { 0.3, 0.9 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15 + tier * 0.02), NumberSequenceKeypoint.new(1, 0) }), fade)
	end
	if tier >= 6 then
		local glow = emitter('Glow', 'rbxasset://textures/particles/fire_main.dds', 2 + tier * 0.5, { 0.9, 1.6 }, { 0.4, 0.9 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 + tier * 0.04), NumberSequenceKeypoint.new(1, 0.1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }))
		glow.EmissionDirection = Enum.NormalId.Top
		glow.SpreadAngle = Vector2.new(25, 25)
		glow.Acceleration = V(0, 1.0, 0)
	end
	if tier >= 9 then
		local star = emitter('Glints', 'rbxasset://textures/particles/sparkles_main.dds', 3, { 1.2, 2 }, { 0.2, 0.5 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) }),
			NumberSequence.new(0.1))
		star:SetAttribute('PreviewTexture', 'star')
	end
end

-- The nameplate over a gun (LOBBY5 r2, CRITIC3: "one big +N Power line per pad, like the soldier stand's"): two
-- lines, the soldier game's stand plates (the gun's name is the prompt's, when you step on its pad):
--   Multiplier  big: "xN Power" with the Power icon
--   Price       the price with the Cash icon, or the state: EQUIPPED (green), OWNED (blue), BUY + price (yellow,
--               a locked gun you can afford), the price in red while it is locked (Armory.client repaints it)
-- Icons come from IconModels.Images when uploaded, else a text glyph kept in the label's Glyph attribute. 5.8 x 2.5
-- studs, its big line 1.5 tall, readable from the spine; HoodClient/LabelFade keeps it whole to 50 studs and fades it
-- out by 75 (FadeNear / FadeFar on the gui, over kind Gun's 38 / 62), so the whole ladder reads from the walkway like
-- the soldier stand and the far shelf is gone from the stages. (It sets MaxDistance itself: 80 is a fallback.)
function Armory.label(c, pos, gun, state, colors)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	g.Size = UDim2.fromScale(Armory.LabelW, Armory.LabelH)
	g.MaxDistance = 46
	-- (LOBBY5 r3, CRITIC3: the whole price ladder reads from the walkway, the back tiers too; B31 PLAZA, critic 3: up close
	-- only, whole to 34 studs, gone by 46, so the plaza's other views stay clear of the stand's ten plates)
	g:SetAttribute('FadeNear', 34)
	g:SetAttribute('FadeFar', 46)
	g.LightInfluence = 0
	g.Parent = anchor
	local ink = C(24, 22, 40)
	local look = colors[state] or {}
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y, h, stroke)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.title, y, h, ink, stroke)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = name == 'Price' and 'PriceIcon' or 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.1, y)
			i.Size = UDim2.fromScale(0.17, h)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.28, y)
			t.Size = UDim2.fromScale(0.7, h)
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
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier .. ' Power', P.white, 0, 0.6, 3)
	local price = row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), look.Word or C(255, 228, 92), 0.62, 0.38, 2)
	if state == 'Equipped' or state == 'Owned' then price.Text = string.upper(state) end
	shadowAll(g)
	return anchor
end

-- One gun on its pad. (x, z) is the pad centre, y the deck it stands on.
function Armory.slot(c, gun, x, z, y, colors)
	local T = Armory.Tone
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local deck = y
	-- The slot's tile (the reference's white-framed square): a raised white rim round a studded mat in the state's
	-- soft tone; the pad stands in it.
	local mw, md, rw = Armory.Mat / 2, Armory.MatDepth / 2, 0.32
	studs(s:box('StateMat', V(x - mw + rw, y, z - md + rw), V(x + mw - rw, y + 0.12, z + md - rw), look.Mat or look.Glow, M.Plastic))
	for _, e in { { V(x - mw, y, z - md), V(x + mw, y + 0.2, z - md + rw) }, { V(x - mw, y, z + md - rw), V(x + mw, y + 0.2, z + md) },
		{ V(x - mw, y, z - md + rw), V(x - mw + rw, y + 0.2, z + md - rw) }, { V(x + mw - rw, y, z - md + rw), V(x + mw, y + 0.2, z + md - rw) } } do
		s:box('MatRim', e[1], e[2], T.matRim, M.SmoothPlastic)
	end
	y += 0.12
	-- The pad, bottom up: a dark plinth, the pale body with a state-coloured line round it, a light lip, and the face: a
	-- dark rim, the glowing state colour, a light core carrying the pad's light. Neon only on the face.
	local h = Armory.Pad / 2
	s:box('PadPlinth', V(x - h - 0.1, y, z - h - 0.1), V(x + h + 0.1, y + 0.16, z + h + 0.1), T.plinth, M.SmoothPlastic)
	s:box('PadBase', V(x - h, y + 0.16, z - h), V(x + h, y + 0.5, z + h), T.pad, M.SmoothPlastic)
	decor(s:box('StateTop', V(x - h - 0.03, y + 0.27, z - h - 0.03), V(x + h + 0.03, y + 0.36, z + h + 0.03), look.Top, M.SmoothPlastic)).CastShadow = false
	s:box('PadLip', V(x - h + 0.04, y + 0.5, z - h + 0.04), V(x + h - 0.04, y + 0.56, z + h - 0.04), T.padLip, M.SmoothPlastic)
	local top = y + 0.56
	decor(s:box('StateShade', V(x - h + 0.22, top, z - h + 0.22), V(x + h - 0.22, top + 0.03, z + h - 0.22), Armory.shade(look), M.SmoothPlastic)).CastShadow = false
	decor(s:box('StateTop', V(x - h + 0.42, top, z - h + 0.42), V(x + h - 0.42, top + 0.06, z + h - 0.42), look.Top, M.Neon)).CastShadow = false
	local core = decor(s:box('StateGlow', V(x - 0.7, top, z - 0.7), V(x + 0.7, top + 0.08, z + 0.7), look.Glow, M.Neon))
	core.CastShadow = false
	-- the face's glow on the tile round the pad (Armory.client recolours it with the face): short and soft
	light(core, look.Top, 1.2, 6)
	top += 0.08
	-- Soft haze rising off the face in the state colour, the reference's faint light over each pad (the client recolours it).
	local hazeSource = ghost(s:part('StateHazeSource', V(h * 1.2, 0.2, h * 1.2), CFrame.new(x, top + 0.1, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 1.6
	haze.Lifetime = NumberRange.new(1.2, 1.8)
	haze.Speed = NumberRange.new(0.6, 1.0)
	haze.SpreadAngle = Vector2.new(6, 6)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 1.5) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.88), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	-- The plate on the pad's front: a block on the plinth with a light cap and two bolts, the state word on it.
	local strip = s:box('StateStrip', V(x - 1.35, y + 0.04, z - h - 0.24), V(x + 1.35, y + 0.5, z - h + 0.02), look.Strip, M.SmoothPlastic)
	s:box('PlateCap', V(x - 1.42, y + 0.5, z - h - 0.28), V(x + 1.42, y + 0.58, z - h + 0.02), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		decor(s:part('PlateBolt', V(0.06, 0.14, 0.14), CFrame.new(x + sx * 1.18, y + 0.27, z - h - 0.25) * CFrame.Angles(0, math.pi / 2, 0), T.trim, M.Metal, Enum.PartType.Cylinder))
	end
	local sg = surface(strip, Enum.NormalId.Front, 60)
	sg.Name = 'StateGui'
	line(sg, 'State', string.upper(state), P.white, FONT.title, 0.06, 0.88, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun floating over the pad in profile to the hall (muzzle to the viewer's right), tilted up a little,
	-- bobbing; never turning, so it is never seen end-on.
	local d, display = s:group('Display')
	local tilt = math.rad(Armory.Tilt)
	local function measure(m)
		local lo, hi = Armory.extents(m, Armory.pivotOf(m))
		return lo, hi, (hi.Y - lo.Y) * math.cos(tilt) + (hi.Z - lo.Z) * math.sin(tilt)
	end
	local g = Armory.gun(gun, 1)
	local lo, hi, tall = measure(g)
	if tall > Armory.DisplayH then
		-- a deep gun (an Uzi's long magazine) stands too tall tilted: a size smaller, under the nameplate
		g:Destroy()
		g = Armory.gun(gun, Armory.DisplayH / tall)
		lo, hi, tall = measure(g)
	end
	local mid = (lo + hi) / 2
	local length = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
	local centre = V(x, top + Armory.Float + tall / 2, z + 0.15)
	local pose = CFrame.new(centre) * CFrame.Angles(0, 0, -tilt) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:SetAttribute('Bob', Armory.Bob)
	display:SetAttribute('BobPeriod', Armory.BobPeriod)
	display:AddTag('HoodMotion')
	local fx = ghost(s:part('FxCore', V(length * 0.5, math.max(tall * 0.7, length * 0.25), length * 0.2), CFrame.new(centre), gun.Color))
	fx.CastShadow = false
	Armory.effects(fx, gun.Tier, gun.Color)
	-- (every label in a row at one height, over the tallest gun, like the reference's nameplates)
	Armory.label(s, V(x, top + Armory.Float + Armory.DisplayH + 0.3 + Armory.LabelH / 2, z), gun, state, colors)
	-- Where the prompt sits and the server measures buying distance from: on the pad's front half, so stepping onto
	-- the pad (in front of the floating gun) brings up Buy / Equip, like the soldier game's stand.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.6, top + 0.2, z - 0.45 * h - 0.6), V(x + 0.6, top + 1.6, z - 0.45 * h + 0.6), P.white))
	point.CastShadow = false
	local _ = deck
	return model
end

-- A pilaster on a wall face at z = zf (facing -Z): a dark base, a light shaft, a light cap.
function Armory.pilaster(c, x, zf, y0, y1, w)
	local T = Armory.Tone
	w = w or 1.0
	c:box('Pilaster', V(x - w / 2, y0, zf - 0.35), V(x + w / 2, y1, zf), T.pilaster, M.SmoothPlastic)
	c:box('PilasterBase', V(x - w / 2 - 0.15, y0, zf - 0.5), V(x + w / 2 + 0.15, y0 + 0.5, zf), T.kick, M.SmoothPlastic)
	c:box('PilasterCap', V(x - w / 2 - 0.15, y1 - 0.35, zf - 0.5), V(x + w / 2 + 0.15, y1, zf), T.trim, M.SmoothPlastic)
end

-- The island and the stand: the apron in its kerb, the three tiers (studded bodies, a dark kick at each wall's foot, a
-- dark band under a light coping on its top edge), a stair at each end from tier to tier, the backdrop on the top
-- tier's back (studded, a dark kick, a dark band under a light coping, pilasters between the top row's guns, corner
-- posts at its ends). Every surface in two or three tones.
function Armory.base(c)
	local b = c:group('ArmoryBase')
	local T, Ap = Armory.Tone, Armory.Apron
	local X, AX, D, Ay, kw = Armory.HalfWidth, Armory.ApronHalf, Armory.Depth, Ap.y, Ap.kerb
	local tiers, BZ, SW = Armory.Tiers, Armory.BackZ, Armory.StairW
	-- the island: a studded apron inside a dark studded kerb (0.15 proud) with a pale top band, studded corner blocks
	studs(b:box('ArmoryApron', V(-AX + kw, 0, kw), V(AX - kw, Ay, D - kw), T.apron))
	local ky = Ay + 0.15
	for _, e in { { V(-AX, 0, 0), V(AX, ky, kw) }, { V(-AX, 0, D - kw), V(AX, ky, D) }, { V(-AX, 0, kw), V(-AX + kw, ky, D - kw) }, { V(AX - kw, 0, kw), V(AX, ky, D - kw) } } do
		studs(b:box('ApronKerb', e[1], e[2], T.kerb, M.Plastic), true)
		decor(b:box('ApronKerbTop', V(e[1].X + 0.12, ky, e[1].Z + 0.12), e[2] + V(-0.12, 0.03, -0.12), T.kerbTop, M.SmoothPlastic)).CastShadow = false
	end
	for _, cx in { -AX + 0.7, AX - 0.7 } do
		for _, cz in { 0.7, D - 0.7 } do
			studs(b:box('ApronCorner', V(cx - 0.9, 0, cz - 0.9), V(cx + 0.9, 0.8, cz + 0.9), T.kerb, M.Plastic), true)
			b:box('ApronCornerCap', V(cx - 1.0, 0.8, cz - 1.0), V(cx + 1.0, 0.95, cz + 1.0), T.trim, M.SmoothPlastic)
		end
	end
	-- the tiers: each a studded body from its front wall to the top tier's back under a studded top slab (two tones), a
	-- dark kick at its wall's foot, a dark band under a light coping on its front edge; the band and coping run round the
	-- ends too
	for k, t in tiers do
		local y0 = k == 1 and Ay or tiers[k - 1].y
		studs(b:box('ArmoryTier', V(-X, Ay, t.z), V(X, t.y - 0.12, BZ), T.wall, M.Plastic), true)
		studs(b:box('ArmoryTierTop', V(-X, t.y - 0.12, t.z), V(X, t.y, BZ), T.deck, M.Plastic))
		b:box('TierKick', V(-X - 0.04, y0, t.z - 0.12), V(X + 0.04, y0 + 0.3, t.z), T.kick, M.SmoothPlastic)
		b:box('TierBand', V(-X - 0.04, t.y - 0.62, t.z - 0.1), V(X + 0.04, t.y - 0.3, t.z), T.band, M.SmoothPlastic)
		b:box('TierCoping', V(-X - 0.08, t.y - 0.3, t.z - 0.3), V(X + 0.08, t.y + 0.02, t.z + 0.35), T.trim, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			local a, e = sx * X, sx * (X + 0.1)
			b:box('TierBand', V(math.min(a, e), t.y - 0.62, t.z), V(math.max(a, e), t.y - 0.3, BZ), T.band, M.SmoothPlastic)
			-- (one kick along each end's foot: the upper tiers stand on the same foot)
			if k == 1 then b:box('TierKick', V(math.min(a, e), Ay, t.z), V(math.max(a, e), Ay + 0.3, BZ), T.kick, M.SmoothPlastic) end
		end
	end
	-- the stairs at each end, from each tier up to the next (0.8 risers on 1.0 treads, ending at the next tier's front
	-- wall): a mid-tone riser body under a light studded tread, a light stringer cap along the outer edge
	for k = 2, #tiers do
		local lo, hi, zt = tiers[k - 1].y, tiers[k].y, tiers[k].z
		local n = math.ceil((hi - lo) / 0.81) - 1
		local rise, run = (hi - lo) / (n + 1), Armory.StairRun
		for _, sx in { -1, 1 } do
			local l, r = math.min(sx * (X - SW), sx * X), math.max(sx * (X - SW), sx * X)
			for j = 1, n do
				local z0 = zt - (n + 1 - j) * run
				local h = lo + j * rise
				b:box('ArmoryStair', V(l, lo, z0), V(r, h - 0.15, zt), T.riser, M.SmoothPlastic)
				studs(b:box('StairTread', V(l, h - 0.15, z0 - 0.05), V(r, h, z0 + run), T.tread, M.Plastic))
			end
		end
	end
	-- the backdrop on the top tier's back: studded both sides, a dark kick, a dark band and a light coping; pilasters
	-- between the top row's guns; corner posts from the apron to over the coping at its ends
	local y3 = tiers[#tiers].y
	local top = Armory.Top
	studs(b:box('ArmoryBack', V(-X, Ay, BZ), V(X, top, BZ + Armory.BackT), T.wall, M.Plastic), true)
	b:box('BackKick', V(-X, y3, BZ - 0.12), V(X, y3 + 0.4, BZ), T.kick, M.SmoothPlastic)
	b:box('BackBand', V(-X, top - 0.9, BZ - 0.12), V(X, top - 0.4, BZ), T.band, M.SmoothPlastic)
	b:box('BackCoping', V(-X - 0.2, top - 0.4, BZ - 0.4), V(X + 0.2, top, BZ + Armory.BackT + 0.2), T.trim, M.SmoothPlastic)
	local row = Armory.Rows[#Armory.Rows]
	for i = 1, #row.xs - 1 do
		Armory.pilaster(b, (row.xs[i] + row.xs[i + 1]) / 2 * Armory.Spacing, BZ, y3, top - 0.9)
	end
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (X - 1.0), sx * (X + 0.25)
		local l, r = math.min(xa, xb), math.max(xa, xb)
		b:box('CornerPost', V(l, Ay, BZ - 0.8), V(r, top + 0.6, BZ + Armory.BackT + 0.25), T.pilaster, M.SmoothPlastic)
		b:box('CornerBase', V(l - 0.15, Ay, BZ - 0.95), V(r + 0.15, Ay + 0.7, BZ + Armory.BackT + 0.4), T.kick, M.SmoothPlastic)
		b:box('CornerCap', V(l - 0.15, top + 0.6, BZ - 0.95), V(r + 0.15, top + 0.9, BZ + Armory.BackT + 0.4), T.trim, M.SmoothPlastic)
	end
	-- a thin white neon line along the coping's front: the stand's outline from across the hall (the reference's lit edge)
	decor(b:box('BackNeon', V(-X + 1.0, top - 0.42, BZ - 0.44), V(X - 1.0, top - 0.3, BZ - 0.4), C(240, 246, 255), M.Neon)).CastShadow = false
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
	-- the guns in order, row by row from the front, each row from the viewer's left (gun 1 on the front row's left:
	-- their left is +X when they look toward +Z)
	local i = 0
	for _, row in Armory.Rows do
		local t = Armory.Tiers[row.tier]
		for _, u in row.xs do
			i += 1
			local gun = guns[i]
			if not gun then return model end
			Armory.slot(a, gun, u * Armory.Spacing, t.z + Armory.RowInset, t.y, colors)
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- buildings
-- The reference street's buildings (ref1_street.png, measured with a matched camera): studded red brick, two
-- storeys of ~15 studs, a slate-blue band between them, big grey-framed windows of four blue panes, a slate eave
-- and a low hip roof. Building frame: origin at the facade's left end on the ground, +X along the facade, +Z out
-- of it; the building runs back to z = -depth. One builder serves both sides of the street.
local function lotFrame(ctx, s, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-FRONT, 0, za), V(-FRONT - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(FRONT, 0, za - w), V(FRONT + 1, 0, za - w)))
end

-- Window: a studded grey stone frame standing proud of the wall, a lighter stone sill under it and a lintel over it
-- (each a step further out, so the frame reads in three shades and casts a shadow line), and, set back inside, four
-- studded panes (the two on the left a darker blue, like the reference's reflections) split by navy bars.
-- x = centre, y = frame bottom.
local function window(c, x, y, o)
	o = o or {}
	local w, h, t = o.w or 15, o.h or P.street.winH, 1.3
	local x0, x1, y1 = x - w / 2, x + w / 2, y + h
	local trim = P.st.trim
	-- (the frame stands 1 stud proud, so the glass sits in a 0.9-deep recess with a shadowed reveal)
	sbox(c, 'WindowFrame', V(x0, y, -0.2), V(x0 + t, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x1 - t, y, -0.2), V(x1, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y, -0.2), V(x1 - t, y + t, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y1 - t, -0.2), V(x1 - t, y1, 1.0), trim, true)
	sbox(c, 'WindowSill', V(x0 - 0.6, y - 0.8, -0.2), V(x1 + 0.6, y, 1.6), P.st.sill, true)
	sbox(c, 'WindowLintel', V(x0 - 0.3, y1, -0.2), V(x1 + 0.3, y1 + 0.9, 1.3), P.st.trimDark, true)
	-- the reveal: a darker strip inside the top and left of the frame, where the frame shades the glass (big windows
	-- only: on small ones it isn't seen and the parts add up on tall buildings)
	if w >= 8 then
		local rev = P.st.trimDark:Lerp(P.black, 0.3)
		sbox(c, 'WindowReveal', V(x0 + t, y1 - t - 0.45, -0.2), V(x1 - t, y1 - t, 0.5), rev, true)
		sbox(c, 'WindowReveal', V(x0 + t, y + t, -0.2), V(x0 + t + 0.45, y1 - t - 0.45, 0.5), rev, true)
	end
	local n = o.panes or (w >= 9 and 4 or 2)
	local bar = 0.7
	local g0, g1 = x0 + t, x1 - t
	local pw = (g1 - g0 - (n - 1) * bar) / n
	-- the glass: one darker pane across the opening, the right half lighter, navy bars in front
	sbox(c, 'Glass', V(g0, y + t, -0.2), V(g1, y1 - t, 0.1), P.st.glassA, true)
	sbox(c, 'Glass', V((g0 + g1) / 2, y + t, -0.2), V(g1, y1 - t, 0.12), P.st.glassB, true)
	for k = 1, n - 1 do
		local a = g0 + k * pw + (k - 1) * bar
		sbox(c, 'WindowBar', V(a, y + t, -0.2), V(a + bar, y1 - t, 0.25), P.st.mullion, true)
	end
end

-- Hip roof (45 degrees by default) in studded slate over the rectangle x0..x1, z0..z1 standing at y: a darker eave
-- slab overhanging the walls by one stud, wedge slopes on all four sides with corner wedges, and a flat top with a
-- darker rim round a lighter panel.
local function hipRoof(c, x0, z0, x1, z1, y, rise, run)
	rise, run = rise or 5, run or 5
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(x0 - 1, y, z0 - 1), V(x1 + 1, y + 1, z1 + 1), dark)
	y += 1
	local my = y + rise / 2
	local lx, lz = x1 - x0 - 2 * run, z1 - z0 - 2 * run
	local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
	-- (a wedge's slope rises toward its local +Z)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z1 - run / 2) * CFrame.Angles(0, math.pi, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z0 + run / 2), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x0 + run / 2, my, mz) * CFrame.Angles(0, math.pi / 2, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x1 - run / 2, my, mz) * CFrame.Angles(0, -math.pi / 2, 0), col, M.Plastic)
	-- corners: a corner wedge's peak stands over its local (+X, -Z) corner; turn it toward the roof's middle
	for _, k in { { x0, z1, 0 }, { x1, z1, 90 }, { x1, z0, 180 }, { x0, z0, -90 } } do
		local cx = k[1] + (k[1] == x0 and run / 2 or -run / 2)
		local cz = k[2] + (k[2] == z0 and run / 2 or -run / 2)
		local p = Instance.new('CornerWedgePart')
		p.Name = 'RoofCorner'
		p.Anchored = true
		p.Size = V(run, rise, run)
		p.CFrame = c:world(CFrame.new(cx, my, cz) * CFrame.Angles(0, math.rad(k[3]), 0))
		p.Color, p.Material = col, M.Plastic
		smooth(p)
		p.Parent = c.parent
	end
	sbox(c, 'RoofTop', V(x0 + run, y, z0 + run), V(x1 - run, y + rise + 0.3, z1 - run), dark)
	if lx > 2 and lz > 2 then sbox(c, 'RoofPanel', V(x0 + run + 1, y + rise + 0.3, z0 + run + 1), V(x1 - run - 1, y + rise + 0.5, z1 - run - 1), col, true) end
end

-- A face of a w x depth block as a facade frame (+Z out of it, +X along it as seen from outside), and its width.
local function faceFrame(c, face, w, depth)
	if face == 'left' then return c:at(CFrame.new(0, 0, -depth) * CFrame.Angles(0, -math.pi / 2, 0)), depth end
	if face == 'right' then return c:at(CFrame.new(w, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)), depth end
	if face == 'back' then return c:at(CFrame.new(w, 0, -depth) * CFrame.Angles(0, math.pi, 0)), w end
	return c, w
end

-- Gable roof, studded slate: the darker eave slab, two slopes up to a ridge cap, and brick gable triangles. along =
-- 'x': the ridge runs along the facade (eaves front and back); along = 'z': the ridge runs back from the street and
-- the gable (with a stone-trimmed pediment and a round vent) faces it.
local function gableRoof(c, w, d, H, rise, along, wall)
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(-1, H, -d - 1), V(w + 1, H + 1, 1), dark)
	local y = H + 1
	local function W(name, size, cf, color) studs(c:wedge(name, size, cf, color, M.Plastic), true) end
	if along == 'z' then
		-- slopes rising from the side eaves to a ridge over the middle; the gables front and back
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w / 4 - 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, math.pi / 2, 0), col)
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w * 3 / 4 + 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, -math.pi / 2, 0), col)
		for _, zf in { -0.5, -d + 0.5 } do
			W('Gable', V(1, rise, w / 2), CFrame.new(w / 4, y + rise / 2, zf) * CFrame.Angles(0, math.pi / 2, 0), wall)
			W('Gable', V(1, rise, w / 2), CFrame.new(w * 3 / 4, y + rise / 2, zf) * CFrame.Angles(0, -math.pi / 2, 0), wall)
		end
		sbox(c, 'RidgeCap', V(w / 2 - 0.6, y + rise - 0.3, -d - 1), V(w / 2 + 0.6, y + rise + 0.4, 1), dark, true)
		decor(c:part('GableVent', V(0.3, 2.2, 2.2), CFrame.new(w / 2, y + rise * 0.4, 0.1) * CFrame.Angles(0, math.pi / 2, 0), P.st.trim, M.Plastic, Enum.PartType.Cylinder))
		decor(c:part('GableVentHole', V(0.32, 1.4, 1.4), CFrame.new(w / 2, y + rise * 0.4, 0.12) * CFrame.Angles(0, math.pi / 2, 0), P.st.gutter, M.Plastic, Enum.PartType.Cylinder))
	else
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, 0.5 - d / 4) * CFrame.Angles(0, math.pi, 0), col)
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, -d * 3 / 4 - 0.5), col)
		for _, xf in { 0.5, w - 0.5 } do
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d * 3 / 4), wall)
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d / 4) * CFrame.Angles(0, math.pi, 0), wall)
		end
		sbox(c, 'RidgeCap', V(-1, y + rise - 0.3, -d / 2 - 0.6), V(w + 1, y + rise + 0.4, -d / 2 + 0.6), dark, true)
	end
end

-- Flat roof behind a brick parapet with a stone coping, a dark deck and rooftop clutter (air-con boxes, a vent).
local function flatRoof(c, w, d, H, wall)
	sbox(c, 'RoofDeck', V(0, H, -d), V(w, H + 0.4, 0), P.st.roofDark)
	for _, e in { { V(-0.3, H, -0.9), V(w + 0.3, H + 2.2, 0.3) }, { V(-0.3, H, -d - 0.3), V(w + 0.3, H + 2.2, -d + 0.9) },
		{ V(-0.3, H, -d), V(0.9, H + 2.2, 0) }, { V(w - 0.9, H, -d), V(w + 0.3, H + 2.2, 0) } } do
		sbox(c, 'Parapet', e[1], e[2], wall)
		sbox(c, 'Coping', V(e[1].X - 0.3, H + 2.2, e[1].Z - 0.3), V(e[2].X + 0.3, H + 2.8, e[2].Z + 0.3), P.st.trim, true)
	end
	for k, x in { w * 0.3, w * 0.62 } do
		sbox(c, 'RoofAirCon', V(x - 1.8, H + 0.4, -d * 0.55 - 1.5), V(x + 1.8, H + 2.6, -d * 0.55 + 1.5), C(206, 210, 216), true)
		decor(c:box('RoofAirConFan', V(x - 1.2, H + 2.6, -d * 0.55 - 1), V(x + 1.2, H + 2.75, -d * 0.55 + 1), C(110, 116, 126), M.Plastic))
		if k == 2 then decor(c:post('RoofVent', 0.5, 3.4, V(x + 4, H + 0.4, -d * 0.4), P.st.gutter, M.Plastic)) end
	end
end

-- Brick chimney stack on the roof: a stone cap and two pots.
local function chimney(c, x, z, y0, y1, wall)
	sbox(c, 'Chimney', V(x - 1.5, y0, z - 1.3), V(x + 1.5, y1, z + 1.3), wall)
	sbox(c, 'ChimneyCap', V(x - 1.8, y1, z - 1.6), V(x + 1.8, y1 + 0.6, z + 1.6), P.st.trim, true)
	for _, dx in { -0.7, 0.7 } do decor(c:post('ChimneyPot', 0.42, 1.0, V(x + dx, y1 + 0.6, z), P.st.trunk, M.Plastic)) end
end

-- An entrance in a facade frame at x: a stone surround standing proud of the wall, the door set back in it with a
-- glazed transom over it, a brass knob, a house number and a wall lamp. kind: 'stoop' (three steps up to a landing
-- between brick cheek walls with stone caps, a slate canopy on brackets), 'porch' (a deck across span = { x0, x1 }
-- with two steps, posts with bases and caps, a rail and a roof with a fascia) or 'door' (two steps and a canopy).
local function entrance(c, x, o)
	local kind, dw, number = o.kind or 'door', 3.8, o.number or '12'
	local rise = kind == 'stoop' and 1.8 or (kind == 'porch' and 1.0 or 0.9)
	local y0 = 0.6 + rise -- (the grass is at 0.6)
	local trim, dark = P.st.trim, P.st.trimDark
	-- surround, door, transom, knob, number, lamp
	sbox(c, 'DoorSurround', V(x - dw / 2 - 1.2, y0 - 0.2, -0.2), V(x - dw / 2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorSurround', V(x + dw / 2, y0 - 0.2, -0.2), V(x + dw / 2 + 1.2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorHead', V(x - dw / 2 - 1.5, y0 + 9.6, -0.2), V(x + dw / 2 + 1.5, y0 + 10.6, 1.0), dark, true)
	sbox(c, 'Door', V(x - dw / 2, y0, -0.2), V(x + dw / 2, y0 + 7.8, 0.15), o.door or C(40, 110, 76))
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 4.4, 0.15), V(x + dw / 2 - 0.5, y0 + 7.2, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 0.6, 0.15), V(x + dw / 2 - 0.5, y0 + 3.8, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'Transom', V(x - dw / 2, y0 + 7.8, -0.2), V(x + dw / 2, y0 + 9.6, 0.1), P.st.glassB, true)
	decor(c:box('DoorKnob', V(x + dw / 2 - 0.8, y0 + 3.9, 0.15), V(x + dw / 2 - 0.4, y0 + 4.3, 0.55), C(232, 188, 70), M.Plastic))
	local plate = sbox(c, 'HouseNumber', V(x + dw / 2 + 1.4, y0 + 6.2, -0.2), V(x + dw / 2 + 2.8, y0 + 7.4, 0.25), P.white, true)
	line(surface(plate, Enum.NormalId.Back, 30), 'Number', number, C(30, 40, 70), FONT.title, 0.05, 0.9)
	local lampBox = sbox(c, 'WallLamp', V(x - dw / 2 - 2.6, y0 + 6.4, 0), V(x - dw / 2 - 1.5, y0 + 8.0, 1.0), P.st.lamp, true)
	decor(c:box('WallLampGlow', V(x - dw / 2 - 2.45, y0 + 6.6, 1.0), V(x - dw / 2 - 1.65, y0 + 7.8, 1.1), P.st.lampGlow, M.Neon)).CastShadow = false
	light(lampBox, P.st.lampGlow, 0.6, 10)
	if kind == 'porch' then
		local x0, x1 = o.span[1], o.span[2]
		local dp = 3.6
		sbox(c, 'PorchDeck', V(x0, -1, 0), V(x1, y0, dp), C(176, 150, 120))
		sbox(c, 'PorchDeckEdge', V(x0 - 0.2, y0 - 0.5, dp - 0.4), V(x1 + 0.2, y0 + 0.1, dp + 0.2), C(150, 124, 96), true)
		for k = 1, 2 do sbox(c, 'PorchStep', V(x - 2.6, -1, dp + (k - 1) * 0.9), V(x + 2.6, y0 - k * 0.5, dp + k * 0.9), P.st.sill) end
		for _, px in { x0 + 0.5, x - 3.4, x + 3.4, x1 - 0.5 } do
			sbox(c, 'PorchPostBase', V(px - 0.7, y0, dp - 1.2), V(px + 0.7, y0 + 0.8, dp - 0.1), dark, true)
			sbox(c, 'PorchPost', V(px - 0.45, y0 + 0.8, dp - 0.95), V(px + 0.45, y0 + 8.6, dp - 0.35), P.white, true)
			sbox(c, 'PorchPostCap', V(px - 0.7, y0 + 8.6, dp - 1.2), V(px + 0.7, y0 + 9.1, dp - 0.1), dark, true)
		end
		for _, seg in { { x0 + 0.5, x - 3.4 }, { x + 3.4, x1 - 0.5 } } do
			sbox(c, 'PorchRail', V(seg[1], y0 + 2.6, dp - 0.8), V(seg[2], y0 + 3.0, dp - 0.5), P.white, true)
			for bx = seg[1] + 1, seg[2] - 0.5, 1.2 do decor(c:box('PorchBaluster', V(bx - 0.15, y0, dp - 0.75), V(bx + 0.15, y0 + 2.6, dp - 0.55), P.white, M.Plastic)) end
		end
		sbox(c, 'PorchRoof', V(x0 - 0.4, y0 + 9.1, -0.2), V(x1 + 0.4, y0 + 9.7, dp + 0.5), P.st.roofDark, true)
		sbox(c, 'PorchFascia', V(x0 - 0.5, y0 + 8.9, dp + 0.2), V(x1 + 0.5, y0 + 9.8, dp + 0.7), trim, true)
	else
		local steps = kind == 'stoop' and 3 or 2
		local land = kind == 'stoop' and 1.6 or 1.0
		local sw = dw + 2.4
		sbox(c, 'StoopLanding', V(x - sw / 2, -1, 0), V(x + sw / 2, y0, land), P.st.sill)
		for k = 1, steps do sbox(c, 'StoopStep', V(x - sw / 2, -1, land + (k - 1) * 0.9), V(x + sw / 2, y0 - k * rise / steps, land + k * 0.9), P.st.sill:Lerp(P.black, (k % 2) * 0.05)) end
		if kind == 'stoop' then
			local dz = land + steps * 0.9
			for _, sx in { -1, 1 } do
				local cx = x + sx * (sw / 2 + 0.5)
				sbox(c, 'CheekWall', V(cx - 0.5, -1, 0), V(cx + 0.5, y0 + 0.9, dz), P.st.brickDark)
				sbox(c, 'CheekCap', V(cx - 0.65, y0 + 0.9, 0), V(cx + 0.65, y0 + 1.3, dz + 0.15), trim, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, 0.3), V(cx + 0.12, y0 + 3.3, 0.6), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 3.0, 0.3), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, dz - 0.6), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
			end
		end
		sbox(c, 'Canopy', V(x - dw / 2 - 1.8, y0 + 10.8, -0.2), V(x + dw / 2 + 1.8, y0 + 11.3, 2.6), P.st.roofDark, true)
		sbox(c, 'CanopyFascia', V(x - dw / 2 - 1.9, y0 + 10.6, 2.4), V(x + dw / 2 + 1.9, y0 + 11.4, 2.8), trim, true)
		for _, sx in { -1, 1 } do decor(c:bar('CanopyBracket', V(x + sx * (dw / 2 + 1.2), y0 + 9.2, 0.2), V(x + sx * (dw / 2 + 1.2), y0 + 10.8, 2.2), 0.3, P.iron, M.Plastic)) end
	end
end

-- Shopfront on a facade frame (+Z out of the wall) between x0 and x1, the ground floor of a shop with flats above:
-- a stone stall riser, display glass in two tones split by dark mullions, a glazed door (sh.door = its centre, default
-- near x1), dark pilasters either side, a fascia board in the shop's colour carrying its name (sh.sign), and a striped
-- fabric awning (sh.stripes) sloping out over the pavement with a valance.
local function shopfront(c, sh)
	local x0, x1 = sh.x0, sh.x1
	local col = sh.color or C(40, 110, 76)
	local dark = col:Lerp(P.black, 0.35)
	local dx = sh.door or (x1 - 3)
	sbox(c, 'ShopPilaster', V(x0 - 0.8, 0.6, -0.2), V(x0, 10, 0.9), dark)
	sbox(c, 'ShopPilaster', V(x1, 0.6, -0.2), V(x1 + 0.8, 10, 0.9), dark)
	sbox(c, 'StallRiser', V(x0, 0.6, -0.2), V(x1, 2.4, 0.7), P.st.trim)
	sbox(c, 'StallSill', V(x0 - 0.2, 2.4, -0.2), V(x1 + 0.2, 2.8, 1.0), P.st.sill, true)
	-- the glass, the door's opening left out
	local spans = { { x0, dx - 2.2 }, { dx + 2.2, x1 } }
	for _, sp in spans do
		if sp[2] - sp[1] > 1 then
			sbox(c, 'ShopGlass', V(sp[1], 2.8, -0.2), V(sp[2], 9.2, 0.1), P.st.glassA, true)
			sbox(c, 'ShopGlass', V((sp[1] + sp[2]) / 2, 2.8, -0.2), V(sp[2], 9.2, 0.12), P.st.glassB, true)
			local n = math.max(1, math.floor((sp[2] - sp[1]) / 4.5 + 0.5))
			for k = 1, n - 1 do
				local mx = sp[1] + (sp[2] - sp[1]) * k / n
				sbox(c, 'ShopMullion', V(mx - 0.3, 2.8, -0.2), V(mx + 0.3, 9.2, 0.5), dark, true)
			end
			sbox(c, 'ShopTransom', V(sp[1], 9.2, -0.2), V(sp[2], 10, 0.6), dark, true)
		end
	end
	-- the door: frame, glass, push bar, a step
	sbox(c, 'ShopDoorFrame', V(dx - 2.2, 0.6, -0.2), V(dx + 2.2, 10, 0.6), dark)
	sbox(c, 'ShopDoor', V(dx - 1.6, 0.6, -0.2), V(dx + 1.6, 8.6, 0.75), P.st.glassB, true)
	sbox(c, 'ShopDoorBar', V(dx - 1.2, 4.2, 0.75), V(dx + 1.2, 4.6, 1.05), C(214, 216, 222), true)
	sbox(c, 'ShopStep', V(dx - 2.4, -0.5, 0), V(dx + 2.4, 0.9, 1.6), P.st.sill)
	-- fascia board with the shop's name
	local board = sbox(c, 'Fascia', V(x0 - 0.8, 10, -0.2), V(x1 + 0.8, 12.8, 1.1), col)
	sbox(c, 'FasciaCap', V(x0 - 1.0, 12.8, -0.2), V(x1 + 1.0, 13.3, 1.4), dark, true)
	if sh.sign then
		local g = surface(board, Enum.NormalId.Back, 20)
		line(g, 'Name', sh.sign, sh.text or P.white, FONT.loud, 0.12, 0.76, col:Lerp(P.black, 0.6), 3)
	end
	-- the awning: stripes sloping from under the fascia out to a valance (a wedge rises toward its local +Z)
	local stripes = sh.stripes or { col, P.white }
	local n = math.max(2, math.floor((x1 - x0) / 1.8))
	local depth = sh.awning or 3.4
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		local sc = stripes[k % #stripes + 1]
		decor(c:wedge('Awning', V(b - a, 1.8, depth), CFrame.new((a + b) / 2, 9.1, depth / 2 + 0.1) * CFrame.Angles(0, math.pi, 0), sc, M.SmoothPlastic))
		decor(c:box('AwningValance', V(a, 7.6, depth), V(b, 8.2, depth + 0.2), sc, M.SmoothPlastic))
	end
end

-- Fire escape on a facade frame at x (w wide): a dark iron landing under the windows of every upper floor, railings
-- with posts, a stair between each landing and the next, and a drop ladder under the lowest.
local function fireEscape(c, x, w, floors)
	local iron, rail = C(46, 50, 60), C(62, 66, 78)
	local x0, x1 = x - w / 2, x + w / 2
	local prev
	for f = 2, floors do
		local y = P.street.sills[2] + (f - 2) * 15 - 1.4
		sbox(c, 'EscapeLanding', V(x0, y - 0.4, 0), V(x1, y, 2.8), iron, true)
		decor(c:box('EscapeRail', V(x0, y + 3.2, 2.5), V(x1, y + 3.5, 2.8), rail, M.Plastic))
		for _, ex in { x0, x1 - 0.3 } do decor(c:box('EscapeRail', V(ex, y + 3.2, 0), V(ex + 0.3, y + 3.5, 2.8), rail, M.Plastic)) end
		for bx = x0, x1 + 0.01, w / math.max(2, math.floor(w / 2)) do
			decor(c:box('EscapePost', V(math.min(bx, x1 - 0.25), y, 2.5), V(math.min(bx, x1 - 0.25) + 0.25, y + 3.2, 2.75), rail, M.Plastic))
		end
		if prev then
			-- the stair from the landing below, rising along the facade
			decor(c:bar('EscapeStair', V(x0 + 1.5, prev + 0.2, 1.4), V(x1 - 2.5, y - 0.2, 1.4), 1.6, iron, M.Plastic))
			decor(c:bar('EscapeStringer', V(x0 + 1.5, prev + 1.4, 2.3), V(x1 - 2.5, y + 1.0, 2.3), 0.25, rail, M.Plastic))
		else
			-- the drop ladder, hooked up under the lowest landing
			for _, lx in { x1 - 2.2, x1 - 0.8 } do decor(c:box('EscapeLadder', V(lx - 0.12, y - 6, 2.3), V(lx + 0.12, y - 0.4, 2.5), rail, M.Plastic)) end
			for ly = y - 5.5, y - 1, 1.1 do decor(c:box('EscapeRung', V(x1 - 2.2, ly, 2.3), V(x1 - 0.8, ly + 0.15, 2.5), rail, M.Plastic)) end
		end
		prev = y
	end
end

-- Balcony on a facade frame at x (w wide) with its floor at y: a stone slab with a darker edge, an iron railing (top
-- rail, posts) and a door-height window behind it is the wall's own window.
local function balcony(c, x, y, w)
	sbox(c, 'BalconySlab', V(x - w / 2, y - 0.6, -0.2), V(x + w / 2, y, 2.8), P.st.trim, true)
	sbox(c, 'BalconyEdge', V(x - w / 2 - 0.1, y - 0.9, 2.5), V(x + w / 2 + 0.1, y - 0.3, 3.0), P.st.trimDark, true)
	decor(c:box('BalconyRail', V(x - w / 2, y + 3, 2.5), V(x + w / 2, y + 3.35, 2.85), P.iron, M.Plastic))
	for _, ex in { x - w / 2, x + w / 2 - 0.3 } do decor(c:box('BalconyRail', V(ex, y + 3, 0), V(ex + 0.3, y + 3.35, 2.85), P.iron, M.Plastic)) end
	for bx = x - w / 2 + 0.6, x + w / 2 - 0.5, 1.0 do decor(c:box('BalconyBar', V(bx - 0.1, y, 2.55), V(bx + 0.1, y + 3, 2.75), P.iron, M.Plastic)) end
end

-- Red brick house of the reference street, built as a family with real variety: w along the facade, o.depth deep,
-- eave at o.h, in three brick tones (the wall, a darker plinth and thin darker courses every 2.5 studs wrapped round
-- the block), a slate band between the storeys and a stone cornice. Options:
--   o.roof = 'hip' (default) | 'gable' (ridge along the street) | 'gableFront' (gable facing it) | 'flat' (parapet)
--   o.pilasters = n: brick piers with stone caps cut the front into n bays, one window per bay and floor
--   o.bays / o.winW: evenly spaced front windows without piers; o.windows = { { face, x, w } } instead
--   o.entrance = { x =, kind = 'stoop' | 'porch' | 'door', door = Color3, number =, span = { x0, x1 } }: the ground-floor
--     window in its bay is left out
--   o.chimney = { x, z } on the roof; o.gutters (faces with an eave gutter and downpipes, default front, none on a
--   flat roof); o.ac = { { face, x, y } } air-con boxes; o.tags = { { face, x, y, text, color } } spray-painted tags.
local function brickBuilding(ctx, w, o)
	o = o or {}
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local d, ST = o.depth or DEPTH, P.street
	-- storeys: 15 studs each (the picture's two); o.floors 3-4 for the taller districts
	local floors = o.floors or 2
	local H = o.h or (floors == 2 and ST.eave or floors * 15)
	local sills, bands = {}, {}
	for f = 1, floors do
		table.insert(sills, f == 1 and ST.sills[1] or ST.sills[2] + (f - 2) * 15)
		if f >= 2 then table.insert(bands, ST.band + (f - 2) * 15) end
	end
	local wall = o.wall or P.st.brick
	local dark = wall:Lerp(P.black, 0.18)
	local roof = o.roof or 'hip'
	sbox(c, 'Wall', V(0, -1, -d), V(w, H, 0), wall)
	sbox(c, 'Plinth', V(-0.3, -1, -d - 0.3), V(w + 0.3, 2.4, 0.3), dark)
	for y = 4.9, H - 2, floors > 2 and 5 or 2.5 do -- (tall blocks: every other course, read from further away)
		local nearBand = false
		for _, b in bands do if math.abs(y - b) <= 1.6 then nearBand = true end end
		if not nearBand then decor(c:box('BrickCourse', V(-0.06, y, -d - 0.06), V(w + 0.06, y + 0.35, 0.06), dark:Lerp(wall, 0.35), M.Plastic)) end
	end
	for _, b in bands do sbox(c, 'Band', V(-0.5, b, -d - 0.5), V(w + 0.5, b + 1.2, 0.5), P.st.band, true) end
	sbox(c, 'Cornice', V(-0.6, H - 1.2, -d - 0.6), V(w + 0.6, H, 0.6), P.st.trim, true)
	local top = H + 1
	if roof == 'flat' then flatRoof(c, w, d, H, wall); top = H + 2.8
	elseif roof == 'gable' or roof == 'gableFront' then
		local rise = o.rise or (roof == 'gable' and d * 0.32 or w * 0.36)
		gableRoof(c, w, d, H, rise, roof == 'gable' and 'x' or 'z', wall)
		top = H + 1 + rise
	else hipRoof(c, 0, -d, w, 0, H, o.rise, o.run); top = H + 1 + (o.rise or 5) end
	if o.chimney then chimney(c, o.chimney[1], o.chimney[2], H, top + 3, wall) end
	-- Bays: piers at the bay lines (corner piers included), one window per bay and floor.
	local list = o.windows
	if not list then
		list = {}
		local n = o.pilasters or o.bays or math.max(1, math.floor(w / 22 + 0.5))
		local bw = w / n
		for k = 1, n do table.insert(list, { face = 'front', x = bw * (k - 0.5), w = o.winW or (o.pilasters and bw - 4.6 or math.min(16, bw - 6)) }) end
		if o.pilasters then
			for k = 0, n do
				local px = math.clamp(bw * k, 0.8, w - 0.8)
				sbox(c, 'Pilaster', V(px - 0.8, 2.4, 0), V(px + 0.8, H - 1.2, 0.6), wall:Lerp(P.black, 0.06))
				sbox(c, 'PilasterBase', V(px - 1.0, 0.6, 0), V(px + 1.0, 2.4, 0.9), dark, true)
				sbox(c, 'PilasterCap', V(px - 1.0, H - 2.2, 0), V(px + 1.0, H - 1.2, 0.9), P.st.trim, true)
			end
		end
	end
	local ent = o.entrance
	local function inShop(face, x, half)
		for _, sh in o.shops or {} do
			if (sh.face or 'front') == face and x + half > sh.x0 - 0.5 and x - half < sh.x1 + 0.5 then return true end
		end
		return false
	end
	for _, win in list do
		local f = faceFrame(c, win.face, w, d)
		for fl, y in sills do
			local skip = fl == 1 and ((ent and win.face == 'front' and math.abs(win.x - ent.x) < win.w / 2 + 3.5) or inShop(win.face, win.x, win.w / 2) or o.noGround)
			if not skip then window(f, win.x, y, { w = win.w, h = o.winH }) end
		end
	end
	if ent then entrance(c, ent.x, ent) end
	for _, sh in o.shops or {} do shopfront(faceFrame(c, sh.face or 'front', w, d), sh) end
	for _, fe in o.fireEscapes or {} do fireEscape(faceFrame(c, fe.face or 'front', w, d), fe.x, fe.w or 10, floors) end
	for _, b in o.balconies or {} do
		local f = faceFrame(c, b.face or 'front', w, d)
		for fl = 2, floors do balcony(f, b.x, sills[fl] - 0.8, b.w or 10) end
	end
	-- Gutters along the eave and a downpipe at each end of the face, with a kick-out shoe at the foot.
	for _, face in o.gutters or (roof == 'flat' and {} or { 'front' }) do
		local f, fw = faceFrame(c, face, w, d)
		sbox(f, 'Gutter', V(-1, H - 0.2, 1.0), V(fw + 1, H + 0.5, 1.8), P.st.gutter, true)
		for _, xp in { 1.4, fw - 1.4 } do
			sbox(f, 'Downpipe', V(xp - 0.25, 1.2, 0.6), V(xp + 0.25, H - 0.2, 1.1), P.st.gutter, true)
			sbox(f, 'DownpipeShoe', V(xp - 0.3, 0.4, 0.6), V(xp + 0.3, 1.2, 1.7), P.st.gutter, true)
		end
	end
	for _, a in o.ac or {} do
		local f = faceFrame(c, a[1], w, d)
		sbox(f, 'AirCon', V(a[2] - 1.6, a[3], 0), V(a[2] + 1.6, a[3] + 2.2, 1.8), C(206, 210, 216), true)
		decor(f:box('AirConGrille', V(a[2] - 1.3, a[3] + 0.3, 1.8), V(a[2] + 1.3, a[3] + 1.9, 1.9), C(120, 126, 136), M.Plastic))
		sbox(f, 'AirConBracket', V(a[2] - 1.2, a[3] - 0.4, 0), V(a[2] + 1.2, a[3], 1.4), P.st.gutter, true)
	end
	for _, t in o.tags or {} do
		local f = faceFrame(c, t[1], w, d)
		local plate = ghost(f:box('Tag', V(t[2] - 4, t[3], 0.02), V(t[2] + 4, t[3] + 3, 0.08), P.white, M.SmoothPlastic))
		local g = surface(plate, Enum.NormalId.Back, 24) -- (the plate's back faces out of the wall)
		line(g, 'Tag', t[4], t[5], FONT.tag, 0.02, 0.96, P.black, 3).Rotation = -6
	end
	model:SetAttribute('Floors', floors)
	return c, model
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
---------------------------------------------------------------------------------------------- lobby
-- World 1's spawn: the warehouse hall, after the user's two hall pictures (brief/ref1_hall_a.png, ref1_hall_b.png: the
-- shell, the floor, the light). Built to BRIEF13/15's bar: every big surface in 2-3 tones, finished edges, base + body +
-- cap on every object.
-- B30 LOBBY (brief 30, the user: "bring back the map how it was, and work of it like that"): LOBBY4's hall (lobby C, Oct 9,
-- b1ce567 "Lobby zoned like the reference") is back as the base: HALL2's pale lavender studded walkway, the darker tiled
-- panels with the inset cyan line, the teal walls between layered periwinkle pillars, the navy-girdered roof with its
-- light bars, the plaza's kerbed deck with a red runner, every activity its own island with walkway round it. Kept from
-- the later briefs: today's compact 3-tier ARMORY (d3_armory), the ranges' black locked bays and 3-line labels (P1,
-- d2_stations), the Robux lanes (PRO BAY, GOLD BAY) with their promo glow, the character-height shoe boxes under big
-- floating "Boxes" / "Exclusive" words, the leaderboards' small rows, the winners' podium, the WORLD 2 arch, the World
-- Boss countdown board (f4_finale builds it at Lobby.Slots.WorldBossBoard), and the pass boards, now the references'
-- product stands (Lobby.productStand: a studded pedestal, the item turning over it, the name and an "ONLY <price>" over
-- that), spread along the walks people take.
-- The plan, on one grid (map frame, studs; north = -Z), interior x -73..73, z 6..122 (146 x 116): see Lobby.Plan below.
-- Builders from other files (Stations, Armory) fill the slots; a missing or failing one leaves a labelled placeholder
-- box of the slot's size. Lobby.Slots: name -> CFrame in the map frame, filled by Lobby.build.
local Lobby = {}

Lobby.W = SPAWN_W - 1 -- interior half width, 73 (walls x +-73..+-74; c_layout's SPAWN_W is the outside face)
Lobby.N, Lobby.S = 6, SPAWN_TOP - 1 -- interior north and south faces (z 6, 122)
Lobby.SouthWalk = 10.5 -- the walk across the hall between the band's end and the dais's front step
Lobby.H = 52 -- ceiling
Lobby.Deck = SPAWN.Y -- the floor (0): the spawn stands on it
Lobby.CrossZ = SPAWN.Z -- where the cross arm meets the spine (55)
Lobby.Walk = 9 -- the cross arm's half width (18 wide: the aisle's width)
Lobby.Spine = 9 -- the spine's half width (18 wide, HALL2's)
Lobby.Gap = 19 -- the activities start this far either side of the spine's centre line (a 10-wide floor panel between)
Lobby.Band = 30.7 -- the activity band's half length along z (the plaza's and the armory's): z CrossZ +-30.7
Lobby.Door, Lobby.DoorH = 21.5, 30 -- the doorway's half width and height (gate 1's pillars outside are at x +-18..22)
Lobby.ExitEdge = 46.4 -- the exit bay frame's outer edge (x +-), see Lobby.exitBay
Lobby.Slots = {}
Lobby.SlotSizes = {}
-- Colours sampled from the reference frames (lit faces), set so our renders land on them (LOBBY4's, lobby C's: the user's
-- pick; B30 put them back over LIGHT3's lighter aqua walls and skylit roof).
Lobby.Colors = {
	walk = C(186, 188, 224), panel = C(149, 153, 191), band = C(88, 98, 146), cyan = C(84, 226, 250),
	wall = C(126, 183, 193), wallDark = C(104, 158, 174), pillar = C(150, 152, 196), channel = C(22, 30, 64),
	neon = C(240, 246, 255), frame = C(146, 154, 188), winFrame = C(18, 34, 72), winGlass = C(214, 244, 255),
	-- (LOBBY3: the ceiling a light steel blue, not navy: it was the darkest band in every high frame)
	truss = C(84, 104, 134), barHousing = C(74, 82, 108), ceiling = C(112, 148, 184), lamp = C(255, 252, 236),
	standTread = C(184, 188, 224), standRiser = C(128, 132, 170), standNose = C(214, 218, 240),
	checkDark = C(44, 48, 62), checkLight = C(214, 218, 232), dais = C(176, 182, 218), shelfDark = C(84, 90, 124),
	shelfLight = C(150, 156, 192), eggPad = C(38, 58, 124), sign = C(222, 226, 238), signFrame = C(150, 156, 186),
	hazard = C(250, 196, 32), gold = C(255, 204, 48), green = C(30, 140, 60), vent = C(152, 176, 210),
	-- the shades (BRIEF13): every big surface gets a lit tone, a shade tone and a darker or paler trim
	-- (LOBBY4: LIGHT2's periwinkle pillars, in the floor's lavender family; the grey-violet showed muddy in Studio)
	panelLight = C(161, 165, 203), pillarSide = C(116, 120, 170), pillarBase = C(98, 104, 150), trim = C(200, 204, 228),
	wallBand = C(150, 202, 210), wallBase = C(86, 130, 152), ceilingPanel = C(150, 186, 216), trussDark = C(72, 88, 118),
	glassTop = C(176, 226, 250), lampBack = C(48, 56, 80), sill = C(184, 190, 220),
	strip = C(206, 220, 246), -- (B30: the pillars' channel strip, calm)
}
---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top (and on the sides when sides is true).
function Lobby.slab(c, name, a, b, color, sides)
	return studs(c:box(name, a, b, color, M.Plastic), sides)
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
function Lobby.motion(model, pivot, spin, bob, period)
	model.WorldPivot = V2.Origin * pivot
	if spin then model:SetAttribute('Spin', spin) end
	if bob then model:SetAttribute('Bob', bob) end
	if period then model:SetAttribute('BobPeriod', period) end
	model:AddTag('HoodMotion')
	return model
end
-- A flat board whose front faces cf's LookVector, with text lines { name, text, color, font, y, h, stroke, thickness }.
function Lobby.board(c, name, cf, w, h, color, rows, ppS, mat)
	local b = c:part(name, V(w, h, 0.3), cf, color, mat or M.SmoothPlastic)
	local g = surface(b, Enum.NormalId.Front, ppS or 16)
	for _, r in rows or {} do line(g, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] or 3) end
	return b, g
end
-- Shaded stripes painted on one face of a part: every `pitch` studs a stripe `width` wide, vertical or horizontal,
-- in color at transparency alpha. len and ht are the face's width and height in studs.
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
-- A ComingSoon prompt (the HUD toasts "<object> is coming soon!").
function Lobby.prompt(part, action, object, dist)
	local p = Instance.new('ProximityPrompt')
	p.Name = 'ComingSoon'
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = dist or 12
	p.RequiresLineOfSight = false
	p:SetAttribute('ComingSoon', true)
	p.Parent = part
	return p
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
-- A floating title in the reference's style (big cyan words with a dark outline, a white line under it).
function Lobby.title(c, pos, w, h, text, sub, color, maxDist)
	local a = billboard(c, pos, w, h, {
		{ 'Title', text, color or C(70, 236, 230), FONT.title, 0, sub and 0.6 or 1 },
		sub and { 'Sub', sub, P.white, FONT.title, 0.62, 0.36 } or nil,
	})
	a.WorldLabel.MaxDistance = maxDist or 200
	for _, t in a.WorldLabel:GetChildren() do
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then s.Color, s.Thickness = Lobby.Ink, 4 end
		-- (B30: the references' gradient fill, the colour's pale top to itself)
		if t:IsA('TextLabel') and not t:GetAttribute('ShadowOf') then Lobby.fill(t, t.TextColor3) end
	end
	return a
end
---------------------------------------------------------------------------------------------- shell
-- A wall pillar standing at pos on the wall's inner face, its front along normal: light grey studded, deep below
-- and slimmer above with a slanted kink between, a navy channel down the middle of its front with a white neon
-- strip in it that follows the kink. y0: where it starts (the armory's back block under an east pillar).
-- (Scaled with the hall: 10 wide, 3.5 deep below the kink at 16..21, 2 above.)
Lobby.PillarW, Lobby.PillarKink, Lobby.PillarD = 10, { 16, 21 }, { 3.5, 2 }
function Lobby.wallPillar(c, pos, normal, y0, w)
	local K, H = Lobby.Colors, Lobby.H
	w = w or Lobby.PillarW
	local k0, k1 = table.unpack(Lobby.PillarKink)
	local d0, d1 = table.unpack(Lobby.PillarD)
	local f = CFrame.lookAt(pos, pos + normal) -- local -Z points into the hall
	local yb = math.min(y0 or 0, Lobby.PillarKink[1] - 4) -- (a deck higher than that just buries the plinth)
	local function B(name, x0, ya, z0, x1, yt, z1, color, mat)
		return c:part(name, V(x1 - x0, yt - ya, z1 - z0), f * CFrame.new((x0 + x1) / 2, (ya + yt) / 2, (z0 + z1) / 2), color, mat or M.SmoothPlastic)
	end
	-- a part lying on the kink's slope (from the lower front plane at k0 to the upper one at k1), lifted off it
	local function slope(name, width, thick, lift, color, mat)
		local a, b = V(0, k0, -d0), V(0, k1, -d1)
		local nrm = V(0, d0 - d1, -(k1 - k0)).Unit * lift
		return c:part(name, V(width, thick, (b - a).Magnitude + 0.3), f * CFrame.lookAt((a + b) / 2 + nrm, b + nrm), color, mat or M.SmoothPlastic)
	end
	-- the body in the shade tone: its sides, and a rim round the front, read a step darker than the face
	studs(B('Pillar', -w / 2, yb, -d0, w / 2, k0, 0, K.pillarSide), true)
	studs(B('Pillar', -w / 2, k0, -d1, w / 2, H, 0, K.pillarSide), true)
	-- the slant: a wedge whose slope runs from the lower part's front top edge up to the upper part's face
	studs(c:wedge('PillarKink', V(w, k1 - k0, d0 - d1), f * CFrame.new(0, (k0 + k1) / 2, -(d0 + d1) / 2), K.pillarSide, M.Plastic), true)
	-- the lit face: two plates standing 0.4 proud, in from each edge, following the kink, with the channel between
	-- them; the navy channel lies back on the body and its white neon strip sits inside it (recessed, not stuck on)
	local e, pt = math.min(0.8, w * 0.08), 0.4
	local fb, ft = yb + 3, Lobby.H - 3 -- above the plinth, under the capital
	local cw, nw = 2, 0.9
	local pw = (w - 2 * e - cw) / 2 -- each face plate's width
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (cw / 2), sx * (cw / 2 + pw)
		local x0, x1 = math.min(xa, xb), math.max(xa, xb)
		studs(B('PillarFace', x0, fb, -d0 - pt, x1, k0, -d0, K.pillar), true)
		local sp = slope('PillarFace', pw, pt, pt / 2, K.pillar, M.Plastic)
		sp.CFrame = sp.CFrame * CFrame.new(sx * (cw / 2 + pw / 2), 0, 0)
		studs(sp, true)
		studs(B('PillarFace', x0, k1, -d1 - pt, x1, ft, -d1, K.pillar), true)
	end
	-- (B30, bible 4.8 / the user's "calm environment, loud interactables": no strip in the channel any more (lobby C's was
	-- white neon and bloomed on every pillar), and the channel is a shade of the pillar, not navy)
	local _ = nw
	for _, s in { { 'PillarChannel', cw, 0.08, K.pillar:Lerp(K.pillarSide, 0.7), M.SmoothPlastic } } do
		decor(B(s[1], -s[2] / 2, fb, -d0 - s[3], s[2] / 2, k0, -d0, s[4], s[5])).CastShadow = false
		decor(B(s[1], -s[2] / 2, k1, -d1 - s[3], s[2] / 2, ft, -d1, s[4], s[5])).CastShadow = false
		decor(slope(s[1], s[2], s[3], s[3] / 2, s[4], s[5])).CastShadow = false
	end
	-- the plinth (darker, a pale lip on top) and the capital where it meets the ceiling
	studs(B('PillarBase', -w / 2 - 0.5, yb, -d0 - 0.9, w / 2 + 0.5, fb - 0.4, 0, K.pillarBase), true)
	B('PillarBaseLip', -w / 2 - 0.7, fb - 0.4, -d0 - 1.1, w / 2 + 0.7, fb, 0, K.trim)
	studs(B('PillarCap', -w / 2 - 0.5, ft + 0.4, -d1 - 0.9, w / 2 + 0.5, Lobby.H, 0, K.pillarBase), true)
	B('PillarCapLip', -w / 2 - 0.7, ft, -d1 - 1.1, w / 2 + 0.7, ft + 0.4, 0, K.trim)
end
-- A big window: a thick navy frame, pale blue glass with two white glints, a navy transom near the top. cf sits on
-- the wall face at the window's centre, -Z into the hall.
-- The window is recessed: a THICK navy frame of four bars standing 1.2 proud of the wall, the glass set back on the
-- wall plane inside it (pale below a navy transom, a deeper blue top pane above it, two soft glint strokes), a pale
-- studded sill under it and a darker head over it.
function Lobby.window(c, cf, w, h)
	local K = Lobby.Colors
	local fw, fd = 1.5, 1.2
	local gw, gh = w - 2 * fw, h - 2 * fw
	for _, b in { { 0, h / 2 - fw / 2, w, fw }, { 0, -h / 2 + fw / 2, w, fw }, { -w / 2 + fw / 2, 0, fw, gh }, { w / 2 - fw / 2, 0, fw, gh } } do
		c:part('WindowFrame', V(b[3], b[4], fd), cf * CFrame.new(b[1], b[2], -fd / 2), K.winFrame, M.SmoothPlastic)
	end
	-- (B30: real glass over a hole in the wall, so the outside shows through)
	local glass = c:part('WindowGlass', V(gw, gh, 0.2), cf * CFrame.new(0, 0, -0.12), K.winGlass, M.Glass)
	glass.Transparency, glass.CastShadow = 0.6, false
	local top = c:part('WindowGlassTop', V(gw, gh * 0.3, 0.06), cf * CFrame.new(0, gh / 2 - gh * 0.15, -0.25), K.glassTop, M.Glass)
	top.Transparency, top.CastShadow = 0.7, false
	c:part('WindowTransom', V(gw, 1.0, 0.7), cf * CFrame.new(0, gh / 2 - gh * 0.3, -0.35), K.winFrame, M.SmoothPlastic)
	for _, g in { { -w * 0.16, 2.4, 0.5 }, { w * 0.1, 1.1, 0.4 } } do
		local s = decor(c:part('WindowGlint', V(g[2], h * g[3], 0.05), cf * CFrame.new(g[1], -h * 0.14, -0.28) * CFrame.Angles(0, 0, math.rad(-38)), P.white, M.SmoothPlastic))
		s.CastShadow, s.Transparency = false, 0.6
	end
	-- finished edges: a pale studded sill under it and a darker head over it
	studs(c:part('WindowSill', V(w + 1.6, 0.9, 1.9), cf * CFrame.new(0, -h / 2 - 0.4, -0.95), K.sill, M.Plastic))
	c:part('WindowHead', V(w + 1, 0.7, 1.5), cf * CFrame.new(0, h / 2 + 0.35, -0.75), K.winFrame:Lerp(P.black, 0.25), M.SmoothPlastic)
end
-- A small wall lamp: a dark back plate and a glowing lens tipped down a little.
-- (B30: an unlit fixture in the daylight hall: a pale lens, no glow)
function Lobby.wallLamp(c, cf)
	decor(c:part('WallLampBack', V(3.8, 1.6, 0.4), cf * CFrame.new(0, 0, -0.2), Lobby.Colors.lampBack, M.SmoothPlastic)).CastShadow = false
	decor(c:part('WallLamp', V(3, 0.9, 0.45), cf * CFrame.new(0, 0.05, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), C(232, 236, 246), M.SmoothPlastic)).CastShadow = false
end
-- The hall: floor slab, the four walls (the north one with the doorway), pillars, windows, lamps, the ceiling,
-- the trusses and the light bars. The bays run on one rhythm: side-wall pillars every 22 studs either side of the
-- cross arm (the middle one on each side wall is on the cross arm's axis: the RANGES sign hangs on the west one, the
-- ARMORY title floats over the east one; none straddles an end of the armory's back block), back-wall pillars at the
-- centre (the SHOE BOXES sign's) and just past the dais's ends, the north wall's corner bays either side of the exit
-- bay; a window and two lamps in every bay; the cross girders span from pillar to pillar, the long ones run
-- north-south between the light-bar columns.
Lobby.SidePillars = { 33, 55, 77, 99 } -- along the side walls (z): CrossZ +-22, +44, plus the corners
Lobby.BackPillars = { -36, 0, 36 } -- along the back wall (x): the dais's bays in the middle, the corner islands' outside
Lobby.BarRows = { 33, 55, 77, 99 } -- cross girders and light-bar rows (z), on the side pillars
Lobby.BarCols = { -37.5, -12.5, 12.5, 37.5 } -- long girders and light-bar centres (x)
Lobby.NoBars = {} -- (B30: the light-bar rows: none, the skylights light the hall)
Lobby.SkyGlass = C(206, 232, 252) -- the skylight glass over the hall (B30)
Lobby.WinY, Lobby.WinH = 31, 18 -- windows y 22..40
-- The windows' bays: { u (centre along the wall), w (the window's width) } on the west, east and south walls (B30: the
-- west wall's two bays beside the head lane's alcove carry the murals, no window).
function Lobby.windowBays()
	local N, S, W, A = Lobby.N, Lobby.S, Lobby.W, Lobby.Apse
	local out = { west = {}, east = {}, south = {} }
	local sides = { N, table.unpack(Lobby.SidePillars) }
	table.insert(sides, S)
	for i = 1, #sides - 1 do
		local a = sides[i] + (i == 1 and 6 or Lobby.PillarW / 2)
		local b = sides[i + 1] - (i == #sides - 1 and 6 or Lobby.PillarW / 2)
		local u, w = (a + b) / 2, math.min(11, b - a - 3)
		if b < A.z0 - 2 or a > A.z1 + 2 then table.insert(out.west, { u, w }) end
		table.insert(out.east, { u, w })
	end
	local backs = { -W, table.unpack(Lobby.BackPillars) }
	table.insert(backs, W)
	for i = 1, #backs - 1 do
		local a = backs[i] + (i == 1 and 6 or Lobby.PillarW / 2)
		local b = backs[i + 1] - (i == #backs - 1 and 6 or Lobby.PillarW / 2)
		table.insert(out.south, { (a + b) / 2, math.min(11, b - a - 3) })
	end
	return out
end
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	-- (B30, the user: "remove that green grass please, its a warehouse": the warehouse's concrete floor; the walkways lie
	-- on it, Lobby.floorPlan)
	Lobby.slab(h, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), Lobby.FieldColor)
	local function wall(a, b) return Lobby.slab(h, 'Wall', a, b, K.wall, true) end
	-- (B30, the user's "daylight inside" and "surroundings seen through the windows"): the side and back walls are cut
	-- round every window's glass (Lobby.windowBays), so the glass shows the cliffs and the hood outside; the west wall
	-- also opens on the head lane's alcove at the aisle's end (Lobby.apse). cut(): one wall from u0 to u1 along it, its
	-- holes { ua, ub, ya, yb }, built as bands between the holes' heights.
	local A = Lobby.Apse
	local bays = Lobby.windowBays()
	local gw, gh = function(w) return w - 3 end, Lobby.WinH - 3
	local function cut(box, u0, u1, holes)
		local ys = { 0, H }
		for _, hl in holes do table.insert(ys, hl[3]); table.insert(ys, hl[4]) end
		table.sort(ys)
		for i = 1, #ys - 1 do
			local ya, yb = ys[i], ys[i + 1]
			if yb - ya > 0.01 then
				local open = {}
				for _, hl in holes do if hl[3] <= ya + 0.01 and hl[4] >= yb - 0.01 then table.insert(open, hl) end end
				table.sort(open, function(a, b) return a[1] < b[1] end)
				local u = u0
				for _, hl in open do
					if hl[1] > u + 0.01 then box(u, hl[1], ya, yb) end
					u = math.max(u, hl[2])
				end
				if u1 > u + 0.01 then box(u, u1, ya, yb) end
			end
		end
	end
	local function holes(list, extra)
		local out = extra or {}
		for _, b in list do table.insert(out, { b[1] - gw(b[2]) / 2, b[1] + gw(b[2]) / 2, Lobby.WinY - gh / 2, Lobby.WinY + gh / 2 }) end
		return out
	end
	cut(function(a, b, ya, yb) wall(V(-W - 1, ya, a), V(-W, yb, b)) end, N - 1, S + 1, holes(bays.west, { { A.z0, A.z1, 0, A.h } }))
	cut(function(a, b, ya, yb) wall(V(W, ya, a), V(W + 1, yb, b)) end, N - 1, S + 1, holes(bays.east))
	cut(function(a, b, ya, yb) wall(V(a, ya, S), V(b, yb, S + 1)) end, -W - 1, W + 1, holes(bays.south))
	wall(V(-W - 1, 0, N - 1), V(-Dw, H, N))
	wall(V(Dw, 0, N - 1), V(W + 1, H, N))
	wall(V(-Dw, DH, N - 1), V(Dw, H, N))
	-- the walls' finish in three tones: a darker studded base band with a pale lip along the floor, the teal wall,
	-- and a lighter cap band under the ceiling over a pale cornice (the exit bay's panels keep the north band off the
	-- middle). strip() is a box on one wall's inner face, u along the wall.
	local function strip(name, side, u0, u1, y0, y1, depth, color, mat)
		local a, b
		if side == 'west' then a, b = V(-W, y0, u0), V(-W + depth, y1, u1)
		elseif side == 'east' then a, b = V(W - depth, y0, u0), V(W, y1, u1)
		elseif side == 'south' then a, b = V(u0, y0, S - depth), V(u1, y1, S)
		else a, b = V(u0, y0, N), V(u1, y1, N + depth) end
		return h:box(name, a, b, color, mat or M.SmoothPlastic)
	end
	local edge = Lobby.ExitEdge
	local runs = { { 'west', N, S }, { 'east', N, S }, { 'south', -W, W }, { 'north', -W, -edge }, { 'north', edge, W } }
	local baseRuns = { { 'west', N, A.z0 }, { 'west', A.z1, S }, { 'east', N, S }, { 'south', -W, W }, { 'north', -W, -edge }, { 'north', edge, W } }
	for _, r in baseRuns do
		studs(strip('WallBase', r[1], r[2], r[3], 0, 4, 0.35, K.wallBase), true)
		strip('WallBaseLip', r[1], r[2], r[3], 4, 4.5, 0.65, K.trim)
		strip('WallKick', r[1], r[2], r[3], 0, 0.8, 0.5, K.pillarBase)
	end
	local bandY = 45
	for _, r in runs do
		studs(strip('WallBand', r[1], r[2], r[3], bandY, H, 0.2, K.wallBand), true)
		strip('WallCornice', r[1], r[2], r[3], bandY - 1, bandY, 0.75, K.trim)
	end
	-- wall frames: cf on the inner face at (u along the wall, y), -Z into the hall
	local function west(u, y) return CFrame.lookAt(V(-W, y, u), V(-W + 1, y, u)) end
	local function east(u, y) return CFrame.lookAt(V(W, y, u), V(W - 1, y, u)) end
	local function south(u, y) return CFrame.lookAt(V(u, y, S), V(u, y, S - 1)) end
	local function north(u, y) return CFrame.lookAt(V(u, y, N), V(u, y, N + 1)) end
	-- pillars: the side walls, the back wall, the four corners (half pillars, one on each wall). (B30: today's compact
	-- armory stands free of the east wall, so every east pillar starts on the floor.)
	for _, z in Lobby.SidePillars do
		if z < A.z0 - 6 or z > A.z1 + 6 then Lobby.wallPillar(h, V(-W, 0, z), V(1, 0, 0)) end -- (none in the alcove's opening)
		Lobby.wallPillar(h, V(W, 0, z), V(-1, 0, 0))
	end
	for _, x in Lobby.BackPillars do Lobby.wallPillar(h, V(x, 0, S), V(0, 0, -1)) end
	for _, sx in { -1, 1 } do
		Lobby.wallPillar(h, V(sx * (W - 3), 0, S), V(0, 0, -1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, S - 3), V(-sx, 0, 0), nil, 6)
		Lobby.wallPillar(h, V(sx * (W - 3), 0, N), V(0, 0, 1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, N + 3), V(-sx, 0, 0), nil, 6)
	end
	-- a window in every bay between two pillars (centred in the bay), a lamp over it and one under it
	local wy, wh = Lobby.WinY, Lobby.WinH
	local function bay(f, u, w, low)
		Lobby.window(h, f(u, wy), w, wh)
		Lobby.wallLamp(h, f(u, wy + wh / 2 + 2))
		if low ~= false then Lobby.wallLamp(h, f(u, 14)) end
	end
	for _, b in bays.west do bay(west, b[1], b[2]) end
	for _, b in bays.east do bay(east, b[1], b[2]) end
	-- the back wall: a window in every bay (the dais's backdrop stands under the two middle ones)
	for _, b in bays.south do bay(south, b[1], b[2]) end
	-- the north wall's corner bays, between the exit bay's frame and the corner pillars: their notice boards hang where
	-- a window would be (Lobby.northBays), a lamp over each
	for _, sx in { -1, 1 } do
		Lobby.wallLamp(h, north(sx * (Lobby.ExitEdge + W - 6) / 2, wy + wh / 2 + 2))
	end
	Lobby.exitBay(h)
	-- Roof: the ceiling, girders along and across the hall, long light bars hung on wires under the cross girders.
	-- Everything up here is named Roof* (the plan view hides it).
	local r = L:group('Roof')
	-- (B30, the user: "daylight inside", the reference's bright outdoor plaza): the roof is a skylight: glass over the whole
	-- hall between the girders, only a ring of solid ceiling panels round the edge; no light bars (the sun lights the hall)
	local sky = r:box('RoofCeiling', V(-W - 1, H, N - 1), V(W + 1, H + 1, S + 1), Lobby.SkyGlass, M.Glass)
	sky.CastShadow, sky.Transparency = false, 0.55
	Lobby.apse(h, r)
	-- paler ceiling panels between the girders (the ceiling reads in two tones, the girders dark against it)
	local xs, zs = { -W }, { N }
	for _, x in Lobby.BarCols do table.insert(xs, x) end
	for _, z in Lobby.BarRows do table.insert(zs, z) end
	table.insert(xs, W)
	table.insert(zs, S)
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local x0, x1 = xs[i] + (i > 1 and 3 or 1), xs[i + 1] - (i < #xs - 1 and 3 or 1)
			local z0, z1 = zs[j] + (j > 1 and 3 or 1), zs[j + 1] - (j < #zs - 1 and 3 or 1)
			if i == 1 or i == #xs - 1 or j == 1 or j == #zs - 1 then
				r:box('RoofPanel', V(x0, H - 0.4, z0), V(x1, H, z1), K.ceilingPanel, M.SmoothPlastic).CastShadow = false
			else
				-- a skylight: a slim frame round the glass and two glazing bars across it
				for _, b in { { x0, x1, z0, z0 + 0.6 }, { x0, x1, z1 - 0.6, z1 }, { x0, x0 + 0.6, z0 + 0.6, z1 - 0.6 }, { x1 - 0.6, x1, z0 + 0.6, z1 - 0.6 } } do
					r:box('RoofSkylightFrame', V(b[1], H - 0.6, b[3]), V(b[2], H, b[4]), K.trussDark, M.SmoothPlastic).CastShadow = false
				end
				for _, t in { 1 / 3, 2 / 3 } do
					local zz = z0 + (z1 - z0) * t
					r:box('RoofSkylightBar', V(x0 + 0.6, H - 0.35, zz - 0.2), V(x1 - 0.6, H, zz + 0.2), K.trussDark, M.SmoothPlastic).CastShadow = false
				end
			end
		end
	end
	local ty = H - 10
	-- deep see-through lattice girders: two TrussParts (2 x 2 each) stacked, the long ones under the cross ones, dark
	-- against the paler ceiling panels; the long ones end on mounting plates on the end walls, the cross ones spring
	-- from the side pillars' capitals
	for _, x in Lobby.BarCols do
		for _, o in { { 0, 1 }, { 0, 3 } } do
			Lobby.truss(r, 'RoofTruss', V(x + o[1], ty + o[2], N), V(x + o[1], ty + o[2], S), K.trussDark)
		end
		for _, z in { N, S } do
			local s = z == N and 1 or -1
			r:box('RoofMount', V(x - 3.5, ty - 1.5, z), V(x + 3.5, ty + 5.5, z + s * 1.2), K.pillarBase, M.SmoothPlastic).CastShadow = false
		end
	end
	for _, z in Lobby.BarRows do
		for _, o in { { 0, 5 }, { 0, 7 } } do
			Lobby.truss(r, 'RoofTruss', V(-W, ty + o[2], z + o[1]), V(W, ty + o[2], z + o[1]), K.trussDark)
		end
	end
	-- (B30: no light bars any more: the skylights light the hall)
	for _, z in Lobby.NoBars do
		for _, x in Lobby.BarCols do
			local y = ty - 6
			studs(r:box('RoofLampBar', V(x - 10, y, z - 1.6), V(x + 10, y + 1, z + 1.6), K.barHousing, M.Plastic), true).CastShadow = false
			decor(r:box('RoofLampRim', V(x - 10.3, y - 0.3, z - 1.9), V(x + 10.3, y, z + 1.9), K.trim, M.SmoothPlastic)).CastShadow = false
			local tube = decor(r:box('RoofLampTube', V(x - 9.7, y - 0.45, z - 1.3), V(x + 9.7, y - 0.3, z + 1.3), K.neon, M.Neon))
			tube.CastShadow = false
			-- a soft cool glow round each bar that lights the ceiling, the girders and the upper walls but stops well
			-- above the floor (light17: Studio washed the floor out to white when the bars reached it)
			light(tube, C(232, 240, 255), 0.6, 26)
			for _, dx in { -8.5, 8.5 } do decor(r:box('RoofLampWire', V(x + dx - 0.08, y + 1, z - 0.08), V(x + dx + 0.08, ty + 4, z + 0.08), C(40, 44, 56), M.SmoothPlastic)).CastShadow = false end
		end
	end
	-- The shell lets the sun in, like the reference's bright, nearly shadowless interior: the walls, their bands, the
	-- pillars and the whole roof cast no shadows (so the roof doesn't make the hall an indoor, Ambient-only space and
	-- the walls don't throw shade over the plaza); window frames, sills, the exit bay and the objects in the hall still
	-- cast, so their depth reads.
	-- (light17 kept this on purpose: Roblox clamps OutdoorAmbient to >= Ambient, so a sun-blocking roof would leave the
	-- hall at best as bright as the streets' shade. HoodSun's calibrated sun lights it like the reference.)
	for _, grp in { h.parent, r.parent } do
		for _, p in grp:GetDescendants() do
			if p:IsA('BasePart') and (grp == r.parent or string.find(p.Name, '^Wall') or string.find(p.Name, '^Pillar')) then p.CastShadow = false end
		end
	end
	return h
end

---------------------------------------------------------------------------------------------- the head lane's alcove
-- (B30) The head lane's shrine at the aisle's far end (ref_W06.5_train_aisle_endcap_250x.jpg: the 250x on its gold stage
-- under a dome, closing the aisle; ref_W05.5_train_mouth_TRAIN_sign.jpg: the TRAIN sign over the far end): an alcove
-- through the west wall, A.z0..A.z1 wide, A.h high, out to A.back. Its walls and roof in the hall's own studded wall and
-- ceiling tones (named Wall* / Roof*, so they cast no shade, like the hall's shell); round the opening on the hall side a
-- crimson frame with gold caps (two studded pilasters and a header beam: the shrine's gate); inside, a warm gold
-- sunburst on the back wall behind the dome and a warm light. The lane itself and its gold stage: Lobby.stand.
-- h: the hall's group (walls), r: the roof's.
function Lobby.apse(h, r)
	local K, W, A = Lobby.Colors, Lobby.W, Lobby.Apse
	local z0, z1, xb, ah = A.z0, A.z1, A.back, A.h
	local crimson, crimsonDark, gold, goldDeep = C(178, 22, 52), C(120, 12, 34), K.gold, K.gold:Lerp(P.black, 0.3)
	-- (its floor a little over the grass outside the hall, which runs under it at 0.4, and a threshold across the opening)
	Lobby.slab(h, 'ApseFloor', V(xb, -1, z0 - 1), V(-W - 1, 0.5, z1 + 1), Lobby.PathColor)
	Lobby.slab(h, 'ApseFloor', V(-W - 1, 0, z0), V(Lobby.Plaza.x0, 0.5, z1), Lobby.PathColor)
	-- the shell: two side walls, the back wall (studded all round, like the hall's), the roof
	Lobby.slab(h, 'WallApse', V(xb, 0, z0 - 1), V(-W - 1, ah + 1, z0), K.wall, true)
	Lobby.slab(h, 'WallApse', V(xb, 0, z1), V(-W - 1, ah + 1, z1 + 1), K.wall, true)
	Lobby.slab(h, 'WallApse', V(xb, 0, z0), V(xb + 1, ah + 1, z1), K.wall, true)
	r:box('RoofApse', V(xb, ah, z0), V(-W - 1, ah + 1, z1), K.ceiling, M.SmoothPlastic).CastShadow = false
	r:box('RoofApsePanel', V(xb + 1.5, ah - 0.4, z0 + 1.5), V(-W - 2, ah, z1 - 1.5), K.ceilingPanel, M.SmoothPlastic).CastShadow = false
	-- inside: the hall's darker studded base band with its pale lip, round the three walls
	for _, b in { { V(xb + 1, 0, z0), V(-W - 1, 4, z0 + 0.35) }, { V(xb + 1, 0, z1 - 0.35), V(-W - 1, 4, z1) }, { V(xb + 1, 0, z0 + 0.35), V(xb + 1.35, 4, z1 - 0.35) } } do
		studs(h:box('WallApseBase', b[1], b[2], K.wallBase, M.SmoothPlastic), true)
	end
	-- the sunburst on the back wall, behind the dome: a gold disc, a paler ring, rays (flat, 0.1-0.4 proud)
	local cy, cz = 13, (z0 + z1) / 2
	local face = xb + 1
	decor(h:part('ApseBurst', V(0.2, 12, 12), CFrame.new(face + 0.1, cy, cz), gold, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	decor(h:part('ApseBurst', V(0.3, 8.6, 8.6), CFrame.new(face + 0.15, cy, cz), C(255, 236, 150), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	for k = 0, 11 do
		local a = k * math.pi / 6
		decor(h:part('ApseRay', V(0.16, 0.9, 3.2), CFrame.new(face + 0.12, cy, cz) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, -7.4), k % 2 == 0 and gold or goldDeep, M.SmoothPlastic)).CastShadow = false
	end
	local lamp = ghost(h:box('ApseLamp', V(xb + 4, ah - 3, cz - 1), V(xb + 6, ah - 1, cz + 1), P.white))
	light(lamp, C(255, 226, 160), 1.2, 22)
	-- the frame round the opening, on the hall side: crimson studded pilasters with gold caps, a header beam with a gold
	-- band, a gold keystone block
	local fx0, fx1 = -W, -W + 1.6
	for _, zz in { { z0 - 2.2, z0 }, { z1, z1 + 2.2 } } do
		studs(h:box('ApseFrame', V(fx0, 0, zz[1]), V(fx1, ah, zz[2]), crimson, M.Plastic), true)
		h:box('ApseFrameFoot', V(fx0, 0, zz[1] - 0.25), V(fx1 + 0.3, 1.2, zz[2] + 0.25), crimsonDark, M.SmoothPlastic)
		h:box('ApseFrameCap', V(fx0, ah - 1.6, zz[1] - 0.2), V(fx1 + 0.25, ah - 1.0, zz[2] + 0.2), gold, M.SmoothPlastic)
	end
	studs(h:box('ApseFrameHeader', V(fx0, ah, z0 - 2.6), V(fx1 + 0.4, ah + 3.4, z1 + 2.6), crimson, M.Plastic), true)
	h:box('ApseFrameBand', V(fx1 + 0.4, ah + 1.1, z0 - 2.3), V(fx1 + 0.55, ah + 2.3, z1 + 2.3), gold, M.SmoothPlastic)
	h:box('ApseFrameKey', V(fx1 + 0.4, ah - 0.4, cz - 1.2), V(fx1 + 0.75, ah + 3.0, cz + 1.2), gold, M.SmoothPlastic)
end

---------------------------------------------------------------------------------------------- exit bay
-- The north wall's centre: a grey framed recess (x +-43, 36 high) round the open doorway (x +-21.5, 30 high) onto the
-- Stage 1 street, two framed panels over the recess, white neon lines under and between them. Nothing in the doorway:
-- from the spawn you look straight down the street at gate 1 and the locked gates beyond it (GATES2's sightline), and
-- no text floats over it (gate 1's own sign is the goal). Inside the recess, west of the door the FURTHEST kiosk and
-- pad (Lobby.spawn), east of it a drinks corner (Lobby.hoodProps). (LOBBY4: WORLD 2 moved to the SW corner island.)
function Lobby.exitBay(h)
	local K, N = Lobby.Colors, Lobby.N
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local e = h:group('ExitBay')
	local RX, RH, fw = 43, 36, 3.4
	-- the recess's back is the wall, a shade darker inside the frame
	for _, seg in { { -RX, -Dw - 2 }, { Dw + 2, RX } } do e:box('ExitRecess', V(seg[1], 0, N), V(seg[2], RH, N + 0.12), K.wallDark, M.SmoothPlastic) end
	e:box('ExitRecess', V(-Dw - 2, DH + 2, N), V(Dw + 2, RH, N + 0.12), K.wallDark, M.SmoothPlastic)
	-- the frame (grey, standing 1.6 proud) and its white neon outline
	for _, sx in { -1, 1 } do
		local a, b = sx * RX, sx * (RX + fw)
		studs(e:box('ExitFrame', V(math.min(a, b), 0, N), V(math.max(a, b), RH + fw, N + 1.6), K.frame, M.Plastic), true)
	end
	studs(e:box('ExitFrame', V(-RX - fw, RH, N), V(RX + fw, RH + fw, N + 1.6), K.frame, M.Plastic), true)
	-- the doorway's own frame
	for _, sx in { -1, 1 } do
		local a, b = sx * Dw, sx * (Dw + 2)
		e:box('DoorJamb', V(math.min(a, b), 0, N), V(math.max(a, b), DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	end
	e:box('DoorHead', V(-Dw - 2, DH, N), V(Dw + 2, DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	-- (no glass in the doorway any more: Studio's Glass greyed the street and halved the gates' contrast. GATES2.)
	-- two framed panels over the recess
	local py0, py1 = RH + fw + 1.2, Lobby.H - 2.5
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * 1.6, sx * RX
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		e:box('ExitPanel', V(lo, py0, N), V(hi, py1, N + 0.12), K.wallDark, M.SmoothPlastic)
		for _, ed in { { V(lo, py0, N), V(hi, py0 + 1.6, N + 1.2) }, { V(lo, py1 - 1.6, N), V(hi, py1, N + 1.2) }, { V(lo, py0, N), V(lo + 1.6, py1, N + 1.2) }, { V(hi - 1.6, py0, N), V(hi, py1, N + 1.2) } } do
			studs(e:box('ExitPanelFrame', ed[1], ed[2], K.frame, M.Plastic), true)
		end
	end
	-- (B30, bible 4.8: no glow on the shell: the lines round the exit bay are a pale trim, not white neon)
	local function neon(a, b) decor(e:box('ExitTrim', a, b, K.trim, M.SmoothPlastic)).CastShadow = false end
	neon(V(-RX - fw, RH + fw, N + 1.2), V(RX + fw, RH + fw + 0.7, N + 1.6)) -- under the panels
	neon(V(-0.4, RH + fw, N + 0.3), V(0.4, py1, N + 0.9)) -- between them
	for _, sx in { -1, 1 } do
		local a, b = sx * (RX + fw), sx * (RX + fw - 0.6)
		neon(V(math.min(a, b), 0.4, N + 1.6), V(math.max(a, b), RH + fw + 0.7, N + 1.9)) -- up the frame's outer edges
	end
	return e
end
-- WORLD 2, the reference's green coming-soon door, built up in layers: a dark studded step with a pale nosing; black
-- arch posts on grey plinths with red caps; the red-and-black block arch with a gold keystone; a green door (a darker
-- frame round two paler panels, the lettering on them, a round top) behind a big gold padlock; a green glow round it.
-- In front, "closed" props: two traffic cones and a striped sawhorse. Front -Z of cf's frame faces the hall (cf: the
-- centre bottom of the door at its back). A glowing backing plate closes the back (it stands free on its island).
function Lobby.world2(e, cf)
	local K = Lobby.Colors
	local p, model = e:at(cf):group('World2Portal')
	local dw, dh, ar, st = 5.6, 11.5, 8.0, 0.6 -- door half width, spring line, arch outer radius, step height (B31: a compact arch, ref's portal)
	local black, red, green = C(28, 30, 36), C(196, 24, 30), K.green
	-- the step
	-- (rule 29) the user's Portal_World2 when imported (its chained, padlocked violet arch), else our arch
	if not Lobby.designed(p, 'Portal_World2', 1, nil, true) then
		Lobby.slab(p, 'World2Step', V(-dw - 2.8, 0, -4.6), V(dw + 2.8, st, 0), C(62, 66, 88), true)
		p:box('World2StepNosing', V(-dw - 2.8, st - 0.12, -4.75), V(dw + 2.8, st + 0.04, -4.2), K.trim, M.SmoothPlastic)
		-- the posts: a grey plinth, the black post, a red cap at the spring line
		for _, sx in { -1, 1 } do
			local x0, x1 = sx > 0 and dw or -dw - 2.8, sx > 0 and dw + 2.8 or -dw
			Lobby.slab(p, 'ArchPlinth', V(x0 - 0.2, st, -2.6), V(x1 + 0.2, st + 2.2, 0), K.pillarBase, true)
			p:box('ArchPost', V(x0, st + 2.2, -2.2), V(x1, dh, 0), black, M.SmoothPlastic)
			p:box('ArchCap', V(x0 - 0.2, dh - 0.9, -2.5), V(x1 + 0.2, dh, 0), red, M.SmoothPlastic)
		end
		local n = 11
		for k = 0, n - 1 do
			local a = math.pi * (k + 0.5) / n
			local r0 = (dw + ar) / 2
			local cfk = CFrame.new(math.cos(a) * r0, dh + math.sin(a) * r0, -1.1) * CFrame.Angles(0, 0, a)
			p:part('ArchBlock', V(ar - dw, 2.9, 2.2), cfk, k % 2 == 0 and red or C(26, 26, 30), M.SmoothPlastic)
		end
		p:box('ArchKeystone', V(-1.5, dh + ar - 1.2, -2.6), V(1.5, dh + ar + 0.6, 0), K.gold, M.SmoothPlastic)
		-- the green glow behind, the door with its round top in front of it
		local glow = decor(p:box('World2Glow', V(-dw - 3, 0, -0.5), V(dw + 3, dh + ar - 1, -0.2), C(90, 255, 140), M.Neon))
		glow.Transparency, glow.CastShadow = 0.55, false
		light(glow, C(120, 255, 150), 2, 22)
		p:box('World2Door', V(-dw, st, -1.8), V(dw, dh, -0.8), green:Lerp(P.black, 0.18), M.SmoothPlastic)
		p:part('World2DoorTop', V(1, 2 * dw, 2 * dw), CFrame.new(0, dh, -1.3) * CFrame.Angles(0, math.pi / 2, 0), green:Lerp(P.black, 0.18), M.SmoothPlastic, Enum.PartType.Cylinder)
		local top = p:box('World2Panel', V(-dw + 1, dh * 0.52, -1.95), V(dw - 1, dh - 0.4, -1.8), green, M.SmoothPlastic)
		local low = p:box('World2Panel', V(-dw + 1, st + 1, -1.95), V(dw - 1, dh * 0.5 - 0.6, -1.8), green, M.SmoothPlastic)
		local g = surface(top, Enum.NormalId.Front, 14)
		line(g, 'Soon', 'BUSINESS DISTRICT', C(255, 214, 60), FONT.title, 0.08, 0.3, C(40, 30, 0), 2) -- (Oct 27: World 2 is built)
		line(g, 'World', 'WORLD 2', P.white, FONT.title, 0.44, 0.44, C(10, 50, 20), 3)
		line(surface(low, Enum.NormalId.Front, 14), 'Detail', 'Beat the Boss Yard\nto unlock!', C(220, 255, 220), FONT.title, 0.62, 0.32, C(10, 50, 20), 1)
		-- the padlock over the panels' join: a gold body with a keyhole, a darker shackle
		p:box('World2Lock', V(-1.5, dh * 0.5 - 1.6, -2.6), V(1.5, dh * 0.5 + 0.8, -1.9), K.gold, M.SmoothPlastic)
		p:box('World2Keyhole', V(-0.25, dh * 0.5 - 1.0, -2.65), V(0.25, dh * 0.5 + 0.1, -2.58), C(60, 40, 10), M.SmoothPlastic)
		local sh = K.gold:Lerp(P.black, 0.3)
		for _, sx in { -1, 1 } do p:box('World2Shackle', V(sx * 0.95 - 0.3, dh * 0.5 + 0.8, -2.4), V(sx * 0.95 + 0.3, dh * 0.5 + 2.4, -2.0), sh, M.SmoothPlastic) end
		p:box('World2Shackle', V(-1.25, dh * 0.5 + 2.4, -2.4), V(1.25, dh * 0.5 + 2.9, -2.0), sh, M.SmoothPlastic)
		-- closed: two cones and a striped sawhorse in front of the step
		for _, sx in { -1, 1 } do
			local cc = p:at(CFrame.new(sx * (dw + 2.6), 0, -6.2))
			cc:box('ConeBase', V(-0.9, 0, -0.9), V(0.9, 0.3, 0.9), C(40, 42, 50), M.SmoothPlastic)
			cc:post('Cone', 0.7, 1.4, V(0, 0.3, 0), C(255, 120, 30), M.SmoothPlastic)
			cc:post('ConeBand', 0.55, 0.4, V(0, 1.7, 0), P.white, M.SmoothPlastic)
			cc:post('ConeTip', 0.38, 0.6, V(0, 2.1, 0), C(255, 120, 30), M.SmoothPlastic)
		end
		for _, sx in { -1, 1 } do
			p:part('SawhorseLeg', V(0.3, 2.4, 1.4), CFrame.new(sx * 3.2, 1.1, -6.6) * CFrame.Angles(math.rad(14), 0, 0), C(60, 62, 70), M.SmoothPlastic)
		end
		local bar = p:box('SawhorseBar', V(-4, 1.7, -6.85), V(4, 2.5, -6.45), P.white, M.SmoothPlastic)
		Lobby.stripes(bar, Enum.NormalId.Front, 8, 0.8, 1.6, 0.8, true, 0, C(220, 40, 40))
		-- the back: a dark studded plate behind the posts and the arch (it stands free on its island, its back to the corner)
		Lobby.slab(p, 'World2Back', V(-dw - 2.8, 0, 0), V(dw + 2.8, dh + ar - 1.2, 0.7), C(46, 50, 66), true)
	end
	local zone = p:box('World2Gate', V(-dw, 0, -6), V(dw, 6, -2), P.white)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	Lobby.Slots.World2Portal = cf
	return model
end

---------------------------------------------------------------------------------------------- floor: the path network
-- B30 (the user: "make the floor in the lobby have pathways that make sense and dont just go whereever they want"; the
-- lead: "copy that palette"; bible 2.1, sketch_soldier_lobby_topdown.png). The hall's floor is calm concrete (the user: "its
-- a warehouse"; Lobby.hall); on it lies one PATH NETWORK, lavender studded walkways with the reference's darker edge band, only where
-- people walk, each path running from the spawn crossroads straight to something:
--   the crossroads  the spawn's square where the four walks meet (plain: no spawn symbol, the user's ask)
--   north           the spine to the Stage 1 door (the products stand along its east edge, the group chest and the CODES
--                   terminal along its west edge, ref_W28.0 / ref_W29.5)
--   west            straight on into the training plaza's aisle (12 wide, the aisle's own width) and down it to the head lane
--   east            to the ARMORY's front (the soldier game's gun stand at the end of its east arm)
--   south           to the box row, where a cross walk in front of the dais runs out to two short stubs: WORLD 2 (SW) and
--                   the leaderboards (SE), each ending at that thing
-- Lobby.Paths: { x0, x1, z0, z1, name } rectangles (map frame) that only touch, never overlap; the edge band runs along
-- every side that no other path continues from. No stubs, no diagonals, no outlines.
Lobby.PathColor, Lobby.PathEdge = C(186, 188, 224), C(112, 116, 158)
-- (B30, the user: "remove that green grass please, its a warehouse" / "and the green floor") off the walks the floor is the
-- warehouse's calm concrete, studded, about two shades under the walks so they still read at once; painted yellow
-- safety lines along the walks, expansion joints, a few drains, forklift scuffs by the stockroom; steel kerbs by the walls
Lobby.FieldColor = C(150, 152, 162) -- the concrete
Lobby.SafetyLine, Lobby.JointColor, Lobby.KerbColor, Lobby.KerbStripe = C(236, 196, 52), C(124, 126, 136), C(74, 78, 94), C(236, 196, 52)
Lobby.Aisle = 6 -- the west walk's and the training aisle's half width (12 wide); the other walks are 10 wide
function Lobby.paths()
	local Z, N, a = Lobby.CrossZ, Lobby.N, Lobby.Aisle
	local sz = Lobby.DaisAt.Position.Z -- the dais's front step
	return {
		{ -a, a, Z - a, Z + a, 'Crossroads' },
		{ -5, 5, N, Z - a, 'North' },
		{ -Lobby.PlazaGap, -a, Z - a, Z + a, 'West' },
		{ a, Lobby.ArmoryX, Z - 5, Z + 5, 'East' },
		{ -5, 5, Z + a, sz - 10, 'South' },
		{ -46, 46, sz - 10, sz, 'BoxWalk' }, -- (its ends at WORLD 2 and the leaderboards)
	}
end
-- One path rectangle: the lavender studded walk, and the darker band on each side's stretches that no other path
-- touches (the band 0.02 proud of the path's edge and a hair higher, so no two faces share a plane).
function Lobby.pathRect(f, r, all)
	local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
	local e, top = 0.9, 0.1
	Lobby.slab(f, 'Path', V(x0, 0, z0), V(x1, top, z1), Lobby.PathColor).CastShadow = false
	-- the side's open stretches: [u0, u1] minus where another path continues across it
	local function open(fixed, isX, u0, u1, outward)
		local cuts = {}
		for _, o in all do
			if o ~= r then
				local t0, t1, s0, s1
				if isX then t0, t1, s0, s1 = o[1], o[2], o[3], o[4] else t0, t1, s0, s1 = o[3], o[4], o[1], o[2] end
				-- o lies just across the side (touching it from the outside)
				local probe = fixed + outward * 0.3
				if probe > s0 and probe < s1 then table.insert(cuts, { math.max(u0, t0), math.min(u1, t1) }) end
			end
		end
		table.sort(cuts, function(p, q) return p[1] < q[1] end)
		local runs, u = {}, u0
		for _, c in cuts do
			if c[2] > c[1] then
				if c[1] > u then table.insert(runs, { u, c[1] }) end
				u = math.max(u, c[2])
			end
		end
		if u1 > u then table.insert(runs, { u, u1 }) end
		return runs
	end
	local function band(a, b) Lobby.slab(f, 'PathEdge', a, b, Lobby.PathEdge).CastShadow = false end
	-- (B30 warehouse) a painted yellow safety line on the concrete 0.45 outside each banded stretch; the lines along x run
	-- on past the corners so the two meet; none where the stretch runs into something solid (Lobby.noLines)
	local function line(isX, fixed, u0, u1)
		local blocks = {}
		for _, q in Lobby.noLines() do
			local cx0, cx1, cz0, cz1 = q[1], q[2], q[3], q[4]
			if isX and fixed > cz0 and fixed < cz1 then table.insert(blocks, { cx0, cx1 })
			elseif not isX and fixed > cx0 and fixed < cx1 then table.insert(blocks, { cz0, cz1 }) end
		end
		table.sort(blocks, function(p2, q2) return p2[1] < q2[1] end)
		local u = u0
		local function put(a, b)
			if b - a < 0.5 then return end
			local part
			if isX then part = f:box('SafetyLine', V(a, 0, fixed - 0.15), V(b, 0.04, fixed + 0.15), Lobby.SafetyLine, M.SmoothPlastic)
			else part = f:box('SafetyLine', V(fixed - 0.15, 0, a), V(fixed + 0.15, 0.04, b), Lobby.SafetyLine, M.SmoothPlastic) end
			decor(part).CastShadow = false
		end
		for _, b in blocks do
			if b[2] > u and b[1] < u1 then put(u, math.min(b[1], u1)); u = math.max(u, b[2]) end
		end
		if u1 > u then put(u, u1) end
	end
	local lo = 0.6 -- (the line's centre, outside the path's edge)
	for _, run in open(z0, true, x0, x1, -1) do
		band(V(run[1], 0, z0 - 0.02), V(run[2], top + 0.03, z0 + e))
		line(true, z0 - lo, run[1] - (run[1] <= x0 and lo + 0.15 or 0), run[2] + (run[2] >= x1 and lo + 0.15 or 0))
	end
	for _, run in open(z1, true, x0, x1, 1) do
		band(V(run[1], 0, z1 - e), V(run[2], top + 0.03, z1 + 0.02))
		line(true, z1 + lo, run[1] - (run[1] <= x0 and lo + 0.15 or 0), run[2] + (run[2] >= x1 and lo + 0.15 or 0))
	end
	-- (the sides along z stop short of the corners, where the x sides' bands already are)
	for _, run in open(x0, false, z0, z1, -1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then band(V(x0 - 0.02, 0, a2), V(x0 + e, top + 0.03, b2)) end
		line(false, x0 - lo, run[1] + (run[1] <= z0 and 0.15 - lo or 0), run[2] - (run[2] >= z1 and 0.15 - lo or 0))
	end
	for _, run in open(x1, false, z0, z1, 1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then band(V(x1 - e, 0, a2), V(x1 + 0.02, top + 0.03, b2)) end
		line(false, x1 + lo, run[1] + (run[1] <= z0 and 0.15 - lo or 0), run[2] - (run[2] >= z1 and 0.15 - lo or 0))
	end
end
-- Where no safety line is painted: outside the hall's walls (the door), under the dais, the armory, the plaza's deck.
function Lobby.noLines()
	local W, N, S = Lobby.W, Lobby.N, Lobby.S
	local ax0, ax1, az0, az1 = Lobby.armoryRect()
	local Pz = Lobby.Plaza
	local sz = Lobby.DaisAt.Position.Z
	return {
		{ -200, 200, -200, N + 0.2 }, { -200, 200, S - 0.2, 400 }, { -200, -W + 0.2, -200, 400 }, { W - 0.2, 200, -200, 400 },
		{ ax0 - 0.05, ax1, az0, az1 }, { Pz.x0, Pz.x1 + 0.05, Pz.z0, Pz.z1 }, { -22.6, 22.6, sz - 0.05, sz + 12 },
	}
end
-- A low steel kerb along a wall (a dark studded rail with a painted yellow top stripe), a to b its footprint corners.
function Lobby.kerb(f, a, b)
	studs(decor(f:box('Kerb', V(a.X, 0, a.Z), V(b.X, 0.8, b.Z), Lobby.KerbColor, M.Plastic)), true)
	decor(f:box('KerbStripe', V(a.X + 0.1, 0.8, a.Z + 0.25), V(b.X - 0.1, 0.86, b.Z - 0.25), Lobby.KerbStripe, M.SmoothPlastic)).CastShadow = false
end
-- A floor drain: a dark square grate in a steel frame, flush with the concrete (x, z: its centre).
function Lobby.drain(f, x, z)
	decor(f:box('DrainFrame', V(x - 0.8, 0, z - 0.8), V(x + 0.8, 0.05, z + 0.8), C(96, 100, 112), M.SmoothPlastic)).CastShadow = false
	decor(f:box('Drain', V(x - 0.6, 0, z - 0.6), V(x + 0.6, 0.07, z + 0.6), C(40, 42, 52), M.SmoothPlastic)).CastShadow = false
	for k = -1, 1 do decor(f:box('DrainSlat', V(x - 0.55, 0.07, z + k * 0.32 - 0.06), V(x + 0.55, 0.09, z + k * 0.32 + 0.06), C(110, 114, 126), M.SmoothPlastic)).CastShadow = false end
end
-- What the floor's details keep clear of: circles { x, z, r } (the stands, the chest, the codes, the podium, the exit bay's props) and
-- rectangles { x0, x1, z0, z1 } (the paths, the plaza, the armory island, the dais, the corners' set pieces, the walls).
function Lobby.keepOut()
	local list, rects = {}, {}
	for _, st in Lobby.Plan.Stands do table.insert(list, { st[2], st[3], (st[5] or Lobby.StandFoot) + 2 }) end
	for _, b in Lobby.Plan.BoxPads do table.insert(list, { b[3], b[4], 5.4 }) end
	local g = Lobby.Plan.Group
	table.insert(list, { g.chest[1], g.chest[2], 6.5 })
	table.insert(list, { g.codes[1], g.codes[2], 4.5 })
	table.insert(list, { Lobby.Plan.Podium[1], Lobby.Plan.Podium[2], 8.5 })
	table.insert(list, { -36, Lobby.N + 3.2, 3.5 })
	table.insert(list, { -29.5, Lobby.N + 3.4, 4 })
	table.insert(list, { Lobby.Plan.WorldBoss.x, Lobby.Plan.WorldBoss.z, 13 })
	for _, r in Lobby.paths() do table.insert(rects, { r[1] - 1, r[2] + 1, r[3] - 1, r[4] + 1 }) end
	local Pz = Lobby.Plaza
	table.insert(rects, { Pz.x0 - 1, Pz.x1 + 1, Pz.z0 - 1, Pz.z1 + 1 })
	local ax0, ax1, az0, az1 = Lobby.armoryRect()
	table.insert(rects, { ax0 - 1.5, Lobby.W, az0 - 2, az1 + 2 })
	local sz = Lobby.DaisAt.Position.Z
	table.insert(rects, { -25, 25, sz - 1, Lobby.S })
	table.insert(list, { Lobby.Plan.World2.x, Lobby.Plan.World2.z, 14 })
	table.insert(rects, { Lobby.Plan.Boards.x - 17, Lobby.Plan.Boards.x + 17, Lobby.Plan.Boards.z, Lobby.S })
	local W, N, S = Lobby.W, Lobby.N, Lobby.S
	table.insert(rects, { -W, -W + 5, N, S }); table.insert(rects, { W - 5, W, N, S })
	table.insert(rects, { -W, W, N, N + 4.5 }); table.insert(rects, { -W, W, S - 5, S })
	return list, rects
end
function Lobby.floorPlan(L)
	local f = L:group('FloorPlan')
	local all = Lobby.paths()
	Lobby.Path = {}
	for _, r in all do
		Lobby.pathRect(f, r, all)
		Lobby.Path[r[5]] = { r[1], r[2], r[3], r[4] }
	end
	local circles, rects = Lobby.keepOut()
	local function clear(x, z)
		for _, c2 in circles do if (V(x, 0, z) - V(c2[1], 0, c2[2])).Magnitude < c2[3] then return false end end
		for _, q in rects do if x > q[1] and x < q[2] and z > q[3] and z < q[4] then return false end end
		return true
	end
	-- the concrete's expansion joints, a 24-stud grid of thin darker lines (under the walks and the stands they just vanish)
	local W, N, S = Lobby.W, Lobby.N, Lobby.S
	for x = -W + 13, W - 1, 24 do
		decor(f:box('FloorJoint', V(x - 0.09, 0, N + 0.5), V(x + 0.09, 0.02, S - 0.5), Lobby.JointColor, M.SmoothPlastic)).CastShadow = false
	end
	for z = N + 12, S - 1, 24 do
		decor(f:box('FloorJoint', V(-W + 0.5, 0, z - 0.09), V(W - 0.5, 0.02, z + 0.09), Lobby.JointColor, M.SmoothPlastic)).CastShadow = false
	end
	-- a few floor drains on clear concrete
	for _, q in { { -30, 19.5 }, { 25.5, 44.5 }, { 42, 79 }, { -40, 89 } } do
		if clear(q[1], q[2]) then Lobby.drain(f, q[1], q[2]) end
	end
	-- forklift tyre scuffs by the stockroom behind the armory (two faint darker tracks)
	local _, ax1 = Lobby.armoryRect()
	for _, dx in { 3.0, 5.4 } do
		local s2 = decor(f:box('TyreScuff', V(ax1 + dx - 0.25, 0, Lobby.CrossZ - 13), V(ax1 + dx + 0.25, 0.025, Lobby.CrossZ - 2), C(108, 110, 120), M.SmoothPlastic))
		s2.CastShadow, s2.Transparency = false, 0.45
	end
	-- low steel kerbs along the north wall, either side of the exit bay (clear of the corner pillars)
	for _, sx in { -1, 1 } do
		local a, b = sx * (Lobby.ExitEdge + 1.5), sx * (Lobby.W - 7)
		Lobby.kerb(f, V(math.min(a, b), 0, Lobby.N + 1.4), V(math.max(a, b), 0, Lobby.N + 2.6))
	end
	-- the dark chevrons on the walks: north of the spawn pointing to the exit, south of it pointing to the boxes
	for _, c in { { Lobby.N + 18, -1 }, { Lobby.CrossZ + 21, 1 } } do
		local tz, d = c[1], c[2]
		for _, sx in { -1, 1 } do
			local tip, tail = V(0, 0.12, tz), V(sx * 3.4, 0.12, tz - d * 3.6)
			decor(f:part('WalkChevron', V(2.0, 0.06, (tip - tail).Magnitude + 1.4), CFrame.lookAt((tip + tail) / 2, tip), Lobby.PathEdge, M.SmoothPlastic)).CastShadow = false
		end
	end
	return f
end

---------------------------------------------------------------------------------------------- range stand
-- B30 (the user: "placed EXACTLY like the soldier game's training area", "follow one to one the layout of the references of
-- the shooting game"): the TRAINING plaza is the soldier game's (bible §2.2, frames sketch_soldier_training_plaza.png,
-- ref_W05-12_training_walk_4fps.jpg, ref_W07.5_train_row_north_50_35_20_1.jpg, ref_W13.5_train_row_south_25_4_10_100.jpg,
-- ref_W06.5_train_aisle_endcap_250x.jpg), built in lobby C's plaza (its kerbed deck, the lavender aisle and red runner,
-- the murals and the RANGES sign on the west wall):
--   Where   west of the spawn: the spawn's west arm runs straight on into the plaza as its AISLE (no turn, no gate).
--   Count   9 lanes: a north row of 4 and a south row of 4 facing the aisle, and the HEAD lane closing the aisle's far end.
--   Facing  every lane perpendicular to the aisle, its shooter end touching it, its target at the far end (the north row
--           shoots north, the south row south): nobody aims across the aisle.
--   Order   north row from the mouth: BAY 1 x1 (0 rebirths), BAY 4 x20 (6), BAY 5 x35 (8), BAY 6 x50 (10); south row from
--           the mouth: PRO BAY x100 R$99 (the cheap paid lane, the first thing on the left as you enter), BAY 2 x4 (2),
--           BAY 3 x10 (4), GOLD BAY x250 R$249 (the deep paid lane); the head: HEAD LANE x500 R$699 on a raised gold stage
--           with red steps from the aisle, under a glass dome. So every next free lane is deeper down the aisle (x1 N1, x4
--           S2, x10 S3, x20 N2, x35 N3, x50 N4) and the paid ones sit at the ends, as the reference.
--   Size    our lanes are 9 wide (d2_stations) on a 10.4 pitch: the reference's 2-stud gaps between them; no posts,
--           walls or benches between lanes. The aisle is C's cross arm (18 wide).
-- Lobby.Plaza = the deck's rectangle (map frame) and the aisle's z run. Lobby.Stand.Lanes[i] = { x, z, look } for
-- Lobby.Ranges[i]; Slots[i] = its frame (origin on the deck at the lane's centre, -Z = the front, toward the aisle).
Lobby.PlazaGap = 16 -- the plaza's mouth (x -16): 7 studs past the spine's edge, room for one stand between
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold', 'Head' }
-- (B30, the user: "make the shooting ranges, especially the golden one be a bit more infront, because right now it
-- overlays with the other shooting ranges"; sketch_soldier_training_plaza.png: the head lane closes the aisle BEYOND the
-- rows and touches none of them.) A 20-long head lane doesn't fit between the rows' ends and the west wall, so it stands
-- in an ALCOVE through the west wall at the aisle's end (Lobby.Apse): its front 3.8 studs past the deepest lanes, its
-- back half in the alcove, the plaza's deck running on to the wall.
Lobby.HeadFront = -64 -- the head lane's front (its shooter's end, facing east down the aisle)
Lobby.Apse = { z0 = 48, z1 = 62, back = -87, h = 24 } -- the opening in the west wall (z, height) and the alcove's back wall
-- (B30 path network: the aisle is the west walk's 12 wide, the rows close in on it, and the deck hugs the rows: their far
-- ends, a 0.8 margin and the kerb)
Lobby.Plaza = { x0 = -Lobby.W + 0.2, x1 = -Lobby.PlazaGap, z0 = Lobby.CrossZ - 6 - 20 - 2.0, z1 = Lobby.CrossZ + 6 + 20 + 2.0, aisle = { Lobby.CrossZ - 6, Lobby.CrossZ + 6 }, deck = 0.4 }
Lobby.Stand = {
	Pitch = 11, -- lane centre to lane centre (9-wide lanes: the reference's 2-stud gaps)
	-- where each lane stands: its row ('N' north of the aisle, facing south to it; 'S' south, facing north) and its place
	-- from the mouth (0 = by the spine), or 'End': the head lane on its stage at the aisle's far end, facing the spawn
	Spots = {
		Starter = { 'N', 0 }, Heavy = { 'N', 1 }, Speed = { 'N', 2 }, DoubleEnd = { 'N', 3 },
		Pro = { 'S', 0 }, Tape = { 'S', 1 }, Street = { 'S', 2 }, Gold = { 'S', 3 },
		Head = { 'End' },
	},
	Head = { Rise = 1.8, Steps = 3, Tread = 1.0, HalfZ = 5.6 }, -- the head lane's stage: its rise, its red steps, its half width
	Place = {},
	-- (B30: 0. The reference's stacks float at one height, about the follow camera's, so seen down the aisle the deeper
	-- ones sit lower and nearer the middle and read past the nearer ones; C's ladder lifted them into the near ones)
	LabelStep = 0, -- each place down the aisle lifts a lane's label stack this much (a north/south pair half of it apart)
	-- (B30, the user's overlap note) neighbouring places alternate: every second place's stack floats this much higher, so
	-- two stacks side by side never sit on one line from the spawn or the high views
	AltLift = 4.4,
	-- a Robux lane's (bigger) stack floats this much higher: clear of the product words in front of the south row's mouth
	-- (2x Cash), whose tops stay under its foot, so from the follow camera the two never meet
	PaidLift = 0, -- (B30: 0 now the places alternate; the 2x Cash stand moved off the mouth)
	Colors = {
		-- (LOBBY4: HALL2's tones again: the pale grey deck in its darker kerb, the walkway's lavender aisle, a red runner)
		deck = C(204, 206, 226), kerb = C(112, 118, 158), kerbTop = C(150, 154, 192), nose = C(228, 232, 250),
		aisle = C(183, 187, 230), aisleEdge = C(140, 146, 196), carpet = C(212, 84, 94), carpetDark = C(158, 46, 62),
		post = C(166, 170, 210), cap = C(210, 214, 242), riserDark = C(104, 110, 156), gold = C(245, 192, 30), goldDark = C(190, 130, 10),
		wood = C(176, 112, 70), woodDark = C(124, 76, 46), metal = C(70, 76, 96),
	},
	Lanes = {}, Slots = {},
}
-- A row place's lane centre x (0 = by the mouth), each row's z, and the head lane's centre x (Lobby.HeadFront: its front).
function Lobby.rowX(k) return Lobby.Plaza.x1 - 1.2 - 1.0 - 4.5 - Lobby.Stand.Pitch * k end
Lobby.RowZ = { N = Lobby.CrossZ - 16, S = Lobby.CrossZ + 16 } -- (the aisle's half width + the lanes' half length)
-- (B35) the built lane's half length: the compact bay's (Stations.LaneHalf), else the full 10
function Lobby.laneHalf() return Stations and (Stations.LaneHalf or Stations.HALF_Z) or 10 end
function Lobby.headHalf() return Stations and (Stations.HeadHalf or Stations.LaneHalf or Stations.HALF_Z) or 10 end
function Lobby.endX() return Lobby.HeadFront - Lobby.headHalf() end
function Lobby.standLayout()
	local St = Lobby.Stand
	table.clear(St.Lanes)
	table.clear(St.Slots)
	table.clear(St.Place)
	for _, id in Lobby.Ranges do
		local spot = St.Spots[id] or { 'N', 0 }
		if spot[1] == 'End' then
			table.insert(St.Place, { Lobby.endX(), Lobby.CrossZ, 'E', St.Head.Rise })
		else
			-- (a north-row lane faces south, a south-row lane north: both to the aisle)
			table.insert(St.Place, { Lobby.rowX(spot[2]), Lobby.RowZ[spot[1]], spot[1] == 'N' and 'S' or 'N', 0 })
		end
	end
	local dirs = { S = V(0, 0, 1), N = V(0, 0, -1), E = V(1, 0, 0) } -- (the way each lane's front faces: to the aisle)
	for i, p in St.Place do
		local pos = V(p[1], Lobby.Plaza.deck + p[4], p[2])
		St.Lanes[i] = { x = p[1], z = p[2], look = dirs[p[3]] }
		St.Slots[i] = CFrame.lookAt(pos, pos + dirs[p[3]])
	end
	return St
end
-- Hood props in a small cluster (c in the map frame, at = the cluster's centre on the ground it stands on):
-- kind 1 a stack of tyres, a crate and a cone; 2 two drums on a pallet; 3 a crate stack, a milk crate and a boombox.
function Lobby.standProps(c, kind, at)
	local wood, woodDark = C(196, 140, 80), C(146, 96, 52)
	local function crate(pos, s)
		c:box('Crate', pos - V(s / 2, 0, s / 2), pos + V(s / 2, s, s / 2), wood, M.SmoothPlastic)
		c:box('CrateBand', pos - V(s / 2 + 0.06, -s * 0.42, s / 2 + 0.06), pos + V(s / 2 + 0.06, s * 0.58, s / 2 + 0.06), woodDark, M.SmoothPlastic)
	end
	if kind == 1 then
		for k = 0, 2 do
			local p = at + V(-1.6 + k * 0.08, 0.36 + k * 0.72, -1.2)
			c:part('Tyre', V(0.72, 2.3, 2.3), CFrame.new(p) * CFrame.Angles(0, k * 0.4, math.pi / 2), C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		end
		c:part('TyreHub', V(0.74, 1.1, 1.1), CFrame.new(at + V(-1.44, 1.8, -1.2)) * CFrame.Angles(0, 0, math.pi / 2), C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
		crate(at + V(1.0, 0, 1.0), 2.2)
		if Stations then Stations.cone(c, CFrame.new(at + V(-1.2, 0, 1.9)) * CFrame.Angles(0, 0.5, 0)) end
	elseif kind == 2 then
		c:box('Pallet', at + V(-1.6, 0, -1.6), at + V(1.6, 0.4, 1.6), C(176, 126, 72), M.SmoothPlastic)
		c:box('PalletSkid', at + V(-1.5, 0, -0.3), at + V(1.5, 0.41, 0.3), C(128, 86, 46), M.SmoothPlastic)
		if Stations then
			Stations.drum(c, at + V(-0.8, 0.4, -0.7), 0.7, 2.0, C(40, 100, 210), C(26, 66, 150), C(30, 60, 130), M.SmoothPlastic)
			Stations.drum(c, at + V(0.8, 0.4, 0.6), 0.7, 2.0, C(214, 50, 46), C(150, 30, 30), C(120, 26, 26), M.SmoothPlastic)
		end
	else
		crate(at + V(-1.0, 0, -0.8), 2.2)
		crate(at + V(-0.9, 2.2, -0.7), 1.7)
		if Stations then
			Stations.milkcrate(c, CFrame.new(at + V(1.2, 0, 0.9)), C(40, 120, 220), { C(235, 55, 60), C(255, 150, 30) })
			Stations.boombox(c, CFrame.new(at + V(1.3, 0, -1.2)) * CFrame.Angles(0, -math.pi / 2, 0))
		end
	end
end
-- A cartoon graffiti mural painted on the west wall over z za..zb, y ya..yb (kind 1 a big target on a magenta
-- splat, 2 a lightning bolt on a cyan splat, 3 a crown on a yellow splat): a stepped splat with a darker drop
-- shadow, drips under it, the motif, two sparkle stars. Flat parts 0.1-0.3 proud of the wall's face (x -120).
function Lobby.rangeMural(c, kind, za, zb, ya, yb)
	local x0 = -Lobby.W
	local cz, cy = (za + zb) / 2, (ya + yb) / 2
	local w, h = zb - za, yb - ya
	local pal = ({ { C(236, 64, 160), C(150, 30, 104), C(255, 214, 60) }, { C(40, 200, 236), C(20, 110, 160), C(255, 230, 70) },
		{ C(255, 206, 40), C(190, 120, 10), C(150, 15, 40) } })[kind]
	-- (B30, calm environment: the paint is faded into the wall a little, so the lanes in front of it stay the loud thing)
	for i, col in pal do pal[i] = col:Lerp(Lobby.Colors.wall, 0.35) end
	local function paint(name, z0, z1, y0, y1, color, d)
		local p = decor(c:box(name, V(x0, y0, z0), V(x0 + (d or 0.12), y1, z1), color, M.SmoothPlastic))
		p.CastShadow = false
		return p
	end
	-- the splat: a cross of three stepped boxes over a darker drop shadow a little down and along
	for _, r in { { 0.5, 0.18, 0.06 }, { 0.36, 0.5, 0.06 }, { 0.44, 0.36, 0.06 } } do
		paint('MuralShadow', cz - w * r[1] + 0.5, cz + w * r[1] + 0.5, cy - h * r[2] - 0.5, cy + h * r[2] - 0.5, pal[2], 0.1)
	end
	for _, r in { { 0.48, 0.2 }, { 0.34, 0.46 }, { 0.42, 0.34 } } do
		paint('MuralSplat', cz - w * r[1], cz + w * r[1], cy - h * r[2], cy + h * r[2], pal[1], 0.16)
	end
	for _, d in { { -0.3, 1.6 }, { 0.05, 2.4 }, { 0.32, 1.2 } } do
		local z = cz + w * d[1]
		paint('MuralDrip', z - 0.35, z + 0.35, cy - h * 0.46 - d[2], cy - h * 0.4, pal[1], 0.16)
	end
	if kind == 1 then
		for k, r in { 4.2, 3.2, 2.2, 1.2 } do
			decor(c:part('MuralTarget', V(0.2 + k * 0.04, 2 * r, 2 * r), CFrame.new(x0 + 0.1 + k * 0.02, cy, cz), k % 2 == 1 and P.white or C(230, 40, 50), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		end
	elseif kind == 2 then
		local ys = math.min(h * 0.38, 4.5)
		for _, b in { { -1.2, ys * 0.55, 1.6, ys, -24 }, { 0.2, 0, 3.6, 1.1, 0 }, { 1.2, -ys * 0.55, 1.6, ys, -24 } } do
			decor(c:part('MuralBolt', V(0.3, b[4], b[3]), CFrame.new(x0 + 0.2, cy + b[2], cz + b[1]) * CFrame.Angles(math.rad(b[5]), 0, 0), pal[3], M.SmoothPlastic)).CastShadow = false
		end
	else
		local cw = math.min(w * 0.6, 7)
		paint('MuralCrown', cz - cw / 2, cz + cw / 2, cy - 2.2, cy + 0.2, pal[3], 0.3)
		for k = 0, 2 do
			local z = cz - cw / 2 + cw * (0.15 + 0.35 * k)
			paint('MuralCrown', z - 0.7, z + 0.7, cy + 0.2, cy + 2.4, pal[3], 0.3)
			paint('MuralGem', z - 0.35, z + 0.35, cy - 1.4, cy - 0.7, k == 1 and C(60, 140, 255) or C(220, 30, 60), 0.36)
		end
	end
	for _, st in { { -0.4, 0.3 }, { 0.42, -0.2 } } do
		decor(c:part('MuralStar', V(0.2, 1.1, 1.1), CFrame.new(x0 + 0.2, cy + h * st[2], cz + w * st[1]) * CFrame.Angles(math.pi / 4, 0, 0), P.white, M.SmoothPlastic)).CastShadow = false
	end
end
-- The head lane's stage (the reference's 250x shrine, ref_W06.5_train_aisle_endcap_250x.jpg): a raised gold studded stage
-- at the aisle's far end with a pale trim round its top, two red carpet steps down to the aisle (dark red nosings), a gold
-- post at each front corner, and a see-through glass dome over the target field with a gold finial: the biggest, brightest
-- thing in the plaza. c: the plaza's group; returns nothing (the lane itself is Lobby.place'd on it).
function Lobby.headStage(t, K)
	local Pz, H = Lobby.Plaza, Lobby.Stand.Head
	local h, hz = Pz.deck, H.HalfZ
	local zc = Lobby.CrossZ
	local x0 = Lobby.endX() - Lobby.headHalf() - 1.0 -- (its back, a stud past the lane's, in the alcove)
	-- (the head lane faces east, +x: its front, the shooter's end, is at endX + HALF_Z)
	local xf = Lobby.endX() + Lobby.headHalf() + 0.6 -- the stage's front edge, 0.6 past the lane's rim
	local top = h + H.Rise
	local gold, goldDeep, goldPale = K.gold, K.goldDark, C(255, 236, 150)
	-- (from the floor: its back half stands in the alcove, past the plaza's deck)
	studs(t:box('HeadStage', V(x0, 0, zc - hz), V(xf, top - 0.2, zc + hz), gold, M.Plastic), true)
	t:box('HeadStageBand', V(x0 - 0.05, 0, zc - hz - 0.08), V(xf + 0.08, h + 0.35, zc + hz + 0.08), goldDeep, M.SmoothPlastic)
	studs(t:box('HeadStageTop', V(x0, top - 0.2, zc - hz), V(xf, top, zc + hz), goldPale, M.Plastic))
	t:box('HeadStageLip', V(xf - 0.25, top - 0.1, zc - hz - 0.1), V(xf + 0.1, top + 0.05, zc + hz + 0.1), C(255, 250, 220), M.SmoothPlastic)
	-- the red steps down to the aisle: risers of Rise / Steps, each tread H.Tread deep
	local n = H.Steps
	for k = 1, n - 1 do
		local y = h + H.Rise * (n - k) / n
		local xa = xf + (k - 1) * H.Tread
		studs(t:box('HeadStep', V(xa, h, zc - hz + 0.6), V(xa + H.Tread, y, zc + hz - 0.6), K.carpet, M.Plastic))
		t:box('HeadStepNose', V(xa + H.Tread - 0.18, y - 0.12, zc - hz + 0.6), V(xa + H.Tread + 0.04, y + 0.03, zc + hz - 0.6), K.carpetDark, M.SmoothPlastic)
	end
	-- the corner posts at the stage's front, gold with a glowing cap (the shrine's pillars), in the strip beside the lane
	for _, sz in { -1, 1 } do
		local z = zc + sz * (hz - 0.55)
		local x = xf - 0.6
		t:box('HeadPost', V(x - 0.55, top, z - 0.55), V(x + 0.55, top + 5.2, z + 0.55), gold, M.SmoothPlastic)
		t:box('HeadPostBand', V(x - 0.62, top + 2.2, z - 0.62), V(x + 0.62, top + 2.6, z + 0.62), goldDeep, M.SmoothPlastic)
		t:box('HeadPostCap', V(x - 0.75, top + 5.2, z - 0.75), V(x + 0.75, top + 5.55, z + 0.75), goldPale, M.SmoothPlastic)
		decor(t:box('HeadPostLamp', V(x - 0.4, top + 5.55, z - 0.4), V(x + 0.4, top + 6.35, z + 0.4), C(255, 232, 140), M.Neon)).CastShadow = false
	end
	-- the glass dome over the target field (an ellipsoid half under the stage top), a gold finial on its crown
	local cx = Lobby.endX() - 3.4
	local dome = decor(t:blob('HeadDome', V(14, 17, 2 * hz - 0.4), V(cx, top, zc), C(236, 246, 255), M.Glass))
	dome.Transparency, dome.CastShadow = 0.72, false
	t:post('HeadFinialFoot', 0.9, 0.5, V(cx, top + 8.4, zc), goldDeep, M.SmoothPlastic)
	decor(t:part('HeadFinial', V(1.1, 1.1, 1.1), CFrame.new(cx, top + 9.4, zc) * CFrame.Angles(0, math.pi / 4, math.pi / 4), goldPale, M.Neon)).CastShadow = false
end
function Lobby.stand(L, skins)
	local St = Lobby.standLayout()
	local K, Pz = St.Colors, Lobby.Plaza
	local x0, x1, z0, z1, h = Pz.x0, Pz.x1, Pz.z0, Pz.z1, Pz.deck
	local a0, a1 = Pz.aisle[1], Pz.aisle[2]
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	local t = L:group('RangeStand')
	local function slab(name, a, b, color, sides) return Lobby.slab(t, name, a, b, color, sides) end
	local function flat(name, a, b, color, mat)
		local p = decor(t:box(name, a, b, color, mat or M.SmoothPlastic))
		p.CastShadow = false
		return p
	end

	-- The deck, the kerb round it (a hair proud, studded, a paler top band) and studded corner blocks; the kerb is open
	-- across the aisle mouth on the east edge, where a pale nosing finishes the step up from the hall floor.
	-- (B34: nothing to trip on: the kerb's top band stands 0.5 over the floor, the corner blocks too)
	local kw = 1.2
	slab('PlazaDeck', V(x0 + kw, 0, z0 + kw), V(x1 - kw, h, z1 - kw), K.deck)
	local ky = math.min(h + 0.25, 0.46)
	-- (B30: open at both ends of the aisle: the mouth by the spine and the west end, where the aisle runs on into the
	-- head lane's alcove)
	local kerbs = {
		{ V(x0, 0, z0), V(x1, ky, z0 + kw) }, { V(x0, 0, z1 - kw), V(x1, ky, z1) },
		{ V(x0, 0, z0 + kw), V(x0 + kw, ky, a0) }, { V(x0, 0, a1), V(x0 + kw, ky, z1 - kw) },
		{ V(x1 - kw, 0, z0 + kw), V(x1, ky, a0) }, { V(x1 - kw, 0, a1), V(x1, ky, z1 - kw) },
	}
	for _, e in kerbs do
		slab('PlazaKerb', e[1], e[2], K.kerb, true)
		flat('PlazaKerbTop', V(e[1].X + 0.15, ky, e[1].Z + 0.15), e[2] + V(-0.15, 0.04, -0.15), K.kerbTop)
	end
	slab('PlazaDeck', V(x1 - kw, 0, a0), V(x1, h, a1), K.aisle) -- (the mouth: the aisle's own colour)
	slab('PlazaDeck', V(x0, 0, a0), V(x0 + kw, h, a1), K.aisle) -- (the west end, on into the alcove)
	flat('PlazaNosing', V(x1 - 0.06, h - 0.14, a0), V(x1 + 0.3, h + 0.03, a1), K.nose)
	for _, c in { { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } } do
		local cx, cz = c[1] + (c[1] == x0 and 0.9 or -0.9), c[2] + (c[2] == z0 and 0.9 or -0.9)
		slab('PlazaCorner', V(cx - 1.1, 0, cz - 1.1), V(cx + 1.1, ky, cz + 1.1), K.kerb, true)
		flat('PlazaCornerCap', V(cx - 1.2, ky, cz - 1.2), V(cx + 1.2, ky + 0.04, cz + 1.2), K.cap)
	end

	-- The aisle: the walkway's lavender from the mouth to the west kerb, darker edge lines, a red runner down its middle
	-- from the mouth to the head lane's red steps (the reference's red steps up to its 250x).
	local ax = x0
	slab('Aisle', V(ax, h, a0), V(x1 - kw, h + 0.04, a1), K.aisle)
	for _, z in { a0, a1 - 0.35 } do flat('AisleEdge', V(ax, h + 0.04, z), V(x1 - kw, h + 0.07, z + 0.35), K.aisleEdge) end
	local rz0, rz1 = (a0 + a1) / 2 - 3, (a0 + a1) / 2 + 3
	local rx = Lobby.endX() + Lobby.headHalf() + 0.6 + (St.Head.Steps - 1) * St.Head.Tread -- (the steps' foot)
	slab('AisleRunner', V(rx, h + 0.04, rz0 + 0.6), V(x1, h + 0.16, rz1 - 0.6), K.runner or K.carpet)
	for _, z in { rz0, rz1 - 0.6 } do slab('AisleRunnerEdge', V(rx, h + 0.04, z), V(x1, h + 0.16, z + 0.6), K.runnerEdge or K.carpetDark) end

	-- Two lamp posts at the mouth, one on each kerb end (lobby C's): a dark foot, a light post with a band, a pale cap, a
	-- warm lamp under a dark lid. (B30: none between the lanes: the reference's lanes stand 2 studs apart, nothing between.)
	local function lamp(x, z)
		local y = h
		slab('LaneLampFoot', V(x - 0.65, y, z - 0.65), V(x + 0.65, y + 0.55, z + 0.65), K.riserDark)
		t:box('LaneLampPost', V(x - 0.42, y + 0.55, z - 0.42), V(x + 0.42, y + 4.4, z + 0.42), K.post, M.SmoothPlastic)
		t:box('LaneLampBand', V(x - 0.47, y + 2.1, z - 0.47), V(x + 0.47, y + 2.45, z + 0.47), K.riserDark, M.SmoothPlastic)
		t:box('LaneLampCap', V(x - 0.6, y + 4.4, z - 0.6), V(x + 0.6, y + 4.7, z + 0.6), K.cap, M.SmoothPlastic)
		decor(t:box('LaneLamp', V(x - 0.38, y + 4.7, z - 0.38), V(x + 0.38, y + 5.4, z + 0.38), C(255, 236, 196), M.Neon)).CastShadow = false
		t:box('LaneLampTop', V(x - 0.52, y + 5.4, z - 0.52), V(x + 0.52, y + 5.62, z + 0.52), K.riserDark, M.SmoothPlastic)
	end
	for _, z in { a0 - 0.65, a1 + 0.65 } do lamp(x1 - 0.6, z) end

	-- the head lane's gold stage
	Lobby.headStage(t, K)

	-- Graffiti murals on the west wall in the bays either side of the RANGES sign's pillar, under the windows: a target,
	-- a lightning bolt, a crown in the bay south of them.
	-- (centred in the bays between the side pillars, under the low wall lamps)
	-- (B30: the bays either side of the head lane's alcove, and the next one south)
	local sp, A = Lobby.SidePillars, Lobby.Apse
	for k, bay in { { sp[1] + Lobby.PillarW / 2 + 0.6, A.z0 - 2.6 }, { A.z1 + 2.6, sp[3] - Lobby.PillarW / 2 - 0.6 }, { sp[3] + Lobby.PillarW / 2 + 0.6, sp[4] - Lobby.PillarW / 2 - 0.6 } } do
		Lobby.rangeMural(t, k, bay[1], bay[2], 4.8, 12.6)
	end
	-- props in tight clusters on the deck past the deepest lanes, by the wall (the reference's sandbag and crate piles
	-- at the plaza's edges): tyres and a cone, a drum pallet, a crate stack, clear of the lanes and the aisle
	local px = (x0 + kw + Lobby.rowX(3) - 4.5) / 2
	for _, c in { { 1, Lobby.RowZ.N - 6 }, { 3, Lobby.RowZ.N + 5 }, { 2, Lobby.RowZ.S - 5 }, { 1, Lobby.RowZ.S + 6 } } do
		Lobby.standProps(t, c[1], V(px, h, c[2]))
	end

	-- The lanes. Each label stack climbs LabelStep per place down the aisle (a north/south pair half a step apart), so seen
	-- from the mouth the deeper stacks stand over the nearer ones instead of running into them; a Robux lane's bigger stack
	-- a stud higher still. The head lane stands on its stage (its slot is raised).
	for k, id in Lobby.Ranges do
		local s = skins.StationById[id]
		if s then
			local spot = St.Spots[id] or { 'N', 0 }
			local step = spot[1] == 'End' and 7 or (2 * spot[2] + (spot[1] == 'S' and 1 or 0))
			local alt = (spot[1] ~= 'End' and spot[2] % 2 == 1) and St.AltLift or 0
			local lift = step * St.LabelStep + alt + (s.Pass and St.PaidLift or 0)
			Lobby.place(L, training, 'Range_' .. id, St.Slots[k], (id == 'Head' and { X = 9, Y = 12, Z0 = -Lobby.headHalf(), Z1 = Lobby.headHalf() } or { X = 9, Y = 12, Z0 = -Lobby.laneHalf(), Z1 = Lobby.laneHalf() }), string.upper(s.Name or id), C(90, 200, 120),
				Stations and function(c) Stations.build(c, id, { labelLift = lift }) end)
		end
	end
	return t
end

---------------------------------------------------------------------------------------------- shoe box dais
-- The EGGS/PETS dais of ref_lobby.png at the spine's south end: a low stepped stage just past the band holding
-- World 1's four SHOE BOXES in one row, left to right as seen from the hall: the two Cash boxes (Street, Graffiti),
-- then the two Robux boxes (BRIEF21; the other boxes are kept for later worlds and not built here).
-- LOBBY5 (BRIEF23: "the boxes. They are too big. Like check out the eggs in the other games. They match the
-- characters height basically, or are a bit bigger"): every box is sized so the top of its art stands Dais.ArtTop
-- (6.3) over the deck you stand on, a Robux box Dais.PremiumTop (6.3: its topper bobs ~0.7 over it, so it peaks under 7)
-- on a wider gold-ringed pad: an R15 character is ~5.5. Each stands on a
-- low round pedestal (the reference's egg pads: a dark foot, a drum in the box's colour, a glowing ring, a pale top)
-- over a checkered shelf strip, its name and price floating just over it; each is turned a little toward the spine.
-- The stage shrank with them (39 x 11.6 plus the stairs, was 49 x 19) and came forward (CRITIC3 r1: near the player, its
-- front 7 studs past the training plaza's end; behind it a stockroom of shoe cartons): a darker studded rim round a paler studded
-- deck 1.6 high, a front step and a stair at each end, pale nosings on every edge; a backdrop along the back (a
-- studded wall with a pale cap, the Robux half framed in gold with a rainbow strip), and over it a stage-like frame
-- (three posts, a header beam, marquee bulbs) carrying SHOE BOXES over the Cash boxes and a gold EXCLUSIVE over the
-- Robux ones, so the two Robux boxes read as the special ones.
-- Map contract (HoodServer/ShoeService, HoodClient/Shoes.client): a Model `ShoeBoxes` tagged HoodShoeBoxes holding
-- `ShoeBox_<Id>` Models (attributes BoxId, Order, World, Price on a Cash box, RobuxPrice and Exclusive on a Robux box),
-- each with:
--   Box_<Id>         BoxModels.build (the closed box; its `Lid` sub-model can pop), on its pad
--   BoxPoint_<Id>    invisible part on the pad's front, about 3 studs over the deck you stand on: the prompt anchor and
--                    the point ShoeService measures to (ShoeRules.Range 12)
--   BoxLabel_<Id>    BillboardGui WorldLabel: TextLabels Title and Price. A Cash box: Title its name, Price its Cash
--                    price (Glyph attribute as the armory's). A Robux box (the reference hall's "99 Robux / Exclusive"
--                    eggs): Title the Robux price, Price "Exclusive", both green. An Attachment ChancesPoint over it
--                    marks where Shoes.client floats the chances board. LabelFade picks it up by name (boxes 34 -> 58).
--   BoxCollider      an invisible solid block round the box (the box's own parts don't collide)
-- The boxes and their order come from Config.Shoes.boxesForWorld(world) (BOXES2's contract), or a stand-in list
-- while it is missing. Lobby.Slots.ShoeBoxes (+ SlotSizes): the dais's front centre on the floor; Lobby.Slots.ShoeBox<i>:
-- box i's pad top, facing the hall.
-- (P3) the box dais's frame: the front step's edge at world x -30 on the west field, the row's centre at z 66.5, local -Z (the
-- front) turned to the east, to the cross arm and the spawn; local +X runs south, +Z runs west (the deck's depth)
Lobby.SouthZ = Lobby.CrossZ + Lobby.Band + Lobby.SouthWalk -- where the south walk ends: the corner fields start here
-- (B30: lobby C's place again, the spine's south end: the front step's edge on the south walk's far side, facing north up
-- the spine to the spawn)
Lobby.DaisAt = CFrame.new(0, 0, Lobby.SouthZ - 1.2)
Lobby.Dais = (function()
	-- (LOBBY5 r2, CRITIC3: "bring the box stage forward, near the player"): the front step starts 8.4 studs past the band's
	-- end (the walk between the training plaza's corner and the stage), the backdrop right behind the row
	local front = 1.2 -- the front step's tread
	local z0 = front -- the deck's front edge, in the dais's own frame (P3: the dais stands on the west field, Lobby.DaisAt turns it to the spawn)
	local rowZ = z0 + 2.6 + 3.9 -- the row's centre line: 2.6 of deck in front of the widest pad, where you stand at a box
	local back = 1.2 -- the backdrop's thickness
	local z1 = rowZ + 3.9 + 0.8 + back -- the backdrop's back, 0.8 behind the widest pad
	return {
		-- the deck x +-19.5 (the stairs take it to +-22.5), z0..z1, 1.6 high (two 0.8 risers at the front and at each end)
		X = 22, StairW = 3, Front = front, Z0 = z0, Z1 = z1, Low = 1.6, PadR = 3.5, PremiumR = 3.5, PadH = 1.0, -- (B31, critic 5: discs 7 wide, 1 tall)
		-- box i stands at x = First - (i - 1) * Pitch (left to right from the hall), all on the one row; the top of each
		-- box's art ArtTop over the deck (PremiumTop for a Robux box: the featured eggs of the reference's row)
		-- (LOBBY5 r3, CRITIC3: the Robux boxes' toppers bob up ~0.7, so both land at 6.3: under 7 with the bob)
		First = 15, Pitch = 10, RowZ = rowZ, Back = back, BackH = 3.2, HeadY = 14.6, HeadH = 4.2, ArtTop = 6.1, PremiumTop = 6.1, -- (B31: 5-stud boxes)
		-- (B30) the premium box's slot: a wider pedestal, taller art, a wider fit; Slots: the row's x positions, left to right
		-- from the hall, the premium one in the third
		TopR = 3.9, TopArt = 6.6, TopWide = 7.6, Slots = { 16.5, 6, -5, -16 },
		-- (B30 final, ref_W23.0_egg_row: a box's width of floor between boxes; the premium on a raised studded plinth)
		Fit = 6.6, Plinth = 1.2,
	}
end)()
-- The stand-in until Config.Shoes.boxesForWorld exists: the two cheapest Cash boxes, then the two Robux boxes.
Lobby.ShoeBoxStub = {
	{ Id = 'Street', Name = 'Street Box', Price = 25, Color = C(232, 70, 56), World = 1 },
	{ Id = 'Graffiti', Name = 'Graffiti Box', Price = 75, Color = C(255, 110, 190), World = 1 },
	{ Id = 'Exclusive', Name = 'Exclusive Box', RobuxPrice = 99, Robux = 'ShoeBoxExclusive', Exclusive = true, Color = C(70, 200, 255), World = 1 },
	{ Id = 'Grail', Name = 'Grail Box', RobuxPrice = 199, Robux = 'ShoeBoxGrail', Exclusive = true, Color = C(170, 80, 255), World = 1 },
}
-- A shared module by path under ReplicatedStorage.Shared ('Config', 'Shoes'), nil if missing or failing.
function Lobby.sharedModule(...)
	local m = ReplicatedStorage:FindFirstChild('Shared')
	for _, name in { ... } do m = m and m:FindFirstChild(name) end
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end
-- This world's boxes in dais order: Config.Shoes.boxesForWorld(1) (Cash boxes cheapest first, then the Robux boxes
-- cheapest first); without it, the config's two cheapest Cash boxes (or the stub's) and the stub's Robux boxes.
function Lobby.shoeBoxList()
	local cfg = Lobby.sharedModule('Config', 'Shoes')
	local world = cfg and type(cfg.ActiveWorld) == 'number' and cfg.ActiveWorld or 1
	if cfg and type(cfg.boxesForWorld) == 'function' then
		local ok, list = pcall(cfg.boxesForWorld, world)
		if ok and type(list) == 'table' and #list > 0 then return list end
	end
	local cash = {}
	for _, b in (cfg and type(cfg.Boxes) == 'table' and #cfg.Boxes > 0) and cfg.Boxes or Lobby.ShoeBoxStub do
		if not b.Robux and type(b.Price) == 'number' then table.insert(cash, b) end
	end
	table.sort(cash, function(a, b) return a.Price < b.Price end)
	local list = { cash[1], cash[2] }
	for _, b in Lobby.ShoeBoxStub do
		if b.Robux then table.insert(list, (cfg and cfg.BoxById and cfg.BoxById[b.Id]) or b) end
	end
	return list
end
-- One round pedestal (c: its centre on the deck, front -Z) in colour col, low like the reference's egg pads: a dark
-- foot, a drum in the box's colour with a pale band (gold on a Robux box), a glowing ring, a pale top; a small tag
-- leaning on its front (the video's oval tags) with `tag` on it. Returns the height of its top.
-- (B30, ref_W23.0_egg_row.jpg / ref_W00.0: the eggs' round grey studded stone pedestals, a small white oval tag on the
-- front with a short coloured word; the premium one wider, glowing in gold with a haze and a light)
function Lobby.boxPad(c, col, tag, premium, radius)
	local r = radius or Lobby.Dais.PadR
	local gold = Lobby.Colors.gold
	local _ = col
	-- (rule 29) the user's Pedestal_Box (7 wide, 1.1 tall) when imported; else our grey stone disc 1 stud tall: a dark
	-- foot, the body, a pale top (a gold band on the Robux boxes)
	local height = Lobby.Dais.PadH
	local k = 2 * r / 7
	if Lobby.designed(c, 'Pedestal_Box', k) then
		height = 1.1 * k
	else
		local stone, stoneDark, stoneTop = C(170, 174, 190), C(118, 122, 142), C(206, 210, 224)
		studs(c:post('BoxPadFoot', r, 0.2, V(0, 0, 0), stoneDark, M.Plastic))
		studs(c:post('BoxPadDrum', r - 0.25, 0.62, V(0, 0.2, 0), stone, M.Plastic))
		c:post('BoxPadBand', r - 0.22, 0.12, V(0, 0.5, 0), premium and gold or stoneTop, M.SmoothPlastic)
		studs(c:post('BoxPadTop', r - 0.4, 0.18, V(0, 0.82, 0), stoneTop, M.Plastic))
		if premium then decor(c:post('BoxPadRing', r - 0.12, 0.1, V(0, 0.6, 0), gold, M.Neon)).CastShadow = false end -- (a gold ring under the top's edge)
	end
	if premium then
		-- the Robux boxes' rising haze
		local hz = ghost(c:box('PadHazeBox', V(-r + 0.8, height, -r + 0.8), V(r - 0.8, height + 0.1, r - 0.8), P.white))
		hz.CastShadow = false
		Lobby.padHaze(hz, C(255, 200, 60), 2)
	end
	if tag then
		-- the oval: a white pill (a slab with round ends) leaning back on the pedestal's front, its word in a gradient
		-- (B30 final, ref_W23.0_egg_row: the "x6" pill about the pedestal's width, standing at its front edge)
		local cf = CFrame.new(0, 0.7, -r - 0.05) * CFrame.Angles(-0.25, 0, 0)
		local plate = c:part('BoxPadTag', V(3.0, 0.95, 0.14), cf, P.white, M.SmoothPlastic)
		for _, sx in { -1, 1 } do c:part('BoxPadTagEnd', V(0.14, 0.95, 0.95), cf * CFrame.new(sx * 1.5, 0, 0.002 * sx) * CFrame.Angles(0, math.pi / 2, 0), P.white, M.SmoothPlastic, Enum.PartType.Cylinder) end
		c:part('BoxPadTagRim', V(4.1, 1.15, 0.1), cf * CFrame.new(0, 0, 0.1), C(60, 64, 86), M.SmoothPlastic)
		local tl = line(surface(plate, Enum.NormalId.Front, 60), 'Tag', tag, P.white, FONT.title, 0.06, 0.88, Lobby.Ink, 2)
		Lobby.fill(tl, premium and 'rainbow' or Lobby.Grad.blue)
	end
	return height
end
-- The floating label over a box (the video's egg labels), kept low so Shoes.client's chances board has the space above
-- it (at the ChancesPoint attachment). A Cash box: its name in its colour over its Cash price in yellow. A Robux box:
-- the reference hall's "99 Robux / Exclusive" in green: the Robux price (the Robux icon, or the glyph) over Exclusive.
-- (LOBBY5 r2, CRITIC3: "name and price at 2x, readable across the hall like ref_hall_b's '99 Robux Exclusive'"):
-- 9 x 4.2 studs (a Robux box's 9.6 x 5), whole to 55 studs and gone by 85 (LabelFade FadeNear / FadeFar), so they read
-- from the spawn; the Cash price in the HUD's Cash green beside the Cash icon.
Lobby.BoxLabelH, Lobby.BoxLabelRobuxH = 4.2, 5.0
function Lobby.boxLabel(c, id, pos, box, col)
	local a = ghost(c:part('BoxLabel_' .. id, V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	-- (the name without " Box": the box says SHOE BOX on its own plate, and the short word reads twice as big)
	local name = string.gsub(box.Name or id, ' Box$', '')
	local robux = box.Robux ~= nil
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	local h = robux and Lobby.BoxLabelRobuxH or Lobby.BoxLabelH
	g.Size = robux and UDim2.fromScale(9.6, h) or UDim2.fromScale(math.max(9, 0.72 * #name), h)
	g.MaxDistance = 40 -- (B31 PLAZA, critic 3: words read up close, ~30 studs)
	g.LightInfluence = 0
	g:SetAttribute('FadeNear', 30)
	g:SetAttribute('FadeFar', 40)
	g.Parent = a
	local ink = C(24, 22, 40)
	local icons = Lobby.sharedModule('Models', 'IconModels')
	local images = icons and icons.Images or {}
	local function icon(t, key, glyph, y, h, x)
		local image = images[key]
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = 'PriceIcon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(x, y)
			i.Size = UDim2.fromScale(0.16, h)
			local r = Instance.new('UIAspectRatioConstraint')
			r.Parent = i
			i.Parent = g
			t.Position, t.Size, t.TextXAlignment = UDim2.fromScale(x + 0.17, y), UDim2.fromScale(0.96 - x - 0.17, h), Enum.TextXAlignment.Left
			t:SetAttribute('Glyph', '')
		else
			t.Text = glyph .. ' ' .. t.Text
			t:SetAttribute('Glyph', glyph)
		end
	end
	-- (B30, ref_W23.0_egg_row.jpg: the name on top in white, the price under it in lime with its icon, both Montserrat Black
	-- in a thick dark outline with a gradient fill; on a Robux box the name in its colour. Lobby.client looks for the price
	-- text by name: Title on a Robux box, Price on a Cash box.)
	if robux then
		local nameL = line(g, 'Price', box.Name or 'Exclusive', P.white, FONT.title, 0, 0.5, ink, 3.5)
		Lobby.fill(nameL, { col:Lerp(P.white, 0.6), col:Lerp(P.white, 0.15) })
		local t = line(g, 'Title', tostring(box.RobuxPrice or ''), P.white, FONT.title, 0.5, 0.5, ink, 3.5)
		Lobby.fill(t, Lobby.Grad.lime)
		-- (B31, the user: "add the robux sign in front of the robux price just like in the games") the Robux mark, U+E002
		t.Text = RobuxText.fmt(box.RobuxPrice)
		g:SetAttribute('Robux', true)
	else
		local nameL = line(g, 'Title', name, P.white, FONT.title, 0, 0.56, ink, 3.5)
		Lobby.fill(nameL, Lobby.Grad.white)
		local t = line(g, 'Price', compact(box.Price or 0), P.white, FONT.title, 0.56, 0.44, ink, 3.5)
		Lobby.fill(t, Lobby.Grad.lime)
		icon(t, 'Cash', '💵', 0.56, 0.44, 0.24)
	end
	shadowAll(g)
	local cp = Instance.new('Attachment')
	cp.Name = 'ChancesPoint'
	cp.CFrame = CFrame.new(0, h / 2 + 2.9, 0) -- (the 5-stud board just over the label)
	cp.Parent = a
	return a
end
-- The tallest point of a model's visible parts (world y), or nil.
function Lobby.topOf(model)
	local yTop = -math.huge
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local _, y, _, _, _, _, r10, r11, r12 = p.CFrame:GetComponents()
			yTop = math.max(yTop, y + (math.abs(r10) * p.Size.X + math.abs(r11) * p.Size.Y + math.abs(r12) * p.Size.Z) / 2)
		end
	end
	return yTop > -math.huge and yTop or nil
end
-- A box model at character height (BRIEF23): built once at scale 1 to measure how tall its art stands, then at the
-- scale that makes it `tall` studs, at `at`. Returns the model and its scale (nil, err when BoxModels fails).
-- (B30: and never wider than wide studs: a wide model, the Crown chest with its wings, is sized by its width so it stays
-- inside the dais's pitch; the width is its larger footprint side, as the boxes stand turned a little)
function Lobby.footprintOf(model)
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, _, z, r00, r01, r02, _, _, _, r20, r21, r22 = p.CFrame:GetComponents()
			local hx = (math.abs(r00) * p.Size.X + math.abs(r01) * p.Size.Y + math.abs(r02) * p.Size.Z) / 2
			local hz = (math.abs(r20) * p.Size.X + math.abs(r21) * p.Size.Y + math.abs(r22) * p.Size.Z) / 2
			x0, x1, z0, z1 = math.min(x0, x - hx), math.max(x1, x + hx), math.min(z0, z - hz), math.max(z1, z + hz)
		end
	end
	if x1 < x0 then return nil end
	return math.max(x1 - x0, z1 - z0)
end
function Lobby.sizedBox(BoxModels, id, tall, at, wide)
	local ok, probe = pcall(BoxModels.build, id, 1, CFrame.new())
	if not ok or not probe then return nil, probe end
	local natural = (Lobby.topOf(probe) or 6) - 0
	local width = Lobby.footprintOf(probe)
	probe:Destroy()
	local sc = math.clamp(tall / math.max(natural, 1), 0.5, 2)
	if wide and width and width * sc > wide then sc = math.max(0.3, wide / width) end
	local okB, box = pcall(BoxModels.build, id, sc, at)
	if not okB or not box then return nil, box end
	return box, sc
end
-- The box the dais shows in its middle: the most expensive Robux box (nil when there is none).
function Lobby.premiumBox(list)
	local best
	for _, b in list do
		if b.Robux and (not best or (b.RobuxPrice or 0) > (best.RobuxPrice or 0)) then best = b end
	end
	return best
end
-- Box i's x on the row (Lobby.Dais.Slots, left to right from the hall): the premium box in the third slot, the cheaper Robux
-- box next to it, the Cash boxes on the outside, cheapest at the left. Another count of boxes: the old even row.
function Lobby.boxSlotX(list, i)
	local D = Lobby.Dais
	local slots = D.Slots
	local prem = Lobby.premiumBox(list)
	if #list ~= #slots or not prem then return D.First - (i - 1) * D.Pitch end
	if list[i] == prem then return slots[3] end
	local cash, robux = {}, {}
	for _, b in list do
		if b ~= prem then table.insert(b.Robux and robux or cash, b) end
	end
	local order = { cash[1], robux[1] or cash[3], cash[2] } -- (slots 1, 2 and 4)
	local at = { slots[1], slots[2], slots[4] }
	for n, b in order do if b == list[i] then return at[n] end end
	return D.First - (i - 1) * D.Pitch
end
-- The area's title board over the box row (ref_W14.5's hanging "PETS" board): a pale studded frame round a white panel,
-- the three-boxes icon (LobbyModels, still) at its left and "BOXES" in big outlined letters, on two chains up to the roof
-- girder. pos: the board's centre in the dais's frame, its face toward -Z.
function Lobby.boxesBoard(d, pos)
	local g = d:at(CFrame.new(pos)):group('BoxesBoard')
	local w, h = 20, 5.6
	-- (B31 PLAZA: out in the open the board hangs on short chains from a slim gantry, its posts in the gaps between the
	-- outer boxes, standing on the dais deck)
	local floor = Lobby.Dais.Low - pos.Y
	local px, beamY = w / 2 + 1.0, h / 2 + 2.4
	local steel, steelDark = C(150, 156, 186), C(104, 108, 140)
	for _, sx in { -1, 1 } do
		g:box('BoxesGantryFoot', V(sx * px - 0.7, floor, -0.7), V(sx * px + 0.7, floor + 0.5, 0.7), steelDark, M.SmoothPlastic)
		g:box('BoxesGantryPost', V(sx * px - 0.4, floor + 0.5, -0.4), V(sx * px + 0.4, beamY, 0.4), steel, M.SmoothPlastic)
	end
	g:box('BoxesGantryBeam', V(-px - 0.6, beamY, -0.5), V(px + 0.6, beamY + 0.8, 0.5), steelDark, M.SmoothPlastic)
	-- (rule 29) the user's Board_Boxes (its hanger rods up to the beam) when imported, else ours on two chains
	local kb = 1.2
	if not Lobby.designed(g:at(CFrame.new(0, beamY - 10.1 * kb, 0)), 'Board_Boxes', kb) then
		for _, sx in { -1, 1 } do
			decor(g:box('BoxesBoardChain', V(sx * (w / 2 - 2) - 0.12, h / 2 + 0.5, -0.12), V(sx * (w / 2 - 2) + 0.12, beamY, 0.12), C(52, 54, 66), M.SmoothPlastic)).CastShadow = false
		end
		studs(g:box('BoxesBoardFrame', V(-w / 2, -h / 2, -0.3), V(w / 2, h / 2, 0.5), C(204, 208, 226), M.Plastic), true)
		local panel = g:box('BoxesBoardPanel', V(-w / 2 + 0.8, -h / 2 + 0.8, -0.42), V(w / 2 - 0.8, h / 2 - 0.8, -0.3), C(244, 246, 252), M.SmoothPlastic)
		g:box('BoxesBoardCap', V(-w / 2 - 0.3, h / 2, -0.45), V(w / 2 + 0.3, h / 2 + 0.5, 0.65), C(150, 156, 186), M.SmoothPlastic)
		local sg = surface(panel, Enum.NormalId.Front, 30)
		local tl = line(sg, 'Title', 'BOXES', P.white, FONT.title, 0.04, 0.92, Lobby.Ink, 6)
		tl.Position, tl.Size = UDim2.fromScale(0.28, 0.04), UDim2.fromScale(0.68, 0.92) -- (the icon takes the left)
		Lobby.fill(tl, { C(255, 236, 120), C(255, 160, 40) })
		-- (the icon at the viewer's left of the word: local +X is the viewer's left from the hall)
		local icon = Lobby.standItem(g:at(CFrame.new(w / 2 - 3.4, 0, -1.6)), 'StandBoxes', 0.95)
		icon:SetAttribute('Spin', nil)
		icon:SetAttribute('Bob', nil)
		icon:RemoveTag('HoodMotion')
	end
	return g
end
function Lobby.shoeDais(L0)
	local L = L0:at(Lobby.DaisAt)
	local K = Lobby.Colors
	local D = Lobby.Dais
	local X, z0, z1, lo = D.X, D.Z0, D.Z1, D.Low
	local d = L:group('ShoeBoxDais')
	local rim, deck, trim = K.pillarSide, K.dais, K.trim
	-- the deck: a darker body (its sides and a 0.6 rim show) under a paler studded top, chamfered front corners
	Lobby.slab(d, 'Dais', V(-X + 3, 0, z0), V(X - 3, lo - 0.25, z1), rim, true)
	Lobby.slab(d, 'Dais', V(-X, 0, z0 + 3), V(X, lo - 0.25, z1), rim, true)
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (X - 1.5), (lo - 0.25) / 2, z0 + 1.5) * CFrame.Angles(0, 0, sx > 0 and -math.pi / 2 or math.pi / 2)
		studs(d:wedge('DaisCorner', V(lo - 0.25, 3, 3), cf, rim, M.Plastic), true)
	end
	Lobby.slab(d, 'DaisTop', V(-X + 3.6, lo - 0.25, z0 + 0.6), V(X - 3.6, lo, z1 - 0.6), deck)
	Lobby.slab(d, 'DaisTop', V(-X + 0.6, lo - 0.25, z0 + 3.6), V(X - 0.6, lo, z1 - 0.6), deck)
	-- the full-width front step (0.8 risers; a pale nosing on each and on the deck's front edge)
	local n = math.floor(lo / 0.8 + 0.5)
	local fd = D.Front / (n - 1)
	for k = 1, n - 1 do
		local za, y = z0 - (n - k) * fd, k * 0.8
		Lobby.slab(d, 'DaisStep', V(-X + 3, 0, za), V(X - 3, y, z0), k % 2 == 1 and deck or K.panelLight, true)
		d:box('DaisNosing', V(-X + 3, y - 0.1, za - 0.1), V(X - 3, y + 0.02, za + 0.4), trim, M.SmoothPlastic)
	end
	d:box('DaisNosing', V(-X + 3, lo - 0.1, z0 - 0.1), V(X - 3, lo + 0.02, z0 + 0.5), trim, M.SmoothPlastic)
	-- a stair at each end (the reference's), along the side in front of the backdrop: the same 0.8 risers stepping out,
	-- each a darker studded body under a pale studded tread, a pale nosing on its outer edge
	local sw, sa, sb = D.StairW, z0 + 3.6, z1 - D.Back - 1.2
	local tw = sw / (n - 1)
	for _, sx in { -1, 1 } do
		local function xs(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		for k = 1, n - 1 do
			local y = k * 0.8
			local xa, xb = xs(X, X + (n - k) * tw)
			Lobby.slab(d, 'DaisStair', V(xa, 0, sa), V(xb, y - 0.2, sb), rim, true)
			Lobby.slab(d, 'DaisStairTread', V(xa, y - 0.2, sa + 0.3), V(xb, y, sb - 0.3), deck)
			local na, nb = xs(X + (n - k) * tw - 0.4, X + (n - k) * tw + 0.1)
			d:box('DaisNosing', V(na, y - 0.1, sa), V(nb, y + 0.02, sb), trim, M.SmoothPlastic)
		end
	end
	-- (P3, the user: "remove the stand behind it, just make it in a good text, just like in the references say boxes, and
	-- exclusive") no backdrop, posts or header any more: big floating words over the boxes, the references' Montserrat Black
	-- with a thick outline: BOXES over the Cash boxes, EXCLUSIVE over the Robux ones.
	local list = Lobby.shoeBoxList()
	local nCash = 0
	for _, b in list do if not b.Robux then nCash += 1 end end
	local split = D.First - (nCash - 0.5) * D.Pitch -- (x between the last Cash box and the first Robux box)
	local textY = D.ArtTop + 10.6
	-- (B30, bible gap 5 / M6: the giant words outshouted everything; now the size of the reference's area titles over its
	-- egg row and training, ref_W23.0_egg_row.jpg / ref_W05.5_train_mouth_TRAIN_sign.jpg)
	local function words(text, cx, w, col, ink)
		local a = Lobby.title(d, V(cx, textY, D.RowZ), w * 0.62, 2.85, text, nil, col, 150)
		local gui = a.WorldLabel
		a.Name = 'Words_' .. text
		-- (always readable from the spawn, like the gate signs, but shrinking as you walk up to the row, so standing at the
		-- boxes they don't fill the screen: LabelFade's near shrink)
		gui:SetAttribute('FadeNear', 300)
		gui:SetAttribute('FadeFar', 320)
		gui:SetAttribute('FadeShrink', 40)
		gui:SetAttribute('FadeShrinkMin', 0.4)
		for _, tl in gui:GetChildren() do
			local st = tl:FindFirstChildOfClass('UIStroke')
			if st then st.Color, st.Thickness = ink, 4 end
		end
	end
	-- (B30, the user: "how the boxes look", ref_W23.0 / ref_W14.5's "PETS" board) no floating words over the row any more:
	-- the area's title hangs over it on chains from the roof girder (Lobby.boxesBoard)
	local _ = { split, words }
	Lobby.boxesBoard(d, V(0, D.ArtTop + 10.4, D.RowZ))
	-- a checkered shelf (2 tones, 2.4-stud checks) under the row of pads
	local sx = X - 1
	local rz = D.RowZ
	local cs = 2.4
	d:box('ShelfStrip', V(-sx, lo, rz - 1.5 * cs), V(sx, lo + 0.05, rz + 1.5 * cs), K.shelfLight, M.SmoothPlastic).CastShadow = false
	for i = 0, math.floor(2 * sx / cs) - 1 do
		for j = 0, 2 do
			if (i + j) % 2 == 0 then
				local xa = -sx + cs * i
				d:box('ShelfTile', V(xa, lo, rz - 1.5 * cs + cs * j), V(math.min(xa + cs, sx), lo + 0.1, rz - 0.5 * cs + cs * j), K.shelfDark, M.SmoothPlastic).CastShadow = false
			end
		end
	end
	-- the boxes, in dais order along the row
	local BoxModels = Lobby.sharedModule('Models', 'BoxModels')
	local cfg = Lobby.sharedModule('Config', 'Shoes')
	local holder, folder = L:group('ShoeBoxes')
	folder:AddTag('HoodShoeBoxes')
	for i, b in list do
		local id = b.Id
		local col = b.Color or C(200, 200, 210)
		local premium = b.Robux ~= nil
		-- (B30, ref_W23.0: the reference's premium egg stands in the middle, bigger, among the others) the most expensive
		-- Robux box takes the middle slot on a wider gold-ringed pedestal; the others keep their order round it
		local top1 = b == Lobby.premiumBox(list)
		local base = V(Lobby.boxSlotX(list, i), lo + 0.1, rz)
		-- turned partly toward the spine, so the plates read from the walkway
		local face = CFrame.lookAt(base, base + V(-base.X * 0.45, 0, -62))
		local bc, model = holder:group('ShoeBox_' .. id)
		model:SetAttribute('BoxId', id)
		model:SetAttribute('Order', i)
		model:SetAttribute('Price', b.Price) -- (nil on a Robux box: it never opens for Cash)
		model:SetAttribute('World', b.World)
		if premium then
			model:SetAttribute('RobuxPrice', b.RobuxPrice)
			model:SetAttribute('Exclusive', true)
		end
		-- (it streams in whole, so Shoes.client finds the box, its point and its label together)
		pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
		local best = 0
		for _, sid in (b.Shoes or {}) do
			local sh = cfg and cfg.ById and cfg.ById[sid]
			if sh and type(sh.Bonus) == 'number' then best = math.max(best, sh.Bonus) end
		end
		local pr = top1 and D.TopR or D.PadR
		if top1 then
			-- the premium box's raised plinth (the reference's x100 egg on its higher step), the pad and the box on it
			local h = D.Plinth
			studs(bc:at(face):box('PremiumPlinth', V(-pr - 0.3, 0, -pr - 0.3), V(pr + 0.3, h, pr + 0.3), C(150, 154, 172), M.Plastic), true)
			bc:at(face):box('PremiumPlinthBand', V(-pr - 0.35, h - 0.22, -pr - 0.35), V(pr + 0.35, h - 0.08, pr + 0.35), Lobby.Colors.gold, M.SmoothPlastic)
			face = face * CFrame.new(0, h, 0)
		end
		local top = Lobby.boxPad(bc:at(face), col, best > 0 and ('+' .. compact(best) .. '%') or ('#' .. i), top1, pr)
		local slot = face * CFrame.new(0, top, 0)
		Lobby.Slots['ShoeBox' .. i] = Lobby.DaisAt * slot
		-- the box at character height: its art's top ArtTop over the deck (PremiumTop on a Robux box, TopArt the middle one)
		local tall = (top1 and D.TopArt or (premium and D.PremiumTop or D.ArtTop)) - top - 0.1
		local sc = tall / 6.2
		local height = tall
		if BoxModels then
			-- (B31) through ItemMeshes (MESH's Box_<Id>), the BoxModels chest as the fallback
			local wide = top1 and D.TopWide or D.Fit
			local scale = nil
			local okP, box = pcall(Lobby.itemMeshes().place, 'Box_' .. id, bc:world(slot), V(wide, tall, wide), model, function(cf2)
				local b2, sc2 = Lobby.sizedBox(BoxModels, id, tall, cf2, wide)
				scale = sc2
				return b2
			end)
			if not okP then box = nil end
			scale = scale or (box and tall / 6.2) or nil
			if box then
				sc = scale
				box.Name = 'Box_' .. id
				box.Parent = model
				box:SetAttribute('ArtTop', tall)
				-- its theme particles and glow, and its floating pieces moving (client-side idle motion)
				if BoxModels.fx then pcall(BoxModels.fx, box) end
				if BoxModels.animate then pcall(BoxModels.animate, box) end
				-- the label floats just over the box's highest visible part
				local yTop = Lobby.topOf(box)
				if yTop then height = yTop - bc:world(slot).Position.Y end
			else
				warn('[Lobby] BoxModels.build(' .. id .. ') failed: ' .. tostring(scale))
			end
		end
		if not model:FindFirstChild('Box_' .. id) then
			-- a placeholder box in the box's colour when BoxModels is missing
			local ph = bc:at(slot):box('Box_' .. id, V(-2.2, 0, -1.7), V(2.2, 3.1, 1.7), col, M.SmoothPlastic)
			decor(ph)
		end
		-- a solid block round the box's tub (its own parts don't collide), the prompt point on the pad's front
		local coll = bc:at(slot):box('BoxCollider', V(-2.3 * sc, 0, -1.8 * sc), V(2.3 * sc, 3.2 * sc, 1.8 * sc), P.white, M.SmoothPlastic)
		coll.Transparency, coll.CanQuery, coll.CanTouch, coll.CastShadow = 1, false, false, false
		local point = ghost(bc:at(face):box('BoxPoint_' .. id, V(-0.6, 2.3, -pr - 1.2), V(0.6, 3.7, -pr), P.white))
		point.CastShadow = false
		Lobby.boxLabel(bc, id, (slot * CFrame.new(0, height + 0.5 + (premium and Lobby.BoxLabelRobuxH or Lobby.BoxLabelH) / 2, 0)).Position, b, col)
	end
	Lobby.Slots.ShoeBoxes = Lobby.DaisAt * CFrame.new(0, 0, z0 - D.Front)
	Lobby.SlotSizes.ShoeBoxes = V(2 * (X + D.StairW), D.HeadY + D.HeadH, z1 - z0 + D.Front)
	return d
end

---------------------------------------------------------------------------------------------- signs
-- The reference's hall signs: a white-framed pale board with a faint diamond lattice and the name in big white
-- letters with a dark grey outline. cf faces the hall.
function Lobby.hallSign(c, name, cf, w, ht, text)
	local K = Lobby.Colors
	c:part(name .. 'Frame', V(w + 2.4, ht + 2.4, 0.6), cf * CFrame.new(0, 0, 0.35), K.signFrame, M.SmoothPlastic)
	c:part(name .. 'Rim', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, 0.05), P.white, M.SmoothPlastic)
	local b, g = Lobby.board(c, name, cf * CFrame.new(0, 0, -0.2), w, ht, K.sign, { { 'Title', text, P.white, FONT.title, 0.18, 0.64, C(90, 96, 120), 5 } }, 10)
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, true, 0.88, C(150, 156, 186))
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, false, 0.88, C(150, 156, 186))
	local _ = g
	return b
end
function Lobby.signs(L)
	local W, S, Z = Lobby.W, Lobby.S, Lobby.CrossZ
	local s = L:group('HallSigns')
	-- the plaza's title on the west wall's middle pillar at the aisle's end (on the slim upper part of the pillar, over
	-- the kink); the dais carries its own SHOE BOXES board on its backdrop (Lobby.shoeDais)
	-- (B30, ref_W05.5_train_mouth_TRAIN_sign.jpg / bible 2.10 "signs are text in the air": the plaza's title floats over
	-- the head lane's alcove at the aisle's end, read from the spawn down the aisle)
	local _ = S
	local tt = Lobby.title(s, V(-W + 6, Lobby.Apse.h + 7.4, Z), 19, 5.2, 'TRAIN', nil, P.white, 220)
	tt.Name = 'TrainTitle'
	for _, l in tt.WorldLabel:GetChildren() do
		local st = l:IsA('TextLabel') and l:FindFirstChildOfClass('UIStroke')
		if st then st.Color, st.Thickness = C(20, 24, 44), 5 end
	end
	-- the reference's big floating CLONE MACHINE words: the ARMORY's title, over its back block on the east wall's middle
	-- pillar's axis (clear of the guns and nameplates from the floor and the treads; Lobby.ArmoryTitle follows the stand)
	local t = Lobby.armoryTitle()
	Lobby.title(s, t.Pos, t.W, t.H, 'ARMORY', 'Better guns, more Power per shot!', nil, 160)
	return s
end

---------------------------------------------------------------------------------------------- north bays
-- The video's "cliff foot" by the exit: what it shows on boards there (update, codes, like the game, the group
-- chest) stands in the north wall's two corner bays either side of the exit bay, seen from the spawn and all down the
-- spine. Each object keeps its own small floating label; the two notices are framed boards on the wall over them
-- (physical boards, like the reference's info boards by its exit), high enough to stay clear of the lanes' and the
-- guns' floating labels seen from the spawn: east, a CODES terminal under "UPDATE SOON!"; west, the group reward
-- chest under "LIKE THE GAME!". ComingSoon prompts where no system exists yet.
-- Floating outlined words (the reference's big area titles and the video's notices): rows { name, text, colour,
-- height share }, a thick dark outline.
function Lobby.notice(c, pos, w, h, rows, maxDist)
	local list, y = {}, 0
	for _, r in rows do
		table.insert(list, { r[1], r[2], r[3], r.font or FONT.title, y, r[4] })
		y += r[4] + 0.02
	end
	local a = billboard(c, pos, w, h, list)
	a.WorldLabel.MaxDistance = maxDist or 160
	for _, t in a.WorldLabel:GetChildren() do
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then s.Color, s.Thickness = Lobby.Ink, 3.5 end
		if t:IsA('TextLabel') and not t:GetAttribute('ShadowOf') then Lobby.fill(t, t.TextColor3) end -- (B30: the gradient fill)
	end
	return a
end
-- Words read when you walk up (B30, ref_W01.0 vs ref_W29.5: the reference's GROUP REWARD / CODES / product words are not
-- readable from the spawn, only on the way to the gate): a fade band from the camera, and the lanes' declutter group, so
-- a nearer label wins over one it covers.
function Lobby.nearWords(gui, near, far)
	gui:SetAttribute('FadeNear', near)
	gui:SetAttribute('FadeFar', far)
	gui:SetAttribute('FadeGroup', 'Lanes')
	return gui
end
-- (Oct 27, release fixes: the open item "product labels too big when passing on the walk to the gate") a product's or a
-- Robux box pad's words: 6.4 x 2.5 studs (were 7.6 x 3.0), whole from 26 studs, gone by 36, and inside 22 studs they
-- shrink with the distance down to half, so walking past one at arm's length never fills the screen (LabelFade's
-- FadeShrink, in studs: the same on a phone and a PC).
Lobby.ProductWordsW, Lobby.ProductWordsH = 6.4, 2.5
function Lobby.productWords(gui)
	Lobby.nearWords(gui, 26, 36)
	gui:SetAttribute('FadeShrink', 22)
	gui:SetAttribute('FadeShrinkMin', 0.5)
	return gui
end
-- The codes terminal (c: on the floor, front -Z): a dark studded foot, a navy body with a yellow stripe, a sloped
-- top carrying a glowing screen, a keypad ledge; a floating CODES label and a ComingSoon prompt.
function Lobby.codeTerminal(c)
	local K = Lobby.Colors
	local g, model = c:group('CodesTerminal')
	local body = C(40, 52, 96)
	-- (rule 29) the user's Chest_Codes when imported (1.3x), else our terminal
	local tall = 5.2
	if not Lobby.designed(g, 'Chest_Codes', 1.3) then
		tall = 6.4
		Lobby.slab(g, 'TerminalFoot', V(-2.4, 0, -2), V(2.4, 0.6, 2), C(60, 64, 84), true)
		g:box('TerminalBody', V(-2, 0.6, -1.4), V(2, 5, 1.6), body, M.SmoothPlastic)
		g:box('TerminalStripe', V(-2.05, 1.6, -1.45), V(2.05, 2.1, 1.65), C(250, 196, 32), M.SmoothPlastic)
		g:box('TerminalLedge', V(-2, 3.4, -2.2), V(2, 3.8, -1.4), K.trim, M.SmoothPlastic)
		g:wedge('TerminalTop', V(4, 1.6, 3), CFrame.new(0, 5.8, 0.1), body:Lerp(P.white, 0.12), M.SmoothPlastic)
		decor(g:part('TerminalScreen', V(3.2, 0.1, 2.4), CFrame.new(0, 5.86, 0.07) * CFrame.Angles(-math.atan2(1.6, 3), 0, 0), C(70, 230, 255), M.Neon)).CastShadow = false
	end
	local hit = ghost(g:box('TerminalHit', V(-2.5, 0, -4), V(2.5, 6, 2), P.white))
	Lobby.prompt(hit, 'Redeem', 'Codes', 10)
	local n = Lobby.notice(g, V(0, tall + 2.8, 0), 7, 2.4, { { 'Name', 'CODES', C(255, 214, 60), 0.58 }, { 'Soon', 'New code at 1K likes!', P.white, 0.38, font = FONT.title } }, 40)
	Lobby.nearWords(n.WorldLabel, 34, 46)
	return model
end
-- A framed notice board on a wall (cf on the wall face, -Z into the hall): the hall signs' grey frame and white rim round
-- a pale board, a big coloured title over a line of detail, both outlined dark.
function Lobby.noticeBoard(c, name, cf, w, ht, title, color, detail)
	local K = Lobby.Colors
	c:part(name .. 'Frame', V(w + 2.4, ht + 2.4, 0.6), cf * CFrame.new(0, 0, -0.3), K.signFrame, M.SmoothPlastic)
	c:part(name .. 'Rim', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, -0.65), P.white, M.SmoothPlastic)
	Lobby.board(c, name, cf * CFrame.new(0, 0, -0.95), w, ht, K.sign, {
		{ 'Title', title, color, FONT.title, 0.08, 0.52, C(30, 34, 56), 4 },
		{ 'Detail', detail, C(46, 52, 80), FONT.title, 0.64, 0.28 },
	}, 12)
end
function Lobby.northBays(L)
	local N, W, e = Lobby.N, Lobby.W, Lobby.ExitEdge
	local b = L:group('NorthBays')
	local x = (e + W - 6) / 2 -- the middle of the corner bay
	local function wall(sx) return CFrame.lookAt(V(sx * x, Lobby.WinY, N), V(sx * x, Lobby.WinY, N + 1)) end
	-- east bay: the World Boss stand (Lobby.worldBoss) under the update notice
	Lobby.noticeBoard(b, 'UpdateBoard', wall(1), 13, 7, 'UPDATE SOON!', C(255, 150, 60), 'Shoe Boxes and new stages')
	-- west bay: the like-the-game notice on the wall
	Lobby.noticeBoard(b, 'LikeBoard', wall(-1), 13, 7, 'LIKE THE GAME!', C(80, 200, 100), 'Likes unlock new codes')
	-- (B30, bible M8, ref_W29.5_stage1_gate_group_chest.jpg / ref_W03.5_spawn_crossroads_codes_chest.jpg: the group chest and
	-- the CODES sign stand on the spine's west side by the gate, turned to the spine and the spawn)
	local g = Lobby.Plan.Group
	Lobby.rewardChest(b:at(CFrame.lookAt(V(g.chest[1], 0.06, g.chest[2]), V(0, 0.06, g.look))))
	Lobby.codeTerminal(b:at(CFrame.lookAt(V(g.codes[1], 0.06, g.codes[2]), V(0, 0.06, g.look))))
	return b
end

---------------------------------------------------------------------------------------------- hood props
-- Hood life off the walkways (BRIEF4/15): a drinks corner in the exit bay east of the door, the FURTHEST kiosk's
-- partner across the doorway (a vending machine against the recess wall, a bin beside it). Chunky boxes, 2-3 tones
-- each.
Lobby.DrinksX = 33.25 -- the exit bay's east half (between the door jamb and the bay frame)
function Lobby.hoodProps(L)
	local g = L:group('HoodProps')
	local x, z = Lobby.DrinksX + 1.5, Lobby.N + 1.7
	local d = g:at(CFrame.lookAt(V(x, 0, z), V(x, 0, z + 10)))
	Lobby.slab(d, 'VendingKick', V(-2.2, 0, -1.6), V(2.2, 0.6, 1.4), C(40, 42, 52), true)
	d:box('VendingBody', V(-2.1, 0.6, -1.5), V(2.1, 8, 1.4), C(210, 40, 52), M.SmoothPlastic)
	d:box('VendingCap', V(-2.2, 8, -1.6), V(2.2, 8.5, 1.5), C(170, 28, 40), M.SmoothPlastic)
	local glass = d:box('VendingGlass', V(-1.8, 2.4, -1.6), V(0.6, 7.4, -1.45), C(170, 220, 245), M.SmoothPlastic)
	local sg = surface(glass, Enum.NormalId.Front, 10)
	for k, col in { C(250, 190, 40), C(60, 170, 240), C(90, 210, 100), C(240, 90, 150) } do
		local f = Instance.new('Frame')
		f.BorderSizePixel, f.BackgroundColor3 = 0, col
		f.Position, f.Size = UDim2.fromScale(0.08, 0.06 + (k - 1) * 0.24), UDim2.fromScale(0.84, 0.13)
		f.Parent = sg
	end
	d:box('VendingPanel', V(0.8, 3.4, -1.58), V(1.8, 6.6, -1.45), C(44, 46, 58), M.SmoothPlastic)
	decor(d:box('VendingSlot', V(1.05, 5.4, -1.62), V(1.55, 6.2, -1.56), C(120, 255, 160), M.Neon)).CastShadow = false
	d:box('VendingTray', V(-1.8, 1.0, -1.62), V(0.6, 1.9, -1.45), C(30, 30, 36), M.SmoothPlastic)
	line(surface(d:box('VendingTop', V(-1.9, 7.5, -1.62), V(1.9, 7.95, -1.5), P.white, M.SmoothPlastic), Enum.NormalId.Front, 30), 'Brand', 'ICE COLD', C(210, 40, 52), FONT.title, 0.05, 0.9, nil)
	local bin = d:at(CFrame.new(3.6, 0, -0.6))
	bin:post('BinBody', 1.1, 2.6, V(0, 0, 0), C(60, 120, 80), M.SmoothPlastic)
	bin:post('BinBand', 1.15, 0.3, V(0, 1.9, 0), C(40, 90, 60), M.SmoothPlastic)
	bin:post('BinLid', 1.2, 0.3, V(0, 2.6, 0), C(44, 46, 58), M.SmoothPlastic)
	return g
end

-- Crates on a pallet (c on the floor): the kit's pallet, two crates side by side, a smaller one on top when tall.
function Lobby.crateStack(c, tall)
	pallet(c, CFrame.new())
	crate(c, CFrame.new(-1.0, 0.8, 0) * CFrame.Angles(0, 0.08, 0), 2)
	crate(c, CFrame.new(1.05, 0.8, 0.1) * CFrame.Angles(0, -0.1, 0), 1.8)
	if tall then crate(c, CFrame.new(-0.8, 2.8, 0) * CFrame.Angles(0, 0.3, 0), 1.6) end
end

---------------------------------------------------------------------------------------------- sign text
-- (B30, the user: "make it like the references ... the fonts, how the boxes look"; ref_W23.0_egg_row.jpg,
-- ref_W13.5_south_row_labels_zoom.jpg, ref_product_pads.webp) The references' in-world words: Montserrat Black (FONT.title)
-- with a thick near-black outline and, on the words that matter, a vertical gradient fill. Lobby.Grad holds the fills
-- (top colour, bottom colour); Lobby.Rainbow the special line's horizontal rainbow.
Lobby.Ink = C(11, 11, 20) -- (TextStyle.Ink #0B0B14)
Lobby.Grad = {
	white = { C(255, 255, 255), C(217, 222, 232) }, -- "4x Power", names (B31: TextStyle presets, the UI's own)
	lime = { C(232, 255, 74), C(78, 224, 32) }, -- "ONLY <price>", prices (TextStyle price E8FF4A -> 4EE020)
	gold = { C(255, 242, 122), C(255, 168, 26) }, -- "25x Power": gold to orange (TextStyle gold)
	cyan = { C(184, 246, 255), C(47, 180, 255) }, -- (TextStyle cyan)
	pink = { C(255, 170, 230), C(222, 64, 206) }, -- "Ninja World": pink to magenta
	blue = { C(196, 238, 255), C(96, 176, 255) }, -- "10x Power": light blue
	salmon = { C(246, 140, 140), C(232, 106, 106) }, -- "Locked" (#E86A6A)
	green = { C(200, 255, 106), C(60, 208, 42) }, -- "Unlocked" (TextStyle green)
	red = { C(255, 154, 138), C(255, 58, 58) }, -- "MOST OP!" (TextStyle red)
}
Lobby.Rainbow = { C(255, 70, 70), C(255, 160, 40), C(255, 230, 60), C(90, 230, 90), C(60, 200, 255), C(120, 110, 255), C(230, 90, 230) }
-- A gradient fill (a { top, bottom } pair, or a colour: its pale top to itself) on a text label; 'rainbow' runs across.
function Lobby.fill(label, grad)
	local g = Instance.new('UIGradient')
	if grad == 'rainbow' then
		local keys = {}
		for k, col in Lobby.Rainbow do table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#Lobby.Rainbow - 1), col)) end
		g.Color = ColorSequence.new(keys)
		g.Rotation = 0
	else
		local pair = typeof(grad) == 'Color3' and { grad:Lerp(P.white, 0.45), grad } or grad
		g.Color = ColorSequence.new(pair[1], pair[2])
		g.Rotation = 90 -- (top to bottom)
	end
	g.Parent = label
	label.TextColor3 = P.white -- (the gradient multiplies the fill: white lets it show true)
	return g
end
-- One floating word stack (a WorldLabel BillboardGui on a ghost anchor at pos): rows { name, text, share of the height,
-- fill (a Lobby.Grad pair, a colour, or 'rainbow'), outline px }, top to bottom. Returns the anchor and the labels by name.
function Lobby.signWords(c, pos, w, h, rows, maxDist)
	local a = ghost(c:part('WordsAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = maxDist or 70
	g.LightInfluence = 0
	g.Parent = a
	local y, labels = 0, {}
	for _, r in rows do
		local l = line(g, r[1], r[2], P.white, FONT.title, y, r[3], Lobby.Ink, r[5] or 3.5)
		l.Position, l.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, r[3])
		Lobby.fill(l, r[4] or Lobby.Grad.white)
		labels[r[1]] = l
		y += r[3]
	end
	shadowAll(g)
	return a, labels, g
end

---------------------------------------------------------------------------------------------- product pads
-- (B30, the user: "make the gamepass 3d signs look better have vfx"; the reference: ref_product_pads.webp, the RPG on its
-- yellow pad and the Red Hyperlaser on its red one) Every pass sells on a pad by a walk:
--   Pad    a low glowing studded square in the pass's colour: a darker studded foot, the body, a pale lip and a glowing
--          top inset, a soft haze rising off it (a few slow coloured puffs) and a PointLight in its colour
--   Item   the pass's 3D thing (LobbyModels, BoxKit) floating over it, turning slowly and bobbing (WorldMotion: one shared
--          loop on the client, no per-pad script)
--   Words  the references' stack: the price on top in lime ("<Robux mark> 199"), the name big in the pass's colour, the
--          benefit in white (Lobby.signWords); readable from ~30 studs, gone further off (LabelFade, the lanes' group)
-- Contract (HoodClient/Lobby, unchanged): a Model PassBoard_<Key> tagged HoodPassBoard (attribute Pass = the Products key),
-- holding a TextLabel Price (attribute Price; the client writes the mark and the price, or OWNED) and a PassPoint part with
-- the ProximityPrompt PassPrompt (attribute Pass). Names and prices come from Config/Products, so the pad and the Store
-- agree. Honest words only: no stock counters, no claims the item doesn't keep.
-- VFX budget per pad: haze 2.5/s x ~2.4 s + rim aura 4 x 3.2/s x 1 s + sparkles 3/s x ~1.1 s, about 22 live particles, one light.
Lobby.PassTones = {
	-- { pad colour, LobbyModels item, item scale }
	DoubleRep = { C(46, 140, 255), 'StandDumbbell', 1.7 }, DoubleCash = { C(150, 82, 236), 'StandCash', 1.7 },
	VIP = { C(255, 186, 36), 'StandCrown', 1.7 }, AutoShoot = { C(236, 64, 64), 'StandCrosshair', 1.6 },
	Lucky = { C(40, 190, 110), 'StandClover', 1.7 }, TripleOpen = { C(255, 136, 40), 'StandBoxes', 1.7 },
	ExtraEquip = { C(236, 80, 170), 'StandSneaker', 1.7 }, AutoOpen = { C(40, 200, 230), 'StandGift', 1.7 }, -- (B31: LobbyModels has no key, bolt or magnet: the nearest real item)
	Speed2x = { C(255, 222, 60), 'StandSneaker', 1.7 }, AutoCollect = { C(214, 70, 214), 'StandCash', 1.7 },
	RangeVIP1 = { C(28, 186, 168), 'StandTarget', 1.25 }, RangeVIP2 = { C(255, 182, 24), 'StandTargetGold', 1.25 },
}
Lobby.PassStub = { -- (when Config/Products is missing)
	DoubleRep = { Title = '2x Power', Big = 'Every\nShot', Price = 199 }, AutoShoot = { Title = 'Auto Fight', Big = 'Hands\nFree', Price = 99 },
	VIP = { Title = 'VIP', Big = 'VIP', Price = 249 }, DoubleCash = { Title = '2x Cash', Big = 'Every\nStage', Price = 149 },
	Lucky = { Title = 'Lucky', Big = 'Better\nBoxes', Price = 129 }, TripleOpen = { Title = 'Triple Open', Big = '3 Boxes\nat Once', Price = 179 },
	ExtraEquip = { Title = '+1 Shoe Slot', Big = '4 Pairs\nOn', Price = 99 }, AutoOpen = { Title = 'Auto Open', Big = 'Open\nNon-Stop', Price = 249 },
	Speed2x = { Title = '2x Speed', Big = 'Run\nFaster', Price = 99 }, AutoCollect = { Title = 'Auto Collect', Big = 'Cash\nCollects Itself', Price = 149 },
}
Lobby.StandFoot, Lobby.StandTop = 4.0, 0.85 -- the pad's half side, its top (B31: 8 wide, the user's Pad_Base)
-- The rising haze over a pad (part: a flat ghost the pad's size on its top), in the pad's colour.
function Lobby.padHaze(part, tone, rate)
	-- (B31 PLAZA, critic 10: the haze read as fire) a low, slow, pale mist in the pad's colour: short rise, wide soft
	-- puffs, little light of its own (daylight kills additive clouds anyway)
	Lobby.fx(part, 'PadHaze', 'mist', {
		Rate = rate or 2, Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(0.5, 1.0),
		SpreadAngle = Vector2.new(14, 14), EmissionDirection = Enum.NormalId.Top, Acceleration = V(0, 0.2, 0), Drag = 0.6,
		Size = Lobby.seq({ { 0, 2.2 }, { 0.5, 3.2 }, { 1, 3.8 } }), Transparency = Lobby.seq({ { 0, 1 }, { 0.25, 0.74 }, { 0.7, 0.84 }, { 1, 1 } }),
		Color = ColorSequence.new(tone:Lerp(P.white, 0.55), tone:Lerp(P.white, 0.3)), LightEmission = 0.15, ZOffset = -1,
	})
	local l = Instance.new('PointLight')
	l.Name = 'PadLight'
	l.Color, l.Brightness, l.Range, l.Shadows = tone, 1.2, 11, false
	l.Parent = part
end
-- (B30 rule 24, ref_product_pads: the pad's light rises off its rim as a soft coloured curtain about a third of the pad's
-- side tall, brightest at the rim.) One upright soft-glow emitter per edge; ~3 live quads per edge, 12 per pad.
function Lobby.padAura(c, tone, half, top)
	local lum = 0.299 * tone.R + 0.587 * tone.G + 0.114 * tone.B
	local base = 0.6 + math.max(0, lum - 0.55) -- (pale tones stack to white: start them fainter; B31: fainter overall, no fire)
	local w = 0.3
	for _, e in { { V(-half, top, -half), V(half, top + 0.1, -half + w) }, { V(-half, top, half - w), V(half, top + 0.1, half) },
		{ V(-half, top, -half + w), V(-half + w, top + 0.1, half - w) }, { V(half - w, top, -half + w), V(half, top + 0.1, half - w) } } do
		local strip = ghost(c:box('PadAuraEdge', e[1], e[2], P.white))
		strip.CastShadow = false
		Lobby.fx(strip, 'PadAura', 'softglow', {
			Rate = 3.2 * half / 3, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(1.0, 1.6),
			SpreadAngle = Vector2.new(3, 3), EmissionDirection = Enum.NormalId.Top, Acceleration = V(0, 0.5, 0), Drag = 0.8,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rotation = NumberRange.new(0, 0),
			Size = Lobby.seq({ { 0, 1.2 }, { 0.5, 1.6 }, { 1, 1.3 } }), Squash = Lobby.seq({ { 0, 0.5 }, { 1, 0.9 } }),
			Transparency = Lobby.seq({ { 0, 1 }, { 0.2, base }, { 0.6, base + 0.2 }, { 1, 1 } }),
			Color = ColorSequence.new(tone:Lerp(P.white, 0.35), tone), LightEmission = 0.4, ZOffset = 0.2,
		})
	end
end
-- The square pad (c: its centre on the floor, front -Z) in colour tone; returns its top's height.
function Lobby.pedestal(c, tone, half)
	half = half or Lobby.StandFoot
	local deep, lit = tone:Lerp(C(14, 16, 40), 0.4), tone
	studs(c:box('PadFoot', V(-half - 0.25, 0, -half - 0.25), V(half + 0.25, 0.3, half + 0.25), deep, M.Plastic), true)
	studs(c:box('Pad', V(-half, 0.3, -half), V(half, 0.72, half), lit, M.Plastic), true)
	local top = Lobby.StandTop
	local w = 0.45
	for _, e in { { V(-half, 0.72, -half), V(half, top, -half + w) }, { V(-half, 0.72, half - w), V(half, top, half) },
		{ V(-half, 0.72, -half + w), V(-half + w, top, half - w) }, { V(half - w, 0.72, -half + w), V(half, top, half - w) } } do
		c:box('PadLip', e[1], e[2], lit:Lerp(P.white, 0.45), M.SmoothPlastic)
	end
	local glow = decor(c:box('PadGlow', V(-half + w, 0.72, -half + w), V(half - w, top - 0.03, half - w), lit:Lerp(P.white, 0.1), M.Neon)) -- (B31: 10 % to white, the pad keeps its colour)
	glow.CastShadow = false
	Lobby.padFX(c, tone, half, top)
	return top
end
-- A pad's effects over its top (whichever pad: ours or the user's Pad_Base): the rising haze and its light, the rim aura.
function Lobby.padFX(c, tone, half, top)
	local hz = ghost(c:box('PadHazeBox', V(-half + 0.6, top, -half + 0.6), V(half - 0.6, top + 0.1, half - 0.6), P.white))
	hz.CastShadow = false
	Lobby.padHaze(hz, tone)
	Lobby.padAura(c, tone, half, top)
end
-- A LobbyModels item turning over a point (c: the item's centre), or a plain placeholder block.
function Lobby.standItem(c, id, scale)
	local LobbyModels = Lobby.sharedModule('Models', 'LobbyModels')
	local g, model = c:group('Item')
	local built = false
	if LobbyModels and LobbyModels.build then
		local ok, m = pcall(LobbyModels.build, id, scale or 1)
		if ok and m then
			for _, p in m:GetDescendants() do
				if p:IsA('BasePart') then p.CFrame = V2.Origin * c.cf * p.CFrame end
			end
			m.Name = id
			m.Parent = model
			built = true
		end
	end
	if not built then g:box('ItemBlock', V(-1.4, -1.4, -1.4), V(1.4, 1.4, 1.4), P.white, M.SmoothPlastic) end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then decor(p) end
	end
	Lobby.motion(model, c.cf, 40, 0.3, 2.6)
	return model
end
-- Sparkles round a floating thing (a few a second, small, in its colour).
function Lobby.sparkles(g, y, tone, r)
	r = r or 2.2
	local box = ghost(g:box('SparkleBox', V(-r, y - 2, -r), V(r, y + 2, r), P.white))
	box.CastShadow = false
	local sp = Instance.new('ParticleEmitter')
	sp.Name = 'StandSparkles'
	sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sp:SetAttribute('PreviewTexture', 'sparkle')
	sp.Color = ColorSequence.new(P.white, tone:Lerp(P.white, 0.3))
	sp.LightEmission, sp.LightInfluence = 1, 0
	sp.Rate = 3
	sp.Lifetime = NumberRange.new(0.8, 1.4)
	sp.Speed = NumberRange.new(0.4, 1.2)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = Lobby.seq({ { 0, 0 }, { 0.35, 0.4 }, { 1, 0 } })
	sp.Transparency = Lobby.seq({ { 0, 0.1 }, { 1, 1 } })
	sp.Parent = box
end
-- (B31 PLAZA, critic 4-6, rules 27-28) The showcased item: ItemMeshes' mesh when imported (MESH: Pad_<Key>, Box_<Id>),
-- else the Part build, fitted so its largest side is `size`, its bottom centre at c, turning 40 deg/s and bobbing 0.3
-- about its own middle (ref_product_pads). Returns the model and its height.
Lobby.ItemSize = 5
function Lobby.showcase(c, meshId, size, build, spin)
	local holder, model = c:group('Item')
	local IM = Lobby.itemMeshes()
	local ok, m = pcall(IM.place, meshId, c:world(CFrame.new()), size, model, function(cf2, size2, parent)
		local built = build and build()
		if not built then return nil end
		Lobby.fitModel(built, cf2, typeof(size2) == 'Vector3' and math.max(size2.X, size2.Y, size2.Z) or size2)
		built.Parent = parent
		return built
	end)
	if not ok then warn('[Lobby] ' .. meshId .. ': ' .. tostring(m)) end
	if not model:FindFirstChildWhichIsA('BasePart', true) then holder:box('ItemBlock', V(-1.4, 0, -1.4), V(1.4, 2.8, 1.4), P.white, M.SmoothPlastic) end
	for _, p in model:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	local lo, hi = Lobby.boundsOf(model)
	Lobby.motion(model, V2.Origin:Inverse() * CFrame.new((lo + hi) / 2), spin or 40, 0.3, 2.6)
	model:SetAttribute('ItemId', meshId)
	return model, hi.Y - lo.Y
end
-- A product's Part build (LobbyModels; Auto Fight is a toy gun, GunModels' Uzi turned side-on, not a target disc).
function Lobby.passItem(key, look)
	if key == 'AutoShoot' then
		local Guns = Lobby.sharedModule('Models', 'GunModels')
		local ok, gun = pcall(function() return Guns.build('Uzi', 1) end)
		if ok and gun then
			for _, p in gun:GetDescendants() do if p:IsA('BasePart') then p.CFrame = CFrame.Angles(0, math.pi / 2, 0) * p.CFrame end end
			return gun
		end
	end
	local LobbyModels = Lobby.sharedModule('Models', 'LobbyModels')
	local ok, m = pcall(function() return LobbyModels.build(look[2], 1) end)
	return ok and m or nil
end
-- One bright star glint over a showcased item every ~3.5 s (rule 28's shine; far under one flash a second).
function Lobby.shine(g, y, tone)
	local box = ghost(g:box('ShineBox', V(-1.2, y - 1, -1.2), V(1.2, y + 1.6, 1.2), P.white))
	box.CastShadow = false
	local e = Lobby.fx(box, 'PadShine', 'sparkle', {
		Rate = 0.28, Lifetime = NumberRange.new(0.55, 0.7), Speed = NumberRange.new(0, 0), RotSpeed = NumberRange.new(-60, 60),
		Size = Lobby.seq({ { 0, 0 }, { 0.4, 3.2 }, { 1, 0 } }), Transparency = Lobby.seq({ { 0, 0.05 }, { 1, 0.3 } }),
		Color = ColorSequence.new(P.white, tone:Lerp(P.white, 0.6)), LightEmission = 1, Brightness = 2.5, ZOffset = 1.5,
	})
	return e
end
-- An oval tag on a pad's front, leaning back (ref_product_pads' "x200" egg tag): a true value only ('2x', '+1', 'x3').
function Lobby.padTag(g, text, z, y)
	local cf = CFrame.new(0, y or 0.62, z) * CFrame.Angles(math.rad(-18), 0, 0)
	local pill = g:part('PadTag', V(3.0, 1.1, 0.24), cf, P.white, M.SmoothPlastic)
	g:part('PadTagRim', V(3.3, 1.35, 0.16), cf * CFrame.new(0, 0, 0.12), C(60, 62, 80), M.SmoothPlastic)
	local tl = line(surface(pill, Enum.NormalId.Front, 40), 'Tag', text, P.white, FONT.title, 0.06, 0.88, Lobby.Ink, 2)
	Lobby.fill(tl, 'rainbow')
	return pill
end
function Lobby.productStand(c, key, opts)
	opts = opts or {}
	local products = Lobby.sharedModule('Config', 'Products')
	local entry = products and products.ByKey and products.ByKey[key] or Lobby.PassStub[key] or { Title = key, Price = 0 }
	local look = Lobby.PassTones[key] or { C(46, 140, 255), 'StandGift', 1 }
	local tone = look[1]
	local g, model = c:group('PassBoard_' .. key)
	model:SetAttribute('Pass', key)
	model:AddTag('HoodPassBoard')
	-- Streams in as one piece, so a client that sees the board also sees its prompt and price (HoodClient/Lobby).
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	local half = opts.half or Lobby.StandFoot
	-- (rule 29) the user's Pad_Base when imported (8 wide, its glowing rim), else our studded pad in the pass's colour
	local top
	if Lobby.designed(g, 'Pad_Base', 2 * half / 8.12) then
		top = 1.39 * 2 * half / 8.12
		Lobby.padFX(g, tone, half, top)
	else
		top = Lobby.pedestal(g, tone, half)
	end
	local foot = top + 0.9 -- (the item floats ~1 stud over the glowing top)
	local _, tall = Lobby.showcase(g:at(CFrame.new(0, foot, 0)), 'Pad_' .. key, Lobby.ItemSize, function() return Lobby.passItem(key, look) end)
	local midY = foot + tall / 2
	Lobby.sparkles(g, midY, tone)
	Lobby.shine(g, midY, tone)
	-- (the user's prizes carry their own 2x / VIP / AUTO blocks; our Part prizes get the true value on a tag)
	if type(entry.Sticker) == 'string' and entry.Sticker ~= '' and not Lobby.hasDesign('Pad_' .. key) then Lobby.padTag(g, entry.Sticker, -half - 0.35) end
	-- the words (rule 28, ref W01 "x2 Power / ONLY 3"): the headline big in gold-orange, "ONLY <Robux mark><price>" in lime
	local name = entry.Title or key
	local a, labels = Lobby.signWords(g, V(0, foot + tall + 2.0 + (opts.lift or 0), 0), Lobby.ProductWordsW, Lobby.ProductWordsH, {
		{ 'Title', name, 0.56, Lobby.Grad.gold, 4 },
		{ 'Price', 'ONLY ' .. RobuxText.fmt(entry.Price), 0.44, Lobby.Grad.lime, 3.5 },
	}, 36)
	labels.Price:SetAttribute('Price', entry.Price)
	Lobby.productWords(a.WorldLabel)
	-- the prompt, on a point at the pad's front
	local point = ghost(g:box('PassPoint', V(-1.2, 0.6, -half - 1.6), V(1.2, 3.4, -half), P.white))
	point.CastShadow = false
	local p = Instance.new('ProximityPrompt')
	p.Name = 'PassPrompt'
	p.ActionText = 'Buy'
	p.ObjectText = name
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute('Pass', key)
	p.Parent = point
	return model
end
-- (older names, kept for callers) a pass board is a product pad now
function Lobby.passBoard(c, key, opts) return Lobby.productStand(c, key, opts) end
function Lobby.laneBoard(c, key) return Lobby.productStand(c, key) end

---------------------------------------------------------------------------------------------- Robux box pads
-- (B30, the user: "bring out some of the boxes, make them for robux"; the reference's Secret Egg: a purple "?" cube
-- hovering over a round pink pad with a rainbow "x200" tag, "Secret Egg" in a pink gradient over a lime "99") The Robux
-- boxes stand out along the walks near the spawn too, each on a round glowing pad: the chest (BoxModels, the dais's own)
-- hovering and turning over it, a white pill tag on the pad's front with a rainbow "NEW" (they are this week's chests), its
-- name and price floating over it. A hold opens the Store at that box's card (HoodClient/Lobby: the prompt's OpenStore
-- attribute fires HoodStore.Open with the catalog key), where the box is bought as from the HUD. VFX as a product pad.
-- Lobby.Plan.BoxPads: { BoxModels id, Products key, x, z, the point it turns to, tag, colour, special line }.
function Lobby.boxPadStand(c, boxId, key, tone, tag, special, lift)
	local products = Lobby.sharedModule('Config', 'Products')
	local entry = products and products.ByKey and products.ByKey[key] or { Title = boxId, Price = 0 }
	local g, model = c:group('BoxPad_' .. boxId)
	model:SetAttribute('Product', key)
	local deep = tone:Lerp(C(14, 16, 40), 0.4)
	local padTop = 0.9
	if Lobby.designed(g, 'Pad_Base', 1) then -- (rule 29: the user's Pad_Base, as under every Robux prize)
		padTop = 1.39
	else
		studs(g:part('BoxPadFoot', V(0.3, 8, 8), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), deep, M.Plastic, Enum.PartType.Cylinder))
		studs(g:part('BoxPadDrum', V(0.45, 7.2, 7.2), CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.pi / 2), tone, M.Plastic, Enum.PartType.Cylinder))
		g:part('BoxPadLip', V(0.14, 7.4, 7.4), CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), tone:Lerp(P.white, 0.5), M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(g:part('BoxPadGlow', V(0.08, 6, 6), CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2), tone:Lerp(P.white, 0.1), M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
	local hz = ghost(g:box('PadHazeBox', V(-2.4, padTop, -2.4), V(2.4, padTop + 0.1, 2.4), P.white))
	hz.CastShadow = false
	Lobby.padHaze(hz, tone, 2)
	-- the pill tag on the pad's front, leaning back, its word in a rainbow (special: the true line, '3 PAIRS')
	Lobby.padTag(g, special or tag or 'NEW', -4.35)
	-- the chest hovering over the pad, turning and bobbing (B31: 5 studs, ItemMeshes' Box_<Id> or BoxModels' chest)
	local foot = padTop + 1.0
	local BoxModels = Lobby.sharedModule('Models', 'BoxModels')
	local box, tall = Lobby.showcase(g:at(CFrame.new(0, foot, 0)), 'Box_' .. boxId, Lobby.ItemSize, function()
		local ok, m = pcall(BoxModels.build, boxId, 1, CFrame.new())
		return ok and m or nil
	end, 30)
	box.Name = 'Box_' .. boxId
	local midY = foot + tall / 2
	Lobby.sparkles(g, midY, tone, 2.6)
	Lobby.shine(g, midY, tone)
	-- the words: the name in the box's colour, "ONLY <Robux mark><price>" in lime under it
	local a = Lobby.signWords(g, V(0, foot + tall + 2.0 + (lift or 0), 0), Lobby.ProductWordsW + 0.8, Lobby.ProductWordsH, {
		{ 'Title', entry.Title or boxId, 0.56, { tone:Lerp(P.white, 0.6), tone:Lerp(P.white, 0.1) }, 4 },
		{ 'Price', 'ONLY ' .. RobuxText.fmt(entry.Price), 0.44, Lobby.Grad.lime, 3.5 },
	}, 36)
	Lobby.productWords(a.WorldLabel)
	-- the prompt: opens the Store at the box's card
	local point = ghost(g:box('BoxPadPoint', V(-1.2, 0.6, -5.6), V(1.2, 3.4, -4.1), P.white))
	point.CastShadow = false
	local p = Instance.new('ProximityPrompt')
	p.Name = 'BoxPadPrompt'
	p.ActionText = 'Buy'
	p.ObjectText = entry.Title or boxId
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute('OpenStore', key)
	p.Parent = point
	return model
end

---------------------------------------------------------------------------------------------- world boss stand
-- The World Boss countdown board's stand (B30): f4_finale's Finale.board builds the board itself (18 x 10.6, its centre
-- at Lobby.Slots.WorldBossBoard, its face toward the slot's -Z; HoodClient/WorldBoss writes NEXT IN m:ss / FIGHT NOW!).
-- The lobby gives it a frame in the map's studded kit, so it reads as a place, like the reference's World Boss panel
-- (refs29 §6: the orange WORLD BOSS header, the boss name in gold, the big timer, JOIN): two studded posts in the board's
-- deep orange on dark plinths with a hazard band, a dark back plate behind the board, a studded header beam with a
-- hazard-striped face over it, an orange warning lamp on each post and the boss's skull bobbing on a little plinth
-- over the beam. c: the stand's front centre on the floor, its face toward -Z; returns the board's slot (in c's frame).
Lobby.BossBoardY = 8.6 -- the board's centre over the floor
function Lobby.worldBossStand(c)
	local g, model = c:group('WorldBossStand')
	local orange, deep, dark, slate = C(216, 72, 40), C(150, 44, 26), C(40, 42, 54), C(62, 66, 84)
	local y, hw = Lobby.BossBoardY, 9 -- the board's centre height and half width
	local px = hw + 1.6 -- the posts' centres
	local beam0, beam1 = y + 6.1, y + 8.3
	for _, sx in { -1, 1 } do
		local x = sx * px
		studs(g:box('BossPlinth', V(x - 1.8, 0, -1.6), V(x + 1.8, 1.3, 1.9), dark, M.Plastic), true)
		g:box('BossPlinthLip', V(x - 1.95, 1.3, -1.75), V(x + 1.95, 1.48, 2.05), Lobby.Colors.trim, M.SmoothPlastic)
		studs(g:box('BossPost', V(x - 1.2, 1.48, -1.0), V(x + 1.2, beam0, 1.3), deep, M.Plastic), true)
		-- the post's lit face plate, inset, and a hazard band near the foot
		studs(g:box('BossPostFace', V(x - 0.85, 2.0, -1.12), V(x + 0.85, beam0 - 0.6, -1.0), orange, M.Plastic))
		local band = g:box('BossHazard', V(x - 1.26, 2.6, -1.06), V(x + 1.26, 3.8, 1.36), C(250, 196, 32), M.SmoothPlastic)
		Lobby.stripes(band, Enum.NormalId.Front, 2.52, 1.2, 0.9, 0.45, true, 0, C(30, 30, 36))
		-- the warning lamp on top of the post: a dark collar, an orange glowing block, a dark lid
		g:box('BossLampCollar', V(x - 0.9, beam1, -0.7), V(x + 0.9, beam1 + 0.4, 1.0), dark, M.SmoothPlastic)
		decor(g:box('BossLamp', V(x - 0.7, beam1 + 0.4, -0.5), V(x + 0.7, beam1 + 1.6, 0.8), C(255, 130, 40), M.Neon)).CastShadow = false
		g:box('BossLampLid', V(x - 0.85, beam1 + 1.6, -0.65), V(x + 0.85, beam1 + 1.85, 0.95), dark, M.SmoothPlastic)
	end
	-- the back plate behind the board (the board's frame is z -0.8..0 in its own frame) and the header beam over it
	g:box('BossBack', V(-hw - 0.4, y - 5.6, 0), V(hw + 0.4, beam0, 0.7), slate, M.SmoothPlastic)
	studs(g:box('BossBeam', V(-px - 1.4, beam0, -1.1), V(px + 1.4, beam1, 1.4), deep, M.Plastic), true)
	local face = g:box('BossBeamFace', V(-px - 1.0, beam0 + 0.3, -1.22), V(px + 1.0, beam1 - 0.3, -1.1), C(250, 196, 32), M.SmoothPlastic)
	Lobby.stripes(face, Enum.NormalId.Front, 2 * px + 2, beam1 - beam0 - 0.6, 1.4, 0.7, true, 0, C(30, 30, 36))
	g:box('BossBeamCap', V(-px - 1.6, beam1, -1.3), V(px + 1.6, beam1 + 0.3, 1.6), Lobby.Colors.trim, M.SmoothPlastic)
	-- the skull on its plinth over the beam's middle, bobbing (no spin: it watches the hall)
	studs(g:box('BossSkullPlinth', V(-1.6, beam1 + 0.3, -1.2), V(1.6, beam1 + 1.2, 1.4), dark, M.Plastic), true)
	local skull = Lobby.standItem(g:at(CFrame.new(0, beam1 + 3.0, 0.1)), 'StandSkull', 0.9)
	skull:SetAttribute('Spin', nil)
	Lobby.Slots.WorldBossStand = c.cf
	return CFrame.new(0, y, -0.02), model
end

---------------------------------------------------------------------------------------------- group reward
-- The group reward (P5: claimed in the Daily Rewards window, with the daily reward): the reference's GROUP REWARD chest
-- (refs29 §10 / img29/12c: a red-and-gold chest on a yellow ring by the spine, "GROUP REWARD / Join the group!" floating
-- over it with a gift). A hold on its prompt opens the Daily Rewards window (HoodClient/Lobby: the prompt's OpenDaily
-- attribute fires HoodHUD.OpenDaily), where the group reward is claimed. c: on the floor, front -Z.
function Lobby.rewardChest(c)
	local K = Lobby.Colors
	local g, model = c:group('GroupRewardChest')
	local red, gold, deepGold = C(214, 40, 52), K.gold, K.gold:Lerp(P.black, 0.3)
	-- (rule 29) the user's Chest_GroupReward when imported (1.3x: 6.2 wide), else our chest on its ring and plinth
	local tall = 5.2
	if not Lobby.designed(g, 'Chest_GroupReward', 1.3) then
		tall = 9
		-- the yellow ring on the floor round it (a glowing band, four bars, on a dark studded pad)
		studs(g:box('ChestPad', V(-4.6, 0, -4.2), V(4.6, 0.3, 4.2), C(54, 58, 78), M.Plastic), true)
		for _, e in { { V(-4.3, 0.3, -3.9), V(4.3, 0.42, -3.4) }, { V(-4.3, 0.3, 3.4), V(4.3, 0.42, 3.9) }, { V(-4.3, 0.3, -3.4), V(-3.8, 0.42, 3.4) }, { V(3.8, 0.3, -3.4), V(4.3, 0.42, 3.4) } } do
			decor(g:box('ChestRing', e[1], e[2], C(255, 214, 40), M.Neon)).CastShadow = false
		end
		Lobby.slab(g, 'ChestPlinth', V(-3.4, 0.3, -2.6), V(3.4, 1.4, 2.6), C(70, 74, 98), true)
		g:box('ChestPlinthLip', V(-3.6, 1.4, -2.8), V(3.6, 1.62, 2.8), K.trim, M.SmoothPlastic)
		studs(g:box('ChestBody', V(-2.8, 1.62, -1.9), V(2.8, 4.2, 1.9), red, M.Plastic), true)
		g:box('ChestLid', V(-2.95, 4.2, -2.05), V(2.95, 5.3, 2.05), red:Lerp(P.white, 0.12), M.SmoothPlastic)
		studs(g:box('ChestLidCap', V(-2.6, 5.3, -1.6), V(2.6, 5.9, 1.6), red:Lerp(P.white, 0.2), M.Plastic))
		for _, sx in { -1, 1 } do g:box('ChestBand', V(sx * 1.7 - 0.35, 1.62, -2.12), V(sx * 1.7 + 0.35, 6.0, 2.12), gold, M.SmoothPlastic) end
		g:box('ChestRim', V(-3.02, 4.1, -2.1), V(3.02, 4.35, 2.1), deepGold, M.SmoothPlastic)
		g:box('ChestLock', V(-0.65, 3.2, -2.3), V(0.65, 4.7, -1.9), gold, M.SmoothPlastic)
		g:box('ChestKeyhole', V(-0.18, 3.5, -2.36), V(0.18, 4.1, -2.28), C(60, 40, 10), M.SmoothPlastic)
		-- the present floating over the lid (the reference's gift icon), bobbing and turning
		Lobby.standItem(g:at(CFrame.new(0, 8.0, 0)), 'StandGift', 0.75)
	end
	local hit = ghost(g:box('ChestHit', V(-3, 0, -4.5), V(3, 6, 3), P.white))
	local p = Lobby.prompt(hit, 'Claim', 'Group Reward', 10)
	p:SetAttribute('ComingSoon', nil)
	p:SetAttribute('OpenDaily', true)
	p.Name = 'GroupRewardPrompt'
	local n = Lobby.notice(g, V(0, tall + 2.8, 0), 10, 2.8, { { 'Name', 'GROUP REWARD', C(255, 214, 60), 0.58 }, { 'Soon', 'Join the group!', P.white, 0.38, font = FONT.title } }, 40)
	Lobby.nearWords(n.WorldLabel, 34, 46)
	return model
end

---------------------------------------------------------------------------------------------- decor
-- LOBBY5 r2 (CRITIC3: "the hall got emptier ... fill the freed floor with 2-5-prop decor clusters"): the reference's
-- bushes on its grass, in the hall's toy style. Each cluster stands on one of the tiled panels (the grass), off every
-- walk: planters with blocky bushes, "+1" banners on poles, and behind the shoe stage a stockroom of shoe cartons.
-- Every prop is 2-3 tones, base + body + cap. (LOBBY6: the benches are gone; Lobby.bench stays for later.)
Lobby.Decor = {
	-- the north strip by the armory, the south strip between the armory and the boards' corner, the plaza's north strip,
	-- the shoe stage's back: { x, z, yaw (degrees), props } in the map frame; props: 'planter' | 'banner' | 'cartons'
	-- with an offset { kind, dx, dz, yaw, colour index }
	-- (B30) behind the shoe dais, its stockroom of shoe cartons with a crate stack each side (no planters: "its a warehouse")
	{ -11, 113, 0, { { 'cartons', 0, 0, 0 }, { 'crates', -5.6, 0.6, 8 } } },
	{ 11, 113, 0, { { 'cartons', 0, 0, 180 }, { 'crates', 5.6, 0.6, -8 } } },
}
Lobby.DecorColors = { C(255, 120, 60), C(70, 170, 255), C(255, 200, 50) } -- planters' and banners' bright tones
-- A planter (c on the floor at its centre): a studded box in col on a dark foot with a pale rim, dark soil, a blocky
-- bush of three studded greens.
function Lobby.planter(c, col)
	c:box('PlanterFoot', V(-1.45, 0, -1.45), V(1.45, 0.25, 1.45), col:Lerp(C(20, 22, 40), 0.55), M.SmoothPlastic)
	studs(c:box('Planter', V(-1.3, 0.25, -1.3), V(1.3, 1.35, 1.3), col, M.Plastic), true)
	c:box('PlanterRim', V(-1.45, 1.35, -1.45), V(1.45, 1.55, 1.45), Lobby.Colors.trim, M.SmoothPlastic)
	c:box('PlanterSoil', V(-1.1, 1.35, -1.1), V(1.1, 1.6, 1.1), C(96, 64, 44), M.SmoothPlastic)
	studs(c:box('Bush', V(-1.15, 1.6, -1.05), V(1.05, 3.1, 1.15), C(76, 186, 72), M.Plastic), true)
	studs(c:box('Bush', V(-0.75, 3.1, -0.65), V(0.85, 4.1, 0.85), C(104, 214, 88), M.Plastic), true)
	studs(c:box('Bush', V(0.3, 2.3, -1.35), V(1.3, 3.3, -0.3), C(62, 160, 64), M.Plastic), true)
end
-- A park bench facing -Z (c on the floor at its centre): two dark legs, two wooden seat slats, two back slats, arm rests.
function Lobby.bench(c)
	local wood, dark = C(196, 132, 76), C(54, 58, 74)
	for _, sx in { -1.7, 1.7 } do
		c:box('BenchLeg', V(sx - 0.18, 0, -0.75), V(sx + 0.18, 1.25, 0.65), dark, M.SmoothPlastic)
		c:box('BenchArm', V(sx - 0.22, 1.9, -0.75), V(sx + 0.22, 2.1, 0.55), dark, M.SmoothPlastic)
		c:box('BenchArmPost', V(sx - 0.15, 1.25, -0.65), V(sx + 0.15, 1.9, -0.4), dark, M.SmoothPlastic)
	end
	for k, z in { -0.5, 0.15 } do
		c:box('BenchSeat', V(-2.1, 1.25, z - 0.3), V(2.1, 1.45, z + 0.3), k == 1 and wood or wood:Lerp(P.black, 0.1), M.SmoothPlastic)
	end
	for k, y in { 1.95, 2.55 } do
		c:part('BenchBack', V(4.2, 0.4, 0.18), CFrame.new(0, y, 0.62) * CFrame.Angles(math.rad(-10), 0, 0), k == 1 and wood or wood:Lerp(P.black, 0.1), M.SmoothPlastic)
	end
	c:box('BenchBackPost', V(-1.86, 1.25, 0.5), V(-1.54, 2.85, 0.72), dark, M.SmoothPlastic)
	c:box('BenchBackPost', V(1.54, 1.25, 0.5), V(1.86, 2.85, 0.72), dark, M.SmoothPlastic)
end
-- A "+1" banner on a pole (c on the floor at the pole's foot, the banner facing -Z and +Z): a dark foot, a grey pole,
-- a crossbar, a hanging banner in col with a white "+1" on both faces and a gold tip.
function Lobby.banner(c, col)
	c:box('BannerFoot', V(-0.7, 0, -0.7), V(0.7, 0.4, 0.7), C(54, 58, 74), M.SmoothPlastic)
	c:box('BannerPole', V(-0.18, 0.4, -0.18), V(0.18, 8.2, 0.18), C(176, 180, 200), M.SmoothPlastic)
	c:box('BannerBar', V(-0.15, 7.8, -0.15), V(2.9, 8.05, 0.15), C(176, 180, 200), M.SmoothPlastic)
	decor(c:part('BannerTip', V(0.5, 0.5, 0.5), CFrame.new(0, 8.45, 0) * CFrame.Angles(0, math.pi / 4, 0), Lobby.Colors.gold, M.Neon)).CastShadow = false
	local b = c:box('Banner', V(0.25, 4.2, -0.08), V(2.75, 7.8, 0.08), col, M.SmoothPlastic)
	c:box('BannerHem', V(0.25, 4.0, -0.1), V(2.75, 4.25, 0.1), col:Lerp(P.white, 0.4), M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		line(surface(b, face, 30), 'Tag', '+1', P.white, FONT.title, 0.12, 0.7, col:Lerp(P.black, 0.5), 3)
	end
end
-- Shoe cartons stacked by the stage (c on the floor at the stack's centre): seven boxes in the boxes' colours, each a
-- body and a white lid, in two piles and one leaning.
function Lobby.cartons(c)
	local cols = { C(232, 70, 56), C(255, 110, 190), C(70, 200, 255), C(170, 80, 255), C(255, 196, 40), C(80, 210, 110), C(255, 140, 50) }
	local spots = { { -1.6, 0, 0, 5 }, { -1.5, 1, 0.1, -4 }, { -1.7, 2, -0.05, 8 }, { 0.6, 0, 0.2, -6 }, { 0.7, 1, 0.1, 3 }, { 2.6, 0, -0.3, 30 }, { 0.6, 2, 0.15, -10 } }
	for k, sp in spots do
		local cf = CFrame.new(sp[1], sp[2] * 0.95 + 0.42, sp[3]) * CFrame.Angles(0, math.rad(sp[4]), 0)
		c:part('Carton', V(2.0, 0.84, 1.3), cf, cols[k], M.SmoothPlastic)
		c:part('CartonLid', V(2.1, 0.22, 1.4), cf * CFrame.new(0, 0.38, 0), P.white, M.SmoothPlastic)
	end
end
function Lobby.decor(L)
	local g = L:group('Decor')
	for _, cl in Lobby.Decor do
		local base = g:at(CFrame.new(cl[1], 0.06, cl[2]) * CFrame.Angles(0, math.rad(cl[3]), 0))
		for _, pr in cl[4] do
			local c = base:at(CFrame.new(pr[2], 0, pr[3]) * CFrame.Angles(0, math.rad(pr[4] or 0), 0))
			local col = Lobby.DecorColors[pr[5] or 1]
			if pr[1] == 'planter' then Lobby.planter(c, col)
			elseif pr[1] == 'bench' then Lobby.bench(c)
			elseif pr[1] == 'banner' then Lobby.banner(c, col)
			elseif pr[1] == 'cartons' then Lobby.cartons(c)
			elseif pr[1] == 'crates' then Lobby.crateStack(c, true) end
		end
	end
	return g
end

---------------------------------------------------------------------------------------------- corners
-- ref_lobby.png's south corners: the WORLD 2 portal in the SW, the leaderboards in the SE, each on its own field
-- either side of the dais (8.5 studs of walkway to it), level with the dais's front step behind the south walk and
-- running back to the walls: a tiled floor panel with the inset cyan line (Lobby.panelRects), the reference's grass
-- round its portal and its boards. The portal stands turned to the spawn with its back to the corner between two
-- clusters of glowing crystals (the reference's); the three boards stand in a V opening to the hall behind a gold
-- trophy on a plinth (the reference's statue there).
Lobby.CornerX = 37 -- the fields' inner edges (x +-), 8.5 studs past the dais's stairs
function Lobby.cornerRect(sx)
	local x0, x1 = sx * Lobby.CornerX, sx * Lobby.W
	return math.min(x0, x1), math.max(x0, x1), Lobby.SouthZ - 1.2, Lobby.S
end
-- A cluster of blocky crystals (c on the floor at the cluster's centre): tall pointed shafts leaning out in a fan,
-- each a body in col with a paler glowing core and a wedge tip, on a dark rocky foot.
function Lobby.crystals(c, col, seed, size)
	local r = Random.new(seed)
	size = size or 1
	local g = c:group('Crystals')
	g:box('CrystalRock', V(-1.6 * size, 0, -1.3 * size), V(1.6 * size, 0.6 * size, 1.3 * size), C(70, 74, 92), M.SmoothPlastic)
	g:box('CrystalRock', V(-1.1 * size, 0, -1.8 * size), V(1.2 * size, 0.45 * size, 1.6 * size), C(84, 88, 108), M.SmoothPlastic)
	for k = 1, 5 do
		local a = (k - 3) * 0.42 + r:NextNumber(-0.12, 0.12)
		local h = (k == 3 and 4.6 or r:NextNumber(2.2, 3.6)) * size
		local w = (k == 3 and 1.15 or r:NextNumber(0.7, 0.95)) * size
		local lean = CFrame.new((k - 3) * 0.55 * size, 0.3 * size, r:NextNumber(-0.5, 0.5) * size) * CFrame.Angles(r:NextNumber(-0.25, 0.25), 0, -a)
		local body = g:part('Crystal', V(w, h, w), lean * CFrame.new(0, h / 2, 0), col, M.SmoothPlastic)
		body.Transparency = 0.12
		decor(g:part('CrystalCore', V(w * 0.45, h * 0.8, w * 0.45), lean * CFrame.new(0, h * 0.45, 0), col:Lerp(P.white, 0.55), M.Neon)).CastShadow = false
		g:wedge('CrystalTip', V(w, w * 1.1, w / 2), lean * CFrame.new(0, h + w * 0.55, -w / 4), col:Lerp(P.white, 0.25), M.SmoothPlastic)
		g:wedge('CrystalTip', V(w, w * 1.1, w / 2), lean * CFrame.new(0, h + w * 0.55, w / 4) * CFrame.Angles(0, math.pi, 0), col:Lerp(P.white, 0.25), M.SmoothPlastic)
	end
	return g
end
function Lobby.corners(L)
	local h = 0.06
	-- (B30, the user's placement note, ref_W23.0 / ref_W14.5: the portal and the boards beside the box row, at either end of
	-- the box walk) WORLD 2 west of the dais, turned to the spawn, a crystal cluster at each side of it (blue on the left,
	-- red on the right, as in the reference) and its floating title in the reference's pink gradient
	local w2 = Lobby.Plan.World2
	local g = L:group('World2Corner')
	local at = V(w2.x, h, w2.z)
	local cf = CFrame.lookAt(at, V(w2.look.X, h, w2.look.Z))
	Lobby.world2(g, cf)
	Lobby.Slots.World2 = cf
	-- (local +X is on the left of a player facing the portal)
	-- (beside the arch, a little back: clear of the box walk's end and of the Lucky pad)
	Lobby.crystals(g:at(cf * CFrame.new(10.6, 0, 1.2) * CFrame.Angles(0, -0.5, 0)), C(70, 190, 255), 5, 1.15)
	Lobby.crystals(g:at(cf * CFrame.new(-10.6, 0, 1.2) * CFrame.Angles(0, 0.5, 0)), C(255, 80, 110), 6, 1.0)
	local a = Lobby.signWords(g, (cf * CFrame.new(0, 23.5, -1)).Position, 14, 4.2, {
		{ 'Title', 'World 2', 0.6, Lobby.Grad.pink, 4.5 },
		{ 'Soon', 'COMING SOON!', 0.4, Lobby.Grad.white, 3.5 },
	}, 200)
	a.WorldLabel:SetAttribute('FadeNear', 110)
	a.WorldLabel:SetAttribute('FadeFar', 150)
	-- the leaderboards east of the dais in a V opening to the walk: REBIRTHS in the middle at the back, POWER and CASH
	-- turned in, small titles over them (ref_V2-07.0 / ref_W23.0)
	local g2 = L:group('BoardCorner')
	Lobby.leaderboards(g2, V(Lobby.Plan.Boards.x, h, Lobby.Plan.Boards.z))
	-- the winners' podium beside the east walk, facing it
	local pa = V(Lobby.Plan.Podium[1], h, Lobby.Plan.Podium[2])
	Lobby.podium(L:group('PodiumCorner'):at(CFrame.lookAt(pa, pa - V(0, 0, 1))))
end

---------------------------------------------------------------------------------------------- leaderboards
-- The reference's boards (user_35), three in a V on the SE corner field: each a grey studded frame on two posts that
-- run down to dark feet, an X joint at every corner of the frame, a dark navy screen with the rows, a grey header
-- plate with the board's name, a dark cap on each post; over each a big floating title in its colour (TOP POWER
-- orange, TOP REBIRTHS red, TOP CASH green), like "TOP 50 POWER".
-- `live` names the model LobbyService writes into (a TextLabel named TextLabel): PowerLeaderboard (top Power),
-- ServerLeaderboard (rebirths, then Power: the rebirth board), CashLeaderboard (top Cash).
-- cf: the board's foot centre on the floor, front -Z.
Lobby.Boards = {
	-- (left to right for a player facing them, i.e. facing south: POWER at the east end, CASH at the west end; x and z
	-- from the field's centre)
	{ x = 11.6, z = 3.2, yaw = 22, lift = 0, name = 'POWER', title = 'Top Power', color = C(255, 166, 40), live = 'PowerLeaderboard', main = 'POWER', extra = 'REBIRTHS' },
	{ x = 0, z = 7.2, yaw = 0, lift = 1, name = 'REBIRTHS', title = 'Top Rebirth', color = C(255, 70, 70), live = 'ServerLeaderboard', main = 'REBIRTHS', extra = 'POWER' },
	{ x = -11.6, z = 3.2, yaw = -22, lift = 0, name = 'CASH', title = 'Top Cash', color = C(120, 226, 70), live = 'CashLeaderboard', main = 'CASH', extra = 'STAGE' },
}
Lobby.BoardW, Lobby.BoardH, Lobby.BoardY = 7.5, 12, 3.2 -- the screen's width, height and its foot's height
Lobby.BoardTilt = 16 -- (B30, ref_V2-07.0_leaderboards.jpg: the boards lean back a little, the feet stay flat)
function Lobby.leaderboard(L, cf, b)
	local base, model = L:at(cf):group(b.live)
	-- everything over the feet leans back about the feet's top edge (front -Z: +X rotation tips the top away)
	local root = base:at(CFrame.new(0, 0.8, 0) * CFrame.Angles(math.rad(Lobby.BoardTilt), 0, 0) * CFrame.new(0, -0.8, 0))
	-- (slate screens with pale rows, as the reference's, not navy)
	-- (B30 final, lead review: the reference's boards are light studded frames, slim, leaning back; no X legs)
	local grey, light, dark, navy, foot = C(186, 192, 210), C(214, 220, 234), C(138, 144, 166), C(72, 84, 116), C(112, 118, 140)
	local w, h, y0 = Lobby.BoardW, Lobby.BoardH, Lobby.BoardY
	local px = w / 2 + 0.65 -- the posts' centres
	local top = y0 + h -- the screen's top; the header plate sits over it
	local hy = top + 3.4 -- the frame's top
	local screen, ppS
	-- (rule 29) the user's Board_Leaderboard when imported (1.3x its 8.5 x 12.15 design: a red frame, a trophy plate, a dark
	-- screen 6.1 x 7.2 whose centre is 5.16 up): our screen part, carrying the rows LobbyService writes, lies on its face
	local kL = 1.3
	if Lobby.designed(base, 'Board_Leaderboard', kL, nil, true) then
		local sw, sh, cy = 6.1 * kL - 0.2, 7.2 * kL - 0.2, 5.16 * kL
		hy = 12.15 * kL
		screen = base:box('BoardScreen', V(-sw / 2, cy - sh / 2, -1.72 * kL - 0.1), V(sw / 2, cy + sh / 2, -1.72 * kL), navy, M.SmoothPlastic) -- (just proud of the design's front)
		w, h = sw + 0.6, sh + 0.6
		ppS = math.ceil(440 / sh) -- (the ten rows need ~440 px of canvas)
	else
		-- the posts (studded on every side), running down to dark feet and up to dark caps
		for _, sx in { -1, 1 } do
			local x = sx * px
			Lobby.slab(root, 'BoardPost', V(x - 0.65, 0.45, -0.65), V(x + 0.65, hy, 0.65), grey, true) -- (sunk into the foot: the lean lifts its front edge)
			base:box('BoardFoot', V(x - 1.0, 0, -1.2), V(x + 1.0, 0.8, 1.2), foot, M.SmoothPlastic)
			root:box('BoardCap', V(x - 0.85, hy, -0.85), V(x + 0.85, hy + 0.5, 0.85), foot, M.SmoothPlastic)
		end
		-- the rails under and over the screen, and the header plate between the posts at the top
		Lobby.slab(root, 'BoardRail', V(-px, y0 - 0.9, -0.6), V(px, y0, 0.6), grey, true)
		Lobby.slab(root, 'BoardRail', V(-px, top, -0.6), V(px, top + 0.6, 0.6), grey, true)
		Lobby.slab(root, 'BoardHeader', V(-px + 0.65, top + 0.6, -0.6), V(px - 0.65, hy - 0.2, 0.6), light, true)
		local plate = root:box('BoardTitle', V(-px + 1.4, top + 1.1, -0.75), V(px - 1.4, hy - 0.7, -0.6), dark, M.SmoothPlastic)
		line(surface(plate, Enum.NormalId.Front, 24), 'Title', b.name, P.white, FONT.title, 0.1, 0.8, C(20, 24, 40), 2)
		-- the screen: a dark bezel, the navy face, pale row stripes behind the text LobbyService writes
		-- (brief 29, the user: "way too large letters and very vague, barely any stats"): small text like the reference's boards,
		-- ten rows of rank + name | main stat | second stat under a small column header, one row every 38 px of a 276 x 456 px
		-- canvas. LobbyService writes the three lists (TextLabel: "1  Name", Values: the main stat, Extra: the second) with
		-- RichText, one line per row, all three at the same size and line height so the rows line up.
		root:box('BoardBezel', V(-px + 0.65, y0, -0.5), V(px - 0.65, top, 0.5), dark, M.SmoothPlastic)
		screen = root:box('BoardScreen', V(-w / 2 + 0.3, y0 + 0.3, -0.62), V(w / 2 - 0.3, top - 0.3, 0.3), navy, M.SmoothPlastic)
		ppS = 40
	end
	local g = surface(screen, Enum.NormalId.Front, ppS)
	local CW, CH = (w - 0.6) * ppS, (h - 0.6) * ppS -- the canvas, px
	local ROW, ROW0, ROWS, SIZE = 38, 46, 10, 19
	for k = 0, ROWS - 1, 2 do
		local f = Instance.new('Frame')
		f.Name = 'Band'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = C(60, 76, 140)
		f.BackgroundTransparency = 0.6
		f.Position, f.Size = UDim2.fromScale(0.02, (ROW0 + k * ROW) / CH), UDim2.fromScale(0.96, ROW / CH)
		f.ZIndex = 0
		f.Parent = g
	end
	local function head(name, value, x, wd, align)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, 8 / CH), UDim2.fromScale(wd, 30 / CH)
		l.FontFace = FONT.title -- (B30: the references' boards are Montserrat Black too)
		l.TextSize, l.Text, l.TextColor3 = 11, value, C(150, 168, 214)
		l.TextXAlignment = align
		l.TextTransparency = 0
		l.Parent = g
		return l
	end
	local function col(name, x, wd, align, color)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, ROW0 / CH), UDim2.fromScale(wd, ROWS * ROW / CH)
		l.FontFace = FONT.title -- (B30: the references' boards are Montserrat Black too)
		l.TextSize, l.LineHeight = SIZE, ROW / (SIZE * 1.219) -- (Montserrat's line is 1.219 em)
		l.RichText, l.TextWrapped, l.TextYAlignment, l.TextXAlignment = true, false, Enum.TextYAlignment.Top, align
		l.TextColor3 = color
		local s = Instance.new('UIStroke')
		s.Color, s.Thickness, s.LineJoinMode = C(8, 12, 30), 2, Enum.LineJoinMode.Round
		s.Parent = l
		l.Parent = g
		return l
	end
	head('HeadName', 'PLAYER', 0.04, 0.42, Enum.TextXAlignment.Left)
	head('HeadMain', b.main, 0.44, 0.31, Enum.TextXAlignment.Right)
	head('HeadExtra', b.extra, 0.75, 0.23, Enum.TextXAlignment.Right)
	local names = col('TextLabel', 0.04, 0.42, Enum.TextXAlignment.Left, C(240, 244, 255))
	col('Values', 0.44, 0.34, Enum.TextXAlignment.Right, C(92, 200, 255))
	col('Extra', 0.76, 0.22, Enum.TextXAlignment.Right, C(190, 198, 226))
	names.Text = 'Be the first to train!'
	-- the floating title in the board's colour
	-- (B30, ref_V2-07.0: each title floats just over its own board, no wider than it, so the three never run together)
	-- (B30: a small title in the board's colour gradient, "Top Power", like the reference's)
	local a = Lobby.signWords(root, V(0, hy + 1.9, 0), 7.2, 1.9, { { 'Title', b.title, 1, { b.color:Lerp(P.white, 0.5), b.color }, 3.5 } }, 200)
	-- (LabelFade: seen across the hall like the reference's "TOP 50" titles, gone from the streets)
	a.WorldLabel:SetAttribute('FadeNear', 110)
	a.WorldLabel:SetAttribute('FadeFar', 150)
	return model
end
function Lobby.leaderboards(L, at)
	local g = L:group('Leaderboards')
	for k, b in Lobby.Boards do
		local cf = CFrame.new(at.X + b.x, at.Y, at.Z + b.z) * CFrame.Angles(0, math.rad(b.yaw), 0)
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(g, cf, b)
	end
	return g
end

---------------------------------------------------------------------------------------------- winners' podium
-- LOBBY6: the armory's south strip, between its ring and the south walk: the winners' podium (the old TOP PLAYERS
-- trophy grown into the reference's trophy stand, user_37): three studded blocks, 2 on the left, 1 in the middle and
-- highest, 3 on the right, each with its big number on the front and a cup on top (gold, silver, bronze; the gold one
-- under a turning star), a "TOP PLAYERS" plate on the base, "BE #1!" floating over it. Turned to the spine and the
-- spawn. c: the base's centre on the floor, its front -Z.
function Lobby.cup(c, col, s)
	local deep = col:Lerp(P.black, 0.3)
	c:box('CupFoot', V(-1.6 * s, 0, -1.6 * s), V(1.6 * s, 0.6 * s, 1.6 * s), deep, M.SmoothPlastic)
	c:box('CupFoot', V(-1.15 * s, 0.6 * s, -1.15 * s), V(1.15 * s, 1.0 * s, 1.15 * s), col, M.SmoothPlastic)
	c:post('CupStem', 0.45 * s, 1.6 * s, V(0, 1.0 * s, 0), col, M.SmoothPlastic)
	c:post('CupKnot', 0.75 * s, 0.45 * s, V(0, 1.6 * s, 0), deep, M.SmoothPlastic)
	c:post('CupBowl', 1.25 * s, 0.7 * s, V(0, 2.6 * s, 0), col, M.SmoothPlastic)
	c:post('CupBowl', 1.75 * s, 1.9 * s, V(0, 3.3 * s, 0), col, M.SmoothPlastic)
	c:post('CupRim', 1.95 * s, 0.35 * s, V(0, 5.2 * s, 0), deep, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		c:box('CupHandle', V(sx * 1.7 * s, 4.6 * s, -0.25 * s), V(sx * 2.7 * s, 4.95 * s, 0.25 * s), col, M.SmoothPlastic)
		c:box('CupHandle', V(sx * 2.35 * s, 3.1 * s, -0.25 * s), V(sx * 2.7 * s, 4.95 * s, 0.25 * s), col, M.SmoothPlastic)
		c:box('CupHandle', V(sx * 1.7 * s, 3.1 * s, -0.25 * s), V(sx * 2.7 * s, 3.45 * s, 0.25 * s), col, M.SmoothPlastic)
	end
end
function Lobby.podium(c)
	local K = Lobby.Colors
	local g, model = c:group('WinnersPodium')
	Lobby.slab(g, 'PodiumBase', V(-6.6, 0, -2.8), V(6.6, 0.5, 2.8), C(62, 66, 88), true)
	g:box('PodiumBaseLip', V(-6.8, 0.5, -3.0), V(6.8, 0.68, 3.0), K.trim, M.SmoothPlastic)
	local plate = g:box('PodiumPlate', V(-3.6, 0.08, -2.92), V(3.6, 0.46, -2.8), K.gold, M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 40), 'Title', 'TOP PLAYERS', C(90, 50, 0), FONT.title, 0.04, 0.92, nil)
	-- (local +X is the viewer's left: 2 on the left, 3 on the right)
	local steps = {
		{ 1, 0, 4.0, K.gold, C(255, 204, 48), 1.05 },
		{ 2, 4.1, 2.8, C(196, 204, 222), C(214, 222, 236), 0.85 },
		{ 3, -4.1, 2.0, C(214, 128, 64), C(205, 127, 50), 0.75 },
	}
	for _, st in steps do
		local n, x, h, trim, cupCol, cs = st[1], st[2], st[3], st[4], st[5], st[6]
		local body = Lobby.slab(g, 'PodiumStep', V(x - 2.0, 0.68, -2.1), V(x + 2.0, 0.68 + h, 2.1), C(214, 218, 240), true)
		g:box('PodiumStepTrim', V(x - 2.1, 0.68 + h - 0.35, -2.2), V(x + 2.1, 0.68 + h, 2.2), trim, M.SmoothPlastic)
		local face = g:box('PodiumNumber', V(x - 1.4, 0.9, -2.16), V(x + 1.4, 0.6 + h - 0.45, -2.1), C(40, 46, 84), M.SmoothPlastic)
		line(surface(face, Enum.NormalId.Front, 30), 'Number', tostring(n), trim:Lerp(P.white, 0.2), FONT.title, 0.04, 0.92, C(14, 16, 32), 3)
		local _ = body
		Lobby.cup(g:at(CFrame.new(x, 0.68 + h, 0)), cupCol, cs)
	end
	-- the star over the gold cup, turning slowly (WorldMotion.client)
	local star, starModel = g:at(CFrame.new(0, 0.68 + 4.0 + 6.6, 0)):group('PodiumStar')
	for _, a in { 0, 72, 144, 216, 288 } do
		decor(star:part('PodiumStar', V(0.55, 1.5, 0.4), CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(0, 0.6, 0), C(255, 230, 110), M.Neon)).CastShadow = false
	end
	Lobby.motion(starModel, star.cf, 40)
	-- (B30: no "BE #1!" words over it any more: they ran into the boards' floating titles behind it, and the reference's
	-- leaderboards have only their own titles)
	return model
end

---------------------------------------------------------------------------------------------- spawn & slots
-- The spawn point on the cross (StageService and SetActive use it), facing north up the spine to the Stage 1 door
-- (the video's rule: from the spawn you already see the next goal, gate 1's "STAGE 1 / Recommended Power", and the
-- locked gates beyond it down the street). No mark on the floor: you land on the walkway cross.
function Lobby.spawn(L)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.4, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = L.parent
	Lobby.Slots.Spawn = CFrame.new(SPAWN)
	-- (LOBBY5, BRIEF23: the FURTHEST STAGE pad and its kiosk are gone: a run starts at Stage 1 through the door; the exit
	-- bay west of the door keeps a hood corner, two drums on a pallet and a stack of tyres, the drinks corner's partner)
	local b = L:group('ExitBayWest')
	Lobby.standProps(b, 2, V(-36, 0, Lobby.N + 3.2))
	Lobby.standProps(b, 1, V(-29.5, 0, Lobby.N + 3.4))
end
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
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front } do line(surface(box, face, 10), 'Text', label, P.white, FONT.title, 0.2, 0.6, P.black, 2) end
	return holder
end
-- The ARMORY (LOBBY5, BRIEF23: ref_lobby.png's EVOLUTIONS 3 TIERS stand, "way better smaller"): the compact 3-tier
-- stand of code5/d3_armory.lua on its own island east of the spine, facing west to it across the cross arm (the arm's
-- walkway runs on to the island's front), a little north of the arm's axis so its front corner and first nameplates
-- show at the right of the spawn's view: island x Lobby.ArmoryX .. + Armory.Depth (22.2), z ArmoryZ +-
-- Armory.ApronHalf (15.8), a 4-stud walkway ring round it inside the east field's tiled panels (Lobby.panelRects).
-- (B30, bible §2.1: the gun stand closes the spawn's east arm 2-2.5 s out, facing west; ref_W17.0_gun_stand.jpg)
Lobby.ArmoryX = 25 -- the island's front edge (x): the east arm's end, 20 studs past the spine (B31 PLAZA: closer, bigger)
Lobby.ArmoryZ = Lobby.CrossZ -- the island's centre line: on the cross arm (lobby C's)
Lobby.ArmoryRing = 4 -- the walkway round the island, between it and the east field
Lobby.ArmoryAt = CFrame.lookAt(V(Lobby.ArmoryX, 0, Lobby.ArmoryZ), V(0, 0, Lobby.ArmoryZ))
-- The island's footprint in the map frame: x0, x1, z0, z1 (a stand-in size while d3_armory is missing).
function Lobby.armoryRect()
	local half = Armory and Armory.ApronHalf or 15.8
	local depth = Armory and Armory.Depth or 22.2
	return Lobby.ArmoryX, Lobby.ArmoryX + depth, Lobby.ArmoryZ - half, Lobby.ArmoryZ + half
end
-- the floating ARMORY title, over the stand's backdrop
function Lobby.armoryTitle()
	local x0, x1 = Lobby.armoryRect()
	local top = Armory and Armory.Top or 9.4
	-- (LOBBY6: raised over the HOOD CHAMP statue behind the stand, so from the spawn the plates, the champ and the title
	-- stack up clear of each other)
	return { Pos = V(x1 - 2, top + 16, Lobby.ArmoryZ), W = 22, H = 5 } -- (over the top row's nameplates)
end
function Lobby.armory(L)
	local x0, x1, z0, z1 = Lobby.armoryRect()
	local half = (z1 - z0) / 2
	Lobby.place(L, L.parent, 'Armory', Lobby.ArmoryAt, { X = 2 * half, Y = 10, Z0 = 0, Z1 = x1 - x0 }, 'ARMORY', C(255, 90, 160),
		Armory and function(c) Armory.build(c) end)
	-- (rule 29) the user's Stand_Guns, the outdoor gun shop, right behind the stepped stand: its striped awning crowns
	-- the top tier (the stand's ten slots stay the shop's counter: GunService and HoodClient/Armory read them)
	Lobby.designed(L:group('GunShop'):at(Lobby.ArmoryAt * CFrame.new(0, 0, x1 - x0 + 3.6)), 'Stand_Guns', 1.4, nil, true)
end


-- The back block's top, behind the stand's back wall (seen from the high cameras and from above; LOBBY3: it read as
-- the hall's biggest bare slab from the top): the armory's stockroom. Pallet racks against the east wall in the two
-- bays between the east pillars that stand on the block (blue uprights, orange beams, two shelves of boxes, ammo crates
-- and gun cases), and in the open middle a forklift parked by rows of crate pallets. All of it is low enough (under
-- the line from the spawn's eye over the back wall's top) to stay out of every floor view, off every walk.
function Lobby.rack(c, len, dep, seed)
	local r = Random.new(seed)
	local up, beam, deck = C(40, 110, 200), C(255, 140, 30), C(170, 140, 100)
	local box = { C(200, 150, 92), C(184, 132, 80), C(104, 118, 78), C(58, 62, 74) }
	local hh = { 0.3, 1.9 } -- the two shelves
	for _, x in { -len / 2, len / 2 } do
		for _, z in { -dep / 2, dep / 2 } do c:box('RackUpright', V(x - 0.25, 0, z - 0.25), V(x + 0.25, 3.7, z + 0.25), up, M.SmoothPlastic) end
	end
	for _, y in hh do
		for _, z in { -dep / 2, dep / 2 } do c:box('RackBeam', V(-len / 2, y, z - 0.2), V(len / 2, y + 0.35, z + 0.2), beam, M.SmoothPlastic) end
		c:box('RackDeck', V(-len / 2 + 0.25, y + 0.1, -dep / 2 + 0.2), V(len / 2 - 0.25, y + 0.3, dep / 2 - 0.2), deck, M.SmoothPlastic)
		local x = -len / 2 + 0.5
		while x < len / 2 - 1.2 do
			local w = math.min(len / 2 - 0.4 - x, r:NextNumber(1.2, 2.1))
			local hgt = r:NextNumber(0.9, 1.35)
			c:box('RackBox', V(x, y + 0.3, -dep / 2 + 0.35), V(x + w, y + 0.3 + hgt, dep / 2 - 0.35), box[r:NextInteger(1, #box)], M.SmoothPlastic)
			x += w + r:NextNumber(0.15, 0.5)
		end
	end
end
function Lobby.forklift(c)
	local yel, dark, fork = C(255, 196, 40), C(46, 48, 58), C(120, 124, 136)
	c:box('ForkliftBody', V(-1.5, 0.6, -1.6), V(1.5, 2.2, 2.2), yel, M.SmoothPlastic)
	c:box('ForkliftWeight', V(-1.5, 0.6, 2.2), V(1.5, 2.6, 2.9), dark, M.SmoothPlastic)
	c:box('ForkliftSeat', V(-0.8, 2.2, 0.6), V(0.8, 2.7, 1.8), dark, M.SmoothPlastic)
	for _, x in { -1.3, 1.3 } do c:box('ForkliftPost', V(x - 0.15, 2.2, -1.2), V(x + 0.15, 4.6, -0.9), dark, M.SmoothPlastic) end
	for _, x in { -1.3, 1.3 } do c:box('ForkliftPost', V(x - 0.15, 2.2, 2.0), V(x + 0.15, 4.6, 2.3), dark, M.SmoothPlastic) end
	c:box('ForkliftRoof', V(-1.5, 4.6, -1.3), V(1.5, 4.85, 2.4), yel, M.SmoothPlastic)
	c:box('ForkliftMast', V(-1.1, 0.3, -2.1), V(1.1, 4.2, -1.6), dark, M.SmoothPlastic)
	for _, x in { -0.75, 0.75 } do c:box('ForkliftFork', V(x - 0.2, 0.25, -4.6), V(x + 0.2, 0.45, -2.1), fork, M.SmoothPlastic) end
	for _, x in { -1.55, 1.55 } do
		for _, z in { -1.0, 2.0 } do c:part('ForkliftWheel', V(0.5, 1.2, 1.2), CFrame.new(x, 0.6, z), C(30, 30, 34), M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
end

---------------------------------------------------------------------------------------------- the plan
-- Where everything stands (map frame). Lobby.Plan.Stands: { Products key, x, z, yaw toward (x, z) }.
-- B30 (bible §2.1, sketch_soldier_lobby_topdown.png; the user: "place some around the map, not all bunched up"): one stand
-- per walk, where the reference sells:
--   the north spine's east side, between the spawn and the gate (ref_W28.0_spine_north_products.jpg: the RPG pad, the
--   Secret Egg, the Hyperlaser): 2x Power nearest the gate, VIP, Auto Fight nearest the spawn, turned to the spine;
--   SW of the spawn at the plaza's mouth (ref_W01.0: the MOST OP! pedestal): 2x Cash;
--   SE of the spawn on the east arm's south side (the reference's World 2 portal corner): +1 Shoe Slot;
--   either end of the box dais (the egg row's ends): Lucky, Triple Open.
-- The lane passes need no stand: a locked Robux lane is its own sell (full colour, "Locked / ONLY N / Nx Power", its
-- step-in prompt), as the reference's 25x / 100x / 250x lanes.
Lobby.Plan = {
	Stands = {
		-- { Products key, x, z, the point it turns to (its front, the prompt, faces the walk) }
		-- (B30 product pads, ref_product_pads.webp: one pad by a walk every ~10 studs, 3 studs of floor between pad and walk)
		{ 'DoubleRep', 11, 17, V(0, 0, 17) }, { 'VIP', 15.5, 27, V(0, 0, 27), nil, 2.6 }, { 'AutoShoot', 11, 37, V(0, 0, 37) }, -- the spine, east
		-- (B31: VIP's words sit 2.6 higher, so from the spawn they clear Auto Fight's: p3_four.jpg's 'VIAuto Fight')
		{ 'AutoOpen', 29, 44.5, V(29, 0, 55) }, -- the east walk, north, by the armory
		{ 'Speed2x', 11, 67, V(0, 0, 67) }, { 'ExtraEquip', 11, 79, V(0, 0, 79) }, -- the south walk, east
		{ 'DoubleCash', -11, 79, V(0, 0, 79) }, -- the south walk, west
		{ 'AutoCollect', 26, 80, V(26, 0, 90) }, -- the box walk, north
		{ 'Lucky', -27.5, 99, V(-27.5, 0, 90) }, { 'TripleOpen', 27.5, 99, V(27.5, 0, 90) }, -- either end of the box dais
	},
	-- the Robux boxes out by the walks near the spawn (the reference's Secret Egg): { BoxModels id, Products key, x, z, the
	-- point it turns to, tag, pad colour, special line (true words only) }
	BoxPads = {
		{ 'Grail', 'ShoeBoxGrail', -11, 37, V(0, 0, 37), 'NEW', C(236, 90, 200) }, -- the spine, west: the Crown Box
		{ 'Exclusive', 'ShoeBoxExclusive', 19, 44.5, V(19, 0, 55), 'NEW', C(120, 150, 255) }, -- the east walk, north: the Chrome Box
		{ 'GrailBundle', 'GrailBundle', -11, 68, V(0, 0, 68), 'NEW', C(176, 96, 255), '3 PAIRS IN ONE' }, -- the south walk, west
	},
	-- the group chest and the codes sign, turned to (0, look): (sketch_soldier_lobby_topdown.png, ref_W29.5) both by the spine's
	-- west edge, the chest ~6 studs south of the gate, the CODES sign ~6 further
	-- (the codes terminal stands a little further out than the chest, so walking up the spine it never hides the chest)
	-- (B30 path network: both along the spine's west edge near the door, ref_W29.5)
	Group = { chest = { -11.6, 13 }, codes = { -10.6, 23.5 }, look = 40 },
	Podium = { 22, 67.5 }, -- the winners' podium (Lobby.corners): beside the east walk, facing it
	World2 = { x = -46, z = 104, look = V(0, 0, 55) }, -- the portal, at the box walk's west end (Lobby.corners)
	Boards = { x = 47, z = 101 }, -- the leaderboards' V, at the box walk's east end (Lobby.corners)
	WorldBoss = { x = 56, z = 11, look = V(56, 0, 60) }, -- the NE corner bay, its back to the wall, facing the hall
}
function Lobby.stands(L)
	local g = L:group('ProductStands')
	for _, s in Lobby.Plan.Stands do
		local at = V(s[2], 0.06, s[3])
		local to = s[4] and V(s[4].X, 0.06, s[4].Z) or at + V(0, 0, -1)
		Lobby.Slots['Stand_' .. s[1]] = CFrame.lookAt(at, to)
		Lobby.productStand(g:at(CFrame.lookAt(at, to)), s[1], { half = s[5], lift = s[6] })
	end
	for _, b in Lobby.Plan.BoxPads do
		local at = V(b[3], 0.06, b[4])
		local cf = CFrame.lookAt(at, V(b[5].X, 0.06, b[5].Z))
		Lobby.Slots['BoxPad_' .. b[1]] = cf
		Lobby.boxPadStand(g:at(cf), b[1], b[2], b[7], b[6], b[8], b[9])
	end
	return g
end
function Lobby.worldBoss(L)
	local wb = Lobby.Plan.WorldBoss
	local at = V(wb.x, 0, wb.z)
	local cf = CFrame.lookAt(at, V(wb.look.X, 0, wb.look.Z))
	local slot = Lobby.worldBossStand(L:group('WorldBossCorner'):at(cf))
	Lobby.Slots.WorldBossBoard = cf * slot
end
-- C's armory stockroom, on the floor behind today's compact stand (LOBBY4 had it on the stand's back block): pallet racks
-- against the east wall in the bays between its pillars, crate pallets and the forklift between them.
function Lobby.armoryYard(L)
	local W, Z = Lobby.W, Lobby.ArmoryZ
	local g = L:group('ArmoryYard')
	local _, x1 = Lobby.armoryRect()
	local top = 0.06
	local x = W - Lobby.PillarD[1] - 0.9 - 2.2 -- the racks' centre line, clear of the pillars' plinths
	local k = 0
	for i = 1, #Lobby.SidePillars - 1 do
		local a, b = Lobby.SidePillars[i], Lobby.SidePillars[i + 1]
		local z = (a + b) / 2
		if math.abs(z - Z) < Lobby.Band then
			k += 1
			Lobby.rack(g:at(CFrame.new(x, top, z) * CFrame.Angles(0, math.pi / 2, 0)), b - a - Lobby.PillarW - 2.4, 3.2, 80 + k)
		end
	end
	local mx = (x1 + x - 2) / 2 + 1
	for _, z in { Z - 22, Z - 14, Z + 14, Z + 22 } do Lobby.crateStack(g:at(CFrame.new(mx, top, z) * CFrame.Angles(0, math.rad(z % 7 - 3), 0)), z % 2 == 0) end
	Lobby.forklift(g:at(CFrame.new(mx + 0.5, top, Z - 4) * CFrame.Angles(0, math.rad(-12), 0)))
	for _, z in { Z + 4, Z + 7 } do
		g:part('GunCase', V(6, 1.1, 1.5), CFrame.new(mx, top + 0.55, z) * CFrame.Angles(0, math.rad(z - Z), 0), C(58, 62, 74), M.SmoothPlastic)
		g:part('GunCaseLatch', V(0.6, 0.3, 1.56), CFrame.new(mx, top + 0.7, z) * CFrame.Angles(0, math.rad(z - Z), 0), C(214, 186, 92), M.SmoothPlastic)
	end
	return g
end

---------------------------------------------------------------------------------------------- outside the hall
-- (B30, the user: "make it like the references", the surroundings "a MIX of cliffs and hood blocks") What the windows,
-- the skylights and the doors show: the reference plaza's ring of orange-brown studded cliffs with grass tops (bible 2.1,
-- ref_W01.0 .. ref_W28.0), here on the far sides of the grass round the hall (west and east, south of the cross arm's
-- line, and a long band past the ring road behind the back wall), stepped up in tiers and jagged along their tops; and,
-- by the stage gate's end of the hall, low hood brick blocks (e_buildings' brickBuilding, flat-roofed, tagged) behind a
-- chain-link fence, with a taller cliff rising behind them. Scenery only: the hall's walls and the boundary keep players
-- in. All in the map frame, on the grass (top 0.4).
Lobby.CliffColors = { body = C(204, 112, 54), light = C(226, 138, 72), strata = C(172, 88, 42), grass = C(112, 196, 62), grassDark = C(86, 160, 46) }
-- One row of cliff columns along a face: u0..u1 along it (step ~8, jagged widths), the columns' depth d0..d1 away from
-- the face (into the cliff), each column h0 +- 4 high. face(u, d, y) -> V maps (along, depth, height) to the map frame;
-- out: the face's outward normal (toward the hall).
function Lobby.cliffRow(c, face, out, u0, u1, d0, d1, h0, seed)
	local K = Lobby.CliffColors
	local r = Random.new(seed)
	local u = u0
	while u < u1 - 0.5 do
		local w = math.min(u1 - u, r:NextNumber(6.5, 10))
		local hgt = h0 + r:NextInteger(-4, 4)
		local dz = d0 + r:NextNumber(0, 2.2)
		local function box(name, a, b, color, isStud)
			local lo, hi = face(a.X, a.Y, a.Z), face(b.X, b.Y, b.Z)
			local p = c:box(name, V(math.min(lo.X, hi.X), math.min(lo.Y, hi.Y), math.min(lo.Z, hi.Z)), V(math.max(lo.X, hi.X), math.max(lo.Y, hi.Y), math.max(lo.Z, hi.Z)), color, M.Plastic)
			if isStud then studs(p, true) end
			return p
		end
		box('CliffBody', V(u, dz, 0), V(u + w, d1, hgt), (r:NextNumber() < 0.35) and K.light or K.body, true)
		-- two darker strata bands across its face, a grass cap overhanging the face, a couple of grass drips
		for _, f in { 0.32, 0.64 } do
			local y = hgt * f + r:NextNumber(-1, 1)
			decor(box('CliffStrata', V(u + 0.2, dz - 0.25, y), V(u + w - 0.2, dz + 0.2, y + 0.9), K.strata)).CastShadow = false
		end
		box('CliffGrass', V(u - 0.1, dz - 0.6, hgt), V(u + w + 0.1, d1, hgt + 1.6), K.grass, true)
		for _ = 1, r:NextInteger(1, 2) do
			local x = u + r:NextNumber(0.6, w - 2.2)
			decor(box('CliffDrip', V(x, dz - 0.5, hgt - r:NextNumber(1.2, 3.2)), V(x + r:NextNumber(1.2, 2.2), dz + 0.2, hgt), K.grassDark)).CastShadow = false
		end
		u += w
	end
end
function Lobby.surroundings(L)
	local g = L:group('Surroundings')
	local W, N, S = Lobby.W + 1, Lobby.N - 1, Lobby.S + 1 -- (the hall's outside faces)
	-- the side cliffs: three tiers stepping up away from the hall, south of the cross arm's line (west and east)
	for _, sx in { -1, 1 } do
		local function face(base) return function(u, d, y) return V(sx * (base + d), y, u) end end
		for k, tier in ipairs({ { 16, 26 }, { 26, 38 }, { 36, 48 } }) do
			Lobby.cliffRow(g, face(W), V(-sx, 0, 0), 66 + (k - 1) * 3, S - 1, tier[1], tier[1] + 14, tier[2], 400 + k * 7 + (sx > 0 and 50 or 0))
		end
		-- a tall cliff behind the hood blocks at the gate's end
		Lobby.cliffRow(g, face(W), V(-sx, 0, 0), N + 1, 62, 36, 49, 46, 470 + (sx > 0 and 50 or 0))
	end
	-- the long band past the ring road behind the back wall
	local function south(base) return function(u, d, y) return V(u, y, base + d) end end
	Lobby.cliffRow(g, south(S), V(0, 0, -1), -150, 150, 42, 56, 30, 520)
	Lobby.cliffRow(g, south(S), V(0, 0, -1), -150, 150, 54, 68, 44, 530)
	-- the hood blocks at the gate's end: a flat-roofed two-storey brick block each side facing the hall, tagged, a
	-- chain-link fence in front with a dumpster and crates
	if brickBuilding then
		for _, sx in { -1, 1 } do
			local x = sx * (W + 13)
			local za = sx < 0 and 44 or N + 3
			local cf = CFrame.lookAt(V(x, 0, za), V(x + sx, 0, za))
			local tags = { { 'front', 8, 6, 'HOOD', C(255, 90, 160) }, { 'front', 26, 7, '+1', C(80, 220, 255) } }
			pcall(brickBuilding, g:at(cf), 38, { name = 'HoodBlock', floors = 2, depth = 18, roof = 'flat', bays = 2, tags = tags, ac = { { 'front', 18, 22 } } })
		end
	end
	for _, sx in { -1, 1 } do
		local x = sx * (W + 6)
		if chainLink then pcall(chainLink, g, V(x, 0.4, N + 2), V(x, 0.4, 44), 7, {}) end
		if dumpster then pcall(dumpster, g, CFrame.new(sx * (W + 9.5), 0.4, 30) * CFrame.Angles(0, sx * math.pi / 2, 0)) end
		if crate then
			for k, z in { 12, 14.6 } do pcall(crate, g, CFrame.new(sx * (W + 9), 0.4 + (k - 1) * 2.2, z), 2.2) end
		end
	end
	-- (no shade from out here: the hall's shell lets the sun in, and a 50-stud cliff's shadow would reach the plaza)
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = false end
	end
	return g
end

---------------------------------------------------------------------------------------------- build
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.hall(L)
	Lobby.floorPlan(L)
	Lobby.stand(L, skins)
	Lobby.shoeDais(L)
	Lobby.armory(L)
	Lobby.armoryYard(L)
	Lobby.signs(L)
	Lobby.northBays(L)
	Lobby.hoodProps(L)
	Lobby.spawn(L)
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	Lobby.corners(L)
	Lobby.surroundings(L)
	Lobby.stands(L)
	if V2.feature('WorldBoss') then Lobby.worldBoss(L) end -- (Oct 27: a later update; Config/Features)
	Lobby.decor(L)
	if Lobby.extras then Lobby.extras(L) end -- (B31 PLAZA: the spin wheel stand, the spawn pad, the plaza's scenery)
	return model
end
---------------------------------------------------------------------------------------------- the open plaza (B31)
-- B31 PLAZA (the user: an OPEN outdoor plaza like the reference, "Drop it, all outdoors": no warehouse, no hall; rules
-- 22-28). This piece runs after e2_lobby and swaps the hall's shell, floor and wall dressing for the soldier game's
-- plaza (bible §2.1, ref_W01.0_spawn_view_north.jpg, ref_STILL_lobby_topdown_superhero.png, ref_product_pads.webp):
--   Ground   one studded grass field (ref W01 lit grass #5ACB2E) inside a ring of terraced clay cliffs: 9-10 studs a
--            step, a grass cap on every column, a few blocky trees on the steps; low hood brick blocks stand back on
--            the upper step as landmarks (never up close). The cliffs are the plaza's edge (invisible walls on their faces).
--   Paths    a plus from the spawn: the spine north to the Stage 1 gate, the west arm into the training deck's aisle,
--            the east arm to the gun stand, the south walk to the box dais. Two-tone 4 x 4 studded tiles with a dark
--            1-stud curb on every side no other path continues from (ref W01's walks). The spawn square is plain grey.
--   Zones    each on a raised grey plinth with a dark curb: the training deck (rows of 4 + the head lane on its own
--            extension), the gun stand (the armory's apron and kerb), the stepped box dais. Products stand on the grass
--            in rows beside the spine and the south walk (ref_product_pads: pads on the grass by the path).
-- Gameplay contracts (slots, prompts, tags, names) are the builders' own (Stations, Armory, productStand,
-- boxPadStand, shoeDais, worldBossStand, leaderboard); only where they stand changes. Map frame, north = -Z.
Lobby.Open = true
-- B35 LAYOUT (the owner: "make it more based on the other references ... way way more optimal"; THE plan is
-- ref_STILL_lobby_topdown_superhero.png). One plus of walks from the crossing (z 42): north to the Stage 1 door (the gate
-- just outside it, z 0), west into the training aisle, east to the gun stand, south to the box row. Round it:
--   W   the training block: two rows of 4 compact bays (13 deep, Stations.Compact) facing an 8-wide aisle that the west
--       arm runs on into, on one sand plinth whose mouth meets the arm 2.5 studs past the spine; the head lane on its
--       gold stage on a small extension closing the aisle (the reference's lone lane at the training block's end)
--   E   the gun stand (ARMORY) on the east arm's end, the owner's gun shop behind it (the reference's evolutions stand)
--   S   the box row on its stepped plinth at the spine's south end (the reference's eggs)
--   N   two special-sale spots flanking the spine before the door (ref_W01's "MOST OP!" showcase), the CODES chest and
--       the group chest in the two north corners beside the door, the spin wheel by the group chest
--   SW  the WORLD 2 portal; SE the World Boss board and the three leaderboards in an angled row toward the east wall.
--       The portal and every board face the crossing (the owner: "make the portal and leaderboards face the main center").
-- No game-pass pads in the world (the owner: passes live in the Store). Calm floor fields between the zones.
-- OCT 27 ROOMIER (the owner: "keep the warehouse, make the layout better ... dont make it so cramped ... lay it out like
-- other games"): the same plan in ref_STILL_lobby_topdown's proportions. The walks 10 wide (the reference's path is ~6%
-- of the hall's width); the training block a walk's width (10) off the spine, like the reference's blocks; the crossing 6 further
-- south (an open band between the door and the zones' north edges, the reference's lawn before the exit); the bays a
-- stud further apart; the box row 9 past the zones (was 2); the hall 172 x 88 (was 124 x 76), grown sideways.
Lobby.SpineHalf = 5 -- every walk's half width (10 wide)
Lobby.PlazaGap = 15 -- the training deck's mouth (x -15): a walk's width past the spine's edge
Lobby.Aisle = 5 -- the training aisle's half width (10: the walks' own width)
-- (Oct 27, the owner: "make the shooting ranges a bit separate from each other") 13: 4 studs of platform between the
-- bays (was 11, 2 studs), so each bay reads as its own. The head lane's extension is trimmed to fit the wider rows.
Lobby.Stand.Pitch = 13 -- lane centre to lane centre (9-wide bays, 4 studs between)
Lobby.RowZ = { N = Lobby.CrossZ - Lobby.Aisle - Lobby.laneHalf(), S = Lobby.CrossZ + Lobby.Aisle + Lobby.laneHalf() } -- (the aisle's half width + the bays' half length)
do
	-- the deck hugs the bays: 2.2 of deck and kerb round the four places of each row and the bays' far ends
	local half = Lobby.Aisle + 2 * Lobby.laneHalf() + 2.2
	local x0 = -Lobby.PlazaGap - 2 * (2.2 + 4.5) - 3 * Lobby.Stand.Pitch
	Lobby.Plaza = { x0 = x0, x1 = -Lobby.PlazaGap, z0 = Lobby.CrossZ - half, z1 = Lobby.CrossZ + half, aisle = { Lobby.CrossZ - Lobby.Aisle, Lobby.CrossZ + Lobby.Aisle }, deck = 0.36 }
	Lobby.HeadFront = x0 - 1 -- the head lane's shooter end; its stage's red steps end 3 past the deepest bays
	Lobby.HeadDeck = { x0 = x0 - 15, z0 = Lobby.CrossZ - 8, z1 = Lobby.CrossZ + 8 } -- the deck's extension under the head lane
end
-- the warehouse's inner wall faces (e4's Lobby.WH; f_areas puts its keep-in walls on them): x -86..86, z 6..94, the
-- north door's mouth |x| < 24
-- (Oct 27: 6 deeper, 172 x 94, for the full-length range bays: the box dais keeps its walk-wide gap to the wall)
Lobby.Bounds = { x = 86, xw = 86, xe = 86, n = 6, s = 100, mouth = 24 }
function Lobby.edgeX(sx) return sx < 0 and Lobby.Bounds.xw or Lobby.Bounds.xe end
-- where you land: on the spine 3 south of the crossing, facing north over it to the gate (ref_W01.0)
Lobby.SpawnAt = SPAWN + V(0, 0, 3)
-- the gun stand: its front on the east arm's end (x 19: 4 further out than the training deck's mouth, so the smaller stand
-- and its shop sit in the middle of the east half, the way the training block fills the west), on the arm's axis
Lobby.ArmoryX, Lobby.ArmoryZ = Lobby.PlazaGap + 4, Lobby.CrossZ
-- (Oct 27 round 2) every zone stands on a raised platform: the deck's top this high over the floor, a darker kerb ring
-- half as high round it (the step up all round), a step where a walk runs on
Lobby.DeckH = 0.9
Lobby.Plaza.deck = Lobby.DeckH
Lobby.ArmoryAt = CFrame.lookAt(V(Lobby.ArmoryX, Lobby.DeckH, Lobby.ArmoryZ), V(0, Lobby.DeckH, Lobby.ArmoryZ))
-- the gun stand 1.1x on its platform (the reference's evolutions block is as big as its training block)
Lobby.ArmoryScale = 1.1
-- the box row on a wide stepped dais (the reference's egg dais): 4 boxes 10 apart, three risers, a stair at each end; its
-- front step 12 studs past the training plinth's south kerb (an open walk between, the portal and the boards either side)
Lobby.Dais.X, Lobby.Dais.StairW, Lobby.Dais.Slots = 20, 4, { 15, 5, -5, -15 }
Lobby.Dais.Low, Lobby.Dais.Front = 2.4, 2.4
Lobby.DaisAt = CFrame.new(0, 0, Lobby.Plaza.z1 + 12)
-- the portal's path: off the south walk, west in the band between the training plinth's kerb and the dais's front
Lobby.PortalPath = { x0 = -30, z0 = Lobby.Plaza.z1 + 1.4, z1 = Lobby.Plaza.z1 + 10.2 }
-- OCT 27 BRIGHT (the owner: "make the colors more bright for our game like the reference"): one calm light green floor,
-- light clean grey platforms with a blue-grey kerb, walks lighter still. Measured off ref_STILL_lobby_topdown (lit,
-- medians): floor (164, 234, 76), platforms (206, 214, 232), walks (210, 218, 235), kerbs (125, 138, 172), the darkest
-- edge (35, 56, 87). Built a shade under, so Huzz's sun lands them on the reference.
Lobby.Bright = {
	floor = C(158, 232, 74), floorB = C(154, 228, 70),
	-- (Oct 27, the owner: "don't make the lighting so bright, it hurts my eyes": the near-white walks and platforms were
	-- the glare, ~5% of the spawn view clipped against the reference's 0.8%; a shade down, still light and clean)
	deck = C(180, 188, 214), deckLight = C(194, 200, 224), kerb = C(110, 124, 164), kerbTop = C(138, 150, 186), edge = C(80, 94, 132),
	walk = C(198, 205, 224),
}
local BR = Lobby.Bright
Lobby.PlazaColors = {
	grass = BR.floor,
	pathA = BR.walk, pathB = BR.walk, curb = BR.kerb, spawn = BR.walk,
	clay = C(226, 128, 62), clayLight = C(238, 146, 78), cap = BR.floor, capDark = C(134, 212, 60),
}
-- the platforms: the training deck, the box dais, the gun stand's platform and the corner plinths
Lobby.Stand.Colors.deck = BR.deck
Lobby.Colors.dais, Lobby.Colors.panelLight, Lobby.Colors.pillarSide = BR.deck, BR.deckLight, BR.kerb
Lobby.Stand.Colors.kerb = BR.kerb
Lobby.Stand.Colors.kerbTop = BR.kerbTop
Lobby.Stand.Colors.nose, Lobby.Stand.Colors.cap, Lobby.Stand.Colors.post = BR.deckLight, BR.deckLight, BR.deckLight
Lobby.Stand.Colors.aisle = BR.walk
Lobby.Stand.Colors.aisleEdge = BR.kerb
Lobby.Stand.Colors.riserDark = BR.edge
Lobby.Stand.Colors.carpet, Lobby.Stand.Colors.carpetDark = C(196, 70, 70), C(140, 40, 48) -- (the head lane's red steps, ref_W06.5)
-- the aisle's runner in the platform's own grey, not a red carpet (critic 7: a big saturated field)
Lobby.Stand.Colors.runner, Lobby.Stand.Colors.runnerEdge = BR.deckLight, BR.kerb -- (calmer: a big field)
-- the gun stand in the same light clean greys (d3_armory reads its tones when it builds)
if Armory and Armory.Tone then
	local T = Armory.Tone
	T.deck, T.tread, T.trim, T.face, T.kick = BR.deck, BR.deckLight, C(240, 244, 252), BR.kerb, BR.edge
	T.riser, T.wall, T.band, T.pilaster = C(178, 188, 214), C(178, 188, 214), BR.kerb, BR.deckLight
	T.pad, T.padLip, T.plinth, T.apron, T.kerb, T.kerbTop = C(228, 232, 244), C(244, 246, 252), BR.edge, BR.deck, BR.kerb, BR.kerbTop
end
Lobby.BoardTilt = 0 -- (critic 9: no leaning slabs; ref_V2-07.0 boards stand upright on the grass)

-- Where everything stands (map frame). The centre every board turns to: the crossing.
Lobby.Centre = V(0, 0, Lobby.CrossZ)
Lobby.Plan = (function()
return {
	Stands = {}, -- (B35, the owner: no game-pass pads in the world; every pass is in the Store's Gamepasses)
	BoxPads = {},
	-- the special-sale spots, one each side of the spine before the door (ref_W01's "MOST OP!" showcase), turned to where
	-- you land. Filled for now with the Robux shoe offers (Lobby.saleSpot); the owner's renders will dress them later.
	Sales = {
		{ Name = 'West', Box = 'Grail', Key = 'ShoeBoxGrail', x = -11, z = 13, Tone = C(236, 90, 200), Tag = 'NEW' },
		{ Name = 'East', Box = 'GrailBundle', Key = 'GrailBundle', x = 11, z = 13, Tone = C(176, 96, 255), Special = '3 PAIRS' },
	},
	-- the open band before the door, over the zones' north edges (the reference's chests before the exit): the CODES
	-- chest (west), the group chest and the spin wheel (east)
	Group = { codes = { -36, 13 }, chest = { 37, 12 }, scale = 0.62 },
	World2 = { x = -36, z = 80, look = Lobby.Centre, scale = 0.85 }, -- (Oct 27: past the dais's west end, its own path) -- (SW, facing the crossing; Oct 27 round 2, the owner: "put the second world portal closer ... easy for the players to see": just off the south walk under the training block, like the reference's)
	WorldBoss = { x = 40, z = 80, look = Lobby.Centre }, -- (SE, facing the crossing; off for now)
	-- (SE) the three boards side by side in one row past the dais's east end, 15 apart, each facing the crossing, at the
	-- end of their own path off the south walk (Oct 27, the owner: "so people can actually see and reach them, not just
	-- being one another": the old staggered row hid each board behind the next from the spawn)
	Boards = { { 26, 86 }, { 48, 86 }, { 70, 86 } }, -- 22 apart: from anywhere in the hall none hides another (Oct 27)
}
end)()

-- ItemMeshes (MESH, Shared/ItemMeshes): the showcase items as real meshes, the Part build as the fallback. Until it
-- lands, the brief's stub: clone ReplicatedStorage.HoodItemMeshes[id] scaled to fit `size` with its bottom centre at cf.
function Lobby.itemMeshes()
	if Lobby._meshes ~= nil then return Lobby._meshes end
	local mod = Lobby.sharedModule('ItemMeshes')
	if not (mod and mod.place) then
		mod = {}
		function mod.place(id, cf, size, parent, fallbackFn)
			local folder = ReplicatedStorage:FindFirstChild('HoodItemMeshes')
			local t = folder and folder:FindFirstChild(id)
			if t and t:IsA('Model') then
				local m = t:Clone()
				local cfB, ext = m:GetBoundingBox()
				local fit = typeof(size) == 'Vector3' and math.min(size.X / ext.X, size.Y / ext.Y, size.Z / ext.Z) or size / math.max(ext.X, ext.Y, ext.Z)
				pcall(function() m:ScaleTo(m:GetScale() * fit) end)
				cfB, ext = m:GetBoundingBox()
				m:PivotTo(cf * CFrame.new(0, ext.Y / 2, 0) * (cfB:Inverse() * m:GetPivot()))
				for _, p in m:GetDescendants() do if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end end
				m.Parent = parent
				return m, true
			end
			return fallbackFn(cf, size, parent), false
		end
	end
	Lobby._meshes = mod
	return mod
end
local function vmin(a, b) return V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
local function vmax(a, b) return V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
-- (B31 PLAZA, rule 29) The user's blocky designs ($S/bz: Blender -> GLB -> the user's one-time import into
-- ReplicatedStorage.HoodItemMeshes) are THE objects; our Part builds are the fallback until they're imported. Their design
-- sizes in studs (GLB bounds; 1 unit = 1 stud, standing on their bottom, front -Z): Lobby.Designed[id] = { x, y, z }.
Lobby.Designed = {
	Pad_Base = { 8.12, 1.39, 8.12 }, Pedestal_Box = { 7, 1.1, 7 }, Spawn_Pad = { 12, 1.17, 12 },
	Gate_Stage1 = { 20.2, 14.17, 4.7 }, Board_Boxes = { 16.3, 10.1, 2.4 }, Board_Leaderboard = { 8.5, 12.15, 3.4 },
	Stand_Guns = { 14.6, 11.28, 6.81 }, Stand_SpinWheel = { 6.6, 8.09, 3.55 }, Portal_World2 = { 16.4, 14.14, 5.46 },
	Chest_Codes = { 4.74, 3.99, 3.64 }, Chest_GroupReward = { 4.74, 3.99, 3.64 },
	Scn_Tree_1 = { 10.6, 13.5, 7.4 }, Scn_Tree_2 = { 8.7, 14.5, 7 }, Scn_Bush_1 = { 3.2, 2.37, 2.64 }, Scn_Cliff_Block = { 16, 12.17, 16 },
	Scn_Building_1 = { 19.05, 15.97, 14.95 }, Scn_Building_2 = { 19.15, 21.95, 14.4 }, Scn_Building_3 = { 19.05, 17, 14.75 }, Scn_Building_4 = { 21.05, 14.18, 15.2 },
	Scn_Hydrant = { 2.48, 3.06, 2.26 }, Scn_TrashCan = { 2.24, 3.65, 2.26 }, Scn_Bench = { 4.7, 2.75, 2.24 }, Scn_StreetLamp = { 4.7, 8.43, 2 },
	Scn_Cone = { 2.7, 2.56, 2.7 }, Scn_Barrel = { 2.06, 3.04, 2.12 }, Scn_Crate = { 2.7, 2.51, 2.7 }, Scn_Sandbag = { 4.68, 1.72, 1.28 },
	Scn_Car = { 5.26, 4.68, 10 }, Scn_Hoop = { 5.4, 9.98, 5.4 }, Scn_Fence = { 8, 4.63, 0.92 }, Scn_GraffitiWall = { 8, 5.39, 1.44 },
}
-- Is the designed model imported (so a builder can lay out round it)?
function Lobby.hasDesign(id)
	local IM = Lobby.itemMeshes()
	return IM.has ~= nil and IM.has(id) == true
end
-- Place the designed model `id` with its bottom centre at c (front -Z), `k` times its design size (default 1); else run
-- build(c) (our Part build). Returns usedMesh, the model. A solid design gets an invisible box collider round its
-- footprint (the import's parts never collide): solid = true (its whole box) or a height.
function Lobby.designed(c, id, k, build, solid)
	local IM = Lobby.itemMeshes()
	local d = Lobby.Designed[id] or { 4, 4, 4 }
	k = k or 1
	local size = math.max(d[1], d[2], d[3]) * k
	local ok, m, used = pcall(IM.place, id, c:world(CFrame.new()), size, c.parent, function() return nil end)
	if ok and m and used ~= false then
		m.Name = id
		if solid then
			local h = type(solid) == 'number' and solid or d[2] * k
			local box = ghost(c:box('DesignCollider', V(-d[1] * k / 2, 0, -d[3] * k / 2), V(d[1] * k / 2, h, d[3] * k / 2), P.white))
			box.CanCollide, box.CastShadow = true, false
		end
		return true, m
	end
	if not ok then warn('[Lobby] ' .. id .. ': ' .. tostring(m)) end
	if build then build(c) end
	return false, nil
end
-- A model's world box (min, max) over its visible parts.
function Lobby.boundsOf(model)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local h = V((math.abs(r00) * p.Size.X + math.abs(r01) * p.Size.Y + math.abs(r02) * p.Size.Z) / 2,
				(math.abs(r10) * p.Size.X + math.abs(r11) * p.Size.Y + math.abs(r12) * p.Size.Z) / 2,
				(math.abs(r20) * p.Size.X + math.abs(r21) * p.Size.Y + math.abs(r22) * p.Size.Z) / 2)
			lo, hi = vmin(lo, V(x, y, z) - h), vmax(hi, V(x, y, z) + h)
		end
	end
	return lo, hi
end
-- Fit a Part-built model (any pose) so its largest side is `size`, its bottom centre at world cf.
function Lobby.fitModel(model, cf, size)
	local lo, hi = Lobby.boundsOf(model)
	if lo.X == math.huge then return model end
	local ext = hi - lo
	local k = size / math.max(ext.X, ext.Y, ext.Z, 0.1)
	local bottom = V((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = p.CFrame - bottom
			p.Size *= k
			p.CFrame = cf * (rel.Rotation + rel.Position * k)
		end
	end
	return model
end

---------------------------------------------------------------------------------------------- ground and cliffs
-- (replaces the hall) The grass field, and the terraced clay cliffs round it.
function Lobby.hall(L)
	local K = Lobby.PlazaColors
	local h = L:group('Hall')
	local g = h:box('Floor', V(-128, -1, Lobby.N - 1), V(128, 0, Lobby.S + 1), K.grass, M.Plastic)
	studs(g)
	g.Name = 'Grass'
	Lobby.cliffs(L)
	return h
end
-- One terrace step along a face: columns 8-12 wide from u0 to u1 (along the face), from the face back to `back`
-- (depth), each column h0 +- 1 tall with a grass cap (overhanging the face 0.4) and, now and then, a blocky tree set
-- back on its top. face(u, d, y) maps along / depth / height to the map frame.
function Lobby.terrace(c, face, u0, u1, back, h0, seed, trees)
	local K = Lobby.PlazaColors
	local r = Random.new(seed)
	local u, k = u0, 0
	while u < u1 - 0.01 do
		-- (B34, the owner's "Alien" place: one 8-stud grid, steps in 4s)
		local w = math.min(u1 - u, ({ 8, 16, 16, 24 })[r:NextInteger(1, 4)])
		if u1 - (u + w) < 4 then w = u1 - u end -- (no sliver at the end)
		local hgt = h0 + ({ 0, 0, 4 })[r:NextInteger(1, 3)]
		k += 1
		local function box(name, a, b, color)
			local lo, hi = face(a.X, a.Y, a.Z), face(b.X, b.Y, b.Z)
			return c:box(name, vmin(lo, hi), vmax(lo, hi), color, M.Plastic)
		end
		studs(box('CliffBody', V(u, 0, -1), V(u + w, back, hgt - 1.2), k % 3 == 0 and K.clayLight or K.clay), true)
		studs(box('CliffCap', V(u, -0.4, hgt - 1.2), V(u + w, back, hgt), k % 4 == 1 and K.capDark or K.cap), true)
		-- grass drips: green strips running down the face from the cap, 4-8 wide, a quarter to three quarters of the face
		local du = u + r:NextInteger(0, math.max(0, math.floor(w) - 8))
		while du < u + w - 3.9 do
			local dw = math.min(({ 4, 4, 8 })[r:NextInteger(1, 3)], u + w - du)
			local len = (hgt - 1.2) * ({ 0.25, 0.5, 0.75 })[r:NextInteger(1, 3)]
			decor(box('CliffDrip', V(du, -0.4, hgt - 1.2 - len), V(du + dw, -0.1, hgt - 1.2), K.cap)).CastShadow = false
			du += dw + 4 * r:NextInteger(1, 3)
		end
		if trees and w >= 10 and r:NextNumber() < trees then
			local p = face(u + w / 2, math.min(back - 4, 6 + r:NextNumber(0, 3)), hgt)
			Lobby.designed(c:at(CFrame.new(p) * CFrame.Angles(0, r:NextInteger(0, 3) * math.pi / 2, 0)), k % 2 == 0 and 'Scn_Tree_1' or 'Scn_Tree_2', 0.7,
				function(f) tree(f, V(0, 0, 0), seed + k, 0.62, nil, true) end)
		end
		u += w
	end
end
function Lobby.cliffs(L)
	local g = L:group('Surroundings')
	local B = Lobby.Bounds
	local X, N, S, mouth = B.x, B.n, B.s, B.mouth
	local function west(base, sx) return function(u, d, y) return V(sx * (base + d), y, u) end end
	local function south(base) return function(u, d, y) return V(u, y, base + d) end end
	local function north(base) return function(u, d, y) return V(u, y, base - d) end end
	-- tier 1 (the step you see over the grass): the user's Scn_Cliff_Block tiles when imported (16 x 12 x 16, stepped,
	-- studded, grass on every step), else our clay columns; tiers 2 and 3 (the high ground behind, out past the map's wall)
	-- stay our columns either way (a tile's back half sinks into tier 2)
	local tiles = Lobby.hasDesign('Scn_Cliff_Block')
	local XW, XE = Lobby.edgeX(-1), Lobby.edgeX(1)
	if tiles then
		Lobby.cliffTiles(g, V(-XW, 0, N), V(-XW, 0, S + 16), V(1, 0, 0), 1)
		Lobby.cliffTiles(g, V(XE, 0, N), V(XE, 0, S + 16), V(-1, 0, 0), 1)
		Lobby.cliffTiles(g, V(-XW, 0, S), V(XE, 0, S), V(0, 0, -1), 1)
		Lobby.cliffTiles(g, V(-mouth, 0, N), V(-XW - 16, 0, N), V(0, 0, 1), 0.75)
		Lobby.cliffTiles(g, V(mouth, 0, N), V(XE + 16, 0, N), V(0, 0, 1), 0.75)
	end
	for _, sx in { -1, 1 } do
		local X = Lobby.edgeX(sx)
		if not tiles then Lobby.terrace(g, west(X, sx), N, S, 8, 8, 600 + sx, 0.35) end
		Lobby.terrace(g, west(X + 8, sx), Lobby.N - 6, S + 45, 12, 16, 620 + sx, 0.25)
		Lobby.terrace(g, west(X + 20, sx), Lobby.N - 6, S + 45, 127 - (X + 20), 24, 630 + sx, 0.2) -- (out past the map's wall)
		-- the north step either side of the gate's mouth, and the higher step behind it beside the stage's blocks
		local function nface(u, d, y) return V(sx * u, y, N - d) end
		if not tiles then
			Lobby.terrace(g, nface, mouth, 37, 12, 9, 640 + sx, 0)
			Lobby.terrace(g, nface, 37, X + 8, 6, 9, 650 + sx, 0)
		end
		Lobby.terrace(g, function(u, d, y) return V(sx * u, y, Lobby.N - d) end, 37, X + 8, 6, 17, 660 + sx, 0)
	end
	if not tiles then Lobby.terrace(g, south(S), -XW - 8, XE + 8, 8, 8, 680, 0.3) end
	Lobby.terrace(g, south(S + 8), -XW - 20, XE + 20, 14, 16, 700, 0.2)
	Lobby.terrace(g, south(S + 22), -127, 127, 23, 24, 710, 0.15)
	local _ = north
	-- the hood blocks on the high ground: flat-roofed two-storey brick blocks set back from the step's edge, tagged
	local lm = L:group('Landmarks')
	if brickBuilding then
		local spots = { -- (on the top step, set back from its edge)
			{ V(-(X + 23), 28, 34), V(1, 0, 0), 30 }, { V(-(X + 23), 28, 92), V(1, 0, 0), 26 },
			{ V(Lobby.edgeX(1) + 23, 28, 26), V(-1, 0, 0), 26 }, { V(Lobby.edgeX(1) + 23, 28, 84), V(-1, 0, 0), 30 },
			{ V(-46, 28, S + 26), V(0, 0, -1), 30 }, { V(40, 28, S + 26), V(0, 0, -1), 34 },
		}
		local tags = { { 'front', 7, 6, 'HOOD', C(255, 90, 160) }, { 'front', 19, 7, '+1', C(80, 220, 255) } }
		for k, s in spots do
			-- (rule 29) the user's Scn_Building_1..4 (a snack bar, a 21 walk-up, the SUDS laundromat, the REVZ garage), 1.2x,
			-- their fronts to the plaza; else brickBuilding (footprint x 0..w, z -d..0, its front on +Z)
			local front = s[1] - V(0, 1, 0) -- (sunk a stud: the step's columns stand 27-29 tall, never a gap under it)
			local mid = front - s[2] * (15 * 1.2 / 2)
			Lobby.designed(lm:at(CFrame.lookAt(mid, mid + s[2])), 'Scn_Building_' .. ((k - 1) % 4 + 1), 1.2, function()
				local cf = CFrame.lookAt(front, front - s[2]) * CFrame.new(-s[3] / 2, 0, 0)
				pcall(brickBuilding, lm:at(cf), s[3], { name = 'HoodBlock', floors = 1, depth = 12, roof = 'flat', bays = 2, tags = k % 2 == 1 and tags or nil, wall = k % 3 == 0 and C(170, 84, 64) or nil })
			end, true)
		end
	end
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = p.Size.Y > 6 end -- (the steps throw short shadows on the grass at their foot)
	end
	for _, p in lm.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = false end
	end
	return g
end
Lobby.surroundings = function() end -- (the cliffs are built with the ground)
-- A row of the user's Scn_Cliff_Block tiles along a cliff face from a to b (map frame, on the ground), fronts toward
-- `inward` (the plaza): as many whole tiles as fit at up to kmax of their 16-stud size, scaled to fill the run exactly.
function Lobby.cliffTiles(g, a, b, inward, kmax)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.max(1, math.ceil(len / (16 * kmax) - 0.01))
	local k = len / (16 * n)
	for i = 0, n - 1 do
		local mid = a + dir * (16 * k * (i + 0.5)) - inward * (8 * k)
		Lobby.designed(g:at(CFrame.lookAt(mid, mid + inward)), 'Scn_Cliff_Block', k, nil, true)
	end
end

---------------------------------------------------------------------------------------------- the path network
function Lobby.paths()
	local Z, N, a = Lobby.CrossZ, Lobby.N, Lobby.SpineHalf
	local sz = Lobby.DaisAt.Position.Z -- the dais's front step
	return {
		-- (B34) one clean plus from the crossing, each arm ending at its zone: no cross walks, no stubs (Oct 27: 10 wide)
		{ -a, a, Z - a, Z + a, 'Crossroads' },
		{ -a, a, N - 1, Z - a, 'North' },
		{ -Lobby.PlazaGap, -a, Z - a, Z + a, 'West' },
		{ a, Lobby.PlazaGap, Z - a, Z + a, 'East' },
		{ -a, a, Z + a, sz, 'South' },
		-- (Oct 27, the owner: "make a pathway to the portal") off the south walk, west between the training block and
		-- the box dais, onto the portal's front
		Lobby.PortalPath and { Lobby.PortalPath.x0, -a, Lobby.PortalPath.z0, Lobby.PortalPath.z1, 'Portal' } or nil,
		-- and its mirror east, along the front of the three leaderboards
		Lobby.PortalPath and { a, Lobby.BoardsPathX or 76, Lobby.PortalPath.z0, Lobby.PortalPath.z1, 'Boards' } or nil,
	}
end
-- One path rectangle: two-tone 4 x 4 studded tiles on a grid from the spawn, a dark 1-stud curb along every stretch of
-- its sides that no other path continues across (a hair higher than the tiles).
function Lobby.pathRect(f, r, all)
	local K = Lobby.PlazaColors
	local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
	local top, ct, e = 0.12, 0.24, 1
	if r[5] == 'Crossroads' then
		studs(f:box('SpawnSquare', V(x0, 0, z0), V(x1, top, z1), K.spawn, M.Plastic)).CastShadow = false
	else
		local T, cz = 4, Lobby.CrossZ - 1 -- (the grid: x on 0, z on the spawn's square edges)
		local function cuts(a, b, origin)
			local list, v = {}, a
			while v < b - 0.01 do
				local nxt = math.min(b, origin + (math.floor((v - origin) / T + 1e-6) + 1) * T)
				table.insert(list, { v, nxt, math.floor((v - origin) / T + 1e-6) })
				v = nxt
			end
			return list
		end
		for _, cx in cuts(x0, x1, 0) do
			for _, czr in cuts(z0, z1, cz) do
				local tone = (cx[3] + czr[3]) % 2 == 0 and K.pathA or K.pathB
				studs(f:box('Path', V(cx[1], 0, czr[1]), V(cx[2], top, czr[2]), tone, M.Plastic)).CastShadow = false
			end
		end
	end
	local function open(fixed, isX, u0, u1, outward)
		local cutsList = {}
		for _, o in all do
			if o ~= r then
				local t0, t1, s0, s1
				if isX then t0, t1, s0, s1 = o[1], o[2], o[3], o[4] else t0, t1, s0, s1 = o[3], o[4], o[1], o[2] end
				local probe = fixed + outward * 0.3
				if probe > s0 and probe < s1 then table.insert(cutsList, { math.max(u0, t0), math.min(u1, t1) }) end
			end
		end
		-- (the gate's end and the plinths a path runs onto take no curb either)
		if isX and outward < 0 and fixed <= Lobby.N then table.insert(cutsList, { u0, u1 }) end
		if not isX and outward < 0 and math.abs(fixed + Lobby.PlazaGap) < 0.01 then table.insert(cutsList, { u0, u1 }) end
		if not isX and outward > 0 and math.abs(fixed - Lobby.PlazaGap) < 0.01 then table.insert(cutsList, { u0, u1 }) end
		local dx = Lobby.Dais.X + Lobby.Dais.StairW
		if isX and outward > 0 and math.abs(fixed - Lobby.DaisAt.Position.Z) < 0.01 then table.insert(cutsList, { math.max(u0, -dx), math.min(u1, dx) }) end
		table.sort(cutsList, function(p, q) return p[1] < q[1] end)
		local runs, u = {}, u0
		for _, c in cutsList do
			if c[2] > c[1] then
				if c[1] > u then table.insert(runs, { u, c[1] }) end
				u = math.max(u, c[2])
			end
		end
		if u1 > u then table.insert(runs, { u, u1 }) end
		return runs
	end
	local function curb(a, b) studs(f:box('PathCurb', a, b, K.curb, M.Plastic)).CastShadow = false end
	for _, run in open(z0, true, x0, x1, -1) do curb(V(run[1], 0, z0), V(run[2], ct, z0 + e)) end
	for _, run in open(z1, true, x0, x1, 1) do curb(V(run[1], 0, z1 - e), V(run[2], ct, z1)) end
	for _, run in open(x0, false, z0, z1, -1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then curb(V(x0, 0, a2), V(x0 + e, ct, b2)) end
	end
	for _, run in open(x1, false, z0, z1, 1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then curb(V(x1 - e, 0, a2), V(x1, ct, b2)) end
	end
end
function Lobby.floorPlan(L)
	local f = L:group('FloorPlan')
	local all = Lobby.paths()
	Lobby.Path = {}
	for _, r in all do
		Lobby.pathRect(f, r, all)
		Lobby.Path[r[5]] = { r[1], r[2], r[3], r[4] }
	end
	-- the dark chevrons on the spine pointing to the gate (ref W01: the walk's arrow marks toward STAGE 1)
	for _, tz in { Lobby.CrossZ - 13, Lobby.CrossZ - 21, Lobby.CrossZ - 29 } do
		for _, sx in { -1, 1 } do
			local tip, tail = V(0, 0.15, tz), V(sx * 2.6, 0.15, tz + 2.8)
			decor(f:part('WalkChevron', V(1.2, 0.06, (tip - tail).Magnitude + 0.6), CFrame.lookAt((tip + tail) / 2, tip), Lobby.PlazaColors.curb, M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the training deck's extension under the head lane: the deck's own slab and curb, round its three outer sides
	local St = Lobby.Stand
	local Kc, Pz, Hd = St.Colors, Lobby.Plaza, Lobby.HeadDeck
	local hgt = Pz.deck
	local t = L:group('HeadDeck')
	local kw = 1.2
	studs(t:box('PlazaDeck', V(Hd.x0 + kw, 0, Hd.z0 + kw), V(Pz.x0, hgt, Hd.z1 - kw), Kc.deck, M.Plastic))
	local ky = math.min(hgt + 0.25, 0.46) -- (the training deck's own kerb ring: a step up all round)
	for _, e in { { V(Hd.x0, 0, Hd.z0), V(Pz.x0, ky, Hd.z0 + kw) }, { V(Hd.x0, 0, Hd.z1 - kw), V(Pz.x0, ky, Hd.z1) }, { V(Hd.x0, 0, Hd.z0 + kw), V(Hd.x0 + kw, ky, Hd.z1 - kw) } } do
		studs(t:box('PlazaKerb', e[1], e[2], Kc.kerb, M.Plastic), true)
	end
	-- (Oct 27 round 2) a half-height step where the west and east arms run onto their platforms
	local sp = Lobby.SpineHalf
	for _, x in { Pz.x1, Lobby.PlazaGap } do
		local a, b = math.min(x, x + (x < 0 and 1.4 or -1.4)), math.max(x, x + (x < 0 and 1.4 or -1.4))
		studs(t:box('PlazaStep', V(a, 0, Lobby.CrossZ - sp), V(b, hgt / 2, Lobby.CrossZ + sp), Kc.kerbTop, M.Plastic))
	end
	return f
end

-- (Oct 27 round 2) The gun stand's platform, the training block's mirror east of the spine: the same raised light grey
-- deck in its darker kerb ring, open at its mouth on the east arm. The stand and the shop stand on it, 1.1x.
function Lobby.gunDeckRect()
	local half = (Armory and Armory.ApronHalf or 20) * Lobby.ArmoryScale + 2.2
	return Lobby.PlazaGap, 64, Lobby.ArmoryZ - half, Lobby.ArmoryZ + half
end
function Lobby.gunDeck(L)
	local Kc = Lobby.Stand.Colors
	local x0, x1, z0, z1 = Lobby.gunDeckRect()
	local h, kw = Lobby.DeckH, 1.2
	local ky = math.min(h + 0.25, 0.46)
	local t = L:group('GunDeck')
	studs(t:box('PlazaDeck', V(x0, 0, z0 + kw), V(x1 - kw, h, z1 - kw), Kc.deck, M.Plastic))
	for _, e in { { V(x0, 0, z0), V(x1, ky, z0 + kw) }, { V(x0, 0, z1 - kw), V(x1, ky, z1) }, { V(x1 - kw, 0, z0 + kw), V(x1, ky, z1 - kw) },
		{ V(x0 - kw, 0, z0), V(x0, ky, Lobby.CrossZ - Lobby.SpineHalf) }, { V(x0 - kw, 0, Lobby.CrossZ + Lobby.SpineHalf), V(x0, ky, z1) } } do
		studs(t:box('PlazaKerb', e[1], e[2], Kc.kerb, M.Plastic), true)
	end
	return t
end
local armoryBase = Lobby.armory
function Lobby.armory(L)
	Lobby.gunDeck(L)
	armoryBase(L)
	local k = Lobby.ArmoryScale
	if k ~= 1 then
		for _, name in { 'Armory', 'GunShop' } do
			local m = L.parent:FindFirstChild(name)
			if m then Lobby.scaleAbout(m, Lobby.ArmoryAt, k) end
		end
	end
end

---------------------------------------------------------------------------------------------- what the plaza drops
-- No wall dressing out here: no murals, no stray crates, drums or tyres on the deck, no stockroom racks or forklift, no
-- vending corner, no carton piles (critic 9: no strays). Their builders stay for other callers.
Lobby.rangeMural = function() end
Lobby.standProps = function() end
Lobby.armoryYard = function() end
Lobby.hoodProps = function() end
Lobby.decor = function() end

-- The plaza's two area titles: TRAIN over the head lane at the aisle's end, ARMORY over the gun stand. One line each.
function Lobby.signs(L)
	local s = L:group('HallSigns')
	local tt = Lobby.title(s, V(Lobby.endX() - 3, 24, Lobby.CrossZ), 19, 5.2, 'TRAIN', nil, P.white, 220)
	tt.Name = 'TrainTitle'
	-- (B34 fix round: the walls and the air stay quiet; only TRAIN and the dais's BOXES sign float)
	return s
end
-- (B35) the CODES chest and the group chest in the north corners beside the door, each on its own small plinth (the
-- training deck's slab in its dark kerb), turned to where you land.
function Lobby.northBays(L)
	local b = L:group('NorthBays')
	local g = Lobby.Plan.Group
	for _, it in { { 'CodesPlinth', g.codes, Lobby.codeTerminal }, { 'GroupPlinth', g.chest, Lobby.rewardChest } } do
		local x, z = it[2][1], it[2][2]
		local y = Lobby.plinth(L, it[1], x - 3.6, x + 3.6, z - 3.4, z + 3.4) + 0.06
		local cf = CFrame.lookAt(V(x, y, z), V(Lobby.SpawnAt.X, y, Lobby.SpawnAt.Z))
		local model = it[3](b:at(cf))
		if model then Lobby.scaleAbout(model, cf, g.scale or 1) end
	end
	return b
end
-- The spawn: the plain grey square at the crossing (no mark, the user's rule 17).
function Lobby.spawn(L)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(Lobby.SpawnAt + V(0, 0.4, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = L.parent
	Lobby.Slots.Spawn = CFrame.new(Lobby.SpawnAt)
end

---------------------------------------------------------------------------------------------- spin wheel stand
-- (rule 29) The user's Stand_SpinWheel on the grass north of the gun stand, by the spine's east row, turned to where you
-- land: a hold opens the Spin Wheel window (HoodClient/Wheel: the prompt's OpenSpin attribute). Our Part wheel when the
-- design isn't imported: a studded base, a post, an eight-wedge wheel with a pointer. One line of words over it.
Lobby.SpinAt = { x = 50, z = 13 } -- (B35: the NE corner beside the group chest)
function Lobby.spinStand(L)
	local at = V(Lobby.SpinAt.x, 0.06, Lobby.SpinAt.z)
	local c, model = L:group('SpinWheelStand')
	c = c:at(CFrame.lookAt(at, V(Lobby.SpawnAt.X, 0.06, Lobby.SpawnAt.Z)))
	Lobby.designed(c, 'Stand_SpinWheel', 1, function(f)
		studs(f:box('WheelBase', V(-3.3, 0, -1.8), V(3.3, 0.6, 1.8), C(236, 240, 248), M.Plastic))
		f:box('WheelBaseBand', V(-3.35, 0.45, -1.85), V(3.35, 0.6, 1.85), C(70, 120, 255), M.SmoothPlastic)
		f:box('WheelPost', V(-0.6, 0.6, -0.2), V(0.6, 4.2, 0.9), C(70, 120, 255), M.SmoothPlastic)
		local hub = CFrame.new(0, 4.6, -0.4)
		local cols = { C(255, 70, 70), C(255, 200, 40), C(60, 200, 90), C(60, 150, 255), C(255, 70, 70), C(255, 200, 40), C(60, 200, 90), C(60, 150, 255) }
		f:part('WheelRim', V(0.5, 7, 7), hub * CFrame.Angles(0, math.pi / 2, 0), C(250, 250, 252), M.SmoothPlastic, Enum.PartType.Cylinder)
		for k, col in cols do
			f:part('WheelWedge', V(0.3, 2.9, 1.9), hub * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, (k - 1) * math.pi / 4) * CFrame.new(0, 1.65, 0), col, M.SmoothPlastic)
		end
		f:part('WheelHub', V(0.7, 1.2, 1.2), hub * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.pi / 2, 0), C(250, 250, 252), M.SmoothPlastic, Enum.PartType.Cylinder)
		f:wedge('WheelPointer', V(0.4, 1.0, 0.9), hub * CFrame.new(0, 3.9, -0.5) * CFrame.Angles(math.pi, 0, 0), C(40, 44, 60), M.SmoothPlastic)
	end, true)
	local hit = ghost(c:box('WheelHit', V(-2.5, 0, -4.5), V(2.5, 6, -1.5), P.white))
	local p = Lobby.prompt(hit, 'Spin', 'Spin Wheel', 10)
	p:SetAttribute('ComingSoon', nil)
	p:SetAttribute('OpenSpin', true)
	p.Name = 'SpinPrompt'
	local a = Lobby.signWords(c, V(0, 10.8, 0), 8, 1.6, { { 'Title', 'SPIN WHEEL', 1, Lobby.Grad.gold, 3.5 } }, 36)
	Lobby.nearWords(a.WorldLabel, 26, 36)
	return model
end

---------------------------------------------------------------------------------------------- scenery (rule 29)
-- The user's plaza scenery (Scn_*), placed like the reference frames: few props, in tight clusters at the edges, never on
-- a walk: sandbags behind the training rows' far ends (ref_W07.5: sandbags behind the targets), street lamps at the
-- crossing's south corners and on the gate approach, benches facing the leaderboards, a hydrant and a bin by the box walk,
-- a barrel-and-crate corner by the world boss board, a parked car, a hoop, a graffiti wall between two fence panels at
-- the east cliff, trees at two corners and bushes at the cliffs' feet. Our Part builds (Lobby.Scn[id]) when the designs
-- aren't imported. Each: { id, x, z, yaw (deg: 0 = front -Z, toward the gate), k = scale }.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Pz = Lobby.Plaza
	for x = Pz.x0 + 3, Pz.x1 - 3, 4.8 do
		add('Scn_Sandbag', x, Pz.z0 - 1.6, 0)
		add('Scn_Sandbag', x, Pz.z1 + 1.6, 180)
	end
	for _, sx in { -1, 1 } do
		add('Scn_StreetLamp', sx * 14.5, 9, sx * 90) -- (either side of the gate's opening, in front of its pillars)
		add('Scn_StreetLamp', 21.5, sx > 0 and 62.5 or 47.5, 90) -- (the east arm's end, by the gun stand's front corners)
	end
	add('Scn_Hydrant', 7.4, 80, -90) add('Scn_TrashCan', -7.4, 80, 90)
	add('Scn_Barrel', 73, 34, 0) add('Scn_Barrel', 75.4, 35.2, 20) add('Scn_Crate', 73.6, 37.6, 8) add('Scn_Crate', 76.6, 38, -10)
	add('Scn_Car', 66, 28, 90)
	add('Scn_Hoop', -80, 30, 90)
	add('Scn_GraffitiWall', 78.4, 72, -90) add('Scn_Fence', 78.6, 64, -90) add('Scn_Fence', 78.6, 80, -90)
	add('Scn_Tree_1', 70, 48, 0) add('Scn_Tree_2', -84, 106, 0) add('Scn_Tree_2', -82, 14, 0)
	for _, z in { 22, 38, 80, 94 } do add('Scn_Bush_1', -91, z, 90) end
	for _, z in { 22, 56, 88, 100 } do add('Scn_Bush_1', 77.6, z, -90) end
	for _, x in { -70, -55, -40, 40, 55, 70 } do add('Scn_Bush_1', x, 13.5, 180) end
	for _, x in { -80, -66, -30, 30 } do add('Scn_Bush_1', x, 115.4, 0) end
	return list
end)()
local SOLID = { Scn_Car = true, Scn_Hoop = true, Scn_Fence = true, Scn_GraffitiWall = true, Scn_Tree_1 = true, Scn_Tree_2 = true }
-- Our Part builds of the scenery: c is the bottom centre, front -Z. Chunky, 2-3 tones each, sized like the designs.
Lobby.Scn = {}
function Lobby.Scn.Scn_Sandbag(c)
	local tan, dark = C(206, 176, 120), C(170, 138, 88)
	for k, b in { { -1.17, 0, 2.2 }, { 1.17, 0, 2.2 }, { 0, 0.86, 2.2 } } do
		c:box('Sandbag', V(b[1] - b[3] / 2, b[2], -0.6), V(b[1] + b[3] / 2, b[2] + 0.86, 0.6), k == 3 and tan or (k == 1 and tan or dark), M.SmoothPlastic)
	end
end
function Lobby.Scn.Scn_StreetLamp(c)
	local navy, glow = C(56, 62, 110), C(255, 236, 160)
	c:box('LampFoot', V(-0.8, 0, -0.8), V(0.8, 0.5, 0.8), navy:Lerp(P.black, 0.3), M.SmoothPlastic)
	c:box('LampPost', V(-0.35, 0.5, -0.35), V(0.35, 8, 0.35), navy, M.SmoothPlastic)
	c:box('LampBand', V(-0.45, 3.4, -0.45), V(0.45, 3.8, 0.45), C(255, 200, 60), M.SmoothPlastic)
	c:box('LampArm', V(-0.25, 7.6, -0.25), V(3.2, 8.0, 0.25), navy, M.SmoothPlastic)
	c:box('LampHood', V(2.2, 6.9, -0.7), V(3.8, 7.6, 0.7), navy, M.SmoothPlastic)
	decor(c:box('LampGlow', V(2.4, 5.9, -0.5), V(3.6, 6.9, 0.5), glow, M.Neon)).CastShadow = false
end
function Lobby.Scn.Scn_Bench(c) Lobby.bench(c:at(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))) end
function Lobby.Scn.Scn_Hydrant(c) hydrant(c, V(0, 0, 0)) end
function Lobby.Scn.Scn_TrashCan(c)
	c:post('BinBody', 1.05, 3.1, V(0, 0, 0), C(56, 150, 80), M.SmoothPlastic)
	c:post('BinBand', 1.12, 0.3, V(0, 1.9, 0), C(40, 110, 60), M.SmoothPlastic)
	c:post('BinLid', 1.15, 0.4, V(0, 3.1, 0), C(40, 110, 60), M.SmoothPlastic)
end
function Lobby.Scn.Scn_Barrel(c) if Stations then Stations.drum(c, V(0, 0, 0), 1.0, 3.0, C(60, 130, 230), C(40, 90, 180), C(30, 70, 150), M.SmoothPlastic) end end
function Lobby.Scn.Scn_Crate(c) crate(c, CFrame.new(0, 0, 0), 2.6) end
function Lobby.Scn.Scn_Cone(c) if Stations then Stations.cone(c, CFrame.new()) end end
function Lobby.Scn.Scn_Car(c) car(c, CFrame.new() * CFrame.Angles(0, math.pi / 2, 0), C(214, 52, 52)) end
function Lobby.Scn.Scn_Hoop(c)
	c:box('HoopFoot', V(-1.4, 0, -1.4), V(1.4, 0.6, 1.4), C(56, 62, 110), M.SmoothPlastic)
	c:box('HoopPole', V(-0.3, 0.6, -0.3), V(0.3, 8.4, 0.3), C(56, 62, 110), M.SmoothPlastic)
	c:box('HoopBoard', V(-2.4, 7.2, -1.2), V(2.4, 10, -0.9), P.white, M.SmoothPlastic)
	c:box('HoopSquare', V(-0.9, 7.6, -1.25), V(0.9, 8.8, -1.2), C(255, 120, 40), M.SmoothPlastic)
	c:part('HoopRim', V(0.2, 1.8, 1.8), CFrame.new(0, 7.6, -2.2) * CFrame.Angles(0, 0, math.pi / 2), C(255, 120, 40), M.SmoothPlastic, Enum.PartType.Cylinder)
end
function Lobby.Scn.Scn_Fence(c)
	for k = 0, 3 do
		local x = -3 + k * 2
		c:box('FencePlank', V(x - 0.95, 0, -0.4), V(x + 0.95, 4.2 + (k % 2) * 0.4, 0.4), k % 2 == 0 and C(206, 150, 96) or C(184, 128, 80), M.SmoothPlastic)
	end
end
function Lobby.Scn.Scn_GraffitiWall(c)
	local w = c:box('GraffitiWall', V(-4, 0, -0.6), V(4, 5, 0.6), C(196, 196, 214), M.SmoothPlastic)
	c:box('GraffitiCap', V(-4.1, 5, -0.7), V(4.1, 5.4, 0.7), C(150, 152, 176), M.SmoothPlastic)
	line(surface(w, Enum.NormalId.Front, 20), 'Tag', 'WOW!', C(255, 90, 170), FONT.title, 0.2, 0.6, Lobby.Ink, 3)
end
function Lobby.Scn.Scn_Tree_1(c) tree(c, V(0, 0, 0), 31, 0.8, 0, true) end
function Lobby.Scn.Scn_Tree_2(c) tree(c, V(0, 0, 0), 37, 0.85, 0, true) end
function Lobby.Scn.Scn_Bush_1(c)
	c:box('Bush', V(-1.6, 0, -1.3), V(1.6, 1.6, 1.3), C(70, 170, 70), M.SmoothPlastic)
	c:box('Bush', V(-0.9, 1.6, -0.9), V(1.1, 2.4, 1.0), C(100, 200, 90), M.SmoothPlastic)
end
function Lobby.scenery(L)
	local g = L:group('Scenery')
	for _, s in Lobby.Scenery do
		local c = g:at(CFrame.new(s[2], 0.06, s[3]) * CFrame.Angles(0, math.rad(s[4]), 0))
		Lobby.designed(c, s[1], s[5], Lobby.Scn[s[1]], SOLID[s[1]] and (s[1]:find('Tree') and 6 or true) or nil)
	end
	-- every prop stays a prop: nothing collides but the solid ones' boxes (and our Part trees' and car's own parts)
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Name ~= 'DesignCollider' and not p:FindFirstAncestor('Tree') and not p.Name:find('^Car') then decor(p) end
	end
	return g
end

-- The spawn pad (rule 29: the user's Spawn_Pad, 12 wide, plain, no symbol) over the crossing, sunk so its top stands
-- 0.35 over the walks (no step to trip on); our plain crossing square when it isn't imported (pathRect).
function Lobby.spawnPad(L)
	-- (B34 fix round) a 6-wide plate under where you land, flush with the walk (0.02 proud), a shade lighter than it: no
	-- symbol, nothing to blow out the view
	local g = L:group('SpawnPad')
	local at = Lobby.SpawnAt
	studs(g:box('SpawnPlate', V(at.X - 3, 0.12, at.Z - 3), V(at.X + 3, 0.14, at.Z + 3), C(196, 188, 176), M.Plastic)).CastShadow = false
end
-- (B34, the owner's "Alien" place) a soft white sparkle fountain rising off a station: one emitter on a flat box (cf in the
-- map frame, the box's centre on the floor; hx / hz its half sizes), the built-in sparkle texture, a low steady rate (no
-- flashing). The pads and the Robux boxes keep their own sparkles (Lobby.sparkles).
function Lobby.fountain(L, name, cf, hx, hz, tone)
	local box = ghost(L:at(cf):box(name, V(-hx, 0, -hz), V(hx, 0.2, hz), P.white))
	box.CastShadow = false
	local sp = Instance.new('ParticleEmitter')
	sp.Name = 'SparkleFountain'
	sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sp:SetAttribute('PreviewTexture', 'sparkle')
	sp.Color = ColorSequence.new(P.white, (tone or P.white):Lerp(P.white, 0.5))
	sp.LightEmission, sp.LightInfluence = 0.8, 0
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Rate = math.clamp(hx * hz * 0.12, 2, 6)
	sp.Lifetime = NumberRange.new(1.6, 2.6)
	sp.Speed = NumberRange.new(1.5, 3)
	sp.Acceleration = V(0, 0.6, 0)
	sp.SpreadAngle = Vector2.new(12, 12)
	sp.Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } })
	sp.Transparency = Lobby.seq({ { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } })
	sp.Parent = box
	return box
end
function Lobby.extras(L)
	Lobby.spinStand(L)
	Lobby.spawnPad(L)
	Lobby.scenery(L)
	-- (Oct 27 round 2, the owner: one calm floor like the reference) no colour fields any more: the hall's one light green
	-- floor, the zones on their light grey platforms. The Stage 1 door marked by two of the owner's street lamps, their
	-- arms over the spine (warm glows on the lamps, no light pools: the look pass keeps every lobby light faint)
	local ln = L:group('DoorLamps')
	for _, sx in { -1, 1 } do
		local c = ln:at(CFrame.new(sx * 7, 0.06, Lobby.N + 2.6) * CFrame.Angles(0, sx < 0 and 0 or math.pi, 0))
		Lobby.designed(c, 'Scn_StreetLamp', 1, Lobby.Scn.Scn_StreetLamp)
	end
	for _, p in ln.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	local f = L:group('Fountains')
	local D = Lobby.Dais
	-- along the box row (on the dais deck, in front of the boxes) and along the gun stand's front step
	Lobby.fountain(f, 'BoxRowFountain', Lobby.DaisAt * CFrame.new(0, D.Low, D.RowZ - 4.4), D.X - 4, 0.6, C(255, 220, 120))
	Lobby.fountain(f, 'GunStandFountain', CFrame.new(Lobby.ArmoryX + 1.2 * Lobby.ArmoryScale, Lobby.DeckH + 0.4, Lobby.ArmoryZ), 0.6, 14 * Lobby.ArmoryScale, C(255, 140, 200))
end

---------------------------------------------------------------------------------------------- the corners (B34)
-- The low zones round the plus: the leaderboards' plinth on the east wall (SE), the group corner's plinth (SW). A
-- plinth is the training deck's slab in its dark kerb, the kerb's top 0.46 over the floor (nothing to trip on).
function Lobby.plinth(L, name, x0, x1, z0, z1)
	local Kc = Lobby.Stand.Colors
	local t = L:group(name)
	local kw, h = 1.2, Lobby.Plaza.deck
	studs(t:box('PlazaDeck', V(x0 + kw, 0, z0 + kw), V(x1 - kw, h, z1 - kw), Kc.deck, M.Plastic))
	local ky = math.min(h + 0.1, 0.46)
	for _, e in { { V(x0, 0, z0), V(x1, ky, z0 + kw) }, { V(x0, 0, z1 - kw), V(x1, ky, z1) },
		{ V(x0, 0, z0 + kw), V(x0 + kw, ky, z1 - kw) }, { V(x1 - kw, 0, z0 + kw), V(x1, ky, z1 - kw) } } do
		studs(t:box('PlazaKerb', e[1], e[2], Kc.kerb, M.Plastic), true)
	end
	return h
end
-- the three boards (Plan.Boards places them: one row, each turned to the crossing)
Lobby.Boards = {
	{ x = 0, z = -10, yaw = 90, lift = 0, name = 'POWER', title = 'Top Power', color = C(255, 166, 40), live = 'PowerLeaderboard', main = 'POWER', extra = 'REBIRTHS' },
	{ x = 0, z = 0, yaw = 90, lift = 0, name = 'REBIRTHS', title = 'Top Rebirth', color = C(255, 70, 70), live = 'ServerLeaderboard', main = 'REBIRTHS', extra = 'POWER' },
	{ x = 0, z = 10, yaw = 90, lift = 0, name = 'CASH', title = 'Top Cash', color = C(120, 226, 70), live = 'CashLeaderboard', main = 'CASH', extra = 'STAGE' },
}
-- Scale a built model's parts about a frame's origin (k < 1 shrinks it toward cf; cf in the map frame).
function Lobby.scaleAbout(model, cf, k)
	cf = V2.Origin * cf
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = cf:ToObjectSpace(p.CFrame)
			p.Size *= k
			p.CFrame = cf * (rel.Rotation + rel.Position * k)
		end
	end
end
function Lobby.corners(L)
	local Pl = Lobby.Plan
	local centre = Lobby.Centre
	-- WORLD 2 (SW): the portal turned to the crossing; 0.85 of its size
	local w2 = Pl.World2
	local g = L:group('World2Corner')
	local at = V(w2.x, 0.06, w2.z)
	local cf = CFrame.lookAt(at, V(w2.look.X, 0.06, w2.look.Z))
	local model = Lobby.world2(g, cf)
	if model then Lobby.scaleAbout(model, cf, w2.scale or 1) end
	Lobby.Slots.World2 = cf
	Lobby.Slots.World2Portal = cf
	local words = Lobby.signWords(g, (cf * CFrame.new(0, 17.5 * (w2.scale or 1), -1)).Position, 12, 3.6, {
		{ 'Title', 'World 2', 0.6, Lobby.Grad.pink, 4.5 },
		{ 'Soon', 'BUSINESS DISTRICT', 0.4, Lobby.Grad.white, 3.5 }, -- (Oct 27: World 2 is built; the door says what opens it)
	}, 120)
	words.WorldLabel:SetAttribute('FadeNear', 30)
	words.WorldLabel:SetAttribute('FadeFar', 48)
	-- the leaderboards (SE): an angled row toward the east wall, each board's face turned to the crossing
	local bg = L:group('BoardCorner'):group('Leaderboards')
	for k, b in Lobby.Boards do
		local p = Pl.Boards[k]
		local bcf = CFrame.lookAt(V(p[1], 0.06, p[2]), V(centre.X, 0.06, centre.Z))
		Lobby.Slots['Leaderboard' .. k] = bcf
		Lobby.leaderboard(bg, bcf, b)
	end
end

---------------------------------------------------------------------------------------------- special-sale spots (B35)
-- (the owner: "not even game passes we need there, we need the special sales for shoes or in general the special sales")
-- Two spots beside the spine before the door, the place of ref_W01's "MOST OP!" showcase. Each spot is a frame (its
-- centre on the floor, turned to where you land) and one builder: today Lobby.saleOffer, the Robux shoe offer on its
-- showcase pad (boxPadStand: the box turning over the pad, its name and its price with the Robux sign, the Buy prompt
-- that opens the Store at its card). Honest words only: no stock, no timer, no "limited". The owner's renders will
-- replace the look in Lobby.saleOffer; the spots (Lobby.Plan.Sales) stay.
function Lobby.saleOffer(c, sale)
	local model = Lobby.boxPadStand(c, sale.Box, sale.Key, sale.Tone, sale.Tag, sale.Special, sale.Lift)
	Lobby.limitedLine(model)
	return model
end
-- The sale's third line under the price, for the limiteds system to come (stock left, time left on the sale): the
-- words stack grows 1.2 studs upward (the name and the price keep their size, nothing moves down onto the box) and gets
-- a hidden, EMPTY row (TextLabels LimitedStock in red and LimitedTimer in white, chunky outlined; the billboard's
-- LimitedLine attribute marks it). The map never writes
-- words into it: Shared/Config/Limiteds fills it (a static placeholder only in Studio, see there; later the real stock
-- and timer).
Lobby.LimitedRowH = 1.2
function Lobby.limitedLine(model)
	local anchor = model and model:FindFirstChild('WordsAnchor', true)
	local g = anchor and anchor:FindFirstChild('WorldLabel')
	if not g then return nil end
	local w, h0 = g.Size.X.Scale, g.Size.Y.Scale
	local h = h0 + Lobby.LimitedRowH
	local k = h0 / h
	for _, t in g:GetChildren() do
		if t:IsA('GuiObject') then
			t.Position = UDim2.new(t.Position.X.Scale, t.Position.X.Offset, t.Position.Y.Scale * k, t.Position.Y.Offset)
			t.Size = UDim2.new(t.Size.X.Scale, t.Size.X.Offset, t.Size.Y.Scale * k, t.Size.Y.Offset)
		end
	end
	g.Size = UDim2.fromScale(w, h)
	anchor.CFrame += V(0, Lobby.LimitedRowH / 2, 0)
	-- (two labels straight in the billboard, each hidden until Limiteds fills it; LimitedLine marks the billboard)
	g:SetAttribute('LimitedLine', true)
	local stock = line(g, 'LimitedStock', '', P.white, FONT.title, k, 1 - k, Lobby.Ink, 3)
	stock.Position, stock.Size, stock.TextXAlignment = UDim2.fromScale(0.02, k), UDim2.fromScale(0.54, 1 - k), Enum.TextXAlignment.Right
	Lobby.fill(stock, Lobby.Grad.red)
	local timer = line(g, 'LimitedTimer', '', P.white, FONT.title, k, 1 - k, Lobby.Ink, 3)
	timer.Position, timer.Size, timer.TextXAlignment = UDim2.fromScale(0.6, k), UDim2.fromScale(0.38, 1 - k), Enum.TextXAlignment.Left
	Lobby.fill(timer, Lobby.Grad.white)
	stock.Visible, timer.Visible = false, false
	return g
end
function Lobby.saleSpot(g, sale)
	local at = V(sale.x, 0.06, sale.z)
	local cf = CFrame.lookAt(at, V(Lobby.SpawnAt.X, 0.06, Lobby.SpawnAt.Z))
	Lobby.Slots['Sale_' .. sale.Name] = cf
	Lobby.Slots['BoxPad_' .. sale.Box] = cf
	local model = Lobby.saleOffer(g:at(cf), sale)
	if model then model:SetAttribute('SaleSpot', sale.Name) end
	return model
end
function Lobby.stands(L)
	local g = L:group('SaleSpots')
	for _, sale in Lobby.Plan.Sales do Lobby.saleSpot(g, sale) end
	return g
end
---------------------------------------------------------------------------------------------- the warehouse (B33, B34)
-- B33 WAREHOUSE (the user: "bring back the warehouse ... it gives the game more personality"; rules 16, 19, 33), made
-- COMPACT in B34 (the user: "redo the lobby layout completely ... make it feel nice to play"; their pick: a smaller,
-- tidier warehouse, everything a few steps from the spawn). Runs after e3_plaza, which lays the zones out.
--   Floor    warm light concrete slabs (two tones, 16 x 16, faint studs), no grass inside; the walks lie on it.
--   Walls    chunky brick round x -86..86, z 6..100 (Oct 27; the training block and the head lane's stage clear of
--            the west wall; the Oct 13 hall's colours again in round 3), a dark brick skirting, cream pilasters every
--            16 studs, an open clerestory band showing the cliffs and the hood blocks outside, one painted field per wall (west red behind the head lane, north blue
--            either side of the door, east teal behind the gun shop, south yellow behind the box dais), roller doors:
--            open ones onto the yard (the north one onto the Stage 1 gate, 6 studs out), shut slatted ones as detail.
--   Roof     trusses (chords, posts and braces) and purlins, 31-37 up, closed by a cream ceiling and a steel deck (Oct 27;
--            they cast no shadow); the HoodToy sun throws
--            stripes of shadow on the floor; the camera never meets it. The shell itself casts no shade.
--   Outside  the cliffs, trees and hood blocks, 12 studs past the walls (a grass yard between), seen through the doors.
-- (Oct 27, the owner: "keep the warehouse ... dont make it so cramped": 172 x 88, was 124 x 76; the spine on its middle
-- line like the reference's path, the zones a walk's width off it, calm floor round them; z0 still hugs the gate's wings)
Lobby.WH = { x0 = -86, x1 = 86, z0 = 6, z1 = 100,
	 t = 2, eave = 30, truss = 6, off = 12, bay = 16,
	win = { 17.6, 28.2 }, skirt = 3, -- (Oct 27 round 2: taller clerestory windows, more sky and cliffs over the walls)
	-- open doors: { wall, u0, u1, height } (u along the wall: z for west/east, x for north/south)
	-- (B34 fix round: the north door 28 high, so the Stage 1 gate's whole frame shows through it from the spawn)
	open = { { 'N', -24, 24, 28 }, { 'S', -46, -32, 16 }, { 'S', 32, 46, 16 }, { 'W', 58, 72, 16 } },
	shut = { { 'N', -66, -52, 14 }, { 'W', 12, 24, 14 }, { 'E', 64, 76, 14 } },
	-- one painted field per wall: { wall, u0, u1, y0, y1, colour key }
	-- (B34 fix round: none; Oct 27 round 3: back, as in the Oct 13 hall the owner picked ("E"): red behind the ranges,
	-- blue either side of the gate's door, teal behind the gun shop, yellow behind the box dais, all under the windows)
	fields = { { 'W', 28, 54, 3, 15, 'red' }, { 'N', -46, -30, 3, 15, 'blue' }, { 'N', 30, 46, 3, 15, 'blue' },
		{ 'E', 30, 58, 3, 15, 'teal' }, { 'S', -14, 14, 3, 14, 'yellow' } },
}
Lobby.WHColors = { -- (Oct 27 round 3, the owner picked the Oct 13 warehouse, "E", the one with blue highlights: its
	-- palette is back: warm light concrete, orange brick with a dark brick skirting and cream pilasters, blue steel trusses
	-- and lamp shades; the layout stays today's)
	floorA = C(224, 210, 190), floorB = C(212, 198, 178), grass = Lobby.Bright.floor,
	brick = C(206, 112, 72), brickLight = C(218, 128, 84), skirt = C(142, 64, 48), trim = C(240, 216, 176),
	steel = C(66, 82, 132), steelLight = C(98, 116, 170), slat = C(176, 184, 198), slatDark = C(146, 154, 170),
	drum = C(84, 92, 112), lamp = C(255, 236, 170),
	red = C(214, 70, 60), blue = C(60, 128, 214), teal = C(40, 172, 160), yellow = C(250, 196, 50),
}
-- (tutorial targets: gate 1 is reached through the north loading door; its arrows pass the doorway first)
Lobby.Door = 23
Lobby.DoorZ = Lobby.WH.z0 - 1

-- One wall's run as boxes: wall w ('N','S','W','E') from u0 to u1, built as bands between the holes' heights; each hole
-- { ua, ub, ya, yb }. The bands under the skirting height take the skirting colour.
function Lobby.whWall(h, w, u0, u1, holes)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local function box(ua, ub, ya, yb, color, name, inset)
		local i = inset or 0
		local a, b
		if w == 'N' then a, b = V(ua, ya, Wh.z0 - Wh.t), V(ub, yb, Wh.z0 + i)
		elseif w == 'S' then a, b = V(ua, ya, Wh.z1 - i), V(ub, yb, Wh.z1 + Wh.t)
		elseif w == 'W' then a, b = V(Wh.x0 - Wh.t, ya, ua), V(Wh.x0 + i, yb, ub)
		else a, b = V(Wh.x1 - i, ya, ua), V(Wh.x1 + Wh.t, yb, ub) end
		return h:box(name or 'Wall', a, b, color, M.SmoothPlastic)
	end
	local ys = { -1, Wh.skirt, Wh.eave }
	for _, hl in holes do table.insert(ys, hl[3]); table.insert(ys, hl[4]) end
	table.sort(ys)
	for i = 1, #ys - 1 do
		local ya, yb = ys[i], ys[i + 1]
		if yb - ya > 0.01 then
			local open = {}
			for _, hl in holes do if hl[3] <= ya + 0.01 and hl[4] >= yb - 0.01 then table.insert(open, hl) end end
			table.sort(open, function(a, b) return a[1] < b[1] end)
			local col = yb <= Wh.skirt + 0.01 and K.skirt or K.brick
			local u = u0
			for _, hl in open do
				if hl[1] > u + 0.01 then box(u, hl[1], ya, yb, col) end
				u = math.max(u, hl[2])
			end
			if u1 > u + 0.01 then box(u, u1, ya, yb, col) end
		end
	end
	return box
end

-- The shell: four walls with their clerestory, doors, pilasters, fields and cap; the open roof; hanging lamps.
function Lobby.warehouse(L, h)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local walls = {
		N = { Wh.x0, Wh.x1, Vector3.zAxis }, S = { Wh.x0, Wh.x1, -Vector3.zAxis },
		W = { Wh.z0 - Wh.t, Wh.z1 + Wh.t, Vector3.xAxis }, E = { Wh.z0 - Wh.t, Wh.z1 + Wh.t, -Vector3.xAxis },
	}
	-- the inner face's point at u along wall w, height y, d studs into the hall
	local function at(w, u, y, d)
		if w == 'N' then return V(u, y, Wh.z0 + d) elseif w == 'S' then return V(u, y, Wh.z1 - d)
		elseif w == 'W' then return V(Wh.x0 + d, y, u) else return V(Wh.x1 - d, y, u) end
	end
	local function face(w, ua, ub, ya, yb, d0, d1, color, name)
		local a, b = at(w, ua, ya, d0), at(w, ub, yb, d1)
		return h:box(name, a, b, color, M.SmoothPlastic)
	end
	for w, spec in walls do
		local u0, u1 = spec[1], spec[2]
		local doors = {}
		for _, d in Wh.open do if d[1] == w then table.insert(doors, { d[2], d[3], d[4], true }) end end
		for _, d in Wh.shut do if d[1] == w then table.insert(doors, { d[2], d[3], d[4], false }) end end
		local function inDoor(a, b)
			for _, d in doors do if b > d[1] - 1 and a < d[2] + 1 then return true end end
			return false
		end
		local function inField(a, b, y0)
			for _, f in Wh.fields do if f[1] == w and b > f[2] - 1 and a < f[3] + 1 and f[5] > y0 then return true end end
			return false
		end
		-- the holes: the open doors, and a clerestory window in every bay with no field reaching up into it
		local holes = {}
		for _, d in doors do if d[4] then table.insert(holes, { d[1], d[2], -1, d[3] }) end end
		local lo, hi = math.min(Wh.x0, Wh.z0), math.max(Wh.x1, Wh.z1)
		local bays = {}
		local b0 = math.ceil((u0 + 1) / Wh.bay) * Wh.bay
		for u = b0, u1 - Wh.bay, Wh.bay do
			if not inField(u + 3, u + 13, Wh.win[1]) and not (w == 'N' and math.abs(u + 8) < 30) then
				table.insert(holes, { u + 3, u + 13, Wh.win[1], Wh.win[2] })
				table.insert(bays, u)
			end
		end
		local _ = lo + hi
		Lobby.whWall(h, w, u0, u1, holes)
		-- window mullions and sills
		for _, u in bays do
			face(w, u + 7.5, u + 8.5, Wh.win[1], Wh.win[2], -Wh.t + 0.4, -0.4, K.steel, 'WallMullion')
			face(w, u + 2.6, u + 13.4, Wh.win[1] - 0.6, Wh.win[1], -Wh.t - 0.4, 0.5, K.trim, 'WallSill')
		end
		-- pilasters on the bay lines (none across a door), skirting-dark foot
		for u = b0, u1, Wh.bay do
			if u > u0 + 1 and u < u1 - 1 and not inDoor(u - 1, u + 1) and not inField(u - 1, u + 1, -1) then
				face(w, u - 1, u + 1, Wh.skirt, Wh.eave, 0, 0.8, K.trim, 'WallPilaster')
				face(w, u - 1.2, u + 1.2, 0, Wh.skirt, 0, 1.0, K.skirt, 'WallPilasterFoot')
			end
		end
		-- the cap along the top, inside and out
		face(w, u0, u1, Wh.eave, Wh.eave + 1.2, -Wh.t - 0.4, 0.6, K.trim, 'WallCap')
		-- doors: steel jambs and header, the drum box over each; open ones keep 2 studs of curtain showing, shut ones are
		-- a full slatted curtain set 0.6 into the opening
		for _, d in doors do
			local a, b, ht, isOpen = d[1], d[2], d[3], d[4]
			face(w, a - 1.4, a, 0, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorJamb')
			face(w, b, b + 1.4, 0, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorJamb')
			face(w, a, b, ht, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorHeader')
			face(w, a + 0.2, b - 0.2, ht - 2.2, ht, 0.1, 1.9, K.drum, 'WallDoorDrum')
			if isOpen then
				for k = 0, 1 do
					face(w, a + 0.3, b - 0.3, ht - 3.2 - k, ht - 2.2 - k, 0.9, 1.3, k % 2 == 0 and K.slat or K.slatDark, 'WallDoorSlat')
				end
				-- (B34 fix round: no hazard stripes on the jambs)
			else
				local y = 0
				local k = 0
				while y < ht - 2.2 - 0.01 do
					local y1 = math.min(y + 1, ht - 2.2)
					face(w, a, b, y, y1, 0.2, 0.6, k % 2 == 0 and K.slat or K.slatDark, 'WallDoorSlat')
					y, k = y1, k + 1
				end
				face(w, a + (b - a) / 2 - 1.5, a + (b - a) / 2 + 1.5, 0.6, 1.2, 0.6, 0.9, K.drum, 'WallDoorHandle')
			end
		end
		-- the painted fields, a trim frame round each
		for _, f in Wh.fields do
			if f[1] == w then
				face(w, f[2], f[3], f[4], f[5], 0, 0.3, K[f[6]], 'WallField')
				face(w, f[2] - 0.6, f[3] + 0.6, f[5], f[5] + 0.6, 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[2] - 0.6, f[3] + 0.6, f[4] - 0.6, f[4], 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[2] - 0.6, f[2], f[4], f[5], 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[3], f[3] + 0.6, f[4], f[5], 0, 0.5, K.trim, 'WallFieldFrame')
			end
		end
		local _ = spec[3]
	end
	-- corner posts (outside the walls' ends) up to the cap
	for _, cx in { Wh.x0 - Wh.t, Wh.x1 } do
		for _, cz in { Wh.z0 - Wh.t, Wh.z1 } do
			h:box('WallCorner', V(cx - 0.6, -1, cz - 0.6), V(cx + Wh.t + 0.6, Wh.eave + 1.6, cz + Wh.t + 0.6), K.trim, M.SmoothPlastic)
		end
	end
	-- the shell throws no shade (no zone in its gloom); it stays solid and queryable (the tutorial's arrows raycast it)
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Name:find('^Wall') then p.CastShadow = false end
	end
	-- the open roof: a truss every 18 studs across the hall (east-west), purlins along it; it throws the sun's stripes
	local r = L:group('Roof')
	local y0, y1 = Wh.eave + 1.2, Wh.eave + 1.2 + Wh.truss
	local xa, xb = Wh.x0 - Wh.t, Wh.x1 + Wh.t
	local n = 20
	for z = Wh.z0 + 10, Wh.z1 - 6, 18 do
		r:box('RoofChord', V(xa, y0, z - 0.6), V(xb, y0 + 1.2, z + 0.6), K.steel, M.SmoothPlastic)
		r:box('RoofChord', V(xa, y1 - 1.2, z - 0.6), V(xb, y1, z + 0.6), K.steel, M.SmoothPlastic)
		local step = (xb - xa) / n
		for k = 0, n do
			local x = xa + k * step
			local px = math.clamp(x, xa + 0.5, xb - 0.5)
			r:box('RoofPost', V(px - 0.5, y0 + 1.2, z - 0.5), V(px + 0.5, y1 - 1.2, z + 0.5), K.steelLight, M.SmoothPlastic)
			if k < n then
				local a, b = V(x + 0.5, y0 + 1.2, z), V(x + step - 0.5, y1 - 1.2, z)
				if k % 2 == 1 then a, b = V(x + 0.5, y1 - 1.2, z), V(x + step - 0.5, y0 + 1.2, z) end
				r:bar('RoofBrace', a, b, 0.8, K.steelLight, M.SmoothPlastic)
			end
		end
	end
	for x = Wh.x0 + 8.65, Wh.x1 - 4, 17.3 do
		r:box('RoofPurlin', V(x - 0.6, y1, Wh.z0 - Wh.t), V(x + 0.6, y1 + 1.2, Wh.z1 + Wh.t), K.steel, M.SmoothPlastic)
	end
	-- (Oct 27, the owner: "add roofs to the warehouses") the roof closed: a brick band round the top of the walls up to the
	-- roof (no sky in the gap over the clerestory), a warm cream ceiling on the purlins and a blue steel deck over it with
	-- a cream lip. The ceiling and deck cast no shadow, so the hall stays as bright as it was under the open trusses
	-- (the trusses still throw their stripes).
	local top = y1 + 1.2
	local band = { { Wh.x0 - Wh.t, Wh.z0 - Wh.t, Wh.x1 + Wh.t, Wh.z0 }, { Wh.x0 - Wh.t, Wh.z1, Wh.x1 + Wh.t, Wh.z1 + Wh.t },
		{ Wh.x0 - Wh.t, Wh.z0, Wh.x0, Wh.z1 }, { Wh.x1, Wh.z0, Wh.x1 + Wh.t, Wh.z1 } }
	for _, b in band do
		r:box('RoofBand', V(b[1], Wh.eave + 1.2, b[2]), V(b[3], top, b[4]), K.brick, M.SmoothPlastic)
	end
	local ceiling = r:box('RoofCeiling', V(Wh.x0 - Wh.t, top, Wh.z0 - Wh.t), V(Wh.x1 + Wh.t, top + 0.4, Wh.z1 + Wh.t), K.trim, M.SmoothPlastic)
	local deck = r:box('RoofDeck', V(Wh.x0 - Wh.t - 0.6, top + 0.4, Wh.z0 - Wh.t - 0.6), V(Wh.x1 + Wh.t + 0.6, top + 1.4, Wh.z1 + Wh.t + 0.6), K.steel, M.SmoothPlastic)
	for _, e in { { -1, Wh.z0 - Wh.t - 0.6 }, { 1, Wh.z1 + Wh.t + 0.6 } } do
		r:box('RoofLip', V(Wh.x0 - Wh.t - 0.8, top + 1.4, e[2] - 0.5), V(Wh.x1 + Wh.t + 0.8, top + 1.8, e[2] + 0.5), K.trim, M.SmoothPlastic)
	end
	ceiling.CastShadow, deck.CastShadow = false, false
	-- hanging lamps under the trusses either side of the spine (chunky shade, a warm glowing underside)
	local lamps = L:group('HallLamps')
	for z = Wh.z0 + 10, Wh.z1 - 6, 18 do
		for _, x in { -46, 46 } do
			lamps:box('LampRod', V(x - 0.2, 24.6, z - 0.2), V(x + 0.2, y0, z + 0.2), K.drum, M.SmoothPlastic)
			lamps:box('LampShade', V(x - 1.6, 23.4, z - 1.6), V(x + 1.6, 24.6, z + 1.6), K.steel, M.SmoothPlastic)
			local g = lamps:box('LampGlow', V(x - 1.2, 23.1, z - 1.2), V(x + 1.2, 23.4, z + 1.2), K.lamp, M.Neon)
			light(g, K.lamp, 0.6, 26)
		end
	end
	for _, p in lamps.parent:GetDescendants() do
		if p:IsA('BasePart') then decor(p).CastShadow = false end
	end
	return h
end

-- (replaces the plaza's ground) Concrete inside, a grass yard outside, the shell, and the cliffs moved out past it.
function Lobby.hall(L)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local h = L:group('Hall')
	-- the concrete: 16 x 16 slabs in two tones on the spawn's grid, the doorways' thresholds included
	local f = L:group('HallFloor')
	local gx, gz = 16, 16
	local ox, oz = SPAWN.X - 8, SPAWN.Z - 8
	local i0, i1 = math.floor((Wh.x0 - ox) / gx), math.ceil((Wh.x1 - ox) / gx) - 1
	local j0, j1 = math.floor((Wh.z0 - oz) / gz), math.ceil((Wh.z1 - oz) / gz) - 1
	for i = i0, i1 do
		for j = j0, j1 do
			local xa, xb = math.max(Wh.x0, ox + i * gx), math.min(Wh.x1, ox + (i + 1) * gx)
			local za, zb = math.max(Wh.z0, oz + j * gz), math.min(Wh.z1, oz + (j + 1) * gz)
			if xb - xa > 0.01 and zb - za > 0.01 then
				studs(f:box('Concrete', V(xa, -1, za), V(xb, 0, zb), (i + j) % 2 == 0 and K.floorA or K.floorB, M.Plastic))
			end
		end
	end
	for _, d in Wh.open do
		local a, b, w = d[2], d[3], d[1]
		local t
		if w == 'N' then t = f:box('Threshold', V(a, -1, Wh.z0 - Wh.t), V(b, 0, Wh.z0), K.floorB, M.SmoothPlastic)
		elseif w == 'S' then t = f:box('Threshold', V(a, -1, Wh.z1), V(b, 0, Wh.z1 + Wh.t), K.floorB, M.SmoothPlastic)
		elseif w == 'W' then t = f:box('Threshold', V(Wh.x0 - Wh.t, -1, a), V(Wh.x0, 0, b), K.floorB, M.SmoothPlastic)
		else t = f:box('Threshold', V(Wh.x1, -1, a), V(Wh.x1 + Wh.t, 0, b), K.floorB, M.SmoothPlastic) end
		local _ = t
	end
	-- the yard outside: grass all round the shell, out under the cliffs
	local xa, xb, za, zb = Wh.x0 - Wh.t, Wh.x1 + Wh.t, Wh.z0 - Wh.t, Wh.z1 + Wh.t
	for _, r in { { -130, 130, Lobby.N - 1, za }, { -130, 130, zb, 160 }, { -130, xa, za, zb }, { xb, 130, za, zb } } do
		if r[4] - r[3] > 0.5 then studs(h:box('Grass', V(r[1], -1, r[3]), V(r[2], 0, r[4]), K.grass, M.Plastic)) end
	end
	Lobby.warehouse(L, h)
	Lobby.outdoors(L)
	return h
end

-- The plaza's cliffs, trees and hood blocks, built 12 studs further out (past the walls and a grass yard); the north row
-- of cliff tiles goes (the north wall stands there; the stage's street is behind it).
function Lobby.outdoors(L)
	local B, O = Lobby.Bounds, Lobby.WH.off
	local tiles = Lobby.cliffTiles
	Lobby.Bounds = { x = B.x + O, xw = B.xw + O, xe = B.xe + O, n = Lobby.WH.z0 - Lobby.WH.t, s = B.s + O, mouth = B.mouth }
	Lobby.cliffTiles = function(g, a, b, inward, k)
		if inward.Z > 0.5 then return end
		return tiles(g, a, b, inward, k)
	end
	local ok, err = pcall(Lobby.cliffs, L)
	Lobby.Bounds, Lobby.cliffTiles = B, tiles
	if not ok then warn('[Lobby] outdoors: ' .. tostring(err)) end
end

-- (rule 19: no grass inside) the scenery with purpose, only along the walls and round a reason (B34): a hoop by the
-- west door,
-- crates and drums in the two south corners, cones and a hydrant and a bin at the open south doors; trees and bushes
-- out in the yard, framed by the doors. Nothing on a walk, nothing between the zones.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Wh = Lobby.WH
	add('Scn_Hoop', Wh.x0 + 4, 54, -90) -- (by the west door)
	add('Scn_Crate', Wh.x0 + 3.4, Wh.z1 - 3.4, 0) add('Scn_Crate', Wh.x0 + 6.4, Wh.z1 - 3, 12) add('Scn_Barrel', Wh.x0 + 3.6, Wh.z1 - 7.4, 0)
	add('Scn_Crate', Wh.x1 - 3.4, Wh.z1 - 3.4, 0) add('Scn_Barrel', Wh.x1 - 3.6, Wh.z1 - 7.4, 0) add('Scn_Barrel', Wh.x1 - 6.2, Wh.z1 - 3.2, 20)
	for _, d in Wh.open do
		if d[1] == 'S' then add('Scn_Cone', d[2] + 2, Wh.z1 - 2.2, 0) add('Scn_Cone', d[3] - 2, Wh.z1 - 2.2, 0) end
	end
	add('Scn_Hydrant', -50, Wh.z1 - 2.4, 180) add('Scn_TrashCan', 28, Wh.z1 - 2.4, 180)
	-- out in the yard (framed by the doors and the clerestory)
	add('Scn_Tree_1', -56, Wh.z1 + 10, 0) add('Scn_Tree_2', 42, Wh.z1 + 10, 0) add('Scn_Tree_2', Wh.x1 + 12, 15, 0) add('Scn_Tree_1', Wh.x0 - 12, 78, 0)
	for _, x in { -70, -44, 34, 58 } do add('Scn_Bush_1', x, Wh.z1 + 5.6, 0) end
	add('Scn_Bush_1', Wh.x1 + 6, 4, -90) add('Scn_Bush_1', Wh.x1 + 6, 26, -90) add('Scn_Bush_1', Wh.x0 - 6, 64, 90) add('Scn_Bush_1', Wh.x0 - 6, 88, 90)
	return list
end)()
---------------------------------------------------------------------------------------------- the business district plaza (World 2)
-- World 2's lobby (runs after e4_warehouse, so it replaces the warehouse's shell): the same plan as World 1's (e3_plaza:
-- spawn on the spine facing the Stage 1 gate north, the training block west, the gun stand east, the box dais south, the
-- portal SW, the boards SE, the special-sale spots and the chests before the gate), inside the owner's "C" hall
-- (city/e6_hall.lua: its shell, floor and props; the keep-in walls are f_areas' invisible ones on Lobby.Bounds):
--   Outside  a ring street (light stone sidewalks, asphalt with white dashes, taxis and cars) and business district round it (Oct
--            27 round 3, the owner: "make the buildings taller"): glass and warm stone towers 55-95 high on shop podiums
--            (awnings and signs on the street), a diner; they show through the hall's door, windows and skylights.
--   Portal   the way back: a brick arch onto the hood (the travel itself is the services'), where World 1 has its World 2
--            door (SW, its own walk off the south walk); the boards in World 1's straight row SE (see below)
-- The builders below (City.highrise, City.block, City.shopfront, City.diner, City.parking, City.tower, City.taxi, City.bus,
-- City.foodTruck, City.busStop, City.planter, City.lamp) are the avenue's too (city/f5_avenue.lua).

---------------------------------------------------------------------------------------------- city kit
-- A face of an axis-aligned block a0..a1 (x) by b0..b1 (z), as a mapper: box(name, u0, u1, y0, y1, d0, d1, colour, mat)
-- with u along the face (x on N/S, z on E/W) and d outward from it. f: 'N' (-Z), 'S' (+Z), 'W' (-X), 'E' (+X).
function City.face(c, f, a0, a1, b0, b1)
	return function(name, u0, u1, y0, y1, d0, d1, col, mat)
		local A, B
		if f == 'S' then A, B = V(u0, y0, b1 + d0), V(u1, y1, b1 + d1)
		elseif f == 'N' then A, B = V(u0, y0, b0 - d0), V(u1, y1, b0 - d1)
		elseif f == 'E' then A, B = V(a1 + d0, y0, u0), V(a1 + d1, y1, u1)
		else A, B = V(a0 - d0, y0, u0), V(a0 - d1, y1, u1) end
		return c:box(name, A, B, col, mat or M.SmoothPlastic)
	end, (f == 'N' or f == 'S') and a0 or b0, (f == 'N' or f == 'S') and a1 or b1
end
-- The window grid on one face of a glass block: white mullions every `pitch` studs (5 unless set; and at both corners) and a slab edge
-- every 5 studs (one storey), standing a little proud of the glass. Decor, no shadows: a flat clean grid like the
-- reference's buildings.
function City.grid(c, f, a0, a1, b0, b1, ya, yb, pitch)
	local box, u0, u1 = City.face(c, f, a0, a1, b0, b1)
	local function bar(name, ua, ub, y0, y1, d)
		local p = decor(box(name, ua, ub, y0, y1, 0, d, City.mullion))
		p.CastShadow = false
		return p
	end
	bar('Mullion', u0, u0 + 0.5, ya, yb, 0.3)
	bar('Mullion', u1 - 0.5, u1, ya, yb, 0.3)
	local n = math.max(1, math.floor((u1 - u0) / pitch + 0.5))
	local step = (u1 - u0) / n
	for k = 1, n - 1 do
		local u = u0 + k * step
		bar('Mullion', u - 0.22, u + 0.22, ya, yb, 0.25)
	end
	for y = ya + 5, yb - 1, 5 do bar('FloorSlab', u0, u1, y - 0.25, y + 0.25, 0.35) end
end
-- A glass tower over block x0..x1, z0..z1 (this frame), h high: a warm studded stone base (baseH, with a pale cornice),
-- the glass body inset 0.8 with its window grid on `faces`, a steel parapet, a plant room on the roof; a setback (studs)
-- steps the top third in. door: the face with the lobby's glass doors and canopy. tone picks the glass and the stone.
function City.tower(c, x0, x1, z0, z1, h, o)
	o = o or {}
	local t, model = c:group(o.name or 'Tower')
	local k = o.tone or 1
	local gl, base = City.glass[(k - 1) % #City.glass + 1], City.base[(k - 1) % #City.base + 1]
	local bh = o.baseH or 8
	local faces = o.faces or { 'N', 'S', 'E', 'W' }
	sbox(t, 'TowerBase', V(x0, -1, z0), V(x1, bh, z1), base)
	decor(sbox(t, 'TowerCornice', V(x0 - 0.4, bh, z0 - 0.4), V(x1 + 0.4, bh + 0.8, z1 + 0.4), base:Lerp(P.white, 0.45))).CastShadow = false
	local function body(a0, a1, b0, b1, ya, yb)
		t:box('TowerGlass', V(a0, ya, b0), V(a1, yb, b1), gl, M.SmoothPlastic)
		for _, f in faces do City.grid(t, f, a0, a1, b0, b1, ya, yb, o.pitch or 5) end
		decor(t:box('TowerParapet', V(a0 - 0.3, yb, b0 - 0.3), V(a1 + 0.3, yb + 1.2, b1 + 0.3), City.roof, M.SmoothPlastic))
	end
	local i, y0 = 0.8, bh + 0.8
	local a0, a1, b0, b1 = x0 + i, x1 - i, z0 + i, z1 - i
	if o.setback and h - y0 > 30 then
		local ys = math.floor((y0 + (h - y0) * 0.64) / 5) * 5 + 0.8
		body(a0, a1, b0, b1, y0, ys)
		local s = o.setback
		a0, a1, b0, b1 = a0 + s, a1 - s, b0 + s, b1 - s
		body(a0, a1, b0, b1, ys + 1.2, h)
	else
		body(a0, a1, b0, b1, y0, h)
	end
	-- the roof: a plant room and, on the tall ones, a mast with a red tip
	local cx, cz = (a0 + a1) / 2, (b0 + b1) / 2
	local rw, rd = math.min(7, (a1 - a0) / 3), math.min(6, (b1 - b0) / 3)
	decor(t:box('RoofPlant', V(cx - rw, h + 1.2, cz - rd), V(cx + rw, h + 5, cz + rd), City.roofDark, M.SmoothPlastic))
	if h >= 90 then
		decor(t:box('RoofMast', V(cx - 0.4, h + 5, cz - 0.4), V(cx + 0.4, h + 16, cz + 0.4), City.steel, M.SmoothPlastic))
		decor(t:box('RoofMastTip', V(cx - 0.6, h + 16, cz - 0.6), V(cx + 0.6, h + 17, cz + 0.6), C(240, 60, 50), M.SmoothPlastic))
	end
	if o.door then City.entrance(t, o.door, x0, x1, z0, z1, bh, o.doorAt) end
	if o.noShadow then
		for _, p in model:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = false end end
	end
	return t, model
end
---------------------------------------------------------------------------------------------- business district highrises
-- (Oct 27 round 3, the owner: "make the buildings taller, make it the size of the first world, and then make the look in
-- general way better") the Business District's towers: a warm studded stone podium (one shop storey, 8 high, with shopfronts,
-- striped awnings and signs on its street faces), and over it either a glass body (sky-blue, teal or violet glass in a
-- white mullion grid) or a warm painted stone one (a window band each storey, piers over them), a bright crown band and
-- a plant room on the roof (a mast with a red tip from 110 up). A storey is 5 studs. Only the podium casts a shadow
-- unless o.shadow.
City.Stone = { C(240, 214, 170), C(232, 170, 124), C(246, 232, 204), C(214, 150, 120), C(236, 196, 140), C(222, 184, 160) }
City.Crown = { C(232, 64, 60), C(48, 140, 220), C(40, 170, 110), C(250, 180, 40), C(150, 90, 210), C(255, 120, 60) }
-- One window band a storey on face f of a stone body, and piers over them every ~7 studs (and at both corners).
function City.ribbons(c, f, a0, a1, b0, b1, ya, yb, trim)
	local box, u0, u1 = City.face(c, f, a0, a1, b0, b1)
	local function d(p) decor(p).CastShadow = false return p end
	for y = ya + 1.2, yb - 3.6, 5 do d(box('WindowBand', u0 + 0.8, u1 - 0.8, y, y + 2.8, 0, 0.15, City.WindowGlass)) end
	local n = math.max(1, math.floor((u1 - u0) / 7 + 0.5))
	for q = 0, n do
		local u = u0 + (u1 - u0) * q / n
		d(box('Pier', math.max(u0, u - 0.55), math.min(u1, u + 0.55), ya, yb, 0, 0.3, trim))
	end
end
-- A highrise over x0..x1, z0..z1 (this frame), h high. o: kind ('glass' | 'stone'), tone, faces (window faces), shops
-- (podium faces with shopfronts), setback (studs the top third steps in), podium (its height, 8), shadow, name, word;
-- stone, glassColor, crown (colour overrides) and neon (a glowing strip up each corner, its colour).
function City.highrise(c, x0, x1, z0, z1, h, o)
	o = o or {}
	local t, model = c:group(o.name or 'Highrise')
	local k = o.tone or 1
	local kind = o.kind or 'glass'
	local ph = o.podium or 8
	local stone = o.stone or City.Stone[(k - 1) % #City.Stone + 1]
	local gl = o.glassColor or City.glass[(k - 1) % #City.glass + 1]
	local crown = o.crown or City.Crown[(k - 1) % #City.Crown + 1]
	local trim = stone:Lerp(P.white, 0.55)
	local faces = o.faces or { 'S' }
	local podium = sbox(t, 'Podium', V(x0, -1, z0), V(x1, ph, z1), kind == 'glass' and City.base[(k - 1) % #City.base + 1] or stone:Lerp(P.black, 0.08))
	decor(sbox(t, 'PodiumCornice', V(x0 - 0.4, ph, z0 - 0.4), V(x1 + 0.4, ph + 0.8, z1 + 0.4), trim)).CastShadow = false
	for n, f in o.shops or {} do City.shopfront(t, f, x0, x1, z0, z1, k + n, n == 1 and o.word or nil) end
	local function mass(a0, a1, b0, b1, ya, yb)
		if kind == 'glass' then
			t:box('TowerGlass', V(a0, ya, b0), V(a1, yb, b1), gl, M.SmoothPlastic)
			for _, f in faces do City.grid(t, f, a0, a1, b0, b1, ya, yb, o.pitch or 5) end
		else
			t:box('TowerStone', V(a0, ya, b0), V(a1, yb, b1), stone, M.SmoothPlastic)
			for _, f in faces do City.ribbons(t, f, a0, a1, b0, b1, ya, yb, trim) end
		end
		-- the top: a bright belt round the last storey and a calm light parapet over the roof (seen from above, the
		-- roofs stay quiet)
		decor(t:box('TowerBelt', V(a0 - 0.35, yb - 1.6, b0 - 0.35), V(a1 + 0.35, yb - 0.2, b1 + 0.35), crown, M.SmoothPlastic))
		decor(t:box('TowerCrown', V(a0 - 0.3, yb, b0 - 0.3), V(a1 + 0.3, yb + 1.6, b1 + 0.3), C(214, 218, 228), M.SmoothPlastic))
		-- o.neon: a steady glowing strip up each corner (the luxury district's pink)
		if o.neon then
			for _, q in { { a0, b0 }, { a0, b1 }, { a1, b0 }, { a1, b1 } } do
				decor(t:box('TowerNeon', V(q[1] - 0.45, ya, q[2] - 0.45), V(q[1] + 0.45, yb - 1.6, q[2] + 0.45), o.neon, M.Neon)).CastShadow = false
			end
		end
	end
	local i, y0 = 1.2, ph + 0.8
	local a0, a1, b0, b1 = x0 + i, x1 - i, z0 + i, z1 - i
	if o.setback and h - y0 > 40 then
		local ys = math.floor((y0 + (h - y0) * 0.62) / 5) * 5 + 0.8
		mass(a0, a1, b0, b1, y0, ys)
		local sb = o.setback
		a0, a1, b0, b1 = a0 + sb, a1 - sb, b0 + sb, b1 - sb
		mass(a0, a1, b0, b1, ys + 1.6, h)
	else
		mass(a0, a1, b0, b1, y0, h)
	end
	local cx, cz = (a0 + a1) / 2, (b0 + b1) / 2
	local rw, rd = math.min(6, (a1 - a0) / 3), math.min(5, (b1 - b0) / 3)
	decor(t:box('RoofPlant', V(cx - rw, h + 1.6, cz - rd), V(cx + rw, h + 5.2, cz + rd), City.roofDark, M.SmoothPlastic))
	if h >= 110 then
		decor(t:box('RoofMast', V(cx - 0.4, h + 5.2, cz - 0.4), V(cx + 0.4, h + 18, cz + 0.4), City.steel, M.SmoothPlastic))
		decor(t:box('RoofMastTip', V(cx - 0.7, h + 18, cz - 0.7), V(cx + 0.7, h + 19.4, cz + 0.7), C(240, 60, 50), M.SmoothPlastic))
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p ~= podium and not o.shadow then p.CastShadow = false end
	end
	if o.noShadow then podium.CastShadow = false end
	return t, model
end
-- The lobby doors on face f of a tower's base: a dark glass front (white frames), a steel canopy over it, two planters.
function City.entrance(c, f, x0, x1, z0, z1, bh, at)
	local box, u0, u1 = City.face(c, f, x0, x1, z0, z1)
	local m = at or (u0 + u1) / 2
	local w = math.min(6, (u1 - u0) / 2 - 2)
	box('LobbyGlass', m - w, m + w, 0, bh - 1.6, -0.1, 0.12, City.doorGlass)
	for _, u in { m - w, m - w / 3, m + w / 3, m + w } do decor(box('LobbyFrame', u - 0.25, u + 0.25, 0, bh - 1.6, 0, 0.3, City.mullion)).CastShadow = false end
	decor(box('LobbyFrame', m - w, m + w, bh - 1.9, bh - 1.6, 0, 0.3, City.mullion)).CastShadow = false
	local can = box('Canopy', m - w - 1.5, m + w + 1.5, bh - 1.6, bh - 0.9, 0, 3.2, City.steel)
	decor(can)
	decor(box('CanopyEdge', m - w - 1.5, m + w + 1.5, bh - 1.75, bh - 0.75, 3.0, 3.4, City.yellow))
end
-- A raised stone planter with a trimmed tree (pos: its centre on the ground), or a hedge in it when w > 7.
function City.planter(c, pos, seed, w, d)
	w, d = w or 5, d or 5
	local g = c:at(CFrame.new(pos)):group('Planter')
	sbox(g, 'PlanterBox', V(-w / 2, 0, -d / 2), V(w / 2, 1.6, d / 2), City.clay)
	decor(sbox(g, 'PlanterCap', V(-w / 2 - 0.2, 1.6, -d / 2 - 0.2), V(w / 2 + 0.2, 1.9, d / 2 + 0.2), City.clayCap)).CastShadow = false
	if w > 7 or d > 7 then
		sbox(g, 'Hedge', V(-w / 2 + 0.5, 1.9, -d / 2 + 0.5), V(w / 2 - 0.5, 3.4, d / 2 - 0.5), City.hedge)
		decor(sbox(g, 'HedgeTop', V(-w / 2 + 0.9, 3.4, -d / 2 + 0.9), V(w / 2 - 0.9, 3.9, d / 2 - 0.9), City.hedgeTop))
	else
		tree(g, V(0, 1.9, 0), seed, 0.62, nil, true)
	end
	return g
end
-- A tall modern street lamp at pos, its arm reaching `dir` (+1 / -1 in x) over the road: a slim steel pole, a long arm,
-- a white LED head (a soft glow, no light pool: the look keeps lamps faint).
function City.lamp(c, pos, dir)
	local g = c:at(CFrame.new(pos)):group('CityLamp')
	sbox(g, 'LampFoot', V(-0.8, 0, -0.8), V(0.8, 0.8, 0.8), City.steelDark)
	g:box('LampPole', V(-0.3, 0.8, -0.3), V(0.3, 13, 0.3), City.steel, M.SmoothPlastic)
	g:box('LampArm', V(math.min(0, dir * 5), 12.6, -0.25), V(math.max(0, dir * 5), 13.1, 0.25), City.steel, M.SmoothPlastic)
	g:box('LampHead', V(dir * 3.4, 12.2, -0.6), V(dir * 5.6, 12.7, 0.6), City.steelDark, M.SmoothPlastic)
	decor(g:box('LampLED', V(dir * 3.6, 12.05, -0.45), V(dir * 5.4, 12.2, 0.45), C(255, 250, 230), M.Neon)).CastShadow = false
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'LampFoot' and p.Name ~= 'LampPole' then decor(p) end end
	return g
end
-- A yellow taxi (the kit's car, cf: its centre on the ground, front -Z) with a lit TAXI roof sign and a checker band.
function City.taxi(c, cf)
	local k = car(c, cf, City.taxiYellow)
	local sign = k:box('TaxiSign', V(-1.1, 4.6, -0.2), V(1.1, 5.5, 0.9), P.white, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(sign, face, 20), 'Taxi', 'TAXI', C(30, 30, 34), FONT.title, 0.05, 0.9) end
	for _, sx in { -1, 1 } do
		for z = -4.8, 4.4, 1.2 do
			decor(k:box('TaxiCheck', V(sx * 2.3, 2.2, z), V(sx * 2.36, 2.6, z + 0.6), C(30, 30, 34), M.SmoothPlastic)).CastShadow = false
		end
	end
	return k
end
-- A city bus (cf: its centre on the ground, front -Z, 24 long): a white body with a coloured belt, a band of dark
-- windows, the destination board in front.
function City.bus(c, cf, color)
	local b = c:at(cf):group('Bus')
	for _, sx in { -2.4, 2.4 } do
		for _, z in { -7.5, 7.5 } do b:part('Wheel', V(0.9, 2.4, 2.4), CFrame.new(sx, 1.2, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
	b:box('BusBody', V(-2.6, 1, -12), V(2.6, 9, 12), P.white, M.SmoothPlastic)
	b:box('BusBelt', V(-2.65, 1.6, -12.05), V(2.65, 3.6, 12.05), color, M.SmoothPlastic)
	decor(b:box('BusWindows', V(-2.7, 4.6, -11), V(2.7, 7.8, 11), C(52, 76, 112), M.SmoothPlastic))
	decor(b:box('BusWindscreen', V(-2.3, 3.8, -12.1), V(2.3, 7.8, -12.05), C(52, 76, 112), M.SmoothPlastic))
	b:box('BusRoof', V(-2.4, 9, -10), V(2.4, 9.6, 10), C(222, 226, 236), M.SmoothPlastic)
	local board = b:box('BusBoard', V(-1.9, 8.0, -12.2), V(1.9, 8.8, -12.05), C(30, 32, 40), M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Front, 30), 'Route', '1 BUSINESS DIST', C(255, 190, 40), FONT.title, 0.08, 0.84)
	for _, x in { -1.8, 1.0 } do decor(b:box('Headlight', V(x, 2.2, -12.15), V(x + 0.8, 2.8, -12.05), C(255, 244, 200), M.Neon)) end
	return b
end
-- A food truck (cf: its centre on the ground, front -Z, serving hatch on its +X side): a coloured box van with a cab, a
-- striped awning over the open hatch, a counter, a roof sign with its food.
function City.foodTruck(c, cf, color, word)
	local t = c:at(cf):group('FoodTruck')
	for _, sx in { -2.4, 2.4 } do
		for _, z in { -6.2, 4.4 } do t:part('Wheel', V(0.9, 2.2, 2.2), CFrame.new(sx, 1.1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
	t:box('TruckBody', V(-2.7, 1, -4.5), V(2.7, 8, 7), color, M.SmoothPlastic)
	t:box('TruckCab', V(-2.6, 1, -8.6), V(2.6, 5.6, -4.5), color:Lerp(P.white, 0.25), M.SmoothPlastic)
	decor(t:box('CabGlass', V(-2.3, 3.6, -8.7), V(2.3, 5.3, -8.55), C(52, 76, 112), M.SmoothPlastic))
	t:box('Hatch', V(2.6, 3.4, -2.6), V(2.75, 6.6, 5.4), C(54, 46, 50), M.SmoothPlastic)
	t:box('Counter', V(2.7, 3.2, -2.8), V(3.6, 3.5, 5.6), P.white, M.SmoothPlastic)
	for k = 0, 3 do
		decor(t:box('Awning', V(2.7, 6.8, -2.8 + k * 2.1), V(4.6, 7.2, -0.7 + k * 2.1), k % 2 == 0 and P.white or C(240, 64, 60), M.SmoothPlastic))
	end
	local sign = t:box('TruckSign', V(-0.2, 8, -4.2), V(0.2, 10.2, 6.6), P.white, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		line(surface(sign, face, 16), 'Food', word, color:Lerp(P.black, 0.25), FONT.title, 0.08, 0.84, P.white, 2)
	end
	return t
end
-- A bus stop shelter (cf: the middle of its back on the ground, open toward -Z): steel posts, a pale glass back, a roof,
-- a bench, the BUS sign on a pole.
function City.busStop(c, cf)
	local s = c:at(cf):group('BusStop')
	for _, x in { -4.6, 4.6 } do s:box('ShelterPost', V(x - 0.25, 0, -2.6), V(x + 0.25, 8, 0.3), City.steelDark, M.SmoothPlastic) end
	local glass = s:box('ShelterGlass', V(-4.4, 0.6, -0.1), V(4.4, 7.6, 0.1), C(200, 230, 250), M.SmoothPlastic)
	glass.Transparency = 0.45
	s:box('ShelterRoof', V(-5.2, 8, -3.2), V(5.2, 8.6, 0.6), City.steel, M.SmoothPlastic)
	decor(s:box('ShelterRoofEdge', V(-5.2, 8.6, -3.2), V(5.2, 8.9, -2.8), City.yellow, M.SmoothPlastic))
	s:box('ShelterBench', V(-3.6, 1.6, -1.4), V(3.6, 2.0, -0.2), C(196, 132, 76), M.SmoothPlastic)
	s:box('ShelterPole', V(5.6, 0, -2.9), V(6.0, 10.5, -2.5), City.steel, M.SmoothPlastic)
	local plate = s:box('BusSign', V(5.0, 9, -3.0), V(6.6, 10.8, -2.4), C(40, 120, 220), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 30), 'Bus', 'BUS', P.white, FONT.title, 0.1, 0.8)
	return s
end

---------------------------------------------------------------------------------------------- pre-business district blocks
-- (Oct 27 round 2, the owner: "make the second world not such high buildings ... make like pre downtown") The city's
-- buildings are 2-5 storey mid-rise blocks in warm saturated paint and brick, busy at street level: shops with striped
-- awnings and signs, apartments with rows of windows, small offices with ribbon windows, a corner diner, a parking lot.
-- Glass towers only as two far landmarks. A storey is 5 studs; a shop's ground floor 8 (glass, awning, sign).
City.Paint = { C(232, 112, 84), C(244, 186, 72), C(84, 176, 170), C(120, 170, 232), C(236, 132, 170), C(132, 200, 120), C(246, 224, 182), C(200, 104, 74) }
City.Awnings = { C(232, 64, 60), C(48, 140, 220), C(40, 170, 110), C(250, 180, 40), C(150, 90, 210) }
City.Words = { 'BAKERY', 'PIZZA', 'BOOKS', 'CAFE', 'MARKET', 'TOYS', 'SHOES', 'DONUTS', 'GAMES', 'FLOWERS', 'MUSIC', 'SPORTS' }
City.WindowGlass, City.ShopGlass = C(150, 206, 246), C(56, 84, 124)
-- A shopfront on face f of a block x0..x1, z0..z1 (this frame): the shop glass in white frames, a striped awning at 5.2,
-- a white sign with the shop's word in the awning's colour (tone k picks both). The ground floor is 8 high.
function City.shopfront(t, f, x0, x1, z0, z1, k, word)
	local function d(p) decor(p).CastShadow = false return p end
	local box, u0, u1 = City.face(t, f, x0, x1, z0, z1)
	local bays = math.max(1, math.floor((u1 - u0) / 5.5))
	local awn = City.Awnings[(k - 1) % #City.Awnings + 1]
	d(box('ShopGlass', u0 + 1, u1 - 1, 0.9, 5.2, 0, 0.12, City.ShopGlass))
	for b = 0, bays do d(box('ShopFrame', u0 + 1 + b * (u1 - u0 - 2) / bays - 0.2, u0 + 1 + b * (u1 - u0 - 2) / bays + 0.2, 0.9, 5.2, 0, 0.25, P.white)) end
	for b = 0, bays * 2 - 1 do
		local a0 = u0 + 1 + b * (u1 - u0 - 2) / (bays * 2)
		d(box('Awning', a0, a0 + (u1 - u0 - 2) / (bays * 2), 5.2, 5.8, 0, 2.6, b % 2 == 0 and awn or P.white))
	end
	local w = math.min(u1 - u0 - 4, 14)
	local m = (u0 + u1) / 2
	local sign = box('ShopSign', m - w / 2, m + w / 2, 5.95, 7.45, 0, 0.3, P.white)
	decor(sign)
	local face = ({ S = Enum.NormalId.Back, N = Enum.NormalId.Front, E = Enum.NormalId.Right, W = Enum.NormalId.Left })[f]
	line(surface(sign, face, 12), 'Shop', word or City.Words[(k - 1) % #City.Words + 1], awn:Lerp(P.black, 0.15), FONT.title, 0.06, 0.88, P.white, 2)
end
-- One block over x0..x1, z0..z1 (this frame). o.kind: 'shop' (shopfronts under an awning and a sign, flats over them),
-- 'flats' (a plain ground floor with a door, windows above), 'office' (ribbon windows); o.floors: storeys over the ground
-- floor; o.tone picks the paint, the awning and the sign's word; o.faces: the faces with windows (the ones you see).
function City.block(c, x0, x1, z0, z1, o)
	local t, model = c:group(o.name or 'Block')
	local k = o.tone or 1
	local col = o.color or City.Paint[(k - 1) % #City.Paint + 1]
	local trim = o.trim or col:Lerp(P.white, 0.6)
	local kind = o.kind or 'flats'
	local g = kind == 'shop' and 8 or 6
	local n = o.floors or 2
	local top = g + n * 5
	sbox(t, 'BlockBody', V(x0, -1, z0), V(x1, top, z1), col)
	local function d(p) decor(p).CastShadow = false return p end
	d(sbox(t, 'BlockPlinth', V(x0 - 0.2, -1, z0 - 0.2), V(x1 + 0.2, 0.9, z1 + 0.2), col:Lerp(P.black, 0.22)))
	d(sbox(t, 'BlockBand', V(x0 - 0.25, g - 0.5, z0 - 0.25), V(x1 + 0.25, g, z1 + 0.25), trim))
	d(sbox(t, 'BlockCornice', V(x0 - 0.5, top, z0 - 0.5), V(x1 + 0.5, top + 1, z1 + 0.5), trim))
	for _, f in o.faces or { 'S' } do
		local box, u0, u1 = City.face(t, f, x0, x1, z0, z1)
		local bays = math.max(1, math.floor((u1 - u0) / 5.5))
		local bw = (u1 - u0) / bays
		-- the storeys over the ground floor
		for fl = 0, n - 1 do
			local y = g + fl * 5 + 1.1
			if kind == 'office' then
				d(box('Ribbon', u0 + 1, u1 - 1, y, y + 3, 0, 0.15, City.WindowGlass))
				for b = 1, bays - 1 do d(box('RibbonMullion', u0 + b * bw - 0.2, u0 + b * bw + 0.2, y, y + 3, 0, 0.25, trim)) end
			else
				for b = 0, bays - 1 do
					local m = u0 + (b + 0.5) * bw
					d(box('Window', m - 1.3, m + 1.3, y, y + 2.9, 0, 0.15, City.WindowGlass))
					d(box('Sill', m - 1.6, m + 1.6, y - 0.35, y, 0, 0.4, trim))
				end
			end
		end
		-- the ground floor
		if kind == 'shop' then
			City.shopfront(t, f, x0, x1, z0, z1, k, o.word)
		elseif kind == 'office' then
			d(box('LobbyGlass', u0 + 1, u1 - 1, 0.9, g - 1.2, 0, 0.12, City.ShopGlass))
		else
			local m = (u0 + u1) / 2
			d(box('Door', m - 1.4, m + 1.4, 0.9, 5, 0, 0.15, col:Lerp(P.black, 0.45)))
			d(box('DoorHood', m - 2, m + 2, 5, 5.4, 0, 1.2, trim))
			for b = 0, bays - 1 do
				local wm = u0 + (b + 0.5) * bw
				if math.abs(wm - m) > 3 then d(box('Window', wm - 1.3, wm + 1.3, 2, 4.6, 0, 0.15, City.WindowGlass)) end
			end
		end
	end
	-- on the roof: a plant box, and a water tank on every other block
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	d(t:box('RoofBox', V(cx - 3, top + 1, cz - 2.5), V(cx + 3, top + 3.2, cz + 2.5), C(150, 156, 172), M.SmoothPlastic))
	if k % 2 == 0 then
		d(t:box('TankLegs', V(cx + 4, top + 1, cz - 1), V(cx + 6, top + 3, cz + 1), C(110, 80, 60), M.SmoothPlastic))
		d(t:box('Tank', V(cx + 3.6, top + 3, cz - 1.4), V(cx + 6.4, top + 6, cz + 1.4), C(170, 112, 76), M.SmoothPlastic))
	end
	if o.noShadow then for _, p in model:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = false end end end
	return t, model
end
-- A corner diner (cf: the middle of its front on the ground, front -Z, 26 wide, 12 deep): one storey in cream with a red
-- band, a long window, a chrome roof edge, DINER on posts over the roof.
function City.diner(c, cf)
	local t = c:at(cf):group('Diner')
	sbox(t, 'DinerBody', V(-13, -1, 0), V(13, 7, 12), C(250, 236, 206))
	decor(sbox(t, 'DinerBand', V(-13.2, 1, -0.2), V(13.2, 2.2, 12.2), C(226, 56, 56))).CastShadow = false
	decor(t:box('DinerWindow', V(-11, 2.6, -0.15), V(7, 5.8, 0), C(56, 84, 124), M.SmoothPlastic)).CastShadow = false
	decor(t:box('DinerDoor', V(8.5, 0.9, -0.15), V(11.5, 5.8, 0), C(226, 56, 56), M.SmoothPlastic)).CastShadow = false
	decor(t:box('DinerRoofEdge', V(-13.5, 7, -0.5), V(13.5, 7.8, 12.5), C(206, 214, 228), M.SmoothPlastic)).CastShadow = false
	for _, x in { -6, 6 } do decor(t:box('SignPost', V(x - 0.3, 7.8, 4), V(x + 0.3, 10, 4.6), C(206, 214, 228), M.SmoothPlastic)) end
	local sign = t:box('DinerSign', V(-9, 10, 3.9), V(9, 14, 4.5), C(226, 56, 56), M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Front, 10), 'Diner', 'DINER', P.white, FONT.title, 0.08, 0.84, C(120, 20, 20), 3)
	decor(sign)
	return t
end
-- A parking lot over x0..x1, z0..z1, its top at y: asphalt with white bays across it, a pale kerb on three sides (open to
-- the street on `open`'s side), a few cars, the P sign.
function City.parking(c, x0, x1, z0, z1, seed, y, openX)
	local t = c:group('ParkingLot')
	sbox(t, 'Lot', V(x0, -1, z0), V(x1, y, z1), City.road:Lerp(P.white, 0.1))
	local kx = openX == x0 and x1 - 0.8 or x0
	for _, e in { { V(x0, -1, z0), V(x1, y + 0.4, z0 + 0.8) }, { V(x0, -1, z1 - 0.8), V(x1, y + 0.4, z1) }, { V(kx, -1, z0), V(kx + 0.8, y + 0.4, z1) } } do
		decor(sbox(t, 'LotKerb', e[1], e[2], City.kerb)).CastShadow = false
	end
	local r = Random.new(seed)
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), City.taxiYellow, C(120, 210, 90) }
	for z = z0 + 2, z1 - 6, 6 do
		decor(sbox(t, 'BayLine', V(x0 + 2, y, z), V(x1 - 2, y + 0.1, z + 0.3), City.line)).CastShadow = false
		if r:NextNumber() < 0.65 then
			local side = r:NextNumber() < 0.5 and 0.25 or 0.75
			car(t, CFrame.new(x0 + (x1 - x0) * side, y, z + 3.15) * CFrame.Angles(0, math.pi / 2, 0), cars[r:NextInteger(1, #cars)])
		end
	end
	local px = openX == x0 and x0 + 1.4 or x1 - 1.4
	t:box('ParkPole', V(px - 0.2, y, z0 + 1.4), V(px + 0.2, y + 9, z0 + 1.8), City.steel, M.SmoothPlastic)
	local plate = t:box('ParkSign', V(px - 1.4, y + 9, z0 + 1.5), V(px + 1.4, y + 11.8, z0 + 1.7), C(40, 110, 220), M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(plate, face, 20), 'P', 'P', P.white, FONT.title, 0.05, 0.9) end
	return t
end

---------------------------------------------------------------------------------------------- the plaza
-- the Business District's ring street round the plaza (map frame): the plaza's sidewalk x 88.5..96 (south: from the hedge's outer face
-- 5.5 deep), the road 96..110 (south: 12 wide), the far sidewalk 6 wide, the towers past it on a paved base (over
-- f_areas' lots). Its levels: the road's top 0.5, the sidewalks' 0.95; the plaza's floor is 0, behind its hedge. North of
-- z = 0 the side streets go on up the whole avenue with the towers along them (City.skylineFar, f5_avenue).
-- (Oct 27 round 3, the owner: "make the buildings taller") the blocks round the plaza are towers now: glass and warm stone
-- on shop podiums, 55-95 high, their shops on the street.
City.Ring = { walk0 = 88.5, road0 = 96, road1 = 110, walk1 = 116, north = 0, road = 0.5, walk = 0.95 }
City.Blocks = {
	-- { z0, z1, kind, height, tone } along the far side of the side streets (x 116..150; the west takes other tones)
	-- (Oct 27 round 5, the owner: "make way less buildings": one tower a side and two to the south, gaps between; was 14)
	east = { { 34, 62, 'glass', 85, 1 } },
	-- { x0, x1, kind, height, tone } along the south street's far side (z from the far sidewalk, 30 deep)
	south = { { -80, -52, 'stone', 70, 6 }, { 52, 80, 'glass', 90, 3 } },
}
function City.skyline(L)
	local g = L:group('Surroundings')
	local R, Wh = City.Ring, Lobby.WH
	local RY, WY = R.road, R.walk
	local zs = Wh.z1 + 2.5 -- the hall's outer face, south
	local zr0, zr1 = zs + 5.5, zs + 17.5 -- the south road
	local zf = zr1 + 6 -- the far sidewalk's back
	City.Ring.zf = zf
	local function walk(a, b) sbox(g, 'Sidewalk', a, b, City.walk) end
	local function road(a, b) sbox(g, 'Road', a, b, City.road) end
	local function kerb(a, b) decor(sbox(g, 'KerbStone', a, b, City.kerb)).CastShadow = false end
	local function paint(a, b) decor(sbox(g, 'RoadLine', a, b, City.line)).CastShadow = false end
	local base = City.walk:Lerp(City.road, 0.25)
	-- the side streets and the south street meet in an L at each corner: each sidewalk and road ends where the other's
	-- begins, a kerb along every road edge, the kerbs meeting at the corners
	for _, s in { -1, 1 } do
		local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local a, b = X(R.walk0, R.road0)
		walk(V(a, -1, R.north), V(b, WY, zr0))
		a, b = X(R.road0, R.road1)
		road(V(a, -1, R.north), V(b, RY, zr0))
		a, b = X(R.road1, R.walk1)
		walk(V(a, -1, R.north), V(b, WY, zr1))
		-- along the plaza's north edge, from the avenue's towers to the side street's sidewalk
		a, b = X(36, R.walk0)
		walk(V(a, -1, 0), V(b, WY, Wh.z0 - 2.5))
		kerb(V(s * (R.road0 - 0.6), -0.5, R.north), V(s * (R.road0 + 0.6), WY + 0.1, zr0 - 0.6))
		kerb(V(s * (R.road1 - 0.6), -0.5, R.north), V(s * (R.road1 + 0.6), WY + 0.1, zr1 + 0.6))
		for z = R.north + 4, zr0 - 16, 12 do paint(V(s * 102.7, RY, z), V(s * 103.3, RY + 0.12, z + 5)) end
		-- a crosswalk over the side street where it meets the south one: the plaza's sidewalk to the far one
		for k = 0, 4 do paint(V(s * (R.road0 + 1.2 + k * 2.6), RY, zr0 - 7), V(s * (R.road0 + 2.6 + k * 2.6), RY + 0.12, zr0 - 1.5)) end
		-- the towers' paved base (their alleys and forecourts), behind the far sidewalk
		a, b = X(R.walk1, 206)
		sbox(g, 'CityBase', V(a, -1, R.north), V(b, WY, zf + 30), base)
	end
	walk(V(-R.walk0, -1, zs), V(R.walk0, WY, zr0))
	road(V(-R.road1, -1, zr0), V(R.road1, RY, zr1))
	walk(V(-R.walk1, -1, zr1), V(R.walk1, WY, zf))
	sbox(g, 'CityBase', V(-R.walk1, -1, zf), V(R.walk1, WY, zf + 30), base)
	kerb(V(-(R.road0 + 0.6), -0.5, zr0 - 0.6), V(R.road0 + 0.6, WY + 0.1, zr0 + 0.6))
	kerb(V(-(R.road1 + 0.6), -0.5, zr1 - 0.6), V(R.road1 + 0.6, WY + 0.1, zr1 + 0.6))
	for x = -106, 100, 12 do paint(V(x, RY, (zr0 + zr1) / 2 - 0.3), V(x + 5, RY + 0.12, (zr0 + zr1) / 2 + 0.3)) end
	-- the towers, their shops on the street (no shadows over the plaza)
	local bx0, bx1 = R.walk1, R.walk1 + 34
	local t = g:at(CFrame.new(0, WY, 0))
	for _, s in { -1, 1 } do
		local street = s > 0 and 'W' or 'E'
		for _, b in City.Blocks.east do
			local x0, x1 = math.min(s * bx0, s * bx1), math.max(s * bx0, s * bx1)
			local tone = b[5] + (s > 0 and 0 or 3)
			City.highrise(t, x0, x1, b[1], b[2], b[4] + (s > 0 and 0 or 10), { kind = b[3], tone = tone, faces = { street, 'S' }, shops = { street }, setback = b[4] >= 80 and 3 or nil, noShadow = true, name = 'Tower' })
		end
	end
	for _, b in City.Blocks.south do City.highrise(t, b[1], b[2], zf, zf + 30, b[4], { kind = b[3], tone = b[5], faces = { 'N' }, shops = { 'N' }, setback = b[4] >= 80 and 3 or nil, noShadow = true, name = 'Tower' }) end
	-- the corner diner between the south towers, on the spine's line behind the box dais
	City.diner(t, CFrame.new(0, 0, zf + 0.5))
	-- the street's life: taxis and cars at the kerbs, trees in planters and lamps along the plaza's sidewalks
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), C(120, 210, 90) }
	for k, z in { 6, 52, 88 } do
		for _, s in { -1, 1 } do
			local cf = CFrame.new(s * 99, RY, z + (s > 0 and 14 or 0)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0)
			if (k + (s > 0 and 1 or 0)) % 2 == 0 then City.taxi(g, cf) else car(g, cf, cars[k]) end
		end
	end
	for k, x in { -70, -20, 44, 86 } do
		local cf = CFrame.new(x, RY, zr0 + 3) * CFrame.Angles(0, math.pi / 2, 0)
		if k % 2 == 1 then City.taxi(g, cf) else car(g, cf, cars[k]) end
	end
	for _, s in { -1, 1 } do
		for z = 14, 90, 19 do City.planter(g, V(s * 92.2, WY, z), 700 + z + (s > 0 and 3 or 0)) end
		for z = 23.5, 80, 19 do City.lamp(g, V(s * 94.6, WY, z), s) end
	end
	for x = -80, 80, 20 do City.planter(g, V(x, WY, zs + 2.75), 760 + x, 3.6, 3.6) end
	return g
end
-- (Oct 27, the owner's "C" for World 2's lobby) The hall round the plan, its floor and its props: city/e6_hall.lua
-- (it calls City.skyline, so business district stands round the hall's walls).

-- (Oct 27 round 3, the owner: "please make the leaderboards not be behind each other") The portal and the boards stand
-- where World 1's do (e3_plaza's Lobby.Plan): the portal SW off the south walk on its own path; the three boards in one
-- straight row past the dais's east end, each turned to the crossing, along the front of their own path east off the
-- south walk. No yard of their own. (Oct 27 release fixes) World 1's row starts at x 26, where World 2's first board
-- (POWER) cut 2.8 studs into the box dais (its east end at x 24.1): here the row is x 31, 51, 71 (20 apart).
Lobby.Plan.Boards = { { 31, 86 }, { 51, 86 }, { 71, 86 } }

-- The way back to the hood, where World 1 has its World 2 door (Lobby.Plan.World2, turned to the crossing): a warm brick
-- arch (the hood's brick) on a stone step, a soft orange glow filling it, THE HOOD on its lintel. Front -Z of cf faces
-- the plaza; cf is the bottom centre of its back. The model is World1Portal (HoodServer/WorldPortalService reads the number) and carries TravelWorld = 1.
function Lobby.world2(e, cf)
	local p, model = e:at(cf):group('World1Portal')
	model:SetAttribute('TravelWorld', 1)
	local brick, dark, trim = C(214, 112, 78), C(176, 86, 62), C(255, 222, 170)
	sbox(p, 'PortalStep', V(-9, 0, -5), V(9, 0.6, 0.6), City.edge)
	decor(sbox(p, 'PortalStepNosing', V(-9, 0.45, -5.2), V(9, 0.7, -4.8), City.edgeCap)).CastShadow = false
	for _, sx in { -1, 1 } do
		local xa, xb = sx * 5.4, sx * 8.4
		sbox(p, 'PortalPillar', V(xa, 0.6, -3), V(xb, 15, 0), brick)
		decor(sbox(p, 'PortalPillarBase', V(xa - sx * 0.3, 0.6, -3.3), V(xb + sx * 0.3, 2.6, 0.2), dark)).CastShadow = false
		for y = 4, 14, 3.4 do decor(sbox(p, 'PortalBrickBand', V(xa - sx * 0.05, y, -3.1), V(xb + sx * 0.05, y + 0.4, -2.95), dark)).CastShadow = false end
	end
	local lintel = sbox(p, 'PortalLintel', V(-9.2, 15, -3.4), V(9.2, 18.4, 0.2), brick)
	decor(sbox(p, 'PortalLintelCap', V(-9.6, 18.4, -3.8), V(9.6, 19.1, 0.4), trim)).CastShadow = false
	local board = p:box('PortalBoard', V(-6.8, 15.4, -3.5), V(6.8, 18, -3.4), C(40, 34, 40), M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Front, 14), 'Hood', 'THE HOOD', C(255, 206, 60), FONT.title, 0.1, 0.8, C(40, 24, 0), 3)
	local field = decor(p:box('PortalField', V(-5.4, 0.6, -1.7), V(5.4, 15, -1.3), C(255, 150, 96), M.Neon))
	field.Transparency, field.CastShadow = 0.35, false
	light(field, C(255, 170, 120), 0.5, 8)
	sbox(p, 'PortalBack', V(-8.4, 0.6, 0), V(8.4, 15, 0.6), dark)
	return model
end
-- The corners as World 1's (the portal turned to the crossing, the boards), the portal's floating words saying where it
-- goes, its slot under the city's name for it too.
do
	local corners = Lobby.corners
	function Lobby.corners(L)
		corners(L)
		local g = L.parent:FindFirstChild('World2Corner')
		local label = g and g:FindFirstChild('WorldLabel', true)
		if label then
			if label:FindFirstChild('Title') then label.Title.Text = 'The Hood' end
			if label:FindFirstChild('Soon') then label.Soon.Text = 'BACK TO WORLD 1' end
		end
		if g then g.Name = 'HoodPortalCorner' end
		Lobby.Slots.World1Portal = Lobby.Slots.World2Portal
	end
end
-- This world's boxes on the dais (Config/Shoes: World 2's two Cash boxes), World 1's list when it has none yet; two
-- boxes stand either side of the dais's middle.
do
	local list, slotX = Lobby.shoeBoxList, Lobby.boxSlotX
	function Lobby.shoeBoxList()
		local cfg = Lobby.sharedModule('Config', 'Shoes')
		if cfg and type(cfg.boxesForWorld) == 'function' then
			local ok, here = pcall(cfg.boxesForWorld, V2.World or 2)
			if ok and type(here) == 'table' and #here > 0 then return here end
		end
		return list()
	end
	function Lobby.boxSlotX(boxes, i)
		if #boxes == 2 then return ({ 9, -9 })[i] end
		return slotX(boxes, i)
	end
end
---------------------------------------------------------------------------------------------- the hall (World 2's lobby)
-- (Oct 27, the owner, for World 2's lobby: "for the second world C", the Oct 10 hall) World 2's lobby is that indoor
-- hall again, round World 2's own plan (e3_plaza's: the training block west, the gun stand east, the box dais south,
-- the portal SW, the boards in one straight row SE, the sale spots and chests by the door), at World 1's size (the
-- warehouse's footprint, Lobby.WH: x -86..86, z 6..100). Runs after e5_plaza, so its Lobby.hall replaces the plaza's.
--   Shell    light aqua walls 2.5 thick (faint studs), a darker studded base band with a pale lip, a paler cap band over
--            a cornice; periwinkle wall pillars with the kinked face (e2's Lobby.wallPillar) on the side and back walls
--            and the corners, kept clear of the training block's head deck
--   Windows  a big recessed window in every bay, cut through the wall, so the business district's towers (City.skyline, outside
--            the walls) show through; a wall lamp over each
--   Door     the north wall's exit bay: a grey framed recess round the open doorway (x +-23, 32 high) onto the Stage 1
--            gate, two framed panels over it, white neon lines
--   Roof     a light ceiling grid with a solid panel in every bay (round 5: was a skylight), blue steel lattice girders, long white light bars;
--            nothing up there (nor the walls or pillars) casts a shadow, so the sun lights the hall like the reference
--   Floor    one light lavender studded floor; a thin cyan neon line round each zone's platform (open where a walk
--            runs onto it), two tiled panels either side of the spine before the door
-- Studs: the city's look pass (city/x2_look) gives the shell's studded parts the faint stud texture on every face.

City.Hall = {
	H = 50, t = 2.5, DoorH = 32, WinY = 29, WinH = 16, Band = 43,
	Side = { 28, 56, 78 }, -- side-wall pillars (z): clear of the head deck (z 34..50, out to x -82.4)
	Back = { -43, 0, 43 }, -- back-wall pillars (x)
	Rows = { 28, 56, 78 }, -- cross girders and light-bar rows (z), on the side pillars
	Cols = { -60, -30, 0, 30, 60 }, -- long girders and light-bar centres (x)
	RX = 43, RH = 37, -- the exit bay's frame (half width, height)
}
-- The Oct 10 hall's colours (its Lobby.Colors with the LIGHT3 roof, window and lamp set).
City.HallColors = {
	walk = C(186, 188, 224), panel = C(146, 152, 206), band = C(88, 98, 146), cyan = C(84, 226, 250),
	wall = C(120, 206, 222), wallDark = C(98, 186, 206), pillar = C(150, 152, 196), channel = C(22, 30, 64),
	neon = C(240, 246, 255), frame = C(146, 154, 188), lamp = C(255, 252, 236),
	pillarSide = C(116, 120, 170), pillarBase = C(98, 104, 150), trim = C(200, 204, 228),
	wallBand = C(170, 226, 236), wallBase = C(88, 150, 178), sill = C(184, 190, 220),
	ceiling = C(192, 208, 232), ceilingPanel = C(224, 234, 248), skylight = C(196, 228, 255),
	truss = C(150, 168, 206), trussDark = C(128, 148, 192), barHousing = C(150, 162, 198), lampBack = C(120, 132, 164),
	winFrame = C(84, 112, 160), winGlass = C(214, 244, 255), glassTop = C(164, 216, 248),
}

-- A window w x h on a wall (cf on the wall's inner face at its centre, -Z into the hall), over a hole cut through the
-- wall: the thick frame standing 1.2 proud, clear glass (the towers show through), a transom, a pale sill, a head.
function City.hallWindow(c, cf, w, h)
	local K = City.HallColors
	local fw, fd = 1.5, 1.2
	local gw, gh = w - 2 * fw, h - 2 * fw
	for _, b in { { 0, h / 2 - fw / 2, w, fw }, { 0, -h / 2 + fw / 2, w, fw }, { -w / 2 + fw / 2, 0, fw, gh }, { w / 2 - fw / 2, 0, fw, gh } } do
		c:part('WindowFrame', V(b[3], b[4], fd), cf * CFrame.new(b[1], b[2], -fd / 2), K.winFrame, M.SmoothPlastic)
	end
	local glass = c:part('WindowGlass', V(gw, gh, 0.2), cf * CFrame.new(0, 0, 0.6), K.winGlass, M.Glass)
	glass.Transparency, glass.CastShadow = 0.75, false
	c:part('WindowTransom', V(gw, 1.0, 0.7), cf * CFrame.new(0, gh / 2 - gh * 0.3, -0.35), K.winFrame, M.SmoothPlastic)
	studs(c:part('WindowSill', V(w + 1.6, 0.9, 1.9), cf * CFrame.new(0, -h / 2 - 0.4, -0.95), K.sill, M.Plastic))
	c:part('WindowHead', V(w + 1, 0.7, 1.5), cf * CFrame.new(0, h / 2 + 0.35, -0.75), K.winFrame:Lerp(P.black, 0.25), M.SmoothPlastic)
end
function City.hallLamp(c, cf)
	local K = City.HallColors
	decor(c:part('WallLampBack', V(3.8, 1.6, 0.4), cf * CFrame.new(0, 0, -0.2), K.lampBack, M.SmoothPlastic)).CastShadow = false
	decor(c:part('WallLamp', V(3, 0.9, 0.45), cf * CFrame.new(0, 0.05, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), K.lamp, M.Neon)).CastShadow = false
end

-- The bays along one wall: between consecutive pillar lines (u), from a to b (studs clear of the pillars), one window
-- per 16 studs, each up to 11 wide. Returns { u, w } for every window.
function City.hallBays(lines, gapEnd, gapMid)
	local out = {}
	for i = 1, #lines - 1 do
		local a = lines[i] + (i == 1 and gapEnd or gapMid)
		local b = lines[i + 1] - (i == #lines - 1 and gapEnd or gapMid)
		local n = math.max(1, math.floor((b - a + 3) / 16))
		local w = math.min(11, (b - a) / n - 3)
		if w >= 6 then
			for k = 1, n do table.insert(out, { a + (b - a) * (k - 0.5) / n, w }) end
		end
	end
	return out
end

function Lobby.hall(L)
	local K, Hl, Wh = City.HallColors, City.Hall, Lobby.WH
	local H, T = Hl.H, Hl.t
	local x0, x1, z0, z1 = Wh.x0, Wh.x1, Wh.z0, Wh.z1
	local Dw, DH = Lobby.Door, Hl.DoorH
	Lobby.DoorH = DH
	local h = L:group('Hall')
	-- the floor: one light lavender slab under the hall and its walls ('Concrete': the look pass's faint studs, 3 layers)
	studs(h:box('Concrete', V(x0 - T, -1, z0 - T), V(x1 + T, 0, z1 + T), K.walk, M.Plastic))
	h:box('Threshold', V(-Lobby.Bounds.mouth, -1, Lobby.N - 4), V(Lobby.Bounds.mouth, 0, z0 - T), K.walk, M.SmoothPlastic)
	-- the windows, wall by wall: { wall, u, width }
	local wy, wh = Hl.WinY, Hl.WinH
	local wins = {}
	local sides = { z0, table.unpack(Hl.Side) }
	table.insert(sides, z1)
	for _, b in City.hallBays(sides, 6, Lobby.PillarW / 2) do
		table.insert(wins, { 'W', b[1], b[2] }); table.insert(wins, { 'E', b[1], b[2] })
	end
	local backs = { x0, table.unpack(Hl.Back) }
	table.insert(backs, x1)
	for _, b in City.hallBays(backs, 6, Lobby.PillarW / 2) do table.insert(wins, { 'S', b[1], b[2] }) end
	local edge = Hl.RX + 3.4
	for _, sx in { -1, 1 } do table.insert(wins, { 'N', sx * (edge + x1 - 6) / 2, 11 }) end
	-- the walls: each run built in bands between the holes' heights (the windows', the doorway's)
	local function run(w, u0, u1, holes)
		local function box(ua, ub, ya, yb)
			local a, b
			if w == 'N' then a, b = V(ua, ya, z0 - T), V(ub, yb, z0)
			elseif w == 'S' then a, b = V(ua, ya, z1), V(ub, yb, z1 + T)
			elseif w == 'W' then a, b = V(x0 - T, ya, ua), V(x0, yb, ub)
			else a, b = V(x1, ya, ua), V(x1 + T, yb, ub) end
			h:box('Wall', a, b, K.wall, M.SmoothPlastic)
		end
		local ys = { 0, H }
		for _, hl in holes do table.insert(ys, hl[3]); table.insert(ys, hl[4]) end
		table.sort(ys)
		for i = 1, #ys - 1 do
			local ya, yb = ys[i], ys[i + 1]
			if yb - ya > 0.01 then
				local open = {}
				for _, hl in holes do if hl[3] <= ya + 0.01 and hl[4] >= yb - 0.01 then table.insert(open, hl) end end
				table.sort(open, function(p, q) return p[1] < q[1] end)
				local u = u0
				for _, hl in open do
					if hl[1] > u + 0.01 then box(u, hl[1], ya, yb) end
					u = math.max(u, hl[2])
				end
				if u1 > u + 0.01 then box(u, u1, ya, yb) end
			end
		end
	end
	local holes = { N = { { -Dw, Dw, 0, DH } }, S = {}, W = {}, E = {} }
	for _, wn in wins do
		local gw, gh = wn[3] - 3, wh - 3
		table.insert(holes[wn[1]], { wn[2] - gw / 2, wn[2] + gw / 2, wy - gh / 2, wy + gh / 2 })
	end
	run('W', z0 - T, z1 + T, holes.W)
	run('E', z0 - T, z1 + T, holes.E)
	run('N', x0, x1, holes.N)
	run('S', x0, x1, holes.S)
	-- the walls' finish: a darker studded base band with a pale lip and a kick along the floor, a paler cap band over a
	-- cornice (the exit bay keeps the north wall's middle). strip(): a box on one wall's inner face, u along it.
	local function strip(name, side, u0, u1, y0, y1, depth, color, mat)
		local a, b
		if side == 'W' then a, b = V(x0, y0, u0), V(x0 + depth, y1, u1)
		elseif side == 'E' then a, b = V(x1 - depth, y0, u0), V(x1, y1, u1)
		elseif side == 'S' then a, b = V(u0, y0, z1 - depth), V(u1, y1, z1)
		else a, b = V(u0, y0, z0), V(u1, y1, z0 + depth) end
		return h:box(name, a, b, color, mat or M.SmoothPlastic)
	end
	local runs = { { 'W', z0, z1 }, { 'E', z0, z1 }, { 'S', x0, x1 }, { 'N', x0, -edge }, { 'N', edge, x1 } }
	for _, r in runs do
		studs(strip('WallBase', r[1], r[2], r[3], 0, 4, 0.35, K.wallBase), true)
		strip('WallBaseLip', r[1], r[2], r[3], 4, 4.5, 0.65, K.trim)
		strip('WallKick', r[1], r[2], r[3], 0, 0.8, 0.5, K.pillarBase)
		studs(strip('WallBand', r[1], r[2], r[3], Hl.Band, H, 0.2, K.wallBand), true)
		strip('WallCornice', r[1], r[2], r[3], Hl.Band - 1, Hl.Band, 0.75, K.trim)
	end
	-- wall frames: cf on the inner face at (u along the wall, y), -Z into the hall
	local frames = {
		W = function(u, y) return CFrame.lookAt(V(x0, y, u), V(x0 + 1, y, u)) end,
		E = function(u, y) return CFrame.lookAt(V(x1, y, u), V(x1 - 1, y, u)) end,
		S = function(u, y) return CFrame.lookAt(V(u, y, z1), V(u, y, z1 - 1)) end,
		N = function(u, y) return CFrame.lookAt(V(u, y, z0), V(u, y, z0 + 1)) end,
	}
	for _, wn in wins do
		local f = frames[wn[1]]
		City.hallWindow(h, f(wn[2], wy), wn[3], wh)
		City.hallLamp(h, f(wn[2], wy + wh / 2 + 2))
	end
	-- the pillars (e2's, in this hall's colours and height): the side walls, the back wall, the corners (narrow ones)
	local keepK, keepH = Lobby.Colors, Lobby.H
	Lobby.Colors, Lobby.H = K, H
	for _, z in Hl.Side do
		Lobby.wallPillar(h, V(x0, 0, z), V(1, 0, 0))
		Lobby.wallPillar(h, V(x1, 0, z), V(-1, 0, 0))
	end
	for _, x in Hl.Back do Lobby.wallPillar(h, V(x, 0, z1), V(0, 0, -1)) end
	for _, sx in { -1, 1 } do
		local xi = sx < 0 and x0 or x1
		Lobby.wallPillar(h, V(xi - sx * 3, 0, z1), V(0, 0, -1), nil, 6)
		Lobby.wallPillar(h, V(xi, 0, z1 - 3), V(-sx, 0, 0), nil, 6)
		Lobby.wallPillar(h, V(xi - sx * 3, 0, z0), V(0, 0, 1), nil, 6)
		Lobby.wallPillar(h, V(xi, 0, z0 + 3), V(-sx, 0, 0), nil, 6)
	end
	Lobby.Colors, Lobby.H = keepK, keepH
	City.exitBay(h)
	City.hallRoof(L)
	-- the shell lets the sun in (the reference's bright interior): the walls, their bands and the pillars cast no shadow
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and (p.Name:find('^Wall') or p.Name:find('^Pillar')) then p.CastShadow = false end
	end
	City.skyline(L)
	return h
end

-- The north wall's centre: a framed recess round the open doorway onto the Stage 1 gate, two framed panels over it,
-- white neon lines under and between them and up the frame's edges (steady light).
function City.exitBay(h)
	local K, Hl, N = City.HallColors, City.Hall, Lobby.WH.z0
	local Dw, DH, RX, RH, fw = Lobby.Door, Hl.DoorH, Hl.RX, Hl.RH, 3.4
	local e = h:group('ExitBay')
	for _, seg in { { -RX, -Dw - 2 }, { Dw + 2, RX } } do e:box('ExitRecess', V(seg[1], 0, N), V(seg[2], RH, N + 0.12), K.wallDark, M.SmoothPlastic) end
	e:box('ExitRecess', V(-Dw - 2, DH + 2, N), V(Dw + 2, RH, N + 0.12), K.wallDark, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local a, b = sx * RX, sx * (RX + fw)
		studs(e:box('ExitFrame', V(math.min(a, b), 0, N), V(math.max(a, b), RH + fw, N + 1.6), K.frame, M.Plastic), true)
		local c, d = sx * Dw, sx * (Dw + 2)
		e:box('DoorJamb', V(math.min(c, d), 0, N - Hl.t), V(math.max(c, d), DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	end
	studs(e:box('ExitFrame', V(-RX - fw, RH, N), V(RX + fw, RH + fw, N + 1.6), K.frame, M.Plastic), true)
	e:box('DoorHead', V(-Dw - 2, DH, N - Hl.t), V(Dw + 2, DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	local py0, py1 = RH + fw + 1.2, Hl.H - 2.5
	for _, sx in { -1, 1 } do
		local a, b = sx * 1.6, sx * RX
		local lo, hi = math.min(a, b), math.max(a, b)
		e:box('ExitPanel', V(lo, py0, N), V(hi, py1, N + 0.12), K.wallDark, M.SmoothPlastic)
		for _, ed in { { V(lo, py0, N), V(hi, py0 + 1.6, N + 1.2) }, { V(lo, py1 - 1.6, N), V(hi, py1, N + 1.2) }, { V(lo, py0, N), V(lo + 1.6, py1, N + 1.2) }, { V(hi - 1.6, py0, N), V(hi, py1, N + 1.2) } } do
			studs(e:box('ExitPanelFrame', ed[1], ed[2], K.frame, M.Plastic), true)
		end
	end
	local function neon(a, b) decor(e:box('ExitNeon', a, b, K.neon, M.Neon)).CastShadow = false end
	neon(V(-RX - fw, RH + fw, N + 1.2), V(RX + fw, RH + fw + 0.7, N + 1.6))
	neon(V(-0.4, RH + fw, N + 0.3), V(0.4, py1, N + 0.9))
	for _, sx in { -1, 1 } do
		local a, b = sx * (RX + fw), sx * (RX + fw - 0.6)
		neon(V(math.min(a, b), 0.4, N + 1.6), V(math.max(a, b), RH + fw + 0.7, N + 1.9))
	end
	return e
end

-- The roof: a light ceiling grid on the girder lines with a skylight in every bay, lattice girders along and across,
-- long light bars hung under the cross girders. All named Roof*, none casts a shadow.
function City.hallRoof(L)
	local K, Hl, Wh = City.HallColors, City.Hall, Lobby.WH
	local H, T = Hl.H, Hl.t
	local x0, x1, z0, z1 = Wh.x0, Wh.x1, Wh.z0, Wh.z1
	local r = L:group('Roof')
	local xs, zs = { x0 }, { z0 }
	for _, x in Hl.Cols do table.insert(xs, x) end
	for _, z in Hl.Rows do table.insert(zs, z) end
	table.insert(xs, x1)
	table.insert(zs, z1)
	for i, x in xs do
		local a = (i == 1 or i == #xs) and T or 3
		local lo, hi = i == 1 and x - T or x - a, i == #xs and x + T or x + a
		r:box('RoofCeiling', V(lo, H, z0 - T), V(hi, H + 1, z1 + T), K.ceiling, M.SmoothPlastic)
	end
	for j, z in zs do
		local a = (j == 1 or j == #zs) and T or 3
		local lo, hi = j == 1 and z - T or z - a, j == #zs and z + T or z + a
		r:box('RoofCeiling', V(x0, H, lo), V(x1, H + 1, hi), K.ceiling, M.SmoothPlastic)
	end
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local a0, a1 = xs[i] + (i > 1 and 3 or 0), xs[i + 1] - (i < #xs - 1 and 3 or 0)
			local b0, b1 = zs[j] + (j > 1 and 3 or 0), zs[j + 1] - (j < #zs - 1 and 3 or 0)
			-- (Oct 27 round 5, the owner: "add roofs to the warehouses") each bay is a solid light ceiling panel now (was a
			-- see-through skylight showing the sky); a soft light under it keeps the hall bright (City.hallLights, x2_look)
			r:box('RoofPanel', V(a0, H + 0.4, b0), V(a1, H + 0.7, b1), K.ceilingPanel, M.SmoothPlastic)
			for _, e in { { a0, b0, a1, b0 + 1 }, { a0, b1 - 1, a1, b1 }, { a0, b0 + 1, a0 + 1, b1 - 1 }, { a1 - 1, b0 + 1, a1, b1 - 1 } } do
				r:box('RoofSkylightFrame', V(e[1], H - 0.6, e[2]), V(e[3], H + 1, e[4]), K.ceilingPanel, M.SmoothPlastic)
			end
		end
	end
	local ty = H - 10
	for _, x in Hl.Cols do
		for _, o in { 1, 3 } do Lobby.truss(r, 'RoofTruss', V(x, ty + o, z0), V(x, ty + o, z1), K.trussDark) end
		for _, z in { z0, z1 } do
			local s = z == z0 and 1 or -1
			local a, b = z, z + s * 1.2
			r:box('RoofMount', V(x - 3.5, ty - 1.5, math.min(a, b)), V(x + 3.5, ty + 5.5, math.max(a, b)), K.pillarBase, M.SmoothPlastic)
		end
	end
	for _, z in Hl.Rows do
		for _, o in { 5, 7 } do Lobby.truss(r, 'RoofTruss', V(x0, ty + o, z), V(x1, ty + o, z), K.trussDark) end
	end
	for _, z in Hl.Rows do
		for _, x in Hl.Cols do
			local y = ty - 6
			studs(r:box('RoofLampBar', V(x - 10, y, z - 1.6), V(x + 10, y + 1, z + 1.6), K.barHousing, M.Plastic), true)
			decor(r:box('RoofLampRim', V(x - 10.3, y - 0.3, z - 1.9), V(x + 10.3, y, z + 1.9), K.trim, M.SmoothPlastic))
			local tube = decor(r:box('RoofLampTube', V(x - 9.7, y - 0.45, z - 1.3), V(x + 9.7, y - 0.3, z + 1.3), K.neon, M.Neon))
			light(tube, C(232, 240, 255), 0.6, 26)
			for _, dx in { -8.5, 8.5 } do decor(r:box('RoofLampWire', V(x + dx - 0.08, y + 1, z - 0.08), V(x + dx + 0.08, ty + 4, z + 0.08), C(96, 106, 130), M.SmoothPlastic)) end
		end
	end
	for _, p in r.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = false end
	end
	return r
end

-- The floor's cyan lines: one round each zone's platform, 1 stud out, open where a walk runs onto it; and two tiled
-- panels either side of the spine before the door (the Oct 10 hall's panel: a darker studded slab, a fine tile grid,
-- the inset cyan line).
function City.zoneLines(L)
	local K = City.HallColors
	local f = L:group('ZoneLines')
	local Pz, Hd = Lobby.Plaza, Lobby.HeadDeck
	local gx0, gx1, gz0, gz1 = Lobby.gunDeckRect()
	local zones = {
		{ Pz.x0, Pz.x1, Pz.z0, Pz.z1 },
		{ Hd.x0, Pz.x0, Hd.z0, Hd.z1 },
		{ gx0 - 1.2, gx1, gz0, gz1 },
		{ -24.1, 24.1, 79.9, 94.8 }, -- (the box dais's footprint)
	}
	-- where a line must not run: inside a zone, across a walk's mouth (the walks themselves)
	local cuts = {}
	for _, z in zones do table.insert(cuts, { z[1] - 0.9, z[2] + 0.9, z[3] - 0.9, z[4] + 0.9 }) end
	for _, p in Lobby.paths() do table.insert(cuts, { p[1], p[2], p[3], p[4] }) end
	local o, w, y = 1.0, 0.5, 0.06
	local function segment(isX, fixed, u0, u1, self)
		local spans = { { u0, u1 } }
		for k, c in cuts do
			if k ~= self then
				local inF
				if isX then inF = fixed > c[3] and fixed < c[4] else inF = fixed > c[1] and fixed < c[2] end
				if inF then
					local ca, cb = isX and c[1] or c[3], isX and c[2] or c[4]
					local nxt = {}
					for _, s in spans do
						if cb <= s[1] or ca >= s[2] then table.insert(nxt, s)
						else
							if ca > s[1] then table.insert(nxt, { s[1], ca }) end
							if cb < s[2] then table.insert(nxt, { cb, s[2] }) end
						end
					end
					spans = nxt
				end
			end
		end
		for _, s in spans do
			if s[2] - s[1] > 0.6 then
				local a, b
				if isX then a, b = V(s[1], 0, fixed - w / 2), V(s[2], y, fixed + w / 2) else a, b = V(fixed - w / 2, 0, s[1]), V(fixed + w / 2, y, s[2]) end
				decor(f:box('ZoneNeon', a, b, K.cyan, M.Neon)).CastShadow = false
			end
		end
	end
	for k, z in zones do
		local a0, a1, b0, b1 = z[1] - o, z[2] + o, z[3] - o, z[4] + o
		segment(true, b0, a0, a1, k)
		segment(true, b1, a0, a1, k)
		segment(false, a0, b0, b1, k)
		segment(false, a1, b0, b1, k)
	end
	-- the two panels before the door, between the spine and the platforms' north ends
	local sp = Lobby.SpineHalf or 5
	for _, r in { { Pz.x1 + 2, -sp - 1.5, 21, Lobby.CrossZ - sp - 2 }, { sp + 1.5, gx0 - 3.2, 21, Lobby.CrossZ - sp - 2 } } do
		local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
		if x1 - x0 > 4 and z1 - z0 > 4 then
			local panel = studs(f:box('PanelTile', V(x0, 0, z0), V(x1, 0.06, z1), K.panel, M.Plastic))
			panel.CastShadow = false
			for _, vertical in { true, false } do
				Lobby.stripes(panel, Enum.NormalId.Top, x1 - x0, z1 - z0, 2.5, 0.16, vertical, 0.6, K.band).Name = 'TileGrid'
			end
			local ins, cw = 0.7, 0.5
			local function n(a, b) decor(f:box('PanelNeon', a, b, K.cyan, M.Neon)).CastShadow = false end
			n(V(x0 + ins, 0.06, z0 + ins), V(x1 - ins, 0.12, z0 + ins + cw))
			n(V(x0 + ins, 0.06, z1 - ins - cw), V(x1 - ins, 0.12, z1 - ins))
			n(V(x0 + ins, 0.06, z0 + ins + cw), V(x0 + ins + cw, 0.12, z1 - ins - cw))
			n(V(x1 - ins - cw, 0.06, z0 + ins + cw), V(x1 - ins, 0.12, z1 - ins - cw))
		end
	end
	return f
end
local floorPlanBase = Lobby.floorPlan
function Lobby.floorPlan(L)
	local f = floorPlanBase(L)
	City.zoneLines(L)
	return f
end

Lobby.outdoors = function() end -- (no cliffs in the city)
-- The hall's props, along its walls only (the calm floor stays clear): benches and bins in the back wall's corner bays,
-- potted bushes in the side bays.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Wh = Lobby.WH
	for _, sx in { -1, 1 } do
		add('Scn_Bench', sx * 70, Wh.z1 - 2.4, 0) add('Scn_TrashCan', sx * 62, Wh.z1 - 2.2, 0)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 17, 0)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 67, 0)
	end
	add('Scn_Bush_1', Wh.x1 - 3, 42, 0)
	return list
end)()
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
	-- Paving under the boss yard.
	local function pave(x0, x1, z0, z1)
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - z0) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-FRONT, FRONT, BOSS_END, BOSS_TOP)
	-- The stage street from the warehouse door to the boss yard, the reference's cross-section (P.street): studded
	-- dark asphalt with a yellow dashed centre line, raised studded sidewalks, studded grass out to the buildings.
	local ST = P.street
	local zA, zB = BOSS_TOP, Lobby.N - 1
	local road, walk = ST.road, ST.road + ST.walk
	sbox(g, 'Road', V(-road, -1, zA), V(road, 0, zB), P.st.road)
	for _, s in { -1, 1 } do
		sbox(g, 'Sidewalk', V(s * road, -1, zA), V(s * walk, ST.kerb, zB), P.st.walk)
		sbox(g, 'Grass', V(s * walk, -1, zA), V(s * FRONT, ST.kerb, zB), P.st.grass)
	end
	-- Centre dashes 1 x 4 every 16 studs, standing a little proud like the picture's (7..11 past each gate, ...).
	for z = -7, zA + 4, -16 do sbox(g, 'RoadDash', V(-0.5, 0, z - 4), V(0.5, 0.2, z), P.st.dash, true) end
	-- Second tones and finished edges: a darker gutter strip along each kerb, light kerb stones capping the sidewalk's
	-- road edge, darker slab joints across the sidewalk every 8 studs, and a darker green edging where the grass starts.
	for _, s in { -1, 1 } do
		sbox(g, 'RoadGutter', V(s * (road - 1.2), -0.5, zA), V(s * (road - 0.05), 0.03, zB), P.st.roadDark, true)
		sbox(g, 'KerbStone', V(s * (road - 0.05), -0.5, zA), V(s * (road + 1), ST.kerb + 0.08, zB), P.st.kerbStone, true)
		sbox(g, 'GrassEdge', V(s * walk, ST.kerb - 0.2, zA), V(s * (walk + 0.8), ST.kerb + 0.04, zB), P.st.grassEdge, true)
		local k = 0
		for z = zB - 8, zA + 1, -8 do
			decor(g:box('WalkJoint', V(s * (road + 1), ST.kerb - 0.1, z - 0.15), V(s * walk, ST.kerb + 0.02, z + 0.15), P.st.walkJoint, M.Plastic)).CastShadow = false
			-- every third slab a shade lighter, every fifth a shade darker (worn and newer paving)
			k += 1
			local tone = (k * (s > 0 and 2 or 1)) % 3 == 0 and P.st.walk:Lerp(P.white, 0.1) or (k % 5 == 0 and P.st.walk:Lerp(P.black, 0.07)) or nil
			if tone then decor(sbox(g, 'WalkSlab', V(s * (road + 1), ST.kerb - 0.1, z - 7.85), V(s * walk, ST.kerb + 0.025, z - 0.15), tone)).CastShadow = false end
		end
	end
	-- Grass behind the buildings and round the warehouse, inside the low boundary wall.
	local zIn0, zIn1 = BOSS_END - 6, SPAWN_TOP + 6
	for _, s in { -1, 1 } do
		g:box('Grass', V(s * (FRONT + DEPTH), -1, BOSS_END), V(s * WALL_X, 0.4, 0), P.grass, M.Grass)
		if not Lobby.Open then g:box('Grass', V(s * SPAWN_W, -1, 0), V(s * WALL_X, 0.4, SPAWN_TOP), P.grass, M.Grass) end -- (B31: the plaza's own field)
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
		if not Lobby.Open then road:box('Road', V(-(W0 + b), -1, zTop + a), V(W0 + b, top, zTop + b), color, mat) end -- (B31: under the south cliffs)
		road:box('Road', V(-(W0 + b), -1, zBot - b), V(W0 + b, top, zBot - a), color, mat)
	end
	for _, s in { -1, 1 } do
		for z = zBot, zTop - 5, 10 do decor(road:box('RoadDash', V(s * (W0 + 11.8), 0, z), V(s * (W0 + 12.2), 0.04, z + 5), P.roadLine, M.SmoothPlastic)) end
	end
	for x = -(W0 + 8), W0 + 3, 10 do
		if not Lobby.Open then decor(road:box('RoadDash', V(x, 0, zTop + 11.8), V(x + 5, 0.04, zTop + 12.2), P.roadLine, M.SmoothPlastic)) end
		decor(road:box('RoadDash', V(x, 0, zBot - 12.2), V(x + 5, 0.04, zBot - 11.8), P.roadLine, M.SmoothPlastic))
	end
	-- Trees on the verge and behind the buildings, cars parked at the kerb.
	local seed = 900
	for _, s in { -1, 1 } do
		for z = zBot - 20, zTop + 20, 22 do
			seed += 1
			tree(road, V(s * (W0 + 28), 0.4, z), seed, 1.0, nil, true)
		end
		for z = BOSS_END + 20, -10, 30 do
			seed += 1
			tree(road, V(s * (FRONT + DEPTH + 3), 0.4, z), seed, 0.85, nil, true)
		end
	end
	for x = -(W0 + 20), W0 + 20, 22 do
		seed += 1
		if not Lobby.Open then tree(road, V(x, 0.4, zTop + 28), seed, 1.0, nil, true) end
		tree(road, V(x, 0.4, zBot - 28), seed + 50, 1.0, nil, true)
	end
	local carColors = { C(252, 204, 40), P.white, C(214, 52, 52), C(52, 102, 214), C(252, 204, 40), C(230, 230, 232) }
	local spots = { { -1, 40 }, { -1, -110 }, { -1, -300 }, { -1, -520 }, { -1, -760 }, { -1, -980 }, { 1, 10 }, { 1, -190 }, { 1, -370 }, { 1, -610 }, { 1, -850 }, { 1, -1040 } }
	for k, sp in spots do
		car(road, CFrame.new(sp[1] * (W0 + 7.5), 0, sp[2]) * CFrame.Angles(0, sp[1] < 0 and math.pi or 0, 0), carColors[(k - 1) % #carColors + 1])
	end
	-- Keep players on the walk where no building closes it: round the warehouse (its walls already do, these
	-- go up past the eaves) and over the forecourt's wing walls.
	if Lobby.Open then
		-- (B31 PLAZA) the open plaza: walls on the cliffs' faces (the steps are solid too; these go up past them)
		local B = Lobby.Bounds
		for _, s in { -1, 1 } do
			local X = Lobby.edgeX(s)
			invisibleWall(g, V(s * X, 0, Lobby.N - 6), V(s * (X + 1), 60, B.s))
			invisibleWall(g, V(s * B.mouth, 0, B.n), V(s * X, 60, B.n + 1))
			invisibleWall(g, V(s * B.mouth, 0, 0.6), V(s * (B.mouth + 1), 60, B.n))
		end
		invisibleWall(g, V(-B.xw, 0, B.s), V(B.xe, 60, B.s + 1))
		invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
		return g
	end
	for _, s in { -1, 1 } do
		-- (B30 LOBBY: the west one leaves the head lane's alcove open, Lobby.Apse; the alcove's own walls close it)
		local A = s < 0 and Lobby.Apse
		if A then
			invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, A.z0 - 1))
			invisibleWall(g, V(s * SPAWN_W, 0, A.z1 + 1), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		else
			invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		end
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
-- A gate at the start of every stage (and the boss yard), built to read from the lobby as SHUT (BRIEF18): a
-- see-through red-tinted haze across the opening between the end buildings (deeper at the top, lighter at the foot,
-- so the street and the next gates show through it), two hazard-striped barrier bars across it and a big chunky
-- padlock hanging on the lower one (the video's locked gate), a lit lip and edges and a glowing emitter track along
-- its foot. Its frame follows the video game's gates: a sturdy studded pillar each side (plinth, a column of
-- recesses, banded cap) and a hazard-striped beam. The text is ONE sign hung in the opening (the video's): "STAGE N" in
-- white, "Recommended" in cyan, "Power: X" in cyan pixel letters (the reference's corridor sign) and a state line, with
-- a thick dark outline. (Brief 29: it is a fixed board now, a SurfaceGui on a thin invisible panel in the gate's own
-- plane, 34 x 12 studs, so it never grows, shrinks, fades or turns; its letters and outlines are painted at one size.
-- HoodClient/Stages only shows it on your next gate and switches its lines for "STAGE N / OPEN!".)
-- The run (brief 23): a gate opens for you when you beat the crew of the stage before it, every run, and shuts again
-- when you go back to the lobby (HoodServer/Runs; gate 1 is always open). HoodClient/Stages keeps the wall solid and
-- locked-looking while it is shut, and at the moment the crew falls shatters the haze, drops the bars and padlock and
-- turns the badge green; StageService keeps anyone from walking past a gate they haven't opened.
-- Two pads stand on the sidewalks just before every gate n >= 2, the reference's "+2 WINS / 2x Wins" and "+1 WIN /
-- Return": yellow on the right ("+10 Cash / Return": the stage's Cash and back to the lobby) and magenta on the left
-- ("+100 Cash / 10x Cash": ten times that, with the 10x Cash pass), both paying for stage n - 1's crew; each a
-- three-tone slab on a dark rim with a neon edge, chevrons home and a few sparkles (d_kit's stagePad).
local GATE = {
	H = 18.5, -- the wall's height (the reference's wall reaches the end buildings' second floor)
	pink = C(250, 160, 222), -- the gate's colour (attribute Color: the STAGE CLEARED banner)
	mint = C(150, 250, 190), -- what flies off when you break through (attribute Light: shards, burst)
	-- The locked haze from the top of the wall down: height above the street, colour, opacity. Deep crimson at the top
	-- (the "closed" read from far away), rose at eye level, where it is thin enough to see the street beyond.
	-- (The opacity only grows upward: the haze is drawn as stacked panes, each from the top down to its band.)
	haze = {
		{ 18.5, C(168, 24, 58), 0.78 }, { 16.5, C(186, 32, 68), 0.72 }, { 12.5, C(212, 54, 90), 0.62 },
		{ 8, C(230, 86, 120), 0.54 }, { 3, C(242, 122, 152), 0.5 }, { 0, C(246, 142, 168), 0.5 },
	},
	bands = 74, -- quarter-stud bands (5 px each at the haze's 20 pixels per stud)
	-- The world's text style (brief 28: the references' Montserrat Black, like the lobby's labels and the pads; was
	-- FredokaOne): heavy letters with a thick near-black outline, colour by meaning: white STAGE N, cyan Recommended and
	-- cyan "Power: X" (the video's #45E6FF, both in this one face, brief 30: ref_W30.0_stage1_gate_close), and the
	-- state line as a badge, white on red (locked, blocked) or green (open).
	font = FONT.title,
	title = C(255, 255, 255), titleInk = C(14, 16, 26),
	sub = C(69, 230, 255), subInk = C(8, 26, 46),
	status = C(255, 255, 255), statusInk = C(40, 6, 14), plate = C(214, 34, 58), plateInk = C(36, 8, 16),
	-- The sign: its size in studs where it stands and the height of its foot (just over the padlock; it grows upward
	-- from there, see HoodClient/Stages: GrowFrom studs, GrowPow, GrowMax, never past the openings in front of it), and
	-- its lines: name, top and height (0-1 of the sign) and outline thickness as a share of the line's height (UI2's:
	-- ~7% on titles, ~11% on small lines).
	signW = 34, signH = 11.6, signY = 6.8, signZ = 2.9, signPPS = 30, -- (the board: studs, foot height, distance in front of the wall, px per stud)
	lines = {
		{ 'Title', 0, 0.37, 0.075 }, { 'Sub', 0.375, 0.235, 0.1 }, { 'Power', 0.61, 0.235, 0.1 }, { 'Status', 0.88, 0.12, 0.1 },
	},
	plateBox = { 0.24, 0.87, 0.52, 0.13 }, -- the state badge behind the Status line: x, y, w, h (0-1 of the sign)
	magenta = C(255, 32, 255), yellow = C(250, 246, 70), padRim = C(58, 66, 98), -- the pads and the dark rim under them
	-- Each pad: its lit top, the darker sides, the neon edge between them, its label's big words (the reference's
	-- "2M Wins" magenta and "200K Wins" yellow) in a well-known game face.
	padLook = {
		magenta = { shade = C(184, 16, 186), rim = C(255, 178, 255), label = C(255, 56, 236) },
		yellow = { shade = C(204, 184, 24), rim = C(255, 255, 196), label = C(255, 232, 36) },
	},
	padFont = FONT.title,
	edge = C(255, 176, 196), -- the haze's lit lip along the top and its side edges
	-- The frame: studded concrete in three tones, dark recesses, a hazard beam with a darker lip.
	pillarW = 4, beamH = 3,
	stone = C(160, 162, 172), stoneDark = C(116, 118, 130), stoneLight = C(190, 192, 200), recess = C(62, 66, 80),
	hazard = C(250, 204, 40), hazardDark = C(36, 38, 46), hazardLip = C(196, 146, 28),
	steel = C(70, 74, 90), bolt = C(156, 160, 172), -- the plates clamping the beam to the pillars
	track = C(58, 66, 98), trackGlow = C(255, 96, 128), -- the emitter track along the foot and its glowing line
	-- The lock: two barrier rails low across the opening (bottom y, height; the stripes' width; the padlock hangs on
	-- the upper one) and the padlock (gold body in three tones, a dark keyhole, a steel shackle).
	bars = { { 1.6, 1.2 }, { 4.6, 1.3 } }, stripe = 1.5,
	gold = C(255, 196, 40), goldDark = C(206, 142, 18), goldLight = C(255, 232, 140), keyhole = C(64, 36, 8),
	shackle = C(196, 202, 216), shackleDark = C(132, 138, 156),
	titleShade = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 228, 240)), -- lighter top, deeper foot
}
-- Colour and opacity of the haze at height h (linear between the keys above).
function GATE.hazeAt(h)
	local k = GATE.haze
	for n = 1, #k - 1 do
		local a, b = k[n], k[n + 1]
		if h <= a[1] and h >= b[1] then
			local t = (a[1] - h) / (a[1] - b[1])
			return a[2]:Lerp(b[2], t), a[3] + (b[3] - a[3]) * t
		end
	end
	return k[#k][2], k[#k][3]
end
-- One line of the sign (y and h are 0-1 of its height), centred, outlined; HoodClient/Stages sets the outline's
-- thickness is the line's height in canvas pixels times its Ink share (about 7% on the title, 10% on the small lines,
-- UI2's), painted once.
function GATE.text(gui, name, value, y, h, color, ink, share)
	local px = GATE.signH * GATE.signPPS * h
	local t = line(gui, name, value, color, GATE.font, y, h, ink, math.max(3, math.floor(px * share + 0.5)))
	t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
	t.TextWrapped = false
	t.ZIndex = 2
	t:SetAttribute('Ink', share)
	return t
end
-- One finished-edge frame over the haze (drawn above its bands).
function GATE.edgeFrame(gui, pos, size, transparency, z)
	local f = Instance.new('Frame')
	f.Name = 'Pane'
	f.BorderSizePixel = 0
	f.Position, f.Size = pos, size
	f.BackgroundColor3, f.BackgroundTransparency = GATE.edge, transparency
	f.ZIndex = z
	f:SetAttribute('BaseColor', GATE.edge)
	f:SetAttribute('BaseTransparency', transparency)
	f.Parent = gui
	return f
end
-- Black stripes slanting "/" across the approach face (at z) of a yellow bar from y to y + h, x -half..half: each
-- stripe two wedges, a parallelogram as wide as its slant (as on the beam).
function GATE.stripes(g, name, half, y, h, a, z)
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0))
	local n = math.floor((2 * half - 1.5) / (2 * a))
	local parts = {}
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a / 2, y + h / 2, z) * CFrame.Angles(0, math.pi, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a * 1.5, y + h / 2, z) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
	end
	return parts
end
-- The lock (only while the gate is shut for you; HoodClient/Stages hides every Lock* part once you can pass): two
-- hazard-striped barrier bars mounted across the haze's approach face, between the pillars, and a big padlock
-- hanging on the lower one in the middle, in front of everything (a gold body with a lighter lip, a darker foot and a
-- keyhole; a steel shackle over the bar).
function GATE.lock(g, inner)
	local parts = {}
	local function add(p) p.CastShadow = false; table.insert(parts, decor(p)); return p end
	for _, b in GATE.bars do
		local y, h = b[1], b[2]
		add(g:box('LockBar', V(-inner, y, 0.34), V(inner, y + h, 0.74), GATE.hazard, M.SmoothPlastic))
		add(g:box('LockBarLip', V(-inner, y - 0.12, 0.3), V(inner, y, 0.78), GATE.hazardLip, M.SmoothPlastic))
		for _, p in GATE.stripes(g, 'LockStripe', inner, y, h, GATE.stripe, 0.77) do add(p) end
	end
	local by = GATE.bars[2][1] -- the upper rail's foot: the body hangs under it, the shackle loops over it
	local x, y0, y1, z0, z1 = 2.3, by - 3.9, by - 0.1, 0.9, 2.3
	add(g:box('LockShackle', V(-1.75, by - 0.4, 1.3), V(-0.95, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(0.95, by - 0.4, 1.3), V(1.75, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(-1.75, by + 1.7, 1.3), V(1.75, by + 2.5, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackleShade', V(-1.75, by + 2.3, 1.25), V(1.75, by + 2.6, 1.95), GATE.shackleDark, M.SmoothPlastic))
	add(g:box('LockBody', V(-x, y0 + 0.6, z0), V(x, y1, z1), GATE.gold, M.SmoothPlastic))
	add(g:box('LockFoot', V(-x, y0, z0), V(x, y0 + 0.6, z1), GATE.goldDark, M.SmoothPlastic))
	add(g:box('LockLip', V(-x - 0.12, y1 - 0.45, z0 - 0.12), V(x + 0.12, y1, z1 + 0.12), GATE.goldLight, M.SmoothPlastic))
	local cy = (y0 + y1) / 2 + 0.15
	add(g:part('LockKeyhole', V(0.1, 1.1, 1.1), CFrame.new(0, cy + 0.25, z1 + 0.05) * CFrame.Angles(0, math.pi / 2, 0), GATE.keyhole, M.SmoothPlastic, Enum.PartType.Cylinder))
	add(g:box('LockKeyhole', V(-0.22, cy - 0.85, z1), V(0.22, cy + 0.2, z1 + 0.1), GATE.keyhole, M.SmoothPlastic))
	for _, p in parts do p:SetAttribute('BaseTransparency', p.Transparency) end
	return parts
end
-- The sign: one fixed board in the opening (the video's gate sign): a SurfaceGui on a thin invisible panel standing in
-- front of the lock, facing the street (the approach side). A panel in the gate's plane is depth-tested like the wall,
-- so the beam and the pillars never cut it, and it holds one size, at one outline, from every distance. It is wide as
-- the opening (34 of its 36 studs) and its top meets the beam; the lock's upper bar and padlock are under its foot.
-- HoodClient/Stages shows it only on your next gate and writes the state line.
function GATE.sign(g, i, req)
	local board = ghost(g:part('SignBoard', V(GATE.signW, GATE.signH, 0.1), CFrame.new(0, GATE.signY + GATE.signH / 2, GATE.signZ), P.white))
	board.CastShadow = false
	local gui = surface(board, Enum.NormalId.Back, GATE.signPPS)
	gui.Name = 'GateSign'
	gui.AlwaysOnTop = false
	-- (brief 28) Built as a player first sees it: HoodClient/Stages shows only your next gate's sign, which from the spawn is
	-- gate 1's; the others start hidden, so Studio's edit view and the previews never stack the far signs behind it.
	gui.Enabled = i == 1
	local L = {}
	for _, l in GATE.lines do L[l[1]] = l end
	local function put(name, text, color, ink)
		return GATE.text(gui, name, text, L[name][2], L[name][3], color, ink, L[name][4])
	end
	-- (brief 30) the last stage is "STAGE 16" like the rest (the user: "remove everything saying its a boss")
	local title = put('Title', 'STAGE ' .. i, GATE.title, GATE.titleInk)
	local grad = Instance.new('UIGradient')
	grad.Color, grad.Rotation = GATE.titleShade, 90
	grad.Parent = title
	put('Sub', 'Recommended', GATE.sub, GATE.subInk)
	-- (brief 30, the user's decision: "Gates show Recommended Power: X, like the reference; Level stays on the HUD bar")
	-- "Power: X" in the sign's own heavy face, cyan like "Recommended" (ref_W30.0_stage1_gate_close: one face, one colour)
	put('Power', 'Power: ' .. compact(req), GATE.sub, GATE.subInk)
	-- The state line on its badge: "Defeat the crew first" while the stage before still has its goons this run (as
	-- built), "OPEN!" once its crew is down (HoodClient/Stages writes it and the badge colour, and makes an open gate's
	-- sign compact: the title over the badge).
	-- (The badge and the line are siblings so every preview exporter places both in the sign's own frame.)
	local b = GATE.plateBox
	local plate = Instance.new('Frame')
	plate.Name = 'StatusPlate'
	plate.BorderSizePixel = 0
	plate.Position, plate.Size = UDim2.fromScale(b[1], b[2]), UDim2.fromScale(b[3], b[4])
	plate.BackgroundColor3, plate.BackgroundTransparency = GATE.plate, 0.08
	plate.ZIndex = 1
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = plate
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = GATE.plateInk, 5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	plate.Parent = gui
	-- (brief 30) the reference's states: a shut gate shows only its white "Defeat the crew first" line mid-barrier, no badge
	-- (HoodClient/Stages writes "Defeat <name>" where a crew's strongest stands); an open one the STAGE / Recommended /
	-- Power lines. Built as the player first sees them: gate 1 open, the rest shut.
	plate.Visible = false
	local status = put('Status', 'Defeat the crew first', GATE.status, GATE.statusInk)
	status.Position, status.Size = UDim2.fromScale(0.03, 0.44), UDim2.fromScale(0.94, 0.17)
	status.Visible = i > 1
	for _, n in { 'Title', 'Sub', 'Power' } do
		local l = gui:FindFirstChild(n)
		if l then l.Visible = i == 1 end
	end
	return gui
end
-- The frame (stays up once you've cleared the gate): a pillar each side of the opening, standing on the gate line
-- in front of the end building's corner (inner face at x = +-inner, outer at +-outer), and the striped beam across
-- the top of the wall between them.
function GATE.frame(g, inner, outer, H)
	local top, half = H + GATE.beamH, 1.7
	for _, s in { -1, 1 } do
		local mid = s * (inner + outer) / 2
		g:box('GatePlinth', V(s * (inner - 0.3), 0, -half - 0.3), V(s * outer, 1.4, half + 0.3), GATE.stoneDark, M.Concrete)
		-- (The pillars rise a little over the beam, as in the video, so the gate reads as two posts and a lintel.)
		studs(g:box('GatePillar', V(s * inner, 1.4, -half), V(s * outer, top + 1.6, half), GATE.stone, M.Plastic), true)
		g:box('GateCapBand', V(s * (inner - 0.15), top + 1.6, -half - 0.15), V(s * outer, top + 2, half + 0.15), GATE.stoneDark, M.SmoothPlastic)
		studs(g:box('GateCap', V(s * (inner - 0.3), top + 2, -half - 0.3), V(s * outer, top + 2.7, half + 0.3), GATE.stoneLight, M.Plastic))
		-- A column of square recesses down the approach face, the back face and the face toward the road, each in a
		-- sunk channel: two lighter strips stand proud along its edges (the face reads as pilaster - channel - pilaster).
		for k = 0, 5 do
			local y = 3 + k * 2.55
			for _, f in { -1, 1 } do
				decor(g:box('GateRecess', V(mid - 0.6, y, f * half), V(mid + 0.6, y + 1.2, f * (half + 0.06)), GATE.recess, M.SmoothPlastic))
			end
			decor(g:box('GateRecess', V(s * (inner - 0.06), y, -0.6), V(s * inner, y + 1.2, 0.6), GATE.recess, M.SmoothPlastic))
		end
		for _, f in { -1, 1 } do
			for _, e in { inner, outer - 0.9 } do
				decor(g:box('GatePilaster', V(s * e, 1.4, f * half), V(s * (e + 0.9), H - 0.3, f * (half + 0.15)), GATE.stoneLight, M.SmoothPlastic))
			end
		end
		for _, zc in { -half + 0.6, half - 0.6 } do
			decor(g:box('GatePilaster', V(s * (inner - 0.15), 1.4, zc - 0.6), V(s * inner, H - 0.3, zc + 0.6), GATE.stoneLight, M.SmoothPlastic))
		end
	end
	-- The beam: yellow with a darker lip under and over it, black stripes slanting across its approach face (each
	-- stripe two wedges: a parallelogram as wide as its slant).
	g:box('GateBeam', V(-inner, H, -1.2), V(inner, top, 1.2), GATE.hazard, M.SmoothPlastic)
	for _, y in { H - 0.25, top } do
		g:box('GateBeamLip', V(-inner, y, -1.3), V(inner, y + 0.25, 1.3), GATE.hazardLip, M.SmoothPlastic)
	end
	-- A steel plate clamps each end of the beam to its pillar, front and back, with two bolts each.
	for _, s in { -1, 1 } do
		for _, f in { -1, 1 } do
			local z0, z1 = f * 1.2, f * 1.45
			g:box('GateClamp', V(s * (inner - 1.3), H - 0.3, z0), V(s * inner, top + 0.3, z1), GATE.steel, M.SmoothPlastic)
			for _, y in { H + 0.55, top - 0.95 } do
				decor(g:box('GateBolt', V(s * (inner - 0.85), y, z1), V(s * (inner - 0.45), y + 0.4, z1 + f * 0.12), GATE.bolt, M.SmoothPlastic))
			end
		end
	end
	local a, h = GATE.beamH, GATE.beamH
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0)) -- a wedge's triangle turned onto the XY plane
	local n = math.floor((2 * inner - 3) / (2 * a))
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		-- left half: right angle at the bottom right; right half: right angle at the top left (both slant "/"), on the
		-- approach face and (mirrored, so they read "/" from that side too) on the back
		for _, f in { 1, -1 } do
			local xa, xb = f * (x + a / 2), f * (x + a * 1.5)
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xa, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and math.pi or 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xb, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and 0 or math.pi, 0) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
		end
	end
end
-- The two pads of `stage` (its crew pays out on them), at +-x, z in g's frame, on a floor at y: magenta 10x Cash on the
-- left, yellow Return on the right, both with chevrons home (toward +Z, the way back). Their first words (ECON's PadRules
-- when it is there; HoodClient/Stages keeps them current).
function GATE.pads(g, stage, x, z, y, w, d)
	local okPads, PadRules = pcall(function() return require(ReplicatedStorage.Shared.PadRules) end)
	local function words(kind)
		if okPads and type(PadRules) == 'table' and type(PadRules.labels) == 'function' then
			local ok, big, small, price = pcall(PadRules.labels, stage, kind, false)
			if ok and type(big) == 'string' then return big, small, price end
		end
		local cash = 10 * 2 ^ (stage - 1) * (kind == 'TenX' and 10 or 1)
		return '+' .. compact(cash) .. ' Cash', kind == 'TenX' and '10x Cash' or 'Return', nil
	end
	for _, side in { { -1, 'TenXPad', 'TenX', GATE.magenta, GATE.padLook.magenta }, { 1, 'ReturnPad', 'Return', GATE.yellow, GATE.padLook.yellow } } do
		local look = side[5]
		local big, small, price = words(side[3])
		stagePad(g, side[2], side[1] * x, z, side[4], stage, side[3], { w = w, d = d, y = y, h = 0.25, material = M.SmoothPlastic,
			base = GATE.padRim, shade = look.shade, rim = look.rim, sparkle = true, arrow = 1, font = GATE.padFont,
			label = { big = big, small = small, price = price, color = look.label } })
	end
end
-- (brief 30, FIGHTS: shared with the warehouse's World 2 door, code5/f4_finale) The wall's see-through haze: an invisible
-- collider across the opening (-inner..inner, H high) carrying the banded haze on its approach face. Returns the Barrier.
function GATE.hazeWall(g, inner, H, dense)
	local barrier = g:box('Barrier', V(-inner, 0, -0.3), V(inner, H, 0.3), GATE.pink, M.SmoothPlastic)
	barrier.Transparency = 1
	barrier:SetAttribute('BaseTransparency', 1)
	barrier.CastShadow = false
	-- The haze: one pane per quarter-stud band, each running from the top of the wall down to its band, so band n
	-- shows panes n..last stacked (the haze is densest at the top). Each pane's colour and opacity are solved so the
	-- stack matches the band's colour exactly; no pane edge falls between two bands, so there are no seams.
	local haze = surface(barrier, Enum.NormalId.Back, 20)
	haze.Name = 'Haze'
	-- Finished edges: a brighter lip along the top and a soft lit edge down each side (above the bands; parented
	-- before them, see below).
	local side = 0.4 / (2 * inner)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3 / H), 0.5, GATE.bands + 1)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 2)
	GATE.edgeFrame(haze, UDim2.fromScale(1 - side, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 3)
	local pa, pc = 0, Vector3.zero -- the stack so far (the panes below this band's): opacity and premultiplied colour
	local panes = {}
	for n = GATE.bands - 1, 0, -1 do
		local color, alpha = GATE.hazeAt(H * (1 - (n + 0.5) / GATE.bands))
		-- (The boss yard's wall is denser: the Champ Ring's glow right behind it would drown it.)
		if dense then alpha = 1 - (1 - alpha) * 0.5 end
		alpha = math.max(alpha, pa)
		local a = pa < 1 and 1 - (1 - alpha) / (1 - pa) or 0
		local want = V(color.R, color.G, color.B) * alpha
		local c = a > 0.001 and (want - pc * (1 - a)) / a or V(color.R, color.G, color.B)
		c = V(math.clamp(c.X, 0, 1), math.clamp(c.Y, 0, 1), math.clamp(c.Z, 0, 1))
		pa, pc = alpha, c * a + pc * (1 - a)
		local paneColor = Color3.new(c.X, c.Y, c.Z)
		local f = Instance.new('Frame')
		f.Name = 'Pane'
		f.BorderSizePixel = 0
		f.Position, f.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, (n + 1) / GATE.bands)
		f.BackgroundColor3, f.BackgroundTransparency = paneColor, 1 - a
		f.ZIndex = GATE.bands - n
		f:SetAttribute('BaseColor', paneColor)
		f:SetAttribute('BaseTransparency', 1 - a)
		panes[n + 1] = f
	end
	-- (ZIndex sets the order in Roblox; parenting the top pane first also keeps preview exporters, which list frames
	-- in reverse, drawing them in the same order.)
	for n = 1, #panes do panes[n].Parent = haze end
	return barrier
end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local st = P.street or {}
	local road, walk, kerb, open, front = st.road or 8.5, st.walk or 8.5, st.kerb or 0.6, st.open or 22, st.front or FRONT
	local H = GATE.H
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	-- The pillars stand on the grass in front of the end buildings' corners; the wall spans the opening between them.
	local inner = open - GATE.pillarW
	-- (B31 PLAZA, rule 29) gate 1 is the user's Gate_Stage1 when imported, scaled to the frame's width (its pillars at
	-- +-4.6..10.1 and its beam's foot 10 up, in design studs): the wall, the lock, the field and the sign's opening follow
	-- its narrower opening, and two invisible blocks make its pillars solid. Else (and for every other gate) our frame.
	local frameTop = H + GATE.beamH + 2.7
	if i == 1 and type(Lobby) == 'table' and Lobby.hasDesign and Lobby.hasDesign('Gate_Stage1') then
		local k = open / 10.1
		Lobby.designed(g, 'Gate_Stage1', k)
		inner, H, frameTop = 4.6 * k, 10 * k, 14.17 * k
		-- its white board (blank by design, 15.9 x 2.3, 12.45 up): the world's name, in the gate's chunky words
		local board = g:box('GateBoardFace', V(-7.6 * k, 11.4 * k, -2.55 * k - 0.05), V(7.6 * k, 13.5 * k, -2.55 * k), P.white, M.SmoothPlastic)
		local bt = line(surface(board, Enum.NormalId.Front, 6), 'World', 'WORLD 1', C(255, 214, 60), FONT.title, 0.08, 0.84, C(40, 30, 10), 4)
		bt.Name = 'GateWorldName'
		for _, sx in { -1, 1 } do
			local post = ghost(g:box('GatePillarSolid', V(sx * inner, 0, -2.35 * k), V(sx * open, H, 2.35 * k), P.white))
			post.CanCollide, post.CastShadow = true, false
		end
	else
		GATE.frame(g, inner, open, H)
	end
	-- The wall: an invisible collider across the opening (solid on the server; HoodClient/Stages lets you through
	-- once it is open for you this run), carrying the haze on its approach face.
	GATE.hazeWall(g, inner, H, i > STAGES)
	-- The lock: barrier bars and the padlock (Lock* parts).
	GATE.lock(g, inner)
	-- The sign (shown by HoodClient/Stages on your next gate only).
	GATE.sign(g, i, req)
	-- The field's foot: a dark emitter track along the ground on the approach side with a glowing line on top,
	-- stepping up onto the sidewalks (HoodClient/Stages tints and clears every Field* part with the haze).
	for _, seg in { { -inner, -road, kerb }, { -road, road, 0 }, { road, inner, kerb } } do
		local x0, x1, y = seg[1], seg[2], seg[3]
		local track = decor(g:box('FieldTrack', V(x0, y, 0.3), V(x1, y + 0.2, 0.95), GATE.track, M.SmoothPlastic))
		local glow = decor(g:box('FieldGlow', V(x0, y + 0.2, 0.54), V(x1, y + 0.27, 0.72), GATE.trackGlow, M.Neon))
		glow.CastShadow = false
		for _, p in { track, glow } do
			p:SetAttribute('BaseColor', p.Color)
			p:SetAttribute('BaseTransparency', 0)
		end
	end
	-- Pads on the sidewalks just before the wall (measured on the reference: ~6 x 11 with the dark rim, a 3-stud strip of
	-- pavement between them and the wall, 0.5 off the kerb), paying for the stage before this gate: 10x Cash (magenta,
	-- left) and Return (yellow, right).
	local padW, padD = math.min(5.6, walk - 1.5), 11
	local padX, padZ = road + 0.5 + padW / 2, 3 + padD / 2
	if i > 1 then GATE.pads(g, i - 1, padX, padZ, kerb, padW, padD) end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-12, 16, -1), V(12, 17, 1), P.white))
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
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GATE.magenta), ColorSequenceKeypoint.new(0.5, GATE.yellow), ColorSequenceKeypoint.new(1, P.white) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', 'HoodW1Stage' .. i)
	-- (Oct 27) a Power in the billions is kept as its digits (Shared/BigAttr: the place writer wraps big whole numbers)
	local okBig, BigAttr = pcall(function() return require(ReplicatedStorage.Shared.BigAttr) end)
	if okBig and type(BigAttr) == 'table' then BigAttr.set(model, 'Required', req) else model:SetAttribute('Required', req) end
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + padZ)
	model:SetAttribute('HalfWidth', front)
	model:SetAttribute('Color', GATE.pink)
	model:SetAttribute('Light', GATE.mint)
	-- The openings HoodClient/Stages fits a grown sign into: this gate's opening and frame outline, and (gate 1) the
	-- hall's doorway it is seen through from the lobby.
	model:SetAttribute('OpenHalf', inner)
	model:SetAttribute('OpenTop', H)
	model:SetAttribute('FrameHalf', open)
	model:SetAttribute('FrameTop', frameTop)
	if i == 1 and type(Lobby) == 'table' and type(Lobby.Door) == 'number' then
		model:SetAttribute('DoorHalf', Lobby.Door)
		model:SetAttribute('DoorTop', Lobby.DoorH or 30)
		model:SetAttribute('DoorZ', Lobby.DoorZ or ((Lobby.N or 6) + 0.9))
	end
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:AddTag('HoodStageGate')
	return model
end
---------------------------------------------------------------------------------------------- stages
-- Every stage is the reference street (ref1_street.png), copied 1:1 for now. buildGround lays the cross-section
-- (road, sidewalks, grass); each stage adds, measured from the picture (z' = studs past the stage's own gate):
--   z' 0..56   the open street: a plank fence along each front yard (|x| = 34.5) and a long two-storey brick
--              building behind it (fronts at |x| = 36);
--   z' 56..64  the end buildings come forward to |x| = 22 and run up to the next gate, whose wall fills the gap;
--   tall navy lamps (left at z' 19 and 53.5, right at 50), stacked-cube trees, low hedges, the green dumpster, blue
--   flowers and grass tufts, where the picture has them (P.street holds the numbers). The camera that matches the
--   picture stands at z' 2, 13.6 up, 1.1 right of the centre line, pitched 17.6 down, FOV 70. The picture's wall is
--   ~120 studs ahead and its narrowing starts ~85 out; ours are 62 and 54 (the stages are 64 long), so the far
--   things here sit closer together than in the picture while the near ones stand where the picture has them.
local function sideRow(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1])
		z -= lot[1]
	end
end
-- The end building on side s, from its front (z0, facing back up the street) to the next gate line (z1): solid from
-- |x| = open out to the back of the lots, windows on the strip of front that shows and on the side facing the road.
local function endBuilding(ctx, s, z0, z1, extra)
	local ST = P.street
	local w, d = FRONT + DEPTH - ST.open, z0 - z1
	local strip = FRONT - ST.open
	local inner = s < 0 and 'right' or 'left'
	-- A stone pillar on the inner front corner frames the narrowing: a darker base, a studded shaft, a darker cap.
	for _, zc in { z0 } do -- (GATES' own pillars frame the wall at the gate line)
		local f = zc == z0 and 1 or -1 -- (which way the corner's exposed face looks: back up the street, or on past the gate)
		local x0, x1 = s * (ST.open - 0.8), s * (ST.open + 1.2)
		local za, zb = zc - f * 1.2, zc + f * 0.8
		sbox(ctx, 'CornerPillarBase', V(x0 - s * 0.3, -0.5, za), V(x1, 2.8, zb + f * 0.3), P.st.trimDark)
		sbox(ctx, 'CornerPillar', V(x0, 2.8, za), V(x1, ST.eave + 2.4, zb), P.st.trim)
		sbox(ctx, 'CornerPillarCap', V(x0 - s * 0.3, ST.eave + 2.4, za), V(x1, ST.eave + 3.6, zb + f * 0.3), P.st.trimDark, true)
	end
	local o = { name = 'EndBuilding', depth = d, h = ST.eave + 2, run = math.min(5, d / 2 - 1), rise = 4, windows = {
		{ face = 'front', x = s < 0 and w - strip / 2 or strip / 2, w = 10 },
		{ face = inner, x = d / 2, w = math.min(10, d - 2) },
	}, gutters = { 'front', inner } }
	-- (extra: the district's own wall colour, storeys and roof)
	for k, v in extra or {} do o[k] = v end
	if o.floors and not (extra and extra.h) then o.h = nil end
	return brickBuilding(ctx:at(CFrame.new(s < 0 and -(FRONT + DEPTH) or ST.open, 0, z0)), w, o)
end
-- Stage plans. Stage 1 is the production section (art direction brief 15): a family of four brick houses that differ
-- in width, height, roofline, setback, entrance and window rhythm, with the fence opening onto paths at their doors.
-- Stages without a plan keep the measured reference street (one long block a side) until the districts are built.
-- A house: { w (along the street), front (|x| of its facade), options for brickBuilding }; rows run from z' 0.
local PLANS = {
	[1] = {
		L = {
			{ 24, 40, edge = 'wall', { name = 'House12', roof = 'gable', h = 27, bays = 3, winW = 5.6, wall = P.st.brickDeep, chimney = { 20.5, -9 },
				entrance = { x = 12, kind = 'stoop', door = C(40, 110, 76), number = '12' } } },
			{ 32, 36, { name = 'House14', roof = 'hip', h = 30, pilasters = 2, chimney = { 8, -15 }, ac = { { 'front', 26, 16.4 } } } },
		},
		R = {
			{ 22, 40, edge = 'picket', { name = 'House15', roof = 'gableFront', h = 26, bays = 3, winW = 4.4, wall = P.st.brickLight,
				entrance = { x = 11, kind = 'porch', span = { 1, 21 }, door = C(36, 60, 110), number = '15' } } },
			{ 34, 38, { name = 'House17', roof = 'flat', h = 31, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.5), ac = { { 'front', 5.7, 16.4 } },
				entrance = { x = 28.33, kind = 'door', door = C(170, 50, 50), number = '17' } } },
		},
		-- fence gateways (z' ranges) and the paver paths from the sidewalk to the steps (x end, z' centre)
		gates = { L = { { 10.5, 13.5 } }, R = { { 9.5, 12.5 }, { 26.2, 29.2 } } },
		paths = { { -35.7, 12 }, { 34.6, 11 }, { 35.2, 27.7 } },
	},
	-- Stage 2: a porch house and a long hip-roofed terrace on the left; a flat-roofed house, a side yard (shed, washing
	-- line) and a gabled stoop house on the right. (Paths stay out of MECHANICS' backstops: left z' 22..47, right 13..24.)
	[2] = {
		L = {
			{ 20, 40, edge = 'picket', { name = 'House22', roof = 'gableFront', h = 27, bays = 2, winW = 5.4, wall = P.st.brickLight,
				entrance = { x = 10, kind = 'porch', span = { 1, 19 }, door = C(170, 50, 50), number = '22' } } },
			{ 36, 36, { name = 'House24', roof = 'hip', h = 30, pilasters = 3, chimney = { 26, -12 }, ac = { { 'front', 6, 16.4 } } } },
		},
		R = {
			{ 24, 38, { name = 'House21', roof = 'flat', h = 29, bays = 2, winW = 7, wall = P.st.brickDeep,
				entrance = { x = 18, kind = 'door', door = C(36, 60, 110), number = '21' } } },
			{ 10, yard = true },
			{ 22, 41, edge = 'wall', { name = 'House25', roof = 'gable', h = 28, bays = 2, winW = 6, chimney = { 4, -8 },
				entrance = { x = 6, kind = 'stoop', door = C(40, 110, 76), number = '25' } } },
		},
		gates = { L = { { 8.5, 11.5 } }, R = { { 4.5, 7.5 }, { 48.5, 51.5 } } },
		paths = { { -34.6, 10 }, { 35.2, 6 }, { 36.7, 50 } },
	},
	-- Stage 3: a three-storey flat-roofed block and a chimneyed stoop house on the left; a front-gabled porch house, a
	-- side yard and a hip-roofed door house on the right.
	[3] = {
		L = {
			{ 28, 36, { name = 'House32', roof = 'flat', floors = 3, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.4), ac = { { 'front', 5, 31.4 } } } },
			{ 28, 41, edge = 'wall', { name = 'House34', roof = 'gable', h = 28, bays = 3, winW = 5, chimney = { 6, -9 }, wall = P.st.brickDeep,
				entrance = { x = 21, kind = 'stoop', door = C(130, 60, 160), number = '34' } } },
		},
		R = {
			{ 18, 40, edge = 'picket', { name = 'House31', roof = 'gableFront', h = 26, bays = 2, winW = 4.6, wall = P.st.brickLight,
				entrance = { x = 9, kind = 'porch', span = { 1, 17 }, door = C(40, 110, 76), number = '31' } } },
			{ 12, yard = true },
			{ 26, 38, { name = 'House35', roof = 'hip', h = 30, pilasters = 2, entrance = { x = 6, kind = 'door', door = C(200, 140, 40), number = '35' } } },
		},
		gates = { L = { { 47.5, 50.5 } }, R = { { 7.5, 10.5 }, { 48.5, 51.5 } } },
		paths = { { -36.7, 49 }, { 34.6, 9 }, { 35.2, 50 } },
	},
}
-- A side yard (between two houses, open to the street over a low picket fence): grass, a plank shed with a sloped
-- roof, a washing line with clothes, a small tree and a kettle grill, closed at the back by a tall wall.
local function sideYard(d, s, za, w, top, seed)
	local ST = P.street
	sbox(d, 'SideYard', V(s * FRONT, -1, za - w), V(s * 64, ST.kerb, za), P.st.grass)
	sbox(d, 'YardWall', V(s * 64, -1, za - w), V(s * 65.6, 14, za), P.st.brickDark)
	sbox(d, 'YardWallCoping', V(s * 63.7, 14, za - w), V(s * 65.9, 14.6, za), P.st.trim, true)
	local mz = za - w / 2
	local shed = d:at(CFrame.new(s * 58, ST.kerb, mz)):group('Shed')
	sbox(shed, 'ShedBody', V(-3.5, 0, -3), V(3.5, 6.4, 3), C(150, 110, 70))
	for z = -2.4, 2.5, 1.2 do decor(shed:box('ShedPlank', V(-s * 3.5 - 0.05, 0.2, z - 0.06), V(-s * 3.5 + s * 0.05, 6.2, z + 0.06), C(118, 84, 52), M.Plastic)) end
	sbox(shed, 'ShedDoor', V(-s * 3.5 - 0.1, 0, -1.2), V(-s * 3.5 + s * 0.1, 5.2, 1.2), C(110, 78, 48), true)
	studs(shed:wedge('ShedRoof', V(w - 3, 1.6, 8.4), CFrame.new(0, 7.2, 0) * CFrame.Angles(0, s > 0 and -math.pi / 2 or math.pi / 2, 0), P.st.roofDark, M.Plastic), true)
	for _, z in { za - 2, za - w + 2 } do
		sbox(d, 'LinePost', V(s * 44 - 0.25, ST.kerb, z - 0.25), V(s * 44 + 0.25, ST.kerb + 7, z + 0.25), C(200, 204, 210), true)
	end
	decor(d:box('WashLine', V(s * 44 - 0.06, ST.kerb + 6.6, za - w + 2), V(s * 44 + 0.06, ST.kerb + 6.72, za - 2), C(240, 240, 240), M.Plastic))
	local cloth = { C(240, 90, 90), C(80, 160, 240), P.white, C(250, 210, 60) }
	for k = 1, math.floor((w - 4) / 2.2) do
		local cz = za - 2 - k * 2.0
		decor(d:box('Laundry', V(s * 44 - 0.08, ST.kerb + 4.2 + (k % 2) * 0.6, cz - 0.8), V(s * 44 + 0.08, ST.kerb + 6.6, cz + 0.8), cloth[k % #cloth + 1], M.Plastic))
	end
	tree(d, V(s * 51, ST.kerb, za - w + 3), seed, 0.7)
	local grill = d:at(CFrame.new(s * 40, ST.kerb, mz)):group('Grill')
	for _, a in { 0, 2.1, 4.2 } do decor(grill:box('GrillLeg', V(math.cos(a) * 0.6 - 0.1, 0, math.sin(a) * 0.6 - 0.1), V(math.cos(a) * 0.6 + 0.1, 2.2, math.sin(a) * 0.6 + 0.1), C(30, 32, 36), M.Plastic)) end
	decor(grill:part('GrillBowl', V(1.8, 1.4, 1.8), CFrame.new(0, 2.7, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Ball))
end
-- A house frame like lotFrame, with the facade at |x| = front.
local function houseFrame(ctx, s, za, w, front)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-front, 0, za), V(-front - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(front, 0, za - w), V(front + 1, 0, za - w)))
end
-- A porch bench (seat, back, legs) and a terracotta pot with a cube plant, for doorsteps.
local function porchBench(c, cf)
	local b = c:at(cf):group('Bench')
	sbox(b, 'BenchSeat', V(-2.4, 1.4, -0.7), V(2.4, 1.8, 0.7), C(150, 104, 66))
	sbox(b, 'BenchBack', V(-2.4, 1.8, 0.4), V(2.4, 3.4, 0.7), C(150, 104, 66))
	for _, x in { -2.0, 2.0 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	return b
end
local function plantPot(c, pos, seed)
	local p = c:at(CFrame.new(pos)):group('PlantPot')
	sbox(p, 'Pot', V(-0.8, 0, -0.8), V(0.8, 1.3, 0.8), C(196, 104, 66))
	sbox(p, 'PotRim', V(-0.95, 1.1, -0.95), V(0.95, 1.4, 0.95), C(170, 86, 54), true)
	sbox(p, 'Plant', V(-0.7, 1.4, -0.7), V(0.7, 2.6 + (seed % 2) * 0.6, 0.7), P.st.leaf, true)
	return p
end

---------------------------------------------------------------------------------------------- districts
-- The district family (brief 15 section 5): every look keeps the street's cross-section, so the walk, GATES' gates
-- and MECHANICS' target bands (the sidewalks, and the grass strip |x| 16.5..19 at z' 13..47) work everywhere, and
-- changes what stands beside it, in the same studded kit: The Block (1-3, houses), Corner Shop (4-6, a T-junction
-- with a corner store), The Alley (7-9, tall walls, fire escapes, a sky bridge), The Courts (10-12, a fenced court on
-- the right), The Yards (13-15, a warehouse dock and a container yard). Open ground beside the street is closed by a
-- tall wall at |x| 64 so the walk can't go round a gate. z' = studs past the stage's gate (map z = gateZ - z').
local District = {}

-- The stage group with its (hidden) fight marker; at(x, z') is a point on the grass/sidewalk level.
function District.base(ctx, i)
	local top = stageTop(i)
	local d = ctx:group('Stage' .. i)
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	return d, top, function(x, zp) return V(x, P.street.kerb, top - zp) end
end
-- Flat studded ground (paving, a court, an apron) between |x| xa..xb on side s and z' za..zb, its top at y.
function District.floor(d, top, s, xa, xb, za, zb, y, color, name)
	return sbox(d, name or 'Paving', V(s * xa, y - 1.4, top - za), V(s * xb, y, top - zb), color)
end
-- A tall brick boundary wall along Z at |x| x (stone coping, darker plinth), closing open ground beside the street.
function District.backWall(d, top, s, x, za, zb, h)
	h = h or 14
	sbox(d, 'BackWall', V(s * x, -1, top - za), V(s * (x + 1.6), h, top - zb), P.st.brickDark)
	sbox(d, 'BackWallPlinth', V(s * (x - 0.3), -1, top - za), V(s * (x + 1.9), 1.6, top - zb), P.st.brickDark:Lerp(P.black, 0.15), true)
	sbox(d, 'BackWallCoping', V(s * (x - 0.3), h, top - za), V(s * (x + 1.9), h + 0.6, top - zb), P.st.trim, true)
end
-- Zebra stripes: n bars, each a x b studs, from p stepping by step (all in the stage frame), white studded paint.
function District.zebra(d, p, a, b, step, n)
	for k = 0, n - 1 do
		local q = p + step * k
		decor(sbox(d, 'Zebra', q - V(a / 2, 0.05, b / 2), q + V(a / 2, 0.14, b / 2), C(240, 240, 236))).CastShadow = false
	end
end
-- Traffic light: a navy pole with a collar, an arm over the road and a yellow three-lamp head facing +Z (the way the
-- player comes), red lit. dir = the arm's direction (+1 or -1 in x).
function District.trafficLight(d, pos, dir)
	local t = d:at(CFrame.new(pos)):group('TrafficLight')
	local col = P.st.lamp
	sbox(t, 'SignalBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), P.st.lampDark)
	sbox(t, 'SignalPole', V(-0.6, 1.2, -0.6), V(0.6, 17, 0.6), col)
	sbox(t, 'SignalArm', V(math.min(0, dir * 9), 15.6, -0.4), V(math.max(0, dir * 9), 16.4, 0.4), col, true)
	for _, hx in { dir * 1.6, dir * 8 } do
		local h = t:at(CFrame.new(hx, 0, 0))
		sbox(h, 'SignalHead', V(-0.9, 10.6 + (hx == dir * 1.6 and 0 or 2.6), -0.6), V(0.9, 15.4 + (hx == dir * 1.6 and 0 or 0.2), 0.6), C(240, 196, 40), true)
		local y0 = 10.6 + (hx == dir * 1.6 and 0 or 2.6)
		for k, c3 in { C(255, 60, 50), C(80, 70, 40), C(50, 70, 50) } do
			local lamp = decor(h:box('SignalLamp', V(-0.55, y0 + 4.8 - k * 1.5 - 0.15, 0.6), V(0.55, y0 + 4.8 - k * 1.5 + 0.95, 0.75), c3, k == 1 and M.Neon or M.Plastic))
			lamp.CastShadow = false
			decor(h:box('SignalHood', V(-0.65, y0 + 4.8 - k * 1.5 + 0.95, 0.6), V(0.65, y0 + 4.8 - k * 1.5 + 1.15, 1.2), C(30, 32, 38), M.Plastic))
		end
	end
	return t
end
-- Stop sign on a short pole: red octagon look (a square and a turned square), white border, facing +Z.
function District.stopSign(d, pos)
	local t = d:at(CFrame.new(pos)):group('StopSign')
	sbox(t, 'SignPole', V(-0.25, 0, -0.25), V(0.25, 8, 0.25), C(150, 154, 162))
	local face = sbox(t, 'StopFace', V(-1.3, 8, 0.25), V(1.3, 10.6, 0.5), C(220, 40, 40), true)
	decor(t:part('StopFace', V(2.6, 2.6, 0.24), CFrame.new(0, 9.3, 0.37) * CFrame.Angles(0, 0, math.rad(45)), C(220, 40, 40), M.Plastic))
	line(surface(face, Enum.NormalId.Back, 30), 'Stop', 'STOP', P.white, FONT.title, 0.28, 0.44)
	return t
end
-- Ice chest outside a shop: a white studded box with a blue lid and handle bar.
function District.iceBox(d, cf)
	local t = d:at(cf):group('IceBox')
	local body = sbox(t, 'IceBox', V(-2.4, 0, -1.2), V(2.4, 3.2, 1.2), C(236, 240, 246))
	sbox(t, 'IceLid', V(-2.5, 3.2, -1.3), V(2.5, 3.7, 1.3), C(40, 110, 220))
	sbox(t, 'IceHandle', V(-1, 3.7, -0.15), V(1, 4.0, 0.15), C(30, 60, 140), true)
	line(surface(body, Enum.NormalId.Front, 30), 'Ice', 'ICE', C(40, 110, 220), FONT.loud, 0.2, 0.6)
	return t
end
-- Bike rack: a low steel rail on feet with two loops, one or two bikes in it. Along local X.
function District.bikeRack(d, cf, bikes)
	local t = d:at(cf):group('BikeRack')
	sbox(t, 'RackRail', V(-3, 0, -0.2), V(3, 0.4, 0.2), C(150, 154, 162))
	for _, x in { -2.2, 0, 2.2 } do
		decor(t:box('RackLoop', V(x - 0.15, 0.4, -0.15), V(x + 0.15, 2.6, 0.15), C(170, 174, 182), M.Plastic))
		decor(t:box('RackLoopTop', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 2.9, 0.8), C(170, 174, 182), M.Plastic))
	end
	for k = 1, bikes or 1 do bike(t, CFrame.new(-1.1 + (k - 1) * 2.2, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0), ({ C(60, 140, 240), C(240, 90, 60) })[k]) end
	return t
end
-- Newspaper box: a small blue studded box on legs with a window.
function District.newsBox(d, cf, color)
	local t = d:at(cf):group('NewsBox')
	for _, x in { -0.8, 0.8 } do sbox(t, 'NewsLeg', V(x - 0.15, 0, -0.6), V(x + 0.15, 1.2, 0.6), P.iron, true) end
	sbox(t, 'NewsBody', V(-1.1, 1.2, -0.8), V(1.1, 4.2, 0.8), color or C(40, 90, 200))
	sbox(t, 'NewsWindow', V(-0.8, 2.6, -0.9), V(0.8, 3.8, -0.8), P.st.glassB, true)
	return t
end
-- A parked car in the studded kit: a two-tone body, glass band, darker skirt, four black wheels (front = local -Z).
function District.car(d, cf, color)
	local k = d:at(cf):group('ParkedCar')
	local dark = color:Lerp(P.black, 0.3)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -3.3, 3.3 } do decor(k:part('Wheel', V(0.9, 2.1, 2.1), CFrame.new(x, 1.05, z) * CFrame.Angles(0, 0, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	sbox(k, 'CarSkirt', V(-2.3, 0.7, -5.2), V(2.3, 1.6, 5.2), dark)
	sbox(k, 'CarBody', V(-2.3, 1.6, -5.2), V(2.3, 3.0, 5.2), color)
	sbox(k, 'CarCabin', V(-2.0, 3.0, -2.2), V(2.0, 4.8, 2.8), color)
	sbox(k, 'CarGlass', V(-2.05, 3.2, -2.25), V(2.05, 4.5, 2.85), P.st.glassA, true)
	sbox(k, 'CarRoof', V(-2.1, 4.8, -2.0), V(2.1, 5.1, 2.6), dark, true)
	for _, x in { -1.6, 1.6 } do
		decor(k:box('Headlight', V(x - 0.5, 2.0, -5.3), V(x + 0.5, 2.6, -5.2), C(255, 244, 200), M.Plastic))
		decor(k:box('TailLight', V(x - 0.5, 2.0, 5.2), V(x + 0.5, 2.6, 5.3), C(220, 40, 40), M.Plastic))
	end
	return k
end

-- Corner Shop (stages 4-6): a T-junction on the right with a corner store on one corner (shopfronts on both streets,
-- produce, an ice chest, a bike rack), shops with flats above down the left, zebra crossings, a traffic light and a
-- stop sign, the side street closing at a fence and a parked car.
District.SHOPS = {
	{ sign = 'BARBER', color = C(40, 80, 180), stripes = { C(220, 50, 50), P.white, C(40, 80, 180), P.white } },
	{ sign = 'PIZZA', color = C(200, 46, 40), stripes = { C(200, 46, 40), P.white }, text = C(255, 222, 80) },
	{ sign = 'LAUNDRY', color = C(60, 150, 200), stripes = { C(60, 150, 200), P.white } },
	{ sign = 'SNEAKERS', color = C(36, 36, 44), stripes = { C(36, 36, 44), C(240, 240, 240) } },
	{ sign = 'DELI', color = C(40, 130, 70), stripes = { C(40, 130, 70), C(250, 220, 90) } },
	{ sign = 'PHONES', color = C(130, 60, 200), stripes = { C(130, 60, 200), P.white } },
}
function District.corner(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local sa = ({ 28, 30, 27 })[t] -- the side street from z' sa to sa + 18, always on the right
	local sb = sa + 18
	local storeNear = t ~= 2
	-- Left: three shops with flats above, fronts at |x| 26 behind a paved forecourt.
	District.floor(d, top, -1, ST.road + ST.walk, 26, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	local lw = ({ { 20, 20, 16 }, { 16, 22, 18 }, { 22, 16, 18 } })[t]
	local z = top
	for k = 1, 3 do
		local sh = District.SHOPS[(i + k) % #District.SHOPS + 1]
		local w = lw[k]
		local floors = (k + t) % 3 == 0 and 3 or 2
		brickBuilding(houseFrame(d, -1, z, w, 26), w, { name = 'Shop' .. k, floors = floors, depth = 38, roof = ({ 'flat', 'gable', 'hip' })[(k + t) % 3 + 1],
			wall = ({ P.st.brick, P.st.brickDeep, P.st.brickLight })[(k + i) % 3 + 1], bays = 2, winW = w / 2 - 4.6,
			shops = { { x0 = 1.6, x1 = w - 1.6, door = w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } } })
		z -= w
	end
	-- Right: the corner store, the side street, the far corner shop.
	local function rightBuilding(z0, z1, store, corner)
		local w = z1 - z0 -- (z0 < z1: z' runs away from the gate)
		local sh = store and { sign = 'CORNER STORE', color = C(30, 120, 60), stripes = { C(30, 120, 60), C(250, 214, 60) } } or District.SHOPS[(i + 4) % #District.SHOPS + 1]
		-- (right side: local x runs back up the street, so the side street side is 'left' for the near corner, 'right'
		-- for the far one)
		local shops = { { x0 = 1.6, x1 = w - 1.6, door = corner == 'left' and 4 or w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } }
		-- (the side face's local x runs from the back to the street on the 'left' face, from the street back on 'right')
		local near = corner == 'left' and function(a) return 40 - a end or function(a) return a end
		if store then table.insert(shops, { face = corner, x0 = math.min(near(3), near(18)), x1 = math.max(near(3), near(18)), door = near(15), sign = '24/7', color = sh.color, stripes = sh.stripes }) end
		brickBuilding(houseFrame(d, 1, top - z0, w, 24), w, { name = store and 'CornerStore' or 'CornerShop', floors = store and 2 or 3, roof = 'flat',
			wall = store and P.st.brickLight or P.st.brick, bays = 2, winW = w / 2 - 4.6, shops = shops, depth = 40,
			windows = (function()
				local list = { { face = 'front', x = w * 0.25, w = w / 2 - 4.6 }, { face = 'front', x = w * 0.75, w = w / 2 - 4.6 } }
				if store then table.insert(list, { face = corner, x = near(10.5), w = 12 }); table.insert(list, { face = corner, x = near(29), w = 12 }) end
				return list
			end)() })
	end
	District.floor(d, top, 1, ST.road + ST.walk, 24, 0, sa, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	District.floor(d, top, 1, ST.road + ST.walk, 24, sb, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	rightBuilding(0, sa, storeNear, 'left')
	rightBuilding(sb, 56, not storeNear, 'right')
	-- The side street: asphalt at sidewalk level between two narrow sidewalks with kerb stones, a zebra across its
	-- mouth, a fence and barriers at its dead end, the back wall behind, a parked car.
	local rx = ST.road + ST.walk
	District.floor(d, top, 1, rx, 62, sa + 3.4, sb - 3.4, ST.kerb + 0.05, P.st.road, 'SideRoad')
	for _, e in { { sa, sa + 3 }, { sb - 3, sb } } do
		District.floor(d, top, 1, rx, 62, e[1], e[2], ST.kerb + 0.3, P.st.walk, 'SideWalk')
		local kz = e[1] == sa and sa + 3 or sb - 3.4
		District.floor(d, top, 1, rx, 62, kz, kz + 0.4, ST.kerb + 0.36, P.st.kerbStone, 'SideKerb')
	end
	District.zebra(d, V(19.6, ST.kerb + 0.05, top - (sa + 3.4) - 1.2), 4, 1, V(0, 0, -2), 5)
	District.zebra(d, V(-7, 0, top - (sa - 4)), 1.4, 5, V(2, 0, 0), 8)
	decor(sbox(d, 'StopLine', V(-8.4, -0.05, top - (sa - 7.3)), V(8.4, 0.14, top - (sa - 6.7)), C(240, 240, 236))).CastShadow = false
	chainLink(d, V(58, ST.kerb, top - sa), V(58, ST.kerb, top - sb), 12)
	for k = 0, 2 do
		local bz = top - (sa + 4.5 + k * 4.5)
		sbox(d, 'Barrier', V(54.6, ST.kerb, bz - 1.9), V(56.4, ST.kerb + 3, bz + 1.9), C(206, 208, 214))
		for q = 0, 1 do sbox(d, 'BarrierStripe', V(54.5, ST.kerb + 1.2 + q * 1.2, bz - 1.95), V(56.5, ST.kerb + 1.8 + q * 1.2, bz + 1.95), C(220, 50, 50), true) end
	end
	District.backWall(d, top, 1, 62.4, sa, sb)
	District.car(d, CFrame.new(at(38, sa + 6.6)) * CFrame.Angles(0, math.rad(storeNear and 90 or -90), 0), ({ C(250, 200, 40), C(230, 230, 236), C(52, 110, 220) })[t])
	-- Corner furniture: the traffic light on the near corner, a stop sign facing the side street, a lamp a side.
	District.trafficLight(d, at(17.2, sa - 1.2), -1)
	District.stopSign(d, at(19.8, sb + 1.2))
	lantern(d, at(-20.5, 12), V(1, 0, 0))
	lantern(d, at(21, 9), V(-1, 0, 0))
	hydrant(d, at(-20.2, 51))
	-- The store's front: produce on pallets under the awning, the ice chest, a bike rack, a news box (clear of the
	-- targets' backstop on the right grass, x 17.8..19, z' 13..23.5).
	storeCrates(d, CFrame.new(at(22.2, storeNear and 7 or sb + 9)) * CFrame.Angles(0, math.rad(90), 0), 2)
	District.iceBox(d, CFrame.lookAt(at(22, storeNear and 24.8 or sb + 4), at(10, storeNear and 24.8 or sb + 4)))
	District.bikeRack(d, CFrame.new(at(26, sa + 1.4)) * CFrame.Angles(0, 0, 0), 2)
	District.newsBox(d, CFrame.lookAt(at(21.6, storeNear and 3.6 or sb + 2.4), at(10, storeNear and 3.6 or sb + 2.4)))
	-- Left shop props: a bench and bins, out of the left target band (z' 22..48 by the sidewalk).
	trashBags(d, CFrame.new(at(-24, 8)) * CFrame.Angles(0, 0.6, 0), 2)
	wheelieBin(d, CFrame.new(at(-24.4, 16)) * CFrame.Angles(0, math.pi, 0), C(40, 90, 160))
	storeCrates(d, CFrame.new(at(-23, 51)) * CFrame.Angles(0, math.rad(90), 0), 1)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brick, roof = 'flat', floors = 3 })
	-- street: a manhole and a drain
	decor(sbox(d, 'Manhole', V(-3.4, -0.2, top - 14 - 1.2), V(-1.0, 0.08, top - 14 + 1.2), P.st.manhole)).CastShadow = false
	return d
end

-- The Alley (stages 7-9): tall brick walls close in to |x| 20 on both sides (three and four storeys, flat roofs),
-- fire escapes, a glazed sky bridge across the alley, cables strung with bulbs overhead, service recesses with a
-- dumpster and a back door, wall lamps, bins along a paved gutter strip, puddles on the asphalt.
function District.alley(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local F = 20 -- the facades
	District.floor(d, top, -1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	District.floor(d, top, 1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	for _, s in { -1, 1 } do
		decor(sbox(d, 'GutterChannel', V(s * (ST.road + ST.walk), ST.kerb + 0.02, top), V(s * (ST.road + ST.walk + 0.7), ST.kerb + 0.1, top - 56), P.st.roadDark)).CastShadow = false
	end
	-- Each side: a tall block, a service recess (a one-storey back building 10 further back), another block.
	local plan = ({
		{ L = { { 0, 14, 4 }, { 14, 24, 'recess' }, { 24, 56, 3 } }, R = { { 0, 30, 3 }, { 30, 40, 'recess' }, { 40, 56, 4 } }, esc = { L = 1, R = 3 } },
		{ L = { { 0, 20, 3 }, { 20, 30, 'recess' }, { 30, 56, 4 } }, R = { { 0, 26, 4 }, { 26, 36, 'recess' }, { 36, 56, 3 } }, esc = { L = 3, R = 1 } },
		{ L = { { 0, 12, 3 }, { 12, 22, 'recess' }, { 22, 56, 4 } }, R = { { 0, 34, 4 }, { 34, 44, 'recess' }, { 44, 56, 3 } }, esc = { L = 3, R = 1 } },
	})[t]
	local walls = { P.st.brickDeep, P.st.brickDark:Lerp(P.st.brick, 0.5), P.st.brick, P.st.brickLight }
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	for _, s in { -1, 1 } do
		local side = s < 0 and 'L' or 'R'
		for k, b in plan[side] do
			local z0, z1 = b[1], b[2]
			local w = z1 - z0
			local za = top - z0
			if b[3] == 'recess' then
				-- the recess: paved, a one-storey back building with a door, a dumpster and bags
				District.floor(d, top, s, F, F + 10.2, z0, z1, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.18), 'RecessFloor')
				brickBuilding(houseFrame(d, s, za, w, F + 10), w, { name = 'BackBuilding', floors = 1, h = 13, roof = 'flat', depth = 34, wall = P.st.brickDark,
					windows = {}, entrance = { x = w / 2, kind = 'door', door = C(70, 76, 90), number = tostring(20 + i) } })
				-- (turned to run along the back wall, its front toward the way the player comes)
				dumpster(d, CFrame.new(V(s * (F + 5.2), ST.kerb + 0.08, top - (z0 + 3.4))) * CFrame.Angles(0, math.rad(90), 0))
				trashBags(d, CFrame.new(V(s * (F + 5.6), ST.kerb + 0.08, top - (z0 + 7.8))), 3)
			else
				local floors = b[3]
				local esc = plan.esc[side] == k
				local wall = walls[(k + i + (s > 0 and 1 or 0)) % #walls + 1]
				local tag = TAGS[(i + k) % #TAGS + 1]
				local n = math.max(2, math.floor(w / 8))
				-- (local x runs down the street on the left, back up it on the right)
				local function lx(zp) return s < 0 and zp - z0 or z1 - zp end
				local doorZ = s < 0 and (z0 < 20 and z0 + 5 or z1 - 4) or (z1 > 26 and z1 - 4 or z0 + 4)
				local okDoor = not (s < 0 and doorZ > 21 and doorZ < 48) and not (s > 0 and doorZ > 12 and doorZ < 25)
				brickBuilding(houseFrame(d, s, za, w, F), w, { name = 'AlleyBlock', floors = floors, roof = 'flat', depth = 44, wall = wall, bays = n, winW = math.min(6, w / n - 3),
					fireEscapes = esc and { { x = w / 2, w = math.min(12, w - 4) } } or nil,
					entrance = okDoor and { x = lx(doorZ), kind = 'door', door = C(60, 66, 80), number = tostring(i * 10 + k) } or nil,
					ac = { { 'front', w * 0.3, 16.5 }, floors > 3 and { 'front', w * 0.7, 31.5 } or nil },
					tags = k == 1 and { { 'front', w * 0.5, 9.6, tag[1], tag[2] } } or nil })
			end
		end
	end
	-- The sky bridge: a glazed brick link across the alley at the second floor, a stone sill and slate roof.
	local bz = ({ 32, 22, 40 })[t]
	local bridge = d:group('SkyBridge')
	local y0, y1 = 21, 30
	sbox(bridge, 'BridgeFloor', V(-F, y0 - 1.2, top - bz), V(F, y0, top - (bz + 8)), P.st.trim)
	sbox(bridge, 'BridgeWall', V(-F, y0, top - bz - 0.2), V(F, y0 + 2.4, top - (bz + 7.8)), walls[(i % 4) + 1])
	sbox(bridge, 'BridgeWall', V(-F, y1 - 1.6, top - bz - 0.2), V(F, y1, top - (bz + 7.8)), walls[(i % 4) + 1])
	for _, zf in { bz + 0.25, bz + 7.75 } do
		sbox(bridge, 'BridgeGlass', V(-F, y0 + 2.4, top - zf - 0.15), V(F, y1 - 1.6, top - zf + 0.15), P.st.glassA, true)
		for x = -F + 4, F - 3, 4 do sbox(bridge, 'BridgeMullion', V(x - 0.35, y0 + 2.4, top - zf - 0.3), V(x + 0.35, y1 - 1.6, top - zf + 0.3), P.st.mullion, true) end
	end
	sbox(bridge, 'BridgeRoof', V(-F, y1, top - bz + 0.6), V(F, y1 + 0.8, top - (bz + 8.6)), P.st.roofDark)
	sbox(bridge, 'BridgeFascia', V(-F, y1 - 0.2, top - bz + 0.7), V(F, y1 + 1.0, top - bz + 0.3), P.st.trim, true)
	for _, s in { -1, 1 } do
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 1), V(s * (F - 4), y0 - 1.2, top - bz - 1), 0.6, C(46, 50, 60), M.Plastic))
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 7), V(s * (F - 4), y0 - 1.2, top - bz - 7), 0.6, C(46, 50, 60), M.Plastic))
	end
	-- Two pipes across at the top, on brackets.
	local pz = ({ 12, 46, 14 })[t]
	for k, py in { 41, 42.4 } do
		decor(d:rod('Pipe', 0.5, 2 * F, CFrame.new(0, py, top - pz - k * 1.3), k == 1 and C(150, 154, 162) or C(196, 120, 60), M.Plastic))
	end
	-- Cables with bulbs, sagging from wall to wall.
	for k, cz in ipairs(({ { 6, 10, 36 }, { 8, 34, 48 }, { 4, 26, 50 } })[t]) do
		local yA, yB, sag = 38 - k * 3, 37 - k * 3, 2.4
		local a, b = V(-F, yA, top - cz), V(F, yB, top - cz - 5)
		local mid = (a + b) / 2 - V(0, sag, 0)
		decor(d:bar('Cable', a, mid, 0.15, C(30, 32, 38), M.Plastic))
		decor(d:bar('Cable', mid, b, 0.15, C(30, 32, 38), M.Plastic))
		for q = 1, 9 do
			local u = q / 10
			local p = u < 0.5 and a:Lerp(mid, u * 2) or mid:Lerp(b, (u - 0.5) * 2)
			local bulb = decor(d:box('Bulb', p - V(0.3, 0.75, 0.3), p - V(-0.3, 0.15, -0.3), ({ C(255, 214, 120), C(255, 120, 160), C(120, 220, 255) })[q % 3 + 1], M.Neon))
			bulb.CastShadow = false
		end
	end
	-- Wall lamps on brackets, bins along the gutter strip (clear of the targets' backstops), puddles.
	for k, lp in ipairs({ { -1, 10 }, { 1, 8 }, { -1, 50 }, { 1, 44 } }) do
		local s, zp = lp[1], lp[2]
		local base = V(s * F, 13, top - zp)
		local arm = sbox(d, 'WallLampArm', base + V(-s * 0, 0, -0.2), base + V(-s * 1.8, 0.4, 0.2), C(46, 50, 60), true)
		sbox(d, 'WallLampHead', base + V(-s * 1.2, -1.0, -0.6), base + V(-s * 2.4, 0.2, 0.6), C(46, 50, 60), true)
		decor(d:box('WallLampGlow', base + V(-s * 1.35, -1.2, -0.45), base + V(-s * 2.25, -1.0, 0.45), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	for _, b in ipairs({ { -1, 4 }, { -1, 8 }, { 1, 30 }, { 1, 47 }, { -1, 51 } }) do
		wheelieBin(d, CFrame.new(V(b[1] * 18.4, ST.kerb + 0.08, top - b[2])) * CFrame.Angles(0, b[1] < 0 and math.pi or 0, 0), ({ C(40, 120, 70), C(40, 90, 160), C(70, 74, 84) })[(b[2] + i) % 3 + 1])
	end
	for _, pd in ipairs({ { -3, 18, 4, 3 }, { 4, 37, 3, 5 }, { -5, 50, 3, 2.5 } }) do
		decor(d:box('Puddle', V(pd[1] - pd[3] / 2, -0.05, top - pd[2] - pd[4] / 2), V(pd[1] + pd[3] / 2, 0.06, top - pd[2] + pd[4] / 2), C(70, 90, 120), M.Glass)).Transparency = 0.3
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDark:Lerp(P.st.brick, 0.5), roof = 'flat', floors = 4 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 4 })
	return d
end

-- Basketball hoop on a frame whose +Z faces the court: a padded post, an arm, a white backboard with a red square,
-- an orange rim and a white net.
function District.hoop(d, cf, sideMount)
	local h = d:at(cf):group('Hoop')
	if not sideMount then -- (P3: a side-mounted hoop hangs from an arm over the court: no pole in the walk)
		sbox(h, 'HoopBase', V(-1.2, 0, -1.2), V(1.2, 1, 1.2), C(46, 50, 60))
		sbox(h, 'HoopPost', V(-0.5, 1, -0.5), V(0.5, 11.5, 0.5), C(60, 66, 80))
		sbox(h, 'HoopPad', V(-0.8, 1, -0.8), V(0.8, 5, 0.8), C(40, 90, 200), true)
	end
	sbox(h, 'HoopArm', V(-0.35, 10.6, 0), V(0.35, 11.2, 2.6), C(60, 66, 80), true)
	sbox(h, 'Backboard', V(-3, 9.2, 2.6), V(3, 13, 3), P.white, true)
	decor(h:box('BoardSquare', V(-1.1, 9.9, 3), V(1.1, 11.3, 3.1), C(220, 60, 50), M.Plastic))
	for q = 0, 7 do
		local a = q / 8 * math.pi * 2
		decor(h:part('Rim', V(0.8, 0.15, 0.18), CFrame.new(math.cos(a) * 0.95, 9.6, 4.1 + math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), C(240, 110, 40), M.Plastic))
		decor(h:bar('Net', V(math.cos(a) * 0.9, 9.55, 4.1 + math.sin(a) * 0.9), V(math.cos(a) * 0.5, 8.4, 4.1 + math.sin(a) * 0.5), 0.08, P.white, M.Plastic))
	end
	return h
end
-- Floodlight pole: a dark base, a tall pole and a head of four lamps turned toward the court (-Z of the frame, as
-- CFrame.lookAt aims it).
function District.floodlight(d, cf, h)
	h = h or 26
	local f = d:at(cf):group('Floodlight')
	sbox(f, 'FloodBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), C(46, 50, 60))
	sbox(f, 'FloodPole', V(-0.5, 1.2, -0.5), V(0.5, h, 0.5), C(150, 156, 166))
	sbox(f, 'FloodFrame', V(-2.6, h, -0.6), V(2.6, h + 3, 0.6), C(60, 66, 80), true)
	for _, x in { -1.3, 1.3 } do for _, y in { h + 0.75, h + 2.25 } do
		decor(f:box('FloodLamp', V(x - 1, y - 0.6, -0.8), V(x + 1, y + 0.6, -0.6), C(250, 248, 230), M.Neon)).CastShadow = false
	end end
	return f
end
-- Bleachers along Z on side s: three studded aluminium tiers stepping up away from the court (x0 = the front edge),
-- blue seat boards and a back rail.
function District.bleachers(d, top, s, x0, za, zb)
	local g = d:group('Bleachers')
	for k = 0, 2 do
		local xa, xb = x0 + k * 1.8, x0 + 6
		sbox(g, 'BleacherTier', V(s * xa, P.street.kerb, top - za), V(s * xb, P.street.kerb + 1.4 * (k + 1), top - zb), C(186, 192, 204))
		sbox(g, 'BleacherSeat', V(s * (xa + 0.2), P.street.kerb + 1.4 * (k + 1), top - za - 0.3), V(s * (xa + 1.2), P.street.kerb + 1.4 * (k + 1) + 0.4, top - zb + 0.3), C(40, 90, 200), true)
	end
	decor(g:box('BleacherRail', V(s * (x0 + 5.8), P.street.kerb + 6.6, top - za), V(s * (x0 + 6), P.street.kerb + 6.9, top - zb), C(150, 156, 166), M.Plastic))
	for z = za, zb, (zb - za) / 4 do decor(g:box('BleacherRailPost', V(s * (x0 + 5.8), P.street.kerb + 4.2, top - z - 0.1), V(s * (x0 + 6), P.street.kerb + 6.6, top - z + 0.1), C(150, 156, 166), M.Plastic)) end
	return g
end

-- The Courts (stages 10-12): the right side opens onto a fenced basketball court (hoops, lines, bleachers, benches,
-- floodlights, a mural wall behind), an apartment block with balconies on the left, trees on its grass.
District.COURTS = {
	{ court = C(226, 120, 52), key = C(196, 92, 40), ground = C(60, 128, 92) },
	{ court = C(52, 112, 210), key = C(36, 86, 170), ground = C(84, 92, 110) },
	{ court = C(196, 60, 60), key = C(160, 44, 44), ground = C(46, 70, 120) },
}
function District.courts(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local K = District.COURTS[t]
	-- Left: apartments with balconies (three storeys), a front garden strip with trees.
	local lw = ({ { 30, 26 }, { 24, 32 }, { 28, 28 } })[t]
	local z = top
	District.floor(d, top, -1, FRONT, 40, 0, 56, ST.kerb, P.st.grass, 'Yard')
	for k = 1, 2 do
		local w = lw[k]
		brickBuilding(houseFrame(d, -1, z, w, 40), w, { name = 'Apartments', floors = 3, roof = k == 1 and 'flat' or 'hip', pilasters = math.max(2, math.floor(w / 10)),
			wall = ({ P.st.brickLight, P.st.brick, P.st.brickDeep })[(k + t) % 3 + 1], depth = 24,
			balconies = { { x = w / 2, w = 8 } }, entrance = { x = k == 1 and 5 or w - 5, kind = 'stoop', door = ({ C(40, 110, 76), C(36, 60, 110), C(170, 50, 50) })[(k + t) % 3 + 1], number = tostring(100 + i * 2 + k) } })
		z -= w
	end
	-- the plank fence opens at both stoops, with paver paths across the grass
	fence(d, -ST.fence, top, top - ST.endZ, 1, nil, { { top - 3.2, top - 6.8 }, { top - 49.2, top - 52.8 } })
	for _, zc in { 5, 51 } do
		for x = ST.road + ST.walk, 34.4, 2 do sbox(d, 'Paver', V(-x, ST.kerb - 0.3, top - zc + 1.5), V(-math.min(x + 1.9, 34.5), ST.kerb + 0.07, top - zc - 1.5), (x // 2) % 2 == 0 and P.st.kerbStone or P.st.sill) end
	end
	for k, zp in ipairs({ 9, 30, 52 }) do tree(d, at(-26.5, zp), i * 100 + k, 0.95, 20 + k * 25) end
	lantern(d, at(-20.5, 15), V(1, 0, 0))
	-- Right: the apron beside the street, where the players' tunnel stands (the fenced yard below).
	local x0, x1, za, zb = 22, 62.4, 3, 55
	District.floor(d, top, 1, ST.road + ST.walk, x1, 0, 56, ST.kerb + 0.08, K.ground, 'CourtGround')
	-- THE COURT IS THE STREET (P3, BRIEF29, the user: "make some of the stages a basketball court, without it being on the
	-- side, as soon as you step in it's a basketball court"): a full court laid over the road and both sidewalks, sideline to
	-- sideline (x +-15, z' 6..58) with its out-of-bounds border, the key and the free-throw circle at each end, the three-point
	-- arc, the half-court line and the centre circle round the fight spot (z' 32). The hoops hang from arms off the left
	-- side so no pole stands in the walk from gate to gate. Layers (tops): sidewalk 0.6, border 0.66, court 0.72, key 0.76,
	-- lines 0.80.
	local sl = ST.road + ST.walk -- 16.5, the sidewalks' outer edge
	local yb, yc, yk, yl = ST.kerb + 0.06, ST.kerb + 0.12, ST.kerb + 0.16, ST.kerb + 0.2
	sbox(d, 'CourtBorder', V(-sl, ST.kerb - 0.4, top - 4.5), V(sl, yb, top - 59.5), K.ground:Lerp(P.black, 0.12))
	sbox(d, 'Court', V(-15, ST.kerb - 0.3, top - 6), V(15, yc, top - 58), K.court)
	local function paint(a, b, y, color, w)
		local lo, hi = V(math.min(a.X, b.X), y - 0.04, math.min(top - a.Z, top - b.Z)), V(math.max(a.X, b.X), y, math.max(top - a.Z, top - b.Z))
		decor(d:box('CourtLine', lo, hi, color or P.white, M.Plastic)).CastShadow = false
	end
	local function mark(x0_, z0_, x1_, z1_) paint(V(x0_ - 0.2, 0, z0_ - 0.2), V(x1_ + 0.2, 0, z1_ + 0.2), yl, P.white) end
	mark(-15, 6, 15, 6); mark(-15, 58, 15, 58); mark(-15, 6, -15, 58); mark(15, 6, 15, 58); mark(-15, 32, 15, 32)
	for _, e in { { 6, 17.6 }, { 46.4, 58 } } do
		decor(d:box('CourtKey', V(-4.4, yc, top - e[2]), V(4.4, yk, top - e[1]), K.key, M.Plastic)).CastShadow = false
		mark(-4.4, e[1], -4.4, e[2]); mark(4.4, e[1], 4.4, e[2])
		mark(-4.4, e[1] == 6 and 17.6 or 46.4, 4.4, e[1] == 6 and 17.6 or 46.4)
	end
	local function arc(cx, cz, r, a0, a1, n)
		for q = 0, n - 1 do
			local t0, t1 = a0 + (a1 - a0) * q / n, a0 + (a1 - a0) * (q + 1) / n
			local p0 = V(cx + math.cos(t0) * r, yl - 0.02, top - (cz + math.sin(t0) * r))
			local p1 = V(cx + math.cos(t1) * r, yl - 0.02, top - (cz + math.sin(t1) * r))
			decor(d:part('CourtArc', V(0.4, 0.04, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), P.white, M.Plastic)).CastShadow = false
		end
	end
	arc(0, 32, 3.6, 0, math.pi * 2, 14) -- the centre circle, round the fight spot
	arc(0, 17.6, 4.4, 0, math.pi, 8) -- the free-throw circles
	arc(0, 46.4, 4.4, math.pi, math.pi * 2, 8)
	arc(0, 8, 13, math.rad(14), math.rad(166), 14) -- the three-point arcs
	arc(0, 56, 13, math.rad(194), math.rad(346), 14)
	-- the hoops: the board and rim at each baseline on the centre line, hung from a long arm off a pole on the left grass
	for _, hp in { { 4, math.pi }, { 60, 0 } } do
		District.hoop(d, CFrame.new(at(0, hp[1])) * CFrame.Angles(0, hp[2], 0), true)
		sbox(d, 'HoopSideArm', V(-18.4, ST.kerb + 10.4, top - hp[1] - 0.35), V(0.35, ST.kerb + 11.0, top - hp[1] + 0.35), C(60, 66, 80), true)
		sbox(d, 'HoopSideBrace', V(-18.4, ST.kerb + 7.8, top - hp[1] - 0.2), V(-17.6, ST.kerb + 10.4, top - hp[1] + 0.2), C(60, 66, 80))
		sbox(d, 'HoopSideBase', V(-19.4, ST.kerb, top - hp[1] - 1.2), V(-17.0, ST.kerb + 1, top - hp[1] + 1.2), C(46, 50, 60))
		sbox(d, 'HoopSidePost', V(-18.9, ST.kerb + 1, top - hp[1] - 0.5), V(-17.9, ST.kerb + 11.2, top - hp[1] + 0.5), C(60, 66, 80))
		sbox(d, 'HoopSidePad', V(-19.3, ST.kerb + 1, top - hp[1] - 0.8), V(-17.5, ST.kerb + 5, top - hp[1] + 0.8), C(40, 90, 200), true)
	end
	-- The fence: chain-link round three sides with a gateway onto the grass, the back wall behind with a mural.
	chainLink(d, V(x0, ST.kerb, top - za), V(x0, ST.kerb, top - zb), 12, { { 23, 27.5 } })
	chainLink(d, V(x0, ST.kerb, top - za), V(x1 - 0.4, ST.kerb, top - za), 12)
	chainLink(d, V(x0, ST.kerb, top - zb), V(x1 - 0.4, ST.kerb, top - zb), 12)
	District.backWall(d, top, 1, x1, 0, 56, 16)
	local mural = ghost(d:box('Mural', V(x1 - 0.08, ST.kerb + 3, top - 14), V(x1 - 0.02, ST.kerb + 13, top - 42), P.white, M.SmoothPlastic))
	local g = surface(mural, Enum.NormalId.Left, 12)
	line(g, 'Mural', ({ 'HOOD BALLERS', 'GAME ON', 'NEXT UP' })[t], ({ C(255, 210, 60), C(255, 96, 206), C(70, 220, 255) })[t], FONT.tag, 0.1, 0.8, P.black, 4).Rotation = -4
	District.bleachers(d, top, 1, 23.4, 5, 20) -- (P3: behind the fence, watching the street court; clear of the gateway at z' 23..27.5)
	for _, bz in { 18, 46 } do
		local b = d:at(CFrame.lookAt(at(-18.4, bz), at(-8, bz))):group('TeamBench')
		sbox(b, 'BenchSeat', V(-3.5, 1.4, -0.7), V(3.5, 1.8, 0.7), C(40, 90, 200))
		for _, x in { -3, 3 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	end
	for k, bp in ipairs({ { -9, 14 }, { 7.5, 44 }, { -3, 33 } }) do decor(d:part('Basketball', V(1.2, 1.2, 1.2), CFrame.new(at(bp[1], bp[2]) + V(0, 0.75, 0)), C(236, 112, 40), M.Plastic, Enum.PartType.Ball)) end
	sbox(d, 'WaterCooler', at(24.4, 44.4), at(25.8, 45.8) + V(0, 2.2, 0), C(40, 120, 220))
	-- (brief 29: the far-left one stands outside the fence now, clear of the players' tunnel)
	for _, fl in { { -19.6, 6 }, { 19.6, 6 }, { -19.6, 58 }, { 19.6, 58 } } do
		District.floodlight(d, CFrame.lookAt(at(fl[1], fl[2]), at(0, 32)), 26)
	end
	-- (brief 29) The players' tunnel in the court's far corner (PropModels 'CourtTunnel', built with BoxKit in Blender's
	-- kit), its mouth toward the gate: the court crew waits inside and jogs out as you walk in (EnemyRules.Courts: the
	-- mouth at x 26.6, z' 45.4; Waves.client draws the walk-out). Its walls are solid; the inside stays open.
	local props = Armory.optional('PropModels')
	local okT, tunnel = false, nil
	if props and props.build then okT, tunnel = pcall(props.build, 'CourtTunnel', 1) end
	if okT and tunnel and tunnel.PrimaryPart then
		tunnel.Name = 'PlayersTunnel'
		local goal = d:world(CFrame.new(at(26.6, 50.4) + V(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0))
		local delta = goal * tunnel.PrimaryPart.CFrame:Inverse()
		for _, p in tunnel:GetDescendants() do
			if p:IsA('BasePart') then
				p.CFrame = delta * p.CFrame
				p.Anchored, p.CanTouch, p.CanQuery = true, false, false
				p.CanCollide = p.Name == 'Wall' or p.Name == 'Back' or p.Name == 'Post'
			end
		end
		tunnel.Parent = d.parent
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickLight, roof = 'hip', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { name = 'Clubhouse', wall = P.st.brickDeep, roof = 'flat', floors = 1, h = 14 })
	return d
end

-- Corrugated metal shed on a lot frame (+Z out of the front): a darker plinth, the wall with a lighter rib every 2.6
-- studs along the front, a dark sign band, a low gable roof along the street with a ridge cap.
function District.shed(c, w, dep, H, color, sign)
	local g = c:group('Warehouse')
	local dark = color:Lerp(P.black, 0.3)
	sbox(g, 'ShedWall', V(0, -1, -dep), V(w, H, 0), color)
	sbox(g, 'ShedPlinth', V(-0.3, -1, -dep - 0.3), V(w + 0.3, 2.2, 0.3), dark)
	for x = 1.3, w - 1, 2.6 do decor(g:box('ShedRib', V(x - 0.4, 2.2, 0), V(x + 0.4, H - 2.6, 0.3), color:Lerp(P.white, 0.14), M.Plastic)) end
	local band = sbox(g, 'ShedBand', V(-0.3, H - 2.6, -dep - 0.3), V(w + 0.3, H, 0.4), dark)
	if sign then line(surface(band, Enum.NormalId.Back, 16), 'Sign', sign, P.white, FONT.loud, 0.1, 0.8, P.black, 3) end
	gableRoof(g, w, dep, H, dep * 0.18, 'x', color:Lerp(P.white, 0.2))
	return g
end
-- Shipping container in the studded kit (8 wide, 20 long along local Z, 8.6 tall): body, darker corner posts and top
-- rim, door end with locking bars.
function District.container(d, cf, color)
	local k = d:at(cf):group('Container')
	local dark = color:Lerp(P.black, 0.28)
	sbox(k, 'ContainerBody', V(-4, 0, -10), V(4, 8.6, 10), color)
	for _, x in { -4.2, 3.6 } do for _, z in { -10.2, 9.6 } do sbox(k, 'ContainerPost', V(x, 0, z), V(x + 0.6, 8.6, z + 0.6), dark, true) end end
	sbox(k, 'ContainerRim', V(-4.2, 8.2, -10.2), V(4.2, 8.8, 10.2), dark, true)
	for z = -7.5, 7.6, 3 do for _, x in { -4.15, 4.0 } do decor(k:box('ContainerRib', V(x, 0.4, z - 0.45), V(x + 0.15, 8.2, z + 0.45), color:Lerp(P.white, 0.1), M.Plastic)) end end
	for _, x in { -1.6, 1.6 } do decor(k:box('ContainerBar', V(x - 0.15, 0.6, 10), V(x + 0.15, 8, 10.25), dark, M.Plastic)) end
	return k
end
-- Forklift (front = local -Z): yellow body, a dark counterweight, the cab frame, mast and forks.
function District.forklift(d, cf)
	local k = d:at(cf):group('Forklift')
	local y = C(250, 196, 40)
	for _, x in { -1.6, 1.6 } do for _, z in { -1.6, 1.8 } do decor(k:part('Wheel', V(0.8, 1.6, 1.6), CFrame.new(x, 0.8, z), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end end
	sbox(k, 'LiftBody', V(-1.6, 0.6, -2.2), V(1.6, 2.6, 2.6), y)
	sbox(k, 'LiftWeight', V(-1.7, 0.6, 2.2), V(1.7, 3.2, 3.2), C(46, 50, 60))
	sbox(k, 'LiftSeat', V(-0.8, 2.6, 0.4), V(0.8, 3.4, 1.8), C(30, 32, 36), true)
	for _, x in { -1.4, 1.4 } do
		decor(k:box('CabPost', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 6.4, -0.5), C(30, 32, 36), M.Plastic))
		decor(k:box('CabPost', V(x - 0.15, 2.6, 2.0), V(x + 0.15, 6.4, 2.3), C(30, 32, 36), M.Plastic))
	end
	sbox(k, 'CabRoof', V(-1.6, 6.4, -0.9), V(1.6, 6.7, 2.4), C(30, 32, 36), true)
	sbox(k, 'Mast', V(-1.2, 0.6, -2.8), V(1.2, 7.2, -2.3), C(60, 66, 80), true)
	for _, x in { -0.8, 0.8 } do sbox(k, 'Fork', V(x - 0.2, 0.5, -5.6), V(x + 0.2, 0.8, -2.8), C(60, 66, 80), true) end
	return k
end

-- The Yards (stages 13-15): concrete aprons; a corrugated warehouse with a loading dock (bumpers, roll-up doors, a
-- canopy, stairs) on one side; a container yard behind chain-link with a sliding gate, stacks two high, a forklift
-- and pallets on the other; floodlights, drums and barriers.
function District.yards(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local apron = C(196, 198, 202)
	for _, s in { -1, 1 } do District.floor(d, top, s, ST.road + ST.walk, 63, 0, 56, ST.kerb + 0.08, apron, 'Apron') end
	for _, st in ipairs({ { -22, 8, 3, 2 }, { -26, 32, 4, 3 }, { 20.5, 6, 2.5, 3 }, { 21, 40, 3, 2 }, { -21, 50, 2, 2.5 } }) do
		decor(sbox(d, 'OilStain', at(st[1] - st[3] / 2, st[2] - st[4] / 2) + V(0, 0.06, 0), at(st[1] + st[3] / 2, st[2] + st[4] / 2) + V(0, 0.11, 0), apron:Lerp(P.black, 0.35))).CastShadow = false
	end
	for _, s in { -1, 1 } do decor(sbox(d, 'LaneLine', V(s * 17.4, ST.kerb + 0.08, top), V(s * 17.9, ST.kerb + 0.13, top - 56), C(250, 204, 40))).CastShadow = false end
	-- Left: the warehouse and its dock.
	local wcol = ({ C(84, 118, 170), C(150, 156, 166), C(120, 140, 110) })[t]
	local wf = 30
	District.shed(houseFrame(d, -1, top - 2, 52, wf), 52, 34, 22, wcol, 'DEPOT ' .. i)
	District.floor(d, top, -1, wf - 0.2, 64, 0, 2, ST.kerb + 0.08, apron, 'Apron')
	District.backWall(d, top, -1, 64, 0, 2, 14)
	District.backWall(d, top, -1, 64, 54, 56, 14)
	local dz0, dz1 = 10, 44
	sbox(d, 'Dock', V(-wf, -1, top - dz0), V(-(wf - 5), 4.2, top - dz1), C(176, 178, 184))
	sbox(d, 'DockEdge', V(-(wf - 5) - 0.3, 3.8, top - dz0), V(-(wf - 5) + 0.3, 4.3, top - dz1), C(250, 204, 40), true)
	for zb = dz0 + 3, dz1 - 2, 6 do sbox(d, 'DockBumper', V(-(wf - 5) + 0.2, 1.4, top - zb - 0.7), V(-(wf - 5) - 0.6, 3.6, top - zb + 0.7), C(30, 32, 36), true) end
	for k, s in ipairs({ { dz1, dz1 + 1.1, 3.4 }, { dz1 + 1.1, dz1 + 2.2, 2.2 }, { dz1 + 2.2, dz1 + 3.3, 1.0 } }) do
		sbox(d, 'DockStep', V(-wf, -1, top - s[1]), V(-(wf - 3), s[3], top - s[2]), C(176, 178, 184))
	end
	for _, dzc in { 19, 35 } do
		sbox(d, 'RollDoorFrame', V(-wf + 0.2, 4.2, top - dzc - 6.6), V(-wf - 0.4, 16.6, top - dzc + 6.6), wcol:Lerp(P.black, 0.4))
		sbox(d, 'RollDoor', V(-wf + 0.35, 4.2, top - dzc - 5.8), V(-wf - 0.4, 15.8, top - dzc + 5.8), C(178, 184, 194))
		for yy = 5.4, 15, 1.2 do decor(d:box('DoorSlat', V(-wf + 0.45, yy, top - dzc - 5.8), V(-wf + 0.3, yy + 0.25, top - dzc + 5.8), C(130, 136, 148), M.Plastic)) end
	end
	-- a clerestory strip high on the front, lamps over the doors, an office door with its own canopy at the far end
	sbox(d, 'Clerestory', V(-wf + 0.15, 19.4, top - 4), V(-wf - 0.2, 22.2, top - 52), P.st.glassA, true)
	for zc = 4, 52, 4 do sbox(d, 'ClerestoryBar', V(-wf + 0.3, 19.4, top - zc - 0.3), V(-wf - 0.2, 22.2, top - zc + 0.3), wcol:Lerp(P.black, 0.4), true) end
	for _, dzc in { 19, 35 } do
		local lb = sbox(d, 'DoorLamp', V(-wf + 1.4, 17.0, top - dzc - 0.8), V(-wf, 17.4, top - dzc + 0.8), C(46, 50, 60), true)
		decor(d:box('DoorLampGlow', V(-wf + 1.3, 16.9, top - dzc - 0.6), V(-wf + 0.1, 17.0, top - dzc + 0.6), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	sbox(d, 'OfficeDoor', V(-wf + 0.3, ST.kerb, top - 47.5), V(-wf - 0.2, ST.kerb + 7.6, top - 50.5), C(70, 76, 90))
	sbox(d, 'OfficeDoorFrame', V(-wf + 0.2, ST.kerb, top - 47), V(-wf - 0.2, ST.kerb + 8.2, top - 51), wcol:Lerp(P.black, 0.4))
	sbox(d, 'OfficeCanopy', V(-wf, ST.kerb + 9, top - 46.2), V(-wf + 2.6, ST.kerb + 9.5, top - 51.8), C(46, 50, 60), true)
	sbox(d, 'OfficeWindow', V(-wf + 0.2, ST.kerb + 3.4, top - 52.4), V(-wf - 0.2, ST.kerb + 7.2, top - 53.6), P.st.glassB, true)
	sbox(d, 'DockCanopy', V(-wf, 17.4, top - dz0 + 1), V(-(wf - 6.5), 18.2, top - dz1 - 1), wcol:Lerp(P.black, 0.25))
	for zb = dz0 + 2, dz1 - 1, 10 do decor(d:bar('CanopyBrace', V(-wf, 13.4, top - zb), V(-(wf - 6), 17.4, top - zb), 0.4, C(46, 50, 60), M.Plastic)) end
	pallet(d, CFrame.new(V(-(wf - 2), 4.2, top - 26)))
	crate(d, CFrame.new(V(-(wf - 2), 5.0, top - 26)) * CFrame.Angles(0, 0.2, 0), 2.6)
	for k, dp in ipairs({ { -21.5, 6 }, { -22.6, 7.6 }, { -21, 8.8 } }) do
		local drum = d:post('Drum', 1.1, 3.4, at(dp[1], dp[2]), ({ C(40, 90, 200), C(200, 50, 40), C(40, 90, 200) })[k], M.Plastic)
		studs(drum)
		decor(d:post('DrumRim', 1.18, 0.3, at(dp[1], dp[2]) + V(0, 3.2, 0), C(30, 32, 36), M.Plastic))
	end
	-- Right: the container yard.
	local fx = 23
	chainLink(d, V(fx, ST.kerb, top - 2), V(fx, ST.kerb, top - 54), 12, { { 20, 34 } })
	chainLink(d, V(fx, ST.kerb, top - 2), V(63, ST.kerb, top - 2), 12)
	chainLink(d, V(fx, ST.kerb, top - 54), V(63, ST.kerb, top - 54), 12)
	District.backWall(d, top, 1, 63, 0, 56, 14)
	-- the sliding gate, shut: a framed chain-link leaf on wheels across the gap, a sign
	local gate = d:group('YardGate')
	sbox(gate, 'GateFrame', V(fx - 0.2, ST.kerb + 0.6, top - 22), V(fx + 0.3, ST.kerb + 11.4, top - 36), C(150, 156, 166))
	local mesh = gate:box('GateMesh', V(fx - 0.25, ST.kerb + 1.2, top - 22.6), V(fx + 0.35, ST.kerb + 10.8, top - 35.4), C(70, 74, 82), M.DiamondPlate)
	mesh.Transparency = 0.45
	for _, gz in { 23, 35 } do decor(gate:part('GateWheel', V(0.5, 1.2, 1.2), CFrame.new(fx + 0.05, ST.kerb + 0.6, top - gz), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	local sign = sbox(gate, 'YardSign', V(fx - 0.5, ST.kerb + 6, top - 26.5), V(fx - 0.3, ST.kerb + 8.6, top - 31.5), P.white, true)
	line(surface(sign, Enum.NormalId.Left, 30), 'Sign', 'YARD ' .. i, C(200, 40, 40), FONT.title, 0.12, 0.76)
	local colors = { C(196, 52, 42), C(44, 96, 186), C(46, 150, 90), C(232, 130, 40) }
	local rows = ({ { { 32, 3, 2 }, { 32, 30, 1 }, { 45, 5, 2 }, { 45, 31, 2 }, { 57, 4, 1 }, { 57, 30, 2 } },
		{ { 32, 4, 1 }, { 32, 30, 2 }, { 45, 4, 2 }, { 45, 30, 1 }, { 57, 4, 2 }, { 57, 30, 2 } },
		{ { 32, 3, 2 }, { 32, 30, 2 }, { 45, 5, 1 }, { 45, 31, 2 }, { 57, 4, 2 }, { 57, 30, 1 } } })[t]
	for k, r in ipairs(rows) do
		for lvl = 0, r[3] - 1 do
			District.container(d, CFrame.new(at(r[1], r[2] + 10.6) + V(0, -ST.kerb + ST.kerb + 0.08 + lvl * 8.7, 0)) * CFrame.Angles(0, math.rad((k * 3 + lvl * 2) % 5 - 2), 0), colors[(k + lvl + i) % #colors + 1])
		end
	end
	District.forklift(d, CFrame.new(at(38.5, 27.5) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(70), 0))
	-- the gatehouse by the gate (inside), a stack of tyres, a second pallet stack
	local booth = d:at(CFrame.new(at(26.6, 41) + V(0, 0.08, 0))):group('Gatehouse')
	sbox(booth, 'BoothBase', V(-2.4, 0, -2.6), V(2.4, 1, 2.6), C(150, 156, 166))
	sbox(booth, 'BoothWall', V(-2.2, 1, -2.4), V(2.2, 3.4, 2.4), C(236, 238, 242))
	sbox(booth, 'BoothGlass', V(-2.25, 3.4, -2.45), V(2.25, 6.2, 2.45), P.st.glassA, true)
	for _, x in { -2.2, 1.9 } do for _, z in { -2.4, 2.1 } do sbox(booth, 'BoothPost', V(x, 3.4, z), V(x + 0.3, 6.2, z + 0.3), C(236, 238, 242), true) end end
	sbox(booth, 'BoothRoof', V(-2.8, 6.2, -3), V(2.8, 6.9, 3), C(46, 96, 186))
	for k = 0, 2 do decor(d:part('Tyre', V(1, 2.4, 2.4), CFrame.new(at(26.2, 51.5) + V(0, 0.6 + k * 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder)) end
	for k = 0, 1 do
		pallet(d, CFrame.new(at(39, 52) + V(0, 0.08 + k * 0.8, 0)) * CFrame.Angles(0, k * 0.15, 0))
	end
	crate(d, CFrame.new(at(39, 52) + V(0, 1.68, 0)) * CFrame.Angles(0, 0.2, 0), 3)
	pallet(d, CFrame.new(at(25.6, 8) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	crate(d, CFrame.new(at(25.6, 8) + V(0, 0.88, 0)), 2.8)
	pallet(d, CFrame.new(at(25.6, 28) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	for k = 0, 2 do
		local bz = top - (4 + k * 4)
		sbox(d, 'Barrier', V(19.4, ST.kerb, bz - 1.8), V(21.2, ST.kerb + 3, bz + 1.8), C(206, 208, 214))
		sbox(d, 'BarrierStripe', V(19.3, ST.kerb + 1.6, bz - 1.85), V(21.3, ST.kerb + 2.2, bz + 1.85), C(250, 204, 40), true)
	end
	District.floodlight(d, CFrame.lookAt(at(-20.5, 14), at(0, 28)), 24)
	District.floodlight(d, CFrame.lookAt(at(26, 50), at(45, 28)), 26)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = C(150, 156, 166), roof = 'flat', floors = 2 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = wcol, roof = 'flat', floors = 2 })
	return d
end

local function streetStage(ctx, i)
	local top = stageTop(i)
	local ST = P.street
	local d = ctx:group('Stage' .. i)
	-- The fight hook stays (V2.Fights, HoodFightPad) as an invisible marker: the picture's road has no pad.
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	local zEnd = top - ST.endZ
	-- Hood touches on the long fronts: a window air-con box and a spray-painted tag above the fence, a different word
	-- each side and stage (kid-friendly ones).
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	local plan = PLANS[i]
	for _, s in { -1, 1 } do
		local tag = TAGS[(i * 2 + (s > 0 and 1 or 0)) % #TAGS + 1]
		local function lx(zp) return s < 0 and zp or ST.endZ - zp end -- (the lot runs along -Z on the left, +Z on the right)
		local gaps = {}
		if plan then
			local z = top
			for _, g in plan.gates[s < 0 and 'L' or 'R'] do table.insert(gaps, { top - g[1], top - g[2] }) end
			for _, h in plan[s < 0 and 'L' or 'R'] do
				if h.yard then
					sideYard(d, s, z, h[1], top, i * 100 + 77)
					picketFence(d, s * ST.fence, z, z - h[1], -s)
					z -= h[1]
					continue
				end
				brickBuilding(houseFrame(d, s, z, h[1], h[2]), h[1], h[3])
				-- the yard in front of a set-back house
				if h[2] > FRONT then sbox(d, 'Yard', V(s * FRONT, -1, z - h[1]), V(s * h[2], ST.kerb, z), P.st.grass) end
				-- its boundary: the tall plank fence of the picture, a low picket fence or a brick garden wall
				local mine = {}
				for _, g in gaps do if math.min(g[1], g[2]) < z and math.max(g[1], g[2]) > z - h[1] then table.insert(mine, g) end end
				if h.edge == 'picket' then picketFence(d, s * ST.fence, z, z - h[1], -s, mine)
				elseif h.edge == 'wall' then gardenWall(d, s * ST.fence, z, z - h[1], -s, mine)
				else fence(d, s * ST.fence, z, z - h[1], -s, nil, mine) end
				z -= h[1]
			end
		else
			sideRow(d, s, top, { { ST.endZ, function(f, w) brickBuilding(f, w, { bays = 2, ac = { { 'front', lx(s < 0 and 18 or 46), 16.4 } }, tags = { { 'front', lx(28), 9.9, tag[1], tag[2] } } }) end } })
		end
		endBuilding(d, s, zEnd, top - SLEN)
		if not plan then fence(d, s * ST.fence, top, zEnd, -s) end
	end
	-- Paver paths from the sidewalk to each gateway's steps: 3 wide, studded slabs in two stone tones.
	for _, pth in plan and plan.paths or {} do
		local s, x1, zc = math.sign(pth[1]), math.abs(pth[1]), top - pth[2]
		local k = 0
		for x = ST.road + ST.walk, x1 - 0.01, 2 do
			k += 1
			sbox(d, 'Paver', V(s * x, ST.kerb - 0.3, zc - 1.5), V(s * math.min(x + 1.9, x1), ST.kerb + 0.07, zc + 1.5), k % 2 == 0 and P.st.kerbStone or P.st.sill)
		end
	end
	local seed = i * 100
	local function at(x, zp) return V(x, ST.kerb, top - zp) end
	-- Dressing keeps off the paver paths (and their 1.5-stud margins): free(x, z', r) is false where an item of
	-- radius r would stand on one.
	local function free(x, zp, r)
		for _, pth in plan and plan.paths or {} do
			if math.sign(pth[1]) == math.sign(x) and math.abs(x) - r < math.abs(pth[1]) and math.abs(zp - pth[2]) < 1.5 + r + 0.5 then return false end
		end
		return true
	end
	-- Left, near to far: hedge, lamp, the big tree, the far tree, a hedge and the second lamp by the end building.
	if free(-27, 5, 3) then hedge(d, plan and at(-27, 5) or at(-25, 14), plan and 5 or 6) end
	lantern(d, at(-20, 19), V(1, 0, 0))
	tree(d, at(-24.5, 28.5), seed + 1, 1, 38)
	if free(-23.8, 45, 3.2) then tree(d, at(-23.8, 45), seed + 2, 0.85, 20) end
	if free(-23, 51, 2.2) then hedge(d, at(-23, 51), 4) end
	-- (the far lamps stand out at |x| 25.5, clear of the line from the street to GATES' gate pillars)
	lantern(d, at(-25.5, 53.5), V(1, 0, 0))
	-- Right: open grass with a flower, the low hedge, the lamp (with its street sign) and the dumpster behind it.
	if free(25.8, 34, 3.2) then hedge(d, at(25.8, 34), 6) end
	local lamp = lantern(d, at(25.5, 50), V(-1, 0, 0))
	local sign = sbox(lamp, 'StreetSign', V(0.9, 17.4, -2.4), V(1.2, 19.0, -0.2), C(40, 150, 70), true)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do line(surface(sign, face, 30), 'Street', 'HOOD ST', P.white, FONT.title, 0.18, 0.64) end
	if free(31, 50.5, 4.5) then dumpster(d, CFrame.new(at(31, 50.5)))
	elseif free(31, 41, 4.5) then dumpster(d, CFrame.new(at(31, 41))) end
	for k, f in { { 20.6, 17.5 }, { 24, 41 }, { -21, 40 }, { -20, 34 }, { -29.8, 24 }, { 20.8, 62.5 } } do if free(f[1], f[2], 1.2) then flower(d, at(f[1], f[2]), seed + 10 + k) end end
	for k, t in { { -33, 33.5 }, { -31.8, 35 }, { -32.5, 30 }, { 22.8, 38 }, { 21, 50 }, { -18, 57.5 } } do if free(t[1], t[2], 1) then tuft(d, at(t[1], t[2]), seed + 20 + k) end end
	-- The grass in two greens: darker clumps where the picture's grass is shaded or worn.
	for _, g in { { -28, plan and 18 or 10, 3, 5 }, { -30.5, 38, 2.5, 4 }, { -19.5, 44, 2, 3 }, { -31, 22, 2, 3 }, { 28, plan and 18 or 12, 4, 3 }, { 22, plan and 33 or 28, 2.5, 4 }, { 31, plan and 22 or 25, 2, 3 }, { 26.5, 44, 3, 2.5 } } do
		local p = at(g[1], g[2])
		if not free(g[1], g[2], math.max(g[3], g[4]) / 2) then continue end
		decor(sbox(d, 'GrassClump', p + V(-g[3] / 2, -0.2, -g[4] / 2), p + V(g[3] / 2, 0.05, g[4] / 2), P.st.grassDark)).CastShadow = false
	end
	-- Street furniture in the road: a manhole and two kerb drains (dark grates in lighter frames).
	local mh = V(3.6, 0, top - 31)
	decor(sbox(d, 'ManholeRim', mh + V(-1.5, -0.2, -1.5), mh + V(1.5, 0.05, 1.5), P.st.manhole)).CastShadow = false
	decor(sbox(d, 'Manhole', mh + V(-1.1, -0.2, -1.1), mh + V(1.1, 0.08, 1.1), P.st.manhole:Lerp(P.white, 0.12))).CastShadow = false
	for _, dr in { { -1, 15 }, { 1, 42 } } do
		local p = V(dr[1] * (ST.road - 0.65), 0, top - dr[2])
		decor(sbox(d, 'DrainFrame', p + V(-0.55, -0.2, -1.4), p + V(0.55, 0.06, 1.4), P.st.kerbStone:Lerp(P.black, 0.25))).CastShadow = false
		decor(sbox(d, 'DrainGrate', p + V(-0.35, -0.2, -1.15), p + V(0.35, 0.08, 1.15), C(34, 38, 46))).CastShadow = false
	end
	-- Hood prop clusters at the sides, never on the walk: bags and a wheelie bin by the dumpster; a crate with a
	-- boombox on it by the left end building; a hydrant on the right before the gate.
	if free(28.4, 44, 2.5) then trashBags(d, CFrame.new(at(28.4, 44)) * CFrame.Angles(0, 0.4, 0), 3) end
	if free(31.9, 41.4, 1.8) then wheelieBin(d, CFrame.new(at(31.9, 41.4))) end
	crate(d, CFrame.new(at(-19.8, 55)) * CFrame.Angles(0, 0.2, 0), 2.6)
	boombox(d, CFrame.new(at(-19.8, 55) + V(0, 2.6, 0)) * CFrame.Angles(0, math.rad(-70), 0))
	hydrant(d, at(19.6, 54.5))
	-- Right, by the near fence: a bike parked against it and corner-store produce crates on a pallet.
	local bz = plan and 16.5 or 13.5
	if not free(32.4, bz, 2.4) then bz = 30 end
	if free(32.4, bz, 2.4) then bike(d, CFrame.new(at(32.4, bz)) * CFrame.Angles(0, math.pi, 0), ({ C(230, 60, 60), C(60, 140, 240), C(250, 200, 40) })[i % 3 + 1]) end
	if i == 1 then
		-- The porch house: a bench on the porch and pots by its steps; pots on the stoop's cheek walls.
		porchBench(d, CFrame.lookAt(V(38.2, ST.kerb + 1.0, top - 18), V(30, ST.kerb + 1.0, top - 18)))
		for _, zp in { 7.4, 14.6 } do plantPot(d, V(37.2, ST.kerb + 1.0, top - zp), zp) end
		for _, zp in { 8.4, 15.6 } do plantPot(d, V(-36.4, ST.kerb + 3.1, top - zp), zp) end
		-- No. 12's front garden behind its wall: soil beds with flowers either side of the stoop, a clipped bush.
		for k, b in { { 1.5, 7.2 }, { 16.8, 22.5 } } do
			decor(sbox(d, 'FlowerBed', V(-39.9, ST.kerb - 0.2, top - b[1]), V(-37.4, ST.kerb + 0.25, top - b[2]), C(110, 84, 64))).CastShadow = false
			for q = 0, 2 do flower(d, V(-38.6, ST.kerb + 0.2, top - (b[1] + 1 + q * 2)), seed + 40 + k * 3 + q) end
		end
		hedge(d, V(-36.8, ST.kerb, top - 20), 3)
	elseif free(30.8, 20.5, 2.6) then
		storeCrates(d, CFrame.new(at(30.8, 20.5)) * CFrame.Angles(0, 0.1, 0), 3)
	end
	-- Left, by the fence between the trees: a junk corner of a chain-link panel, a tagged board leaning on it and a
	-- pallet with a crate.
	if free(-31, 40, 4) then
		chainLink(d, at(-32.9, 36.6), at(-32.9, 43.4), 7)
		local tag2 = TAGS[(i + 2) % #TAGS + 1]
		graffitiBoard(d, CFrame.lookAt(at(-31.7, 40), at(-31.7, 40) + V(1, 0, 0)), tag2[1], tag2[2])
		pallet(d, CFrame.new(at(-29.6, 42.8)) * CFrame.Angles(0, 0.3, 0))
		crate(d, CFrame.new(at(-29.6, 42.8) + V(0, 0.8, 0)) * CFrame.Angles(0, 0.5, 0), 2.4)
	end
	-- A darker repair patch in the asphalt.
	decor(sbox(d, 'RoadPatch', V(-5.6, -0.2, top - 47), V(-2.2, 0.03, top - 41.5), P.st.roadDark)).CastShadow = false
	-- Stage 1: brick wings between the warehouse wall and the gate line, so its wall is the only way through.
	if i == 1 then
		for _, s in { -1, 1 } do
			-- (out to |x| 40: the set-back houses' yards must not open onto the hall's grass)
			brickBuilding(d:at(CFrame.new(s < 0 and -40 or ST.open, 0, Lobby.N - 1)), 40 - ST.open, { name = 'GateWing', depth = Lobby.N - 1, h = ST.eave + 2, run = 1.5, rise = 1.5, windows = {}, gutters = {} })
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- boss yard
-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end, between the Boss's two pads.
local function bossYard(ctx)
	-- (brief 29, P3b) the Harbor Crew's warehouse (code5/f4_finale: no ring), and the World Boss pier and board
	if V2.Finale then
		local yard = V2.Finale.yard(ctx)
		if V2.feature('WorldBoss') then -- (Oct 27: the World Boss is a later update; Config/Features)
			V2.Finale.arena(ctx)
			V2.Finale.board(ctx)
		end
		return yard
	end
	local b = ctx:group('BossYard')
	b:box('YardSlab', V(-FRONT, 0, BOSS_END), V(FRONT, 0.06, BOSS_TOP - 4), C(176, 178, 184), M.Concrete)
	sideRow(b, -1, BOSS_TOP, {
		{ 56, function(f, w) warehouse(f, w) end },
		{ 40, function(f, w) brickBuilding(f, w, { wall = P.warehouse:Lerp(P.black, 0.1), bays = 2 }) end },
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
	-- (brief 30: no BOSS pad, ring or banner: the last stage's strongest is just a strong enemy; the pad marker stays hidden)
	fightPad(b, 16, V(0, 0, bz), P.padRed, 6, 14, nil, true)
	-- (brief 23) The stage's pads: beat its crew, then cash out here like before every gate (stage 16's Cash).
	GATE.pads(b, 16, 15, bz - 7, 0.06, 5.6, 11)
	for x = -30, 30, 15 do tree(b, V(x, 0, BOSS_END + 4), 600 + x, 1) end
	return b
end

---------------------------------------------------------------------------------------------- the strong enemies' arenas
-- (brief 30, FIGHTS; bible 2.4 "The arena") Where a crew's strongest fights (the even stages: its name on the gate
-- sign), the street gets that crew's set dressing in the reference's layers: mid, clusters of 2-4 themed props hugging
-- the yards, the forecourts and the side street (never on the road or the pads' sidewalks: the middle stays clear);
-- back, a billboard or a water tower on a flat end-building roof over the gate. One theme a crew, nothing random. The
-- props are BoxKit models (Shared/Models/PropModels, hood/tools/blender/models/props.py), given the map kit's studs on
-- their big plastic tops. The generic props a theme replaces are taken out first (Arena.clear).
--   bullies (2)   Big Bully Brock's schoolyard: a school bus on the lawn, its stop arm out; a dodgeball cart; cones
--   crooks (4)    The Ringleader's getaway: the van in the side street, back doors open on money bags; a safe
--   muscle (6)    The Foreman's site: scaffold, cement mixer, barriers and cones across the side street
--   little (8)    Big Shot's alley show: speaker stacks in the service recesses
--   gangsters (10) Furcoat Frankie's corner: the purple lowrider, burning barrels, a card table
--   ballers (12)  Court King's court: ball racks at the sidelines
--   dockhands (14) The Dockmaster's yard edge: drums, bollards, rope coils, cones and tyres
local Arena = {}
Arena.Crews = { [2] = 'bullies', [4] = 'crooks', [6] = 'muscle', [8] = 'little', [10] = 'gangsters', [12] = 'ballers', [14] = 'dockhands' }
Arena.Signs = { -- the crew's sign on the end building's front and its bunting's two colours
	bullies = { 'RECESS RULES', C(255, 196, 32), C(232, 48, 52) }, crooks = { 'CASH 4 GOLD', C(92, 214, 110), C(255, 206, 64) },
	muscle = { 'BUILD IT BIG', C(255, 140, 40), C(250, 204, 40) }, little = { 'BIG SHOT LIVE', C(196, 110, 255), C(70, 220, 255) },
	gangsters = { "FRANKIE'S", C(255, 120, 200), C(150, 70, 220) }, ballers = { 'COURT KINGS', C(255, 150, 40), C(40, 90, 200) },
	dockhands = { 'HARBOR FREIGHT', C(80, 170, 255), C(250, 204, 40) },
}
-- A BoxKit prop at pos (this ctx's frame) turned yaw about Y, anchored; solid: its visible parts collide.
function Arena.prop(c, id, pos, yaw, scale, solid)
	local props = Armory.optional('PropModels')
	local ok, m = false, nil
	if props and props.build then ok, m = pcall(props.build, id, scale or 1) end
	if not ok or not m or not m.PrimaryPart then return nil end
	local delta = c:world(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)) * m.PrimaryPart.CFrame:Inverse()
	for _, p in m:GetDescendants() do
		if p:IsA('BasePart') then
			p.CFrame = delta * p.CFrame
			p.Anchored, p.CanTouch, p.CanQuery = true, false, false
			p.CanCollide = solid == true and p.Transparency < 1
			-- (brief 30, the lead: no stud textures on props until the LOOK agent's recipe lands; smooth toy tops)
			if p:IsA('Part') then p.TopSurface = S.Smooth end
		end
	end
	m.Parent = c.parent
	return m
end
-- The generic props (models named in `names`) standing in a box of the stage (|x| side s from xa to xb, z' za..zb).
function Arena.clear(stage, top, names, s, xa, xb, za, zb)
	for _, m in stage:GetChildren() do
		if m:IsA('Model') and names[m.Name] then
			local p = m:FindFirstChildWhichIsA('BasePart', true)
			if p then
				local q = V2.Origin:PointToObjectSpace(p.CFrame.Position)
				local x, zp = q.X * s, top - q.Z
				if x >= xa and x <= xb and zp >= za and zp <= zb then m:Destroy() end
			end
		end
	end
end
-- The back layer, framing the gate the crew waits at (the end buildings are too tall for anything on their roofs to show
-- from the street): the crew's sign on the left end building's front, lit, and a line of pennant bunting in the crew's
-- two colours strung across the street over the gate's beam.
function Arena.backdrop(d, top, crew)
	local sign = Arena.Signs[crew]
	if not sign then return end
	local ST = P.street
	local zf = top - ST.endZ -- (the end buildings' fronts face back up the street at z' 56)
	local x0 = -(ST.open + (FRONT - ST.open) / 2)
	local frameP = sbox(d, 'CrewSignFrame', V(x0 - 6.6, 13.4, zf + 0.05), V(x0 + 6.6, 18.6, zf + 0.45), C(30, 34, 46))
	local board = sbox(d, 'CrewSign', V(x0 - 6.1, 13.9, zf + 0.45), V(x0 + 6.1, 18.1, zf + 0.6), C(20, 24, 36), true)
	line(surface(board, Enum.NormalId.Back, 24), 'Sign', sign[1], sign[2], FONT.title, 0.14, 0.72, P.black, 4)
	for _, dx in { -4.5, 4.5 } do
		sbox(d, 'CrewSignLampArm', V(x0 + dx - 0.2, 18.6, zf + 0.4), V(x0 + dx + 0.2, 19.0, zf + 1.8), C(46, 50, 60), true)
		decor(d:box('CrewSignLamp', V(x0 + dx - 0.7, 18.3, zf + 1.4), V(x0 + dx + 0.7, 18.6, zf + 2.2), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	local _ = frameP
	-- the bunting: a cord sagging from end building to end building, a pennant every 2 studs
	local zb, half, yTop, sag = zf + 2.2, ST.open - 0.4, 26.2, 2.6
	local function cordY(x) return yTop - sag * (1 - (x / half) ^ 2) end
	local prev = nil
	for x = -half, half + 0.01, half / 6 do
		local p = V(x, cordY(x), zb)
		if prev then decor(d:bar('BuntingCord', prev, p, 0.12, C(40, 40, 46), M.Plastic)).CastShadow = false end
		prev = p
	end
	local k = 0
	for x = -half + 1.2, half - 1.2, 2 do
		k += 1
		local y = cordY(x)
		local flag = d:part('Pennant', V(1.15, 1.15, 0.12), CFrame.new(x, y - 0.55, zb) * CFrame.Angles(0, 0, math.rad(45)), k % 2 == 0 and sign[2] or sign[3], M.SmoothPlastic)
		decor(flag).CastShadow = false
	end
end
local GENERIC = { Hedge = true, TrashBags = true, WheelieBin = true, Dumpster = true, ParkedCar = true }
function Arena.dress(d, i)
	local crew = Arena.Crews[i]
	if not crew then return end
	local stage = d.parent
	local top = stageTop(i)
	local ST = P.street
	local function at(x, zp, y) return V(x, y or ST.kerb, top - zp) end
	local a = d:group('Arena')
	local t = trioOf(i)
	if crew == 'bullies' then
		Arena.clear(stage, top, GENERIC, 1, 19.5, 34.4, 20, 48)
		Arena.prop(a, 'SchoolBus', at(27.4, 35.2), 0, 1, true)
		Arena.prop(a, 'DodgeballCart', at(21.6, 46.6), math.rad(16), 1)
		for k, z in { 27, 30.5, 34 } do Arena.prop(a, 'TrafficCone', at(19.7 + (k % 2) * 0.3, z), k * 0.4, 1) end
		Arena.prop(a, 'DodgeballCart', at(-21.2, 50.8), math.rad(-12), 1)
		Arena.backdrop(a, top, crew)
	elseif crew == 'crooks' or crew == 'muscle' then
		local sa = ({ 28, 30, 27 })[t]
		local sb = sa + 18
		if crew == 'muscle' then Arena.clear(stage, top, GENERIC, 1, 20, 62, sa, sb) end
		if crew == 'crooks' then
			-- (on the left forecourt, nose to the gate, its back doors open toward you as you come down the street; the
			-- car in the side street stays)
			Arena.clear(stage, top, GENERIC, -1, 16.5, 27, 28, 52)
			Arena.prop(a, 'GetawayVan', at(-21.8, 40.2, ST.kerb + 0.08), 0, 1, true)
			Arena.prop(a, 'Safe', at(-19.6, 29.2, ST.kerb + 0.08), math.rad(160), 1, true)
			for k, mb in { { -21.4, 30.4 }, { -23.2, 31.4 }, { -18.9, 31.8 } } do Arena.prop(a, 'MoneyBag', at(mb[1], mb[2], ST.kerb + 1.1), k * 0.7, 1) end
			Arena.prop(a, 'TrafficCone', at(19.4, 49.6, ST.kerb + 0.08), 0.3, 1)
		else
			Arena.prop(a, 'Scaffold', at(33, sb - 2.2, ST.kerb + 0.05), math.pi, 1, true)
			Arena.prop(a, 'CementMixer', at(42.5, sa + 8, ST.kerb + 0.05), 0.7, 1, true)
			for _, bz in { sa + 6, sa + 11 } do Arena.prop(a, 'RoadBarrier', at(20.6, bz, ST.kerb + 0.05), math.pi / 2, 1, true) end
			for k, cz in { sa + 3.6, sb - 3.2, sa + 8.5 } do Arena.prop(a, 'TrafficCone', at(k == 3 and 24.2 or 18.6, cz), k * 0.5, 1) end
			Arena.prop(a, 'PalletStack', at(-22.6, 45.6), 0.12, 1, true)
			Arena.prop(a, 'Crate', at(-21.2, 49.6, ST.kerb + 1.3), 0.4, 1, true)
		end
		Arena.backdrop(a, top, crew)
	elseif crew == 'little' then
		local plan = ({ { 14, 24, 30, 40 }, { 20, 30, 26, 36 }, { 12, 22, 34, 44 } })[t]
		Arena.clear(stage, top, GENERIC, -1, 20, 31, plan[1], plan[2])
		Arena.clear(stage, top, GENERIC, 1, 20, 31, plan[3], plan[4])
		Arena.prop(a, 'SpeakerStack', at(-25.2, (plan[1] + plan[2]) / 2, ST.kerb + 0.08), math.pi / 2, 1, true)
		Arena.prop(a, 'SpeakerStack', at(25.2, (plan[3] + plan[4]) / 2, ST.kerb + 0.08), -math.pi / 2, 1, true)
		-- and the show at the alley's end, a stack each side against the walls, facing the street, where the crew waits
		Arena.clear(stage, top, { WheelieBin = true }, 1, 16, 21, 44, 56)
		Arena.clear(stage, top, { WheelieBin = true }, -1, 16, 21, 44, 56)
		Arena.prop(a, 'SpeakerStack', at(18.4, 50.5, ST.kerb + 0.08), -math.pi / 2, 0.8, true)
		Arena.prop(a, 'SpeakerStack', at(-18.4, 49.0, ST.kerb + 0.08), math.pi / 2, 0.8, true)
		Arena.backdrop(a, top, crew)
	elseif crew == 'gangsters' then
		Arena.prop(a, 'Lowrider', at(-27.6, 41.2), 0, 1, true)
		for _, fb in { { -20.6, 38.4 }, { -20.8, 52.2 }, { 19.8, 41.5 } } do Arena.prop(a, 'FireBarrel', at(fb[1], fb[2], fb[1] > 0 and ST.kerb + 0.08 or nil), fb[2] * 0.1, 1, true) end
		Arena.prop(a, 'CardTable', at(-23.4, 25.4), 0.25, 1, true)
		Arena.backdrop(a, top, crew)
	elseif crew == 'ballers' then
		Arena.prop(a, 'BallRack', at(19.6, 38.6, ST.kerb + 0.08), -math.pi / 2, 1, true)
		Arena.prop(a, 'BallRack', at(-19.8, 31.5), math.pi / 2, 1, true)
		Arena.prop(a, 'TrafficCone', at(19.4, 33.4, ST.kerb + 0.08), 0.4, 1)
		Arena.backdrop(a, top, crew)
	elseif crew == 'dockhands' then
		for k, br in { { -21.2, 46.6 }, { -22.8, 48.4 }, { -20.8, 49.8 } } do Arena.prop(a, 'Barrel', at(br[1], br[2], ST.kerb + 0.08 + 1.5), k * 0.8, 1, true) end
		Arena.prop(a, 'RopeCoil', at(-24.6, 51.6, ST.kerb + 0.08), 0.6, 1)
		for _, bz in { 42.6, 53.8 } do Arena.prop(a, 'Bollard', at(-19.6, bz, ST.kerb + 0.08), 0, 1, true) end
		for k, cz in { 45.6, 48.8 } do Arena.prop(a, 'TrafficCone', at(19.8 + k * 0.3, cz, ST.kerb + 0.08), k, 1) end
		Arena.prop(a, 'TireStack', at(21.2, 53.2, ST.kerb + 0.08), 0.3, 1)
		Arena.backdrop(a, top, crew)
	end
end

local function buildStages(ctx)
	local byLook = { streetStage, District.corner, District.alley, District.courts, District.yards }
	for i = 1, STAGES do
		local d = (byLook[lookOf(i)] or streetStage)(ctx, i)
		if d then Arena.dress(d, i) end -- (brief 30: the strong enemies' arenas)
	end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do stageGate(gates, i) end
	bossYard(ctx)
end
---------------------------------------------------------------------------------------------- stage crews' hangouts
-- Brief 18: every stage holds a crew of cartoon rival goons (Shared/EnemyRules: who and where; each player's client draws
-- its own goons, Shared/GoonRig, and the server runs them, WaveService). The map only dresses the spot each crew hangs out
-- at, so the street reads as their turf: a milk crate with a boombox on it (two speaker cones, a cassette deck, a
-- stripe in the crew's colour), a second crate to sit on, a few soda cans, and a paint splat in the crew's colour on
-- the sidewalk. Nothing here blocks the street: everything stands on the sidewalk beside the crew (|x| 10..16) or on
-- the court, behind the goons' line. (brief 30: the warehouse has no armchair: its strongest is just a strong enemy.)
-- (The old cartoon target waves are gone; HoodClient/Waves hides any a map built before brief 18 still carries.)
local Waves = {}
Waves.Ground = 0.6 -- the sidewalk top (P.street.kerb)
Waves.Crew = {
	Red = C(222, 58, 58), Green = C(64, 182, 96), Purple = C(140, 76, 214), Orange = C(255, 146, 44), Yellow = C(255, 214, 56), Boss = C(255, 202, 64),
}
Waves.Wood = { lit = C(232, 196, 140), dark = C(136, 86, 48) }

-- Parts: a cylinder lying along the frame's Z (a disc facing -Z), an upright cylinder standing on a point.
function Waves.disc(c, name, r, thick, centre, color, material)
	return decor(c:part(name, V(thick, 2 * r, 2 * r), CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.can(c, name, r, h, foot, color, material)
	return decor(c:part(name, V(h, 2 * r, 2 * r), CFrame.new(foot + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.trim(c, name, a, b, color) return decor(c:box(name, a, b, color, M.SmoothPlastic)) end

-- A blue milk crate (slots on its sides, a darker rim), from y0, its footprint centred on the frame's origin.
function Waves.crate(c, y0, color)
	local blue = color or C(52, 98, 204)
	local rim = blue:Lerp(C(0, 0, 0), 0.3)
	local h = 1.5
	sbox(c, 'MilkCrate', V(-1.3, y0, -1.0), V(1.3, y0 + h, 1.0), blue)
	Waves.trim(c, 'MilkCrateRim', V(-1.36, y0 + h - 0.25, -1.06), V(1.36, y0 + h, 1.06), rim)
	for _, x in { -0.75, 0, 0.75 } do
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, -1.04), V(x + 0.24, y0 + 0.95, -1.0), rim:Lerp(C(0, 0, 0), 0.3))
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, 1.0), V(x + 0.24, y0 + 0.95, 1.04), rim:Lerp(C(0, 0, 0), 0.3))
	end
	return y0 + h
end

-- A big boombox (front -Z): charcoal case, a lighter face plate, two speaker cones in chrome rims, a cassette deck,
-- four coloured buttons, a chrome carry handle and a stripe in the crew's colour.
function Waves.boombox(c, y0, stripe)
	local y1 = y0 + 2.5
	decor(c:box('Case', V(-2.1, y0, -0.5), V(2.1, y1, 0.55), C(50, 52, 62), M.SmoothPlastic))
	Waves.trim(c, 'FacePlate', V(-1.98, y0 + 0.12, -0.58), V(1.98, y1 - 0.12, -0.5), C(74, 78, 92))
	Waves.trim(c, 'Stripe', V(-2.12, y0 + 0.18, -0.6), V(2.12, y0 + 0.42, 0.57), stripe)
	local cy = (y0 + y1) / 2 + 0.1
	for _, x in { -1.18, 1.18 } do
		Waves.disc(c, 'SpeakerRim', 0.98, 0.1, V(x, cy, -0.6), C(204, 208, 218))
		Waves.disc(c, 'Grille', 0.86, 0.1, V(x, cy, -0.63), C(34, 36, 44))
		Waves.disc(c, 'Cone', 0.5, 0.1, V(x, cy, -0.67), C(70, 72, 84))
		Waves.disc(c, 'DustCap', 0.2, 0.1, V(x, cy, -0.71), C(150, 154, 166))
	end
	Waves.trim(c, 'Deck', V(-0.5, cy - 0.05, -0.62), V(0.5, cy + 0.6, -0.56), C(30, 32, 40))
	Waves.trim(c, 'Cassette', V(-0.36, cy + 0.08, -0.66), V(0.36, cy + 0.46, -0.6), C(222, 222, 228))
	for k, col in { C(236, 64, 64), C(250, 206, 56), C(70, 200, 100), C(70, 140, 240) } do
		local x = -0.6 + (k - 1) * 0.4
		Waves.trim(c, 'Button', V(x - 0.13, y1, -0.35), V(x + 0.13, y1 + 0.16, -0.05), col)
	end
	local chrome = C(204, 208, 218)
	for _, x in { -1.4, 1.4 } do Waves.trim(c, 'HandlePost', V(x - 0.14, y1, -0.12), V(x + 0.14, y1 + 0.62, 0.16), chrome) end
	Waves.trim(c, 'Handle', V(-1.54, y1 + 0.5, -0.14), V(1.54, y1 + 0.78, 0.18), chrome)
end

-- A paint splat on the ground in the crew's colour (three overlapping blobs and two drips, a white rim), lying flat.
function Waves.splat(c, y, color)
	local rim = C(250, 250, 252)
	local blobs = { { 0, 0, 2.2 }, { 1.1, 0.6, 1.4 }, { -0.9, -0.7, 1.2 } }
	for k, b in blobs do
		decor(c:part('SplatRim', V(0.04, b[3] + 0.3, b[3] + 0.3), CFrame.new(b[1], y + 0.02, b[2]) * CFrame.Angles(0, 0, math.pi / 2), rim, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		decor(c:part('Splat', V(0.05, b[3], b[3]), CFrame.new(b[1], y + 0.03 + k * 0.001, b[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
	for _, d in { { 1.9, 1.3, 0.5 }, { -1.8, 0.9, 0.4 } } do
		decor(c:part('Drip', V(0.05, d[3], d[3]), CFrame.new(d[1], y + 0.03, d[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- One crew's hangout, at the frame `cf` (on the sidewalk; its -Z faces the street): the boombox on its crate, a crate to
-- sit on beside it, three soda cans, the splat in front.
function Waves.hangout(c, cf, crew)
	local h = c:at(cf)
	local color = Waves.Crew[crew] or Waves.Crew.Red
	local top = Waves.crate(h, Waves.Ground)
	Waves.boombox(h, top, color)
	local seat = h:at(CFrame.new(3.4, 0, 0.4) * CFrame.Angles(0, math.rad(12), 0))
	Waves.crate(seat, Waves.Ground, C(236, 120, 40))
	for k, col in { C(226, 54, 60), C(62, 188, 98), C(52, 118, 226) } do
		Waves.can(h, 'SodaCan', 0.24, 0.62, V(-2.0 + k * 0.42, Waves.Ground, -1.4 + (k % 2) * 0.3), col)
	end
	Waves.splat(h:at(CFrame.new(-3.4, 0, -0.3)), Waves.Ground, color)
end

-- The boss's armchair (front -Z): big red cushions, gold trim, on four stubby gold feet.
function Waves.throne(c, cf)
	local t = c:at(cf)
	local red, deep, gold = C(208, 40, 52), C(150, 24, 36), C(255, 202, 64)
	local y = 0.06
	for _, x in { -2.6, 2.6 } do for _, z in { -1.8, 1.8 } do sbox(t, 'Foot', V(x - 0.3, y, z - 0.3), V(x + 0.3, y + 0.6, z + 0.3), gold) end end
	sbox(t, 'Seat', V(-3, y + 0.6, -2.2), V(3, y + 2.2, 2.2), red)
	Waves.trim(t, 'SeatPiping', V(-3.05, y + 2.0, -2.25), V(3.05, y + 2.25, 2.25), gold)
	sbox(t, 'Back', V(-3, y + 2.2, 1.2), V(3, y + 7.2, 2.2), deep)
	Waves.trim(t, 'BackPiping', V(-3.05, y + 7.0, 1.15), V(3.05, y + 7.4, 2.25), gold)
	for _, x in { -3, 2.2 } do
		sbox(t, 'Arm', V(x, y + 2.2, -2.2), V(x + 0.8, y + 4.0, 1.2), red)
		Waves.trim(t, 'ArmPiping', V(x - 0.05, y + 3.85, -2.25), V(x + 0.85, y + 4.1, 1.25), gold)
	end
	Waves.trim(t, 'Cushion', V(-2.2, y + 2.2, -2.0), V(2.2, y + 2.7, 1.2), C(236, 70, 82))
	-- a gold crown badge on the backrest
	Waves.trim(t, 'CrownBase', V(-0.9, y + 5.2, 1.12), V(0.9, y + 5.6, 1.2), gold)
	for _, x in { -0.75, 0, 0.75 } do Waves.trim(t, 'CrownPoint', V(x - 0.18, y + 5.6, 1.12), V(x + 0.18, y + 6.3, 1.2), gold) end
end

-- Where each stage's hangout goes: on the sidewalk of the side most of the crew stands toward, a few steps in front of
-- the nearest of them (clear of the next gate's pads, which fill the sidewalks from z' ~48), or on the court where the
-- Courts' crews hang out.
function Waves.spotFor(spots, stage)
	local sx, near = 0, math.huge
	for _, s in spots do sx += s[1]; near = math.min(near, s[2]) end
	sx = sx / #spots
	if stage >= 10 and stage <= 12 then return 33, near - 5, 1 end -- (on the court, by the two there)
	local side = sx >= 0 and 1 or -1
	if stage >= 7 and stage <= 9 then return side * 12.9, near - 7, side end -- (the Alley: tight against the wall)
	return side * 12.8, near - 7, side
end

function Waves.build(ctx)
	-- (Optional: a place or src without Shared.EnemyRules builds without the hangouts instead of stopping the build.)
	local module = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('EnemyRules')
	local ok, rules = false, nil
	if module then ok, rules = pcall(require, module) end
	if not ok or type(rules) ~= 'table' then
		warn('[TheBlockV2] No Shared.EnemyRules: crew hangouts skipped')
		return nil
	end
	Waves.Rules = rules
	local all = ctx:group('Waves')
	for stage = 1, STAGES do
		local spots = rules.Spots[stage]
		if spots then
			local g = all:group('Hangout' .. stage)
			local x, zp, side = Waves.spotFor(spots, stage)
			local top = stageTop(stage)
			-- turned to face across the street (toward the crew), a few degrees off square
			local yaw = (side > 0 and math.pi / 2 or -math.pi / 2) + math.rad((stage * 7) % 9 - 4)
			Waves.hangout(g, CFrame.new(x, 0, top - zp) * CFrame.Angles(0, yaw, 0), rules.Crews[stage])
		end
	end
	return all
end
V2.Waves = Waves -- (the unit tests and integ_waves read it)
---------------------------------------------------------------------------------------------- the districts' props (World 2)
-- (Oct 27, the owner's districts mockup, docs/refs/world2/owner_world2_districts_oct27.png: "don't make it exactly like
-- this ... make the models look more low poly/cartoony") Five districts, three stages each, every prop our own chunky
-- blocks in clean saturated colours (no copies of the mockup's models):
--   City Streets (1-3)       black lanterns, trees in planters, red brick and grey towers
--   Modern Plaza (4-6)       glass towers, light plaza tiles, fountains, planters
--   Construction Zone (7-9)  sand ground, red steel frames with yellow scaffolds, yellow tower cranes, barriers, cones,
--                            sand piles, brick pallets
--   Transit Area (10-12)     an elevated train line on concrete piers over the left side, a station with an escalator,
--                            a train (the street court stays on the right: EnemyRules.Courts has the crew there)
--   Luxury District (13-15)  dark glass towers with pink neon edges, palms, pink lines along the run, a fountain, the red
--                            BOSS gateway before gate 16 (the CEO tower and its rooftop beyond)
-- City.avenueStage (f5_avenue) calls these by district.

City.D = {
	lantern = C(44, 48, 62), lanternGlow = C(255, 214, 120),
	brick = { C(198, 88, 68), C(182, 76, 60), C(208, 104, 80) }, grey = { C(150, 156, 172), C(132, 140, 160), C(168, 172, 186) },
	plazaTile = C(222, 228, 238), water = C(84, 196, 250), waterTop = C(170, 232, 255), fountainStone = C(236, 238, 244),
	sand = C(238, 204, 128), sandDark = C(214, 176, 100), red = C(214, 62, 52), redDark = C(176, 46, 40),
	yellow = C(252, 198, 40), yellowDark = C(214, 160, 24), concrete = C(178, 182, 194), concreteLight = C(204, 208, 218),
	white = C(244, 246, 250), trainBlue = C(40, 110, 220), trainRed = C(226, 54, 60), window = C(46, 70, 108),
	pink = C(255, 70, 190), pinkSoft = C(244, 132, 206), luxGlass = C(70, 92, 176), luxPlanter = C(64, 60, 92),
	trunk = C(196, 150, 96), trunkDark = C(170, 124, 76), frond = C(70, 190, 76), frondDark = C(48, 150, 62),
}

---------------------------------------------------------------------------------------------- City Streets
-- A black street lantern (pos: its foot on the ground): a stepped foot, a slim post, a warm glowing lamp box under a cap.
function City.lantern(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('Lantern')
	sbox(g, 'LanternFoot', V(-0.9, 0, -0.9), V(0.9, 1, 0.9), K.lantern)
	g:box('LanternPost', V(-0.35, 1, -0.35), V(0.35, 9, 0.35), K.lantern, M.SmoothPlastic)
	g:box('LanternCollar', V(-0.7, 9, -0.7), V(0.7, 9.5, 0.7), K.lantern, M.SmoothPlastic)
	decor(g:box('LanternGlow', V(-0.8, 9.5, -0.8), V(0.8, 11.3, 0.8), K.lanternGlow, M.Neon)).CastShadow = false
	g:box('LanternCap', V(-1.1, 11.3, -1.1), V(1.1, 11.9, 1.1), K.lantern, M.SmoothPlastic)
	g:box('LanternTop', V(-0.4, 11.9, -0.4), V(0.4, 12.6, 0.4), K.lantern, M.SmoothPlastic)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'LanternFoot' and p.Name ~= 'LanternPost' then decor(p) end end
	return g
end

---------------------------------------------------------------------------------------------- Modern Plaza
-- A square stepped fountain (pos: its centre on the ground): a stone basin with a rim and water in it, a pedestal with
-- a second bowl, a water column with a bright cap. rim: the rim's colour (the luxury one is pink).
function City.fountain(c, pos, rim, r)
	local K = City.D
	r = r or 5
	local g = c:at(CFrame.new(pos)):group('Fountain')
	sbox(g, 'FountainBasin', V(-r, 0, -r), V(r, 1.0, r), K.fountainStone)
	decor(g:box('FountainWater', V(-r + 0.7, 1.0, -r + 0.7), V(r - 0.7, 1.4, r - 0.7), K.water, M.SmoothPlastic)).CastShadow = false
	for _, e in { { -r, -r, r, -r + 0.7 }, { -r, r - 0.7, r, r }, { -r, -r + 0.7, -r + 0.7, r - 0.7 }, { r - 0.7, -r + 0.7, r, r - 0.7 } } do
		sbox(g, 'FountainRim', V(e[1], 1.0, e[2]), V(e[3], 1.9, e[4]), rim or K.fountainStone)
	end
	sbox(g, 'FountainPedestal', V(-1.1, 1.4, -1.1), V(1.1, 4.2, 1.1), K.fountainStone)
	sbox(g, 'FountainBowl', V(-2.6, 4.2, -2.6), V(2.6, 4.9, 2.6), rim or K.fountainStone)
	decor(g:box('FountainWater', V(-2.1, 4.9, -2.1), V(2.1, 5.1, 2.1), K.water, M.SmoothPlastic)).CastShadow = false
	local col = decor(g:box('FountainJet', V(-0.45, 5.1, -0.45), V(0.45, 8.2, 0.45), K.waterTop, M.SmoothPlastic))
	col.CastShadow, col.Transparency = false, 0.2
	local cap = decor(g:box('FountainSpray', V(-1.0, 8.2, -1.0), V(1.0, 8.8, 1.0), K.waterTop, M.SmoothPlastic))
	cap.CastShadow, cap.Transparency = false, 0.25
	return g
end

---------------------------------------------------------------------------------------------- Construction Zone
-- A building going up over x0..x1, z0..z1 (this frame), h high: a concrete pad, red steel columns on a grid (some a storey
-- short: still going up), beams round and across every storey, concrete floors on the lower third, a yellow scaffold up
-- the face toward the street (face: 'W' at x0 or 'E' at x1).
function City.steelFrame(c, x0, x1, z0, z1, h, face, seed)
	local K = City.D
	local g = c:group('SteelFrame')
	local r = Random.new(seed or 1)
	sbox(g, 'FramePad', V(x0, -1, z0), V(x1, 1.2, z1), K.concrete)
	local st = 6
	local top = math.max(2, math.floor((h - 1.2) / st)) * st + 1.2
	local nx, nz = math.max(2, math.floor((x1 - x0) / 7 + 0.5)), math.max(2, math.floor((z1 - z0) / 7 + 0.5))
	local xs, zs = {}, {}
	for i = 0, nx do table.insert(xs, x0 + 1 + (x1 - x0 - 2) * i / nx) end
	for j = 0, nz do table.insert(zs, z0 + 1 + (z1 - z0 - 2) * j / nz) end
	local reach = {}
	for i, x in xs do
		reach[i] = {}
		for j, z in zs do
			local edge = i == 1 or i == #xs or j == 1 or j == #zs
			local t = top - ((not edge or r:NextNumber() < 0.35) and r:NextInteger(0, 1) * st or 0)
			reach[i][j] = t
			g:box('FrameColumn', V(x - 0.6, 1.2, z - 0.6), V(x + 0.6, t, z + 0.6), K.red, M.SmoothPlastic)
		end
	end
	for y = 1.2 + st, top, st do
		for j, z in zs do
			for i = 1, #xs - 1 do
				if reach[i][j] >= y and reach[i + 1][j] >= y then g:box('FrameBeam', V(xs[i], y - 0.9, z - 0.45), V(xs[i + 1], y, z + 0.45), K.redDark, M.SmoothPlastic) end
			end
		end
		for i, x in xs do
			for j = 1, #zs - 1 do
				if reach[i][j] >= y and reach[i][j + 1] >= y then g:box('FrameBeam', V(x - 0.45, y - 0.9, zs[j]), V(x + 0.45, y, zs[j + 1]), K.redDark, M.SmoothPlastic) end
			end
		end
		if y <= 1.2 + (top - 1.2) / 3 + 0.1 then
			sbox(g, 'FrameFloor', V(xs[1] - 0.6, y - 0.9, zs[1] - 0.6), V(xs[#xs] + 0.6, y - 0.3, zs[#zs] + 0.6), K.concreteLight)
		end
	end
	-- the scaffold: yellow standards every ~4 studs, a plank deck and a rail every storey, two storeys up the face
	local fx = face == 'W' and x0 - 2.2 or x1 + 2.2
	local sh = math.min(top, 1.2 + st * 3)
	for z = z0 + 1, z1 - 1, 4 do
		for _, dx in { -0.9, 0.9 } do decor(g:box('ScaffoldPole', V(fx + dx - 0.2, 1.2, z - 0.2), V(fx + dx + 0.2, sh + 2, z + 0.2), K.yellow, M.SmoothPlastic)) end
	end
	for y = 1.2 + st, sh, st do
		decor(sbox(g, 'ScaffoldDeck', V(fx - 1.2, y - 0.4, z0 + 0.6), V(fx + 1.2, y, z1 - 0.6), C(196, 150, 96)))
		decor(g:box('ScaffoldRail', V(fx + (face == 'W' and -1.3 or 1.1), y + 1.6, z0 + 0.6), V(fx + (face == 'W' and -1.1 or 1.3), y + 1.9, z1 - 0.6), K.yellowDark, M.SmoothPlastic))
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = p.Name == 'FramePad' or p.Name == 'FrameColumn' or p.Name == 'FrameFloor' end end
	return g
end

-- A yellow tower crane: a lattice mast at (x, z) on a concrete foot, the cab and the slewing ring on top, a long jib
-- toward dir (+1 / -1 in x) with its trolley, the cable and a red beam hanging from it, the short counter-jib behind with
-- its concrete weights, the ties from the peak.
function City.crane(c, x, z, h, dir, len)
	local K = City.D
	local g = c:at(CFrame.new(x, 0, z)):group('TowerCrane')
	len = len or 30
	local a = 1.6 -- the mast's half width
	sbox(g, 'CraneFoot', V(-3, -1, -3), V(3, 1.4, 3), K.concrete)
	for _, q in { { -a, -a }, { a, -a }, { -a, a }, { a, a } } do
		g:box('CraneMast', V(q[1] - 0.3, 1.4, q[2] - 0.3), V(q[1] + 0.3, h, q[2] + 0.3), K.yellow, M.SmoothPlastic)
	end
	for y = 4, h - 1, 3.5 do
		for _, s in { -1, 1 } do
			decor(g:box('CraneRung', V(-a, y - 0.15, s * a - 0.15), V(a, y + 0.15, s * a + 0.15), K.yellowDark, M.SmoothPlastic))
			decor(g:box('CraneRung', V(s * a - 0.15, y - 0.15, -a), V(s * a + 0.15, y + 0.15, a), K.yellowDark, M.SmoothPlastic))
		end
		-- one diagonal per face, alternating (the lattice's zigzag)
		local lean = math.atan2(2 * a, 3.5) * ((math.floor(y / 3.5) % 2 == 0) and 1 or -1)
		local dl = math.sqrt(3.5 ^ 2 + (2 * a) ^ 2)
		for _, s in { -1, 1 } do
			decor(g:part('CraneBrace', V(0.25, dl, 0.25), CFrame.new(0, y + 1.75, s * a) * CFrame.Angles(0, 0, lean), K.yellowDark, M.SmoothPlastic))
			decor(g:part('CraneBrace', V(0.25, dl, 0.25), CFrame.new(s * a, y + 1.75, 0) * CFrame.Angles(lean, 0, 0), K.yellowDark, M.SmoothPlastic))
		end
	end
	g:box('CraneRing', V(-2.2, h, -2.2), V(2.2, h + 1, 2.2), K.lantern, M.SmoothPlastic)
	g:box('CraneCab', V(-dir * 0.2 - (dir > 0 and 0 or 3.4), h + 1, 1.0), V(-dir * 0.2 + (dir > 0 and 3.4 or 0), h + 4, 3.6), K.yellow, M.SmoothPlastic)
	decor(g:box('CraneCabGlass', V(math.min(dir * 3.2, dir * 3.5), h + 2.2, 1.2), V(math.max(dir * 3.2, dir * 3.5), h + 3.6, 3.4), K.window, M.SmoothPlastic))
	-- the jib (two bottom chords and a top chord, rungs between) and the counter-jib
	local function chord(name, u0, u1, y, zz, w)
		local lo, hi = math.min(u0, u1), math.max(u0, u1)
		return g:box(name, V(lo, y - w, zz - w), V(hi, y + w, zz + w), K.yellow, M.SmoothPlastic)
	end
	local yb = h + 1.4
	for _, zz in { -1.1, 1.1 } do chord('CraneJib', -dir * 10, dir * len, yb, zz, 0.25) end
	chord('CraneJib', -dir * 10, dir * len, yb + 2.4, 0, 0.25)
	for u = -8, len, 3 do
		decor(g:box('CraneJibRung', V(dir * u - 0.15, yb - 0.2, -1.1), V(dir * u + 0.15, yb + 0.2, 1.1), K.yellowDark, M.SmoothPlastic))
		for _, zz in { -1.1, 1.1 } do
			decor(g:part('CraneJibBrace', V(0.2, 2.6, 0.2), CFrame.new(dir * u, yb + 1.2, zz / 2) * CFrame.Angles(math.atan2(-zz, 2.4), 0, 0), K.yellowDark, M.SmoothPlastic))
		end
	end
	sbox(g, 'CraneWeight', V(math.min(-dir * 10, -dir * 6), yb - 3.4, -1.6), V(math.max(-dir * 10, -dir * 6), yb - 0.3, 1.6), K.concrete)
	g:box('CranePeak', V(-0.6, h + 1, -0.6), V(0.6, h + 9, 0.6), K.yellow, M.SmoothPlastic)
	local peak = V(0, h + 9, 0)
	for _, tip in { V(dir * len * 0.7, yb + 2.4, 0), V(-dir * 9, yb + 2.4, 0) } do
		local m = (peak + tip) / 2
		decor(g:part('CraneTie', V(0.15, 0.15, (tip - peak).Magnitude), CFrame.lookAt(m, tip), K.lantern, M.SmoothPlastic))
	end
	-- the trolley, the cable, the hook and its load (a red beam)
	local tx = dir * len * 0.62
	decor(g:box('CraneTrolley', V(tx - 1.2, yb - 0.9, -1.2), V(tx + 1.2, yb - 0.25, 1.2), K.lantern, M.SmoothPlastic))
	local hy = math.max(24, h * 0.45)
	decor(g:box('CraneCable', V(tx - 0.08, hy + 1.2, -0.08), V(tx + 0.08, yb - 0.9, 0.08), K.lantern, M.SmoothPlastic))
	decor(g:box('CraneHook', V(tx - 0.6, hy, -0.6), V(tx + 0.6, hy + 1.2, 0.6), K.yellow, M.SmoothPlastic))
	decor(g:box('CraneLoad', V(tx - 0.7, hy - 1.6, -5), V(tx + 0.7, hy - 0.2, 5), K.red, M.SmoothPlastic))
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = p.Name == 'CraneMast' or p.Name == 'CraneFoot' end end
	return g
end

-- Site props (cf / pos on the ground): a red-and-white jersey barrier, a sand pile, a pallet of bricks.
function City.barrier(c, cf)
	local g = c:at(cf):group('Barrier')
	for k = 0, 2 do sbox(g, 'BarrierBlock', V(-3 + k * 2, 0, -0.6), V(-1 + k * 2, 2.2, 0.6), k % 2 == 0 and City.D.red or City.D.white) end
	sbox(g, 'BarrierFoot', V(-3.1, 0, -0.9), V(3.1, 0.6, 0.9), City.D.concrete)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end
function City.sandPile(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('SandPile')
	sbox(g, 'Sand', V(-3.2, 0, -2.6), V(3.2, 1.2, 2.6), K.sandDark)
	sbox(g, 'Sand', V(-2.2, 1.2, -1.8), V(2.2, 2.2, 1.8), K.sand)
	sbox(g, 'Sand', V(-1.1, 2.2, -0.9), V(1.1, 2.9, 0.9), K.sand)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end
function City.bricks(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('BrickPallet')
	sbox(g, 'Pallet', V(-2, 0, -1.6), V(2, 0.5, 1.6), C(176, 128, 82))
	for k = 0, 5 do
		local cx, cz, cy = -1.1 + (k % 2) * 2.2, k < 4 and -0.8 or 0.8, k < 4 and 0.5 or 1.5
		if k >= 2 and k < 4 then cz = 0.8 end
		sbox(g, 'BrickStack', V(cx - 0.9, cy, cz - 0.7), V(cx + 0.9, cy + 1.0, cz + 0.7), k % 3 == 0 and K.brick[2] or K.brick[1])
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end

---------------------------------------------------------------------------------------------- Transit Area
-- The elevated line over the left side (x xa..xb, z' za..zb of a stage, its deck top at y): a concrete deck with kerbs
-- and two rails, hammerhead piers at the given z'.
City.Rail = { xa = -35, xb = -23, y = 24.2, piers = { 26, 46 } }
function City.viaduct(d, top, za, zb, ends)
	local K, R = City.D, City.Rail
	local g = d:group('Viaduct')
	local xa, xb, y = R.xa, R.xb, R.y
	sbox(g, 'ViaductDeck', V(xa, y - 2.2, top - zb), V(xb, y, top - za), K.concrete)
	decor(g:box('ViaductSkirt', V(xa - 0.2, y - 2.6, top - zb), V(xb + 0.2, y - 2.2, top - za), K.trainBlue, M.SmoothPlastic)).CastShadow = false
	for _, x in { xa, xb - 0.7 } do sbox(g, 'ViaductKerb', V(x, y, top - zb), V(x + 0.7, y + 1.2, top - za), K.concreteLight) end
	local mid = (xa + xb) / 2
	for _, x in { mid - 1.6, mid + 1.6 } do decor(g:box('Rail', V(x - 0.2, y, top - zb), V(x + 0.2, y + 0.4, top - za), City.steel, M.SmoothPlastic)) end
	for _, zp in R.piers do
		sbox(g, 'PierFoot', V(mid - 2.6, -0.5, top - zp - 2.6), V(mid + 2.6, P.street.kerb + 1, top - zp + 2.6), K.concrete)
		sbox(g, 'Pier', V(mid - 2, P.street.kerb + 1, top - zp - 2), V(mid + 2, y - 4.2, top - zp + 2), K.concreteLight)
		sbox(g, 'PierHead', V(xa + 1, y - 4.2, top - zp - 2.4), V(xb - 1, y - 2.2, top - zp + 2.4), K.concrete)
	end
	for _, e in ends or {} do
		sbox(g, 'RailBuffer', V(mid - 2.4, y, top - e - 0.8), V(mid + 2.4, y + 1.6, top - e + 0.8), K.trainRed)
	end
	return g
end
-- A train of n cars on the line, its nose at z' zp heading -Z (up the track): white bodies with a blue band and a red
-- stripe, a dark window band, a grey roof, dark bogies; the lead car's nose sloped.
function City.train(d, top, zp, n)
	local K, R = City.D, City.Rail
	local g = d:group('Train')
	local x, y = (R.xa + R.xb) / 2, R.y + 0.4
	local cl, gap = 15, 0.8
	for k = 0, n - 1 do
		local z0 = top - zp + k * (cl + gap)
		local z1 = z0 + cl
		local function B(name, a0, ya, a1, yb2, za, zb, col, isDecor)
			local p = g:box(name, V(x + a0, y + ya, za), V(x + a1, y + yb2, zb), col, M.SmoothPlastic)
			if isDecor then decor(p).CastShadow = false end
			return p
		end
		B('TrainBogie', -1.6, 0, 1.6, 0.9, z0 + 1.5, z1 - 1.5, K.lantern)
		B('TrainBody', -2.1, 0.9, 2.1, 5.6, z0, z1, K.white)
		B('TrainBand', -2.2, 1.5, 2.2, 2.5, z0 + 0.2, z1 - 0.2, K.trainBlue, true)
		B('TrainStripe', -2.2, 2.5, 2.2, 2.85, z0 + 0.2, z1 - 0.2, K.trainRed, true)
		B('TrainWindows', -2.2, 3.2, 2.2, 4.7, z0 + 1, z1 - 1, K.window, true)
		B('TrainRoof', -1.8, 5.6, 1.8, 6.1, z0 + 0.5, z1 - 0.5, K.concreteLight, true)
		if k == 0 then
			-- the nose: a wedge sloping down to the front, its windscreen dark
			g:wedge('TrainNose', V(4.2, 3.1, 3), CFrame.new(x, y + 4.15, z0 - 1.5), K.white, M.SmoothPlastic)
			B('TrainNoseBase', -2.1, 0.9, 2.1, 2.6, z0 - 3, z0, K.white)
			B('TrainNoseBand', -2.2, 1.5, 2.2, 2.5, z0 - 3, z0, K.trainBlue, true)
		end
	end
	return g
end
-- The station on the line (z' za..zb): a blue canopy on posts over the deck with a METRO sign toward the street, and an
-- escalator up from the paved strip (x -22.6..-18.6, z' zLow on the ground to zHigh at the deck).
function City.station(d, top, za, zb, zHigh, zLow)
	local K, R = City.D, City.Rail
	local g = d:group('Station')
	local y = R.y
	for zp = za, zb, 8 do
		for _, x in { R.xa + 0.35, R.xb - 0.35 } do g:box('CanopyPost', V(x - 0.3, y + 1.2, top - zp - 0.3), V(x + 0.3, y + 6.4, top - zp + 0.3), City.steel, M.SmoothPlastic) end
	end
	sbox(g, 'Canopy', V(R.xa - 0.8, y + 6.4, top - zb - 1), V(R.xb + 0.8, y + 7.2, top - za + 1), K.trainBlue)
	local sign = g:box('StationSign', V(R.xb + 0.8, y + 5.2, top - (za + zb) / 2 - 7), V(R.xb + 1.1, y + 7.2, top - (za + zb) / 2 + 7), K.white, M.SmoothPlastic)
	decor(sign).CastShadow = false
	line(surface(sign, Enum.NormalId.Right, 12), 'Metro', 'METRO', K.trainBlue, FONT.title, 0.06, 0.88, P.white, 2)
	-- the escalator: a solid grey body under the slope, a dark step band on it, blue glass sides with black rails, a
	-- landing onto the deck
	local x0, x1 = R.xb + 0.4, R.xb + 4.4
	local y0 = P.street.kerb
	local run, rise = zLow - zHigh, y - y0
	local zl, zh = top - zLow, top - zHigh
	g:wedge('Escalator', V(x1 - x0, rise, run), CFrame.new((x0 + x1) / 2, y0 + rise / 2, (zl + zh) / 2), K.concrete, M.SmoothPlastic)
	local a, b = V(0, y0, zl), V(0, y, zh)
	local len = (b - a).Magnitude
	local up = CFrame.lookAt((a + b) / 2, b)
	decor(g:part('EscalatorSteps', V(x1 - x0 - 1.2, 0.2, len), CFrame.new((x0 + x1) / 2, 0, 0) * up * CFrame.new(0, 0.1, 0), K.lantern, M.SmoothPlastic)).CastShadow = false
	for _, x in { x0 + 0.25, x1 - 0.25 } do
		local side = g:part('EscalatorSide', V(0.3, 2.4, len), CFrame.new(x, 0, 0) * up * CFrame.new(0, 1.3, 0), K.water, M.Glass)
		side.Transparency, side.CastShadow = 0.35, false
		decor(g:part('EscalatorRail', V(0.5, 0.4, len), CFrame.new(x, 0, 0) * up * CFrame.new(0, 2.6, 0), K.lantern, M.SmoothPlastic)).CastShadow = false
	end
	sbox(g, 'EscalatorLanding', V(R.xb - 0.2, y - 2.2, zh), V(x1, y, zh + 4), K.concrete)
	return g
end

---------------------------------------------------------------------------------------------- Luxury District
-- A palm (pos: its foot): a trunk of six chunky segments leaning a little, two tones, a crown of seven drooping fronds,
-- three coconuts.
function City.palm(c, pos, seed, s)
	local K = City.D
	local r = Random.new(seed or 1)
	s = s or 1
	local g = c:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber() * math.pi * 2, 0)):group('Palm')
	local lean = 0.12 + r:NextNumber() * 0.12
	local x, y = 0, 0
	for k = 1, 6 do
		local w = (1.5 - k * 0.06) * s
		sbox(g, 'PalmTrunk', V(x - w / 2, y, -w / 2), V(x + w / 2, y + 2.1 * s, w / 2), k % 2 == 0 and K.trunk or K.trunkDark)
		y += 2.1 * s
		x += lean * k * 0.35 * s
	end
	local topCf = CFrame.new(x, y + 0.2, 0)
	sbox(g, 'PalmHeart', V(x - 0.9 * s, y, -0.9 * s), V(x + 0.9 * s, y + 0.9 * s, 0.9 * s), K.frondDark)
	for k = 0, 6 do
		local a = k * math.pi * 2 / 7 + r:NextNumber() * 0.3
		local base = topCf * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-18), 0, 0)
		local col = k % 2 == 0 and K.frond or K.frondDark
		g:part('PalmFrond', V(1.4 * s, 0.35 * s, 5 * s), base * CFrame.new(0, 0, -2.5 * s), col, M.SmoothPlastic)
		g:part('PalmFrondTip', V(1.0 * s, 0.3 * s, 3 * s), base * CFrame.new(0, 0, -5 * s) * CFrame.Angles(math.rad(-38), 0, 0) * CFrame.new(0, 0, -1.4 * s), col, M.SmoothPlastic)
	end
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		g:box('Coconut', V(x + math.cos(a) * 0.7 * s - 0.4 * s, y - 0.9 * s, math.sin(a) * 0.7 * s - 0.4 * s), V(x + math.cos(a) * 0.7 * s + 0.4 * s, y - 0.1 * s, math.sin(a) * 0.7 * s + 0.4 * s), C(120, 84, 50), M.SmoothPlastic)
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'PalmTrunk' then decor(p) end end
	return g
end
-- A dark square planter with a pink glowing rim and a palm in it (pos: its centre on the ground).
function City.palmPlanter(c, pos, seed)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('PalmPlanter')
	sbox(g, 'PlanterBox', V(-2.6, 0, -2.6), V(2.6, 1.6, 2.6), K.luxPlanter)
	decor(g:box('PlanterNeon', V(-2.75, 1.6, -2.75), V(2.75, 1.85, 2.75), K.pink, M.Neon)).CastShadow = false
	decor(sbox(g, 'PlanterSoil', V(-2.2, 1.6, -2.2), V(2.2, 1.9, 2.2), C(110, 84, 64)))
	City.palm(g, V(0, 1.9, 0), seed, 0.85)
	return g
end
-- The red BOSS gateway over the run just before gate 16 (stage 15, z' zp): two red towers on the strips, a lintel over
-- the street with BOSS on it (facing the way you come), steady red neon round it.
function City.bossGate(d, top, zp)
	local K = City.D
	local g = d:group('BossGate')
	local z0, z1 = top - zp - 2, top - zp + 2
	local red, dark = C(226, 40, 52), C(150, 24, 36)
	for _, s in { -1, 1 } do
		local a, b = s * 22.5, s * 27.5
		sbox(g, 'BossTower', V(math.min(a, b), -0.5, z0), V(math.max(a, b), 36, z1), red)
		sbox(g, 'BossTowerBase', V(math.min(a, b) - 0.5, -0.5, z0 - 0.5), V(math.max(a, b) + 0.5, 2.5, z1 + 0.5), dark)
		local e = s * 22
		decor(g:box('BossNeon', V(math.min(e, e + s * 0.5) , 2.5, z1 - 0.2), V(math.max(e, e + s * 0.5), 30, z1 + 0.3), C(255, 60, 70), M.Neon)).CastShadow = false
	end
	sbox(g, 'BossLintel', V(-27.5, 30, z0), V(27.5, 38, z1), red)
	decor(g:box('BossNeon', V(-22.4, 29.6, z1 - 0.2), V(22.4, 30.1, z1 + 0.3), C(255, 60, 70), M.Neon)).CastShadow = false
	local sign = g:box('BossSign', V(-11, 31, z1), V(11, 37, z1 + 0.3), dark, M.SmoothPlastic)
	decor(sign).CastShadow = false
	line(surface(sign, Enum.NormalId.Back, 10), 'Boss', 'BOSS', P.white, FONT.title, 0.04, 0.92, C(120, 0, 20), 4)
	return g
end
---------------------------------------------------------------------------------------------- the business district avenue (World 2)
-- World 2's stages (runs after f2_stages and f3_waves; its buildStages is the one V2.Build calls). (Oct 27 round 3, the
-- owner: "make the buildings taller, make it the size of the first world, and then make the look in general way
-- better") World 1's track: 15 stages of 64 studs, gate 16, the boss yard (here the rooftop, Stage 16: The CEO's crew).
-- The cross-section is World 1's (f_areas, P.street, in the city's colours from a2_city): the asphalt run |x| < 8.5 with
-- white dashes, the stone sidewalks to 16.5, the paved strip to the tower fronts at 36. Each stage adds (z' = studs
-- past its own gate):
--   towers   two highrises a side (z' 0..28 and 28..56, fronts at |x| 36, back to 64; City.highrise): a shop podium
--            with awnings and signs on the street, glass or warm stone above, 45 high by the lobby and taller every
--            stage, up to ~140 by Stage 15; a one-storey shop row each side at z' 56..64 out to |x| 22, framing the next
--            gate the way World 1's end buildings do
--   street   solid white edge lines, a zebra crosswalk kerb to kerb at z' 13..19 with a stop line and a tall signal
--            (its lights high over the road, out of the camera's way), steel lamps
--   district three stages each (the owner's Oct 27 mockup; props in city/f4_districts.lua): City Streets (red brick
--            and grey towers, lanterns, a bus stop, taxis, food trucks), Modern Plaza (glass, light tiles, a fountain),
--            Construction Zone (sand, steel frames with scaffolds, a crane, barriers), Transit Area (the elevated line,
--            the station and its escalator, a train; the fenced street court on the right, where EnemyRules.Courts has
--            the crew), Luxury District (dark glass with pink neon, palms, pink lines, a sky bridge, the BOSS gateway)
-- Past gate 16: the rooftop (City.rooftop), the CEO tower behind it. Round it all: the side streets and two more rows
-- of towers either side, taller up the track (City.skylineFar). World 1's hood edges (its grass lots, low wall and ring
-- road, f_areas) give way to the city's paved base (the buildGround wrapper below).

-- The city's extra shop words (the podiums' signs).
for _, w in { 'COFFEE', 'DELI', 'SUSHI', 'GYM', 'HOTEL', 'PHONES', 'SNEAKERS', 'ARCADE', 'JUICE', 'BAGELS', 'NOODLES', 'SALON' } do table.insert(City.Words, w) end

-- A tall signal at pos (on the sidewalk's back edge): a steel pole, a mast arm reaching `dir` (+1 / -1 in x) over the
-- road, two yellow three-lamp heads hanging from it at 15-19 (over a player's head and camera), facing +Z (the way you
-- come), the red lit.
function City.signal(c, pos, dir)
	local t = c:at(CFrame.new(pos)):group('Signal')
	sbox(t, 'SignalBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), City.steelDark)
	t:box('SignalPole', V(-0.55, 1.2, -0.55), V(0.55, 21, 0.55), City.steel, M.SmoothPlastic)
	decor(t:box('SignalArm', V(math.min(0, dir * 13), 20.2, -0.35), V(math.max(0, dir * 13), 20.9, 0.35), City.steel, M.SmoothPlastic))
	for _, hx in { dir * 5.5, dir * 11.5 } do
		decor(t:box('SignalHanger', V(hx - 0.15, 19, -0.15), V(hx + 0.15, 20.2, 0.15), City.steelDark, M.SmoothPlastic))
		decor(t:box('SignalHead', V(hx - 0.9, 14.6, -0.6), V(hx + 0.9, 19, 0.6), City.yellow, M.SmoothPlastic))
		for k, c3 in { C(255, 60, 50), C(96, 84, 50), C(50, 76, 56) } do
			local y = 19 - k * 1.42
			decor(t:box('SignalLamp', V(hx - 0.55, y + 0.1, 0.6), V(hx + 0.55, y + 1.2, 0.72), c3, k == 1 and M.Neon or M.SmoothPlastic)).CastShadow = false
			decor(t:box('SignalHood', V(hx - 0.65, y + 1.2, 0.6), V(hx + 0.65, y + 1.38, 1.15), C(30, 32, 38), M.SmoothPlastic)).CastShadow = false
		end
	end
	return t
end
-- A cinema marquee on face f of a podium (City.face): a deep yellow canopy over the doors with a white sign band on its
-- three sides (the word on the front), a row of warm bulbs under its lip (steady, no flashing), a tall blade sign above.
function City.marquee(c, f, x0, x1, z0, z1, word)
	local box, u0, u1 = City.face(c, f, x0, x1, z0, z1)
	local m, w = (u0 + u1) / 2, math.min(9, (u1 - u0) / 2 - 1)
	local function d(p) decor(p).CastShadow = false return p end
	d(box('CinemaDoors', m - w + 1, m + w - 1, 0.9, 5.2, 0, 0.14, City.doorGlass))
	decor(box('Marquee', m - w, m + w, 5.4, 6.6, 0, 4.4, C(255, 196, 40)))
	local sign = box('MarqueeSign', m - w - 0.1, m + w + 0.1, 6.6, 9.4, 3.2, 4.5, P.white)
	decor(sign)
	local face = ({ S = Enum.NormalId.Back, N = Enum.NormalId.Front, E = Enum.NormalId.Right, W = Enum.NormalId.Left })[f]
	line(surface(sign, face, 12), 'Cinema', word, C(214, 40, 60), FONT.title, 0.06, 0.88, P.white, 2)
	for b = 0, math.floor(w * 2 / 1.6) do
		local u = m - w + 0.5 + b * 1.6
		if u < m + w - 0.3 then d(box('MarqueeBulb', u - 0.22, u + 0.22, 5.1, 5.4, 4.0, 4.4, C(255, 244, 200))).Material = M.Neon end
	end
end
-- A green news stand (cf: its centre on the ground, front -Z): a kiosk with a striped roof and racks of papers.
function City.newsStand(c, cf)
	local t = c:at(cf):group('NewsStand')
	sbox(t, 'KioskBody', V(-2.6, 0, -1.8), V(2.6, 4.4, 1.8), C(40, 150, 100))
	decor(t:box('KioskWindow', V(-2, 1.6, -1.9), V(2, 3.8, -1.8), City.doorGlass, M.SmoothPlastic)).CastShadow = false
	for k = 0, 5 do decor(t:box('KioskRoof', V(-3 + k, 4.4, -2.4), V(-2 + k, 5, 2.2), k % 2 == 0 and C(232, 64, 60) or P.white, M.SmoothPlastic)) end
	for k, col in { C(250, 250, 250), C(250, 210, 60), C(120, 190, 250) } do
		decor(t:box('Papers', V(-2.2 + (k - 1) * 1.5, 0.8, -2.3), V(-1.0 + (k - 1) * 1.5, 1.5, -1.8), col, M.SmoothPlastic))
	end
	return t
end

---------------------------------------------------------------------------------------------- the stages
-- The districts (three stages each; the owner's mockup, city/f4_districts.lua): the name, glass's share of the towers,
-- an extra height (studs).
City.Looks = {
	{ name = 'City Streets', glass = 0.25, lift = 0 },
	{ name = 'Modern Plaza', glass = 1.0, lift = 4 },
	{ name = 'Construction Zone', glass = 0.5, lift = 6 },
	{ name = 'Transit Area', glass = 0.6, lift = 8 },
	{ name = 'Luxury District', glass = 1.0, lift = 16 },
}
-- How tall a front tower stands: ~45 on Stage 1, ~6 more each stage (taller up the track), varied per tower, in whole
-- storeys over the podium.
function City.heightAt(i, slot, s)
	local L = City.Looks[lookOf(math.clamp(i, 1, STAGES))] or City.Looks[1]
	local v = ((i * 3 + slot * 2 + (s > 0 and 1 or 0)) % 4) * 5
	return 8.8 + math.floor((30 + i * 6 + v + L.lift) / 5) * 5
end
function City.kindAt(i, slot, s)
	local L = City.Looks[lookOf(math.clamp(i, 1, STAGES))] or City.Looks[1]
	local r = ((i * 7 + slot * 5 + (s > 0 and 3 or 0)) % 10) / 10
	return r < L.glass and 'glass' or 'stone'
end

-- The Park Courts' street court (stages 10-12, the right side; EnemyRules.Courts: the chain-link at x 22, z' 3..55, its
-- gateway at z' 23..27.5, the players' tunnel at x 26.6, z' 52 with its mouth toward the gate): a fenced court on a park
-- apron, hoops at both ends, floodlights, a mural wall at the back, trees outside the fence.
City.Courts = { { court = C(52, 112, 210), key = C(36, 86, 170) }, { court = C(226, 120, 52), key = C(196, 92, 40) }, { court = C(40, 160, 110), key = C(30, 126, 86) } }
function City.court(d, top, at, i)
	local ST = P.street
	local K = City.Courts[trioOf(i)]
	local x0, x1, za, zb = 22, 62.4, 3, 55
	District.floor(d, top, 1, ST.road + ST.walk, 64, 0, 56, ST.kerb + 0.08, C(96, 176, 96), 'CourtGround')
	local y = ST.kerb + 0.08
	sbox(d, 'CourtBorder', V(30, y - 0.3, top - 6), V(60, y + 0.06, top - 52), C(236, 232, 222))
	sbox(d, 'Court', V(31.5, y - 0.2, top - 7.5), V(58.5, y + 0.12, top - 50.5), K.court)
	local function mark(a0, b0, a1, b1) decor(d:box('CourtLine', V(a0, y + 0.12, top - b1), V(a1, y + 0.16, top - b0), P.white, M.SmoothPlastic)).CastShadow = false end
	mark(31.5, 7.5, 58.5, 7.9); mark(31.5, 50.1, 58.5, 50.5); mark(31.5, 7.5, 31.9, 50.5); mark(58.1, 7.5, 58.5, 50.5); mark(31.5, 28.8, 58.5, 29.2)
	for _, e in { { 7.9, 17 }, { 41, 50.1 } } do
		decor(d:box('CourtKey', V(41, y + 0.12, top - e[2]), V(49, y + 0.14, top - e[1]), K.key, M.SmoothPlastic)).CastShadow = false
	end
	for _, hp in { { 7, math.pi }, { 51, 0 } } do District.hoop(d, CFrame.new(V(45, y, top - hp[1])) * CFrame.Angles(0, hp[2], 0)) end
	chainLink(d, V(x0, ST.kerb, top - za), V(x0, ST.kerb, top - zb), 10, { { 23, 27.5 } })
	chainLink(d, V(x0, ST.kerb, top - za), V(x1, ST.kerb, top - za), 10)
	chainLink(d, V(x0, ST.kerb, top - zb), V(x1, ST.kerb, top - zb), 10)
	District.backWall(d, top, 1, x1, 0, 56, 14)
	-- (release fixes) keep-in caps over the fence tops, from just under them to 40 up: a player who climbs a signal and a
	-- tree crown can't stand on the chain-link and drop into the court's corners or onto the shop roofs behind it, where
	-- there's no way back (tools/checks/city_reach); the gateway at ground level stays open
	local capY = ST.kerb + 9
	invisibleWall(d, V(x0 - 0.5, capY, top - zb), V(x0 + 0.5, 40, top - za))
	invisibleWall(d, V(x0, capY, top - za - 0.5), V(x1, 40, top - za + 0.5))
	invisibleWall(d, V(x0, capY, top - zb - 0.5), V(x1, 40, top - zb + 0.5))
	local mural = ghost(d:box('Mural', V(x1 - 0.08, ST.kerb + 3, top - 12), V(x1 - 0.02, ST.kerb + 12, top - 44), P.white, M.SmoothPlastic))
	line(surface(mural, Enum.NormalId.Left, 12), 'Mural', ({ 'CITY HOOPS', 'GAME ON', 'NEXT UP' })[trioOf(i)], ({ C(255, 210, 60), C(255, 96, 206), C(70, 220, 255) })[trioOf(i)], FONT.tag, 0.1, 0.8, P.black, 4).Rotation = -4
	for _, fl in { { 24, 5 }, { 60, 5 }, { 24, 53 }, { 60, 53 } } do District.floodlight(d, CFrame.lookAt(at(fl[1], fl[2]), at(45, 29)), 22) end
	for k, zp in ipairs({ 8, 47 }) do tree(d, at(19.4, zp), i * 100 + k, 0.8, 30 * k) end
	-- the players' tunnel (PropModels 'CourtTunnel', as World 1's courts), its mouth toward the gate
	local props = Armory.optional('PropModels')
	local okT, tunnel = false, nil
	if props and props.build then okT, tunnel = pcall(props.build, 'CourtTunnel', 1) end
	if okT and tunnel and tunnel.PrimaryPart then
		tunnel.Name = 'PlayersTunnel'
		local goal = d:world(CFrame.new(at(26.6, 50.4) + V(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0))
		local delta = goal * tunnel.PrimaryPart.CFrame:Inverse()
		for _, p in tunnel:GetDescendants() do
			if p:IsA('BasePart') then
				p.CFrame = delta * p.CFrame
				p.Anchored, p.CanTouch, p.CanQuery = true, false, false
				p.CanCollide = p.Name == 'Wall' or p.Name == 'Back' or p.Name == 'Post'
			end
		end
		tunnel.Parent = d.parent
	end
end

---------------------------------------------------------------------------------------------- the street's edge
-- (Oct 27 round 6, the owner: World 2 should "look and feel like the reference", his plan's stage shots) The street is
-- framed close, not open: low chunky blocks right behind the props strip on both sides (fronts at |x| 32, 12 deep, an
-- alley at z' 24..30 between the two), their shops on the street, in the district's colours; benches, crates and a
-- planter at the alley mouth. The construction zone has a site hoarding there instead (its steel frames stand behind),
-- the luxury district pink neon pillars (steady, no flashing) in front of its dark blocks.
City.Edge = { x0 = 32, x1 = 44, segs = { { 2, 24 }, { 30, 54 } } }
City.EdgeColors = {
	{ C(150, 154, 166), C(186, 92, 70), C(132, 138, 152) }, -- City Streets: grey stone and red brick
	{ C(214, 222, 236), C(176, 206, 232), C(226, 230, 238) }, -- Modern Plaza: pale stone and glass
	nil, -- Construction Zone: the hoarding
	{ C(146, 150, 160), C(120, 126, 140), C(160, 162, 170) }, -- Transit Area: concrete
	{ C(70, 62, 120), C(56, 66, 128), C(88, 64, 132) }, -- Luxury District: dark violet and blue
}
function City.bench(c, cf)
	local b = c:at(cf):group('Bench')
	for _, x in { -1.6, 1.6 } do sbox(b, 'BenchLeg', V(x - 0.3, 0, -0.6), V(x + 0.3, 1.4, 0.6), City.steelDark) end
	sbox(b, 'BenchSeat', V(-2.2, 1.4, -0.8), V(2.2, 1.8, 0.8), C(176, 116, 70))
	decor(b:box('BenchBack', V(-2.2, 1.8, 0.5), V(2.2, 3.2, 0.8), C(176, 116, 70), M.SmoothPlastic))
	return b
end
function City.crates(c, cf, seed)
	local b = c:at(cf):group('Crates')
	local wood, wood2 = C(196, 140, 78), C(170, 116, 62)
	sbox(b, 'Crate', V(-1.6, 0, -1.6), V(1.6, 3.2, 1.6), seed % 2 == 0 and wood or wood2)
	sbox(b, 'Crate', V(1.8, 0, -1.2), V(4.2, 2.4, 1.2), seed % 2 == 0 and wood2 or wood)
	decor(sbox(b, 'Crate', V(-1.1, 3.2, -1.1), V(1.1, 5.4, 1.1), wood:Lerp(P.white, 0.15))).CastShadow = false
	return b
end
function City.streetEdge(d, top, i, s, look, street)
	local E, ST, K = City.Edge, P.street, City.D
	local y = ST.kerb + 0.08
	local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
	local xa, xb = X(E.x0, E.x1)
	local pal = City.EdgeColors[look]
	for k, seg in E.segs do
		local z0, z1 = top - seg[2], top - seg[1]
		if look == 3 then
			-- the site hoarding: a board wall 7 high, blue and yellow panels, a top rail
			local hx0, hx1 = X(E.x0, E.x0 + 0.8)
			local n = math.floor((seg[2] - seg[1]) / 8 + 0.5)
			local len = (seg[2] - seg[1]) / n
			for q = 0, n - 1 do
				sbox(d, 'Hoarding', V(hx0, y - 1, top - seg[1] - (q + 1) * len), V(hx1, y + 7, top - seg[1] - q * len), (q + k + i) % 2 == 0 and C(52, 110, 200) or City.yellow)
			end
			decor(sbox(d, 'HoardingRail', V(math.min(hx0, hx1) - 0.1, y + 7, z0), V(math.max(hx0, hx1) + 0.1, y + 7.5, z1), City.steel)).CastShadow = false
		else
			local col = pal[(i + k + (s > 0 and 1 or 0)) % #pal + 1]
			local word = City.Words[(i * 3 + k * 5 + (s > 0 and 2 or 0)) % #City.Words + 1]
			City.block(d, xa, xb, z0, z1, { kind = look == 2 and 'office' or 'shop', floors = look == 5 and 2 or 1, color = col, tone = i + k, faces = { street, 'S' }, word = word, name = 'EdgeBlock' })
			if look == 5 then
				-- pink neon pillars at the block's two street corners (steady glow)
				for _, zp in { seg[1] + 0.5, seg[2] - 1.5 } do
					local pa, pb = X(E.x0 - 1.6, E.x0 - 0.2)
					local p = decor(d:box('NeonPillar', V(pa, y, top - zp - 1), V(pb, y + 18, top - zp), K.pink, M.Neon))
					p.CastShadow = false
				end
			end
		end
	end
	-- the alley mouth (z' 24..30): a bench facing the street, a stack of crates, a lantern's warm light over them
	local seed = i * 7 + (s > 0 and 3 or 0)
	-- (no bench where a food truck or the plaza's side fountain already stands)
	local busy = (look == 1 and s > 0) or (look == 2 and trioOf(i) ~= 2 and s == (i % 2 == 0 and 1 or -1))
	if not busy then City.bench(d, CFrame.new(s * 30.2, y, top - 27) * CFrame.Angles(0, s > 0 and -math.pi / 2 or math.pi / 2, 0)) end
	if look ~= 5 then City.crates(d, CFrame.new(s * 27.5, y, top - 51.5), seed) end
end

-- One stage of the avenue: World 1's stage group with its hidden fight marker (District.base), then the city on it, in
-- its district's dress (city/f4_districts.lua).
function City.avenueStage(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local K = City.D
	local look = lookOf(i)
	local cw0, cw1 = 13, 19 -- the crosswalk (z'), between the centre dashes at z' 7..11 and 23..27
	local ground = ({ nil, K.plazaTile, K.sand, nil, C(232, 222, 238) })[look] -- the district's ground on the paved strips
	local siteSide = i % 2 == 0 and 1 or -1 -- the construction zone's crane side
	for _, s in { -1, 1 } do
		local street = s < 0 and 'E' or 'W'
		local function x(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local court = look == 4 and s > 0
		if ground then District.floor(d, top, s, ST.road + ST.walk, FRONT, 0, ST.endZ, ST.kerb + 0.08, ground, 'DistrictGround') end
		-- (Oct 27 round 5, the owner: "make way less buildings following the new building plans": his mockup's stages
		-- are an open street under the sky, carried by the district's props, with only a few towers set back and spaced
		-- out) Per stage: one hero tower, set back off the street on the far lot (z' 28..56, the side alternating, never
		-- the court's), one low block on the near lot across from it, and open lots (paving and trees in planters) in
		-- between; the construction zone keeps its steel frames on the far lots instead.
		if not court then
			local hero = (i % 2 == 1 and 1 or -1)
			if look == 4 then hero = -1 end -- (the court has the right side)
			local lotY = ST.kerb + 0.08
			local lotColor = ground or City.walk:Lerp(City.road, 0.15)
			for slot = 1, 2 do
				local z0, z1 = top - 28 * slot, top - 28 * (slot - 1)
				local h = City.heightAt(i, slot, s)
				local tone = i * 2 + slot + (s > 0 and 3 or 0)
				local xa, xb = x(FRONT, FRONT + DEPTH)
				if look == 3 and slot == 2 then
					-- the construction zone's back lots: a building going up (a crane over the one on the crane side)
					City.steelFrame(d, xa, xb, z0, z1, 40 + ((i + (s > 0 and 1 or 0)) % 3) * 6, street, i * 10 + s)
					if s == siteSide then City.crane(d, s * 46.75, top - 38.75, 84 + trioOf(i) * 4, -s, 34) end
				elseif slot == 2 and s == hero then
					-- the hero tower, 8 back from the street front, a paved forecourt before it
					local fa, fb = x(FRONT, FRONT + 8)
					sbox(d, 'Lot', V(fa, lotY - 1.4, z0), V(fb, lotY, z1), lotColor)
					xa, xb = x(FRONT + 8, FRONT + DEPTH)
					local word = City.Words[(i * 5 + slot * 3 + (s > 0 and 7 or 0)) % #City.Words + 1]
					local o = { kind = City.kindAt(i, slot, s), tone = tone, faces = { street, 'S' }, shops = { street }, word = word, setback = h >= 80 and 3 or nil, shadow = true, name = 'TowerB' }
					if look == 1 then -- red brick and grey
						local brick = (i % 2) == 0
						o.stone = brick and K.brick[(i % 3) + 1] or K.grey[(i + slot) % 3 + 1]
						o.crown = brick and C(250, 206, 120) or C(232, 64, 60)
					elseif look == 2 then -- clean glass, a white crown
						o.crown = C(244, 246, 250)
					elseif look == 5 then -- dark blue glass, pink neon up the corners
						o.kind, o.glassColor = 'glass', ({ C(70, 92, 176), C(96, 76, 168), C(58, 108, 176) })[(i + slot) % 3 + 1]
						o.crown, o.neon = K.pink, K.pink
					end
					City.highrise(d, xa, xb, z0, z1, h + 10, o)
				else
					-- an open lot behind the street's own low blocks (round 6: City.streetEdge): paving to the lot's back
					sbox(d, 'Lot', V(xa, lotY - 1.4, z0), V(xb, lotY, z1), lotColor)
				end
			end
		end
		if not court then City.streetEdge(d, top, i, s, look, street) end
		-- (round 5) the street's keep-in: with the lots open, an invisible wall along the street front (the court's
		-- side keeps its fence, back wall and caps)
		if not court then invisibleWall(d, V(math.min(s * FRONT, s * (FRONT + 1)), 0, top - SLEN), V(math.max(s * FRONT, s * (FRONT + 1)), 60, top + (i == 1 and 8 or 1))) end
		local pa, pb = x(ST.open, FRONT + DEPTH)
		City.block(d, pa, pb, top - SLEN, top - ST.endZ, { kind = 'shop', floors = 1, tone = i * 2 + (s > 0 and 3 or 6), color = City.EdgeColors[look] and City.EdgeColors[look][(i + (s > 0 and 2 or 0)) % 3 + 1] or nil, faces = { street, 'S' }, name = 'ShopRow' }) -- (round 6: a storey taller, in the street's own colours, so it reads as the corner building framing the gate, not a low dark fence)
		-- the solid edge line along the run, broken at the crosswalk (the luxury district's glows pink)
		for _, r in { { 0, cw0 - 0.5 }, { cw1 + 0.5, SLEN } } do
			local e = decor(sbox(d, 'LaneEdge', V(s * 7.2, 0, top - r[2]), V(s * 7.7, 0.12, top - r[1]), City.line))
			e.CastShadow = false
			if look == 5 then e.Color, e.Material = K.pink, M.Neon end
		end
		-- lamps on the sidewalk (the old streets' black lanterns), their arms over the run
		for _, zp in { 9, 30 } do
			-- (round 6: the plan's warm lanterns in the streets, the plaza and the transit area)
			if look == 1 or look == 2 or look == 4 then City.lantern(d, at(s * 15.4, zp)) else City.lamp(d, at(s * 15.4, zp), -s) end
		end
	end
	if look == 4 then City.court(d, top, at, i) end
	-- the crosswalk, kerb to kerb (7 bars over the 17-stud run), a stop line before it, its signal
	District.zebra(d, V(-7.0, 0, top - (cw0 + cw1) / 2), 1.4, cw1 - cw0, V(7 / 3, 0, 0), 7)
	decor(sbox(d, 'StopLine', V(-7.1, 0, top - cw0 + 1.0), V(7.1, 0.12, top - cw0 + 1.6), City.line)).CastShadow = false
	local ls = i % 2 == 1 and 1 or -1
	City.signal(d, at(ls * 15.6, cw0 - 1.5), -ls)
	-- the street's life, by district; on the sidewalks' back half and the paved strip, z' 2..42 (the crew and the next
	-- gate's pads keep z' 44..64 clear)
	local seed = 800 + i * 10
	local t = trioOf(i)
	local function planters(list) for _, p in list do City.planter(d, at(p[1], p[2]), seed + p[2]) end end
	if look == 1 then
		if i == 1 then City.busStop(d, CFrame.new(at(-20.2, 21)) * CFrame.Angles(0, -math.pi / 2, 0)) end
		City.taxi(d, CFrame.new(at(-19.6, 36)))
		City.foodTruck(d, CFrame.new(at(27.5, 22)) * CFrame.Angles(0, math.pi, 0), ({ C(240, 96, 60), C(60, 150, 240), C(250, 180, 40) })[t], ({ 'TACOS', 'ICE CREAM', 'BURGERS' })[t])
		planters({ { -19.6, 5 }, { 19.6, 5 }, { -27, 40 }, { 26, 40 }, { -27, 12 } })
	elseif look == 2 then
		local fs = i % 2 == 0 and 1 or -1
		-- (round 6, the plan's Modern Plaza 2: the fountain in the middle of the road; players pass either side)
		if trioOf(i) == 2 then City.fountain(d, V(0, 0, top - 22), nil, 3) else City.fountain(d, at(fs * 26, 25)) end
		City.taxi(d, CFrame.new(at(-fs * 19.6, 30)))
		planters({ { -19.6, 5 }, { 19.6, 5 }, { -fs * 28, 12 }, { -27, 41 }, { 27, 41 } })
		City.planter(d, at(-fs * 28, 22), seed + 3, 8, 4)
	elseif look == 3 then
		-- (round 6, the plan: sand across the whole street, kerb to kerb and over the sidewalks, to the gate's pads)
		sbox(d, 'SandStreet', V(-P.street.road + 0.05, -0.2, top - 54), V(P.street.road - 0.05, 0.06, top), K.sand)
		for _, s in { -1, 1 } do
			local a, b = math.min(s * (P.street.road - 0.05), s * (P.street.road + P.street.walk)), math.max(s * (P.street.road - 0.05), s * (P.street.road + P.street.walk))
			sbox(d, 'SandWalk', V(a, P.street.kerb - 0.2, top - 54), V(b, P.street.kerb + 0.12, top), K.sandDark:Lerp(K.sand, 0.5))
		end
		for _, s in { -1, 1 } do
			City.barrier(d, CFrame.new(at(s * 19.2, 9)) * CFrame.Angles(0, math.pi / 2, 0))
			if Stations then for _, zp in { 4, 24, 36 } do Stations.cone(d:at(CFrame.new(at(s * 9.4, zp))), CFrame.new()) end end
		end
		City.sandPile(d, at(-siteSide * 27, 16))
		City.bricks(d, at(siteSide * 27, 20))
		City.bricks(d, at(-siteSide * 28, 34))
		City.barrier(d, CFrame.new(at(siteSide * 28, 38)) * CFrame.Angles(0, math.pi / 2, 0))
	elseif look == 4 then
		City.viaduct(d, top, 0, SLEN, ({ { 1 }, nil, { SLEN - 1 } })[t])
		if t <= 2 then City.station(d, top, 4, 28, 10, 36) -- (round 6: the escalator up to the line on Transit 2 too, as the plan)
		else City.taxi(d, CFrame.new(at(-19.6, 30))) end
		if t == 2 then City.train(d, top, 6, 3) elseif t == 3 then City.train(d, top, 22, 2) end
		planters({ { -19.6, 5 }, { -27, 18 }, { -27, 38 } })
	else
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { -27, 40 }, { 27, 40 }, { 27, 14 }, { -27, 14 } } do City.palmPlanter(d, at(p[1], p[2]), seed + p[2] + (p[1] > 0 and 1 or 0)) end
		if i == 14 then City.fountain(d, V(0, 0, top - 22), K.pinkSoft, 3) end -- (round 6: in the road's middle, as the plan)
		car(d, CFrame.new(at(i % 2 == 0 and 19.6 or -19.6, 26)), K.pinkSoft)
		if i == 14 then -- a glass sky bridge over the avenue between the two towers' upper floors
			local y0 = City.heightAt(i, 1, -1) - 22
			local b = d:group('SkyBridge')
			b:box('BridgeGlass', V(-FRONT - 1, y0, top - 18), V(FRONT + 1, y0 + 6, top - 10), City.glass[2], M.SmoothPlastic)
			decor(b:box('BridgeDeck', V(-FRONT - 1, y0 - 1.2, top - 18.4), V(FRONT + 1, y0, top - 9.6), City.steelDark, M.SmoothPlastic))
			decor(b:box('BridgeRoof', V(-FRONT - 1, y0 + 6, top - 18.4), V(FRONT + 1, y0 + 6.8, top - 9.6), K.pink, M.SmoothPlastic))
			for xx = -FRONT + 6, FRONT - 6, 6 do
				for _, zz in { top - 18.15, top - 9.85 } do decor(b:box('BridgeMullion', V(xx - 0.25, y0, zz - 0.15), V(xx + 0.25, y0 + 6, zz + 0.15), City.mullion, M.SmoothPlastic)) end
			end
		end
		if i == STAGES then City.bossGate(d, top, 51) end
	end
	return d
end

---------------------------------------------------------------------------------------------- the rooftop (Stage 16)
-- (GoalRules' World 2 chain: "Reach the rooftop", "Beat The CEO", "on the rooftop, Stage 16") Past gate 16: the CEO
-- tower's podium roof, World 1's boss yard frame (|x| < 36, z BOSS_TOP..BOSS_END). Its floor is a blue-grey roof deck in
-- big two-tone tiles with a helipad (a dark disc, a yellow ring, a white H) in the middle; a glass parapet on a stone kerb round its sides and far
-- end (invisible walls over it); along the edges, clear of the fight: rooftop plant (AC units with fans,
-- vents, a dish); the CHAMP BAY (the Champ Ring's lane, as World 1's warehouse has it) in the near right corner; the
-- stage's two cash pads before the far parapet; the CEO tower rising behind it with a gold CEO sign over its doors. The crew waits
-- in front of the far parapet (EnemyRules.Spots[16]); the fight marker stays hidden, like World 1's.
function City.rooftop(ctx)
	local b, model = ctx:group('Rooftop')
	model:SetAttribute('Stage', 16)
	local function zp(v) return BOSS_TOP - v end
	local D = BOSS_TOP - BOSS_END -- 96
	local deckY = 0.12
	-- the deck: 16 x 16 tiles, two close tones, a darker frame round it
	for x = -FRONT, FRONT - 1, 16 do
		for v = 0, D - 1, 16 do
			local tone = ((x + FRONT) // 16 + v // 16) % 2 == 0 and C(132, 146, 186) or C(124, 138, 178)
			sbox(b, 'RoofDeck', V(x, -0.5, zp(math.min(v + 16, D))), V(math.min(x + 16, FRONT), deckY, zp(v)), tone)
		end
	end
	-- the helipad: a yellow ring, a white H, in the middle of the deck (z' 46)
	local hz = zp(46)
	decor(b:part('Helipad', V(0.1, 30, 30), CFrame.new(0, deckY + 0.05, hz) * CFrame.Angles(0, 0, math.pi / 2), C(70, 78, 104), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	for q = 0, 23 do
		local a0, a1 = q / 24 * math.pi * 2, (q + 1) / 24 * math.pi * 2
		local p0, p1 = V(math.cos(a0) * 13, deckY + 0.12, hz + math.sin(a0) * 13), V(math.cos(a1) * 13, deckY + 0.12, hz + math.sin(a1) * 13)
		decor(b:part('HelipadRing', V(1.4, 0.08, (p1 - p0).Magnitude + 0.1), CFrame.lookAt((p0 + p1) / 2, p1), City.yellow, M.SmoothPlastic)).CastShadow = false
	end
	for _, r in { { -4.5, -3, -5.5, 5.5 }, { 3, 4.5, -5.5, 5.5 }, { -3, 3, -0.75, 0.75 } } do
		decor(b:box('HelipadH', V(r[1], deckY + 0.08, hz + r[3]), V(r[2], deckY + 0.16, hz + r[4]), P.white, M.SmoothPlastic)).CastShadow = false
	end
	-- the parapet: a stone kerb, glass panels, a steel rail, along both sides and the far end (open at the gate)
	local function parapet(a, c2)
		local lo, hi = V(math.min(a.X, c2.X), 0, math.min(a.Z, c2.Z)), V(math.max(a.X, c2.X), 0, math.max(a.Z, c2.Z))
		sbox(b, 'ParapetKerb', lo + V(0, -0.5, 0), hi + V(0, 1.4, 0), C(206, 198, 186))
		-- the glass: the kerb's length, a third of its thickness, in its middle
		local thinX = hi.X - lo.X <= 1.01
		local glass = decor(b:box('ParapetGlass', V(thinX and lo.X + 0.35 or lo.X, 1.4, thinX and lo.Z or lo.Z + 0.35), V(thinX and hi.X - 0.35 or hi.X, 4.6, thinX and hi.Z or hi.Z - 0.35), C(170, 220, 250), M.SmoothPlastic))
		glass.Transparency, glass.CastShadow = 0.5, false
		decor(b:box('ParapetRail', lo + V(0, 4.6, 0), hi + V(0, 5.1, 0), City.steel, M.SmoothPlastic))
		invisibleWall(b, lo, hi + V(0, 30, 0))
	end
	parapet(V(-FRONT, 0, zp(0)), V(-FRONT + 1, 0, zp(D)))
	parapet(V(FRONT - 1, 0, zp(0)), V(FRONT, 0, zp(D)))
	parapet(V(-FRONT + 1, 0, zp(D - 1)), V(FRONT - 1, 0, zp(D)))
	-- rooftop plant along the sides (z' 26..70) and the far corners
	local plant = b:group('RoofPlant')
	local function ac(xc, v, k)
		local g = plant:at(CFrame.new(xc, deckY, zp(v)))
		sbox(g, 'ACUnit', V(-2.4, 0, -2), V(2.4, 3.2, 2), C(206, 212, 222))
		for _, fz in { -1, 1 } do
			decor(g:part('ACFan', V(0.12, 2.4, 2.4), CFrame.new(fz * 1.2, 3.25, 0) * CFrame.Angles(0, 0, math.pi / 2), C(80, 88, 104), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		end
		decor(g:box('ACStripe', V(-2.45, 0.6, -2.05), V(2.45, 0.9, 2.05), ({ City.yellow, C(48, 140, 220), C(232, 64, 60) })[k % 3 + 1], M.SmoothPlastic)).CastShadow = false
	end
	for k, v in ipairs({ 28, 36, 60, 68 }) do ac(k % 2 == 0 and 31 or -31, v, k) end
	ac(-31, 48, 3)
	local dish = plant:at(CFrame.new(31, deckY, zp(48)))
	sbox(dish, 'DishBase', V(-1.2, 0, -1.2), V(1.2, 1, 1.2), City.steelDark)
	dish:box('DishPole', V(-0.3, 1, -0.3), V(0.3, 4, 0.3), City.steel, M.SmoothPlastic)
	decor(dish:part('Dish', V(0.4, 5, 5), CFrame.new(0, 5.2, 0) * CFrame.Angles(0, math.rad(200), math.rad(40)), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	-- the CHAMP BAY (the Champ Ring's lane, as World 1's warehouse): a steel deck in the near right corner with the lane's
	-- TrainingZone, a hazard edge, a big target and the bay's sign
	local ring = SKINS.StationById.Ring
	local bay = b:at(CFrame.new(26, deckY, zp(14))):group('Training_' .. ring.Id)
	sbox(bay, 'BayDeck', V(-7, 0, -7), V(7, 1, 7), C(70, 74, 90))
	for k = 0, 6 do decor(bay:box('BayEdge', V(-7 + k * 2, 1, 6.6), V(-6 + k * 2, 1.06, 7), City.yellow, M.SmoothPlastic)).CastShadow = false end
	local zone = bay:box('TrainingZone', V(-5, 1, -5), V(5, 1.25, 5), C(236, 238, 244), M.Fabric)
	zone.Name = 'TrainingZone'
	local target = bay:at(CFrame.new(6.2, 1, 0)):group('Equipment')
	target:box('TargetStand', V(-0.3, 0, -0.3), V(0.3, 5, 0.3), City.steelDark, M.Metal)
	for k, r2 in ipairs({ { 7, C(232, 48, 52) }, { 5, P.white }, { 3, C(232, 48, 52) }, { 1.2, City.yellow } }) do
		decor(target:part('Target', V(0.2 + k * 0.05, r2[1], r2[1]), CFrame.new(-0.2 - k * 0.05, 7.4, 0), r2[2], M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	local plate = bay:box('Nameplate', V(-6, 9.6, 6.2), V(6, 12.4, 6.6), C(24, 32, 56), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 24), 'Name', 'CHAMP BAY', City.yellow, FONT.title, 0.1, 0.8, P.black, 3)
	for _, x in { -5.6, 5.6 } do bay:box('PlatePost', V(x - 0.25, 1, 6.25), V(x + 0.25, 9.6, 6.55), City.steelDark, M.Metal) end
	local vfx = Armory.optional('HoodVFX')
	if vfx then vfx.station(zone, 9, nil, V(10, 12, 12)) end
	-- the stage's pads (beat the crew, then cash out, like before every gate) and the hidden fight marker
	local bz = BOSS_END + 22
	GATE.pads(b, 16, 15, bz - 7, deckY, 5.6, 11)
	fightPad(b, 16, V(0, deckY, bz), P.padRed, 6, 14, nil, true)
	-- the flanks past the parapet (|x| 36..64): the podium's lower roof, gravel and plant, up to the next towers
	for _, s in { -1, 1 } do
		sbox(b, 'FlankRoof', V(math.min(s * FRONT, s * (FRONT + DEPTH)), -1, BOSS_END), V(math.max(s * FRONT, s * (FRONT + DEPTH)), 0.95, BOSS_TOP), C(176, 178, 188))
		for k, v in ipairs({ 20, 52, 84 }) do
			local g = plant:at(CFrame.new(s * 50, 0.95, zp(v)))
			sbox(g, 'Vent', V(-3, 0, -3), V(3, 2.6, 3), C(200, 206, 216))
			decor(g:box('VentCap', V(-3.4, 2.6, -3.4), V(3.4, 3.2, 3.4), ({ City.yellow, C(48, 140, 220), C(232, 64, 60) })[k], M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the CEO tower behind the far parapet: the tallest glass on the map, a gold CEO sign over its doors, facing the deck
	local ceoZ0, ceoZ1 = BOSS_END - 72, BOSS_END - 4
	local t = City.highrise(b, -40, 40, ceoZ0, ceoZ1, 196, { kind = 'glass', tone = 2, faces = { 'S', 'E', 'W' }, setback = 6, name = 'CEOTower' })
	local sign = t:box('CEOSign', V(-18, 16, ceoZ1 - 1.1), V(18, 28, ceoZ1 - 0.7), C(255, 196, 40), M.SmoothPlastic)
	decor(sign)
	line(surface(sign, Enum.NormalId.Back, 6), 'CEO', 'CEO', P.white, FONT.title, 0.06, 0.88, C(120, 70, 0), 4)
	return b
end

---------------------------------------------------------------------------------------------- the city round the track
-- North of the plaza's ring (City.skyline, e5_plaza) the side streets run on up the whole avenue to the CEO tower's
-- block, the city's paved base under everything: an inner row of towers between the avenue's and the side street
-- (|x| 64..88.5), an outer row past it (|x| 116..166), a far row of plain glass silhouettes (|x| 170..206), and a row
-- across the north end either side of the CEO tower. Each row stands taller than the one inside it, and taller up the
-- track. No shadows (they'd only fall on roofs).
function City.skylineFar(ctx)
	local g = ctx:group('Skyline')
	local R = City.Ring
	local RY, WY = R.road, R.walk
	local zN = BOSS_END - 40 -- the side streets' north end, where the north row closes them
	local base = City.walk:Lerp(City.road, 0.25)
	local function stageAt(z) return math.clamp(math.floor(-z / SLEN) + 1, 1, STAGES) end
	for _, s in { -1, 1 } do
		local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local a, b = X(FRONT + DEPTH, R.walk0)
		sbox(g, 'CityBase', V(a, -1, zN), V(b, WY, 0), base)
		a, b = X(R.walk0, R.road0)
		sbox(g, 'Sidewalk', V(a, -1, zN), V(b, WY, 0), City.walk)
		a, b = X(R.road0, R.road1)
		sbox(g, 'Road', V(a, -1, zN), V(b, RY, 0), City.road)
		a, b = X(R.road1, R.walk1)
		sbox(g, 'Sidewalk', V(a, -1, zN), V(b, WY, 0), City.walk)
		a, b = X(R.walk1, 206)
		sbox(g, 'CityBase', V(a, -1, zN), V(b, WY, 0), base)
		for _, kx in { R.road0, R.road1 } do decor(sbox(g, 'KerbStone', V(s * (kx - 0.6), -0.5, zN), V(s * (kx + 0.6), WY + 0.1, 0), City.kerb)).CastShadow = false end
		for z = -8, zN + 6, -12 do decor(sbox(g, 'RoadLine', V(s * 102.7, RY, z - 5), V(s * 103.3, RY + 0.12, z), City.line)).CastShadow = false end
		-- (Oct 27 round 5, the owner's plan: a few towers for the skyline, set back and spaced out, not walls of them)
		-- one hero tower past the side street every 3 stages a side (the sides offset by a stage and a half), each in its
		-- district's glass or stone; open paved base between them
		local outer = s > 0 and 'W' or 'E'
		local k = 0
		local z = s > 0 and -40 or -136
		while z - 40 > zN do
			k += 1
			local z1, z0 = z, z - 36
			local h = City.heightAt(stageAt(z0), 1, s) + 40 + ((k * 7) % 3) * 12
			local xa, xb = X(R.walk1 + 4, R.walk1 + 40)
			City.highrise(g, xa, xb, z0, z1, h, { kind = (k + (s > 0 and 1 or 0)) % 3 == 1 and 'stone' or 'glass', tone = k + (s > 0 and 4 or 1), faces = { outer, 'S' }, setback = h >= 100 and 3 or nil, pitch = 6, name = 'OuterTower' })
			z -= 192
		end
	end
	-- the north end: the city's base round the CEO tower, a row of towers across either side of it
	sbox(g, 'CityBase', V(-206, -1, zN - 80), V(206, WY, zN), base)
	sbox(g, 'CityBase', V(-(FRONT + DEPTH), -1, zN), V(FRONT + DEPTH, WY, BOSS_END), base)
	for k, xs in ipairs({ { 90, 128 } }) do -- (round 5: one a side, framing the CEO tower; was three)
		for _, s in { -1, 1 } do
			local xa, xb = math.min(s * xs[1], s * xs[2]), math.max(s * xs[1], s * xs[2])
			City.highrise(g, xa, xb, zN - 46, zN - 4, 150 + k * 10 + (s > 0 and 8 or 0), { kind = (k + (s > 0 and 1 or 0)) % 2 == 0 and 'stone' or 'glass', tone = k * 2 + (s > 0 and 1 or 0), faces = { 'S' }, setback = 3, pitch = 6, name = 'NorthTower' })
		end
	end
	return g
end

-- The ground: World 1's (f_areas) for the street, its forecourt and the keep-in walls, without its hood edges (the grass
-- lots, the low boundary wall, the ring road round it, the boss yard's paving under the rooftop's deck), which the city's paved base and towers replace.
local hoodGround = buildGround
local function buildGround(ctx)
	local g = hoodGround(ctx)
	local ground = g and g.parent
	if ground then
		for _, p in ground:GetChildren() do
			if p:IsA('BasePart') and (p.Material == M.Grass or p.Name == 'Wall' or p.Name == 'WallCap' or p.Name == 'Paving') then p:Destroy() end
		end
		-- (Oct 27 round 6, the plan's grey stone walks, not white: the sidewalks mid grey stone, their slabs a shade either
		-- way, the props strip behind them a darker grey, so the street's white band is gone)
		local walk, strip = C(172, 174, 184), C(138, 140, 152)
		for _, p in ground:GetChildren() do
			if p:IsA('BasePart') then
				if p.Name == 'Sidewalk' then p.Color = walk
				elseif p.Name == 'WalkSlab' then p.Color = p.Color.R > P.st.walk.R and walk:Lerp(P.white, 0.08) or walk:Lerp(P.black, 0.06)
				elseif p.Name == 'WalkJoint' then p.Color = walk:Lerp(P.black, 0.18)
				elseif p.Name == 'Grass' then p.Color = strip
				elseif p.Name == 'GrassEdge' then p.Color = strip:Lerp(P.black, 0.15) end
			end
		end
	end
	local ring = ctx.parent:FindFirstChild('RingRoad')
	if ring then ring:Destroy() end
	return g
end

local function buildStages(ctx)
	for i = 1, STAGES do City.avenueStage(ctx, i) end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do
		local model = stageGate(gates, i)
		model:SetAttribute('WallId', 'HoodW' .. (V2.World or 2) .. 'Stage' .. i)
		model:SetAttribute('World', V2.World or 2)
		local name = model:FindFirstChild('GateWorldName', true)
		if name then
			name.Text = 'WORLD ' .. (V2.World or 2)
			-- (round 3) the board's lobby side carries the name too (the owner's board is blank there): a plate on its
			-- south face, the same words facing the plaza
			local face = name.Parent and name.Parent.Parent
			if face and face:IsA('BasePart') then
				local back = face:Clone()
				back.Name = 'GateBoardBack'
				local at, lz = face.CFrame.Position, (V2.Origin * CFrame.new(0, 0, model:GetAttribute('LineZ'))).Position.Z
				back.CFrame = CFrame.new(at.X, at.Y, 2 * lz - at.Z)
				pcall(function() back.Position = back.CFrame.Position end)
				local gui = back:FindFirstChildOfClass('SurfaceGui')
				if gui then gui.Face = Enum.NormalId.Back end
				back.Parent = face.Parent
			end
		end
	end
	City.rooftop(ctx)
	City.skylineFar(ctx)
end
---------------------------------------------------------------------------------------------- play here
-- Make The Block V2 the map the game runs on (players spawn here; gameplay services and the HUD use it),
-- or hand the game back to the original Block. Other spawn points are switched off, never deleted: each
-- remembers it was on (attribute HoodSpawnWasEnabled), and SetActive(false) switches it back on.
function V2.SetActive(on)
	local root = workspace:FindFirstChild(V2.Name)
	assert(root, 'Build the map first: require(game.ServerStorage.' .. V2.Name .. ').Build()')
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
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint(V2.Name .. ' active ' .. tostring(on)) end)
	print(on and ('[' .. V2.Name .. '] Active: press Play to spawn here. SetActive(false) gives the game back to the original Block.')
		or ('[' .. V2.Name .. '] Inactive: the original Block is the game map again.'))
end
---------------------------------------------------------------------------------------------- look (B31)
-- The look pass over the lobby (brief 31 LOOK, $S/brief/B31/LOOK_RECIPE.md): the reference's toy-plastic finish instead
-- of the B30 hall's cold, studded-everywhere look. Runs once after the lobby is built (V2.Build), touches only the
-- Lobby model, and never moves, renames or removes a part that gameplay reads (lanes, pads, prompts, slots).
--   1. Studs: Roblox's Studs surface (high-contrast white/black strokes in the real client, brief/ref23
--      ours_studio_spawn.png) comes off every face. Walkable ground (an upright part whose top is near the deck)
--      gets the reference's faint tone-on-tone studs instead: one Texture on its top face (UIKit's StudBevel, one
--      stud per tile, drawn white at Look.StudAlpha). Walls, pillars, props and items stay flat clean colour; the
--      cliffs outside keep faint studs on every face (ref_product_pads: studded clay cliffs).
--   2. Material: Plastic -> SmoothPlastic (flat colour, no grain); Neon, Glass and the rest keep theirs.
--   3. Palette: the hall's cold teal / periwinkle / navy swapped for warm saturated fields (Look.Palettes).
--   4. Variant A "warehouse done right": the roof opens (glass, panels and skylight frames go; the girders stay and
--      throw stripes of shadow), warm clay brick walls, a light warm concrete field, lavender studded walks.
--      Variant B "open hood plaza": the same slice outdoors (rules 16/19 relaxed for the comparison only): the hall
--      shell goes, the field turns to studded grass, the cliffs and hood blocks frame it.
--   5. Items on product pads: a ground halo and slow star glints (built-in textures only; box pads keep BoxModels.fx).
-- Look.Variant: 'A' (default), 'B', or 'off' (the B30 look). Look.Lighting names the HoodLighting preset per variant.
local Look = {}
Look.Variant = 'P' -- (B31 PLAZA: the open plaza, rule 26; 'A' / 'B' were the slice's variants)
Look.StudAlpha = 0.15 -- the stud texture's Transparency (B31 PLAZA, critic 1: the ref's walks and grass show their studs plainly, a lit patch's
-- luminance spread 15-25 of 255; 0.45 measured 0.4, a dead fill)
Look.Lighting = { P = 'PlusOne', A = 'PlusOne', B = 'PlusOne', off = 'HoodSun' } -- (Oct 27: PlusOne, the +1 games' softer look; Huzz, HoodToy before)
-- Old colour (r,g,b) -> new colour, per variant. Keys are the hall's own colours (Lobby.Colors, Lobby.FieldColor and the
-- shades the hall builder derives), measured by area in the B30 lobby (work31_LOOK/tools: 57% of its surface was studded).
local function key(c) return string.format('%d,%d,%d', math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end
Look.Palettes = {
	A = {
		-- walls: clay brick (ref cliff clay H26 S84 V80, darker trims), a paler band, a deep brick base
		['126,183,193'] = C(224, 124, 56), ['150,202,210'] = C(236, 150, 96), ['86,130,152'] = C(142, 62, 44),
		['104,158,174'] = C(182, 88, 54),
		-- the field: light warm concrete (the walks stay the reference's lavender-grey)
		['150,152,162'] = C(212, 202, 186), ['204,206,226'] = C(238, 232, 220),
		-- pillars and the dais: warm cream stone with brick-red caps and bases
		['116,120,170'] = C(204, 182, 150), ['150,152,196'] = C(236, 222, 196), ['98,104,150'] = C(158, 78, 54),
		['200,204,228'] = C(250, 242, 226), ['126,130,178'] = C(214, 192, 160), ['176,182,218'] = C(232, 218, 196),
		-- the girders: toy-red steel (they stay; the roof between them opens)
		['72,88,118'] = C(186, 56, 44), ['84,104,134'] = C(200, 70, 52), ['76,100,138'] = C(170, 60, 46),
		-- windows and frames: dark warm brown frames, cream panels
		['18,34,72'] = C(70, 42, 34), ['146,154,188'] = C(226, 206, 176), ['150,156,186'] = C(226, 206, 176),
		['184,190,220'] = C(236, 220, 196), ['112,118,158'] = C(150, 120, 104),
	},
}
Look.Palettes.B = table.clone(Look.Palettes.A)
Look.Palettes.B['150,152,162'] = C(96, 200, 52) -- the field is grass outdoors (ref W01 grass 90,203,46 lit)
Look.Grass = C(96, 200, 52)
Look.Palettes.P = {} -- (the plaza builds in its own colours, e3_plaza)

function Look.studTexture()
	if Look._stud ~= nil then return Look._stud end
	local ok, Kit = pcall(require, ReplicatedStorage.Shared.UIKit)
	Look._stud = ok and Kit and (Kit.StudBevel ~= '' and Kit.StudBevel or Kit.StudTile) or ''
	return Look._stud
end
-- Faint studs on one face (or every face): a white StudBevel tile per stud.
function Look.faintStuds(p, faces, alpha)
	local id = Look.studTexture()
	if id == '' then return end
	for _, f in faces do
		local t = Instance.new('Texture')
		t.Name = 'LookStuds'
		t.Texture = id
		t.Face = f
		t.StudsPerTileU, t.StudsPerTileV = 1, 1
		t.Color3 = Color3.new(1, 1, 1)
		t.Transparency = alpha or Look.StudAlpha
		t:SetAttribute('PreviewTexture', 'stud_bevel')
		t.Parent = p
	end
end
local FACES = { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
local ALL = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
function Look.isStudded(p)
	for _, f in FACES do if p[f] == S.Studs then return true end end
	return false
end

-- Variant B: the hall's shell goes (everything over the deck in Hall and Roof, the World 2 portal stays).
function Look.openPlaza(lobby, deckY)
	for _, name in { 'Hall', 'Roof' } do
		local g = lobby:FindFirstChild(name)
		if g then
			for _, p in g:GetDescendants() do
				if p:IsA('BasePart') and not p:FindFirstAncestor('World2Portal') and not p:FindFirstAncestor('World1Portal') then
					local top = p.CFrame.Position.Y + p.Size.Y / 2
					if name == 'Roof' or top > deckY + 1.6 then p:Destroy() end
				end
			end
		end
	end
end
-- Variant A: the roof opens to the sky; the girders stay.
function Look.openRoof(lobby)
	local roof = lobby:FindFirstChild('Roof')
	if not roof then return end
	for _, p in roof:GetDescendants() do
		if p:IsA('BasePart') and (p.Name == 'RoofCeiling' or p.Name == 'RoofPanel' or p.Name:find('^RoofSkylight')) then p:Destroy() end
	end
end

-- (B34, the owner: "Classic studs everywhere", like their "Alien" place: Plastic with all six faces SurfaceType.Studs
-- on the lobby's built blocks) the floor slabs, walks and curbs, the decks, kerbs and plinths, the dais and the armory's
-- apron, the walls, the roof's steel and the cliffs and terraces outside. Smooth stay: Neon glows, glass, anything see-
-- through, anything carrying words (a SurfaceGui), signs, boards, screens and lamps, every lane, pad, item and prop, and
-- the owner's designed meshes (MeshParts). The faint stud texture goes wherever real studs replace it.
Look.Classic = false -- (Oct 27 round 2: the faint studs above instead; the classic surface's contrast can't be tuned)
Look.ClassicNames = { '^Concrete$', '^Threshold$', '^Grass$', '^Wall', '^Roof', '^Path', '^SpawnSquare$', '^Plaza', '^Dais',
	'^Apron', '^Cliff', '^Floor$', '^FloorField$' }
Look.ClassicKeep = { 'Sign', 'Board', 'Glow', 'Lamp', 'Screen', 'Label', 'Text', 'Neon', 'Nosing', 'Hazard' }
function Look.classicStuds(lobby)
	local n = 0
	for _, p in lobby:GetDescendants() do
		if p:IsA('Part') and p.Shape == Enum.PartType.Block and p.Material ~= M.Neon and p.Material ~= M.Glass
			and p.Transparency < 0.05 and not p:FindFirstChildOfClass('SurfaceGui') then
			local hit = false
			for _, pat in Look.ClassicNames do if p.Name:find(pat) then hit = true break end end
			if hit then for _, k in Look.ClassicKeep do if p.Name:find(k) then hit = false break end end end
			if hit then
				for _, t in p:GetChildren() do if t:IsA('Texture') and t.Name == 'LookStuds' then t:Destroy() end end
				p.Material = M.Plastic
				for _, f in FACES do p[f] = S.Studs end
				n += 1
			end
		end
	end
	lobby:SetAttribute('ClassicStudParts', n)
end
-- Items over product pads and box pads: a soft halo on the pad under the item and a few big star glints on it.
function Look.itemFX(lobby)
	for _, m in lobby:GetDescendants() do
		if m:IsA('Model') and m.Name:find('^PassBoard_') then -- (box pads: their chests carry BoxModels.fx's own glow disc and bob, b438ce4)
			local box = m:FindFirstChild('SparkleBox', true)
			local glow = m:FindFirstChild('PadGlow', true) or m:FindFirstChild('BoxPadGlow', true)
			local tone = glow and glow.Color or C(255, 230, 120)
			local _ = box -- (B31 PLAZA: the pads' own PadShine glints instead)
			if glow then
				local att = Instance.new('Attachment')
				att.Name = 'LookHalo'
				local r = glow.CFrame
				local hy = math.abs(r.RightVector.Y) * glow.Size.X / 2 + math.abs(r.UpVector.Y) * glow.Size.Y / 2 + math.abs(r.LookVector.Y) * glow.Size.Z / 2
				att.CFrame = r:ToObjectSpace(CFrame.new(glow.CFrame.Position + Vector3.new(0, hy + 0.06, 0)))
				att.Parent = glow
				local h = Instance.new('ParticleEmitter')
				h.Name = 'LookHalo'
				h.Texture = 'rbxasset://textures/glow.png'
				h:SetAttribute('PreviewTexture', 'softglow')
				h.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
				h.EmissionDirection = Enum.NormalId.Top
				h.Speed = NumberRange.new(0.01)
				h.Color = ColorSequence.new(tone:Lerp(Color3.new(1, 1, 1), 0.1)) -- (B31 PLAZA: the pad keeps its colour)
				h.LightEmission, h.LightInfluence = 1, 0
				h.Rate = 0.8
				h.Lifetime = NumberRange.new(2.5)
				local w = math.max(glow.Size.X, glow.Size.Y, glow.Size.Z) * 1.5
				h.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, w * 0.8), NumberSequenceKeypoint.new(1, w) })
				h.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(0.7, 0.76), NumberSequenceKeypoint.new(1, 1) })
				h.Parent = att
			end
		end
	end
end

-- (B31 PLAZA) Saturation over this on a lane's surfaces comes down to it (critic 7: big fields S 0.55-0.75; the pad tops,
-- prices and items keep theirs). Measured in the colour the part is built with; HoodToy's grade adds ~0.1 on screen.
-- (Oct 27, the owner: "make the colors the same also as the references ... more cartoony": the reference's bays are
-- full-strength hues, red ~(240, 40, 40); was 0.38, B31's "tone down", which left them pastel)
Look.BigS = 0.85
-- (stud layers on the plaza's ground, by part name; Oct 27 round 2, the owner: "make the studs not stand out as much,
-- make it like the reference": the faint tone-on-tone studs on the floor, the walks and every platform instead of
-- Roblox's classic Studs surface, tuned to the reference's stud contrast: a flat lit patch's luminance spread (p10..p90)
-- 16-26 of 255 in ref_STILL_lobby_topdown's floor and platforms)
Look.Layers = { Grass = 3, Path = 3, SpawnSquare = 3, PlazaDeck = 3, Concrete = 3, PlazaKerb = 2, PlazaStep = 2, DaisTop = 3, DaisStep = 3, DaisStairTread = 3 }
Look.WallLayers = 1 -- (the warehouse's brick walls: the same faint studs on every face, fainter: 2 layers measured 62 on a lit wall)
local function calm(col, maxS)
	local h, sat, v = col:ToHSV()
	if sat <= maxS then return col end
	return Color3.fromHSV(h, maxS, v)
end
function Look.apply(root)
	local v = Look.Variant
	if v == 'off' then return end
	local lobby = root:FindFirstChild('Lobby', true)
	if not lobby then return end
	local deckY = (V2.Origin * CFrame.new(SPAWN)).Y
	if v == 'B' then Look.openPlaza(lobby, deckY) elseif v == 'A' then Look.openRoof(lobby) end
	local pal = Look.Palettes[v] or {}
	local outside = lobby:FindFirstChild('Surroundings')
	local training = lobby:FindFirstChild('Training')
	for _, p in lobby:GetDescendants() do
		if p:IsA('BasePart') then
			local new = pal[key(p.Color)]
			if new then p.Color = new end
			if p.Material == M.Plastic then p.Material = M.SmoothPlastic end
			-- (B31 PLAZA, critic 7 and the user's "tone down" for the themed bays) big lane surfaces calm down, and a
			-- big neon face (a glowing backboard, a lip) turns into flat colour: glow only on small accents
			if v == 'P' and training and p:IsDescendantOf(training) and p.Transparency < 1 then
				local s = p.Size
				if math.max(s.X * s.Y, s.Y * s.Z, s.X * s.Z) >= 3 then p.Color = calm(p.Color, Look.BigS) end
				if p.Material == M.Neon and math.max(s.X, s.Y, s.Z) > 1.5 then p.Material = M.SmoothPlastic end
			end
			if Look.isStudded(p) then
				for _, f in FACES do p[f] = S.Smooth end
				local upright = p.CFrame.UpVector.Y > 0.99 and p:IsA('Part') and p.Shape == Enum.PartType.Block
				local top = p.CFrame.Position.Y + p.Size.Y / 2
				if outside and p:IsDescendantOf(outside) then
					if upright then Look.faintStuds(p, ALL) end
				elseif v == 'P' and Look.Layers[p.Name] then
					-- (critic 1: the ref's grass and walks show their studs plainly, a lit patch's spread 15-25; one layer of
					-- the faint bevel measured 3-7 in the renderer, so the plaza's ground stacks a few)
					for _ = 1, Look.Layers[p.Name] do Look.faintStuds(p, { Enum.NormalId.Top }) end
				elseif upright and top <= deckY + 2.6 and (v ~= 'P' or p.Size.Y <= 1.7) and p.Size.X >= 3 and p.Size.Z >= 3 then
					Look.faintStuds(p, { Enum.NormalId.Top }) -- (B31 PLAZA: walkable ground only: the grass, walks, decks, mats, pads)
				end
			elseif v == 'P' and p.Name == 'Wall' and p:IsA('Part') and p.Transparency < 0.05 then
				for _ = 1, Look.WallLayers do Look.faintStuds(p, ALL) end
			end
		end
	end
	-- outdoors the field is grass (variant B): the hall floor slab and the edge fill
	if v == 'B' then
		for _, p in lobby:GetDescendants() do
			if p:IsA('BasePart') and p.Name == 'Floor' and p.Parent and p.Parent.Name == 'Hall' then p.Color = Look.Grass end
		end
	end
	if Look.Classic then Look.classicStuds(lobby) end
	-- (B34, the Huss look: "objects don't have light only around them") every lamp in the lobby stays faint: a glow on
	-- its object, no pool on the floor, no shadows of its own
	for _, l in lobby:GetDescendants() do
		if l:IsA('PointLight') or l:IsA('SpotLight') or l:IsA('SurfaceLight') then
			l.Brightness, l.Range, l.Shadows = math.min(l.Brightness, 0.5), math.min(l.Range, 8), false
		end
	end
	Look.itemFX(lobby)
	lobby:SetAttribute('LookVariant', v)
end
-- (Oct 27 round 5, the owner: "make the studs less visible", both worlds) The one rule for everything the lobby pass
-- doesn't cover (the stages, the gates, the buildings, the props, the edges): Roblox's classic Studs surface comes off
-- every face (its strokes are high-contrast in the real client and can't be tuned), and the lobby's faint stud texture
-- goes on instead where a stud reads: SoftGroundLayers on the top of walkable ground (an upright block, top within 2.6 of
-- the deck, 3 x 3 or more), one fainter layer (SoftWallAlpha) on any other studded face of SoftFaceArea or more (a
-- building's wall, a tree's crown); small parts (trims, posts, props) turn smooth. Untouched: the owner's meshes (MeshParts), Neon, glass,
-- see-through parts and anything carrying words (a SurfaceGui).
Look.SoftGroundLayers = 1
Look.SoftFaceArea = 24
Look.SoftWallAlpha = 0.4 -- (the walls' and crowns' one layer, fainter than the ground's: a stud you notice only up close)
local NORMAL = { TopSurface = Enum.NormalId.Top, BottomSurface = Enum.NormalId.Bottom, FrontSurface = Enum.NormalId.Front,
	BackSurface = Enum.NormalId.Back, LeftSurface = Enum.NormalId.Left, RightSurface = Enum.NormalId.Right }
local function faceArea(s, f)
	if f == 'TopSurface' or f == 'BottomSurface' then return s.X * s.Z end
	if f == 'FrontSurface' or f == 'BackSurface' then return s.X * s.Y end
	return s.Y * s.Z
end
function Look.softStuds(root)
	local parts, textures = 0, 0
	for _, p in root:GetDescendants() do
		if p:IsA('BasePart') and not p:IsA('MeshPart') and Look.isStudded(p) then
			parts += 1
			local studded = {}
			for _, f in FACES do
				if p[f] == S.Studs then table.insert(studded, f) end
				p[f] = S.Smooth
			end
			if p.Material == M.Plastic then p.Material = M.SmoothPlastic end
			if p.Material ~= M.Neon and p.Material ~= M.Glass and p.Transparency < 0.05 and not p:FindFirstChildOfClass('SurfaceGui') then
				local block = p:IsA('Part') and p.Shape == Enum.PartType.Block
				local ground = block and p.CFrame.UpVector.Y > 0.99 and p.Size.X >= 3 and p.Size.Z >= 3
					and V2.Origin:PointToObjectSpace(p.CFrame.Position).Y + p.Size.Y / 2 <= 2.6
				for _, f in studded do
					local onGround = ground and f == 'TopSurface'
					local layers = onGround and Look.SoftGroundLayers or ((block and faceArea(p.Size, f) >= Look.SoftFaceArea) and 1 or 0)
					for _ = 1, layers do Look.faintStuds(p, { NORMAL[f] }, not onGround and Look.SoftWallAlpha or nil); textures += 1 end
				end
			end
		end
	end
	root:SetAttribute('SoftStudParts', parts)
	root:SetAttribute('SoftStudTextures', textures)
end
V2.Look = Look
V2.Stations = Stations
---------------------------------------------------------------------------------------------- the hall's studs (World 2)
-- (Oct 27, the owner's "C": the Oct 10 hall shows its studs on the walls, pillars and bands) After the look pass
-- (x_look: faint studs on the walkable ground and the 'Wall' parts), the hall's other studded shell parts take the same
-- faint stud texture on every face: the pillars, the wall bands, the exit bay's frames, the sills, the light bars.
local lookApply = Look.apply
City.HallStudNames = { '^Pillar', '^WallBase$', '^WallBand$', '^ExitFrame$', '^ExitPanelFrame$', '^WindowSill$', '^RoofLampBar$' }
function Look.apply(root)
	lookApply(root)
	local lobby = root:FindFirstChild('Lobby', true)
	local hall = lobby and lobby:FindFirstChild('Hall')
	local roof = lobby and lobby:FindFirstChild('Roof')
	for _, g in { hall, roof } do
		for _, p in g and g:GetDescendants() or {} do
			if p:IsA('BasePart') and p.Material ~= M.Neon and p.Transparency < 0.05 then
				for _, pat in City.HallStudNames do
					if p.Name:find(pat) then
						Look.faintStuds(p, { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right })
						break
					end
				end
			end
		end
	end
end
---------------------------------------------------------------------------------------------- z-fighting
-- (P3, BRIEF29, the user: "fix the studs appearing and disappearing, make it all the same, also remove the overlays between
-- objects") Two blocks whose faces lie in the same plane, look the same way and overlap flicker against each other (and a
-- studded face flickers its studs). The builders stack parts freely (a wall piece butting into a pillar, a neon strip laid on a
-- channel, a trim over a body), so one pass after the build finds every such pair among the axis-aligned visible blocks and
-- lifts the smaller part's face out by 0.03 (twice that over a third part), so exactly one surface wins: the detail
-- over the body, never the reverse. Faces looking down are never seen and are left alone; a transparent part is not a surface.
local FIGHT_STEP, FIGHT_MIN = 0.03, 0.05
local function resolveCoplanar(root)
	local faces, byKey, parts = {}, {}, {}
	local order = 0
	local function key(a, d, plane) return a * 4 + d + 1, math.floor(plane * 100 + 0.5) end
	for _, p in root:GetDescendants() do
		if p.ClassName == 'Part' and p.Shape == Enum.PartType.Block and p.Transparency < 0.9 then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local R = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } }
			local aligned = true
			for _, row in R do
				for _, v in row do
					local m = math.abs(v)
					if m > 0.001 and m < 0.999 then aligned = false end
				end
			end
			if aligned then
				local sz = p.Size
				local S = { sz.X, sz.Y, sz.Z }
				local c = { x, y, z }
				local h = {}
				local local_of = {}
				for a = 1, 3 do
					h[a] = (math.abs(R[a][1]) * S[1] + math.abs(R[a][2]) * S[2] + math.abs(R[a][3]) * S[3]) / 2
					for i = 1, 3 do if math.abs(R[a][i]) > 0.5 then local_of[a] = i end end
				end
				local vol = S[1] * S[2] * S[3]
				order += 1
				parts[p] = { vol = vol, local_of = local_of, idx = order }
				for a = 1, 3 do
					local o1, o2 = a % 3 + 1, (a + 1) % 3 + 1
					for _, d in { 1, -1 } do
						local plane = c[a] + d * h[a]
						if not (a == 2 and d == -1) then
							local f = { p = p, a = a, d = d, plane = plane, lo1 = c[o1] - h[o1], hi1 = c[o1] + h[o1], lo2 = c[o2] - h[o2], hi2 = c[o2] + h[o2], vol = vol }
							table.insert(faces, f)
							local kk, kp = key(a, d, plane)
							byKey[kk] = byKey[kk] or {}
							byKey[kk][kp] = byKey[kk][kp] or {}
							table.insert(byKey[kk][kp], f)
						end
					end
				end
			end
		end
	end
	-- the overlapping coplanar pairs: (a, d, plane +- 0.01) buckets, the smaller part lifts over the bigger
	local pairsList = {}
	for _, f in faces do
		local kk, kp = key(f.a, f.d, f.plane)
		for dk = -1, 1 do
			for _, g in (byKey[kk] and byKey[kk][kp + dk]) or {} do
				if g.p ~= f.p and f.vol > g.vol + 1e-6 then
					if math.abs(f.plane - g.plane) < 0.011 then
						local w = math.min(f.hi1, g.hi1) - math.max(f.lo1, g.lo1)
						local h = math.min(f.hi2, g.hi2) - math.max(f.lo2, g.lo2)
						if w > FIGHT_MIN and h > FIGHT_MIN then table.insert(pairsList, { big = f, small = g }) end
					end
				end
			end
		end
	end
	-- equal volumes: the pair is seen from both sides above and kept once (f.vol > g.vol is strict), so equals are lifted below
	for _, f in faces do
		local kk, kp = key(f.a, f.d, f.plane)
		for dk = -1, 1 do
			for _, g in (byKey[kk] and byKey[kk][kp + dk]) or {} do
				if g.p ~= f.p and math.abs(f.vol - g.vol) < 1e-6 and parts[f.p].idx < parts[g.p].idx and math.abs(f.plane - g.plane) < 0.011 then
					local w = math.min(f.hi1, g.hi1) - math.max(f.lo1, g.lo1)
					local h = math.min(f.hi2, g.hi2) - math.max(f.lo2, g.lo2)
					if w > FIGHT_MIN and h > FIGHT_MIN then table.insert(pairsList, { big = f, small = g }) end
				end
			end
		end
	end
	table.sort(pairsList, function(a, b) return a.big.vol > b.big.vol end)
	local lift = {} -- [face] = how far this face lifts
	for _ = 1, 4 do
		local changed = false
		for _, pr in pairsList do
			local need = (lift[pr.big] or 0) + FIGHT_STEP
			if (lift[pr.small] or 0) < need then lift[pr.small] = need changed = true end
		end
		if not changed then break end
	end
	local count = 0
	for f, amount in lift do
		local info = parts[f.p]
		local i = info.local_of[f.a]
		if i then
			local sz = f.p.Size
			local comp = { sz.X, sz.Y, sz.Z }
			comp[i] += amount
			local shift = Vector3.zero
			if f.a == 1 then shift = Vector3.new(f.d * amount / 2, 0, 0) elseif f.a == 2 then shift = Vector3.new(0, f.d * amount / 2, 0) else shift = Vector3.new(0, 0, f.d * amount / 2) end
			f.p.Size = Vector3.new(comp[1], comp[2], comp[3])
			f.p.CFrame = f.p.CFrame + shift
			count += 1
		end
	end
	return count, #pairsList
end
V2.ResolveCoplanar = resolveCoplanar

---------------------------------------------------------------------------------------------- build
-- The warehouse lobby's builder; V2.Lobby.Slots (name -> CFrame in the map frame) is filled by Build.
V2.Lobby = Lobby
function V2.Build()
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	SKINS = skins
	Props = require(game:GetService('ServerStorage').HoodProps)
	PROPS_KIT = { studs = studs, decor = decor, ghost = ghost, light = light, surface = surface, line = line, billboard = billboard, compact = compact, FONT = FONT }

	local old = workspace:FindFirstChild(V2.Name)
	if old then
		local backup = Instance.new('Folder')
		backup.Name = V2.Name .. '_Before_' .. os.date('!%Y%m%d_%H%M%S')
		backup.Parent = game:GetService('ServerStorage')
		old.Parent = backup
	end
	local root = Instance.new('Model')
	root.Name = V2.Name
	-- (World 2's city: 2; World 1 leaves it unset.) The workspace carries it too: that's what Shared/WorldInfo reads, and
	-- it saves with the place, so World 2's place knows its world from the first server.
	if V2.World then root:SetAttribute('HoodWorld', V2.World); workspace:SetAttribute('HoodWorld', V2.World) end
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 LOBBY6 VIP lanes, full armory side')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', Lobby.SpawnAt or SPAWN) -- (B31 PLAZA: on the south walk, the crossing just ahead)
	root:SetAttribute('LobbySpawnYaw', 0) -- facing north up the spine to the Stage 1 door (StageService's Lobby pads land you so)
	root:SetAttribute('MorphStand', false) -- no Morphs stands in the world any more: looks are equipped from the HUD's EVOLVE menu
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	Look.apply(root) -- (B31 LOOK) the toy-plastic finish over the lobby: faint studs on the ground only, warm palette
	buildStages(ctx)
	if Waves then Waves.build(ctx) end -- each stage's target wave (f3_waves, MECHANICS)

	local lifted, fights = resolveCoplanar(root)
	for _ = 1, 2 do lifted += resolveCoplanar(root) end -- (a lift can land on a third part's plane: more passes settle the chains)
	root:SetAttribute('FaceFightsLifted', lifted)
	Look.softStuds(root) -- (Oct 27 round 5) the faint studs outside the lobby too, both worlds (x_look)
	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint(V2.Name .. ' built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply(Look.Lighting[Look.Variant] or 'HoodSun') end) -- (B31: HoodToy, a real sun with shadows)
	V2.SetActive(true)
	print(string.format('[%s] Built %d parts at %s. Press Play to spawn in the %s; select %s and press F to fly there.', V2.Name, count, tostring(V2.Origin.Position), V2.Where or 'hood', V2.Name))
	return { parts = count }
end

return V2
