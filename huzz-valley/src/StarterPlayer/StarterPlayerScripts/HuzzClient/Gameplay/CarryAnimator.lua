--[[
	Runs the girl animations on this client. The motion itself lives in
	Shared/CarryMotion and Shared/GirlMotion, which is the same code the offline
	preview runs. This script feeds them real parts every frame:
	  - every carried girl (Workspace.HuzzCarried): the pickup flight, the carrier's
	    raised arms and lean, and her limbs and mood (model attributes Mood, MoodAt);
	  - the prize girl (tag "HuzzPrize"): her idle, watching the nearest player;
	  - a girl following a catcher (tag "HuzzFollower", Shared/FollowMotion): she drops
	    to the ground, then walks or runs behind him and stands when he stops.
	It writes Motor6D.Transform in PreSimulation, after Roblox's animations, so
	walk, run and huss animations keep the legs. An upper-body animation ID in
	Config/Animations.CarryArms replaces the scripted arms.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)
	local CarryMotion = require(Shared.CarryMotion)
	local GirlMotion = require(Shared.GirlMotion)
	local FollowMotion = require(Shared.FollowMotion)

	local folder = Workspace:WaitForChild("HuzzCarried")
	local useArmAnimation = Animations.CarryArms ~= ""
	local carries = {} -- model -> { rec, model, humanoid, armTrack }
	local prizes = {} -- model -> { state, joints, root }
	local followers = {} -- model -> FollowMotion record (+ leaderId)

	local function motorsOf(model, except)
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d ~= except then
				table.insert(list, d)
			end
		end
		return list
	end

	local function seedOf(model)
		local seed = 0
		for i = 1, #model.Name do
			seed = (seed * 31 + string.byte(model.Name, i)) % 1000003
		end
		return seed
	end

	local function stopCarry(model)
		local c = carries[model]
		if not c then
			return
		end
		carries[model] = nil
		CarryMotion.release(c.rec)
		if c.armTrack then
			c.armTrack:Stop(0.25)
		end
	end

	local function startCarry(model)
		local motor = model:WaitForChild("HuzzCarryMotor", 10)
		local torso = motor and motor.Part0
		local character = torso and torso.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rig = character and CarryMath.rig(character)
		if not (humanoid and humanoid.RootPart and rig) or not model.Parent then
			return
		end
		local c = {
			model = model,
			humanoid = humanoid,
			rec = CarryMotion.new({
				motor = motor,
				rig = rig,
				root = humanoid.RootPart,
				girlMotors = motorsOf(model, motor),
				start = model:GetAttribute("Start") or Workspace:GetServerTimeNow(),
				from = model:GetAttribute("From"),
				seed = seedOf(model),
				useArmAnimation = useArmAnimation,
			}),
		}
		if useArmAnimation and character == Players.LocalPlayer.Character then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local animation = Instance.new("Animation")
				animation.AnimationId = Animations.CarryArms
				c.armTrack = animator:LoadAnimation(animation)
				c.armTrack.Priority = Enum.AnimationPriority.Action
				c.armTrack.Looped = true
				c.armTrack:Play(0.2)
			end
		end
		carries[model] = c
	end

	local function startPrize(model)
		local root = model.PrimaryPart
		if root then
			prizes[model] = { state = GirlMotion.new(seedOf(model)), joints = GirlMotion.joints(motorsOf(model)), root = root }
		end
	end

	-- The nearest player's head to a point.
	local function nearestHead(position)
		local best, bestDist = nil, math.huge
		for _, p in Players:GetPlayers() do
			local head = p.Character and p.Character:FindFirstChild("Head")
			if head then
				local d = (head.Position - position).Magnitude
				if d < bestDist then
					best, bestDist = head.Position, d
				end
			end
		end
		return best, bestDist
	end

	-- The owner's girl walk/run/idle animations (Config/Animations), played on this client.
	local function loadGirlTracks(model)
		if Animations.GirlWalk == "" then
			return nil
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if not animator then
			return nil
		end
		local tracks = {}
		for key, id in { Idle = Animations.GirlIdle, Walk = Animations.GirlWalk, Run = Animations.GirlRun } do
			if id ~= "" then
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local ok, track = pcall(animator.LoadAnimation, animator, animation)
				if ok then
					track.Looped = true
					track:Play(0.2, 0.001)
					tracks[key] = track
				end
			end
		end
		return tracks
	end

	-- Blends idle / walk / run by her speed and plays them at a matching rate.
	local function driveGirlTracks(tracks, speed)
		local walkSpeed, runSpeed = Animations.GirlWalkSpeed, Animations.GirlRunSpeed
		local run = if tracks.Run then math.clamp((speed - walkSpeed) / (runSpeed - walkSpeed), 0, 1) else 0
		local moving = math.clamp(speed / 2, 0, 1)
		local weights = { Idle = 1 - moving, Walk = moving * (1 - run), Run = moving * run }
		for key, track in tracks do
			track:AdjustWeight(math.max(weights[key], 0.001), 0.15)
		end
		if tracks.Walk then
			tracks.Walk:AdjustSpeed(math.max(speed, 1) / walkSpeed)
		end
		if tracks.Run then
			tracks.Run:AdjustSpeed(math.max(speed, 1) / runSpeed)
		end
	end

	local function startFollower(model)
		local root = model.PrimaryPart
		if not root then
			return
		end
		local tracks = loadGirlTracks(model)
		local rec = FollowMotion.new({
			root = root,
			motors = motorsOf(model),
			from = root.Position,
			rootHeight = model:GetAttribute("RootHeight"),
			seed = seedOf(model),
			animated = tracks ~= nil,
		})
		rec.leaderId = model:GetAttribute("Follow")
		rec.tracks = tracks
		followers[model] = rec
	end

	-- Ground height under a point, ignoring every character and girl.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function groundAt(from, above)
		local origin = Vector3.new(from.X, math.max(from.Y, above) + 6, from.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
		return hit and hit.Position.Y
	end

	folder.ChildAdded:Connect(function(model)
		task.spawn(startCarry, model)
	end)
	folder.ChildRemoved:Connect(stopCarry)
	for _, model in folder:GetChildren() do
		task.spawn(startCarry, model)
	end
	CollectionService:GetInstanceAddedSignal("HuzzPrize"):Connect(startPrize)
	CollectionService:GetInstanceRemovedSignal("HuzzPrize"):Connect(function(model)
		prizes[model] = nil
	end)
	for _, model in CollectionService:GetTagged("HuzzPrize") do
		startPrize(model)
	end
	CollectionService:GetInstanceAddedSignal("HuzzFollower"):Connect(startFollower)
	CollectionService:GetInstanceRemovedSignal("HuzzFollower"):Connect(function(model)
		followers[model] = nil
	end)
	for _, model in CollectionService:GetTagged("HuzzFollower") do
		startFollower(model)
	end

	RunService.PreSimulation:Connect(function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		for model, c in carries do
			local rec = c.rec
			if not (model.Parent and rec.motor.Parent and rec.root.Parent and rec.rig.torso.Parent) then
				stopCarry(model)
			else
				local moodAt = model:GetAttribute("MoodAt") or rec.start
				CarryMotion.step(rec, dt, now, model:GetAttribute("Mood"), now - moodAt)
			end
		end
		if next(followers) then
			local ignore = { folder, Workspace:FindFirstChild("HuzzFollowers") }
			for _, p in Players:GetPlayers() do
				table.insert(ignore, p.Character)
			end
			rayParams.FilterDescendantsInstances = ignore
		end
		for model, rec in followers do
			local leader = Players:GetPlayerByUserId(rec.leaderId or 0)
			local leaderRoot = leader and leader.Character and leader.Character:FindFirstChild("HumanoidRootPart")
			if not model.Parent then
				followers[model] = nil
			elseif leaderRoot then
				local head = leader.Character:FindFirstChild("Head")
				FollowMotion.step(rec, dt, now, leaderRoot.CFrame, function(p)
					return groundAt(p, leaderRoot.Position.Y)
				end, head and head.Position)
				if rec.tracks then
					driveGirlTracks(rec.tracks, rec.speed)
				end
			end
		end
		for model, p in prizes do
			if model.Parent then
				local target, distance = nearestHead(p.root.Position)
				GirlMotion.idle(p.state, p.joints, dt, now, { target = target, distance = distance })
			else
				prizes[model] = nil
			end
		end
	end)
end

return M
