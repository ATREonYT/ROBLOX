--[[
	The anime girls walk, run and stand with the owner's real animations (owner: "get all the animations right in
	the game"): the movement pack's Idle, Walk and Run (Sprint) KeyframeSequences, played by hand on her joints,
	so it works now in Studio and in the live game with nothing uploaded (Config/Animations.GirlWalk stays "").
	  - The pack is R15 and most girls are R6: each frame's pose is sampled (Shared/KeyframeSampler) and put on her
	    body by Shared/DanceRetarget, the same way her dances are.
	  - Idle, Walk and Run blend by her speed with Shared/LocomotionMix (the player's own blend): no pops, the feet
	    in step between walk and run, each loop sped up with her speed inside calm limits (Config/GirlMotion.Pack).
	    The speed each loop plays at 1x is measured from the animation itself (how far its planted foot travels
	    in one loop), times her size: a small companion takes shorter, quicker steps.
	  - Planted feet (an R6 leg can't bend, and the pack's feet don't move back at an even speed):
	      footOverFoot: each straight leg is aimed so its foot sits right over the R15 foot;
	      the lock: her body surges forward and back a little within each step (the animation's own rhythm,
	        measured once per loop) so the foot on the ground stays put while she moves at an even speed;
	      plant: her body goes up or down so that foot touches the ground (the leg swinging through may brush it
	        by a sliver, Config.Pack.Clip; in a run a little air is allowed between steps).
	    Past the rate limits (keeping up with a fast catcher) the feet slide a little: calmer than blurred legs.
	  - look: an optional head turn on top (the prize girl watching the nearest player, a follower watching her
	    catcher when she stands), faded in by how much she's standing.
	Where the animations come from (GirlMoves.find): ReplicatedStorage.HuzzGirlMoves, which Bootstrap fills from
	ServerStorage.HuzzAnimations in Studio AND in the live game (only these three, ~180 KB), else
	ReplicatedStorage.HuzzAnimations (Studio). Nothing there (yet) = nil, and the girls keep the built-in scripted
	walk (Shared/GirlMotion) until it arrives.
	Pure maths on joint tables (Shared/GirlMotion.joints): the offline preview and tests/GirlMoves.spec run this.
]]
local Config = require(script.Parent.Config.GirlMotion)
local Sampler = require(script.Parent.KeyframeSampler)
local Retarget = require(script.Parent.DanceRetarget)
local Mix = require(script.Parent.LocomotionMix)

local GirlMoves = {}
local R15_HEIGHT = 5.2 -- (DanceRetarget scales the hips' movement by her height against an R15 avatar)
local R6_ROOT = 3 -- root above the feet on a standard 5.25-stud R6 body: sizes are measured against it
local R6_LEG = 2 -- hip to sole on that body
local DOWN = Vector3.new(0, -1, 0)
local LOCK_SAMPLES = 64

GirlMoves.NAMES = { "Idle", "Walk", "Run" }

-- Which foot the R15 animation has on the ground: the lower ankle with the knees bent as the animation bends
-- them (an R6 leg is straight, so its own height can't tell: a leg swinging through would look lowest).
local function stanceSide(pose): string
	local lower = pose.LowerTorso or CFrame.identity
	local best, bestY = "L", math.huge
	for side, name in { L = "Left", R = "Right" } do
		local u = (pose[name .. "UpperLeg"] or CFrame.identity).Rotation
		local l = (pose[name .. "LowerLeg"] or CFrame.identity).Rotation
		local y = lower.Position.Y + lower.Rotation:VectorToWorldSpace(u:VectorToWorldSpace(DOWN) + (u * l):VectorToWorldSpace(DOWN)).Y
		if y < bestY then
			best, bestY = side, y
		end
	end
	return best
end
GirlMoves.stanceSide = stanceSide

--[[ R6 legs can't bend, and a straight leg aimed where the R15 leg points puts the foot too far forward or back
	whenever the R15 knee is bent (her planted foot would skate). So each leg is aimed so its foot is right over the
	R15 foot instead (same spot forward/back and sideways, as a share of the leg); the R15 foot's height is lost
	(a leg swinging through hangs straight down). Rewrites the pose's UpperLeg turn and straightens LowerLeg;
	DanceRetarget then aims the R6 leg along it. Returns each leg's aim (in the LowerTorso's space). ]]
-- The pack's sprint tips the body far forward; on an R6 girl's straight legs that reads as falling over. This caps
-- the body's tilt (lower torso and chest together) at `maxDeg`, turning the lower torso back by the excess.
local function capLean(pose, maxDeg: number)
	local lower = pose.LowerTorso
	if not lower then return end
	local up = (lower * (pose.UpperTorso or CFrame.identity)).UpVector
	local tilt = math.acos(math.clamp(up.Y, -1, 1))
	local excess = tilt - math.rad(maxDeg)
	local axis = Vector3.new(0, 1, 0):Cross(up)
	if excess <= 0 or axis.Magnitude < 1e-4 then return end
	pose.LowerTorso = CFrame.new(lower.Position) * CFrame.fromAxisAngle(axis.Unit, -excess) * lower.Rotation
end

local function footOverFoot(pose)
	local aims = {}
	for side, name in { L = "Left", R = "Right" } do
		local upper, lower = pose[name .. "UpperLeg"], pose[name .. "LowerLeg"]
		if upper then
			local u = upper.Rotation
			local l = if lower then lower.Rotation else CFrame.identity
			local ankle = (u:VectorToWorldSpace(DOWN) + (u * l):VectorToWorldSpace(DOWN)) / 2 -- (two equal bones)
			local flat = Vector3.new(ankle.X, 0, ankle.Z)
			if flat.Magnitude > 0.95 then
				flat = flat.Unit * 0.95
			end
			local aim = flat + Vector3.new(0, -math.sqrt(1 - flat:Dot(flat)), 0)
			aims[side] = aim
			pose[name .. "UpperLeg"] = CFrame.new(upper.Position) * Retarget.fromTo(DOWN, aim)
			if lower then
				pose[name .. "LowerLeg"] = CFrame.new(lower.Position)
			end
		end
	end
	return aims
end

--[[ The lock for a loop (Walk, Run): over one loop, how far forward/back (studs, standard size) her body should
	be at each moment so the planted foot doesn't move, and how far she travels in one loop (stride). ]]
local function measureLock(anim)
	local n = LOCK_SAMPLES
	local feet, sides = {}, {}
	for i = 0, n do
		local pose = Sampler.sample(anim, i / n * anim.length)
		local lower = pose.LowerTorso or CFrame.identity
		local side = stanceSide(pose)
		local aim = footOverFoot(pose)[side] or DOWN
		local hip = Vector3.new(if side == "L" then -0.5 else 0.5, -1, 0)
		feet[i] = lower.Position.Z * 5.25 / R15_HEIGHT + lower.Rotation:VectorToWorldSpace(hip + aim * R6_LEG).Z
		sides[i] = side
	end
	-- the planted foot moves back (+Z) by dz; her body should move forward by the same, around an even pace
	local back = {}
	local stride = 0
	for i = 0, n - 1 do
		local dz = if sides[i] == sides[i + 1] then feet[i + 1] - feet[i] else 0
		back[i] = math.max(dz, 0) -- (a foot moving forward while planted is the swap between feet: ignore)
		stride += back[i]
	end
	local c, sum = { [0] = 0 }, 0
	for i = 0, n - 1 do
		c[i + 1] = c[i] + stride / n - back[i] -- (her offset along +Z, back: the body moves on with the foot, around an even pace)
	end
	for i = 0, n - 1 do
		sum += c[i]
	end
	for i = 0, n do
		c[i] -= sum / n
	end
	return { c = c, stride = stride }
end

local function lockAt(lock, u)
	local x = (u % 1) * LOCK_SAMPLES
	local i = math.floor(x)
	local f = x - i
	return lock.c[i] + (lock.c[math.min(i + 1, LOCK_SAMPLES)] - lock.c[i]) * f
end

-- { Idle, Walk, Run } sampled animations from a folder of KeyframeSequences, or nil if any is missing/unreadable.
function GirlMoves.load(folder)
	if not folder then
		return nil
	end
	local out = {}
	for _, name in GirlMoves.NAMES do
		local seq = folder:FindFirstChild(name)
		if not (seq and seq.ClassName == "KeyframeSequence") then
			return nil
		end
		local ok, anim = pcall(Sampler.load, seq)
		if not (ok and anim and anim.length > 0) then
			return nil
		end
		out[name] = anim
	end
	local ok, locks = pcall(function()
		return { Walk = measureLock(out.Walk), Run = measureLock(out.Run) }
	end)
	if not ok or locks.Walk.stride < 0.5 or locks.Run.stride < 0.5 then
		return nil -- (not a walk we can read)
	end
	out.locks = locks
	return out
end

-- The game's copy (see the header), cached once read. Asks again at most every 2 s while it isn't there.
local cached, lastTry = nil, -math.huge
function GirlMoves.find(now: number)
	if cached or now - lastTry < 2 then
		return cached
	end
	lastTry = now
	local ok, RS = pcall(function() return game:GetService("ReplicatedStorage") end)
	if ok and RS then
		cached = GirlMoves.load(RS:FindFirstChild("HuzzGirlMoves")) or GirlMoves.load(RS:FindFirstChild("HuzzAnimations"))
	end
	return cached
end

--[[ A girl's player. anims: from load/find. rootHeight: her root above her feet (studs; sets her size). ]]
function GirlMoves.new(anims, rootHeight: number?)
	local P = Config.Pack
	local k = (rootHeight or R6_ROOT) / R6_ROOT
	local quick = 1 / math.sqrt(math.clamp(k, 0.3, 2)) -- smaller legs step quicker (and bigger ones slower)
	local C = {
		SpeedResponse = P.SpeedResponse,
		MoveFrom = P.MoveFrom * k, MoveFull = P.MoveFull * k,
		RunFrom = P.RunFrom * k, RunFull = P.RunFull * k,
		-- 1x = the speed at which the planted foot stays put (its stride over the loop's length)
		WalkAt = anims.locks.Walk.stride * k / anims.Walk.length, WalkRate = { P.WalkRate[1], P.WalkRate[2] * quick },
		RunAt = anims.locks.Run.stride * k / anims.Run.length, RunRate = { P.RunRate[1], P.RunRate[2] * quick },
		WalkPhase = P.WalkPhase, RunPhase = P.RunPhase,
		AirIn = 0.1, AirOut = 0.2, JumpHold = 0, ClimbAt = 1, -- (no jumping or climbing for the girls)
	}
	return { anims = anims, mix = Mix.new(C), k = k, t = 0, scale = k * 5.25 / R15_HEIGHT }
end

-- Blends sampled poses by weight: { {pose, w}, ... } (weights add up to 1).
local function blend(list)
	local out = {}
	local total = 0
	for _, item in list do
		local pose, w = item[1], item[2]
		if w > 1e-3 then
			total += w
			local f = w / total -- (running blend: each new pose takes its share of what's there so far)
			for name, cf in pose do
				local have = out[name]
				out[name] = if have then have:Lerp(cf, f) else cf
			end
		end
	end
	return out
end

-- The point at the bottom of a leg, in her root part's space (R6), from the joints as they are now.
local function footY(root, hip)
	local leg = hip.Part1
	local size = leg and leg.Size
	if not size then
		return nil
	end
	local inTorso = (hip.C0 * hip.Transform * hip.C1:Inverse()) * Vector3.new(0, -size.Y / 2, 0)
	return ((root.C0 * root.Transform * root.C1:Inverse()) * inTorso).Y
end
local function restY(root, hip)
	local leg = hip.Part1
	local inTorso = (hip.C0 * hip.C1:Inverse()) * Vector3.new(0, -leg.Size.Y / 2, 0)
	return ((root.C0 * root.C1:Inverse()) * inTorso).Y
end

-- Moves her whole body by d (studs, in her root part's space) on top of the pose.
local function shiftBody(root, d: Vector3)
	root.Transform = CFrame.new(root.C0.Rotation:Inverse() * d) * root.Transform
end

--[[ R6: moves her body up or down so the foot the animation stands on (side "L"/"R") touches the ground, never
	letting the other foot sink more than a sliver (Config.Pack.Clip times her size) into it. air 0-1: how much
	the planted foot may float (in a run, between steps). s (optional): her state, to smooth the shift so switching
	feet never pops. Returns the shift (studs, in her root's space). ]]
function GirlMoves.plant(J, air: number?, side: string?, s, dt: number?)
	local root, l, r = J.Root, J.LHip, J.RHip
	if J.Waist or not (root and l and r) then
		return 0 -- (R15 girls bend their knees: the animation's own hips are right)
	end
	local yl, yr = footY(root, l), footY(root, r)
	if not (yl and yr) then
		return 0
	end
	local rest = restY(root, l)
	local planted = if side == "R" then yr elseif side == "L" then yl else math.min(yl, yr)
	local shift = rest - planted
	if shift < 0 then
		shift *= 1 - math.clamp(air or 0, 0, 1) -- (above the ground: in a run she may stay up between steps)
	end
	local clip = Config.Pack.Clip * (if s then s.k else 1)
	local floor = rest - math.min(yl, yr) - clip -- (the other foot: at most a sliver into the ground)
	shift = math.max(shift, floor)
	if s and dt then
		s.shift = if s.shift then s.shift + (shift - s.shift) * (1 - math.exp(-dt * 30)) else shift
		shift = math.max(s.shift, floor - clip * 0.5)
	end
	shiftBody(root, Vector3.new(0, shift, 0))
	return shift
end

--[[ One frame. J: her joints, speed: her ground speed (studs/s), look: optional CFrame (a head turn in her torso's
	space) faded in while she stands. Returns the weights { Idle, Walk, Run }. ]]
function GirlMoves.step(s, J, dt: number, speed: number, look: CFrame?)
	local a = s.anims
	s.t += dt
	local mix = Mix.step(s.mix, dt, { speed = speed, state = "ground", lengths = { Walk = a.Walk.length, Run = a.Run.length } })
	local w = mix.weights
	local function at(anim, t, weight) -- (only the loops that show are sampled)
		return { if weight > 1e-3 then Sampler.sample(anim, t) else {}, weight }
	end
	local pose = blend({ at(a.Idle, s.t, w.Idle), at(a.Walk, mix.times.Walk, w.Walk), at(a.Run, mix.times.Run, w.Run) })
	if look and pose.Head then
		local turn = CFrame.identity:Lerp(look, math.clamp(w.Idle, 0, 1))
		pose.Head = turn * pose.Head
	end
	local side = stanceSide(pose)
	if J.Waist then
		Retarget.apply(J, pose, 1, s.scale) -- (R15 girl: the pack as it is)
		return w
	end
	capLean(pose, 30)
	footOverFoot(pose)
	Retarget.apply(J, pose, 1, s.scale)
	-- the lock: the animation's own surge within each step, so the planted foot stays put
	local surge = w.Walk * lockAt(a.locks.Walk, mix.times.Walk / a.Walk.length) + w.Run * lockAt(a.locks.Run, mix.times.Run / a.Run.length)
	if J.Root then
		shiftBody(J.Root, Vector3.new(0, 0, surge * s.k)) -- (+Z = back)
	end
	GirlMoves.plant(J, w.Run * 0.7, side, s, dt)
	return w
end

-- Standing only (the prize girl): the Idle loop, the head turn on top.
function GirlMoves.idle(s, J, dt: number, look: CFrame?)
	s.t += dt
	local pose = Sampler.sample(s.anims.Idle, s.t)
	if look and pose.Head then
		pose.Head = look * pose.Head
	end
	local side = stanceSide(pose)
	if not J.Waist then
		footOverFoot(pose)
	end
	Retarget.apply(J, pose, 1, s.scale)
	GirlMoves.plant(J, 0, side, s, dt)
end

return GirlMoves
