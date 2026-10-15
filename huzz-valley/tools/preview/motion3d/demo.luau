-- Pipeline proof: one R15 rig walks a slow circle for 4 s with a procedural walk; the camera follows from behind.
-- Run: sh video.sh demo.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")

local FPS, SECONDS = 30, 4
local RADIUS, SPEED = 8, 6 -- studs, studs per second
local STRIDE = 4.8 -- studs per full gait cycle (two steps)
local LEG = 2.7 -- hip joint to sole
local rad, sin, cos = math.rad, math.sin, math.cos

local scene = Scene.new()
local rig = scene:addRig(Rig.r15("Walker", { shirt = "#2f6fe0", pants = "#262a36" }))
scene:addBox(CFrame.new(0, 0.5, 0), Vector3.new(1, 1, 1), "#e05a3a") -- circle centre marker
local M = {}
for _, m in rig.motors do M[m.Name] = m end

local camPos
for f = 0, FPS * SECONDS - 1 do
	local t = f / FPS
	local angle = SPEED * t / RADIUS
	local pos = Vector3.new(RADIUS * cos(angle), 0, RADIUS * sin(angle))
	local dir = Vector3.new(-sin(angle), 0, cos(angle)) -- walking direction (tangent)
	local phase = 2 * math.pi * SPEED * t / STRIDE
	local swing = rad(30) * sin(phase) -- right leg forward when positive

	M.RightHip.Transform = CFrame.Angles(swing, 0, 0)
	M.LeftHip.Transform = CFrame.Angles(-swing, 0, 0)
	-- Knees bend while the leg swings back behind the body (negative X bends the shin backward).
	M.RightKnee.Transform = CFrame.Angles(-rad(45) * math.max(0, -sin(phase)), 0, 0)
	M.LeftKnee.Transform = CFrame.Angles(-rad(45) * math.max(0, sin(phase)), 0, 0)
	-- Arms swing opposite to their own side's leg, elbows slightly bent forward.
	M.RightShoulder.Transform = CFrame.Angles(-swing * 0.8, 0, 0)
	M.LeftShoulder.Transform = CFrame.Angles(swing * 0.8, 0, 0)
	M.RightElbow.Transform = CFrame.Angles(rad(15), 0, 0)
	M.LeftElbow.Transform = CFrame.Angles(rad(15), 0, 0)
	-- Drop the hips so the straighter leg keeps its foot on the ground.
	M.Root.Transform = CFrame.new(0, -LEG * (1 - cos(swing)), 0)

	rig.root.CFrame = CFrame.lookAt(pos + Vector3.new(0, Rig.REST_HEIGHT, 0), pos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)
	Rig.fk(rig)

	-- Roblox-style follow camera: ~12 studs back, 5 up, swung 35 degrees off straight-behind (a 3/4 view).
	local back = (CFrame.Angles(0, rad(35), 0) * CFrame.lookAt(Vector3.zero, dir)).LookVector * -12
	local target = pos + back + Vector3.new(0, 5 + Rig.REST_HEIGHT, 0)
	camPos = if camPos then camPos:Lerp(target, 0.15) else target
	scene:frame(camPos, pos + Vector3.new(0, Rig.REST_HEIGHT + 1, 0))
end

scene:save(nil, FPS, 1280, 720)
