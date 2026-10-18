-- lune run tests/Locomotion.spec.luau
-- Everyone's walk and run (Shared/LocomotionMix with Config/Run.Loco and .Track; owner, Oct 18: "player to player
-- less choppy", "make the walking animations way way better"):
--   - the walk and run speeds in the config are the pack's own (measured on a standard R15 body), so the feet plant;
--   - at every walking speed and up to the 16 studs/s you set off at, the planted foot slides less than 12%;
--   - walk and run step at nearly the same rate where they swap (no pop); a runner's 28 is ~4.6 steps/s (HV);
--   - another player's speed read from jittery, bursty network positions stays smooth and right, a teleport
--     doesn't spike it, a network stall doesn't drop it, a real stop does;
--   - the stride phase never jumps or runs backwards, whatever the speed does;
--   - holding W (16 to 28 in ~0.5 s) never makes the blend jump; a bigger avatar takes longer steps.
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

-- Holding W from standing (Gameplay/Sprint: off at 16, 28 in ~0.5 s): a run within ~0.1 s like HV (stand to full
-- run pose in ~0.1 s on their 30 fps frames), never a one-frame snap; then a sudden stop eases back to the idle.
do
	local s3 = Mix.new()
	local speed, prev = 0, nil
	local runAt, idleAt, biggestStop = nil, nil, 0
	for i = 1, 150 do
		local target = if i <= 90 then Round.Speeds.Runner else 0
		if i == 1 then speed = Run.StartSpeed end
		speed = if target == 0 then 0 else speed + (target - speed) * (1 - math.exp(-(1 / 60) / (Run.Ramp / 3)))
		Mix.step(s3, 1 / 60, { speed = speed, state = "ground", lengths = lengths })
		local w = s3.weights
		if not runAt and w.Run > 0.95 then runAt = i / 60 end
		if i > 90 then
			if not idleAt and w.Idle > 0.95 then idleAt = (i - 90) / 60 end
			biggestStop = math.max(biggestStop, math.abs(w.Walk - prev.Walk), math.abs(w.Run - prev.Run), math.abs(w.Idle - prev.Idle))
		end
		prev = table.clone(w)
	end
	check(runAt and runAt >= 0.06 and runAt <= 0.25, string.format("setting off: a full run after %.2f s (HV ~0.1 s)", runAt or -1))
	check(idleAt and idleAt >= 0.1 and idleAt <= 0.5 and biggestStop < 0.4,
		string.format("a sudden stop eases to the idle in %.2f s (biggest change in a frame %.2f)", idleAt or -1, biggestStop))
end

print(`Locomotion: {passed} ok, {failed} failed`)
if failed > 0 then
	error("Locomotion spec failed")
end
