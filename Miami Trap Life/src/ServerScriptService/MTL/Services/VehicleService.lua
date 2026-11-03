--!strict
-- Cars: the phone's Garage app spawns a car you own next to you, and its dealer tab sells them (Config/Vehicles).
-- One live car per player: spawning another (or the same one again) removes the old one first. Leaving the game
-- removes it too. Only the owner can drive it (others are lifted out of the driver's seat). Car bodies are copied
-- into ServerStorage.MTL_Cars in Studio; cars with a `chassis` spec are made drivable by Services/Chassis at spawn,
-- the Oros brings its own A-Chassis. This service never touches a car that sits in the Workspace.
--
-- Phone actions: "spawnCar" { id }   "despawnCar" {}   "buyCar" { id }   "styleCar" { id, paint?, glow? }
-- API: VehicleService.give(player, carId)   VehicleService.owns(player, carId) -> bool
--      VehicleService.spawn(player, carId) -> ok, reason   VehicleService.despawn(player)
-- Player attribute MTL_Car = the id of the car that's out (nil when none); the Garage app reads it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)
local Chassis = require(script.Parent.Chassis)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PhoneService = require(script.Parent.PhoneService)
local Notify = require(script.Parent.Notify)

local VehicleService = {}

local T = Vehicles.Tuning
local G = Vehicles.Guard
local live: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}
type GuardState = { strikes: number, lastStrike: number, lastPos: Vector3?, air: number, flipped: number, empty: number }
local guard: { [Player]: GuardState } = {}

-- every "no" the player gets says why (house rule: Notify.refuse when the HUD has it)
local function refuse(player: Player, reason: string)
	local f = (Notify :: any).refuse
	if type(f) == "function" then
		f(player, reason)
	else
		Notify.toast(player, reason)
	end
end

local function log(...)
	print("[MTL Cars]", ...)
end

local function garage(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.Garage = data.Garage or { Owned = {}, Last = "", Bought = {} }
	data.Garage.Owned = data.Garage.Owned or {}
	data.Garage.Bought = data.Garage.Bought or {}
	data.Garage.Style = data.Garage.Style or {} -- Style[carId] = { paint = id, glow = id, glowOwned = bool }
	return data.Garage
end

-- Paint + underglow on a live car (Config/Vehicles.Style). The body's main colour is the one covering the most
-- surface; those parts are tagged once (MTL_Paint) so a later repaint, or "Factory", knows which they are.
local function isWheelPart(p: Instance, car: Model): boolean
	local a = p.Parent
	while a and a ~= car do
		if string.match(a.Name, "^Wheel_") or a.Name == "Rig" then
			return true
		end
		a = a.Parent
	end
	return string.match(p.Name, "^Wheel_") ~= nil
end

local function colorKey(c: Color3): string
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function applyStyle(car: Model, style: any)
	style = style or {}
	-- find + tag the paint once
	if car:GetAttribute("MTL_FactoryColor") == nil then
		local area: { [string]: number } = {}
		local pick: { [string]: Color3 } = {}
		for _, p in car:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency == 0 and p.Material ~= Enum.Material.Glass and p.Material ~= Enum.Material.Neon and not p:IsA("VehicleSeat") and not isWheelPart(p, car) then
				local key = colorKey(p.Color)
				local s = p.Size
				area[key] = (area[key] or 0) + s.X * s.Y + s.Y * s.Z + s.X * s.Z
				pick[key] = p.Color
			end
		end
		local best, bestArea = nil, 0
		for k, a in area do
			if a > bestArea then
				best, bestArea = k, a
			end
		end
		if not best then
			return
		end
		local factory = pick[best]
		car:SetAttribute("MTL_FactoryColor", factory)
		for _, p in car:GetDescendants() do
			if p:IsA("BasePart") and not isWheelPart(p, car) then
				if colorKey(p.Color) == best then
					p:SetAttribute("MTL_Paint", true)
				end
			end
		end
	end
	local paint = Vehicles.paint(style.paint or "Factory")
	local color: Color3 = (paint and paint.color) or car:GetAttribute("MTL_FactoryColor") :: Color3
	for _, p in car:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("MTL_Paint") then
			p.Color = color
		end
	end

	-- underglow: a thin neon plate + light under the floor, welded to the body
	local old = car:FindFirstChild("Underglow")
	if old then
		old:Destroy()
	end
	local glow = Vehicles.glow(style.glow or "Off")
	if glow and glow.color then
		local anchor = car.PrimaryPart or driveSeat(car)
		if anchor then
			local cf, size = car:GetBoundingBox()
			local pivot = car:GetPivot()
			local plate = Instance.new("Part")
			plate.Name = "Underglow"
			plate.Size = Vector3.new(math.max(1, size.X * 0.7), 0.1, math.max(2, size.Z * 0.75))
			plate.CFrame = pivot * CFrame.new(pivot:PointToObjectSpace(cf.Position).X, 0.35, pivot:PointToObjectSpace(cf.Position).Z)
			plate.Material = Enum.Material.Neon
			plate.Color = glow.color
			plate.Transparency = 0.3
			plate.CanCollide = false
			plate.CanQuery = false
			plate.CanTouch = false
			plate.Massless = true
			plate.Anchored = anchor.Anchored
			local light = Instance.new("PointLight")
			light.Color = glow.color
			light.Range = 14
			light.Brightness = 2.2
			light.Shadows = false
			light.Parent = plate
			local w = Instance.new("WeldConstraint")
			w.Part0 = anchor
			w.Part1 = plate
			w.Parent = plate
			plate.Parent = car
		end
	end
end

local function spawnFolder(): Folder
	local f = workspace:FindFirstChild(Vehicles.SpawnFolder)
	if not f then
		f = Instance.new("Folder")
		f.Name = Vehicles.SpawnFolder
		f.Parent = workspace
	end
	return f :: Folder
end

local function driveSeat(model: Model): VehicleSeat?
	local s = model:FindFirstChild("DriveSeat", true)
	if s and s:IsA("VehicleSeat") then
		return s
	end
	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function unseat(hum: Humanoid)
	local seat = hum.SeatPart
	if seat then
		local w = seat:FindFirstChild("SeatWeld")
		if w then
			w:Destroy()
		end
	end
	hum.Sit = false
	hum.Jump = true
end

function VehicleService.owns(player: Player, carId: string): boolean
	local g = garage(player)
	return g ~= nil and g.Owned[carId] == true
end

function VehicleService.give(player: Player, carId: string)
	local g = garage(player)
	if g and Vehicles.get(carId) and not g.Owned[carId] then
		g.Owned[carId] = true
		DataService.push(player)
	end
end

-- The dealer: takes the cash and adds the car. Returns ok, message.
function VehicleService.buy(player: Player, carId: string): (boolean, string)
	local def = Vehicles.get(carId)
	if not def or type(def.price) ~= "number" then
		return false, "That car isn't for sale"
	end
	local g = garage(player)
	if not g then
		return false, "Try again in a moment"
	end
	if g.Owned[carId] then
		return false, "You already own the " .. def.name
	end
	if not EconomyService.spend(player, def.price, "car:" .. carId) then
		return false, "Not enough cash for the " .. def.name
	end
	g.Owned[carId] = true
	g.Bought[carId] = true
	DataService.push(player)
	log(player.Name, "bought", carId, "for", def.price)
	return true, "The " .. def.name .. " is yours. Spawn it from your Garage."
end

-- Paint and/or underglow for a car you own. Returns ok, message. Restyles it live if it's out.
function VehicleService.style(player: Player, carId: string, paintId: any, glowId: any): (boolean, string)
	local def = Vehicles.get(carId)
	local g = garage(player)
	if not def or not g then
		return false, "Try again in a moment"
	end
	if not g.Owned[carId] then
		return false, "You don't own that car"
	end
	local S = Vehicles.Style
	local st = g.Style[carId] or {}
	local cost = 0
	local paint = if type(paintId) == "string" then Vehicles.paint(paintId) else nil
	local glow = if type(glowId) == "string" then Vehicles.glow(glowId) else nil
	if paintId ~= nil and not paint or glowId ~= nil and not glow then
		return false, "That style isn't available"
	end
	if paint and paint.id ~= (st.paint or "Factory") and paint.color then
		cost += S.PaintPrice
	end
	if glow and glow.color and not st.glowOwned then
		cost += S.GlowPrice
	end
	if cost > 0 and not EconomyService.spend(player, cost, "carStyle:" .. carId) then
		return false, "Not enough cash (" .. string.format("$%d", cost) .. ")"
	end
	if paint then
		st.paint = paint.id
	end
	if glow then
		st.glow = glow.id
		if glow.color then
			st.glowOwned = true
		end
	end
	g.Style[carId] = st
	DataService.push(player)
	local car = live[player]
	if car and car:GetAttribute("MTL_CarId") == carId then
		pcall(applyStyle, car, st)
	end
	return true, if cost > 0 then ("Done. -$" .. cost) else "Done"
end

function VehicleService.despawn(player: Player)
	local car = live[player]
	live[player] = nil
	local st = guard[player]
	if st then -- strikes stay (re-spawning doesn't wipe them); the rest starts fresh
		st.lastPos, st.air, st.flipped, st.empty = nil, 0, 0, 0
	end
	if car then
		car:Destroy()
	end
	if player.Parent then
		player:SetAttribute("MTL_Car", nil)
	end
end

-- A clear, flat-ish spot next to the player, facing the way they face. Returns the model's pivot, or nil.
local function findSpot(model: Model, root: BasePart): CFrame?
	local bbCF, size = model:GetBoundingBox()
	local rel = bbCF:ToObjectSpace(model:GetPivot())
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	local facing = CFrame.lookAt(Vector3.zero, look)

	local ignore: { Instance } = { spawnFolder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = ignore
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore

	local function clear(cf: CFrame, sz: Vector3): boolean
		for _, part in workspace:GetPartBoundsInBox(cf, sz, overlap) do
			if part.CanCollide and part ~= workspace.Terrain then
				return false
			end
		end
		return true
	end
	-- facings to try at each spot, best first: the way the player looks, then the other three
	local facings = {
		facing,
		CFrame.lookAt(Vector3.zero, -look),
		CFrame.lookAt(Vector3.zero, right),
		CFrame.lookAt(Vector3.zero, -right),
	}
	local reach = T.SpawnDistance + math.max(size.X, size.Z) * 0.25
	local fallback: CFrame? = nil
	for _, dir in { right, -right, look, -look } do
		local spot = root.Position + dir * reach
		local hit = workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), ray)
		if hit and hit.Normal.Y > 0.8 then
			local base = CFrame.new(hit.Position + Vector3.new(0, size.Y / 2 + 0.4, 0))
			for _, f in facings do
				local box = base * f
				if clear(box + Vector3.new(0, 0.5, 0), size * 0.9) then
					-- prefer a facing with an open lane ahead (so W doesn't drive straight into a wall)
					local lane = box * CFrame.new(0, 0.5, -(size.Z * 0.5 + size.Z * 0.75))
					if clear(lane, Vector3.new(size.X * 0.9, size.Y * 0.6, size.Z * 1.5)) then
						return box * rel
					end
					fallback = fallback or box * rel
				end
			end
		end
	end
	return fallback
end

local function lockToOwner(player: Player, car: Model, seat: VehicleSeat, def: any)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum and Players:GetPlayerFromCharacter(hum.Parent) ~= player then
			task.defer(unseat, hum)
			return
		end
		-- the owner drives it on their machine; parked, it's the server's
		task.defer(function()
			if seat.Parent and not seat.Anchored then
				pcall(function()
					seat:SetNetworkOwner(if seat.Occupant then player else nil)
				end)
			end
		end)
	end)
	if seat:FindFirstChildWhichIsA("ProximityPrompt") then
		return -- the model brings its own seat prompt
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = T.PromptDistance
	prompt.Parent = seat
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player then
			refuse(who, "That's not your car")
			return
		end
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not seat.Occupant and not hum.SeatPart then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)
end

function VehicleService.spawn(player: Player, carId: string): (boolean, string?)
	local def = Vehicles.get(carId)
	if not def then
		return false, "Unknown car"
	end
	if not VehicleService.owns(player, carId) then
		return false, "You don't own that car"
	end
	local now = os.clock()
	if now - (lastSpawn[player] or -1e9) < T.SpawnCooldown then
		return false, "Wait a few seconds"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return false, "You can't do that right now"
	end
	if player:GetAttribute("MTL_InHome") then
		return false, "Go outside first"
	end
	if hum.SeatPart then
		return false, "Get out of your seat first"
	end
	if root.AssemblyLinearVelocity.Magnitude > T.MaxSpeedToSpawn then
		return false, "Stand still first"
	end
	local folder = ServerStorage:FindFirstChild(Vehicles.TemplateFolder)
	local template = folder and folder:FindFirstChild(def.template)
	if not template or not template:IsA("Model") then
		warn("[MTL Cars] missing template ServerStorage." .. Vehicles.TemplateFolder .. "." .. tostring(def.template))
		return false, "That car isn't in the garage yet"
	end

	local car = (template :: Model):Clone()
	local pivot = findSpot(car, root)
	if not pivot then
		car:Destroy()
		return false, "No room for it here"
	end
	lastSpawn[player] = now
	VehicleService.despawn(player) -- one car out at a time
	car.Name = player.Name .. "_" .. def.id
	car:SetAttribute("MTL_Owner", player.UserId)
	car:SetAttribute("MTL_CarId", def.id)
	if def.chassis then
		local ok, err = pcall(Chassis.rig, car, def.chassis)
		if not ok then
			warn("[MTL Cars] couldn't rig", def.id, err)
			car:Destroy()
			return false, "That car can't drive right now"
		end
	end
	do
		local g0 = garage(player)
		local ok, err = pcall(applyStyle, car, g0 and g0.Style[def.id])
		if not ok then
			warn("[MTL Cars] style failed", def.id, err)
		end
	end
	car:PivotTo(pivot)
	car.Parent = spawnFolder()
	if def.chassis then
		Chassis.release(car)
	end
	live[player] = car
	player:SetAttribute("MTL_Car", def.id)

	local g = garage(player)
	if g then
		g.Last = def.id
		DataService.push(player)
	end

	local seat = driveSeat(car)
	if seat then
		lockToOwner(player, car, seat, def)
		if T.SeatOnSpawn then
			task.delay(0.3, function()
				if seat.Parent and not seat.Occupant and hum.Parent and hum.Health > 0 then
					seat:Sit(hum)
				end
			end)
		end
	else
		warn("[MTL Cars]", def.id, "has no VehicleSeat")
	end
	car.Destroying:Connect(function()
		if live[player] == car then
			live[player] = nil
			if player.Parent then
				player:SetAttribute("MTL_Car", nil)
			end
		end
	end)
	log(player.Name, "spawned", def.id)
	return true, nil
end

-- Car safety, 4 times a second for every live car:
--   speed above the car's top speed (with slack), a jump across the map, or hovering with nothing below
--   = a strike; Guard.Strikes strikes = impounded (despawned) with a reason. Strikes fade over time.
--   Flipped with a driver = put back on its wheels; flipped or abandoned with nobody in it = towed.

local function towed(player: Player, why: string)
	VehicleService.despawn(player)
	refuse(player, why)
	log(player.Name, "car removed:", why)
end

local function strike(player: Player, st: GuardState, what: string)
	st.strikes += 1
	st.lastStrike = os.clock()
	log(player.Name, "car strike", st.strikes, what)
	if st.strikes >= G.Strikes then
		st.strikes = 0
		towed(player, "Your car was impounded (" .. what .. "). Spawn it again from the Garage.")
	end
end

local function guardStep(dt: number)
	local now = os.clock()
	for player, car in live do
		local seat = driveSeat(car)
		local root = car.PrimaryPart or seat
		if not seat or not root or not root.Parent then
			continue
		end
		local st = guard[player]
		if not st then
			st = { strikes = 0, lastStrike = now, lastPos = nil, air = 0, flipped = 0, empty = 0 }
			guard[player] = st
		end
		if st.strikes > 0 and now - st.lastStrike > G.StrikeForgetSeconds then
			st.strikes -= 1
			st.lastStrike = now
		end
		local def = Vehicles.get(car:GetAttribute("MTL_CarId") :: any)
		local top = (def and def.chassis and def.chassis.maxSpeed) or G.DefaultTopSpeed
		local pos = root.Position
		local vel = root.AssemblyLinearVelocity
		local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local driven = seat.Occupant ~= nil

		if driven then
			st.empty = 0
			if flat > top * G.SpeedSlack + G.SpeedExtra then
				strike(player, st, "too fast")
				if not live[player] then
					continue
				end
			end
			if st.lastPos and (pos - st.lastPos).Magnitude > G.TeleportStuds + flat * dt * 2 then
				strike(player, st, "teleported")
				if not live[player] then
					continue
				end
			end
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { car, player.Character :: any }
			local ground = workspace:Raycast(pos, Vector3.new(0, -G.HoverRay, 0), ray)
			if not ground and vel.Y > -4 then
				st.air += dt
				if st.air > G.HoverSeconds then
					st.air = 0
					strike(player, st, "flying")
					if not live[player] then
						continue
					end
				end
			else
				st.air = 0
			end
		else
			-- abandoned: owner gone or far away
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp or (hrp.Position - pos).Magnitude > G.AbandonStuds then
				st.empty += dt
				if st.empty > G.AbandonSeconds then
					towed(player, "Your car was towed. You left it too long.")
					continue
				end
			else
				st.empty = 0
			end
		end
		st.lastPos = pos

		-- flipped
		if root.CFrame.UpVector.Y < 0.3 then
			st.flipped += dt
			if driven and st.flipped > G.FlippedSeconds then
				st.flipped = 0
				local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
				local rel = root.CFrame:ToObjectSpace(car:GetPivot())
				car:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + look) * rel)
				for _, p in car:GetDescendants() do
					if p:IsA("BasePart") then
						p.AssemblyLinearVelocity = Vector3.zero
						p.AssemblyAngularVelocity = Vector3.zero
					end
				end
			elseif not driven and st.flipped > G.EmptyFlippedSeconds then
				towed(player, "Your car was towed. It was on its roof.")
				continue
			end
		else
			st.flipped = 0
		end
		-- fell out of the world
		if pos.Y < workspace.FallenPartsDestroyHeight + 30 then
			towed(player, "Your car fell out of the map. Spawn it again from the Garage.")
		end
	end
end

function VehicleService.init()
	DataService.Ready:Connect(function(player, data)
		data.Garage = data.Garage or { Owned = {}, Last = "", Bought = {} }
		data.Garage.Owned = data.Garage.Owned or {}
		data.Garage.Bought = data.Garage.Bought or {}
		for _, car in Vehicles.Cars do
			if car.starter then
				data.Garage.Owned[car.id] = true
			end
		end
		for _, id in Vehicles.Grants[player.UserId] or {} do
			if Vehicles.get(id) then
				data.Garage.Owned[id] = true
			end
		end
	end)

	PhoneService.onAction("styleCar", function(player, payload)
		if type(payload.id) ~= "string" then
			return
		end
		local ok, msg = VehicleService.style(player, payload.id, payload.paint, payload.glow)
		if ok then
			Notify.toast(player, msg)
		else
			refuse(player, msg)
		end
	end)

	PhoneService.onAction("buyCar", function(player, payload)
		if type(payload.id) ~= "string" then
			return
		end
		local ok, msg = VehicleService.buy(player, payload.id)
		if ok then
			Notify.toast(player, msg)
		else
			refuse(player, msg)
		end
	end)

	PhoneService.onAction("spawnCar", function(player, payload)
		if type(payload.id) ~= "string" then
			return
		end
		local ok, reason = VehicleService.spawn(player, payload.id)
		if ok then
			local def = Vehicles.get(payload.id)
			Notify.toast(player, "Your " .. (if def then def.name else "car") .. " is here")
		elseif reason then
			refuse(player, reason)
		end
	end)
	PhoneService.onAction("despawnCar", function(player)
		if live[player] then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.SeatPart and hum.SeatPart:IsDescendantOf(live[player]) then
				unseat(hum)
			end
			VehicleService.despawn(player)
			Notify.toast(player, "Car put away")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		VehicleService.despawn(player)
		lastSpawn[player] = nil
		guard[player] = nil
	end)
	task.spawn(function()
		local step = 1 / G.Hz
		while true do
			local dt = task.wait(step)
			local ok, err = pcall(guardStep, dt)
			if not ok then
				warn("[MTL Cars] guard:", err)
			end
		end
	end)
	log("ready,", #Vehicles.Cars, "car(s)")
end

return VehicleService
