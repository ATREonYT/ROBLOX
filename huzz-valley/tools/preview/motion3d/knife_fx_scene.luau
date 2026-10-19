-- The knife effects ladder (owner, Oct 19 evening: "add some vfx ... make the knifes more advanced"; Oct 18: "dont
-- make it overly crazy"): one of his knives of each rarity, Common to Mythic, side by side, each slashing every 2 s
-- (staggered), drawn with Shared/KnifeLook's own numbers: the slash trail (KnifeLook.trailLook: every skin in its own
-- colour, Common and Uncommon faint), the glow light (KnifeLook.LADDER glow; render.mjs draws 4 lights, so the
-- Uncommon's faint one is left out), sparkles, Mythic's embers and the Legendary+ tip glint, simulated like their
-- ParticleEmitters (KnifeService.addFx). Particles in our assets/fx pictures (until the owner uploads them Studio
-- shows Roblox's sparkle). From the repo root:
--   KNIFE_MESHES=<python3 -I tools/knives/knife_meshes.py file> sh huzz-valley/tools/preview/motion3d/video.sh \
--     huzz-valley/tools/preview/motion3d/knife_fx_scene.luau out.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")

local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local SECONDS = tonumber(process.env.SECONDS or "") or 6
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end

local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local seedN = 777
local function rnd() seedN = (seedN * 1103515245 + 12345) % 2147483648; return seedN / 2147483648 end
local function range(a, b) return a + (b - a) * rnd() end
local WHITE = Color3.new(1, 1, 1)

local PICKS = { "ScoutDagger", "JadeKunai", "EmberEdge", "StormKunai", "SolarReaper", "AbyssEclipse" }
local scene = Scene.new()
scene:addBox(CFrame.new(0, -0.05, 0), Vector3.new(40, 0.1, 12), "#2a2a36")
local K = {}
for i, key in PICKS do
	local k, skin = baked[key], CoinShop.get(key)
	local look = KnifeLook.fx(skin.Rarity)
	K[i] = { key = key, k = k, skin = skin, look = look, x = (3.5 - i) * 2.8, per = k.studs / k.length,
		colour = KnifeLook.colour(skin) or WHITE, trail = KnifeLook.trailLook(skin, KnifeLook.element(key)),
		history = {}, parts = {}, acc = {}, phase = (i - 1) * 0.33 }
	K[i].reach = (k.tip - k.grip) * K[i].per
end

-- the swing: at rest tilted 25 degrees; every 2 s a cut from +70 to -110 degrees in 0.18 s, back in 0.5 s
local function angle(t)
	local u = t % 2
	if u < 0.18 then return math.rad(70 - 180 * (u / 0.18)) end
	if u < 0.68 then local a = (u - 0.18) / 0.5; a = a * a * (3 - 2 * a); return math.rad(-110 + 85 * a) end
	if u < 1.7 then return math.rad(-25) end
	local a = (u - 1.7) / 0.3; a = a * a * (3 - 2 * a)
	return math.rad(-25 + 95 * a)
end
local function cutting(t) return t % 2 < 0.2 end
local function handleAt(s, t)
	return CFrame.new(s.x, 2.2, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(angle(t + s.phase), 0, 0)
end

local FPS, SUB = 30, 4
local dt = 1 / FPS
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local meshes, sprites, ribbons, lights, labels = {}, {}, {}, {}, {}
	for i, s in K do
		local T = KnifeLook.TRAIL
		for q = SUB - 1, 0, -1 do
			local tt = t - q / (FPS * SUB)
			if cutting(tt + s.phase) then
				local h = handleAt(s, tt)
				table.insert(s.history, { t = tt, base = h * Vector3.new(0, s.reach * 0.3, 0), tip = h * Vector3.new(0, s.reach, 0) })
			end
		end
		local h = handleAt(s, t)
		local c = { (h * CFrame.new(0, -s.k.grip * s.per, 0) * TURN):GetComponents() }
		table.insert(meshes, { m = s.key, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = s.per })
		-- the trail: KnifeLook.trailLook's colours and see-through, over its Lifetime
		local keep = {}
		for _, e in s.history do if t - e.t <= T.Lifetime then table.insert(keep, e) end end
		s.history = keep
		if #keep >= 2 then
			local c0, c1 = hex(s.trail.colours[1]), hex(s.trail.colours[2])
			for band = 1, 4 do
				local u = (band - 0.5) / 4
				local pts, w, a, cs = {}, {}, {}, {}
				for n = #keep, 1, -1 do
					local e = keep[n]
					local p = e.base:Lerp(e.tip, u)
					local age = (t - e.t) / T.Lifetime
					table.insert(pts, { p.X, p.Y, p.Z })
					table.insert(w, (e.tip - e.base).Magnitude / 4 * 1.1)
					table.insert(a, (1 - (s.trail.transparency[1] + (s.trail.transparency[2] - s.trail.transparency[1]) * age)) * (0.4 + 0.6 * u))
					table.insert(cs, if age < 0.5 then c0 else c1)
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = c0, cs = cs, add = s.trail.light > 0.5 })
			end
		end
		-- the glow (the 4 brightest: Rare and up)
		local mid = h * Vector3.new(0, s.reach * 0.6, 0)
		if s.look.glow and i >= 3 then
			table.insert(lights, { p = { mid.X, mid.Y, mid.Z }, c = hex(s.colour), b = s.look.glow.brightness * 0.5, r = s.look.glow.range })
		end
		-- sparkles, embers, the tip glint (their ParticleEmitters in KnifeService.addFx)
		local function spawn(kind, n)
			for _ = 1, n do
				local p = if kind == "glint" then nil else h * Vector3.new(range(-0.05, 0.05), s.reach * range(0.3, 1), range(-0.12, 0.12))
				local dir = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
				table.insert(s.parts, { kind = kind, p = p, age = 0, rot = range(0, 360), f = math.floor(range(0, 3.99)),
					life = if kind == "spark" then range(0.5, 0.8) elseif kind == "ember" then range(1, 1.4) else range(0.45, 0.55),
					v = if kind == "spark" then dir.Unit * range(0.2, 0.6) elseif kind == "ember" then Vector3.new(0, range(0.1, 0.3), 0) else Vector3.zero })
			end
		end
		for kind, rate in { spark = s.look.sparkles or 0, ember = s.look.embers or 0, glint = if s.look.glint then 1 / s.look.glint else 0 } do
			s.acc[kind] = (s.acc[kind] or (if kind == "glint" then 0.2 * i else 0)) + rate * dt
			while s.acc[kind] >= 1 do s.acc[kind] -= 1; spawn(kind, 1) end
		end
		local keepP = {}
		for _, q in s.parts do
			q.age += dt
			if q.age < q.life then
				local a = q.age / q.life
				local pos, size, alpha, tex, col
				if q.kind == "spark" then
					q.v *= math.exp(-2 * dt); q.p += q.v * dt
					pos, size, alpha, tex = q.p, 0.16 * (if a < 0.2 then a / 0.2 else (1 - a) / 0.8), 1 - (0.1 + 0.5 * a), "twinkle"
					col = s.colour:Lerp(WHITE, 0.35):Lerp(s.colour, a)
				elseif q.kind == "ember" then
					q.v += Vector3.new(0, 1.2, 0) * dt; q.v *= math.exp(-dt); q.p += q.v * dt
					pos, size, alpha, tex, col = q.p, 0.12 * (1 - a), 1 - (0.2 + 0.8 * a), "spark", s.colour
				else
					pos = h * Vector3.new(0, s.reach, 0)
					size, alpha, tex = 0.55 * (if a < 0.4 then a / 0.4 else (1 - a) / 0.6), 0.85, "star-flare"
					col = s.colour:Lerp(WHITE, 0.7)
					q.rot += 60 * dt
				end
				table.insert(sprites, { p = { pos.X, pos.Y, pos.Z }, s = size * 1.3, c = hex(col), a = alpha, t = tex, r = q.rot, add = true,
					g = if tex == "twinkle" then 2 else nil, f = if tex == "twinkle" then q.f else nil })
				table.insert(keepP, q)
			end
		end
		s.parts = keepP
		table.insert(labels, { p = { s.x, 0.55, 0 }, text = s.skin.Rarity, h = 0.42, c = "#ffe28a", o = "#1e1228" })
		table.insert(labels, { p = { s.x, 0.05, 0 }, text = s.skin.Name, h = 0.32, c = "#ffffff", o = "#1e1228" })
	end
	scene:frame(Vector3.new(0, 2.9, -11.5), Vector3.new(0, 2.3, 0), { meshes = meshes, sprites = sprites, ribbons = ribbons, lights = lights,
		labels = labels, fov = 36, caption = "Knife effects by rarity (KnifeLook): trail in its own colour, glow, sparkles, Mythic embers, Legendary+ tip glint" })
end
local keepDir = process.env.MOTION3D_KEEP
scene:save(nil, FPS, 1280, 540, { meshFile = MESHES, sky = "#1c1c28", ground = "#2a2a36", grid = false,
	stills = if keepDir then { 3, 50 } else nil })
