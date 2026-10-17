-- lune run tests/GirlMotion.spec.luau  (R6 and R15 limbs end up where the poses say, in world space)
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local GirlMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/GirlMotion.lua")

local failed = 0
local function check(ok, what)
	if not ok then
		failed += 1
		print("FAIL " .. what)
	end
end

-- Stock R6 rig (Roblox's own joint values, rotated C0/C1 included)
local function r6()
	local rig = { parts = {}, motors = {} }
	local function part(n, size) rig.parts[n] = { Name = n, Size = size, CFrame = CFrame.identity } return rig.parts[n] end
	part("HumanoidRootPart", Vector3.new(2, 2, 1)); part("Torso", Vector3.new(2, 2, 1)); part("Head", Vector3.new(2, 1, 1))
	for _, n in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do part(n, Vector3.new(1, 2, 1)) end
	local function m(name, p0, p1, c0, c1) table.insert(rig.motors, Rig.motor(name, rig.parts[p0], rig.parts[p1], c0, c1)) end
	local R = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	m("RootJoint", "HumanoidRootPart", "Torso", R, R)
	m("Neck", "Torso", "Head", CFrame.new(0, 1, 0) * R, CFrame.new(0, -0.5, 0) * R)
	m("Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	m("Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	m("Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	m("Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	rig.root = rig.parts.HumanoidRootPart
	return rig
end

-- Where a limb points in the world: down its own length (parts hang along -Y at rest).
local function limbDir(rig, partName)
	return -rig.parts[partName].CFrame.UpVector
end

for _, kind in { "R6", "R15" } do
	local rig = if kind == "R6" then r6() else Rig.r15("G")
	local J = GirlMotion.joints(rig.motors)
	check(J.LShoulder and J.RShoulder and J.LHip and J.RHip and J.Neck, kind .. " joints found")

	-- Lying face-up across shoulders (as CarryMath.holdRotation): gravity is toward her back (+Z).
	rig.root.CFrame = CFrame.new(0, 10, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0))
	local s = GirlMotion.new(1)
	for i = 1, 90 do
		GirlMotion.carried(s, J, 1 / 30, 50 + i / 30, { accel = Vector3.zero, forward = Vector3.new(0, 0, -1), mood = "Calm", moodAge = 0 })
		Rig.fk(rig)
	end
	local arm = limbDir(rig, if kind == "R6" then "Left Arm" else "LeftUpperArm")
	print(kind, "carried arm", arm)
	check(arm.Y < -0.8, kind .. " carried arm hangs down")

	-- Standing idle, no one near: arms hang by her sides, head up.
	rig.root.CFrame = CFrame.new(0, 3, 0)
	for _, m in rig.motors do m.Transform = CFrame.identity end
	local s2 = GirlMotion.new(2)
	s2.lastWave, s2.nextWave = 0, 1e9 -- no wave
	for i = 1, 30 do
		GirlMotion.idle(s2, J, 1 / 30, 100 + i / 30, { target = nil, distance = math.huge })
		Rig.fk(rig)
	end
	local idleArm = limbDir(rig, if kind == "R6" then "Right Arm" else "RightUpperArm")
	local leg = limbDir(rig, if kind == "R6" then "Left Leg" else "LeftUpperLeg")
	print(kind, "idle arm", idleArm, "leg", leg, "head up", rig.parts.Head.CFrame.UpVector)
	check(idleArm.Y < -0.95 and idleArm.X > 0, kind .. " idle arm down, slightly out")
	check(leg.Y < -0.97, kind .. " idle leg straight down")
	check(rig.parts.Head.CFrame.UpVector.Y > 0.95, kind .. " idle head upright")

	-- Waving: right arm goes up.
	s2.lastWave = 100 + 31 / 30 - 1
	GirlMotion.idle(s2, J, 1 / 30, 100 + 31 / 30, { target = nil, distance = math.huge })
	for i = 32, 50 do GirlMotion.idle(s2, J, 1 / 30, 100 + i / 30, { target = nil, distance = math.huge }) end
	Rig.fk(rig)
	local wave = limbDir(rig, if kind == "R6" then "Right Arm" else "RightUpperArm")
	print(kind, "wave arm", wave)
	check(wave.Y > 0.5, kind .. " waving arm is up")
end

print(failed == 0 and "GirlMotion ok" or `{failed} failed`)
if failed > 0 then
	error("tests failed")
end
