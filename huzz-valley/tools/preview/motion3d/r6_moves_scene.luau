-- Your R6 walk, run and stops as the game does them now (owner, Oct 23 08:36: "Send me some pictures ... And also
-- please send me the stopping animations"): his pack's R6Idle / R6Walk / R6Run blended by Shared/LocomotionMix with
-- Config/Run.LocoR6, the speed from Gameplay/Sprint (a walk at StartSpeed for WalkHold, then the 1 s build-up,
-- RunMotion.rampSpeed), the halt from a full run (Shared/Halt's slide, RunMotion.haltPush) with PlayerMoves' R6 plant
-- and brace (r6Stop), and a stop from a walk. Filmed side on, following.
--   0.0 - 0.5 s  standing
--   0.5 - 3.6 s  W held: the walk (its longer stride, Oct 23), the build-up, the run (lobby speed)
--   3.6 s        let go at full speed: the halt (slide, plant, brace), then standing
--   4.8 - 5.5 s  W tapped: only the walk
--   5.5 s        let go: a plain stop
-- sh video.sh r6_moves_scene.luau out.mp4   (repo root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for key, name in { Idle = "R6Idle", Walk = "R6Walk", Run = "R6Run" } do
	local seq = lib:FindFirstChild(name, true)
	assert(seq, "his R6 pack isn't in HuzzAnimations.rbxm (the public copy): put the private one in place")
	A[key] = KFS.load(seq)
end

local config = table.clone(Run.Loco)
for k, v in Run.LocoR6 do config[k] = v end

local scene = Scene.new()
for z = 10, -120, -4 do scene:addBox(CFrame.new(0, 0.02, z), Vector3.new(14, 0.04, 0.3), "#f4f4f4") end
for z = 10, -120, -8 do scene:addBox(CFrame.new(-4, 0.6, z), Vector3.new(0.5, 1.2, 0.5), "#2e6e3a") end
local rig = scene:addRig(Rig.r6("You", { shirt = "#26262e", pants = "#3a4a6a", skin = "#e9c29a", hair = "#1a1414" }))
local motor = {}
for _, m in rig.motors do motor[m.Part1.Name] = m end

local CAP, START, HOLD = Round.Speeds.Lobby, Run.StartSpeed, Run.WalkHold or 0
local FPS, DT, SECONDS, SUB = 30, 1 / 30, 6.6, 4
local function held(t) return (t >= 0.5 and t < 3.6) or (t >= 4.8 and t < 5.5) end

-- PlayerMoves' R6 stop: the plant's arms out (LocomotionMix.stopArm) and the halt's brace, turned into each joint
local B = { Turn = -30, Lean = 10, Front = 34, Back = -28, Arms = 38, ArmsForward = 14 }
local function turnJoint(name, turn)
	local m = motor[name]
	local r = m.C0.Rotation
	m.Transform = r:Inverse() * turn * r * m.Transform
end

local mix = Mix.new(config)
local z, built, last, halt, idleT = 0, 0, 0, nil, 0
for f = 0, math.floor(SECONDS * FPS) - 1 do
	local t = f * DT
	local speed = 0
	for _ = 1, SUB do
		local dt = DT / SUB
		if held(t) then
			halt = nil
			built += dt
			speed = if built < HOLD then START else RunMotion.rampSpeed(START, CAP, built - HOLD)
			last = speed
		else
			if last > 0 and not halt and RunMotion.haltFrom(last, CAP, START) then
				halt = { t = 0, cfg = RunMotion.haltPush(last) }
			end
			last, built = 0, 0
			if halt then
				speed = RunMotion.pushSpeed(halt.cfg, halt.t) or 0
				halt.t += dt
				if speed == 0 then halt.done = true end
			end
		end
		z -= speed * dt
	end
	local halting = halt ~= nil and not halt.done
	Mix.step(mix, DT, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length }, halt = halting })
	idleT += DT
	-- (the same blend PlayerMoves draws: LocomotionMix.pose, with the walk's longer stride and the hips' drop)
	local pose = Mix.pose(mix, A, idleT, KFS.sample)
	for name, cf in pose do
		if motor[name] then motor[name].Transform = cf end
	end
	if (mix.drop or 0) > 1e-3 then
		local m = motor.Torso
		m.Transform = CFrame.new(m.C0.Rotation:Inverse() * Vector3.new(0, -mix.drop, 0)) * m.Transform
	end
	local plant, brace = Mix.stopAmount(mix), Mix.brace(mix)
	if plant > 1e-4 or brace > 1e-4 then
		for _, side in { 1, -1 } do
			turnJoint(if side > 0 then "Right Arm" else "Left Arm", Mix.stopArm(mix, plant, side)
				* CFrame.Angles(math.rad(B.ArmsForward) * brace, 0, side * math.rad(B.Arms) * brace))
		end
		if brace > 1e-4 then
			turnJoint("Torso", CFrame.Angles(math.rad(B.Lean) * brace, math.rad(B.Turn) * brace, 0))
			turnJoint("Left Leg", CFrame.Angles(math.rad(B.Front) * brace, 0, 0))
			turnJoint("Right Leg", CFrame.Angles(math.rad(B.Back) * brace, 0, 0))
		end
	end
	rig.root.CFrame = CFrame.new(0, config.RootHeight, z)
	Rig.fk(rig)
	local what = if held(t) then (if built < HOLD then "WALK" elseif speed < CAP - 0.5 then "BUILDING UP" else "RUN")
		elseif halting or brace > 0.05 then "LET GO: THE HALT" elseif plant > 0.05 then "LET GO: STOP" else "STANDING"
	scene:frame(Vector3.new(13, 3.6, z - 2), Vector3.new(0, 2.4, z - 1), {
		caption = string.format("%.1f s   %s   %d studs/s", t, what, math.floor(speed + 0.5)),
	})
end
scene:save(nil, FPS, 1280, 720, { sky = "#5aa0e6", ground = "#3f9a45", grid = false })
