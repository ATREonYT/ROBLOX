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
	-- The stage street, sampled from ref1_street.png (lit faces; every surface studded like the picture), then
	-- raised so a HoodSoft render of each surface reads the picture's RGB (renders came out 10-25% darker).
	st = {
		road = C(63, 81, 112), dash = C(255, 243, 50), walk = C(153, 167, 195), grass = C(39, 187, 98),
		brick = C(182, 118, 108), trim = C(190, 174, 170), band = C(128, 148, 182), roof = C(102, 136, 180),
		glassA = C(124, 154, 193), glassB = C(190, 210, 230), mullion = C(48, 78, 126),
		fence = { C(229, 122, 63), C(143, 79, 71), C(192, 100, 64), C(143, 79, 71) }, -- light, dark, mid, dark
		lamp = C(34, 62, 100), lampGlow = C(255, 244, 196),
		leaf = C(42, 190, 64), trunk = C(97, 90, 103), hedge = C(30, 172, 74), dumpster = C(26, 165, 90),
		petal = C(30, 70, 156), petalEye = C(250, 232, 70), stem = C(40, 180, 82), garbage = C(230, 130, 46),
	},
	-- Its cross-section, measured from the picture (studs from the centre line, heights from the road top):
	-- road |x| < road, sidewalk to road + walk (top at kerb), grass to front, the plank fence at fence, building
	-- fronts at front; the last SLEN - endZ studs of each stage narrow to |x| = open, framing the next gate's wall.
	street = { road = 8.5, walk = 8, kerb = 0.6, front = 36, open = 22, fence = 34.5, endZ = 56, eave = 30, band = 15, sills = { 4, 19 }, winH = 8.5 },
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
local WALL_X = 124 -- the low boundary wall (wide enough to go round the lobby hall, x +-121)
local SLEN = 64 -- one stage
local STAGES = 15
local SPAWN_W, SPAWN_TOP = 121, 187 -- the lobby hall's outside walls: x -121..121, z 5..187 (Lobby, e2_lobby)
local BOSS_TOP = -STAGES * SLEN -- -960
local BOSS_END = BOSS_TOP - 96 -- the boss yard runs to -1056
local SPAWN = V(0, 0, 87) -- the spawn on the hall's cross, where the walkways meet (on the floor)
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

-- The reference street's props (ref1_street.png): chunky blocks, studded on every face, sized from the picture.
-- A studded box between two corners (the street kit's only brick).
local function sbox(c, name, a, b, color, isDecor)
	local p = studs(c:box(name, a, b, color, M.Plastic), true)
	if isDecor then decor(p) end
	return p
end
-- Tree of stacked green cubes on a short grey trunk, measured from the picture (top ~15.8 above the grass, crown
-- ~7 wide and ~12 tall, trunk ~3 wide and ~3.8 tall): three tiers that step in and wander a little, a cap and a
-- thin side block. seed varies it; yaw (degrees) turns it (the picture's trees stand at an angle to the street).
local function tree(c, pos, seed, scale, yaw)
	local r = Random.new(seed)
	local s = scale or 1
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or r:NextInteger(0, 3) * 90), 0)):group('Tree')
	local leaf = P.st.leaf
	local function B(name, a, b, col) return sbox(t, name, a * s, b * s, col) end
	local function off() return r:NextInteger(-1, 1) * 0.5 end
	B('Trunk', V(-1.5, 0, -1.5), V(1.5, 3.8, 1.5), P.st.trunk)
	B('Crown', V(-3.5, 3.8, -3.5), V(3.5, 8.6, 3.5), leaf)
	local x2, z2 = off(), off()
	B('Crown', V(-3 + x2, 8.6, -3 + z2), V(3 + x2, 12.4, 3 + z2), leaf)
	local x3, z3 = x2 + off(), z2 + off()
	B('Crown', V(-2.2 + x3, 12.4, -2.2 + z3), V(2.2 + x3, 14.8, 2.2 + z3), leaf)
	B('CrownTop', V(-1.3 + x3, 14.8, -1.3 + z3), V(1.3 + x3, 15.8, 1.3 + z3), leaf)
	B('CrownSide', V(3.5, 6.6, -1.5), V(4.3, 10.6, 1.5), leaf:Lerp(P.black, 0.1))
	return t
end
-- Low hedge of two stacked green blocks (the ones on the reference's grass), long along Z.
local function hedge(c, pos, len)
	len = len or 6
	local h = c:at(CFrame.new(pos)):group('Hedge')
	sbox(h, 'Hedge', V(-1.6, 0, -len / 2), V(1.6, 2.2, len / 2), P.st.hedge)
	sbox(h, 'Hedge', V(-1.2, 2.2, -len / 2), V(1.2, 3.8, len / 2 - 2), P.st.hedge:Lerp(P.st.leaf, 0.5))
	return h
end
-- Wooden plank fence along Z at x from z0 to z1 (the picture's front-yard fence, ~8 tall): 2-stud planks, 1 thick,
-- alternating light / dark wood (the light ones in two tones), every other plank stepped toward the street (side = the
-- street's direction, +1 or -1), each capped with a steep wedge that slopes down toward the street, heights jittered.
local function fence(c, x, z0, z1, side, h)
	h = h or 6.8
	local f = c:group('Fence')
	local n = math.max(1, math.floor(math.abs(z1 - z0) / 2 + 0.5))
	local w = (z1 - z0) / n
	for k = 0, n - 1 do
		local za, zb = z0 + k * w, z0 + (k + 1) * w
		local col = P.st.fence[k % #P.st.fence + 1]
		local xm = x + (k % 2 == 1 and side * 0.5 or 0)
		local hk = h + ((k * 7) % 3 - 1) * 0.4
		sbox(f, 'FencePlank', V(xm - 0.5, 0, za), V(xm + 0.5, hk, zb), col)
		-- (a wedge rises toward its local +Z: turn that away from the street)
		studs(f:wedge('FencePlankTop', V(math.abs(w), 1.8, 1), CFrame.new(xm, hk + 0.9, (za + zb) / 2) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0), col, M.Plastic), true)
	end
	return f
end
-- Tall street lamp (~27 studs): a studded navy base block, a square pole, a cap, and a 1-stud arm out over the
-- sidewalk (a rising strut, then level) ending in a small head with a thin warm light under its tip. dir points at
-- the road.
local function lantern(c, pos, dir)
	dir = dir or V(1, 0, 0)
	local l = c:at(CFrame.lookAt(pos, pos - dir)):group('Lamp') -- (lookAt's -Z points away from the road: the arm runs along local +Z)
	local col = P.st.lamp
	sbox(l, 'LampBase', V(-1.8, 0, -1.8), V(1.8, 2.2, 1.8), col)
	sbox(l, 'LampPole', V(-0.9, 2.2, -0.9), V(0.9, 26.4, 0.9), col)
	sbox(l, 'LampCap', V(-1.1, 26.4, -1.1), V(1.1, 27.4, 1.1), col)
	studs(decor(l:bar('LampStrut', V(0, 22.4, 0.6), V(0, 25.2, 4), 1, col, M.Plastic)), true)
	sbox(l, 'LampArm', V(-0.5, 24.7, 3.4), V(0.5, 25.7, 10.4), col, true)
	sbox(l, 'LampHead', V(-0.8, 24.3, 7.6), V(0.8, 25.7, 10.8), col, true)
	decor(l:box('LampGlow', V(-0.5, 24.1, 9.0), V(0.5, 24.3, 10.6), P.st.lampGlow, M.Neon)).CastShadow = false
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
-- The reference's big green dumpster (8 long along Z, 5 deep, 6 tall), studded, a darker rim, rubbish heaped over
-- it in small orange, brown and dark bits, and its lid flung open from the back (+X) edge, leaning out over the
-- street side. The front, the street side, faces local -X.
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local col = P.st.dumpster
	sbox(d, 'DumpsterBody', V(-2.5, 0.5, -4), V(2.5, 5.6, 4), col)
	sbox(d, 'DumpsterRim', V(-2.8, 5.2, -4.3), V(2.8, 6.0, 4.3), col:Lerp(P.black, 0.12), true)
	for _, z in { -3.2, 3.2 } do sbox(d, 'DumpsterFoot', V(-2.2, 0, z - 0.6), V(2.2, 0.5, z + 0.6), P.black:Lerp(col, 0.3)) end
	decor(d:box('DumpsterInside', V(-2.3, 5.5, -3.8), V(2.3, 5.9, 3.8), C(52, 44, 40), M.Plastic))
	local r = Random.new(7)
	local bits = { P.st.garbage, P.st.garbage, C(120, 76, 46), C(60, 56, 54), C(250, 170, 60) }
	for k = 1, 14 do
		local x, z, sz = r:NextNumber(-1.9, 1.6), r:NextNumber(-3.3, 3.0), r:NextNumber(0.6, 1.1)
		decor(d:box('Rubbish', V(x, 5.8, z), V(x + sz, 5.9 + r:NextNumber(0.3, 0.9), z + sz), bits[k % #bits + 1], M.Plastic)).CastShadow = false
	end
	-- the lid, hinged on the back top edge, leaning ~25 degrees past upright toward the street
	local lid = d:at(CFrame.new(2.8, 6.0, 0) * CFrame.Angles(0, 0, math.rad(-65)))
	sbox(lid, 'DumpsterLid', V(-5.4, 0, -4.3), V(0, 0.5, 4.3), col, true)
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

-- Teleport pad, as on the reference street: one flat neon slab with a prompt (StageService handles targets 'Lobby' and
-- 'Furthest'). opts: w, d (size; default 7 x 4), y (the floor it sits on), h (thickness), material (default Neon),
-- base (colour of a thin dark plate under it, showing as a rim), bare (no floating label).
local function teleportPad(g, name, x, z, color, target, label, opts)
	opts = opts or {}
	local w, d, y, h = opts.w or 7, opts.d or 4, opts.y or 0, opts.h or 0.42
	if opts.base then
		decor(g:box(name .. 'Base', V(x - w / 2 - 0.3, y, z - d / 2 - 0.3), V(x + w / 2 + 0.3, y + 0.15, z + d / 2 + 0.3), opts.base, M.SmoothPlastic))
		y += 0.15
	end
	local pad = g:box(name, V(x - w / 2, y, z - d / 2), V(x + w / 2, y + h, z + d / 2), color, opts.material or M.Neon)
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
	if not opts.bare then billboard(g, V(x, y + 3.2, z), 6, 1.4, { { 'Title', label, P.white, FONT.title, 0, 1 } }).WorldLabel.MaxDistance = 50 end
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
-- The ARMORY, after the user's item-shop reference (brief/ref_armory.png), run like the soldier game's gun stand
-- (brief/video1/notes.md section 4): the gun ladder as big guns floating in profile over big glowing hexagonal pads,
-- two rows stepping up toward the back. Guns 1-5 stand on the front deck (a light studded plinth with a dark studded
-- step along its front), guns 6-10 on a raised studded terrace behind it, reached by a stair at each end; a back wall
-- with a raised centre and corner posts closes it. Built like a shop wall: every gun has a framed display bay behind
-- it (a light studded pegboard panel set back in a frame, a roller-shutter box over it, a sill), bays parted by
-- pilasters with bases and caps; finished edges everywhere (light nosings and copings on top edges, dark kick bands at
-- the foot, a dark band under every cap). A till and a stack of gun cases stand on the terrace's ends.
-- Each pad is layered: a dark plinth, a pale body with a state-coloured line round it, a light bevelled lip, and the
-- face (a dark rim, the glowing state colour, a light core); a plate on its front says LOCKED / BUY / OWNED /
-- EQUIPPED. Step onto the pad's front half for the Buy / Equip prompt. Over each gun a three-line nameplate: the
-- name, a big "xN Power", the price (red locked, yellow BUY) or the state (OWNED blue, EQUIPPED green).
-- Neon only on the pad faces; saturated colour only on the pads, the guns and their nameplates.
-- State colours (GunRules.Colors; Armory.client repaints): pink locked, blue owned, green equipped.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun with attributes GunId, Tier,
-- Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part on the pad's front half: prompt anchor and buy-distance point
--   StateTop           parts in the state colour (the pad face and its side line)
--   StateGlow          the face's light core, with the pad's PointLight under it
--   StateShade         the face's dark rim (the state's dark tone)
--   StateStrip         the front plate, with SurfaceGui > TextLabel State; StateHaze (ParticleEmitter)
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Bob) with the gun inside, horizontal, in profile to the hall
-- The Armory model is tagged HoodArmory; each slot streams Atomic.
-- Local frame: origin at the centre of the front step's foot on the hall floor, front faces -Z (players stand
-- at -Z looking +Z), footprint x -29.4..29.4, z 0..31.2 (Armory.HalfWidth, Armory.Depth), at most 20 tall.
local Armory = {}

Armory.HalfWidth, Armory.Depth = 29.4, 31.2
Armory.Floor = 1.6 -- front deck top (one 0.8 step up from the hall floor)
Armory.Step = 9.2 -- back terrace top: a step about the front row's height, like the reference's stepped back wall
Armory.TerraceZ = 17.4 -- where the terrace's front wall stands
Armory.Rows = { { z = 10.2, y = 1.6, label = 1.1, scale = 1 }, { z = 24.6, y = 9.2, label = 1.4, scale = 1.15 } }
Armory.Spacing = 10.3
Armory.Radius = 3.9 -- pad apothem (centre to a flat side); flats face -Z
Armory.PadHeight = 0.95
Armory.MaxLength = 7.2
Armory.Tilt = 17 -- degrees the muzzle points up
Armory.DisplayH = 5.0 -- the tallest a tilted gun may stand (taller ones are scaled down; nameplates sit over it)
Armory.Bob, Armory.BobPeriod = 0.35, 2.6
Armory.StairW = 4.4 -- the stairs at each end, x +-(25..29.4)
Armory.BackWall = 6.6 -- the terrace's back wall, above the terrace top
Armory.BayW = 8 -- display bay width (pilasters stand between bays)
-- Tones, two or three per surface: a lit body, a darker band at the foot and under every cap, a light trim on
-- every top edge. From ref_armory.png (deck 195,195,213 lit; its lip 101,112,145 and the terrace wall 118,111,134
-- in shade), a touch lighter so the renderer's shade lands on them.
Armory.Tone = {
	deck = C(204, 205, 218), tread = C(210, 211, 224), trim = C(226, 227, 238), face = C(104, 110, 148),
	kick = C(78, 82, 116), riser = C(132, 134, 168), wall = C(128, 124, 160), band = C(96, 94, 132),
	pilaster = C(176, 176, 200), pad = C(206, 208, 226), padLip = C(236, 237, 246), plinth = C(98, 102, 140),
	frame = C(206, 207, 224), panel = C(190, 192, 212), bolt = C(150, 154, 184),
	case = C(58, 62, 80), caseRim = C(132, 136, 156), metal = C(176, 180, 196), crate = C(70, 104, 160),
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

-- Hexagonal plinth: three boxes turned 60 degrees apart (flat sides face +-Z), each width 2r*tan(30).
function Armory.hex(c, name, x, z, r, y0, y1, color, material)
	local w = 2 * r * math.tan(math.pi / 6)
	local parts = {}
	for k = 0, 2 do
		table.insert(parts, c:part(name, V(w, y1 - y0, 2 * r), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 3, 0), color, material))
	end
	return parts
end

-- A chamfer round a hexagon's top edge: six wedges, each sloping from the inner ring (y1, r - w) down to the
-- outer edge (y0, r), so the pad's rim reads bevelled and catches the light on one side.
function Armory.bevel(c, name, x, z, r, w, y0, y1, color)
	local side = 2 * r * math.tan(math.pi / 6)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local out = V(math.sin(a), 0, -math.cos(a))
		local mid = V(x, (y0 + y1) / 2, z) + out * (r - w / 2)
		-- (a wedge's low side is its -Z: face it outward)
		c:wedge(name, V(side, y1 - y0, w), CFrame.lookAt(mid, mid + out), color, M.SmoothPlastic)
	end
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
-- pad. Small guns are blown up more than big ones (display length ~ natural length^0.5), so a pistol is about 4.8
-- studs and the long guns about 7, and each tier gets 3% more on top, up to 7.2 studs (the item is the hero of its
-- pad, as in the reference).
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
	local length = math.min(Armory.MaxLength, 3.9 * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
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

-- The nameplate over a gun: one floating-text system, three lines, read like the reference's nameplates and the
-- soldier game's stand:
--   Name        the gun's name in its colour
--   Multiplier  big: "xN Power" with the Power icon
--   Price       the price with the Cash icon, or the state: EQUIPPED (green), OWNED (blue), BUY + price (yellow,
--               a locked gun you can afford), the price in red while it is locked (Armory.client repaints it)
-- Icons come from IconModels.Images when uploaded, else a text glyph kept in the label's Glyph attribute. Readable
-- from 30 studs, shown up to 80, so the whole shop reads from the hall walkway.
function Armory.label(c, pos, gun, state, colors)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	-- as wide as the name needs, so every name (even Diamond Cannon) fills its row's full height: one name size
	g.Size = UDim2.fromScale(math.max(6.4, 0.52 * #gun.Name), 2.9)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Parent = anchor
	local ink = C(24, 22, 40)
	local look = colors[state] or {}
	-- (a grey gun's name would fade on the pale hall: it gets a rust orange instead)
	local _, sat = gun.Color:ToHSV()
	local nameColor = sat < 0.25 and C(240, 150, 90) or gun.Color:Lerp(P.white, 0.1)
	line(g, 'Name', gun.Name, nameColor, FONT.loud, 0, 0.3, ink, 3)
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y, h)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.loud, y, h, ink, 3)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = name == 'Price' and 'PriceIcon' or 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.22, y)
			i.Size = UDim2.fromScale(0.14, h)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.37, y)
			t.Size = UDim2.fromScale(0.6, h)
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
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier .. ' Power', P.white, 0.3, 0.4)
	local price = row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), look.Word or C(255, 228, 92), 0.72, 0.28)
	if state == 'Equipped' or state == 'Owned' then price.Text = string.upper(state) end
	return anchor
end

-- A display bay on a wall whose face is at z = zf (facing -Z), centred on x, from y0 to y1: a studded pegboard
-- panel in a light neutral grey (the dark guns stand out on it; saturated colour stays on the pads) set back inside
-- a light frame (two jambs, a roller-shutter box over it, a deeper sill), so every gun has its own backdrop.
function Armory.bay(c, x, zf, y0, y1)
	local T, w = Armory.Tone, Armory.BayW / 2
	studs(c:box('BayPanel', V(x - w + 0.4, y0 + 0.3, zf - 0.12), V(x + w - 0.4, y1 - 0.5, zf), T.panel, M.Plastic))
	c:box('BayPanelBand', V(x - w + 0.4, y0 + 0.3, zf - 0.16), V(x + w - 0.4, y0 + 0.9, zf - 0.12), T.band, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		c:box('BayJamb', V(x + sx * w, y0, zf - 0.5), V(x + sx * (w - 0.45), y1, zf), T.frame, M.SmoothPlastic)
	end
	c:box('BaySill', V(x - w - 0.15, y0 - 0.1, zf - 0.75), V(x + w + 0.15, y0 + 0.32, zf), T.trim, M.SmoothPlastic)
	-- a roller-shutter box over the bay, the shutter drawn a little way down (a corner-store touch): a light housing
	-- with a dark lip, the ribbed shutter under it
	c:box('ShutterBox', V(x - w - 0.15, y1 - 0.75, zf - 1.0), V(x + w + 0.15, y1, zf), T.trim, M.SmoothPlastic)
	c:box('ShutterLip', V(x - w - 0.15, y1 - 0.95, zf - 1.05), V(x + w + 0.15, y1 - 0.75, zf - 0.6), T.band, M.SmoothPlastic)
	c:box('Shutter', V(x - w + 0.45, y1 - 1.75, zf - 0.4), V(x + w - 0.45, y1 - 0.75, zf - 0.25), T.riser, M.SmoothPlastic)
	for k = 1, 2 do
		c:box('ShutterRib', V(x - w + 0.45, y1 - 0.75 - k * 0.34, zf - 0.47), V(x + w - 0.45, y1 - 0.69 - k * 0.34, zf - 0.25), T.band, M.SmoothPlastic)
	end
end

-- A pilaster on a wall face at z = zf (facing -Z): a dark base, a light shaft, a light cap.
function Armory.pilaster(c, x, zf, y0, y1, w)
	local T = Armory.Tone
	w = w or 1.3
	c:box('Pilaster', V(x - w / 2, y0, zf - 0.45), V(x + w / 2, y1, zf), T.pilaster, M.SmoothPlastic)
	c:box('PilasterBase', V(x - w / 2 - 0.2, y0, zf - 0.7), V(x + w / 2 + 0.2, y0 + 0.7, zf), T.kick, M.SmoothPlastic)
	c:box('PilasterCap', V(x - w / 2 - 0.2, y1 - 0.45, zf - 0.7), V(x + w / 2 + 0.2, y1, zf), T.trim, M.SmoothPlastic)
end

-- One gun on its pad. (x, z) is the pad centre, y the deck it stands on, wall the z of the wall face behind it.
function Armory.slot(c, gun, x, z, y, colors, lift, scale, wall)
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
	local r, ph = Armory.Radius, Armory.PadHeight
	-- The pad, bottom up: a dark plinth, the pale body with a state-coloured line round it, a light lip bevelled at
	-- its edge, and the face: a dark rim, the glowing state colour, a light core carrying the pad's light. Neon only
	-- on the face.
	Armory.hex(s, 'PadPlinth', x, z, r + 0.3, y, y + 0.3, T.plinth, M.SmoothPlastic)
	Armory.hex(s, 'PadBase', x, z, r, y + 0.3, y + ph - 0.3, T.pad, M.SmoothPlastic)
	for _, p in Armory.hex(s, 'StateTop', x, z, r + 0.04, y + 0.42, y + 0.54, look.Top, M.SmoothPlastic) do decor(p).CastShadow = false end
	Armory.hex(s, 'PadLip', x, z, r - 0.55, y + ph - 0.3, y + ph, T.padLip, M.SmoothPlastic)
	Armory.bevel(s, 'PadBevel', x, z, r, 0.55, y + ph - 0.3, y + ph, T.padLip)
	local top = y + ph
	for _, p in Armory.hex(s, 'StateShade', x, z, r - 0.75, top, top + 0.04, Armory.shade(look), M.SmoothPlastic) do decor(p).CastShadow = false end
	for _, p in Armory.hex(s, 'StateTop', x, z, r - 1.0, top, top + 0.07, look.Top, M.Neon) do decor(p).CastShadow = false end
	local core = Armory.hex(s, 'StateGlow', x, z, r - 2.8, top, top + 0.09, look.Glow, M.Neon)
	for _, p in core do decor(p).CastShadow = false end
	-- the face's glow on the deck round the pad (Armory.client recolours it with the face)
	light(core[1], look.Top, 2, 11)
	top += 0.09
	-- Soft haze rising off the face in the state colour, the reference's faint light column over each pad (the client
	-- recolours it with the pad).
	local hazeSource = ghost(s:part('StateHazeSource', V(r * 1.3, 0.2, r * 1.3), CFrame.new(x, top + 0.1, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 2.4
	haze.Lifetime = NumberRange.new(1.4, 2)
	haze.Speed = NumberRange.new(1, 1.6)
	haze.SpreadAngle = Vector2.new(6, 6)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 3.6) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.86), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	-- The plate on the pad's front: a chunky block standing on the plinth, with a light cap and two bolts.
	local strip = s:box('StateStrip', V(x - 1.95, y + 0.3, z - r - 0.3), V(x + 1.95, y + ph - 0.12, z - r + 0.05), look.Strip, M.SmoothPlastic)
	s:box('PlateCap', V(x - 2.05, y + ph - 0.12, z - r - 0.36), V(x + 2.05, y + ph, z - r + 0.05), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		s:part('PlateBolt', V(0.08, 0.2, 0.2), CFrame.new(x + sx * 1.72, y + 0.62, z - r - 0.32) * CFrame.Angles(0, math.pi / 2, 0), T.bolt, M.Metal, Enum.PartType.Cylinder)
	end
	local sg = surface(strip, Enum.NormalId.Front, 50)
	sg.Name = 'StateGui'
	line(sg, 'State', string.upper(state), P.white, FONT.loud, 0.06, 0.88, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun floating over the pad in profile to the hall (muzzle to the viewer's right), tilted up a little,
	-- bobbing; never turning, so it is never seen end-on.
	local d, display = s:group('Display')
	local tilt = math.rad(Armory.Tilt)
	local function measure(m)
		local lo, hi = Armory.extents(m, Armory.pivotOf(m))
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
	local centre = V(x, top + 1.0 + tall / 2, z + 0.7)
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
	Armory.label(s, V(x, y + ph + 1.0 + Armory.DisplayH * k + (lift or 0.8) + 0.3, z), gun, state, colors)
	-- The display bay on the wall behind the gun: the front row's on the terrace wall (under its nameplate, which
	-- sits on the wall's studded band), the back row's on the back wall.
	if wall then
		local front = y < Armory.Step - 1
		Armory.bay(s, x, wall, y + 0.75, front and Armory.Step - 1.3 or y + Armory.BackWall - 1.4)
	end
	-- Where the prompt sits and the server measures buying distance from: on the pad's front half, so stepping onto
	-- the pad (in front of the floating gun) brings up Buy / Equip, like the soldier game's stand.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.6, top + 0.2, z - 2.6), V(x + 0.6, top + 1.6, z - 1.4), P.white))
	point.CastShadow = false
	return model
end

-- The deck: a step along the front, the studded front deck, the raised studded terrace behind it with its back
-- wall, a stair up at each end. Every surface in two or three tones: light nosings on the top edges, dark kick
-- bands at the foot, a dark band under every cap; pilasters part the display bays.
function Armory.base(c)
	local b = c:group('ArmoryBase')
	local T = Armory.Tone
	local X, Dp, F, H, TZ, SW = Armory.HalfWidth, Armory.Depth, Armory.Floor, Armory.Step, Armory.TerraceZ, Armory.StairW
	local BW = Armory.BackWall
	-- the front step and the deck, with their finished front edges
	studs(b:box('ArmoryStep', V(-X, 0, 0), V(X, F / 2, 1.2), T.face, M.Plastic), true)
	b:box('StepKick', V(-X - 0.06, 0, -0.06), V(X + 0.06, 0.24, 1.2), T.kick, M.SmoothPlastic)
	b:box('StepNosing', V(-X - 0.04, F / 2 - 0.18, -0.08), V(X + 0.04, F / 2 + 0.02, 0.35), T.riser, M.SmoothPlastic)
	studs(b:box('ArmoryFloor', V(-X, 0, 1.2), V(X, F, TZ), T.deck, M.Plastic))
	b:box('DeckFace', V(-X - 0.06, F / 2, 1.14), V(X + 0.06, F - 0.2, 1.2), T.face, M.SmoothPlastic)
	b:box('DeckNosing', V(-X - 0.06, F - 0.2, 1.08), V(X + 0.06, F + 0.02, 1.55), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		-- the deck's ends: a dark face and a light nosing too
		b:box('DeckFace', V(sx * X, 0.24, 0), V(sx * (X + 0.06), F - 0.2, TZ), T.face, M.SmoothPlastic)
		b:box('DeckKick', V(sx * X, 0, 0), V(sx * (X + 0.08), 0.24, Dp), T.kick, M.SmoothPlastic)
	end
	-- the terrace: studded wall body, a studded top, a dark skirting and a dark band under a light coping on its
	-- front wall, the same round its ends
	studs(b:box('ArmoryTerrace', V(-X, 0, TZ), V(X, H, Dp), T.wall, M.Plastic), true)
	studs(b:box('ArmoryTerraceTop', V(-X, H - 0.05, TZ), V(X, H, Dp), T.deck, M.Plastic))
	local x0, x1 = -X + SW, X - SW
	b:box('WallKick', V(x0, F, TZ - 0.14), V(x1, F + 0.55, TZ), T.kick, M.SmoothPlastic)
	b:box('WallBand', V(x0, H - 1.15, TZ - 0.12), V(x1, H - 0.35, TZ), T.band, M.SmoothPlastic)
	b:box('WallCap', V(-X - 0.1, H - 0.35, TZ - 0.45), V(X + 0.1, H + 0.03, TZ + 0.5), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		b:box('WallBand', V(sx * X, H - 1.15, TZ), V(sx * (X + 0.12), H - 0.35, Dp), T.band, M.SmoothPlastic)
		b:box('WallKick', V(sx * X, 0, TZ), V(sx * (X + 0.14), 0.6, Dp), T.kick, M.SmoothPlastic)
	end
	-- pilasters between the front row's bays (the stairs close the two ends)
	for k = -2, 1 do
		Armory.pilaster(b, (k + 0.5) * Armory.Spacing, TZ, F, H - 1.15)
	end
	-- the back wall on the terrace: studded, a dark skirting, a dark band and a light coping; pilasters between
	-- the back row's bays and big corner posts at its ends, from the hall floor to above the coping
	studs(b:box('BackWall', V(-X, H, Dp - 1.2), V(X, H + BW, Dp), T.wall, M.Plastic), true)
	b:box('BackKick', V(-X, H, Dp - 1.34), V(X, H + 0.5, Dp - 1.2), T.kick, M.SmoothPlastic)
	b:box('BackBand', V(-X, H + BW - 1.0, Dp - 1.32), V(X, H + BW - 0.4, Dp - 1.2), T.band, M.SmoothPlastic)
	b:box('BackCap', V(-X - 0.3, H + BW - 0.4, Dp - 1.7), V(X + 0.3, H + BW, Dp + 0.3), T.trim, M.SmoothPlastic)
	-- the three middle bays' wall a step higher, with its own band and cap: the skyline steps up to the centre
	local cx = 1.5 * Armory.Spacing
	studs(b:box('BackCrown', V(-cx, H + BW, Dp - 1.2), V(cx, H + BW + 1.6, Dp), T.wall, M.Plastic), true)
	b:box('BackBand', V(-cx, H + BW + 0.6, Dp - 1.32), V(cx, H + BW + 1.2, Dp - 1.2), T.band, M.SmoothPlastic)
	b:box('BackCap', V(-cx - 0.3, H + BW + 1.2, Dp - 1.7), V(cx + 0.3, H + BW + 1.6, Dp + 0.3), T.trim, M.SmoothPlastic)
	for k = -2, 1 do
		Armory.pilaster(b, (k + 0.5) * Armory.Spacing, Dp - 1.2, H, H + BW - 1.0)
	end
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (X - 1.4), sx * (X + 0.3)
		b:box('CornerPost', V(xa, 0, Dp - 2.1), V(xb, H + BW + 0.6, Dp + 0.3), T.pilaster, M.SmoothPlastic)
		b:box('CornerBase', V(xa - sx * 0.2, 0, Dp - 2.3), V(xb + sx * 0.2, 1.0, Dp + 0.5), T.kick, M.SmoothPlastic)
		b:box('CornerCap', V(xa - sx * 0.2, H + BW + 0.6, Dp - 2.3), V(xb + sx * 0.2, H + BW + 1.1, Dp + 0.5), T.trim, M.SmoothPlastic)
		-- a low parapet along the terrace's open end, with a light cap
		studs(b:box('Parapet', V(sx * (X - 0.8), H, TZ + 0.5), V(sx * X, H + 1.3, Dp - 2.1), T.wall, M.Plastic), true)
		b:box('ParapetCap', V(sx * (X - 0.95), H + 1.3, TZ + 0.35), V(sx * (X + 0.15), H + 1.6, Dp - 2.1), T.trim, M.SmoothPlastic)
	end
	-- a stair at each end, from the deck up to the terrace (rises under 0.8, 1.2 treads): a mid-tone riser body
	-- under a light studded tread with its nosing, between two stringers with light caps
	local n = math.ceil((H - F) / 0.8) - 1
	local rise = (H - F) / (n + 1)
	for _, sx in { -1, 1 } do
		local a, bx = sx * (X - SW), sx * X
		local lo, hi = math.min(a, bx), math.max(a, bx)
		for k = 1, n do
			local z0 = TZ - (n + 1 - k) * 1.2
			local h = F + k * rise
			studs(b:box('ArmoryStair', V(lo, F, z0), V(hi, h - 0.2, TZ), T.riser, M.Plastic))
			studs(b:box('StairTread', V(lo, h - 0.2, z0 - 0.06), V(hi, h, z0 + 1.2), T.tread, M.Plastic))
		end
		-- (the stringer's slope runs 0.7 above the treads' nosings, so it starts a little in front of the first step)
		local za, zb = TZ - (n + 1) * 1.2 - 0.7 * 1.2 / rise, TZ
		for _, xe in { a, bx - sx * 0.5 } do
			local xl, xr = math.min(xe, xe + sx * 0.5), math.max(xe, xe + sx * 0.5)
			local ht = H - F + 0.7
			b:wedge('Stringer', V(xr - xl, ht, zb - za), CFrame.new((xl + xr) / 2, F + ht / 2, (za + zb) / 2), T.riser, M.SmoothPlastic)
			local p0, p1 = V((xl + xr) / 2, F, za), V((xl + xr) / 2, F + ht, zb)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			b:part('StringerCap', V(0.8, 0.28, (p1 - p0).Magnitude), cf * CFrame.new(0, 0.12, 0), T.trim, M.SmoothPlastic)
		end
	end
	return b
end

-- The shop's props, one purposeful group on each terrace end beside the back row (clear of the stair landings):
-- the till (a counter on a dark kick with a light top, a register with its screen and drawer, a stool) at the
-- viewer's left, the stock (hard gun cases stacked and leaning, a milk crate) at the right. Neutral tones: the
-- saturated colour stays on the pads.
function Armory.props(c)
	local T = Armory.Tone
	local X, H, Dp = Armory.HalfWidth, Armory.Step, Armory.Depth
	local p = c:group('ArmoryProps')
	-- the till, x 25..28.6 on the terrace's +X end, against the back wall
	local x0, x1, z0, z1 = X - 4.3, X - 1.1, Dp - 6.8, Dp - 3.0
	p:box('CounterKick', V(x0 + 0.1, H, z0 + 0.1), V(x1 - 0.1, H + 0.35, z1 - 0.1), T.kick, M.SmoothPlastic)
	studs(p:box('Counter', V(x0 + 0.2, H + 0.35, z0 + 0.2), V(x1 - 0.2, H + 2.9, z1 - 0.2), T.riser, M.Plastic), true)
	p:box('CounterBand', V(x0 + 0.15, H + 2.3, z0 + 0.15), V(x1 - 0.15, H + 2.6, z1 - 0.15), T.band, M.SmoothPlastic)
	p:box('CounterTop', V(x0, H + 2.9, z0), V(x1, H + 3.2, z1), T.trim, M.SmoothPlastic)
	local rx, rz = (x0 + x1) / 2, z0 + 1.6
	p:box('RegisterBase', V(rx - 0.8, H + 3.2, rz - 0.7), V(rx + 0.8, H + 3.55, rz + 0.7), T.case, M.SmoothPlastic)
	p:box('RegisterDrawer', V(rx - 0.75, H + 3.25, rz - 0.75), V(rx + 0.75, H + 3.45, rz - 0.7), T.metal, M.SmoothPlastic)
	p:wedge('RegisterKeys', V(1.3, 0.5, 0.8), CFrame.new(rx, H + 3.8, rz - 0.25) * CFrame.Angles(0, math.pi, 0), T.caseRim, M.SmoothPlastic)
	p:box('RegisterBody', V(rx - 0.65, H + 3.55, rz + 0.15), V(rx + 0.65, H + 4.35, rz + 0.65), T.case, M.SmoothPlastic)
	p:box('RegisterScreen', V(rx - 0.45, H + 3.85, rz + 0.1), V(rx + 0.45, H + 4.2, rz + 0.15), C(110, 200, 150), M.SmoothPlastic)
	-- (the stool on the customer side, clear of the end pad)
	p:post('StoolLeg', 0.18, 1.7, V(x1 - 0.9, H, z0 - 0.9), T.case, M.Metal)
	p:post('StoolFoot', 0.6, 0.15, V(x1 - 0.9, H, z0 - 0.9), T.case, M.SmoothPlastic)
	p:post('StoolSeat', 0.62, 0.3, V(x1 - 0.9, H + 1.7, z0 - 0.9), C(150, 60, 70), M.SmoothPlastic)
	-- the stock, on the -X end: two hard cases stacked (a light seam band, two latches and a handle each), one
	-- leaning on the back wall, a milk crate
	local sx0 = -X + 1.2
	local function case(cf, w, h, d)
		p:part('GunCase', V(w, h, d), cf, T.case, M.SmoothPlastic)
		p:part('CaseSeam', V(w + 0.06, 0.12, d + 0.06), cf, T.caseRim, M.SmoothPlastic)
		for _, s in { -1, 1 } do
			p:part('CaseLatch', V(0.3, 0.3, 0.12), cf * CFrame.new(s * w * 0.3, 0, -d / 2 - 0.05), T.metal, M.SmoothPlastic)
		end
		p:part('CaseHandle', V(0.9, 0.16, 0.16), cf * CFrame.new(0, 0, -d / 2 - 0.14), T.case, M.SmoothPlastic)
	end
	case(CFrame.new(sx0 + 1.7, H + 0.45, Dp - 4.6) * CFrame.Angles(0, math.rad(4), 0), 3.2, 0.9, 1.6)
	case(CFrame.new(sx0 + 1.6, H + 1.3, Dp - 4.5) * CFrame.Angles(0, math.rad(-7), 0), 2.8, 0.8, 1.4)
	case(CFrame.new(sx0 + 0.55, H + 1.75, Dp - 2.6) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(80)), 3.4, 0.9, 1.6)
	local cx, cz = sx0 + 2.2, Dp - 7.2
	p:box('CrateBase', V(cx - 0.8, H, cz - 0.8), V(cx + 0.8, H + 0.25, cz + 0.8), T.crate:Lerp(C(0, 0, 0), 0.3), M.SmoothPlastic)
	p:box('Crate', V(cx - 0.75, H + 0.25, cz - 0.75), V(cx + 0.75, H + 1.3, cz + 0.75), T.crate, M.SmoothPlastic)
	p:box('CrateRim', V(cx - 0.8, H + 1.3, cz - 0.8), V(cx + 0.8, H + 1.45, cz + 0.8), T.crate:Lerp(P.white, 0.25), M.SmoothPlastic)
	for _, dz in { -0.4, 0.4 } do
		p:box('CrateSlot', V(cx - 0.78, H + 0.7, cz + dz - 0.15), V(cx + 0.78, H + 0.95, cz + dz + 0.15), T.crate:Lerp(C(0, 0, 0), 0.45), M.SmoothPlastic)
	end
	return p
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local colors = require(ReplicatedStorage.Shared.GunRules).Colors
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.base(a)
	Armory.props(a)
	local walls = { Armory.TerraceZ, Armory.Depth - 1.2 }
	for i, gun in guns do
		local ri = (i - 1) // 5 + 1
		local row = Armory.Rows[ri]
		if not row then break end
		local col = (i - 1) % 5
		-- Gun 1 stands on the viewer's left: their left is +X when they look toward +Z.
		Armory.slot(a, gun, 2 * Armory.Spacing - col * Armory.Spacing, row.z, row.y, colors, row.label, row.scale, walls[ri])
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

-- Window: a studded grey stone frame standing proud of the wall and, set back inside it, four studded panes (the
-- two on the left a darker blue, like the reference's reflections) split by navy bars. x = centre, y = frame bottom.
local function window(c, x, y, o)
	o = o or {}
	local w, h, t = o.w or 15, o.h or P.street.winH, 1.3
	local x0, x1, y1 = x - w / 2, x + w / 2, y + h
	local trim = P.st.trim
	sbox(c, 'WindowFrame', V(x0, y, -0.2), V(x0 + t, y1, 0.7), trim, true)
	sbox(c, 'WindowFrame', V(x1 - t, y, -0.2), V(x1, y1, 0.7), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y, -0.2), V(x1 - t, y + t, 0.7), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y1 - t, -0.2), V(x1 - t, y1, 0.7), trim, true)
	local n = o.panes or (w >= 9 and 4 or 2)
	local bar = 0.7
	local g0, g1 = x0 + t, x1 - t
	local pw = (g1 - g0 - (n - 1) * bar) / n
	for k = 0, n - 1 do
		local a = g0 + k * (pw + bar)
		sbox(c, 'Glass', V(a, y + t, -0.2), V(a + pw, y1 - t, 0.1), k < n / 2 and P.st.glassA or P.st.glassB, true)
		if k < n - 1 then sbox(c, 'WindowBar', V(a + pw, y + t, -0.2), V(a + pw + bar, y1 - t, 0.25), P.st.mullion, true) end
	end
end

-- Hip roof (45 degrees by default) in studded slate over the rectangle x0..x1, z0..z1 standing at y: an eave slab overhanging the walls
-- by one stud, wedge slopes on all four sides with corner wedges, and a flat studded top.
local function hipRoof(c, x0, z0, x1, z1, y, rise, run)
	rise, run = rise or 5, run or 5
	local col = P.st.roof
	sbox(c, 'RoofEave', V(x0 - 1, y, z0 - 1), V(x1 + 1, y + 1, z1 + 1), col)
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
	sbox(c, 'RoofTop', V(x0 + run, y, z0 + run), V(x1 - run, y + rise, z1 - run), col)
end

-- A face of a w x depth block as a facade frame (+Z out of it, +X along it as seen from outside).
local function faceFrame(c, face, w, depth)
	if face == 'left' then return c:at(CFrame.new(0, 0, -depth) * CFrame.Angles(0, -math.pi / 2, 0)) end
	if face == 'right' then return c:at(CFrame.new(w, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)) end
	if face == 'back' then return c:at(CFrame.new(w, 0, -depth) * CFrame.Angles(0, math.pi, 0)) end
	return c
end

-- Red brick block of the reference street: w along the facade, o.depth deep, eave at o.h. Windows on both floors:
-- o.bays evenly along the front, or o.windows = { { face = 'front' | 'left' | 'right' | 'back', x = centre along
-- that face, w = width }, ... }.
local function brickBuilding(ctx, w, o)
	o = o or {}
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local d, H, ST = o.depth or DEPTH, o.h or P.street.eave, P.street
	sbox(c, 'Wall', V(0, -1, -d), V(w, H, 0), o.wall or P.st.brick)
	sbox(c, 'Band', V(-0.5, ST.band, -d - 0.5), V(w + 0.5, ST.band + 1.2, 0.5), P.st.band, true)
	hipRoof(c, 0, -d, w, 0, H, o.rise, o.run)
	local list = o.windows
	if not list then
		list = {}
		local n = o.bays or math.max(1, math.floor(w / 22 + 0.5))
		for k = 1, n do table.insert(list, { face = 'front', x = w * (k - 0.5) / n, w = o.winW or math.min(16, w / n - 6) }) end
	end
	for _, win in list do
		local f = faceFrame(c, win.face, w, d)
		for _, y in ST.sills do window(f, win.x, y, { w = win.w }) end
	end
	model:SetAttribute('Floors', 2)
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
-- World 1's spawn: the hall, a one-to-one copy of the user's two hall pictures (brief/ref1_hall_a.png from the exit
-- end looking south, ref1_hall_b.png from over the dais looking north), at the pictures' own scale. Measured off the
-- 1-stud floor studs (an avatar is about 6 studs): an 18-wide walkway, a hall about 240 x 180 x 70.
--   Shell: teal studded walls between light grey studded pillars (a navy channel with a white neon strip up the
--     front, kinked like the reference's), big navy-framed windows, small white wall lamps, grey lattice trusses
--     with long dark light bars on wires.
--   Floor: a lavender studded floor, an 18-wide N-S walkway and E-W arm, four big darker tiled panels outlined in
--     cyan neon with a dark band on the walkway side, notched in front of the dais.
--   North (-Z): the exit bay (a framed recess, two framed panels over it, a pale glass doorway onto the Stage 1
--     street), the WORLD 2 door (the reference's green coming-soon door) inside it, the FURTHEST STAGE pad beside it.
--   East: the shooting-range stand (from the user's range video) where the picture has its stepped capsule terrace.
--   South centre: the SHOE BOXES dais (the reference's PETS egg dais) under its sign.
--   South-west: the ARMORY (the reference's clone-machine corner) under its floating title.
--   West: the gamepass pads on checkered patches (decor with ComingSoon prompts).
--   South-east: the leaderboards against the back wall.
-- Builders from other files (Stations, Armory) fill the slots; a missing or failing one leaves a labelled
-- placeholder box of the slot's size.
-- Map frame (studs): interior x -120..120, z 6..186 (north wall z 5..6; the Stage 1 gate at z = 0 stays outside),
-- floor top y = 0. North = -Z. Lobby.Slots: name -> CFrame in the map frame, filled by Lobby.build.
local Lobby = {}

Lobby.W = 120 -- interior half width (walls x +-120..+-121)
Lobby.N, Lobby.S = 6, 186 -- interior north and south faces
Lobby.H = 70 -- ceiling
Lobby.Deck = SPAWN.Y -- the floor (0): the spawn stands on it
Lobby.CrossZ = SPAWN.Z -- where the walkways cross
Lobby.Door, Lobby.DoorH = 21.5, 30 -- the doorway's half width and height (the Stage 1 wall outside is +-22)
Lobby.Slots = {}
Lobby.SlotSizes = {}
-- Colours sampled from the reference frames (lit faces), set so our renders land on them.
Lobby.Colors = {
	walk = C(179, 182, 222), panel = C(146, 151, 199), band = C(92, 104, 152), cyan = C(60, 232, 255),
	wall = C(122, 170, 202), wallDark = C(100, 148, 182), pillar = C(146, 150, 180), channel = C(34, 50, 92),
	neon = C(240, 246, 255), frame = C(146, 154, 188), winFrame = C(30, 66, 112), winGlass = C(172, 222, 246),
	truss = C(84, 104, 134), barHousing = C(54, 58, 78), ceiling = C(70, 98, 128), lamp = C(255, 252, 236),
	standTread = C(184, 188, 224), standRiser = C(128, 132, 170), standNose = C(214, 218, 240),
	checkDark = C(44, 48, 62), checkLight = C(214, 218, 232), dais = C(176, 182, 218), shelfDark = C(84, 90, 124),
	shelfLight = C(150, 156, 192), eggPad = C(38, 58, 124), sign = C(222, 226, 238), signFrame = C(150, 156, 186),
	hazard = C(250, 196, 32), gold = C(255, 204, 48), green = C(30, 140, 60), vent = C(152, 176, 210),
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
		{ 'Title', text, color or C(70, 236, 230), FONT.loud, 0, sub and 0.6 or 1 },
		sub and { 'Sub', sub, P.white, FONT.title, 0.62, 0.36 } or nil,
	})
	a.WorldLabel.MaxDistance = maxDist or 200
	for _, t in a.WorldLabel:GetChildren() do
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then s.Color, s.Thickness = C(12, 40, 52), 3 end
	end
	return a
end

---------------------------------------------------------------------------------------------- shell
-- A wall pillar standing at pos on the wall's inner face, its front along normal: light grey studded, deep below
-- and slimmer above with a slanted kink between, a navy channel down the middle of its front with a white neon
-- strip in it that follows the kink. y0: where it starts (the terrace top behind the capsules).
Lobby.PillarW, Lobby.PillarKink, Lobby.PillarD = 12, { 20, 26 }, { 5, 2.6 }
function Lobby.wallPillar(c, pos, normal, y0, w)
	local K, H = Lobby.Colors, Lobby.H
	w = w or Lobby.PillarW
	local k0, k1 = table.unpack(Lobby.PillarKink)
	local d0, d1 = table.unpack(Lobby.PillarD)
	local f = CFrame.lookAt(pos, pos + normal) -- local -Z points into the hall
	local yb = y0 or 0
	local function B(name, x0, ya, z0, x1, yt, z1, color, mat)
		return c:part(name, V(x1 - x0, yt - ya, z1 - z0), f * CFrame.new((x0 + x1) / 2, (ya + yt) / 2, (z0 + z1) / 2), color, mat or M.SmoothPlastic)
	end
	studs(B('Pillar', -w / 2, yb, -d0, w / 2, k0, 0, K.pillar), true)
	studs(B('Pillar', -w / 2, k0, -d1, w / 2, H, 0, K.pillar), true)
	-- the slant: a wedge whose slope runs from the lower part's front top edge up to the upper part's face
	studs(c:wedge('PillarKink', V(w, k1 - k0, d0 - d1), f * CFrame.new(0, (k0 + k1) / 2, -(d0 + d1) / 2), K.pillar, M.Plastic), true)
	local cw, nw = 1.7, 1.0
	for _, e in { { 'PillarChannel', cw, 0.1, K.channel, M.SmoothPlastic }, { 'PillarNeon', nw, 0.22, K.neon, M.Neon } } do
		decor(B(e[1], -e[2] / 2, yb + 1.2, -d0 - e[3], e[2] / 2, k0, -d0, e[4], e[5])).CastShadow = false
		decor(B(e[1], -e[2] / 2, k1, -d1 - e[3], e[2] / 2, H - 0.6, -d1, e[4], e[5])).CastShadow = false
		local a, b = V(0, k0, -d0), V(0, k1, -d1)
		local nrm = V(0, d0 - d1, -(k1 - k0)).Unit * (e[3] / 2)
		decor(c:part(e[1], V(e[2], e[3], (b - a).Magnitude + 0.3), f * CFrame.lookAt((a + b) / 2 + nrm, b + nrm), e[4], e[5])).CastShadow = false
	end
end
-- A big window: a thick navy frame, pale blue glass with two white glints, a navy transom near the top. cf sits on
-- the wall face at the window's centre, -Z into the hall.
function Lobby.window(c, cf, w, h)
	local K = Lobby.Colors
	c:part('WindowFrame', V(w, h, 0.6), cf * CFrame.new(0, 0, -0.3), K.winFrame, M.SmoothPlastic)
	c:part('WindowGlass', V(w - 2.6, h - 2.6, 0.2), cf * CFrame.new(0, 0, -0.65), K.winGlass, M.SmoothPlastic)
	c:part('WindowTransom', V(w - 2.6, 1.1, 0.3), cf * CFrame.new(0, h / 2 - 1.3 - (h - 2.6) * 0.3, -0.75), K.winFrame, M.SmoothPlastic)
	for _, g in { { -w * 0.16, 2.6, 0.62 }, { w * 0.12, 1.3, 0.5 } } do
		decor(c:part('WindowGlint', V(g[2], h * g[3], 0.05), cf * CFrame.new(g[1], -h * 0.1, -0.79) * CFrame.Angles(0, 0, math.rad(-38)), K.winGlass:Lerp(P.white, 0.6), M.SmoothPlastic)).CastShadow = false
	end
end
-- A small glowing wall lamp plate.
function Lobby.wallLamp(c, cf)
	decor(c:part('WallLamp', V(3, 1, 0.5), cf * CFrame.new(0, 0, -0.25), Lobby.Colors.lamp, M.Neon)).CastShadow = false
end
-- The hall: floor slab, the four walls (the north one with the doorway), pillars, windows, lamps, the ceiling,
-- the trusses and the light bars.
Lobby.SidePillars = { 42, 78, 114, 150 } -- along the side walls (z), plus the corners
Lobby.BackPillars = { -84, -42, 0, 42, 84 } -- along the back wall (x)
Lobby.NorthPillars = { -86, 86 } -- along the north wall (x); the exit bay's frame (+-43..46.4) borders the inner bays
Lobby.BarRows = { 25, 67, 109, 151 } -- light bar rows (z)
Lobby.BarCols = { -63, -19, 19, 63 } -- light bar centres (x)
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	Lobby.slab(h, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), K.walk)
	local function wall(a, b) return Lobby.slab(h, 'Wall', a, b, K.wall, true) end
	wall(V(-W - 1, 0, N - 1), V(-W, H, S + 1))
	wall(V(W, 0, N - 1), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, S), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, N - 1), V(-Dw, H, N))
	wall(V(Dw, 0, N - 1), V(W + 1, H, N))
	wall(V(-Dw, DH, N - 1), V(Dw, H, N))
	-- wall frames: cf on the inner face at (u along the wall, y), -Z into the hall
	local function west(u, y) return CFrame.lookAt(V(-W, y, u), V(-W + 1, y, u)) end
	local function east(u, y) return CFrame.lookAt(V(W, y, u), V(W - 1, y, u)) end
	local function south(u, y) return CFrame.lookAt(V(u, y, S), V(u, y, S - 1)) end
	local function north(u, y) return CFrame.lookAt(V(u, y, N), V(u, y, N + 1)) end
	local St = Lobby.standLayout()
	local tz = { St.Stairs[1][1], St.Stairs[2][2] }
	local top = St.Rows[#St.Rows].top
	-- pillars: the side walls (the east ones behind the capsules stand on the top tier), the back wall, the north
	-- wall, the four corners (half pillars, one on each wall)
	for _, z in Lobby.SidePillars do
		Lobby.wallPillar(h, V(-W, 0, z), V(1, 0, 0))
		Lobby.wallPillar(h, V(W, 0, z), V(-1, 0, 0), (z > tz[1] and z < tz[2]) and top or nil)
	end
	for _, x in Lobby.BackPillars do Lobby.wallPillar(h, V(x, 0, S), V(0, 0, -1)) end
	for _, x in Lobby.NorthPillars do Lobby.wallPillar(h, V(x, 0, N), V(0, 0, 1)) end
	for _, sx in { -1, 1 } do
		Lobby.wallPillar(h, V(sx * (W - 3), 0, S), V(0, 0, -1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, S - 3), V(-sx, 0, 0), nil, 6)
		Lobby.wallPillar(h, V(sx * (W - 3), 0, N), V(0, 0, 1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, N + 3), V(-sx, 0, 0), nil, 6)
	end
	-- windows (y 33..55) and lamps between the pillars
	local wy, ww, wh = 40, 23, 19 -- windows y 30.5..49.5
	local function bay(f, u, w, ht, y)
		Lobby.window(h, f(u, y or wy), w or ww, ht or wh)
		Lobby.wallLamp(h, f(u, wy + wh / 2 + 2))
		Lobby.wallLamp(h, f(u, 22))
	end
	-- (the side walls' windows are taller: y 31..57)
	for _, z in { 24, 96, 132, 168 } do
		bay(west, z, 24, 26, 44)
		bay(east, z, 24, 26, 44)
	end
	for _, f in { west, east } do Lobby.wallLamp(h, f(60, wy + wh / 2 + 4)) end -- (the hall signs hang in this bay)
	for _, x in { -101.75, -63, -21, 21, 63, 101.75 } do bay(south, x) end
	for _, x in { -103, 103 } do bay(north, x, 18) end
	-- the inner north bays (between the exit frame and the +-86 pillars) are plain wall: two lamps and a low vent
	for _, sx in { -1, 1 } do
		Lobby.wallLamp(h, north(sx * 62, 53))
		Lobby.wallLamp(h, north(sx * 62, 26))
		local v = h:part('Vent', V(23, 10.5, 0.8), north(sx * 61.5, 5.25) * CFrame.new(0, 0, -0.4), K.vent, M.SmoothPlastic)
		Lobby.stripes(v, Enum.NormalId.Front, 23, 10.5, 2, 1.1, true, 0.55, C(70, 90, 130))
		h:part('VentFrame', V(24.4, 1.2, 1), north(sx * 61.5, 11.1) * CFrame.new(0, 0, -0.5), K.frame, M.SmoothPlastic)
	end
	Lobby.exitBay(h)
	-- Roof: the ceiling, trusses along and across the hall, long light bars hung on wires under the cross trusses.
	-- Everything up here is named Roof* (the plan view hides it).
	local r = L:group('Roof')
	r:box('RoofCeiling', V(-W - 1, H, N - 1), V(W + 1, H + 1, S + 1), K.ceiling, M.SmoothPlastic).CastShadow = false
	local ty = 60
	-- (a TrussPart is 2 x 2; two stacked read as the reference's deep lattice girders)
	for _, x in Lobby.BarCols do
		for _, dy in { 0, 2.6 } do Lobby.truss(r, 'RoofTruss', V(x, ty + dy, N), V(x, ty + dy, S), K.truss) end
	end
	for _, z in Lobby.BarRows do
		for _, dy in { 5.2, 7.8 } do Lobby.truss(r, 'RoofTruss', V(-W, ty + dy, z), V(W, ty + dy, z), K.truss) end
	end
	for _, z in Lobby.BarRows do
		for _, x in Lobby.BarCols do
			local y = 50
			studs(r:box('RoofLampBar', V(x - 12.5, y, z - 1.6), V(x + 12.5, y + 1, z + 1.6), K.barHousing, M.Plastic), true).CastShadow = false
			decor(r:box('RoofLampTube', V(x - 12.2, y - 0.15, z - 1.3), V(x + 12.2, y, z + 1.3), K.neon, M.Neon)).CastShadow = false
			for _, dx in { -11, 11 } do decor(r:box('RoofLampWire', V(x + dx - 0.08, y + 1, z - 0.08), V(x + dx + 0.08, ty + 1, z + 0.08), C(40, 44, 56), M.SmoothPlastic)).CastShadow = false end
		end
	end
	return h
end

---------------------------------------------------------------------------------------------- exit bay
-- The north wall's centre between the pillars at +-52: a grey framed recess (x +-43, 39 high) round a pale glass
-- doorway (x +-21.5, 30 high) that opens onto the Stage 1 street (its wall shows through), two big framed panels
-- over the recess, white neon lines under and between them. Inside the recess, east of the door: the WORLD 2 door.
function Lobby.exitBay(h)
	local K, N = Lobby.Colors, Lobby.N
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local e = h:group('ExitBay')
	local RX, RH, fw = 43, 39, 3.4
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
	-- pale glass in the doorway: you see the street through it and walk straight through
	local glass = e:box('ExitGlass', V(-Dw, 0, N - 0.5), V(Dw, DH, N - 0.3), C(186, 226, 255), M.Glass)
	glass.Transparency, glass.CanCollide, glass.CanQuery, glass.CanTouch, glass.CastShadow = 0.72, false, false, false, false
	-- two big framed panels over the recess
	local py0, py1 = RH + fw + 1.2, RH + fw + 21
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * 1.6, sx * RX
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		e:box('ExitPanel', V(lo, py0, N), V(hi, py1, N + 0.12), K.wallDark, M.SmoothPlastic)
		for _, ed in { { V(lo, py0, N), V(hi, py0 + 2, N + 1.2) }, { V(lo, py1 - 2, N), V(hi, py1, N + 1.2) }, { V(lo, py0, N), V(lo + 2, py1, N + 1.2) }, { V(hi - 2, py0, N), V(hi, py1, N + 1.2) } } do
			studs(e:box('ExitPanelFrame', ed[1], ed[2], K.frame, M.Plastic), true)
		end
	end
	local function neon(a, b) decor(e:box('ExitNeon', a, b, K.neon, M.Neon)).CastShadow = false end
	neon(V(-RX - fw, RH + fw, N + 1.2), V(RX + fw, RH + fw + 0.7, N + 1.6)) -- under the panels
	neon(V(-0.4, RH + fw, N + 0.3), V(0.4, py1, N + 0.9)) -- between them
	for _, sx in { -1, 1 } do
		local a, b = sx * (RX + fw), sx * (RX + fw - 0.6)
		neon(V(math.min(a, b), 0.4, N + 1.6), V(math.max(a, b), RH + fw + 0.7, N + 1.9)) -- up the frame's outer edges
	end
	Lobby.world2(e, CFrame.lookAt(V(34, 0, N + 0.3), V(34, 0, N + 10)))
	return e
end
-- WORLD 2, the reference's green coming-soon door: a green arched door (a padlock, COMING SOON) in a red-and-black
-- striped arch, two little grave markers and pumpkins at its foot, a green glow round it. Front -Z of cf's frame
-- faces the hall (cf: centre bottom of the door on the recess back).
function Lobby.world2(e, cf)
	local K = Lobby.Colors
	local p, model = e:at(cf):group('World2Portal')
	local dw, dh, ar = 6.4, 17, 9.6 -- door half width, height to the arch's spring line, arch outer radius
	-- the arch: red and black blocks round a half circle, black posts down to the floor (local -Z = the hall)
	for _, sx in { -1, 1 } do
		p:box('ArchPost', V(sx * dw - (sx > 0 and 0 or 3.2), 0, -2.2), V(sx * dw + (sx > 0 and 3.2 or 0), dh, 0), C(28, 30, 36), M.SmoothPlastic)
	end
	local n = 11
	for k = 0, n - 1 do
		local a = math.pi * (k + 0.5) / n
		local r0 = (dw + ar) / 2
		local cfk = CFrame.new(math.cos(a) * r0, dh + math.sin(a) * r0, -1.1) * CFrame.Angles(0, 0, a)
		p:part('ArchBlock', V(ar - dw, 2.9, 2.2), cfk, k % 2 == 0 and C(196, 24, 30) or C(26, 26, 30), M.SmoothPlastic)
	end
	-- the green glow behind, the green door with its round top in front of it
	local glow = decor(p:box('World2Glow', V(-dw - 3, 0, -0.5), V(dw + 3, dh + ar - 1, -0.2), C(90, 255, 140), M.Neon))
	glow.Transparency, glow.CastShadow = 0.55, false
	light(glow, C(120, 255, 150), 2, 22)
	local door = p:box('World2Door', V(-dw, 0, -1.8), V(dw, dh, -0.8), K.green, M.SmoothPlastic)
	p:part('World2DoorTop', V(1, 2 * dw, 2 * dw), CFrame.new(0, dh, -1.3) * CFrame.Angles(0, math.pi / 2, 0), K.green, M.SmoothPlastic, Enum.PartType.Cylinder)
	local g = surface(door, Enum.NormalId.Front, 14)
	line(g, 'Soon', 'COMING SOON', C(255, 214, 60), FONT.loud, 0.06, 0.12, C(40, 30, 0), 2)
	line(g, 'World', 'WORLD 2', P.white, FONT.loud, 0.3, 0.16, C(10, 50, 20), 2)
	line(g, 'Detail', 'Beat the Boss Yard\nto unlock!', C(220, 255, 220), FONT.title, 0.55, 0.2, C(10, 50, 20), 1)
	p:box('World2Lock', V(-1.1, dh + 1.4, -2.2), V(1.1, dh + 3.6, -1.8), K.gold, M.SmoothPlastic)
	-- grave markers and pumpkins at its foot
	for _, sx in { -1, 1 } do
		local x = sx * (dw + 4.5)
		p:box('Marker', V(x - 1.1, 0, -3.4), V(x + 1.1, 2.6, -2.6), C(120, 126, 132), M.SmoothPlastic)
		p:part('MarkerTop', V(0.8, 2.2, 2.2), CFrame.new(x, 2.6, -3) * CFrame.Angles(0, math.pi / 2, 0), C(120, 126, 132), M.SmoothPlastic, Enum.PartType.Cylinder)
		p:part('Pumpkin', V(1.6, 1.3, 1.6), CFrame.new(x - sx * 2.4, 0.65, -4.2), C(255, 140, 30), M.SmoothPlastic, Enum.PartType.Ball)
	end
	local zone = p:box('World2Gate', V(-dw, 0, -6), V(dw, 6, -2), P.white)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	Lobby.Slots.World2Portal = cf
	return model
end

---------------------------------------------------------------------------------------------- floor
-- The floor slab is the walkway's lavender; the panels are a darker tiled overlay (a 4-stud tile grid under the
-- studs) with a cyan neon border on their edge and a dark band just outside it, on the walkway side. The two
-- south panels are notched in front of the dais (the walkway widens to +-20 there). A pale chevron on the north
-- walkway points to the exit.
Lobby.Panels = {
	{ -38, -10, 9, 78 }, { 10, 38, 9, 78 }, -- north pair (to the arm at z 78..96)
	{ -38, -10, 96, 119 }, { 10, 38, 96, 119 }, { -38, -20, 119, 134 }, { 20, 38, 119, 134 }, -- south pair, notched
}
-- Each panel's outline as edges { x0, z0, x1, z1 } (the notched pair share one outline each).
Lobby.PanelOutlines = {
	{ { -38, 9, -10, 9 }, { -10, 9, -10, 78 }, { -38, 78, -10, 78 }, { -38, 9, -38, 78 } },
	{ { 10, 9, 38, 9 }, { 10, 9, 10, 78 }, { 10, 78, 38, 78 }, { 38, 9, 38, 78 } },
	{ { -38, 96, -10, 96 }, { -10, 96, -10, 119 }, { -20, 119, -10, 119 }, { -20, 119, -20, 134 }, { -38, 134, -20, 134 }, { -38, 96, -38, 134 } },
	{ { 10, 96, 38, 96 }, { 10, 96, 10, 119 }, { 10, 119, 20, 119 }, { 20, 119, 20, 134 }, { 20, 134, 38, 134 }, { 38, 96, 38, 134 } },
}
function Lobby.floorPlan(L)
	local K = Lobby.Colors
	local f = L:group('FloorPlan')
	for _, p in Lobby.Panels do
		local x0, x1, z0, z1 = p[1], p[2], p[3], p[4]
		local s = Lobby.slab(f, 'Panel', V(x0, 0, z0), V(x1, 0.06, z1), K.panel)
		s.CastShadow = false
		Lobby.stripes(s, Enum.NormalId.Top, x1 - x0, z1 - z0, 4, 0.22, true, 0.82, C(70, 80, 130))
		Lobby.stripes(s, Enum.NormalId.Top, x1 - x0, z1 - z0, 4, 0.22, false, 0.82, C(70, 80, 130))
	end
	-- cyan border (0.8, inside the panel's edge) and the dark band (1.0, outside it)
	local cw, bw = 1.0, 0.8
	for _, outline in Lobby.PanelOutlines do
		-- the panel's centre, to know which side is outside
		local cx, cz, n = 0, 0, 0
		for _, ed in outline do cx += ed[1] + ed[3]; cz += ed[2] + ed[4]; n += 2 end
		cx, cz = cx / n, cz / n
		for _, ed in outline do
			local x0, z0, x1, z1 = ed[1], ed[2], ed[3], ed[4]
			if z0 == z1 then
				local out = (z0 < cz) and -1 or 1
				local lo, hi = math.min(x0, x1), math.max(x0, x1)
				decor(f:box('PanelNeon', V(lo, 0, z0 - out * cw), V(hi, 0.14, z0), K.cyan, M.Neon)).CastShadow = false
				decor(f:box('PanelBand', V(lo - bw, 0, z0), V(hi + bw, 0.1, z0 + out * bw), K.band, M.SmoothPlastic)).CastShadow = false
			else
				local out = (x0 < cx) and -1 or 1
				local lo, hi = math.min(z0, z1), math.max(z0, z1)
				decor(f:box('PanelNeon', V(x0 - out * cw, 0, lo), V(x0, 0.14, hi), K.cyan, M.Neon)).CastShadow = false
				decor(f:box('PanelBand', V(x0, 0, lo - bw), V(x0 + out * bw, 0.1, hi + bw), K.band, M.SmoothPlastic)).CastShadow = false
			end
		end
	end
	-- the pale chevron on the north walkway, pointing to the exit
	for _, sx in { -1, 1 } do
		local tip, tail = V(0, 0.05, 48), V(sx * 6.2, 0.05, 54.5)
		decor(f:part('WalkChevron', V(3.2, 0.06, (tip - tail).Magnitude + 1.6), CFrame.lookAt((tip + tail) / 2, tip), C(214, 218, 250), M.SmoothPlastic)).CastShadow = false
	end
	return f
end

---------------------------------------------------------------------------------------------- range stand
-- The east side, where the hall picture has its stepped capsule terrace: the shooting-range stand from the user's
-- video (another +1 game's range), facing the hall: wide grey studded treads stepping up toward the east wall,
-- darker studded risers under a pale nosing, a low front step, and at each end a wide straight stair up the stand
-- that meets every tread. The range builder (d2_stations) puts its pads, figures and labels on the treads:
-- Stations.stand(ctx, Lobby.Stand, skins) when it has one (the whole range in one call, in the map frame), otherwise
-- one Stations.build per range at Lobby.Stand.Slots (5 per tread, cheapest at the exit end of the front tread).
-- Lobby.Stand (map frame; everything faces west, -X):
--   Rows[i] = { x0, x1, top, z0, z1 }: tread i's front edge, back edge (the next riser), top height and z run;
--   rows 1-3 carry pads, row 4 is the top level against the wall. Rise 4 per tread, treads 16 deep.
--   Step = the low front step (x 44..46, 0.8 high) along the treads; Stairs = the two stairs' z runs (x 44..120, a
--   0.8 rise and a 3-stud tread each, 17 steps from the floor at x 44 to the top level at x 92).
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.Stand = { Z = { 36, 118 }, Stairs = { { 22, 36 }, { 118, 132 } }, Step = { 44, 46, 0.8 }, Rise = 4, Depth = 16, StairRise = 0.8, StairRun = 3, Rows = {}, Slots = {} }
function Lobby.standLayout()
	local St = Lobby.Stand
	table.clear(St.Rows)
	table.clear(St.Slots)
	local x, top = 46, 1.6
	for i = 1, 4 do
		local x1 = i == 4 and Lobby.W or x + St.Depth
		St.Rows[i] = { x0 = x, x1 = x1, top = top, z0 = St.Z[1], z1 = St.Z[2] }
		x, top = x1, top + St.Rise
	end
	-- 5 pad slots per tread on rows 1-3: origin on the tread at its middle, -Z = the front (west)
	local pitch = (St.Z[2] - St.Z[1]) / 5
	for i = 1, 3 do
		local r = St.Rows[i]
		for k = 0, 4 do
			local pos = V((r.x0 + r.x1) / 2, r.top, St.Z[1] + pitch * (k + 0.5))
			table.insert(St.Slots, CFrame.lookAt(pos, pos + V(-1, 0, 0)))
		end
	end
	St.Pitch = pitch
	return St
end
function Lobby.stand(L, skins)
	local K = Lobby.Colors
	local St = Lobby.standLayout()
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	local t = L:group('RangeStand')
	local z0, z1 = St.Z[1], St.Z[2]
	-- the front step and the treads (a dark riser body under a pale studded tread, a nosing strip on the front edge)
	Lobby.slab(t, 'StandStep', V(St.Step[1], 0, z0), V(St.Step[2], St.Step[3], z1), K.standTread, true)
	for _, r in St.Rows do
		Lobby.slab(t, 'StandRiser', V(r.x0, 0, z0), V(r.x1, r.top - 0.3, z1), K.standRiser, true)
		Lobby.slab(t, 'StandTread', V(r.x0, r.top - 0.3, z0), V(r.x1, r.top, z1), K.standTread, true)
		decor(t:box('StandNosing', V(r.x0 - 0.05, r.top - 0.3, z0), V(r.x0 + 0.7, r.top + 0.03, z1), K.standNose, M.SmoothPlastic)).CastShadow = false
	end
	-- the stairs: each step runs back to the wall so nothing is hollow
	local n = math.floor(St.Rows[4].top / St.StairRise + 0.5)
	for _, sr in St.Stairs do
		for k = 1, n do
			local xs = St.Step[1] + (k - 1) * St.StairRun
			Lobby.slab(t, 'StandStair', V(xs, 0, sr[1]), V(Lobby.W, k * St.StairRise, sr[2]), K.standTread, true)
		end
	end
	-- the range itself
	if Stations and Stations.stand then
		local ok, err = pcall(Stations.stand, L:into(training), St, skins)
		if ok then return t end
		warn('[Lobby] Stations.stand failed, one slot per range used: ' .. tostring(err))
		training:ClearAllChildren()
	end
	for k, id in Lobby.Ranges do
		local s = skins.StationById[id]
		Lobby.place(L, training, 'Range_' .. id, St.Slots[k], { X = St.Pitch, Y = 12, Z0 = -St.Depth / 2, Z1 = St.Depth / 2 }, string.upper(s and s.Name or id), C(90, 200, 120),
			Stations and function(c) Stations.build(c, id) end)
	end
	return t
end

---------------------------------------------------------------------------------------------- shoe box dais
-- The back wall's centre (the reference's PETS egg dais): a raised studded grey dais with sloped front corners, two
-- shelves of checkered tiles (the lower one in front, the upper one a step higher behind it), each shoe box on a
-- small navy pad with a rarity nameplate over it; blue tub seats along the back; the SHOE BOXES sign on the back
-- wall's centre pillar above (made in Lobby.signs). One ComingSoon prompt ("Shoe Boxes"); no unboxing yet.
-- Lobby.Slots.ShoeBoxes is the dais's front centre on the floor, facing the hall; Lobby.SlotSizes.ShoeBoxes its size.
Lobby.Dais = { X = 27, Z0 = 136, Z1 = 172, Low = 1.6, High = 4.4, Riser = 147 }
Lobby.ShoeBoxes = {
	{ Name = 'Common', Color = C(236, 238, 244), Trim = C(150, 158, 176), Shelf = 1, X = 12 },
	{ Name = 'Uncommon', Color = C(80, 210, 90), Trim = C(200, 255, 200), Shelf = 1, X = 4 },
	{ Name = 'Rare', Color = C(50, 130, 240), Trim = C(170, 214, 255), Shelf = 1, X = -4 },
	{ Name = 'Epic', Color = C(150, 80, 230), Trim = C(220, 180, 255), Shelf = 1, X = -12 },
	{ Name = 'Legendary', Color = C(250, 190, 30), Trim = C(255, 240, 160), Shelf = 2, X = 12 },
	{ Name = 'Mythic', Color = C(240, 70, 150), Trim = C(255, 190, 220), Shelf = 2, X = 4 },
	{ Name = 'Secret', Color = C(40, 44, 56), Trim = C(120, 255, 200), Shelf = 2, X = -4 },
	{ Name = 'Exclusive', Color = C(230, 40, 52), Trim = C(255, 220, 120), Shelf = 2, X = -12 },
}
-- One shoe box (local: centre bottom at the origin, front -Z): a body in the rarity colour with slanted side
-- stripes, tissue paper over the rim, a white lid lifted a little with a band of the rarity colour.
function Lobby.shoeBox(c, b, scale)
	local k = scale or 1
	local function B(name, lo, hi, color, mat) return c:box(name, lo * k, hi * k, color, mat or M.SmoothPlastic) end
	B('ShoeBoxBody', V(-2.5, 0, -1.7), V(2.5, 2.3, 1.7), b.Color)
	for _, sx in { -1, 1 } do
		c:part('ShoeBoxFlash', V(0.06, 0.42, 2.6) * k, CFrame.new(V(sx * 2.53, 1.4, 0.1) * k) * CFrame.Angles(math.rad(-18), 0, 0), b.Trim, M.SmoothPlastic)
	end
	for j = -1, 1 do
		c:part('ShoeBoxTissue', V(1.7, 0.5, 3.0) * k, CFrame.new(V(j * 1.55, 2.4, 0) * k) * CFrame.Angles(0, 0, math.rad(j * 9)), C(255, 222, 236), M.SmoothPlastic)
	end
	c:part('ShoeBoxLid', V(5.4, 0.7, 3.8) * k, CFrame.new(V(0, 3.1, 0) * k), C(246, 246, 250), M.SmoothPlastic)
	c:part('ShoeBoxLidBand', V(5.44, 0.14, 3.84) * k, CFrame.new(V(0, 2.82, 0) * k), b.Color:Lerp(P.white, 0.1), M.SmoothPlastic)
end
function Lobby.shoeDais(L)
	local K = Lobby.Colors
	local D = Lobby.Dais
	local X, z0, z1 = D.X, D.Z0, D.Z1
	local d = L:group('ShoeBoxDais')
	-- the dais: a low front deck and a higher back deck; the front corners slope down to the floor
	Lobby.slab(d, 'Dais', V(-X + 4, 0, z0), V(X - 4, D.Low, z1), K.dais, true)
	Lobby.slab(d, 'Dais', V(-X, 0, z0 + 4), V(X, D.Low, z1), K.dais, true)
	for _, sx in { -1, 1 } do
		-- a corner wedge sloping off the front corner (45 degrees in plan)
		-- a triangular prism standing up (the wedge turned on its side): its right angle on the body's corner
		local cf = CFrame.new(sx * (X - 2), D.Low / 2, z0 + 2) * CFrame.Angles(0, 0, sx > 0 and -math.pi / 2 or math.pi / 2)
		studs(d:wedge('DaisCorner', V(D.Low, 4, 4), cf, K.dais, M.Plastic), true)
	end
	Lobby.slab(d, 'DaisHigh', V(-X + 3, D.Low, D.Riser), V(X - 3, D.High, z1), K.dais, true)
	-- the shelves: checkered tiles (2-stud checks) in a recessed strip, navy pads under the boxes
	local shelves = { { y = D.Low, za = z0 + 3, zb = z0 + 9 }, { y = D.High, za = D.Riser + 2, zb = D.Riser + 8 } }
	for _, s in shelves do
		for xx = -18, 16, 2 do
			for zz = s.za, s.zb - 2, 2 do
				local dark = ((xx + 18) // 2 + (zz - s.za) // 2) % 2 == 0
				decor(d:box('ShelfTile', V(xx, s.y, zz), V(xx + 2, s.y + 0.06, zz + 2), dark and K.shelfDark or K.shelfLight, M.SmoothPlastic)).CastShadow = false
			end
		end
	end
	for i, b in Lobby.ShoeBoxes do
		local s = shelves[b.Shelf]
		local zc = (s.za + s.zb) / 2
		d:box('EggPad', V(b.X - 2.2, s.y, zc - 2.2), V(b.X + 2.2, s.y + 0.25, zc + 2.2), K.eggPad, M.SmoothPlastic)
		local base = V(b.X, s.y + 0.25, zc)
		local bc, box = d:at(CFrame.new(base) * CFrame.Angles(0, math.rad((i % 2 == 0) and 12 or -12), 0)):group('ShoeBox')
		Lobby.shoeBox(bc, b, 1.3)
		Lobby.motion(box, CFrame.new(base), 10, 0.2, 2.4 + i * 0.2)
		local nb = billboard(d, base + V(0, 7, 0), 5, 1.5, {
			{ 'Name', b.Name, b.Color:Lerp(P.white, 0.25), FONT.loud, 0, 0.55 },
			{ 'Soon', 'SOON', C(255, 214, 60), FONT.loud, 0.55, 0.45 },
		})
		nb.WorldLabel.MaxDistance = 90
	end
	-- blue tub seats along the back of the high deck
	for _, x in { -20, -14, 14, 20 } do
		d:box('TubSeat', V(x - 2, D.High, z1 - 4), V(x + 2, D.High + 2.4, z1 - 0.5), C(40, 90, 200), M.SmoothPlastic)
	end
	local hit = ghost(d:box('ShoeBoxPrompt', V(-6, D.Low, z0 + 1), V(6, D.Low + 4, z0 + 3), P.white))
	Lobby.prompt(hit, 'Open', 'Shoe Boxes', 14)
	Lobby.Slots.ShoeBoxes = CFrame.new(0, 0, z0)
	Lobby.SlotSizes.ShoeBoxes = V(2 * X, 14, z1 - z0)
	return d
end

---------------------------------------------------------------------------------------------- gamepass pads
-- The west side's gamepass pads (the reference's 2x Power / x2 Wins spots): a floor patch (black-and-white checks,
-- or a plain orange / yellow one), a short pedestal with a big capsule trophy in the pass's colour, a floating
-- name. Decor with ComingSoon prompts.
Lobby.Pads = {
	{ Name = '2x POWER', Color = C(60, 150, 255), X = -58, Z = 53, Patch = 'check', W = 24, D = 12 },
	{ Name = 'x2 CASH', Color = C(255, 214, 40), X = -58, Z = 68, Patch = 'check', W = 24, D = 12 },
	{ Name = 'AUTO SHOOT', Color = C(240, 60, 60), X = -82, Z = 65, Patch = C(255, 140, 40), W = 16, D = 10 },
	{ Name = 'VIP', Color = C(255, 210, 40), X = -77, Z = 86, Patch = C(255, 214, 60), W = 10, D = 11 },
	{ Name = 'LUCKY', Color = C(80, 220, 120), X = -58, Z = 103, Patch = 'check', W = 24, D = 12 },
}
function Lobby.pads(L)
	local K = Lobby.Colors
	local g = L:group('GamepassPads')
	for _, pd in Lobby.Pads do
		local x0, x1, za, zb = pd.X - pd.W / 2, pd.X + pd.W / 2, pd.Z - pd.D / 2, pd.Z + pd.D / 2
		if pd.Patch == 'check' then
			for xx = x0, x1 - 3, 3 do
				for zz = za, zb - 3, 3 do
					local dark = ((xx - x0) // 3 + (zz - za) // 3) % 2 == 0
					decor(g:box('PadCheck', V(xx, 0, zz), V(xx + 3, 0.1, zz + 3), dark and K.checkDark or K.checkLight, M.SmoothPlastic)).CastShadow = false
				end
			end
		else
			decor(g:box('PadPatch', V(x0, 0, za), V(x1, 0.1, zb), pd.Patch, M.SmoothPlastic)).CastShadow = false
		end
		-- the pedestal and the capsule trophy
		local c = g:at(CFrame.new(pd.X, 0, pd.Z))
		c:post('PadFoot', 1.8, 0.6, V(0, 0, 0), C(40, 44, 56), M.SmoothPlastic)
		c:post('PadStem', 0.5, 2.6, V(0, 0.6, 0), C(40, 44, 56), M.SmoothPlastic)
		c:post('PadCup', 1.5, 0.6, V(0, 3.2, 0), C(200, 204, 214), M.SmoothPlastic)
		c:post('PadBody', 1.3, 4.6, V(0, 3.8, 0), pd.Color, M.SmoothPlastic)
		c:post('PadCap', 1.45, 0.7, V(0, 8.4, 0), C(200, 204, 214), M.SmoothPlastic)
		local hit = ghost(c:box('PadHit', V(-2, 0, -2), V(2, 8, 2), P.white))
		Lobby.prompt(hit, 'Buy', pd.Name, 10)
		local a = billboard(c, V(0, 12, 0), 8, 2.2, { { 'Name', pd.Name, pd.Color:Lerp(P.white, 0.2), FONT.loud, 0, 0.62 }, { 'Soon', 'COMING SOON', P.white, FONT.title, 0.64, 0.36 } })
		a.WorldLabel.MaxDistance = 110
	end
	return g
end

---------------------------------------------------------------------------------------------- signs
-- The reference's hall signs: a white-framed pale board with a faint diamond lattice and the name in big white
-- letters with a dark grey outline. cf faces the hall.
function Lobby.hallSign(c, name, cf, w, ht, text)
	local K = Lobby.Colors
	c:part(name .. 'Frame', V(w + 2.4, ht + 2.4, 0.6), cf * CFrame.new(0, 0, 0.35), K.signFrame, M.SmoothPlastic)
	c:part(name .. 'Rim', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, 0.05), P.white, M.SmoothPlastic)
	local b, g = Lobby.board(c, name, cf * CFrame.new(0, 0, -0.2), w, ht, K.sign, { { 'Title', text, P.white, FONT.loud, 0.18, 0.64, C(90, 96, 120), 5 } }, 10)
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, true, 0.88, C(150, 156, 186))
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, false, 0.88, C(150, 156, 186))
	local _ = g
	return b
end
function Lobby.signs(L)
	local W, S = Lobby.W, Lobby.S
	local s = L:group('HallSigns')
	Lobby.hallSign(s, 'ShoeBoxSign', CFrame.lookAt(V(0, 24.4, S - Lobby.PillarD[1] - 0.8), V(0, 24.4, 0)), 30, 10.5, 'SHOE BOXES')
	Lobby.hallSign(s, 'RangeSign', CFrame.lookAt(V(W - 1.2, 30.5, 60), V(0, 30.5, 60)), 25, 12, 'RANGES')
	Lobby.hallSign(s, 'BoostSign', CFrame.lookAt(V(-W + 1.2, 30.5, 60), V(0, 30.5, 60)), 25, 12, 'BOOSTS')
	-- the reference's big floating CLONE MACHINE words (seen from near the dais, not from the exit end): the
	-- ARMORY's title, over the floor north of it
	Lobby.title(s, V(-60, 22.8, 112), 40, 9, 'ARMORY', 'Better guns, more Power per shot!', nil, 105)
	return s
end

---------------------------------------------------------------------------------------------- leaderboards
-- The reference's leaderboards: a white board between two grey studded columns (a base and a capital each), a grey
-- header slab on top with a dark title plate. `live` names the model LobbyService writes into (a TextLabel named
-- TextLabel): ServerLeaderboard (top Power) or CashLeaderboard. Without it the board shows a season teaser.
function Lobby.leaderboard(L, cf, title, w, ht, live)
	local b, model = L:at(cf):group(live or 'Leaderboard')
	local grey, dark = C(150, 154, 176), C(70, 74, 92)
	for _, sx in { -1, 1 } do
		local x = sx * (w / 2 + 1)
		Lobby.slab(b, 'BoardColumn', V(x - 1, 0, -1), V(x + 1, ht, 1), grey, true)
		Lobby.slab(b, 'BoardColumnBase', V(x - 1.5, 0, -1.5), V(x + 1.5, 1.2, 1.5), grey:Lerp(P.white, 0.15), true)
		Lobby.slab(b, 'BoardColumnCap', V(x - 1.5, ht - 1.2, -1.5), V(x + 1.5, ht, 1.5), grey:Lerp(P.white, 0.15), true)
	end
	Lobby.slab(b, 'BoardHeader', V(-w / 2 - 2.6, ht, -1.6), V(w / 2 + 2.6, ht + 2.6, 1.6), grey:Lerp(P.white, 0.1), true)
	local plate = b:box('BoardTitle', V(-w / 2 + 1, ht + 0.4, -1.75), V(w / 2 - 1, ht + 2.2, -1.6), dark, M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 20), 'Title', title, P.white, FONT.loud, 0.1, 0.8, P.black, 1)
	local screen = b:box('BoardScreen', V(-w / 2, 1.2, -0.4), V(w / 2, ht - 0.4, 0.4), C(246, 246, 252), M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	if live then
		local t = line(g, 'TextLabel', live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!' or 'TOP POWER\nTHIS SERVER\nBe the first to train!', C(30, 34, 50), FONT.body, 0.05, 0.9, nil)
		t.TextYAlignment = Enum.TextYAlignment.Top
	else
		line(g, 'Rows', 'SEASON 1', C(30, 34, 50), FONT.loud, 0.3, 0.2, nil)
		line(g, 'Soon', 'TOP 5 SOON', C(90, 96, 120), FONT.loud, 0.55, 0.14, nil)
	end
	return model
end

---------------------------------------------------------------------------------------------- spawn & slots
-- The spawn point on the cross (StageService and SetActive use it), facing south down the hall like the
-- reference's first frame; the FURTHEST STAGE pad west of the exit bay on a glowing orange patch beside a yellow
-- kiosk (the reference's yellow machine there).
function Lobby.spawn(L)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.1, 0)) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = L.parent
	Lobby.Slots.Spawn = CFrame.new(SPAWN) * CFrame.Angles(0, math.pi, 0)
	-- the kiosk stands in front of the exit frame's west jamb, the pad just east of it, on one orange glow patch;
	-- two blue drums and a red post further west by the wall (the reference's props there)
	local k = L:group('FurthestKiosk')
	decor(k:box('KioskGlow', V(-52, 0, 8), V(-31, 0.08, 20), C(255, 150, 40), M.Neon)).CastShadow = false
	Lobby.slab(k, 'Kiosk', V(-51, 0, 8.5), V(-43, 5, 14.5), C(255, 210, 40), true)
	k:box('KioskTop', V(-50.4, 5, 9.1), V(-43.6, 6.4, 13.9), P.white, M.SmoothPlastic)
	k:box('KioskScreen', V(-49.6, 2, 14.5), V(-44.4, 4.2, 14.6), C(40, 200, 120), M.Neon)
	teleportPad(L, 'FurthestPad', -37, 15, C(255, 222, 40), 'Furthest', 'FURTHEST STAGE')
	Lobby.Slots.FurthestPad = CFrame.new(-37, Lobby.Deck, 15)
	for _, e in { { -88, 10 }, { -84.6, 11.2 } } do
		k:post('Drum', 1.6, 3.2, V(e[1], 0, e[2]), C(40, 90, 200), M.SmoothPlastic)
		k:post('DrumBand', 1.65, 0.3, V(e[1], 2.2, e[2]), C(28, 60, 150), M.SmoothPlastic)
	end
	k:post('Post', 0.9, 4.2, V(-72, 0, 13), C(210, 30, 40), M.SmoothPlastic)
	k:post('PostBand', 0.95, 0.6, V(-72, 2.6, 13), C(28, 30, 36), M.SmoothPlastic)
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
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front } do line(surface(box, face, 10), 'Text', label, P.white, FONT.loud, 0.2, 0.6, P.black, 2) end
	return holder
end
-- The ARMORY in the south-west (the reference's clone-machine corner), its front to the hall (north), and its
-- floating title (the reference's CLONE MACHINE words).
Lobby.ArmoryAt = CFrame.lookAt(V(-64, 0, 136), V(-64, 0, 0))
function Lobby.armory(L)
	local cf = Lobby.ArmoryAt
	Lobby.place(L, L.parent, 'Armory', cf, { X = 58.8, Y = 21, Z0 = 0, Z1 = 31.2 }, 'ARMORY', C(255, 90, 160),
		Armory and function(c) Armory.build(c, {}) end)
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
	Lobby.pads(L)
	Lobby.armory(L)
	Lobby.signs(L)
	Lobby.spawn(L)
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	local boards = L:group('Leaderboards')
	for k, e in { { 45, 'TOP POWER', 13, 22, 'ServerLeaderboard' }, { 63, 'TOP CASH', 13, 22, 'CashLeaderboard' }, { 89, 'TOP REBIRTHS', 8, 15 }, { 101, 'TOP TIME', 8, 15 } } do
		local cf = CFrame.lookAt(V(e[1], 0, Lobby.S - 7), V(e[1], 0, 0))
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(boards, cf, e[2], e[3], e[4], e[5])
	end
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
-- The spawn is the warehouse lobby (e2_lobby): shooting ranges, the EVOLUTIONS podium, the armory,
-- the spawn badge, FurthestPad and the leaderboards are all built there.
local function buildSpawn(ctx, skins)
	return Lobby.build(ctx, skins)
end
---------------------------------------------------------------------------------------------- stage gates
-- A gate at the start of every stage (and the boss yard), copied from the reference street: a see-through wall
-- across the opening between the end buildings, pink up top and fading to white at the foot, with "Stage N",
-- "Recommended" and "Power: X" on it in the Arcade pixel font, and two flat neon pads on the sidewalks right in
-- front of it (magenta on the left: back to spawn; yellow on the right: on to your furthest stage).
-- HoodClient/Stages keeps the wall solid while you're short, tints it green when you can pass and clears it once
-- you have; StageService records the clear and pays the reward.
local BOSS_RED = C(214, 44, 44)
local GATE = {
	H = 18.5, -- the wall's height (the reference's wall reaches the end buildings' second floor)
	pink = C(250, 160, 222), -- the gate's colour (attributes Color/Light: banner, shards)
	-- The haze from the top of the wall down: height above the street, colour, opacity (sampled from the reference:
	-- lavender at the top edge, pink through the "Stage" line, white below "Power").
	-- (The opacity only grows downward: the haze is drawn as stacked panes, each from its band down to the foot.)
	haze = {
		{ 18.5, C(246, 186, 222), 0.52 }, { 16.5, C(236, 176, 216), 0.6 }, { 13, C(200, 160, 200), 0.66 },
		{ 10, C(198, 162, 200), 0.7 }, { 7.5, C(214, 186, 218), 0.76 }, { 6, C(226, 210, 232), 0.84 },
		{ 4.8, C(228, 232, 248), 0.93 }, { 0, C(228, 232, 248), 0.95 },
	},
	bands = 74, -- quarter-stud bands (5 px each at the haze's 20 pixels per stud)
	title = C(180, 190, 208), titleInk = C(46, 60, 106), -- "Stage N": pale steel, navy outline
	sub = C(118, 180, 220), subInk = C(34, 74, 126), -- "Recommended" / "Power: X": sky blue, deep blue outline
	magenta = C(255, 32, 255), yellow = C(250, 246, 70), padRim = C(58, 66, 98), -- the pads and the dark rim under them
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
-- One line of the wall's text, scaled to its band (top y and height in studs), centred, outlined.
function GATE.text(gui, name, value, top, h, color, ink, thick)
	local t = line(gui, name, value, color, Enum.Font.Arcade, (GATE.H - top) / GATE.H, h / GATE.H, ink, thick)
	t.Position, t.Size = UDim2.fromScale(0, (GATE.H - top) / GATE.H), UDim2.fromScale(1, h / GATE.H)
	t.TextWrapped = false
	return t
end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local st = P.street or {}
	local road, walk, kerb, open, front = st.road or 8.5, st.walk or 8.5, st.kerb or 0.6, st.open or 22, st.front or FRONT
	local H = GATE.H
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	-- The wall: an invisible collider across the opening (solid on the server; HoodClient/Stages lets you through
	-- once you have the Power), carrying the haze and the text on its approach face.
	local barrier = g:box('Barrier', V(-open, 0, -0.3), V(open, H, 0.3), GATE.pink, M.SmoothPlastic)
	barrier.Transparency = 1
	barrier:SetAttribute('BaseTransparency', 1)
	barrier.CastShadow = false
	-- The haze: one pane per quarter-stud band, each running from its band down to the foot, so band n shows panes
	-- 1..n stacked. Each pane's colour and opacity are solved so the stack matches the sampled band exactly; no
	-- pane edge falls between two bands, so there are no seams between them.
	local haze = surface(barrier, Enum.NormalId.Back, 20)
	haze.Name = 'Haze'
	local pa, pc = 0, Vector3.zero -- the stack so far: opacity and premultiplied colour
	local panes = {}
	for n = 0, GATE.bands - 1 do
		local color, alpha = GATE.hazeAt(H * (1 - (n + 0.5) / GATE.bands))
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
		f.Position, f.Size = UDim2.fromScale(0, n / GATE.bands), UDim2.fromScale(1, 1 - n / GATE.bands)
		f.BackgroundColor3, f.BackgroundTransparency = paneColor, 1 - a
		f.ZIndex = n + 1
		f:SetAttribute('BaseColor', paneColor)
		f:SetAttribute('BaseTransparency', 1 - a)
		table.insert(panes, 1, f)
	end
	-- (ZIndex sets the order in Roblox; parenting the lowest band first also keeps preview exporters, which list
	-- frames in reverse, drawing them top band first.)
	for _, f in panes do f.Parent = haze end
	-- The text reads from far down the street, as in the reference; HoodClient/Stages shows it only on your next
	-- gate, so the walls beyond don't stack their text behind it.
	local sign = surface(barrier, Enum.NormalId.Back, 20)
	pcall(function() sign.MaxDistance = 400 end)
	GATE.text(sign, 'Title', i > STAGES and 'Boss Yard' or ('Stage ' .. i), 15.1, 2.95, GATE.title, GATE.titleInk, 6)
	GATE.text(sign, 'Sub', 'Recommended', 9.95, 1.95, GATE.sub, GATE.subInk, 4)
	GATE.text(sign, 'Power', 'Power: ' .. compact(req), 6.8, 1.95, GATE.sub, GATE.subInk, 4)
	-- Pads on the sidewalks just before the wall (measured on the reference: 6 x 11 on a dark rim, a 3-stud strip of
	-- pavement between them and the wall, 0.5 off the kerb): back to spawn, and on to your furthest stage.
	local padW, padD = math.min(6, walk - 1.5), 11
	local padX, padZ = road + 0.5 + padW / 2, 3 + padD / 2
	if i > 1 then
		local opts = { w = padW, d = padD, y = kerb, h = 0.25, bare = true, material = M.SmoothPlastic, base = GATE.padRim }
		teleportPad(g, 'LobbyPad', -padX, padZ, GATE.magenta, 'Lobby', 'SPAWN', opts)
		teleportPad(g, 'FurthestPad', padX, padZ, GATE.yellow, 'Furthest', 'FURTHEST STAGE', opts)
	end
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
	model:SetAttribute('Required', req)
	model:SetAttribute('Reward', math.max(10, math.floor(req * 0.2)))
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + padZ)
	model:SetAttribute('HalfWidth', front)
	model:SetAttribute('Color', GATE.pink)
	model:SetAttribute('Light', GATE.pink)
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:AddTag('HoodStageGate')
	return model
end

---------------------------------------------------------------------------------------------- stages
-- Every stage is the reference street (ref1_street.png), copied 1:1 for now. buildGround lays the cross-section
-- (road, sidewalks, grass); each stage adds, measured from the picture (z' = studs past the stage's own gate):
--   z' 0..44   the open street: a plank fence along each front yard (|x| = 34.5) and a long two-storey brick
--              building behind it (fronts at |x| = 36);
--   z' 44..64  the end buildings come forward to |x| = 22 and run up to the next gate, whose wall fills the gap;
--   a tall navy lamp each side (left at z' 19, right at 50), stacked-cube trees, low hedges, the green dumpster,
--   blue flowers and grass tufts, where the picture has them. The camera that matches the picture stands at z' 2,
--   13.6 up, 1 right of the centre line (the picture's wall is ~120 ahead; ours, 62: the stages are 64 long).
local function sideRow(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1])
		z -= lot[1]
	end
end
-- The end building on side s, from its front (z0, facing back up the street) to the next gate line (z1): solid from
-- |x| = open out to the back of the lots, windows on the strip of front that shows and on the side facing the road.
local function endBuilding(ctx, s, z0, z1)
	local ST = P.street
	local w, d = FRONT + DEPTH - ST.open, z0 - z1
	local strip = FRONT - ST.open
	return brickBuilding(ctx:at(CFrame.new(s < 0 and -(FRONT + DEPTH) or ST.open, 0, z0)), w, { name = 'EndBuilding', depth = d, h = ST.eave + 2, run = math.min(5, d / 2 - 1), rise = 4, windows = {
		{ face = 'front', x = s < 0 and w - strip / 2 or strip / 2, w = 10 },
		{ face = s < 0 and 'right' or 'left', x = d / 2, w = 10 },
	} })
end
local function streetStage(ctx, i)
	local top = stageTop(i)
	local ST = P.street
	local d = ctx:group('Stage' .. i)
	-- The fight hook stays (V2.Fights, HoodFightPad) as an invisible marker: the picture's road has no pad.
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	local zEnd = top - ST.endZ
	for _, s in { -1, 1 } do
		sideRow(d, s, top, { { ST.endZ, function(f, w) brickBuilding(f, w, { bays = 2 }) end } })
		endBuilding(d, s, zEnd, top - SLEN)
		fence(d, s * ST.fence, top, zEnd, -s)
	end
	local seed = i * 100
	local function at(x, zp) return V(x, ST.kerb, top - zp) end
	-- Left, near to far: hedge, lamp, the big tree, the far tree, a hedge and the second lamp by the end building.
	hedge(d, at(-25, 14), 6)
	lantern(d, at(-20, 19), V(1, 0, 0))
	tree(d, at(-24.5, 28.5), seed + 1, 1, 38)
	tree(d, at(-23.8, 47), seed + 2, 0.85, 20)
	hedge(d, at(-23.5, 51.5), 4)
	lantern(d, at(-20, 54.5), V(1, 0, 0))
	-- Right: open grass with a flower, the low hedge, the lamp (with its street sign) and the dumpster behind it.
	hedge(d, at(25.8, 34), 6)
	local lamp = lantern(d, at(20, 50), V(-1, 0, 0))
	sbox(lamp, 'StreetSign', V(0.9, 17.4, -2.4), V(1.2, 19.0, -0.2), C(40, 150, 70), true)
	dumpster(d, CFrame.new(at(31, 50.5)))
	for k, f in { { 21.5, 16.8 }, { 24, 41 }, { -21, 40 }, { -20, 34 }, { -29.8, 24 }, { 19.5, 60 } } do flower(d, at(f[1], f[2]), seed + 10 + k) end
	for k, t in { { -33, 44 }, { -31.8, 45.5 }, { -32.5, 30 }, { 22.8, 38 }, { 21, 50 }, { -18.5, 60 } } do tuft(d, at(t[1], t[2]), seed + 20 + k) end
	-- Stage 1: brick wings between the warehouse wall and the gate line, so its wall is the only way through.
	if i == 1 then
		for _, s in { -1, 1 } do
			local w = d:group('GateWing')
			sbox(w, 'Wall', V(s * ST.open, -1, 0), V(s * FRONT, ST.eave + 2, Lobby.N - 1), P.st.brick)
			sbox(w, 'Band', V(s * ST.open - s * 0.5, ST.band, -0.5), V(s * FRONT, ST.band + 1.2, Lobby.N - 1), P.st.band, true)
			sbox(w, 'RoofEave', V(s * ST.open - s * 1, ST.eave + 2, -1), V(s * FRONT, ST.eave + 3, Lobby.N - 1), P.st.roof)
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- boss yard
-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end.
local function bossYard(ctx)
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

local function buildStages(ctx)
	for i = 1, STAGES do streetStage(ctx, i) end
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
