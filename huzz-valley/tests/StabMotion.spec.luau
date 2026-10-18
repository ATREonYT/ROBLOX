-- lune run tests/StabMotion.spec.luau
-- The catcher's slash (Shared/StabMotion) on an R15 rig, as Huss Valley's (docs/knife-study.md): no wind-up, the
-- knife arm sweeps out to the right and lands in ~0.07 s, holds out to the side, is back by 0.40 s; the lunge adds
-- a dive into the leap's direction; every joint goes back to the animation after.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local StabMotion = Env.load(SHARED .. "StabMotion.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local rig = Rig.r15("C")
rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0) -- facing -Z
local rec = StabMotion.new(CarryMath.rig(rig), rig.root)
check(rec.neck ~= nil, "the head joint is found (eyes stay on the target)")
local T = Round.Stab.Time
check(math.abs(T - 0.40) < 0.021, "the slash lasts about 0.40 s (HV)")

local function poseAt(seconds, lunge, dir)
	for _, m in rig.motors do m.Transform = CFrame.identity end -- (the animation's pose this frame)
	StabMotion.play(rec, 0, lunge)
	if dir then StabMotion.setDive(rec, dir) end
	StabMotion.step(rec, seconds)
	Rig.fk(rig)
	local chest = rig.parts.UpperTorso.CFrame.Position
	return {
		hand = rig.parts.RightHand.CFrame.Position - chest,
		look = rig.parts.Head.CFrame.LookVector,
		chestUp = rig.parts.UpperTorso.CFrame.UpVector,
		chestLook = rig.parts.UpperTorso.CFrame.LookVector,
		free = rig.parts.LeftHand.CFrame.Position - chest,
	}
end
local rest = poseAt(-1)
local reach, hold = poseAt(T * 0.18), poseAt(T * 0.5)
print(string.format("  hand at reach: right %.2f, forward %.2f, up %.2f; held: right %.2f, forward %.2f", reach.hand.X, -reach.hand.Z, reach.hand.Y, hold.hand.X, -hold.hand.Z))
-- No wind-up: the hand never pulls back behind where it hangs.
local minForward = math.huge
for i = 0, 40 do
	minForward = math.min(minForward, -poseAt(T * 0.18 * i / 40).hand.Z)
end
check(minForward > -rest.hand.Z - 0.15, "no wind-up: the knife hand never coils back")
check(reach.hand.X > 1.5, "the sweep goes out to the right")
check(reach.hand.Y > -0.9, "the sweep comes up to about level (not low at the hip)")
check(hold.hand.X > 1.8 and -hold.hand.Z < 0.8, "held out to the side, a little back")
check(-reach.free.Z > 1.0, "the free arm points ahead at the runner")
check(reach.look.Z < -0.9 and hold.look.Z < -0.9, "the head keeps looking ahead while the waist turns")
-- Fast: out to the side (more than 1.5 studs right) within 0.08 s of the start.
local outAt
for i = 0, 200 do
	local s = T * i / 200
	if poseAt(s).hand.X > 1.5 then outAt = s break end
end
check(outAt ~= nil and outAt <= 0.08, string.format("the sweep lands in ~0.07 s (%.3f s)", outAt or 99))
check(StabMotion.trailOn(rec, 0.05) and not StabMotion.trailOn(rec, T * 0.9), "trail on during the sweep, off before the end")

-- Over a hunched run (hips tipped 20°, waist bent 20° more, as the pack's Sprint), the arm still sweeps about level.
do
	local function hunched()
		for _, m in rig.motors do m.Transform = CFrame.identity end
		rig.parts.LowerTorso.joints.Root.Transform = CFrame.Angles(math.rad(-20), 0, 0)
		rig.parts.UpperTorso.joints.Waist.Transform = CFrame.Angles(math.rad(-20), 0, 0)
	end
	StabMotion.play(rec, 0)
	hunched(); StabMotion.step(rec, T * 0.2); Rig.fk(rig)
	hunched(); StabMotion.step(rec, T * 0.25); Rig.fk(rig)
	local shoulder = rig.parts.RightUpperArm.CFrame.Position
	local hand = rig.parts.RightHand.CFrame.Position
	local dir = (hand - shoulder).Unit
	print(string.format("  hunched sweep: arm points %.0f° below level", math.deg(math.asin(-dir.Y))))
	check(dir.Y > -0.45, "hunched run: the knife arm still sweeps out, not at the ground")
end

-- The lunge's dive: the chest tips 35° into the leap, forward or sideways, then comes back up.
do
	local D = StabMotion.DIVE
	local fwd = poseAt((D.Full + D.Hold) / 2, true, Vector3.new(0, 0, -1))
	local right = poseAt((D.Full + D.Hold) / 2, true, Vector3.new(1, 0, 0))
	local upAgain = poseAt(D.Up + 0.01, true, Vector3.new(1, 0, 0))
	local tipF = math.deg(math.acos(math.clamp(fwd.chestUp.Y, -1, 1)))
	print(string.format("  dive: forward tips %.0f° (chest up z %.2f), sideways chest up x %.2f", tipF, fwd.chestUp.Z, right.chestUp.X))
	check(fwd.chestUp.Z < -0.4, "a forward leap dives forward")
	check(right.chestUp.X > 0.4, "a sideways leap tips into its side")
	check(upAgain.chestUp.Y > 0.99, "up again after the dive")
	check(StabMotion.diveAt(0.1) == 0, "no dive at take-off (the sweep comes first)")
end

-- Afterwards every joint is the animation's again.
StabMotion.play(rec, 0)
StabMotion.step(rec, T * 0.5)
StabMotion.step(rec, T + 0.02) -- (the frame it ends: release)
check(next(rec.written) == nil, "released when it ends")
for _, m in rig.motors do m.Transform = CFrame.new(0, 0.01, 0) end -- (the next frame's animation)
StabMotion.step(rec, T + 0.05)
local clean = true
for _, m in rig.motors do
	if (m.Transform.Position - Vector3.new(0, 0.01, 0)).Magnitude > 1e-4 then clean = false end
end
check(clean, "after the slash, the joints are handed back to the animation")
check(not StabMotion.trailOn(rec, T + 0.05), "trail off after")

print(`StabMotion: {passed} ok, {failed} failed`)
if failed > 0 then error("StabMotion spec failed") end
