--[[
	The Secret girl's arrival cutscene, on every screen (the timing, shots and camera: Shared/SecretReveal; the owner's
	Oct 17 reference shot by shot: design/vfx/ref3, beat sheet docs/secret-beats.md; owner: "make the cutscene look
	one to one as the reference"). The server sets the Round stage "Reveal" and stamps RevealAt on the big girl over
	the map (HuzzShowcase); this builds the effects locally and drives her and the camera from one timeline:
	  the night   your Lighting, on this screen only, from the first frame's camera cut until she rises: midnight,
	              a purple Atmosphere (the sky itself turns purple, no pictures needed), a stronger Bloom (neon and
	              beams glow), more stars, purple ambient light, a violet grade; all put back exactly afterwards
	  all along   purple and cyan motes, drifting crystals, nebula haze in the sky, purple smoke on the ground,
	              a few butterflies (they make the scene full, like the reference)
	  build-up    a small orb, sparks rushing in; twin beams strike down (wide haze, magenta glow, a crackling white
	              core that shimmers a few times a second, never strobes); ladder blocks climb the first; red-pink
	              slashes; two big glowing eyes with a halo and a glint line
	  impact      hit-stop, a split-second manga frame, light rays and four-point sparkles, a star burst, sparks,
	              shards, streaks, rings; she appears in white, drops and lands (a ring, a dome, smoke)
	  after       crescent slashes round her, a star flare, speed streaks rushing past, an eye glint, red streak
	              lines, a butterfly swarm, a crackling flare, then the burst (rays, a pink cloud) and she rises
	Flashes: soft pulses only at the impact, the swell and the burst (more than a second apart; kid-safe).
	Reduced Motion (Settings): no shake, kicks, impact frame, pulses or crackle. No black bars (owner).
	Pictures: Shared/FxTexture (our set once uploaded; until then beams are solid light and particles use Roblox's
	built-in sparkle and smoke). Filmed offline: tools/preview/motion3d/secret_scene.luau.
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
local HAZE, MAGENTA, CORE = rgb(120, 40, 220), rgb(200, 70, 255), rgb(255, 228, 252)
local SLASH, RED = rgb(255, 40, 95), rgb(255, 45, 100)

-- The night look (Lighting, on this screen only), blended in by Shared/SecretReveal.night.
local NIGHT_LOOK = {
	Lighting = { Ambient = rgb(34, 28, 62), OutdoorAmbient = rgb(48, 40, 92), Brightness = 1.2 },
	Atmosphere = { Density = 0.42, Offset = 0.2, Color = rgb(70, 48, 140), Decay = rgb(24, 18, 70), Glare = 0, Haze = 2.4 },
	BloomEffect = { Intensity = 1.3, Size = 40, Threshold = 0.9 },
	SunRaysEffect = { Intensity = 0 },
	Sky = { StarCount = 5000 },
}

local function seq(...)
	local list = { ... }
	local keys = {}
	for i, c in list do keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(#list - 1, 1), c) end
	return ColorSequence.new(keys)
end
local function nseq(list)
	local keys = {}
	for i, kp in list do keys[i] = NumberSequenceKeypoint.new(kp[1], kp[2], kp[3] or 0) end
	return NumberSequence.new(keys)
end
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, v in props do p[key] = v end
	p.Parent = parent
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Rate = 0
	for key, v in props do
		if key == "Picture" then
			FxTexture.flipbook(e, v[1], v[2], v[3])
		else
			e[key] = v
		end
	end
	e.Parent = parent
	return e
end
local function lerp(a, b, x)
	if typeof(a) == "number" then return a + (b - a) * x end
	return a:Lerp(b, x)
end

-- Everything for one play of the cutscene; returns step(t, dir, cam?) and cleanup(). `junk` collects every
-- instance made, so a failed build can remove them all (M.build). Lighting's own values are only changed by step.
local function build(model: Model, base: CFrame, revealAt: number, junk: { Instance })
	local k = (Config.Showcase.Scale or 3) / 3
	local spot = base.Position - Vector3.new(0, Config.Showcase.Height, 0) -- (her pivot when she stands on the floor)
	local box, size = model:GetBoundingBox() -- (she's still at `base` here)
	-- the floor under her: her box's bottom when she stands (her pivot is her root part, not her middle)
	local ground = Vector3.new(spot.X, box.Position.Y - size.Y / 2 - Config.Showcase.Height, spot.Z)
	local mid = size.Y / 2
	local orbAt = ground + Vector3.new(0, Reveal.ORB_HEIGHT * k + mid, 0) -- the orb is where her middle appears
	local folder = Instance.new("Folder")
	folder.Name = "HuzzSecretReveal"
	folder.Parent = Workspace
	table.insert(junk, folder)
	local up = Vector3.new(0, 1, 0)
	local rnd = Random.new(11)

	-- the night: remember every Lighting value we touch, make what's missing (and remove it after)
	local saved, made = {}, {}
	local function keep(inst: Instance, props)
		for key, target in props do
			local ok, was = pcall(function() return (inst :: any)[key] end)
			if ok and was ~= nil then table.insert(saved, { inst = inst, key = key, was = was, target = target }) end
		end
	end
	keep(Lighting, NIGHT_LOOK.Lighting)
	for _, cls in { "Atmosphere", "BloomEffect", "SunRaysEffect", "Sky" } do
		local inst = Lighting:FindFirstChildOfClass(cls)
		if not inst and cls ~= "SunRaysEffect" then
			inst = Instance.new(cls)
			inst.Name = "HuzzSecret" .. cls
			-- (a new one starts from nothing and fades in with the night, and back out: no sudden haze)
			if cls == "Atmosphere" then (inst :: any).Density, (inst :: any).Haze, (inst :: any).Glare = 0, 0, 0 end
			if cls == "BloomEffect" then (inst :: any).Intensity = 0 end
			table.insert(made, inst)
			table.insert(junk, inst)
		end
		if inst then keep(inst, NIGHT_LOOK[cls]) end
	end
	local day = Lighting.ClockTime

	-- beams: solid light until our pictures are uploaded
	local anchors, beams = {}, {}
	local function anchor()
		local a = Instance.new("Attachment")
		a.Parent = Workspace.Terrain
		table.insert(anchors, a)
		table.insert(junk, a)
		return a
	end
	local function beam(a0, a1, color, light, texture, props)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Texture = if texture and FxTexture.ready(texture) then FxTexture.get(texture) else ""
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 8
		b.FaceCamera = true
		b.Segments = 24
		b.Width0, b.Width1 = 0, 0
		for key, v in props or {} do b[key] = v end
		b.Parent = Workspace.Terrain
		table.insert(beams, b)
		table.insert(junk, b)
		return b
	end
	local ENDS = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1) })
	local TAPER = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 1) })
	local function setWidth(b, w0, w1)
		b.Width0, b.Width1 = math.max(w0, 0), math.max(w1 or w0, 0)
	end

	-- the orb: a neon core inside an energy shell, sparks rushing in from a sphere round it, four lights circling
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = WHITE, Size = Vector3.one * 0.5, CFrame = CFrame.new(orbAt) }, folder)
	local shell = part({ Name = "Shell", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = VIOLET, Size = Vector3.one * 0.6, CFrame = CFrame.new(orbAt) }, folder)
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

	-- the twin beams (the reference's 0.75-2.75 s): a wide soft haze, a magenta glow, a white core, and a thin
	-- crackle line whose bend re-aims a few times a second and glides there (a shimmer, never a strobe)
	local twins = {}
	for i, def in { { -1, Reveal.BEAM_A, 46 }, { 1, Reveal.BEAM_B, 40 } } do
		local a0, a1 = anchor(), anchor()
		local tw = { side = def[1], at = def[2], tall = def[3] * k, a0 = a0, a1 = a1 }
		tw.haze = beam(a0, a1, HAZE, 0.8, "BeamGlow", { Transparency = NumberSequence.new(0.3) })
		tw.glow = beam(a0, a1, MAGENTA, 1, "BeamGlow", { Transparency = NumberSequence.new(0) })
		tw.core = beam(a0, a1, CORE, 1, "BeamGlow")
		tw.crackle = beam(a0, a1, WHITE, 1, "Lightning", { TextureLength = 10, TextureSpeed = 1.5, Segments = 30 })
		tw.jit = { from = Vector2.zero, to = Vector2.zero, at = 0 }
		tw.bent = { tw.haze, tw.glow, tw.core }
		twins[i] = tw
	end
	-- the ladder blocks climbing beam A (the reference's 1.6 s), and its picture once uploaded
	local rungs = {}
	for i = 1, 7 do
		local a0, a1 = anchor(), anchor()
		table.insert(rungs, { i = i, a0 = a0, a1 = a1, b = beam(a0, a1, rgb(255, 200, 255), 1, nil, { Segments = 2 }) })
	end
	local ladderSkin = if FxTexture.ready("BeamLadder") then beam(twins[1].a0, twins[1].a1, rgb(255, 190, 255), 1, "BeamLadder", { TextureLength = 18, TextureSpeed = -1.6 }) else nil

	-- slashes across the screen: the red-pink four of the build-up and the long red lines of 10.1 s
	local slashes = {}
	local function addSlash(at, kind, i)
		local a0, a1 = anchor(), anchor()
		local col = if kind == "red" then RED else SLASH
		local sl = { at = at, i = i, kind = kind, a0 = a0, a1 = a1, glow = beam(a0, a1, col, 0.8, "BeamGlow", { Transparency = ENDS }), core = beam(a0, a1, WHITE, 1, "BeamGlow", { Transparency = ENDS }) }
		table.insert(slashes, sl)
	end
	local heights = { 2.5, -1.5, 4.2, -3.2, 0.8 }
	for i, at in Reveal.SLASHES do addSlash(at, "build", i) end
	for i, at in Reveal.RED do addSlash(at, "red", i) end

	-- the eyes: big glowing slits with a halo, a flare bar and one glint line through both
	-- (two clearly separate slits, each a pink slit round a white-hot middle, a soft pink glow along it; the orb
	-- melts away as they open, so nothing blurs them into one blob)
	local eyeAt = orbAt + Vector3.new(0, size.Y * 0.12, 0)
	local EYE_W = 8
	local eyeGap = EYE_W * 0.5 + 0.9 -- (half the centre-to-centre distance, studs before scaling: a clear gap)
	local eyes = {}
	for _, side in { -1, 1 } do
		local eye = part({ Name = "Eye", Material = Enum.Material.Neon, Color = rgb(255, 60, 120), Size = Vector3.new(EYE_W * k, 2 * k, 0.3 * k), Transparency = 1 }, folder)
		local hot = part({ Name = "EyeCore", Material = Enum.Material.Neon, Color = rgb(255, 225, 240), Size = Vector3.new(EYE_W * 0.8 * k, 0.8 * k, 0.4 * k), Transparency = 1 }, folder)
		local a0, a1 = anchor(), anchor()
		local halo = beam(a0, a1, rgb(255, 50, 130), 1, "BeamGlow", { Transparency = ENDS, Segments = 2 })
		table.insert(eyes, { side = side, eye = eye, hot = hot, a0 = a0, a1 = a1, halo = halo })
	end
	local glint = { a0 = anchor(), a1 = anchor() }
	glint.glow = beam(glint.a0, glint.a1, rgb(255, 90, 170), 1, "BeamGlow", { Transparency = ENDS, Segments = 2 })
	glint.core = beam(glint.a0, glint.a1, WHITE, 1, "BeamGlow", { Transparency = ENDS, Segments = 2 })

	-- light rays (impact and burst): beams from a point outwards, laid out in the camera's picture plane
	local rays = {}
	for i = 1, 18 do
		local a0, a1 = anchor(), anchor()
		local ang = (i - 1) / 18 * math.pi * 2 + rnd:NextNumber(-0.15, 0.15)
		table.insert(rays, { ang = ang, len = rnd:NextNumber(0.55, 1), w = rnd:NextNumber(0.6, 1.4), a0 = a0, a1 = a1,
			b = beam(a0, a1, seq(WHITE, PINK), 1, "BeamGlow", { Transparency = TAPER, Segments = 2 }) })
	end
	-- four-point star flares: two long spikes and two short diagonals each way, a neon core
	local function newFlare(name)
		local f = { spikes = {} }
		f.core = part({ Name = name, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = rgb(255, 210, 245), Size = Vector3.one, Transparency = 1 }, folder)
		for j = 1, 8 do
			local a0, a1 = anchor(), anchor()
			f.spikes[j] = { a0 = a0, a1 = a1, b = beam(a0, a1, seq(WHITE, PINK), 1, "BeamGlow", { Transparency = TAPER, Segments = 2 }) }
		end
		return f
	end
	local flares = { newFlare("FlareA"), newFlare("FlareB"), newFlare("FlareC") }
	local function setFlare(f, at, s, alpha, camR, camU, color, coreScale)
		f.core.CFrame = CFrame.new(at)
		f.core.Size = Vector3.one * math.max(1.6 * s * (coreScale or 1), 0.05)
		f.core.Transparency = 1 - alpha
		f.core.Color = color or rgb(255, 210, 245)
		for j, sp in f.spikes do
			local ang = (j - 1) * math.pi / 2 + (if j > 4 then math.pi / 4 else 0)
			local dirv = camR * math.cos(ang) + camU * math.sin(ang)
			local len = (if j > 4 then 4 elseif j % 2 == 1 then 15 else 10) * s
			sp.a0.WorldPosition = at
			sp.a1.WorldPosition = at + dirv * len
			setWidth(sp.b, (if j > 4 then 0.35 else 0.7) * s * alpha, 0)
			sp.b.Color = seq(WHITE, color or PINK)
		end
	end

	-- crescent swings round her (4.4 / 4.9 / 5.3 s) and the crackle round the flare (11.45 s)
	local swings = {}
	for i, at in Reveal.SWINGS do
		local a0, a1 = anchor(), anchor()
		local sw = { at = at, i = i, a0 = a0, a1 = a1, glow = beam(a0, a1, MAGENTA, 0.8, "BeamGlow", { Transparency = ENDS }), core = beam(a0, a1, CORE, 1, "BeamGlow", { Transparency = ENDS }),
			tilt = ({ 20, -25, 8 })[i], start = ({ -70, 110, 200 })[i], lift = ({ 1, 3, -1 })[i] }
		sw.both = { sw.glow, sw.core }
		table.insert(swings, sw)
	end
	local tendrils = {}
	for i = 1, 5 do
		local a0, a1 = anchor(), anchor()
		table.insert(tendrils, { i = i, a0 = a0, a1 = a1, b = beam(a0, a1, rgb(255, 170, 240), 1, "Lightning", { Segments = 16, TextureLength = 6 }), jit = 0 })
	end

	-- speed streaks (7.0-9.35 s): long lines rushing towards the camera, all towards one vanishing point by her
	local streakLines = {}
	for i = 1, 44 do
		local a0, a1 = anchor(), anchor()
		table.insert(streakLines, { a0 = a0, a1 = a1, phase = rnd:NextNumber(), y = rnd:NextNumber(-0.35, 0.95), depth = rnd:NextNumber(0.6, 1.3),
			len = rnd:NextNumber(0.5, 1.3), w = rnd:NextNumber(0.08, 0.35), speed = rnd:NextNumber(1.1, 1.9),
			b = beam(a0, a1, seq(WHITE, rgb(220, 120, 255), rgb(150, 70, 255)), 1, "BeamGlow", { Transparency = TAPER, Segments = 2 }) })
	end

	-- the impact frame: a split second of pink manga lines bursting in from the edges on deep violet. Reduced Motion: none.
	local frameGui = Instance.new("ScreenGui")
	frameGui.Name, frameGui.IgnoreGuiInset, frameGui.DisplayOrder, frameGui.Enabled, frameGui.ResetOnSpawn = "HuzzImpactFrame", true, 60, false, false
	local paper = Instance.new("Frame")
	paper.Size, paper.BackgroundColor3, paper.BorderSizePixel = UDim2.fromScale(1, 1), rgb(34, 10, 58), 0
	paper.Parent = frameGui
	local burstGui = Instance.new("Frame")
	burstGui.AnchorPoint, burstGui.Position, burstGui.Size, burstGui.BackgroundTransparency = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(2400, 2400), 1
	burstGui.Parent = paper
	local lineRnd = Random.new(7)
	for i = 1, 26 do
		local a = (i - 1) / 26 * 360 + lineRnd:NextNumber(-5, 5)
		local w = lineRnd:NextInteger(8, 46)
		local len = lineRnd:NextInteger(820, 1180)
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
		line.Parent = burstGui
	end
	table.insert(junk, frameGui)

	-- the impact: emitters at the orb, at her middle (follows her) and on the ground
	local blast = part({ Name = "Blast", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(orbAt) }, folder)
	local heart = part({ Name = "Heart", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(orbAt) }, folder)
	local function burstSet(parent, s)
		return {
			star = emitter(parent, { Picture = { "BurstStar", "Random" }, Color = seq(WHITE, PINK), LightEmission = 1, Brightness = 2,
				Size = nseq({ { 0, 0 }, { 0.2, 14 * k * s }, { 1, 16 * k * s } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.05 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), ZOffset = 2 }),
			sparks = emitter(parent, { Picture = { "Spark" }, Color = seq(WHITE, CYAN, VIOLET), LightEmission = 1, Brightness = 2,
				Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({ { 0, 0.8 * k }, { 1, 0.2 } }),
				Squash = nseq({ { 0, 0 }, { 0.3, 2 }, { 1, 2.5 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(25 * k, 45 * k), Drag = 6, SpreadAngle = Vector2.new(180, 180) }),
			shards = emitter(parent, { Picture = { "Crystal" }, Color = seq(WHITE, PINK, CYAN), LightEmission = 1, Brightness = 1.6,
				Size = nseq({ { 0, 1.6 * k }, { 1, 0.5 * k } }), Transparency = nseq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(20 * k, 40 * k), Drag = 3, SpreadAngle = Vector2.new(180, 180),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Acceleration = Vector3.new(0, -6 * k, 0) }),
			streaks = emitter(parent, { Picture = { "Streak" }, Color = seq(WHITE, PINK, VIOLET), LightEmission = 1, Brightness = 2,
				Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({ { 0, 1.2 * k }, { 1, 0.3 * k } }),
				Squash = nseq({ { 0, 3 }, { 1, 4 } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(70 * k, 110 * k), SpreadAngle = Vector2.new(180, 180) }),
		}
	end
	local hit, burst2 = burstSet(blast, 1), burstSet(heart, 1.3)
	local spark0 = emitter(blast, { Picture = { "StarFlare" }, Color = seq(WHITE, PINK), LightEmission = 1, Brightness = 2,
		Size = nseq({ { 0, 0 }, { 0.25, 9 * k }, { 1, 10 * k } }), Transparency = nseq({ { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0), ZOffset = 1 })
	local shock = emitter(blast, { Picture = { "ShockSheet", "OneShot" }, Color = seq(WHITE, CYAN), LightEmission = 1,
		Size = nseq({ { 0, 6 * k }, { 1, 18 * k } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(0), ZOffset = 1 })
	-- the burst's big red-white ring (the reference's 12.3 s), facing the camera
	local ringBurst = emitter(heart, { Picture = { "RingSoft" }, Color = seq(rgb(255, 200, 215), rgb(255, 40, 80)), LightEmission = 1, Brightness = 3,
		Size = nseq({ { 0, 4 * k }, { 0.2, 24 * k }, { 1, 32 * k } }), Transparency = nseq({ { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.6), Speed = NumberRange.new(0), ZOffset = 1 })
	local cloud = emitter(heart, { Picture = { "Nebula" }, Color = seq(rgb(255, 130, 200), rgb(230, 50, 150), rgb(120, 30, 150)), LightEmission = 0.8, Brightness = 1.5,
		Size = nseq({ { 0, 8 * k }, { 1, 26 * k } }), Transparency = nseq({ { 0, 0.25 }, { 0.6, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(8 * k, 18 * k), Drag = 2, SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30) })
	local swarmBox = part({ Name = "SwarmBox", Transparency = 1, Size = Vector3.new(22 * k, 14 * k, 10 * k), CFrame = CFrame.new(orbAt) }, folder)
	local swarm = emitter(swarmBox, { Picture = { "Butterfly", "Loop", 14 }, Color = seq(rgb(130, 180, 255), rgb(255, 110, 210)),
		LightEmission = 0.5, Brightness = 1, Size = nseq({ { 0, 0 }, { 0.1, 2.4 * k }, { 0.8, 2.2 * k }, { 1, 0 } }),
		Transparency = nseq({ { 0, 0 }, { 1, 0.3 } }), Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(6 * k, 14 * k),
		Drag = 1.5, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(-30, 30), RotSpeed = NumberRange.new(-40, 40) })

	local floor = part({ Name = "Floor", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) }, folder)
	local flat = { Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), SpreadAngle = Vector2.zero }
	local function flatEmitter(props)
		for key, v in flat do props[key] = v end
		return emitter(floor, props)
	end
	local groundRing = flatEmitter({ Picture = { "RingHard" }, Color = seq(WHITE, CYAN), LightEmission = 1, Brightness = 1.5,
		Size = nseq({ { 0, 2 * k }, { 0.15, 14 * k }, { 0.45, 22 * k }, { 1, 26 * k } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5) })
	local landRing = flatEmitter({ Picture = { "RingSoft" }, Color = seq(WHITE, PINK, VIOLET), LightEmission = 1, Brightness = 1.5,
		Size = nseq({ { 0, 3 * k }, { 0.15, 11 * k }, { 0.45, 16 * k }, { 1, 18 * k } }), Transparency = nseq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5) })
	-- one sigil from the build-up to the landing
	local sigilLife = Reveal.LAND + 0.3 - Reveal.BUILD
	local sigil = flatEmitter({ Picture = { "Sigil" }, Color = seq(WHITE, VIOLET), LightEmission = 1, Brightness = 1.3,
		Size = nseq({ { 0, 13 * k }, { 1, 15 * k } }), Transparency = nseq({ { 0, 1 }, { 0.12, 0.3 }, { 0.88, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(sigilLife), RotSpeed = NumberRange.new(28), Rotation = NumberRange.new(0, 360), LockedToPart = true })
	local dust = emitter(floor, { Picture = { "Wisp" }, Color = seq(rgb(220, 210, 255), rgb(120, 110, 160)), LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapePartial = 1,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Size = nseq({ { 0, 2 * k }, { 1, 5 * k } }),
		Transparency = nseq({ { 0, 0.4 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(14 * k, 22 * k), Drag = 4 })
	floor.Size = Vector3.new(6 * k, 0.2, 6 * k)
	-- purple smoke rolling on the ground round the spot (the reference's 2 s and 4.5 s)
	local smokeBed = part({ Name = "SmokeBed", Transparency = 1, Size = Vector3.new(30 * k, 0.5, 30 * k), CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)) }, folder)
	local smoke = emitter(smokeBed, { Picture = { "Nebula" }, Color = seq(rgb(160, 70, 240), rgb(90, 40, 170)), LightEmission = 0.35, Brightness = 1.2,
		Size = nseq({ { 0, 5 * k }, { 1, 12 * k } }), Transparency = nseq({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(1.5 * k, 3.5 * k), Drag = 1, SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 0.3 * k, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15) })
	-- the air: motes, drifting crystals and butterflies all round the spot; nebula haze in the sky
	local air = part({ Name = "Air", Transparency = 1, Size = Vector3.new(70 * k, 40 * k, 70 * k), CFrame = CFrame.new(ground + Vector3.new(0, 18 * k, 0)) }, folder)
	local motes = emitter(air, { Picture = { "Bokeh" }, Color = seq(rgb(220, 120, 255), rgb(255, 120, 210)), LightEmission = 1, Brightness = 2,
		Size = nseq({ { 0, 0 }, { 0.15, 0.9 * k, 0.5 * k }, { 0.85, 0.9 * k, 0.5 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.2 }, { 1, 0.5 } }),
		Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.5 * k, 0), Drag = 0.5 })
	local motesCyan = emitter(air, { Picture = { "Bokeh" }, Color = seq(rgb(140, 230, 255), rgb(120, 170, 255)), LightEmission = 1, Brightness = 2,
		Size = nseq({ { 0, 0 }, { 0.15, 0.7 * k, 0.35 * k }, { 0.85, 0.7 * k, 0.35 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.2 }, { 1, 0.5 } }),
		Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.5 * k, 0), Drag = 0.5 })
	local crystals = emitter(air, { Picture = { "Crystal" }, Color = seq(rgb(210, 235, 255), rgb(190, 140, 255)), LightEmission = 0.7, Brightness = 1.5,
		Size = nseq({ { 0, 0 }, { 0.1, 1.1 * k, 0.4 * k }, { 0.9, 1.1 * k, 0.4 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.15 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -0.8 * k, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60) })
	local butterflies = emitter(air, { Picture = { "Butterfly", "Loop", 14 }, Color = seq(rgb(160, 215, 255), rgb(110, 160, 255)),
		LightEmission = 0.6, Brightness = 1.4, Size = nseq({ { 0, 0 }, { 0.1, 2 * k }, { 0.85, 2 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(2 * k, 4 * k), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.6 * k, 0),
		Rotation = NumberRange.new(-25, 25), RotSpeed = NumberRange.new(-20, 20), Drag = 0.5 })
	local hazes = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local slab = part({ Name = "Sky", Transparency = 1, Size = Vector3.new(220 * k, 24 * k, 20 * k),
			CFrame = CFrame.lookAt(ground + out * 95 * k + up * 22 * k, ground + up * 22 * k) }, folder)
		table.insert(hazes, emitter(slab, { Picture = { "Nebula" }, Color = seq(rgb(60, 90, 210), rgb(45, 60, 170), rgb(100, 60, 190)),
			LightEmission = 0.4, Brightness = 1, Size = nseq({ { 0, 40 * k, 10 * k }, { 1, 60 * k, 10 * k } }), Transparency = nseq({ { 0, 1 }, { 0.25, 0.6 }, { 0.75, 0.6 }, { 1, 1 } }),
			Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8) }))
	end

	-- stand-in rings until the ring pictures are uploaded: a thin neon ring of short segments, growing and fading
	local function newRing(color)
		local bits = {}
		for i = 1, 28 do bits[i] = part({ Name = "RingBit", Material = Enum.Material.Neon, Color = color, Size = Vector3.one * 0.05, Transparency = 1 }, folder) end
		return bits
	end
	local function setRing(bits, centre, ax, ay, radius, thick, alpha)
		local len = 2 * math.pi * radius / #bits * 1.1
		for i, p in bits do
			local a = (i - 0.5) / #bits * math.pi * 2
			local out = ax * math.cos(a) + ay * math.sin(a)
			p.CFrame = CFrame.fromMatrix(centre + out * radius, -ax * math.sin(a) + ay * math.cos(a), out)
			p.Size = Vector3.new(math.max(len, 0.05), math.max(thick, 0.05), math.max(thick * 0.5, 0.05))
			p.Transparency = if alpha > 0.01 then 1 - alpha else 1
		end
	end
	local standIns = {}
	if not FxTexture.ready("RingSoft") then
		standIns.burst = newRing(rgb(255, 70, 110))
		standIns.land = newRing(rgb(255, 150, 220))
	end
	if not FxTexture.ready("RingHard") then standIns.impact = newRing(rgb(200, 240, 255)) end
	local function ringAt(bits, at, life, t, centre, ax, ay, r0, r1, thick)
		if not bits then return end
		local x = (t - at) / life
		if x < 0 or x > 1 then setRing(bits, centre, ax, ay, r0, thick, 0); return end
		setRing(bits, centre, ax, ay, r0 + (r1 - r0) * (1 - (1 - x) ^ 3), thick * (1 - 0.6 * x), 1 - x * x)
	end

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
	table.insert(junk, grade)

	local all = { rush, hit.star, hit.sparks, hit.shards, hit.streaks, burst2.star, burst2.sparks, burst2.shards, burst2.streaks, spark0, shock, ringBurst,
		cloud, swarm, groundRing, landRing, sigil, dust, smoke, motes, motesCyan, crystals, butterflies }
	for _, e in hazes do table.insert(all, e) end
	local fired = {}
	local function once(name, fn)
		if not fired[name] then fired[name] = true; fn() end
	end
	local ambientRates = { [motes] = 18, [motesCyan] = 8, [crystals] = 7, [butterflies] = 2.5 }
	for _, e in hazes do ambientRates[e] = 1.2 end

	local function step(t: number, dir: Vector3, cam: CFrame?)
		local calm = Motion.reduced
		local side = dir:Cross(up)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
		-- the camera's picture plane (rays, flares and streaks are laid out in it); from `dir` if no camera given
		local camR = if cam then cam.RightVector else -side
		local camU = if cam then cam.UpVector else up
		local camPos = if cam then cam.Position else ground + dir * 40 * k
		-- hit-stop: every emitter nearly frozen for a split second
		local stop = t >= Reveal.HOLD and t < Reveal.IMPACT
		for _, e in all do e.TimeScale = if stop then 0.05 else 1 end
		local h = Reveal.height(t, Config.Showcase.Height)
		local herMid = spot + Vector3.new(0, (h or Reveal.ORB_HEIGHT) * k, 0) + (box.Position - base.Position)
		heart.CFrame = CFrame.new(herMid)
		swarmBox.CFrame = CFrame.lookAt(herMid + (camPos - herMid) * 0.3, camPos)

		-- the night and the air
		local night = Reveal.night(t)
		for _, s in saved do
			(s.inst :: any)[s.key] = lerp(s.was, s.target, night)
		end
		Lighting.ClockTime = Reveal.clock(t, day)
		once("air", function()
			motes:Emit(45); motesCyan:Emit(18); crystals:Emit(20)
			for _, e in hazes do e:Emit(6) end
		end)
		local airOn = t < Reveal.DAWN
		for e, rate in ambientRates do
			e.Rate = if airOn and not stop and (e ~= butterflies or t >= Reveal.BEAM_A) then rate else 0
		end
		smoke.Rate = if not airOn or stop then 0 elseif t >= Reveal.LAND then 12 elseif t >= Reveal.BEAM_A then 6 else 0

		-- the orb
		local orbSize, spin = Reveal.orb(t)
		local melt = math.clamp((t - Reveal.EYES) / 0.25, 0, 1) -- (the orb gives way to the eyes)
		core.Transparency = if orbSize > 0 then melt else 1
		shell.Transparency = if orbSize > 0 then 0.2 + 0.8 * melt else 1
		core.Size = Vector3.one * math.max(orbSize, 0.05) * k
		shell.Size = Vector3.one * math.max(orbSize * 1.25, 0.05) * k
		rush.Rate = if orbSize > 0 and not stop and melt < 1 then 40 + 50 * (orbSize / Reveal.ORB_MAX) else 0
		for _, o in orbiters do
			local a = t * spin + o.phase
			local r = (5 - 2.5 * math.min(1, orbSize / Reveal.ORB_MAX)) * k
			local off = CFrame.Angles(o.tilt, 0, 0):VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			o.a0.WorldPosition = orbAt + off + Vector3.new(0, 0.18, 0)
			o.a1.WorldPosition = orbAt + off - Vector3.new(0, 0.18, 0)
		end
		if t >= Reveal.BUILD then
			once("sigil", function()
				if FxTexture.ready("Sigil") then sigil:Emit(1) end
				Sfx.play("secret_riser")
			end)
		end
		if t >= Reveal.SPARK then once("spark", function() spark0:Emit(1) end) end

		-- the twin beams: struck from the sky, bowing outwards, leaning a little the same way
		for _, tw in twins do
			local reach, power = Reveal.beam(t, tw.at)
			if t >= tw.at then once("strike" .. tw.at, function() hit.shards:Emit(10); hit.sparks:Emit(12) end) end
			local out = side * tw.side
			local foot = ground + out * 10 * k
			local top = foot + up * tw.tall - side * 0.06 * tw.tall
			local low = top + (foot - top) * math.max(reach, 0.02)
			local lean = math.rad(12)
			tw.a0.WorldCFrame = CFrame.fromMatrix(low, up * math.cos(lean) + out * math.sin(lean), dir)
			tw.a1.WorldCFrame = CFrame.fromMatrix(top, up * math.cos(lean) - out * math.sin(lean), dir)
			local curve = (top - low).Magnitude * 0.3
			for _, b in tw.bent do b.CurveSize0, b.CurveSize1 = curve, curve end
			setWidth(tw.haze, 26 * k * power, 18 * k * power)
			setWidth(tw.glow, 11 * k * power, 8 * k * power)
			setWidth(tw.core, 3 * k * power, 2.2 * k * power)
			-- the crackle: a new bend every 0.16 s, glided to (no snapping: a shimmer)
			local jt = tw.jit
			if not calm and t - jt.at > 0.16 then
				jt.from, jt.to, jt.at = jt.to, Vector2.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1)), t
			end
			local x = math.clamp((t - jt.at) / 0.16, 0, 1)
			local j = jt.from:Lerp(jt.to, x * x * (3 - 2 * x))
			tw.crackle.CurveSize0, tw.crackle.CurveSize1 = curve + j.X * 4 * k, curve + j.Y * 4 * k
			setWidth(tw.crackle, 1 * k * power, 0.7 * k * power)
		end
		-- the ladder blocks climb beam A
		local lv = Reveal.ladder(t)
		local A = twins[1]
		local aLow, aTop = A.a0.WorldCFrame.Position, A.a1.WorldCFrame.Position
		for _, r in rungs do
			local u = ((t * 0.55 + r.i / #rungs) % 1)
			local p = aLow + (aTop - aLow) * u + side * A.side * math.sin(u * math.pi) * (aTop - aLow).Magnitude * 0.075
			r.a0.WorldPosition = p - side * 4 * k
			r.a1.WorldPosition = p + side * 4 * k
			setWidth(r.b, 2.6 * k * lv)
		end
		if ladderSkin then setWidth(ladderSkin, 10 * k * lv, 8 * k * lv); ladderSkin.CurveSize0, ladderSkin.CurveSize1 = A.haze.CurveSize0, A.haze.CurveSize1 end

		-- slashes
		for _, sl in slashes do
			local v = Reveal.slash(t, sl.at)
			local flip = if sl.i % 2 == 0 then -1 else 1
			local centre, len, tilt = orbAt, 24 * k, 4 * k
			if sl.kind == "red" then centre, len, tilt = herMid, 45 * k, 14 * k end
			local mid = centre + up * heights[sl.i] * k + side * math.max(0, t - sl.at) * 30 * k * flip
			sl.a0.WorldPosition = mid - side * len + up * tilt * flip
			sl.a1.WorldPosition = mid + side * len - up * tilt * flip
			setWidth(sl.glow, (if sl.kind == "red" then 4.5 else 3.6) * k * v)
			setWidth(sl.core, 0.9 * k * v)
		end

		-- the eyes
		local ev = if t >= Reveal.EYES and t < Reveal.IMPACT then math.clamp((t - Reveal.EYES) / 0.2, 0, 1) else 0
		for _, e in eyes do
			local p = eyeAt + side * e.side * eyeGap * k
			local cf = CFrame.fromMatrix(p, side, up) * CFrame.Angles(0, 0, math.rad(-12 * e.side)) -- (angry: outer ends up)
			e.eye.CFrame = cf
			e.eye.Size = Vector3.new(EYE_W * k, math.max(2 * k * ev, 0.05), 0.3 * k)
			e.eye.Transparency = 1 - ev
			e.hot.CFrame = cf + dir * 0.1 * k
			e.hot.Size = Vector3.new(EYE_W * 0.8 * k, math.max(0.8 * k * ev, 0.05), 0.4 * k)
			e.hot.Transparency = 1 - ev
			e.a0.WorldPosition = cf:PointToWorldSpace(Vector3.new(-EYE_W * 0.75 * k, 0, 0)) - dir * 0.3 * k
			e.a1.WorldPosition = cf:PointToWorldSpace(Vector3.new(EYE_W * 0.75 * k, 0, 0)) - dir * 0.3 * k
			setWidth(e.halo, 7 * k * ev)
		end
		glint.a0.WorldPosition = eyeAt - side * 22 * k
		glint.a1.WorldPosition = eyeAt + side * 22 * k
		setWidth(glint.glow, 1.4 * k * ev)
		setWidth(glint.core, 0.25 * k * ev)

		-- light rays: the impact (pink-white, round the orb) and the burst (red, round her)
		local rv, rc, rs, rcol = 0, orbAt, 1, PINK
		local iv, bv = Reveal.pop(t, Reveal.IMPACT, 0.06, 0.55), Reveal.pop(t, Reveal.BURST, 0.06, 0.65)
		local lv2 = 0.6 * Reveal.pop(t, Reveal.FLARE - 0.1, 0.1, 0.45)
		if bv > iv then rv, rc, rs, rcol = bv, herMid, 1.6, rgb(255, 35, 75) else rv = iv end
		if lv2 > rv then rv, rc, rs, rcol = lv2, herMid + up * 1.5 * k, 1.5, rgb(200, 130, 255) end
		for _, r in rays do
			local dirv = camR * math.cos(r.ang) + camU * math.sin(r.ang)
			local len = (14 + 36 * math.min(1, rv * 1.6)) * r.len * k * rs
			r.a0.WorldPosition = rc + dirv * 2 * k
			r.a1.WorldPosition = rc + dirv * len
			setWidth(r.b, 2.4 * r.w * k * rv * rs, 0)
			r.b.Color = seq(WHITE:Lerp(rcol, 0.3), rcol, rcol)
		end
		-- the star flares: sparkles either side of the impact, one on her at 6.75 s, growing from 11.45 s, the burst
		local fa = Reveal.pop(t, Reveal.IMPACT, 0.05, 0.5)
		setFlare(flares[2], orbAt - camR * 14 * k + camU * 2 * k, 1.6 * k, fa, camR, camU)
		setFlare(flares[3], orbAt + camR * 15 * k - camU * 3 * k, 1.3 * k, fa, camR, camU)
		local g0, g1 = Reveal.GROW[1], Reveal.GROW[2]
		local grow = if t >= g0 and t < g1 then Reveal.smooth((t - g0) / (g1 - g0)) else 0
		local sparkV = Reveal.pop(t, Reveal.SPARK - 0.04, 0.04, 0.4) -- (the little starburst on the orb)
		local fv = math.max(Reveal.pop(t, Reveal.FLARE - 0.1, 0.1, 0.5), grow, Reveal.pop(t, Reveal.BURST, 0.04, 0.6), sparkV)
		local fs = if t >= Reveal.BURST then 2.6 elseif grow > 0 then 0.6 + 1.6 * grow elseif sparkV > 0 then 0.9 else 2
		local glintOn = Reveal.pop(t, Reveal.GLINT, 0.08, 0.35)
		if glintOn > fv then -- (the eye glint in the close-up: a small flare by her face)
			local face = herMid + up * (mid - 1.9 * k) + dir * 1.6 * k + side * 0.35 * k
			setFlare(flares[1], face, 0.7 * k, glintOn, camR, camU, rgb(255, 90, 170), 0.2)
		else
			setFlare(flares[1], herMid + up * 1.5 * k + (camPos - herMid).Unit * 2 * k, fs * k, fv, camR, camU,
				if t >= Reveal.BURST then rgb(255, 70, 110) else nil)
		end
		-- crackling tendrils round the growing flare
		for _, td in tendrils do
			local ang = td.i / #tendrils * math.pi * 2 + t * 0.7
			local dirv = camR * math.cos(ang) + camU * math.sin(ang)
			td.a0.WorldPosition = herMid + up * 1.5 * k
			td.a1.WorldPosition = herMid + up * 1.5 * k + dirv * (5 + 6 * grow) * k
			if not calm and t - td.jit > 0.2 then
				td.jit = t
				td.b.CurveSize0, td.b.CurveSize1 = rnd:NextNumber(-3, 3) * k, rnd:NextNumber(-3, 3) * k
			end
			setWidth(td.b, 0.45 * k * grow, 0.1 * k * grow)
		end

		-- crescent swings round her
		for _, sw in swings do
			local v = Reveal.pop(t, sw.at, 0.06, 0.32)
			local tilt = math.rad(sw.tilt)
			local axis = (up * math.cos(tilt) + dir * math.sin(tilt)).Unit
			local u = (dir - axis * dir:Dot(axis)).Unit
			local w = axis:Cross(u)
			local th0 = math.rad(sw.start) + (t - sw.at) * 3
			local th1 = th0 + math.rad(150)
			local R = 8 * k
			local c = herMid + up * sw.lift * k
			local p0, p1 = c + (u * math.cos(th0) + w * math.sin(th0)) * R, c + (u * math.cos(th1) + w * math.sin(th1)) * R
			local t0, t1 = -u * math.sin(th0) + w * math.cos(th0), -u * math.sin(th1) + w * math.cos(th1)
			sw.a0.WorldCFrame = CFrame.fromMatrix(p0, t0, axis)
			sw.a1.WorldCFrame = CFrame.fromMatrix(p1, t1, axis)
			for _, b in sw.both do b.CurveSize0, b.CurveSize1 = R * 1.02, R * 1.02 end
			setWidth(sw.glow, 2.2 * k * v)
			setWidth(sw.core, 0.5 * k * v)
		end

		-- speed streaks rushing past
		local s0, s1 = Reveal.STREAKS[1], Reveal.STREAKS[2]
		local sv = if t >= s0 and t < s1 then math.min(1, (t - s0) / 0.2, (s1 - t) / 0.25) else 0
		-- (laid out in front of the camera, so they fill the picture whatever the shot: rushing left to right and a
		-- little up, most of them over her, like the reference)
		local camF = if cam then cam.LookVector else -dir
		local flow = (camR + camU * 0.22).Unit
		for _, sl in streakLines do
			local D = 22 * k * sl.depth
			local half = D * 0.62 -- (about half the picture's width at that distance)
			local s = ((t * sl.speed + sl.phase) % 1)
			local head = camPos + camF * D + camU * sl.y * half * 0.8 + flow * (-1.6 + 3.4 * s) * half
			sl.a0.WorldPosition = head
			sl.a1.WorldPosition = head - flow * sl.len * half * 1.4
			setWidth(sl.b, sl.w * D * 0.05 * sv * 4, 0)
		end

		ringAt(standIns.impact, Reveal.IMPACT, 0.5, t, ground + up * 0.4, side, dir, 2 * k, 24 * k, 0.5 * k)
		ringAt(standIns.land, Reveal.LAND, 0.5, t, ground + up * 0.4, side, dir, 3 * k, 16 * k, 0.45 * k)
		ringAt(standIns.burst, Reveal.BURST, 0.6, t, herMid, camR, camU, 4 * k, 30 * k, 1 * k)
		frameGui.Enabled = Reveal.impactFrame(t, calm)
		-- the impact
		if t >= Reveal.IMPACT then
			once("impact", function()
				hit.star:Emit(1)
				hit.sparks:Emit(24)
				hit.shards:Emit(28)
				if FxTexture.ready("ShockSheet") then shock:Emit(1) end
				if FxTexture.ready("RingHard") then groundRing:Emit(1) end
				if FxTexture.ready("Streak") then hit.streaks:Emit(30) end
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
				smoke:Emit(16)
				Sfx.play("secret_land")
			end)
			local x = math.clamp((t - Reveal.LAND) / 0.45, 0, 1)
			dome.Size = Vector3.one * (2 + 12 * (1 - (1 - x) ^ 3)) * k
			dome.Transparency = if x >= 1 then 1 else 0.2 + 0.8 * x
		end
		if t >= Reveal.SWARM then once("swarm", function() swarm:Emit(60) end) end
		if t >= Reveal.BURST then
			once("burst", function()
				burst2.star:Emit(1)
				burst2.sparks:Emit(40)
				burst2.shards:Emit(36)
				if FxTexture.ready("Streak") then burst2.streaks:Emit(36) end
				cloud:Emit(22)
				if FxTexture.ready("RingSoft") then ringBurst:Emit(1) end
				Sfx.play("secret_impact")
			end)
		end
		-- her: hidden until the impact, then dropping, standing, rising (facing the camera, then turning slowly)
		if h then
			local S = Config.Showcase
			local yaw = math.max(0, t - Reveal.RISE) * (S.Spin or 0.35)
			local face = CFrame.lookAt(Vector3.zero, Vector3.new(dir.X, 0, dir.Z)).Rotation
			local pose = CFrame.new(spot + Vector3.new(0, h * k, 0)) * face * CFrame.Angles(0, yaw, 0)
			if t > Reveal.RISE then -- (so there's no snap when Gameplay/CarryAnimator takes her back at the end)
				local now = revealAt + t
				local float = base * CFrame.new(0, math.sin(now * 1.1) * (S.Bob or 0), 0) * CFrame.Angles(0, (now * (S.Spin or 0)) % (2 * math.pi), 0)
				pose = pose:Lerp(float, Reveal.smooth((t - Reveal.RISE) / (Reveal.LENGTH - Reveal.RISE)))
			end
			model:PivotTo(pose)
		else
			model:PivotTo(base * CFrame.new(0, -2000, 0))
		end
		-- the world's colour
		local b, s, tint, pulse, contrast = Reveal.grade(t)
		grade.Brightness = b + (if calm then 0 else 0.12 * pulse)
		grade.Saturation = s
		grade.Contrast = contrast
		grade.TintColor = WHITE:Lerp(rgb(200, 170, 255), tint)
		return orbAt, h
	end

	local function cleanup()
		for i = #saved, 1, -1 do
			local s = saved[i]
			pcall(function() (s.inst :: any)[s.key] = s.was end)
		end
		Lighting.ClockTime = day
		for _, inst in made do inst:Destroy() end
		folder:Destroy()
		grade:Destroy()
		frameGui:Destroy()
		for _, b in beams do b:Destroy() end
		for _, a in anchors do a:Destroy() end
	end
	if M.failForTest then error("test: build failed on purpose") end
	-- last of all, into Lighting and the screen (nothing there to undo if anything above failed)
	frameGui.Parent = if player then player:WaitForChild("PlayerGui") else nil
	for _, inst in made do inst.Parent = Lighting end
	grade.Parent = Lighting
	return step, cleanup, ground, k, mid
end

function M.build(model: Model, base: CFrame, revealAt: number?)
	local junk = {}
	local ok, step, cleanup, ground, k, mid = pcall(build, model, base, revealAt or 0, junk)
	if not ok then
		for i = #junk, 1, -1 do pcall(function() junk[i]:Destroy() end) end
		error(step, 0)
	end
	return step, cleanup, ground, k, mid
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
		local ok, step, cleanup, ground, k, mid = pcall(M.build, model, base, at)
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
		-- (the camera never sits behind a wall or prop: from her towards the camera, stop just in front of a hit)
		local okRay, ray = pcall(function()
			local p = RaycastParams.new()
			p.FilterType = Enum.RaycastFilterType.Exclude
			p.FilterDescendantsInstances = { model, Workspace:FindFirstChild("HuzzSecretReveal"), player.Character }
			return p
		end)
		local function clear(eye: Vector3, look: Vector3): Vector3
			if not okRay then return eye end
			local v = eye - look
			if v.Magnitude < 0.5 then return eye end
			local okHit, hit = pcall(function() return Workspace:Raycast(look, v, ray) end)
			if okHit and hit then return hit.Position - v.Unit * 1 end
			return eye
		end
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
				local h = Reveal.height(t, Config.Showcase.Height)
				local eye, look = Reveal.camera(math.min(t, Reveal.RETURN), ground + Vector3.new(0, 0.5, 0), dir, h or Config.Showcase.Height, k, mid)
				eye = clear(eye, look)
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
				step(t, dir, cf)
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
