-- 11 Beach (x 1483..1700 along Ocean Blvd) + Yacht Marina (basin x 1000..1640, z 650..1060)
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local W = L.WATER
	local T = workspace.Terrain
	local VB = L.folder(workspace, "ViceBay")
	local BE = L.folder(L.folder(VB, "Landmarks"), "Beach")
	local MA = L.folder(L.folder(VB, "Landmarks"), "Marina")
	BE:ClearAllChildren()
	MA:ClearAllChildren()
	L.seed(1600)

	-- ================= BEACH =================
	-- beachwalk: paver promenade with palms, lamps, benches
	local walk = L.model(BE, "Beachwalk")
	L.P(walk, Vector3.new(16, 0.6, 1730), CFrame.new(1500, G + 0.1, -235), C(214, 204, 186), M.Pavement, "HerringbonePavers")
	L.P(walk, Vector3.new(1.2, 2, 1730), CFrame.new(1508.6, G + 0.6, -235), C(236, 232, 222), M.Concrete, "ConcretePlain")
	for z = -1090, 590, 30 do
		L.palm(walk, Vector3.new(1490, G, z + L.r(-3, 3)), L.r(34, 46), (z % 90 == 0) and "hero" or "royal")
		if z % 60 == 0 then
			L.Cyl(walk, 14, 0.5, CFrame.new(1505, G + 7, z + 15), C(240, 240, 236), M.Metal)
			L.D(walk, Vector3.new(1.6, 2, 1.6), CFrame.new(1505, G + 14.6, z + 15), C(255, 240, 210), M.Neon)
			L.bench(walk, CFrame.new(1504, G + 0.4, z) * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
	-- lifeguard towers, umbrellas, volleyball, beach bar, showers
	for z = -1000, 560, 190 do L.lifeguard(BE, CFrame.new(1600, G, z) * CFrame.Angles(0, -math.pi / 2, 0)) end
	for z = -1080, 600, 26 do
		for _, x in ipairs({ 1540, 1565 }) do
			if L.chance(0.45) then L.umbrella(BE, CFrame.new(x + L.r(-4, 4), G, z + L.r(-6, 6)) * CFrame.Angles(0, L.r(0, 6), 0)) end
		end
	end
	for _, z in ipairs({ -320, -240 }) do
		local vc = CFrame.new(1560, G, z)
		local v = L.model(BE, "Volleyball")
		for _, q in ipairs({ { -15, 0 }, { 15, 0 } }) do L.B(v, vc, q[1], 0, q[2], 0.4, 9, 0.4, C(240, 240, 240), M.Metal) end
		L.BD(v, vc, 0, 6.4, 0, 30, 2.4, 0.15, C(30, 30, 30), M.Fabric, nil, { Transparency = 0.4 })
		for _, a in ipairs({ { 0, -15, 30, 0.3 }, { 0, 15, 30, 0.3 } }) do L.BD(v, vc, a[1], 0.02, a[2], a[3], 0.05, a[4], C(40, 80, 200), M.Fabric) end
	end
	L.poi(Vector3.new(1560, G, -280), "Park", "Beach Volleyball")
	do
		local bb = CFrame.new(1530, G, -40)
		local bar = L.model(BE, "BeachBar")
		L.B(bar, bb, 0, 0, 0, 30, 1, 22, C(176, 150, 114), M.WoodPlanks, "WoodPlanksOld")
		L.B(bar, bb, 0, 1, 0, 16, 4, 6, C(120, 90, 60), M.Wood)
		for _, q in ipairs({ { -13, -9 }, { 13, -9 }, { -13, 9 }, { 13, 9 } }) do L.B(bar, bb, q[1], 1, q[2], 0.8, 11, 0.8, C(120, 90, 60), M.Wood) end
		L.W(bar, Vector3.new(32, 5, 12), bb * CFrame.new(0, 14.5, -6), C(200, 170, 110), M.Grass)
		L.W(bar, Vector3.new(32, 5, 12), bb * CFrame.new(0, 14.5, 6) * CFrame.Angles(0, math.pi, 0), C(200, 170, 110), M.Grass)
		local s = L.D(bar, Vector3.new(12, 2, 0.2), bb * CFrame.new(0, 9.5, -9.2), C(250, 200, 60), M.SmoothPlastic)
		L.text(s, Enum.NormalId.Front, "TIKI BAR", { font = Enum.Font.Bangers, color = C(30, 120, 140), pps = 20 })
		for k = 0, 4 do L.Cyl(bar, 3, 1.4, bb * CFrame.new(-8 + k * 4, 2.5, -4.5), C(240, 240, 236), M.Plastic) end
		L.poi(Vector3.new(1530, G, -60), "Job", "Helados Stand", { Job = "Ice Cream Vendor", Pay = 40 })
		L.footprint(BE, bb, 30, 22)
	end
	L.poi(Vector3.new(1600, G, -100), "Job", "Lifeguard HQ", { Job = "Lifeguard", Pay = 60 })
	-- fishing pier
	do
		local pz = -560
		local pier = L.model(BE, "FishingPier")
		local len = 300
		L.P(pier, Vector3.new(len, 1.4, 16), CFrame.new(1600 + len / 2, G + 1.2, pz), C(170, 146, 110), M.WoodPlanks, "WoodPlanksOld")
		for x = 1610, 1600 + len, 20 do
			for _, sd in ipairs({ -1, 1 }) do
				L.P(pier, Vector3.new(1.2, 20, 1.2), CFrame.new(x, G - 8, pz + sd * 7.4), C(110, 90, 66), M.Wood)
				L.D(pier, Vector3.new(0.3, 3.4, 20), CFrame.new(x - 10, G + 3.6, pz + sd * 7.8), C(200, 196, 188), M.Wood)
			end
			if (x - 1610) % 60 == 0 then
				L.Cyl(pier, 12, 0.4, CFrame.new(x, G + 8, pz - 7), C(240, 240, 236), M.Metal)
				L.D(pier, Vector3.new(1.2, 1.6, 1.2), CFrame.new(x, G + 14.6, pz - 7), C(255, 240, 210), M.Neon)
			end
		end
		L.P(pier, Vector3.new(40, 1.4, 40), CFrame.new(1600 + len + 18, G + 1.2, pz), C(170, 146, 110), M.WoodPlanks, "WoodPlanksOld")
		L.poi(Vector3.new(1600 + len + 18, G + 2, pz), "Job", "Pier Fishing", { Job = "Fisher", Pay = 35 })
	end

	-- ================= MARINA =================
	-- breakwater (rock jetty) protecting the basin, lighthouse at the tip
	local BW = { { 1640, 640 }, { 1660, 900 }, { 1610, 1000 }, { 1480, 1050 }, { 1330, 1062 } }
	for i = 1, #BW - 1 do
		local a = Vector3.new(BW[i][1], 0, BW[i][2])
		local b = Vector3.new(BW[i + 1][1], 0, BW[i + 1][2])
		local cf = CFrame.lookAt((a + b) / 2, b)
		T:FillBlock(cf * CFrame.new(0, -6, 0), Vector3.new(26, 20, (b - a).Magnitude + 20), M.Rock)
	end
	do
		local lc = CFrame.new(1330, G + 2, 1062)
		local lh = L.model(MA, "Lighthouse")
		L.Cyl(lh, 4, 22, lc * CFrame.new(0, 2, 0), C(200, 196, 188), M.Concrete)
		L.Cyl(lh, 50, 12, lc * CFrame.new(0, 29, 0), C(250, 250, 248), M.Plaster)
		for k = 0, 2 do L.Cyl(lh, 5, 12.2, lc * CFrame.new(0, 12 + k * 14, 0), C(200, 40, 40), M.Plaster) end
		L.Cyl(lh, 8, 9, lc * CFrame.new(0, 58, 0), C(240, 250, 255), M.Glass, nil, { Transparency = 0.3 })
		L.Ball(lh, 4, lc * CFrame.new(0, 58, 0), C(255, 240, 180), M.Neon)
		L.Cyl(lh, 4, 11, lc * CFrame.new(0, 64, 0), C(30, 30, 32), M.Metal)
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Brightness = 3
		pl.Color = C(255, 240, 180)
		pl.Parent = lh:FindFirstChildWhichIsA("BasePart")
	end
	-- promenade along the north edge of the basin
	L.P(MA, Vector3.new(470, 1.4, 22), CFrame.new(1230, G + 0.1, 641), C(176, 150, 114), M.WoodPlanks, "WoodPlanksOld")
	for x = 1010, 1450, 22 do
		L.Cyl(MA, 1, 0.9, CFrame.new(x, G + 1, 652), C(40, 40, 44), M.Metal)
		if (x - 1010) % 66 == 0 then
			L.Cyl(MA, 12, 0.4, CFrame.new(x, G + 6.5, 634), C(30, 30, 34), M.Metal)
			L.D(MA, Vector3.new(1.4, 1.8, 1.4), CFrame.new(x, G + 13, 634), C(255, 236, 200), M.Neon)
		end
	end
	-- floating docks with boats in the slips
	local dockX = { 1130, 1240, 1350, 1450 }
	for i, x in ipairs(dockX) do
		local len = (i == 4) and 240 or 300
		local cf = CFrame.new(x, W, 652) * CFrame.Angles(0, math.pi, 0) -- runs south
		L.dock(MA, cf, len, math.floor(len / 34), 22)
		for k = 1, math.floor(len / 34) do
			local z = 652 + (k - 0.5) * len / (math.floor(len / 34) + 1)
			for _, sd in ipairs({ -1, 1 }) do
				if L.chance(0.78) then
					local bx = x + sd * 16
					local bcf = CFrame.new(bx, W, z + 16) * CFrame.Angles(0, math.pi, 0)
					if L.chance(0.22) then
						L.yacht(MA, CFrame.new(bx + sd * 14, W, z) * CFrame.Angles(0, (sd > 0) and math.pi / 2 or -math.pi / 2, 0), L.r(50, 60), "motor")
					else
						L.boat(MA, CFrame.new(bx, W, z) * CFrame.Angles(0, (sd > 0) and math.pi / 2 or -math.pi / 2, 0), L.r(22, 30))
					end
				end
			end
		end
		L.poi(Vector3.new(x, G, 660), "Dock", "Marina Dock " .. string.char(64 + i))
	end
	-- megayacht pier on the east side with superyachts
	local mp = CFrame.new(1560, W, 680) * CFrame.Angles(0, math.pi, 0)
	L.dock(MA, mp, 300, 0, 0)
	L.yacht(MA, CFrame.new(1530, W, 760) * CFrame.Angles(0, 0, 0), 150, "super")
	L.yacht(MA, CFrame.new(1595, W, 900) * CFrame.Angles(0, math.pi, 0), 130, "super")
	L.poi(Vector3.new(1560, G, 700), "Job", "Superyacht Deckhand", { Job = "Deckhand", Pay = 85 })
	-- marina plaza on piles (west side): Vice Bay Yachts & Boats dealership + harbour master + fuel dock
	do
		local pc = CFrame.new(1040, G, 730)
		L.P(MA, Vector3.new(80, 2, 150), pc * CFrame.new(0, -1, 0), C(196, 190, 178), M.Concrete, "ConcretePlain")
		for x = -36, 36, 18 do for z = -70, 70, 20 do L.P(MA, Vector3.new(2, 14, 2), pc * CFrame.new(x, -9, z), C(150, 146, 136), M.Concrete) end end
		local show = L.model(MA, "ViceBayYachts")
		local sc = pc * CFrame.new(-10, 0, -30)
		L.P(show, Vector3.new(50, 0.4, 60), sc * CFrame.new(0, 0.2, 0), C(236, 232, 226), M.Marble, "LobbyMarble")
		L.P(show, Vector3.new(50, 18, 60), sc * CFrame.new(0, 9.4, 0), C(150, 190, 200), M.Glass, nil, { Transparency = 0.6, CanCollide = false })
		L.P(show, Vector3.new(54, 1.6, 64), sc * CFrame.new(0, 19, 0), C(244, 244, 240), M.Concrete, "ConcretePlain")
		L.boat(show, sc * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0.4, 0), 30, C(30, 30, 34))
		local s = L.D(show, Vector3.new(36, 4, 0.3), sc * CFrame.new(0, 22, -30), C(20, 30, 50), M.SmoothPlastic)
		L.text(s, Enum.NormalId.Front, "VICE BAY YACHTS & BOATS", { font = Enum.Font.Merriweather, color = C(222, 190, 110), pps = 12, dist = 500, light = 0 })
		L.poi((sc).Position, "Dealer", "Vice Bay Yachts & Boats", { Tier = 5, PriceMin = 40000, PriceMax = 6000000 })
		-- harbour master + fuel dock
		local hm = pc * CFrame.new(-12, 0, 40)
		L.B(MA, hm, 0, 0, 0, 30, 14, 26, C(244, 244, 240), M.Plaster, "StuccoWhite")
		L.W(MA, Vector3.new(32, 6, 14), hm * CFrame.new(0, 17, -6.5), C(60, 100, 140), M.Metal)
		L.W(MA, Vector3.new(32, 6, 14), hm * CFrame.new(0, 17, 6.5) * CFrame.Angles(0, math.pi, 0), C(60, 100, 140), M.Metal)
		L.sign(MA, hm * CFrame.new(0, 10, -13.3), 22, 3, "HARBOUR MASTER", C(30, 60, 100), Color3.new(1, 1, 1), Enum.Font.GothamBold, {})
		L.poi((hm * CFrame.new(0, 0, -16)).Position, "Job", "Boat Tours Captain", { Job = "Captain", Pay = 75 })
		local fd = CFrame.new(1100, W, 1010)
		L.P(MA, Vector3.new(60, 1.6, 12), fd * CFrame.new(0, 1.2, 0), C(176, 150, 114), M.WoodPlanks, "WoodPlanksOld")
		for k = -1, 1 do
			L.B(MA, fd, k * 16, 2, -3, 2, 5, 1.4, C(240, 240, 236), M.Metal)
			L.BD(MA, fd, k * 16, 5, -3.75, 1.6, 1, 0.1, C(200, 30, 30), M.SmoothPlastic)
		end
		local fs = L.D(MA, Vector3.new(16, 3, 0.3), fd * CFrame.new(0, 10, 4), C(200, 30, 30), M.SmoothPlastic)
		L.text(fs, Enum.NormalId.Front, "MARINE FUEL", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), pps = 16 })
		L.B(MA, fd, -24, 2, 4, 0.8, 12, 0.8, C(60, 60, 64), M.Metal)
		L.poi(Vector3.new(1100, G, 1010), "Gas", "Marina Fuel Dock")
	end
	local parts = 0
	for _, f in ipairs({ BE, MA }) do for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	return "beach + marina parts " .. parts
end
