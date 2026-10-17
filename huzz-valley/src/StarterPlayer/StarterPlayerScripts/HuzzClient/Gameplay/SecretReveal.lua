--[[
	The Secret girl's arrival cutscene, on every screen (the timing and the camera: Shared/SecretReveal). The
	server sets the Round stage "Reveal" and stamps RevealAt on the big girl over the map (HuzzShowcase); this
	builds the effects locally and drives her and the camera from one timeline (docs/vfx-guide.md 4.1, 6.3):
	  build-up  a growing orb (neon core in an energy shell), sparks rushing in, four lights circling it faster
	            and faster on trails, a pillar of light, night on this screen under a violet grade (Shared/SecretReveal
	            .clock: set on the first frame's camera cut; the sun rises again with her), the camera pushing in
	  impact    a hit-stop, then a star burst, flying sparks, a shock ring in the air and one on the ground; she
	            appears as a white silhouette that melts into her colours; one soft brightness pulse (the only
	            flash, kid-safe), a camera kick and shake
	  landing   a ring and an energy dome burst along the ground, dust; a slow low orbit round her
	  rise      she floats up to her place over the map, the camera following, then it eases back to you
	Reduced Motion (Settings): no shake, no kick, no brightness pulse. No black bars (owner).
	Pictures: Shared/FxTexture (our anime set once uploaded; Roblox's stand-ins until then).
]]
local M = {}

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local Reveal = require(Shared.SecretReveal)
local FxTexture = require(Shared.FxTexture)
local Motion = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local Sfx = require(script.Parent.Sfx)
local player = Players.LocalPlayer

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local VIOLET, CYAN, PINK, DEEP = rgb(150, 110, 255), rgb(110, 235, 255), rgb(255, 120, 210), rgb(60, 20, 120)

local function seq(...)
	local list = { ... }
	local keys = {}
	for i, c in list do keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(#list - 1, 1), c) end
	return ColorSequence.new(keys)
end
local function nseq(list)
	local keys = {}
	for i, k in list do keys[i] = NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0) end
	return NumberSequence.new(keys)
end
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Rate = 0
	for k, v in props do
		if k == "Picture" then
			FxTexture.flipbook(e, v[1], v[2], v[3])
		else
			e[k] = v
		end
	end
	e.Parent = parent
	return e
end

-- Everything for one play of the cutscene; returns step(t) and cleanup().
function M.build(model: Model, base: CFrame)
	local k = (Config.Showcase.Scale or 3) / 3
	local spot = base.Position - Vector3.new(0, Config.Showcase.Height, 0) -- (her pivot when she stands on the floor)
	local box, size = model:GetBoundingBox() -- (she's still at `base` here)
	-- the floor under her: her box's bottom when she stands (her pivot is her root part, not her middle)
	local ground = Vector3.new(spot.X, box.Position.Y - size.Y / 2 - Config.Showcase.Height, spot.Z)
	local orbAt = ground + Vector3.new(0, Reveal.ORB_HEIGHT * k + size.Y * 0.5, 0) -- the orb is where her middle appears
	local folder = Instance.new("Folder")
	folder.Name = "HuzzSecretReveal"
	folder.Parent = Workspace

	-- the orb: a neon core inside an energy shell, sparks sucked in, four lights circling on trails
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.one * 0.5, CFrame = CFrame.new(orbAt) }, folder)
	local shell = part({ Name = "Shell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = VIOLET, Size = Vector3.one * 0.6, CFrame = CFrame.new(orbAt) }, folder)
	-- (sparks start on a sphere round the orb and die as they reach its middle: on the small shell they shot
	-- straight through it and out the far side)
	local rushBall = part({ Name = "Rush", Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one * 12 * k, CFrame = CFrame.new(orbAt) }, folder)
	local rush = emitter(rushBall, {
		Picture = { "Spark" }, Color = seq(WHITE, CYAN, VIOLET), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = nseq({ { 0, 0.5 }, { 1, 0.15 } }), Squash = nseq({ { 0, 1 }, { 1, 2.5 } }),
		Transparency = nseq({ { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0 }, { 1, 1 } }), Lifetime = NumberRange.new(0.3, 0.36),
		Speed = NumberRange.new(16 * k, 19 * k),
	})
	local orbiters = {}
	for i = 1, 4 do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = core, core
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		if FxTexture.ready("Streak") then
			tr.Texture = FxTexture.get("Streak")
			tr.TextureMode = Enum.TextureMode.Stretch
		end
		tr.Color = seq(WHITE, if i % 2 == 0 then CYAN else PINK, DEEP)
		tr.Transparency = nseq({ { 0, 0 }, { 1, 1 } })
		tr.WidthScale = nseq({ { 0, 1 }, { 1, 0 } })
		tr.Lifetime = 0.3
		tr.LightEmission, tr.LightInfluence = 1, 0
		tr.FaceCamera = true
		tr.Parent = core
		table.insert(orbiters, { a0 = a0, a1 = a1, phase = (i - 1) * math.pi / 2, tilt = math.rad((i - 2.5) * 25) })
	end
	-- the pillar: three beams up from the ground (a white core, a coloured rim, rising streaks)
	local base0 = Instance.new("Attachment"); base0.WorldPosition = ground; base0.Parent = Workspace.Terrain
	local top0 = Instance.new("Attachment"); top0.WorldPosition = ground + Vector3.new(0, 90, 0); top0.Parent = Workspace.Terrain
	local pillar = {}
	for _, def in { { WHITE, 2.2 * k, 1, "BeamGlow", 0 }, { VIOLET, 6 * k, 0.6, "BeamGlow", 0 }, { rgb(225, 130, 255), 4 * k, 1, "BeamGlow", 0 } } do -- (all soft glow, magenta-violet like the reference: no stripes)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = base0, top0
		b.Color = ColorSequence.new(def[1])
		b.LightEmission, b.LightInfluence = def[3], 0
		b.Texture = if FxTexture.ready(def[4]) then FxTexture.get(def[4]) else "" -- (solid light until uploaded)
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 8
		b.TextureSpeed = def[5]
		b.FaceCamera = true
		b.Segments = 2
		b.Width0, b.Width1 = 0, 0
		b.Parent = Workspace.Terrain
		table.insert(pillar, { beam = b, width = def[2] })
	end

	-- The owner's Oct 17 reference (design/vfx/ref3): two tall beams of light close either side of the orb (a white
	-- core in a wide violet glow, both leaning the same way and bowing a little outwards), bright lines slashing
	-- across between them, then two glowing eyes opening in the dark where she'll appear. Placed every frame from
	-- the camera's side. Framing checked with tools/preview/secret_sketch.py.
	local anchors = {}
	local function anchor()
		local a = Instance.new("Attachment")
		a.Parent = Workspace.Terrain
		table.insert(anchors, a)
		return a
	end
	local beams = {}
	local function lightBeam(a0, a1, color, light, texture, speed)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = ColorSequence.new(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Texture = if FxTexture.ready(texture) then FxTexture.get(texture) else "" -- (solid light until uploaded)
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 8
		b.TextureSpeed = speed
		b.FaceCamera = true
		b.Segments = 24
		b.Width0, b.Width1 = 0, 0
		b.Parent = Workspace.Terrain
		table.insert(beams, b)
		return b
	end
	local crescents = {}
	for _, side in { -1, 1 } do
		local a0, a1 = anchor(), anchor()
		table.insert(crescents, { side = side, a0 = a0, a1 = a1, glow = lightBeam(a0, a1, rgb(190, 70, 255), 0.75, "BeamGlow", 0), core = lightBeam(a0, a1, rgb(255, 225, 250), 1, "BeamGlow", 0) })
	end
	local SLASH = rgb(255, 70, 150)
	local slashes = {}
	for i, at in Reveal.SLASHES do
		local a0, a1 = anchor(), anchor()
		local sl = { at = at, i = i, a0 = a0, a1 = a1, glow = lightBeam(a0, a1, SLASH, 0.8, "BeamGlow", 0), core = lightBeam(a0, a1, WHITE, 1, "BeamGlow", 0) }
		for _, b in { sl.glow, sl.core } do -- (pointed ends: a beam can only taper one way, so its ends fade out)
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) })
		end
		table.insert(slashes, sl)
	end
	for _, c in crescents do c.glow.Transparency = NumberSequence.new(0.25) end
	local eyeAt = orbAt + Vector3.new(0, size.Y * 0.28, 0)
	local eyeGap = math.max(size.X * 0.2, 1.6 * k)
	local EYE_W = 3.2
	local eyes = {}
	for _, side in { -1, 1 } do
		local eye = part({ Name = "Eye", Material = Enum.Material.Neon, Color = PINK, Size = Vector3.new(EYE_W * k, 0.6 * k, 0.3 * k), Transparency = 1 }, folder)
		local flare = part({ Name = "Flare", Material = Enum.Material.Neon, Color = rgb(255, 160, 225), Size = Vector3.one * 0.05, Transparency = 1 }, folder)
		table.insert(eyes, { side = side, eye = eye, flare = flare })
	end

	-- the impact frame: a split second of pink manga lines bursting in from the edges on deep violet (not white: the
	-- reference's impact is pink on dark, and it's gentler on the eyes). Reduced Motion: none.
	local frameGui = Instance.new("ScreenGui")
	frameGui.Name, frameGui.IgnoreGuiInset, frameGui.DisplayOrder, frameGui.Enabled, frameGui.ResetOnSpawn = "HuzzImpactFrame", true, 60, false, false
	local paper = Instance.new("Frame")
	paper.Size, paper.BackgroundColor3, paper.BorderSizePixel = UDim2.fromScale(1, 1), rgb(34, 10, 58), 0
	paper.Parent = frameGui
	local burst = Instance.new("Frame")
	burst.AnchorPoint, burst.Position, burst.Size, burst.BackgroundTransparency = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(2400, 2400), 1
	burst.Parent = paper
	local rnd = Random.new(7)
	for i = 1, 26 do
		local a = (i - 1) / 26 * 360 + rnd:NextNumber(-5, 5)
		local w = rnd:NextInteger(8, 46)
		local len = rnd:NextInteger(820, 1180)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.fromOffset(w, len)
		line.Rotation = a
		local r = 1200 - len / 2 -- (from the outer edge inwards; its centre sits this far out)
		line.Position = UDim2.fromOffset(math.round(1200 + math.sin(math.rad(a)) * r), math.round(1200 - math.cos(math.rad(a)) * r))
		line.BackgroundColor3, line.BorderSizePixel = rgb(255, 150, 215), 0
		local fade = Instance.new("UIGradient") -- (solid at the screen's edge, gone before the middle)
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.1), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = line
		line.Parent = burst
	end
	frameGui.Parent = if player then player:WaitForChild("PlayerGui") else nil

	-- the impact: one emitter part at the orb, one on the ground
	local blast = part({ Name = "Blast", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(orbAt) }, folder)
	local star = emitter(blast, { Picture = { "BurstStar", "Random" }, Color = seq(WHITE, PINK), LightEmission = 1, Brightness = 2,
		Size = nseq({ { 0, 0 }, { 0.2, 14 * k }, { 1, 16 * k } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.05 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), ZOffset = 2 })
	local sparks = emitter(blast, { Picture = { "Spark" }, Color = seq(WHITE, CYAN, VIOLET), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({ { 0, 0.8 * k }, { 1, 0.2 } }),
		Squash = nseq({ { 0, 0 }, { 0.3, 2 }, { 1, 2.5 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(25 * k, 45 * k), Drag = 6, SpreadAngle = Vector2.new(180, 180) })
	local shock = emitter(blast, { Picture = { "ShockSheet", "OneShot" }, Color = seq(WHITE, CYAN), LightEmission = 1,
		Size = nseq({ { 0, 6 * k }, { 1, 18 * k } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(0), ZOffset = 1 })
	local shards = emitter(blast, { Picture = { "Shard" }, Color = seq(WHITE, PINK, CYAN), LightEmission = 1, Brightness = 1.6,
		Size = nseq({ { 0, 1.4 * k }, { 1, 0.4 * k } }), Transparency = nseq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(20 * k, 40 * k), Drag = 3, SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Acceleration = Vector3.new(0, -6 * k, 0) })
	local streaks = emitter(blast, { Picture = { "Streak" }, Color = seq(WHITE, PINK, VIOLET), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({ { 0, 1.2 * k }, { 1, 0.3 * k } }),
		Squash = nseq({ { 0, 3 }, { 1, 4 } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(70 * k, 110 * k), SpreadAngle = Vector2.new(180, 180) })
	local floor = part({ Name = "Floor", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) }, folder)
	local flat = { Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), SpreadAngle = Vector2.zero }
	local function flatEmitter(props)
		for kk, v in flat do props[kk] = v end
		return emitter(floor, props)
	end
	local groundRing = flatEmitter({ Picture = { "RingHard" }, Color = seq(WHITE, CYAN), LightEmission = 1, Brightness = 1.5,
		Size = nseq({ { 0, 2 * k }, { 0.15, 14 * k }, { 0.45, 22 * k }, { 1, 26 * k } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5) })
	local landRing = flatEmitter({ Picture = { "RingSoft" }, Color = seq(WHITE, PINK, VIOLET), LightEmission = 1, Brightness = 1.5,
		Size = nseq({ { 0, 3 * k }, { 0.15, 11 * k }, { 0.45, 16 * k }, { 1, 18 * k } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5) })
	-- one sigil from the build-up to the landing (a new one every 0.8 s drew two at once, turning against each other)
	local sigilLife = Reveal.LAND + 0.3 - (Reveal.BUILD - 0.1)
	local sigil = flatEmitter({ Picture = { "Sigil" }, Color = seq(WHITE, VIOLET), LightEmission = 1, Brightness = 1.3,
		Size = nseq({ { 0, 13 * k }, { 1, 15 * k } }), Transparency = nseq({ { 0, 1 }, { 0.12, 0.3 }, { 0.88, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(sigilLife), RotSpeed = NumberRange.new(28), Rotation = NumberRange.new(0, 360), LockedToPart = true })
	local dust = emitter(floor, { Picture = { "Wisp" }, Color = seq(rgb(220, 210, 255), rgb(120, 110, 160)), LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapePartial = 1,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Size = nseq({ { 0, 2 * k }, { 1, 5 * k } }),
		Transparency = nseq({ { 0, 0.4 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(14 * k, 22 * k), Drag = 4 })
	local butterflies = emitter(floor, { Picture = { "Butterfly", "Loop", 14 }, Color = seq(rgb(160, 215, 255), rgb(110, 160, 255)),
		LightEmission = 0.6, Brightness = 1.4, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = nseq({ { 0, 0 }, { 0.1, 2.2 * k }, { 0.85, 2.2 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(2, 2.5), Speed = NumberRange.new(2 * k, 4 * k), Acceleration = Vector3.new(0, 1.5 * k, 0),
		SpreadAngle = Vector2.new(60, 60), Rotation = NumberRange.new(-25, 25), RotSpeed = NumberRange.new(-20, 20), Drag = 0.5 })
	floor.Size = Vector3.new(6 * k, 0.2, 6 * k)
	local dome = part({ Name = "Dome", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = PINK, Size = Vector3.one * 2, CFrame = CFrame.new(ground), Transparency = 1 }, folder)
	local hiStroke = Instance.new("Highlight")
	hiStroke.FillColor, hiStroke.OutlineColor = WHITE, WHITE
	hiStroke.FillTransparency, hiStroke.OutlineTransparency = 1, 1
	hiStroke.DepthMode = Enum.HighlightDepthMode.Occluded
	hiStroke.Adornee = model
	hiStroke.Parent = folder

	-- the grade (our own, on top of the game's look)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HuzzSecretGrade"
	grade.Parent = Lighting
	-- and night on this screen until she rises (Shared/SecretReveal.clock), the game's own time after
	local day = Lighting.ClockTime

	local all = { rush, star, sparks, shock, groundRing, landRing, sigil, dust, shards, streaks, butterflies }
	local fired = {}
	local function once(name, fn)
		if not fired[name] then fired[name] = true; fn() end
	end

	local function step(t: number, dir: Vector3)
		local calm = Motion.reduced
		-- hit-stop: every emitter nearly frozen for a split second
		local stop = t >= Reveal.HOLD and t < Reveal.IMPACT
		for _, e in all do e.TimeScale = if stop then 0.05 else 1 end
		-- the orb
		local orbSize, spin = Reveal.orb(t)
		core.Transparency = if orbSize > 0 then 0 else 1
		shell.Transparency = if orbSize > 0 then 0.2 else 1
		core.Size = Vector3.one * math.max(orbSize, 0.05) * k
		shell.Size = Vector3.one * math.max(orbSize * 1.25, 0.05) * k
		rush.Rate = if orbSize > 0 and not stop then 40 + 50 * (orbSize / Reveal.ORB_MAX) else 0
		for _, o in orbiters do
			local a = t * spin + o.phase
			local r = (5 - 2.5 * math.min(1, orbSize / Reveal.ORB_MAX)) * k
			local off = CFrame.Angles(o.tilt, 0, 0):VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			o.a0.WorldPosition = orbAt + off + Vector3.new(0, 0.18, 0)
			o.a1.WorldPosition = orbAt + off - Vector3.new(0, 0.18, 0)
		end
		-- the pillar: grows during the build-up, makes way for the crescents (the gap between them stays dark, like the
		-- reference), comes back with the impact and thins out after the landing
		local pw = if t < Reveal.IMPACT then math.clamp((t - Reveal.BUILD) / 1.2, 0, 1) * (1 - math.clamp((t - Reveal.CRESCENTS) / 0.4, 0, 1)) else 1 - math.clamp((t - Reveal.LAND) / 1.6, 0, 1)
		for _, p in pillar do p.beam.Width0, p.beam.Width1 = p.width * pw, p.width * pw * 0.7 end
		if t >= Reveal.BUILD - 0.1 then
			once("sigil", function()
				if FxTexture.ready("Sigil") then sigil:Emit(1) end
				Sfx.play("secret_riser") -- (ends in silence right before the impact: the hit sounds louder)
			end)
		end
		-- the crescents, the slashes and the eyes (from the camera's side: `dir` points from the spot to the camera)
		local up = Vector3.new(0, 1, 0)
		local side = dir:Cross(up)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
		local grow = math.clamp((t - Reveal.CRESCENTS) / 0.45, 0, 1)
		local cw = (1 - (1 - grow) ^ 3) * (1 - math.clamp((t - Reveal.LAND) / 1.2, 0, 1))
		local tall = 46 * k * math.max(grow, 0.02)
		for _, c in crescents do
			local out = side * c.side
			local foot = ground + out * 4.6 * k
			local lean = math.rad(12)
			-- a beam bends towards its attachments' X axes: both lean outwards at the ends, so it bows outwards
			c.a0.WorldCFrame = CFrame.fromMatrix(foot, up * math.cos(lean) + out * math.sin(lean), dir)
			c.a1.WorldCFrame = CFrame.fromMatrix(foot + up * tall - side * 0.04 * tall, up * math.cos(lean) - out * math.sin(lean), dir)
			for _, b in { c.glow, c.core } do b.CurveSize0, b.CurveSize1 = tall * 0.3, tall * 0.3 end
			c.glow.Width0, c.glow.Width1 = 8 * k * cw, 4 * k * cw
			c.core.Width0, c.core.Width1 = 1.8 * k * cw, 0.9 * k * cw
		end
		local heights = { 2.5, -1.5, 4.2, -3.2 }
		for _, sl in slashes do
			local v = Reveal.slash(t, sl.at)
			local flip = if sl.i % 2 == 0 then -1 else 1
			local mid = orbAt + up * heights[sl.i] * k + side * math.max(0, t - sl.at) * 30 * k * flip
			sl.a0.WorldPosition = mid - side * 24 * k + up * 4 * k * flip
			sl.a1.WorldPosition = mid + side * 24 * k - up * 4 * k * flip
			sl.glow.Width0, sl.glow.Width1 = 2.6 * k * v, 2.6 * k * v
			sl.core.Width0, sl.core.Width1 = 0.5 * k * v, 0.5 * k * v
		end
		local ev = if t >= Reveal.EYES and t < Reveal.IMPACT then math.clamp((t - Reveal.EYES) / 0.25, 0, 1) else 0
		for _, e in eyes do
			local p = eyeAt + side * e.side * eyeGap
			-- slanted slits (inner ends lower, a fierce look), opening from a line
			e.eye.CFrame = CFrame.fromMatrix(p, side, up) * CFrame.Angles(0, 0, math.rad(-14 * e.side))
			e.eye.Size = Vector3.new(EYE_W * k, math.max(0.6 * k * ev, 0.05), 0.3 * k)
			e.eye.Transparency = 1 - ev
			e.flare.CFrame = CFrame.fromMatrix(p, side, up)
			e.flare.Size = Vector3.new(math.max(8 * k * ev, 0.05), 0.22 * k, 0.22 * k)
			e.flare.Transparency = 1 - 0.9 * ev
		end
		frameGui.Enabled = Reveal.impactFrame(t, calm)
		-- the impact
		if t >= Reveal.IMPACT then
			once("impact", function()
				star:Emit(1)
				sparks:Emit(24)
				-- (the rings are our own pictures: they wait for the upload rather than show a sparkle blob)
				if FxTexture.ready("ShockSheet") then shock:Emit(1) end
				if FxTexture.ready("RingHard") then groundRing:Emit(1) end
				if FxTexture.ready("Shard") then shards:Emit(28) end
				if FxTexture.ready("Streak") then streaks:Emit(30) end
				hiStroke.FillTransparency, hiStroke.OutlineTransparency = 0, 0
				Sfx.play("secret_impact")
			end)
			local x = math.clamp((t - Reveal.IMPACT - 0.1) / 0.35, 0, 1)
			hiStroke.FillTransparency = x
			hiStroke.OutlineTransparency = 0.3 + 0.7 * x
		end
		if t >= Reveal.LAND then
			once("land", function()
				if FxTexture.ready("RingSoft") then landRing:Emit(1) end
				dust:Emit(14)
				butterflies.Rate = if FxTexture.ready("Butterfly") then 4 else 0
				Sfx.play("secret_land")
			end)
			local x = math.clamp((t - Reveal.LAND) / 0.45, 0, 1)
			dome.Size = Vector3.one * (2 + 12 * (1 - (1 - x) ^ 3)) * k
			dome.Transparency = if x >= 1 then 1 else 0.2 + 0.8 * x
		end
		if t >= Reveal.RISE then butterflies.Rate = 0 end -- (the last ones fade out before the cutscene ends)
		-- her: hidden until the impact, then dropping, standing, rising (facing the camera, then turning slowly)
		local h = Reveal.height(t, Config.Showcase.Height)
		if h then
			local yaw = math.max(0, t - Reveal.RISE) * (Config.Showcase.Spin or 0.35)
			local face = CFrame.lookAt(Vector3.zero, Vector3.new(dir.X, 0, dir.Z)).Rotation
			model:PivotTo(CFrame.new(spot + Vector3.new(0, h * k, 0)) * face * CFrame.Angles(0, yaw, 0))
		else
			model:PivotTo(base * CFrame.new(0, -2000, 0))
		end
		-- the world's colour
		local b, s, tint, pulse, contrast = Reveal.grade(t)
		grade.Brightness = b + (if calm then 0 else 0.12 * pulse)
		grade.Saturation = s
		grade.Contrast = contrast
		grade.TintColor = WHITE:Lerp(rgb(200, 170, 255), tint)
		Lighting.ClockTime = Reveal.clock(t, day)
		return orbAt, h
	end

	local function cleanup()
		Lighting.ClockTime = day
		folder:Destroy()
		grade:Destroy()
		frameGui:Destroy()
		for _, b in beams do b:Destroy() end
		for _, a in anchors do a:Destroy() end
		base0:Destroy()
		top0:Destroy()
		for _, p in pillar do p.beam:Destroy() end
	end
	return step, cleanup, ground, k, size.Y / 2
end

function M.start()
	local playing = false
	local function play(model: Model)
		if playing then return end
		local at = model:GetAttribute("RevealAt")
		local base = model:GetAttribute("Base")
		if type(at) ~= "number" or typeof(base) ~= "CFrame" then return end
		if Workspace:GetServerTimeNow() - at > Reveal.RETURN then return end -- (joined late: she's already up there)
		playing = true
		model:SetAttribute("HuzzRevealing", true) -- (Gameplay/CarryAnimator leaves her to us meanwhile)
		local ok, step, cleanup, ground, k, mid = pcall(M.build, model, base)
		if not ok then
			warn("[Huzz] Secret reveal couldn't start: " .. tostring(step))
			model:SetAttribute("HuzzRevealing", nil)
			playing = false
			return
		end
		local camera = Workspace.CurrentCamera
		player:SetAttribute("HuzzCinematic", true)
		RunService.RenderStepped:Wait() -- (Gameplay/Feel hands back its sprint widening first, so it isn't kept for good)
		local startCF, startFov = camera.CFrame, camera.FieldOfView
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local from = if root then root.Position - ground else Vector3.new(0, 0, 1)
		local dir = Vector3.new(from.X, 0, from.Z)
		dir = if dir.Magnitude > 1 then dir.Unit else Vector3.new(0, 0, 1)
		player:SetAttribute("HuzzCinematic", true)
		camera.CameraType = Enum.CameraType.Scriptable
		local noise = math.random() * 100
		local function finish()
			RunService:UnbindFromRenderStep("HuzzSecretReveal")
			pcall(cleanup)
			model:SetAttribute("HuzzRevealing", nil)
			camera.FieldOfView = startFov
			camera.CameraType = Enum.CameraType.Custom
			player:SetAttribute("HuzzCinematic", false)
			playing = false
		end
		RunService:BindToRenderStep("HuzzSecretReveal", Enum.RenderPriority.Camera.Value + 3, function()
			local t = Workspace:GetServerTimeNow() - at
			if t > Reveal.LENGTH or not model.Parent then
				finish()
				return
			end
			local okStep, err = pcall(function()
				local _, h = step(t, dir)
				local eye, look = Reveal.camera(math.min(t, Reveal.RETURN), ground + Vector3.new(0, 0.5, 0), dir, h or Config.Showcase.Height, k, mid)
				local cf = CFrame.lookAt(eye, look)
				local fov = Reveal.fov(t, Motion.reduced)
				if t > Reveal.RETURN then -- ease back to where your camera was
					local x = math.clamp((t - Reveal.RETURN) / (Reveal.LENGTH - Reveal.RETURN), 0, 1)
					x = 1 - (1 - x) ^ 3
					cf = cf:Lerp(startCF, x)
					fov = fov + (startFov - fov) * x
				end
				local shake = if Motion.reduced then 0 else Reveal.shake(t)
				if shake > 0 then
					local n = t * 12
					cf = cf * CFrame.Angles(math.noise(n, noise) * shake * 0.12, math.noise(noise, n) * shake * 0.12, math.noise(n, n + noise) * shake * 0.06)
						+ Vector3.new(math.noise(n + 3, noise), math.noise(noise, n + 3), 0) * shake
				end
				camera.CFrame = cf
				camera.FieldOfView = fov
			end)
			if not okStep then
				warn("[Huzz] Secret reveal stopped: " .. tostring(err))
				finish()
			end
		end)
	end

	local function watch(model: Instance)
		if not model:IsA("Model") then return end
		if model:GetAttribute("RevealAt") then task.defer(play, model) end
		model:GetAttributeChangedSignal("RevealAt"):Connect(function() play(model) end)
	end
	local CollectionService = game:GetService("CollectionService")
	CollectionService:GetInstanceAddedSignal("HuzzShowcase"):Connect(watch)
	for _, m in CollectionService:GetTagged("HuzzShowcase") do watch(m) end
end

return M
