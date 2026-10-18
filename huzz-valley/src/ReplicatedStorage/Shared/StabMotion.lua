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
	The lunge (Space, Gameplay/Dash) plays the same sweep at take-off and then a dive (DIVE: the body tips 35 degrees
	into the leap, forward or sideways, for 0.15 s as it lands, up again by +0.25 s); Gameplay/Actions passes the
	leap's direction each frame (from the body's speed, so every screen sees it the same).

	Pure maths on joints (R15), so the offline preview runs this exact code (motion3d/stab_scene.luau,
	knife_scene.luau); HuzzClient/Gameplay/Actions feeds it real characters. Written to Motor6D.Transform after
	Roblox's animations (Gameplay/Frame order 30), so it sits over the run like an Action track and the legs keep
	running. The knife is welded to the right hand (KnifeService), so it stays in hand.
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
	{ at = 0.18, ease = "out", shoulder = { 0, 42, 62 }, elbow = { 14, 0, 0 }, wrist = { -12, 0, 0 }, off = { 80, 0, -6 }, offElbow = { 14, 0, 0 }, waist = { -6, -20, 0 }, neck = { 2, 17, 0 } },
	-- a small overshoot: the arm carries on out to the side, a little back
	{ at = 0.25, ease = "out", shoulder = { 0, 0, 80 }, elbow = { 8, 0, 0 }, wrist = { -16, 0, 0 }, off = { 84, 0, -6 }, offElbow = { 10, 0, 0 }, waist = { -6, -24, 0 }, neck = { 2, 20, 0 } },
	-- held out, so it reads
	{ at = 0.60, ease = "smooth", shoulder = { 0, 6, 76 }, elbow = { 10, 0, 0 }, wrist = { -12, 0, 0 }, off = { 80, 0, -5 }, offElbow = { 12, 0, 0 }, waist = { -5, -20, 0 }, neck = { 2, 17, 0 } },
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

-- The pose of one joint at u (0..1).
local function at(u, key)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if u <= b.at then
			local s = (EASE[b.ease] or smooth)(math.clamp((u - a.at) / (b.at - a.at), 0, 1))
			return angles(a[key]):Lerp(angles(b[key]), s)
		end
	end
	return CFrame.identity
end
StabMotion.poseAt = at

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

-- The lunge's dive (seconds from the start): tips in from At to Full, holds to Hold, up again by Up.
StabMotion.DIVE = { At = 0.24, Full = 0.32, Hold = 0.47, Up = 0.72, Angle = 35 }

-- lunge: true for the Space leap (the sweep, then the dive).
function StabMotion.play(rec, now, lunge: boolean?)
	rec.start = now
	rec.lunge = lunge == true
	rec.diveDir = Vector3.new(0, 0, -1)
end

-- The leap's direction in the body's own space (x right, -z forward), flat; Gameplay/Actions sets it each frame.
function StabMotion.setDive(rec, localDir: Vector3)
	local d = Vector3.new(localDir.X, 0, localDir.Z)
	if d.Magnitude > 0.2 then
		rec.diveDir = d.Unit
	end
end

-- How far into the dive (0..1) at t seconds since the start.
function StabMotion.diveAt(t: number): number
	local D = StabMotion.DIVE
	if t <= D.At or t >= D.Up then
		return 0
	elseif t < D.Full then
		return smooth((t - D.At) / (D.Full - D.At))
	elseif t <= D.Hold then
		return 1
	end
	return 1 - smooth((t - D.Hold) / (D.Up - D.Hold))
end

function StabMotion.progress(rec, now)
	return (now - rec.start) / Round.Stab.Time
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

-- Returns true while the move is playing. animatedArm = false skips the knife arm (an uploaded Stab
-- animation plays it instead); the body, the free arm and the head always play.
function StabMotion.step(rec, now, animatedArm)
	local u = StabMotion.progress(rec, now)
	local t = now - rec.start
	local diving = rec.lunge and t >= 0 and t < StabMotion.DIVE.Up
	if (u < 0 or u > 1) and not diving then
		if next(rec.written) then
			StabMotion.release(rec)
		end
		return false
	end
	local w = if u >= 0 and u <= 1 then weight(u) else 0
	local function pose(key) return if w > 0 then at(u, key) else CFrame.identity end
	-- body and head first: added on top of the run (the legs and hips keep running)
	local waist = rec.rig.waist
	if waist then
		local body = CFrame.identity:Lerp(pose("waist"), w)
		local dive = if rec.lunge then StabMotion.diveAt(t) else 0
		if dive > 0 then -- the dive: tipped into the leap (forward = pitch, sideways = roll)
			local d, a = rec.diveDir, rad(StabMotion.DIVE.Angle) * dive
			body = CFrame.Angles(d.Z * a, 0, -d.X * a) * body
		end
		write(rec, waist, animated(rec, waist) * CarryMath.inJoint(waist, body))
	end
	if rec.neck then
		write(rec, rec.neck, animated(rec, rec.neck) * CarryMath.inJoint(rec.neck, CFrame.identity:Lerp(pose("neck"), w)))
	end
	local level = CFrame.Angles(hunch(rec), 0, 0) -- (a hunched run tips the chest: keep the knife arm level)
	local function arm(side, keys)
		if w <= 0 then return end
		for joint, key in keys do
			local motor = side and side[joint]
			if motor then
				local pose = at(u, key)
				if key == "shoulder" then
					pose = level * pose
				end
				write(rec, motor, animated(rec, motor):Lerp(CarryMath.inJoint(motor, pose), w))
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
	for motor, base in rec.base do
		if motor.Parent then
			motor.Transform = base
		end
	end
	rec.written, rec.base = {}, {}
end

return StabMotion
