-- 09 Wynwood / Midtown (north of the river, x -720..300, outside the park and SoHo):
-- mural warehouses, galleries, lofts, a food truck park, the Wynwood Walls,
-- and MAIN STREET (NW 2 Ave): a continuous walkable shopping street with outdoor dining and string lights.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	local VB = L.folder(workspace, "ViceBay")
	local LM = L.folder(L.folder(VB, "Landmarks"), "Wynwood")
	local B = L.folder(L.folder(VB, "Buildings"), "Wynwood")
	LM:ClearAllChildren()
	B:ClearAllChildren()
	L.seed(2402)
	local function at(x, z, yaw) return CFrame.new(x, G, z) * CFrame.Angles(0, yaw or 0, 0) end
	local MURALS = { "WYNWOOD", "DREAM BIG", "305 FOREVER", "STAY WILD", "LOVE MIAMI", "COLOR CITY", "VICE BAY", "ART IS LIFE", "SOL", "RISE UP" }
	local MAIN_X = -240

	-- ===== Wynwood Walls (open-air mural park), block between NW 3 Ave / NW 2 Ave and NW 26 / NW 22 St =====
	do
		local c = at(-320, -484)
		local ww = L.model(LM, "WynwoodWalls")
		L.BD(ww, c, 0, 0.03, 0, 100, 0.2, 80, C(186, 180, 170), M.Concrete, "ConcretePlain")
		for k = 0, 5 do
			local x = -45 + k * 18
			local wall = L.P(ww, Vector3.new(14, 18, 1.2), c * CFrame.new(x, 9, (k % 2 == 0) and -20 or 18) * CFrame.Angles(0, (k % 3 - 1) * 0.3, 0), C(236, 236, 232), M.Concrete, "ConcretePlain")
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				L.text(wall, face, L.pick(MURALS), { font = L.pick({ Enum.Font.Bangers, Enum.Font.FredokaOne, Enum.Font.PermanentMarker }), color = L.pick(L.TAGCOLORS), stroke = 0, bg = L.pick({ C(30, 60, 140), C(220, 60, 120), C(250, 190, 40), C(40, 160, 140), C(120, 60, 200), C(240, 110, 40) }), pps = 8, dist = 400, light = 1 })
			end
		end
		for k = 0, 3 do L.bench(ww, c * CFrame.new(-30 + k * 20, 0, 0)) end
		for k = 0, 4 do L.palm(ww, (c * CFrame.new(-44 + k * 22, 0, 34)).Position, L.r(26, 34)) end
		L.footprint(LM, c, 100, 80)
		L.poi(Vector3.new(-320, G, -484), "Park", "Wynwood Walls")
		L.poi(Vector3.new(-300, G, -470), "Job", "Mural Crew", { Job = "Street Artist", Pay = 55 })
	end
	-- ===== Food truck park (block x -560..-400, z -690..-552) =====
	do
		local c = at(-480, -621)
		local fp = L.model(LM, "FoodTruckPark")
		L.BD(fp, c, 0, 0.03, 0, 100, 0.2, 80, C(150, 130, 100), M.Pebble, "GravelLot")
		local trucks = { { "TACOS LOCOS", C(250, 200, 40) }, { "AREPA BOX", C(230, 60, 60) }, { "POKE WAVE", C(40, 170, 200) }, { "BURGER BUS", C(30, 30, 34) }, { "CHURRO KING", C(240, 120, 180) } }
		for k, t in ipairs(trucks) do
			local tc = c * CFrame.new(-40 + (k - 1) * 20, 0, -28) * CFrame.Angles(0, math.pi / 2, 0)
			L.B(fp, tc, 0, 1.4, 0, 16, 9, 7, t[2], M.Metal)
			L.B(fp, tc, -6.5, 1.4, 0, 3, 6, 7, L.shade(t[2], 0.85), M.Metal)
			L.BD(fp, tc, 1, 4.5, -3.6, 7, 3.6, 0.2, C(30, 30, 34), M.Glass)
			L.P(fp, Vector3.new(8, 0.3, 3), tc * CFrame.new(1, 9.6, -5) * CFrame.Angles(math.rad(-20), 0, 0), C(240, 240, 236), M.Fabric)
			local sg = L.BD(fp, tc, 1, 8.4, -3.65, 9, 1.6, 0.1, C(250, 250, 248), M.SmoothPlastic)
			L.text(sg, Enum.NormalId.Front, t[1], { font = Enum.Font.Bangers, color = L.shade(t[2], 0.6), pps = 20 })
			for _, x in ipairs({ -5, 5 }) do for _, z in ipairs({ -3, 3 }) do L.D(fp, Vector3.new(1, 2.6, 2.6), tc * CFrame.new(x, 1.3, z), C(20, 20, 20), M.Rubber, nil, { Shape = Enum.PartType.Cylinder }) end end
		end
		-- picnic tables under string lights
		for r = 0, 2 do
			for k = 0, 3 do
				local tc = c * CFrame.new(-36 + k * 24, 0, 2 + r * 12)
				L.B(fp, tc, 0, 2.4, 0, 8, 0.4, 3, C(150, 110, 70), M.Wood)
				L.B(fp, tc, 0, 1.4, 2.6, 8, 0.3, 1.2, C(150, 110, 70), M.Wood)
				L.B(fp, tc, 0, 1.4, -2.6, 8, 0.3, 1.2, C(150, 110, 70), M.Wood)
				L.B(fp, tc, 0, 0, 0, 0.6, 2.4, 0.6, C(60, 60, 60), M.Metal)
			end
		end
		for x = -48, 48, 24 do
			L.B(fp, c, x, 0, -10, 0.5, 16, 0.5, C(40, 40, 40), M.Wood)
			L.B(fp, c, x, 0, 36, 0.5, 16, 0.5, C(40, 40, 40), M.Wood)
			for k = 0, 8 do
				L.D(fp, Vector3.new(0.7, 0.7, 0.7), c * CFrame.new(x, 15.5 - math.sin(k / 8 * math.pi) * 2.5, -10 + k * 5.75), C(255, 220, 150), M.Neon, nil, { Shape = Enum.PartType.Ball })
			end
		end
		L.footprint(LM, c, 100, 80)
		L.poi(Vector3.new(-480, G, -650), "Job", "Food Truck Vendor", { Job = "Food Truck", Pay = 50 })
	end
	-- Creator House (content creators' loft), Rivet Roasters cafe, Sparkle Car Wash as named lots
	L.loft(LM, at(-480, -1040, math.pi), 60, 50, { sign = "CREATOR HOUSE", floors = 4, rooftop = true })
	L.footprint(LM, at(-480, -1040, math.pi), 60, 50)
	L.poi(Vector3.new(-480, G, -1018), "Job", "Creator House", { Job = "Content Creator", Pay = 65 })

	-- ===== MAIN STREET (NW 2 Ave, x = -240): continuous storefronts, outdoor dining, banners, string lights =====
	local main = L.model(LM, "MainStreet")
	for z = -1080, 300, 40 do
		-- string lights across the street
		for k = 0, 8 do
			local x = MAIN_X - 21 + k * 42 / 8
			L.D(main, Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, G + 19 - math.sin(k / 8 * math.pi) * 2.5, z), C(255, 220, 150), M.Neon, nil, { Shape = Enum.PartType.Ball })
		end
	end
	local CROSS = { -1110, -975, -830, -690, -552, -410, -270, -130, 10, 334 }
	local function nearCross(z) for _, c in ipairs(CROSS) do if math.abs(z - c) < 34 then return true end end return false end
	for z = -1060, 280, 22 do
		if nearCross(z) then continue end
		for _, sd in ipairs({ -1, 1 }) do
			-- cafe tables + umbrellas on the wide sidewalks, planters between them
			local px = MAIN_X + sd * 25
			local zc = z + L.r(-3, 3)
			if L.chance(0.55) then
				local tc = CFrame.new(px, G + 0.9, zc)
				L.B(main, tc, 0, 2.6, 0, 3, 0.2, 3, C(250, 250, 248), M.Metal)
				L.B(main, tc, 0, 0, 0, 0.3, 2.6, 0.3, C(30, 30, 30), M.Metal)
				for _, q in ipairs({ { -2.2, 0 }, { 2.2, 0 } }) do L.B(main, tc * CFrame.new(q[1], 0, q[2]), 0, 1.4, 0, 1.4, 0.3, 1.4, C(30, 30, 30), M.Metal) end
				if L.chance(0.6) then L.Cyl(main, 0.4, 7, tc * CFrame.new(0, 7.5, 0), L.pick({ C(240, 240, 236), C(30, 30, 34), C(150, 40, 40), C(40, 90, 70) }), M.Fabric) end
			else
				L.B(main, CFrame.new(px, G + 0.9, zc), 0, 0, 0, 3, 2.4, 6, C(70, 72, 76), M.Concrete, "DowntownConcreteFacade")
				L.bush(main, Vector3.new(px, G + 3.3, zc), 4)
			end
		end
	end
	-- lamppost banners
	for z = -1050, 280, 60 do
		for _, sd in ipairs({ -1, 1 }) do
			local b = L.D(main, Vector3.new(0.1, 5, 2.4), CFrame.new(MAIN_X + sd * 21.5, G + 16, z), sd < 0 and C(220, 60, 120) or C(40, 160, 200), M.Fabric)
			L.text(b, sd < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "MAIN\nST", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), pps = 20 })
		end
	end

	-- ===== fill: Main Street gets a continuous retail wall; the rest is warehouses with murals, galleries, lofts =====
	local function inWyn(x, z)
		if x < -715 or x > 300 or z < -1115 or z > 330 then return false end
		if x > -85 and z > -695 and z < 15 then return false end -- park
		if x > 75 and z < -686 then return false end -- SoHo
		return true
	end
	local built = L.fill(B, net, function(x, z, st, side, e)
		if not inWyn(x, z) then return nil end
		local onMain = (e[5] == "NW 2 Ave")
		if onMain then
			return { kind = "shop", w = L.r(34, 48), d = L.r(44, 52), gap = 0, opts = { rundown = false, floors = L.chance(0.6) and 2 or 1, units = 2, signs = { L.pick({ "GALLERY 26", "BREW CO", "VINYL SHOP", "SNEAKER LAB", "TACO BAR", "MATCHA", "THRIFT", "PIZZA SLICE", "BOOKS", "JUICE BAR", "STREETWEAR", "TATTOO ART", "BAGEL CO", "PLANT SHOP" }), L.pick({ "COFFEE", "BAR & GRILL", "BARBER", "BOUTIQUE", "WINE BAR", "RAMEN", "GELATO", "RECORDS" }) } } }
		end
		local r = L.rng:NextNumber()
		if r < 0.42 then return { kind = "warehouse", w = L.r(50, 80), d = L.r(50, 60), opts = { mural = L.pick(MURALS), rundown = false } } end
		if r < 0.7 then return { kind = "loft", w = L.r(30, 46), d = L.r(40, 48) } end
		if r < 0.88 then return { kind = "shop", w = L.r(40, 60), d = 50, opts = { rundown = L.chance(0.3), floors = 1 } } end
		if r < 0.95 then return { kind = "condoBoard", w = 50, d = 50 } end
		return { kind = "emptyLot", w = 40, d = 46 }
	end)
	local parts = 0
	for _, d in ipairs(B:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "wynwood lots " .. built .. ", parts " .. parts
end
