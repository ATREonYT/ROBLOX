--[[
	One carried girl, frame by frame: the pickup flight, the step bob and
	inertia sway of the carry joint, the carrier's raised arms and lean, and
	her own motion (GirlMotion.carried). Pure maths on joint tables, so the
	offline preview runs this exact code; HuzzClient/Gameplay/CarryAnimator
	feeds it real Roblox parts.

	Everything is a Motor6D.Transform written after Roblox's animations
	(PreSimulation). Legs and hips keep whatever walk/run/huss animation is
	playing; the arms are posed with Carry.Arms.AnimBlend of the animation
	let through; the waist lean is added on top of the animation.
]]
local Carry = require(script.Parent.Config.Carry)
local GirlConfig = require(script.Parent.Config.GirlMotion)
local CarryMath = require(script.Parent.CarryMath)
local GirlMotion = require(script.Parent.GirlMotion)

local CarryMotion = {}
local rad, sin, clamp, exp = math.rad, math.sin, math.clamp, math.exp

local function clampVector(v, limit)
	return Vector3.new(clamp(v.X, -limit, limit), clamp(v.Y, -limit, limit), clamp(v.Z, -limit, limit))
end

local function clampLength(v, limit)
	local m = v.Magnitude
	return if m > limit then v * (limit / m) else v
end

local function springStep(x, v, target, dt)
	local S = Carry.Spring
	local w = 2 * math.pi * S.Frequency
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	for _ = 1, steps do
		v += (w * w * (target - x) - 2 * S.Damping * w * v) * h
		x += v * h
	end
	return x, v
end

-- What the animation wrote this frame (or, if nothing did, what it last wrote).
local function animated(rec, motor)
	local current = motor.Transform
	local anim = if rec.written[motor] == current then rec.base[motor] else current
	rec.base[motor] = anim
	return anim
end

local function remember(rec, motor)
	rec.written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
end

-- Replace an arm joint's pose, letting a little of the animation through.
local function poseJoint(rec, motor, pose, weight)
	if motor then
		local anim = animated(rec, motor)
		local keep = CFrame.identity:Lerp(anim, Carry.Arms.AnimBlend)
		motor.Transform = anim:Lerp(CarryMath.inJoint(motor, pose) * keep, weight)
		remember(rec, motor)
	end
end

-- Add a pose on top of the animation (the waist lean).
local function addJoint(rec, motor, pose)
	if motor then
		motor.Transform = animated(rec, motor) * CarryMath.inJoint(motor, pose)
		remember(rec, motor)
	end
end

--[[ info: motor (the carry Motor6D), rig (CarryMath.rig of the carrier), root (carrier's root part),
	girlMotors (her Motor6Ds), start (time the pickup began), from (world position she flies in from),
	seed, useArmAnimation ]]
function CarryMotion.new(info)
	local rec = {
		motor = info.motor,
		rig = info.rig,
		root = info.root,
		c0rot = info.motor.C0.Rotation,
		start = info.start,
		from = info.from or (info.root.CFrame * CFrame.new(0, -2.2, -2.5)).Position,
		useArmAnimation = info.useArmAnimation,
		joints = GirlMotion.joints(info.girlMotors or {}),
		girl = GirlMotion.new(info.seed or 1),
		phase = 0,
		vel = Vector3.zero, prevVel = Vector3.zero, lag = Vector3.zero, lagVel = Vector3.zero,
		yaw = 0, yawVel = 0, yawRate = 0,
		girlVel = Vector3.zero, girlAccel = Vector3.zero,
		written = {}, base = {},
	}
	return rec
end

-- Gives the carrier's joints back to their animations.
function CarryMotion.release(rec)
	for motor, base in rec.base do
		if motor.Parent then
			motor.Transform = base
		end
	end
end

--[[
	The huss, age seconds after it started (Carry.Huss): a quick dip, then he throws her
	up; she twirls once along her length while he hits his huss move under her (arms out
	to a double flex, chest pumping); his arms go back up in time and he catches her with
	a soft give at the knees of the elbows. Returns nil when no huss is playing, else
	lift (studs up), spin (radians), flex (0..1: arms in the huss pose), give (0..1).
]]
function CarryMotion.huss(age)
	local H = Carry.Huss
	local u = if age then age / H.Time else -1
	if u < 0 or u >= 1 then
		return nil
	end
	local launch, land = 0.1, 0.84
	local lift, spin, give = 0, 0, 0
	if u < launch then
		give = sin(math.pi / 2 * u / launch)
		lift = -0.45 * give
	elseif u < land then
		local f = (u - launch) / (land - launch)
		lift = H.Height * 4 * f * (1 - f) - 0.45 * (1 - f) ^ 4
		spin = 2 * math.pi * (H.Spins or 1) * (f * f * (3 - 2 * f))
	else
		give = sin(math.pi * (u - land) / (1 - land))
		lift = -0.55 * give
	end
	local function ramp(a, b)
		local x = clamp((u - a) / (b - a), 0, 1)
		return x * x * (3 - 2 * x)
	end
	local flex = ramp(0.13, 0.3) * (1 - ramp(0.6, 0.78))
	return lift, spin, flex, give, u
end

-- now: the same clock as rec.start. mood/moodAge: see GirlMotion.carried.
-- hussAge: seconds since his huss started (nil = none). hussAnimated: an uploaded Huss
-- animation plays his move, so the scripted arms step aside while she's in the air.
function CarryMotion.step(rec, dt, now, mood, moodAge, hussAge, hussAnimated)
	local root, motor = rec.root, rec.motor
	local torso = rec.rig.torso
	local rootCF = root.CFrame

	-- Carrier motion, measured from position so other players' characters work too.
	local pos = rootCF.Position
	if rec.prevPos and (pos - rec.prevPos).Magnitude < 15 then
		rec.vel = rec.vel:Lerp((pos - rec.prevPos) / dt, 1 - exp(-dt * 14))
	else
		rec.vel, rec.prevVel = Vector3.zero, Vector3.zero -- spawned or teleported
	end
	rec.prevPos = pos
	local accel = rootCF:VectorToObjectSpace((rec.vel - rec.prevVel) / dt)
	rec.prevVel = rec.vel
	local look = rootCF.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = (yaw - (rec.prevYaw or yaw) + math.pi) % (2 * math.pi) - math.pi
	rec.prevYaw = yaw
	rec.yawRate += (turn / dt - rec.yawRate) * (1 - exp(-dt * 10))

	-- Inertia: she lags behind speed changes and turns, then springs back.
	local S = Carry.Spring
	rec.lag, rec.lagVel = springStep(rec.lag, rec.lagVel, clampVector(-accel * S.Lag, S.MaxLag), dt)
	rec.yaw, rec.yawVel = springStep(rec.yaw, rec.yawVel, clamp(-rec.yawRate * S.TurnLag, -S.MaxTurnLag, S.MaxTurnLag), dt)

	-- Footstep bob and rock.
	local B = Carry.Bob
	local speed = Vector3.new(rec.vel.X, 0, rec.vel.Z).Magnitude
	if math.abs(rec.vel.Y) < 4 then
		rec.phase += speed * dt * B.StepsPerStud
	end
	local amount = clamp(speed / 16, 0, 1.4)
	local step = sin(rec.phase * math.pi)
	local L = rec.lag
	local hold = CFrame.new(L.X, L.Y + (math.abs(step) - 0.5) * B.Height * amount, L.Z)
		* CFrame.Angles(rad(S.Tilt * L.Z), rec.yaw, rad(-S.Tilt * L.X) + rad(B.Roll) * step * amount)

	-- Pickup: she flies in upright from where she was, arcs, and settles into the hold.
	local p = if Carry.PickupTime > 0 then clamp((now - rec.start) / Carry.PickupTime, 0, 1) else 1
	if p < 1 then
		local frame = torso.CFrame * CFrame.new(motor.C0.Position)
		local startCF = CFrame.new(frame:PointToObjectSpace(rec.from)) * rec.c0rot:Inverse()
		local e = 1 - (1 - p) ^ 3
		hold = startCF:Lerp(hold, e) + frame:VectorToObjectSpace(Vector3.yAxis) * Carry.ArcHeight * sin(math.pi * p)
	end
	-- The huss: up she goes (straight up from his hands), twirling, and back down into them.
	local lift, spin, hussFlex, give, hu = CarryMotion.huss(hussAge)
	if lift then
		local up = (torso.CFrame * CFrame.new(motor.C0.Position)):VectorToObjectSpace(Vector3.yAxis)
		hold = (hold + up * lift) * CFrame.Angles(spin, 0, 0)
	end
	motor.Transform = rec.c0rot:Inverse() * hold * rec.c0rot

	-- Carrier: arms up as she arrives, elbows flexing with each step; a lean back under her weight.
	-- During a huss the arms swing out to a double flex while she's in the air, then back up to catch.
	hussFlex, give = hussFlex or 0, give or 0
	if not rec.useArmAnimation then
		local weight = clamp(p * 1.8, 0, 1) * (if hussAnimated then 1 - hussFlex else 1)
		local flex = math.abs(step) * B.ElbowFlex * amount + give * 30
		local pump = if lift then sin(hu * 2 * math.pi * 6.5) else 0
		for _, arm in rec.rig.arms do
			local shoulder, elbow = CarryMath.shoulderPose(arm.sign, 1), CarryMath.elbowPose(arm.sign, Carry.Arms.ElbowBend + flex)
			if hussFlex > 0 then
				local out = CFrame.Angles(0, 0, rad(arm.sign * (86 + 5 * pump))) * CFrame.Angles(rad(180), 0, 0)
				shoulder = shoulder:Lerp(out, hussFlex)
				elbow = elbow:Lerp(CarryMath.elbowPose(arm.sign, 104 + 14 * pump), hussFlex)
			end
			poseJoint(rec, arm.shoulder, shoulder, weight)
			poseJoint(rec, arm.elbow, elbow, weight)
		end
	end
	local G = GirlConfig.Carrier
	local groove = if lift then hussFlex * sin(hu * 2 * math.pi * 3.25) else 0
	addJoint(rec, rec.rig.waist, CFrame.Angles(
		rad(G.Lean * clamp(p * 1.8, 0, 1) + G.StepDip * math.abs(step) * amount + 7 * hussFlex + 5 * groove - 4 * give),
		rad(12 * groove),
		rad(G.StepRoll) * step * amount))

	-- Her own motion, driven by how her body actually moves (flight, bob, sway, turns).
	local girlRoot = motor.Part1
	if girlRoot then
		local gp = girlRoot.CFrame.Position
		if rec.girlPrev and (gp - rec.girlPrev).Magnitude < 15 then
			local v = (gp - rec.girlPrev) / dt
			rec.girlAccel = rec.girlAccel:Lerp(clampLength((v - rec.girlVel) / dt, 250), 1 - exp(-dt * 20))
			rec.girlVel = v
		end
		rec.girlPrev = gp
	end
	GirlMotion.carried(rec.girl, rec.joints, dt, now - rec.start, {
		accel = rec.girlAccel,
		forward = look,
		mood = mood,
		moodAge = moodAge,
	})
end

return CarryMotion
