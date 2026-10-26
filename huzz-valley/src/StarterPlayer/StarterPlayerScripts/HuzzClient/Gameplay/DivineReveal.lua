--[[
	The Divine girl's arrival cutscene, "Fallen Star" (the timing, the shot and the camera: Shared/DivineReveal;
	owner, Oct 26: "make it completely different from the secret animation"; 17:42 "follow the animation styles as
	references given before, right now it looks too ai made"; 18:34 "remove the very basic ai looking effects of the
	start, and continuation, make it different"). Gameplay/SecretReveal plays it (its play() picks this one when the
	showcase's RevealKind is "Divine": the same camera planning, steady clock and hand-back), and this builds the
	effects and poses her. Drawn as the reference anime VFX are: a dark night, hard shapes with a white-hot core and a
	gold band, curves and swirls rather than perfect rings and straight sticks, fast in and snapping out:
	  the light    your Lighting, on this screen only: a deep blue night with stars, a dark haze, more bloom, a cool
	               hard grade and a vignette; all put back exactly afterwards
	  the star     a white-hot star twinkling on high falls with a long gold tail, shedding sparks
	  the crash    the impact frame, a shockwave over the ground, gold shards flying, jagged cracks of light racing
	               out over the ground from a glowing crater
	  whirlwind    twelve golden crescents rise out of the crater and whirl round the spot, tighter, taller and
	               faster, sparks swirling up, lightning jumping from them to the cracks; three slashes cross the
	               picture as it winds up
	  the burst    crescent slashes cut it open and it flies apart; she bursts out spinning, lit white; star flares,
	               feathers, rings of light; curved wings of light (two rows of pointed feathers) snap open; a crown halo
	  her name     DIVINE and 8 stars in gold, her name with a shine sweeping over it, gold lines drawing out
	  ascension    the wings beat; the crescents spiral up round her as she rises; the wings fade into sparkles; she
	               twinkles like the star she came as
	Flashes: the impact frame, the burst and a small swell (kid-safe: over a second apart).
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
	local floorAt = ground + up * 0.25
	local folder = Instance.new("Folder")
	folder.Name = "HuzzDivineReveal"
	folder.Parent = Workspace
	table.insert(junk, folder)

	-- her lights: a warm key light from the camera's side, a gold rim from behind and above; the crater's glow on the
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
	local craterPart, craterLight = lamp("CraterLight", rgb(255, 230, 180), 0, 40 * k)
	craterPart.CFrame = CFrame.new(ground + up * 3 * k)
	craterLight.Enabled = true

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

	-- the falling star: a white-hot core (a twinkle round it), a long gold tail (a white core in a gold band), sparks
	-- shed behind it
	local starCore = part({ Name = "Star", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = CREAM, Size = Vector3.one, Transparency = 1 }, folder)
	local tailA0, tailA1 = anchor(), anchor()
	local tailGlow = beam(tailA0, tailA1, seq(WHITE, SUN, AMBER), { Transparency = TAPER, Segments = 1 })
	local tailCore = beam(tailA0, tailA1, seq(WHITE, CREAM), { Transparency = TAPER, Segments = 1 })
	local starSparks = emitter(starCore, { Picture = { "Spark" }, Color = seq(WHITE, SUN, AMBER), LightEmission = 1, Brightness = 2,
		Size = sizeSeq({ { 0, 0.7 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0 }, { 1, 0.4 } }), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2 * k, 6 * k), SpreadAngle = Vector2.new(180, 180), Drag = 3 })
	local starFrom: Vector3? = nil

	-- the cracks of light: jagged lines of neon over the ground (a white-hot core over a wider gold band), each with one
	-- branch, racing out from a glowing crater. Laid out once (studs from the spot, scaled).
	local crackRnd = Random.new(23)
	local segs, crackEnds = {}, {}
	local function addCrack(from: Vector3, heading: number, lens, startAt: number, w: number)
		local p, at = from, startAt
		local pts = {}
		for j, L in lens do
			heading += math.rad(crackRnd:NextNumber(-Reveal.CRACK_WANDER, Reveal.CRACK_WANDER))
			local step = Vector3.new(math.cos(heading), 0, math.sin(heading)) * L * k
			local width = w * (1 - 0.6 * (j - 1) / #lens) * k
			table.insert(segs, { from = p, unit = step.Unit, len = step.Magnitude, at = at, w = width,
				core = part({ Name = "Crack", Material = Enum.Material.Neon, Color = CREAM, Size = Vector3.one * 0.05, Transparency = 1 }, folder),
				glow = part({ Name = "CrackGlow", Material = Enum.Material.Neon, Color = rgb(255, 214, 120), Size = Vector3.one * 0.05, Transparency = 1 }, folder) })
			pts[j] = p
			p += step
			at += L
		end
		table.insert(crackEnds, p)
		return pts, at
	end
	local crackLen = 0
	for i = 1, Reveal.CRACKS do
		local a = (i - 1) / Reveal.CRACKS * math.pi * 2 + crackRnd:NextNumber(-0.25, 0.25)
		local pts, total = addCrack(Vector3.new(math.cos(a), 0, math.sin(a)) * 1.6 * k, a, Reveal.CRACK_SEGMENTS, 0, 0.9)
		crackLen = math.max(crackLen, total)
		local fork = pts[3]
		local _, total2 = addCrack(fork, a + math.rad(if i % 2 == 0 then 40 else -40), { 2.2, 1.8, 1.4 }, 6.8, 0.55)
		crackLen = math.max(crackLen, total2)
	end
	local crater = part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = PALE,
		Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(floorAt) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }, folder)

	-- the whirlwind: twelve golden crescents (curved beams, white-hot at the head, thinning to nothing at the tail)
	-- whirling round the spot; after RISE the same crescents spiral up round her
	local arcRnd = Random.new(41)
	local arcs = {}
	local ARC_FADE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(1, 0) })
	for i = 1, Reveal.ARCS do
		local a0, a1 = anchor(), anchor()
		arcs[i] = { i = i, a0 = a0, a1 = a1, hf = (i - 0.5) / Reveal.ARCS, phase = i * 2.4, tilt = math.rad(arcRnd:NextNumber(-14, 14)),
			w = arcRnd:NextNumber(0.8, 1.3), span = math.rad(arcRnd:NextNumber(100, 140)),
			glow = beam(a0, a1, seq(AMBER, SUN, WHITE), { Transparency = ARC_FADE, Segments = 12 }),
			core = beam(a0, a1, seq(SUN, WHITE), { Transparency = ARC_FADE, Segments = 12 }) }
	end
	local function setArc(arc, centre: Vector3, side: Vector3, R: number, th0: number, span: number, w: number, alpha: number)
		if alpha <= 0.01 or R <= 0.01 then
			if arc.on then
				arc.on = false
				arc.glow.Width1, arc.core.Width1 = 0, 0
			end
			return
		end
		arc.on = true
		local axis = (up * math.cos(arc.tilt) + side * math.sin(arc.tilt)).Unit
		local u = side - axis * side:Dot(axis)
		u = if u.Magnitude > 1e-3 then u.Unit else Vector3.new(1, 0, 0)
		local v = axis:Cross(u)
		local th1 = th0 + span
		local p0, p1 = centre + (u * math.cos(th0) + v * math.sin(th0)) * R, centre + (u * math.cos(th1) + v * math.sin(th1)) * R
		local t0, t1 = -u * math.sin(th0) + v * math.cos(th0), -u * math.sin(th1) + v * math.cos(th1)
		arc.a0.WorldCFrame = CFrame.fromMatrix(p0, t0, axis)
		arc.a1.WorldCFrame = CFrame.fromMatrix(p1, t1, axis)
		local handle = 4 / 3 * math.tan(span / 4) * R -- (a cubic's handles for a circular arc)
		for _, b in { arc.glow, arc.core } do b.CurveSize0, b.CurveSize1 = handle, handle end
		arc.glow.Width0, arc.glow.Width1 = 0, 1.1 * k * w * alpha -- (thinner: wider read as flat paper tape, critic Oct 26)
		arc.core.Width0, arc.core.Width1 = 0, 0.35 * k * w * alpha
	end
	-- sparks swirling up the whirlwind
	local swirlBase = part({ Name = "Swirl", Transparency = 1, Size = Vector3.new(10 * k, 0.5, 10 * k), CFrame = CFrame.new(floorAt) }, folder)
	local swirl = emitter(swirlBase, { Picture = { "Spark" }, Color = seq(WHITE, SUN, AMBER), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0.5 * k }, { 1, 0.1 * k } }),
		Squash = sizeSeq({ { 0, 2 }, { 1, 3 } }), Transparency = nseq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(14 * k, 26 * k), SpreadAngle = Vector2.new(20, 20) })
	-- lightning jumping from the whirlwind to the cracks: jagged threads, each bend jumping every 0.08 s
	local bolts = {}
	for i = 1, 5 do
		local b = { i = i, atts = {}, segs = {}, at = -1, n = 6, from = Vector3.zero, to = Vector3.zero, off = {} }
		for q = 0, b.n do
			b.atts[q] = anchor()
			b.off[q] = 0
		end
		for q = 0, b.n - 1 do b.segs[q] = beam(b.atts[q], b.atts[q + 1], seq(WHITE, PALE), { Segments = 1 }) end
		bolts[i] = b
	end
	local boltRnd = Random.new(77)

	-- shockwaves and the crown halo (rings of short neon pieces)
	local rings = {
		crash = newRing(PALE, 56), burstFloor = newRing(SUN, 56), settle = newRing(PALE, 40),
	}
	local crown = newRing(SUN, 28)

	-- the air: gold embers rising round the spot
	local air = part({ Name = "Air", Transparency = 1, Size = Vector3.new(70 * k, 2, 70 * k), CFrame = CFrame.new(ground + up * 2 * k) }, folder)
	local motes = emitter(air, { Picture = { "Spark" }, Color = seq(rgb(255, 236, 170), rgb(255, 196, 90)), LightEmission = 1, Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = sizeSeq({ { 0, 0 }, { 0.15, 0.45 * k }, { 0.85, 0.35 * k }, { 1, 0 } }),
		Squash = sizeSeq({ { 0, 2 }, { 1, 2 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(3 * k, 6 * k), SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 1.5 * k, 0) })
	-- bursts of light: at the crater, at her back (wings) and at her middle
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
	-- gold shards torn out of the ground where the star hits and where she bursts out (the green reference's debris), flying up
	-- and falling back, turning; drawn by the step
	local rocks = {}
	local rockRnd = Random.new(57)
	for i = 1, 30 do
		local sz = rockRnd:NextNumber(0.5, 1.5) * k
		local a = rockRnd:NextNumber(0, math.pi * 2)
		rocks[i] = {
			p = part({ Name = "Shard", Material = Enum.Material.Neon, Color = if i % 3 == 0 then WHITE else SUN, Size = Vector3.new(sz * 0.3, sz * 1.3, sz * 0.15), Transparency = 1 }, folder),
			at = if i <= 18 then Reveal.CRASH else Reveal.BURST, a = a, r = rockRnd:NextNumber(2, 5) * k,
			out = rockRnd:NextNumber(8, 18) * k, upv = rockRnd:NextNumber(22, 38) * k, spin = Vector3.new(rockRnd:NextNumber(-1, 1), rockRnd:NextNumber(-1, 1), rockRnd:NextNumber(0.2, 1)).Unit * rockRnd:NextNumber(4, 10),
			size = Vector3.new(sz * 0.3, sz * 1.3, sz * 0.15), -- (gold shards: brown rock read as dirt)
		}
	end
	local wingDust = emitter(back, { Picture = { "Feather" }, Color = seq(WHITE, PALE), LightEmission = 0.8, Brightness = 1.8,
		Size = sizeSeq({ { 0, 0.9 * k }, { 1, 0 } }), Transparency = nseq({ { 0, 0.1 }, { 1, 0.6 } }),
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1 * k, 3 * k), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -2 * k, 0), Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60) })

	-- her wings: two rows of pointed, curved feathers from her shoulder blades (long flight feathers, short coverts
	-- over them), each a white core over a gold band
	local wings = {}
	for _, s in { -1, 1 } do
		for row = 1, 2 do
			for i, def in Reveal.FEATHERS do
				local a0, a1 = anchor(), anchor()
				table.insert(wings, {
					s = s, i = i, row = row, def = def, a0 = a0, a1 = a1,
					glow = beam(a0, a1, if row == 1 then seq(SUN, GOLD, AMBER) else seq(PALE, SUN, GOLD), { Segments = 8 }),
					core = beam(a0, a1, seq(WHITE, CREAM, PALE), { Segments = 8 }),
				})
			end
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

	-- slashes across the picture, crescent swings round her and star flares
	-- (all laid out from the camera, so they read the same from any angle)
	local function pair(color, glowW)
		local a0, a1 = anchor(), anchor()
		return { a0 = a0, a1 = a1, glow = beam(a0, a1, color, { Transparency = TAPER, Segments = 2 }), core = beam(a0, a1, WHITE, { Transparency = TAPER, Segments = 2 }), gw = glowW }
	end
	local slashes = {}
	for i, at in Reveal.SLASHES do
		local sl = pair(seq(WHITE, SUN), 1.8) -- (thin and white-hot: the wider beige bar read dull)
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
	local function newFlare()
		local f = { spikes = {} }
		f.core = part({ Name = "Flare", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = CREAM, Size = Vector3.one, Transparency = 1 }, folder)
		for j = 1, 8 do
			local a0, a1 = anchor(), anchor()
			f.spikes[j] = { a0 = a0, a1 = a1, b = beam(a0, a1, seq(WHITE, GOLD), { Transparency = TAPER, Segments = 1 }) }
		end
		return f
	end
	local flares = { newFlare(), newFlare(), newFlare(), newFlare(), newFlare() } -- (the burst x2, the swell, the star, the last twinkle)
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
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.82, 0), NumberSequenceKeypoint.new(1, 1) }) -- (hard ink, a short taper)
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
			(s.inst :: any)[s.key] = lerp(s.was, s.target, on)
		end
		Lighting.ClockTime = Reveal.clock(t, day)
		once("start", function()
			motes:Emit(30)
			Sfx.beat("Build", Reveal.CRASH) -- (the riser tops out on the crash)
		end)
		motes.Rate = if on > 0.3 and t < Reveal.CLOSE then 28 else 0

		-- the falling star (its path is laid out once, from where the camera first is: high up behind the spot)
		local s, sa, tail = Reveal.star(t)
		if not starFrom then
			local back = Vector3.new(ground.X - camPos.X, 0, ground.Z - camPos.Z)
			back = if back.Magnitude > 0.1 then back.Unit else -dir
			local right = back:Cross(up).Unit
			local F = Reveal.STAR_FROM
			starFrom = ground + right * F[1] * k + up * F[2] * k + back * F[3] * k
		end
		local from = starFrom :: Vector3
		local function path(x: number): Vector3
			return from:Lerp(floorAt, x) + up * math.sin(x * math.pi) * 6 * k
		end
		if sa > 0 then
			local at = path(s)
			starCore.CFrame = CFrame.new(at)
			starCore.Size = Vector3.one * (2.2 + 1 * tail) * k -- (first film: too small to read at that distance)
			starCore.Transparency = 1 - sa
			-- (the twinkle: its points grow and shrink a little, never blinking)
			setFlare(flares[4], at, (1.1 + 0.2 * math.sin(t * 11)) * k * (1 + 0.5 * tail), sa, camR, camU)
			local behind = (path(math.max(0, s - 0.02)) - at)
			behind = if behind.Magnitude > 1e-3 then behind.Unit else (from - floorAt).Unit
			tailA0.WorldPosition, tailA1.WorldPosition = at, at + behind * 40 * k * tail
			tailGlow.Width0, tailGlow.Width1 = 5 * k * tail, 0.5 * k * tail
			tailCore.Width0, tailCore.Width1 = 1.8 * k * tail, 0
			starSparks.Rate = 70 * tail
		else
			starCore.Transparency = 1
			setFlare(flares[4], floorAt, 0.05, 0, camR, camU)
			tailGlow.Width0, tailGlow.Width1, tailCore.Width0, tailCore.Width1 = 0, 0, 0, 0
			starSparks.Rate = 0
		end

		-- the crash
		if t >= Reveal.CRASH then
			once("crash", function()
				footBurst.sparks:Emit(50); footBurst.shards:Emit(24); footBurst.glints:Emit(14)
				Sfx.beat("Burst")
			end)
		end
		ringAt(rings.crash, Reveal.CRASH, 0.8, t, floorAt + up * 0.1, side, dir, 2 * k, 38 * k, 0.7 * k)

		-- the cracks of light racing out over the ground, the glowing crater
		local crackGrow, cg = Reveal.cracks(t)
		local reachAll = crackGrow * crackLen
		for _, sg in segs do
			local reach = (reachAll - sg.at) * k
			if cg <= 0.01 or reach <= 0 then
				if sg.shown then sg.core.Transparency, sg.glow.Transparency, sg.shown = 1, 1, false end
				continue
			end
			sg.shown = true
			local len = math.min(sg.len, reach)
			local p0 = floorAt + sg.from
			local c = p0 + sg.unit * len / 2
			sg.core.CFrame = CFrame.fromMatrix(c + up * 0.08, sg.unit, up)
			sg.core.Size = Vector3.new(math.max(len, 0.05), 0.1, math.max(sg.w * 0.35, 0.05))
			sg.glow.CFrame = CFrame.fromMatrix(c + up * 0.04, sg.unit, up)
			sg.glow.Size = Vector3.new(math.max(len + 0.3 * k, 0.05), 0.06, math.max(sg.w, 0.05))
			sg.core.Transparency = 1 - cg
			sg.glow.Transparency = 1 - 0.5 * cg -- (gold over green grass went lime on the first film)
		end
		local cd = 3.2 * k * crackGrow
		crater.Size = Vector3.new(0.1, math.max(cd, 0.05), math.max(cd, 0.05))
		crater.Transparency = 1 - 0.75 * cg
		local tall, R, turn, va, out, spiral = Reveal.vortex(t)
		craterLight.Brightness = 0.6 * cg + 0.8 * va

		-- her: hidden until she bursts out, then spinning to a stop as she settles, standing, rising to her place
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
			local toCam = Vector3.new(camPos.X - herMid.X, 0, camPos.Z - herMid.Z)
			toCam = if toCam.Magnitude > 0.1 then toCam.Unit else dir
			keyPart.CFrame = CFrame.new(herMid + toCam * 7 * k + up * mid * 0.4)
			rimPart.CFrame = CFrame.new(herMid - toCam * 5 * k + up * mid * 0.9)
		end
		local white = Reveal.glow(t)
		local rimOut = Reveal.smooth((t - Reveal.RISE) / 0.8)
		if h then
			hl.FillTransparency = 1 - 0.6 * white
			hl.OutlineColor = WHITE:Lerp(RIM, 1 - white)
			hl.OutlineTransparency = math.min(1, 0.1 + 0.45 * (1 - white) + 0.45 * rimOut)
		end

		-- the whirlwind: rising out of the crater, winding tighter and faster; flying apart at the burst; after RISE the
		-- same crescents spiral up round her
		local H = 2.6 * mid * tall
		for _, arc in arcs do
			if va > 0.01 then
				local y = arc.hf * H * (1 + 0.5 * out)
				local r = R * k * (0.7 + 0.6 * arc.hf) * (1 + 3 * out)
				setArc(arc, floorAt + up * y, side, r, turn * (1 + 0.3 * arc.hf) + arc.phase, arc.span, arc.w, va)
			elseif spiral > 0.01 then
				local y = (arc.hf - 0.5) * mid * 2.6
				local r = (3.2 + 1.2 * math.sin(arc.phase + t * 2)) * k
				setArc(arc, herMid + up * y, side, r, turn * 1.4 + arc.phase, math.rad(160), arc.w * 0.8, spiral * 0.85)
			else
				setArc(arc, herMid, side, 0, 0, 0, 0, 0)
			end
		end
		swirlBase.Size = Vector3.new(math.max(2 * R * k, 0.1), 0.5, math.max(2 * R * k, 0.1))
		swirl.Rate = if va > 0.3 and t < Reveal.BURST then 110 * va else 0
		if t >= Reveal.VORTEX then once("vortex", function() Sfx.beat("Build", Reveal.BURST - Reveal.VORTEX) end) end

		-- lightning from the whirlwind to the cracks
		local boltOn = Reveal.bolts(t)
		for _, b in bolts do
			if not boltOn then
				if b.shown then
					for _, sgm in b.segs do sgm.Width0, sgm.Width1 = 0, 0 end
					b.shown = false
				end
				continue
			end
			if t - b.at > 0.08 + b.i * 0.013 and (not calm or b.at < 0) then
				b.at = t
				local a = boltRnd:NextNumber(0, math.pi * 2)
				b.from = floorAt + up * boltRnd:NextNumber(0.2, 0.9) * H + (side * math.cos(a) + dir * math.sin(a)) * R * k
				b.to = floorAt + crackEnds[boltRnd:NextInteger(1, #crackEnds)] + up * 0.2
				for q = 1, b.n - 1 do b.off[q] = boltRnd:NextNumber(-1, 1) end
			end
			b.shown = true
			local along = b.to - b.from
			local nv = along:Cross(camPos - b.from)
			nv = if nv.Magnitude > 1e-3 then nv.Unit else side
			for q = 0, b.n do
				b.atts[q].WorldPosition = b.from + along * (q / b.n) + nv * b.off[q] * along.Magnitude * 0.08
			end
			for _, sgm in b.segs do sgm.Width0, sgm.Width1 = 0.3 * k, 0.3 * k end
		end

		-- the slashes: snapping across the picture over the whirlwind, drifting sideways as they thin out
		for _, sl in slashes do
			local v = Reveal.slash(t, sl.at)
			local flip = if sl.i % 2 == 0 then -1 else 1
			local c = ground + up * (mid * 1.1 + ({ 3, -2, 6 })[sl.i] * k) + camR * math.max(0, t - sl.at) * 30 * k * flip
			local len, tilt = 30 * k, 7 * k
			sl.a0.WorldPosition = c - camR * len + camU * tilt * flip
			sl.a1.WorldPosition = c + camR * len - camU * tilt * flip
			sl.glow.Width0, sl.glow.Width1 = sl.gw * k * v, sl.gw * k * v
			sl.core.Width0, sl.core.Width1 = 0.7 * k * v, 0.7 * k * v
		end

		-- the burst: crescent slashes round her, star flares, feathers, rings of light
		if t >= Reveal.BURST then
			once("burst", function()
				heartBurst.sparks:Emit(48); heartBurst.glints:Emit(14); heartBurst.shards:Emit(16)
				backBurst.sparks:Emit(30); wingDust:Emit(30)
				Sfx.play("secret_impact")
			end)
		end
		for _, sw in swings do
			local v = Reveal.swing(t, sw.at)
			if v <= 0 then sw.glow.Width0, sw.glow.Width1, sw.core.Width0, sw.core.Width1 = 0, 0, 0, 0; continue end
			local tilt = math.rad(sw.tilt)
			local axis = (up * math.cos(tilt) + dir * math.sin(tilt)).Unit
			local u = (dir - axis * dir:Dot(axis)).Unit
			local w = axis:Cross(u)
			local th0 = math.rad(sw.start) + (t - sw.at) * 4
			local th1 = th0 + math.rad(150)
			local Rs = (8 + 6 * (t - sw.at)) * k
			local c = herMid + up * sw.lift * k
			local p0, p1 = c + (u * math.cos(th0) + w * math.sin(th0)) * Rs, c + (u * math.cos(th1) + w * math.sin(th1)) * Rs
			local t0, t1 = -u * math.sin(th0) + w * math.cos(th0), -u * math.sin(th1) + w * math.cos(th1)
			sw.a0.WorldCFrame = CFrame.fromMatrix(p0, t0, axis)
			sw.a1.WorldCFrame = CFrame.fromMatrix(p1, t1, axis)
			for _, b in { sw.glow, sw.core } do b.CurveSize0, b.CurveSize1 = Rs * 1.02, Rs * 1.02 end
			sw.glow.Width0, sw.glow.Width1 = 0, sw.gw * k * v
			sw.core.Width0, sw.core.Width1 = 0, 0.5 * k * v
		end
		local bf = Reveal.slash(t, Reveal.BURST)
		setFlare(flares[1], herMid - camR * 9 * k + camU * 3 * k, 1.1 * k, bf, camR, camU)
		setFlare(flares[2], herMid + camR * 10 * k - camU * 2 * k, 0.9 * k, bf, camR, camU)
		ringAt(rings.burstFloor, Reveal.BURST, 0.7, t, floorAt + up * 0.12, side, dir, 3 * k, 30 * k, 0.5 * k)

		-- shards flying up and falling back (at the crash and the burst)
		for _, rk in rocks do
			local x = t - rk.at
			if x < 0 or x > 1.3 then
				if rk.shown then rk.p.Transparency = 1; rk.shown = false end
				continue
			end
			local outv = side * math.cos(rk.a) + dir * math.sin(rk.a)
			local y = rk.upv * x - 30 * k * x * x
			if y < 0 and x > 0.2 then
				if rk.shown then rk.p.Transparency = 1; rk.shown = false end
				continue
			end
			rk.shown = true
			local p = floorAt + outv * (rk.r + rk.out * x / (1 + 2 * x)) + up * math.max(y, 0)
			rk.p.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(rk.spin.Unit, rk.spin.Magnitude * x)
			rk.p.Size = rk.size * (1 - 0.5 * Reveal.smooth((x - 0.9) / 0.4))
			rk.p.Transparency = 0
		end

		-- her wings: snapping open as she bursts out, each feather a beat after the one above it, curved: leaving her back
		-- steep and sweeping out to a point
		local wingOpen, wingSeen = Reveal.wings(t)
		if pose and wingSeen > 0.01 then
			local fwd = Vector3.new(pose.LookVector.X, 0, pose.LookVector.Z)
			fwd = if fwd.Magnitude > 0.1 then fwd.Unit else dir
			local right = fwd:Cross(up).Unit
			local shoulder = feet + up * mid * 1.45 - fwd * 0.6 * k
			back.CFrame = CFrame.lookAt(shoulder - fwd * 1.5 * k, shoulder - fwd * 3 * k)
			-- (a real wing's shape, not a fan: the feathers hang off a leading edge that runs up and out from her shoulder
			-- to the wrist; the inner ones point down and out, the outer ones out and up, longest at the tip)
			local bend = math.rad(18)
			local function across(a: number, sgn: number): Vector3
				return (up * math.cos(a) + right * sgn * math.sin(a) - fwd * 0.32).Unit
			end
			local n = #Reveal.FEATHERS
			for _, w in wings do
				local fOpen = math.min(wingOpen, (Reveal.wings(t - (w.i - 1) * 0.03)))
				local o = math.clamp(fOpen, 0, 1.1)
				local f = (w.i - 1) / (n - 1) -- (0 at her shoulder, 1 at the wing tip)
				local edgeAng = math.rad(lerp(12, 52, o))
				local span = mid * 1.2 * (0.3 + 0.7 * o)
				local root = shoulder + right * w.s * 0.45 * k + across(edgeAng, w.s) * span * f + (if w.row == 2 then -fwd * 0.15 * k else Vector3.zero)
				local a = math.rad(lerp(Reveal.FOLDED, lerp(155, 72, f), o))
				local len = mid * (0.55 + 0.55 * f) * (0.4 + 0.6 * o) * (if w.row == 2 then 0.5 else 1)
				local x0, x1 = across(a - bend, w.s), across(a + bend, w.s)
				local tip = root + across(a, w.s) * len
				local y0, y1 = x0:Cross(fwd), x1:Cross(fwd)
				y0 = if y0.Magnitude > 1e-3 then y0.Unit else right
				y1 = if y1.Magnitude > 1e-3 then y1.Unit else right
				w.a0.WorldCFrame = CFrame.fromMatrix(root, x0, y0)
				w.a1.WorldCFrame = CFrame.fromMatrix(tip, x1, y1)
				for _, bm in { w.core, w.glow } do bm.CurveSize0, bm.CurveSize1 = len * 0.3, len * 0.22 end
				local wd = w.def.w * k * (0.5 + 0.5 * math.clamp(wingOpen, 0, 1)) * (if w.row == 2 then 1.3 else 1.1)
				w.core.Width0, w.core.Width1 = wd * 0.35, wd * 0.06 -- (pointed: wide at the root, a point at the tip)
				w.glow.Width0, w.glow.Width1 = wd * 0.95, wd * 0.18
				setAlpha(w.core, 0.95 * wingSeen, 0.08, 0.1)
				setAlpha(w.glow, 0.7 * wingSeen, 0.08, 0.12)
			end
		else
			for _, w in wings do
				setAlpha(w.core, 0, 0.08, 0.1)
				setAlpha(w.glow, 0, 0.08, 0.12)
			end
		end
		wingDust.Rate = if wingSeen > 0.3 then 8 * wingSeen else 0
		if t >= Reveal.RISE + 0.5 then once("dissolve", function() wingDust:Emit(50) end) end

		-- the crown halo over her head
		local crownA = Reveal.smooth((t - Reveal.BURST) / 0.25) * (1 - Reveal.smooth((t - Reveal.RISE - 0.8) / 0.9))
		setRing(crown, feet + up * (2 * mid + 1.1 * k), side, dir, Reveal.CROWN_RADIUS * k, 0.3 * k, if h then crownA else 0, t * 0.6)

		-- settling on the ground
		if t >= Reveal.TOUCH then once("touch", function() footBurst.glints:Emit(8) end) end
		ringAt(rings.settle, Reveal.TOUCH, 0.8, t, floorAt + up * 0.14, side, dir, 2 * k, 14 * k, 0.4 * k)

		-- the ascension: a small burst behind her head; at the end she twinkles over the map
		if t >= Reveal.SWELL then
			once("swell", function() heartBurst.sparks:Emit(30); heartBurst.glints:Emit(10) end)
		end
		local behindHead = herMid + up * mid * 0.6 - (camPos - herMid).Unit * 3 * k
		setFlare(flares[3], behindHead, 1.1 * k, Reveal.pop(t, Reveal.SWELL, 0.05, 0.6), camR, camU)
		setFlare(flares[5], herMid + up * mid * 0.4 + (camPos - herMid).Unit * 2 * k, 1.3 * k, Reveal.pop(t, Reveal.TWINKLE, 0.15, 0.6), camR, camU)

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

		-- the world's colour: a cool hard night, with the swells
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
