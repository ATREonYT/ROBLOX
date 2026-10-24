-- Shift lock, before and after (owner, Oct 19: "make it so when you shift lock the only thing that moves when you press
-- w a s d (etc) is their body not their head"). Two runners take the same keys in shift lock, the camera behind them
-- the way the round camera sits (Shared/CinematicShot): left BEFORE (the body held to the camera: A/D slide sideways
-- with the run playing straight ahead, S moonwalks), right AFTER (Shared/LocomotionMix.strafe: the hips and legs turn
-- toward the move, the head keeps facing ahead, S back-pedals). The pack's Idle/Walk/Run as Gameplay/Locomotion blends
-- them. Keys: W 0.6 s, D 2.0 s, W 3.4 s, A 4.4 s, S 5.6 s, let go 6.8 s.
-- sh video.sh strafe_scene.luau out.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Round = Env.load(SHARED .. "Config/Round.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local Shot = Env.load(SHARED .. "CinematicShot.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local scene = Scene.new()
for i = -6, 40 do
	for x = -24, 24, 6 do
		scene:addBox(CFrame.new(x, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#6f9a52")
	end
end
local GAP = 7
local runners = {}
for i, after in { false, true } do
	local rig = scene:addRig(Rig.r15(if after then "After" else "Before",
		{ shirt = if after then "#2f7de0" else "#7a7f8c", pants = "#1d1f2a", hair = "#2a1a10" }))
	-- a nose and a cap brim so which way the head faces shows from behind too
	table.insert(rig.decor, { part = rig.parts.Head, offset = CFrame.new(0, 0.62, -0.55), Size = Vector3.new(1.25, 0.12, 0.7), Color = "#e04a3a" })
	runners[i] = { rig = rig, after = after, mix = Mix.new(), x = (if after then 1 else -1) * GAP / 2, idleT = 0 }
end

local FPS, DT, SECONDS = 30, 1 / 30, 8
local KEYS = { { 0.6, Vector3.new(0, 0, -1) }, { 2.0, Vector3.new(1, 0, 0) }, { 3.4, Vector3.new(0, 0, -1) },
	{ 4.4, Vector3.new(-1, 0, 0) }, { 5.6, Vector3.new(0, 0, 1) }, { 6.8, nil } }
local LABEL = { [0.6] = "W", [2.0] = "D", [3.4] = "W", [4.4] = "A", [5.6] = "S", [6.8] = "let go" }
local vel = Vector3.zero
local pos = Vector3.zero
local cap = Round.Speeds.Runner
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local want, key = nil, ""
	for _, k in KEYS do
		if t >= k[1] then want, key = k[2], LABEL[k[1]] end
	end
	-- the Humanoid speeding up and slowing down (shift lock: the body always faces the camera, -Z)
	local target = if want then want * cap else Vector3.zero
	vel += (target - vel) * (1 - math.exp(-DT * (if want then 12 else 18)))
	pos += vel * DT
	local labels = {}
	for _, r in runners do
		local rig, mix = r.rig, r.mix
		local speed = vel.Magnitude
		local turn = 0
		if r.after then
			turn = Mix.strafe(mix, DT, vel, true, 0)
		end
		Mix.step(mix, DT, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
		r.idleT += DT
		local total = 0
		local function layer(anim, at, w)
			if w <= 1e-4 then return end
			total += w
			KFS.apply(anim, rig, at, w / total)
		end
		layer(A.Idle, r.idleT, mix.weights.Idle)
		layer(A.Walk, mix.times.Walk, mix.weights.Walk)
		layer(A.Run, mix.times.Run, mix.weights.Run)
		if r.after and math.abs(turn) > 1e-3 then
			local rootJ = rig.parts.LowerTorso.joints.Root
			local waist, neck = rig.parts.UpperTorso.joints.Waist, rig.parts.Head.joints.Neck
			local a, b, c = Mix.strafePose(mix, turn, {
				root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
				waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
				neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
			})
			rootJ.Transform, waist.Transform, neck.Transform = a, b, c
		end
		rig.root.CFrame = CFrame.new(pos + Vector3.new(r.x, Rig.REST_HEIGHT, 0))
		Rig.fk(rig)
		table.insert(labels, { p = { pos.X + r.x, 7.2, pos.Z }, text = if r.after then "AFTER" else "BEFORE", h = 0.9, c = "#ffffff", o = "#000000" })
	end
	-- the round camera behind them both (Shared/CinematicShot.behind), a little wider so both fit
	local focus = pos + Vector3.new(0, Shot.FocusHeight, 0)
	local eye, at = Shot.behind(Vector3.new(0, 0, -1), focus)
	eye = focus + (eye - focus) * 1.35
	scene:frame(eye, at, { labels = labels, caption = "Shift lock, key: " .. key .. "   (left before, right after)" })
end
scene:save(nil, FPS, 1280, 720, { sky = "#9fd3f7", ground = "#3fbf4f" })
