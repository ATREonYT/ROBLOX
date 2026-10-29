-- How smooth your own character's moves are, in numbers (owner Oct 19: "make animations more smooth"). Runs the
-- game's own layers in the game's order on the owner's pack: the Idle/Walk/Run blend (Shared/LocomotionMix, as
-- Gameplay/Locomotion asks for it), the huss pose (Shared/RunMotion, Gameplay/RunAnimator), the lean and the shift-lock
-- body turn (LocomotionMix.lean / LocomotionMix.strafe, Gameplay/Locomotion), the stab and the leap
-- (Shared/StabMotion, Gameplay/Actions), at 30 fps (what the owner's eye and our films see) and 60 fps.
-- For each moment it prints the biggest turn of any body part in one frame (relative to the HumanoidRootPart) and
-- its "pop": how much that turn is bigger than the frame before's (a smooth swing grows a little each frame; a pop
-- jumps from still to fast in one frame).
-- lune run huzz-valley/tools/preview/motion3d/move_smooth_measure.luau [fps]     (repo root)
-- MOVE_SHARED=<folder>/ measures another copy of Shared (the code before a change: git archive <commit>
-- huzz-valley/src/ReplicatedStorage/Shared | tar -x -C /tmp/before, MOVE_SHARED=/tmp/before/huzz-valley/src/ReplicatedStorage/Shared/).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = process.env.MOVE_SHARED or "huzz-valley/src/ReplicatedStorage/Shared/"
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(SHARED .. "StabMotion.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local M = {}
-- MOVE_TRACE="Part,Part:from:to" prints those parts frame by frame between from and to seconds.
local TRACE = nil
if process.env.MOVE_TRACE then
	local names, from, to = string.match(process.env.MOVE_TRACE, "^([^:]+):([%d.]+):([%d.]+)$")
	TRACE = { from = tonumber(from), to = tonumber(to) }
	for n in string.gmatch(names, "[^,]+") do TRACE[n] = true end
end

local function angleOf(cf)
	local _, ang = cf.Rotation:ToAxisAngle()
	ang = math.deg(math.abs(ang)) % 360
	return math.min(ang, 360 - ang)
end

-- The timeline (seconds): what the player does. strafe: the move's way in the body's frame while shift lock holds
-- the body to the camera (x right, z back, Roblox's MoveDirection in object space).
M.EVENTS = {
	{ at = 0.0, what = "idle" },
	{ at = 1.0, what = "W: set off" },
	{ at = 2.4, what = "huss right" },
	{ at = 3.4, what = "D: strafe right (shift lock)" },
	{ at = 4.2, what = "W again" },
	{ at = 4.8, what = "click stab" },
	{ at = 5.6, what = "Space: leap" },
	{ at = 6.8, what = "S: back (shift lock)" },
	{ at = 7.6, what = "let go: stop" },
	{ at = 8.8, what = "W: run again" },
	{ at = 10.2, what = "let go: halt" }, -- (owner, Oct 20 07:55: the halt from a full run, Shared/Halt)
	{ at = 11.0, what = "end" },
}

function M.run(fps: number)
	local DT = 1 / fps
	local rig = Rig.r15("Me")
	local huss = RunMotion.new(rig)
	local stab = StabMotion.new(CarryMath.rig(rig), rig.root)
	local mix = Mix.new()
	local rootJoint = rig.parts.LowerTorso.joints.Root
	local HIP = Rig.REST_HEIGHT - 1
	local speed, built, idleT, held = 0, Run.StartSpeed, 0, 0
	local dash, push = nil, nil
	local halt = nil -- the halt after a full run (Gameplay/Sprint + Shared/Halt): { t, cfg }
	local lastDir = Vector3.new(0, 0, -1)
	local prevRel, prevTurn = {}, {}
	local out = {}
	local function window(t)
		local w = M.EVENTS[1]
		for _, e in M.EVENTS do
			if t >= e.at then w = e end
		end
		return w
	end
	for f = 0, math.floor(11.0 * fps) do
		local t = f * DT
		local moveDir -- in the body's frame
		if t >= 1.0 and t < 3.4 then moveDir = Vector3.new(0, 0, -1)
		elseif t >= 3.4 and t < 4.2 then moveDir = Vector3.new(1, 0, 0)
		elseif t >= 4.2 and t < 6.8 then moveDir = Vector3.new(0, 0, -1)
		elseif t >= 6.8 and t < 7.6 then moveDir = Vector3.new(0, 0, 1)
		elseif t >= 8.8 and t < 10.2 then moveDir = Vector3.new(0, 0, -1)
		end
		local holding = moveDir ~= nil
		lastDir = moveDir or lastDir -- (the body slides on the way it went while it slows)
		if holding and held == 0 then built = Run.StartSpeed end
		held = if holding then held + DT else 0
		local cap = Round.Speeds.Runner
		if holding and RunMotion.rampSpeed then
			built = RunMotion.rampSpeed(Run.StartSpeed, cap, held) -- (the 1 s build, Oct 20)
		elseif holding then
			built += (cap - built) * (1 - math.exp(-DT / (Run.Ramp / 3)))
		end
		local want = if holding then built else 0
		if holding then
			halt = nil
		elseif not halt and RunMotion.haltFrom and speed > 0 and RunMotion.haltFrom(speed, cap, Run.StartSpeed) then
			halt = { t = 0, cfg = RunMotion.haltPush(speed) }
		end
		local haltSpeed = if halt then RunMotion.pushSpeed(halt.cfg, halt.t) else nil
		if halt then halt.t += DT end
		if haltSpeed then
			speed = haltSpeed -- (the body carries on, slowing: Shared/Halt)
		else
			speed += (want - speed) * (1 - math.exp(-DT * (if holding then 30 else 18)))
		end
		if math.abs(t - 2.4) < DT / 2 then
			dash = { at = t }
		end
		if math.abs(t - 4.8) < DT / 2 then StabMotion.play(stab, t) end
		if math.abs(t - 5.6) < DT / 2 then StabMotion.play(stab, t, true) end
		local hussSpeed = if dash then RunMotion.pushSpeed(Round.Dash, t - dash.at) else nil
		local groundSpeed = speed
		if hussSpeed then groundSpeed = math.sqrt(speed * speed + hussSpeed * hussSpeed) end

		-- the pack (Gameplay/Locomotion: Roblox blends one priority's tracks by weight)
		Mix.step(mix, DT, {
			speed = groundSpeed, state = "ground", jumped = false,
			lengths = { Walk = A.Walk.length, Run = A.Run.length },
			halt = haltSpeed ~= nil,
		})
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
		-- order 10: the huss (Gameplay/RunAnimator, speed 0: only the huss)
		local age = if dash then t - dash.at else nil
		RunMotion.step(huss, DT, 0, true, false, age, if dash then Vector3.new(1, 0, 0) else nil)
		-- order 12: the lean and the shift-lock body turn (Gameplay/Locomotion)
		local hussing = age ~= nil and age < Run.Dash.Length + 0.1
		local leaping = stab.lunge and t - stab.start < StabMotion.LEAP.Up
		local quiet = if hussing or leaping then 1 else 0
		local roll, pitch = Mix.lean(mix, DT, 0, quiet)
		local pose = rootJoint.Transform
		rootJoint.Transform = rootJoint.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * rootJoint.C0 * pose
		-- the halt's braced stance (Gameplay/Locomotion, Run.Loco.Stop.Halt.Brace)
		local brace = if Mix.brace and quiet == 0 then Mix.brace(mix) else 0
		if brace > 1e-4 then
			for part, joint in { LowerTorso = "Root", RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee" } do
				local j = rig.parts[part].joints[joint]
				j.Transform = Mix.braceJoint(mix, brace, joint, j.C0) * j.Transform
			end
		end
		if Mix.strafe then
			local vel = lastDir * speed
			local turn = Mix.strafe(mix, DT, vel, true, quiet)
			local waist, neck = rig.parts.UpperTorso.joints.Waist, rig.parts.Head.joints.Neck
			local a, b, c = Mix.strafePose(mix, turn, {
				root = { C0 = rootJoint.C0, C1 = rootJoint.C1, T = rootJoint.Transform },
				waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
				neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
			})
			rootJoint.Transform, waist.Transform, neck.Transform = a, b, c
		end
		-- order 30: the stab and the leap (Gameplay/Actions)
		StabMotion.step(stab, t)
		rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(rig)

		-- measure
		local e = window(t)
		local rec = out[e.what] or { turn = 0, pop = 0, part = "", at = 0, popPart = "", popAt = 0 }
		out[e.what] = rec
		for name, p in rig.parts do
			if name ~= "HumanoidRootPart" then
				local rel = rig.root.CFrame:Inverse() * p.CFrame
				local last = prevRel[name]
				if last then
					local d = last:Inverse() * rel
					local ang = angleOf(d)
					if ang > rec.turn then rec.turn, rec.part, rec.at = ang, name, t end
					-- the pop: how far this frame's turn is from the last frame's (the same swing going on = 0)
					local before = prevTurn[name]
					local pop = if before then angleOf(before:Inverse() * d) else 0
					if pop > rec.pop then rec.pop, rec.popPart, rec.popAt = pop, name, t end
					prevTurn[name] = d
					if TRACE and TRACE[name] and t >= TRACE.from and t <= TRACE.to then
						print(string.format("    %.3f %-14s turn %6.1f pop %6.1f", t, name, ang, pop))
					end
				end
				prevRel[name] = rel
			end
		end
	end
	return out
end

if not process.args[1] or tonumber(process.args[1]) then
	local fps = tonumber(process.args[1]) or 30
	local out = M.run(fps)
	print(string.format("%d fps: biggest part turn in one frame (deg) and its pop (deg more than the frame before)", fps))
	for _, e in M.EVENTS do
		local r = out[e.what]
		if r then
			print(string.format("  %-30s turn %5.1f (%s %.2fs)  pop %5.1f (%s %.2fs)", e.what, r.turn, r.part, r.at, r.pop, r.popPart, r.popAt))
		end
	end
end

return M
