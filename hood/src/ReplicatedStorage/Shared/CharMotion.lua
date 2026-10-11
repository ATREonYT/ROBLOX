-- (brief 29) Your character's gun arms, like the soldier game's: while you shoot (a range or a fight) both arms come up
-- and hold the gun out in front, and every shot kicks the arms and chest up and back (a spring: a snap, an overshoot,
-- settling); in a fight (goons up in your stage) you keep a ready stance, gun up, between shots. Your legs and the walk
-- stay Roblox's own animation: only the arms, chest and head are layered over it.
--   CharMotion.start()        once per client (HoodClient/Motion.client)
--   CharMotion.shot(power)    a shot just went off (Shoot.client on the ranges, Waves.client in fights); power ~1
--   CharMotion.target(state)  the pose weights for a state (pure: the unit tests read it)
-- How: every frame, after Roblox's Animator has written the joints (RunService.Stepped), each joint's Motor6D.Transform
-- is blended toward the pose by its weight. A joint the Animator left alone this frame is blended from the base it last
-- had, so nothing builds up, and at weight 0 it is handed back untouched. Local only: no assets, nothing sent.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local CharMotion = {}
local A = CFrame.Angles

-- Gun up in both hands: right arm straight out, the left reaching across to hold it, chest square.
CharMotion.Aim = {
	RightShoulder = A(0, 0.12, 0) * A(1.5, 0, 0), RightElbow = A(0.1, 0, 0),
	LeftShoulder = A(0, -0.8, 0) * A(1.38, 0, 0), LeftElbow = A(0.55, 0, 0),
	Waist = A(-0.04, 0.12, 0),
}
-- The fight's ready stance between shots: the same hold, a little lower, chest leaning in.
CharMotion.Ready = {
	RightShoulder = A(0, 0.22, 0) * A(1.15, 0, 0), RightElbow = A(0.45, 0, 0),
	LeftShoulder = A(0, -0.7, 0) * A(1.05, 0, 0), LeftElbow = A(0.8, 0, 0),
	Waist = A(-0.08, 0.1, 0),
}
CharMotion.AimHold = 0.6 -- the arms stay up this long after the last shot
CharMotion.In, CharMotion.Out = 14, 5 -- blend speeds (per second) into and out of the pose

local state = { last = -10, recoil = 0, vel = 0, w = 0, joints = {}, base = {}, wrote = {}, char = nil }

function CharMotion.shot(power)
	state.last = os.clock()
	state.vel += 7.5 * (power or 1)
end

local function fighting(player)
	local stage, left = player:GetAttribute('WaveStage'), player:GetAttribute('WaveLeft')
	return type(stage) == 'number' and stage > 0 and type(left) == 'number' and left > 0
end

-- What to hold and how much: aiming (just shot), ready (in a fight), or nothing.
function CharMotion.target(s)
	if s.sinceShot < CharMotion.AimHold then return CharMotion.Aim, 1 end
	if s.fight then return CharMotion.Ready, 1 end
	return CharMotion.Aim, 0
end

-- The recoil on top of the hold, r radians of kick: arms up, forearm flicks, chest and head rock back.
function CharMotion.recoil(r)
	return {
		RightShoulder = A(r * 0.9, 0, 0), RightElbow = A(r * 0.7, 0, 0),
		LeftShoulder = A(r * 0.6, 0, 0), LeftElbow = A(r * 0.4, 0, 0),
		Waist = A(r * 0.22, 0, 0), Neck = A(r * 0.18, 0, 0),
	}
end

local NAMES = { 'RightShoulder', 'RightElbow', 'LeftShoulder', 'LeftElbow', 'Waist', 'Neck' }
local function bind(character)
	table.clear(state.joints)
	table.clear(state.base)
	table.clear(state.wrote)
	state.char = character
	if not character then return end
	for _, d in character:GetDescendants() do
		if d:IsA('Motor6D') and table.find(NAMES, d.Name) then state.joints[d.Name] = d end
	end
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
			local pose, want = CharMotion.target({ sinceShot = os.clock() - state.last, fight = fighting(player) })
			local speed = want > state.w and CharMotion.In or CharMotion.Out
			state.w += (want - state.w) * (1 - math.exp(-speed * dt))
			if state.w < 1e-3 and math.abs(state.recoil) < 1e-3 then
				-- hand every joint back
				for name, m in state.joints do
					if state.wrote[name] then
						if m.Transform == state.wrote[name] then m.Transform = state.base[name] or CFrame.identity end
						state.wrote[name] = nil
					end
				end
				return
			end
			local kick = CharMotion.recoil(state.recoil)
			for name, m in state.joints do
				local now = m.Transform
				-- (the Animator wrote it this frame: that's the base; else it's still what we wrote, so keep the old base)
				if state.wrote[name] == nil or now ~= state.wrote[name] then state.base[name] = now end
				local base = state.base[name] or CFrame.identity
				local held = pose[name] and base:Lerp(pose[name], state.w) or base
				local out = held * (kick[name] or CFrame.identity)
				m.Transform = out
				state.wrote[name] = out
			end
		end)
	end)
	return ok
end

return CharMotion
