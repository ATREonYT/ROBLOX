-- lune run tests/StabMotion.spec.luau
-- The catcher's slash (Shared/StabMotion) on an R15 rig, as Huss Valley's (docs/knife-study.md): no wind-up, the
-- knife arm sweeps out to the right and lands in ~0.07 s, holds out to the side, is back by 0.40 s; Space is a
-- whole-body dive with a stun on the floor (below); every joint goes back to the animation after.
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

-- The dive (owner, Oct 19: "add a dive feature for the tagger and after they use it they are stunned for 2 seconds";
-- it was a leap landing in a low lunge). It tips into the dive from take-off (never back: no wind-up), the legs
-- stretch out behind, both arms reach ahead with the knife leading until it reaches someone, then it sweeps out to
-- the right in ~0.07 s; a quick crouch, then a straight dive; the body lands flat on its belly (chest and legs on the
-- floor, nothing under it), slides, and pops straight back up by LEAP.Up as the short stun ends (owner Oct 20 15:13:
-- "make it straight to the point and without a long unconsiousness"); sideways dives go into their side; smooth at
-- 30 and 60 fps; every joint handed back after.
do
	local L = StabMotion.LEAP
	local air = StabMotion.air()
	local stunEnd = (Round.Lunge.StunAfter or Round.Lunge.Time) + (Round.Lunge.Stun or 0)
	print(string.format("  dive: %.3f s in the air (Lunge.Up %d), sliding until %.2f s, up by %.2f s (stun ends %.2f s, %.2f s on the floor)",
		air, Round.Lunge.Up, L.Out, L.Up, stunEnd, L.Up - air))
	check(air >= 0.22 and air <= 0.3, "the hop lasts long enough to show a dive (0.22 to 0.3 s)")
	check(L.Up <= 0.85, "running again within 0.85 s of the press (it was 2.83 s, 2 s of it lying dazed)")
	check(L.Up - air >= 0.4 and L.Up - air <= 0.7, "on the floor 0.4 to 0.7 s: a slide and a pop up, not knocked out")
	check(Round.Lunge.Stun <= 0.5 and math.abs(L.Up - stunEnd) <= 0.05, "the stun (no moving) ends as the body stands")
	check(L.Up - L.Out >= 0.3 and L.Up - L.Out <= 0.6, "and gets up in 0.3 to 0.6 s")
	check(Round.Lunge.Cooldown >= 2.5, "still not spammable: Space waits its cooldown")
	local function lowest(names)
		local y = math.huge
		for _, n in names do
			local c, h = rig.parts[n].CFrame, rig.parts[n].Size / 2
			local reach = math.abs(c.RightVector.Y) * h.X + math.abs(c.UpVector.Y) * h.Y + math.abs(c.LookVector.Y) * h.Z
			y = math.min(y, c.Position.Y - reach)
		end
		return y
	end
	local FEET = { "LeftFoot", "RightFoot" }
	local BODY = { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg", "LowerTorso", "UpperTorso" }
	-- t seconds into a dive along dir (body space); hitAt: when the knife reached someone (nil = no one)
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
			hand = hand.Position - chest, blade = blade, offHand = rig.parts.LeftHand.CFrame.Position - chest,
			chestUp = rig.parts.UpperTorso.CFrame.UpVector, pelvisUp = rig.parts.LowerTorso.CFrame.UpVector,
			low = lowest(FEET), body = lowest(BODY), chestY = chest.Y, hipsY = rig.parts.LowerTorso.CFrame.Position.Y,
			lfoot = rig.parts.LeftFoot.CFrame.Position, rfoot = rig.parts.RightFoot.CFrame.Position,
		}
	end
	local standLow = (function() for _, m in rig.motors do m.Transform = CFrame.identity end Rig.fk(rig) return lowest(FEET) end)()
	-- take-off: tipping in at once, never back
	local backMost = 0
	for i = 0, 60 do
		local q = leapPose(L.Up * i / 60)
		backMost = math.max(backMost, q.pelvisUp.Z)
	end
	check(backMost < 0.02, "no wind-up: the body never leans back during the dive")
	local standHips = (function() for _, m in rig.motors do m.Transform = CFrame.identity end Rig.fk(rig) return rig.parts.LowerTorso.CFrame.Position.Y end)()
	local crouch = leapPose(0.07)
	print(string.format("  crouch (0.07 s): hips %.2f lower, feet on the floor %.2f", standHips - crouch.hipsY, crouch.low - standLow))
	check(standHips - crouch.hipsY > 0.2 and math.abs(crouch.low - standLow) < 0.1, "a quick crouch first: knees bend and the hips come down to the feet (as the hop lifts off)")
	local launch = leapPose(0.16)
	local tipLaunch = math.deg(math.asin(math.clamp(-launch.pelvisUp.Z, -1, 1)))
	print(string.format("  the spring (0.16 s): body tipped %.0f° in; feet behind %.2f / %.2f", tipLaunch, launch.lfoot.Z, launch.rfoot.Z))
	check(tipLaunch > 50, "then the body springs into the dive")
	check(launch.rfoot.Z > 1.0 and launch.lfoot.Z > 1.0, "the legs push off and stretch out behind, together (one straight line)")
	-- both arms reach ahead, the knife leading, until it reaches someone
	local flyAt = math.min(L.ArmIn, L.SlashBy) - 0.01 -- (the reach takes ArmIn: Oct 19 evening, evenly, so no arm turns faster than a running leg)
	local flying = leapPose(flyAt)
	print(string.format("  in the air (%.2f s): hand ahead %.2f, up %.2f, side %.2f; free hand ahead %.2f; blade forward %.2f",
		flyAt, -flying.hand.Z, flying.hand.Y, flying.hand.X, -flying.offHand.Z, -flying.blade.Z))
	check(-flying.hand.Z > 1.2 and math.abs(flying.hand.X) < 1.2, "the knife hand leads, ahead of the chest")
	check(-flying.offHand.Z > 1.0, "the free arm reaches ahead too (a dive, not a lunge)")
	check(-flying.blade.Z > 0.6, "the blade points ahead (it leads the dive)")
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
		check(L.SlashBy + 0.07 < air, "and lands before the body touches down")
	end
	-- flat on the belly: chest tipped near 90°, the body's lowest point on the floor (not floating, not under it)
	for _, at in { air + 0.08, L.Out - 0.05 } do
		local land = leapPose(at)
		local tip = math.deg(math.acos(math.clamp(land.chestUp.Y, -1, 1)))
		print(string.format("  lying (%.2f s): chest tipped %.0f°, lowest point %.2f (floor %.2f), chest %.2f above it",
			at, tip, land.body, standLow, land.chestY - standLow))
		check(land.chestUp.Z < -0.8 and tip > 75 and tip < 100, string.format("at %.2f s the body lies flat on its belly", at))
		check(math.abs(land.body - standLow) < 0.15, string.format("at %.2f s it lies on the floor, not floating or under it", at))
		check(land.chestY - standLow < 1.2, string.format("at %.2f s the chest is down on the floor", at))
	end
	local midAir = leapPose(air * 0.6)
	check(midAir.body > standLow - 0.05, "nothing goes under the floor in the air")
	-- the pop up: hands under the shoulders, knees under, never lying still, nothing under the floor
	local pop = leapPose(L.Out + 0.14)
	local popTip = math.deg(math.acos(math.clamp(pop.chestUp.Y, -1, 1)))
	print(string.format("  pop up (%.2f s): chest tipped %.0f°, lowest point %.2f (floor %.2f)", L.Out + 0.14, popTip, pop.body, standLow))
	check(popTip > 30 and popTip < 75, "popping up: the chest comes up off the floor at once")
	check(math.abs(pop.body - standLow) < 0.2, "and the body stays on the floor while it does (not floating, not under it)")
	local stillest = math.huge
	for i = 0, 7 do
		local a, b = leapPose(L.Out + i * 0.05), leapPose(L.Out + (i + 1) * 0.05)
		local turn = math.deg(math.acos(math.clamp(a.chestUp:Dot(b.chestUp), -1, 1)))
		stillest = math.min(stillest, turn)
	end
	print(string.format("  after the slide the chest keeps moving: at least %.1f° every 0.05 s", stillest))
	check(stillest > 1, "no lying still after the slide (it was 2 s lying dazed)")
	-- standing again after Up
	local up = leapPose(L.Up + 0.02)
	check(up.chestUp.Y > 0.99, "standing up again by LEAP.Up")
	-- sideways (D): tips right
	local right = leapPose(air + 0.15, Vector3.new(1, 0, 0))
	print(string.format("  sideways: chest up x %.2f", right.chestUp.X))
	check(right.chestUp.X > 0.6, "a sideways dive goes into its side")
	-- smooth: the body (hips, chest, legs, head) turns at most 24° a frame at 60 fps and 42° at 30 fps: the crouch, the
	-- spring and the pop up are quick on purpose (Oct 20: "make it concrete"), still well under the run's own legs
	-- (~66° a frame at 30 fps, motion3d/move_smooth_measure.luau); the old slow dive was 14.6° / 30°
	local function frames(fps)
		local worst, prev, where = 0, nil, ""
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
					if math.deg(math.abs(ang)) > worst then
						worst, where = math.deg(math.abs(ang)), string.format("%s at %.2f s", n, f / fps)
					end
				end
			end
			prev = now
		end
		return worst, where
	end
	local w60, at60 = frames(60)
	local w30, at30 = frames(30)
	print(string.format("  smoothness: body turns at most %.1f°/frame at 60 fps (%s), %.1f° at 30 fps (%s)", w60, at60, w30, at30))
	check(w60 < 24, "smooth at 60 fps (no body part turns more than 24° in a frame)")
	check(w30 < 42, "smooth at 30 fps (no body part turns more than 42° in a frame)")
	-- handed back after the dive
	StabMotion.play(rec, 0, true)
	StabMotion.slash(rec, 0.06)
	for f = 0, math.ceil((L.Up + 0.1) / 0.02) do
		for _, m in rig.motors do m.Transform = CFrame.identity end
		StabMotion.step(rec, f * 0.02)
	end
	for _, m in rig.motors do m.Transform = CFrame.new(0, 0.01, 0) end
	StabMotion.step(rec, L.Up + 0.3)
	local clean = true
	for _, m in rig.motors do
		if (m.Transform.Position - Vector3.new(0, 0.01, 0)).Magnitude > 1e-4 then clean = false end
	end
	check(clean, "after the dive, every joint (legs and root too) is the animation's again")
	-- the arms over a running animation at 30 fps (Oct 19 evening, a fresh critic: the hand turned 173° in one frame
	-- at take-off, 113° at the slash and 100° while getting up, a CFrame Lerp near 180° flipping the long way round):
	-- with the run's arms swinging ±60° under it, no arm part turns more in a frame than a leg does in the run (~67°)
	local function armWorst(hitAt, phase)
		StabMotion.play(rec, 0, true)
		local worst, where, prev = 0, "", nil
		for f = 0, math.ceil((L.Up + 0.1) * 30) do
			local t = f / 30
			for _, m in rig.motors do m.Transform = CFrame.identity end
			for _, m in rig.motors do -- (the run's arm swing, opposite arms)
				if m.Name == "RightShoulder" or m.Name == "LeftShoulder" then
					local s = if m.Name == "RightShoulder" then 1 else -1
					m.Transform = CarryMath.inJoint(m, CFrame.Angles(math.rad(60 * s * math.sin(2 * math.pi * 1.4 * t + phase)), 0, 0))
				end
			end
			if hitAt and t >= hitAt then StabMotion.slash(rec, hitAt) end
			StabMotion.step(rec, t)
			Rig.fk(rig)
			local now = {}
			for _, n in { "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand" } do
				now[n] = rig.root.CFrame.Rotation:Inverse() * rig.parts[n].CFrame.Rotation
			end
			if prev then
				for n, cf in now do
					local _, ang = (prev[n]:Inverse() * cf):ToAxisAngle()
					local deg = math.deg(math.abs(ang)) % 360
					deg = math.min(deg, 360 - deg)
					if deg > worst then worst, where = deg, string.format("%s at %.2f s", n, t) end
				end
			end
			prev = now
		end
		return worst, where
	end
	local armMost, armWhere = 0, ""
	for _, hit in { false, 0.05 } do
		for k = 0, 7 do
			local w, at = armWorst(if hit then hit else nil, k * math.pi / 4)
			if w > armMost then armMost, armWhere = w, at .. (if hit then " (hit at 0.05 s)" else "") end
		end
	end
	print(string.format("  arms over the run at 30 fps: at most %.1f°/frame (%s)", armMost, armWhere))
	check(armMost <= 68, "the dive's arms never turn more in a frame than a running leg (~67°)")
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
