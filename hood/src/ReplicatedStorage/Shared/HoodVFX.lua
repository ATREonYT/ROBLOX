-- Hood VFX: layered, tiered effects built from ParticleEmitters, Beams and lights. Works from map builders
-- (edit time, server) and from client scripts alike; it never yields and only sets real engine properties.
--
--   HoodVFX.station(part, tier, color, size?, opts?)  aura on a training platform; returns the Aura model
--   HoodVFX.item(part, tier, color, opts?)            glow / sparkles / fire on a displayed item; returns emitters
--   HoodVFX.theme(part, name, size?, opts?)           themed effects on a range lane's target field (lava
--                                                     flames and burning barrels, rain, snow, toxic wisps...);
--                                                     returns the Theme model
--   HoodVFX.setEnabled(container, on)                 switch every effect under `container` (distance LOD)
--   HoodVFX.setDensity(container, k)                  scale every emitter's Rate (e.g. 0.5 on low graphics)
--   HoodVFX.Textures                                  name -> uploaded rbxassetid ('' = use a Roblox built-in)
--   HoodVFX.applyTexture(emitter, name, opts?)        give any emitter (or Beam) a HoodVFX texture the house
--                                                     way: uploaded sheet + flipbook, or the tuned built-in
--                                                     fallback; returns true when the real sheet is in use
--   HoodVFX.fallbackOk(name)                          false when `name` has no usable stand-in before upload
--   HoodVFX.TierColors                                the 9-step glow colour ladder (green .. gold, rainbow)
--
-- How an aura is layered (skill: .claude/skills/roblox-vfx/SKILL.md). Each tier keeps every layer below it,
-- makes it a little bigger and brighter, and adds one new channel:
--   1 floor glow + faint dust       4 + sparks, glints, ground ring   7 + god rays (beams + ray shafts)
--   2 + billowing mist, core glow,  5 + floor vortex, electric arcs   8 + gold glitter
--     a point light                 6 + flames round the edges       9 + rainbow colours, more of everything
--   3 + curly wisps
-- Particle budget (live particles ~ Rate x Lifetime, measured on the 10.4 x 8.8 station deck; rates scale
-- with the deck area):  T1 ~12  T2 ~26  T3 ~35  T4 ~47  T5 ~55  T6 ~77  T7 ~89  T8 ~106  T9 ~120.
-- Fill rate, not count, is what costs on phones: the big soft layers (mist ~15, spill ~7, core and floor glow
-- 2 each, rays ~5) are the expensive ones, so they grow in size with the tier more than in number. The three
-- spawn stations (T1-T3) come to ~75 live particles; the route has one station per two stages, so a T6-T8
-- aura is on screen alone. Clients can thin or cull auras with setDensity / setEnabled.
--
-- Textures: hood/art/vfx/*.png (make_aura_textures.js; the themes' rain, ember, bubble, snow, comet,
-- firepuff, streakup and the stations' stamp come from make_theme_textures.js). Until they are uploaded and pasted into Textures, every layer falls back to a
-- texture that ships with Roblox and flipbook layouts stay off (a built-in is one image).
-- Emitters carry a PreviewTexture attribute so the offline renderer can show the intended look.
local HoodVFX = {}

local V, C = Vector3.new, Color3.fromRGB
local NR = NumberRange.new

HoodVFX.Textures = {
	aura = '', -- 2x2 billowy cloud puffs (static random frame)
	wisp = '', -- 4x4 curly smoke tendril (OneShot)
	flame = '', -- 4x4 cartoon flame (Loop)
	arc = '', -- 2x2 electric bolts (static random frame)
	mist = '', ray = '', shaft = '', glitter = '', swirl = '', dust = '', softglow = '', ring = '', spark = '',
	-- Station themes (make_theme_textures.js).
	rain = '', -- thin vertical streak (VelocityParallel)
	ember = '', -- hot point with a halo
	bubble = '', -- rim + highlight bubble
	snow = '', -- six-armed snowflake
	comet = '', -- head + fading tail along U (Beam)
	firepuff = '', -- 4x4 round cartoon fire puff (Loop)
	streakup = '', -- straight tapered vertical wisp
	-- Guidance (Lobby.client's floor guide to the free lane): a chevron pointing along +U (Beam, Wrap).
	chevron = '',
	-- Not an effect: the bag stations' stamped X block texture (d2_stations reads it; '' draws nothing).
	stamp = '',
}
-- Textures that ship with the Roblox client (research_notes/Tiered props VFX and vibrant maps/vfx_handbook.md §5).
local BUILTIN = {
	aura = 'rbxasset://textures/particles/smoke_main.dds', mist = 'rbxasset://textures/particles/smoke_main.dds',
	wisp = 'rbxasset://textures/particles/smoke_main.dds', flame = 'rbxasset://textures/particles/fire_main.dds',
	arc = 'rbxasset://textures/particles/sparkles_main.dds', glitter = 'rbxasset://textures/particles/sparkles_main.dds',
	spark = 'rbxasset://textures/particles/sparkles_main.dds', ray = 'rbxasset://textures/glow.png', shaft = 'rbxasset://textures/glow.png',
	dust = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png',
	swirl = 'rbxasset://textures/particles/explosion01_shockwave_main.dds', ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
	rain = 'rbxasset://textures/glow.png', ember = 'rbxasset://textures/glow.png', snow = 'rbxasset://textures/particles/sparkles_main.dds',
	bubble = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
	comet = 'rbxasset://textures/glow.png', firepuff = 'rbxasset://textures/particles/fire_main.dds',
	streakup = 'rbxasset://textures/particles/smoke_main.dds',
	chevron = 'rbxasset://textures/glow.png', -- (before upload: a trail of soft glowing dashes)
}
-- Flipbook settings, applied only when the uploaded sheet is in use.
local FLIPBOOK = {
	aura = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(0), FlipbookStartRandom = true },
	arc = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(0), FlipbookStartRandom = true },
	wisp = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot },
	flame = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(16, 22), FlipbookStartRandom = true },
	firepuff = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(14, 20), FlipbookStartRandom = true },
}

-- How a texture behaves before it is uploaded. A number keeps that share of the opacity (the built-in is only
-- a soft stand-in: it supports instead of smothering); false means there is no usable stand-in, so the emitter
-- starts switched off (attribute NeedsUpload) until the sheet is uploaded. Unlisted names: the built-in reads
-- well enough on its own. Other builders can add their own names here.
HoodVFX.Fallback = { wisp = 0.45, arc = 0.6, streakup = 0.5 }
local FALLBACK_FADE = HoodVFX.Fallback
-- Extra settings for a built-in stand-in: a soft glow squashed into a streak reads as rain.
local FALLBACK_PROPS = {
	rain = { Squash = NumberSequence.new(3), Size = NumberSequence.new(0.7) },
	-- Smoke squashed tall and thin reads as a rising wisp, not a cloud.
	streakup = { Squash = NumberSequence.new(2.6), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.0), NumberSequenceKeypoint.new(1, 2.4) }) },
}

-- Glow colours for tiers 1-9: green, cyan, blue, purple, pink, red, white (on black), gold, white (rainbow).
HoodVFX.TierColors = {
	C(90, 235, 110), C(70, 225, 255), C(80, 140, 255), C(180, 100, 255), C(255, 105, 205),
	C(255, 64, 64), C(235, 240, 255), C(255, 200, 60), C(255, 255, 255),
}
local RAINBOW = { C(255, 80, 80), C(255, 190, 60), C(120, 255, 110), C(70, 210, 255), C(170, 110, 255), C(255, 90, 200) }
local WHITE = C(255, 255, 255)

---------------------------------------------------------------------------------------------- helpers
local function texture(name)
	local id = HoodVFX.Textures[name]
	if id and id ~= '' then return id, true end
	return BUILTIN[name] or BUILTIN.softglow, false
end
-- NumberSequence from { {time, value, envelope?}, ... } (times 0..1, first 0, last 1).
local function seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
local function cseq(points)
	local k = {}
	for _, p in points do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(k)
end
local function rainbow(offset)
	local k = {}
	for i = 0, 5 do table.insert(k, { i / 5, RAINBOW[(i + offset) % #RAINBOW + 1] }) end
	return cseq(k)
end
local function lighten(c, t) return c:Lerp(WHITE, t) end
local function darken(c, t) return c:Lerp(C(0, 0, 0), t) end

-- True when `name`'s real sheet is uploaded, or its built-in stand-in is usable on its own.
function HoodVFX.fallbackOk(name)
	return select(2, texture(name)) or FALLBACK_FADE[name] ~= false
end

-- Give an emitter (or a Beam) a HoodVFX texture the house way, after its other properties are set: the
-- uploaded sheet with its flipbook layout, or else the built-in stand-in with its tuned extras (a squash, a
-- fade, or switched off when there is no stand-in). Always tags PreviewTexture for the offline renderer.
-- opts.fade: opacity share kept on the fallback (overrides HoodVFX.Fallback[name]; false = switch it off);
-- opts.fallbackProps: extra properties for the fallback only. Returns true when the real sheet is in use.
function HoodVFX.applyTexture(e, name, opts)
	opts = opts or {}
	local id, uploaded = texture(name)
	e.Texture = id
	e:SetAttribute('PreviewTexture', name)
	if not e:IsA('ParticleEmitter') then return uploaded end
	if uploaded then
		for k, v in FLIPBOOK[name] or {} do (e :: any)[k] = v end
		return true
	end
	for k, v in FALLBACK_PROPS[name] or {} do (e :: any)[k] = v end
	for k, v in opts.fallbackProps or {} do (e :: any)[k] = v end
	local fade = opts.fade
	if fade == nil then fade = FALLBACK_FADE[name] end
	if fade == false then
		e.Enabled = false
		e:SetAttribute('NeedsUpload', true)
	elseif type(fade) == 'number' then
		local k = {}
		for _, kp in e.Transparency.Keypoints do table.insert(k, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * fade, kp.Envelope * fade)) end
		e.Transparency = NumberSequence.new(k)
	end
	return false
end

-- A ParticleEmitter with everything the engine needs spelled out: LightInfluence 0 (glows stay bright at
-- night; Instance.new gives 0 but Studio insertion gives 1, so never rely on the default), then the texture
-- through applyTexture (flipbook only with the real sheet, the tuned built-in otherwise).
local function emitter(parent, name, tex, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Rotation = NR(0, 360)
	for k, v in props do (e :: any)[k] = v end
	HoodVFX.applyTexture(e, tex)
	e.Parent = parent
	return e
end
-- Invisible anchored part that particles spawn in (emitters on a part fill its box).
local function holder(parent, name, cf, size)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end
local function attach(parent, name, pos)
	local a = Instance.new('Attachment')
	a.Name = name
	a.CFrame = CFrame.new(pos) -- (CFrame rather than Position: offline tools only read CFrame)
	a.Parent = parent
	return a
end

---------------------------------------------------------------------------------------------- station aura
-- `part`: the surface the aura stands on (the platform deck); the aura is centred on its top face and uses
-- its axes. `tier`: 1..9. `color`: the glow colour (white for a black station). `size`: Vector3 (width, aura
-- height, depth) or nil for (part width, 12, part depth). opts.parent: where the Aura model goes (default the
-- part's parent); opts.smoke: cloud colour if not `color`. Returns the Aura model; every holder part in it is
-- invisible and non-colliding.
function HoodVFX.station(part, tier, color, size, opts)
	opts = opts or {}
	local T = math.clamp(math.floor(tier or 1), 1, 9)
	local k = (T - 1) / 8 -- 0 at tier 1, 1 at tier 9
	color = color or HoodVFX.TierColors[T]
	if typeof(size) == 'number' then size = V(size, 12, size) end
	size = size or V(part.Size.X, 12, part.Size.Z)
	local w, h, d = size.X, size.Y, size.Z
	local S = math.max(w, d) / 12 -- layer sizes are tuned on a 12-stud platform
	local A = (w * d) / 100 -- emission rates scale with the deck area (tuned on ~10x10)
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	local light, deep, pale = lighten(color, 0.35), darken(color, 0.35), lighten(color, 0.7)
	local smoke = opts.smoke or color -- the clouds' colour (a black-and-white station wants grey smoke)
	local champ = T >= 9
	-- Additive layers in a pale colour stack up to a white blob fast, so pale glows (white, gold, cyan) get
	-- dimmed: o(t) keeps (1 - t) * hot of the opacity.
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	local hot = 1 - math.max(0, lum - 0.55)
	local function o(t) return 1 - (1 - t) * hot end

	local aura = Instance.new('Model')
	aura.Name = 'Aura'
	aura:SetAttribute('Tier', T)
	aura.Parent = opts.parent or part.Parent or part
	-- Spawn volumes: a thin deck slab (mist, wisps, dust rise off it) and the column above it (glints, arcs).
	local deck = holder(aura, 'AuraDeck', top * CFrame.new(0, 0.15, 0), V(w * 0.86, 0.3, d * 0.86))
	local column = holder(aura, 'AuraColumn', top * CFrame.new(0, h * 0.38, 0), V(w * 0.7, h * 0.6, d * 0.7))
	local floor = attach(deck, 'Floor', V(0, 0.05, 0))
	local core = attach(deck, 'Core', V(0, h * 0.3, 0))

	-- 1. Floor glow: a soft pool of light lying on the deck (VelocityPerpendicular + tiny upward speed = flat).
	emitter(floor, 'FloorGlow', 'softglow', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.8, Lifetime = NR(2.5),
		Size = seq({ { 0, w * 0.95 }, { 1, w * 1.05 } }), Rotation = NR(0),
		Transparency = seq({ { 0, 1 }, { 0.3, o(0.62 - 0.3 * k) }, { 0.7, o(0.62 - 0.3 * k) }, { 1, 1 } }),
		Color = champ and rainbow(0) or cseq({ { 0, light }, { 1, color } }), LightEmission = 1, Brightness = 1 + k,
	})
	-- 1. Dust motes drifting up.
	emitter(deck, 'Dust', 'dust', {
		Rate = (4 + 6 * k) * A, Lifetime = NR(2, 3.4), Speed = NR(0.6, 1.6), SpreadAngle = Vector2.new(25, 25),
		Acceleration = V(0, 0.6, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.15, 0.3 * S, 0.08 * S }, { 0.8, 0.22 * S, 0.06 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.25 }, { 0.75, 0.35 }, { 1, 1 } }),
		Color = champ and rainbow(2) or cseq({ { 0, pale }, { 1, color } }), LightEmission = 0.8,
	})
	if T >= 2 then
		-- 2. Billowing mist: big cloud puffs rolling up and over the edges. Nearly normal blending: additive
		-- clouds wash out to white against a daytime floor and sky, solid colour keeps the tier readable.
		-- ZOffset -1.5 sorts the clouds behind the bag where they overlap, so the bag reads (more than that and
		-- the deck starts to hide the low puffs).
		emitter(deck, 'Mist', 'aura', {
			Rate = (2 + 3 * k) * A, Lifetime = NR(3, 4), Speed = NR(0.8, 1.8 + 0.8 * k), SpreadAngle = Vector2.new(60 + 20 * k, 60 + 20 * k),
			Drag = 0.5, Acceleration = V(0, 0.3 + 0.5 * k, 0), RotSpeed = NR(-18, 18), ZOffset = -1.5,
			Size = seq({ { 0, 3 * S, 0.5 * S }, { 0.4, (5 + 2.5 * k) * S, 0.8 * S }, { 1, (7 + 4 * k) * S, S } }),
			Transparency = seq({ { 0, 1 }, { 0.2, 0.45 - 0.2 * k, 0.08 }, { 0.6, 0.55 - 0.2 * k, 0.08 }, { 1, 1 } }),
			Color = champ and rainbow(1) or cseq({ { 0, lighten(smoke, 0.25) }, { 0.45, smoke }, { 1, darken(smoke, 0.12) } }), LightEmission = 0.05,
		})
		-- 2. Spill: wide soft fog rolling sideways off the deck and sinking over the edges.
		emitter(deck, 'Spill', 'mist', {
			Rate = (0.8 + 2 * k) * A, Lifetime = NR(2.5, 3.5), Speed = NR(2.5, 4 + k), SpreadAngle = Vector2.new(85, 85),
			Drag = 0.8, Acceleration = V(0, -0.4, 0), RotSpeed = NR(-10, 10), ZOffset = -1,
			Size = seq({ { 0, 3 * S, 0.5 * S }, { 1, (6 + 4 * k) * S, S } }),
			Transparency = seq({ { 0, 1 }, { 0.25, 0.55 - 0.2 * k }, { 1, 1 } }),
			Color = champ and rainbow(2) or cseq({ { 0, lighten(smoke, 0.2) }, { 1, darken(smoke, 0.1) } }), LightEmission = 0,
		})
		-- 2. Core glow: a big additive halo at the heart of the aura, pushed behind the bag with ZOffset.
		emitter(core, 'CoreGlow', 'softglow', {
			Rate = 0.8, Lifetime = NR(2.5), Speed = NR(0), Rotation = NR(0),
			Size = seq({ { 0, (7 + 4 * k) * S }, { 1, (8 + 5 * k) * S } }),
			Transparency = seq({ { 0, 1 }, { 0.4, o(0.86 - 0.25 * k) }, { 0.6, o(0.86 - 0.25 * k) }, { 1, 1 } }),
			Color = champ and rainbow(3) or cseq({ { 0, color }, { 1, color } }), LightEmission = 1, ZOffset = -2,
		})
		local l = Instance.new('PointLight')
		l.Name = 'AuraLight'
		l.Color, l.Brightness, l.Range, l.Shadows = color, 0.6 + 1.6 * k, 8 + 8 * k, false
		l.Parent = column -- lights on parts preview offline; on an attachment works too
	end
	if T >= 3 then
		-- 3. Curly wisps: the inked smoke curls (OneShot flipbook: each grows, curls and breaks up once).
		local wisp = {
			Rate = (1.6 + 4 * k) * A, Lifetime = NR(1.6, 2.4), Speed = NR(2.5, 4.5), SpreadAngle = Vector2.new(22, 22),
			Drag = 0.8, Acceleration = V(0, 1.2, 0), Rotation = NR(-40, 40), RotSpeed = NR(-30, 30),
			Size = seq({ { 0, 2.8 * S, 0.5 * S }, { 1, (4.2 + 1.2 * k) * S, 0.7 * S } }),
			Transparency = seq({ { 0, 0.4 }, { 0.15, 0 }, { 0.8, 0.15 }, { 1, 1 } }),
			Color = champ and rainbow(4) or cseq({ { 0, WHITE }, { 1, light } }), LightEmission = 0.6, Brightness = 1.3 + k,
		}
		emitter(deck, 'Wisps', 'wisp', wisp)
		if T >= 6 and select(2, texture('wisp')) then
			-- From tier 6 the curls fill the whole column, not just the deck (the reference's top pads). Only
			-- with the real wisp sheet: built-in puffs up there would hide the sign.
			wisp.Rate, wisp.Speed, wisp.Rotation = (1 + 2 * k) * A, NR(0.8, 2), NR(0, 360)
			emitter(column, 'WispsHigh', 'wisp', wisp)
		end
	end
	if T >= 4 then
		-- 4. Glints popping in the column and sparks shooting up off the deck.
		emitter(column, 'Glints', 'glitter', {
			Rate = (3 + 5 * k) * A, Lifetime = NR(0.45, 0.8), Speed = NR(0.2, 0.8), Rotation = NR(0, 90), RotSpeed = NR(-60, 60),
			Size = seq({ { 0, 0 }, { 0.3, 0.75 * S, 0.25 * S }, { 1, 0 } }),
			Color = cseq({ { 0, WHITE }, { 1, champ and C(255, 220, 120) or light } }), LightEmission = 1, Brightness = 1.5 + k, ZOffset = 1,
		})
		emitter(deck, 'Sparks', 'dust', {
			Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = (3 + 5 * k) * A, Lifetime = NR(0.6, 1.1),
			Speed = NR(6, 11), SpreadAngle = Vector2.new(18, 18), Drag = 1.2, Acceleration = V(0, -2, 0),
			Size = seq({ { 0, 0.3 * S }, { 1, 0 } }), Squash = seq({ { 0, 1.5 }, { 1, 1 } }),
			Color = cseq({ { 0, WHITE }, { 1, champ and C(255, 220, 120) or light } }), LightEmission = 1, Brightness = 1.5 + k,
		})
		-- 4. Ground ring: a shockwave rippling out across the deck every couple of seconds.
		emitter(floor, 'GroundRing', 'ring', {
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.45 + 0.3 * k, Lifetime = NR(1.4, 1.8),
			Rotation = NR(0), Size = seq({ { 0, 2 * S }, { 1, 0.95 * math.min(w, d) } }),
			Transparency = seq({ { 0, 0.25 }, { 0.6, 0.55 }, { 1, 1 } }),
			Color = champ and rainbow(5) or cseq({ { 0, light }, { 1, color } }), LightEmission = 1, Brightness = 1.2 + k,
		})
	end
	if T >= 5 then
		-- 5. A vortex spinning flat on the deck, and electric arcs crackling round the column.
		emitter(floor, 'Vortex', 'swirl', {
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.45, Lifetime = NR(3, 3.4),
			RotSpeed = NR(100, 150), Size = seq({ { 0, 0.62 * w }, { 1, 0.8 * w } }),
			Transparency = seq({ { 0, 1 }, { 0.25, 0.5 - 0.2 * k }, { 0.75, 0.5 - 0.2 * k }, { 1, 1 } }),
			Color = champ and rainbow(0) or cseq({ { 0, light }, { 1, color } }), LightEmission = 1,
		})
		emitter(column, 'Arcs', 'arc', {
			Rate = (5 + 6 * k) * A, Lifetime = NR(0.12, 0.22), Speed = NR(0),
			Size = seq({ { 0, 2.6 * S, 0.6 * S }, { 1, 3.2 * S, 0.6 * S } }),
			Transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
			Color = cseq({ { 0, WHITE }, { 1, champ and C(170, 230, 255) or pale } }), LightEmission = 1, Brightness = 2 + k, ZOffset = 0.5,
		})
	end
	if T >= 6 then
		-- 6. Flames licking up round the deck edges (FacingCameraWorldUp keeps them upright from above).
		local edges = { { V(0, 0, -d / 2 + 0.4), V(w * 0.9, 0.3, 0.6), 0.6 }, { V(0, 0, d / 2 - 0.4), V(w * 0.9, 0.3, 0.6), 1 },
			{ V(-w / 2 + 0.4, 0, 0), V(0.6, 0.3, d * 0.9), 1 }, { V(w / 2 - 0.4, 0, 0), V(0.6, 0.3, d * 0.9), 1 } }
		-- A warm white birth makes any tint read as fire; the tier colour takes over as the flame rises.
		local birth = lum > 0.85 and WHITE or color:Lerp(C(255, 226, 120), 0.55) -- white glows burn white
		local fire = champ and rainbow(2) or cseq({ { 0, birth }, { 0.18, color:Lerp(birth, 0.4) }, { 0.45, color }, { 1, deep } })
		for i, e in edges do
			local edge = holder(aura, 'FlameEdge', top * CFrame.new(e[1] + V(0, 0.2, 0)), e[2])
			emitter(edge, 'Flames' .. i, 'flame', {
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = (3 + 3 * k) * e[3] * math.max(e[2].X, e[2].Z) / 10,
				Lifetime = NR(0.6, 1), Speed = NR(2, 3.5), SpreadAngle = Vector2.new(8, 8), Acceleration = V(0, 3, 0), Drag = 0.5, ZOffset = 0.5,
				Rotation = NR(-8, 8), Size = seq({ { 0, 2 * S }, { 0.3, 3.6 * S, 0.5 * S }, { 1, 2.2 * S } }),
				Transparency = seq({ { 0, 0.6 }, { 0.15, 0.05 }, { 0.7, 0.25 }, { 1, 1 } }),
				Color = fire, LightEmission = 0.7,
			})
		end
	end
	if T >= 7 then
		-- 7. God rays: faint shafts fading in and out on the deck, plus three steady beams rising through it.
		emitter(deck, 'Rays', 'ray', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = (1 + 1.5 * k) * A, Lifetime = NR(2, 3), Speed = NR(0.05),
			Rotation = NR(0), Size = seq({ { 0, h * 0.75, h * 0.1 }, { 1, h * 0.85, h * 0.1 } }),
			Transparency = seq({ { 0, 1 }, { 0.35, o(0.62 - 0.15 * k) }, { 0.65, o(0.62 - 0.15 * k) }, { 1, 1 } }),
			Color = champ and rainbow(1) or cseq({ { 0, light }, { 1, color } }), LightEmission = 0.8, Brightness = 1.3,
		})
		-- Beams stand at the sides and the back of the deck, leaning out, so they frame whatever is in the
		-- middle (the bag) instead of washing over it.
		for i, at in { V(-0.36, 0, -0.1), V(0.36, 0, -0.1), V(0, 0, 0.42) } do
			local a0 = attach(deck, 'RayBase' .. i, V(at.X * w, 0.1, at.Z * d))
			local a1 = attach(deck, 'RayTop' .. i, V(at.X * w * 1.6, h * 1.25, at.Z * d * 1.3))
			local b = Instance.new('Beam')
			b.Name = 'GodRay' .. i
			b.Attachment0, b.Attachment1 = a0, a1
			HoodVFX.applyTexture(b, 'shaft')
			b.TextureMode, b.TextureLength, b.TextureSpeed = Enum.TextureMode.Stretch, 1, 0.15 + 0.1 * i
			b.Width0, b.Width1 = (1.6 + 0.6 * k) * S, (3.4 + k) * S
			b.FaceCamera, b.Segments = true, 1
			b.LightEmission, b.LightInfluence, b.Brightness = 0.7, 0, 1.5 + k
			b.Color = champ and rainbow(i) or ColorSequence.new(light, color)
			b.Transparency = seq({ { 0, o(0.5 - 0.1 * k) }, { 0.5, o(0.72) }, { 1, 1 } })
			b.ZOffset = -1
			b.Parent = deck
		end
	end
	if T >= 8 then
		-- 8. Gold glitter drifting up through everything.
		emitter(column, 'Glitter', 'glitter', {
			Rate = (12 + 8 * (T - 8)) * A, Lifetime = NR(0.6, 1.1), Speed = NR(0.5, 2), Rotation = NR(0, 45), RotSpeed = NR(-90, 90),
			Size = seq({ { 0, 0 }, { 0.4, 0.62 * S, 0.22 * S }, { 1, 0 } }),
			Color = champ and rainbow(3) or cseq({ { 0, WHITE }, { 0.5, C(255, 226, 120) }, { 1, C(255, 180, 40) } }),
			LightEmission = 1, Brightness = 2.5, ZOffset = 1.5,
		})
	end
	return aura
end

---------------------------------------------------------------------------------------------- item glow
-- Effects for a displayed item (a gun on a pedestal). `part` is the item's main part or an invisible box
-- around it: glints and motes fill its box, the glow and fire sit on attachments, nothing new is anchored, so
-- it also works on items that move. `tier` 1..10. Returns the list of emitters (and the light, if any).
-- Live particles: T1 ~2, T3 ~6, T5 ~12, T7 ~20, T10 ~30.
function HoodVFX.item(part, tier, color, opts)
	opts = opts or {}
	local T = math.clamp(math.floor(tier or 1), 1, 10)
	local k = (T - 1) / 9
	color = color or HoodVFX.TierColors[math.min(T, 9)]
	local r = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	local light, pale = lighten(color, 0.35), lighten(color, 0.7)
	local champ = T >= 9
	local hot = 1 - math.max(0, 0.299 * color.R + 0.587 * color.G + 0.114 * color.B - 0.55) -- dim pale halos
	local made = {}
	local centre = attach(part, 'ItemFX', V())
	local base = attach(part, 'ItemFXBase', V(0, -part.Size.Y / 2, 0))
	local function add(e) table.insert(made, e) return e end
	-- Soft halo behind the item.
	add(emitter(centre, 'ItemGlow', 'softglow', {
		Rate = 1, Lifetime = NR(2), Speed = NR(0), Rotation = NR(0), ZOffset = -1,
		Size = seq({ { 0, r * (1.3 + 0.9 * k) }, { 1, r * (1.5 + 1 * k) } }),
		Transparency = seq({ { 0, 1 }, { 0.4, 1 - (0.18 + 0.32 * k) * hot }, { 0.6, 1 - (0.18 + 0.32 * k) * hot }, { 1, 1 } }),
		Color = champ and rainbow(0) or ColorSequence.new(color), LightEmission = 1,
	}))
	if T >= 2 then
		add(emitter(part, 'ItemGlints', 'glitter', {
			Rate = 0.8 + 2.4 * k, Lifetime = NR(0.4, 0.7), Speed = NR(0), Rotation = NR(0, 90), RotSpeed = NR(-60, 60), ZOffset = 1,
			Size = seq({ { 0, 0 }, { 0.35, r * 0.45, r * 0.12 }, { 1, 0 } }),
			Color = cseq({ { 0, WHITE }, { 1, light } }), LightEmission = 1, Brightness = 1.5 + k,
		}))
	end
	if T >= 3 then
		add(emitter(part, 'ItemMotes', 'dust', {
			Rate = 2 + 4 * k, Lifetime = NR(1.2, 2), Speed = NR(0.5, 1.2), SpreadAngle = Vector2.new(30, 30), Acceleration = V(0, 0.8, 0),
			Size = seq({ { 0, 0 }, { 0.2, 0.16 * r, 0.05 * r }, { 1, 0 } }),
			Transparency = seq({ { 0, 1 }, { 0.2, 0.2 }, { 1, 1 } }),
			Color = champ and rainbow(2) or cseq({ { 0, pale }, { 1, color } }), LightEmission = 0.9,
		}))
	end
	if T >= 4 then
		local l = Instance.new('PointLight')
		l.Name = 'ItemLight'
		l.Color, l.Brightness, l.Range, l.Shadows = color, 0.5 + k, 4 + 4 * k, false
		l.Parent = centre
		table.insert(made, l)
	end
	if T >= 5 then
		add(emitter(base, 'ItemWisps', 'wisp', {
			Rate = 1.2 + 1.5 * k, Lifetime = NR(1.2, 1.8), Speed = NR(1.2, 2.2), SpreadAngle = Vector2.new(25, 25), Rotation = NR(-35, 35),
			RotSpeed = NR(-30, 30), Size = seq({ { 0, r * 0.7 }, { 1, r * 1.1 } }),
			Transparency = seq({ { 0, 0.5 }, { 0.15, 0.1 }, { 1, 1 } }),
			Color = champ and rainbow(4) or cseq({ { 0, WHITE }, { 1, pale } }), LightEmission = 0.85,
		}))
	end
	if T >= 6 then
		add(emitter(part, 'ItemFlames', 'flame', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 4 + 4 * k, Lifetime = NR(0.5, 0.8), ZOffset = 0.4,
			Speed = NR(1.5, 2.5), SpreadAngle = Vector2.new(20, 20), Acceleration = V(0, 2, 0), Rotation = NR(-8, 8),
			Size = seq({ { 0, r * 0.55 }, { 0.3, r * 0.95, r * 0.15 }, { 1, r * 0.5 } }),
			Transparency = seq({ { 0, 0.6 }, { 0.15, 0.1 }, { 1, 1 } }),
			Color = champ and rainbow(1) or cseq({ { 0, color:Lerp(C(255, 226, 120), 0.55) }, { 0.45, color }, { 1, darken(color, 0.4) } }),
			LightEmission = 0.7,
		}))
	end
	if T >= 7 then
		add(emitter(part, 'ItemArcs', 'arc', {
			Rate = 3 + 4 * k, Lifetime = NR(0.1, 0.18), Speed = NR(0), Size = seq({ { 0, r * 0.8, r * 0.2 }, { 1, r, r * 0.2 } }),
			Color = cseq({ { 0, WHITE }, { 1, pale } }), LightEmission = 1, Brightness = 2, ZOffset = 0.5,
		}))
	end
	if T >= 8 then
		add(emitter(base, 'ItemRays', 'ray', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1, Lifetime = NR(1.8, 2.6), Speed = NR(0.05), Rotation = NR(0),
			Size = seq({ { 0, r * 2.6 }, { 1, r * 3 } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.45 }, { 0.6, 0.45 }, { 1, 1 } }),
			Color = champ and rainbow(3) or cseq({ { 0, pale }, { 1, light } }), LightEmission = 1, ZOffset = -0.5,
		}))
		add(emitter(part, 'ItemGlitter', 'glitter', {
			Rate = 6 + 4 * k, Lifetime = NR(0.5, 0.9), Speed = NR(0.4, 1.4), Rotation = NR(0, 45), RotSpeed = NR(-90, 90),
			Size = seq({ { 0, 0 }, { 0.4, r * 0.18, r * 0.06 }, { 1, 0 } }),
			Color = champ and rainbow(5) or cseq({ { 0, WHITE }, { 1, C(255, 210, 90) } }), LightEmission = 1, Brightness = 2.5, ZOffset = 1,
		}))
	end
	return made
end

---------------------------------------------------------------------------------------------- station themes
-- Effects that belong to a range lane, one theme per tier (the shooting ranges, d2_stations; the bag stations
-- before them): `part` is the lane's target field (from the bench to the backstop):
-- effects stand on its top face and use its axes, `name` one of the keys of
-- HoodVFX.Themes, `size` Vector3 (width, effect height, depth) or nil for (part width, 12, part depth).
-- opts.parent (default: the part's parent), opts.color (the theme's glow colour), opts.tier, opts.bag (the
-- main target or bag: lava lights it from below, and licks up a bag's sides when there are no burners),
-- opts.burners (parts on top of burning barrels: lava sets them on fire). Returns the Theme model; every holder
-- part in it is invisible.
-- The mats are flat saturated colours, so nothing additive lies on them (no floor pools, decals or light
-- shafts): the material's own particles carry each theme, as in the reference. Live particles (Rate x
-- Lifetime, measured on the old 7 x 18 mat; the lanes' 7 x 10 field runs at ~0.57 of these):  stone ~12  red ~39  lava ~98  arcane ~35 (+3 comet beams)  frost ~58
-- toxic ~51  shadow ~42  gold ~38 (25 big glints). All eight together ~456: thin them on phones with setDensity
-- (the lobby client already halves locked stations).
-- Brief 8 volume: every theme a notch quieter than the signed-off set (rates ~20% lower, glints and motes less
-- bright, lights ~25% dimmer), the same escalation from stone to gold.
HoodVFX.Themes = {}
local THEME_COLOR = {
	stone = C(255, 244, 220), red = C(250, 45, 85), lava = C(255, 150, 40), arcane = C(230, 120, 255),
	frost = C(150, 236, 255), toxic = C(120, 255, 80), shadow = C(176, 120, 255), gold = C(255, 222, 80),
}

local function pointLight(at, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Name = 'ThemeLight'
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = at
	return l
end

-- 1 Stone: the humble start. A little chalk dust drifting off the mat.
function HoodVFX.Themes.stone(ctx)
	local A, S, color = ctx.A, ctx.S, ctx.color
	emitter(ctx.deck, 'Dust', 'dust', {
		Rate = 3.5 * A, Lifetime = NR(2, 3.4), Speed = NR(0.3, 1), SpreadAngle = Vector2.new(30, 30), Acceleration = V(0, 0.4, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.15, 0.28 * S, 0.08 * S }, { 0.8, 0.2 * S, 0.06 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.35 }, { 0.75, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 0.3,
	})
end

-- 2 Red: dense red rain dashing down over the back half of its own mat (from 4 studs up, short streaks, in
-- the theme red so nothing looks like a white tracer), tiny splashes where it lands.
function HoodVFX.Themes.red(ctx)
	local A, S, w, d = ctx.A, ctx.S, ctx.w, ctx.d
	local sky = holder(ctx.theme, 'RainSky', ctx.top * CFrame.new(0, 4, d / 4), V(w * 0.96, 0.2, d * 0.48))
	emitter(sky, 'Rain', 'rain', {
		EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 32 * A, Lifetime = NR(0.2, 0.24), Speed = NR(16, 19), SpreadAngle = Vector2.new(3, 3),
		Size = seq({ { 0, 1.1 }, { 1, 1.3 } }), Transparency = seq({ { 0, 1 }, { 0.12, 0 }, { 0.85, 0.05 }, { 1, 1 } }),
		Color = cseq({ { 0, C(255, 120, 150) }, { 1, C(250, 45, 85) } }), LightEmission = 0,
	})
	local floor = holder(ctx.theme, 'RainFloor', ctx.top * CFrame.new(0, 0.15, d / 4), V(w * 0.9, 0.3, d * 0.45))
	emitter(floor, 'Splash', 'dust', {
		Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 12 * A, Lifetime = NR(0.2, 0.35),
		Speed = NR(3, 6), SpreadAngle = Vector2.new(55, 55), Acceleration = V(0, -30, 0), Drag = 1,
		Size = seq({ { 0, 0.22 * S }, { 1, 0 } }), Squash = seq({ { 0, 1.2 }, { 1, 0.5 } }),
		Color = cseq({ { 0, C(255, 200, 210) }, { 1, C(250, 45, 85) } }), LightEmission = 0.6,
	})
end

-- 3 Lava: the whole mat carpeted in soft glowing fire puffs (pale-yellow cores, orange to red-orange edges)
-- right to the rim, stray flame licks rising past the bag's bottom, small fires on the bag's flanks, embers,
-- and a warm light under the bag. Before upload the fire_main stand-in gets the same red-ended ramp, smaller,
-- so it reads as flame rather than gold leaves.
function HoodVFX.Themes.lava(ctx)
	local A, S, w, d = ctx.A, ctx.S, ctx.w, ctx.d
	-- Two layers of the same soft puff: a wide orange to red-orange body, and smaller pale-yellow cores drawn in
	-- front of it, so each flame reads yellow in the middle and red-orange at the edge.
	local fire = cseq({ { 0, C(255, 240, 0) }, { 0.35, C(255, 190, 30) }, { 0.75, C(245, 90, 20) }, { 1, C(200, 40, 10) } })
	local body = cseq({ { 0, C(250, 110, 10) }, { 0.5, C(235, 70, 15) }, { 1, C(190, 35, 10) } }) -- redder than the mat
	local core = cseq({ { 0, C(255, 240, 0) }, { 0.5, C(255, 210, 20) }, { 1, C(255, 160, 10) } })
	local lick = cseq({ { 0, C(255, 200, 60) }, { 1, C(245, 80, 20) } })
	local uploaded = select(2, texture('firepuff'))
	-- Two holders (front and back half) so the aisle end is as dense as the back. With burning barrels at the
	-- sides the carpet keeps clear of them (narrower), so their bases stay visible. Before upload the fire_main
	-- stand-in carpet is smaller and denser and the flame licks take over (flames, not flakes). Budget: ~52 live
	-- particles with uploads (carpet 16, cores 8, licks 7, two burners 16, embers 4), ~53 before (carpet 19).
	local bedW = ctx.burners and #ctx.burners > 0 and math.min(w, 4.3) or w
	for i, zc in { -d / 4, d / 4 } do
		local half = holder(ctx.theme, 'FireBed' .. i, ctx.top * CFrame.new(0, 0.1, zc), V(bedW, 0.2, d / 2))
		emitter(half, 'FireCarpet', 'firepuff', {
			Rate = (uploaded and 16 or 19) * A, Lifetime = NR(0.4, 0.7), Speed = NR(0.3, 1), SpreadAngle = Vector2.new(12, 12), Acceleration = V(0, 1.5, 0),
			RotSpeed = NR(-20, 20), ZOffset = 0.2, -- (the soft puff fills ~45% of its frame)
			Size = uploaded and seq({ { 0, 4.0 * S, 0.3 * S }, { 0.4, 5.4 * S, 0.4 * S }, { 1, 0 } }) or seq({ { 0, 1.5 * S, 0.15 * S }, { 0.4, 2.1 * S, 0.2 * S }, { 1, 0 } }),
			Transparency = seq({ { 0, 0.1 }, { 0.5, 0.25 }, { 1, 1 } }), Color = uploaded and body or fire, LightEmission = 0.35,
		})
		if uploaded then
			emitter(half, 'FireCores', 'firepuff', {
				Rate = 10 * A, Lifetime = NR(0.35, 0.6), Speed = NR(0.4, 1.2), SpreadAngle = Vector2.new(12, 12), Acceleration = V(0, 1.5, 0),
				RotSpeed = NR(-20, 20), ZOffset = 0.5, Size = seq({ { 0, 2.3 * S, 0.2 * S }, { 0.4, 3.1 * S, 0.3 * S }, { 1, 0 } }),
				Transparency = seq({ { 0, 0.1 }, { 0.5, 0.2 }, { 1, 1 } }), Color = core, LightEmission = 0.35,
			})
		end
		emitter(half, 'FlameLicks', 'flame', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = uploaded and 4 or 7, Lifetime = NR(0.5, 0.9), Speed = NR(3, 5),
			SpreadAngle = Vector2.new(10, 10), Rotation = NR(-8, 8), ZOffset = 0.3,
			Size = seq({ { 0, 0.6 * S }, { 0.4, 1.0 * S, 0.2 * S }, { 1, 0 } }), Transparency = seq({ { 0, 0.3 }, { 0.15, 0 }, { 1, 1 } }),
			Color = lick, LightEmission = 0.5,
		})
	end
	for _, b in ctx.burners or {} do
		-- A burning barrel: puffs and licks rising out of its open top (the part is the coals disc).
		local top = b.CFrame * CFrame.new(0, 0, 0)
		local fire1 = holder(ctx.theme, 'Burner', CFrame.new(top.Position + V(0, 0.15, 0)), V(0.9, 0.2, 0.9))
		emitter(fire1, 'BurnerFire', 'firepuff', {
			Rate = 7, Lifetime = NR(0.45, 0.8), Speed = NR(1.5, 3), SpreadAngle = Vector2.new(10, 10), Acceleration = V(0, 2, 0), ZOffset = 0.4,
			RotSpeed = NR(-25, 25), Size = uploaded and seq({ { 0, 1.6, 0.2 }, { 0.4, 2.2, 0.3 }, { 1, 0 } }) or seq({ { 0, 1.0 }, { 0.4, 1.4, 0.2 }, { 1, 0 } }),
			Transparency = seq({ { 0, 0.1 }, { 0.5, 0.2 }, { 1, 1 } }), Color = fire, LightEmission = 0.5,
		})
		emitter(fire1, 'BurnerLicks', 'flame', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 4, Lifetime = NR(0.5, 0.8), Speed = NR(3, 4.5),
			SpreadAngle = Vector2.new(8, 8), ZOffset = 0.5, Size = seq({ { 0, 0.7 }, { 0.4, 1.1, 0.2 }, { 1, 0 } }),
			Transparency = seq({ { 0, 0.3 }, { 0.15, 0 }, { 1, 1 } }), Color = lick, LightEmission = 0.6,
		})
		pointLight(fire1, C(255, 150, 50), 0.9, 9)
	end
	if ctx.bag and not ctx.burners then
		-- Two small fires on the bag's flanks (attachments on a belly slab, so they swing with it).
		for _, sx in { -1, 1 } do
			local a = attach(ctx.bag, 'BagFire', V(sx * ctx.bag.Size.Z / 2, -0.3, 0))
			emitter(a, 'BagFlames', 'firepuff', {
				Rate = 8, Lifetime = NR(0.4, 0.7), Speed = NR(1, 2), SpreadAngle = Vector2.new(15, 15), Acceleration = V(0, 2, 0), ZOffset = 0.4,
				RotSpeed = NR(-20, 20), Size = seq({ { 0, 1.2 }, { 0.4, 1.8, 0.3 }, { 1, 0 } }), Transparency = seq({ { 0, 0.1 }, { 0.5, 0.25 }, { 1, 1 } }),
				Color = fire, LightEmission = 0.35,
			})
		end
	end
	if ctx.bag then
		-- The bag lit orange from below: a light one stud over the mat under it (static, not on the swinging bag).
		local under = ctx.top:PointToObjectSpace(ctx.bag.CFrame.Position)
		pointLight(holder(ctx.theme, 'FireGlow', ctx.top * CFrame.new(under.X, 1, under.Z), V(0.2, 0.2, 0.2)), C(255, 140, 50), 0.9, 9)
	end
	emitter(ctx.deck, 'Embers', 'ember', {
		Rate = 3 * A, Lifetime = NR(1.4, 2.6), Speed = NR(2, 5), SpreadAngle = Vector2.new(25, 25), Acceleration = V(0.6, 1.5, 0.3), Drag = 0.6,
		RotSpeed = NR(-40, 40), Size = seq({ { 0, 0.3 * S, 0.1 * S }, { 0.7, 0.2 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Color = cseq({ { 0, C(255, 240, 160) }, { 0.4, C(255, 160, 40) }, { 1, C(255, 70, 20) } }), LightEmission = 1, Brightness = 1.5, ZOffset = 0.8,
	})
	pointLight(ctx.column, C(255, 140, 50), 0.75, 14)
end

-- 4 Arcane: pink-white comets sweeping in arcs over the gantry, with pink sparkles.
function HoodVFX.Themes.arcane(ctx)
	local A, S, color, w, d = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d
	-- Long arcs (head, tail, bend) over the back of the field: above the gantry beam and the wall's top (9.2-10.6
	-- studs over the field, against the lobby, never across the line of fire, under the label), pink heads fading
	-- to violet tails: bright against the sky and the lobby's blue walls, and up there no tracer is near.
	local arcs = {
		{ V(-0.42 * w, 9.3, 0.36 * d), V(0.42 * w, 10.2, 0.44 * d), 1.0 },
		{ V(0.4 * w, 10.6, 0.3 * d), V(-0.38 * w, 9.5, 0.46 * d), 0.8 },
		{ V(-0.2 * w, 10.0, 0.42 * d), V(0.3 * w, 9.2, 0.34 * d), 0.7 },
	}
	for i, arc in arcs do
		local up = CFrame.Angles(0, 0, math.pi / 2) -- attachment X axis points up: the beam bows upward
		local a0 = Instance.new('Attachment')
		a0.Name, a0.CFrame, a0.Parent = 'CometA' .. i, CFrame.new(arc[1] - V(0, 0.15, 0)) * up, ctx.deck
		local a1 = Instance.new('Attachment')
		a1.Name, a1.CFrame, a1.Parent = 'CometB' .. i, CFrame.new(arc[2] - V(0, 0.15, 0)) * up, ctx.deck
		local b = Instance.new('Beam')
		b.Name = 'Comet' .. i
		b.Attachment0, b.Attachment1 = a0, a1
		HoodVFX.applyTexture(b, 'comet')
		b.TextureMode, b.TextureLength, b.TextureSpeed = Enum.TextureMode.Stretch, 1, 0.5 + 0.2 * i
		b.CurveSize0, b.CurveSize1 = arc[3], -arc[3]
		b.Width0, b.Width1 = 0.9, 0.06 -- the head (Attachment0) wide, the tail thin
		b.FaceCamera, b.Segments = true, 16
		b.LightEmission, b.LightInfluence, b.Brightness = 0.2, 0, 0.85 -- (mostly opaque, not over-bright: the colour holds)
		b.Color = ColorSequence.new(C(255, 110, 225), C(150, 60, 255))
		b.Transparency = seq({ { 0, 0 }, { 1, 1 } })
		b.Parent = ctx.deck
	end
	emitter(ctx.deck, 'Motes', 'ember', {
		Rate = 9 * A, Lifetime = NR(1.4, 2.4), Speed = NR(1, 3), SpreadAngle = Vector2.new(30, 30), Acceleration = V(0, 1, 0), Drag = 0.5,
		Size = seq({ { 0, 0 }, { 0.2, 0.3 * S, 0.1 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(250, 120, 230) } }), LightEmission = 1, Brightness = 1.3, ZOffset = 0.8,
	})
	emitter(ctx.column, 'Glints', 'glitter', {
		Rate = 6 * A, Lifetime = NR(0.45, 0.8), Speed = NR(0.2, 0.8), Rotation = NR(0, 90), RotSpeed = NR(-60, 60),
		Size = seq({ { 0, 0 }, { 0.3, 0.7 * S, 0.25 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(255, 170, 240) } }), LightEmission = 1, Brightness = 1.5, ZOffset = 1,
	})
	pointLight(ctx.column, color, 0.6, 12)
end

-- 5 Frost: ice sparkles twinkling over the cyan ice and slow snow drifting down.
function HoodVFX.Themes.frost(ctx)
	local A, S, color, w, d, h = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d, ctx.h
	emitter(ctx.column, 'IceSparkle', 'snow', {
		Rate = 9 * A, Lifetime = NR(0.5, 0.9), Speed = NR(0.2, 0.6), Rotation = NR(0, 60), RotSpeed = NR(-50, 50),
		Size = seq({ { 0, 0 }, { 0.35, 0.65 * S, 0.2 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, lighten(color, 0.4) } }), LightEmission = 1, Brightness = 1.5, ZOffset = 1,
	})
	local sky = holder(ctx.theme, 'SnowSky', ctx.top * CFrame.new(0, h * 0.8, 0), V(w, 0.2, d))
	emitter(sky, 'Snowfall', 'snow', {
		EmissionDirection = Enum.NormalId.Bottom, Rate = 8 * A, Lifetime = NR(4, 5.5), Speed = NR(1.2, 2), SpreadAngle = Vector2.new(20, 20),
		Acceleration = V(0.3, 0, 0.2), RotSpeed = NR(-60, 60), Size = seq({ { 0, 0.3 * S, 0.1 * S }, { 1, 0.3 * S, 0.1 * S } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0.1 }, { 0.85, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(WHITE), LightEmission = 0.4,
	})
	pointLight(ctx.column, C(170, 230, 255), 0.6, 12)
end

-- A field of soft, straight vertical wisps rising from the whole pad to above the bag (6-8 studs), the
-- reference's toxic look (no curly stock wisps). `from`/`to` colour the wisp from root to tip.
local function streakField(ctx, name, rate, from, to, tall)
	local field = holder(ctx.theme, name .. 'Field', ctx.top * CFrame.new(0, 0.15, 0), V(ctx.w * 0.95, 0.2, ctx.d * 0.95))
	return emitter(field, name, 'streakup', {
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = rate, Lifetime = NR(1.5, 2.5),
		Speed = NR(1, 2), SpreadAngle = Vector2.new(2, 2), Acceleration = V(0, 0.4, 0), Drag = 0.2, Rotation = NR(-3, 3),
		Size = seq({ { 0, tall or 8.5, 1 }, { 1, (tall or 8.5) + 1, 1 } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.2 }, { 0.65, 0.3 }, { 1, 1 } }),
		Color = cseq({ { 0, from }, { 1, to } }), LightEmission = 0,
	})
end

-- 6 Toxic: soft dark-green wisps rising out of the whole neon-rimmed pit past the bag, ooze bubbles, spores.
function HoodVFX.Themes.toxic(ctx)
	local A, S, color = ctx.A, ctx.S, ctx.color
	streakField(ctx, 'DarkStreaks', 11 * A, C(14, 70, 30), C(4, 24, 10))
	emitter(ctx.deck, 'Bubbles', 'bubble', {
		Rate = 4 * A, Lifetime = NR(1, 1.8), Speed = NR(0.5, 1.4), SpreadAngle = Vector2.new(20, 20), Acceleration = V(0, 0.6, 0), Drag = 0.6,
		RotSpeed = NR(-30, 30), Size = seq({ { 0, 0.2 * S }, { 0.85, 0.7 * S, 0.2 * S }, { 0.9, 0.9 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.85, 0.1 }, { 1, 1 } }), Color = cseq({ { 0, lighten(color, 0.3) }, { 1, color } }), LightEmission = 0.5, ZOffset = 0.6,
	})
	emitter(ctx.column, 'Spores', 'ember', {
		Rate = 4 * A, Lifetime = NR(1.5, 2.5), Speed = NR(0.5, 1.5), SpreadAngle = Vector2.new(40, 40), Acceleration = V(0, 0.5, 0),
		Size = seq({ { 0, 0 }, { 0.2, 0.26 * S }, { 1, 0 } }), Color = ColorSequence.new(lighten(color, 0.2)), LightEmission = 1, Brightness = 1.2, ZOffset = 0.8,
	})
	pointLight(ctx.column, color, 0.75, 14)
end

-- 7 Shadow: the same straight wisps in violet over the deep purple pad, and a low violet ground fog.
function HoodVFX.Themes.shadow(ctx)
	local A, S, color = ctx.A, ctx.S, ctx.color
	streakField(ctx, 'VioletStreaks', 10 * A, C(130, 75, 215), C(45, 22, 80), 4.5) -- capped near 5 studs: no purple fire
	emitter(ctx.deck, 'GroundFog', 'mist', {
		Rate = 1.2 * A, Lifetime = NR(3, 4), Speed = NR(0.4, 1), SpreadAngle = Vector2.new(85, 85), Drag = 0.8, Acceleration = V(0, -0.1, 0),
		RotSpeed = NR(-10, 10), ZOffset = -1, Size = seq({ { 0, 2.5 * S }, { 1, 5 * S } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }),
		Color = ColorSequence.new(C(120, 80, 180)), LightEmission = 0,
	})
	pointLight(ctx.column, color, 0.75, 14)
end

-- 8 Gold: big white four-point glints popping all over the mat and up to six studs above it, a few specks.
function HoodVFX.Themes.gold(ctx)
	local A, S, w, d = ctx.A, ctx.S, ctx.w, ctx.d
	local air = holder(ctx.theme, 'GlintAir', ctx.top * CFrame.new(0, 3, 0), V(w, 6, d))
	emitter(air, 'Glints', 'glitter', {
		Rate = 38, Lifetime = NR(0.5, 0.9), Speed = NR(0.05, 0.3), Rotation = NR(0, 20), RotSpeed = NR(-40, 40),
		Size = seq({ { 0, 0 }, { 0.35, 0.8, 0.2 }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(255, 246, 200) } }), LightEmission = 1, Brightness = 1.8, ZOffset = 1.2,
	})
	emitter(ctx.deck, 'Specks', 'ember', {
		Rate = 5 * A, Lifetime = NR(1.2, 2.2), Speed = NR(0.8, 2.4), SpreadAngle = Vector2.new(35, 35), Acceleration = V(0, 0.6, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.2, 0.24 * S, 0.08 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(255, 226, 120) } }), LightEmission = 1, Brightness = 1.5, ZOffset = 1,
	})
	pointLight(ctx.column, C(255, 220, 110), 0.75, 14)
end

function HoodVFX.theme(part, name, size, opts)
	opts = opts or {}
	local recipe = HoodVFX.Themes[name] or HoodVFX.Themes.stone
	if typeof(size) == 'number' then size = V(size, 12, size) end
	size = size or V(part.Size.X, 12, part.Size.Z)
	local w, h, d = size.X, size.Y, size.Z
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	local theme = Instance.new('Model')
	theme.Name = 'Theme'
	theme:SetAttribute('Theme', name)
	theme.Parent = opts.parent or part.Parent or part
	-- Spawn volumes: a thin slab on the mat and the column above it.
	local deck = holder(theme, 'ThemeDeck', top * CFrame.new(0, 0.15, 0), V(w * 0.9, 0.3, d * 0.9))
	local column = holder(theme, 'ThemeColumn', top * CFrame.new(0, h * 0.38, 0), V(w * 0.8, h * 0.6, d * 0.8))
	recipe({
		theme = theme, top = top, deck = deck, column = column, bag = opts.bag, burners = opts.burners,
		w = w, h = h, d = d, A = (w * d) / 100, S = math.sqrt(w * d) / 11, -- rates scale with the mat area, sizes with its span
		color = opts.color or THEME_COLOR[name] or WHITE, tier = opts.tier or 1,
	})
	return theme
end

---------------------------------------------------------------------------------------------- LOD
-- Switch every emitter, beam and light under `container` on or off (e.g. a client turning off auras more
-- than ~120 studs away). Only writes when the value changes: emitter property writes are not free.
function HoodVFX.setEnabled(container, on)
	for _, d in container:GetDescendants() do
		-- (An emitter waiting for its texture upload stays off.)
		local want = on and not d:GetAttribute('NeedsUpload')
		if (d:IsA('ParticleEmitter') or d:IsA('Beam') or d:IsA('Light')) and d.Enabled ~= want then d.Enabled = want end
	end
end

-- Multiply every emitter's Rate under `container` by k (0..1), relative to the rate it was built with, so it
-- can be called again with a new k. Emitters keep their built rate in the BaseRate attribute.
function HoodVFX.setDensity(container, k)
	for _, d in container:GetDescendants() do
		if d:IsA('ParticleEmitter') then
			local base = d:GetAttribute('BaseRate')
			if not base then
				base = d.Rate
				d:SetAttribute('BaseRate', base)
			end
			local rate = base * math.clamp(k, 0, 1)
			if d.Rate ~= rate then d.Rate = rate end
		end
	end
end

return HoodVFX
