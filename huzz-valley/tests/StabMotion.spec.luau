-- lune run tests/StabMotion.spec.luau
-- The catcher's slash (Shared/StabMotion) on an R15 rig, as Huss Valley's (docs/knife-study.md): no wind-up, the
-- knife arm sweeps out to the right and lands in ~0.07 s, holds out to the side, is back by 0.40 s; the lunge is a
-- whole-body leap (below); every joint goes back to the animation after.
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

-- The lunge (knife pass 2, Oct 19: "make them have good animations, the leaping, the killing"): the whole body
-- leaps. It leans into the leap from take-off (never back: no wind-up), the legs leave the run (lead knee up, back
-- leg long behind), the knife leads ahead and level until it reaches someone, then sweeps out to the right in
-- ~0.07 s; it lands low (tipped ~34° into the leap) with the feet on the floor, sideways leaps into their side,
-- smooth at 30 and 60 fps, and gives every joint back by LEAP.Up.
do
	local L = StabMotion.LEAP
	local air = StabMotion.air()
	print(string.format("  leap: %.3f s in the air (Lunge.Up %d)", air, Round.Lunge.Up))
	check(air >= 0.22 and air <= 0.3, "the hop lasts long enough to show a leap (0.22 to 0.3 s)")
	local function lowestFoot()
		local y = math.huge
		for _, n in { "LeftFoot", "RightFoot" } do
			local c, h = rig.parts[n].CFrame, rig.parts[n].Size / 2
			local reach = math.abs(c.RightVector.Y) * h.X + math.abs(c.UpVector.Y) * h.Y + math.abs(c.LookVector.Y) * h.Z
			y = math.min(y, c.Position.Y - reach)
		end
		return y
	end
	-- t seconds into a leap along dir (body space); hitAt: when the knife reached someone (nil = no one)
	local function leapPose(t, dir, hitAt)
		for _, m in rig.motors do m.Transform = CFrame.identity end
		StabMotion.play(rec, 0, true)
		StabMotion.setDive(rec, dir or Vector3.new(0, 0, -1))
		if hitAt and hitAt <= t then
			StabMotion.step(rec, hitAt) -- (the frame it reached them)
			for _, m in rig.motors do m.Transform = CFrame.identity end
			StabMotion.slash(rec, hitAt)
		end
		StabMotion.step(rec, t)
		Rig.fk(rig)
		local chest = rig.parts.UpperTorso.CFrame.Position
		local hand = rig.parts.RightHand.CFrame
		local blade = (hand * CFrame.Angles(math.rad(-150), 0, 0)).UpVector -- (KnifeLook.handC0: the knife's way)
		return {
			hand = hand.Position - chest, blade = blade,
			chestUp = rig.parts.UpperTorso.CFrame.UpVector, pelvisUp = rig.parts.LowerTorso.CFrame.UpVector,
			low = lowestFoot(), lknee = rig.parts.LeftLowerLeg.CFrame.Position, rknee = rig.parts.RightLowerLeg.CFrame.Position,
			lfoot = rig.parts.LeftFoot.CFrame.Position, rfoot = rig.parts.RightFoot.CFrame.Position,
		}
	end
	local standLow = (function() for _, m in rig.motors do m.Transform = CFrame.identity end Rig.fk(rig) return lowestFoot() end)()
	-- take-off: leaning in at once, never back
	local backMost = 0
	for i = 0, 30 do
		local q = leapPose(L.Up * i / 30)
		backMost = math.max(backMost, q.pelvisUp.Z)
	end
	check(backMost < 0.02, "no wind-up: the body never leans back during the leap")
	local launch = leapPose(0.08)
	local tipLaunch = math.deg(math.asin(math.clamp(-launch.pelvisUp.Z, -1, 1)))
	print(string.format("  take-off (0.08 s): body tipped %.0f° in; knee ahead %.2f; back foot behind %.2f", tipLaunch, -(launch.lknee.Z), launch.rfoot.Z))
	check(tipLaunch > 12, "the body lines up into the leap from take-off")
	check(-launch.lknee.Z > 0.25 and launch.rfoot.Z > 1.2, "the legs leave the run: lead knee ahead, back leg long behind")
	-- the knife leads, ahead and level, blade forward, until it reaches someone
	local flying = leapPose(0.1)
	print(string.format("  in the air (0.10 s): hand ahead %.2f, up %.2f; blade forward %.2f", -flying.hand.Z, flying.hand.Y, -flying.blade.Z))
	check(-flying.hand.Z > 1.2 and math.abs(flying.hand.X) < 1.2, "the knife hand leads, ahead of the chest")
	check(-flying.blade.Z > 0.75, "the blade points ahead (it leads the leap)")
	-- the slash the moment it reaches someone: out to the right within 0.08 s
	local outAt
	for i = 0, 60 do
		local dt = 0.12 * i / 60
		if leapPose(0.05 + dt, nil, 0.05).hand.X > 1.5 then outAt = dt break end
	end
	check(outAt ~= nil and outAt <= 0.08, string.format("reaching someone at 0.05 s, the slash lands in %.3f s", outAt or 99))
	check(not StabMotion.trailOn(rec, 0) or false, "no slash trail before the slash")
	do -- reaching no one: the slash anyway at SlashBy
		StabMotion.play(rec, 0, true)
		check(StabMotion.slashStart(rec, L.SlashBy - 0.01) == nil and StabMotion.slashStart(rec, L.SlashBy + 0.01) ~= nil,
			"reaching no one, the slash comes at LEAP.SlashBy")
		check(L.SlashBy + 0.07 < air, "and lands before the feet touch down")
	end
	-- landing low, feet on the floor
	local land = leapPose(air + 0.12)
	local tipLand = math.deg(math.acos(math.clamp(land.chestUp.Y, -1, 1)))
	print(string.format("  landing (%.2f s): chest tipped %.0f°, lowest foot %.2f (standing %.2f)", air + 0.12, tipLand, land.low, standLow))
	check(land.chestUp.Z < -0.4 and tipLand > 28, "lands low, tipped into the leap")
	check(math.abs(land.low - standLow) < 0.12, "the hips come down on landing: the feet stay on the floor, not floating or under it")
	local midAir = leapPose(air * 0.6)
	check(midAir.low > standLow - 0.05, "nothing goes under the floor in the air")
	-- sideways (D): tips right, the right leg leads out to the side
	local right = leapPose(air + 0.12, Vector3.new(1, 0, 0))
	local rightLaunch = leapPose(0.08, Vector3.new(1, 0, 0))
	print(string.format("  sideways: chest up x %.2f; right knee out %.2f", right.chestUp.X, rightLaunch.rknee.X))
	check(right.chestUp.X > 0.4, "a sideways leap tips into its side")
	check(rightLaunch.rknee.X > 1.0, "a sideways leap leads with that side's leg")
	-- smooth: the body (hips, chest, legs) turns at most 16° a frame at 60 fps, and no frame pops at 30 fps
	local function frames(fps)
		local worst, prev = 0, nil
		for f = 0, math.ceil((L.Up + 0.05) * fps) do
			leapPose(f / fps, nil, 0.06)
			local now = {}
			for _, n in { "LowerTorso", "UpperTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Head" } do
				now[n] = rig.parts[n].CFrame
			end
			if prev then
				for n, cf in now do
					local d = prev[n].Rotation:Inverse() * cf.Rotation
					local _, ang = d:ToAxisAngle()
					worst = math.max(worst, math.deg(math.abs(ang)))
				end
			end
			prev = now
		end
		return worst
	end
	local w60, w30 = frames(60), frames(30)
	print(string.format("  smoothness: body turns at most %.1f°/frame at 60 fps, %.1f° at 30 fps", w60, w30))
	check(w60 < 16, "smooth at 60 fps (no body part turns more than 16° in a frame)")
	check(w30 < 30, "smooth at 30 fps (no body part turns more than 30° in a frame)")
	-- handed back after the leap
	StabMotion.play(rec, 0, true)
	StabMotion.slash(rec, 0.06)
	for f = 0, 50 do
		for _, m in rig.motors do m.Transform = CFrame.identity end
		StabMotion.step(rec, f * 0.02)
	end
	for _, m in rig.motors do m.Transform = CFrame.new(0, 0.01, 0) end
	StabMotion.step(rec, L.Up + 0.3)
	local clean = true
	for _, m in rig.motors do
		if (m.Transform.Position - Vector3.new(0, 0.01, 0)).Magnitude > 1e-4 then clean = false end
	end
	check(clean, "after the leap, every joint (legs and root too) is the animation's again")
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
