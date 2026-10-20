-- The Combine machine on film (owner, Oct 20 14:57: "can you please anime this combine machine ... make nice
-- animations with vfx, gfx, sfx, and make a nice merging animation. Keep it smooth and tidy. and not too long";
-- 14:58 "also give the effects around the machine animations"). Three parts, 30 fps:
--   1. his machine idling (seen from the lobby, the COMBINE sign over it, then in close)
--   2. a whole merge, two Silver copies into one Gold, with the camera your screen gets
--   3. one girl in her four grades side by side: Normal, Silver, Gold, Diamond (each with its own small effect)
-- His machine is HIS parts from places/HUSSANIME.rbxl (where each one stands, its size and its name), drawn as
-- simple shapes picked by its name: the meshes and their colour pictures only show in Studio, so the shapes and
-- colours here are stand-ins matched by eye to his screenshot (design/owner-oct20/1457-combine-machine.png); the
-- girls are the scenes' usual box girl in Yuno's colours (Config/GirlLooks). The motion is the game's own numbers:
-- the timeline from Shared/CombineMotion, the idle and grade looks from Config/Combine, the idle maths as in
-- Gameplay/CombineMachine (ring parts turn round the ring, floor ticks round the altar, blade and orb float, his
-- flames drift, trim breathes), particles as its emitters say.
-- From the repo root: sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/combine_scene.luau huzz-valley/docs/previews/combine-machine.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
-- (Lune's CFrame.lookAt turns the wrong way, off Roblox's; the game's maths and ours use Roblox's, as the harness does)
CFrame = setmetatable({ lookAt = function(at, target) return Rig.lookAt(at, target) end }, { __index = roblox.CFrame })
Env.globals.CFrame = CFrame
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Motion = Env.load(SHARED .. "CombineMotion.lua")
local Config = Env.load(SHARED .. "Config/Combine.lua")

local FPS, DT = 30, 1 / 30
local UP = Vector3.new(0, 1, 0)
math.randomseed(20)
local rng = { NextNumber = function() return math.random() end }

local function hex(c) return "#" .. string.lower(c:ToHex()) end
local function mix(a, b, k) return a:Lerp(b, k) end
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- his machine, moved so its floor is y = 0 at the origin
local place = roblox.deserializePlace(fs.readFile(Env.root .. "/huzz-valley/places/HUSSANIME.rbxl"))
local model = place:GetService("Workspace").Combine.Combine_Machine
local parts = {}
local byBase = {}
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		local base = string.gsub(d.Name, "_%d+$", "")
		local p = { base = base, cf = d.CFrame, size = d.Size, holder = d.Parent and d.Parent.Name or "" }
		table.insert(parts, p)
		byBase[base] = byBase[base] or {}
		table.insert(byBase[base], p)
	end
end
local tier0 = byBase.shrine_tier[1]
local O = Vector3.new(tier0.cf.Position.X, tier0.cf.Position.Y - tier0.size.Y / 2, tier0.cf.Position.Z)
for _, p in parts do p.cf = p.cf - O; p.home = p.cf end
local ring = byBase.glow_summon_ring[1]
for _, p in byBase.glow_summon_ring do if p.size.X > ring.size.X then ring = p end end
local altar = byBase.altar_base[1]
local padA, padB = byBase.pad_cap[1], byBase.pad_cap[2]
local modelTop = 0
for _, p in parts do modelTop = math.max(modelTop, p.cf.Position.Y + p.size.Y / 2) end

-- the machine's frame (as Gameplay/CombineMachine works it out)
local function frameOf()
	local front = ring.cf.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	local padMid = (padA.cf.Position + padB.cf.Position) / 2
	local toPads = Vector3.new(padMid.X - ring.cf.Position.X, 0, padMid.Z - ring.cf.Position.Z)
	front = front.Unit
	if front:Dot(toPads) < 0 then front = -front end
	return {
		ring = ring.cf.Position, front = front,
		padA = padA.cf.Position + UP * (padA.size.Y / 2), padB = padB.cf.Position + UP * (padB.size.Y / 2),
		altar = altar.cf.Position + UP * (altar.size.Y / 2 + 0.6), height = Config.Merge.Height,
	}
end
local F = frameOf()
local SIDE = (F.padA - F.padB)
SIDE = Vector3.new(SIDE.X, 0, SIDE.Z).Unit

-- stand-in colours (his screenshot)
local COL = {
	shrine_tier = "#2b1d5e", tier_trim = "#e4ad4f", glow_tier_inlay = "#ff52d9", stair = "#3a2a80", ofuda = "#f3eee4",
	blade = "#2a1a52", glow_blade_edge = "#f4a6ff", glow_blade_rune = "#ff6be8", tsuba = "#e4ad4f", habaki = "#e4ad4f",
	blade_socket = "#e4ad4f", shimenawa = "#d9a46a", shide_zigzag = "#f7f4ff", rope_knot = "#d9a46a", tassel = "#c9213e",
	tassel_cord = "#c9213e", tassel_cap = "#e4ad4f", glow_summon_ring = "#ff63e6", glow_summon_arc = "#ff8ef0",
	glow_summon_dot = "#ffe3fb", glow_summon_tick = "#ff8ef0", glow_summon_gem = "#c98bff", glow_fusion_blade = "#c4f6ff",
	fusion_tsuba = "#e4ad4f", fusion_grip = "#3b2350", altar_base = "#e4ad4f", altar_trim = "#f2c46a",
	lotus_petal = "#5b2fa0", glow_lotus_petal = "#ffd6fb", glow_soul_orb = "#ffe6fb", glow_floor_ring = "#ff52d9",
	glow_floor_tick = "#ff8ef0", pad_base = "#e4ad4f", pad_trim = "#f2c46a", glow_pad = "#ffb8f3", pad_cap = "#2b1d5e",
	glow_pad_plus = "#ffffff", glow_pad_link = "#ff52d9",
}
local WISP = { "#ffc4ef", "#c4f3ff" }

-- shapes
local scene = Scene.new()
local boxes, ribbons, sprites, labels, lights = {}, {}, {}, {}, {}
local function box(cf, size, color, extra)
	local b = { CFrame = cf, Size = size, Color = color }
	if extra then for k, v in extra do b[k] = v end end
	table.insert(boxes, b)
end
-- a regular octagon (flat faces along the part's own axes) as four crossing boxes
local function octagon(cf, w, h, color, extra)
	local r = w / 2
	local short = 2 * r * math.tan(math.rad(22.5))
	for i = 0, 3 do
		box(cf * CFrame.Angles(0, i * math.pi / 4, 0), Vector3.new(2 * r, h, short), color, extra)
	end
end
local function circle(centre, normal, radius, width, color, alpha, from, to)
	local a = if math.abs(normal.Y) < 0.9 then normal:Cross(UP).Unit else normal:Cross(Vector3.new(1, 0, 0)).Unit
	local b = normal:Cross(a).Unit
	local pts, w, al = {}, {}, {}
	from, to = from or 0, to or 2 * math.pi
	local n = math.max(6, math.floor(48 * (to - from) / (2 * math.pi)))
	for i = 0, n do
		local t = from + (to - from) * i / n
		local p = centre + (a * math.cos(t) + b * math.sin(t)) * radius
		table.insert(pts, { p.X, p.Y, p.Z }); table.insert(w, width); table.insert(al, alpha or 1)
	end
	table.insert(ribbons, { pts = pts, w = w, a = al, c = color, add = true })
end

-- his parts moved as Gameplay/CombineMachine moves them (state: ring/floor angles, glow)
local I = Config.Idle
local angle = { a = 0, b = 0, floor = 0 }
local function idle(now, dt, ringMul, glow)
	angle.a += dt * (2 * math.pi / I.RingSpin) * ringMul
	angle.b -= dt * (2 * math.pi / I.ArcSpin) * ringMul
	angle.floor += dt * (2 * math.pi / I.FloorSpin) * (1 + (ringMul - 1) * 0.4)
	local axis = ring.home.LookVector
	local rc = ring.home.Position
	local ac = altar.home.Position
	local bob = math.sin(now * 2 * math.pi / I.Bob.Period) * I.Bob.Height
	local bladePivot = byBase.glow_fusion_blade[1].home.Position
	for _, p in parts do
		local home = p.home
		local b = p.base
		if b == "glow_summon_tick" or b == "glow_summon_gem" or b == "glow_summon_ring" then
			p.cf = CFrame.new(rc) * CFrame.fromAxisAngle(axis, angle.a) * CFrame.new(-rc) * home
		elseif b == "glow_summon_arc" or b == "glow_summon_dot" then
			p.cf = CFrame.new(rc) * CFrame.fromAxisAngle(axis, angle.b) * CFrame.new(-rc) * home
		elseif b == "glow_floor_tick" or b == "glow_floor_ring" then
			p.cf = CFrame.new(ac) * CFrame.fromAxisAngle(UP, angle.floor) * CFrame.new(-ac) * home
		elseif b == "glow_fusion_blade" or b == "fusion_tsuba" or b == "fusion_grip" then
			local sway = math.sin(now * 0.9) * math.rad(14)
			p.cf = CFrame.new(bladePivot + UP * bob) * CFrame.fromAxisAngle(UP, sway) * CFrame.new(-bladePivot) * home
		elseif b == "glow_soul_orb" then
			p.cf = (home + UP * (bob * 0.7)) * CFrame.Angles(0, now * 0.6, 0)
		elseif string.find(b, "^glow_spirit") then
			local seed = (#p.holder * 7.3 + string.byte(p.holder, -1) * 1.7) % 6.283
			local w = 2 * math.pi / I.Wisps.Period
			local D = I.Wisps.Drift
			p.cf = home + Vector3.new(math.sin(now * w + seed) * D, math.sin(now * w * 1.3 + seed * 2) * D * 0.8, math.cos(now * w * 0.8 + seed) * D)
		end
	end
	-- the trim's breath (his SurfaceAppearance glow; here a white fill on the glowing parts)
	local breathe = 1 + I.Glow.Pulse * math.sin(now * 2 * math.pi / I.Glow.Period)
	return math.clamp(0.12 * breathe + 0.45 * glow, 0, 0.75)
end

local function drawMachine(glowFill, hideBlade)
	local tierC = byBase.shrine_tier[1].home.Position
	for _, p in parts do
		local b, cf, s = p.base, p.cf, p.size
		local c = COL[b]
		local glowing = string.sub(b, 1, 5) == "glow_"
		local look = if glowing then { Neon = true, Emit = glowFill } else nil
		if b == "shrine_tier" or b == "tier_trim" then
			octagon(cf, s.X, s.Y, c)
		elseif b == "glow_tier_inlay" or b == "glow_floor_tick" then
			-- a glowing strip along the tier's face (round the middle)
			local radial = Vector3.new(cf.Position.X - tierC.X, 0, cf.Position.Z - tierC.Z)
			local len = if math.abs(s.X - s.Z) < 0.5 then s.X * math.sqrt(2) * 0.9 else math.max(s.X, s.Z)
			if b == "glow_floor_tick" then len = math.max(s.X, s.Z) end
			local tangent = if radial.Magnitude > 0.1 then UP:Cross(radial).Unit else Vector3.new(1, 0, 0)
			box(CFrame.lookAt(cf.Position, cf.Position + tangent), Vector3.new(0.22, math.max(s.Y, 0.14), len), c, look)
		elseif b == "blade_left" or b == "blade_right" then
			-- his arch blade: a curve from its foot up to the crossing at the top (the mesh's shape, simplified)
			local toOther = byBase[if b == "blade_left" then "blade_right" else "blade_left"][1].home.Position - p.home.Position
			local dir = Vector3.new(toOther.X, 0, toOther.Z).Unit
			local bottom = cf.Position.Y - s.Y / 2 + 0.6
			local cx = cf.Position + dir * (s.X / 2 - 0.4)
			local a, h = s.X - 1.2, s.Y - 0.8
			local prev = nil
			local edge, ew, ea = {}, {}, {}
			for i = 0, 16 do
				local th = (i / 16) * math.pi / 2
				local q = Vector3.new(cx.X, bottom, cx.Z) - dir * (a * math.cos(th)) + UP * (h * math.sin(th))
				if prev then
					local mid = (prev + q) / 2
					box(CFrame.lookAt(mid, q), Vector3.new(0.5, 0.95, (q - prev).Magnitude + 0.12), COL.blade)
				end
				local out = (q - (Vector3.new(cx.X, bottom, cx.Z))).Unit
				local e = q + out * 0.5
				table.insert(edge, { e.X, e.Y, e.Z }); table.insert(ew, 0.13); table.insert(ea, 0.9)
				prev = q
			end
			table.insert(ribbons, { pts = edge, w = ew, a = ea, c = COL.glow_blade_edge, add = true })
		elseif b == "glow_blade_edge" then
			-- (drawn with the blade)
		elseif b == "glow_summon_ring" then
			circle(cf.Position, cf.LookVector, s.X / 2 - 0.05, if s.X > 5.5 then 0.16 else 0.1, c, 0.95)
		elseif b == "glow_floor_ring" then
			circle(cf.Position + UP * 0.03, UP, s.X / 2 - 0.05, 0.14, c, 0.9)
		elseif b == "glow_summon_arc" then
			local rc = ring.cf.Position
			local rel = cf.Position - rc
			local axis = ring.cf.LookVector
			local ax = if math.abs(axis.Y) < 0.9 then axis:Cross(UP).Unit else axis:Cross(Vector3.new(1, 0, 0)).Unit
			local bx = axis:Cross(ax).Unit
			local at = math.atan2(rel:Dot(bx), rel:Dot(ax))
			circle(rc, axis, rel.Magnitude, 0.08, c, 0.9, at - 0.35, at + 0.35)
		elseif b == "glow_summon_dot" or b == "glow_summon_gem" or b == "glow_soul_orb" or b == "rope_knot" then
			box(cf, Vector3.one * math.max(s.X, s.Y, s.Z) * (if b == "glow_summon_dot" then 1.2 else 1), c, { Shape = "ball", Neon = glowing or nil, Emit = if glowing then glowFill else nil, Alpha = if b == "glow_soul_orb" then 0.9 else nil })
		elseif b == "lotus_petal" or b == "glow_lotus_petal" then
			box(cf, s, c, { Shape = "ball", Neon = glowing or nil, Emit = if glowing then glowFill else nil })
		elseif string.find(b, "^glow_spirit") then
			local idx = (string.byte(p.holder, -1) % 2) + 1
			local k = if b == "glow_spirit_flame" then 1 elseif b == "glow_spirit_tail" then 0.7 else 0.45
			box(cf, Vector3.one * math.max(s.X, s.Z) * k, WISP[idx], { Shape = "ball", Neon = true, Alpha = 0.88 })
		elseif b == "altar_base" or b == "altar_trim" or b == "pad_base" or b == "pad_trim" or b == "glow_pad" or b == "pad_cap" then
			octagon(cf, s.X, s.Y, c, look)
		elseif b == "glow_pad_plus" then
			local n = 0
			for _, q in byBase.glow_pad_plus do n += 1; if q == p then break end end
			box(cf * CFrame.Angles(0, math.pi / 4 + (n % 2) * math.pi / 2, 0), Vector3.new(0.85, 0.08, 0.18), c, look)
		elseif b == "shimenawa_strand" then
			-- his rope, sagging between the two knots
			local k1, k2 = byBase.rope_knot[1].cf.Position, byBase.rope_knot[2].cf.Position
			local pts, w, a = {}, {}, {}
			local lift = if p == byBase.shimenawa_strand[1] then 0 else 0.18
			for i = 0, 20 do
				local u = i / 20
				local q = k1:Lerp(k2, u) - UP * (math.sin(math.pi * u) * 0.9 - lift)
				table.insert(pts, { q.X, q.Y, q.Z }); table.insert(w, 0.32); table.insert(a, 1)
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = COL.shimenawa })
		elseif (b == "glow_fusion_blade" or b == "fusion_tsuba" or b == "fusion_grip") and hideBlade then
			-- (hidden while the girls are in the ring)
		elseif c then
			box(cf, s, c, look)
		end
	end
end

-- particles (as the emitters in Gameplay/CombineMachine and Shared/GirlGrade say)
local live = {}
local function emit(pos, vel, life, size, color, tex, accel, drag, add)
	table.insert(live, { p = pos, v = vel, age = 0, life = life, size = size, c = color, t = tex, acc = accel or Vector3.zero, drag = drag or 0, add = add })
end
local function rnd(a, b) return a + (b - a) * rng:NextNumber() end
local function inBox(cf, size)
	return (cf * CFrame.new(rnd(-0.5, 0.5) * size.X, rnd(-0.5, 0.5) * size.Y, rnd(-0.5, 0.5) * size.Z)).Position
end
local function unitRandom()
	local v = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1))
	return if v.Magnitude > 0.01 then v.Unit else UP
end
local acc = {}
local function rate(key, r, dt, fn)
	acc[key] = (acc[key] or rng:NextNumber()) + r * dt
	while acc[key] >= 1 do acc[key] -= 1; fn() end
end
-- one at a time on a fixed timer (the game's glints and ring sparkles: Shared/KnifeMotes.glint), first one offset
local clockOf = {}
local function every(key, period, dt, fn)
	clockOf[key] = (clockOf[key] or rng:NextNumber() * period) + dt
	if clockOf[key] >= period then clockOf[key] -= period; fn() end
end
local function stepParticles(dt)
	for i = #live, 1, -1 do
		local q = live[i]
		q.age += dt
		if q.age >= q.life then table.remove(live, i) else
			q.v = (q.v + q.acc * dt) * math.exp(-q.drag * dt)
			q.p += q.v * dt
		end
	end
end
local function drawParticles()
	for _, q in live do
		local k = q.age / q.life
		local s = q.size * (if k < 0.4 then k / 0.4 else 1 - (k - 0.4) / 0.6)
		local a = if k < 0.2 then k / 0.2 else 1 - math.max(0, k - 0.75) / 0.25
		table.insert(sprites, { p = { q.p.X, q.p.Y, q.p.Z }, s = math.max(0.02, s), c = q.c, a = a * 0.95, t = q.t, add = q.add ~= false })
	end
end

local function machineEmitters(dt, glow, inward, centre)
	local top = altar.cf.Position + UP * (altar.size.Y / 2)
	rate("motes", I.Motes.Rate, dt, function()
		emit(inBox(CFrame.new(top), Vector3.new(12, 0.2, 12)), UP * rnd(0.5, 1.1) + Vector3.new(rnd(-0.15, 0.15), 0, rnd(-0.15, 0.15)), rnd(I.Motes.Life * 0.8, I.Motes.Life), I.Motes.Size, hex(I.Motes.Color), "glow", UP * 0.25, 0.3)
	end)
	every("sparkles", I.Sparkles.Every, dt, function()
		emit(inBox(ring.cf, Vector3.new(5.6, 5.6, 0.6)), Vector3.zero, rnd(0.7, 1.1), I.Sparkles.Size, hex(I.Sparkles.Color), "twinkle")
	end)
	if inward then
		rate("inward", 40, dt, function()
			local d = unitRandom()
			local sp = rnd(6, 8)
			emit(centre + d * 4.5, -d * sp, rnd(0.5, 0.7), 0.35, hex(I.Motes.Color), "glow")
		end)
	end
end

-- a box girl (Yuno's colours) in a grade
local YUNO = { shirt = "#e86fa5", pants = "#3b2a5a", skin = "#f6d3b8", hair = "#ff9ec6", eyes = "#2a1a40" }
local function tint(hexc, c3)
	local c = Color3.fromHex(string.sub(hexc, 2))
	return hex(Color3.new(c.R * c3.R, c.G * c3.G, c.B * c3.B))
end
local function girl(name, grade, height)
	local g = Config.Grades[grade]
	local colors = table.clone(YUNO)
	if g and g.Hair then
		colors.hair = hex(g.Hair)
		colors.shirt = tint(YUNO.shirt, g.Cloth)
		colors.pants = tint(YUNO.pants, g.Cloth)
		-- her sheen (a Highlight fill in the grade's colour) lies over all of her; its rim only shows in Studio
		if g.Sheen then
			for k, v in colors do
				colors[k] = hex(Color3.fromHex(string.sub(v, 2)):Lerp(g.Sheen.Color, 1 - g.Sheen.Fill))
			end
		end
	end
	local rig = Rig.r6(name, colors)
	-- (more hair than the scenes' usual box girl: a fringe and two long side locks, so the grade's hair reads face on,
	-- as her real hairdo does in the game)
	local head = rig.parts.Head
	for _, d in { { CFrame.new(0, 0.45, -0.6), Vector3.new(1.35, 0.32, 0.2) }, { CFrame.new(-0.7, -0.35, 0), Vector3.new(0.26, 1.7, 0.9) }, { CFrame.new(0.7, -0.35, 0), Vector3.new(0.26, 1.7, 0.9) } } do
		table.insert(rig.decor, { part = head, offset = d[1], Size = d[2], Color = colors.hair })
	end
	local k = height / 5
	Rig.scale(rig, k)
	rig.k = k
	rig.grade = grade
	return rig
end
local function place(rig, feet)
	rig.root.CFrame = feet * CFrame.new(0, 3 * rig.k, 0)
	Rig.fk(rig)
end
local function gradeFx(key, rig, dt)
	local g = Config.Grades[rig.grade]
	local spec = g and g.Fx
	if not spec then return end
	local h = 5 * rig.k
	local kk = h / 5
	local boxCF = rig.root.CFrame + UP * (h * 0.1)
	local boxSize = Vector3.new(1.6 * kk, h * 0.8, 1.2 * kk)
	if spec.Glint then
		every(key .. "g", spec.Glint.Every, dt, function()
			emit(inBox(boxCF, boxSize), Vector3.zero, rnd(0.6, 1), spec.Glint.Size * kk, hex(spec.Glint.Color), "twinkle")
		end)
	end
	if spec.Motes then
		rate(key .. "m", spec.Motes.Rate, dt, function()
			emit(inBox(boxCF, boxSize), unitRandom() * rnd(0.15, 0.4) * kk, rnd(1.6, 2.4), spec.Motes.Size * kk, hex(spec.Motes.Color), "glow", UP * 0.5 * kk, 0.5)
		end)
	end
	if spec.Light then
		table.insert(lights, { p = { boxCF.Position.X, boxCF.Position.Y, boxCF.Position.Z }, c = hex(spec.Light.Color), b = spec.Light.Brightness, r = spec.Light.Range * math.max(kk, 0.5) })
	end
end

-- the sign over his arch (Config/Combine.Sign: a BillboardGui, white words, dark outline)
local S = Config.Sign
local function sign()
	local at = altar.cf.Position.Y + (modelTop - altar.cf.Position.Y) + S.Above + S.Height / 2
	local p = Vector3.new(altar.cf.Position.X, at, altar.cf.Position.Z)
	table.insert(labels, { p = { p.X, p.Y + 0.6, p.Z }, text = S.Text, h = S.Height * 0.62, c = "#ffffff", o = "#0b0f24" })
	table.insert(labels, { p = { p.X, p.Y - S.Height * 0.38, p.Z }, text = S.Sub, h = S.Height * 0.2, c = "#f3d9ff", o = "#0b0f24" })
end

local function lightsMachine(glow, now)
	local top = altar.cf.Position + UP * (altar.size.Y / 2)
	table.insert(lights, { p = { top.X, top.Y + 0.5, top.Z }, c = hex(I.Light.Color), b = I.Light.Brightness * (1 + 0.15 * math.sin(now * 2 * math.pi / I.Glow.Period) + 1.2 * glow), r = I.Light.Range })
end

local function flush(camPos, lookAt, extra)
	drawParticles()
	scene.boxes = boxes
	local e = extra or {}
	e.sprites, e.ribbons, e.labels, e.lights = sprites, ribbons, labels, lights
	e.bloom = e.bloom or { i = 0.6, size = 18, th = 1.4 }
	scene:frame(camPos, lookAt, e)
	boxes, ribbons, sprites, labels, lights = {}, {}, {}, {}, {}
	scene.rigs = {}
end

local centre = Motion.centre(F)
local frontCam = function(dist, up, swing)
	local c, s = math.cos(swing), math.sin(swing)
	local dir = Vector3.new(F.front.X * c + F.front.Z * s, 0, -F.front.X * s + F.front.Z * c)
	return centre + dir * dist + UP * up
end
local now = 0
local stills = {}
-- COMBINE_PART=3 films only part 3 (the grades side by side), for a quick look at the grade colours
local ONLY = require("@lune/process").env.COMBINE_PART
local SKIP = ONLY == "3"

-- 1. idle: from the lobby (sign readable), round to the front and in
local IDLE = 5
for f = 0, (if SKIP then -1 else IDLE * FPS - 1) do
	local t = f * DT
	local fill = idle(now, DT, 1, 0)
	machineEmitters(DT, 0, false, centre)
	stepParticles(DT)
	drawMachine(fill, false)
	sign()
	lightsMachine(0, now)
	local u = smooth(t / IDLE)
	local eye = frontCam(34 - 18 * u, 9 - 4.5 * u, 0.9 - 0.85 * u)
	local look = centre + UP * (5 - 3.5 * u)
	if f == 40 then table.insert(stills, #scene.frames) end
	flush(eye, look, { caption = "His machine, idle: ring turning, blade and orb floating, flames drifting, motes and sparkles" })
	now += DT
end

-- 2. a whole merge: two Silver Yunos into one Gold
local FROM, TO = "Silver", "Gold"
local H = Config.Merge.Height
local a, b, res = girl("A", FROM, H), girl("B", FROM, H), girl("R", TO, H)
local burstDone, ringFx = false, nil
local camFrom = frontCam(16, 4.5, 0.05)
local LOOK0 = centre + UP * 1.5
local LEN = Motion.LENGTH
for f = 0, (if SKIP then -1 else math.floor((LEN + 0.6) * FPS) - 1) do
	local t = f * DT
	local st = Motion.at(math.min(t, LEN - 1e-3), F)
	local ringMul = if t < LEN then st.ring else 1
	local glow = if t < LEN then st.glow else 0
	local fill = idle(now, DT, ringMul, glow)
	machineEmitters(DT, glow, t < LEN and st.inward, centre)
	-- the puffs on his pads as they appear
	if f == 0 then
		for _, pad in { F.padA, F.padB } do
			for _ = 1, 10 do emit(pad + UP * 1.2, unitRandom() * rnd(2, 4), rnd(0.3, 0.6), 0.35, hex(Config.Grades[FROM].Badge), "spark", UP * 3, 3) end
		end
	end
	if t < LEN then
		if st.a.show then place(a, st.a.cf); table.insert(scene.rigs, a); gradeFx("a", a, DT) end
		if st.b.show then place(b, st.b.cf); table.insert(scene.rigs, b); gradeFx("b", b, DT) end
		if st.result.show then place(res, st.result.cf); table.insert(scene.rigs, res); gradeFx("r", res, DT) end
		if st.burst then
			local col = hex(Config.Grades[TO].Badge)
			box(CFrame.new(centre), Vector3.one * st.burst.size, col, { Shape = "ball", Neon = true, Alpha = 1 - st.burst.transparency })
			table.insert(lights, { p = { centre.X, centre.Y, centre.Z }, c = col, b = 6 * st.flash, r = 18 })
			if not burstDone then
				burstDone = true
				ringFx = 0
				for _ = 1, 36 do emit(centre, unitRandom() * rnd(7, 12), rnd(0.5, 0.9), 0.45, if rng:NextNumber() < 0.5 then col else "#ffffff", "spark", UP * -4, 4) end
				table.insert(stills, #scene.frames)
			end
		end
	end
	-- the ring of light out through his ring (Burst.ring: 0.6 -> 5 studs in 0.55 s)
	if ringFx then
		ringFx += DT
		local k = ringFx / 0.55
		if k < 1 then
			local e = 1 - (1 - k) ^ 4
			circle(centre, F.front, 0.6 + 4.4 * e, 0.16 + 0.3 * (1 - k), hex(Config.Grades[TO].Badge), 1 - smooth((k - 0.55) / 0.45))
		end
	end
	stepParticles(DT)
	drawMachine(fill, t > 0.9 and t < Motion.HOLD_END)
	sign()
	lightsMachine(glow, now)
	local eye, look
	if t < LEN then
		local k = smooth(t / 0.5)
		eye = camFrom:Lerp(st.camera.eye, k)
		look = LOOK0:Lerp(st.camera.look, k)
	else
		local st2 = Motion.at(LEN - 1e-3, F)
		local k = smooth((t - LEN) / 0.6)
		eye = st2.camera.eye:Lerp(frontCam(16, 4.5, 0.05), k)
		look = st2.camera.look:Lerp(LOOK0, k)
	end
	-- the window's reveal ("GOLD YUNO!") from the burst until the merge ends
	local overlay = nil
	if t >= Motion.MERGE_AT and t < LEN + 0.4 then
		local k = math.min(1, (t - Motion.MERGE_AT) / 0.15)
		overlay = { texts = {
			{ text = "GOLD YUNO!", x = 340, y = 92, w = 600, h = 70 * (0.8 + 0.2 * k), c = hex(Config.Grades[TO].Badge), a = 1, o = "#0b0f24", ow = 3, italic = true, weight = 900 },
			{ text = "Two became one!", x = 440, y = 160, w = 400, h = 26, c = "#ffffff", a = 1, o = "#0b0f24", ow = 1.6, weight = 700 },
		} }
	elseif t < Motion.MERGE_AT then
		overlay = { texts = { { text = "TAP TO SKIP", x = 540, y = 668, w = 200, h = 22, c = "#c6cbe4", a = 1, o = "#0b0f24", ow = 1.2, weight = 700 } } }
	end
	flush(eye, look, { caption = "A merge: 2 Silver Yuno -> 1 Gold Yuno (your camera)", overlay = overlay })
	now += DT
end

-- 3. her four grades side by side, by the machine
local row = {}
local spacing = 4.6
local base = altar.cf.Position + F.front * 15
base = Vector3.new(base.X, 0, base.Z)
for i, g in { "Normal", "Silver", "Gold", "Diamond" } do
	local rig = girl("G" .. i, g, 5)
	local pos = base - SIDE * ((i - 2.5) * spacing) -- (Normal on the left as you look)
	row[i] = { rig = rig, pos = pos, grade = g }
end
live = {}
for f = 0, 5 * FPS - 1 do
	local t = f * DT
	local fill = idle(now, DT, 1, 0)
	machineEmitters(DT, 0, false, centre)
	for i, r in row do
		place(r.rig, CFrame.lookAt(r.pos + UP * (0.03 * math.sin(t * 2.4 + i)), r.pos + F.front))
		table.insert(scene.rigs, r.rig)
		gradeFx("row" .. i, r.rig, DT)
		local word = string.upper(r.grade)
		table.insert(labels, { p = { r.pos.X, 6.1, r.pos.Z }, text = word, h = 0.75, c = hex(Config.Grades[r.grade].Badge), o = "#0b0f24" })
	end
	stepParticles(DT)
	drawMachine(fill, false)
	lightsMachine(0, now)
	-- (a lobby lamp in front of them, a film stand-in: his lobby's own lamps light them in the game)
	local lamp = base + F.front * 7 + UP * 6
	table.insert(lights, { p = { lamp.X, lamp.Y, lamp.Z }, c = "#fff4e6", b = 1.6, r = 20 })
	local u = smooth(t / 5)
	local eye = base + F.front * (16 - 2 * u) + UP * (3.6 - 0.4 * u) + SIDE * (1.5 - 1.5 * u)
	if f == 75 then table.insert(stills, #scene.frames) end
	flush(eye, base + UP * 2.6, { caption = "Yuno in her four grades: Normal, Silver, Gold, Diamond" })
	now += DT
end

scene:save(nil, FPS, 1280, 720, { sky = "#a9b9d8", ground = "#b9733c", dim = 0.8, stills = stills })
