-- BoxModels: the shoe boxes ("eggs" of the shoe system), part-built in Luau (no meshes, no uploads).
-- (brief 30) World 1's boxes are CHESTS with a hinged lid, rebuilt from the user's own render sheets
-- (brief/ref30/user_models): Street (white and red, a crown), Graffiti (cyan and pink, drips and a tag), Exclusive (shown
-- as the Chrome Box: navy and white, a cyan diamond), Grail (shown as the Crown Box: purple and gold, a crown and gold
-- wings) and the Grail Bundle's box (purple, gold and white wings). They are BoxKit models (hood/tools/blender/models/
-- chests.py) exported as part rows into the sibling module BoxParts (export_wear.py): what the Blender renders and the
-- UI pictures show is what this builds. Each is hollow (an inside floor and walls) and its lid has an inside plate, so
-- the lid opens onto an inside like the sheets' open view.
-- The eight later-world boxes (Frost .. Gold, not built in World 1) keep the earlier kit below (brief 28: a chunky
-- rounded tub, a "+1" coin on each side, a lid carrying the box's theme topper).
--   BoxModels.build(boxId, scale?, at?) -> Model   closed box, pivot = bottom centre (PrimaryPart `Root`), front -Z;
--               built at CFrame `at` (default the origin)
--     .Lid      sub-model (the lid's parts and the `Topper` model: a chest's handle); its pivot (PrimaryPart `Hinge`) is
--               the hinge on the body's back top edge, so the client can swing it open (see BoxModels.openLid)
--   BoxModels.openLid(model, t)    poses the lid: t = 0 shut .. 1 wide open (about 110 degrees), like the sheets'
--   BoxModels.fx(model)            the box's ambient effect (theme particles and a soft light); optional
--   BoxModels.animate(model)       sets its floating pieces moving (WorldMotion's HoodMotion tag); for boxes on display
--   BoxModels.Ids, BoxModels.Meta[id] = { Name (the id), Display, Color, Accent, Order }, BoxModels.Size (scale-1 studs)
--   BoxModels.Seal[boxId] = { Body, Lid, Low } (a chest's): where the reveal's seal tape lies on the front (the tub's and
--               the lid's front faces in the middle, design studs; the tape's lower end)
--   BoxModels.TopperShoes (kept empty: no box carries a shoe since brief 30)
-- Every part is Anchored, CanCollide/CanTouch/CanQuery false; studs, neon, glass and small trim cast no shadow.
-- Scale 1: the tub is 4.4 x 3.4 and 3.08 tall to the lid top; a handle or topper adds up to about 0.5 (a legacy topper
-- up to 3.5).
local BoxModels = {}

local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local SM, NEON, GLASS, FOIL = M.SmoothPlastic, M.Neon, M.Glass, M.Foil
local PI = math.pi
local WHITE = C(250, 250, 252)

BoxModels.Ids = { 'Street', 'Graffiti', 'Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold', 'Exclusive', 'Grail', 'GrailBundle' }
-- the tub (W x D), the body's top (where the lid sits and the hinge is), the lid's cap top
BoxModels.Size = { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
local W, D = BoxModels.Size.W, BoxModels.Size.D
local HW, HD = W / 2, D / 2
local BODY, TOP = BoxModels.Size.Body, BoxModels.Size.Top
-- the most parts a box may have (phones: the hall shows several at once)
local LIMIT = 220 -- (brief 30: the chests with their bevel strips and outlined emblems; the later worlds stay <= 140)
BoxModels.TopperShoes = {}
-- (brief 30) the chests: BoxKit part rows (Shared/Models/BoxParts, generated); nil if that module is missing
local BoxParts
do
	local ok, m = pcall(function()
		local node = script.Parent:FindFirstChild('BoxParts')
		return node and require(node)
	end)
	BoxParts = ok and type(m) == 'table' and m or nil
end
BoxModels.Seal = {}
if BoxParts then
	for id, b in BoxParts.Boxes do BoxModels.Seal[id] = b.Seal end
end

---------------------------------------------------------------------------------------------- kit
-- A builder frame: parts go into `parent`, positions are design studs (scale 1) in the frame `cf` (already scaled).
local Kit = {}
Kit.__index = Kit
local function newKit(parent, s, cf)
	return setmetatable({ parent = parent, s = s, cf = cf or CFrame.identity }, Kit)
end
-- a sub-frame at cf (design studs, relative to this frame)
function Kit:at(cf)
	return newKit(self.parent, self.s, self.cf * CFrame.new(cf.Position * self.s) * cf.Rotation)
end
function Kit:into(parent)
	return newKit(parent, self.s, self.cf)
end
function Kit:model(name)
	local m = Instance.new('Model')
	m.Name = name
	m.Parent = self.parent
	return self:into(m), m
end
-- A sub-model for a floating piece, pivoting at pos (design studs): BoxModels.animate turns its Anim* attributes into
-- WorldMotion's idle motion (spin round the pivot's Y, a bob), so only boxes on display move.
function Kit:floating(name, pos, spin, bob, period)
	local k, m = self:model(name)
	m.WorldPivot = self.cf * CFrame.new(pos * self.s)
	if spin then m:SetAttribute('AnimSpin', spin) end
	if bob then m:SetAttribute('AnimBob', bob * self.s) end
	if period then m:SetAttribute('AnimPeriod', period) end
	return k, m
end
local SURFACES = { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
function Kit:make(class, name, size, cf, color, mat)
	local p = Instance.new(class)
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size * self.s
	p.CFrame = self.cf * CFrame.new(cf.Position * self.s) * cf.Rotation
	p.Color = color
	p.Material = mat or SM
	for _, f in SURFACES do
		(p :: any)[f] = Enum.SurfaceType.Smooth
	end
	-- (brief 28) metal catches the light: chrome and gold get a little reflectance
	if p.Material == M.Metal or p.Material == FOIL then
		p.Reflectance = 0.12
	end
	-- glowing, see-through and small trim parts cast no shadow (cheap, and no speckle on the box)
	if p.Material == NEON or p.Material == GLASS or math.min(size.X, size.Y, size.Z) < 0.12 or size.Magnitude < 0.6 then
		p.CastShadow = false
	end
	p.Parent = self.parent
	return p
end
-- box centred on pos (rot: an optional rotation)
function Kit:box(name, pos, size, color, mat, rot)
	return self:make('Part', name, size, CFrame.new(pos) * (rot or CFrame.identity), color, mat)
end
-- axis-aligned box between two corners
function Kit:span(name, a, b, color, mat)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:make('Part', name, hi - lo, CFrame.new((lo + hi) / 2), color, mat)
end
local AXIS = { x = CFrame.identity, y = CFrame.Angles(0, 0, PI / 2), z = CFrame.Angles(0, PI / 2, 0) }
-- cylinder centred on pos along axis 'x' | 'y' | 'z' (or a rotation whose X is the axis)
function Kit:cyl(name, pos, axis, len, d, color, mat)
	local rot = type(axis) == 'string' and AXIS[axis] or axis
	local p = self:make('Part', name, V(len, d, d), CFrame.new(pos) * rot, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end
function Kit:ball(name, pos, d, color, mat)
	local p = self:make('Part', name, V(d, d, d), CFrame.new(pos), color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end
-- ellipsoid (a built-in sphere SpecialMesh, no asset)
function Kit:blob(name, pos, size, color, mat, rot)
	local p = self:make('Part', name, size, CFrame.new(pos) * (rot or CFrame.identity), color, mat)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Kit:wedge(name, cf, size, color, mat)
	return self:make('WedgePart', name, size, cf, color, mat)
end
-- An isosceles triangle (two wedges back to back): base w along the frame's Z, apex h up its Y, t thick along X.
function Kit:tent(name, cf, w, h, t, color, mat)
	local a = self:wedge(name, cf * CFrame.new(0, 0, -w / 4), V(t, h, w / 2), color, mat)
	local b = self:wedge(name, cf * CFrame.new(0, 0, w / 4) * CFrame.Angles(0, PI, 0), V(t, h, w / 2), color, mat)
	return a, b
end
-- A rounded box: two crossed boxes and four upright corner cylinders. (x, z) centre, y0 bottom, r corner radius.
function Kit:rbox(name, x, y0, z, w, h, d, r, color, mat)
	local y = y0 + h / 2
	local parts = {
		self:box(name, V(x, y, z), V(w, h, d - 2 * r), color, mat),
		self:box(name, V(x, y, z), V(w - 2 * r, h, d), color, mat),
	}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(parts, self:cyl(name .. 'Corner', V(x + sx * (w / 2 - r), y, z + sz * (d / 2 - r)), 'y', h, 2 * r, color, mat))
		end
	end
	return parts
end
-- A ring of n bars round the frame's Y axis (radius R to the bars' centre line), each bar t thick and h tall.
function Kit:ring(name, cf, R, n, t, h, color, mat)
	local len = 2 * R * math.tan(PI / n) + t * 0.6
	for k = 0, n - 1 do
		local a = k * 2 * PI / n
		self:make('Part', name, V(len, h, t), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, R), color, mat)
	end
end
-- A low-poly frustum (a cone with a flat top): n wedges round the frame's Y axis, their slopes facing out, from
-- radius rb at y 0 to rt at y h. colors: a list cycled round the sides (two tones). Returns the wedges.
function Kit:frustum(name, cf, rb, rt, h, n, colors, mat)
	local wedges = {}
	local wd = 2 * rb * math.tan(PI / n) * 1.04
	for j = 0, n - 1 do
		local a = j * 2 * PI / n
		local u = V(math.cos(a), 0, math.sin(a))
		local at = u * (rb + rt) / 2 + V(0, h / 2, 0)
		-- the wedge's sheer back (+Z) faces the axis, its slope faces out
		table.insert(wedges, self:wedge(name, cf * CFrame.lookAt(at, at + u), V(wd, h, rb - rt), colors[j % #colors + 1], mat))
	end
	return wedges
end
-- A four-point sparkle in the frame's XY plane (a plus of two bars and a diamond core), facing -Z.
function Kit:sparkle(name, cf, size, color, mat)
	self:make('Part', name, V(size, size * 0.2, size * 0.2), cf, color, mat)
	self:make('Part', name, V(size * 0.2, size, size * 0.2), cf, color, mat)
	self:make('Part', name, V(size * 0.46, size * 0.46, size * 0.22), cf * CFrame.Angles(0, 0, PI / 4), color, mat)
end
-- A five-arm star lying in the frame's XZ plane (arms are flat bars from the centre).
function Kit:star5(name, cf, R, t, color, mat)
	for k = 0, 4 do
		self:make('Part', name, V(R * 0.36, t, R), cf * CFrame.Angles(0, k * 2 * PI / 5, 0) * CFrame.new(0, 0, -R / 2), color, mat)
	end
	self:cyl(name .. 'Core', cf.Position, 'y', t * 1.05, R * 0.62, color, mat)
end

---------------------------------------------------------------------------------------------- themes
-- Colours sampled from the mock-ups (lit faces), set a little stronger so the hall's light lands on them.
--   body/bodyShade/foot   the tub, its lower band and its foot
--   lid/lidLight/stud     the lid body, its bevel cap, its studs (stud = false: no studs)
--   rim, rimMat           the band between lid and tub (glowing on most boxes, like the pictures)
--   coin/coinFace/mark    the "+1" side coin
--   lidMat/coinMat        optional materials for the lid body and cap, and the coin (default SmoothPlastic)
--   premium               a Robux box: the rainbow band round the tub, a stronger glow, rainbow sparkles
local THEMES = {
	-- (brief 30) World 1's chests: only what the box's light, sparkles and pictures read (their looks are BoxParts')
	Street = { Order = 1, Name = 'Street', Display = 'Street Box', Color = C(222, 56, 48), Accent = C(255, 132, 116) },
	Graffiti = { Order = 2, Name = 'Graffiti', Display = 'Graffiti Box', Color = C(250, 120, 180), Accent = C(90, 210, 246) },
	Frost = {
		Order = 3, Name = 'Frost', Color = C(60, 150, 230), Accent = C(170, 222, 255),
		body = C(70, 156, 226), bodyShade = C(44, 120, 202), foot = C(26, 86, 160),
		lid = C(236, 242, 250), lidLight = C(248, 251, 255), stud = C(224, 234, 246),
		rim = C(40, 122, 214), rimMat = SM,
		coin = C(40, 122, 214), coinFace = C(70, 150, 230), mark = WHITE,
		ice = C(150, 204, 246), iceLight = C(206, 236, 255),
	},
	Lava = {
		Order = 4, Name = 'Lava', Color = C(255, 120, 40), Accent = C(255, 170, 110),
		body = C(48, 30, 30), bodyShade = C(36, 22, 22), foot = C(24, 16, 16),
		lid = C(36, 28, 30), lidLight = C(50, 40, 42), stud = C(30, 24, 26),
		rim = C(230, 96, 28), rimMat = NEON,
		coin = C(255, 166, 112), coinFace = C(255, 190, 140), mark = WHITE,
		drip = C(236, 104, 40), glow = C(236, 96, 26),
	},
	Toxic = {
		Order = 5, Name = 'Toxic', Color = C(110, 214, 70), Accent = C(196, 250, 160),
		body = C(84, 70, 190), bodyShade = C(62, 52, 158), foot = C(40, 34, 110),
		lid = C(112, 214, 66), lidLight = C(144, 232, 98), stud = false,
		rim = C(116, 206, 66), rimMat = NEON,
		coin = C(202, 244, 184), coinFace = C(224, 252, 210), mark = C(110, 200, 80),
		drip = C(112, 214, 66),
	},
	Candy = {
		Order = 6, Name = 'Candy', Color = C(250, 140, 180), Accent = C(200, 190, 255),
		body = C(250, 156, 186), bodyShade = C(236, 128, 164), foot = C(206, 104, 140),
		lid = C(250, 160, 188), lidLight = C(255, 180, 204), stud = C(246, 146, 178),
		rim = C(158, 136, 232), rimMat = NEON,
		coin = C(204, 198, 252), coinFace = C(222, 218, 255), mark = WHITE,
		ribbon = C(150, 140, 240), ribbonDark = C(122, 112, 214),
	},
	Ocean = {
		Order = 7, Name = 'Ocean', Color = C(30, 140, 190), Accent = C(150, 232, 222),
		body = C(22, 112, 164), bodyShade = C(14, 88, 136), foot = C(10, 62, 102),
		lid = C(30, 124, 176), lidLight = C(44, 142, 194), stud = C(36, 132, 186),
		rim = C(64, 186, 176), rimMat = NEON,
		coin = C(160, 232, 222), coinFace = C(196, 244, 236), mark = C(30, 124, 176),
		wave = C(170, 226, 246),
	},
	Gem = {
		Order = 8, Name = 'Gem', Color = C(40, 190, 100), Accent = C(250, 200, 70),
		body = C(26, 160, 86), bodyShade = C(16, 124, 66), foot = C(10, 84, 46),
		lid = C(226, 232, 238), lidLight = C(244, 247, 250), stud = C(214, 222, 230),
		rim = C(250, 200, 64), rimMat = FOIL,
		coin = C(246, 196, 62), coinFace = C(255, 218, 110), mark = WHITE,
		gold = C(246, 196, 62),
	},
	Galaxy = {
		Order = 9, Name = 'Galaxy', Color = C(130, 110, 240), Accent = C(214, 204, 255),
		body = C(30, 32, 86), bodyShade = C(22, 22, 64), foot = C(16, 16, 46),
		lid = C(30, 32, 88), lidLight = C(40, 42, 108), stud = C(60, 72, 186),
		rim = C(146, 124, 232), rimMat = NEON,
		coin = C(206, 200, 252), coinFace = C(226, 222, 255), mark = C(60, 60, 150),
		ringC = C(216, 208, 255),
	},
	Gold = {
		Order = 10, Name = 'Gold', Color = C(250, 186, 40), Accent = C(255, 220, 150),
		body = C(250, 178, 36), bodyShade = C(226, 146, 20), foot = C(184, 110, 14),
		lid = C(246, 194, 66), lidLight = C(255, 212, 96), stud = C(240, 186, 60),
		rim = C(240, 156, 46), rimMat = NEON,
		coin = C(255, 204, 90), coinFace = C(255, 224, 140), mark = WHITE,
		gold = C(255, 196, 50), wing = C(244, 246, 252), wingShade = C(206, 216, 238),
	},
	-- (brief 21) the Robux boxes; (brief 30) shown as the Chrome Box and the Crown Box (their ids stay: saves, receipts)
	Exclusive = { Order = 11, Name = 'Exclusive', Display = 'Chrome Box', Color = C(70, 200, 255), Accent = C(190, 240, 255), premium = true },
	Grail = { Order = 12, Name = 'Grail', Display = 'Crown Box', Color = C(170, 80, 255), Accent = C(255, 210, 80), premium = true },
	-- (brief 30) the Grail Bundle's box (a Store product, not a box you open): its picture and the bundle's reveal
	GrailBundle = { Order = 13, Name = 'GrailBundle', Display = 'The Grail Bundle', Color = C(150, 80, 240), Accent = C(255, 206, 70), premium = true },
}
BoxModels.Meta = {}
for id, t in THEMES do
	BoxModels.Meta[id] = { Name = t.Name, Display = t.Display or (t.Name .. ' Box'), Color = t.Color, Accent = t.Accent, Order = t.Order }
end

---------------------------------------------------------------------------------------------- the common box
-- the stud grid on the lid's cap (x, z); a theme may drop some (skip[i] = true) where its topper sits; one stud size
-- for every box, seated 0.02 into the cap
local STUD_D, STUD_H = 0.56, 0.22
local STUDS = {}
for _, z in { -1.0, 0, 1.0 } do
	for _, x in { -1.6, -0.8, 0, 0.8, 1.6 } do
		table.insert(STUDS, V(x, 0, z))
	end
end

-- The "+1" coin on a side face (sx = 1: +X side, -1: -X side), its mark reading from outside.
local function coin(k, t, sx)
	local x = sx * HW
	k:cyl('Coin', V(x + sx * 0.06, 1.2, 0), 'x', 0.2, 1.36, t.coin, t.coinMat or SM)
	k:cyl('CoinFace', V(x + sx * 0.17, 1.2, 0), 'x', 0.08, 1.04, t.coinFace, t.coinMat or SM)
	-- the viewer's left on this face is +Z * sx
	local mx, left = x + sx * 0.22, sx
	k:box('CoinPlus', V(mx, 1.2, left * 0.17), V(0.06, 0.1, 0.34), t.mark, SM)
	k:box('CoinPlus', V(mx, 1.2, left * 0.17), V(0.06, 0.34, 0.1), t.mark, SM)
	k:box('CoinOne', V(mx, 1.2, -left * 0.2), V(0.06, 0.52, 0.12), t.mark, SM)
	k:box('CoinOne', V(mx, 1.4, -left * 0.2 + left * 0.08), V(0.06, 0.1, 0.12), t.mark, SM)
end

-- Drips hanging from the lid rim along the front (and round the front corners): each a bar and a round tip.
-- spec: list of { x, length, width }; y: the rim's underside.
local function drips(k, color, mat, spec, y)
	for _, d in spec do
		local x, len, w = d[1], d[2], d[3] or 0.34
		local z = -HD - 0.08
		k:box('Drip', V(x, y - len / 2 + 0.06, z), V(w, len, 0.16), color, mat)
		k:ball('DripTip', V(x, y - len + 0.06, z + 0.01), w * 1.04, color, mat)
	end
end

-- the tub (body) and the lid; returns the lid's kit and its topper's kit
local function common(k, t)
	-- tub: a darker foot, the body, a shade band near the bottom (2-3 tones on every face)
	k:rbox('Foot', 0, 0, 0, W - 0.24, 0.38, D - 0.24, 0.42, t.foot, SM)
	k:rbox('Body', 0, 0.3, 0, W, BODY - 0.3, D, 0.5, t.body, SM)
	k:rbox('BodyBand', 0, 0.29, 0, W + 0.04, 0.35, D + 0.04, 0.52, t.bodyShade, SM)
	coin(k, t, 1)
	coin(k, t, -1)
	-- the lid, hinged on the body's back top edge
	local lk, lid = k:model('Lid')
	local hinge = lk:box('Hinge', V(0, BODY, HD), V(0.4, 0.1, 0.1), WHITE, SM)
	hinge.Transparency = 1
	lid.PrimaryPart = hinge
	local gloss = {}
	for _, p in lk:rbox('LidRim', 0, BODY, 0, W + 0.24, 0.24, D + 0.24, 0.62, t.rim, t.rimMat or SM) do table.insert(gloss, p) end
	for _, p in lk:rbox('LidBody', 0, BODY + 0.24, 0, W + 0.16, 0.58, D + 0.16, 0.58, t.lid, t.lidMat or SM) do table.insert(gloss, p) end
	for _, p in lk:rbox('LidCap', 0, TOP - 0.16, 0, W - 0.2, 0.16, D - 0.2, 0.42, t.lidLight, t.lidMat or SM) do table.insert(gloss, p) end
	-- (brief 28) a soft gloss on the lid (the tub's faces stay satin)
	for _, p in gloss do
		if p.Material ~= NEON then p.Reflectance = math.max(p.Reflectance, 0.06) end
	end
	-- the lid's underside (covers the glowing rim's bottom when the lid is open) and the tub's dark inside (shut,
	-- they meet inside the rim)
	lk:span('LidInside', V(-HW + 0.1, BODY - 0.065, -HD + 0.1), V(HW - 0.1, BODY - 0.005, HD - 0.1), t.lid, SM)
	k:span('Inside', V(-HW + 0.3, BODY - 0.05, -HD + 0.3), V(HW - 0.3, BODY + 0.012, HD - 0.3), C(30, 30, 38), SM)
	local tk = lk:model('Topper')
	return lk, tk, lid
end

local function studsOn(lk, t, skip)
	if not t.stud then return end
	for i, p in STUDS do
		if not (skip and skip[i]) then
			lk:cyl('Stud', V(p.X, TOP + STUD_H / 2 - 0.02, p.Z), 'y', STUD_H, STUD_D, t.stud, t.lidMat or SM)
		end
	end
end

-- The Robux boxes' rainbow band: glowing segments in the six rainbow colours round the tub on its shade band (the whole
-- rainbow across the front, two along each side and two across the back), the colours running on round the corners.
local RAINBOW = { C(255, 72, 92), C(255, 160, 40), C(255, 230, 64), C(80, 226, 120), C(60, 180, 255), C(170, 100, 255) }
BoxModels.Rainbow = RAINBOW
local function rainbowBand(k)
	local y0, y1, out = 0.36, 0.56, 0.05
	local i = 0
	local function seg(a, b)
		i += 1
		k:span('RainbowBand', a, b, RAINBOW[(i - 1) % #RAINBOW + 1], NEON)
	end
	local fx = HW - 0.5 -- (the straight part of each face, clear of the rounded corners)
	for j = 0, 5 do
		local x0 = -fx + 2 * fx * j / 6
		seg(V(x0, y0, -HD - out), V(x0 + 2 * fx / 6, y1, -HD + 0.02))
	end
	local fz = HD - 0.5
	for j = 0, 1 do
		local z0 = -fz + 2 * fz * j / 2
		seg(V(HW - 0.02, y0, z0), V(HW + out, y1, z0 + 2 * fz / 2))
	end
	for j = 1, 0, -1 do
		local x0 = -fx + 2 * fx * j / 2
		seg(V(x0, y0, HD - 0.02), V(x0 + 2 * fx / 2, y1, HD + out))
	end
	for j = 1, 0, -1 do
		local z0 = -fz + 2 * fz * j / 2
		seg(V(-HW - out, y0, z0), V(-HW + 0.02, y1, z0 + 2 * fz / 2))
	end
end

---------------------------------------------------------------------------------------------- toppers
-- Each takes (k: the box's kit, lk: the lid's kit, tk: the topper's kit, t: the theme). Positions are scale-1 studs
-- in the box's frame (front -Z), on the lid's cap (y = TOP) or floating over it.
local TOPPERS = {}

-- A snow-capped lid with icicles round the rim, a cluster of ice crystals on top and ice spikes off the corners.
function TOPPERS.Frost(k, lk, tk, t)
	-- snow mounds over the cap (rounded, two tones), a row of snowy studs at the front
	lk:blob('Snow', V(-0.9, TOP + 0.05, 0.2), V(2.6, 0.8, 2.8), t.lidLight, SM)
	lk:blob('Snow', V(1.0, TOP + 0.02, 0.35), V(2.4, 0.66, 2.6), t.lidLight, SM)
	lk:blob('Snow', V(0.1, TOP, -0.6), V(3.2, 0.5, 1.6), C(240, 245, 252), SM)
	for _, x in { -1.6, -0.55, 0.5, 1.55 } do
		lk:cyl('Stud', V(x, TOP + STUD_H / 2 - 0.02, -1.25), 'y', STUD_H, STUD_D, t.stud, SM)
	end
	-- icicles: single wedges (a sheer side and a slant) hanging off the rim's front and sides, alternating
	local icicle = C(214, 238, 255)
	for i, x in { -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0 } do
		local len = (i % 3 == 1) and 0.7 or ((i % 3 == 2) and 0.45 or 0.58)
		local flip = (i % 2 == 0) and PI or 0
		lk:wedge('Icicle', CFrame.new(x, BODY - len / 2 + 0.02, -HD - 0.08) * CFrame.Angles(0, PI / 2 + flip, 0) * CFrame.Angles(PI, 0, 0),
			V(0.14, len, 0.36), icicle, SM)
	end
	for _, sx in { -1, 1 } do
		-- (two, either side of the coin: one over it would run into its rim)
		for j, z in { -0.95, 0.95 } do
			local len = j == 1 and 0.62 or 0.44
			lk:wedge('Icicle', CFrame.new(sx * (HW + 0.08), BODY - len / 2 + 0.02, z) * CFrame.Angles(PI, 0, 0), V(0.14, len, 0.34), icicle, SM)
		end
	end
	-- crystals: square columns turned 45 degrees with a ridged tip, pale blue, glassy
	local function crystal(pos, h, w, lean, col)
		local c = tk:at(CFrame.new(pos) * CFrame.Angles(lean.X, 0, lean.Z))
		c:box('Crystal', V(0, h / 2, 0), V(w, h, w), col, SM, CFrame.Angles(0, PI / 4, 0))
		c:tent('CrystalTip', CFrame.new(0, h + w * 0.42, 0) * CFrame.Angles(0, PI / 4, 0), w * 1.42, w * 0.84, w * 1.42 * 0.5, t.iceLight, SM)
	end
	crystal(V(0.1, TOP + 0.2, 0.4), 1.8, 0.62, V(0, 0, 0.05), t.ice)
	crystal(V(-0.75, TOP + 0.2, 0.0), 1.15, 0.5, V(0.1, 0, 0.3), t.ice)
	crystal(V(0.9, TOP + 0.15, 0.1), 0.85, 0.48, V(-0.1, 0, -0.35), t.ice)
	crystal(V(0.55, TOP + 0.15, 1.0), 0.65, 0.44, V(0.35, 0, -0.1), C(130, 186, 236))
	crystal(V(-0.4, TOP + 0.1, -0.75), 0.6, 0.42, V(-0.3, 0, 0.1), C(170, 214, 248))
	-- ice spikes off the lid's four corners, pointing out and up
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local base = V(c[1] * (HW - 0.3), BODY + 0.55, c[2] * (HD - 0.3))
		local out = V(c[1] * 0.75, 0.55, c[2] * 0.45).Unit
		local cf = CFrame.lookAt(base + out * 0.9, base + out * 2) * CFrame.Angles(-PI / 2, 0, 0)
		lk:tent('IceSpike', cf, 0.5, 1.9, 0.34, t.ice, SM)
		lk:tent('IceSpike', cf * CFrame.Angles(0, PI / 2, 0), 0.5, 1.9, 0.34, C(176, 220, 252), SM)
	end
end

-- A stepped volcano on the black lid with a glowing crater and lava running down it; glowing cracks on the tub,
-- glowing lava dripping off the rim.
function TOPPERS.Lava(k, lk, tk, t)
	studsOn(lk, t, { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true, [8] = true, [9] = true, [11] = true, [12] = true, [13] = true, [14] = true })
	drips(lk, t.drip, NEON, { { -1.95, 0.7 }, { -1.4, 0.42 }, { -0.8, 0.34 }, { -0.2, 0.46, 0.38 }, { 0.4, 0.36 }, { 1.0, 0.44 }, { 1.55, 0.36 }, { 2.0, 0.8 } }, BODY + 0.1)
	-- glowing zigzag cracks on the tub's front corners and sides (three short neon bars each)
	local function crack(cf)
		local c = k:at(cf)
		c:box('Crack', V(0, 0.32, 0), V(0.1, 0.42, 0.06), t.glow, NEON, CFrame.Angles(0, 0, 0.55))
		c:box('Crack', V(0.04, 0, 0), V(0.1, 0.42, 0.06), t.glow, NEON, CFrame.Angles(0, 0, -0.55))
		c:box('Crack', V(0, -0.32, 0), V(0.1, 0.42, 0.06), t.glow, NEON, CFrame.Angles(0, 0, 0.55))
	end
	crack(CFrame.new(-1.88, 1.05, -HD - 0.02))
	crack(CFrame.new(1.88, 1.05, -HD - 0.02))
	-- (on the sides, beside the coin rather than under it)
	crack(CFrame.new(HW + 0.02, 1.0, -1.0) * CFrame.Angles(0, PI / 2, 0))
	crack(CFrame.new(-HW - 0.02, 1.0, 1.0) * CFrame.Angles(0, PI / 2, 0))
	-- the volcano: an eight-sided cone of grey-brown rock (two tones), a dark crater rim with glowing lava in it,
	-- three lava runs down its slopes and a lava blob popping out
	local rb, rt, h = 1.55, 0.62, 1.95
	local v = tk:at(CFrame.new(-0.35, TOP - 0.02, 0.15))
	v:frustum('Volcano', CFrame.identity, rb, rt, h, 8, { C(84, 70, 72), C(66, 56, 60) }, SM)
	v:cyl('VolcanoTop', V(0, h - 0.06, 0), 'y', 0.12, 2 * rt / math.cos(PI / 8), C(66, 56, 60), SM)
	v:cyl('CraterRim', V(0, h + 0.06, 0), 'y', 0.16, 1.5, C(48, 40, 44), SM)
	v:cyl('Crater', V(0, h + 0.1, 0), 'y', 0.12, 1.1, C(255, 120, 40), NEON)
	local L = math.sqrt(h * h + (rb - rt) ^ 2)
	local phi = math.atan2(rb - rt, h)
	for _, j in { 6, 7, 1 } do
		local a = j * 2 * PI / 8
		local u = V(math.cos(a), 0, math.sin(a))
		local at = u * (rb + rt) / 2 + V(0, h / 2, 0)
		local n = V(0, rb - rt, -h).Unit
		v:make('Part', 'LavaRun', V(0.2, L * (j == 7 and 0.95 or 0.7), 0.06), CFrame.lookAt(at, at + u) * CFrame.new(n * 0.03 + V(0, j == 7 and 0 or 0.25, j == 7 and 0 or 0.11)) * CFrame.Angles(phi, 0, 0), t.glow, NEON)
	end
	v:ball('LavaBlob', V(0.15, h + 0.38, -0.1), 0.34, C(255, 150, 70), NEON)
	v:ball('LavaBlob', V(-0.3, h + 0.62, 0.15), 0.22, C(255, 150, 70), NEON)
end

-- A slime-green lid with slime oozing down the front, two googly eyes on stalks and slime bubbles.
function TOPPERS.Toxic(k, lk, tk, t)
	-- slime drips: long and wide, two running all the way down the front corners
	drips(lk, t.drip, SM, { { -1.9, 1.95, 0.44 }, { -1.35, 0.6 }, { -0.8, 0.44, 0.4 }, { -0.25, 0.36 }, { 0.3, 0.47, 0.42 }, { 0.85, 0.36 }, { 1.4, 0.62 }, { 1.95, 1.8, 0.44 } }, BODY + 0.12)
	for _, sx in { -1, 1 } do
		-- (beside the side coin, in front of it, not over its mark)
		lk:box('SideDrip', V(sx * (HW + 0.1), BODY - 0.3, -0.95), V(0.14, 0.7, 0.4), t.drip, SM)
		lk:ball('SideDripTip', V(sx * (HW + 0.1), BODY - 0.64, -0.95), 0.42, t.drip, SM)
	end
	-- a slime puddle on the lid and the eyes on stalks
	lk:blob('Slime', V(0.5, TOP, 0.0), V(3.0, 0.5, 2.4), C(96, 196, 56), SM)
	for i, e in { { -0.25, -0.1 }, { 1.25, 0.05 } } do
		local x, z = e[1], e[2]
		tk:cyl('EyeStalk', V(x, TOP + 0.45, z), 'y', 0.7, 0.18, C(84, 180, 50), SM)
		tk:ball('Eye', V(x, TOP + 1.25, z), 1.12, C(244, 246, 248), SM)
		tk:ball('Pupil', V(x + (i == 1 and 0.08 or -0.06), TOP + 1.2, z - 0.38), 0.52, C(26, 28, 34), SM)
		tk:ball('Glint', V(x + (i == 1 and 0.0 or -0.14), TOP + 1.34, z - 0.62), 0.14, WHITE, SM)
	end
	-- bubbles at the back left (see-through, bobbing on display)
	local bubbles = tk:floating('Bubbles', V(-1.3, TOP + 0.9, 0.6), nil, 0.12, 1.9)
	for _, e in { { -1.4, 0.55, 0.6, 1.0 }, { -0.95, 1.05, 0.9, 0.66 }, { -1.6, 1.25, 0.3, 0.46 } } do
		local b = bubbles:ball('Bubble', V(e[1], TOP + e[2], e[3]), e[4], C(190, 246, 160), SM)
		b.Transparency = 0.35
		b.CastShadow = false
	end
end

-- A pink box tied with a lavender ribbon and bow, sprinkles on the lid, two swirl lollipops.
function TOPPERS.Candy(k, lk, tk, t)
	studsOn(lk, t, { [5] = true, [10] = true, [15] = true, [13] = true })
	-- white swirl stripes on the tub (slanted bars on the front and sides)
	local cream = C(255, 244, 248)
	for _, x in { -0.2, 1.95 } do
		k:box('CandyStripe', V(x, 1.0, -HD - 0.025), V(0.42, 1.9, 0.06), cream, SM, CFrame.Angles(0, 0, 0.6))
	end
	for _, sx in { -1, 1 } do
		for _, z in { -0.9, 0.9 } do
			k:box('CandyStripe', V(sx * (HW + 0.025), 1.1, z), V(0.06, 1.7, 0.42), cream, SM, CFrame.Angles(0.55 * sx, 0, 0))
		end
	end
	-- the ribbon: over the lid front to back at x = -1.45, down the lid's front and the tub's front
	local rx = 1.45
	lk:span('Ribbon', V(rx - 0.3, TOP - 0.02, -HD - 0.1), V(rx + 0.3, TOP + 0.04, HD + 0.1), t.ribbon, SM)
	lk:span('Ribbon', V(rx - 0.3, BODY - 0.02, -HD - 0.14), V(rx + 0.3, TOP + 0.04, -HD - 0.08), t.ribbon, SM)
	k:span('Ribbon', V(rx - 0.3, 0.3, -HD - 0.06), V(rx + 0.3, BODY, -HD + 0.02), t.ribbon, SM)
	-- the bow: two puffy loops tilted up and out from a knot (a darker hollow in each), two tails
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(rx + sx * 0.7, TOP + 0.9, -0.95) * CFrame.Angles(0, sx * 0.3, sx * -0.42)
		tk:blob('BowLoop', cf.Position, V(1.4, 1.05, 0.44), t.ribbon, SM, cf.Rotation)
		tk:blob('BowLoopHollow', (cf * CFrame.new(sx * 0.08, 0, -0.17)).Position, V(0.72, 0.48, 0.2), t.ribbonDark, SM, cf.Rotation)
		tk:box('BowTail', V(rx + sx * 0.3, TOP + 0.2, -1.4), V(0.26, 0.08, 0.7), t.ribbonDark, SM, CFrame.Angles(0, sx * 0.5, 0))
	end
	tk:ball('BowKnot', V(rx, TOP + 0.62, -0.95), 0.6, t.ribbonDark, SM)
	-- sprinkles: little bars in five colours scattered on the cap
	local sprinkle = { C(120, 220, 190), C(170, 150, 250), C(255, 220, 90), WHITE, C(90, 170, 250) }
	for i, e in { { -0.45, -0.55, 0.3 }, { 0.3, 0.6, 1.2 }, { 0.95, -0.5, 2.2 }, { 1.55, 0.5, 0.7 }, { -0.1, 0.95, 2.6 }, { 0.6, -1.15, 1.8 }, { 1.85, -0.9, 0.2 }, { -0.75, 0.3, 1.0 } } do
		lk:box('Sprinkle', V(e[1], TOP + 0.05, e[2]), V(0.34, 0.1, 0.1), sprinkle[(i - 1) % 5 + 1], SM, CFrame.Angles(0, e[3], 0))
	end
	-- lollipops: a white stick and a round candy facing the front with a white swirl on it (bars along a spiral)
	local function lolly(x, z, h, d, col, lean)
		local c = tk:at(CFrame.new(x, TOP, z) * CFrame.Angles(0, 0, lean))
		c:cyl('LollyStick', V(0, h / 2, 0), 'y', h, 0.14, C(244, 244, 248), SM)
		local cy = h + d / 2 - 0.1
		c:cyl('Lolly', V(0, cy, 0), 'z', 0.32, d, col, SM)
		c:cyl('LollyRim', V(0, cy, 0.02), 'z', 0.3, d + 0.08, col:Lerp(C(0, 0, 0), 0.15), SM)
		local prev = nil
		for i = 0, 9 do
			local th = i * PI / 2.6
			local r = d / 2 * (0.06 + 0.8 * i / 9)
			local p = V(math.cos(th) * r, cy + math.sin(th) * r, -0.18)
			if prev then
				local m = (p + prev) / 2
				c:make('Part', 'LollySwirl', V((p - prev).Magnitude + 0.06, d * 0.09, 0.06), CFrame.new(m) * CFrame.Angles(0, 0, math.atan2(p.Y - prev.Y, p.X - prev.X)), WHITE, SM)
			end
			prev = p
		end
	end
	lolly(-1.15, 0.35, 1.6, 1.6, C(236, 84, 150), 0.12)
	lolly(0.2, 0.75, 2.2, 1.2, C(120, 216, 186), -0.1)
end

-- A teal box with wave lines, an open clam with a pearl, a coral starfish and rising bubbles.
function TOPPERS.Ocean(k, lk, tk, t)
	studsOn(lk, t, { [1] = true, [2] = true, [6] = true, [7] = true, [5] = true, [10] = true, [14] = true, [15] = true })
	-- wave lines: short tilted bars either side of the coin on the sides and a row across the back, all on the flat of
	-- each face (the front stays plain)
	for _, sx in { -1, 1 } do
		for j, z in { -0.95, 0.95 } do
			local tilt = (j == 1 and 0.4 or -0.4)
			k:box('Wave', V(sx * (HW + 0.025), 0.95 + (j - 1) * 0.16, z), V(0.06, 0.17, 0.5), t.wave, SM, CFrame.Angles(tilt, 0, 0))
			k:box('Wave', V(sx * (HW + 0.025), 1.55 + (j - 1) * 0.16, z), V(0.06, 0.17, 0.5), t.wave, SM, CFrame.Angles(tilt, 0, 0))
		end
	end
	for j = 0, 4 do
		k:box('Wave', V(-1.36 + j * 0.68, 1.2 + (j % 2) * 0.16, HD + 0.025), V(0.64, 0.17, 0.06), t.wave, SM, CFrame.Angles(0, 0, (j % 2 == 0 and 0.4 or -0.4)))
	end
	-- the clam: a bottom shell, a top shell open behind it, ridges on the top shell, a big pearl
	local shell, shellDark = C(250, 204, 194), C(236, 170, 164)
	local c = tk:at(CFrame.new(-0.8, TOP + 0.1, -0.1))
	-- each half a fan of five ribs (flattened ellipsoids) from the hinge at the back: a scalloped edge, two tones
	for j = -2, 2 do
		local fan = CFrame.new(0, 0.12, 0.85) * CFrame.Angles(0, j * 0.34, 0)
		c:blob('Shell', (fan * CFrame.new(0, 0, -0.95)).Position, V(0.74, 0.36, 2.05), j % 2 == 0 and shell or shellDark, SM, fan.Rotation)
		local up = CFrame.new(0, 0.3, 0.85) * CFrame.Angles(1.72, 0, 0) * CFrame.Angles(0, j * 0.34, 0)
		c:blob('ShellTop', (up * CFrame.new(0, 0, -0.95)).Position, V(0.74, 0.32, 2.05), j % 2 == 0 and shellDark or shell, SM, up.Rotation)
	end
	c:ball('Pearl', V(0, 0.82, -0.25), 1.15, C(250, 248, 252), SM)
	-- the starfish on the front right of the lid
	tk:star5('Starfish', CFrame.new(1.25, TOP + 0.1, -0.55) * CFrame.Angles(0, 0.3, 0), 0.95, 0.2, C(240, 116, 96), SM)
	-- bubbles rising off the back right (bobbing on display)
	local bubbles = tk:floating('Bubbles', V(1.6, TOP + 1.8, 1.0), nil, 0.2, 2.2)
	for _, e in { { 1.4, 0.7, 0.9, 0.8 }, { 1.7, 1.55, 0.95, 0.62 }, { 1.45, 2.3, 1.0, 0.5 }, { 1.8, 2.95, 1.05, 0.36 } } do
		local b = bubbles:ball('Bubble', V(e[1], TOP + e[2], e[3]), e[4], C(150, 214, 240), GLASS)
		b.Transparency = 0.3
	end
end

-- A green box under a white lid with a gold rim and red gems, a gold crown ring holding a cluster of crystals.
function TOPPERS.Gem(k, lk, tk, t)
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true, [14] = true })
	-- glass highlights: pale slanted streaks on the tub's front and sides
	for _, e in { { -1.85, 1.1 }, { 1.9, 0.9 } } do
		k:box('Glint', V(e[1], e[2], -HD - 0.025), V(0.16, 1.1, 0.06), C(120, 226, 160), SM, CFrame.Angles(0, 0, 0.5))
	end
	for _, sx in { -1, 1 } do
		k:box('Glint', V(sx * (HW + 0.025), 1.2, -0.9 * sx), V(0.06, 1.2, 0.16), C(120, 226, 160), SM, CFrame.Angles(0.5, 0, 0))
	end
	-- red gems along the rim's front (diamonds), small gold corner caps
	for _, x in { -1.3, 0, 1.3 } do
		lk:box('RimGem', V(x, BODY + 0.12, -HD - 0.16), V(0.32, 0.32, 0.12), C(244, 88, 76), SM, CFrame.Angles(0, 0, PI / 4))
	end
	-- the crown ring: an octagon of gold bars on the cap, four posts with gold knobs
	local ring = tk:at(CFrame.new(0, TOP + 0.12, 0))
	ring:ring('CrownRing', CFrame.identity, 1.2, 8, 0.22, 0.24, t.gold, FOIL)
	for j = 0, 3 do
		local a = j * PI / 2 + PI / 4
		local p = V(math.cos(a) * 1.2, 0, math.sin(a) * 1.2)
		ring:cyl('CrownPost', p + V(0, 0.35, 0), 'y', 0.5, 0.18, t.gold, FOIL)
		ring:ball('CrownKnob', p + V(0, 0.7, 0), 0.34, C(255, 214, 90), FOIL)
	end
	-- crystals: a tall green one in the middle, a blue and two red ones round it, pale tips
	local function crystal(pos, h, w, lean, col)
		local c = tk:at(CFrame.new(pos) * CFrame.Angles(lean.X, 0, lean.Z))
		c:box('Crystal', V(0, h / 2, 0), V(w, h, w), col, SM, CFrame.Angles(0, PI / 4, 0))
		c:tent('CrystalTip', CFrame.new(0, h + w * 0.4, 0) * CFrame.Angles(0, PI / 4, 0), w * 1.42, w * 0.8, w * 0.71, C(226, 246, 236), SM)
	end
	crystal(V(0.0, TOP + 0.1, 0.15), 2.3, 0.72, V(0, 0, 0), C(40, 190, 96))
	crystal(V(-0.75, TOP + 0.1, 0.05), 1.5, 0.56, V(0.05, 0, 0.3), C(44, 112, 232))
	crystal(V(0.78, TOP + 0.1, -0.2), 1.1, 0.54, V(-0.15, 0, -0.32), C(232, 52, 72))
	crystal(V(0.55, TOP + 0.1, 0.75), 1.35, 0.5, V(0.3, 0, -0.15), C(214, 40, 64))
end

-- A navy box under a starry lid, a lavender ring orbiting it, a ringed orange planet and a crescent moon.
function TOPPERS.Galaxy(k, lk, tk, t)
	studsOn(lk, t)
	-- stars and nebula specks on the tub (flat), little stars on the lid
	for _, e in { { -1.85, 1.6 }, { 1.85, 0.55 }, { -0.5, 0.45 }, { 0.9, 1.95 } } do
		k:box('StarSpeck', V(e[1], e[2], -HD - 0.03), V(0.14, 0.14, 0.06), C(230, 230, 255), SM, CFrame.Angles(0, 0, PI / 4))
	end
	for _, sx in { -1, 1 } do
		k:cyl('Nebula', V(sx * (HW + 0.025), 0.75, sx * 0.95), 'x', 0.06, 0.56, C(92, 70, 180), SM) -- (clear of the coin)
		k:box('StarSpeck', V(sx * (HW + 0.03), 1.75, -sx * 0.8), V(0.06, 0.14, 0.14), C(230, 230, 255), SM, CFrame.Angles(PI / 4, 0, 0))
	end
	for _, e in { { -1.2, -0.5 }, { 0.4, 0.5 }, { 1.2, -0.5 }, { -0.4, 0.5 } } do
		lk:sparkle('LidStar', CFrame.new(e[1], TOP + 0.04, e[2]) * CFrame.Angles(-PI / 2, 0, 0.3), 0.6, C(236, 236, 255), SM)
	end
	-- the orbit ring round the box (16 bars), tilted
	local orbit = tk:floating('Orbit', V(0, BODY + 0.3, 0), 24)
	orbit:ring('OrbitRing', CFrame.new(0, BODY + 0.3, 0) * CFrame.Angles(0.12, 0, 0.18), 3.3, 24, 0.26, 0.2, t.ringC, SM)
	-- the planet with its own ring, at the back left
	local pc = CFrame.new(-1.55, TOP + 2.0, 0.85)
	local planet = tk:floating('Planet', pc.Position, 30, 0.15, 3.1)
	planet:ball('Planet', pc.Position, 1.25, C(232, 150, 76), SM)
	planet:blob('PlanetBand', pc.Position, V(1.27, 0.3, 1.27), C(210, 120, 60), SM)
	planet:ring('PlanetRing', pc * CFrame.Angles(0.3, 0, -0.35), 1.0, 12, 0.11, 0.1, C(236, 228, 255), SM)
	-- the crescent moon at the back right: bars on an arc, thick in the middle
	local mc = CFrame.new(1.5, TOP + 1.7, 0.8) * CFrame.Angles(0, -0.4, 0.25)
	for j = -2, 2 do
		local a = j * 0.42
		local th = 0.5 - math.abs(j) * 0.11
		tk:make('Part', 'Moon', V(th, 0.6, 0.34), mc * CFrame.Angles(0, 0, a) * CFrame.new(0.85, 0, 0), C(226, 220, 196), NEON)
	end
	-- floating stars
	for _, e in { { 2.4, 1.0, -0.6, 0.55 }, { -2.5, 0.8, -0.3, 0.5 }, { 0.3, 2.2, 0.2, 0.42 } } do
		tk:sparkle('Star', CFrame.new(e[1], TOP + e[2], e[3]) * CFrame.Angles(0, 0, 0.2), e[4], C(232, 228, 255), SM)
	end
end

-- A gold box under a glowing rim: a gold crown with a red velvet dome, pearl tips and gems, a halo over it, white
-- wings on both sides and a little stack of +1 coins at its foot.
function TOPPERS.Gold(k, lk, tk, t)
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true, [14] = true })
	local cr = tk:at(CFrame.new(0, TOP, 0.05))
	cr:cyl('CrownBand', V(0, 0.42, 0), 'y', 0.84, 2.3, t.gold, FOIL)
	cr:cyl('CrownBandLip', V(0, 0.08, 0), 'y', 0.16, 2.42, C(232, 160, 30), FOIL)
	cr:blob('Velvet', V(0, 0.95, 0), V(1.9, 1.4, 1.9), C(226, 58, 70), SM)
	-- five points round the band, each with a pearl
	for j = 0, 4 do
		local a = j * 2 * PI / 5 + PI / 2
		local p = V(math.cos(a) * 1.02, 0.84, math.sin(a) * 1.02)
		local cf = CFrame.lookAt(p, V(0, 0.84, 0)) * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, PI / 2, 0)
		cr:tent('CrownPoint', cf, 0.84, 0.95, 0.16, t.gold, FOIL)
		cr:ball('CrownPearl', p + V(0, 0.98, 0), 0.34, C(252, 250, 246), SM)
	end
	-- gems on the band's front
	cr:box('CrownGem', V(-0.55, 0.45, -1.1), V(0.3, 0.3, 0.12), C(244, 92, 92), SM, CFrame.Angles(0, 0.45, PI / 4))
	cr:box('CrownGem', V(0.55, 0.45, -1.1), V(0.3, 0.3, 0.12), C(100, 160, 250), SM, CFrame.Angles(0, -0.45, PI / 4))
	-- the halo
	local halo = tk:floating('Halo', V(0, TOP + 3.0, 0.05), 40, 0.15, 2.4)
	halo:ring('Halo', CFrame.new(0, TOP + 3.0, 0.05) * CFrame.Angles(-0.25, 0, 0), 0.95, 12, 0.16, 0.14, C(255, 248, 226), NEON)
	-- wings: three long rounded feathers fanned up and out from a root on each side (the longest on top), layered
	-- white over a pale blue shade
	for _, sx in { -1, 1 } do
		local wc = k:at(CFrame.new(sx * (HW + 0.15), 1.7, 1.15) * CFrame.Angles(0, sx * -0.4, 0)) -- (behind the side coin)
		for j, e in { { 0.45, 3.1, 1.15 }, { 0.95, 2.6, 1.05 }, { 1.45, 2.05, 0.95 } } do
			local a = sx * -e[1]
			local f = CFrame.Angles(0, 0, a) * CFrame.new(0, e[2] / 2, (j - 2) * 0.1)
			wc:blob('Feather', f.Position, V(e[3], e[2], 0.36), j == 3 and t.wingShade or t.wing, SM, f.Rotation)
		end
		wc:ball('WingRoot', V(0, 0.15, 0), 0.9, t.wing, SM)
	end
	-- a short stack of coins at the front right foot
	for j = 0, 2 do
		k:cyl('CoinStack', V(-2.55 + j * 0.04, 0.09 + j * 0.17, -1.35 - j * 0.03), 'y', 0.16, 0.9, j == 1 and C(240, 180, 50) or C(255, 204, 80), FOIL)
	end
end

---------------------------------------------------------------------------------------------- build
-- (brief 30) A chest from its BoxKit rows: the tub's parts in the model, the lid's in `Lid` (pivot: its Hinge part)
-- and the handle in `Lid.Topper`. Materials: BoxKit's kinds as Roblox materials (gold = Foil, neon, glass).
local KIND_MAT = { plastic = M.Plastic, smooth = SM, metal = M.Metal, neon = NEON, gold = FOIL, glass = GLASS }
local function chest(k, data)
	local lk, lid = k:model('Lid')
	local tk = lk:model('Topper')
	local hinge
	for _, r in data.Parts do
		local into = r[12] == 'l' and lk or r[12] == 't' and tk or k
		local shape = r[1]
		local rot = BoxParts.Rots[r[10]]
		local cf = CFrame.new(r[7], r[8], r[9], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
		local kind = BoxParts.Kinds[r[3]]
		local p = into:make(shape == 'W' and 'WedgePart' or 'Part', r[11], V(r[4], r[5], r[6]), cf, BoxParts.Colors[r[2]], KIND_MAT[kind] or SM)
		if shape == 'C' then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == 'S' then
			p.Shape = Enum.PartType.Ball
		elseif shape == 'E' then
			local mesh = Instance.new('SpecialMesh')
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		if kind == 'glass' then p.Transparency = 0.3 end
		-- (brief 30, "make the boxes look more attractive": the sheets' gloss) a little shine on the paint, more on the
		-- gold and the metal trim
		if kind == 'smooth' or kind == 'plastic' then p.Reflectance = 0.08
		elseif kind == 'gold' then p.Reflectance = 0.2
		elseif kind == 'metal' then p.Reflectance = 0.15 end
		if r[11] == 'Hinge' then
			hinge = p
			p.Transparency = 1
			p.CastShadow = false
		end
	end
	assert(hinge, 'BoxModels: a chest without its Hinge')
	lid.PrimaryPart = hinge
	return lid
end

-- at: where to build it (its pivot), so a caller needs no PivotTo (default: the origin).
function BoxModels.build(boxId: string, scale: number?, at: CFrame?): Model
	local t = THEMES[boxId]
	assert(t, 'BoxModels.build: unknown box ' .. tostring(boxId))
	local s = scale or 1
	local model = Instance.new('Model')
	model.Name = boxId .. 'Box'
	local k = newKit(model, s, at)
	local root = k:box('Root', V(0, 0, 0), V(1, 0.2, 1), WHITE, SM)
	root.Transparency = 1
	model.PrimaryPart = root
	local data = BoxParts and BoxParts.Boxes[boxId]
	local lid
	if data then
		lid = chest(k, data)
	else
		assert(TOPPERS[boxId], 'BoxModels.build: no model for ' .. tostring(boxId))
		local lk, tk
		lk, tk, lid = common(k, t)
		TOPPERS[boxId](k, lk, tk, t)
	end
	lid.WorldPivot = lid.PrimaryPart.CFrame
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then n += 1 end
	end
	assert(n <= LIMIT, 'BoxModels: ' .. boxId .. ' has ' .. n .. ' parts')
	model:SetAttribute('BoxId', boxId)
	model:SetAttribute('Parts', n)
	model:SetAttribute('Scale', s)
	return model
end

-- Pose the lid: t = 0 shut .. 1 open (the lid swings up and back about its hinge on the body's back top edge).
function BoxModels.openLid(model: Model, t: number)
	local lid = model:FindFirstChild('Lid') :: Model
	local root = model.PrimaryPart
	if not (lid and root) then return end
	local s = model:GetAttribute('Scale') or 1
	local target = root.CFrame * CFrame.new(0, BODY * s, HD * s) * CFrame.Angles(math.rad(110) * math.clamp(t, 0, 1), 0, 0)
	-- move every lid part by the hinge's change (same as lid:PivotTo(target), without depending on the pivot)
	local delta = target * lid.PrimaryPart.CFrame:Inverse()
	for _, p in lid:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end
	end
end

-- Set a box on display moving: its floating pieces (the orbit ring, planet, halo, bubbles, paint puff) get WorldMotion's
-- HoodMotion tag with their Spin/Bob/BobPeriod. Only for boxes that stay put (not one the client is shaking).
function BoxModels.animate(model: Model)
	-- (brief 30) a chest on display bobs gently (WorldMotion moves the whole model)
	local id = model:GetAttribute('BoxId')
	if id and BoxParts and BoxParts.Boxes[id] then
		model:SetAttribute('Bob', 0.12 * (model:GetAttribute('Scale') or 1))
		model:SetAttribute('BobPeriod', 2.8)
		model:AddTag('HoodMotion')
	end
	for _, m in model:GetDescendants() do
		if m:IsA('Model') and (m:GetAttribute('AnimSpin') or m:GetAttribute('AnimBob')) then
			m:SetAttribute('Spin', m:GetAttribute('AnimSpin'))
			m:SetAttribute('Bob', m:GetAttribute('AnimBob'))
			m:SetAttribute('BobPeriod', m:GetAttribute('AnimPeriod'))
			m:AddTag('HoodMotion')
		end
	end
end

-- The ambient effect of a box on display: a slow theme particle round it and a soft light in its colour.
-- (textures are Roblox built-ins; the PreviewTexture attribute tells the offline previewer the intended look)
local FX = {
	Street = { 'sparkles_main', 'sparkle', C(255, 255, 255), 2, 0.5 },
	Graffiti = { 'sparkles_main', 'glitter', C(255, 160, 210), 2.5, 0.45 },
	Frost = { 'sparkles_main', 'snow', C(230, 244, 255), 4, 0.5 },
	Lava = { 'fire_main', 'ember', C(255, 150, 60), 4, 0.35 },
	Toxic = { 'sparkles_main', 'bubble', C(170, 250, 120), 3, 0.5 },
	Candy = { 'sparkles_main', 'confetti', C(255, 190, 220), 3, 0.4 },
	Ocean = { 'explosion01_shockwave_main', 'bubble', C(190, 236, 255), 3, 0.45 },
	Gem = { 'sparkles_main', 'glitter', C(170, 255, 200), 4, 0.5 },
	Galaxy = { 'sparkles_main', 'star', C(220, 210, 255), 4, 0.55 },
	Gold = { 'sparkles_main', 'star', C(255, 226, 120), 5, 0.6 },
	Exclusive = { 'sparkles_main', 'sparkle', C(170, 240, 255), 6, 0.55 },
	Grail = { 'sparkles_main', 'star', C(255, 226, 120), 6, 0.6 },
	GrailBundle = { 'sparkles_main', 'star', C(255, 226, 120), 6, 0.6 },
}
function BoxModels.fx(model: Model)
	local id = model:GetAttribute('BoxId')
	local f = id and FX[id]
	local root = model.PrimaryPart
	if not (f and root) then return end
	local s = model:GetAttribute('Scale') or 1
	-- an invisible volume round the lid and topper that the particles spawn in
	local a = Instance.new('Part')
	a.Name = 'FxVolume'
	a.Anchored, a.CanCollide, a.CanTouch, a.CanQuery, a.CastShadow = true, false, false, false, false
	a.Transparency = 1
	a.Size = V(W + 1.6, 3.2, D + 1.6) * s
	a.CFrame = root.CFrame * CFrame.new(0, 3.6 * s, 0)
	a.Parent = model
	local e = Instance.new('ParticleEmitter')
	e.Name = 'BoxSparkle'
	e.Texture = 'rbxasset://textures/particles/' .. f[1] .. '.dds'
	e:SetAttribute('PreviewTexture', f[2])
	e.Color = ColorSequence.new(f[3])
	e.LightEmission = 0.6
	e.LightInfluence = 0
	e.Rate = f[4]
	e.Lifetime = NumberRange.new(1.4, 2.4)
	e.Speed = NumberRange.new(0.4, 1.1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = V(0, id == 'Frost' and -0.6 or 0.5, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, f[5] * s), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = a
	local premium = THEMES[id].premium
	if premium then
		-- the Robux boxes: rainbow sparkles too
		local r = e:Clone()
		r.Name = 'BoxRainbow'
		local keys = {}
		for i, c in RAINBOW do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), c)) end
		r.Color = ColorSequence.new(keys)
		r:SetAttribute('PreviewTexture', 'sparkle')
		r.Rate = 3
		r.LightEmission = 1
		r.Parent = a
	end
	local l = Instance.new('PointLight')
	l.Name = 'BoxGlow'
	l.Color = THEMES[id].Color
	-- (a little stronger and wider on the Robux boxes, still a short pool: LIGHT2 asks for no long bright lights)
	l.Brightness = premium and 1.1 or 0.8
	l.Range = (premium and 10 or 8) * s
	l.Shadows = false
	l.Parent = root
	-- (brief 30) a chest's idle glow: a soft line of its accent colour where the lid meets the tub, with a short light
	-- from inside it, so the shut chest looks charged
	if BoxParts and BoxParts.Boxes[id] then
		local seam = Instance.new('Part')
		seam.Name = 'SeamGlow'
		seam.Anchored, seam.CanCollide, seam.CanTouch, seam.CanQuery, seam.CastShadow = true, false, false, false, false
		seam.Material = NEON
		seam.Color = THEMES[id].Accent
		seam.Transparency = 0.45
		seam.Size = V(W + 0.05, 0.07, D + 0.05) * s
		seam.CFrame = root.CFrame * CFrame.new(0, (BODY + 0.03) * s, 0)
		seam.Parent = model
		local sl = Instance.new('PointLight')
		sl.Name = 'SeamLight'
		sl.Color = THEMES[id].Accent
		sl.Brightness = 0.7
		sl.Range = 5 * s
		sl.Shadows = false
		sl.Parent = seam
		-- and a soft glow disc under it in its colour (the lead: "vibrant ... nice effects on items")
		local disc = Instance.new('Part')
		disc.Name = 'GlowDisc'
		disc.Shape = Enum.PartType.Cylinder
		disc.Anchored, disc.CanCollide, disc.CanTouch, disc.CanQuery, disc.CastShadow = true, false, false, false, false
		disc.Material = NEON
		disc.Color = THEMES[id].Color
		disc.Transparency = 0.72
		disc.Size = V(0.05, W * 1.25, W * 1.25) * s
		disc.CFrame = root.CFrame * CFrame.new(0, 0.03 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
		disc.Parent = model
	end
end

return BoxModels
