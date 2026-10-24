-- The catcher's stab before and after Oct 19 (owner: "better knife animations, not only during gameplay ..."),
-- side by side, standing, front three-quarter view: two stabs at full speed, then one at 1/4 speed.
--   left  BEFORE: the old Shared/StabMotion (STAB_OLD: a module path, e.g. the Oct 18 file copied next to the new one)
--         with what his place showed for the Inferno Knife then: our plain dagger in its colours, the 0.12 s trail;
--   right AFTER: today's Shared/StabMotion (wrist snap, deeper lean, same no-wind-up timing) with the Inferno
--         Knife's stand-in (Shared/KnifeShapes, until his import), its element trail (KnifeLook.TRAIL ElementLifetime,
--         tapered), the slash arc (KnifeLook.ARC, arcFade) and the element's burst and steady flames (KnifeLook.ELEMENTS,
--         half rate in hand), drawn with our assets/fx pictures (stand-ins in Studio until he uploads).
-- STAB_OLD=huzz-valley/src/ReplicatedStorage/Shared/StabMotionOld.lua sh video.sh stab_fx_scene.luau out.mp4
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local New = Env.load(SHARED .. "StabMotion.lua")
local Old = Env.load(process.env.STAB_OLD or error("set STAB_OLD"))
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local rad = math.rad

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local seedN = 777
local function rnd() seedN = (seedN * 1103515245 + 12345) % 2147483648; return seedN / 2147483648 end
local function range(a, b) return a + (b - a) * rnd() end

local KEY = "DragonsMaw"
local el = KnifeLook.element(KEY)
local glow = Color3.fromRGB(255, 122, 26)
local scene = Scene.new()
for i = -6, 6 do
	for j = -4, 4 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(3.8, 0.06, 3.8), if (i + j) % 2 == 0 then "#9aa3b0" else "#8e97a4") end
end

-- the knife's boxes in the hand (Handle space -> hand: KnifeLook.handC0 at the R15 grip)
local GRIP = KnifeLook.handC0(Vector3.new(0, -0.15, 0))
local function dagger()
	local dark, blade = "#201e26", hex(Color3.fromRGB(42, 17, 13))
	return {
		{ CFrame.new(0, 0, 0), Vector3.new(0.22, 0.75, 0.26), dark },
		{ CFrame.new(0, -0.42, 0), Vector3.new(0.26, 0.12, 0.3), dark },
		{ CFrame.new(0, 0.42, 0), Vector3.new(0.24, 0.1, 0.62), hex(glow), true },
		{ CFrame.new(0, 0.995, 0.02), Vector3.new(0.07, 1.05, 0.3), blade },
		{ CFrame.new(0, 1.66, 0.08), Vector3.new(0.07, 0.3, 0.16), blade },
	}, 0.595, 1.845
end
local function standin()
	local r = KnifeShapes.get(KEY)
	local out = {}
	for _, p in r.parts do
		local rot = p.rot or { 0, 0, 0 }
		local size = Vector3.new(p.size[1], p.size[2], p.size[3])
		local off = CFrame.new(p.at[1], p.at[2], p.at[3]) * CFrame.Angles(rad(rot[1]), rad(rot[2]), rad(rot[3]))
		if p.kind == "Wedge" then size = Vector3.new(size.X, size.Y, size.Z * 0.5); off = off * CFrame.new(0, 0, size.Z * 0.5) end
		table.insert(out, { off, size, hex(r.palette[p.paint]), p.mat == "Neon", p.kind == "Cylinder" })
	end
	return out, r.trail[1], r.trail[2]
end

local SIDES = {
	{ name = "BEFORE", mod = Old, x = 3.2, shirt = "#e0453a", knife = { dagger() }, life = KnifeLook.TRAIL.Lifetime, c0 = hex(glow), c1 = "#ffffff", taper = false },
	{ name = "AFTER", mod = New, x = -3.2, shirt = "#e0453a", knife = { standin() }, life = KnifeLook.TRAIL.ElementLifetime, c0 = hex(el.trail[1]), c1 = hex(el.trail[2]),
		taper = true, arc = true, element = true },
}
for _, s in SIDES do
	s.rig = scene:addRig(Rig.r15(s.name, { shirt = s.shirt, pants = "#2b2f3a" }))
	s.rig.root.CFrame = CFrame.new(s.x, Rig.REST_HEIGHT, 0) * CFrame.Angles(0, rad(-25), 0)
	s.rec = s.mod.new(CarryMath.rig(s.rig), s.rig.root)
	s.parts, s.base, s.tip = s.knife[1], s.knife[2], s.knife[3]
	s.boxes = {}
	for _, p in s.parts do
		local b = scene:addBox(CFrame.identity, p[2], p[3])
		if p[4] then b.Neon = true end
		if p[5] then b.Shape = "cyl" end
		table.insert(s.boxes, { box = b, off = p[1] })
	end
	s.history, s.particles, s.acc = {}, {}, {}
end

local FPS, DT, SUB = 30, 1 / 30, 4
local SECONDS = 6
local stabs = { 0.6, 1.8, 3.0 } -- the third at 1/4 speed
local clock = 0
local A = KnifeLook.ARC
local function bez(p0, p1, p2, p3, u)
	local v = 1 - u
	return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u)
end
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local slow = t >= 2.95 and t < 5.0
	local h = if slow then DT / 4 else DT
	local sprites, ribbons, labels = {}, {}, {}
	for k = SUB - 1, 0, -1 do
		local c = clock + h * (1 - k / SUB)
		for _, s in SIDES do
			for _, at in stabs do
				if t >= at and t - DT < at and k == SUB - 1 then
					s.mod.play(s.rec, c)
					s.arcStart = c + A.At
					if s.element then -- the burst: half the element's count
						s.burstPending = math.ceil(el.burst * 0.5)
					end
				end
			end
			for _, m in s.rig.motors do m.Transform = CFrame.identity end
			s.mod.step(s.rec, c)
			Rig.fk(s.rig)
			local hc = s.rig.parts.RightHand.CFrame * GRIP
			if s.mod.trailOn(s.rec, c) then
				table.insert(s.history, { t = c, base = hc * Vector3.new(0, s.base, 0), tip = hc * Vector3.new(0, s.tip, 0) })
			end
			s.hc = hc
		end
	end
	clock += h
	for _, s in SIDES do
		local hc = s.hc
		for _, b in s.boxes do b.box.CFrame = hc * b.off end
		-- trail
		local keep = {}
		for _, e in s.history do if clock - e.t <= s.life then table.insert(keep, e) end end
		s.history = keep
		if #keep >= 2 then
			for i = 1, 5 do
				local u = (i - 0.5) / 5
				local pts, w, a, cs = {}, {}, {}, {}
				for n = #keep, 1, -1 do
					local e = keep[n]
					local p = e.base:Lerp(e.tip, u)
					local age = (clock - e.t) / s.life
					table.insert(pts, { p.X, p.Y, p.Z })
					table.insert(w, (e.tip - e.base).Magnitude / 5 * 1.15 * (if s.taper then 1 - 0.65 * age else 1))
					table.insert(a, 0.75 * (1 - KnifeLook.TRAIL.Tinted[1]) * (1 - age) * (0.35 + 0.65 * u))
					table.insert(cs, if age < 0.35 then s.c0 else s.c1)
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = s.c0, cs = cs, add = true })
			end
		end
		-- the slash arc (a Beam: bezier from From to To, widths Width0 -> Width1, solid middle)
		if s.arc and s.arcStart then
			local fade = KnifeLook.arcFade(clock - s.arcStart)
			if fade < 1 then
				local root = s.rig.root.CFrame
				local p0, p3 = root * A.From, root * A.To
				local p1 = p0 + root:VectorToWorldSpace(Vector3.new(1, 0, 0)) * A.Curve
				local p2 = p3 - root:VectorToWorldSpace(Vector3.new(0, 0, 1)) * A.Curve
				local pts, w, a = {}, {}, {}
				for i = 0, 20 do
					local u = i / 20
					local p = bez(p0, p1, p2, p3, u)
					table.insert(pts, { p.X, p.Y, p.Z })
					table.insert(w, A.Width[1] + (A.Width[2] - A.Width[1]) * u)
					local tr = if u < 0.5 then 1 + (fade - 1) * (u / 0.5) else fade + (math.min(1, fade + 0.3) - fade) * ((u - 0.5) / 0.5)
					table.insert(a, 1 - tr)
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(el.trail[1]:Lerp(Color3.new(1, 1, 1), 0.3)), add = true })
			end
		end
		-- element: steady flames (half rate in hand) and the burst
		if s.element then
			local function spawn(spec, n, burst)
				for _ = 1, n do
					local p = hc * Vector3.new(range(-0.04, 0.04), s.base + (s.tip - s.base) * range(0.05, 1), range(-0.15, 0.15))
					local dir = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
					if dir.Magnitude < 0.01 then dir = Vector3.new(0, 1, 0) end
					table.insert(s.particles, { p = p, v = dir.Unit * (if burst then range(4, 8) else range(spec.speed[1], spec.speed[2])), age = 0,
						life = if burst then range(0.7, 1.2) else range(spec.life[1], spec.life[2]), spec = spec, burst = burst, rot = range(0, 360) })
				end
			end
			for i, spec in el.emit do
				s.acc[i] = (s.acc[i] or 0) + KnifeLook.elementRate(spec, "hand") * h
				while s.acc[i] >= 1 do s.acc[i] -= 1; spawn(spec, 1, false) end
			end
			if s.burstPending then spawn(el.emit[1], s.burstPending, true); s.burstPending = nil end
			local keepP = {}
			for _, q in s.particles do
				q.age += h
				if q.age < q.life then
					local spec = q.spec
					local acc = if q.burst then Vector3.new(0, -1, 0) elseif spec.accel then Vector3.new(spec.accel[1], spec.accel[2], spec.accel[3]) else Vector3.zero
					q.v = (q.v + acc * h) * math.exp(-(if q.burst then 4 else 1.5) * h)
					q.p += q.v * h
					local a = q.age / q.life
					local size = spec.size * (if q.burst then 1.2 * (1 - a) elseif spec.shrink then 1 - a else 1)
					table.insert(sprites, { p = { q.p.X, q.p.Y, q.p.Z }, s = size * 1.3, c = hex(spec.colours[1]:Lerp(spec.colours[2], a)), a = 0.9 * (1 - a),
						t = if spec.texture == "Flame" then "flame" else "spark", r = q.rot, add = true })
					table.insert(keepP, q)
				end
			end
			s.particles = keepP
		end
		local head = s.rig.parts.Head.CFrame.Position
		table.insert(labels, { p = { s.x, head.Y + 1.6, 0 }, text = s.name, h = 0.6, c = "#ffffff", o = "#1e1228" })
	end
	local u = New.progress(SIDES[2].rec, clock)
	local cap = (if slow then "1/4 speed" else "full speed") .. (if u >= 0 and u <= 1 then string.format("   stab %.2f s", u * Round.Stab.Time) else "")
	scene:frame(Vector3.new(-1.5, 5.6, -11.5), Vector3.new(0, 2.8, 0), { sprites = sprites, ribbons = ribbons, labels = labels, caption = cap, fov = 50 })
end
local keepDir = process.env.MOTION3D_KEEP
scene:save(nil, FPS, 1280, 720, { sky = "#9fd0f0", ground = "#8e97a4", grid = false,
	stills = if keepDir then { 20, 21, 22, 24, 26, 30, 94, 97, 100, 104 } else nil })
