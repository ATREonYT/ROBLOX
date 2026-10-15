--[[
	A girl walking behind the catcher who caught her carrier. Pure maths, like
	CarryMotion: HuzzClient/Gameplay/CarryAnimator feeds it real parts and the
	offline preview runs it as is.

	Her root part is anchored; every client moves it on its own screen (so
	she's smooth for everyone with no network cost). She drops to the ground
	first if she starts in the air (stolen off a runner's head), then heads for
	her spot behind and beside the catcher (Carry.Follow), walking or running
	to keep up, and stands normally when he stops.
]]
local Carry = require(script.Parent.Config.Carry)
local GirlMotion = require(script.Parent.GirlMotion)

local FollowMotion = {}
local exp, atan2, pi = math.exp, math.atan2, math.pi

-- info: root (her anchored root part), motors (her Motor6Ds), from (start position of her root,
-- or nil to start at her spot), rootHeight (root above her feet), seed
function FollowMotion.new(info)
	return {
		root = info.root,
		joints = GirlMotion.joints(info.motors or {}),
		girl = GirlMotion.new(info.seed or 1),
		pos = info.from,
		vel = Vector3.zero,
		fall = 0,
		yaw = nil,
		rootHeight = info.rootHeight or 3,
	}
end

local function turnToward(from, to, rate)
	local diff = (to - from + pi) % (2 * pi) - pi
	return from + diff * rate
end

-- leaderCF: the catcher's root CFrame. groundAt(position) -> ground height there (or nil).
-- watch: the head position she looks at when standing (or nil).
function FollowMotion.step(rec, dt, t, leaderCF, groundAt, watch)
	local F = Carry.Follow
	local spot = (leaderCF * CFrame.new(F.Offset)).Position
	if not rec.pos or (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(rec.pos.X, 0, rec.pos.Z)).Magnitude > F.TeleportDistance then
		rec.pos, rec.vel = spot + Vector3.new(0, rec.rootHeight, 0), Vector3.zero
	end

	-- Head for her spot: faster the further behind she is, settling without overshoot.
	local gap = Vector3.new(spot.X - rec.pos.X, 0, spot.Z - rec.pos.Z)
	local dist = gap.Magnitude
	local want = if dist > F.StopDistance then gap.Unit * math.min(F.MaxSpeed, (dist - F.StopDistance) * F.Catchup) else Vector3.zero
	rec.vel = rec.vel:Lerp(want, 1 - exp(-dt * 8))
	local pos = rec.pos + rec.vel * dt

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

	local distance = if watch then (watch - pos).Magnitude else math.huge
	GirlMotion.walk(rec.girl, rec.joints, dt, t, { speed = speed, stride = F.Stride, target = watch, distance = distance })
end

return FollowMotion
