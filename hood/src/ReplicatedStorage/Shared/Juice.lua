-- Game feel for hits and rewards, client-side only (the server just validates and awards Power).
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
-- Sparks + an expanding ring at a world position. Uses Roblox's default particle texture until custom
-- textures are uploaded. Emitters live on a hidden anchor part and clean themselves up.
local function anchorAt(position)
	local p = Instance.new('Part')
	p.Name = 'ImpactFX'
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	Debris:AddItem(p, 2)
	return p
end
function Juice.burst(position, color, power)
	power = power or 1
	local p = anchorAt(position)
	local sparks = Instance.new('ParticleEmitter')
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.fromRGB(255, 194, 26))
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(18, 32)
	sparks.Drag = 10 -- fast out, then hang: the official burst recipe
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * power), NumberSequenceKeypoint.new(1, 0) })
	sparks.Squash = NumberSequence.new(1.2) -- stretched streaks
	sparks.Parent = p
	sparks:Emit(math.floor(10 * power))
	local ring = Instance.new('ParticleEmitter')
	ring.Enabled = false
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.LightEmission = 1
	ring.Lifetime = NumberRange.new(0.25)
	ring.Speed = NumberRange.new(0)
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 6 * power) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	ring.Parent = p
	ring:Emit(1)
end

-- White flash over a model for one beat (uses one of the 255 Highlight slots briefly, then frees it).
function Juice.flash(model)
	local h = Instance.new('Highlight')
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.3
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
	Debris:AddItem(h, 0.15)
end

-- "+123" floating up from a world point: overshoot pop, drift up, fade.
function Juice.popNumber(position, text, color, fontFace)
	local p = anchorAt(position)
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

-- Everything for one punch landing on a bag. `bag` = { sway = Juice.sway(...), model = Model, point = Vector3 }
function Juice.punch(bag, fromPosition, gained, big)
	local dir = (bag.point - fromPosition) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) end
	local power = big and 1.6 or 1
	bag.sway:hit(dir.Unit, power)
	Juice.burst(bag.point, nil, power)
	Juice.flash(bag.model)
	Juice.kick(big and 0.9 or 0.35)
	if gained then Juice.popNumber(bag.point + Vector3.new(0, 1.5, 0), '+' .. gained) end
end

return Juice
