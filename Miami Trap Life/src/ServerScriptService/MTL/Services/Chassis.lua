--!strict
-- Chassis: makes a script-free car body drivable with plain Roblox constraints (no scripts inside the model).
-- Used by VehicleService for every car whose Config/Vehicles entry has a `chassis` spec (the dealership
-- cars and the bike). The Oros keeps its own A-Chassis and never comes here.
--
-- Template rules (ServerStorage.MTL_Cars.<template>): an anchored Model with no scripts, its pivot at GROUND
-- level in the middle of the car, facing the pivot's LookVector (-Z). Optional parts anywhere inside:
--   Wheel_FL / Wheel_FR / Wheel_RL / Wheel_RR  visual wheels (a Part, or a Model/Folder of parts: tyre + rim)
--   Wheel_F / Wheel_R                          a bike's two visual wheels
-- The wheels' own positions and size set the wheelbase, track and radius (spec values are only a fallback).
--   a VehicleSeat (else one is made at spec.seat)
--   Seat parts for passengers are left as they are.
--
-- Per corner:  Chassis -(Prismatic up + Spring)- Strut -(Hinge servo, front only; Weld at the back)- Hub
--              -(Hinge motor)- Wheel (an invisible Cylinder that touches the road)
-- The body is welded to the Chassis box, massless and non-colliding; the box is the car's collider.
--
--   Chassis.rig(model, spec) -> VehicleSeat     (call while the model is still anchored, before PivotTo)
--   Chassis.release(model)                       (unanchor once it's parented in the Workspace)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Chassis = {}

-- Which way the wheels spin for "forward". Flip if a play test shows the cars driving backwards.
Chassis.SPIN = -1

export type Spec = {
	wheelbase: number?, -- studs between front and rear axles (measured from the Wheel_ parts when present)
	track: number?, -- studs between left and right wheel centres (bikes: the hidden stabiliser track)
	wheelRadius: number?,
	wheelWidth: number?,
	maxSpeed: number, -- studs/s at full throttle (about 1 stud/s = 0.6 mph on the HUD)
	reverseSpeed: number?,
	torque: number?, -- wheel motor torque (scaled by mass at rig time)
	steer: number?, -- max steering angle, degrees
	travel: number?, -- suspension travel each way, studs
	seat: Vector3?, -- driver seat offset from the pivot, if the body has no VehicleSeat
	bike: boolean?, -- two visual wheels; the physics wheels are an invisible narrow quad
}

local CORNERS = {
	{ name = "FL", side = -1, front = true },
	{ name = "FR", side = 1, front = true },
	{ name = "RL", side = -1, front = false },
	{ name = "RR", side = 1, front = false },
}

-- an attachment whose primary axis (X) points along `axis` in the part's space
local function attach(parent: BasePart, name: string, pos: Vector3, axis: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	local up = if math.abs(axis.Y) > 0.9 then Vector3.zAxis else Vector3.yAxis
	local sec = up:Cross(axis).Unit:Cross(axis).Unit * -1
	a.CFrame = CFrame.fromMatrix(pos, axis, sec)
	a.Parent = parent
	return a
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function noCollide(a: BasePart, b: BasePart)
	local n = Instance.new("NoCollisionConstraint")
	n.Part0 = a
	n.Part1 = b
	n.Parent = a
end

local function newPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Chassis.rig(model: Model, spec: Spec): VehicleSeat
	local pivot = model:GetPivot()
	local travel = spec.travel or 0.45
	local rig = Instance.new("Folder")
	rig.Name = "Rig"
	rig.Parent = model

	-- the body: everything already in the model
	local body: { BasePart } = {}
	local visual: { [string]: { BasePart } } = {}
	local function wheelOf(d: Instance): string?
		local a: Instance? = d
		while a and a ~= model do
			local w = string.match(a.Name, "^Wheel_(%u%u?)$")
			if w then
				return w
			end
			a = a.Parent
		end
		return nil
	end
	local seat: VehicleSeat? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- templates must be script-free; never run a script that came with a model
		elseif d:IsA("JointInstance") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("VehicleSeat") and not seat then
			seat = d
		elseif d:IsA("BasePart") then
			local w = wheelOf(d)
			if w then
				visual[w] = visual[w] or {}
				table.insert(visual[w], d)
			end
			table.insert(body, d)
		end
	end

	-- wheel geometry from the model's own wheels: centre (pivot space) and radius of each group
	local centres: { [string]: Vector3 } = {}
	local radius = 0
	for name, parts in visual do
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in parts do
			local c = pivot:PointToObjectSpace(p.Position)
			local half = p.Size / 2
			local e = Vector3.one * math.max(half.X, half.Y, half.Z)
			lo, hi = lo:Min(c - e), hi:Max(c + e)
		end
		local mid = (lo + hi) / 2
		centres[name] = mid
		radius = math.max(radius, math.min(hi.Y - lo.Y, hi.Z - lo.Z) / 2)
	end
	local R = spec.wheelRadius or (if radius > 0.3 then radius else 1.2)
	local W = spec.wheelWidth or math.max(0.6, R * 0.7)
	local function corner(name: string, side: number, front: boolean): Vector3
		if spec.bike then
			local c = centres[if front then "F" else "R"]
			local z = if c then c.Z else (if front then -1 else 1) * (spec.wheelbase or 5) / 2
			return Vector3.new((c and c.X or 0) + side * (spec.track or 2.6) / 2, if c then c.Y else R, z)
		end
		local c = centres[name]
		if c then
			return c -- exactly where the model's wheel is, so the visual wheel spins on its own centre
		end
		return Vector3.new(side * (spec.track or 5) / 2, R, (if front then -1 else 1) * (spec.wheelbase or 8) / 2)
	end
	if next(centres) == nil and not spec.wheelbase then
		warn("[MTL Chassis]", model.Name, "has no Wheel_ parts and no wheelbase in its spec; using defaults")
	end

	-- the collider: the body's bounding box, lifted so it clears the road
	local bbCF, bbSize = model:GetBoundingBox()
	local local0 = pivot:ToObjectSpace(bbCF)
	local bottom = local0.Position.Y - bbSize.Y / 2
	local top = local0.Position.Y + bbSize.Y / 2
	local floor = math.max(bottom, R * 0.9)
	local height = math.max(1, (top - floor) * 0.8)
	local box = newPart(
		"Chassis",
		Vector3.new(math.max(1.2, bbSize.X * 0.92), height, math.max(2, bbSize.Z * 0.95)),
		pivot * CFrame.new(local0.Position.X, floor + height / 2, local0.Position.Z),
		model
	)
	box.CanCollide = true
	box.CanQuery = true
	box.CanTouch = true
	-- keep the centre of mass low so it doesn't roll over in corners
	box.CustomPhysicalProperties = PhysicalProperties.new(if spec.bike then 1.4 else 0.9, 0.3, 0.2)
	model.PrimaryPart = box
	-- keep the model's pivot at ground centre (a PrimaryPart moves the pivot to its own CFrame otherwise, and
	-- VehicleService's PivotTo would then sink the car into the road by the box's height)
	box.PivotOffset = box.CFrame:ToObjectSpace(pivot)

	for _, p in body do
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.Anchored = true
		if not wheelOf(p) then
			weld(box, p)
		end
	end

	-- the driver's seat
	if not seat then
		local s = Instance.new("VehicleSeat")
		s.Name = "DriveSeat"
		s.Size = Vector3.new(2, 1, 2)
		local fl = corner("FL", -1, true)
		local off = spec.seat or Vector3.new(if spec.bike then 0 else fl.X * 0.45, R + 0.8, 0)
		s.CFrame = pivot * CFrame.new(off)
		s.Transparency = 1
		s.CanCollide = false
		s.Anchored = true
		s.Parent = model
		seat = s
	end
	local driver = seat :: VehicleSeat
	driver.Name = "DriveSeat"
	driver.HeadsUpDisplay = false
	driver.MaxSpeed = 0 -- the motors below do the driving
	driver.Torque = 0
	driver.Massless = true
	driver.Anchored = true
	weld(box, driver)

	-- the mass the springs have to hold (wheels/struts are small next to the box)
	local mass = box:GetMass()
	local g = workspace.Gravity
	local k = mass * g / 4 / (travel * 0.55)
	local damping = 2 * math.sqrt(k * mass / 4) * 0.55
	-- the moving parts get real mass: tiny parts on huge forces are what fling a car into space
	local function weigh(p: BasePart, target: number, volume: number)
		local d = math.clamp(target / math.max(volume, 0.01), 0.7, 100)
		local cur = p.CustomPhysicalProperties
		p.CustomPhysicalProperties = PhysicalProperties.new(d, if cur then cur.Friction else 0.3, if cur then cur.Elasticity else 0.1, if cur then cur.FrictionWeight else 1, if cur then cur.ElasticityWeight else 1)
	end
	local wheelMass = mass * 0.04
	local linkMass = mass * 0.015
	local total = mass + 4 * (wheelMass + 2 * linkMass)
	-- per-wheel motor torque for about 0.3 g of pull with all four wheels driving (spec.torque scales it)
	local torque = (spec.torque or 1) * total * g * 0.16 * R / 4
	local spinAccel = math.max(20, (spec.maxSpeed / R) * 1.2) -- rad/s^2: wheels spin up smoothly, never instantly

	local motors: { HingeConstraint } = {}
	local steers: { HingeConstraint } = {}
	for _, c in CORNERS do
		local at = corner(c.name, c.side, c.front)
		local cf = pivot * CFrame.new(at)

		local strut = newPart("Strut" .. c.name, Vector3.new(0.6, 0.6, 0.6), cf, rig)
		local hub = newPart("Hub" .. c.name, Vector3.new(0.6, 0.6, 0.6), cf, rig)
		local wheel = newPart("Tyre" .. c.name, Vector3.new(W, R * 2, R * 2), cf, rig)
		wheel.Shape = Enum.PartType.Cylinder -- a Cylinder's axis is its X: the car's sideways axis
		wheel.CanCollide = true
		wheel.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1.6, 0.05, 100, 1)
		weigh(strut, linkMass, 0.216)
		weigh(hub, linkMass, 0.216)
		weigh(wheel, wheelMass, math.pi * R * R * W)
		noCollide(box, wheel)

		-- suspension: the strut slides up and down
		local boxPos = box.CFrame:PointToObjectSpace(cf.Position)
		local pr = Instance.new("PrismaticConstraint")
		pr.Name = "Travel"
		pr.Attachment0 = attach(box, "Susp" .. c.name, boxPos, Vector3.yAxis)
		pr.Attachment1 = attach(strut, "Susp", Vector3.zero, Vector3.yAxis)
		pr.LimitsEnabled = true
		pr.LowerLimit = -travel
		pr.UpperLimit = travel
		pr.Parent = strut
		local sp = Instance.new("SpringConstraint")
		sp.Name = "Spring"
		sp.Attachment0 = attach(box, "SpringTop" .. c.name, boxPos + Vector3.new(0, 2, 0), Vector3.yAxis)
		sp.Attachment1 = attach(strut, "SpringLow", Vector3.zero, Vector3.yAxis)
		sp.FreeLength = 2 + travel * 0.55
		sp.Stiffness = k
		sp.Damping = damping
		sp.Parent = strut

		-- steering: the hub turns on the strut (front) or is fixed to it (back)
		if c.front then
			local h = Instance.new("HingeConstraint")
			h.Name = "Steer"
			h.Attachment0 = attach(strut, "Steer", Vector3.zero, Vector3.yAxis)
			h.Attachment1 = attach(hub, "Steer", Vector3.zero, Vector3.yAxis)
			h.ActuatorType = Enum.ActuatorType.Servo
			h.ServoMaxTorque = total * g * R * 0.6
			h.AngularSpeed = 4
			h.TargetAngle = 0
			h.Parent = hub
			table.insert(steers, h)
		else
			weld(strut, hub)
		end

		-- drive: the wheel spins on the hub around the car's sideways axis
		local m = Instance.new("HingeConstraint")
		m.Name = "Motor"
		m.Attachment0 = attach(hub, "Spin", Vector3.zero, Vector3.xAxis)
		m.Attachment1 = attach(wheel, "Spin", Vector3.zero, Vector3.xAxis)
		m.ActuatorType = Enum.ActuatorType.Motor
		m.MotorMaxTorque = torque * 0.6
		m.MotorMaxAcceleration = spinAccel
		m.AngularVelocity = 0
		m.Parent = wheel
		table.insert(motors, m)

		-- the model's own wheel (if any) rides on the physics wheel
		local vis = visual[c.name]
		if spec.bike then
			wheel.Transparency = 1
			-- bikes: two visual wheels (Wheel_F, Wheel_R) on the centre line, carried by the left-hand tyres
			-- (the weld keeps the sideways offset, which lies on the spin axis, so they roll true)
			local v = if c.side == -1 then visual[if c.front then "F" else "R"] else nil
			for _, p in v or {} do
				weld(wheel, p)
			end
		elseif vis then
			for _, p in vis do
				weld(wheel, p)
			end
		else
			-- no wheel in the model: make the tyre itself visible
			wheel.Transparency = 0
			wheel.Color = Color3.fromRGB(24, 24, 26)
			wheel.Material = Enum.Material.SmoothPlastic
		end
	end

	-- bikes: keep the bike upright (a rider can't balance a physics bike); pitch on hills is still free-ish
	if spec.bike then
		local up = attach(box, "Upright", Vector3.zero, Vector3.yAxis)
		local ao = Instance.new("AlignOrientation")
		ao.Name = "Upright"
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = up
		ao.AlignType = Enum.AlignType.PrimaryAxisParallel
		ao.PrimaryAxis = Vector3.yAxis
		ao.MaxTorque = total * g * 6
		ao.Responsiveness = 25
		ao.Parent = box
	end

	-- the driving loop lives on the server: VehicleSeat input replicates, constraint targets replicate back
	local maxSteer = spec.steer or 32
	local vMax = spec.maxSpeed
	local vRev = spec.reverseSpeed or vMax * 0.35
	local conn: RBXScriptConnection? = nil
	local function drive()
		if not box.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local throttle = driver.ThrottleFloat
		local steer = driver.SteerFloat
		local speed = box.CFrame.LookVector:Dot(box.AssemblyLinearVelocity) -- studs/s, >0 going forward
		local target, power
		if math.abs(throttle) < 0.05 then
			target, power = 0, torque * 0.12 -- coast, gently
		elseif throttle > 0 then
			if speed < -1 then
				target, power = 0, torque * 1.4 -- braking out of reverse
			else
				target, power = vMax * throttle, torque
			end
		else
			if speed > 1 then
				target, power = 0, torque * 1.4 -- brakes
			else
				target, power = -vRev, torque * 0.8
			end
		end
		if not driver.Occupant then
			target, power = 0, torque * 0.6 -- parked
		end
		local w = Chassis.SPIN * target / R
		for _, m in motors do
			m.AngularVelocity = w
			m.MotorMaxTorque = power
		end
		local fade = 1 - 0.55 * math.clamp(math.abs(speed) / math.max(vMax, 1), 0, 1)
		for _, h in steers do
			h.TargetAngle = -steer * maxSteer * fade
		end
	end
	conn = RunService.Heartbeat:Connect(drive)
	model.Destroying:Connect(function()
		if conn then
			conn:Disconnect()
		end
	end)

	-- the driver simulates the car (smooth on their screen); a parked car is the server's (nobody can fling it)
	driver:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not box.Parent or box.Anchored then
			return
		end
		local hum = driver.Occupant
		local who = hum and Players:GetPlayerFromCharacter(hum.Parent)
		pcall(function()
			if who then
				box:SetNetworkOwner(who)
			else
				box:SetNetworkOwner(nil)
			end
		end)
	end)
	return driver
end

function Chassis.release(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	-- parked = the server simulates it, so no nearby client can take it over and fling it
	local box = model:FindFirstChild("Chassis")
	if box and box:IsA("BasePart") then
		pcall(function()
			box:SetNetworkOwner(nil)
		end)
	end
end

return Chassis
