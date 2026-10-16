-- Holding W from a standstill, as the game plays it: Gameplay/Sprint ramps the speed from Run.StartSpeed to the
-- runner's 24 over Run.Ramp seconds (smoothstep), and Roblox's Animate blends the owner's Walk into their Run by
-- speed (walk alone up to 8 studs/s, all run from 16, each sped up with the speed: R15 Animate's setRunSpeed).
-- 0-1 s idle, 1-5.5 s holding W (a dash at 4 s), 5.5-8 s let go and stand.
-- sh video.sh ramp_scene.luau out.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local Run = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Run.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local function anim(name) return KFS.load(lib:FindFirstChild(name, true)) end
local idle, walk, run, dash = anim("Idle"), anim("Walk"), anim("Run"), anim("Dash")

local scene = Scene.new()
local rig = scene:addRig(Rig.r15("Runner", { shirt = "#3a5bd0", pants = "#22232c" }))
-- a strip of ground markers every 4 studs so the speed shows
for i = 0, 60 do scene:addBox(CFrame.new(1.8, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#8a7a55") end

local FPS, DT, SECONDS = 30, 1 / 30, 8
local z, speed, held = 0, 0, 0
local tWalk, tRun, tIdle = 0, 0, 0
local function smooth(u) return u * u * (3 - 2 * u) end
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local holding = t >= 1 and t < 5.5
	if holding then held += DT else held = 0 end
	local want = if holding then Run.StartSpeed + (24 - Run.StartSpeed) * smooth(math.clamp(held / Run.Ramp, 0, 1)) else 0
	speed += (want - speed) * (1 - math.exp(-DT * (if holding then 30 else 10))) -- (Humanoid acceleration)
	z -= speed * DT
	-- Animate: walk/run weights and time-warp by speed (normalised by 16)
	local n = speed / 16
	local runW = math.clamp((n - 0.5) / 0.5, 0, 1)
	tWalk += DT * math.max(n / 0.5, 0.01)
	tRun += DT * math.max(n, 0.01)
	tIdle += DT
	local moving = math.clamp(speed / 2, 0, 1)
	KFS.apply(idle, rig, tIdle)
	KFS.apply(walk, rig, tWalk, moving * (1 - runW))
	if runW > 0 then KFS.apply(run, rig, tRun, moving * runW) end
	if t >= 4 and t < 4 + dash.length / 1.15 then
		local age = (t - 4) * 1.15
		local w = math.min(1, age / 0.05, (dash.length - age) / 0.12)
		KFS.apply(dash, rig, age, math.clamp(w, 0, 1))
		z -= 30 * DT * math.clamp(1 - age / dash.length, 0, 1) -- (the dash push)
	end
	rig.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, z), Vector3.new(0, Rig.REST_HEIGHT, z - 1))
	Rig.fk(rig)
	scene:frame(Vector3.new(11, 3.5, z - 2), Vector3.new(0, 2.4, z - 1))
end
scene:save(nil, FPS, 1280, 640)
