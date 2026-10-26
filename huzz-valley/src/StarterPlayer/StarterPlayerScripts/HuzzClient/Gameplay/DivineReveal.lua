--[[
	The Divine girl's arrival cutscene, "Heaven's Gate" (the timing, the shot and the camera: Shared/DivineReveal;
	owner, Oct 26: "make it completely different from the secret animation ... way smoother and more fitting and
	better looking"). Gameplay/SecretReveal plays it (its play() picks this one when the showcase's RevealKind is
	"Divine": the same camera planning, steady clock and hand-back), and this builds the effects and poses her:
	  the light   your Lighting, on this screen only: warm golden light, a gold haze, a little more bloom and sun rays,
	              warm clouds and a warm grade; all put back exactly afterwards
	  the sky     a ring of cloud parts high over the spot (Roblox's own smoke picture), a disc of heaven's light
	              grows in it (Neon, a ForceField shimmer round it); seven soft god rays fan down out of it and sway
	  halo gate   three golden rings of neon pieces, tilted and turning against each other, gems on one, sun spikes
	              on another; it comes down out of the light, spins up, and as she floats down it closes in round her
	              and shrinks into her crown halo
	  sigil       a golden circle draws itself on the ground: three rings, a six-point star, spokes and rune marks
	  pillar      one pillar of light (five layers of plain Beams, white in the middle, gold outside, and a shimmering
	              ForceField shell) falls through the halo; a ring races out on the ground, another climbs the pillar
	  her         lit white as she appears, floating down turning round to you, settling to a warm gold rim; wings of
	              light (16 feathers, each a white core and a gold glow) unfold behind her, beat once, and fade into
	              sparkles as she rises
	  the air     gold motes rising, flakes of light drifting down, sparks up the pillar, bursts of light
	  her name    DIVINE and 8 stars in gold, her name with a shine sweeping over it, gold lines drawing out
	Flashes: soft swells only at the pillar, the touchdown (small) and the ascension (kid-safe: over a second apart).
	Reduced Motion (Settings): no swells. Nothing here needs an uploaded picture: every particle uses Roblox's
	built-in sparkle and smoke (Shared/FxTexture's stand-ins); the shapes are neon parts and plain beams.
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

-- The heavenly look (Lighting, on this screen only), blended in by Shared/DivineReveal.heaven. Daylight, warmer and
-- brighter: never night (that is the Secret one's).
local HEAVEN_LOOK = {
	-- (dimmer than the day, so the gold glows against it: critic, Oct 26)
	Lighting = { Ambient = rgb(96, 78, 62), OutdoorAmbient = rgb(140, 112, 86), Brightness = 1.3 },
	Atmosphere = { Density = 0.3, Offset = 0.25, Color = rgb(255, 226, 176), Decay = rgb(255, 194, 128), Glare = 0.5, Haze = 1.6 },
	BloomEffect = { Intensity = 0.5, Size = 30, Threshold = 0.95 }, -- (gentle: the light here is already bright)
	SunRaysEffect = { Intensity = 0.12, Spread = 0.7 },
	Clouds = { Cover = 0.5, Density = 0.55, Color = rgb(255, 236, 210) },
}

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
	local pillarPart, pillarLight = lamp("PillarLight", rgb(255, 222, 150), 0, 50 * k)
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

	-- the sky: a disc of heaven's light in a ring of cloud
	local disc = part({ Name = "HeavenDisc", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = CREAM,
		Size = Vector3.new(0.4, 1, 1), CFrame = CFrame.new(skyAt) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }, folder)
	local discGlow = part({ Name = "HeavenGlow", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = PALE,
		Size = Vector3.new(0.6, 1, 1), CFrame = CFrame.new(skyAt - up * 0.6) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }, folder)
	local cloudRing = part({ Name = "CloudRing", Transparency = 1, Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(skyAt - up * 2 * k) }, folder)
	local cloudProps = {
		Picture = { "Wisp" }, Color = seq(rgb(255, 248, 236), rgb(236, 214, 190)), LightEmission = 0.15, Brightness = 1.3,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapePartial = 1,
		EmissionDirection = Enum.NormalId.Bottom, Size = sizeSeq({ { 0, 18 * k }, { 1, 28 * k } }),
		Transparency = nseq({ { 0, 1 }, { 0.25, 0.3 }, { 0.75, 0.35 }, { 1, 1 } }), Lifetime = NumberRange.new(1.8, 2.6),
		Speed = NumberRange.new(1 * k, 2.5 * k), SpreadAngle = Vector2.new(40, 40), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
	}
	local cloudsIn = emitter(cloudRing, cloudProps)
	local cloudOuter = part({ Name = "CloudOuter", Transparency = 1, Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(skyAt + up * 2 * k) }, folder)
	cloudProps.Size = sizeSeq({ { 0, 26 * k }, { 1, 38 * k } })
	cloudProps.Color = seq(rgb(250, 238, 222), rgb(226, 200, 176))
	local cloudsOut = emitter(cloudOuter, cloudProps)

	-- the god rays: each a soft core and a wide faint glow, from inside the disc to a foot on the ground
	local rays = {}
	for i, def in Reveal.RAY_FEET do
		local a0, a1 = anchor(), anchor()
		table.insert(rays, {
			def = def, a0 = a0, a1 = a1,
			glow = beam(a0, a1, seq(CREAM, PALE, GOLD), { Segments = 6 }),
			core = beam(a0, a1, seq(WHITE, CREAM, PALE), { Segments = 6 }),
		})
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

	-- the pillar: layered beams from the sky to the ground, a shimmering shell round them
	local pTop, pFoot = anchor(), anchor()
	local PILLAR_COLORS = { rgb(255, 186, 84), rgb(255, 212, 128), rgb(255, 234, 178), rgb(255, 248, 224), WHITE }
	local pillar = {}
	for i, L in Reveal.PILLAR_LAYERS do
		pillar[i] = { b = beam(pTop, pFoot, PILLAR_COLORS[i], { Segments = 4 }), def = L }
	end
	local shell = part({ Name = "PillarShell", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = PALE,
		Size = Vector3.new(1, 1, 1), Transparency = 1 }, folder)
	local pillarBase = part({ Name = "PillarBase", Transparency = 1, Size = Vector3.new(7 * k, 0.5, 7 * k), CFrame = CFrame.new(floorAt) }, folder)
	local upSparks = emitter(pillarBase, { Picture = { "Spark" }, Color = seq(WHITE, PALE, GOLD), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0.5 * k }, { 1, 0.15 * k } }),
		Squash = sizeSeq({ { 0, 2 }, { 1, 3 } }), Transparency = nseq({ { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(22 * k, 36 * k), SpreadAngle = Vector2.new(6, 6) })

	-- the air: gold motes rising round the spot, flakes of light drifting down from the halo
	local air = part({ Name = "Air", Transparency = 1, Size = Vector3.new(70 * k, 2, 70 * k), CFrame = CFrame.new(ground + up * 2 * k) }, folder)
	local motes = emitter(air, { Picture = { "Bokeh" }, Color = seq(rgb(255, 236, 170), rgb(255, 196, 90)), LightEmission = 1, Brightness = 2,
		Size = sizeSeq({ { 0, 0 }, { 0.15, 0.7 * k }, { 0.85, 0.6 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.15 }, { 1, 0.5 } }),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1 * k, 2 * k), SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 1.2 * k, 0), Drag = 0.4 })
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
		}
	end
	local footBurst, backBurst, heartBurst = burst(foot, 1.2), burst(back, 1), burst(heart, 1.3)
	-- a bed of soft cloud on the ground round her (covers the grass: she lands on clouds)
	local mistBed = part({ Name = "MistBed", Transparency = 1, Size = Vector3.new(34 * k, 0.4, 34 * k), CFrame = CFrame.new(floorAt + up * 0.4) }, folder)
	local mist = emitter(mistBed, { Picture = { "Wisp" }, Color = seq(rgb(255, 250, 238), rgb(244, 226, 200)), LightEmission = 0.2, Brightness = 1.2,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, ShapePartial = 1,
		EmissionDirection = Enum.NormalId.Top, Size = sizeSeq({ { 0, 7 * k }, { 1, 12 * k } }), Transparency = nseq({ { 0, 1 }, { 0.3, 0.45 }, { 0.75, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.3 * k, 0.8 * k), SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10) })
	local dust = emitter(foot, { Picture = { "Wisp" }, Color = seq(rgb(255, 246, 226), rgb(236, 206, 160)), LightEmission = 0.2,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapePartial = 1,
		EmissionDirection = Enum.NormalId.Top, Size = sizeSeq({ { 0, 2 * k }, { 1, 6 * k } }),
		Transparency = nseq({ { 0, 0.45 }, { 1, 1 } }), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(2 * k, 5 * k),
		SpreadAngle = Vector2.new(60, 60), Drag = 2, Rotation = NumberRange.new(0, 360) })
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
				glow = beam(a0, a1, seq(GOLD, AMBER, rgb(255, 130, 40)), { Segments = 2, LightEmission = 0.6 }), -- (gold edges: white alone vanished on bright sky)
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
		mist.Rate = if t >= Reveal.SIGIL - 0.6 and t < Reveal.RISE + 0.3 then 14 else 0
		if t >= Reveal.SIGIL - 0.6 then once("mistIn", function() mist:Emit(20) end) end

		-- the sky opening: the cloud ring widens, heaven's light grows inside it; both close again at the end
		local open = Reveal.skyOpen(t)
		local hole = (12 + (Reveal.SKY_RADIUS - 12) * open) * k
		cloudRing.Size = Vector3.new(hole * 2, 1, hole * 2)
		cloudOuter.Size = Vector3.new(hole * 3, 1, hole * 3)
		local cloudy = t < Reveal.CLOSE + 1.2
		cloudsIn.Rate = if cloudy then 40 else 0
		cloudsOut.Rate = if cloudy then 24 else 0
		once("clouds", function() cloudsIn:Emit(50); cloudsOut:Emit(30) end)
		local d = math.max(hole * 1.7 * open, 0.1)
		disc.Size = Vector3.new(0.4, d, d)
		disc.Transparency = 1 - 0.85 * open
		discGlow.Size = Vector3.new(0.6, d * 1.4, d * 1.4)
		discGlow.Transparency = 1 - 0.7 * open

		local skyA = open * (1 - Reveal.smooth((t - Reveal.CLOSE) / 0.8))
		local tiltSky = CFrame.fromAxisAngle(side, math.rad(10)):VectorToWorldSpace(dir)
		setRing(skyRings[1], skyAt - up * 4 * k, side, tiltSky, (Reveal.SKY_RADIUS + 12) * k, 0.9 * k, 0.55 * skyA, t * 0.12)
		setRing(skyRings[2], skyAt - up * 9 * k, side, dir, (Reveal.SKY_RADIUS + 3) * k, 0.6 * k, 0.45 * skyA, -t * 0.18)

		-- the god rays sway slowly over the ground
		for i, r in rays do
			local power, sway = Reveal.ray(t, i)
			power *= open
			local a = math.rad(r.def.ang + sway)
			local out = dir * math.cos(a) + side * math.sin(a)
			r.a0.WorldPosition = skyAt + out * hole * 0.45
			r.a1.WorldPosition = floorAt + out * r.def.out * k
			local reach = Reveal.easeOut((t - Reveal.RAYS - (i - 1) * Reveal.RAY_GAP) / 0.5) -- (its light comes down out of the sky)
			if reach < 1 then r.a1.WorldPosition = r.a0.WorldPosition:Lerp(r.a1.WorldPosition, reach) end
			r.core.Width0, r.core.Width1 = r.def.w0 * k * 0.35, r.def.w1 * k * 0.35
			r.glow.Width0, r.glow.Width1 = r.def.w0 * k * 0.8, r.def.w1 * k * 0.8
			-- (faint: seven of them overlap, and they add light; the first film was washed out)
			setAlpha(r.core, 0.22 * power, 0.12, 0.3, 0.6)
			setAlpha(r.glow, 0.07 * power, 0.12, 0.25, 0.6)
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
		glow *= 0.75 -- (gold on green adds up to a hot yellow: kept softer)
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
		local tall = Reveal.SKY * k * reach
		shell.CFrame = CFrame.new(skyAt - up * tall / 2) * CFrame.Angles(0, 0, math.pi / 2)
		shell.Size = Vector3.new(math.max(tall, 0.1), 9 * k * width, 9 * k * width)
		shell.Transparency = 1 - 0.2 * power
		upSparks.Rate = if power > 0.2 then 45 * power else 0
		pillarLight.Brightness = 3 * power
		if t >= Reveal.PILLAR then
			once("pillar", function()
				footBurst.sparks:Emit(40); footBurst.glints:Emit(14); dust:Emit(18)
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
			once("touch", function() dust:Emit(16); footBurst.glints:Emit(8) end)
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
		grade.TintColor = WHITE:Lerp(rgb(255, 222, 172), tint) -- (golden hour)
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
		if ratingWas ~= nil then pcall(function() (rating :: BillboardGui).Enabled = ratingWas end) end
		for _, b in beams do b:Destroy() end
		for _, a in anchors do a:Destroy() end
	end
	if M.failForTest then error("test: build failed on purpose") end
	nameGui.Parent = if player then player:WaitForChild("PlayerGui") else nil
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
