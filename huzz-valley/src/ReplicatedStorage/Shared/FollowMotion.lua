--[[
	A girl walking behind the catcher who caught her carrier. Pure maths, like
	CarryMotion: HuzzClient/Gameplay/CarryAnimator feeds it real parts and the
	offline preview runs it as is.

	Her root part is anchored; every client moves it on its own screen (so
	she's smooth for everyone with no network cost). She drops to the ground
	first if she starts in the air (stolen off a runner's head), then heads for
	her spot behind and beside the catcher (Carry.Follow), walking or running
	to keep up, and stands normally when he stops.

	Your companion (HuzzClient/Gameplay/Auras) uses the same code with her own
	settings (info.config = Config/GirlMotion.Companion): she matches your
	speed, never trails more than MaxLag, her stride grows when she runs (so
	her small legs don't blur), and rec.cheer = true makes her hop and cheer
	when she stands (beside you, at CheerOffset); rec.beside = true brings her to that spot too (dancing with
	you: Gameplay/CompanionDance poses her on top).

	Her legs and arms: the owner's movement pack (Idle / Walk / Run, Shared/GirlMoves) when rec.moves holds
	them (the caller sets it from GirlMoves.find), blended by her speed, her head watching the catcher while
	she stands; otherwise the built-in scripted walk (Shared/GirlMotion.walk). The cheer hops stay scripted.
]]
local Carry = require(script.Parent.Config.Carry)
local GirlMotion = require(script.Parent.GirlMotion)
local GirlMoves = require(script.Parent.GirlMoves)

local FollowMotion = {}
local exp, atan2, pi = math.exp, math.atan2, math.pi

-- info: root (her anchored root part), motors (her Motor6Ds), from (start position of her root,
-- or nil to start at her spot), rootHeight (root above her feet), seed,
-- animated (true = her limbs come from uploaded animations, so only move and turn her),
-- moves (optional: the pack's sampled Idle/Walk/Run from GirlMoves.find; can also be set on rec later),
-- config (optional: settings in place of Config/Carry.Follow, as Config/GirlMotion.Companion)
function FollowMotion.new(info)
	return {
		config = info.config,
		root = info.root,
		joints = GirlMotion.joints(info.motors or {}),
		girl = GirlMotion.new(info.seed or 1),
		pos = info.from,
		vel = Vector3.zero,
		fall = 0,
		yaw = nil,
		rootHeight = info.rootHeight or 3,
		animated = info.animated,
		moves = info.moves,
		speed = 0,
	}
end

local function turnToward(from, to, rate)
	local diff = (to - from + pi) % (2 * pi) - pi
	return from + diff * rate
end

-- leaderCF: the catcher's root CFrame. groundAt(position) -> ground height there (or nil).
-- watch: the head position she looks at when standing (or nil).
function FollowMotion.step(rec, dt, t, leaderCF, groundAt, watch)
	local F = rec.config or Carry.Follow
	local offset = if (rec.cheer or rec.beside) and F.CheerOffset then F.CheerOffset else F.Offset
	local spot = (leaderCF * CFrame.new(offset)).Position
	local jumped = rec.pos and (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(rec.pos.X, 0, rec.pos.Z)).Magnitude > F.TeleportDistance
	if not rec.pos or jumped then
		rec.pos, rec.vel = spot + Vector3.new(0, rec.rootHeight, 0), Vector3.zero
		rec.leaderAt, rec.leaderVel = nil, Vector3.zero
		if F.StartOnGround then -- (the companion appears standing, never dropping in)
			rec.pos = Vector3.new(spot.X, (groundAt(spot) or (spot.Y - 3)) + rec.rootHeight, spot.Z)
		end
	end

	-- (MatchSpeed) the leader's own speed along the ground, smoothed
	local lead = Vector3.zero
	if F.MatchSpeed then
		local here = leaderCF.Position
		if rec.leaderAt and dt > 0 then
			local v = (here - rec.leaderAt) / dt
			rec.leaderVel = (rec.leaderVel or Vector3.zero):Lerp(Vector3.new(v.X, 0, v.Z), 1 - exp(-dt * 10))
		end
		rec.leaderAt = here
		lead = rec.leaderVel or Vector3.zero
	end

	-- Head for her spot: faster the further behind she is, settling without overshoot.
	local gap = Vector3.new(spot.X - rec.pos.X, 0, spot.Z - rec.pos.Z)
	local dist = gap.Magnitude
	local want = if dist > F.StopDistance then gap.Unit * math.min(F.MaxSpeed, (dist - F.StopDistance) * F.Catchup) else Vector3.zero
	if F.MatchSpeed then
		want += lead
		if want.Magnitude > F.MaxSpeed then
			want = want.Unit * F.MaxSpeed
		end
	end
	rec.vel = rec.vel:Lerp(want, 1 - exp(-dt * 8))
	local pos = rec.pos + rec.vel * dt
	-- (MaxLag) never further than this from her spot: she's pulled along
	if F.MaxLag then
		local left = Vector3.new(pos.X - spot.X, 0, pos.Z - spot.Z)
		if left.Magnitude > F.MaxLag then
			local fix = left.Unit * F.MaxLag - left
			pos += fix
		end
	end

	-- Feet on the ground: falls if she's above it (stolen off a runner's head), steps up and down otherwise.
	local ground = groundAt(pos) or (spot.Y - 3)
	local standY = ground + rec.rootHeight
	if pos.Y > standY + 0.05 then
		rec.fall += 160 * dt
		pos = Vector3.new(pos.X, math.max(standY, pos.Y - rec.fall * dt), pos.Z)
	else
		rec.fall = 0
		pos = Vector3.new(pos.X, pos.Y + (standY - pos.Y) * (1 - exp(-dt * 20)), pos.Z)
	end
	rec.pos = pos

	-- Face where she's going; when standing, face the same way as the catcher.
	local speed = Vector3.new(rec.vel.X, 0, rec.vel.Z).Magnitude
	local look = if speed > 1 then rec.vel else leaderCF.LookVector
	local targetYaw = atan2(-look.X, -look.Z)
	rec.yaw = if rec.yaw then turnToward(rec.yaw, targetYaw, 1 - exp(-dt * 10)) else targetYaw
	rec.root.CFrame = CFrame.new(pos) * CFrame.Angles(0, rec.yaw, 0)

	rec.speed = speed
	if not rec.animated then
		local distance = if watch then (watch - pos).Magnitude else math.huge
		if rec.cheer and speed < 2 then
			-- little hops on the spot, landing back on the ground
			local hop = GirlMotion.cheer(rec.girl, rec.joints, dt, t, {})
			rec.root.CFrame += Vector3.new(0, hop * (F.HopHeight or 0.5), 0)
			return
		end
		rec.girl.cheerAge = 0
		local stride = F.Stride
		if F.MaxCadence then
			stride = math.max(stride, speed / F.MaxCadence)
		end
		if rec.moves then
			-- the owner's animations (Shared/GirlMoves), her head watching the leader while she stands
			if not rec.pack or rec.pack.anims ~= rec.moves then
				rec.pack = GirlMoves.new(rec.moves, rec.rootHeight)
			end
			GirlMoves.step(rec.pack, rec.joints, dt, speed, GirlMotion.look(rec.girl, rec.joints, dt, t, { target = watch, distance = distance }))
			return
		end
		local run = if F.RunFrom then math.clamp((speed - F.RunFrom) / (F.RunTo - F.RunFrom), 0, 1) else nil
		GirlMotion.walk(rec.girl, rec.joints, dt, t, { speed = speed, stride = stride, target = watch, distance = distance, run = run })
	end
end

return FollowMotion
