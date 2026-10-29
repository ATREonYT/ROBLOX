-- Mock R15 blocky rig as plain tables, shaped like Roblox's so game code (CarryMath, animators) can read it.
-- Parts: {Name, Size, CFrame, Color}. Motors: {Name, Part0, Part1, C0, C1, Transform}, Parent = Part1.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local Rig = {}

-- Roblox puts a joint inside its Part1 (RightShoulder in RightUpperArm), so part:FindFirstChild finds it there.
local Part = {}
Part.__index = Part
function Part:FindFirstChild(name)
	return self.joints[name]
end

local Model = {}
Model.__index = Model
function Model:FindFirstChild(name)
	return self.parts[name]
end

-- Roblox's CFrame.lookAt (Lune 0.10.5's own faces the opposite way, so scenes use this one).
function Rig.lookAt(pos, target)
	local look = (target - pos).Unit
	local right = look:Cross(Vector3.new(0, 1, 0)).Unit
	return CFrame.fromMatrix(pos, right, right:Cross(look), -look)
end

-- A Motor6D. Use it for extra joints too (a carried rig's root welded to this rig's torso).
function Rig.motor(name, part0, part1, c0, c1)
	local m = { Name = name, Part0 = part0, Part1 = part1, C0 = c0 or CFrame.identity, C1 = c1 or CFrame.identity, Transform = CFrame.identity, Parent = part1 }
	if part1.joints then part1.joints[name] = m end
	return m
end

local REST_HEIGHT = 3.1 -- HRP centre: 0.2 + 0.8 (hip) + 1.2 (knee) + 0.75 (ankle) + 0.15 (half foot)

-- colors: {shirt, pants, skin, hair, eyes} as "#rrggbb"; anything missing gets a default.
function Rig.r15(name, colors)
	colors = colors or {}
	local shirt, pants = colors.shirt or "#3a6fd8", colors.pants or "#2b2f3a"
	local skin, hair, eyes = colors.skin or "#f2c9a0", colors.hair or "#4a2c1a", colors.eyes or "#1a1a22"
	local rig = setmetatable({ Name = name, parts = {}, motors = {}, decor = {} }, Model)
	local function part(n, size, color)
		local p = setmetatable({ Name = n, Size = size, CFrame = CFrame.identity, Color = color, joints = {}, rig = rig }, Part)
		rig.parts[n] = p
		return p
	end
	local function v(x, y, z) return CFrame.new(x, y, z) end
	local P = rig.parts
	part("HumanoidRootPart", Vector3.new(2, 2, 1), "#ffffff").hidden = true -- invisible, as in Roblox
	part("LowerTorso", Vector3.new(2, 0.4, 1), pants)
	part("UpperTorso", Vector3.new(2, 1.6, 1), shirt)
	part("Head", Vector3.new(1.2, 1.2, 1.2), skin)
	for _, s in { "Left", "Right" } do
		part(s .. "UpperArm", Vector3.new(1, 1.1, 1), shirt)
		part(s .. "LowerArm", Vector3.new(1, 1.1, 1), skin)
		part(s .. "Hand", Vector3.new(1, 0.3, 1), skin)
		part(s .. "UpperLeg", Vector3.new(1, 1.2, 1), pants)
		part(s .. "LowerLeg", Vector3.new(1, 1.2, 1), pants)
		part(s .. "Foot", Vector3.new(1, 0.3, 1), "#3b3b3b")
	end
	local function joint(n, p0, p1, c0, c1)
		table.insert(rig.motors, Rig.motor(n, P[p0], P[p1], c0, c1))
	end
	joint("Root", "HumanoidRootPart", "LowerTorso", v(0, -0.2, 0), CFrame.identity)
	joint("Waist", "LowerTorso", "UpperTorso", v(0, 0.2, 0), v(0, -0.8, 0))
	joint("Neck", "UpperTorso", "Head", v(0, 0.8, 0), v(0, -0.6, 0))
	for _, s in { "Left", "Right" } do
		local x = if s == "Right" then 1 else -1 -- right is +x
		joint(s .. "Shoulder", "UpperTorso", s .. "UpperArm", v(x, 0.55, 0), v(-x * 0.5, 0.4, 0))
		joint(s .. "Elbow", s .. "UpperArm", s .. "LowerArm", v(0, -0.5, 0), v(0, 0.5, 0))
		joint(s .. "Wrist", s .. "LowerArm", s .. "Hand", v(0, -0.55, 0), v(0, 0.15, 0))
		joint(s .. "Hip", "LowerTorso", s .. "UpperLeg", v(x * 0.5, -0.2, 0), v(0, 0.6, 0))
		joint(s .. "Knee", s .. "UpperLeg", s .. "LowerLeg", v(0, -0.6, 0), v(0, 0.6, 0))
		joint(s .. "Ankle", s .. "LowerLeg", s .. "Foot", v(0, -0.6, 0), v(0, 0.15, 0))
	end
	-- Face and hair: boxes that follow the head (front is -Z), so you can see where it looks.
	local head = P.Head
	local function deco(offset, size, color) table.insert(rig.decor, { part = head, offset = offset, Size = size, Color = color }) end
	deco(v(-0.25, 0.08, -0.61), Vector3.new(0.16, 0.26, 0.04), eyes)
	deco(v(0.25, 0.08, -0.61), Vector3.new(0.16, 0.26, 0.04), eyes)
	deco(v(0, 0.5, 0.08), Vector3.new(1.3, 0.35, 1.2), hair) -- top
	deco(v(0, 0.05, 0.62), Vector3.new(1.3, 0.9, 0.12), hair) -- back
	rig.root = P.HumanoidRootPart
	rig.root.CFrame = CFrame.new(0, REST_HEIGHT, 0)
	Rig.fk(rig)
	return rig
end
Rig.REST_HEIGHT = REST_HEIGHT

-- Mock R6 blocky rig (most anime girls are R6), with Roblox's real R6 joint frames: every R6 joint's C0/C1 is
-- turned 90° (unlike R15's), so code that poses R6 joints is tested against the real thing. Root part centre 3
-- studs up. Parts: Torso, Head, Left Arm, Right Arm, Left Leg, Right Leg.
function Rig.r6(name, colors)
	colors = colors or {}
	local shirt, pants = colors.shirt or "#e85d9a", colors.pants or "#3b2a5a"
	local skin, hair, eyes = colors.skin or "#f6d3b8", colors.hair or "#f2b6d0", colors.eyes or "#2a1a40"
	local rig = setmetatable({ Name = name, parts = {}, motors = {}, decor = {} }, Model)
	local function part(n, size, color)
		local p = setmetatable({ Name = n, Size = size, CFrame = CFrame.identity, Color = color, joints = {}, rig = rig }, Part)
		rig.parts[n] = p
		return p
	end
	local P = rig.parts
	part("HumanoidRootPart", Vector3.new(2, 2, 1), "#ffffff").hidden = true
	part("Torso", Vector3.new(2, 2, 1), shirt)
	part("Head", Vector3.new(1.25, 1.25, 1.25), skin)
	part("Left Arm", Vector3.new(1, 2, 1), skin)
	part("Right Arm", Vector3.new(1, 2, 1), skin)
	part("Left Leg", Vector3.new(1, 2, 1), pants)
	part("Right Leg", Vector3.new(1, 2, 1), pants)
	local function cf(x, y, z, ...) return CFrame.new(x, y, z, ...) end
	local function joint(n, p0, p1, c0, c1)
		table.insert(rig.motors, Rig.motor(n, P[p0], P[p1], c0, c1))
	end
	joint("RootJoint", "HumanoidRootPart", "Torso", cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	joint("Neck", "Torso", "Head", cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, -0.625, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	joint("Right Shoulder", "Torso", "Right Arm", cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	joint("Left Shoulder", "Torso", "Left Arm", cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	joint("Right Hip", "Torso", "Right Leg", cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	joint("Left Hip", "Torso", "Left Leg", cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local head = P.Head
	local function deco(offset, size, color) table.insert(rig.decor, { part = head, offset = offset, Size = size, Color = color }) end
	deco(CFrame.new(-0.26, 0.05, -0.64), Vector3.new(0.18, 0.3, 0.04), eyes)
	deco(CFrame.new(0.26, 0.05, -0.64), Vector3.new(0.18, 0.3, 0.04), eyes)
	deco(CFrame.new(0, 0.5, 0.08), Vector3.new(1.4, 0.4, 1.35), hair)
	deco(CFrame.new(0, -0.2, 0.62), Vector3.new(1.4, 1.6, 0.2), hair) -- long hair down the back
	rig.root = P.HumanoidRootPart
	rig.root.CFrame = CFrame.new(0, 3, 0)
	Rig.fk(rig)
	return rig
end

-- Scales a rig (parts, joints, face) by k, as Model:ScaleTo does.
function Rig.scale(rig, k)
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

-- Forward kinematics, breadth-first from rig.root: Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse().
-- extraMotors join other rigs on (e.g. Rig.motor("Carry", carrier.parts.UpperTorso, girl.root, c0)); list those
-- rigs in otherRigs so their own joints solve too, after their root is placed.
function Rig.fk(rig, extraMotors, otherRigs)
	local byPart0 = {}
	local function add(m)
		byPart0[m.Part0] = byPart0[m.Part0] or {}
		table.insert(byPart0[m.Part0], m)
	end
	for _, m in rig.motors do add(m) end
	for _, m in extraMotors or {} do add(m) end
	for _, r in otherRigs or {} do for _, m in r.motors do add(m) end end
	local queue, i = { rig.root }, 1
	while queue[i] do
		local p0 = queue[i]
		i += 1
		for _, m in byPart0[p0] or {} do
			m.Part1.CFrame = p0.CFrame * m.C0 * m.Transform * m.C1:Inverse()
			table.insert(queue, m.Part1)
		end
	end
end

-- Every visible box of the rig: {CFrame, Size, Color} (parts, then face and hair).
function Rig.boxes(rig)
	local out = {}
	for _, p in rig.parts do
		if not p.hidden then table.insert(out, { CFrame = p.CFrame, Size = p.Size, Color = p.Color }) end
	end
	for _, d in rig.decor do
		table.insert(out, { CFrame = d.part.CFrame * d.offset, Size = d.Size, Color = d.Color })
	end
	return out
end

return Rig
