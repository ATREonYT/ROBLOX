-- A catcher tags the runner carrying her: she falls down and follows the catcher (Shared/FollowMotion).
--   0-1.8 s  the runner carries her, the catcher chases
--   1.8 s    tag: she drops off the runner's head and follows the catcher
--   1.8-10 s the catcher runs, turns, stops, walks, stops; she keeps up and stands when he stops
-- sh video.sh follow_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local FPS, DT, SECONDS = 30, 1 / 30, 10
local rad, sin, cos = math.rad, math.sin, math.cos
local TAG_AT = 1.8

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

-- Stand-in walk/run animation for the players.
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

-- A player moving along a path: position, facing, speed, walk phase.
local function mover(pos, facing)
	return { pos = pos, facing = facing, speed = 0, phase = 0 }
end
local function move(rig, m, target, turnRate)
	m.speed += (target - m.speed) * math.min(1, DT * 5)
	m.facing += (turnRate or 0) * DT
	local dir = Vector3.new(-sin(-m.facing), 0, -cos(-m.facing))
	m.pos += dir * m.speed * DT
	m.phase += m.speed * DT * 2 * math.pi / 5
	walkAnim(rig, m.phase, math.min(1, m.speed / 12))
	rig.root.CFrame = Rig.lookAt(m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0), m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)
end

local scene = Scene.new()
local runner = named(scene:addRig(Rig.r15("Runner", { shirt = "#2f6fe0", pants = "#262a36" })))
local catcher = named(scene:addRig(Rig.r15("Catcher", { shirt = "#e0453a", pants = "#2b2f3a" })))
local girl = named(scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" })))
scale(girl, Carry.GirlLength / 5.9)
local rootHeight = girl.root.CFrame.Position.Y -- root above her feet, standing on y = 0
local centre, size = bounds(girl)

local carry = Rig.motor("HuzzCarryMotor", runner.parts.UpperTorso, girl.root, CarryMath.holdC0(CarryMath.rig(runner), size.Z), centre)
local carryRec = CarryMotion.new({ motor = carry, rig = CarryMath.rig(runner), root = runner.root, girlMotors = girl.motors, start = -10, seed = 7 })
local follow = nil

local R = mover(Vector3.new(0, 0, 0), 0)
local C = mover(Vector3.new(-3, 0, 12), 0)
local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	if t < TAG_AT then
		move(runner, R, 15)
		move(catcher, C, 19, rad(-6))
	else
		move(runner, R, 0) -- caught: in the game he's sent to the bench
		local turn = if t > 3.6 and t < 5 then rad(60) elseif t > 7.4 and t < 8.2 then rad(-90) else 0
		local speed = if t < 5.6 then 18 elseif t < 6.2 then 0 elseif t > 7.2 and t < 9 then 8 else 0
		if t >= 5.6 and t < 5.75 then C.speed = 0 end
		move(catcher, C, speed, turn)
	end
	Rig.fk(catcher)

	if t < TAG_AT then
		CarryMotion.step(carryRec, DT, t, "Calm", 99)
		Rig.fk(runner, { carry }, { girl })
	else
		if not follow then
			for _, m in girl.motors do m.Transform = CFrame.identity end
			follow = FollowMotion.new({ root = girl.root, motors = girl.motors, from = girl.root.CFrame.Position, rootHeight = rootHeight, seed = 7 })
			print(string.format("tagged at %.2f s: she drops from y=%.1f", t, girl.root.CFrame.Position.Y))
		end
		Rig.fk(runner)
		FollowMotion.step(follow, DT, t, catcher.root.CFrame, function() return 0 end, catcher.parts.Head.CFrame.Position)
		Rig.fk(girl)
	end

	-- Camera: wide, behind and to the left of the catcher
	local back = CFrame.Angles(0, C.facing + rad(-35), 0).LookVector * -11
	local target = C.pos + back + Vector3.new(0, 5, 0)
	camPos = if camPos then camPos:Lerp(target, 0.1) else target
	scene:frame(camPos, C.pos + Vector3.new(0, 3, 0))
end
scene:save(nil, FPS, 1280, 720)
