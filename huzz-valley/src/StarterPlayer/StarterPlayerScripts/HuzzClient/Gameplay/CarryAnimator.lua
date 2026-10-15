--[[
	Runs the girl animations on this client. The motion itself lives in
	Shared/CarryMotion and Shared/GirlMotion, which is the same code the offline
	preview runs. This script feeds them real parts every frame:
	  - every carried girl (Workspace.HuzzCarried): the pickup flight, the carrier's
	    raised arms and lean, and her limbs and mood (model attributes Mood, MoodAt);
	  - the prize girl (tag "HuzzPrize"): her idle, watching the nearest player.
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

	local folder = Workspace:WaitForChild("HuzzCarried")
	local useArmAnimation = Animations.CarryArms ~= ""
	local carries = {} -- model -> { rec, model, humanoid, armTrack }
	local prizes = {} -- model -> { state, joints, root }

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
