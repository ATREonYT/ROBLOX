---------------------------------------------------------------------------------------------- the hall (World 2's lobby)
-- (Oct 27, the owner, for World 2's lobby: "for the second world C", the Oct 10 hall) World 2's lobby is that indoor
-- hall again, round World 2's own plan (e3_plaza's: the training block west, the gun stand east, the box dais south,
-- the portal SW, the boards in one straight row SE, the sale spots and chests by the door), at World 1's size (the
-- warehouse's footprint, Lobby.WH: x -86..86, z 6..116). Runs after e5_plaza, so its Lobby.hall replaces the plaza's.
--   Shell    light aqua walls 2.5 thick (faint studs), a darker studded base band with a pale lip, a paler cap band over
--            a cornice; periwinkle wall pillars with the kinked face (e2's Lobby.wallPillar) on the side and back walls
--            and the corners, kept clear of the training block's head deck
--   Windows  a big recessed window in every bay, cut through the wall, so the business district's towers (City.skyline, outside
--            the walls) show through; a wall lamp over each
--   Door     the north wall's exit bay: a grey framed recess round the open doorway (x +-23, 32 high) onto the Stage 1
--            gate, two framed panels over it, white neon lines
--   Roof     a light ceiling grid with a solid panel in every bay (round 5: was a skylight), blue steel lattice girders, long white light bars;
--            nothing up there (nor the walls or pillars) casts a shadow, so the sun lights the hall like the reference
--   Floor    one light lavender studded floor; a thin cyan neon line round each zone's platform (open where a walk
--            runs onto it), two tiled panels either side of the spine before the door
-- Studs: the city's look pass (city/x2_look) gives the shell's studded parts the faint stud texture on every face.

City.Hall = {
	H = 50, t = 2.5, DoorH = 32, WinY = 29, WinH = 16, Band = 43,
	Side = { 30, 74, 96 }, -- side-wall pillars (z): clear of the head deck (lobby round 1: z 47..63, out to the west wall)
	Back = { -43, 0, 43 }, -- back-wall pillars (x)
	Rows = { 30, 74, 96 }, -- cross girders and light-bar rows (z), on the side pillars
	Cols = { -60, -30, 0, 30, 60 }, -- long girders and light-bar centres (x)
	RX = 43, RH = 37, -- the exit bay's frame (half width, height)
}
-- The Oct 10 hall's colours (its Lobby.Colors with the LIGHT3 roof, window and lamp set).
City.HallColors = {
	walk = C(186, 188, 224), panel = C(146, 152, 206), band = C(88, 98, 146), cyan = C(84, 226, 250),
	wall = C(120, 206, 222), wallDark = C(98, 186, 206), pillar = C(150, 152, 196), channel = C(22, 30, 64),
	neon = C(240, 246, 255), frame = C(146, 154, 188), lamp = C(255, 252, 236),
	pillarSide = C(116, 120, 170), pillarBase = C(98, 104, 150), trim = C(200, 204, 228),
	wallBand = C(170, 226, 236), wallBase = C(88, 150, 178), sill = C(184, 190, 220),
	ceiling = C(192, 208, 232), ceilingPanel = C(224, 234, 248), skylight = C(196, 228, 255),
	truss = C(150, 168, 206), trussDark = C(128, 148, 192), barHousing = C(150, 162, 198), lampBack = C(120, 132, 164),
	winFrame = C(84, 112, 160), winGlass = C(214, 244, 255), glassTop = C(164, 216, 248),
}

-- A window w x h on a wall (cf on the wall's inner face at its centre, -Z into the hall), over a hole cut through the
-- wall: the thick frame standing 1.2 proud, clear glass (the towers show through), a transom, a pale sill, a head.
function City.hallWindow(c, cf, w, h)
	local K = City.HallColors
	local fw, fd = 1.5, 1.2
	local gw, gh = w - 2 * fw, h - 2 * fw
	for _, b in { { 0, h / 2 - fw / 2, w, fw }, { 0, -h / 2 + fw / 2, w, fw }, { -w / 2 + fw / 2, 0, fw, gh }, { w / 2 - fw / 2, 0, fw, gh } } do
		c:part('WindowFrame', V(b[3], b[4], fd), cf * CFrame.new(b[1], b[2], -fd / 2), K.winFrame, M.SmoothPlastic)
	end
	local glass = c:part('WindowGlass', V(gw, gh, 0.2), cf * CFrame.new(0, 0, 0.6), K.winGlass, M.Glass)
	glass.Transparency, glass.CastShadow = 0.75, false
	c:part('WindowTransom', V(gw, 1.0, 0.7), cf * CFrame.new(0, gh / 2 - gh * 0.3, -0.35), K.winFrame, M.SmoothPlastic)
	studs(c:part('WindowSill', V(w + 1.6, 0.9, 1.9), cf * CFrame.new(0, -h / 2 - 0.4, -0.95), K.sill, M.Plastic))
	c:part('WindowHead', V(w + 1, 0.7, 1.5), cf * CFrame.new(0, h / 2 + 0.35, -0.75), K.winFrame:Lerp(P.black, 0.25), M.SmoothPlastic)
end
function City.hallLamp(c, cf)
	local K = City.HallColors
	decor(c:part('WallLampBack', V(3.8, 1.6, 0.4), cf * CFrame.new(0, 0, -0.2), K.lampBack, M.SmoothPlastic)).CastShadow = false
	decor(c:part('WallLamp', V(3, 0.9, 0.45), cf * CFrame.new(0, 0.05, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), K.lamp, M.Neon)).CastShadow = false
end

-- The bays along one wall: between consecutive pillar lines (u), from a to b (studs clear of the pillars), one window
-- per 16 studs, each up to 11 wide. Returns { u, w } for every window.
function City.hallBays(lines, gapEnd, gapMid)
	local out = {}
	for i = 1, #lines - 1 do
		local a = lines[i] + (i == 1 and gapEnd or gapMid)
		local b = lines[i + 1] - (i == #lines - 1 and gapEnd or gapMid)
		local n = math.max(1, math.floor((b - a + 3) / 16))
		local w = math.min(11, (b - a) / n - 3)
		if w >= 6 then
			for k = 1, n do table.insert(out, { a + (b - a) * (k - 0.5) / n, w }) end
		end
	end
	return out
end

function Lobby.hall(L)
	local K, Hl, Wh = City.HallColors, City.Hall, Lobby.WH
	local H, T = Hl.H, Hl.t
	local x0, x1, z0, z1 = Wh.x0, Wh.x1, Wh.z0, Wh.z1
	local Dw, DH = Lobby.Door, Hl.DoorH
	Lobby.DoorH = DH
	local h = L:group('Hall')
	-- the floor: one light lavender slab under the hall and its walls ('Concrete': the look pass's faint studs, 3 layers)
	studs(h:box('Concrete', V(x0 - T, -1, z0 - T), V(x1 + T, 0, z1 + T), K.walk, M.Plastic))
	h:box('Threshold', V(-Lobby.Bounds.mouth, -1, Lobby.N - 4), V(Lobby.Bounds.mouth, 0, z0 - T), K.walk, M.SmoothPlastic)
	-- the windows, wall by wall: { wall, u, width }
	local wy, wh = Hl.WinY, Hl.WinH
	local wins = {}
	local sides = { z0, table.unpack(Hl.Side) }
	table.insert(sides, z1)
	for _, b in City.hallBays(sides, 6, Lobby.PillarW / 2) do
		table.insert(wins, { 'W', b[1], b[2] }); table.insert(wins, { 'E', b[1], b[2] })
	end
	local backs = { x0, table.unpack(Hl.Back) }
	table.insert(backs, x1)
	for _, b in City.hallBays(backs, 6, Lobby.PillarW / 2) do table.insert(wins, { 'S', b[1], b[2] }) end
	local edge = Hl.RX + 3.4
	for _, sx in { -1, 1 } do table.insert(wins, { 'N', sx * (edge + x1 - 6) / 2, 11 }) end
	-- the walls: each run built in bands between the holes' heights (the windows', the doorway's)
	local function run(w, u0, u1, holes)
		local function box(ua, ub, ya, yb)
			local a, b
			if w == 'N' then a, b = V(ua, ya, z0 - T), V(ub, yb, z0)
			elseif w == 'S' then a, b = V(ua, ya, z1), V(ub, yb, z1 + T)
			elseif w == 'W' then a, b = V(x0 - T, ya, ua), V(x0, yb, ub)
			else a, b = V(x1, ya, ua), V(x1 + T, yb, ub) end
			h:box('Wall', a, b, K.wall, M.SmoothPlastic)
		end
		local ys = { 0, H }
		for _, hl in holes do table.insert(ys, hl[3]); table.insert(ys, hl[4]) end
		table.sort(ys)
		for i = 1, #ys - 1 do
			local ya, yb = ys[i], ys[i + 1]
			if yb - ya > 0.01 then
				local open = {}
				for _, hl in holes do if hl[3] <= ya + 0.01 and hl[4] >= yb - 0.01 then table.insert(open, hl) end end
				table.sort(open, function(p, q) return p[1] < q[1] end)
				local u = u0
				for _, hl in open do
					if hl[1] > u + 0.01 then box(u, hl[1], ya, yb) end
					u = math.max(u, hl[2])
				end
				if u1 > u + 0.01 then box(u, u1, ya, yb) end
			end
		end
	end
	local holes = { N = { { -Dw, Dw, 0, DH } }, S = {}, W = {}, E = {} }
	for _, wn in wins do
		local gw, gh = wn[3] - 3, wh - 3
		table.insert(holes[wn[1]], { wn[2] - gw / 2, wn[2] + gw / 2, wy - gh / 2, wy + gh / 2 })
	end
	run('W', z0 - T, z1 + T, holes.W)
	run('E', z0 - T, z1 + T, holes.E)
	run('N', x0, x1, holes.N)
	run('S', x0, x1, holes.S)
	-- the walls' finish: a darker studded base band with a pale lip and a kick along the floor, a paler cap band over a
	-- cornice (the exit bay keeps the north wall's middle). strip(): a box on one wall's inner face, u along it.
	local function strip(name, side, u0, u1, y0, y1, depth, color, mat)
		local a, b
		if side == 'W' then a, b = V(x0, y0, u0), V(x0 + depth, y1, u1)
		elseif side == 'E' then a, b = V(x1 - depth, y0, u0), V(x1, y1, u1)
		elseif side == 'S' then a, b = V(u0, y0, z1 - depth), V(u1, y1, z1)
		else a, b = V(u0, y0, z0), V(u1, y1, z0 + depth) end
		return h:box(name, a, b, color, mat or M.SmoothPlastic)
	end
	local runs = { { 'W', z0, z1 }, { 'E', z0, z1 }, { 'S', x0, x1 }, { 'N', x0, -edge }, { 'N', edge, x1 } }
	for _, r in runs do
		studs(strip('WallBase', r[1], r[2], r[3], 0, 4, 0.35, K.wallBase), true)
		strip('WallBaseLip', r[1], r[2], r[3], 4, 4.5, 0.65, K.trim)
		strip('WallKick', r[1], r[2], r[3], 0, 0.8, 0.5, K.pillarBase)
		studs(strip('WallBand', r[1], r[2], r[3], Hl.Band, H, 0.2, K.wallBand), true)
		strip('WallCornice', r[1], r[2], r[3], Hl.Band - 1, Hl.Band, 0.75, K.trim)
	end
	-- wall frames: cf on the inner face at (u along the wall, y), -Z into the hall
	local frames = {
		W = function(u, y) return CFrame.lookAt(V(x0, y, u), V(x0 + 1, y, u)) end,
		E = function(u, y) return CFrame.lookAt(V(x1, y, u), V(x1 - 1, y, u)) end,
		S = function(u, y) return CFrame.lookAt(V(u, y, z1), V(u, y, z1 - 1)) end,
		N = function(u, y) return CFrame.lookAt(V(u, y, z0), V(u, y, z0 + 1)) end,
	}
	for _, wn in wins do
		local f = frames[wn[1]]
		City.hallWindow(h, f(wn[2], wy), wn[3], wh)
		City.hallLamp(h, f(wn[2], wy + wh / 2 + 2))
	end
	-- the pillars (e2's, in this hall's colours and height): the side walls, the back wall, the corners (narrow ones)
	local keepK, keepH = Lobby.Colors, Lobby.H
	Lobby.Colors, Lobby.H = K, H
	for _, z in Hl.Side do
		Lobby.wallPillar(h, V(x0, 0, z), V(1, 0, 0))
		Lobby.wallPillar(h, V(x1, 0, z), V(-1, 0, 0))
	end
	for _, x in Hl.Back do Lobby.wallPillar(h, V(x, 0, z1), V(0, 0, -1)) end
	for _, sx in { -1, 1 } do
		local xi = sx < 0 and x0 or x1
		Lobby.wallPillar(h, V(xi - sx * 3, 0, z1), V(0, 0, -1), nil, 6)
		Lobby.wallPillar(h, V(xi, 0, z1 - 3), V(-sx, 0, 0), nil, 6)
		Lobby.wallPillar(h, V(xi - sx * 3, 0, z0), V(0, 0, 1), nil, 6)
		Lobby.wallPillar(h, V(xi, 0, z0 + 3), V(-sx, 0, 0), nil, 6)
	end
	Lobby.Colors, Lobby.H = keepK, keepH
	City.exitBay(h)
	City.hallRoof(L)
	-- the shell lets the sun in (the reference's bright interior): the walls, their bands and the pillars cast no shadow
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and (p.Name:find('^Wall') or p.Name:find('^Pillar')) then p.CastShadow = false end
	end
	City.skyline(L)
	return h
end

-- The north wall's centre: a framed recess round the open doorway onto the Stage 1 gate, two framed panels over it,
-- white neon lines under and between them and up the frame's edges (steady light).
function City.exitBay(h)
	local K, Hl, N = City.HallColors, City.Hall, Lobby.WH.z0
	local Dw, DH, RX, RH, fw = Lobby.Door, Hl.DoorH, Hl.RX, Hl.RH, 3.4
	local e = h:group('ExitBay')
	for _, seg in { { -RX, -Dw - 2 }, { Dw + 2, RX } } do e:box('ExitRecess', V(seg[1], 0, N), V(seg[2], RH, N + 0.12), K.wallDark, M.SmoothPlastic) end
	e:box('ExitRecess', V(-Dw - 2, DH + 2, N), V(Dw + 2, RH, N + 0.12), K.wallDark, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local a, b = sx * RX, sx * (RX + fw)
		studs(e:box('ExitFrame', V(math.min(a, b), 0, N), V(math.max(a, b), RH + fw, N + 1.6), K.frame, M.Plastic), true)
		local c, d = sx * Dw, sx * (Dw + 2)
		e:box('DoorJamb', V(math.min(c, d), 0, N - Hl.t), V(math.max(c, d), DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	end
	studs(e:box('ExitFrame', V(-RX - fw, RH, N), V(RX + fw, RH + fw, N + 1.6), K.frame, M.Plastic), true)
	e:box('DoorHead', V(-Dw - 2, DH, N - Hl.t), V(Dw + 2, DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	local py0, py1 = RH + fw + 1.2, Hl.H - 2.5
	for _, sx in { -1, 1 } do
		local a, b = sx * 1.6, sx * RX
		local lo, hi = math.min(a, b), math.max(a, b)
		e:box('ExitPanel', V(lo, py0, N), V(hi, py1, N + 0.12), K.wallDark, M.SmoothPlastic)
		for _, ed in { { V(lo, py0, N), V(hi, py0 + 1.6, N + 1.2) }, { V(lo, py1 - 1.6, N), V(hi, py1, N + 1.2) }, { V(lo, py0, N), V(lo + 1.6, py1, N + 1.2) }, { V(hi - 1.6, py0, N), V(hi, py1, N + 1.2) } } do
			studs(e:box('ExitPanelFrame', ed[1], ed[2], K.frame, M.Plastic), true)
		end
	end
	local function neon(a, b) decor(e:box('ExitNeon', a, b, K.neon, M.Neon)).CastShadow = false end
	neon(V(-RX - fw, RH + fw, N + 1.2), V(RX + fw, RH + fw + 0.7, N + 1.6))
	neon(V(-0.4, RH + fw, N + 0.3), V(0.4, py1, N + 0.9))
	for _, sx in { -1, 1 } do
		local a, b = sx * (RX + fw), sx * (RX + fw - 0.6)
		neon(V(math.min(a, b), 0.4, N + 1.6), V(math.max(a, b), RH + fw + 0.7, N + 1.9))
	end
	return e
end

-- The roof: a light ceiling grid on the girder lines with a skylight in every bay, lattice girders along and across,
-- long light bars hung under the cross girders. All named Roof*, none casts a shadow.
function City.hallRoof(L)
	local K, Hl, Wh = City.HallColors, City.Hall, Lobby.WH
	local H, T = Hl.H, Hl.t
	local x0, x1, z0, z1 = Wh.x0, Wh.x1, Wh.z0, Wh.z1
	local r = L:group('Roof')
	local xs, zs = { x0 }, { z0 }
	for _, x in Hl.Cols do table.insert(xs, x) end
	for _, z in Hl.Rows do table.insert(zs, z) end
	table.insert(xs, x1)
	table.insert(zs, z1)
	for i, x in xs do
		local a = (i == 1 or i == #xs) and T or 3
		local lo, hi = i == 1 and x - T or x - a, i == #xs and x + T or x + a
		r:box('RoofCeiling', V(lo, H, z0 - T), V(hi, H + 1, z1 + T), K.ceiling, M.SmoothPlastic)
	end
	for j, z in zs do
		local a = (j == 1 or j == #zs) and T or 3
		local lo, hi = j == 1 and z - T or z - a, j == #zs and z + T or z + a
		r:box('RoofCeiling', V(x0, H, lo), V(x1, H + 1, hi), K.ceiling, M.SmoothPlastic)
	end
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local a0, a1 = xs[i] + (i > 1 and 3 or 0), xs[i + 1] - (i < #xs - 1 and 3 or 0)
			local b0, b1 = zs[j] + (j > 1 and 3 or 0), zs[j + 1] - (j < #zs - 1 and 3 or 0)
			-- (Oct 27 round 5, the owner: "add roofs to the warehouses") each bay is a solid light ceiling panel now (was a
			-- see-through skylight showing the sky); a soft light under it keeps the hall bright (City.hallLights, x2_look)
			r:box('RoofPanel', V(a0, H + 0.4, b0), V(a1, H + 0.7, b1), K.ceilingPanel, M.SmoothPlastic)
			for _, e in { { a0, b0, a1, b0 + 1 }, { a0, b1 - 1, a1, b1 }, { a0, b0 + 1, a0 + 1, b1 - 1 }, { a1 - 1, b0 + 1, a1, b1 - 1 } } do
				r:box('RoofSkylightFrame', V(e[1], H - 0.6, e[2]), V(e[3], H + 1, e[4]), K.ceilingPanel, M.SmoothPlastic)
			end
		end
	end
	local ty = H - 10
	for _, x in Hl.Cols do
		for _, o in { 1, 3 } do Lobby.truss(r, 'RoofTruss', V(x, ty + o, z0), V(x, ty + o, z1), K.trussDark) end
		for _, z in { z0, z1 } do
			local s = z == z0 and 1 or -1
			local a, b = z, z + s * 1.2
			r:box('RoofMount', V(x - 3.5, ty - 1.5, math.min(a, b)), V(x + 3.5, ty + 5.5, math.max(a, b)), K.pillarBase, M.SmoothPlastic)
		end
	end
	for _, z in Hl.Rows do
		for _, o in { 5, 7 } do Lobby.truss(r, 'RoofTruss', V(x0, ty + o, z), V(x1, ty + o, z), K.trussDark) end
	end
	for _, z in Hl.Rows do
		for _, x in Hl.Cols do
			local y = ty - 6
			studs(r:box('RoofLampBar', V(x - 10, y, z - 1.6), V(x + 10, y + 1, z + 1.6), K.barHousing, M.Plastic), true)
			decor(r:box('RoofLampRim', V(x - 10.3, y - 0.3, z - 1.9), V(x + 10.3, y, z + 1.9), K.trim, M.SmoothPlastic))
			local tube = decor(r:box('RoofLampTube', V(x - 9.7, y - 0.45, z - 1.3), V(x + 9.7, y - 0.3, z + 1.3), K.neon, M.Neon))
			light(tube, C(232, 240, 255), 0.6, 26)
			for _, dx in { -8.5, 8.5 } do decor(r:box('RoofLampWire', V(x + dx - 0.08, y + 1, z - 0.08), V(x + dx + 0.08, ty + 4, z + 0.08), C(96, 106, 130), M.SmoothPlastic)) end
		end
	end
	for _, p in r.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = false end
	end
	return r
end

-- The floor's cyan lines: one round each zone's platform, 1 stud out, open where a walk runs onto it; and two tiled
-- panels either side of the spine before the door (the Oct 10 hall's panel: a darker studded slab, a fine tile grid,
-- the inset cyan line).
function City.zoneLines(L)
	local K = City.HallColors
	local f = L:group('ZoneLines')
	local Pz, Hd = Lobby.Plaza, Lobby.HeadDeck
	local gx0, gx1, gz0, gz1 = Lobby.gunDeckRect()
	local zones = {
		{ Pz.x0, Pz.x1, Pz.z0, Pz.z1 },
		{ Hd.x0, Pz.x0, Hd.z0, Hd.z1 },
		{ gx0 - 1.2, gx1, gz0, gz1 },
		{ -24.1, 24.1, 79.9, 94.8 }, -- (the box dais's footprint)
	}
	-- where a line must not run: inside a zone, across a walk's mouth (the walks themselves)
	local cuts = {}
	for _, z in zones do table.insert(cuts, { z[1] - 0.9, z[2] + 0.9, z[3] - 0.9, z[4] + 0.9 }) end
	for _, p in Lobby.paths() do table.insert(cuts, { p[1], p[2], p[3], p[4] }) end
	local o, w, y = 1.0, 0.5, 0.06
	local function segment(isX, fixed, u0, u1, self)
		local spans = { { u0, u1 } }
		for k, c in cuts do
			if k ~= self then
				local inF
				if isX then inF = fixed > c[3] and fixed < c[4] else inF = fixed > c[1] and fixed < c[2] end
				if inF then
					local ca, cb = isX and c[1] or c[3], isX and c[2] or c[4]
					local nxt = {}
					for _, s in spans do
						if cb <= s[1] or ca >= s[2] then table.insert(nxt, s)
						else
							if ca > s[1] then table.insert(nxt, { s[1], ca }) end
							if cb < s[2] then table.insert(nxt, { cb, s[2] }) end
						end
					end
					spans = nxt
				end
			end
		end
		for _, s in spans do
			if s[2] - s[1] > 0.6 then
				local a, b
				if isX then a, b = V(s[1], 0, fixed - w / 2), V(s[2], y, fixed + w / 2) else a, b = V(fixed - w / 2, 0, s[1]), V(fixed + w / 2, y, s[2]) end
				decor(f:box('ZoneNeon', a, b, K.cyan, M.Neon)).CastShadow = false
			end
		end
	end
	for k, z in zones do
		local a0, a1, b0, b1 = z[1] - o, z[2] + o, z[3] - o, z[4] + o
		segment(true, b0, a0, a1, k)
		segment(true, b1, a0, a1, k)
		segment(false, a0, b0, b1, k)
		segment(false, a1, b0, b1, k)
	end
	-- the two panels before the door, between the spine and the platforms' north ends
	local sp = Lobby.SpineHalf or 5
	for _, r in { { Pz.x1 + 2, -sp - 1.5, 21, Lobby.CrossZ - sp - 2 }, { sp + 1.5, gx0 - 3.2, 21, Lobby.CrossZ - sp - 2 } } do
		local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
		if x1 - x0 > 4 and z1 - z0 > 4 then
			local panel = studs(f:box('PanelTile', V(x0, 0, z0), V(x1, 0.06, z1), K.panel, M.Plastic))
			panel.CastShadow = false
			for _, vertical in { true, false } do
				Lobby.stripes(panel, Enum.NormalId.Top, x1 - x0, z1 - z0, 2.5, 0.16, vertical, 0.6, K.band).Name = 'TileGrid'
			end
			local ins, cw = 0.7, 0.5
			local function n(a, b) decor(f:box('PanelNeon', a, b, K.cyan, M.Neon)).CastShadow = false end
			n(V(x0 + ins, 0.06, z0 + ins), V(x1 - ins, 0.12, z0 + ins + cw))
			n(V(x0 + ins, 0.06, z1 - ins - cw), V(x1 - ins, 0.12, z1 - ins))
			n(V(x0 + ins, 0.06, z0 + ins + cw), V(x0 + ins + cw, 0.12, z1 - ins - cw))
			n(V(x1 - ins - cw, 0.06, z0 + ins + cw), V(x1 - ins, 0.12, z1 - ins - cw))
		end
	end
	return f
end
local floorPlanBase = Lobby.floorPlan
function Lobby.floorPlan(L)
	local f = floorPlanBase(L)
	City.zoneLines(L)
	return f
end

Lobby.outdoors = function() end -- (no cliffs in the city)
-- The hall's props, along its walls only (the calm floor stays clear): benches and bins in the back wall's corner bays,
-- potted bushes in the side bays.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Wh = Lobby.WH
	for _, sx in { -1, 1 } do
		add('Scn_Bench', sx * 70, Wh.z1 - 2.4, 0) add('Scn_TrashCan', sx * 62, Wh.z1 - 2.2, 0)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 17, 0)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 67, 0)
	end
	add('Scn_Bush_1', Wh.x1 - 3, 42, 0)
	return list
end)()
