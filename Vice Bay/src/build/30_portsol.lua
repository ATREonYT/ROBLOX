-- 30 Port Sol: the Sol Expressway (3 lanes each way, divided, lit) from the north end of I-95 across the bay on
-- a long high bridge, then sweeping curves through open country to Port Sol, a small Florida coastal town with
-- its own parkway, main street, waterfront drive and a residential pocket. Built light: long road segments,
-- sparse cheap vegetation, ~110 lots. Everything streams in only when you are out there.
return function(L)
	local M, C = L.M, L.C
	local G, W = L.G, L.WATER
	local T = workspace.Terrain
	local VB = workspace.ViceBay
	for _, n in ipairs({ "Expressway", "PortSol" }) do local f = VB:FindFirstChild(n) if f then f:Destroy() end end
	local BP = VB.Buildings:FindFirstChild("PortSol")
	if BP then BP:Destroy() end
	local LMp = VB.Landmarks:FindFirstChild("PortSol")
	if LMp then LMp:Destroy() end
	local EX = L.folder(VB, "Expressway")
	L.seed(3030)
	local t0 = os.clock()

	-- ===== 1. water + new land =====
	for x = -2400, 1400, 400 do
		for z = -1700, -5000, -400 do
			T:FillBlock(CFrame.new(x + 200, -8, z - 200), Vector3.new(400, 8, 400), M.Water)
		end
		task.wait()
	end
	local LX0, LX1, LZ0, LZ1 = -1500, 600, -2650, -4750
	for x = LX0 - 48, LX1 + 48, 128 do
		for z = LZ0 + 48, LZ1 - 48, -128 do
			T:FillBlock(CFrame.new(x + 64, -10, z - 64), Vector3.new(128, 16, 128), M.Sand)
		end
		task.wait()
	end
	-- land surface exactly at G (same voxel convention as the mainland: occ = clamp((H - 2 - yb) / 4, 0, 1))
	local CH = 256
	for x0 = LX0, LX1 - 1, CH do
		for z1 = LZ0, LZ1 + 1, -CH do
			local reg = Region3.new(Vector3.new(x0, -16, z1 - CH), Vector3.new(x0 + CH, 8, z1)):ExpandToGrid(4)
			local sz = reg.Size / 4
			local mats, occ = {}, {}
			for ix = 1, sz.X do
				mats[ix], occ[ix] = {}, {}
				for iy = 1, sz.Y do
					mats[ix][iy], occ[ix][iy] = {}, {}
					local yb = reg.CFrame.Position.Y - reg.Size.Y / 2 + (iy - 1) * 4
					local o = math.clamp((G - 2 - yb) / 4, 0, 1)
					local mt = (yb >= -4) and M.LeafyGrass or M.Ground
					for iz = 1, sz.Z do
						mats[ix][iy][iz] = (o > 0) and mt or M.Air
						occ[ix][iy][iz] = o
					end
				end
			end
			T:WriteVoxels(reg, 4, mats, occ)
			task.wait()
		end
	end

	-- ===== 2. the Sol Expressway =====
	local XW = 88
	local pts = {}
	local function add(x, y, z) table.insert(pts, Vector3.new(x, y, z)) end
	local base = G + 0.27
	local H = 16
	-- on-ramp stub north of Shore Rd, then the bay bridge (cosine ramps, long flat top)
	for z = -1176, -1220, -22 do add(-810, base, z) end
	for z = -1240, -1480, -20 do
		local t = (-1220 - z) / 260
		add(-810, base + H * (1 - math.cos(math.pi * t)) / 2, z)
	end
	for z = -1540, -2440, -60 do add(-810, base + H, z) end
	for z = -2460, -2700, -20 do
		local t = (z + 2440) / -260
		add(-810, base + H * (1 + math.cos(math.pi * t)) / 2, z)
	end
	-- country: Catmull-Rom through sweeping control points (radius >= ~600: full speed)
	local CP = { Vector3.new(-810, base, -2600), Vector3.new(-810, base, -2700), Vector3.new(-805, base, -2950), Vector3.new(-700, base, -3250),
		Vector3.new(-500, base, -3500), Vector3.new(-430, base, -3740), Vector3.new(-450, base, -3934), Vector3.new(-450, base, -4100) }
	local function cr(p0, p1, p2, p3, t)
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
	for i = 2, #CP - 2 do
		local seg = (CP[i + 1] - CP[i]).Magnitude
		local n = math.max(2, math.floor(seg / 40))
		for k = 1, n do
			local p = cr(CP[i - 1], CP[i], CP[i + 1], CP[i + 2], k / n)
			add(p.X, base, p.Z)
		end
	end
	L.road3D(EX, pts, XW, { name = "Sol Expressway", median = true, lanes = 3, lights = 180, pierStep = 80, var = "AsphaltPlain", color = C(126, 126, 128) })
	L.gantry(EX, Vector3.new(-810, base, -1240), Vector3.new(0, 0, -1), XW, "SOL EXPRESSWAY  NORTH", "Port Sol  4 MI")
	L.gantry(EX, Vector3.new(-805, base, -2900), Vector3.new(0, 0, 1), XW, "VICE BAY", "Downtown  •  I-95 SOUTH")
	L.gantry(EX, Vector3.new(-470, base, -3600), Vector3.new(0.25, 0, -1).Unit, XW, "PORT SOL", "Next exit  •  Waterfront")
	-- roadside: grass shoulders, palms + oaks in loose clusters, two billboards
	local function onLand(x, z) return x > LX0 + 20 and x < LX1 - 20 and z < LZ0 - 20 and z > LZ1 + 20 end
	local veg = 0
	for i = 1, #pts - 1, 3 do
		local a, b = pts[i], pts[i + 1]
		if a.Y < G + 1 and onLand(a.X, a.Z) then
			local d = (b - a).Unit
			local r = Vector3.new(-d.Z, 0, d.X)
			for sd = -1, 1, 2 do
				if L.chance(0.55) then
					local p = a + r * sd * (XW / 2 + L.r(14, 40)) + d * L.r(-10, 10)
					if L.chance(0.6) then L.palm(EX, Vector3.new(p.X, G, p.Z), L.r(30, 42), "royal") else L.tree(EX, Vector3.new(p.X, G, p.Z), L.r(0.8, 1.1)) end
					veg += 1
				end
			end
		end
	end
	local function billboard(p, look, txt, col)
		local m = L.model(EX, "Billboard")
		local cf = CFrame.lookAt(p, p + look)
		for sd = -1, 1, 2 do L.B(m, cf, sd * 8, 0, 0, 1, 26, 1, C(90, 92, 96), M.Metal) end
		L.B(m, cf, 0, 25, 0.6, 30, 0.6, 3, C(90, 92, 96), M.Metal)
		local s = L.B(m, cf, 0, 26, 0, 30, 12, 0.6, col, M.SmoothPlastic)
		L.label(s, Enum.NormalId.Front, txt, { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), light = 0.3, bright = 1.4 })
	end
	billboard(Vector3.new(-900, G, -3050), Vector3.new(1, 0, 0.3), "PORT SOL\nWHERE THE SUN SETS SLOW", C(240, 120, 40))
	billboard(Vector3.new(-380, G, -3350), Vector3.new(-1, 0, -0.2), "SOL MARINA\nBOATS • FUEL • BAIT", C(30, 110, 170))

	-- ===== 3. Port Sol roads =====
	local S = L.STY
	if not S.PSOL then
		S.PSOL = table.clone(S.BLVD)
		S.PSOL.w, S.PSOL.medianW, S.PSOL.tier, S.PSOL.busLane = 86, 12, 2, nil
	end
	local lines = {}
	local function ln(style, p, o)
		o = o or {}
		local t = { style = style, pts = p, name = o.name, cul = o.cul }
		if type(style) == "string" then t.style = S[style] end
		table.insert(lines, t)
	end
	ln("PSOL", { { -450, -3940 }, { -450, -4560 } }, { name = "Sol Pkwy" })
	ln("HABA", { { -1000, -4000 }, { -450, -4000 }, { 100, -4000 } }, { name = "1st Ave" })
	ln("HAB", { { -1000, -4250 }, { -450, -4250 }, { 100, -4250 } }, { name = "Main St" })
	ln("HABA", L.wob and L.wob(-1000, -4560, 100, -4560, 6, 10) or { { -1000, -4560 }, { 100, -4560 } }, { name = "Ocean Dr" })
	ln("HAB", { { -850, -4000 }, { -850, -4560 } }, { name = "Palm Ave" })
	ln("HAB", { { -100, -4000 }, { -100, -4560 } }, { name = "Harbor Ave" })
	ln("RES", { { -1000, -4000 }, { -1000, -4560 } }, { name = "West Rd" })
	ln("RES", { { 100, -4000 }, { 100, -4560 } }, { name = "East Rd" })
	ln("RES", { { -650, -4250 }, { -650, -4420 } }, { name = "Sol Ct", cul = true })
	ln("RES", { { -280, -4000 }, { -280, -4140 } }, { name = "Coral Ct", cul = true })
	local net = L.net(lines)
	L.buildRoads(VB, net, "PortSol")
	local PS = VB.PortSol

	-- ===== 4. lots =====
	local B = L.folder(VB.Buildings, "PortSol")
	local LM = L.folder(VB.Landmarks, "PortSol")
	local blk = L.FILL_BLOCKERS
	local hadPS = false
	for _, n in ipairs(blk) do if n == "PortSol" then hadPS = true end end
	if not hadPS then table.insert(blk, "PortSol") end
	if not table.find(blk, "Expressway") then table.insert(blk, "Expressway") end
	local NAMES = { "SOL CAFE", "MARINA BAIT", "SURF SHACK", "ISLAND REALTY", "TACOS DEL SOL", "BAYSIDE PHARMACY", "PIER PIZZA", "SUNSET YOGA", "DIVE SHOP", "ICE CREAM" }
	local gasDone = false
	local built = L.fill(B, net, function(x, z, st, side, e)
		local nm = e[5] or ""
		if nm == "Sol Pkwy" then
			if not gasDone and z > -4120 then gasDone = true return { kind = "gas", w = 84, d = 64 } end
			return { kind = "stripmall", w = L.r(120, 150), d = 88, opts = { sign = L.pick({ "SOL PLAZA", "HARBOR SQUARE", "PELICAN POINTE" }) } }
		elseif nm == "Main St" or nm == "1st Ave" then
			return { kind = "shop", w = L.r(40, 54), d = 48, opts = { rundown = false, floors = L.chance(0.4) and 2 or 1, signs = { L.pick(NAMES) } } }
		elseif nm == "Harbor Ave" and L.chance(0.4) then
			return { kind = "warehouse", w = L.r(60, 80), d = 54, opts = { sign = L.pick({ "SOL BOATWORKS", "HARBOR COLD STORAGE", "PORT SOL MARINE" }), rundown = false } }
		end
		return { kind = "flhouse", w = L.r(46, 56), d = 52 }
	end, function(x, z) return x > -1100 and x < 200 and z < -3950 and z > -4650 end)

	-- ===== 5. landmarks: welcome monument, waterfront pier, marina POI =====
	do
		local ec = CFrame.new(-520, G, -3900) * CFrame.Angles(0, math.rad(90), 0)
		local mm = L.model(LM, "WelcomeSign")
		L.B(mm, ec, 0, 0, 0, 26, 2, 4, C(206, 196, 178), M.Cobblestone, "StoneFieldLight")
		L.B(mm, ec, 0, 2, 0, 22, 6, 2, C(240, 236, 226), M.Plaster)
		local pl = L.BD(mm, ec, 0, 3, -1.05, 18, 3.6, 0.2, C(24, 70, 110), M.Metal)
		L.label(pl, Enum.NormalId.Front, "WELCOME TO PORT SOL", { font = Enum.Font.Merriweather, color = C(250, 226, 160), light = 0.2, bright = 1.4 })
		for sd = -1, 1, 2 do L.palm(mm, (ec * CFrame.new(sd * 15, 0, 0)).Position, 30, "royal") end
		-- pier off the waterfront
		local pc = CFrame.new(-300, W + 2.2, -4700)
		local pier = L.model(LM, "SolPier")
		L.P(pier, Vector3.new(14, 0.8, 160), pc * CFrame.new(0, 0, -60), C(170, 130, 90), M.WoodPlanks, "WoodPlanksOld")
		for z = 0, -140, -20 do
			for sd = -1, 1, 2 do L.Cyl(pier, 10, 1.2, pc * CFrame.new(sd * 6.4, -4, z + 10), C(110, 90, 70), M.Wood) end
			L.D(pier, Vector3.new(0.4, 6, 0.4), pc * CFrame.new(6.6, 3.4, z + 10), C(40, 40, 42), M.Metal)
			L.D(pier, Vector3.new(0.9, 0.6, 0.9), pc * CFrame.new(6.6, 6.6, z + 10), C(255, 236, 200), M.Neon)
		end
		pcall(function() L.poi(Vector3.new(-300, G, -4640), "Dock", "Sol Pier") end)
	end

	local parts = 0
	for _, f in ipairs({ EX, PS, B, LM }) do for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	return string.format("Port Sol: expressway pts %d, veg %d, lots %s, parts %d (%.0fs)", #pts, veg, tostring(built), parts, os.clock() - t0)
end
