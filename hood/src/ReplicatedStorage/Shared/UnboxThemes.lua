-- UnboxThemes (brief 27, REVEAL): the theme kit of the box-opening cinematic (Shared/UnboxCinematic), one entry per
-- box look. Pure data, nothing here makes an Instance. Each box has its own SIGNATURE moments (ANIMLAB's unbox_beats §7)
-- that change the SHAPE of a beat, not just its hue: lamps flicker on, paint crowns the floor, frost creeps, magma
-- cracks, slime splashes, jelly lands, a wave rolls out, light splits into a rainbow, night falls through a warp ring,
-- coins fountain; the Robux boxes own the whole premium sheet (crystal shatter; dawn, wings and a halo).
--
--   UnboxThemes.get(boxId) -> theme        (unknown ids get Street's)
--   UnboxThemes.Ids                         the 12 box looks, cash boxes first
--   UnboxThemes.tierOf(boxId)               1..10 for the cash boxes (price order), 11/12 for the Robux boxes
--   UnboxThemes.strength(boxId, tier)       0..1: how much theme a box shows (Robux boxes and premium: 1)
--   UnboxThemes.Rarity[rank]                the rarity ladder (both tiers): one new channel per rank
--
-- A theme:
--   Color, Accent, Third, Rim     main, accent and third colours; the stage's neon (pad lip, sign, speaker rings)
--   Deep, Relit                   the premium night's sky colour; the relit stage's colour after the flash
--   Debris                        the slam's chunks: { colors, kind, material }
--   Land, Open                    signature names played at the landing and at the pop (UnboxCinematic.Sig)
--   Arrive, Charge, Dip           premium only: signatures at the comet, during the charge, in the dark beat
--   Ambient                       P13 emitter recipes while the stage is up ({ tex, rate, colors, life, size, speed,
--                                 grav (studs/s^2 down; negative rises), where = back | sky | floor | around })
--   Deluxe                        cash tiers 7-10: the look's tint { tint, atm, decay, haze, clock, stars, ambient }
--   Night, Lit                    premium: NightTakeover and StageLit overrides { ambient, atm, decay, clock, ... }
--   Rings                         the premium charge rings' colours (ring 1 also shows the honest rarity tease)
--   Neon                          the Secret's two saturated ring colours (its charge and the rings before the reveal)
--   Tags, Wall, Poster, Hold      the reveal's backdrop: poster words, wall colour, poster style, the hold layer
local UnboxThemes = {}

local C = Color3.fromRGB
local WHITE = C(255, 255, 255)

UnboxThemes.Ids = { 'Street', 'Graffiti', 'Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold', 'Exclusive', 'Grail' }
UnboxThemes.Rainbow = { C(255, 82, 82), C(255, 170, 40), C(255, 236, 70), C(80, 220, 110), C(60, 170, 255), C(170, 90, 255) }

local function amb(tex, rate, colors, o)
	local r = { tex = tex, rate = rate, colors = colors }
	for k, v in o or {} do r[k] = v end
	return r
end

local T = {}
-- Cash boxes ---------------------------------------------------------------------------------------------------
T.Street = {
	Color = C(222, 56, 48), Accent = C(255, 132, 116), Third = C(250, 250, 252), Rim = C(255, 84, 70),
	Deep = C(36, 16, 26), Relit = C(255, 120, 90),
	Debris = { colors = { C(70, 70, 82), C(222, 56, 48), C(150, 150, 160) }, kind = 'cube' },
	-- the block at night, a fresh drop: the street lamps flicker on as it hits, a spray-paint puff ring scuffs out;
	-- the lid pops with a spray-can burst and a fresh "+1" tag hits the pad
	Land = { 'lampsOn', 'sprayRing' }, Open = { 'sprayBurst', 'tag' },
	Ambient = {},
}
T.Graffiti = {
	Color = C(250, 120, 180), Accent = C(80, 240, 230), Third = C(255, 200, 50), Rim = C(255, 110, 190),
	Deep = C(40, 16, 48), Relit = C(255, 140, 200),
	Debris = { colors = { C(250, 120, 180), C(80, 240, 230), C(130, 230, 80), C(255, 200, 50) }, kind = 'cube' },
	-- the slam paints the floor: a crown of paint splats; the pop: a rainbow mist and drips down the box
	Land = { 'paintCrown' }, Open = { 'mist', 'drips' },
	Ambient = {},
}
T.Frost = {
	Color = C(60, 150, 230), Accent = C(170, 222, 255), Third = WHITE, Rim = C(130, 210, 255),
	Deep = C(10, 24, 56), Relit = C(140, 210, 255),
	Debris = { colors = { C(200, 235, 255), C(150, 205, 250), C(240, 250, 255) }, kind = 'shard', material = 'Glass' },
	-- the floor freezes (frost creeps across the pad), the lid shatters into ice shards
	Land = { 'frostCreep' }, Open = { 'lidShatter', 'snowPuff' },
	Ambient = {},
}
T.Lava = {
	Color = C(255, 120, 40), Accent = C(255, 170, 110), Third = C(255, 210, 90), Rim = C(255, 110, 30),
	Deep = C(40, 10, 6), Relit = C(255, 140, 60),
	Debris = { colors = { C(48, 30, 30), C(70, 44, 38), C(36, 24, 24) }, kind = 'rock' },
	-- the pad cracks open with lava light; the lid launches on a fire geyser (magma orange, never blood red)
	Land = { 'magma' }, Open = { 'geyser' },
	Ambient = { amb('glow', 5, { C(255, 210, 90), C(255, 120, 40) }, { life = { 1, 1.6 }, size = { 0.18, 0.4 }, speed = { 3, 6 }, grav = -4, where = 'floor', emission = 1 }) },
}
T.Toxic = {
	Color = C(110, 214, 70), Accent = C(196, 250, 160), Third = C(84, 70, 190), Rim = C(120, 230, 70),
	Deep = C(14, 30, 12), Relit = C(150, 255, 110),
	Debris = { colors = { C(110, 214, 70), C(84, 70, 190), C(40, 50, 40) }, kind = 'cube' },
	-- a slime splash on landing, a bubble that inflates and pops it open
	Land = { 'slimeCrown' }, Open = { 'bubblePop' },
	Ambient = {
		amb('spark', 4, { C(200, 255, 160), C(140, 240, 100) }, { life = { 1.6, 2.4 }, size = { 0.3, 0.6 }, speed = { 1.5, 3 }, grav = -0.6, where = 'floor', emission = 0.5 }),
		amb('smoke', 1.2, { C(150, 230, 110), C(90, 170, 70) }, { life = { 2.4, 3.2 }, size = { 2.5, 5 }, speed = { 0.4, 0.9 }, where = 'floor', emission = 0.2, transparency = 0.7 }),
	},
}
T.Candy = {
	Color = C(250, 140, 180), Accent = C(200, 190, 255), Third = C(120, 220, 190), Rim = C(255, 150, 200),
	Deep = C(46, 20, 44), Relit = C(255, 170, 210),
	Debris = { colors = { C(255, 160, 200), C(200, 190, 255), C(255, 230, 90), C(120, 220, 190) }, kind = 'candy' },
	-- a jelly landing (2-3 jiggles), a sweets fountain, sprinkles raining through the hold
	Land = { 'jelly' }, Open = { 'sweets' },
	Ambient = { amb('spark', 4, { C(255, 140, 190), C(200, 190, 255), C(255, 230, 90), C(120, 220, 190) }, { life = { 1.6, 2.4 }, size = { 0.3, 0.5 }, speed = { 0.5, 1 }, grav = 1.5, where = 'sky', emission = 0.3, rods = true }) },
}
T.Ocean = {
	Color = C(30, 140, 190), Accent = C(150, 232, 222), Third = WHITE, Rim = C(80, 214, 230),
	Deep = C(6, 24, 46), Relit = C(110, 220, 240),
	Debris = { colors = { C(30, 140, 190), C(150, 232, 222), C(240, 250, 255) }, kind = 'cube' },
	-- the wave rolls out, the spout lifts the shoe
	Land = { 'wave' }, Open = { 'spout' },
	Ambient = { amb('ring', 2.5, { C(210, 245, 255), C(140, 220, 240) }, { life = { 2, 3 }, size = { 0.3, 0.7 }, speed = { 1.2, 2.2 }, grav = -0.8, where = 'floor', emission = 0.4, bubbles = true }) },
	Deluxe = { tint = C(225, 245, 255), atm = C(120, 200, 230), decay = C(60, 120, 170), haze = 1.0 },
}
T.Gem = {
	Color = C(40, 190, 100), Accent = C(250, 200, 70), Third = C(200, 255, 230), Rim = C(70, 230, 140),
	Deep = C(6, 30, 20), Relit = C(110, 240, 170),
	Debris = { colors = { C(60, 220, 130), C(250, 200, 70), C(200, 255, 230) }, kind = 'shard', material = 'Glass' },
	-- the lid opening splits light into a rainbow; a crystal clink ring on landing
	Land = { 'clink' }, Open = { 'prism' },
	Ambient = { amb('spark', 3, { C(200, 255, 220), C(255, 236, 150) }, { life = { 0.8, 1.4 }, size = { 0.3, 0.6 }, speed = { 0.2, 0.6 }, where = 'around', emission = 1 }) },
	Deluxe = { tint = C(235, 255, 240), atm = C(150, 230, 190), decay = C(60, 150, 110), haze = 0.8 },
}
T.Galaxy = {
	Color = C(130, 110, 240), Accent = C(214, 204, 255), Third = C(255, 120, 200), Rim = C(160, 130, 255),
	Deep = C(10, 8, 34), Relit = C(150, 120, 255),
	Debris = { colors = { C(40, 36, 100), C(130, 110, 240), C(214, 204, 255) }, kind = 'cube' },
	-- (the user's own example) night falls during the drop, the box drops out of a warp ring, a nebula turns under it,
	-- hyperspace on the open
	Arrive = { 'nightfall', 'warpDrop' }, Land = { 'starBurst' }, Open = { 'hyperspace' },
	Ambient = {
		amb('smoke', 1.5, { C(150, 90, 240), C(255, 120, 200), C(90, 120, 240) }, { life = { 2.6, 3.4 }, size = { 6, 10 }, speed = { 0.05, 0.2 }, where = 'floor', emission = 0.6, transparency = 0.55, nebula = true }),
		amb('spark', 6, { WHITE, C(214, 204, 255), C(170, 220, 255) }, { life = { 1.2, 2 }, size = { 0.3, 0.6 }, speed = { 0.05, 0.2 }, where = 'sky', emission = 1 }),
	},
	Deluxe = { tint = C(220, 214, 255), atm = C(90, 60, 180), decay = C(40, 20, 90), haze = 1.2, clock = 24, stars = 3000, ambient = C(110, 100, 160), night = true },
}
T.Gold = {
	Color = C(250, 186, 40), Accent = C(255, 220, 150), Third = WHITE, Rim = C(255, 196, 60),
	Deep = C(36, 22, 6), Relit = C(255, 200, 90),
	Debris = { colors = { C(255, 200, 60), C(230, 150, 30), C(255, 230, 150) }, kind = 'coin' },
	-- a jackpot coin fountain in golden-hour light, golden rays behind the shoe
	Land = { 'goldDust' }, Open = { 'coinFountain' },
	Ambient = { amb('spark', 4, { C(255, 236, 160), WHITE }, { life = { 1, 1.8 }, size = { 0.3, 0.6 }, speed = { 0.2, 0.6 }, where = 'around', emission = 1 }) },
	Deluxe = { tint = C(255, 240, 215), atm = C(255, 200, 150), decay = C(200, 120, 90), haze = 1.4, clock = 17.6 },
}
-- Robux boxes (premium: the full kit in every phase) ---------------------------------------------------------------
T.Exclusive = {
	Color = C(70, 200, 255), Accent = C(190, 240, 255), Third = C(255, 120, 220), Rim = C(80, 220, 255),
	Deep = C(4, 14, 34), Relit = C(110, 220, 255),
	Debris = { colors = { C(180, 240, 255), C(90, 200, 255), C(240, 250, 255) }, kind = 'shard', material = 'Glass' },
	Rings = { C(70, 200, 255), C(255, 120, 220), WHITE },
	-- diamond / crystal chrome: a diamond-glint comet, prism crystals orbiting through the charge, a crystal shell that
	-- forms in the dark and SHATTERS under the flash, a cyan prism fan from the lid
	Arrive = { 'diamondComet' }, Land = { 'shardRing' }, Charge = { 'crystals' }, Dip = { 'shell' }, Open = { 'shatter', 'prismFan' },
	Ambient = {
		amb('spark', 7, { WHITE, C(170, 235, 255), C(255, 170, 235) }, { life = { 1.2, 2 }, size = { 0.3, 0.7 }, speed = { 0.1, 0.4 }, where = 'sky', emission = 1 }),
		amb('glow', 1.6, { C(90, 210, 255), C(200, 120, 255) }, { life = { 2.4, 3.2 }, size = { 6, 10 }, speed = { 0.1, 0.3 }, where = 'back', transparency = 0.82, emission = 1 }),
	},
	Night = { ambient = C(60, 90, 130), atm = C(60, 140, 200), decay = C(20, 40, 90) },
	Lit = { ambient = C(190, 220, 240), atm = C(150, 220, 255), decay = C(60, 120, 200), tint = C(240, 250, 255) },
}
T.Grail = {
	Color = C(170, 80, 255), Accent = C(255, 210, 80), Third = WHITE, Rim = C(255, 206, 80),
	Deep = C(24, 8, 44), Relit = C(255, 210, 120),
	Debris = { colors = { C(255, 206, 70), C(170, 80, 255), C(250, 250, 255) }, kind = 'cube', material = 'Foil' },
	Rings = { C(255, 210, 80), C(170, 80, 255), WHITE },
	-- heavenly: a gold beam marks the pad, a golden comet descends through it, golden motes fall like feathers through
	-- the charge, DAWN breaks under the flash, wings unfold, a halo lands on the shoe
	Arrive = { 'heavenBeam' }, Land = { 'featherBurst' }, Charge = { 'goldMotes' }, Open = { 'wings', 'heavenRays' },
	Ambient = {
		amb('spark', 6, { C(255, 236, 170), WHITE, C(220, 180, 255) }, { life = { 1.4, 2.2 }, size = { 0.3, 0.7 }, speed = { 0.1, 0.4 }, grav = 0.6, where = 'sky', emission = 1 }),
		amb('glow', 1.6, { C(255, 200, 90), C(180, 100, 255) }, { life = { 2.4, 3.2 }, size = { 6, 10 }, speed = { 0.1, 0.3 }, where = 'back', transparency = 0.82, emission = 1 }),
	},
	Night = { ambient = C(70, 50, 120), atm = C(120, 70, 200), decay = C(40, 20, 80) },
	Lit = { ambient = C(220, 196, 170), atm = C(255, 214, 160), decay = C(180, 110, 200), tint = C(255, 246, 230), clock = 6.4, dawn = true },
}

-- The reveal keeps the box's theme on screen (CRITIC5 r1 fix 2): the two wall posters' words and colours, a HOLD layer
-- behind the pair through the hold (`Hold`: an emitter recipe like Ambient's, on a sheet just behind the pair), the
-- posters' style (`Poster`: 'paint' | 'glass' | 'gold') and the wall's tint. Words are short and kid-safe.
local HOLD = {
	Street = { Tags = { 'HOOD', 'KICKS' }, Wall = C(104, 78, 82),
		Hold = amb('smoke', 5, { C(255, 90, 80), WHITE }, { life = { 1.4, 2 }, size = { 0.8, 1.8 }, speed = { 0.4, 1 }, grav = -0.6, emission = 0.1, transparency = 0.45 }) },
	Graffiti = { Tags = { 'FRESH', 'PAINT' }, Wall = C(96, 70, 92),
		Hold = amb('glow', 10, { C(250, 120, 180), C(80, 240, 230), C(255, 200, 50), C(130, 230, 80) }, { life = { 1.2, 1.8 }, size = { 0.3, 0.55 }, speed = { 0.5, 1.5 }, grav = 7, emission = 0.4 }) },
	Frost = { Tags = { 'CHILL', 'ICE' }, Wall = C(84, 92, 112),
		Hold = amb('spark', 14, { WHITE, C(200, 235, 255) }, { life = { 1.8, 2.4 }, size = { 0.25, 0.5 }, speed = { 0.5, 1 }, grav = 2, emission = 0.6 }) },
	Lava = { Tags = { 'HOT!', 'MAGMA' }, Wall = C(92, 56, 50),
		Hold = amb('glow', 12, { C(255, 220, 110), C(255, 120, 40) }, { life = { 1.2, 1.8 }, size = { 0.22, 0.45 }, speed = { 2, 4 }, grav = -3, emission = 1 }) },
	Toxic = { Tags = { 'SLIME', 'GOO' }, Wall = C(70, 84, 66),
		Hold = amb('ring', 7, { C(200, 255, 160), C(120, 230, 80) }, { life = { 1.6, 2.4 }, size = { 0.35, 0.8 }, speed = { 1, 2 }, grav = -1, emission = 0.5, bubbles = true }) },
	Candy = { Tags = { 'SWEET', 'YUM!' }, Wall = C(112, 80, 100),
		Hold = amb('spark', 12, { C(255, 140, 190), C(200, 190, 255), C(255, 230, 90), C(120, 220, 190) }, { life = { 1.6, 2.2 }, size = { 0.3, 0.5 }, speed = { 1, 2 }, grav = 3, emission = 0.3, rods = true }) },
	Ocean = { Tags = { 'SURF', 'WAVE' }, Wall = C(66, 86, 104),
		Hold = amb('ring', 8, { C(220, 250, 255), C(140, 220, 240) }, { life = { 1.6, 2.4 }, size = { 0.3, 0.8 }, speed = { 1.2, 2.2 }, grav = -1, emission = 0.5, bubbles = true }) },
	Gem = { Tags = { 'SHINE', 'GEMS' }, Wall = C(72, 92, 82),
		Hold = amb('spark', 10, { C(200, 255, 220), C(255, 236, 150), WHITE }, { life = { 0.6, 1.1 }, size = { 0.5, 0.9 }, speed = { 0.1, 0.3 }, emission = 1 }) },
	Galaxy = { Tags = { 'COSMIC', 'STARS' }, Wall = C(70, 62, 104),
		Hold = amb('spark', 12, { WHITE, C(214, 204, 255), C(255, 150, 210) }, { life = { 0.8, 1.4 }, size = { 0.3, 0.6 }, speed = { 0.1, 0.4 }, emission = 1 }) },
	Gold = { Tags = { 'BLING', 'GOLD' }, Wall = C(110, 82, 62), Poster = 'gold',
		Hold = amb('spark', 12, { C(255, 226, 120), C(255, 190, 60) }, { life = { 1.4, 2 }, size = { 0.3, 0.55 }, speed = { 0.3, 0.8 }, grav = 2.5, emission = 1 }) },
	Exclusive = { Tags = { 'VIP', 'ICE' }, Wall = C(44, 52, 72), Poster = 'glass',
		Hold = amb('spark', 12, { C(150, 240, 255), C(255, 150, 230), WHITE }, { life = { 0.8, 1.4 }, size = { 0.3, 0.6 }, speed = { 0.3, 0.8 }, grav = -0.5, emission = 1 }) },
	Grail = { Tags = { 'GLORY', 'GRAIL' }, Wall = C(96, 70, 110), Poster = 'gold',
		Hold = amb('glow', 9, { C(255, 236, 170), C(255, 200, 80) }, { life = { 2, 2.6 }, size = { 0.3, 0.5 }, speed = { 0.5, 1 }, grav = 1.2, emission = 1 }) },
}
for id, h in HOLD do
	for k, v in h do T[id][k] = v end
end
-- The Secret's neon rings: two saturated colours per look (CRITIC5: S >= 0.7, never pastel; the reference's magenta
-- and red over a blue sky)
local NEON = {
	Street = { C(255, 30, 60), C(255, 40, 200) }, Graffiti = { C(255, 40, 170), C(0, 215, 230) },
	Frost = { C(0, 170, 255), C(60, 80, 255) }, Lava = { C(255, 110, 0), C(255, 30, 40) },
	Toxic = { C(90, 230, 30), C(130, 60, 255) }, Candy = { C(255, 60, 170), C(140, 60, 255) },
	Ocean = { C(0, 200, 230), C(30, 100, 255) }, Gem = { C(0, 210, 110), C(255, 190, 0) },
	Galaxy = { C(150, 60, 255), C(0, 215, 255) }, Gold = { C(255, 190, 0), C(255, 100, 0) },
	Exclusive = { C(0, 200, 255), C(255, 50, 210) }, Grail = { C(255, 190, 20), C(160, 40, 255) },
}
for id, t in T do
	t.Id = id
	t.Land = t.Land or {}
	t.Open = t.Open or {}
	t.Rings = t.Rings or { t.Color, t.Accent, WHITE }
	t.Neon = t.Neon or NEON[id]
	t.Ambient = t.Ambient or {}
end
UnboxThemes.Themes = T

local TIER = { Street = 1, Graffiti = 2, Frost = 3, Lava = 4, Toxic = 5, Candy = 6, Ocean = 7, Gem = 8, Galaxy = 9, Gold = 10, Exclusive = 11, Grail = 12 }
UnboxThemes.Premium = { Exclusive = true, Grail = true }

function UnboxThemes.get(boxId: string?)
	return T[boxId or ''] or T.Street
end
function UnboxThemes.tierOf(boxId: string?): number
	return TIER[boxId or ''] or 1
end
-- How much of its theme a box shows: Robux boxes all of it; cash tiers 1-3 a landing and a pop touch, 4-6 add an
-- ambient layer, 7-10 (deluxe) add their tint to the look.
function UnboxThemes.strength(boxId: string?, tier: string?): number
	if tier == 'premium' then return 1 end
	local n = TIER[boxId or ''] or 1
	if n > 10 then return 0.9 end
	return 0.45 + 0.5 * (n - 1) / 9
end

-- The rarity ladder: one new channel per rank (unbox_beats §4, CRITIC5 §7).
--   Sparks     sparkles in the reveal accent       Ring    a small ring at the accent (radius, studs)
--   Rays       god rays behind the pair             Comets  orbiting comets round the pair
--   Confetti   confetti pieces (two cannons)        Rain    extra confetti from above
--   Pillar     a light pillar through the pair      Edge    the screen's edges glow in the rarity colour
--   Double     a double shockwave at the accent     Halo    a halo descends onto the pair
--   SlowMo     the "false calm" slow-mo beat        Flash2  a second white flash (>= 1 s after the first)
--   Shake      trauma at the accent; HitStop        Hold    extra seconds on the read hold (normal tier)
--   MiniFlash  a soft 0.35 flash at the pop (normal tier)
UnboxThemes.Rarity = {
	{ Sparks = 6, Ring = 0, Rays = 0, Comets = 0, Confetti = 0, Rain = 0, Pillar = false, Edge = false, Double = false, Halo = false, SlowMo = false, Flash2 = false, Shake = 0, HitStop = 0, Hold = 0, MiniFlash = false },
	{ Sparks = 10, Ring = 4, Rays = 0, Comets = 0, Confetti = 0, Rain = 0, Pillar = false, Edge = false, Double = false, Halo = false, SlowMo = false, Flash2 = false, Shake = 0.15, HitStop = 0, Hold = 0.1, MiniFlash = true },
	{ Sparks = 12, Ring = 5, Rays = 6, Comets = 0, Confetti = 0, Rain = 0, Pillar = false, Edge = false, Double = false, Halo = false, SlowMo = false, Flash2 = false, Shake = 0.25, HitStop = 0.04, Hold = 0.4, MiniFlash = true },
	{ Sparks = 16, Ring = 6, Rays = 10, Comets = 2, Confetti = 48, Rain = 0, Pillar = false, Edge = false, Double = false, Halo = false, SlowMo = false, Flash2 = false, Shake = 0.45, HitStop = 0.06, Hold = 0.8, MiniFlash = true },
	{ Sparks = 20, Ring = 8, Rays = 14, Comets = 2, Confetti = 48, Rain = 20, Pillar = true, Edge = true, Double = true, Halo = false, SlowMo = false, Flash2 = false, Shake = 0.7, HitStop = 0.09, Hold = 1.2, MiniFlash = true },
	{ Sparks = 24, Ring = 10, Rays = 16, Comets = 2, Confetti = 48, Rain = 20, Pillar = true, Edge = true, Double = true, Halo = true, SlowMo = true, Flash2 = true, Shake = 1.0, HitStop = 0.16, Hold = 1.8, MiniFlash = true },
}

-- The egg's tuning (brief 28 / 28b: the hit games' hatch with the reference's animation grammar): data, so that
-- matching it is a value change.
--   Glint     how long the box hangs glinting in the sky before it drops (s)
--   Shakes    { roll (deg), hop (studs), length (s) } per shake, in order: a crouch, a hop with a left-right roll in
--             the air, a squash on landing (the count is the list's length)
--   Pauses    the rests between shakes (s, shrinking)   Swings  left-right swings per shake (1.5: L-R-L)
--   First     the first shake of a single (s)         Pop     { the pair's overshoot scale, its time (s) }
--   Squash    the box's height on the landing frame     ShakeSquash  its height as each shake lands
--   BoxShare  the box's (tub and lid) share of the frame height while it shakes; Fov the egg camera's
--   Flash     the pop's soft flash peak (plain, rainbow: a rainbow's real flash comes >= 1 s later, at its reveal)
--   Confetti  pieces from the top by rank
--   Lux       Legendary / Mythic after the pop (the reference's beats 13-15, short): the dusk dip (s), the rings
--             (count, size), the spin (turns, s); then the rarity flash and the reveal
--   Rainbow   per level (1 Legendary, 2 Mythic): sweep (turns/s), sat, cycle (box widths per hue turn), and a
--             Mythic's extra channels: glow (its rim and band in Neon, pulsing at pulse Hz), aura (a halo round the
--             box, in box widths past its edge), ring (a ring of light round it), stars (larger star sparkles a second,
--             in the rarity's colour), pop (burst scale)
UnboxThemes.Egg = {
	Glint = 0.25,
	Shakes = { { 7, 0.35, 0.2 }, { 10, 0.55, 0.22 }, { 15, 0.8, 0.25 } },
	Pauses = { 0.2, 0.13 },
	Swings = 1.5,
	First = 0.72,
	Pop = { 1.15, 0.28 },
	Squash = 0.76, ShakeSquash = 0.86,
	BoxShare = 0.32,
	Fov = 70,
	Flash = { 0.18, 0.18 },
	Confetti = { 0, 18, 22, 34, 38, 38 },
	Lux = {
		{ dusk = 0.35, rings = 3, size = 1, turns = 1.5, spin = 0.45 },
		{ dusk = 0.35, rings = 4, size = 1.25, turns = 1.5, spin = 0.3 },
	},
	Rainbow = {
		{ sweep = 0.35, sat = 0.7, cycle = 0.85, pop = 1.2 },
		{ sweep = 0.7, sat = 0.8, cycle = 0.8, pop = 1.4, glow = true, pulse = 1.6, aura = 0.3, ring = true, stars = 8 },
	},
}

-- The opening in the world (brief 28c, copy_spec v5 §11.5: the soldier game's egg hatch at its own speed, with our box
-- and pair; UnboxWorld). Times in seconds from the buy.
--   Box, Pair  shares of the screen's height (the box with its lid and topper; the pair at the reveal); At  the rig's
--              centre, as a share of the height from the top (a row's: RowAt); Dist  studs from the camera to the rig
--   Land, Fall the drop (Quad In) lands; Stretch, Squash  its sy falling and on contact; Bounce { hop (box heights), s }
--   Shakes     { time, roll (deg), hop (box heights), length (s) }: hop-and-roll shakes on the bottom edge (ShakesLux: a
--              Legendary's four, ShakesMythic: a Mythic's, harder); Rock { deg from, deg to, Hz from, Hz to }: the low
--              rock between them
--   Ghost      { landing scale, shake scale, opacity, fade (s) }: the translucent copy of the box at each impact
--   Jolt       the lid's jump at each shake (box heights)
--   Squeeze    { from, to, scale } (SqueezeLux); Pop, PopLux  the pop; Spring  the pair growing in (s: 0.45x to full
--              in 0.1 s, a touch over, settled); SpinLux { s, Legendary turns, Mythic turns }  their extra spin
--   Wash       { Common-Epic peak (white, never a white-out), Legendary/Mythic peak, Quad Out (s) }; Burst  the pop's burst
--              and ring size by tier
--   Hold       auto-close after the reveal (s); Close { auto, tap } the fly into the inventory button (s)
--   Idle       { deg/s, bob (pair heights), bob Hz }
--   Rays       the reference's sunburst: count, reach and peak (pair heights from the centre), Legendary and Mythic
--              size, deg/s, the core's opacity (low: its breathing low), from (s after the pop), the first fade in and
--              hold { in, hold } (s), then the breath's period (s)
UnboxThemes.World = {
	Box = 0.34, Pair = 0.31, At = 0.47, RowAt = 0.43, Dist = 6.5,
	Land = 0.35, Fall = 0.25, Stretch = 1.15, Squash = 0.8, Bounce = { 0.06, 0.15 },
	Shakes = { { 0.9, 12, 0.05, 0.22 }, { 1.65, 18, 0.08, 0.22 }, { 2.2, 24, 0.12, 0.24 } },
	ShakesLux = { { 0.9, 10, 0.04, 0.2 }, { 1.8, 14, 0.06, 0.22 }, { 2.55, 19, 0.09, 0.22 }, { 3.15, 25, 0.12, 0.24 } },
	ShakesMythic = { { 0.9, 11, 0.04, 0.2 }, { 1.8, 16, 0.065, 0.22 }, { 2.55, 22, 0.1, 0.22 }, { 3.15, 29, 0.14, 0.24 } },
	Rock = { 4, 8, 2.5, 5 },
	Ghost = { 1.5, 1.12, 0.4, 0.25 },
	Jolt = { 0.035, 0.055, 0.075, 0.095 },
	Squeeze = { 2.45, 2.9, 0.85 }, SqueezeLux = { 3.25, 3.75, 0.85 },
	Pop = 2.95, PopLux = 3.8,
	Swing = { 112, 0.15, 0.3 }, -- (brief 30) at the pop the lid swings open to [1] deg in [2] s; the box is gone by [3] s
	Spring = 0.25, SpinLux = { 0.6, 2, 2.5 },
	Wash = { 0.48, 0.85, 0.45 },
	Burst = { 1, 1.35, 1.65 }, -- (the pop's burst and ring: Common-Epic, Legendary, Mythic)
	Hold = 5.7, Close = { 0.5, 0.3 },
	Idle = { 90, 0.03, 0.5 },
	Rays = { n = 20, reach = 2.3, peak = 1.75, lux = 1.3, mythic = 1.55, turn = 4, core = 0.58, low = 0.3, from = 0.35, cycle = { 1, 0.5 }, period = 3 },
}

-- The crazy sheet's single-box beats (a Secret's middle; brief 27's premium, to be re-timed to REF28's measures of the
-- crate video): data, like the egg's. Times are seconds from the sheet's start.
--   Telegraph  the pad pulses               Appear, Fall0, Land  the comet shows, falls, slams
--   Charge     { from, to }                 RingsIn  the three rings' entries     Wobbles  { time, roll, hop }
--   Dip        the dark beat's length; the flash ends it       Accent  the reveal after the flash (Secret: SlowAccent)
--   SlowMo     the old false calm (unused by the chain)   Dusk, Rings2  the dusk dip and the second rings, before the
--              reveal (s before it)                         Hold  the read hold after the reveal
--   Whip, Carousel, Pick, Tease  the Secret's animated middle (copy_spec §1 beats 9-12), from flash 2 (s): the pair
--              launches past the lens and back; five candidates revolve; the others fly out; the edge-on tease
UnboxThemes.Crazy = {
	-- (copy_spec §1/§9.1, the crate's clock: the tear hangs, the streak falls in 2 frames, the slam at 0.50; the charge
	-- 0.77-2.0; the warm dip 2.0-2.4; flash 2; the bright middle; the dusk dip and the second rings; the reveal flash)
	Telegraph = { 0.3, 0.43 },
	Appear = 0.1, Fall0 = 0.43, Land = 0.5,
	Charge = { 0.77, 2.0 }, RingsIn = { 0.77, 0.8, 0.83 },
	Wobbles = { { 0.92, 5, 0.1 }, { 1.18, 6, 0.1 }, { 1.45, 6, 0.15 }, { 1.68, 7, 0.15 }, { 1.86, 8, 0.2 } },
	Dip = 0.4,
	Accent = 4.7, SlowMo = { 0.65, 1.25 }, SlowAccent = 4.7,
	Whip = { 0.07, 0.73 }, Carousel = { 0.73, 3.2 }, Pick = { 3.2, 3.43 }, Tease = { 3.43, 3.9 },
	Dusk = 0.8, Rings2 = 0.43, Hold = 2.2,
}

return UnboxThemes
