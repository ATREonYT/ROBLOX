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

	Knife pass 2 (Oct 19, owner: "make them have good animations ... the killing"): before, the runner stopped dead
	from a full sprint and tipped over like a board. Now the catch lands first (HIT: in 0.1 s the back arches, the
	head snaps back, the arms fly up and out, the knees buckle; at its fullest before the body tips, gone by 0.34 s), and the
	body carries on forward as it falls (Config/Round.Knockdown.Slide studs, fast then settling; the server shortens
	it before a wall: KnockdownService, the character's DownedSlide).
]]
local Config = require(script.Parent.Config.Round)
local CarryMath = require(script.Parent.CarryMath)
local GirlMotion = require(script.Parent.GirlMotion)

local DownMotion = {}
local rad, clamp, exp, sin = math.rad, math.clamp, math.exp, math.sin

local function fallTime()
	return Config.Knockdown.FallTime
end

-- How far the body has slid forward t seconds after the catch, of `slide` studs (fast at first, settling as it lands).
function DownMotion.slideAt(t, slide)
	local p = clamp(t / fallTime(), 0, 1)
	return (slide or 0) * (1 - (1 - p) * (1 - p))
end

-- How much of a screen's own last view of the body still shows t seconds after the catch (Config/Round.Knockdown
-- Blend): 1 at the catch, easing out to 0, so the fall starts where that screen had the body instead of snapping.
function DownMotion.blendAt(t)
	local b = Config.Knockdown.Blend or 0
	if b <= 0 or t >= b then return 0 end
	local x = 1 - clamp(t / b, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Extra slide (studs) for the runner's own screen being ahead of the server's copy: their speed along the way they
-- face, over half their ping (the round trip), at most Config/Round.Knockdown.Lead seconds. Never backwards.
function DownMotion.leadSlide(velocity, look, ping)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then return 0 end
	local along = Vector3.new(velocity.X, 0, velocity.Z):Dot(flat.Unit)
	return math.max(0, along) * clamp((ping or 0) / 2, 0, Config.Knockdown.Lead or 0)
end

-- The longest slide (at most `want`) that keeps a body reaching `reach` past its feet inside the field's walls.
-- The walls are invisible and can't be hit by a ray (CanQuery off), so KnockdownService asks this too (bug hunt,
-- Oct 19: a runner caught beside a side wall slid through it and lay over the floor's edge, then stood up outside).
-- In the field's own frame: x, z where they fall, dx, dz the flat unit way they slide, lo/hi the walls' box corners
-- ({ X, Z }). Outside the box (not on the field) the walls don't apply: `want` comes back.
function DownMotion.fieldSlide(x, z, dx, dz, want, reach, lo, hi)
	if x < lo.X or x > hi.X or z < lo.Z or z > hi.Z then return want end
	local room = math.huge
	if dx > 1e-6 then room = math.min(room, (hi.X - x) / dx) elseif dx < -1e-6 then room = math.min(room, (lo.X - x) / dx) end
	if dz > 1e-6 then room = math.min(room, (hi.Z - z) / dz) elseif dz < -1e-6 then room = math.min(room, (lo.Z - z) / dz) end
	return clamp(room - reach, 0, want)
end

-- Root part CFrame t seconds after the catch. feet: CFrame at the feet on the ground
-- (facing the way they were), height: root above the feet when standing, slide: studs the body carries on
-- forward as it falls (the character's DownedSlide; nil = none).
function DownMotion.rootCFrame(feet, height, t, slide)
	local p = clamp(t / fallTime(), 0, 1)
	local angle = -rad(90) * p * p -- speeds up as it goes, like a real fall
	if t > fallTime() then
		local b = t - fallTime()
		angle += rad(Config.Knockdown.Bounce) * exp(-b * 9) * sin(b * 22) -- lands with a small bounce
	end
	local lift = Config.Knockdown.Lift * p -- torso thickness off the floor
	return feet * CFrame.new(0, 0, -DownMotion.slideAt(t, slide)) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, height, 0) + Vector3.new(0, lift, 0)
end

-- The hit: how much of the flinch shows at t (in by In, held to Hold, gone by Out), and its pose per joint.
DownMotion.HIT = { In = 0.1, Hold = 0.14, Out = 0.34 }
function DownMotion.hitAt(t)
	local H = DownMotion.HIT
	if t < 0 or t >= H.Out then
		return 0
	elseif t < H.In then
		local x = t / H.In
		return x * x * (3 - 2 * x)
	elseif t <= H.Hold then
		return 1
	end
	local x = (t - H.Hold) / (H.Out - H.Hold)
	return 1 - x * x * (3 - 2 * x)
end
local function flinch(key)
	local P = {
		Waist = CFrame.Angles(rad(18), 0, 0), -- the back arches (hit from behind)
		Neck = CFrame.Angles(rad(24), 0, 0), -- the head snaps back
		LShoulder = CFrame.Angles(rad(48), 0, -rad(30)), -- the arms fly up and out
		RShoulder = CFrame.Angles(rad(48), 0, rad(30)),
		LElbow = CFrame.Angles(rad(20), 0, 0),
		RElbow = CFrame.Angles(rad(20), 0, 0),
		LKnee = CFrame.Angles(-rad(22), 0, 0), -- the knees buckle
		RKnee = CFrame.Angles(-rad(30), 0, 0),
	}
	return P[key]
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

-- Blends every joint from the playing animation into the lying pose as they fall, then holds it; the hit's
-- flinch shows over the first 0.3 s.
function DownMotion.step(rec, t)
	local w = clamp(t / (fallTime() * 0.8), 0, 1)
	local f = DownMotion.hitAt(t)
	for _, m in rec.all do
		local current = m.Transform
		local anim = if rec.written[m] == current then rec.base[m] else current
		rec.base[m] = anim
		local pose = anim:Lerp(target(rec, m), w)
		local hit = f > 0 and flinch(rec.keyOf[m])
		if hit then
			local r = m.C0.Rotation
			pose = pose:Lerp(r:Inverse() * hit * r, f)
		end
		m.Transform = pose
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
	-- (only a joint nothing animated since our last write: one an animation already posed this frame keeps that fresh pose;
	-- writing the older `base` over it showed a stale pose for one frame, a pop at the end of the move)
	for m, base in rec.base do
		if m.Parent and m.Transform == rec.written[m] then
			m.Transform = base
		end
	end
end

return DownMotion
