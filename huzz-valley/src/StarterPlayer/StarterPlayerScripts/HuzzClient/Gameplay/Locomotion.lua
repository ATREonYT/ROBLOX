--[[
	Your own idle, walk, run, jump, fall and climb, smooth like Huss Valley (owner: "make it more smooth just like
	in Huss Valley"). Roblox's Animate script is switched off on your character and this plays the owner's
	animations itself (Shared/AnimationLibrary: published, or raw in Studio), all at once on your Animator, their
	weights and speeds set every frame by Shared/LocomotionMix:
	  - cross-faded by your smoothed speed (no pops), the feet kept in step between walk and run;
	  - played at a calm rate (the run never frantic, a little foot slide at full speed);
	  - jump / fall / climb fade in over them in the lobby;
	  - a little lean into turns and into speeding up on top (Motor6D.Transform, Gameplay/Frame order 12: after
	    Roblox's animations and the scripted run, before the carry, the stab and the knockdown).
	Tracks on your own Animator replicate, so other players see the same. Dances and the stab are Action tracks: they
	play over all this (the lean holds still while they do); so does the huss (drawn by Gameplay/RunAnimator from
	DashAt, Config/Run.Dash.Length), so its quick turn and push don't tip the body. AvatarAnimations starts this only when
	the owner's Idle, Walk and Run can all play (otherwise Roblox's Animate stays, with their animations swapped in).
]]
local Locomotion = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Library = require(Shared.AnimationLibrary)
local DASH_LENGTH = require(Shared.Config.Run).Dash.Length
local Mix = require(Shared.LocomotionMix)
local Frame = require(script.Parent.Frame)

local current -- the running controller (one character at a time: yours)

local STATE = {
	[Enum.HumanoidStateType.Jumping] = "jump",
	[Enum.HumanoidStateType.Freefall] = "fall",
	[Enum.HumanoidStateType.Climbing] = "climb",
}

local function stopOthers(animator, keep)
	for _, t in animator:GetPlayingAnimationTracks() do
		if not keep[t] and t.Priority ~= Enum.AnimationPriority.Action then
			pcall(function() t:Stop(0.2) end)
		end
	end
end

local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return -- (the owner's animations are R15; an R6 avatar keeps Roblox's own)
	end
	local animator = humanoid:WaitForChild("Animator", 10) :: Animator?
	local root = humanoid.RootPart or character:WaitForChild("HumanoidRootPart", 10)
	if not (animator and root) or character.Parent == nil then
		return
	end

	-- Roblox's Animate would fight us (and time-warps the run to 1.5x at our speed): switch it off.
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 2)
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end

	local tracks, lengths, keep = {}, {}, {}
	for _, name in Mix.TRACKS do
		local id = Library.id(name)
		if id ~= "" then
			local a = Instance.new("Animation")
			a.Name = "Huzz" .. name
			a.AnimationId = id
			local ok, t = pcall(function() return (animator :: Animator):LoadAnimation(a) end)
			if ok and t then
				t.Priority = Enum.AnimationPriority.Movement
				t.Looped = name ~= "Jump"
				tracks[name] = t
				keep[t] = true
			end
		end
	end
	if not (tracks.Idle and tracks.Walk and tracks.Run) then
		if animate and animate:IsA("LocalScript") then animate.Disabled = false end
		return
	end
	task.defer(stopOthers, animator, keep) -- (whatever Animate had started before it stopped)

	local mix = Mix.new()
	local sent = {} -- name -> { weight, speed } last sent (only real changes go out: they replicate)
	for name, t in tracks do
		local w = mix.weights[name] or 0
		if name ~= "Jump" then
			t:Play(0.2, math.max(w, 0.001), 1)
		end
		sent[name] = { w, 1 }
	end
	local function lengthOf(name)
		local t = tracks[name]
		local len = t and t.Length or 0
		return if len > 0 then len else nil
	end

	local ctl = { character = character }
	local wasJumping = false
	local quietUntil = 0
	local lastScan = 0
	local written, base = nil, nil
	local rootJoint = (character:FindFirstChild("LowerTorso") and character.LowerTorso:FindFirstChild("Root")) :: Motor6D?

	-- Is an Action track (a dance, the dash, the stab) playing over us? Checked a few times a second.
	local function actionPlaying(now)
		if now - lastScan < 0.1 then
			return now < quietUntil
		end
		lastScan = now
		for _, t in (animator :: Animator):GetPlayingAnimationTracks() do
			if not keep[t] and t.Priority == Enum.AnimationPriority.Action and t.WeightCurrent > 0.05 then
				quietUntil = now + 0.25
				return true
			end
		end
		return now < quietUntil
	end

	function ctl.step(dt)
		if character.Parent == nil or humanoid.Health <= 0 then
			return
		end
		local state = humanoid:GetState()
		local mode = STATE[state] or "ground"
		local jumped = mode == "jump" and not wasJumping
		wasJumping = mode == "jump"
		local v = root.AssemblyLinearVelocity
		local downed = character:GetAttribute("DownedAt") ~= nil
		local speed = if downed or root.Anchored or state == Enum.HumanoidStateType.Seated then 0 else Vector3.new(v.X, 0, v.Z).Magnitude
		Mix.step(mix, dt, {
			speed = speed,
			state = mode,
			climbSpeed = v.Y,
			jumped = jumped,
			lengths = { Walk = lengthOf("Walk"), Run = lengthOf("Run") },
		})

		if jumped and tracks.Jump then
			tracks.Jump:Play(0.06, 1, 1)
			tracks.Jump.TimePosition = 0
		end
		for name, t in tracks do
			local w = mix.weights[name] or 0
			local sp = mix.speeds[name] or 1
			local last = sent[name]
			if math.abs(w - last[1]) > 0.01 or (w == 0 and last[1] ~= 0) or (w >= 0.999 and last[1] < 0.999) then
				t:AdjustWeight(math.max(w, 0.001), 0.05)
				last[1] = w
			end
			if math.abs(sp - last[2]) > 0.02 then
				t:AdjustSpeed(sp)
				last[2] = sp
			end
		end
		-- Walk and run stay in step: the one showing less is nudged onto the other's stride while it's barely
		-- visible (their speeds already match, so this is rare and never seen).
		local walk, run = tracks.Walk, tracks.Run
		local lead, follow = walk, run
		local leadPhase, followPhase = mix.C.WalkPhase, mix.C.RunPhase
		if mix.weights.Run > mix.weights.Walk then
			lead, follow, leadPhase, followPhase = run, walk, followPhase, leadPhase
		end
		local followW = if follow == run then mix.weights.Run else mix.weights.Walk
		if followW < 0.05 and lead.Length > 0 and follow.Length > 0 then
			local stride = (lead.TimePosition / lead.Length - leadPhase) % 1
			local want = ((stride + followPhase) % 1) * follow.Length
			local diff = math.abs(follow.TimePosition - want)
			if math.min(diff, follow.Length - diff) > 0.03 then
				follow.TimePosition = want
			end
		end

		-- the lean on top
		if rootJoint and rootJoint.Parent then
			local now = os.clock()
			local dashAt = character:GetAttribute("DashAt")
			local hussing = type(dashAt) == "number" and Workspace:GetServerTimeNow() - dashAt < DASH_LENGTH + 0.1
			local quiet = if downed or hussing or actionPlaying(now) or mode ~= "ground" then 1 else 0
			local look = root.CFrame.LookVector
			local roll, pitch = Mix.lean(mix, dt, math.atan2(-look.X, -look.Z), quiet)
			local pose = rootJoint.Transform
			if written and pose == written then
				pose = base -- (nothing animated the hips this frame: lean the last pose again, don't stack)
			end
			base = pose
			if math.abs(roll) + math.abs(pitch) > 1e-4 then
				-- turned about the ground under you (in the root part's space), then into the joint's own frame
				local c0 = rootJoint.C0
				local extra = c0:Inverse() * Mix.leanCFrame(roll, pitch, root.Size.Y / 2 + humanoid.HipHeight) * c0
				rootJoint.Transform = extra * pose
			end
			written = rootJoint.Transform
		end
	end

	function ctl.stop()
		for _, t in tracks do
			pcall(function() t:Stop(0.2) end)
		end
	end
	return ctl
end

function Locomotion.start()
	local player = Players.LocalPlayer
	local function onCharacter(character)
		if current then
			current.stop()
			current = nil
		end
		local ctl = attach(character)
		if ctl and player.Character == character then
			current = ctl
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	Frame.on(12, function(dt)
		if current then
			current.step(math.clamp(dt, 1 / 240, 1 / 15))
		end
	end)
end

-- True when this controller drives your walk and run (the owner's Idle, Walk and Run can all play here).
function Locomotion.available(): boolean
	return Library.has("Idle") and Library.has("Walk") and Library.has("Run")
end

return Locomotion
