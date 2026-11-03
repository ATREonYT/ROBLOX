-- Vice Bay road network: polylines -> graph -> roads with sidewalks, markings and street life
return function(L)
	local M, C = L.M, L.C

	-- ===== styles =====
	local S = {}
	L.STY = S
	S.HOOD = { tier = 1, var = "HoodAsphaltCracked", color = C(156, 154, 150), w = 36, sw = 7, swVar = "SidewalkSlabs", swColor = C(198, 198, 196),
		center = "single", lineColor = C(236, 236, 232), lineTrans = 0.12, patches = 3.4, cross = "zebra", hatch = 0.85, arrows = true, patchVar = "AsphaltTarPatch",
		poles = true, lights = 150, swDrop = 0.06, redCurb = true, drains = true, hydrants = 0.36, trash = 0.35, bags = 0.35, weeds = 0.6, stop = true, curb = C(170, 166, 158) }
	S.HOODA = { tier = 1, var = "HoodAsphaltFaded", color = C(148, 146, 142), w = 56, sw = 10, swVar = "SidewalkSlabs", swColor = C(198, 198, 196), arrows = true,
		center = "double", centerColor = C(222, 190, 70), lineTrans = 0.12, patches = 2.4, patchVar = "AsphaltTarPatch", edgeLines = true, lineColor = C(220, 214, 196),
		cross = "zebra", hatch = 1, poles = true, lights = 140, redCurb = true, drains = true, hydrants = 0.30, trash = 0.4, bags = 0.2, weeds = 0.3, signals = true, curb = C(176, 172, 164), busStop = 0.15 }
	S.ALLEY = { tier = 1, var = "HoodRoadPotholes", color = C(118, 116, 112), w = 24, sw = 0, center = "none", patches = 3, patchVar = "AsphaltTarPatch", poles = true, weeds = 1, bags = 0.5 }
	S.HAB = { tier = 2, swGrass = 4.5, shoebox = true, var = "AsphaltWorn", color = C(130, 130, 132), w = 38, sw = 10, swVar = "SidewalkSlabs", swColor = C(196, 192, 184),
		center = "double", centerColor = C(232, 196, 64), lineTrans = 0.15, edgeLines = true, lineColor = C(236, 234, 226), cross = "zebra",
		patches = 0.5, patchVar = "AsphaltTarPatch", poles = true, lights = 130, hydrants = 0.24, trash = 0.4, stop = true, curb = C(196, 192, 186), sidePalms = 100 }
	S.HABA = { tier = 2, swGrass = 5, shoebox = true, var = "AsphaltWorn", color = C(126, 126, 128), w = 56, sw = 12, swVar = "SidewalkConcrete", swColor = C(200, 196, 188),
		center = "double", centerColor = C(236, 200, 60), lanes = true, edgeLines = true, lineColor = C(238, 238, 232), cross = "zebra", hatch = 1, arrows = true, patches = 1.2, patchVar = "AsphaltTarPatch",
		lights = 130, hydrants = 0.24, trash = 0.5, signals = true, curb = C(200, 196, 190), sidePalms = 90, busStop = 0.18 }
	S.WYN = { tier = 2, var = "AsphaltGranular", color = C(124, 124, 126), w = 38, sw = 12, swVar = "SidewalkSlabs", swColor = C(204, 200, 194),
		center = "dashed", centerColor = C(236, 200, 60), edgeLines = true, lineColor = C(238, 238, 232), cross = "zebra", lights = 120, trash = 0.5, stop = true, curb = C(190, 188, 184), trees = 95 }
	S.WYNA = { tier = 2, var = "AsphaltGranular", color = C(120, 120, 124), w = 56, sw = 12, swVar = "SidewalkSlabs", swColor = C(204, 200, 194),
		center = "double", centerColor = C(236, 200, 60), lanes = true, bike = true, lineColor = C(240, 240, 236), cross = "zebra", hatch = 1, arrows = true, lights = 120, trash = 0.5, signals = true, curb = C(190, 188, 184), trees = 90, busStop = 0.18 }
	S.DT = { tier = 3, var = "DowntownAsphaltClean", color = C(118, 118, 122), w = 60, sw = 12, swVar = "SidewalkSlabs", swColor = C(206, 206, 204),
		center = "double", centerColor = C(240, 204, 60), lanes = true, edgeLines = true, lineColor = C(246, 246, 242), cross = "zebra", hatch = 1, stopLines = true, patches = 0.35, patchVar = "AsphaltTarPatch", redCurb = true, lineTrans = 0,
		lights = 105, modernLights = true, trash = 0.6, signals = true, curb = C(214, 212, 206), trees = 85, busStop = 0.21, arrows = true }
	S.DTS = { tier = 3, var = "DowntownAsphaltClean", color = C(122, 122, 126), w = 44, sw = 12, swVar = "SidewalkSlabs", swColor = C(206, 206, 204),
		center = "dashed", centerColor = C(240, 204, 60), lineColor = C(246, 246, 242), cross = "zebra", hatch = 1, arrows = true, patches = 0.35, patchVar = "AsphaltTarPatch", redCurb = true, lineTrans = 0, oneway = true, lights = 105, modernLights = true, trash = 0.5, stop = true, curb = C(214, 212, 206), trees = 85 }
	S.BLVD = { tier = 3, swGrass = 5, shoebox = true, sidePalms = 48, var = "AsphaltPlain", color = C(126, 126, 128), w = 76, sw = 12, swVar = "DowntownPavers", swColor = C(206, 200, 190),
		center = "median", medianW = 14, palms = 48, lanes = true, edgeLines = true, lineColor = C(246, 246, 242), cross = "zebra", hatch = 1, stopLines = true, lineTrans = 0,
		lights = 120, modernLights = true, signals = true, curb = C(214, 212, 206), busStop = 0.15, arrows = true }
	-- Glades Rd: the luxury edge of Mangrove Bay. Wide divided boulevard, palm median, clean paint, no utility poles.
	S.GLADES = { tier = 2, shoebox = true, var = "AsphaltPlain", color = C(126, 126, 128), w = 66, sw = 7, swVar = "SidewalkSlabs", swColor = C(214, 212, 206),
		center = "median", medianW = 12, palms = 44, lanes = true, edgeLines = true, lineColor = C(246, 246, 242), cross = "zebra", stopLines = true, lineTrans = 0,
		lights = 110, signals = true, curb = C(220, 218, 212), arrows = true, hydrants = 0.2 }
	S.PORT = { tier = 1, var = "AsphaltGranular", color = C(128, 128, 128), w = 52, sw = 6, swVar = "ConcreteStained", swColor = C(170, 168, 160),
		center = "double", centerColor = C(226, 194, 70), edgeLines = true, lineColor = C(226, 222, 210), patches = 1.2, patchVar = "AsphaltTarPatch", poles = true, lights = 160, curb = C(170, 166, 158) }
	S.HWYE = { var = "DowntownAsphaltClean", color = C(120, 120, 122), w = 84, sw = 0, center = "double", centerColor = C(236, 200, 60), lanes = true, edgeLines = true, lineColor = C(240, 240, 236), stopLines = true, signals = true }
	S.RES = { tier = 2, shoebox = true, var = "AsphaltWorn", color = C(130, 130, 132), w = 36, sw = 8, swVar = "SidewalkConcrete", swColor = C(200, 198, 192),
		center = "none", lights = 160, hydrants = 0.18, stop = true, curb = C(200, 198, 192), trees = 105, swGrass = 4 }

	-- painted lane arrow (reference style): shaft, side branches, flat wedge heads. cf on the road surface, -Z = travel direction
	local AR = C(226, 226, 222)
	local function head(par, base, W, Lh)
		local o = { CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.06 }
		L.W(par, Vector3.new(0.04, W / 2, Lh), base * CFrame.new(-W / 4, 0, -Lh / 2) * CFrame.Angles(0, 0, math.pi / 2), AR, M.SmoothPlastic, nil, o)
		L.W(par, Vector3.new(0.04, W / 2, Lh), base * CFrame.new(W / 4, 0, -Lh / 2) * CFrame.Angles(0, 0, -math.pi / 2), AR, M.SmoothPlastic, nil, o)
	end
	function L.roadArrow(par, cf, kind)
		local o = { Transparency = 0.06 }
		local S_, L_, R_ = kind:find("S"), kind:find("L"), kind:find("R")
		local top = S_ and -4.2 or -0.9
		L.D(par, Vector3.new(0.9, 0.04, 4 - top), cf * CFrame.new(0, 0, (4 + top) / 2), AR, M.SmoothPlastic, nil, o)
		if S_ then head(par, cf * CFrame.new(0, 0, top), 3, 3) end
		for sd, on in pairs({ [-1] = L_, [1] = R_ }) do
			if on then
				L.D(par, Vector3.new(3.4, 0.04, 0.9), cf * CFrame.new(sd * 2.1, 0, -0.45), AR, M.SmoothPlastic, nil, o)
				head(par, cf * CFrame.new(sd * 3.7, 0, -0.45) * CFrame.Angles(0, sd < 0 and math.pi / 2 or -math.pi / 2, 0), 2.8, 2.6)
			end
		end
	end

	-- ===== graph =====
	-- lines: { {pts = {{x,z},...}, style = "HOOD"|table, w = width?, cul = bool, cul0 = bool, name = "..."} }
	local function segInt(p1, p2, p3, p4)
		local d1x, d1z = p2[1] - p1[1], p2[2] - p1[2]
		local d2x, d2z = p4[1] - p3[1], p4[2] - p3[2]
		local den = d1x * d2z - d1z * d2x
		if math.abs(den) < 1e-6 then return nil end
		local t = ((p3[1] - p1[1]) * d2z - (p3[2] - p1[2]) * d2x) / den
		local u = ((p3[1] - p1[1]) * d1z - (p3[2] - p1[2]) * d1x) / den
		if t > -1e-6 and t < 1 + 1e-6 and u > -1e-6 and u < 1 + 1e-6 then
			return t, u, p1[1] + d1x * t, p1[2] + d1z * t
		end
	end
	local function proj(p, a, b)
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local l2 = dx * dx + dz * dz
		if l2 < 1e-6 then return 0, a[1], a[2], math.huge end
		local t = math.clamp(((p[1] - a[1]) * dx + (p[2] - a[2]) * dz) / l2, 0, 1)
		local x, z = a[1] + dx * t, a[2] + dz * t
		return t, x, z, math.sqrt((p[1] - x) ^ 2 + (p[2] - z) ^ 2)
	end

	function L.net(lines, opts)
		opts = opts or {}
		local SNAP = opts.snap or 14
		-- 1. snap free endpoints onto nearby segments of other lines (T junctions)
		for li, ln in ipairs(lines) do
			ln.style = type(ln.style) == "string" and S[ln.style] or ln.style
			ln.w = ln.w or ln.style.w
			for _, endIdx in ipairs({ 1, #ln.pts }) do
				local p = ln.pts[endIdx]
				local best, bx, bz = SNAP * 1.6, nil, nil
				for lj, o in ipairs(lines) do
					if lj ~= li then
						for k = 1, #o.pts - 1 do
							local _, x, z, d = proj(p, o.pts[k], o.pts[k + 1])
							if d < best then best, bx, bz = d, x, z end
						end
					end
				end
				if bx then ln.pts[endIdx] = { bx, bz } end
			end
		end
		-- 2. per line: list of (param, x, z) split points
		local splits = {}
		for li, ln in ipairs(lines) do
			local s = {}
			local acc = 0
			for k = 1, #ln.pts do
				if k > 1 then
					acc += math.sqrt((ln.pts[k][1] - ln.pts[k - 1][1]) ^ 2 + (ln.pts[k][2] - ln.pts[k - 1][2]) ^ 2)
				end
				table.insert(s, { acc, ln.pts[k][1], ln.pts[k][2] })
			end
			ln._cum = s
			splits[li] = s
		end
		local function paramAt(ln, k, t)
			local a, b = ln._cum[k], ln._cum[k + 1]
			return a[1] + (b[1] - a[1]) * t
		end
		for li = 1, #lines do
			local A = lines[li]
			for lj = li + 1, #lines do
				local B = lines[lj]
				for i = 1, #A.pts - 1 do
					for j = 1, #B.pts - 1 do
						local t, u, x, z = segInt(A.pts[i], A.pts[i + 1], B.pts[j], B.pts[j + 1])
						if t then
							table.insert(splits[li], { paramAt(A, i, t), x, z })
							table.insert(splits[lj], { paramAt(B, j, u), x, z })
						end
					end
				end
			end
			-- endpoints lying on other lines (after snap) also split them
			for _, endIdx in ipairs({ 1, #A.pts }) do
				local p = A.pts[endIdx]
				for lj, B in ipairs(lines) do
					if lj ~= li then
						for j = 1, #B.pts - 1 do
							local t, x, z, d = proj(p, B.pts[j], B.pts[j + 1])
							if d < 0.5 then table.insert(splits[lj], { paramAt(B, j, t), x, z }) end
						end
					end
				end
			end
		end
		-- 3. nodes + edges
		local nodes, edges, seen = {}, {}, {}
		local function addNode(x, z)
			for id, n in ipairs(nodes) do
				if (n[1] - x) ^ 2 + (n[2] - z) ^ 2 < SNAP * SNAP then return id end
			end
			table.insert(nodes, { x, z })
			return #nodes
		end
		-- intersections first so they win the snap
		for li, ln in ipairs(lines) do
			for k = #ln.pts + 1, #splits[li] do addNode(splits[li][k][2], splits[li][k][3]) end
		end
		for li, ln in ipairs(lines) do
			local s = splits[li]
			table.sort(s, function(a, b) return a[1] < b[1] end)
			local prev
			for k, sp in ipairs(s) do
				local id = addNode(sp[2], sp[3])
				if k == 1 and ln.cul0 then nodes[id].cul = true end
				if k == #s and ln.cul then nodes[id].cul = true end
				if prev and prev ~= id then
					local key = math.min(prev, id) .. "_" .. math.max(prev, id)
					if not seen[key] then
						seen[key] = true
						table.insert(edges, { prev, id, ln.w, ln.style, ln.name or ("Line" .. li) })
					end
				end
				prev = id
			end
		end
		-- 4. drop degenerate edges
		local out = {}
		for _, e in ipairs(edges) do
			local A, B = nodes[e[1]], nodes[e[2]]
			if math.sqrt((A[1] - B[1]) ^ 2 + (A[2] - B[2]) ^ 2) > 3 then table.insert(out, e) end
		end
		return { nodes = nodes, edges = out }
	end

	-- ===== build =====
	local ROAD_Y = 0.25 -- road top above L.G
	function L.buildRoads(parent, net, folderName)
		local root = L.folder(parent, folderName or "Roads")
		local G = L.G
		local nodes, edges = net.nodes, net.edges
		local adj = {}
		for i, e in ipairs(edges) do
			for k = 1, 2 do
				adj[e[k]] = adj[e[k]] or {}
				table.insert(adj[e[k]], i)
			end
		end
		net.adj = adj
		local function outDir(n, ei)
			local e = edges[ei]
			local o = (e[1] == n) and e[2] or e[1]
			local A, B = nodes[n], nodes[o]
			return Vector3.new(B[1] - A[1], 0, B[2] - A[2]).Unit
		end
		local function maxW(n)
			local w = 0
			for _, ej in ipairs(adj[n]) do w = math.max(w, edges[ej][3]) end
			return w
		end
		-- trim for the sidewalk on one side (lat = world lateral unit vector of that sidewalk)
		local function trimSide(n, ei, lat)
			-- how far this side's sidewalk must stop short of node n so neither its inner (curb) nor outer edge
			-- pokes into the carriageway of any road arriving on this side. nil = nothing on this side.
			local list = adj[n]
			if #list < 2 then return nil end
			local d0 = outDir(n, ei)
			local hwI, swI = edges[ei][3] / 2, edges[ei][4].sw or 0
			local t
			for _, oj in ipairs(list) do
				if oj ~= ei then
					local d1 = outDir(n, oj)
					if d1:Dot(lat) > 0.02 and d1:Dot(d0) > -0.985 then
						local k = d1:Cross(d0).Y
						local c = d1:Cross(lat).Y
						if math.abs(k) < 0.15 then k = (k >= 0) and 0.15 or -0.15 end
						local sg = (k >= 0) and 1 or -1
						local W = edges[oj][3] / 2 + 0.6
						for _, o in ipairs({ hwI, hwI + swI }) do
							t = math.max(t or 0, (W - sg * o * c) / math.abs(k))
						end
					end
				end
			end
			return t
		end
		local function trimRoad(n, ei)
			local list = adj[n]
			if #list < 3 then return 0 end
			local d0 = outDir(n, ei)
			local t = 0
			for _, oj in ipairs(list) do
				if oj ~= ei then
					local d1 = outDir(n, oj)
					-- the straight-through continuation of this road doesn't cut into it
					if d1:Dot(d0) > -0.9 then
						local s = math.max(math.abs(d0:Cross(d1).Y), 0.45)
						t = math.max(t, (edges[oj][3] / 2) / s)
					end
				end
			end
			return t
		end
		local function crossName(n, ei)
			local d0 = outDir(n, ei)
			local best, bd = nil, 2
			for _, oj in ipairs(adj[n]) do
				if oj ~= ei and edges[oj][5] and edges[oj][5] ~= edges[ei][5] then
					local dd = math.abs(outDir(n, oj):Dot(d0))
					if dd < bd then best, bd = edges[oj][5], dd end
				end
			end
			return (best or ""):gsub(" [WEXNS]$", "")
		end
		local function isMajor(n, ei)
			return edges[ei][3] >= maxW(n) - 0.5
		end
		local nodeDone = {}
		for i, e in ipairs(edges) do
			local st = e[4]
			local seg = Instance.new("Model")
			seg.Name = e[5] or ("Road_" .. i)
			local A, B = nodes[e[1]], nodes[e[2]]
			local a = Vector3.new(A[1], G, A[2])
			local b = Vector3.new(B[1], G, B[2])
			local len = (b - a).Magnitude
			local d0 = (b - a).Unit
			local right = Vector3.new(-d0.Z, 0, d0.X)
			local w = e[3]
			local hw = w / 2
			local yTop = ROAD_Y -- every carriageway at exactly the same height: no steps for cars
			local cf0 = CFrame.lookAt(a, b)
			local degA, degB = #adj[e[1]], #adj[e[2]]
			local ka = degA == 1 and "end" or (degA == 2 and "bend" or "junction")
			local kb = degB == 1 and "end" or (degB == 2 and "bend" or "junction")
			local ta, tb = trimRoad(e[1], i), trimRoad(e[2], i)
			-- asphalt
			-- junction ends stop at the junction edge (the junction plate fills the box) so slabs never overlap
			local s0 = (ka == "end") and (A.cul and 0 or -hw * 0.2) or ((ka == "junction") and math.max(0, ta - 0.2) or -0.5)
			local s1 = (kb == "end") and len + (B.cul and 0 or hw * 0.2) or ((kb == "junction") and (len - math.max(0, tb - 0.2)) or len + 0.5)
			local road = L.P(seg, Vector3.new(w, 0.8, s1 - s0), cf0 * CFrame.new(0, yTop - 0.4, -(s0 + s1) / 2), st.color, M.Asphalt, st.var)
			road.Name = "Asphalt"
			road.CastShadow = false
			-- bridge detection (over water)
			local wet = {}
			local nS = math.max(2, math.floor(len / 12))
			for k = 0, nS do
				local p = a + d0 * (len * k / nS)
				wet[k] = L.isWater(p.X, p.Z)
			end
			local anyWet = false
			for k = 0, nS do if wet[k] then anyWet = true end end
			-- sidewalks (per side trims)
			local sw = st.sw or 0
			local swTop = 0.9
			for side = -1, 1, 2 do
				local lat = right * side
				local function sideTrim(k, nn)
					if k ~= "junction" and k ~= "bend" then return 0 end
					local ts = trimSide(nn, i, lat)
					if ts then return ts end
					return (k == "bend") and -(0.4 * (hw + sw)) or 0
				end
				local sa = sideTrim(ka, e[1])
				local sb = sideTrim(kb, e[2])
				local l0, l1 = sa, len - sb
				if sw > 0 and l1 - l0 > 1 and not (st.swDrop and L.chance(st.swDrop)) then
					local h = swTop + ((i + side) % 3) * 0.015
					local p = L.P(seg, Vector3.new(sw, h, l1 - l0), cf0 * CFrame.new(side * (hw + sw / 2), h / 2 - 0.0, -(l0 + l1) / 2), st.swColor, M.Concrete, st.swVar)
					p.Name = "Sidewalk"
					p.CastShadow = false
					-- curb strip (and red-painted curb near corners in the hood)
					if st.curb then
						L.D(seg, Vector3.new(0.7, h + 0.03, l1 - l0), cf0 * CFrame.new(side * (hw + 0.35), (h + 0.03) / 2, -(l0 + l1) / 2), st.curb, M.Concrete, "ConcretePlain")
						if st.redCurb then
							for endK = 1, 2 do
								if (endK == 1 and ka == "junction") or (endK == 2 and kb == "junction") then
									local rl = math.min(18, (l1 - l0) / 3)
									local zc = endK == 1 and (l0 + rl / 2) or (l1 - rl / 2)
									L.D(seg, Vector3.new(0.74, h + 0.05, rl), cf0 * CFrame.new(side * (hw + 0.35), (h + 0.05) / 2, -zc), C(176, 52, 44), M.Concrete)
								end
							end
						end
					end
					-- grass strip between curb and walk (suburbs)
					if st.swGrass then
						local vl = l1 - l0 - 20
						if vl > 6 then
							L.D(seg, Vector3.new(st.swGrass, 0.08, vl), cf0 * CFrame.new(side * (hw + 0.7 + st.swGrass / 2), h + 0.02, -(l0 + l1) / 2), C(104, 140, 66), M.Grass, "LawnGrassB")
							-- raised concrete edge on the walk side of the verge
							L.D(seg, Vector3.new(0.35, 0.18, vl), cf0 * CFrame.new(side * (hw + 0.7 + st.swGrass + 0.17), h + 0.07, -(l0 + l1) / 2), C(196, 194, 188), M.Concrete)
						end
					end
					-- bridge railing
					if anyWet then
						L.P(seg, Vector3.new(0.8, 3.4, l1 - l0), cf0 * CFrame.new(side * (hw + sw - 0.4), h + 1.7, -(l0 + l1) / 2), C(196, 192, 184), M.Concrete, "BridgeConcretePanels")
					end
					-- street life along this side
					local function at(z, off) return (cf0 * CFrame.new(side * (hw + off), h, -z)).Position end
					if st.hydrants and L.chance(st.hydrants) and l1 - l0 > 30 then L.hydrant(seg, at(l0 + L.r(6, 12), 1.8)) end
					if st.trash and L.chance(st.trash) and l1 - l0 > 30 then L.trashcan(seg, at(l1 - L.r(5, 9), 1.8)) end
					if st.bags and L.chance(st.bags) and l1 - l0 > 40 then L.trashBags(seg, at(L.r(l0 + 10, l1 - 10), 2.2)) end
					if st.weeds and l1 - l0 > 20 then
						for _ = 1, math.floor((l1 - l0) / 90 * st.weeds + L.r(0, 1)) do L.weeds(seg, at(L.r(l0 + 2, l1 - 2), sw - 0.6)) end
					end
					if st.trees and l1 - l0 > 40 then
						local z = l0 + 14
						while z < l1 - 10 do
							L.D(seg, Vector3.new(4, 0.1, 4), cf0 * CFrame.new(side * (hw + 3), h + 0.02, -z), C(70, 56, 42), M.Ground, "LeafLitter")
							L.tree(seg, at(z, 3), L.r(0.7, 0.95))
							z += st.trees + L.r(-8, 8)
						end
					end
					if st.sidePalms and l1 - l0 > 40 and not anyWet then
						local z = l0 + 16 + (st.center == "median" and st.sidePalms / 2 or 0)
						while z < l1 - 12 do
							L.streetPalm(seg, at(z, st.swGrass and (0.7 + st.swGrass / 2) or (sw - 2.4)), z, nil, cf0.LookVector)
							z += st.sidePalms
						end
					end
					if st.busStop and L.chance(st.busStop) and l1 - l0 > 90 and not anyWet then
						local z = (l0 + l1) / 2
						L.busStop(seg, cf0 * CFrame.new(side * (hw + sw / 2 + 1), h, -z) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0))
					end
					-- storm drain on the curb face near the downstream corner
					if st.drains and l1 - l0 > 24 then
						L.D(seg, Vector3.new(0.3, 0.5, 3.2), cf0 * CFrame.new(side * (hw - 0.05), yTop + 0.1, -(l1 - 6)), C(30, 30, 30), M.Metal)
						L.D(seg, Vector3.new(1.6, 0.05, 3.2), cf0 * CFrame.new(side * (hw - 0.9), yTop + 0.02, -(l1 - 6)), C(46, 46, 46), M.DiamondPlate)
					end
					-- stop sign at the right-hand corner of a minor approach
					if st.stop then
						for endK = 1, 2 do
							local kk = endK == 1 and ka or kb
							local nn = endK == 1 and e[1] or e[2]
							-- right-hand side when driving INTO the node: for end b that's side +1, for end a that's side -1
							if kk == "junction" and ((endK == 2 and side == 1) or (endK == 1 and side == -1)) and not isMajor(nn, i) and not st.signals then
								local z = endK == 1 and (l0 + 2.5) or (l1 - 2.5)
								local p = at(z, 1.6)
								local look = endK == 2 and -d0 or d0
								L.stopSign(seg, CFrame.lookAt(p, p + look))
							end
						end
					end
					if L.streetSide and st.tier then
						local sig = function(nn) return st.signals and maxW(nn) >= 34 end
						L.streetSide(seg, { tier = st.tier, cf0 = cf0, side = side, hw = hw, sw = sw, h = h, l0 = l0, l1 = l1,
							corner1 = ka == "junction" and side == -1, corner2 = kb == "junction" and side == 1,
							name = (e[5] or ""):gsub(" [WEXNS]$", ""), cross1 = ka == "junction" and crossName(e[1], i) or "", cross2 = kb == "junction" and crossName(e[2], i) or "",
							signal1 = ka == "junction" and sig(e[1]), signal2 = kb == "junction" and sig(e[2]), oneway = st.oneway, metroNear = st.tier == 3 })
					end
					-- traffic signal on the right-hand corner of a signalised approach
					if st.signals then
						for endK = 1, 2 do
							local kk = endK == 1 and ka or kb
							local nn = endK == 1 and e[1] or e[2]
							if kk == "junction" and ((endK == 2 and side == 1) or (endK == 1 and side == -1)) and maxW(nn) >= 34 then
								local z = endK == 1 and (l0 + 3) or (l1 - 3)
								-- arm points across the approach lanes (toward the road centre)
								local p = at(z, 2)
								local toward = (cf0 * CFrame.new(0, h, -z)).Position
								local armLen = hw + 2 - (st.center == "median" and 0 or hw * 0.05)
								L.trafficLight(seg, CFrame.lookAt(p, Vector3.new(toward.X, p.Y, toward.Z)), math.max(10, armLen), nil, crossName(nn, i))
							end
						end
					end
				end
			end
			-- bridge piers
			if anyWet then
				for k = 1, nS - 1 do
					if wet[k] and k % 3 == 0 then
						local p = a + d0 * (len * k / nS)
						L.P(seg, Vector3.new(w * 0.7, 18, 4), CFrame.lookAt(p, p + d0) * CFrame.new(0, -9.4, 0), C(170, 168, 160), M.Concrete, "BridgeConcretePanels")
					end
				end
				L.D(seg, Vector3.new(w + 2 * sw, 1.6, len), cf0 * CFrame.new(0, -0.6, -len / 2), C(160, 158, 150), M.Concrete, "BridgeConcretePanels")
			end
			-- markings
			local la = (ka == "junction") and (ta + 3) or 0
			local lb = (kb == "junction") and (tb + 3) or 0
			local m0, m1 = la, len - lb
			local lc = st.lineColor or C(230, 230, 220)
			local lt = st.lineTrans or 0
			local ly = yTop + 0.02
			local function strip(x, z0, z1, width, col, trans)
				if z1 - z0 < 0.5 then return end
				local p = L.D(seg, Vector3.new(width, 0.04, z1 - z0), cf0 * CFrame.new(x, ly, -(z0 + z1) / 2), col or lc, M.Concrete, nil, { Transparency = trans or lt })
				p.Name = "Line"
				return p
			end
			local function dashes(x, z0, z1, col)
				-- broken lane line: 10 ft dash / 30 ft gap (9 / 27 studs)
				local z = z0 + 6
				while z + 9 < z1 do
					strip(x, z, z + 9, 0.45, col)
					z += 36
				end
			end
			if m1 - m0 > 4 then
				if st.center == "single" then
					strip(0, m0, m1, 0.55)
				elseif st.center == "double" then
					strip(-0.5, m0, m1, 0.42, st.centerColor)
					strip(0.5, m0, m1, 0.42, st.centerColor)
				elseif st.center == "dashed" then
					dashes(0, m0, m1, st.centerColor)
				elseif st.center == "median" then
					local mw = st.medianW or 10
					local med = L.P(seg, Vector3.new(mw, 1.1, m1 - m0), cf0 * CFrame.new(0, 0.55, -(m0 + m1) / 2), C(206, 204, 198), M.Concrete, "ConcretePlain")
					med.Name = "Median"
					-- inset planting bed: lawn edges, a darker mulch spine, shrub clusters between the palms
					L.D(seg, Vector3.new(mw - 1.6, 0.14, m1 - m0 - 1.6), cf0 * CFrame.new(0, 1.16, -(m0 + m1) / 2), C(92, 116, 62), M.Grass, "LawnGrassB")
					L.D(seg, Vector3.new(4.2, 0.16, m1 - m0 - 6), cf0 * CFrame.new(0, 1.18, -(m0 + m1) / 2), C(122, 84, 58), M.Ground)
					if st.palms and not anyWet then
						local z = m0 + 12
						while z < m1 - 10 do
							L.streetPalm(seg, (cf0 * CFrame.new(0, 1.2, -z)).Position, z, "date")
							L.D(seg, Vector3.new(0.7, 0.3, 0.7), cf0 * CFrame.new(1.4, 1.3, -z), C(255, 236, 200), M.Neon)
							if z + st.palms / 2 < m1 - 10 then
								for k = -1, 1 do L.bush(seg, (cf0 * CFrame.new(k * 1.6, 1.2, -(z + st.palms / 2 + k * 3))).Position, L.r(2.6, 3.4)) end
							end
							z += st.palms
						end
					end
				end
				if st.lanes then
					local off = (st.center == "median") and ((st.medianW or 10) / 2) or 0
					local q = (hw - off) / 2 + off
					dashes(-q, m0, m1)
					dashes(q, m0, m1)
				end
				if st.edgeLines then
					strip(-hw + 1.4, m0, m1, 0.4)
					strip(hw - 1.4, m0, m1, 0.4)
				end
				if st.bike then
					for sd = -1, 1, 2 do
						strip(sd * (hw - 6), m0, m1, 0.5)
						L.D(seg, Vector3.new(4.4, 0.03, m1 - m0), cf0 * CFrame.new(sd * (hw - 3.4), yTop + 0.012, -(m0 + m1) / 2), C(62, 132, 86), M.SmoothPlastic).Name = "BikeLane"
					end
				end
			end
			-- red bus-only lane on the outer lane of downtown boulevards
			if st.busLane and m1 - m0 > 80 then
				local lw = (hw - (st.medianW or 10) / 2) / 2
				for sd = -1, 1, 2 do
					local x = sd * (hw - lw / 2 - 0.4)
					L.D(seg, Vector3.new(lw - 1.2, 0.03, m1 - m0 - 40), cf0 * CFrame.new(x, yTop + 0.011, -(m0 + m1) / 2), C(150, 46, 40), M.Concrete, nil, { Transparency = 0.25 }).Name = "BusLane"
					if L.roadText then
						local z = m0 + 30
						while z < m1 - 30 do
							L.roadText(seg, cf0 * CFrame.new(x, ly, -z) * CFrame.Angles(0, sd < 0 and math.pi or 0, 0), "BUS ONLY", lw - 3, 3.4)
							z += 110
						end
					end
				end
			end
			-- crosswalks, stop lines, arrows at junction ends
			for endIdx = 1, 2 do
				local kk = endIdx == 1 and ka or kb
				if kk == "junction" then
					local t = endIdx == 1 and ta or tb
					local zc = endIdx == 1 and (t + 5) or (len - t - 5)
					local sg = endIdx == 1 and -1 or 1 -- approach lanes: for end b it's the +x half
					if st.cross == "ladder" then
						strip(0, zc - 4.4, zc - 3.6, w - 1, C(232, 232, 226), 0.15)
						strip(0, zc + 3.6, zc + 4.4, w - 1, C(232, 232, 226), 0.15)
					elseif st.cross == "zebra" then
						-- continental crosswalk: wide bars between two edge lines
						local n = math.floor((w - 3) / 5.2)
						local x0 = -(n - 1) * 5.2 / 2
						for k = 0, n - 1 do
							strip(x0 + k * 5.2, zc - 3.9, zc + 3.9, 2.8, C(236, 236, 232), 0.06)
						end
						strip(0, zc - 4.9, zc - 4.3, w - 1, C(236, 236, 232), 0.06)
						strip(0, zc + 4.3, zc + 4.9, w - 1, C(236, 236, 232), 0.06)
					elseif st.cross == "brick" then
						L.D(seg, Vector3.new(w - 0.4, 0.05, 9), cf0 * CFrame.new(0, yTop + 0.015, -zc), C(150, 84, 64), M.Brick, "DowntownBrickPavers")
						strip(0, zc - 4.7, zc - 4.3, w - 0.6, C(240, 240, 236), 0)
						strip(0, zc + 4.3, zc + 4.7, w - 0.6, C(240, 240, 236), 0)
					end
					if st.stopLines or st.cross then
						local zs = endIdx == 1 and (t + 10.9) or (len - t - 10.9)
						local off = (st.center == "median") and ((st.medianW or 10) / 2) or 0.5
						local half = hw - off
						strip(sg * (off + half / 2), zs - 0.55, zs + 0.55, half - 0.6, C(236, 236, 232), 0.06)
					end
					if st.arrows and len > 70 then
						local off = (st.center == "median") and ((st.medianW or 10) / 2) or 0
						local za = endIdx == 1 and (t + 24) or (len - t - 24)
						local lanes = st.lanes and 2 or 1
						for ln = 1, lanes do
							local x = sg * (off + (hw - off) * (ln - 0.5) / lanes)
							local kind
							if lanes == 1 then kind = L.pick({ "LSR", "LS", "SR", "LR" }) else kind = (ln == 1) and "LS" or "SR" end
							-- travel direction on this half points toward the junction
							local acf = cf0 * CFrame.new(x, ly, -za) * CFrame.Angles(0, endIdx == 1 and math.pi or 0, 0)
							L.roadArrow(seg, acf, kind)
							if st.tier == 3 and L.roadText then L.roadText(seg, acf * CFrame.new(0, 0, 8), "ONLY", 4.6, 2.6) end
						end
					end
				end
			end
			-- tar patches like the reference photos: dark irregular slab with a pale ragged sealant border
			local pz0, pz1 = (ka == "junction" and ta + 16 or 8), len - (kb == "junction" and tb + 16 or 8)
			if st.patches and st.patches > 0 and pz1 - pz0 > 10 then
				local n = math.max(1, math.floor(st.patches * (pz1 - pz0) / 110 + L.r(0, 1)))
				for _ = 1, n do
					local pz = L.r(pz0, pz1)
					local px = L.r(-hw + 3, hw - 3)
					local pw, pl = L.r(4, math.min(13, w - 6)), L.r(5, 18)
					local pc = cf0 * CFrame.new(px, yTop + 0.01, -pz) * CFrame.Angles(0, L.r(-0.1, 0.1), 0)
					-- utility-cut patch: dark fill inside a pale, ragged sealant rim (two offset rims = crumbly edge)
					local dark = L.shade(st.color, L.r(0.7, 0.8))
					local rim = C(164, 160, 152)
					local o1 = CFrame.Angles(0, L.r(-0.04, 0.04), 0)
					L.D(seg, Vector3.new(pw + 1.5, 0.026, pl + 1.5), pc * o1, rim, M.Concrete, nil, { Transparency = 0.55 })
					L.D(seg, Vector3.new(pw + 0.9, 0.027, pl + 2.1), pc * CFrame.new(L.r(-0.3, 0.3), 0.001, L.r(-0.3, 0.3)) * CFrame.Angles(0, L.r(-0.05, 0.05), 0), rim, M.Concrete, nil, { Transparency = 0.7 })
					L.D(seg, Vector3.new(pw, 0.032, pl), pc * o1 * CFrame.new(0, 0.004, 0), dark, M.Asphalt, st.patchVar)
				end
			end
			if len > 60 and L.chance(0.6) then
				L.D(seg, Vector3.new(0.05, 2.8, 2.8), cf0 * CFrame.new(L.r(-hw / 3, hw / 3), yTop + 0.02, -L.r(20, len - 20)) * CFrame.Angles(0, 0, math.pi / 2), C(52, 50, 48), M.DiamondPlate, nil, { Shape = Enum.PartType.Cylinder })
			end
			-- utility poles with sagging wires (Beams)
			if st.poles and len > 50 and not anyWet then
				local side = (i % 2 == 0) and 1 or -1
				local off = hw + (sw > 0 and sw - 1.2 or 2.5)
				local prevAtt
				local z = math.max(14, (ka == "junction" and ta + 14 or 0))
				while z < len - math.max(10, (kb == "junction" and tb + 14 or 0)) do
					local pc = cf0 * CFrame.new(side * off, 0.9, -z)
					local pole = L.Cyl(seg, 36, 1.15, pc * CFrame.new(0, 18, 0), C(98, 80, 62), M.Wood)
					pole.Name = "UtilityPole"
					pole.CastShadow = true
					local arm = L.D(seg, Vector3.new(8, 0.5, 0.5), pc * CFrame.new(0, 33.5, 0), C(98, 80, 62), M.Wood)
					L.D(seg, Vector3.new(5, 0.4, 0.4), pc * CFrame.new(0, 30.5, 0), C(98, 80, 62), M.Wood)
					if L.chance(0.35) then L.Cyl(seg, 3.2, 2.1, pc * CFrame.new(side * -1.5, 29.5, 0), C(126, 126, 124), M.Metal) end
					local atts = {}
					for k, x in ipairs({ -3.6, 0, 3.6 }) do
						local att = Instance.new("Attachment")
						att.Position = Vector3.new(x, 0.3, 0)
						att.Parent = arm
						atts[k] = att
					end
					if prevAtt then
						for k = 1, 3 do
							local bm = Instance.new("Beam")
							bm.Attachment0 = prevAtt[k]
							bm.Attachment1 = atts[k]
							bm.Width0 = 0.12
							bm.Width1 = 0.12
							bm.Color = ColorSequence.new(C(24, 24, 24))
							bm.CurveSize0 = -2.5
							bm.CurveSize1 = 2.5
							bm.FaceCamera = true
							bm.Segments = 8
							bm.LightInfluence = 1
							bm.Parent = arm
						end
					end
					prevAtt = atts
					z += L.r(70, 90)
				end
			end
			-- street lights
			if st.lights and len > 40 then
				local z = math.max(24, (ka == "junction" and ta + 16 or 0))
				local k = i % 2
				while z < len - math.max(12, (kb == "junction" and tb + 16 or 0)) do
					local side = (k % 2 == 0) and 1 or -1
					local p = (cf0 * CFrame.new(side * (hw + 1.6), 0.9, -z)).Position
					local toward = (cf0 * CFrame.new(0, 0.9, -z)).Position
					L.streetlight(seg, CFrame.lookAt(p, toward), st.modernLights, st.shoebox)
					if st.center == "median" then
						-- double-headed light in the median
						L.streetlight(seg, CFrame.lookAt((cf0 * CFrame.new(0, 1.1, -z - 30)).Position, (cf0 * CFrame.new(1, 1.1, -z - 30)).Position), true)
						L.streetlight(seg, CFrame.lookAt((cf0 * CFrame.new(0, 1.1, -z - 30)).Position, (cf0 * CFrame.new(-1, 1.1, -z - 30)).Position), true)
					end
					z += st.lights
					k += 1
				end
			end
			seg.Parent = root
			-- node fills: bends, junction plates, cul-de-sacs
			for k = 1, 2 do
				local n = e[k]
				if not nodeDone[n] then
					nodeDone[n] = true
					local N = nodes[n]
					local deg = #adj[n]
					-- plates sit 0.02 below the carriageway so where they overlap the slab ends the slab always wins
					local nc = CFrame.new(N[1], G + ROAD_Y - 0.02 - 0.4, N[2])
					if deg == 2 then
						L.Cyl(root, 0.8, w, nc, st.color, M.Asphalt, st.var, { CastShadow = false }).Name = "Bend"
					elseif deg >= 3 then
						local mw = maxW(n)
						local rr = 0
						for _, ej in ipairs(adj[n]) do rr = math.max(rr, trimRoad(n, ej)) end
						L.Cyl(root, 0.8, math.max(mw * 1.02, rr * 2.9 + 1), nc, st.color, M.Asphalt, st.var, { CastShadow = false }).Name = "Junction"
						if st.hatch and mw >= 30 and L.chance(st.hatch) then
							-- yellow box junction aligned with the widest road: border + 45-degree stripes clipped to the box
							local wide = adj[n][1]
							for _, ej in ipairs(adj[n]) do if edges[ej][3] > edges[wide][3] then wide = ej end end
							local dir = outDir(n, wide)
							local hb = L.model(root, "HatchBox")
							local pos = Vector3.new(N[1], G + ROAD_Y + 0.03, N[2])
							local bc = CFrame.lookAt(pos, pos + dir)
							local az = trimRoad(n, wide) - 1.6
							local ax = az
							for _, ej in ipairs(adj[n]) do
								if math.abs(outDir(n, ej):Dot(dir)) < 0.5 then ax = trimRoad(n, ej) - 1.6 break end
							end
							local Y = C(168, 138, 58)
							local step, sw2 = 7, 3.4
							local c = -(ax + az) + step / 2
							while c < ax + az do
								-- stripe along x - z = c, clipped to the box
								local x0, x1 = math.max(-ax, c - az), math.min(ax, c + az)
								if x1 - x0 > 0.6 then
									local mx = (x0 + x1) / 2
									L.D(hb, Vector3.new(sw2, 0.035, (x1 - x0) * math.sqrt(2)), bc * CFrame.new(mx, 0, mx - c) * CFrame.Angles(0, math.pi / 4, 0), Y, M.Concrete, nil, { Transparency = 0.62 })
								end
								c += step
							end
						end
					elseif deg == 1 and N.cul then
						L.Cyl(root, 0.8, w * 1.7, nc, st.color, M.Asphalt, st.var, { CastShadow = false }).Name = "CulDeSac"
					end
				end
			end
			if i % 12 == 0 then task.wait() end
		end
		return root
	end

	-- ===== 3D roads: highways, ramps, bridges =====
	-- pts: list of Vector3 (y = road top). opts: {barriers, median, lanes, piers, lights, var, color, gaps = {{from,to,side}}}
	function L.road3D(parent, pts, w, opts)
		opts = opts or {}
		local m = L.model(parent, opts.name or "Road3D")
		local col = opts.color or C(86, 86, 90)
		local var = opts.var or "DowntownAsphaltClean"
		local acc = 0
		local function gapAt(s, side)
			for _, g in ipairs(opts.gaps or {}) do
				if s >= g[1] and s <= g[2] and (g[3] == 0 or g[3] == side) then return true end
			end
			return false
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt(a, b)
			local mid = cf * CFrame.new(0, 0, -len / 2)
			-- deck (asphalt on a concrete slab)
			L.P(m, Vector3.new(w, 0.6, len + 1), mid * CFrame.new(0, -0.3, 0), col, M.Asphalt, var)
			local elevated = math.min(a.Y, b.Y) > L.G + 3
			if elevated or opts.slab then
				L.P(m, Vector3.new(w + 1, 3.4, len + 1), mid * CFrame.new(0, -2.3, 0), C(176, 172, 164), M.Concrete, "OverpassConcrete")
			end
			-- jersey barriers
			if opts.barriers ~= false then
				for side = -1, 1, 2 do
					-- split each barrier in 3 pieces so gaps can drop single pieces
					for k = 0, 2 do
						local s0 = acc + len * k / 3
						if not gapAt(s0 + len / 6, side) then
							local bc = mid * CFrame.new(side * (w / 2 - 0.8), 1.4, -len / 2 + len * (k + 0.5) / 3)
							L.P(m, Vector3.new(1.4, 2.8, len / 3 + 0.2), bc, C(198, 196, 190), M.Concrete, "ConcretePlain")
						end
					end
				end
			end
			if opts.median then
				L.P(m, Vector3.new(1.6, 2.8, len + 0.4), mid * CFrame.new(0, 1.4, 0), C(198, 196, 190), M.Concrete, "ConcretePlain")
			end
			-- markings
			local ly = 0.03
			local function strip(x, z0, z1, width, c2)
				L.D(m, Vector3.new(width, 0.05, z1 - z0), cf * CFrame.new(x, ly, -(z0 + z1) / 2), c2 or C(240, 240, 236), M.SmoothPlastic)
			end
			local half = w / 2
			if opts.median then
				strip(-1.6, 0, len, 0.45, C(236, 200, 60)); strip(1.6, 0, len, 0.45, C(236, 200, 60))
			end
			strip(-half + 2, 0, len, 0.45); strip(half - 2, 0, len, 0.45)
			local lanes = opts.lanes or 0
			if lanes > 1 then
				local inner = opts.median and 1.6 or 0
				local lw = (half - 2 - inner) / lanes
				for side = -1, 1, 2 do
					for k = 1, lanes - 1 do
						local x = side * (inner + k * lw)
						local z = (acc % 40)
						z = 4
						while z + 10 < len do strip(x, z, z + 10, 0.4); z += 40 end
					end
				end
			end
			-- piers
			if elevated and opts.piers ~= false then
				local step = opts.pierStep or 60
				local first = math.ceil(acc / step) * step - acc
				local s = first
				local rot = CFrame.lookAt(Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z))
				rot = rot - rot.Position
				local opR = OverlapParams.new()
				opR.FilterType = Enum.RaycastFilterType.Include
				opR.FilterDescendantsInstances = { workspace.ViceBay:FindFirstChild("Roads") }
				while s < len do
					local p = cf * CFrame.new(0, 0, -s)
					local top = p.Position.Y - 4
					if top > L.G + 6 then
						local h = top - (L.WATER - 6)
						local base = CFrame.new(p.Position.X, top - h / 2, p.Position.Z) * rot
						local any = false
						for _, x in ipairs({ -w / 4, w / 4 }) do
							local col = base * CFrame.new(x, 0, 0)
							local gp = Vector3.new(col.Position.X, L.G + 1, col.Position.Z)
							if #workspace:GetPartBoundsInBox(CFrame.new(gp), Vector3.new(5, 2, 5), opR) == 0 then
								L.P(m, Vector3.new(4.5, h, 4.5), col, C(176, 172, 164), M.Concrete, "OverpassPrecast")
								any = true
							end
						end
						if any then L.P(m, Vector3.new(w * 0.8, 3, 5), CFrame.new(p.Position.X, top - 1.5, p.Position.Z) * rot, C(170, 166, 158), M.Concrete, "OverpassConcrete") end
					end
					s += step
				end
			end
			-- lights on the median
			if opts.lights and opts.median then
				local s = (math.ceil(acc / opts.lights) * opts.lights) - acc
				while s < len do
					local p = (cf * CFrame.new(0, 2.8, -s)).Position
					L.Cyl(m, 24, 0.7, CFrame.new(p + Vector3.new(0, 12, 0)), C(70, 72, 76), M.Metal)
					for side = -1, 1, 2 do
						local f = CFrame.lookAt(p, p + cf.RightVector * side)
						L.D(m, Vector3.new(0.4, 0.4, 7), f * CFrame.new(0, 23.6, -3.4), C(70, 72, 76), M.Metal)
						L.D(m, Vector3.new(1.4, 0.4, 3), f * CFrame.new(0, 23.4, -7.6), C(255, 240, 220), M.Neon)
					end
					s += opts.lights
				end
			end
			acc += len
			if i % 4 == 0 then task.wait() end
		end
		return m
	end

	-- overhead green sign gantry across a 3D road at point p facing direction dir
	function L.gantry(parent, p, dir, w, text, sub)
		local m = L.model(parent, "SignGantry")
		local cf = CFrame.lookAt(p, p + dir)
		for side = -1, 1, 2 do L.P(m, Vector3.new(1.2, 26, 1.2), cf * CFrame.new(side * (w / 2 + 1), 13, 0), C(150, 152, 156), M.Metal) end
		L.P(m, Vector3.new(w + 3, 1.6, 1.6), cf * CFrame.new(0, 25, 0), C(150, 152, 156), M.Metal)
		local sw = math.min(w * 0.45, 28)
		-- reflective green panel with a white border, readable from both directions
		L.D(m, Vector3.new(sw + 0.6, 8.6, 0.3), cf * CFrame.new(w * 0.2, 21, -1), Color3.new(1, 1, 1), M.SmoothPlastic)
		local s = L.D(m, Vector3.new(sw, 8, 0.5), cf * CFrame.new(w * 0.2, 21, -1), C(16, 110, 60), M.SmoothPlastic)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			L.text(s, f, text .. (sub and ("\n" .. sub) or ""), { font = Enum.Font.Highway, color = Color3.new(1, 1, 1), size = UDim2.fromScale(0.9, 0.8), pos = UDim2.fromScale(0.05, 0.1), pps = 12, dist = 500, light = 0.4 })
		end
		return m
	end

	-- cut a gap in any sidewalk crossing a box (curb cut for ramps / driveways)
	function L.cutSidewalk(cf, size, folderName)
		-- clear street furniture standing in the cut (trees, lights, hydrants, bins, tree pits)
		local roadsF = workspace.ViceBay:FindFirstChild(folderName or "Roads")
		if roadsF then
			local clear = { Tree = true, Palm = true, Hydrant = true, StreetLight = true, BusStop = true, Bench = true, StopSign = true, Plant = true, Bush = true, StreetFurniture = true, TrashCan = true }
			for _, d in ipairs(roadsF:GetDescendants()) do
				local lp2
				if d:IsA("Model") and clear[d.Name] then
					lp2 = cf:PointToObjectSpace(d:GetPivot().Position)
				elseif d:IsA("BasePart") and (d.Name == "Part") and d.Material == Enum.Material.Ground then
					lp2 = cf:PointToObjectSpace(d.Position)
				end
				if lp2 and math.abs(lp2.X) < size.X / 2 + 4 and math.abs(lp2.Z) < size.Z / 2 + 4 then d:Destroy() end
			end
		end
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = { roadsF }
		if not roadsF then return end
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
			if p.Name == "Sidewalk" then
				local lp = p.CFrame:PointToObjectSpace(cf.Position)
				local half = p.Size.Z / 2
				local ax = p.CFrame.LookVector
				local hx = math.abs(ax:Dot(cf.RightVector)) * size.X / 2 + math.abs(ax:Dot(cf.LookVector)) * size.Z / 2
				local g0, g1 = lp.Z - hx, lp.Z + hx
				local function piece(z0, z1)
					if z1 - z0 < 1 then return end
					local q = p:Clone()
					q.Size = Vector3.new(p.Size.X, p.Size.Y, z1 - z0)
					q.CFrame = p.CFrame * CFrame.new(0, 0, (z0 + z1) / 2)
					q.Parent = p.Parent
				end
				piece(-half, math.max(-half, g0))
				piece(math.min(half, g1), half)
				p:Destroy()
			end
		end
	end
end
