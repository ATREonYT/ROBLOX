--[[
	A caught player falling flat on their face and lying there until the
	round ends. Pure maths, like CarryMotion: HuzzClient/Gameplay/Knockdown
	feeds it real parts (the server anchors the root part and sets the
	character's DownedAt / DownedFeet / DownedHeight attributes), and the
	offline preview runs it as is.

	The body pivots forward over the feet like a falling plank and lands flat
	on the floor (owner, Oct 18: "not have a swinging animations ... you go
	like in and under the map, just make them lay on the floor and look like
	their dead"). Every joint is ours while they lie there, the root, waist,
	hands and feet too, so no animation keeps playing on a downed body (the
	run's hip bob and crouch were what swung it and pushed it into the floor):
	arms out in front, legs straight and a little apart, cheek on the floor.
]]
local Config = require(script.Parent.Config.Round)
local CarryMath = require(script.Parent.CarryMath)
local GirlMotion = require(script.Parent.GirlMotion)

local DownMotion = {}
local rad, clamp, exp, sin = math.rad, math.clamp, math.exp, math.sin

local function fallTime()
	return Config.Knockdown.FallTime
end

-- Root part CFrame t seconds after the catch. feet: CFrame at the feet on the ground
-- (facing the way they were), height: root above the feet when standing.
function DownMotion.rootCFrame(feet, height, t)
	local p = clamp(t / fallTime(), 0, 1)
	local angle = -rad(90) * p * p -- speeds up as it goes, like a real fall
	if t > fallTime() then
		local b = t - fallTime()
		angle += rad(Config.Knockdown.Bounce) * exp(-b * 9) * sin(b * 22) -- lands with a small bounce
	end
	local lift = Config.Knockdown.Lift * p -- torso thickness off the floor
	return feet * CFrame.Angles(angle, 0, 0) * CFrame.new(0, height, 0) + Vector3.new(0, lift, 0)
end

-- motors: the character's Motor6Ds (or AnimationConstraints).
function DownMotion.new(motors)
	local list = {}
	for _, m in motors do
		table.insert(list, CarryMath.joint(m))
	end
	local joints = GirlMotion.joints(list)
	local keyOf = {}
	for key, m in joints do
		keyOf[m] = key
	end
	return { joints = joints, all = list, keyOf = keyOf, written = {}, base = {} }
end

-- The sprawl, in each parent part's space (x right, y up, -z forward).
local function sprawl(key)
	-- (arms and legs turn only in the body's flat plane, which is the floor's plane when they lie face down, so no
	-- hand or knee goes into the floor; the head turns a little and lifts its chin to clear it)
	local arms, legs = rad(Config.Knockdown.ArmsOut), rad(12)
	local P = {
		LShoulder = CFrame.Angles(0, 0, -arms),
		RShoulder = CFrame.Angles(0, 0, arms),
		LHip = CFrame.Angles(0, 0, -legs),
		RHip = CFrame.Angles(0, 0, legs),
		LKnee = CFrame.Angles(-rad(12), 0, 0), -- (heels lift off the floor, not into it)
		RKnee = CFrame.Angles(-rad(18), 0, 0),
		Neck = CFrame.Angles(rad(Config.Knockdown.ChinUp), 0, 0) * CFrame.Angles(0, rad(Config.Knockdown.HeadTurn), 0),
	}
	return P[key]
end

-- Every joint's lying-down Transform: the sprawl where it has one, else straight (root, waist, hands, feet).
local function target(rec, m)
	local pose = sprawl(rec.keyOf[m])
	if not pose then
		return CFrame.identity
	end
	local r = m.C0.Rotation
	return r:Inverse() * pose * r
end
DownMotion.target = target

-- Blends every joint from the playing animation into the lying pose as they fall, then holds it.
function DownMotion.step(rec, t)
	local w = clamp(t / (fallTime() * 0.8), 0, 1)
	for _, m in rec.all do
		local current = m.Transform
		local anim = if rec.written[m] == current then rec.base[m] else current
		rec.base[m] = anim
		m.Transform = anim:Lerp(target(rec, m), w)
		rec.written[m] = m.Transform
	end
end

--[[ Getting up (revived, or the round ended): the server stands the root part straight up at once, so without
	this the body would pop from lying flat to standing in one frame. For RISE seconds the body is tipped back
	down about the feet (Root joint) and the limbs keep the sprawl, both easing out to the animation.
	age: seconds since they got up; height: root above the feet when standing (DownedHeight). ]]
DownMotion.RISE = 0.4
function DownMotion.rise(rec, age, height)
	local w = 1 - clamp(age / DownMotion.RISE, 0, 1)
	w = w * w * (3 - 2 * w)
	local function own(m, target)
		local current = m.Transform
		local anim = if rec.written[m] == current then rec.base[m] else current
		rec.base[m] = anim
		m.Transform = target(anim)
		rec.written[m] = m.Transform
	end
	local root = rec.joints.Root
	for _, m in rec.all do
		if m ~= root or not height then
			local pose = target(rec, m)
			own(m, function(anim) return anim:Lerp(pose, w) end)
		end
	end
	if root and height then
		-- in the root part's space: tipped forward about the feet, lifted by the torso's thickness
		local tip = CFrame.new(0, -height, 0) * CFrame.Angles(-rad(90) * w, 0, 0) * CFrame.new(0, height, 0)
		local pivot = CFrame.new(0, Config.Knockdown.Lift * w, 0) * tip
		own(root, function(anim) return root.C0:Inverse() * pivot * root.C0 * anim:Lerp(CFrame.identity, w) end)
	end
	return w > 0
end

-- Gives the joints back to the animations (when they get up).
function DownMotion.release(rec)
	for m, base in rec.base do
		if m.Parent then
			m.Transform = base
		end
	end
end

return DownMotion
