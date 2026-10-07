-- Hood VFX: layered, tiered effects built from ParticleEmitters, Beams and lights. Works from map builders
-- (edit time, server) and from client scripts alike; it never yields and only sets real engine properties.
--
--   HoodVFX.station(part, tier, color, size?, opts?)  aura on a training platform; returns the Aura model
--   HoodVFX.item(part, tier, color, opts?)            glow / sparkles / fire on a displayed item; returns emitters
--   HoodVFX.theme(part, name, size?, opts?)           themed effects on a bag-station mat (lava flames, frost
--                                                     mist, toxic wisps...); returns the Theme model
--   HoodVFX.setEnabled(container, on)                 switch every effect under `container` (distance LOD)
--   HoodVFX.setDensity(container, k)                  scale every emitter's Rate (e.g. 0.5 on low graphics)
--   HoodVFX.Textures                                  name -> uploaded rbxassetid ('' = use a Roblox built-in)
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
-- Textures: hood/art/vfx/*.png (make_aura_textures.js; the themes' rain, ember, bubble, snow and tendril come
-- from make_theme_textures.js). Until they are uploaded and pasted into Textures, every layer falls back to a
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
	tendril = '', -- 2x2 rising smoke strands (static random frame)
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
	bubble = 'rbxasset://textures/particles/explosion01_shockwave_main.dds', tendril = 'rbxasset://textures/particles/smoke_main.dds',
}
-- Flipbook settings, applied only when the uploaded sheet is in use.
local FLIPBOOK = {
	aura = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(0), FlipbookStartRandom = true },
	arc = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(0), FlipbookStartRandom = true },
	wisp = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot },
	flame = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(16, 22), FlipbookStartRandom = true },
	tendril = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NR(0), FlipbookStartRandom = true },
}

-- Opacity kept when a texture falls back to a built-in (wisps and arcs have no built-in look-alike).
local FALLBACK_FADE = { wisp = 0.45, arc = 0.6, tendril = 0.5 }
-- Extra settings for a built-in stand-in: a soft glow squashed into a streak reads as rain.
local FALLBACK_PROPS = { rain = { Squash = NumberSequence.new(3), Size = NumberSequence.new(0.7) } }

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

-- A ParticleEmitter with everything the engine needs spelled out: LightInfluence 0 (glows stay bright at
-- night; Instance.new gives 0 but Studio insertion gives 1, so never rely on the default), the texture or its
-- built-in fallback, and the flipbook layout only when the real sheet is uploaded.
local function emitter(parent, name, tex, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	local id, uploaded = texture(tex)
	e.Texture = id
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Rotation = NR(0, 360)
	for k, v in props do (e :: any)[k] = v end
	if uploaded and FLIPBOOK[tex] then
		for k, v in FLIPBOOK[tex] do (e :: any)[k] = v end
	end
	if not uploaded and FALLBACK_PROPS[tex] then
		for k, v in FALLBACK_PROPS[tex] do (e :: any)[k] = v end
	end
	if not uploaded and FALLBACK_FADE[tex] then
		-- A built-in stand-in is only a soft blob: keep it faint so it supports instead of smothering.
		local f, k = FALLBACK_FADE[tex], {}
		for _, kp in e.Transparency.Keypoints do table.insert(k, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * f, kp.Envelope * f)) end
		e.Transparency = NumberSequence.new(k)
	end
	e:SetAttribute('PreviewTexture', tex)
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
			b.Texture = texture('shaft')
			b:SetAttribute('PreviewTexture', 'shaft')
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
-- Effects that belong to a bag station's mat material, one theme per tier (the punching-bag stations,
-- d2_stations): `part` is the mat (effects stand on its top face, use its axes), `name` one of the keys of
-- HoodVFX.Themes, `size` Vector3 (width, effect height, depth) or nil for (part width, 12, part depth).
-- opts.parent (default: the part's parent), opts.color (the theme's glow colour), opts.tier (1..8, makes the
-- shared layers a little stronger per tier). Returns the Theme model; every holder part in it is invisible.
-- Each theme is 4-7 layers: a ground glow, a volume (mist/smoke/flames), detail (wisps, bubbles, rain,
-- embers), sparkle, and from tier 3 one PointLight. Live particles (Rate x Lifetime on the 12 x 10 mat):
--   stone ~12  red ~33  lava ~56  arcane ~52  frost ~59  toxic ~76  shadow ~78  gold ~92
HoodVFX.Themes = {}
local THEME_COLOR = {
	stone = C(255, 244, 220), red = C(255, 70, 80), lava = C(255, 140, 30), arcane = C(196, 120, 255),
	frost = C(150, 236, 255), toxic = C(120, 255, 80), shadow = C(176, 120, 255), gold = C(255, 214, 80),
}

-- Shared layer: a flat glow pool on the mat (VelocityPerpendicular + tiny upward speed = lies flat).
local function floorGlow(at, w, color, strength)
	return emitter(at, 'FloorGlow', 'softglow', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.8, Lifetime = NR(2.5),
		Size = seq({ { 0, w * 0.95 }, { 1, w * 1.05 } }), Rotation = NR(0),
		Transparency = seq({ { 0, 1 }, { 0.3, 1 - strength }, { 0.7, 1 - strength }, { 1, 1 } }),
		Color = cseq({ { 0, lighten(color, 0.3) }, { 1, color } }), LightEmission = 1,
	})
end
local function pointLight(at, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Name = 'ThemeLight'
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = at
	return l
end
-- Four thin slabs round the mat's edge (for things that rise around the pad, not over the bag).
local function edgeHolders(theme, top, w, d)
	local list = {}
	for _, e in { { V(0, 0, -d / 2 + 0.35), V(w * 0.92, 0.2, 0.5) }, { V(0, 0, d / 2 - 0.35), V(w * 0.92, 0.2, 0.5) },
		{ V(-w / 2 + 0.35, 0, 0), V(0.5, 0.2, d * 0.92) }, { V(w / 2 - 0.35, 0, 0), V(0.5, 0.2, d * 0.92) } } do
		table.insert(list, holder(theme, 'EdgeFx', top * CFrame.new(e[1] + V(0, 0.15, 0)), e[2]))
	end
	return list
end

-- 1 Stone: the humble start. Chalk dust drifting off the mat and the odd puff.
function HoodVFX.Themes.stone(ctx)
	local A, S, color = ctx.A, ctx.S, ctx.color
	emitter(ctx.deck, 'Dust', 'dust', {
		Rate = 3 * A, Lifetime = NR(2, 3.4), Speed = NR(0.3, 1), SpreadAngle = Vector2.new(30, 30), Acceleration = V(0, 0.4, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.15, 0.28 * S, 0.08 * S }, { 0.8, 0.2 * S, 0.06 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.35 }, { 0.75, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 0.3,
	})
	emitter(ctx.deck, 'Puff', 'mist', {
		Rate = 0.5 * A, Lifetime = NR(2.5, 3.5), Speed = NR(0.4, 1), SpreadAngle = Vector2.new(70, 70), Drag = 0.6, ZOffset = -1,
		Size = seq({ { 0, 1.5 * S }, { 1, 4 * S } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.8 }, { 1, 1 } }),
		Color = ColorSequence.new(C(220, 222, 230)), LightEmission = 0,
	})
end

-- 2 Red: red rain streaking down onto the mat, tiny splashes where it lands, a red sheen.
function HoodVFX.Themes.red(ctx)
	local A, S, color, w, d, h = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d, ctx.h
	floorGlow(ctx.floor, w, color, 0.3)
	local sky = holder(ctx.theme, 'RainSky', ctx.top * CFrame.new(0, h * 0.7, 0), V(w * 0.95, 0.2, d * 0.95))
	emitter(sky, 'Rain', 'rain', {
		EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 60 * A, Lifetime = NR(0.3, 0.36), Speed = NR(22, 26), SpreadAngle = Vector2.new(4, 4),
		Size = seq({ { 0, 2.6 * S }, { 1, 2.8 * S } }), Transparency = seq({ { 0, 1 }, { 0.12, 0.1 }, { 0.85, 0.15 }, { 1, 1 } }),
		Color = cseq({ { 0, C(255, 110, 124) }, { 1, color } }), LightEmission = 0.2,
	})
	emitter(ctx.deck, 'Splash', 'dust', {
		Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 14 * A, Lifetime = NR(0.2, 0.35),
		Speed = NR(3, 6), SpreadAngle = Vector2.new(55, 55), Acceleration = V(0, -30, 0), Drag = 1,
		Size = seq({ { 0, 0.22 * S }, { 1, 0 } }), Squash = seq({ { 0, 1.2 }, { 1, 0.5 } }),
		Color = cseq({ { 0, C(255, 200, 205) }, { 1, color } }), LightEmission = 0.8,
	})
	emitter(ctx.deck, 'Haze', 'mist', {
		Rate = 0.7 * A, Lifetime = NR(2.5, 3.5), Speed = NR(0.5, 1.2), SpreadAngle = Vector2.new(80, 80), Drag = 0.6, ZOffset = -1,
		Size = seq({ { 0, 2 * S }, { 1, 5 * S } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.72 }, { 1, 1 } }),
		Color = ColorSequence.new(lighten(color, 0.2)), LightEmission = 0,
	})
end

-- 3 Lava: flames licking all over the mat, embers spiralling up, a heat glow and a little smoke.
function HoodVFX.Themes.lava(ctx)
	local A, S, color, w, d = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d
	floorGlow(ctx.floor, w, color, 0.25)
	emitter(ctx.deck, 'Flames', 'flame', {
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 32 * A, Lifetime = NR(0.5, 0.9),
		Speed = NR(1.2, 2.6), SpreadAngle = Vector2.new(10, 10), Acceleration = V(0, 3, 0), Drag = 0.5, ZOffset = 0.3,
		Rotation = NR(-8, 8), Size = seq({ { 0, 1.6 * S }, { 0.3, 3 * S, 0.6 * S }, { 1, 1.6 * S } }),
		Transparency = seq({ { 0, 0.6 }, { 0.15, 0.05 }, { 0.7, 0.25 }, { 1, 1 } }),
		Color = cseq({ { 0, C(255, 236, 120) }, { 0.2, C(255, 184, 40) }, { 0.5, C(255, 110, 14) }, { 1, C(190, 40, 10) } }), LightEmission = 0.3,
	})
	emitter(ctx.deck, 'Embers', 'ember', {
		Rate = 9 * A, Lifetime = NR(1.4, 2.6), Speed = NR(2, 5), SpreadAngle = Vector2.new(25, 25), Acceleration = V(0.6, 1.5, 0.3), Drag = 0.6,
		RotSpeed = NR(-40, 40), Size = seq({ { 0, 0.32 * S, 0.1 * S }, { 0.7, 0.22 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Color = cseq({ { 0, C(255, 240, 160) }, { 0.4, C(255, 160, 40) }, { 1, C(255, 70, 20) } }), LightEmission = 1, Brightness = 2, ZOffset = 0.8,
	})
	emitter(ctx.core, 'HeatGlow', 'softglow', {
		Rate = 0.8, Lifetime = NR(2.5), Speed = NR(0), Rotation = NR(0), ZOffset = -2,
		Size = seq({ { 0, 8 * S }, { 1, 9 * S } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.78 }, { 0.6, 0.78 }, { 1, 1 } }),
		Color = ColorSequence.new(C(255, 120, 30)), LightEmission = 1,
	})
	emitter(ctx.deck, 'Smoke', 'aura', {
		Rate = 0.9 * A, Lifetime = NR(2.5, 3.5), Speed = NR(1.5, 2.5), SpreadAngle = Vector2.new(20, 20), Drag = 0.4, Acceleration = V(0, 0.8, 0), ZOffset = -1.5,
		RotSpeed = NR(-15, 15), Size = seq({ { 0, 1.5 * S }, { 1, 4.5 * S } }), Transparency = seq({ { 0, 1 }, { 0.25, 0.7 }, { 1, 1 } }),
		Color = ColorSequence.new(C(70, 56, 54)), LightEmission = 0,
	})
	pointLight(ctx.column, C(255, 140, 50), 1.2, 14)
end

-- 4 Arcane: a purple vortex turning on the mat, rising curls, sparks of magic and a pulsing ring.
function HoodVFX.Themes.arcane(ctx)
	local A, S, color, w, d = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d
	-- No floor glow: on a bright purple mat additive layers stack to white; the vortex carries the ground.
	emitter(ctx.floor, 'Swirl', 'swirl', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.5, Lifetime = NR(3, 3.4),
		RotSpeed = NR(100, 140), Size = seq({ { 0, 0.6 * w }, { 1, 0.78 * w } }),
		Transparency = seq({ { 0, 1 }, { 0.25, 0.68 }, { 0.75, 0.68 }, { 1, 1 } }),
		Color = ColorSequence.new(darken(color, 0.15)), LightEmission = 1,
	})
	emitter(ctx.floor, 'Ring', 'ring', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.5, Lifetime = NR(1.4, 1.8),
		Rotation = NR(0), Size = seq({ { 0, 2 * S }, { 1, 0.9 * math.min(w, d) } }), Transparency = seq({ { 0, 0.45 }, { 0.6, 0.65 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 1,
	})
	emitter(ctx.deck, 'Wisps', 'wisp', {
		Rate = 3.5 * A, Lifetime = NR(1.6, 2.4), Speed = NR(2.5, 4.5), SpreadAngle = Vector2.new(22, 22),
		Drag = 0.8, Acceleration = V(0, 1.2, 0), Rotation = NR(-40, 40), RotSpeed = NR(-30, 30),
		Size = seq({ { 0, 2.6 * S, 0.5 * S }, { 1, 4 * S, 0.7 * S } }), Transparency = seq({ { 0, 0.4 }, { 0.15, 0 }, { 0.8, 0.15 }, { 1, 1 } }),
		Color = cseq({ { 0, WHITE }, { 1, lighten(color, 0.3) } }), LightEmission = 0.6, Brightness = 1.4,
	})
	emitter(ctx.deck, 'Motes', 'ember', {
		Rate = 13 * A, Lifetime = NR(1.4, 2.4), Speed = NR(1, 3), SpreadAngle = Vector2.new(30, 30), Acceleration = V(0, 1, 0), Drag = 0.5,
		Size = seq({ { 0, 0 }, { 0.2, 0.3 * S, 0.1 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, color } }), LightEmission = 1, Brightness = 1.8, ZOffset = 0.8,
	})
	emitter(ctx.column, 'Glints', 'glitter', {
		Rate = 7 * A, Lifetime = NR(0.45, 0.8), Speed = NR(0.2, 0.8), Rotation = NR(0, 90), RotSpeed = NR(-60, 60),
		Size = seq({ { 0, 0 }, { 0.3, 0.7 * S, 0.25 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, lighten(color, 0.3) } }), LightEmission = 1, Brightness = 2, ZOffset = 1,
	})
	emitter(ctx.deck, 'Sparks', 'dust', {
		Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 6 * A, Lifetime = NR(0.6, 1.1),
		Speed = NR(6, 10), SpreadAngle = Vector2.new(18, 18), Drag = 1.2, Acceleration = V(0, -2, 0),
		Size = seq({ { 0, 0.28 * S }, { 1, 0 } }), Squash = seq({ { 0, 1.5 }, { 1, 1 } }),
		Color = cseq({ { 0, WHITE }, { 1, color } }), LightEmission = 1, Brightness = 1.8,
	})
	pointLight(ctx.column, color, 1, 12)
end

-- 5 Frost: cold mist rolling off the ice and sinking over the edge, ice sparkles, slow snow.
function HoodVFX.Themes.frost(ctx)
	local A, S, color, w, d, h = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d, ctx.h
	-- The ice itself glows (it's a pale mat): no additive floor pool, the mist stays thin so the cyan reads.
	emitter(ctx.deck, 'FrostMist', 'aura', {
		Rate = 2 * A, Lifetime = NR(3, 4), Speed = NR(0.6, 1.6), SpreadAngle = Vector2.new(80, 80), Drag = 0.5, Acceleration = V(0, -0.15, 0),
		RotSpeed = NR(-12, 12), ZOffset = -1.2, Size = seq({ { 0, 2.5 * S, 0.5 * S }, { 0.5, 4.5 * S, 0.8 * S }, { 1, 6 * S, S } }),
		Transparency = seq({ { 0, 1 }, { 0.2, 0.6, 0.08 }, { 0.65, 0.68, 0.08 }, { 1, 1 } }),
		Color = cseq({ { 0, C(240, 252, 255) }, { 1, C(170, 226, 255) } }), LightEmission = 0.05,
	})
	emitter(ctx.deck, 'FrostSpill', 'mist', {
		Rate = 1.2 * A, Lifetime = NR(2.5, 3.5), Speed = NR(2.5, 4), SpreadAngle = Vector2.new(85, 85), Drag = 0.8, Acceleration = V(0, -0.5, 0),
		RotSpeed = NR(-10, 10), ZOffset = -1, Size = seq({ { 0, 3 * S }, { 1, 6.5 * S } }), Transparency = seq({ { 0, 1 }, { 0.25, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(C(226, 246, 255)), LightEmission = 0,
	})
	emitter(ctx.column, 'IceSparkle', 'snow', {
		Rate = 8 * A, Lifetime = NR(0.5, 0.9), Speed = NR(0.2, 0.6), Rotation = NR(0, 60), RotSpeed = NR(-50, 50),
		Size = seq({ { 0, 0 }, { 0.35, 0.65 * S, 0.2 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, lighten(color, 0.4) } }), LightEmission = 1, Brightness = 2, ZOffset = 1,
	})
	local sky = holder(ctx.theme, 'SnowSky', ctx.top * CFrame.new(0, h * 0.8, 0), V(w, 0.2, d))
	emitter(sky, 'Snowfall', 'snow', {
		EmissionDirection = Enum.NormalId.Bottom, Rate = 7 * A, Lifetime = NR(4, 5.5), Speed = NR(1.2, 2), SpreadAngle = Vector2.new(20, 20),
		Acceleration = V(0.3, 0, 0.2), RotSpeed = NR(-60, 60), Size = seq({ { 0, 0.3 * S, 0.1 * S }, { 1, 0.3 * S, 0.1 * S } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0.1 }, { 0.85, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(WHITE), LightEmission = 0.4,
	})
	pointLight(ctx.column, C(170, 230, 255), 1, 12)
end

-- 6 Toxic: dark wisps rising round the pit, ooze bubbles popping, a low green fume.
function HoodVFX.Themes.toxic(ctx)
	local A, S, color, w, d = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d
	floorGlow(ctx.floor, w, color, 0.5)
	for i, edge in edgeHolders(ctx.theme, ctx.top, w, d) do
		local long = math.max(edge.Size.X, edge.Size.Z)
		emitter(edge, 'DarkWisps' .. i, 'tendril', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 0.65 * long, Lifetime = NR(1.4, 2.2),
			Speed = NR(1.5, 3), SpreadAngle = Vector2.new(6, 6), Acceleration = V(0, 1, 0), Drag = 0.3, Rotation = NR(-6, 6),
			Size = seq({ { 0, 3.2 * S, 0.5 * S }, { 1, 5 * S, 0.6 * S } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.05 }, { 0.7, 0.2 }, { 1, 1 } }),
			Color = cseq({ { 0, C(24, 64, 28) }, { 0.5, C(12, 30, 16) }, { 1, C(4, 8, 6) } }), LightEmission = 0,
		})
	end
	emitter(ctx.deck, 'Bubbles', 'bubble', {
		Rate = 6 * A, Lifetime = NR(1, 1.8), Speed = NR(0.5, 1.4), SpreadAngle = Vector2.new(20, 20), Acceleration = V(0, 0.6, 0), Drag = 0.6,
		RotSpeed = NR(-30, 30), Size = seq({ { 0, 0.2 * S }, { 0.85, 0.75 * S, 0.2 * S }, { 0.9, 0.95 * S }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.85, 0.1 }, { 1, 1 } }), Color = cseq({ { 0, lighten(color, 0.3) }, { 1, color } }), LightEmission = 0.5, ZOffset = 0.6,
	})
	emitter(ctx.deck, 'Fume', 'aura', {
		Rate = 1.4 * A, Lifetime = NR(2.5, 3.5), Speed = NR(0.5, 1.4), SpreadAngle = Vector2.new(75, 75), Drag = 0.5, Acceleration = V(0, 0.2, 0),
		RotSpeed = NR(-15, 15), ZOffset = -1.5, Size = seq({ { 0, 2.5 * S }, { 1, 5.5 * S } }), Transparency = seq({ { 0, 1 }, { 0.25, 0.6 }, { 1, 1 } }),
		Color = cseq({ { 0, C(150, 255, 100) }, { 1, C(60, 160, 50) } }), LightEmission = 0.05,
	})
	emitter(ctx.column, 'Spores', 'ember', {
		Rate = 5 * A, Lifetime = NR(1.5, 2.5), Speed = NR(0.5, 1.5), SpreadAngle = Vector2.new(40, 40), Acceleration = V(0, 0.5, 0),
		Size = seq({ { 0, 0 }, { 0.2, 0.26 * S }, { 1, 0 } }), Color = ColorSequence.new(lighten(color, 0.2)), LightEmission = 1, Brightness = 1.6, ZOffset = 0.8,
	})
	pointLight(ctx.column, color, 1.5, 15)
end

-- 7 Shadow: heavy black-violet smoke boiling up, dark tendrils, violet sparks and a ring pulse.
function HoodVFX.Themes.shadow(ctx)
	local A, S, color, w, d = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d
	floorGlow(ctx.floor, w, color, 0.3)
	emitter(ctx.deck, 'ShadowSmoke', 'aura', {
		Rate = 3.4 * A, Lifetime = NR(3, 4.2), Speed = NR(1, 2.4), SpreadAngle = Vector2.new(70, 70), Drag = 0.5, Acceleration = V(0, 0.6, 0),
		RotSpeed = NR(-18, 18), ZOffset = -1.5, Size = seq({ { 0, 3 * S, 0.5 * S }, { 0.45, 5.5 * S, 0.8 * S }, { 1, 7.5 * S, S } }),
		Transparency = seq({ { 0, 1 }, { 0.2, 0.3, 0.08 }, { 0.6, 0.45, 0.08 }, { 1, 1 } }),
		Color = cseq({ { 0, C(70, 50, 110) }, { 0.4, C(34, 24, 54) }, { 1, C(12, 10, 18) } }), LightEmission = 0,
	})
	for i, edge in edgeHolders(ctx.theme, ctx.top, w, d) do
		local long = math.max(edge.Size.X, edge.Size.Z)
		emitter(edge, 'DarkWisps' .. i, 'tendril', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 0.72 * long, Lifetime = NR(1.4, 2.2),
			Speed = NR(2, 3.5), SpreadAngle = Vector2.new(6, 6), Acceleration = V(0, 1, 0), Drag = 0.3, Rotation = NR(-6, 6),
			Size = seq({ { 0, 2.6 * S, 0.4 * S }, { 1, 4 * S, 0.5 * S } }), Transparency = seq({ { 0, 1 }, { 0.2, 0.2 }, { 0.7, 0.35 }, { 1, 1 } }),
			Color = cseq({ { 0, C(60, 40, 100) }, { 1, C(10, 8, 16) } }), LightEmission = 0,
		})
	end
	emitter(ctx.deck, 'VoidSparks', 'dust', {
		Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 5 * A, Lifetime = NR(0.6, 1.1),
		Speed = NR(6, 10), SpreadAngle = Vector2.new(18, 18), Drag = 1.2, Acceleration = V(0, -2, 0),
		Size = seq({ { 0, 0.3 * S }, { 1, 0 } }), Squash = seq({ { 0, 1.5 }, { 1, 1 } }),
		Color = cseq({ { 0, WHITE }, { 1, color } }), LightEmission = 1, Brightness = 2,
	})
	emitter(ctx.column, 'Glints', 'glitter', {
		Rate = 4 * A, Lifetime = NR(0.45, 0.8), Speed = NR(0.2, 0.8), Rotation = NR(0, 90), RotSpeed = NR(-60, 60),
		Size = seq({ { 0, 0 }, { 0.3, 0.7 * S, 0.25 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, lighten(color, 0.3) } }), LightEmission = 1, Brightness = 2, ZOffset = 1,
	})
	emitter(ctx.floor, 'Ring', 'ring', {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NR(0.01), Rate = 0.6, Lifetime = NR(1.4, 1.8),
		Rotation = NR(0), Size = seq({ { 0, 2 * S }, { 1, 0.95 * math.min(w, d) } }), Transparency = seq({ { 0, 0.25 }, { 0.6, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 1, Brightness = 1.5,
	})
	pointLight(ctx.column, color, 1.6, 15)
end

-- 8 Gold: glints popping all over, glitter drifting up, warm light rays and gold dust.
function HoodVFX.Themes.gold(ctx)
	local A, S, color, w, d, h = ctx.A, ctx.S, ctx.color, ctx.w, ctx.d, ctx.h
	floorGlow(ctx.floor, w, color, 0.2)
	emitter(ctx.core, 'GoldGlow', 'softglow', {
		Rate = 0.8, Lifetime = NR(2.5), Speed = NR(0), Rotation = NR(0), ZOffset = -2,
		Size = seq({ { 0, 9 * S }, { 1, 10 * S } }), Transparency = seq({ { 0, 1 }, { 0.4, 0.88 }, { 0.6, 0.88 }, { 1, 1 } }),
		Color = ColorSequence.new(C(255, 190, 50)), LightEmission = 1,
	})
	emitter(ctx.column, 'Glints', 'glitter', {
		Rate = 16 * A, Lifetime = NR(0.5, 0.9), Speed = NR(0.1, 0.5), Rotation = NR(0, 45), RotSpeed = NR(-60, 60),
		Size = seq({ { 0, 0 }, { 0.35, 1.0 * S, 0.3 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(255, 230, 140) } }), LightEmission = 1, Brightness = 2.5, ZOffset = 1.2,
	})
	emitter(ctx.deck, 'MatGlints', 'glitter', {
		Rate = 12 * A, Lifetime = NR(0.4, 0.7), Speed = NR(0.05, 0.2), Rotation = NR(0, 45),
		Size = seq({ { 0, 0 }, { 0.35, 0.8 * S, 0.25 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 1, C(255, 236, 160) } }), LightEmission = 1, Brightness = 2.5, ZOffset = 1,
	})
	emitter(ctx.deck, 'Glitter', 'ember', {
		Rate = 20 * A, Lifetime = NR(1.2, 2.2), Speed = NR(0.8, 2.4), SpreadAngle = Vector2.new(35, 35), Acceleration = V(0, 0.6, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.2, 0.26 * S, 0.08 * S }, { 1, 0 } }), Color = cseq({ { 0, WHITE }, { 0.5, C(255, 226, 120) }, { 1, C(255, 180, 40) } }), LightEmission = 1, Brightness = 2, ZOffset = 1,
	})
	emitter(ctx.deck, 'Rays', 'ray', {
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1.2 * A, Lifetime = NR(2, 3), Speed = NR(0.05),
		Rotation = NR(0), Size = seq({ { 0, h * 0.7, h * 0.1 }, { 1, h * 0.8, h * 0.1 } }),
		Transparency = seq({ { 0, 1 }, { 0.35, 0.8 }, { 0.65, 0.8 }, { 1, 1 } }), Color = cseq({ { 0, C(255, 240, 180) }, { 1, color } }), LightEmission = 0.8, ZOffset = -1,
	})
	emitter(ctx.deck, 'GoldDust', 'dust', {
		Rate = 7 * A, Lifetime = NR(2, 3.2), Speed = NR(0.4, 1.2), SpreadAngle = Vector2.new(40, 40), Acceleration = V(0, 0.5, 0), Drag = 0.4,
		Size = seq({ { 0, 0 }, { 0.15, 0.3 * S, 0.08 * S }, { 0.8, 0.22 * S }, { 1, 0 } }), Transparency = seq({ { 0, 1 }, { 0.15, 0.3 }, { 0.75, 0.4 }, { 1, 1 } }),
		Color = ColorSequence.new(C(255, 220, 110)), LightEmission = 0.6,
	})
	-- Three steady god rays from the back and sides, leaning out so they frame the bag.
	for i, at in { V(-0.38, 0, 0.1), V(0.38, 0, 0.1), V(0, 0, 0.42) } do
		local a0 = attach(ctx.deck, 'RayBase' .. i, V(at.X * w, 0.1, at.Z * d))
		local a1 = attach(ctx.deck, 'RayTop' .. i, V(at.X * w * 1.5, h * 1.1, at.Z * d * 1.3))
		local b = Instance.new('Beam')
		b.Name = 'GodRay' .. i
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = texture('shaft')
		b:SetAttribute('PreviewTexture', 'shaft')
		b.TextureMode, b.TextureLength, b.TextureSpeed = Enum.TextureMode.Stretch, 1, 0.15 + 0.1 * i
		b.Width0, b.Width1 = 1.8 * S, 3.8 * S
		b.FaceCamera, b.Segments = true, 1
		b.LightEmission, b.LightInfluence, b.Brightness = 0.7, 0, 1.6
		b.Color = ColorSequence.new(C(255, 240, 170), color)
		b.Transparency = seq({ { 0, 0.55 }, { 0.5, 0.75 }, { 1, 1 } })
		b.ZOffset = -1
		b.Parent = ctx.deck
	end
	pointLight(ctx.column, C(255, 214, 110), 1.8, 16)
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
	local deck = holder(theme, 'ThemeDeck', top * CFrame.new(0, 0.15, 0), V(w * 0.86, 0.3, d * 0.86))
	local column = holder(theme, 'ThemeColumn', top * CFrame.new(0, h * 0.38, 0), V(w * 0.7, h * 0.6, d * 0.7))
	recipe({
		theme = theme, top = top, deck = deck, column = column,
		floor = attach(deck, 'Floor', V(0, 0.05, 0)), core = attach(deck, 'Core', V(0, h * 0.3, 0)),
		w = w, h = h, d = d, A = (w * d) / 100, S = math.max(w, d) / 12, -- rates scale with the mat area, sizes with its span
		color = opts.color or THEME_COLOR[name] or WHITE, tier = opts.tier or 1,
	})
	return theme
end

---------------------------------------------------------------------------------------------- LOD
-- Switch every emitter, beam and light under `container` on or off (e.g. a client turning off auras more
-- than ~120 studs away). Only writes when the value changes: emitter property writes are not free.
function HoodVFX.setEnabled(container, on)
	for _, d in container:GetDescendants() do
		if (d:IsA('ParticleEmitter') or d:IsA('Beam') or d:IsA('Light')) and d.Enabled ~= on then d.Enabled = on end
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
