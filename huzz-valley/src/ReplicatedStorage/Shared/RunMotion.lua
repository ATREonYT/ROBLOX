--[[
	The Huss Valley sprint (owner's call: "make a run animation like in Huss Valley"): once a
	character runs fast it leans hard into the run, the legs take long strides with a high knee
	fold, the arms pump bent at the elbow and the shoulders twist against the hips, with a small
	bounce each step. Walking pace keeps Roblox's own walk; the sprint blends in with speed.

	Pure maths on R15 joints, so the offline preview runs this exact code; HuzzClient/Gameplay/
	RunAnimator feeds it every character. Written to Motor6D.Transform after Roblox's animations;
	the carry, the stab and the knockdown are layered after it. An uploaded run in
	Config/Animations.Run replaces it.
]]
local Config = require(script.Parent.Config.Run)
local CarryMath = require(script.Parent.CarryMath)

local RunMotion = {}
local rad, sin, max, clamp, pi = math.rad, math.sin, math.max, math.clamp, math.pi

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
	motor.Transform = anim:Lerp(pose, weight or rec.weight)
	rec.written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
end

local function angles(x, y, z)
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

-- speed: studs per second along the ground; grounded: false while jumping or falling;
-- carrying: she's overhead, so the lean is gentler and the arms are left to the carry.
function RunMotion.step(rec, dt, speed, grounded, carrying)
	local C = Config
	local target = if grounded then clamp((speed - C.From) / (C.Full - C.From), 0, 1) else 0
	local blend = 1 - math.exp(-dt * 10)
	rec.weight += (target - rec.weight) * blend
	-- The arms hand over to the carry smoothly when she's picked up or dropped.
	rec.arms += ((if carrying then 0 else 1) - rec.arms) * blend
	if rec.weight < 0.01 then
		if next(rec.written) then
			RunMotion.release(rec)
		end
		return
	end
	rec.phase = (rec.phase + dt * speed / C.Stride * 2 * pi) % (2 * pi)
	local p = rec.phase
	local s = sin(p)
	local J = rec.joints
	local inJoint = CarryMath.inJoint
	local lean = C.Lean * (if carrying then 0.35 else 1)

	-- Body: lean in, bounce twice a stride, twist the shoulders against the hips.
	local bounce = C.Bounce * (math.abs(math.cos(p)) - 0.5)
	write(rec, J.root, CFrame.new(0, bounce, 0) * inJoint(J.root, angles(-lean, -C.HipTwist * s, C.Roll * s)))
	write(rec, J.waist, inJoint(J.waist, angles(-C.WaistLean, C.Twist * s, 0)))
	write(rec, J.neck, inJoint(J.neck, angles(lean + C.WaistLean - 4, -C.Twist * 0.5 * s, 0)))

	-- Legs: long strides from under the leaning body; the knee folds high as the leg swings through.
	for _, leg in { { J.rHip, J.rKnee, J.rAnkle, 0 }, { J.lHip, J.lKnee, J.lAnkle, pi } } do
		local q = p + leg[4]
		local swing = sin(q)
		local fold = max(0, sin(q - pi - 0.5))
		write(rec, leg[1], inJoint(leg[1], angles(C.Swing * swing + lean * 0.8)))
		write(rec, leg[2], inJoint(leg[2], angles(-(12 + C.KneeFold * fold))))
		write(rec, leg[3], inJoint(leg[3], angles(-18 * max(0, -swing) + 10 * max(0, swing))))
	end

	-- Arms: pumping, bent at the elbow, opposite to the legs (faded out while she's carried).
	local armWeight = rec.weight * rec.arms
	if armWeight > 0.01 then
		for _, arm in { { J.rShoulder, J.rElbow, 0, -1 }, { J.lShoulder, J.lElbow, pi, 1 } } do
			local swing = sin(p + arm[3])
			write(rec, arm[1], inJoint(arm[1], angles(-C.ArmSwing * swing + 12, 0, arm[4] * 8)), armWeight)
			write(rec, arm[2], inJoint(arm[2], angles(C.Elbow + 15 * swing)), armWeight)
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
