-- (brief 30, FIGHTS; the user: "make the animations smooth though, like in the references") Springs on joint transforms.
-- Every animated joint (the crews' R15 rigs in Shared/EnemyRig, your arms in Shared/CharMotion) eases toward the pose
-- the fight code asks for through a damped spring on its rotation vector and its offset, stepped with the real frame
-- time (dt), so nothing snaps between poses:
--   * a new state (idle, run, wind-up, strike, hit, fall, heap) cross-fades in about 0.1-0.2 s;
--   * secondary motion falls out of the tuning: the arms are a little under-damped, so a strike's follow-through
--     carries them a touch past the pose and back; the chest (Waist) is slower than the arms, so it lags them; the head
--     (Neck) is the softest, so after a hit it settles with one small nod.
-- Exact at any frame rate: the spring is integrated in fixed sub-steps of at most 1/240 s, whatever dt is.
--   JointSpring.new()                          -> a set of springs (one per joint name)
--   JointSpring.step(set, name, target, dt)     -> the joint's CFrame this frame (target: the pose's CFrame)
--   JointSpring.snap(set)                       the next step lands exactly on its target (a rig just built or popped
--                                               back to its spot)
--   JointSpring.resting(set, eps)               every spring at rest on its last target
--   JointSpring.scalar(set, name, target, dt, w, z) the same for a number (pose parameters of the box-built fallback)
local JointSpring = {}

-- Per joint: natural frequency w (rad/s) and damping ratio z (1 = critically damped, < 1 overshoots once and settles).
-- About 0.1-0.15 s to cover most of a step at w 24-30; legs stiff and critically damped so feet never skate.
JointSpring.Tune = {
	default = { 26, 1 },
	Waist = { 17, 0.9 }, -- the chest lags the arms
	Neck = { 15, 0.6 }, -- the head settles after a hit
	RightShoulder = { 25, 0.62 }, LeftShoulder = { 25, 0.62 }, -- follow-through past a strike
	RightElbow = { 27, 0.7 }, LeftElbow = { 27, 0.7 },
	RightWrist = { 27, 0.75 }, LeftWrist = { 27, 0.75 },
	RightHip = { 32, 1 }, LeftHip = { 32, 1 }, RightKnee = { 32, 1 }, LeftKnee = { 32, 1 }, RightAnkle = { 32, 1 }, LeftAnkle = { 32, 1 },
	Root = { 20, 0.85 }, -- the body's own lean, turn and lunge
}
JointSpring.MaxStep = 1 / 240

function JointSpring.new()
	return { joints = {}, snap = true }
end
function JointSpring.snap(set)
	set.snap = true
end

local function toVec(cf)
	local axis, angle = cf:ToAxisAngle()
	return axis * angle
end
local function fromVec(r, p)
	local a = r.Magnitude
	local rot = a > 1e-6 and CFrame.fromAxisAngle(r / a, a) or CFrame.identity
	return CFrame.new(p) * rot
end

-- One spring (x, v toward target t) over dt, in sub-steps (semi-implicit Euler: stable for any dt).
local function integrate(x, v, t, dt, w, z)
	local n = math.max(1, math.ceil(dt / JointSpring.MaxStep))
	local h = dt / n
	local k, c = w * w, 2 * z * w
	for _ = 1, n do
		v += ((t - x) * k - v * c) * h
		x += v * h
	end
	return x, v
end

function JointSpring.step(set, name, target, dt)
	local j = set.joints[name]
	local tr, tp = toVec(target), target.Position
	if not j or set.snap or not dt or dt <= 0 then
		-- (no time has passed, or nothing to blend from: exactly the pose)
		if not j then
			j = {}
			set.joints[name] = j
		end
		j.r, j.p, j.vr, j.vp, j.tr, j.tp = tr, tp, Vector3.zero, Vector3.zero, tr, tp
		return target
	end
	-- (a rotation vector and its negative-equivalent across pi: keep the target on the near side of the current one)
	local a = tr.Magnitude
	if a > 2.6 and (tr - j.r).Magnitude > math.pi then
		local alt = tr.Unit * (a - 2 * math.pi)
		if (alt - j.r).Magnitude < (tr - j.r).Magnitude then tr = alt end
	end
	local tune = JointSpring.Tune[name] or JointSpring.Tune.default
	dt = math.min(dt, 0.1)
	j.r, j.vr = integrate(j.r, j.vr, tr, dt, tune[1], tune[2])
	j.p, j.vp = integrate(j.p, j.vp, tp, dt, tune[1], tune[2])
	j.tr, j.tp = tr, tp
	return fromVec(j.r, j.p)
end

-- After a frame's steps: the next frame blends again (a snap lasts one frame).
function JointSpring.done(set)
	set.snap = false
end

function JointSpring.resting(set, eps)
	eps = eps or 1e-3
	for _, j in set.joints do
		if (j.r - j.tr).Magnitude > eps or (j.p - j.tp).Magnitude > eps or j.vr.Magnitude > eps or j.vp.Magnitude > eps then return false end
	end
	return true
end

function JointSpring.scalar(set, name, target, dt, w, z)
	set.scalars = set.scalars or {}
	local s = set.scalars[name]
	if not s or set.snap or not dt or dt <= 0 then
		set.scalars[name] = { x = target, v = 0 }
		return target
	end
	s.x, s.v = integrate(s.x, s.v, target, math.min(dt, 0.1), w or 24, z or 1)
	return s.x
end

return JointSpring
