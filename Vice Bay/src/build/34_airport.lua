-- 34 Vice Bay International (VBI): the airport district on new land north of Coral County.
-- Coral Way runs straight on as Airport Rd / Airport Blvd to the terminal curb. Landside: terminal with a
-- walk-in hall (check-in islands, departures boards, security, seating), parking lots with palm islands,
-- cargo sheds, hangars, control tower. Airside: apron with three gates + jet bridges, parallel taxiway and
-- a 1,960-stud runway that is open to cars through the service gate - the longest full-speed strip on the map.
-- Low-poly and light: big flat slabs, markings as thin decals, aircraft from ~28 parts each.
return function(L)
	local M, C = L.M, L.C
	local G, WL = L.G, L.WATER
	local T = workspace.Terrain
	local VB = workspace.ViceBay
	for _, n in ipairs({ "Airport" }) do local f = VB:FindFirstChild(n) if f then f:Destroy() end end
	local AP = L.folder(VB, "Airport")
	L.seed(3434)
	local t0 = os.clock()
	local TOP = G + 0.25 -- every paved surface at road height

	-- ===== layout (world x/z) =====
	local LX0, LX1, LZ0, LZ1 = -4500, -2350, 1540, 2600
	local RWY = { x0 = -4380, x1 = -2420, z = 2385, w = 110 }
	local TWY = { x0 = -4300, x1 = -2500, z = 2225, w = 50 }
	local APRON = { x0 = -3560, x1 = -2900, z0 = 1925, z1 = 2200 }
	local APRON2 = { x0 = -3990, x1 = -3570, z0 = 1965, z1 = 2200 }
	local TERM = { x0 = -3460, x1 = -3020, z0 = 1802, z1 = 1922, h = 34 }
	local PAVED = {
		{ RWY.x0 - 10, RWY.x1 + 10, RWY.z - RWY.w / 2 - 6, RWY.z + RWY.w / 2 + 6 },
		{ TWY.x0, TWY.x1, TWY.z - TWY.w / 2, TWY.z + TWY.w / 2 },
		{ APRON.x0, APRON.x1, APRON.z0, APRON.z1 }, { APRON2.x0, APRON2.x1, APRON2.z0, APRON2.z1 },
		{ TERM.x0 - 4, TERM.x1 + 4, TERM.z0 - 4, TERM.z1 + 4 },
		{ -3290, -3190, 1290, 1800 }, { -3820, -2680, 1716, 1806 }, { -2724, -2676, 1760, 2205 },
		{ -3480, -3292, 1560, 1716 }, { -3188, -3000, 1560, 1716 },
	}
	for _, x in ipairs({ -4250, -3240, -2560 }) do table.insert(PAVED, { x - 30, x + 30, TWY.z, RWY.z }) end
	local function paved(x, z)
		for _, r in ipairs(PAVED) do if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] then return true end end
		return false
	end

	-- ===== 1. water around + new land at exactly G =====
	for x = -4900, -1900, 400 do
		for z = 1500, 3000, 400 do T:FillBlock(CFrame.new(x + 200, WL - 6, z + 200), Vector3.new(400, 12, 400), M.Water) end
		task.wait()
	end
	local CH = 256
	for x0 = LX0, LX1 - 1, CH do
		for z0 = LZ0, LZ1 - 1, CH do
			local reg = Region3.new(Vector3.new(x0, -16, z0), Vector3.new(math.min(x0 + CH, LX1), 8, math.min(z0 + CH, LZ1))):ExpandToGrid(4)
			local sz = reg.Size / 4
			local base = reg.CFrame.Position - reg.Size / 2
			local mats, occ = {}, {}
			for ix = 1, sz.X do
				mats[ix], occ[ix] = {}, {}
				local x = base.X + (ix - 0.5) * 4
				for iy = 1, sz.Y do
					mats[ix][iy], occ[ix][iy] = {}, {}
					local yb = base.Y + (iy - 1) * 4
					local o = math.clamp((G - 2 - yb) / 4, 0, 1)
					for iz = 1, sz.Z do
						local z = base.Z + (iz - 0.5) * 4
						local edge = math.min(x - LX0, LX1 - x, z - LZ0, LZ1 - z)
						local oo = o
						if edge < 24 and z > 1640 then oo = o * math.clamp(edge / 24, 0, 1) end -- soft shoreline
						local mt = (yb >= -4) and ((paved(x, z) and M.Ground) or M.LeafyGrass) or M.Ground
						if edge < 30 and z > 1640 and yb >= -4 then mt = M.Sand end
						if oo > 0 then
							mats[ix][iy][iz], occ[ix][iy][iz] = mt, oo
						elseif yb + 2 < WL then
							mats[ix][iy][iz], occ[ix][iy][iz] = M.Water, 1
						else
							mats[ix][iy][iz], occ[ix][iy][iz] = M.Air, 0
						end
					end
				end
			end
			T:WriteVoxels(reg, 4, mats, occ)
			task.wait()
		end
	end

	-- ===== 1b. clear county lots / trees in the Airport Rd corridor and on the new land =====
	local cleared = 0
	local function inZone(p)
		return (p.X > -3290 and p.X < -3190 and p.Z > 1296 and p.Z < 1600) or (p.X > LX0 and p.X < LX1 and p.Z > 1560 and p.Z < LZ1)
	end
	for _, fname in ipairs({ "Buildings", "Landmarks" }) do
		local f = VB:FindFirstChild(fname)
		local cf2 = f and f:FindFirstChild("County")
		if cf2 then
			for _, m in ipairs(cf2:GetChildren()) do
				if m:IsA("Model") then
					local bc, bs = m:GetBoundingBox()
					local hit = false
					for _, dx in ipairs({ -0.5, 0, 0.5 }) do
						for _, dz in ipairs({ -0.5, 0, 0.5 }) do
							if inZone(bc.Position + Vector3.new(bs.X * dx, 0, bs.Z * dz)) then hit = true end
						end
					end
					if hit then m:Destroy() cleared += 1 end
				end
			end
		end
	end
	local VEG = { Tree = true, Palm = true, Bush = true, Plant = true, ["Oak Tree"] = true }
	for _, m in ipairs(VB:GetDescendants()) do
		if m:IsA("Model") and VEG[m.Name] and m.Parent and not m:IsDescendantOf(AP) and inZone(m:GetPivot().Position) then m:Destroy() cleared += 1 end
	end
	-- the north sidewalk of Soria St crosses the new road: cut it
	pcall(function() L.cutSidewalk(CFrame.new(-3240, G + 0.5, 1312), Vector3.new(60, 3, 16), "CountyRoads") end)

	-- ===== 2. landside roads (own street graph) =====
	local S = L.STY
	local lines = {}
	local function ln(style, p, o)
		o = o or {}
		table.insert(lines, { style = S[style], pts = p, name = o.name, cul = o.cul })
	end
	ln("HABA", { { -3240, 1290 }, { -3240, 1500 } }, { name = "Airport Rd" })
	ln("BLVD", { { -3240, 1500 }, { -3240, 1760 } }, { name = "Airport Blvd" })
	ln("HABA", { { -3480, 1760 }, { -3240, 1760 }, { -3000, 1760 } }, { name = "Terminal Dr" })
	ln("RES", { { -3800, 1760 }, { -3480, 1760 } }, { name = "Hangar Rd" })
	ln("RES", { { -3000, 1760 }, { -2700, 1760 } }, { name = "Cargo Rd" })
	ln("RES", { { -2700, 1760 }, { -2700, 2192 } }, { name = "Airfield Service Rd" })
	local net = L.net(lines)
	L.buildRoads(AP, net, "Roads")

	local LM = L.model(AP, "Landside")
	local AS = L.model(AP, "Airside")

	-- ===== 3. airside paving + markings =====
	local WHITE, YEL = C(236, 236, 230), C(232, 186, 40)
	local function slab(par, x0, x1, z0, z1, col, mat, var, name)
		local p = L.P(par, Vector3.new(x1 - x0, 0.6, z1 - z0), CFrame.new((x0 + x1) / 2, TOP - 0.3, (z0 + z1) / 2), col, mat, var)
		p.Name = name or "Asphalt"
		p.CastShadow = false
		return p
	end
	local function mark(par, cx, cz, sx, sz, col, yaw)
		return L.D(par, Vector3.new(sx, 0.04, sz), CFrame.new(cx, TOP + 0.02, cz) * CFrame.Angles(0, yaw or 0, 0), col, M.SmoothPlastic, nil, { Transparency = 0.06 })
	end
	local function light(par, x, z, col)
		L.D(par, Vector3.new(0.7, 0.9, 0.7), CFrame.new(x, TOP + 0.45, z), col, M.Neon)
	end
	-- runway
	local rw = L.model(AS, "Runway")
	slab(rw, RWY.x0, RWY.x1, RWY.z - RWY.w / 2, RWY.z + RWY.w / 2, C(74, 76, 80), M.Asphalt, "DowntownAsphaltClean", "Runway")
	for _, sd in ipairs({ -1, 1 }) do
		slab(rw, RWY.x0, RWY.x1, sd > 0 and (RWY.z + RWY.w / 2) or (RWY.z - RWY.w / 2 - 6), sd > 0 and (RWY.z + RWY.w / 2 + 6) or (RWY.z - RWY.w / 2), C(128, 126, 120), M.Concrete, nil, "Shoulder")
		mark(rw, (RWY.x0 + RWY.x1) / 2, RWY.z + sd * (RWY.w / 2 - 2), RWY.x1 - RWY.x0 - 4, 1.4, WHITE)
	end
	for x = RWY.x0 + 220, RWY.x1 - 220, 50 do mark(rw, x, RWY.z, 26, 1.2, WHITE) end
	for _, e in ipairs({ { RWY.x0, 1, "09" }, { RWY.x1, -1, "27" } }) do
		local ex, dir = e[1], e[2]
		-- threshold piano keys
		for k = -4, 4 do
			if k ~= 0 then mark(rw, ex + dir * 24, RWY.z + k * 11, 34, 4, WHITE) end
		end
		-- designator
		local pos = Vector3.new(ex + dir * 78, TOP + 0.02, RWY.z)
		L.roadText(rw, CFrame.lookAt(pos, pos + Vector3.new(dir, 0, 0)), e[3], 30, 40)
		-- aiming point + touchdown zone bars
		for _, sd in ipairs({ -1, 1 }) do
			mark(rw, ex + dir * 330, RWY.z + sd * 18, 60, 9, WHITE)
			for _, dd in ipairs({ 190, 470 }) do
				for j = 0, 1 do mark(rw, ex + dir * dd, RWY.z + sd * (14 + j * 7), 26, 3.4, WHITE) end
			end
		end
		-- threshold lights (green) across the end
		for k = -5, 5 do light(rw, ex + dir * 2, RWY.z + k * 10, C(60, 255, 120)) end
	end
	for x = RWY.x0 + 40, RWY.x1 - 40, 80 do
		for _, sd in ipairs({ -1, 1 }) do light(rw, x, RWY.z + sd * (RWY.w / 2 + 1.5), C(255, 240, 200)) end
	end
	-- taxiway + connectors
	local tw = L.model(AS, "Taxiway")
	slab(tw, TWY.x0, TWY.x1, TWY.z - TWY.w / 2, TWY.z + TWY.w / 2, C(80, 82, 86), M.Asphalt, "DowntownAsphaltClean", "Taxiway")
	mark(tw, (TWY.x0 + TWY.x1) / 2, TWY.z, TWY.x1 - TWY.x0 - 10, 0.9, YEL)
	for _, x in ipairs({ -4250, -3240, -2560 }) do
		slab(tw, x - 25, x + 25, TWY.z + TWY.w / 2, RWY.z - RWY.w / 2, C(80, 82, 86), M.Asphalt, "DowntownAsphaltClean", "Taxiway")
		mark(tw, x, (TWY.z + RWY.z) / 2, 0.9, RWY.z - TWY.z - 6, YEL)
		-- hold-short line (2 solid + 2 dashed)
		local hz = RWY.z - RWY.w / 2 - 12
		mark(tw, x, hz, 48, 0.7, YEL)
		mark(tw, x, hz - 1.6, 48, 0.7, YEL)
		for k = -2, 2 do mark(tw, x + k * 10, hz - 4, 5, 0.7, YEL) mark(tw, x + k * 10, hz - 5.6, 5, 0.7, YEL) end
		-- taxiway sign (yellow on black)
		local sp = Vector3.new(x + 30, TOP, hz - 6)
		local sg = L.D(tw, Vector3.new(8, 2.4, 0.6), CFrame.lookAt(sp + Vector3.new(0, 1.8, 0), sp + Vector3.new(0, 1.8, -10)), C(20, 20, 22), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "09-27", { font = Enum.Font.GothamBlack, color = YEL, pps = 20, dist = 220, light = 0.4 })
	end
	for x = TWY.x0 + 30, TWY.x1 - 30, 110 do
		for _, sd in ipairs({ -1, 1 }) do light(tw, x, TWY.z + sd * (TWY.w / 2 + 1), C(60, 120, 255)) end
	end

	-- aprons with stand markings
	local ap = L.model(AS, "Apron")
	slab(ap, APRON.x0, APRON.x1, APRON.z0, APRON.z1, C(178, 178, 172), M.Concrete, nil, "Apron")
	slab(ap, APRON2.x0, APRON2.x1, APRON2.z0, APRON2.z1, C(176, 176, 170), M.Concrete, nil, "Apron")
	-- concrete panel joints
	for x = APRON.x0 + 40, APRON.x1 - 1, 40 do mark(ap, x, (APRON.z0 + APRON.z1) / 2, 0.3, APRON.z1 - APRON.z0, C(120, 120, 116)) end
	for z = APRON.z0 + 40, APRON.z1 - 1, 40 do mark(ap, (APRON.x0 + APRON.x1) / 2, z, APRON.x1 - APRON.x0, 0.3, C(120, 120, 116)) end
	-- apron taxilane
	mark(ap, (APRON.x0 + APRON.x1) / 2, 2170, APRON.x1 - APRON.x0 - 10, 0.9, YEL)
	mark(ap, -3240, 2196, 0.9, 30, YEL)
	local GATES = { -3380, -3240, -3100 }
	for i, gx in ipairs(GATES) do
		mark(ap, gx, 2045, 0.9, 250, YEL)          -- lead-in line
		mark(ap, gx, 1952, 14, 1.2, YEL)           -- stop bar
		mark(ap, gx - 32, 2020, 0.6, 150, C(200, 40, 40)) -- equipment limit lines
		mark(ap, gx + 32, 2020, 0.6, 150, C(200, 40, 40))
		local tp = Vector3.new(gx + 14, TOP + 0.02, 1990)
		L.roadText(ap, CFrame.lookAt(tp, tp + Vector3.new(0, 0, -1)), "GATE " .. i, 14, 5)
	end

	-- ===== 4. aircraft (low poly) =====
	-- cf at ground under the plane's centre, -Z = nose. s = scale (1 = narrow-body airliner, ~0.35 bizjet)
	local function hcyl(par, len, dia, cf, col, mat)
		local p = L.P(par, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, math.pi / 2, 0), col, mat)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- real aircraft models (ServerStorage.VBPlanes: Airliner = widebody template, BizJet = mesh bizjet, both nose -Z,
	-- pivot = ground centre, scripts stripped). Falls back to the part-built low-poly aircraft below.
	local PL = game.ServerStorage:FindFirstChild("VBPlanes")
	local function fromTemplate(par, cf, o)
		local big = (o.s or 1) > 0.6
		local t = PL and PL:FindFirstChild(big and "Airliner" or "BizJet")
		if not t then return nil end
		local m = t:Clone()
		local sc = big and 1.12 or 1
		if sc ~= 1 then m:ScaleTo(sc) end
		m:PivotTo(cf * CFrame.new(0, big and 0 or 2.6, 0))
		local rc = m.PrimaryPart.CFrame
		if big then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					local rel = rc:PointToObjectSpace(d.Position)
					if rel.Y > 17 * sc and rel.Z > 30 * sc then d.Color = o.tail or d.Color d.Material = M.SmoothPlastic end
				end
			end
		else
			for _, g in ipairs({ { 0, -26 }, { -4.5, 4 }, { 4.5, 4 } }) do
				L.D(m, Vector3.new(0.5, 2.8, 0.5), rc * CFrame.new(g[1], 1.6, g[2]), C(200, 200, 200), M.Metal)
				local w = L.P(m, Vector3.new(1, 1.9, 1.9), rc * CFrame.new(g[1], 0.95, g[2]), C(26, 26, 26), M.Rubber)
				w.Shape = Enum.PartType.Cylinder
			end
		end
		m.Name = o.name or t.Name
		m.Parent = par
		L.lod(m)
		return m
	end
	function L.aircraft(par, cf, o)
		o = o or {}
		local real = fromTemplate(par, cf, o)
		if real then return real end
		local s = o.s or 1
		local m = L.model(par, o.name or "Aircraft")
		local body, tail = o.body or C(244, 244, 242), o.tail or C(18, 120, 170)
		local fy = 11 * s
		local fl = 96 * s
		local fd = 12 * s
		local function P(...) local p = L.P(m, ...) return p end
		hcyl(m, fl, fd, cf * CFrame.new(0, fy, 0), body, M.SmoothPlastic)
		L.Ball(m, fd, cf * CFrame.new(0, fy - 0.4 * s, -fl / 2), body, M.SmoothPlastic)
		hcyl(m, 16 * s, fd * 0.8, cf * CFrame.new(0, fy + 1.2 * s, fl / 2 + 6 * s), body, M.SmoothPlastic)
		L.Ball(m, fd * 0.62, cf * CFrame.new(0, fy + 2.2 * s, fl / 2 + 14 * s), body, M.SmoothPlastic)
		-- cockpit glass, window bands, cheatline, belly
		L.D(m, Vector3.new(fd * 0.6, 1.2 * s, 2.4 * s), cf * CFrame.new(0, fy + fd * 0.33, -fl / 2 - 2.6 * s) * CFrame.Angles(math.rad(-30), 0, 0), C(26, 30, 36), M.Glass)
		for _, sd in ipairs({ -1, 1 }) do
			L.D(m, Vector3.new(0.12, 0.7 * s, fl * 0.84), cf * CFrame.new(sd * fd * 0.47, fy + 1.6 * s, 2 * s), C(30, 34, 40), M.SmoothPlastic)
			L.D(m, Vector3.new(0.12, 1 * s, fl * 0.95), cf * CFrame.new(sd * fd * 0.48, fy - 0.6 * s, 0), tail, M.SmoothPlastic)
			if o.name and s > 0.6 then
				local nm = L.D(m, Vector3.new(0.1, 2.4 * s, 26 * s), cf * CFrame.new(sd * fd * 0.5, fy + 3.4 * s, -fl * 0.2), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
				L.text(nm, sd > 0 and Enum.NormalId.Right or Enum.NormalId.Left, o.livery or "SOL AIR", { font = Enum.Font.GothamBlack, color = tail, pps = 10, dist = 500, light = 1 })
			end
		end
		-- wings (swept, slight dihedral) + winglets
		local sweep = 0.42
		for _, sd in ipairs({ -1, 1 }) do
			local span = 52 * s
			local root = Vector3.new(sd * fd * 0.4, fy - fd * 0.3, 2 * s)
			local c = cf * CFrame.new(root) * CFrame.Angles(0, -sd * sweep, 0) * CFrame.new(sd * span / 2, 0, 0) * CFrame.Angles(0, 0, sd * 0.07)
			P(Vector3.new(span, 1.1 * s, 13 * s), c, body, M.SmoothPlastic)
			L.D(m, Vector3.new(1 * s, 5 * s, 6 * s), c * CFrame.new(sd * span / 2, 2.4 * s, 2 * s), tail, M.SmoothPlastic)
			-- engine under the wing
			if s > 0.6 then
				local ec = cf * CFrame.new(sd * 17 * s, fy - fd * 0.6, -4 * s)
				hcyl(m, 13 * s, 6.4 * s, ec, C(220, 220, 222), M.Metal)
				hcyl(m, 0.3, 5.2 * s, ec * CFrame.new(0, 0, -6.6 * s), C(30, 30, 34), M.Metal)
			else
				hcyl(m, 6 * s * 2.2, 3.6 * s * 2, cf * CFrame.new(sd * fd * 0.75, fy + 1.5 * s, fl * 0.32), C(220, 220, 222), M.Metal)
			end
			-- tailplane
			L.P(m, Vector3.new(18 * s, 0.8 * s, 8 * s), cf * CFrame.new(0, fy + (s > 0.6 and 1.6 or 7) * s, fl / 2 + 10 * s) * CFrame.Angles(0, -sd * 0.5, 0) * CFrame.new(sd * 9 * s, 0, 0), body, M.SmoothPlastic)
		end
		-- fin with the logo
		local fin = L.W(m, Vector3.new(1.2 * s, 20 * s, 20 * s), cf * CFrame.new(0, fy + fd * 0.4 + 10 * s, fl / 2 + 8 * s), tail, M.SmoothPlastic)
		L.text(fin, Enum.NormalId.Right, o.logo or "☀", { font = Enum.Font.GothamBlack, color = C(255, 214, 90), size = UDim2.fromScale(0.5, 0.4), pos = UDim2.fromScale(0.45, 0.45), pps = 6, dist = 500, light = 1 })
		L.text(fin, Enum.NormalId.Left, o.logo or "☀", { font = Enum.Font.GothamBlack, color = C(255, 214, 90), size = UDim2.fromScale(0.5, 0.4), pos = UDim2.fromScale(0.05, 0.45), pps = 6, dist = 500, light = 1 })
		-- landing gear
		local function gear(x, z, n)
			L.D(m, Vector3.new(0.7 * s, fy - fd / 2, 0.7 * s), cf * CFrame.new(x, (fy - fd / 2) / 2 + 1.2 * s, z), C(200, 200, 200), M.Metal)
			local w = L.P(m, Vector3.new(n * 1.4 * s, 2.6 * s, 2.6 * s), cf * CFrame.new(x, 1.3 * s, z), C(26, 26, 26), M.Rubber)
			w.Shape = Enum.PartType.Cylinder
		end
		gear(0, -fl / 2 + 8 * s, 1)
		gear(-5 * s, 6 * s, 2)
		gear(5 * s, 6 * s, 2)
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CastShadow = d.Size.Magnitude > 20 end end
		L.lod(m)
		return m
	end
	local LIV = {
		{ "SOL AIR", C(18, 120, 170), "☀" }, { "CORAL AIRWAYS", C(222, 92, 70), "✦" }, { "BAYJET", C(30, 40, 110), "B" }, { "TROPIC", C(30, 140, 90), "✿" },
	}
	for i, gx in ipairs(GATES) do
		local lv = LIV[i]
		L.aircraft(AS, CFrame.new(gx, TOP, 2008) * CFrame.Angles(0, 0, 0), { name = "Airliner", livery = lv[1], tail = lv[2], logo = lv[3] })
	end
	L.aircraft(AS, CFrame.new(-3720, TOP, TWY.z) * CFrame.Angles(0, -math.pi / 2, 0), { name = "Airliner", livery = LIV[4][1], tail = LIV[4][2], logo = LIV[4][3] })
	L.aircraft(AS, CFrame.new(-3925, TOP, 2125) * CFrame.Angles(0, math.rad(200), 0), { name = "BizJet", s = 0.36, tail = C(30, 30, 34), logo = "V" })
	L.aircraft(AS, CFrame.new(-3800, TOP, 2125) * CFrame.Angles(0, math.rad(160), 0), { name = "BizJet", s = 0.36, tail = C(150, 120, 60), logo = "V" })

	-- ===== 5. terminal (walk-in hall) =====
	local TM = L.model(LM, "Terminal")
	local tw0, tw1, tz0, tz1, TH = TERM.x0, TERM.x1, TERM.z0, TERM.z1, TERM.h
	local tcx, tcz, TW, TD = (tw0 + tw1) / 2, (tz0 + tz1) / 2, tw1 - tw0, tz1 - tz0
	local FL = G + 0.9
	local stone = C(232, 228, 218)
	local glassC = C(110, 140, 158)
	L.P(TM, Vector3.new(TW, 1, TD), CFrame.new(tcx, FL - 0.5, tcz), C(226, 222, 214), M.Marble, "LobbyMarble")
	-- side + airside walls
	for _, sd in ipairs({ -1, 1 }) do L.P(TM, Vector3.new(2, TH, TD), CFrame.new(tcx + sd * (TW / 2 - 1), FL + TH / 2, tcz), stone, M.Concrete) end
	L.P(TM, Vector3.new(TW, 9, 2), CFrame.new(tcx, FL + 4.5, tz1 - 1), stone, M.Concrete)
	local ag = L.P(TM, Vector3.new(TW, TH - 9, 1), CFrame.new(tcx, FL + 9 + (TH - 9) / 2, tz1 - 1), glassC, M.Glass, nil, { Transparency = 0.45, Reflectance = 0.15 })
	L.windowGrid(ag, Enum.NormalId.Back, { col = 9, row = TH - 9, mull = C(220, 222, 224), spandrel = C(200, 204, 206) })
	-- landside glass front with three entrances (16 wide x 10 high) and glass transoms
	local DOORS = { tcx - 130, tcx, tcx + 130 }
	local x = tw0
	for _, dx in ipairs(DOORS) do
		local w = (dx - 8) - x
		local p = L.P(TM, Vector3.new(w, TH, 1), CFrame.new(x + w / 2, FL + TH / 2, tz0 + 0.5), glassC, M.Glass, nil, { Transparency = 0.45, Reflectance = 0.15 })
		L.windowGrid(p, Enum.NormalId.Front, { col = 8, row = TH / 2, mull = C(220, 222, 224), spandrel = C(200, 204, 206) })
		L.P(TM, Vector3.new(16, TH - 10, 1), CFrame.new(dx, FL + 10 + (TH - 10) / 2, tz0 + 0.5), glassC, M.Glass, nil, { Transparency = 0.45, Reflectance = 0.15 })
		L.D(TM, Vector3.new(16.6, 0.6, 1.4), CFrame.new(dx, FL + 10, tz0 + 0.5), C(200, 202, 206), M.Metal)
		x = dx + 8
	end
	do
		local w = tw1 - x
		local p = L.P(TM, Vector3.new(w, TH, 1), CFrame.new(x + w / 2, FL + TH / 2, tz0 + 0.5), glassC, M.Glass, nil, { Transparency = 0.45, Reflectance = 0.15 })
		L.windowGrid(p, Enum.NormalId.Front, { col = 8, row = TH / 2, mull = C(220, 222, 224), spandrel = C(200, 204, 206) })
	end
	-- wave roof: main slab overhanging the curb as a canopy, raised clerestory, fascia lettering
	local roofY = FL + TH
	L.P(TM, Vector3.new(TW + 24, 2.4, TD + 46), CFrame.new(tcx, roofY + 1.2, tcz - 17), C(236, 236, 232), M.SmoothPlastic)
	L.D(TM, Vector3.new(TW + 23, 0.2, TD + 45), CFrame.new(tcx, roofY - 0.05, tcz - 17), C(196, 176, 140), M.WoodPlanks)
	local fas = L.P(TM, Vector3.new(TW + 24, 4.4, 1), CFrame.new(tcx, roofY + 0.4, tz0 - 40), C(244, 244, 240), M.SmoothPlastic)
	L.text(fas, Enum.NormalId.Front, "VICE BAY INTERNATIONAL AIRPORT", { font = Enum.Font.GothamBold, color = C(24, 60, 110), size = UDim2.fromScale(0.5, 0.7), pos = UDim2.fromScale(0.25, 0.15), pps = 8, dist = 900, light = 0.6 })
	local cl = L.P(TM, Vector3.new(TW * 0.62, 9, TD * 0.5), CFrame.new(tcx, roofY + 2.4 + 4.5, tcz + 6), glassC, M.Glass, nil, { Transparency = 0.3, Reflectance = 0.2 })
	L.windowGrid(cl, Enum.NormalId.Front, { col = 6, row = 9 })
	L.windowGrid(cl, Enum.NormalId.Back, { col = 6, row = 9 })
	L.P(TM, Vector3.new(TW * 0.66, 1.6, TD * 0.56), CFrame.new(tcx, roofY + 2.4 + 9.8, tcz + 6), C(236, 236, 232), M.SmoothPlastic)
	for k = -1, 1, 2 do L.B(TM, CFrame.new(tcx + k * TW * 0.4, roofY + 2.4, tcz + 30), 0, 0, 0, 10, 4, 8, C(196, 198, 200), M.Metal) end
	-- tree columns along the curb (canopy supports)
	for k = 0, 5 do
		local cx = tw0 + 30 + k * (TW - 60) / 5
		local base = Vector3.new(cx, G + 0.9, tz0 - 7)
		L.Cyl(TM, TH - 6, 2.2, CFrame.new(base + Vector3.new(0, (TH - 6) / 2, 0)), C(236, 236, 232), M.Metal)
		for _, sd in ipairs({ -1, 1 }) do
			L.bar(TM, base + Vector3.new(0, TH - 6, 0), base + Vector3.new(sd * 9, TH + 0.6, 4), 1.1, C(236, 236, 232), M.Metal)
		end
	end
	-- DEPARTURES signs over each entrance, drop-off curb markings
	for _, dx in ipairs(DOORS) do
		local sg = L.D(TM, Vector3.new(22, 3.2, 0.6), CFrame.new(dx, FL + 13.6, tz0 - 6), C(22, 44, 92), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "✈  DEPARTURES", { font = Enum.Font.GothamBold, color = C(255, 255, 255), pps = 16, dist = 400, light = 0.2, bright = 1.3 })
		L.D(TM, Vector3.new(22, 0.4, 0.4), CFrame.new(dx, FL + 15.4, tz0 - 3), C(120, 122, 126), M.Metal)
	end
	-- interior: check-in islands, boards, security, seating, planters, ceiling lights
	local IN = L.model(TM, "Interior")
	local AIRL = { "SOL AIR", "CORAL AIRWAYS", "BAYJET", "TROPIC" }
	for i = 1, 4 do
		local ix = tw0 + 50 + (i - 1) * (TW - 100) / 3
		local c = CFrame.new(ix, FL, tcz - 10)
		L.B(IN, c, 0, 0, 0, 44, 3.6, 3.6, C(70, 74, 80), M.SmoothPlastic)
		L.BD(IN, c, 0, 3.6, 0, 44.4, 0.2, 4, C(230, 230, 226), M.Marble)
		L.B(IN, c, 0, 0, 4.4, 44, 1.4, 3.4, C(40, 42, 46), M.Rubber)
		local brd = L.BD(IN, c, 0, 9, 6.8, 40, 4, 0.6, C(22, 44, 92), M.SmoothPlastic)
		L.text(brd, Enum.NormalId.Front, "CHECK-IN " .. string.char(64 + i) .. "   ·   " .. AIRL[i], { font = Enum.Font.GothamBold, color = C(255, 214, 90), pps = 16, dist = 160, light = 0, bright = 1.3 })
	end
	for _, bx in ipairs({ tcx - 60, tcx + 60 }) do
		local b = L.D(IN, Vector3.new(30, 13, 0.6), CFrame.new(bx, FL + 16, tz1 - 3), C(8, 10, 14), M.SmoothPlastic)
		L.text(b, Enum.NormalId.Front, "DEPARTURES\nSA 101   PORT SOL      08:40  ON TIME\nCA 220   NASSAU        09:15  BOARDING\nBJ 512   NEW YORK      09:50  ON TIME\nTR 031   KINGSTON      10:25  DELAYED\nSA 145   CANCUN        11:05  ON TIME\nCA 618   BOGOTA        11:40  ON TIME", { font = Enum.Font.Code, color = C(255, 214, 90), pps = 18, dist = 140, light = 0, bright = 1.4 })
	end
	for k = -1, 1 do
		local c = CFrame.new(tcx + k * 26, FL, tz1 - 26)
		for _, sd in ipairs({ -1, 1 }) do L.B(IN, c, sd * 2.6, 0, 0, 0.8, 7.4, 3.6, C(200, 202, 206), M.Metal) end
		L.B(IN, c, 0, 7.4, 0, 6, 0.8, 3.6, C(200, 202, 206), M.Metal)
		L.B(IN, c, 8, 0, 0, 10, 3, 3, C(40, 42, 46), M.Rubber)
	end
	for r = 0, 2 do
		for _, sd in ipairs({ -1, 1 }) do
			local c = CFrame.new(tcx + sd * 150, FL, tz1 - 34 + r * 9)
			L.B(IN, c, 0, 1.6, 0, 26, 0.8, 2.8, C(40, 90, 140), M.SmoothPlastic)
			L.B(IN, c, 0, 2.4, 1.3, 26, 2.4, 0.4, C(40, 90, 140), M.SmoothPlastic)
			L.BD(IN, c, 0, 0, 0, 25, 1.6, 0.4, C(160, 162, 166), M.Metal)
		end
	end
	for _, sd in ipairs({ -1, 1 }) do
		local pc = Vector3.new(tcx + sd * 70, FL, tcz + 6)
		L.B(IN, CFrame.new(pc), 0, 0, 0, 8, 2.6, 8, C(214, 208, 196), M.Concrete)
		L.palm(IN, pc + Vector3.new(0, 2.6, 0), 24, "royal")
	end
	for k = 0, 4 do
		local lx = tw0 + 44 + k * (TW - 88) / 4
		L.BD(IN, CFrame.new(lx, FL, tcz), 0, TH - 1.4, 0, 3, 0.3, TD - 30, C(250, 248, 240), M.Neon)
	end
	for _, lx in ipairs({ tcx - 120, tcx, tcx + 120 }) do
		local a = L.D(IN, Vector3.new(0.2, 0.2, 0.2), CFrame.new(lx, FL + TH - 3, tcz), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Brightness = 0.8
		pl.Shadows = false
		pl.Parent = a
	end
	-- jet bridges to the three gates
	for _, gx in ipairs(GATES) do
		local a = Vector3.new(gx + 8, FL + 11, tz1)
		local b = Vector3.new(gx + 10, FL + 11, 1972)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		L.P(TM, Vector3.new(8, 8, len), cf, C(206, 208, 210), M.Metal)
		L.D(TM, Vector3.new(8.2, 1.2, len), cf * CFrame.new(0, 3, 0), C(60, 62, 66), M.Metal)
		L.Cyl(TM, 9, 9, CFrame.new(b + Vector3.new(0, 0.5, 0)), C(206, 208, 210), M.Metal)
		L.Cyl(TM, FL + 7 - G, 1.4, CFrame.new(Vector3.new(b.X, (G + FL + 7) / 2, b.Z - 4)), C(140, 142, 146), M.Metal)
	end
	L.lod(TM)

	-- ===== 6. control tower, hangars, cargo, monument, windsock =====
	do
		local tc = Vector3.new(-2966, G, 1872)
		local tm = L.model(LM, "ControlTower")
		L.B(tm, CFrame.new(tc), 0, 0, 0, 30, 14, 30, stone, M.Concrete)
		L.Cyl(tm, 84, 11, CFrame.new(tc + Vector3.new(0, 14 + 42, 0)), C(236, 236, 232), M.Concrete)
		L.Cyl(tm, 3, 24, CFrame.new(tc + Vector3.new(0, 99.5, 0)), C(200, 202, 206), M.Metal)
		L.Cyl(tm, 10, 22, CFrame.new(tc + Vector3.new(0, 106, 0)), C(60, 90, 110), M.Glass, nil, { Transparency = 0.25, Reflectance = 0.3 })
		L.Cyl(tm, 2.2, 26, CFrame.new(tc + Vector3.new(0, 112, 0)), C(236, 236, 232), M.SmoothPlastic)
		L.Cyl(tm, 14, 0.6, CFrame.new(tc + Vector3.new(0, 120, 0)), C(200, 200, 200), M.Metal)
		L.D(tm, Vector3.new(1.2, 1.2, 1.2), CFrame.new(tc + Vector3.new(0, 127.6, 0)), C(255, 40, 40), M.Neon)
		local sg = L.D(tm, Vector3.new(16, 4, 0.3), CFrame.new(tc + Vector3.new(0, 9, -15.2)), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(sg, Enum.NormalId.Front, "VBI TOWER", { font = Enum.Font.GothamBold, color = C(24, 60, 110), pps = 14, dist = 300 })
		L.lod(tm)
	end
	local function hangar(cx, label)
		local hm = L.model(LM, "Hangar")
		local W, D, H = 130, 96, 30
		local c = CFrame.new(cx, G, APRON2.z0 - D / 2) * CFrame.Angles(0, math.pi, 0) -- doors (local -Z) open onto the apron
		local col = C(206, 210, 212)
		L.P(hm, Vector3.new(W, 1, D), c * CFrame.new(0, -0.25, 0), C(170, 170, 166), M.Concrete)
		L.B(hm, c, 0, 0, D / 2 - 1, W, H, 2, col, M.Metal, "CorrugatedPlain")
		for _, sd in ipairs({ -1, 1 }) do L.B(hm, c, sd * (W / 2 - 1), 0, 0, 2, H, D, col, M.Metal, "CorrugatedPlain") end
		-- barrel roof from 7 flat panels
		local R = W / 2 + 6
		local rise = 14
		for k = -3, 3 do
			local a0, a1 = (k - 0.5) / 7 * math.pi * 0.62, (k + 0.5) / 7 * math.pi * 0.62
			local p0 = Vector2.new(math.sin(a0) * W / 2 / math.sin(math.pi * 0.31), math.cos(a0))
			local p1 = Vector2.new(math.sin(a1) * W / 2 / math.sin(math.pi * 0.31), math.cos(a1))
			local y0 = H + rise * (p0.Y - math.cos(math.pi * 0.31)) / (1 - math.cos(math.pi * 0.31))
			local y1 = H + rise * (p1.Y - math.cos(math.pi * 0.31)) / (1 - math.cos(math.pi * 0.31))
			local a = Vector3.new(p0.X, y0, 0)
			local b = Vector3.new(p1.X, y1, 0)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local ang = math.atan2(b.Y - a.Y, b.X - a.X)
			L.P(hm, Vector3.new(len + 0.6, 1, D + 2), c * CFrame.new(mid.X, mid.Y, 0) * CFrame.Angles(0, 0, ang), C(176, 180, 184), M.Metal, "RoofBoxProfile")
		end
		-- front gable infill above the doors + big sliding doors pulled open
		L.B(hm, c, 0, H - 4, -D / 2 + 1, W * 0.6, rise * 0.68 + 4, 1.4, col, M.Metal, "CorrugatedPlain")
		L.B(hm, c, 0, H - 4, D / 2 - 1, W * 0.6, rise * 0.68 + 4, 1.4, col, M.Metal, "CorrugatedPlain")
		for _, sd in ipairs({ -1, 1 }) do
			for _, zz in ipairs({ -D / 2 + 1, D / 2 - 1 }) do L.B(hm, c, sd * W * 0.38, H - 4, zz, W * 0.16, rise * 0.3 + 4, 1.4, col, M.Metal, "CorrugatedPlain") end
		end
		for _, sd in ipairs({ -1, 1 }) do L.B(hm, c, sd * (W / 2 - 18), 0, -D / 2 - 1, 34, H - 4, 1.2, C(150, 160, 170), M.Metal, "CorrugatedPlain") end
		local sg = L.D(hm, Vector3.new(60, 6, 0.4), c * CFrame.new(0, H + 4, -D / 2 - 0.2), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(sg, Enum.NormalId.Front, label, { font = Enum.Font.GothamBlack, color = C(24, 60, 110), pps = 8, dist = 700, light = 0.8 })
		L.aircraft(hm, c * CFrame.new(0, 0.25, 6), { name = "BizJet", s = 0.38, tail = C(40, 40, 44), logo = "V" })
		local a = L.D(hm, Vector3.new(0.2, 0.2, 0.2), c * CFrame.new(0, H - 3, 0), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Range = 50
		pl.Brightness = 0.7
		pl.Shadows = false
		pl.Parent = a
		L.lod(hm)
	end
	hangar(-3880, "VICE BAY JET CENTER")
	hangar(-3680, "SOL AIR MAINTENANCE")
	-- cargo sheds on Cargo Rd
	L.warehouse(LM, CFrame.new(-2880, G, 1846), 110, 90, { sign = "VBI AIR CARGO", rundown = false })
	L.warehouse(LM, CFrame.new(-2772, G, 1846), 90, 90, { sign = "SUNCOAST FREIGHT AIR", rundown = false })
	-- welcome monument + palms at the Airport Blvd entrance
	do
		local ec = CFrame.new(-3306, G, 1520) * CFrame.Angles(0, math.rad(90), 0)
		local mm = L.model(LM, "AirportSign")
		L.B(mm, ec, 0, 0, 0, 30, 2, 5, C(206, 196, 178), M.Cobblestone, "StoneFieldLight")
		L.B(mm, ec, 0, 2, 0, 26, 7, 2.4, C(240, 236, 226), M.Plaster)
		local pl = L.BD(mm, ec, 0, 3, -1.25, 22, 4.4, 0.2, C(24, 60, 110), M.Metal)
		L.text(pl, Enum.NormalId.Front, "✈  VICE BAY INTERNATIONAL", { font = Enum.Font.GothamBold, color = C(250, 226, 160), light = 0.2, bright = 1.4, pps = 20, dist = 300 })
		for sd = -1, 1, 2 do L.palm(mm, (ec * CFrame.new(sd * 17, 0, 0)).Position, 32, "royal") end
	end
	do
		local wp = Vector3.new(-2560, G, RWY.z - RWY.w / 2 - 30)
		local ws = L.model(AS, "Windsock")
		L.Cyl(ws, 18, 0.5, CFrame.new(wp + Vector3.new(0, 9, 0)), C(200, 200, 200), M.Metal)
		for k = 0, 2 do
			local p = L.P(ws, Vector3.new(4, 2.6 - k * 0.6, 2.6 - k * 0.6), CFrame.new(wp + Vector3.new(2 + k * 4, 17.4 - k * 0.5, 0)), k % 2 == 0 and C(255, 110, 30) or C(250, 250, 248), M.Fabric)
			p.Shape = Enum.PartType.Cylinder
			p.CanCollide = false
		end
	end
	-- service gate to the airfield (barrier arm up: cars may use the runway)
	do
		local gp = Vector3.new(-2700, G + 0.25, 2150)
		local gm = L.model(AS, "ServiceGate")
		L.B(gm, CFrame.new(gp + Vector3.new(-22, 0, 0)), 0, 0, 0, 6, 9, 6, C(236, 236, 232), M.Concrete)
		L.D(gm, Vector3.new(0.6, 22, 0.6), CFrame.new(gp + Vector3.new(-19, 13, 0)) * CFrame.Angles(0, 0, math.rad(-12)), C(240, 60, 50), M.SmoothPlastic)
		local sg = L.D(gm, Vector3.new(14, 3.4, 0.3), CFrame.new(gp + Vector3.new(-22, 11.5, -3.2)), C(240, 200, 40), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "AIRFIELD ACCESS", { font = Enum.Font.GothamBlack, color = C(20, 20, 22), pps = 14, dist = 200 })
	end

	-- ===== 7. parking lots with palm islands =====
	local PK = L.model(LM, "Parking")
	for _, lot in ipairs({ { -3480, -3292 }, { -3188, -3000 } }) do
		local x0, x1, z0, z1 = lot[1], lot[2], 1566, 1712
		slab(PK, x0, x1, z0, z1, C(96, 98, 100), M.Asphalt, "ParkingLotAsphalt", "ParkingLot")
		for _, rz in ipairs({ 1600, 1680 }) do
			for x = x0 + 14, x1 - 14, 11 do mark(PK, x, rz, 0.5, 40, WHITE) end
			mark(PK, (x0 + x1) / 2, rz, x1 - x0 - 28, 0.5, WHITE)
			for _, ex in ipairs({ x0 + 6, x1 - 6 }) do
				L.B(PK, CFrame.new(ex, TOP, rz), 0, -0.1, 0, 8, 0.8, 40, C(200, 198, 190), M.Concrete).Name = "Median"
				L.BD(PK, CFrame.new(ex, TOP, rz), 0, 0.7, 0, 7, 0.1, 39, C(110, 82, 56), M.Ground)
				L.palm(PK, Vector3.new(ex, TOP + 0.7, rz), L.r(26, 32), "royal")
			end
			for _ = 1, 4 do
				local sx = x0 + 14 + 11 * L.ri(0, math.floor((x1 - x0 - 28) / 11) - 1) + 5.5
				local sd = L.chance(0.5) and 1 or -1
				L.car(PK, CFrame.new(sx, TOP, rz + sd * 10.2) * CFrame.Angles(0, sd > 0 and 0 or math.pi, 0))
			end
		end
		local sg = L.D(PK, Vector3.new(10, 4, 0.4), CFrame.new(x0 + 14, TOP + 9, 1716), C(22, 44, 92), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "P  " .. (x0 < -3300 and "SHORT TERM" or "LONG TERM"), { font = Enum.Font.GothamBold, color = C(255, 255, 255), pps = 16, dist = 260 })
		L.Cyl(PK, 9, 0.4, CFrame.new(x0 + 14, TOP + 4.5, 1716.4), C(120, 122, 126), M.Metal)
	end
	-- airside grass: a few palms along the landside edge only (nothing near the paving)
	for x = -4400, -2450, 130 do
		if x < TERM.x0 - 40 or x > -2650 then L.palm(LM, Vector3.new(x + L.r(-10, 10), G, 1600 + L.r(-20, 20)), L.r(28, 36)) end
	end

	-- ===== 8b. filling the open land: heliport, fire rescue, hotel, rental cars, fuel farm, approach lights =====
	-- heliport (east of the service road): three marked pads, a small lounge, two helicopters
	do
		local HP = L.model(LM, "Heliport")
		slab(HP, -2650, -2430, 1880, 2100, C(176, 176, 170), M.Concrete, nil, "Apron")
		for i, px in ipairs({ -2610, -2540, -2470 }) do
			local pc = CFrame.new(px, TOP, 1950)
			L.D(HP, Vector3.new(0.06, 40, 40), pc * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), C(70, 72, 76), M.Asphalt, nil, { Shape = Enum.PartType.Cylinder })
			L.D(HP, Vector3.new(0.07, 36, 36), pc * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), WHITE, M.SmoothPlastic, nil, { Shape = Enum.PartType.Cylinder })
			L.D(HP, Vector3.new(0.08, 33, 33), pc * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), C(70, 72, 76), M.Asphalt, nil, { Shape = Enum.PartType.Cylinder })
			L.roadText(HP, pc * CFrame.new(0, 0.07, 0), "H", 16, 20)
			for k = 0, 7 do
				local a = k * math.pi / 4
				light(HP, px + math.cos(a) * 19.5, 1950 + math.sin(a) * 19.5, C(255, 230, 120))
			end
			if i < 3 then
				local t = PL and PL:FindFirstChild("Helicopter")
				if t then
					local h = t:Clone()
					h:PivotTo(CFrame.new(px, TOP, 1950) * CFrame.Angles(0, math.rad(L.r(-30, 30)), 0))
					h.Parent = HP
				end
			end
		end
		local lc = CFrame.new(-2540, G, 2060)
		L.B(HP, lc, 0, 0, 0, 70, 12, 30, stone, M.Concrete)
		local gl = L.BD(HP, lc, 0, 1, -15.1, 64, 9, 0.3, glassC, M.Glass, nil, { Transparency = 0.3, Reflectance = 0.2 })
		L.windowGrid(gl, Enum.NormalId.Front, { col = 6, row = 9 })
		L.BD(HP, lc, 0, 12, 0, 74, 1, 34, C(236, 236, 232), M.SmoothPlastic)
		local hs = L.D(HP, Vector3.new(40, 4, 0.3), lc * CFrame.new(0, 15, -15.3), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(hs, Enum.NormalId.Front, "VBI HELIPORT", { font = Enum.Font.GothamBold, color = C(24, 60, 110), pps = 10, dist = 500 })
		L.BD(HP, CFrame.new(-2662, TOP, 1990), 0, 0, 0, 24, 0.3, 30, C(176, 176, 170), M.Concrete)
	end
	-- airport fire rescue + airport inn on the south side of Hangar Rd (fronts face the road)
	pcall(function() L.firestation(LM, CFrame.new(-3700, G, 1697) * CFrame.Angles(0, math.pi, 0), 76, 70, { sign = "VBI FIRE RESCUE" }) end)
	pcall(function() L.walkup(LM, CFrame.new(-3570, G, 1705) * CFrame.Angles(0, math.pi, 0), 78, 54, { floors = 3, rundown = false, aptName = "Airport Inn", color = C(236, 230, 214) }) end)
	-- rental car return: a lot of identical white/silver cars in rows
	do
		local RC = L.model(LM, "RentalCars")
		local x0, x1, z0, z1 = -3860, -3620, 1560, 1640
		slab(RC, x0, x1, z0, z1, C(96, 98, 100), M.Asphalt, "ParkingLotAsphalt", "ParkingLot")
		for x = x0 + 8, x1 - 8, 11 do mark(RC, x, 1600, 0.5, 40, WHITE) end
		mark(RC, (x0 + x1) / 2, 1600, x1 - x0 - 16, 0.5, WHITE)
		for k = 0, 9 do
			local cx = x0 + 13.5 + k * 22
			L.car(RC, CFrame.new(cx, TOP, 1590) * CFrame.Angles(0, math.pi, 0), L.pick({ C(236, 236, 234), C(180, 182, 186), C(40, 42, 46) }))
		end
		local sg = L.D(RC, Vector3.new(26, 5, 0.4), CFrame.new(x0 + 20, TOP + 10, z1 + 2), C(240, 196, 40), M.SmoothPlastic)
		L.text(sg, Enum.NormalId.Front, "RENTAL CAR RETURN", { font = Enum.Font.GothamBlack, color = C(20, 20, 22), pps = 12, dist = 300 })
		L.Cyl(RC, 10, 0.5, CFrame.new(x0 + 20, TOP + 5, z1 + 2.4), C(120, 122, 126), M.Metal)
	end
	-- fuel farm west of the hangars
	do
		local FF = L.model(LM, "FuelFarm")
		slab(FF, -4360, -4120, 1800, 1930, C(160, 160, 156), M.Concrete, nil, "Apron")
		for i, p in ipairs({ { -4300, 1850 }, { -4240, 1880 }, { -4180, 1850 } }) do
			L.Cyl(FF, 20, 34, CFrame.new(p[1], TOP + 10, p[2]), C(236, 236, 232), M.Metal)
			L.Cyl(FF, 1.2, 35, CFrame.new(p[1], TOP + 19.6, p[2]), C(200, 202, 206), M.Metal)
			L.D(FF, Vector3.new(0.3, 3, 30), CFrame.new(p[1] - 17.1, TOP + 12, p[2]), C(220, 60, 50), M.SmoothPlastic)
		end
		L.fence(FF, Vector3.new(-4360, TOP, 1800), Vector3.new(-4120, TOP, 1800), 8, "chain")
		local fs = L.D(FF, Vector3.new(30, 4, 0.3), CFrame.new(-4240, TOP + 24, 1880), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(fs, Enum.NormalId.Front, "JET A-1", { font = Enum.Font.GothamBlack, color = C(200, 40, 40), pps = 10, dist = 500 })
	end
	-- approach light bars beyond both runway ends (on land)
	for _, e in ipairs({ { RWY.x0, -1 }, { RWY.x1, 1 } }) do
		for k = 1, 6 do
			local x = e[1] + e[2] * k * 18
			if x > LX0 + 10 and x < LX1 - 10 then
				for j = -2, 2 do light(rw, x, RWY.z + j * 4, C(255, 244, 214)) end
			end
		end
	end
	-- shade trees on the landside grass
	for _ = 1, 22 do
		local x, z = L.r(-4440, -3900), L.r(1580, 1700)
		if not paved(x, z) and not (x > -3880 and x < -3600) then L.tree(LM, Vector3.new(x, G, z), L.r(0.8, 1.2)) end
	end

	-- ===== 8. POIs =====
	L.CAT.Airport = L.CAT.Airport or { tag = "Airport", color = C(120, 190, 255), glyph = "✈", prompt = "Check In" }
	pcall(function()
		L.poi(Vector3.new(tcx, G, tz0 - 10), "Airport", "Vice Bay International", { Note = "Flights, arrivals and the airfield" })
		L.poi(Vector3.new(-3240, G, 1960), "Job", "VBI Ramp Agent", { Job = "Ramp Agent", Pay = 70 })
		L.poi(Vector3.new(-2600, G, RWY.z), "Park", "VBI Runway", { Note = "Open runway - full speed strip" }, { noPrompt = true })
		L.poi(Vector3.new(-2540, G, 1950), "Helipad", "VBI Heliport", {}, { iconDist = 900 })
	end)

	-- keep the county filler / tidy passes aware of the new district
	if L.FILL_BLOCKERS and not table.find(L.FILL_BLOCKERS, "Airport") then table.insert(L.FILL_BLOCKERS, "Airport") end
	local parts = 0
	for _, d in ipairs(AP:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("VBI airport: parts %d (%.1fs)", parts, os.clock() - t0)
end
