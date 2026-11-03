--!strict
-- Makes the map's cars read from across the street (client only, nothing replicates):
--   * the paint gets a little reflectance so it catches the sky, street lights and shop glow instead of
--     sinking into the night shade
--   * at dusk the head lights go white Neon and the tail lights red Neon (bloom makes them glow), and the
--     closest few cars also cast a small red/white light onto the road
-- A car is any Model with a "Color" body part and "Glass" light parts (the map's ParkedCar / Sedan kit).
local RunService = game:GetService("RunService")

local CarGlow = {}

local PAINT_REFLECTANCE = 0.12
local ON_AT = 0.55 -- nightness above which the lights switch on
local LIT_CARS = 10 -- closest cars that get real lights
local LIT_RADIUS = 160
local REFRESH = 0.5

local WHITE = Color3.fromRGB(255, 244, 226)
local RED = Color3.fromRGB(255, 40, 32)

type Light = { part: BasePart, material: Enum.Material, color: Color3, red: boolean }
type Car = { root: BasePart, lights: { Light }, glow: { PointLight } }

local cars: { Car } = {}
local seen: { [Instance]: boolean } = {} -- parts already handled
local lightsOn = false

local function isRedGlass(p: BasePart): boolean
	local c = p.Color
	return c.R > 0.5 and c.G < 0.35 and c.B < 0.35
end

local function isWhiteGlass(p: BasePart): boolean
	local c = p.Color
	return p.Material == Enum.Material.Neon or (c.R > 0.85 and c.G > 0.85 and c.B > 0.85)
end

local byModel: { [Instance]: Car } = {}

-- the car a part belongs to: the closest ancestor Model that has a "Color" body part
local function carModelOf(part: Instance): Model?
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:FindFirstChild("Color", true) then
			return m
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- parts stream in one by one, so cars are built up part by part
local function addPart(d: BasePart)
	if seen[d] then
		return
	end
	local isBody = d.Name == "Color"
	local isLight = d.Name == "Glass" or d.Name == "Tail" or d.Name == "Lights"
	if not isBody and not isLight then
		return
	end
	local model = carModelOf(d)
	if not model then
		return
	end
	seen[d] = true
	local car = byModel[model]
	if not car then
		local root = model:FindFirstChild("Color", true) :: BasePart
		car = { root = root, lights = {}, glow = {} }
		byModel[model] = car
		table.insert(cars, car)
	end
	if isBody then
		d.Reflectance = math.max(d.Reflectance, PAINT_REFLECTANCE)
		return
	end
	local red = isRedGlass(d)
	if red or isWhiteGlass(d) then
		local l = { part = d, material = d.Material, color = d.Color, red = red }
		table.insert(car.lights, l)
		if lightsOn then
			d.Material = Enum.Material.Neon
			d.Color = if red then RED else WHITE
		end
	end
end

local function scan(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			addPart(d)
		end
	end
end

local function setLights(car: Car, on: boolean)
	for _, l in car.lights do
		if not l.part.Parent then
			continue
		end
		if on then
			l.part.Material = Enum.Material.Neon
			l.part.Color = if l.red then RED else WHITE
		else
			l.part.Material = l.material
			l.part.Color = l.color
		end
	end
end

local function clearGlow(car: Car)
	for _, g in car.glow do
		g:Destroy()
	end
	car.glow = {}
end

local function addGlow(car: Car)
	if #car.glow > 0 then
		return
	end
	local front, back
	for _, l in car.lights do
		if l.red and not back then
			back = l.part
		elseif not l.red and not front then
			front = l.part
		end
	end
	for _, spec in { { front, WHITE, 1.4, 14 }, { back, RED, 0.9, 8 } } do
		local p = spec[1] :: BasePart?
		if p then
			local light = Instance.new("PointLight")
			light.Name = "MTL_CarGlow"
			light.Color = spec[2] :: Color3
			light.Brightness = spec[3] :: number
			light.Range = spec[4] :: number
			light.Shadows = false
			light.Parent = p
			table.insert(car.glow, light)
		end
	end
end

function CarGlow.init(nightness: () -> number)
	local map = workspace:FindFirstChild("ViceBay")
	if map then
		scan(map)
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			addPart(d)
		end
	end)

	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < REFRESH then
			return
		end
		timer = 0
		local on = nightness() >= ON_AT
		if on ~= lightsOn then
			lightsOn = on
			for _, car in cars do
				setLights(car, on)
				if not on then
					clearGlow(car)
				end
			end
		end
		if not on then
			return
		end
		-- real lights only on the closest cars
		local cam = workspace.CurrentCamera.CFrame.Position
		local near = {}
		for _, car in cars do
			if car.root.Parent and #car.lights > 0 then
				local d = (car.root.Position - cam).Magnitude
				if d < LIT_RADIUS then
					table.insert(near, { car = car, d = d })
				end
			end
		end
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
		local keep = {}
		for i = 1, math.min(#near, LIT_CARS) do
			keep[near[i].car] = true
			addGlow(near[i].car)
		end
		for _, car in cars do
			if not keep[car] and #car.glow > 0 then
				clearGlow(car)
			end
		end
	end)
end

return CarGlow
