-- lune run tests/R6Huss.spec.luau  (Shared/R6HussPose: the game's huss on six rigid blocks; owner, Oct 22 17:21)
-- On a stock R6 body standing on the floor: the outside foot planted on it, the inside foot just off it, the body
-- lower, tipped into the move and leaning forward, fists in front; the other way is its mirror.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local Pose = Env.load("huzz-valley/src/ReplicatedStorage/Shared/R6HussPose.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local function posed(side)
	local rig = Rig.r6("H")
	rig.root.CFrame = CFrame.new(0, 3, 0) -- (standing: the floor at 0, facing -Z)
	local motors = {}
	for _, m in rig.motors do motors[m.Part1.Name] = m end
	Pose.pose(motors, side, 1, 1)
	Rig.fk(rig)
	return rig.parts
end
local function foot(p) return (p.CFrame * CFrame.new(0, -1, 0)).Position end

for _, side in { 1, -1 } do
	local P = posed(side)
	local lead, trail = if side > 0 then "Right" else "Left", if side > 0 then "Left" else "Right"
	local name = if side > 0 then "right" else "left"
	local planted, lifted = foot(P[trail .. " Leg"]), foot(P[lead .. " Leg"])
	check(math.abs(planted.Y) < 0.05, string.format("huss %s: the outside foot is on the floor (%.2f)", name, planted.Y))
	check(lifted.Y > 0.1 and lifted.Y < 0.6, string.format("huss %s: the inside foot just off it (%.2f)", name, lifted.Y))
	check(planted.X * side < -1.2 and lifted.X * side > 0.8, string.format("huss %s: legs spread wide (%.2f, %.2f)", name, planted.X, lifted.X))
	local torso = P.Torso.CFrame
	check(torso.Position.Y < 2.7, string.format("huss %s: crouched (torso at %.2f, standing 3)", name, torso.Position.Y))
	check(torso.UpVector.X * side > 0.25, string.format("huss %s: tipped into the move (%.2f)", name, torso.UpVector.X))
	check(torso.UpVector.Z < -0.1, string.format("huss %s: leaning forward (%.2f)", name, torso.UpVector.Z))
	check(math.abs(P.Head.CFrame.UpVector.X) < torso.UpVector.X * side, "huss " .. name .. ": the head nearer upright than the body")
	for _, arm in { "Right Arm", "Left Arm" } do
		local hand = (P[arm].CFrame * CFrame.new(0, -1, 0)).Position
		check(hand.Z < torso.Position.Z - 0.5, string.format("huss %s: %s's fist in front (%.2f)", name, arm, hand.Z))
	end
end
print(string.format("R6Huss: %d ok, %d failed", passed, failed))
if failed > 0 then error("R6Huss spec failed") end
