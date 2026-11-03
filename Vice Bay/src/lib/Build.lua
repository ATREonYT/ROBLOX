-- Vice Bay buildings + lot filler
-- every generator: gen(parent, cf, w, d, opts). cf = lot centre at ground level, -Z faces the street.
return function(L)
	local M, C = L.M, L.C

	-- Miami hood palette: sun-faded pastel stucco + a few greys (60/30/10 rule: walls stay muted)
	-- muted, sun-faded and dirty (Larp references): tans, greige, dusty salmon, faded sage / blue-grey, cream
	L.HOOD_COLS = { C(198, 166, 134), C(186, 152, 126), C(172, 168, 158), C(206, 198, 182), C(160, 168, 156), C(180, 162, 140),
		C(150, 156, 160), C(192, 178, 152), C(172, 134, 112), C(214, 204, 186), C(188, 172, 150), C(164, 150, 136) }
	-- public grime images (Creator Store): water/mould streaks, hairline cracks, peeling paint, oil stain, wet smudge, road cracks
	L.GRIME = { streaks = "rbxassetid://729943180", cracks = "rbxassetid://30217423", peel = "rbxassetid://164688340",
		oil = "rbxassetid://118775947", smudge = "rbxassetid://182906320", roadCracks = "rbxassetid://146096699", cracks2 = "rbxassetid://483309292" }
	function L.decal(part, face, img, tr)
		local d = Instance.new("Decal")
		d.Texture = img
		d.Face = face
		d.Transparency = tr or 0
		d.Parent = part
		return d
	end
	-- grime a whole box: streaks down every visible face (no extra parts) + now and then a crack / peel patch
	function L.grimeBox(m, part, frontZ, cf, x, y0, w, h, heavy)
		local tr = heavy and L.r(0.1, 0.25) or L.r(0.25, 0.45)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back }) do L.decal(part, f, L.GRIME.streaks, tr + L.r(-0.05, 0.08)) end
		if frontZ and L.chance(heavy and 0.7 or 0.4) then
			local pw = L.r(4, 7)
			local pp = L.D(m, Vector3.new(pw, pw * 0.8, 0.05), cf * CFrame.new(x + L.r(-w / 3, w / 3), y0 + L.r(4, math.max(5, h - 5)), frontZ - 0.04), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
			L.decal(pp, Enum.NormalId.Front, L.pick({ L.GRIME.cracks, L.GRIME.peel, L.GRIME.cracks2 }), 0.35)
		end
	end
	L.WALLVARS = { "HoodStuccoWorn", "HoodStuccoWorn", "StuccoPinkWeathered", "PlasterWorn", "HoodPlasterChipped", "HoodStuccoCracked", "PlasterCrackedB" }
	-- kid-safe, real-feeling hood businesses (no liquor / lotto / pawn / bail bonds / gangs)
	L.SHOP_NAMES = { "FOOD MART", "WASH N FOLD", "WIRELESS 4 LESS", "TIRES", "BEAUTY SUPPLY", "BARBER SHOP", "PHONE REPAIR", "WINGS", "99 CENT",
		"SNEAKERS", "DOLLAR STORE", "TAX SERVICE", "JERK CHICKEN", "SEAFOOD", "MEAT MARKET", "FURNITURE", "DISCOUNT", "LAUNDROMAT", "CORNER STORE",
		"BRAIDS", "KICKS", "BOTANICA", "PIZZA", "CHINESE FOOD", "AUTO PARTS", "GROCERY", "BAKERY", "CONCH SHACK", "CAFE CUBANO", "FISH FRY", "TACOS" }
	L.SIGN_COLS = { { C(196, 30, 30), C(255, 255, 255) }, { C(250, 210, 40), C(20, 20, 20) }, { C(20, 60, 140), C(255, 255, 255) },
		{ C(250, 250, 248), C(200, 20, 20) }, { C(20, 120, 60), C(255, 255, 255) }, { C(26, 26, 28), C(255, 200, 40) }, { C(250, 250, 248), C(20, 60, 140) } }

	local INK = C(34, 34, 36)
	local GLASS = C(40, 48, 56)

	-- window with sill + lintel, optional bars / shade / AC / jalousie / boarded
	function L.win(m, cf, x, y0, fz, w, h, o)
		o = o or {}
		if o.boarded then
			L.B(m, cf, x, y0, fz - 0.15, w, h, 0.35, C(150, 122, 92), M.WoodPlanks, "WoodPlanksOld")
			return
		end
		-- frame plate, dark glass, cross mullion, deep concrete sill
		local tr = o.trim or C(222, 220, 214)
		L.BD(m, cf, x, y0 - 0.4, fz - 0.05, w + 0.8, h + 0.8, 0.2, tr, M.SmoothPlastic)
		L.BD(m, cf, x, y0, fz - 0.12, w, h, 0.2, o.glass or C(34, 40, 46), M.Glass, nil, { Reflectance = 0.16 })
		L.BD(m, cf, x, y0, fz - 0.2, 0.25, h, 0.3, tr, M.SmoothPlastic)
		L.BD(m, cf, x, y0 + h * 0.62, fz - 0.2, w, 0.25, 0.3, tr, M.SmoothPlastic)
		L.BD(m, cf, x, y0 - 0.95, fz - 0.35, w + 1.4, 0.4, 0.9, C(196, 192, 184), M.Concrete)
		if o.jalousie then
			for k = 1, math.floor(h / 0.9) do
				L.BD(m, cf, x, y0 + k * 0.9 - 0.5, fz - 0.25, w - 0.2, 0.12, 0.3, C(200, 206, 210), M.Glass, nil, { Transparency = 0.2 })
			end
		end
		if o.shade then
			local sh = h * L.r(0.25, 0.6)
			L.BD(m, cf, x, y0 + h - sh, fz - 0.2, w - 0.2, sh, 0.1, L.pick({ C(236, 230, 214), C(220, 214, 200), C(190, 170, 140) }), M.Fabric)
		end
		if o.bars then
			local bc = o.barCol or INK
			local n = math.max(3, math.floor(w / 1.1))
			for k = 0, n do
				L.BD(m, cf, x - w / 2 + k * w / n, y0 - 0.2, fz - 0.75, 0.15, h + 0.4, 0.15, bc, M.Metal)
			end
			for _, yy in ipairs({ y0 - 0.1, y0 + h * 0.5, y0 + h + 0.05 }) do L.BD(m, cf, x, yy, fz - 0.75, w + 0.3, 0.16, 0.16, bc, M.Metal) end
		end
		if o.ac then
			L.B(m, cf, x + w * 0.2, y0 + 0.05, fz - 1.1, 2.4, 1.6, 1.9, C(206, 204, 198), M.Metal)
			L.BD(m, cf, x + w * 0.2, y0 + 0.4, fz - 2.08, 2.1, 1.1, 0.06, C(120, 120, 118), M.Metal)
		end
	end
	local function door(m, cf, x, y0, fz, w, h, col, screen)
		L.BD(m, cf, x, y0, fz - 0.1, w, h, 0.25, col or L.pick({ C(90, 60, 40), C(236, 236, 230), C(40, 60, 90), C(150, 40, 40), C(70, 96, 70) }), M.Wood)
		L.BD(m, cf, x, y0 + h, fz - 0.2, w + 0.8, 0.4, 0.4, C(232, 228, 218), M.Concrete)
		if screen then
			-- security screen door (iron) - very Miami
			L.BD(m, cf, x, y0, fz - 0.5, w + 0.2, h, 0.12, INK, M.Metal, nil, { Transparency = 0.45 })
			L.BD(m, cf, x, y0 + h / 2, fz - 0.58, w + 0.2, 0.18, 0.18, INK, M.Metal)
		end
	end
	local CAP = C(200, 198, 192)
	local function parapet(m, cf, x, z, w, d, h, col)
		-- parapet walls in the facade colour, light concrete coping on top (the line that reads on every reference building)
		L.B(m, cf, x, h, z - d / 2 + 0.4, w, 1.8, 0.8, col, M.Plaster)
		L.B(m, cf, x, h, z + d / 2 - 0.4, w, 1.8, 0.8, col, M.Plaster)
		L.B(m, cf, x - w / 2 + 0.4, h, z, 0.8, 1.8, d - 1.6, col, M.Plaster)
		L.B(m, cf, x + w / 2 - 0.4, h, z, 0.8, 1.8, d - 1.6, col, M.Plaster)
		L.BD(m, cf, x, h + 1.8, z - d / 2 + 0.4, w + 0.8, 0.45, 1.5, CAP, M.Concrete)
		L.BD(m, cf, x, h + 1.8, z + d / 2 - 0.4, w + 0.8, 0.45, 1.5, CAP, M.Concrete)
		L.BD(m, cf, x - w / 2 + 0.4, h + 1.8, z, 1.5, 0.45, d - 1.6, CAP, M.Concrete)
		L.BD(m, cf, x + w / 2 - 0.4, h + 1.8, z, 1.5, 0.45, d - 1.6, CAP, M.Concrete)
		L.BD(m, cf, x, h - 0.05, z, w - 1.4, 0.15, d - 1.4, C(70, 68, 66), M.Asphalt, "RoofFlatBitumen")
	end
	local function rooftop(m, cf, x, z, w, d, h)
		if L.chance(0.7) then L.B(m, cf, x + L.r(-w / 4, w / 4), h, z + L.r(-d / 4, d / 4), 4, 2.6, 4, C(190, 190, 186), M.Metal) end
		if L.chance(0.35) then
			L.Cyl(m, 0.25, 2.6, cf * CFrame.new(x + L.r(-w / 3, w / 3), h + 2.4, z - d / 2 + 1.6) * CFrame.Angles(0.5, L.r(-0.5, 0.5), 0), C(228, 228, 226), M.SmoothPlastic)
		end
	end
	L.parapet, L.rooftop, L.door = parapet, rooftop, door
	local function wall(m, cf, x, y0, z, w, h, d, col, var, rundown)
		-- realistic low poly: plain render (no noisy variant) + streak decals on every face + a dirty concrete plinth
		local p = L.B(m, cf, x, y0, z, w, h, d, col, M.Plaster, var)
		L.BD(m, cf, x, y0, z, w + 0.5, 2, d + 0.5, L.shade(col, 0.6), M.Concrete)
		L.grimeBox(m, p, z - d / 2 - 0.25, cf, x, y0, w, h, rundown ~= false)
		return p
	end
	L.wall = wall

	-- =====================================================================================
	-- LARP-STYLE EXTERIOR KIT: the things that make a hood box read as a real building
	-- (cornice + coping, false fronts, wall AC with drip stains, meter banks + conduit, wall packs,
	--  rooftop billboards on steel, hand-painted side-wall ads). Every piece is 1-3 parts.
	-- =====================================================================================
	local STEEL = C(72, 74, 78)
	local CAP = C(216, 214, 206)
	-- window AC hanging off a side wall (side = -1 left / 1 right of the box centred at bx), drip stain below
	function L.wallAC(m, cf, bx, side, bw, z, y, col)
		local x = bx + side * bw / 2
		L.B(m, cf, x + side * 1, y, z, 2, 1.7, 2.6, C(206, 204, 198), M.Metal)
		L.BD(m, cf, x + side * 2.02, y + 0.3, z, 0.06, 1.1, 2.2, C(104, 104, 102), M.Metal)
		L.BD(m, cf, x + side * 0.04, 0.4, z + 0.4, 0.06, y - 0.4, 0.8, L.shade(col, 0.7), M.Plaster, nil, { Transparency = 0.45 })
	end
	-- electric meter bank + conduit running up to the roof (one per building)
	function L.meterBank(m, cf, bx, side, bw, z, h)
		local x = bx + side * (bw / 2 + 0.3)
		L.BD(m, cf, x, 3.4, z, 0.6, 2.6, 3.6, C(150, 152, 150), M.Metal)
		for k = -1, 1 do L.BD(m, cf, x + side * 0.35, 4, z + k * 1.1, 0.2, 0.7, 0.7, C(200, 200, 196), M.Glass) end
		L.BD(m, cf, x, 6, z - 1, 0.28, h - 5.4, 0.28, C(160, 160, 156), M.Metal)
	end
	-- windows on the two side walls (real buildings are not blank boxes from the side)
	function L.sideWindows(m, cf, cx, bz, bw, bd, y0, floors, fh, o)
		o = o or {}
		local cols = math.max(1, math.floor(bd / 16))
		for _, sd in ipairs({ -1, 1 }) do
			if not (o.skipSide == sd) then
				for k = 0, cols - 1 do
					local zz = bz - bd / 2 + (k + 0.5) * bd / cols
					local sc = cf * CFrame.new(cx + sd * bw / 2, 0, zz) * CFrame.Angles(0, -sd * math.pi / 2, 0)
					for f = 0, floors - 1 do
						if not (f == 0 and o.noGround) and L.chance(o.chance or 0.75) then
							L.win(m, sc, 0, y0 + f * fh, 0, 4.4, 4.6, { bars = f == 0 or L.chance(0.25), shade = L.chance(0.4) })
							if f > 0 and L.chance(0.18) then L.facadeAC(m, sc, 3.6, y0 + f * fh + 0.4, 0) end
						end
					end
				end
			end
		end
	end
	-- split-AC condenser bolted to a facade (round fan grille), drip stain under it
	function L.facadeAC(m, cf, x, y, fz)
		L.B(m, cf, x, y, fz - 0.9, 2.8, 2.2, 1.6, C(214, 212, 206), M.Metal)
		L.D(m, Vector3.new(0.1, 1.7, 1.7), cf * CFrame.new(x - 0.3, y + 1.1, fz - 1.72) * CFrame.Angles(0, math.pi / 2, 0), C(40, 40, 42), M.Metal, nil, { Shape = Enum.PartType.Cylinder })
		L.BD(m, cf, x, 0.6, fz - 0.04, 0.6, y - 0.6, 0.06, C(90, 84, 76), M.Plaster, nil, { Transparency = 0.6 })
	end
	-- warm wall pack lamp over a door
	function L.wallPack(m, cf, x, y, fz)
		L.BD(m, cf, x, y, fz - 0.35, 1, 0.7, 0.7, C(60, 60, 62), M.Metal)
		L.BD(m, cf, x, y - 0.06, fz - 0.55, 0.7, 0.1, 0.4, C(255, 214, 160), M.Neon)
	end
	-- false-front parapet profile + cornice band + coping (front face at fz, building width w, roof at h)
	function L.falseFront(m, cf, x0, fz, w, h, col, kind)
		kind = kind or L.pick({ "flat", "step", "raise", "cornice", "cornice", "band" })
		local cap = CAP
		L.BD(m, cf, x0, h - 2.4, fz - 0.4, w + 0.5, 0.8, 0.8, L.shade(col, 1.1), M.Concrete)
		if kind == "raise" then
			local rw = math.min(w * 0.5, 28)
			L.B(m, cf, x0, h + 1.6, fz + 0.2, rw, 2.6, 0.8, L.shade(col, 0.95), M.Plaster)
			L.BD(m, cf, x0, h + 4.2, fz + 0.2, rw + 0.6, 0.35, 1.2, cap, M.Concrete)
		elseif kind == "step" then
			local w1, w2 = math.min(w * 0.62, 34), math.min(w * 0.3, 16)
			L.B(m, cf, x0, h + 1.6, fz + 0.2, w1, 1.8, 0.8, L.shade(col, 0.95), M.Plaster)
			L.BD(m, cf, x0, h + 3.4, fz + 0.2, w1 + 0.5, 0.3, 1.1, cap, M.Concrete)
			L.B(m, cf, x0, h + 3.7, fz + 0.2, w2, 1.8, 0.8, L.shade(col, 0.95), M.Plaster)
			L.BD(m, cf, x0, h + 5.5, fz + 0.2, w2 + 0.5, 0.3, 1.1, cap, M.Concrete)
		elseif kind == "cornice" then
			L.BD(m, cf, x0, h + 1.1, fz - 0.7, w + 1.4, 0.6, 2, cap, M.Concrete)
		elseif kind == "band" then
			-- MiMo eyebrow: a thin deep slab across the whole front
			L.BD(m, cf, x0, h - 4.8, fz - 1.6, w + 0.6, 0.45, 3.2, cap, M.Concrete)
		end
		L.BD(m, cf, x0, h + 1.6, fz + 0.2, w + 0.6, 0.25, 1.1, cap, M.Concrete)
		return kind
	end
	-- made-up advertisers only
	L.ADS = {
		{ "PALMS CREDIT UNION", "Banking for the 305", C(20, 90, 160) }, { "ISLAND 99.1 FM", "Hits all day, every day", C(230, 96, 30) },
		{ "VICE BAY MOBILE", "Unlimited talk & text $25", C(120, 36, 140) }, { "BAY CITY PIZZA", "Hot to your door in 30", C(196, 32, 30) },
		{ "SOL AIR", "Fly to Port Sol from $49", C(18, 140, 170) }, { "COCO FRESH", "Real coconut water", C(40, 140, 72) },
		{ "SMILE BRIGHT DENTAL", "Kids see the dentist free", C(30, 120, 200) }, { "KICKS CITY", "New drops every Friday", C(28, 28, 30) },
		{ "SUNCOAST MOVERS", "We move Dade County", C(240, 180, 30) }, { "CORAL BAY COLLEGE", "Enroll today", C(24, 50, 110) },
	}
	-- rooftop billboard on a steel frame; cf frame at the roof (y = h), -Z = the side the ad faces
	function L.roofBillboard(m, cf, x, z, h, yaw)
		local c = cf * CFrame.new(x, h, z) * CFrame.Angles(0, yaw or 0, 0)
		local bw, bh, post = 24, 9, 7
		for _, sx in ipairs({ -bw * 0.3, bw * 0.3 }) do
			L.B(m, c, sx, 0, 0.6, 0.7, post + bh - 1, 0.7, STEEL, M.Metal)
			L.bar(m, (c * CFrame.new(sx, 0, 5)).Position, (c * CFrame.new(sx, post * 0.8, 0.8)).Position, 0.4, STEEL, M.Metal)
		end
		L.BD(m, c, 0, post - 0.3, -0.9, bw, 0.2, 1.8, STEEL, M.DiamondPlate)
		L.B(m, c, 0, post, 0, bw, bh, 0.5, C(120, 122, 126), M.Metal)
		local ad = L.pick(L.ADS)
		local face = L.BD(m, c, 0, post + 0.3, -0.3, bw - 0.6, bh - 0.6, 0.06, ad[3], M.SmoothPlastic)
		L.text(face, Enum.NormalId.Front, ad[1], { font = Enum.Font.GothamBlack, color = C(255, 255, 255), size = UDim2.fromScale(0.9, 0.46), pos = UDim2.fromScale(0.05, 0.1), pps = 6, dist = 700, light = 0.8 })
		L.text(face, Enum.NormalId.Front, ad[2], { font = Enum.Font.GothamBold, color = C(255, 240, 200), size = UDim2.fromScale(0.8, 0.2), pos = UDim2.fromScale(0.1, 0.66), pps = 6, dist = 500, light = 0.8 })
		if L.chance(0.5) then
			-- sun-bleached / peeling strip
			L.BD(m, c, L.r(-bw / 3, bw / 3), post + L.r(0.6, 3), -0.36, L.r(3, 6), L.r(2, 5), 0.04, C(226, 222, 210), M.SmoothPlastic, nil, { Transparency = 0.25 })
		end
		for _, sx in ipairs({ -bw * 0.25, bw * 0.25 }) do L.BD(m, c, sx, post - 0.1, -1.7, 0.5, 0.5, 1.4, STEEL, M.Metal) end
	end
	-- hand-painted ad across the upper part of a side wall
	L.WALL_ADS = { "CELL PHONES • CASES • REPAIRS", "COLD DRINKS • ICE • SNACKS", "TIRES • RIMS • BRAKES", "WASH • DRY • FOLD", "FRESH FISH DAILY",
		"HAIRCUTS • FADES • LINE UPS", "OPEN 7 DAYS", "GROCERIES • HOT FOOD", "WINGS • FRIES • SHAKES", "PHONE CASES • CHARGERS" }
	function L.sideAd(part, face, txt, bg)
		L.text(part, face, txt or L.pick(L.WALL_ADS), {
			font = L.pick({ Enum.Font.Oswald, Enum.Font.GothamBlack, Enum.Font.Bangers }), color = C(250, 250, 246),
			bg = bg or L.pick({ C(30, 60, 140), C(170, 32, 30), C(30, 110, 60), C(30, 30, 32), C(214, 146, 30) }),
			size = UDim2.fromScale(0.84, 0.17), pos = UDim2.fromScale(0.08, 0.12), pps = 8, dist = 320, light = 1, trans = 0.06,
		})
	end

	-- hollow shell for buildings with a walk-in interior. gaps = front openings { {x0, x1, top}, ... } in local x.
	-- returns { front = header part, left, right, back, roof }
	function L.shell(m, cf, cx, cz, w, d, h, col, var, gaps)
		local fz, t = cz - d / 2, 1
		local S = {}
		S.back = L.B(m, cf, cx, 0, cz + d / 2 - t / 2, w, h, t, col, M.Plaster, var)
		S.left = L.B(m, cf, cx - w / 2 + t / 2, 0, cz, t, h, d - 2 * t, col, M.Plaster, var)
		S.right = L.B(m, cf, cx + w / 2 - t / 2, 0, cz, t, h, d - 2 * t, col, M.Plaster, var)
		S.roof = L.B(m, cf, cx, h - 1, cz, w - 2 * t, 1, d - 2 * t, L.shade(col, 0.8), M.Concrete)
		-- front: header above the tallest opening, piers between openings
		table.sort(gaps, function(a, b) return a[1] < b[1] end)
		local top = 0
		for _, g in ipairs(gaps) do top = math.max(top, g[3]) end
		S.front = L.B(m, cf, cx, top, fz + t / 2, w, h - top, t, col, M.Plaster, var)
		local x = cx - w / 2
		for _, g in ipairs(gaps) do
			if g[1] - x > 0.05 then L.B(m, cf, (x + g[1]) / 2, 0, fz + t / 2, g[1] - x, top, t, col, M.Plaster, var) end
			if g[3] < top - 0.05 then L.B(m, cf, (g[1] + g[2]) / 2, g[3], fz + t / 2, g[2] - g[1], top - g[3], t, col, M.Plaster, var) end
			x = g[2]
		end
		if cx + w / 2 - x > 0.05 then L.B(m, cf, (x + cx + w / 2) / 2, 0, fz + t / 2, cx + w / 2 - x, top, t, col, M.Plaster, var) end
		-- plinth along the front + streaks on every wall
		L.BD(m, cf, cx, 0, fz - 0.1, w + 0.5, 2, 0.4, L.shade(col, 0.6), M.Concrete)
		for _, k in ipairs({ "front", "left", "right", "back" }) do
			for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back }) do L.decal(S[k], f, L.GRIME.streaks, L.r(0.2, 0.4)) end
		end
		return S
	end

	-- =====================================================================================
	-- LOW-POLY INTERIORS for purposeful shops (jobs / POIs only). c = unit frame at floor level,
	-- centre of the room, -Z = street. uw x ud = clear room size, h = ceiling.
	-- =====================================================================================
	local STAIN = C(178, 180, 182)
	local function ceilingLight(m, c, uw, ud, h, warm)
		L.BD(m, c, 0, h - 1.25, 0, math.min(uw - 4, 14), 0.15, 1.2, warm and C(255, 226, 180) or C(240, 246, 255), M.Neon)
		local a = L.BD(m, c, 0, h - 1.6, 0, 0.2, 0.2, 0.2, C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Range = math.min(28, math.max(uw, ud))
		pl.Brightness = 0.9
		pl.Color = warm and C(255, 224, 186) or C(236, 244, 255)
		pl.Shadows = false
		pl.Parent = a
	end
	local function productBands(m, c, x, z, len, h0, h1, side, alongX)
		local cols = { C(220, 50, 40), C(250, 200, 40), C(40, 110, 200), C(60, 170, 80), C(240, 120, 30), C(236, 236, 230), C(140, 60, 160) }
		local y = h0
		while y < h1 - 0.2 do
			if alongX then
				L.BD(m, c, x, y, z + side * 0.05, len, 0.9, 0.5, L.pick(cols), M.SmoothPlastic)
			else
				L.BD(m, c, x + side * 0.05, y, z, 0.5, 0.9, len, L.pick(cols), M.SmoothPlastic)
			end
			y += 1.5
		end
	end
	function L.interiorKind(name)
		name = string.upper(name or "")
		local function has(t) for _, k in ipairs(t) do if string.find(name, k, 1, true) then return true end end end
		if has({ "BURGER", "WING", "PIZZA", "CHICKEN", "TACO", "FISH", "SEAFOOD", "CAFE", "BAKERY", "CHINESE", "CONCH", "JERK", "FOOD TRUCK", "DINER", "GRILL" }) and not has({ "FOOD MART" }) then return "food" end
		if has({ "BARBER", "BRAID", "BEAUTY", "SALON", "NAILS" }) then return "barber" end
		if has({ "WIRELESS", "PHONE", "CELL" }) then return "phone" end
		if has({ "WASH", "LAUNDR" }) then return "laundry" end
		if has({ "STUDIO", "SOUND", "RECORDS" }) then return "studio" end
		return "store"
	end
	function L.unitInterior(m, c, uw, ud, h, kind, o)
		o = o or {}
		local hz, hx = ud / 2, uw / 2
		h = math.min(h, 15)
		L.BD(m, c, 0, 0.02, 0, uw, 0.12, ud, o.floor or L.pick({ C(206, 200, 188), C(186, 180, 170), C(214, 210, 204) }), M.SmoothPlastic)
		-- smooth painted linings + a drop ceiling so the room doesn't read as the outside stucco
		local lin = o.lining or L.pick({ C(238, 232, 218), C(226, 232, 230), C(240, 236, 228) })
		L.BD(m, c, 0, 0, hz - 0.05, uw, h - 1, 0.1, lin, M.SmoothPlastic)
		L.BD(m, c, -hx + 0.05, 0, 0, 0.1, h - 1, ud, lin, M.SmoothPlastic)
		L.BD(m, c, hx - 0.05, 0, 0, 0.1, h - 1, ud, lin, M.SmoothPlastic)
		L.BD(m, c, 0, h - 1.1, 0, uw, 0.1, ud, C(232, 232, 228), M.SmoothPlastic)
		if kind == "food" then L.BD(m, c, 0, 0, hz - 0.12, uw, 5.6, 0.06, C(246, 246, 242), M.Slate) end
		if kind == "food" then
			local red = o.accent or C(176, 40, 36)
			-- counter with register, kitchen line on the back wall, menu boards above it
			local cz = hz - ud * 0.42
			L.B(m, c, 0, 0, cz, uw * 0.7, 3.4, 2, red, M.SmoothPlastic)
			L.BD(m, c, 0, 3.4, cz, uw * 0.7 + 0.4, 0.2, 2.4, C(226, 226, 220), M.Marble)
			L.BD(m, c, -uw * 0.2, 3.6, cz, 1.4, 1, 1.2, C(30, 30, 32), M.SmoothPlastic)
			for k = -1, 1 do L.B(m, c, k * uw * 0.24, 0, hz - 1.6, uw * 0.22, 3.6, 2.6, STAIN, M.Metal) end
			L.BD(m, c, 0, 7.4, hz - 1.6, uw * 0.72, 2, 3, C(150, 152, 154), M.Metal)
			local menu = L.BD(m, c, 0, 9.6, hz - 0.35, math.min(uw * 0.7, 18), 2.6, 0.1, C(22, 22, 24), M.SmoothPlastic)
			L.text(menu, Enum.NormalId.Front, o.menu or "COMBOS  •  WINGS  •  FRIES  •  SHAKES", { font = Enum.Font.GothamBlack, color = C(255, 206, 60), pps = 20, dist = 90, light = 0, bright = 1.4 })
			-- two tables by the window, stools
			for _, sx in ipairs({ -1, 1 }) do
				local tc = c * CFrame.new(sx * uw * 0.28, 0, -hz + 4)
				L.Cyl(m, 0.2, 3.2, tc * CFrame.new(0, 3, 0), C(230, 230, 226), M.SmoothPlastic)
				L.Cyl(m, 3, 0.4, tc * CFrame.new(0, 1.5, 0), C(60, 60, 62), M.Metal)
				for _, k in ipairs({ -1, 1 }) do L.Cyl(m, 2, 1.4, tc * CFrame.new(k * 2.4, 1, 0), red, M.SmoothPlastic) end
			end
			-- drinks cooler on a side wall
			L.B(m, c, -hx + 1.4, 0, 0, 2.4, 7, 4, C(30, 30, 34), M.Metal)
			productBands(m, c, -hx + 2.65, 0, 3.4, 1, 6.4, 1, false)
		elseif kind == "barber" then
			-- mirror wall + chairs on the left, waiting bench on the right
			L.BD(m, c, -hx + 0.1, 3.2, 0, 0.1, 4.2, ud * 0.7, C(170, 190, 200), M.Glass, nil, { Reflectance = 0.45 })
			L.BD(m, c, -hx + 0.8, 3, 0, 1.4, 0.3, ud * 0.7, C(236, 236, 232), M.Marble)
			local n = math.max(2, math.floor(ud * 0.7 / 6))
			for k = 0, n - 1 do
				local z = -ud * 0.35 + (k + 0.5) * ud * 0.7 / n
				local cc = c * CFrame.new(-hx + 4.2, 0, z) * CFrame.Angles(0, math.pi / 2, 0)
				L.Cyl(m, 1.6, 1.6, cc * CFrame.new(0, 0.8, 0), C(180, 182, 184), M.Metal)
				L.B(m, cc, 0, 1.6, 0, 2.6, 1, 2.4, o.accent or C(150, 30, 30), M.Leather)
				L.B(m, cc, 0, 2.6, 1.1, 2.6, 2.8, 0.5, o.accent or C(150, 30, 30), M.Leather)
			end
			L.B(m, c, hx - 1.6, 0, 0, 2.4, 1.8, ud * 0.5, C(40, 40, 44), M.Leather)
			L.BD(m, c, hx - 0.15, 3.4, 0, 0.1, 3, ud * 0.4, C(30, 30, 32), M.SmoothPlastic)
		elseif kind == "phone" then
			L.BD(m, c, 0, 1, hz - 0.3, uw * 0.8, 7, 0.2, C(236, 236, 232), M.SmoothPlastic)
			productBands(m, c, 0, hz - 0.45, uw * 0.76, 1.6, 7.6, -1, true)
			for _, sx in ipairs({ -1, 1 }) do
				L.B(m, c, sx * uw * 0.22, 0, -ud * 0.05, uw * 0.26, 3.2, 4, C(244, 244, 242), M.SmoothPlastic)
				for k = -1, 1 do L.BD(m, c, sx * uw * 0.22 + k * 1.8, 3.2, -ud * 0.05, 0.9, 0.08, 1.6, C(20, 20, 22), M.Glass) end
			end
			L.B(m, c, 0, 0, hz - ud * 0.35, uw * 0.5, 3.6, 2, C(30, 30, 34), M.SmoothPlastic)
		elseif kind == "studio" then
			-- control room: console + monitors + couch, glass to a vocal booth at the back
			L.BD(m, c, 0, 0.14, 0, uw - 1, 0.1, ud - 1, C(60, 44, 36), M.Fabric)
			L.B(m, c, 0, 0, hz - ud * 0.42, uw * 0.6, 3.2, 3.4, C(30, 30, 34), M.SmoothPlastic)
			L.P(m, Vector3.new(uw * 0.58, 0.4, 3.2), c * CFrame.new(0, 3.4, hz - ud * 0.42) * CFrame.Angles(math.rad(12), 0, 0), C(50, 52, 58), M.SmoothPlastic)
			for _, sd in ipairs({ -1, 1 }) do
				L.B(m, c, sd * uw * 0.36, 0, hz - ud * 0.42, 2.4, 6, 2.2, C(24, 24, 26), M.SmoothPlastic)
				L.Cyl(m, 0.1, 1.6, c * CFrame.new(sd * uw * 0.36, 4.4, hz - ud * 0.42 - 1.15) * CFrame.Angles(math.pi / 2, 0, 0), C(80, 80, 84), M.Metal)
			end
			for k = -1, 1 do L.BD(m, c, k * 3.4, 3.8, hz - ud * 0.42 + 1.4, 3, 2, 0.2, C(20, 24, 30), M.Glass) end
			L.B(m, c, 0, 0, hz - ud * 0.2, uw - 2, 8, 0.6, C(120, 150, 170), M.Glass, nil, { Transparency = 0.5 })
			L.Cyl(m, 5, 0.3, c * CFrame.new(0, 2.5, hz - ud * 0.1), C(60, 60, 64), M.Metal)
			L.BD(m, c, 0, 5, hz - ud * 0.1 - 0.4, 1.2, 1.2, 0.2, C(40, 40, 44), M.Metal)
			L.B(m, c, -hx + 2, 0, -ud * 0.15, 3, 2.4, ud * 0.3, C(110, 40, 40), M.Leather)
			L.BD(m, c, hx - 0.15, 3, 0, 0.1, 5, ud * 0.4, C(200, 160, 40), M.SmoothPlastic)
			for k = -1, 1 do L.BD(m, c, hx - 0.3, 4.4, k * 4, 0.1, 2.6, 2.6, C(220, 200, 120), M.Metal) end
		elseif kind == "laundry" then
			local n = math.max(3, math.floor((ud - 6) / 3.4))
			for k = 0, n - 1 do
				local z = -hz + 4 + k * 3.4
				L.B(m, c, -hx + 1.8, 0, z, 3, 3.6, 3.1, C(236, 236, 232), M.SmoothPlastic)
				L.Cyl(m, 0.08, 2.2, c * CFrame.new(-hx + 3.32, 2, z) * CFrame.Angles(0, 0, math.pi / 2), C(40, 44, 50), M.Glass)
				L.B(m, c, hx - 1.8, 0, z, 3, 7, 3.1, C(214, 216, 218), M.Metal)
				for _, y in ipairs({ 1.8, 5.2 }) do L.Cyl(m, 0.08, 2.2, c * CFrame.new(hx - 3.32, y, z) * CFrame.Angles(0, 0, math.pi / 2), C(40, 44, 50), M.Glass) end
			end
			L.B(m, c, 0, 0, 0, 3, 3, ud * 0.5, C(200, 196, 186), M.SmoothPlastic)
		else
			-- corner store: gondola aisles, cooler wall at the back, counter by the door with a plexi screen
			local na = math.max(1, math.floor((uw - 8) / 7))
			for k = 0, na - 1 do
				local x = -uw / 2 + 4 + (k + 0.5) * (uw - 8) / na
				local len = ud * 0.5
				L.B(m, c, x, 0, ud * 0.02, 1.4, 5.2, len, C(214, 214, 210), M.Metal)
				productBands(m, c, x - 0.75, ud * 0.02, len - 0.6, 1, 5, -1, false)
				productBands(m, c, x + 0.75, ud * 0.02, len - 0.6, 1, 5, 1, false)
			end
			L.B(m, c, 0, 0, hz - 1.4, uw - 2, 7.6, 2.4, C(32, 32, 36), M.Metal)
			productBands(m, c, 0, hz - 2.65, uw - 3, 1, 7, -1, true)
			L.BD(m, c, 0, 1, hz - 3.05, uw - 2.6, 6.6, 0.1, C(200, 220, 230), M.Glass, nil, { Transparency = 0.6 })
			L.BD(m, c, 0, 7.4, hz - 3.1, uw - 2.6, 0.15, 0.15, C(220, 240, 255), M.Neon)
			local cx = hx - 4
			L.B(m, c, cx, 0, -hz + 6, 6, 3.6, 2.4, o.accent or C(120, 84, 52), M.Wood)
			L.BD(m, c, cx, 3.6, -hz + 6, 6, 3.4, 0.1, C(220, 230, 236), M.Glass, nil, { Transparency = 0.55 })
			L.BD(m, c, cx + 1.4, 3.6, -hz + 6.4, 1.2, 0.9, 1, C(30, 30, 32), M.SmoothPlastic)
		end
		ceilingLight(m, c, uw, ud, h, kind == "food" or kind == "barber")
	end

	-- ===== single-family CBS house =====
	function L.house(par, cf, w, d, o)
		o = o or {}
		local abandoned = o.abandoned or (o.rundown ~= false and L.chance(0.07))
		local m = Instance.new("Model")
		m.Name = o.name or "House"
		local rundown = o.rundown ~= false
		local col = o.color or L.jitter(L.pick(L.HOOD_COLS), 0.04)
		-- one-storey CBS ranch or a two-storey duplex (the references are full of both)
		local storeys = o.storeys or (L.chance(o.twoChance or 0.35) and 2 or 1)
		local h = storeys == 2 and L.r(20.5, 22) or L.r(12, 13.2)
		local bw = math.min(w - 14, L.r(26, 34))
		local bd = math.min(d - 16, L.r(26, 34))
		local bx = -w / 2 + 3 + bw / 2
		local bz = -d / 2 + L.r(10, 14) + bd / 2
		local fz = bz - bd / 2
		local body = wall(m, cf, bx, 0, bz, bw, h, bd, col, nil, rundown)
		-- slab porch + steps
		L.B(m, cf, bx, 0, fz - 3, bw * 0.55, 0.6, 6, C(180, 176, 168), M.Concrete, "LotConcreteWorn")
		-- roof: flat w/ parapet, or low hip barrel tile / shingle
		if L.chance(0.5) then
			parapet(m, cf, bx, bz, bw + 0.4, bd + 0.4, h, L.shade(col, 0.9))
			rooftop(m, cf, bx, bz, bw, bd, h)
		else
			local rh = L.r(4, 5.5)
			local tile = L.chance(0.55)
			local rc = tile and L.pick({ C(168, 96, 70), C(150, 86, 64), C(186, 120, 90) }) or L.pick({ C(92, 104, 118), C(110, 106, 100), C(120, 124, 128), C(84, 90, 98), C(140, 136, 130) })
			local rv = tile and "RoofClayMission" or "RoofShinglesGrey"
			L.W(m, Vector3.new(bw + 2, rh, bd / 2 + 1), cf * CFrame.new(bx, h + rh / 2, bz - bd / 4 - 0.5), rc, tile and M.ClayRoofTiles or M.Slate, rv)
			L.W(m, Vector3.new(bw + 2, rh, bd / 2 + 1), cf * CFrame.new(bx, h + rh / 2, bz + bd / 4 + 0.5) * CFrame.Angles(0, math.pi, 0), rc, tile and M.ClayRoofTiles or M.Slate, rv)
			L.BD(m, cf, bx, h - 0.6, bz, bw + 2.2, 0.6, bd + 2.2, C(236, 234, 228), M.Wood)
			-- gable ends in the wall colour (the roof edge reads as a rake board) + a louvred vent
			for _, sx in ipairs({ -1, 1 }) do
				local gx = bx + sx * (bw / 2 + 1.04)
				L.W(m, Vector3.new(0.12, rh - 0.6, bd / 2), cf * CFrame.new(gx, h + (rh - 0.6) / 2, bz - bd / 4), col, M.Plaster, nil, { CanCollide = false, CastShadow = false })
				L.W(m, Vector3.new(0.12, rh - 0.6, bd / 2), cf * CFrame.new(gx, h + (rh - 0.6) / 2, bz + bd / 4) * CFrame.Angles(0, math.pi, 0), col, M.Plaster, nil, { CanCollide = false, CastShadow = false })
			end
			L.BD(m, cf, bx + bw / 2 + 1.12, h + rh * 0.3, bz, 0.1, 1.4, 1.8, C(236, 234, 228), M.Wood)
		end
		-- Florida room / front wing that breaks the box (L-shaped plan)
		local wing = L.chance(0.35) and bw > 24
		if wing then
			local ww, wd = bw * 0.4, 14
			local wx = bx - bw / 2 + ww / 2
			local wz = fz - 8 + wd / 2
			local wcol = L.chance(0.5) and col or L.shade(col, 0.94)
			L.B(m, cf, wx, 0, wz, ww, h - 1, wd, wcol, M.Plaster, L.pick(L.WALLVARS))
			L.BD(m, cf, wx, 0, wz - wd / 2 - 0.02, ww + 0.04, 1.2, 0.06, L.shade(wcol, 0.72), M.Plaster)
			L.BD(m, cf, wx, h - 1, wz, ww + 0.6, 0.6, wd + 0.6, C(232, 230, 222), M.Concrete)
			L.win(m, cf, wx, 3.4, wz - wd / 2, math.min(ww - 3, 8), 4.2, { bars = rundown and L.chance(0.7), jalousie = L.chance(0.6), shade = L.chance(0.4) })
		end
		-- front: door + 2 barred windows, aluminium awning over door
		door(m, cf, bx, 0.6, fz, 3.6, 7.2, nil, rundown and L.chance(0.7))
		for _, sx in ipairs({ -1, 1 }) do
			if not (wing and sx == -1) then
				L.win(m, cf, bx + sx * bw / 3.1, 3.6, fz, 5, 4.2, { bars = rundown and L.chance(0.85), shade = L.chance(0.4), jalousie = L.chance(0.35), ac = (not abandoned) and L.chance(0.3), boarded = abandoned or (rundown and L.chance(0.05)) })
			end
		end
		L.sideWindows(m, cf, bx, bz, bw, bd, 3.6, storeys, 10, { chance = 0.6 })
		if not abandoned and L.chance(0.45) then L.wallAC(m, cf, bx, -1, bw, bz + bd / 5, 4.4, col) end
		if storeys == 2 then
			L.BD(m, cf, bx, 11.2, fz - 0.25, bw + 0.2, 0.5, 0.5, L.shade(col, 1.08), M.Concrete)
			for k = -1, 1 do
				L.win(m, cf, bx + k * bw / 3.2, 13.6, fz, 4.6, 4.4, { bars = rundown and L.chance(0.7), shade = L.chance(0.5), jalousie = L.chance(0.3), boarded = abandoned or (rundown and L.chance(0.05)) })
			end
			if not abandoned and L.chance(0.6) then L.facadeAC(m, cf, bx + bw / 6.4, 14.2, fz) end
		end
		if L.chance(0.35) and not abandoned then
			-- porch roof on two square columns
			local pw = bw * 0.38
			L.BD(m, cf, bx + bw * 0.08, 8.8, fz - 3.4, pw, 0.5, 6.8, C(236, 234, 228), M.Concrete)
			for _, sx in ipairs({ -1, 1 }) do L.B(m, cf, bx + bw * 0.08 + sx * (pw / 2 - 0.6), 0.6, fz - 6.2, 0.8, 8.2, 0.8, C(236, 234, 228), M.Concrete) end
		elseif L.chance(0.6) then
			local ac = L.pick({ C(236, 236, 230), C(40, 90, 60), C(170, 40, 40), C(40, 60, 110) })
			L.P(m, Vector3.new(7, 0.25, 4), cf * CFrame.new(bx, 8.9, fz - 2) * CFrame.Angles(math.rad(-12), 0, 0), ac, M.Metal)
		end
		-- wall AC on the side + electric meter
		L.B(m, cf, bx + bw / 2 + 1.3, 0, bz + bd / 4, 2.6, 2.6, 3.4, C(198, 198, 194), M.Metal)
		L.BD(m, cf, bx - bw / 2 - 0.3, 4, bz - bd / 4, 0.4, 1.6, 1.1, C(160, 160, 158), M.Metal)
		-- yard ground
		L.BD(m, cf, 0, 0.02, 0, w - 1, 0.08, d - 1, rundown and C(124, 116, 92) or C(96, 120, 64), rundown and M.Ground or M.LeafyGrass)
		-- driveway + car
		local dx = bx + bw / 2 + 6.5
		if dx + 5 < w / 2 + 0.5 then
			local dl = bz + bd / 2 + d / 2
			L.BD(m, cf, dx, 0.03, -d / 2 + dl / 2, 10, 0.15, dl, C(170, 166, 158), M.Concrete, "ConcreteDriveway")
			local carport = (not abandoned) and L.chance(0.35)
			if carport then
				-- aluminium carport off the side of the house: two posts, flat roof, fascia
				local cz0, cz1 = fz - 2, fz + 18
				local czc = (cz0 + cz1) / 2
				for _, z in ipairs({ cz0 + 0.6, cz1 - 0.6 }) do L.B(m, cf, dx + 4.6, 0, z, 0.5, 8.6, 0.5, C(230, 230, 226), M.Metal) end
				L.B(m, cf, dx - 0.3, 8.6, czc, 10.8, 0.3, cz1 - cz0, L.pick({ C(236, 236, 232), C(200, 204, 206), C(120, 120, 118) }), M.Metal)
				L.BD(m, cf, dx + 4.95, 8.3, czc, 0.2, 0.7, cz1 - cz0, C(236, 236, 232), M.Metal)
				if L.chance(o.carChance or 0.55) then
					L.car(m, cf * CFrame.new(dx, 0.15, czc) * CFrame.Angles(0, L.chance(0.7) and 0 or math.pi, 0))
				end
			elseif L.chance(o.carChance or 0.55) then
				L.car(m, cf * CFrame.new(dx, 0.15, -d / 2 + 11) * CFrame.Angles(0, L.chance(0.5) and 0 or math.pi, 0))
			end
		end
		-- satellite dish on the roof edge
		if L.chance(0.3) then
			L.Cyl(m, 0.25, 2.4, cf * CFrame.new(bx + bw / 2 - 2, h + 1.4, fz + 3) * CFrame.Angles(0.5, 0.4, 0), C(226, 226, 222), M.SmoothPlastic)
			L.BD(m, cf, bx + bw / 2 - 2, h - 0.2, fz + 3.4, 0.2, 1.6, 0.2, C(120, 120, 118), M.Metal)
		end
		-- fence across the front: chain-link (hood) / low CMU wall / iron
		local fk = rundown and L.pick({ "chain", "chain", "chain", "wall", "iron" }) or L.pick({ "wall", "iron", "none" })
		if fk ~= "none" then
			local x1 = (dx + 5 < w / 2) and (dx - 5.5) or w / 2 - 1
			L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(x1, 0, -d / 2 + 1)).Position, fk == "wall" and 3.5 or 4.5, fk)
			if rundown and L.chance(0.5) then
				L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(-w / 2 + 1, 0, d / 2 - 1)).Position, 4.5, "chain")
			end
		end
		-- garbage cans at the curb, a mango / palm tree
		if L.chance(0.6) then
			for k = 0, L.ri(0, 1) do
				L.B(m, cf, w / 2 - 3 - k * 2.6, 0, -d / 2 + 2.5, 2.2, 3.4, 2.2, L.pick({ C(40, 70, 50), C(40, 40, 44), C(30, 60, 120) }), M.Plastic)
			end
		end
		if L.chance(0.45) then L.tree(m, (cf * CFrame.new(bx - bw / 4, 0, -d / 2 + 6)).Position, L.r(0.7, 1)) end
		if L.chance(0.25) then L.palm(m, (cf * CFrame.new(-w / 2 + 3, 0, d / 2 - 4)).Position, L.r(22, 30)) end
		if rundown and L.chance(o.tagChance or 0.15) then L.graffiti(body, Enum.NormalId.Right) end
		-- overgrown verge + yard: tall grass clumps along the fence line
		if rundown and L.chance(0.5) then
			for _ = 1, L.ri(2, 4) do L.weeds(m, (cf * CFrame.new(L.r(-w / 2 + 2, w / 2 - 2), 0, -d / 2 + L.r(2, 5))).Position) end
		end
		if rundown and L.grime then L.grime(m, cf, bx, bz, bw, bd, h, { pitched = (m:FindFirstChildWhichIsA("WedgePart") ~= nil), flat = (m:FindFirstChildWhichIsA("WedgePart") == nil) }) end
		if abandoned then
			m.Name = "AbandonedHouse"
			L.graffiti(body, Enum.NormalId.Front)
			for _ = 1, L.ri(4, 8) do L.weeds(m, (cf * CFrame.new(L.r(-w / 2.3, w / 2.3), 0, L.r(-d / 2.3, d / 2.3))).Position) end
			for _ = 1, L.ri(1, 3) do L.bush(m, (cf * CFrame.new(L.r(-w / 2.5, w / 2.5), 0, L.r(-d / 2.5, -d / 4))).Position, L.r(3, 6)) end
			L.trashBags(m, (cf * CFrame.new(L.r(-w / 4, w / 4), 0, -d / 2 + 4)).Position)
		end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== strip of storefronts (1-2 storey) =====
	-- o.interior = true: hollow shell + low-poly interior per unit (job / POI shops only - keeps the hood light)
	function L.shop(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "Shops"
		local rundown = o.rundown ~= false
		local floors = o.floors or (L.chance(0.3) and 2 or 1)
		local h = (floors == 1 and L.r(15, 17)) or (floors == 2 and L.r(24, 26)) or (9.4 * floors + 6)
		local col = o.color or L.jitter(L.pick(L.HOOD_COLS), 0.04)
		local bd = math.min(d - 3, L.r(32, 44))
		local bz = -d / 2 + 2 + bd / 2
		local fz = bz - bd / 2
		local brick = (not o.interior) and L.chance(0.2)
		local n = o.units or math.max(1, math.floor(w / L.r(16, 22)))
		local uw = w / n
		local body, S
		if o.interior then
			-- one storefront opening per unit (glass from 0.6 to 9.2), party walls between units
			local gaps = {}
			for k = 0, n - 1 do
				local x = -w / 2 + uw * (k + 0.5)
				table.insert(gaps, { x - (uw - 3) / 2, x + (uw - 3) / 2, 9.2 })
			end
			S = L.shell(m, cf, 0, bz, w, bd, h, col, nil, gaps)
			body = S.front
			for k = 1, n - 1 do L.B(m, cf, -w / 2 + uw * k, 0, bz + 0.5, 0.6, h - 1, bd - 1, L.shade(col, 0.9), M.Plaster) end
			L.BD(m, cf, 0, 0.02, bz, w - 1, 0.1, bd - 1, C(170, 170, 166), M.Concrete)
		elseif brick then
			body = L.B(m, cf, 0, 0, bz, w, h, bd, L.pick({ C(140, 96, 80), C(176, 166, 150), C(156, 116, 96) }), M.Brick)
			L.BD(m, cf, 0, 0, bz, w + 0.5, 2, bd + 0.5, C(96, 90, 84), M.Concrete)
			L.grimeBox(m, body, fz - 0.25, cf, 0, 0, w, h, rundown)
		else
			body = wall(m, cf, 0, 0, bz, w, h, bd, col, nil, rundown)
		end
		local function face(f)
			if not S then return body end
			if f == Enum.NormalId.Left then return S.left elseif f == Enum.NormalId.Right then return S.right elseif f == Enum.NormalId.Back then return S.back end
			return S.front
		end
		parapet(m, cf, 0, bz, w + 0.4, bd + 0.4, h, L.shade(col, 0.85))
		L.falseFront(m, cf, 0, fz, w, h, col, o.front)
		rooftop(m, cf, 0, bz, w, bd, h)
		-- units
		for k = 0, n - 1 do
			local x = -w / 2 + uw * (k + 0.5)
			-- pilasters between units
			if k > 0 then L.B(m, cf, -w / 2 + uw * k, 0, fz - 0.35, 1.2, h - 1, 0.7, L.shade(col, 0.92), M.Plaster) end
			-- painted CMU / brick base (blue-grey) under the stucco, rust streak band above the shutters
			if rundown and not o.interior and L.chance(0.55) then
				L.B(m, cf, x, 0, fz - 0.15, uw - 0.4, 10.6, 0.3, L.pick({ C(92, 100, 122), C(110, 118, 130), C(120, 96, 110), C(86, 104, 96) }), M.Concrete, L.pick({ "HoodCinderBlock", "CinderBlockB", "HoodPaintedBrick" }))
			end
			if rundown and L.chance(0.6) then
				L.BD(m, cf, x, 9.6, fz - 0.42, uw - 1.2, 1.4, 0.12, C(112, 66, 44), M.CorrodedMetal, "RustCoarse")
			end
			-- glass storefront + door (see-through and walk-in when the unit has an interior)
			local gz = o.interior and 0.5 or -0.1
			local glass
			if o.interior then
				glass = L.B(m, cf, x - 2.2, 0.6, fz + gz, uw - 7.4, 8.6, 0.25, C(150, 170, 180), M.Glass, nil, { Reflectance = 0.08, Transparency = 0.6 })
				L.BD(m, cf, x + uw / 2 - 4, 8.4, fz + gz, 3.6, 0.8, 0.25, C(150, 170, 180), M.Glass, nil, { Transparency = 0.6 })
			else
				glass = L.BD(m, cf, x, 0.6, fz + gz, uw - 3, 8.6, 0.25, GLASS, M.Glass, nil, { Reflectance = 0.2 })
			end
			glass.Name = "Storefront"
			for _, mx in ipairs({ -(uw - 3) / 2, (uw - 3) / 2, uw / 2 - 5.9 }) do L.BD(m, cf, x + mx, 0.6, fz + gz - 0.15, 0.3, 8.6, 0.4, C(60, 62, 66), M.Metal) end
			L.BD(m, cf, x, 0, fz - 0.3, uw - 2.4, 0.7, 0.4, L.shade(col, 0.7), M.Concrete)
			local dr = L.BD(m, cf, x + uw / 2 - 4, 0.6, fz + gz - 0.25, 3.6, 7.8, 0.25, o.interior and C(150, 170, 180) or C(52, 52, 56), o.interior and M.Glass or M.Metal, nil, o.interior and { Transparency = 0.5 } or nil)
			dr.Name = "Door"
			L.BD(m, cf, x + uw / 2 - 5.4, 3.6, fz - 0.05, 0.15, 1.4, 0.2, C(200, 200, 196), M.Metal)
			L.wallPack(m, cf, x + uw / 2 - 4, 9.6, fz)
			-- roll-down shutter (half/closed) or bars - never fully closed on a working shop
			local shutter = rundown and L.chance(0.55)
			if shutter then
				local closed = (not o.interior) and L.chance(0.45)
				local sh = closed and 8.6 or L.r(1.4, 2.6)
				local sp = L.B(m, cf, x, 9.2 - sh, fz - 0.5, uw - 2.6, sh, 0.3, L.pick({ C(140, 142, 142), C(128, 134, 130), C(120, 128, 134), C(150, 146, 138) }), M.Metal)
				if L.villaStripes then L.villaStripes(sp, Enum.NormalId.Front, math.floor(sh * 2.2), C(70, 72, 74), 0.55, false) end
				L.decal(sp, Enum.NormalId.Front, L.GRIME.streaks, 0.35)
				sp.CanCollide = false
				if closed and L.chance(0.6) then L.graffiti(sp, Enum.NormalId.Front) end
				L.BD(m, cf, x, 9.1, fz - 0.6, uw - 2.2, 0.8, 0.9, C(110, 110, 110), M.Metal)
				shutter = closed
			elseif rundown and not o.interior then
				for b2 = 0, math.floor((uw - 3) / 1.1) do
					L.BD(m, cf, x - (uw - 3) / 2 + b2 * 1.1, 0.7, fz - 0.45, 0.14, 8.2, 0.14, INK, M.Metal)
				end
			end
			-- sign band + sign
			local sc = L.pick(L.SIGN_COLS)
			local name = (o.signs and o.signs[k + 1]) or (k == 0 and o.sign) or L.pick(L.SHOP_NAMES)
			if L.storeSign then
				L.storeSign(m, cf * CFrame.new(x, 11.8, fz - 0.4), uw - 2.4, name, { rundown = rundown, pal = sc, h = floors == 1 and 3.2 or 3.6 })
			else
				L.sign(m, cf * CFrame.new(x, 11.6, fz - 0.4), math.min(uw - 2.4, #name * 1.9 + 5), 2.8, name, sc[1], sc[2], Enum.Font.GothamBlack, { light = 0.8 })
			end
			-- awning
			if L.chance(0.45) then
				local ac = L.pick({ C(180, 30, 30), C(30, 90, 50), C(30, 50, 110), C(220, 160, 30), C(60, 60, 60), C(240, 240, 236) })
				L.P(m, Vector3.new(uw - 2, 0.35, 4.6), cf * CFrame.new(x, 10.1, fz - 2.2) * CFrame.Angles(math.rad(-16), 0, 0), ac, M.Fabric)
			end
			if not shutter and L.storeWindow then L.storeWindow(m, cf * CFrame.new(x, 0, fz + gz - 0.15), uw - 3, { rundown = rundown }) end
			if o.interior then
				L.unitInterior(m, cf * CFrame.new(x, 0, bz + 0.5), uw - 1.6, bd - 3, h, L.interiorKind(name), { menu = o.menu, accent = o.accent })
			end
		end
		-- upper floor windows (flats above shops)
		for f = 2, floors do
			local wn = math.max(2, math.floor(w / 11))
			local y = 15.6 + (f - 2) * 9.4
			for k = 0, wn - 1 do
				local x = -w / 2 + (k + 0.5) * w / wn
				L.win(m, cf, x, y, fz, 4.4, 4.8, { bars = rundown and L.chance(0.6), shade = L.chance(0.45), ac = L.chance(0.25), jalousie = L.chance(0.3), boarded = rundown and L.chance(0.08) })
				if k < wn - 1 and L.chance(0.35) then L.facadeAC(m, cf, x + w / wn / 2, y + 0.6, fz) end
			end
			-- floor line band between storeys
			L.BD(m, cf, 0, y - 1.6, fz - 0.25, w + 0.2, 0.5, 0.5, L.shade(col, 1.08), M.Concrete)
		end
		if floors > 1 then L.sideWindows(m, cf, 0, bz, w, bd, 15.6 - 9.4, floors, 9.4, { noGround = true, chance = 0.6 }) end
		-- side walls: AC units with drip stains, meter bank + conduit, painted ad
		local sideA = L.chance(0.5) and -1 or 1
		for _ = 1, L.ri(1, 2) do L.wallAC(m, cf, 0, sideA, w, bz + L.r(-bd / 3, bd / 3), L.r(6.5, 9), col) end
		L.meterBank(m, cf, 0, -sideA, w, bz + bd / 2 - 5, h)
		local sideFace = sideA == -1 and Enum.NormalId.Right or Enum.NormalId.Left
		if L.chance(o.adChance or 0.4) then L.sideAd(face(sideFace), sideFace) end
		-- rooftop billboard on the arterials
		if o.billboard or (o.billboard == nil and w >= 44 and L.chance(0.16)) then
			L.roofBillboard(m, cf, L.r(-w / 6, w / 6), bz + bd * 0.15, h, 0)
		end
		-- tags + pieces on the side / back walls
		if rundown and L.chance(0.7) then L.graffiti(face(sideFace), sideFace) end
		if rundown and L.chance(0.45) then L.graffiti(face(Enum.NormalId.Back), Enum.NormalId.Back) end
		if rundown and L.chance(0.5) then local f = L.pick({ Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back }) L.piece(face(f), f) end
		if L.chance(0.5) then L.dumpster(m, cf * CFrame.new(L.r(-w / 3, w / 3), 0, bz + bd / 2 + 3)) end
		-- forecourt
		L.BD(m, cf, 0, 0.02, -d / 2 + (d - bd - 2) / 2 + 0.5, w, 0.1, math.max(1, d - bd - 2), C(166, 162, 154), M.Concrete, "ParkingLotStained")
		if rundown and L.grime then L.grime(m, cf, 0, bz, w, bd, h, { flat = true, yard = false }) end
		m.Parent = par
		L.lod(m)
		return m, body
	end

	-- ===== Miami garden walk-up (exterior catwalks + stair) =====
	function L.walkup(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "Apartments"
		local rundown = o.rundown ~= false
		local floors = o.floors or L.ri(3, 4)
		local fh = 10.5
		local h = floors * fh + 1
		local col = o.color or L.jitter(L.pick(L.HOOD_COLS), 0.04)
		local bd = math.min(d - 14, L.r(28, 36))
		local bw = w - 8
		local bz = -d / 2 + 12 + bd / 2
		local fz = bz - bd / 2
		local body = wall(m, cf, 0, 0, bz, bw, h, bd, col, nil, rundown)
		parapet(m, cf, 0, bz, bw + 0.4, bd + 0.4, h, L.shade(col, 0.85))
		rooftop(m, cf, 0, bz, bw, bd, h)
		-- painted accent band per floor (Miami Modern)
		local accent = L.pick({ C(222, 220, 212), C(96, 110, 120), C(122, 80, 70), C(86, 104, 94) })
		-- raised parapet panel with the building's script name (60s Miami garden apartments)
		L.falseFront(m, cf, 0, fz, bw, h, col, "raise")
		do
			local rw = math.min(bw * 0.5, 28)
			local nm = L.D(m, Vector3.new(rw - 1, 2.3, 0.1), cf * CFrame.new(0, h + 2.9, fz - 0.26), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
			L.text(nm, Enum.NormalId.Front, o.aptName or L.pick({ "Palm Court", "Sunrise Apts", "Liberty Gardens", "Coral Arms", "Biscayne Villas", "Tropicana", "Sea Breeze", "Flamingo Apts", "Royal Palms", "Bay Vista" }), {
				font = L.pick({ Enum.Font.Kalam, Enum.Font.Fondamento, Enum.Font.Oswald }), color = accent == C(240, 240, 236) and C(40, 90, 120) or accent,
				stroke = 0.6, strokeColor = C(255, 255, 255), pps = 12, dist = 300, light = 1 })
		end
		local units = math.max(2, math.floor(bw / 13))
		for f = 0, floors - 1 do
			if f > 0 then
				-- catwalk slab + railing
				L.B(m, cf, 0, f * fh - 0.6, fz - 2.6, bw, 0.6, 5.2, C(184, 180, 172), M.Concrete, "LotConcreteWorn")
				L.BD(m, cf, 0, f * fh, fz - 5.1, bw, 3.2, 0.2, accent, M.Metal, nil, { Transparency = 0.25 })
				L.BD(m, cf, 0, f * fh + 3.1, fz - 5.1, bw, 0.3, 0.3, accent, M.Metal)
			end
			for k = 0, units - 1 do
				local x = -bw / 2 + (k + 0.5) * bw / units
				door(m, cf, x - 3, f * fh + 0.05, fz, 3.4, 7.2, nil, rundown and L.chance(0.5))
				L.win(m, cf, x + 2.6, f * fh + 3.4, fz, 4.4, 3.8, { bars = rundown and f == 0, shade = L.chance(0.45), jalousie = L.chance(0.5), ac = L.chance(0.35), boarded = rundown and L.chance(0.04) })
			end
		end
		L.sideWindows(m, cf, 0, bz, bw, bd, 3.4, floors, fh, { skipSide = 1, chance = 0.7 })
		-- open stair at one end
		local sx = bw / 2 + 2.5
		for f = 0, floors - 2 do
			L.W(m, Vector3.new(4, fh, 12), cf * CFrame.new(sx, f * fh + fh / 2, fz + 6) * CFrame.Angles(0, math.pi, 0), C(160, 158, 152), M.Concrete, "LotConcreteWorn")
			L.bar(m, (cf * CFrame.new(sx + 2.1, f * fh + 3.2, fz + 12)).Position, (cf * CFrame.new(sx + 2.1, (f + 1) * fh + 3.2, fz)).Position, 0.25, accent, M.Metal)
			L.B(m, cf, sx, (f + 1) * fh - 0.6, fz - 2.6, 4, 0.6, 5.2, C(184, 180, 172), M.Concrete)
		end
		-- laundry line, satellite dishes, parking at front
		if L.chance(0.4) then
			for k = 1, 3 do
				L.BD(m, cf, L.r(-bw / 3, bw / 3), fh + L.r(1, 2.5), fz - 4.8, L.r(1, 1.8), L.r(1.4, 2.4), 0.05, L.pick({ C(240, 240, 236), C(200, 60, 60), C(60, 100, 200), C(250, 210, 60) }), M.Fabric)
			end
		end
		if L.chance(0.5) then
			L.Cyl(m, 0.25, 2.6, cf * CFrame.new(-bw / 2 + 2, h + 1.6, fz + 1.4) * CFrame.Angles(0.5, 0.3, 0), C(228, 228, 226), M.SmoothPlastic)
		end
		L.BD(m, cf, 0, 0.03, -d / 2 + 6, w - 2, 0.12, 11, C(110, 110, 112), M.Asphalt, "ParkingLotAsphalt")
		for k = 1, L.ri(0, 2) do
			L.car(m, cf * CFrame.new(L.r(-bw / 2.5, bw / 2.5), 0.15, -d / 2 + 6) * CFrame.Angles(0, math.pi / 2 + (L.chance(0.5) and math.pi or 0), 0))
		end
		if L.chance(0.6) then
			L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, 4.5, rundown and "chain" or "iron")
		end
		if rundown and L.chance(0.4) then L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right })) end
		if L.chance(0.4) then L.palm(m, (cf * CFrame.new(-w / 2 + 3, 0, -d / 2 + 13)).Position) end
		if rundown and L.grime then L.grime(m, cf, 0, bz, bw, bd, h, { flat = true }) end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== hood mid-rise: 4-5 storey stucco / painted-brick apartment block (Liberty City style) =====
	function L.midrise(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "MidRise"
		local floors = o.floors or L.ri(4, 5)
		local fh = 10
		local h = floors * fh + 2
		local brick = L.chance(0.4)
		local col = brick and L.pick({ C(140, 96, 80), C(156, 116, 96), C(120, 86, 72) }) or L.jitter(L.pick(L.HOOD_COLS), 0.04)
		local bw = w - 6
		local bd = math.min(d - 12, L.r(34, 44))
		local bz = -d / 2 + 10 + bd / 2
		local fz = bz - bd / 2
		local body
		if brick then
			body = L.B(m, cf, 0, 0, bz, bw, h, bd, col, M.Brick)
			L.grimeBox(m, body, fz - 0.25, cf, 0, 0, bw, h, true)
			L.BD(m, cf, 0, 0, fz - 0.02, bw + 0.04, 1.2, 0.06, L.shade(col, 0.7), M.Brick)
		else
			body = wall(m, cf, 0, 0, bz, bw, h, bd, col)
		end
		parapet(m, cf, 0, bz, bw + 0.4, bd + 0.4, h, L.shade(col, 0.85))
		L.falseFront(m, cf, 0, fz, bw, h, col, L.pick({ "cornice", "flat", "band" }))
		-- ground floor: entrance with canopy + a couple of barred windows / a corner shop unit
		door(m, cf, 0, 0.6, fz, 5, 8, C(60, 64, 70), true)
		L.BD(m, cf, 0, 9.4, fz - 2.4, 12, 0.5, 5, C(40, 42, 46), M.Metal)
		local nm = L.D(m, Vector3.new(11, 1.2, 0.1), cf * CFrame.new(0, 10.4, fz - 4.9), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(nm, Enum.NormalId.Front, o.aptName or L.pick({ "LIBERTY TOWERS", "PALM GARDENS", "THE HARRIS", "SUNSET ARMS", "BAYVIEW APTS", "MLK PLAZA" }), { font = Enum.Font.GothamBold, color = C(240, 240, 236), pps = 20, dist = 160 })
		local wn = math.max(3, math.floor(bw / 13))
		for f = 0, floors - 1 do
			local y = f * fh + 3.2
			for k = 0, wn - 1 do
				local x = -bw / 2 + (k + 0.5) * bw / wn
				if not (f == 0 and math.abs(x) < 8) then
					L.win(m, cf, x, y, fz, 5, 4.8, { bars = (f <= 1) or L.chance(0.3), shade = L.chance(0.5), boarded = L.chance(0.04) })
					if f > 0 and L.chance(0.28) then L.facadeAC(m, cf, x + bw / wn / 2, y + 0.4, fz) end
				end
			end
			if f > 0 then L.BD(m, cf, 0, f * fh + 0.6, fz - 0.25, bw + 0.2, 0.45, 0.5, L.shade(col, brick and 1.25 or 1.08), M.Concrete) end
		end
		-- steel fire escape on one side wall
		local sx = L.chance(0.5) and -1 or 1
		for f = 1, floors - 1 do
			L.BD(m, cf, sx * (bw / 2 + 2), f * fh, bz - bd / 4, 4, 0.3, 12, C(46, 48, 52), M.Metal)
			L.BD(m, cf, sx * (bw / 2 + 3.9), f * fh, bz - bd / 4, 0.2, 3, 12, C(46, 48, 52), M.Metal)
			L.bar(m, (cf * CFrame.new(sx * (bw / 2 + 2), (f - 1) * fh + 0.3, bz - bd / 4 + 5)).Position, (cf * CFrame.new(sx * (bw / 2 + 2), f * fh, bz - bd / 4 - 5)).Position, 0.3, C(46, 48, 52), M.Metal)
		end
		L.sideWindows(m, cf, 0, bz, bw, bd, 3.2, floors, fh, { chance = 0.7 })
		L.wallAC(m, cf, 0, -sx, bw, bz, 8, col)
		L.meterBank(m, cf, 0, -sx, bw, bz + bd / 2 - 5, h)
		-- roof: water tank / units, sometimes a billboard
		L.Cyl(m, 7, 7, cf * CFrame.new(L.r(-bw / 4, bw / 4), h + 3.5 + 4, bz + bd / 4), C(130, 100, 70), M.WoodPlanks)
		for k = -1, 1, 2 do L.B(m, cf, L.r(-bw / 4, bw / 4) + k * 2, h, bz + bd / 4, 0.5, 4, 0.5, C(60, 60, 62), M.Metal) end
		rooftop(m, cf, 0, bz, bw, bd, h)
		if L.chance(0.3) then L.roofBillboard(m, cf, L.r(-bw / 6, bw / 6), bz, h, 0) end
		local sideFace = sx == 1 and Enum.NormalId.Right or Enum.NormalId.Left
		if L.chance(0.5) then L.piece(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right })) end
		L.graffiti(body, Enum.NormalId.Front)
		if L.chance(0.5) then L.graffiti(body, sideFace) end
		-- forecourt + fence
		L.BD(m, cf, 0, 0.02, -d / 2 + (d - bd) / 2 - 2, w - 2, 0.1, d - bd - 6, C(150, 146, 138), M.Concrete, "ParkingLotStained")
		if L.chance(0.6) then L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(-8, 0, -d / 2 + 1)).Position, 6, "iron") L.fence(m, (cf * CFrame.new(8, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, 6, "iron") end
		if L.chance(0.6) then L.dumpster(m, cf * CFrame.new(-sx * (w / 2 - 6), 0, bz + bd / 2 + 3)) end
		if L.grime then L.grime(m, cf, 0, bz, bw, bd, h, { flat = true }) end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== empty lot (one per block face, chain-link, dirt, weeds) =====
	function L.emptyLot(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = "EmptyLot"
		L.BD(m, cf, 0, 0.02, 0, w - 1, 0.12, d - 1, C(132, 118, 92), M.Ground)
		local a = (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position
		local b = (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position
		local c2 = (cf * CFrame.new(w / 2 - 1, 0, d / 2 - 1)).Position
		local d2 = (cf * CFrame.new(-w / 2 + 1, 0, d / 2 - 1)).Position
		L.fence(m, a, b, 7, "chain")
		if L.chance(0.6) then L.fence(m, b, c2, 7, "chain") end
		if L.chance(0.6) then L.fence(m, d2, a, 7, "chain") end
		for _ = 1, L.ri(3, 8) do L.weeds(m, (cf * CFrame.new(L.r(-w / 2.4, w / 2.4), 0, L.r(-d / 2.4, d / 2.4))).Position) end
		for _ = 1, L.ri(0, 3) do L.bush(m, (cf * CFrame.new(L.r(-w / 3, w / 3), 0, L.r(-d / 3, d / 3))).Position, L.r(3, 6), C(92, 104, 52)) end
		if L.chance(0.4) then L.trashBags(m, (cf * CFrame.new(L.r(-w / 4, w / 4), 0, L.r(-d / 4, d / 4))).Position) end
		if L.chance(0.35) then
			L.D(m, Vector3.new(1, 3, 3), cf * CFrame.new(L.r(-w / 3, w / 3), 1, L.r(-d / 3, d / 3)) * CFrame.Angles(0, L.r(0, 3), 0.3), C(24, 24, 24), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
		end
		if L.chance(0.3) then L.tree(m, (cf * CFrame.new(L.r(-w / 4, w / 4), 0, d / 4)).Position, L.r(0.8, 1.2)) end
		local sgn = o.sign or (L.chance(0.45) and L.pick({ "WE BUY HOUSES  CASH", "LOT FOR SALE", "NO DUMPING" }) or nil)
		if sgn then
			L.B(m, cf, -3, 0, -d / 2 + 3, 0.5, 7, 0.5, C(90, 80, 70), M.Wood)
			L.B(m, cf, 3, 0, -d / 2 + 3, 0.5, 7, 0.5, C(90, 80, 70), M.Wood)
			L.sign(m, cf * CFrame.new(0, 7.6, -d / 2 + 2.7) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.pi, 0), 8.6, 3.2, sgn, C(250, 250, 248), C(200, 20, 20), Enum.Font.GothamBlack, {})
		end
		m.Parent = par
		return m
	end

	-- gentrification hint: fenced lot with the condo billboard
	function L.condoBoard(par, cf, w, d)
		local m = L.emptyLot(par, cf, w, d, { sign = "NO TRESPASSING" })
		m.Name = "FutureCondoLot"
		local bc = cf * CFrame.new(0, 0, d / 4)
		L.B(m, bc, -9, 0, 0, 1, 20, 1, C(60, 60, 64), M.Metal)
		L.B(m, bc, 9, 0, 0, 1, 20, 1, C(60, 60, 64), M.Metal)
		L.sign(m, bc * CFrame.new(0, 23, 0), 30, 9, "THE VUE  LUXURY CONDOS  COMING SOON", C(240, 240, 236), C(30, 30, 34), Enum.Font.Oswald, { both = true, dist = 500 })
		return m
	end

	-- storefront church / small white church
	function L.church(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = "Church"
		local bd = math.min(d - 10, 40)
		local bw = math.min(w - 8, 30)
		local bz = -d / 2 + 8 + bd / 2
		local col = C(238, 234, 224)
		wall(m, cf, 0, 0, bz, bw, 16, bd, col, "StuccoWhite")
		L.W(m, Vector3.new(bw + 1.5, 8, bd / 2 + 0.5), cf * CFrame.new(0, 20, bz - bd / 4), C(150, 80, 60), M.ClayRoofTiles, "RoofClayMission")
		L.W(m, Vector3.new(bw + 1.5, 8, bd / 2 + 0.5), cf * CFrame.new(0, 20, bz + bd / 4) * CFrame.Angles(0, math.pi, 0), C(150, 80, 60), M.ClayRoofTiles, "RoofClayMission")
		wall(m, cf, 0, 0, bz - bd / 2 - 3, 8, 27, 6, col, "StuccoWhite")
		L.B(m, cf, 0, 31, bz - bd / 2 - 3, 0.8, 8, 0.8, C(230, 200, 90), M.Metal)
		L.B(m, cf, 0, 34, bz - bd / 2 - 3, 4.5, 0.8, 0.8, C(230, 200, 90), M.Metal)
		door(m, cf, 0, 0.5, bz - bd / 2 - 6, 5, 9, C(110, 70, 40))
		L.win(m, cf, -bw / 3, 5, bz - bd / 2, 3, 8, { glass = C(90, 60, 120) })
		L.win(m, cf, bw / 3, 5, bz - bd / 2, 3, 8, { glass = C(60, 90, 140) })
		L.sign(m, cf * CFrame.new(0, 3.2, -d / 2 + 3), 15, 4, o.sign or "NEW HOPE BAPTIST CHURCH", C(250, 250, 245), C(30, 30, 80), Enum.Font.Merriweather, {})
		L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(-5, 0, -d / 2 + 1)).Position, 4, "iron")
		L.fence(m, (cf * CFrame.new(5, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, 4, "iron")
		m.Parent = par
		L.lod(m)
		return m
	end

	-- auto repair / tire shop with roll-up bays. o.interior: open shell with lifts, tool chests, tire racks
	function L.bays(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "AutoShop"
		local h = 16
		local bd = math.min(d - 14, 34)
		local bz = -d / 2 + 12 + bd / 2
		local fz = bz - bd / 2
		local bw = w - 4
		local col = L.jitter(L.pick({ C(214, 210, 200), C(190, 200, 210), C(220, 200, 150) }), 0.04)
		local n = math.max(1, math.floor((w - 10) / 14))
		local body, S
		if o.interior then
			local gaps = {}
			for k = 0, n - 1 do
				local x = -bw / 2 + (k + 0.5) * bw / n
				table.insert(gaps, { x - 5.5, x + 5.5, 11 })
			end
			S = L.shell(m, cf, 0, bz, bw, bd, h, col, "HoodPaintedConcrete", gaps)
			body = S.front
			L.BD(m, cf, 0, 0.02, bz, bw - 1, 0.1, bd - 1, C(150, 150, 146), M.Concrete, "ParkingLotStained")
		else
			body = wall(m, cf, 0, 0, bz, bw, h, bd, col, "HoodPaintedConcrete")
		end
		parapet(m, cf, 0, bz, bw + 0.4, bd + 0.4, h, L.shade(col, 0.85))
		L.falseFront(m, cf, 0, fz, bw, h, col, L.pick({ "flat", "cornice", "raise" }))
		rooftop(m, cf, 0, bz, bw, bd, h)
		local STRIPE = L.pick({ C(196, 30, 30), C(30, 70, 150), C(240, 180, 30) })
		L.BD(m, cf, 0, 11.6, fz - 0.08, bw, 0.6, 0.1, STRIPE, M.SmoothPlastic)
		for k = 0, n - 1 do
			local x = -bw / 2 + (k + 0.5) * bw / n
			local open = o.interior and (k % 2 == 0 or L.chance(0.5)) or L.chance(0.5)
			if not o.interior then L.BD(m, cf, x, 0, fz - 0.05, 11, 11, 0.2, C(30, 30, 32), M.SmoothPlastic) end
			-- steel jambs + bollards
			for _, sx in ipairs({ -1, 1 }) do
				L.BD(m, cf, x + sx * 5.7, 0, fz - 0.2, 0.4, 11.2, 0.5, C(60, 62, 66), M.Metal)
				L.Cyl(m, 3.2, 0.9, cf * CFrame.new(x + sx * 6.4, 1.6, fz - 0.9), C(236, 196, 40), M.SmoothPlastic)
			end
			if not open then
				local bsp = L.B(m, cf, x, 0.2, fz + (o.interior and 0.5 or -0.3), 11, 10.8, 0.3, C(150, 152, 150), M.Metal)
				if L.villaStripes then L.villaStripes(bsp, o.interior and Enum.NormalId.Front or Enum.NormalId.Front, 19, C(70, 72, 74), 0.55, false) end
			else
				L.BD(m, cf, x, 9, fz + (o.interior and 0.5 or -0.3), 11, 2, 0.3, C(196, 196, 192), M.Metal, "ShutterPainted")
				if o.interior then
					-- two-post lift with a car up on it
					local lc = cf * CFrame.new(x, 0, bz + 1)
					for _, sx in ipairs({ -1, 1 }) do
						L.B(m, lc, sx * 5, 0, 0, 1, 11, 1, C(40, 80, 160), M.Metal)
						L.BD(m, lc, sx * 3.6, 4.2, 0, 2.8, 0.4, 0.5, C(60, 62, 66), M.Metal)
					end
					local car = L.car(m, lc * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.pi, 0))
					if car then for _, dd in ipairs(car:GetDescendants()) do if dd:IsA("BasePart") then dd.CanCollide = false end end end
				else
					L.car(m, cf * CFrame.new(x, 0.1, fz + 9) * CFrame.Angles(0, math.pi, 0))
				end
			end
		end
		if o.interior then
			-- back wall: red tool chests, workbench, tire rack, oil drums, fluorescent strips
			local backZ = bz + bd / 2 - 1
			for k = 0, math.max(1, n) do
				local x = -bw / 2 + 4 + k * 7
				if x < bw / 2 - 4 then
					L.B(m, cf, x, 0, backZ - 1.2, 4.6, 4.4, 2.2, C(176, 30, 30), M.Metal)
					for y = 1, 3 do L.BD(m, cf, x, y * 1.1, backZ - 2.33, 4.2, 0.08, 0.05, C(200, 200, 196), M.Metal) end
				end
			end
			L.B(m, cf, bw / 2 - 2.6, 0, bz, 3, 3.4, bd * 0.4, C(120, 96, 70), M.Wood)
			L.BD(m, cf, bw / 2 - 1.1, 4.4, bz, 0.1, 4, bd * 0.36, C(70, 72, 76), M.DiamondPlate)
			for j = 0, 3 do
				L.D(m, Vector3.new(1, 2.8, 2.8), cf * CFrame.new(-bw / 2 + 2.2, 1.6 + j * 0.02, bz - bd / 4 + j * 1.1) * CFrame.Angles(0, math.pi / 2, math.pi / 2), C(22, 22, 22), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
			end
			L.BD(m, cf, -bw / 2 + 2.2, 0, bz - bd / 4 + 1.6, 3, 0.3, 5.4, C(60, 62, 66), M.Metal)
			for j = 0, 1 do L.Cyl(m, 3, 2, cf * CFrame.new(-bw / 2 + 2.4 + j * 2.1, 1.5, bz + bd / 4), L.pick({ C(30, 70, 150), C(40, 100, 50) }), M.Metal) end
			for k = -1, 1 do L.BD(m, cf, k * bw / 3, h - 1.3, bz, 1, 0.15, bd * 0.6, C(236, 244, 255), M.Neon) end
			local a = L.BD(m, cf, 0, h - 2, bz, 0.2, 0.2, 0.2, C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
			local pl = Instance.new("PointLight")
			pl.Range = 30
			pl.Brightness = 0.8
			pl.Shadows = false
			pl.Parent = a
		end
		L.sign(m, cf * CFrame.new(0, h - 3, fz - 0.4), math.min(w - 10, 32), 3.4, o.sign or L.pick({ "WESTSIDE AUTO REPAIR", "A1 TIRES & RIMS", "LIBERTY AUTO BODY", "BRAKES  TIRES  OIL" }), C(26, 26, 28), C(255, 210, 40), Enum.Font.GothamBlack, {})
		L.BD(m, cf, 0, 0.02, -d / 2 + 6, w - 2, 0.12, 12, C(150, 146, 140), M.Concrete, "ParkingLotStained")
		-- tire stacks
		for k = 1, L.ri(2, 4) do
			local p = cf * CFrame.new(-w / 2 + 4 + k * 2.6, 0, -d / 2 + 3)
			for j = 0, L.ri(2, 5) do
				L.D(m, Vector3.new(1, 2.8, 2.8), p * CFrame.new(0, 0.5 + j * 1, 0) * CFrame.Angles(0, 0, math.pi / 2), C(22, 22, 22), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
			end
		end
		local sideA = L.chance(0.5) and -1 or 1
		L.wallAC(m, cf, 0, sideA, bw, bz, 7.5, col)
		L.meterBank(m, cf, 0, -sideA, bw, bz + bd / 2 - 5, h)
		L.fence(m, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, d / 2 - 1)).Position, 8, "chain")
		local sf = sideA == -1 and Enum.NormalId.Right or Enum.NormalId.Left
		local sp = S and (sideA == -1 and S.right or S.left) or body
		if L.chance(0.5) then L.sideAd(sp, sf, "TIRES • RIMS • BRAKES • OIL") end
		if L.chance(0.6) then L.graffiti(sp, sf) end
		m.Parent = par
		L.lod(m)
		return m
	end

	function L.warehouse(par, cf, w, d, o)
		-- tilt-up / metal-clad industrial building (Larp + port references): panel joints, parapet coping, a glazed
		-- office corner with canopy + sign, raised loading docks (seals, bumpers, dock lights, levelers, bollards),
		-- one drive-in door on a ramp, wall packs, downspouts, meter boxes, roof units + skylights. Murals go on the
		-- street-facing side wall as a painted panel (not across the dock doors).
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "Warehouse"
		local h = o.h or L.r(24, 30)
		local bw, bd = w - 6, d - 10
		local bz = -d / 2 + 8 + bd / 2
		local fz = bz - bd / 2
		local metal = o.metal
		local col = o.color or (metal and L.pick({ C(176, 182, 186), C(150, 164, 170), C(196, 192, 182) }) or L.pick({ C(206, 200, 188), C(190, 186, 178), C(214, 206, 190), C(176, 178, 174) }))
		local rd = o.rundown
		local mat, var = M.Concrete, rd and "HoodConcreteDirty" or "ConcretePlain"
		if metal then mat, var = M.Metal, nil end
		local body = L.B(m, cf, 0, 0, bz, bw, h, bd, col, mat, var)
		local stripes = L.villaStripes
		if stripes then
			-- tilt-up panel joints (vertical) or ribbed cladding
			for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do stripes(body, f, math.floor(bw / (metal and 2 or 12)), L.shade(col, 0.72), metal and 0.55 or 0.35, true) end
			for _, f in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do stripes(body, f, math.floor(bd / (metal and 2 or 12)), L.shade(col, 0.72), metal and 0.55 or 0.35, true) end
		end
		-- accent band + darker base course
		local accent = o.accent or L.pick({ C(30, 90, 150), C(170, 40, 40), C(40, 110, 80), C(60, 60, 64), C(230, 150, 40) })
		L.BD(m, cf, 0, 0, bz, bw + 0.1, 2.2, bd + 0.1, L.shade(col, 0.68), M.Concrete)
		L.BD(m, cf, 0, h - 3.2, bz, bw + 0.12, 1.1, bd + 0.12, accent, M.SmoothPlastic)
		-- parapet + coping + roof
		L.B(m, cf, 0, h, bz, bw + 0.4, 0.5, bd + 0.4, C(60, 62, 66), M.Metal)
		L.B(m, cf, 0, h - 1, bz, bw - 1, 0.6, bd - 1, C(120, 120, 118), M.Asphalt, "RoofFlatBitumen")
		for k = 0, math.max(0, math.floor(bw / 30)) do
			local x = -bw / 2 + 10 + k * 28
			if x < bw / 2 - 6 then
				L.B(m, cf, x, h - 0.4, bz + L.r(-bd / 4, bd / 4), 6, 3.6, 5, C(196, 198, 200), M.Metal)
				L.BD(m, cf, x + 9, h - 0.4, bz + L.r(-bd / 4, bd / 4), 5, 0.8, 5, C(170, 200, 220), M.Glass, nil, { Transparency = 0.3 })
			end
		end
		-- office corner: glass box + door + canopy + sign (left end of the front)
		local ow = math.min(22, bw * 0.3)
		local ox = -bw / 2 + ow / 2
		L.BD(m, cf, ox, 1.5, fz - 0.2, ow - 2, 11, 0.3, C(60, 80, 96), M.Glass, nil, { Reflectance = 0.25 })
		for k = 0, 3 do L.BD(m, cf, ox - (ow - 2) / 2 + k * (ow - 2) / 3, 1.5, fz - 0.35, 0.4, 11, 0.4, C(60, 62, 66), M.Metal) end
		L.BD(m, cf, ox, 6.6, fz - 0.4, ow - 2, 0.4, 0.4, C(60, 62, 66), M.Metal)
		L.B(m, cf, ox, 13, fz - 3, ow, 0.8, 6, accent, M.Metal)
		for k = 0, 2 do L.D(m, Vector3.new(0.8, 0.1, 0.8), cf * CFrame.new(ox - ow / 3 + k * ow / 3, 12.95, fz - 3), C(255, 244, 222), M.Neon) end
		local sname = o.sign or L.pick({ "BAYSIDE SUPPLY", "SOUTH DADE DIST.", "COASTAL DEPOT", "VICE IMPORTS", "SUNRISE STORAGE", "OCEAN AVE PRINT" })
		local sg = L.D(m, Vector3.new(math.min(bw - ow - 8, #sname * 2.2 + 6), 3.6, 0.3), cf * CFrame.new(ox + ow / 2 + (math.min(bw - ow - 8, #sname * 2.2 + 6)) / 2 + 2, h - 6.5, fz - 0.3), C(250, 250, 248), M.SmoothPlastic)
		L.label(sg, Enum.NormalId.Front, sname, { font = Enum.Font.GothamBlack, color = accent, light = 0.3, bright = 1.2 })
		-- loading docks: raised dock, seals, bumpers, dock light, leveler, bollards
		local docks = math.max(1, math.floor((bw - ow - 14) / 16))
		local dx0 = -bw / 2 + ow + 6
		local dockLen = docks * 16
		L.B(m, cf, dx0 + dockLen / 2, 0, fz - 3, dockLen + 2, 4.2, 6, C(176, 174, 168), M.Concrete, "ConcreteStained")
		L.BD(m, cf, dx0 + dockLen / 2, 4.2, fz - 5.9, dockLen + 2, 0.2, 0.3, C(240, 200, 40), M.SmoothPlastic)
		for k = 0, docks - 1 do
			local x = dx0 + 8 + k * 16
			-- door frame + roll-up door (horizontal slats)
			L.BD(m, cf, x, 4.2, fz - 0.4, 12.6, 11.4, 0.5, C(60, 62, 66), M.Metal)
			local door = L.BD(m, cf, x, 4.4, fz - 0.6, 11.8, 10.8, 0.3, rd and C(170, 168, 160) or C(220, 222, 224), rd and M.CorrodedMetal or M.Metal, rd and "ShutterRusty" or nil)
			if stripes then stripes(door, Enum.NormalId.Front, 14, C(90, 92, 96), 0.5, false) end
			-- black dock seal around the door, bumpers, leveler plate, dock light
			for sd = -1, 1, 2 do L.BD(m, cf, x + sd * 6.9, 4.2, fz - 1.2, 1.2, 11.4, 1.4, C(26, 26, 28), M.Fabric) end
			L.BD(m, cf, x, 15.2, fz - 1.2, 15, 1.4, 1.4, C(26, 26, 28), M.Fabric)
			for sd = -1, 1, 2 do L.BD(m, cf, x + sd * 4, 2.2, fz - 6.3, 1.4, 1.8, 0.6, C(20, 20, 20), M.Rubber) end
			L.BD(m, cf, x, 4.2, fz - 3.4, 7, 0.08, 5, C(90, 92, 96), M.DiamondPlate)
			L.D(m, Vector3.new(0.3, 0.3, 2), cf * CFrame.new(x - 7.6, 12.6, fz - 1.4), C(60, 62, 66), M.Metal)
			L.D(m, Vector3.new(0.9, 0.6, 0.9), cf * CFrame.new(x - 7.6, 12.4, fz - 2.4), C(255, 236, 200), M.Neon)
			L.Cyl(m, 4.2, 1, cf * CFrame.new(x + 7.8, 2.1, fz - 6.6), C(240, 200, 40), M.Metal)
		end
		-- drive-in door on a ramp at the right end
		local rx = bw / 2 - 8
		if rx - dx0 - dockLen > 8 then
			L.BD(m, cf, rx, 0, fz - 0.4, 13, 14.4, 0.5, C(60, 62, 66), M.Metal)
			local dd = L.BD(m, cf, rx, 0.2, fz - 0.6, 12, 14, 0.3, C(220, 222, 224), M.Metal)
			if stripes then stripes(dd, Enum.NormalId.Front, 16, C(90, 92, 96), 0.5, false) end
			for sd = -1, 1, 2 do L.Cyl(m, 4.2, 1, cf * CFrame.new(rx + sd * 7.4, 2.1, fz - 1.6), C(240, 200, 40), M.Metal) end
		end
		-- wall packs, downspouts, meter boxes, a wall AC unit, an exterior stair to the roof on the back
		for k = 0, 3 do
			local x = -bw / 2 + 6 + k * (bw - 12) / 3
			L.D(m, Vector3.new(1.4, 1, 0.8), cf * CFrame.new(x, h - 6, fz - 0.5), C(60, 62, 66), M.Metal)
			L.D(m, Vector3.new(1, 0.1, 0.6), cf * CFrame.new(x, h - 6.55, fz - 0.6), C(255, 236, 200), M.Neon)
		end
		for sd = -1, 1, 2 do
			L.D(m, Vector3.new(0.7, h, 0.7), cf * CFrame.new(sd * (bw / 2 - 0.4), h / 2, fz - 0.5), L.shade(col, 0.8), M.Metal)
			L.D(m, Vector3.new(0.7, h, 0.7), cf * CFrame.new(sd * (bw / 2 + 0.4), h / 2, bz + bd / 2 - 3), L.shade(col, 0.8), M.Metal)
		end
		-- side walls: clerestory window band, man doors with a light over them, downspouts
		for sd = -1, 1, 2 do
			local xw = sd * (bw / 2 + 0.08)
			L.D(m, Vector3.new(0.15, 2.4, bd - 10), cf * CFrame.new(xw, h - 7, bz), C(70, 92, 104), M.Glass, nil, { Reflectance = 0.25 })
			for k = 0, math.floor((bd - 10) / 8) do L.D(m, Vector3.new(0.25, 2.6, 0.3), cf * CFrame.new(xw, h - 7, bz - (bd - 10) / 2 + k * 8), C(60, 62, 66), M.Metal) end
			local dz = bz + bd / 2 - 10
			L.BD(m, cf, xw, 0, dz, 0.3, 8, 4.4, C(60, 62, 66), M.Metal)
			L.BD(m, cf, xw + sd * 0.05, 0.2, dz, 0.3, 7.6, 3.8, L.shade(accent, 0.9), M.Metal)
			L.D(m, Vector3.new(0.8, 0.6, 1.2), cf * CFrame.new(xw + sd * 0.4, 9, dz), C(255, 236, 200), M.Neon)
			L.B(m, cf, xw + sd * 2, 0, dz, 4, 0.6, 5, C(176, 174, 168), M.Concrete)
		end
		L.BD(m, cf, bw / 2 + 0.4, 3, bz + bd / 4, 0.6, 3, 2.4, C(150, 152, 156), M.Metal)
		L.BD(m, cf, bw / 2 + 0.5, 3.6, bz + bd / 4 + 3, 0.8, 1.6, 1.2, C(196, 196, 192), M.Metal)
		-- apron: concrete truck court with stall lines
		L.BD(m, cf, 0, 0.03, -d / 2 + 4, w - 2, 0.15, 8, C(170, 168, 162), M.Concrete, "ConcreteStained")
		-- mural on the side wall (painted panel with gradient + bubble piece), Wynwood style
		if o.mural then
			local side = L.chance(0.5) and 1 or -1
			local mw, mh = bd - 6, h - 6
			local panel = L.D(m, Vector3.new(0.1, mh, mw), cf * CFrame.new(side * (bw / 2 + 0.06), 2.6 + mh / 2, bz), Color3.new(1, 1, 1), M.SmoothPlastic)
			local face = (side > 0) and Enum.NormalId.Right or Enum.NormalId.Left
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 8
			g.LightInfluence = 1
			g.MaxDistance = 500
			g.Parent = panel
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BorderSizePixel = 0
			bg.BackgroundColor3 = Color3.new(1, 1, 1)
			bg.Parent = g
			local gr = Instance.new("UIGradient")
			local c1, c2 = L.pick({ C(40, 70, 170), C(230, 70, 140), C(250, 170, 40), C(30, 170, 150) }), L.pick({ C(140, 60, 200), C(250, 120, 60), C(40, 200, 220), C(250, 220, 80) })
			gr.Color = ColorSequence.new(c1, c2)
			gr.Rotation = L.r(10, 80)
			gr.Parent = bg
			for k = 1, 6 do
				local sh = Instance.new("Frame")
				sh.BorderSizePixel = 0
				sh.AnchorPoint = Vector2.new(0.5, 0.5)
				sh.Position = UDim2.fromScale(L.r(0.1, 0.9), L.r(0.1, 0.9))
				local sz = L.r(0.15, 0.45)
				sh.Size = UDim2.fromScale(sz * 0.6, sz)
				sh.Rotation = L.r(0, 90)
				sh.BackgroundColor3 = L.pick({ C(255, 255, 255), C(20, 20, 30), C(255, 220, 60), C(255, 90, 140), C(60, 220, 200) })
				sh.BackgroundTransparency = L.r(0.2, 0.6)
				sh.Parent = bg
				local cr = Instance.new("UICorner")
				cr.CornerRadius = UDim.new(L.r(0, 0.5), 0)
				cr.Parent = sh
			end
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.9, 0.45)
			t.Position = UDim2.fromScale(0.05, 0.28)
			t.Text = o.mural
			t.TextScaled = true
			t.Font = L.pick({ Enum.Font.Bangers, Enum.Font.FredokaOne, Enum.Font.LuckiestGuy })
			t.TextColor3 = L.pick({ C(255, 255, 255), C(255, 230, 80), C(120, 240, 255) })
			t.Rotation = L.r(-6, 6)
			t.Parent = bg
			local st = Instance.new("UIStroke")
			st.Thickness = 6
			st.Color = C(20, 20, 30)
			st.Parent = t
		elseif rd ~= false and L.chance(0.6) then
			L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right }))
		end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- invisible queryable footprint so the lot filler never builds on top of a lot (decoration parts are CanQuery=false)
	function L.footprint(parent, cf, w, d)
		local p = Instance.new("Part")
		p.Name = "Footprint"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(math.max(1, w - 1), 4, math.max(1, d - 1))
		p.CFrame = cf * CFrame.new(0, 2, 0)
		p.Parent = parent
		return p
	end

	-- ===== LOT FILLER =====
	-- chooser(x, z, edgeStyle, side, edge) -> nil | {kind, w, d, opts, gap}
	L.FILL_BLOCKERS = { "Roads", "Buildings", "Reserved", "Landmarks", "Highway", "River", "Rail", "CountyRoads", "CoralCauseway", "Canal", "Parks" }
	function L.fill(par, net, chooser, filterFn)
		local VB = workspace:FindFirstChild("ViceBay")
		local inc = {}
		for _, n in ipairs(L.FILL_BLOCKERS) do
			local f = VB and VB:FindFirstChild(n)
			if f then table.insert(inc, f) end
		end
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = inc
		-- round junction / bend plates only overlap by their square bounding box: don't let them block lots
		local SKIP = { Junction = true, Bend = true, CulDeSac = true }
		local function blocked(cf, size)
			for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
				if not SKIP[p.Name] then return true end
			end
			return false
		end
		local built = 0
		for i, e in ipairs(net.edges) do
			local A, B = net.nodes[e[1]], net.nodes[e[2]]
			local a = Vector3.new(A[1], L.G, A[2])
			local b = Vector3.new(B[1], L.G, B[2])
			local len = (b - a).Magnitude
			local mid = (a + b) / 2
			if len > 36 and (not filterFn or filterFn(mid.X, mid.Z, e)) then
				local dir = (b - a).Unit
				local right = Vector3.new(-dir.Z, 0, dir.X)
				local st = e[4]
				local edgeOff = e[3] / 2 + (st.sw or 0) + 1.5
				for side = -1, 1, 2 do
					local s = 14
					while s < len - 14 do
						local p0 = a + dir * s
						local ch = chooser(p0.X, p0.Z, st, side, e)
						if not ch then
							s += 20
						else
							local w, d = ch.w, ch.d
							if s + w > len - 10 then break end
							local center = a + dir * (s + w / 2) + right * side * (edgeOff + d / 2)
							local cf = CFrame.lookAt(center, center - right * side)
							-- check at ROAD height (y G..G+6) so lots never sit on roads
							local ok = not blocked(cf * CFrame.new(0, 3, 0), Vector3.new(w - 1, 6, d - 1))
							-- shallower lot if the full depth hits the lots behind
							for _, k in ipairs({ 0.82, 0.68 }) do
								if ok or d * k < 30 then break end
								local d2 = d * k
								local c2 = a + dir * (s + w / 2) + right * side * (edgeOff + d2 / 2)
								local cf2 = CFrame.lookAt(c2, c2 - right * side)
								if not blocked(cf2 * CFrame.new(0, 3, 0), Vector3.new(w - 1, 6, d2 - 1)) then
									ok, d, cf, center = true, d2, cf2, c2
								end
							end
							if ok then
								for _, q in ipairs({ { 0, 0 }, { -w / 2 + 2, -d / 2 + 2 }, { w / 2 - 2, d / 2 - 2 }, { -w / 2 + 2, d / 2 - 2 }, { w / 2 - 2, -d / 2 + 2 } }) do
									local pq = (cf * CFrame.new(q[1], 0, q[2])).Position
									if L.isWater(pq.X, pq.Z) then ok = false break end
								end
							end
							if ok then
								local mm = L[ch.kind](par, cf, w, d, ch.opts)
								L.footprint((typeof(mm) == "Instance" and mm) or par, cf, w, d)
								built += 1
								s += w + (ch.gap or L.r(1, 4))
							else
								s += 5
							end
						end
					end
				end
			end
			if i % 6 == 0 then task.wait() end
		end
		return built
	end

	-- ===== hood landmarks =====
	-- corner store with parking in front (spawn spot)
	function L.foodMart(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "FoodMart"
		local bd = math.min(40, d * 0.45)
		local bz = d / 2 - bd / 2 - 1
		local fz = bz - bd / 2
		local col = o.color or C(222, 196, 160)
		-- walk-in shell: barred shop window + glass door, corner-store interior inside
		local S = L.shell(m, cf, 0, bz, w - 4, bd, 16, col, "StuccoPinkWeathered", { { -w * 0.275, w * 0.275, 9 }, { w * 0.36 - 2.2, w * 0.36 + 2.2, 8.4 } })
		local body = S.left
		parapet(m, cf, 0, bz, w - 3.6, bd + 0.4, 16, L.shade(col, 0.85))
		L.falseFront(m, cf, 0, fz, w - 4, 16, col, "raise")
		rooftop(m, cf, 0, bz, w - 4, bd, 16)
		L.B(m, cf, 0, 0.6, fz + 0.5, w * 0.55, 8.4, 0.25, C(150, 170, 180), M.Glass, nil, { Reflectance = 0.08, Transparency = 0.6 })
		for b = 0, math.floor(w * 0.55 / 1.1) do L.BD(m, cf, -w * 0.275 + b * 1.1, 0.7, fz - 0.15, 0.14, 8.2, 0.14, INK, M.Metal) end
		L.BD(m, cf, w * 0.36, 0.6, fz + 0.5, 4, 7.8, 0.25, C(150, 170, 180), M.Glass, nil, { Transparency = 0.5 }).Name = "Door"
		L.BD(m, cf, 0, 0.02, bz, w - 5, 0.1, bd - 1, C(200, 196, 188), M.SmoothPlastic)
		L.unitInterior(m, cf * CFrame.new(0, 0, bz + 0.5), w - 7, bd - 3, 16, "store", { accent = C(150, 30, 30) })
		L.wallPack(m, cf, w * 0.36, 9.4, fz)
		L.wallAC(m, cf, 0, 1, w - 4, bz + 4, 8, col)
		L.meterBank(m, cf, 0, -1, w - 4, bz + bd / 2 - 5, 16)
		L.sign(m, cf * CFrame.new(0, 12.4, fz - 0.45), math.min(w - 8, 34), 3.6, o.sign or "LIBERTY FOOD MART", C(196, 30, 30), C(255, 255, 255), Enum.Font.GothamBlack, { lit = true })
		L.P(m, Vector3.new(w - 6, 0.35, 5), cf * CFrame.new(0, 10.4, fz - 2.4) * CFrame.Angles(math.rad(-14), 0, 0), C(30, 90, 50), M.Fabric)
		local op = L.D(m, Vector3.new(3.4, 1.3, 0.1), cf * CFrame.new(-w * 0.15, 6.2, fz - 0.3), C(255, 60, 80), M.Neon)
		L.text(op, Enum.NormalId.Front, "OPEN", { font = Enum.Font.GothamBold, color = Color3.new(1, 1, 1), pps = 30, dist = 120 })
		L.text(body, Enum.NormalId.Left, "ICE • GROCERY • HOT FOOD", { font = Enum.Font.Oswald, color = C(250, 250, 248), bg = C(30, 60, 140), size = UDim2.fromScale(0.8, 0.14), pos = UDim2.fromScale(0.1, 0.55), pps = 12, dist = 300 })
		-- parking lot with faded stalls, ice box, phone pole, payphone-style kiosk
		local pd = d - bd - 2
		local pz = -d / 2 + pd / 2
		L.BD(m, cf, 0, 0.03, pz, w - 1, 0.15, pd, C(116, 114, 110), M.Asphalt, "ParkingLotAsphalt")
		local n = math.floor((w - 8) / 10)
		for k = 0, n do L.BD(m, cf, -w / 2 + 4 + k * 10, 0.19, pz + pd / 2 - 9, 0.4, 0.02, 16, C(220, 214, 196), M.SmoothPlastic, nil, { Transparency = 0.35 }) end
		for k = 1, L.ri(2, 4) do L.car(m, cf * CFrame.new(-w / 2 + 9 + (k - 1) * 20, 0.2, pz + pd / 2 - 9) * CFrame.Angles(0, (L.chance(0.5) and 0 or math.pi), 0)) end
		L.B(m, cf, w / 2 - 6, 0, fz - 1.6, 6, 5, 3, C(236, 236, 238), M.Metal)
		L.text(L.BD(m, cf, w / 2 - 6, 3.2, fz - 3.15, 5, 1.4, 0.1, C(40, 110, 200), M.SmoothPlastic), Enum.NormalId.Front, "ICE", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), pps = 30 })
		L.dumpster(m, cf * CFrame.new(-w / 2 + 6, 0, d / 2 - 3))
		L.graffiti(S.right, Enum.NormalId.Right)
		L.piece(S.back, Enum.NormalId.Back)
		m.Parent = par
		L.lod(m)
		return m, cf * CFrame.new(0, 0.2, pz)
	end

	-- gas station: canopy, pumps, kiosk
	function L.gas(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "GasStation"
		L.BD(m, cf, 0, 0.03, 0, w - 1, 0.15, d - 1, C(150, 148, 142), M.Concrete, "ParkingLotStained")
		local cw, cd = math.min(w - 16, 56), 28
		local cz = -d / 2 + 22
		for _, x in ipairs({ -cw / 2 + 6, cw / 2 - 6 }) do
			for _, z in ipairs({ cz - 7, cz + 7 }) do L.B(m, cf, x, 0, z, 1.4, 17, 1.4, C(236, 236, 236), M.Metal) end
		end
		L.B(m, cf, 0, 17, cz, cw, 2.4, cd, C(240, 240, 238), M.Metal)
		local band = L.BD(m, cf, 0, 17.6, cz - cd / 2 - 0.05, cw, 1.4, 0.1, o.brand or C(200, 30, 30), M.SmoothPlastic)
		L.text(band, Enum.NormalId.Front, o.sign or "SUNSHINE GAS", { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), size = UDim2.fromScale(0.4, 0.9), pos = UDim2.fromScale(0.3, 0.05), pps = 14 })
		L.BD(m, cf, 0, 16.9, cz, cw - 2, 0.1, cd - 2, C(255, 250, 236), M.Neon)
		for _, x in ipairs({ -cw / 4, cw / 4 }) do
			L.B(m, cf, x, 0, cz, 4, 0.8, 12, C(200, 196, 188), M.Concrete)
			for _, z in ipairs({ cz - 3.5, cz + 3.5 }) do
				L.B(m, cf, x, 0.8, z, 2, 6, 1.4, C(236, 236, 236), M.Metal)
				L.BD(m, cf, x, 4.6, z - 0.72, 1.6, 1.2, 0.05, C(30, 30, 30), M.SmoothPlastic)
			end
		end
		-- kiosk
		local kz = d / 2 - 14
		local col = C(226, 222, 212)
		wall(m, cf, 0, 0, kz, 30, 13, 20, col, "StuccoWhite")
		parapet(m, cf, 0, kz, 30.4, 20.4, 13, L.shade(col, 0.9))
		L.BD(m, cf, 0, 0.6, kz - 10.1, 20, 8, 0.25, GLASS, M.Glass, nil, { Reflectance = 0.2 })
		for b = 0, 18 do L.BD(m, cf, -10 + b * 1.1, 0.7, kz - 10.45, 0.14, 7.8, 0.14, INK, M.Metal) end
		L.sign(m, cf * CFrame.new(0, 10.4, kz - 10.4), 18, 2.6, "FOOD MART • ATM", C(250, 250, 248), C(200, 30, 30), Enum.Font.GothamBlack, {})
		-- price pylon
		local px = w / 2 - 4
		L.B(m, cf, px, 0, -d / 2 + 4, 1.2, 22, 1.2, C(80, 80, 84), M.Metal)
		local py = L.BD(m, cf, px, 16, -d / 2 + 4, 0.6, 9, 6, C(200, 30, 30), M.SmoothPlastic)
		L.text(py, Enum.NormalId.Left, "GAS\n3.49\n3.89", { font = Enum.Font.Code, color = C(255, 230, 120), bg = C(20, 20, 22), pps = 10 })
		L.text(py, Enum.NormalId.Right, "GAS\n3.49\n3.89", { font = Enum.Font.Code, color = C(255, 230, 120), bg = C(20, 20, 22), pps = 10 })
		m.Parent = par
		L.lod(m)
		return m
	end

	-- used car lot: flags, small office, rows of cars with price stickers
	function L.carLot(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "UsedCarLot"
		L.BD(m, cf, 0, 0.03, 0, w - 1, 0.15, d - 1, C(112, 110, 106), M.Asphalt, "ParkingLotAsphalt")
		local oz = d / 2 - 10
		wall(m, cf, -w / 2 + 12, 0, oz, 18, 11, 14, C(236, 232, 222), "StuccoWhite")
		L.BD(m, cf, -w / 2 + 12, 0.6, oz - 7.1, 10, 6, 0.25, GLASS, M.Glass)
		L.sign(m, cf * CFrame.new(0, 14, -d / 2 + 2), math.min(w - 10, 40), 5, o.sign or "LUCKY'S USED AUTOS", C(250, 210, 40), C(20, 20, 20), Enum.Font.GothamBlack, { both = true, dist = 400 })
		L.B(m, cf, -math.min(w - 10, 40) / 2 + 1, 0, -d / 2 + 2, 0.8, 12, 0.8, C(60, 60, 64), M.Metal)
		L.B(m, cf, math.min(w - 10, 40) / 2 - 1, 0, -d / 2 + 2, 0.8, 12, 0.8, C(60, 60, 64), M.Metal)
		-- pennant string flags
		for k = 0, math.floor(w / 4) do
			L.D(m, Vector3.new(1.4, 1.6, 0.05), cf * CFrame.new(-w / 2 + 2 + k * 4, 9, -d / 2 + 1) * CFrame.Angles(0, 0, math.pi / 4), L.pick({ C(220, 40, 40), C(40, 90, 200), C(250, 210, 40), C(240, 240, 240) }), M.Fabric)
		end
		local cols = math.floor((w - 30) / 11)
		for r = 0, 1 do
			for k = 0, cols - 1 do
				local car = L.car(m, cf * CFrame.new(-w / 2 + 26 + k * 11, 0.2, -d / 2 + 14 + r * 20) * CFrame.Angles(0, math.pi, 0))
				local st = L.D(car, Vector3.new(2.4, 1.2, 0.05), cf * CFrame.new(-w / 2 + 26 + k * 11, 4.2, -d / 2 + 14 + r * 20 - 7.6), C(250, 250, 240), M.SmoothPlastic)
				L.text(st, Enum.NormalId.Front, "$" .. L.ri(2, 9) .. "," .. L.ri(1, 9) .. "99", { font = Enum.Font.GothamBlack, color = C(200, 20, 20), pps = 30, dist = 80 })
			end
		end
		m.Parent = par
		return m
	end

	-- fenced basketball court
	function L.court(par, cf, w, d, o)
		local m = Instance.new("Model")
		m.Name = "Court"
		local cw, cd = math.min(w - 6, 50), math.min(d - 6, 90)
		L.BD(m, cf, 0, 0.03, 0, cw, 0.2, cd, C(84, 110, 140), M.Concrete, "ConcretePlain")
		L.BD(m, cf, 0, 0.24, 0, cw - 6, 0.02, cd - 6, C(180, 92, 60), M.Concrete)
		L.BD(m, cf, 0, 0.27, 0, cw - 6, 0.02, 0.4, C(240, 240, 236), M.SmoothPlastic)
		L.Cyl(m, 0.03, 12, cf * CFrame.new(0, 0.28, 0), C(240, 240, 236), M.SmoothPlastic)
		for _, s in ipairs({ -1, 1 }) do
			local z = s * (cd / 2 - 4)
			L.B(m, cf, 0, 0, z + s * 2, 0.6, 10, 0.6, C(40, 40, 44), M.Metal)
			L.BD(m, cf, 0, 9, z + s * 1.4, 6, 4, 0.3, C(240, 240, 240), M.SmoothPlastic)
			L.D(m, Vector3.new(0.2, 2.2, 2.2), cf * CFrame.new(0, 10, z) * CFrame.Angles(0, 0, math.pi / 2), C(230, 80, 30), M.Metal, nil, { Shape = Enum.PartType.Cylinder })
			L.BD(m, cf, 0, 0.26, z - s * 9, 12, 0.02, 18, C(150, 60, 50), M.Concrete)
		end
		local a = (cf * CFrame.new(-cw / 2, 0, -cd / 2)).Position
		local b = (cf * CFrame.new(cw / 2, 0, -cd / 2)).Position
		local c = (cf * CFrame.new(cw / 2, 0, cd / 2)).Position
		local e = (cf * CFrame.new(-cw / 2, 0, cd / 2)).Position
		-- gate gap in the street-side fence so players can walk in
		local g0 = (cf * CFrame.new(-4, 0, -cd / 2)).Position
		local g1 = (cf * CFrame.new(4, 0, -cd / 2)).Position
		L.fence(m, a, g0, 12, "chain"); L.fence(m, g1, b, 12, "chain")
		L.fence(m, b, c, 12, "chain"); L.fence(m, c, e, 12, "chain"); L.fence(m, e, a, 12, "chain")
		-- courtside bench + light poles
		L.bench(m, cf * CFrame.new(cw / 2 - 2.5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
		for _, sd in ipairs({ -1, 1 }) do
			L.B(m, cf, -cw / 2 - 1, 0, sd * cd / 4, 0.5, 20, 0.5, C(70, 72, 76), M.Metal)
			L.BD(m, cf, -cw / 2 + 0.6, 19.6, sd * cd / 4, 3, 0.6, 1.6, C(255, 244, 220), M.Neon)
		end
		m.Parent = par
		return m
	end

	-- two-storey public housing block (Liberty Square style)
	function L.projects(par, cf, w, d, o)
		local m = Instance.new("Model")
		m.Name = "LibertyProjects"
		local col = C(214, 196, 168)
		local rows = 3
		for r = 0, rows - 1 do
			local z = -d / 2 + 12 + r * (d - 20) / rows
			local bw = w - 10
			local body = wall(m, cf, 0, 0, z + 6, bw, 21, 14, col, "HoodStuccoWorn")
			L.W(m, Vector3.new(bw + 1.5, 4, 8), cf * CFrame.new(0, 23, z + 2.5), C(150, 90, 70), M.ClayRoofTiles, "RoofClayMission")
			L.W(m, Vector3.new(bw + 1.5, 4, 8), cf * CFrame.new(0, 23, z + 9.5) * CFrame.Angles(0, math.pi, 0), C(150, 90, 70), M.ClayRoofTiles, "RoofClayMission")
			local units = math.floor(bw / 12)
			for k = 0, units - 1 do
				local x = -bw / 2 + (k + 0.5) * bw / units
				door(m, cf, x - 2.6, 0.05, z - 1, 3.2, 7.2, C(110, 130, 150), true)
				L.win(m, cf, x + 2.4, 3.2, z - 1, 3.6, 3.8, { bars = true, jalousie = true, ac = L.chance(0.3) })
				L.win(m, cf, x, 13.2, z - 1, 4.4, 3.8, { jalousie = true, shade = L.chance(0.4), ac = L.chance(0.35) })
				L.B(m, cf, x - 2.6, 7.6, z - 2.6, 5, 0.4, 3.2, C(200, 196, 188), M.Concrete)
			end
			if L.chance(0.7) then L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right })) end
			-- laundry line between rows
			L.bar(m, (cf * CFrame.new(-bw / 3, 7, z + 16)).Position, (cf * CFrame.new(bw / 3, 7, z + 16)).Position, 0.08, C(230, 230, 230), M.SmoothPlastic)
		end
		L.BD(m, cf, 0, 0.02, 0, w - 2, 0.1, d - 2, C(140, 128, 100), M.Ground)
		for _ = 1, 6 do L.weeds(m, (cf * CFrame.new(L.r(-w / 2.3, w / 2.3), 0, L.r(-d / 2.3, d / 2.3))).Position) end
		for _ = 1, 2 do L.tree(m, (cf * CFrame.new(L.r(-w / 3, w / 3), 0, L.r(-d / 3, d / 3))).Position, L.r(0.8, 1.1)) end
		L.sign(m, cf * CFrame.new(-w / 2 + 10, 3, -d / 2 + 2), 14, 3.4, "LIBERTY SQUARE", C(30, 60, 110), C(255, 255, 255), Enum.Font.GothamBold, {})
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== SoHo cast-iron loft (4-6 storeys, brick, tall windows, fire escape, boutique at street level) =====
	L.BOUTIQUES = { "MAISON VICE", "ATELIER 305", "SOLE CLUB", "GOLD ROOM", "NOIR", "RAZOR & CO", "THE VAULT", "LUXE", "OCEAN DRIVE SUPPLY", "VELVET", "STUDIO 8", "KAIA", "HAUS", "DRIP LAB", "MONARCH" }
	function L.loft(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "Loft"
		local floors = o.floors or L.ri(4, 6)
		local gh, fh = 16, 12
		local h = gh + (floors - 1) * fh
		local bd = math.min(d - 2, 40)
		local bz = -d / 2 + 1 + bd / 2
		local fz = bz - bd / 2
		local bc = L.pick({ C(150, 84, 64), C(126, 70, 56), C(170, 108, 82), C(110, 92, 80), C(196, 184, 166) })
		local body = L.B(m, cf, 0, 0, bz, w, h, bd, bc, M.Brick, L.pick({ "DowntownBrickOld", "BrickRedClassic", "BrickBrownOld", "DowntownBrickRed" }))
		local trim = L.pick({ C(236, 232, 222), C(40, 40, 42), C(70, 86, 74) })
		-- cornice + parapet
		L.B(m, cf, 0, h, bz - 0.6, w + 1.6, 1.4, bd + 1.2, trim, M.Concrete)
		L.B(m, cf, 0, h + 1.4, bz, w, 1.4, bd, L.shade(bc, 0.9), M.Brick)
		L.BD(m, cf, 0, h - 0.1, bz, w - 1, 0.2, bd - 1, C(60, 60, 62), M.Asphalt, "RoofFlatBitumen")
		-- cast-iron ground floor: columns + big glass + boutique
		local bays = math.max(2, math.floor(w / 10))
		for k = 0, bays do
			L.B(m, cf, -w / 2 + k * w / bays, 0, fz - 0.4, 1.2, gh - 1, 0.8, trim, M.Metal)
		end
		L.BD(m, cf, 0, 0.6, fz - 0.1, w - 2, gh - 4, 0.25, C(34, 40, 46), M.Glass, nil, { Reflectance = 0.25 })
		L.BD(m, cf, 0, gh - 3, fz - 0.5, w, 2.4, 1, trim, M.Metal)
		local name = o.sign or L.pick(L.BOUTIQUES)
		local gold = L.chance(0.4)
		L.sign(m, cf * CFrame.new(0, gh - 1.8, fz - 1.05), math.min(w - 4, #name * 1.4 + 6), 1.8, name, gold and C(20, 20, 22) or C(250, 250, 248), gold and C(222, 190, 110) or C(20, 20, 22), Enum.Font.Merriweather, { lit = true })
		if L.chance(0.6) then L.P(m, Vector3.new(w - 2, 0.3, 4), cf * CFrame.new(0, gh - 4.4, fz - 2.2) * CFrame.Angles(math.rad(-10), 0, 0), C(24, 24, 26), M.Fabric) end
		-- warm interior glow
		local glow = L.BD(m, cf, 0, 1, fz + 1.2, w - 3, gh - 5, 0.2, C(255, 226, 180), M.Neon, nil, { Transparency = 0.55 })
		-- upper floors: tall windows with lintels, some lit
		local wn = math.max(2, math.floor(w / 7))
		for f = 1, floors - 1 do
			local y = gh + (f - 1) * fh + 2
			for k = 0, wn - 1 do
				local x = -w / 2 + (k + 0.5) * w / wn
				L.win(m, cf, x, y, fz, 3.4, 7.4, { trim = trim, shade = L.chance(0.25), glass = L.chance(0.3) and C(120, 100, 70) or nil })
			end
			-- belt course
			L.BD(m, cf, 0, y - 1.6, fz - 0.2, w, 0.5, 0.4, trim, M.Concrete)
		end
		-- fire escape (zig-zag) on half of them
		if L.chance(0.55) and floors >= 4 then
			local fe = C(30, 30, 32)
			for f = 1, floors - 1 do
				local y = gh + (f - 1) * fh
				L.BD(m, cf, 0, y, fz - 2, w * 0.5, 0.25, 3.6, fe, M.Metal, "RustyGrate")
				L.BD(m, cf, 0, y + 3, fz - 3.75, w * 0.5, 0.15, 0.15, fe, M.Metal)
				if f < floors - 1 then
					local dir = (f % 2 == 0) and 1 or -1
					L.D(m, Vector3.new(1.4, 0.2, math.sqrt(fh ^ 2 + (w * 0.4) ^ 2)), cf * CFrame.new(0, y + fh / 2, fz - 2.6) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(dir * math.atan2(fh, w * 0.4), 0, 0), fe, M.Metal)
				end
			end
		end
		-- rooftop water tank (the SoHo skyline)
		if L.chance(0.45) then
			local tc = cf * CFrame.new(L.r(-w / 4, w / 4), h + 2.8, bz + L.r(-bd / 4, bd / 4))
			for _, q in ipairs({ { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } }) do L.B(m, tc, q[1], 0, q[2], 0.5, 6, 0.5, C(40, 40, 40), M.Metal) end
			L.Cyl(m, 8, 8, tc * CFrame.new(0, 10, 0), C(120, 86, 60), M.Wood, "WoodPlanksOld")
			L.Cyl(m, 3, 8.4, tc * CFrame.new(0, 15.3, 0), C(60, 50, 44), M.Wood)
		end
		-- rooftop string lights / lounge
		if o.rooftop or L.chance(0.2) then
			for k = 0, 6 do
				L.D(m, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(-w / 2 + 2 + k * (w - 4) / 6, h + 4.5, fz + 3), C(255, 220, 150), M.Neon, nil, { Shape = Enum.PartType.Ball })
			end
		end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== supercar (generic, no brands): low wedge, big rims, spoiler, underglow =====
	L.SUPER_COLS = { C(255, 200, 0), C(230, 30, 30), C(20, 200, 120), C(250, 110, 20), C(140, 40, 220), C(240, 240, 240), C(20, 20, 22), C(30, 120, 255), C(255, 60, 160), C(120, 255, 60) }
	function L.supercar(par, cf, color, glow)
		color = color or L.pick(L.SUPER_COLS)
		-- realistic mesh car if the asset library has one (recolour the paint panels)
		local A = game:GetService("ServerStorage"):FindFirstChild("VBAssets")
		local src = A and A:FindFirstChild("SuperA")
		if src then
			local m = src:Clone()
			m.Name = "Supercar"
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Paint" then d.Color = color end
			end
			pcall(function() m:ScaleTo(18.5 / (src:GetAttribute("L") or 18.9)) end)
			m:PivotTo(cf)
			m.Parent = par
			if glow ~= false then
				local ug = L.D(m, Vector3.new(6, 0.1, 14), cf * CFrame.new(0, 0.25, 0), L.pick({ C(0, 200, 255), C(255, 0, 200), C(120, 255, 80), C(255, 120, 0) }), M.Neon, nil, { Transparency = 0.35 })
				local pl = Instance.new("PointLight")
				pl.Range = 12
				pl.Brightness = 2
				pl.Color = ug.Color
				pl.Shadows = false
				pl.Parent = ug
			end
			return m
		end
		local m = Instance.new("Model")
		m.Name = "Supercar"
		local wid, len = 7.4, 16
		L.P(m, Vector3.new(wid, 1.6, len - 5), cf * CFrame.new(0, 1.7, 1.2), color, M.SmoothPlastic, nil, { Reflectance = 0.25 })
		L.W(m, Vector3.new(wid, 1.6, 5), cf * CFrame.new(0, 1.7, -len / 2 + 2.5) * CFrame.Angles(0, math.pi, 0), color, M.SmoothPlastic, nil, { Reflectance = 0.25 })
		L.W(m, Vector3.new(wid - 1.2, 1.5, 4.2), cf * CFrame.new(0, 3.25, -1.6) * CFrame.Angles(0, math.pi, 0), C(18, 20, 24), M.Glass, nil, { Reflectance = 0.35 })
		L.P(m, Vector3.new(wid - 1.2, 1.5, 3.2), cf * CFrame.new(0, 3.25, 2.1), C(18, 20, 24), M.Glass, nil, { Reflectance = 0.35 })
		L.W(m, Vector3.new(wid - 1.2, 1.5, 3.4), cf * CFrame.new(0, 3.25, 5.3), color, M.SmoothPlastic)
		-- spoiler
		L.D(m, Vector3.new(wid, 0.25, 1.6), cf * CFrame.new(0, 4.1, len / 2 - 1), C(20, 20, 22), M.Metal)
		for _, x in ipairs({ -2.2, 2.2 }) do L.D(m, Vector3.new(0.3, 1.4, 0.5), cf * CFrame.new(x, 3.3, len / 2 - 1), C(20, 20, 22), M.Metal) end
		-- wheels with chrome rims
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local wc = cf * CFrame.new(sx * (wid / 2 - 0.4), 1.4, sz * (len / 2 - 3.2))
				L.D(m, Vector3.new(1.3, 2.9, 2.9), wc, C(16, 16, 16), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
				L.D(m, Vector3.new(1.36, 2, 2), wc, C(200, 200, 205), M.Metal, nil, { Shape = Enum.PartType.Cylinder, Reflectance = 0.4 })
			end
		end
		L.D(m, Vector3.new(wid - 1.6, 0.35, 0.15), cf * CFrame.new(0, 2.1, -len / 2 + 0.1), C(240, 250, 255), M.Neon)
		L.D(m, Vector3.new(wid - 1, 0.35, 0.15), cf * CFrame.new(0, 2.3, len / 2 + 0.05), C(255, 20, 30), M.Neon)
		if glow ~= false then
			local ug = L.D(m, Vector3.new(wid - 1.2, 0.1, len - 3), cf * CFrame.new(0, 0.3, 0), L.pick({ C(0, 200, 255), C(255, 0, 200), C(120, 255, 80), C(255, 120, 0) }), M.Neon, nil, { Transparency = 0.3 })
			local pl = Instance.new("PointLight")
			pl.Range = 12
			pl.Brightness = 2
			pl.Color = ug.Color
			pl.Shadows = false
			pl.Parent = ug
		end
		m.Parent = par
		return m
	end

	-- ===== asset yacht (or part-built fallback). cf = position on the water surface, -Z = bow =====
	function L.yacht(par, cf, len, kind)
		local A = game:GetService("ServerStorage"):FindFirstChild("VBAssets")
		local name = (kind == "super") and "YachtSuper" or "YachtMotor"
		-- the lite copy (railings / tiny trim stripped, 226 parts instead of 1137) everywhere except hero spots
		local src = A and ((kind == "motor" and A:FindFirstChild("YachtMotorLite")) or A:FindFirstChild(name))
		if src then
			local m = src:Clone()
			local s = len / (src:GetAttribute("L") or len)
			pcall(function() m:ScaleTo(s) end)
			local draft = (kind == "super") and 0.1 or 0.12
			m:PivotTo(cf * CFrame.new(0, -(src:GetAttribute("H") or 20) * s * draft, 0))
			m.Parent = par
			return m
		end
		return L.boat(par, cf, len)
	end
	-- small part-built boats (center console / speedboat) for the slips
	function L.boat(par, cf, len, color)
		local m = Instance.new("Model")
		m.Name = "Boat"
		len = len or 26
		local w = len * 0.32
		color = color or L.pick({ C(245, 245, 245), C(240, 240, 236), C(30, 60, 110), C(200, 30, 40), C(240, 240, 236) })
		L.P(m, Vector3.new(w, len * 0.12, len * 0.72), cf * CFrame.new(0, len * 0.03, len * 0.1), color, M.SmoothPlastic)
		for side = -1, 1, 2 do
			L.W(m, Vector3.new(len * 0.12, w / 2, len * 0.28), cf * CFrame.new(side * w / 4, len * 0.03, -len * 0.39) * CFrame.Angles(0, 0, -side * math.pi / 2), color, M.SmoothPlastic)
		end
		L.D(m, Vector3.new(w * 1.01, len * 0.03, len * 0.72), cf * CFrame.new(0, -len * 0.015, len * 0.1), C(25, 40, 70), M.SmoothPlastic)
		L.D(m, Vector3.new(w * 0.82, 0.2, len * 0.6), cf * CFrame.new(0, len * 0.09, len * 0.12), C(200, 175, 130), M.WoodPlanks, "WoodPlanksOld")
		L.D(m, Vector3.new(w * 0.5, len * 0.1, len * 0.12), cf * CFrame.new(0, len * 0.14, -len * 0.02), C(30, 40, 50), M.Glass, nil, { Transparency = 0.3 })
		L.D(m, Vector3.new(w * 0.7, 0.3, len * 0.2), cf * CFrame.new(0, len * 0.27, 0.02 * len), C(240, 240, 240), M.SmoothPlastic)
		L.D(m, Vector3.new(1.4, 2.6, 1.4), cf * CFrame.new(0, len * 0.08, len * 0.47), C(30, 30, 32), M.Metal)
		m.Parent = par
		return m
	end
	-- floating dock: main walkway with finger piers, cleats, lamp posts. cf at water level, runs along -Z
	function L.dock(par, cf, len, fingers, fingerLen, side)
		local m = L.model(par, "Dock")
		local deck = C(176, 150, 114)
		L.P(m, Vector3.new(10, 1.6, len), cf * CFrame.new(0, 1.2, -len / 2), deck, M.WoodPlanks, "WoodPlanksOld")
		for z = 6, len - 4, 24 do
			L.D(m, Vector3.new(0.8, 5, 0.8), cf * CFrame.new(-5.2, -1, -z), C(90, 70, 50), M.Wood)
			L.D(m, Vector3.new(0.8, 5, 0.8), cf * CFrame.new(5.2, -1, -z), C(90, 70, 50), M.Wood)
		end
		local n = fingers or math.floor(len / 30)
		for k = 1, n do
			local z = k * len / (n + 1)
			for _, sd in ipairs(side and { side } or { -1, 1 }) do
				local fc = cf * CFrame.new(sd * (5 + fingerLen / 2), 1.1, -z)
				L.P(m, Vector3.new(fingerLen, 1.4, 4), fc, deck, M.WoodPlanks, "WoodPlanksOld")
				L.D(m, Vector3.new(0.6, 0.6, 1.4), fc * CFrame.new(sd * fingerLen / 2 - sd * 1, 0.9, 0), C(220, 220, 220), M.Metal)
				-- utility pedestal
				L.D(m, Vector3.new(1, 3, 1), cf * CFrame.new(sd * 4.2, 3.5, -z), C(236, 236, 236), M.SmoothPlastic)
				L.D(m, Vector3.new(0.8, 0.4, 0.8), cf * CFrame.new(sd * 4.2, 5.1, -z), C(80, 200, 255), M.Neon)
			end
		end
		return m
	end
	-- lifeguard tower (pastel, Miami Beach style)
	function L.lifeguard(par, cf, col)
		local m = L.model(par, "LifeguardTower")
		col = col or L.pick({ C(255, 140, 170), C(90, 210, 220), C(255, 210, 80), C(150, 120, 230), C(120, 220, 140) })
		for _, q in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do L.B(m, cf, q[1], 0, q[2], 0.8, 8, 0.8, C(236, 236, 236), M.Wood) end
		L.B(m, cf, 0, 8, 0, 11, 0.6, 11, C(236, 236, 236), M.Wood)
		L.B(m, cf, 0, 8.6, 1, 9, 7, 7, col, M.Plaster)
		L.BD(m, cf, 0, 10.6, -2.6, 7, 3, 0.2, C(40, 60, 70), M.Glass)
		L.W(m, Vector3.new(10, 2.4, 8), cf * CFrame.new(0, 16.8, 1), C(240, 240, 240), M.Plaster)
		L.P(m, Vector3.new(3, 0.4, 9), cf * CFrame.new(0, 4.2, -8) * CFrame.Angles(math.rad(-35), 0, 0), C(236, 236, 236), M.Wood)
		L.B(m, cf, 4.5, 15.5, 4, 0.2, 6, 0.2, C(200, 200, 200), M.Metal)
		L.BD(m, cf, 5.6, 19.5, 4, 2, 1.4, 0.1, C(255, 60, 40), M.Fabric)
		return m
	end
	-- beach umbrella + two loungers
	function L.umbrella(par, cf, col)
		local m = L.model(par, "Umbrella")
		col = col or L.pick({ C(240, 90, 120), C(60, 170, 220), C(250, 210, 60), C(240, 240, 236), C(60, 190, 150) })
		L.Cyl(m, 8, 0.3, cf * CFrame.new(0, 4, 0), C(236, 236, 236), M.Metal)
		-- canopy: shallow cone made of a flat disc + a smaller raised disc (cylinders lie along X, so roll them upright)
		L.Cyl(m, 0.5, 9, cf * CFrame.new(0, 8, 0), col, M.Fabric)
		L.Cyl(m, 0.5, 5, cf * CFrame.new(0, 8.45, 0), L.shade(col, 0.92), M.Fabric)
		L.Cyl(m, 0.4, 1, cf * CFrame.new(0, 8.85, 0), C(236, 236, 236), M.Metal)
		for sx = -1, 1, 2 do
			L.B(m, cf * CFrame.new(sx * 3, 0, 2), 0, 0, 0, 2.2, 0.8, 6, C(250, 250, 248), M.Plastic)
			L.D(m, Vector3.new(2.2, 0.4, 2.4), cf * CFrame.new(sx * 3, 1.4, 4.4) * CFrame.Angles(math.rad(40), 0, 0), C(250, 250, 248), M.Plastic)
		end
		return m
	end

	-- ===== Florida ranch house (suburb): stucco, barrel tile hip roof, lawn, palms, hedges, driveway =====
	L.SUBURB_COLS = { C(240, 234, 220), C(230, 220, 196), C(220, 230, 226), C(242, 226, 214), C(226, 230, 240), C(236, 222, 190) }
	function L.flhouse(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = "SuburbHouse"
		local col = o.color or L.pick(L.SUBURB_COLS)
		local bw = math.min(w - 16, L.r(34, 44))
		local bd = math.min(d - 22, L.r(28, 34))
		local bx = -w / 2 + 4 + bw / 2
		local bz = -d / 2 + 18 + bd / 2
		local fz = bz - bd / 2
		local h = 12
		L.BD(m, cf, 0, 0.02, 0, w - 1, 0.1, d - 1, C(96, 128, 64), M.Grass)
		wall(m, cf, bx, 0, bz, bw, h, bd, col, "StuccoSuburb")
		local rc = L.pick({ C(186, 112, 80), C(164, 96, 70), C(120, 116, 110), C(200, 136, 100) })
		local tile = rc.R > 0.6
		for sd = -1, 1, 2 do
			L.W(m, Vector3.new(bw + 3, 6, bd / 2 + 1.5), cf * CFrame.new(bx, h + 3, bz + sd * (bd / 4 + 0.75)) * CFrame.Angles(0, sd > 0 and math.pi or 0, 0), rc, tile and M.ClayRoofTiles or M.RoofShingles, tile and "RoofClayMission" or "RoofShinglesGrey")
		end
		L.BD(m, cf, bx, h - 0.6, bz, bw + 3, 0.6, bd + 3, C(250, 250, 248), M.Wood)
		-- entry with arch + white door, windows with white trim + shutters
		door(m, cf, bx - bw / 4, 0.4, fz, 4, 8, C(250, 250, 248))
		L.B(m, cf, bx - bw / 4, 0, fz - 3, 8, 0.4, 6, C(200, 190, 176), M.Concrete, "PlazaTiles")
		for _, x in ipairs({ bx + bw / 6, bx + bw / 2.6 }) do
			L.win(m, cf, x, 3.4, fz, 5, 5, { trim = C(250, 250, 248), shade = L.chance(0.3) })
		end
		-- garage
		local gx = bx + bw / 2 + 9
		if gx + 9 < w / 2 then
			wall(m, cf, gx, 0, bz + 2, 18, 10, bd - 4, col, "StuccoSuburb")
			L.B(m, cf, gx, 0.2, bz + 2 - (bd - 4) / 2 - 0.2, 14, 8.4, 0.3, C(250, 250, 248), M.Metal, "ShutterPainted")
			L.W(m, Vector3.new(19, 4, (bd - 4) / 2), cf * CFrame.new(gx, 12, bz + 2 - (bd - 4) / 4), rc, tile and M.ClayRoofTiles or M.RoofShingles, tile and "RoofClayMission" or "RoofShinglesGrey")
			L.W(m, Vector3.new(19, 4, (bd - 4) / 2), cf * CFrame.new(gx, 12, bz + 2 + (bd - 4) / 4) * CFrame.Angles(0, math.pi, 0), rc, tile and M.ClayRoofTiles or M.RoofShingles, tile and "RoofClayMission" or "RoofShinglesGrey")
			local dl = bz + 2 - (bd - 4) / 2 + d / 2
			L.BD(m, cf, gx, 0.04, -d / 2 + dl / 2, 15, 0.15, dl, C(200, 196, 188), M.Concrete, "ConcreteDriveway")
			if L.chance(0.7) then L.car(m, cf * CFrame.new(gx, 0.2, -d / 2 + 10) * CFrame.Angles(0, math.pi, 0)) end
		end
		-- landscaping: hedges along the house, palms, a tree, mailbox
		for k = 0, 3 do L.bush(m, (cf * CFrame.new(bx - bw / 2 + 4 + k * (bw / 4), 0, fz - 2.5)).Position, L.r(3, 4.5)) end
		L.palm(m, (cf * CFrame.new(-w / 2 + 5, 0, -d / 2 + 8)).Position, L.r(24, 34))
		if L.chance(0.6) then L.palm(m, (cf * CFrame.new(-w / 2 + 9, 0, -d / 2 + 12)).Position, L.r(20, 28)) end
		if L.chance(0.5) then L.tree(m, (cf * CFrame.new(w / 2 - 8, 0, d / 2 - 10)).Position, L.r(0.9, 1.2)) end
		L.B(m, cf, w / 2 - 3, 0, -d / 2 + 2, 0.4, 3.6, 0.4, C(40, 40, 40), M.Metal)
		L.B(m, cf, w / 2 - 3, 3.6, -d / 2 + 2, 1.2, 1, 2, C(40, 40, 40), M.Metal)
		if o.pool ~= false and L.chance(0.45) then
			L.BD(m, cf, bx, 0.05, bz + bd / 2 + 8, 16, 0.3, 9, C(214, 206, 192), M.Concrete, "PlazaTiles")
			L.BD(m, cf, bx, 0.25, bz + bd / 2 + 8, 12, 0.2, 6, C(50, 180, 210), M.Glass, nil, { Transparency = 0.2 })
		end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== modern villa / mansion (islands, Coral Heights): stacked white boxes, glass, pool, palms, dock =====
	function L.mansion(par, cf, w, d, o)
		o = o or {}
		if L.luxHouse and not o.legacy then
			return L.luxHouse(par, cf, w, d, { dock = o.dock, name = o.name, price = o.price, style = o.style, yacht = o.yacht })
		end
		local m = Instance.new("Model")
		m.Name = o.name or "Villa"
		local WH, GL = C(244, 244, 240), C(70, 100, 116)
		L.BD(m, cf, 0, 0.02, 0, w - 2, 0.12, d - 2, C(92, 132, 64), M.Grass)
		local bw, bd = w * 0.62, d * 0.42
		local bz = d * 0.05
		-- ground floor: glass box with white slab frame
		L.P(m, Vector3.new(bw, 12, bd), cf * CFrame.new(0, 6, bz), GL, M.Glass, nil, { Reflectance = 0.3 })
		L.P(m, Vector3.new(bw + 6, 1.4, bd + 6), cf * CFrame.new(0, 12.7, bz), WH, M.Concrete, "ConcretePlain")
		-- upper floor shifted (cantilever), stone feature wall, roof slab
		L.P(m, Vector3.new(bw * 0.8, 11, bd * 0.9), cf * CFrame.new(bw * 0.12, 18.9, bz + 2), WH, M.Plaster, "StuccoWhite")
		L.D(m, Vector3.new(bw * 0.6, 7, 0.3), cf * CFrame.new(bw * 0.12, 18.9, bz + 2 - bd * 0.45 - 0.1), GL, M.Glass, nil, { Reflectance = 0.3 })
		L.P(m, Vector3.new(bw * 0.9, 1.2, bd), cf * CFrame.new(bw * 0.12, 25, bz + 2), WH, M.Concrete, "ConcretePlain")
		L.P(m, Vector3.new(4, 24, bd * 0.7), cf * CFrame.new(-bw / 2 - 2, 12, bz), C(170, 150, 126), M.Sandstone, "DowntownStoneBlocks")
		-- pool deck + pool + loungers + palms
		local pz = bz + bd / 2 + 12
		L.BD(m, cf, 0, 0.05, pz, bw + 10, 0.4, 20, C(222, 214, 200), M.Concrete, "PlazaTiles")
		L.BD(m, cf, 0, 0.3, pz, bw * 0.6, 0.3, 10, C(40, 190, 220), M.Glass, nil, { Transparency = 0.15 })
		for k = -2, 2 do L.B(m, cf, k * 5, 0.45, pz + 7, 2, 0.8, 5, WH, M.Fabric) end
		for _, q in ipairs({ { -w / 2 + 6, -d / 2 + 6 }, { w / 2 - 6, -d / 2 + 6 }, { -w / 2 + 6, d / 2 - 6 }, { w / 2 - 6, d / 2 - 6 }, { bw / 2 + 8, pz } }) do
			L.palm(m, (cf * CFrame.new(q[1], 0, q[2])).Position, L.r(28, 40), L.chance(0.3) and "hero" or nil)
		end
		-- motor court + gate + supercar
		L.BD(m, cf, 0, 0.06, -d / 2 + 10, bw * 0.7, 0.3, 18, C(214, 206, 192), M.Pavement, "HerringbonePavers")
		L.supercar(m, cf * CFrame.new(-bw * 0.15, 0.3, -d / 2 + 10) * CFrame.Angles(0, math.pi / 2, 0), nil, false)
		for sx = -1, 1, 2 do L.B(m, cf, sx * (bw * 0.35 + 3), 0, -d / 2 + 1.5, 3, 7, 3, WH, M.Plaster, "StuccoWhite") end
		L.BD(m, cf, 0, 0, -d / 2 + 1.5, bw * 0.7, 6, 0.4, C(30, 30, 32), M.Metal, nil, { Transparency = 0.3 })
		for k = 0, math.floor(w / 8) do L.bush(m, (cf * CFrame.new(-w / 2 + 2 + k * 8, 0, -d / 2 + 3)).Position, 4) end
		if o.dock then
			local dc = cf * CFrame.new(0, L.WATER - L.G, d / 2 + 6)
			L.P(m, Vector3.new(8, 1.4, 34), dc * CFrame.new(0, 1, 17), C(176, 150, 114), M.WoodPlanks, "WoodPlanksOld")
			L.yacht(m, dc * CFrame.new(14, 0, 22) * CFrame.Angles(0, 0, 0), L.r(50, 70), "motor")
		end
		if o.price then L.poi((cf * CFrame.new(0, 0, -d / 2 + 6)).Position, "Property", o.name or "Villa", { Price = o.price, Tier = 5 }) end
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== strip mall (county): long one-storey row with a parking lot in front =====
	function L.stripmall(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "StripMall"
		local bd = 34
		local bz = d / 2 - bd / 2 - 2
		local fz = bz - bd / 2
		local col = L.pick({ C(236, 226, 206), C(226, 218, 200), C(214, 222, 226) })
		wall(m, cf, 0, 0, bz, w - 4, 16, bd, col, "StuccoSuburb")
		L.B(m, cf, 0, 16, bz - bd / 2 + 2, w - 4, 4, 4, L.shade(col, 0.92), M.Plaster, "StuccoSuburb")
		L.B(m, cf, 0, 10, fz - 5, w - 4, 1.2, 10, L.shade(col, 0.95), M.Concrete)
		local n = math.floor((w - 4) / 22)
		local names = { "PIZZA", "NAILS", "SUB SHOP", "PHARMACY", "DRY CLEAN", "SMOOTHIES", "INSURANCE", "TACOS", "VET CLINIC", "DENTIST", "PHONE FIX", "BAGELS", "YOGA", "FITNESS", "SUSHI" }
		for k = 0, n - 1 do
			local x = -(w - 4) / 2 + (k + 0.5) * (w - 4) / n
			L.BD(m, cf, x, 0.6, fz - 0.1, (w - 4) / n - 3, 8.5, 0.25, C(40, 50, 58), M.Glass, nil, { Reflectance = 0.25 })
			L.B(m, cf, x - (w - 4) / n / 2, 0, fz - 9.4, 1.2, 10, 1.2, L.shade(col, 0.9), M.Concrete)
			local nm = L.pick(names)
			L.sign(m, cf * CFrame.new(x, 17.6, fz - 0.4), math.min((w - 4) / n - 4, #nm * 1.8 + 6), 2.6, nm, C(250, 250, 248), L.pick({ C(200, 30, 30), C(20, 60, 140), C(20, 120, 60), C(30, 30, 30) }), Enum.Font.GothamBlack, { lit = true })
		end
		local pd = d - bd - 6
		L.BD(m, cf, 0, 0.04, -d / 2 + pd / 2, w - 2, 0.15, pd, C(96, 96, 100), M.Asphalt, "ParkingLotAsphalt")
		for k = 0, math.floor((w - 10) / 10) do
			L.BD(m, cf, -w / 2 + 6 + k * 10, 0.2, -d / 2 + pd / 2, 0.4, 0.02, 16, C(240, 240, 236), M.SmoothPlastic)
			if L.chance(0.4) then L.car(m, cf * CFrame.new(-w / 2 + 11 + k * 10, 0.2, -d / 2 + pd / 2) * CFrame.Angles(0, L.chance(0.5) and 0 or math.pi, 0)) end
		end
		for k = 0, 2 do L.palm(m, (cf * CFrame.new(-w / 3 + k * w / 3, 0, -d / 2 + 3)).Position, L.r(26, 34)) end
		local py = L.B(m, cf, w / 2 - 6, 0, -d / 2 + 3, 2, 22, 2, C(120, 120, 124), M.Metal)
		local pl = L.BD(m, cf, w / 2 - 6, 22, -d / 2 + 3, 10, 7, 1.2, C(250, 250, 248), M.SmoothPlastic)
		L.text(pl, Enum.NormalId.Front, o.sign or "CORAL PLAZA", { font = Enum.Font.GothamBlack, color = C(20, 80, 140), pps = 12, dist = 500 })
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== fire station (red brick, 3 bays, tower) =====
	function L.firestation(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = o.name or "FireStation"
		local bd = d - 30
		local bz = d / 2 - bd / 2 - 2
		local fz = bz - bd / 2
		L.B(m, cf, 0, 0, bz, w - 6, 22, bd, C(150, 70, 56), M.Brick, "DowntownBrickRed")
		L.B(m, cf, 0, 22, bz, w - 5, 1.6, bd + 1, C(236, 232, 222), M.Concrete)
		for k = -1, 1 do
			L.B(m, cf, k * 16, 0.2, fz - 0.2, 12, 14, 0.3, C(230, 40, 40), M.Metal, "ShutterPainted")
			L.BD(m, cf, k * 16, 14.2, fz - 0.3, 13, 1, 0.5, C(236, 232, 222), M.Concrete)
		end
		L.B(m, cf, w / 2 - 10, 0, bz + bd / 4, 10, 40, 10, C(150, 70, 56), M.Brick, "DowntownBrickRed")
		L.sign(m, cf * CFrame.new(0, 18.5, fz - 0.4), 34, 3, o.sign or "CORAL COUNTY FIRE RESCUE  STATION 1", C(236, 232, 222), C(160, 20, 20), Enum.Font.Merriweather, {})
		L.BD(m, cf, 0, 0.05, -d / 2 + 13, w - 8, 0.2, 26, C(200, 196, 188), M.Concrete, "ConcreteDriveway")
		L.B(m, cf, -w / 2 + 6, 0, -d / 2 + 4, 0.5, 26, 0.5, C(200, 200, 200), M.Metal)
		L.BD(m, cf, -w / 2 + 8.5, 23, -d / 2 + 4, 4.5, 3, 0.1, C(30, 60, 140), M.Fabric)
		m.Parent = par
		L.lod(m)
		return m
	end
end
