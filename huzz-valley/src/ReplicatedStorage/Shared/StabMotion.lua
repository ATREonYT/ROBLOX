--[[
	The catcher's stab, a placeholder until the real Huss Valley animation is in
	(Config/Animations.Stab). About a third of a second: the knife hand pulls back
	to the hip while the shoulders wind up, then the arm punches straight forward
	with the body twisting into it, holds for a beat, and eases back into the walk.

	Pure maths on joints (R15), so the offline preview runs this exact code;
	HuzzClient/Gameplay/Stab feeds it real characters. Written to Motor6D.Transform
	after Roblox's animations, so the legs keep running.
]]
local Round = require(script.Parent.Config.Round)
local CarryMath = require(script.Parent.CarryMath)

local StabMotion = {}
local rad = math.rad

-- Keyframes over the move (0..1). Angles in degrees, in the joint's parent part space
-- (x = right, y = up, -z = forward). shoulder/elbow/wrist: the knife arm; waist: twist and lean.
local KEYS = {
	{ at = 0.00, shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, waist = { 0, 0, 0 } },
	{ at = 0.30, shoulder = { -32, 0, 12 }, elbow = { 100, 0, 0 }, wrist = { 20, 0, 0 }, waist = { 4, 16, 0 } },
	{ at = 0.52, shoulder = { 86, 0, -4 }, elbow = { 6, 0, 0 }, wrist = { -24, 0, 0 }, waist = { -8, -20, 0 } },
	{ at = 0.66, shoulder = { 84, 0, -4 }, elbow = { 10, 0, 0 }, wrist = { -22, 0, 0 }, waist = { -7, -18, 0 } },
	{ at = 1.00, shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, waist = { 0, 0, 0 } },
}

local function smooth(x)
	return x * x * (3 - 2 * x)
end

local function angles(t)
	return CFrame.Angles(rad(t[1]), rad(t[2]), rad(t[3]))
end

-- The pose of one joint at u (0..1).
local function at(u, key)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if u <= b.at then
			local s = smooth(math.clamp((u - a.at) / (b.at - a.at), 0, 1))
			return angles(a[key]):Lerp(angles(b[key]), s)
		end
	end
	return CFrame.identity
end

-- How much the move owns the arm (the rest is the running animation).
local function weight(u)
	if u < 0.12 then
		return smooth(u / 0.12)
	elseif u < 0.7 then
		return 1
	end
	return 1 - smooth(math.clamp((u - 0.7) / 0.3, 0, 1))
end

function StabMotion.new(rig)
	return { rig = rig, start = -math.huge, written = {}, base = {} }
end

function StabMotion.play(rec, now)
	rec.start = now
end

function StabMotion.progress(rec, now)
	return (now - rec.start) / Round.Stab.Time
end

-- The blade's trail shows while the knife is moving fast.
function StabMotion.trailOn(rec, now)
	local u = StabMotion.progress(rec, now)
	return u >= 0.3 and u <= 0.72
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

-- Returns true while the move is playing. animatedArm = false skips the arm (an uploaded Stab
-- animation plays it instead); the waist twist always plays.
function StabMotion.step(rec, now, animatedArm)
	local u = StabMotion.progress(rec, now)
	if u < 0 or u > 1 then
		if next(rec.written) then
			StabMotion.release(rec)
		end
		return false
	end
	local w = weight(u)
	local arm = rec.rig.arms[1] -- the right arm holds the knife
	if animatedArm ~= false then
		for _, key in { "shoulder", "elbow", "wrist" } do
			local motor = arm[key]
			if motor then
				local anim = animated(rec, motor)
				write(rec, motor, anim:Lerp(CarryMath.inJoint(motor, at(u, key)), w))
			end
		end
	end
	local waist = rec.rig.waist
	if waist then
		write(rec, waist, animated(rec, waist) * CarryMath.inJoint(waist, CFrame.identity:Lerp(at(u, "waist"), w)))
	end
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
