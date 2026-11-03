-- Vice Bay: gas stations (Florida / Larp references). Made-up brands only.
-- L.gasStation(par, cf, w, d, o): cf = lot centre on the ground, local -Z = the street.
--   o.brand = key of BRANDS, o.rundown = hood version (grime, faded paint, bars on the store)
-- Forecourt with a branded canopy (stone-clad columns, LED ceiling), 3 pump islands, LED price pylon,
-- air/vac, light poles, landscaping, and a convenience store with a walk-in interior (gameplay building).
return function(L)
	local M, C = L.M, L.C
	local CS = game:GetService("CollectionService")
	local WHITE, INK = C(244, 244, 240), C(26, 26, 28)
	local BRANDS = {
		sunshine = { name = "SUNSHINE", a = C(240, 120, 30), b = C(250, 200, 40), c = WHITE, store = "SUNSHINE MART" },
		gulfstar = { name = "GULFSTAR", a = C(22, 64, 150), b = C(240, 60, 50), c = WHITE, store = "GULFSTAR FOOD STORE" },
		palm = { name = "PALM PETRO", a = C(20, 120, 70), b = C(250, 210, 50), c = WHITE, store = "PALM PANTRY" },
		vice = { name = "VICE FUEL", a = C(30, 30, 34), b = C(240, 60, 150), c = C(80, 220, 240), store = "VICE 24/7" },
		coastal = { name = "COASTAL", a = C(240, 240, 236), b = C(30, 120, 200), c = C(220, 40, 40), store = "COASTAL EXPRESS" },
	}
	L.GAS_BRANDS = BRANDS

	local function label(part, face, txt, col, font, o)
		o = o or {}
		return L.label(part, face, txt, { font = font or Enum.Font.GothamBlack, color = col or WHITE, light = o.light or 0.2, bright = o.bright or 1.4, size = o.size, pos = o.pos, pps = o.pps })
	end
	local function stripes(part, face, n, col, alpha, vertical)
		if L.villaStripes then L.villaStripes(part, face, n, col, alpha, vertical) end
	end

	function L.gasStation(par, cf, w, d, o)
		o = o or {}
		local B = BRANDS[o.brand or ""] or L.pick({ BRANDS.sunshine, BRANDS.gulfstar, BRANDS.palm, BRANDS.vice, BRANDS.coastal })
		local rd = o.rundown
		local m = Instance.new("Model")
		m.Name = "GasStation"
		m:SetAttribute("Brand", B.name)
		local function Bx(x, y0, z, sx, sy, sz, col, mat, var, opt) return L.B(m, cf, x, y0, z, sx, sy, sz, col, mat, var, opt) end
		local function BDx(x, y0, z, sx, sy, sz, col, mat, var, opt) return L.BD(m, cf, x, y0, z, sx, sy, sz, col, mat, var, opt) end

		-- ---- ground: asphalt lot, concrete forecourt under the canopy, grass + palm strip along the street
		BDx(0, 0.02, 0, w - 1, 0.16, d - 1, rd and C(132, 130, 126) or C(124, 124, 126), M.Asphalt, rd and "ParkingLotAsphalt" or "AsphaltPlain")
		local cw, cdp = math.min(w - 18, 66), 32
		local cz = -d / 2 + 10 + cdp / 2
		BDx(0, 0.05, cz, cw + 8, 0.17, cdp + 6, rd and C(170, 166, 158) or C(196, 194, 188), M.Concrete, rd and "ConcreteStained" or "ConcretePlain")
		-- street strip with two driveway openings
		local ent = { -w / 2 + 12, w / 2 - 12 }
		local x = -w / 2 + 1
		local function strip(x0, x1)
			if x1 - x0 > 2 then
				Bx((x0 + x1) / 2, 0, -d / 2 + 2.2, x1 - x0, 0.5, 3.4, C(200, 198, 192), M.Concrete)
				BDx((x0 + x1) / 2, 0.5, -d / 2 + 2.2, x1 - x0 - 0.8, 0.12, 2.6, C(104, 140, 66), M.Grass)
				for px = x0 + 5, x1 - 4, 14 do L.streetPalm(m, cf * Vector3.new(px, 0.6, -d / 2 + 2.2), px, "date") end
			end
		end
		strip(-w / 2 + 1, ent[1] - 7)
		strip(ent[1] + 7, ent[2] - 7)
		strip(ent[2] + 7, w / 2 - 1)

		-- ---- canopy
		local CH = 16 -- clearance
		local cols = {}
		local nx = (cw > 50) and 3 or 2
		for i = 0, nx - 1 do
			local cx = -cw / 2 + 9 + i * (cw - 18) / math.max(1, nx - 1)
			for _, z in ipairs({ cz - 7, cz + 7 }) do table.insert(cols, { cx, z }) end
		end
		for _, q in ipairs(cols) do
			Bx(q[1], 0, q[2], 1.8, CH, 1.8, rd and C(200, 198, 192) or C(60, 62, 66), M.Metal)
			Bx(q[1], 0, q[2], 2.6, 4.2, 2.6, C(206, 196, 178), M.Cobblestone, "StoneFieldLight")
			Bx(q[1], 4.2, q[2], 2.8, 0.3, 2.8, C(220, 218, 212), M.Concrete)
		end
		local deck = Bx(0, CH, cz, cw, 3, cdp, WHITE, M.SmoothPlastic)
		-- brand fascia: colour band + accent stripe on all four sides, logo front/back
		for _, f in ipairs({ { 0, cz - cdp / 2 - 0.1, cw + 0.3, 0.2 }, { 0, cz + cdp / 2 + 0.1, cw + 0.3, 0.2 }, { -cw / 2 - 0.1, cz, 0.2, cdp + 0.3 }, { cw / 2 + 0.1, cz, 0.2, cdp + 0.3 } }) do
			BDx(f[1], CH + 0.9, f[2], f[3], 1.7, f[4], B.a, M.SmoothPlastic)
			BDx(f[1], CH + 0.55, f[2], f[3], 0.35, f[4], B.b, M.SmoothPlastic)
		end
		for _, sd in ipairs({ -1, 1 }) do
			local lg = L.D(m, Vector3.new(14, 2.4, 0.2), cf * CFrame.new(0, CH + 1.6, cz + sd * (cdp / 2 + 0.25)) * CFrame.Angles(0, sd > 0 and math.pi or 0, 0), B.a, M.SmoothPlastic)
			label(lg, Enum.NormalId.Front, B.name, B.c, Enum.Font.GothamBlack, { bright = 2 })
		end
		-- LED ceiling panels
		for i = 0, 2 do
			for j = 0, 1 do
				local p = L.D(m, Vector3.new(3.4, 0.1, 3.4), cf * CFrame.new(-cw / 3 + i * cw / 3, CH - 0.05, cz - 6 + j * 12), C(255, 252, 240), M.Neon)
				if (i + j) % 2 == 0 then
					local sl = Instance.new("SpotLight")
					sl.Face = Enum.NormalId.Bottom
					sl.Range, sl.Angle, sl.Brightness, sl.Shadows = 24, 120, 1.2, false
					sl.Color = C(255, 248, 236)
					sl.Parent = p
				end
			end
		end

		-- ---- pump islands (between the columns, along z)
		local islands = {}
		for i = 0, nx - 1 do table.insert(islands, -cw / 2 + 9 + i * (cw - 18) / math.max(1, nx - 1)) end
		for k, ix in ipairs(islands) do
			Bx(ix, 0, cz, 3.6, 0.7, 20, rd and C(196, 190, 176) or C(232, 226, 210), M.Concrete)
			BDx(ix, 0.7, cz, 3.7, 0.08, 20.1, B.b, M.SmoothPlastic)
			for _, sz in ipairs({ -4, 4 }) do
				local pc = cf * CFrame.new(ix, 0.7, cz + sz)
				local body = L.B(m, pc, 0, 0, 0, 2.2, 5.6, 1.4, rd and C(210, 210, 206) or WHITE, M.SmoothPlastic)
				L.B(m, pc, 0, 5.6, 0, 2.4, 1.4, 1.6, B.a, M.SmoothPlastic)
				for sd = -1, 1, 2 do
					local scr = L.D(m, Vector3.new(0.05, 1.2, 1), pc * CFrame.new(sd * 1.13, 4, 0), C(16, 20, 24), M.Glass)
					L.label(scr, sd < 0 and Enum.NormalId.Left or Enum.NormalId.Right, string.format("%d\n$ 0.00", (k - 1) * 2 + (sz > 0 and 2 or 1)), { font = Enum.Font.Code, color = C(120, 255, 160), light = 0, bright = 1.6 })
					L.D(m, Vector3.new(0.3, 1.2, 0.3), pc * CFrame.new(sd * 1.2, 2.4, -0.4), INK, M.Rubber)
					L.D(m, Vector3.new(0.15, 0.15, 1.6), pc * CFrame.new(sd * 1.3, 2.6, 0.3), INK, M.Rubber)
				end
				body.Name = "FuelPump"
				CS:AddTag(body, "FuelPump")
			end
			-- bollards + bin + squeegee
			for _, sz in ipairs({ -10.4, 10.4 }) do
				L.Cyl(m, 3.4, 0.9, cf * CFrame.new(ix, 1.7, cz + sz), C(240, 200, 40), M.Metal, nil, { CanCollide = false })
			end
			L.Cyl(m, 2.6, 1.4, cf * CFrame.new(ix, 2, cz), C(40, 44, 46), M.Plastic)
		end

		-- ---- convenience store (walk-in): stucco box, parapet, full glass front, brand fascia
		local sw2 = math.min(w - 20, 48)
		local sd2 = 24
		local sx = 0
		local sz = d / 2 - 3 - sd2 / 2
		local H = 15
		local wallCol = rd and C(214, 204, 186) or C(238, 234, 226)
		local wallVar = rd and "HoodStuccoWorn" or "StuccoWhite"
		local fz = sz - sd2 / 2
		-- floor + walls (front is glass with a door gap)
		BDx(sx, 0.05, sz, sw2, 0.3, sd2, C(214, 212, 206), M.CeramicTiles, "PlazaTiles")
		Bx(sx, 0, sz + sd2 / 2 - 0.5, sw2, H, 1, wallCol, M.Plaster, wallVar)
		for s = -1, 1, 2 do Bx(sx + s * (sw2 / 2 - 0.5), 0, sz, 1, H, sd2, wallCol, M.Plaster, wallVar) end
		Bx(sx, H, sz, sw2 + 0.6, 0.8, sd2 + 0.6, C(200, 198, 192), M.Concrete) -- roof slab
		for _, e in ipairs({ { 0, -sd2 / 2, sw2 + 1.2, 1 }, { 0, sd2 / 2, sw2 + 1.2, 1 }, { -sw2 / 2, 0, 1, sd2 + 1.2 }, { sw2 / 2, 0, 1, sd2 + 1.2 } }) do
			Bx(sx + e[1], H + 0.8, sz + e[2], e[3], 2.4, e[4], wallCol, M.Plaster, wallVar)
		end
		-- glass front: two panes either side of the door, aluminium mullions, kick plate
		local doorW = 6
		for s = -1, 1, 2 do
			local pw = (sw2 - doorW) / 2 - 1
			local px = sx + s * (doorW / 2 + pw / 2)
			local g = L.P(m, Vector3.new(pw, H - 4.4, 0.3), cf * CFrame.new(px, 1.2 + (H - 4.4) / 2, fz), C(80, 104, 116), M.Glass, nil, { Transparency = 0.45, Reflectance = 0.15 })
			BDx(px, 0, fz, pw, 1.2, 0.5, C(170, 172, 176), M.Metal)
			for k = 0, math.floor(pw / 5) do BDx(px - pw / 2 + k * pw / math.floor(pw / 5), 0, fz, 0.35, H - 3.2, 0.5, C(170, 172, 176), M.Metal) end
			-- window posters (rundown: more, faded)
			for k = 1, rd and 3 or 1 do
				local po = L.D(m, Vector3.new(2.6, 3.4, 0.05), cf * CFrame.new(px + L.r(-pw / 3, pw / 3), 5, fz - 0.2), L.pick({ C(230, 60, 50), C(250, 210, 50), C(40, 120, 200) }), M.SmoothPlastic)
				label(po, Enum.NormalId.Front, L.pick({ "2 FOR\n$3", "COLD\nDRINKS", "ICE", "COFFEE\n99¢", "ATM\nINSIDE", "LOTTO-FREE\nSNACKS" }), WHITE, Enum.Font.GothamBlack, { bright = 1 })
			end
		end
		BDx(sx, H - 3.2, fz, sw2, 3.2, 0.6, wallCol, M.Plaster, wallVar)
		-- entry door (open frame) + canopy over the storefront with brand fascia + store name
		for s = -1, 1, 2 do BDx(sx + s * doorW / 2, 0, fz, 0.4, 8.6, 0.6, C(170, 172, 176), M.Metal) end
		BDx(sx, 8.6, fz, doorW, 0.4, 0.6, C(170, 172, 176), M.Metal)
		Bx(sx, H - 3.4, fz - 3, sw2 + 2, 0.6, 6, WHITE, M.SmoothPlastic)
		local fasc = L.D(m, Vector3.new(sw2 + 2, 2.6, 0.3), cf * CFrame.new(sx, H - 1.7 + 0.3, fz - 6.05), B.a, M.SmoothPlastic)
		label(fasc, Enum.NormalId.Front, B.store, B.c, Enum.Font.GothamBlack, { bright = 1.8 })
		BDx(sx, H - 3.6, fz - 6, sw2 + 2, 0.35, 0.3, B.b, M.SmoothPlastic)
		for k = 0, 3 do
			local dl = L.D(m, Vector3.new(0.8, 0.08, 0.8), cf * CFrame.new(sx - sw2 / 2 + 4 + k * (sw2 - 8) / 3, H - 3.75, fz - 3), C(255, 246, 228), M.Neon)
		end
		-- store-front kit: ice chest, propane cage, ATM, trash, newspaper box, bench
		local front = function(xx, w0, h0, d0, col, mat, txt)
			local b = Bx(sx + xx, 0, fz - 1.6, w0, h0, d0, col, mat)
			if txt then label(L.D(m, Vector3.new(w0 * 0.8, 1, 0.05), cf * CFrame.new(sx + xx, h0 - 0.8, fz - 1.6 - d0 / 2 - 0.03), col, M.SmoothPlastic), Enum.NormalId.Front, txt, WHITE, Enum.Font.GothamBlack) end
			return b
		end
		front(-sw2 / 2 + 4, 5, 4.2, 2.4, C(40, 100, 190), M.SmoothPlastic, "ICE")
		front(-sw2 / 2 + 10, 4, 6, 2, C(170, 172, 176), M.DiamondPlate, nil)
		front(sw2 / 2 - 4, 2.6, 6.4, 2, C(50, 60, 70), M.Metal, "ATM")
		L.Cyl(m, 3.2, 2, cf * CFrame.new(sx + sw2 / 2 - 8, 1.6, fz - 1.6), C(40, 44, 46), M.Plastic)

		-- ---- interior (low poly): counter + register, 3 aisles, cooler wall, coffee bar, ceiling lights
		local I = Instance.new("Model")
		I.Name = "Interior"
		local function IB(x, y0, z, sx3, sy3, sz3, col, mat, var, opt) return L.B(I, cf, sx + x, y0, sz + z, sx3, sy3, sz3, col, mat, var, opt) end
		local function ID(x, y0, z, sx3, sy3, sz3, col, mat, var, opt) return L.BD(I, cf, sx + x, y0, sz + z, sx3, sy3, sz3, col, mat, var, opt) end
		-- counter by the door
		IB(-sw2 / 2 + 7, 0.35, -sd2 / 2 + 6, 10, 3.6, 3, C(110, 80, 56), M.Wood)
		ID(-sw2 / 2 + 7, 3.95, -sd2 / 2 + 6, 10.4, 0.3, 3.4, C(40, 40, 42), M.Granite)
		ID(-sw2 / 2 + 5, 4.25, -sd2 / 2 + 6, 1.6, 1.2, 1.4, INK, M.Metal)
		ID(-sw2 / 2 + 8, 4.25, -sd2 / 2 + 6, 2.4, 2.4, 0.4, C(30, 34, 40), M.Glass)
		-- back shelving behind the counter (cigarette-wall style, generic packs)
		local bs = IB(-sw2 / 2 + 7, 0.35, -sd2 / 2 + 9.2, 10, 8, 1.2, C(60, 60, 64), M.Metal)
		stripes(bs, Enum.NormalId.Front, 12, C(220, 200, 120), 0.35, false)
		-- aisles: gondola shelves with product colour bands
		for k = 0, 2 do
			local ax = -sw2 / 2 + 18 + k * 8
			if ax < sw2 / 2 - 8 then
				local g = IB(ax, 0.35, 1, 2.6, 5.6, sd2 - 12, C(236, 236, 232), M.SmoothPlastic)
				for _, f in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do stripes(g, f, 8, L.pick({ C(220, 60, 50), C(40, 120, 200), C(250, 200, 40), C(60, 160, 80) }), 0.25, false) end
				ID(ax, 5.95, 1, 2.8, 0.4, sd2 - 11.6, B.a, M.SmoothPlastic)
			end
		end
		-- cooler wall along the back with glowing glass doors
		for k = 0, math.floor((sw2 - 14) / 3.4) - 1 do
			local cx = sw2 / 2 - 3 - k * 3.4
			IB(cx, 0.35, sd2 / 2 - 2.2, 3.3, 9, 2.4, C(60, 62, 66), M.Metal)
			local dr = ID(cx, 1, sd2 / 2 - 3.45, 2.9, 7.6, 0.1, C(200, 230, 240), M.Glass, nil, { Transparency = 0.35 })
			ID(cx, 1.2, sd2 / 2 - 3.3, 2.6, 7.2, 0.05, L.pick({ C(220, 60, 50), C(40, 120, 200), C(250, 200, 40), C(240, 240, 236) }), M.Neon, nil, { Transparency = 0.55 })
		end
		-- coffee bar on the side wall
		IB(sw2 / 2 - 2, 0.35, -sd2 / 2 + 6, 2.4, 3.4, 8, C(110, 80, 56), M.Wood)
		for k = 0, 2 do ID(sw2 / 2 - 2, 3.75, -sd2 / 2 + 3.5 + k * 2.4, 1.4, 2, 1.4, INK, M.Metal) end
		-- ceiling: drop panels + light strips
		ID(0, H - 0.5, 0, sw2 - 2, 0.2, sd2 - 2, C(236, 236, 232), M.SmoothPlastic)
		for k = 0, 2 do
			local ls = ID(-sw2 / 2 + 8 + k * (sw2 - 16) / 2, H - 0.62, 0, 1, 0.1, sd2 - 6, C(255, 252, 244), M.Neon)
			if k == 1 then
				local pl = Instance.new("PointLight")
				pl.Range, pl.Brightness, pl.Shadows, pl.Color = 26, 0.9, false, C(255, 250, 240)
				pl.Parent = ls
			end
		end
		I.Parent = m

		-- ---- LED price pylon at the street corner
		local px, pz = w / 2 - 6, -d / 2 + 6
		local pc = cf * CFrame.new(px, 0, pz)
		L.B(m, pc, 0, 0, 0, 7, 3, 2.4, C(206, 196, 178), M.Cobblestone, "StoneFieldLight")
		L.B(m, pc, 0, 3, 0, 1.4, 6, 1.4, C(60, 62, 66), M.Metal)
		local top = L.B(m, pc, 0, 9, 0, 7, 4.4, 1.6, B.a, M.SmoothPlastic)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do label(top, f, B.name, B.c, Enum.Font.GothamBlack, { bright = 2 }) end
		local prices = { { "REGULAR", 3.29 + L.ri(0, 30) / 100 }, { "PLUS", 3.69 + L.ri(0, 30) / 100 }, { "PREMIUM", 4.09 + L.ri(0, 30) / 100 }, { "DIESEL", 3.89 + L.ri(0, 30) / 100 } }
		for i, pr in ipairs(prices) do
			local row = L.B(m, pc, 0, 9 - i * 1.5 + 0.0, 0, 7, 1.4, 1.4, C(16, 16, 18), M.SmoothPlastic)
			for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				L.label(row, f, string.format("%-8s  %.2f", pr[1], pr[2]), { font = Enum.Font.Code, color = (i == 4) and C(80, 255, 120) or C(255, 70, 60), light = 0, bright = 2.2, size = UDim2.fromScale(0.96, 0.8), pos = UDim2.fromScale(0.02, 0.1) })
			end
		end

		-- ---- air / vacuum machine, parking stalls, lot lights
		local ac = cf * CFrame.new(-w / 2 + 5, 0, sz)
		L.B(m, ac, 0, 0, 0, 2.4, 6, 2, C(220, 40, 40), M.Metal)
		label(L.D(m, Vector3.new(2, 1.2, 0.05), ac * CFrame.new(0, 4.6, -1.03), C(220, 40, 40), M.SmoothPlastic), Enum.NormalId.Front, "AIR\nVAC", WHITE, Enum.Font.GothamBlack)
		for k = 0, 3 do
			local lx = sx + sw2 / 2 + 3 + k * 4.5
			if lx < w / 2 - 3 then BDx(lx, 0.12, sz - 4, 0.3, 0.05, 12, WHITE, M.SmoothPlastic) end
		end
		for _, q in ipairs({ { -w / 2 + 3, -d / 2 + 6 }, { -w / 2 + 3, d / 2 - 4 }, { w / 2 - 3, d / 2 - 4 } }) do
			L.streetlight(m, cf * CFrame.new(q[1], 0, q[2]) * CFrame.Angles(0, math.pi / 2, 0), true, true)
		end
		-- hood grime
		if rd and L.grime then pcall(function() L.grime(m, cf, sx, sz, sw2, sd2, H + 3, { yard = false }) end) end

		m.Parent = par
		L.lod(m)
		if L.poi then pcall(function() L.poi((cf * CFrame.new(0, 0, cz)).Position, "Gas", B.name, { Brand = B.name }) end) end
		return m
	end
	-- every older caller gets the new station
	L.gasLegacy = L.gas
	L.gas = function(par, cf, w, d, o)
		o = o or {}
		return L.gasStation(par, cf, w, d, { brand = o.brandKey, rundown = o.rundown })
	end
end
