-- Setting off, stopping and turning, before and after (owner, Oct 19 18:16: "make the head not move for the user when
-- he runs, for example when he presses D, the body turns right, but the head and camera stays the same, and also add
-- some velocity into the game, and add animations for when you stop running ... and then the slow walking into the
-- running animation"). Two runners take the same keys, the camera behind them looking ahead the whole time:
-- left BEFORE (Oct 19 morning: the run at once, the legs running on in place ~0.3 s after a stop, the head turning
-- with the body), right AFTER (Shared/LocomotionMix SetOff, StopResponse, Stop and look(), Config/Run.Loco).
-- Keys: W 0.5 s (set off), let go 2.0 s (stop), D 2.8 s without shift lock (Roblox turns the body right; the camera
-- stays), let go 4.3 s (stop). The ground stops at once, as Roblox's Humanoid and Huss Valley's (measured).
-- sh video.sh feel_scene.luau out.mp4   (repo root; sheet against HV: feel_sheet.py)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local Shot = Env.load(SHARED .. "CinematicShot.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

-- the morning's numbers (before this change)
local old = table.clone(Run.Loco)
old.SetOff, old.StopResponse, old.WeightTime, old.Stop, old.Look = nil, nil, nil, nil, nil

local scene = Scene.new()
for i = -6, 40 do
	for x = -30, 40, 6 do
		scene:addBox(CFrame.new(x, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#6f9a52")
	end
end
local GAP = 7
local runners = {}
for i, after in { false, true } do
	local rig = scene:addRig(Rig.r15(if after then "After" else "Before",
		{ shirt = if after then "#2f7de0" else "#7a7f8c", pants = "#1d1f2a", hair = "#2a1a10" }))
	-- a red cap brim, so which way the head faces shows from behind
	table.insert(rig.decor, { part = rig.parts.Head, offset = CFrame.new(0, 0.62, -0.55), Size = Vector3.new(1.25, 0.12, 0.7), Color = "#e04a3a" })
	runners[i] = { rig = rig, after = after, mix = Mix.new(if after then nil else old), x = (if after then 1 else -1) * GAP / 2, idleT = 0 }
end

local FPS, DT, SECONDS = 30, 1 / 30, 5.2
local CAP, START, TAU = Round.Speeds.Runner, Run.StartSpeed, Run.Ramp / 3
local HIP = Rig.REST_HEIGHT - 1
local KEYS = { { 0.5, Vector3.new(0, 0, -1), "W" }, { 2.0, nil, "let go" }, { 2.8, Vector3.new(1, 0, 0), "D (no shift lock)" }, { 4.3, nil, "let go" } }
local pos, yaw, built, wasHeld = Vector3.zero, 0, START, false
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local want, key = nil, "idle"
	for _, k in KEYS do
		if t >= k[1] then want, key = k[2], k[3] end
	end
	-- Gameplay/Sprint: set off at StartSpeed, build to the cap; Roblox's Humanoid: the ground speed follows at once
	if want and not wasHeld then built = START end
	wasHeld = want ~= nil
	if want then built += (CAP - built) * (1 - math.exp(-DT / TAU)) end
	local vel = if want then want * built else Vector3.zero
	-- Roblox's AutoRotate turns the body to the move (no shift lock)
	if want then
		local target = math.atan2(-want.X, -want.Z)
		local d = (target - yaw + math.pi) % (2 * math.pi) - math.pi
		yaw += d * (1 - math.exp(-DT / 0.06))
	end
	pos += vel * DT
	local bodyCF = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local labels = {}
	for _, r in runners do
		local rig, mix = r.rig, r.mix
		Mix.step(mix, DT, { speed = vel.Magnitude, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
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
		local rootJ = rig.parts.LowerTorso.joints.Root
		local roll, pitch = Mix.lean(mix, DT, yaw, 0)
		rootJ.Transform = rootJ.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * rootJ.C0 * rootJ.Transform
		if r.after then
			-- the head looks where the camera looks (straight ahead, -Z), as Gameplay/Locomotion asks
			local l = bodyCF:VectorToObjectSpace(Vector3.new(0, 0, -1))
			local look = Mix.look(mix, DT, math.atan2(l.X, -l.Z), true, 0)
			if math.abs(look) > 1e-3 then
				local waist, neck = rig.parts.UpperTorso.joints.Waist, rig.parts.Head.joints.Neck
				local a, b, c = Mix.strafePose(mix, 0, {
					root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
					waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
					neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
				}, look)
				rootJ.Transform, waist.Transform, neck.Transform = a, b, c
			end
			local plant = Mix.stopAmount(mix)
			if plant > 1e-4 then
				for side, name in { [1] = "RightUpperArm", [-1] = "LeftUpperArm" } do
					local j = rig.parts[name].joints[(if side == 1 then "Right" else "Left") .. "Shoulder"]
					j.Transform = Mix.stopArm(mix, plant, side) * j.Transform
				end
			end
		end
		rig.root.CFrame = CFrame.new(pos + Vector3.new(r.x, Rig.REST_HEIGHT, 0)) * CFrame.Angles(0, yaw, 0)
		Rig.fk(rig)
		table.insert(labels, { p = { pos.X + r.x, 7.2, pos.Z }, text = if r.after then "AFTER" else "BEFORE", h = 0.9, c = "#ffffff", o = "#000000" })
	end
	-- the camera behind, looking ahead (-Z) the whole time, following
	local focus = pos + Vector3.new(0, Shot.FocusHeight, 0)
	local eye, at = Shot.behind(Vector3.new(0, 0, -1), focus)
	eye = focus + (eye - focus) * 1.35
	scene:frame(eye, at, { labels = labels, caption = string.format("%.2f s  key: %s   (left before, right after)", t, key) })
end
scene:save(nil, FPS, 1280, 720, { sky = "#9fd3f7", ground = "#3fbf4f" })
