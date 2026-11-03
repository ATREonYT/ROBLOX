-- 04 the Liberty Canal: concrete flood channel through the hood, modelled on the LA-river style channel in the
-- Larp references: pale sloped concrete walls with panel joints and big graffiti pieces, a flat floor with a
-- recessed low-flow trough of real (terrain) water, algae / wet stains at the waterline, outfall pipes, debris,
-- weeds in the cracks and a steel chain-link fence on the lip. Re-runnable; run 25_clear_roads after it.
return function(L)
	local M, C = L.M, L.C
	local T = workspace.Terrain
	local G = L.G
	local root = L.root("Canal")
	root:ClearAllChildren()
	L.seed(99)
	local P = { { -1166, -1180 }, { -1170, -980 }, { -1152, -770 }, { -1176, -540 }, { -1160, -300 }, { -1146, -70 }, { -1150, 180 } }
	L.CANAL = P
	local TOP, FLOOR, DEPTH = 34, 18, 12
	local fy = G - DEPTH
	local wallRun = (TOP - FLOOR) / 2
	local wallLen = math.sqrt(wallRun ^ 2 + DEPTH ^ 2)
	local ang = math.atan2(DEPTH, wallRun)
	local TROUGH_W, TROUGH_D = 6, 1.4
	local CONC = C(186, 182, 172)
	local function stripes(part, face, n, col, alpha, vertical)
		if L.villaStripes then return L.villaStripes(part, face, n, col, alpha, vertical) end
	end
	for i = 1, #P - 1 do
		local a = Vector3.new(P[i][1], G, P[i][2])
		local b = Vector3.new(P[i + 1][1], G, P[i + 1][2])
		local len = (b - a).Magnitude
		local ext = (i < #P - 1) and 6 or 0
		local L2 = len + ext
		local cf = CFrame.lookAt((a + b) / 2, b)
		T:FillBlock(cf * CFrame.new(0, -DEPTH / 2 + 1, 0), Vector3.new(TOP + 6, DEPTH + 6, len + 12), M.Air)
		local seg = L.model(root, "Canal_" .. i)
		-- floor in two halves either side of the trough
		local half = (FLOOR + 1 - TROUGH_W) / 2
		for sd = -1, 1, 2 do
			local fl = L.P(seg, Vector3.new(half, 2, L2), cf * CFrame.new(sd * (TROUGH_W / 2 + half / 2), fy - 1, 0), CONC, M.Concrete, "ChannelConcreteDirty")
			stripes(fl, Enum.NormalId.Top, math.floor(L2 / 12), C(120, 116, 108), 0.55, false)
			-- dark wet band along the trough edge
			L.D(seg, Vector3.new(1.6, 0.04, L2), cf * CFrame.new(sd * (TROUGH_W / 2 + 0.8), fy + 0.02, 0), C(70, 74, 62), M.Concrete, nil, { Transparency = 0.35 })
		end
		-- trough: concrete U with terrain water in it
		L.P(seg, Vector3.new(TROUGH_W, 1, L2), cf * CFrame.new(0, fy - TROUGH_D - 0.5, 0), C(120, 120, 112), M.Concrete, "ChannelConcreteDamaged")
		pcall(function() T:FillBlock(cf * CFrame.new(0, fy - TROUGH_D / 2 - 0.15, 0), Vector3.new(TROUGH_W, TROUGH_D - 0.3, len + 2), M.Water) end)
		-- sloped walls: panel joints, waterline algae, graffiti pieces + tags
		for side = -1, 1, 2 do
			local mid = cf * CFrame.new(side * (FLOOR / 2 + wallRun / 2), fy + DEPTH / 2, 0)
			local w = L.P(seg, Vector3.new(wallLen + 0.6, 1.6, L2), mid * CFrame.Angles(0, 0, side * ang), CONC, M.Concrete, "ChannelWall")
			w.Name = "Wall"
			local face = side < 0 and Enum.NormalId.Top or Enum.NormalId.Top
			stripes(w, Enum.NormalId.Top, math.floor(L2 / 10), C(130, 126, 118), 0.5, false)
			-- algae / water stain band at the foot of the wall
			L.D(seg, Vector3.new(3.2, 0.05, L2), mid * CFrame.Angles(0, 0, side * ang) * CFrame.new(-side * (wallLen / 2 - 1.8), 0.83, 0), C(84, 96, 66), M.Concrete, nil, { Transparency = 0.3 })
			-- graffiti: 1-2 big pieces and a few throw-ups per side, on thin facing panels laid on the slope
			local nP = (L2 > 150) and L.ri(1, 2) or 1
			for k = 1, nP + L.ri(1, 3) do
				local big = k <= nP
				local plen = big and L.r(28, 40) or L.r(8, 14)
				local z = L.r(-L2 / 2 + plen / 2 + 4, L2 / 2 - plen / 2 - 4)
				local panel = L.D(seg, Vector3.new(big and (wallLen - 2) or 5, 0.06, plen), mid * CFrame.Angles(0, 0, side * ang) * CFrame.new(0, 0.84, z), CONC, M.Concrete, nil, { Transparency = 1 })
				if big and L.piece then L.piece(panel, Enum.NormalId.Top) else L.graffiti(panel, Enum.NormalId.Top) end
			end
			-- lip cap flush with the street + chain-link fence on posts
			L.P(seg, Vector3.new(3, 1, L2), cf * CFrame.new(side * (TOP / 2 + 1), G - 0.5, 0), C(196, 192, 184), M.Concrete, "ConcretePlain")
			local p1 = (cf * CFrame.new(side * (TOP / 2 + 2.2), G, -len / 2)).Position
			local p2 = (cf * CFrame.new(side * (TOP / 2 + 2.2), G, len / 2)).Position
			L.fence(seg, p1, p2, 7, "chain")
			-- outfall pipe with a rust streak and a trickle of water
			if L.chance(0.7) then
				local z = L.r(-len / 3, len / 3)
				local oc = cf * CFrame.new(side * (FLOOR / 2 + 2.6), fy + 2.4, z)
				L.Cyl(seg, 3.6, 3.6, oc * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(side * ang, 0, 0), C(46, 46, 44), M.Metal)
				L.D(seg, Vector3.new(2.2, 0.05, 2), mid * CFrame.Angles(0, 0, side * ang) * CFrame.new(-side * (wallLen / 2 - 3.6), 0.84, z), C(120, 72, 40), M.Concrete, nil, { Transparency = 0.4 })
				L.D(seg, Vector3.new(1.2, 0.04, 6), cf * CFrame.new(side * (FLOOR / 2 - 2), fy + 0.03, z), C(60, 80, 86), M.Glass, nil, { Transparency = 0.35, Reflectance = 0.3 })
			end
		end
		-- debris: puddles, tyres, trash piles, carts, a dumped sofa, weeds in the joints
		for _ = 1, L.ri(3, 6) do
			local z = L.r(-L2 / 2.4, L2 / 2.4)
			local sd = L.chance(0.5) and 1 or -1
			local x = sd * L.r(TROUGH_W / 2 + 1.5, FLOOR / 2 - 1)
			local k = L.ri(1, 6)
			if k == 1 then
				L.D(seg, Vector3.new(1, 3, 3), cf * CFrame.new(x, fy + 1, z) * CFrame.Angles(L.r(-0.4, 0.4), L.r(0, 3), math.pi / 2 + L.r(-0.3, 0.3)), C(22, 22, 22), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
			elseif k == 2 then
				L.trashBags(seg, (cf * CFrame.new(x, fy, z)).Position)
			elseif k == 3 then
				local cc = cf * CFrame.new(x, fy, z) * CFrame.Angles(0, L.r(0, 6), 0.4)
				L.D(seg, Vector3.new(2.4, 1.8, 3.4), cc * CFrame.new(0, 1.6, 0), C(150, 152, 156), M.DiamondPlate, nil, { Transparency = 0.4 })
				L.D(seg, Vector3.new(2.2, 0.2, 3.2), cc * CFrame.new(0, 0.4, 0), C(120, 122, 126), M.Metal)
			elseif k == 4 then
				L.D(seg, Vector3.new(L.r(4, 9), 0.04, L.r(3, 6)), cf * CFrame.new(x, fy + 0.03, z) * CFrame.Angles(0, L.r(0, 3), 0), C(56, 66, 70), M.Glass, nil, { Transparency = 0.3, Reflectance = 0.35 })
			elseif k == 5 then
				local sc = cf * CFrame.new(x, fy, z) * CFrame.Angles(0, L.r(0, 6), 0.12)
				local col = L.pick({ C(120, 90, 70), C(70, 80, 100), C(110, 104, 90) })
				L.B(seg, sc, 0, 0, 0, 7, 1.4, 3, col, M.Fabric)
				L.B(seg, sc, 0, 1.4, 1.1, 7, 1.8, 0.8, col, M.Fabric)
			else
				for _ = 1, 3 do L.weeds(seg, (cf * CFrame.new(x + L.r(-1, 1), fy, z + L.r(-3, 3))).Position) end
			end
		end
		task.wait()
	end
	L.poi(Vector3.new(P[4][1], fy, P[4][2]), "Park", "Liberty Canal", { Note = "Flood channel" }, { noPrompt = true })
	return "canal ok"
end
