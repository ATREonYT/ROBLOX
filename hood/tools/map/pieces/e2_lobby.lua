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
		line(g, 'Soon', 'COMING SOON', C(255, 214, 60), FONT.title, 0.08, 0.3, C(40, 30, 0), 2)
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
function Lobby.endX() return Lobby.HeadFront - Lobby.laneHalf() end
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
	local x0 = Lobby.endX() - Lobby.laneHalf() - 1.0 -- (its back, a stud past the lane's, in the alcove)
	-- (the head lane faces east, +x: its front, the shooter's end, is at endX + HALF_Z)
	local xf = Lobby.endX() + Lobby.laneHalf() + 0.6 -- the stage's front edge, 0.6 past the lane's rim
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
	local rx = Lobby.endX() + Lobby.laneHalf() + 0.6 + (St.Head.Steps - 1) * St.Head.Tread -- (the steps' foot)
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
			Lobby.place(L, training, 'Range_' .. id, St.Slots[k], { X = 9, Y = 12, Z0 = -Lobby.laneHalf(), Z1 = Lobby.laneHalf() }, string.upper(s.Name or id), C(90, 200, 120),
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
	local a, labels = Lobby.signWords(g, V(0, foot + tall + 2.3 + (opts.lift or 0), 0), 7.6, 3.0, {
		{ 'Title', name, 0.56, Lobby.Grad.gold, 4 },
		{ 'Price', 'ONLY ' .. RobuxText.fmt(entry.Price), 0.44, Lobby.Grad.lime, 3.5 },
	}, 36)
	labels.Price:SetAttribute('Price', entry.Price)
	Lobby.nearWords(a.WorldLabel, 26, 36)
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
	local a = Lobby.signWords(g, V(0, foot + tall + 2.3 + (lift or 0), 0), 8.4, 3.0, {
		{ 'Title', entry.Title or boxId, 0.56, { tone:Lerp(P.white, 0.6), tone:Lerp(P.white, 0.1) }, 4 },
		{ 'Price', 'ONLY ' .. RobuxText.fmt(entry.Price), 0.44, Lobby.Grad.lime, 3.5 },
	}, 36)
	Lobby.nearWords(a.WorldLabel, 26, 36)
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
