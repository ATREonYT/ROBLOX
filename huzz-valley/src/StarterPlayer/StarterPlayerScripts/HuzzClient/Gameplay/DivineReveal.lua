--[[
	The Divine girl's arrival cutscene, "Heaven's Gate" (the timing, the shot and the camera: Shared/DivineReveal;
	owner, Oct 26: "make it completely different from the secret animation"; 17:42: "follow the animation styles as
	references given before, right now it looks too ai made"). Gameplay/SecretReveal plays it (its play() picks this one
	when the showcase's RevealKind is "Divine": the same camera planning, steady clock and hand-back), and this builds
	the effects and poses her. Drawn as the reference anime VFX are: a dark night, hard neon shapes with a white-hot
	core and a gold band (no soft haze, no smoke, no ForceField glow), fast in and snapping out:
	  the light   your Lighting, on this screen only: a deep blue night with stars, a dark haze, more bloom, a cool
	              hard grade and a vignette; all put back exactly afterwards
	  the sky     a gold portal draws itself over the spot: two huge rings, sun spikes and a white-hot core
	  spears      seven spears of light strike down round the spot, lightning crackling on each, a ring where it hits;
	              swallowed into the pillar when it falls
	  halo gate   three golden rings of neon pieces, gems and sun spikes; it comes down, spins up, closes in round her
	              and shrinks into her crown halo
	  sigil       a golden circle draws itself on the ground: three rings, a six-point star, spokes and rune marks
	  slashes     three gold slashes across the picture as the halo spins up
	  pillar      a hard pillar of light (four plain Beams, white in the middle, gold outside) slams down: the impact
	              frame, gold shards fly, a shockwave, rungs climb it
	  her         lit white as she appears, riding the pillar down with speed streaks rushing past, settling to a gold
	              rim; wings of light (16 feathers) snap open with three crescent swings round her, beat once, and fade
	              into sparkles as she rises
	  bursts      star flares and shards on the touchdown, a radial burst of gold blades from behind her at the ascension
	  her name    DIVINE and 8 stars in gold, her name with a shine sweeping over it, gold lines drawing out
	Flashes: the impact frame, a small swell on the touchdown and the burst (kid-safe: over a second apart).
	Reduced Motion (Settings): no swells and no impact frame. Nothing here needs an uploaded picture: every particle
	uses Roblox's built-in sparkle (Shared/FxTexture's stand-ins); the shapes are neon parts, plain beams and UI.
	Filmed offline: tools/preview/motion3d/secret_scene.luau with DIVINE=1.
]]
local M = {}

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local Reveal = require(Shared.DivineReveal)
local FxTexture = require(Shared.FxTexture)
local Motion = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local Sfx = require(script.Parent.Sfx)
local player = Players.LocalPlayer

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local CREAM, PALE, GOLD, AMBER = rgb(255, 248, 228), rgb(255, 234, 170), rgb(255, 198, 72), rgb(255, 160, 50)
local INK = rgb(12, 9, 4) -- the impact frame's ink
local SUN = rgb(255, 200, 48) -- saturated gold (critic, Oct 26: the paler mixes read as beige)

-- The night look (Lighting, on this screen only), blended in by Shared/DivineReveal.heaven: a deep blue night, not
-- the Secret one's violet, so the gold reads hard against it (the golden-dusk version washed into soft glow).
local HEAVEN_LOOK = {
	Lighting = { Ambient = rgb(30, 32, 58), OutdoorAmbient = rgb(44, 48, 88), Brightness = 1.1, EnvironmentDiffuseScale = 0.25 },
	Atmosphere = { Density = 0.4, Offset = 0.2, Color = rgb(36, 42, 96), Decay = rgb(12, 14, 46), Glare = 0, Haze = 2.4 },
	BloomEffect = { Intensity = 0.8, Size = 32, Threshold = 0.95 },
	SunRaysEffect = { Intensity = 0 },
	Sky = { StarCount = 5000, SunAngularSize = 0 },
	Clouds = { Cover = 0.3, Density = 0.5, Color = rgb(40, 46, 100) },
}
local TAPER = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })

local function seq(...)
	local list = { ... }
	local keys = {}
	for i, c in list do keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(#list - 1, 1), c) end
	return ColorSequence.new(keys)
end
local function nseq(list)
	local keys = {}
	for i, kp in list do keys[i] = NumberSequenceKeypoint.new(kp[1], math.clamp(kp[2], 0, 1), kp[3] or 0) end
	return NumberSequence.new(keys)
end
local function sizeSeq(list) -- (sizes go past 1, unlike transparency)
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

local function build(model: Model, base: CFrame, revealAt: number, junk: { Instance })
	local k = (Config.Showcase.Scale or 3) / 3
	local spot = base.Position - Vector3.new(0, Config.Showcase.Height, 0)
	-- her body's own top and bottom (as Gameplay/SecretReveal: not the showcase's aura box, stand or lamps)
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
	local ground = Vector3.new(spot.X, lo - Config.Showcase.Height, spot.Z)
	pcall(function() -- (the real floor under her, as Gameplay/SecretReveal)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { model }
		for _, name in { "HuzzSecretReveal", "HuzzDivineReveal", "HuzzAuraFX", "HuzzCarried", "HuzzFollowers" } do
			local f = Workspace:FindFirstChild(name)
			if f then table.insert(ignore, f) end
		end
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(ignore, p.Character) end
		end
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		local hit = Workspace:Raycast(Vector3.new(spot.X, lo - 1, spot.Z), Vector3.new(0, -(Config.Showcase.Height + 20), 0), params)
		if hit and math.abs(hit.Position.Y - ground.Y) < 16 then
			local lift = hit.Position.Y - ground.Y
			ground += Vector3.new(0, lift, 0)
			spot += Vector3.new(0, lift, 0)
		end
	end)
	local mid = (hi - lo) / 2
	local feetOff = lo - base.Position.Y -- (her feet under her pivot)
	local up = Vector3.new(0, 1, 0)
	local skyAt = ground + up * Reveal.SKY * k
	local floorAt = ground + up * 0.25
	local folder = Instance.new("Folder")
	folder.Name = "HuzzDivineReveal"
	folder.Parent = Workspace
	table.insert(junk, folder)

	-- her lights: a warm key light from the camera's side, a gold rim from behind and above; the pillar's glow on the
	-- ground
	local function lamp(name, color, brightness, range)
		local holder = part({ Name = name, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(ground) }, folder)
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Shadows, l.Enabled = color, brightness, range, false, false
		l.Parent = holder
		return holder, l
	end
	local keyPart, keyLight = lamp("KeyLight", rgb(255, 242, 220), 1.5, 24 * k)
	local rimPart, rimLight = lamp("RimLight", rgb(255, 204, 120), 1.6, 20 * k)
	local pillarPart, pillarLight = lamp("PillarLight", rgb(255, 240, 215), 0, 50 * k)
	pillarPart.CFrame = CFrame.new(ground + up * 4 * k)
	pillarLight.Enabled = true

	-- the light: remember every Lighting value we touch, make what's missing (and remove it after)
	local saved, made = {}, {}
	local function keep(inst: Instance, props)
		for key, target in props do
			local ok, was = pcall(function() return (inst :: any)[key] end)
			if ok and was ~= nil then table.insert(saved, { inst = inst, key = key, was = was, target = target }) end
		end
	end
	keep(Lighting, HEAVEN_LOOK.Lighting)
	local sky0 = Lighting:FindFirstChildOfClass("Sky")
	if sky0 then keep(sky0, HEAVEN_LOOK.Sky) end
	for _, cls in { "Atmosphere", "BloomEffect", "SunRaysEffect" } do
		local inst = Lighting:FindFirstChildOfClass(cls)
		if not inst then
			inst = Instance.new(cls)
			inst.Name = "HuzzDivine" .. cls
			if cls == "Atmosphere" then (inst :: any).Density, (inst :: any).Haze, (inst :: any).Glare = 0, 0, 0 end
			if cls == "BloomEffect" or cls == "SunRaysEffect" then (inst :: any).Intensity = 0 end
			table.insert(made, inst)
			table.insert(junk, inst)
		end
		keep(inst, HEAVEN_LOOK[cls])
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then keep(clouds, HEAVEN_LOOK.Clouds) end
	local day = Lighting.ClockTime

	-- beams (plain light: no picture needed)
	local anchors, beams = {}, {}
	local function anchor()
		local a = Instance.new("Attachment")
		a.Parent = Workspace.Terrain
		table.insert(anchors, a)
		table.insert(junk, a)
		return a
	end
	local function beam(a0, a1, color, props)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
		b.LightEmission, b.LightInfluence = 1, 0
		b.Texture = ""
		b.FaceCamera = true
		b.Segments = 8
		b.Width0, b.Width1 = 0, 0
		for key, v in props or {} do b[key] = v end
		b.Parent = Workspace.Terrain
		table.insert(beams, b)
		table.insert(junk, b)
		return b
	end
	-- a beam's see-through along it: `alpha` at its strongest, fading in over `head` at its start and out over the
	-- last `tail` (0..1 of its length); one NumberSequence per change, so only when it moved on
	local function along(alpha: number, head: number, tail: number, top: number?): NumberSequence
		local a = math.clamp(alpha, 0, 1)
		return nseq({ { 0, 1 - a * (top or 0) }, { head, 1 - a }, { 1 - tail, 1 - a }, { 1, 1 } })
	end
	local lastAlpha = {}
	local function setAlpha(b: Beam, alpha: number, head: number, tail: number, top: number?)
		local q = math.floor(alpha * 60 + 0.5)
		if lastAlpha[b] == q then return end
		lastAlpha[b] = q
		b.Transparency = along(q / 60, head, tail, top)
	end

	-- the sky: a white-hot core in a gold portal (the rings and spikes are drawn in the step)
	local disc = part({ Name = "PortalCore", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = CREAM,
		Size = Vector3.new(0.4, 1, 1), CFrame = CFrame.new(skyAt) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }, folder)
	local portalSpikes = {}
	for i = 1, 16 do
		portalSpikes[i] = part({ Name = "PortalSpike", Material = Enum.Material.Neon, Color = if i % 2 == 0 then PALE else GOLD, Size = Vector3.one * 0.05, Transparency = 1 }, folder)
	end

	-- the spears: each a white core in a hard gold band, a jagged lightning thread round it (each bend jumps to a new
	-- place every 0.07 s: a crackle, not a screen flash), sparks where it hits
	local spears = {}
	local spearRnd = Random.new(31)
	for i, def in Reveal.RAY_FEET do
		local a0, a1 = anchor(), anchor()
		local sp = {
			def = def, a0 = a0, a1 = a1, at = -1, n = 9, atts = {}, bolts = {}, off = {},
			glow = beam(a0, a1, seq(SUN, GOLD, AMBER), { Segments = 2 }),
			core = beam(a0, a1, seq(WHITE, CREAM), { Segments = 2 }),
		}
		for q = 0, sp.n do
			sp.atts[q] = anchor()
			sp.off[q] = spearRnd:NextNumber(-1, 1)
		end
		for q = 0, sp.n - 1 do sp.bolts[q] = beam(sp.atts[q], sp.atts[q + 1], seq(WHITE, PALE), { Segments = 1 }) end
		sp.hit = part({ Name = "SpearFoot", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground) }, folder)
		sp.sparks = emitter(sp.hit, { Picture = { "Spark" }, Color = seq(WHITE, PALE, GOLD), LightEmission = 1, Brightness = 2,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0.6 * k }, { 1, 0.15 * k } }),
			Squash = sizeSeq({ { 0, 1 }, { 0.3, 2.5 }, { 1, 3 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(20 * k, 36 * k), Drag = 5, SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top })
		spears[i] = sp
	end

	-- rings of short neon pieces (as Gameplay/SecretReveal), drawn round from the front: `upto` (0..1) of it showing
	local ringShown, ringColor = {}, {}
	local function newRing(color, n)
		local bits = {}
		for i = 1, n or 32 do bits[i] = part({ Name = "RingBit", Material = Enum.Material.Neon, Color = color, Size = Vector3.one * 0.05, Transparency = 1 }, folder) end
		ringColor[bits] = color
		return bits
	end
	local function setRing(bits, centre, ax, ay, radius, thick, alpha, turn, upto)
		if alpha <= 0.01 or (upto or 1) <= 0 then
			if ringShown[bits] then
				for _, p in bits do p.Transparency = 1 end
				ringShown[bits] = false
			end
			return
		end
		ringShown[bits] = true
		local len = 2 * math.pi * radius / #bits * 1.1
		local n = #bits
		for i, p in bits do
			local share = (i - 0.5) / n
			if share > (upto or 1) then
				p.Transparency = 1
				continue
			end
			local a = share * math.pi * 2 + (turn or 0)
			local out = ax * math.cos(a) + ay * math.sin(a)
			p.CFrame = CFrame.fromMatrix(centre + out * radius, -ax * math.sin(a) + ay * math.cos(a), out)
			p.Size = Vector3.new(math.max(len, 0.05), math.max(thick, 0.05), math.max(thick * 0.5, 0.05))
			-- (the newest piece of a ring being drawn glows brightest: the pen's tip)
			local tip = if upto and upto < 1 then math.clamp(1 - ((upto - share) * n) / 4, 0, 1) else 0
			p.Transparency = 1 - math.min(1, alpha * (1 + 0.4 * tip))
			p.Color = ringColor[bits]:Lerp(WHITE, 0.5 * tip)
		end
	end
	local function ringAt(bits, at, life, t, centre, ax, ay, r0, r1, thick)
		local x = (t - at) / life
		if x < 0 or x > 1 then setRing(bits, centre, ax, ay, r0, thick, 0); return end
		setRing(bits, centre, ax, ay, r0 + (r1 - r0) * (1 - (1 - x) ^ 3), thick * (1 - 0.6 * x), 1 - x * x)
	end
	local function bar(name, color)
		return part({ Name = name, Material = Enum.Material.Neon, Color = color, Size = Vector3.one * 0.05, Transparency = 1 }, folder)
	end

	-- the halo gate: three rings, gems riding the middle one, sun spikes on the outer one
	local halo = { newRing(GOLD, 44), newRing(rgb(255, 214, 110), 52), newRing(rgb(255, 228, 150), 60) }
	-- two huge rings turning slowly round the hole in the sky (the scale of heaven: critic, Oct 26)
	local skyRings = { newRing(rgb(255, 214, 120), 80), newRing(rgb(255, 234, 176), 72) }
	local gems, spikes = {}, {}
	for i = 1, 8 do gems[i] = bar("HaloGem", rgb(255, 252, 236)) end
	for i = 1, 12 do spikes[i] = bar("HaloSpike", rgb(255, 236, 170)) end
	-- the circle on the ground
	local sigil = { outer = newRing(GOLD, 64), inner = newRing(rgb(255, 214, 110), 48), centre = newRing(rgb(255, 236, 170), 24) }
	local spokes, runes, star = {}, {}, {}
	for i = 1, 12 do spokes[i] = bar("SigilSpoke", rgb(255, 214, 110)) end
	for i = 1, 16 do runes[i] = bar("SigilRune", rgb(255, 240, 190)) end
	for i = 1, 6 do star[i] = bar("SigilStar", GOLD) end
	-- the shockwaves and ripples
	local rings = {
		shock = newRing(rgb(255, 240, 200), 48), climb = newRing(rgb(255, 230, 170), 32), gust = newRing(rgb(255, 244, 214), 40),
		ripple1 = newRing(rgb(255, 222, 140), 44), ripple2 = newRing(rgb(255, 230, 160), 44), ripple3 = newRing(rgb(255, 238, 190), 44),
	}
	for _, sp in spears do sp.ring = newRing(PALE, 24) end

	-- the pillar: hard layered beams from the sky to the ground
	local pTop, pFoot = anchor(), anchor()
	local PILLAR_COLORS = { AMBER, GOLD, PALE, WHITE }
	local pillar = {}
	for i, L in Reveal.PILLAR_LAYERS do
		pillar[i] = { b = beam(pTop, pFoot, PILLAR_COLORS[i], { Segments = 2 }), def = L }
	end
	-- rungs climbing the pillar (the reference's ladder beam), each a white core over a gold band
	local rungs = {}
	for i = 1, 8 do
		local a0, a1 = anchor(), anchor()
		rungs[i] = { i = i, a0 = a0, a1 = a1, glow = beam(a0, a1, GOLD, { Segments = 1 }), core = beam(a0, a1, WHITE, { Segments = 1 }) }
	end
	local pillarBase = part({ Name = "PillarBase", Transparency = 1, Size = Vector3.new(7 * k, 0.5, 7 * k), CFrame = CFrame.new(floorAt) }, folder)
	local upSparks = emitter(pillarBase, { Picture = { "Spark" }, Color = seq(WHITE, PALE, GOLD), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0.5 * k }, { 1, 0.15 * k } }),
		Squash = sizeSeq({ { 0, 2 }, { 1, 3 } }), Transparency = nseq({ { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(22 * k, 36 * k), SpreadAngle = Vector2.new(6, 6) })

	-- the air: gold motes rising round the spot, flakes of light drifting down from the halo
	local air = part({ Name = "Air", Transparency = 1, Size = Vector3.new(70 * k, 2, 70 * k), CFrame = CFrame.new(ground + up * 2 * k) }, folder)
	local motes = emitter(air, { Picture = { "Spark" }, Color = seq(rgb(255, 236, 170), rgb(255, 196, 90)), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0 }, { 0.15, 0.45 * k }, { 0.85, 0.35 * k }, { 1, 0 } }),
		Squash = sizeSeq({ { 0, 2 }, { 1, 2 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(3 * k, 6 * k), SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 1.5 * k, 0) })
	local sky = part({ Name = "FlakeSky", Transparency = 1, Size = Vector3.new(46 * k, 2, 46 * k), CFrame = CFrame.new(ground + up * 46 * k) }, folder)
	local flakes = emitter(sky, { Picture = { "Feather" }, Color = seq(CREAM, PALE), LightEmission = 0.7, Brightness = 1.6,
		Size = sizeSeq({ { 0, 0 }, { 0.1, 1.1 * k }, { 0.9, 0.9 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -2.6 * k, 0), Drag = 0.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-50, 50) })

	-- bursts of light: at the pillar's foot, at her back (wings) and at her middle (the ascension)
	local foot = part({ Name = "Foot", Transparency = 1, Size = Vector3.new(6 * k, 0.2, 6 * k), CFrame = CFrame.new(floorAt) }, folder)
	local heart = part({ Name = "Heart", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground) }, folder)
	local back = part({ Name = "Back", Transparency = 1, Size = Vector3.new(3 * mid, mid, 1), CFrame = CFrame.new(ground) }, folder)
	local function burst(parent, s)
		return {
			sparks = emitter(parent, { Picture = { "Spark" }, Color = seq(WHITE, PALE, GOLD), LightEmission = 1, Brightness = 2,
				Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0.7 * k * s }, { 1, 0.2 * k } }),
				Squash = sizeSeq({ { 0, 0.5 }, { 0.3, 2 }, { 1, 2.5 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(18 * k * s, 34 * k * s), Drag = 4, SpreadAngle = Vector2.new(180, 180) }),
			glints = emitter(parent, { Picture = { "Star" }, Color = seq(WHITE, PALE), LightEmission = 1, Brightness = 2.4,
				Size = sizeSeq({ { 0, 0 }, { 0.2, 1.6 * k * s }, { 1, 0 } }), Transparency = nseq({ { 0, 0 }, { 1, 0.2 } }),
				Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(6 * k * s, 16 * k * s), Drag = 3, SpreadAngle = Vector2.new(180, 180),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) }),
			shards = emitter(parent, { Picture = { "Crystal" }, Color = seq(WHITE, PALE, GOLD), LightEmission = 1, Brightness = 1.6,
				Size = sizeSeq({ { 0, 1.2 * k * s }, { 1, 0.4 * k } }), Transparency = nseq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(18 * k * s, 34 * k * s), Drag = 3, SpreadAngle = Vector2.new(70, 70),
				EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
				Acceleration = Vector3.new(0, -30 * k, 0) }),
		}
	end
	local footBurst, backBurst, heartBurst = burst(foot, 1.2), burst(back, 1), burst(heart, 1.3)
	-- gold shards torn out of the ground where the pillar hits and where she lands (the green reference's debris), flying up
	-- and falling back, turning; drawn by the step
	local rocks = {}
	local rockRnd = Random.new(57)
	for i = 1, 30 do
		local sz = rockRnd:NextNumber(0.5, 1.5) * k
		local a = rockRnd:NextNumber(0, math.pi * 2)
		rocks[i] = {
			p = part({ Name = "Shard", Material = Enum.Material.Neon, Color = if i % 3 == 0 then WHITE else SUN, Size = Vector3.new(sz * 0.3, sz * 1.3, sz * 0.15), Transparency = 1 }, folder),
			at = if i <= 18 then Reveal.PILLAR else Reveal.TOUCH, a = a, r = rockRnd:NextNumber(2, 5) * k,
			out = rockRnd:NextNumber(8, 18) * k, upv = rockRnd:NextNumber(22, 38) * k, spin = Vector3.new(rockRnd:NextNumber(-1, 1), rockRnd:NextNumber(-1, 1), rockRnd:NextNumber(0.2, 1)).Unit * rockRnd:NextNumber(4, 10),
			size = Vector3.new(sz * 0.3, sz * 1.3, sz * 0.15), -- (gold shards: brown rock read as dirt)
		}
	end
	local wingDust = emitter(back, { Picture = { "Feather" }, Color = seq(WHITE, PALE), LightEmission = 0.8, Brightness = 1.8,
		Size = sizeSeq({ { 0, 0.9 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.6 } }),
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1 * k, 3 * k), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -2 * k, 0), Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60) })

	-- her wings: feathers from her shoulder blades, each a white core over a wider gold glow
	local wings = {}
	for _, s in { -1, 1 } do
		for i, def in Reveal.FEATHERS do
			local a0, a1 = anchor(), anchor()
			table.insert(wings, {
				s = s, i = i, def = def, a0 = a0, a1 = a1,
				glow = beam(a0, a1, seq(SUN, GOLD, AMBER), { Segments = 2 }), -- (gold edges: white alone vanished on bright sky)
				core = beam(a0, a1, seq(WHITE, CREAM, PALE), { Segments = 2 }),
			})
		end
	end

	-- her light: white as she appears, a gold rim after
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = WHITE, WHITE
	hl.FillTransparency, hl.OutlineTransparency = 1, 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = folder
	local RIM = rgb(255, 214, 120)

	-- her name on screen: DIVINE and 8 stars in gold over her name, a shine sweeping across, gold lines drawing out
	local girlName = model:GetAttribute("GirlName")
	local rating = model:FindFirstChild("Rating", true)
	if type(girlName) ~= "string" or girlName == "" then
		local first = rating and rating:FindFirstChildOfClass("TextLabel")
		girlName = if first and first.Text ~= "" then first.Text else "Divine girl"
	end
	local ratingWas = if rating and rating:IsA("BillboardGui") then rating.Enabled else nil
	local function font(weight)
		local ok, f = pcall(function()
			return Font.new("rbxasset://fonts/families/GothamSSm.json", weight, Enum.FontStyle.Normal)
		end)
		return if ok then f else nil
	end
	local nameGui = Instance.new("ScreenGui")
	nameGui.Name, nameGui.IgnoreGuiInset, nameGui.DisplayOrder, nameGui.Enabled, nameGui.ResetOnSpawn = "HuzzDivineName", true, 55, false, false
	local card = Instance.new("Frame")
	card.Name, card.AnchorPoint, card.Position, card.Size, card.BackgroundTransparency = "Card", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.77), UDim2.fromScale(0.9, 0.27), 1
	card.Parent = nameGui
	local grow = Instance.new("UIScale")
	grow.Name = "Pop"
	grow.Parent = card
	local band = Instance.new("Frame")
	band.Name, band.AnchorPoint, band.Position, band.Size = "Band", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.55), UDim2.fromScale(1, 0.84)
	band.BackgroundColor3, band.BorderSizePixel, band.BackgroundTransparency = rgb(46, 28, 6), 0, 1
	local bandFade = Instance.new("UIGradient")
	bandFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	bandFade.Parent = band
	band.Parent = card
	local function cardText(name, text, y, h, weight, maxSize, stroke, strokeColor, colors)
		local l = Instance.new("TextLabel")
		l.Name, l.AnchorPoint, l.Position, l.Size, l.BackgroundTransparency = name, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, y), UDim2.fromScale(1, h), 1
		l.Text, l.TextColor3, l.TextScaled, l.TextTransparency = text, WHITE, true, 1
		local f = font(weight)
		if f then l.FontFace = f end
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = l
		local s = Instance.new("UIStroke")
		s.Name, s.Thickness, s.Color, s.Transparency = "Outline", stroke, strokeColor, 1
		s.Parent = l
		local g = Instance.new("UIGradient")
		g.Name, g.Color = "Gold", colors
		g.Parent = l
		l.Parent = card
		return l, s, g
	end
	local TITLE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 214, 110)), ColorSequenceKeypoint.new(0.3, rgb(255, 244, 196)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 196, 70)), ColorSequenceKeypoint.new(0.7, rgb(255, 244, 196)), ColorSequenceKeypoint.new(1, rgb(255, 214, 110)),
	})
	-- (the name's gradient carries the shine: pale gold with one white band, slid across by its Offset)
	local SHINE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 238, 196)), ColorSequenceKeypoint.new(0.42, rgb(255, 238, 196)),
		ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(0.58, rgb(255, 238, 196)), ColorSequenceKeypoint.new(1, rgb(255, 238, 196)),
	})
	local tagLabel, tagStroke = cardText("Tag", "★★★★  DIVINE  ★★★★", 0.17, 0.3, Enum.FontWeight.Heavy, 40, 2.5, rgb(80, 44, 0), TITLE)
	local nameLabel, nameStroke, nameShine = cardText("Name", string.upper(girlName), 0.6, 0.56, Enum.FontWeight.Heavy, 100, 4, rgb(96, 54, 0), SHINE)
	local lines = {}
	for i, y in { 0.13, 0.97 } do
		local line = Instance.new("Frame")
		line.Name, line.AnchorPoint, line.Position, line.Size = "Line" .. i, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, y), UDim2.new(0, 0, 0, 3)
		line.BackgroundColor3, line.BorderSizePixel, line.BackgroundTransparency = GOLD, 0, 1
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = line
		line.Parent = card
		lines[i] = line
	end
	table.insert(junk, nameGui)

	-- slashes across the picture, crescent swings round her, speed streaks, the radial burst and star flares
	-- (all laid out from the camera, so they read the same from any angle)
	local function pair(color, glowW)
		local a0, a1 = anchor(), anchor()
		return { a0 = a0, a1 = a1, glow = beam(a0, a1, color, { Transparency = TAPER, Segments = 2 }), core = beam(a0, a1, WHITE, { Transparency = TAPER, Segments = 2 }), gw = glowW }
	end
	local slashes = {}
	for i, at in Reveal.SLASHES do
		local sl = pair(seq(PALE, GOLD), 3)
		sl.at, sl.i = at, i
		local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		sl.glow.Transparency, sl.core.Transparency = fade, fade
		slashes[i] = sl
	end
	local swings = {}
	for i, at in Reveal.SWINGS do
		local sw = pair(seq(PALE, GOLD, AMBER), 2.2)
		local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0) })
		sw.glow.Transparency, sw.core.Transparency = fade, fade
		sw.glow.Segments, sw.core.Segments = 12, 12
		sw.at, sw.i, sw.tilt, sw.start, sw.lift = at, i, ({ 20, -25, 8 })[i], ({ -70, 110, 200 })[i], ({ 1, 3, -1 })[i]
		swings[i] = sw
	end
	local streakRnd = Random.new(11)
	local streakLines = {}
	for i = 1, 60 do
		local a0, a1 = anchor(), anchor()
		streakLines[i] = { a0 = a0, a1 = a1, phase = streakRnd:NextNumber(), x = streakRnd:NextNumber(-1, 1), depth = streakRnd:NextNumber(0.6, 1.3),
			len = streakRnd:NextNumber(0.5, 1.3), w = streakRnd:NextNumber(0.08, 0.3), speed = streakRnd:NextNumber(1.1, 1.9),
			b = beam(a0, a1, seq(WHITE, SUN, AMBER), { Transparency = TAPER, Segments = 1 }) }
	end
	local rays = {}
	for i = 1, 9 do -- (few blades of uneven length: twenty even bars read as clip-art)
		local a0, a1 = anchor(), anchor()
		rays[i] = { ang = (i - 1) / 9 * math.pi * 2 + streakRnd:NextNumber(-0.25, 0.25), len = if i % 2 == 0 then streakRnd:NextNumber(0.4, 0.6) else streakRnd:NextNumber(0.85, 1.15),
			w = streakRnd:NextNumber(0.8, 1.3), a0 = a0, a1 = a1, b = beam(a0, a1, seq(WHITE, SUN, AMBER), { Transparency = TAPER, Segments = 1 }) }
	end
	local function newFlare()
		local f = { spikes = {} }
		f.core = part({ Name = "Flare", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = CREAM, Size = Vector3.one, Transparency = 1 }, folder)
		for j = 1, 8 do
			local a0, a1 = anchor(), anchor()
			f.spikes[j] = { a0 = a0, a1 = a1, b = beam(a0, a1, seq(WHITE, GOLD), { Transparency = TAPER, Segments = 1 }) }
		end
		return f
	end
	local flares = { newFlare(), newFlare(), newFlare() }
	local function setFlare(f, at, s, alpha, camR, camU)
		f.core.CFrame = CFrame.new(at)
		f.core.Size = Vector3.one * math.max(1.4 * s, 0.05)
		f.core.Transparency = 1 - alpha
		for j, sp in f.spikes do
			local ang = (j - 1) * math.pi / 2 + (if j > 4 then math.pi / 4 else 0)
			local dirv = camR * math.cos(ang) + camU * math.sin(ang)
			local len = (if j > 4 then 4 elseif j % 2 == 1 then 15 else 10) * s
			sp.a0.WorldPosition = at
			sp.a1.WorldPosition = at + dirv * len
			sp.b.Width0, sp.b.Width1 = (if j > 4 then 0.35 else 0.7) * s * alpha, 0
		end
	end

	-- the impact frame: black ink claws bursting in from the edges on white paper (the reference's manga frame; one
	-- frame of 0.12 s, so one flash). Reduced Motion: none.
	local frameGui = Instance.new("ScreenGui")
	frameGui.Name, frameGui.IgnoreGuiInset, frameGui.DisplayOrder, frameGui.Enabled, frameGui.ResetOnSpawn = "HuzzImpactFrame", true, 60, false, false
	local paper = Instance.new("Frame")
	paper.Size, paper.BackgroundColor3, paper.BorderSizePixel = UDim2.fromScale(1, 1), rgb(250, 247, 238), 0
	paper.Parent = frameGui
	local burstGui = Instance.new("Frame")
	burstGui.AnchorPoint, burstGui.Position, burstGui.Size, burstGui.BackgroundTransparency = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(2400, 2400), 1
	burstGui.Parent = paper
	local lineRnd = Random.new(9)
	local function inkLine(a, w, len, r, color, inward)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.fromOffset(w, len)
		line.Rotation = if inward then a + 180 else a -- (its solid end: at the screen's edge, or in the middle)
		line.Position = UDim2.fromOffset(math.round(1200 + math.sin(math.rad(a)) * r), math.round(1200 - math.cos(math.rad(a)) * r))
		line.BackgroundColor3, line.BorderSizePixel = color, 0
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.05), NumberSequenceKeypoint.new(1, 1) }) -- (solid ink, a short taper)
		fade.Parent = line
		line.Parent = burstGui
	end
	for i = 1, 14 do -- (black ink claws of uneven width and length on white, as the reference's frame)
		local len = lineRnd:NextInteger(700, 1150)
		inkLine((i - 1) / 14 * 360 + lineRnd:NextNumber(-10, 10), lineRnd:NextInteger(30, 110), len, 1200 - len / 2, INK)
	end
	table.insert(junk, frameGui)

	-- the vignette: the picture's edges sink into the night (as the reference's)
	local vignette = Instance.new("ScreenGui")
	vignette.Name, vignette.IgnoreGuiInset, vignette.DisplayOrder, vignette.Enabled, vignette.ResetOnSpawn = "HuzzDivineVignette", true, 40, false, false
	local edges = {}
	for _, e in { { 0, 0, 0.3, 1, 0, false }, { 0.7, 0, 0.3, 1, 0, true }, { 0, 0, 1, 0.28, 90, false }, { 0, 0.72, 1, 0.28, 90, true } } do
		local f = Instance.new("Frame")
		f.Position, f.Size = UDim2.fromScale(e[1], e[2]), UDim2.fromScale(e[3], e[4])
		f.BackgroundColor3, f.BorderSizePixel, f.BackgroundTransparency = rgb(4, 4, 14), 0, 1
		local g = Instance.new("UIGradient")
		g.Rotation = e[5]
		g.Transparency = if e[6] then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
			else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = vignette
		table.insert(edges, f)
	end
	table.insert(junk, vignette)

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HuzzDivineGrade"
	table.insert(junk, grade)

	local fired = {}
	local function once(name, fn)
		if not fired[name] then fired[name] = true; fn() end
	end

	local function step(t: number, dir: Vector3, cam: CFrame?)
		local calm = Motion.reduced
		local side = dir:Cross(up)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
		local h = Reveal.height(t, Config.Showcase.Height)
		local camR = if cam then cam.RightVector else side
		local camU = if cam then cam.UpVector else up
		local camPos = if cam then cam.Position else ground + dir * 40 * k + up * 10 * k

		-- the light
		local on = Reveal.heaven(t)
		for _, s in saved do
			(s.inst :: any)[s.key] = lerp(s.was, s.target, if s.inst == Lighting then Reveal.dusk(t) else on)
		end
		Lighting.ClockTime = Reveal.clock(t, day)
		once("start", function()
			motes:Emit(40)
			Sfx.beat("Build", Reveal.PILLAR) -- (the riser tops out on the pillar)
		end)
		motes.Rate = if on > 0.3 and t < Reveal.CLOSE then 14 else 0
		flakes.Rate = if t >= Reveal.SPIN and t < Reveal.RISE + 0.5 then 9 else 0

		-- the portal drawing itself in the sky: two huge rings (drawn round from the front), sun spikes, a white-hot core;
		-- all closing again at the end
		local open = Reveal.skyOpen(t)
		local hole = (12 + (Reveal.SKY_RADIUS - 12) * open) * k
		local d = math.max(hole * 0.4 * open, 0.1) -- (small: bigger read as a grey moon on the first film)
		disc.Size = Vector3.new(0.4, d, d)
		disc.Transparency = 1 - open
		local skyA = math.min(1, open * 1.5) * (1 - Reveal.smooth((t - Reveal.CLOSE) / 0.8))
		local tiltSky = CFrame.fromAxisAngle(side, math.rad(10)):VectorToWorldSpace(dir)
		setRing(skyRings[1], skyAt - up * 2 * k, side, tiltSky, hole, 1.1 * k, skyA, t * 0.12, open)
		setRing(skyRings[2], skyAt - up * 5 * k, side, dir, hole * 0.72, 0.7 * k, skyA, -t * 0.18, open)
		for i, sp in portalSpikes do
			local a = (i - 1) / #portalSpikes * math.pi * 2 - t * 0.25
			local out = side * math.cos(a) + dir * math.sin(a)
			local len = (if i % 2 == 0 then 7 else 13) * k * open
			sp.CFrame = CFrame.fromMatrix(skyAt - up * 2 * k + out * (hole + len / 2 + 1 * k), out, up)
			sp.Size = Vector3.new(math.max(len, 0.05), 0.5 * k, 0.9 * k * (1 - 0.4 * (i % 2)))
			sp.Transparency = 1 - skyA
		end

		-- the spears striking round the spot, lightning crackling on them; swallowed into the pillar
		local toCamFlat = Vector3.new(camPos.X - ground.X, 0, camPos.Z - ground.Z)
		toCamFlat = if toCamFlat.Magnitude > 0.1 then toCamFlat.Unit else dir
		for i, sp in spears do
			local reach, power, pull = Reveal.spear(t, i)
			if power <= 0.01 then
				if sp.on then
					sp.on = false
					sp.glow.Width0, sp.glow.Width1, sp.core.Width0, sp.core.Width1 = 0, 0, 0, 0
					for _, b in sp.bolts do b.Width0, b.Width1 = 0, 0 end
				end
				setRing(sp.ring, floorAt, side, dir, 1, 0.1, 0)
				continue
			end
			sp.on = true
			local a = math.rad(sp.def.ang + 4 * t)
			local out = dir * math.cos(a) + side * math.sin(a)
			local footAt = (floorAt + out * sp.def.out * k):Lerp(floorAt, pull)
			local top = skyAt - up * 2 * k + out * hole * 0.6
			local low = top:Lerp(footAt, reach)
			sp.a0.WorldPosition, sp.a1.WorldPosition = top, low
			local w = sp.def.w0 * 0.25 * k
			sp.core.Width0, sp.core.Width1 = w * 0.6, w * 0.75 -- (critic: hairlines read as wireframe)
			sp.glow.Width0, sp.glow.Width1 = w * 1.7, w * 2.1
			setAlpha(sp.core, power, 0.02, 0.03)
			setAlpha(sp.glow, 0.75 * power, 0.02, 0.03)
			-- the lightning thread
			if not calm and t - sp.at > 0.07 then
				sp.at = t
				for q = 1, sp.n - 1 do sp.off[q] = spearRnd:NextNumber(-1, 1) end
			end
			local along = low - top
			local nv = along:Cross(camPos - (top + low) / 2)
			nv = if nv.Magnitude > 1e-3 then nv.Unit else side
			for q = 0, sp.n do
				local jit = if q == 0 or q == sp.n then 0 else sp.off[q] * w * 1.6
				sp.atts[q].WorldPosition = top + along * (q / sp.n) + nv * jit
			end
			for _, b in sp.bolts do b.Width0, b.Width1 = 0.32 * k * power, 0.32 * k * power end
			sp.hit.CFrame = CFrame.new(footAt)
			if reach >= 1 then
				once("spear" .. i, function() sp.sparks:Emit(14) end)
			end
			local at = Reveal.RAYS + (i - 1) * Reveal.SPEAR_GAP + 0.08
			ringAt(sp.ring, at, 0.45, t, footAt + up * 0.1, side, dir, 0.5 * k, 6 * k, 0.3 * k)
		end

		-- the halo gate coming down, spinning up, closing in round her and becoming her crown
		local hy, hr, turn, hAlpha, crown = Reveal.halo(t, k, mid, h)
		local hc = ground + up * hy
		local tiltA, tiltB = math.rad(16) * (1 - crown), math.rad(-12) * (1 - crown)
		local axA = CFrame.fromAxisAngle(dir, tiltA):VectorToWorldSpace(side)
		local ayB = CFrame.fromAxisAngle(side, tiltB):VectorToWorldSpace(dir)
		setRing(halo[1], hc, side, dir, hr, 0.5 * k * (1 - 0.5 * crown), hAlpha, turn)
		setRing(halo[2], hc, axA, dir, hr * 1.3, 0.4 * k, hAlpha * (1 - crown), -turn * 0.8)
		setRing(halo[3], hc, side, ayB, hr * 1.6, 0.32 * k, hAlpha * (1 - crown), turn * 0.6)
		for i, g in gems do
			local a = (i - 1) / #gems * math.pi * 2 - turn * 0.8
			local out = axA * math.cos(a) + dir * math.sin(a)
			g.CFrame = CFrame.fromMatrix(hc + out * hr * 1.3, out, out:Cross(axA:Cross(dir).Unit).Unit) * CFrame.Angles(math.rad(45), 0, 0)
			g.Size = Vector3.one * 0.9 * k
			g.Transparency = 1 - hAlpha * (1 - crown)
		end
		local ny = side:Cross(ayB).Unit
		for i, sp in spikes do
			local a = (i - 1) / #spikes * math.pi * 2 + turn * 0.6
			local out = side * math.cos(a) + ayB * math.sin(a)
			local len = (1.6 + 0.8 * (i % 2)) * k
			sp.CFrame = CFrame.fromMatrix(hc + out * (hr * 1.6 + len / 2 + 0.3 * k), out, ny)
			sp.Size = Vector3.new(len, 0.22 * k, 0.22 * k)
			sp.Transparency = 1 - hAlpha * (1 - crown)
		end

		-- the circle drawing itself on the ground
		local drawn, glow = Reveal.sigil(t)
		local st = t * 0.15
		glow *= 0.55 -- (gold on green adds up to lime: kept softer)
		setRing(sigil.outer, floorAt, side, dir, 14 * k, 0.36 * k, glow, st, drawn)
		setRing(sigil.inner, floorAt, side, dir, 10.5 * k, 0.3 * k, glow * 0.9, -st + math.pi, drawn)
		setRing(sigil.centre, floorAt, side, dir, 4 * k, 0.26 * k, glow * 0.85, st * 2, drawn)
		for i, sp in spokes do
			local share = (i - 0.5) / #spokes
			local grown = math.clamp((drawn - share) * 6, 0, 1)
			local a = share * math.pi * 2 + st
			local out = side * math.cos(a) + dir * math.sin(a)
			local len = 6.5 * k * grown
			sp.CFrame = CFrame.fromMatrix(floorAt + out * (4 * k + len / 2), out, up)
			sp.Size = Vector3.new(math.max(len, 0.05), 0.08, 0.2 * k)
			sp.Transparency = if grown > 0 then 1 - glow * 0.8 else 1
		end
		for i, rn in runes do
			local share = (i - 0.5) / #runes
			local a = share * math.pi * 2 + st
			local out = side * math.cos(a) + dir * math.sin(a)
			rn.CFrame = CFrame.fromMatrix(floorAt + out * 12.25 * k, out, up) * CFrame.Angles(0, math.rad(45), 0)
			rn.Size = Vector3.new(0.9 * k, 0.08, 0.9 * k)
			rn.Transparency = if drawn >= share then 1 - glow * 0.85 else 1
		end
		local starOn = math.clamp((drawn - 0.55) / 0.45, 0, 1) -- (the six-point star: two triangles across the inner ring)
		for i, ln in star do
			local a0 = (i - 1) / 6 * math.pi * 2 - st + math.pi
			local a1 = a0 + 2 * (math.pi * 2 / 6)
			local p0 = floorAt + (side * math.cos(a0) + dir * math.sin(a0)) * 10.5 * k
			local p1 = floorAt + (side * math.cos(a1) + dir * math.sin(a1)) * 10.5 * k
			local along = (p1 - p0) * starOn
			if along.Magnitude > 0.05 then
				local x = along.Unit
				ln.CFrame = CFrame.fromMatrix(p0 + along / 2, x, up)
				ln.Size = Vector3.new(along.Magnitude, 0.08, 0.24 * k)
				ln.Transparency = 1 - glow * 0.75
			else
				ln.Transparency = 1
			end
		end

		-- the pillar
		local power, width, reach = Reveal.pillar(t)
		pTop.WorldPosition = skyAt
		pFoot.WorldPosition = skyAt:Lerp(ground, reach)
		for _, L in pillar do
			L.b.Width0, L.b.Width1 = L.def.w * k * width * 0.8, L.def.w * k * width
			setAlpha(L.b, L.def.alpha * power, 0.08, 0.04, 0.4)
		end
		-- the rungs climbing it while it's at its strongest
		local tall = Reveal.SKY * k * reach
		local ladder = math.clamp(power * 1.4 - 0.4, 0, 1) * (1 - Reveal.smooth((t - Reveal.TOUCH) / 0.5))
		local half = 2.6 * k * width
		for _, r in rungs do
			local u = (t * 0.7 + r.i / #rungs) % 1
			local y = tall * u * 0.6
			local fade = math.sin(u * math.pi) * ladder
			local c = ground + up * y
			r.a0.WorldPosition, r.a1.WorldPosition = c - camR * half, c + camR * half
			r.glow.Width0, r.glow.Width1 = 1.6 * k * fade, 1.6 * k * fade
			r.core.Width0, r.core.Width1 = 0.5 * k * fade, 0.5 * k * fade
		end
		upSparks.Rate = if power > 0.2 then 45 * power else 0
		pillarLight.Brightness = 0.8 * power -- (gold light on green grass went lime on the first film)
		if t >= Reveal.PILLAR then
			once("pillar", function()
				footBurst.sparks:Emit(40); footBurst.glints:Emit(14); footBurst.shards:Emit(18)
				Sfx.beat("Burst")
			end)
		end
		ringAt(rings.shock, Reveal.PILLAR, 0.9, t, floorAt + up * 0.1, side, dir, 2 * k, 32 * k, 0.6 * k)
		local cx = math.clamp((t - Reveal.PILLAR) / 0.9, 0, 1)
		ringAt(rings.climb, Reveal.PILLAR, 0.9, t, ground + up * (2 + 34 * Reveal.easeOut(cx)) * k, side, dir, 9 * k, 4 * k, 0.4 * k)

		-- her: hidden until she appears, then floating down turning round to you, standing, rising to her place
		local pose: CFrame? = nil
		if h then
			local S = Config.Showcase
			local face = CFrame.lookAt(Vector3.zero, Vector3.new(dir.X, 0, dir.Z)).Rotation
			pose = CFrame.new(spot + Vector3.new(0, h * k, 0)) * face * CFrame.Angles(0, Reveal.facing(t), 0)
			if t > Reveal.RISE then -- (so there's no snap when Gameplay/CarryAnimator takes her back at the end)
				local now = revealAt + t
				local float = base * CFrame.new(0, math.sin(now * 1.1) * (S.Bob or 0), 0) * CFrame.Angles(0, (now * (S.Spin or 0)) % (2 * math.pi), 0)
				pose = (pose :: CFrame):Lerp(float, Reveal.smooth((t - Reveal.RISE) / (Reveal.LENGTH - Reveal.RISE)))
			end
			model:PivotTo(pose :: CFrame)
		else
			model:PivotTo(base * CFrame.new(0, -2000, 0))
		end
		local feet = if pose then pose.Position + up * feetOff else ground + up * Reveal.APPEAR_HEIGHT * k
		local herMid = feet + up * mid
		heart.CFrame = CFrame.new(herMid)
		keyLight.Enabled = h ~= nil
		rimLight.Enabled = h ~= nil
		if pose then
			local camPos = if cam then cam.Position else herMid + dir * 30 * k
			local toCam = Vector3.new(camPos.X - herMid.X, 0, camPos.Z - herMid.Z)
			toCam = if toCam.Magnitude > 0.1 then toCam.Unit else dir
			keyPart.CFrame = CFrame.new(herMid + toCam * 7 * k + up * mid * 0.4)
			rimPart.CFrame = CFrame.new(herMid - toCam * 5 * k + up * mid * 0.9)
		end
		local white = Reveal.glow(t)
		local rimOut = Reveal.smooth((t - Reveal.RISE) / 0.8)
		if h then
			once("appear", function() heartBurst.glints:Emit(10) end)
			hl.FillTransparency = 1 - 0.6 * white
			hl.OutlineColor = WHITE:Lerp(RIM, 1 - white)
			hl.OutlineTransparency = math.min(1, 0.1 + 0.45 * (1 - white) + 0.45 * rimOut)
		end

		-- her wings
		local wingOpen, wingSeen = Reveal.wings(t)
		if pose and wingSeen > 0.01 then
			local fwd = Vector3.new(pose.LookVector.X, 0, pose.LookVector.Z)
			fwd = if fwd.Magnitude > 0.1 then fwd.Unit else dir
			local right = fwd:Cross(up).Unit
			local shoulder = feet + up * mid * 1.45 - fwd * 0.6 * k
			back.CFrame = CFrame.lookAt(shoulder - fwd * 1.5 * k, shoulder - fwd * 3 * k)
			for _, w in wings do
				-- (each feather a beat after the one above it: they fan open one by one, with a little bounce)
				local fOpen = math.min(wingOpen, (Reveal.wings(t - (w.i - 1) * 0.045)))
				local a = math.rad(lerp(Reveal.FOLDED, w.def.ang, math.clamp(fOpen, 0, 1.1)))
				local len = w.def.len * mid * (0.35 + 0.65 * math.clamp(fOpen, 0, 1.1))
				local root = shoulder + right * w.s * 0.45 * k
				local out = (up * math.cos(a) + right * w.s * math.sin(a) - fwd * 0.32).Unit
				w.a0.WorldPosition = root
				w.a1.WorldPosition = root + out * len
				local wd = w.def.w * k * (0.4 + 0.6 * math.clamp(wingOpen, 0, 1))
				w.core.Width0, w.core.Width1 = wd * 0.3, wd * 0.6
				w.glow.Width0, w.glow.Width1 = wd * 0.7, wd * 1.5
				setAlpha(w.core, 0.9 * wingSeen, 0.1, 0.22)
				setAlpha(w.glow, 0.45 * wingSeen, 0.1, 0.3)
			end
		else
			for _, w in wings do
				setAlpha(w.core, 0, 0.1, 0.22)
				setAlpha(w.glow, 0, 0.1, 0.3)
			end
		end
		wingDust.Rate = if wingSeen > 0.3 then 10 * wingSeen else 0
		if t >= Reveal.WINGS then
			once("wings", function() backBurst.sparks:Emit(36); backBurst.glints:Emit(12) end)
		end
		local gustAt = (if pose then feet else ground) + up * mid * 1.45
		ringAt(rings.gust, Reveal.WINGS, 0.45, t, gustAt, side, dir, 3 * k, 15 * k, 0.2 * k)
		if t >= Reveal.RISE + 0.5 then once("dissolve", function() wingDust:Emit(50) end) end

		-- the touchdown: three ripples, warm dust
		if t >= Reveal.TOUCH then
			once("touch", function() footBurst.shards:Emit(14); footBurst.glints:Emit(8) end)
		end
		ringAt(rings.ripple1, Reveal.RIPPLES[1], 1.0, t, floorAt + up * 0.12, side, dir, 2 * k, 18 * k, 0.45 * k)
		ringAt(rings.ripple2, Reveal.RIPPLES[2], 1.0, t, floorAt + up * 0.14, side, dir, 2 * k, 15 * k, 0.38 * k)
		ringAt(rings.ripple3, Reveal.RIPPLES[3], 1.0, t, floorAt + up * 0.16, side, dir, 2 * k, 12 * k, 0.32 * k)

		-- the ascension
		if t >= Reveal.SWELL then
			once("swell", function()
				heartBurst.sparks:Emit(48); heartBurst.glints:Emit(16)
				Sfx.play("secret_impact")
			end)
		end

		-- the shards flying up and falling back
		for _, rk in rocks do
			local x = t - rk.at
			if x < 0 or x > 1.3 then
				if rk.shown then rk.p.Transparency = 1; rk.shown = false end
				continue
			end
			local out = side * math.cos(rk.a) + dir * math.sin(rk.a)
			local y = rk.upv * x - 30 * k * x * x
			if y < 0 and x > 0.2 then
				if rk.shown then rk.p.Transparency = 1; rk.shown = false end
				continue
			end
			rk.shown = true
			local p = floorAt + out * (rk.r + rk.out * x / (1 + 2 * x)) + up * math.max(y, 0)
			rk.p.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(rk.spin.Unit, rk.spin.Magnitude * x)
			rk.p.Size = rk.size * (1 - 0.5 * Reveal.smooth((x - 0.9) / 0.4))
			rk.p.Transparency = 0
		end

		-- the slashes: snapping across the picture by the halo, drifting sideways as they thin out
		local hy0 = Reveal.halo(t, k, mid, h)
		for _, sl in slashes do
			local v = Reveal.slash(t, sl.at)
			local flip = if sl.i % 2 == 0 then -1 else 1
			local c = ground + up * (hy0 + ({ 2, -4, 5 })[sl.i] * k) + camR * math.max(0, t - sl.at) * 30 * k * flip
			local len, tilt = 34 * k, 6 * k
			sl.a0.WorldPosition = c - camR * len + camU * tilt * flip
			sl.a1.WorldPosition = c + camR * len - camU * tilt * flip
			sl.glow.Width0, sl.glow.Width1 = sl.gw * k * v, sl.gw * k * v
			sl.core.Width0, sl.core.Width1 = 0.7 * k * v, 0.7 * k * v
		end

		-- the crescent swings round her as the wings open
		for _, sw in swings do
			local v = Reveal.swing(t, sw.at)
			if v <= 0 then sw.glow.Width0, sw.glow.Width1, sw.core.Width0, sw.core.Width1 = 0, 0, 0, 0; continue end
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
			for _, b in { sw.glow, sw.core } do b.CurveSize0, b.CurveSize1 = R * 1.02, R * 1.02 end
			sw.glow.Width0, sw.glow.Width1 = 0, sw.gw * k * v
			sw.core.Width0, sw.core.Width1 = 0, 0.5 * k * v
		end

		-- the speed streaks: rushing down past her as she rides the pillar, up as she rises (laid out in front of the
		-- camera, so they fill the picture whatever the shot)
		local sv, sdir = Reveal.streaks(t)
		local camF = if cam then cam.LookVector else -dir
		local flow = (camU * sdir + camR * 0.55).Unit -- (diagonal, as the reference's)
		for _, sl in streakLines do
			if sv <= 0 then
				if sl.shown then sl.b.Width0 = 0; sl.shown = false end
				continue
			end
			sl.shown = true
			local D = 22 * k * sl.depth
			local half = D * 0.62
			local s = (t * sl.speed + sl.phase) % 1
			local head = camPos + camF * D + camR * sl.x * half * 1.2 + flow * (-1.4 + 2.8 * s) * half * 0.6
			sl.a0.WorldPosition = head
			sl.a1.WorldPosition = head - flow * sl.len * half * 0.9
			sl.b.Width0, sl.b.Width1 = sl.w * D * 0.05 * sv * 1.8, 0 -- (critic: dense and thick, so they read as speed, not rain)
		end

		-- the radial burst of gold rays: round her feet on the touchdown, from behind her head at the ascension
		local rv, rs = Reveal.rays(t)
		local behindHead = herMid + up * mid * 0.6 - (camPos - herMid).Unit * 3 * k
		local rc = if rs > 1 then behindHead else feet + up * 1 * k
		for _, r in rays do
			if rv <= 0 then
				if r.shown then r.b.Width0 = 0; r.shown = false end
				continue
			end
			r.shown = true
			local dirv = camR * math.cos(r.ang) + camU * math.sin(r.ang)
			local len = (14 + 36 * math.min(1, rv * 1.6)) * r.len * k * rs
			r.a0.WorldPosition = rc + dirv * 2 * k
			r.a1.WorldPosition = rc + dirv * len
			r.b.Width0, r.b.Width1 = 1.6 * r.w * k * rv * rs, 0
		end
		-- star flares: either side of her on the touchdown, a big one behind her head at the ascension
		local tf = Reveal.slash(t, Reveal.TOUCH)
		setFlare(flares[1], herMid - camR * 9 * k + camU * 3 * k, 1.1 * k, tf, camR, camU)
		setFlare(flares[2], herMid + camR * 10 * k - camU * 2 * k, 0.9 * k, tf, camR, camU)
		setFlare(flares[3], behindHead, 1.1 * k, Reveal.pop(t, Reveal.SWELL, 0.05, 0.6), camR, camU)

		-- the impact frame and the vignette
		frameGui.Enabled = Reveal.impactFrame(t, calm)
		vignette.Enabled = on > 0.01
		for _, e in edges do e.BackgroundTransparency = 1 - 0.85 * on end

		-- her name on screen: rises in, gold lines draw out, the shine crosses twice; gone before she rises
		local nv = Reveal.name(t)
		nameGui.Enabled = nv > 0
		if t >= Reveal.NAME then once("sting", function() Sfx.beat("Reveal") end) end
		if nv > 0 then
			local x = Reveal.easeOut((t - Reveal.NAME) / 0.45)
			card.Position = UDim2.fromScale(0.5, 0.77 + 0.03 * (1 - x))
			grow.Scale = 1.25 - 0.25 * x -- (lands in from big)
			local tagIn = math.clamp((t - Reveal.NAME - 0.1) / 0.25, 0, 1) * nv
			nameLabel.TextTransparency, nameStroke.Transparency = 1 - nv, 1 - nv
			tagLabel.TextTransparency, tagStroke.Transparency = 1 - tagIn, 1 - tagIn
			band.BackgroundTransparency = 1 - 0.6 * nv
			nameShine.Offset = Vector2.new(Reveal.shine(t), 0)
			for _, line in lines do
				line.Size = UDim2.new(0.62 * Reveal.smooth((t - Reveal.NAME - 0.05) / 0.5), 0, 0, 3)
				line.BackgroundTransparency = 1 - nv
			end
		end
		if ratingWas ~= nil then (rating :: BillboardGui).Enabled = ratingWas and t >= Reveal.RISE + 0.3 end

		-- the world's colour: warmer and brighter, with soft swells
		local b, s, tint, pulse, contrast = Reveal.grade(t)
		grade.Brightness = b + (if calm then 0 else 0.1 * pulse)
		grade.Saturation = s
		grade.Contrast = contrast
		grade.TintColor = WHITE:Lerp(rgb(206, 218, 255), tint) -- (cool moonlight: the gold stands out against it)
		return herMid, h
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
		nameGui:Destroy()
		frameGui:Destroy()
		vignette:Destroy()
		if ratingWas ~= nil then pcall(function() (rating :: BillboardGui).Enabled = ratingWas end) end
		for _, b in beams do b:Destroy() end
		for _, a in anchors do a:Destroy() end
	end
	if M.failForTest then error("test: build failed on purpose") end
	nameGui.Parent = if player then player:WaitForChild("PlayerGui") else nil
	frameGui.Parent, vignette.Parent = nameGui.Parent, nameGui.Parent
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

return M
