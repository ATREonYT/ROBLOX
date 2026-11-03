-- 13 Coral County: the suburbs west of the glades, across the Coral Causeway.
-- Real elevation (smooth heightmap hills written with WriteVoxels), a hilltop villa district (Coral Heights)
-- reached by a winding road, a suburban grid with strip malls / fire station / church, a golf club, a beach town,
-- and an airboat dock in the glades.
return function(L)
	local M, C = L.M, L.C
	local G, WATER = L.G, L.WATER
	local T = workspace.Terrain
	local VB = L.folder(workspace, "ViceBay")
	for _, n in ipairs({ "CountyRoads", "County3D", "CoralCauseway" }) do
		local f = VB:FindFirstChild(n)
		if f then f:Destroy() end
	end
	local LMc = L.folder(L.folder(VB, "Landmarks"), "County")
	local Bc = L.folder(L.folder(VB, "Buildings"), "County")
	LMc:ClearAllChildren()
	Bc:ClearAllChildren()
	local R3 = L.folder(VB, "County3D")
	local CW = L.folder(VB, "CoralCauseway")
	if not table.find(L.FILL_BLOCKERS, "County3D") then table.insert(L.FILL_BLOCKERS, "County3D") end
	L.seed(4040)
	local t0 = os.clock()

	-- ===== 1. ocean + base land =====
	local fill = function(x0, x1, y0, y1, z0, z1, mat)
		local step = 512
		local x = x0
		while x < x1 do
			local z = z0
			local xe = math.min(x1, x + step)
			while z < z1 do
				local ze = math.min(z1, z + step)
				T:FillBlock(CFrame.new((x + xe) / 2, (y0 + y1) / 2, (z + ze) / 2), Vector3.new(xe - x, y1 - y0, ze - z), mat)
				z = ze
			end
			x = xe
			task.wait()
		end
	end
	fill(-5400, -2600, -24, -12, -1900, 2200, M.Sand)
	fill(-5400, -2600, -12, -4, -1900, 2200, M.Water)
	fill(-4720, -2330, -12, -4, -1650, 1650, M.Ground)
	fill(-4720, -2330, -4, 0, -1650, 1650, M.Grass)
	fill(-4900, -4720, -12, 0, -1650, 1650, M.Sand)
	for k = 0, 4 do
		local x1 = -4900 - k * 20
		fill(x1 - 20, x1, -12, -(k + 1) * 2, -1650, 1650, M.Sand)
	end

	-- ===== 2. hills, roads-on-hills and building pads (one heightmap so everything sits on the ground) =====
	local function sm(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
	local HILLS = {
		{ -3950, -1130, 280, 72 }, -- Coral Heights
		{ -4150, 450, 260, 46 },
		{ -4200, 1110, 200, 34 },
	}
	local function hillH(x, z)
		local hmax = 0
		for _, h in ipairs(HILLS) do
			local r = math.sqrt((x - h[1]) ^ 2 + (z - h[2]) ^ 2)
			if r < h[3] then hmax = math.max(hmax, h[4] * sm(1 - r / h[3])) end
		end
		return G + hmax
	end
	-- Catmull-Rom smoothing of a control polyline into ~step-stud points
	local function spline(ctrl, step)
		local out = {}
		for i = 1, #ctrl - 1 do
			local p0, p1, p2, p3 = ctrl[math.max(1, i - 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(#ctrl, i + 2)]
			local n = math.max(1, math.floor((p2 - p1).Magnitude / step))
			for k = 0, n - 1 do
				local t = k / n
				local t2, t3 = t * t, t * t * t
				table.insert(out, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
			end
		end
		table.insert(out, ctrl[#ctrl])
		return out
	end
	local function drape(pts, flatEnds)
		-- y follows the hills, smoothed so the grade never jumps
		local ys = {}
		for i, p in ipairs(pts) do ys[i] = hillH(p.X, p.Z) end
		for _ = 1, 4 do
			local n = {}
			for i = 1, #ys do n[i] = (ys[math.max(1, i - 1)] + ys[i] * 2 + ys[math.min(#ys, i + 1)]) / 4 end
			ys = n
		end
		local out = {}
		for i, p in ipairs(pts) do
			local y = ys[i]
			if flatEnds and (i <= 2 or i >= #pts - 1) then y = G end
			out[i] = Vector3.new(p.X, y + 0.3, p.Z)
		end
		return out
	end

	-- Coral Heights: access road north from Coral Blvd, then a 1.6-turn spiral to the summit
	local HC = HILLS[1]
	local ctrl = { Vector3.new(-3900, 0, -436), Vector3.new(-3900, 0, -640), Vector3.new(-3905, 0, -790) }
	local turns, r0, r1 = 1.6, HC[3] + 20, 52
	local a0 = math.pi / 2 - 0.3
	for k = 0, 40 do
		local t = k / 40
		local a = a0 - t * turns * math.pi * 2
		local r = r0 + (r1 - r0) * t
		table.insert(ctrl, Vector3.new(HC[1] + math.cos(a) * r, 0, HC[2] + math.sin(a) * r))
	end
	local heights = drape(spline(ctrl, 18), false)
	heights[1] = Vector3.new(heights[1].X, G + 0.3, heights[1].Z)
	-- the summit is a flat circle at the road's final height
	local topY = heights[#heights].Y - 0.3
	-- County Rd 1: Coral Blvd south through the hills to Ocean Dr
	local cr1 = drape(spline({
		Vector3.new(-3800, 0, -384), Vector3.new(-3790, 0, -250), Vector3.new(-3850, 0, -60), Vector3.new(-3960, 0, 120),
		Vector3.new(-4040, 0, 300), Vector3.new(-4010, 0, 500), Vector3.new(-4090, 0, 700), Vector3.new(-4250, 0, 820),
		Vector3.new(-4430, 0, 870), Vector3.new(-4626, 0, 900),
	}, 20), true)
	local CORR = { { pts = heights, hw = 16 }, { pts = cr1, hw = 17 } }

	-- villa pads along the outside of the spiral
	local PADS = {}
	local acc, nextAt = 0, 380
	for i = 2, #heights - 1 do
		acc += (heights[i] - heights[i - 1]).Magnitude
		if acc > nextAt and acc < 0.92 * (function() local s = 0 for k = 2, #heights do s += (heights[k] - heights[k - 1]).Magnitude end return s end)() then
			nextAt = acc + 230
			local p = heights[i]
			local dirv = (heights[i + 1] - heights[i - 1]) * Vector3.new(1, 0, 1)
			dirv = dirv.Unit
			local out = Vector3.new(p.X - HC[1], 0, p.Z - HC[2]).Unit
			local c = Vector3.new(p.X, 0, p.Z) + out * 54
			if c.X < -3720 then table.insert(PADS, { c = c, y = p.Y - 0.3, w = 80, d = 66, face = Vector3.new(p.X, 0, p.Z), dir = dirv }) end
		end
	end
	local function padH(x, z, H)
		for _, pd in ipairs(PADS) do
			local f = (pd.face - pd.c).Unit
			local rgt = Vector3.new(-f.Z, 0, f.X)
			local v = Vector3.new(x - pd.c.X, 0, z - pd.c.Z)
			local lx, lz = math.abs(v:Dot(rgt)) - pd.w / 2, math.abs(v:Dot(f)) - pd.d / 2
			local dd = math.max(lx, lz)
			if dd < 0 then return pd.y end
			if dd < 14 then H = H + (pd.y - H) * (1 - sm(dd / 14)) end
		end
		-- summit
		local rs = math.sqrt((x - HC[1]) ^ 2 + (z - HC[2]) ^ 2)
		if rs < 70 then return topY end
		if rs < 86 then H = H + (topY - H) * (1 - sm((rs - 70) / 16)) end
		return H
	end
	local function corrH(x, z, H)
		for _, c in ipairs(CORR) do
			local best, by = 1e9, nil
			local P = c.pts
			for i = 1, #P - 1 do
				local a, b = P[i], P[i + 1]
				local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				local ap = Vector3.new(x - a.X, 0, z - a.Z)
				local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
				local q = Vector3.new(a.X + ab.X * t, 0, a.Z + ab.Z * t)
				local dd = (Vector3.new(x, 0, z) - q).Magnitude
				if dd < best then best, by = dd, a.Y + (b.Y - a.Y) * t end
			end
			if by then
				local ry = by - 0.9
				if best < c.hw + 2 then H = ry
				elseif best < c.hw + 22 then H = H + (ry - H) * (1 - sm((best - c.hw - 2) / 20)) end
			end
		end
		return H
	end
	local function finalH(x, z)
		local H = hillH(x, z)
		H = padH(x, z, H)
		H = corrH(x, z, H)
		return H
	end
	-- write voxels chunk by chunk over every hill's bounding box
	local function writeArea(x0, x1, z0, z1)
		local YB, YT = -12, 88
		for cx = x0, x1 - 1, 128 do
			for cz = z0, z1 - 1, 128 do
				local reg = Region3.new(Vector3.new(cx, YB, cz), Vector3.new(cx + 128, YT, cz + 128)):ExpandToGrid(4)
				local nx, ny, nz = 32, (YT - YB) / 4, 32
				local hm = {}
				for i = 0, nx + 1 do
					hm[i] = {}
					for k = 0, nz + 1 do hm[i][k] = finalH(cx + (i - 0.5) * 4, cz + (k - 0.5) * 4) end
				end
				local mats, occ = {}, {}
				for i = 1, nx do
					mats[i], occ[i] = {}, {}
					for j = 1, ny do mats[i][j], occ[i][j] = {}, {} end
					for k = 1, nz do
						local H = hm[i][k]
						local g = math.abs(hm[i + 1][k] - hm[i - 1][k]) + math.abs(hm[i][k + 1] - hm[i][k - 1])
						local top = (g > 16) and M.Rock or (((g > 9) or (H > 24 and (i * 7 + k * 3) % 5 == 0)) and M.LeafyGrass or M.Grass)
						for j = 1, ny do
							local yb = YB + (j - 1) * 4
							local o = math.clamp((H - 2 - yb) / 4, 0, 1) -- same convention as FillBlock-to-y0 (renders at y=2)
							occ[i][j][k] = o
							if o <= 0 then mats[i][j][k] = M.Air
							elseif H - yb > 8 then mats[i][j][k] = (g > 16) and M.Rock or M.Ground
							else mats[i][j][k] = top end
						end
					end
				end
				T:WriteVoxels(reg, 4, mats, occ)
				task.wait()
			end
		end
	end
	for _, h in ipairs(HILLS) do
		local pad = h[3] + 40
		writeArea(math.floor((h[1] - pad) / 128) * 128, math.ceil((h[1] + pad) / 128) * 128, math.floor((h[2] - pad) / 128) * 128, math.ceil((h[2] + pad) / 128) * 128)
	end
	-- flat parts of County Rd 1 between the hills also get their corridor (cheap: terrain there is flat at G already)

	-- ===== 3. the roads =====
	-- Coral Causeway: Flagler St W -> across the glades -> arch over the channel -> Coral Blvd
	local cpts = {}
	-- gentle bridge: cosine profile (zero slope at both ends), 16 studs clearance, max grade ~8 degrees
	for x = -1820, -2380, -16 do
		local y = G + 0.3
		local x0, x1 = -1995, -2375
		if x < x0 and x > x1 then
			local t = (x0 - x) / (x0 - x1)
			y = G + 0.3 + 16 * (1 - math.cos(2 * math.pi * t)) / 2
		end
		table.insert(cpts, Vector3.new(x, y, -410))
	end
	L.road3D(CW, cpts, 64, { name = "Coral Causeway", median = true, lanes = 2, lights = 120, pierStep = 50, var = "AsphaltPlain" })
	L.cutSidewalk(CFrame.new(-1826, G + 0.5, -410), Vector3.new(24, 3, 68))
	-- clear any mainland lot the causeway now runs through (glades edge west of Glades Rd)
	do
		local cop = OverlapParams.new()
		cop.FilterType = Enum.RaycastFilterType.Include
		cop.FilterDescendantsInstances = { VB:FindFirstChild("Buildings") }
		local dead = {}
		for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(-1925, G + 4, -410), Vector3.new(250, 8, 46), cop)) do
			local m = p
			while m.Parent and m.Parent.Parent and m.Parent ~= VB.Buildings and m.Parent.Parent ~= VB.Buildings do m = m.Parent end
			if m.Parent and m.Parent.Parent == VB.Buildings and m:IsA("Model") then dead[m] = true end
			if p.Name == "Footprint" then dead[p] = true end
		end
		for m in pairs(dead) do m:Destroy() end
	end
	L.gantry(CW, Vector3.new(-1880, G, -410), Vector3.new(-1, 0, 0), 44, "CORAL COUNTY", "Coral Blvd  ->")
	-- hill roads
	L.road3D(R3, heights, 32, { name = "Coral Heights Dr", barriers = false, lanes = 1, var = "AsphaltPlain" })
	L.road3D(R3, cr1, 34, { name = "County Rd 1", barriers = false, lanes = 1, var = "AsphaltWorn" })
	-- guard rails on the downhill side of the spiral
	for i = 2, #heights - 1, 2 do
		local a, b = heights[i], heights[i + 1]
		local out = Vector3.new(a.X - HC[1], 0, a.Z - HC[2]).Unit
		local pa, pb = a + out * 12.5 + Vector3.new(0, 1.6, 0), b + out * 12.5 + Vector3.new(0, 1.6, 0)
		L.P(R3, Vector3.new(0.4, 1, (pb - pa).Magnitude + 0.4), CFrame.lookAt((pa + pb) / 2, pb), C(200, 202, 204), M.Metal)
		L.P(R3, Vector3.new(0.5, 2.4, 0.5), CFrame.new(pa - Vector3.new(0, 0.8, 0)), C(120, 110, 96), M.Wood)
	end
	for i = 1, #heights, 6 do
		local p = heights[i]
		local inn = Vector3.new(HC[1] - p.X, 0, HC[2] - p.Z).Unit
		local lp = Vector3.new(p.X, p.Y - 0.3, p.Z) + inn * 14
		L.streetlight(R3, CFrame.lookAt(lp, Vector3.new(p.X, lp.Y, p.Z)))
	end

	-- the suburban street net (its own graph, built into CountyRoads)
	local lines = {}
	local function ln(style, pts, o)
		o = o or {}
		table.insert(lines, { style = style, pts = pts, name = o.name, cul = o.cul })
	end
	ln("BLVD", { { -2380, -410 }, { -4640, -410 } }, { name = "Coral Blvd" })
	ln("RES", { { -2440, -1260 }, { -2440, 1290 } }, { name = "Bayshore Dr" })
	ln("RES", { { -2840, -1260 }, { -2840, 1290 } }, { name = "Granada Ave" })
	ln("HABA", { { -3240, -1260 }, { -3240, 1290 } }, { name = "Coral Way" })
	ln("RES", { { -3640, -1260 }, { -3640, 1290 } }, { name = "Alhambra Ave" })
	ln("RES", { { -4640, -900 }, { -4640, 1350 } }, { name = "Ocean Dr W" })
	local NAMES = { "Sevilla", "Valencia", "Malaga", "Toledo", "Madrid", "Cadiz", "Cordoba", "Leon", "Murcia", "Girona", "Navarra", "Bilbao", "Ronda", "Vigo", "Soria" }
	local ni = 0
	for k = -5, 10 do
		if k ~= 0 then
			ni += 1
			ln("RES", { { -2440, -410 + 170 * k }, { -3640, -410 + 170 * k } }, { name = NAMES[ni] .. " St" })
		end
	end
	-- two beach-town cross streets
	ln("RES", { { -4640, 100 }, { -4380, 100 } }, { name = "Surf Ave", cul = true })
	ln("RES", { { -4640, 1200 }, { -4440, 1200 } }, { name = "Dune Rd", cul = true })
	local net = L.net(lines)
	L.buildRoads(VB, net, "CountyRoads")
	L.cutSidewalk(CFrame.new(-3900, G + 0.5, -446), Vector3.new(30, 3, 22), "CountyRoads")
	L.cutSidewalk(CFrame.new(-3800, G + 0.5, -374), Vector3.new(30, 3, 22), "CountyRoads")
	L.cutSidewalk(CFrame.new(-4624, G + 0.5, 900), Vector3.new(16, 3, 32), "CountyRoads")
	print(string.format("county roads %.1fs", os.clock() - t0))

	-- ===== 4. landmarks =====
	-- Coral Heights villas on their pads + the overlook
	for k, pd in ipairs(PADS) do
		local cf = CFrame.lookAt(Vector3.new(pd.c.X, pd.y, pd.c.Z), Vector3.new(pd.face.X, pd.y, pd.face.Z))
		L.mansion(LMc, cf, pd.w - 4, pd.d - 4, { name = "Coral Heights Villa " .. k, price = 2500000 + k * 450000, style = ({ "med", "white", "tropical", "noir", "med", "white" })[(k - 1) % 6 + 1] })
	end
	do
		local sc = CFrame.new(HC[1], topY, HC[2])
		local ov = L.model(LMc, "CoralHeightsOverlook")
		L.Cyl(ov, 0.3, 120, sc * CFrame.new(0, 0.15, 0), C(206, 198, 184), M.Pavement, "HerringbonePavers")
		-- water tower
		for _, q in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do L.B(ov, sc * CFrame.new(-28, 0, 20), q[1], 0, q[2], 1.2, 40, 1.2, C(200, 204, 208), M.Metal) end
		L.Cyl(ov, 16, 24, sc * CFrame.new(-28, 48, 20), C(230, 236, 240), M.Metal)
		local tank = L.P(ov, Vector3.new(24.2, 6, 0.2), sc * CFrame.new(-28, 48, 7.9), C(230, 236, 240), M.Metal, nil, { Transparency = 1, CanCollide = false })
		L.text(tank, Enum.NormalId.Front, "CORAL COUNTY", { font = Enum.Font.GothamBlack, color = C(20, 90, 150), pps = 10, dist = 1500 })
		-- the big hillside letters, facing the city
		local sg = L.P(ov, Vector3.new(0.4, 16, 110), sc * CFrame.new(52, 9, 0), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1, CanCollide = false })
		L.text(sg, Enum.NormalId.Right, "CORAL HEIGHTS", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), pps = 6, dist = 4000, light = 0.2 })
		for z = -50, 50, 12.5 do L.B(ov, sc * CFrame.new(52.6, 0, z), 0, 0, 0, 0.6, 2, 0.6, C(80, 80, 80), M.Metal) end
		for k = -2, 2 do L.bench(ov, sc * CFrame.new(30, 0, k * 14) * CFrame.Angles(0, -math.pi / 2, 0)) end
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			L.palm(ov, (sc * CFrame.new(math.cos(a) * 54, 0, math.sin(a) * 54)).Position, L.r(26, 36), "hero")
		end
		L.poi(sc.Position, "Park", "Coral Heights Overlook")
	end
	-- hillside trees
	for _, h in ipairs(HILLS) do
		for _ = 1, math.floor(h[3] / 3) do
			local a, rr = L.r(0, 6.28), h[3] * math.sqrt(L.r(0.02, 0.9))
			local x, z = h[1] + math.cos(a) * rr, h[2] + math.sin(a) * rr
			local H = finalH(x, z)
			if math.abs(H - hillH(x, z)) < 0.5 then
				if L.chance(0.55) then L.tree(LMc, Vector3.new(x, H - 0.4, z), L.r(0.9, 1.4)) else L.palm(LMc, Vector3.new(x, H - 0.4, z), L.r(28, 42)) end
			end
		end
	end

	-- Coral Golf Club (x -3700..-4560, z -360..170)
	do
		local gc = L.model(LMc, "CoralGolfClub")
		local cx, cz = -4120, -100
		L.BD(gc, CFrame.new(cx, G, cz), 0, 0.02, 0, 820, 0.1, 470, C(110, 160, 72), M.Grass)
		for k = 0, 5 do
			local p = CFrame.new(cx - 340 + k * 136, G, cz + ((k % 2 == 0) and -110 or 110))
			L.Cyl(gc, 0.14, 34, p * CFrame.new(0, 0.12, 0), C(120, 186, 80), M.Grass, nil, { CanCollide = false })
			L.Cyl(gc, 9, 0.25, p * CFrame.new(0, 4.6, 0), C(240, 240, 240), M.Metal)
			L.D(gc, Vector3.new(0.1, 1.8, 2.6), p * CFrame.new(0, 8, 1.3), C(230, 30, 30), M.Fabric)
			L.Cyl(gc, 0.16, 16, p * CFrame.new(22, 0.1, 12), C(236, 220, 170), M.Sand, nil, { CanCollide = false })
			L.Cyl(gc, 0.16, 10, p * CFrame.new(-60, 0.12, -40), C(236, 220, 170), M.Sand, nil, { CanCollide = false })
		end
		T:FillBlock(CFrame.new(cx + 40, -1, cz + 10), Vector3.new(120, 6, 60), M.Air)
		T:FillBlock(CFrame.new(cx + 40, -6, cz + 10), Vector3.new(120, 4, 60), M.Water)
		-- clubhouse on Coral Blvd
		local ch = CFrame.new(-4000, G, -300)
		L.B(gc, ch, 0, 0, 0, 70, 16, 40, C(240, 232, 214), M.Plaster, "StuccoSuburb")
		L.W(gc, Vector3.new(74, 8, 22), ch * CFrame.new(0, 20, -11), C(170, 96, 70), M.ClayRoofTiles, "RoofClayMission")
		L.W(gc, Vector3.new(74, 8, 22), ch * CFrame.new(0, 20, 11) * CFrame.Angles(0, math.pi, 0), C(170, 96, 70), M.ClayRoofTiles, "RoofClayMission")
		L.sign(gc, ch * CFrame.new(0, 12, -20.4), 30, 3, "CORAL GOLF CLUB", C(30, 70, 50), C(250, 246, 236), Enum.Font.Merriweather, {})
		for k = 0, 4 do L.car(gc, ch * CFrame.new(-30 + k * 14, 0.2, -44) * CFrame.Angles(0, math.pi / 2, 0)) end
		L.BD(gc, ch, 0, 0.03, -44, 80, 0.15, 30, C(96, 96, 100), M.Asphalt, "ParkingLotAsphalt")
		L.footprint(LMc, ch * CFrame.new(0, 0, -15), 84, 72)
		L.poi((ch * CFrame.new(0, 0, -22)).Position, "Job", "Golf Caddie", { Job = "Caddie", Pay = 55 })
	end

	-- Coral Beach (west coast): lifeguard towers, umbrellas, palms
	do
		local bm = L.model(LMc, "CoralBeach")
		for z = -1500, 1500, 200 do L.lifeguard(bm, CFrame.new(-4820, G, z) * CFrame.Angles(0, math.pi / 2, 0)) end
		for _ = 1, 70 do L.umbrella(bm, CFrame.new(L.r(-4880, -4760), G, L.r(-1550, 1550))) end
		for z = -1580, 1580, 46 do L.palm(bm, Vector3.new(-4728 + L.r(-6, 6), G, z), L.r(30, 44)) end
		L.poi(Vector3.new(-4800, G, 300), "Park", "Coral Beach")
	end

	-- ===== 5. fill the suburb =====
	local fireDone, schoolDone, churchDone = false, false, false
	local built = L.fill(Bc, net, function(x, z, st, side, e)
		for _, q in ipairs({ { 0, 0 }, { 80, 0 }, { -80, 0 }, { 0, 80 }, { 0, -80 } }) do
			if hillH(x + q[1], z + q[2]) > G + 0.5 then return nil end
		end
		local nm = e[5] or ""
		if nm == "Coral Blvd" then
			if x > -2800 and x < -2560 and not fireDone then fireDone = true return { kind = "firestation", w = 70, d = 56 } end
			if x < -3660 then return nil end -- golf club side
			if L.chance(0.35) then return { kind = "gas", w = 84, d = 64 } end
			return { kind = "stripmall", w = L.r(130, 170), d = 92, opts = { sign = L.pick({ "CORAL PLAZA", "GRANADA SQUARE", "MIRACLE MILE", "SUNSET PLACE", "PALM COURT" }) } }
		end
		if nm == "Coral Way" then
			if not churchDone and z > 400 then churchDone = true return { kind = "church", w = 56, d = 62 } end
			if L.chance(0.45) then return { kind = "stripmall", w = L.r(110, 150), d = 88 } end
			return { kind = "shop", w = L.r(40, 56), d = 48, opts = { rundown = false, floors = L.chance(0.4) and 2 or 1, signs = { L.pick({ "CAFE", "BAKERY", "FLORIST", "DENTAL", "REALTY", "PET SPA", "BIKE SHOP", "ICE CREAM" }) } } }
		end
		if nm == "Ocean Dr W" then
			return { kind = "flhouse", w = L.r(48, 56), d = 52, opts = { color = L.pick({ C(250, 220, 226), C(200, 236, 228), C(252, 238, 196), C(216, 228, 250), C(255, 214, 190) }) } }
		end
		if not schoolDone and x < -2900 and x > -3200 and z > 600 then schoolDone = true return { kind = "court", w = 70, d = 56 } end
		if L.chance(0.04) then return { kind = "emptyLot", w = 44, d = 48 } end
		return { kind = "flhouse", w = L.r(44, 54), d = 50 }
	end, function(x, z, e)
		return x < -2330
	end)

	-- ===== 6. glades airboat tours (mainland marsh pond) =====
	do
		local ab = L.model(LMc, "AirboatTours")
		local dc = CFrame.new(-1930, WATER + 0.4, 392) * CFrame.Angles(0, math.pi, 0)
		L.dock(ab, dc, 36, 1, 14, nil)
		for k, sd in ipairs({ -1, 1 }) do
			local bc = CFrame.new(-1930 + sd * 26, WATER, 418) * CFrame.Angles(0, 0, 0)
			L.boat(ab, bc, 22, C(60, 90, 60))
			L.Cyl(ab, 0.6, 9, bc * CFrame.new(0, 7, 9) * CFrame.Angles(math.pi / 2, 0, 0), C(40, 40, 42), M.Metal, nil, { CanCollide = false, Transparency = 0.3 })
			L.P(ab, Vector3.new(4, 3, 3), bc * CFrame.new(0, 3.5, 7.5), C(50, 50, 52), M.Metal)
			L.P(ab, Vector3.new(3, 5, 1.6), bc * CFrame.new(0, 4.5, 2), C(30, 30, 32), M.Metal)
		end
		local hut = CFrame.new(-1930, G, 372)
		L.B(ab, hut, 0, 0, 0, 22, 10, 14, C(150, 120, 84), M.WoodPlanks, "WoodPlanksOld")
		L.W(ab, Vector3.new(24, 4, 8), hut * CFrame.new(0, 12, -4), C(170, 150, 100), M.Grass)
		L.W(ab, Vector3.new(24, 4, 8), hut * CFrame.new(0, 12, 4) * CFrame.Angles(0, math.pi, 0), C(170, 150, 100), M.Grass)
		L.sign(ab, hut * CFrame.new(0, 8, -7.4), 18, 2.6, "AIRBOAT TOURS", C(240, 220, 120), C(30, 60, 30), Enum.Font.Bangers, {})
		L.poi(Vector3.new(-1930, G, 380), "Dock", "Airboat Tours")
		L.poi(Vector3.new(-1920, G, 368), "Job", "Airboat Guide", { Job = "Airboat Guide", Pay = 60 })
	end


	-- ===== 7. the countryside: golf fairways, hammock forest, ranch houses on County Rd 1, grass variation =====
	local function nearPoly(P, x, z, dist)
		for i = 1, #P - 1 do
			local a, b = P[i], P[i + 1]
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local ap = Vector3.new(x - a.X, 0, z - a.Z)
			local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
			if (Vector3.new(x - a.X - ab.X * t, 0, z - a.Z - ab.Z * t)).Magnitude < dist then return true end
		end
		return false
	end
	do
		local gc = LMc:FindFirstChild("CoralGolfClub")
		local cx, cz = -4120, -100
		for k = 0, 5 do
			local green = Vector3.new(cx - 340 + k * 136, G, cz + ((k % 2 == 0) and -110 or 110))
			local tee = Vector3.new(green.X + ((k % 2 == 0) and 40 or -40), G, cz + ((k % 2 == 0) and 150 or -150))
			local mid = (green + tee) / 2
			local len = (green - tee).Magnitude
			local fcf = CFrame.lookAt(mid, green)
			if not nearPoly(cr1, mid.X, mid.Z, 40) then
				L.D(gc, Vector3.new(46, 0.1, len), fcf * CFrame.new(0, 0.08, 0), C(124, 180, 82), M.Grass)
				for st = -2, 2, 2 do L.D(gc, Vector3.new(7, 0.1, len - 8), fcf * CFrame.new(st * 7, 0.1, 0), C(134, 190, 90), M.Grass) end
				L.D(gc, Vector3.new(14, 0.4, 10), CFrame.new(tee) * CFrame.new(0, 0.2, 0), C(130, 186, 86), M.Grass)
				for _, sd in ipairs({ -1, 1 }) do
					for q = 0, 3 do
						local tp = (fcf * CFrame.new(sd * L.r(34, 48), 0, -len / 2 + 10 + q * (len - 20) / 3)).Position
						if not nearPoly(cr1, tp.X, tp.Z, 24) then L.tree(gc, Vector3.new(tp.X, G, tp.Z), L.r(0.9, 1.3)) end
					end
				end
			end
		end
		for x = -4500, -3740, 40 do
			if not nearPoly(cr1, x, -20, 22) then L.D(gc, Vector3.new(40, 0.12, 5), CFrame.new(x, G + 0.06, -20), C(196, 190, 178), M.Concrete) end
		end
	end
	-- ranch houses along the flat stretches of County Rd 1
	local acc2, ranch = 0, 0
	for i = 2, #cr1 - 1 do
		acc2 += (cr1[i] - cr1[i - 1]).Magnitude
		if acc2 > 140 then
			local p = cr1[i]
			local dirv = ((cr1[i + 1] - cr1[i - 1]) * Vector3.new(1, 0, 1)).Unit
			local rgt = Vector3.new(-dirv.Z, 0, dirv.X)
			for _, sd in ipairs({ -1, 1 }) do
				local c = Vector3.new(p.X, G, p.Z) + rgt * sd * 44
				local ok = true
				for _, q in ipairs({ { 0, 0 }, { 28, 28 }, { -28, 28 }, { 28, -28 }, { -28, -28 } }) do
					if hillH(c.X + q[1], c.Z + q[2]) > G + 0.3 or nearPoly(cr1, c.X + q[1], c.Z + q[2], 16) then ok = false end
				end
				local op = OverlapParams.new()
				op.FilterType = Enum.RaycastFilterType.Include
				op.FilterDescendantsInstances = { LMc, Bc }
				if ok and #workspace:GetPartBoundsInBox(CFrame.new(c + Vector3.new(0, 4, 0)), Vector3.new(60, 8, 60), op) == 0 and c.X > -4560 then
					local cf = CFrame.lookAt(c, c - rgt * sd)
					L.flhouse(LMc, cf, 56, 54, { color = L.pick(L.SUBURB_COLS) })
					L.footprint(LMc, cf, 56, 54)
					ranch += 1
					acc2 = 0
					break
				end
			end
		end
	end
	-- hammock forest over the west hills and the flat land around County Rd 1
	local placed = 0
	local fop = OverlapParams.new()
	fop.FilterType = Enum.RaycastFilterType.Include
	fop.FilterDescendantsInstances = { LMc, Bc, VB:FindFirstChild("CountyRoads") }
	local function clearAt(x, z, H)
		for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(x, H + 4, z), Vector3.new(12, 8, 12), fop)) do
			if p.Name == "Footprint" or p:IsDescendantOf(VB:FindFirstChild("CountyRoads")) then return false end
		end
		return true
	end
	for _ = 1, 1600 do
		if placed >= 360 then break end
		local x, z = L.r(-4560, -3700), L.r(180, 1500)
		local H = finalH(x, z)
		if math.abs(H - hillH(x, z)) < 0.4 and not nearPoly(cr1, x, z, 24) and clearAt(x, z, H) then
			placed += 1
			local r = L.rng:NextNumber()
			if r < 0.5 then L.tree(LMc, Vector3.new(x, H - 0.4, z), L.r(0.9, 1.5))
			elseif r < 0.75 then L.palm(LMc, Vector3.new(x, H - 0.4, z), L.r(28, 44))
			else L.bush(LMc, Vector3.new(x, H - 0.3, z), L.r(5, 10)) end
		end
	end
	-- grass variation across the flat county (patches of leafy grass / dry ground)
	for _ = 1, 70 do
		local x, z = L.r(-4680, -2360), L.r(-1620, 1620)
		local s = L.r(40, 140)
		local reg = Region3.new(Vector3.new(x - s, -4, z - s), Vector3.new(x + s, 4, z + s)):ExpandToGrid(4)
		T:ReplaceMaterial(reg, 4, M.Grass, L.chance(0.7) and M.LeafyGrass or M.Ground)
	end
	print("county countryside: trees " .. placed .. " ranch " .. ranch)
	local parts = 0
	for _, f in ipairs({ Bc, LMc, R3, CW, VB:FindFirstChild("CountyRoads") }) do
		if f then for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	end
	return string.format("county lots %d villas %d parts %d (%.0fs)", built, #PADS, parts, os.clock() - t0)
end
