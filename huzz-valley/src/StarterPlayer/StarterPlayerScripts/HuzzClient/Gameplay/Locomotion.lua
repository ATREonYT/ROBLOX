--[[
	Your own idle, walk, run, jump, fall and climb, smooth like Huss Valley (owner: "make it more smooth just like
	in Huss Valley"). Roblox's Animate script is switched off on your character and this plays the owner's
	animations itself (Shared/AnimationLibrary: published, or raw in Studio), all at once on your Animator, their
	weights and speeds set every frame by Shared/LocomotionMix:
	  - cross-faded by your smoothed speed (no pops), the feet kept in step between walk and run;
	  - each loop played at the speed that keeps its feet planted (Config/Run.Loco, Oct 18: "make the walking
	    animations way way better"), scaled to your avatar's size, the run capped at HV's ~4.6 steps a second;
	  - jump / fall / climb fade in over them in the lobby;
	  - a little lean into turns and into speeding up on top (Motor6D.Transform, Gameplay/Frame order 12: after
	    Roblox's animations and the scripted run, before the carry, the stab and the knockdown);
	  - in shift lock, the hips and legs turn toward the way you move and the head keeps looking where you aim
	    (Shared/LocomotionMix.strafe, owner Oct 19: "the only thing that moves when you press w a s d (etc) is their
	    body not their head"); moving backwards plays the loops backwards. Your screen only: everyone else draws it
	    from your body's movement (Gameplay/PlayerMoves);
	  - without shift lock (the lobby, Alt held) Roblox turns your body to the move and the head turns back toward
	    where the camera looks (LocomotionMix.look, owner Oct 19 18:16: "when he presses D, the body turns right, but
	    the head and camera stays the same");
	  - setting off walks first and a stop from a run plays a quick plant (LocomotionMix SetOff / Stop, measured on
	    Huss Valley's recording): the arms swing out on the shoulders here.
	Published tracks replicate, so other players see the same. Studio's temporary copies play only on this screen:
	there Gameplay/PlayerMoves draws your walk on everyone else's screen by hand (it skips you here while
	Locomotion.drives(character) says this runs). Dances and the stab are Action tracks: they
	play over all this (the lean holds still while they do); so does the huss (drawn by Gameplay/RunAnimator from
	DashAt, Config/Run.Dash.Length), so its quick turn and push don't tip the body. AvatarAnimations starts this only when
	the owner's Idle, Walk and Run can all play (otherwise Roblox's Animate stays, with their animations swapped in).
]]
local Locomotion = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Library = require(Shared.AnimationLibrary)
local RunConfig = require(Shared.Config.Run)
local DASH_LENGTH = RunConfig.Dash.Length
local LEAP_LENGTH = 0.85 -- seconds a catcher's leap owns the body (Shared/StabMotion LEAP.Up, plus a little)
local Mix = require(Shared.LocomotionMix)
local RunMotion = require(Shared.RunMotion)
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

	-- (a bigger avatar's legs take longer steps: every speed scales with its height)
	local size = math.clamp((humanoid.HipHeight + root.Size.Y / 2) / RunConfig.Loco.RootHeight, 0.5, 2)
	local mix = Mix.new(Mix.sized(RunConfig.Loco, size))
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
	local written, base = {}, {} -- motor -> what we last wrote / the animation's pose under it (never stack)
	local function jointOf(partName, jointName): Motor6D?
		local part = character:FindFirstChild(partName)
		local j = part and part:FindFirstChild(jointName)
		return if j and j:IsA("Motor6D") then j else nil
	end
	local rootJoint = jointOf("LowerTorso", "Root")
	local waistJoint, neckJoint = jointOf("UpperTorso", "Waist"), jointOf("Head", "Neck")
	local rightArm, leftArm = jointOf("RightUpperArm", "RightShoulder"), jointOf("LeftUpperArm", "LeftShoulder")
	-- This frame's animated pose of a joint (or the last one, if nothing animated it since our write: never stack).
	local function current(motor: Motor6D): CFrame
		local pose = motor.Transform
		if written[motor] and pose == written[motor] then
			pose = base[motor]
		end
		base[motor] = pose
		return pose
	end
	local function put(motor: Motor6D, cf: CFrame)
		if motor.Transform ~= cf then
			motor.Transform = cf
		end
		written[motor] = motor.Transform -- read back: Roblox stores CFrames as float32
	end

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
			if mix.back and (name == "Walk" or name == "Run") then
				sp = -sp -- (back-pedalling in shift lock: the loop plays backwards)
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
			local dashAt = RunMotion.dashAt(character)
			local hussing = type(dashAt) == "number" and Workspace:GetServerTimeNow() - dashAt < DASH_LENGTH + 0.1
			local lungeAt = character:GetAttribute("LungeAt")
			local leaping = type(lungeAt) == "number" and Workspace:GetServerTimeNow() - lungeAt < LEAP_LENGTH
			local quiet = if downed or hussing or leaping or actionPlaying(now) or mode ~= "ground" then 1 else 0
			local look = root.CFrame.LookVector
			local roll, pitch = Mix.lean(mix, dt, math.atan2(-look.X, -look.Z), quiet)
			local hipsPose = current(rootJoint)
			if math.abs(roll) + math.abs(pitch) > 1e-4 then
				-- turned about the ground under you (in the root part's space), then into the joint's own frame
				local c0 = rootJoint.C0
				hipsPose = c0:Inverse() * Mix.leanCFrame(roll, pitch, root.Size.Y / 2 + humanoid.HipHeight) * c0 * hipsPose
			end
			-- shift lock: hips toward the move, the head still looking where you aim (Shared/LocomotionMix.strafe);
			-- without it: the body goes the way you move, the head looks where the camera looks (LocomotionMix.look)
			local locked = player:GetAttribute("HuzzShiftLock") == true
			local turn = Mix.strafe(mix, dt, root.CFrame:VectorToObjectSpace(v), locked, quiet)
			local cam = Workspace.CurrentCamera
			local aim = 0
			if cam then
				local l = root.CFrame:VectorToObjectSpace(cam.CFrame.LookVector)
				aim = math.atan2(l.X, -l.Z) -- (0 = the camera looks the way you face, + = to your right)
			end
			local look = Mix.look(mix, dt, aim, not locked and cam ~= nil, quiet)
			if waistJoint and neckJoint and waistJoint.Parent and neckJoint.Parent then
				local waistPose, neckPose = current(waistJoint), current(neckJoint)
				if math.abs(turn) > 1e-3 or math.abs(look) > 1e-3 then
					hipsPose, waistPose, neckPose = Mix.strafePose(mix, turn, {
						root = { C0 = rootJoint.C0, C1 = rootJoint.C1, T = hipsPose },
						waist = { C0 = waistJoint.C0, C1 = waistJoint.C1, T = waistPose },
						neck = { C0 = neckJoint.C0, C1 = neckJoint.C1, T = neckPose },
					}, look)
				end
				put(waistJoint, waistPose)
				put(neckJoint, neckPose)
			end
			put(rootJoint, hipsPose)
			-- the stop's plant: the arms swing out as the feet come together (LocomotionMix.stopAmount)
			local plant = if quiet > 0 then 0 else Mix.stopAmount(mix)
			for side, arm in { [1] = rightArm, [-1] = leftArm } do
				if arm and arm.Parent then
					local pose = current(arm)
					put(arm, if plant > 1e-4 then Mix.stopArm(mix, plant, side) * pose else pose)
				end
			end
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

-- True while this controller is playing the pack on this character (yours, its tracks loaded).
function Locomotion.drives(character: Model?): boolean
	return current ~= nil and character ~= nil and current.character == character and character.Parent ~= nil
end

return Locomotion
