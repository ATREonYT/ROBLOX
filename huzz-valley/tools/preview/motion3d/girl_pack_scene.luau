-- The anime girls on the owner's movement pack (Shared/GirlMoves), the game's own code, next to the old scripted
-- walk. A catcher (red, the pack's walk/run on him as Gameplay/Locomotion plays it) walks, runs a wide U-turn,
-- walks back and stops; two R6 girls follow him (Shared/FollowMotion with Config/Carry.Follow):
--   pink, beside him on his right: NOW (the pack: Idle / Walk / Run, feet planted)
--   grey, further back on the same side: BEFORE (the built-in scripted walk, Shared/GirlMotion.walk)
-- A prize girl (purple) stands where he stops, on the pack's Idle, turning her head to watch him come.
--   0-1.5 s stand, 1.5-4 s walk (5 studs/s), 4-8 s run (26, U-turn), 8-9.6 s walk back, 9.6-11 s stop
-- sh video.sh girl_pack_scene.luau out.mp4   (STILLS=1 keeps a few frames for a contact sheet: MOTION3D_KEEP=dir)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local folder = lib:FindFirstChild("HuzzAnimations")
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(folder:FindFirstChild(name))
end
local moves = assert(GirlMoves.load(folder), "pack didn't load")

local scene = Scene.new()
-- ground dots so foot sliding shows
for i = -10, 40 do
	for j = -6, 8 do
		scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end
local catcher = scene:addRig(Rig.r15("Catcher", { shirt = "#e0453a", pants = "#2b2f3a" }))
local now = scene:addRig(Rig.r6("Now", { shirt = "#f06aa8", pants = "#3b2f5c", hair = "#ffb0d0" }))
local before = scene:addRig(Rig.r6("Before", { shirt = "#9a9aa6", pants = "#55555f", hair = "#c8c8d0" }))
local prize = scene:addRig(Rig.r6("Prize", { shirt = "#9b6cf0", pants = "#2e2550", hair = "#c9a8ff" }))
local K = Carry.GirlLength / 5.25
for _, g in { now, before, prize } do Rig.scale(g, K) end
local rootHeight = 3 * K

-- the catcher's path (speed, turn) by time; the prize stands where he ends up, off to his side
local FPS, DT, SECONDS = 30, 1 / 30, 11
local function want(t) return if t < 1.5 then 0 elseif t < 4 then 5 elseif t < 8 then 26 elseif t < 9.6 then 5 else 0 end
local function turnAt(t) return if t > 5 and t < 6.4 then math.pi / 1.4 else 0 end
local endPos, endYaw
do
	local p, y, v = Vector3.zero, 0, 0
	for f = 0, SECONDS * FPS - 1 do
		local t = f * DT
		v += (want(t) - v) * (1 - math.exp(-DT * 8))
		y += turnAt(t) * DT
		p += Vector3.new(-math.sin(y), 0, -math.cos(y)) * v * DT
	end
	endPos, endYaw = p, y
end
local endLook = Vector3.new(-math.sin(endYaw), 0, -math.cos(endYaw))
local endRight = Vector3.new(math.cos(endYaw), 0, -math.sin(endYaw))
local prizeSpot = endPos + endLook * 4 - endRight * 5
local prizeAt = CFrame.lookAt(prizeSpot + Vector3.new(0, rootHeight, 0), endPos + Vector3.new(0, rootHeight, 0))
prize.root.CFrame = prizeAt
Rig.fk(prize)

local leftCfg = table.clone(Carry.Follow)
leftCfg.Offset = Carry.Follow.Offset + Vector3.new(0, 0, 6) -- (behind the pink one, same side: both in view)
local fNow = FollowMotion.new({ root = now.root, motors = now.motors, rootHeight = rootHeight, seed = 3, moves = moves })
local fBefore = FollowMotion.new({ root = before.root, motors = before.motors, rootHeight = rootHeight, seed = 3, config = leftCfg })
local pJ = GirlMotion.joints(prize.motors)
local pPack, pState = GirlMoves.new(moves, rootHeight), GirlMotion.new(5)

local mix = Mix.new()
local pos, yaw, speed = Vector3.new(0, 0, 0), 0, 0
local idleT = 0
local camPos
local stills = {}
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	speed += (want(t) - speed) * (1 - math.exp(-DT * 8))
	yaw += turnAt(t) * DT -- (a U-turn while running)
	local look = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	pos += look * speed * DT

	-- the catcher: idle/walk/run blended as Gameplay/Locomotion does
	Mix.step(mix, DT, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
	idleT += DT
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, catcher, at, w / total)
	end
	layer(A.Idle, idleT, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)
	catcher.root.CFrame = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT, 0)) * CFrame.Angles(0, yaw, 0)
	Rig.fk(catcher)

	local head = catcher.parts.Head.CFrame.Position
	local ground = function() return 0 end
	FollowMotion.step(fNow, DT, t, catcher.root.CFrame, ground, head)
	FollowMotion.step(fBefore, DT, t, catcher.root.CFrame, ground, head)
	Rig.fk(now)
	Rig.fk(before)
	-- the prize: the pack's Idle, watching the catcher (GirlMotion.look on top, as Gameplay/CarryAnimator)
	local d = (head - prize.root.CFrame.Position).Magnitude
	GirlMoves.idle(pPack, pJ, DT, GirlMotion.look(pState, pJ, DT, t, { target = head, distance = d }))
	Rig.fk(prize)

	-- camera: straight from the girls' side (his right), following the pink girl
	local girl = now.root.CFrame.Position
	local side = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local target = girl + side * 12 + look * 1.5 + Vector3.new(0, 2.5, 0)
	camPos = if camPos then camPos:Lerp(target, 0.35) else target
	local phase = if t < 1.5 then "STAND" elseif t < 4 then "WALK" elseif t < 8 then "RUN" elseif t < 9.6 then "WALK" else "STAND"
	scene:frame(camPos, girl + look * 1.5 + Vector3.new(0, 0.6, 0), { caption = "pink (front): owner's pack, now   grey (back): scripted, before   " .. phase })
	if process.env.STILLS and f % 30 == 15 then table.insert(stills, f) end
end
scene:save(nil, FPS, 1280, 720, { stills = stills })
