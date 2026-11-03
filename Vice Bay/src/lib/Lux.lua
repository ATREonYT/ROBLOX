-- Vice Bay: detail library (signage, curtain-wall windows, furniture, luxury houses, mangroves, marina kit)
return function(L)
	local M, C = L.M, L.C
	local WHITE = C(240, 240, 236)
	local INK = C(24, 24, 26)

	-- =====================================================================================
	-- SIGNAGE: channel letters, lightboxes, hand-painted wall signs, blade signs
	-- =====================================================================================
	L.FONTS_BOLD = { Enum.Font.GothamBlack, Enum.Font.Oswald, Enum.Font.RobotoCondensed, Enum.Font.Michroma, Enum.Font.TitilliumWeb, Enum.Font.DenkOne, Enum.Font.Sarpanch }
	L.FONTS_PAINT = { Enum.Font.Bangers, Enum.Font.LuckiestGuy, Enum.Font.PermanentMarker, Enum.Font.FredokaOne, Enum.Font.SpecialElite, Enum.Font.Kalam }
	L.FONTS_CLASSY = { Enum.Font.Merriweather, Enum.Font.Bodoni, Enum.Font.Garamond, Enum.Font.JosefinSans, Enum.Font.Nunito }
	L.TAGLINES = {
		["FOOD MART"] = "GROCERIES • DELI • ATM", ["WASH N FOLD"] = "COIN LAUNDRY • OPEN 7 DAYS", ["WIRELESS 4 LESS"] = "PHONES • PLANS • REPAIRS",
		["TIRES"] = "NEW & USED • FLATS FIXED", ["BEAUTY SUPPLY"] = "HAIR • NAILS • WIGS", ["BARBER SHOP"] = "FADES • LINE UPS • WALK INS",
		["PHONE REPAIR"] = "SCREENS • BATTERIES • UNLOCKS", ["WINGS"] = "OPEN LATE • 10 FLAVORS", ["99 CENT"] = "EVERYTHING 99¢ & UP",
		["COFFEE"] = "ESPRESSO • PASTRIES", ["BAKERY"] = "FRESH DAILY", ["TACOS"] = "AUTHENTIC • DRIVE THRU", ["PIZZA"] = "BY THE SLICE",
	}
	local function tagline(name)
		if L.TAGLINES[name] then return L.TAGLINES[name] end
		return L.pick({ "EST. " .. L.ri(1968, 2019), "OPEN 7 DAYS", "SINCE " .. L.ri(1972, 2015), "WALK INS WELCOME", "FAMILY OWNED", "MIAMI • FL" })
	end
	local function label(part, face, txt, o)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = o.pps or 30
		g.LightInfluence = o.light or 0.4
		g.Brightness = o.bright or 1.2
		g.MaxDistance = o.dist or 320
		g.Parent = part
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = o.size or UDim2.fromScale(0.94, 0.86)
		t.Position = o.pos or UDim2.fromScale(0.03, 0.07)
		t.Text = txt
		t.TextScaled = true
		t.Font = o.font or Enum.Font.GothamBlack
		t.TextColor3 = o.color or WHITE
		t.TextXAlignment = o.xa or Enum.TextXAlignment.Center
		t.Rotation = o.rot or 0
		t.TextTransparency = o.trans or 0
		t.Parent = g
		if o.stroke then
			local s = Instance.new("UIStroke")
			s.Color = o.stroke
			s.Thickness = o.strokeT or 2
			s.Transparency = o.strokeTr or 0
			s.Parent = t
		end
		if o.grad then
			local gr = Instance.new("UIGradient")
			gr.Color = ColorSequence.new(o.grad[1], o.grad[2])
			gr.Rotation = 90
			gr.Parent = t
		end
		return t, g
	end
	L.label = label

	-- cf = centre of the sign band on the facade, local -Z points out to the street
	function L.storeSign(m, cf, maxW, name, o)
		o = o or {}
		local style = o.style or (o.rundown and L.pick({ "painted", "painted", "lightbox", "channel" }) or L.pick({ "channel", "lightbox", "channel", "classy" }))
		local len = #name
		local w = math.min(maxW, len * 1.75 + 5)
		local h = o.h or 3.2
		local pal = o.pal or L.pick({
			{ C(196, 30, 30), WHITE }, { C(250, 200, 30), C(20, 20, 20) }, { C(20, 60, 150), WHITE }, { C(20, 120, 70), WHITE },
			{ C(30, 30, 32), C(255, 210, 90) }, { WHITE, C(200, 30, 40) }, { C(120, 30, 120), WHITE }, { C(240, 120, 30), WHITE },
		})
		if style == "channel" then
			-- raceway + individual lit letters, a thin halo stroke
			L.D(m, Vector3.new(w * 0.9, 0.5, 0.5), cf * CFrame.new(0, -h * 0.28, -0.25), C(60, 62, 66), M.Metal)
			local p = L.D(m, Vector3.new(w, h, 0.4), cf * CFrame.new(0, 0, -0.55), WHITE, M.SmoothPlastic, nil, { Transparency = 1 })
			p.Name = "Sign"
			label(p, Enum.NormalId.Front, name, { font = o.font or L.pick(L.FONTS_BOLD), color = pal[2] == WHITE and pal[1] or pal[2], stroke = C(250, 250, 250), strokeT = 1.4, strokeTr = 0.4, light = 0, bright = 1.6, pps = 26 })
			if o.sub ~= false then
				local s2 = L.D(m, Vector3.new(w * 0.8, h * 0.32, 0.2), cf * CFrame.new(0, -h * 0.72, -0.4), WHITE, M.SmoothPlastic, nil, { Transparency = 1 })
				label(s2, Enum.NormalId.Front, tagline(name), { font = Enum.Font.GothamMedium, color = C(230, 230, 226), light = 0.6, pps = 30 })
			end
			local sl = Instance.new("SurfaceLight")
			sl.Face = Enum.NormalId.Front
			sl.Range = 8
			sl.Brightness = 0.6
			sl.Color = pal[1]
			sl.Shadows = false
			sl.Parent = p
		elseif style == "lightbox" then
			-- aluminium cabinet, acrylic face with the name and a tagline strip
			local box = L.D(m, Vector3.new(w, h + 0.8, 0.9), cf * CFrame.new(0, 0, -0.45), C(70, 72, 76), M.Metal)
			local face = L.D(m, Vector3.new(w - 0.5, h + 0.3, 0.1), cf * CFrame.new(0, 0, -0.95), pal[1], M.SmoothPlastic)
			face.Name = "Sign"
			label(face, Enum.NormalId.Front, name, { font = o.font or L.pick(L.FONTS_BOLD), color = pal[2], size = UDim2.fromScale(0.92, 0.62), pos = UDim2.fromScale(0.04, 0.06), light = 0, bright = 1.3 })
			label(face, Enum.NormalId.Front, tagline(name), { font = Enum.Font.GothamBold, color = pal[2], size = UDim2.fromScale(0.8, 0.22), pos = UDim2.fromScale(0.1, 0.72), light = 0, bright = 1.1, trans = 0.1 })
			if o.rundown then
				-- yellowed, one corner dead, a crack
				face.Color = L.shade(pal[1], 0.82)
				L.D(m, Vector3.new(w * 0.22, h * 0.5, 0.05), cf * CFrame.new(w * 0.36, h * 0.2, -1.02), C(40, 36, 30), M.SmoothPlastic, nil, { Transparency = 0.55 })
				L.D(m, Vector3.new(0.08, h * 0.9, 0.04), cf * CFrame.new(L.r(-w / 3, w / 3), 0, -1.02) * CFrame.Angles(0, 0, L.r(-0.4, 0.4)), C(30, 30, 30), M.SmoothPlastic)
			end
			local sl = Instance.new("SurfaceLight")
			sl.Face = Enum.NormalId.Front
			sl.Range = 9
			sl.Brightness = o.rundown and 0.3 or 0.8
			sl.Color = WHITE
			sl.Shadows = false
			sl.Parent = face
			box.Name = "SignBox"
		elseif style == "classy" then
			-- dark fascia panel with thin serif gold letters (boutiques, restaurants)
			local p = L.D(m, Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, -0.2), C(26, 28, 30), M.Metal)
			p.Name = "Sign"
			label(p, Enum.NormalId.Front, name, { font = o.font or L.pick(L.FONTS_CLASSY), color = C(222, 190, 120), light = 0.2, bright = 1.4, size = UDim2.fromScale(0.9, 0.7), pos = UDim2.fromScale(0.05, 0.15) })
			for sd = -1, 1, 2 do L.D(m, Vector3.new(0.3, 0.3, 1.2), cf * CFrame.new(sd * w * 0.35, h / 2 + 0.6, -0.8), C(30, 30, 30), M.Metal) end
		else
			-- hand-painted straight onto the wall: faded colour block, slightly crooked letters, drips
			local bg = L.D(m, Vector3.new(w, h + 0.6, 0.06), cf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, 0, L.r(-0.015, 0.015)), pal[1], M.Plaster, nil, { Transparency = L.r(0.05, 0.25) })
			bg.Name = "Sign"
			label(bg, Enum.NormalId.Front, name, { font = o.font or L.pick(L.FONTS_PAINT), color = pal[2], rot = L.r(-2, 2), light = 1, bright = 1, stroke = C(20, 20, 20), strokeT = 1, strokeTr = 0.5 })
			for _ = 1, L.ri(1, 4) do
				L.D(m, Vector3.new(0.18, L.r(0.6, 1.8), 0.04), cf * CFrame.new(L.r(-w / 2.3, w / 2.3), -h / 2 - 0.6, -0.09), pal[1], M.Plaster, nil, { Transparency = 0.3 })
			end
		end
		-- blade sign sticking out from the wall for some shops
		if o.blade ~= false and L.chance(o.bladeChance or 0.3) then
			local bc = cf * CFrame.new(w / 2 + 1.6, 1.6, -2.4) * CFrame.Angles(0, math.pi / 2, 0)
			L.D(m, Vector3.new(4.2, 0.25, 0.25), cf * CFrame.new(w / 2 + 1.6, 3.8, -2.2) * CFrame.Angles(0, math.pi / 2, 0), C(40, 40, 42), M.Metal)
			local b = L.D(m, Vector3.new(3.4, 3.4, 0.35), bc, pal[1], M.SmoothPlastic)
			local short = name:match("^(%S+)") or name
			label(b, Enum.NormalId.Front, short, { font = L.pick(L.FONTS_BOLD), color = pal[2], light = 0.2, bright = 1.2 })
			label(b, Enum.NormalId.Back, short, { font = L.pick(L.FONTS_BOLD), color = pal[2], light = 0.2, bright = 1.2 })
		end
	end

	-- window decals for a storefront (hours, OPEN neon, credit cards, specials)
	function L.storeWindow(m, cf, w, o)
		o = o or {}
		if L.chance(0.5) then
			local op = L.D(m, Vector3.new(2.8, 1.1, 0.08), cf * CFrame.new(-w / 4, 5.6, -0.12), C(255, 50, 70), M.Neon)
			label(op, Enum.NormalId.Front, "OPEN", { font = Enum.Font.GothamBlack, color = WHITE, light = 0, bright = 2 })
			L.D(m, Vector3.new(3, 0.08, 0.04), cf * CFrame.new(-w / 4, 6.25, -0.12), C(40, 120, 255), M.Neon)
		end
		local hrs = L.D(m, Vector3.new(1.6, 2.2, 0.03), cf * CFrame.new(w / 4, 4.4, -0.1), WHITE, M.SmoothPlastic, nil, { Transparency = 0.15 })
		label(hrs, Enum.NormalId.Front, "HOURS\nMON-SAT 8-10\nSUN 9-8", { font = Enum.Font.GothamMedium, color = INK, light = 1, pps = 40 })
		if o.rundown then
			for _ = 1, L.ri(1, 3) do
				local px = L.D(m, Vector3.new(L.r(1.6, 2.6), L.r(2, 3.2), 0.03), cf * CFrame.new(L.r(-w / 2.6, w / 2.6), L.r(3, 6), -0.11), L.pick({ C(250, 220, 60), C(255, 255, 255), C(220, 50, 50), C(80, 180, 240) }), M.SmoothPlastic)
				label(px, Enum.NormalId.Front, L.pick({ "EBT\nACCEPTED", "COLD\nDRINKS", "SALE\nTODAY", "ATM\nINSIDE", "2 FOR\n$5", "HOT\nFOOD", "NOW\nHIRING", "PHONE\nCARDS" }), { font = Enum.Font.GothamBlack, color = INK, light = 1, pps = 30 })
			end
		end
	end

	-- =====================================================================================
	-- CURTAIN WALL: mullion grid, spandrel bands, blinds and a few warm lit windows on a glass face
	-- =====================================================================================
	function L.windowGrid(part, face, o)
		o = o or {}
		local s = part.Size
		local fw, fh
		if face == Enum.NormalId.Left or face == Enum.NormalId.Right then fw, fh = s.Z, s.Y
		elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then return
		else fw, fh = s.X, s.Y end
		if fw < 6 or fh < 6 then return end
		local colW, rowH = o.col or 5, o.row or 12
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.CanvasSize = Vector2.new(math.clamp(math.floor(fw * 4), 32, 1024), math.clamp(math.floor(fh * 4), 32, 1024))
		g.LightInfluence = 1
		g.MaxDistance = o.dist or 1400
		g.Parent = part
		local mull = o.mull or C(30, 34, 38)
		local nc = math.max(1, math.floor(fw / colW))
		local nr = math.max(1, math.floor(fh / rowH))
		local function fr(x, y, w, h, c, tr)
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = c
			f.BackgroundTransparency = tr or 0
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w, h)
			f.Parent = g
			return f
		end
		local mw = math.max(0.004, 0.22 / fw)
		for k = 1, nc - 1 do fr(k / nc - mw / 2, 0, mw, 1, mull, 0.05) end
		local sh = math.min(0.4, 1.6 / fh)
		for r = 1, nr do
			local y = 1 - r / nr
			fr(0, y, 1, sh, o.spandrel or C(46, 52, 58), 0.1)
			fr(0, y + 1 / nr * 0.82, 1, mw * 0.6 * fw / fh, mull, 0.3)
		end
		-- blinds and lit rooms (random but stable per part)
		local rr = Random.new(math.floor(part.Position.X * 13 + part.Position.Y * 7 + part.Position.Z))
		local nb = math.min(30, math.floor(nc * nr * 0.08))
		for _ = 1, nb do
			local cx, cy = rr:NextInteger(0, nc - 1), rr:NextInteger(0, nr - 1)
			local depth = rr:NextNumber() * 0.6 + 0.2
			fr(cx / nc + mw, cy / nr + sh, 1 / nc - mw * 2, (1 / nr - sh) * depth, C(214, 210, 198), 0.35)
		end
		local nl = math.min(18, math.floor(nc * nr * 0.04))
		for _ = 1, nl do
			local cx, cy = rr:NextInteger(0, nc - 1), rr:NextInteger(0, nr - 1)
			fr(cx / nc + mw, cy / nr + sh, 1 / nc - mw * 2, 1 / nr - sh - 0.002, C(255, 214, 150), 0.72)
		end
		return g
	end
	function L.glassFaces(part, o)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do L.windowGrid(part, f, o) end
	end

	-- =====================================================================================
	-- FURNITURE (cf at floor level, local -Z = the side you use it from)
	-- =====================================================================================
	local F = {}
	L.F = F
	local FAB = { C(214, 208, 196), C(176, 170, 160), C(120, 116, 108), C(60, 60, 62), C(150, 132, 110), C(196, 186, 168) }
	local WOODS = { C(168, 124, 84), C(120, 84, 56), C(196, 160, 116), C(86, 60, 44) }
	function F.rug(m, cf, w, d, col)
		L.BD(m, cf, 0, 0.02, 0, w, 0.1, d, col or L.pick({ C(200, 196, 186), C(120, 116, 110), C(170, 150, 126), C(70, 74, 80) }), M.Fabric)
	end
	function F.sofa(m, cf, len, col)
		col = col or L.pick(FAB)
		L.B(m, cf, 0, 0.4, 0, len, 1.4, 3.4, col, M.Fabric)
		L.B(m, cf, 0, 0.4, 1.3, len, 3.4, 0.9, col, M.Fabric)
		for sd = -1, 1, 2 do L.B(m, cf, sd * (len / 2 - 0.45), 0.4, 0, 0.9, 2.4, 3.4, L.shade(col, 0.95), M.Fabric) end
		local n = math.max(2, math.floor(len / 3))
		for k = 0, n - 1 do
			local x = -len / 2 + 0.9 + (k + 0.5) * (len - 1.8) / n
			L.B(m, cf, x, 1.8, -0.2, (len - 1.8) / n - 0.15, 0.7, 2.6, L.shade(col, 1.04), M.Fabric)
			L.B(m, cf, x, 2.2, 0.75, (len - 1.8) / n - 0.3, 1.8, 0.6, L.shade(col, 1.06), M.Fabric)
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do L.B(m, cf, q[1] * (len / 2 - 0.4), 0, q[2] * 1.4, 0.3, 0.4, 0.3, C(30, 30, 30), M.Metal) end
		L.B(m, cf, -len / 2 + 2, 2.4, 0.2, 1.4, 1.2, 0.5, L.pick({ C(170, 140, 90), C(80, 90, 100), WHITE }), M.Fabric)
	end
	function F.armchair(m, cf, col)
		col = col or L.pick(FAB)
		L.B(m, cf, 0, 0.5, 0, 3, 1.2, 3, col, M.Fabric)
		L.B(m, cf, 0, 0.5, 1.2, 3, 3.6, 0.6, col, M.Fabric)
		for sd = -1, 1, 2 do L.B(m, cf, sd * 1.35, 0.5, 0, 0.4, 2.2, 3, L.shade(col, 0.9), M.Fabric) end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do L.B(m, cf, q[1] * 1.2, 0, q[2] * 1.2, 0.2, 0.5, 0.2, C(180, 150, 90), M.Metal) end
	end
	function F.coffeeTable(m, cf, w, d)
		L.B(m, cf, 0, 1.2, 0, w, 0.2, d, C(190, 210, 214), M.Glass, nil, { Transparency = 0.4 })
		L.B(m, cf, 0, 0, 0, w * 0.6, 1.2, d * 0.5, INK, M.Metal)
		L.B(m, cf, w * 0.2, 1.4, 0, 1.2, 0.5, 0.9, C(220, 214, 200), M.Fabric)
	end
	function F.plant(m, cf, s)
		s = s or 1
		L.Cyl(m, 1.8 * s, 1.6 * s, cf * CFrame.new(0, 0.9 * s, 0), L.pick({ INK, C(200, 196, 188), C(120, 90, 70) }), M.Concrete)
		L.bush(m, (cf * CFrame.new(0, 1.6 * s, 0)).Position, 3.2 * s)
	end
	function F.art(m, cf, w, h)
		-- canvas with a framed abstract (brush strokes / horizon), cf = centre on the wall, -Z out
		local cv = L.D(m, Vector3.new(w, h, 0.2), cf, C(234, 232, 226), M.SmoothPlastic)
		L.D(m, Vector3.new(w + 0.3, h + 0.3, 0.12), cf * CFrame.new(0, 0, 0.06), INK, M.Metal)
		local style = L.ri(1, 3)
		if style == 1 then
			L.D(m, Vector3.new(w * 0.9, h * 0.18, 0.05), cf * CFrame.new(0, -h * 0.05, -0.12), C(40, 44, 50), M.SmoothPlastic)
			L.D(m, Vector3.new(w * 0.7, h * 0.06, 0.05), cf * CFrame.new(-w * 0.05, h * 0.06, -0.12), C(90, 100, 110), M.SmoothPlastic)
		elseif style == 2 then
			for k = 1, 5 do
				L.D(m, Vector3.new(w * L.r(0.3, 0.7), h * 0.07, 0.05), cf * CFrame.new(L.r(-w * 0.15, w * 0.15), L.r(-h * 0.35, h * 0.35), -0.12) * CFrame.Angles(0, 0, L.r(-0.7, 0.7)), C(30, 30, 32), M.SmoothPlastic)
			end
		else
			L.D(m, Vector3.new(w * 0.35, w * 0.35, 0.05), cf * CFrame.new(-w * 0.12, 0, -0.12), L.pick({ C(196, 120, 70), C(60, 90, 120), C(180, 160, 120) }), M.SmoothPlastic, nil, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, w * 0.35, w * 0.35) })
			L.D(m, Vector3.new(w * 0.5, h * 0.08, 0.05), cf * CFrame.new(w * 0.1, -h * 0.25, -0.12), C(30, 30, 32), M.SmoothPlastic)
		end
		return cv
	end
	function F.pendant(m, cf, light)
		L.D(m, Vector3.new(0.06, 3, 0.06), cf * CFrame.new(0, 1.5, 0), INK, M.Metal)
		local s = L.D(m, Vector3.new(1.4, 0.9, 1.4), cf, C(30, 30, 30), M.Metal, nil, { Shape = Enum.PartType.Ball })
		L.D(m, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, -0.45, 0), C(255, 226, 170), M.Neon, nil, { Shape = Enum.PartType.Ball })
		if light then
			local pl = Instance.new("PointLight")
			pl.Range = 16
			pl.Brightness = 1.1
			pl.Color = C(255, 214, 160)
			pl.Shadows = false
			pl.Parent = s
		end
	end
	function F.bed(m, cf, w)
		w = w or 7
		local wood = L.pick(WOODS)
		L.B(m, cf, 0, 0, 0, w + 0.6, 1.4, 8.6, wood, M.Wood)
		L.B(m, cf, 0, 1.4, 0.2, w, 1.2, 8, C(236, 234, 228), M.Fabric)
		-- headboard: upholstered panel in a wood frame
		L.B(m, cf, 0, 0, 4.4, w + 1.6, 5.6, 0.6, wood, M.Wood)
		L.B(m, cf, 0, 2.2, 4.0, w, 3, 0.4, L.pick({ C(150, 146, 138), C(196, 190, 178), C(90, 92, 96) }), M.Fabric)
		-- duvet draped over the foot, pillows
		local dv = L.pick({ C(150, 146, 140), C(110, 108, 104), C(206, 200, 190) })
		L.B(m, cf, 0, 2.6, -0.8, w + 0.3, 0.35, 6.2, dv, M.Fabric)
		L.P(m, Vector3.new(w + 0.3, 0.3, 1.6), cf * CFrame.new(0, 2.1, -4.1) * CFrame.Angles(math.rad(70), 0, 0), dv, M.Fabric)
		for k = -1, 1, 2 do
			L.P(m, Vector3.new(w * 0.42, 1, 1.6), cf * CFrame.new(k * w * 0.24, 3.2, 3.2) * CFrame.Angles(math.rad(-18), 0, 0), L.pick({ C(236, 232, 224), C(196, 190, 180) }), M.Fabric)
		end
		L.P(m, Vector3.new(w * 0.3, 0.9, 1.3), cf * CFrame.new(-w * 0.15, 3.1, 2.3) * CFrame.Angles(math.rad(-12), 0, 0), C(150, 140, 126), M.Fabric)
		-- nightstands with lamps, bench at the foot
		for sd = -1, 1, 2 do
			local nc = cf * CFrame.new(sd * (w / 2 + 2.2), 0, 3.4)
			L.B(m, nc, 0, 0, 0, 2.6, 2.2, 2.2, wood, M.Wood)
			L.B(m, nc, 0, 0.8, -1.12, 2.2, 0.06, 0.06, INK, M.Metal)
			L.Cyl(m, 1.2, 0.9, nc * CFrame.new(0, 2.8, 0), C(200, 190, 170), M.Concrete)
			local sh = L.D(m, Vector3.new(1.2, 1, 1.2), nc * CFrame.new(0, 3.9, 0), C(240, 230, 210), M.Fabric)
			if sd > 0 then
				local pl = Instance.new("PointLight")
				pl.Range = 10
				pl.Brightness = 0.6
				pl.Color = C(255, 210, 160)
				pl.Shadows = false
				pl.Parent = sh
			end
		end
		L.B(m, cf, 0, 0, -5.6, w, 1.8, 1.8, wood, M.Wood)
		L.B(m, cf, w * 0.25, 1.8, -5.6, 0.5, 0.8, 0.5, WHITE, M.SmoothPlastic)
	end
	function F.kitchen(m, cf, len, o)
		-- wall run: wood base cabinets, stone counter, sink, cooktop, upper open shelving, tall pantry
		o = o or {}
		local wood = o.wood or L.pick(WOODS)
		local stone = o.stone or C(232, 230, 226)
		L.B(m, cf, 0, 0, 0, len, 3.2, 2.4, wood, M.Wood)
		L.B(m, cf, 0, 3.2, -0.1, len + 0.2, 0.35, 2.7, stone, M.Marble, "LobbyMarble")
		local n = math.floor(len / 2.6)
		for k = 0, n - 1 do
			local x = -len / 2 + (k + 0.5) * len / n
			L.B(m, cf, x, 1.4, -1.22, len / n - 0.15, 0.06, 0.04, C(20, 20, 20), M.Metal)
		end
		L.B(m, cf, len * 0.18, 3.5, -0.2, 2.6, 0.06, 1.6, C(180, 184, 188), M.Metal)
		L.B(m, cf, len * 0.18, 3.5, 0.6, 0.2, 1.4, 0.2, C(180, 184, 188), M.Metal)
		L.B(m, cf, -len * 0.2, 3.55, -0.2, 2.6, 0.04, 1.8, C(16, 16, 18), M.Glass)
		L.B(m, cf, 0, 5.4, 0.6, len, 0.3, 1.2, wood, M.Wood)
		L.B(m, cf, 0, 7.6, 0.6, len, 0.3, 1.2, wood, M.Wood)
		for k = 0, 4 do L.B(m, cf, -len / 2 + 1 + k * (len - 2) / 4, 5.7, 0.6, 0.6, L.r(0.6, 1.4), 0.6, L.pick({ WHITE, C(60, 60, 60), C(170, 140, 100) }), M.Concrete) end
		L.B(m, cf, len / 2 + 1.6, 0, 0, 3, 9.5, 2.6, wood, M.Wood)
		L.B(m, cf, len / 2 + 1.6, 0.2, -1.32, 0.06, 9, 0.06, INK, M.Metal)
	end
	function F.island(m, cf, len, stools)
		-- waterfall marble island with a cooktop and stools
		L.B(m, cf, 0, 0, 0, len, 3.4, 3.6, C(232, 230, 226), M.Marble, "LobbyMarble")
		L.B(m, cf, 0, 3.4, 0, len + 0.2, 0.3, 3.8, C(238, 236, 232), M.Marble, "LobbyMarble")
		L.B(m, cf, len * 0.2, 3.7, 0.4, 2.4, 0.04, 1.6, C(16, 16, 18), M.Glass)
		for k = 0, (stools or 3) - 1 do
			local sc = cf * CFrame.new(-len / 2 + 1.5 + k * (len - 3) / math.max(1, (stools or 3) - 1), 0, -3)
			L.B(m, sc, 0, 2.4, 0, 1.6, 0.3, 1.6, L.pick(WOODS), M.Wood)
			L.B(m, sc, 0, 0, 0, 0.2, 2.4, 0.2, INK, M.Metal)
			L.B(m, sc, 0, 2.7, 0.7, 1.6, 1.2, 0.2, L.pick(WOODS), M.Wood)
		end
	end
	function F.hood(m, cf)
		L.D(m, Vector3.new(1.6, 3, 1.6), cf * CFrame.new(0, 1.5, 0), C(90, 92, 96), M.Metal)
		L.D(m, Vector3.new(4, 0.6, 2.6), cf, C(90, 92, 96), M.Metal)
	end
	function F.dining(m, cf, len)
		local wood = L.pick(WOODS)
		L.B(m, cf, 0, 2.9, 0, len, 0.35, 3.6, wood, M.Wood)
		for sd = -1, 1, 2 do L.B(m, cf, sd * (len / 2 - 0.6), 0, 0, 0.5, 2.9, 3, INK, M.Metal) end
		local n = math.floor(len / 2.6)
		for k = 0, n - 1 do
			for sd = -1, 1, 2 do
				local cc = cf * CFrame.new(-len / 2 + 1.3 + k * (len - 2.6) / math.max(1, n - 1), 0, sd * 2.8) * CFrame.Angles(0, sd > 0 and math.pi or 0, 0)
				L.B(m, cc, 0, 1.6, 0, 1.6, 0.25, 1.6, wood, M.Wood)
				L.B(m, cc, 0, 1.85, 0.7, 1.6, 1.8, 0.2, wood, M.Wood)
				for _, q in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do L.B(m, cc, q[1], 0, q[2], 0.12, 1.6, 0.12, INK, M.Metal) end
			end
		end
		L.Cyl(m, 1.2, 0.8, cf * CFrame.new(0, 3.7, 0), WHITE, M.Concrete)
		L.bush(m, (cf * CFrame.new(0, 4.2, 0)).Position, 1.6)
	end
	function F.fireplace(m, cf, w, h)
		L.B(m, cf, 0, 0, 0, w, h, 2, C(52, 52, 54), M.Slate, "RoofSlatesDark")
		L.B(m, cf, 0, 1, -0.9, w * 0.45, 3.4, 0.3, C(14, 14, 14), M.SmoothPlastic)
		for k = 0, 2 do L.D(m, Vector3.new(w * 0.32, 0.4, 0.4), cf * CFrame.new(L.r(-0.6, 0.6), 1.4 + k * 0.25, -0.6) * CFrame.Angles(0, L.r(-0.4, 0.4), 0), C(110, 80, 56), M.Wood) end
		local fl = L.D(m, Vector3.new(w * 0.3, 0.8, 0.3), cf * CFrame.new(0, 2, -0.5), C(255, 140, 40), M.Neon, nil, { Transparency = 0.3 })
		local f = Instance.new("Fire")
		f.Size = 2
		f.Heat = 3
		f.Parent = fl
	end
	function F.tv(m, cf, w)
		L.D(m, Vector3.new(w, w * 0.56, 0.2), cf, C(10, 10, 12), M.Glass, nil, { Reflectance = 0.3 })
		L.B(m, cf * CFrame.new(0, -w * 0.28 - 3.2, 0.4), 0, 0, 0, w * 1.2, 1.6, 1.6, L.pick(WOODS), M.Wood)
	end
	function F.bath(m, cf)
		-- freestanding tub, double vanity with mirror, glass shower
		L.B(m, cf, -3, 0, 1, 6, 2.2, 3, WHITE, M.SmoothPlastic)
		L.B(m, cf, -3, 1.4, 1, 5.2, 0.9, 2.2, C(170, 210, 220), M.Glass, nil, { Transparency = 0.3 })
		L.B(m, cf, 3.2, 0, 1.4, 6, 3, 2, L.pick(WOODS), M.Wood)
		L.B(m, cf, 3.2, 3, 1.4, 6.2, 0.25, 2.2, C(236, 234, 230), M.Marble, "LobbyMarble")
		L.B(m, cf, 3.2, 4.4, 2.4, 5.4, 3.6, 0.1, C(200, 214, 220), M.Glass, nil, { Reflectance = 0.6 })
		L.B(m, cf, 3.2, 3.25, 1.6, 0.2, 0.9, 0.2, C(180, 184, 188), M.Metal)
	end
	function F.desk(m, cf)
		L.B(m, cf, 0, 2.8, 0, 6, 0.3, 2.6, L.pick(WOODS), M.Wood)
		for sd = -1, 1, 2 do L.B(m, cf, sd * 2.8, 0, 0, 0.3, 2.8, 2.4, INK, M.Metal) end
		L.B(m, cf, 0, 3.1, 0.6, 3, 1.9, 0.15, C(14, 14, 16), M.Glass)
		L.B(m, cf, 0, 3.1, 0.7, 0.3, 0.6, 0.3, C(180, 184, 188), M.Metal)
		F.armchair(m, cf * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.pi, 0), C(40, 40, 42))
	end

	-- =====================================================================================
	-- LUXURY HOUSE (walk-in, furnished). styles: noir (dark glass box), white (Miami modern),
	-- med (Mediterranean revival, clay roof), tropical (teak slats + stone). cf at lot centre,
	-- local -Z = street side, +Z = water / garden side. o.dock = private dock with yacht + boat lift.
	-- =====================================================================================
	L.HOUSE_STYLES = {
		noir = { wall = C(46, 46, 48), wallMat = M.Plaster, wallVar = "StuccoGreyFine", frame = C(22, 22, 24), roof = C(36, 36, 38), base = C(196, 194, 188), soffit = C(150, 112, 76), deck = C(156, 116, 80), floor = C(186, 144, 104), inner = C(196, 194, 188), flat = true },
		white = { wall = C(244, 242, 238), wallMat = M.Plaster, wallVar = "StuccoWhite", frame = C(40, 40, 42), roof = C(236, 234, 230), base = C(214, 208, 198), soffit = C(176, 134, 92), deck = C(170, 130, 90), floor = C(206, 176, 136), inner = C(238, 236, 232), flat = true },
		med = { wall = C(236, 222, 196), wallMat = M.Plaster, wallVar = "StuccoBeige", frame = C(70, 52, 40), roof = C(176, 92, 62), base = C(196, 176, 150), soffit = C(120, 84, 56), deck = C(186, 160, 130), floor = C(200, 150, 110), inner = C(242, 234, 220), flat = false },
		tropical = { wall = C(214, 206, 192), wallMat = M.Concrete, wallVar = "BoardFormedConcrete", frame = C(34, 34, 36), roof = C(60, 56, 52), base = C(150, 140, 126), soffit = C(150, 104, 64), deck = C(150, 104, 66), floor = C(170, 126, 84), inner = C(226, 220, 210), flat = true, slats = true },
	}
	local function glassPane(m, cf, x, y0, z, w, h, axisX, st)
		-- floor-to-ceiling glass with black mullions every ~5 studs
		local size = axisX and Vector3.new(w, h, 0.3) or Vector3.new(0.3, h, w)
		L.P(m, size, cf * CFrame.new(x, y0 + h / 2, z), C(150, 176, 186), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.15 })
		local n = math.max(1, math.floor(w / 5))
		for k = 0, n do
			local o = -w / 2 + k * w / n
			if axisX then L.D(m, Vector3.new(0.35, h, 0.5), cf * CFrame.new(x + o, y0 + h / 2, z), st.frame, M.Metal)
			else L.D(m, Vector3.new(0.5, h, 0.35), cf * CFrame.new(x, y0 + h / 2, z + o), st.frame, M.Metal) end
		end
		if axisX then L.D(m, Vector3.new(w, 0.4, 0.5), cf * CFrame.new(x, y0 + h - 0.2, z), st.frame, M.Metal)
		else L.D(m, Vector3.new(0.5, 0.4, w), cf * CFrame.new(x, y0 + h - 0.2, z), st.frame, M.Metal) end
	end
	local function railing(m, a, b, st, glass)
		local len = (b - a).Magnitude
		local cfm = CFrame.lookAt((a + b) / 2, b)
		L.P(m, Vector3.new(0.3, 0.3, len), cfm * CFrame.new(0, 3.4, 0), st.frame, M.Metal)
		if glass then
			L.P(m, Vector3.new(0.15, 3.2, len), cfm * CFrame.new(0, 1.7, 0), C(170, 200, 210), M.Glass, nil, { Transparency = 0.6 })
		else
			for s = -len / 2 + 0.6, len / 2 - 0.4, 1.4 do L.D(m, Vector3.new(0.14, 3.3, 0.14), cfm * CFrame.new(0, 1.65, s), st.frame, M.Metal) end
			L.P(m, Vector3.new(0.12, 3.2, len), cfm * CFrame.new(0, 1.7, 0), WHITE, M.SmoothPlastic, nil, { Transparency = 1 })
		end
	end
	local function slabHole(m, cf, x0, x1, z0, z1, hx0, hx1, hz0, hz1, y, th, col, mat, var)
		local function r(a0, a1, b0, b1)
			if a1 - a0 > 0.2 and b1 - b0 > 0.2 then L.P(m, Vector3.new(a1 - a0, th, b1 - b0), cf * CFrame.new((a0 + a1) / 2, y - th / 2, (b0 + b1) / 2), col, mat, var) end
		end
		r(x0, x1, z0, hz0)
		r(x0, x1, hz1, z1)
		r(x0, hx0, hz0, hz1)
		r(hx1, x1, hz0, hz1)
	end


	-- empty private berth: invisible tagged volume the game can use to spawn / park the owner's boat,
	-- two white mooring buoys marking the ends, fenders on the dock edge
	local CS = game:GetService("CollectionService")
	local function berth(m, cf, len, wid, house)
		local b = Instance.new("Part")
		b.Name = "HouseBerth"
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, true, false
		b.Transparency = 1
		b.Size = Vector3.new(len, 8, wid)
		b.CFrame = cf
		b:SetAttribute("House", house or "")
		b:SetAttribute("MaxLength", len)
		CS:AddTag(b, "HouseBerth")
		b.Parent = m
		for sd = -1, 1, 2 do
			L.D(m, Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(sd * (len / 2 + 2), 0.4, wid / 2), WHITE, M.SmoothPlastic, nil, { Shape = Enum.PartType.Ball })
			L.D(m, Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(sd * (len / 2 + 2), 1.3, wid / 2), C(255, 120, 40), M.Neon)
		end
		return b
	end
	L.houseBerth = berth
	function L.luxHouse(par, cf, w, d, o)
		o = o or {}
		local sname = o.style or L.pick({ "noir", "white", "med", "tropical" })
		local st = L.HOUSE_STYLES[sname]
		local m = Instance.new("Model")
		m.Name = o.name or ("Villa_" .. sname)
		m:SetAttribute("HouseStyle", sname)
		-- footprint
		local bw = math.clamp(w - 14, 34, 78)
		local bd = math.clamp(d - 28, 26, 44)
		local front = -d / 2 + 15
		local hz = front + bd / 2
		local GH, UH = 13, 12
		local PL = 1.2 -- plinth / floor level
		local uy0 = PL + GH + 0.3 -- upper floor level
		-- grounds: lawn, driveway, path, hedges
		L.BD(m, cf, 0, 0.02, 0, w - 1, 0.12, d - 1, C(96, 134, 66), M.Grass)
		local drX = -w / 2 + 9
		L.BD(m, cf, drX, 0.06, -d / 2 + 8, 14, 0.2, 16, C(206, 200, 188), M.Pavement, "HerringbonePavers")
		L.BD(m, cf, 4, 0.06, -d / 2 + 7.5, 4, 0.2, 15, C(214, 210, 200), M.Concrete, "ConcretePlain")
		for x = -w / 2 + 18, w / 2 - 3, 4.5 do L.bush(m, (cf * CFrame.new(x, 0, -d / 2 + 1.5)).Position, 3.2) end
		-- plinth
		L.P(m, Vector3.new(bw + 4, PL, bd + 4), cf * CFrame.new(0, PL / 2, hz), st.base, M.Concrete, "ConcretePlain")
		-- ===== ground floor shell =====
		local x0, x1, z0, z1 = -bw / 2, bw / 2, hz - bd / 2, hz + bd / 2
		local floorY = PL
		L.P(m, Vector3.new(bw, 0.3, bd), cf * CFrame.new(0, floorY + 0.15, hz), st.floor, M.WoodPlanks, "WoodPlanksOld")
		-- front facade: solid wall with a tall recessed entrance + garage glass door, side walls part solid
		local entX = 6
		local gw = (bw >= 56) and 24 or 15 -- fits a full-size (22-stud) car sideways
		local garX = x0 + gw / 2 + 1
		-- garage (left front corner)
		L.P(m, Vector3.new(gw + 2, 3, 0.8), cf * CFrame.new(garX, floorY + GH - 1.5, z0), st.wall, st.wallMat, st.wallVar)
		L.P(m, Vector3.new(gw, GH - 3, 0.25), cf * CFrame.new(garX, floorY + (GH - 3) / 2, z0 + 0.2), C(60, 70, 76), M.Glass, nil, { Transparency = 0.25, Reflectance = 0.2 })
		for k = 1, 3 do L.D(m, Vector3.new(gw, 0.2, 0.4), cf * CFrame.new(garX, floorY + k * (GH - 3) / 4, z0), st.frame, M.Metal) end
		L.P(m, Vector3.new(0.8, GH, 16), cf * CFrame.new(garX + gw / 2 + 0.6, floorY + GH / 2, z0 + 8), st.wall, st.wallMat, st.wallVar)
		L.supercar(m, cf * CFrame.new(garX, floorY + 0.3, z0 + 8) * CFrame.Angles(0, gw >= 24 and math.pi / 2 or 0, 0), nil, false)
		-- solid front wall between garage and entrance, entrance, then glass/solid to the right
		local segA0, segA1 = garX + gw / 2 + 1, entX - 3
		if segA1 - segA0 > 1 then L.P(m, Vector3.new(segA1 - segA0, GH, 0.8), cf * CFrame.new((segA0 + segA1) / 2, floorY + GH / 2, z0), st.wall, st.wallMat, st.wallVar) end
		L.P(m, Vector3.new(6, 2.4, 0.8), cf * CFrame.new(entX, floorY + GH - 1.2, z0), st.wall, st.wallMat, st.wallVar)
		-- pivot door (left open), wood, with a long brass pull
		local door = L.P(m, Vector3.new(4.4, GH - 2.6, 0.4), cf * CFrame.new(entX - 1.2, floorY + (GH - 2.6) / 2, z0 + 1.8) * CFrame.Angles(0, math.rad(78), 0), st.soffit, M.Wood)
		L.D(m, Vector3.new(0.2, 5, 0.3), door.CFrame * CFrame.new(1.6, 0, -0.35), C(196, 160, 90), M.Metal)
		local segB0 = entX + 3
		if sname == "med" then
			L.P(m, Vector3.new(x1 - segB0, GH, 0.8), cf * CFrame.new((segB0 + x1) / 2, floorY + GH / 2, z0), st.wall, st.wallMat, st.wallVar)
			for k = 0, 1 do
				local wx = segB0 + (x1 - segB0) * (0.3 + k * 0.4)
				L.D(m, Vector3.new(4, 6.4, 0.2), cf * CFrame.new(wx, floorY + 5, z0 - 0.45), C(60, 80, 90), M.Glass, nil, { Reflectance = 0.2 })
				for sd = -1, 1, 2 do L.D(m, Vector3.new(1.9, 6.6, 0.2), cf * CFrame.new(wx + sd * 3.1, floorY + 5, z0 - 0.55), C(86, 110, 80), M.WoodPlanks) end
				L.D(m, Vector3.new(5, 0.6, 0.6), cf * CFrame.new(wx, floorY + 8.6, z0 - 0.6), st.base, M.Concrete)
			end
		else
			glassPane(m, cf, (segB0 + x1) / 2, floorY, z0, x1 - segB0, GH - 0.4, true, st)
		end
		-- entrance canopy, wall sconces, house number, water feature
		L.P(m, Vector3.new(10, 0.6, 7), cf * CFrame.new(entX, floorY + GH - 0.5, z0 - 3.3), st.roof, M.Concrete)
		for sd = -1, 1, 2 do L.D(m, Vector3.new(0.3, 2, 0.3), cf * CFrame.new(entX + sd * 3.6, floorY + 7.5, z0 - 0.5), C(255, 220, 170), M.Neon) end
		local num = L.D(m, Vector3.new(2.4, 1.2, 0.1), cf * CFrame.new(entX + 4.6, floorY + 9, z0 - 0.45), st.frame, M.Metal)
		L.label(num, Enum.NormalId.Front, tostring(L.ri(100, 9900)), { font = Enum.Font.Michroma, color = C(220, 200, 150), light = 0.3 })
		L.BD(m, cf, entX + 8, 0.1, z0 - 5, 6, 1.2, 3, C(40, 40, 42), M.Slate)
		L.BD(m, cf, entX + 8, 1.2, z0 - 5, 5.4, 0.1, 2.4, C(60, 120, 140), M.Glass, nil, { Transparency = 0.2 })
		-- side walls (mostly solid, a slot window), rear = full glass with one slider left open
		for sd = -1, 1, 2 do
			local x = sd < 0 and x0 or x1
			local zs = z0
			L.P(m, Vector3.new(0.8, GH, z1 - zs), cf * CFrame.new(x, floorY + GH / 2, (zs + z1) / 2), st.wall, st.wallMat, st.wallVar)
			L.D(m, Vector3.new(0.3, 2.2, (z1 - zs) * 0.5), cf * CFrame.new(x + sd * 0.3, floorY + 9, (zs + z1) / 2 + 2), C(70, 90, 100), M.Glass, nil, { Reflectance = 0.2 })
		end
		if sname == "med" then
			-- arcade loggia at the back: piers, lintel band, glass in three bays, one bay open
			for k = 0, 4 do L.P(m, Vector3.new(3, GH, 1.2), cf * CFrame.new(x0 + bw * k / 4, floorY + GH / 2, z1), st.wall, st.wallMat, st.wallVar) end
			L.P(m, Vector3.new(bw, 3.2, 1.2), cf * CFrame.new(0, floorY + GH - 1.6, z1), st.wall, st.wallMat, st.wallVar)
			for k = 0, 3 do
				local ax = x0 + bw * (k + 0.5) / 4
				if k ~= 1 then L.P(m, Vector3.new(bw / 4 - 3, GH - 3.2, 0.3), cf * CFrame.new(ax, floorY + (GH - 3.2) / 2, z1 + 0.2), C(150, 176, 186), M.Glass, nil, { Transparency = 0.55 }) end
				L.D(m, Vector3.new(1.4, 1.4, 1.3), cf * CFrame.new(ax, floorY + GH - 3.6, z1) * CFrame.Angles(0, 0, math.pi / 4), st.base, M.Concrete)
			end
		else
			local gl = bw - 8
			glassPane(m, cf, -4, floorY, z1, gl, GH - 0.4, true, st)
			-- open slider gap (8 studs) at the right end so you can walk out to the pool
			L.D(m, Vector3.new(0.5, GH - 0.4, 0.5), cf * CFrame.new(x1, floorY + (GH - 0.4) / 2, z1), st.frame, M.Metal)
		end
		-- ===== ground-floor interior =====
		-- light plaster lining on the inside of the solid walls, ceiling panels with recessed downlights
		local IN = st.inner
		L.D(m, Vector3.new(0.12, GH - 0.4, bd - 1.6), cf * CFrame.new(x0 + 0.5, floorY + GH / 2, hz), IN, M.Plaster, "StuccoGreyFine")
		L.D(m, Vector3.new(0.12, GH - 0.4, bd - 1.6), cf * CFrame.new(x1 - 0.5, floorY + GH / 2, hz), IN, M.Plaster, "StuccoGreyFine")
		L.D(m, Vector3.new(entX - 3 - (garX + gw / 2 + 1), GH - 0.4, 0.12), cf * CFrame.new((entX - 3 + garX + gw / 2 + 1) / 2, floorY + GH / 2, z0 + 0.5), IN, M.Plaster, "StuccoGreyFine")
		slabHole(m, cf, x0 + 0.5, x1 - 0.5, z0 + 0.5, z1 - 0.5, x1 - 18, x1 - 3.5, z0 + 2.5, z0 + 7.5, uy0 - 1.22, 0.12, IN, M.SmoothPlastic)
		for x = x0 + 6, x1 - 6, 9 do
			for z = z0 + 6, z1 - 4, 9 do L.D(m, Vector3.new(0.9, 0.08, 0.9), cf * CFrame.new(x, uy0 - 1.38, z), C(255, 240, 214), M.Neon) end
		end
		-- garage back + side wall so the garage is its own room (door into the hall)
		L.P(m, Vector3.new(gw + 1.2, GH, 0.6), cf * CFrame.new(x0 + (gw + 1.2) / 2, floorY + GH / 2, z0 + 16), IN, M.Plaster, "StuccoGreyFine")
		local inner = cf * CFrame.new(0, floorY + 0.3, hz)
		-- stair void (front right corner, runs along X)
		local sx0, sx1, sz0, sz1 = x1 - 22, x1 - 4, z0 + 2.5, z0 + 7.5
		-- kitchen along the left wall behind the garage wall, island, dining
		local kz = (z0 + 16 + z1) / 2
		F.kitchen(m, cf * CFrame.new(x0 + 1.6, floorY + 0.3, kz) * CFrame.Angles(0, -math.pi / 2, 0), math.min(16, bd - 24), {})
		F.island(m, cf * CFrame.new(x0 + 11, floorY + 0.3, kz) * CFrame.Angles(0, -math.pi / 2, 0), 9, 3)
		F.hood(m, cf * CFrame.new(x0 + 11, floorY + GH - 4.5, kz))
		F.dining(m, cf * CFrame.new(x0 + 22, floorY + 0.3, z1 - 9) * CFrame.Angles(0, math.pi / 2, 0), 10)
		F.pendant(m, cf * CFrame.new(x0 + 22, floorY + GH - 4, z1 - 9), true)
		-- living: sofa facing the fireplace wall, armchair, coffee table on a rug, art, plants, TV
		local lx = x1 - 13
		F.rug(m, cf * CFrame.new(lx, floorY + 0.3, z1 - 11), 16, 12)
		F.sofa(m, cf * CFrame.new(lx, floorY + 0.3, z1 - 6.5), 12)
		F.coffeeTable(m, cf * CFrame.new(lx, floorY + 0.3, z1 - 11), 5, 3)
		F.armchair(m, cf * CFrame.new(lx - 7, floorY + 0.3, z1 - 12) * CFrame.Angles(0, -math.pi / 2, 0))
		F.fireplace(m, cf * CFrame.new(lx, floorY + 0.3, z0 + 10.5) * CFrame.Angles(0, math.pi, 0), 9, GH - 0.6)
		F.tv(m, cf * CFrame.new(x1 - 0.6, floorY + 6.5, z1 - 11) * CFrame.Angles(0, -math.pi / 2, 0), 7)
		F.art(m, cf * CFrame.new(x0 + 0.6, floorY + 8.5, z0 + 21) * CFrame.Angles(0, math.pi / 2, 0), 6, 4)
		F.plant(m, cf * CFrame.new(x1 - 2.5, floorY + 0.3, z1 - 2.5), 1.4)
		F.plant(m, cf * CFrame.new(x0 + 2.5, floorY + 0.3, z1 - 2.5), 1.2)
		F.pendant(m, cf * CFrame.new(lx, floorY + GH - 4, z1 - 11), true)
		-- open-tread stair along the front wall: 14 treads, dark steel stringer
		local rise = (GH + 0.3) / 14
		for k = 0, 13 do
			L.P(m, Vector3.new(1.3, 0.35, 4.4), cf * CFrame.new(sx0 + 0.8 + k * 1.3, floorY + 0.3 + (k + 1) * rise - 0.18, (sz0 + sz1) / 2), st.floor, M.Wood)
		end
		local sa = (cf * CFrame.new(sx0, floorY, sz1 + 0.1)).Position
		local sb = (cf * CFrame.new(sx0 + 18.2, floorY + GH, sz1 + 0.1)).Position
		L.bar(m, sa, sb, 0.5, INK, M.Metal)
		L.bar(m, sa + Vector3.new(0, 3.4, 0), sb + Vector3.new(0, 3.4, 0), 0.2, INK, M.Metal)
		-- ===== upper floor (cantilevers toward the garden side and to one side) =====
		local uy = floorY + GH + 0.3
		local ubw, ubd = bw * 0.78, bd + 2
		local ux = bw * 0.11
		local uz = hz + 3
		local ux0, ux1, uz0, uz1 = ux - ubw / 2, ux + ubw / 2, uz - ubd / 2, uz + ubd / 2
		-- GF roof / UF floor (with the stair hole), terrace deck on the uncovered part
		slabHole(m, cf, x0 - 0.5, x1 + 0.5, z0 - 0.5, z1 + 0.5, sx0 + 4, sx1 + 0.5, sz0, sz1, uy, 1.2, st.roof, M.Concrete, "ConcretePlain")
		slabHole(m, cf, ux0, ux1, uz0, uz1, sx0 + 4, sx1 + 0.5, sz0, sz1, uy + 0.12, 0.12, st.floor, M.WoodPlanks, "WoodPlanksOld")
		if uz1 > z1 + 0.5 then L.P(m, Vector3.new(ubw, 1.2, uz1 - z1 - 0.5), cf * CFrame.new(ux, uy - 0.6, (uz1 + z1 + 0.5) / 2), st.roof, M.Concrete, "ConcretePlain") end
		-- UF walls: rear glass, front solid with a ribbon window, sides solid; leave a doorway to the terrace
		glassPane(m, cf, ux, uy, uz1, ubw, UH - 0.4, true, st)
		L.P(m, Vector3.new(ubw, UH, 0.8), cf * CFrame.new(ux, uy + UH / 2, uz0), st.wall, st.wallMat, st.wallVar)
		L.D(m, Vector3.new(ubw * 0.6, 2.4, 0.3), cf * CFrame.new(ux, uy + 7, uz0 - 0.4), C(70, 90, 100), M.Glass, nil, { Reflectance = 0.25 })
		L.P(m, Vector3.new(0.8, UH, ubd), cf * CFrame.new(ux1, uy + UH / 2, uz), st.wall, st.wallMat, st.wallVar)
		L.P(m, Vector3.new(0.8, UH, ubd - 8), cf * CFrame.new(ux0, uy + UH / 2, uz + 4), st.wall, st.wallMat, st.wallVar)
		L.P(m, Vector3.new(0.8, 3, 8), cf * CFrame.new(ux0, uy + UH - 1.5, uz0 + 4), st.wall, st.wallMat, st.wallVar) -- doorway to the terrace
		-- roof: thin dark slab with a deep overhang + wood soffit (flat styles), clay hip roof (med)
		if st.flat then
			L.P(m, Vector3.new(ubw + 5, 1.2, ubd + 5), cf * CFrame.new(ux, uy + UH + 0.6, uz), st.roof, M.Concrete, "ConcretePlain")
			L.D(m, Vector3.new(ubw + 4.6, 0.1, ubd + 4.6), cf * CFrame.new(ux, uy + UH - 0.05, uz), st.soffit, M.WoodPlanks, "WoodPlanksOld")
			L.D(m, Vector3.new(ubw + 5.2, 0.25, 0.25), cf * CFrame.new(ux, uy + UH - 0.2, uz1 + 2.6), C(255, 226, 180), M.Neon)
		else
			L.P(m, Vector3.new(ubw + 3, 0.6, ubd + 3), cf * CFrame.new(ux, uy + UH + 0.3, uz), st.soffit, M.Wood)
			L.W(m, Vector3.new(ubw + 3, 6, (ubd + 3) / 2), cf * CFrame.new(ux, uy + UH + 3.6, uz - (ubd + 3) / 4), st.roof, M.ClayRoofTiles, "RoofClayMission")
			L.W(m, Vector3.new(ubw + 3, 6, (ubd + 3) / 2), cf * CFrame.new(ux, uy + UH + 3.6, uz + (ubd + 3) / 4) * CFrame.Angles(0, math.pi, 0), st.roof, M.ClayRoofTiles, "RoofClayMission")
			L.D(m, Vector3.new(2.4, 4, 2.4), cf * CFrame.new(ux1 - 6, uy + UH + 5, uz), st.wall, M.Plaster)
		end
		-- stair/elevator core: dark tower that rises above the roof (the reference's chimney block)
		local coreX = x1 - 3
		L.P(m, Vector3.new(6, GH + UH + 7, 7), cf * CFrame.new(coreX + 3, (GH + UH + 7) / 2 + PL, z0 + 6), C(30, 30, 32), M.Concrete, "ConcretePlain")
		-- terrace on the uncovered GF roof: deck, railing, loungers
		local tx0, tx1 = x0, ux0
		if tx1 - tx0 > 5 then
			L.D(m, Vector3.new(tx1 - tx0 - 0.4, 0.15, bd), cf * CFrame.new((tx0 + tx1) / 2, uy + 0.08, hz), st.deck, M.WoodPlanks, "WoodPlanksOld")
			railing(m, (cf * CFrame.new(tx0 + 0.3, uy, z0 + 0.3)).Position, (cf * CFrame.new(tx0 + 0.3, uy, z1 - 0.3)).Position, st, sname ~= "noir")
			railing(m, (cf * CFrame.new(tx0 + 0.3, uy, z1 - 0.3)).Position, (cf * CFrame.new(tx1, uy, z1 - 0.3)).Position, st, sname ~= "noir")
			railing(m, (cf * CFrame.new(tx0 + 0.3, uy, z0 + 0.3)).Position, (cf * CFrame.new(tx1, uy, z0 + 0.3)).Position, st, sname ~= "noir")
			for k = 0, 1 do L.B(m, cf * CFrame.new((tx0 + tx1) / 2, uy, hz - 3 + k * 6), 0, 0, 0, 2.4, 1, 6, WHITE, M.Fabric) end
		end
		-- ===== upper-floor interior: master suite at the back, bath + office at the front =====
		L.D(m, Vector3.new(ubw - 1.6, UH - 0.4, 0.12), cf * CFrame.new(ux, uy + UH / 2, uz0 + 0.5), IN, M.Plaster, "StuccoGreyFine")
		L.D(m, Vector3.new(0.12, UH - 0.4, ubd - 1.6), cf * CFrame.new(ux1 - 0.5, uy + UH / 2, uz), IN, M.Plaster, "StuccoGreyFine")
		L.D(m, Vector3.new(ubw - 1, 0.12, ubd - 1), cf * CFrame.new(ux, uy + UH - 0.1, uz), IN, M.SmoothPlastic)
		for x = ux0 + 6, ux1 - 6, 10 do L.D(m, Vector3.new(0.9, 0.08, 0.9), cf * CFrame.new(x, uy + UH - 0.2, uz + 4), C(255, 240, 214), M.Neon) end
		F.bed(m, cf * CFrame.new(ux - 2, uy, uz1 - 10) * CFrame.Angles(0, math.pi, 0), 7)
		F.art(m, cf * CFrame.new(ux - 2, uy + 8.5, uz - 1.2) * CFrame.Angles(0, math.pi, 0), 6, 3.6)
		L.P(m, Vector3.new(ubw - 12, UH, 0.6), cf * CFrame.new(ux - 6, uy + UH / 2, uz - 1.6), st.inner, M.Plaster, "StuccoGreyFine")
		F.bath(m, cf * CFrame.new(ux - 8, uy, uz0 + 4) * CFrame.Angles(0, math.pi, 0))
		F.desk(m, cf * CFrame.new(ux1 - 6, uy, uz1 - 4))
		F.plant(m, cf * CFrame.new(ux1 - 2.5, uy, uz1 - 9), 1.3)
		F.pendant(m, cf * CFrame.new(ux - 2, uy + UH - 3.5, uz1 - 12), true)
		-- UF balcony along the back with railing
		railing(m, (cf * CFrame.new(ux0, uy, uz1 + 0.6)).Position, (cf * CFrame.new(ux1, uy, uz1 + 0.6)).Position, st, true)
		-- tropical: vertical teak slat screen over the front of the upper floor
		if st.slats then
			for x = ux0 + 1, ux1 - 1, 1.2 do L.D(m, Vector3.new(0.4, UH + 1, 0.6), cf * CFrame.new(x, uy + UH / 2, uz0 - 1.2), C(140, 96, 60), M.Wood) end
			L.P(m, Vector3.new(6, GH, 1.6), cf * CFrame.new(x0 + 3, floorY + GH / 2, z1 + 1), C(130, 122, 110), M.Slate, "RockGrey")
		end
		-- ===== garden side: infinity pool, deck, loungers, outdoor kitchen, palms, lights =====
		local gz0 = z1 + 1
		local gz1 = d / 2 - 1
		local gd = gz1 - gz0
		if gd > 8 then
			local pw = math.min(bw * 0.6, 34)
			local pd = math.min(gd - 5, 10)
			local pz = gz0 + 2 + pd / 2
			local px = -bw * 0.12
			slabHole(m, cf, -w / 2 + 2, w / 2 - 2, gz0, gz1, px - pw / 2, px + pw / 2, pz - pd / 2, pz + pd / 2, PL, PL - 0.05, L.shade(st.base, 1.04), M.CeramicTiles, "PlazaTiles")
			L.BD(m, cf, -bw * 0.12, PL - 0.2, pz, pw, 0.25, pd, C(40, 170, 200), M.Glass, nil, { Transparency = 0.12, CanCollide = false })
			L.BD(m, cf, -bw * 0.12, PL - 0.6, pz, pw + 0.6, 0.4, pd + 0.6, C(30, 110, 140), M.SmoothPlastic)
			local pl = Instance.new("PointLight")
			pl.Range = 14
			pl.Brightness = 0.6
			pl.Color = C(120, 220, 255)
			pl.Shadows = false
			pl.Parent = L.D(m, Vector3.new(1, 0.2, 1), cf * CFrame.new(-bw * 0.12, PL - 0.4, pz), C(120, 220, 255), M.Neon, nil, { Transparency = 1 })
			for k = 0, 2 do L.B(m, cf * CFrame.new(-bw * 0.12 + pw / 2 + 4, PL, gz0 + 2 + k * 3.4), 0, 0, 0, 5.6, 0.9, 2.2, WHITE, M.Fabric) end
			L.umbrella(m, cf * CFrame.new(-bw * 0.12 + pw / 2 + 9, PL, pz))
			-- outdoor kitchen + fire pit on the other side
			local ok = cf * CFrame.new(x1 - 6, PL, gz0 + 3)
			L.B(m, ok, 0, 0, 0, 8, 3.2, 2.4, C(60, 60, 62), M.Slate)
			L.B(m, ok, 0, 3.2, 0, 8.2, 0.3, 2.6, C(220, 216, 208), M.Marble)
			L.Cyl(m, 1.2, 5, cf * CFrame.new(x1 - 6, PL + 0.6, gz0 + gd - 3), C(70, 70, 72), M.Slate)
			local fp = L.D(m, Vector3.new(2, 0.4, 2), cf * CFrame.new(x1 - 6, PL + 1.3, gz0 + gd - 3), C(255, 130, 40), M.Neon)
			local fi = Instance.new("Fire")
			fi.Size = 3
			fi.Parent = fp
		end
		for _, q in ipairs({ { -w / 2 + 4, d / 2 - 4 }, { w / 2 - 4, d / 2 - 4 }, { -w / 2 + 4, -d / 2 + 18 }, { w / 2 - 4, -d / 2 + 6 } }) do
			L.palm(m, (cf * CFrame.new(q[1], 0, q[2])).Position, L.r(30, 44), L.chance(0.5) and "hero" or "royal")
		end
		-- uplights along the facade
		for x = x0 + 4, x1 - 4, 10 do L.D(m, Vector3.new(0.6, 0.3, 0.6), cf * CFrame.new(x, PL + 0.15, z0 - 1.2), C(255, 230, 190), M.Neon) end
		-- gate + perimeter wall on the street side
		L.B(m, cf, w / 2 - 6, 0, -d / 2 + 1, 10, 6, 0.8, st.wall, st.wallMat, st.wallVar)
		L.B(m, cf, drX, 0, -d / 2 + 0.6, 13, 5.4, 0.3, C(30, 30, 32), M.Metal, nil, { Transparency = 0.25, CanCollide = false })
		local mb = L.B(m, cf, drX + 8.5, 0, -d / 2 + 1, 1.6, 4, 1.2, st.frame, M.Metal)
		-- ===== private dock: seawall cap, timber dock, boat lift + boat, yacht at the end =====
		if o.dock and o.dockMode == "parallel" then
			-- canal lot: seawall + a timber dock running along the bank, yacht moored alongside (keeps the canal open)
			local wz = d / 2
			L.P(m, Vector3.new(w, 7.4, 2.4), cf * CFrame.new(0, -3.4, wz - 1.2), C(206, 202, 194), M.Concrete, "ConcretePlain")
			local dc = cf * CFrame.new(0, L.WATER - L.G + 1.6, wz + 3)
			L.P(m, Vector3.new(w - 8, 0.8, 6), dc, st.deck, M.WoodPlanks, "WoodPlanksOld")
			for x = -w / 2 + 6, w / 2 - 6, 8 do
				for _, zz in ipairs({ -2.6, 2.6 }) do L.Cyl(m, 9, 1, dc * CFrame.new(x, -3.6, zz), C(110, 90, 70), M.Wood) end
				L.D(m, Vector3.new(1.4, 0.5, 0.5), dc * CFrame.new(x, 0.6, 2.6), C(220, 220, 222), M.Metal)
			end
			for x = -w / 2 + 10, w / 2 - 10, 16 do
				L.D(m, Vector3.new(0.5, 2.6, 0.5), dc * CFrame.new(x, 1.7, -2.4), INK, M.Metal)
				L.D(m, Vector3.new(0.6, 0.4, 0.6), dc * CFrame.new(x, 3.1, -2.4), C(255, 236, 200), M.Neon)
			end
			L.B(m, cf, w / 2 - 8, -0.9, wz - 0.4, 3, 0.4, 2, C(206, 202, 194), M.Concrete) -- steps down
			for x = -w / 2 + 8, w / 2 - 8, 6 do L.D(m, Vector3.new(2.2, 1.2, 0.6), dc * CFrame.new(x, -0.2, 3.2), WHITE, M.Rubber) end
			-- empty berth alongside: the owner's boat goes here (drive straight in parallel to the dock)
			berth(m, dc * CFrame.new(0, -1.6, 12), w - 10, 18, o.name)
			if o.yacht == true then L.yacht(m, dc * CFrame.new(0, -1.6, 11) * CFrame.Angles(0, math.pi / 2, 0), o.yachtLen or L.r(50, 62), "motor") end
		elseif o.dock then
			local wz = d / 2
			L.P(m, Vector3.new(w, 3.4, 2.4), cf * CFrame.new(0, -1.2, wz - 1.2), C(206, 202, 194), M.Concrete, "ConcretePlain")
			local dc = cf * CFrame.new(o.dockX or (w * 0.25), L.WATER - L.G + 1.6, wz + 1)
			local dl = o.dockLen or 26
			L.P(m, Vector3.new(8, 0.8, dl), dc * CFrame.new(0, 0, dl / 2), st.deck, M.WoodPlanks, "WoodPlanksOld")
			-- wide T-head parallel to the shore: its outer face is an open-water berth you can drive straight onto
			L.P(m, Vector3.new(48, 0.8, 7), dc * CFrame.new(0, 0, dl - 3.5), st.deck, M.WoodPlanks, "WoodPlanksOld")
			for x = -22, 22, 6 do L.D(m, Vector3.new(2.2, 1.2, 0.6), dc * CFrame.new(x, -0.2, dl + 0.2), WHITE, M.Rubber) end
			for x = -20, 20, 10 do L.D(m, Vector3.new(0.6, 0.6, 1.4), dc * CFrame.new(x, 0.6, dl - 1), C(220, 220, 222), M.Metal) end
			for zz = 2, dl, 6 do for _, sx in ipairs({ -4, 4 }) do L.Cyl(m, 9, 1.1, dc * CFrame.new(sx, -3.6, zz), C(110, 90, 70), M.Wood) end end
			for zz = 4, dl, 8 do
				L.D(m, Vector3.new(0.5, 0.5, 1.4), dc * CFrame.new(3.6, 0.6, zz), C(220, 220, 222), M.Metal)
				L.D(m, Vector3.new(0.5, 2.6, 0.5), dc * CFrame.new(-3.6, 1.7, zz), INK, M.Metal)
				L.D(m, Vector3.new(0.6, 0.4, 0.6), dc * CFrame.new(-3.6, 3.1, zz), C(255, 236, 200), M.Neon)
			end
			-- empty berth on the outside of the T-head (open water, no piles in the way)
			berth(m, dc * CFrame.new(0, -1.6, dl + 11), 70, 20, o.name)
			if o.yacht == true then L.yacht(m, dc * CFrame.new(0, -1.6, dl + 10) * CFrame.Angles(0, math.pi / 2, 0), o.yachtLen or L.r(56, 72), "motor") end
		end
		m.Parent = par
		L.lod(m)
		if o.price then L.poi((cf * CFrame.new(entX, 0, -d / 2 + 8)).Position, "Property", o.name or "Villa", { Price = o.price, Tier = 5, Style = sname }) end
		return m
	end

	-- =====================================================================================
	-- MANGROVE: asset if present, otherwise a part-built tree with prop roots
	-- =====================================================================================
	function L.mangrove(par, pos, h)
		h = h or L.r(14, 24)
		local A = game:GetService("ServerStorage"):FindFirstChild("VBAssets")
		local pool = {}
		if A then for _, c in ipairs(A:GetChildren()) do if c.Name:match("^Mangrove") then table.insert(pool, c) end end end
		if #pool > 0 then
			local src = L.pick(pool)
			local mm = src:Clone()
			local s = h / math.max(1, (src:GetAttribute("H") or mm:GetExtentsSize().Y))
			pcall(function() mm:ScaleTo(s) end)
			mm:PivotTo(CFrame.new(pos) * CFrame.Angles(0, L.r(0, 6.28), 0))
			mm.Name = "Mangrove"
			mm.Parent = par
			return mm
		end
		local m = L.model(par, "Mangrove")
		local trunk = C(96, 80, 64)
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + L.r(-0.3, 0.3)
			local foot = pos + Vector3.new(math.cos(a) * h * 0.35, -1, math.sin(a) * h * 0.35)
			local knee = pos + Vector3.new(math.cos(a) * h * 0.22, h * 0.28, math.sin(a) * h * 0.22)
			L.bar(m, foot, knee, 0.5, trunk, M.Wood)
			L.bar(m, knee, pos + Vector3.new(0, h * 0.42, 0), 0.6, trunk, M.Wood)
		end
		L.bar(m, pos + Vector3.new(0, h * 0.4, 0), pos + Vector3.new(0, h * 0.7, 0), 1, trunk, M.Wood)
		-- dense rounded canopy from the bush meshes, a few branches poking out
		for k = 1, 4 do
			local c = pos + Vector3.new(L.r(-h * 0.28, h * 0.28), h * L.r(0.5, 0.62), L.r(-h * 0.28, h * 0.28))
			local b = L.bush(m, c, h * L.r(0.42, 0.6))
			if b then for _, d in ipairs(b:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end end
			L.bar(m, pos + Vector3.new(0, h * 0.55, 0), c + Vector3.new(0, h * 0.1, 0), 0.4, trunk, M.Wood)
		end
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
		return m
	end

	-- =====================================================================================
	-- MARINA KIT: concrete floating pontoon with fender strip, pedestals every berth, lights
	-- =====================================================================================
	function L.pontoon(par, cf, len, wid, o)
		-- cf at water level, runs along local -Z
		o = o or {}
		wid = wid or 10
		local m = L.model(par, o.name or "Pontoon")
		L.P(m, Vector3.new(wid, 2.2, len), cf * CFrame.new(0, 1.0, -len / 2), C(214, 212, 206), M.Concrete, "ConcretePlain")
		L.D(m, Vector3.new(wid - 1.2, 0.06, len), cf * CFrame.new(0, 2.13, -len / 2), C(186, 150, 110), M.WoodPlanks, "WoodPlanksOld")
		for sd = -1, 1, 2 do
			L.D(m, Vector3.new(0.5, 0.7, len), cf * CFrame.new(sd * (wid / 2 + 0.2), 1.1, -len / 2), C(40, 40, 42), M.Rubber)
			for z = 6, len - 3, o.berth or 22 do
				L.D(m, Vector3.new(0.6, 0.5, 1.6), cf * CFrame.new(sd * (wid / 2 - 0.6), 2.35, -z), C(230, 230, 232), M.Metal)
			end
		end
		for z = 10, len - 4, o.berth or 22 do
			local pc = cf * CFrame.new(o.pedX or (wid / 2 - 1.4), 2.1, -z)
			L.B(m, pc, 0, 0, 0, 1.2, 3.4, 1.2, WHITE, M.SmoothPlastic)
			L.B(m, pc, 0, 3.4, 0, 1.3, 0.5, 1.3, C(40, 140, 220), M.SmoothPlastic)
			L.D(m, Vector3.new(0.9, 0.3, 0.9), pc * CFrame.new(0, 3.9, 0), C(220, 240, 255), M.Neon)
		end
		for z = 0, len, 30 do
			local lc = cf * CFrame.new(-(wid / 2 - 1), 2.1, -z)
			L.B(m, lc, 0, 0, 0, 0.5, 4.6, 0.5, C(50, 52, 56), M.Metal)
			L.D(m, Vector3.new(0.8, 0.4, 0.8), lc * CFrame.new(0, 4.8, 0), C(255, 236, 200), M.Neon)
		end
		return m
	end


	-- =====================================================================================
	-- GRIME for rundown buildings: splash-zone dirt band, rust/water streaks, peeling paint, cracks,
	-- roof clutter (dish, antenna, tarp) and yard junk. Box = body (centre bx,bz, size bw x bd, height h).
	-- =====================================================================================
	function L.grime(m, cf, bx, bz, bw, bd, h, o)
		o = o or {}
		local fz, rz = bz - bd / 2, bz + bd / 2
		local dirt = C(70, 62, 52)
		-- wall wear now comes from the streak / crack decals (L.grimeBox); only roof and yard clutter here
		local _ = dirt or fz or rz
		-- roof clutter
		if L.chance(0.45) then
			local dc = cf * CFrame.new(bx + L.r(-bw / 3, bw / 3), h + (o.flat and 0.6 or 3), bz + L.r(-bd / 4, bd / 4))
			L.B(m, dc, 0, 0, 0, 0.3, 1.6, 0.3, C(150, 150, 150), M.Metal)
			L.D(m, Vector3.new(0.3, 2.6, 2.6), dc * CFrame.new(0, 2, -0.3) * CFrame.Angles(0, L.r(-1, 1), 0) * CFrame.Angles(0, 0, math.rad(25)), C(220, 220, 216), M.Metal, nil, { Shape = Enum.PartType.Cylinder })
		end
		if L.chance(0.3) then
			local ac = cf * CFrame.new(bx + L.r(-bw / 4, bw / 4), h + (o.flat and 0.4 or 2.6), bz + L.r(-bd / 4, bd / 4))
			L.B(m, ac, 0, 0, 0, 0.2, 5, 0.2, C(120, 120, 120), M.Metal)
			for k = 0, 3 do L.B(m, ac, 0, 3 + k * 0.6, 0, 3 - k * 0.6, 0.12, 0.12, C(120, 120, 120), M.Metal) end
		end
		if o.pitched and L.chance(0.22) then
			L.P(m, Vector3.new(L.r(6, 10), 0.15, L.r(5, 8)), cf * CFrame.new(bx + L.r(-bw / 4, bw / 4), h + 2.6, bz - bd / 5) * CFrame.Angles(math.rad(-30), L.r(-0.2, 0.2), 0), C(40, 90, 170), M.Fabric)
			for k = 0, 2 do L.B(m, cf * CFrame.new(bx + L.r(-bw / 4, bw / 4), h + 2.2 + k * 0.4, bz - bd / 5 + L.r(-2, 2)), 0, 0, 0, 1, 0.5, 1, C(120, 112, 100), M.Concrete) end
		end
		-- yard junk in front
		if o.yard ~= false then
			local yz = fz - L.r(3, 6)
			local r = L.rng:NextNumber()
			if r < 0.25 then
				for k = 0, L.ri(1, 3) do L.D(m, Vector3.new(1, 2.6, 2.6), cf * CFrame.new(bx - bw / 2 + 2 + k * 0.9, 1.1 + (k % 2) * 0.2, yz) * CFrame.Angles(0, 0, 0), C(26, 26, 26), M.Rubber, nil, { Shape = Enum.PartType.Cylinder, CanCollide = true }) end
			elseif r < 0.45 then
				L.B(m, cf * CFrame.new(bx + bw / 4, 0, yz), 0, 1.4, 0, 1.6, 0.2, 1.6, WHITE, M.Plastic)
				L.B(m, cf * CFrame.new(bx + bw / 4, 0, yz), 0, 1.6, 0.7, 1.6, 1.4, 0.2, WHITE, M.Plastic)
				for _, q in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do L.B(m, cf * CFrame.new(bx + bw / 4, 0, yz), q[1], 0, q[2], 0.15, 1.4, 0.15, WHITE, M.Plastic) end
			elseif r < 0.55 then
				L.P(m, Vector3.new(5, 6.4, 0.8), cf * CFrame.new(bx - bw / 3, 3.1, fz - 0.9) * CFrame.Angles(math.rad(-10), 0, 0), L.pick({ C(196, 186, 170), C(160, 170, 190) }), M.Fabric)
			elseif r < 0.65 then
				local cc = cf * CFrame.new(bx + L.r(-bw / 3, bw / 3), 0, yz)
				L.B(m, cc, 0, 1.2, 0, 2.2, 1.6, 3, C(170, 172, 176), M.Metal, nil, { Transparency = 0.3 })
				for _, q in ipairs({ { -0.9, -1.2 }, { 0.9, -1.2 }, { -0.9, 1.2 }, { 0.9, 1.2 } }) do L.B(m, cc, q[1], 0, q[2], 0.3, 1.2, 0.3, C(40, 40, 40), M.Rubber) end
			end
		end
	end

	-- extra grime pass over hood roads + sidewalks: cracks, oil stains, potholes, puddles, gum spots
	function L.roadGrime(seg, part, density)
		local s = part.Size
		local len = math.max(s.X, s.Z)
		local wid = math.min(s.X, s.Z)
		local alongX = s.X > s.Z
		local top = part.CFrame * CFrame.new(0, s.Y / 2, 0)
		local function at(u, v) -- u along, v across
			if alongX then return top * CFrame.new(u, 0, v) end
			return top * CFrame.new(v, 0, u) * CFrame.Angles(0, math.pi / 2, 0)
		end
		-- keep clear of the ends (crosswalks, stop lines, junction boxes) so wear never sits on markings
		local pad = 22
		if len - 2 * pad < 8 then return end
		local n = math.floor((len - 2 * pad) / 30 * density + L.r(0, 1))
		for _ = 1, n do
			local r = L.rng:NextNumber()
			local u, v = L.r(-len / 2 + pad, len / 2 - pad), L.r(-wid / 2 + 2, wid / 2 - 2)
			-- skip the centre-line band so cracks don't cut through the paint
			if math.abs(v) < 1.6 then v = v + (v >= 0 and 2.4 or -2.4) end
			if r < 0.45 then
				-- crack: 3-5 jagged segments
				local c = at(u, v) * CFrame.Angles(0, L.r(0, 6.28), 0)
				for k = 0, L.ri(2, 4) do
					local sl = L.r(1.5, 4)
					L.D(seg, Vector3.new(0.22, 0.03, sl), c * CFrame.new(0, 0.03, -sl / 2), C(34, 34, 34), M.SmoothPlastic, nil, { Transparency = 0.25 })
					c = c * CFrame.new(0, 0, -sl) * CFrame.Angles(0, L.r(-0.8, 0.8), 0)
				end
			elseif r < 0.7 then
				-- oil / water stain
				local dsz = L.r(2.5, 6)
				L.D(seg, Vector3.new(0.03, dsz, dsz * L.r(0.6, 1)), at(u, v) * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), C(30, 30, 32), M.SmoothPlastic, nil, { Shape = Enum.PartType.Cylinder, Transparency = L.r(0.45, 0.7) })
			elseif r < 0.88 and density >= 2 then
				-- pothole: dark disc with a crumbled pale rim (only on the roughest streets)
				local dsz = L.r(2.2, 4.4)
				L.D(seg, Vector3.new(0.04, dsz + 0.8, dsz + 0.6), at(u, v) * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), C(150, 146, 136), M.Asphalt, nil, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
				L.D(seg, Vector3.new(0.05, dsz, dsz * 0.8), at(u, v) * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), C(22, 22, 22), M.Asphalt, nil, { Shape = Enum.PartType.Cylinder })
			else
				-- puddle near the gutter
				local dsz = L.r(3, 7)
				L.D(seg, Vector3.new(0.03, dsz, dsz * 0.6), at(u, (v > 0 and 1 or -1) * (wid / 2 - 2.5)) * CFrame.new(0, 0.025, 0) * CFrame.Angles(0, 0, math.pi / 2), C(120, 136, 150), M.Glass, nil, { Shape = Enum.PartType.Cylinder, Transparency = 0.35, Reflectance = 0.35 })
			end
		end
	end

	-- lobby upgrade: inlaid marble floor, coffered ceiling with cove light, walnut feature panels, columns, art
	function L.lobbyLux(m, cf, w, d, LH)
		local BR = C(196, 160, 90)
		-- floor border + medallion inlay
		for sd = -1, 1, 2 do
			L.D(m, Vector3.new(w - 6, 0.04, 1.2), cf * CFrame.new(0, 0.62, sd * (d / 2 - 3)), C(40, 40, 44), M.Marble, "LobbyMarble")
			L.D(m, Vector3.new(1.2, 0.04, d - 6), cf * CFrame.new(sd * (w / 2 - 3), 0.62, 0), C(40, 40, 44), M.Marble, "LobbyMarble")
		end
		L.D(m, Vector3.new(0.05, 14, 14), cf * CFrame.new(0, 0.63, -d * 0.1) * CFrame.Angles(0, 0, math.pi / 2), C(40, 40, 44), M.Marble, "LobbyMarble", { Shape = Enum.PartType.Cylinder })
		L.D(m, Vector3.new(0.05, 11, 11), cf * CFrame.new(0, 0.64, -d * 0.1) * CFrame.Angles(0, 0, math.pi / 2), C(236, 232, 224), M.Marble, "LobbyMarble", { Shape = Enum.PartType.Cylinder })
		L.D(m, Vector3.new(0.05, 4, 4), cf * CFrame.new(0, 0.65, -d * 0.1) * CFrame.Angles(0, 0, math.pi / 2), BR, M.Metal, nil, { Shape = Enum.PartType.Cylinder })
		-- coffered ceiling with warm cove lighting
		local nx, nz = math.max(2, math.floor(w / 14)), math.max(2, math.floor(d / 14))
		for i = 1, nx - 1 do L.D(m, Vector3.new(1.2, 1.4, d - 4), cf * CFrame.new(-w / 2 + i * w / nx, LH - 2.8, 0), C(232, 228, 220), M.SmoothPlastic) end
		for j = 1, nz - 1 do L.D(m, Vector3.new(w - 4, 1.4, 1.2), cf * CFrame.new(0, LH - 2.8, -d / 2 + j * d / nz), C(232, 228, 220), M.SmoothPlastic) end
		for sd = -1, 1, 2 do L.D(m, Vector3.new(w - 6, 0.25, 0.25), cf * CFrame.new(0, LH - 2.4, sd * (d / 2 - 2.6)), C(255, 214, 160), M.Neon) end
		-- walnut panels between the elevator doors, brass reveals
		for sd = -1, 1, 2 do
			L.D(m, Vector3.new(w * 0.18, LH - 6, 0.3), cf * CFrame.new(sd * w * 0.38, (LH - 6) / 2 + 0.6, d / 2 - 1.35), C(92, 62, 42), M.WoodPlanks, "WoodPlanksOld")
			L.D(m, Vector3.new(0.2, LH - 6, 0.35), cf * CFrame.new(sd * (w * 0.38 - w * 0.09), (LH - 6) / 2 + 0.6, d / 2 - 1.4), BR, M.Metal)
		end
		-- stone columns with brass collars
		for _, q in ipairs({ { -0.3, -0.3 }, { 0.3, -0.3 }, { -0.3, 0.25 }, { 0.3, 0.25 } }) do
			local cc = cf * CFrame.new(q[1] * w, 0.6, q[2] * d)
			L.Cyl(m, LH - 3, 3, cc * CFrame.new(0, (LH - 3) / 2, 0), C(226, 220, 210), M.Marble, "LobbyMarble")
			L.Cyl(m, 0.6, 3.4, cc * CFrame.new(0, 0.3, 0), BR, M.Metal)
			L.Cyl(m, 0.6, 3.4, cc * CFrame.new(0, LH - 3.3, 0), BR, M.Metal)
		end
		-- big art on the side walls (inside the glass), floor vases
		for sd = -1, 1, 2 do
			F.art(m, cf * CFrame.new(sd * (w / 2 - 1.2), LH * 0.45, d * 0.2) * CFrame.Angles(0, sd < 0 and math.pi / 2 or -math.pi / 2, 0), 9, 6)
			F.plant(m, cf * CFrame.new(sd * (w / 2 - 3), 0.6, -d / 2 + 4), 1.6)
		end
	end
end
