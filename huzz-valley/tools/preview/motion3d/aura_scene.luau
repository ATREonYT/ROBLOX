-- The anime girls' auras (Shared/AuraLook, the same data the game builds its ParticleEmitters and Beams from),
-- simulated and filmed from the front like the owner's reference (video cf007d44): 4 seconds each of
-- Nazuna (Night, Legendary), Rukia (Frost, Epic), Yuno (Sakura, Legendary) and Megumin (Flame, Mythic), on a
-- player, with the girl's small companion floating beside them (a pink stand-in rig).
-- sh video.sh aura_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local AuraLook = Env.load(SHARED .. "AuraLook.lua")
local Looks = Env.load(SHARED .. "Config/GirlLooks.lua")

local FPS, DT = 30, 1 / 30
local SHOWS = {
	{ "CAC_R6_fivehomics_788B0C", "Legendary" }, -- Nazuna
	{ "CAC_R6_GoodwinDakota422_AA2072", "Epic" }, -- Rukia
	{ "CAC_R6_Raptus578_E86CB0", "Legendary" }, -- Yuno
	{ "CAC_R6_ixKatsu_358858", "Mythic" }, -- Megumin
}
local EACH = 4
local SECONDS = EACH * #SHOWS

local scene = Scene.new()
local player = scene:addRig(Rig.r15("Player", { shirt = "#1d1f2a", pants = "#16171f", hair = "#3a5bd0" }))
player.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, 0), Vector3.new(0, Rig.REST_HEIGHT, -1))
Rig.fk(player)
-- the companion stand-in: a small pink girl rig
local girl = scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0" }))
local K = 2.8 / 5.2
for _, p in girl.parts do p.Size *= K end
for _, m in girl.motors do
	m.C0 = CFrame.new(m.C0.Position * K) * m.C0.Rotation
	m.C1 = CFrame.new(m.C1.Position * K) * m.C1.Rotation
end
for _, d in girl.decor do
	d.offset = CFrame.new(d.offset.Position * K) * d.offset.Rotation
	d.Size *= K
end

-- (Lune has no Random: a small seeded one)
local state = 7
local rng = {}
function rng:NextNumber()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
function rng:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function sample(seq, t)
	for i = 1, #seq - 1 do
		local a, b = seq[i], seq[i + 1]
		if t <= b[1] then
			local f = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
			if typeof(a[2]) == "Color3" then
				return a[2]:Lerp(b[2], f)
			end
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return seq[#seq][2]
end

-- Where an emitter sits on a rig (as AuraFX's anchors).
local function anchorPos(rig, at, scale)
	local P = rig.parts
	if at == "RightHand" then return P.RightHand.CFrame.Position end
	if at == "LeftHand" then return P.LeftHand.CFrame.Position end
	if at == "Head" then return P.Head.CFrame.Position end
	if at == "Feet" then return rig.root.CFrame.Position - Vector3.new(0, 2.6 * scale, 0) end
	return P.UpperTorso.CFrame.Position
end

-- A running copy of one AuraLook spec on one rig: ParticleEmitter-like particles plus the slashes.
local function system(rig, spec)
	local sys = { rig = rig, spec = spec, particles = {}, acc = {}, slashes = {}, clock = 0, nextSlash = 0, seed = rng:NextInteger(1, 1e5), on = true }
	return sys
end
local function stepSystem(sys, dt)
	local spec, scale = sys.spec, sys.spec.scale or 1
	sys.clock += dt
	if sys.on then
		for i, e in spec.emitters do
			sys.acc[i] = (sys.acc[i] or 0) + e.rate * dt
			while sys.acc[i] >= 1 do
				sys.acc[i] -= 1
				-- a direction within `spread` degrees of straight up
				local yaw = rng:NextNumber() * math.pi * 2
				local tilt = math.rad(e.spread) * math.sqrt(rng:NextNumber())
				local dir = Vector3.new(math.sin(tilt) * math.cos(yaw), math.cos(tilt), math.sin(tilt) * math.sin(yaw))
				table.insert(sys.particles, {
					e = e, p = anchorPos(sys.rig, e.at, scale),
					v = dir * (e.speed[1] + rng:NextNumber() * (e.speed[2] - e.speed[1])) * scale,
					age = 0, life = e.life[1] + rng:NextNumber() * (e.life[2] - e.life[1]),
					rot = e.rot[1] + rng:NextNumber() * (e.rot[2] - e.rot[1]), spin = e.spin[1] + rng:NextNumber() * (e.spin[2] - e.spin[1]),
				})
			end
		end
		local S = spec.slashes
		if S and sys.clock >= sys.nextSlash then
			sys.nextSlash = sys.clock + (0.6 + rng:NextNumber() * 0.8) / S.rate
			sys.seed += 1
			table.insert(sys.slashes, { born = sys.clock, seed = sys.seed })
		end
	end
	local alive = {}
	for _, q in sys.particles do
		q.age += dt
		if q.age < q.life then
			local a = q.e.accel
			q.v += Vector3.new(a[1], a[2], a[3]) * scale * dt
			q.v *= math.max(0, 1 - (q.e.drag or 0) * dt)
			q.p += q.v * dt
			q.rot += q.spin * dt
			table.insert(alive, q)
		end
	end
	sys.particles = alive
end
local cam
local function drawSystem(sys, sprites, ribbons)
	local scale = sys.spec.scale or 1
	for _, q in sys.particles do
		local t = q.age / q.life
		local transparency = sample(q.e.alpha, t)
		local toward = (cam - q.p).Unit * (q.e.z or 0) * scale -- ZOffset: drawn that much closer to the camera
		local at = q.p + toward
		table.insert(sprites, {
			p = { at.X, at.Y, at.Z }, s = sample(q.e.size, t) * scale, c = hex(sample(q.e.colors, t)),
			a = math.clamp(1 - transparency, 0, 1), t = q.e.texture, r = q.rot, add = q.e.light > 0.5,
		})
	end
	local S = sys.spec.slashes
	if not S then
		return
	end
	local keep = {}
	for _, sl in sys.slashes do
		local age = sys.clock - sl.born
		if age <= S.life then
			table.insert(keep, sl)
			local centre = anchorPos(sys.rig, "Body", scale)
			local p0, p1, t0, t1, curve, alpha, width = AuraLook.slash(S, sl.seed, age, centre, scale)
			local c0, c1 = p0 + t0 * curve, p1 - t1 * curve
			for _, layer in { { S.edge, 1.9, 0.15, false }, { S.core, 1, 0, true } } do
				local pts, w, a = {}, {}, {}
				for k = 0, 16 do
					local u = k / 16
					local b = p0 * (1 - u) ^ 3 + c0 * 3 * (1 - u) ^ 2 * u + c1 * 3 * (1 - u) * u ^ 2 + p1 * u ^ 3
					table.insert(pts, { b.X, b.Y, b.Z })
					table.insert(w, width * layer[2] * u)
					local tr = if u < 0.45 then 1 + (math.min(1, alpha + layer[3] + 0.35) - 1) * (u / 0.45)
						else math.min(1, alpha + layer[3] + 0.35) + ((alpha + layer[3]) - math.min(1, alpha + layer[3] + 0.35)) * ((u - 0.45) / 0.55)
					table.insert(a, math.clamp(1 - tr, 0, 1))
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(layer[1]), add = layer[4] })
			end
		end
	end
	sys.slashes = keep
end

local systems = {}
local shown = 0
cam = Vector3.new(1.4, 3.9, -8.6)
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local i = math.floor(t / EACH) + 1
	if i ~= shown then
		shown = i
		for _, s in systems do s.on = false end -- the last look's particles die away naturally
		local id, rarity = SHOWS[i][1], SHOWS[i][2]
		local look = AuraLook.lookFor(Looks, id, nil)
		table.insert(systems, system(player, AuraLook.build(look, rarity, "Player")))
		local comp = AuraLook.build(look, rarity, "Companion")
		comp.scale = 2.8 / 5
		table.insert(systems, system(girl, comp))
	end
	-- a gentle idle sway on the player, the companion bobbing over his right shoulder
	player.byName = player.byName or {}
	for _, m in player.motors do player.byName[m.Name] = m end
	player.byName.RightShoulder.Transform = CFrame.Angles(0, 0, math.rad(-12 - 3 * math.sin(t * 2)))
	player.byName.LeftShoulder.Transform = CFrame.Angles(0, 0, math.rad(12 + 3 * math.sin(t * 2)))
	Rig.fk(player)
	local gp = Vector3.new(-3.8, Rig.REST_HEIGHT * K + 2.6 + math.sin(t * 2.2) * 0.25, 1.2)
	girl.root.CFrame = Rig.lookAt(gp, gp + Vector3.new(0, 0, -1))
	Rig.fk(girl)
	local sprites, ribbons = {}, {}
	local live = {}
	for _, s in systems do
		stepSystem(s, DT)
		drawSystem(s, sprites, ribbons)
		if s.on or #s.particles > 0 or #s.slashes > 0 then table.insert(live, s) end
	end
	systems = live
	scene:frame(cam, Vector3.new(-0.3, 3.4, 0), { sprites = sprites, ribbons = ribbons })
end
scene:save(nil, FPS, 1024, 768, { sky = "#5c6672", ground = "#2c333c", grid = false })
