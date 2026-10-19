-- The lobby stands with their BIG Game Pass knives (owner, Oct 19: "right now its very small and you dont even notice
-- it ... make the knife animations look like the ones i have attached in the video"), laid out like his reference
-- (design/lobby-ref/oct19-stands-ref.mp4: three stands in a row seen from the plaza): Inferno Knife (Dragon's Maw,
-- R6, the reference's PUMPKIN CLEAVER: low hold, spin slash, big arc), Sunrise Knife (Celestial Seraph, R15, its VIP
-- DAGGER: guard, quick flicks) and Hunter Knife (Crimson Requiem, R6, its VOWBREAKER: raised spin, petal burst).
-- The game's own code: Shared/StandShowcase (each knife's STYLE), KnifeLook.standScale (the size) and standWiden (round
-- 2: the blade broader than life, with KnifeService.display's see-through Neon glow shell), KnifeLook.ELEMENTS
-- (each knife's particles, simulated here like a ParticleEmitter: rate, life, speed, accel, drag, size, spin; the
-- burst when a move fires one; the tip glint), the slash trail over StandShowcase.TRAIL_LIFETIME in the element's
-- colours, the knife's light, the stand's glow disc and our sign words (not the reference's).
-- Particles are drawn with our assets/fx pictures, as they look once the owner has uploaded them (until then Studio
-- shows Roblox's sparkle and fire).
-- KNIFE_MODE=standin draws our plain-part stand-ins (Shared/KnifeShapes, what shows before his import) instead of his
-- meshes. From the repo root:
--   KNIFE_MESHES=/tmp/knives.json sh huzz-valley/tools/preview/motion3d/video.sh \
--     huzz-valley/tools/preview/motion3d/stand_knives_scene.luau /tmp/ours.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Show = Env.load(SHARED .. "StandShowcase.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua")

local STANDIN = process.env.KNIFE_MODE == "standin"
local MESHES = process.env.KNIFE_MESHES
if not STANDIN and not MESHES then error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>) or KNIFE_MODE=standin") end
local SECONDS = tonumber(process.env.SECONDS or "") or 10
local W, H = tonumber(process.env.W or "") or 960, tonumber(process.env.H or "") or 360
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
-- his meshes' blade extents (the "blade*" nodes, in .glb units): X is the blade's width, Y its length, Z its thickness
local bladeBox = {}
if MESHES then
	for key, parts in serde.decode("json", fs.readFile(MESHES)) do
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, q in parts do
			if string.sub(q.node or "", 1, 5) == "blade" then
				for i = 1, #q.pos, 3 do
					local v = Vector3.new(q.pos[i], q.pos[i + 1], q.pos[i + 2])
					lo, hi = lo:Min(v), hi:Max(v)
				end
			end
		end
		if lo.X < hi.X then bladeBox[key] = { lo = lo, hi = hi } end
	end
end

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle.
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local TEX = { Petal = "petal", Moon = "moon", Wisp = "wisp", Feather = "feather", Twinkle = "twinkle", Flame = "flame", Spark = "spark",
	Shard = "shard", Snow = "snow", StarFlare = "star-flare" }

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local seedN = 12345
local function rnd() seedN = (seedN * 1103515245 + 12345) % 2147483648; return seedN / 2147483648 end
local function range(a, b) return a + (b - a) * rnd() end

local scene = Scene.new()
for i = -6, 6 do
	for j = -4, 3 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(3.8, 0.06, 3.8), if (i + j) % 2 == 0 then "#c08a4a" else "#b07c40") end
end
local SET = {
	{ kind = "R6", key = "DragonsMaw", x = 10, seed = 4, accent = "#ff8a3d", shirt = "#1d1f27", pants = "#16171c", title = "INFERNO KNIFE" },
	{ kind = "R15", key = "CelestialSeraph", x = 0, seed = 9, accent = "#3ac0ff", shirt = "#1d1f27", pants = "#16171c", title = "SUNRISE KNIFE" },
	{ kind = "R6", key = "CrimsonRequiem", x = -10, seed = 14, accent = "#ff3344", shirt = "#1d1f27", pants = "#16171c", title = "HUNTER KNIFE" },
}
for _, s in SET do
	s.rig = scene:addRig(if s.kind == "R15" then Rig.r15(s.key, { shirt = s.shirt, pants = s.pants }) else Rig.r6(s.key, { shirt = s.shirt, pants = s.pants }))
	s.rig.root.CFrame = CFrame.new(s.x, if s.kind == "R15" then Rig.REST_HEIGHT else 3, 0) * CFrame.Angles(0, math.atan(s.x / 20), 0) -- (turned to the viewer, as AvatarStands turns them)
	s.rec = Show.new(s.rig, s.seed, s.key)
	s.k = baked[s.key]
	s.el = KnifeLook.element(s.key)
	s.history, s.particles, s.acc = {}, {}, {}
	if STANDIN then
		local recipe = KnifeShapes.get(s.key)
		local lo, hi = math.huge, -math.huge
		for _, p in recipe.parts do
			if not string.find(p.name, "Tassel") then lo, hi = math.min(lo, p.at[2] - p.size[2] / 2), math.max(hi, p.at[2] + p.size[2] / 2) end
		end
		s.scale = KnifeLook.standScale(hi - lo)
		local bw = 0
		for _, p in recipe.parts do if p.name == "Blade" then bw = p.size[3] * s.scale end end
		local thick, wide = KnifeLook.standWiden(bw)
		local fv = Vector3.new(thick, 1, wide)
		s.blade0 = recipe.trail[1] * s.scale
		s.tip = recipe.trail[2] * s.scale
		s.base = s.blade0 + (s.tip - s.blade0) * 0.45 -- (KnifeService's StandTrailBase)
		s.boxes = {}
		for _, p in recipe.parts do
			local rot = p.rot or { 0, 0, 0 }
			local turn = CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
			local grow = Vector3.new((turn.RightVector * fv).Magnitude, (turn.UpVector * fv).Magnitude, (turn.LookVector * fv).Magnitude)
			local size = Vector3.new(p.size[1], p.size[2], p.size[3]) * s.scale * grow
			local off = CFrame.new(Vector3.new(p.at[1], p.at[2], p.at[3]) * s.scale * fv) * turn
			if p.kind == "Wedge" then -- (a box at half depth on the tall side stands in for the wedge)
				size = Vector3.new(size.X, size.Y, size.Z * 0.5)
				off = off * CFrame.new(0, 0, size.Z * 0.5)
			end
			local b = scene:addBox(CFrame.identity, size, hex(recipe.palette[p.paint]))
			if p.kind == "Cylinder" then b.Shape = "cyl" end
			if p.mat == "Neon" then b.Neon = true end
			if p.mat == "Glass" then b.Alpha = 0.85 end
			table.insert(s.boxes, { box = b, off = off })
			if string.find(string.lower(p.name), "blade", 1, true) then -- the glow shell (KnifeLook.STAND.Shell see-through)
				local g = scene:addBox(CFrame.identity, size + Vector3.new(0.08, 0.04, 0.1), hex(s.el.light))
				g.Neon, g.Alpha, g.Add = true, 1 - KnifeLook.STAND.Shell, true
				table.insert(s.boxes, { box = g, off = off })
			end
		end
	else
		s.per = s.k.studs / s.k.length * KnifeLook.standScale(s.k.studs)
		s.tip = (s.k.tip - s.k.grip) * s.per
		local bb = bladeBox[s.key]
		local thick, wide = KnifeLook.standWiden(bb and (bb.hi.X - bb.lo.X) * s.per)
		s.sv = { s.per * wide, s.per, s.per * thick } -- (the mesh's own axes: width, length, thickness)
		local tw = if bb then (bb.hi.Z - bb.lo.Z) * s.per * thick else 0.1
		s.shellS = { s.sv[1] * 1.08, s.per * 1.01, s.sv[3] * (1 + 0.1 / math.max(tw, 0.05)) }
		s.blade0 = if bb then (bb.lo.Y - s.k.grip) * s.per else 0
		s.base = s.blade0 + (s.tip - s.blade0) * 0.45
	end
end

local function handleOf(s, pose)
	local hand = s.rig.parts.RightHand or s.rig.parts["Right Arm"]
	local gripAt = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	return hand.CFrame * CFrame.new(gripAt) * Show.knifeTurn(pose, KnifeLook.handC0(gripAt).Rotation)
end

local function spawn(s, spec, h, n, burst)
	for _ = 1, n do
		local u = range(0.05, 1)
		local p = if spec.tip then h * Vector3.new(0, s.tip, 0) else h * Vector3.new(range(-0.1, 0.1), s.blade0 + (s.tip - s.blade0) * u, range(-0.5, 0.5))
		local dir = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
		if dir.Magnitude < 0.01 then dir = Vector3.new(0, 1, 0) end
		local sp = if burst then range(4, 8) else range(spec.speed[1], spec.speed[2])
		table.insert(s.particles, {
			p = p, v = dir.Unit * sp, age = 0, life = if burst then range(0.7, 1.2) else range(spec.life[1], spec.life[2]), spec = spec, burst = burst,
			rot = range(0, 360), spin = if burst then range(-180, 180) else range(-(spec.spin or 0), spec.spin or 0), lock = spec.lock and not burst,
		})
	end
end

local FPS, SUB = 30, 4
local LIFE = Show.TRAIL_LIFETIME
local T = KnifeLook.TRAIL
local dt = 1 / FPS
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local meshes, lights, sprites, ribbons, labels = {}, {}, {}, {}, {}
	for _, s in SET do
		local pose
		for k = SUB - 1, 0, -1 do
			local tt = t - k / (FPS * SUB)
			pose = Show.step(s.rec, tt)
			Rig.fk(s.rig)
			local h = handleOf(s, pose)
			if pose.trail then
				table.insert(s.history, { t = tt, base = h * Vector3.new(0, s.base, 0), tip = h * Vector3.new(0, s.tip, 0) })
			end
		end
		local h = handleOf(s, pose)
		if STANDIN then
			for _, b in s.boxes do b.box.CFrame = h * b.off end
		else
			local cf = h * CFrame.new(0, -s.k.grip * s.per, 0) * TURN
			local c = { cf:GetComponents() }
			local r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }
			table.insert(meshes, { m = s.key, p = { c[1], c[2], c[3] }, r = r, s = s.sv })
			table.insert(meshes, { m = s.key, p = { c[1], c[2], c[3] }, r = r, s = s.shellS, shell = { c = hex(s.el.light), a = 1 - KnifeLook.STAND.Shell, only = "blade" } })
		end
		-- the knife's light (a stand's after the soft-lighting pass: range 4, brightness 0.6; render.mjs reads about
		-- twice Studio's)
		local mid = h * Vector3.new(0, (s.blade0 + s.tip) * 0.5, 0)
		table.insert(lights, { p = { mid.X, mid.Y, mid.Z }, c = hex(s.el.light), b = 0.3, r = 4 })
		table.insert(sprites, { p = { s.x, 0.08, 0 }, s = 4.5, c = s.accent, a = 0.5, t = "@disc", flat = true, add = true })
		-- element particles: steady emitters, the move's burst, the tip glint
		for i, spec in s.el.emit do
			s.acc[i] = (s.acc[i] or 0) + spec.rate * dt
			while s.acc[i] >= 1 do s.acc[i] -= 1; spawn(s, spec, h, 1, false) end
		end
		local id = if pose.burst then pose.loop * 10 + pose.burst else nil
		if id and s.lastBurst ~= nil and id ~= s.lastBurst then spawn(s, s.el.emit[1], h, s.el.burst, true) end
		s.lastBurst = id or s.lastBurst or -1
		s.glintAcc = (s.glintAcc or 0.7) + 0.4 * dt
		if s.glintAcc >= 1 then s.glintAcc -= 1; s.glint = 0 end
		if s.glint then
			s.glint += dt
			local g = s.glint / 0.5
			if g >= 1 then s.glint = nil else
				local tp = h * Vector3.new(0, s.tip, 0)
				local size = if g < 0.4 then 1.1 * g / 0.4 else 1.1 * (1 - g) / 0.6
				table.insert(sprites, { p = { tp.X, tp.Y, tp.Z }, s = size * 1.4, c = hex(s.el.light:Lerp(roblox.Color3.new(1, 1, 1), 0.7)), a = 0.9, t = "star-flare", r = s.glint * 60, add = true })
			end
		end
		local keepP = {}
		for _, q in s.particles do
			q.age += dt
			if q.age < q.life then
				local spec = q.spec
				local acc = if spec.accel then Vector3.new(spec.accel[1], spec.accel[2], spec.accel[3]) else Vector3.zero
				if q.burst then acc = Vector3.new(0, -1, 0) end
				q.v = (q.v + acc * dt) * math.exp(-(if q.burst then 4 else 1.5) * dt)
				q.p += q.v * dt
				q.rot += q.spin * dt
				local a = q.age / q.life
				local size = spec.size * (if q.burst then 1.2 * (1 - a) elseif spec.grow then (if a < 0.35 then a / 0.35 else (1 - a) / 0.65) elseif spec.shrink then 1 - a else (if a < 0.15 then a / 0.15 else 1 - 0.4 * (a - 0.15) / 0.85)) * math.max(1, KnifeLook.standScale(3.2) * 0.85)
				local tr = if q.burst then a elseif a < 0.15 then 1 - (1 - (if spec.faint then 0.55 else 0.1)) * a / 0.15 else (if spec.faint then 0.55 else 0.1) + (1 - (if spec.faint then 0.55 else 0.1)) * (a - 0.15) / 0.85
				local col = spec.colours[1]:Lerp(spec.colours[2], a)
				local pos = if q.lock then h * Vector3.new(0, s.tip, 0) else q.p
				table.insert(sprites, { p = { pos.X, pos.Y, pos.Z }, s = size * 1.3, c = hex(col), a = 1 - tr, t = TEX[spec.texture] or "glow", r = q.rot, add = true })
				table.insert(keepP, q)
			end
		end
		s.particles = keepP
		-- the slash trail in the element's colours
		local keep = {}
		for _, e in s.history do if t - e.t <= LIFE then table.insert(keep, e) end end
		s.history = keep
		if #keep >= 2 then
			local c0, c1 = hex(s.el.trail[1]), hex(s.el.trail[2])
			for i = 1, 5 do
				local u = (i - 0.5) / 5
				local pts, w, a, cs = {}, {}, {}, {}
				for n = #keep, 1, -1 do
					local e = keep[n]
					local p = e.base:Lerp(e.tip, u)
					local age = (t - e.t) / LIFE
					table.insert(pts, { p.X, p.Y, p.Z })
					table.insert(w, (e.tip - e.base).Magnitude / 5 * 1.15 * (1 - 0.7 * age))
					table.insert(a, 0.8 * (1 - T.Tinted[1]) * (1 - age) * (0.35 + 0.65 * u))
					table.insert(cs, if age < 0.4 then c0 else c1)
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = c0, cs = cs, add = true })
			end
		end
		local head = s.rig.parts.Head.CFrame.Position
		table.insert(labels, { p = { s.x, head.Y + 2.2, 0 }, text = s.title, h = 0.9, c = "#ffffff", o = "#1e1228" })
	end
	scene:frame(Vector3.new(0, 9, -20), Vector3.new(0, 3.2, 0), { meshes = meshes, lights = lights, sprites = sprites, ribbons = ribbons,
		labels = labels, fov = 36 })
end
local keepDir = process.env.MOTION3D_KEEP
scene:save(nil, FPS, W, H, { meshFile = MESHES, sky = "#8fc8f0", ground = "#b07c40", grid = false, stills = if keepDir then { 30, 75, 120, 165, 210, 255 } else nil })
