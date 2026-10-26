-- A caught runner going down and lying still (Shared/DownMotion), owner Oct 18: "not have a swinging animations ...
-- you go like in and under the map, just make them lay on the floor and look like their dead". The run animation
-- (with its hip bob and crouch) keeps playing under the body the whole time, as Roblox's Animator does in the game.
-- sh video.sh down_scene.luau out.mp4   (0.6 s running, caught, then 2.4 s lying; low side view at floor level)
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local DownMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/DownMotion.lua")

local FPS, DT, SECONDS = 30, 1 / 30, 3
local rad, sin = math.rad, math.sin
local scene = Scene.new()
local runner = scene:addRig(Rig.r15("Runner", { shirt = "#1d1d22", pants = "#141418" }))
local M = {}
for _, m in runner.motors do M[m.Name] = m end
local function run(phase)
	local swing = rad(40) * sin(phase)
	for _, m in runner.motors do m.Transform = CFrame.identity end
	M.Root.Transform = CFrame.new(0, -0.35 + 0.25 * math.abs(sin(phase)), 0) * CFrame.Angles(-rad(14), 0, 0)
	M.RightHip.Transform = CFrame.Angles(swing, 0, 0)
	M.LeftHip.Transform = CFrame.Angles(-swing, 0, 0)
	M.RightKnee.Transform = CFrame.Angles(-rad(60) * math.max(0, -sin(phase)), 0, 0)
	M.LeftKnee.Transform = CFrame.Angles(-rad(60) * math.max(0, sin(phase)), 0, 0)
	M.RightShoulder.Transform = CFrame.Angles(-swing, 0, 0)
	M.LeftShoulder.Transform = CFrame.Angles(swing, 0, 0)
	M.RightElbow.Transform = CFrame.Angles(rad(70), 0, 0)
	M.LeftElbow.Transform = CFrame.Angles(rad(70), 0, 0)
end
local z, down, feet = 6, nil, nil
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	run(t * 14)
	if t < 0.6 then
		z -= 26 * DT
		runner.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT - 0.35, z)
	else
		if not down then
			down = DownMotion.new(runner.motors)
			feet = CFrame.new(0, 0, z)
		end
		runner.root.CFrame = DownMotion.rootCFrame(feet, Rig.REST_HEIGHT, t - 0.6)
		DownMotion.step(down, t - 0.6)
	end
	Rig.fk(runner)
	scene:frame(Vector3.new(6.5, 4.5, z + 1.5), Vector3.new(0, 0.6, z - 2.2))
end
scene:save(nil, FPS, 1280, 720)
