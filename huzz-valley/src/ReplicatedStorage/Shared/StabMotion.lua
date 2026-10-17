--[[
	The catcher's stab (owner: "get all the animations right in the game"), scripted until a real one is uploaded
	(Config/Animations.Stab). Anime timing, about 0.42 s (Config/Round.Stab.Time):
	  0.00-0.11 s  anticipation: the knife hand coils back by the ribs, shoulders turn away, a little lean back,
	               the free arm comes forward as a guard, eyes stay on the target;
	  0.11-0.17 s  the thrust (two frames at 30 fps): the arm shoots straight out, the body turns into it and leans
	               in, the free arm snaps back to the hip;
	  0.17-0.27 s  the hit: a tiny overshoot settles and holds, so the stab reads;
	  0.27-0.42 s  follow-through: eases back into the run.
	Every segment has its own easing (out into the coil, in for the snap, smooth after), and the move blends in
	within ~35 ms so it starts at once.

	Pure maths on joints (R15), so the offline preview runs this exact code (motion3d/stab_scene.luau);
	HuzzClient/Gameplay/Actions feeds it real characters. Written to Motor6D.Transform after Roblox's animations
	(Gameplay/Frame order 30), so it sits over the run like an Action track and the legs keep running. The knife is
	welded to the right hand (KnifeService), so it stays in hand.
]]
local Round = require(script.Parent.Config.Round)
local CarryMath = require(script.Parent.CarryMath)

local StabMotion = {}
local rad = math.rad

-- Keyframes over the move (0..1 of Round.Stab.Time). Angles in degrees, in each joint's parent part space
-- (x = right, y = up, -z = forward: +x pitch raises an arm forward / leans the waist back, +y turns left).
-- shoulder/elbow/wrist: the knife (right) arm; off/offElbow: the free (left) arm; waist; neck.
-- ease: how the segment arriving at that key moves ("out" = fast then settling, "in" = speeding up, "smooth").
local KEYS = {
	{ at = 0.00, shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, off = { 0, 0, 0 }, offElbow = { 0, 0, 0 }, waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
	-- anticipation: coiled (right shoulder back = turned right, -y)
	{ at = 0.26, ease = "out", shoulder = { -45, 0, 30 }, elbow = { 85, 0, 0 }, wrist = { 0, 0, 0 }, off = { 34, 0, 0 }, offElbow = { 62, 0, 0 }, waist = { 7, -24, 0 }, neck = { -3, 20, 0 } },
	-- thrust: full reach (turned left into it, leaning in)
	{ at = 0.405, ease = "in", shoulder = { 94, 0, -6 }, elbow = { -2, 0, 0 }, wrist = { -30, 0, 0 }, off = { -28, 0, 0 }, offElbow = { 96, 0, 0 }, waist = { -13, 28, 0 }, neck = { 6, -24, 0 } },
	-- the hit: a small settle back from the overshoot, then held
	{ at = 0.48, ease = "out", shoulder = { 88, 0, -6 }, elbow = { 6, 0, 0 }, wrist = { -24, 0, 0 }, off = { -24, 0, 0 }, offElbow = { 92, 0, 0 }, waist = { -10, 23, 0 }, neck = { 5, -20, 0 } },
	{ at = 0.64, ease = "smooth", shoulder = { 84, 0, -5 }, elbow = { 10, 0, 0 }, wrist = { -22, 0, 0 }, off = { -20, 0, 0 }, offElbow = { 88, 0, 0 }, waist = { -9, 20, 0 }, neck = { 4, -18, 0 } },
	-- follow-through: back to the run
	{ at = 1.00, ease = "smooth", shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, off = { 0, 0, 0 }, offElbow = { 0, 0, 0 }, waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
}
StabMotion.KEYS = KEYS

local function smooth(x)
	return x * x * (3 - 2 * x)
end
local EASE = {
	smooth = smooth,
	out = function(x) return 1 - (1 - x) ^ 3 end,
	["in"] = function(x) return x * x end,
}

local function angles(t)
	return CFrame.Angles(rad(t[1]), rad(t[2]), rad(t[3]))
end

-- The pose of one joint at u (0..1).
local function at(u, key)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if u <= b.at then
			local s = (EASE[b.ease] or smooth)(math.clamp((u - a.at) / (b.at - a.at), 0, 1))
			return angles(a[key]):Lerp(angles(b[key]), s)
		end
	end
	return CFrame.identity
end
StabMotion.poseAt = at

-- How much the move owns the joints (the rest is the running animation): in fast, out with the follow-through.
local function weight(u)
	if u < 0.08 then
		return smooth(u / 0.08)
	elseif u < 0.64 then
		return 1
	end
	return 1 - smooth(math.clamp((u - 0.64) / 0.36, 0, 1))
end
StabMotion.weight = weight

-- rig: CarryMath.rig(character); root: the HumanoidRootPart (to keep the thrust level while running hunched).
function StabMotion.new(rig, root)
	local head = rig.head
	local neck = head and CarryMath.joint(head:FindFirstChild("Neck"))
	return { rig = rig, root = root, neck = neck, start = -math.huge, written = {}, base = {} }
end

-- How far the running animation tips the chest forward (radians): the hips' tilt (from the parts) plus the
-- animation's own waist bend this frame. The knife arm is raised by this much, so a hunched sprint still
-- stabs straight ahead instead of at the ground.
local function hunch(rec)
	local waist, root = rec.rig.waist, rec.root
	local pelvis = waist and waist.Part0
	if not (pelvis and root) then
		return 0
	end
	local up = root.CFrame:VectorToObjectSpace(pelvis.CFrame.UpVector)
	local a = math.atan2(-up.Z, up.Y)
	local base = rec.base[waist]
	if base then
		local r = waist.C0.Rotation
		local w = (r * base.Rotation * r:Inverse()):VectorToWorldSpace(Vector3.new(0, 1, 0))
		a += math.atan2(-w.Z, w.Y)
	end
	return math.clamp(a, 0, rad(55))
end

function StabMotion.play(rec, now)
	rec.start = now
end

function StabMotion.progress(rec, now)
	return (now - rec.start) / Round.Stab.Time
end

-- The blade's trail shows while the knife is moving fast (the thrust and the hit).
function StabMotion.trailOn(rec, now)
	local u = StabMotion.progress(rec, now)
	return u >= 0.26 and u <= 0.56
end

local function animated(rec, motor)
	local current = motor.Transform
	local anim = if rec.written[motor] == current then rec.base[motor] else current
	rec.base[motor] = anim
	return anim
end

local function write(rec, motor, transform)
	motor.Transform = transform
	rec.written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
end

-- Returns true while the move is playing. animatedArm = false skips the knife arm (an uploaded Stab
-- animation plays it instead); the body, the free arm and the head always play.
function StabMotion.step(rec, now, animatedArm)
	local u = StabMotion.progress(rec, now)
	if u < 0 or u > 1 then
		if next(rec.written) then
			StabMotion.release(rec)
		end
		return false
	end
	local w = weight(u)
	-- body and head first: added on top of the run (the legs and hips keep running)
	local waist = rec.rig.waist
	if waist then
		write(rec, waist, animated(rec, waist) * CarryMath.inJoint(waist, CFrame.identity:Lerp(at(u, "waist"), w)))
	end
	if rec.neck then
		write(rec, rec.neck, animated(rec, rec.neck) * CarryMath.inJoint(rec.neck, CFrame.identity:Lerp(at(u, "neck"), w)))
	end
	local level = CFrame.Angles(hunch(rec), 0, 0) -- (a hunched run tips the chest: keep the knife arm level)
	local function arm(side, keys)
		for joint, key in keys do
			local motor = side and side[joint]
			if motor then
				local pose = at(u, key)
				if key == "shoulder" then
					pose = level * pose
				end
				write(rec, motor, animated(rec, motor):Lerp(CarryMath.inJoint(motor, pose), w))
			end
		end
	end
	if animatedArm ~= false then
		arm(rec.rig.arms[1], { shoulder = "shoulder", elbow = "elbow", wrist = "wrist" }) -- the right arm holds the knife
	end
	arm(rec.rig.arms[2], { shoulder = "off", elbow = "offElbow" })
	return true
end

-- Hands the joints back to their animations.
function StabMotion.release(rec)
	for motor, base in rec.base do
		if motor.Parent then
			motor.Transform = base
		end
	end
	rec.written, rec.base = {}, {}
end

return StabMotion
