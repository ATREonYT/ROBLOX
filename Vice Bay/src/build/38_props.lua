-- 38 Prop kit: turns vetted Creator Store picks + AI-generated meshes into a clean prop library
-- (ServerStorage.VBProps/<Category>/<Name>) and provides the shelf / fridge filler used in the interiors.
-- Rules (Prop Art List): anchored, CanTouch off, CanQuery off on non-floor props, CanCollide off on small stuff,
-- CastShadow off on small items, MeshParts CollisionFidelity = Box, no scripts, no real brands, interior colours <= ~200.
return function(L, mode)
	local SS = game:GetService("ServerStorage")
	local CAND = SS:FindFirstChild("VBPropCandidates")
	local LIB = SS:FindFirstChild("VBProps") or Instance.new("Folder")
	LIB.Name = "VBProps"
	LIB.Parent = SS

	-- picks: { category, name, candidate model name, target size (largest dimension, studs) or nil to keep }
	local PICKS = {
		{ "Store", "ShelfBay", "Shelf_94350431635711", nil },
		{ "Store", "Register", "Register_108737011917105", 1.6 },
		{ "Store", "DrinksFridge", "Fridge_123829768880176", 9 },
		{ "Kitchen", "Grill", "Grill_14144434425", nil },
		{ "Kitchen", "Fryer", "Fryer_2725730657", nil },
		{ "Garage", "CarLift", "CarLift_89290978342285", nil },
		{ "Garage", "ToolChest", "ToolChest_9675076041", 4 },
		{ "Garage", "TireStack", "TireStack_9504148189", 3.2 },
		{ "Garage", "Jack", "Jack_12931798761", 3 },
		{ "Depot", "Pallet", "Pallet_10627539754", nil },
		{ "Depot", "Forklift", "Forklift_12635164828", nil },
		{ "Depot", "PalletJack", "PalletJack_94188768861634", nil },
		{ "Depot", "Container", "Container_77003885266485", nil },
		{ "Jobs", "MopBucket", "MopBucket_2414950007", 3 },
		{ "Jobs", "WetFloorSign", "WetSign_4950163226", 2.2 },
		{ "Jobs", "CardboardBox", "Box_102880290032203", 1.6 },
		{ "Street", "Hydrant", "Hydrant_439585165", 2.6 },
		{ "Street", "Payphone", "Payphone_4900193185", nil },
	}

	local function clean(m, small)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
				d:Destroy()
			end
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
				d.CanQuery = false
				if small or d.Size.Magnitude < 4 then
					d.CanCollide = false
					d.CastShadow = false
				end
				if d:IsA("MeshPart") then pcall(function() d.CollisionFidelity = Enum.CollisionFidelity.Box end) end
			end
		end
	end
	local function maxDim(m)
		local _, s = m:GetBoundingBox()
		return math.max(s.X, s.Y, s.Z)
	end
	local function rootAtFloor(m)
		-- pivot = centre of the bottom face, so props drop straight onto a floor / shelf
		local cf, s = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, s.Y / 2, 0))
	end

	local made = {}
	if CAND then
		for _, p in ipairs(PICKS) do
			local src = CAND:FindFirstChild(p[3])
			if src then
				local cat = LIB:FindFirstChild(p[1]) or Instance.new("Folder")
				cat.Name = p[1]
				cat.Parent = LIB
				local old = cat:FindFirstChild(p[2])
				if old then old:Destroy() end
				local m = src:Clone()
				m.Name = p[2]
				clean(m, (p[4] or 99) < 4)
				if p[4] then pcall(function() m:ScaleTo(m:GetScale() * p[4] / maxDim(m)) end) end
				rootAtFloor(m)
				m:SetAttribute("Source", p[3])
				m.Parent = cat
				table.insert(made, p[1] .. "/" .. p[2])
			end
		end
	end

	-- AI-generated meshes dropped into Workspace by generate_mesh: move any named "Gen_*" into VBProps/Products
	local prod = LIB:FindFirstChild("Products") or Instance.new("Folder")
	prod.Name = "Products"
	prod.Parent = LIB
	for _, d in ipairs(workspace:GetChildren()) do
		if d.Name:match("^Gen_") then
			clean(d, true)
			if d:IsA("Model") then rootAtFloor(d) end
			d.Name = d.Name:gsub("^Gen_", "")
			d.Parent = prod
			table.insert(made, "Products/" .. d.Name)
		end
	end

	-- ===== shelf filler (placement rules from the prop list) =====
	-- shelfCF: front-centre of one shelf level, -Z = towards the customer; w = usable width, depth = usable depth
	function L.fillShelfRow(par, shelfCF, w, depth, products, rng)
		rng = rng or Random.new()
		local x = -w / 2
		local brand, left = nil, 0
		while x < w / 2 do
			if left <= 0 then
				brand = products[rng:NextInteger(1, #products)]
				left = rng:NextInteger(3, 6)
			end
			local _, s = brand:GetBoundingBox()
			if x + s.X > w / 2 then break end
			if rng:NextNumber() > rng:NextNumber() * 0.1 + 0.05 then -- 5-15% empty slots
				local copies = math.max(1, math.floor(depth / (s.Z + 0.05)))
				local pull = (rng:NextInteger(1, 4) == 1) and -0.25 or 0 -- every 3rd-5th item pulled forward
				for k = 0, copies - 1 do
					local it = brand:Clone()
					it:PivotTo(shelfCF * CFrame.new(x + s.X / 2, 0.01, -depth / 2 + s.Z / 2 + k * (s.Z + 0.05) + pull) * CFrame.Angles(0, math.rad(rng:NextNumber(-5, 5)), 0))
					it.Parent = par
				end
			end
			x += s.X + 0.06
			left -= 1
		end
	end

	return "VBProps: " .. #made .. " props\n" .. table.concat(made, "\n")
end
