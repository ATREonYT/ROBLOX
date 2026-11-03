-- Vice Bay props (street furniture, vegetation, vehicles)
return function(L)
	local M, C, TAU = L.M, L.C, L.TAU

	-- ===== vegetation (realistic meshes from ServerStorage.VBAssets, cleaned of scripts) =====
	local SS = game:GetService("ServerStorage")
	local function lib() return SS:FindFirstChild("VBAssets") end
	-- clone an asset so its base sits at pos, scaled to the given height
	function L.asset(name, parent, pos, height, yaw)
		local A = lib()
		local src = A and A:FindFirstChild(name)
		if not src then return nil end
		local m = src:Clone()
		local h0 = src:GetAttribute("H") or 10
		if height then pcall(function() m:ScaleTo(height / h0) end) end
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw or L.r(0, TAU), 0))
		m.Parent = parent
		return m
	end
	local PALMS = { "PalmA", "PalmB", "PalmB", "PalmTree2", "PalmTree1" }
	-- the "hero" palm meshes were 70-90 parts each (19k parts map-wide); the 3-part coconut palm reads the same
	local HERO = { "PalmB", "PalmB", "PalmA" }
	local TREES = { "Oak" }
	local BUSHES = { "BushA", "BushB", "Bush1", "Bush2", "Bush3", "Bush4", "Bush5" }
	local LOW = { "Fern1", "Fern3", "Fern4", "Fern5", "SwampPlant1", "SwampPlant3", "Bush5" }
	L.PALMS, L.HEROPALMS, L.TREES, L.BUSHES, L.LOWPLANTS = PALMS, HERO, TREES, BUSHES, LOW
	function L.palm(parent, pos, h, kind)
		h = h or L.r(30, 44)
		local name
		if kind == "royal" then name = "PalmB"
		elseif kind == "hero" then name = L.pick(HERO); h = h * 1.25
		else name = L.pick(PALMS) end
		local m = L.asset(name, parent, pos - Vector3.new(0, 0.4, 0), h)
		if m then m.Name = "Palm" return m end
		-- fallback (no asset library yet)
		m = Instance.new("Model")
		m.Name = "Palm"
		L.Cyl(m, h, 1.6, CFrame.new(pos + Vector3.new(0, h / 2, 0)), C(150, 132, 108), M.Wood, "PalmBark")
		m.Parent = parent
		return m
	end
	-- street / median palm: one straight species, steady height, so rows read as planted (not random)
	L.STREET_PALM = "PalmB"
	function L.streetPalm(parent, pos, seed, kind, along)
		local name = (kind == "date") and "PalmTree2" or L.STREET_PALM
		local h = ((kind == "date") and 24 or 36) + ((math.floor(seed or 0) * 7) % 5) * 0.9
		local m = L.asset(name, parent, pos - Vector3.new(0, 0.4, 0), h, ((math.floor(seed or 0) * 37) % 360) * math.pi / 180)
		if m then
			m.Name = "Palm"
			-- turn a leaning trunk so every palm in the row leans the same way, along the street
			if along and kind ~= "date" then
				local cf, sz = m:GetBoundingBox()
				local lean = Vector3.new(cf.X - pos.X, 0, cf.Z - pos.Z)
				if lean.Magnitude > 0.5 then
					local want = Vector3.new(along.X, 0, along.Z).Unit
					local a0 = math.atan2(lean.X, lean.Z)
					local a1 = math.atan2(want.X, want.Z)
					local base = CFrame.new(pos)
					m:PivotTo(base * CFrame.Angles(0, a1 - a0, 0) * base:Inverse() * m:GetPivot())
				end
			end
			return m
		end
		return L.palm(parent, pos, h, "royal")
	end
	function L.tree(parent, pos, s, col)
		s = s or L.r(0.8, 1.3)
		local m = L.asset(L.pick(TREES), parent, pos - Vector3.new(0, 0.3, 0), 26 * s)
		if m then m.Name = "Tree" return m end
		m = Instance.new("Model")
		m.Name = "Tree"
		L.Cyl(m, 9 * s, 1.5 * s, CFrame.new(pos + Vector3.new(0, 4.5 * s, 0)), C(96, 80, 64), M.Wood)
		L.D(m, Vector3.new(15 * s, 10 * s, 13 * s), CFrame.new(pos + Vector3.new(0, 13 * s, 0)), col or C(70, 100, 50), M.LeafyGrass, nil, { Shape = Enum.PartType.Ball })
		m.Parent = parent
		return m
	end
	function L.bush(parent, pos, s, col)
		s = s or L.r(3, 6)
		local m = L.asset(L.pick(BUSHES), parent, pos - Vector3.new(0, 0.3, 0), s * 1.1)
		if m then m.Name = "Bush" return m end
		return L.D(parent, Vector3.new(s * 1.3, s * 0.75, s), CFrame.new(pos + Vector3.new(0, s * 0.28, 0)), col or C(60, 92, 42), M.LeafyGrass, nil, { Shape = Enum.PartType.Ball })
	end
	function L.plant(parent, pos, s)
		local m = L.asset(L.pick(LOW), parent, pos - Vector3.new(0, 0.2, 0), s or L.r(2.5, 5))
		if m then m.Name = "Plant" end
		return m
	end
	function L.hedge(parent, cf, len, h, w)
		return L.B(parent, cf, 0, 0, 0, w or 3, h or 4, len, C(58, 88, 42), M.LeafyGrass)
	end
	function L.weeds(parent, pos)
		if L.plant(parent, pos, L.r(1.6, 3)) then return end
		L.D(parent, Vector3.new(L.r(1, 2.2), L.r(0.6, 1.3), L.r(0.8, 1.6)), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, L.r(0, TAU), 0), L.pick({ C(92, 108, 50), C(118, 120, 62), C(80, 98, 46) }), M.Grass, nil, { Shape = Enum.PartType.Ball })
	end

	-- ===== street furniture =====
	-- cobra-head streetlight. cf at sidewalk level, -Z points over the road
	function L.streetlight(parent, cf, modern, shoebox)
		local m = Instance.new("Model")
		m.Name = "StreetLight"
		if shoebox then
			-- Florida arterial / parking-lot style: tall square white pole, twin flat shoebox heads on a short arm
			local col = C(222, 222, 218)
			L.Cyl(m, 1.4, 1.6, cf * CFrame.new(0, 0.7, 0), C(196, 194, 188), M.Concrete)
			L.D(m, Vector3.new(0.7, 26, 0.7), cf * CFrame.new(0, 13.4, 0), col, M.Metal)
			L.D(m, Vector3.new(0.35, 0.35, 5.2), cf * CFrame.new(0, 26.2, 0), col, M.Metal)
			for sd = -1, 1, 2 do
				L.D(m, Vector3.new(1.8, 0.7, 2.6), cf * CFrame.new(0, 26.1, sd * 2.9), C(120, 122, 124), M.Metal)
				L.D(m, Vector3.new(1.4, 0.06, 2.1), cf * CFrame.new(0, 25.72, sd * 2.9), C(255, 236, 196), M.Neon)
			end
			m.Parent = parent
			return m
		end
		local col = modern and C(56, 58, 62) or C(140, 140, 136)
		L.Cyl(m, 26, 0.75, cf * CFrame.new(0, 13, 0), col, M.Metal)
		L.D(m, Vector3.new(0.45, 0.45, 8), cf * CFrame.new(0, 25.8, -3.8), col, M.Metal)
		L.D(m, Vector3.new(1.5, 0.5, 3.2), cf * CFrame.new(0, 25.6, -8.2), modern and C(255, 244, 225) or C(255, 214, 160), M.Neon)
		m.Parent = parent
		return m
	end
	-- mast-arm signal: cf at the corner, -Z along the arm over the approach lanes
	function L.trafficLight(parent, cf, armLen, heads, blade)
		-- mast arm with 3-lens heads (backplates, visors, lit lamp), street-name blade on the arm
		armLen = armLen or 18
		heads = heads or math.clamp(math.floor(armLen / 9), 1, 3)
		local m = Instance.new("Model")
		m.Name = "TrafficLight"
		local col = C(70, 74, 78)
		L.Cyl(m, 22, 1.1, cf * CFrame.new(0, 11, 0), col, M.Metal)
		L.Cyl(m, 1.2, 1.8, cf * CFrame.new(0, 0.6, 0), col, M.Metal)
		L.D(m, Vector3.new(0.55, 0.55, armLen), cf * CFrame.new(0, 21.2, -armLen / 2), col, M.Metal)
		L.D(m, Vector3.new(0.25, 0.25, armLen * 0.45), cf * CFrame.new(0, 21.2 - armLen * 0.12, -armLen * 0.2) * CFrame.Angles(math.rad(-24), 0, 0), col, M.Metal)
		local state = L.pick({ 1, 1, 3, 2 }) -- 1 red, 2 amber, 3 green
		local LENS = { C(255, 50, 40), C(255, 170, 30), C(60, 255, 140) }
		for k = 1, heads do
			local z = -armLen + 1.5 + (k - 1) * (armLen - 6) / math.max(1, heads)
			local hc = cf * CFrame.new(0, 18.6, z) * CFrame.Angles(0, math.pi / 2, 0)
			L.D(m, Vector3.new(1.4, 4.2, 1.2), hc, C(28, 30, 28), M.Metal)
			L.D(m, Vector3.new(2.2, 5, 0.12), hc * CFrame.new(0, 0, 0.62), C(18, 18, 18), M.SmoothPlastic)
			-- lit lens + one dark strip for the two unlit lenses (keeps the part count low)
			local ly = 1.35 - (state - 1) * 1.35
			L.D(m, Vector3.new(0.95, 0.95, 0.08), hc * CFrame.new(0, ly, -0.62), LENS[state], M.Neon)
			L.D(m, Vector3.new(0.9, 3.6, 0.06), hc * CFrame.new(0, 0, -0.61), C(40, 42, 40), M.Glass)
		end
		if blade and blade ~= "" then
			local b = L.D(m, Vector3.new(0.1, 1.3, 8), cf * CFrame.new(0, 22.6, -armLen * 0.45), C(18, 104, 62), M.SmoothPlastic)
			for _, f in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
				L.text(b, f, string.upper(blade), { font = Enum.Font.Highway, color = Color3.new(1, 1, 1), size = UDim2.fromScale(0.94, 0.78), pos = UDim2.fromScale(0.03, 0.11), pps = 24, dist = 220 })
			end
		end
		m.Parent = parent
		return m
	end
	function L.trashcan(parent, pos)
		local m = L.model(parent, "TrashCan")
		local c = L.pick({ C(36, 40, 38), C(34, 52, 40), C(40, 40, 44) })
		L.Cyl(m, 3.2, 2.1, CFrame.new(pos + Vector3.new(0, 1.6, 0)), c, M.Metal, nil, { CanCollide = true })
		L.Cyl(m, 0.35, 2.35, CFrame.new(pos + Vector3.new(0, 3.3, 0)), L.shade(c, 0.8), M.Metal)
		L.Cyl(m, 0.25, 2.2, CFrame.new(pos + Vector3.new(0, 0.6, 0)), L.shade(c, 0.7), M.Metal)
		return m
	end
	function L.stopSign(parent, cf)
		-- regular octagon = union of four w x 0.414w bands at 0/45/90/135 degrees; white rim behind
		local m = Instance.new("Model")
		m.Name = "StopSign"
		L.Cyl(m, 9, 0.22, cf * CFrame.new(0, 4.5, 0.05), C(150, 152, 154), M.Metal)
		local face
		for k, spec in ipairs({ { 2.5, C(236, 236, 232), 0.12 }, { 2.25, C(178, 22, 26), 0 } }) do
			local w = spec[1]
			for r = 0, 3 do
				local p = L.D(m, Vector3.new(w, w * 0.4142, 0.06), cf * CFrame.new(0, 8.6, -0.12 - k * 0.04) * CFrame.Angles(0, 0, r * math.pi / 4), spec[2], M.SmoothPlastic)
				if k == 2 and r == 0 then face = p end
			end
		end
		local t = L.D(m, Vector3.new(2.1, 0.8, 0.02), cf * CFrame.new(0, 8.6, -0.25), C(178, 22, 26), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(t, Enum.NormalId.Front, "STOP", { font = Enum.Font.GothamBold, color = Color3.new(1, 1, 1), size = UDim2.fromScale(1, 1), pos = UDim2.fromScale(0, 0), pps = 40, dist = 120 })
		m.Parent = parent
		return m
	end
	function L.hydrant(parent, pos)
		local m = L.model(parent, "Hydrant")
		local c = L.pick({ C(214, 196, 60), C(190, 70, 40), C(220, 220, 214) })
		L.Cyl(m, 2.3, 1, CFrame.new(pos + Vector3.new(0, 1.15, 0)), c, M.Metal, nil, { CanCollide = true })
		L.D(m, Vector3.new(1.7, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 1.5, 0)), c, M.Metal)
		return m
	end
	function L.trashBags(parent, pos)
		for _ = 1, L.ri(2, 4) do
			local s = L.r(1.6, 2.3)
			L.D(parent, Vector3.new(s, s * 0.85, s), CFrame.new(pos + Vector3.new(L.r(-1.4, 1.4), s * 0.4, L.r(-1.4, 1.4))), L.pick({ C(24, 24, 26), C(30, 30, 34), C(210, 210, 205) }), M.Plastic, nil, { Shape = Enum.PartType.Ball })
		end
	end
	function L.dumpster(parent, cf)
		local m = L.model(parent, "Dumpster")
		L.B(m, cf, 0, 0.5, 0, 7, 4.2, 4, L.pick({ C(46, 84, 54), C(34, 64, 110), C(70, 70, 70) }), M.CorrodedMetal, "DumpsterGreenRust")
		L.B(m, cf, 0, 4.7, 0.2, 7.2, 0.35, 4.4, C(28, 28, 30), M.Plastic)
		for _, x in ipairs({ -3, 3 }) do L.BD(m, cf, x, 0, 0, 0.6, 0.5, 3.6, C(30, 30, 30), M.Metal) end
		return m
	end
	function L.bench(parent, cf)
		local m = L.model(parent, "Bench")
		L.B(m, cf, 0, 1.6, 0, 6, 0.35, 1.8, C(120, 86, 56), M.Wood)
		L.BD(m, cf, 0, 2.2, 0.8, 6, 1.6, 0.25, C(120, 86, 56), M.Wood)
		for _, x in ipairs({ -2.6, 2.6 }) do L.BD(m, cf, x, 0, 0, 0.35, 1.6, 1.6, C(36, 36, 36), M.Metal) end
		return m
	end
	function L.busStop(parent, cf, name)
		local m = L.model(parent, "BusStop")
		local fc = C(70, 74, 78)
		for _, x in ipairs({ -6, 6 }) do L.B(m, cf, x, 0, 1.8, 0.4, 8.6, 0.4, fc, M.Metal) end
		L.B(m, cf, 0, 8.6, 0.6, 13.4, 0.4, 5, fc, M.Metal)
		L.B(m, cf, 0, 1, 2.2, 12, 7.2, 0.15, C(170, 200, 210), M.Glass, nil, { Transparency = 0.6 })
		local ad = L.BD(m, cf, 6.3, 1, 0.6, 0.3, 6.5, 4.2, C(240, 240, 240), M.SmoothPlastic)
		L.text(ad, Enum.NormalId.Right, "VBX\nINVEST IN\nVICE BAY", { font = Enum.Font.GothamBlack, color = C(30, 30, 40), bg = C(250, 214, 90), pps = 20 })
		L.bench(m, cf * CFrame.new(0, 0, 1))
		return m
	end
	-- fences: kind "chain", "wall", "wood", "iron"
	function L.fence(parent, a, b, h, kind)
		h = h or 7
		local d = (b - a)
		local len = d.Magnitude
		if len < 1 then return end
		local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
		local m = L.model(parent, "Fence")
		if kind == "wall" then
			L.P(m, Vector3.new(1, h, len), cf * CFrame.new(0, h / 2, 0), C(196, 188, 174), M.Concrete, "HoodCinderBlock")
			L.D(m, Vector3.new(1.3, 0.35, len), cf * CFrame.new(0, h + 0.17, 0), C(176, 170, 160), M.Concrete)
		elseif kind == "wood" then
			L.P(m, Vector3.new(0.35, h, len), cf * CFrame.new(0, h / 2, 0), C(132, 104, 76), M.WoodPlanks, "FenceWoodRaw")
		else
			local iron = kind == "iron"
			local col = iron and C(28, 28, 28) or C(150, 152, 150)
			L.P(m, Vector3.new(0.1, h - 0.4, len), cf * CFrame.new(0, h / 2, 0), col, iron and M.Metal or M.DiamondPlate, nil, { Transparency = iron and 0.6 or 0.68, CastShadow = false })
			L.D(m, Vector3.new(0.28, 0.28, len), cf * CFrame.new(0, h, 0), col, M.Metal)
			local n = math.max(1, math.floor(len / 10))
			for k = 0, n do
				L.D(m, Vector3.new(0.32, h, 0.32), cf * CFrame.new(0, h / 2, -len / 2 + k * len / n), col, M.Metal)
			end
		end
		return m
	end

	-- ===== vehicles =====
	L.CAR_COLS = { C(28, 28, 30), C(28, 28, 30), C(214, 214, 216), C(214, 214, 216), C(150, 152, 156), C(150, 152, 156), C(92, 94, 98), C(240, 240, 238), C(120, 18, 24), C(26, 46, 96), C(60, 44, 34) }
	function L.car(parent, cf, color, style)
		-- cf at ground, facing -Z. Uses the realistic sedan mesh (badge-free lite copy) when it is in the asset library.
		color = color or L.pick(L.CAR_COLS)
		local A = game:GetService("ServerStorage"):FindFirstChild("VBAssets")
		local src = A and A:FindFirstChild("SedanLite")
		if src and style ~= "box" then
			local mm = src:Clone()
			mm.Name = "ParkedCar"
			for _, d in ipairs(mm:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Color" then d.Color = color end
			end
			pcall(function() mm:ScaleTo(19 / (src:GetAttribute("L") or 21)) end) -- same scale as the game's drivable cars (about 22 long, 10 wide)
			mm:PivotTo(cf)
			mm.Parent = parent
			return mm
		end
		local m = Instance.new("Model")
		m.Name = "ParkedCar"
		color = color or L.pick(L.CAR_COLS)
		style = style or L.pick({ "sedan", "sedan", "suv", "pickup", "sedan" })
		local len, wid = 15, 6.4
		local bodyH, y0, cabL, cabH, cz = 2.3, 1.1, 7.2, 2.1, 0.9
		if style == "suv" then bodyH, cabL, cabH, cz = 3, 9.6, 2.4, 1.4; len = 15.6 end
		if style == "pickup" then bodyH, cabL, cabH, cz = 3, 5.6, 2.3, -1 ; len = 17 end
		if style == "sports" then bodyH, y0, cabL, cabH, cz = 1.8, 0.8, 5.6, 1.5, 0.8 end
		L.P(m, Vector3.new(wid, bodyH, len), cf * CFrame.new(0, y0 + bodyH / 2, 0), color, M.SmoothPlastic, nil, { Reflectance = 0.08 })
		L.D(m, Vector3.new(wid - 0.5, cabH, cabL), cf * CFrame.new(0, y0 + bodyH + cabH / 2, cz), C(24, 28, 34), M.Glass, nil, { Reflectance = 0.2 })
		L.D(m, Vector3.new(wid - 0.4, 0.25, cabL - 1.4), cf * CFrame.new(0, y0 + bodyH + cabH + 0.12, cz), color, M.SmoothPlastic)
		if style == "pickup" then
			L.D(m, Vector3.new(wid - 0.8, 0.3, 6.4), cf * CFrame.new(0, y0 + bodyH + 0.05, 4.6), C(30, 30, 30), M.Plastic)
		end
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				L.D(m, Vector3.new(1.1, 2.7, 2.7), cf * CFrame.new(sx * (wid / 2 - 0.45), 1.35, sz * (len / 2 - 2.8)), C(20, 20, 20), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
				L.D(m, Vector3.new(1.15, 1.4, 1.4), cf * CFrame.new(sx * (wid / 2 - 0.42), 1.35, sz * (len / 2 - 2.8)), C(170, 170, 172), M.Metal, nil, { Shape = Enum.PartType.Cylinder })
			end
		end
		L.D(m, Vector3.new(wid - 1, 0.5, 0.15), cf * CFrame.new(0, y0 + bodyH - 0.55, -len / 2 - 0.05), C(255, 250, 235), M.Neon)
		L.D(m, Vector3.new(wid - 1, 0.5, 0.15), cf * CFrame.new(0, y0 + bodyH - 0.55, len / 2 + 0.05), C(170, 16, 16), M.Neon)
		L.D(m, Vector3.new(wid + 0.1, 0.5, 0.6), cf * CFrame.new(0, y0 + 0.3, -len / 2), C(40, 40, 42), M.Plastic)
		L.D(m, Vector3.new(wid + 0.1, 0.5, 0.6), cf * CFrame.new(0, y0 + 0.3, len / 2), C(40, 40, 42), M.Plastic)
		m.Parent = parent
		return m
	end
end
