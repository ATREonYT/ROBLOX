-- 36 Westside: the hood grows west. Mangrove Bay shrinks to its north canal (z < -420); the south half is
-- filled in and becomes hood blocks between Glades Rd and the bay: a back street (NW 52 Ave), five cross
-- streets joined to Glades Rd with curb cuts, rundown lots, and the hood activities on the Glades Rd frontage:
-- Sudz Car Wash (job), Westside Courts (basketball), Westside Boxing (gym/job), Fresh Cutz barber + Liberty Sound
-- studio (jobs, walk-in interiors) and the Westside car meet lot. Also swaps a few empty hood lots for courts.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local T = workspace.Terrain
	local VB = workspace.ViceBay
	L.seed(3636)
	local t0 = os.clock()
	local X0, X1, Z0, Z1 = -2048, -1832, -420, 940
	local function inZone(p) return p.X > X0 - 20 and p.X < X1 and p.Z > Z0 and p.Z < Z1 + 30 end

	-- ===== 1. shrink Mangrove Bay: remove everything south of the north canal =====
	local removed = 0
	for _, f in ipairs({ VB.Buildings:FindFirstChild("MangroveBay"), VB.Landmarks:FindFirstChild("MangroveBay"), VB:FindFirstChild("POIs") }) do
		if f then
			for _, m in ipairs(f:GetChildren()) do
				local p
				if m:IsA("Model") then p = m:GetBoundingBox().Position elseif m:IsA("BasePart") then p = m.Position end
				if p and inZone(p) then m:Destroy() removed += 1 end
			end
		end
	end
	for _, m in ipairs(VB:GetDescendants()) do
		if m:IsA("Model") and (m.Name == "Mangrove" or m.Name == "Tree" or m.Name == "Palm" or m.Name == "Bush" or m.Name == "Plant") and m.Parent and inZone(m:GetPivot().Position) then
			if m:GetPivot().Position.X < -1834 then m:Destroy() removed += 1 end
		end
	end
	for _, n in ipairs({ "HoodWest" }) do local f = VB:FindFirstChild(n) if f then f:Destroy() end end
	local LMh = L.folder(VB.Landmarks, "HoodWest")
	local Bh = L.folder(VB.Buildings, "HoodWest")
	LMh:ClearAllChildren()
	Bh:ClearAllChildren()

	-- ===== 2. fill the south canal + mouths: solid ground at exactly G, dirt with patchy grass =====
	local CH = 128
	local rng = Random.new(36)
	for x0 = X0, X1 - 1, CH do
		for z0 = Z0, Z1 - 1, CH do
			local reg = Region3.new(Vector3.new(x0, -16, z0), Vector3.new(math.min(x0 + CH, X1), 8, math.min(z0 + CH, Z1))):ExpandToGrid(4)
			local sz = reg.Size / 4
			local base = reg.CFrame.Position - reg.Size / 2
			local mats, occ = {}, {}
			for ix = 1, sz.X do
				mats[ix], occ[ix] = {}, {}
				for iy = 1, sz.Y do
					mats[ix][iy], occ[ix][iy] = {}, {}
					local yb = base.Y + (iy - 1) * 4
					local o = math.clamp((G - 2 - yb) / 4, 0, 1)
					for iz = 1, sz.Z do
						local mt = M.Ground
						if yb >= -4 and rng:NextNumber() < 0.35 then mt = M.LeafyGrass end
						mats[ix][iy][iz] = (o > 0) and mt or M.Air
						occ[ix][iy][iz] = o
					end
				end
			end
			T:WriteVoxels(reg, 4, mats, occ)
		end
		task.wait()
	end
	T:ReplaceMaterial(Region3.new(Vector3.new(X0 - 40, -20, Z0), Vector3.new(X1, 20, Z1 + 40)):ExpandToGrid(4), 4, M.Grass, M.LeafyGrass)

	-- ===== 3. streets =====
	local S = L.STY
	local lines = {}
	local function ln(style, p, o)
		o = o or {}
		table.insert(lines, { style = S[style], pts = p, name = o.name, cul = o.cul })
	end
	local CROSS = { { -340, "NW 30 St" }, { -40, "NW 33 St" }, { 260, "NW 36 St" }, { 560, "NW 39 St" }, { 860, "NW 42 St" } }
	local back = {}
	for _, c in ipairs(CROSS) do table.insert(back, { -1960, c[1] }) end
	ln("HOOD", back, { name = "NW 52 Ave" })
	for _, c in ipairs(CROSS) do ln("HOOD", { { -1960, c[1] }, { -1822, c[1] } }, { name = c[2] }) end
	local net = L.net(lines)
	L.buildRoads(VB, net, "HoodWest")
	if not table.find(L.FILL_BLOCKERS, "HoodWest") then table.insert(L.FILL_BLOCKERS, "HoodWest") end
	for _, c in ipairs(CROSS) do
		pcall(function() L.cutSidewalk(CFrame.new(-1827, G + 0.5, c[1]), Vector3.new(14, 3, 40), "Roads") end)
	end

	-- ===== 4. hood activities on the Glades Rd frontage (fronts face east, onto Glades Rd) =====
	local E = -math.pi / 2
	local function lot(z, w, d) return CFrame.new(-1831.5 - d / 2, G, z) * CFrame.Angles(0, E, 0), w, d end
	local INK = C(30, 30, 32)
	-- Sudz Car Wash: drive-through tunnel with brushes, 3 self-serve bays, vacuums, pylon
	do
		local cf, w, d = lot(-190, 110, 100)
		local m = L.model(LMh, "SudzCarWash")
		L.BD(m, cf, 0, 0.03, 0, w - 1, 0.15, d - 1, C(150, 148, 142), M.Concrete, "ParkingLotStained")
		-- tunnel runs front-to-back on the left side
		local tx = -w / 2 + 18
		for _, sd in ipairs({ -1, 1 }) do L.B(m, cf, tx + sd * 12, 0, 6, 2, 15, 64, C(236, 236, 232), M.Concrete) end
		L.B(m, cf, tx, 15, 6, 26, 1.4, 66, C(30, 120, 200), M.Metal)
		local sg = L.BD(m, cf, tx, 15, -26.1, 26, 1.4, 0.2, C(255, 255, 255), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "ENTER  →", { font = Enum.Font.GothamBlack, color = C(30, 120, 200), pps = 20, dist = 200 })
		for k = 0, 2 do
			for _, sd in ipairs({ -1, 1 }) do L.Cyl(m, 10, 3.2, cf * CFrame.new(tx + sd * 8.6, 5.4, -6 + k * 18), L.pick({ C(30, 120, 220), C(220, 40, 120), C(250, 200, 40) }), M.Fabric, nil, { CanCollide = false }) end
		end
		local tb = L.P(m, Vector3.new(16, 2.6, 2.6), cf * CFrame.new(tx, 11.5, 20) * CFrame.Angles(0, 0, 0), C(30, 120, 220), M.Fabric)
		tb.Shape = Enum.PartType.Cylinder
		tb.CanCollide = false
		-- self-serve bays with a canopy
		local bx = w / 2 - 30
		L.B(m, cf, bx, 13, 18, 52, 1.2, 40, C(236, 236, 232), M.Metal)
		for _, x in ipairs({ -26, -8.7, 8.7, 26 }) do L.B(m, cf, bx + x, 0, 18, 1, 13, 40, C(30, 120, 200), M.Metal) end
		for _, x in ipairs({ -17.4, 0, 17.4 }) do
			L.B(m, cf, bx + x, 0, 37, 2.4, 5, 1.2, C(60, 62, 66), M.Metal)
			L.BD(m, cf, bx + x, 0.16, 18, 2, 0.04, 2, C(60, 60, 64), M.Metal)
		end
		local bsg = L.BD(m, cf, bx, 14.2, -2.1, 52, 3, 0.3, C(30, 120, 200), M.SmoothPlastic)
		L.text(bsg, Enum.NormalId.Front, "SELF SERVE  •  $3", { font = Enum.Font.GothamBlack, color = C(255, 255, 255), pps = 12, dist = 250 })
		-- vacuums along the front
		for k = 0, 3 do
			local vx = bx - 22 + k * 15
			L.B(m, cf, vx, 0, -d / 2 + 12, 1.6, 7, 1.6, C(250, 200, 40), M.Metal)
			L.BD(m, cf, vx, 6.4, -d / 2 + 13, 0.3, 0.3, 4, INK, M.Rubber)
		end
		-- pylon
		L.B(m, cf, w / 2 - 6, 0, -d / 2 + 4, 1.4, 24, 1.4, C(70, 72, 76), M.Metal)
		local py = L.BD(m, cf, w / 2 - 6, 16, -d / 2 + 4, 16, 8, 1, C(30, 120, 200), M.SmoothPlastic)
		L.text(py, Enum.NormalId.Front, "SUDZ\nCAR WASH", { font = Enum.Font.Bangers, color = C(255, 255, 255), stroke = 0, pps = 10, dist = 400, light = 0.6 })
		L.text(py, Enum.NormalId.Back, "SUDZ\nCAR WASH", { font = Enum.Font.Bangers, color = C(255, 255, 255), stroke = 0, pps = 10, dist = 400, light = 0.6 })
		L.footprint(LMh, cf, w, d)
		L.lod(m)
		pcall(function() L.poi((cf * CFrame.new(0, 0, -d / 2 + 8)).Position, "Job", "Sudz Car Wash", { Job = "Car Wash Attendant", Pay = 45 }) end)
	end
	-- Westside Courts: two fenced full courts with lights, bleachers and a wall with a piece
	do
		local cf, w, d = lot(115, 124, 96)
		local m = L.model(LMh, "WestsideCourts")
		L.BD(m, cf, 0, 0.02, 0, w - 1, 0.12, d - 1, C(150, 148, 142), M.Concrete)
		for _, sd in ipairs({ -1, 1 }) do
			L.court(m, cf * CFrame.new(sd * 31, 0, 2), 58, 92)
		end
		local wl = L.B(m, cf, 0, 0, d / 2 - 2, w - 6, 12, 1.4, C(206, 200, 188), M.Concrete, "HoodConcreteDirty")
		L.piece(wl, Enum.NormalId.Front)
		L.text(wl, Enum.NormalId.Front, "WESTSIDE COURTS", { font = Enum.Font.Bangers, color = C(255, 210, 60), stroke = 0, size = UDim2.fromScale(0.5, 0.22), pos = UDim2.fromScale(0.25, 0.04), pps = 8, dist = 300, light = 1 })
		for r = 0, 2 do L.B(m, cf, (r - 1) * 2.6, 0, 0, 2.6, 1 + r, 30, C(170, 172, 176), M.Metal) end
		L.footprint(LMh, cf, w, d)
		pcall(function() L.poi((cf * CFrame.new(0, 0, 0)).Position, "Park", "Westside Courts", { Note = "Pickup basketball" }) end)
	end
	-- Westside Boxing: walk-in gym with a ring, heavy bags, mats and a mirror wall
	do
		local cf, w, d = lot(345, 90, 96)
		local m = L.model(LMh, "WestsideBoxing")
		local col = C(150, 70, 60)
		local bw, bd, h = w - 6, d - 20, 22
		local bz = -d / 2 + 14 + bd / 2
		local S2 = L.shell(m, cf, 0, bz, bw, bd, h, col, nil, { { -6, 6, 9 }, { 16, 30, 9 } })
		L.BD(m, cf, 0, 0.02, bz, bw - 2, 0.1, bd - 2, C(40, 40, 44), M.Rubber)
		L.B(m, cf, 23, 0.6, bz - bd / 2 + 0.5, 14, 8.4, 0.25, C(150, 170, 180), M.Glass, nil, { Transparency = 0.5 })
		-- ring
		local rc = cf * CFrame.new(-10, 0, bz + 6)
		L.B(m, rc, 0, 0, 0, 26, 3, 26, C(30, 60, 140), M.Fabric)
		L.BD(m, rc, 0, 3, 0, 24, 0.1, 24, C(230, 228, 220), M.Fabric)
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do L.B(m, rc, sx * 12.2, 3, sz * 12.2, 0.8, 5.4, 0.8, C(200, 30, 30), M.Metal) end end
		for k = 1, 3 do
			local y = 3 + k * 1.5
			for _, sd in ipairs({ -1, 1 }) do
				L.BD(m, rc, sd * 12.2, y, 0, 0.25, 0.25, 24.4, C(240, 240, 236), M.Fabric)
				L.BD(m, rc, 0, y, sd * 12.2, 24.4, 0.25, 0.25, C(240, 240, 236), M.Fabric)
			end
		end
		-- steps up into the ring
		L.B(m, rc, 14, 0, 9, 3, 1.5, 4, C(60, 60, 64), M.Metal)
		-- heavy bags
		for k = 0, 3 do
			local bc = cf * CFrame.new(18, 0, bz - 10 + k * 9)
			L.Cyl(m, 5, 2.4, bc * CFrame.new(0, 5.5, 0), L.pick({ C(200, 30, 30), C(30, 30, 34), C(120, 80, 40) }), M.Leather)
			L.BD(m, bc, 0, 8, 0, 0.15, h - 9, 0.15, C(160, 160, 160), M.Metal)
		end
		L.BD(m, cf, -bw / 2 + 1.1, 2, bz, 0.1, 7, bd * 0.6, C(170, 190, 200), M.Glass, nil, { Reflectance = 0.45 })
		local lp = L.D(m, Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, h - 3, bz), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		local pl = Instance.new("PointLight") pl.Range = 34 pl.Brightness = 0.9 pl.Shadows = false pl.Parent = lp
		for k = -1, 1 do L.BD(m, cf, k * 22, h - 1.3, bz, 2, 0.2, bd * 0.7, C(240, 246, 255), M.Neon) end
		L.parapet(m, cf, 0, bz, bw + 0.4, bd + 0.4, h, L.shade(col, 0.85))
		L.falseFront(m, cf, 0, bz - bd / 2, bw, h, col, "raise")
		local sg = L.BD(m, cf, 0, 12.5, bz - bd / 2 - 0.3, 40, 5, 0.3, C(20, 20, 22), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "WESTSIDE BOXING", { font = Enum.Font.Bangers, color = C(230, 40, 40), stroke = 0, strokeColor = C(255, 255, 255), pps = 10, dist = 300, light = 0.6 })
		L.sideAd(S2.left, Enum.NormalId.Left, "TRAIN HARD • STAY UP")
		L.graffiti(S2.right, Enum.NormalId.Right)
		L.footprint(LMh, cf, w, d)
		L.lod(m)
		pcall(function() L.poi((cf * CFrame.new(0, 0, bz - bd / 2 - 4)).Position, "Job", "Westside Boxing", { Job = "Sparring Partner", Pay = 50 }) end)
	end
	-- Fresh Cutz barbershop + Liberty Sound studio (walk-in)
	do
		local cf, w, d = lot(470, 100, 60)
		L.shop(LMh, cf, w, d, { units = 2, floors = 2, rundown = true, interior = true, signs = { "FRESH CUTZ BARBER SHOP", "LIBERTY SOUND STUDIO" }, billboard = true })
		L.footprint(LMh, cf, w, d)
		pcall(function()
			L.poi((cf * CFrame.new(-25, 0, -d / 2 + 6)).Position, "Job", "Fresh Cutz", { Job = "Barber", Pay = 55 })
			L.poi((cf * CFrame.new(25, 0, -d / 2 + 6)).Position, "Job", "Liberty Sound Studio", { Job = "Music Producer", Pay = 70 })
		end)
	end
	-- Westside car meet: big lot with string lights, a food truck, speakers, painted wall
	do
		local cf, w, d = lot(710, 230, 100)
		local m = L.model(LMh, "WestsideCarMeet")
		L.BD(m, cf, 0, 0.03, 0, w - 1, 0.15, d - 1, C(70, 72, 76), M.Asphalt, "ParkingLotAsphalt")
		for x = -w / 2 + 14, w / 2 - 14, 14 do L.BD(m, cf, x, 0.19, d / 2 - 18, 0.4, 0.02, 26, C(220, 214, 196), M.SmoothPlastic, nil, { Transparency = 0.3 }) end
		local wl = L.B(m, cf, 0, 0, d / 2 - 2, w - 4, 14, 1.6, C(200, 196, 186), M.Concrete, "HoodConcreteDirty")
		L.piece(wl, Enum.NormalId.Front)
		L.piece(wl, Enum.NormalId.Front)
		L.text(wl, Enum.NormalId.Front, "WESTSIDE MEET", { font = Enum.Font.Bangers, color = C(80, 200, 255), stroke = 0, size = UDim2.fromScale(0.3, 0.3), pos = UDim2.fromScale(0.35, 0.05), pps = 6, dist = 400, light = 1 })
		-- light poles with string lights between them
		local poles = {}
		for k = 0, 4 do
			local p = (cf * CFrame.new(-w / 2 + 10 + k * (w - 20) / 4, 0, 0)).Position
			L.Cyl(m, 18, 0.7, CFrame.new(p + Vector3.new(0, 9, 0)), C(60, 62, 66), M.Metal)
			table.insert(poles, p + Vector3.new(0, 17.5, 0))
		end
		for k = 1, #poles - 1 do
			local a, b = poles[k], poles[k + 1]
			L.bar(m, a, b, 0.15, C(30, 30, 30), M.Rubber)
			for j = 1, 6 do L.D(m, Vector3.new(0.7, 0.7, 0.7), CFrame.new(a:Lerp(b, j / 7) - Vector3.new(0, 0.8, 0)), C(255, 214, 140), M.Neon) end
		end
		-- food truck
		local fc = cf * CFrame.new(w / 2 - 22, 0, 20)
		L.B(m, fc, 0, 1.6, 0, 9, 9, 22, C(250, 200, 40), M.SmoothPlastic)
		L.BD(m, fc, -4.6, 4.5, 2, 0.2, 3.2, 12, C(30, 30, 34), M.Glass)
		L.P(m, Vector3.new(3, 0.3, 13), fc * CFrame.new(-6, 8.2, 2) * CFrame.Angles(0, 0, math.rad(-14)), C(200, 30, 30), M.Fabric)
		for _, z in ipairs({ -7, 7 }) do for _, sd in ipairs({ -1, 1 }) do
			local wh = L.P(m, Vector3.new(1.2, 3.2, 3.2), fc * CFrame.new(sd * 4.6, 1.6, z), C(26, 26, 26), M.Rubber) wh.Shape = Enum.PartType.Cylinder
		end end
		local ts = L.BD(m, fc, -4.65, 8.2, 2, 0.1, 1.6, 14, C(200, 30, 30), M.SmoothPlastic)
		L.text(ts, Enum.NormalId.Left, "WINGS • FRIES • ICE", { font = Enum.Font.GothamBlack, color = C(255, 255, 255), pps = 20, dist = 200 })
		-- speaker stack
		for k = 0, 1 do L.B(m, cf, -w / 2 + 14, k * 4, d / 2 - 8, 4, 4, 3, C(24, 24, 26), M.SmoothPlastic) end
		-- a few cars already parked for the meet
		for _ = 1, 5 do
			local x = -w / 2 + 14 + 14 * L.ri(0, math.floor((w - 28) / 14) - 1) + 7
			L.supercar(m, cf * CFrame.new(x, 0.2, d / 2 - 18) * CFrame.Angles(0, math.pi, 0), L.pick({ C(230, 40, 40), C(250, 200, 30), C(30, 30, 34), C(40, 120, 220), C(240, 240, 238) }))
		end
		L.footprint(LMh, cf, w, d)
		L.lod(m)
		pcall(function() L.poi((cf * CFrame.new(0, 0, 0)).Position, "Park", "Westside Car Meet", { Note = "Pull up and show off" }) end)
	end

	-- ===== 5. fill the rest: The Ends style lots =====
	local built = L.fill(Bh, net, function(x, z, st, side, e)
		if x < X0 or x > X1 + 4 or z < Z0 or z > Z1 then return nil end
		local r = L.rng:NextNumber()
		if r < 0.42 then return { kind = "house", w = L.r(40, 48), d = L.r(42, 48), opts = { abandoned = L.chance(0.2), carChance = 0.35, tagChance = 0.4, twoChance = 0.4 }, gap = L.r(0, 3) } end
		if r < 0.58 then return { kind = "walkup", w = L.r(52, 64), d = 50, opts = { rundown = true } } end
		if r < 0.66 then return { kind = "midrise", w = L.r(52, 62), d = 54 } end
		if r < 0.74 then return { kind = "shop", w = L.r(38, 50), d = 48, opts = { rundown = true, floors = L.pick({ 1, 2, 2, 3 }) } } end
		if r < 0.82 then return { kind = "court", w = 56, d = 80 } end
		if r < 0.9 then return { kind = "bays", w = L.r(54, 64), d = 56 } end
		return { kind = "emptyLot", w = L.r(30, 44), d = 46 }
	end, function(x, z) return x > X0 and x < X1 + 4 and z > Z0 and z < Z1 end)

	-- ===== 6. more courts in the old hood: swap a few empty lots for fenced courts =====
	local swapped = 0
	local HB = VB.Buildings:FindFirstChild("Hood")
	if HB then
		local empties = {}
		for _, m in ipairs(HB:GetChildren()) do if m:IsA("Model") and m.Name == "EmptyLot" then table.insert(empties, m) end end
		for i = 1, #empties do
			if swapped >= 4 then break end
			local m = empties[i]
			local cf, size = m:GetBoundingBox()
			if size.X >= 40 and size.Z >= 40 and i % 3 == 1 then
				local flat = CFrame.new(cf.Position.X, G, cf.Position.Z) * (cf - cf.Position)
				local w2, d2 = size.X, size.Z
				if w2 > d2 then flat = flat * CFrame.Angles(0, math.pi / 2, 0) w2, d2 = d2, w2 end
				m:Destroy()
				L.court(HB, flat, math.min(w2, 56), d2)
				pcall(function() L.poi(flat.Position, "Park", "Pickup Court") end)
				swapped += 1
			end
		end
	end

	local parts = 0
	for _, f in ipairs({ LMh, Bh, VB:FindFirstChild("HoodWest") }) do for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	return string.format("Westside: removed %d mangrove items, lots %d, courts swapped %d, parts %d (%.1fs)", removed, built, swapped, parts, os.clock() - t0)
end
