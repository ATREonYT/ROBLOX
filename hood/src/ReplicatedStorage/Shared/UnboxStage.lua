-- UnboxStage (brief 28, STAGE28): the set behind the box opening (Shared/UnboxCinematic), "The Corner". It is a
-- daylight corner of our block, built the way TheBlockV2 builds the stage streets: studded brick houses in two or
-- three tones with stone-trimmed windows and slate roofs, a navy studded street lamp, stacked-cube trees, the studded
-- road with its yellow dashes, the light studded walk, a white picket fence, a hydrant, a boombox on a crate. The box
-- lands on a round pad (the lobby's box pad, flattened) in a pale paved plaza; the camera stands in the cross street in
-- front of it and looks down our street (+Z). The street narrows at the step line, where two end buildings step in the
-- way the map's stage ends do: the corner shoe shop on the left of the frame and a mural wall on the right. The narrow
-- far street behind the box stays calm (road, walks, low walls, trees, sky).
-- It is built client-side far from the map for one opening and goes with the job's folder. Every part is anchored and
-- untouchable; only the big blocks cast shadows. Nothing here runs per frame.
--
--   UnboxStage.build(job, kind?)   kind 'egg' (the plain block in daylight) or 'secret' (the same block dressed in the
--                                  box's theme: colours, bunting and string lights, a few props); default 'secret' when
--                                  job.P.premium. Reads job.P (n, padR, G, premium, theme, riser), job.folder, job.O,
--                                  job.park. Sets the fields UnboxCinematic reads (see below). Returns job.
--   UnboxStage.dress(job, theme?)  turns an egg set into the Secret set in place (once)
--   UnboxStage.night(job, a, lights)  0..1: lights the windows and the shop's glass and dims the floor for the dark
--                                  beats (a), and the Secret's string lights (lights); writes only when they change, and
--                                  0 puts every part back as built
--   UnboxStage.framePosters(job, cf, fov, aspect, pairU)   slides each side's posters along its own wall so its word
--                                  sits beside the pair in that frame (or, when the wall cannot bring it whole into the
--                                  frame, whole out of it)
--   UnboxStage.floorAt(job) -> fn(worldPos) -> y          where a falling bit stops (pad, riser, plaza, roads)
--   UnboxStage.count(job) -> parts, lights
--
-- Stage space: job.O is the pad's centre on the plaza, y = 0 the plaza (the roads a kerb, 0.6, below it), +Z away from
-- the camera, +X the frame's left. The fields: anchor, padTop (0.22 up), deckY, padRim (one neon part), the part named
-- 'Pad', riser, posterParts, posterLabels ({ label, stroke }), wordParts, posterGroups, wallInfo, signParts (a
-- free-standing rooftop board), signNeon (4 frame strips), signText, signStroke, lamps ({ head, light, color }: the
-- street lamp and the shop's wall lamp), speakers ({ actor, base }: the boombox), boxGlow, boxLight, volumes (back,
-- sky, floor, around), and the new setKind, setParts, layout, marks (stage-space { eye, at, fov } that see the set's
-- calm side), nightParts. Lights: the two lamps and the box light, 3 PointLights.
local UnboxStage = {}

local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local C3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PI = math.pi
local MAT = Enum.Material

local Fonts
do
	local node = script.Parent:FindFirstChild('Fonts')
	if node then
		local ok, m = pcall(require, node)
		Fonts = ok and type(m) == 'table' and m or nil
	end
end

-- TheBlockV2's stage-street palette (P.st), the same values, so the set under the game's light reads like the map.
local PAL = {
	road = C3(120, 126, 142), roadDark = C3(100, 106, 122), dash = C3(255, 243, 50), walk = C3(160, 172, 190),
	walkJoint = C3(132, 142, 160), kerbStone = C3(184, 192, 206), grass = C3(38, 212, 92), grassEdge = C3(24, 160, 70),
	brick = C3(203, 118, 85), brickDeep = C3(187, 102, 71), brickLight = C3(217, 136, 95), trim = C3(199, 177, 175),
	sill = C3(233, 210, 200), band = C3(182, 196, 222), roof = C3(102, 136, 180), roofDark = C3(76, 100, 138),
	glassA = C3(162, 204, 250), glassB = C3(190, 218, 243), mullion = C3(44, 86, 142), lamp = C3(74, 104, 160),
	lampDark = C3(56, 80, 130), lampLight = C3(104, 138, 194), lampGlow = C3(255, 244, 196), leaf = C3(32, 250, 56),
	leafDark = C3(26, 214, 48), trunk = C3(97, 90, 103), hedge = C3(26, 196, 70), manhole = C3(70, 74, 84),
	crate = C3(206, 148, 76), woodDark = C3(150, 96, 52),
	windowLit = C3(150, 112, 66), -- (a lit window in the dark beats: warm at about half brightness, never blooming)
	shopLit = C3(124, 100, 76), -- (the shop's glass in the dark beats, dimmer still)
	shop = C3(66, 120, 214), -- (the egg set's shop: a light shop blue; the Secret paints it in the theme)
	rimEgg = C3(232, 236, 248), -- (the egg set's pad lip: pale, so it never echoes the box's colour)
}
UnboxStage.Palette = PAL
UnboxStage.MaxParts = 250
UnboxStage.MaxLights = 3
UnboxStage.FloorDim = 0.12 -- (the plaza and the pad at night 1: a touch darker, the dark looks already sit low)

---------------------------------------------------------------------------------------------- parts
local SURF = { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
local SIDES = { 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
-- A build context: the job, the folder, a frame (world CFrame) that local coordinates are in.
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(job, parent, cf) return setmetatable({ job = job, parent = parent, cf = cf }, Ctx) end
function Ctx:at(cf) return newCtx(self.job, self.parent, self.cf * cf) end
function Ctx:into(parent) return newCtx(self.job, parent, self.cf) end
-- o: st = 'top' | 'all' (classic studs: Plastic with the Studs surface), shadow, shape, class, t (transparency),
-- mat (a material instead of the default)
function Ctx:part(name, size, cf, color, o)
	o = o or {}
	local p = Instance.new(o.class or 'Part')
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = o.shadow == true
	p.Size = size
	p.CFrame = self.cf * cf
	p.Color = color
	p.Material = o.mat or (o.st and MAT.Plastic or MAT.SmoothPlastic)
	for _, f in SURF do (p :: any)[f] = Enum.SurfaceType.Smooth end
	if o.st then
		p.TopSurface = Enum.SurfaceType.Studs
		if o.st == 'all' then
			for _, f in SIDES do (p :: any)[f] = Enum.SurfaceType.Studs end
		end
	end
	if o.shape then (p :: any).Shape = o.shape end
	if o.t then p.Transparency = o.t end
	p.Parent = self.parent
	self.job.setParts = (self.job.setParts or 0) + 1
	return p
end
-- An axis-aligned box between two corners (this frame).
function Ctx:box(name, a, b, color, o)
	local lo = V3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CF((lo + hi) / 2), color, o)
end
-- A cylinder standing up on pos (its axis along this frame's Y).
function Ctx:post(name, d, h, pos, color, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return self:part(name, V3(h, d, d), CF(pos + V3(0, h / 2, 0)) * ANG(0, 0, PI / 2), color, o)
end
-- A wedge (its slope rises toward its local +Z).
function Ctx:wedge(name, size, cf, color, o)
	o = o or {}
	o.class = 'WedgePart'
	return self:part(name, size, cf, color, o)
end
function Ctx:ball(name, d, pos, color, o)
	o = o or {}
	o.shape = Enum.PartType.Ball
	return self:part(name, V3(d, d, d), CF(pos), color, o)
end
local function light(part, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = part
	return l
end
-- A part the dark beats darken (the pale plaza and the pad a little, UnboxStage.FloorDim at night 1; an unlit
-- window's glass by `amount`).
function UnboxStage.dims(job, p, amount)
	table.insert(job.nightParts, { p, nil, kind = 'dim', amount = amount })
	return p
end
-- A facade frame in stage space: its plane through (x, 0, z), +Z out of the wall toward `facing` ('+x', '-x', '-z'),
-- +X along it (seen from outside, to the right).
local function facade(c, x, z, facing)
	local yaw = facing == '+x' and PI / 2 or facing == '-x' and -PI / 2 or PI
	return c:at(CF(x, 0, z) * ANG(0, yaw, 0))
end

-- A rigid group the cinematic can bump (the boombox): pose(cf, s) puts its parts back about the pivot, scaled by s.
-- It writes only when the pose changes.
local Bump = {}
Bump.__index = Bump
local function newBump(parts, pivot)
	local self = setmetatable({ parts = parts, rel = {}, size = {}, cfs = {} }, Bump)
	local inv = pivot:Inverse()
	for i, p in parts do
		self.rel[i] = inv * p.CFrame
		self.size[i] = p.Size
	end
	return self
end
function Bump:pose(cf, sx)
	sx = sx or 1
	if self.lastCf == cf and self.lastS == sx then return end
	self.lastCf, self.lastS = cf, sx
	for i, p in self.parts do
		local r = self.rel[i]
		self.cfs[i] = cf * CF(r.Position * sx) * r.Rotation
		local s = self.size[i] * sx
		if p.Size ~= s then p.Size = s end
	end
	local ok = pcall(function() workspace:BulkMoveTo(self.parts, self.cfs, Enum.BulkMoveMode.FireCFrameChanged) end)
	if not ok then
		for i, p in self.parts do p.CFrame = self.cfs[i] end
	end
end

-- Words on a part's face (a SurfaceGui), in the house font with the house outline.
local function words(part, face, text, color, stroke, ppS, light0)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Words'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 30
	g.LightInfluence = light0 or 0.6
	local l = Instance.new('TextLabel')
	l.Name = 'Text'
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	local st
	if Fonts and type(Fonts.apply) == 'function' then
		local _, s = Fonts.apply(l, 'Title', { stroke = 4, strokeColor = stroke })
		st = s
	end
	if not st then
		st = Instance.new('UIStroke')
		st.Color = stroke or C3(6, 6, 8)
		st.Thickness = 4
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
	end
	l.Parent = g
	g.Parent = part
	return l, st
end

---------------------------------------------------------------------------------------------- the map's kit
-- (TheBlockV2's street props at the same sizes, with fewer pieces: the set has a part budget)
local Kit = {}
-- Window on a facade frame: a studded stone frame standing proud, the glass in two blues split by a navy bar, and a
-- sill when `sill`. x = centre, y = frame bottom. lit: the glass glows warm in the dark beats (UnboxStage.night).
function Kit.window(c, x, y, w, h, lit, sill)
	local x0, x1, y1, t = x - w / 2, x + w / 2, y + h, 0.9
	c:box('WindowFrame', V3(x0, y, -0.2), V3(x1, y1, 0.75), PAL.trim, { st = 'all' })
	local a = c:box('Glass', V3(x0 + t, y + t, -0.2), V3(x, y1 - t, 0.82), PAL.glassA, { st = 'all' })
	local b = c:box('Glass', V3(x, y + t, -0.2), V3(x1 - t, y1 - t, 0.84), PAL.glassB, { st = 'all' })
	c:box('WindowBar', V3(x - 0.35, y + t, -0.2), V3(x + 0.35, y1 - t, 0.95), PAL.mullion, { st = 'all' })
	if sill then c:box('WindowSill', V3(x0 - 0.5, y - 0.7, -0.2), V3(x1 + 0.5, y, 1.3), PAL.sill, { st = 'all' }) end
	if lit then
		table.insert(c.job.nightParts, { a, PAL.windowLit:Lerp(BLACK, 0.12) })
		table.insert(c.job.nightParts, { b, PAL.windowLit })
	else
		-- (the pale glass of an unlit window would be the brightest thing left in a dark beat: it goes dark too)
		UnboxStage.dims(c.job, a, 0.55)
		UnboxStage.dims(c.job, b, 0.55)
	end
end
-- Stacked-cube tree on a short grey trunk (the map's: three tiers that step in, darker below), scale s.
function Kit.tree(c, pos, s, yaw, tint, simple)
	local t = c:at(CF(pos) * ANG(0, math.rad(yaw or 0), 0))
	local leaf, dark = tint or PAL.leaf, (tint or PAL.leaf):Lerp(PAL.leafDark, 0.6)
	local parts = {}
	local function B(name, a, b, col, sh) table.insert(parts, t:box(name, a * s, b * s, col, { st = 'all', shadow = sh })) end
	B('Trunk', V3(-1.5, 0, -1.5), V3(1.5, 3.8, 1.5), PAL.trunk, true)
	B('Crown', V3(-3.5, 3.8, -3.5), V3(3.5, 8.6, 3.5), dark:Lerp(BLACK, 0.06), true)
	B('Crown', V3(-3, 8.6, -2.5), V3(3, 12.4, 3.5), leaf, true)
	B('Crown', V3(-2.2, 12.4, -1.7), V3(2.2, 14.8, 2.7), leaf:Lerp(WHITE, 0.1), true)
	if not simple then B('CrownTop', V3(-1.3, 14.8, -0.8), V3(1.3, 15.8, 1.8), leaf:Lerp(WHITE, 0.16)) end
	return parts
end
-- Tall street lamp in three navy tones (the map's lantern), its arm out over the road toward dir; the head carries
-- the lamp's PointLight (off by day: the cinematic drives it). w thins it (the set's is 0.7 wide: a slim pole in the
-- wide shots, the map's full height).
function Kit.lamp(c, pos, dir, job, w)
	w = w or 1
	local l = c:at(CF(pos) * ANG(0, math.atan2(dir.X, dir.Z), 0)) -- (local +Z points at the road)
	local col, dark = PAL.lamp, PAL.lampDark
	local function B(name, a, b, colour, o) return l:box(name, V3(a.X * w, a.Y, a.Z * w), V3(b.X * w, b.Y, b.Z * w), colour, o) end
	B('LampPlinth', V3(-2.1, -0.2, -2.1), V3(2.1, 0.9, 2.1), dark, { st = 'all' })
	B('LampBase', V3(-1.7, 0.9, -1.7), V3(1.7, 3, 1.7), col, { st = 'all', shadow = true })
	B('LampPole', V3(-0.9, 3, -0.9), V3(0.9, 26.4, 0.9), col, { st = 'all', shadow = true })
	B('LampCap', V3(-1.2, 26.4, -1.2), V3(1.2, 27.4, 1.2), dark, { st = 'all' })
	l:box('LampArm', V3(-0.5 * w, 24.7, 0.9 * w), V3(0.5 * w, 25.7, 7.4), col, { st = 'all' })
	l:box('LampHead', V3(-0.8, 24.3, 5.0), V3(0.8, 25.9, 8.1), PAL.lampLight, { st = 'all' })
	local head = l:box('LampGlow', V3(-0.45, 24.05, 6.4), V3(0.45, 24.25, 7.7), PAL.lampGlow, { mat = MAT.Neon })
	local lt = light(head, C3(255, 226, 170), 0, 34)
	table.insert(job.lamps, { head = head, light = lt, color = head.Color })
	return head
end
-- Fire hydrant: red barrel on a darker foot, a collar and cap, side nozzles.
function Kit.hydrant(c, pos)
	local h = c:at(CF(pos))
	local red, dark = C3(226, 56, 48), C3(168, 36, 34)
	h:box('HydrantFoot', V3(-1, 0, -1), V3(1, 0.5, 1), dark, { st = 'all' })
	h:box('HydrantBody', V3(-0.7, 0.5, -0.7), V3(0.7, 2.9, 0.7), red, { st = 'all', shadow = true })
	h:box('HydrantCap', V3(-0.85, 2.6, -0.85), V3(0.85, 3.2, 0.85), dark, { st = 'all' })
	h:box('HydrantNozzles', V3(-1.1, 1.5, -0.35), V3(1.1, 2.1, 0.35), dark, { st = 'all' })
end
-- Wooden crate with a darker band and a boombox on it (the map's crate and boombox): the speakers the cinematic bumps.
function Kit.boombox(c, cf, job)
	local k = c:at(cf)
	k:box('Crate', V3(-1.4, 0, -1.4), V3(1.4, 2.8, 1.4), PAL.crate, { mat = MAT.WoodPlanks, shadow = true })
	k:box('CrateBand', V3(-1.45, 2.3, -1.45), V3(1.45, 2.6, 1.45), PAL.woodDark, { mat = MAT.Wood })
	local b = k:at(CF(0, 2.8, 0))
	local parts = {
		b:box('BoomboxCase', V3(-1.5, 0, -0.5), V3(1.5, 1.5, 0.5), C3(36, 38, 44), { st = 'all' }),
		b:box('BoomboxHandle', V3(-1.1, 1.5, -0.15), V3(1.1, 1.9, 0.15), C3(190, 194, 202), { st = 'all' }),
	}
	for _, x in { -0.8, 0.8 } do
		table.insert(parts, b:part('BoomboxSpeaker', V3(0.12, 1.0, 1.0), CF(x, 0.75, -0.55) * ANG(0, PI / 2, 0), C3(190, 194, 202), { shape = Enum.PartType.Cylinder }))
		table.insert(parts, b:part('BoomboxCone', V3(0.14, 0.6, 0.6), CF(x, 0.75, -0.6) * ANG(0, PI / 2, 0), C3(60, 62, 70), { shape = Enum.PartType.Cylinder }))
	end
	local base = b.cf
	table.insert(job.speakers, { actor = newBump(parts, base), base = base })
	return parts
end
-- Wheelie bin (dark green body, darker lid, black handle) and a heap of two black bags.
function Kit.bins(c, cf, color)
	local b = c:at(cf)
	color = color or C3(40, 120, 70)
	b:box('BinBody', V3(-1.2, 0, -1.3), V3(1.2, 3.6, 1.3), color, { st = 'all', shadow = true })
	b:box('BinLid', V3(-1.4, 3.6, -1.4), V3(1.5, 4.0, 1.4), color:Lerp(BLACK, 0.25), { st = 'all' })
	local g = b:at(CF(2.8, 0, 0.4) * ANG(0, 0.6, 0))
	g:box('TrashBag', V3(-1.1, 0, -1.1), V3(1.1, 1.8, 1.1), C3(44, 46, 54), { st = 'all' })
	g:at(CF(1.2, 0, 1.3) * ANG(0, 0.5, 0.15)):box('TrashBag', V3(-0.9, 0, -0.9), V3(0.9, 1.5, 0.9), C3(50, 52, 60), { st = 'all' })
end
-- Traffic cone (the map's training cones): an orange studded foot and a two-step cone with a white band.
function Kit.cone(c, pos, s)
	s = s or 1
	local k = c:at(CF(pos))
	k:box('ConeFoot', V3(-0.9, 0, -0.9) * s, V3(0.9, 0.3, 0.9) * s, C3(240, 110, 30), { st = 'all' })
	k:box('Cone', V3(-0.55, 0.3, -0.55) * s, V3(0.55, 1.6, 0.55) * s, C3(250, 130, 40), { st = 'all' })
	k:box('ConeBand', V3(-0.6, 1.0, -0.6) * s, V3(0.6, 1.35, 0.6) * s, C3(245, 245, 245))
end
-- Low white picket fence along this frame's Z from z0 to z1 at x (a front-garden boundary of the map's houses):
-- pickets on two rails, a capped square post at each end.
function Kit.picket(c, x, z0, z1)
	local white, rail = C3(240, 240, 234), C3(206, 206, 200)
	c:box('PicketRail', V3(x - 0.2, 1.4, z0), V3(x + 0.2, 1.8, z1), rail)
	c:box('PicketRail', V3(x - 0.2, 3.1, z0), V3(x + 0.2, 3.5, z1), rail)
	for _, z in { z0, z1 } do
		c:box('PicketPost', V3(x - 0.5, 0, z - 0.5), V3(x + 0.5, 4.8, z + 0.5), white, { st = 'all' })
		c:box('PicketPostCap', V3(x - 0.65, 4.8, z - 0.65), V3(x + 0.65, 5.2, z + 0.65), rail, { st = 'all' })
	end
	local n = math.floor(math.abs(z1 - z0) / 1.6)
	for k = 1, n - 1 do
		local z = z0 + (z1 - z0) * k / n
		c:box('Picket', V3(x - 0.15, 0, z - 0.35), V3(x + 0.15, 4.1, z + 0.35), white, { st = 'all' })
	end
end
-- Low hedge: a darker lower block and a lighter top.
function Kit.hedge(c, pos, len)
	local h = c:at(CF(pos))
	h:box('Hedge', V3(-1.6, 0, -len / 2), V3(1.6, 2.2, len / 2), PAL.hedge:Lerp(BLACK, 0.08), { st = 'all', shadow = true })
	h:box('Hedge', V3(-1.2, 2.2, -len / 2 + 0.6), V3(1.2, 3.6, len / 2 - 1.4), PAL.hedge:Lerp(PAL.leaf, 0.5), { st = 'all' })
end

-- A brick building on a facade frame (+Z out of the front, +X along it): w long, d deep, eave at h, in the map's
-- three brick tones (the wall, a darker plinth, thin darker courses) with a slate band between the storeys, a stone
-- cornice and a slate roof ('gable': the ridge along the front, 'flat': a coping and an air-con box).
-- o.windows = { { x, y, w, h, lit } } on the front; o.side = { frame, list } adds windows on another face.
local function building(c, o)
	local w, d, h = o.w, o.d, o.h
	local wall = o.wall or PAL.brick
	local dark = wall:Lerp(BLACK, 0.18)
	c:box('Wall', V3(0, -1, -d), V3(w, h, 0), wall, { st = 'all', shadow = true })
	c:box('Plinth', V3(-0.3, -1, -d - 0.3), V3(w + 0.3, 2.4, 0.3), dark, { st = 'all' })
	for _, y in o.courses or {} do
		c:box('BrickCourse', V3(-0.06, y, -d - 0.06), V3(w + 0.06, y + 0.35, 0.06), dark:Lerp(wall, 0.35))
	end
	if o.band then c:box('Band', V3(-0.5, o.band, -d - 0.5), V3(w + 0.5, o.band + 1.2, 0.5), PAL.band, { st = 'all' }) end
	c:box('Cornice', V3(-0.6, h - 1.2, -d - 0.6), V3(w + 0.6, h, 0.6), PAL.trim, { st = 'all' })
	if o.roof == 'gable' then
		local rise = o.rise or 6
		c:box('RoofEave', V3(-1, h, -d - 1), V3(w + 1, h + 1, 1), PAL.roofDark, { st = 'all', shadow = true })
		c:wedge('RoofSlope', V3(w + 2, rise, d / 2 + 1), CF(w / 2, h + 1 + rise / 2, 0.5 - d / 4) * ANG(0, PI, 0), PAL.roof, { st = 'all', shadow = true })
		c:wedge('RoofSlope', V3(w + 2, rise, d / 2 + 1), CF(w / 2, h + 1 + rise / 2, -d * 3 / 4 - 0.5), PAL.roof, { st = 'all', shadow = true })
		c:box('RidgeCap', V3(-1, h + rise + 0.7, -d / 2 - 0.6), V3(w + 1, h + rise + 1.4, -d / 2 + 0.6), PAL.roofDark, { st = 'all' })
	else
		c:box('Coping', V3(-0.4, h, -d - 0.4), V3(w + 0.4, h + 0.6, 0.4), PAL.trim, { st = 'all' })
		if o.ac then c:box('RoofAirCon', V3(o.ac - 1.8, h + 0.6, -d * 0.5 - 1.5), V3(o.ac + 1.8, h + 2.8, -d * 0.5 + 1.5), C3(206, 210, 216), { st = 'all', shadow = true }) end
	end
	for _, win in o.windows or {} do Kit.window(c, win[1], win[2], win[3], win[4], win[5], o.sills) end
	if o.side then
		for _, win in o.side[2] do Kit.window(o.side[1], win[1], win[2], win[3], win[4], win[5]) end
	end
	return dark
end

---------------------------------------------------------------------------------------------- the layout
-- Every size the set needs, from the plan: the road widens for a Buy 3 / Buy 8 pad (and the riser), the step line
-- moves back with it.
local function layout(P)
	local R = P.padR or 6.7
	local riserW = P.riser and P.riser.w / 2 + 1 or 0
	local RW = math.max(9, R + 2, riserW)
	local L = { R = R, RW = RW }
	L.WALK = 6.5
	L.SIDE = RW + L.WALK -- (the plaza's sides: the building line on the right, the yard on the left)
	L.KERB = 0.6 -- (the roads lie a kerb below the plaza)
	L.WY = 0 -- the plaza and the walks (the deck the pad stands on)
	L.ZC = -math.max(10.5, R + 3.5) -- the plaza's near kerb, on the cross street the camera stands in
	L.ZS = 24 + (RW - 9) * 0.6 -- the step line: the end buildings' fronts
	L.HS, L.HM = 13.2, 12.4 -- the shop's and the mural block's heights (low: the sky comes down behind the box)
	L.FAR = 12 -- the far street's walls at |x| = FAR (out past the calm zone behind the box)
	L.FR = 4.5 -- the far road's half-width
	L.ZE = L.ZS + 64 -- the far street's end
	L.ZN = -34 -- the near end of everything (behind the furthest camera)
	L.XR = -(L.SIDE + 1.5) -- the near-right building's front (the frame's right, -X)
	L.XL = L.SIDE + 10 -- the near-left house's front, behind its yard
	return L
end
UnboxStage.layout = layout

---------------------------------------------------------------------------------------------- the ground
local function ground(job, c, L)
	local RW, SIDE, KERB, ZS, ZN, ZE, FAR, FR, ZC = L.RW, L.SIDE, L.KERB, L.ZS, L.ZN, L.ZE, L.FAR, L.FR, L.ZC
	local XW = SIDE + 30 -- (out past the building lines)
	-- the plaza: the map's light studded walk in big slabs, a few darker joints and a lighter slab, the pad in its middle
	UnboxStage.dims(job, c:box('Plaza', V3(-XW, -1, ZC), V3(SIDE + 0.8, 0, ZS), PAL.walk, { st = 'top' }))
	UnboxStage.dims(job, c:box('Walk', V3(SIDE + 0.8, -1, ZS - 5), V3(XW, 0, ZS), PAL.walk, { st = 'top' }))
	for _, x in { -(RW - 0.5), RW - 0.5 } do
		c:box('WalkJoint', V3(x - 0.15, -0.1, ZC), V3(x + 0.15, 0.02, ZS - 5), PAL.walkJoint)
	end
	for _, z in { 8, ZS - 5 } do
		c:box('WalkJoint', V3(-SIDE, -0.1, z - 0.15), V3(SIDE + 0.8, 0.02, z + 0.15), PAL.walkJoint)
	end
	UnboxStage.dims(job, c:box('WalkSlab', V3(RW - 0.35, -0.1, ZC), V3(SIDE + 0.8, 0.025, 8 - 0.15), PAL.walk:Lerp(WHITE, 0.1), { st = 'top' }))
	UnboxStage.dims(job, c:box('WalkSlab', V3(-SIDE, -0.1, 8 + 0.15), V3(-(RW - 0.35), 0.025, ZS - 5.15), PAL.walk:Lerp(WHITE, 0.1), { st = 'top' }))
	-- the yard's grass on the left, behind its fence
	c:box('Grass', V3(SIDE + 0.8, -1, ZN), V3(L.XL + 1, 0, ZS - 5), PAL.grass, { st = 'top' })
	c:box('GrassEdge', V3(SIDE + 0.8, -0.2, ZC), V3(SIDE + 1.6, 0.04, ZS - 5), PAL.grassEdge, { st = 'top' })
	-- the cross street the camera stands in: studded road a kerb down, a darker gutter, the yellow dashes along it
	c:box('Road', V3(-XW, -1, ZN), V3(XW, -KERB, ZC), PAL.road, { st = 'top' })
	c:box('KerbStone', V3(-XW, -1, ZC - 1), V3(XW, 0.08, ZC + 0.05), PAL.kerbStone, { st = 'all' })
	c:box('RoadGutter', V3(-XW, -1, ZC - 2.2), V3(XW, -KERB + 0.03, ZC - 1), PAL.roadDark, { st = 'top' })
	local zd = ZC - 9.5
	for _, x in { -26, -8, 10 } do c:box('RoadDash', V3(x, -KERB, zd - 0.5), V3(x + 4, -KERB + 0.2, zd + 0.5), PAL.dash, { st = 'all' }) end
	local mh = V3(RW * 0.55, -KERB, ZC - 5)
	c:box('ManholeRim', mh + V3(-1.5, -0.2, -1.5), mh + V3(1.5, 0.05, 1.5), PAL.manhole, { st = 'top' })
	-- the far street past the step line: its road a kerb down between the walks, the yellow dashes down the middle
	c:box('Road', V3(-FR, -1, ZS), V3(FR, -KERB, ZE), PAL.road, { st = 'top' })
	for _, s in { -1, 1 } do
		UnboxStage.dims(job, c:box('Sidewalk', V3(s * FR, -1, ZS), V3(s * FAR, 0, ZE), PAL.walk, { st = 'top' }))
		c:box('KerbStone', V3(s * (FR - 0.05), -1, ZS), V3(s * (FR + 1), 0.08, ZE), PAL.kerbStone, { st = 'all' })
	end
	c:box('KerbStone', V3(-FR, -1, ZS - 0.05), V3(FR, 0.08, ZS + 1), PAL.kerbStone, { st = 'all' })
	for z = ZS + 8, ZE - 8, 16 do c:box('RoadDash', V3(-0.5, -KERB, z), V3(0.5, -KERB + 0.2, z + 4), PAL.dash, { st = 'all' }) end
	-- the far end: the low boundary wall of the block and the grass past it
	c:box('EndWall', V3(-FAR - 4, -1, ZE), V3(FAR + 4, 3, ZE + 1.4), C3(214, 214, 218), { st = 'all' })
	c:box('EndWallCap', V3(-FAR - 4.2, 3, ZE - 0.2), V3(FAR + 4.2, 3.5, ZE + 1.6), C3(222, 222, 226), { st = 'all' })
	c:box('EndGrass', V3(-60, -1, ZE + 1.4), V3(60, 0.4, ZE + 80), C3(104, 178, 72), { mat = MAT.Grass })
end

---------------------------------------------------------------------------------------------- the pad and the riser
-- The landing pad: the lobby's box pad flattened to 0.22 (the box stands on its top): a neon lip round a dark drum, a
-- pale top with a band. padRim is the lip (the cinematic colours it), 'Pad' the top.
local function pad(job, c, L)
	local R = L.R
	local padTop = 0.22
	job.padRim = c:post('PadRim', R * 2 + 0.7, 0.15, V3(0, 0, 0), PAL.rimEgg, { mat = MAT.Neon })
	c:post('PadDrum', R * 2 + 0.2, 0.19, V3(0, 0, 0), C3(40, 44, 70))
	job.padMat = c:post('Pad', R * 2 - 0.3, padTop, V3(0, 0, 0), C3(186, 192, 222))
	job.padBand = c:post('PadBand', R * 2 - 1.6, padTop + 0.006, V3(0, 0, 0), C3(150, 158, 198))
	job.padInner = c:post('PadInner', R * 2 - 2.6, padTop + 0.012, V3(0, 0, 0), C3(192, 198, 226))
	for _, p in { job.padMat, job.padBand, job.padInner } do UnboxStage.dims(job, p) end
	job.padTop = job.O.Y + padTop
	job.deckY = job.O.Y
	local P = job.P
	if P.riser then
		local r = P.riser
		c:box('Riser', V3(-r.w / 2, 0, r.z - r.d / 2), V3(r.w / 2, r.h, r.z + r.d / 2), PAL.walk, { st = 'all', shadow = true })
		c:box('RiserLip', V3(-r.w / 2 - 0.1, r.h - 0.3, r.z - r.d / 2 - 0.1), V3(r.w / 2 + 0.1, r.h + 0.06, r.z - r.d / 2 + 0.7), PAL.kerbStone, { st = 'all' })
		job.riser = r
	end
end

---------------------------------------------------------------------------------------------- the near street
-- Right (-X): a two-storey brick block (a gable roof with its ridge along the street), the street lamp, the boombox
-- and a cone on the plaza. Left (+X): a lower house set back behind its grass and white picket fence, a cube tree in
-- the yard, the hydrant on the plaza.
local function nearStreet(job, c, L)
	local RW, SIDE, ZS = L.RW, L.SIDE, L.ZS
	-- right: 23 studs to the eave, from z -14 to 3 (it ends early: the sky shows over the yard behind it)
	local z0, z1 = -14, 3
	local fR = facade(c, L.XR, z1, '+x')
	building(fR, {
		w = z1 - z0, d = 14, h = 23, wall = PAL.brick, roof = 'gable', rise = 4.5, band = 12, courses = { 4.6, 17.4 },
		sills = true, windows = { { 8.5, 3.6, 8, 6.8 }, { 8.5, 14.6, 8, 6.2, true } },
	})
	-- left: a lighter brick house behind the yard, a flat roof, 19 to the coping
	local lz0, lz1 = -14, 6 -- (it ends well short of the shop: the sign on the shop's corner stays whole in view)
	local fL = facade(c, L.XL, lz0, '-x')
	building(fL, {
		w = lz1 - lz0, d = 14, h = 19, wall = PAL.brickLight, roof = 'flat', courses = { 5, 11 },
		windows = { { (lz1 - lz0) * 0.3, 12.6, 6, 4.8, true }, { (lz1 - lz0) * 0.72, 12.6, 6, 4.8 } },
	})
	-- the yard's white picket fence along the plaza, a tree and a hedge in the yard
	-- (the fence stops at z 1 and the tree stands near its front end: neither hides the shop's poster or the
	-- rooftop sign from the wide shots)
	Kit.picket(c, SIDE + 1.2, -10, 1)
	job.trees = { Kit.tree(c, V3(SIDE + 6.5, L.WY, -6), 0.9, 12) }
	Kit.hedge(c, V3(L.XL - 3, L.WY, -11.2), 6)
	-- the street lamp (a key light) and the plaza's props
	-- (the lamp stands far out on the left, past the house's end: at least 30 studs from every camera mark, a
	-- slim pole with its head in the wide shots, on the orbit camera's own side so never behind the box, clear of the
	-- boxes; the second lamp is the shop's wall lamp)
	Kit.lamp(c, V3(SIDE + 18, L.WY, ZS - 10), V3(-1, 0, 0), job, 0.7)
	Kit.hydrant(c, V3(RW + 1.8, L.WY, -2))
	Kit.boombox(c, CF(-(RW + 2.5), L.WY, -2) * ANG(0, math.rad(-62), 0), job)
	Kit.cone(c, V3(-(RW + 1.9), L.WY, 6.5))
	Kit.hedge(c, V3(L.XR - 2.2, L.WY, 11.5), 9)
end

---------------------------------------------------------------------------------------------- the step line
-- The two end buildings' fronts face the camera at z = ZS. Left (+X): the corner shoe shop (one storey and a
-- parapet, a striped awning, its window posters) with the rooftop sign on top. Right (-X): a low block whose front is
-- the mural wall (posters, a drip and a word). Each side's posters are one group that framePosters
-- slides along that front.
local function posterPanel(job, c, gi, name, x, y, sx, sy, rot, color, mat)
	local face = job.wallInfo.face
	local p = c:part(name, V3(sx, sy, 0.08), CF(x, y, face) * ANG(0, 0, rot), color, { mat = mat })
	table.insert(job.posterParts, p)
	table.insert(job.posterGroups[gi].parts, p)
	return p
end
local function posterWord(job, c, gi, x, y, rot, text, size, color)
	local face = job.wallInfo.face
	local p = c:part('Tag', V3(size.X, size.Y, 0.05), CF(x, y, face - 0.08) * ANG(0, 0, rot), color, { t = 0.999 })
	-- (the wall faces -Z, toward the camera: so does the part's Front face)
	local l, st = words(p, Enum.NormalId.Front, text, color, C3(24, 20, 30), 30, 0.6)
	l.Name = 'TagText'
	table.insert(job.posterLabels, { l, st })
	table.insert(job.wordParts, p)
	table.insert(job.posterGroups[gi].parts, p)
	job.posterGroups[gi].word = p
	return p
end
local function stepLine(job, c, L)
	local ZS, FAR, SIDE = L.ZS, L.FAR, L.SIDE
	local face = ZS - 0.65
	job.posterParts, job.posterLabels, job.wordParts = {}, {}, {}
	-- group 1: the right (-X) wall; group 2: the left (+X) shop
	job.posterGroups = {
		{ parts = {}, x0 = -(SIDE + 21), x1 = -FAR - 0.6, y0 = 1.2, y1 = 12.4 },
		{ parts = {}, x0 = FAR + 0.6, x1 = SIDE + 14, y0 = 2.4, y1 = 6.9 }, -- (under the shop's awning)
	}
	job.wallInfo = { wz = ZS, h = 12.5, w = 2 * (SIDE + 14), face = face }
	-- the right block: brick in the deep tone, flat roof, two windows up top, the mural below
	local wR = SIDE + 22 - FAR
	local fR = facade(c, -FAR, ZS, '-z')
	building(fR, {
		w = wR, d = 22, h = L.HM, wall = PAL.brickDeep, roof = 'flat', courses = { 4.6, 9.2 },
	})
	-- the left shop: one storey, a parapet; the shopfront 8 to 23.5 in from its outer end (so it keeps its place by
	-- the plaza in every layout)
	local wL = SIDE + 22 - FAR
	local fL = facade(c, SIDE + 22, ZS, '-z')
	building(fL, {
		w = wL, d = 22, h = L.HS, wall = PAL.brick, roof = 'flat', courses = { 4.6 },
	})
	job.shop = UnboxStage._shopfront(job, fL, 8, 23.5)
	return face
end
-- The corner shoe shop's front (on the facade frame f, between x0 and x1): a stone stall riser, display glass in two
-- blues split by dark mullions, a glazed door at the x1 end, a fascia board, a striped awning over the walk.
function UnboxStage._shopfront(job, f, x0, x1)
	local col = PAL.shop
	local dark = col:Lerp(BLACK, 0.35)
	local dx = x1 - 3
	local gm = (x0 + dx - 2.2) / 2
	local shop = { awning = {}, glass = {} }
	f:box('StallRiser', V3(x0, 0.6, -0.2), V3(x1, 2.2, 0.7), PAL.trim, { st = 'all' })
	shop.glass[1] = f:box('ShopGlass', V3(x0, 2.2, -0.2), V3(dx - 2.2, 8.4, 0.1), PAL.glassA, { st = 'all' })
	shop.glass[2] = f:box('ShopGlass', V3(x0, 2.2, -0.2), V3(gm, 8.4, 0.12), PAL.glassB, { st = 'all' })
	f:box('ShopMullion', V3(gm - 0.3, 2.2, -0.2), V3(gm + 0.3, 8.4, 0.5), dark, { st = 'all' })
	shop.frame = f:box('ShopDoorFrame', V3(dx - 2.2, 0.6, -0.2), V3(dx + 2.2, 9, 0.5), dark, { st = 'all' })
	shop.glass[3] = f:box('ShopDoor', V3(dx - 1.6, 0.6, -0.2), V3(dx + 1.6, 8.2, 0.6), PAL.glassB, { st = 'all' })
	shop.fascia = f:box('Fascia', V3(x0 - 0.6, 9, -0.2), V3(x1 + 0.6, 11.6, 1.1), col, { st = 'all' })
	f:box('FasciaCap', V3(x0 - 0.8, 11.6, -0.2), V3(x1 + 0.8, 12.1, 1.4), PAL.trim, { st = 'all' })
	-- (a plain fascia: the frame already has its sign and the posters' two words)
	shop.stripe = f:box('FasciaStripe', V3(x0 + 1, 9.9, 1.1), V3(x1 - 1, 10.7, 1.2), WHITE)
	local n = 4
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		table.insert(shop.awning, f:wedge('Awning', V3(b - a, 1.6, 3.4), CF((a + b) / 2, 8.2, 1.8) * ANG(0, PI, 0), k % 2 == 0 and col or WHITE, { shadow = true }))
	end
	shop.valance = f:box('AwningValance', V3(x0, 7, 3.4), V3(x1, 7.5, 3.6), col)
	-- the wall lamp at the shop's outer end (the map's entrance lamp): the set's second lamp
	local lx = x0 - 1.8
	f:box('WallLamp', V3(lx - 0.55, 6.6, -0.2), V3(lx + 0.55, 8.2, 0.9), PAL.lamp, { st = 'all' })
	local glow = f:box('WallLampGlow', V3(lx - 0.4, 6.8, 0.9), V3(lx + 0.4, 8.0, 1.0), PAL.lampGlow, { mat = MAT.Neon })
	table.insert(job.lamps, { head = glow, light = light(glow, C3(255, 226, 170), 0, 18), color = glow.Color })
	for _, g in shop.glass do table.insert(job.nightParts, { g, PAL.shopLit }) end
	return shop
end
-- The posters and words: painted panels on the mural wall (right) and pasted in the shop's window (left), each group
-- with its word. The egg set wears the hood's own colours and words (never the box's colour, which would echo it);
-- the Secret wears the theme's (UnboxStage.paint).
local HOOD = { Color = C3(70, 210, 230), Accent = C3(60, 110, 220), Third = C3(250, 250, 252), Tags = { 'HOOD', 'KICKS' } }
local function posterColours(th)
	local cols = { th.Color, th.Accent, th.Third, C3(255, 214, 60), C3(70, 210, 230) }
	if th.Poster == 'gold' then cols = { C3(255, 200, 70), C3(240, 170, 40), th.Accent, C3(255, 226, 140), th.Color } end
	return cols
end
local function posters(job, c, L)
	job.paint = {}
	local function panel(gi, name, x, y, sx, sy, rot, k)
		table.insert(job.paint, { posterPanel(job, c, gi, name, x, y, sx, sy, rot, WHITE), k })
	end
	-- right group (-X): a big panel and a small one on the mural wall, a drip under the big one, the word on it
	-- (whole in the egg and wide frames, clear of the boombox and of a Buy 3's row; near the orbit's line only at yaw 41)
	local xr = -(L.SIDE + 7.5 + (L.RW - 9) * 0.1)
	panel(1, 'Graffiti', xr, 8.2, 9, 5.2, 0.08, 1)
	panel(1, 'Graffiti', xr - 6.4, 10.4, 4.2, 2, -0.1, 4)
	panel(1, 'Drip', xr - 2.4, 4.6, 0.45, 2, 0, 1)
	posterWord(job, c, 1, xr, 8.2, 0.08, 'KICKS', V3(7.6, 3.4, 0), WHITE)
	-- left group (+X): posters in the shop's window and a sticker
	local xl = L.SIDE + 8 -- (on the shop's glass, which keeps it out past the back row of a Buy 3 or a Buy 8)
	panel(2, 'Graffiti', xl, 4.65, 6.4, 3.9, -0.05, 2)
	panel(2, 'Graffiti', xl + 4.6, 3.9, 2.4, 2.4, 0.12, 3)
	posterWord(job, c, 2, xl, 4.65, -0.05, 'HOOD', V3(5.6, 2.8, 0), C3(255, 240, 120))
end
-- Paints the posters, their words and the sign in a theme (the egg set's HOOD look, or the box's for the Secret).
function UnboxStage.paint(job, th)
	local cols = posterColours(th)
	job.nightWords = nil -- (night() takes the words' day colours afresh)
	local mat = th.Poster == 'glass' and MAT.Glass or th.Poster == 'gold' and MAT.Foil or MAT.SmoothPlastic
	for _, e in job.paint or {} do
		e[1].Color = cols[e[2]]
		e[1].Material = mat
		if th.Poster == 'glass' then e[1].Transparency, e[1].Reflectance = 0.3, 0.2 end
	end
	local tags = th.Tags or HOOD.Tags
	for i, l in job.posterLabels or {} do l[1].Text = tags[i == 1 and 2 or 1] or l[1].Text end
	local rim = th.Rim or PAL.rimEgg
	for _, p in job.signNeon or {} do p.Color = rim end
	if job.signText then
		job.signText.TextColor3 = rim:Lerp(WHITE, 0.45)
		job.signStroke.Color = rim:Lerp(BLACK, 0.6)
	end
end
-- The rooftop sign over the shop: a dark board on two posts, a neon frame and "+1 DROP" (free-standing, so fading it
-- leaves the roof whole). UnboxStage.paint colours it: pale in the egg set, the theme's rim colour in the Secret.
local function sign(job, c, L)
	-- (on the front edge of the shop's roof at its far corner: whole in every frame that sees it, never sunk behind the
	-- parapet from the low egg camera, and out of the reveal's title band at every mark)
	local w, h = 9, 3
	local x0 = L.SIDE + 22 - w / 2 - 0.6
	local y0 = L.HS + 0.6
	local z = L.ZS + 0.9
	local board = c:box('Sign', V3(x0 - w / 2, y0 + 1.4, z - 0.25), V3(x0 + w / 2, y0 + 1.4 + h, z + 0.25), C3(26, 24, 34))
	job.signParts = {
		board,
		c:box('SignPost', V3(x0 - w * 0.3 - 0.25, y0, z + 0.25), V3(x0 - w * 0.3 + 0.25, y0 + 1.4, z + 0.75), C3(40, 40, 48), { mat = MAT.Metal }),
		c:box('SignPost', V3(x0 + w * 0.3 - 0.25, y0, z + 0.25), V3(x0 + w * 0.3 + 0.25, y0 + 1.4, z + 0.75), C3(40, 40, 48), { mat = MAT.Metal }),
	}
	local sy = y0 + 1.4 + h / 2
	job.signNeon = {}
	for _, e in { { 0, h / 2, w + 0.3, 0.22 }, { 0, -h / 2, w + 0.3, 0.22 }, { -w / 2, 0, 0.22, h }, { w / 2, 0, 0.22, h } } do
		table.insert(job.signNeon, c:part('SignNeon', V3(e[3], e[4], 0.2), CF(x0 + e[1], sy + e[2], z - 0.3), PAL.rimEgg, { mat = MAT.Neon }))
	end
	local l, st = words(board, Enum.NormalId.Front, '+1 DROP', WHITE, BLACK, 40, 0)
	job.signText, job.signStroke = l, st
	job.signGui = l.Parent
end

---------------------------------------------------------------------------------------------- the far street
-- Past the step buildings' sides: a lower block on each side that ends early, so from the egg camera the sky comes
-- down to the far street's end behind the box; the low end wall of the block; trees out to the sides, never in line
-- behind the box.
local function farStreet(job, c, L)
	local ZS, FAR, ZE = L.ZS, L.FAR, L.ZE
	local z0 = ZS + 22
	building(facade(c, FAR, z0, '-x'), { w = 18, d = 12, h = 14, wall = PAL.brickLight, roof = 'flat', courses = { 4.6 },
		windows = { { 9, 4, 6, 6.2, true } } })
	building(facade(c, -FAR, z0 + 22, '+x'), { w = 22, d = 12, h = 16, wall = C3(150, 158, 176), roof = 'flat', courses = { 4.6 },
		windows = { { 11, 4, 6, 6.2 } } })
	table.insert(job.trees, Kit.tree(c, V3(FAR + 6, L.WY, z0 + 23), 0.9, 30, nil, true))
	table.insert(job.trees, Kit.tree(c, V3(-FAR - 7, L.WY, z0 + 8), 0.85, -20, nil, true))
	Kit.bins(c, CF(-FAR - 15, L.WY, ZS - 2) * ANG(0, PI, 0))
	-- the ring road's trees past the end wall, out to the sides (the sky stays open behind the box)
	Kit.tree(c, V3(-FAR - 18, 0.4, ZE + 10), 1.2, 10, nil, true)
	Kit.tree(c, V3(FAR + 20, 0.4, ZE + 16), 1.1, 40, nil, true)
end

---------------------------------------------------------------------------------------------- anchors
local function anchors(job, c, L)
	local R, G = L.R, job.P.G or 1.33
	job.anchor = c:part('FxAnchor', V3(0.2, 0.2, 0.2), CF(0, 0, 0), WHITE, { t = 1 })
	job.boxGlow = c:part('BoxLight', V3(0.2, 0.2, 0.2), CF(0, 3, 0), WHITE, { t = 1 })
	job.boxLight = light(job.boxGlow, WHITE, 0, 16)
	job.volumes = {}
	local spec = {
		back = { V3(2 * L.FAR + 8, 10, 6), CF(0, 24, L.ZS + 4) },
		sky = { V3(70, 6, 40), CF(0, 30 * G, 6) },
		floor = { V3(R * 2.4, 0.4, R * 2.4), CF(0, 0.5, 0) },
		around = { V3(R * 1.7, 7 * G, R * 1.7), CF(0, 4.5 * G, 0) },
	}
	for name, v in spec do job.volumes[name] = c:part('Volume_' .. name, v[1], v[2], WHITE, { t = 1 }) end
end

-- Stage-space camera suggestions that see the calm far street behind the pair (the cinematic may use them or not).
local function marks(job, L)
	local R = L.R
	local d = math.max(15, R * 2.3)
	job.marks = {
		egg = { eye = V3(0, 3.3, -d), at = V3(0, 2.6, 0), fov = 60 },
		heroLeft = { eye = V3(math.sin(math.rad(15)) * 14, 7, -math.cos(math.rad(15)) * 14), at = V3(0, 6.5, 0), fov = 50 },
		heroRight = { eye = V3(-math.sin(math.rad(20)) * 14, 7, -math.cos(math.rad(20)) * 14), at = V3(0, 6.5, 0), fov = 50 },
		wide = { eye = V3(0, 4.7, -math.max(24, R * 2.6)), at = V3(0, 5, 0), fov = 62 },
	}
end

---------------------------------------------------------------------------------------------- the Secret's dressing
-- The same block dressed in the box's theme: the shop's awning, fascia and door, the pad's top, string lights across the
-- far street's mouth, and the theme's props (UnboxStage.Props). The posters already wear the theme.
UnboxStage.Props = {}
local function stringLights(job, c, L, th)
	local cols = { th.Color, th.Accent, th.Third, th.Rim }
	local y, z = 13.6, L.ZS + 1.4
	local x0, x1 = -L.FAR, L.FAR
	c:box('LightWire', V3(x0, y + 0.55, z - 0.06), V3(x1, y + 0.67, z + 0.06), C3(40, 40, 48))
	-- bulbs (lit in the dark beats) with the theme's bunting between them (diamond flags hung by a corner)
	local n = 11
	for k = 1, n do
		local x = x0 + (x1 - x0) * k / (n + 1)
		local col = cols[(k // 2) % #cols + 1]
		if k % 2 == 1 then
			local b = c:ball('LightBulb', 0.8, V3(x, y - 0.1, z), col:Lerp(WHITE, 0.3))
			table.insert(job.nightParts, { b, col:Lerp(WHITE, 0.15), kind = 'bulb' })
		else
			c:part('Bunting', V3(1.3, 1.3, 0.1), CF(x, y - 0.35, z - 0.1) * ANG(0, 0, PI / 4), col)
		end
	end
end

-- The theme's props, a few chunky pieces each (about 6 to 16 parts) in the map's kit, at the set's free spots: the left
-- walk by the hydrant (A), the right walk by the cone (B), the road round the pad, the roofs and the far street.
local function spots(L)
	return {
		A = V3(L.RW + 3.4, L.WY, 9.5), B = V3(-(L.RW + 3.2), L.WY, 10.5),
		roofL = V3(L.FAR + 9, L.HS + 0.6, L.ZS + 8), roofR = V3(-L.FAR - 8, L.HM + 0.6, L.ZS + 8),
		farL = V3(L.FAR - 2.6, L.WY, L.ZS + 12), farR = V3(-L.FAR + 2.6, L.WY, L.ZS + 18),
	}
end
-- a glowing flat patch on the ground (slime, lava, paint): lit in the dark beats too
local function patch(job, c, name, pos, d, color, glow)
	local p = c:post(name, d, 0.08, pos, color, { mat = glow and MAT.Neon or nil })
	return p
end
local function crystal(c, pos, s, color, tilt)
	local k = c:at(CF(pos) * ANG(0, tilt or 0, 0))
	k:part('Crystal', V3(1.2, 3.6, 1.2) * s, CF(0, 1.5 * s, 0) * ANG(0, 0.6, 0.12), color, { mat = MAT.Glass, t = 0.15 })
	k:part('Crystal', V3(0.9, 2.4, 0.9) * s, CF(0.9 * s, 1 * s, 0.3 * s) * ANG(0.2, 0.3, -0.45), color:Lerp(WHITE, 0.3), { mat = MAT.Glass, t = 0.1 })
	k:part('Crystal', V3(0.8, 2, 0.8) * s, CF(-0.8 * s, 0.8 * s, -0.2 * s) * ANG(-0.15, 1, 0.5), color, { mat = MAT.Glass, t = 0.15 })
end
local Props = UnboxStage.Props
Props.Street = function(job, c, L, th)
	local sp = spots(L)
	Kit.cone(c, sp.A + V3(-1.2, 0, -1.5))
	Kit.cone(c, sp.A + V3(0.6, 0, 1.2), 0.85)
	-- a stack of three tyres on the right walk
	for k = 0, 2 do c:post('Tyre', 2.6, 0.9, sp.B + V3(0, k * 0.9, 0), C3(34, 36, 42)) end
	c:post('TyreRim', 1.3, 0.92, sp.B + V3(0, 1.8, 0), C3(170, 174, 184))
end
Props.Graffiti = function(job, c, L, th)
	local sp = spots(L)
	for k, e in { { V3(L.RW * 0.55, 0, -L.R - 2), 3.2, th.Color }, { V3(-L.RW * 0.6, 0, -L.R + 2.5), 2.4, th.Accent }, { V3(L.RW * 0.3, 0, L.R + 3), 2.8, th.Third } } do
		patch(job, c, 'PaintSplat', e[1], e[2], e[3], false)
	end
	-- spray cans on a crate (the map's training-lane cans)
	c:box('Crate', sp.A + V3(-1.3, 0, -1.3), sp.A + V3(1.3, 2.2, 1.3), PAL.crate, { mat = MAT.WoodPlanks })
	for k, col in { th.Color, th.Accent, th.Third } do
		c:post('SprayCan', 0.7, 1.5, sp.A + V3(-0.8 + (k - 1) * 0.8, 2.2, 0), col, { st = 'top' })
	end
end
Props.Frost = function(job, c, L, th)
	local sp = spots(L)
	local snow = C3(244, 250, 255)
	c:box('SnowCap', V3(L.FAR + 0.2, L.HS + 0.6, L.ZS - 0.4), V3(L.SIDE + 22.4, L.HS + 1.4, L.ZS + 22.4), snow, { st = 'top' })
	c:box('SnowCap', V3(-L.FAR - 0.2, L.HM + 0.6, L.ZS - 0.4), V3(-(L.SIDE + 22.4), L.HM + 1.4, L.ZS + 22.4), snow, { st = 'top' })
	c:box('SnowDrift', sp.A + V3(-1.8, 0, -2.4), sp.A + V3(1.8, 1.1, 2.4), snow, { st = 'all' })
	for k, e in { { sp.B, 2.2 }, { sp.B + V3(0.8, 0, 2.6), 1.6 }, { sp.B + V3(-0.2, 2.2, 0.3), 1.3 } } do
		c:part('IceBlock', V3(e[2], e[2], e[2]), CF(e[1] + V3(0, e[2] / 2, 0)) * ANG(0, k * 0.5, 0), th.Accent, { mat = MAT.Glass, t = 0.2 })
	end
	for _, tree in job.trees or {} do
		for k = 3, #tree do tree[k].Color = snow:Lerp(th.Accent, (k - 3) * 0.25) end
	end
end
Props.Lava = function(job, c, L, th)
	local sp = spots(L)
	local glow = C3(255, 120, 30)
	local dimGlow = C3(150, 70, 20)
	for k, e in { { -L.RW * 0.55, -L.R - 1.5, 0.4 }, { L.RW * 0.5, -L.R - 3, -0.5 }, { -L.RW * 0.25, L.R + 2.5, 1.1 }, { L.RW * 0.6, L.R + 1, -1.2 } } do
		local p = c:part('LavaCrack', V3(0.5, 0.06, 4 + k % 2 * 2), CF(e[1], 0.02, e[2]) * ANG(0, e[3], 0), glow, { mat = MAT.Neon })
		table.insert(job.nightParts, { p, dimGlow })
	end
	for k, e in { { sp.A, 2.4 }, { sp.B, 2.8 }, { sp.B + V3(1.4, 0, 2.4), 1.8 } } do
		c:part('Rock', V3(e[2], e[2] * 0.8, e[2] * 1.1), CF(e[1] + V3(0, e[2] * 0.4, 0)) * ANG(0.1, k, 0.15), C3(58, 40, 38), { st = 'all' })
	end
end
Props.Toxic = function(job, c, L, th)
	local sp = spots(L)
	for k, pos in { sp.A, sp.B } do
		c:post('Barrel', 2.4, 3.2, pos, C3(70, 74, 60), { st = 'top' })
		c:post('BarrelBand', 2.5, 0.5, pos + V3(0, 2.1, 0), th.Third or C3(255, 210, 40))
	end
	for k, e in { { V3(L.RW * 0.5, 0, -L.R - 2.5), 3.4 }, { sp.A + V3(-2.4, 0.02, -2), 2.4 }, { V3(-L.RW * 0.45, 0, L.R + 2.6), 2.8 } } do
		local p = patch(job, c, 'Slime', e[1], e[2], th.Color, true)
		table.insert(job.nightParts, { p, th.Color:Lerp(BLACK, 0.4) })
	end
end
Props.Candy = function(job, c, L, th)
	local sp = spots(L)
	for k, e in { { sp.A, th.Color }, { sp.B, th.Accent }, { sp.farL, th.Third } } do
		c:box('LollipopStick', e[1] + V3(-0.2, 0, -0.2), e[1] + V3(0.2, 5, 0.2), WHITE)
		c:part('Lollipop', V3(0.6, 3.2, 3.2), CF(e[1] + V3(0, 6.4, 0)) * ANG(0, PI / 2, 0), e[2], { shape = Enum.PartType.Cylinder })
	end
	for _, tree in job.trees or {} do
		for k = 2, #tree do tree[k].Color = th.Color:Lerp(WHITE, 0.15 + (k - 2) * 0.1) end
	end
end
Props.Ocean = function(job, c, L, th)
	local sp = spots(L)
	-- two palms like the reference's island, in our blocks: a leaning studded trunk and four leaf slabs
	for k, e in { { sp.A + V3(1, 0, 0), 0.25 }, { sp.farR, -0.2 } } do
		local t = c:at(CF(e[1]) * ANG(0, k * 1.3, e[2]))
		t:box('PalmTrunk', V3(-0.7, 0, -0.7), V3(0.7, 11, 0.7), C3(150, 110, 70), { st = 'all' })
		for a = 0, 3 do
			t:at(CF(0, 11, 0) * ANG(0, a * PI / 2, 0)):part('PalmLeaf', V3(1.6, 0.5, 5), CF(0, -0.6, 2.4) * ANG(-0.35, 0, 0), PAL.leaf:Lerp(PAL.leafDark, a % 2 * 0.6), { st = 'all' })
		end
	end
	c:part('Surfboard', V3(1.6, 6, 0.4), CF(sp.B + V3(0, 3, 0)) * ANG(0, 0.3, 0.2), th.Accent, { st = 'all' })
end
Props.Gem = function(job, c, L, th)
	local sp = spots(L)
	crystal(c, sp.A, 1.2, th.Color, 0.3)
	crystal(c, sp.B, 1, th.Third, 1.4)
	crystal(c, sp.roofL, 1.4, th.Color, 2.2)
end
Props.Galaxy = function(job, c, L, th)
	-- two planets over the far street and a scatter of star blocks (they glow in the dark beats)
	for k, e in { { V3(-20, 40, L.ZE - 4), 16, th.Color }, { V3(26, 50, L.ZE + 26), 10, th.Third } } do
		c:ball('Planet', e[2], e[1], e[3])
		c:part('PlanetRing', V3(0.3, e[2] * 1.7, e[2] * 1.7), CF(e[1]) * ANG(0.4, 0, PI / 2 - 0.25), e[3]:Lerp(WHITE, 0.5), { shape = Enum.PartType.Cylinder, t = 0.2 })
	end
	for k = 1, 6 do
		local x = (k - 3.5) * 9 + (k % 2) * 4
		local p = c:part('Star', V3(1.2, 1.2, 1.2), CF(x, 30 + (k * 7) % 13, L.ZS + 30 + (k * 11) % 30) * ANG(0.6, 0.8, 0), WHITE, { mat = MAT.Neon, t = 1 })
		table.insert(job.nightParts, { p, C3(150, 150, 190), true })
	end
end
Props.Gold = function(job, c, L, th)
	local sp = spots(L)
	local gold = C3(255, 196, 50)
	for k, pos in { sp.A, sp.A + V3(1.8, 0, 1.6), sp.B } do
		local h = 1.2 + (k % 2) * 1.2
		c:post('CoinStack', 2.2, h, pos, gold, { mat = MAT.Foil })
		c:post('CoinTop', 2.3, 0.2, pos + V3(0, h, 0), gold:Lerp(WHITE, 0.3))
	end
	for k = 0, 1 do c:box('GoldBar', sp.B + V3(1.6, k * 0.8, -1.2 + k * 0.3), sp.B + V3(3.6, k * 0.8 + 0.8, -0.2 + k * 0.3), gold, { mat = MAT.Foil }) end
end
Props.Exclusive = function(job, c, L, th)
	local sp = spots(L)
	-- the VIP line: a red carpet to the pad between gold rope posts, crystals on the walks
	-- (the ropes stand wide of the carpet, |x| 7.5: the low close camera in front of the pad sees between them; the
	-- carpet and the posts step down the kerb onto the cross street)
	local red = C3(196, 30, 52)
	local function base(z) return z < L.ZC and -L.KERB or 0 end
	c:box('Carpet', V3(-3, 0, L.ZC), V3(3, 0.06, -L.R + 0.4), red)
	c:box('Carpet', V3(-3, -L.KERB, -L.R - 12), V3(3, 0.06 - L.KERB, L.ZC), red)
	for _, sx in { -1, 1 } do
		local x, z0, z1 = sx * 7.5, -L.R - 9, -L.R - 2
		c:post('RopePost', 0.5, 3 - base(z0), V3(x, base(z0), z0), C3(255, 200, 70), { mat = MAT.Foil })
		c:post('RopePost', 0.5, 3 - base(z1), V3(x, base(z1), z1), C3(255, 200, 70), { mat = MAT.Foil })
		c:box('Rope', V3(x - 0.12, 2.3, z0), V3(x + 0.12, 2.55, z1), C3(170, 20, 40))
	end
	crystal(c, sp.A, 1.1, th.Color, 0.4)
	crystal(c, sp.B, 1, th.Third, 1.7)
end
Props.Grail = function(job, c, L, th)
	-- two gold columns at the far street's mouth carrying purple banners
	local gold = C3(255, 206, 80)
	for _, sx in { -1, 1 } do
		local pos = V3(sx * (L.FAR - 1.4), L.WY, L.ZS + 1.5)
		c:box('ColumnBase', pos + V3(-1.3, 0, -1.3), pos + V3(1.3, 1, 1.3), gold:Lerp(WHITE, 0.2), { st = 'all' })
		c:post('Column', 1.8, 12, pos + V3(0, 1, 0), gold, { mat = MAT.Foil })
		c:box('ColumnCap', pos + V3(-1.3, 13, -1.3), pos + V3(1.3, 14, 1.3), gold:Lerp(WHITE, 0.2), { st = 'all' })
		c:box('Banner', pos + V3(-1.2, 5.5, -1.05), pos + V3(1.2, 12, -0.95), th.Color)
	end
end

function UnboxStage.dress(job, theme)
	if job.dressed then return job end
	job.dressed = true
	local th = theme or (job.P and job.P.theme) or {}
	local L = job.layout
	local c = newCtx(job, job.folder, job.O)
	local col = th.Color or C3(222, 56, 48)
	local shop = job.shop
	if shop then
		for k, p in shop.awning do p.Color = (k % 2 == 1) and col or (th.Third or WHITE) end
		shop.valance.Color = col
		shop.fascia.Color = col:Lerp(BLACK, 0.12)
		shop.frame.Color = col:Lerp(BLACK, 0.45)
	end
	UnboxStage.paint(job, th)
	if job.padRim then job.padRim.Color = th.Rim or col end
	if job.padMat then
		job.padMat.Color = col:Lerp(WHITE, 0.7)
		job.padBand.Color = col:Lerp(WHITE, 0.25)
		job.padInner.Color = col:Lerp(WHITE, 0.82)
	end
	stringLights(job, c, L, th)
	local fn = UnboxStage.Props[th.Id or ''] or UnboxStage.Props.Street
	if fn then fn(job, c, L, th) end
	return job
end

---------------------------------------------------------------------------------------------- build
function UnboxStage.build(job, kind)
	local P = job.P
	kind = kind or (P.premium and 'secret' or 'egg')
	local th = P.theme or {}
	job.setKind = kind
	job.setParts = 0
	job.nightParts = {}
	job.lamps, job.speakers = {}, {}
	local L = layout(P)
	job.layout = L
	local c = newCtx(job, job.folder, job.O)
	ground(job, c, L)
	pad(job, c, L)
	nearStreet(job, c, L)
	stepLine(job, c, L)
	posters(job, c, L)
	sign(job, c, L)
	UnboxStage.paint(job, HOOD)
	farStreet(job, c, L)
	anchors(job, c, L)
	marks(job, L)
	if kind == 'secret' then UnboxStage.dress(job, th) end
	return job
end

-- Lights the set for the dark beats, keeping one bright thing in the frame (REF28: the reference's dark beats have
-- exactly one): at a = 1 a few windows and the shop's glass glow warm at about half brightness, the theme's glows dim,
-- the plaza and the pad fall a little darker (FloorDim), the sign's words take the scene's light and its frame stops
-- glowing.
-- lights (0..1, default 0) is the string lights' own level (off in the deep-blue beat, at most 0.35 in the purple
-- one). a = 0 and lights = 0 put every part back as built. Writes only when a value changes.
function UnboxStage.night(job, a, lights)
	a = math.clamp(a or 0, 0, 1)
	lights = math.clamp(lights or 0, 0, 1)
	if job.nightA == a and job.nightL == lights then return end
	job.nightA, job.nightL = a, lights
	for _, e in job.nightParts or {} do
		local p = e[1]
		if not e.day then e.day = { p.Color, p.Material, p.Transparency } end
		local level = e.kind == 'bulb' and lights or a
		if level <= 0.001 then
			p.Color, p.Material, p.Transparency = e.day[1], e.day[2], e.day[3]
		elseif e.kind == 'dim' then
			p.Color = e.day[1]:Lerp(e.day[1]:Lerp(BLACK, e.amount or UnboxStage.FloorDim), level)
		else
			p.Material = MAT.Neon
			p.Color = e.day[1]:Lerp(BLACK, 0.55):Lerp(e[2], level)
			if e[3] then p.Transparency = 1 - level end
		end
	end
	if job.signGui then job.signGui.LightInfluence = a end
	-- the words (the posters' and the sign's) fall to about half their brightness, so none outshines the subject
	if not job.nightWords then
		job.nightWords = {}
		for _, l in job.posterLabels or {} do table.insert(job.nightWords, { l[1], l[1].TextColor3 }) end
		if job.signText then table.insert(job.nightWords, { job.signText, job.signText.TextColor3 }) end
	end
	for _, w in job.nightWords do w[1].TextColor3 = w[2]:Lerp(w[2]:Lerp(BLACK, 0.5), a) end
	for _, p in job.signNeon or {} do
		local m = a > 0.001 and MAT.SmoothPlastic or MAT.Neon
		if p.Material ~= m then p.Material = m end
	end
end

-- Once the camera is planned: each side's posters slide along their own wall (and up or down) so that, as the hero
-- frame sees it, the side's word sits beside the pair at mid-height, clear of the pair (pairU: its half-width in the
-- frame's -1..1 units) and inside the frame's outer lanes (|u| < 0.8, where the confetti flies); they stay on the wall.
-- A word its wall cannot bring whole into the frame goes whole out of it instead (never cut by the frame's edge).
function UnboxStage.framePosters(job, cf, fov, aspect, pairU)
	local wall = job.wallInfo
	if not job.posterGroups or not wall then return end
	local O = job.O
	local ty = math.tan(math.rad(fov / 2))
	local tx = ty * aspect
	local nW = O:VectorToWorldSpace(V3(0, 0, 1))
	local eye = cf.Position
	-- the shift (kept on the wall) that puts the group's word at the frame's u
	local function slide(g, wp, u)
		local dirW = cf:VectorToWorldSpace(V3(u * tx, 0.02 * ty, -1))
		local den = dirW:Dot(nW)
		if math.abs(den) < 1e-4 then return nil end
		local hit = eye + dirW * ((wp.CFrame.Position - eye):Dot(nW) / den)
		local d = O:VectorToObjectSpace(hit - wp.CFrame.Position)
		local x0, x1, y0, y1 = UnboxStage.extents(O, g.parts)
		-- (a group bigger than its wall on an axis stays put on that axis)
		local dx = (g.x1 - g.x0 >= x1 - x0) and math.clamp(d.X, g.x0 - x0, g.x1 - x1) or 0
		local dy = (g.y1 - g.y0 >= y1 - y0) and math.clamp(d.Y, g.y0 - y0, g.y1 - y1) or 0
		return O:VectorToWorldSpace(V3(dx, dy, 0))
	end
	-- the word's left and right edges in the frame's u after a shift
	local function span(wp, shift)
		local q = cf:PointToObjectSpace(wp.CFrame.Position + shift)
		local c, h = q.X / (-q.Z * tx), (wp.Size.X * 0.5) / (-q.Z * tx)
		return c - h, c + h
	end
	for _, g in job.posterGroups do
		local wp = g.word
		if not wp then continue end
		local q = cf:PointToObjectSpace(wp.CFrame.Position)
		if q.Z > -1 then continue end
		local side = q.X < 0 and -1 or 1
		local halfU = (wp.Size.X * 0.5) / (-q.Z * tx)
		local shift = slide(g, wp, side * math.clamp(pairU + halfU + 0.05, 0.42, math.max(0.42, 0.8 - halfU)))
		if not shift then continue end
		local a, b = span(wp, shift)
		if a < -1 or b > 1 then
			local out = slide(g, wp, side * (1.1 + halfU))
			if out then
				local a2, b2 = span(wp, out)
				if a2 > 1 or b2 < -1 then shift = out end
			end
		end
		for _, p in g.parts do p.CFrame += shift end
	end
end

-- A group of parts' extents in the frame O's X and Y (each part's rotated box).
function UnboxStage.extents(O, parts)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in parts do
		local _, _, _, r00, r01, r02, r10, r11, r12 = O:ToObjectSpace(p.CFrame):GetComponents()
		local c = O:PointToObjectSpace(p.CFrame.Position)
		local s = p.Size * 0.5
		local ex = math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z
		local ey = math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z
		x0, x1, y0, y1 = math.min(x0, c.X - ex), math.max(x1, c.X + ex), math.min(y0, c.Y - ey), math.max(y1, c.Y + ey)
	end
	return x0, x1, y0, y1
end

-- Where a falling bit stops: the riser, the pad (inside its radius), the roads (a kerb down), else the plaza.
function UnboxStage.floorAt(job)
	local L = job.layout or layout(job.P)
	return function(p)
		local q = job.O:PointToObjectSpace(p)
		local r = job.riser
		if r and math.abs(q.X) <= r.w / 2 and math.abs(q.Z - r.z) <= r.d / 2 then return job.deckY + r.h end
		if Vector2.new(q.X, q.Z).Magnitude <= job.P.padR then return job.padTop end
		-- (the roads lie a kerb below the plaza: the cross street in front of it, the far street's road behind it)
		if q.Z < L.ZC or (q.Z > L.ZS + 1 and math.abs(q.X) < L.FR) then return job.deckY - L.KERB end
		return job.deckY
	end
end

-- The set's parts and PointLights (the test and the budget).
function UnboxStage.count(job)
	local parts, lights = 0, 0
	if job.folder then
		for _, d in job.folder:GetDescendants() do
			if d:IsA('BasePart') then parts += 1 elseif d:IsA('PointLight') or d:IsA('SpotLight') or d:IsA('SurfaceLight') then lights += 1 end
		end
	end
	return parts, lights
end

return UnboxStage
