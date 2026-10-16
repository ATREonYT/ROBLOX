-- The anime girls' auras (Shared/AuraLook, the same data the game builds its ParticleEmitters and Beams from),
-- simulated and filmed 3/4 from the front like the owner's reference (video cf007d44), one shot per rarity
-- (owner: "not so strong on commons, rares, epics, just little"): Aqua (Water) as a Common, Rukia (Frost) as
-- a Rare, Yuno (Sakura) as an Epic, Nazuna (Night) as a Legendary and Megumin (Flame) as a Mythic (rarities
-- picked for the film, not theirs). The player jogs forward (faster in the last shot), then stops; his small
-- companion walks and runs behind him on the ground with the game's own Shared/FollowMotion and GirlMotion
-- (owner: "walk behind you, not fly"; a pink R15 stand-in, the real girls are mostly R6). Then the big girl
-- over the map, filmed from the field below.
-- sh video.sh aura_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local AuraLook = Env.load(SHARED .. "AuraLook.lua")
local Looks = Env.load(SHARED .. "Config/GirlLooks.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion

local FPS, DT = 30, 1 / 30
local rad, sin, cos = math.rad, math.sin, math.cos
local SHOWS = { -- girl, rarity, jog speed (studs/s)
	{ "CAC_R6_Kairvexa_EA0023", "Common", 9 }, -- Aqua
	{ "CAC_R6_GoodwinDakota422_AA2072", "Rare", 10 }, -- Rukia
	{ "CAC_R6_Raptus578_E86CB0", "Epic", 10 }, -- Yuno
	{ "CAC_R6_fivehomics_788B0C", "Legendary", 12 }, -- Nazuna
	{ "CAC_R6_ixKatsu_358858", "Mythic", 20 }, -- Megumin
}
local EACH = 4.4
local STOP_AT = 3.1 -- seconds into each shot: he stops, she settles and stands
local SKY = 4 -- then the girl over the map, filmed from the field below (the disc under her is gone)
local SECONDS = EACH * #SHOWS + SKY

local function scale(rig, k)
	for _, p in rig.parts do p.Size *= k end
	for _, m in rig.motors do
		m.C0 = CFrame.new(m.C0.Position * k) * m.C0.Rotation
		m.C1 = CFrame.new(m.C1.Position * k) * m.C1.Rotation
	end
	for _, d in rig.decor do
		d.offset = CFrame.new(d.offset.Position * k) * d.offset.Rotation
		d.Size *= k
	end
	Rig.fk(rig)
end
-- her body's box in her root's frame
local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		if not p.hidden then
			local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
local function named(rig)
	rig.byName = {}
	for _, m in rig.motors do rig.byName[m.Name] = m end
	return rig
end
-- Stand-in walk/jog for the player (as follow_scene)
local function walkAnim(rig, phase, amount)
	local M = rig.byName
	local swing = rad(32) * sin(phase) * amount
	M.RightHip.Transform = CFrame.Angles(swing, 0, 0)
	M.LeftHip.Transform = CFrame.Angles(-swing, 0, 0)
	M.RightKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, -sin(phase)) * amount, 0, 0)
	M.LeftKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, sin(phase)) * amount, 0, 0)
	M.RightShoulder.Transform = CFrame.Angles(-swing * 0.9, 0, 0)
	M.LeftShoulder.Transform = CFrame.Angles(swing * 0.9, 0, 0)
	M.RightElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.LeftElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.Root.Transform = CFrame.new(0, -2.7 * (1 - cos(swing)) + 0.12 * math.abs(sin(phase)) * amount, 0)
end

local scene = Scene.new()
local player = named(scene:addRig(Rig.r15("Player", { shirt = "#1d1f2a", pants = "#16171f", hair = "#3a5bd0" })))
player.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, 0), Vector3.new(0, Rig.REST_HEIGHT, -1))
Rig.fk(player)
-- the companion stand-in: a small pink girl rig, Companion.Height tall, standing on the ground
local girl = named(scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" })))
do
	local _, size = bounds(girl)
	scale(girl, Companion.Height / size.Y)
end
local centre, size = bounds(girl)
local rootHeight = -(centre.Position.Y - size.Y / 2)
print(string.format("companion: %.2f studs tall, root %.2f above her feet", size.Y, rootHeight))
-- stepping stones along the path (so you can see them move over the ground)
for z = 8, -240, -5 do
	scene:addBox(CFrame.new(-3.2, 0.05, z), Vector3.new(1.4, 0.1, 1.4), "#4a5361")
	scene:addBox(CFrame.new(5.6, 0.05, z - 2.5), Vector3.new(1.4, 0.1, 1.4), "#4a5361")
end
local follow = FollowMotion.new({ root = girl.root, motors = girl.motors, rootHeight = rootHeight, seed = 7, config = Companion })

-- (Lune has no Random: a small seeded one)
local state = 7
local rng = {}
-- the big her over the map: a 3x pink stand-in rig, 34 studs up
local big = scene:addRig(Rig.r15("Showcase", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0" }))
for _, p in big.parts do p.Size *= 3 end
for _, m in big.motors do
	m.C0 = CFrame.new(m.C0.Position * 3) * m.C0.Rotation
	m.C1 = CFrame.new(m.C1.Position * 3) * m.C1.Rotation
end
for _, d in big.decor do
	d.offset = CFrame.new(d.offset.Position * 3) * d.offset.Rotation
	d.Size *= 3
end
big.root.CFrame = CFrame.new(0, -500, 0)
Rig.fk(big)
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
	-- the rig's own speed (ParticleEmitter.VelocityInheritance: e.inherit of it goes into each new particle)
	local here = sys.rig.root.CFrame.Position
	local rigVel = if sys.lastAt and sys.rig == player then (here - sys.lastAt) / dt else Vector3.zero -- (her root is moved by CFrame in the game: no velocity)
	sys.lastAt = here
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
					v = dir * (e.speed[1] + rng:NextNumber() * (e.speed[2] - e.speed[1])) * scale + rigVel * (e.inherit or 0),
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
			local p0, pm, p1, t0, tm, t1, curve, alpha, width = AuraLook.slash(S, sl.seed, age, centre, scale)
			for _, layer in { { S.edge, 1.7, 0.15, false }, { S.core, 1, 0, true } } do
				local pts, w, a = {}, {}, {}
				for half = 1, 2 do
					local A, B = if half == 1 then p0 else pm, if half == 1 then pm else p1
					local tA, tB = if half == 1 then t0 else tm, if half == 1 then tm else t1
					local c0, c1 = A + tA * curve, B - tB * curve
					for k = (if half == 1 then 0 else 1), 8 do
						local u = k / 8
						local b = A * (1 - u) ^ 3 + c0 * 3 * (1 - u) ^ 2 * u + c1 * 3 * (1 - u) * u ^ 2 + B * u ^ 3
						table.insert(pts, { b.X, b.Y, b.Z })
						table.insert(w, width * layer[2] * (if half == 1 then u else 1 - u))
						table.insert(a, math.clamp(1 - (alpha + layer[3]), 0, 1))
					end
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(layer[1]), add = layer[4] })
			end
		end
	end
	sys.slashes = keep
end

local systems = {}
local shown = 0
local P = { pos = Vector3.zero, speed = 0, phase = 0 }
local FWD = Vector3.new(0, 0, -1)
local onGround, worstLag, behindFrames, frames = 0, 0, 0, 0
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local i = math.floor(t / EACH) + 1
	local skyShot = i > #SHOWS
	if skyShot and shown <= #SHOWS then
		shown = i
		for _, s in systems do s.on = false end
		local look = AuraLook.lookFor(Looks, SHOWS[#SHOWS][1], nil)
		local spec = AuraLook.build(look, SHOWS[#SHOWS][2], "Showcase")
		local at = P.pos + Vector3.new(0, 34 + Rig.REST_HEIGHT * 3, -24)
		big.root.CFrame = Rig.lookAt(at, at + Vector3.new(0, 0, 1))
		Rig.fk(big)
		table.insert(systems, system(big, spec))
	elseif not skyShot and i ~= shown then
		shown = i
		for _, s in systems do s.on = false end -- the last look's particles die away naturally
		local id, rarity = SHOWS[i][1], SHOWS[i][2]
		local look = AuraLook.lookFor(Looks, id, nil)
		table.insert(systems, system(player, AuraLook.build(look, rarity, "Player")))
		local comp = AuraLook.build(look, rarity, "Companion")
		comp.scale = Companion.Height / 5
		table.insert(systems, system(girl, comp))
	end

	-- the player jogs forward, then stops (he stands still through the sky shot)
	local inShot = t - (i - 1) * EACH
	local target = if skyShot or inShot > STOP_AT then 0 else SHOWS[i][3]
	P.speed += (target - P.speed) * math.min(1, DT * 5)
	if P.speed < 0.05 then P.speed = 0 end
	P.pos += FWD * P.speed * DT
	P.phase += P.speed * DT * 2 * math.pi / 5
	walkAnim(player, P.phase, math.min(1, P.speed / 12))
	local rootAt = P.pos + Vector3.new(0, Rig.REST_HEIGHT, 0)
	player.root.CFrame = Rig.lookAt(rootAt, rootAt + FWD)
	Rig.fk(player)

	-- the companion walks behind him on the ground (the game's own code)
	FollowMotion.step(follow, DT, t, player.root.CFrame, function() return 0 end, player.parts.Head.CFrame.Position)
	Rig.fk(girl)
	if not skyShot then
		frames += 1
		local gp = girl.root.CFrame.Position
		if math.abs(gp.Y - rootHeight) < 0.06 then onGround += 1 end
		local rel = player.root.CFrame:PointToObjectSpace(gp)
		if rel.Z > 1 then behindFrames += 1 end
		local spot = (player.root.CFrame * CFrame.new(Companion.Offset)).Position
		worstLag = math.max(worstLag, (Vector3.new(gp.X, 0, gp.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude)
	end

	cam = if skyShot then P.pos + Vector3.new(7, 4, 14) else P.pos + Vector3.new(9.2, 2.8, -3.6) -- (the particles' ZOffset faces it)
	local sprites, ribbons = {}, {}
	local live = {}
	for _, s in systems do
		stepSystem(s, DT)
		drawSystem(s, sprites, ribbons)
		if s.on or #s.particles > 0 or #s.slashes > 0 then table.insert(live, s) end
	end
	systems = live
	if skyShot then
		local base = P.pos + Vector3.new(0, 34 + Rig.REST_HEIGHT * 3, -24)
		big.root.CFrame = Rig.lookAt(base + Vector3.new(0, math.sin(t * 1.5) * 0.6, 0), base + Vector3.new(math.sin(t * 0.35) * 5, 0, 5))
		Rig.fk(big)
		scene:frame(cam, P.pos + Vector3.new(0, 36, -24), { sprites = sprites, ribbons = ribbons })
	else
		-- 3/4 from the front, on his right, tracking alongside; framing both of them
		scene:frame(cam, P.pos + Vector3.new(0.6, 2.1, 1.9), { sprites = sprites, ribbons = ribbons })
	end
end
print(string.format("companion on the ground %d/%d frames, behind him %d/%d, furthest from her spot %.1f studs", onGround, frames, behindFrames, frames, worstLag))
scene:save(nil, FPS, 1024, 768, { sky = "#5c6672", ground = "#2c333c" })
