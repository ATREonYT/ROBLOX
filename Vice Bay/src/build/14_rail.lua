-- 14 Vice Bay Rail: two tracks on ballast running UNDER the elevated I-95 (between its pier rows),
-- crossing gates with flashing lights at every street, a steel truss bridge over the river,
-- a parked freight train and a station platform.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local VB = L.folder(workspace, "ViceBay")
	local old = VB:FindFirstChild("Rail")
	if old then old:Destroy() end
	local RL = L.folder(VB, "Rail")
	L.seed(95)
	local X = L.RAILX or { -816, -804 }
	local Z0, Z1 = -840, 690
	local mid = (X[1] + X[2]) / 2
	-- clear anything (lots, props) sitting in the corridor first
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { VB:FindFirstChild("Buildings"), VB:FindFirstChild("Landmarks") }
	local box = CFrame.new(mid, G + 6, (Z0 + Z1) / 2)
	local removed = 0
	for _, p in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(X[2] - X[1] + 18, 10, Z1 - Z0), op)) do
		local m = p:FindFirstAncestorWhichIsA("Model")
		if m and m.Parent and not m:IsDescendantOf(VB:FindFirstChild("Roads") or RL) then m:Destroy() removed += 1 end
	end
	-- also street furniture from the road network
	L.cutSidewalk(box, Vector3.new(X[2] - X[1] + 14, 12, Z1 - Z0))
	-- road probes (where the rail meets a street)
	local rop = OverlapParams.new()
	rop.FilterType = Enum.RaycastFilterType.Include
	rop.FilterDescendantsInstances = { VB:FindFirstChild("Roads") }
	local function onRoad(z)
		for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(mid, G + 0.2, z), Vector3.new(4, 1.2, 1), rop)) do
			if p.Material == M.Asphalt then return true end
		end
		return false
	end
	local function overRiver(z) return L.isWater(mid, z) end
	-- ballast bed
	local bedW = X[2] - X[1] + 14
	local z = Z0
	local segStart = Z0
	local state = nil
	local crossings, bridges = {}, {}
	local function flush(z1, st)
		local len = z1 - segStart
		if len > 1 then
			if st == "bed" then
				L.D(RL, Vector3.new(bedW, 1, len), CFrame.new(mid, G + 0.5, segStart + len / 2), C(122, 116, 106), M.Pebble, "GravelLot")
			elseif st == "road" then
				table.insert(crossings, { segStart, z1 })
			elseif st == "river" then
				table.insert(bridges, { segStart, z1 })
			end
		end
		segStart = z1
	end
	while z < Z1 do
		local st = overRiver(z) and "river" or (onRoad(z) and "road" or "bed")
		if st ~= state then
			if state then flush(z, state) end
			state = st
		end
		z += 2
	end
	flush(Z1, state)
	-- extend bridges onto the banks
	for _, b in ipairs(bridges) do b[1] -= 14 b[2] += 14 end
	local function inBridge(zz) for _, b in ipairs(bridges) do if zz > b[1] and zz < b[2] then return b end end end
	local function inCross(zz) for _, c in ipairs(crossings) do if zz > c[1] - 1 and zz < c[2] + 1 then return true end end end
	-- ties + rails
	local railTop = G + 1.6
	for _, x in ipairs(X) do
		for zz = Z0 + 1, Z1 - 1, 3.2 do
			if not inCross(zz) then
				local y = inBridge(zz) and (G + 2.2) or (G + 1.15)
				L.D(RL, Vector3.new(9, 0.6, 1.2), CFrame.new(x, y, zz), C(84, 70, 58), M.Wood)
			end
		end
		-- rails stop at every street; across the road they are flush steel strips set into the asphalt (no bump)
		local runs, zz = {}, Z0
		local cs = {}
		for _, c in ipairs(crossings) do table.insert(cs, { c[1] - 1, c[2] + 1 }) end
		table.sort(cs, function(p, q) return p[1] < q[1] end)
		for _, c in ipairs(cs) do
			if c[1] > zz then table.insert(runs, { zz, c[1] }) end
			zz = math.max(zz, c[2])
		end
		if Z1 > zz then table.insert(runs, { zz, Z1 }) end
		for _, sd in ipairs({ -2.4, 2.4 }) do
			for _, r in ipairs(runs) do
				local z0 = r[1]
				while z0 < r[2] - 0.5 do
					local ze = math.min(r[2], z0 + 200)
					L.P(RL, Vector3.new(0.5, 0.7, ze - z0), CFrame.new(x + sd, railTop, (z0 + ze) / 2), C(120, 110, 100), M.CorrodedMetal, "RustCoarse")
					L.D(RL, Vector3.new(0.3, 0.05, ze - z0), CFrame.new(x + sd, railTop + 0.37, (z0 + ze) / 2), C(200, 200, 204), M.Metal)
					z0 = ze
				end
			end
			for _, c in ipairs(cs) do
				L.D(RL, Vector3.new(0.4, 0.04, c[2] - c[1]), CFrame.new(x + sd, G + 0.29, (c[1] + c[2]) / 2), C(176, 176, 180), M.Metal)
			end
		end
	end
	-- level crossings: rubber panels, cross-bucks, gate arms, flashing lights, bells
	for _, c in ipairs(crossings) do
		local cz, len = (c[1] + c[2]) / 2, c[2] - c[1]
		for _, x in ipairs(X) do
			L.D(RL, Vector3.new(8, 0.04, len), CFrame.new(x, G + 0.27, cz), C(46, 46, 48), M.Rubber)
		end
		for _, sd in ipairs({ -1, 1 }) do
			local px = (sd < 0) and (X[1] - 10) or (X[2] + 10)
			for _, sz in ipairs({ -1, 1 }) do
				local pz = (sz < 0) and (c[1] - 3) or (c[2] + 3)
				local pc = CFrame.new(px, G, pz)
				L.Cyl(RL, 14, 0.7, pc * CFrame.new(0, 7, 0), C(236, 236, 236), M.Metal)
				-- cross-buck
				for _, a in ipairs({ 0.6, -0.6 }) do
					local cb = L.D(RL, Vector3.new(8, 1.4, 0.2), pc * CFrame.new(0, 13, 0) * CFrame.Angles(0, (sz < 0) and 0 or math.pi, a), C(250, 250, 248), M.SmoothPlastic)
					L.text(cb, Enum.NormalId.Front, a > 0 and "RAILROAD" or "CROSSING", { font = Enum.Font.GothamBold, color = C(20, 20, 20), pps = 14 })
				end
				-- twin flashers
				for _, fx in ipairs({ -1.4, 1.4 }) do
					local fl = L.D(RL, Vector3.new(1.2, 1.2, 0.4), pc * CFrame.new(fx, 10, -sz * 0.5), C(220, 30, 30), M.Neon)
					fl:SetAttribute("RailFlasher", true)
				end
				-- gate arm (raised)
				local arm = L.D(RL, Vector3.new(0.6, 18, 0.6), pc * CFrame.new(-sd * 1.2, 13, 0), C(250, 250, 248), M.SmoothPlastic)
				arm:SetAttribute("RailGate", true)
				for k = 0, 3 do L.D(RL, Vector3.new(0.65, 1.6, 0.65), pc * CFrame.new(-sd * 1.2, 5.5 + k * 4.5, 0), C(220, 30, 30), M.SmoothPlastic) end
				L.B(RL, pc, sd * 2, 0, 0, 2, 4, 2, C(150, 150, 150), M.Metal)
			end
		end
	end
	-- truss bridges over the river
	for _, b in ipairs(bridges) do
		local len = b[2] - b[1]
		local cz = (b[1] + b[2]) / 2
		local sc = C(70, 84, 90)
		L.P(RL, Vector3.new(bedW, 1.6, len), CFrame.new(mid, G + 1.1, cz), sc, M.Metal, "MetalPaintedRusty")
		for _, sx in ipairs({ -1, 1 }) do
			local x = mid + sx * (bedW / 2)
			L.P(RL, Vector3.new(1.4, 1.4, len), CFrame.new(x, G + 2, cz), sc, M.Metal)
			L.P(RL, Vector3.new(1.4, 1.4, len - 20), CFrame.new(x, G + 22, cz), sc, M.Metal)
			local n = math.max(2, math.floor(len / 20))
			for k = 0, n do
				local zz = b[1] + k * len / n
				L.P(RL, Vector3.new(1, 20, 1), CFrame.new(x, G + 12, zz), sc, M.Metal)
				if k < n then
					local a = Vector3.new(x, G + 2, zz)
					local c2 = Vector3.new(x, G + 22, zz + len / n)
					if k % 2 == 1 then a, c2 = Vector3.new(x, G + 22, zz), Vector3.new(x, G + 2, zz + len / n) end
					L.bar(RL, a, c2, 0.9, sc, M.Metal)
				end
			end
		end
		for k = 0, math.floor(len / 20) do
			L.D(RL, Vector3.new(bedW, 1, 1), CFrame.new(mid, G + 22.4, b[1] + 10 + k * 20), sc, M.Metal)
		end
		-- piers
		for zz = b[1] + 20, b[2] - 20, 40 do
			L.P(RL, Vector3.new(bedW - 2, 14, 6), CFrame.new(mid, G - 6, zz), C(150, 146, 138), M.Concrete, "OverpassConcrete")
		end
	end
	-- corridor fences (chain link) with gaps at crossings
	for _, sd in ipairs({ -1, 1 }) do
		local x = (sd < 0) and (X[1] - 7.5) or (X[2] + 7.5)
		local zz = Z0
		local cs = {}
		for _, c in ipairs(crossings) do table.insert(cs, { c[1] - 8, c[2] + 8 }) end
		for _, b in ipairs(bridges) do table.insert(cs, b) end
		table.sort(cs, function(a, b2) return a[1] < b2[1] end)
		for _, c in ipairs(cs) do
			if c[1] - zz > 6 then L.fence(RL, Vector3.new(x, G, zz), Vector3.new(x, G, c[1]), 7, "chain") end
			zz = math.max(zz, c[2])
		end
		if Z1 - zz > 6 then L.fence(RL, Vector3.new(x, G, zz), Vector3.new(x, G, Z1), 7, "chain") end
	end
	-- buffer stops at both ends of the line
	for _, x in ipairs(X) do
		for _, e in ipairs({ { Z0 + 3, 1 }, { Z1 - 3, -1 } }) do
			local bc = CFrame.new(x, G, e[1])
			L.B(RL, bc, 0, 0, 0, 7, 5, 3, C(60, 60, 64), M.Metal)
			L.B(RL, bc, 0, 5, 0, 8, 1.6, 1.6, C(250, 200, 40), M.Metal)
			L.D(RL, Vector3.new(1, 1, 0.3), bc * CFrame.new(0, 7, e[2] * 0.9), C(255, 40, 40), M.Neon)
		end
	end
	-- parked freight train on track 2 (box cars + tank cars + locomotive)
	do
		local tr = L.model(RL, "FreightTrain")
		-- park it in the longest stretch between level crossings / bridges so no street is blocked
		local cuts = { { Z0 - 1, Z0 + 8 }, { Z1 - 8, Z1 + 1 } }
		for _, c in ipairs(crossings) do table.insert(cuts, { c[1] - 10, c[2] + 10 }) end
		for _, b2 in ipairs(bridges) do table.insert(cuts, b2) end
		table.sort(cuts, function(a, b2) return a[1] < b2[1] end)
		local gs, ge = Z0, Z0
		for i = 1, #cuts - 1 do
			local a0, a1 = cuts[i][2], cuts[i + 1][1]
			if a1 - a0 > ge - gs then gs, ge = a0, a1 end
		end
		local zz = gs + 2 + 28
		local maxCars = math.max(0, math.floor((ge - gs - 62) / 50))
		local function bogies(cz, len)
			for _, o in ipairs({ -len / 2 + 6, len / 2 - 6 }) do
				L.D(tr, Vector3.new(7, 2.6, 8), CFrame.new(X[2], railTop + 1.8, cz + o), C(40, 40, 42), M.Metal)
				for _, w in ipairs({ -2.5, 2.5 }) do
					for _, sx in ipairs({ -2.4, 2.4 }) do
						L.D(tr, Vector3.new(0.6, 3, 3), CFrame.new(X[2] + sx, railTop + 1.6, cz + o + w), C(30, 30, 32), M.Metal, nil, { Shape = Enum.PartType.Cylinder })
					end
				end
			end
		end
		-- locomotive
		local ll = 56
		bogies(zz, ll)
		L.P(tr, Vector3.new(10, 1.6, ll), CFrame.new(X[2], railTop + 3.8, zz), C(40, 40, 42), M.Metal)
		L.P(tr, Vector3.new(9, 11, ll - 14), CFrame.new(X[2], railTop + 10, zz + 6), C(30, 80, 160), M.Metal)
		L.P(tr, Vector3.new(9.6, 12, 12), CFrame.new(X[2], railTop + 10.6, zz - ll / 2 + 7), C(250, 196, 40), M.Metal)
		L.D(tr, Vector3.new(8.6, 3, 0.2), CFrame.new(X[2], railTop + 13.4, zz - ll / 2 + 0.9), C(30, 40, 50), M.Glass)
		L.D(tr, Vector3.new(1.4, 1.4, 0.3), CFrame.new(X[2], railTop + 6, zz - ll / 2 + 0.9), C(255, 250, 220), M.Neon)
		local lb = L.D(tr, Vector3.new(0.2, 2.4, 20), CFrame.new(X[2] + 4.6, railTop + 11, zz + 8), C(30, 80, 160), M.Metal)
		L.text(lb, Enum.NormalId.Right, "VICE BAY RAIL", { font = Enum.Font.GothamBlack, color = C(250, 250, 248), pps = 10 })
		zz += ll / 2 + 2
		local cols = { C(150, 60, 40), C(40, 80, 120), C(120, 110, 90), C(60, 100, 70), C(170, 140, 60) }
		for k = 1, math.min(14, maxCars) do
			local cl = (k % 4 == 0) and 40 or 48
			zz += cl / 2
			bogies(zz, cl)
			L.P(tr, Vector3.new(9.4, 1.4, cl), CFrame.new(X[2], railTop + 3.6, zz), C(40, 40, 42), M.Metal)
			if k % 4 == 0 then
				L.Cyl(tr, cl - 4, 9, CFrame.new(X[2], railTop + 9, zz) * CFrame.Angles(math.pi / 2, 0, 0), C(40, 40, 44), M.Metal)
			else
				local b2 = L.P(tr, Vector3.new(9.4, 12, cl - 2), CFrame.new(X[2], railTop + 10.3, zz), L.pick(cols), M.CorrodedMetal, "ShippingContainer")
				if L.chance(0.35) then L.graffiti(b2, L.chance(0.5) and Enum.NormalId.Left or Enum.NormalId.Right) end
			end
			zz += cl / 2 + 2
		end
	end
	-- station platform + shelter at Flagler (z -410)
	do
		local st = L.model(RL, "FlaglerStation")
		local sz0 = -380
		L.P(st, Vector3.new(10, 3.4, 120), CFrame.new(X[1] - 11.5, G + 1.7, sz0 + 64), C(200, 196, 188), M.Concrete, "SidewalkConcrete")
		L.D(st, Vector3.new(0.8, 0.1, 120), CFrame.new(X[1] - 7, G + 3.45, sz0 + 64), C(240, 200, 40), M.SmoothPlastic)
		for k = 0, 4 do
			local pc = CFrame.new(X[1] - 13, G + 3.4, sz0 + 20 + k * 22)
			L.B(st, pc, 0, 0, 0, 0.6, 10, 0.6, C(60, 62, 66), M.Metal)
		end
		L.P(st, Vector3.new(8, 0.6, 100), CFrame.new(X[1] - 12, G + 13.6, sz0 + 64), C(60, 62, 66), M.Metal)
		for k = 0, 3 do L.bench(st, CFrame.new(X[1] - 14, G + 3.4, sz0 + 30 + k * 22) * CFrame.Angles(0, math.pi / 2, 0)) end
		L.sign(st, CFrame.new(X[1] - 8.2, G + 11.4, sz0 + 64) * CFrame.Angles(0, -math.pi / 2, 0), 20, 2.6, "FLAGLER STATION", C(20, 60, 120), C(250, 250, 248), Enum.Font.GothamBold, { both = true, lit = true })
		L.poi(Vector3.new(X[1] - 12, G + 3.4, sz0 + 64), "Job", "Train Conductor", { Job = "Conductor", Pay = 60 })
	end
	local parts = 0
	for _, d in ipairs(RL:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("rail parts %d crossings %d bridges %d cleared %d", parts, #crossings, #bridges, removed)
end
