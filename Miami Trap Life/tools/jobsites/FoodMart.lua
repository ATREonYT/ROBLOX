-- Liberty Food Mart: full interior rebuild (Supermarket + Cashier jobs, the FirstMission robbery, cutscene FirstDay).
-- Run from the Command Bar / MCP:  require(game.ServerStorage.MTL_Tools.JobSite_FoodMart)()
-- Builds Workspace.ViceBay.Landmarks.Hood.FoodMart.InteriorV2 and moves the job stations onto the real objects.
-- Old interior parts go to ServerStorage.MTL_ReplacedJobSites.FoodMart (attribute MTL_OriginalParent). Re-running
-- rebuilds InteriorV2 from scratch.
--
-- Layout (world, north = -Z, the glass front is at z -323.7, floor top y 2.15):
--   * FirstDay cutscene needs: open floor z -323..-313, the walk aisle centred on x -1431.6 (z -313..-294),
--     Patel at (-1444.6,-317.4), cameras around (-1451, 6..12, -321..-313). Kept clear.
--   * Roomy layout: 3 gondolas at x -1424.1/-1439.1/-1454.1 (15 stud pitch, 13.2 wide aisles, z -311.6..-296.5).
--   * Restock endcaps (5 wide, run along X so JobFX "ShelfFill" products land on the boards) on both ends of the
--     -1454.1 and -1424.1 gondolas. Boards are CanQuery=false so JobFX.floor still finds the floor.
--   * Checkout on the east side (counter along Z at x -1425), clerk behind it. New centre entrance at x -1442,
--     right where Locations.FoodMart.Door / the mission "Door" point are. The old east door is filled in.
--   * Stockroom in the north-west corner (x -1489..-1463, z -306..-286.5): time clock, stock pallet, back door to
--     NW 58 Alley with the dumpster.
local SS = game:GetService("ServerStorage")
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M

local FY = 2.15 -- floor top
local XW, XE = -1522.4, -1412.15 -- inner wall faces (XW = the west wing wall, built by step 0)
local XS = -1489.05 -- the old west wall line: the stockroom keeps it
local WING = 33.4 -- the west wing widens the store by this much
local ZF, ZB = -323.575, -286.55 -- inside of the glass, inside of the back wall
local CEIL = 15.85
local CX = (XW + XE) / 2

local function W(x, y, z)
	return CFrame.new(x, FY + y, z)
end
local V = Vector3.new

return function()
	local store = workspace.ViceBay.Landmarks.Hood.FoodMart
	local site = "FoodMart"

	---------------------------------------------------------------- 0. west wing shell (once): the store grows 33.4 studs west
	if not store:GetAttribute("MTL_WestWing") then
		local list = store:GetChildren()
		for _, p in list do
			if p:IsA("BasePart") then
				local q = p.Position
				if (q.X < -1489.6 and p.Size.X <= 1.5) or (math.abs(q.X + 1489.1) < 0.06 and p.Size.X <= 0.2) then
					-- the west wall, its parapet, meter and conduit move out to the new west end
					p:SetAttribute("MTL_MovedFrom", q)
					p:SetAttribute("MTL_WingMoved", true)
					p.Position = q - V(WING, 0, 0)
				elseif p.Size.X >= 77 and p.Name ~= "Sign" then
					-- long shell parts (roof, parapets, floor, ceiling, sill, awning, the parking lot) get a wing piece
					local west = q.X - p.Size.X / 2
					local c = p:Clone()
					for _, ch in c:GetChildren() do
						if ch:IsA("SurfaceGui") or ch:IsA("Light") then
							ch:Destroy()
						end
					end
					c.Name = "Wing_" .. p.Name
					c.Size = V(WING, p.Size.Y, p.Size.Z)
					c.Position = V(west - WING / 2, q.Y, q.Z)
					c:SetAttribute("MTL_WingMoved", true)
					c.Parent = store
				end
			end
		end
		-- back wall + inner panel for the wing (copies of the trimmed west pieces)
		for _, n in { "BackWallW", "BackPanelW" } do
			local src = store:FindFirstChild(n)
			if src then
				local c = src:Clone()
				c.Name = "Wing_" .. n
				local east = src.Position.X - src.Size.X / 2
				local west = if n == "BackPanelW" then -1522.45 else east - WING
				c.Size = V(east - west, src.Size.Y, src.Size.Z)
				c.Position = V((east + west) / 2, src.Position.Y, src.Position.Z)
				c:SetAttribute("MTL_WingMoved", true)
				c.Parent = store
			end
		end
		-- front: a stucco pier at the new corner, glass, and the security bars
		local ref
		for _, p in store:GetChildren() do
			if p:IsA("BasePart") and p.MaterialVariant == "StuccoPinkWeathered" and math.abs(p.Position.Z + 323.7) < 0.1 and p.Size.Y == 9 and p.Position.X < -1475 then
				ref = p
			end
		end
		if ref then
			local pier = ref:Clone()
			pier.Name = "Wing_Pier"
			pier.Size = V(3.0, 9, 1)
			pier.Position = V(-1522.55, ref.Position.Y, -323.7)
			pier:SetAttribute("MTL_WingMoved", true)
			pier.Parent = store
		end
		local gl = Instance.new("Part")
		gl.Name = "Wing_Glass"
		gl.Anchored = true
		gl.Size = V(30.4, 8.4, 0.25)
		gl.Position = V(-1505.85, 6.8, -323.7)
		gl.Material = M.Glass
		gl.Color = C(150, 170, 180)
		gl.Transparency = 0.6
		gl:SetAttribute("MTL_WingMoved", true)
		gl.Parent = store
		local x = -1520.5
		while x < -1491 do
			local bar = Instance.new("Part")
			bar.Name = "Wing_Bar"
			bar.Anchored = true
			bar.CanCollide = false
			bar.Size = V(0.1, 8.2, 0.1)
			bar.Position = V(x, 6.8, -324.4)
			bar.Material = M.Metal
			bar.Color = C(34, 34, 36)
			bar:SetAttribute("MTL_WingMoved", true)
			bar.Parent = store
			x += 1.1
		end
		store:SetAttribute("MTL_WestWing", true)
	end

	---------------------------------------------------------------- 1. stash the old interior
	local old = store:FindFirstChild("InteriorV2")
	if old then
		old:Destroy()
	end
	local moved = 0
	for _, p in store:GetChildren() do
		if p:IsA("BasePart") then
			local q = p.Position
			local inside = not p:GetAttribute("MTL_WingMoved") and q.X > XW + 0.05 and q.X < XE - 0.1 and q.Z > ZF + 0.1 and q.Z < ZB - 0.1 and q.Y > FY + 0.05 and q.Y < CEIL
			if inside then
				K.stash(site, p)
				moved += 1
			end
		end
	end
	-- the east door becomes wall (the counter now stands behind it)
	local door = store:FindFirstChild("Door")
	if door then
		K.stash(site, door)
	end

	local model = Instance.new("Model")
	model.Name = "InteriorV2"
	model:SetAttribute("MTL_Style", "JobInteriorV2")
	local b = K.builder(model)
	local P, group = b.P, b.group
	local rng = Random.new(305)

	---------------------------------------------------------------- 2. shell edits: centre door, back door
	do
		local g = group("Shell")
		-- storefront glass: split around a 4.4 wide door at x -1442
		for _, p in store:GetChildren() do
			if p:IsA("BasePart") and p.Material == M.Glass and p.Size.X > 40 and math.abs(p.Position.Z + 323.7) < 0.2 then
				K.stash(site, p)
			end
			-- security bars in front of the new door
			if p:IsA("BasePart") and p.Size.Y > 8 and p.Size.X < 0.2 and math.abs(p.Position.Z + 324.4) < 0.1 and p.Position.X > -1445 and p.Position.X < -1439 then
				K.stash(site, p)
			end
		end
		local gy0, gy1 = 2.6, 11.0
		local function glass(x0, x1, y0, y1)
			P("Glass", V(x1 - x0, y1 - y0, 0.25), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -323.7), C(150, 170, 180), M.Glass, { Transparency = 0.6, parent = g })
		end
		glass(-1473.7, -1445.0, gy0, gy1)
		glass(-1439.0, -1427.5, gy0, gy1)
		glass(-1445.0, -1439.0, FY + 8.2, gy1) -- transom
		for _, x in { -1444.8, -1439.2 } do
			P("DoorFrame", V(0.4, gy1 - FY, 0.45), CFrame.new(x, (FY + gy1) / 2, -323.7), C(40, 40, 42), M.Metal, { parent = g })
		end
		P("DoorHeader", V(6.0, 0.4, 0.45), CFrame.new(-1442, FY + 8.2, -323.7), C(40, 40, 42), M.Metal, { parent = g })
		-- automatic sliding doors: two leaves meet in the middle and slide behind the fixed glass when anyone is near
		-- (server Script "AutoDoor" inside the model; matches the FirstDay cutscene's door props)
		local doors = group("AutoDoors", g)
		doors:SetAttribute("Centre", V(-1442, FY + 2.5, -323.4))
		for _, s in { -1, 1 } do
			local x = -1442 + s * 1.3
			local leaf = P(if s < 0 then "LeafL" else "LeafR", V(2.6, 7.9, 0.12), CFrame.new(x, FY + 4.1, -323.35), C(150, 170, 180), M.Glass, { Transparency = 0.55, parent = doors })
			local function trim(name, size, off)
				local t = P(name, size, leaf.CFrame * off, C(150, 152, 156), M.Metal, { parent = leaf, deco = true })
				t.Anchored = false
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = leaf, t
				w.Parent = t
			end
			trim("Rail", V(2.6, 0.25, 0.16), CFrame.new(0, -3.83, 0))
			trim("Rail", V(2.6, 0.2, 0.16), CFrame.new(0, 3.85, 0))
			trim("Stile", V(0.12, 7.9, 0.16), CFrame.new(-s * 1.24, 0, 0))
			trim("Handle", V(0.1, 1.6, 0.1), CFrame.new(-s * 1.0, -0.3, 0.15))
		end
		local auto = Instance.new("Script")
		auto.Name = "AutoDoor"
		auto.Source = [==[
-- Liberty Food Mart automatic doors (built by tools/jobsites/FoodMart.lua). Opens for any character within 10 studs.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local model = script.Parent
local L, R = model:WaitForChild("LeafL"), model:WaitForChild("LeafR")
local centre = model:GetAttribute("Centre")
local closedL, closedR = L.CFrame, R.CFrame
local openL, openR = closedL * CFrame.new(-2.65, 0, 0), closedR * CFrame.new(2.65, 0, 0)
local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local params = OverlapParams.new()
local isOpen = false
local function set(open)
	if open == isOpen then
		return
	end
	isOpen = open
	TweenService:Create(L, info, { CFrame = if open then openL else closedL }):Play()
	TweenService:Create(R, info, { CFrame = if open then openR else closedR }):Play()
end
while true do
	local near = false
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - centre).Magnitude < 10 then
			near = true
			break
		end
	end
	if not near then -- NPCs / cutscene rigs on the server
		for _, part in workspace:GetPartBoundsInRadius(centre, 9, params) do
			if part.Name == "HumanoidRootPart" then
				near = true
				break
			end
		end
	end
	set(near)
	task.wait(0.2)
end
]==]
		auto.Parent = doors
		local sensor = P("DoorSensor", V(1.2, 0.35, 0.3), CFrame.new(-1442, FY + 8.6, -323.9), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		P("SensorLed", V(0.15, 0.1, 0.05), CFrame.new(-1441.6, FY + 8.6, -324.06), C(255, 60, 40), M.Neon, { parent = g, deco = true })
		local hours = P("HoursDecal", V(1.6, 1.0, 0.02), CFrame.new(-1439.9, FY + 5.2, -323.86), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(hours, Enum.NormalId.Front, "OPEN 6AM–2AM\n7 DAYS", nil, C(255, 255, 255), { font = Enum.Font.GothamBold })
		local ebt = P("EbtDecal", V(1.4, 0.8, 0.02), CFrame.new(-1446.2, FY + 4.6, -323.86), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(ebt, Enum.NormalId.Front, "WE ACCEPT\nEBT · SNAP", C(255, 255, 255), C(20, 90, 170))
		-- mats
		P("MatIn", V(5, 0.06, 3), W(-1442, 0.04, -321.7), C(140, 30, 30), M.Fabric, { parent = g, deco = true })
		_ = sensor

		-- the old east door hole (x -1422.4..-1418.4) becomes a barred window like the rest of the shopfront
		-- (a stucco infill here read as "a random wall in front of the entrance")
		P("EastWindow", V(4.0, 8.2, 0.25), CFrame.new(-1420.4, 6.7, -323.7), C(150, 170, 180), M.Glass, { parent = g, Transparency = 0.6 })
		P("EastSill", V(4.4, 0.4, 0.8), CFrame.new(-1420.4, 2.4, -323.9), C(130, 116, 96), M.Concrete, { parent = g })
		for k = 0, 3 do
			P("EastBar", V(0.1, 8.2, 0.1), CFrame.new(-1421.9 + k * 1.0, 6.8, -324.4), C(34, 34, 36), M.Metal, { parent = g, deco = true })
		end

		-- back wall: open a 4 wide door at x -1480..-1476 (main part trimmed, the "305" piece keeps its spot)
		for _, p in (if store:FindFirstChild("BackWallW") then {} else store:GetChildren()) do
			if p:IsA("BasePart") and math.abs(p.Size.X - 80) < 0.01 and p.Size.Y == 16 and math.abs(p.Position.Z + 286) < 0.1 then
				K.stash(site, p:Clone()) -- keep an untouched copy
				local x0, x1 = p.Position.X - 40, p.Position.X + 40 -- -1490.6 .. -1410.6
				local west = p:Clone()
				for _, ch in west:GetChildren() do
					if ch:IsA("SurfaceGui") then
						ch:Destroy()
					end
				end
				west.Size = V(-1480 - x0, 16, 1)
				west.Position = V((x0 - 1480) / 2, p.Position.Y, p.Position.Z)
				west.Name = "BackWallW"
				west.Parent = store
				local lint = west:Clone()
				lint.Size = V(4, 16 - (10.35 - 2), 1)
				lint.Position = V(-1478, 10.35 + lint.Size.Y / 2, p.Position.Z)
				lint.Name = "BackWallLintel"
				lint.Parent = store
				-- trim the original from the west (gui origin is on the west edge of the Back face: rescale labels)
				local newW = x1 - (-1476)
				for _, gui in p:GetChildren() do
					if gui:IsA("SurfaceGui") then
						for _, lab in gui:GetDescendants() do
							if lab:IsA("GuiObject") and lab.Parent == gui then
								local sx, wx = lab.Position.X.Scale, lab.Size.X.Scale
								lab.Position = UDim2.new((sx * 80 - (-1476 - x0)) / newW, 0, lab.Position.Y.Scale, 0)
								lab.Size = UDim2.new(wx * 80 / newW, 0, lab.Size.Y.Scale, 0)
							end
						end
					end
				end
				p.Size = V(newW, 16, 1)
				p.Position = V((x1 - 1476) / 2, p.Position.Y, p.Position.Z)
			elseif p:IsA("BasePart") and math.abs(p.Size.X - 77) < 0.01 and math.abs(p.Size.Y - 14) < 0.01 and math.abs(p.Position.Z + 286.6) < 0.1 then
				K.stash(site, p:Clone())
				local x0, x1 = p.Position.X - 38.5, p.Position.X + 38.5
				local west = p:Clone()
				west.Size = V(-1480 - x0, 14, 0.1)
				west.Position = V((x0 - 1480) / 2, p.Position.Y, p.Position.Z)
				west.Name = "BackPanelW"
				west.Parent = store
				local lint = west:Clone()
				lint.Size = V(4, 16 - 10.35, 0.1)
				lint.Position = V(-1478, 10.35 + lint.Size.Y / 2, p.Position.Z)
				lint.Name = "BackPanelLintel"
				lint.Parent = store
				p.Size = V(x1 + 1476, 14, 0.1)
				p.Position = V((x1 - 1476) / 2, p.Position.Y, p.Position.Z)
			end
		end
		-- back door: steel frame, the door swung open flat against the outside wall
		P("BackDoorFrame", V(0.35, 8.4, 1.3), CFrame.new(-1480.1, FY + 4.2, -286), C(70, 72, 74), M.Metal, { parent = g })
		P("BackDoorFrame", V(0.35, 8.4, 1.3), CFrame.new(-1475.9, FY + 4.2, -286), C(70, 72, 74), M.Metal, { parent = g })
		P("BackDoorFrame", V(4.5, 0.35, 1.3), CFrame.new(-1478, FY + 8.2, -286), C(70, 72, 74), M.Metal, { parent = g })
		local bd = P("BackDoor", V(0.18, 7.9, 3.9), CFrame.new(-1475.6, FY + 4.0, -283.4), C(96, 104, 98), M.DiamondPlate, { parent = g })
		bd.CanCollide = false
		P("BackDoorBar", V(0.12, 0.25, 3.2), CFrame.new(-1475.45, FY + 3.6, -283.4), C(180, 180, 184), M.Metal, { parent = g, deco = true })
		local stencil = P("Stencil", V(0.02, 0.9, 3.0), CFrame.new(-1475.5, FY + 6, -283.4), C(0, 0, 0), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(stencil, Enum.NormalId.Right, "DELIVERIES\nRING BELL", nil, C(230, 230, 220), { font = Enum.Font.Arcade })
		local pack = P("WallPack", V(1.2, 0.8, 0.8), CFrame.new(-1478, FY + 9.3, -285.1), C(50, 50, 52), M.Metal, { parent = g })
		P("WallPackLens", V(1.0, 0.1, 0.6), CFrame.new(-1478, FY + 8.88, -285.05), C(255, 220, 160), M.Neon, { parent = g, deco = true })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Brightness = 2
		spot.Range = 20
		spot.Angle = 110
		spot.Color = C(255, 214, 160)
		spot.Parent = pack
		P("Threshold", V(4.2, 0.12, 1.4), CFrame.new(-1478, FY + 0.06, -286), C(150, 150, 150), M.DiamondPlate, { parent = g, deco = true })
	end

	---------------------------------------------------------------- 3. floors, walls, ceiling
	do
		local g = group("Room")
		P("FloorTiles", V(XE - (-1463.25), 0.05, ZB - ZF), CFrame.new((XE - 1463.25) / 2, FY - 0.005, (ZF + ZB) / 2), C(184, 180, 170), M.CeramicTiles, { parent = g })
		P("FloorTilesW", V(-1463.25 - XW, 0.05, -306.25 - ZF), CFrame.new((XW - 1463.25) / 2, FY - 0.005, (ZF - 306.25) / 2), C(184, 180, 170), M.CeramicTiles, { parent = g })
		P("FloorTilesX", V(XS - XW, 0.05, ZB + 306.25), CFrame.new((XW + XS) / 2, FY - 0.005, (ZB - 306.25) / 2), C(184, 180, 170), M.CeramicTiles, { parent = g })
		P("FloorStock", V(-1463.25 - XS, 0.05, ZB + 306.25), CFrame.new((XS - 1463.25) / 2, FY - 0.005, (ZB - 306.25) / 2), C(150, 148, 142), M.Concrete, { parent = g })
		-- green wainscot band and white kick along the sales-floor walls
		local band = C(30, 96, 58)
		P("BandE", V(0.06, 0.5, ZB - ZF - 0.4), CFrame.new(XE - 0.04, FY + 3.6, (ZF + ZB) / 2), band, M.SmoothPlastic, { parent = g, deco = true })
		P("BandW", V(0.06, 0.5, ZB - ZF), CFrame.new(XW + 0.04, FY + 3.6, (ZF + ZB) / 2), band, M.SmoothPlastic, { parent = g, deco = true })
		P("KickE", V(0.06, 0.4, ZB - ZF - 0.4), CFrame.new(XE - 0.04, FY + 0.2, (ZF + ZB) / 2), C(60, 60, 62), M.SmoothPlastic, { parent = g, deco = true })
		P("FrontPanelE", V(XE + 1427.5, CEIL - FY, 0.08), CFrame.new((XE - 1427.5) / 2, FY + (CEIL - FY) / 2, -323.16), C(226, 232, 230), M.SmoothPlastic, { parent = g })
		P("FrontPanelW", V(-1473.75 + 1490.65, CEIL - FY, 0.08), CFrame.new((-1490.65 - 1473.75) / 2, FY + (CEIL - FY) / 2, -323.16), C(226, 232, 230), M.SmoothPlastic, { parent = g })
		P("FrontPanelWing", V(1.4, CEIL - FY, 0.08), CFrame.new(XW + 0.7, FY + (CEIL - FY) / 2, -323.16), C(226, 232, 230), M.SmoothPlastic, { parent = g })
		P("FrontPanelWingTop", V(30.4, CEIL - 11.0, 0.08), CFrame.new(-1505.85, 11.0 + (CEIL - 11.0) / 2, -323.16), C(226, 232, 230), M.SmoothPlastic, { parent = g })
		P("Jamb", V(0.12, 9.0, 1.2), CFrame.new(-1490.6, FY + 4.5, -323.7), C(40, 40, 42), M.Metal, { parent = g })
		P("Jamb", V(0.12, 9.0, 1.2), CFrame.new(-1521.0, FY + 4.5, -323.7), C(40, 40, 42), M.Metal, { parent = g })
		for _, x in { -1427.55, -1473.65 } do
			P("Jamb", V(0.12, 9.0, 1.2), CFrame.new(x, FY + 4.5, -323.7), C(40, 40, 42), M.Metal, { parent = g })
		end
		P("FrontPanelTop", V(-1427.5 + 1473.75, CEIL - 11.0, 0.08), CFrame.new(-1450.625, 11.0 + (CEIL - 11.0) / 2, -323.16), C(226, 232, 230), M.SmoothPlastic, { parent = g })
		-- stockroom partitions (door at z -296.2..-291.8)
		local wall = C(226, 228, 222)
		local H = CEIL - FY
		P("PartitionA1", V(0.5, H, 9.8), CFrame.new(-1463, FY + H / 2, -301.1), wall, M.Plaster, { parent = g })
		P("PartitionA2", V(0.5, H, 5.25), CFrame.new(-1463, FY + H / 2, -289.175), wall, M.Plaster, { parent = g })
		P("PartitionA3", V(0.5, H - 8, 4.4), CFrame.new(-1463, FY + 8 + (H - 8) / 2, -294), wall, M.Plaster, { parent = g })
		P("PartitionB", V(-1462.75 - XS, H, 0.5), CFrame.new((XS - 1462.75) / 2, FY + H / 2, -306), wall, M.Plaster, { parent = g })
		P("PartitionC", V(0.5, H, ZB + 306.25), CFrame.new(XS - 0.25, FY + H / 2, (ZB - 306.25) / 2), wall, M.Plaster, { parent = g })
		P("StockBand", V(0.06, 0.5, 19.5), CFrame.new(-1462.72, FY + 3.6, -296.3), band, M.SmoothPlastic, { parent = g, deco = true })
		-- door frame + swing door (ajar into the stockroom)
		for _, z in { -296.2, -291.8 } do
			P("DoorJamb", V(0.7, 8, 0.2), W(-1463, 4, z), C(80, 80, 84), M.Metal, { parent = g })
		end
		P("DoorHead", V(0.7, 0.2, 4.6), W(-1463, 8, -294), C(80, 80, 84), M.Metal, { parent = g })
		local swing = P("SwingDoor", V(0.15, 7.8, 4.2), CFrame.new(-1463, FY + 3.95, -291.9) * CFrame.Angles(0, math.rad(65), 0) * CFrame.new(0, 0, -2.1), C(176, 170, 156), M.SmoothPlastic, { parent = g, deco = true })
		local emp = P("EmpSign", V(0.04, 0.8, 2.6), swing.CFrame * CFrame.new(0.1, 1.4, 0), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(emp, Enum.NormalId.Right, "EMPLOYEES ONLY", C(200, 30, 30), C(255, 255, 255))
		local emp2 = P("EmpSign2", V(0.04, 0.7, 3.2), W(-1462.73, 8.7, -294), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(emp2, Enum.NormalId.Right, "STOCKROOM · EMPLOYEES ONLY", C(30, 96, 58), C(255, 255, 255))
		-- ceiling: light panels + a few real lights
		local lightsX = { -1517, -1506, -1495, -1482, -1470, -1458.45, -1449.1, -1439.1, -1429.1, -1418.5 }
		local lightsZ = { -319, -309, -299, -290.5 }
		for _, x in lightsX do
			for _, z in lightsZ do
				if not (x < -1463 and x > XS and z > -306) then
					P("TroughFrame", V(2.4, 0.12, 4.4), CFrame.new(x, CEIL - 0.07, z), C(200, 200, 204), M.Metal, { parent = g, deco = true })
					P("Trough", V(2.0, 0.08, 4.0), CFrame.new(x, CEIL - 0.15, z), C(246, 248, 255), M.Neon, { parent = g, deco = true })
				end
			end
		end
		for _, pos in { V(-1446.75, CEIL - 0.6, -316), V(-1431, CEIL - 0.6, -316), V(-1439, CEIL - 0.6, -300), V(-1454, CEIL - 0.6, -300), V(-1420, CEIL - 0.6, -300), V(-1476, CEIL - 0.6, -315), V(-1440, CEIL - 0.6, -290) } do
			local a = P("LightPoint", V(0.2, 0.2, 0.2), CFrame.new(pos), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
			local l = Instance.new("PointLight")
			l.Range = 26
			l.Brightness = 0.9
			l.Color = C(245, 248, 255)
			l.Shadows = false
			l.Parent = a
		end
		-- vents, dome cameras, a convex mirror
		for _, pos in { V(-1450, 0, -306), V(-1430, 0, -296), V(-1474, 0, -316) } do
			P("Vent", V(2, 0.1, 2), CFrame.new(pos.X, CEIL - 0.06, pos.Z), C(190, 190, 194), M.DiamondPlate, { parent = g, deco = true })
		end
		for _, pos in { V(-1415, 0, -320.5), V(-1460, 0, -321), V(-1415, 0, -290), V(-1460, 0, -290) } do
			P("CamBase", V(0.9, 0.12, 0.9), CFrame.new(pos.X, CEIL - 0.06, pos.Z), C(230, 230, 230), M.SmoothPlastic, { parent = g, deco = true })
			P("CamDome", V(0.7, 0.7, 0.7), CFrame.new(pos.X, CEIL - 0.12, pos.Z), C(20, 20, 24), M.Glass, { parent = g, deco = true, shape = Enum.PartType.Ball, Transparency = 0.15 })
		end
		P("Mirror", V(1.6, 1.6, 0.4), CFrame.new(XE - 0.9, CEIL - 1.6, ZB - 0.9) * CFrame.Angles(math.rad(-25), math.rad(45), 0), C(220, 226, 232), M.Glass, { parent = g, deco = true, shape = Enum.PartType.Ball, Reflectance = 0.5 })
		-- wall posters
		local posters = {
			{ V(XE - 0.04, 9.5, -305), Enum.NormalId.Left, "SMILE!\nYOU'RE ON CAMERA", C(250, 210, 40), C(20, 20, 20), V(0.04, 1.6, 3.2) },
			{ V(XS - 0.54, 10.5, -298), Enum.NormalId.Left, "ICE COLD\nBEER & MALT", C(20, 40, 90), C(250, 250, 250), V(0.04, 1.8, 4.2) },
			{ V(-1462.72, 10.5, -301), Enum.NormalId.Right, "NO LOITERING\nNO SKATEBOARDS", C(240, 240, 240), C(190, 20, 20), V(0.04, 1.4, 3.2) },
		}
		for _, d in posters do
			local p = P("Poster", d[6], CFrame.new(d[1].X, FY + d[1].Y, d[1].Z), d[4], M.SmoothPlastic, { parent = g, deco = true })
			K.sign(p, d[2], d[3], d[4], d[5])
		end
	end
	model.Parent = store
	task.wait()

	---------------------------------------------------------------- 4. gondolas + endcaps + aisle signs
	local function gondola(gx: number, palettes)
		local g = group("Gondola", model)
		local z0, z1 = -311.6, -296.5
		local L, zc = z1 - z0, (z0 + z1) / 2
		P("Kick", V(1.6, 0.45, L), W(gx, 0.225, zc), C(70, 72, 76), M.Metal, { parent = g })
		P("Spine", V(0.15, 5.4, L), W(gx, 3.15, zc), C(214, 216, 220), M.SmoothPlastic, { parent = g })
		P("Cap", V(1.5, 0.12, L), W(gx, 5.9, zc), C(132, 136, 142), M.Metal, { parent = g })
		for _, z in { z0 + 0.1, z1 - 0.1 } do
			P("Upright", V(1.6, 5.9, 0.18), W(gx, 2.95, z), C(132, 136, 142), M.Metal, { parent = g })
		end
		for side = -1, 1, 2 do
			local pal = palettes[(side + 3) / 2]
			for i, y in { 0.45, 1.75, 3.05, 4.35 } do
				if i > 1 then
					P("Board", V(0.72, 0.08, L - 0.2), W(gx + side * 0.44, y - 0.04, zc), C(225, 226, 230), M.Metal, { parent = g })
				end
				P("PriceStrip", V(0.04, 0.2, L - 0.2), W(gx + side * 0.81, y - 0.1, zc), if i == 2 then C(250, 214, 60) else C(240, 240, 236), M.SmoothPlastic, { parent = g, deco = true })
				local base = CFrame.lookAt(Vector3.new(gx + side * 0.44, FY + y, zc), Vector3.new(gx + side * 5, FY + y, zc))
				K.fillShelf(b, base, L - 0.4, 0.68, if i == 4 then 1.15 else 1.1, rng, pal, g)
			end
		end
		return g
	end
	-- Quality pass (2026-11-02, Alex: "the store, make it a bit bigger, its still very small and crowded"): 3 gondolas
	-- on a 15 stud pitch (13.2 wide aisles). The FirstDay walk now uses aisle 1 (centred x -1431.6).
	gondola(-1424.1, { K.Snacks, K.Snacks })
	gondola(-1439.1, { K.Snacks, K.Grocery })
	task.wait()
	gondola(-1454.1, { K.Grocery, K.Household })
	task.wait()

	-- Restock endcaps: products from the job pop onto these boards (JobFX ShelfFill: 3x3 along X at y +0.85/+2.45/+4.05).
	local endcapSpots = {}
	local function endcap(gx: number, zc: number, facing: number, header: string, color: Color3)
		local g = group("Endcap", model)
		local function q(p)
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false -- the ray must reach the floor (see K.blockers)
			return p
		end
		K.blockers(b, g, W(gx, 0, zc), V(5.0, 6.2, 1.8))
		q(P("Base", V(5.0, 0.3, 1.8), W(gx, 0.15, zc), C(52, 54, 58), M.Metal, { parent = g }))
		for _, y in { 1.85, 3.45 } do
			q(P("Board", V(4.9, 0.1, 1.7), W(gx, y, zc), C(225, 226, 230), M.Metal, { parent = g }))
			P("PriceStrip", V(4.9, 0.2, 0.04), W(gx, y - 0.08, zc - facing * 0.87), C(240, 240, 236), M.SmoothPlastic, { parent = g, deco = true })
		end
		q(P("Back", V(5.0, 6.2, 0.15), W(gx, 3.1, zc + facing * 0.92), C(214, 216, 220), M.SmoothPlastic, { parent = g }))
		for _, s in { -1, 1 } do
			q(P("Side", V(0.15, 5.4, 1.8), W(gx + s * 2.5, 2.7, zc), C(132, 136, 142), M.Metal, { parent = g }))
		end
		local hdr = P("Header", V(5.0, 1.0, 0.2), W(gx, 6.7, zc + facing * 0.8), color, M.SmoothPlastic, { parent = g, deco = true })
		K.sign(hdr, if facing > 0 then Enum.NormalId.Front else Enum.NormalId.Back, header, color, C(255, 255, 255))
		-- one "sold out" talker until you restock it
		local talker = P("Talker", V(1.4, 0.5, 0.03), W(gx + 1.6, 1.68, zc - facing * 0.9), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(talker, if facing > 0 then Enum.NormalId.Front else Enum.NormalId.Back, "SOLD OUT", C(250, 214, 60), C(180, 20, 20))
		table.insert(endcapSpots, V(gx, FY + 2.5, zc))
		return g
	end
	endcap(-1454.1, -312.5, 1, "NEW ARRIVALS", C(30, 96, 58)) -- Shelf1
	endcap(-1454.1, -295.6, -1, "2 FOR $5", C(200, 30, 30)) -- Shelf2
	endcap(-1424.1, -312.5, 1, "HOT DEALS", C(200, 30, 30)) -- Shelf3
	endcap(-1424.1, -295.6, -1, "FRESH STOCK", C(30, 96, 58)) -- Shelf4
	endcap(-1439.1, -312.5, 1, "WEEKLY SPECIALS", C(30, 96, 58)) -- decor only (the Studio copy is stocked and has no talker)
	task.wait()

	do -- hanging aisle signs
		local g = group("AisleSigns", model)
		local aisles = { { -1431.6, "1  CHIPS · SNACKS" }, { -1446.6, "2  CANNED · GROCERY" }, { -1458.45, "3  HOUSEHOLD · PAPER" } }
		for _, a in aisles do
			local s = P("AisleSign", V(4.6, 1.3, 0.15), CFrame.new(a[1], FY + 10.2, -311.5), C(30, 96, 58), M.SmoothPlastic, { parent = g, deco = true })
			K.sign(s, Enum.NormalId.Front, a[2], C(30, 96, 58), C(255, 255, 255), { font = Enum.Font.GothamBold })
			K.sign(s, Enum.NormalId.Back, a[2], C(30, 96, 58), C(255, 255, 255), { font = Enum.Font.GothamBold })
			for _, dx in { -1.8, 1.8 } do
				P("Wire", V(0.05, CEIL - FY - 10.85, 0.05), CFrame.new(a[1] + dx, (FY + 10.85 + CEIL) / 2, -311.5), C(40, 40, 40), M.Metal, { parent = g, deco = true })
			end
		end
	end

	---------------------------------------------------------------- 5. coolers
	local function cooler(cf: CFrame, L: number, label: string, palette)
		-- cf: floor point at the centre of the front face, LookVector = out to the customer
		local g = group("Cooler", model)
		local doors = math.max(1, math.floor(L / 3.1))
		local dw = L / doors
		local D = 2.4
		local function at(x, y, z)
			return cf * CFrame.new(x, y, z)
		end
		P("Kick", V(L, 0.9, D), at(0, 0.45, D / 2), C(28, 28, 30), M.SmoothPlastic, { parent = g })
		P("Inside", V(L, 7.3, 0.2), at(0, 4.55, D - 0.1), C(36, 40, 46), M.SmoothPlastic, { parent = g })
		P("Top", V(L, 0.2, D), at(0, 8.1, D / 2), C(36, 40, 46), M.SmoothPlastic, { parent = g })
		local hdr = P("Header", V(L, 1.3, D + 0.2), at(0, 8.85, D / 2 - 0.1), C(24, 24, 26), M.SmoothPlastic, { parent = g })
		K.sign(hdr, Enum.NormalId.Front, label, C(24, 24, 26), C(255, 255, 255), { lit = true, font = Enum.Font.GothamBold, pad = 0.18 })
		P("Glow", V(L - 0.2, 0.1, 0.1), at(0, 7.9, 0.3), C(220, 240, 255), M.Neon, { parent = g, deco = true })
		for e = -1, 1, 2 do
			P("EndPanel", V(0.25, 8.2, D), at(e * (L / 2 - 0.125), 4.1, D / 2), C(28, 28, 30), M.SmoothPlastic, { parent = g })
		end
		for lvl, y in { 1.0, 2.45, 3.9, 5.35, 6.8 } do
			P("Shelf", V(L - 0.4, 0.08, D - 0.5), at(0, y, D / 2 + 0.1), C(170, 174, 180), M.Metal, { parent = g, deco = true })
			for d = 1, doors do
				local x0 = -L / 2 + (d - 1) * dw + 0.25
				local x = x0
				local maxH = if lvl == 5 then 0.9 else 1.25
				while x < x0 + dw - 0.6 do
					local pal = palette[rng:NextInteger(1, #palette)]
					local w = rng:NextNumber(0.55, 0.95)
					if x + w > x0 + dw - 0.3 then
						break
					end
					local h = maxH * rng:NextNumber(0.7, 1)
					P("Drink", V(w, h, D - 0.8), at(x + w / 2, y + 0.04 + h / 2, D / 2 + 0.15), pal[1], M.SmoothPlastic, { parent = g, deco = true })
					if lvl > 1 and lvl < 5 then P("Cap", V(w * 0.9, 0.12, D - 0.9), at(x + w / 2, y + 0.04 + h + 0.06, D / 2 + 0.15), pal[2], M.SmoothPlastic, { parent = g, deco = true }) end
					x += w + 0.08
				end
			end
		end
		for d = 0, doors do
			local x = -L / 2 + d * dw
			P("Mullion", V(0.22, 7.2, 0.25), at(x, 4.5, 0.12), C(40, 40, 42), M.Metal, { parent = g })
		end
		for d = 1, doors do
			local x = -L / 2 + (d - 0.5) * dw
			P("Door", V(dw - 0.22, 7.0, 0.1), at(x, 4.5, 0.12), C(180, 210, 225), M.Glass, { parent = g, Transparency = 0.7 })
			P("Handle", V(0.1, 2.4, 0.14), at(x + dw / 2 - 0.45, 4.6, -0.04), C(200, 202, 206), M.Metal, { parent = g, deco = true })
		end
		local light = P("CoolerLight", V(0.2, 0.2, 0.2), at(0, 7.6, 0.6), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 10
		sl.Brightness = 1.2
		sl.Angle = 120
		sl.Color = C(220, 236, 255)
		sl.Parent = light
		return g
	end
	cooler(CFrame.lookAt(V(-1437.4, FY, ZB - 2.45), V(-1437.4, FY, ZB - 10)), 49.6, "COLD DRINKS · WATER · JUICE", K.Drinks)
	task.wait()
	cooler(CFrame.lookAt(V(XS - 2.95, FY, -296.4), V(XS - 10, FY, -296.4)), 19.0, "BEER · MALT · ICE", K.Drinks) -- on the stockroom's west wall, facing the wing
	task.wait()

	---------------------------------------------------------------- 6. checkout
	do
		local g = group("Checkout", model)
		local cz0, cz1 = -322.3, -315.5
		local czc, cl = (cz0 + cz1) / 2, cz1 - cz0
		P("CounterBody", V(1.8, 3.25, cl), W(-1425, 1.725, czc), C(122, 74, 46), M.Wood, { parent = g })
		P("CounterKick", V(1.9, 0.3, cl), W(-1425, 0.15, czc), C(30, 30, 32), M.SmoothPlastic, { parent = g })
		P("CounterTop", V(2.1, 0.15, cl + 0.2), W(-1425, 3.42, czc), C(44, 44, 48), M.Slate, { parent = g })
		P("CounterEdge", V(0.05, 3.0, cl), W(-1425.93, 1.75, czc), C(150, 92, 58), M.Wood, { parent = g, deco = true })
		local front = P("CounterSign", V(0.04, 1.0, 4.0), W(-1425.94, 2.2, czc + 0.6), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(front, Enum.NormalId.Left, "MUST BE 21 · NO CHECKS\nWE CARD EVERYONE", C(250, 250, 250), C(170, 20, 20), { font = Enum.Font.GothamBold })
		-- plexiglass shield with a pass-through at the till
		local function plexi(z0, z1, y0, y1)
			P("Plexi", V(0.12, y1 - y0, z1 - z0), W(-1425.0, (y0 + y1) / 2, (z0 + z1) / 2), C(200, 220, 230), M.Glass, { parent = g, Transparency = 0.8 })
		end
		plexi(cz0, -318.5, 3.5, 7.2)
		plexi(-316.5, cz1, 3.5, 7.2)
		plexi(-318.5, -316.5, 4.6, 7.2)
		P("PlexiTrim", V(0.2, 0.12, cl), W(-1425.0, 7.25, czc), C(60, 60, 64), M.Metal, { parent = g, deco = true })
		-- till (faces the clerk, +X) + card reader on the customer side
		local tz = -317.5
		P("TillDrawer", V(1.0, 0.4, 1.4), W(-1424.4, 3.7, tz), C(36, 36, 40), M.SmoothPlastic, { parent = g, deco = true })
		P("TillBody", V(0.8, 0.5, 1.2), W(-1424.35, 4.15, tz), C(50, 50, 54), M.SmoothPlastic, { parent = g, deco = true })
		local scr = P("TillScreen", V(0.08, 0.8, 1.1), W(-1424.25, 4.8, tz) * CFrame.Angles(0, 0, math.rad(-12)), C(30, 30, 34), M.SmoothPlastic, { parent = g, deco = true })
		P("TillGlow", V(0.02, 0.62, 0.92), scr.CFrame * CFrame.new(0.05, 0, 0), C(120, 220, 170), M.Neon, { parent = g, deco = true })
		P("Printer", V(0.6, 0.4, 0.6), W(-1424.4, 3.7, tz - 1.2), C(220, 220, 220), M.SmoothPlastic, { parent = g, deco = true })
		P("CardReader", V(0.45, 0.2, 0.3), W(-1425.65, 3.6, tz + 0.2) * CFrame.Angles(0, 0, math.rad(20)), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
		P("CardScreen", V(0.02, 0.14, 0.2), W(-1425.76, 3.66, tz + 0.2) * CFrame.Angles(0, 0, math.rad(20)), C(120, 200, 255), M.Neon, { parent = g, deco = true })
		-- candy rack + lottery dispenser on the counter
		for i = 0, 2 do
			P("CandyTier", V(0.35, 0.12, 1.8), W(-1425.8 + i * 0.2, 3.56 + i * 0.32, -320.6), C(200, 200, 204), M.Metal, { parent = g, deco = true })
			for j = 0, 4 do
				local pal = K.Snacks[rng:NextInteger(1, #K.Snacks)]
				P("Candy", V(0.25, 0.26, 0.3), W(-1425.8 + i * 0.2, 3.75 + i * 0.32, -321.3 + j * 0.35), pal[1], M.SmoothPlastic, { parent = g, deco = true })
			end
		end
		P("LottoCase", V(0.8, 1.6, 2.2), W(-1424.5, 4.3, -321.2), C(200, 220, 230), M.Glass, { parent = g, deco = true, Transparency = 0.6 })
		for i = 0, 5 do
			P("Ticket", V(0.04, 0.7, 0.28), W(-1424.6, 4.45, -322.15 + i * 0.36), Color3.fromHSV(i / 6, 0.7, 0.95), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- clerk's side: back counter, cigarette wall, lotto screen, CCTV monitor, stool
		P("BackCounter", V(1.6, 3.0, 8.0), W(XE - 0.8, 1.5, -318.4), C(122, 74, 46), M.Wood, { parent = g })
		P("BackTop", V(1.7, 0.12, 8.1), W(XE - 0.8, 3.06, -318.4), C(44, 44, 48), M.Slate, { parent = g })
		local rack = P("SmokeRack", V(0.8, 4.4, 7.6), W(XE - 0.45, 6.2, -318.4), C(30, 30, 34), M.SmoothPlastic, { parent = g })
		for r = 0, 6 do
			local x0 = -322.0
			while x0 < -314.9 do
				local pal = K.Snacks[rng:NextInteger(1, #K.Snacks)]
				P("Pack", V(0.3, 0.45, 0.42), W(XE - 0.95, 4.35 + r * 0.6, x0 + 0.21), if rng:NextNumber() < 0.5 then C(240, 240, 236) else pal[1], M.SmoothPlastic, { parent = g, deco = true })
				x0 += 0.48
			end
		end
		local lot = P("LottoSign", V(0.2, 1.0, 4.0), W(XE - 0.6, 9.2, -318.4), C(200, 30, 30), M.SmoothPlastic, { parent = g })
		K.sign(lot, Enum.NormalId.Left, "★ LOTTO ★ PLAY HERE", C(200, 30, 30), C(255, 230, 80), { lit = true })
		local mon = P("Monitor", V(0.9, 1.3, 1.6), W(XE - 0.9, 3.75, -321.6) * CFrame.Angles(0, math.rad(-15), 0), C(36, 36, 38), M.SmoothPlastic, { parent = g, deco = true })
		K.grid(P("MonitorScreen", V(0.02, 1.0, 1.3), mon.CFrame * CFrame.new(-0.46, 0.05, 0), C(0, 0, 0), M.SmoothPlastic, { parent = g, deco = true }), Enum.NormalId.Left, 2, 2, C(56, 70, 66), C(10, 10, 10), true)
		P("LottoTerm", V(0.9, 0.7, 1.2), W(XE - 0.9, 3.45, -316.2), C(220, 220, 224), M.SmoothPlastic, { parent = g, deco = true })
		P("LottoTermScreen", V(0.02, 0.4, 0.8), W(XE - 1.36, 3.6, -316.2), C(90, 160, 255), M.Neon, { parent = g, deco = true })
		P("StoolSeat", V(0.2, 1.2, 1.2), W(-1418.5, 2.8, -320.4), C(30, 30, 32), M.SmoothPlastic, { parent = g, shape = Enum.PartType.Cylinder, CFrame = W(-1418.5, 2.8, -320.4) * CFrame.Angles(0, 0, math.rad(90)) })
		P("StoolLeg", V(0.2, 2.7, 0.2), W(-1418.5, 1.35, -320.4), C(150, 152, 156), M.Metal, { parent = g })
		P("ClerkMat", V(3, 0.05, 5), W(-1421, 0.03, -318.5), C(30, 30, 32), M.Rubber, { parent = g, deco = true })
	end
	task.wait()

	---------------------------------------------------------------- 7. front floor (west): coffee + slush, ATM, chips, freezer
	do
		local g = group("FrontWest", model)
		local x0, x1 = -1473.4, -1463.0
		local xc, L = (x0 + x1) / 2, x1 - x0
		P("CoffeeCounter", V(L, 3.2, 2.0), W(xc, 1.6, ZF + 1.0), C(122, 74, 46), M.Wood, { parent = g })
		P("CoffeeTop", V(L + 0.1, 0.12, 2.1), W(xc, 3.26, ZF + 1.0), C(200, 196, 188), M.Marble, { parent = g })
		-- coffee machine
		P("Brewer", V(2.0, 2.2, 1.3), W(-1471.6, 4.42, ZF + 0.8), C(30, 30, 32), M.Metal, { parent = g, deco = true })
		for i = 0, 1 do
			P("Pot", V(0.6, 0.7, 0.6), W(-1472.1 + i * 1.0, 3.7, ZF + 1.45), C(60, 30, 20), M.Glass, { parent = g, deco = true, Transparency = 0.2 })
			P("Burner", V(0.7, 0.06, 0.7), W(-1472.1 + i * 1.0, 3.35, ZF + 1.45), C(200, 40, 30), M.Neon, { parent = g, deco = true })
		end
		for i = 0, 2 do
			P("Cups", V(0.45, 1.4, 0.45), W(-1469.8 + i * 0.6, 4.02, ZF + 1.3), C(250, 250, 246), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- slush machine: two bowls
		P("SlushBase", V(2.4, 1.2, 1.4), W(-1466.6, 3.92, ZF + 0.9), C(220, 220, 224), M.Metal, { parent = g, deco = true })
		for i, col in { C(230, 40, 60), C(40, 120, 230) } do
			local x = -1467.2 + (i - 1) * 1.2
			P("SlushBowl", V(1.0, 1.7, 1.0), W(x, 5.4, ZF + 0.9), col, M.Glass, { parent = g, deco = true, Transparency = 0.25 })
			P("SlushLid", V(1.05, 0.2, 1.05), W(x, 6.35, ZF + 0.9), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- hot dog roller
		P("Roller", V(1.8, 0.4, 1.2), W(-1464.2, 3.52, ZF + 1.1), C(190, 190, 194), M.Metal, { parent = g, deco = true })
		for i = 0, 3 do
			P("HotDog", V(1.4, 0.18, 0.18), W(-1464.2, 3.82, ZF + 0.7 + i * 0.27), C(170, 70, 50), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		end
		P("RollerHood", V(1.9, 0.08, 1.3), W(-1464.2, 4.6, ZF + 1.1), C(200, 220, 230), M.Glass, { parent = g, deco = true, Transparency = 0.5 })
		local menu = P("CoffeeSign", V(6.0, 1.2, 0.08), W(-1468.2, 7.6, ZF + 0.1), C(60, 30, 20), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(menu, Enum.NormalId.Back, "HOT COFFEE 99¢ · SLUSH $1.49 · HOT DOGS 2/$3", C(60, 30, 20), C(255, 220, 140), { font = Enum.Font.GothamBold })
		-- ATM
		local atm = group("ATM", g)
		P("AtmBody", V(2.2, 5.4, 1.6), W(-1457.5, 2.7, ZF + 0.85), C(40, 70, 130), M.SmoothPlastic, { parent = atm })
		P("AtmFace", V(1.8, 2.4, 0.1), W(-1457.5, 3.6, ZF + 1.68), C(40, 40, 44), M.SmoothPlastic, { parent = atm })
		P("AtmScreen", V(1.0, 0.75, 0.05), W(-1457.5, 4.3, ZF + 1.74), C(100, 180, 255), M.Neon, { parent = atm, deco = true })
		P("AtmKeys", V(0.8, 0.5, 0.05), W(-1457.5, 3.2, ZF + 1.74), C(170, 170, 176), M.Metal, { parent = atm, deco = true })
		local atop = P("AtmTop", V(2.2, 0.8, 1.7), W(-1457.5, 5.8, ZF + 0.85), C(250, 250, 250), M.SmoothPlastic, { parent = atm })
		K.sign(atop, Enum.NormalId.Back, "ATM", C(250, 250, 250), C(40, 70, 130), { lit = true })
		-- trash can by the door (Bin1)
		local bin = group("TrashCan", g)
		P("Can", V(2.8, 1.9, 1.9), W(-1461.3, 1.4, ZF + 1.3) * CFrame.Angles(0, 0, math.rad(90)), C(60, 64, 68), M.Metal, { parent = bin, shape = Enum.PartType.Cylinder, deco = true })
		P("Lid", V(0.3, 2.0, 2.0), W(-1461.3, 2.95, ZF + 1.3) * CFrame.Angles(0, 0, math.rad(90)), C(36, 36, 38), M.SmoothPlastic, { parent = bin, shape = Enum.PartType.Cylinder, deco = true })
		K.blockers(b, bin, W(-1461.3, 0, ZF + 1.3), V(2.1, 3.1, 2.1))
		-- chip racks + freezer chest
		local function chipRack(x, z)
			local r = group("ChipRack", g)
			P("Post", V(0.2, 6, 0.2), W(x, 3, z - 1.4), C(60, 60, 64), M.Metal, { parent = r })
			P("Post", V(0.2, 6, 0.2), W(x, 3, z + 1.4), C(60, 60, 64), M.Metal, { parent = r })
			local hdr = P("Header", V(0.15, 0.9, 3.0), W(x, 6.3, z), C(230, 40, 36), M.SmoothPlastic, { parent = r, deco = true })
			K.sign(hdr, Enum.NormalId.Right, "CHIPS", C(230, 40, 36), C(255, 230, 80))
			for i = 0, 4 do
				local y = 0.6 + i * 1.1
				P("Wire", V(1.0, 0.06, 2.8), W(x + 0.3, y, z) * CFrame.Angles(0, 0, math.rad(-10)), C(80, 80, 84), M.Metal, { parent = r, deco = true })
				for j = 0, 2 do
					local pal = K.Snacks[rng:NextInteger(1, #K.Snacks)]
					P("Bag", V(0.35, 0.95, 0.85), W(x + 0.35, y + 0.5, z - 0.95 + j * 0.95) * CFrame.Angles(0, 0, math.rad(-12)), pal[1], M.SmoothPlastic, { parent = r, deco = true })
				end
			end
		end
		chipRack(-1480.5, -318)
		chipRack(-1480.5, -311)
		P("FreezerBody", V(5.0, 3.0, 2.6), W(-1472, 1.5, -314.5), C(240, 240, 240), M.SmoothPlastic, { parent = g })
		P("FreezerLid", V(4.8, 0.1, 2.4), W(-1472, 3.05, -314.5), C(200, 220, 235), M.Glass, { parent = g, Transparency = 0.5 })
		for i = 0, 7 do
			local pal = K.Snacks[rng:NextInteger(1, #K.Snacks)]
			P("IceCream", V(0.5, 0.4, 0.9), W(-1474 + i * 0.55, 2.7, -314.9 + (i % 2) * 0.9), pal[1], M.SmoothPlastic, { parent = g, deco = true })
		end
		local fs = P("FreezerSign", V(4.0, 0.7, 0.05), W(-1472, 2.2, -315.83), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(fs, Enum.NormalId.Front, "ICE CREAM", C(60, 150, 230), C(255, 255, 255))
		-- east side: wall shelving (household) + a water pallet display
		P("WallShelfBack", V(0.2, 7.0, 21.0), W(XE - 0.1, 3.5, -301.0), C(214, 216, 220), M.SmoothPlastic, { parent = g })
		for i, y in { 0.45, 1.85, 3.25, 4.65, 6.05 } do
			P("WallBoard", V(1.4, 0.1, 21.0), W(XE - 0.8, y - 0.05, -301.0), C(225, 226, 230), M.Metal, { parent = g })
			local base = CFrame.lookAt(V(XE - 0.8, FY + y, -301.0), V(XE - 5, FY + y, -301.0))
			K.fillShelf(b, base, 20.6, 1.2, if i == 5 then 0.95 else 1.25, rng, K.Household, g)
		end
		local wsh = P("WallShelfSign", V(0.1, 0.9, 8.0), W(XE - 0.25, 7.6, -301.0), C(30, 96, 58), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(wsh, Enum.NormalId.Left, "HOUSEHOLD · PET · BABY", C(30, 96, 58), C(255, 255, 255), { font = Enum.Font.GothamBold })
	end
	task.wait()

	---------------------------------------------------------------- 8. stockroom
	do
		local g = group("Stockroom", model)
		-- pallet racking along the west wall
		local function rack(xc, zc, L)
			local r = group("Racking", g)
			for _, dz in { -L / 2, 0, L / 2 } do
				for _, dx in { -1.1, 1.1 } do
					P("RackPost", V(0.25, 10, 0.25), W(xc + dx, 5, zc + dz), C(40, 80, 160), M.Metal, { parent = r })
				end
			end
			for _, y in { 0.4, 3.6, 6.8, 9.6 } do
				P("RackBeam", V(0.2, 0.35, L), W(xc - 1.1, y, zc), C(230, 120, 30), M.Metal, { parent = r })
				P("RackBeam", V(0.2, 0.35, L), W(xc + 1.1, y, zc), C(230, 120, 30), M.Metal, { parent = r })
				P("RackDeck", V(2.2, 0.08, L), W(xc, y + 0.2, zc), C(150, 150, 152), M.DiamondPlate, { parent = r, deco = true })
				if y < 9 then
					local z = zc - L / 2 + 0.2
					while z < zc + L / 2 - 1.4 do
						local h = rng:NextNumber(1.0, 2.6)
						local w = rng:NextNumber(1.2, 2.0)
						P("Box", V(rng:NextNumber(1.6, 2.0), h, w), W(xc + rng:NextNumber(-0.1, 0.1), y + 0.24 + h / 2, z + w / 2) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0), C(176 + rng:NextInteger(-16, 10), 132 + rng:NextInteger(-14, 10), 84), M.Cardboard, { parent = r, deco = true })
						z += w + rng:NextNumber(0.1, 0.6)
					end
				end
			end
		end
		rack(XS + 1.4, -300.5, 9.0)
		rack(XS + 1.4, -291.0, 8.0)
		-- the stock pallet (Stockroom station): boxes ready to grab
		local pal = group("StockPallet", g)
		P("Pallet", V(3.6, 0.45, 3.6), W(-1474, 0.225, -297), C(170, 130, 80), M.WoodPlanks, { parent = pal, deco = true })
		K.blockers(b, pal, W(-1474, 0, -297), V(3.8, 5.2, 3.8))
		for i, p in { V(-0.9, 0.8, -0.9), V(0.9, 0.8, -0.9), V(-0.9, 0.8, 0.9), V(0.9, 0.8, 0.9), V(-0.9, 2.4, -0.9), V(0.9, 2.4, 0.9), V(0, 4.0, 0) } do
			P("Box" .. i, V(1.75, 1.55, 1.7), W(-1474 + p.X, 0.45 + p.Y - 0.8 + 0.78, -297 + p.Z) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), C(176, 132, 84), M.Cardboard, { parent = pal, deco = true })
		end
		local tag = P("PalletTag", V(1.6, 0.9, 0.04), W(-1474, 1.2, -298.88), C(255, 255, 255), M.SmoothPlastic, { parent = pal, deco = true })
		K.sign(tag, Enum.NormalId.Front, "STOCK FOR\nFLOOR", C(255, 255, 255), C(20, 20, 20), { font = Enum.Font.Arcade })
		-- hand truck
		for _, dz in { -0.65, 0.65 } do
			P("TruckRail", V(0.15, 4.4, 0.15), W(-1471.0, 2.25, -298.4 + dz) * CFrame.Angles(0, 0, math.rad(-12)), C(200, 40, 30), M.Metal, { parent = g })
			P("TruckWheel", V(0.25, 0.8, 0.8), W(-1470.4, 0.4, -298.4 + dz * 1.25), C(30, 30, 30), M.Rubber, { parent = g, shape = Enum.PartType.Cylinder, deco = true })
		end
		for _, y in { 1.4, 2.6, 3.8 } do
			P("TruckBar", V(0.1, 0.1, 1.3), W(-1471.0 - (y - 2.25) * 0.21, y, -298.4), C(200, 40, 30), M.Metal, { parent = g, deco = true })
		end
		P("TruckNose", V(1.0, 0.1, 1.6), W(-1470.8, 0.1, -298.4), C(150, 150, 150), M.Metal, { parent = g, deco = true })
		-- second pallet: shrink-wrapped drinks
		P("Pallet2", V(3.6, 0.45, 3.6), W(-1480, 0.225, -296), C(170, 130, 80), M.WoodPlanks, { parent = g })
		for lx = 0, 2 do
			for ly = 0, 3 do
				for lz = 0, 2 do
					P("Case", V(1.05, 0.78, 1.05), W(-1481.1 + lx * 1.1, 0.86 + ly * 0.8, -297.1 + lz * 1.1), if (lx + ly + lz) % 2 == 0 then C(200, 30, 40) else C(220, 40, 50), M.SmoothPlastic, { parent = g, deco = true })
				end
			end
		end
		P("Wrap", V(3.45, 3.3, 3.45), W(-1480, 2.1, -296), C(235, 240, 245), M.Glass, { parent = g, Transparency = 0.7 })
		-- time clock + cork board on the partition (stockroom side, by the door)
		local tc = group("TimeClock", g)
		P("ClockBody", V(0.6, 1.6, 1.2), W(-1463.55, 4.6, -299.5), C(214, 210, 196), M.SmoothPlastic, { parent = tc })
		P("ClockFace", V(0.05, 0.6, 0.8), W(-1463.88, 5.0, -299.5), C(250, 250, 250), M.SmoothPlastic, { parent = tc, deco = true })
		P("ClockDigits", V(0.04, 0.22, 0.6), W(-1463.9, 5.0, -299.5), C(255, 80, 60), M.Neon, { parent = tc, deco = true })
		P("CardSlot", V(0.05, 0.1, 0.5), W(-1463.88, 4.3, -299.5), C(20, 20, 20), M.SmoothPlastic, { parent = tc, deco = true })
		P("CardRack", V(0.3, 2.2, 1.2), W(-1463.6, 4.6, -301.0), C(150, 150, 154), M.Metal, { parent = tc })
		for i = 0, 5 do
			P("TimeCard", V(0.05, 0.9, 0.18), W(-1463.8, 4.9, -301.45 + i * 0.18), C(240, 236, 210), M.SmoothPlastic, { parent = tc, deco = true })
		end
		local cork = P("CorkBoard", V(0.12, 2.4, 3.4), W(-1463.31, 5.4, -303.4), C(170, 120, 70), M.Fabric, { parent = g })
		for i = 0, 4 do
			P("Note", V(0.04, 0.7, 0.6), W(-1463.39, 4.7 + (i % 2) * 1.1, -304.6 + i * 0.6), Color3.fromHSV(0.12 + i * 0.13, 0.3, 1), M.SmoothPlastic, { parent = g, deco = true })
		end
		local eom = P("EmployeeOfMonth", V(0.04, 0.9, 1.0), W(-1463.39, 6.0, -302.4), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(eom, Enum.NormalId.Left, "EMPLOYEE\nOF THE\nMONTH", C(255, 255, 255), C(30, 96, 58))
		_ = cork
		-- lockers along the partition (south side of the room)
		for i = 0, 4 do
			local lx = -1471.5 + i * 1.5
			P("Locker", V(1.4, 6.0, 1.4), W(lx, 3, -304.95), C(90, 110, 130), M.Metal, { parent = g })
			P("LockerVent", V(0.8, 0.5, 0.05), W(lx, 5.2, -304.22), C(50, 60, 70), M.SmoothPlastic, { parent = g, deco = true })
			P("LockerHandle", V(0.1, 0.5, 0.1), W(lx + 0.45, 3.3, -304.2), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		end
		-- desk with an old monitor (Patel's corner)
		P("Desk", V(4.0, 0.2, 2.0), W(-1482.5, 2.6, -304.4), C(110, 80, 56), M.Wood, { parent = g })
		for _, dx in { -1.85, 1.85 } do
			P("DeskLeg", V(0.2, 2.5, 1.8), W(-1482.5 + dx, 1.25, -304.4), C(80, 60, 44), M.Wood, { parent = g })
		end
		P("CRT", V(1.4, 1.2, 1.3), W(-1483.2, 3.3, -304.6), C(200, 196, 180), M.SmoothPlastic, { parent = g, deco = true })
		P("CRTGlow", V(1.0, 0.8, 0.04), W(-1483.2, 3.35, -303.93), C(70, 110, 90), M.Neon, { parent = g, deco = true })
		P("Papers", V(0.9, 0.06, 0.7), W(-1481.6, 2.73, -304.2) * CFrame.Angles(0, math.rad(12), 0), C(245, 245, 240), M.SmoothPlastic, { parent = g, deco = true })
		P("Mug", V(0.35, 0.3, 0.3), W(-1481.1, 2.88, -304.8), C(200, 40, 40), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = W(-1481.1, 2.88, -304.8) * CFrame.Angles(0, 0, math.rad(90)) })
		P("ChairSeat", V(1.4, 0.25, 1.4), W(-1482.5, 1.7, -302.6), C(30, 30, 34), M.Fabric, { parent = g })
		P("ChairBack", V(1.4, 1.5, 0.2), W(-1482.5, 2.6, -301.9), C(30, 30, 34), M.Fabric, { parent = g })
		P("ChairPost", V(0.2, 1.5, 0.2), W(-1482.5, 0.8, -302.6), C(120, 120, 124), M.Metal, { parent = g })
		-- mop sink, mop bucket, water heater, wet-floor sign
		P("MopSink", V(2.4, 1.0, 2.0), W(-1468.5, 0.5, ZB - 1.1), C(220, 220, 214), M.Concrete, { parent = g })
		P("Faucet", V(0.2, 1.4, 0.2), W(-1468.5, 2.0, ZB - 0.2), C(190, 190, 194), M.Metal, { parent = g, deco = true })
		P("Heater", V(5.0, 2.0, 2.0), W(-1465.4, 2.5, ZB - 1.1), C(200, 200, 196), M.Metal, { parent = g, shape = Enum.PartType.Cylinder, CFrame = W(-1465.4, 2.5, ZB - 1.1) * CFrame.Angles(0, 0, math.rad(90)) })
		P("Bucket", V(1.2, 1.0, 1.0), W(-1468.2, 0.5, ZB - 3.0), C(250, 200, 30), M.Plastic, { parent = g })
		P("MopHandle", V(0.12, 5.0, 0.12), W(-1468.2, 2.6, ZB - 3.0) * CFrame.Angles(math.rad(14), 0, 0), C(200, 180, 140), M.Wood, { parent = g, deco = true })
		local wet = P("WetSign", V(1.0, 2.2, 0.08), W(-1466.2, 1.1, ZB - 3.2) * CFrame.Angles(math.rad(10), math.rad(20), 0), C(250, 210, 30), M.Plastic, { parent = g, deco = true })
		K.sign(wet, Enum.NormalId.Front, "⚠\nCAUTION\nWET FLOOR", C(250, 210, 30), C(20, 20, 20))
		-- trash can (Bin2) by the back door
		local bin = group("TrashCan", g)
		P("Can", V(2.8, 2.0, 2.0), W(-1472.0, 1.4, ZB - 1.4) * CFrame.Angles(0, 0, math.rad(90)), C(30, 60, 120), M.Plastic, { parent = bin, shape = Enum.PartType.Cylinder, deco = true })
		P("Bag", V(0.2, 2.1, 2.1), W(-1472.0, 2.85, ZB - 1.4) * CFrame.Angles(0, 0, math.rad(90)), C(26, 26, 28), M.Plastic, { parent = bin, shape = Enum.PartType.Cylinder, deco = true })
		K.blockers(b, bin, W(-1472.0, 0, ZB - 1.4), V(2.1, 3.0, 2.1))
		-- flattened boxes, ladder, extinguisher
		for i = 0, 3 do
			P("FlatBox", V(0.1, 3.2, 4.0), W(-1486.2 + i * 0.12, 1.6, ZB - 3.5) * CFrame.Angles(0, 0, math.rad(-8)), C(170, 128, 80), M.Cardboard, { parent = g, deco = true })
		end
		P("Extinguisher", V(0.5, 1.4, 0.5), W(-1463.55, 2.6, -288.2), C(200, 20, 20), M.SmoothPlastic, { parent = g, deco = true })
		-- stockroom lights: bare tubes + a light
		for _, z in { -301, -292 } do
			P("Tube", V(0.3, 0.2, 4.0), CFrame.new(-1476, CEIL - 0.3, z), C(246, 248, 255), M.Neon, { parent = g, deco = true })
		end
		local a = P("StockLight", V(0.2, 0.2, 0.2), CFrame.new(-1476, CEIL - 0.8, -296), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 1.0
		l.Color = C(240, 244, 255)
		l.Shadows = false
		l.Parent = a
	end
	task.wait()

	---------------------------------------------------------------- 11. west wing: deli / hot food, produce, frozen, meat & dairy
	do
		local g = group("WestWing", model)
		local function hang(x, z, text, color, w)
			local s = P("HangSign", V(w or 5.0, 1.3, 0.15), CFrame.new(x, FY + 10.2, z), color, M.SmoothPlastic, { parent = g, deco = true })
			K.sign(s, Enum.NormalId.Front, text, color, C(255, 255, 255), { font = Enum.Font.GothamBold })
			K.sign(s, Enum.NormalId.Back, text, color, C(255, 255, 255), { font = Enum.Font.GothamBold })
			for _, dx in { -(w or 5) / 2 + 0.4, (w or 5) / 2 - 0.4 } do
				P("Wire", V(0.05, CEIL - FY - 10.85, 0.05), CFrame.new(x + dx, (FY + 10.85 + CEIL) / 2, z), C(40, 40, 40), M.Metal, { parent = g, deco = true })
			end
		end
		-- deli: glass case along the west wall, staff strip behind it
		local dx, z0, z1 = -1517.5, -320.0, -300.0
		local zc, L = (z0 + z1) / 2, z1 - z0
		P("DeliBase", V(2.0, 2.8, L), W(dx, 1.4, zc), C(122, 74, 46), M.Wood, { parent = g })
		P("DeliKick", V(2.05, 0.3, L), W(dx, 0.15, zc), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		P("DeliDeck", V(2.0, 0.1, L), W(dx, 2.85, zc), C(200, 200, 204), M.Metal, { parent = g })
		P("DeliGlass", V(0.1, 1.9, L), W(dx + 0.75, 3.75, zc) * CFrame.Angles(0, 0, math.rad(-18)), C(200, 225, 235), M.Glass, { parent = g, Transparency = 0.7 })
		P("DeliTop", V(1.2, 0.1, L), W(dx - 0.2, 4.75, zc), C(200, 225, 235), M.Glass, { parent = g, Transparency = 0.6 })
		P("DeliLight", V(0.3, 0.08, L - 0.4), W(dx - 0.5, 4.68, zc), C(255, 236, 200), M.Neon, { parent = g, deco = true })
		local foods = { { C(176, 100, 40), "lump" }, { C(120, 64, 40), "flat" }, { C(240, 150, 40), "wedge" }, { C(245, 240, 225), "flat" }, { C(200, 60, 40), "lump" }, { C(220, 170, 80), "lump" }, { C(90, 140, 60), "flat" } }
		local tz = z0 + 0.6
		local fi = 0
		while tz < z1 - 1.8 do
			fi += 1
			local f = foods[(fi - 1) % #foods + 1]
			P("Tray", V(1.4, 0.12, 2.2), W(dx, 3.0, tz + 1.1), C(220, 220, 224), M.Metal, { parent = g, deco = true })
			if f[2] == "flat" then
				P("Food", V(1.2, 0.25, 2.0), W(dx, 3.18, tz + 1.1), f[1], M.SmoothPlastic, { parent = g, deco = true })
			else
				for k = 0, 3 do
					P("Food", V(0.55, 0.4, 0.55), W(dx + (k % 2) * 0.5 - 0.25, 3.3, tz + 0.5 + math.floor(k / 2) * 0.9) * CFrame.Angles(0, k, 0.3), f[1], M.SmoothPlastic, { parent = g, deco = true })
				end
			end
			P("Tag", V(0.05, 0.3, 0.6), W(dx + 0.95, 2.55, tz + 1.1), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
			tz += 2.4
		end
		-- staff side: back counter with fryers, warmer, rice cooker
		local bx = XW + 0.9
		P("DeliBack", V(1.8, 3.1, L), W(bx, 1.55, zc), C(200, 200, 204), M.Metal, { parent = g })
		for i = 0, 1 do
			P("Fryer", V(1.6, 1.2, 1.8), W(bx, 3.7, z0 + 1.5 + i * 2.0), C(170, 172, 176), M.Metal, { parent = g, deco = true })
			P("FryOil", V(1.2, 0.05, 1.4), W(bx, 4.32, z0 + 1.5 + i * 2.0), C(170, 120, 30), M.SmoothPlastic, { parent = g, deco = true })
		end
		P("Warmer", V(1.6, 2.4, 3.2), W(bx, 4.3, z0 + 7.0), C(60, 60, 64), M.Metal, { parent = g, deco = true })
		P("WarmerGlass", V(0.05, 1.8, 2.8), W(bx + 0.83, 4.3, z0 + 7.0), C(255, 170, 90), M.Glass, { parent = g, deco = true, Transparency = 0.4 })
		P("RiceCooker", V(1.0, 0.9, 1.0), W(bx, 3.6, z0 + 10.5), C(240, 240, 236), M.SmoothPlastic, { parent = g, deco = true })
		P("Slicer", V(1.2, 0.9, 1.4), W(bx, 3.6, z0 + 13.0), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		P("SlicerBlade", V(0.08, 0.8, 0.8), W(bx + 0.3, 3.9, z0 + 13.0), C(230, 230, 236), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = W(bx + 0.3, 3.9, z0 + 13.0) })
		local menu = P("DeliMenu", V(0.12, 3.0, 14.0), W(XW + 0.06, 8.6, zc), C(24, 24, 26), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(menu, Enum.NormalId.Right, "<b>HOT FOOD · DELI</b>\n2 PC CHICKEN + SIDE $5.99 · BEEF PATTY $2.50\nEMPANADAS 3/$4 · ARROZ CON POLLO $6.99", C(24, 24, 26), C(255, 220, 140), { lit = true, font = Enum.Font.GothamBold, pad = 0.05 })

		-- produce islands near the windows
		local function produce(x, z)
			local pg = group("Produce", g)
			P("Stand", V(7.0, 2.2, 3.4), W(x, 1.1, z), C(150, 108, 66), M.WoodPlanks, { parent = pg })
			local fruit = { { C(200, 30, 30), 0.5 }, { C(250, 150, 30), 0.5 }, { C(110, 180, 50), 0.4 }, { C(150, 100, 60), 0.55 }, { C(240, 220, 160), 0.5 }, { C(120, 40, 110), 0.45 } }
			for row = 0, 1 do
				for col = 0, 2 do
					local f = fruit[(row * 3 + col + math.floor(x)) % #fruit + 1]
					local bxp, bzp = x - 2.3 + col * 2.3, z - 0.8 + row * 1.6
					local tilt = CFrame.Angles(math.rad(row == 0 and 14 or -14), 0, 0)
					local bin = P("Bin", V(2.1, 0.5, 1.5), W(bxp, 2.45, bzp) * tilt, C(120, 84, 50), M.WoodPlanks, { parent = pg })
					for k = 0, 5 do
						P("Fruit", V(f[2], f[2], f[2]), bin.CFrame * CFrame.new(-0.7 + (k % 3) * 0.7, 0.35, -0.35 + math.floor(k / 3) * 0.7), f[1], M.SmoothPlastic, { parent = pg, deco = true, shape = Enum.PartType.Ball })
					end
				end
			end
			local tag = P("PriceBoard", V(1.6, 0.9, 0.08), W(x, 3.3, z - 1.75), C(24, 24, 26), M.SmoothPlastic, { parent = pg, deco = true })
			K.sign(tag, Enum.NormalId.Front, "FRESH\n99¢ / LB", C(24, 24, 26), C(255, 255, 255), { font = Enum.Font.Arcade })
		end
		produce(-1510.0, -317.4)
		produce(-1499.0, -317.4)
		-- banana stand
		P("BananaStand", V(1.6, 4.4, 1.6), W(-1493.0, 2.2, -318.0), C(150, 108, 66), M.WoodPlanks, { parent = g })
		for k = 0, 5 do
			P("Bananas", V(0.9, 0.35, 0.6), W(-1493.0 + (k % 2) * 0.4 - 0.2, 4.6 + math.floor(k / 2) * 0.4, -318.0 - 0.9) * CFrame.Angles(0, 0, math.rad(25)), C(250, 214, 60), M.SmoothPlastic, { parent = g, deco = true })
		end
		hang(-1504.5, -320.5, "FRESH PRODUCE", C(60, 140, 50), 6)

		-- frozen island: two rows of glass-door freezers back to back
		cooler(CFrame.lookAt(V(-1506.45, FY, -304), V(-1512, FY, -304)), 16, "FROZEN · ICE CREAM", K.Drinks)
		task.wait()
		cooler(CFrame.lookAt(V(-1501.55, FY, -304), V(-1496, FY, -304)), 16, "FROZEN · PIZZA · MEALS", K.Grocery)
		task.wait()

		-- open meat & dairy case along the back wall
		local mx0, mx1 = -1517.0, -1494.5
		local mxc, ML = (mx0 + mx1) / 2, mx1 - mx0
		local mz = ZB - 1.55
		P("CaseBase", V(ML, 1.2, 3.0), W(mxc, 0.6, mz), C(240, 240, 240), M.SmoothPlastic, { parent = g })
		P("CaseBack", V(ML, 8.0, 0.2), W(mxc, 4.0, ZB - 0.15), C(36, 40, 46), M.SmoothPlastic, { parent = g })
		local canopy = P("CaseCanopy", V(ML, 1.2, 2.6), W(mxc, 8.6, ZB - 1.3), C(240, 240, 240), M.SmoothPlastic, { parent = g })
		K.sign(canopy, Enum.NormalId.Front, "MEAT · DAIRY · EGGS", C(240, 240, 240), C(180, 30, 30), { font = Enum.Font.GothamBold, pad = 0.15 })
		P("CaseLight", V(ML - 0.4, 0.08, 0.3), W(mxc, 7.96, ZB - 2.3), C(230, 244, 255), M.Neon, { parent = g, deco = true })
		for _, e in { mx0, mx1 } do
			P("CaseEnd", V(0.3, 9.2, 3.0), W(e, 4.6, mz), C(240, 240, 240), M.SmoothPlastic, { parent = g })
		end
		local dairy = { { C(250, 250, 250), C(30, 90, 190) }, { C(250, 210, 60), C(40, 40, 40) }, { C(200, 60, 60), C(250, 240, 230) }, { C(230, 120, 140), C(255, 255, 255) }, { C(245, 236, 210), C(150, 90, 50) } }
		for i, y in { 1.2, 2.8, 4.4, 6.0 } do
			P("CaseShelf", V(ML - 0.4, 0.08, 2.2 - i * 0.2), W(mxc, y - 0.04, ZB - 0.3 - (2.2 - i * 0.2) / 2), C(170, 174, 180), M.Metal, { parent = g, deco = true })
			P("CaseLip", V(ML - 0.4, 0.2, 0.05), W(mxc, y - 0.1, ZB - 0.3 - (2.2 - i * 0.2)), C(250, 214, 60), M.SmoothPlastic, { parent = g, deco = true })
			local depth = 2.2 - i * 0.2
			local base = CFrame.lookAt(V(mxc, FY + y, ZB - 0.3 - depth / 2), V(mxc, FY + y, ZB - 10))
			K.fillShelf(b, base, ML - 0.6, depth, 1.2, rng, dairy, g)
		end
		hang(mxc, -292.5, "MEAT & DAIRY", C(180, 30, 30), 5)
		-- bakery rack by the corner
		P("BakeryRack", V(3.2, 6.0, 1.4), W(-1517.5, 3.0, -296.0), C(150, 108, 66), M.WoodPlanks, { parent = g })
		for i, y in { 1.0, 2.4, 3.8, 5.2 } do
			for k = 0, 2 do
				P("Bread", V(0.9, 0.55, 0.9), W(-1518.5 + k * 1.0, y + 0.3, -296.9), if (i + k) % 2 == 0 then C(214, 160, 90) else C(190, 120, 60), M.SmoothPlastic, { parent = g, deco = true })
			end
		end
		local bs = P("BakerySign", V(3.2, 0.8, 0.1), W(-1517.5, 6.5, -296.75), C(150, 90, 40), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(bs, Enum.NormalId.Front, "PAN · BAKERY", C(150, 90, 40), C(255, 240, 200))
		-- lights for the wing
		for _, pos in { V(-1510, CEIL - 0.6, -316), V(-1505, CEIL - 0.6, -298) } do
			local a = P("LightPoint", V(0.2, 0.2, 0.2), CFrame.new(pos), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
			local l = Instance.new("PointLight")
			l.Range = 26
			l.Brightness = 0.9
			l.Color = C(245, 248, 255)
			l.Shadows = false
			l.Parent = a
		end
		-- outside: a second fascia sign over the wing's windows
		local ws = P("WingSign", V(26, 3.0, 0.5), CFrame.new(-1505.85, 14.4, -324.7), C(30, 96, 58), M.SmoothPlastic, { parent = g })
		K.sign(ws, Enum.NormalId.Front, "FRESH PRODUCE · DELI · HOT FOOD", C(30, 96, 58), C(255, 255, 255), { lit = true, font = Enum.Font.GothamBlack, pad = 0.12 })
		local wl = Instance.new("SurfaceLight")
		wl.Face = Enum.NormalId.Front
		wl.Range = 10
		wl.Brightness = 1
		wl.Parent = ws
		P("CamBase", V(0.9, 0.12, 0.9), CFrame.new(-1520, CEIL - 0.06, -320), C(230, 230, 230), M.SmoothPlastic, { parent = g, deco = true })
		P("CamDome", V(0.7, 0.7, 0.7), CFrame.new(-1520, CEIL - 0.12, -320), C(20, 20, 24), M.Glass, { parent = g, deco = true, shape = Enum.PartType.Ball, Transparency = 0.15 })
	end
	task.wait()

	---------------------------------------------------------------- 9. out back: dumpster, bags, crates
	local dumpsterPos = V(-1486, FY + 2.5, -279.6)
	do
		local g = group("OutBack", model)
		-- the map's dumpster was a flat dark block: stash it and build a proper one (8 yd, green, black lids)
		local dm = store:FindFirstChild("Dumpster")
		if dm then
			K.stash(site, dm)
		end
		local dg = group("Dumpster", g)
		local GREEN, DARKG, LID = C(46, 104, 62), C(34, 78, 46), C(28, 28, 30)
		local dc = CFrame.new(-1486, 2.25, -282.9) -- floor point, back against the wall, front faces +Z (the alley)
		local function D(name, size, off, color, mat, opts)
			opts = opts or {}
			opts.parent = dg
			opts.CanQuery = false
			return P(name, size, dc * off, color, mat, opts)
		end
		D("Body", V(7.0, 3.6, 4.0), CFrame.new(0, 2.2, 0), GREEN, M.Metal)
		D("SlopeFront", V(7.0, 1.2, 0.6), CFrame.new(0, 3.75, 2.05) * CFrame.Angles(math.rad(-30), 0, 0), GREEN, M.Metal)
		D("TopRim", V(7.2, 0.25, 4.5), CFrame.new(0, 4.1, 0.15), DARKG, M.Metal)
		for _, x in { -3.0, -1.0, 1.0, 3.0 } do
			D("Rib", V(0.25, 3.4, 0.15), CFrame.new(x, 2.2, 2.05), DARKG, M.Metal, { deco = true })
		end
		for _, x in { -3.65, 3.65 } do
			D("ForkSleeve", V(0.5, 0.7, 4.2), CFrame.new(x, 2.9, 0), DARKG, M.Metal)
			D("Wheel", V(0.5, 0.7, 0.7), CFrame.new(x * 0.85, 0.35, 1.5), C(20, 20, 20), M.Rubber, { shape = Enum.PartType.Cylinder })
			D("Wheel", V(0.5, 0.7, 0.7), CFrame.new(x * 0.85, 0.35, -1.5), C(20, 20, 20), M.Rubber, { shape = Enum.PartType.Cylinder })
		end
		D("Skid", V(6.6, 0.4, 3.6), CFrame.new(0, 0.6, 0), DARKG, M.Metal)
		-- lids: one shut, one propped open against the wall with a bag poking out
		D("LidShut", V(3.4, 0.2, 4.4), CFrame.new(-1.75, 4.3, 0.2) * CFrame.Angles(math.rad(3), 0, 0), LID, M.Plastic)
		D("LidOpen", V(3.4, 0.2, 4.4), CFrame.new(1.75, 5.9, -2.1) * CFrame.Angles(math.rad(80), 0, 0), LID, M.Plastic)
		D("BagTop", V(1.6, 1.0, 1.4), CFrame.new(1.6, 4.4, 0.6) * CFrame.Angles(0, 0.4, 0.2), C(26, 26, 28), M.Plastic)
		D("BagTop", V(1.2, 0.8, 1.2), CFrame.new(2.6, 4.3, -0.4) * CFrame.Angles(0.3, 0, 0), C(40, 40, 44), M.Plastic)
		D("Rust", V(1.8, 1.4, 0.05), CFrame.new(-1.8, 1.4, 2.03), C(120, 70, 40), M.CorrodedMetal, { deco = true })
		D("Rust", V(1.2, 0.9, 0.05), CFrame.new(2.4, 2.8, 2.03), C(120, 70, 40), M.CorrodedMetal, { deco = true })
		local stencil = D("Stencil", V(4.0, 0.8, 0.03), CFrame.new(0, 2.6, 2.09), GREEN, M.SmoothPlastic, { deco = true, Transparency = 1 })
		K.sign(stencil, Enum.NormalId.Back, "DRY GARBAGE", nil, C(236, 236, 226), { font = Enum.Font.Arcade })
		local co = D("CoName", V(3.0, 0.5, 0.03), CFrame.new(0, 1.6, 2.09), GREEN, M.SmoothPlastic, { deco = true, Transparency = 1 })
		K.sign(co, Enum.NormalId.Back, "VICE BAY WASTE · 305-555-0199", nil, C(236, 236, 226), { font = Enum.Font.GothamBold })
		for i = 0, 2 do
			P("TrashBag", V(1.4, 1.2, 1.3), CFrame.new(-1481.8 + i * 0.4, 2.25 + 0.6 + (i == 2 and 0.9 or 0), -283.6 + (i % 2) * 0.9) * CFrame.Angles(0, math.rad(i * 40), 0), C(26, 26, 28), M.Plastic, { parent = g, deco = true })
		end
		P("MilkCrate", V(1.3, 1.0, 1.3), CFrame.new(-1473.2, 2.75, -284.4), C(30, 90, 170), M.Plastic, { parent = g })
		P("MilkCrate", V(1.3, 1.0, 1.3), CFrame.new(-1473.2, 3.75, -284.4) * CFrame.Angles(0, math.rad(15), 0), C(200, 40, 40), M.Plastic, { parent = g })
		P("OldPallet", V(0.4, 3.6, 3.6), CFrame.new(-1470.4, 2.25 + 1.8, -284.9) * CFrame.Angles(0, 0, math.rad(-12)), C(150, 112, 70), M.WoodPlanks, { parent = g })
	end

	for _, car in store:GetChildren() do
		if car:IsA("Model") and car.Name == "ParkedCar" then
			local p = car:GetPivot().Position
			if math.abs(p.X + 1443.6) < 2 and p.Z < -323 then
				car:SetAttribute("MTL_MovedFrom", p)
				car:PivotTo(car:GetPivot() + V(-10, 0, 0)) -- into the empty stall; keeps the door clear
			end
		end
	end

	-- tone the shell's own interior faces (inner wall panels, ceiling, floor slab): they were near-white and washed out
	for _, p in store:GetChildren() do
		if p:IsA("BasePart") and p.Material == M.SmoothPlastic then
			local q = p.Position
			local c = p:GetAttribute("MTL_ToneFrom") or p.Color
			local mx = math.max(c.R, c.G, c.B) * 255
			if mx > 200 and q.X > -1525 and q.X < -1410 and q.Z > -324.5 and q.Z < -285.5 and q.Y > 1.5 and q.Y < 16.5 then
				if p:GetAttribute("MTL_ToneFrom") == nil then
					p:SetAttribute("MTL_ToneFrom", p.Color)
				end
				p.Color = if q.Y > 15 then C(196, 194, 188) else C(190, 186, 178)
			end
			-- modern surfaces on the shell's own interior faces: tile ceiling, drywall walls
			if p:GetAttribute("MTL_ToneFrom") ~= nil and q.Y > 2.5 then
				K.dressPart(p, if q.Y > 15 then "MTL_CeilingTile" else "MTL_Drywall")
			end
		end
	end
	K.dress(model, {
		FloorTiles = "MTL_VCTTile", FloorTilesW = "MTL_VCTTile", FloorTilesX = "MTL_VCTTile", FloorStock = "MTL_Concrete",
		FrontPanelE = "MTL_Drywall", FrontPanelW = "MTL_Drywall", FrontPanelTop = "MTL_Drywall", FrontPanelWing = "MTL_Drywall", FrontPanelWingTop = "MTL_Drywall",
		PartitionA1 = "MTL_Drywall", PartitionA2 = "MTL_Drywall", PartitionA3 = "MTL_Drywall", PartitionB = "MTL_Drywall", PartitionC = "MTL_Drywall",
		CounterBody = "MTL_CounterWood", BackCounter = "MTL_CounterWood", CoffeeCounter = "MTL_CounterWood", DeliBase = "MTL_CounterWood", Desk = "MTL_CounterWood",
	})

	---------------------------------------------------------------- 10. move the job stations onto the real objects
	K.quietFootprints(V(-1460, 0, -310), 60)
	local stations = workspace:FindFirstChild("MTL_Stations")
	local Y = FY + 2.5
	local spots = {
		Supermarket = {
			TimeClock = { V(-1465.6, Y, -299.5) },
			Stockroom = { V(-1474, Y, -297) },
			Shelf1 = { endcapSpots[1] },
			Shelf2 = { endcapSpots[2] },
			Shelf3 = { endcapSpots[3] },
			Shelf4 = { endcapSpots[4] },
			Floor1 = { V(-1446.6, Y, -304), true },
			Floor2 = { V(-1431.6, Y, -300), true },
			Floor3 = { V(-1418.5, Y, -304), true },
			Bin1 = { V(-1461.3, Y, ZF + 1.3) },
			Bin2 = { V(-1472.0, Y, ZB - 1.4) },
			Dumpster = { dumpsterPos },
		},
		Cashier = {
			TimeClock = { V(-1465.6, Y, -299.5) },
			Register = { V(-1424.8, Y, -317.5) },
		},
		FirstMission = {
			Clerk = { V(-1421, Y, -318.5), true, CFrame.Angles(0, math.rad(90), 0) },
			Register = { V(-1424.8, Y, -317.5), true },
		},
	}
	local report = {}
	if stations then
		for job, list in spots do
			local f = stations:FindFirstChild(job)
			for id, s in list do
				local p = f and f:FindFirstChild(id)
				if p and p:IsA("BasePart") then
					if p:GetAttribute("MTL_OldPos") == nil then
						p:SetAttribute("MTL_OldPos", p.Position)
					end
					p.CFrame = CFrame.new(s[1]) * (s[3] or CFrame.identity)
					if p:GetAttribute("Prop") ~= nil and not s[2] then
						p:SetAttribute("Prop", "") -- a real object stands here now
					end
					table.insert(report, job .. "." .. id)
				end
			end
		end
	end
	return string.format("FoodMart InteriorV2: %d parts, %d old parts stashed, stations moved: %s", b.n, moved, table.concat(report, ", "))
end
