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
local Sim = require("./aura_sim") -- (the particle simulation, shared with worn_scene.luau)
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
local cam
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
		table.insert(systems, Sim.new(big, spec, { AuraLook = AuraLook }))
	elseif not skyShot and i ~= shown then
		shown = i
		for _, s in systems do s.on = false end -- the last look's particles die away naturally
		local id, rarity = SHOWS[i][1], SHOWS[i][2]
		local look = AuraLook.lookFor(Looks, id, nil)
		table.insert(systems, Sim.new(player, AuraLook.build(look, rarity, "Player"), { AuraLook = AuraLook, inherit = true }))
		local comp = AuraLook.build(look, rarity, "Companion")
		comp.scale = Companion.Height / 5
		table.insert(systems, Sim.new(girl, comp, { AuraLook = AuraLook }))
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
		Sim.step(s, DT)
		Sim.draw(s, cam, sprites, ribbons)
		if Sim.alive(s) then table.insert(live, s) end
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
