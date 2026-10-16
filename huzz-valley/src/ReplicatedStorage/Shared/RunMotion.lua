--[[
	The Huss Valley run and the huss dash, matched to the owner's reference video:
	  Run:  low and hunched, leaning hard into it; high knees with the heel folding up behind; the arms
	        swing wide and high (the fist comes up to the head) against the legs; the body rolls from
	        side to side and the shoulders twist against the hips; a bounce on every step.
	  Huss: a quick low dash the way you're moving: forward = a deep lunge with the arms flung back;
	        sideways = a low slide, leaning into it, the outside leg stretched out; back = a hop back,
	        leaning away, arms forward.
	Walking pace keeps Roblox's own walk; the run blends in with speed.

	Pure maths on R15 joints, so the offline preview runs this exact code; HuzzClient/Gameplay/
	RunAnimator feeds it every character. Written to Motor6D.Transform after Roblox's animations; the
	carry, the stab and the knockdown are layered after it. An uploaded run in Config/Animations.Run
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
		-- A low slide sideways: lean and roll into it, the outside leg stretched out, arms out to balance.
		local lead = if side > 0 then J.rHip else J.lHip
		local trail = if side > 0 then J.lHip else J.rHip
		poses[J.root] = CFrame.new(0, -D.Crouch, 0) * CarryMath.inJoint(J.root, angles(-12, 0, -side * D.SideRoll))
		poses[J.waist] = CarryMath.inJoint(J.waist, angles(-10, side * 10, side * 12))
		poses[lead] = CarryMath.inJoint(lead, angles(20, 0, side * -D.SideSplay))
		poses[trail] = CarryMath.inJoint(trail, angles(-10, 0, side * D.SideSplay * 0.6))
		poses[J.rKnee] = CarryMath.inJoint(J.rKnee, angles(if side > 0 then -55 else -10))
		poses[J.lKnee] = CarryMath.inJoint(J.lKnee, angles(if side > 0 then -10 else -55))
		poses[J.rShoulder] = CarryMath.inJoint(J.rShoulder, angles(20, 0, -70))
		poses[J.lShoulder] = CarryMath.inJoint(J.lShoulder, angles(20, 0, 70))
		poses[J.rElbow] = CarryMath.inJoint(J.rElbow, angles(30))
		poses[J.lElbow] = CarryMath.inJoint(J.lElbow, angles(30))
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

local function isArm(J, motor)
	return motor == J.rShoulder or motor == J.lShoulder or motor == J.rElbow or motor == J.lElbow
end

--[[
	speed: studs per second along the ground; grounded: false while in the air; carrying: she's overhead,
	so the lean is gentler and the arms are left to the carry. dashAge: seconds since this character's
	huss dash began (nil = none); dashDir: its direction in the body's frame (x right, z forward).
]]
function RunMotion.step(rec, dt, speed, grounded, carrying, dashAge, dashDir)
	local C = Config
	local target = if grounded then clamp((speed - C.From) / (C.Full - C.From), 0, 1) else 0
	local blend = 1 - math.exp(-dt * 10)
	rec.weight += (target - rec.weight) * blend
	rec.arms += ((if carrying then 0 else 1) - rec.arms) * blend
	local dw = if dashAge and dashDir then dashWeight(dashAge) else 0
	if rec.weight < 0.01 and dw < 0.01 then
		if next(rec.written) then
			RunMotion.release(rec)
		end
		return
	end
	rec.phase = (rec.phase + dt * speed / C.Stride * 2 * pi) % (2 * pi)
	local J = rec.joints
	local run = runPose(J, rec.phase, carrying)
	local dash = if dw > 0.01 then dashPose(J, dashDir, carrying) else nil
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
