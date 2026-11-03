-- 05 Bayside Central Park: x -80..300, z -690..10 (Flagler crosses it). Lawns, a lake with an island,
-- a hill with a lookout, courts, a dog park, a bandshell, a fountain plaza, jogging loop, lots of real trees.
return function(L)
	local M, C = L.M, L.C
	local T = workspace.Terrain
	local G = L.G
	local P = L.root("Parks")
	local old = P:FindFirstChild("BaysideCentralPark")
	if old then old:Destroy() end
	local park = L.model(P, "BaysideCentralPark")
	L.seed(2024)
	local X0, X1 = -33, 246
	local NZ0, NZ1 = -655, -456 -- north half (inside the widened streets)
	local SZ0, SZ1 = -364, -26 -- south half
	local function at(x, z, yaw) return CFrame.new(x, G, z) * CFrame.Angles(0, yaw or 0, 0) end

	-- ===== ground: lawn =====
	local function lawn(x0, x1, z0, z1)
		T:ReplaceMaterial(Region3.new(Vector3.new(x0, -8, z0), Vector3.new(x1, 4, z1)):ExpandToGrid(4), 4, M.Concrete, M.LeafyGrass)
		T:ReplaceMaterial(Region3.new(Vector3.new(x0, -8, z0), Vector3.new(x1, 4, z1)):ExpandToGrid(4), 4, M.Ground, M.LeafyGrass)
	end
	lawn(X0, X1, NZ0, NZ1)
	lawn(X0, X1, SZ0, SZ1)

	-- ===== elevation: a grassy hill in the north half with a lookout gazebo =====
	local hill = Vector3.new(185, 0, -560)
	T:FillBall(Vector3.new(hill.X, -48, hill.Z), 70, M.LeafyGrass)
	T:FillBall(Vector3.new(hill.X - 30, -40, hill.Z + 20), 52, M.LeafyGrass)
	task.wait()
	local topY = L.groundY(hill.X, hill.Z)
	do
		local g = L.model(park, "Lookout")
		local c = CFrame.new(hill.X, topY - 0.3, hill.Z)
		L.Cyl(g, 1, 22, c * CFrame.new(0, 0.5, 0), C(186, 180, 170), M.Concrete, "ConcretePlain")
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			L.Cyl(g, 11, 0.8, c * CFrame.new(math.cos(a) * 9, 6.5, math.sin(a) * 9), C(240, 238, 232), M.Wood)
		end
		L.Cyl(g, 1, 23, c * CFrame.new(0, 12.2, 0), C(240, 238, 232), M.Wood)
		L.Cyl(g, 3, 16, c * CFrame.new(0, 14, 0), C(150, 84, 64), M.ClayRoofTiles, "RoofClayMission")
		L.Cyl(g, 2, 8, c * CFrame.new(0, 16.4, 0), C(150, 84, 64), M.ClayRoofTiles, "RoofClayMission")
		for k = 0, 2 do L.bench(g, c * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0, 1, 5)) end
		L.poi(Vector3.new(hill.X, topY, hill.Z), "Park", "Lookout Hill")
	end

	-- ===== the lake (sunken, with an island) in the south half =====
	local lake = Vector3.new(105, 0, -205)
	local LRX, LRZ = 72, 56
	for x = -LRX, LRX, 4 do
		local hz = LRZ * math.sqrt(math.max(0, 1 - (x / LRX) ^ 2))
		if hz > 2 then
			-- grid-aligned regions (FillBlock with off-grid heights leaves partial cells that render as solid)
			local x0, z0, z1 = lake.X + x - 2, lake.Z - hz, lake.Z + hz
			T:FillRegion(Region3.new(Vector3.new(x0, -4, z0), Vector3.new(x0 + 4, 8, z1)):ExpandToGrid(4), 4, M.Air)
			T:FillRegion(Region3.new(Vector3.new(x0, -12, z0), Vector3.new(x0 + 4, -4, z1)):ExpandToGrid(4), 4, M.Water)
			T:FillRegion(Region3.new(Vector3.new(x0, -16, z0), Vector3.new(x0 + 4, -12, z1)):ExpandToGrid(4), 4, M.Mud)
		end
	end
	-- island
	T:FillBall(Vector3.new(lake.X + 18, -16, lake.Z - 8), 18, M.LeafyGrass)
	task.wait()
	-- stone edge around the lake
	local edge = L.model(park, "LakeEdge")
	local n = 48
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		local p0 = Vector3.new(lake.X + math.cos(a0) * (LRX + 1), G - 1.2, lake.Z + math.sin(a0) * (LRZ + 1))
		local p1 = Vector3.new(lake.X + math.cos(a1) * (LRX + 1), G - 1.2, lake.Z + math.sin(a1) * (LRZ + 1))
		L.P(edge, Vector3.new(3, 3, (p1 - p0).Magnitude + 0.6), CFrame.lookAt((p0 + p1) / 2, p1), C(170, 164, 150), M.Rock, "RockGrey")
	end
	for _ = 1, 3 do L.palm(park, Vector3.new(lake.X + 18 + L.r(-6, 6), G + 1, lake.Z - 8 + L.r(-5, 5)), L.r(30, 40), "hero") end

	-- ===== paths =====
	local paths = L.model(park, "Paths")
	local segs = {}
	local function path(a, b, w, var, col)
		local len = (b - a).Magnitude
		local p = L.P(paths, Vector3.new(w, 0.4, len + w * 0.5), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.05, 0), col or C(196, 186, 168), M.Concrete, var or "DowntownPavers")
		p.Name = "Path"
		table.insert(segs, { a, b, w })
		return p
	end
	local function loop(c, rx, rz, w, var, col, n2)
		n2 = n2 or 40
		local pts = {}
		for k = 0, n2 do
			local a = k / n2 * math.pi * 2
			pts[k] = Vector3.new(c.X + math.cos(a) * rx, G, c.Z + math.sin(a) * rz)
		end
		for k = 0, n2 - 1 do path(pts[k], pts[k + 1], w, var, col) end
		return pts
	end
	-- jogging loop around the lake
	local lp = loop(lake, LRX + 18, LRZ + 18, 7, "DowntownPavers")
	-- promenade from NW 17 St (south entrance) to the lake, and from Flagler (north) to the lake
	path(Vector3.new(lake.X, G, SZ1 + 2), Vector3.new(lake.X, G, lake.Z + LRZ + 18), 14, "HerringbonePavers", C(206, 190, 170))
	path(Vector3.new(lake.X, G, SZ0 - 2), Vector3.new(lake.X, G, lake.Z - LRZ - 18), 12, "HerringbonePavers", C(206, 190, 170))
	-- side entrances from Miami Ave and Biscayne Blvd
	path(Vector3.new(X0 - 2, G, lake.Z), Vector3.new(lake.X - LRX - 18, G, lake.Z), 8)
	path(Vector3.new(X1 + 2, G, -120), Vector3.new(lake.X + LRX + 12, G, -150), 8)
	-- north half: loop around the hill + cross path
	loop(hill, 62, 58, 6, "ParkDirt", C(160, 136, 104), 32)
	path(Vector3.new(X0 - 2, G, -553), Vector3.new(hill.X - 62, G, -553), 7)
	path(Vector3.new(105, G, NZ1 + 2), Vector3.new(105, G, -520), 8)

	-- ===== fountain plaza at the south entrance =====
	do
		local f = L.model(park, "Fountain")
		local c = CFrame.new(lake.X, G, -62)
		L.Cyl(f, 0.4, 46, c * CFrame.new(0, 0.2, 0), C(210, 200, 184), M.Concrete, "PlazaTiles")
		L.Cyl(f, 2.2, 26, c * CFrame.new(0, 1.1, 0), C(226, 220, 208), M.Concrete, "DowntownStoneBlocks")
		L.Cyl(f, 0.3, 24, c * CFrame.new(0, 1.9, 0), C(60, 130, 150), M.Glass, nil, { Transparency = 0.25, CanCollide = false })
		L.Cyl(f, 6, 3, c * CFrame.new(0, 4, 0), C(226, 220, 208), M.Concrete, "DowntownStoneBlocks")
		L.Cyl(f, 0.8, 10, c * CFrame.new(0, 6.5, 0), C(226, 220, 208), M.Concrete, "DowntownStoneBlocks")
		local jet = L.D(f, Vector3.new(1, 1, 1), c * CFrame.new(0, 7.2, 0), C(200, 230, 240), M.Glass, nil, { Transparency = 1 })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(210, 235, 245))
		pe.Size = NumberSequence.new(0.6, 1.4)
		pe.Transparency = NumberSequence.new(0.3, 1)
		pe.Lifetime = NumberRange.new(0.9, 1.3)
		pe.Rate = 60
		pe.Speed = NumberRange.new(16, 20)
		pe.SpreadAngle = Vector2.new(12, 12)
		pe.Acceleration = Vector3.new(0, -40, 0)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = jet
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			L.bench(f, c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 19) * CFrame.Angles(0, math.pi, 0))
		end
		-- entrance sign
		local sg = L.B(f, at(lake.X - 26, SZ1 - 3), 0, 0, 0, 22, 4, 2, C(196, 190, 176), M.Concrete, "DowntownStoneBlocks")
		L.text(sg, Enum.NormalId.Back, "BAYSIDE CENTRAL PARK", { font = Enum.Font.Merriweather, color = C(40, 50, 40), pps = 18, light = 1 })
		L.text(sg, Enum.NormalId.Front, "BAYSIDE CENTRAL PARK", { font = Enum.Font.Merriweather, color = C(40, 50, 40), pps = 18, light = 1 })
		L.poi(Vector3.new(lake.X, G, -62), "Park", "Bayside Central Park")
		-- hot dog cart (job)
		local hc = c * CFrame.new(26, 0, 6) * CFrame.Angles(0, -0.4, 0)
		L.B(f, hc, 0, 1.2, 0, 6, 3.4, 3, C(230, 230, 228), M.Metal, "PaintedMetalA")
		L.Cyl(f, 0.4, 2.2, hc * CFrame.new(-2.2, 1.1, 1.6) * CFrame.Angles(math.pi / 2, 0, 0), C(30, 30, 30), M.Rubber)
		L.D(f, Vector3.new(0.2, 5, 0.2), hc * CFrame.new(0, 7, 0), C(200, 200, 200), M.Metal)
		L.D(f, Vector3.new(7, 0.3, 6), hc * CFrame.new(0, 9.5, 0), C(220, 50, 40), M.Fabric)
		L.poi((hc * CFrame.new(0, 0, -3)).Position, "Job", "Hot Dog Cart", { Job = "Vendor", Pay = 45 })
	end

	-- ===== bandshell on the east lawn =====
	do
		local b = L.model(park, "Bandshell")
		local c = at(228, -205, math.pi / 2) -- faces west toward the lake
		L.B(b, c, 0, 0, 0, 34, 3, 18, C(214, 208, 196), M.Concrete, "ConcretePlain")
		for k = -4, 4 do
			local a = k / 4 * 1.15
			L.P(b, Vector3.new(4.6, 22, 1), c * CFrame.new(math.sin(a) * 16, 14, 8 - math.cos(a) * 10) * CFrame.Angles(0, -a, 0), C(244, 242, 236), M.Concrete, "StuccoWhite")
		end
		L.P(b, Vector3.new(34, 1, 22), c * CFrame.new(0, 25.5, 2) * CFrame.Angles(math.rad(-10), 0, 0), C(244, 242, 236), M.Concrete, "StuccoWhite")
		L.D(b, Vector3.new(30, 0.3, 0.3), c * CFrame.new(0, 24.4, -8), C(255, 230, 190), M.Neon)
		for r = 1, 4 do
			for k = -2, 2 do L.bench(b, c * CFrame.new(k * 7, 0, -14 - r * 6)) end
		end
		L.poi((c * CFrame.new(0, 3, 0)).Position, "Park", "Bayside Bandshell", nil, { noPrompt = true })
	end

	-- ===== north half: courts + dog park =====
	L.court(park, at(8, -553), 56, 86)
	do
		-- pickleball / tennis pair
		local t = L.model(park, "TennisCourts")
		local c = at(78, -553)
		L.BD(t, c, 0, 0.03, 0, 40, 0.2, 86, C(70, 120, 90), M.Concrete, "ConcretePlain")
		for _, z in ipairs({ -21, 21 }) do
			L.BD(t, c, 0, 0.24, z, 30, 0.02, 38, C(60, 100, 150), M.Concrete)
			L.BD(t, c, 0, 0.24, z, 30, 3.2, 0.2, C(240, 240, 240), M.Fabric, nil, { Transparency = 0.5 })
		end
		local a = (c * CFrame.new(-20, 0, -43)).Position
		local b = (c * CFrame.new(20, 0, -43)).Position
		local d = (c * CFrame.new(20, 0, 43)).Position
		local e = (c * CFrame.new(-20, 0, 43)).Position
		L.fence(t, a, b, 10, "chain"); L.fence(t, b, d, 10, "chain"); L.fence(t, d, e, 10, "chain"); L.fence(t, e, a, 10, "chain")
	end
	do
		local dp = L.model(park, "DogPark")
		local c = at(60, -470)
		L.BD(dp, c, 0, 0.03, 0, 70, 0.15, 36, C(140, 120, 90), M.Ground, "ParkDirt")
		local a = (c * CFrame.new(-35, 0, -18)).Position
		local b = (c * CFrame.new(35, 0, -18)).Position
		local d = (c * CFrame.new(35, 0, 18)).Position
		local e = (c * CFrame.new(-35, 0, 18)).Position
		L.fence(dp, a, b, 5, "iron"); L.fence(dp, b, d, 5, "iron"); L.fence(dp, d, e, 5, "iron"); L.fence(dp, e, a, 5, "iron")
		L.sign(dp, c * CFrame.new(0, 6, -18.5), 12, 2.4, "DOG PARK", C(40, 90, 60), C(255, 255, 255), Enum.Font.GothamBold, {})
	end
	-- playground in the south-west corner
	do
		local pg = L.model(park, "Playground")
		local c = at(2, -330)
		L.BD(pg, c, 0, 0.03, 0, 44, 0.3, 40, C(170, 80, 60), M.Rubber)
		L.B(pg, c, -8, 0, 0, 12, 7, 12, C(40, 120, 200), M.Plastic)
		L.B(pg, c, -8, 7, 0, 13, 0.6, 13, C(250, 200, 40), M.Plastic)
		L.W(pg, Vector3.new(3, 7, 14), c * CFrame.new(-8, 3.5, 13) * CFrame.Angles(0, math.pi, 0), C(220, 60, 50), M.Plastic)
		for _, x in ipairs({ 8, 18 }) do
			L.B(pg, c, x, 0, -10, 0.5, 10, 0.5, C(60, 60, 64), M.Metal)
			L.B(pg, c, x, 0, 10, 0.5, 10, 0.5, C(60, 60, 64), M.Metal)
		end
		L.B(pg, c, 13, 9.6, 0, 11, 0.5, 21, C(60, 60, 64), M.Metal)
		for _, z in ipairs({ -4, 4 }) do L.B(pg, c, 13, 2.2, z, 2.4, 0.3, 1.2, C(30, 30, 30), M.Rubber) end
	end

	-- ===== perimeter hedges (gaps at entrances) =====
	local function hedgeRun(a, b, gaps)
		local d = (b - a)
		local len = d.Magnitude
		local dir = d.Unit
		local s = 0
		while s < len do
			local p = a + dir * s
			local blocked = false
			for _, g in ipairs(gaps or {}) do if (p - g).Magnitude < 14 then blocked = true end end
			if not blocked then L.bush(park, p, L.r(4, 6)) end
			s += L.r(7, 10)
		end
	end
	local function v(x, z) return Vector3.new(x, G, z) end
	hedgeRun(v(X0, NZ0), v(X1, NZ0), { v(80, NZ0) })
	hedgeRun(v(X0, NZ0), v(X0, NZ1), { v(X0, -553) })
	hedgeRun(v(X1, NZ0), v(X1, NZ1), {})
	hedgeRun(v(X0, NZ1), v(X1, NZ1), { v(105, NZ1) })
	hedgeRun(v(X0, SZ0), v(X1, SZ0), { v(105, SZ0) })
	hedgeRun(v(X0, SZ0), v(X0, SZ1), { v(X0, lake.Z) })
	hedgeRun(v(X1, SZ0), v(X1, SZ1), { v(X1, -120) })
	hedgeRun(v(X0, SZ1), v(X1, SZ1), { v(lake.X, SZ1), v(lake.X - 26, SZ1) })

	-- ===== trees: lots of them, kept off paths, the lake, courts and structures =====
	local function nearPath(p, pad)
		for _, s in ipairs(segs) do
			local a, b, w = s[1], s[2], s[3]
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			if (p - (a + ab * t)).Magnitude < w / 2 + pad then return true end
		end
		return false
	end
	local blockers = {
		{ lake.X, lake.Z, LRX + 10, LRZ + 10, "ellipse" },
		{ hill.X, hill.Z, 16, 16, "ellipse" },
		{ lake.X, -62, 30, 30, "ellipse" },
		{ 214, -205, 28, 22, "box" },
		{ 8, -553, 32, 46, "box" }, { 78, -553, 24, 46, "box" }, { 60, -470, 38, 22, "box" }, { 2, -330, 26, 24, "box" },
	}
	local function blocked(p)
		for _, b in ipairs(blockers) do
			local dx, dz = p.X - b[1], p.Z - b[2]
			if b[5] == "ellipse" then
				if (dx / b[3]) ^ 2 + (dz / b[4]) ^ 2 < 1 then return true end
			elseif math.abs(dx) < b[3] and math.abs(dz) < b[4] then return true end
		end
		return nearPath(p, 5)
	end
	local trees = L.model(park, "Trees")
	local placed = {}
	local function place(x0, x1, z0, z1, n2)
		local tries = 0
		while n2 > 0 and tries < n2 * 12 do
			tries += 1
			local p = Vector3.new(L.r(x0 + 6, x1 - 6), 0, L.r(z0 + 6, z1 - 6))
			local ok = not blocked(p)
			if ok then for _, q in ipairs(placed) do if (q - p).Magnitude < 15 then ok = false break end end end
			if ok then
				local y = L.groundY(p.X, p.Z)
				local pos = Vector3.new(p.X, y, p.Z)
				local r = L.rng:NextNumber()
				if r < 0.55 then L.tree(trees, pos, L.r(0.9, 1.5))
				elseif r < 0.85 then L.palm(trees, pos, L.r(30, 46))
				else L.palm(trees, pos, L.r(34, 44), "hero") end
				if L.chance(0.35) then L.bush(trees, pos + Vector3.new(L.r(-5, 5), 0, L.r(-5, 5)), L.r(3, 6)) end
				table.insert(placed, p)
				n2 -= 1
			end
			if tries % 25 == 0 then task.wait() end
		end
	end
	place(X0, X1, NZ0, NZ1, 55)
	place(X0, X1, SZ0, SZ1, 95)
	-- lamps + benches along the lake loop
	for k = 0, #lp - 1, 4 do
		local p = lp[k]
		local toLake = (lake - Vector3.new(p.X, 0, p.Z)).Unit
		local out = p - toLake * 6
		local m = L.model(park, "ParkLamp")
		L.Cyl(m, 12, 0.5, CFrame.new(out + Vector3.new(0, 6, 0)), C(30, 34, 32), M.Metal)
		L.D(m, Vector3.new(1.4, 1.8, 1.4), CFrame.new(out + Vector3.new(0, 12.6, 0)), C(255, 236, 200), M.Neon)
		local bp = p + toLake * 5.5
		L.bench(park, CFrame.lookAt(bp, bp - toLake))
	end
	local parts = 0
	for _, d in ipairs(park:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "park ok, trees " .. #placed .. ", parts " .. parts
end
