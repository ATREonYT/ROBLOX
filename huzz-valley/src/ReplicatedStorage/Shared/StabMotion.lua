--[[
	The catcher's slash (owner: "add the animations you learnt to make for the knifes"), scripted until a real one is
	uploaded (Config/Animations.Stab). Huss Valley's, measured frame by frame (docs/knife-study.md section 3,
	docs/previews/knife-study-slash.jpg): no wind-up, a sideways sweep, about 0.40 s (Config/Round.Stab.Time):
	  0.00 s       carry: the knife low by the right hip (the run's own arm);
	  0.00-0.07 s  the sweep: the arm swings straight out and across to the right, about level, the waist turning
	               20 degrees into it, the free arm pointing ahead at the runner (the hit lands here, ~0.07 s);
	  0.07-0.10 s  a small overshoot: the knife arm out to the side, a little back;
	  0.10-0.24 s  held out (it reads);
	  0.24-0.40 s  back to carry.

	The dive (Space, Gameplay/Dash; owner Oct 19: "add a dive feature for the tagger"; Oct 20 15:13: "right now its
	like a ragdoll, make it straight to the point and without a long unconsiousness, make it concrete"). The whole
	body dives (LEAP), one clean athletic move, 0.80 s from the press to running again (it was 2.83 s, 2 s of it lying
	dazed):
	  0.00-0.06 s  a quick crouch: knees bend, the hips drop, the body leans in (the push is already going);
	  0.06-0.13 s  the spring: the body straightens into one line along the ground, legs together behind, toes pointed,
	               both arms reaching ahead (superman), the knife leading;
	  in the air   that straight line, tipping down to the floor as the hop ends (Air: Config/Round.Lunge.Up);
	  the slash    the moment the knife reaches the runner (slash(): the catcher's own screen when its hit check finds
	               them, everyone else when the server's Caught arrives), or at SlashBy if it reaches no one: the arm
	               sweeps from ahead out to the right in 0.14 s (DIVE_KEYS), then the arms lie ahead;
	  landing      chest and legs on the floor, a short belly slide (Config/Round.Lunge.Slide, ~2 studs, done by 0.54 s);
	  pop up       0.40-0.80 s: hands push under the shoulders, knees tuck under, a quick crouch and up, the run back
	               over the last Blend seconds (Up). The stun (PowerService.stun, StunAfter + Stun = 0.78 s) ends as you stand.
	A sideways dive (A / D) does the same into its side. No dazed head roll, no lying still.

	Pure maths on joints (R15), so the offline preview runs this exact code (motion3d/catch_scene.luau,
	stab_scene.luau, knife_scene.luau); HuzzClient/Gameplay/Actions feeds it real characters. Written to
	Motor6D.Transform after Roblox's animations (Gameplay/Frame order 30), so the click slash sits over the run like
	an Action track and the legs keep running; a lunge owns the legs and the root joint too, then hands them back.
	The knife is welded to the right hand (KnifeService), so it stays in hand.
]]
local Round = require(script.Parent.Config.Round)
local CarryMath = require(script.Parent.CarryMath)

local StabMotion = {}
local rad = math.rad

-- Keyframes over the move (0..1 of Round.Stab.Time). Angles in degrees, in each joint's parent part space
-- (x = right, y = up, -z = forward: +x pitch raises an arm forward / leans the waist back, +y turns left).
-- shoulder/elbow/wrist: the knife (right) arm; off/offElbow: the free (left) arm; waist; neck.
-- ease: how the segment arriving at that key moves ("out" = fast then settling, "in" = speeding up, "smooth").
local KEYS = {
	{ at = 0.00, shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, off = { 0, 0, 0 }, offElbow = { 0, 0, 0 }, waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
	-- the sweep's reach (~0.07 s): knife arm forward and out to the right, near level; waist turned into it
	-- (right, -y), leaning in; free arm up pointing ahead; the head counter-turns to stay on the runner
	-- Oct 19 ("better knife animations ... during gameplay"): the wrist snaps the blade flat into the sweep (it cuts
	-- level across instead of hanging down) and the body leans into it a little more; same timing, still no wind-up
	{ at = 0.18, ease = "out", shoulder = { -2, 44, 64 }, elbow = { 14, 0, 0 }, wrist = { -24, 0, -20 }, off = { 80, 0, -6 }, offElbow = { 14, 0, 0 }, waist = { -10, -24, 0 }, neck = { 4, 21, 0 } },
	-- a small overshoot: the arm carries on out to the side, a little back, the wrist following through
	{ at = 0.25, ease = "out", shoulder = { 0, 0, 82 }, elbow = { 8, 0, 0 }, wrist = { -28, 0, -26 }, off = { 84, 0, -6 }, offElbow = { 10, 0, 0 }, waist = { -10, -28, 0 }, neck = { 4, 24, 0 } },
	-- held out, so it reads
	{ at = 0.60, ease = "smooth", shoulder = { 0, 6, 76 }, elbow = { 10, 0, 0 }, wrist = { -18, 0, -16 }, off = { 80, 0, -5 }, offElbow = { 12, 0, 0 }, waist = { -7, -24, 0 }, neck = { 3, 21, 0 } },
	-- back to carry
	{ at = 1.00, ease = "smooth", shoulder = { 0, 0, 0 }, elbow = { 0, 0, 0 }, wrist = { 0, 0, 0 }, off = { 0, 0, 0 }, offElbow = { 0, 0, 0 }, waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
}
StabMotion.KEYS = KEYS

local function smooth(x)
	return x * x * (3 - 2 * x)
end
local EASE = {
	smooth = smooth,
	out = function(x) return 1 - (1 - x) ^ 3 end,
	["in"] = function(x) return x * x end,
}

local function angles(t)
	return CFrame.Angles(rad(t[1]), rad(t[2]), rad(t[3]))
end

-- The pose of one joint at u (0..1). first: replaces the first key's pose (a dive's slash starts from the reach);
-- last: replaces the last (a dive's slash settles into the arms lying ahead, not back to the carry).
local function at(u, key, first, last)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if u <= b.at then
			local s = (EASE[b.ease] or smooth)(math.clamp((u - a.at) / (b.at - a.at), 0, 1))
			local from = if i == 1 and first and first[key] then first[key] else a[key]
			local to = if i + 1 == #KEYS and last and last[key] then last[key] else b[key]
			return angles(from):Lerp(angles(to), s)
		end
	end
	return if last and last[key] then angles(last[key]) else CFrame.identity
end
StabMotion.poseAt = at

-- A dive's slash (Oct 19 evening, a fresh critic: at 30 fps the click slash's 0.07 s sweep, started from the arms
-- overhead, turned the knife hand 113° in one frame): the same sweep, held and settle, but from the reach overhead it
-- lands at DIVE_SWEEP of the slash (0.14 s; the hand is still out to the right within 0.08 s of the hit) with a smooth ease, so
-- no arm joint turns more in one frame than a leg does in the run (~65°). Angles as KEYS; the first and last poses
-- are the dive's REACH and LIE.
local DIVE_SWEEP = 0.35
local DIVE_KEYS = {
	{ at = 0 },
	{ at = DIVE_SWEEP, ease = "smooth", from = 2 },
	{ at = DIVE_SWEEP + 0.1, ease = "smooth", from = 3 },
	{ at = 0.6, ease = "smooth", from = 4 },
	{ at = 1.0, ease = "smooth" },
}
-- The dive's pose of one joint at u (0..1 of the slash) as { x, y, z } degrees, mixed number by number (so the
-- arm blend below can mix it the same way): first = REACH, last = LIE.
local function diveAt(u, key, first, last)
	local function of(i)
		if i == 1 then return first[key] end
		if i == #DIVE_KEYS then return last[key] end
		return KEYS[DIVE_KEYS[i].from][key]
	end
	for i = 1, #DIVE_KEYS - 1 do
		local a, b = DIVE_KEYS[i], DIVE_KEYS[i + 1]
		if u <= b.at then
			local s = EASE[b.ease](math.clamp((u - a.at) / (b.at - a.at), 0, 1))
			local p, q = of(i), of(i + 1)
			return { p[1] + (q[1] - p[1]) * s, p[2] + (q[2] - p[2]) * s, p[3] + (q[3] - p[3]) * s }
		end
	end
	return last[key]
end
StabMotion.diveAt = diveAt

-- An arm joint in a dive: from the animation's own pose toward `deg` ({ x, y, z } degrees, the pose's XYZ angles)
-- by w, angle by angle. Not CFrame:Lerp: the arms overhead (REACH 168°, LIE 158°) are close to 180° from the run's
-- swing, and a Lerp there takes the shorter way round, which flips to the other way from one frame to the next as
-- the run's arm swings (Oct 19: the right arm turned 100° in one frame while getting up from a dive, at 8.30 s in
-- motion3d/move_smooth_measure.luau). Angle by angle the arm always goes the same way (forward and up).
local function blendArm(motor, animatedT, deg, w)
	local c0 = motor.C0.Rotation
	local ax, ay, az = (c0 * animatedT.Rotation * c0:Inverse()):ToEulerAnglesXYZ()
	local tx, ty, tz = rad(deg[1]), rad(deg[2]), rad(deg[3])
	local r = CFrame.Angles(ax + (tx - ax) * w, ay + (ty - ay) * w, az + (tz - az) * w)
	return CFrame.new(animatedT.Position * (1 - w)) * c0:Inverse() * r * c0
end
StabMotion.blendArm = blendArm

-- How much the move owns the joints (the rest is the running animation): in fast, out with the follow-through.
local function weight(u)
	if u < 0.06 then
		return smooth(u / 0.06)
	elseif u < 0.6 then
		return 1
	end
	return 1 - smooth(math.clamp((u - 0.6) / 0.4, 0, 1))
end
StabMotion.weight = weight

--[[ The dive (seconds from Space). Air: the hop's time in the air, 2 x Up / gravity (Config/Round.Lunge.Up 24:
	0.245 s). KEYS: t in seconds ("air" adds Air x that), lean = the body tipped into the dive (degrees, about the
	hips, the root joint), lead / trail = hip swing into the dive (+) or away (-), knee bend (-), ankle (+ toes up);
	the lead leg is the left on a forward dive (opposite the knife arm), the side's own leg on a sideways one.
	REACH: both arms ahead until the slash (over the head, so on a flat body they point the way it dives); LIE: the
	arms after the slash, ahead on the floor; PUSH: hands under the shoulders for the pop up (from Out over 0.12 s).
	Out: the belly slide ends, the pop up starts; Up: on your feet, the run back over the last Blend seconds.
	The hips are lowered so the lowest part of the body touches the floor while crouching, landing and getting up. ]]
StabMotion.LEAP = {
	Gravity = 196.2,
	In = 0.07, -- the crouch takes over from the run this fast
	ArmIn = 0.16, -- the arms reach ahead this fast, evenly (Oct 19 evening: 0.06 with an ease turned the hand 173° in one frame)
	SlashBy = 0.14, -- the slash if the knife has reached no one sooner (lands 0.07 s later, before the landing)
	Out = 0.40, -- the pop up starts (the belly slide, Config/Round.Lunge.Slide, eases out under it by 0.54)
	Up = 0.80, -- on your feet, the run back (the stun ends at StunAfter + Stun = 0.78)
	Blend = 0.16, -- the pop up's last part hands back to the run
	KEYS = {
		{ t = 0.00, lean = 6, lead = { 10, -20, 0 }, trail = { 6, -20, 0 } }, -- from the run
		{ t = 0.07, lean = 22, lead = { 44, -66, 18 }, trail = { 24, -58, 14 } }, -- a quick crouch: knees bent, hips low
		{ t = 0.16, lean = 60, lead = { 6, -8, -20 }, trail = { -14, -4, -26 } }, -- the spring: straight, legs behind
		{ t = 0, air = 0.75, lean = 76, lead = { 2, -4, -28 }, trail = { -8, -4, -30 } }, -- one straight line, toes pointed
		{ t = 0, air = 1, lean = 84, lead = { 0, -6, -30 }, trail = { -4, -8, -30 } }, -- chest and legs touch down
		{ t = 0.40, lean = 88, lead = { 0, -10, -32 }, trail = { -2, -12, -32 } }, -- on the belly (Out: the pop up starts)
		{ t = 0.54, lean = 54, lead = { 70, -100, 0 }, trail = { 54, -94, 0 } }, -- hands push, knees tuck under
		{ t = 0.67, lean = 16, lead = { 48, -70, 12 }, trail = { 38, -62, 10 } }, -- a quick crouch, rising
		{ t = 0.80, lean = 0, lead = { 0, 0, 0 }, trail = { 0, 0, 0 } }, -- standing (Up)
	},
	Neck = 0.5, -- the head lifts this much of the lean back, so the eyes look ahead
	REACH = { shoulder = { 168, 0, -10 }, elbow = { 6, 0, 0 }, wrist = { -30, 0, 0 }, off = { 162, 0, 14 }, offElbow = { 10, 0, 0 },
		waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
	LIE = { shoulder = { 158, 0, -26 }, elbow = { 16, 0, 0 }, wrist = { -12, 0, 0 }, off = { 158, 0, 26 }, offElbow = { 16, 0, 0 },
		waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
	PUSH = { shoulder = { 50, 0, -8 }, elbow = { 20, 0, 0 }, wrist = { -10, 0, 0 }, off = { 50, 0, 8 }, offElbow = { 20, 0, 0 },
		waist = { 0, 0, 0 }, neck = { 0, 0, 0 } },
}

function StabMotion.air(): number
	local L = StabMotion.LEAP
	return 2 * ((Round.Lunge and Round.Lunge.Up) or 18) / L.Gravity
end

-- The leap's pose at t seconds: { lean, lead = {hip, knee, ankle}, trail = {...} } (degrees), eased between keys.
function StabMotion.leapAt(t: number)
	local K, air = StabMotion.LEAP.KEYS, StabMotion.air()
	local function tOf(k) return k.t + (k.air or 0) * air end
	local function mix(a, b, s)
		local function v3(x, y) return { x[1] + (y[1] - x[1]) * s, x[2] + (y[2] - x[2]) * s, x[3] + (y[3] - x[3]) * s } end
		return { lean = a.lean + (b.lean - a.lean) * s, lead = v3(a.lead, b.lead), trail = v3(a.trail, b.trail) }
	end
	if t <= 0 then return mix(K[1], K[1], 0) end
	for i = 1, #K - 1 do
		local a, b = K[i], K[i + 1]
		local ta, tb = tOf(a), tOf(b)
		if t <= tb then
			return mix(a, b, smooth(math.clamp((t - ta) / math.max(tb - ta, 1e-3), 0, 1)))
		end
	end
	return mix(K[#K], K[#K], 0)
end

-- How much the leap owns the body, legs and root joint at t (in fast, held, back to the run over the last Blend).
function StabMotion.leapWeight(t: number): number
	local L = StabMotion.LEAP
	if t < 0 or t >= L.Up then
		return 0
	elseif t < L.In then
		return smooth(t / L.In)
	elseif t <= L.Up - L.Blend then
		return 1
	end
	return 1 - smooth((t - (L.Up - L.Blend)) / L.Blend)
end

-- rig: CarryMath.rig(character); root: the HumanoidRootPart (to keep the thrust level while running hunched).
function StabMotion.new(rig, root)
	local head = rig.head
	local neck = head and CarryMath.joint(head:FindFirstChild("Neck"))
	return { rig = rig, root = root, neck = neck, start = -math.huge, written = {}, base = {} }
end

-- How far the running animation tips the chest forward (radians): the hips' tilt (from the parts) plus the
-- animation's own waist bend this frame. The knife arm is raised by this much, so a hunched sprint still
-- stabs straight ahead instead of at the ground.
local function hunch(rec)
	local waist, root = rec.rig.waist, rec.root
	local pelvis = waist and waist.Part0
	if not (pelvis and root) then
		return 0
	end
	local up = root.CFrame:VectorToObjectSpace(pelvis.CFrame.UpVector)
	local a = math.atan2(-up.Z, up.Y)
	local base = rec.base[waist]
	if base then
		local r = waist.C0.Rotation
		local w = (r * base.Rotation * r:Inverse()):VectorToWorldSpace(Vector3.new(0, 1, 0))
		a += math.atan2(-w.Z, w.Y)
	end
	return math.clamp(a, 0, rad(55))
end

-- lunge: true for the Space leap (the reach, the slash when it lands, the landing).
function StabMotion.play(rec, now, lunge: boolean?)
	rec.start = now
	rec.lunge = lunge == true
	rec.slashAt = if rec.lunge then nil else now
	rec.diveDir = Vector3.new(0, 0, -1)
	rec.lead = nil
end

-- The lunge's knife reached someone at `now`: the slash starts (once, and only before SlashBy).
function StabMotion.slash(rec, now)
	if rec.lunge and not rec.slashAt and now >= rec.start then
		rec.slashAt = math.min(now, rec.start + StabMotion.LEAP.SlashBy)
	end
end

-- When the slash starts (a lunge: when it reached someone, else SlashBy into the leap); nil before then.
function StabMotion.slashStart(rec, now): number?
	if rec.lunge and not rec.slashAt and now - rec.start >= StabMotion.LEAP.SlashBy then
		rec.slashAt = rec.start + StabMotion.LEAP.SlashBy
	end
	return rec.slashAt
end

-- The leap's direction in the body's own space (x right, -z forward), flat; Gameplay/Actions sets it each frame.
function StabMotion.setDive(rec, localDir: Vector3)
	local d = Vector3.new(localDir.X, 0, localDir.Z)
	if d.Magnitude > 0.2 then
		rec.diveDir = d.Unit
	end
end

-- The slash's progress (0..1 of Round.Stab.Time); before a lunge's slash, negative.
function StabMotion.progress(rec, now)
	local s = StabMotion.slashStart(rec, now)
	if not s then return -1 end
	return (now - s) / Round.Stab.Time
end

-- The blade's trail shows during the sweep and the start of the hold (docs/knife-study.md: 0.08 to 0.45).
function StabMotion.trailOn(rec, now)
	local u = StabMotion.progress(rec, now)
	return u >= 0.02 and u <= 0.45
end

local function animated(rec, motor)
	local current = motor.Transform
	local anim = if rec.written[motor] == current then rec.base[motor] else current
	rec.base[motor] = anim
	return anim
end

local function write(rec, motor, transform)
	motor.Transform = transform
	rec.written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
end

-- A leg's three joint rotations (parent part space) for a swing `a` along the flat body-space direction d.
local function legPose(d, v)
	return CFrame.Angles(-d.Z * rad(v[1]), 0, d.X * rad(v[1])), CFrame.Angles(rad(v[2]), 0, 0), CFrame.Angles(rad(v[3]), 0, 0)
end

-- The lowest point of either foot below the root part's centre (studs) with these joint Transforms, from the
-- joints' C0 / C1 and the feet's sizes (the parts' own CFrames lag a frame behind).
local function lowestFoot(rig, rootT, legT)
	local rootJ = rig.root
	local pelvis = rootJ.C0 * rootT * rootJ.C1:Inverse()
	local low = math.huge
	for i, leg in rig.legs do
		local t = legT and legT[i]
		if leg.hip and leg.knee and leg.ankle and leg.foot then
			local upper = pelvis * leg.hip.C0 * (t and t[1] or CFrame.identity) * leg.hip.C1:Inverse()
			local lower = upper * leg.knee.C0 * (t and t[2] or CFrame.identity) * leg.knee.C1:Inverse()
			local foot = lower * leg.ankle.C0 * (t and t[3] or CFrame.identity) * leg.ankle.C1:Inverse()
			local s = leg.foot.Size / 2
			for _, x in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (foot * Vector3.new(s.X * x, -s.Y, s.Z * z)).Y)
				end
			end
		end
	end
	return low
end
StabMotion.lowestFoot = lowestFoot

-- The lowest point of the whole body (feet, legs, hips, chest, head) below the root part's centre: a body on its
-- belly lies on its chest and legs, not its feet.
local function lowestBody(rig, rootT, legT)
	local low = lowestFoot(rig, rootT, legT)
	local rootJ = rig.root
	local pelvis = rootJ.C0 * rootT * rootJ.C1:Inverse()
	local function box(cf, size, k)
		local h = size / 2 * (k or 1)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (cf * Vector3.new(h.X * x, h.Y * y, h.Z * z)).Y)
				end
			end
		end
	end
	local waist = rig.waist
	local hips = waist and waist.Part0
	if hips then
		box(pelvis, hips.Size)
	end
	if waist and rig.torso then
		local chest = pelvis * waist.C0 * waist.C1:Inverse()
		box(chest, rig.torso.Size)
		local neck = rig.head and CarryMath.joint(rig.head:FindFirstChild("Neck"))
		if neck then
			box(chest * neck.C0 * neck.C1:Inverse(), rig.head.Size, 0.8) -- (a round head: its box's corners stick out)
		end
	end
	for i, leg in rig.legs do
		local t = legT and legT[i]
		if leg.hip and leg.knee and leg.upper and leg.lower then
			local upper = pelvis * leg.hip.C0 * (t and t[1] or CFrame.identity) * leg.hip.C1:Inverse()
			box(upper, leg.upper.Size, 0.9)
			box(upper * leg.knee.C0 * (t and t[2] or CFrame.identity) * leg.knee.C1:Inverse(), leg.lower.Size, 0.9)
		end
	end
	return low
end
StabMotion.lowestBody = lowestBody

-- The lunge's body: the root joint (lean + the hips lowered on landing), both legs, the head lifting.
local function leap(rec, t)
	local rig = rec.rig
	local lw = StabMotion.leapWeight(t)
	if lw <= 0 or not (rig.root and rig.legs) then return end
	local d = rec.diveDir or Vector3.new(0, 0, -1)
	if not rec.lead and t >= 0.02 then -- the lead leg: the side's on a sideways leap, else the left
		rec.lead = if d.X > 0.5 then 1 elseif d.X < -0.5 then 2 else 2
	end
	local leadI = rec.lead or 2
	local p = StabMotion.leapAt(t)
	local a = rad(p.lean)
	local tip = CFrame.Angles(d.Z * a, 0, -d.X * a) -- (forward: pitch down; right: roll right)
	local legT = {}
	for i, leg in rig.legs do
		local v = if i == leadI then p.lead else p.trail
		local h, k, an = legPose(d, v)
		legT[i] = { leg.hip and CarryMath.inJoint(leg.hip, h), leg.knee and CarryMath.inJoint(leg.knee, k), leg.ankle and CarryMath.inJoint(leg.ankle, an) }
	end
	-- on the floor while crouching (leaving it as the spring lifts the body), then down to the floor through the
	-- second half of the hop, on it for the slide and the pop up (the lowest part of the body touching, nothing under)
	local air = StabMotion.air()
	local ground = math.max(1 - smooth(math.clamp((t - 0.07) / 0.09, 0, 1)), smooth(math.clamp((t - air * 0.4) / (air * 0.6 + 0.04), 0, 1)))
	local drop = 0
	if ground > 0 then
		local rest = lowestFoot(rig, CFrame.identity, nil)
		local posed = lowestBody(rig, CarryMath.inJoint(rig.root, tip), legT)
		drop = math.max(0, posed - rest) * ground
	end
	local c0 = rig.root.C0.Rotation
	local rootT = c0:Inverse() * (CFrame.new(0, -drop, 0) * tip) * c0
	write(rec, rig.root, animated(rec, rig.root):Lerp(rootT, lw))
	for i, leg in rig.legs do
		for j, joint in { leg.hip, leg.knee, leg.ankle } do
			if joint and legT[i][j] then
				write(rec, joint, animated(rec, joint):Lerp(legT[i][j], lw))
			end
		end
	end
	-- the head: lifted to look ahead (no dazed roll: the owner, Oct 20 15:13, "without a long unconsiousness")
	local L = StabMotion.LEAP
	return lw, CFrame.Angles(-d.Z * a * L.Neck, 0, d.X * a * L.Neck)
end

-- Returns true while the move is playing. animatedArm = false skips the knife arm (an uploaded Stab
-- animation plays it instead); the body, the free arm and the head always play.
function StabMotion.step(rec, now, animatedArm)
	local t = now - rec.start
	local slashAt = StabMotion.slashStart(rec, now)
	local u = if slashAt then (now - slashAt) / Round.Stab.Time else -1
	local leaping = rec.lunge and t >= 0 and t < StabMotion.LEAP.Up
	local reaching = rec.lunge and t >= 0 and not slashAt
	local lying = rec.lunge and leaping and slashAt ~= nil and u > 1 -- (after a dive's slash: arms flat ahead)
	if (u < 0 or u > 1) and not leaping and not reaching then
		if next(rec.written) then
			StabMotion.release(rec)
		end
		return false
	end
	-- the arms' clock: the reach (a lunge before its slash), then the slash from the reach pose
	local w, first
	-- (a dive's arms come in evenly over ArmIn and stay in through the slash: a slash that starts before the reach is
	-- complete carries on from where the arms are, no jump)
	local armIn = if rec.lunge then math.clamp(t / StabMotion.LEAP.ArmIn, 0, 1) else 0
	if reaching then
		w = armIn
	elseif u >= 0 and u <= 1 then
		w = weight(u)
		if rec.lunge then
			first = StabMotion.LEAP.REACH
			w = armIn -- (already reaching, and settling into the arms lying ahead: no fade out)
		end
	elseif lying then
		w = StabMotion.leapWeight(t) -- (back to the run's arms as the body gets up)
	else
		w = 0
	end
	local last = if rec.lunge then StabMotion.LEAP.LIE else nil
	-- a dive's pose as { x, y, z } degrees (its arms blend angle by angle: blendArm). On the floor the arms lie
	-- ahead, then from Out the hands come under the shoulders for the pop up (PUSH), also while a late slash settles.
	local ground
	if rec.lunge then
		local L = StabMotion.LEAP
		local g = smooth(math.clamp((t - L.Out) / 0.12, 0, 1))
		ground = {}
		for key, p in L.LIE do
			local q = L.PUSH[key]
			ground[key] = { p[1] + (q[1] - p[1]) * g, p[2] + (q[2] - p[2]) * g, p[3] + (q[3] - p[3]) * g }
		end
	end
	local function diveDeg(key)
		if reaching then return StabMotion.LEAP.REACH[key] end
		if lying then return ground[key] end
		return diveAt(u, key, StabMotion.LEAP.REACH, ground)
	end
	local function pose(key)
		if w <= 0 then return CFrame.identity end
		if rec.lunge then return angles(diveDeg(key)) end
		return at(u, key, first, last)
	end
	-- the leap's body (root joint and legs) first, then the waist and head on top
	local neckLift
	if rec.lunge then
		local _, lift = leap(rec, t)
		neckLift = lift
	end
	local waist = rec.rig.waist
	if waist then
		-- (a dive keeps the chest in line with the hips: the slash's waist turn would tip a body lying flat into the floor)
		local body = if rec.lunge then CFrame.identity else CFrame.identity:Lerp(pose("waist"), w)
		write(rec, waist, animated(rec, waist) * CarryMath.inJoint(waist, body))
	end
	if rec.neck then
		local head = CFrame.identity:Lerp(pose("neck"), w)
		if neckLift then head = CFrame.identity:Lerp(neckLift, StabMotion.leapWeight(t)) * head end
		write(rec, rec.neck, animated(rec, rec.neck) * CarryMath.inJoint(rec.neck, head))
	end
	-- (a hunched run tips the chest: keep the knife arm level; a dive tips the whole body itself, so not then)
	local level = if rec.lunge then CFrame.identity else CFrame.Angles(hunch(rec), 0, 0)
	local function arm(side, keys)
		if w <= 0 then return end
		for joint, key in keys do
			local motor = side and side[joint]
			if motor and rec.lunge then
				write(rec, motor, blendArm(motor, animated(rec, motor), diveDeg(key), w))
			elseif motor then
				local p = pose(key)
				if key == "shoulder" then
					p = level * p
				end
				write(rec, motor, animated(rec, motor):Lerp(CarryMath.inJoint(motor, p), w))
			end
		end
	end
	if animatedArm ~= false then
		arm(rec.rig.arms[1], { shoulder = "shoulder", elbow = "elbow", wrist = "wrist" }) -- the right arm holds the knife
	end
	arm(rec.rig.arms[2], { shoulder = "off", elbow = "offElbow" })
	return true
end

-- Hands the joints back to their animations.
function StabMotion.release(rec)
	-- (only a joint nothing animated since our last write: one an animation already posed this frame keeps that fresh pose;
	-- writing the older `base` over it showed a stale pose for one frame, a pop at the end of the move)
	for motor, base in rec.base do
		if motor.Parent and motor.Transform == rec.written[motor] then
			motor.Transform = base
		end
	end
	rec.written, rec.base = {}, {}
end

return StabMotion
