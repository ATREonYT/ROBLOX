-- lune run tests/StabMotion.spec.luau
-- The catcher's stab (Shared/StabMotion) on an R15 rig: it coils back, thrusts the knife hand well forward with
-- the right shoulder turning into it, holds, comes back, and hands every joint back to the animation after.
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
check(T >= 0.35 and T <= 0.5, "the stab lasts about 0.4 s")

local function poseAt(seconds)
	for _, m in rig.motors do m.Transform = CFrame.identity end -- (the animation's pose this frame)
	StabMotion.play(rec, 0)
	StabMotion.step(rec, seconds)
	Rig.fk(rig)
	local chest = rig.parts.UpperTorso.CFrame.Position
	return {
		hand = rig.parts.RightHand.CFrame.Position - chest,
		shoulder = rig.parts.RightUpperArm.CFrame.Position - chest,
		look = rig.parts.Head.CFrame.LookVector,
	}
end
local coil, thrust, hold = poseAt(T * 0.26), poseAt(T * 0.405), poseAt(T * 0.6)
print(string.format("  hand forward: coil %.2f, thrust %.2f, hold %.2f studs", -coil.hand.Z, -thrust.hand.Z, -hold.hand.Z))
check(-coil.hand.Z < 0.3, "coiled: the knife hand is pulled back by the body")
check(-thrust.hand.Z > 2.2, "thrust: the knife hand is far out in front")
check(-hold.hand.Z > 2, "the hit holds the reach")
check(thrust.shoulder.Z < coil.shoulder.Z - 0.3, "the right shoulder turns forward into the thrust")
check(math.abs(thrust.hand.Y) < 1, "the thrust goes straight out at chest height")
check(thrust.look.Z < -0.9 and coil.look.Z < -0.9, "the head keeps looking ahead while the body turns")

-- The thrust is the fastest part: the hand travels from the coil to full reach in under 0.08 s.
local reachAt
for i = 0, 200 do
	local s = T * i / 200
	if -poseAt(s).hand.Z > 2.2 then reachAt = s break end
end
check(reachAt ~= nil and reachAt - T * 0.26 < 0.08, string.format("snappy thrust (%.3f s from coil to reach)", (reachAt or 99) - T * 0.26))

-- Over a hunched run (hips tipped 20°, waist bent 20° more, as the pack's Sprint), the thrust still goes
-- straight ahead, not at the ground. (Two frames: the hips' tilt is read from the parts, as in the game.)
do
	local function hunched()
		for _, m in rig.motors do m.Transform = CFrame.identity end
		rig.parts.LowerTorso.joints.Root.Transform = CFrame.Angles(math.rad(-20), 0, 0)
		rig.parts.UpperTorso.joints.Waist.Transform = CFrame.Angles(math.rad(-20), 0, 0)
	end
	StabMotion.play(rec, 0)
	hunched(); StabMotion.step(rec, T * 0.39); Rig.fk(rig)
	hunched(); StabMotion.step(rec, T * 0.405); Rig.fk(rig)
	local shoulder = rig.parts.RightUpperArm.CFrame.Position
	local hand = rig.parts.RightHand.CFrame.Position
	local dir = (hand - shoulder).Unit
	print(string.format("  hunched thrust: arm points %.0f° below level", math.deg(math.asin(-dir.Y))))
	check(dir.Y > -0.35, "hunched run: the knife arm still points ahead, not at the ground")
end

-- Afterwards every joint is the animation's again.
StabMotion.step(rec, T + 0.02) -- (the frame it ends: release)
check(next(rec.written) == nil, "released when it ends")
for _, m in rig.motors do m.Transform = CFrame.new(0, 0.01, 0) end -- (the next frame's animation)
StabMotion.step(rec, T + 0.05)
local clean = true
for _, m in rig.motors do
	if (m.Transform.Position - Vector3.new(0, 0.01, 0)).Magnitude > 1e-4 then clean = false end
end
check(clean, "after the stab, the joints are handed back to the animation")
check(not StabMotion.trailOn(rec, T + 0.05), "trail off after")

print(`StabMotion: {passed} ok, {failed} failed`)
if failed > 0 then error("StabMotion spec failed") end
