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
function Juice.popNumber(position, text, color, fontFace)
	local p = anchorAt(position)
	Debris:AddItem(p, 1)
	local g = Instance.new('BillboardGui')
	g.Size = UDim2.fromScale(4, 1.6)
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
	t.TextColor3 = color or Color3.fromRGB(255, 194, 26)
	local s = Instance.new('UIStroke')
	s.Color = Color3.fromRGB(28, 24, 48)
	s.Thickness = 2.5
	s.Parent = t
	scale.Parent = t
	t.Parent = g
	local drift = (math.random() - 0.5) * 1.5
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(g, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(drift, 3, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { Transparency = 1 }):Play()
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

-- Shell casings: a pool of eight brass cylinders flipped out to the right, falling under gravity for 0.6 s.
local casings, casingNext, flying, casingConn = {}, 1, {}, nil
function Juice.casing(cframe, color)
	local p = casings[casingNext]
	if not p or not p.Parent then
		p = Instance.new('Part')
		p.Name = 'Casing'
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 0.13, 0.13)
		p.Material = Enum.Material.Metal
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Parent = workspace
		casings[casingNext] = p
	end
	casingNext = casingNext % 8 + 1
	p.Color = color or Color3.fromRGB(236, 184, 70)
	p.Transparency = 0
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
				if c.age > 0.45 then part.Transparency = math.min(1, (c.age - 0.45) / 0.15) end
				if c.age > 0.6 then
					part.Transparency = 1
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

-- A knockable target (Equipment > Targets > Target<i>): Hinge is the pivot, everything in Swing moves with it.
-- Knock 'Tip' tips back about the hinge's X axis and springs up again, 'Swing' swings on its hanger, 'Spin'
-- spins about the hinge's Y axis and settles facing front, 'Pop' vanishes and grows back. :hit(strength).
-- Targets also have idle life (k.idle; :pose(t) shows it while nothing knocks them): hanging plates sway a
-- few degrees, spinners turn slowly, balloons bob; standing targets keep still.
local knocking, knockConn = {}, nil
local KNOCK = { Tip = { 3.2, 0.32, 9 }, Swing = { 1.3, 0.12, -4.5 }, Spin = { 1.2, 0.5, 26 }, Pop = { 4, 0.5, 0 } }
function Juice.knocker(target)
	local hinge = target:FindFirstChild('Hinge')
	local swing = target:FindFirstChild('Swing')
	if not hinge or not swing then return nil end
	local style = target:GetAttribute('Knock') or 'Tip'
	local k = { target = target, style = style, base = hinge.CFrame, parts = {}, angle = 0, vel = 0, popped = 0 }
	local p0 = hinge.CFrame.Position
	local phase = (p0.X * 0.37 + p0.Z * 0.61) % (2 * math.pi) -- neighbours never move in step
	k.idle = (style == 'Swing' and function(t) return 0.05 * math.sin(1.3 * t + phase) end)
		or (style == 'Spin' and function(t) return (0.45 * t + phase) % (2 * math.pi) end)
		or (style == 'Pop' and function(t) return 0.12 * math.sin(2 * t + phase) end)
		or nil
	for _, p in swing:GetDescendants() do
		if p:IsA('BasePart') then table.insert(k.parts, { part = p, offset = hinge.CFrame:ToObjectSpace(p.CFrame), t = p.Transparency }) end
	end
	local function apply()
		local a = k.angle + (k.idle and k.idle(os.clock()) or 0)
		local turn = (style == 'Spin') and CFrame.Angles(0, a, 0) or (style == 'Pop') and CFrame.new(0, a, 0) or CFrame.Angles(a, 0, 0)
		local at = k.base * turn
		for _, r in k.parts do r.part.CFrame = at * r.offset end
	end
	k.apply = apply
	-- The idle pose (call every frame for targets near the camera that nothing is knocking).
	function k:pose() if not knocking[self] then apply() end end
	local function step(dt)
		local spec = KNOCK[style] or KNOCK.Tip
		if style == 'Spin' and math.abs(k.vel) > 4 then
			-- Free spin with drag, then a spring pulls it round to the nearest front-facing turn.
			k.vel *= math.exp(-1.6 * dt)
			k.angle += k.vel * dt
		else
			local goal = style == 'Spin' and math.floor(k.angle / (2 * math.pi) + 0.5) * 2 * math.pi or 0
			k.angle, k.vel = Juice.springStep(k.angle, k.vel, goal, spec[1], spec[2], dt)
		end
		if style == 'Tip' then k.angle = math.clamp(k.angle, -0.3, 1.25) end
		if k.popped > 0 then
			k.popped -= dt
			if k.popped <= 0 then
				for _, r in k.parts do r.part.Transparency = r.t end
				k.angle, k.vel = -0.8, 0 -- grows back from a little below
			end
		end
		apply()
		local settled = k.popped <= 0 and math.abs(k.vel) < 1e-3 and math.abs(k.angle - (style == 'Spin' and math.floor(k.angle / (2 * math.pi) + 0.5) * 2 * math.pi or 0)) < 1e-3
		if settled then
			k.angle, k.vel = 0, 0
			apply()
			knocking[k] = nil
		end
	end
	k.step = step
	function k:hit(strength)
		strength = strength or 1
		local spec = KNOCK[style] or KNOCK.Tip
		if style == 'Pop' then
			if self.popped > 0 then return end
			for _, r in self.parts do r.part.Transparency = 1 end
			self.popped = 0.7
		else
			self.vel += spec[3] * strength
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
