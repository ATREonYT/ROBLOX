-- lune run tests/Movement.spec.luau
-- Movement and camera feel against Huss Valley's measured numbers (docs/feel-study.md gaps 4 to 9):
--   the huss push eases from a burst to a glide (~0.30 s, ~10 studs), the lunge keeps its reach, the huss pose leans
--   ~28 degrees into the move, drops, holds to 0.30 s and is upright by ~0.40 s; the run starts quick with HV's step
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
check(D.Time >= 0.28 and D.Time <= 0.32, "the huss pushes for ~0.30 s")
check(RunMotion.pushSpeed(D, 0) == D.Speed and D.Speed >= 40 and D.Speed <= 55, "it starts with a burst (~45-50 studs/s)")
check(D.EndSpeed >= 15 and D.EndSpeed <= 25, "and eases down to ~20 studs/s")
local last, smooth = math.huge, true
for i = 0, 29 do
	local v = RunMotion.pushSpeed(D, i / 100)
	if not v or v > last + 1e-6 then smooth = false end
	last = v or last
end
check(smooth, "the push speed only ever eases down, every frame (no flat push and cut)")
check(RunMotion.pushSpeed(D, D.Time) == nil, "and it ends at Time")
local dist = RunMotion.pushDistance(D)
check(dist >= 8 and dist <= 11, string.format("the huss covers ~10 studs (%.1f)", dist))
local L = Round.Lunge
local reach = RunMotion.pushDistance(L)
check(reach >= 17 and reach <= 21, string.format("the lunge keeps its old ~20 stud reach (%.1f)", reach))
check(L.HitWindow >= L.Time, "the lunge can hit for the whole leap")

-- The run start and step rate.
check(Run.StartSpeed >= 14 and Run.StartSpeed <= 18 and Run.Ramp >= 0.4 and Run.Ramp <= 0.6, "the run starts at ~16 and is full in ~0.5 s")
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
local early = pose(0.05, 1)
check(early >= leanR * 0.9, "it's leaning from the first frames (in by 0.05 s)")
local held = pose(0.29, 1)
check(held >= leanR * 0.9, "it holds the lean to 0.30 s")
local late = pose(0.41, 1)
check(math.abs(late) <= leanR * 0.15, string.format("upright again by ~0.40 s (%.1f)", late))
pose(0.6, 1)
local released = true
for _, m in rig.motors do
	if m.Transform ~= CFrame.identity then released = false end
end
check(released, "then every joint is handed back to the run")

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
