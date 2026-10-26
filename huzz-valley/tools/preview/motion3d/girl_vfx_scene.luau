-- The girls' own effects after the Oct 18 rebuild (Shared/AuraLook.girl, the same data and maths Gameplay/AuraFX builds
-- in the game; owner: "they still look strange and low quality ... they just float there"). One shot per rarity:
-- Ryo (Common), Anko (Epic), Yuno (Legendary), Megumin (Mythic), C.C. (Secret), each as YOUR companion: she walks
-- behind you (the game's Shared/FollowMotion), you stop, she settles and idles (the beat, the breathing, the orbits).
-- Filmed close and low on her, 3/4 from the front. Then the Secret as the big prize over the map on her stand, from
-- the field below and from her level. A pink R15 stand-in body (the real girls are mostly R6).
-- sh video.sh girl_vfx_scene.luau out.mp4   (MOTION3D_KEEP=<dir> keeps the stills listed at the bottom)
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Sim = require("./aura_sim")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local AuraLook = Env.load(SHARED .. "AuraLook.lua")
local Looks = Env.load(SHARED .. "Config/GirlLooks.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion

local FPS, DT = 30, 1 / 30
local rad, sin, cos = math.rad, math.sin, math.cos
local SHOWS = { -- girl, rarity, name for the caption
	{ "CAC_R6_Zero57334_E2B7CE", "Common", "Ryo" },
	{ "CAC_R6_Master_Cheif4444_BB5C2C", "Epic", "Anko" },
	{ "CAC_R6_Raptus578_E86CB0", "Legendary", "Yuno" },
	{ "CAC_R6_ixKatsu_358858", "Mythic", "Megumin" },
	{ "CAC_R15_TransportViewer_DDEE6E", "Secret", "C.C." },
}
local EACH = 5
local STOP_AT = 2.3 -- seconds into each shot: you stop, she settles and idles
local SKY = 7 -- the big Secret over the map: 3.5 s from the field, 3.5 s from her level
local SECONDS = EACH * #SHOWS + SKY
local JOG = 10

local function scaleRig(rig, k)
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
local girl = named(scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" })))
do
	local _, size = bounds(girl)
	scaleRig(girl, Companion.Height / size.Y)
end
local centre, size = bounds(girl)
local rootHeight = -(centre.Position.Y - size.Y / 2)
-- floor tiles along the path (so you can see her move over the ground)
for z = 8, -200, -4 do
	scene:addBox(CFrame.new(-3.2, 0.05, z), Vector3.new(1.4, 0.1, 1.4), "#56606e")
	scene:addBox(CFrame.new(5.6, 0.05, z - 2), Vector3.new(1.4, 0.1, 1.4), "#56606e")
end
local follow = FollowMotion.new({ root = girl.root, motors = girl.motors, rootHeight = rootHeight, seed = 7, config = Companion })

-- the big her over the map on her stand (GirlService.showcase: a dark round top with a band in her colour)
local big = named(scene:addRig(Rig.r15("Showcase", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0" })))
scaleRig(big, 3)
big.root.CFrame = CFrame.new(0, -500, 0)
Rig.fk(big)
local standR = 2.2
local standTop = scene:addBox(CFrame.new(0, -500, 0), Vector3.new(0.5, standR * 2, standR * 2), "#221a42")
standTop.Shape = "cyl"
local standBand = scene:addBox(CFrame.new(0, -500, 0), Vector3.new(0.18, standR * 2 + 0.24, standR * 2 + 0.24), "#ebebff")
standBand.Shape, standBand.Neon, standBand.Alpha = "cyl", true, 0.85

local systems = {}
local shown = 0
local P = { pos = Vector3.zero, speed = 0, phase = 0 }
local FWD = Vector3.new(0, 0, -1)
local stills = {}
local skyBase
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local i = math.floor(t / EACH) + 1
	local skyShot = i > #SHOWS
	local caption
	if skyShot and shown <= #SHOWS then
		shown = i
		for _, s in systems do s.on = false end
		local look = AuraLook.lookFor(Looks, SHOWS[#SHOWS][1], nil)
		local spec = AuraLook.build(look, "Secret", "Showcase")
		skyBase = P.pos + Vector3.new(0, 34 + Rig.REST_HEIGHT * 3, -24)
		big.root.CFrame = Rig.lookAt(skyBase, skyBase + Vector3.new(0, 0, 1))
		Rig.fk(big)
		table.insert(systems, Sim.new(big, spec, { AuraLook = AuraLook, standRadius = standR }))
	elseif not skyShot and i ~= shown then
		shown = i
		for _, s in systems do s.on = false end
		local look = AuraLook.lookFor(Looks, SHOWS[i][1], nil)
		local comp = AuraLook.build(look, SHOWS[i][2], "Companion")
		comp.scale = Companion.Height / 5
		table.insert(systems, Sim.new(girl, comp, { AuraLook = AuraLook }))
		local b = AuraLook.budget(comp)
		print(string.format("%-9s %-7s emitters %d, particles alive ~%.0f, beams %d, parts %d, trails %d", SHOWS[i][2], SHOWS[i][3], b.emitters, b.live, b.beams, b.parts, b.trails))
	end

	local inShot = t - (i - 1) * EACH
	local target = if skyShot or inShot > STOP_AT then 0 else JOG
	P.speed += (target - P.speed) * math.min(1, DT * 5)
	if P.speed < 0.05 then P.speed = 0 end
	P.pos += FWD * P.speed * DT
	P.phase += P.speed * DT * 2 * math.pi / 5
	walkAnim(player, P.phase, math.min(1, P.speed / 12))
	local rootAt = P.pos + Vector3.new(0, Rig.REST_HEIGHT, 0)
	player.root.CFrame = Rig.lookAt(rootAt, rootAt + FWD)
	Rig.fk(player)
	FollowMotion.step(follow, DT, t, player.root.CFrame, function() return 0 end, player.parts.Head.CFrame.Position)
	Rig.fk(girl)

	local cam, look
	if skyShot then
		local k = t - EACH * #SHOWS
		local wob = sin(t * 1.1) * 0.6
		big.root.CFrame = Rig.lookAt(skyBase + Vector3.new(0, wob, 0), skyBase + Vector3.new(0, wob, 0) + Vector3.new(sin(t * 0.35) * 5, 0, 5))
		Rig.fk(big)
		local feet = skyBase + Vector3.new(0, wob - Rig.REST_HEIGHT * 3, 0)
		standTop.CFrame = CFrame.new(feet - Vector3.new(0, 0.27, 0)) * CFrame.Angles(0, 0, rad(90))
		standBand.CFrame = CFrame.new(feet - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, rad(90))
		if k < SKY / 2 then
			cam, look = P.pos + Vector3.new(7, 4, 14), skyBase + Vector3.new(0, -1, 0)
			caption = "Secret, the big prize over the map (from the field)"
		else
			cam, look = skyBase + Vector3.new(9, 3, 16), skyBase + Vector3.new(0, -1.5, 0)
			caption = "Secret, the big prize over the map (at her level)"
		end
	else
		-- close and low on her, from her right, a little in front (you stay to one side, not in front of her)
		local gp = girl.root.CFrame.Position
		cam = Vector3.new(gp.X + 5, 1.8, gp.Z - 2)
		look = Vector3.new(gp.X, 1.3, gp.Z)
		caption = string.format("%s (%s): %s", SHOWS[i][2], SHOWS[i][3], if inShot < STOP_AT + 0.4 then "walking" else "idle")
		if inShot > 1 and inShot <= 1 + DT then table.insert(stills, f) end
		if math.abs(inShot - 4.0) < DT / 2 then table.insert(stills, f) end
	end
	local sprites, ribbons, lights = {}, {}, {}
	local live = {}
	for _, s in systems do
		Sim.step(s, DT)
		Sim.draw(s, cam, sprites, ribbons, lights)
		if Sim.alive(s) then table.insert(live, s) end
	end
	systems = live
	if skyShot and math.abs(t - (EACH * #SHOWS + 1.5)) < DT / 2 then table.insert(stills, f) end
	if skyShot and math.abs(t - (EACH * #SHOWS + 5.5)) < DT / 2 then table.insert(stills, f) end
	scene:frame(cam, look, { sprites = sprites, ribbons = ribbons, lights = lights, caption = caption,
		bloom = { i = 0.55, size = 22, th = 1.5 } })
end
scene:save(nil, FPS, 1024, 576, { sky = "#8fa3ba", ground = "#3d4654", stills = stills })
