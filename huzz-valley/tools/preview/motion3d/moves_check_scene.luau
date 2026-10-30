-- The owner's Oct 20 14:07 questions about his own moves ("can you check the animations ... for the users again, i
-- still have questions to it, it doesnt seem fixed"), filmed the way his recording was (1407-animations.mov: Studio,
-- standing still facing the camera, the camera in front and a little above, the mouse moving past him). One runner,
-- the real layers as Gameplay/Locomotion stacks them (Shared/LocomotionMix: the pack's Idle/Walk/Run blended by
-- speed, the lean, the head on the mouse with LocomotionMix.aimFrom + look + strafePose, the stop plant, the halt's
-- brace; Gameplay/Sprint's 1 s build-up and Shared/Halt's slide via RunMotion). No shift lock (his lobby camera):
-- Roblox's AutoRotate turns the body to the move.
--   0.0 - 2.4 s  standing, the cursor swept across the field past him (left, right, middle)
--   2.4 - 3.8 s  A held (the body turns and runs to the screen's left, the cursor kept on the far field)
--   3.8 - 5.2 s  D held (the other way), let go: a full-speed stop is a halt
--   5.9 - 7.6 s  W toward the camera (the 1 s build-up), let go at 7.6 s: the halt, then standing
-- sh video.sh moves_check_scene.luau out.mp4   (repo root). Prints the head's turn and the speed each 0.2 s.
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
local RunMotion = Env.load(SHARED .. "RunMotion.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local scene = Scene.new()
-- his Halloween field: orange tiles and a white line behind him
for x = -40, 40, 2 do
	for z = -30, 30, 2 do
		if (x + z) % 4 == 0 then
			scene:addBox(CFrame.new(x, 0.03, z), Vector3.new(1.8, 0.06, 1.8), "#d9893a")
		end
	end
end
scene:addBox(CFrame.new(0, 0.04, -3), Vector3.new(90, 0.08, 1.2), "#f4fbff")
local rig = scene:addRig(Rig.r15("You", { shirt = "#16161c", pants = "#111116", hair = "#141010" }))

local CAP, START = Round.Speeds.Runner, Run.StartSpeed
local FPS, DT, SECONDS = 30, 1 / 30, 8.8
local SUB = 4
local HIP = Rig.REST_HEIGHT - 1
local TURN_RATE = 14 -- (Roblox's AutoRotate: the body comes round to the move in ~0.15 s)

-- keys: direction in the world (camera at +Z looking -Z: the screen's left is -X)
local function keyAt(t)
	if t >= 2.4 and t < 3.8 then return Vector3.new(-1, 0, 0), "A" end
	if t >= 3.8 and t < 5.2 then return Vector3.new(1, 0, 0), "D" end
	if t >= 5.9 and t < 7.6 then return Vector3.new(0, 0, 1), "W" end
	return nil, "none"
end
-- where the cursor points: on the far field past him, swept left - right - middle while he stands
local function cursorX(t)
	if t < 0.4 then return 0 end
	if t < 1.2 then return -16 * math.sin((t - 0.4) / 0.8 * math.pi / 2) end
	if t < 2.0 then return -16 + 32 * ((t - 1.2) / 0.8) end
	if t < 2.4 then return 16 * (1 - (t - 2.0) / 0.4) end
	return 6 * math.sin(t * 1.3)
end

local mix = Mix.new()
local pos, yaw, idleT = Vector3.zero, 0, 0 -- yaw 0 faces -Z; facing the camera = pi
yaw = math.pi
local built, last, halt, lastDir = 0, 0, nil, Vector3.new(0, 0, 1)
local log = {}
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local dir, key = keyAt(t)
	local speed = 0
	for _ = 1, SUB do
		local dt = DT / SUB
		if dir then
			if halt then halt = nil end
			built += dt
			speed = RunMotion.rampSpeed(START, CAP, built)
			last, lastDir = speed, dir
			local want = math.atan2(-dir.X, -dir.Z)
			local d = (want - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw += d * math.min(1, TURN_RATE * dt)
		else
			if last > 0 and not halt and RunMotion.haltFrom(last, CAP, START) then
				halt = { t = 0, cfg = RunMotion.haltPush(last) }
			end
			last, built = 0, 0
			if halt then
				speed = RunMotion.pushSpeed(halt.cfg, halt.t) or 0
				halt.t += dt
				if speed == 0 then halt.done = true end
			end
		end
		pos += lastDir * speed * dt
	end
	local halting = halt ~= nil and not halt.done
	Mix.step(mix, DT, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length }, halt = halting })
	idleT += DT
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, rig, at, w / total)
	end
	layer(A.Idle, idleT, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)

	-- order 12: Gameplay/Locomotion's layers, as it stacks them
	local rootCF = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT, 0)) * CFrame.Angles(0, yaw, 0)
	local rootJ = rig.parts.LowerTorso.joints.Root
	local roll, pitch = Mix.lean(mix, DT, yaw, 0)
	local hipsPose = rootJ.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * rootJ.C0 * rootJ.Transform
	local brace = Mix.brace(mix)
	if brace > 1e-4 then
		hipsPose = Mix.braceJoint(mix, brace, "Root", rootJ.C0) * hipsPose
	end
	local turn = Mix.strafe(mix, DT, rootCF:VectorToObjectSpace(lastDir * speed), false, 0)
	local cursor = Vector3.new(pos.X + cursorX(t), 0, pos.Z - 30) -- (the far field past him, where the ray lands)
	local eyes = rootCF.Position + Vector3.new(0, 1.5, 0)
	local aim, up = Mix.aimFrom(rootCF:VectorToObjectSpace(cursor - eyes))
	local look, tilt = Mix.look(mix, DT, aim, true, 0, up)
	local waist, neck = rig.parts.UpperTorso.joints.Waist, rig.parts.Head.joints.Neck
	if math.abs(turn) > 1e-3 or math.abs(look) > 1e-3 or math.abs(tilt) > 1e-3 then
		local a, b, c = Mix.strafePose(mix, turn, {
			root = { C0 = rootJ.C0, C1 = rootJ.C1, T = hipsPose },
			waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
			neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
		}, look, tilt)
		hipsPose, waist.Transform, neck.Transform = a, b, c
	end
	rootJ.Transform = hipsPose
	local plant = Mix.stopAmount(mix)
	if plant > 1e-4 then
		for side, name in { [1] = "RightUpperArm", [-1] = "LeftUpperArm" } do
			local j = rig.parts[name].joints[(if side == 1 then "Right" else "Left") .. "Shoulder"]
			j.Transform = Mix.stopArm(mix, plant, side) * j.Transform
		end
	end
	if brace > 1e-4 then
		for part, joint in { RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee" } do
			local j = rig.parts[part].joints[joint]
			j.Transform = Mix.braceJoint(mix, brace, joint, j.C0) * j.Transform
		end
	end
	rig.root.CFrame = rootCF
	Rig.fk(rig)
	if f % 6 == 0 then
		table.insert(log, string.format("  %.1f s  key %-4s  speed %5.1f  head turn %4.0f  tilt %4.0f%s", t, key, speed,
			math.deg(look), math.deg(tilt), if halting then "  halt" else ""))
	end

	-- the camera: in front and a little above, following him (Roblox's Classic camera), as in his recording
	local focus = pos + Vector3.new(0, 2.6, 0)
	local eye = focus + Vector3.new(0, 4.2, 11)
	local caption = string.format("%.1f s   key: %s", t, if key == "none" then (if halting then "let go: halt" else "none") else key)
	scene:frame(eye, focus + Vector3.new(0, -0.6, 0), {
		caption = caption,
		labels = { { p = { cursor.X, 0.6, cursor.Z }, text = "mouse", h = 0.9, c = "#ff4040", o = "#000000" } },
	})
end
print(table.concat(log, "\n"))
scene:save(nil, FPS, 720, 720, { sky = "#8fc8f0", ground = "#e0974a" })
