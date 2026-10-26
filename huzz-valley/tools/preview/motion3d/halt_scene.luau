-- The run's 1 s build-up and the halt (owner, Oct 20 07:55: "Make acceleration 1 second long and after they randomly
-- stop after fully running they move a little forward as a sort of "hault" like in the game Huss valley"), filmed the
-- way Huss Valley's recording shows its one full-speed stop (f1c7bb86, 40.3 to 41.6 s): the camera turned round in
-- front of the runner and a little above (~20 degrees down, ~10 studs off), the runner coming toward it and a little
-- to the left, facing the way it runs (critic, Oct 20: the first film was from behind, not the same framing). Two
-- runners on the same keys: BEFORE (the 0.5 s build, the ground stops at once) and AFTER (Gameplay/Sprint:
-- RunMotion.rampSpeed over 1 s; Shared/Halt: the body carries on along the ground over Run.Halt.Time while the legs
-- plant and brace, LocomotionMix input.halt and Stop.Halt.Brace).
-- Keys: W from 0.3 s, let go at 1.8 s.
-- sh video.sh halt_scene.luau out.mp4   (repo root; HALT_ONLY=after films only the AFTER runner, for the side by side)
local fs = require("@lune/fs")
local process = require("@lune/process")
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
local RunMotion = Env.load(SHARED .. "RunMotion.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local only = process.env.HALT_ONLY
local scene = Scene.new()
for x = -32, 14, 2 do
	for z = -10, 52, 2 do
		if (x + z) % 4 == 0 then
			scene:addBox(CFrame.new(x, 0.03, z), Vector3.new(0.9, 0.06, 0.9), "#2f9a52")
		end
	end
end
-- a white line slanting across the run near the stop (HV's field line), to see the slide against
scene:addBox(CFrame.new(-8, 0.04, 33) * CFrame.Angles(0, 0.3, 0), Vector3.new(50, 0.08, 0.5), "#ffffff")

local CAP, START = Round.Speeds.Runner, Run.StartSpeed
local LANE = 9
local runners = {}
for _, after in { false, true } do
	if only == "after" and not after then continue end
	local rig = scene:addRig(Rig.r15(if after then "After" else "Before", { shirt = "#1c1c24", pants = "#15151c", hair = "#2a1a10" }))
	table.insert(runners, { rig = rig, after = after, mix = Mix.new(), z = if after or only then 0 else -LANE, pos = Vector3.zero, idleT = 0,
		built = 0, halt = nil })
end

local FPS, DT, SECONDS = 30, 1 / 30, 3.2
local SUB = 4 -- physics steps a frame (the game runs at 60+)
local GO, LET = 0.3, 1.8
local HIP = Rig.REST_HEIGHT - 1
local DIR = Vector3.new(-0.3, 0, 1).Unit -- (toward the camera and a little left: HV's runner at 40.3 to 41.2 s)
local YAW = math.atan2(-DIR.X, -DIR.Z) -- (the body faces the way it runs)
local track = {}
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local held = t >= GO and t < LET
	local labels = {}
	for _, r in runners do
		local speed = 0
		for _ = 1, SUB do
			local dt = DT / SUB
			if held then
				r.built += dt
				if r.after then
					speed = RunMotion.rampSpeed(START, CAP, r.built)
				else
					speed = START + (CAP - START) * (1 - math.exp(-r.built / (0.5 / 3))) -- (the 0.5 s build before)
				end
				r.last = speed
			elseif r.after and r.last and r.last > 0 and RunMotion.haltFrom(r.last, CAP, START) and not r.halt then
				r.halt = { t = 0, cfg = RunMotion.haltPush(r.last) }
				r.last = 0
			end
			if not held and r.halt then
				speed = RunMotion.pushSpeed(r.halt.cfg, r.halt.t) or 0
				r.halt.t += dt
				if speed == 0 then r.halt.done = true end
			end
			r.pos += DIR * speed * dt
		end
		local halting = r.halt ~= nil and not r.halt.done
		local turn = Mix.strafe(r.mix, DT, DIR * speed, false, 0)
		Mix.step(r.mix, DT, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length }, halt = halting })
		r.idleT += DT
		local rig, mix = r.rig, r.mix
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
		local roll, pitch = Mix.lean(mix, DT, YAW, 0)
		rootJ.Transform = rootJ.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * rootJ.C0 * rootJ.Transform
		-- the halt's braced stance (as Gameplay/Locomotion puts it on)
		local brace = Mix.brace(mix)
		if brace > 1e-4 then
			for part, joint in { LowerTorso = "Root", RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee" } do
				local j = rig.parts[part].joints[joint]
				j.Transform = Mix.braceJoint(mix, brace, joint, j.C0) * j.Transform
			end
		end
		if math.abs(turn) > 1e-3 then
			local waist, neck = rig.parts.UpperTorso.joints.Waist, rig.parts.Head.joints.Neck
			local a, b, c = Mix.strafePose(mix, turn, {
				root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
				waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
				neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
			})
			rootJ.Transform, waist.Transform, neck.Transform = a, b, c
		end
		local plant = Mix.stopAmount(mix)
		if plant > 1e-4 then
			for side, name in { [1] = "RightUpperArm", [-1] = "LeftUpperArm" } do
				local j = rig.parts[name].joints[(if side == 1 then "Right" else "Left") .. "Shoulder"]
				j.Transform = Mix.stopArm(mix, plant, side) * j.Transform
			end
		end
		rig.root.CFrame = CFrame.new(r.pos + Vector3.new(r.z, Rig.REST_HEIGHT, 0)) * CFrame.Angles(0, YAW, 0)
		Rig.fk(rig)
		if not only then
			table.insert(labels, { p = { r.pos.X + r.z, 7.2, r.pos.Z }, text = if r.after then "AFTER" else "BEFORE", h = 0.9, c = "#ffffff", o = "#000000" })
		end
		if r.after then table.insert(track, { t = t, x = r.pos:Dot(DIR), speed = speed, halt = halting }) end
	end
	-- the camera follows the AFTER runner from in front and a little above, as HV's at 41 s (it keeps its distance
	-- while the runner comes toward it, so the runner stays put on screen and the ground flows under)
	local focusPos = runners[#runners].pos
	local focus = focusPos + Vector3.new(if only then 0 else -LANE / 2, 2.4, 0)
	local eye = focus + (if only then Vector3.new(1, 4.4, 7.2) else Vector3.new(3, 9, 24))
	local key = if t < GO then "idle" elseif held then "W (building up)" else "let go"
	scene:frame(eye, focus + Vector3.new(0.6, -0.9, 0), { labels = labels, caption = if only then nil else string.format("%.2f s  key: %s", t, key) })
end
-- where the AFTER runner went after letting go (studs past the let-go point, per frame)
local at, prev = nil, 0
for _, p in track do
	if not at and p.t >= LET then at = prev end
	prev = p.x
	if at and p.t <= LET + 0.45 then
		print(string.format("  %.3f s  %5.2f studs on  %5.1f studs/s%s", p.t, p.x - at, p.speed, if p.halt then "  halt" else ""))
	end
end
scene:save(nil, FPS, if only then 720 else 1280, 720, { sky = "#8fd0f5", ground = "#24a95a" })
