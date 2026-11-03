-- 10 Little Habana (south of the river, x -720..980) + the Port (z 960..1140)
-- Habana: colourful stucco, red tile roofs, Spanish signs, Calle Ocho with Domino Park, the Tower Theater, Cafe La Habana.
-- Port: container yards, freight warehouses, gantry cranes on the quay and a docked cargo ship.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	local VB = L.folder(workspace, "ViceBay")
	local LM = L.folder(L.folder(VB, "Landmarks"), "Habana")
	local B = L.folder(L.folder(VB, "Buildings"), "Habana")
	local PL = L.folder(L.folder(VB, "Landmarks"), "Port")
	local PB = L.folder(L.folder(VB, "Buildings"), "Port")
	for _, f in ipairs({ LM, B, PL, PB }) do f:ClearAllChildren() end
	L.seed(808305)
	local function at(x, z, yaw) return CFrame.new(x, G, z) * CFrame.Angles(0, yaw or 0, 0) end
	local HAB_COLS = { C(244, 170, 180), C(120, 210, 200), C(250, 214, 110), C(250, 150, 120), C(180, 220, 130), C(200, 170, 230), C(250, 236, 200), C(110, 180, 230) }
	local SPANISH = { "FARMACIA", "PANADERIA", "CAFETERIA", "BOTANICA", "ROPA", "MERCADO", "JOYERIA", "BARBERIA", "FRUTERIA", "MUEBLES", "RESTAURANTE", "LAVANDERIA", "MUSICA", "LIBRERIA", "CARNICERIA", "ZAPATERIA", "DULCERIA", "FLORISTERIA" }

	-- ===== Domino Park (Parque del Domino) on Calle Ocho =====
	do
		local c = at(-320, 719)
		local dp = L.model(LM, "DominoPark")
		L.BD(dp, c, 0, 0.03, 0, 106, 0.3, 68, C(214, 200, 176), M.Pavement, "HerringbonePavers")
		-- pergola
		for x = -40, 40, 16 do
			for _, z in ipairs({ -14, 14 }) do L.B(dp, c, x, 0, z, 1.4, 14, 1.4, C(244, 240, 230), M.Concrete) end
		end
		L.B(dp, c, 0, 14, 0, 86, 1.2, 32, C(186, 110, 80), M.ClayRoofTiles, "RoofClayMission")
		-- domino tables with stools
		for x = -36, 36, 12 do
			for _, z in ipairs({ -6, 6 }) do
				local tc = c * CFrame.new(x, 0, z)
				L.B(dp, tc, 0, 0, 0, 1, 2.6, 1, C(60, 60, 60), M.Metal)
				L.B(dp, tc, 0, 2.6, 0, 4, 0.3, 4, C(30, 110, 60), M.SmoothPlastic)
				for _, q in ipairs({ { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 } }) do L.Cyl(dp, 1.8, 1.4, tc * CFrame.new(q[1], 0.9, q[2]), C(240, 240, 236), M.Plastic) end
				for k = 1, 4 do L.D(dp, Vector3.new(0.5, 0.15, 0.9), tc * CFrame.new(L.r(-1.4, 1.4), 2.85, L.r(-1.4, 1.4)) * CFrame.Angles(0, L.r(0, 3), 0), C(250, 250, 245), M.SmoothPlastic) end
			end
		end
		local mural = L.P(dp, Vector3.new(60, 14, 1.2), c * CFrame.new(0, 7, 31), C(240, 236, 226), M.Plaster, "StuccoWhite")
		L.text(mural, Enum.NormalId.Front, "PARQUE DEL DOMINO", { font = Enum.Font.Bangers, color = C(200, 40, 50), stroke = 0, bg = C(250, 214, 110), pps = 8, dist = 400, light = 1 })
		for _, x in ipairs({ -48, 48 }) do L.palm(dp, (c * CFrame.new(x, 0, -26)).Position, L.r(28, 36)) end
		L.footprint(LM, c, 106, 68)
		L.poi(Vector3.new(-320, G, 719), "Park", "Domino Park")
	end
	-- Tower Theater (art deco cinema) + Cafe La Habana (job) on Calle Ocho
	L.artdeco(LM, at(-160, 584, math.pi), 64, 60, { sign = "TOWER THEATER", floors = 4, color = C(250, 236, 200) })
	L.footprint(LM, at(-160, 584, math.pi), 64, 60)
	L.shop(LM, at(-480, 590, math.pi), 70, 50, { units = 2, floors = 2, rundown = false, signs = { "CAFE LA HABANA", "CAFE VENTANITA" }, color = C(244, 170, 180), interior = true, menu = "CAFECITO  •  CROQUETAS  •  PASTELITOS  •  CUBANO", accent = C(40, 110, 80), front = "cornice" })
	L.footprint(LM, at(-480, 590, math.pi), 70, 50)
	L.poi(Vector3.new(-480, G, 625), "Job", "Cafe La Habana", { Job = "Waiter", Pay = 55 })
	L.poi(Vector3.new(-160, G, 625), "Shop", "Tower Theater", { Sells = "Movies" })

	-- ===== Calle Ocho street life: flags/bunting across the street, palms already on HABA style =====
	local co = L.model(LM, "CalleOcho")
	for x = -700, 280, 36 do
		for k = 0, 7 do
			local z = 650 - 20 + k * 40 / 7
			L.D(co, Vector3.new(0.1, 1.6, 1.4), CFrame.new(x, G + 20 - math.sin(k / 7 * math.pi) * 2, z), L.pick({ C(200, 30, 40), C(250, 250, 248), C(30, 60, 160), C(250, 200, 40) }), M.Fabric)
		end
	end

	-- ===== Habana fill =====
	local function inHab(x, z)
		if z < 330 or z > 1000 then return false end
		if x < -715 or x > 985 then return false end
		if x < -100 and z > 945 then return false end -- port strip
		return true
	end
	local built = L.fill(B, net, function(x, z, st, side, e)
		if not inHab(x, z) then return nil end
		local col = L.pick(HAB_COLS)
		if e[5] == "Calle Ocho" then
			return { kind = "shop", w = L.r(36, 50), d = L.r(44, 50), gap = 0, opts = { rundown = false, floors = L.chance(0.5) and 2 or 1, units = 2, color = col, signs = { L.pick(SPANISH), L.pick(SPANISH) } } }
		end
		local r = L.rng:NextNumber()
		if r < 0.55 then return { kind = "house", w = L.r(40, 48), d = L.r(44, 50), opts = { rundown = false, color = col, carChance = 0.6 } } end
		if r < 0.72 then return { kind = "walkup", w = L.r(54, 66), d = 50, opts = { rundown = false, color = col } } end
		if r < 0.9 then return { kind = "shop", w = L.r(40, 56), d = 48, opts = { rundown = false, floors = 1, color = col, signs = { L.pick(SPANISH), L.pick(SPANISH) } } } end
		if r < 0.95 then return { kind = "church", w = 46, d = 54, opts = { sign = "IGLESIA SAN JUAN" } } end
		return { kind = "emptyLot", w = 36, d = 44 }
	end)

	-- ===== PORT =====
	-- container yards between Port Blvd and Port Rd, freight warehouses, the quay with cranes and a ship
	function L.containerYard(par, cf, w, d)
		local m = L.model(par, "ContainerYard")
		L.BD(m, cf, 0, 0.03, 0, w - 1, 0.15, d - 1, C(130, 128, 122), M.Concrete, "ConcreteStained")
		local cols = { C(180, 60, 40), C(40, 90, 160), C(60, 130, 80), C(220, 180, 50), C(150, 150, 150), C(230, 120, 40), C(40, 40, 46), C(240, 240, 240) }
		for x = -w / 2 + 6, w / 2 - 6, 10 do
			for z = -d / 2 + 22, d / 2 - 22, 44 do
				local n = L.ri(0, 3)
				for k = 0, n - 1 do
					L.P(m, Vector3.new(8, 8.6, 40), cf * CFrame.new(x, 4.3 + k * 8.6, z), L.pick(cols), M.Metal, "ShippingContainer")
				end
			end
		end
		L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, 9, "chain")
		return m
	end
	local pbuilt = L.fill(PB, net, function(x, z, st, side, e)
		if not (z > 945 and x < -110 and x > -1795) then return nil end
		if L.chance(0.5) then return { kind = "containerYard", w = L.r(60, 90), d = L.r(44, 60), gap = 4 } end
		return { kind = "warehouse", w = L.r(60, 90), d = L.r(44, 60), opts = { metal = true, sign = L.pick({ "SUNCOAST FREIGHT", "VICE BAY LOGISTICS", "ATLANTIC COLD STORAGE", "PORT SUPPLY CO", "A1 SCRAP & METAL" }), rundown = true } }
	end)
	-- the quay: concrete edge, bollards, gantry cranes
	local quay = L.model(PL, "Quay")
	L.P(quay, Vector3.new(1640, 10, 14), CFrame.new(-930, G - 5, 1133), C(170, 166, 156), M.Concrete, "ChannelWall")
	for x = -1740, -120, 40 do L.Cyl(quay, 2, 1.6, CFrame.new(x, G + 1, 1136), C(40, 40, 44), M.Metal) end
	for _, x in ipairs({ -1450, -1150, -850 }) do
		local cc = CFrame.new(x, G, 1128)
		local cr = L.model(PL, "GantryCrane")
		local yel = C(230, 180, 40)
		for _, q in ipairs({ { -14, -8 }, { 14, -8 }, { -14, 30 }, { 14, 30 } }) do L.P(cr, Vector3.new(3, 60, 3), cc * CFrame.new(q[1], 30, q[2]), yel, M.Metal) end
		L.P(cr, Vector3.new(3, 3, 140), cc * CFrame.new(-14, 61, 30), yel, M.Metal)
		L.P(cr, Vector3.new(3, 3, 140), cc * CFrame.new(14, 61, 30), yel, M.Metal)
		for k = 0, 6 do L.D(cr, Vector3.new(30, 1, 1), cc * CFrame.new(0, 61, -30 + k * 20), yel, M.Metal) end
		L.P(cr, Vector3.new(12, 8, 10), cc * CFrame.new(0, 56, 40), C(240, 240, 236), M.Metal)
		L.D(cr, Vector3.new(0.4, 30, 0.4), cc * CFrame.new(0, 40, 40), C(30, 30, 30), M.Metal)
		L.P(cr, Vector3.new(10, 2, 42), cc * CFrame.new(0, 24, 40), C(200, 200, 200), M.Metal)
	end
	-- docked cargo ship
	do
		local sc = CFrame.new(-1150, L.WATER, 1185)
		local ship = L.model(PL, "CargoShip")
		L.P(ship, Vector3.new(380, 22, 46), sc * CFrame.new(0, 4, 0), C(30, 50, 80), M.Metal, "PaintedMetalA")
		L.P(ship, Vector3.new(381, 6, 46.5), sc * CFrame.new(0, -6, 0), C(150, 40, 30), M.Metal)
		L.W(ship, Vector3.new(46, 22, 30), sc * CFrame.new(-205, 4, 0) * CFrame.Angles(0, -math.pi / 2, 0), C(30, 50, 80), M.Metal)
		L.P(ship, Vector3.new(30, 36, 40), sc * CFrame.new(165, 33, 0), C(240, 240, 236), M.Metal)
		L.D(ship, Vector3.new(30.5, 4, 40.5), sc * CFrame.new(165, 44, 0), C(40, 50, 60), M.Glass)
		L.P(ship, Vector3.new(6, 16, 6), sc * CFrame.new(165, 59, 0), C(200, 60, 40), M.Metal)
		local cols = { C(180, 60, 40), C(40, 90, 160), C(60, 130, 80), C(220, 180, 50), C(150, 150, 150), C(230, 120, 40) }
		for x = -170, 130, 42 do
			for z = -16, 16, 10.5 do
				for k = 0, L.ri(1, 3) - 1 do L.P(ship, Vector3.new(40, 8.6, 9), sc * CFrame.new(x, 19.3 + k * 8.6, z), L.pick(cols), M.Metal, "ShippingContainer") end
			end
		end
		local nm = L.D(ship, Vector3.new(60, 6, 0.2), sc * CFrame.new(-120, 8, -23.2), C(30, 50, 80), M.SmoothPlastic)
		L.text(nm, Enum.NormalId.Front, "VICE STAR", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), pps = 8, dist = 600 })
	end
	L.poi(Vector3.new(-1150, G, 1110), "Job", "Suncoast Freight", { Job = "Trucker", Pay = 70 })
	L.poi(Vector3.new(-700, G, 1110), "Job", "Port Dockworker", { Job = "Dockworker", Pay = 60 })

	local parts = 0
	for _, f in ipairs({ LM, B, PL, PB }) do for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end
	return "habana lots " .. built .. ", port lots " .. pbuilt .. ", parts " .. parts
end
