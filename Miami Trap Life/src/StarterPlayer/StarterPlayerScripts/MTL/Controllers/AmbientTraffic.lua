--!strict
-- Through traffic (client only). Required by AmbientLife, which calls step() from its one Heartbeat.
-- 4-6 cars drive closed lane loops from AmbientMap.Lanes (right-hand traffic) at 22-32 studs/s, ease into corners,
-- stop for the player / people / the car in front, honk after 2.5 s stuck. Anchored, moved with BulkMoveTo (front
-- and rear axles follow the lane, so they turn like cars), wheels spin. 1 in 3 thumps bass. At night head/tail lights
-- go Neon and only the nearest 2 get a real SpotLight. A car that drifts far from the player jumps to a lane point
-- near them while out of sight, so traffic is always around you.
-- Body: ReplicatedStorage.MTL_AmbientCars.<Template> (tools/DressHoodLife copies the map's SedanA there), else a
-- simple built sedan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientTraffic = {}

type WheelPart = { part: BasePart, off: CFrame, axle: Vector3 } -- off is relative to the axle centre
type Car = {
	model: Model,
	parts: { BasePart },
	offs: { CFrame }, -- part offsets in the car's ground frame (front = -Z)
	wheels: { WheelPart },
	wheelOf: { [BasePart]: WheelPart },
	heads: { BasePart },
	tails: { BasePart },
	spot: SpotLight?,
	length: number,
	halfLen: number,
	wheelbase: number,
	lane: any?,
	d: number,
	v: number,
	cruise: number,
	spin: number,
	stuck: number,
	honkAt: number,
	pos: Vector3,
	fwd: Vector3,
	cf: CFrame,
	active: boolean,
	music: boolean,
	key: string,
	lastMove: number,
}

local cfg: any
local R: any
local cars: { Car } = {}
local folder: Folder
local rng = Random.new()
local lightsOn = false

local HEAD = Color3.fromRGB(255, 240, 214)
local TAIL = Color3.fromRGB(225, 40, 36)
local OFF = Color3.fromRGB(150, 150, 150)

---------------------------------------------------------------- bodies

local function bodyPart(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- a plain sedan (front = -Z, origin on the ground) for when no map car is available
local function builtCar(): Model
	local m = Instance.new("Model")
	m.Name = "AmbientSedan"
	local paint = Color3.fromRGB(120, 124, 130)
	bodyPart(m, "Color", Vector3.new(6.2, 1.9, 14), CFrame.new(0, 2.15, 0), paint)
	bodyPart(m, "Color", Vector3.new(5.6, 1.7, 7), CFrame.new(0, 3.95, 0.8), paint)
	bodyPart(m, "Glass", Vector3.new(5.7, 1.4, 7.1), CFrame.new(0, 4.0, 0.8), Color3.fromRGB(26, 32, 42), Enum.Material.Glass).Transparency = 0.2
	bodyPart(m, "Trim", Vector3.new(6.3, 0.5, 14.1), CFrame.new(0, 1.3, 0), Color3.fromRGB(34, 34, 38))
	for _, z in { -4.6, 4.4 } do
		for _, x in { -2.9, 2.9 } do
			local w = bodyPart(m, "Wheel", Vector3.new(1, 2.4, 2.4), CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 24, 26))
			w.Shape = Enum.PartType.Cylinder
			bodyPart(m, "Rim", Vector3.new(1.05, 1.3, 1.3), CFrame.new(x * 1.01, 1.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 170, 176), Enum.Material.Metal).Shape =
				Enum.PartType.Cylinder
		end
	end
	return m
end

local function template(): Model?
	local lib = ReplicatedStorage:FindFirstChild("MTL_AmbientCars")
	local t = lib and lib:FindFirstChild(cfg.Traffic.Template)
	return if t and t:IsA("Model") then t else nil
end

local function isWheelName(n: string): boolean
	local l = string.lower(n)
	return string.find(l, "wheel") ~= nil or string.find(l, "tire") ~= nil or string.find(l, "tyre") ~= nil or string.find(l, "rim") ~= nil
end

local function makeCar(i: number): Car?
	local t = template()
	local m: Model
	if t then
		local was = t.Archivable
		t.Archivable = true
		m = t:Clone()
		t.Archivable = was
	else
		m = builtCar()
	end
	for _, d in m:GetDescendants() do
		-- no scripts, sounds, joints or the model's own lights (our lenses + the nearest-2 SpotLights do the night)
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Light") then
			d:Destroy()
		end
	end
	local parts: { BasePart } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		m:Destroy()
		return nil
	end
	-- ground frame: bounding-box centre on the floor, long axis = Z. Which end is the front? Red glass = the back.
	local box, size = m:GetBoundingBox()
	local frame = box
	if size.X > size.Z then
		frame = box * CFrame.Angles(0, math.rad(90), 0)
		size = Vector3.new(size.Z, size.Y, size.X)
	end
	local redZ, redN = 0, 0
	for _, p in parts do
		local c = p.Color
		if (p.Name == "Glass" or p.Material == Enum.Material.Neon or p.Material == Enum.Material.Glass) and c.R > 0.5 and c.G < 0.35 and c.B < 0.35 then
			redZ += frame:PointToObjectSpace(p.Position).Z
			redN += 1
		end
	end
	if redN > 0 and redZ / redN < 0 then
		frame = frame * CFrame.Angles(0, math.pi, 0) -- tail lights at -Z: turn round so the front is -Z
	end
	local ground = frame * CFrame.new(0, -size.Y / 2, 0)
	local car: Car = {
		model = m,
		parts = parts,
		offs = {},
		wheels = {},
		wheelOf = {},
		heads = {},
		tails = {},
		spot = nil,
		length = size.Z,
		halfLen = size.Z / 2,
		wheelbase = size.Z * 0.6,
		lane = nil,
		d = 0,
		v = 0,
		cruise = 26,
		spin = 0,
		stuck = 0,
		honkAt = 0,
		pos = Vector3.zero,
		fwd = Vector3.new(0, 0, -1),
		cf = CFrame.identity,
		active = false,
		music = false,
		key = "Car" .. i,
		lastMove = 0,
	}
	-- wheels: grouped by corner, each spins round its corner's axle centre
	local corners: { [string]: { BasePart } } = {}
	for _, p in parts do
		local off = ground:ToObjectSpace(p.CFrame)
		table.insert(car.offs, off)
		local low = off.Y < size.Y * 0.45
		if low and (isWheelName(p.Name) or (p:IsA("Part") and p.Shape == Enum.PartType.Cylinder)) then
			local key = (if off.X < 0 then "L" else "R") .. (if off.Z < 0 then "F" else "B")
			corners[key] = corners[key] or {}
			table.insert(corners[key], p)
		end
	end
	for _, list in corners do
		local c = Vector3.zero
		for _, p in list do
			c += ground:PointToObjectSpace(p.Position)
		end
		c /= #list
		for _, p in list do
			local w = { part = p, off = CFrame.new(-c) * ground:ToObjectSpace(p.CFrame), axle = c }
			table.insert(car.wheels, w)
			car.wheelOf[p] = w
		end
	end
	-- recolour the paint
	local paint = cfg.Traffic.BodyColors[rng:NextInteger(1, #cfg.Traffic.BodyColors)]
	for _, p in parts do
		if p.Name == "Color" or p.Name == "Body" or p.Name == "Paint" then
			p.Color = paint
		end
	end
	-- our own light lenses (front = -Z), so day/night never depends on the model's naming
	local hw, hy = size.X * 0.36, size.Y * 0.38
	for _, side in { -1, 1 } do
		local h = bodyPart(m, "AmbientHead", Vector3.new(1.1, 0.45, 0.12), CFrame.new(side * hw, hy, -size.Z / 2 - 0.03), OFF)
		local tl = bodyPart(m, "AmbientTail", Vector3.new(1.0, 0.4, 0.12), CFrame.new(side * hw, hy + 0.3, size.Z / 2 + 0.03), OFF)
		for _, p in { h, tl } do
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Transparency = 1
			table.insert(car.parts, p)
			table.insert(car.offs, p.CFrame) -- built in ground space already
		end
		table.insert(car.heads, h)
		table.insert(car.tails, tl)
	end
	m.Name = "AmbientCar" .. i
	m.Parent = folder
	return car
end

---------------------------------------------------------------- lights

local function setLights(car: Car, on: boolean)
	for _, p in car.heads do
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = if on then HEAD else OFF
		p.Transparency = if on then 0 else 1
	end
	for _, p in car.tails do
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = if on then TAIL else OFF
		p.Transparency = if on then 0 else 1
	end
end

local function setSpot(car: Car, on: boolean)
	if on and not car.spot then
		local s = Instance.new("SpotLight")
		s.Brightness = 3
		s.Range = 40
		s.Angle = 70
		s.Face = Enum.NormalId.Front
		s.Color = HEAD
		s.Shadows = false
		s.Parent = car.heads[1]
		car.spot = s
	elseif not on and car.spot then
		car.spot:Destroy()
		car.spot = nil
	end
end

---------------------------------------------------------------- motion

local function pose(car: Car)
	local lane = car.lane
	local fx, fz = R.sample(lane.path, car.d + car.wheelbase / 2)
	local rx, rz = R.sample(lane.path, car.d - car.wheelbase / 2)
	local front = Vector3.new(fx, lane.y, fz)
	local rear = Vector3.new(rx, lane.y, rz)
	local fwd = front - rear
	if fwd.Magnitude < 1e-3 then
		fwd = car.fwd
	else
		fwd = fwd.Unit
	end
	car.fwd = fwd
	car.pos = (front + rear) / 2
	car.cf = CFrame.lookAt(car.pos, car.pos + fwd)
end

local function move(car: Car)
	local cfs = table.create(#car.parts)
	local spin = CFrame.Angles(car.spin, 0, 0)
	for i, p in car.parts do
		local w = car.wheelOf[p]
		if w then
			cfs[i] = car.cf * CFrame.new(w.axle) * spin * w.off
		else
			cfs[i] = car.cf * car.offs[i]
		end
	end
	workspace:BulkMoveTo(car.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- distance ahead to the nearest thing in our lane (player, people, cars)
local function blockedAhead(ctx: any, car: Car): number
	local best = math.huge
	local right = Vector3.new(-car.fwd.Z, 0, car.fwd.X)
	local function test(o: Vector3, width: number)
		local rel = o - car.pos
		local along = rel:Dot(car.fwd) - car.halfLen
		if along > -1 and along < cfg.Traffic.StopAhead + cfg.Traffic.Gap and math.abs(rel:Dot(right)) < width and math.abs(rel.Y) < 8 then
			best = math.min(best, math.max(along, 0))
		end
	end
	if ctx.playerPos then
		test(ctx.playerPos, 4.2)
	end
	for _, p in ctx.peds or {} do
		test(p, 3.8)
	end
	for _, o in cars do
		if o ~= car and o.active then
			local rel = o.pos - car.pos
			local along = rel:Dot(car.fwd) - car.halfLen - o.halfLen
			if along > -2 and along < cfg.Traffic.StopAhead + cfg.Traffic.Gap and math.abs(rel:Dot(right)) < 3.2 then
				best = math.min(best, math.max(along - cfg.Traffic.Gap + cfg.Traffic.StopAhead * 0.3, 0))
			end
		end
	end
	return best
end

local function clearAt(lane: any, d: number, car: Car): boolean
	for _, o in cars do
		if o ~= car and o.active and o.lane == lane then
			local gap = math.abs(o.d - d)
			if lane.path.loop then
				gap = math.min(gap, lane.path.total - gap)
			end
			if gap < 40 then
				return false
			end
		end
	end
	return true
end

-- put a car on a lane near the player, out of sight. Returns false if no good spot this tick.
local function placeNear(ctx: any, car: Car): boolean
	local lanes = ctx.lanes
	if #lanes == 0 then
		return false
	end
	local focus = ctx.playerPos or ctx.camPos
	local order = {}
	for _, l in lanes do
		local d, dist = R.nearest(l.path, focus.X, focus.Z)
		if dist < 260 then
			table.insert(order, { lane = l, d = d, dist = dist })
		end
	end
	if #order == 0 then
		return false
	end
	for _ = 1, 6 do
		local o = order[rng:NextInteger(1, #order)]
		local d = o.d + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(110, 230)
		d = R.wrap(o.lane.path, d)
		local x, z = R.sample(o.lane.path, d)
		local off = Vector3.new(x - ctx.camPos.X, 0, z - ctx.camPos.Z)
		if R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, cfg.Traffic.SpawnMinDist, ctx.cfg.People.BehindDot)
			and clearAt(o.lane, d, car) then
			car.lane = o.lane
			car.d = d
			car.cruise = o.lane.speed or rng:NextNumber(cfg.Traffic.Speed[1], cfg.Traffic.Speed[2])
			car.cruise = math.clamp(car.cruise * rng:NextNumber(0.9, 1.1), cfg.Traffic.Speed[1], cfg.Traffic.Speed[2])
			car.v = car.cruise * 0.8
			car.stuck = 0
			pose(car)
			move(car)
			return true
		end
	end
	return false
end

local function park(car: Car)
	car.active = false
	car.lane = nil
	car.cf = CFrame.new(0, 2000, 0)
	move(car)
	setSpot(car, false)
	if AmbientTraffic.sound then
		AmbientTraffic.sound.remove(car.key)
		AmbientTraffic.sound.remove(car.key .. "E")
	end
end

---------------------------------------------------------------- loop

function AmbientTraffic.init(ctx: any)
	cfg = ctx.cfg
	R = ctx.R
	AmbientTraffic.sound = ctx.sound
	folder = Instance.new("Folder")
	folder.Name = "Traffic"
	folder.Parent = ctx.folder
	if #ctx.lanes == 0 then
		return
	end
	task.spawn(function()
		-- the map car template is copied in by DressHoodLife; give it a moment to replicate
		local lib = ReplicatedStorage:WaitForChild("MTL_AmbientCars", 10)
		if lib then
			lib:WaitForChild(cfg.Traffic.Template, 5)
		end
		for i = 1, cfg.Traffic.Max do
			local car = makeCar(i)
			if car then
				car.music = rng:NextNumber() < cfg.Traffic.MusicShare
				table.insert(cars, car)
				park(car)
			end
			task.wait()
		end
	end)
end

function AmbientTraffic.step(ctx: any, dt: number, far: boolean)
	if #cars == 0 then
		return
	end
	local T = cfg.Traffic
	if far then
		local want = if ctx.night then T.Count[1] else T.Count[2]
		if ctx.hour >= 1.5 and ctx.hour < 5 then
			want = math.max(2, want - 2)
		end
		local n = 0
		for _, car in cars do
			if car.active then
				n += 1
			end
		end
		local focus = ctx.playerPos or ctx.camPos
		for _, car in cars do
			if car.active then
				local dist = (car.pos - focus).Magnitude
				local off = Vector3.new(car.pos.X - ctx.camPos.X, 0, car.pos.Z - ctx.camPos.Z)
				local hidden = R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, T.SpawnMinDist, ctx.cfg.People.BehindDot)
				if n > want and hidden and dist > T.SpawnMinDist then
					park(car)
					n -= 1
				elseif dist > T.RecycleDist and hidden then
					placeNear(ctx, car)
				end
			elseif n < want then
				car.active = placeNear(ctx, car)
				if car.active then
					n += 1
					if ctx.sound then
						ctx.sound.emitter(car.key .. "E", "Engine", function()
							return car.pos
						end)
						if car.music then
							ctx.sound.emitter(car.key, "CarMusic", function()
								return car.pos
							end)
						end
					end
				end
			end
		end
		-- night lights: Neon on every car, a real SpotLight on the nearest 2
		local on = ctx.night
		if on ~= lightsOn then
			lightsOn = on
			for _, car in cars do
				setLights(car, on)
			end
		end
		local dists = {}
		for i, car in cars do
			dists[i] = if car.active and on then (car.pos - ctx.camPos).Magnitude else nil
		end
		local lit = {}
		for _, i in R.nearestN(dists, T.LitCars, #cars) do
			lit[i] = true
		end
		for i, car in cars do
			setSpot(car, lit[i] == true)
		end
	end
	for _, car in cars do
		if car.active and car.lane then
			local blockedDist = blockedAhead(ctx, car)
			local corner = R.cornerAhead(car.lane.path, car.d + car.halfLen, T.CornerSlowDist + 5)
			local target = R.targetSpeed(car.cruise, corner, T, blockedDist)
			car.v = R.approach(car.v, target, T.Accel, T.Brake, dt)
			car.d = R.wrap(car.lane.path, car.d + car.v * dt)
			car.spin = (car.spin - car.v * dt / T.WheelRadius) % (math.pi * 2)
			-- honk when stuck behind the player
			if car.v < 0.5 and blockedDist < T.StopAhead then
				car.stuck += dt
				if car.stuck > T.HonkAfter and ctx.now - car.honkAt > T.HonkCooldown then
					car.honkAt = ctx.now
					if ctx.sound then
						ctx.sound.oneShot("Horn", car.pos)
					end
				end
			else
				car.stuck = 0
			end
			local near = (car.pos - ctx.camPos).Magnitude < 220
			if near or far then
				pose(car)
				move(car)
			end
		end
	end
end

function AmbientTraffic.stats(): number
	local n = 0
	for _, car in cars do
		if car.active then
			n += 1
		end
	end
	return n
end

return AmbientTraffic
