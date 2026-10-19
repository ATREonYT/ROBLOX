-- lune run tests/Locomotion.spec.luau
-- Everyone's walk and run (Shared/LocomotionMix with Config/Run.Loco and .Track; owner, Oct 18: "player to player
-- less choppy", "make the walking animations way way better"):
--   - the walk and run speeds in the config are the pack's own (measured on a standard R15 body), so the feet plant;
--   - at every walking speed and up to the 16 studs/s you set off at, the planted foot slides less than 12%;
--   - walk and run step at nearly the same rate where they swap (no pop); a runner's 28 is ~4.6 steps/s (HV);
--   - another player's speed read from jittery, bursty network positions stays smooth and right, a teleport
--     doesn't spike it, a network stall doesn't drop it, a real stop does;
--   - the stride phase never jumps or runs backwards, whatever the speed does;
--   - holding W (16 to 28 in ~0.5 s) never makes the blend jump; a bigger avatar takes longer steps;
--   - shift lock: A/D turn the hips toward the move while the head keeps facing ahead, S back-pedals, nothing snaps.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local Sampler = Env.load(SHARED .. "KeyframeSampler.lua")
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local L = Run.Loco

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

-- The pack, measured on the preview's standard R15 body: how fast the planted foot moves back at 1x.
local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local folder = lib:FindFirstChild("HuzzAnimations")
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = Sampler.load(folder:FindFirstChild(name)) end
local lengths = { Walk = A.Walk.length, Run = A.Run.length }
local rig = Rig.r15("M")
local function soles(anim, t)
	local pose = Sampler.sample(anim, t)
	for _, m in rig.motors do m.Transform = pose[m.Part1.Name] or CFrame.identity end
	rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
	Rig.fk(rig)
	return rig.parts.LeftFoot.CFrame * Vector3.new(0, -0.15, 0), rig.parts.RightFoot.CFrame * Vector3.new(0, -0.15, 0)
end
local function plantedSpeed(anim)
	local n, back = 240, 0
	local l0, r0 = soles(anim, 0)
	for i = 1, n do
		local l1, r1 = soles(anim, i / n * anim.length)
		local side0 = if l0.Y < r0.Y then "l" else "r"
		local side1 = if l1.Y < r1.Y then "l" else "r"
		if side0 == side1 then
			back += math.max(if side0 == "l" then l1.Z - l0.Z else r1.Z - r0.Z, 0)
		end
		l0, r0 = l1, r1
	end
	return back / anim.length
end
local walkPlanted, runPlanted = plantedSpeed(A.Walk), plantedSpeed(A.Run)
print(string.format("  pack: walk feet planted at %.2f studs/s (config %.2f), run at %.2f (config %.2f)", walkPlanted, L.WalkAt, runPlanted, L.RunAt))
check(math.abs(L.WalkAt / walkPlanted - 1) < 0.08, "Loco.WalkAt is the pack Walk's own planted-foot speed (within 8%)")
check(math.abs(L.RunAt / runPlanted - 1) < 0.08, "Loco.RunAt is the pack Run's own planted-foot speed (within 8%)")

-- Steady state at a speed: the foot slide and the step rate.
local function settle(v, config)
	local s = Mix.new(config)
	for _ = 1, 180 do Mix.step(s, 1 / 60, { speed = v, state = "ground", lengths = lengths }) end
	return s
end
local worst, worstAt = 0, 0
for v = L.MoveFull, Run.StartSpeed, 0.5 do
	local s = settle(v)
	local slide = math.abs(Mix.footSpeed(s) - v) / v
	if slide > worst then worst, worstAt = slide, v end
end
print(string.format("  worst foot slide from %.0f to %.0f studs/s: %.0f%% at %.1f", L.MoveFull, Run.StartSpeed, worst * 100, worstAt))
check(worst < 0.12, "walking speeds up to the 16 you set off at: the planted foot slides under 12%")
do -- (before Oct 18 the walk was asked to cover 16 studs/s: show how bad that was, for the record)
	local old = table.clone(L)
	old.RunFrom, old.RunFull, old.WalkAt, old.WalkRate, old.RunAt, old.RunRate = 13, 21, 8, { 0.75, 1.3 }, 25, { 0.85, 1.15 }
	local s = settle(16, old)
	local foot = s.weights.Walk * s.speeds.Walk * walkPlanted + s.weights.Run * s.speeds.Run * runPlanted
	print(string.format("  (old numbers at 16 studs/s: feet moved %.1f studs/s under a body going 16: %.0f%% slide)", foot, math.abs(foot - 16) / 16 * 100))
end
local function rateAt(v, which)
	local s = settle(v)
	return s.speeds[which] / lengths[which] * 2, s
end
local walkSwap = rateAt(L.RunFrom, "Walk")
local runSwap = rateAt(L.RunFull, "Run")
local walkEnd = rateAt(L.RunFull, "Walk")
local runStart = rateAt(L.RunFrom, "Run")
check(math.abs(walkSwap / runStart - 1) < 0.3 and math.abs(walkEnd / runSwap - 1) < 0.15,
	string.format("walk and run step at nearly the same rate where they swap (%.1f vs %.1f and %.1f vs %.1f steps/s)", walkSwap, runStart, walkEnd, runSwap))
local top = Mix.stepsPerSecond(settle(Round.Speeds.Runner), lengths)
check(top >= 4.2 and top <= 4.8, string.format("a runner (28) steps ~4.6 times a second like HV (%.2f)", top))
check(settle(Run.StartSpeed).weights.Run > 0.97, "setting off at 16 is already a run (HV runs at once)")
check(settle(4).weights.Walk > 0.97, "a slow thumbstick (4 studs/s) is a walk")
check(settle(0).weights.Idle > 0.99, "standing is the idle")

-- A bigger avatar: the same slide at the same share of its size.
do
	local big = Mix.sized(L, 1.5)
	local s = settle(6, big)
	check(math.abs(Mix.footSpeed(s) - 6) / 6 < 0.12 and big.WalkAt > L.WalkAt, "a 1.5x avatar's walk plants its feet at its own (longer) stride")
end

-- Another player's speed from jittery network positions: true speed 20 along x, positions arriving in bursts
-- (held for 1-3 frames, then caught up), with +-0.15 stud noise, at 60 fps.
local Rand = {} -- (a seeded generator: Lune has no Random)
Rand.__index = Rand
function Rand.new(seed) return setmetatable({ x = seed }, Rand) end
function Rand:NextNumber(a, b)
	self.x = (self.x * 1103515245 + 12345) % 2147483648
	return a + (b - a) * self.x / 2147483648
end
function Rand:NextInteger(a, b) return math.min(b, a + math.floor(self:NextNumber(0, b - a + 1))) end
local rng = Rand.new(7)
local function jitter(trueSpeed, seconds, startPos, startT, tr, s, out)
	local pos, t = startPos, startT
	local shown = pos
	local hold = 0
	for _ = 1, math.floor(seconds * 60) do
		t += 1 / 60
		pos += Vector3.new(trueSpeed / 60, 0, 0)
		if hold > 0 then
			hold -= 1
		else
			shown = pos + Vector3.new(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
			hold = rng:NextInteger(0, 2)
		end
		local v = Mix.track(tr, t, shown)
		local phase0 = s.phase
		Mix.step(s, 1 / 60, { speed = v, state = "ground", lengths = lengths })
		table.insert(out, { t = t, raw = v, speed = s.speed, dphase = (s.phase - phase0) % 1, walk = s.times.Walk, run = s.times.Run })
	end
	return pos, t
end
local tr, s, out = Mix.tracker(Run.Track), Mix.new(), {}
local pos, t = jitter(20, 3, Vector3.zero, 0, tr, s, out)
local minS, maxS, maxStep = math.huge, -math.huge, 0
for i = 90, #out do
	minS, maxS = math.min(minS, out[i].speed), math.max(maxS, out[i].speed)
	maxStep = math.max(maxStep, math.abs(out[i].speed - out[i - 1].speed))
end
-- the same positions read the old way (velocity from one frame to the next)
local naiveMin, naiveMax = math.huge, -math.huge
do
	local p0, t0 = Vector3.zero, 0
	rng = Rand.new(7)
	local hold, shown, p = 0, Vector3.zero, Vector3.zero
	for i = 1, 180 do
		local tt = i / 60
		p += Vector3.new(20 / 60, 0, 0)
		if hold > 0 then hold -= 1 else shown = p + Vector3.new(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)); hold = rng:NextInteger(0, 2) end
		local v = (shown - p0).Magnitude / (tt - t0)
		p0, t0 = shown, tt
		if i > 90 then naiveMin, naiveMax = math.min(naiveMin, v), math.max(naiveMax, v) end
	end
end
print(string.format("  jittery network at 20 studs/s: read %.1f to %.1f (frame-to-frame velocity: %.1f to %.1f)", minS, maxS, naiveMin, naiveMax))
check(minS > 18 and maxS < 22, "a remote runner at 20 studs/s reads 18-22 through bursty, noisy positions")
check(maxStep < 0.6, string.format("and the speed the blend uses never jumps (biggest change in a frame %.2f studs/s)", maxStep))
local maxCadence = math.max(L.WalkRate[2] / lengths.Walk, L.RunRate[2] / lengths.Run)
local phaseOk, timesOk = true, true
for i = 2, #out do
	if out[i].dphase < 0 or out[i].dphase > maxCadence / 60 + 1e-6 then phaseOk = false end
end
check(phaseOk, "the stride phase only moves forward, never more than the fastest cadence allows in a frame")

-- A network stall (no update for 0.12 s) keeps the speed; a teleport (40 studs) doesn't spike it; a real stop ends it.
do
	local before = tr.speed
	local stallPos = tr.last.p
	local v = before
	for i = 1, 7 do v = Mix.track(tr, t + i / 60, stallPos) end
	check(math.abs(v - before) < 0.01, "a 0.12 s network stall keeps the last speed")
	t += 8 / 60
	pos = stallPos + Vector3.new(20 * 8 / 60, 0, 0)
	v = Mix.track(tr, t, pos)
	check(v < 24, string.format("the catch-up after the stall doesn't spike the speed (%.1f)", v))
	pos += Vector3.new(40, 0, 0)
	local peak = 0
	for _ = 1, 30 do
		t += 1 / 60
		pos += Vector3.new(20 / 60, 0, 0)
		peak = math.max(peak, Mix.track(tr, t, pos))
	end
	check(peak < 24, string.format("a 40-stud teleport doesn't spike the speed (peak %.1f)", peak))
	local s2 = Mix.new()
	for _ = 1, 60 do
		t += 1 / 60
		Mix.step(s2, 1 / 60, { speed = Mix.track(tr, t, pos), state = "ground", lengths = lengths })
	end
	check(tr.speed < 0.5 and s2.weights.Idle > 0.9, "standing still for a second reads as a stop (idle)")
end

-- Holding W from standing (Gameplay/Sprint: off at 16, 28 in ~0.5 s), measured against Huss Valley's recording
-- (owner, Oct 19: "the slow walking into the running animation", "a quick but nice looking stopping animation"):
-- HV takes short quick steps for ~0.15 s and has the full stride by ~0.35 s; its ground stops within a frame and the
-- legs are at the idle ~0.15 s later, the arms swinging out as the feet plant.
do
	local s3 = Mix.new()
	local speed, prev = 0, nil
	local walkAt, runAt, idleAt, biggestStop, biggestGo = nil, nil, nil, 0, 0
	local plantPeak, plantPeakAt, plantGoneAt = 0, nil, nil
	for i = 1, 150 do
		local target = if i <= 90 then Round.Speeds.Runner else 0
		if i == 1 then speed = Run.StartSpeed end
		speed = if target == 0 then 0 else speed + (target - speed) * (1 - math.exp(-(1 / 60) / (Run.Ramp / 3)))
		Mix.step(s3, 1 / 60, { speed = speed, state = "ground", lengths = lengths })
		local w = s3.weights
		if not walkAt and w.Walk > 0.5 then walkAt = i / 60 end
		if not runAt and w.Run > 0.95 then runAt = i / 60 end
		if prev then
			local change = math.max(math.abs(w.Walk - prev.Walk), math.abs(w.Run - prev.Run), math.abs(w.Idle - prev.Idle))
			if i > 90 then biggestStop = math.max(biggestStop, change) else biggestGo = math.max(biggestGo, change) end
		end
		if i > 90 then
			local t = (i - 90) / 60
			if not idleAt and w.Idle > 0.95 then idleAt = t end
			local p = Mix.stopAmount(s3)
			if p > plantPeak then plantPeak, plantPeakAt = p, t end
			if plantPeak > 0 and p < 0.01 and not plantGoneAt then plantGoneAt = t end
		end
		prev = table.clone(w)
	end
	print(string.format("  set-off: walk at %.2f s, full run at %.2f s (HV ~0.15 / ~0.35); stop: idle at %.2f s (HV ~0.15), plant %.2f at %.2f s, gone by %.2f s; biggest change a frame %.2f going, %.2f stopping",
		walkAt or -1, runAt or -1, idleAt or -1, plantPeak, plantPeakAt or -1, plantGoneAt or -1, biggestGo, biggestStop))
	check(walkAt and walkAt <= 0.1, "setting off: the walk shows first (short quick steps, like HV)")
	check(runAt and runAt >= 0.28 and runAt <= 0.45, string.format("and the full run comes in by HV's ~0.35 s (%.2f s)", runAt or -1))
	check(biggestGo < 0.35, string.format("never a pop on the way (biggest change in a 60 fps frame %.2f)", biggestGo))
	check(idleAt and idleAt >= 0.1 and idleAt <= 0.25 and biggestStop < 0.4,
		string.format("a sudden stop: the legs at the idle in %.2f s (HV ~0.15), biggest change in a frame %.2f", idleAt or -1, biggestStop))
	check(plantPeak > 0.85 and plantPeakAt <= 0.1 and plantGoneAt and plantGoneAt <= 0.36,
		"and the plant (body back, arms out) is up within 0.1 s and gone by ~0.3 s")
	-- a stop from a walk plays no plant; setting off again at once takes the plant away
	local s4 = Mix.new()
	for _ = 1, 60 do Mix.step(s4, 1 / 60, { speed = 4, state = "ground", lengths = lengths }) end
	for _ = 1, 10 do Mix.step(s4, 1 / 60, { speed = 0, state = "ground", lengths = lengths }) end
	check(Mix.stopAmount(s4) < 0.01, "stopping from a slow walk plays no plant")
	local s5 = Mix.new()
	for _ = 1, 90 do Mix.step(s5, 1 / 60, { speed = 28, state = "ground", lengths = lengths }) end
	for _ = 1, 3 do Mix.step(s5, 1 / 60, { speed = 0, state = "ground", lengths = lengths }) end
	for _ = 1, 8 do Mix.step(s5, 1 / 60, { speed = 20, state = "ground", lengths = lengths }) end
	check(Mix.stopAmount(s5) < 0.15, "setting off again straight away takes the plant away (no arms out while running)")
end

-- Shift lock (owner, Oct 19: "make it so when you shift lock the only thing that moves when you press w a s d (etc)
-- is their body not their head"): the hips turn toward the move, the head keeps facing ahead, backwards is a
-- back-pedal, and nothing snaps.
do
	local DT = 1 / 30
	local body = Rig.r15("S")
	local rootJ = body.parts.LowerTorso.joints.Root
	local waist, neck = body.parts.UpperTorso.joints.Waist, body.parts.Head.joints.Neck
	local function yawOf(cf)
		local look = cf.LookVector
		return math.deg(math.atan2(-look.X, -look.Z)) -- (+ = turned left, as Roblox's yaw)
	end
	local function drive(s, vel, on, quiet, seconds)
		local biggest, turn, back = 0, 0, false
		for _ = 1, math.floor(seconds / DT) do
			local before = s.turn
			Mix.step(s, DT, { speed = vel.Magnitude, state = "ground", lengths = lengths })
			turn, back = Mix.strafe(s, DT, vel, on, quiet)
			biggest = math.max(biggest, math.abs(math.deg(turn - before)))
		end
		-- (over the run's own pose at mid-stride: hunched forward, so a plain counter-turn would tip the head)
		local pose = Sampler.sample(A.Run, A.Run.length * 0.3)
		for _, m in body.motors do m.Transform = pose[m.Part1.Name] or CFrame.identity end
		body.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(body)
		local head0, lower0, upper0 = body.parts.Head.CFrame, body.parts.LowerTorso.CFrame, body.parts.UpperTorso.CFrame
		local hips, w, n = Mix.strafePose(s, turn, {
			root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
			waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
			neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
		})
		rootJ.Transform, waist.Transform, neck.Transform = hips, w, n
		body.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(body)
		local _, headOff = (head0.Rotation:Inverse() * body.parts.Head.CFrame.Rotation):ToAxisAngle()
		return { hips = yawOf(lower0) - yawOf(body.parts.LowerTorso.CFrame), chest = yawOf(upper0) - yawOf(body.parts.UpperTorso.CFrame),
			head = math.deg(math.abs(headOff)), back = back, biggest = biggest }
	end
	local S = L.Strafe
	local s = Mix.new()
	local right = drive(s, Vector3.new(28, 0, 0), true, 0, 0.6)
	check(math.abs(right.hips - S.MaxTurn) < 3, string.format("D in shift lock: the hips turn right toward the move (%.0f degrees)", right.hips))
	check(right.head < 1, string.format("the head keeps facing just where the run had it, no tip (%.2f degrees off)", right.head))
	check(right.chest > 10 and right.chest < right.hips, string.format("the chest turns part way (%.0f)", right.chest))
	check(right.biggest <= 25, string.format("no snap: at most %.0f degrees a frame at 30 fps", right.biggest))
	local fwd = drive(Mix.new(), Vector3.new(0, 0, -28), true, 0, 0.6)
	check(math.abs(fwd.hips) < 1 and not fwd.back, "W: the body faces ahead as before")
	local free = drive(Mix.new(), Vector3.new(28, 0, 0), false, 0, 0.6)
	check(math.abs(free.hips) < 1, "without shift lock nothing turns (Roblox already faces you the way you go)")
	local hussing = drive(Mix.new(), Vector3.new(28, 0, 0), true, 1, 0.6)
	check(math.abs(hussing.hips) < 1, "a huss, a leap, a dance or lying down keeps it out")
	local s2 = Mix.new()
	local back = drive(s2, Vector3.new(0, 0, 28), true, 0, 0.6)
	local phase0 = s2.phase
	Mix.step(s2, DT, { speed = 28, state = "ground", lengths = lengths })
	local stepBack = ((s2.phase - phase0 + 0.5) % 1) - 0.5
	check(back.back and math.abs(back.hips) < 1 and stepBack < 0, "S: a back-pedal (facing ahead, the run playing backwards)")
	local backRight = drive(Mix.new(), Vector3.new(20, 0, 20), true, 0, 0.6)
	check(backRight.back and backRight.hips < -30, string.format("back and right: the hips turn to the front left, pedalling back (%.0f)", backRight.hips))
	local stop = drive(s, Vector3.zero, true, 0, 0.6)
	check(math.abs(stop.hips) < 3 and stop.biggest <= 25, string.format("letting go turns the body back ahead smoothly (%.0f left, %.0f a frame at most)", stop.hips, stop.biggest))
end

-- Without shift lock (owner, Oct 19 18:16: "when he presses D, the body turns right, but the head and camera stays
-- the same"): Roblox has turned the body to the move; the head turns back toward where the camera looks, within a
-- neck's reach, never tipped, and comes to the front when the camera looks at your face.
do
	local DT = 1 / 30
	local body = Rig.r15("H")
	local rootJ = body.parts.LowerTorso.joints.Root
	local waist, neck = body.parts.UpperTorso.joints.Waist, body.parts.Head.joints.Neck
	local function yawOf(cf)
		local look = cf.LookVector
		return math.deg(math.atan2(-look.X, -look.Z))
	end
	local function headFor(aimDeg, on, seconds)
		local s = Mix.new()
		local biggest, look = 0, 0
		for _ = 1, math.floor(seconds / DT) do
			Mix.step(s, DT, { speed = 28, state = "ground", lengths = lengths })
			local before = look
			look = Mix.look(s, DT, math.rad(aimDeg), on, 0)
			biggest = math.max(biggest, math.abs(math.deg(look - before)))
		end
		local pose = Sampler.sample(A.Run, A.Run.length * 0.3)
		for _, m in body.motors do m.Transform = pose[m.Part1.Name] or CFrame.identity end
		body.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(body)
		local head0, lower0 = body.parts.Head.CFrame, body.parts.LowerTorso.CFrame
		local hips, w, n = Mix.strafePose(s, 0, {
			root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
			waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
			neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
		}, look)
		rootJ.Transform, waist.Transform, neck.Transform = hips, w, n
		Rig.fk(body)
		-- the head turned exactly `look` about straight up from where the run had it (no tip)
		local want = CFrame.Angles(0, -look, 0) * head0.Rotation
		local _, tip = (want:Inverse() * body.parts.Head.CFrame.Rotation):ToAxisAngle()
		return { head = yawOf(head0) - yawOf(body.parts.Head.CFrame), hips = yawOf(lower0) - yawOf(body.parts.LowerTorso.CFrame),
			tip = math.deg(math.abs(tip)), biggest = biggest }
	end
	local Lk = L.Look
	-- D without shift lock: the body faces right, the camera still looks ahead = 90 degrees to the body's left
	local d = headFor(-90, true, 0.8)
	check(math.abs(d.head + Lk.Max) < 3 and math.abs(d.hips) < 0.5 and d.tip < 1,
		string.format("D without shift lock: the head turns %.0f degrees back toward the camera's way, the legs stay on the move (tip %.2f)", d.head, d.tip))
	check(d.biggest <= 20, string.format("no snap: at most %.0f degrees a frame at 30 fps", d.biggest))
	local ahead = headFor(0, true, 0.8)
	check(math.abs(ahead.head) < 0.5, "running the way the camera looks: the head faces ahead")
	local face = headFor(175, true, 0.8)
	check(math.abs(face.head) < 1, "the camera looking at your face: the head faces where you run (a neck can't turn round)")
	local locked = headFor(-90, false, 0.8)
	check(math.abs(locked.head) < 0.5, "in shift lock the body already faces the camera: the look stays out")

	-- Oct 19 19:48 (owner: "make the users head move but make it follow mouse movements"): up and down too, a neck's
	-- reach, shift lock or not, the turn and the tilt together without tipping the head over
	local function tiltFor(aimDeg, upDeg, on)
		local s = Mix.new()
		local biggest, look, tilt = 0, 0, 0
		for _ = 1, math.floor(0.8 / DT) do
			Mix.step(s, DT, { speed = 0, state = "ground", lengths = lengths })
			local before = tilt
			look, tilt = Mix.look(s, DT, math.rad(aimDeg), on, 0, math.rad(upDeg))
			biggest = math.max(biggest, math.abs(math.deg(tilt - before)))
		end
		local pose = Sampler.sample(A.Idle, 0)
		for _, m in body.motors do m.Transform = pose[m.Part1.Name] or CFrame.identity end
		body.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(body)
		local head0 = body.parts.Head.CFrame
		local hips, w, n = Mix.strafePose(s, 0, {
			root = { C0 = rootJ.C0, C1 = rootJ.C1, T = rootJ.Transform },
			waist = { C0 = waist.C0, C1 = waist.C1, T = waist.Transform },
			neck = { C0 = neck.C0, C1 = neck.C1, T = neck.Transform },
		}, look, tilt)
		rootJ.Transform, waist.Transform, neck.Transform = hips, w, n
		Rig.fk(body)
		local function elevation(cf) return math.deg(math.asin(math.clamp(cf.LookVector.Y, -1, 1))) end
		local want = CFrame.Angles(0, -look, 0) * CFrame.Angles(tilt, 0, 0) * head0.Rotation
		local _, err = (want:Inverse() * body.parts.Head.CFrame.Rotation):ToAxisAngle()
		return { up = elevation(body.parts.Head.CFrame) - elevation(head0), side = yawOf(head0) - yawOf(body.parts.Head.CFrame),
			tilt = math.deg(tilt), err = math.deg(math.abs(err)), biggest = biggest }
	end
	local up = tiltFor(0, 50, true)
	check(math.abs(up.tilt - Lk.Up) < 1 and math.abs(up.up - Lk.Up) < 2 and up.err < 1,
		string.format("the mouse high up: the head tilts up %.0f degrees, its neck's reach (%.0f wanted)", up.up, Lk.Up))
	check(up.biggest <= 12, string.format("no snap: at most %.0f degrees a frame at 30 fps", up.biggest))
	local down = tiltFor(0, -80, false)
	check(math.abs(down.tilt + Lk.Down) < 1 and down.err < 1,
		string.format("the mouse at your feet, shift lock: the head looks down %.0f degrees", -down.tilt))
	local both = tiltFor(-40, 20, true)
	check(math.abs(both.side + 40) < 2 and math.abs(both.tilt - 20) < 1 and both.err < 1,
		string.format("left and up together: turned %.0f, tilted %.0f, no tip (%.2f)", both.side, both.tilt, both.err))
	local behind = tiltFor(175, 40, true)
	check(math.abs(behind.tilt) < 1, "the mouse behind you: the head comes back to the front, not up")

	-- everyone sees it (HuzzServer/HeadLookService): what a screen sends is checked and limited
	local Service = Env.load("huzz-valley/src/ServerScriptService/HuzzServer/HeadLookService.lua")
	local t, u = Service.clean(500, -500)
	check(t == Lk.Max and u == -Lk.Down, "a turn past a neck's reach is clamped")
	check(Service.clean(0 / 0, 1) == nil and Service.clean("x", 1) == nil and Service.clean(1) == nil, "NaN, text and missing numbers are refused")
	local fake, took = {}, 0
	for i = 1, 60 do
		if Service.allow(fake, i / 60) then took += 1 end -- (60 sends in one second)
	end
	check(took <= 10, string.format("a screen spamming 60 a second gets %d through (at most 8 a second, a burst of 2)", took))
	check(Lk.SendRate <= 10 and Lk.SendStep >= 1, "screens send a few times a second, only when the head moved")
end

-- Another player stopping: their legs follow ~0.15 s after their body stops (a still body past a network stall has
-- stopped), not eased out over the whole 0.25 s window.
do
	local tr, s = Mix.tracker(Run.Track), Mix.new()
	local t, x = 0, 0
	for _ = 1, 60 do
		t += 1 / 60
		x += 28 / 60
		Mix.step(s, 1 / 60, { speed = Mix.track(tr, t, Vector3.new(x, 0, 0)), state = "ground", lengths = lengths })
	end
	local zeroAt, idleAt = nil, nil
	for i = 1, 40 do
		t += 1 / 60
		local v = Mix.track(tr, t, Vector3.new(x, 0, 0))
		Mix.step(s, 1 / 60, { speed = v, state = "ground", lengths = lengths })
		if not zeroAt and v < 0.01 then zeroAt = i / 60 end
		if not idleAt and s.weights.Idle > 0.95 then idleAt = i / 60 end
	end
	print(string.format("  another player stops: read as stopped after %.2f s, legs at the idle after %.2f s", zeroAt or -1, idleAt or -1))
	check(zeroAt and zeroAt <= Run.Track.Hold + 0.03 and idleAt and idleAt <= Run.Track.Hold + 0.2,
		"another player's stop shows ~0.15 s after their body stops (was the whole window, ~0.4 s)")
	-- with their replicated velocity at zero too, at once (the legs stop with the body, as HV's)
	local tr2, s2 = Mix.tracker(Run.Track), Mix.new()
	t, x = 0, 0
	for _ = 1, 60 do
		t += 1 / 60
		x += 28 / 60
		Mix.step(s2, 1 / 60, { speed = Mix.track(tr2, t, Vector3.new(x, 0, 0), 28), state = "ground", lengths = lengths })
	end
	local idle2 = nil
	for i = 1, 40 do
		t += 1 / 60
		Mix.step(s2, 1 / 60, { speed = Mix.track(tr2, t, Vector3.new(x, 0, 0), 0), state = "ground", lengths = lengths })
		if not idle2 and s2.weights.Idle > 0.95 then idle2 = i / 60 end
	end
	check(idle2 and idle2 <= 0.2, string.format("and with their velocity at zero, their legs are at the idle in %.2f s (HV ~0.15)", idle2 or -1))
	-- a network stall (not moved, their velocity still saying they run) keeps the run
	local tr3 = Mix.tracker(Run.Track)
	t, x = 0, 0
	for _ = 1, 30 do
		t += 1 / 60
		x += 28 / 60
		Mix.track(tr3, t, Vector3.new(x, 0, 0), 28)
	end
	local held = Mix.track(tr3, t + 0.1, Vector3.new(x, 0, 0), 28)
	check(held > 20, string.format("a 0.1 s stall with their velocity still running keeps the run (%.1f)", held))
end

print(`Locomotion: {passed} ok, {failed} failed`)
if failed > 0 then
	error("Locomotion spec failed")
end
