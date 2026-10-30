--[[
	C.C. (his only R15 girl, the Secret) next to an R6 girl (Yui), both moved by the game's own code on his real
	models (places/HUSSANIME.rbxl, every part drawn as its box). Owner Oct 23: "also make cc's body move normally,
	keep the head attatched".
	  0-5 s    Dance_Balenci (an R6 dance: Shared/KeyframeSampler + Shared/DanceRetarget, as CompanionDance does)
	  5-9 s    walking (Shared/GirlMoves with the pack's Walk/Run, as FollowMotion does)
	  9-12 s   held up (Shared/GirlMotion.carried)
	Her root joint sits at her hips (the R6 one in the middle of the torso): before the Oct 23 fix the dance's leans
	swung her whole body round her hips, her head and feet up to 18% of her height off the R6 girls' (her feet
	through the floor). MEASURE=1 prints each piece's turn against Yui's, the head gap and both girls' feet.
	From the repo root: sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/cc_body_scene.luau out.mp4
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local Sampler = Env.load(SHARED .. "KeyframeSampler.lua")
local Retarget = Env.load(SHARED .. "DanceRetarget.lua")
local GirlRig = luau.load(fs.readFile(SHARED .. "GirlRig.lua"), {
	debugName = "GirlRig", environment = setmetatable({ Instance = Instance, CFrame = CFrame }, { __index = _G }) })()

local lib = Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local anims = assert(GirlMoves.load(lib:FindFirstChild("HuzzAnimations")))
local dance = Sampler.load(lib:FindFirstChild("Dance_" .. (process.env.DANCE or "Balenci"), true))

local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HUSSANIME.rbxl"))
local cc, yui
for _, d in place:GetService("Workspace"):FindFirstChild("ANIME GIRLS"):GetDescendants() do
	if d:IsA("Model") and d.Name:find("TransportViewer") then cc = d end
	if d:IsA("Model") and d.Name == "CAC_R6_IdontLikeSand312_C3D54E" then yui = d end
end
assert(cc and yui, "C.C. or Yui not found")

local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local scene = Scene.new()
local function build(source)
	local m = source:Clone()
	GirlRig.toMotors(m)
	GirlRig.joinAccessories(m)
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	local rest, joints, motors = {}, {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then rest[d] = d.CFrame end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then
			local j = { kind = "Motor6D", Name = d.Name, Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1, Transform = CFrame.identity }
			table.insert(joints, j)
			table.insert(motors, j)
		elseif d:IsA("JointInstance") then
			table.insert(joints, { kind = "Weld", Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1 })
		elseif d.ClassName == "WeldConstraint" then
			table.insert(joints, { kind = "WeldConstraint", Part0 = d.Part0, Part1 = d.Part1 })
		end
	end
	local g = { root = root, rest = rest, joints = joints, motors = motors, J = GirlMotion.joints(motors), boxes = {} }
	for part in rest do
		if part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
			g.boxes[part] = scene:addBox(part.CFrame, part.Size, hex(part.Color))
			if part:FindFirstAncestorWhichIsA("Accoutrement") then
				g.boxes[part].Alpha = 0.3 -- (her long hair drawn as a see-through box, so her body shows)
			end
		end
	end
	local lowest = math.huge
	for part, cf in rest do
		if part.Transparency < 1 then lowest = math.min(lowest, cf.Position.Y - part.Size.Y / 2) end
	end
	g.rootHeight = math.clamp(rest[root].Position.Y - lowest, 1, 6)
	g.height = 0
	for part, cf in rest do
		if part.Transparency < 1 then g.height = math.max(g.height, cf.Position.Y + part.Size.Y / 2 - lowest) end
	end
	return g
end

local function pose(g, rootCF)
	local at = { [g.root] = rootCF }
	local changed = true
	while changed do
		changed = false
		for _, j in g.joints do
			local p0, p1 = j.Part0, j.Part1
			for _, pair in { { p0, p1, false }, { p1, p0, true } } do
				local a, b, back = pair[1], pair[2], pair[3]
				if a and b and at[a] and not at[b] then
					local rel
					if j.kind == "WeldConstraint" then
						rel = g.rest[p0]:ToObjectSpace(g.rest[p1])
					elseif j.kind == "Motor6D" then
						rel = j.C0 * j.Transform * j.C1:Inverse()
					else
						rel = j.C0 * j.C1:Inverse()
					end
					at[b] = if back then at[a] * rel:Inverse() else at[a] * rel
					changed = true
				end
			end
		end
	end
	for part, cf in at do
		part.CFrame = cf
		local box = g.boxes[part]
		if box then box.CFrame = cf end
	end
end

local girls = { build(cc), build(yui) }
local facing = CFrame.Angles(0, math.pi, 0) -- (facing the camera)
for i, g in girls do
	g.spot = CFrame.new((i == 1) and -2.6 or 2.6, g.rootHeight, 0) * facing
	g.state = GirlMotion.new(40 + i)
	g.pack = GirlMoves.new(anims, g.rootHeight)
end

local FPS, LEN = 30, 12
local R15_HEIGHT = 5.2
for f = 0, LEN * FPS - 1 do
	local t, dt = f / FPS, 1 / FPS
	local caption
	for _, g in girls do
		for _, m in g.motors do m.Transform = CFrame.identity end
		local rootCF = g.spot
		if t < 5 then
			caption = "Dance_Balenci (an R6 dance):  C.C. (R15)   |   Yui (R6)"
			GirlMoves.idle(g.pack, g.J, dt)
			Retarget.apply(g.J, Sampler.sample(dance, t), 1, g.height / R15_HEIGHT)
		elseif t < 9 then
			caption = "Walking (the pack's Walk):  C.C. (R15)   |   Yui (R6)"
			GirlMoves.step(g.pack, g.J, dt, 7)
		else
			caption = "Held up (carried):  C.C. (R15)   |   Yui (R6)"
			rootCF = g.spot * CFrame.new(0, 1.5, 0)
			GirlMotion.carried(g.state, g.J, dt, t + 4, {
				accel = Vector3.zero, forward = Vector3.new(0, 0, 1), mood = "Calm", moodAge = 99, step = 0, amount = 0,
			})
		end
		pose(g, rootCF)
	end
	if process.env.MEASURE then -- each body piece's turn against her root: C.C.'s R15 parts vs Yui's R6 parts
		local pairs6 = { UpperTorso = "Torso", LowerTorso = "Torso", Head = "Head", LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm",
			RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg" }
		local a, b = girls[1], girls[2]
		local function part(g, n) for p in g.rest do if p.Name == n and not p:FindFirstAncestorWhichIsA("Accoutrement") then return p end end end
		local line = {}
		for r15, r6 in pairs6 do
			local pa, pb = part(a, r15), part(b, r6)
			local ra = a.root.CFrame:ToObjectSpace(pa.CFrame).Rotation * a.rest[a.root]:ToObjectSpace(a.rest[pa]).Rotation:Inverse()
			local rb = b.root.CFrame:ToObjectSpace(pb.CFrame).Rotation * b.rest[b.root]:ToObjectSpace(b.rest[pb]).Rotation:Inverse()
			local _, ang = (ra:Inverse() * rb):ToAxisAngle()
			table.insert(line, string.format("%s %.0f", r15, math.deg(ang)))
		end
		-- where her head and hips are against her root, as a share of her height
		local function rel(g, n) return g.root.CFrame:PointToObjectSpace(part(g, n).CFrame.Position) / g.height end
		local dh = (rel(a, "Head") - rel(b, "Head")).Magnitude
		local dl = (rel(a, "LeftFoot") - rel(b, "Left Leg") ).Magnitude
		table.insert(line, string.format("headGap %.2f", dh))
		local function low(g)
			local y = math.huge
			for p in g.rest do
				if p.Transparency < 1 and not p:FindFirstAncestorWhichIsA("Accoutrement") then
					local h = p.Size / 2
					for _, c in { Vector3.new(-1,-1,-1), Vector3.new(1,-1,1), Vector3.new(-1,-1,1), Vector3.new(1,-1,-1) } do
						y = math.min(y, p.CFrame:PointToWorldSpace(h * c).Y)
					end
				end
			end
			return y
		end
		table.insert(line, string.format("feetY cc %.2f yui %.2f  headY cc %.2f/%.2f", low(a), low(b), part(a, "Head").CFrame.Position.Y, a.height))
		if f % 15 == 0 then print(string.format("t=%.1f ", t) .. table.concat(line, "  ")) end
	end
	local turn = if t < 5 then 0.35 * math.sin(t * 0.6) else (if t < 9 then -1.2 else 0.2)
	local cam = Vector3.new(math.sin(turn) * 11, 3.4, math.cos(turn) * 12.5)
	scene:frame(cam, Vector3.new(0, 2.6, 0), { fov = 45, caption = caption })
end
scene:save(nil, FPS, 960, 540, { sky = "#cfd8e6", ground = "#8a9a7a", grid = false })
