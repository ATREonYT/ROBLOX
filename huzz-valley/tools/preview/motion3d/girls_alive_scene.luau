--[[
	Owner Oct 20: "check the animations for the girls ... again, i still have questions to it, it doesnt seem fixed"
	(his clip: the prize girl Yui hung over the field and didn't seem to move). His real girls (places/HUSSANIME.rbxl,
	every part drawn as its box), moved by the game's own code:
	  0-7 s    ALL 35 of his girls held (GirlMotion.carried, calm: feet swinging, kicks, glances, waves), each lying
	           across a carrier's raised hands the way CarryMath holds her (the carrier isn't drawn), from the front;
	  7-15 s   the round's prize, Yui, floating over the field, seen from the field the way his clip saw her (her
	           height and the camera at 1/3, the same as 3x her size at 34 studs up). Left BEFORE (the pack's Idle
	           and a slow head drift: what his clip showed), right NOW (she watches the player below, swings her feet,
	           waves and kicks now and then: GirlMotion.showcase). Both turn and bob as the game does.
	From the repo root: sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/girls_alive_scene.luau out.mp4
	Film: docs/previews/girls-alive.mp4. Numbers: girl_alive_measure.luau; every girl checked: tests/GirlsAlive.spec.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local Showcase = Env.load(SHARED .. "Config/Round.lua").Showcase

local GirlRig = luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/GirlRig.lua"), {
	debugName = "GirlRig", environment = setmetatable({ Instance = Instance, CFrame = CFrame }, { __index = _G }) })()

local lib = Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local anims = assert(GirlMoves.load(lib:FindFirstChild("HuzzAnimations")))

local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HUSSANIME.rbxl"))
local folder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
local sources = {}
for _, rarity in folder:GetChildren() do
	for _, m in rarity:GetChildren() do
		if m:IsA("Model") then table.insert(sources, m) end
	end
end
local yuiSource = nil
for _, m in sources do
	if m.Name == "CAC_R6_IdontLikeSand312_C3D54E" then yuiSource = m end
end
assert(yuiSource, "Yui not found")

local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- A girl as the game makes her (GirlRig), with stand-in Motor6Ds whose Transform the motion code can write.
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
		end
	end
	-- her root above her feet
	local lowest = math.huge
	for part, cf in rest do
		if part.Transparency < 1 then lowest = math.min(lowest, cf.Position.Y - part.Size.Y / 2) end
	end
	g.rootHeight = math.clamp(rest[root].Position.Y - lowest, 1, 6)
	return g
end

-- Forward kinematics from her root placed at rootCF; writes every part's CFrame (the motion code reads her torso's).
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
local function hide(g, on)
	for _, b in g.boxes do b.Hidden = on end
end

local FPS = 30
local A_LEN, B_LEN = 7, 8

-- Part A: the grid of every girl held
local COLS, GAP_X, GAP_Y = 7, 6.2, 5.2
local AZ = -3000 -- (part A far from part B's field)
local held = {}
local hold = CarryMath.holdRotation()
local carrierFacing = CFrame.Angles(0, math.pi, 0) -- (the carrier faces the camera)
for i, source in sources do
	local g = build(source)
	local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
	g.spot = CFrame.new((col - (COLS - 1) / 2) * GAP_X, 40 - row * GAP_Y, AZ) * carrierFacing * hold
	g.state = GirlMotion.new(1000 + i * 37)
	g.offset = i * 0.37 -- (each at her own moment)
	g.name = source.Name
	held[i] = g
end

-- Part B: Yui before / now
local before, now = build(yuiSource), build(yuiSource)
for _, g in { before, now } do
	g.state = GirlMotion.new(17)
	g.pack = GirlMoves.new(anims, g.rootHeight)
end
local FIELD_Y = 0
local K = 1 / 3 -- (1x girl, heights and distances at a third: the same picture as 3x her size)
before.base = CFrame.new(-6, FIELD_Y + Showcase.Height * K + before.rootHeight, 0)
now.base = CFrame.new(6, FIELD_Y + Showcase.Height * K + now.rootHeight, 0)
local field = scene:addBox(CFrame.new(0, FIELD_Y - 0.05, 0), Vector3.new(160, 0.1, 160), "#d39a5c")
local playerBox = scene:addBox(CFrame.new(1, FIELD_Y + 1, 9), Vector3.new(0.7, 2, 0.5), "#1c1c22")
for _, g in held do hide(g, false) end
hide(before, true)
hide(now, true)
field.Hidden, playerBox.Hidden = true, true

for i = 0, (A_LEN + B_LEN) * FPS - 1 do
	local t = i / FPS
	local dt = 1 / FPS
	if t < A_LEN then
		for _, g in held do
			pose(g, g.spot)
			local tt = t + g.offset + 4 -- (calm moves already under way)
			GirlMotion.carried(g.state, g.J, dt, tt, {
				accel = Vector3.zero, forward = Vector3.new(0, 0, 1), mood = "Calm", moodAge = 99, step = 0, amount = 0,
			})
		end
		scene:frame(Vector3.new(0, 40 - 2 * GAP_Y, AZ + 48), Vector3.new(0, 40 - 2 * GAP_Y, AZ), {
			fov = 50, caption = "Every one of his 35 girls held (the carrier isn't drawn): feet swing, kicks, glances, waves",
		})
	else
		if t - dt < A_LEN then
			for _, g in held do hide(g, true) end
			hide(before, false)
			hide(now, false)
			field.Hidden, playerBox.Hidden = false, false
		end
		local tb = t - A_LEN
		local player = playerBox.CFrame.Position + Vector3.new(0, 1, 0)
		for _, g in { before, now } do
			local spin = CFrame.Angles(0, (tb * Showcase.Spin + 1.2) % (2 * math.pi), 0)
			pose(g, g.base * CFrame.new(0, math.sin(tb * 1.1) * Showcase.Bob * K, 0) * spin)
			if g == before then
				GirlMoves.idle(g.pack, g.J, dt, GirlMotion.look(g.state, g.J, dt, tb, {}))
			else
				GirlMoves.idle(g.pack, g.J, dt, GirlMotion.look(g.state, g.J, dt, tb, { target = player, distance = 40 }))
				GirlMotion.showcase(g.state, g.J, dt, tb + 2)
			end
		end
		pose(before, before.root.CFrame)
		pose(now, now.root.CFrame)
		local cam = Vector3.new(0, FIELD_Y + 1.8, 30)
		scene:frame(cam, Vector3.new(0, FIELD_Y + Showcase.Height * K + 2, 0), {
			fov = 50, caption = "Round 1 prize Yui over the field, seen from the field:  BEFORE (his clip)   |   NOW",
			labels = {
				{ p = { -6, FIELD_Y + Showcase.Height * K + 8, 0 }, text = "BEFORE", h = 1.1, c = "#ffffff", o = "#14122a" },
				{ p = { 6, FIELD_Y + Showcase.Height * K + 8, 0 }, text = "NOW", h = 1.1, c = "#5be07a", o = "#14122a" },
			},
		})
	end
end
scene:save(nil, FPS, 1280, 720, { sky = "#7fb6e8", ground = "#d39a5c", grid = false })
