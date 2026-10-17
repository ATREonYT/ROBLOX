--[[
	How your own walk and run blend (owner: "make it more smooth just like in Huss Valley"). Pure maths, so the
	offline video (tools/preview/motion3d/ramp_scene.luau) runs this exact code; Gameplay/Locomotion feeds it
	your character every frame and turns the answer into AnimationTrack weights and speeds.

	  - Idle, Walk and Run all play at once and cross-fade by your speed, smoothed by a critically damped spring
	    (no pops, ~0.35 s to settle). Their weights always add up to 1.
	  - The feet stay in step through the cross-fade: one shared stride phase drives both loops, at a cadence
	    blended between the walk's and the run's.
	  - Calm playback: each loop is sped up or slowed down with your speed but kept inside Config/Run.Loco's
	    rates (the run never goes past ~1.1x, so at full speed the feet slide a little, as in Huss Valley).
	  - Jump, Fall and Climb fade in over the ground loops when the Humanoid leaves the ground or climbs.
	  - lean(): a small procedural touch on top: rolling into turns and pitching forward as you speed up
	    (back a little as you stop), both critically damped.
]]
local Run = require(script.Parent.Config.Run)

local LocomotionMix = {}
local clamp, exp, rad, pi = math.clamp, math.exp, math.rad, math.pi

LocomotionMix.TRACKS = { "Idle", "Walk", "Run", "Jump", "Fall", "Climb" }

local function smooth(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Exact critically damped spring step: (x, v) toward target at angular rate w.
local function spring(x, v, target, w, dt)
	local d = x - target
	local k = (v + w * d) * dt
	local e = exp(-w * dt)
	return target + (d + k) * e, (v - w * k) * e
end
LocomotionMix.spring = spring

local function approach(x, target, tau, dt)
	return x + (target - x) * (1 - exp(-dt / math.max(tau, 1e-3)))
end

function LocomotionMix.new(config)
	return {
		C = config or Run.Loco,
		speed = 0, accel = 0, -- smoothed ground speed and its rate of change
		phase = 0, -- shared stride phase (0-1)
		air = 0, jump = 0, climb = 0, -- fades
		jumpAge = math.huge,
		weights = { Idle = 1, Walk = 0, Run = 0, Jump = 0, Fall = 0, Climb = 0 },
		speeds = { Idle = 1, Walk = 1, Run = 1, Jump = 1, Fall = 1, Climb = 1 },
		times = { Walk = 0, Run = 0 }, -- where the walk and run loops should be (seconds), from the shared phase
		roll = 0, rollV = 0, pitch = 0, pitchV = 0, yaw = nil,
	}
end

--[[ One frame. input:
	speed       ground speed (studs/s, horizontal)
	state       "ground" | "jump" (just jumped) | "fall" | "climb"
	climbSpeed  (climbing) studs/s up or down
	lengths     { Walk = s, Run = s } the loops' lengths in seconds
	jumped      true on the frame you jump (restarts the jump pose)
	Fills s.weights, s.speeds and s.times. ]]
function LocomotionMix.step(s, dt, input)
	local C = s.C
	s.speed, s.accel = spring(s.speed, s.accel, input.speed, C.SpeedResponse, dt)
	local v = math.max(s.speed, 0)

	-- ground: idle -> walk -> run
	local moving = smooth((v - C.MoveFrom) / (C.MoveFull - C.MoveFrom))
	local run = smooth((v - C.RunFrom) / (C.RunFull - C.RunFrom))
	local walkRate = clamp(v / C.WalkAt, C.WalkRate[1], C.WalkRate[2])
	local runRate = clamp(v / C.RunAt, C.RunRate[1], C.RunRate[2])
	local walkLen = (input.lengths and input.lengths.Walk) or 1
	local runLen = (input.lengths and input.lengths.Run) or 0.5
	local cadence = (walkRate / walkLen) * (1 - run) + (runRate / runLen) * run -- strides a second
	s.phase = (s.phase + cadence * dt) % 1
	s.speeds.Walk, s.speeds.Run = cadence * walkLen, cadence * runLen
	s.times.Walk = ((s.phase + C.WalkPhase) % 1) * walkLen
	s.times.Run = ((s.phase + C.RunPhase) % 1) * runLen

	-- air and ladders
	if input.jumped then
		s.jumpAge = 0
	else
		s.jumpAge += dt
	end
	local state = input.state or "ground"
	local inAir = state == "jump" or state == "fall"
	s.air = approach(s.air, if inAir then 1 else 0, if inAir then C.AirIn else C.AirOut, dt)
	s.climb = approach(s.climb, if state == "climb" then 1 else 0, if state == "climb" then C.AirIn else C.AirOut, dt)
	local jumping = s.jumpAge < C.JumpHold
	s.jump = approach(s.jump, if jumping then 1 else 0, if jumping then 0.04 else 0.15, dt)
	s.speeds.Climb = clamp((input.climbSpeed or 0) / C.ClimbAt, -1.5, 1.5)

	local ground = math.max(0, 1 - s.air - s.climb)
	local w = s.weights
	w.Idle = ground * (1 - moving)
	w.Walk = ground * moving * (1 - run)
	w.Run = ground * moving * run
	w.Jump = s.air * s.jump
	w.Fall = s.air * (1 - s.jump)
	w.Climb = math.min(s.climb, 1 - math.min(1, s.air))
	return s
end

--[[ The lean on top, in radians: (roll, pitch). Roll leans into a turn (positive = left, the way Roblox's
	angles turn), pitch leans forward when speeding up (negative = forward, as CFrame.Angles turns about x).
	yaw: the way you face (radians), quiet: 0-1 (1 = hold still: dancing, dashing, knocked down). ]]
function LocomotionMix.lean(s, dt, yaw, quiet)
	local C = s.C
	local turn = 0
	if s.yaw then
		turn = ((yaw - s.yaw + pi) % (2 * pi) - pi) / math.max(dt, 1e-3)
	end
	s.yaw = yaw
	local runningness = smooth((s.speed - C.MoveFrom) / (C.RunFull - C.MoveFrom))
	local live = 1 - clamp(quiet or 0, 0, 1)
	local rollTarget = clamp(rad(C.TurnLean) * turn, -rad(C.MaxRoll), rad(C.MaxRoll)) * runningness * live
	local pitchTarget = -clamp(rad(C.AccelLean) * s.accel, -rad(C.MaxPitchBack), rad(C.MaxPitch)) * live
		* smooth(s.speed / C.MoveFull)
	s.roll, s.rollV = spring(s.roll, s.rollV, rollTarget, C.LeanResponse, dt)
	s.pitch, s.pitchV = spring(s.pitch, s.pitchV, pitchTarget, C.LeanResponse, dt)
	return s.roll, s.pitch
end

-- The lean as a turn about a point on the ground under the hips (so the feet stay put), in the hips' parent
-- space; Gameplay/Locomotion puts it into the Root joint's own frame. footDrop: studs from the joint to the ground.
function LocomotionMix.leanCFrame(roll, pitch, footDrop)
	local f = CFrame.new(0, -footDrop, 0)
	return f * CFrame.Angles(pitch, 0, roll) * f:Inverse()
end

return LocomotionMix
