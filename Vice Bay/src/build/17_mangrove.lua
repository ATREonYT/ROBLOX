-- 17 Mangrove Bay: the glades west of Glades Rd become a rich canal neighbourhood.
-- Man-made canals (72 wide, open to the sea at both ends) you can drive a boat through, luxury houses on
-- both banks with private docks, boat-only "Keys" between the canals and the sea, mangroves on every
-- natural bank, and a public dock (Mangrove Bay Landing) with airboat tours and a bait & tackle shop.
return function(L)
	local M, C = L.M, L.C
	local G, W = L.G, L.WATER
	local T = workspace.Terrain
	local VB = L.folder(workspace, "ViceBay")
	local LM = L.folder(L.folder(VB, "Landmarks"), "MangroveBay")
	local B = L.folder(L.folder(VB, "Buildings"), "MangroveBay")
	LM:ClearAllChildren()
	B:ClearAllChildren()
	L.seed(1717)
	local t0 = os.clock()
	local XW, XE = -2048, -1833 -- glades strip (sea edge .. Glades Rd sidewalk, road widened to 62)
	local CX0, CX1 = -1980, -1908 -- canal banks
	-- ===== 1. clear the old glades contents (stray hood lots, old airboat dock) =====
	local cleared = 0
	for _, fname in ipairs({ "Hood", "Port" }) do
		local f = VB.Buildings:FindFirstChild(fname)
		if f then
			for _, m in ipairs(f:GetChildren()) do
				local p = m:IsA("Model") and m:GetBoundingBox().Position or (m:IsA("BasePart") and m.Position)
				if p and p.X < XE and p.Z < 960 then m:Destroy() cleared += 1 end
			end
		end
	end
	local cty = VB.Landmarks:FindFirstChild("County")
	if cty and cty:FindFirstChild("AirboatTours") then cty.AirboatTours:Destroy() end
	-- ===== 2. ground: fill the old ponds, real soil + grass where people live =====
	for _, p in ipairs({ { -1960, -900, 70, 40 }, { -1900, -620, 50, 60 }, { -1980, -250, 60, 40 }, { -1930, 420, 80, 50 }, { -1970, 820, 60, 70 } }) do
		T:FillBlock(CFrame.new(p[1], -6, p[2]), Vector3.new(p[3] + 8, 12, p[4] + 8), M.Ground)
		T:FillBlock(CFrame.new(p[1], -2, p[2]), Vector3.new(p[3] + 8, 4, p[4] + 8), M.Grass)
	end
	local reg = Region3.new(Vector3.new(XW, -16, -1152), Vector3.new(XE + 1, 8, 960)):ExpandToGrid(4)
	T:ReplaceMaterial(reg, 4, M.Mud, M.Ground)
	T:ReplaceMaterial(reg, 4, M.LeafyGrass, M.Grass)
	task.wait()
	-- ===== 3. carve the canals (water surface = sea level) =====
	local CANALS = {
		{ CX0, CX1, -1104, -448 }, -- north canal
		{ -2064, CX1, -1104, -1060 }, -- north mouth
		{ -2064, CX1, -492, -448 }, -- north-south mouth
		{ CX0, CX1, -372, 920 }, -- south canal
		{ -2064, CX1, -372, -328 }, -- south-north mouth
		{ -2064, CX1, 876, 920 }, -- south mouth
	}
	for _, c in ipairs(CANALS) do
		local cx, cz, sx, sz = (c[1] + c[2]) / 2, (c[3] + c[4]) / 2, c[2] - c[1], c[4] - c[3]
		T:FillBlock(CFrame.new(cx, -2, cz), Vector3.new(sx, 20, sz), M.Air) -- water will not overwrite solid voxels, so empty first
		T:FillBlock(CFrame.new(cx, -8, cz), Vector3.new(sx, 8, sz), M.Water)
		T:FillBlock(CFrame.new(cx, -14, cz), Vector3.new(sx, 4, sz), M.Mud)
		task.wait()
	end
	local function inCanal(x, z, pad)
		pad = pad or 0
		for _, c in ipairs(CANALS) do
			if x > c[1] - pad and x < c[2] + pad and z > c[3] - pad and z < c[4] + pad then return true end
		end
		return false
	end
	-- ===== 4. lots =====
	local RIVER_Z0, RIVER_Z1 = 128, 238
	local LANDING_Z0, LANDING_Z1 = 556, 684
	local function runs(z0, z1, cuts)
		local out, z = {}, z0
		table.sort(cuts, function(a, b) return a[1] < b[1] end)
		for _, c in ipairs(cuts) do
			if c[1] > z then table.insert(out, { z, math.min(c[1], z1) }) end
			z = math.max(z, c[2])
		end
		if z1 > z then table.insert(out, { z, z1 }) end
		return out
	end
	local STY = { "noir", "white", "med", "tropical" }
	local houses, k = 0, 0
	local function row(side, segs)
		-- side "east": between canal and Glades Rd, faces the road; "key": boat-only island, faces the sea
		local d = (side == "east") and (XE - 2 - CX1) or (CX0 - XW - 2)
		local cx = (side == "east") and (CX1 + d / 2) or (XW + 2 + d / 2)
		for _, s in ipairs(segs) do
			local n = math.floor((s[2] - s[1]) / 80)
			if n > 0 then
				local lw = (s[2] - s[1]) / n
				for i = 0, n - 1 do
					k += 1
					local c = Vector3.new(cx, G, s[1] + (i + 0.5) * lw)
					local face = (side == "east") and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)
					local cf = CFrame.lookAt(c, c + face)
					local nm = (side == "east" and "Mangrove Bay Estate " or "Mangrove Key Villa ") .. k
					L.luxHouse(B, cf, lw - 4, d, { style = STY[(k % 4) + 1], dock = true, dockMode = "parallel", front = 18, name = nm, price = (side == "key" and 6500000 or 4200000) + L.ri(0, 20) * 100000 })
					L.footprint(B, cf, lw - 4, d)
					houses += 1
					if houses % 3 == 0 then task.wait() end
				end
			end
		end
	end
	row("east", runs(-1056, -496, {}))
	row("key", runs(-1056, -496, {}))
	row("east", runs(-324, 872, { { RIVER_Z0, RIVER_Z1 }, { LANDING_Z0, LANDING_Z1 } }))
	row("key", runs(-324, 872, { { RIVER_Z0, RIVER_Z1 } }))
	print(string.format("mangrove houses %d (%.1fs)", houses, os.clock() - t0))

	-- ===== 5. mangroves on every natural bank: the sea shore of the Keys, the canal mouths, the river =====
	local mg = L.model(LM, "Mangroves")
	local placed = 0
	local function mangroveLine(x0, z0, x1, z1, step)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		for t = 0, len, step do
			local x = x0 + (x1 - x0) * t / len + L.r(-4, 4)
			local z = z0 + (z1 - z0) * t / len + L.r(-4, 4)
			L.mangrove(mg, Vector3.new(x, W + 0.5, z), L.r(14, 22))
			placed += 1
		end
	end
	-- sea shore of the keys (outside the house lots' front lawns: right at the waterline)
	-- open shoreline: only scattered mangrove clumps on the sea side of the keys (views + easy boat access)
	for _, s in ipairs({ { -1100, -452 }, { -376, 916 } }) do mangroveLine(XW - 8, s[1], XW - 8, s[2], 90) end
	-- along the mouths (both banks)
	for _, c in ipairs(CANALS) do
		if c[1] == -2064 then
			mangroveLine(-2050, c[3] - 5, CX0, c[3] - 5, 60)
			mangroveLine(-2050, c[4] + 5, CX0, c[4] + 5, 60)
		end
	end
	-- river banks inside the glades
	mangroveLine(-2040, RIVER_Z0 + 8, XE - 6, RIVER_Z0 + 22, 40)
	mangroveLine(-2040, RIVER_Z1 - 18, XE - 6, RIVER_Z1 - 4, 40)
	-- marsh patches (leafy grass + mud) on the river corners
	for _, p in ipairs({ { -2010, 120 }, { -1860, 248 }, { -2020, 250 }, { -1850, 118 } }) do
		T:FillBlock(CFrame.new(p[1], -1, p[2]), Vector3.new(36, 2, 20), M.LeafyGrass)
	end

	-- ===== 6. Mangrove Bay Landing: public dock, airboat tours, bait & tackle, parking off Glades Rd =====
	do
		local lm = L.model(LM, "MangroveBayLanding")
		local z0, z1 = LANDING_Z0, LANDING_Z1
		local zc = (z0 + z1) / 2
		-- seawall + boardwalk on the bank
		L.P(lm, Vector3.new(2.4, 7.4, z1 - z0), CFrame.new(CX1 + 1.2, -1.4, zc), C(206, 202, 194), M.Concrete, "ConcretePlain")
		L.P(lm, Vector3.new(14, 0.8, z1 - z0 - 6), CFrame.new(CX1 + 8, G + 0.4, zc), C(170, 130, 90), M.WoodPlanks, "WoodPlanksOld")
		-- floating pontoon with fingers, airboats and two rental boats
		L.pontoon(lm, CFrame.new(CX1 - 6, W, z0 + 8) * CFrame.Angles(0, math.pi, 0), z1 - z0 - 16, 8, { berth = 24 })
		for i = 0, 3 do
			local bc = CFrame.new(CX1 - 18, W, z0 + 22 + i * 26) * CFrame.Angles(0, 0, 0)
			L.boat(lm, bc, 22, (i < 2) and C(60, 90, 60) or nil)
			if i < 2 then
				L.Cyl(lm, 0.6, 9, bc * CFrame.new(0, 7, 9) * CFrame.Angles(math.pi / 2, 0, 0), C(40, 40, 42), M.Metal, nil, { CanCollide = false, Transparency = 0.3 })
				L.P(lm, Vector3.new(4, 3, 3), bc * CFrame.new(0, 3.5, 7.5), C(50, 50, 52), M.Metal)
				L.P(lm, Vector3.new(3, 5, 1.6), bc * CFrame.new(0, 4.5, 2), C(30, 30, 32), M.Metal)
			end
		end
		-- bait & tackle / tour office: raised timber shack with a tin roof and painted sign
		local hc = CFrame.new(-1872, G, zc) * CFrame.Angles(0, -math.pi / 2, 0)
		for _, q in ipairs({ { -10, -7 }, { 10, -7 }, { -10, 7 }, { 10, 7 } }) do L.B(lm, hc, q[1], 0, q[2], 1, 3, 1, C(110, 90, 70), M.Wood) end
		L.B(lm, hc, 0, 3, 0, 22, 0.6, 16, C(150, 120, 86), M.WoodPlanks, "WoodPlanksOld")
		L.B(lm, hc, 0, 3.6, 2, 20, 9, 12, C(120, 150, 140), M.WoodPlanks, "SidingBlue")
		L.W(lm, Vector3.new(24, 4, 9), hc * CFrame.new(0, 14.6, -2.5), C(160, 160, 156), M.CorrodedMetal, "CorrugatedRusty")
		L.W(lm, Vector3.new(24, 4, 9), hc * CFrame.new(0, 14.6, 6.5) * CFrame.Angles(0, math.pi, 0), C(160, 160, 156), M.CorrodedMetal, "CorrugatedRusty")
		L.P(lm, Vector3.new(24, 0.4, 5), hc * CFrame.new(0, 12.4, -6) * CFrame.Angles(math.rad(-12), 0, 0), C(160, 160, 156), M.CorrodedMetal, "CorrugatedRusty")
		L.storeSign(lm, hc * CFrame.new(0, 10.6, -4.1), 18, "BAIT & TACKLE", { style = "painted", pal = { C(250, 220, 120), C(40, 70, 40) }, blade = false })
		L.storeSign(lm, hc * CFrame.new(0, 7.6, -4.1), 16, "AIRBOAT TOURS", { style = "lightbox", pal = { C(40, 110, 60), C(250, 250, 240) }, blade = false })
		L.BD(lm, hc, 0, 3.6, -4.05, 6, 6, 0.2, C(40, 60, 70), M.Glass)
		for k2 = 0, 2 do L.B(lm, hc * CFrame.new(-8 + k2 * 2.2, 3.6, -5.2), 0, 0, 0, 1.6, 2.6, 1.6, C(60, 120, 200), M.Plastic) end
		-- parking off Glades Rd
		L.BD(lm, CFrame.new(-1850, G, zc), 0, 0.04, 0, 26, 0.15, z1 - z0 - 10, C(120, 116, 110), M.Pebble, "GravelLot")
		for i = 0, 3 do L.car(lm, CFrame.new(-1848, G + 0.2, z0 + 20 + i * 24) * CFrame.Angles(0, math.pi / 2, 0)) end
		L.footprint(LM, CFrame.new(-1871, G, zc), 72, z1 - z0)
		L.poi(Vector3.new(CX1 - 6, G, zc), "Dock", "Mangrove Bay Landing")
		L.poi(Vector3.new(-1850, G, zc - 12), "Job", "Airboat Guide", { Job = "Airboat Guide", Pay = 60 })
		L.poi(Vector3.new(-1850, G, zc + 12), "Shop", "Bait & Tackle", { Shop = "Fishing" })
	end
	-- entrance monument on Glades Rd
	do
		local ec = CFrame.new(-1844, G, -410 + 52) * CFrame.Angles(0, -math.pi / 2, 0)
		L.B(LM, ec, 0, 0, 0, 22, 5, 2, C(214, 206, 192), M.Concrete, "BoardFormedConcrete")
		local pl = L.BD(LM, ec, 0, 1, -1.05, 18, 2.6, 0.2, C(30, 30, 32), M.Metal)
		L.label(pl, Enum.NormalId.Front, "MANGROVE BAY", { font = Enum.Font.Merriweather, color = C(222, 196, 140), light = 0.2, bright = 1.3 })
		for sd = -1, 1, 2 do L.palm(LM, (ec * CFrame.new(sd * 13, 0, 0)).Position, 30, "royal") end
	end
	-- manicured lawns: no tall terrain grass blades anywhere in the bay (LeafyGrass has no decoration)
	T:ReplaceMaterial(Region3.new(Vector3.new(-2100, -10, -1160), Vector3.new(-1828, 8, 960)):ExpandToGrid(4), 4, M.Grass, M.LeafyGrass)
	local parts = 0
	for _, f in ipairs({ B, LM }) do for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	return string.format("mangrove bay: houses %d, mangroves %d, cleared %d, parts %d (%.0fs)", houses, placed, cleared, parts, os.clock() - t0)
end
