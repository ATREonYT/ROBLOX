-- The Huss Valley sprint (Shared/RunMotion) over a stand-in run: 0-4 s a runner speeds up from a walk to a
-- full sprint, side on; 4-8 s a carrier sprints with her overhead (the carry arms layered on the run).
-- sh video.sh run_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local DownMotion = Env.load(SHARED .. "DownMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local FPS, DT, SECONDS = 30, 1 / 30, 8
local rad, sin, cos = math.rad, math.sin, math.cos

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
	M.RightWrist.Transform = CFrame.identity
	M.Waist.Transform = CFrame.identity
	M.Root.Transform = CFrame.new(0, -2.7 * (1 - cos(swing)) + 0.12 * math.abs(sin(phase)) * amount, 0)
end

local function mover(pos, facing)
	return { pos = pos, facing = facing, speed = 0, phase = 0 }
end
local function move(rig, m, target)
	m.speed += (target - m.speed) * math.min(1, DT * 5)
	local dir = Vector3.new(-sin(-m.facing), 0, -cos(-m.facing))
	m.pos += dir * m.speed * DT
	m.phase += m.speed * DT * 2 * math.pi / 5
	walkAnim(rig, m.phase, math.min(1, m.speed / 12))
	rig.root.CFrame = Rig.lookAt(m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0), m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)
end


local scene = Scene.new()
local runner = named(scene:addRig(Rig.r15("Runner", { shirt = "#2f6fe0", pants = "#262a36" })))
local carrier = named(scene:addRig(Rig.r15("Carrier", { shirt = "#2f6fe0", pants = "#262a36" })))
local girl = named(scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" })))
scale(girl, Carry.GirlLength / 5.9)
local centre, size = bounds(girl)
local carryRig = CarryMath.rig(carrier)
local carry = Rig.motor("HuzzCarryMotor", carrier.parts.UpperTorso, girl.root, CarryMath.holdC0(carryRig, size.Z), centre)
local carryRec = CarryMotion.new({ motor = carry, rig = carryRig, root = carrier.root, girlMotors = girl.motors, start = -10, seed = 7 })
local runRec = RunMotion.new(runner)
local carryRun = RunMotion.new(carrier)
carrier.root.CFrame = CFrame.new(Vector3.new(200, Rig.REST_HEIGHT, 0))
local R = mover(Vector3.new(0, 0, 0), rad(90))
local K = mover(Vector3.new(200, 0, 0), rad(90))
local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	if t < 4 then
		local target = if t < 0.8 then 8 else 24
		move(runner, R, target)
		RunMotion.step(runRec, DT, R.speed, true, false)
		Rig.fk(runner)
		Rig.fk(carrier, { carry }, { girl })
		local tgt = R.pos + Vector3.new(0, 3.5, -13)
		camPos = if camPos then camPos:Lerp(tgt, 0.15) else tgt
		scene:frame(camPos, R.pos + Vector3.new(0, 2.8, 0))
	else
		move(carrier, K, 23)
		RunMotion.step(carryRun, DT, K.speed, true, true)
		CarryMotion.step(carryRec, DT, t, "Calm", 99)
		Rig.fk(carrier, { carry }, { girl })
		local tgt = K.pos + Vector3.new(-3, 5, -15)
		camPos = if t - DT < 4 then tgt else camPos:Lerp(tgt, 0.15)
		scene:frame(camPos, K.pos + Vector3.new(0, 4.5, 0))
	end
end
scene:save(nil, FPS, 1280, 720)
