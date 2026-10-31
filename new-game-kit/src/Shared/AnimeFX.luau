--!strict
-- New Game Kit: AnimeFX (anime-style power-up auras and hit effects, vault note 15)
-- Install: ReplicatedStorage/Kit/AnimeFX (ModuleScript). Call it from LocalScripts only: effects are
-- drawn on each client; the server decides what happened and tells clients (note 15 §6).
--
--   local aura = AnimeFX.Aura(character, { color = Color3.fromRGB(255, 210, 60), tier = 0.6 })
--   aura:Charge()            -- burst: flare up, ground shockwave, dust, small shake
--   aura:SetTier(1)          -- 0..1: each step adds a channel (core, streaks, ground, arcs, outline)
--   aura:Destroy()
--   AnimeFX.Hit(position, color, "Heavy")        -- sparks, flash, ring (+ shake on Heavy/Finisher)
--   AnimeFX.Shockwave(position, color, radius)   -- flat ring + dust
--   AnimeFX.Crater(position, radius)             -- rocks pop up in a ring, then sink away
--   AnimeFX.ImpactFrame()                         -- one 0.07 s black-and-white frame (finishers only)
--   AnimeFX.SpeedLines(duration)                  -- radial lines on screen (dashes, charges)
--   AnimeFX.HitStop(animationTrack, seconds)      -- freezes an attack for 0.04-0.12 s
--   AnimeFX.Shake(strength, seconds)
--
-- Kid-safe (repo CLAUDE.md): ImpactFrame is at most one a second and skipped when the player's
-- Flashes setting is off; Shake is skipped when ScreenShake is off; nothing flashes the whole screen
-- white; no blood (hits are sparks, rings and stars). Only Roblox's built-in textures, so nothing to
-- upload; swap AnimeFX.Textures for your uploaded ids later.
-- Status: aura previewed offline (new-game-kit/previews/anime-aura.png); not yet run in Studio.

local AnimeFX = {}

AnimeFX.Textures = {
	flame = "rbxasset://textures/particles/fire_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	glow = "rbxasset://textures/glow.png",
}

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function colors(a: Color3, b: Color3, c: Color3?): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, c or b),
	})
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local WHITE = Color3.new(1, 1, 1)

-- Player settings (kit Settings module publishes Setting_<key> attributes). Missing = on.
local function isClient(): boolean
	local ok, client = pcall(function()
		return game:GetService("RunService"):IsClient()
	end)
	return ok and client == true
end

local function settingOn(key: string): boolean
	local ok, players = pcall(function()
		return game:GetService("Players")
	end)
	local lp = ok and players and players.LocalPlayer
	if not lp then
		return true
	end
	return lp:GetAttribute(`Setting_{key}`) ~= false
end

---------------------------------------------------------------------------------------------------
-- Aura: the power-up flare around the body (Dragon Ball-style energy, our own recipe)
---------------------------------------------------------------------------------------------------
-- Layers, each one a different job (skill roblox-vfx §1):
--   Flames   tall flame tongues licking up the body: the silhouette of the aura (tier colour)
--   Core     smaller white-hot tongues close to the body: makes it read as energy, not fire  (tier >= 0.2)
--   Streaks  thin sparks shooting straight up: speed and power                              (tier >= 0.4)
--   Dust     dust pushed out along the ground + a glow disc under the feet: weight            (tier >= 0.5)
--   Arcs     short electric crackles round the body (scripted beams, ~4 a second)            (tier >= 0.75)
--   Outline  a soft Highlight on the character (local player only: Highlights are limited)  (tier >= 0.9)
--   Light    one PointLight, Shadows off
export type AuraOptions = { color: Color3?, tier: number?, outline: boolean? }
export type Aura = {
	Model: Model,
	SetTier: (Aura, number) -> (),
	Charge: (Aura) -> (),
	Destroy: (Aura) -> (),
}

function AnimeFX.Aura(character: Model, options: AuraOptions?): Aura
	local opts = options or {}
	local color = opts.color or Color3.fromRGB(255, 210, 60)
	local hot = color:Lerp(WHITE, 0.65)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(root, "AnimeFX.Aura: the character needs a HumanoidRootPart")

	local model = Instance.new("Model")
	model.Name = "AnimeAura"

	-- An invisible box the size of the body: emitters fill its volume, LockedToPart keeps the
	-- flames on the body while it moves (an aura that trails behind looks broken).
	local body = Instance.new("Part")
	body.Name = "AuraBody"
	body.Size = Vector3.new(3.6, 5, 1.6)
	body.Transparency = 1
	body.CanCollide, body.CanTouch, body.CanQuery, body.Massless, body.CastShadow = false, false, false, true, false
	body.CFrame = root.CFrame * CFrame.new(0, -0.3, 0)
	body.Parent = model

	local feet = Instance.new("Attachment")
	feet.Name = "Feet"
	feet.CFrame = CFrame.new(0, -2.65, 0)
	feet.Parent = body

	-- The envelope: big soft glows stretched tall behind the body give the aura its egg-shaped
	-- outline, so it reads as one shape and not a few loose flames.
	local shell = emitter(body, "Shell", {
		Texture = AnimeFX.Textures.glow,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top,
		LockedToPart = true,
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(1, 2),
		Squash = seq({ { 0, 0.7 }, { 1, 0.7 } }),
		Size = seq({ { 0, 6 }, { 0.5, 7.5 }, { 1, 7 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }),
		Color = colors(color, color),
		LightEmission = 1,
		ZOffset = -1.2,
		Rate = 0,
	})
	local flames = emitter(body, "Flames", {
		Texture = AnimeFX.Textures.flame,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top,
		LockedToPart = true,
		Lifetime = NumberRange.new(0.45, 0.7),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 18, 0),
		Drag = 1,
		Rotation = NumberRange.new(-8, 8),
		Squash = seq({ { 0, 0.5 }, { 1, 1.1 } }),
		Size = seq({ { 0, 1.8 }, { 0.4, 3 }, { 1, 0.8 } }),
		Transparency = seq({ { 0, 1 }, { 0.12, 0.25 }, { 0.65, 0.45 }, { 1, 1 } }),
		Color = colors(hot, color, color:Lerp(Color3.new(), 0.25)),
		LightEmission = 1,
		Brightness = 1,
		ZOffset = -0.6,
		Rate = 0,
	})
	local core = emitter(body, "Core", {
		Texture = AnimeFX.Textures.flame,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top,
		LockedToPart = true,
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(0, 12, 0),
		Squash = seq({ { 0, 0.6 }, { 1, 0.6 } }),
		Size = seq({ { 0, 0.8 }, { 0.4, 1.3 }, { 1, 0.3 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.45 }, { 0.7, 0.6 }, { 1, 1 } }),
		Color = colors(WHITE, hot),
		LightEmission = 1,
		ZOffset = 0.4,
		Rate = 0,
	})
	local streaks = emitter(body, "Streaks", {
		Texture = AnimeFX.Textures.spark,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		LockedToPart = true,
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(4, 4),
		Squash = seq({ { 0, 2.5 }, { 1, 2.5 } }),
		Size = seq({ { 0, 0.35 }, { 1, 0.15 } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0 }, { 1, 1 } }),
		Color = colors(WHITE, hot),
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 0.8,
		Rate = 0,
	})
	local dust = emitter(feet, "Dust", {
		Texture = AnimeFX.Textures.smoke,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(85, 85),
		Drag = 3,
		Acceleration = Vector3.new(0, -2, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Size = seq({ { 0, 0.8 }, { 1, 2.6 } }),
		Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
		Color = colors(Color3.fromRGB(235, 225, 210), Color3.fromRGB(200, 190, 175)),
		LightEmission = 0.05,
		LightInfluence = 0.6,
		Rate = 0,
	})
	local disc = emitter(feet, "GroundGlow", {
		Texture = AnimeFX.Textures.glow,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.8, 1),
		Size = seq({ { 0, 5 }, { 1, 6.5 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }),
		Color = colors(color, color),
		LightEmission = 1,
		Rate = 0,
	})
	-- One-shot layers for Charge (Rate 0, fired with :Emit).
	local ring = emitter(feet, "ChargeRing", {
		Texture = AnimeFX.Textures.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.45),
		Size = seq({ { 0, 2 }, { 1, 18 } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Color = colors(hot, color),
		LightEmission = 1,
		Rate = 0,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 0
	light.Shadows = false
	light.Parent = body

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = root
	weld.Parent = body
	model.Parent = character

	local outline: Highlight? = nil
	local tier = 0
	local alive = true

	local self = { Model = model } :: any

	function self.SetTier(_: Aura, k: number)
		tier = math.clamp(k, 0, 1)
		flames.Rate = 45 + 75 * tier
		flames.Size = seq({ { 0, 1.8 + 0.5 * tier }, { 0.4, 3 + 1.2 * tier }, { 1, 0.8 } })
		shell.Rate = 8 + 8 * tier
		shell.Size = seq({ { 0, 6 + 2 * tier }, { 0.5, 7.5 + 2.5 * tier }, { 1, 7 + 2 * tier } })
		core.Rate = if tier >= 0.2 then 18 + 20 * tier else 0
		streaks.Rate = if tier >= 0.4 then 8 + 22 * tier else 0
		dust.Rate = if tier >= 0.5 then 3 + 4 * tier else 0
		disc.Rate = if tier >= 0.5 then 1.5 else 0
		light.Brightness = 0.8 + 1.4 * tier
		if tier >= 0.9 and opts.outline ~= false and not outline then
			local h = Instance.new("Highlight")
			h.Name = "AuraOutline"
			h.FillColor = color
			h.FillTransparency = 0.85
			h.OutlineColor = hot
			h.OutlineTransparency = 0.35
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = character
			h.Parent = model
			outline = h
		elseif tier < 0.9 and outline then
			outline:Destroy()
			outline = nil
		end
	end

	-- Electric crackle (tier >= 0.75): 2-3 jagged beams between random points on the body, each
	-- lives 0.08 s. Scripted, so it only runs in a live game (the offline preview won't show it).
	local function crackle()
		local arcs = {}
		for _ = 1, 2 + math.random(0, 1) do
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.CFrame = CFrame.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 4.5, (math.random() - 0.5) * 1.6)
			a1.CFrame = a0.CFrame * CFrame.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, 0)
			a0.Parent, a1.Parent = body, body
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.FaceCamera = true
			beam.Segments = 6
			beam.CurveSize0, beam.CurveSize1 = (math.random() - 0.5) * 3, (math.random() - 0.5) * 3
			beam.Width0, beam.Width1 = 0.18, 0.08
			beam.Color = ColorSequence.new(hot)
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Parent = body
			table.insert(arcs, a0)
			table.insert(arcs, a1)
			table.insert(arcs, beam)
		end
		task.delay(0.08, function()
			for _, inst in arcs do
				inst:Destroy()
			end
		end)
	end
	if isClient() then
		task.spawn(function()
			while alive do
				task.wait(0.18 + math.random() * 0.25)
				if alive and tier >= 0.75 and model.Parent then
					crackle()
				end
			end
		end)
	end

	function self.Charge(_: Aura)
		ring:Emit(1)
		task.delay(0.12, function()
			ring:Emit(1)
		end)
		dust:Emit(24)
		streaks:Emit(20)
		local before = flames.Rate
		flames.Rate = before * 2.2
		flames.Speed = NumberRange.new(6, 10)
		task.delay(0.9, function()
			if alive then
				flames.Rate = before
				flames.Speed = NumberRange.new(3, 6)
			end
		end)
		AnimeFX.Shake(0.35 + 0.35 * tier, 0.4)
	end

	function self.Destroy(_: Aura)
		alive = false
		model:Destroy()
	end

	self:SetTier(opts.tier or 0.5)
	return self :: Aura
end

---------------------------------------------------------------------------------------------------
-- Hits and impacts
---------------------------------------------------------------------------------------------------
-- One pooled rig per colour would be cheaper; a fresh one per hit is fine for a few hits a second.
local function burstAt(position: Vector3): (Part, Attachment)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	local a = Instance.new("Attachment")
	a.Parent = p
	p.Parent = workspace
	return p, a
end

local HIT = {
	Light = { flash = 2.5, ring = 5, sparks = 10, shake = 0, stop = 0.04 },
	Heavy = { flash = 4, ring = 9, sparks = 18, shake = 0.5, stop = 0.07 },
	Finisher = { flash = 6, ring = 14, sparks = 28, shake = 1, stop = 0.1 },
}
AnimeFX.HitSizes = HIT

function AnimeFX.Hit(position: Vector3, color: Color3?, size: string?)
	local s = HIT[size or "Light"] or HIT.Light
	local c = color or Color3.fromRGB(255, 220, 120)
	local p, a = burstAt(position)
	emitter(a, "Flash", {
		Texture = AnimeFX.Textures.glow,
		Speed = NumberRange.new(0),
		Lifetime = NumberRange.new(0.1),
		Size = seq({ { 0, 0 }, { 0.3, s.flash }, { 1, 0 } }),
		Color = colors(WHITE, c),
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 1.5,
		Rate = 0,
	}):Emit(1)
	emitter(a, "Ring", {
		Texture = AnimeFX.Textures.ring,
		Speed = NumberRange.new(0),
		Lifetime = NumberRange.new(0.22),
		Size = seq({ { 0, 0.5 }, { 1, s.ring } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Color = colors(WHITE, c),
		LightEmission = 1,
		Rate = 0,
	}):Emit(1)
	emitter(a, "Sparks", {
		Texture = AnimeFX.Textures.spark,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(28, 45),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 9,
		Lifetime = NumberRange.new(0.15, 0.35),
		Squash = seq({ { 0, 2 }, { 1, 2 } }),
		Size = seq({ { 0, 0.5 }, { 1, 0.1 } }),
		Color = colors(WHITE, c),
		LightEmission = 1,
		Brightness = 2,
		Rate = 0,
	}):Emit(s.sparks)
	if s.shake > 0 then
		AnimeFX.Shake(s.shake, 0.25)
	end
	task.delay(0.6, function()
		p:Destroy()
	end)
end

function AnimeFX.Shockwave(position: Vector3, color: Color3?, radius: number?)
	local r = radius or 12
	local p, a = burstAt(position + Vector3.new(0, 0.1, 0))
	emitter(a, "Wave", {
		Texture = AnimeFX.Textures.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.5),
		Size = seq({ { 0, 1 }, { 1, r * 2 } }),
		Transparency = seq({ { 0, 0.05 }, { 1, 1 } }),
		Color = colors(WHITE, color or WHITE),
		LightEmission = 1,
		Rate = 0,
	}):Emit(1)
	emitter(a, "Dust", {
		Texture = AnimeFX.Textures.smoke,
		Speed = NumberRange.new(r * 0.8, r * 1.4),
		SpreadAngle = Vector2.new(88, 88),
		Drag = 4,
		Lifetime = NumberRange.new(0.6, 1),
		Rotation = NumberRange.new(0, 360),
		Size = seq({ { 0, 1.5 }, { 1, 4 } }),
		Transparency = seq({ { 0, 0.4 }, { 1, 1 } }),
		Color = colors(Color3.fromRGB(230, 220, 205), Color3.fromRGB(190, 180, 165)),
		LightEmission = 0.05,
		LightInfluence = 0.6,
		Rate = 0,
	}):Emit(math.floor(10 + r))
	task.delay(1.2, function()
		p:Destroy()
	end)
end

-- Rocks pop out of the ground in a ring, tilted outward, then sink back after 2.5 s. Colours come
-- from the floor under the hit (a raycast), so it fits any map. Pure parts: no assets.
function AnimeFX.Crater(position: Vector3, radius: number?)
	local r = radius or 6
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0))
	local ground = if hit then hit.Position else position
	local color = if hit and hit.Instance then hit.Instance.Color else Color3.fromRGB(120, 110, 100)
	local material = if hit and hit.Instance then hit.Instance.Material else Enum.Material.Slate
	local ok, TweenService = pcall(function()
		return game:GetService("TweenService")
	end)
	local count = math.clamp(math.floor(r * 1.6), 6, 14)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.3
		local size = (0.35 + math.random() * 0.25) * r
		local rock = Instance.new("Part")
		rock.Anchored, rock.CanCollide, rock.CanQuery, rock.CanTouch = true, false, false, false
		rock.Size = Vector3.new(size, size * 0.7, size * 0.9)
		rock.Color = color:Lerp(Color3.new(), math.random() * 0.15)
		rock.Material = material
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local final = CFrame.lookAt(ground + out * r, ground + out * (r + 1)) * CFrame.Angles(math.rad(-35 - math.random() * 15), 0, math.rad(math.random(-15, 15)))
		rock.CFrame = final * CFrame.new(0, -size, 0)
		rock.Parent = workspace
		if ok then
			TweenService:Create(rock, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final }):Play()
			task.delay(2.5 + math.random() * 0.4, function()
				TweenService:Create(rock, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = final * CFrame.new(0, -size * 1.2, 0) }):Play()
			end)
		else
			rock.CFrame = final
		end
		task.delay(3.6, function()
			rock:Destroy()
		end)
	end
	AnimeFX.Shockwave(ground, nil, r * 1.6)
end

---------------------------------------------------------------------------------------------------
-- Screen and timing (client only)
---------------------------------------------------------------------------------------------------
local lastImpactFrame = -math.huge

-- The anime "impact frame": the world drops to black and white with hard contrast for one beat.
-- Kid-safe: at most one a second, skipped when Flashes is off, never pure white. Save it for
-- finishers and ultimates; on every hit it stops meaning anything.
function AnimeFX.ImpactFrame(seconds: number?): boolean
	local now = os.clock()
	if now - lastImpactFrame < 1 or not settingOn("Flashes") then
		return false
	end
	lastImpactFrame = now
	local lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AnimeImpactFrame"
	cc.Saturation = -1
	cc.Contrast = 2.5
	cc.Brightness = -0.05
	cc.Parent = lighting
	task.delay(seconds or 0.07, function()
		cc:Destroy()
	end)
	return true
end

-- Camera shake: random offsets that fade out, applied after the camera updates. Skipped when the
-- player turned ScreenShake off. strength ~0.3 (light) .. 1 (finisher), in studs at the camera.
local shakeUntil, shakeStrength, shakeLength, shakeBound = 0, 0, 0, false
function AnimeFX.Shake(strength: number, seconds: number)
	if not settingOn("ScreenShake") then
		return
	end
	if not isClient() then
		return
	end
	local RunService = game:GetService("RunService")
	local now = os.clock()
	local running = shakeStrength * math.max(0, (shakeUntil - now) / math.max(shakeLength, 0.01))
	if running > strength then
		return -- a bigger shake is still running
	end
	shakeUntil, shakeStrength, shakeLength = now + seconds, strength, seconds
	if shakeBound then
		return
	end
	shakeBound = true
	RunService:BindToRenderStep("AnimeFXShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			RunService:UnbindFromRenderStep("AnimeFXShake")
			shakeBound = false
			return
		end
		local amount = shakeStrength * (left / shakeLength) * 0.25
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
	end)
end

-- Freeze an attack on its contact frame (hit-stop). Light 0.04, heavy 0.07, finisher 0.1 s.
function AnimeFX.HitStop(track: AnimationTrack, seconds: number)
	local speed = track.Speed
	track:AdjustSpeed(0)
	task.delay(seconds, function()
		if track.IsPlaying then
			track:AdjustSpeed(if speed > 0 then speed else 1)
		end
	end)
end

-- Radial speed lines from the screen edges toward the centre (dashes, charge-ups). Plain white
-- frames, no texture. 24 lines that shoot inward and fade over `duration` (default 0.35 s).
function AnimeFX.SpeedLines(duration: number?)
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	local TweenService = game:GetService("TweenService")
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnimeSpeedLines"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local t = duration or 0.35
	for i = 1, 24 do
		local angle = (i / 24) * 360 + math.random(-6, 6)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(1.6, 0)
		holder.BackgroundTransparency = 1
		holder.Rotation = angle
		holder.Parent = gui
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = WHITE
		line.BackgroundTransparency = 0.35
		line.AnchorPoint = Vector2.new(1, 0.5)
		line.Size = UDim2.new(0.18 + math.random() * 0.12, 0, 0, math.random(2, 4))
		line.Position = UDim2.fromScale(1, 0)
		line.Parent = holder
		TweenService:Create(line, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.82, 0),
			BackgroundTransparency = 1,
		}):Play()
	end
	gui.Parent = lp:WaitForChild("PlayerGui")
	task.delay(t + 0.05, function()
		gui:Destroy()
	end)
end

return AnimeFX
