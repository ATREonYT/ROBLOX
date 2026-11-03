-- Vice Bay downtown architecture. Fictional towers whose design language is taken from real landmarks:
--  exo     : curving white concrete exoskeleton (One Thousand Museum, Zaha Hadid)
--  stepped : stepped, colour-lit crown tiers (Miami Tower)
--  twist   : floor plates rotating up the tower (twisting towers)
--  flatiron: triangular plan on a wedge site (Brickell Flatiron)
--  xbrace  : exposed diagonal structure on the facade (SOM's new downtown office tower)
--  sail    : bulging sail-shaped profile (Aston Martin Residences)
--  taper   : rounded plan that tapers to the top (Una Residences)
--  balcony : white slab balconies that wave up the facade (Brickell condo towers, Missoni Baia)
--  glass   : clean curtain-wall office with fins and a lit crown
--  artdeco : Ocean Drive hotels (eyebrows, rounded corners, neon fin)
return function(L)
	local M, C = L.M, L.C
	L.GLASS = { C(70, 96, 122), C(56, 78, 100), C(88, 116, 134), C(64, 104, 110), C(96, 92, 84), C(46, 60, 78) }
	local WHITE = C(236, 236, 232)

	local function glassBox(m, cf, sx, sy, sz, y0, col)
		local p = L.P(m, Vector3.new(sx, sy, sz), cf * CFrame.new(0, y0 + sy / 2, 0), col, M.Glass, nil, { Reflectance = 0.32, CastShadow = true })
		if L.glassFaces then L.glassFaces(p) end
		return p
	end
	L.glassBox = glassBox
	local function bands(m, cf, sx, sz, y0, y1, step, col, protrude, th)
		local y = y0 + step
		while y < y1 - 1 do
			L.D(m, Vector3.new(sx + protrude, th or 0.8, sz + protrude), cf * CFrame.new(0, y, 0), col, M.Concrete, "ConcretePlain")
			y += step
		end
	end
	local function fins(m, cf, sx, sz, y0, h, n, col)
		for side = -1, 1, 2 do
			for k = 1, n do
				local x = -sx / 2 + k * sx / (n + 1)
				L.D(m, Vector3.new(0.6, h, 1.2), cf * CFrame.new(x, y0 + h / 2, side * (sz / 2 + 0.6)), col, M.Metal)
			end
		end
	end
	local function crown(m, cf, sx, sz, top, col)
		L.P(m, Vector3.new(sx - 6, 14, sz - 6), cf * CFrame.new(0, top + 7, 0), L.shade(col, 0.8), M.Metal)
		for side = -1, 1, 2 do
			L.D(m, Vector3.new(sx + 0.4, 0.5, 0.4), cf * CFrame.new(0, top - 1, side * (sz / 2 + 0.2)), C(240, 248, 255), M.Neon)
			L.D(m, Vector3.new(0.4, 0.5, sz + 0.4), cf * CFrame.new(side * (sx / 2 + 0.2), top - 1, 0), C(240, 248, 255), M.Neon)
		end
	end
	-- red aircraft-warning beacon
	local function beacon(m, p)
		L.D(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(p), C(255, 40, 40), M.Neon, nil, { Shape = Enum.PartType.Ball })
	end

	-- ===== podium with parking screen + lobby + amenity deck (pool, palms) =====
	function L.podium(m, cf, w, d, h, o)
		o = o or {}
		local col = o.col or C(214, 210, 200)
		L.P(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), col, M.Concrete, o.var or "DowntownPrecastPanel")
		-- lobby: glass ground floor + canopy
		L.D(m, Vector3.new(w * 0.7, 12, 0.3), cf * CFrame.new(0, 6.5, -d / 2 - 0.1), C(40, 50, 58), M.Glass, nil, { Reflectance = 0.3 })
		L.P(m, Vector3.new(w * 0.4, 0.8, 8), cf * CFrame.new(0, 13, -d / 2 - 4), C(40, 40, 44), M.Metal)
		-- parking-screen levels
		for y = 18, h - 4, 8 do
			L.D(m, Vector3.new(w + 0.3, 1.2, d + 0.3), cf * CFrame.new(0, y, 0), L.shade(col, 0.85), M.Concrete)
			L.D(m, Vector3.new(w + 0.2, 3.2, d + 0.2), cf * CFrame.new(0, y + 3, 0), C(44, 46, 50), M.Metal, nil, { Transparency = 0.2 })
		end
		if o.sign then
			L.sign(m, cf * CFrame.new(-w / 4, 15.5, -d / 2 - 0.3), math.min(w * 0.4, #o.sign * 1.6 + 6), 2.6, o.sign, C(20, 20, 22), C(236, 236, 232), Enum.Font.GothamMedium, { lit = true })
		end
		if o.deck then
			-- amenity deck: pool, loungers, palms
			local dk = cf * CFrame.new(0, h, 0)
			L.D(m, Vector3.new(w - 2, 0.3, d - 2), dk * CFrame.new(0, 0.15, 0), C(214, 206, 192), M.Concrete, "PlazaTiles")
			local px = o.deckX or 0
			L.D(m, Vector3.new(math.min(w * 0.35, 40), 0.4, math.min(d * 0.25, 18)), dk * CFrame.new(px, 0.35, d / 4), C(40, 180, 210), M.Glass, nil, { Transparency = 0.2 })
			for k = -2, 2 do
				L.D(m, Vector3.new(2, 0.6, 5), dk * CFrame.new(px + k * 5, 0.6, d / 4 - 13), WHITE, M.Fabric)
			end
			for _, q in ipairs({ { -w / 2 + 5, d / 2 - 5 }, { w / 2 - 5, d / 2 - 5 }, { -w / 2 + 5, -d / 2 + 5 }, { w / 2 - 5, -d / 2 + 5 } }) do
				L.palm(m, (dk * CFrame.new(q[1], 0.3, q[2])).Position, L.r(22, 30))
			end
		end
	end

	-- ===== tower kinds =====
	local K = {}
	function K.glass(m, cf, w, d, h, o)
		local col = o.col or L.pick(L.GLASS)
		glassBox(m, cf, w, h, d, o.y0, col)
		bands(m, cf, w, d, o.y0, o.y0 + h, 24, C(200, 206, 210), 0.6, 0.6)
		fins(m, cf, w, d, o.y0, h, 5, C(190, 196, 200))
		crown(m, cf, w, d, o.y0 + h, col)
		if o.spire then
			L.Cyl(m, o.spire, 1.6, cf * CFrame.new(0, o.y0 + h + 14 + o.spire / 2, 0), C(200, 200, 204), M.Metal)
			beacon(m, (cf * CFrame.new(0, o.y0 + h + 14 + o.spire, 0)).Position)
			return nil
		end
		return { y = o.y0 + h + 14, w = w - 6, d = d - 6 }
	end
	function K.balcony(m, cf, w, d, h, o)
		local col = o.col or C(70, 96, 112)
		local cw, cd = w - 8, d - 8
		glassBox(m, cf, cw, h, cd, o.y0, col)
		local phase = L.r(0, 6)
		local wave = o.wave and 3 or 0
		for y = o.y0 + 12, o.y0 + h - 4, 12 do
			local f = (y - o.y0) / 12
			local bf = 4 + wave * math.sin(f * 0.32 + phase)
			local bb = 4 + wave * math.sin(f * 0.32 + phase + 2)
			local sz = cd + bf + bb
			local zc = (bb - bf) / 2
			L.D(m, Vector3.new(cw + 6, 0.9, sz), cf * CFrame.new(0, y, zc), WHITE, M.Concrete, "ConcretePlain", { CastShadow = true })
			L.D(m, Vector3.new(cw + 5.6, 3.2, 0.2), cf * CFrame.new(0, y + 2, -cd / 2 - bf + 0.2), C(160, 196, 210), M.Glass, nil, { Transparency = 0.55 })
			L.D(m, Vector3.new(cw + 5.6, 3.2, 0.2), cf * CFrame.new(0, y + 2, cd / 2 + bb - 0.2), C(160, 196, 210), M.Glass, nil, { Transparency = 0.55 })
		end
		L.P(m, Vector3.new(cw + 6, 3, cd + 8), cf * CFrame.new(0, o.y0 + h + 1.5, 0), WHITE, M.Concrete, "ConcretePlain")
		L.P(m, Vector3.new(cw * 0.5, 12, cd * 0.5), cf * CFrame.new(0, o.y0 + h + 9, 0), WHITE, M.Concrete, "ConcretePlain")
		return { y = o.y0 + h + 3, w = cw + 6, d = cd + 8, legs = 16 }
	end
	function K.exo(m, cf, w, d, h, o)
		local col = o.col or C(60, 84, 104)
		glassBox(m, cf, w, h, d, o.y0, col)
		bands(m, cf, w, d, o.y0, o.y0 + h, 36, C(220, 222, 224), 0.4, 0.6)
		-- 8 ribs (4 corners + 4 face mids) whose offset from the facade bulges at the base and the crown
		local ribs = {
			{ 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 },
		}
		local segs = 8
		for _, r in ipairs(ribs) do
			local prev
			for k = 0, segs do
				local t = k / segs
				local y = o.y0 + t * h
				local off = 2 + 13 * (2 * t - 1) ^ 2
				local x = r[1] * (w / 2 + off * (r[1] ~= 0 and 1 or 0))
				local z = r[2] * (d / 2 + off * (r[2] ~= 0 and 1 or 0))
				if r[1] == 0 then x = 0; z = r[2] * (d / 2 + off * 0.8) end
				if r[2] == 0 then z = 0; x = r[1] * (w / 2 + off * 0.8) end
				local p = (cf * CFrame.new(x, y, z)).Position
				if prev then
					local len = (p - prev).Magnitude
					L.P(m, Vector3.new(5.5, 5.5, len + 2.5), CFrame.lookAt((p + prev) / 2, p), WHITE, M.Concrete, "ConcretePlain")
				end
				prev = p
			end
		end
		-- ring beams tie the ribs at base / mid / top
		for _, t in ipairs({ 0.02, 0.5, 0.98 }) do
			local off = 2 + 13 * (2 * t - 1) ^ 2
			local y = o.y0 + t * h
			L.D(m, Vector3.new(w + 2 * off + 2, 2.2, 2.2), cf * CFrame.new(0, y, -(d / 2 + off)), WHITE, M.Concrete)
			L.D(m, Vector3.new(w + 2 * off + 2, 2.2, 2.2), cf * CFrame.new(0, y, d / 2 + off), WHITE, M.Concrete)
		end
		beacon(m, (cf * CFrame.new(0, o.y0 + h + 2, 0)).Position)
		return { y = o.y0 + h, w = w, d = d }
	end
	function K.stepped(m, cf, w, d, h, o)
		local col = o.col or C(226, 228, 230)
		local body = h * 0.78
		L.P(m, Vector3.new(w, body, d), cf * CFrame.new(0, o.y0 + body / 2, 0), col, M.Concrete, "DowntownConcreteFacade")
		-- ribbon windows
		for y = o.y0 + 8, o.y0 + body - 4, 12 do
			L.D(m, Vector3.new(w + 0.2, 4, d + 0.2), cf * CFrame.new(0, y, 0), C(50, 70, 88), M.Glass, nil, { Reflectance = 0.3 })
		end
		-- three stepped, rounded, colour-lit tiers
		local tierH = (h - body) / 3
		local lit = o.lit or { C(0, 180, 255), C(255, 60, 160), C(120, 80, 255) }
		for k = 1, 3 do
			local s = 1 - 0.2 * k
			local y = o.y0 + body + (k - 1) * tierH
			local tw, td = w * s, d * s
			local back = (d - td) / 2
			L.P(m, Vector3.new(tw, tierH, td), cf * CFrame.new(0, y + tierH / 2, back), col, M.Concrete, "DowntownConcreteFacade")
			L.Cyl(m, tierH, tw, cf * CFrame.new(0, y + tierH / 2, back - td / 2) * CFrame.Angles(0, 0, 0), col, M.Concrete, "DowntownConcreteFacade")
			L.Cyl(m, 1, tw + 0.6, cf * CFrame.new(0, y + tierH - 0.5, back - td / 2), lit[k], M.Neon, nil, { CanCollide = false })
		end
		beacon(m, (cf * CFrame.new(0, o.y0 + h + 1, d * 0.2)).Position)
	end
	function K.twist(m, cf, w, d, h, o)
		local col = o.col or L.pick(L.GLASS)
		local step = 16
		local n = math.floor(h / step)
		local total = o.turn or math.rad(90)
		for k = 0, n - 1 do
			local y = o.y0 + k * step
			local rot = cf * CFrame.Angles(0, total * k / n, 0)
			local gp = L.P(m, Vector3.new(w, step - 1, w), rot * CFrame.new(0, y + (step - 1) / 2, 0), col, M.Glass, nil, { Reflectance = 0.32, CastShadow = true })
			if L.glassFaces then L.glassFaces(gp, { row = step }) end
			L.D(m, Vector3.new(w + 1.4, 1, w + 1.4), rot * CFrame.new(0, y + step - 0.5, 0), C(220, 224, 228), M.Concrete, "ConcretePlain")
		end
		L.Cyl(m, 40, 2, cf * CFrame.new(0, o.y0 + n * step + 20, 0), C(210, 210, 214), M.Metal)
		beacon(m, (cf * CFrame.new(0, o.y0 + n * step + 41, 0)).Position)
	end
	function K.flatiron(m, cf, w, d, h, o)
		local col = o.col or C(60, 90, 110)
		-- triangle plan: two wedges laid flat (vertical prism), point toward -Z
		local function prism(y0, hh, c, mat, var, opt)
			for side = -1, 1, 2 do
				local p = L.W(m, Vector3.new(hh, w / 2, d), cf * CFrame.new(side * w / 4, y0 + hh / 2, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(side > 0 and 0 or math.pi, 0, 0), c, mat, var, opt)
			end
		end
		prism(o.y0, h, col, M.Glass, nil, { Reflectance = 0.32 })
		for y = o.y0 + 24, o.y0 + h - 4, 24 do
			for side = -1, 1, 2 do
				L.W(m, Vector3.new(0.8, w / 2 + 0.6, d + 0.6), cf * CFrame.new(side * (w / 4 + 0.15), y, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(side > 0 and 0 or math.pi, 0, 0), C(220, 224, 228), M.Concrete, "ConcretePlain").CanCollide = false
			end
		end
		prism(o.y0 + h, 10, C(200, 204, 208), M.Metal)
		beacon(m, (cf * CFrame.new(0, o.y0 + h + 12, 0)).Position)
	end
	function K.xbrace(m, cf, w, d, h, o)
		local col = o.col or C(52, 66, 80)
		glassBox(m, cf, w, h, d, o.y0, col)
		local mod = 48
		local sc = C(214, 216, 218)
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			L.P(m, Vector3.new(3, h, 3), cf * CFrame.new(q[1] * (w / 2 + 1.5), o.y0 + h / 2, q[2] * (d / 2 + 1.5)), sc, M.Concrete, "ConcretePlain")
		end
		for y = o.y0, o.y0 + h - mod, mod do
			for _, face in ipairs({ { 0, -1, w }, { 0, 1, w }, { -1, 0, d }, { 1, 0, d } }) do
				local fl = face[3]
				local diag = math.sqrt(fl ^ 2 + mod ^ 2)
				local a = math.atan2(mod, fl)
				for s = -1, 1, 2 do
					local base
					if face[1] == 0 then
						base = cf * CFrame.new(0, y + mod / 2, face[2] * (d / 2 + 1.5))
						L.D(m, Vector3.new(diag, 2.2, 2.2), base * CFrame.Angles(0, 0, s * a), sc, M.Concrete)
					else
						base = cf * CFrame.new(face[1] * (w / 2 + 1.5), y + mod / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
						L.D(m, Vector3.new(diag, 2.2, 2.2), base * CFrame.Angles(0, 0, s * a), sc, M.Concrete)
					end
				end
			end
			L.D(m, Vector3.new(w + 3, 1.6, d + 3), cf * CFrame.new(0, y + mod, 0), sc, M.Concrete)
		end
		crown(m, cf, w, d, o.y0 + h, col)
		return { y = o.y0 + h + 14, w = w - 6, d = d - 6 }
	end
	function K.sail(m, cf, w, d, h, o)
		local col = o.col or C(84, 110, 126)
		local step = 24
		for y = o.y0, o.y0 + h - step, step do
			local t = (y - o.y0) / h
			local s = 0.62 + 0.38 * math.sin(math.pi * math.min(1, t * 1.15))
			local ww = w * s
			local shift = (w - ww) * 0.5 * (t > 0.5 and 1 or -0.3)
			local gp = L.P(m, Vector3.new(ww, step - 1, d), cf * CFrame.new(shift, y + (step - 1) / 2, 0), col, M.Glass, nil, { Reflectance = 0.32, CastShadow = true })
			if L.glassFaces then L.glassFaces(gp, { row = 12 }) end
			L.D(m, Vector3.new(ww + 3, 1, d + 3), cf * CFrame.new(shift, y + step - 0.5, 0), WHITE, M.Concrete, "ConcretePlain")
		end
		beacon(m, (cf * CFrame.new(0, o.y0 + h + 1, 0)).Position)
	end
	function K.taper(m, cf, w, d, h, o)
		local col = o.col or C(76, 100, 116)
		local step = 24
		for y = o.y0, o.y0 + h - step, step do
			local t = (y - o.y0) / h
			local s = 1 - 0.5 * t ^ 1.6
			local ww, dd = w * s, d * s
			L.P(m, Vector3.new(ww - dd, step - 1, dd), cf * CFrame.new(0, y + (step - 1) / 2, 0), col, M.Glass, nil, { Reflectance = 0.32 })
			for side = -1, 1, 2 do
				L.Cyl(m, step - 1, dd, cf * CFrame.new(side * (ww - dd) / 2, y + (step - 1) / 2, 0), col, M.Glass, nil, { Reflectance = 0.32 })
			end
			L.D(m, Vector3.new(ww - dd, 1, dd + 2), cf * CFrame.new(0, y + step - 0.5, 0), WHITE, M.Concrete, "ConcretePlain")
		end
		beacon(m, (cf * CFrame.new(0, o.y0 + h + 1, 0)).Position)
	end

	-- ===== more tower families (so the skyline never repeats) =====
	-- deco: 1930s setback skyscraper (Chrysler / Empire State / Miami's Freedom Tower language):
	-- limestone tiers with dark window piers, cornices at each setback, a faceted stainless crown and needle
	function K.deco(m, cf, w, d, h, o)
		local col = o.col or C(216, 206, 186)
		local stone = L.shade(col, 1.06)
		local tiers = { { 1, 0.5 }, { 0.82, 0.2 }, { 0.64, 0.14 }, { 0.48, 0.08 } }
		local y = o.y0
		for _, t in ipairs(tiers) do
			local tw, td, th = w * t[1], d * t[1], h * t[2]
			L.P(m, Vector3.new(tw, th, td), cf * CFrame.new(0, y + th / 2, 0), col, M.Sandstone, "DowntownStoneBlocks")
			-- vertical window strips between stone piers
			local n = math.max(3, math.floor(tw / 7))
			for k = 1, n - 1 do
				local x = -tw / 2 + k * tw / n
				for sd = -1, 1, 2 do
					L.D(m, Vector3.new(2.2, th - 8, 0.2), cf * CFrame.new(x, y + th / 2, sd * (td / 2 + 0.05)), C(40, 50, 60), M.Glass, nil, { Reflectance = 0.2 })
				end
			end
			local nz = math.max(3, math.floor(td / 7))
			for k = 1, nz - 1 do
				local z = -td / 2 + k * td / nz
				for sd = -1, 1, 2 do
					L.D(m, Vector3.new(0.2, th - 8, 2.2), cf * CFrame.new(sd * (tw / 2 + 0.05), y + th / 2, z), C(40, 50, 60), M.Glass, nil, { Reflectance = 0.2 })
				end
			end
			-- cornice + uplight at every setback
			L.D(m, Vector3.new(tw + 2, 2, td + 2), cf * CFrame.new(0, y + th - 1, 0), stone, M.Sandstone)
			L.D(m, Vector3.new(tw + 2.4, 0.4, td + 2.4), cf * CFrame.new(0, y + th - 2.2, 0), C(255, 214, 150), M.Neon)
			y += th
		end
		-- faceted crown: shrinking boxes, every other one turned 45 degrees
		local cw = w * 0.4
		for k = 0, 5 do
			local s = cw * (1 - k * 0.15)
			local c = cf * CFrame.new(0, y + 4, 0) * CFrame.Angles(0, (k % 2) * math.pi / 4, 0)
			L.P(m, Vector3.new(s, 8, s), c, C(206, 210, 216), M.Metal, nil, { Reflectance = 0.35 })
			L.D(m, Vector3.new(s + 0.4, 0.4, s + 0.4), c * CFrame.new(0, 3.8, 0), C(255, 236, 190), M.Neon)
			y += 8
		end
		L.Cyl(m, 60, 1.2, cf * CFrame.new(0, y + 30, 0), C(210, 212, 216), M.Metal)
		beacon(m, (cf * CFrame.new(0, y + 61, 0)).Position)
	end
	-- jenga: stacked glass floor-blocks pushed in and out (56 Leonard / Jenga Building)
	function K.jenga(m, cf, w, d, h, o)
		local col = o.col or L.pick(L.GLASS)
		local cw, cd = w - 14, d - 14
		local step = 12
		local n = math.floor(h / step)
		local rr = Random.new(math.floor(cf.X * 7 + cf.Z))
		local ox, oz = 0, 0
		for k = 0, n - 1 do
			local y = o.y0 + k * step
			local amp = 2 + 5 * (k / n) ^ 2 -- the top floors cantilever the most
			if k % 2 == 0 then
				ox = (rr:NextNumber() * 2 - 1) * amp
				oz = (rr:NextNumber() * 2 - 1) * amp
			end
			local c = cf * CFrame.new(ox, y, oz)
			local gp = L.P(m, Vector3.new(cw, step - 1, cd), c * CFrame.new(0, (step - 1) / 2, 0), col, M.Glass, nil, { Reflectance = 0.3, CastShadow = true })
			if L.glassFaces then L.glassFaces(gp, { row = step }) end
			L.D(m, Vector3.new(cw + 0.8, 1, cd + 0.8), c * CFrame.new(0, step - 0.5, 0), WHITE, M.Concrete, "ConcretePlain")
		end
		return { y = o.y0 + n * step, w = cw, d = cd, x = ox, z = oz }
	end
	-- round: cylindrical glass condo with white ring balconies (Brickell round towers)
	function K.round(m, cf, w, d, h, o)
		local col = o.col or C(78, 110, 124)
		local dia = math.min(w, d) - 8
		L.Cyl(m, h, dia, cf * CFrame.new(0, o.y0 + h / 2, 0), col, M.Glass, nil, { Reflectance = 0.3, CastShadow = true })
		for y = o.y0 + 12, o.y0 + h - 4, 12 do
			L.Cyl(m, 0.9, dia + 8, cf * CFrame.new(0, y, 0), WHITE, M.Concrete, "ConcretePlain", { CanCollide = false })
			L.Cyl(m, 3, dia + 7.4, cf * CFrame.new(0, y + 2, 0), C(170, 204, 214), M.Glass, nil, { Transparency = 0.6, CanCollide = false })
		end
		L.Cyl(m, 3, dia + 8, cf * CFrame.new(0, o.y0 + h + 1.5, 0), WHITE, M.Concrete, "ConcretePlain")
		L.Cyl(m, 14, dia * 0.55, cf * CFrame.new(0, o.y0 + h + 10, 0), WHITE, M.Concrete, "ConcretePlain")
		L.Cyl(m, 0.6, dia + 8.4, cf * CFrame.new(0, o.y0 + h + 3.2, 0), C(120, 220, 255), M.Neon, nil, { CanCollide = false })
		return { y = o.y0 + h + 3, w = dia * 0.8, d = dia * 0.8, legs = 18 }
	end
	-- brutal: deep concrete egg-crate grid over dark glass (1970s civic / bank towers)
	function K.brutal(m, cf, w, d, h, o)
		local col = o.col or C(178, 172, 162)
		L.P(m, Vector3.new(w - 4, h, d - 4), cf * CFrame.new(0, o.y0 + h / 2, 0), C(34, 40, 46), M.Glass, nil, { Reflectance = 0.15 })
		-- solid base and top
		L.P(m, Vector3.new(w, 16, d), cf * CFrame.new(0, o.y0 + 8, 0), col, M.Concrete, "DowntownPrecastPanel")
		L.P(m, Vector3.new(w, 10, d), cf * CFrame.new(0, o.y0 + h - 5, 0), col, M.Concrete, "DowntownPrecastPanel")
		local sp = 8
		for _, f in ipairs({ { 1, 0, w, d }, { 0, 1, d, w } }) do
			local n = math.floor(f[3] / sp)
			for k = 1, n - 1 do
				local a = -f[3] / 2 + k * f[3] / n
				for sd = -1, 1, 2 do
					local pos = f[1] == 1 and CFrame.new(a, o.y0 + h / 2, sd * (f[4] / 2 - 0.5)) or CFrame.new(sd * (f[4] / 2 - 0.5), o.y0 + h / 2, a)
					local sz = f[1] == 1 and Vector3.new(1.6, h - 26, 3.4) or Vector3.new(3.4, h - 26, 1.6)
					L.D(m, sz, cf * pos, col, M.Concrete, "ConcretePlain")
				end
			end
		end
		for y = o.y0 + 16 + 12, o.y0 + h - 12, 12 do
			L.D(m, Vector3.new(w + 0.4, 1.6, d + 0.4), cf * CFrame.new(0, y, 0), col, M.Concrete, "ConcretePlain")
		end
		return { y = o.y0 + h, w = w - 8, d = d - 8 }
	end
	-- frame: glass slab held by a giant white portal frame that rises past the roof (Brickell City Centre / Four Seasons)
	function K.frame(m, cf, w, d, h, o)
		local col = o.col or L.pick(L.GLASS)
		local fw = 6
		glassBox(m, cf, w - 2 * fw, h, d - 4, o.y0, col)
		bands(m, cf, w - 2 * fw, d - 4, o.y0, o.y0 + h, 12, C(46, 56, 66), 0.3, 0.4)
		for sd = -1, 1, 2 do
			L.P(m, Vector3.new(fw, h + 34, d), cf * CFrame.new(sd * (w / 2 - fw / 2), o.y0 + (h + 34) / 2, 0), WHITE, M.Concrete, "ConcretePlain")
			L.D(m, Vector3.new(0.4, h + 30, 0.6), cf * CFrame.new(sd * (w / 2 - fw - 0.1), o.y0 + (h + 30) / 2, -d / 2 + 0.6), C(255, 250, 236), M.Neon)
		end
		L.P(m, Vector3.new(w, 6, d), cf * CFrame.new(0, o.y0 + h + 31, 0), WHITE, M.Concrete, "ConcretePlain")
		-- colour stripe up the face
		L.D(m, Vector3.new(3, h, 0.3), cf * CFrame.new(-w / 6, o.y0 + h / 2, -d / 2 + 1.8), L.pick({ C(30, 130, 170), C(200, 120, 60), C(70, 160, 120) }), M.Glass, nil, { Reflectance = 0.4 })
		return { y = o.y0 + h, w = w - 2 * fw - 2, d = d - 6, legs = 4 }
	end
	-- slab: wide Miami condo slab with staggered balconies, tinted glass rails and white shear-wall ends (Icon / Jade)
	function K.slab(m, cf, w, d, h, o)
		local col = o.col or C(66, 98, 116)
		local tint = L.pick({ C(90, 190, 200), C(70, 130, 200), C(160, 210, 220), C(120, 180, 150) })
		local bd = d - 10
		glassBox(m, cf, w - 4, h, bd, o.y0, col)
		for sd = -1, 1, 2 do
			L.P(m, Vector3.new(4, h + 8, bd + 10), cf * CFrame.new(sd * (w / 2 - 2), o.y0 + (h + 8) / 2, 0), WHITE, M.Plaster, "StuccoWhite")
		end
		local f = 0
		for y = o.y0 + 11, o.y0 + h - 4, 11 do
			f += 1
			for side = -1, 1, 2 do
				-- two balcony runs per face that swap lengths every floor (the staggered look)
				local split = (f % 2 == 0) and 0.38 or 0.62
				local runs = { { -(w - 8) / 2, -(w - 8) / 2 + (w - 8) * split }, { -(w - 8) / 2 + (w - 8) * split + 4, (w - 8) / 2 } }
				for ri, r in ipairs(runs) do
					local len = r[2] - r[1]
					if len > 6 then
						local depth = (ri == (f % 2) + 1) and 5 or 3
						local z = side * (bd / 2 + depth / 2)
						L.D(m, Vector3.new(len, 0.8, depth), cf * CFrame.new((r[1] + r[2]) / 2, y, z), WHITE, M.Concrete, "ConcretePlain")
						L.D(m, Vector3.new(len, 3, 0.2), cf * CFrame.new((r[1] + r[2]) / 2, y + 1.9, side * (bd / 2 + depth - 0.1)), tint, M.Glass, nil, { Transparency = 0.45 })
					end
				end
			end
		end
		L.P(m, Vector3.new(w - 4, 2, bd + 2), cf * CFrame.new(0, o.y0 + h + 1, 0), WHITE, M.Concrete, "ConcretePlain")
		return { y = o.y0 + h + 2, w = w - 12, d = bd - 2 }
	end

	-- ===== rooftop helipad: raised steel helideck, yellow circle + H, edge lights, safety net, windsock =====
	function L.helipad(m, cf, size, legs)
		local s = math.clamp(size, 28, 46)
		local lh = legs or 5
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 } }) do
			L.P(m, Vector3.new(1.4, lh, 1.4), cf * CFrame.new(q[1] * s * 0.36, lh / 2, q[2] * s * 0.36), C(64, 66, 70), M.Metal)
		end
		L.P(m, Vector3.new(s, 0.8, s), cf * CFrame.new(0, lh - 0.6, 0), C(64, 66, 70), M.DiamondPlate)
		local deck = L.P(m, Vector3.new(s, 0.6, s), cf * CFrame.new(0, lh + 0.1, 0), C(84, 88, 92), M.Concrete, "ConcretePlain")
		deck.Name = "Helipad"
		local top = cf * CFrame.new(0, lh + 0.4, 0)
		L.Cyl(m, 0.06, s * 0.8, top * CFrame.new(0, 0.03, 0), C(244, 200, 40), M.SmoothPlastic, nil, { CanCollide = false })
		L.Cyl(m, 0.08, s * 0.72, top * CFrame.new(0, 0.04, 0), C(84, 88, 92), M.Concrete, nil, { CanCollide = false })
		local hw, hh = s * 0.075, s * 0.34
		for sd = -1, 1, 2 do L.D(m, Vector3.new(hw, 0.1, hh), top * CFrame.new(sd * s * 0.12, 0.05, 0), C(248, 248, 246), M.SmoothPlastic) end
		L.D(m, Vector3.new(s * 0.24, 0.1, hw), top * CFrame.new(0, 0.05, 0), C(248, 248, 246), M.SmoothPlastic)
		-- white edge stripe, perimeter lights, angled safety net
		for _, e in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
			local ex, ez = e[1] * (s / 2 - 1), e[2] * (s / 2 - 1)
			L.D(m, Vector3.new(e[1] == 0 and s - 2 or 0.8, 0.1, e[1] == 0 and 0.8 or s - 2), top * CFrame.new(ex, 0.05, ez), C(248, 248, 246), M.SmoothPlastic)
			local net = top * CFrame.new(e[1] * (s / 2 + 1.8), -0.6, e[2] * (s / 2 + 1.8))
			if e[1] == 0 then
				L.D(m, Vector3.new(s, 0.15, 3.6), net * CFrame.Angles(e[2] * 0.25, 0, 0), C(40, 42, 46), M.Metal, nil, { Transparency = 0.45 })
			else
				L.D(m, Vector3.new(3.6, 0.15, s), net * CFrame.Angles(0, 0, -e[1] * 0.25), C(40, 42, 46), M.Metal, nil, { Transparency = 0.45 })
			end
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
			L.D(m, Vector3.new(0.7, 0.5, 0.7), top * CFrame.new(q[1] * (s / 2 - 0.4), 0.25, q[2] * (s / 2 - 0.4)), C(80, 255, 120), M.Neon)
		end
		-- windsock on the corner
		local wc = top * CFrame.new(s / 2 + 3, 0, -s / 2 - 3)
		L.Cyl(m, 9, 0.35, wc * CFrame.new(0, 4.5, 0), C(230, 230, 230), M.Metal)
		L.D(m, Vector3.new(1.4, 1.4, 5), wc * CFrame.new(0, 8.4, 2.6) * CFrame.Angles(-0.25, 0, 0), C(255, 120, 30), M.Fabric)
		local p = deck.Position + Vector3.new(0, 0.5, 0)
		return p
	end
	L.TOWERS = K

	-- one building: podium (optional) + tower kind

	-- ===== grand entrance: double-height lobby you can walk into + porte-cochere drop-off + valet + garage ramp =====
	local MARBLE, BRASS, WOOD = C(236, 232, 226), C(196, 160, 90), C(92, 64, 44)
	function L.sofa(m, cf, w, col)
		col = col or C(60, 62, 66)
		L.B(m, cf, 0, 0, 0, w, 1.6, 3.2, col, M.Fabric)
		L.B(m, cf, 0, 1.6, 1.2, w, 1.8, 0.8, col, M.Fabric)
		L.B(m, cf, -w / 2 + 0.4, 1.6, 0, 0.8, 1, 3.2, col, M.Fabric)
		L.B(m, cf, w / 2 - 0.4, 1.6, 0, 0.8, 1, 3.2, col, M.Fabric)
	end
	-- lobby box occupies the tower footprint (w x d) from y 0..LH, front at z = -d/2 (local)
	function L.lobby(m, cf, w, d, LH, name)
		local fz, bz = -d / 2, d / 2
		-- floor + ceiling slab (the tower sits on top)
		L.P(m, Vector3.new(w, 0.6, d), cf * CFrame.new(0, 0.3, 0), MARBLE, M.Marble, "LobbyMarble")
		L.P(m, Vector3.new(w + 1, 2, d + 1), cf * CFrame.new(0, LH - 1, 0), C(30, 32, 36), M.Metal)
		L.D(m, Vector3.new(w - 4, 0.2, d - 4), cf * CFrame.new(0, LH - 2.1, 0), C(240, 236, 228), M.SmoothPlastic)
		-- glass curtain walls (front has the entrance gap) + slim mullions
		local gap = 22
		local seg = (w - gap) / 2
		for side = -1, 1, 2 do
			L.P(m, Vector3.new(seg, LH - 2, 0.4), cf * CFrame.new(side * (gap / 2 + seg / 2), (LH - 2) / 2 + 0.6, fz), C(150, 180, 190), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.2 })
			L.P(m, Vector3.new(0.4, LH - 2, d), cf * CFrame.new(side * w / 2, (LH - 2) / 2 + 0.6, 0), C(150, 180, 190), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.2 })
		end
		L.P(m, Vector3.new(gap, LH - 12, 0.4), cf * CFrame.new(0, 11 + (LH - 12) / 2, fz), C(150, 180, 190), M.Glass, nil, { Transparency = 0.55 })
		-- back wall: stone feature wall with the building name + elevator bank
		local back = L.P(m, Vector3.new(w, LH - 2, 1.2), cf * CFrame.new(0, (LH - 2) / 2 + 0.6, bz - 0.6), C(214, 204, 188), M.Sandstone, "DowntownStoneBlocks")
		for x = -w / 2 + 3, w / 2 - 3, 6 do
			L.D(m, Vector3.new(0.3, LH - 2, 0.6), cf * CFrame.new(x, (LH - 2) / 2 + 0.6, fz - 0.2), C(40, 42, 46), M.Metal)
		end
		local ne = math.clamp(math.floor(w / 14), 2, 4)
		for k = 1, ne do
			local x = -w / 2 + k * w / (ne + 1)
			L.BD(m, cf, x, 0.6, bz - 1.3, 5, 9, 0.2, C(190, 192, 196), M.Metal, nil, { Reflectance = 0.4 })
			L.BD(m, cf, x, 9.6, bz - 1.3, 6.4, 0.6, 0.3, BRASS, M.Metal)
			L.BD(m, cf, x, 10.4, bz - 1.35, 1.6, 0.6, 0.1, C(255, 200, 120), M.Neon)
		end
		-- reception desk with a backlit name panel
		local dc = cf * CFrame.new(0, 0.6, d * 0.12)
		L.B(m, dc, 0, 0, 0, 16, 3.6, 3, MARBLE, M.Marble, "LobbyMarble")
		L.B(m, dc, 0, 3.6, 0, 16.4, 0.3, 3.4, WOOD, M.Wood)
		L.BD(m, dc, 0, 0.2, -1.55, 15, 0.3, 0.1, BRASS, M.Neon)
		local plate = L.BD(m, cf, 0, LH * 0.45, bz - 1.4, math.min(w - 10, 30), 4, 0.2, C(20, 20, 22), M.SmoothPlastic)
		L.text(plate, Enum.NormalId.Front, name or "", { font = Enum.Font.Merriweather, color = BRASS, pps = 14, dist = 120, light = 0 })
		-- lounge: two sofas facing a coffee table on a rug, planters, a statement chandelier
		for side = -1, 1, 2 do
			local lc = cf * CFrame.new(side * w * 0.28, 0.6, -d * 0.15)
			L.BD(m, lc, 0, 0, 0, 16, 0.1, 12, C(120, 110, 96), M.Fabric)
			L.sofa(m, lc * CFrame.new(0, 0, 4), 10, side < 0 and C(70, 66, 60) or C(150, 120, 92))
			L.sofa(m, lc * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0), 10, side < 0 and C(70, 66, 60) or C(150, 120, 92))
			L.B(m, lc, 0, 0, 0, 5, 1.6, 3, WOOD, M.Wood)
			L.bush(m, (cf * CFrame.new(side * (w / 2 - 4), 0.6, bz - 6)).Position, 5)
			L.Cyl(m, 3, 4, cf * CFrame.new(side * (w / 2 - 4), 2.1, bz - 6), C(40, 40, 44), M.Concrete)
		end
		local ch = cf * CFrame.new(0, LH - 6, -d * 0.1)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			L.D(m, Vector3.new(0.8, 4 + (k % 2) * 2, 0.8), ch * CFrame.new(math.cos(a) * 3, -(k % 2), math.sin(a) * 3), C(255, 236, 200), M.Neon)
		end
		local pl = Instance.new("PointLight")
		pl.Range = 40
		pl.Brightness = 1.4
		pl.Color = C(255, 230, 190)
		pl.Shadows = false
		pl.Parent = L.D(m, Vector3.new(1, 1, 1), ch, C(255, 236, 200), M.Neon, nil, { Transparency = 1 })
		if L.lobbyLux then L.lobbyLux(m, cf, w, d, LH) end
	end

	-- porte-cochere in the forecourt in front of the lobby. cf = tower centre frame, fd = forecourt depth,
	-- pw = plaza width. Builds the U drive, canopy, fountain island, valet, garage ramp and the curb cuts.
	function L.porteCochere(m, cf, w, d, fd, pw, o)
		o = o or {}
		local fz = -d / 2
		local front = fz - fd
		local lane = 14
		local lx = math.min(pw / 2 - lane / 2 - 4, w / 2 + 4)
		local asph = C(56, 56, 60)
		-- pavers for the whole forecourt
		L.D(m, Vector3.new(pw, 0.3, fd), cf * CFrame.new(0, 0.15, fz - fd / 2), C(212, 202, 186), M.Pavement, "HerringbonePavers")
		-- U drive: two legs + the cross lane under the canopy
		for side = -1, 1, 2 do
			L.P(m, Vector3.new(lane, 0.35, fd - 4), cf * CFrame.new(side * lx, 0.2, front + (fd - 4) / 2), asph, M.Asphalt, "DowntownAsphaltClean")
			-- driveway apron across the sidewalk to the street (+ curb cut)
			local mouth = cf * CFrame.new(side * lx, 0, front - 11)
			L.P(m, Vector3.new(lane, 0.5, 24), mouth * CFrame.new(0, 0.05, 0), asph, M.Asphalt, "DowntownAsphaltClean")
			L.cutSidewalk(mouth * CFrame.new(0, 0.5, 0), Vector3.new(lane + 2, 3, 22))
			-- arrows painted on the legs (in on the right, out on the left)
			L.D(m, Vector3.new(0.6, 0.05, 6), cf * CFrame.new(side * lx, 0.4, front + 12), C(240, 240, 236), M.SmoothPlastic)
		end
		L.P(m, Vector3.new(2 * lx + lane, 0.35, lane), cf * CFrame.new(0, 0.2, fz - 4 - lane / 2), asph, M.Asphalt, "DowntownAsphaltClean")
		-- island: water feature + royal palms + sculpture
		local ic = cf * CFrame.new(0, 0, (front + fz - 4 - lane) / 2)
		local iw, id = 2 * lx - lane - 4, fd - lane - 12
		if iw > 8 and id > 8 then
			L.B(m, ic, 0, 0, 0, iw, 1.4, id, C(200, 196, 188), M.Concrete, "ConcretePlain")
			L.BD(m, ic, 0, 1.2, 0, iw - 3, 0.3, id - 3, C(40, 140, 160), M.Glass, nil, { Transparency = 0.25, Reflectance = 0.3 })
			L.B(m, ic, 0, 1.4, 0, 3, 7, 3, BRASS, M.Metal, nil, { Reflectance = 0.3 })
			L.Ball(m, 4, ic * CFrame.new(0, 10.5, 0), BRASS, M.Metal, nil, { Reflectance = 0.4 })
			for sx = -1, 1, 2 do L.palm(m, (ic * CFrame.new(sx * (iw / 2 - 3), 1.4, 0)).Position, L.r(34, 40), "royal") end
		end
		-- the canopy: thin cantilevered slab with a lit underside, over the cross lane
		local cw = 2 * lx + lane + 6
		L.P(m, Vector3.new(cw, 1.6, lane + 8), cf * CFrame.new(0, 17, fz - (lane + 8) / 2 + 1), C(236, 236, 232), M.Concrete, "ConcretePlain")
		L.D(m, Vector3.new(cw - 1, 0.15, lane + 7), cf * CFrame.new(0, 16.15, fz - (lane + 8) / 2 + 1), C(255, 238, 210), M.Neon, nil, { Transparency = 0.15 })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 18
		sl.Brightness = 1.2
		sl.Color = C(255, 236, 205)
		sl.Shadows = false
		sl.Parent = L.D(m, Vector3.new(cw - 2, 0.1, lane + 6), cf * CFrame.new(0, 16.05, fz - (lane + 8) / 2 + 1), C(255, 238, 210), M.Neon, nil, { Transparency = 1 })
		for sx = -1, 1, 2 do L.Cyl(m, 16, 1.6, cf * CFrame.new(sx * (cw / 2 - 2), 8.2, fz - lane - 6), C(40, 40, 44), M.Metal) end
		local cs = L.D(m, Vector3.new(math.min(cw - 10, 40), 2.4, 0.3), cf * CFrame.new(0, 18.6, fz - lane - 8), C(20, 20, 22), M.SmoothPlastic)
		L.text(cs, Enum.NormalId.Front, o.name or "", { font = Enum.Font.Merriweather, color = BRASS, pps = 14, dist = 300, light = 0 })
		-- valet stand + parked luxury cars
		local vc = cf * CFrame.new(lx - lane / 2 - 4, 0.3, fz - 6)
		L.B(m, vc, 0, 0, 0, 3, 3.6, 2, C(20, 20, 22), M.Wood)
		local vs = L.D(m, Vector3.new(3, 1, 0.1), vc * CFrame.new(0, 3, -1.05), C(20, 20, 22), M.SmoothPlastic)
		L.text(vs, Enum.NormalId.Front, "VALET", { font = Enum.Font.GothamBold, color = BRASS, pps = 30 })
		L.supercar(m, cf * CFrame.new(-lx * 0.35, 0.35, fz - 4 - lane / 2) * CFrame.Angles(0, -math.pi / 2, 0), nil, false)
		L.poi((vc * CFrame.new(0, 0, -2)).Position, "Job", (o.name or "Tower") .. " Valet", { Job = "Valet", Pay = 70 })
		-- garage ramp down to parking (side of the forecourt)
		local gx = -(pw / 2 - 8)
		if math.abs(gx) > lx + lane / 2 + 6 then
			local gc = cf * CFrame.new(gx, 0, fz - fd / 2)
			L.P(m, Vector3.new(12, 0.6, fd - 8), gc * CFrame.new(0, -2.6, 0) * CFrame.Angles(math.rad(-8), 0, 0), asph, M.Asphalt, "DowntownAsphaltClean")
			for sx = -1, 1, 2 do L.P(m, Vector3.new(1, 4, fd - 8), gc * CFrame.new(sx * 6.5, 0.6, 0), C(200, 196, 188), M.Concrete, "ConcretePlain") end
			local gs = L.D(m, Vector3.new(10, 2, 0.3), gc * CFrame.new(0, 5, (fd - 8) / 2), C(20, 60, 140), M.SmoothPlastic)
			L.text(gs, Enum.NormalId.Front, "P  PARKING", { font = Enum.Font.GothamBold, color = Color3.new(1, 1, 1), pps = 20 })
		end
	end


	-- extra layer of detail for the grand entrances (portal, revolving door, bollards, flags, planters, lights, art)
	function L.entranceDetails(m, cf, w, d, fd, pw, name, LH)
		local fz = -d / 2
		local STONE = C(222, 214, 200)
		-- stone portal around the doors + brass lettering
		for sx = -1, 1, 2 do L.P(m, Vector3.new(3, LH - 1, 3), cf * CFrame.new(sx * 12.5, (LH - 1) / 2 + 0.6, fz - 1), STONE, M.Sandstone, "DowntownStoneBlocks") end
		local lint = L.P(m, Vector3.new(28, 3, 3.4), cf * CFrame.new(0, LH - 1, fz - 1.2), STONE, M.Sandstone, "DowntownStoneBlocks")
		L.text(lint, Enum.NormalId.Front, name or "", { font = Enum.Font.Merriweather, color = BRASS, pps = 16, dist = 200, light = 0 })
		-- revolving door: glass drum, 4 wings, brass rings
		local rc = cf * CFrame.new(0, 0.6, fz - 0.2)
		L.Cyl(m, 0.4, 10, rc * CFrame.new(0, 0.2, 0), BRASS, M.Metal, nil, { CanCollide = false })
		L.Cyl(m, 0.6, 10.4, rc * CFrame.new(0, 9.4, 0), BRASS, M.Metal)
		for k = 0, 3 do
			L.D(m, Vector3.new(0.2, 9, 4.6), rc * CFrame.Angles(0, k * math.pi / 2 + 0.4, 0) * CFrame.new(0, 4.6, 2.3), C(170, 200, 210), M.Glass, nil, { Transparency = 0.6 })
		end
		L.Cyl(m, 9, 0.4, rc * CFrame.new(0, 4.6, 0), BRASS, M.Metal)
		-- swing doors either side (brass frames)
		for sx = -1, 1, 2 do
			L.D(m, Vector3.new(4.4, 9, 0.3), cf * CFrame.new(sx * 8.4, 5.1, fz - 0.4), C(170, 200, 210), M.Glass, nil, { Transparency = 0.5 })
			L.D(m, Vector3.new(0.3, 9, 0.4), cf * CFrame.new(sx * 10.7, 5.1, fz - 0.45), BRASS, M.Metal)
			L.D(m, Vector3.new(0.2, 3, 0.2), cf * CFrame.new(sx * 6.6, 5.1, fz - 0.7), BRASS, M.Metal)
		end
		-- planters with clipped hedges + uplit palms flanking the doors
		for sx = -1, 1, 2 do
			local pc = cf * CFrame.new(sx * 15, 0, fz - 4)
			L.B(m, pc, 0, 0.3, 0, 7, 3, 7, C(60, 62, 66), M.Concrete, "DowntownConcreteFacade")
			L.bush(m, (pc * CFrame.new(0, 3.3, 0)).Position, 6)
			local up = L.D(m, Vector3.new(1, 0.4, 1), pc * CFrame.new(2, 3.4, -2), C(255, 240, 210), M.Neon)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Top
			sl.Angle = 50
			sl.Range = 24
			sl.Brightness = 1.5
			sl.Color = C(255, 236, 200)
			sl.Shadows = false
			sl.Parent = up
		end
		-- three flagpoles on the forecourt edge
		local front = fz - fd
		for k = -1, 1 do
			local fp = cf * CFrame.new(-pw / 2 + 8 + k * 5, 0, front + 6)
			L.Cyl(m, 34, 0.5, fp * CFrame.new(0, 17, 0), C(220, 220, 224), M.Metal)
			L.Ball(m, 0.9, fp * CFrame.new(0, 34.4, 0), BRASS, M.Metal)
			L.D(m, Vector3.new(0.1, 4, 7), fp * CFrame.new(0, 31, 3.6), L.pick({ C(30, 60, 140), C(250, 250, 248), C(200, 30, 40) }), M.Fabric)
		end
		-- bollards along the street edge between the two drive mouths, + path lights
		for x = -pw / 2 + 4, pw / 2 - 4, 6 do
			if math.abs(math.abs(x) - math.min(pw / 2 - 11, w / 2 + 4)) > 10 then
				L.Cyl(m, 3, 1.2, cf * CFrame.new(x, 1.7, front + 1.5), C(60, 62, 66), M.Metal)
				L.D(m, Vector3.new(1.25, 0.25, 1.25), cf * CFrame.new(x, 3.1, front + 1.5), C(255, 236, 200), M.Neon)
			end
		end
		-- "DROP OFF" + hatched speed table under the canopy
		local dropC = cf * CFrame.new(0, 0.42, fz - 11)
		local dr = L.D(m, Vector3.new(16, 0.05, 4), dropC, C(240, 240, 236), M.SmoothPlastic, nil, { Transparency = 1 })
		L.text(dr, Enum.NormalId.Top, "DROP OFF", { font = Enum.Font.GothamBlack, color = C(240, 240, 236), pps = 12, dist = 150, light = 1 })
		for k = -3, 3 do L.D(m, Vector3.new(1.4, 0.06, 3), cf * CFrame.new(k * 3.2, 0.43, fz - 16), C(236, 200, 60), M.SmoothPlastic) end
		-- lobby extras: stone columns, sculpture on a plinth, LED wall, security turnstiles, coffee bar
		for sx = -1, 1, 2 do L.Cyl(m, LH - 2, 3, cf * CFrame.new(sx * w * 0.18, LH / 2, -d * 0.05), STONE, M.Marble, "LobbyMarble") end
		local sc = cf * CFrame.new(-w * 0.3, 0.6, d * 0.2)
		L.B(m, sc, 0, 0, 0, 4, 3, 4, C(30, 30, 32), M.Marble)
		L.Ball(m, 4, sc * CFrame.new(0, 5.5, 0), BRASS, M.Metal, nil, { Reflectance = 0.5 })
		local led = L.D(m, Vector3.new(0.3, 9, 16), cf * CFrame.new(w / 2 - 0.6, 8, d * 0.1), C(10, 12, 16), M.SmoothPlastic)
		L.text(led, Enum.NormalId.Left, "VBX  ▲ 2.4%   WELCOME TO " .. (name or ""), { font = Enum.Font.Code, color = C(80, 220, 255), pps = 10, dist = 120, light = 0 })
		for k = -2, 2 do L.B(m, cf, k * 4, 0.6, d / 2 - 12, 0.8, 3.4, 3, C(40, 42, 46), M.Metal) end
		local cb = cf * CFrame.new(w * 0.32, 0.6, d * 0.25)
		L.B(m, cb, 0, 0, 0, 10, 3.6, 3, WOOD, M.Wood)
		L.BD(m, cb, 0, 3.6, 0, 10.4, 0.3, 3.4, MARBLE, M.Marble)
		local cs = L.D(m, Vector3.new(6, 1.4, 0.2), cb * CFrame.new(0, 8, 1.6), C(20, 20, 22), M.SmoothPlastic)
		L.text(cs, Enum.NormalId.Front, "COFFEE", { font = Enum.Font.GothamBold, color = BRASS, pps = 20 })
	end

	function L.dtTower2(par, cf, o)
		local m = Instance.new("Model")
		m.Name = o.name or ("Tower_" .. o.kind)
		local y0 = 0
		if o.podiumH and o.podiumH > 0 then
			L.podium(m, cf, o.pw or (o.w + 20), o.pd or (o.d + 20), o.podiumH, { deck = o.deck, sign = o.sign })
			y0 = o.podiumH
		else
			-- plaza
			L.D(m, Vector3.new(o.pw or (o.w + 30), 0.3, o.pd or (o.d + 30)), cf * CFrame.new(0, 0.15, 0), C(206, 200, 188), M.Concrete, "DowntownPavers")
			if not o.entrance then L.D(m, Vector3.new(o.w * 0.8, 14, 0.4), cf * CFrame.new(0, 7, -o.d / 2 - 0.4), C(36, 44, 52), M.Glass, nil, { Reflectance = 0.3 }) end
			if o.sign and not o.entrance then L.sign(m, cf * CFrame.new(0, 3, -o.d / 2 - 10), math.min(30, #o.sign * 1.6 + 6), 3, o.sign, C(30, 30, 34), C(222, 190, 110), Enum.Font.GothamMedium, {}) end
		end
		local tc = cf * CFrame.new(o.ox or 0, 0, o.oz or 0)
		if o.entrance then
			-- tower sits on a double-height glass lobby, with a drop-off forecourt in front of it
			local LH = 24
			local fd = o.fd or 52
			tc = cf * CFrame.new(0, 0, (o.pd or (o.d + 30)) / 2 - o.d / 2 - 5)
			local lw = (o.kind == "twist") and o.w or o.w
			L.lobby(m, tc, lw, o.d, LH, o.sign or o.name)
			local fdepth = (o.pd or (o.d + 30)) - o.d - 8
			L.porteCochere(m, tc, o.w, o.d, fdepth, (o.pw or (o.w + 30)) - 4, { name = o.sign or o.name })
			L.entranceDetails(m, tc, o.w, o.d, fdepth, (o.pw or (o.w + 30)) - 4, o.sign or o.name, LH)
			y0 = LH
		end
		local roof = K[o.kind](m, tc, o.w, o.d, o.h, { y0 = y0, col = o.col, wave = o.wave, spire = o.spire, turn = o.turn, lit = o.lit })
		if o.heli and roof then
			local hp = L.helipad(m, tc * CFrame.new(roof.x or 0, roof.y, roof.z or 0), math.min(roof.w, roof.d), roof.legs)
			L.poi(hp, "Helipad", (o.sign or o.name or "Tower") .. " Helipad", {}, { iconDist = 900 })
		end
		m.Parent = par
		L.lod(m)
		L.footprint(par, cf, o.pw or (o.w + 30), o.pd or (o.d + 30))
		return m
	end

	-- ===== Ocean Drive art deco hotel =====
	L.DECO_COLS = { C(246, 214, 220), C(196, 232, 226), C(250, 232, 190), C(214, 222, 246), C(250, 246, 240), C(255, 206, 180) }
	L.DECO_NAMES = { "THE CORAL", "FLAMINGO", "PELICAN", "SEAGLASS", "NEPTUNE", "THE PARK CENTRAL", "TIDES", "BREAKWATER", "LUNA", "CAVALIER", "AVALON", "SUNRISE" }
	function L.artdeco(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = "ArtDecoHotel"
		local floors = o.floors or L.ri(3, 5)
		local h = floors * 11 + 2
		local col = o.color or L.pick(L.DECO_COLS)
		local acc = L.pick({ C(40, 170, 180), C(240, 120, 160), C(250, 190, 60), C(90, 120, 220) })
		local bd = d - 14
		local bz = d / 2 - bd / 2 - 1
		local fz = bz - bd / 2
		L.B(m, cf, 0, 0, bz, w, h, bd, col, M.Plaster, "StuccoWhite")
		-- rounded corners
		for side = -1, 1, 2 do L.Cyl(m, h, 8, cf * CFrame.new(side * (w / 2 - 3), h / 2, fz + 3), col, M.Plaster, "StuccoWhite") end
		-- eyebrows over every window band
		for f = 1, floors - 1 do
			local y = f * 11 + 7
			L.BD(m, cf, 0, y, fz - 1.6, w - 6, 0.5, 3.2, WHITE, M.Concrete)
			for k = 0, math.floor((w - 10) / 7) - 1 do
				local x = -w / 2 + 8 + k * 7
				L.BD(m, cf, x, y - 5.5, fz - 0.1, 4, 4.6, 0.2, C(40, 70, 90), M.Glass, nil, { Reflectance = 0.25 })
			end
		end
		-- accent stripes
		L.BD(m, cf, 0, h - 3, fz - 0.15, w, 1, 0.3, acc, M.SmoothPlastic)
		L.BD(m, cf, 0, h - 5, fz - 0.15, w, 0.6, 0.3, acc, M.SmoothPlastic)
		-- central fin with the neon name
		local name = o.sign or L.pick(L.DECO_NAMES)
		L.B(m, cf, 0, h - 6, fz - 1.5, 6, 22, 3, WHITE, M.Plaster, "StuccoWhite")
		local nf = L.BD(m, cf, 0, h - 4, fz - 3.1, 4.6, 18, 0.2, acc, M.Neon)
		L.text(nf, Enum.NormalId.Front, name:gsub(" ", "\n"), { font = Enum.Font.Arcade, color = Color3.new(1, 1, 1), pps = 10, dist = 500, light = 0 })
		-- porch / terrace with umbrellas
		L.BD(m, cf, 0, 0, -d / 2 + 6, w - 2, 0.8, 11, C(226, 216, 196), M.Concrete, "PlazaTiles")
		for k = -1, 1 do
			local uc = cf * CFrame.new(k * (w / 3), 0.8, -d / 2 + 6)
			L.Cyl(m, 7, 0.3, uc * CFrame.new(0, 3.5, 0), WHITE, M.Metal)
			L.Cyl(m, 0.6, 7, uc * CFrame.new(0, 7, 0), acc, M.Fabric)
			L.B(m, uc, 0, 0, 0, 3, 2.6, 3, WHITE, M.Wood)
		end
		L.BD(m, cf, 0, 0.8, fz - 0.1, w * 0.5, 9, 0.2, C(40, 60, 70), M.Glass)
		L.BD(m, cf, 0, h + 0.2, bz, w, 0.6, bd, L.shade(col, 0.9), M.Concrete)
		m.Parent = par
		L.lod(m)
		return m
	end

	-- ===== classic midrise office (stone base, glass, cornice) =====
	function L.office(par, cf, w, d, o)
		o = o or {}
		local m = Instance.new("Model")
		m.Name = "Office"
		local h = o.h or L.r(70, 140)
		local bd = math.min(d - 4, 60)
		local bz = -d / 2 + 2 + bd / 2
		local style = o.style or L.pick({ "classic", "brick", "modern", "classic" })
		if style == "brick" then
			-- 1920s brick office: punched windows, stone base and cornice
			local hb = math.min(h, 96)
			L.B(m, cf, 0, 0, bz, w, hb, bd, L.pick({ C(150, 76, 58), C(128, 70, 56), C(170, 100, 74) }), M.Brick, "DowntownBrickOld")
			L.B(m, cf, 0, 0, bz, w + 0.6, 14, bd + 0.6, C(206, 198, 184), M.Sandstone, "DowntownStoneBlocks")
			for y = 18, hb - 8, 11 do
				for x = -w / 2 + 6, w / 2 - 6, 7 do
					L.BD(m, cf, x, y, bz - bd / 2 - 0.1, 3.6, 6.2, 0.25, C(38, 48, 56), M.Glass, nil, { Reflectance = 0.2 })
					L.BD(m, cf, x, y - 0.6, bz - bd / 2 - 0.5, 4.6, 0.6, 1, C(206, 198, 184), M.Sandstone)
				end
			end
			L.B(m, cf, 0, hb, bz, w + 2, 3, bd + 2, C(206, 198, 184), M.Sandstone, "DowntownStoneBlocks")
			L.D(m, Vector3.new(w * 0.4, 10, 0.3), cf * CFrame.new(0, 5.5, bz - bd / 2 - 0.4), C(40, 50, 58), M.Glass)
			m.Parent = par
			L.lod(m)
			return m
		elseif style == "modern" then
			-- white-framed glass box with deep vertical fins and a set-back top floor
			L.B(m, cf, 0, 0, bz, w, h, bd, C(60, 86, 104), M.Glass, nil, { Reflectance = 0.3 })
			for x = -w / 2, w / 2, w / 8 do L.BD(m, cf, x, 0, bz - bd / 2 - 1.5, 1, h, 3, WHITE, M.Concrete, "ConcretePlain") end
			L.B(m, cf, 0, h, bz, w + 2, 2, bd + 2, WHITE, M.Concrete, "ConcretePlain")
			L.B(m, cf, 0, h + 2, bz + 4, w * 0.7, 10, bd * 0.7, C(56, 76, 92), M.Glass, nil, { Reflectance = 0.3 })
			L.B(m, cf, 0, h + 12, bz + 4, w * 0.7 + 4, 1, bd * 0.7 + 4, WHITE, M.Concrete)
			L.D(m, Vector3.new(w * 0.5, 0.8, 8), cf * CFrame.new(0, 13, bz - bd / 2 - 5), WHITE, M.Concrete)
			m.Parent = par
			L.lod(m)
			return m
		end
		L.B(m, cf, 0, 0, bz, w, 18, bd, C(204, 196, 182), M.Sandstone, "DowntownStoneBlocks")
		glassBox(m, cf * CFrame.new(0, 0, bz), w - 4, h - 18, bd - 4, 18, o.col or L.pick(L.GLASS))
		bands(m, cf * CFrame.new(0, 0, bz), w - 4, bd - 4, 18, h, 12, C(214, 210, 200), 0.8, 1)
		L.B(m, cf, 0, h, bz, w, 3, bd, C(204, 196, 182), M.Sandstone, "DowntownStoneBlocks")
		L.D(m, Vector3.new(w * 0.6, 12, 0.3), cf * CFrame.new(0, 6.5, bz - bd / 2 - 0.2), C(40, 50, 58), M.Glass)
		m.Parent = par
		L.lod(m)
		return m
	end
end
