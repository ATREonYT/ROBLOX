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
	  Companion  on HER, the small companion walking behind you, the same ladder: motes (Common/Uncommon),
	             + element and a little light (Rare), + soft hand flames (Epic), stars, element and full hand
	             flames (Legendary up).
	  Showcase   on the big her over the map: the full Player look at 3x, her element all round her, slashes.
	Elements: Flame (embers), Frost (snow), Sakura (petals and hearts), Night (heavy dark wisps), Holy (feathers
	and gold stars), Storm (fast sparks), Nature (leaves), Water (bubbles); Sparkle = no look set.

	An emitter: { name, at = "RightHand" | "LeftHand" | "Body" | "Head" | "Feet", texture = a TEXTURES key,
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
			name = "Flame" .. hand, at = hand, texture = "Flame",
			colors = { { 0, c1 }, { 0.5, c1:Lerp(c2, 0.4) }, { 1, c2 } }, light = if soft then 0.6 else 1,
			rate = (if soft then 9 else 40 + 10 * math.max(0, rank - 3)) * k, life = { 0.3, 0.6 },
			speed = if soft then { 0.5, 1.1 } else { 1, 2.2 }, spread = 50,
			size = { { 0, 1.6 * grow }, { 0.4, 2.3 * grow }, { 1, 0.6 * grow } },
			alpha = if soft then { { 0, 0.6 }, { 0.5, 0.7 }, { 1, 1 } } else { { 0, 0.3 }, { 0.5, 0.45 }, { 1, 1 } },
			accel = if soft then { 0, 3, 0 } else { 0, 5, 0 }, drag = 2, rot = { -15, 15 }, spin = { -30, 30 }, z = 1.5, inherit = 0.85,
		})
		if soft then
			continue
		end
		table.insert(list, {
			name = "Core" .. hand, at = hand, texture = "Flame",
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

local function stars(look, rank, at, k)
	return {
		name = "Stars", at = at, texture = "Star",
		colors = { { 0, WHITE }, { 1, look.Colors[1] } }, light = 1,
		rate = (2.5 + rank) * k, life = { 0.8, 1.6 }, speed = { 0.6, 1.4 }, spread = 180,
		size = { { 0, 0 }, { 0.3, 0.3 }, { 1, 0 } }, alpha = { { 0, 0 }, { 1, 1 } },
		accel = { 0, 0.4, 0 }, drag = 2, rot = { 0, 360 }, spin = { -90, 90 },
	}
end

-- Common and up: a few faint, tiny motes in her colours drifting up from the feet (almost nothing).
local function motes(look, rank, at, k)
	return {
		name = "Motes", at = at, texture = "Star",
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
		if rank == 3 or rank == 4 then
			out.light = { color = c1, brightness = 0.25 + 0.15 * (rank - 3), range = 6, at = "Body" } -- a faint glow
		elseif rank >= 5 then
			out.light = { color = c1, brightness = 0.8 + 0.25 * (rank - 4), range = 8 + 2 * (rank - 4), at = "Body" }
		end
	elseif kind == "Companion" then
		table.insert(out.emitters, motes(look, rank, "Feet", 1))
		if rank >= 3 and rank <= 4 then
			add(elementField(look, rank, "Body", 0.4, if rank == 3 then 3 else 4, 1, true))
			if rank == 4 then
				add(handFlames(look, rank, 0.7, true))
			end
			out.light = { color = c1, brightness = 0.3 + 0.15 * (rank - 3), range = 5, at = "Body" }
		elseif rank >= 5 then
			table.insert(out.emitters, stars(look, rank, "Body", 1))
			add(elementField(look, rank, "Body", 0.5, 1.5, 1))
			add(handFlames(look, rank, 0.6))
			out.light = { color = c1, brightness = 0.6 + 0.15 * rank, range = 6 + rank, at = "Body" }
		end
	elseif kind == "Showcase" then
		local r = math.max(rank, 5)
		add(handFlames(look, r, 1))
		add(darkWisps(look, r, 1))
		add(elementField(look, r, "Body", 1.4, 6, 1.6))
		table.insert(out.emitters, stars(look, r, "Body", 2))
		out.slashes = slashes(look, r, 1)
		if out.slashes then
			out.slashes.rate = math.min(out.slashes.rate, 1) -- (everyone sees her: calm, kid-safe)
		end
		out.light = { color = c1, brightness = 2.5, range = 26, at = "Body" }
		out.scale = 3
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

return AuraLook
