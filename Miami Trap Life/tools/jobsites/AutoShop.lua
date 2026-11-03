-- Westside Auto Repair: interior pass for the Mechanic job.
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_AutoShop)()
-- Builds <AutoShop at (-1015,-478)>.AutoShopV2 and moves the Mechanic stations inside (they were on the street).
-- The two lift cars, lifts, red tool chests, tires and drums stay; the west bay becomes the customer office (glass
-- front + door), the third bay is opened up as the wash/detail bay. Replaced pieces go to
-- ServerStorage.MTL_ReplacedJobSites.AutoShop. Re-running rebuilds.
--
-- World: the street is +Z. Front wall inner face z -462.5, back wall inner face z -494.5, walls x -1050..-980,
-- floor top y 2.15, ceiling y 17. Bays (between piers): A -1047.5..-1036.5 (office), B -1029.5..-1018.5 (lift, Bay1),
-- C -1011.5..-1000.5 (wash, WashBay), D -993.5..-982.5 (lift, Bay2).
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M

local FY = 2.15
local XW, XE = -1050, -980
local ZF, ZB = -462.5, -494.5
local CEIL = 17.0

local function W(x, y, z)
	return CFrame.new(x, FY + y, z)
end
local V = Vector3.new

return function()
	local shop
	for _, m in workspace.ViceBay.Landmarks.Hood:GetChildren() do
		if m.Name == "AutoShop" and m:IsA("Model") and (m:GetPivot().Position - V(-1014.6, 12, -481)).Magnitude < 30 then
			shop = m
		end
	end
	assert(shop, "AutoShop model not found")
	local site = "AutoShop"
	local old = shop:FindFirstChild("AutoShopV2")
	if old then
		old:Destroy()
	end
	local washOld = shop:FindFirstChild("WashCar")
	if washOld then
		washOld:Destroy()
	end
	-- stash: the west counter + its wall plate, and the shutters on bays A and C
	local moved = 0
	for _, p in shop:GetChildren() do
		if p:IsA("BasePart") then
			local q = p.Position
			local westCounter = q.X < -1047 and q.X > -1050.2 and q.Z < ZF and q.Z > ZB and q.Y < 12 and (p.Material == M.Wood or p.Material == M.DiamondPlate)
			local shutter = p.Material == M.Metal and math.abs(p.Size.X - 11) < 0.1 and p.Size.Y > 10 and math.abs(q.Z + 462) < 0.3 and (math.abs(q.X + 1042) < 0.5 or math.abs(q.X + 1006) < 0.5)
			if westCounter or shutter then
				K.stash(site, p)
				moved += 1
			end
		end
	end

	local model = Instance.new("Model")
	model.Name = "AutoShopV2"
	model:SetAttribute("MTL_Style", "JobInteriorV2")
	local b = K.builder(model)
	local P, group = b.P, b.group
	local rng = Random.new(1015)
	local YEL, STEEL, DARK = C(240, 196, 30), C(170, 172, 176), C(40, 40, 44)

	---------------------------------------------------------------- floor marks, lights, walls
	do
		local g = group("Room")
		-- yellow bay lines + oil stains
		for _, bx in { -1024, -1006, -988 } do
			for _, s in { -1, 1 } do
				P("BayLine", V(0.35, 0.03, 26), W(bx + s * 5.8, 0.02, -478.5), YEL, M.SmoothPlastic, { parent = g, deco = true })
			end
			for i = 1, 3 do
				local r = rng:NextNumber(1.2, 2.6)
				P("Stain", V(0.02, r, r * rng:NextNumber(0.6, 1)), W(bx + rng:NextNumber(-3, 3), 0.015, -478 + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)), C(46, 44, 40), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder, Transparency = 0.35 })
			end
		end
		-- high-bay lights
		for _, x in { -1042, -1024, -1006, -988 } do
			for _, z in { -470, -486 } do
				P("LampHousing", V(2.6, 0.4, 2.6), CFrame.new(x, CEIL - 1.2, z), C(60, 60, 64), M.Metal, { parent = g, deco = true })
				P("LampLens", V(2.2, 0.06, 2.2), CFrame.new(x, CEIL - 1.43, z), C(255, 250, 235), M.Neon, { parent = g, deco = true })
				P("LampChain", V(0.06, 1.0, 0.06), CFrame.new(x, CEIL - 0.5, z), C(40, 40, 40), M.Metal, { parent = g, deco = true })
			end
		end
		for _, pos in { V(-1024, CEIL - 2, -478), V(-988, CEIL - 2, -478), V(-1006, CEIL - 2, -478), V(-1043, CEIL - 3, -472) } do
			local a = P("LightPoint", V(0.2, 0.2, 0.2), CFrame.new(pos), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
			local l = Instance.new("PointLight")
			l.Range = 30
			l.Brightness = 0.9
			l.Color = C(250, 246, 236)
			l.Shadows = false
			l.Parent = a
		end
		-- painted block lower wall (back wall) + safety stripe
		P("BackPaint", V(XE - XW, 5, 0.06), W((XW + XE) / 2, 2.5, ZB + 0.04), C(60, 90, 140), M.Concrete, { parent = g, deco = true })
		P("BackStripe", V(XE - XW, 0.4, 0.07), W((XW + XE) / 2, 5.2, ZB + 0.05), YEL, M.SmoothPlastic, { parent = g, deco = true })
		local signs = {
			{ V(-1015, 11.5, ZB + 0.06), Enum.NormalId.Back, "WESTSIDE AUTO · SINCE 1987", C(20, 50, 110), C(255, 255, 255), V(18, 2, 0.05) },
			{ V(-997, 9.0, ZB + 0.06), Enum.NormalId.Back, "SAFETY FIRST\nGLASSES ON IN THE SHOP", YEL, C(20, 20, 20), V(6, 2, 0.05) },
		}
		for _, d in signs do
			local p = P("Sign", d[6], CFrame.new(d[1].X, FY + d[1].Y, d[1].Z), d[4], M.SmoothPlastic, { parent = g, deco = true })
			K.sign(p, d[2], d[3], d[4], d[5])
		end
	end
	model.Parent = shop
	task.wait()

	---------------------------------------------------------------- lifts: base plates, controls, hydraulic look, tools around
	local function liftExtras(bx)
		local g = group("LiftKit", model)
		for _, s in { -1, 1 } do
			P("PostBase", V(2.0, 0.25, 2.0), W(bx + s * 5, 0.125, -479.5), C(30, 60, 130), M.Metal, { parent = g })
			P("PostDecal", V(0.06, 3.0, 0.7), W(bx + s * 5 + s * 0.53, 6.5, -479.5), YEL, M.SmoothPlastic, { parent = g, deco = true })
		end
		P("CrossBar", V(10, 0.6, 0.8), W(bx, 11.15, -479.5), C(40, 80, 160), M.Metal, { parent = g })
		P("Control", V(0.6, 1.2, 0.8), W(bx + 5.75, 4.4, -479.5), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
		P("ControlBtn", V(0.06, 0.3, 0.3), W(bx + 6.08, 4.6, -479.5), C(30, 200, 60), M.Neon, { parent = g, deco = true })
		-- oil drain on a stand + jack stands + creeper
		P("DrainPan", V(0.3, 2.0, 2.0), W(bx - 1.2, 3.4, -478) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 30), M.Metal, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
		P("DrainPost", V(0.2, 3.2, 0.2), W(bx - 1.2, 1.6, -478), C(200, 30, 30), M.Metal, { parent = g, deco = true })
		P("DrainBase", V(1.6, 0.2, 1.6), W(bx - 1.2, 0.1, -478), C(200, 30, 30), M.Metal, { parent = g, deco = true })
		P("Creeper", V(1.6, 0.25, 3.6), W(bx + 3.2, 0.35, -485.5) * CFrame.Angles(0, math.rad(15), 0), C(200, 30, 30), M.Plastic, { parent = g, deco = true })
		for _, dz in { -2.6, 2.6 } do
			P("JackStand", V(0.6, 2.0, 0.6), W(bx - 7.0, 1.0, -479.5 + dz), C(220, 120, 30), M.Metal, { parent = g, deco = true })
		end
	end
	liftExtras(-1024)
	liftExtras(-988)
	-- raise the lift cars a little and keep them from catching rays (the beacon ring sits on the floor)
	for _, car in shop:GetChildren() do
		if car:IsA("Model") and car.Name == "ParkedCar" then
			local p = car:GetPivot().Position
			if p.Z < ZF and p.Z > ZB then
				for _, d in car:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide, d.CanQuery = false, false -- up on the lift: nobody walks into it, rays pass to the floor
					end
				end
			end
		end
	end

	---------------------------------------------------------------- wash / detail bay (C)
	local washSpot
	do
		local g = group("WashBay", model)
		local bx = -1006
		-- rolled-up shutter drum where the closed shutter was
		P("ShutterRoll", V(11.2, 1.6, 1.6), W(bx, 10.9, -461.7) * CFrame.Angles(0, 0, 0), C(150, 152, 150), M.Metal, { parent = g })
		P("ShutterLip", V(11.0, 0.3, 0.4), W(bx, 10.0, -462.0), C(120, 122, 120), M.Metal, { parent = g, deco = true })
		-- a car to detail: clone of a shop car, new paint, parked nose to the street
		local src
		for _, car in shop:GetChildren() do
			if car:IsA("Model") and car.Name == "ParkedCar" then
				src = car
				break
			end
		end
		if src then
			local car = src:Clone()
			car.Name = "WashCar"
			local cf, size = car:GetBoundingBox()
			local piv = car:GetPivot()
			local target = CFrame.new(bx, FY + size.Y / 2, -479.5) * cf.Rotation
			car:PivotTo(target * cf:ToObjectSpace(piv))
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanQuery = false
					if d.Name == "Color" then
						d.Color = C(160, 30, 36)
					end
				end
			end
			car.Parent = shop
		end
		-- drain grate, buckets, pressure washer, hose, foam cannon, towels
		P("Grate", V(10, 0.03, 0.8), W(bx, 0.02, -479.5), C(50, 50, 52), M.DiamondPlate, { parent = g, deco = true })
		P("WetFloor", V(9.6, 0.02, 20), W(bx, 0.012, -479.5), C(90, 100, 110), M.Glass, { parent = g, deco = true, Transparency = 0.6, Reflectance = 0.15 })
		for i, col in { C(30, 90, 200), C(220, 40, 40) } do
			P("Bucket", V(1.2, 1.3, 1.2), W(bx - 4.6, 0.65, -471 - i * 1.6), col, M.Plastic, { parent = g, shape = Enum.PartType.Cylinder, CFrame = W(bx - 4.6, 0.65, -471 - i * 1.6) * CFrame.Angles(0, 0, math.rad(90)) })
			P("Suds", V(0.2, 1.0, 1.0), W(bx - 4.6, 1.35, -471 - i * 1.6) * CFrame.Angles(0, 0, math.rad(90)), C(250, 250, 250), M.SmoothPlastic, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
		end
		P("Washer", V(1.8, 2.6, 2.6), W(bx + 4.6, 1.3, -489), C(240, 196, 30), M.Plastic, { parent = g })
		P("WasherMotor", V(1.2, 1.0, 1.4), W(bx + 4.6, 3.1, -489), C(30, 30, 30), M.Metal, { parent = g, deco = true })
		P("HoseReel", V(0.6, 2.4, 2.4), CFrame.new(bx + 5.3, FY + 7, ZB + 0.5), C(30, 30, 30), M.Rubber, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
		P("TowelRack", V(0.15, 3.4, 3.0), W(bx - 5.5, 1.7, -490), C(150, 150, 154), M.Metal, { parent = g })
		for i = 0, 3 do
			P("Towel", V(0.25, 1.2, 0.6), W(bx - 5.4, 2.6, -491.1 + i * 0.75), Color3.fromHSV(0.55 + i * 0.1, 0.5, 0.85), M.Fabric, { parent = g, deco = true })
		end
		local ws = P("WashSign", V(8, 1.4, 0.05), W(bx, 9.0, ZB + 0.06), C(30, 110, 200), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(ws, Enum.NormalId.Back, "DETAIL BAY · HAND WASH $25", C(30, 110, 200), C(255, 255, 255))
		washSpot = V(bx, FY + 2.5, -470.0)
	end
	task.wait()

	---------------------------------------------------------------- tire rack + tire machines (between bays B and C)
	local tireSpot
	do
		local g = group("Tires", model)
		local rx, rz = -1022, ZB + 1.3
		for _, dx in { -4, 0, 4 } do
			P("RackUpright", V(0.25, 9, 2.2), W(rx + dx, 4.5, rz), C(200, 60, 30), M.Metal, { parent = g })
		end
		for _, y in { 0.3, 3.2, 6.1 } do
			P("RackBar", V(8.2, 0.2, 0.2), W(rx, y, rz - 0.8), C(200, 60, 30), M.Metal, { parent = g })
			P("RackBar", V(8.2, 0.2, 0.2), W(rx, y, rz + 0.8), C(200, 60, 30), M.Metal, { parent = g })
			for i = 0, 6 do
				P("Tire", V(0.95, 2.6, 2.6), W(rx - 3.4 + i * 1.12, y + 1.4, rz) * CFrame.Angles(0, 0, 0), C(26, 26, 28), M.Rubber, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
				P("Rim", V(0.97, 1.4, 1.4), W(rx - 3.4 + i * 1.12, y + 1.4, rz), C(150, 152, 156), M.Metal, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
			end
		end
		local ts = P("TireSign", V(6, 1.0, 0.05), W(rx, 9.6, ZB + 0.06), C(26, 26, 28), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(ts, Enum.NormalId.Back, "NEW & USED TIRES", C(26, 26, 28), YEL)
		tireSpot = V(rx, FY + 2.5, rz + 2.6)
		-- tire changer + balancer next to the rack
		P("ChangerBase", V(2.4, 2.4, 2.0), W(rx - 10.5, 1.2, ZB + 2.0), C(200, 30, 30), M.Metal, { parent = g })
		P("ChangerTable", V(0.3, 2.2, 2.2), W(rx - 10.5, 2.55, ZB + 2.0) * CFrame.Angles(0, 0, math.rad(90)), C(40, 40, 44), M.Metal, { parent = g, shape = Enum.PartType.Cylinder })
		P("ChangerArm", V(0.4, 3.6, 0.4), W(rx - 11.2, 4.2, ZB + 1.4), C(40, 40, 44), M.Metal, { parent = g, deco = true })
		P("BalancerBase", V(2.0, 3.0, 1.8), W(rx + 6.5, 1.5, ZB + 1.8), C(30, 80, 160), M.Metal, { parent = g })
		P("BalancerHood", V(2.2, 0.4, 1.6), W(rx + 6.5, 4.0, ZB + 1.8) * CFrame.Angles(math.rad(-30), 0, 0), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		P("BalancerScreen", V(1.2, 0.6, 0.05), W(rx + 6.5, 3.2, ZB + 2.72), C(120, 220, 120), M.Neon, { parent = g, deco = true })
	end

	---------------------------------------------------------------- workbenches, pegboards, compressor, oil shelf (back wall, bay D side)
	do
		local g = group("Benches", model)
		local function bench(x, z, L)
			P("BenchTop", V(L, 0.3, 2.4), W(x, 3.2, z), C(140, 100, 60), M.WoodPlanks, { parent = g })
			P("BenchShelf", V(L - 0.4, 0.15, 2.0), W(x, 0.8, z), C(80, 80, 84), M.Metal, { parent = g, deco = true })
			for _, dx in { -L / 2 + 0.2, L / 2 - 0.2 } do
				P("BenchLeg", V(0.3, 3.1, 2.2), W(x + dx, 1.55, z), C(80, 80, 84), M.Metal, { parent = g })
			end
			local peg = P("Pegboard", V(L, 4, 0.1), W(x, 6.5, ZB + 0.1), C(196, 170, 130), M.Wood, { parent = g, deco = true })
			K.grid(peg, Enum.NormalId.Back, math.floor(L * 2), 8, C(196, 170, 130), C(150, 126, 96), false)
			for i = 0, math.floor(L) - 1 do
				local tx = x - L / 2 + 0.6 + i
				local kind = i % 4
				local col = ({ C(200, 30, 30), C(30, 30, 30), C(200, 200, 204), C(240, 196, 30) })[kind + 1]
				P("Tool", V(0.18, if kind == 2 then 1.6 else 1.0, 0.1), W(tx, 6.6 + (i % 2) * 0.9, ZB + 0.2) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 15)), col, M.Metal, { parent = g, deco = true })
			end
			P("Vise", V(0.8, 0.7, 0.9), W(x + L / 2 - 0.8, 3.7, z - 0.6), C(40, 80, 160), M.Metal, { parent = g, deco = true })
			P("Rag", V(0.9, 0.08, 0.7), W(x - 0.6, 3.39, z - 0.3) * CFrame.Angles(0, math.rad(20), 0), C(200, 40, 40), M.Fabric, { parent = g, deco = true })
		end
		bench(-1043, ZB + 1.3, 6)
	end
	task.wait()

	---------------------------------------------------------------- customer office (bay A): glass front, counter, waiting area, time clock
	local clockSpot
	do
		local g = group("Office", model)
		local x0, x1 = -1047.45, -1036.55
		-- glass storefront with a door gap in the bay opening
		local gy0, gy1 = FY + 0.2, FY + 10.6
		local function glass(a, c)
			P("Glass", V(c - a, gy1 - gy0, 0.25), CFrame.new((a + c) / 2, (gy0 + gy1) / 2, -462.0), C(150, 170, 180), M.Glass, { parent = g, Transparency = 0.55 })
		end
		glass(x0, -1044.0)
		glass(-1040.0, x1)
		P("Transom", V(4.0, gy1 - (FY + 8.0), 0.25), CFrame.new(-1042.0, (FY + 8.0 + gy1) / 2, -462.0), C(150, 170, 180), M.Glass, { parent = g, Transparency = 0.55 })
		for _, x in { -1044.1, -1039.9 } do
			P("Mullion", V(0.3, gy1 - gy0, 0.4), CFrame.new(x, (gy0 + gy1) / 2, -462.0), DARK, M.Metal, { parent = g })
		end
		P("DoorHead", V(4.4, 0.3, 0.4), CFrame.new(-1042.0, FY + 8.0, -462.0), DARK, M.Metal, { parent = g })
		P("Sill", V(x1 - x0, 0.2, 0.5), CFrame.new((x0 + x1) / 2, FY + 0.1, -462.0), DARK, M.Metal, { parent = g })
		local office = P("OfficeDecal", V(3.0, 1.0, 0.02), CFrame.new(-1045.6, FY + 5.5, -461.86), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(office, Enum.NormalId.Back, "OFFICE · PAY HERE", nil, C(255, 255, 255))
		local hrs = P("HoursDecal", V(3.0, 1.4, 0.02), CFrame.new(-1038.3, FY + 5.0, -461.86), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(hrs, Enum.NormalId.Back, "OIL CHANGE $29.99\nBRAKES · TIRES · AC", nil, C(255, 230, 80))
		-- partition between office and bay B (door at the back)
		P("Partition", V(0.4, 10, 20), W(-1036.0, 5, -472.5), C(220, 222, 216), M.Plaster, { parent = g })
		P("PartitionCap", V(0.6, 0.2, 20), W(-1036.0, 10.1, -472.5), C(150, 150, 154), M.Metal, { parent = g, deco = true })
		-- floor + counter
		P("OfficeFloor", V(-1036.2 - XW, 0.05, 20), W((XW - 1036.2) / 2, -0.005, -472.5), C(180, 176, 166), M.CeramicTiles, { parent = g })
		P("Counter", V(1.8, 3.3, 7.0), W(-1046.5, 1.65, -474.0), C(30, 60, 120), M.SmoothPlastic, { parent = g })
		P("CounterTop", V(2.0, 0.15, 7.2), W(-1046.5, 3.37, -474.0), C(40, 40, 44), M.Slate, { parent = g })
		P("Monitor", V(0.15, 1.1, 1.6), W(-1047.0, 4.2, -475.5) * CFrame.Angles(0, math.rad(-15), 0), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		P("MonitorGlow", V(0.02, 0.9, 1.4), W(-1046.9, 4.2, -475.5) * CFrame.Angles(0, math.rad(-15), 0), C(90, 150, 230), M.Neon, { parent = g, deco = true })
		P("Register", V(1.0, 0.5, 1.1), W(-1046.6, 3.7, -472.6), DARK, M.SmoothPlastic, { parent = g, deco = true })
		P("KeyBoard", V(0.6, 0.06, 1.2), W(-1046.2, 3.48, -475.3), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
		P("Bell", V(0.4, 0.3, 0.4), W(-1045.8, 3.6, -471.0), C(220, 180, 60), M.Metal, { parent = g, deco = true })
		-- key board on the wall behind the counter (car keys)
		local kb = P("KeyCabinet", V(0.2, 2.2, 3.0), W(XW + 0.1, 6.0, -474.0), C(140, 100, 60), M.Wood, { parent = g })
		for i = 0, 11 do
			P("Key", V(0.06, 0.35, 0.12), W(XW + 0.25, 5.4 + math.floor(i / 6) * 1.0, -475.2 + (i % 6) * 0.48), C(220, 190, 60), M.Metal, { parent = g, deco = true })
		end
		_ = kb
		-- time clock on the west wall by the shop door
		local tc = group("TimeClock", g)
		P("ClockBody", V(0.6, 1.6, 1.2), W(XW + 0.3, 4.6, -480.0), C(214, 210, 196), M.SmoothPlastic, { parent = tc })
		P("ClockDigits", V(0.04, 0.22, 0.6), W(XW + 0.62, 5.0, -480.0), C(255, 80, 60), M.Neon, { parent = tc, deco = true })
		P("CardSlot", V(0.05, 0.1, 0.5), W(XW + 0.62, 4.3, -480.0), C(20, 20, 20), M.SmoothPlastic, { parent = tc, deco = true })
		P("CardRack", V(0.3, 2.2, 1.2), W(XW + 0.2, 4.6, -481.5), C(150, 150, 154), M.Metal, { parent = tc })
		for i = 0, 5 do
			P("TimeCard", V(0.05, 0.9, 0.18), W(XW + 0.38, 4.9, -481.95 + i * 0.18), C(240, 236, 210), M.SmoothPlastic, { parent = tc, deco = true })
		end
		clockSpot = V(XW + 2.0, FY + 2.5, -480.0)
		-- waiting chairs, coffee, vending, parts shelf
		for i = 0, 3 do
			local cz = -464.5 - i * 1.6
			P("ChairSeat", V(1.4, 0.3, 1.4), W(-1037.6, 1.6, cz), C(30, 30, 34), M.Plastic, { parent = g })
			P("ChairBack", V(0.2, 1.6, 1.4), W(-1037.0, 2.5, cz), C(30, 30, 34), M.Plastic, { parent = g })
		end
		P("ChairRail", V(0.3, 1.4, 6.6), W(-1037.6, 0.7, -466.9), C(150, 150, 154), M.Metal, { parent = g, deco = true })
		P("CoffeeTable", V(1.4, 2.8, 1.4), W(-1037.6, 1.4, -471.3), C(80, 60, 44), M.Wood, { parent = g })
		P("CoffeeMaker", V(0.8, 1.1, 0.8), W(-1037.6, 3.35, -471.3), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		P("Vending", V(3.0, 6.5, 2.4), W(-1048.6, 3.25, -464.5), C(200, 30, 30), M.SmoothPlastic, { parent = g })
		P("VendingGlass", V(0.05, 4.2, 1.8), W(-1047.08, 3.9, -464.5), C(160, 200, 220), M.Glass, { parent = g, deco = true, Transparency = 0.4 })
		for r = 0, 3 do
			for c = 0, 2 do
				local pal = K.Drinks[rng:NextInteger(1, #K.Drinks)]
				P("Can", V(0.4, 0.7, 0.4), W(-1047.4, 2.4 + r * 1.0, -465.1 + c * 0.6), pal[1], M.SmoothPlastic, { parent = g, deco = true })
			end
		end
		P("PartsShelf", V(0.2, 7.0, 5.0), W(-1036.4, 3.5, -480.8), C(200, 200, 204), M.Metal, { parent = g })
		for i, y in { 0.6, 2.2, 3.8, 5.4 } do
			P("PartsBoard", V(1.4, 0.1, 5.0), W(-1037.6, y, -480.8), C(200, 200, 204), M.Metal, { parent = g, deco = true })
			local base = CFrame.lookAt(V(-1037.6, FY + y + 0.05, -480.8), V(-1045, FY + y + 0.05, -480.8))
			K.fillShelf(b, base, 4.8, 1.2, 1.2, rng, { { C(230, 180, 30), C(30, 30, 30) }, { C(30, 30, 30), C(240, 196, 30) }, { C(30, 90, 170), C(255, 255, 255) }, { C(200, 30, 30), C(255, 255, 255) } }, g)
			_ = i
		end
	end
	task.wait()

	---------------------------------------------------------------- stations
	K.dress(model, { OfficeFloor = "MTL_VinylPlank", Partition = "MTL_Drywall", Counter = "MTL_CounterWood", CoffeeTable = "MTL_CounterWood" })
	K.quietFootprints(V(-1015, 0, -480), 45)
	local stations = workspace:FindFirstChild("MTL_Stations")
	local spots = {
		TimeClock = { clockSpot },
		TireRack = { tireSpot },
		Bay1 = { V(-1024, FY + 2.5, -479.5) },
		Bay2 = { V(-988, FY + 2.5, -479.5) },
		WashBay = { washSpot },
	}
	local report = {}
	local f = stations and stations:FindFirstChild("Mechanic")
	for id, s in spots do
		local p = f and f:FindFirstChild(id)
		if p and p:IsA("BasePart") then
			if p:GetAttribute("MTL_OldPos") == nil then
				p:SetAttribute("MTL_OldPos", p.Position)
			end
			p.CFrame = CFrame.new(s[1])
			p:SetAttribute("Prop", "")
			table.insert(report, id)
		end
	end
	return string.format("AutoShopV2: %d parts, %d stashed, stations moved: %s", b.n, moved, table.concat(report, ", "))
end
