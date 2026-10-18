--[[
	How a girl moves, as poses on her joints (Motor6D.Transform), worked out
	fresh each frame. Pure maths on joint tables, so the offline preview runs
	this exact code (tools/preview/motion3d).

	carried(): held up over the carrier's head, sitting up in his hands (upper body
	  raised, legs bent up at the hips), arms half hanging; dips and dangles in time
	  with his steps, swings her feet, kicks and looks round now and then, plus her
	  mood: Excited (just picked up), Struggle (stolen), Cheer (won), all calm.
	idle(): standing as the prize (when the owner's Idle can't be read). Shifts her weight, breathes,
	  watches the nearest runner, waves, and bounces when someone is close.
	walk(): walking or running (a girl following a catcher, your companion), when the owner's animations
	  can't be read (Shared/GirlMoves plays those).
	look(): the head turn toward the nearest player (idle uses it; so does Shared/GirlMoves).
	cheer(): little hops on the ground, arms up (your companion when you're safe).

	Joints are found by their Part1 name, so R6 and R15 both work. Poses are
	written in the parent part's space (x right, y up, -z forward) and
	turned into each joint's own frame by set().
]]
local Config = require(script.Parent.Config.GirlMotion)

local GirlMotion = {}
local rad, sin, abs, clamp, pi = math.rad, math.sin, math.abs, math.clamp, math.pi

local KEYS = {
	LowerTorso = "Root", UpperTorso = "Waist", Head = "Neck",
	LeftUpperArm = "LShoulder", RightUpperArm = "RShoulder", LeftLowerArm = "LElbow", RightLowerArm = "RElbow",
	LeftUpperLeg = "LHip", RightUpperLeg = "RHip", LeftLowerLeg = "LKnee", RightLowerLeg = "RKnee",
	Torso = "Root", ["Left Arm"] = "LShoulder", ["Right Arm"] = "RShoulder", ["Left Leg"] = "LHip", ["Right Leg"] = "RHip",
}

-- Joint table by role from a list of Motor6Ds.
function GirlMotion.joints(motors)
	local J = {}
	for _, m in motors do
		local key = m.Part1 and KEYS[m.Part1.Name]
		if key and not J[key] then
			J[key] = m
		end
	end
	return J
end

function GirlMotion.new(seed)
	return { seed = math.floor(seed or 1) % 2147483646 + 1, springs = {}, bursts = {} }
end

-- A pose in the parent part's space -> the joint's Transform.
local function set(m, cf)
	if m then
		local r = m.C0.Rotation
		m.Transform = r:Inverse() * cf * r
	end
end

local function random(s)
	s.seed = (s.seed * 16807) % 2147483647
	return s.seed / 2147483647
end

local function spring(s, key, target, dt, freq, damping)
	local sp = s.springs[key]
	if not sp then
		sp = { x = target, v = 0 }
		s.springs[key] = sp
	end
	local w = 2 * pi * freq
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	for _ = 1, steps do
		sp.v += (w * w * (target - sp.x) - 2 * damping * w * sp.v) * h
		sp.x += sp.v * h
	end
	return sp.x
end

-- 0 -> 1 -> 0 over a window, with soft edges.
local function envelope(age, length, fadeIn, fadeOut)
	if age < 0 or age > length then
		return 0
	end
	return math.min(1, age / fadeIn, (length - age) / fadeOut)
end

-- A recurring burst (a kick, a wave): its envelope now, rescheduled after it ends.
local function burst(s, name, t, every, length, fadeIn: number?, fadeOut: number?)
	local b = s.bursts[name]
	if not b then
		b = { start = t + every[1] * 0.5 + random(s) * every[1] }
		s.bursts[name] = b
	end
	if t > b.start + length then
		b.start = t + every[1] + (every[2] - every[1]) * random(s)
	end
	return envelope(t - b.start, length, fadeIn or 0.3, fadeOut or 0.4)
end

-- Pitch/roll that turn a limb hanging along -Y to point along d.
local function aim(d)
	return -math.asin(clamp(d.Z, -1, 1)), math.atan2(d.X, -d.Y)
end

local function limb(pitch, roll)
	return CFrame.Angles(0, 0, roll) * CFrame.Angles(pitch, 0, 0)
end

-- Gravity (plus inertia) as a direction in a part's space.
local function down(part, gWorld)
	return part.CFrame:VectorToObjectSpace(gWorld).Unit
end

local function hangToward(g, weight)
	local d = Vector3.new(0, -1, 0):Lerp(g, weight)
	if d.Magnitude < 0.05 then
		d = g
	end
	return aim(d.Unit)
end

-- Bend of an elbow/knee (x-axis) that lets the lower limb fall toward g.
local function bendToward(g)
	return math.atan2(-g.Z, -g.Y)
end

--[[ Carried overhead (owner Oct 18: "make the girls have some motion, not just be held straight up like that, and
	make it for all of the girls"): not a stiff plank any more but sitting up in his hands, like being lifted up
	high: her upper body raised (Pose.TorsoUp), her legs bent up at the hips (Pose.LegsUp; an R15 girl's shins
	also hang from bent knees), arms relaxed and half hanging, head loose and looking where he goes. On top, calm
	life: a small dip and dangle in time with his footsteps (ctx.step), her feet swinging slowly, a little kick
	and a look round now and then, limbs swinging a little when he starts, stops or turns (Inertia). Moods add a
	short happy flutter (Excited), a wriggle (Struggle) or waving (Cheer), all kept small.
	ctx: accel (world, her own acceleration), forward (world, the carrier's facing), mood ("Calm" | "Excited" |
	"Struggle" | "Cheer"), moodAge (seconds), step (-1..1, his step: CarryMotion's bob), amount (0-1.4: how hard he's
	moving; 0 standing still) ]]
function GirlMotion.carried(s, J, dt, t, ctx)
	local C = Config.Carried
	local P = C.Pose
	local gWorld = Vector3.new(0, -C.Gravity, 0) - ctx.accel * C.Inertia
	local mood, age = ctx.mood or "Calm", ctx.moodAge or 99
	if not C.Moods then
		mood = "Calm"
	end
	local step, amount = ctx.step or 0, clamp(ctx.amount or 0, 0, 1.4)
	local still = 1 - clamp(amount, 0, 1) -- (her own slow swinging shows most while he stands)
	local bounce = abs(step) * amount -- (each footfall)

	-- How much of each overlay plays right now
	local excited = if mood == "Excited" then envelope(age, C.Excited.Time, 0.15, 0.5) else 0
	local cheer = if mood == "Cheer" then math.min(1, age / 0.3) else 0
	local struggle = 0
	if mood == "Struggle" then
		struggle = math.max(envelope(age, C.Struggle.Time, 0.1, 0.5), if age > C.Struggle.Time then burst(s, "struggle", t, C.Struggle.Every, C.Struggle.Burst) else 0)
	end
	local calm = 1 - math.max(excited, cheer, struggle)
	local kick = math.max(excited, cheer * 0.5, calm * burst(s, "kick", t, C.Calm.Kick.Every, C.Calm.Kick.Time))
	local waveOne = calm * burst(s, "wave", t, C.Calm.Wave.Every, C.Calm.Wave.Time, 0.6, 0.7) -- (slow: calm)
	local waveBoth = math.max(excited * 0.6, cheer)
	local glance = calm * burst(s, "glance", t, C.Calm.Glance.Every, C.Calm.Glance.Time, 0.6, 0.7)
	if glance > 0 and not s.glanceSide then
		s.glanceSide = if random(s) < 0.5 then -1 else 1
	elseif glance == 0 then
		s.glanceSide = nil
	end
	local kickSpeed = if struggle > 0 then 2.6 else 1.8

	-- Her body sits up (a turn of her torso), gives a little at each of his steps, breathes
	local sit = rad(P.TorsoUp) + rad(P.StepGive) * bounce + rad(1.5) * sin(t * 1.6) + rad(6) * sin(t * 2 * pi * 2.1) * struggle
	set(J.Root, CFrame.Angles(-spring(s, "sit", sit, dt, C.Spring.Legs, 0.8), 0, rad(8) * sin(t * 2 * pi * 1.3) * struggle))
	-- (R15: a soft curve at the waist too)
	set(J.Waist, CFrame.Angles(-rad(P.TorsoUp) * 0.3 + rad(1.5) * sin(t * 1.6), 0, rad(8) * sin(t * 2 * pi * 2.3) * struggle))

	for side, sign in { L = -1, R = 1 } do
		local other = if side == "L" then pi else 0
		-- Arms: half hanging, swaying a little with his steps; waving at the sky; wriggling when struggling
		local shoulder = J[side .. "Shoulder"]
		if shoulder and shoulder.Part0 then
			local p, r = hangToward(down(shoulder.Part0, gWorld), C.Arms)
			p += rad(P.ArmSway) * step * amount * sign + rad(3) * sin(t * 0.9 + other) * still
			r += sign * rad(P.ArmsOut)
			local wave = math.max(waveBoth, if side == "R" then waveOne else 0)
			local swing = sin(t * 2 * pi * 1.6 + other)
			p += (rad(120) - p) * wave
			r += (sign * rad(20 + 14 * swing) - r) * wave
			if struggle > 0 then
				local flail = sin(t * 2 * pi * 2.2 + (if side == "L" then 0 else 2))
				p += (rad(35 + 30 * flail) - p) * struggle
				r += (sign * rad(25 + 12 * sin(t * 2 * pi * 1.7 + sign)) - r) * struggle
			end
			set(shoulder, limb(spring(s, side .. "ap", p, dt, C.Spring.Arms, C.Spring.Damping), spring(s, side .. "ar", r, dt, C.Spring.Arms, C.Spring.Damping)))
		end
		local elbow = J[side .. "Elbow"]
		if elbow and elbow.Part0 then
			local bend = clamp(bendToward(down(elbow.Part0, gWorld)), 0, rad(130)) * C.Elbows + rad(15)
			bend += (rad(35) - bend) * math.max(waveBoth, if side == "R" then waveOne else 0, struggle)
			set(elbow, CFrame.Angles(spring(s, side .. "e", bend, dt, C.Spring.Arms * 1.3, C.Spring.Damping), 0, 0))
		end

		-- Legs: bent up at the hips, a little apart, dangling with his steps and swinging slowly on their own;
		-- a small flutter kick now and then
		local hip = J[side .. "Hip"]
		if hip and hip.Part0 then
			local phase = t * 2 * pi * kickSpeed + other
			local p = rad(P.LegsUp) + rad(P.LegSway) * (step * sign * 0.6 + bounce * 0.4)
				+ rad(P.Swing) * sin(t * 2 * pi * 0.45 + other) * (0.4 + 0.6 * still)
				+ sin(phase) * rad(C.Calm.Kick.Size) * math.max(kick, struggle * 1.3)
			local r = sign * rad(P.LegsApart)
			set(hip, limb(spring(s, side .. "lp", p, dt, C.Spring.Legs, C.Spring.Damping), spring(s, side .. "lr", r, dt, C.Spring.Legs, C.Spring.Damping)))
		end
		local knee = J[side .. "Knee"]
		if knee and knee.Part0 then
			local phase = t * 2 * pi * kickSpeed + other
			local bend = -rad(P.Knees) - (0.5 + 0.5 * sin(phase)) * rad(30) * math.max(kick, struggle) - rad(4) * bounce
			set(knee, CFrame.Angles(spring(s, side .. "k", bend, dt, C.Spring.Legs * 1.3, C.Spring.Damping), 0, 0))
		end
	end

	-- Head: looks where you're going, loose (nods a little with each step), glances round now and then
	local neck = J.Neck
	if neck and neck.Part0 then
		local v = neck.Part0.CFrame:VectorToObjectSpace(ctx.forward)
		local yaw = clamp(math.atan2(-v.X, -v.Z), rad(-75), rad(75)) * C.LookAhead
		yaw += rad(C.Calm.Glance.Angle) * (s.glanceSide or 0) * glance
		if C.LookAround then
			yaw += rad(12) * sin(t * 0.7) * sin(t * 0.31)
		end
		local pitch = clamp(math.atan2(v.Y, Vector3.new(v.X, 0, v.Z).Magnitude), rad(-40), rad(40)) * C.LookAhead
		pitch += rad(P.HeadNod) * bounce
		yaw += rad(18) * sin(t * 2 * pi * 2.5) * struggle
		pitch += rad(12) * math.max(waveBoth, waveOne) -- lifts her head to wave
		set(neck, CFrame.Angles(0, spring(s, "ny", yaw, dt, 2.5, 0.8), 0) * CFrame.Angles(spring(s, "np", pitch, dt, 3, 0.8), 0, 0))
	end
end

--[[ ctx: target (world position of the nearest runner's head, or nil), distance ]]
function GirlMotion.idle(s, J, dt, t, ctx)
	local I = Config.Idle
	local dist = ctx.distance or math.huge
	local shift = sin(t * 2 * pi / I.SwaySeconds)
	local sway = rad(I.Sway) * shift
	local excite = spring(s, "excite", if I.Bounce and dist < I.BounceDistance then 1 else 0, dt, 1.5, 1)
	local hop = abs(sin(t * 2 * pi * 1.6)) * 0.45 * excite

	-- A wave when a runner comes close (at most every 6 s), and now and then anyway
	local waveLen = 2.2
	s.lastWave = s.lastWave or -99
	s.nextWave = s.nextWave or (t + I.WaveEvery[1] * random(s))
	if I.Wave and t - s.lastWave > 6 and (dist < I.WaveDistance or t > s.nextWave) then
		s.lastWave = t
		s.nextWave = t + I.WaveEvery[1] + (I.WaveEvery[2] - I.WaveEvery[1]) * random(s)
	end
	local wave = envelope(t - s.lastWave, waveLen, 0.3, 0.4)

	-- Body: weight shift side to side, a hop when excited
	set(J.Root, CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, sway))
	set(J.Waist, CFrame.Angles(rad(1.2) * sin(t * 1.6), 0, -sway * 0.5))
	for side, sign in { L = -1, R = 1 } do
		set(J[side .. "Hip"], limb(rad(2) * sign * shift, -sway))
		set(J[side .. "Knee"], CFrame.Angles(-rad(6) * math.max(0, sign * shift), 0, 0))
		local breath = rad(2) * sin(t * 1.6 + sign)
		local p, r = breath, sign * rad(6)
		if side == "R" then
			p += (rad(10) - p) * wave
			r += (rad(150) + rad(16) * sin((t - s.lastWave) * 2 * pi * 2.5) - r) * wave
		end
		set(J[side .. "Shoulder"], limb(spring(s, side .. "ip", p, dt, 4, 0.7), spring(s, side .. "ir", r, dt, 4, 0.7)))
		set(J[side .. "Elbow"], CFrame.Angles(rad(12) + rad(30) * (if side == "R" then wave else 0), 0, 0))
	end

	-- Head: watches the nearest runner, a little tilt
	local look = GirlMotion.look(s, J, dt, t, ctx, rad(8) * wave - sway * 0.6)
	if look then
		set(J.Neck, look)
	end
end

--[[ The head turn that watches ctx.target (the nearest player's head) when within Config.Idle.LookDistance,
	else drifts slowly; springy. In the torso's space (as a Neck pose), or nil without a neck. tilt: extra roll.
	idle() uses it, and so does the pack's idle (Shared/GirlMoves: the prize girl, a girl standing still). ]]
function GirlMotion.look(s, J, dt, t, ctx, tilt: number?)
	local neck = J.Neck
	if not (neck and neck.Part0) then
		return nil
	end
	local dist = ctx.distance or math.huge
	local yaw, pitch = rad(12) * sin(t * 0.3), 0
	if ctx.target and dist < Config.Idle.LookDistance then
		local head = neck.Part0.CFrame * neck.C0
		local v = head:VectorToObjectSpace(ctx.target - head.Position)
		v = neck.C0.Rotation:VectorToWorldSpace(v) -- back into the torso's frame
		yaw = clamp(math.atan2(-v.X, -v.Z), rad(-65), rad(65))
		pitch = clamp(math.atan2(v.Y, Vector3.new(v.X, 0, v.Z).Magnitude), rad(-30), rad(30))
	end
	local roll = rad(2) * sin(t * 0.5) + (tilt or 0)
	return CFrame.Angles(0, spring(s, "iy", yaw, dt, 2, 0.8), 0) * CFrame.Angles(spring(s, "ipt", pitch, dt, 2, 0.8), 0, roll)
end

--[[ Walking behind a catcher. ctx: speed (studs/s), stride (studs per two steps),
	target/distance (as idle: who to watch when she stands still),
	run (optional, 0-1: blends in a run: leaning, knees up, arms bent and pumping; the companion uses it) ]]
function GirlMotion.walk(s, J, dt, t, ctx)
	s.phase = (s.phase or 0) + ctx.speed * dt * 2 * pi / ctx.stride
	local amount = spring(s, "walk", clamp(ctx.speed / 10, 0, 1.2), dt, 3, 1)
	if amount < 0.03 then
		GirlMotion.idle(s, J, dt, t, ctx)
		return
	end
	local run = spring(s, "run", clamp(ctx.run or 0, 0, 1), dt, 3, 1) * math.min(1, amount)
	local phase = s.phase
	local swing = rad(30 + 14 * run) * sin(phase) * amount
	set(J.Root, CFrame.new(0, (abs(sin(phase)) - 0.5) * (0.1 + 0.12 * run) * amount, 0) * CFrame.Angles(rad(3 + 9 * run) * amount, rad(4) * sin(phase) * amount, 0))
	set(J.Waist, CFrame.Angles(rad(4) * run, -rad(6) * sin(phase) * amount, 0))
	for side, sign in { L = -1, R = 1 } do
		local legSwing = if side == "R" then swing else -swing
		set(J[side .. "Hip"], CFrame.Angles(legSwing, 0, 0))
		set(J[side .. "Knee"], CFrame.Angles(-rad(50 + 35 * run) * math.max(0, (if side == "R" then -1 else 1) * sin(phase)) * amount, 0, 0))
		set(J[side .. "Shoulder"], limb(-legSwing * (0.8 + 0.3 * run), sign * rad(5 + 5 * run)))
		set(J[side .. "Elbow"], CFrame.Angles(rad(12 + 15 * amount + 55 * run), 0, 0))
	end
	set(J.Neck, CFrame.Angles(-rad(3 + 5 * run) * amount, 0, 0))
end

--[[ Cheering on the ground (your companion once you're safe across in a round): little hops with both arms
	up and waving, knees bending as she lands. Returns how high her feet are off the ground now (0-1 of a full
	hop); the caller lifts her by that times her hop height, so she always lands back on the ground. ]]
function GirlMotion.cheer(s, J, dt, t, ctx)
	local period = 0.62
	local u = ((t + (s.seed % 100) * 0.013) % period) / period
	local air = 0.62 -- the part of each hop in the air; the rest is the landing crouch
	local hop, crouch = 0, 0
	if u < air then
		local a = u / air
		hop = 4 * a * (1 - a)
	else
		crouch = sin((u - air) / (1 - air) * pi)
	end
	local on = math.min(1, (s.cheerAge or 0) / 0.25)
	s.cheerAge = (s.cheerAge or 0) + dt
	local pump = sin(t * 2 * pi / period)
	set(J.Root, CFrame.new(0, 0, 0) * CFrame.Angles(-rad(4) * crouch * on, 0, 0))
	set(J.Waist, CFrame.Angles(-rad(3) * on, 0, rad(3) * sin(t * 3)))
	for side, sign in { L = -1, R = 1 } do
		-- arms up in a V, pumping with each hop
		local r = sign * rad(145 + 12 * pump) * on
		set(J[side .. "Shoulder"], limb(spring(s, side .. "cp", rad(10) * on, dt, 5, 0.7), spring(s, side .. "cr", r, dt, 5, 0.7)))
		set(J[side .. "Elbow"], CFrame.Angles(rad(15 + 15 * crouch) * on, 0, 0))
		-- knees bend on landing, legs tuck a little in the air
		set(J[side .. "Hip"], limb(rad(20 * crouch + 10 * hop) * on, sign * rad(3)))
		set(J[side .. "Knee"], CFrame.Angles(-rad(40 * crouch + 25 * hop) * on, 0, 0))
	end
	set(J.Neck, CFrame.Angles(rad(10) * on, 0, rad(6) * pump * on))
	return hop * on
end

return GirlMotion
