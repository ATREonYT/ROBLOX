--[[
	The Secret girl's arrival cutscene, on every screen (the timing, the beams' layout, the shots and camera:
	Shared/SecretReveal; beat sheet docs/secret-beats.md; owner Oct 19: "make it more detailed, especially the beams
	... make the duration of it logical"). The server sets the Round stage "Reveal" and stamps RevealAt on the big
	girl over the map (HuzzShowcase); this builds the effects locally and drives her and the camera from one timeline:
	  the night   your Lighting, on this screen only, from the first frame's camera cut until she rises: midnight,
	              a purple Atmosphere, a stronger Bloom, more stars, purple ambient light, a violet grade; all put
	              back exactly afterwards (the Oct 19 even daylight comes back unchanged)
	  all along   purple and cyan motes, drifting crystals, nebula haze in the sky, purple smoke on the ground
	  beams       few, then many, then converging (Shared/SecretReveal.PILLARS): three thin threads, the twin beams,
	              a ring of six. Each beam is layers of plain Beams (outer haze, glow, inner glow, core, white-hot
	              middle: flat strips that add up to a soft falloff, so they read before any picture is uploaded),
	              bright pulses climbing the glow layers (their Transparency, rebuilt every frame), strands winding
	              round the big ones (a helix of short curved Beams that turns faster as they converge), a jagged
	              white filament that re-bends a few times a second and glides there (a shimmer, never a strobe),
	              sparks shedding off and a pool of light where it meets the floor. Rungs climb the first. Then
	              every beam swings its foot into the point between the eyes and pinches thin.
	  burst       hit-stop, a split-second manga frame, a shockwave (a dome, a ring on the floor, a ring facing you),
	              rays and four-point sparkles; she appears in white, drops and lands (a ring, dust, smoke) and a
	              magic circle lights up under her
	  reveal      crescent slashes round her, a soft violet rim on her outline, her NAME on screen (SECRET and 7
	              stars over it, a line drawing out under it) with a star flare behind her, speed streaks while the
	              camera pushes into her face, an eye glint
	  finale      the cut, red streak lines, a butterfly swarm, a crackling flare, the last burst (rays, rings, a pink
	              cloud) and she rises to her place (her name over her head comes back as she rises)
	Flashes: soft pulses only at the burst, the swell and the last burst (more than a second apart; kid-safe).
	Reduced Motion (Settings): no shake, kicks, impact frame, pulses or crackle. No black bars (owner).
	The camera: one smooth move from Shared/SecretReveal.camera with a slow, small wobble (shakeAt); walls pull it in
	at once and let it ease back out. The hand-back (the last 0.5 s): a quick dip to black and, once it is fully
	black, the camera goes back to Roblox behind where you stand now (your old angle and distance); black holds 2
	frames more, then lifts. A dark dip, not a flash.
	Pictures: Shared/FxTexture (the owner's set once uploaded: the beams then scroll his beam-glow, ladder and
	lightning pictures; until then they are the plain layers above and particles use Roblox's sparkle and smoke).
	Filmed offline: tools/preview/motion3d/secret_scene.luau (SECRET_NOTEX=1 films today's look, nothing uploaded).
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
local MAGENTA, CORE = rgb(200, 70, 255), rgb(255, 228, 252)
local SLASH, RED = rgb(255, 40, 95), rgb(255, 45, 100)
-- each beam tone's five layer colours, outside in (Shared/SecretReveal.LAYERS): haze, glow, inner glow, core, middle
local TONES = {
	violet = { rgb(100, 40, 220), rgb(150, 60, 255), rgb(205, 90, 255), rgb(255, 175, 250), WHITE },
	magenta = { rgb(140, 30, 190), rgb(205, 60, 230), rgb(255, 95, 215), rgb(255, 195, 240), WHITE },
	blue = { rgb(60, 60, 210), rgb(90, 115, 255), rgb(145, 175, 255), rgb(205, 228, 255), WHITE },
	ice = { rgb(90, 120, 230), rgb(140, 190, 255), rgb(190, 230, 255), rgb(232, 246, 255), WHITE },
}

-- The night look (Lighting, on this screen only), blended in by Shared/SecretReveal.night.
local NIGHT_LOOK = {
	-- (EnvironmentDiffuseScale too: the day look's sky light at 1 would lift the night's shade to blue-grey)
	Lighting = { Ambient = rgb(34, 28, 62), OutdoorAmbient = rgb(48, 40, 92), Brightness = 1.2, EnvironmentDiffuseScale = 0.25 },
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
local STRAND = { seq(WHITE, PINK, rgb(200, 90, 255)), seq(WHITE, CYAN, rgb(120, 140, 255)) } -- the strands round a beam
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
	-- Her body's own top and bottom (she's still at `base` here). Not GetBoundingBox: the showcase's Aura box
	-- (1 stud bigger all round), stand and lamp holders would put the floor rings 1 stud under the floor.
	local extra = { Aura = true, StandTop = true, StandBand = true, StandGlow = true, KeyLight = true, RimLight = true }
	local lo, hi = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not extra[d.Name] and d.Transparency < 1 then
			local c, h = d.CFrame, d.Size / 2
			local reach = math.abs(c.RightVector.Y) * h.X + math.abs(c.UpVector.Y) * h.Y + math.abs(c.LookVector.Y) * h.Z
			lo, hi = math.min(lo, d.Position.Y - reach), math.max(hi, d.Position.Y + reach)
		end
	end
	if lo == math.huge then
		local box, size = model:GetBoundingBox()
		lo, hi = box.Position.Y - size.Y / 2, box.Position.Y + size.Y / 2
	end
	-- the floor under her: her feet when she stands (her pivot is her root part, not her middle)
	local ground = Vector3.new(spot.X, lo - Config.Showcase.Height, spot.Z)
	-- The real floor under her, read here too (owner: "the girl is under the map and it shows that in the
	-- cutscene"): the server's floor was 8 studs low on Halloween. Her feet and the floor effects go on what the
	-- ray hits, so she lands on the floor and the camera stays above it, whatever the server measured.
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { model }
		for _, name in { "HuzzSecretReveal", "HuzzAuraFX", "HuzzCarried", "HuzzFollowers" } do
			local f = Workspace:FindFirstChild(name)
			if f then table.insert(ignore, f) end
		end
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(ignore, p.Character) end
		end
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true -- (the map's zone boxes are see-through markers, not floor)
		local hit = Workspace:Raycast(Vector3.new(spot.X, lo - 1, spot.Z), Vector3.new(0, -(Config.Showcase.Height + 20), 0), params)
		if hit and math.abs(hit.Position.Y - ground.Y) < 16 then
			local lift = hit.Position.Y - ground.Y
			ground += Vector3.new(0, lift, 0)
			spot += Vector3.new(0, lift, 0)
		end
	end)
	local mid = (hi - lo) / 2
	local orbAt = ground + Vector3.new(0, Reveal.ORB_HEIGHT * k + mid, 0) -- the orb is where her middle appears
	local folder = Instance.new("Folder")
	folder.Name = "HuzzSecretReveal"
	folder.Parent = Workspace
	table.insert(junk, folder)
	local up = Vector3.new(0, 1, 0)
	local rnd = Random.new(11)
	-- her key light: the night would leave her almost black; the reference keeps her pale and lit in violet
	local keyPart = Instance.new("Part")
	keyPart.Name, keyPart.Anchored, keyPart.CanCollide, keyPart.CanQuery, keyPart.CanTouch = "KeyLight", true, false, false, false
	keyPart.Transparency, keyPart.Size = 1, Vector3.one
	keyPart.Parent = folder
	local keyLight = Instance.new("PointLight")
	keyLight.Color, keyLight.Brightness, keyLight.Range, keyLight.Shadows, keyLight.Enabled = Color3.fromRGB(235, 220, 255), 2.5, 22 * k, false, false
	keyLight.Parent = keyPart
	-- a violet rim from behind and above (she reads against the night sky) and the beams' own light on the ground
	local function lamp(name, color, brightness, range)
		local holder = part({ Name = name, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(ground) }, folder)
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Shadows, l.Enabled = color, brightness, range, false, false
		l.Parent = holder
		return holder, l
	end
	local rimPart, rimLight = lamp("RimLight", rgb(190, 140, 255), 2.5, 18 * k)
	local beamPart, beamLight = lamp("BeamLight", rgb(170, 90, 255), 0, 45 * k)

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

	-- the beams (Shared/SecretReveal.PILLARS): few, then many, then converging. Each is a stack of plain Beams on one
	-- pair of attachments (LAYERS: wide and faint outside, thin and white-hot in the middle), so with nothing uploaded
	-- they still fall off softly; with the owner's pictures the outer layers scroll beam-glow at different speeds.
	local pillars = {}
	local nLayers = #Reveal.LAYERS
	for i, def in Reveal.PILLARS do
		local a0, a1 = anchor(), anchor()
		local tone = TONES[def.tone] or TONES.violet
		local pl = { def = def, i = i, a0 = a0, a1 = a1, layers = {}, strands = {}, seed = rnd:NextNumber() }
		-- thin beams keep only the inner layers, scaled so their outermost one is their whole width
		local first = if def.w >= 9 then 1 elseif def.w >= 5 then 2 else 3
		local outer = Reveal.LAYERS[first].share
		for li = first, nLayers do
			local L = Reveal.LAYERS[li]
			local pic = if li <= 3 then "BeamGlow" else nil
			local b = beam(a0, a1, tone[L.col], 1, pic, {
				TextureLength = ({ 7, 10, 5 })[li] or 8, TextureSpeed = ({ 0.45, -0.3, 1.1 })[li] or 0, Segments = 20,
			})
			table.insert(pl.layers, { b = b, share = L.share / outer, alpha = L.alpha, pulse = li == 2 or li == 3 })
		end
		if def.helix > 0 then -- strands winding round it: a helix of short curved Beams
			for j = 1, def.helix do
				local strand = { atts = {}, beams = {}, phase = (j - 1) * math.pi, col = STRAND[(j - 1) % 2 + 1] }
				local n = if def.w >= 15 then 14 else 9
				for q = 0, n do strand.atts[q] = anchor() end
				for q = 0, n - 1 do
					strand.beams[q] = beam(strand.atts[q], strand.atts[q + 1], strand.col, 1, nil, { Segments = 6 })
				end
				strand.n = n
				table.insert(pl.strands, strand)
			end
		end
		if def.crackle then -- the jagged white filament: straight pieces whose bends glide to new ones
			local n = 11
			pl.chain = { atts = {}, beams = {}, n = n, from = {}, to = {}, at = -1 }
			for q = 0, n do
				pl.chain.atts[q] = anchor()
				pl.chain.from[q], pl.chain.to[q] = 0, 0
			end
			for q = 0, n - 1 do
				pl.chain.beams[q] = beam(pl.chain.atts[q], pl.chain.atts[q + 1], seq(WHITE, rgb(255, 225, 255)), 1, nil, { Segments = 1 })
			end
			if FxTexture.ready("Lightning") then -- (his lightning picture along the whole beam once uploaded)
				pl.bolt = beam(a0, a1, WHITE, 1, "Lightning", { TextureLength = 10, TextureSpeed = 1.5, Segments = 24 })
			end
		end
		if def.w >= 6 then
			-- sparks shedding off along it, and a pool of light where it meets the floor
			pl.sparkPart = part({ Name = "BeamSparks", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground) }, folder)
			pl.sparks = emitter(pl.sparkPart, { Picture = { "Spark" }, Color = seq(WHITE, tone[3], tone[2]), LightEmission = 1, Brightness = 2,
				Orientation = Enum.ParticleOrientation.VelocityParallel, Size = nseq({ { 0, 0.45 * k }, { 1, 0.1 } }),
				Squash = nseq({ { 0, 1 }, { 1, 2.2 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.35, 0.8), Speed = NumberRange.new(5 * k, 12 * k), Drag = 2.5,
				SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 5 * k, 0) })
			pl.pool = part({ Name = "BeamPool", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = tone[2],
				Size = Vector3.new(0.1, 1, 1), Transparency = 1 }, folder)
		end
		if def.ladder and FxTexture.ready("BeamLadder") then -- (his ladder picture once uploaded)
			pl.ladderSkin = beam(a0, a1, rgb(255, 190, 255), 1, "BeamLadder", { TextureLength = 18, TextureSpeed = -1.6 })
		end
		pillars[i] = pl
		if def.ladder then pillars.ladder = pl end
	end
	-- the ladder rungs climbing beam A (the reference's 1.6 s): short glowing bars across it, a white core in each
	local rungs = {}
	for i = 1, 9 do
		local a0, a1 = anchor(), anchor()
		table.insert(rungs, { i = i, a0 = a0, a1 = a1, glow = beam(a0, a1, rgb(230, 90, 255), 1, nil, { Segments = 2, Transparency = ENDS }),
			core = beam(a0, a1, rgb(255, 225, 255), 1, nil, { Segments = 2, Transparency = ENDS }) })
	end
	-- a point on a beam's curve (Roblox's Beam: a cubic Bezier from Attachment0 along its X axis by CurveSize0 to
	-- Attachment1, arriving along its X axis by CurveSize1)
	local function bez(P0: Vector3, P1: Vector3, P2: Vector3, P3: Vector3, s: number): Vector3
		local u = 1 - s
		return P0 * (u * u * u) + P1 * (3 * u * u * s) + P2 * (3 * u * s * s) + P3 * (s * s * s)
	end
	-- how see-through a layer is along its length (0 = foot, 1 = top): soft at the foot, fading into the sky at the
	-- top, with bright bands where the pulses are (at most 14 keypoints: Roblox allows 20)
	local function layerSeq(alpha: number, bands: { number }?): NumberSequence
		local function tr(a) return math.clamp(1 - a, 0, 1) end
		local keys = { NumberSequenceKeypoint.new(0, tr(alpha * 0.55)), NumberSequenceKeypoint.new(0.07, tr(alpha)) }
		local last = 0.07
		for _, c in bands or {} do
			if c - 0.06 > last + 0.005 and c + 0.06 < 0.81 then
				table.insert(keys, NumberSequenceKeypoint.new(c - 0.06, tr(alpha)))
				table.insert(keys, NumberSequenceKeypoint.new(c, tr(math.min(1, alpha * 2.4 + 0.15))))
				table.insert(keys, NumberSequenceKeypoint.new(c + 0.06, tr(alpha)))
				last = c + 0.06
			end
		end
		table.insert(keys, NumberSequenceKeypoint.new(0.82, tr(alpha * 0.9)))
		table.insert(keys, NumberSequenceKeypoint.new(1, 1))
		return NumberSequence.new(keys)
	end
	local spinAngle, lastSpinT = 0, nil :: number?

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
	local eyeAt = orbAt + Vector3.new(0, (hi - lo) * 0.12, 0)
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
	-- (without the soft glow picture a streak is a flat bar, so it is drawn thinner until that picture is uploaded)
	local streakW = if FxTexture.ready("BeamGlow") then 1 else 0.45
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
	local swarm = emitter(swarmBox, { Picture = { "Butterfly", "Loop", 14 }, Color = seq(rgb(200, 130, 255), rgb(255, 110, 210)),
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

	-- rings of short neon pieces (no picture needed): the shockwaves, the landing ring and the magic circle
	local function newRing(color, n)
		local bits = {}
		for i = 1, n or 28 do bits[i] = part({ Name = "RingBit", Material = Enum.Material.Neon, Color = color, Size = Vector3.one * 0.05, Transparency = 1 }, folder) end
		return bits
	end
	local ringShown = {} -- (which rings are showing, keyed by the ring's own table: never by an Instance)
	local function setRing(bits, centre, ax, ay, radius, thick, alpha, turn)
		if alpha <= 0.01 then -- (hidden: touch nothing more once every piece is see-through)
			if ringShown[bits] then
				for _, p in bits do p.Transparency = 1 end
				ringShown[bits] = false
			end
			return
		end
		ringShown[bits] = true
		local len = 2 * math.pi * radius / #bits * 1.1
		for i, p in bits do
			local a = (i - 0.5) / #bits * math.pi * 2 + (turn or 0)
			local out = ax * math.cos(a) + ay * math.sin(a)
			p.CFrame = CFrame.fromMatrix(centre + out * radius, -ax * math.sin(a) + ay * math.cos(a), out)
			p.Size = Vector3.new(math.max(len, 0.05), math.max(thick, 0.05), math.max(thick * 0.5, 0.05))
			p.Transparency = 1 - alpha
		end
	end
	local rings = {
		impact = newRing(rgb(200, 240, 255), 36), -- on the floor, racing out from the burst
		impactFace = newRing(rgb(255, 200, 250)), -- facing you, round the burst
		land = newRing(rgb(255, 150, 220)), -- on the floor as she lands
		burst = newRing(rgb(255, 70, 110), 32), -- facing you, the last burst
		burstFloor = newRing(rgb(255, 120, 200), 36), -- on the floor, the last burst
		circleIn = newRing(rgb(200, 150, 255), 30), -- the magic circle under her (two rings turning opposite ways)
		circleOut = newRing(rgb(150, 110, 255), 40),
	}
	local function ringAt(bits, at, life, t, centre, ax, ay, r0, r1, thick)
		local x = (t - at) / life
		if x < 0 or x > 1 then setRing(bits, centre, ax, ay, r0, thick, 0); return end
		setRing(bits, centre, ax, ay, r0 + (r1 - r0) * (1 - (1 - x) ^ 3), thick * (1 - 0.6 * x), 1 - x * x)
	end
	-- the magic circle's six diamonds riding its outer ring
	local gems = {}
	for i = 1, 6 do gems[i] = part({ Name = "CircleGem", Material = Enum.Material.Neon, Color = rgb(235, 210, 255), Size = Vector3.one * 0.05, Transparency = 1 }, folder) end

	local dome = part({ Name = "Dome", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = PINK, Size = Vector3.one * 2, CFrame = CFrame.new(ground), Transparency = 1 }, folder)
	local shockDome = part({ Name = "ShockDome", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = rgb(210, 170, 255), Size = Vector3.one * 2, CFrame = CFrame.new(orbAt), Transparency = 1 }, folder)
	local hiStroke = Instance.new("Highlight")
	hiStroke.FillColor, hiStroke.OutlineColor = WHITE, WHITE
	hiStroke.FillTransparency, hiStroke.OutlineTransparency = 1, 1
	hiStroke.DepthMode = Enum.HighlightDepthMode.Occluded
	hiStroke.Adornee = model
	hiStroke.Parent = folder
	local RIM = rgb(215, 185, 255) -- (her outline after the white flash: a soft violet rim, so she reads against the night)

	-- her name on screen (owner's look: Gotham Heavy Italic, white with a dark outline, the rarity in its colour):
	-- SECRET and 7 stars, her name big, a line drawing out under it, on a soft dark band so it reads over the effects
	local girlName = model:GetAttribute("GirlName")
	local rating = model:FindFirstChild("Rating", true)
	if type(girlName) ~= "string" or girlName == "" then
		local first = rating and rating:FindFirstChildOfClass("TextLabel")
		girlName = if first and first.Text ~= "" then first.Text else "Secret girl"
	end
	local ratingWas = if rating and rating:IsA("BillboardGui") then rating.Enabled else nil
	local function font(weight, italic)
		local ok, f = pcall(function()
			return Font.new("rbxasset://fonts/families/GothamSSm.json", weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
		end)
		return if ok then f else nil
	end
	local nameGui = Instance.new("ScreenGui")
	nameGui.Name, nameGui.IgnoreGuiInset, nameGui.DisplayOrder, nameGui.Enabled, nameGui.ResetOnSpawn = "HuzzSecretName", true, 55, false, false
	local card = Instance.new("Frame")
	card.Name, card.AnchorPoint, card.Position, card.Size, card.BackgroundTransparency = "Card", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.86, 0.2), 1
	card.Parent = nameGui
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = card
	local band = Instance.new("Frame")
	band.Name, band.AnchorPoint, band.Position, band.Size = "Band", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52), UDim2.fromScale(1, 0.9)
	band.BackgroundColor3, band.BorderSizePixel, band.BackgroundTransparency = rgb(14, 8, 36), 0, 1
	local bandFade = Instance.new("UIGradient") -- (dark in the middle, gone at both ends)
	bandFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) })
	bandFade.Parent = band
	band.Parent = card
	local function cardText(name, text, y, h, color, weight, italic, maxSize, stroke)
		local l = Instance.new("TextLabel")
		l.Name, l.AnchorPoint, l.Position, l.Size, l.BackgroundTransparency = name, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, y), UDim2.fromScale(1, h), 1
		l.Text, l.TextColor3, l.TextScaled, l.TextTransparency = text, color, true, 1
		local f = font(weight, italic)
		if f then l.FontFace = f end
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = l
		local s = Instance.new("UIStroke")
		s.Name, s.Thickness, s.Color, s.Transparency = "Outline", stroke, rgb(20, 12, 44), 1
		s.Parent = l
		l.Parent = card
		return l, s
	end
	local tagLabel, tagStroke = cardText("Tag", "SECRET  " .. string.rep("★", 7), 0.17, 0.26, rgb(196, 160, 255), Enum.FontWeight.Bold, false, 30, 2)
	local nameLabel, nameStroke = cardText("Name", string.upper(girlName), 0.55, 0.58, WHITE, Enum.FontWeight.Heavy, true, 84, 3.5)
	local line = Instance.new("Frame")
	line.Name, line.AnchorPoint, line.Position, line.Size = "Line", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.9), UDim2.new(0, 0, 0, 4)
	line.BackgroundColor3, line.BorderSizePixel, line.BackgroundTransparency = rgb(215, 185, 255), 0, 1
	local lineFade = Instance.new("UIGradient")
	lineFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	lineFade.Parent = line
	line.Parent = card
	table.insert(junk, nameGui)

	-- the grade (our own, on top of the game's look)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HuzzSecretGrade"
	table.insert(junk, grade)

	local all = { rush, hit.star, hit.sparks, hit.shards, hit.streaks, burst2.star, burst2.sparks, burst2.shards, burst2.streaks, spark0, shock, ringBurst,
		cloud, swarm, groundRing, landRing, sigil, dust, smoke, motes, motesCyan, crystals, butterflies }
	for _, e in hazes do table.insert(all, e) end
	for _, pl in pillars do
		if pl.sparks then table.insert(all, pl.sparks) end
	end
	local fired = {}
	local function once(name, fn)
		if not fired[name] then fired[name] = true; fn() end
	end
	-- the night's haze, smoke and the burst's cloud fade out with the night (Roblox applies an emitter's
	-- Transparency to particles already out), so no purple smoke is left hanging in the morning sky
	local nightOnly = {}
	for _, e in hazes do table.insert(nightOnly, { e = e, base = e.Transparency }) end
	table.insert(nightOnly, { e = smoke, base = smoke.Transparency })
	table.insert(nightOnly, { e = cloud, base = cloud.Transparency })
	local function fadeNightOnly(n: number)
		for _, f in nightOnly do
			local keys = {}
			for i, kp in f.base.Keypoints do keys[i] = NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * n) end
			f.e.Transparency = NumberSequence.new(keys)
		end
	end
	local ambientRates = { [motes] = 18, [motesCyan] = 8, [crystals] = 7, [butterflies] = 2.5 }
	for _, e in hazes do ambientRates[e] = 1.2 end

	local function step(t: number, dir: Vector3, cam: CFrame?)
		local calm = Motion.reduced
		keyLight.Enabled = t >= Reveal.IMPACT
		rimLight.Enabled = keyLight.Enabled
		if keyLight.Enabled then
			local at = model:GetPivot().Position
			keyPart.CFrame = CFrame.new(at + dir * 6 * k + up * mid * 0.4)
			rimPart.CFrame = CFrame.new(at - dir * 5 * k + up * mid * 0.9)
		end
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
		local herMid = spot + Vector3.new(0, (h or Reveal.ORB_HEIGHT) * k, 0) + Vector3.new(0, (lo + hi) / 2 - base.Position.Y, 0)
		heart.CFrame = CFrame.new(herMid)
		swarmBox.CFrame = CFrame.lookAt(herMid + (camPos - herMid) * 0.3, camPos)

		-- the night and the air
		local night = Reveal.night(t)
		for _, s in saved do
			(s.inst :: any)[s.key] = lerp(s.was, s.target, night)
		end
		Lighting.ClockTime = Reveal.clock(t, day)
		if t >= Reveal.DAWN then fadeNightOnly(night) end
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
		local conv = Reveal.converge(t) -- (and comes back as a white-hot point where the beams converge)
		core.Transparency = if orbSize > 0 then 1 - math.max(1 - melt, conv) else 1
		shell.Transparency = if orbSize > 0 then 0.2 + 0.8 * melt else 1
		core.Size = Vector3.one * math.max(orbSize * (1 + 0.6 * conv), 0.05) * k
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
				Sfx.beat("Build") -- (Config/SecretSounds: riser + magic bed)
			end)
		end
		if t >= Reveal.SPARK then once("spark", function() spark0:Emit(1) end) end

		-- the beams: struck from the sky, bowing outwards, all leaning a little to the right (the reference); then
		-- their feet swing into the eyes' point and they pinch thin there (converge), and they're gone after the burst
		local spinDt = math.clamp(t - (lastSpinT or t), 0, 0.1)
		lastSpinT = t
		spinAngle += spinDt * ((if calm then 2 else 5) + 13 * conv) -- (the strands wind faster as they converge)
		local rightV = -side -- (right on your screen)
		local toCam = (camPos - orbAt).Unit
		local anyLit = 0
		for _, pl in pillars do
			local d = pl.def
			local reach, power = Reveal.beam(t, d.at)
			if power <= 0 then -- (not struck yet, or gone: hide it once and leave it alone)
				if not pl.hidden then
					pl.hidden = true
					for _, L in pl.layers do setWidth(L.b, 0, 0) end
					for _, st in pl.strands do
						for _, b in st.beams do setWidth(b, 0, 0) end
					end
					if pl.chain then
						for _, b in pl.chain.beams do setWidth(b, 0, 0) end
					end
					if pl.bolt then setWidth(pl.bolt, 0, 0) end
					if pl.ladderSkin then setWidth(pl.ladderSkin, 0, 0) end
					if pl.sparks then pl.sparks.Rate = 0; pl.pool.Transparency = 1 end
				end
				continue
			end
			pl.hidden = false
			anyLit = math.max(anyLit, power)
			local foot = ground + rightV * d.x * k + dir * d.z * k
			local top = foot + up * d.tall * k + rightV * 0.06 * d.tall * k
			local low = top + (foot - top) * math.max(reach, 0.02)
			low = low:Lerp(orbAt, conv)
			local outv = if d.x >= 0 then rightV else -rightV
			local lean = math.rad(d.lean)
			local r0 = up * math.cos(lean) + outv * math.sin(lean)
			local r1 = up * math.cos(lean) - outv * math.sin(lean)
			pl.a0.WorldCFrame = CFrame.fromMatrix(low, r0, dir)
			pl.a1.WorldCFrame = CFrame.fromMatrix(top, r1, dir)
			local cv = (top - low).Magnitude * d.bow * (1 - conv)
			local W = d.w * k * math.sqrt(power) * (1 + 0.05 * math.sin(t * 6 + pl.seed * 10)) -- (a slow breath, not a flicker)
			local pinch = 1 - 0.75 * conv
			local bands = Reveal.pulses(t, pl.seed)
			for _, L in pl.layers do
				L.b.CurveSize0, L.b.CurveSize1 = cv, cv
				setWidth(L.b, W * L.share * pinch, W * L.share * 0.8)
				L.b.Transparency = if power > 0 then layerSeq(L.alpha * power, if L.pulse then bands else nil) else NumberSequence.new(1)
			end
			if pl.bolt then pl.bolt.CurveSize0, pl.bolt.CurveSize1 = cv, cv; setWidth(pl.bolt, W * 0.12 * pinch, W * 0.1) end
			if pl.ladderSkin then
				local lv0 = Reveal.ladder(t)
				pl.ladderSkin.CurveSize0, pl.ladderSkin.CurveSize1 = cv, cv
				setWidth(pl.ladderSkin, W * 0.45 * lv0, W * 0.36 * lv0)
			end
			local P0, P1, P2, P3 = low, low + r0 * cv, top - r1 * cv, top
			pl.curve = { P0, P1, P2, P3 }
			-- the strands winding round it (dimmer where they pass behind it)
			for _, st in pl.strands do
				local pts = {}
				for q = 0, st.n do
					local s = q / st.n
					local p = bez(P0, P1, P2, P3, s)
					local tan = bez(P0, P1, P2, P3, math.min(1, s + 0.02)) - bez(P0, P1, P2, P3, math.max(0, s - 0.02))
					tan = if tan.Magnitude > 1e-3 then tan.Unit else up
					local nv = tan:Cross(toCam)
					nv = if nv.Magnitude > 1e-3 then nv.Unit else rightV
					local bv = nv:Cross(tan)
					local th = math.pi * 2 * 2.5 * s + spinAngle + st.phase
					local r = W * 0.3 * (1 - 0.5 * conv) * (1 - 0.35 * s) * Reveal.smooth(s / 0.15) -- (tucked in at the foot)
					pts[q] = { p = p + (nv * math.cos(th) + bv * math.sin(th)) * r, front = math.sin(th) }
				end
				for q = 0, st.n do
					local a, b = pts[math.max(0, q - 1)].p, pts[math.min(st.n, q + 1)].p
					local tan = b - a
					tan = if tan.Magnitude > 1e-3 then tan.Unit else up
					local yv = tan:Cross(toCam)
					yv = if yv.Magnitude > 1e-3 then yv.Unit else rightV
					st.atts[q].WorldCFrame = CFrame.fromMatrix(pts[q].p, tan, yv)
				end
				for q = 0, st.n - 1 do
					local b = st.beams[q]
					local cs = (pts[q + 1].p - pts[q].p).Magnitude / 3
					b.CurveSize0, b.CurveSize1 = cs, cs
					local s = q / st.n
					local depth = 0.55 + 0.45 * math.clamp((pts[q].front + 1) / 2, 0, 1)
					local wq = (0.6 - 0.35 * s) * k * math.sqrt(power) * (if d.w >= 15 then 1 else 0.7)
					setWidth(b, wq, wq * 0.9)
					b.Transparency = NumberSequence.new(math.clamp(1 - power * depth * (1 - 0.65 * s) * Reveal.smooth(s / 0.1), 0, 1))
				end
			end
			-- the jagged white filament: each bend glides to a new one every 0.11 s (no snapping: a shimmer)
			local ch = pl.chain
			if ch then
				if not calm and t - ch.at > 0.11 then
					ch.at = t
					for q = 0, ch.n do ch.from[q], ch.to[q] = ch.to[q], rnd:NextNumber(-1, 1) end
				end
				local x = Reveal.smooth((t - ch.at) / 0.11)
				local amp = W * 0.1 * (1 - 0.5 * conv)
				for q = 0, ch.n do
					local s = q / ch.n
					local p = bez(P0, P1, P2, P3, s)
					local tan = bez(P0, P1, P2, P3, math.min(1, s + 0.02)) - bez(P0, P1, P2, P3, math.max(0, s - 0.02))
					local nv = (if tan.Magnitude > 1e-3 then tan.Unit else up):Cross(toCam)
					nv = if nv.Magnitude > 1e-3 then nv.Unit else rightV
					local j = if q == 0 or q == ch.n then 0 else ch.from[q] + (ch.to[q] - ch.from[q]) * x
					ch.atts[q].WorldPosition = p + nv * j * amp
				end
				for q = 0, ch.n - 1 do
					setWidth(ch.beams[q], 0.5 * k * math.sqrt(power) * pinch, 0.5 * k * math.sqrt(power))
					ch.beams[q].Transparency = NumberSequence.new(if power > 0 then 1 - power * (1 - 0.5 * q / ch.n) else 1)
				end
			end
			-- sparks shedding off along it, a pool of light on the floor, and a shower where it strikes
			if pl.sparks then
				local len = (top - low).Magnitude
				pl.sparkPart.CFrame = CFrame.fromMatrix((low + top) / 2, rightV, (top - low).Unit)
				pl.sparkPart.Size = Vector3.new(math.max(W * 0.2, 0.05), math.max(len * 0.85, 0.05), math.max(W * 0.2, 0.05))
				pl.sparks.Rate = if stop or power < 0.3 then 0 else (if d.w >= 15 then 26 else 10) * power
				pl.pool.CFrame = CFrame.new(foot + up * 0.12) * CFrame.Angles(0, 0, math.pi / 2)
				local D = math.max(W * 0.75 * (0.6 + 0.4 * reach), 0.05)
				pl.pool.Size = Vector3.new(0.1, D, D)
				pl.pool.Transparency = 1 - 0.3 * power * (1 - conv)
				if t >= d.at + 0.15 then once("strike" .. pl.i, function() pl.sparks:Emit(if d.w >= 15 then 24 else 10) end) end
			end
		end
		if t >= Reveal.BEAM_A then once("strikeA", function() hit.shards:Emit(10); hit.sparks:Emit(12) end) end
		if t >= Reveal.BEAM_B then once("strikeB", function() hit.shards:Emit(8); hit.sparks:Emit(10) end) end
		-- the beams light the floor round the spot (violet, stronger as they converge)
		beamLight.Enabled = anyLit > 0
		beamPart.CFrame = CFrame.new(orbAt)
		beamLight.Brightness = anyLit * (1.2 + 2 * conv)
		-- the ladder rungs climb beam A
		local lv = Reveal.ladder(t)
		local A = pillars.ladder
		local half = (A.def.w * 0.32) * k
		for _, r in rungs do
			local u = ((t * 0.6 + r.i / #rungs) % 1)
			local c = A.curve or { ground, ground, ground + up, ground + up }
			local p = bez(c[1], c[2], c[3], c[4], u)
			local fade = math.sin(u * math.pi) -- (fading in at the foot, out at the top)
			r.a0.WorldPosition = p - rightV * half
			r.a1.WorldPosition = p + rightV * half
			setWidth(r.glow, 2.8 * k * lv * fade)
			setWidth(r.core, 0.9 * k * lv * fade)
		end

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
		local lv2 = 0.4 * Reveal.pop(t, Reveal.FLARE - 0.1, 0.1, 0.45) -- (soft: her name is up)
		if bv > iv then rv, rc, rs, rcol = bv, herMid, 1.6, rgb(255, 35, 75) else rv = iv end
		-- (the name's flare and rays sit behind her head, so they frame her instead of covering her)
		local behindHead = herMid + up * mid * 0.7 - (camPos - herMid).Unit * 3 * k
		if lv2 > rv then rv, rc, rs, rcol = lv2, behindHead, 1.3, rgb(200, 130, 255) end
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
		local nameFlare = Reveal.pop(t, Reveal.FLARE - 0.1, 0.1, 0.5)
		local fv = math.max(nameFlare, grow, Reveal.pop(t, Reveal.BURST, 0.04, 0.6), sparkV)
		local fs = if t >= Reveal.BURST then 2.6 elseif grow > 0 then 0.6 + 1.6 * grow elseif sparkV > 0 then 0.9 else 1.5
		local glintOn = Reveal.pop(t, Reveal.GLINT, 0.08, 0.35)
		if glintOn > fv then -- (the eye glint in the close-up: a small flare by her face)
			local face = herMid + up * (mid - 1.9 * k) + dir * 1.6 * k + side * 0.35 * k
			setFlare(flares[1], face, 0.7 * k, glintOn, camR, camU, rgb(255, 90, 170), 0.2)
		else
			local at = if nameFlare > 0 and nameFlare >= fv then behindHead else herMid + up * 1.5 * k + (camPos - herMid).Unit * 2 * k
			setFlare(flares[1], at, fs * k, fv, camR, camU,
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
			setWidth(sl.b, sl.w * D * 0.05 * sv * 4 * streakW, 0)
		end

		-- the shockwaves: a ring racing out over the floor and one facing you at the burst, a dome swelling out of the
		-- point; the landing ring; at the last burst a ring facing you round her and one on the floor
		ringAt(rings.impact, Reveal.IMPACT, 0.6, t, ground + up * 0.4, side, dir, 3 * k, 44 * k, 0.7 * k)
		ringAt(rings.impactFace, Reveal.IMPACT, 0.45, t, orbAt, camR, camU, 3 * k, 26 * k, 0.8 * k)
		ringAt(rings.land, Reveal.LAND, 0.5, t, ground + up * 0.4, side, dir, 3 * k, 16 * k, 0.45 * k)
		ringAt(rings.burst, Reveal.BURST, 0.6, t, herMid, camR, camU, 4 * k, 30 * k, 1 * k)
		ringAt(rings.burstFloor, Reveal.BURST, 0.7, t, ground + up * 0.4, side, dir, 4 * k, 40 * k, 0.6 * k)
		do
			local x = (t - Reveal.IMPACT) / 0.5
			shockDome.CFrame = CFrame.new(orbAt)
			shockDome.Size = Vector3.one * math.max((2 + 32 * (1 - (1 - math.clamp(x, 0, 1)) ^ 3)) * k, 0.1)
			shockDome.Transparency = if x < 0 or x >= 1 then 1 else 0.1 + 0.9 * x
		end
		-- the magic circle under her, from the landing until she rises: two rings turning opposite ways, six
		-- diamonds riding the outer one; it breathes slowly (never blinks)
		local cv = math.min(Reveal.smooth((t - Reveal.LAND) / 0.3), 1 - Reveal.smooth((t - Reveal.RISE) / 0.5))
		local circleA = if cv > 0 then cv * (0.72 + 0.08 * math.sin(t * 2.5)) else 0
		local floorAt = ground + up * 0.3
		setRing(rings.circleIn, floorAt, side, dir, 6.5 * k, 0.28 * k, circleA, t * 0.6)
		setRing(rings.circleOut, floorAt, side, dir, 9 * k, 0.36 * k, circleA * 0.85, -t * 0.4)
		for i, g in gems do
			local a = (i - 1) / #gems * math.pi * 2 - t * 0.4
			local out = side * math.cos(a) + dir * math.sin(a)
			g.CFrame = CFrame.fromMatrix(floorAt + out * 9 * k, out, up) * CFrame.Angles(0, math.rad(45), 0)
			g.Size = Vector3.new(0.9 * k, 0.15 * k, 0.9 * k)
			g.Transparency = 1 - circleA
		end
		-- her name on screen (Shared/SecretReveal.name): pops in a touch big, the line draws out, fades by the cut
		local nv = Reveal.name(t)
		nameGui.Enabled = nv > 0
		if nv > 0 then
			local x = math.clamp((t - Reveal.NAME) / 0.25, 0, 1)
			pop.Scale = 1.18 - 0.18 * (1 - (1 - x) ^ 3)
			local tagIn = math.clamp((t - Reveal.NAME - 0.12) / 0.2, 0, 1) * nv
			nameLabel.TextTransparency, nameStroke.Transparency = 1 - nv, 1 - nv
			tagLabel.TextTransparency, tagStroke.Transparency = 1 - tagIn, 1 - tagIn
			band.BackgroundTransparency = 1 - 0.85 * nv
			line.Size = UDim2.new(0.5 * Reveal.smooth((t - Reveal.NAME - 0.1) / 0.35), 0, 0, 4)
			line.BackgroundTransparency = 1 - nv
		end
		-- her name over her head (the showcase's own label) waits until she rises
		if ratingWas ~= nil then (rating :: BillboardGui).Enabled = ratingWas and t >= Reveal.RISE + 0.3 end
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
				Sfx.beat("Burst") -- (the hit + sparkle tail; cuts the riser)
			end)
			-- the white flash on her fades to a soft violet rim that stays while she's on the ground, gone as she rises
			local x = math.clamp((t - Reveal.IMPACT - 0.1) / 0.35, 0, 1)
			local rimOut = Reveal.smooth((t - Reveal.RISE) / 0.8)
			hiStroke.FillTransparency = x
			hiStroke.OutlineColor = WHITE:Lerp(RIM, x)
			hiStroke.OutlineTransparency = 0.3 * (1 - x) + 0.5 * x + 0.5 * rimOut
		end
		if t >= Reveal.LAND then
			once("land", function()
				if FxTexture.ready("RingSoft") then landRing:Emit(1) end
				dust:Emit(14)
				smoke:Emit(16)
				Sfx.beat("Reveal") -- (the sting as she lands and poses)
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
				cloud:Emit(14) -- (fewer: she rises out of it)
				if FxTexture.ready("RingSoft") then ringBurst:Emit(1) end
				Sfx.play("secret_impact")
			end)
		end
		-- her: hidden until the impact, then dropping, standing, rising (facing the camera, then turning slowly)
		if h then
			local S = Config.Showcase
			-- (she drops turned a little away and settles round to face you by the time her name is up)
			local settle = math.rad(-18) * (1 - Reveal.smooth((t - Reveal.LAND) / 0.9))
			local yaw = settle + math.max(0, t - Reveal.RISE) * (S.Spin or 0.35)
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
		nameGui:Destroy()
		if ratingWas ~= nil then pcall(function() (rating :: BillboardGui).Enabled = ratingWas end) end
		for _, b in beams do b:Destroy() end
		for _, a in anchors do a:Destroy() end
	end
	if M.failForTest then error("test: build failed on purpose") end
	-- last of all, into Lighting and the screen (nothing there to undo if anything above failed)
	frameGui.Parent = if player then player:WaitForChild("PlayerGui") else nil
	nameGui.Parent = frameGui.Parent
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
		-- (a streaming place can hand us her model before her parts: wait for them, at most 2 s)
		local waitUntil = os.clock() + 2
		while not model:FindFirstChildWhichIsA("BasePart", true) and os.clock() < waitUntil do
			task.wait(0.05)
		end
		model:SetAttribute("HuzzRevealing", true) -- (Gameplay/CarryAnimator leaves her to us meanwhile)
		pcall(function() require(script.Parent.Music).quiet(Reveal.LENGTH) end) -- (the songs fade out under it)
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
		-- (your camera's distance from your character before the cutscene: the hand-back puts it back at that distance)
		local startDist = if root then (startCF.Position - (root.Position + Vector3.new(0, 1.5, 0))).Magnitude else 12
		if startDist < 2 or startDist > 60 then startDist = 12 end -- (first person or a far shot: Roblox's usual)
		local from = if root then root.Position - ground else Vector3.new(0, 0, 1)
		local dir = Vector3.new(from.X, 0, from.Z)
		dir = if dir.Magnitude > 1 then dir.Unit else Vector3.new(0, 0, 1)
		player:SetAttribute("HuzzCinematic", true)
		camera.CameraType = Enum.CameraType.Scriptable
		local noise = math.random() * 100
		local reach, lastT = 1, nil :: number? -- (how much of the camera's distance from its look point is clear of walls)
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
		-- the dip to black for the hand-back (a plain black frame over everything; ours alone)
		local dip = Instance.new("ScreenGui")
		dip.Name = "HuzzRevealDip"
		dip.IgnoreGuiInset = true
		dip.ResetOnSpawn = false
		dip.DisplayOrder = 100
		local black = Instance.new("Frame")
		black.Size = UDim2.fromScale(1, 1)
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BackgroundTransparency = 1
		black.BorderSizePixel = 0
		black.Parent = dip
		dip.Parent = player:FindFirstChildOfClass("PlayerGui")
		local DOWN = 0.2 -- seconds to black after RETURN; the camera is handed back under it, then it lifts
		local LIFT = Reveal.LENGTH - Reveal.RETURN - DOWN -- (0.3 s)
		local HOLD_FRAMES = 2 -- frames of full black after the hand-back, so Roblox's camera has settled before we lift
		local done = false
		local handed = false -- the camera is Roblox's again (from the first fully black frame)
		local heldFrames = 0
		local liftFrom: number? = nil
		local function handBack()
			if handed then return end
			handed = true
			-- Under full black: put the camera behind where you stand NOW (your own camera's angle and distance from
			-- before the cutscene, over the shoulder only if shift lock will be on), give it back to Roblox and stop
			-- writing it. Roblox's camera keeps that angle, so the black lifts on the view you'll play with.
			pcall(function()
				local c = player.Character
				local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					local look = startCF.LookVector
					local focus = r.Position + Vector3.new(0, 1.5, 0)
					local okLock, ShiftLock = pcall(require, script.Parent.ShiftLock)
					if okLock and ShiftLock.wouldLock() then
						local flat = Vector3.new(look.X, 0, look.Z)
						flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
						focus += Vector3.new(-flat.Z, 0, flat.X) * ShiftLock.OFFSET.X
					end
					local dist = math.clamp(startDist, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
					camera.CFrame = CFrame.lookAt(focus - look * dist, focus)
				end
			end)
			camera.FieldOfView = startFov
			camera.CameraType = Enum.CameraType.Custom
			player:SetAttribute("HuzzCinematic", false)
		end
		local function finish()
			if done then return end
			done = true
			Sfx.beat("End") -- (fades what still rings)
			RunService:UnbindFromRenderStep("HuzzSecretReveal")
			dip:Destroy()
			pcall(cleanup)
			model:SetAttribute("HuzzRevealing", nil)
			handBack() -- (no-op when the dip already did it)
			playing = false
		end
		RunService:BindToRenderStep("HuzzSecretReveal", Enum.RenderPriority.Camera.Value + 3, function()
			if done then return end
			local t = Workspace:GetServerTimeNow() - at
			-- ends when the black has lifted; a safety stop if frames ran late
			if not model.Parent or (liftFrom and t - liftFrom >= LIFT) or t > Reveal.LENGTH + 0.5 then
				finish()
				return
			end
			local okStep, err = pcall(function()
				if t > Reveal.RETURN then -- dip to black, hand the camera back under it, hold, lift
					local x = t - Reveal.RETURN
					if x < DOWN then
						black.BackgroundTransparency = 1 - (x / DOWN) ^ 2
					else
						black.BackgroundTransparency = 0
						if not handed then
							handBack()
						elseif liftFrom then
							local up = math.clamp((t - liftFrom) / LIFT, 0, 1)
							black.BackgroundTransparency = up * up
						else
							heldFrames += 1
							if heldFrames >= HOLD_FRAMES then liftFrom = t end
						end
					end
				end
				if handed then -- the camera is Roblox's: only the scene's effects keep going
					step(t, dir, camera.CFrame)
					return
				end
				local h = Reveal.height(t, Config.Showcase.Height)
				local eye, look = Reveal.camera(math.min(t, Reveal.LENGTH), ground + Vector3.new(0, 0.5, 0), dir, h or Config.Showcase.Height, k, mid)
				eye = Vector3.new(eye.X, math.max(eye.Y, ground.Y + 1.5), eye.Z) -- (never under the floor)
				-- in front of walls: pulled in at once when something is in the way, eased back out once it's clear
				-- (a wall flicking in and out of the ray made the camera jump back and forth)
				local want = 1
				local full = eye - look
				if full.Magnitude > 0.5 then want = (clear(eye, look) - look).Magnitude / full.Magnitude end
				local dt = math.clamp(t - (lastT or t), 0, 0.1)
				for _, c in Reveal.CUTS do
					if lastT and lastT < c and t >= c then reach = want end -- (a fresh start on the cut)
				end
				lastT = t
				reach = if want < reach then want else reach + (want - reach) * math.min(1, dt * 5)
				eye = look + full * reach
				local cf = CFrame.lookAt(eye, look)
				local fov = Reveal.fov(t, Motion.reduced)
				if not Motion.reduced then -- (a slow, small wobble: Shared/SecretReveal.shakeAt)
					local rx, ry, rz, px, py = Reveal.shakeAt(t, noise)
					cf = cf * CFrame.new(px * k, py * k, 0) * CFrame.Angles(rx, ry, rz)
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
