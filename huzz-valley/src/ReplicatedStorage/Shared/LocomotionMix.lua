--[[
	How the walk and run blend, for your own character and everyone else's (owner: "make it more smooth just like in
	Huss Valley"; Oct 18: "player to player less choppy" and "make the walking animations way way better"). Pure
	maths, so the offline video (tools/preview/motion3d/remote_walk_scene.luau, ramp_scene.luau) and the spec
	(tests/Locomotion.spec.luau) run this exact code. Gameplay/Locomotion feeds it your character (AnimationTrack
	weights and speeds); Gameplay/PlayerMoves feeds it every other R15 character (the pack sampled by hand).

	  - Idle, Walk and Run all play at once and cross-fade by speed, smoothed by a critically damped spring
	    (no pops, ~0.35 s to settle). Their weights always add up to 1.
	  - The feet stay in step through the cross-fade: one shared stride phase drives both loops, at a cadence
	    blended between the walk's and the run's. The phase only ever moves forward by cadence x dt, so a jumpy
	    speed can never make the feet pop.
	  - Planted feet (Oct 18): WalkAt / RunAt in Config/Run.Loco are the speeds at which the pack's own loops keep
	    the foot on the ground still (measured: tools/preview/motion3d/pack_measure.luau), and the walk hands over
	    to the run between 6 and 11 studs/s, where both loops step at the same rate. Before, the walk was asked to
	    cover 16 studs/s at 1.3x (the planted foot slid along at half the ground speed). The run's rate is capped at HV's ~4.6
	    steps a second, so past ~16 studs/s the feet slide a little, as in Huss Valley.
	  - sized(): the same numbers for a bigger or smaller avatar (longer legs take longer steps).
	  - tracker()/track(): another player's speed from where their body is over time (a short window, holding
	    through network stalls, ignoring teleports), never from their replicated velocity, which jumps.
	  - pose(): the blended pose of the sampled loops (Gameplay/PlayerMoves).
	  - Jump, Fall and Climb fade in over the ground loops when the Humanoid leaves the ground or climbs.
	  - lean(): a small procedural touch on top: rolling into turns and pitching forward as you speed up
	    (back a little as you stop), both critically damped.
	  - strafe() / strafePose(): shift lock (owner, Oct 19: "make it so when you shift lock the only thing that moves
	    when you press w a s d (etc) is their body not their head"). Shift lock holds the body to the camera, so A/D
	    used to slide you sideways with the run playing straight ahead (and S moonwalked). Now the hips and legs turn
	    toward the way you move (up to Config/Run.Loco.Strafe MaxTurn), the chest turns part way and the head turns
	    back, so it keeps looking where you aim; moving backwards turns them toward the mirrored side and plays the
	    loop backwards (a back-pedal). Springy, so starting, stopping and switching keys never snaps.
	  - look(): without shift lock (Roblox turns the body to the move) the head keeps looking where the camera points,
	    within a neck's reach (owner, Oct 19: "when he presses D, the body turns right, but the head and camera stays
	    the same"); strafePose() takes that turn too, the chest following part way.
	  - Setting off and stopping, measured on Huss Valley's recording (tools/preview/motion3d/ground_flow.py and 30 fps
	    sheets; owner, Oct 19: "add animations for when you stop running, its a quick but nice looking stopping
	    animation ... and then the slow walking into the running animation"):
	      - from a standstill the legs walk first and hand over to the run by Config/Run.Loco.SetOff (HV: short quick
	        steps for ~0.15 s, the full stride by ~0.35 s), whatever the speed;
	      - slowing down follows the speed much faster than speeding up (StopResponse: HV's legs are at the idle
	        ~0.15 s after the ground stops; ours ran on in place for ~0.3 s, the feet sliding), and a stop from a run
	        plays a quick plant on top (stopAmount(): the body tips back a little and the arms swing out, gone in
	        ~0.3 s; HV's 40.7 s frames), cancelled if you set off again;
	      - the halt (owner, Oct 20 07:55: "they move a little forward as a sort of "hault""; input.halt, Shared/Halt):
	        the plant starts at once while the ground still slides, the steps slow to a stop and the legs come together
	        (Config/Run.Loco.Stop.Halt), so the feet skid instead of running on.
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
		turn = 0, turnV = 0, back = false, -- shift lock: the body's turn toward the move (radians) and back-pedalling
		look = 0, lookV = 0, -- the head's turn toward where the camera looks (radians, + = right)
		lookUp = 0, lookUpV = 0, -- and its tilt (radians, + = up)
		goAge = 0, -- seconds since setting off from a standstill (the walk shows first)
		stopAge = math.huge, stopK = 0, armed = false, -- the stop's plant: how long ago, how strong; armed = running
	}
end

--[[ One frame. input:
	speed       ground speed (studs/s, horizontal)
	state       "ground" | "jump" (just jumped) | "fall" | "climb"
	climbSpeed  (climbing) studs/s up or down
	lengths     { Walk = s, Run = s } the loops' lengths in seconds
	jumped      true on the frame you jump (restarts the jump pose)
	stride      (optional, default 1) scales the stride rate: in the air the legs slow down instead of running on
	halt        (optional) true while the body halts (Shared/Halt; owner, Oct 20 07:55: "they move a little forward as
	            a sort of "hault""): the stop's plant starts at once and the legs go to the idle while the ground
	            still slides, so the feet skid instead of running on
	Fills s.weights, s.speeds and s.times. ]]
function LocomotionMix.step(s, dt, input)
	local C = s.C
	local before = s.speed
	-- (slowing down follows quicker than speeding up: a stop is a stop, the legs don't run on in place)
	local response = if input.speed < s.speed then (C.StopResponse or C.SpeedResponse) else C.SpeedResponse
	s.speed, s.accel = spring(s.speed, s.accel, input.speed, response, dt)
	local v = math.max(s.speed, 0)

	-- the stop's plant: armed while running, set off when the ground speed drops to a stand (Config/Run.Loco.Stop)
	local St = C.Stop
	local halting = input.halt == true
	s.stopAge += dt
	if St then
		if input.speed > C.RunFull and before > C.RunFull and not halting then
			s.armed = true -- (running: the next stand-still is a stop)
		end
		if s.armed and (input.speed < C.MoveFrom or halting) then
			s.armed = false
			s.stopAge = 0
			s.stopK = smooth((before - C.RunFrom) / (C.RunAt - C.RunFrom))
		elseif input.speed > C.MoveFull and not halting and s.stopAge < St.In + St.Out then
			s.stopK = approach(s.stopK, 0, 0.04, dt) -- (off again at once: the plant gets out of the way)
		end
	end

	-- ground: idle -> walk -> run (each eased over WeightTime, so a quick stop is quick but never a one-frame pop)
	local moving = smooth((v - C.MoveFrom) / (C.MoveFull - C.MoveFrom))
	local run = smooth((v - C.RunFrom) / (C.RunFull - C.RunFrom))
	-- setting off from a standstill: the walk first, the run after SetOff (HV's short first steps)
	if v < C.MoveFrom then
		s.goAge = 0
	else
		s.goAge += dt
	end
	if C.SetOff then
		run = math.min(run, smooth((s.goAge - C.SetOff.Walk) / C.SetOff.Blend))
	end
	-- a stop from a run goes straight from the run to the idle over Stop.Blend (HV: no walk in between)
	local stopping = St ~= nil and s.stopK > 0 and s.stopAge < St.In + St.Out and (input.speed < C.MoveFrom or halting)
	if stopping then
		moving, run = 0, s.running or run
	end
	if C.WeightTime then
		local tau = if stopping then (if halting and St.Halt then St.Halt.Blend else St.Blend) else C.WeightTime
		s.moving = approach(s.moving or moving, moving, tau, dt)
		s.running = approach(s.running or run, run, tau, dt)
		moving, run = s.moving, s.running
	end
	local walkRate = clamp(v / C.WalkAt, C.WalkRate[1], C.WalkRate[2])
	local runRate = clamp(v / C.RunAt, C.RunRate[1], C.RunRate[2])
	local walkLen = (input.lengths and input.lengths.Walk) or 1
	local runLen = (input.lengths and input.lengths.Run) or 0.5
	local cadence = ((walkRate / walkLen) * (1 - run) + (runRate / runLen) * run) * (input.stride or 1) -- strides a second
	if stopping and halting and St.Halt then
		-- (the halt: the steps slow to a stop over Halt.Settle and the legs come together over Halt.Blend while the
		-- ground still slides, so the feet skid instead of running on; a sudden freeze reversed a swinging arm in one frame)
		cadence *= math.max(0, 1 - s.stopAge / St.Halt.Settle)
	end
	-- (back-pedalling in shift lock: the loops play backwards, LocomotionMix.strafe)
	s.phase = (s.phase + cadence * dt * (if s.back then -1 else 1)) % 1
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
	-- (+ the stop's plant: the body tips back a little as the legs come together)
	local plant = if C.Stop then rad(C.Stop.Lean) * LocomotionMix.stopAmount(s) * live else 0
	return s.roll, s.pitch + plant
end

-- The stop's plant right now, 0 to 1 (Config/Run.Loco.Stop: up in In seconds, gone Out seconds later).
function LocomotionMix.stopAmount(s): number
	local St = s.C.Stop
	if not St or s.stopAge >= St.In + St.Out or s.stopK <= 0 then
		return 0
	end
	local t = s.stopAge
	return s.stopK * smooth(t / St.In) * (1 - smooth((t - St.In) / St.Out))
end

-- The stop's arms: a turn for a shoulder's Transform (put in front of it: R * T), side = 1 right, -1 left. The arm
-- swings out to the side and a little forward (HV: arms out as the feet plant).
function LocomotionMix.stopArm(s, amount: number, side: number): CFrame
	local St = s.C.Stop
	if not St or amount <= 1e-4 then
		return CFrame.identity
	end
	return CFrame.Angles(rad(St.ArmsForward) * amount, 0, side * rad(St.ArmsOut) * amount)
end

-- The lean as a turn about a point on the ground under the hips (so the feet stay put), in the hips' parent
-- space; Gameplay/Locomotion puts it into the Root joint's own frame. footDrop: studs from the joint to the ground.
function LocomotionMix.leanCFrame(roll, pitch, footDrop)
	local f = CFrame.new(0, -footDrop, 0)
	return f * CFrame.Angles(pitch, 0, roll) * f:Inverse()
end

local STRAFE = { MaxTurn = 90, BackFrom = 110, Response = 12, Chest = 0.4, MinSpeed = 2 }
local LOOK = { Max = 70, BackFrom = 110, Fade = 30, Response = 10, Up = 30, Down = 35, RemoteResponse = 8 }

--[[ Shift lock's body turn, one frame. localVel: the body's ground velocity in its own space (x right, z back, as
	CFrame:VectorToObjectSpace gives it); on: shift lock holds the body to the camera (otherwise Roblox turns the body
	to the move and there is nothing to do); quiet (0..1): a huss, a leap, a dance or lying down fades it out.
	Returns the hips' turn (radians, + = to the right) and whether the loops play backwards. Config/Run.Loco.Strafe:
	MaxTurn (degrees) the most the hips turn; BackFrom (degrees off straight ahead) where moving turns into a
	back-pedal; Response the spring's speed; MinSpeed (studs/s) below it the body faces ahead. ]]
function LocomotionMix.strafe(s, dt, localVel: Vector3, on: boolean, quiet: number?): (number, boolean)
	local C = s.C.Strafe or STRAFE
	local flat = Vector3.new(localVel.X, 0, localVel.Z)
	local speed = flat.Magnitude
	local target = 0
	local live = 1 - clamp(quiet or 0, 0, 1)
	if on and live > 0 and speed > C.MinSpeed then
		local a = math.atan2(flat.X, -flat.Z) -- (0 straight ahead, + to the right, +-pi straight back)
		-- (a little stickiness either side of BackFrom, so a stick held near it doesn't flip every frame)
		local backFrom = rad(C.BackFrom + (if s.back then -8 else 8))
		s.back = math.abs(a) > backFrom
		if s.back then
			a -= pi * (if a > 0 then 1 else -1) -- (back and to the right = hips to the front left, legs pedalling back)
		end
		target = clamp(a, -rad(C.MaxTurn), rad(C.MaxTurn)) * smooth((speed - C.MinSpeed) / C.MinSpeed) * live
	elseif s.speed < C.MinSpeed * 2 then
		s.back = false -- (only once the legs have nearly stopped: flipping a fast loop round would jolt the legs)
	end
	s.turn, s.turnV = spring(s.turn, s.turnV, target, C.Response, dt)
	return s.turn, s.back
end

--[[ The head's turn toward where the camera looks, one frame (no shift lock: Roblox has turned the body to the move,
	so pressing D turns the body right while the head keeps looking ahead with the camera). aim: the camera's look,
	relative to the body (radians, + = to the body's right, as strafe()); on: false fades the turn out (shift lock: the
	strafe keeps the head ahead); quiet as strafe(). Up to Config/Run.Loco.Look Max degrees (a neck's reach); when the
	camera looks back past BackFrom (looking at yourself) the head comes round to the front over Fade degrees instead
	of flipping. up (Oct 19 19:48, the head follows the mouse): how far above the body's level the aim is (radians,
	+ = up), Look.Up / Down degrees at most, shift lock or not. remote: another player's head from the turn their
	screen sent (Gameplay/HeadAim), springing with the softer RemoteResponse. Returns the head's (turn, tilt). ]]
function LocomotionMix.look(s, dt, aim: number, on: boolean, quiet: number?, up: number?, remote: boolean?): (number, number)
	local C = s.C.Look or LOOK
	local live = 1 - clamp(quiet or 0, 0, 1)
	local target, tilt = 0, 0
	if live > 0 then
		local fade = 1 - smooth((math.deg(math.abs(aim)) - C.BackFrom) / C.Fade)
		if on then
			target = clamp(aim, -rad(C.Max), rad(C.Max)) * fade * live
		end
		tilt = clamp(up or 0, -rad(C.Down or 35), rad(C.Up or 30)) * fade * live
	end
	local k = if remote then (C.RemoteResponse or C.Response) else C.Response
	s.look, s.lookV = spring(s.look, s.lookV, target, k, dt)
	s.lookUp, s.lookUpV = spring(s.lookUp or 0, s.lookUpV or 0, tilt, k, dt)
	return s.look, s.lookUp
end

--[[ The strafe and the look on the body's three top joints, worked out exactly from this frame's poses so the head
	ends up facing just where the animation had it, turned only by `look` (a plain counter-turn at the neck tipped the
	head sideways while the run hunches the body forward). J: { root, waist, neck } = each joint's { C0, C1, T }
	(T = its Transform this frame). Returns the new Transforms: the hips turned `turn` about the root part's up, the
	head turned `look` and tilted `up` (default 0: facing where the body part faces), the chest Chest of the way from the head's turn
	to the hips'. Gameplay/Locomotion and Gameplay/PlayerMoves write them. ]]
function LocomotionMix.strafePose(s, turn: number, J, look: number?, up: number?): (CFrame, CFrame, CFrame)
	local C = s.C.Strafe or STRAFE
	local chest = clamp(C.Chest, 0, 1)
	local headTurn = look or 0
	local r, w, n = J.root, J.waist, J.neck
	local function rot(cf: CFrame): CFrame
		return cf.Rotation
	end
	-- (each part's turn in the root part's space, rotations only)
	local lower0 = rot(r.C0) * rot(r.T) * rot(r.C1):Inverse()
	local upper0 = lower0 * rot(w.C0) * rot(w.T) * rot(w.C1):Inverse()
	local head0 = upper0 * rot(n.C0) * rot(n.T) * rot(n.C1):Inverse()
	local hips = CFrame.Angles(0, -turn, 0)
	local rootT = r.C0:Inverse() * hips * r.C0 * r.T
	local lower1 = hips * lower0
	local upper1 = CFrame.Angles(0, -(headTurn + (turn - headTurn) * chest), 0) * upper0
	-- (the tilt about the body's level right, then the turn: the head looks `up` above level, `look` to the side)
	local head1 = CFrame.Angles(0, -headTurn, 0) * CFrame.Angles(up or 0, 0, 0) * head0
	local waistR = rot(w.C0):Inverse() * lower1:Inverse() * upper1 * rot(w.C1)
	local neckR = rot(n.C0):Inverse() * upper1:Inverse() * head1 * rot(n.C1)
	return rootT, CFrame.new(w.T.Position) * waistR, CFrame.new(n.T.Position) * neckR
end

-- A copy of a Loco config for an avatar `k` times the standard size (legs k times as long: every speed scales).
local SPEEDS = { "MoveFrom", "MoveFull", "RunFrom", "RunFull", "WalkAt", "RunAt" }
function LocomotionMix.sized(config, k: number)
	local c = table.clone(config)
	for _, key in SPEEDS do
		c[key] = config[key] * k
	end
	return c
end

-- How fast the planted foot moves back under the body (studs/s) as the loops play now (0 standing). With the body
-- moving at the ground speed, the feet slide by the difference. (The walk at 1x moves its foot at C.WalkAt, the run
-- at C.RunAt.)
function LocomotionMix.footSpeed(s): number
	local w = s.weights
	local total = w.Walk + w.Run
	if total < 1e-3 then
		return 0
	end
	return (w.Walk * s.speeds.Walk * s.C.WalkAt + w.Run * s.speeds.Run * s.C.RunAt) / total
end

-- Steps a second as the loops play now (a stride is two steps). lengths: { Walk = s, Run = s }.
function LocomotionMix.stepsPerSecond(s, lengths): number
	local w = s.weights
	local total = w.Walk + w.Run
	if total < 1e-3 then
		return 0
	end
	return 2 * (w.Walk * s.speeds.Walk / lengths.Walk + w.Run * s.speeds.Run / lengths.Run) / total
end

--[[ Another player's ground speed from where their body is, frame by frame (Config/Run.Track):
	  - the distance covered over the last Window seconds, so a frame where the network didn't move them and the
	    next where they jump twice as far average out;
	  - a body that hasn't moved at all is a network stall for up to Hold seconds (the last speed is kept), then a
	    real stop;
	  - a jump faster than Teleport studs/s (respawn, the round moving everyone) starts the window over.
	track(tr, now, pos) returns (ground speed, up speed), studs/s. Feed the ground speed to step(): its spring
	smooths what's left. tr.vel is the ground velocity over the same window (which way they go, for strafe()).
	still (optional): their replicated ground speed. Too jumpy to read a speed from, but a body that hasn't moved AND
	says it isn't moving has stopped, now (a network stall keeps its last velocity): their legs stop with them. ]]
function LocomotionMix.tracker(config)
	return { C = config or Run.Track, list = {}, speed = 0, up = 0, last = nil, vel = Vector3.zero }
end

function LocomotionMix.track(tr, now: number, pos: Vector3, still: number?): (number, number)
	local C, list = tr.C, tr.list
	local last = tr.last
	if last then
		local dt = now - last.t
		if dt <= 0 then
			return tr.speed, tr.up
		end
		local dist = (pos - last.p).Magnitude
		if dist > C.TeleportMin and dist / dt > C.Teleport then
			table.clear(list) -- (a teleport: start over from here, keeping the speed we had)
		elseif dist < 1e-3 and dt < C.Hold and not (still and still < 1) then
			return tr.speed, tr.up -- (not moved since the last sample: most likely the network, wait for an update)
		elseif dist < 1e-3 then
			-- still for longer than a stall: a real stop, now (not eased out over the window: their legs stop
			-- ~0.15 s after the body does instead of running on in place for ~0.4 s)
			table.clear(list)
			tr.last = { t = now, p = pos }
			table.insert(list, tr.last)
			tr.speed, tr.up, tr.vel = 0, 0, Vector3.zero
			return 0, 0
		end
	end
	local sample = { t = now, p = pos }
	tr.last = sample
	table.insert(list, sample)
	while #list > 2 and now - list[2].t >= C.Window do
		table.remove(list, 1)
	end
	local first = list[1]
	local span = now - first.t
	if span >= C.MinSpan then
		local d = pos - first.p
		local flat = Vector3.new(d.X, 0, d.Z) / span
		tr.speed = math.min(flat.Magnitude, C.MaxSpeed)
		tr.vel = if flat.Magnitude > 1e-3 then flat.Unit * tr.speed else Vector3.zero
		tr.up = d.Y / span
	end
	return tr.speed, tr.up
end

--[[ The blended pose { [partName] = CFrame }: Idle at idleT, Walk and Run at the shared phase's times, each loop
	taking its share by weight (only the loops that show are sampled). sample = Shared/KeyframeSampler.sample. ]]
function LocomotionMix.pose(s, anims, idleT: number, sample)
	local w = s.weights
	local out, total = {}, 0
	for _, item in { { anims.Idle, idleT, w.Idle }, { anims.Walk, s.times.Walk, w.Walk }, { anims.Run, s.times.Run, w.Run } } do
		local weight = item[3]
		if weight > 1e-3 and item[1] then
			total += weight
			local f = weight / total -- (running blend: each loop takes its share of what's there so far)
			for name, cf in sample(item[1], item[2]) do
				local have = out[name]
				out[name] = if have then have:Lerp(cf, f) else cf
			end
		end
	end
	return out
end

return LocomotionMix
