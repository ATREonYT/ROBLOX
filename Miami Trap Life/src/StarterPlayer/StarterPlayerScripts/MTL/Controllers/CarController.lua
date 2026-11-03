--!strict
-- Car feel on every client, for every live car (Workspace.MTL_SpawnedCars), nobody's car waits on anything:
--   tyre smoke when a car slides sideways or spins its wheels from a stop (rear tyres of our constraint chassis;
--   the Oros's A-Chassis brings its own effects and is left alone).
-- Uses only Roblox's built-in particle texture (no asset ids). Cheap: one check per car 10x a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)

local CarController = {}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SLIP_START = 9 -- studs/s sideways before smoke
local SLIP_FULL = 30 -- full smoke at this much sideways slide

type Car = { model: Model, box: BasePart, emitters: { ParticleEmitter } }
local cars: { [Model]: Car } = {}

local function smokeOn(tyre: BasePart): ParticleEmitter
	local a = Instance.new("Attachment")
	a.Name = "SmokeAt"
	a.Position = Vector3.new(0, -tyre.Size.Y / 2 + 0.2, 0)
	a.Parent = tyre
	local e = Instance.new("ParticleEmitter")
	e.Name = "TyreSmoke"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	e.LightEmission = 0.05
	e.LightInfluence = 1
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.4, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Drag = 1.5
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Enabled = true
	e.Parent = a
	return e
end

local function track(model: Instance)
	if not model:IsA("Model") or cars[model] then
		return
	end
	task.spawn(function()
		-- only our chassis cars (they have a Rig with Tyre parts); give replication a moment
		local rig = model:WaitForChild("Rig", 5)
		local box = model:WaitForChild("Chassis", 5)
		if not rig or not box or not box:IsA("BasePart") or not model.Parent then
			return
		end
		local def = Vehicles.get(model:GetAttribute("MTL_CarId") :: any)
		local emitters = {}
		for _, name in { "TyreRL", "TyreRR" } do
			local t = rig:WaitForChild(name, 3)
			if t and t:IsA("BasePart") then
				table.insert(emitters, smokeOn(t))
			end
		end
		if def and def.chassis and def.chassis.bike then
			-- one rear wheel: keep just the first emitter
			for i = #emitters, 2, -1 do
				emitters[i]:Destroy()
				table.remove(emitters, i)
			end
		end
		cars[model] = { model = model, box = box, emitters = emitters }
	end)
end

local acc = 0
local function step(dt: number)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	for model, c in cars do
		if not model.Parent or not c.box.Parent then
			cars[model] = nil
			continue
		end
		local v = c.box.AssemblyLinearVelocity
		local cf = c.box.CFrame
		local side = math.abs(cf.RightVector:Dot(v))
		local fwd = cf.LookVector:Dot(v)
		local rate = 0
		if side > SLIP_START and math.abs(fwd) > 8 then
			rate = math.clamp((side - SLIP_START) / (SLIP_FULL - SLIP_START), 0.15, 1) * 60
		end
		-- burnout: driver on the throttle, car barely moving
		local seat = model:FindFirstChild("DriveSeat", true)
		if seat and seat:IsA("VehicleSeat") and seat.Occupant and seat.ThrottleFloat > 0.5 and math.abs(fwd) < 3 then
			rate = math.max(rate, 35)
		end
		for _, e in c.emitters do
			e.Rate = rate
		end
	end
end

function CarController.init()
	local function hook(folder: Instance)
		for _, m in folder:GetChildren() do
			track(m)
		end
		folder.ChildAdded:Connect(track)
	end
	local f = workspace:FindFirstChild(Vehicles.SpawnFolder)
	if f then
		hook(f)
	else
		local conn
		conn = workspace.ChildAdded:Connect(function(c)
			if c.Name == Vehicles.SpawnFolder then
				conn:Disconnect()
				hook(c)
			end
		end)
	end
	RunService.Heartbeat:Connect(step)
end

return CarController
