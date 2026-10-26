-- lune run tests/CarryMath.spec.luau  (checks the pose maths on a stock R15 rig)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local function load(path, deps)
	local env = setmetatable({ CFrame = CFrame, Vector3 = Vector3, Color3 = roblox.Color3, script = { Parent = { Config = {} } } }, { __index = _G })
	env.require = function()
		return deps
	end
	return luau.load(fs.readFile(path), { environment = env })()
end
local Carry = load("src/ReplicatedStorage/Shared/Config/Carry.lua")
local M = load("src/ReplicatedStorage/Shared/CarryMath.lua", Carry)

local failed = 0
local function check(ok, what)
	if not ok then
		failed += 1
		print("FAIL " .. what)
	end
end

-- Stock blocky R15 joint values
local function motor(c0, c1)
	return { C0 = c0, C1 = c1 }
end
local function arm(sign)
	local x = -sign
	return {
		sign = sign,
		shoulder = motor(CFrame.new(x, 0.563, 0), CFrame.new(-x * 0.5 + x * 0.5, 0.392, 0)),
		elbow = motor(CFrame.new(0, -0.334, 0), CFrame.new(0, 0.259, 0)),
		wrist = motor(CFrame.new(0, -0.501, 0), CFrame.new(0, 0.125, 0)),
		hand = { Size = Vector3.new(1, 0.3, 1) },
	}
end
local neck = motor(CFrame.new(0, 0.8, 0), CFrame.new(0, -0.5, 0))
local head = { Size = Vector3.new(1.2, 1.2, 1.2), FindFirstChild = function(_, n) return n == "Neck" and neck or nil end }
local rig = { kind = "R15", torso = { Size = Vector3.new(2, 1.6, 1) }, head = head, arms = { arm(-1), arm(1) } }

-- Right arm (sign -1): upper arm should point up, a little forward and outward (+x)
local up = M.shoulderPose(-1, 1):VectorToWorldSpace(Vector3.new(0, -1, 0))
print("right upper arm dir", up)
check(up.Y > 0.9 and up.X > 0.1 and up.Z < 0, "right arm up/out/forward")
local upL = M.shoulderPose(1, 1):VectorToWorldSpace(Vector3.new(0, -1, 0))
check(upL.Y > 0.9 and upL.X < -0.1, "left arm up/out")
-- Forearm bends back in toward the head
local fore = (M.shoulderPose(-1, 1) * M.elbowPose(-1, Carry.Arms.ElbowBend)):VectorToWorldSpace(Vector3.new(0, -1, 0))
print("right forearm dir", fore)
check(fore.X < up.X, "right forearm turns inward")

-- Girl lies across, head to the left, face up (tilted toward the camera)
local r = M.holdRotation()
print("girl head dir", r.UpVector, "face dir", r.LookVector)
check(r.UpVector.X < -0.99, "head to the left")
check(r.LookVector.Y > 0.9 and r.LookVector.Z > 0.2, "face up, toward camera")

-- Height: hands of a 5-stud avatar reach about 2.3-2.7 studs above the torso centre
local h = M.holdHeight(rig, 1)
print("hold height", h)
check(h - 0.5 >= 0.8 + 0.5 + 0.6 + Carry.HairRoom - 1e-6, "clears the head")
check(h < 3.4, "hold height plausible")

-- Joint-space conversion is identity for an unrotated C0, and correct for R6's rotated C0
local r6 = { C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0) }
local pose = M.shoulderPose(-1, 1)
local t = M.inJoint(r6, pose)
local world = (r6.C0 * t).Rotation
local expected = (pose * r6.C0.Rotation)
check((world:VectorToWorldSpace(Vector3.new(0, -1, 0)) - expected:VectorToWorldSpace(Vector3.new(0, -1, 0))).Magnitude < 1e-4, "R6 joint conversion")

print(failed == 0 and "CarryMath ok" or `{failed} failed`)
if failed > 0 then
	error("tests failed")
end
