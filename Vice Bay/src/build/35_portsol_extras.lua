-- 35 Port Sol extras, on the open land around the town:
--   * Sol Raceway (east): a 50-wide road course with a 900-stud main straight, red/white kerbs on the corners,
--     tyre walls, start/finish gantry, grandstand, pit garages and a paddock you drive straight onto the track from.
--   * Port Sol Regional Airport (west): 1,060-stud runway, parallel taxiway, apron with bizjets, small terminal, hangar.
--   * Sol Marina (south shore): three pontoons with boats, a marina clubhouse and a fuel dock.
-- Access roads are their own small street graphs joined to the Port Sol grid (curb cuts at the joins).
return function(L)
	local M, C = L.M, L.C
	local G, WL = L.G, L.WATER
	local VB = workspace.ViceBay
	local old = VB:FindFirstChild("PortSolExtras")
	if old then old:Destroy() end
	local PX = L.folder(VB, "PortSolExtras")
	L.seed(3535)
	local t0 = os.clock()
	local TOP = G + 0.25
	local WHITE, YEL, RED = C(236, 236, 230), C(232, 186, 40), C(200, 30, 30)
	local PL = game.ServerStorage:FindFirstChild("VBPlanes")

	local function slab(par, x0, x1, z0, z1, col, mat, var, name)
		local p = L.P(par, Vector3.new(x1 - x0, 0.6, z1 - z0), CFrame.new((x0 + x1) / 2, TOP - 0.3, (z0 + z1) / 2), col, mat, var)
		p.Name = name or "Asphalt"
		p.CastShadow = false
		return p
	end
	local function mark(par, cx, cz, sx, sz, col, yaw)
		return L.D(par, Vector3.new(sx, 0.04, sz), CFrame.new(cx, TOP + 0.02, cz) * CFrame.Angles(0, yaw or 0, 0), col, M.SmoothPlastic, nil, { Transparency = 0.06 })
	end
	local function light(par, x, z, col) L.D(par, Vector3.new(0.7, 0.9, 0.7), CFrame.new(x, TOP + 0.45, z), col, M.Neon) end
	local function plane(par, cf, big, tail)
		local t = PL and PL:FindFirstChild(big and "Airliner" or "BizJet")
		if not t then return end
		local m = t:Clone()
		if big then m:ScaleTo(0.9) end
		m:PivotTo(cf * CFrame.new(0, big and 0 or 2.6, 0))
		local rc = m.PrimaryPart.CFrame
		if big and tail then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					local rel = rc:PointToObjectSpace(d.Position)
					if rel.Y > 13.5 and rel.Z > 24 then d.Color = tail end
				end
			end
		elseif not big then
			for _, g in ipairs({ { 0, -26 }, { -4.5, 4 }, { 4.5, 4 } }) do
				L.D(m, Vector3.new(0.5, 2.8, 0.5), rc * CFrame.new(g[1], 1.6, g[2]), C(200, 200, 200), M.Metal)
				local w = L.P(m, Vector3.new(1, 1.9, 1.9), rc * CFrame.new(g[1], 0.95, g[2]), C(26, 26, 26), M.Rubber)
				w.Shape = Enum.PartType.Cylinder
			end
		end
		m.Parent = par
		L.lod(m)
		return m
	end
	-- clear anything (trees, lots) standing where the new things go
	local function clearBox(x0, x1, z0, z1)
		local n = 0
		for _, f in ipairs({ VB.Buildings:FindFirstChild("PortSol"), VB.Landmarks:FindFirstChild("PortSol"), VB:FindFirstChild("Expressway") }) do
			if f then
				for _, m in ipairs(f:GetChildren()) do
					if m:IsA("Model") and m.Name ~= "Road3D" and m.Name ~= "Sol Expressway" then
						local p = m:GetPivot().Position
						if p.X > x0 and p.X < x1 and p.Z > z0 and p.Z < z1 then m:Destroy() n += 1 end
					end
				end
			end
		end
		return n
	end

	-- ===== access roads (joined to the Port Sol grid) =====
	local S = L.STY
	local lines = {}
	local function ln(style, p, o)
		o = o or {}
		table.insert(lines, { style = S[style], pts = p, name = o.name, cul = o.cul })
	end
	ln("HAB", { { -280, -4000 }, { -280, -3900 } }, { name = "Raceway Dr" })
	ln("HAB", { { -1000, -4000 }, { -1000, -3330 } }, { name = "Sol Airport Rd" })
	local net = L.net(lines)
	L.buildRoads(PX, net, "Roads")
	pcall(function()
		L.cutSidewalk(CFrame.new(-280, G + 0.5, -3968), Vector3.new(44, 3, 20), "PortSol")
		L.cutSidewalk(CFrame.new(-1000, G + 0.5, -3968), Vector3.new(44, 3, 20), "PortSol")
		L.cutSidewalk(CFrame.new(-968, G + 0.5, -4000), Vector3.new(20, 3, 44), "PortSol")
	end)

	-- =====================================================================================
	-- SOL RACEWAY
	-- =====================================================================================
	local RW = L.model(PX, "SolRaceway")
	local cleared = clearBox(-400, 600, -3910, -2680)
	local TW = 50
	local CP = {
		{ -250, -3650 }, { -250, -3300 }, { -250, -2960 }, { -225, -2810 }, { -130, -2745 }, { 10, -2770 }, { 110, -2870 }, { 240, -2900 },
		{ 390, -2810 }, { 495, -2860 }, { 520, -3010 }, { 455, -3150 }, { 515, -3300 }, { 505, -3500 }, { 420, -3600 }, { 300, -3565 },
		{ 185, -3455 }, { 65, -3485 }, { 25, -3620 }, { 115, -3755 }, { 55, -3850 }, { -120, -3845 }, { -225, -3790 },
	}
	-- closed Catmull-Rom spline, ~14-stud steps
	local P = {}
	for _, c in ipairs(CP) do table.insert(P, Vector3.new(c[1], TOP, c[2])) end
	local n = #P
	local pts = {}
	local function cr(p0, p1, p2, p3, t)
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
	for i = 1, n do
		local p0, p1, p2, p3 = P[(i - 2) % n + 1], P[i], P[i % n + 1], P[(i + 1) % n + 1]
		local steps = math.max(2, math.floor((p2 - p1).Magnitude / 14))
		for k = 0, steps - 1 do table.insert(pts, cr(p0, p1, p2, p3, k / steps)) end
	end
	table.insert(pts, pts[1])
	L.road3D(RW, pts, TW, { name = "Track", barriers = false, lanes = 0, var = "DowntownAsphaltClean", color = C(70, 72, 76) })
	-- fill the outside of bends + kerbs where the track turns
	local kerbs, lapLen = 0, 0
	for i = 2, #pts - 1 do
		local a, b, c = pts[i - 1], pts[i], pts[i + 1]
		lapLen += (b - a).Magnitude
		local d1, d2 = (b - a).Unit, (c - b).Unit
		local turn = math.asin(math.clamp(d1:Cross(d2).Y, -1, 1))
		if math.abs(turn) > math.rad(2.5) then
			L.Cyl(RW, 0.6, TW, CFrame.new(b - Vector3.new(0, 0.3, 0)), C(70, 72, 76), M.Asphalt, "DowntownAsphaltClean", { CastShadow = false }).Name = "Bend"
			-- kerb on both edges, alternating red / white blocks
			local right = Vector3.new(-d2.Z, 0, d2.X)
			for _, sd in ipairs({ -1, 1 }) do
				local kp = b + right * sd * (TW / 2 - 1.4) + Vector3.new(0, 0.06, 0)
				L.D(RW, Vector3.new(2.8, 0.12, 14.4), CFrame.lookAt(kp, kp + d2), (i % 2 == 0) and RED or WHITE, M.SmoothPlastic)
				kerbs += 1
			end
		end
		if i % 60 == 0 then task.wait() end
	end
	-- start / finish line, grid boxes, gantry with lights
	local sfz = -3300
	mark(RW, -250, sfz, TW - 4, 3, WHITE)
	for k = 0, 9 do
		local x = -250 + (k % 2 == 0 and -10 or 10)
		local z = sfz - 22 - math.floor(k / 2) * 26 - (k % 2) * 13
		mark(RW, x, z, 10, 0.7, WHITE)
	end
	do
		local g = L.model(RW, "StartGantry")
		local gc = CFrame.new(-250, TOP, sfz)
		for _, sd in ipairs({ -1, 1 }) do L.B(g, gc, sd * (TW / 2 + 2), 0, 0, 2, 22, 2, C(40, 40, 44), M.Metal) end
		local beam = L.B(g, gc, 0, 18, 0, TW + 6, 4, 2, C(30, 30, 34), M.Metal)
		L.text(beam, Enum.NormalId.Front, "SOL RACEWAY", { font = Enum.Font.GothamBlack, color = C(255, 214, 60), pps = 10, dist = 500, light = 0.4 })
		L.text(beam, Enum.NormalId.Back, "SOL RACEWAY", { font = Enum.Font.GothamBlack, color = C(255, 214, 60), pps = 10, dist = 500, light = 0.4 })
		for k = -2, 2 do L.D(g, Vector3.new(1.6, 1.6, 0.5), gc * CFrame.new(k * 3, 16.5, -1.2), C(255, 40, 40), M.Neon) end
		-- chequered band on the beam underside
		for k = 0, 11 do L.D(g, Vector3.new((TW + 6) / 12, 1, 2.1), gc * CFrame.new(-(TW + 6) / 2 + (k + 0.5) * (TW + 6) / 12, 18.5, 0), (k % 2 == 0) and C(20, 20, 20) or WHITE, M.SmoothPlastic) end
	end
	-- paddock (west of the straight, flush with the track) + pit garages
	slab(RW, -372, -275, -3890, -2980, C(96, 98, 100), M.Asphalt, "ParkingLotAsphalt", "Paddock")
	mark(RW, -277, -3435, 0.6, 900, WHITE)
	do
		local pg = L.model(RW, "PitGarages")
		local pc = CFrame.new(-340, G, -3380) * CFrame.Angles(0, -math.pi / 2, 0) -- doors (local -Z) face the track (+X)
		L.B(pg, pc, 0, 0, 0, 240, 16, 36, C(236, 236, 232), M.Concrete)
		for k = 0, 9 do
			local x = -108 + k * 24
			L.BD(pg, pc, x, 0, -18.1, 18, 11, 0.3, C(40, 42, 46), M.Metal)
			local nb = L.BD(pg, pc, x, 12, -18.1, 10, 2.4, 0.2, C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
			L.text(nb, Enum.NormalId.Front, tostring(k + 1), { font = Enum.Font.GothamBlack, color = C(30, 30, 34), pps = 14, dist = 200 })
		end
		local bar = L.BD(pg, pc, 0, 16, -12, 240, 1, 16, C(30, 30, 34), M.Metal)
		local tw = L.B(pg, pc, -100, 16, 6, 30, 14, 22, C(30, 34, 40), M.Glass, nil, { Transparency = 0.2, Reflectance = 0.25 })
		L.text(L.BD(pg, pc, -100, 30, 6, 30, 3, 22.2, C(240, 196, 40), M.SmoothPlastic), Enum.NormalId.Front, "RACE CONTROL", { font = Enum.Font.GothamBlack, color = C(20, 20, 22), pps = 10, dist = 400 })
		local _ = bar or tw
		L.lod(pg)
	end
	-- grandstand in the infield, facing the main straight
	do
		local gs = L.model(RW, "Grandstand")
		local gc = CFrame.new(-196, G, -3380) * CFrame.Angles(0, math.pi / 2, 0) -- seats face -X (the straight)
		for r = 0, 7 do
			L.B(gs, gc, 0, 0, -10 + r * 3.2, 200, 1.6 + r * 1.6, 3.2, C(200, 200, 196), M.Concrete)
			L.BD(gs, gc, 0, 1.6 + r * 1.6, -10.6 + r * 3.2, 198, 0.8, 1.4, (r % 2 == 0) and C(20, 70, 150) or C(200, 30, 30), M.SmoothPlastic)
		end
		L.B(gs, gc, 0, 0, 16.2, 204, 26, 1, C(180, 182, 186), M.Metal)
		for k = -2, 2 do L.B(gs, gc, k * 48, 0, 15, 1.2, 26, 1.2, C(60, 62, 66), M.Metal) end
		L.P(gs, Vector3.new(206, 1, 30), gc * CFrame.new(0, 26.5, 2) * CFrame.Angles(math.rad(-6), 0, 0), C(236, 236, 232), M.Metal)
		local fas = L.D(gs, Vector3.new(206, 4, 0.4), gc * CFrame.new(0, 25, -13), C(200, 30, 30), M.SmoothPlastic)
		L.text(fas, Enum.NormalId.Front, "SOL RACEWAY  ·  PORT SOL", { font = Enum.Font.GothamBlack, color = WHITE, pps = 6, dist = 500, light = 0.6 })
		L.lod(gs)
	end
	-- tyre walls on the outside of the fastest corners (low, one part each)
	for _, tw in ipairs({ { -260, -2770, 70, 0.6 }, { 545, -2930, 90, 1.4 }, { 545, -3420, 120, 1.57 }, { 75, -3885, 120, 0 } }) do
		local p = L.P(RW, Vector3.new(tw[3], 2.4, 3), CFrame.new(tw[1], TOP + 1.2, tw[2]) * CFrame.Angles(0, tw[4], 0), C(30, 30, 30), M.Rubber)
		p.Name = "TyreWall"
		for k = 0, 3 do L.D(RW, Vector3.new(tw[3], 0.5, 3.1), CFrame.new(tw[1], TOP + 0.4 + k * 0.6, tw[2]) * CFrame.Angles(0, tw[4], 0), (k % 2 == 0) and WHITE or RED, M.SmoothPlastic, nil, { Transparency = 0.2 }) end
	end
	-- sponsor boards along the straight (made-up brands)
	for k = 0, 5 do
		local ad = L.ADS and L.ADS[(k % #L.ADS) + 1] or { "SOL RACEWAY", "", C(30, 30, 34) }
		local b = L.P(RW, Vector3.new(1, 4, 40), CFrame.new(-221, TOP + 2, -3700 + k * 70), ad[3], M.SmoothPlastic)
		L.text(b, Enum.NormalId.Left, ad[1], { font = Enum.Font.GothamBlack, color = WHITE, pps = 8, dist = 300, light = 0.6 })
	end
	pcall(function()
		L.poi(Vector3.new(-250, G, sfz), "Park", "Sol Raceway", { Note = string.format("Road course, %.0f-stud lap. Full send.", lapLen) }, { noPrompt = true })
	end)

	-- =====================================================================================
	-- PORT SOL REGIONAL AIRPORT
	-- =====================================================================================
	local RA = L.model(PX, "SolAirport")
	clearBox(-1500, -870, -3950, -2680)
	local RX, RZ0, RZ1, RWW = -1380, -3830, -2770, 80
	slab(RA, RX - RWW / 2, RX + RWW / 2, RZ0, RZ1, C(74, 76, 80), M.Asphalt, "DowntownAsphaltClean", "Runway")
	for _, sd in ipairs({ -1, 1 }) do mark(RA, RX + sd * (RWW / 2 - 2), (RZ0 + RZ1) / 2, 1.2, RZ1 - RZ0 - 4, WHITE) end
	for z = RZ0 + 160, RZ1 - 160, 48 do mark(RA, RX, z, 1, 24, WHITE) end
	for _, e in ipairs({ { RZ0, 1, "36" }, { RZ1, -1, "18" } }) do
		for k = -3, 3 do if k ~= 0 then mark(RA, RX + k * 9, e[1] + e[2] * 20, 3.4, 28, WHITE) end end
		local pos = Vector3.new(RX, TOP + 0.02, e[1] + e[2] * 64)
		L.roadText(RA, CFrame.lookAt(pos, pos + Vector3.new(0, 0, e[2])), e[3], 24, 32)
		for k = -4, 4 do light(RA, RX + k * 9, e[1] + e[2] * 2, C(60, 255, 120)) end
	end
	for z = RZ0 + 30, RZ1 - 30, 80 do for _, sd in ipairs({ -1, 1 }) do light(RA, RX + sd * (RWW / 2 + 1.5), z, C(255, 240, 200)) end end
	-- taxiway + apron + connectors
	local TX = -1295
	slab(RA, TX - 18, TX + 18, RZ0 + 40, RZ1 - 40, C(80, 82, 86), M.Asphalt, "DowntownAsphaltClean", "Taxiway")
	mark(RA, TX, (RZ0 + RZ1) / 2, 0.8, RZ1 - RZ0 - 90, YEL)
	for _, z in ipairs({ RZ0 + 60, -3300, RZ1 - 60 }) do slab(RA, RX + RWW / 2, TX - 18, z - 18, z + 18, C(80, 82, 86), M.Asphalt, "DowntownAsphaltClean", "Taxiway") end
	slab(RA, TX + 18, -1110, -3460, -3140, C(178, 178, 172), M.Concrete, nil, "Apron")
	for _, z in ipairs({ -3400, -3300, -3200 }) do
		mark(RA, -1200, z, 120, 0.8, YEL)
		plane(RA, CFrame.new(-1170, TOP, z) * CFrame.Angles(0, math.pi / 2, 0), false)
	end
	-- terminal (faces the access road to the east)
	do
		local tm = L.model(RA, "Terminal")
		local tc = CFrame.new(-1072, G, -3300) * CFrame.Angles(0, -math.pi / 2, 0)
		L.B(tm, tc, 0, 0, 0, 150, 18, 72, C(240, 236, 226), M.Plaster)
		local gl = L.BD(tm, tc, 0, 1, -36.1, 120, 13, 0.3, C(110, 140, 158), M.Glass, nil, { Transparency = 0.3, Reflectance = 0.2 })
		L.windowGrid(gl, Enum.NormalId.Front, { col = 6, row = 13, mull = C(220, 222, 224), spandrel = C(200, 204, 206) })
		L.BD(tm, tc, 0, 15, -40, 160, 1.2, 9, C(236, 236, 232), M.SmoothPlastic)
		for k = -3, 3 do L.B(tm, tc, k * 24, 0, -42, 1.2, 15, 1.2, C(236, 236, 232), M.Metal) end
		local sg = L.D(tm, Vector3.new(90, 5, 0.3), tc * CFrame.new(0, 20.5, -36.2), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(sg, Enum.NormalId.Front, "PORT SOL REGIONAL AIRPORT", { font = Enum.Font.GothamBold, color = C(24, 60, 110), pps = 8, dist = 600 })
		-- small control cab on the roof
		L.Cyl(tm, 14, 8, tc * CFrame.new(50, 25, 10), C(236, 236, 232), M.Concrete)
		L.Cyl(tm, 6, 16, tc * CFrame.new(50, 35, 10), C(60, 90, 110), M.Glass, nil, { Transparency = 0.25, Reflectance = 0.3 })
		L.Cyl(tm, 1.2, 18, tc * CFrame.new(50, 38.6, 10), C(236, 236, 232), M.SmoothPlastic)
		L.lod(tm)
	end
	-- hangar at the north end of the apron
	do
		local hm = L.model(RA, "Hangar")
		local hc = CFrame.new(-1185, G, -3090) -- doors (local -Z) face the apron
		L.B(hm, hc, 0, 0, 40, 110, 26, 2, C(206, 210, 212), M.Metal, "CorrugatedPlain")
		for _, sd in ipairs({ -1, 1 }) do L.B(hm, hc, sd * 54, 0, 0, 2, 26, 80, C(206, 210, 212), M.Metal, "CorrugatedPlain") end
		L.P(hm, Vector3.new(112, 2, 84), hc * CFrame.new(0, 27, 0), C(176, 180, 184), M.Metal, "RoofBoxProfile")
		for _, sd in ipairs({ -1, 1 }) do L.B(hm, hc, sd * 40, 0, -41, 28, 24, 1.2, C(150, 160, 170), M.Metal, "CorrugatedPlain") end
		slab(hm, -1240, -1130, -3130, -3050, C(170, 170, 166), M.Concrete, nil, "Apron")
		plane(hm, hc * CFrame.new(0, 0, 4), false)
		local sg = L.D(hm, Vector3.new(60, 5, 0.3), hc * CFrame.new(0, 21, -41.2), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(sg, Enum.NormalId.Front, "SOL AVIATION", { font = Enum.Font.GothamBlack, color = C(24, 60, 110), pps = 8, dist = 500 })
	end
	-- windsock + parking
	do
		local wp = Vector3.new(RX + 70, G, RZ1 - 200)
		L.Cyl(RA, 16, 0.5, CFrame.new(wp + Vector3.new(0, 8, 0)), C(200, 200, 200), M.Metal)
		for k = 0, 2 do
			local p = L.P(RA, Vector3.new(3.6, 2.4 - k * 0.5, 2.4 - k * 0.5), CFrame.new(wp + Vector3.new(2 + k * 3.6, 15.6 - k * 0.4, 0)), k % 2 == 0 and C(255, 110, 30) or WHITE, M.Fabric)
			p.Shape = Enum.PartType.Cylinder
			p.CanCollide = false
		end
		slab(RA, -965, -870, -3420, -3200, C(96, 98, 100), M.Asphalt, "ParkingLotAsphalt", "ParkingLot")
		for z = -3412, -3208, 11 do mark(RA, -917, z, 40, 0.5, WHITE) end
		for _ = 1, 5 do L.car(RA, CFrame.new(L.chance(0.5) and -932 or -902, TOP, -3412 + 11 * L.ri(0, 17) + 5.5) * CFrame.Angles(0, math.pi / 2, 0)) end
	end
	L.CAT.Airport = L.CAT.Airport or { tag = "Airport", color = C(120, 190, 255), glyph = "✈", prompt = "Check In" }
	pcall(function()
		L.poi(Vector3.new(-1035, G, -3300), "Airport", "Port Sol Regional", { Note = "Short hops and private jets" })
	end)

	-- =====================================================================================
	-- SOL MARINA (south shore, west of the pier)
	-- =====================================================================================
	local MA = L.model(PX, "SolMarina")
	local mcleared = clearBox(-960, -560, -4740, -4592)
	local shoreZ = -4752
	-- quay along the shore
	L.P(MA, Vector3.new(420, 8, 8), CFrame.new(-760, G - 3.75, shoreZ - 2), C(206, 200, 188), M.Concrete, "ConcretePlain")
	slab(MA, -960, -560, shoreZ, -4600, C(200, 196, 186), M.Concrete, "DowntownPavers", "Plaza")
	-- three pontoons with fingers + boats
	local yachts = 0
	for i, x in ipairs({ -900, -760, -620 }) do
		local cf0 = CFrame.lookAt(Vector3.new(x, WL, shoreZ - 18), Vector3.new(x, WL, shoreZ - 200))
		L.pontoon(MA, cf0, 160, 10, { name = "Pontoon" .. string.char(64 + i), berth = 28 })
		local ga, gb = Vector3.new(x, G + 0.05, shoreZ - 4), Vector3.new(x, WL + 2.3, shoreZ - 19)
		L.P(MA, Vector3.new(5, 0.4, (gb - ga).Magnitude + 0.6), CFrame.lookAt((ga + gb) / 2, gb), C(186, 150, 110), M.WoodPlanks, "WoodPlanksOld")
		for k = 0, 4 do
			for _, sd in ipairs({ -1, 1 }) do
				local bz = shoreZ - 36 - k * 30
				if (i + k + (sd > 0 and 1 or 0)) % 3 ~= 0 then
					local big = yachts < 4 and L.chance(0.3)
					local len = big and L.r(44, 54) or L.r(22, 32)
					local cx = x + sd * (8 + len / 2)
					local bc = CFrame.lookAt(Vector3.new(cx, WL, bz), Vector3.new(cx + sd * 10, WL, bz))
					if big then
						L.yacht(MA, bc, len, "motor")
						yachts += 1
					else
						L.boat(MA, bc, len, L.pick({ C(250, 250, 248), C(236, 236, 232), C(30, 50, 90), C(200, 40, 40) }))
					end
				end
			end
		end
	end
	-- clubhouse on the plaza
	do
		local cm = L.model(MA, "MarinaClub")
		local cc = CFrame.new(-760, G, -4660) -- glass front (local -Z) faces the water
		L.B(cm, cc, 0, 0, 0, 90, 14, 40, C(244, 242, 236), M.Plaster)
		local gl = L.BD(cm, cc, 0, 1, -20.1, 80, 11, 0.3, C(110, 140, 158), M.Glass, nil, { Transparency = 0.3, Reflectance = 0.2 })
		L.windowGrid(gl, Enum.NormalId.Front, { col = 6, row = 11, mull = C(220, 222, 224), spandrel = C(200, 204, 206) })
		L.BD(cm, cc, 0, 14, 6, 100, 1, 56, C(236, 236, 232), M.SmoothPlastic)
		L.B(cm, cc, 20, 14, -4, 40, 9, 26, C(244, 242, 236), M.Plaster)
		local sg = L.D(cm, Vector3.new(50, 4.4, 0.3), cc * CFrame.new(0, 18, -20.2), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(sg, Enum.NormalId.Front, "SOL MARINA  ·  YACHT CLUB", { font = Enum.Font.Merriweather, color = C(24, 60, 110), pps = 10, dist = 400 })
		for _, sd in ipairs({ -1, 1 }) do L.palm(cm, (cc * CFrame.new(sd * 56, 0, -24)).Position, 34, "royal") end
		for k = -2, 2 do
			L.umbrella(cm, cc * CFrame.new(k * 16, 0, -32), L.pick({ C(30, 60, 120), WHITE, C(200, 40, 40) }))
		end
		L.lod(cm)
	end
	-- fuel dock at the east end
	L.pontoon(MA, CFrame.lookAt(Vector3.new(-575, WL, shoreZ - 18), Vector3.new(-575, WL, shoreZ - 100)), 70, 10, { berth = 20, name = "FuelDock" })
	do
		local ga, gb = Vector3.new(-575, G + 0.05, shoreZ - 4), Vector3.new(-575, WL + 2.3, shoreZ - 19)
		L.P(MA, Vector3.new(5, 0.4, (gb - ga).Magnitude + 0.6), CFrame.lookAt((ga + gb) / 2, gb), C(186, 150, 110), M.WoodPlanks, "WoodPlanksOld")
		local pump = L.B(MA, CFrame.new(-569, WL + 2.2, shoreZ - 60), 0, 0, 0, 2, 5, 1.6, C(236, 236, 232), M.Metal)
		pump.Name = "FuelPump"
		game:GetService("CollectionService"):AddTag(pump, "FuelPump")
	end
	pcall(function()
		L.poi(Vector3.new(-760, G, shoreZ + 10), "Dock", "Sol Marina")
		L.poi(Vector3.new(-540, G, shoreZ - 20), "Gas", "Sol Marina Fuel Dock")
	end)

	local parts = 0
	for _, d in ipairs(PX:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("Port Sol extras: lap %.0f, kerbs %d, cleared %d/%d, yachts %d, parts %d (%.1fs)", lapLen, kerbs, cleared, mcleared, yachts, parts, os.clock() - t0)
end
