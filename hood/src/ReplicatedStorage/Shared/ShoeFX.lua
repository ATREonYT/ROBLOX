-- ShoeFX: the shoes' rarity effects (brief 24). One ladder, used everywhere a shoe shows:
--   Common   plain
--   Rare     a subtle glint (a white star twinkling on the shoe)
--   Epic     + a soft glow behind and sparkles drifting up
--   Legendary + an aura (a pool of light on the ground, motes rising), a Trail when it moves, more sparkles, a light
--   Mythic   + a strong aura: light shafts, a ground ring, the box's themed particles (stars, embers, snow...)
--   Secret   + everything in rainbow colours and a halo ring over the pair
-- The glow, aura and trail take the RARITY colour (the reference pets' splats: players learn purple = Epic, orange =
-- Legendary, red = Mythic, rainbow = Secret); sparkles and themed particles take the shoe's own theme colours.
--
--   ShoeFX.tier(rarity) -> Tiers row            pure data, no Instances (the 2D reveal reads it; UI6):
--       { Id, Rank, Name, Color, Accent, Gradient (ColorSequence; Secret = rainbow), Glint, Glow 0..1, Rays 0..16,
--         Sparkles 0..24, Trail, EdgeGlow, Rainbow, Halo, Shake 0..1, Hold (extra seconds) }
--     rarity: 'Common'..'Secret', a rank 1..6, or a Config.Shoes rarity row
--   ShoeFX.apply(model, rarity, opts?) -> holder?   the 3D effects (client-side eye candy; nil for Common)
--       model: a ShoeModels.pair or .shoe model (anchored, or welded to its PrimaryPart), or a worn 'HoodShoes' model
--       opts.context  'follower' (default) | 'display' | 'worn'
--       opts.feet     (worn) { { Part = foot part, At = CFrame from it to the shoe's Fit centre, Scale = Vector3,
--                     Side = 'L' | 'R' } } (ShoeModels.wear passes them)
--       opts.id       the shoe id (default the model's ShoeId attribute): its box's theme colours
--       opts.theme    { tex = name, colors = { Color3 } } overrides the theme (ShoeModels passes per-shoe themes)
--       opts.scale    the model's scale (default its Scale attribute)
--       opts.quality  'low' | 'high' (default ShoeFX.quality(): the player's graphics setting)
--       opts.density  0..1 extra rate factor (e.g. other players' pairs)
--     Returns the 'ShoeFX' holder part (the first one on worn shoes; one per foot there). Every emitter, trail and
--     light of the call is under the holder parts named 'ShoeFX'.
--   ShoeFX.setEnabled(container, on), ShoeFX.setDensity(container, k)   LOD switches (write only on change)
--   ShoeFX.live(container) -> number   live particles (Rate x mean Lifetime of the enabled emitters)
--   ShoeFX.quality() -> 'low' | 'high'  graphics levels 1-3 are low (Automatic counts as high: the engine thins
--                     particles itself there); ShoeFX.Quality = 'low' | 'high' forces it
--   ShoeFX.Budget[context][rank]       live particles per pair (measured, see the comment there)
--
-- Performance: emitters only (no per-frame Lua anywhere), rates capped per layer (none above 8/s on a pair), one
-- PointLight per pair (Legendary+, Shadows off), one Trail per moving pair or per worn shoe (Legendary+). On low graphics
-- each tier keeps only its signature layers (Rare glint; Epic glow; Legendary glow + trail; Mythic glow + motes;
-- Secret rainbow glow + halo + trail) at 40 % of the rate, and no light.
local ShoeFX = {}

local V, C = Vector3.new, Color3.fromRGB
local CF = CFrame.new
local NR = NumberRange.new

local function sibling(...)
	local node = script.Parent
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, m = pcall(require, node)
	return ok and type(m) == 'table' and m or nil
end
local Config = sibling('Config', 'Shoes')
local HoodVFX -- (required on first use: the effects only)

---------------------------------------------------------------------------------------------- the ladder (data)
local IDS = { 'Common', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret' }
local COLORS = { C(178, 186, 198), C(61, 155, 255), C(166, 77, 255), C(255, 150, 32), C(255, 59, 92), C(255, 236, 120) }
local RAINBOW = { C(255, 82, 82), C(255, 170, 40), C(255, 236, 70), C(80, 220, 110), C(60, 170, 255), C(170, 90, 255) }
if Config then
	for i, r in Config.Rarities or {} do
		if typeof(r.Color) == 'Color3' and IDS[i] == r.Id then COLORS[i] = r.Color end
	end
	if type(Config.Rainbow) == 'table' and #Config.Rainbow >= 2 then RAINBOW = Config.Rainbow end
end
ShoeFX.Rainbow = RAINBOW

local function cseq(colors)
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local k = {}
	for i, c in colors do table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)) end
	return ColorSequence.new(k)
end
local function lighten(c, t) return c:Lerp(C(255, 255, 255), t) end
local function rainbowSeq(offset)
	local list = {}
	for i = 1, #RAINBOW do list[i] = RAINBOW[(i - 1 + (offset or 0)) % #RAINBOW + 1] end
	table.insert(list, list[1])
	return cseq(list)
end

-- Per rank: Glint, Glow, Rays, Sparkles, Trail, EdgeGlow, Rainbow, Halo, Shake, Hold.
local LADDER = {
	{ false, 0, 0, 0, false, false, false, false, 0, 0 },
	{ true, 0.15, 0, 3, false, false, false, false, 0.1, 0 },
	{ true, 0.35, 6, 8, false, false, false, false, 0.25, 0.3 },
	{ true, 0.55, 10, 14, true, false, false, false, 0.45, 0.8 },
	{ true, 0.8, 14, 20, true, true, false, false, 0.7, 1.2 },
	{ true, 1, 16, 24, true, true, true, true, 1, 1.8 },
}
ShoeFX.Tiers = {}
for rank, id in IDS do
	local l = LADDER[rank]
	local color = COLORS[rank]
	local accent = rank == 6 and C(255, 244, 190) or lighten(color, 0.45)
	local row = {
		Id = id, Rank = rank, Name = id, Color = color, Accent = accent,
		Gradient = rank == 6 and rainbowSeq(0) or cseq({ color, accent }),
		Glint = l[1], Glow = l[2], Rays = l[3], Sparkles = l[4], Trail = l[5], EdgeGlow = l[6], Rainbow = l[7], Halo = l[8],
		Shake = l[9], Hold = l[10],
	}
	table.freeze(row)
	ShoeFX.Tiers[id] = row
	ShoeFX.Tiers[rank] = row
end
table.freeze(ShoeFX.Tiers)

-- The ladder row for 'Epic', 3, or a Config.Shoes rarity row ({ Id = 'Epic', ... }). Unknown -> Common.
function ShoeFX.tier(rarity: any)
	if type(rarity) == 'table' then rarity = rarity.Id or rarity.Rank end
	if type(rarity) == 'number' then rarity = math.clamp(math.floor(rarity), 1, #IDS) end
	return ShoeFX.Tiers[rarity] or ShoeFX.Tiers[1]
end

-- Themed particles per box: the texture (hood/art/vfx name) and its colours. ShoeModels can pass a shoe's own.
ShoeFX.Themes = {
	Street = { tex = 'star', colors = { C(255, 110, 120), C(255, 190, 150) } },
	Graffiti = { tex = 'sparkle', colors = { C(255, 110, 190), C(110, 230, 255), C(150, 255, 110) } },
	Frost = { tex = 'snow', colors = { C(230, 245, 255), C(170, 220, 255) } },
	Lava = { tex = 'ember', colors = { C(255, 190, 70), C(255, 90, 40) } },
	Toxic = { tex = 'dust', colors = { C(170, 255, 100), C(110, 230, 70) } },
	Candy = { tex = 'star', colors = { C(255, 140, 200), C(150, 200, 255), C(255, 230, 120) } },
	Ocean = { tex = 'bubble', colors = { C(190, 240, 255), C(120, 220, 255) } },
	Gem = { tex = 'shard', colors = { C(150, 255, 200), C(220, 250, 255) } },
	Galaxy = { tex = 'star', colors = { C(220, 210, 255), C(170, 140, 255) } },
	Gold = { tex = 'sparkle', colors = { C(255, 225, 110), C(255, 190, 40) } },
	Exclusive = { tex = 'sparkle', colors = { C(170, 240, 255), C(255, 170, 230) } },
	Grail = { tex = 'star', colors = { C(255, 220, 90), C(200, 150, 255) } },
}

---------------------------------------------------------------------------------------------- quality and budget
ShoeFX.Quality = nil -- 'low' | 'high' forces the level (tests, a settings toggle)
function ShoeFX.quality(): string
	if ShoeFX.Quality == 'low' or ShoeFX.Quality == 'high' then return ShoeFX.Quality end
	local ok, level = pcall(function()
		return (UserSettings() :: any):GetService('UserGameSettings').SavedQualityLevel
	end)
	if ok and typeof(level) == 'EnumItem' and level.Value >= 1 and level.Value <= 3 then return 'low' end
	return 'high'
end

-- Live particles (Rate x mean Lifetime) of every enabled emitter under `container`.
function ShoeFX.live(container: Instance): number
	local n = 0
	for _, d in container:GetDescendants() do
		if d:IsA('ParticleEmitter') and d.Enabled then n += d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2 end
	end
	return n
end

-- Live particles per pair, measured with ShoeFX.live at scale 1 (high / low graphics). 'worn' = both feet together.
-- Mobile aim (roblox-vfx skill): <= 150-300 on screen; a Secret pair is ~1 in 2000 opens.
ShoeFX.Budget = {
	follower = { 0, 0.4, 5.3, 16, 32, 39 },
	worn = { 0, 0.5, 5.2, 12.3, 24.8, 31.2 },
	low = { 0, 0.2, 3, 3.5, 7.8, 10.5 }, -- (a follower pair on low graphics; worn shoes are under it too)
}

---------------------------------------------------------------------------------------------- building blocks
local BUILTIN = {
	sparkle = 'rbxasset://textures/particles/sparkles_main.dds', star = 'rbxasset://textures/particles/sparkles_main.dds',
	snow = 'rbxasset://textures/particles/sparkles_main.dds', shard = 'rbxasset://textures/particles/sparkles_main.dds',
	glitter = 'rbxasset://textures/particles/sparkles_main.dds',
	softglow = 'rbxasset://textures/glow.png', glow = 'rbxasset://textures/glow.png', dust = 'rbxasset://textures/glow.png',
	ember = 'rbxasset://textures/glow.png', ray = 'rbxasset://textures/glow.png',
	ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
	bubble = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
}
local function setTexture(e, name)
	if HoodVFX == nil then HoodVFX = sibling('HoodVFX') or false end
	local id = HoodVFX and HoodVFX.Textures and HoodVFX.Textures[name]
	e.Texture = (type(id) == 'string' and id ~= '') and id or BUILTIN[name] or BUILTIN.glow
	e:SetAttribute('PreviewTexture', name)
end
local function nseq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
-- A fade in / hold / fade out transparency at peak opacity `o` (0..1).
local function fade(o, a, b)
	return nseq({ { 0, 1 }, { a or 0.2, 1 - o }, { b or 0.75, 1 - o }, { 1, 1 } })
end
local function emitter(parent, name, tex, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 1
	e.Rotation = NR(0, 360)
	for key, v in props do (e :: any)[key] = v end
	setTexture(e, tex)
	e:SetAttribute('BaseRate', e.Rate)
	e.Parent = parent
	return e
end
local function attach(parent, name, cf)
	local a = Instance.new('Attachment')
	a.Name = name
	a.CFrame = cf -- (CFrame, not Position: the offline preview reads CFrame)
	a.Parent = parent
	return a
end
local function holderPart(size, cf)
	local p = Instance.new('Part')
	p.Name = 'ShoeFX'
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CastShadow = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
-- Pale additive colours stack to white: keep `hot` of the opacity (1 for saturated, less for pale).
local function hot(c)
	return 1 - math.max(0, 0.299 * c.R + 0.587 * c.G + 0.114 * c.B - 0.55)
end
local function trail(parent, name, a0, a1, tier, life, opacity)
	local t = Instance.new('Trail')
	t.Name = name
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = life
	t.MinLength = 0.05
	t.FaceCamera = true
	t.LightEmission = 0.7
	t.LightInfluence = 0
	t.Color = tier.Rank == 6 and rainbowSeq(0) or cseq({ lighten(tier.Color, 0.35), tier.Color })
	t.Transparency = nseq({ { 0, 1 - opacity }, { 1, 1 } })
	t.WidthScale = nseq({ { 0, 1 }, { 1, 0.25 } })
	t.Parent = parent
	return t
end

-- per rank (index 1..6); 0 = layer off
local R = {
	glint = { 0, 1.0, 1.2, 1.4, 1.6, 2.0 },
	glintSize = { 0, 0.5, 0.55, 0.6, 0.65, 0.7 },
	glow = { 0, 0, 0.38, 0.45, 0.55, 0.58 }, -- peak opacity of the halo behind the pair
	glowSize = { 0, 0, 2.6, 3.0, 3.4, 3.8 },
	sparkle = { 0, 0, 2.5, 4, 5, 6 },
	ground = { 0, 0, 0, 0.5, 0.62, 0.62 }, -- peak opacity of the pool of light on the floor
	wornGlow = { 0, 0, 0.45, 0.6, 0.72, 0.72 }, -- worn: the pool's peak opacity round each foot
	motes = { 0, 0, 0, 4, 6, 7 },
	light = { 0, 0, 0, 0.6, 0.8, 0.9 },
	trail = { 0, 0, 0, 0.25, 0.3, 0.38 }, -- Trail lifetime (s): at walk speed 16 a 4 to 6 stud streak
	theme = { 0, 0, 0, 0, 4, 5 },
}

-- A ring of n glowing rainbow beads (parts named ShoeFX) round `centre` (a CFrame, ring in its XZ plane), welded to
-- `body` (or anchored with it): the Secret halo.
local function beadRing(body, centre, radius, n, d)
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi
		local bead = holderPart(V(d, d, d), centre * CF(math.cos(a) * radius, 0, math.sin(a) * radius))
		bead.Shape = Enum.PartType.Ball
		bead.Transparency = 0
		bead.Material = Enum.Material.Neon
		bead.Color = RAINBOW[(i - 1) % #RAINBOW + 1]
		bead.Anchored = body.Anchored
		if not body.Anchored then
			local w = Instance.new('WeldConstraint')
			w.Part0 = body
			w.Part1 = bead
			w.Parent = bead
		end
		bead.Parent = body
	end
end

---------------------------------------------------------------------------------------------- pairs (followers, displays)
local function pairFx(model, tier, theme, opts, low)
	local r = tier.Rank
	local root = model:IsA('Model') and model.PrimaryPart or (model:IsA('BasePart') and model) or nil
	local k = opts.scale or model:GetAttribute('Scale') or 1
	local isPair = model:IsA('Model') and model:FindFirstChild('Root') ~= nil
	-- the ground point under the shoe(s): a pair's Root is on the ground; a single shoe's Fit is 0.15 above it
	local base = (root and root.CFrame or CFrame.identity) * CF(0, isPair and 0 or -0.15 * k, 0)
	local W, H, D = (isPair and 2.7 or 1.35) * k, 1.45 * k, 1.75 * k
	local body = holderPart(V(W, H, D), base * CF(0, H / 2, -0.15 * k))
	body.Anchored = root == nil or root.Anchored
	if root and not root.Anchored then
		local w = Instance.new('WeldConstraint')
		w.Part0 = root
		w.Part1 = body
		w.Parent = body
	end
	local dens = math.clamp(opts.density or 1, 0, 1) * (low and 0.4 or 1)
	local secret = r >= 6
	local col, acc = tier.Color, tier.Accent
	local glowSeq = secret and rainbowSeq(0) or cseq({ lighten(col, 0.2), col }) -- (deep: purple, orange and red stay apart)
	local themeSeq = secret and rainbowSeq(2) or cseq(theme.colors)
	local floor = attach(body, 'Floor', CF(0, -H / 2 + 0.05 * k, 0))
	local core = attach(body, 'Core', CF(0, 0.05 * k, 0.1 * k))

	-- Rare+: the glint, a white star that twinkles on the shoes (in front of them)
	if r >= 2 and not (low and r >= 3) then
		emitter(body, 'Glint', 'sparkle', {
			Rate = R.glint[r] * dens, Lifetime = NR(0.3, 0.5), Speed = NR(0), RotSpeed = NR(-60, 60),
			Size = nseq({ { 0, 0 }, { 0.45, R.glintSize[r] * k, 0.1 * k }, { 1, 0 } }),
			Transparency = nseq({ { 0, 0.1 }, { 1, 0.3 } }), Color = ColorSequence.new(secret and C(255, 250, 225) or C(255, 255, 255)),
			Brightness = 2, ZOffset = 1.2,
		})
	end
	-- Epic+: the soft glow behind the pair, in the rarity colour
	if r >= 3 then
		local o = R.glow[r] * hot(secret and C(255, 255, 255) or col)
		emitter(core, 'Glow', 'softglow', {
			Rate = 0.9, Lifetime = NR(2), Speed = NR(0), Rotation = NR(0),
			Size = nseq({ { 0, R.glowSize[r] * k * 0.92 }, { 1, R.glowSize[r] * k } }),
			Transparency = fade(o, 0.35, 0.65), Color = glowSeq, ZOffset = -1.5,
			LightEmission = 0.7, -- (keeps the rarity's hue on a pale backdrop; fully additive it turns pastel)
		})
	end
	-- Epic+: sparkles drifting up off the shoes, in the theme colours
	if r >= 3 and not (low and r ~= 3) then
		emitter(body, 'Sparkles', 'sparkle', {
			Rate = R.sparkle[r] * dens, Lifetime = NR(0.9, 1.5), Speed = NR(0.4, 1.0), SpreadAngle = Vector2.new(30, 30),
			Acceleration = V(0, 0.6, 0), Drag = 0.8, RotSpeed = NR(-90, 90), EmissionDirection = Enum.NormalId.Top,
			Size = nseq({ { 0, 0 }, { 0.25, 0.36 * k, 0.1 * k }, { 0.8, 0.26 * k }, { 1, 0 } }),
			Transparency = nseq({ { 0, 1 }, { 0.15, 0 }, { 0.8, 0.15 }, { 1, 1 } }), Color = themeSeq, Brightness = 1.6, ZOffset = 1,
		})
	end
	if r >= 4 then
		-- Legendary+: the aura: a pool of the rarity colour on the floor and motes rising through the pair
		local o = R.ground[r] * hot(secret and C(255, 255, 255) or col)
		emitter(floor, 'Ground', 'softglow', {
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
			Rate = 0.7, Lifetime = NR(2.4), Rotation = NR(0),
			Size = nseq({ { 0, W * 1.15 }, { 1, W * 1.3 } }), Transparency = fade(o, 0.3, 0.7), Color = glowSeq,
			LightEmission = 0.35, -- (tints a pale floor; fully additive it washes out to white in daylight)
		})
		if not (low and r == 4) then
			local s = 0.2 * k
			-- (from the holder's box: an emitter on an attachment spawns at one point)
			emitter(body, 'Motes', 'dust', {
				Rate = R.motes[r] * dens, Lifetime = NR(1.4, 2.2), Speed = NR(0.8, 1.6), SpreadAngle = Vector2.new(12, 12),
				Acceleration = V(0, 0.8, 0), Drag = 0.4, EmissionDirection = Enum.NormalId.Top,
				Size = nseq({ { 0, 0 }, { 0.2, s, s * 0.3 }, { 0.8, s * 0.7 }, { 1, 0 } }),
				Transparency = nseq({ { 0, 1 }, { 0.2, 0.1 }, { 0.75, 0.3 }, { 1, 1 } }), Color = glowSeq, LightEmission = 0.9, ZOffset = 0.5,
			})
		end
		-- the Trail, from the back of the pair: a streak of the rarity colour when it moves (still: nothing)
		local back = D / 2 - 0.05 * k
		local a0 = attach(body, 'TrailLow', CF(0, -H / 2 + 0.2 * k, back))
		local a1 = attach(body, 'TrailHigh', CF(0, -H / 2 + 0.85 * k, back))
		trail(body, 'Trail', a0, a1, tier, R.trail[r], 0.45)
		if not low then
			local l = Instance.new('PointLight')
			l.Name = 'Light'
			l.Color = secret and C(255, 240, 200) or col
			-- a soft pool, not a floodlight (LIGHT2: pale floors wash out under bright lights)
			l.Brightness = R.light[r]
			l.Range = (5 + (r - 4) * 0.6) * k
			l.Shadows = false
			l.Parent = body
		end
	end
	if r >= 5 then
		-- Mythic+: the strong aura: light shafts rising behind, a ring rolling out on the floor, themed particles
		if not low then
			emitter(floor, 'Shafts', 'ray', {
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1.4, Lifetime = NR(1.8, 2.6), Speed = NR(0.05),
				Rotation = NR(0), EmissionDirection = Enum.NormalId.Top,
				Size = nseq({ { 0, 2.9 * k, 0.3 * k }, { 1, 3.4 * k, 0.3 * k } }),
				Transparency = fade(0.5 * hot(secret and C(255, 255, 255) or acc), 0.35, 0.65),
				Color = secret and rainbowSeq(1) or cseq({ C(255, 255, 255), col }), ZOffset = -1,
			})
			emitter(floor, 'Ring', 'ring', {
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
				Rate = 0.6, Lifetime = NR(1.8), Rotation = NR(0),
				Size = nseq({ { 0, 0.8 * k }, { 1, W * 1.35 } }), Transparency = nseq({ { 0, 1 }, { 0.15, 0.25 }, { 1, 1 } }),
				Color = glowSeq,
			})
			emitter(body, 'Theme', theme.tex, {
				Rate = R.theme[r] * dens, Lifetime = NR(1.3, 2.1), Speed = NR(0.6, 1.4), SpreadAngle = Vector2.new(25, 25),
				Acceleration = V(0, theme.tex == 'snow' and -0.3 or 0.6, 0), Drag = 0.6, RotSpeed = NR(-60, 60),
				EmissionDirection = Enum.NormalId.Top,
				Size = nseq({ { 0, 0 }, { 0.2, 0.42 * k, 0.12 * k }, { 0.8, 0.34 * k }, { 1, 0 } }),
				Transparency = nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.75, 0.2 }, { 1, 1 } }), Color = themeSeq,
				LightEmission = (theme.tex == 'bubble' or theme.tex == 'snow') and 0.4 or 0.9, Brightness = 1.3, ZOffset = 0.8,
			})
		end
	end
	if secret then
		-- Secret: a rainbow halo floating over the pair: a ring of glowing beads, one per rainbow colour (parts named
		-- ShoeFX, welded like the holder), and a soft ring of light behind them whose colour cycles as it lives
		local hy = H / 2 + 0.5 * k
		local top = attach(body, 'Halo', CF(0, hy, -0.05 * k))
		emitter(top, 'Halo', 'ring', {
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
			Rate = 0.9, Lifetime = NR(2.2), Rotation = NR(0), RotSpeed = NR(0),
			Size = nseq({ { 0, 1.5 * k }, { 1, 1.65 * k } }), Transparency = fade(0.7, 0.2, 0.75),
			Color = rainbowSeq(0), LightEmission = 0.8,
		})
		beadRing(body, body.CFrame * CF(0, hy, -0.05 * k), 0.62 * k, 12, 0.17 * k)
	end
	body.Parent = model
	return body
end

---------------------------------------------------------------------------------------------- worn (per foot)
local function wornFx(model, tier, theme, opts, low)
	local r = tier.Rank
	local feet = opts.feet or {}
	local dens = math.clamp(opts.density or 1, 0, 1) * (low and 0.4 or 1)
	local secret = r >= 6
	local col, acc = tier.Color, tier.Accent
	local glowSeq = secret and rainbowSeq(0) or cseq({ lighten(col, 0.2), col }) -- (deep: purple, orange and red stay apart)
	local themeSeq = secret and rainbowSeq(2) or cseq(theme.colors)
	local first
	for i, foot in feet do
		local host = foot.Part
		local f = foot.Scale or V(1, 1, 1)
		local k = (f.X + f.Z) / 2
		local sx = foot.Side == 'L' and -1 or 1
		-- the shoe's box round the foot (foot space: outer side +X on the right shoe, toe -Z)
		local size = V(1.25 * f.X, 1.15 * f.Y, 1.65 * f.Z)
		local c0 = (foot.At or CFrame.identity) * CF(sx * 0.08 * f.X, 0.42 * f.Y, -0.17 * f.Z)
		local body = holderPart(size, host.CFrame * c0)
		body.Anchored = false
		local w = Instance.new('Weld')
		w.Name = 'ShoeFXWeld'
		w.Part0 = host
		w.Part1 = body
		w.C0 = c0
		w.Parent = body
		local h = size.Y
		local floor = attach(body, 'Floor', CF(0, -h / 2 + 0.04 * k, 0))
		if r >= 2 and not (low and r >= 3) then
			emitter(body, 'Glint', 'sparkle', {
				Rate = R.glint[r] * 0.6 * dens, Lifetime = NR(0.3, 0.5), Speed = NR(0), RotSpeed = NR(-60, 60),
				Size = nseq({ { 0, 0 }, { 0.45, R.glintSize[r] * k, 0.1 * k }, { 1, 0 } }),
				Transparency = nseq({ { 0, 0.1 }, { 1, 0.3 } }), Color = ColorSequence.new(C(255, 255, 255)), Brightness = 2, ZOffset = 1,
			})
		end
		if r >= 3 then
			-- Epic+: the soft glow, worn as a pool of the rarity colour on the floor round each foot (it reads from the
			-- follow camera above and behind; a camera-facing halo round the ankles would read as fog)
			local o = R.wornGlow[r] * hot(secret and C(255, 255, 255) or col)
			emitter(floor, 'Ground', 'softglow', {
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
				Rate = 0.5, Lifetime = NR(2.2), Rotation = NR(0),
				Size = nseq({ { 0, (3.0 + 0.25 * r) * k }, { 1, (3.3 + 0.25 * r) * k } }), Transparency = fade(o, 0.3, 0.7), Color = glowSeq,
				LightEmission = 0.35, -- (tints a pale floor; fully additive it washes out to white in daylight)
			})
			if not (low and r ~= 3) then
				emitter(body, 'Sparkles', 'sparkle', {
					Rate = R.sparkle[r] * 0.5 * dens, Lifetime = NR(0.7, 1.2), Speed = NR(0.4, 0.9), SpreadAngle = Vector2.new(30, 30),
					Acceleration = V(0, 0.5, 0), Drag = 0.8, RotSpeed = NR(-90, 90), EmissionDirection = Enum.NormalId.Top,
					Size = nseq({ { 0, 0 }, { 0.25, 0.44 * k, 0.12 * k }, { 0.8, 0.3 * k }, { 1, 0 } }),
					Transparency = nseq({ { 0, 1 }, { 0.15, 0 }, { 0.8, 0.15 }, { 1, 1 } }), Color = themeSeq, Brightness = 1.6, ZOffset = 1,
				})
			end
		end
		if r >= 4 then
			-- the Trail from the heel: a streak in the rarity colour behind each running foot
			local back = 0.8 * f.Z
			local a0 = attach(body, 'TrailLow', CF(-sx * 0.08 * f.X, -h / 2 + 0.12 * k, back))
			local a1 = attach(body, 'TrailHigh', CF(-sx * 0.08 * f.X, -h / 2 + 0.62 * k, back))
			trail(body, 'Trail', a0, a1, tier, R.trail[r], 0.5)
			if not low and i == #feet then
				local l = Instance.new('PointLight')
				l.Name = 'Light'
				l.Color = secret and C(255, 240, 200) or col
				l.Brightness = R.light[r] * 0.75
				l.Range = 4 * k
				l.Shadows = false
				l.Parent = body
			end
		end
		if r >= 4 then
			-- Legendary+: the aura's motes rising round each foot
			emitter(body, 'Motes', 'dust', {
				Rate = R.motes[r] * 0.45 * dens, Lifetime = NR(1.2, 1.9), Speed = NR(0.8, 1.5),
				SpreadAngle = Vector2.new(12, 12), Acceleration = V(0, 0.8, 0), Drag = 0.4, EmissionDirection = Enum.NormalId.Top,
				Size = nseq({ { 0, 0 }, { 0.2, 0.22 * k, 0.06 * k }, { 0.8, 0.15 * k }, { 1, 0 } }),
				Transparency = nseq({ { 0, 1 }, { 0.2, 0.1 }, { 0.75, 0.3 }, { 1, 1 } }), Color = glowSeq, LightEmission = 0.9, ZOffset = 0.5,
			})
			if not low and r >= 5 then
				emitter(body, 'Theme', theme.tex, {
					Rate = R.theme[r] * 0.4 * dens, Lifetime = NR(1.1, 1.8), Speed = NR(0.5, 1.2), SpreadAngle = Vector2.new(25, 25),
					Acceleration = V(0, theme.tex == 'snow' and -0.3 or 0.6, 0), Drag = 0.6, RotSpeed = NR(-60, 60),
					EmissionDirection = Enum.NormalId.Top,
					Size = nseq({ { 0, 0 }, { 0.2, 0.32 * k, 0.08 * k }, { 0.8, 0.26 * k }, { 1, 0 } }),
					Transparency = nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.75, 0.2 }, { 1, 1 } }), Color = themeSeq,
					LightEmission = (theme.tex == 'bubble' or theme.tex == 'snow') and 0.4 or 0.9, Brightness = 1.3, ZOffset = 0.8,
				})
			end
		end
		if r >= 5 and not low then
			-- Mythic+: the strong aura: a light shaft rising round each foot and a ring rolling out under it
			emitter(floor, 'Shafts', 'ray', {
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 0.7, Lifetime = NR(1.6, 2.2), Speed = NR(0.05),
				Rotation = NR(0), EmissionDirection = Enum.NormalId.Top,
				Size = nseq({ { 0, 2.0 * k, 0.2 * k }, { 1, 2.4 * k, 0.2 * k } }),
				Transparency = fade(0.5 * hot(secret and C(255, 255, 255) or acc), 0.35, 0.65),
				Color = secret and rainbowSeq(1) or cseq({ C(255, 255, 255), col }), ZOffset = -0.5,
			})
			emitter(floor, 'Ring', 'ring', {
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
				Rate = 0.45, Lifetime = NR(1.6), Rotation = NR(0),
				Size = nseq({ { 0, 0.6 * k }, { 1, 2.4 * k } }), Transparency = nseq({ { 0, 1 }, { 0.15, 0.3 }, { 1, 1 } }),
				Color = secret and rainbowSeq(3) or glowSeq,
			})
		end
		if secret then
			-- Secret: a rainbow halo round each ankle: glowing beads and a ring of light (its colour cycling as it lives)
			beadRing(body, body.CFrame * CF(-sx * 0.08 * f.X, h / 2 + 0.06 * k, 0.17 * f.Z), 0.86 * k, 8, 0.15 * k)
			local ankle = attach(body, 'Halo', CF(-sx * 0.08 * f.X, h / 2 + 0.05 * k, 0.17 * f.Z))
			emitter(ankle, 'Halo', 'ring', {
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Speed = NR(0.01),
				Rate = 0.6, Lifetime = NR(2.2), Rotation = NR(0),
				Size = nseq({ { 0, 1.7 * k }, { 1, 1.8 * k } }), Transparency = fade(0.8, 0.2, 0.75), Color = rainbowSeq(0), Brightness = 1.6,
			})
		end
		body.Parent = model
		first = first or body
	end
	return first
end

---------------------------------------------------------------------------------------------- the API
local function themeFor(id)
	local shoe = Config and Config.ById and type(id) == 'string' and Config.ById[id]
	return shoe and ShoeFX.Themes[shoe.Box] or ShoeFX.Themes.Street
end

function ShoeFX.apply(model: Instance, rarity: any, opts: { [string]: any }?): BasePart?
	local o = opts or {}
	local tier = ShoeFX.tier(rarity)
	if tier.Rank < 2 or not model then return nil end
	local low = (o.quality or ShoeFX.quality()) == 'low'
	local theme = o.theme or themeFor(o.id or model:GetAttribute('ShoeId'))
	if o.context == 'worn' then return wornFx(model, tier, theme, o, low) end
	return pairFx(model, tier, theme, o, low)
end

-- Switch every effect under `container` on or off (distance LOD). Writes only when the value changes.
function ShoeFX.setEnabled(container: Instance, on: boolean)
	for _, d in container:GetDescendants() do
		if (d:IsA('ParticleEmitter') or d:IsA('Trail') or d:IsA('Light')) and d.Enabled ~= on then d.Enabled = on end
	end
end

-- Scale every emitter's rate under `container` to k (0..1) of the rate it was built with (BaseRate).
function ShoeFX.setDensity(container: Instance, k: number)
	for _, d in container:GetDescendants() do
		if d:IsA('ParticleEmitter') then
			local base = d:GetAttribute('BaseRate')
			if type(base) ~= 'number' then
				base = d.Rate
				d:SetAttribute('BaseRate', base)
			end
			local rate = base * math.clamp(k, 0, 1)
			if d.Rate ~= rate then d.Rate = rate end
		end
	end
end

return ShoeFX
