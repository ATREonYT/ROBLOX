--[[
	C.C. (the owner's R15 Secret, places/HUSSANIME.rbxl) turning her head, before and after Shared/GirlRig (owner,
	Oct 19: "cc's head doesnt move, or in general it looks weird even in the animations"):
	  left, BEFORE: the copies welded her hair, face and hat (held on by AccessoryRigidConstraints, which they didn't
	                count) to her ROOT, so her head turned under hair that stayed still;
	  right, AFTER: GirlRig.joinAccessories welds each to the body part it sits on (her Head).
	Every part drawn as its box (meshes too), posed by walking her joints from the root (Motor6D with its Transform,
	Weld, WeldConstraint). Her neck looks left and right and nods; her waist sways a little.
	From the repo root: sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/girl_rig_scene.luau out.mp4
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local Scene = require("./scene")

local GirlRig = luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/GirlRig.lua"), {
	debugName = "GirlRig", environment = setmetatable({ Instance = Instance, CFrame = CFrame }, { __index = _G }) })()

local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HUSSANIME.rbxl"))
local source = nil
for _, d in place:GetService("Workspace"):FindFirstChild("ANIME GIRLS"):GetDescendants() do
	if d:IsA("Model") and d.Name:find("TransportViewer") then source = d end
end
assert(source, "C.C. not found")

-- the copy as the game made it before (Motor6Ds, and anything not joined to the root welded to the root)
local function before(m)
	GirlRig.toMotors(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	local links = {}
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") or d.ClassName == "WeldConstraint" then
			links[d.Part0] = links[d.Part0] or {}
			links[d.Part1] = links[d.Part1] or {}
			table.insert(links[d.Part0], d.Part1)
			table.insert(links[d.Part1], d.Part0)
		end
	end
	local joined, queue = { [root] = true }, { root }
	while #queue > 0 do
		for _, o in links[table.remove(queue)] or {} do
			if o and not joined[o] then joined[o] = true table.insert(queue, o) end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not joined[d] and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, d
			w.Parent = d
		end
	end
end
local function after(m)
	GirlRig.toMotors(m)
	GirlRig.joinAccessories(m)
end

local function build(fix, x)
	local m = source:Clone()
	local rest = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then rest[d] = d.CFrame end
	end
	fix(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") or d.ClassName == "WeldConstraint" then table.insert(joints, d) end
	end
	local motors = {}
	for _, j in joints do
		if j:IsA("Motor6D") then motors[j.Part1.Name] = j end
	end
	return { model = m, root = root, rest = rest, joints = joints, motors = motors, offset = CFrame.new(x, 0, 0) }
end
local rigs = { build(before, -2.4), build(after, 2.4) }

-- forward kinematics from the root: Part1 = Part0 * C0 * Transform * C1^-1 (Weld: no Transform; WeldConstraint:
-- the rest offset)
local function pose(r, transforms)
	local at = { [r.root] = r.offset * r.rest[r.root] }
	local changed = true
	while changed do
		changed = false
		for _, j in r.joints do
			local p0, p1 = j.Part0, j.Part1
			for _, pair in { { p0, p1, false }, { p1, p0, true } } do
				local a, b, back = pair[1], pair[2], pair[3]
				if a and b and at[a] and not at[b] then
					local rel
					if j.ClassName == "WeldConstraint" then
						rel = r.rest[p0]:ToObjectSpace(r.rest[p1])
					else
						rel = j.C0 * (transforms[j] or CFrame.new()) * j.C1:Inverse()
					end
					at[b] = if back then at[a] * rel:Inverse() else at[a] * rel
					changed = true
				end
			end
		end
	end
	return at
end

local scene = Scene.new()
local boxes = {}
for _, r in rigs do
	for part in r.rest do
		if part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
			local c = part.Color
			boxes[part] = scene:addBox(part.CFrame, part.Size, string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)))
		end
	end
end
local base = rigs[1].rest[rigs[1].root].Position
local FPS, LEN = 30, 4
for i = 0, LEN * FPS - 1 do
	local t = i / FPS
	for _, r in rigs do
		local tf = {}
		local neck, waist = r.motors.Head, r.motors.UpperTorso
		if neck then tf[neck] = CFrame.Angles(math.rad(14) * math.sin(t * 2.4), math.rad(55) * math.sin(t * 1.6), math.rad(8) * math.sin(t * 1.6)) end
		if waist then tf[waist] = CFrame.Angles(0, math.rad(12) * math.sin(t * 1.6 + 0.6), math.rad(5) * math.sin(t * 1.2)) end
		local at = pose(r, tf)
		for part, b in boxes do
			if r.rest[part] and at[part] then b.CFrame = at[part] end
		end
	end
	scene:frame(base + Vector3.new(0, 1.2, 9.5), base + Vector3.new(0, 1.0, 0), {
		fov = 50, caption = "C.C. turns her head:  BEFORE (hair on her root)   |   AFTER (hair on her Head)" })
end
scene:save(nil, FPS, 960, 540, { sky = "#cfd8e6", ground = "#8a9a7a", grid = false })
