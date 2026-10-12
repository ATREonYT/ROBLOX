-- (brief 30) The reference's fight feedback, copied (bible 0.6, 2.4 "Hit reactions, shake, VFX", 2.6 "Animations"):
-- every hit pops a "+N" with the bicep by YOUR body (never a damage number over the enemy), a shot puts a white X on the
-- enemy for a few frames, a swing a white impact star and a white crescent swoosh round you, a punch that lands on you
-- a small white star on your chest, and a level-up a gold burst of light round you with white chevrons rising over your
-- head. All flat, camera-facing sprites drawn from frames (BillboardGuis sized in studs, every child laid out in Scale,
-- so they read the same at any distance and the offline previews draw them), white with a thin dark edge, like the
-- reference's. Client only (Waves.client, HoodClient/LevelBurst); nothing is sent.
--   FightFX.gain(at, amount, opts)   "+N" and the bicep at `at` (world); rises ~2 studs in 0.6 s and fades (opts.melee:
--                                    a touch bigger, the reference's +9 next to +6)
--   FightFX.hitX(at)                 the white X hit-marker, 0.12 s (3-4 frames)
--   FightFX.star(at, size, life)     the white 4-point impact star (default 2.2 studs, 0.1 s)
--   FightFX.swoosh(cf, n)            the white crescent round a body at cf (its LookVector forward), about 1.5 body widths
--                                    across, 0.15 s; n odd sweeps right to left, n even left to right
--   FightFX.levelBurst(root)         the level-up burst round a character's root part (0.8 s, peak at 0.3-0.5 s)
--   FightFX.slash(cf, color)         the reference Pouncer's hit (V4 15.0-15.3 s): a bright spiral slash wrapping a body
--                                    at cf, about 2 body widths, three turns of curved beams, gone in 0.15 s (a leap
--                                    that lands on you)
--   FightFX.dust(at, scale)          a small brown dust puff (a body landing in its heap)
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Fonts = require(script.Parent.Fonts)

local FightFX = {}
FightFX.Parent = nil -- (Waves.client sets its HoodGoons folder; else Workspace)
FightFX.White = Color3.new(1, 1, 1)
FightFX.Ink = Color3.fromRGB(26, 22, 36) -- (the thin dark edge round the white marks)
FightFX.Gold = Color3.fromRGB(255, 206, 64)
FightFX.GoldLight = Color3.fromRGB(255, 244, 176)
FightFX.MaxGains = 5 -- "+N" pops alive at once (a fast trigger reuses the oldest)

local okKit, Kit = pcall(require, script.Parent.UIKit)
local function muscleImage()
	if okKit and Kit and Kit.iconImage then
		local ok, id = pcall(Kit.iconImage, 'Muscle')
		if ok and type(id) == 'string' then return id end
	end
	return ''
end

-- (Debris where there is one; a plain delay where there isn't: the offline checks)
local function expire(inst, seconds)
	if not pcall(function() Debris:AddItem(inst, seconds) end) then
		task.delay(seconds, function() if inst.Parent then inst:Destroy() end end)
	end
end
local function tween(obj, t, props, style, dir, delay)
	local ok, tw = pcall(TweenService.Create, TweenService, obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	if ok and tw then tw:Play() end
	return tw
end

-- An invisible anchor at `at` with a camera-facing board `w` x `h` studs on it; gone after `life` seconds.
local function board(name, at, w, h, life, onTop)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p.Parent = FightFX.Parent or workspace
	local g = Instance.new('BillboardGui')
	g.Name = name
	g.Size = UDim2.fromScale(w, h)
	g.LightInfluence = 0
	g.AlwaysOnTop = onTop ~= false
	g.MaxDistance = 140
	g.ClipsDescendants = false
	g.Parent = p
	if life then expire(p, life) end
	return g, p
end
FightFX.board = board

-- A flat bar centred at (x, y) (fractions of its parent), w x h (fractions), turned `rot` degrees, with an optional dark
-- edge (px) and corner (0..0.5 of its short side).
local function bar(parent, name, x, y, w, h, rot, color, edge, corner, z)
	local f = Instance.new('Frame')
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color or FightFX.White
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	if corner and corner > 0 then
		local c = Instance.new('UICorner')
		c.CornerRadius = UDim.new(corner, 0)
		c.Parent = f
	end
	if edge and edge > 0 then
		local s = Instance.new('UIStroke')
		s.Color = FightFX.Ink
		s.Thickness = edge
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
	end
	f.Parent = parent
	return f
end
FightFX.bar = bar
-- A tapered ray: a bar whose ends fade out (UIGradient transparency), brightest in the middle.
local function ray(parent, name, x, y, w, h, rot, color, z, core)
	local f = bar(parent, name, x, y, w, h, rot, color, nil, 0.5, z)
	local g = Instance.new('UIGradient')
	g.Rotation = 90 -- (along the bar's length: its Y)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5 - (core or 0.12), 0.15), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.5 + (core or 0.12), 0.15), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end
FightFX.ray = ray
local function holder(parent, scale)
	local h = Instance.new('Frame')
	h.Name = 'Holder'
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.5)
	h.Size = UDim2.fromScale(1, 1)
	h.Parent = parent
	local s = Instance.new('UIScale')
	s.Scale = scale or 1
	s.Parent = h
	return h, s
end
-- Every frame / label / image under `root` faded to `t` (a group fade without CanvasGroups, which billboards lack).
local function fadeAll(root, t, time, delay)
	for _, d in root:GetDescendants() do
		if d:IsA('Frame') then tween(d, time, { BackgroundTransparency = 1 - (1 - d.BackgroundTransparency) * (1 - t) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
		elseif d:IsA('TextLabel') then tween(d, time, { TextTransparency = t }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
		elseif d:IsA('ImageLabel') then tween(d, time, { ImageTransparency = t }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
		elseif d:IsA('UIStroke') then tween(d, time, { Transparency = t }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
		end
	end
end
FightFX.fadeAll = fadeAll

---------------------------------------------------------------------------------------------- "+N" by you
-- The reference's "+6": white heavy digits with a dark outline, the orange bicep right after them, by the player's
-- body at chest height (W 31.4-33.7 s, V4 15.25 s); it pops in, rises about 4 % of the screen over 0.6 s and fades.
local gains = {}
function FightFX.gain(at, amount, opts)
	opts = opts or {}
	if type(amount) ~= 'number' or amount <= 0 then return end
	while #gains >= FightFX.MaxGains do
		local old = table.remove(gains, 1)
		if old and old.Parent then old:Destroy() end
	end
	local k = opts.melee and 1.12 or 1
	local g, p = board('GainFX', at, 2.3 * k, 0.86 * k, 0.75, true)
	table.insert(gains, p)
	local h, scale = holder(g, 0.45)
	local text = '+' .. (opts.text or (function()
		local ok, Format = pcall(require, script.Parent.Format)
		return ok and Format.compact(amount) or tostring(math.floor(amount))
	end)())
	-- (the digits right-aligned up to the bicep: "+6" then the arm, like the reference)
	local n = #text
	local textW = math.clamp(0.2 * n + 0.08, 0.35, 0.72)
	local t = Instance.new('TextLabel')
	t.Name = 'Amount'
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(1, 0.5)
	t.Position = UDim2.fromScale(0.62, 0.5)
	t.Size = UDim2.fromScale(textW, 0.92)
	t.Text = text
	t.TextScaled = true
	t.FontFace = Fonts.Title -- (the world's text: Montserrat Black, as the reference's)
	t.TextColor3 = FightFX.White
	t.TextXAlignment = Enum.TextXAlignment.Right
	t.ZIndex = 3
	local st = Instance.new('UIStroke')
	st.Color = FightFX.Ink
	st.Thickness = 2.5
	st.Parent = t
	t.Parent = h
	local img = Instance.new('ImageLabel')
	img.Name = 'Bicep'
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.Position = UDim2.fromScale(0.63, 0.52)
	img.Size = UDim2.fromScale(0.33, 0.9)
	img.Image = muscleImage()
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 3
	img:SetAttribute('PreviewImage', 'Muscle')
	img.Parent = h
	-- pop 0.45 -> 1.1 -> 1 (0.14 s), rise 1 stud over 0.6 s (about 4 % of the screen from the play camera, r3: matched to
	-- W 9.3-12.3 s and 31.4-32.5 s), fade out from 0.42 s
	tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	g.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	tween(g, 0.6, { StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 0.3, 1.0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	fadeAll(h, 1, 0.2, 0.42)
	return g
end

---------------------------------------------------------------------------------------------- the X and the star
-- The white X hit-marker on the enemy per shot (W 31.6-32.2 s: a small crisp white "x" on the guard, 3 frames).
function FightFX.hitX(at)
	local g = board('HitX', at, 1.05, 1.05, 0.16, true)
	local h, scale = holder(g, 1.35)
	local turn = (math.random() - 0.5) * 16
	for _, r in { 45, -45 } do bar(h, 'XBar', 0.5, 0.5, 0.17, 0.92, r + turn, FightFX.White, 1.5, 0.5, 3) end
	tween(scale, 0.06, { Scale = 1 })
	fadeAll(h, 1, 0.05, 0.09)
	return g
end
-- The white 4-point impact star (W 38.5 s, W 39.2 s: a melee hit's burst on the enemy, 2-3 frames): two long tapered
-- rays crossed, two short diagonal ones, a bright core.
function FightFX.star(at, size, life)
	size = size or 2.2
	life = life or 0.1
	local g = board('HitStar', at, size, size, life + 0.06, true)
	local h, scale = holder(g, 0.6)
	local turn = (math.random() - 0.5) * 30
	ray(h, 'StarRay', 0.5, 0.5, 0.15, 1.0, turn, FightFX.White, 3, 0.1)
	ray(h, 'StarRay', 0.5, 0.5, 0.15, 1.0, turn + 90, FightFX.White, 3, 0.1)
	ray(h, 'StarRay', 0.5, 0.5, 0.09, 0.56, turn + 45, FightFX.White, 2, 0.12)
	ray(h, 'StarRay', 0.5, 0.5, 0.09, 0.56, turn - 45, FightFX.White, 2, 0.12)
	bar(h, 'StarCore', 0.5, 0.5, 0.22, 0.22, 0, FightFX.White, nil, 0.5, 4)
	tween(scale, 0.05, { Scale = 1.08 })
	fadeAll(h, 1, 0.05, life - 0.03)
	return g
end

---------------------------------------------------------------------------------------------- the swoosh
-- The white crescent of a swing (W 41.7 s: thick white arcs sweeping round the player's front, ~1.5 body widths): three
-- curved beams, the inner one thick and solid, two thin trailing ones, gone in 0.15 s.
function FightFX.swoosh(cf, n)
	local side = ((n or 1) % 2 == 1) and 1 or -1
	local p = Instance.new('Part')
	p.Name = 'Swoosh'
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = FightFX.Parent or workspace
	expire(p, 0.2)
	local beams = {}
	for k, spec in { { 1.0, 1.1, 0 }, { 1.35, 0.35, 0.18 }, { 0.72, 0.28, 0.3 } } do
		local r, width, fade = spec[1], spec[2], spec[3]
		local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
		-- from behind its shoulder on one side round the front to the other, at chest height, a little rising
		a0.Position = Vector3.new(side * 1.9 * r, 0.9 - k * 0.15, 0.6)
		a1.Position = Vector3.new(-side * 1.9 * r, 0.1 - k * 0.1, 0.4)
		a0.Parent, a1.Parent = p, p
		local b = Instance.new('Beam')
		b.Name = 'SwooshArc'
		b.Attachment0, b.Attachment1 = a0, a1
		-- the curve bows forward (the body's front, -Z)
		b.CurveSize0, b.CurveSize1 = 3.1 * r, -3.1 * r
		b.Width0, b.Width1 = width * 0.25, width
		b.Segments = 20
		b.FaceCamera = true
		b.LightEmission, b.LightInfluence = 1, 0
		b.Color = ColorSequence.new(FightFX.White)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.35, fade), NumberSequenceKeypoint.new(0.85, fade + 0.1), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = p
		table.insert(beams, b)
	end
	-- (a Beam's curve leaves Attachment0 along its Axis (+X) and comes into Attachment1 against its Axis: both axes turned
	-- to the body's front (-Z), CurveSize0 > 0 and CurveSize1 < 0 bow the arc forward)
	for _, b in beams do
		b.Attachment0.CFrame = CFrame.new(b.Attachment0.Position) * CFrame.Angles(0, math.pi / 2, 0)
		b.Attachment1.CFrame = CFrame.new(b.Attachment1.Position) * CFrame.Angles(0, math.pi / 2, 0)
	end
	task.delay(0.1, function()
		for _, b in beams do
			if b.Parent then b.Transparency = NumberSequence.new(0.75) end
		end
	end)
	return p
end

---------------------------------------------------------------------------------------------- the spiral slash
FightFX.SlashColor = Color3.fromRGB(150, 255, 70) -- (the reference's toxic green)
function FightFX.slash(cf, color)
	local p = Instance.new('Part')
	p.Name = 'Slash'
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = FightFX.Parent or workspace
	expire(p, 0.2)
	local beams = {}
	-- three arcs climbing round the body, each a half turn: front-left low to back-right, back-right to front-left
	-- higher, and a last one over the shoulders (a spiral read in 2-3 frames)
	for k = 0, 2 do
		local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
		local side = k % 2 == 0 and 1 or -1
		local r = 1.9 - k * 0.15
		a0.CFrame = CFrame.new(side * r, -1.4 + k * 1.3, -0.3) * CFrame.Angles(0, math.pi / 2, 0)
		a1.CFrame = CFrame.new(-side * r, -0.8 + k * 1.3, 0.3) * CFrame.Angles(0, math.pi / 2, 0)
		a0.Parent, a1.Parent = p, p
		local b = Instance.new('Beam')
		b.Name = 'SlashArc'
		b.Attachment0, b.Attachment1 = a0, a1
		b.CurveSize0, b.CurveSize1 = side * -3.2, side * 3.2 -- (bows round the back on one turn, the front on the next)
		b.Width0, b.Width1 = 0.25, 0.95 - k * 0.15
		b.Segments = 20
		b.FaceCamera = true
		b.LightEmission, b.LightInfluence = 1, 0
		b.Color = ColorSequence.new(Color3.new(1, 1, 1), color or FightFX.SlashColor)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = p
		table.insert(beams, b)
	end
	task.delay(0.1, function()
		for _, b in beams do if b.Parent then b.Transparency = NumberSequence.new(0.7) end end
	end)
	return p
end

---------------------------------------------------------------------------------------------- the level-up burst
-- W 32.0-32.8 s (ref_W32.4_levelup_burst): a gold-white burst round the player, radiating gold rays, a bright core, and a
-- column of white chevrons (^) rising over the head; about 0.8 s, brightest at 0.3-0.5 s. It sits on the character's
-- root and follows it.
function FightFX.levelBurst(root, opts)
	opts = opts or {}
	if not root or not root.Parent then return end
	-- (brief 30, r3: matched frame by frame to W 32.05-32.9 s) first a white-gold light column straight up through you;
	-- then a white-hot glow round your body and long gold rays out to about one and a half body heights (the burst is
	-- about three of you across at its peak, 0.3-0.5 s); big gold chevrons rise over your head one after another; all of
	-- it gone by 0.85 s. The body stays visible through it (no solid disc).
	local beam, bp = board('LevelBeam', root.CFrame.Position, 2.2, 15, 0.7, true)
	beam.Adornee = root
	beam.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	bp.CFrame = root.CFrame
	local bh, bscale = holder(beam, 0.5)
	local glowCol = ray(bh, 'BeamGlow', 0.5, 0.5, 0.9, 1.0, 0, FightFX.GoldLight, 2, 0.3)
	glowCol.BackgroundTransparency = 0.35
	local coreCol = ray(bh, 'BeamCore', 0.5, 0.5, 0.36, 1.0, 0, FightFX.White, 3, 0.35)
	coreCol.BackgroundTransparency = 0
	tween(bscale, 0.1, { Scale = 1 })
	fadeAll(bh, 1, 0.3, 0.25)
	local g, p = board('LevelBurst', root.CFrame.Position, 17, 17, 1.0, true)
	g.Adornee = root
	g.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
	p.CFrame = root.CFrame
	local h, scale = holder(g, 0.3)
	for k, spec in { { 0.5, 0.86 }, { 0.36, 0.78 }, { 0.24, 0.6 } } do
		local glow = bar(h, 'BurstGlow', 0.5, 0.5, spec[1], spec[1], 0, k == 3 and FightFX.GoldLight or FightFX.Gold, nil, 0.5, 1)
		glow.BackgroundTransparency = spec[2]
	end
	local ring = bar(h, 'BurstRing', 0.5, 0.5, 0.3, 0.3, 0, FightFX.Gold, nil, 0.5, 2)
	ring.BackgroundTransparency = 1
	local rs = Instance.new('UIStroke')
	rs.Color, rs.Thickness, rs.Transparency = FightFX.Gold, 4, 0.3
	rs.Parent = ring
	local core = bar(h, 'BurstCore', 0.5, 0.5, 0.17, 0.17, 0, FightFX.White, nil, 0.5, 4)
	core.BackgroundTransparency = 0.05
	for k = 0, 7 do
		local long = k % 2 == 0
		local rr = ray(h, 'BurstRay', 0.5, 0.5, long and 0.034 or 0.024, long and 1.0 or 0.62, k * 22.5 + 6, k % 3 == 0 and FightFX.White or FightFX.GoldLight, 3, 0.07)
		rr.BackgroundTransparency = 0
	end
	local shaft = ray(h, 'BurstShaft', 0.5, 0.3, 0.05, 0.6, 0, FightFX.White, 3, 0.2)
	shaft.BackgroundTransparency = 0.15
	for _, sp in { { 0.36, 0.38 }, { 0.64, 0.4 }, { 0.33, 0.62 }, { 0.66, 0.64 }, { 0.5, 0.3 }, { 0.44, 0.56 } } do
		bar(h, 'Sparkle', sp[1], sp[2], 0.016, 0.016, 45, FightFX.White, nil, nil, 5)
	end
	tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, nil, 0.06)
	tween(ring, 0.45, { Size = UDim2.fromScale(0.5, 0.5) }, nil, nil, 0.06)
	fadeAll(h, 1, 0.32, 0.5)
	-- the chevrons: three big gold "^" (about one and a half body widths) rising over the head one after another
	local cg, cp = board('LevelChevrons', root.CFrame.Position, 6, 12, 1.0, true)
	cg.Adornee = root
	cg.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	cp.CFrame = root.CFrame
	for k = 1, 3 do
		local c = Instance.new('Frame')
		c.Name = 'Chevron'
		c.BackgroundTransparency = 1
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Size = UDim2.fromScale(0.95, 0.16)
		c.Position = UDim2.fromScale(0.5, 0.82)
		c.Parent = cg
		-- two thick bars meeting at the top: a "^", gold with a white-hot edge
		bar(c, 'ChevronArm', 0.29, 0.5, 0.6, 0.36, -36, FightFX.GoldLight, 3, 0.3, 3)
		bar(c, 'ChevronArm', 0.71, 0.5, 0.6, 0.36, 36, FightFX.GoldLight, 3, 0.3, 3)
		for _, d in c:GetChildren() do
			local st = d:FindFirstChildOfClass('UIStroke')
			if st then st.Color = FightFX.White end
			d.BackgroundTransparency = 1
		end
		local delay = 0.08 + (k - 1) * 0.12
		for _, d in c:GetChildren() do
			tween(d, 0.08, { BackgroundTransparency = 0.05 }, nil, nil, delay)
			local st = d:FindFirstChildOfClass('UIStroke')
			if st then st.Transparency = 1; tween(st, 0.08, { Transparency = 0.1 }, nil, nil, delay) end
		end
		tween(c, 0.55, { Position = UDim2.fromScale(0.5, 0.18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
		fadeAll(c, 1, 0.22, delay + 0.36)
	end
	return g, cg
end

---------------------------------------------------------------------------------------------- dust
-- A small brown dust puff (the reference's "brown dust puff" round a heap): soft balls swelling and fading.
function FightFX.dust(at, scale, count)
	scale = scale or 1
	local brown = Color3.fromRGB(176, 146, 112)
	for k = 1, count or 5 do
		local a = k / (count or 5) * math.pi * 2 + math.random() * 0.5
		local off = Vector3.new(math.cos(a), 0.15, math.sin(a)) * scale
		local p = Instance.new('Part')
		p.Name = 'Dust'
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Color = brown:Lerp(Color3.fromRGB(226, 210, 186), math.random() * 0.5)
		p.Transparency = 0.25
		p.Size = Vector3.one * 0.8 * scale
		p.CFrame = CFrame.new(at + off * 0.4)
		p.Parent = FightFX.Parent or workspace
		tween(p, 0.45, { Size = Vector3.one * 2.1 * scale, CFrame = CFrame.new(at + off * 1.3 + Vector3.new(0, 0.5 * scale, 0)), Transparency = 1 })
		expire(p, 0.5)
	end
end

return FightFX
