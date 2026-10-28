-- (brief 29) Your character's gun arms, like the soldier game's (bible 2.6, matched side by side to its clips in brief 30):
--   * with the gun in your hand you ALWAYS hold it (Hold): the right hand at chest height, the gun pointing ahead, the
--     left arm bent in front; a slow, small breath while you stand; in the walk and the run the arms stay up with a
--     light counter-swing taken from your own legs (the Animator's hips), no lean;
--   * a shot: the gun arm straight out at the target (Aim), the other arm stays bent; each shot kicks it a little (a
--     spring: a snap, an overshoot, settling: small, like the reference's, which barely moves);
--   * in a fight (goons up in your stage) the ready stance between shots (Ready): the hold, the gun a little higher.
-- Your legs and the walk stay Roblox's own animation: only the arms, chest and head are layered over it.
--   CharMotion.start()        once per client (HoodClient/Motion.client)
--   CharMotion.shot(power)    a shot just went off (Shoot.client on the ranges, Waves.client in fights); power ~1
--   CharMotion.target(state)  the pose weights for a state (pure: the unit tests read it)
--   (brief 30, "more fighting animations just like in the references")
--   CharMotion.melee(n)       a swing (Waves.client, a goon in contact): the reference's close-range swings into the scrum,
--                             in turn a gun-hand swipe from the right and a left hook (n odd / even): wound back by 0.07 s,
--                             swept across by 0.15 s, back by SwingTime
--   CharMotion.hurt(power)    a punch landed on you: the chest and head snap back, the arms fly out, and spring back
--   CharMotion.down(on)       knocked down (the revive screen): the arms flung out while you lie there
--   CharMotion.swingPose(t, n) the swing's joint pose and weight at t seconds (pure: the previews and tests read it)
-- (brief 30, the user: "make the animations smooth though") What this layers over the Animator's pose rides Shared/
-- JointSpring's damped springs per joint, stepped with the frame's dt: a stance change (aim to ready), a swing, a hit and
-- the knockdown cross-fade instead of snapping, the arms follow through a swing, the chest lags, the head settles.
-- How: every frame, after Roblox's Animator has written the joints (RunService.Stepped), each joint's Motor6D.Transform
-- is blended toward the pose by its weight. A joint the Animator left alone this frame is blended from the base it last
-- had, so nothing builds up, and at weight 0 it is handed back untouched. Local only: no assets, nothing sent.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local JointSpring = require(script.Parent.JointSpring)
local okAR, AnimationRules = pcall(require, script.Parent.AnimationRules)

local CharMotion = {}
local A = CFrame.Angles

-- (brief 30) A shot: the gun arm straight out at the target, the other arm stays bent by the chest (the reference aims
-- one-handed: W 9.3-12.3 s on the 1x lane, W 31.4 s in the fight), the chest turned a touch into it.
CharMotion.Aim = {
	RightShoulder = A(0, 0.08, 0) * A(1.55, 0, 0), RightElbow = A(0.05, 0, 0),
	LeftShoulder = A(0, -0.4, 0) * A(0.6, 0, 0), LeftElbow = A(1.0, 0, 0),
	Waist = A(0, 0.1, 0),
}
-- (brief 30) Always, with the gun in your hand (W 50.6-52.4 s standing, W 27.5-30 s running): the gun at chest height
-- pointing ahead, the left arm bent in front; upright, no lean.
CharMotion.Hold = {
	RightShoulder = A(0, 0.3, 0) * A(0.95, 0, 0), RightElbow = A(0.65, 0, 0),
	LeftShoulder = A(0, -0.55, 0) * A(0.75, 0, 0), LeftElbow = A(1.15, 0, 0),
	Waist = A(0, 0.06, 0),
}
-- The fight's ready stance between shots: the hold with the gun a little higher (still no lean: the reference runs
-- upright into its fights).
CharMotion.Ready = {
	RightShoulder = A(0, 0.25, 0) * A(1.32, 0, 0), RightElbow = A(0.42, 0, 0),
	LeftShoulder = A(0, -0.6, 0) * A(0.85, 0, 0), LeftElbow = A(1.1, 0, 0),
	Waist = A(0, 0.06, 0),
}
CharMotion.AimHold = 0.6 -- the arm stays out this long after the last shot (at 3 shots a second it stays out)
-- (brief 30) The breath while you stand: the chest rises and the arms with it, one slow cycle every 3 s, barely there
-- (the reference shows no sway at 15 fps). The run's counter-swing: each arm swings with the other side's hip.
CharMotion.Breath, CharMotion.BreathHz = 0.018, 0.33
CharMotion.Swing = 0.25
CharMotion.Kick = 2.6 -- the shot's kick (the spring's push per shot; was 7.5 before brief 30: the reference's arm barely moves)
-- (brief 30) The two swings: wound back, then swept across (yaw > 0 takes the right arm across to the left).
CharMotion.SwingTime = 0.3
CharMotion.Swings = {
	{ -- a swipe with the gun hand, right to left
		Wind = { RightShoulder = A(0, -0.95, 0) * A(1.25, 0, 0.25), RightElbow = A(0.9, 0, 0), LeftShoulder = A(0, -0.5, 0) * A(1.0, 0, 0), LeftElbow = A(0.9, 0, 0), Waist = A(0.05, -0.5, 0), Neck = A(0, 0.2, 0) },
		Hit = { RightShoulder = A(0, 0.95, 0) * A(1.5, 0, -0.1), RightElbow = A(0.12, 0, 0), LeftShoulder = A(0, -0.2, 0) * A(0.35, 0, -0.3), LeftElbow = A(0.8, 0, 0), Waist = A(-0.08, 0.6, 0), Neck = A(-0.05, -0.25, 0) },
	},
	{ -- a left hook, left to right
		Wind = { LeftShoulder = A(0, 0.95, 0) * A(1.25, 0, -0.25), LeftElbow = A(1.1, 0, 0), RightShoulder = A(0, 0.4, 0) * A(1.1, 0, 0), RightElbow = A(0.6, 0, 0), Waist = A(0.05, 0.5, 0), Neck = A(0, -0.2, 0) },
		Hit = { LeftShoulder = A(0, -0.9, 0) * A(1.5, 0, 0.1), LeftElbow = A(0.5, 0, 0), RightShoulder = A(0, 0.2, 0) * A(0.5, 0, 0.3), RightElbow = A(0.9, 0, 0), Waist = A(-0.08, -0.6, 0), Neck = A(-0.05, 0.25, 0) },
	},
}
-- Knocked down: the whole body laid on its back about the hips (the Root joint: your HumanoidRootPart itself never
-- moves, Waves.client holds it still), the arms flung out to the sides, the head turned.
CharMotion.Down = { Root = CFrame.new(0, -1.45, 0) * A(1.5, 0, 0), RightShoulder = A(0.2, 0, 1.35), RightElbow = A(0.4, 0, 0), LeftShoulder = A(0.2, 0, -1.35), LeftElbow = A(0.4, 0, 0), Neck = A(0.3, 0.4, 0) }
CharMotion.In, CharMotion.Out = 14, 5 -- blend speeds (per second) into and out of the pose

local state = { last = -10, recoil = 0, vel = 0, w = 0, joints = {}, base = {}, wrote = {}, char = nil, swing = -10, swingN = 1, hurt = 0, hurtV = 0, down = false, downW = 0, springs = JointSpring.new(), hips = {} }

function CharMotion.shot(power)
	state.last = os.clock()
	state.vel += CharMotion.Kick * (power or 1)
end
-- (Oct 28, the feel round) the owner's fight moves (Config/Animations Punch, Kick) when their ids are set: swings go
-- Punch, Punch, Kick; the drawn swings stand in for any move without one. Returns 'Animation' or 'Drawn'.
CharMotion.MeleeMoves = { 'Punch', 'Punch', 'Kick' }
function CharMotion.meleeMove(n)
	return CharMotion.MeleeMoves[((n or 1) - 1) % #CharMotion.MeleeMoves + 1]
end
local tracks = {} -- (this character's loaded fight moves; false: that move has no id)
local function playMove(move)
	if not okAR or not AnimationRules.oneShot then return false end
	local c = state.char
	local hum = c and c:FindFirstChildOfClass('Humanoid')
	local animator = hum and hum:FindFirstChildOfClass('Animator')
	if not animator then return false end
	local tr = tracks[move]
	if tr == nil then
		tr = AnimationRules.oneShot(animator, move) or false
		tracks[move] = tr
	end
	if not tr then return false end
	local ok = pcall(function() tr:Play(0.05, 1, 1.15) end)
	if ok then
		local len = 0.45
		pcall(function() if tr.Length > 0 then len = tr.Length / 1.15 end end)
		state.animUntil = os.clock() + len
	end
	return ok
end
function CharMotion.melee(n)
	if playMove(CharMotion.meleeMove(n)) then
		state.swing = -10
		return 'Animation'
	end
	state.last = os.clock()
	state.swing = os.clock()
	state.swingN = ((n or 1) - 1) % #CharMotion.Swings + 1
	return 'Drawn'
end
-- (Oct 28, the feel round) hit-stop: the swing holds the frame it landed on for `seconds` (the goon holds it too)
function CharMotion.hitStop(seconds)
	if os.clock() - state.swing < CharMotion.SwingTime then state.swing += math.clamp(seconds or 0, 0, 0.15) end
end
function CharMotion.hurt(power)
	state.hurtV += 9 * (power or 1)
end
function CharMotion.down(on)
	state.down = on == true
end
-- The swing at t seconds: (pose, weight): wound back by 0.07 s, swept across by 0.15 s, held a beat, back by SwingTime.
local function smooth(a) a = math.clamp(a, 0, 1) return a * a * (3 - 2 * a) end
function CharMotion.swingPose(t, n)
	local sw = CharMotion.Swings[((n or 1) - 1) % #CharMotion.Swings + 1]
	if t < 0 or t >= CharMotion.SwingTime then return sw.Hit, 0 end
	local out = {}
	if t < 0.07 then
		local k = smooth(t / 0.07)
		for name, cf in sw.Wind do out[name] = cf end
		return out, k
	end
	local k = math.min(1, (t - 0.07) / 0.08)
	k = 1 - (1 - k) ^ 3 -- (snaps across)
	for name, cf in sw.Wind do out[name] = cf:Lerp(sw.Hit[name] or cf, k) end
	for name, cf in sw.Hit do if not out[name] then out[name] = cf end end
	local w = t < 0.19 and 1 or 1 - smooth((t - 0.19) / (CharMotion.SwingTime - 0.19))
	return out, w
end
-- (brief 30: a punch landed: chest and head back, arms out)
local function hurtKick(h)
	return { Waist = A(h * 0.45, 0, h * 0.12), Neck = A(h * 0.55, 0, 0), RightShoulder = A(0, 0, h * 0.7), LeftShoulder = A(0, 0, -h * 0.7) }
end

local function fighting(player)
	local stage, left = player:GetAttribute('WaveStage'), player:GetAttribute('WaveLeft')
	return type(stage) == 'number' and stage > 0 and type(left) == 'number' and left > 0
end

-- What to hold and how much: aiming (just shot), ready (in a fight), holding the gun (armed: a gun in your hand), or
-- nothing (no gun: Roblox's own arms).
function CharMotion.target(s)
	if s.sinceShot < CharMotion.AimHold then return CharMotion.Aim, 1 end
	if s.fight then return CharMotion.Ready, 1 end
	if s.armed then return CharMotion.Hold, 1 end
	return CharMotion.Hold, 0
end

-- The recoil on top of the pose, r radians of kick: the gun arm up, the forearm flicks, chest and head rock back a hair.
function CharMotion.recoil(r)
	return {
		RightShoulder = A(r * 0.9, 0, 0), RightElbow = A(r * 0.7, 0, 0),
		LeftShoulder = A(r * 0.2, 0, 0), LeftElbow = A(r * 0.1, 0, 0),
		Waist = A(r * 0.12, 0, 0), Neck = A(r * 0.1, 0, 0),
	}
end

-- (brief 30) The layer that lives under the pose while you hold the gun: the breath (standing still) and the run's
-- counter-swing (each arm with the other side's hip, so it keeps time with the Animator's legs). hipR / hipL: the hips'
-- forward swing (radians, + forward); still: 1 standing .. 0 moving; t: seconds.
function CharMotion.life(hipR, hipL, still, t)
	local b = CharMotion.Breath * still * math.sin(t * CharMotion.BreathHz * 2 * math.pi)
	local k = CharMotion.Swing * (1 - still)
	return {
		RightShoulder = A(k * hipL - b * 0.6, 0, 0), LeftShoulder = A(k * hipR - b * 0.6, 0, 0),
		Waist = A(b, 0.08 * k * (hipR - hipL), 0),
	}
end

local NAMES = { 'RightShoulder', 'RightElbow', 'LeftShoulder', 'LeftElbow', 'Waist', 'Neck', 'Root' }
-- (brief 30) "is the joint still what we wrote last frame?" within a hair, not bit for bit: a Transform read back can
-- differ from the CFrame written in its last float bits, and an exact test would then take our own pose for the
-- Animator's and build on it (a knockdown that never lets go)
local function ours(now, wrote)
	return wrote ~= nil and now:FuzzyEq(wrote, 1e-4)
end
local function bind(character)
	table.clear(state.joints)
	table.clear(state.base)
	table.clear(state.wrote)
	state.springs = JointSpring.new()
	state.char = character
	state.hips = {}
	table.clear(tracks)
	if not character then return end
	for _, d in character:GetDescendants() do
		if d:IsA('Motor6D') and table.find(NAMES, d.Name) then state.joints[d.Name] = d end
		if d:IsA('Motor6D') and (d.Name == 'RightHip' or d.Name == 'LeftHip') then state.hips[d.Name] = d end
	end
end
-- (brief 30) a gun in the hand (the Tool GunService gives you: GunTool.is)
local function armed(c)
	for _, child in c:GetChildren() do
		if child:IsA('Tool') and child:GetAttribute('GunId') ~= nil then return true end
	end
	return false
end
local function hipSwing(m)
	if not m then return 0 end
	local rx = m.Transform:ToEulerAnglesXYZ()
	return rx
end

local started = false
function CharMotion.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	if not player then return end
	player.CharacterAdded:Connect(function(c)
		task.wait(0.5) -- (its joints arrive with it)
		bind(c)
	end)
	if player.Character then bind(player.Character) end
	local ok = pcall(function()
		RunService.Stepped:Connect(function(_, dt)
			dt = math.min(dt, 0.1)
			local c = player.Character
			if c ~= state.char then bind(c) end
			local hum = c and c:FindFirstChildOfClass('Humanoid')
			if not hum or hum.Health <= 0 or hum.RigType ~= Enum.HumanoidRigType.R15 then return end
			-- the kick: a stiff spring, a little under-damped so it overshoots once
			local k, z = 520, 2 * math.sqrt(520) * 0.42
			state.vel += (-k * state.recoil - z * state.vel) * dt
			state.recoil = math.clamp(state.recoil + state.vel * dt, -0.15, 0.6)
			-- (brief 30) the hurt kick: a softer spring, overshooting once; the knocked-down pose blends in and out
			local kh, zh = 260, 2 * math.sqrt(260) * 0.45
			state.hurtV += (-kh * state.hurt - zh * state.hurtV) * dt
			state.hurt = math.clamp(state.hurt + state.hurtV * dt, -0.3, 0.9)
			state.downW += ((state.down and 1 or 0) - state.downW) * (1 - math.exp(-12 * dt))
			local pose, want = CharMotion.target({ sinceShot = os.clock() - state.last, fight = fighting(player), armed = armed(c) })
			-- (Oct 28) one of the owner's fight moves is playing: our layer steps aside for it
			if os.clock() < (state.animUntil or 0) then want = 0 end
			-- (brief 30) the breath and the run's counter-swing, under the hold and the ready stance
			-- (how fast you move, from where your root was last frame: walking reads ~0.5, running 1)
			local r = c:FindFirstChild('HumanoidRootPart')
			local at = r and r.CFrame.Position or Vector3.zero
			local d = state.lastPos and (at - state.lastPos) or Vector3.zero
			state.lastPos = at
			local pace = dt > 0 and Vector3.new(d.X, 0, d.Z).Magnitude / dt or 0
			local moving = pace > 40 and 0 or math.clamp((pace - 1) / 7, 0, 1) -- (a teleport is not a run)
			state.still = (state.still or 1) + (1 - moving - (state.still or 1)) * (1 - math.exp(-6 * dt))
			local life = pose ~= CharMotion.Aim and CharMotion.life(hipSwing(state.hips.RightHip), hipSwing(state.hips.LeftHip), state.still, os.clock()) or nil
			local swingPose, swingW = CharMotion.swingPose(os.clock() - state.swing, state.swingN)
			local speed = want > state.w and CharMotion.In or CharMotion.Out
			state.w += (want - state.w) * (1 - math.exp(-speed * dt))
			if state.w < 1e-3 and math.abs(state.recoil) < 1e-3 and swingW < 1e-3 and math.abs(state.hurt) < 1e-3 and state.downW < 1e-3 and JointSpring.resting(state.springs, 2e-3) then
				-- hand every joint back
				for name, m in state.joints do
					if state.wrote[name] then
						if ours(m.Transform, state.wrote[name]) then m.Transform = state.base[name] or CFrame.identity end
						state.wrote[name] = nil
					end
				end
				return
			end
			local kick = CharMotion.recoil(state.recoil)
			local hurt = hurtKick(state.hurt)
			for name, m in state.joints do
				local now = m.Transform
				-- (the Animator wrote it this frame: that's the base; else it's still what we wrote, so keep the old base)
				if not ours(now, state.wrote[name]) then state.base[name] = now end
				local base = state.base[name] or CFrame.identity
				local held = pose[name] and base:Lerp(life and life[name] and pose[name] * life[name] or pose[name], state.w) or base
				if swingW > 1e-3 and swingPose[name] then held = held:Lerp(swingPose[name], swingW) end
				if state.downW > 1e-3 and CharMotion.Down[name] then held = held:Lerp(CharMotion.Down[name], state.downW) end
				local out = held * (kick[name] or CFrame.identity) * (hurt[name] or CFrame.identity)
				-- (only our layer rides the spring: the Animator's own motion underneath passes straight through)
				out = base * JointSpring.step(state.springs, name, base:Inverse() * out, dt)
				m.Transform = out
				state.wrote[name] = out
			end
			JointSpring.done(state.springs)
		end)
	end)
	return ok
end

return CharMotion
