-- Crown Pose (Shared/CrownPose): two rigs strike it, filmed from the front and from 3/4, with the crown.
-- sh video.sh crown_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local CrownPose = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CrownPose.lua")

local FPS, SECONDS = 30, 4
local scene = Scene.new()
local rigs = {}
for i, x in { -2.6, 2.6 } do
	local rig = Rig.r15("R" .. i)
	rig.root.CFrame = CFrame.new(x, 3, 0) * CFrame.Angles(0, if i == 1 then 0 else math.rad(-40), 0)
	scene:addRig(rig)
	rigs[i] = rig
end
local crownBoxes = {}
for i in rigs do
	crownBoxes[i] = {}
	for _, p in CrownPose.parts() do
		table.insert(crownBoxes[i], { def = p, box = scene:addBox(CFrame.identity, p.size, if p.kind == "Gem" then "#ff5fb4" else "#eef0ff") })
	end
end
local times = {}
local process = require("@lune/process")
for f = 0, SECONDS * FPS - 1 do table.insert(times, f / FPS - 0.3) end
if process.env.STILL then times = { tonumber(process.env.STILL) } end -- one frame at that second (for tuning)
for _, t in times do
	for i, rig in rigs do
		local joints = {}
		for _, m in rig.motors do m.Transform = CFrame.identity; joints[m.Name] = m end
		CrownPose.apply(joints, t)
		Rig.fk(rig)
		local up, spin, k = CrownPose.crownAt(t)
		local head = rig.parts.Head
		local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.5 + 0.12 + up, 0) * CFrame.Angles(0, spin, 0)
		for _, c in crownBoxes[i] do
			c.box.CFrame = top * CFrame.new(c.def.cf.Position * k) * c.def.cf.Rotation
			c.box.Size = c.def.size * math.max(k, 0.001)
		end
	end
	scene:frame(Vector3.new(0, 5, -11), Vector3.new(0, 4, 0))
end
scene:save(nil, FPS, 960, 540)
