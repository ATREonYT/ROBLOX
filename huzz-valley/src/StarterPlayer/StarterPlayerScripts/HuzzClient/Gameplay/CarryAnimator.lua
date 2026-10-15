--[[
	Animates every carried girl on this client: the pickup flight, the raised
	arms, the step bob, inertia sway, and her dangling limbs.

	It works by overriding Motor6D.Transform right after Roblox's animations
	run each frame (PreSimulation). Legs, hips and torso keep whatever walk,
	run or huss animation is playing; only the arms are posed, with a little
	of the animation's swing let through (Carry.Arms.AnimBlend). So new
	Huss Valley animations need no changes here. Upload an upper-body carry
	animation and put it in Config/Animations.CarryArms to replace the
	scripted arms entirely.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Carry = require(Shared.Config.Carry)
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)

	local folder = Workspace:WaitForChild("HuzzCarried")
	local useArmAnimation = Animations.CarryArms ~= ""
	local rad, sin, clamp, exp = math.rad, math.sin, math.clamp, math.exp
	local records = {} -- model -> record

	-- Girl joints that hang with gravity (weight key) or bend a little (bend key)
	local DANGLE = {
		LeftUpperArm = "Arms", RightUpperArm = "Arms", ["Left Arm"] = "Arms", ["Right Arm"] = "Arms",
		LeftUpperLeg = "Legs", RightUpperLeg = "Legs", ["Left Leg"] = "Legs", ["Right Leg"] = "Legs",
		Head = "Head",
	}
	local BEND = { LeftLowerLeg = -1, RightLowerLeg = -1, LeftLowerArm = 1, RightLowerArm = 1 }

	local function clampVector(v, limit)
		return Vector3.new(clamp(v.X, -limit, limit), clamp(v.Y, -limit, limit), clamp(v.Z, -limit, limit))
	end

	-- Pose one of the carrier's arm joints on top of what the animation wrote this frame.
	local function poseJoint(rec, motor, pose, weight)
		if not motor then
			return
		end
		local current = motor.Transform
		-- Unchanged since our last write = no animation touched it this frame.
		local anim = if rec.written[motor] == current then rec.base[motor] else current
		rec.base[motor] = anim
		local keep = CFrame.identity:Lerp(anim, Carry.Arms.AnimBlend)
		motor.Transform = anim:Lerp(CarryMath.inJoint(motor, pose) * keep, weight)
		rec.written[motor] = motor.Transform
	end

	local function unregister(model)
		local rec = records[model]
		if not rec then
			return
		end
		records[model] = nil
		for motor, base in rec.base do
			if motor.Parent then
				motor.Transform = base
			end
		end
		if rec.armTrack then
			rec.armTrack:Stop(0.25)
		end
	end

	local function register(model)
		local motor = model:WaitForChild("HuzzCarryMotor", 10)
		local torso = motor and motor.Part0
		local character = torso and torso.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rig = character and CarryMath.rig(character)
		if not (humanoid and humanoid.RootPart and rig) or not model.Parent then
			return
		end
		local root = humanoid.RootPart
		local rec = {
			model = model, motor = motor, rig = rig, humanoid = humanoid, root = root,
			c0rot = motor.C0.Rotation,
			start = model:GetAttribute("Start") or Workspace:GetServerTimeNow(),
			-- No flight origin: she's lifted from the ground in front.
			from = model:GetAttribute("From") or (root.CFrame * CFrame.new(0, -2.2, -2.5)).Position,
			phase = 0, vel = Vector3.zero, prevVel = Vector3.zero, lag = Vector3.zero, lagVel = Vector3.zero,
			yaw = 0, yawVel = 0, yawRate = 0,
			written = {}, base = {}, limbs = {},
		}
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d ~= motor and d.Part1 then
				local key = DANGLE[d.Part1.Name]
				local rest = d.C1:Inverse().Position
				if key and rest.Magnitude > 0.05 then
					table.insert(rec.limbs, { motor = d, weight = Carry.Dangle[key], rest = rest.Unit, side = if d.Part1.Name:find("Left") then 1 else -1 })
				elseif BEND[d.Part1.Name] then
					local bend = if BEND[d.Part1.Name] < 0 then -Carry.Dangle.Knees else Carry.Dangle.Elbows
					table.insert(rec.limbs, { motor = d, bend = rad(bend) })
				end
			end
		end
		if useArmAnimation and character == Players.LocalPlayer.Character then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local animation = Instance.new("Animation")
				animation.AnimationId = Animations.CarryArms
				rec.armTrack = animator:LoadAnimation(animation)
				rec.armTrack.Priority = Enum.AnimationPriority.Action
				rec.armTrack.Looped = true
				rec.armTrack:Play(0.2)
			end
		end
		records[model] = rec
	end

	local function springStep(x, v, target, dt)
		local S = Carry.Spring
		local w = 2 * math.pi * S.Frequency
		-- Small fixed steps keep the spring stable at low frame rates.
		local steps = math.ceil(dt / (1 / 120))
		local h = dt / steps
		for _ = 1, steps do
			v += (w * w * (target - x) - 2 * S.Damping * w * v) * h
			x += v * h
		end
		return x, v
	end

	local function update(rec, dt)
		local root, torso, motor = rec.root, rec.rig.torso, rec.motor
		if not (rec.model.Parent and motor.Parent and root.Parent and torso.Parent) then
			unregister(rec.model)
			return
		end

		-- Carrier motion, measured from position so other players' characters work too.
		local pos = root.Position
		if rec.prevPos and (pos - rec.prevPos).Magnitude < 15 then
			rec.vel = rec.vel:Lerp((pos - rec.prevPos) / dt, 1 - exp(-dt * 14))
		else
			rec.vel, rec.prevVel = Vector3.zero, Vector3.zero -- spawned or teleported
		end
		rec.prevPos = pos
		local accel = root.CFrame:VectorToObjectSpace((rec.vel - rec.prevVel) / dt)
		rec.prevVel = rec.vel
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local turn = (yaw - (rec.prevYaw or yaw) + math.pi) % (2 * math.pi) - math.pi
		rec.prevYaw = yaw
		rec.yawRate += (turn / dt - rec.yawRate) * (1 - exp(-dt * 10))

		-- Inertia: she lags behind speed changes and turns, then springs back.
		local S = Carry.Spring
		rec.lag, rec.lagVel = springStep(rec.lag, rec.lagVel, clampVector(-accel * S.Lag, S.MaxLag), dt)
		rec.yaw, rec.yawVel = springStep(rec.yaw, rec.yawVel, clamp(-rec.yawRate * S.TurnLag, -S.MaxTurnLag, S.MaxTurnLag), dt)

		-- Footstep bob and rock.
		local B = Carry.Bob
		local speed = Vector3.new(rec.vel.X, 0, rec.vel.Z).Magnitude
		if math.abs(rec.vel.Y) < 4 then
			rec.phase += speed * dt * B.StepsPerStud
		end
		local amount = clamp(speed / 16, 0, 1.4)
		local step = sin(rec.phase * math.pi)
		local L = rec.lag
		local hold = CFrame.new(L.X, L.Y + (math.abs(step) - 0.5) * B.Height * amount, L.Z)
			* CFrame.Angles(rad(S.Tilt * L.Z), rec.yaw, rad(-S.Tilt * L.X) + rad(B.Roll) * step * amount)

		-- Pickup: fly in upright from where she was, arc, settle into the hold.
		local p = clamp((Workspace:GetServerTimeNow() - rec.start) / Carry.PickupTime, 0, 1)
		if p < 1 then
			local frame = torso.CFrame * CFrame.new(motor.C0.Position)
			local startCF = CFrame.new(frame:PointToObjectSpace(rec.from)) * rec.c0rot:Inverse()
			local e = 1 - (1 - p) ^ 3
			hold = startCF:Lerp(hold, e) + frame:VectorToObjectSpace(Vector3.yAxis) * Carry.ArcHeight * sin(math.pi * p)
		end
		motor.Transform = rec.c0rot:Inverse() * hold * rec.c0rot

		-- Carrier's arms: up as she arrives, elbows flexing with each step.
		if not useArmAnimation then
			local weight = clamp(p * 1.8, 0, 1)
			local flex = math.abs(step) * B.ElbowFlex * amount
			for _, arm in rec.rig.arms do
				poseJoint(rec, arm.shoulder, CarryMath.shoulderPose(arm.sign, 1), weight)
				poseJoint(rec, arm.elbow, CarryMath.elbowPose(arm.sign, Carry.Arms.ElbowBend + flex), weight)
			end
		end

		-- Her limbs hang toward the ground and swing with the steps.
		local D = Carry.Dangle
		local down = -Vector3.yAxis
		for i, limb in rec.limbs do
			local m = limb.motor
			if limb.bend then
				m.Transform = CFrame.Angles(limb.bend, 0, 0)
			elseif m.Part0 then
				local localDown = (m.Part0.CFrame * m.C0):VectorToObjectSpace(down)
				local target = limb.rest:Lerp(localDown, limb.weight).Unit
				local axis = limb.rest:Cross(target)
				local swing = CFrame.Angles(rad(D.Swing) * amount * sin(rec.phase * math.pi + i) * limb.side, 0, 0)
				if axis.Magnitude > 1e-3 then
					m.Transform = CFrame.fromAxisAngle(axis.Unit, math.acos(clamp(limb.rest:Dot(target), -1, 1))) * swing
				else
					m.Transform = swing
				end
			end
		end
	end

	folder.ChildAdded:Connect(function(model)
		task.spawn(register, model)
	end)
	folder.ChildRemoved:Connect(unregister)
	for _, model in folder:GetChildren() do
		task.spawn(register, model)
	end

	RunService.PreSimulation:Connect(function(dt)
		dt = math.max(dt, 1 / 240)
		for _, rec in records do
			update(rec, dt)
		end
	end)
end

return M
