-- Game feel for hits and rewards, client-side only (the server just validates and awards Power): punches and
-- bursts, and (Shoot.client) shots: muzzle flash, tracer, shell casing, target knock-back (section "shooting").
-- Recipe from the animation research (research_notes/.../animation_and_vfx.md, "impact frame"):
--   hit-stop 40-60 ms (90-120 ms for big hits) -> bag squashes and swings on an underdamped spring
--   -> spark burst + ring -> white flash -> small camera bump -> "+Power" number pops up and drifts away.
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')

local Juice = {}

---------------------------------------------------------------------------------------------- springs
-- Semi-implicit spring step. f = frequency (Hz), z = damping ratio (1 = no overshoot, <1 = swings).
-- Works for numbers and Vector3s. Substeps keep it stable when a frame hitches.
function Juice.springStep(x, v, target, f, z, dt)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	local w = 2 * math.pi * f
	for _ = 1, steps do
		v += (w * w * (target - x) - 2 * z * w * v) * h
		x += v * h
	end
	return x, v
end
Juice.Spring = { uiPop = { 4, 0.5 }, petFollow = { 2, 1 }, bagWobble = { 2.5, 0.3 }, squash = { 5, 0.4 } }

-- 1 - exp(-speed * dt): frame-rate independent smoothing for Lerp (speed ~10 snappy, ~4 floaty).
function Juice.alpha(speed, dt) return 1 - math.exp(-speed * dt) end

---------------------------------------------------------------------------------------------- bag sway
-- Swings a hanging bag from its hook. `parts` move rigidly with the swing; `hook` is the world CFrame of
-- the pivot (top of the chain). Call :hit(direction, strength) on every punch. Sleeps when settled.
function Juice.sway(parts, hook)
	local offsets = {}
	for _, p in parts do offsets[p] = hook:ToObjectSpace(p.CFrame) end
	local tilt, vel = Vector3.zero, Vector3.zero -- x/z tilt in radians, angular velocity
	local conn
	local self = {}
	local function apply()
		local swing = hook * CFrame.Angles(tilt.X, 0, tilt.Z)
		for p, off in offsets do p.CFrame = swing * off end
	end
	local function step(dt)
		tilt, vel = Juice.springStep(tilt, vel, Vector3.zero, Juice.Spring.bagWobble[1], Juice.Spring.bagWobble[2], dt)
		apply()
		if tilt.Magnitude < 1e-3 and vel.Magnitude < 1e-3 then
			tilt, vel = Vector3.zero, Vector3.zero
			apply()
			conn:Disconnect()
			conn = nil
		end
	end
	-- 4 rad/s per unit of strength gives a ~9 degree swing that rings out in about a second.
	function self:hit(direction, strength)
		local d = hook:VectorToObjectSpace(direction) * Vector3.new(1, 0, 1)
		if d.Magnitude < 1e-3 then return end
		d = d.Unit
		vel += Vector3.new(d.Z, 0, -d.X) * (strength or 1) * 4 -- pushing along +X tips the bag about Z
		if not conn then conn = RunService.PreRender:Connect(step) end
	end
	function self:destroy() if conn then conn:Disconnect() end end
	return self
end

---------------------------------------------------------------------------------------------- hit-stop
-- Freeze animation tracks for a beat at the moment of impact, then resume.
function Juice.hitStop(tracks, duration)
	local saved = {}
	for i, track in tracks do
		saved[i] = track.Speed
		track:AdjustSpeed(0)
	end
	task.delay(duration or 0.05, function()
		for i, track in tracks do
			if track.IsPlaying then track:AdjustSpeed(saved[i]) end
		end
	end)
end

---------------------------------------------------------------------------------------------- camera shake
-- Spring-driven camera bump: kick() pushes the offset; it rings out on its own. One shared controller.
local shake = { x = Vector3.zero, v = Vector3.zero, bound = false }
function Juice.kick(amount)
	local a = amount or 0.4
	-- Units are degrees of camera tilt: a 0.4 kick peaks near 0.6 degrees, a big 0.9 kick near 1.3.
	shake.v += Vector3.new((math.random() - 0.5) * 2, math.random() * 0.6 + 0.4, 0) * a * 120
	if not shake.bound then
		shake.bound = true
		RunService:BindToRenderStep('HoodCameraKick', Enum.RenderPriority.Camera.Value + 1, function(dt)
			shake.x, shake.v = Juice.springStep(shake.x, shake.v, Vector3.zero, 7, 0.35, dt)
			local cam = workspace.CurrentCamera
			cam.CFrame *= CFrame.new(shake.x.X * 0.12, shake.x.Y * 0.12, 0) * CFrame.Angles(math.rad(shake.x.Y * 1.5), 0, math.rad(shake.x.X * 1.2))
			if shake.x.Magnitude < 1e-3 and shake.v.Magnitude < 1e-3 then
				RunService:UnbindFromRenderStep('HoodCameraKick')
				shake.bound = false
			end
		end)
	end
end

---------------------------------------------------------------------------------------------- impact burst
-- Sparks + an expanding ring at a world position. A small pool of hidden anchor parts is reused round-robin
-- (a fast puncher hits 5-8 times a second; making and destroying parts and emitters per hit adds up).
-- Particles are in world space, so moving an anchor never drags the previous burst along.
local function backOut(t) -- Back easing (overshoot), 0..1
	local c = 1.70158
	t -= 1
	return 1 + (c + 1) * t * t * t + c * t * t
end
local function anchorAt(position)
	local p = Instance.new('Part')
	p.Name = 'ImpactFX'
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	return p
end
local pool, nextSlot = {}, 1
local POOL_SIZE = 6
local function burstSlot()
	local slot = pool[nextSlot]
	if not slot or not slot.part.Parent then
		local p = anchorAt(Vector3.zero)
		local sparks = Instance.new('ParticleEmitter')
		sparks.Name = 'Sparks'
		sparks.Enabled = false
		sparks.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Lifetime = NumberRange.new(0.2, 0.45)
		sparks.Speed = NumberRange.new(18, 32)
		sparks.Drag = 10 -- fast out, then hang: the official burst recipe
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Squash = NumberSequence.new(1.2) -- stretched streaks
		sparks.Parent = p
		local ring = Instance.new('ParticleEmitter')
		ring.Name = 'Ring'
		ring.Enabled = false
		ring.Texture = 'rbxasset://textures/particles/explosion01_shockwave_main.dds'
		ring.LightEmission = 1
		ring.LightInfluence = 0
		ring.Lifetime = NumberRange.new(0.25)
		ring.Speed = NumberRange.new(0)
		ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		ring.Parent = p
		slot = { part = p, sparks = sparks, ring = ring }
		pool[nextSlot] = slot
	end
	nextSlot = nextSlot % POOL_SIZE + 1
	return slot
end
function Juice.burst(position, color, power)
	power = power or 1
	local slot = burstSlot()
	slot.part.CFrame = CFrame.new(position)
	slot.sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.fromRGB(255, 194, 26))
	slot.sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * power), NumberSequenceKeypoint.new(1, 0) })
	slot.sparks:Emit(math.floor(10 * power))
	slot.ring.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.new(1, 1, 1))
	slot.ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 6 * power) })
	slot.ring:Emit(1)
end

-- White flash over a model for one beat. One Highlight per model, made on first use and switched off
-- between hits: only enabled Highlights count toward the 255 limit, and nothing is created per punch.
local flashes = setmetatable({}, { __mode = 'k' })
function Juice.flash(model)
	local f = flashes[model]
	if not f or not f.h.Parent then
		local h = Instance.new('Highlight')
		h.Name = 'HitFlash'
		h.FillColor = Color3.new(1, 1, 1)
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Adornee = model
		h.Parent = model
		f = { h = h }
		flashes[model] = f
	end
	if f.tween then f.tween:Cancel() end
	f.h.FillTransparency = 0.3
	f.h.Enabled = true
	f.tween = TweenService:Create(f.h, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 })
	f.tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then f.h.Enabled = false end
	end)
	f.tween:Play()
end

-- "+123" floating up from a world point: overshoot pop, drift up, fade.
-- opts (optional): fill (text colour, default `color`), stroke (outline colour), thickness, size (Vector2 studs).
function Juice.popNumber(position, text, color, fontFace, opts)
	opts = opts or {}
	local p = anchorAt(position)
	Debris:AddItem(p, 1)
	local g = Instance.new('BillboardGui')
	g.Size = opts.size and UDim2.fromScale(opts.size.X, opts.size.Y) or UDim2.fromScale(4, 1.6)
	g.LightInfluence = 0
	g.AlwaysOnTop = true
	g.MaxDistance = 80
	g.Parent = p
	local scale = Instance.new('UIScale')
	scale.Scale = 0.4
	local t = Instance.new('TextLabel')
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true -- BillboardGuis are the one place TextScaled is recommended
	t.FontFace = fontFace or Font.new('rbxasset://fonts/families/LuckiestGuy.json')
	t.TextColor3 = opts.fill or color or Color3.fromRGB(255, 194, 26)
	local s = Instance.new('UIStroke')
	s.Color = opts.stroke or Color3.fromRGB(28, 24, 48)
	s.Thickness = opts.thickness or 2.5
	s.Parent = t
	scale.Parent = t
	t.Parent = g
	local drift = (math.random() - 0.5) * 1.5
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(g, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(drift, 3, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { Transparency = 1 }):Play()
end

-- One running "+N" per lane under a held trigger (the simulator norm), instead of a number per shot piling up
-- over the target. Juice.combo(key, at, gain, opts): `key` is the lane (one combo each), `at` a world point above
-- and beside the main target (Juice.comboAt), `gain` this hit's Power. The first hit pops a clean "+N"; each
-- further hit within 0.8 s punches it (scale 1.25 -> 1), rolls the total up to the new sum and shows the hit
-- count under it ("+2,112" over "6 HITS"); 0.5 s after the last hit it fades out over 0.3 s and the next shot
-- starts a new one. opts: color (the lane's colour: the count and, darkened, the outline), fill (default white),
-- big (top lanes: a bigger number), format (number -> text; default thousands separators).
local combos, comboConn = {}, nil
local COMBO_HOLD, COMBO_FADE = 0.5, 0.3
local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
	return (out:gsub('^,', ''))
end
local function comboStep(dt)
	for key, c in combos do
		c.age += dt
		c.rollT += dt
		c.popT += dt
		-- The total rolls up to the new sum in 0.12 s.
		local f = math.min(1, c.rollT / 0.12)
		local shown = c.from + (c.total - c.from) * f
		local text = '+' .. c.format(shown)
		if c.number.Text ~= text then c.number.Text = text end
		-- The first hit pops in (0.4 -> 1 with an overshoot); later hits punch it (1.25 -> 1).
		if c.count == 1 then
			c.scale.Scale = 0.4 + 0.6 * backOut(math.min(1, c.popT / 0.15))
		else
			c.scale.Scale = 1 + 0.25 * (1 - math.min(1, c.popT / 0.12))
		end
		local fade = math.clamp((c.age - COMBO_HOLD) / COMBO_FADE, 0, 1)
		c.number.TextTransparency, c.numberStroke.Transparency = fade, fade
		c.hits.TextTransparency, c.hitsStroke.Transparency = fade, fade
		if fade >= 1 then
			c.gui.Enabled = false
			c.alive = false
			combos[key] = nil
			c.parked = true
		end
	end
	if next(combos) == nil and comboConn then
		comboConn:Disconnect()
		comboConn = nil
	end
end
local comboRigs = setmetatable({}, { __mode = 'k' })
function Juice.combo(key, at, gain, opts)
	opts = opts or {}
	local color = opts.color or Color3.fromRGB(255, 194, 26)
	local c = combos[key]
	if not c then
		-- A rig per lane, made once and reused (parked while no combo runs).
		c = comboRigs[key]
		if not c or not c.part.Parent then
			local part = anchorAt(at)
			part.Name = 'ComboFX'
			local g = Instance.new('BillboardGui')
			g.Name = 'Combo'
			g.LightInfluence = 0
			g.AlwaysOnTop = true
			g.MaxDistance = 80
			g.Parent = part
			local holder = Instance.new('Frame')
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.Parent = g
			local scale = Instance.new('UIScale')
			scale.Parent = holder
			local function label(name, y, h)
				local t = Instance.new('TextLabel')
				t.Name = name
				t.BackgroundTransparency = 1
				t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
				t.TextScaled = true
				t.FontFace = opts.fontFace or Font.new('rbxasset://fonts/families/LuckiestGuy.json')
				local st = Instance.new('UIStroke')
				st.Parent = t
				t.Parent = holder
				return t, st
			end
			c = { part = part, gui = g, scale = scale }
			c.number, c.numberStroke = label('Number', 0, 0.64)
			c.hits, c.hitsStroke = label('Hits', 0.62, 0.38)
			comboRigs[key] = c
		end
		local size = opts.big and Vector2.new(5, 2.9) or Vector2.new(4.2, 2.4)
		c.gui.Size = UDim2.fromScale(size.X, size.Y)
		c.part.CFrame = CFrame.new(at)
		c.number.TextColor3 = opts.fill or Color3.new(1, 1, 1)
		c.numberStroke.Color = opts.stroke or color:Lerp(Color3.new(0, 0, 0), 0.65)
		c.numberStroke.Thickness = opts.thickness or 3
		c.hits.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
		c.hitsStroke.Color = Color3.fromRGB(20, 18, 32)
		c.hitsStroke.Thickness = 2
		c.format = opts.format or commas
		c.total, c.from, c.count = 0, 0, 0
		c.alive, c.parked = true, false
		c.gui.Enabled = true
		combos[key] = c
	end
	c.from = c.from + (c.total - c.from) * math.min(1, (c.rollT or 1) / 0.12) -- (where the roll had got to)
	c.total += gain
	c.count += 1
	c.age, c.rollT, c.popT = 0, c.count == 1 and 1 or 0, 0
	if c.count == 1 then c.from = c.total end
	c.hits.Text = c.count > 1 and (c.count .. ' HITS') or ''
	c.hits.Visible = c.count > 1
	c.number.Text = '+' .. c.format(c.from)
	if not comboConn then comboConn = RunService.PreRender:Connect(comboStep) end
	comboStep(0)
	return c
end
-- Where a lane's combo sits: over the main target's top edge and to the shooter's right of it (the lane faces
-- `lane`'s +Z; its right on screen is the lane's -X), so it never covers the target or its knock-back.
function Juice.comboAt(target, lane)
	local top, aim = -math.huge, target:GetAttribute('Aim')
	for _, p in target:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				top = math.max(top, (p.CFrame * CFrame.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)).Position.Y)
			end end end
		end
	end
	if typeof(aim) ~= 'Vector3' then aim = target:GetPivot().Position end
	if top == -math.huge then top = aim.Y + 1 end
	local zone = lane and lane:FindFirstChild('TrainingZone', true)
	local right = zone and -zone.CFrame.RightVector or Vector3.new(1, 0, 0)
	return Vector3.new(aim.X, top + 1.8, aim.Z) + right * 1.8
end

-- Everything for one punch landing on a bag. `bag` = { sway = Juice.sway(...), model = Model, point = Vector3,
-- tier = station tier (1-9, optional), color = rarity colour (optional) }. Better bags hit a little harder:
-- sparks take the bag's rarity colour and grow about 6% per tier, so the gold bag's hits feel heavier too.
function Juice.punch(bag, fromPosition, gained, big)
	local dir = (bag.point - fromPosition) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) end
	local power = (big and 1.6 or 1) * (1 + ((bag.tier or 1) - 1) * 0.06)
	bag.sway:hit(dir.Unit, big and 1.6 or 1)
	Juice.burst(bag.point, bag.color, power)
	Juice.flash(bag.model)
	Juice.kick(big and 0.9 or 0.35)
	if gained then Juice.popNumber(bag.point + Vector3.new(0, 1.5, 0), '+' .. gained) end
end


---------------------------------------------------------------------------------------------- shooting
-- Everything a shot shows, all client-side and pooled (a fast shooter fires ~7 times a second):
--   Juice.gunRig(tool)            muzzle flash emitters + a flash light on the tool's Muzzle attachment, made once
--   Juice.muzzle(rig, color, power) the flash: a hot core, a star, a few forward sparks, a 50 ms light
--   Juice.tracer(from, to, color, width)  a neon streak (white core in a coloured glow) that fades in ~0.1 s
--   Juice.casing(cframe, color)   a brass shell flipping out of the Eject attachment, falling and fading
--   Juice.knocker(target)         a target's knock-back (Target model: Hinge + Swing, attribute Knock)
local function quickEmitter(parent, name, texture, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Enabled = false
	e.Texture = texture
	e.LightInfluence = 0
	e.LockedToPart = true -- the flash rides the barrel
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end
function Juice.gunRig(tool)
	local handle = tool and tool:FindFirstChild('Handle')
	local muzzle = handle and handle:FindFirstChild('Muzzle')
	if not muzzle then return nil end
	local rig = muzzle:FindFirstChild('FlashCore') and { muzzle = muzzle } or nil
	if rig then
		rig.core, rig.star, rig.sparks, rig.light = muzzle.FlashCore, muzzle.FlashStar, muzzle.FlashSparks, muzzle:FindFirstChild('FlashLight')
		rig.eject = handle:FindFirstChild('Eject')
		return rig
	end
	rig = { muzzle = muzzle, eject = handle:FindFirstChild('Eject') }
	rig.core = quickEmitter(muzzle, 'FlashCore', 'rbxasset://textures/particles/sparkles_main.dds', {
		Lifetime = NumberRange.new(0.05, 0.07), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3, ZOffset = 1,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	})
	rig.star = quickEmitter(muzzle, 'FlashStar', 'rbxasset://textures/particles/explosion01_core_main.dds', {
		Lifetime = NumberRange.new(0.04, 0.06), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 2, ZOffset = 0.8,
		Rotation = NumberRange.new(0, 360), Transparency = NumberSequence.new(0.1),
	})
	rig.sparks = quickEmitter(muzzle, 'FlashSparks', 'rbxasset://textures/particles/sparkles_main.dds', {
		Lifetime = NumberRange.new(0.08, 0.14), Speed = NumberRange.new(14, 24), SpreadAngle = Vector2.new(14, 14), Drag = 6,
		EmissionDirection = Enum.NormalId.Front, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(1.6),
		LightEmission = 1, Brightness = 2, LockedToPart = false,
	})
	local light = Instance.new('PointLight')
	light.Name = 'FlashLight'
	light.Range, light.Brightness, light.Shadows, light.Enabled = 10, 3, false, false
	light.Parent = muzzle
	rig.light = light
	return rig
end
-- power ~1 (pistol) .. 2 (top guns): the flash grows with the gun.
function Juice.muzzle(rig, color, power)
	if not rig then return end
	power = power or 1
	local hot = Color3.fromRGB(255, 244, 200)
	rig.core.Color = ColorSequence.new(Color3.new(1, 1, 1), hot)
	rig.core.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0 * power), NumberSequenceKeypoint.new(1, 1.6 * power) })
	rig.core:Emit(1)
	rig.star.Color = ColorSequence.new(hot, color or hot)
	rig.star.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3 * power), NumberSequenceKeypoint.new(1, 0.4 * power) })
	rig.star:Emit(1)
	rig.sparks.Color = ColorSequence.new(hot, color or hot)
	rig.sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18 * power), NumberSequenceKeypoint.new(1, 0) })
	rig.sparks:Emit(math.floor(3 + 2 * power))
	if rig.light then
		rig.light.Color = color or hot
		rig.light.Enabled = true
		task.delay(0.05, function() rig.light.Enabled = false end)
	end
end

-- Tracers: a pool of two-part streaks (a thin white neon core inside a wider coloured glow), anchored, no
-- collisions, faded by one tween each.
local tracerPool, tracerNext = {}, 1
local function tracerPart(name, color, transparency)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 1
	p:SetAttribute('Rest', transparency)
	p.Size = Vector3.new(0.1, 0.1, 1)
	p.Parent = workspace
	return p
end
function Juice.tracer(from, to, color, width)
	local slot = tracerPool[tracerNext]
	if not slot or not slot.core.Parent then
		slot = { core = tracerPart('TracerCore', Color3.new(1, 1, 1), 0), glow = tracerPart('TracerGlow', Color3.new(1, 1, 1), 0.45) }
		tracerPool[tracerNext] = slot
	end
	tracerNext = tracerNext % 4 + 1
	local length = (to - from).Magnitude
	if length < 0.05 then return end
	local cf = CFrame.lookAt((from + to) / 2, to)
	width = width or 0.2
	for _, p in { slot.core, slot.glow } do
		local w = p == slot.core and width * 0.45 or width
		p.Size = Vector3.new(w, w, length)
		p.CFrame = cf
		-- The glow is the gun's colour warmed toward tracer yellow, so a grey pistol still draws a bright line.
		p.Color = p == slot.glow and (color or Color3.fromRGB(255, 214, 110)):Lerp(Color3.fromRGB(255, 214, 110), 0.5) or Color3.new(1, 1, 1)
		p.Transparency = p:GetAttribute('Rest')
		if slot.tween then slot.tween:Cancel() end
		TweenService:Create(p, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(w * 0.2, w * 0.2, length) }):Play()
	end
end

-- Shell casings: a pool of eight chunky brass cylinders (a bright neon tip so they read at play distance)
-- flipped out to the right, falling under gravity for 0.6 s.
local casings, casingNext, flying, casingConn = {}, 1, {}, nil
function Juice.casing(cframe, color)
	local p = casings[casingNext]
	if not p or not p.Parent then
		p = Instance.new('Part')
		p.Name = 'Casing'
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.45, 0.2, 0.2)
		p.Material = Enum.Material.Metal
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		local tip = Instance.new('Part')
		tip.Name = 'CasingTip'
		tip.Shape = Enum.PartType.Cylinder
		tip.Size = Vector3.new(0.06, 0.18, 0.18)
		tip.Material = Enum.Material.Neon
		tip.Color = Color3.fromRGB(255, 226, 140)
		tip.Anchored, tip.CanCollide, tip.CanQuery, tip.CanTouch, tip.CastShadow = true, false, false, false, false
		tip.Parent = p
		p.Parent = workspace
		casings[casingNext] = p
	end
	casingNext = casingNext % 8 + 1
	p.Color = color or Color3.fromRGB(236, 184, 70)
	p.Transparency = 0
	p.CasingTip.Transparency = 0
	local right, up = cframe.RightVector, cframe.UpVector
	flying[p] = { pos = cframe.Position, vel = right * (5 + math.random() * 2) + up * (6 + math.random() * 2) - cframe.LookVector * 1.5, spin = 0, age = 0 }
	if not casingConn then
		casingConn = RunService.PreRender:Connect(function(dt)
			for part, c in flying do
				c.age += dt
				c.vel += Vector3.new(0, -40, 0) * dt
				c.pos += c.vel * dt
				c.spin += dt * 25
				part.CFrame = CFrame.new(c.pos) * CFrame.Angles(c.spin, c.spin * 0.6, 0)
				part.CasingTip.CFrame = part.CFrame * CFrame.new(0.23, 0, 0)
				if c.age > 0.45 then
					part.Transparency = math.min(1, (c.age - 0.45) / 0.15)
					part.CasingTip.Transparency = part.Transparency
				end
				if c.age > 0.6 then
					part.Transparency, part.CasingTip.Transparency = 1, 1
					flying[part] = nil
				end
			end
			if next(flying) == nil then
				casingConn:Disconnect()
				casingConn = nil
			end
		end)
	end
end

-- Shards and confetti: a pool of three burst rigs (world-space particles, :Emit only). Bottles shatter into
-- glints in their colour, balloons pop into confetti in theirs plus white.
local shardPool, shardNext = {}, 1
local function shardRig()
	local slot = shardPool[shardNext]
	if not slot or not slot.part.Parent then
		local part = anchorAt(Vector3.zero)
		part.Name = 'ShardFX'
		local e = Instance.new('ParticleEmitter')
		e.Name = 'Shards'
		e.Enabled = false
		e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
		e.LightInfluence, e.LightEmission, e.Brightness = 0, 0.6, 1.5
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-300, 300)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = part
		slot = { part = part, e = e }
		shardPool[shardNext] = slot
	end
	shardNext = shardNext % 3 + 1
	return slot
end
-- kind 'glass': 10 shards in `color` (speed 8-14, falling); 'confetti': 12 flat squares in `color` and white.
function Juice.shards(position, color, kind)
	local slot = shardRig()
	slot.part.CFrame = CFrame.new(position)
	local e = slot.e
	color = color or Color3.new(1, 1, 1)
	if kind == 'confetti' then
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, color) })
		e.Speed, e.Lifetime, e.Acceleration, e.Drag = NumberRange.new(6, 10), NumberRange.new(0.6, 0.9), Vector3.new(0, -25, 0), 2
		e.Size = NumberSequence.new(0.45)
		e:Emit(12)
	else
		e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
		e.Speed, e.Lifetime, e.Acceleration, e.Drag = NumberRange.new(8, 14), NumberRange.new(0.4, 0.6), Vector3.new(0, -40, 0), 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.18) })
		e:Emit(10)
	end
end

-- A knockable target (Equipment > Targets > Target<i>): Hinge is the pivot, everything in Swing moves with it.
--   Tip     tips back about the hinge's X axis with a little hop and springs up again (boards, plates, barrels)
--   Swing   swings on its hanger (gongs, hanging plates)
--   Spin    spins about the hinge's Y axis and settles facing front (the spinner)
--   Pop     bursts into confetti, grows back (balloons)
--   Shatter bursts into shards in its colour, grows back (bottles)
--   Fly     flies up and back spinning about its middle, vanishes and pops back (cans)
-- :hit(strength); :present() is false while a burst or flown target is away (the shooter aims elsewhere). A Tip
-- target's TipMin attribute limits how far it rocks forward (0 for a can standing on a shelf: it never dips into
-- it). Swings are capped at SWING_BACK radians backwards, so a gong never reaches the wall behind it, however fast
-- you fire. Targets also have idle life (k.idle; :pose() shows it while nothing knocks them): hanging
-- plates sway a few degrees, spinners turn slowly, balloons bob; standing targets keep still. Everything is
-- local and cheap: a few CFrame writes per frame per knocked target, sleeping when settled.
local knocking, knockConn = {}, nil
local KNOCK = { Tip = { 3.2, 0.32, 14 }, Swing = { 1.3, 0.12, -3.2 }, Spin = { 1.2, 0.5, 26 }, Pop = { 4, 0.5, 0 }, Shatter = { 4, 0.5, 0 }, Fly = { 4, 0.5, 0 } }
local GONE = { Pop = 0.7, Shatter = 0.5, Fly = 0.8 } -- seconds a burst/flown target stays away
local SWING_BACK, SWING_FRONT = 0.3, 0.5 -- swing limits (radians; back = away from the shooter; idle sway adds 0.05)
local FLY_HIDE = 0.3 -- a flown can vanishes this soon (before it can reach the wall behind)
function Juice.knocker(target)
	local hinge = target:FindFirstChild('Hinge')
	local swing = target:FindFirstChild('Swing')
	if not hinge or not swing then return nil end
	local style = target:GetAttribute('Knock') or 'Tip'
	local k = { target = target, style = style, base = hinge.CFrame, parts = {}, angle = 0, vel = 0, gone = 0, grow = 1, hop = 0, fly = nil }
	k.tipMin = target:GetAttribute('TipMin') or -0.3
	-- A flown target spins about its middle (the aim point, in the hinge's frame), not about its foot.
	local aim = target:GetAttribute('Aim')
	k.centre = typeof(aim) == 'Vector3' and hinge.CFrame:PointToObjectSpace(aim) or Vector3.zero
	local p0 = hinge.CFrame.Position
	local phase = (p0.X * 0.37 + p0.Z * 0.61) % (2 * math.pi) -- neighbours never move in step
	k.idle = (style == 'Swing' and function(t) return 0.05 * math.sin(1.3 * t + phase) end)
		or (style == 'Spin' and function(t) return (0.45 * t + phase) % (2 * math.pi) end)
		or (style == 'Pop' and function(t) return 0.12 * math.sin(2 * t + phase) end)
		or nil
	for _, p in swing:GetDescendants() do
		if p:IsA('BasePart') then table.insert(k.parts, { part = p, offset = hinge.CFrame:ToObjectSpace(p.CFrame), size = p.Size, t = p.Transparency }) end
	end
	local function setHidden(on)
		for _, r in k.parts do r.part.Transparency = on and 1 or r.t end
	end
	local function apply()
		local a = k.angle + (k.idle and k.idle(os.clock()) or 0)
		local turn
		if style == 'Spin' then turn = CFrame.Angles(0, a, 0)
		elseif style == 'Pop' then turn = CFrame.new(0, a, 0)
		elseif style == 'Swing' then turn = CFrame.Angles(a, 0, 0)
		elseif style == 'Tip' then turn = CFrame.new(0, k.hop, 0) * CFrame.Angles(a, 0, 0)
		else turn = CFrame.new() end
		if k.fly then turn = CFrame.new(k.fly.pos + k.centre) * CFrame.Angles(k.fly.spin, 0, 0) * CFrame.new(-k.centre) end
		local at = k.base * turn
		local g = k.grow
		for _, r in k.parts do
			if g ~= 1 then
				r.part.Size = r.size * g
				r.part.CFrame = at * (r.offset - r.offset.Position + r.offset.Position * g)
			else
				if r.part.Size ~= r.size then r.part.Size = r.size end
				r.part.CFrame = at * r.offset
			end
		end
	end
	k.apply = apply
	-- The idle pose (call every frame for targets near the camera that nothing is knocking).
	function k:pose() if not knocking[self] then apply() end end
	-- False while a burst or flown target is away (it grows back in place, which counts as there).
	function k:present() return self.gone <= 0 and not self.fly end
	local function step(dt)
		local spec = KNOCK[style] or KNOCK.Tip
		if style == 'Spin' and math.abs(k.vel) > 4 then
			-- Free spin with drag, then a spring pulls it round to the nearest front-facing turn.
			k.vel *= math.exp(-1.6 * dt)
			k.angle += k.vel * dt
		elseif style == 'Tip' or style == 'Swing' or style == 'Spin' then
			local goal = style == 'Spin' and math.floor(k.angle / (2 * math.pi) + 0.5) * 2 * math.pi or 0
			k.angle, k.vel = Juice.springStep(k.angle, k.vel, goal, spec[1], spec[2], dt)
		end
		if style == 'Swing' and (k.angle < -SWING_BACK or k.angle > SWING_FRONT) then
			-- At the limit it stops and drifts back (a soft knock, not a bounce off the wall).
			k.angle = math.clamp(k.angle, -SWING_BACK, SWING_FRONT)
			k.vel = -k.vel * 0.25
		end
		if style == 'Tip' then
			if k.angle < k.tipMin then k.angle, k.vel = k.tipMin, math.max(k.vel, 0) end
			k.angle = math.min(k.angle, 1.25)
			k.hopT = (k.hopT or 0) + dt
			k.hop = k.hopT < 0.2 and 0.15 * math.sin(math.pi * k.hopT / 0.2) or 0
		end
		if k.fly then
			-- Up and back, spinning, then gone.
			local f = k.fly
			f.t += dt
			f.vel += Vector3.new(0, -30, 0) * dt
			f.pos += f.vel * dt
			f.spin += 15 * dt
			if f.t > FLY_HIDE and not f.hidden then
				f.hidden = true
				setHidden(true)
			end
		end
		if k.gone > 0 then
			k.gone -= dt
			if k.gone <= 0 then
				-- Back in its place, growing from 60% with a little overshoot.
				k.fly = nil
				k.growT = 0
				k.grow = 0.6
				setHidden(false)
			end
		elseif k.growT then
			k.growT += dt
			local f = math.min(1, k.growT / 0.3)
			k.grow = 0.6 + 0.4 * backOut(f)
			if f >= 1 then
				k.grow, k.growT = 1, nil
			end
		end
		apply()
		local rest = style == 'Spin' and math.floor(k.angle / (2 * math.pi) + 0.5) * 2 * math.pi or 0
		local settled = k.gone <= 0 and not k.growT and not k.fly and k.hop == 0 and math.abs(k.vel) < 1e-3 and math.abs(k.angle - rest) < 1e-3
		if settled then
			k.angle, k.vel, k.hopT = 0, 0, nil
			apply()
			knocking[k] = nil
		end
	end
	k.step = step
	function k:hit(strength, at)
		strength = strength or 1
		local spec = KNOCK[style] or KNOCK.Tip
		local centre = at or target:GetAttribute('Aim') or hinge.Position
		if GONE[style] then
			if self.gone > 0 or self.fly then return end
			local color = target:GetAttribute('ShardColor')
			if style == 'Pop' then
				setHidden(true)
				Juice.shards(centre, color, 'confetti')
			elseif style == 'Shatter' then
				setHidden(true)
				Juice.shards(centre, color, 'glass')
			else
				-- Fly: up 7, back 5 (away from the shooter, the hinge's +Z), spinning.
				self.fly = { t = 0, pos = Vector3.zero, vel = Vector3.new(0, 7, 5) * strength, spin = 0 }
			end
			self.gone = GONE[style]
			self.grow, self.growT = 1, nil
		else
			self.vel += spec[3] * strength
			if style == 'Tip' then self.hopT = 0 end
		end
		knocking[self] = true
		if not knockConn then
			knockConn = RunService.PreRender:Connect(function(dt)
				for item in knocking do item.step(dt) end
				if next(knocking) == nil then
					knockConn:Disconnect()
					knockConn = nil
				end
			end)
		end
	end
	return k
end

return Juice
