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
-- C.C. (his only R15 girl, the real model; owner Oct 23: "make cc's body move normally, keep the head attatched"):
-- on an R6 dance her whole body moves like the R6 dancer's, each R15 piece turned like its R6 part and her head and
-- feet where the dancer's are (as a share of height: her root joint sits at her hips, so the leans used to swing
-- her round them, up to 15% off), her head on her neck and her hair on her head.
do
	local luau = require("@lune/luau")
	local function file(p) return if fs.isFile(p) then p else "huzz-valley/" .. p end
	local GirlRig = luau.load(fs.readFile(file("src/ReplicatedStorage/Shared/GirlRig.lua")), {
		debugName = "GirlRig", environment = { Instance = roblox.Instance, CFrame = CFrame } })()
	local place = roblox.deserializePlace(fs.readFile(file("places/HUSSANIME.rbxl")))
	local source = nil
	for _, d in place:GetService("Workspace"):FindFirstChild("ANIME GIRLS"):GetDescendants() do
		if d:IsA("Model") and d.Name:find("TransportViewer") then source = d end
	end
	check(source ~= nil, "C.C. is in his place")
	local m = source:Clone()
	GirlRig.toMotors(m)
	GirlRig.joinAccessories(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	-- stand-in joints the dance code can write (as the motion3d scenes do), posed from her root by hand
	local rest, joints, motors = {}, {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then rest[d] = d.CFrame end
		if d:IsA("Motor6D") then
			local j = { kind = "M", Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1, Transform = CFrame.identity }
			table.insert(joints, j)
			table.insert(motors, j)
		elseif d:IsA("JointInstance") then
			table.insert(joints, { kind = "W", Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1 })
		end
	end
	local J = GirlMotion.joints(motors)
	local function fk()
		local at, changed = { [root] = rest[root] }, true
		while changed do
			changed = false
			for _, j in joints do
				if at[j.Part0] and not at[j.Part1] then
					at[j.Part1] = at[j.Part0] * j.C0 * (if j.kind == "M" then j.Transform else CFrame.identity) * j.C1:Inverse()
					changed = true
				end
			end
		end
		return at
	end
	local function named(n)
		for p in rest do
			if p.Name == n and not p:FindFirstAncestorWhichIsA("Accoutrement") then return p end
		end
	end
	local function lowest(at, names)
		local y = math.huge
		for _, n in names do
			local p = named(n) or n
			local cf, h = at[p] or p.CFrame, p.Size / 2
			for _, c in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, -1, 1), Vector3.new(1, -1, -1) } do
				y = math.min(y, cf:PointToWorldSpace(h * c).Y)
			end
		end
		return y
	end
	local restAt = fk()
	local ccLow = lowest(restAt, { "LeftFoot", "RightFoot" })
	local ccHeight = restAt[named("Head")].Position.Y + named("Head").Size.Y / 2 - ccLow
	local hair = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestorWhichIsA("Accoutrement") then hair[d] = rest[named("Head")]:ToObjectSpace(rest[d]) end
	end
	local PIECES = { UpperTorso = "Torso", LowerTorso = "Torso", Head = "Head", LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm",
		RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg",
		RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg" }
	local data = serde.decode("json", fs.readFile(file("tools/anim/fit/dances/balenci.json")))
	local worstTurn, worstHead, worstFeet, neckGap, hairOff = 0, 0, 0, 0, 0
	for i = 1, #data.frames, math.max(1, #data.frames // 24) do
		local pose = {}
		for part, n in data.frames[i] do pose[part] = cf(n) end
		local dancer = Rig.r6("D")
		for _, mm in dancer.motors do
			if pose[mm.Part1.Name] then mm.Transform = pose[mm.Part1.Name] end
		end
		local dRest = {}
		for n, p in dancer.parts do dRest[n] = dancer.root.CFrame:ToObjectSpace(p.CFrame) end
		Rig.fk(dancer)
		for _, j in motors do j.Transform = CFrame.identity end
		Retarget.apply(J, pose, 1, ccHeight / 5.2)
		local at = fk()
		for r15, r6 in PIECES do
			local p = named(r15)
			local mine = rest[root]:ToObjectSpace(at[p]).Rotation * rest[root]:ToObjectSpace(rest[p]).Rotation:Inverse()
			local theirs = dancer.root.CFrame:ToObjectSpace(dancer.parts[r6].CFrame).Rotation * dRest[r6].Rotation:Inverse()
			local _, ang = (mine:Inverse() * theirs):ToAxisAngle()
			worstTurn = math.max(worstTurn, math.deg(ang))
		end
		local headMine = rest[root]:PointToObjectSpace(at[named("Head")].Position) / ccHeight
		local headTheirs = dancer.root.CFrame:PointToObjectSpace(dancer.parts.Head.CFrame.Position) / 5.25
		local headRest = (rest[root]:PointToObjectSpace(restAt[named("Head")].Position) / ccHeight)
			- (dRest.Head.Position / 5.25)
		worstHead = math.max(worstHead, (headMine - headTheirs - headRest).Magnitude)
		local feetMine = (lowest(at, { "LeftFoot", "RightFoot" }) - ccLow) / ccHeight
		local feetTheirs = (lowest({ [dancer.parts["Left Leg"]] = dancer.parts["Left Leg"].CFrame, [dancer.parts["Right Leg"]] = dancer.parts["Right Leg"].CFrame },
			{ dancer.parts["Left Leg"], dancer.parts["Right Leg"] }) - (dancer.root.CFrame.Position.Y - 3)) / 5.25
		worstFeet = math.max(worstFeet, math.abs(feetMine - feetTheirs))
		local neck = J.Neck
		neckGap = math.max(neckGap, ((at[neck.Part0] * neck.C0).Position - (at[neck.Part1] * neck.C1).Position).Magnitude)
		for h, off in hair do
			hairOff = math.max(hairOff, ((at[named("Head")] * off).Position - at[h].Position).Magnitude)
		end
	end
	check(worstTurn < 1, string.format("C.C. on Balenci: every R15 piece turns like the R6 dancer's part (worst %.2f°)", worstTurn))
	check(worstHead < 0.04, string.format("C.C. on Balenci: her head is where the dancer's is (worst %.3f of her height)", worstHead))
	check(worstFeet < 0.04, string.format("C.C. on Balenci: her feet are where the dancer's are (worst %.3f of her height)", worstFeet))
	check(neckGap < 1e-3, string.format("C.C. on Balenci: her head stays on her neck (gap %.4f)", neckGap))
	check(hairOff < 1e-3, string.format("C.C. on Balenci: her hair and face stay on her head (off %.4f)", hairOff))
	print(string.format("C.C. on Balenci: turn %.2f°, head %.3f, feet %.3f of her height", worstTurn, worstHead, worstFeet))
end
print(string.format("DanceRetarget: %d ok, %d failed", passed, failed))
if failed > 0 then error("DanceRetarget spec failed") end
