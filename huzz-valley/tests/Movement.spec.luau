-- lune run tests/Movement.spec.luau
-- Movement and camera feel against Huss Valley's measured numbers (docs/feel-study.md gaps 4 to 9):
--   the huss push is a hard burst (~4x the run, HV's) easing out to a soft hand-back (~0.28 s, ~12 studs, most of it in
--   the first 0.15 s; owner Oct 19 "their huss is way quicker than ours", ready again after 2 s), the lunge keeps its
--   reach, the huss pose leans ~28 degrees into the move over 3 frames (never most of it in one 30 fps frame), drops,
--   holds through the push and is upright by ~0.40 s; the run starts quick with HV's step
--   rate; the cinematic swings go round and over (never through a runner or straight down) and the hand-back frames
--   you like HV (a third of the screen tall, the horizon ~30% from the top).
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Shot = Env.load(SHARED .. "CinematicShot.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local Run = Env.load(SHARED .. "Config/Run.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end
local deg = math.deg

-- The huss push.
local D = Round.Dash
check(D.Time >= 0.24 and D.Time <= 0.32, "the huss pushes for ~0.25-0.3 s")
check(RunMotion.pushSpeed(D, 0) == D.Speed and D.Speed >= 90 and D.Speed <= 140, "it starts with a hard burst, ~4x the run like HV (90-140 studs/s)")
check(D.EndSpeed >= 10 and D.EndSpeed <= 20, "and eases down to 10-20 studs/s, so handing back to the run is soft")
check(D.Cooldown == 2, "ready again after 2 seconds (owner's number)")
local last, smooth = math.huge, true
for i = 0, math.floor(D.Time * 100) - 1 do
	local v = RunMotion.pushSpeed(D, i / 100)
	if not v or v > last + 1e-6 then smooth = false end
	last = v or last
end
check(smooth, "the push speed only ever eases down, every frame (no flat push and cut)")
check(RunMotion.pushSpeed(D, D.Time) == nil, "and it ends at Time")
local dist = RunMotion.pushDistance(D)
check(dist >= 11 and dist <= 13.5, string.format("the huss covers ~12 studs (owner: a bit further than 9, not too much) (%.1f)", dist))
local covered, at80 = 0, nil
for i = 0, 600 do
	local v = RunMotion.pushSpeed(D, i / 2000)
	if not v then break end
	covered += v / 2000
	if not at80 and covered >= 0.8 * dist then at80 = i / 2000 end
end
check(at80 ~= nil and at80 <= 0.18, string.format("quick: 80%% of it is covered in the first 0.18 s (%.2f s; was 0.22)", at80 or -1))
local L = Round.Lunge
local reach = RunMotion.pushDistance(L)
check(reach >= 17 and reach <= 21, string.format("the lunge keeps its old ~20 stud reach (%.1f)", reach))
check(L.HitWindow >= L.Time, "the lunge can hit for the whole leap")
-- The dive's end (owner Oct 20 15:13: "make it straight to the point and without a long unconsiousness"): after the
-- push the belly slides on to a stop (RunMotion.lungeSpeed, no dead stop), and the stun is short.
do
	local tail, prev, jump, last = 0, nil, 0, nil
	for i = 0, 2000 do
		local age = i / 2000
		local v = RunMotion.lungeSpeed(L, age)
		if not v then last = age break end
		if prev then jump = math.max(jump, math.abs(v - prev)) end
		prev = v
		if age >= L.Time then tail += v / 2000 end
	end
	print(string.format("  dive: push %.1f studs, then a belly slide of %.1f studs, stopped at %.2f s; stun %.1f s from %.2f s",
		reach, tail, last or -1, L.Stun, L.StunAfter))
	check(RunMotion.lungeSpeed(L, 0) == L.Speed and math.abs((RunMotion.lungeSpeed(L, L.Time) or -1) - L.EndSpeed) < 1e-6,
		"the dive's push, then the slide goes on from where the push ends (no jump)")
	check(jump < 1.5, "no jolt anywhere in the dive's speed (at most 1.5 studs/s a 2000th)")
	check(tail >= 1.5 and tail <= 3 and last and last <= L.Time + L.Slide + 1e-3, "a short belly slide (1.5 to 3 studs) instead of a dead stop")
	check(L.Stun <= 0.5 and L.StunAfter + L.Stun <= 0.8, "the stun is short: moving again within 0.8 s of the press (it was 2.38 s)")
	check(L.Cooldown >= 2.5, "and Space still waits its cooldown (not spammable)")
end

-- The run start and step rate.
check(Run.StartSpeed >= 14 and Run.StartSpeed <= 18 and Run.Ramp == 1, "the run starts at ~16 and is full after 1 s (owner, Oct 20: \"Make acceleration 1 second long\")")
-- the build-up (Gameplay/Sprint, RunMotion.rampSpeed): exactly 1 s, clearly still building at 0.5 s, no jolt
do
	local cap, start = Round.Speeds.Runner, Run.StartSpeed
	local prev, biggest, rising, lastGain = start, 0, true, 0
	for i = 1, 60 do
		local v = RunMotion.rampSpeed(start, cap, i / 60)
		if v < prev - 1e-9 then rising = false end
		biggest = math.max(biggest, v - prev)
		lastGain = v - prev
		prev = v
	end
	local half = (RunMotion.rampSpeed(start, cap, 0.5) - start) / (cap - start)
	local at90 = nil
	for i = 0, 120 do
		if not at90 and RunMotion.rampSpeed(start, cap, i / 120) >= start + 0.9 * (cap - start) then at90 = i / 120 end
	end
	print(string.format("  build-up 16 to %d: %.0f%% at 0.5 s, 90%% at %.2f s, full at %.2f s; biggest gain a 60 fps frame %.2f, last %.3f",
		cap, half * 100, at90 or -1, Run.Ramp, biggest, lastGain))
	check(RunMotion.rampSpeed(start, cap, 0) == start and math.abs(RunMotion.rampSpeed(start, cap, 1) - cap) < 1e-6
		and RunMotion.rampSpeed(start, cap, 3) == cap, "the build goes from 16 to the top in exactly 1 s, then holds")
	check(rising and biggest < 0.5 and lastGain < 0.01, "only ever up, at most 0.5 studs/s a frame, and settling softly into the top (no jolt)")
	check(half >= 0.65 and half <= 0.8 and at90 and at90 >= 0.6, string.format("clearly still building at 0.5 s (%.0f%%; was ~95%%), 90%% not before 0.6 s", half * 100))
	check(RunMotion.rampSpeed(start, 12, 0.3) == 12, "a top speed under the start (slowed, frozen) is kept as it is")
end

-- the halt (owner, Oct 20 07:55: "after they randomly stop after fully running they move a little forward as a sort
-- of \"hault\" like in the game Huss valley"): only from 90% of the top speed, ~2.3 studs over ~0.25 s, easing down
do
	local H = Run.Halt
	local cap, start = Round.Speeds.Runner, Run.StartSpeed
	check(H and H.From == 0.9, "a halt only from 90% of your top speed or more")
	check(RunMotion.haltFrom(cap, cap, start) and RunMotion.haltFrom(0.9 * cap, cap, start), "letting go at full speed halts")
	check(not RunMotion.haltFrom(0.89 * cap, cap, start), "under 90% it doesn't")
	check(not RunMotion.haltFrom(start, start, start) and not RunMotion.haltFrom(10, 0, start), "frozen or walking: never")
	local lobby = Round.Speeds.Lobby
	check(not RunMotion.haltFrom(RunMotion.rampSpeed(start, lobby, 0.2), lobby, start),
		"a tap in the lobby (0.2 s) never halts")
	check(not RunMotion.haltFrom(RunMotion.rampSpeed(start, cap, 0.3), cap, start), "nor a short dash in a round (0.3 s)")
	local d = RunMotion.pushDistance(RunMotion.haltPush(cap))
	local dMax = RunMotion.pushDistance(RunMotion.haltPush(Round.Speeds.Catcher * (1 + Round.SpeedUp.Max)))
	local dLobby = RunMotion.pushDistance(RunMotion.haltPush(lobby))
	print(string.format("  halt: %.2f studs from a runner's %d over %.2f s (fastest catcher %.2f, lobby %.2f)", d, cap, H.Time, dMax, dLobby))
	check(d >= 1.5 and d <= 2.5, string.format("a runner carries on ~2 studs (%.2f; HV's last 0.28 s ~2.5)", d))
	check(dMax <= 3.01, string.format("never more than 3 studs, even at the fastest (%.2f)", dMax))
	check(H.Time >= 0.2 and H.Time <= 0.35, "over ~0.25-0.3 s")
	local cfg = RunMotion.haltPush(cap)
	local last, down = math.huge, true
	for i = 0, 40 do
		local v = RunMotion.pushSpeed(cfg, i * H.Time / 40)
		if v and v > last + 1e-9 then down = false end
		last = v or last
	end
	check(RunMotion.pushSpeed(cfg, 0) == cap and down and RunMotion.pushSpeed(cfg, H.Time) == nil,
		"it starts at your speed (no jump), only ever slows, and ends at a stand")
end
local steps = 2 * Round.Speeds.Runner / Run.Stride
check(steps >= 4.2 and steps <= 5, string.format("the scripted run and the footsteps step ~4.6 times a second at runner speed (%.2f)", steps))
check(Run.ArmOut <= 12, "arms swing front to back, not out wide")

-- The huss pose on an R15 rig: lean, drop, timing, both sides.
local rig = Rig.r15("H")
rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0) -- facing -Z, right = +X
local rec = RunMotion.new(rig)
check(rec ~= nil, "the huss finds an R15 body")
local function pose(age, side)
	for _, m in rig.motors do m.Transform = CFrame.identity end -- (the animation's pose this frame)
	RunMotion.step(rec, 1 / 60, 0, true, false, age, Vector3.new(side, 0, 0))
	Rig.fk(rig)
	local up = rig.parts.UpperTorso.CFrame.UpVector
	return deg(math.atan2(up.X, up.Y)), rig.parts.Head.CFrame.Position.Y -- (+ = the chest tips to the right)
end
local _, standHead = pose(-1, 1)
local leanR, headR = pose(0.18, 1)
local leanL = pose(0.18, -1)
check(leanR >= 24 and leanR <= 32, string.format("the huss leans ~28 degrees into the move (%.1f)", leanR))
check(-leanL >= 24 and -leanL <= 32, string.format("the same the other way (%.1f)", -leanL))
local drop = (standHead - headR) / (standHead - 0)
check(drop >= 0.08 and drop <= 0.2, string.format("the body drops ~13%% (%.0f%%)", drop * 100))
local frame1 = pose(1 / 30, 1)
check(frame1 >= leanR * 0.1 and frame1 <= leanR * 0.55, string.format("smooth in: one 30 fps frame in it's part way, not most of it (%.1f)", frame1))
local early = pose(0.1, 1)
check(early >= leanR * 0.9, "and fully leaning by the third frame (in by 0.1 s)")
local held = pose(0.24, 1)
check(held >= leanR * 0.9, "it holds the lean through the push")
local late = pose(0.41, 1)
check(math.abs(late) <= leanR * 0.15, string.format("upright again by ~0.40 s (%.1f)", late))
pose(0.6, 1)
local released = true
for _, m in rig.motors do
	if m.Transform ~= CFrame.identity then released = false end
end
check(released, "then every joint is handed back to the run")

-- The cast pose (a power's wind-up, Config/Run.Cast): both hands come up in front of the shoulders, then let go.
local function castAt(age)
	for _, m in rig.motors do m.Transform = CFrame.identity end
	RunMotion.step(rec, 1 / 60, 0, true, false, nil, nil, age, 0.25)
	Rig.fk(rig)
	local p = rig.parts
	return p.RightHand.CFrame.Position, p.LeftHand.CFrame.Position, p.RightUpperArm.CFrame.Position, p.UpperTorso.CFrame.UpVector
end
local rh, lh, shoulder, torsoUp = castAt(0.2)
check(rh.Y > shoulder.Y and lh.Y > shoulder.Y, "the cast raises both hands above the shoulders")
check(rh.Z < shoulder.Z - 0.5 and lh.Z < shoulder.Z - 0.5, "the cast reaches forward (facing -Z)")
local lean = deg(math.atan2(-torsoUp.Z, torsoUp.Y))
check(lean > 5 and lean < 16, string.format("the cast leans ~10 degrees in (%.1f)", lean))
castAt(0.25 + Run.Cast.Out + 0.05)
local castReleased = true
for _, m in rig.motors do
	if m.Transform ~= CFrame.identity then castReleased = false end
end
check(castReleased, "after the wind-up the cast hands every joint back")

-- Cinematic swings: round and over, never through.
local line = CFrame.new(0, 0, 0) -- the runners' line: X along it, -Z the field
local headY = 5.5
local function steepest(fromEye, fromLook, toEye, toLook, minClear, label)
	local worst, low = 0, math.huge
	for i = 0, 100 do
		local e, l = Shot.transition(fromEye, fromLook, toEye, toLook, i / 100, headY)
		local d = (l - e).Unit
		worst = math.max(worst, deg(math.asin(-d.Y)))
		-- over the runners' row (within 1.5 studs of the line, inside its length): how high above the heads
		local p = line:PointToObjectSpace(e)
		if math.abs(p.Z) < 1.5 and math.abs(p.X) < 12 then
			low = math.min(low, e.Y - headY)
		end
	end
	check(worst < 70, string.format("%s never looks straight down (%.0f degrees at most)", label, worst))
	if low < math.huge then
		check(low >= minClear, string.format("%s crosses the row %.1f studs over the heads", label, low))
	end
end
local e0, l0 = Shot.lineup(line, 3, 3)
local e1, l1 = Shot.sweep(line, 12, 0, 2)
steepest(e0, l0, e1, l1, 2, "lineup to the front of the line")
local headCF = CFrame.lookAt(Vector3.new(4, 4.9, 0), Vector3.new(4, 4.9, -1)) -- a runner facing the field (-Z)
headCF = CFrame.lookAt(headCF.Position, headCF.Position + Vector3.new(0, 0, 1)) -- turned to the camera for the pick
local fe, fl = Shot.face(line, headCF, true)
local be, bl = Shot.behind(Vector3.new(0, 0, -1), Vector3.new(4, 3 + Shot.FocusHeight, 0))
steepest(fe, fl, be, bl, 1, "the hand-back")
local near = math.huge
for i = 0, 100 do
	local e = Shot.transition(fe, fl, be, bl, i / 100, headY)
	near = math.min(near, (e - headCF.Position).Magnitude)
end
check(near >= 3, string.format("the hand-back stays clear of your head (%.1f studs at the closest)", near))
local s0, s1 = Shot.transition(fe, fl, be, bl, 0, headY), Shot.transition(fe, fl, be, bl, 1, headY)
check((s0 - fe).Magnitude < 1e-3 and (s1 - be).Magnitude < 1e-3, "a swing starts and lands exactly on its shots")
check(Shot.TransitionTime >= 0.2 and Shot.TransitionTime <= 0.3, "shot changes are one 0.2-0.3 s swing")

-- The round camera: HV's framing.
local focus = Vector3.new(0, 3 + Shot.FocusHeight, 0)
local eye, look = Shot.behind(Vector3.new(0, 0, -1), focus)
check(math.abs((eye - focus).Magnitude - Shot.RoundZoom) < 1e-3, "Roblox's camera takes over at exactly RoundZoom")
local tan35 = math.tan(math.rad(35)) -- (half of the default 70 degree field of view)
local pitch = math.asin(-(look - eye).Unit.Y)
local horizon = 0.5 - 0.5 * math.tan(pitch) / tan35
check(horizon >= 0.27 and horizon <= 0.36, string.format("the horizon sits ~30%% from the top (%.0f%%)", horizon * 100))
local tall = 5.2 / (2 * Shot.RoundZoom * tan35)
check(tall >= 0.28 and tall <= 0.36, string.format("you're about a third of the screen tall (%.0f%%)", tall * 100))
check(Shot.RoundMaxZoom >= 18 and Shot.RoundMaxZoom <= 24, "zooming out is capped ~22 in a round")

print(string.format("  huss %.1f studs in %.2f s, lean %.1f deg, drop %.0f%%; lunge %.1f studs; round camera: horizon %.0f%% from the top, you %.0f%% tall", dist, D.Time, leanR, drop * 100, reach, horizon * 100, tall * 100))
print(string.format("Movement: %d ok, %d failed", passed, failed))
if failed > 0 then
	error("Movement spec failed")
end
