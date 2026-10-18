--[[
	The Huss Valley run and the huss dash, matched to the owner's reference video:
	  Run:  low and hunched, leaning hard into it; high knees with the heel folding up behind; the arms
	        swing wide and high (the fist comes up to the head) against the legs; the body rolls from
	        side to side and the shoulders twist against the hips; a bounce on every step.
	  Huss: Huss Valley's compact sideways throw (docs/previews/feel-huss.jpg): crouched, hips shifted and the
	        body leaning ~28 degrees into the move from the first frame, the outside leg kicked out, the inside
	        one bent under you, fists kept in front; held to 0.30 s, upright by ~0.40 s (Config/Run.Dash). It owns
	        every joint while it plays, over the scripted run or over the owner's pack run (your own character
	        too: Gameplay/RunAnimator), so everyone sees the same huss. (Forward and back poses stay for old saves
	        of DashDir but the huss is sideways only.)
	The scripted run is only a stand-in now: everyone walks and runs with the owner's pack (Gameplay/Locomotion,
	Gameplay/PlayerMoves; owner, Oct 18: "player to player less choppy"), and RunAnimator calls step() with speed 0
	on them, so only the huss and the cast are drawn here. The run shows only until the pack's folder arrives.
	Cast: while a power winds up, both arms reach forward and up and the body leans in (Config/Run.Cast).
	pushSpeed: the huss's (and the lunge's) ground speed `age` seconds in, easing from Speed to EndSpeed.

	Pure maths on R15 joints, so the offline preview runs this exact code; HuzzClient/Gameplay/
	RunAnimator feeds it every character. Written to Motor6D.Transform after Roblox's animations and the hand-played
	pack (Gameplay/Frame order 8, 10 here); the carry, the stab and the knockdown are layered after it. An uploaded run in Config/Animations.Run
	replaces it.
]]
local Config = require(script.Parent.Config.Run)
local CarryMath = require(script.Parent.CarryMath)

local RunMotion = {}
local rad, sin, cos, max, clamp, pi, abs = math.rad, math.sin, math.cos, math.max, math.clamp, math.pi, math.abs

local NAMES = {
	root = { "LowerTorso", "Root" }, waist = { "UpperTorso", "Waist" }, neck = { "Head", "Neck" },
	rHip = { "RightUpperLeg", "RightHip" }, lHip = { "LeftUpperLeg", "LeftHip" },
	rKnee = { "RightLowerLeg", "RightKnee" }, lKnee = { "LeftLowerLeg", "LeftKnee" },
	rAnkle = { "RightFoot", "RightAnkle" }, lAnkle = { "LeftFoot", "LeftAnkle" },
	rShoulder = { "RightUpperArm", "RightShoulder" }, lShoulder = { "LeftUpperArm", "LeftShoulder" },
	rElbow = { "RightLowerArm", "RightElbow" }, lElbow = { "LeftLowerArm", "LeftElbow" },
}

-- The joints of an R15 character, or nil (R6 keeps Roblox's run).
function RunMotion.new(character)
	local joints = {}
	for key, path in NAMES do
		local part = character:FindFirstChild(path[1])
		local joint = part and CarryMath.joint(part:FindFirstChild(path[2]))
		if not joint then
			return nil
		end
		joints[key] = joint
	end
	return { joints = joints, phase = 0, weight = 0, arms = 1, written = {}, base = {} }
end

local function animated(rec, motor)
	local current = motor.Transform
	local anim = if rec.written[motor] == current then rec.base[motor] else current
	rec.base[motor] = anim
	return anim
end

local function write(rec, motor, pose, weight)
	local anim = animated(rec, motor)
	motor.Transform = anim:Lerp(pose, weight)
	rec.written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
end

local function angles(x, y, z)
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function smooth(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- How much the dash owns the body, `age` seconds in (in fast, held, out).
local function dashWeight(age)
	local D = Config.Dash
	if age < 0 or age > D.Length then
		return 0
	end
	return smooth(age / D.In) * (1 - smooth((age - (D.Length - D.Out)) / D.Out))
end

-- The ground speed of a push (Config/Round.Dash or .Lunge: Speed, EndSpeed, Time) `age` seconds in, or nil once it's
-- over: a hard start easing out (quad) to EndSpeed, so the move bursts and then settles instead of a flat push and a cut.
function RunMotion.pushSpeed(cfg, age)
	if age < 0 or age >= cfg.Time then
		return nil
	end
	local u = 1 - age / cfg.Time
	local finish = cfg.EndSpeed or cfg.Speed
	return finish + (cfg.Speed - finish) * u * u
end

-- When a character's huss started (server time), or nil. Your own huss is stamped twice: at once on your screen
-- (Gameplay/Dash also keeps that time in the local-only attribute HuzzMyDashAt), then by the server, which may move
-- it up to ~0.15 s (more on a laggy link). A DashAt within 0.6 s of your own local stamp is that same huss, so the
-- local time wins and the lean, the lines and the lean pause never start over.
RunMotion.SAME_HUSS = 0.6
function RunMotion.dashAt(character)
	local at = character:GetAttribute("DashAt")
	local mine = character:GetAttribute("HuzzMyDashAt")
	if type(at) == "number" and type(mine) == "number" and abs(at - mine) < RunMotion.SAME_HUSS then
		return mine
	end
	return if type(at) == "number" then at else nil
end

-- How far a push carries you (studs), for the checks and the simulation.
function RunMotion.pushDistance(cfg)
	local finish = cfg.EndSpeed or cfg.Speed
	return cfg.Time * (finish + (cfg.Speed - finish) / 3)
end

-- The huss's speed lines (Config/Run.Dash.Lines), `age` seconds in: thin lines riding with the body, trailing
-- behind it along the move (`dir`, world), each from `from` back to `to`, `alpha` opaque at its head (a quarter of
-- that at its tail). They draw out over the first 0.06 s, hold their length like HV's, and fade out at the end; nil
-- once they're over.
-- Gameplay/Feel draws them as Beams; the offline film draws the same.
function RunMotion.hussLines(rootCF, dir, age)
	local L = Config.Dash.Lines
	if age < 0 or age >= L.Time then
		return nil
	end
	local k = smooth(age / 0.06)
	local alpha = 0.9 * clamp((L.Time - age) / (L.Time * 0.4), 0, 1)
	local look = rootCF.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zero
	local out = {}
	for _, l in ipairs(L) do
		local from = rootCF.Position + Vector3.new(0, l[1], 0) + forward * l[2] - dir * L.Gap
		table.insert(out, { from = from, to = from - dir * (L.Length * l[3] * k), alpha = alpha })
	end
	return out
end

-- The run pose at phase p (radians of the stride). Returns joint -> {pose, which weight}.
local function runPose(J, p, carrying)
	local C = Config
	local s, c = sin(p), cos(p)
	local lean = C.Lean * (if carrying then 0.35 else 1)
	local poses = {}
	local bounce = C.Bounce * (abs(c) - 0.5) - C.Crouch
	poses[J.root] = CFrame.new(0, bounce, 0) * CarryMath.inJoint(J.root, angles(-lean, -C.HipTwist * s, C.Roll * s))
	poses[J.waist] = CarryMath.inJoint(J.waist, angles(-C.WaistLean, C.Twist * s, -C.Roll * 0.5 * s))
	poses[J.neck] = CarryMath.inJoint(J.neck, angles(lean + C.WaistLean - 6, -C.Twist * 0.5 * s, 0))
	for _, leg in { { J.rHip, J.rKnee, J.rAnkle, 0, -1 }, { J.lHip, J.lKnee, J.lAnkle, pi, 1 } } do
		local q = p + leg[4]
		local swing = sin(q)
		-- High knees: the thigh comes up a long way in front and only part way behind.
		local thigh = if swing > 0 then C.KneeUp * swing else C.KickBack * swing
		local fold = max(0, sin(q - pi - 0.5))
		poses[leg[1]] = CarryMath.inJoint(leg[1], angles(thigh + lean * 0.8, 0, leg[5] * C.Splay))
		poses[leg[2]] = CarryMath.inJoint(leg[2], angles(-(18 + C.KneeFold * fold + 25 * max(0, swing))))
		poses[leg[3]] = CarryMath.inJoint(leg[3], angles(-20 * max(0, -swing) + 12 * max(0, swing)))
	end
	for _, arm in { { J.rShoulder, J.rElbow, 0, -1 }, { J.lShoulder, J.lElbow, pi, 1 } } do
		local swing = sin(p + arm[3])
		-- Wide and high: the forward arm comes up to the head, the back arm swings out behind.
		local forward = max(0, -swing)
		poses[arm[1]] = CarryMath.inJoint(arm[1], angles(-C.ArmSwing * swing + C.ArmLift * forward, 0, arm[4] * (C.ArmOut + 10 * abs(swing))))
		poses[arm[2]] = CarryMath.inJoint(arm[2], angles(C.Elbow + 25 * forward))
	end
	return poses
end

-- The dash pose. dir: the dash direction in the body's frame (x right, z forward).
local function dashPose(J, dir, carrying)
	local D = Config.Dash
	local poses = {}
	local side = if abs(dir.X) > abs(dir.Z) then (if dir.X > 0 then 1 else -1) else 0
	if side ~= 0 then
		-- Huss Valley's sideways throw (the pose the built DashLeft/DashRight had, tools/anim/extract_anims.luau, with
		-- the lean brought to HV's ~28 degrees): low, hips shifted and tipped into the move, the inside leg bent
		-- under you, the outside one kicked out, fists held in front like the run, the head nearly upright.
		local right = side > 0
		local leadHip, leadKnee, leadAnkle = if right then J.rHip else J.lHip, if right then J.rKnee else J.lKnee, if right then J.rAnkle else J.lAnkle
		local trailHip, trailKnee, trailAnkle = if right then J.lHip else J.rHip, if right then J.lKnee else J.rKnee, if right then J.lAnkle else J.rAnkle
		poses[J.root] = CFrame.new(D.SideShift * side, -D.Crouch, 0) * CarryMath.inJoint(J.root, angles(-12, -5 * side, -D.SideRoll * side))
		poses[J.waist] = CarryMath.inJoint(J.waist, angles(-8, 4 * side, -D.SideWaist * side))
		poses[J.neck] = CarryMath.inJoint(J.neck, angles(12, 0, D.SideHead * side))
		poses[leadHip] = CarryMath.inJoint(leadHip, angles(D.LeadHip or 30, 0, (D.LeadSplay or 30) * side))
		poses[leadKnee] = CarryMath.inJoint(leadKnee, angles(D.LeadKnee or -52))
		poses[leadAnkle] = CarryMath.inJoint(leadAnkle, angles(18, 0, -12 * side))
		poses[trailHip] = CarryMath.inJoint(trailHip, angles(8, 0, -D.SideSplay * side))
		poses[trailKnee] = CarryMath.inJoint(trailKnee, angles(-18))
		poses[trailAnkle] = CarryMath.inJoint(trailAnkle, angles(0, 0, 14 * side))
		local holdR, holdL = angles(48, -18, -14), angles(48, 18, 14)
		local leadArm, trailArm = if right then J.rShoulder else J.lShoulder, if right then J.lShoulder else J.rShoulder
		poses[leadArm] = CarryMath.inJoint(leadArm, if right then holdR else holdL)
		poses[trailArm] = CarryMath.inJoint(trailArm, angles(0, 0, -18 * side) * (if right then holdL else holdR))
		poses[if right then J.rElbow else J.lElbow] = CarryMath.inJoint(if right then J.rElbow else J.lElbow, angles(72))
		poses[if right then J.lElbow else J.rElbow] = CarryMath.inJoint(if right then J.lElbow else J.rElbow, angles(60))
	elseif dir.Z >= 0 then
		-- A deep lunge forward, arms flung back.
		poses[J.root] = CFrame.new(0, -D.Crouch, 0) * CarryMath.inJoint(J.root, angles(-D.LungeLean, 0, 0))
		poses[J.waist] = CarryMath.inJoint(J.waist, angles(-10, 0, 0))
		poses[J.neck] = CarryMath.inJoint(J.neck, angles(D.LungeLean - 5, 0, 0))
		poses[J.rHip] = CarryMath.inJoint(J.rHip, angles(D.LungeLean + 55))
		poses[J.rKnee] = CarryMath.inJoint(J.rKnee, angles(-75))
		poses[J.lHip] = CarryMath.inJoint(J.lHip, angles(D.LungeLean - 50))
		poses[J.lKnee] = CarryMath.inJoint(J.lKnee, angles(-15))
		poses[J.rShoulder] = CarryMath.inJoint(J.rShoulder, angles(-70, 0, -25))
		poses[J.lShoulder] = CarryMath.inJoint(J.lShoulder, angles(-70, 0, 25))
		poses[J.rElbow] = CarryMath.inJoint(J.rElbow, angles(10))
		poses[J.lElbow] = CarryMath.inJoint(J.lElbow, angles(10))
	else
		-- A hop back, leaning away, arms forward.
		poses[J.root] = CFrame.new(0, -D.Crouch * 0.6, 0) * CarryMath.inJoint(J.root, angles(14, 0, 0))
		poses[J.waist] = CarryMath.inJoint(J.waist, angles(8, 0, 0))
		poses[J.rHip] = CarryMath.inJoint(J.rHip, angles(40))
		poses[J.lHip] = CarryMath.inJoint(J.lHip, angles(20))
		poses[J.rKnee] = CarryMath.inJoint(J.rKnee, angles(-55))
		poses[J.lKnee] = CarryMath.inJoint(J.lKnee, angles(-35))
		poses[J.rShoulder] = CarryMath.inJoint(J.rShoulder, angles(55, 0, -10))
		poses[J.lShoulder] = CarryMath.inJoint(J.lShoulder, angles(55, 0, 10))
		poses[J.rElbow] = CarryMath.inJoint(J.rElbow, angles(40))
		poses[J.lElbow] = CarryMath.inJoint(J.lElbow, angles(40))
	end
	if carrying then -- her carrier's arms stay up holding her
		poses[J.rShoulder], poses[J.lShoulder], poses[J.rElbow], poses[J.lElbow] = nil, nil, nil, nil
	end
	return poses
end

-- How much the cast pose owns the body, `age` seconds into a power's wind-up of `length` seconds.
local function castWeight(age, length)
	local K = Config.Cast
	if not K or age < 0 or age > length + K.Out then
		return 0
	end
	return smooth(age / K.In) * (1 - smooth((age - length) / K.Out))
end
RunMotion.castWeight = castWeight

-- The cast pose: both arms forward and up (Config/Run.Cast), a slight bend at the elbows, the body leaning in.
local function castPose(J)
	local K = Config.Cast
	local poses = {}
	poses[J.root] = CarryMath.inJoint(J.root, angles(-K.Lean, 0, 0))
	poses[J.waist] = CarryMath.inJoint(J.waist, angles(-3, 0, 0))
	poses[J.neck] = CarryMath.inJoint(J.neck, angles(K.Lean, 0, 0)) -- (the head stays level, looking ahead)
	local raise = 90 + K.ArmsUp
	poses[J.rShoulder] = CarryMath.inJoint(J.rShoulder, angles(raise, 0, K.ArmsOut))
	poses[J.lShoulder] = CarryMath.inJoint(J.lShoulder, angles(raise, 0, -K.ArmsOut))
	poses[J.rElbow] = CarryMath.inJoint(J.rElbow, angles(14))
	poses[J.lElbow] = CarryMath.inJoint(J.lElbow, angles(14))
	return poses
end

local function isArm(J, motor)
	return motor == J.rShoulder or motor == J.lShoulder or motor == J.rElbow or motor == J.lElbow
end

--[[
	speed: studs per second along the ground; grounded: false while in the air; carrying: she's overhead,
	so the lean is gentler and the arms are left to the carry. dashAge: seconds since this character's
	huss dash began (nil = none); dashDir: its direction in the body's frame (x right, z forward).
	castAge, castLength: seconds since a power's wind-up began and how long it is (nil = none): the cast pose.
]]
function RunMotion.step(rec, dt, speed, grounded, carrying, dashAge, dashDir, castAge, castLength)
	local C = Config
	local target = if grounded then clamp((speed - C.From) / (C.Full - C.From), 0, 1) else 0
	local blend = 1 - math.exp(-dt * 10)
	rec.weight += (target - rec.weight) * blend
	rec.arms += ((if carrying then 0 else 1) - rec.arms) * blend
	local dw = if dashAge and dashDir then dashWeight(dashAge) else 0
	local cw = if castAge and castLength then castWeight(castAge, castLength) else 0
	if rec.weight < 0.01 and dw < 0.01 and cw < 0.01 then
		if next(rec.written) then
			RunMotion.release(rec)
		end
		return
	end
	rec.phase = (rec.phase + dt * speed / C.Stride * 2 * pi) % (2 * pi)
	local J = rec.joints
	local run = runPose(J, rec.phase, carrying)
	local dash = if dw > 0.01 then dashPose(J, dashDir, carrying) else nil
	local cast = if cw > 0.01 then castPose(J) else nil
	for _, motor in J do
		local pose, w = run[motor], rec.weight
		if isArm(J, motor) then
			w *= rec.arms
		end
		local d = dash and dash[motor]
		if d then
			-- The dash on top of the run (or of the plain animation when standing).
			pose = if pose and w > 0.01 then pose:Lerp(d, dw) else d
			w = if w > 0.01 then w + (1 - w) * dw else dw
		end
		local c = cast and cast[motor]
		if c and not (carrying and isArm(J, motor)) then -- (a carrier's arms stay on her)
			-- The cast on top of everything: the arms reach, the body leans in.
			pose = if pose and w > 0.01 then pose:Lerp(c, cw) else c
			w = if w > 0.01 then w + (1 - w) * cw else cw
		end
		if pose and w > 0.01 then
			write(rec, motor, pose, math.min(w, 1))
		end
	end
end

function RunMotion.release(rec)
	for motor, base in rec.base do
		if motor.Parent then
			motor.Transform = base
		end
	end
	rec.written, rec.base = {}, {}
end

return RunMotion
