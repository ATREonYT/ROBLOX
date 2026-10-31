--!strict
-- New Game Kit: LaunchFX (a cannon / throw / launch shot that feels pro; vault notes 16 §4 and 17)
-- Install: ReplicatedStorage/Kit/LaunchFX (ModuleScript). Client only: the server decides power and
-- distance and fires one remote; every client plays these visuals (note 17 §3).
--
--   local shot = LaunchFX.Charge(cannonModel, { seconds = 0.28 })   -- tips up, creeps back, trembles
--   shot:Fire({ tier = "Epic", color = accent, direction = look })  -- release, recoil, muzzle, camera
--   local flight = LaunchFX.Flight(ballPart, { color = accent, tier = "Epic" })
--   ... each frame the ball moves; flight stretches it by speed and keeps its trails ...
--   flight:Land(hitPosition)                                         -- squash, ring, dust, hit-stop
--
-- The cannon model needs a PrimaryPart (or a pivot) and, ideally, an Attachment named "Muzzle" at
-- the barrel tip. Optional: a part named "Barrel" (stretched on release) and "Glow" (tip that cools).
-- Timings are the note 16 recipe: slow charge, 1-2 frame release, recoil in 0.06 s, spring return.
-- Bigger tiers add layers and time (Tiers below); RareReveal plays the cinematic on top for Legendary+.
-- Kid-safe: one muzzle flash light per shot (no screen flash), shake through Emit.MotionScale and capped
-- at a "Bump", under ~100 particles per shot. Built-in textures only: swap LaunchFX.Textures for your own.
-- Status: pure maths covered by tests/LaunchFX.spec.luau; visuals need a Play test in Studio.

local Spring = require(script.Parent:WaitForChild("Spring"))
local Emit = require(script.Parent:WaitForChild("Emit"))

local LaunchFX = {}

LaunchFX.Textures = {
	glow = "rbxasset://textures/glow.png",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
}

-- One row per shot tier. power scales sizes and counts; shake is trauma added at the shot (0..1);
-- stop is the landing hit-stop in seconds; fov is the extra field of view at the kick.
LaunchFX.Tiers = {
	-- The reference (+1 Stone Skipping, frame-studied Oct 31) has no shake or zoom on a normal throw:
	-- keep Common nearly clean and let the extras grow with rarity.
	Common = { power = 1, shake = 0, stop = 0, fov = 0, sparks = 12, puffs = 6 },
	Rare = { power = 1.15, shake = 0, stop = 0, fov = 0, sparks = 16, puffs = 7 },
	Epic = { power = 1.3, shake = 0.25, stop = 0, fov = 8, sparks = 18, puffs = 8 },
	Legendary = { power = 1.5, shake = 0.35, stop = 0.1, fov = 10, sparks = 22, puffs = 9 },
	Mythic = { power = 1.75, shake = 0.45, stop = 0.1, fov = 12, sparks = 25, puffs = 10 },
	Secret = { power = 2, shake = 0.5, stop = 0.12, fov = 14, sparks = 25, puffs = 10 },
}

LaunchFX.Recipe = {
	chargeSeconds = 0.28, -- reference: tap to shot 0.33 s, no hold-to-charge (note 17 §1)
	chargeTiltDeg = 6,
	chargeCreep = 0.15, -- studs back while charging
	tremble = 0.5, -- degrees, last 0.1 s of the charge
	recoilFraction = 0.2, -- of the model's length
	recoilPitchDeg = 9,
	returnSpring = Spring.Presets.Bouncy,
	rockSpring = Spring.Presets.Wobble,
	fovKickSeconds = 0.08,
	fovFlight = 5, -- extra FOV kept during flight
	maxStretch = 0.6,
	stretchSpeed = 120,
}

-- Pure helpers -----------------------------------------------------------------------------------

function LaunchFX.Tier(name: string?): typeof(LaunchFX.Tiers.Common)
	return LaunchFX.Tiers[name or "Common"] or LaunchFX.Tiers.Common
end

-- Visual stretch along the velocity: length z and width xy keep the volume (z * xy * xy = 1).
function LaunchFX.StretchFor(speed: number): (number, number)
	local r = LaunchFX.Recipe
	local z = 1 + math.clamp(speed / r.stretchSpeed, 0, r.maxStretch)
	return z, 1 / math.sqrt(z)
end

-- Projectile position after t seconds (gravity in studs/s^2, Roblox default 196.2).
function LaunchFX.Arc(origin: Vector3, velocity: Vector3, t: number, gravity: number?): Vector3
	local g = gravity or 196.2
	return origin + velocity * t + Vector3.new(0, -0.5 * g * t * t, 0)
end

-- When the shot comes back down to height groundY (nil if it never does).
function LaunchFX.LandingTime(origin: Vector3, velocity: Vector3, groundY: number, gravity: number?): number?
	local g = gravity or 196.2
	local a, b, c = -0.5 * g, velocity.Y, origin.Y - groundY
	local disc = b * b - 4 * a * c
	if disc < 0 then
		return nil
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	return if t > 0 then t else nil
end

-- Trauma camera shake (GDC "Juicing Your Cameras With Math"): shake = trauma^2, trauma decays.
local Trauma = {}
Trauma.__index = Trauma
LaunchFX.Trauma = Trauma

function Trauma.new(decayPerSecond: number?, maxDegrees: number?)
	return setmetatable({ value = 0, decay = decayPerSecond or 1.6, max = maxDegrees or 2.5 }, Trauma)
end

function Trauma:Add(amount: number)
	self.value = math.min(1, self.value + amount)
end

-- Returns the shake angle in degrees for this frame (0 once trauma has decayed).
function Trauma:Step(dt: number): number
	self.value = math.max(0, self.value - self.decay * dt)
	return self.max * self.value * self.value
end

-- Client visuals -----------------------------------------------------------------------------------

local function isClient(): boolean
	local ok, client = pcall(function()
		return game:GetService("RunService"):IsClient()
	end)
	return ok and client
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local WHITE = ((Color3 :: any) and Color3.new(1, 1, 1)) :: Color3 -- (nil in the offline test mock)

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Rotation = NumberRange.new(-180, 180)
	e.RotSpeed = NumberRange.new(-90, 90)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function holder(cf: CFrame): (Part, Attachment)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	local a = Instance.new("Attachment")
	a.Parent = p
	p.Parent = workspace
	return p, a
end

-- Muzzle effect as an Emit template: flash, sparks, ring, puffs, fastest first (note 16 §4).
function LaunchFX.MuzzleTemplate(color: Color3, tierName: string?): Attachment
	local t = LaunchFX.Tier(tierName)
	local s = t.power
	local a = Instance.new("Attachment")
	a.Name = "MuzzleFX"
	local flash = emitter(a, "Flash", {
		Texture = LaunchFX.Textures.glow,
		Speed = NumberRange.new(0),
		Lifetime = NumberRange.new(0.06, 0.08),
		Size = seq({ { 0, 2 * s }, { 0.2, 4.5 * s }, { 1, 0 } }),
		Color = ColorSequence.new(WHITE, color),
		LightEmission = 1,
		ZOffset = 1,
	})
	flash:SetAttribute("EmitCount", 2)
	local sparks = emitter(a, "Sparks", {
		Texture = LaunchFX.Textures.spark,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(25, 25),
		Speed = NumberRange.new(20, 40),
		Drag = 4,
		Lifetime = NumberRange.new(0.2, 0.4),
		Squash = seq({ { 0, 1.5 }, { 1, 1.5 } }),
		Size = seq({ { 0, 0.45 * s }, { 1, 0 } }),
		Color = ColorSequence.new(WHITE, color),
		LightEmission = 1,
	})
	sparks:SetAttribute("EmitCount", t.sparks)
	sparks:SetAttribute("EmitDelay", 0.02)
	local ring = emitter(a, "Ring", {
		Texture = LaunchFX.Textures.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.35),
		Size = seq({ { 0, 1 * s }, { 0.25, 4.5 * s }, { 1, 6 * s } }),
		Transparency = seq({ { 0, 0.1 }, { 0.4, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.3,
		Rotation = NumberRange.new(0),
		RotSpeed = NumberRange.new(0),
	})
	ring:SetAttribute("EmitCount", 1)
	ring:SetAttribute("EmitDelay", 0.02)
	local puffs = emitter(a, "Puffs", {
		Texture = LaunchFX.Textures.smoke,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(35, 35),
		Speed = NumberRange.new(4, 9),
		Drag = 3,
		Lifetime = NumberRange.new(0.8, 1.2),
		Size = seq({ { 0, 1.5 * s }, { 0.2, 3.5 * s }, { 1, 5 * s } }),
		Transparency = seq({ { 0, 0.2 }, { 0.6, 0.55 }, { 1, 1 } }),
		Color = ColorSequence.new(Color3.fromRGB(235, 235, 240)),
		LightEmission = 0, -- smoke is never additive (white fog in daylight)
	})
	puffs:SetAttribute("EmitCount", t.puffs)
	puffs:SetAttribute("EmitDelay", 0.05)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = 16
	light:SetAttribute("EmitDuration", 0.1)
	light.Parent = a
	return a
end

export type Shot = {
	Fire: (self: Shot, options: { tier: string?, color: Color3?, direction: Vector3? }?) -> (),
	Cancel: (self: Shot) -> (),
}

local camTrauma = Trauma.new()
local camBound = false
local shakeDir = Vector3.new(0, 0, 1)
local baseFov: number? = nil
local fovSpring: Spring.Spring? = nil

local function cameraLoop()
	if camBound then
		return
	end
	camBound = true
	local RunService = game:GetService("RunService")
	RunService:BindToRenderStep("LaunchFXCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		local angle = camTrauma:Step(dt) * Emit.MotionScale()
		if angle > 0 then
			-- push opposite the shot, plus a little noise
			local t = os.clock() * 25
			local pitch = math.rad(angle) * (0.6 + 0.4 * math.noise(t, 1))
			local yaw = math.rad(angle) * 0.5 * math.noise(t, 2) * (if shakeDir.X >= 0 then 1 else -1)
			cam.CFrame = cam.CFrame * CFrame.Angles(pitch, yaw, 0)
		end
		if fovSpring and baseFov then
			cam.FieldOfView = fovSpring:Step(dt)
		end
		if camTrauma.value <= 0 and (not fovSpring or fovSpring:IsResting(0.01)) then
			RunService:UnbindFromRenderStep("LaunchFXCamera")
			camBound = false
			if fovSpring then
				cam.FieldOfView = fovSpring.Target
			end
		end
	end)
end

-- Kick the camera for a shot: trauma shake opposite `direction` and a fast FOV punch that settles to
-- `hold` extra degrees (keep it during flight; call LaunchFX.ReleaseCamera() at landing).
function LaunchFX.KickCamera(trauma: number, fovKick: number, hold: number?, direction: Vector3?)
	if not isClient() then
		return
	end
	local cam = workspace.CurrentCamera
	if direction then
		shakeDir = -direction
	end
	camTrauma:Add(trauma * Emit.MotionScale())
	baseFov = baseFov or cam.FieldOfView
	local base = baseFov :: number
	local reduced = Emit.MotionScale() == 0
	fovSpring = Spring.new(cam.FieldOfView, 0.7, 3)
	local spring = fovSpring :: Spring.Spring
	if not reduced then
		spring.Value = base + fovKick
	end
	spring:SetTarget(base + (if reduced then 0 else (hold or 0)))
	cameraLoop()
end

function LaunchFX.ReleaseCamera()
	if fovSpring and baseFov then
		fovSpring:SetTarget(baseFov)
		cameraLoop()
	end
	baseFov = nil
end

-- Charge the cannon. Returns a Shot; call :Fire() on release (or :Cancel()).
function LaunchFX.Charge(model: Model, options: { seconds: number? }?): Shot
	local r = LaunchFX.Recipe
	local seconds = (options and options.seconds) or r.chargeSeconds
	local base = model:GetPivot()
	local size = model:GetExtentsSize()
	local length = math.max(size.X, size.Z)
	local start = os.clock()
	local RunService = game:GetService("RunService")
	local alive = true
	local loop: RBXScriptConnection? = nil
	-- offsets in the model's own space: z back (+), pitch up (+)
	local back = Spring.new(0, r.returnSpring.damping, r.returnSpring.frequency)
	local pitch = Spring.new(0, r.rockSpring.damping, r.rockSpring.frequency)
	local phase = "charge"

	local function apply(extraPitch: number)
		model:PivotTo(base * CFrame.new(0, 0, back.Value) * CFrame.Angles(math.rad(pitch.Value + extraPitch), 0, 0))
	end

	loop = RunService.RenderStepped:Connect(function(dt)
		if not alive then
			return
		end
		if phase == "charge" then
			local k = math.clamp((os.clock() - start) / seconds, 0, 1)
			local ease = 0.5 - 0.5 * math.cos(math.pi * k) -- Sine InOut
			back:Snap(r.chargeCreep * ease)
			pitch:Snap(r.chargeTiltDeg * ease)
			local tremble = if k > 1 - 0.1 / seconds then (math.random() - 0.5) * 2 * r.tremble else 0
			apply(tremble)
		else
			back:Step(dt)
			pitch:Step(dt)
			apply(0)
			if back:IsResting(0.005) and pitch:IsResting(0.05) then
				back:Snap(0)
				pitch:Snap(0)
				apply(0)
				alive = false
				if loop then
					loop:Disconnect()
				end
			end
		end
	end)

	local shot = {}
	function shot.Fire(_, fireOptions: { tier: string?, color: Color3?, direction: Vector3? }?)
		if phase ~= "charge" then
			return
		end
		phase = "recoil"
		local o = fireOptions or {}
		local tier = LaunchFX.Tier(o.tier)
		local color = o.color or Color3.fromRGB(255, 200, 80)
		-- release: snap back and up instantly (the 1-2 frame action), then the springs bring it home
		back.Value = r.chargeCreep + r.recoilFraction * length * math.min(tier.power, 1.4)
		back.Velocity = 0
		back:SetTarget(0)
		pitch.Value = r.chargeTiltDeg + r.recoilPitchDeg
		pitch.Velocity = 0
		pitch:SetTarget(0)
		-- barrel stretch for two frames
		local barrel = model:FindFirstChild("Barrel", true)
		if barrel and barrel:IsA("BasePart") then
			local original = barrel.Size
			barrel.Size = Vector3.new(original.X * 0.9, original.Y * 0.9, original.Z * 1.2)
			task.delay(0.066, function()
				barrel.Size = original
			end)
		end
		-- muzzle layers
		local muzzle = model:FindFirstChild("Muzzle", true)
		local cf = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldCFrame else base
		if Emit.InRange(cf.Position) then
			local p, _ = holder(cf)
			Emit.Play(LaunchFX.MuzzleTemplate(color, o.tier), p)
			task.delay(1.6, function()
				p:Destroy()
			end)
		end
		-- the barrel tip glows and cools
		local glow = model:FindFirstChild("Glow", true)
		if glow and glow:IsA("BasePart") then
			local TweenService = game:GetService("TweenService")
			local original = glow.Color
			glow.Color = Color3.fromRGB(255, 150, 60)
			TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = original }):Play()
		end
		LaunchFX.KickCamera(tier.shake, tier.fov, r.fovFlight, o.direction or cf.LookVector)
	end
	function shot.Cancel(_)
		alive = false
		if loop then
			loop:Disconnect()
		end
		model:PivotTo(base)
	end
	return (shot :: any) :: Shot
end

export type Flight = { Land: (self: Flight, position: Vector3?) -> (), Stop: (self: Flight) -> () }

-- Keep a flying ball readable: stretch by speed, spin, two trails (accent + bright core).
-- `ball` is the visual part (not the physics part). Stretching uses a SpecialMesh or the part's Size.
function LaunchFX.Flight(ball: BasePart, options: { color: Color3?, tier: string? }?): Flight
	local o = options or {}
	local color = o.color or Color3.fromRGB(255, 200, 80)
	local tier = LaunchFX.Tier(o.tier)
	local width = math.max(ball.Size.X, 0.5)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, width * 0.5, 0), Vector3.new(0, -width * 0.5, 0)
	a0.Parent, a1.Parent = ball, ball
	local function trail(name: string, w: number, life: number, c: Color3, emission: number)
		local t = Instance.new("Trail")
		t.Name = name
		t.Attachment0, t.Attachment1 = a0, a1
		t.Lifetime = life
		t.WidthScale = seq({ { 0, w }, { 1, 0 } })
		t.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
		t.Color = ColorSequence.new(c)
		t.LightEmission = emission
		t.FaceCamera = true
		t.Parent = ball
		return t
	end
	local outer = trail("Accent", 1, 0.3 + 0.15 * tier.power, color, 0.4)
	local inner = trail("Core", 0.35, 0.2, WHITE, 1)
	local mesh = ball:FindFirstChildOfClass("SpecialMesh")
	local baseScale = if mesh then mesh.Scale else nil
	local baseSize = ball.Size
	local last = ball.Position
	local spin = 0
	local RunService = game:GetService("RunService")
	local conn = RunService.RenderStepped:Connect(function(dt)
		if dt <= 0 then
			return
		end
		local pos = ball.Position
		local vel = (pos - last) / dt
		last = pos
		local z, xy = LaunchFX.StretchFor(vel.Magnitude)
		if mesh and baseScale then
			mesh.Scale = Vector3.new(baseScale.X * xy, baseScale.Y * xy, baseScale.Z * z)
		end
		spin += dt * math.pi * 2 * 1.5
		if vel.Magnitude > 1 and ball.Anchored then
			ball.CFrame = CFrame.lookAt(pos, pos + vel) * CFrame.Angles(0, 0, spin)
		end
	end)
	local flight = {}
	local done = false
	function flight.Stop(_)
		if done then
			return
		end
		done = true
		conn:Disconnect()
		outer.Enabled, inner.Enabled = false, false
		if mesh and baseScale then
			mesh.Scale = baseScale
		end
		task.delay(0.6, function()
			outer:Destroy()
			inner:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end
	function flight.Land(self: any, position: Vector3?)
		local where = position or ball.Position
		self:Stop()
		LaunchFX.Land(where, color, o.tier)
		-- squash the ball and spring it back (landing mirrors launch)
		local squash = Spring.fromPreset(0.6, "Squash")
		squash:SetTarget(1)
		local function apply(v: number)
			local wide = 1 + (1 - v) * 0.75
			if mesh and baseScale then
				mesh.Scale = Vector3.new(baseScale.X * wide, baseScale.Y * v, baseScale.Z * wide)
			elseif ball.Anchored then
				ball.Size = Vector3.new(baseSize.X * wide, baseSize.Y * v, baseSize.Z * wide)
			end
		end
		if tier.stop > 0 then
			apply(0.6)
			task.wait(tier.stop) -- hit-stop: hold the squash
		end
		Spring.Run(squash, apply)
		LaunchFX.ReleaseCamera()
	end
	return (flight :: any) :: Flight
end

-- Landing burst: ground ring and dust, scaled by tier. Bigger tiers add a small extra shake.
function LaunchFX.Land(position: Vector3, color: Color3?, tierName: string?)
	if not Emit.InRange(position) then
		return
	end
	local t = LaunchFX.Tier(tierName)
	local s = t.power
	local p, a = holder(CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0))
	emitter(a, "Ring", {
		Texture = LaunchFX.Textures.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.4),
		Size = seq({ { 0, 1 * s }, { 0.25, 6 * s }, { 1, 8 * s } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Color = ColorSequence.new(color or WHITE),
		LightEmission = 0.2,
		Rotation = NumberRange.new(0),
		RotSpeed = NumberRange.new(0),
	}):Emit(1)
	emitter(a, "Dust", {
		Texture = LaunchFX.Textures.smoke,
		SpreadAngle = Vector2.new(80, 80),
		Speed = NumberRange.new(6, 14),
		Drag = 4,
		Acceleration = Vector3.new(0, 4, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Size = seq({ { 0, 1 * s }, { 0.2, 2.5 * s }, { 1, 3.5 * s } }),
		Transparency = seq({ { 0, 0.25 }, { 0.6, 0.6 }, { 1, 1 } }),
		Color = ColorSequence.new(Color3.fromRGB(225, 215, 200)),
		LightEmission = 0,
	}):Emit(math.floor(8 + 6 * (s - 1)))
	if t.stop > 0 then
		camTrauma:Add(t.shake * 0.6 * Emit.MotionScale())
		cameraLoop()
	end
	task.delay(1.4, function()
		p:Destroy()
	end)
end

return LaunchFX
