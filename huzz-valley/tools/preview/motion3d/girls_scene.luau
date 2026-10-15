-- The girl animations, run through the game's own code (CarryMotion, GirlMotion, CarryMath):
--   0-10.5 s  carry: pickup, walk, turn, hard stop, calm, stolen run (struggle), win (cheer)
--   10.5-16 s prize: she waits on the far side while a runner walks up (looks, waves, bounces)
-- sh video.sh girls_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local process = require("@lune/process")
local ORBIT = process.env.ORBIT ~= nil -- ORBIT=1: carrier stands still, camera circles (to judge the pose)
local FPS, DT = 30, 1 / 30
local rad, sin, cos = math.rad, math.sin, math.cos
local GIRL = { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" }

-- Scales a mock rig like Model:ScaleTo.
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

-- Bounding-box centre in the root's space, and the box size (as Model:GetBoundingBox).
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

-- A simple walk cycle for the stand-in animations (the game uses Roblox's or yours).
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

local function named(rig)
	rig.byName = {}
	for _, m in rig.motors do rig.byName[m.Name] = m end
	return rig
end

local scene = Scene.new()
local carrier = named(scene:addRig(Rig.r15("Carrier", { shirt = "#2f6fe0", pants = "#262a36" })))
local girl = named(scene:addRig(Rig.r15("Girl", GIRL)))
scale(girl, Carry.GirlLength / 5.9)
local centre, size = bounds(girl)

local carry = Rig.motor("HuzzCarryMotor", carrier.parts.UpperTorso, girl.root, CarryMath.holdC0(CarryMath.rig(carrier), size.Z), centre)
local START = 0.6
local carrierPos = Vector3.new(0, 0, 0)
local facing = 0 -- radians, 0 = -Z
local rec = CarryMotion.new({
	motor = carry, rig = CarryMath.rig(carrier), root = carrier.root, girlMotors = girl.motors,
	start = START, from = Vector3.new(0, size.Y / 2, -3.2), seed = 7,
})

-- Clip 2 cast, far away from clip 1
local PRIZE = Vector3.new(300, 0, 0)
local girl2 = named(scene:addRig(Rig.r15("Prize", GIRL)))
scale(girl2, Carry.GirlLength / 5.9)
local girl2Height = girl2.root.CFrame.Position.Y
girl2.root.CFrame = CFrame.new(PRIZE + Vector3.new(0, girl2Height, 0)) -- faces -Z, toward the runner
Rig.fk(girl2)
local runner = named(scene:addRig(Rig.r15("Runner", { shirt = "#e05a3a", pants = "#2b2f3a" })))
runner.root.CFrame = CFrame.new(PRIZE + Vector3.new(0, Rig.REST_HEIGHT, -40))
Rig.fk(runner)
local idleState, idleJoints = GirlMotion.new(3), GirlMotion.joints(girl2.motors)
scene:addBox(CFrame.new(PRIZE + Vector3.new(0, -0.45, 0)), Vector3.new(26, 1, 18), "#6fdc8c") -- safe zone

local speed, phase, camPos = 0, 0, nil
for f = 0, math.floor(16 * FPS) - 1 do
	local t = f * DT
	local mood, moodAge = "Excited", t - START
	if ORBIT then
		mood, moodAge = "Calm", 99
	elseif t >= 6.4 and t < 9 then
		mood, moodAge = "Struggle", t - 6.4
	elseif t >= 9 then
		mood, moodAge = "Cheer", t - 9
	end

	if t < 10.5 then
		-- Carrier path: stand, walk, turn right, hard stop, stand, run, stand
		local target = 0
		if ORBIT then target = 0 elseif t > 1.3 and t < 5 then target = 16 elseif t > 6.4 and t < 9 then target = 20 end
		if t >= 5 and t < 5.15 then speed = 0 else speed += (target - speed) * math.min(1, DT * 5) end
		if not ORBIT and t > 3.4 and t < 4.9 then facing -= DT * 1.1 end
		if not ORBIT and t > 7.2 and t < 8.2 then facing += DT * 1.4 end
		local dir = Vector3.new(-sin(-facing), 0, -cos(-facing))
		carrierPos += dir * speed * DT
		phase += speed * DT * 2 * math.pi / 5
		walkAnim(carrier, phase, math.min(1, speed / 12))
		carrier.root.CFrame = Rig.lookAt(carrierPos + Vector3.new(0, Rig.REST_HEIGHT, 0), carrierPos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)
		CarryMotion.step(rec, DT, t, mood, moodAge)
		Rig.fk(carrier, { carry }, { girl })
		if process.env.DUMP and math.abs(t - tonumber(process.env.DUMP)) < DT / 2 then
			for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
				print(n, carrier.root.CFrame:PointToObjectSpace(girl.parts[n].CFrame.Position))
			end
			print("carrier head", carrier.root.CFrame:PointToObjectSpace(carrier.parts.Head.CFrame.Position))
			print("carrier hands", carrier.root.CFrame:PointToObjectSpace(carrier.parts.LeftHand.CFrame.Position), carrier.root.CFrame:PointToObjectSpace(carrier.parts.RightHand.CFrame.Position))
		end
		local back = (CFrame.Angles(0, -facing + rad(-40), 0)).LookVector * -12
		local camTarget = carrierPos + back + Vector3.new(0, 6, 0)
		camPos = if camPos and t > 0 then camPos:Lerp(camTarget, 0.12) else camTarget
		if ORBIT then
			camPos = carrierPos + CFrame.Angles(0, t * 2 * math.pi / 10, 0):VectorToWorldSpace(Vector3.new(0, 4, 11))
		end
		scene:frame(camPos, carrierPos + Vector3.new(0, 5.5, 0))
	else
		-- Prize: runner walks up from 40 studs and stops 7 studs away
		local tt = t - 10.5
		local runnerDist = math.max(7, 40 - tt * 9)
		local moving = runnerDist > 7
		local rp = PRIZE + Vector3.new(4, 0, -runnerDist)
		walkAnim(runner, tt * 2 * math.pi * 1.8, if moving then 1 else 0)
		runner.root.CFrame = Rig.lookAt(rp + Vector3.new(0, Rig.REST_HEIGHT, 0), PRIZE + Vector3.new(0, Rig.REST_HEIGHT, 0))
		Rig.fk(runner)
		local head = runner.parts.Head.CFrame.Position
		GirlMotion.idle(idleState, idleJoints, DT, t, { target = head, distance = (head - PRIZE).Magnitude })
		Rig.fk(girl2)
		scene:frame(PRIZE + Vector3.new(-9, 5, -12), PRIZE + Vector3.new(0, 2.6, 0))
	end
end
scene:save(nil, FPS, 1280, 720)
