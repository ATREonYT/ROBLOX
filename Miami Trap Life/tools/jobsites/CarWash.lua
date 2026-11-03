-- Bay Suds job (CarWash, Level 8) moved to the real Sudz Car Wash tunnel in HoodWest (it was a placeholder spot on
-- a road junction at (-1196,-360)). Needs Config/Jobs CarWash.mapJob to include "Car Wash Attendant" so the site
-- centre follows the map's JobSpot at (-1840,-190).
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_CarWash)()
-- Builds HoodWest.SudzCarWash.CarWashV2: a car parked in the tunnel under a foam arch (the Lane station is at its
-- nose), conveyor rails, dryers, tunnel lights, an attendant booth with the time clock, a pay kiosk.
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M

local FY = 2.2 -- tunnel slab top
local ZL = -227 -- lane centre line (tunnel runs along X, walls at z -216 / -238)
local V = Vector3.new
local function W(x, y, z)
	return CFrame.new(x, FY + y, z)
end

return function()
	local sudz = workspace.ViceBay.Landmarks.HoodWest:FindFirstChild("SudzCarWash")
	assert(sudz, "SudzCarWash not found")
	local old = sudz:FindFirstChild("CarWashV2")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "CarWashV2"
	model:SetAttribute("MTL_Style", "JobInteriorV2")
	local b = K.builder(model)
	local P, group = b.P, b.group
	local BLUE, YEL, PINK = C(30, 120, 220), C(250, 200, 40), C(230, 60, 150)

	-- conveyor + guide rails + wet floor
	P("Conveyor", V(56, 0.12, 1.2), W(-1888, 0.06, ZL - 2.6), C(60, 62, 66), M.DiamondPlate, { parent = model })
	for _, dz in { -3.4, -1.8 } do
		P("GuideRail", V(56, 0.4, 0.2), W(-1888, 0.2, ZL + dz), YEL, M.Metal, { parent = model })
	end
	P("WetFloor", V(62, 0.02, 20), W(-1887.5, 0.012, ZL), C(80, 100, 120), M.Glass, { parent = model, deco = true, Transparency = 0.6, Reflectance = 0.2 })
	-- foam arch at the entrance end
	local arch = group("FoamArch")
	local ax = -1866
	for _, dz in { -9.5, 9.5 } do
		P("ArchPost", V(0.8, 11, 0.8), W(ax, 5.5, ZL + dz), C(200, 200, 204), M.Metal, { parent = arch })
	end
	P("ArchBar", V(0.8, 0.8, 19.8), W(ax, 11.2, ZL), C(200, 200, 204), M.Metal, { parent = arch })
	for i = 0, 8 do
		local col = ({ PINK, BLUE, YEL })[(i % 3) + 1]
		P("Nozzle", V(0.5, 0.6, 0.5), W(ax, 10.6, ZL - 8 + i * 2), col, M.Neon, { parent = arch, deco = true })
	end
	local fs = P("FoamSign", V(0.2, 1.4, 10), W(ax, 12.4, ZL), C(20, 20, 24), M.SmoothPlastic, { parent = arch, deco = true })
	K.sign(fs, Enum.NormalId.Right, "TRIPLE FOAM", C(20, 20, 24), C(255, 120, 200), { lit = true })
	K.sign(fs, Enum.NormalId.Left, "TRIPLE FOAM", C(20, 20, 24), C(255, 120, 200), { lit = true })
	-- dryers at the exit end
	local dx = -1914
	for _, dz in { -9.2, 9.2 } do
		P("Dryer", V(3, 6, 1.6), W(dx, 5, ZL + dz), C(200, 200, 204), M.Metal, { parent = model })
		P("DryerMouth", V(2.6, 4.6, 0.1), W(dx, 5, ZL + dz - math.sign(dz) * 0.85), C(30, 30, 34), M.SmoothPlastic, { parent = model, deco = true })
	end
	P("DryerTop", V(3, 1.6, 14), W(dx, 11.5, ZL), C(200, 200, 204), M.Metal, { parent = model })
	-- tunnel light strips (blue LED) along both walls
	for _, dz in { -10.8, 10.8 } do
		P("LedStrip", V(60, 0.25, 0.1), W(-1887.5, 9.8, ZL + dz), C(60, 160, 255), M.Neon, { parent = model, deco = true })
	end
	for _, x in { -1868, -1888, -1908 } do
		local a = P("LightPoint", V(0.2, 0.2, 0.2), W(x, 12.5, ZL), C(255, 255, 255), M.SmoothPlastic, { parent = model, deco = true, Transparency = 1 })
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 0.8
		l.Color = C(190, 220, 255)
		l.Shadows = false
		l.Parent = a
	end
	local neutral = P("NeutralSign", V(0.15, 2.0, 7), W(-1857.2, 9.0, ZL - 9.5), YEL, M.SmoothPlastic, { parent = model, deco = true })
	K.sign(neutral, Enum.NormalId.Right, "PUT CAR IN NEUTRAL\nHANDS OFF THE WHEEL", YEL, C(20, 20, 20))
	-- the car in the lane, nose to the exit (west)
	local src
	for _, car in workspace.ViceBay:GetDescendants() do
		if car:IsA("Model") and car.Name == "ParkedCar" and car:FindFirstChild("Color", true) then
			src = car
			break
		end
	end
	local laneSpot = V(ax - 2.0, FY + 2.5, ZL)
	if src then
		local car = src:Clone()
		car.Name = "WashLaneCar"
		local cf, size = car:GetBoundingBox()
		local long = if size.X > size.Z then "X" else "Z"
		local rot = if long == "Z" then CFrame.Angles(0, math.rad(90), 0) else CFrame.identity
		local target = CFrame.new(ax - 2.0 - math.max(size.X, size.Z) / 2, FY + size.Y / 2, ZL) * rot * cf.Rotation
		car:PivotTo(target * cf:ToObjectSpace(car:GetPivot()))
		for _, d in car:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanQuery = false
				if d.Name == "Color" then
					d.Color = C(40, 44, 52)
				end
			end
		end
		car.Parent = model
		laneSpot = V(ax - 1.0, FY + 2.5, ZL) -- right at the nose, under the foam arch
	end

	-- attendant booth with the time clock (outside the entrance, south side)
	local booth = group("Booth")
	local bx, bz = -1849, -246
	P("BoothFloor", V(7, 0.3, 7), W(bx, 0.15, bz), C(150, 150, 146), M.Concrete, { parent = booth })
	for _, s in { { -3.4, 0, 0.2, 7 }, { 3.4, 0, 0.2, 7 }, { 0, -3.4, 7, 0.2 } } do
		P("BoothWall", V(s[3], 8, s[4]), W(bx + s[1], 4.3, bz + s[2]), C(236, 236, 232), M.Plaster, { parent = booth })
	end
	-- front (+Z, toward the lane): low wall + window, door gap on the west end
	P("BoothFrontLow", V(4.6, 3.4, 0.2), W(bx + 1.0, 2.0, bz + 3.4), C(236, 236, 232), M.Plaster, { parent = booth })
	P("BoothWindow", V(4.6, 3.8, 0.12), W(bx + 1.0, 5.6, bz + 3.4), C(170, 200, 220), M.Glass, { parent = booth, Transparency = 0.5 })
	P("BoothHeader", V(7, 0.9, 0.2), W(bx, 7.95, bz + 3.4), C(236, 236, 232), M.Plaster, { parent = booth })
	P("BoothRoof", V(8, 0.5, 8), W(bx, 8.55, bz), BLUE, M.Metal, { parent = booth })
	local bsign = P("BoothSign", V(6, 1.0, 0.1), W(bx, 9.4, bz + 3.9), BLUE, M.SmoothPlastic, { parent = booth, deco = true })
	K.sign(bsign, Enum.NormalId.Back, "ATTENDANT", BLUE, C(255, 255, 255), { lit = true })
	P("BoothDesk", V(5, 0.2, 1.4), W(bx + 1.0, 3.4, bz + 2.5), C(120, 90, 60), M.Wood, { parent = booth })
	P("BoothStool", V(1.0, 2.6, 1.0), W(bx + 1.0, 1.3, bz + 0.8), C(30, 30, 34), M.SmoothPlastic, { parent = booth })
	P("BoothAC", V(1.6, 1.0, 1.0), W(bx + 3.9, 6.5, bz - 1.5), C(220, 220, 216), M.Metal, { parent = booth })
	local tc = group("TimeClock", booth)
	P("ClockBody", V(0.6, 1.6, 1.2), W(bx - 3.0, 4.6, bz), C(214, 210, 196), M.SmoothPlastic, { parent = tc })
	P("ClockDigits", V(0.04, 0.22, 0.6), W(bx - 2.68, 5.0, bz), C(255, 80, 60), M.Neon, { parent = tc, deco = true })
	local clockSpot = V(bx - 1.5, FY + 2.5, bz)
	-- pay kiosk at the entrance (north of the lane mouth)
	local k = group("PayKiosk")
	P("KioskBase", V(1.6, 1.0, 1.6), W(-1852, 0.5, ZL + 13.5), YEL, M.Concrete, { parent = k })
	P("KioskBody", V(1.4, 4.6, 1.2), W(-1852, 3.3, ZL + 13.5), C(30, 30, 34), M.Metal, { parent = k })
	P("KioskScreen", V(0.05, 1.2, 0.9), W(-1852.73, 4.3, ZL + 13.5), C(80, 170, 255), M.Neon, { parent = k, deco = true })
	-- cones at the entrance
	for i = 0, 2 do
		P("Cone", V(0.9, 1.4, 0.9), W(-1856, 0.7, ZL - 13.5 - i * 1.5), C(250, 110, 20), M.Plastic, { parent = model })
	end
	model.Parent = sudz

	K.quietFootprints(V(-1881, 0, -190), 70)
	-- stations
	local f = workspace:FindFirstChild("MTL_Stations") and workspace.MTL_Stations:FindFirstChild("CarWash")
	local report = {}
	for id, pos in { Lane = laneSpot, TimeClock = clockSpot } do
		local p = f and f:FindFirstChild(id)
		if p then
			if p:GetAttribute("MTL_OldPos") == nil then
				p:SetAttribute("MTL_OldPos", p.Position)
			end
			p.CFrame = CFrame.new(pos)
			p:SetAttribute("Prop", "")
			table.insert(report, id)
		end
	end
	return string.format("CarWashV2: %d parts, stations moved: %s", b.n, table.concat(report, ", "))
end
