-- Your companion girl dances when you dance (Gameplay/CompanionDance): the player (R15) plays the owner's dance, the
-- small R6 girl beside them gets the same dance through Shared/KeyframeSampler + Shared/DanceRetarget (the game's
-- own code), faded in and out over 0.3 s, on top of her stand pose from Shared/FollowMotion.
--   0-1 s    both standing
--   1-5 s    "Floss"
--   5-9 s    "Hype Up" (switching dances)
--   9-10.5 s stop: she fades back to standing
--   10.5-14 s a dance this screen can't read: the built-in dance (sway, bounce, arm waves)
-- sh video.sh dance_scene.luau out.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Sampler = Env.load(SHARED .. "KeyframeSampler.lua")
local Retarget = Env.load(SHARED .. "DanceRetarget.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local idle = KFS.load(lib:FindFirstChild("Idle", true))
local floss = KFS.load(lib:FindFirstChild("Dance_Floss", true))
local hype = KFS.load(lib:FindFirstChild("Dance_HypeUp", true))

local scene = Scene.new()
local player = scene:addRig(Rig.r15("Player", { shirt = "#3a5bd0", pants = "#22232c" }))
local girl = scene:addRig(Rig.r6("Girl"))
local HEIGHT = Companion.Height -- (Gameplay/Auras scales her to this)
Rig.scale(girl, HEIGHT / 5.25)
local rootHeight = 3 * HEIGHT / 5.25

player.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, 0), Vector3.new(0, Rig.REST_HEIGHT, 1)) -- facing the camera
local walk = FollowMotion.new({ root = girl.root, motors = girl.motors, rootHeight = rootHeight, seed = 7, config = Companion })
walk.beside = true -- (Gameplay/Auras: she steps beside you while you dance)

local FPS, DT, SECONDS = 30, 1 / 30, 14
local R15_HEIGHT = 5.2
local weight, t, mode = 0, 0, nil -- the girl's dance fade, time, and which dance
local playerW, playerAnim, playerT = 0, nil, 0
local function dance(time)
	if time >= 1 and time < 5 then return "floss", time - 1 end
	if time >= 5 and time < 9 then return "hype", time - 5 end
	if time >= 10.5 then return "unknown", time - 10.5 end
	return nil
end

for f = 0, SECONDS * FPS - 1 do
	local now = f * DT
	local which, at = dance(now)
	-- the player: idle, with the dance over it (Action, faded 0.25 s as UI/DancePlayer does)
	KFS.apply(idle, player, now)
	if which then
		playerAnim = if which == "floss" then floss elseif which == "hype" then hype else floss
		playerT = at
		playerW = math.min(1, playerW + DT / 0.25)
	else
		playerT += DT
		playerW = math.max(0, playerW - DT / 0.25)
	end
	if playerAnim and playerW > 0 then KFS.apply(playerAnim, player, playerT, playerW) end
	Rig.fk(player)

	-- the girl: her stand pose (Shared/FollowMotion), then the dance on top (Gameplay/CompanionDance's maths)
	FollowMotion.step(walk, DT, now, player.root.CFrame, function() return 0 end, player.parts.Head.CFrame.Position)
	if which then
		mode, t = which, at
	else
		t += DT
	end
	weight = math.clamp(weight + (if which then DT else -DT) / 0.3, 0, 1)
	if weight > 0 and mode then
		local w = weight * weight * (3 - 2 * weight)
		local scale = HEIGHT / R15_HEIGHT
		if mode == "unknown" then
			Retarget.procedural(walk.joints, t, w, scale)
		else
			Retarget.apply(walk.joints, Sampler.sample(if mode == "floss" then floss else hype, t), w, scale)
		end
	end
	Rig.fk(girl)
	scene:frame(Vector3.new(-3.4, 2.7, 5.2), Vector3.new(-1.2, 1.9, 0))
end
scene:save(nil, FPS, 1280, 720)
