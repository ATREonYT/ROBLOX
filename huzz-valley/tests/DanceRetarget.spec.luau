-- lune run tests/DanceRetarget.spec.luau  (owner, Oct 22 16:22: "make the girls dance with you"; the dances became
-- R6 that day and the girls stood still: Shared/DanceRetarget only read R15 poses). An R6 dance on an R6 girl is the
-- dance exactly; on an R15 girl her torso, head, upper arms and thighs point the way the dancer's do.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local GirlMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/GirlMotion.lua")
local Retarget = Env.load("huzz-valley/src/ReplicatedStorage/Shared/DanceRetarget.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local function cf(n)
	return CFrame.new(n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8], n[9], n[10], n[11], n[12])
end
local PAIRS = { Torso = "UpperTorso", Head = "Head", ["Right Arm"] = "RightUpperArm", ["Left Arm"] = "LeftUpperArm",
	["Right Leg"] = "RightUpperLeg", ["Left Leg"] = "LeftUpperLeg" }

for _, file in { "sweet.json", "balenci.json", "jumpstyle.json" } do
	local path = "tools/anim/fit/dances/" .. file
	local data = serde.decode("json", fs.readFile(if fs.isFile(path) then path else "huzz-valley/" .. path))
	for i = 1, #data.frames, math.max(1, #data.frames // 6) do
		local pose = {}
		for part, n in data.frames[i] do pose[part] = cf(n) end
		-- the dancer: the pose on a stock R6 body, as Roblox plays it
		local dancer = Rig.r6("D")
		for _, m in dancer.motors do
			if pose[m.Part1.Name] then m.Transform = pose[m.Part1.Name] end
		end
		Rig.fk(dancer)
		-- an R6 girl: the same Transforms
		local girl = Rig.r6("G")
		Retarget.apply(GirlMotion.joints(girl.motors), pose, 1, 1)
		local same = true
		for _, m in girl.motors do
			local want = pose[m.Part1.Name]
			if want and (m.Transform.Position - want.Position).Magnitude + (m.Transform.LookVector - want.LookVector).Magnitude
				+ (m.Transform.UpVector - want.UpVector).Magnitude > 1e-4 then same = false end
		end
		check(same, file .. " frame " .. i .. ": an R6 girl dances it exactly")
		-- an R15 girl: each matching part points the same way
		local big = Rig.r15("B")
		Retarget.apply(GirlMotion.joints(big.motors), pose, 1, 1)
		Rig.fk(big)
		for r6, r15 in PAIRS do
			local a, b = dancer.parts[r6].CFrame, big.parts[r15].CFrame
			check(a.UpVector:Dot(b.UpVector) > 0.97 and a.LookVector:Dot(b.LookVector) > 0.9,
				string.format("%s frame %d: an R15 girl's %s points like the dancer's %s", file, i, r15, r6))
		end
	end
end
print(string.format("DanceRetarget: %d ok, %d failed", passed, failed))
if failed > 0 then error("DanceRetarget spec failed") end
