--[[
	The anime girls' effects as plain data (pure: no Roblox instances), so the game (HuzzClient/Gameplay/AuraFX
	builds real ParticleEmitters, Beams and lights from it) and the offline video (motion3d/aura_scene.luau
	simulates the same numbers) show the same thing.

	Owner's reference (video cf007d44): glowing flames on both hands with dark smoky wisps, and crescent
	slashes flicking round the body. Ours takes that and themes it per girl (Config/GirlLooks: her element and
	two colours) and grows it with her rarity (owner: "not so strong on commons, rares, epics, just little"):
	  Player     on YOU when she's equipped:
	               Common/Uncommon  a few faint tiny motes in her colours drifting up from your feet; no light.
	               Rare             + her element's motes (petals, snow, embers...) softly round you; a faint glow.
	               Epic             + small soft hand flames (no white cores, no wisps, no slashes).
	               Legendary        the old Epic look: hand flames, dark wisps and shards, her element round you,
	                                and slashes at a gentle 0.7 a second.
	               Mythic/Secret    the full look: bigger flames, crescent slashes 2.2/2.8 a second; Secret adds
	                                a smoky aura at your feet.
	  Companion  on HER (your girl walking behind you; the round's girl carried or following) and
	  Showcase   the big her over the map (3x, at least the Rare look): AuraLook.girl (Oct 18 rebuild, see there):
	               Common     a faint light pool on the floor and a few tiny motes;
	               Uncommon   + a thin ring round the pool;
	               Rare       + a highlight running round the ring, her element, puffs where her feet land, a glow;
	               Epic       + one orbiting light, a slow breathing swell;
	               Legendary  + flame tongues hugging her from behind, 2 orbits, a beat (draw in, flare, a ring runs
	                            out, sparkles), streaks rising off the floor, trails at her feet when she moves;
	               Mythic     + 3 orbits, a crescent slash on each beat, glints and trails on her hands;
	               Secret     + two tones, 4 orbits, the owner's crystals and butterflies, a halo.
	Elements: Flame (embers), Frost (snow), Sakura (petals and hearts), Night (heavy dark wisps), Holy (feathers
	and gold stars), Storm (fast sparks), Nature (leaves), Water (bubbles); Sparkle = no look set.

	An emitter: { name, at = "RightHand" | "LeftHand" | "Body" | "Head" | "Feet", texture = a Shared/FxTexture name,
	  flip = "OneShot" | "Random" (a flipbook sheet), offset (studs up from the anchor), orient = "Flat" (lies level:
	  sigils, halos) | "Streak" (stretched along its flight), squash = { {t, n} }, bright (Brightness), every =
	  seconds (bursts of `count` on a beat instead of a steady rate),
	  colors = { {t, Color3}, ... }, light (LightEmission 0-1), rate (per second), life = {min, max},
	  speed = {min, max}, spread (degrees round straight up), size = { {t, studs}, ... },
	  alpha = { {t, transparency}, ... }, accel = {x, y, z}, drag, rot = {min, max}, spin = {min, max},
	  z = ZOffset (studs drawn closer to the camera: the hand flames sit in front of the arm, as in the reference),
	  inherit = VelocityInheritance (0-1: the hand flames and wisps keep up with you when you run instead of
	  streaming back over the companion walking behind you) }.
	Sizes, speeds and acceleration are for a 5-stud character; the builder multiplies them by the scale.
]]
local AuraLook = {}

AuraLook.RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

-- Particle pictures: our own (assets/fx, uploaded with the other pictures into Config/ImageIds as "Fx/<Name>"),
-- or Roblox's built-in particle textures until they're uploaded.
AuraLook.TEXTURES = {
	Flame = "rbxasset://textures/particles/fire_main.dds",
	Wisp = "rbxasset://textures/particles/smoke_main.dds",
	Star = "rbxasset://textures/particles/sparkles_main.dds",
	Glow = "rbxasset://textures/particles/sparkles_main.dds",
	Heart = "rbxasset://textures/particles/sparkles_main.dds",
	Petal = "rbxasset://textures/particles/sparkles_main.dds",
	Feather = "rbxasset://textures/particles/sparkles_main.dds",
	Snow = "rbxasset://textures/particles/sparkles_main.dds",
	Leaf = "rbxasset://textures/particles/sparkles_main.dds",
	Bubble = "rbxasset://textures/particles/sparkles_main.dds",
	Shard = "rbxasset://textures/particles/sparkles_main.dds",
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- What each element adds round the body: { texture(s), drift (accel), spin, light, size }.
local ELEMENTS = {
	Flame = { textures = { "Star" }, accel = { 0, 5, 0 }, speed = { 0.5, 1.5 }, size = 0.45, light = 1, spin = 0, dark = 0.85 },
	Frost = { textures = { "Snow" }, accel = { 0, -1.2, 0 }, speed = { 0.2, 0.7 }, size = 0.6, light = 0.6, spin = 40, dark = 0.55 },
	Sakura = { textures = { "Petal", "Heart" }, accel = { 0, -0.8, 0 }, speed = { 0.3, 0.9 }, size = 0.6, light = 0.4, spin = 90, dark = 0.5 },
	Night = { textures = { "Wisp" }, accel = { 0, 1.2, 0 }, speed = { 0.2, 0.6 }, size = 1.6, light = 0, spin = 20, dark = 0.92 },
	Holy = { textures = { "Feather", "Star" }, accel = { 0, 0.8, 0 }, speed = { 0.2, 0.6 }, size = 0.65, light = 0.8, spin = 30, dark = 0.4 },
	Storm = { textures = { "Star" }, accel = { 0, 0, 0 }, speed = { 3, 6 }, size = 0.4, light = 1, spin = 0, dark = 0.8 },
	Nature = { textures = { "Leaf" }, accel = { 0, -0.6, 0 }, speed = { 0.4, 1.2 }, size = 0.6, light = 0.3, spin = 120, dark = 0.6 },
	Water = { textures = { "Bubble" }, accel = { 0, 1.6, 0 }, speed = { 0.2, 0.6 }, size = 0.55, light = 0.5, spin = 0, dark = 0.6 },
	Sparkle = { textures = { "Star" }, accel = { 0, 0.5, 0 }, speed = { 0.2, 0.6 }, size = 0.45, light = 1, spin = 0, dark = 0.7 },
}
AuraLook.ELEMENTS = ELEMENTS

-- The look for a girl: her GirlLooks entry, else her rarity colour with Sparkle.
function AuraLook.lookFor(looks, id, rarityColor)
	local look = looks[id or ""]
	if look then
		return look
	end
	local c = rarityColor or Color3.fromRGB(200, 200, 255)
	return { Element = "Sparkle", Colors = { c:Lerp(WHITE, 0.4), c:Lerp(BLACK, 0.35) } }
end

-- Flames wrapped round each hand (big, slow, in front of the arm) with a hot white core.
-- soft (Epic): small, see-through, a low rate and no white core: just a little flicker on each hand.
local function handFlames(look, rank, k, soft)
	local c1, c2 = look.Colors[1], look.Colors[2]
	local list = {}
	local grow = if soft then 0.45 else 1 + 0.1 * math.max(0, rank - 3)
	for _, hand in { "RightHand", "LeftHand" } do
		table.insert(list, {
			name = "Flame" .. hand, at = hand, texture = "FlameSheet", flip = "OneShot",
			colors = { { 0, c1 }, { 0.5, c1:Lerp(c2, 0.4) }, { 1, c2 } }, light = if soft then 0.6 else 1,
			rate = (if soft then 9 else 16 + 3 * math.max(0, rank - 3)) * k, life = { 0.3, 0.6 },
			speed = if soft then { 0.5, 1.1 } else { 1, 2.2 }, spread = 50,
			size = { { 0, 1.6 * grow }, { 0.4, 2.0 * grow }, { 1, 0.6 * grow } },
			alpha = if soft then { { 0, 0.6 }, { 0.5, 0.7 }, { 1, 1 } } else { { 0, 0.1 }, { 0.5, 0.3 }, { 1, 1 } },
			accel = if soft then { 0, 3, 0 } else { 0, 5, 0 }, drag = 2, rot = { -15, 15 }, spin = { -30, 30 }, z = 1.5, inherit = 0.85,
		})
		if soft then
			continue
		end
		table.insert(list, {
			name = "Core" .. hand, at = hand, texture = "FlameSheet", flip = "OneShot",
			colors = { { 0, c1:Lerp(WHITE, 0.25) }, { 1, c1 } }, light = 1,
			rate = (10 + 3 * math.max(0, rank - 3)) * k, life = { 0.18, 0.35 }, speed = { 0.2, 0.6 }, spread = 180,
			size = { { 0, 0.7 * grow }, { 1, 0.2 } }, alpha = { { 0, 0.55 }, { 1, 1 } },
			accel = { 0, 3, 0 }, drag = 3, rot = { -20, 20 }, spin = { -40, 40 }, z = 1.8, inherit = 0.85,
		})
	end
	return list
end

-- Dark smoke round the hands and sharp dark shards flying off them (the reference's black flakes).
local function darkWisps(look, rank, k)
	local deep = look.Colors[2]:Lerp(BLACK, (ELEMENTS[look.Element] or ELEMENTS.Sparkle).dark)
	local list = {}
	for _, hand in { "RightHand", "LeftHand" } do
		table.insert(list, {
			name = "Wisp" .. hand, at = hand, texture = "Wisp",
			colors = { { 0, deep }, { 1, deep:Lerp(BLACK, 0.5) } }, light = 0,
			rate = (14 + 3 * math.max(0, rank - 4)) * k, life = { 0.5, 0.9 }, speed = { 0.8, 2 }, spread = 180,
			size = { { 0, 1.5 }, { 1, 2.6 } }, alpha = { { 0, 0.2 }, { 1, 1 } },
			accel = { 0, 2.5, 0 }, drag = 2, rot = { 0, 360 }, spin = { -40, 40 }, z = 1.6, inherit = 0.7,
		})
		table.insert(list, {
			name = "Shard" .. hand, at = hand, texture = "Shard",
			colors = { { 0, deep }, { 1, deep } }, light = 0,
			rate = (16 + 4 * math.max(0, rank - 4)) * k, life = { 0.35, 0.7 }, speed = { 3, 6 }, spread = 180,
			size = { { 0, 0.85 }, { 1, 0.25 } }, alpha = { { 0, 0 }, { 1, 1 } },
			accel = { 0, -2, 0 }, drag = 3, rot = { 0, 360 }, spin = { -300, 300 }, z = 1.2, inherit = 0.6,
		})
	end
	return list
end

-- Her element's particles round the body. soft (Rare, Epic): a few at a time, smaller and see-through.
local function elementField(look, rank, at, radiusSpeed, rateBase, k, soft)
	local e = ELEMENTS[look.Element] or ELEMENTS.Sparkle
	local c1, c2 = look.Colors[1], look.Colors[2]
	local list = {}
	local size = if soft then e.size * 0.6 else e.size
	for i, tex in e.textures do
		table.insert(list, {
			name = "Element" .. i, at = at, texture = tex,
			colors = { { 0, c1:Lerp(WHITE, 0.3) }, { 1, c2 } }, light = e.light,
			rate = (if soft then rateBase else rateBase + 2.5 * rank) * k / #e.textures, life = { 1.4, 2.6 },
			speed = { e.speed[1] + radiusSpeed, e.speed[2] + radiusSpeed }, spread = 180,
			size = { { 0, 0 }, { 0.15, size }, { 0.85, size }, { 1, 0 } },
			alpha = if soft then { { 0, 0.45 }, { 0.8, 0.6 }, { 1, 1 } } else { { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } },
			accel = e.accel, drag = 1.2, rot = { 0, 360 }, spin = { -e.spin, e.spin },
		})
	end
	return list
end

-- Common and up: a few faint, tiny motes in her colours drifting up from the feet (almost nothing).
local function motes(look, rank, at, k)
	return {
		name = "Motes", at = at, texture = "Twinkle", flip = "Random",
		colors = { { 0, look.Colors[1]:Lerp(WHITE, 0.5) }, { 1, look.Colors[1] } }, light = 0.6,
		rate = (2 + 0.5 * math.min(rank, 3)) * k, life = { 1.2, 2 }, speed = { 0.3, 0.8 }, spread = 40,
		size = { { 0, 0 }, { 0.25, 0.22 }, { 1, 0 } }, alpha = { { 0, 0.55 }, { 0.6, 0.65 }, { 1, 1 } },
		accel = { 0, 0.8, 0 }, drag = 1.5, rot = { 0, 360 }, spin = { -60, 60 },
	}
end

-- Crescent slashes: how many a second, their size, and their two colours (bright core, dark edge).
local function slashes(look, rank, k)
	local per = ({ [5] = 0.7, [6] = 2.2, [7] = 2.8 })[math.min(rank, 7)] or 0
	if per <= 0 then
		return nil
	end
	local e = ELEMENTS[look.Element] or ELEMENTS.Sparkle
	return {
		rate = per * k, life = 0.5, radius = 2.6, span = 110, width = 0.6,
		core = look.Colors[1]:Lerp(WHITE, 0.25), edge = look.Colors[2]:Lerp(BLACK, e.dark),
	}
end

-- The anime layers (docs/vfx-guide.md 6.1). Three tones each: white, main, deep.
-- A turning magic circle flat on the ground at the feet (two overlap and crossfade, so it's always there).
local function sigil(main, size, rate)
	return {
		name = "Sigil", at = "Feet", offset = -0.3, texture = "Sigil", orient = "Flat",
		colors = { { 0, main:Lerp(WHITE, 0.25) }, { 1, main } }, light = 1, bright = 1.4,
		rate = rate or 1.25, life = { 1.6, 1.6 }, speed = { 0, 0 }, spread = 0,
		size = { { 0, size * 0.9 }, { 1, size } }, alpha = { { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.35 }, { 1, 1 } },
		accel = { 0, 0, 0 }, rot = { 0, 360 }, spin = { 22, 28 },
	}
end
-- A ring that bursts out from the feet on a beat.
local function pulseRing(main, every)
	return {
		name = "Pulse", at = "Feet", offset = -0.25, texture = "RingSoft", orient = "Flat", every = every,
		colors = { { 0, WHITE }, { 0.25, main }, { 1, main } }, light = 1, bright = 1.5,
		rate = 0, life = { 0.9, 0.9 }, speed = { 0, 0 }, spread = 0,
		size = { { 0, 2.4 }, { 0.12, 5 }, { 0.4, 6.8 }, { 1, 7.5 } }, alpha = { { 0, 0.15 }, { 0.6, 0.4 }, { 1, 1 } },
		accel = { 0, 0, 0 }, rot = { 0, 360 }, spin = { 0, 0 },
	}
end
-- Cel flame tongues licking up round the body (colour, then a smaller white core in front of it).
local function tongues(white, main, deep, rate)
	return {
		{
			name = "Tongues", at = "Feet", offset = 0.4, texture = "FlameSheet", flip = "OneShot",
			colors = { { 0, main:Lerp(WHITE, 0.2) }, { 0.45, main }, { 1, deep } }, light = 0.5,
			rate = rate, life = { 0.6, 0.9 }, speed = { 2.5, 4 }, spread = 60,
			size = { { 0, 0 }, { 0.15, 2.6 }, { 1, 0.9 } }, alpha = { { 0, 0.15 }, { 0.7, 0.3 }, { 1, 1 } },
			accel = { 0, 4, 0 }, drag = 1, rot = { -10, 10 }, spin = { -10, 10 }, z = 1.3, inherit = 0.4,
		},
		{
			name = "CoreTongues", at = "Feet", offset = 0.4, texture = "FlameSheet", flip = "OneShot",
			colors = { { 0, white }, { 1, main:Lerp(WHITE, 0.5) } }, light = 1,
			rate = rate * 0.6, life = { 0.5, 0.75 }, speed = { 2.5, 4 }, spread = 55,
			size = { { 0, 0 }, { 0.15, 1.4 }, { 1, 0.45 } }, alpha = { { 0, 0.1 }, { 0.7, 0.25 }, { 1, 1 } },
			accel = { 0, 4, 0 }, drag = 1, rot = { -10, 10 }, spin = { -10, 10 }, z = 1.6, inherit = 0.4,
		},
	}
end
local function twinkles(main, rate)
	return {
		name = "Twinkles", at = "Body", texture = "Twinkle", flip = "Random",
		colors = { { 0, WHITE }, { 1, main:Lerp(WHITE, 0.35) } }, light = 1,
		rate = rate, life = { 1, 1.6 }, speed = { 2, 3.5 }, spread = 180,
		size = { { 0, 0 }, { 0.3, 0.75, 0.15 }, { 1, 0 } }, alpha = { { 0, 0 }, { 1, 0.2 } },
		accel = { 0, 0.3, 0 }, drag = 1.5, rot = { 0, 360 }, spin = { -40, 40 }, z = 1,
	}
end
-- A little lightning crackling round the body (a different bolt each time). Kid-safe: one bolt on a beat, never
-- faster than every `every` seconds (at most 1 flash a second), fading in and out rather than popping.
local function crackle(main, every)
	return {
		name = "Crackle", at = "Body", texture = "Bolt", flip = "Random", every = math.max(every, 1.2),
		colors = { { 0, WHITE }, { 1, main } }, light = 1, bright = 1.2,
		rate = 0, life = { 0.22, 0.28 }, speed = { 1.5, 3 }, spread = 180,
		size = { { 0, 2.4, 0.4 }, { 1, 2.8 } }, alpha = { { 0, 0.6 }, { 0.25, 0.1 }, { 0.6, 0.2 }, { 1, 1 } },
		accel = { 0, 0, 0 }, rot = { 0, 360 }, spin = { 0, 0 }, z = 2,
	}
end
-- A glowing halo level over the head (two crossfading, like the sigil).
local function halo(main)
	return {
		name = "Halo", at = "Head", offset = 1.25, texture = "RingHard", orient = "Flat",
		colors = { { 0, WHITE }, { 1, main } }, light = 1, bright = 1.6,
		rate = 1.25, life = { 1.6, 1.6 }, speed = { 0, 0 }, spread = 0,
		size = { { 0, 1.5 }, { 1, 1.6 } }, alpha = { { 0, 1 }, { 0.2, 0.15 }, { 0.8, 0.15 }, { 1, 1 } },
		accel = { 0, 0, 0 }, rot = { 0, 360 }, spin = { 30, 40 },
	}
end
local function orbs(count, white, main, deep, tilt)
	return { count = count, radius = 2.2, speed = 2.5, bob = 0.4, height = 0.3, size = 1.1, trail = 0.5, tilt = tilt or 0, colors = { white, main, deep } }
end
AuraLook.layers = { sigil = sigil, pulseRing = pulseRing, tongues = tongues, twinkles = twinkles, crackle = crackle, halo = halo, orbs = orbs }

-- The auras you wear (Config/CoinShop "Aura" rewards and the Blossom Aura cosmetic), by item key. Each rarer
-- reward adds a new layer rather than more of the same (Legendary: sigil, flames, 2 orbs; Mythic: + a pulse ring,
-- 3 orbs, slashes; Secret: + a halo, lightning, dark wisps, 4 tilted orbs).
function AuraLook.worn(key: string)
	local rgb = Color3.fromRGB
	local out = { emitters = {}, slashes = nil, light = nil, scale = 1 }
	local function add(e) table.insert(out.emitters, e) end
	if key == "BlossomAura" then
		local pink, deep = rgb(255, 170, 205), rgb(235, 95, 150)
		for i, tex in { "Petal", "Heart" } do
			add({
				name = "Blossom" .. i, at = "Head", offset = 1, texture = tex,
				colors = { { 0, pink:Lerp(WHITE, 0.4) }, { 1, pink } }, light = 0.3,
				rate = if i == 1 then 10 else 2, life = { 2.2, 3 }, speed = { 0.8, 1.6 }, spread = 180,
				size = { { 0, 0 }, { 0.1, if i == 1 then 0.75 else 0.6, 0.1 }, { 0.85, 0.65 }, { 1, 0 } },
				alpha = { { 0, 0.05 }, { 0.8, 0.2 }, { 1, 1 } }, accel = { 0, -1.6, 0 }, drag = 1.3, rot = { 0, 360 }, spin = { -90, 90 },
			})
		end
		add(twinkles(pink, 3))
		add(pulseRing(deep, 3.2))
		out.light = { color = pink, brightness = 0.5, range = 7, at = "Body" }
	elseif key == "AuraLegend" then
		local white, main, deep = rgb(255, 245, 230), rgb(255, 140, 70), rgb(220, 60, 50) -- (sunfire, not gold: the owner)
		add(sigil(main, 6.5))
		for _, e in tongues(white, main, deep, 10) do add(e) end
		add(twinkles(main, 5))
		out.orbs = orbs(2, white, main, deep)
		out.light = { color = main, brightness = 1.2, range = 10, at = "Body" }
	elseif key == "AuraMythic" then
		local white, main, deep = rgb(255, 225, 235), rgb(255, 84, 120), rgb(150, 20, 70)
		add(sigil(main, 7))
		for _, e in tongues(white, main, deep, 14) do add(e) end
		add(twinkles(main, 5))
		add(pulseRing(main, 2.5))
		out.orbs = orbs(3, white, main, deep, 12)
		out.slashes = { rate = 0.8, life = 0.5, radius = 2.6, span = 110, width = 0.6, core = main:Lerp(WHITE, 0.3), edge = deep:Lerp(BLACK, 0.5) }
		out.light = { color = main, brightness = 1.4, range = 11, at = "Body" }
	elseif key == "AuraSecret" then
		local white, main, deep = rgb(235, 225, 255), rgb(150, 110, 255), rgb(60, 20, 120)
		local cyan, pink = rgb(110, 235, 255), rgb(255, 120, 210)
		add(sigil(main, 7.5))
		for _, e in tongues(white, main, deep, 16) do add(e) end
		add(twinkles(cyan, 6))
		add(pulseRing(pink, 2.5))
		add(halo(cyan))
		add(crackle(cyan, 1.3))
		add({
			name = "VoidWisps", at = "Feet", texture = "Wisp", colors = { { 0, deep }, { 1, BLACK } }, light = 0,
			rate = 10, life = { 0.8, 1.4 }, speed = { 1.5, 3 }, spread = 85,
			size = { { 0, 1 }, { 1, 2.4 } }, alpha = { { 0, 0.55 }, { 1, 1 } }, accel = { 0, 1, 0 }, drag = 2,
			rot = { 0, 360 }, spin = { -30, 30 },
		})
		out.orbs = orbs(4, white, cyan, main, 20)
		out.slashes = { rate = 1.2, life = 0.5, radius = 2.6, span = 110, width = 0.6, core = pink:Lerp(WHITE, 0.3), edge = deep }
		out.light = { color = main, brightness = 1.6, range = 12, at = "Body" }
	else
		return nil
	end
	return out
end

--[[
	kind: "Player" | "Companion" | "Showcase". Returns { emitters = {...}, slashes = {...} or nil, light = {...} or
	nil, scale }. Every rarity shows something (Common: a few faint motes).
]]
function AuraLook.build(look, rarity, kind)
	local rank = AuraLook.RANK[rarity or ""] or 1
	local out = { emitters = {}, slashes = nil, light = nil, scale = 1 }
	local function add(list)
		for _, e in list do
			table.insert(out.emitters, e)
		end
	end
	local c1 = look.Colors[1]
	if kind == "Player" then
		-- Everyone gets the motes; each rarity adds a little (the ladder in the header).
		table.insert(out.emitters, motes(look, rank, "Feet", 1))
		if rank >= 3 and rank <= 4 then
			add(elementField(look, rank, "Body", 0.6, if rank == 3 then 3 else 4, 1, true))
		end
		if rank == 4 then
			add(handFlames(look, rank, 1, true))
		elseif rank == 5 then
			-- the old Epic look, with gentle slashes
			add(handFlames(look, 4, 1))
			add(darkWisps(look, 4, 1))
			add(elementField(look, 4, "Body", 0.8, 1, 1))
		elseif rank >= 6 then
			add(handFlames(look, rank, 1))
			add(darkWisps(look, rank, 1))
			add(elementField(look, rank, "Body", 0.8, 1, 1))
		end
		out.slashes = slashes(look, rank, 1)
		if rank >= 7 then
			local deep = look.Colors[2]:Lerp(BLACK, 0.85)
			table.insert(out.emitters, {
				name = "FeetSmoke", at = "Feet", texture = "Wisp", colors = { { 0, deep }, { 1, BLACK } }, light = 0,
				rate = 14, life = { 0.8, 1.4 }, speed = { 1.5, 3 }, spread = 85,
				size = { { 0, 1 }, { 1, 2.4 } }, alpha = { { 0, 0.5 }, { 1, 1 } }, accel = { 0, 1, 0 }, drag = 2,
				rot = { 0, 360 }, spin = { -30, 30 },
			})
		end
		-- Legendary and up: the anime layers (docs/vfx-guide.md 6.1), each rarity adding a new one
		if rank >= 5 then
			local white, deep = c1:Lerp(WHITE, 0.8), look.Colors[2]
			table.insert(out.emitters, sigil(c1, 6))
			out.orbs = orbs(rank - 3, white, c1, deep, if rank >= 7 then 18 else 0)
			if rank >= 6 then table.insert(out.emitters, pulseRing(c1, 2.8)) end
			if rank >= 7 then table.insert(out.emitters, crackle(c1:Lerp(WHITE, 0.3), 1.6)) end
		end
		if rank == 3 or rank == 4 then
			out.light = { color = c1, brightness = 0.25 + 0.15 * (rank - 3), range = 6, at = "Body" } -- a faint glow
		elseif rank >= 5 then
			out.light = { color = c1, brightness = 0.8 + 0.25 * (rank - 4), range = 8 + 2 * (rank - 4), at = "Body" }
		end
	elseif kind == "Companion" or kind == "Showcase" then
		return AuraLook.girl(look, rarity, kind)
	end
	return out
end

-- A tiny seeded random (so a slash's shape is the same wherever it's worked out).
local function rand(seed, n)
	local x = math.sin(seed * 12.9898 + n * 78.233) * 43758.5453
	return x - math.floor(x)
end

--[[
	One crescent slash, `age` seconds into its `life`, round `centre` (a Vector3) at `scale`: an arc on a tilted
	circle that sweeps round as it fades, thick in the middle and sharp at both ends (drawn as two halves).
	Returns the start, middle and end points, their tangents, the control-point distance for each half
	(Beam CurveSize), alpha (0 = solid, 1 = gone) and the width at the middle.
	Kid-safe: it fades in over 0.2 s (never a pop), then fades out.
]]
function AuraLook.slash(spec, seed, age, centre, scale)
	local t = math.clamp(age / spec.life, 0, 1)
	-- a random tilted plane through the centre
	local yaw = rand(seed, 1) * math.pi * 2
	local tilt = (rand(seed, 2) - 0.5) * math.rad(110)
	local up = Vector3.new(math.sin(tilt) * math.cos(yaw), math.cos(tilt), math.sin(tilt) * math.sin(yaw))
	local ref = if math.abs(up.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local u = up:Cross(ref).Unit
	local v = up:Cross(u).Unit
	local r = spec.radius * scale * (0.85 + rand(seed, 3) * 0.35)
	local height = (rand(seed, 4) - 0.35) * 1.6 * scale
	local span = math.rad(spec.span) * (0.8 + rand(seed, 5) * 0.4)
	local dir = if rand(seed, 6) < 0.5 then 1 else -1
	local a0 = rand(seed, 7) * math.pi * 2 + dir * math.rad(70) * (1 - (1 - t) ^ 2) -- sweeps round, easing out
	local a1 = a0 + dir * span * (0.45 + 0.55 * math.min(1, t * 2.5)) -- the arc grows out
	local am = (a0 + a1) / 2
	local c = centre + Vector3.new(0, height, 0)
	local function at(a)
		return c + (u * math.cos(a) + v * math.sin(a)) * r
	end
	local function tangent(a)
		return (u * -math.sin(a) + v * math.cos(a)) * dir
	end
	local curve = 4 / 3 * math.tan(math.abs(am - a0) / 4) * r
	local fadeIn = 0.2 / spec.life
	local alpha = if t < fadeIn then 1 - t / fadeIn else ((t - fadeIn) / (1 - fadeIn)) ^ 2
	return at(a0), at(am), at(a1), tangent(a0), tangent(am), tangent(a1), curve, alpha, spec.width * scale * (1 - 0.4 * t)
end

--[[
	The girls' own effects (kind "Companion": your girl walking behind you, and the round's girl carried or
	following; kind "Showcase": the big prize girl over the map), rebuilt Oct 18 after the owner: "they still look
	strange and low quality ... they just float there". What the pro references do that we copy
	(design/vfx/vysvex-green-reference.mp4, ref3, the other game's Soul Reaper stand):
	  - anchored to her and to the ground, not loose sprites: a soft light pool and a crisp ring flat on the floor
	    under her feet ("ground"), energy rising off that floor, puffs where her feet land, flame tongues hugging
	    her outline from behind ("flames", drawn behind her body so they never cover her face), glints on her hands;
	  - layers that move at different speeds: a slow breathing pulse, a highlight running round the ring, orbiting
	    lights on tilted orbits that pass in front of and behind her, quick rising streaks;
	  - rhythm with anticipation ("beat"): the flames draw in for a moment, then flare, a ring runs out across the
	    floor and a few sparkles burst (Mythic and up: one crescent slash flicks round her on the beat, like the
	    Soul Reaper stand's loop). Never closer than 2.4 s apart (kid-safe: far under 1 flash a second);
	  - motion that reacts to her: trails at her feet (Legendary up) and hands (Mythic up) only while she moves;
	  - a white core, her colour, a deep edge; few big shapes rather than many dots; and almost nothing on a
	    Common (owner: "effects tiny below Legendary").
	Only the particles need an uploaded picture (Roblox's stand-ins until the owner uploads assets/fx): the floor
	pool and rings are SurfaceGui circles, the flames are Beams, the orbiting lights are small neon balls with
	Trails, the wakes are Trails (Gameplay/AuraFX builds them).
	Extra spec fields (sizes for a 5-stud body; AuraFX multiplies by spec.scale):
	  ground = { radius, colors = {white, main, deep}, accent, pool = {transparency per step, outside in} or nil,
	             ring = transparency or nil, runner = true (a highlight running round the ring), inner = true (a
	             thin second ring), breathe = 0-1 (how much it swells), spin = degrees a second }
	  flames = { count, core (how many white inner tongues), radius, height, width, colors = {white, main, accent, deep},
	             behind (how far back they sit, x radius; default 1.5) }
	  beat   = { every (seconds), pre (anticipation seconds), burst (sparkles on "Burst"), shock = true, slash = true }
	  wake   = { feet = true, hands = true, colors = {white, main, deep} }  (trails while she moves)
	  halo   = { radius, colors = {white, accent} }  (Secret: a thin ring over her head)
	  emitters may say at = "Ground" (from the floor pool's area) and stride = studs (`count` puffs every
	  `stride` studs she walks, instead of a rate).
]]
local SECRET_ACCENT_A, SECRET_ACCENT_B = Color3.fromRGB(110, 235, 255), Color3.fromRGB(255, 120, 210)

-- Her colour made strong enough to read over a bright sky or floor (pale colours on glowing layers wash out to
-- white in daylight): the channels pushed apart until the colour is at least ~60% saturated.
local function vivid(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	if mx <= 0 or mx - mn >= 0.6 * mx then
		return c
	end
	local f = math.min(4, 0.6 * mx / math.max(mx - mn, 0.02))
	local function ch(x) return math.clamp(mx - (mx - x) * f, 0, 1) end
	return Color3.new(ch(c.R), ch(c.G), ch(c.B))
end
AuraLook.vivid = vivid

-- The rarity ladder for the girls (index = rank). Each step adds a new layer, not just more of the same.
-- r = floor radius, pool = its glow steps (transparency, outside in), ring, runner, inner, breathe, orbs,
-- flames = { outer tongues, white inner tongues, height, width }, beat = seconds between beats, light = { brightness, range }.
local LADDER = {
	[1] = { r = 1.2, pool = { 0.9, 0.84 }, orbs = 0 },
	[2] = { r = 1.3, pool = { 0.88, 0.82 }, ring = 0.62, orbs = 0 },
	[3] = { r = 1.5, pool = { 0.9, 0.84, 0.76 }, ring = 0.45, runner = true, orbs = 0, light = { 0.3, 5 } },
	[4] = { r = 1.6, pool = { 0.88, 0.82, 0.72 }, ring = 0.35, runner = true, breathe = 0.05, orbs = 1, light = { 0.45, 6 } },
	[5] = { r = 1.9, pool = { 0.86, 0.78, 0.66 }, ring = 0.25, runner = true, inner = true, breathe = 0.07, orbs = 2,
		flames = { 4, 2, 1.1, 1.1 }, beat = 3.6, light = { 0.8, 8 } },
	[6] = { r = 2.1, pool = { 0.85, 0.76, 0.62 }, ring = 0.2, runner = true, inner = true, breathe = 0.08, orbs = 3,
		flames = { 5, 3, 1.35, 1.2 }, beat = 3.0, light = { 1.0, 9 } },
	[7] = { r = 2.3, pool = { 0.84, 0.74, 0.6 }, ring = 0.15, runner = true, inner = true, breathe = 0.09, orbs = 4,
		flames = { 6, 3, 1.55, 1.25 }, beat = 2.6, light = { 1.2, 10 } },
}
AuraLook.LADDER = LADDER

function AuraLook.girl(look, rarity, kind)
	local rank = AuraLook.RANK[rarity or ""] or 1
	if kind == "Showcase" then
		rank = math.max(rank, 3) -- (the prize over the map always reads as a prize)
	end
	local L = LADDER[rank]
	local e = ELEMENTS[look.Element] or ELEMENTS.Sparkle
	local main, deep = look.Colors[1], look.Colors[2]:Lerp(BLACK, 0.25)
	local white = main:Lerp(WHITE, 0.8)
	local accent = main
	if rank >= 7 then -- Secret: two tones (cyan or pink, whichever is further from her own colour)
		local function dist(a, b) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) end
		accent = if dist(main, SECRET_ACCENT_A) > dist(main, SECRET_ACCENT_B) then SECRET_ACCENT_A else SECRET_ACCENT_B
	end
	local out = { emitters = {}, scale = if kind == "Showcase" then 3 else 1, rank = rank }
	local function add(x) table.insert(out.emitters, x) end

	out.ground = {
		radius = L.r, colors = { white, main, deep }, accent = accent, pool = L.pool, ring = L.ring, runner = L.runner,
		inner = L.inner, breathe = L.breathe or 0, spin = 50 + 10 * rank,
	}
	-- Common and up: a few faint tiny motes drifting up off the floor (almost nothing)
	add({
		name = "Motes", at = "Ground", texture = "Twinkle", flip = "Random",
		colors = { { 0, white }, { 1, main } }, light = 0.6,
		rate = ({ 1.5, 2, 2.5, 2.5, 3, 3.5, 4 })[rank], life = { 1.2, 2 }, speed = { 0.3, 0.7 }, spread = 25,
		size = { { 0, 0 }, { 0.25, if rank <= 2 then 0.22 else 0.28 }, { 1, 0 } },
		alpha = { { 0, if rank <= 2 then 0.5 else 0.3 }, { 0.6, 0.45 }, { 1, 1 } },
		accel = { 0, 0.8, 0 }, drag = 1.5, rot = { 0, 360 }, spin = { -60, 60 },
	})
	if rank >= 3 then
		-- her element (petals, snow, embers...) drifting round her, a few at a time
		for i, tex in e.textures do
			add({
				name = "Element" .. i, at = "Body", texture = tex,
				colors = { { 0, main:Lerp(WHITE, 0.35) }, { 1, main } }, light = e.light,
				rate = ({ 0, 0, 2, 2.5, 3.5, 4.5, 5 })[rank] / #e.textures, life = { 1.6, 2.6 },
				speed = { e.speed[1] + 0.5, e.speed[2] + 0.5 }, spread = 180,
				size = { { 0, 0 }, { 0.15, e.size * 0.7 }, { 0.85, e.size * 0.7 }, { 1, 0 } },
				alpha = { { 0, 0.25 }, { 0.8, 0.4 }, { 1, 1 } },
				accel = e.accel, drag = 1.2, rot = { 0, 360 }, spin = { -e.spin, e.spin },
			})
		end
		-- a puff where her feet land as she walks (her element's picture)
		add({
			name = "Steps", at = "Ground", texture = e.textures[1], stride = 1.6, count = if rank >= 5 then 3 else 2,
			colors = { { 0, white }, { 1, main } }, light = e.light,
			rate = 0, life = { 0.5, 0.9 }, speed = { 0.8, 1.6 }, spread = 60,
			size = { { 0, 0.15 }, { 0.2, e.size * 0.6 }, { 1, 0 } }, alpha = { { 0, 0.2 }, { 1, 1 } },
			accel = { 0, -0.5, 0 }, drag = 3, rot = { 0, 360 }, spin = { -90, 90 },
		})
	end
	if L.orbs > 0 then
		out.orbs = {
			count = L.orbs, radius = 1.5, speed = 2.2, bob = 0.25, height = 0.2, size = 0.3, trail = 0.45,
			tilt = ({ 0, 0, 0, 0, 16, 24, 30 })[rank], colors = { WHITE, main, deep }, ball = true,
		}
		if rank >= 7 then out.orbs.colors2 = { WHITE, accent, deep } end
	end
	if L.flames then
		local f = L.flames
		out.flames = { count = f[1], core = f[2], radius = 1.0, height = f[3], width = f[4], colors = { white, vivid(main), vivid(accent), deep } }
		out.beat = { every = L.beat, pre = 0.35, burst = 4 + 2 * (rank - 4), shock = true, slash = rank >= 6 }
		out.wake = { feet = true, hands = rank >= 6, colors = { WHITE, main, deep } }
		-- sparkles that burst out on the beat
		add({
			name = "Burst", at = "Body", texture = "Twinkle", flip = "Random", rate = 0,
			colors = { { 0, WHITE }, { 1, main:Lerp(WHITE, 0.3) } }, light = 1,
			life = { 0.5, 0.8 }, speed = { 3, 5 }, spread = 180,
			size = { { 0, 0 }, { 0.15, 0.45, 0.1 }, { 1, 0 } }, alpha = { { 0, 0 }, { 1, 0.3 } },
			accel = { 0, 0.5, 0 }, drag = 4, rot = { 0, 360 }, spin = { -60, 60 }, z = 0.5,
		})
		-- quick thin streaks rising off the floor round her (energy that moves)
		add({
			name = "Rising", at = "Ground", texture = "Spark", orient = "Streak",
			colors = { { 0, WHITE }, { 0.4, main:Lerp(WHITE, 0.4) }, { 1, main } }, light = 1,
			rate = ({ 0, 0, 0, 0, 3, 4.5, 6 })[rank], life = { 0.45, 0.75 }, speed = { 3.5, 5.5 }, spread = 8,
			size = { { 0, 0 }, { 0.2, 0.3 }, { 1, 0 } }, alpha = { { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
			squash = { { 0, 1.5 }, { 1, 2.5 } }, accel = { 0, 2, 0 }, drag = 0.5, rot = { 0, 0 }, spin = { 0, 0 },
		})
	end
	if rank >= 6 then
		-- a soft glint held on each hand
		for _, hand in { "RightHand", "LeftHand" } do
			add({
				name = "Glint" .. hand, at = hand, texture = "Glow", locked = true,
				colors = { { 0, WHITE }, { 1, main } }, light = 1,
				rate = 5, life = { 0.3, 0.5 }, speed = { 0, 0 }, spread = 0,
				size = { { 0, 0.55, 0.1 }, { 1, 0.25 } }, alpha = { { 0, 0.35 }, { 1, 1 } },
				accel = { 0, 0, 0 }, rot = { 0, 360 }, spin = { -30, 30 }, z = 0.3,
			})
		end
	end
	if rank >= 7 then
		-- Secret: the owner's crystals and butterflies drifting round her, and a halo over her head
		add({
			name = "Crystals", at = "Body", texture = "Crystal",
			colors = { { 0, WHITE }, { 1, accent } }, light = 1,
			rate = 1.5, life = { 1.6, 2.4 }, speed = { 0.6, 1.2 }, spread = 180,
			size = { { 0, 0 }, { 0.15, 0.4 }, { 0.85, 0.35 }, { 1, 0 } }, alpha = { { 0, 0.15 }, { 0.8, 0.3 }, { 1, 1 } },
			accel = { 0, 0.6, 0 }, drag = 1.5, rot = { 0, 360 }, spin = { -40, 40 },
		})
		add({
			name = "Butterflies", at = "Body", texture = "Butterfly", flip = "Loop", fps = 10,
			colors = { { 0, accent:Lerp(WHITE, 0.3) }, { 1, main } }, light = 0.7,
			rate = 0.8, life = { 2.2, 3 }, speed = { 0.8, 1.4 }, spread = 180,
			size = { { 0, 0 }, { 0.1, 0.55 }, { 0.9, 0.5 }, { 1, 0 } }, alpha = { { 0, 0.1 }, { 0.8, 0.25 }, { 1, 1 } },
			accel = { 0, 0.4, 0 }, drag = 1.2, rot = { -15, 15 }, spin = { -10, 10 },
		})
		out.halo = { radius = 0.55, colors = { WHITE, accent } }
	end
	if L.light then
		out.light = { color = main, brightness = L.light[1], range = L.light[2], at = "Body" }
	end
	if kind == "Showcase" then
		-- seen from the field 34 studs below: bolder tongues and bigger, wider orbiting lights; the flames sit closer
		-- behind her (from below, pushing them far back hides them behind her body)
		if out.flames then
			out.flames.width *= 1.3
			out.flames.behind = 1
		end
		if out.orbs then
			out.orbs.size, out.orbs.radius = 0.42, 1.8
		end
	end
	if out.beat and out.beat.slash then
		out.slashes = { rate = 1 / out.beat.every, life = 0.45, radius = 2.4, span = 120, width = 0.55,
			core = main:Lerp(WHITE, 0.4), edge = deep:Lerp(BLACK, 0.3), onBeat = true }
	end
	return out
end

-- How heavy a look is, for the budget (counted from the spec the way AuraFX builds it): emitters, particles
-- alive at once (rate x lifetime; puffs counted at 10 studs a second of walking), beams, parts, trails.
function AuraLook.budget(spec)
	local live = 0
	for _, e in spec.emitters do
		local per = if e.stride then (e.count or 1) * 10 / e.stride elseif e.every then (e.count or 1) / e.every else e.rate
		live += per * (e.life[1] + e.life[2]) / 2
	end
	if spec.beat then
		live += spec.beat.burst * 0.65 / spec.beat.every
	end
	local orbs = spec.orbs and spec.orbs.count or 0
	local parts = (spec.ground and 1 or 0) + (spec.beat and spec.beat.shock and 1 or 0) + (spec.halo and 1 or 0)
		+ (if spec.orbs and spec.orbs.ball then orbs else 0)
	local wake = spec.wake and ((spec.wake.feet and 2 or 0) + (spec.wake.hands and 2 or 0)) or 0
	return {
		emitters = #spec.emitters, live = live, parts = parts, trails = orbs + wake,
		beams = (spec.flames and (spec.flames.count + spec.flames.core) or 0) + (spec.slashes and 4 * 2 or 0),
	}
end

-- The beat (idle pulse with anticipation) at time t: energy (the flames' size: ~0.85 drawn in, ~1.3 on the
-- flare), shock (0-1: the ring running out over the floor, else -1) and the breathing (-1..1, a 2.6 s swell).
function AuraLook.beatAt(B, t)
	local breathe = math.sin(t * 2 * math.pi / 2.6)
	if not B then
		return 1 + 0.04 * breathe, -1, breathe
	end
	local u = t % B.every
	local energy = 1 + 0.05 * breathe
	local shock = -1
	if u > B.every - B.pre then
		local s = (u - (B.every - B.pre)) / B.pre
		energy -= 0.17 * s * s -- (draws in, faster at the end)
	elseif u < 0.8 then
		energy += 0.35 * math.exp(-u / 0.22) - 0.17 * math.max(0, 1 - u / 0.06) -- (snaps out, then settles)
		shock = u / 0.8
	end
	return energy, shock, breathe
end

-- Flame tongue i (outer ring, or the white inner ring when core): its fixed bend directions in her root's frame
-- (d0: leaving the floor, bulging out; d1: the tip curling in) and its angle round her.
function AuraLook.flameDirs(F, i, core)
	local n = if core then F.core else F.count
	local a = (i - 1) / n * math.pi * 2 + (if core then math.pi / n else 0.3)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(c, 1.3, s).Unit, Vector3.new(-c, 1.4, -s).Unit, a
end

-- Flame tongue i at time t (energy from beatAt): bottom and tip points (root frame, 5-stud body), the two curve
-- sizes and the two widths. It leaves the floor at her feet; the tip flickers above her head and sways.
function AuraLook.flameAt(F, i, core, t, energy, seed)
	local _, _, a = AuraLook.flameDirs(F, i, core)
	local c, s = math.cos(a), math.sin(a)
	local ph = (seed or 0) + i * 1.7 + (if core then 0.9 else 0)
	-- (they leave the floor just outside her outline and bulge past it, so they frame her silhouette from behind)
	local r0 = F.radius * (if core then 0.75 else 1.05)
	local flick = 0.75 + 0.15 * math.sin(t * 3.1 + ph) + 0.1 * math.sin(t * 7.3 + ph * 2.3)
	local h = F.height * (if core then 0.55 else 1) * flick * energy
	local sway = 0.22 * math.sin(t * 1.7 + ph)
	local p0 = Vector3.new(c * r0, -2.45, s * r0)
	local p1 = Vector3.new(c * r0 * 0.25 - s * sway, 2.2 + h, s * r0 * 0.25 + c * sway)
	local reach = F.radius * (if core then 1.1 else 1.7) * (0.85 + 0.15 * energy)
	local width = F.width * (if core then 0.45 else 1) * (0.8 + 0.2 * energy)
	return p0, p1, reach, F.radius * 0.9, width, 0.04
end

-- Orbiting light i of n at time t: its offset from her body centre (5-stud body). Odd ones go one way, even
-- ones the other, each on its own tilted orbit, so they cross in front of and behind her.
function AuraLook.orbitAt(O, i, n, t)
	local phase = (i - 1) / n * math.pi * 2
	local a = t * O.speed * (if i % 2 == 0 then -0.8 else 1) + phase
	local flat = Vector3.new(math.cos(a), 0, math.sin(a)) * O.radius
	local tilt = math.rad(O.tilt or 0) * ((i % 2) * 2 - 1) * (1 + (i - 1) * 0.25)
	local ct, st = math.cos(tilt), math.sin(tilt) -- (a turn about X)
	local bob = (O.height or 0) + math.sin(t * 2 * math.pi * 0.6 + phase) * (O.bob or 0)
	return Vector3.new(flat.X, flat.Y * ct - flat.Z * st + bob, flat.Y * st + flat.Z * ct)
end

return AuraLook
