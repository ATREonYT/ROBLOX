--!nocheck
-- Turns assets/rivals.json (written by tools/blender/rivals.py) into Roblox files:
--   assets/Rivals.rbxm      Folder of R15 rival rigs made of plain Parts (no uploads needed)
--   assets/RivalAnims.rbxm  Folder of KeyframeSequences: Idle, Tap, Victory, Defeat
--   assets/DuelTable.rbxm   the stand-up blitz table with chess clock and anchors
-- Run from the repo root: lune run chess-evolution/tools/blender/build_rivals.luau
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3, Color3, Enum = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum

local ROOT = "chess-evolution/assets/"
local data = serde.decode("json", fs.readFile(ROOT .. "rivals.json"))

local function v3(t, s) s = s or 1 return Vector3.new(t[1] * s, t[2] * s, t[3] * s) end
local function col(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function rot(t) return CFrame.Angles(math.rad(t[1]), math.rad(t[2]), math.rad(t[3])) end
local MATS = { SmoothPlastic = Enum.Material.SmoothPlastic, Neon = Enum.Material.Neon, Metal = Enum.Material.Metal, Glass = Enum.Material.Glass, Fabric = Enum.Material.Fabric, Wood = Enum.Material.Wood, Plastic = Enum.Material.Plastic }

local function newPart(name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = MATS[mat or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	if shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder elseif shape == "Ball" then p.Shape = Enum.PartType.Ball end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if mat == "Glass" then p.Transparency = 0.45 end
	return p
end

-- ---------- rivals ----------
local rivals = Instance.new("Folder")
rivals.Name = "Rivals"
for _, r in data.rivals do
	local s = r.scale
	local m = Instance.new("Model")
	m.Name = r.id
	m:SetAttribute("RivalId", r.id)
	m:SetAttribute("DisplayName", r.display)
	m:SetAttribute("Stage", r.stage)
	m:SetAttribute("Scale", s)
	local base = CFrame.new(0, 3 * s, 0) -- HumanoidRootPart centre; feet touch y = 0
	local parts = {}
	for _, name in data.order do
		local L = data.limbs[name]
		local p = newPart(name, v3(L.size, s), base * CFrame.new(v3(L.center, s)), col(r.colors[name]))
		p.CanCollide = false
		p.Massless = name ~= "HumanoidRootPart"
		if name == "HumanoidRootPart" then
			p.Transparency = 1
			p.Anchored = true
		end
		p.Parent = m
		parts[name] = p
	end
	for _, name in data.order do
		local L = data.limbs[name]
		if L.parent then
			local mo = Instance.new("Motor6D")
			mo.Name = L.motor
			mo.Part0 = parts[L.parent]
			mo.Part1 = parts[name]
			local pc = data.limbs[L.parent].center
			mo.C0 = CFrame.new(v3({ L.joint[1] - pc[1], L.joint[2] - pc[2], L.joint[3] - pc[3] }, s))
			mo.C1 = CFrame.new(v3({ L.joint[1] - L.center[1], L.joint[2] - L.center[2], L.joint[3] - L.center[3] }, s))
			mo.Parent = parts[name]
		end
	end
	local extras = Instance.new("Folder")
	extras.Name = "Outfit"
	extras.Parent = m
	for _, a in r.extras do
		local limb = parts[a.limb]
		local cf = base * CFrame.new(v3(a.pos, s)) * rot(a.rot)
		local p = newPart(a.name, v3(a.size, s), cf, col(a.color), a.mat, a.shape)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local w = Instance.new("Weld")
		w.Part0 = limb
		w.Part1 = p
		w.C0 = limb.CFrame:Inverse() * cf
		w.Parent = p
		p.Parent = extras
	end
	-- anchors for the main game: name tag / move badges above the head, hit sparks on the hands
	local head = parts.Head
	local top = Instance.new("Attachment")
	top.Name = "OverheadAnchor"
	top.Position = Vector3.new(0, head.Size.Y / 2 + 1.6 * s, 0)
	top.Parent = head
	for _, hand in { "LeftHand", "RightHand" } do
		local a = Instance.new("Attachment")
		a.Name = "HitFX"
		a.Position = Vector3.new(0, -parts[hand].Size.Y / 2, 0)
		a.Parent = parts[hand]
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = data.hipHeight * s
	hum.DisplayName = r.display
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
	local animator = Instance.new("Animator")
	animator.Parent = hum
	m.PrimaryPart = parts.HumanoidRootPart
	m.WorldPivot = CFrame.new(0, 0, 0)
	m.Parent = rivals
end
fs.writeFile(ROOT .. "Rivals.rbxm", roblox.serializeModel({ rivals }))

-- ---------- animations ----------
local anims = Instance.new("Folder")
anims.Name = "RivalAnims"
local EASE = { Cubic = Enum.PoseEasingStyle.Cubic, Sine = Enum.PoseEasingStyle.Cubic, Linear = Enum.PoseEasingStyle.Linear }
local DIR = { In = Enum.PoseEasingDirection.In, Out = Enum.PoseEasingDirection.Out, InOut = Enum.PoseEasingDirection.InOut }
local PRI = { Idle = Enum.AnimationPriority.Idle, Action = Enum.AnimationPriority.Action }
for _, a in data.anims do
	local ks = Instance.new("KeyframeSequence")
	ks.Name = a.name
	ks.Loop = a.loop
	ks.Priority = PRI[a.priority]
	for _, f in a.frames do
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		local poses = {}
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 0
		rootPose.Parent = kf
		poses.HumanoidRootPart = rootPose
		local style, dir = string.match(f.ease, "^(%a+)%-?(%a*)$")
		for _, name in data.order do
			local L = data.limbs[name]
			if L.parent then
				local P = f.poses[name]
				local pose = Instance.new("Pose")
				pose.Name = name
				if P then
					local q, p = P.q, P.p
					pose.CFrame = CFrame.new(p[1], p[2], p[3], q[2], q[3], q[4], q[1])
					pose.EasingStyle = EASE[style] or Enum.PoseEasingStyle.Cubic
					pose.EasingDirection = DIR[dir] or Enum.PoseEasingDirection.InOut
				else
					pose.Weight = 0 -- not animated here (legs stay free); kept only to hold the hierarchy
				end
				pose.Parent = poses[L.parent]
				poses[name] = pose
			end
		end
		kf.Parent = ks
	end
	ks.Parent = anims
end
fs.writeFile(ROOT .. "RivalAnims.rbxm", roblox.serializeModel({ anims }))

-- ---------- duel table ----------
local duel = Instance.new("Model")
duel.Name = "DuelTable"
for _, d in data.duel do
	local p = newPart(d.name, v3(d.size), CFrame.new(v3(d.pos)) * rot(d.rot), col(d.color), d.mat, d.shape)
	p.Anchored = true
	if string.find(d.name, "Square") or string.find(d.name, "Piece") then
		p.CanCollide = false
	end
	p.Parent = duel
end
for name, an in data.anchors do
	local p = newPart(name, Vector3.new(1, 1, 1), CFrame.new(v3(an[1])) * rot(an[2]), Color3.new(1, 0, 1))
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = duel
end
duel.PrimaryPart = duel:FindFirstChild("Top")
duel.WorldPivot = CFrame.new(0, 0, 0)
fs.writeFile(ROOT .. "DuelTable.rbxm", roblox.serializeModel({ duel }))
print(string.format("[Rivals] wrote %d rivals, %d animations, DuelTable with %d parts", #rivals:GetChildren(), #anims:GetChildren(), #duel:GetChildren()))
