-- BoxModels: the 12 shoe boxes ("eggs" of the shoe system), part-built in Luau (no meshes, no uploads), after the
-- user's mock-up renders (shoes_in/Shoes_And_Boxes_Detailed/<NN>_<Box>_Box/0_<Box>_Box.jpg), tuned to the game's
-- studded toy style: a chunky rounded tub on a darker foot, a framed name plate ("STREET / SHOE BOX"), a "+1" coin
-- on each side, and a lid (rim band, body, bevel cap, big studs) carrying the box's theme topper.
-- The two Robux boxes (brief 21: Exclusive and Grail, World 1's "Robux Exclusive" eggs) wear a premium finish the
-- Cash boxes never have: a glowing rainbow band round the tub, a metal (chrome or gold) lid, a big floating topper (a
-- spinning cut diamond; a golden winged sneaker under a rainbow halo), a stronger glow and rainbow sparkles.
--   BoxModels.build(boxId, scale?, at?) -> Model   closed box, pivot = bottom centre (PrimaryPart `Root`), front -Z;
--               built at CFrame `at` (default the origin)
--     .Lid      sub-model (rim, lid, studs, drips and the `Topper` model); its pivot (PrimaryPart `Hinge`) is the
--               hinge on the body's back top edge, so the client can pop it open (see BoxModels.openLid)
--   BoxModels.openLid(model, t)    poses the lid: t = 0 shut .. 1 wide open (about 110 degrees)
--   BoxModels.fx(model)            the box's ambient effect (theme particles and a soft light); optional
--   BoxModels.animate(model)       sets its floating pieces moving (WorldMotion's HoodMotion tag); for boxes on display
--   BoxModels.Ids, BoxModels.Meta[id] = { Name, Color, Accent, Order }, BoxModels.Size (scale-1 studs)
-- Every part is Anchored, CanCollide/CanTouch/CanQuery false; studs, neon, glass and small trim cast no shadow.
-- Scale 1: the tub is 4.4 x 3.4 and 3.1 tall to the lid top; toppers add up to about 3.5 more.
local BoxModels = {}

local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local SM, NEON, GLASS, FOIL = M.SmoothPlastic, M.Neon, M.Glass, M.Foil
local PI = math.pi
local WHITE = C(250, 250, 252)

BoxModels.Ids = { 'Street', 'Graffiti', 'Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold', 'Exclusive', 'Grail' }
-- the tub (W x D), the body's top (where the lid sits and the hinge is), the lid's cap top
BoxModels.Size = { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
local W, D = BoxModels.Size.W, BoxModels.Size.D
local HW, HD = W / 2, D / 2
local BODY, TOP = BoxModels.Size.Body, BoxModels.Size.Top

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
--   plate/frame/ink/inkStroke/sub   the name plate: its face, its frame, the name's colour and outline, "SHOE BOX"
--   coin/coinFace/mark    the "+1" side coin
--   lidMat/coinMat        optional materials for the lid body and cap, and the coin (default SmoothPlastic)
--   premium               a Robux box: the rainbow band round the tub, a stronger glow, rainbow sparkles
local THEMES = {
	Street = {
		Order = 1, Name = 'Street', Color = C(222, 56, 48), Accent = C(255, 132, 116),
		body = C(242, 242, 246), bodyShade = C(214, 216, 224), foot = C(58, 58, 70),
		lid = C(220, 54, 46), lidLight = C(238, 82, 70), stud = C(232, 70, 58),
		rim = C(214, 70, 58), rimMat = NEON,
		plate = C(250, 250, 252), frame = C(214, 44, 40), ink = C(206, 34, 34), inkStroke = C(52, 18, 22), sub = C(40, 40, 48),
		coin = C(34, 34, 42), coinFace = C(58, 58, 70), mark = WHITE,
	},
	Graffiti = {
		Order = 2, Name = 'Graffiti', Color = C(250, 120, 180), Accent = C(255, 168, 206),
		body = C(246, 242, 246), bodyShade = C(222, 216, 226), foot = C(46, 40, 56),
		lid = C(34, 30, 42), lidLight = C(48, 44, 58), stud = C(28, 26, 36),
		rim = C(218, 84, 150), rimMat = NEON,
		plate = C(30, 28, 40), frame = C(238, 92, 156), ink = C(255, 160, 204), inkStroke = C(120, 30, 80), sub = WHITE,
		coin = C(238, 98, 160), coinFace = C(252, 130, 184), mark = WHITE,
		drip = C(255, 162, 204),
	},
	Frost = {
		Order = 3, Name = 'Frost', Color = C(60, 150, 230), Accent = C(170, 222, 255),
		body = C(70, 156, 226), bodyShade = C(44, 120, 202), foot = C(26, 86, 160),
		lid = C(236, 242, 250), lidLight = C(248, 251, 255), stud = C(224, 234, 246),
		rim = C(40, 122, 214), rimMat = SM,
		plate = C(232, 241, 250), frame = C(30, 108, 200), ink = C(28, 104, 206), inkStroke = C(210, 232, 252), sub = C(30, 90, 170),
		coin = C(40, 122, 214), coinFace = C(70, 150, 230), mark = WHITE,
		ice = C(150, 204, 246), iceLight = C(206, 236, 255),
	},
	Lava = {
		Order = 4, Name = 'Lava', Color = C(255, 120, 40), Accent = C(255, 170, 110),
		body = C(48, 30, 30), bodyShade = C(36, 22, 22), foot = C(24, 16, 16),
		lid = C(36, 28, 30), lidLight = C(50, 40, 42), stud = C(30, 24, 26),
		rim = C(230, 96, 28), rimMat = NEON,
		plate = C(30, 22, 24), frame = C(240, 108, 36), ink = C(244, 236, 244), inkStroke = C(214, 92, 30), sub = WHITE,
		coin = C(255, 166, 112), coinFace = C(255, 190, 140), mark = WHITE,
		drip = C(236, 104, 40), glow = C(236, 96, 26),
	},
	Toxic = {
		Order = 5, Name = 'Toxic', Color = C(110, 214, 70), Accent = C(196, 250, 160),
		body = C(84, 70, 190), bodyShade = C(62, 52, 158), foot = C(40, 34, 110),
		lid = C(112, 214, 66), lidLight = C(144, 232, 98), stud = false,
		rim = C(116, 206, 66), rimMat = NEON,
		plate = C(24, 34, 40), frame = C(98, 196, 60), ink = C(150, 230, 96), inkStroke = C(16, 40, 22), sub = C(150, 230, 96),
		coin = C(202, 244, 184), coinFace = C(224, 252, 210), mark = C(110, 200, 80),
		drip = C(112, 214, 66),
	},
	Candy = {
		Order = 6, Name = 'Candy', Color = C(250, 140, 180), Accent = C(200, 190, 255),
		body = C(250, 156, 186), bodyShade = C(236, 128, 164), foot = C(206, 104, 140),
		lid = C(250, 160, 188), lidLight = C(255, 180, 204), stud = C(246, 146, 178),
		rim = C(158, 136, 232), rimMat = NEON,
		plate = C(252, 230, 238), frame = C(150, 140, 240), ink = C(236, 76, 142), inkStroke = C(150, 140, 240), sub = C(214, 70, 130),
		coin = C(204, 198, 252), coinFace = C(222, 218, 255), mark = WHITE,
		ribbon = C(150, 140, 240), ribbonDark = C(122, 112, 214),
	},
	Ocean = {
		Order = 7, Name = 'Ocean', Color = C(30, 140, 190), Accent = C(150, 232, 222),
		body = C(22, 112, 164), bodyShade = C(14, 88, 136), foot = C(10, 62, 102),
		lid = C(30, 124, 176), lidLight = C(44, 142, 194), stud = C(36, 132, 186),
		rim = C(64, 186, 176), rimMat = NEON,
		plate = C(14, 40, 72), frame = C(118, 220, 206), ink = C(156, 238, 226), inkStroke = C(10, 30, 50), sub = WHITE,
		coin = C(160, 232, 222), coinFace = C(196, 244, 236), mark = C(30, 124, 176),
		wave = C(170, 226, 246),
	},
	Gem = {
		Order = 8, Name = 'Gem', Color = C(40, 190, 100), Accent = C(250, 200, 70),
		body = C(26, 160, 86), bodyShade = C(16, 124, 66), foot = C(10, 84, 46),
		lid = C(226, 232, 238), lidLight = C(244, 247, 250), stud = C(214, 222, 230),
		rim = C(250, 200, 64), rimMat = FOIL,
		plate = C(16, 52, 36), frame = C(246, 196, 62), ink = C(226, 244, 232), inkStroke = C(150, 110, 20), sub = WHITE,
		coin = C(246, 196, 62), coinFace = C(255, 218, 110), mark = WHITE,
		gold = C(246, 196, 62),
	},
	Galaxy = {
		Order = 9, Name = 'Galaxy', Color = C(130, 110, 240), Accent = C(214, 204, 255),
		body = C(30, 32, 86), bodyShade = C(22, 22, 64), foot = C(16, 16, 46),
		lid = C(30, 32, 88), lidLight = C(40, 42, 108), stud = C(60, 72, 186),
		rim = C(146, 124, 232), rimMat = NEON,
		plate = C(20, 22, 60), frame = C(170, 158, 244), ink = C(206, 198, 255), inkStroke = C(30, 26, 80), sub = WHITE,
		coin = C(206, 200, 252), coinFace = C(226, 222, 255), mark = C(60, 60, 150),
		ringC = C(216, 208, 255),
	},
	Gold = {
		Order = 10, Name = 'Gold', Color = C(250, 186, 40), Accent = C(255, 220, 150),
		body = C(250, 178, 36), bodyShade = C(226, 146, 20), foot = C(184, 110, 14),
		lid = C(246, 194, 66), lidLight = C(255, 212, 96), stud = C(240, 186, 60),
		rim = C(240, 156, 46), rimMat = NEON,
		plate = C(74, 42, 124), frame = C(42, 30, 82), ink = C(244, 244, 252), inkStroke = C(30, 20, 60), sub = C(230, 226, 250),
		coin = C(255, 204, 90), coinFace = C(255, 224, 140), mark = WHITE,
		gold = C(255, 196, 50), wing = C(244, 246, 252), wingShade = C(206, 216, 238),
	},
	-- (brief 21) the Robux boxes: a midnight tub with a chrome lid and an ice-blue glow; a royal purple tub with a gold
	-- lid and a gold glow
	Exclusive = {
		Order = 11, Name = 'Exclusive', Color = C(70, 200, 255), Accent = C(190, 240, 255), premium = true,
		body = C(30, 34, 70), bodyShade = C(22, 24, 52), foot = C(14, 14, 30),
		lid = C(206, 216, 232), lidLight = C(232, 238, 248), stud = C(196, 206, 224), lidMat = M.Metal,
		rim = C(70, 214, 255), rimMat = NEON,
		plate = C(16, 18, 40), frame = C(70, 214, 255), ink = C(160, 238, 255), inkStroke = C(10, 44, 90), sub = WHITE,
		coin = C(206, 216, 232), coinFace = C(232, 238, 248), mark = C(40, 150, 220), coinMat = M.Metal,
		gem = C(110, 226, 255), gemLight = C(200, 246, 255), gemCore = C(150, 240, 255),
	},
	Grail = {
		Order = 12, Name = 'Grail', Color = C(170, 80, 255), Accent = C(255, 210, 80), premium = true,
		body = C(104, 44, 184), bodyShade = C(80, 30, 150), foot = C(46, 18, 96),
		lid = C(255, 194, 52), lidLight = C(255, 214, 100), stud = C(250, 186, 56), lidMat = FOIL,
		rim = C(255, 206, 70), rimMat = NEON,
		plate = C(42, 16, 84), frame = C(255, 200, 60), ink = C(255, 224, 120), inkStroke = C(90, 40, 10), sub = WHITE,
		coin = C(255, 200, 60), coinFace = C(255, 222, 120), mark = C(104, 44, 184), coinMat = FOIL,
		gold = C(255, 198, 56), goldDark = C(222, 150, 30), wing = C(250, 250, 255), wingShade = C(214, 222, 242),
	},
}
BoxModels.Meta = {}
for id, t in THEMES do
	BoxModels.Meta[id] = { Name = t.Name, Color = t.Color, Accent = t.Accent, Order = t.Order }
end

---------------------------------------------------------------------------------------------- the common box
-- the stud grid on the lid's cap (x, z); a theme may drop some (skip[i] = true) where its topper sits
local STUDS = {}
for _, z in { -1.0, 0, 1.0 } do
	for _, x in { -1.6, -0.8, 0, 0.8, 1.6 } do
		table.insert(STUDS, V(x, 0, z))
	end
end

-- The name plate on the front face: a frame, a face with the name and "SHOE BOX".
local function plate(k, t)
	local z = -HD
	k:span('PlateFrame', V(-1.62, 0.6, z + 0.04), V(1.62, 1.86, z - 0.12), t.frame, SM)
	local face = k:span('Plate', V(-1.46, 0.72, z - 0.1), V(1.46, 1.74, z - 0.17), t.plate, SM)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0
	g.Parent = face
	local function line(name, text, color, font, y, h, stroke, thick)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.06, y)
		l.Size = UDim2.fromScale(0.88, h)
		l.Font = font
		l.Text = text
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 1
		if stroke then
			local s = Instance.new('UIStroke')
			s.Color = stroke
			s.Thickness = thick
			s.LineJoinMode = Enum.LineJoinMode.Round
			s.Parent = l
		end
		l.Parent = g
	end
	line('Name', string.upper(t.Name), t.ink, Enum.Font.LuckiestGuy, 0.1, 0.52, t.inkStroke, 4)
	line('Sub', 'SHOE BOX', t.sub, Enum.Font.GothamBlack, 0.66, 0.24)
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
	k:rbox('BodyBand', 0, 0.3, 0, W + 0.04, 0.34, D + 0.04, 0.52, t.bodyShade, SM)
	plate(k, t)
	coin(k, t, 1)
	coin(k, t, -1)
	-- the lid, hinged on the body's back top edge
	local lk, lid = k:model('Lid')
	local hinge = lk:box('Hinge', V(0, BODY, HD), V(0.4, 0.1, 0.1), WHITE, SM)
	hinge.Transparency = 1
	lid.PrimaryPart = hinge
	lk:rbox('LidRim', 0, BODY, 0, W + 0.24, 0.24, D + 0.24, 0.62, t.rim, t.rimMat or SM)
	lk:rbox('LidBody', 0, BODY + 0.24, 0, W + 0.16, 0.58, D + 0.16, 0.58, t.lid, t.lidMat or SM)
	lk:rbox('LidCap', 0, TOP - 0.16, 0, W - 0.2, 0.16, D - 0.2, 0.42, t.lidLight, t.lidMat or SM)
	-- the lid's underside (covers the glowing rim's bottom when the lid is open) and the tub's dark inside
	lk:span('LidInside', V(-HW + 0.1, BODY - 0.016, -HD + 0.1), V(HW - 0.1, BODY - 0.004, HD - 0.1), t.lid, SM)
	k:span('Inside', V(-HW + 0.3, BODY, -HD + 0.3), V(HW - 0.3, BODY + 0.012, HD - 0.3), C(30, 30, 38), SM)
	local tk = lk:model('Topper')
	return lk, tk, lid
end

local function studsOn(lk, t, skip)
	if not t.stud then return end
	for i, p in STUDS do
		if not (skip and skip[i]) then
			lk:cyl('Stud', V(p.X, TOP + 0.1, p.Z), 'y', 0.2, 0.56, t.stud, t.lidMat or SM)
		end
	end
end

-- The Robux boxes' rainbow band: glowing segments in the six rainbow colours round the tub on its shade band, under
-- the name plate (six across the front and the back, four along each side), the colours running on round the corners.
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
	for j = 0, 3 do
		local z0 = -fz + 2 * fz * j / 4
		seg(V(HW - 0.02, y0, z0), V(HW + out, y1, z0 + 2 * fz / 4))
	end
	for j = 5, 0, -1 do
		local x0 = -fx + 2 * fx * j / 6
		seg(V(x0, y0, HD - 0.02), V(x0 + 2 * fx / 6, y1, HD + out))
	end
	for j = 3, 0, -1 do
		local z0 = -fz + 2 * fz * j / 4
		seg(V(-HW - out, y0, z0), V(-HW + 0.02, y1, z0 + 2 * fz / 4))
	end
end

---------------------------------------------------------------------------------------------- toppers
-- Each takes (k: the box's kit, lk: the lid's kit, tk: the topper's kit, t: the theme). Positions are scale-1 studs
-- in the box's frame (front -Z), on the lid's cap (y = TOP) or floating over it.
local TOPPERS = {}

-- A mini white high-top (the box's own Fresh Canvas) sitting on the lid, toe to the front-right, and tissue paper
-- poking out under the lid.
function TOPPERS.Street(k, lk, tk, t)
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true })
	-- tissue paper folded out over the tub's top edge under the lid (white and salmon sheets): a wedge with its sheer
	-- face on the tub and its slope falling outward
	for i, e in { { -1.15, -1, 0 }, { 1.25, -1, 0 }, { -0.35, 1, PI }, { HW, 0.55, -PI / 2 }, { -HW, -0.45, PI / 2 } } do
		local onFront = e[2] == -1 or e[2] == 1
		local pos = onFront and V(e[1], BODY - 0.1, e[2] * (HD + 0.15)) or V(e[1] + math.sign(e[1]) * 0.15, BODY - 0.1, e[2])
		k:wedge('Tissue', CFrame.new(pos) * CFrame.Angles(0, e[3], 0), V(1.15, 0.26, 0.3), i % 2 == 0 and C(255, 250, 248) or C(255, 170, 156), SM).CastShadow = false
	end
	local s = newKit(tk.parent, tk.s * 1.2, tk.cf * CFrame.new(V(0.2, TOP + 0.04, 0.2) * tk.s) * CFrame.Angles(0, -0.55, 0))
	local white, grey, dark, red = C(250, 250, 252), C(222, 224, 234), C(44, 44, 52), C(222, 50, 44)
	-- the sole: a dark outsole, a thick white midsole with a red line round it
	s:span('ShoeOutsole', V(-0.56, 0, -1.25), V(0.56, 0.12, 1.2), dark, SM)
	s:span('ShoeSole', V(-0.6, 0.12, -1.28), V(0.6, 0.44, 1.22), white, SM)
	s:span('ShoeSoleLine', V(-0.62, 0.24, -1.3), V(0.62, 0.32, 1.24), red, SM)
	-- the toe box: a low block under a vamp sloping up to the laces
	s:span('ShoeToe', V(-0.52, 0.44, -1.22), V(0.52, 0.62, -0.2), white, SM)
	s:wedge('ShoeVamp', CFrame.new(0, 0.62 + 0.24, -0.71), V(1.04, 0.48, 1.02), white, SM)
	s:span('ShoeToeCap', V(-0.54, 0.44, -1.27), V(0.54, 0.56, -0.85), grey, SM)
	-- the upper and the high collar with a padded top, the tongue standing up out of it
	s:span('ShoeUpper', V(-0.53, 0.44, -0.2), V(0.53, 1.12, 1.18), white, SM)
	s:span('ShoeCollar', V(-0.53, 1.12, 0.32), V(0.53, 1.62, 1.18), white, SM)
	s:span('ShoeCollarPad', V(-0.46, 1.62, 0.38), V(0.46, 1.78, 1.12), grey, SM)
	s:box('ShoeTongue', V(0, 1.38, 0.2), V(0.56, 0.78, 0.16), C(240, 240, 246), SM, CFrame.Angles(-0.25, 0, 0))
	-- laces: two on the vamp's slope, two across the top of the upper
	for j, z in { -0.75, -0.42 } do
		s:box('ShoeLace', V(0, 0.68 + 0.24 * j, z), V(0.92, 0.07, 0.11), grey, SM, CFrame.Angles(-0.48, 0, 0))
	end
	for _, z in { -0.08, 0.14 } do
		s:box('ShoeLace', V(0, 1.14, z), V(0.92, 0.07, 0.11), grey, SM)
	end
	-- the red side stripe (a slanted swoosh) and heel tab: the box's colour
	for _, sx in { -1, 1 } do
		s:box('ShoeStripe', V(sx * 0.545, 0.78, 0.2), V(0.04, 0.16, 1.25), red, SM, CFrame.Angles(0.3, 0, 0))
	end
	s:span('ShoeHeelTab', V(-0.18, 1.25, 1.16), V(0.18, 1.9, 1.26), red, SM)
end

-- A spray can on the black studded lid, paint splats on the tub and lid, pink paint dripping over the plate,
-- a puff of pink paint from the nozzle.
function TOPPERS.Graffiti(k, lk, tk, t)
	studsOn(lk, t, { [5] = true, [10] = true, [15] = true })
	-- splats on the tub (flat discs on the faces) and paint streaks on the lid cap
	local splat = { C(255, 150, 40), C(236, 60, 60), C(60, 112, 232), C(150, 92, 226), C(255, 214, 60), C(80, 200, 120) }
	for i, e in { { 1, -1.5, 0.55 }, { 1, 1.75, 1.0 }, { 2, -1.85, 1.6 }, { -2, -0.8, 0.7 }, { -2, 0.9, 1.3 }, { 3, 0.4, 0.55 } } do
		local col = splat[i]
		if e[1] == 1 then
			k:cyl('Splat', V(e[2], e[3], -HD - 0.03), 'z', 0.06, 0.95 + 0.08 * i, col, SM)
			k:cyl('Splat', V(e[2] + 0.45, e[3] - 0.3, -HD - 0.035), 'z', 0.06, 0.45, col, SM)
		elseif e[1] == 3 then
			k:cyl('Splat', V(e[2], e[3], HD + 0.03), 'z', 0.06, 1.2, col, SM)
		else
			k:cyl('Splat', V(math.sign(e[1]) * (HW + 0.03), e[3], e[2]), 'x', 0.06, 1.15, col, SM)
			k:cyl('Splat', V(math.sign(e[1]) * (HW + 0.035), e[3] - 0.45, e[2] + 0.4), 'x', 0.06, 0.5, col, SM)
		end
	end
	local cyan, green = C(96, 206, 214), C(116, 214, 84)
	lk:cyl('PaintBlob', V(-1.35, TOP + 0.01, -0.5), 'y', 0.03, 1.5, cyan, SM)
	lk:cyl('PaintBlob', V(-0.45, TOP + 0.012, -0.85), 'y', 0.03, 0.9, cyan, SM)
	lk:span('PaintStreak', V(-2.12, BODY + 0.4, -1.4), V(-1.5, TOP - 0.1, -0.5), cyan, SM)
	lk:cyl('PaintBlob', V(0.35, TOP + 0.01, 0.5), 'y', 0.03, 1.55, green, SM)
	lk:cyl('PaintBlob', V(-0.35, TOP + 0.012, 0.95), 'y', 0.03, 0.7, green, SM)
	lk:cyl('PaintBlob', V(-1.5, TOP + 0.01, 0.95), 'y', 0.03, 0.55, C(150, 110, 230), SM)
	-- the drips: a pink band over the rim and drips down over the plate
	drips(lk, t.drip, SM, { { -1.95, 0.85, 0.4 }, { -1.4, 0.48 }, { -0.85, 0.36 }, { -0.3, 0.46, 0.38 }, { 0.3, 0.34 }, { 0.85, 0.46 }, { 1.4, 0.38 }, { 1.95, 1.05, 0.4 } }, BODY + 0.1)
	-- the can: a chunky cyan body, a pink band, a pink shoulder and cap, a white nozzle, leaning back a little
	local c = tk:at(CFrame.new(1.25, TOP, 0.55) * CFrame.Angles(0.1, 0, -0.08))
	c:cyl('CanBody', V(0, 0.85, 0), 'y', 1.7, 1.44, C(92, 204, 226), SM)
	c:cyl('CanBand', V(0, 0.9, 0), 'y', 0.5, 1.52, C(240, 86, 150), SM)
	c:cyl('CanFoot', V(0, 0.08, 0), 'y', 0.16, 1.5, C(66, 166, 194), SM)
	c:cyl('CanShoulder', V(0, 1.82, 0), 'y', 0.24, 1.16, C(240, 86, 150), SM)
	c:cyl('CanCap', V(0, 2.08, 0), 'y', 0.3, 0.72, C(250, 120, 176), SM)
	c:box('CanNozzle', V(0, 2.32, -0.1), V(0.26, 0.2, 0.38), WHITE, SM)
	c:box('CanShine', V(-0.5, 0.95, -0.42), V(0.12, 1.3, 0.12), C(190, 240, 250), SM, CFrame.Angles(0, 0.7, 0))
	-- the puff: pink balls trailing off the nozzle to the left, shrinking (bobbing a little on display)
	local puff = tk:floating('Puff', V(0, TOP + 2.7, 0.35), nil, 0.12, 2.6)
	for i, e in { { -0.85, 2.55, 0.95 }, { -1.65, 2.75, 0.74 }, { -2.3, 2.85, 0.54 }, { -2.8, 2.9, 0.36 } } do
		puff:ball('PaintPuff', V(1.25 + e[1], TOP + e[2], 0.35), e[3], C(255, 168, 206), SM).CastShadow = i <= 1
	end
end

-- A snow-capped lid with icicles round the rim, a cluster of ice crystals on top and ice spikes off the corners.
function TOPPERS.Frost(k, lk, tk, t)
	-- snow mounds over the cap (rounded, two tones), a row of snowy studs at the front
	lk:blob('Snow', V(-0.9, TOP + 0.05, 0.2), V(2.6, 0.8, 2.8), t.lidLight, SM)
	lk:blob('Snow', V(1.0, TOP + 0.02, 0.35), V(2.4, 0.66, 2.6), t.lidLight, SM)
	lk:blob('Snow', V(0.1, TOP, -0.6), V(3.2, 0.5, 1.6), C(240, 245, 252), SM)
	for _, x in { -1.6, -0.55, 0.5, 1.55 } do
		lk:cyl('Stud', V(x, TOP + 0.06, -1.25), 'y', 0.2, 0.5, t.stud, SM)
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
		for j, z in { -0.8, 0.1, 0.9 } do
			local len = j == 2 and 0.62 or 0.44
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
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true, [14] = true, [1] = true })
	drips(lk, t.drip, NEON, { { -1.95, 0.7 }, { -1.4, 0.42 }, { -0.8, 0.34 }, { -0.2, 0.46, 0.38 }, { 0.4, 0.36 }, { 1.0, 0.44 }, { 1.55, 0.36 }, { 2.0, 0.8 } }, BODY + 0.1)
	-- glowing zigzag cracks on the tub's front corners and sides (three short neon bars each)
	local function crack(cf)
		local c = k:at(cf)
		c:box('Crack', V(0, 0.32, 0), V(0.1, 0.42, 0.04), t.glow, NEON, CFrame.Angles(0, 0, 0.55))
		c:box('Crack', V(0.04, 0, 0), V(0.1, 0.42, 0.04), t.glow, NEON, CFrame.Angles(0, 0, -0.55))
		c:box('Crack', V(0, -0.32, 0), V(0.1, 0.42, 0.04), t.glow, NEON, CFrame.Angles(0, 0, 0.55))
	end
	crack(CFrame.new(-1.88, 1.05, -HD - 0.02))
	crack(CFrame.new(1.88, 1.05, -HD - 0.02))
	crack(CFrame.new(HW + 0.02, 1.0, -0.55) * CFrame.Angles(0, PI / 2, 0))
	crack(CFrame.new(-HW - 0.02, 1.0, 0.55) * CFrame.Angles(0, PI / 2, 0))
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

-- A slime-green lid with slime oozing over the plate, two googly eyes on stalks and slime bubbles.
function TOPPERS.Toxic(k, lk, tk, t)
	-- slime drips: long and wide, two running all the way down the front corners
	drips(lk, t.drip, SM, { { -1.9, 1.95, 0.44 }, { -1.35, 0.6 }, { -0.8, 0.44, 0.4 }, { -0.25, 0.36 }, { 0.3, 0.47, 0.42 }, { 0.85, 0.36 }, { 1.4, 0.62 }, { 1.95, 1.8, 0.44 } }, BODY + 0.12)
	for _, sx in { -1, 1 } do
		lk:box('SideDrip', V(sx * (HW + 0.1), BODY - 0.3, -0.2), V(0.14, 0.7, 0.4), t.drip, SM)
		lk:ball('SideDripTip', V(sx * (HW + 0.1), BODY - 0.64, -0.2), 0.42, t.drip, SM)
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
		k:box('CandyStripe', V(x, 1.0, -HD - 0.02), V(0.42, 1.9, 0.05), cream, SM, CFrame.Angles(0, 0, 0.6))
	end
	for _, sx in { -1, 1 } do
		for _, z in { -0.9, 0.9 } do
			k:box('CandyStripe', V(sx * (HW + 0.02), 1.1, z), V(0.05, 1.7, 0.42), cream, SM, CFrame.Angles(0.55 * sx, 0, 0))
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
				c:make('Part', 'LollySwirl', V((p - prev).Magnitude + 0.06, d * 0.09, 0.05), CFrame.new(m) * CFrame.Angles(0, 0, math.atan2(p.Y - prev.Y, p.X - prev.X)), WHITE, SM)
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
	-- wave lines: a row of short tilted bars along each side and the back
	for _, sx in { -1, 1 } do
		for j = 0, 3 do
			local z = -1.05 + j * 0.7
			k:box('Wave', V(sx * (HW + 0.02), 0.95 + (j % 2) * 0.16, z), V(0.05, 0.17, 0.66), t.wave, SM, CFrame.Angles((j % 2 == 0 and 0.4 or -0.4), 0, 0))
			k:box('Wave', V(sx * (HW + 0.02), 1.55 + (j % 2) * 0.16, z), V(0.05, 0.17, 0.66), t.wave, SM, CFrame.Angles((j % 2 == 0 and 0.4 or -0.4), 0, 0))
		end
	end
	for j = 0, 4 do
		k:box('Wave', V(-1.6 + j * 0.8, 1.2 + (j % 2) * 0.16, HD + 0.02), V(0.76, 0.17, 0.05), t.wave, SM, CFrame.Angles(0, 0, (j % 2 == 0 and 0.4 or -0.4)))
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
		k:box('Glint', V(e[1], e[2], -HD - 0.02), V(0.16, 1.1, 0.04), C(120, 226, 160), SM, CFrame.Angles(0, 0, 0.5))
	end
	for _, sx in { -1, 1 } do
		k:box('Glint', V(sx * (HW + 0.02), 1.2, -0.9 * sx), V(0.04, 1.2, 0.16), C(120, 226, 160), SM, CFrame.Angles(0.5, 0, 0))
	end
	-- red gems along the rim's front (diamonds), small gold corner caps
	for _, x in { -1.3, 0, 1.3 } do
		lk:box('RimGem', V(x, BODY + 0.12, -HD - 0.16), V(0.32, 0.32, 0.12), C(244, 88, 76), SM, CFrame.Angles(0, 0, PI / 4))
	end
	-- the crown ring: an octagon of gold bars on the cap, four posts with gold knobs
	local ring = tk:at(CFrame.new(0, TOP + 0.12, 0))
	ring:ring('CrownRing', CFrame.identity, 1.25, 8, 0.22, 0.24, t.gold, FOIL)
	for j = 0, 3 do
		local a = j * PI / 2 + PI / 4
		local p = V(math.cos(a) * 1.25, 0, math.sin(a) * 1.25)
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
		k:box('StarSpeck', V(e[1], e[2], -HD - 0.03), V(0.14, 0.14, 0.05), C(230, 230, 255), SM, CFrame.Angles(0, 0, PI / 4))
	end
	for _, sx in { -1, 1 } do
		k:cyl('Nebula', V(sx * (HW + 0.02), 0.85, sx * 0.6), 'x', 0.04, 0.9, C(92, 70, 180), SM)
		k:box('StarSpeck', V(sx * (HW + 0.03), 1.75, -sx * 0.8), V(0.05, 0.14, 0.14), C(230, 230, 255), SM, CFrame.Angles(PI / 4, 0, 0))
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
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true })
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
	halo:ring('Halo', CFrame.new(0, TOP + 3.0, 0.05) * CFrame.Angles(0.15, 0, 0), 0.95, 12, 0.16, 0.14, C(255, 248, 226), NEON)
	-- wings: three long rounded feathers fanned up and out from a root on each side (the longest on top), layered
	-- white over a pale blue shade
	for _, sx in { -1, 1 } do
		local wc = k:at(CFrame.new(sx * (HW + 0.15), 1.7, 0.45) * CFrame.Angles(0, sx * -0.4, 0))
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

-- (brief 21) Exclusive: a big cut diamond spinning over a chrome stand ringed in ice-blue light, with sparkles round
-- it; the rainbow band on the midnight tub.
function TOPPERS.Exclusive(k, lk, tk, t)
	studsOn(lk, t, { [3] = true, [7] = true, [8] = true, [9] = true, [13] = true })
	rainbowBand(k)
	-- the stand: a chrome drum on the lid with a glowing ring and a cup the diamond's point sits over
	tk:cyl('Stand', V(0, TOP + 0.14, 0), 'y', 0.28, 1.7, t.lidLight, M.Metal)
	tk:cyl('StandRing', V(0, TOP + 0.3, 0), 'y', 0.08, 1.82, t.rim, NEON)
	tk:cyl('StandCup', V(0, TOP + 0.4, 0), 'y', 0.16, 0.9, t.lid, M.Metal)
	-- the diamond (a brilliant cut, girdle up the middle): a shallow crown of 8 facets under a glowing table, a deep
	-- pavilion of 8 facets down to a point; two tones so the facets read. It turns slowly and bobs.
	local gy = TOP + 1.95
	local gem = tk:floating('Diamond', V(0, gy, 0), 36, 0.14, 2.6)
	local girdle = CFrame.new(0, gy, 0)
	gem:frustum('DiamondCrown', girdle, 1.12, 0.66, 0.5, 8, { t.gem, t.gemLight }, SM)
	gem:cyl('DiamondTable', V(0, gy + 0.52, 0), 'y', 0.06, 1.36, t.gemCore, NEON)
	gem:frustum('DiamondPavilion', girdle * CFrame.Angles(PI, PI / 8, 0), 1.12, 0.08, 1.05, 8, { t.gemLight, t.gem }, SM)
	-- sparkles round it (they float with it)
	for _, e in { { -1.55, 0.45, -0.3, 0.6 }, { 1.5, 0.95, 0.2, 0.5 }, { 1.0, -0.5, -0.9, 0.42 }, { -1.15, 1.2, 0.6, 0.38 } } do
		gem:sparkle('Sparkle', CFrame.new(e[1], gy + e[2], e[3]) * CFrame.Angles(0, 0.35, 0.2), e[4], WHITE, NEON)
	end
end

-- (brief 21) Grail: the dream pair, a golden winged high-top on a gold plinth under a spinning rainbow halo, stars
-- round it; the rainbow band on the royal purple tub.
function TOPPERS.Grail(k, lk, tk, t)
	studsOn(lk, t, { [2] = true, [3] = true, [4] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true, [14] = true })
	rainbowBand(k)
	-- the plinth: a gold drum with a glowing lip
	tk:cyl('Plinth', V(0, TOP + 0.16, 0.05), 'y', 0.32, 2.5, t.goldDark, FOIL)
	tk:cyl('PlinthLip', V(0, TOP + 0.35, 0.05), 'y', 0.08, 2.62, t.rim, NEON)
	-- the golden sneaker (a chunky high-top like the Street box's, toe to the front-left), rainbow line round its sole
	local s = newKit(tk.parent, tk.s * 1.12, tk.cf * CFrame.new(V(0.05, TOP + 0.39, 0.1) * tk.s) * CFrame.Angles(0, 1.15, 0))
	local gold, goldDark, purple, white = t.gold, t.goldDark, C(104, 44, 184), C(250, 250, 252)
	s:span('ShoeOutsole', V(-0.56, 0, -1.25), V(0.56, 0.12, 1.2), purple, SM)
	s:span('ShoeSole', V(-0.6, 0.12, -1.28), V(0.6, 0.44, 1.22), white, SM)
	for j = 0, 5 do
		local z0 = -1.3 + 2.54 * j / 6
		s:span('ShoeSoleLine', V(-0.62, 0.24, z0), V(0.62, 0.32, z0 + 2.54 / 6), RAINBOW[j + 1], NEON)
	end
	s:span('ShoeToe', V(-0.52, 0.44, -1.22), V(0.52, 0.62, -0.2), gold, FOIL)
	s:wedge('ShoeVamp', CFrame.new(0, 0.62 + 0.24, -0.71), V(1.04, 0.48, 1.02), gold, FOIL)
	s:span('ShoeToeCap', V(-0.54, 0.44, -1.27), V(0.54, 0.56, -0.85), purple, SM)
	s:span('ShoeUpper', V(-0.53, 0.44, -0.2), V(0.53, 1.12, 1.18), gold, FOIL)
	s:span('ShoeCollar', V(-0.53, 1.12, 0.32), V(0.53, 1.62, 1.18), gold, FOIL)
	s:span('ShoeCollarPad', V(-0.46, 1.62, 0.38), V(0.46, 1.78, 1.12), purple, SM)
	s:box('ShoeTongue', V(0, 1.38, 0.2), V(0.56, 0.78, 0.16), goldDark, FOIL, CFrame.Angles(-0.25, 0, 0))
	for j, z in { -0.75, -0.42 } do
		s:box('ShoeLace', V(0, 0.68 + 0.24 * j, z), V(0.92, 0.07, 0.11), white, SM, CFrame.Angles(-0.48, 0, 0))
	end
	for _, z in { -0.08, 0.14 } do
		s:box('ShoeLace', V(0, 1.14, z), V(0.92, 0.07, 0.11), white, SM)
	end
	s:span('ShoeHeelTab', V(-0.18, 1.25, 1.16), V(0.18, 1.9, 1.26), purple, SM)
	-- a purple swoosh on each side, a glowing star on it
	for _, sx in { -1, 1 } do
		s:box('ShoeStripe', V(sx * 0.545, 0.8, 0.15), V(0.04, 0.2, 1.3), purple, SM, CFrame.Angles(0.3, 0, 0))
		s:box('ShoeStar', V(sx * 0.57, 0.86, -0.05), V(0.04, 0.3, 0.3), C(255, 250, 230), NEON, CFrame.Angles(PI / 4, 0, 0))
	end
	-- white wings off both sides of the collar: three rounded feathers fanned up and back
	for _, sx in { -1, 1 } do
		local wc = s:at(CFrame.new(sx * 0.58, 1.2, 0.55) * CFrame.Angles(0, sx * -0.35, 0))
		for j, e in { { 0.5, 1.5, 0.6 }, { 0.95, 1.25, 0.55 }, { 1.35, 0.95, 0.5 } } do
			local f = CFrame.Angles(0.55, 0, sx * -e[1]) * CFrame.new(0, e[2] / 2, 0)
			wc:blob('Wing', f.Position, V(e[3], e[2], 0.2), j == 3 and t.wingShade or t.wing, SM, f.Rotation)
		end
	end
	-- the rainbow halo over it, turning; gold stars round it
	local hy = TOP + 3.55
	local halo = tk:floating('Halo', V(0, hy, 0.05), 40, 0.15, 2.4)
	local hcf = CFrame.new(0, hy, 0.05) * CFrame.Angles(0.18, 0, 0)
	local n = 12
	local R = 1.15
	local len = 2 * R * math.tan(PI / n) + 0.1
	for j = 0, n - 1 do
		halo:make('Part', 'Halo', V(len, 0.16, 0.2), hcf * CFrame.Angles(0, j * 2 * PI / n, 0) * CFrame.new(0, 0, R), RAINBOW[j % #RAINBOW + 1], NEON)
	end
	local stars = tk:floating('Stars', V(0, TOP + 2.2, 0), 18, 0.12, 3.0)
	for _, e in { { -1.85, 1.6, -0.4, 0.62 }, { 1.9, 2.3, 0.1, 0.52 }, { 1.45, 0.8, -1.0, 0.42 } } do
		stars:sparkle('Star', CFrame.new(e[1], TOP + e[2], e[3]) * CFrame.Angles(0, 0.3, 0.15), e[4], C(255, 226, 120), NEON)
	end
end

---------------------------------------------------------------------------------------------- build
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
	local lk, tk, lid = common(k, t)
	TOPPERS[boxId](k, lk, tk, t)
	lid.WorldPivot = lid.PrimaryPart.CFrame
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then n += 1 end
	end
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
end

return BoxModels
