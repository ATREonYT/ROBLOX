-- 03 Liberty Heights (hood): landmarks, spawn, then fill every street with worn Miami hood lots
return function(L)
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	local VB = L.folder(workspace, "ViceBay")
	local LM = L.folder(L.folder(VB, "Landmarks"), "Hood")
	local B = L.folder(L.folder(VB, "Buildings"), "Hood")
	LM:ClearAllChildren()
	B:ClearAllChildren()
	L.seed(7)
	local G = L.G
	local function at(x, z, yaw) return CFrame.new(x, G, z) * CFrame.Angles(0, yaw or 0, 0) end
	-- yaw so that -Z (the front) faces the given street direction: front toward north (-Z) = 0, south = pi, east = -pi/2, west = pi/2
	local N, S, E, W = 0, math.pi, -math.pi / 2, math.pi / 2

	-- ground: the hood is dirt yards + patchy lawn, not a concrete slab
	do
		local T = workspace.Terrain
		local x0, x1, z0, z1 = -1800, -925, -1140, 940
		local step = 256
		for x = x0, x1 - 1, step do
			for z = z0, z1 - 1, step do
				local xe, ze = math.min(x1, x + step), math.min(z1, z + step)
				T:ReplaceMaterial(Region3.new(Vector3.new(x, -8, z), Vector3.new(xe, 4, ze)):ExpandToGrid(4), 4, L.M.Concrete, L.M.Ground)
			end
			task.wait()
		end
		local rng = Random.new(11)
		for _ = 1, 260 do
			local px, pz = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
			local hw, hd = rng:NextNumber(6, 16), rng:NextNumber(6, 16)
			T:ReplaceMaterial(Region3.new(Vector3.new(px - hw, -8, pz - hd), Vector3.new(px + hw, 4, pz + hd)):ExpandToGrid(4), 4, L.M.Ground, L.M.LeafyGrass)
		end
	end

	-- ===== landmarks (placed first so the filler builds around them) =====
	-- spawn: Liberty Food Mart, block between Flagler (z -410) / NW 58 St and NW 15 Ave / Liberty Blvd
	local _, lotCf = L.foodMart(LM, at(-1442, -336, N), 84, 86, { sign = "LIBERTY FOOD MART" })
	local sp = workspace:FindFirstChildOfClass("SpawnLocation") or Instance.new("SpawnLocation")
	sp.Name = "HoodSpawn"
	sp.Anchored = true
	sp.Size = Vector3.new(10, 0.4, 10)
	sp.CFrame = CFrame.new(-1432, G + 0.25, -368)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Duration = 0
	sp.Parent = workspace
	L.poi(Vector3.new(-1442, G, -312), "Shop", "Liberty Food Mart", { Sells = "Food,Drinks" })

	-- gas station: Liberty Blvd & North Ave (NE corner)
	L.gas(LM, at(-1297, -892, S), 84, 64, { sign = "SUNSHINE GAS" })
	L.poi(Vector3.new(-1297, G, -880), "Gas", "Sunshine Gas")
	-- used car lot on Liberty Blvd
	L.carLot(LM, at(-1301, -621, W), 86, 80, { sign = "LUCKY'S USED AUTOS" })
	L.poi(Vector3.new(-1312, G, -620), "Dealer", "Lucky's Used Autos", { Tier = 1, PriceMin = 2000, PriceMax = 9000 })
	-- Liberty Square projects
	L.projects(LM, at(-1297, -1046, S), 84, 80)
	L.poi(Vector3.new(-1300, G, -1000), "Property", "Liberty Square Unit", { Price = 1200, Tier = 0 })
	-- Liberty Park: fenced court + patchy grass + benches
	do
		local pc = at(-1580, -206, N)
		local park = L.model(LM, "LibertyPark")
		L.BD(park, pc, 0, 0.03, 0, 90, 0.12, 76, Color3.fromRGB(104, 118, 70), L.M.Grass)
		L.BD(park, pc, 22, 0.05, 0, 30, 0.12, 76, Color3.fromRGB(140, 120, 90), L.M.Ground, "ParkDirt")
		L.court(park, pc * CFrame.new(-18, 0, 0), 54, 74)
		for k = -1, 1 do L.bench(park, pc * CFrame.new(30, 0, k * 26) * CFrame.Angles(0, -math.pi / 2, 0)) end
		L.tree(park, (pc * CFrame.new(40, 0, -36)).Position, 1.2)
		L.tree(park, (pc * CFrame.new(38, 0, 34)).Position, 1)
		L.palm(park, (pc * CFrame.new(16, 0, 40)).Position)
		L.poi(Vector3.new(-1580, G, -200), "Park", "Liberty Park")
	end
	-- Burger Shack (job) on Flagler
	L.shop(LM, at(-1442, -467, S), 82, 54, { units = 2, signs = { "BURGER SHACK", "WINGS & FISH" }, floors = 2, interior = true, menu = "BURGERS  •  WINGS  •  FISH  •  FRIES", billboard = true })
	L.poi(Vector3.new(-1442, G, -445), "Job", "Burger Shack", { Job = "Cook", Pay = 60 })
	-- Westside Auto Repair (job)
	L.bays(LM, at(-1015, -472, S), 76, 64, { sign = "WESTSIDE AUTO REPAIR", interior = true })
	L.poi(Vector3.new(-1015, G, -445), "Job", "Westside Auto Repair", { Job = "Mechanic", Pay = 75 })
	-- Starter crib (first purchasable home)
	L.house(LM, at(-1442, -190, S), 44, 44, { name = "StarterCrib", rundown = true, abandoned = false })
	L.poi(Vector3.new(-1442, G, -165), "Property", "Starter Crib", { Price = 2500, Tier = 1 })
	-- storefront church
	L.church(LM, at(-1160, 342, N), 56, 62, { sign = "NEW HOPE BAPTIST CHURCH" })


	-- THE ENDS entrance wall (east side of Liberty Blvd, just south of the river)
	do
		local cf = CFrame.new(-1326, G, 330) * CFrame.Angles(0, math.pi / 2, 0) -- just off the widened Liberty Blvd sidewalk
		local wall = L.B(LM, cf, 0, 0, 0, 60, 14, 2, Color3.fromRGB(196, 186, 170), L.M.Concrete, "HoodConcreteDirty")
		wall.Name = "TheEndsWall"
		L.text(wall, Enum.NormalId.Front, "THE ENDS", { font = Enum.Font.Bangers, color = Color3.fromRGB(255, 210, 60), stroke = 0, size = UDim2.fromScale(0.9, 0.7), pos = UDim2.fromScale(0.05, 0.15), pps = 8, dist = 400, light = 1 })
	end

	-- reserve landmark lots
	L.footprint(LM, at(-1442, -336, N), 84, 86)
	L.footprint(LM, at(-1297, -892, S), 84, 64)
	L.footprint(LM, at(-1301, -621, W), 86, 80)
	L.footprint(LM, at(-1297, -1046, S), 84, 80)
	L.footprint(LM, at(-1442, -467, S), 82, 54)
	L.footprint(LM, at(-1015, -472, S), 76, 64)
	L.footprint(LM, at(-1442, -190, S), 44, 44)
	L.footprint(LM, at(-1160, 342, N), 56, 62)
	L.footprint(LM, at(-1580, -206, N), 90, 76)

	-- ===== fill =====
	local function inHood(x, z) return x > -1800 and x < -925 and z > -1140 and z < 940 end
	local hoodNames = {}
	local built = L.fill(B, net, function(x, z, st, side, e)
		if not inHood(x, z) then return nil end
		local arterial = (e[3] >= 50)
		local r = L.rng:NextNumber()
		if arterial then
			-- main roads: 2-3 storey shop rows, 3-4 storey walk-ups and 4-5 storey mid-rises (taller street walls)
			if r < 0.42 then return { kind = "shop", w = L.r(44, 70), d = L.r(48, 58), opts = { rundown = true, floors = L.pick({ 1, 2, 2, 2, 3, 3 }) } } end
			if r < 0.52 then return { kind = "bays", w = L.r(54, 70), d = 56 } end
			if r < 0.66 then return { kind = "walkup", w = L.r(56, 76), d = 54, opts = { rundown = true } } end
			if r < 0.82 then return { kind = "midrise", w = L.r(56, 76), d = 58 } end
			if r < 0.86 then return { kind = "church", w = 46, d = 56 } end
			if r < 0.91 then return { kind = "emptyLot", w = L.r(34, 50), d = 50 } end
			return { kind = "house", w = L.r(42, 50), d = 50, opts = { twoChance = 0.6 } }
		elseif z > 240 then
			-- THE ENDS: the roughest blocks (south of the river, along the canal and port)
			if r < 0.44 then return { kind = "house", w = L.r(40, 50), d = L.r(44, 48), opts = { abandoned = L.chance(0.3), carChance = 0.3, tagChance = 0.45, twoChance = 0.3 }, gap = L.r(0, 3) } end
			if r < 0.62 then return { kind = "walkup", w = L.r(54, 70), d = 52, opts = { rundown = true } } end
			if r < 0.7 then return { kind = "midrise", w = L.r(54, 66), d = 56 } end
			if r < 0.82 then return { kind = "emptyLot", w = L.r(30, 46), d = 48 } end
			if r < 0.88 then return { kind = "court", w = 56, d = 80 } end
			return { kind = "shop", w = L.r(36, 50), d = 48, opts = { rundown = true, floors = L.pick({ 1, 2, 2 }) } }
		else
			if r < 0.56 then return { kind = "house", w = L.r(40, 50), d = L.r(44, 48), gap = L.r(0, 3), opts = { twoChance = 0.4 } } end
			if r < 0.72 then return { kind = "walkup", w = L.r(54, 70), d = 52, opts = { rundown = true } } end
			if r < 0.78 then return { kind = "midrise", w = L.r(54, 66), d = 56 } end
			if r < 0.86 then return { kind = "emptyLot", w = L.r(30, 46), d = 48 } end
			if r < 0.94 then return { kind = "shop", w = L.r(36, 50), d = 48, opts = { rundown = true, floors = L.pick({ 1, 2, 2, 3 }) } } end
			if r < 0.97 then return { kind = "court", w = 56, d = 80 } end
			return { kind = "church", w = 44, d = 52 }
		end
	end)
	-- The Ends: burnt-out cars parked along the curbs, a big wall piece at the entrance
	do
		local E = L.model(LM, "TheEnds")
		local cnt = 0
		for _, e in ipairs(net.edges) do
			local A, B2 = net.nodes[e[1]], net.nodes[e[2]]
			local mz = (A[2] + B2[2]) / 2
			local mx = (A[1] + B2[1]) / 2
			if mz > 300 and mz < 940 and mx > -1790 and mx < -935 and e[3] < 30 and L.chance(0.35) then
				local a = Vector3.new(A[1], G, A[2])
				local b = Vector3.new(B2[1], G, B2[2])
				local cf = CFrame.lookAt(a, b) * CFrame.new(e[3] / 2 - 3.6, 0.3, -(b - a).Magnitude * L.r(0.3, 0.7))
				local car = L.car(E, cf, Color3.fromRGB(34, 30, 28), "sedan")
				for _, d in ipairs(car:GetDescendants()) do
					if d:IsA("BasePart") then
						if d.Material == L.M.Neon or d.Material == L.M.Glass or d.Name == "Glass" then d:Destroy()
						elseif d.Name == "Color" then d.Material = L.M.CorrodedMetal
						elseif d.Name == "Rim" then d.Color = Color3.fromRGB(110, 70, 44) d.Material = L.M.CorrodedMetal end
					end
				end
				car:PivotTo(car:GetPivot() * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(L.r(-4, 4))))
				car.Name = "BurntCar"
				cnt += 1
			end
		end
	end
	local parts = 0
	for _, d in ipairs(B:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("hood lots %d, parts %d", built, parts)
end
