---------------------------------------------------------------------------------------------- the downtown plaza (World 2)
-- World 2's lobby (runs after e4_warehouse, so it replaces the warehouse's shell): the same plan as World 1's (e3_plaza:
-- spawn on the spine facing the Stage 1 gate north, the training block west, the gun stand east, the box dais south, the
-- portal SW, the boards SE, the special-sale spots and the chests before the gate), out in the open in a downtown plaza:
--   Floor    one calm field of warm sand pavers (16 x 16, two close tones, faint studs), the zones on World 1's raised
--            light grey platforms on it, the walks over it
--   Edge     a low terracotta planter wall with a trimmed hedge on top all round (the keep-in walls are f_areas' invisible
--            ones on Lobby.Bounds), open to the north on the gate's forecourt
--   Outside  a ring street (light stone sidewalks, asphalt with white dashes, taxis and cars) and "pre-downtown" round it
--            (Oct 27 round 2): 2-5 storey blocks in warm paint and brick, shops with awnings and signs, a diner, a
--            parking lot; two far glass towers as landmarks. Open sky over the hedge.
--   Portal   the way back: a brick arch onto the hood (the travel itself is the services'), at the end of its own walk west
--            off the south walk; the boards on a yard at the end of the walk east (see Lobby.Plan below)
-- The builders below (City.block, City.diner, City.parking, City.tower, City.taxi, City.bus, City.foodTruck,
-- City.busStop, City.planter, City.lamp) are the avenue's too (city/f5_avenue.lua).

---------------------------------------------------------------------------------------------- city kit
-- A face of an axis-aligned block a0..a1 (x) by b0..b1 (z), as a mapper: box(name, u0, u1, y0, y1, d0, d1, colour, mat)
-- with u along the face (x on N/S, z on E/W) and d outward from it. f: 'N' (-Z), 'S' (+Z), 'W' (-X), 'E' (+X).
function City.face(c, f, a0, a1, b0, b1)
	return function(name, u0, u1, y0, y1, d0, d1, col, mat)
		local A, B
		if f == 'S' then A, B = V(u0, y0, b1 + d0), V(u1, y1, b1 + d1)
		elseif f == 'N' then A, B = V(u0, y0, b0 - d0), V(u1, y1, b0 - d1)
		elseif f == 'E' then A, B = V(a1 + d0, y0, u0), V(a1 + d1, y1, u1)
		else A, B = V(a0 - d0, y0, u0), V(a0 - d1, y1, u1) end
		return c:box(name, A, B, col, mat or M.SmoothPlastic)
	end, (f == 'N' or f == 'S') and a0 or b0, (f == 'N' or f == 'S') and a1 or b1
end
-- The window grid on one face of a glass block: white mullions every `pitch` studs (5 unless set; and at both corners) and a slab edge
-- every 5 studs (one storey), standing a little proud of the glass. Decor, no shadows: a flat clean grid like the
-- reference's buildings.
function City.grid(c, f, a0, a1, b0, b1, ya, yb, pitch)
	local box, u0, u1 = City.face(c, f, a0, a1, b0, b1)
	local function bar(name, ua, ub, y0, y1, d)
		local p = decor(box(name, ua, ub, y0, y1, 0, d, City.mullion))
		p.CastShadow = false
		return p
	end
	bar('Mullion', u0, u0 + 0.5, ya, yb, 0.3)
	bar('Mullion', u1 - 0.5, u1, ya, yb, 0.3)
	local n = math.max(1, math.floor((u1 - u0) / pitch + 0.5))
	local step = (u1 - u0) / n
	for k = 1, n - 1 do
		local u = u0 + k * step
		bar('Mullion', u - 0.22, u + 0.22, ya, yb, 0.25)
	end
	for y = ya + 5, yb - 1, 5 do bar('FloorSlab', u0, u1, y - 0.25, y + 0.25, 0.35) end
end
-- A glass tower over block x0..x1, z0..z1 (this frame), h high: a warm studded stone base (baseH, with a pale cornice),
-- the glass body inset 0.8 with its window grid on `faces`, a steel parapet, a plant room on the roof; a setback (studs)
-- steps the top third in. door: the face with the lobby's glass doors and canopy. tone picks the glass and the stone.
function City.tower(c, x0, x1, z0, z1, h, o)
	o = o or {}
	local t, model = c:group(o.name or 'Tower')
	local k = o.tone or 1
	local gl, base = City.glass[(k - 1) % #City.glass + 1], City.base[(k - 1) % #City.base + 1]
	local bh = o.baseH or 8
	local faces = o.faces or { 'N', 'S', 'E', 'W' }
	sbox(t, 'TowerBase', V(x0, -1, z0), V(x1, bh, z1), base)
	decor(sbox(t, 'TowerCornice', V(x0 - 0.4, bh, z0 - 0.4), V(x1 + 0.4, bh + 0.8, z1 + 0.4), base:Lerp(P.white, 0.45))).CastShadow = false
	local function body(a0, a1, b0, b1, ya, yb)
		t:box('TowerGlass', V(a0, ya, b0), V(a1, yb, b1), gl, M.SmoothPlastic)
		for _, f in faces do City.grid(t, f, a0, a1, b0, b1, ya, yb, o.pitch or 5) end
		decor(t:box('TowerParapet', V(a0 - 0.3, yb, b0 - 0.3), V(a1 + 0.3, yb + 1.2, b1 + 0.3), City.roof, M.SmoothPlastic))
	end
	local i, y0 = 0.8, bh + 0.8
	local a0, a1, b0, b1 = x0 + i, x1 - i, z0 + i, z1 - i
	if o.setback and h - y0 > 30 then
		local ys = math.floor((y0 + (h - y0) * 0.64) / 5) * 5 + 0.8
		body(a0, a1, b0, b1, y0, ys)
		local s = o.setback
		a0, a1, b0, b1 = a0 + s, a1 - s, b0 + s, b1 - s
		body(a0, a1, b0, b1, ys + 1.2, h)
	else
		body(a0, a1, b0, b1, y0, h)
	end
	-- the roof: a plant room and, on the tall ones, a mast with a red tip
	local cx, cz = (a0 + a1) / 2, (b0 + b1) / 2
	local rw, rd = math.min(7, (a1 - a0) / 3), math.min(6, (b1 - b0) / 3)
	decor(t:box('RoofPlant', V(cx - rw, h + 1.2, cz - rd), V(cx + rw, h + 5, cz + rd), City.roofDark, M.SmoothPlastic))
	if h >= 90 then
		decor(t:box('RoofMast', V(cx - 0.4, h + 5, cz - 0.4), V(cx + 0.4, h + 16, cz + 0.4), City.steel, M.SmoothPlastic))
		decor(t:box('RoofMastTip', V(cx - 0.6, h + 16, cz - 0.6), V(cx + 0.6, h + 17, cz + 0.6), C(240, 60, 50), M.SmoothPlastic))
	end
	if o.door then City.entrance(t, o.door, x0, x1, z0, z1, bh, o.doorAt) end
	if o.noShadow then
		for _, p in model:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = false end end
	end
	return t, model
end
-- The lobby doors on face f of a tower's base: a dark glass front (white frames), a steel canopy over it, two planters.
function City.entrance(c, f, x0, x1, z0, z1, bh, at)
	local box, u0, u1 = City.face(c, f, x0, x1, z0, z1)
	local m = at or (u0 + u1) / 2
	local w = math.min(6, (u1 - u0) / 2 - 2)
	box('LobbyGlass', m - w, m + w, 0, bh - 1.6, -0.1, 0.12, City.doorGlass)
	for _, u in { m - w, m - w / 3, m + w / 3, m + w } do decor(box('LobbyFrame', u - 0.25, u + 0.25, 0, bh - 1.6, 0, 0.3, City.mullion)).CastShadow = false end
	decor(box('LobbyFrame', m - w, m + w, bh - 1.9, bh - 1.6, 0, 0.3, City.mullion)).CastShadow = false
	local can = box('Canopy', m - w - 1.5, m + w + 1.5, bh - 1.6, bh - 0.9, 0, 3.2, City.steel)
	decor(can)
	decor(box('CanopyEdge', m - w - 1.5, m + w + 1.5, bh - 1.75, bh - 0.75, 3.0, 3.4, City.yellow))
end
-- A raised stone planter with a trimmed tree (pos: its centre on the ground), or a hedge in it when w > 7.
function City.planter(c, pos, seed, w, d)
	w, d = w or 5, d or 5
	local g = c:at(CFrame.new(pos)):group('Planter')
	sbox(g, 'PlanterBox', V(-w / 2, 0, -d / 2), V(w / 2, 1.6, d / 2), City.clay)
	decor(sbox(g, 'PlanterCap', V(-w / 2 - 0.2, 1.6, -d / 2 - 0.2), V(w / 2 + 0.2, 1.9, d / 2 + 0.2), City.clayCap)).CastShadow = false
	if w > 7 or d > 7 then
		sbox(g, 'Hedge', V(-w / 2 + 0.5, 1.9, -d / 2 + 0.5), V(w / 2 - 0.5, 3.4, d / 2 - 0.5), City.hedge)
		decor(sbox(g, 'HedgeTop', V(-w / 2 + 0.9, 3.4, -d / 2 + 0.9), V(w / 2 - 0.9, 3.9, d / 2 - 0.9), City.hedgeTop))
	else
		tree(g, V(0, 1.9, 0), seed, 0.62, nil, true)
	end
	return g
end
-- A tall modern street lamp at pos, its arm reaching `dir` (+1 / -1 in x) over the road: a slim steel pole, a long arm,
-- a white LED head (a soft glow, no light pool: the look keeps lamps faint).
function City.lamp(c, pos, dir)
	local g = c:at(CFrame.new(pos)):group('CityLamp')
	sbox(g, 'LampFoot', V(-0.8, 0, -0.8), V(0.8, 0.8, 0.8), City.steelDark)
	g:box('LampPole', V(-0.3, 0.8, -0.3), V(0.3, 13, 0.3), City.steel, M.SmoothPlastic)
	g:box('LampArm', V(math.min(0, dir * 5), 12.6, -0.25), V(math.max(0, dir * 5), 13.1, 0.25), City.steel, M.SmoothPlastic)
	g:box('LampHead', V(dir * 3.4, 12.2, -0.6), V(dir * 5.6, 12.7, 0.6), City.steelDark, M.SmoothPlastic)
	decor(g:box('LampLED', V(dir * 3.6, 12.05, -0.45), V(dir * 5.4, 12.2, 0.45), C(255, 250, 230), M.Neon)).CastShadow = false
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'LampFoot' and p.Name ~= 'LampPole' then decor(p) end end
	return g
end
-- A yellow taxi (the kit's car, cf: its centre on the ground, front -Z) with a lit TAXI roof sign and a checker band.
function City.taxi(c, cf)
	local k = car(c, cf, City.taxiYellow)
	local sign = k:box('TaxiSign', V(-1.1, 4.6, -0.2), V(1.1, 5.5, 0.9), P.white, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(sign, face, 20), 'Taxi', 'TAXI', C(30, 30, 34), FONT.title, 0.05, 0.9) end
	for _, sx in { -1, 1 } do
		for z = -4.8, 4.4, 1.2 do
			decor(k:box('TaxiCheck', V(sx * 2.3, 2.2, z), V(sx * 2.36, 2.6, z + 0.6), C(30, 30, 34), M.SmoothPlastic)).CastShadow = false
		end
	end
	return k
end
-- A city bus (cf: its centre on the ground, front -Z, 24 long): a white body with a coloured belt, a band of dark
-- windows, the destination board in front.
function City.bus(c, cf, color)
	local b = c:at(cf):group('Bus')
	for _, sx in { -2.4, 2.4 } do
		for _, z in { -7.5, 7.5 } do b:part('Wheel', V(0.9, 2.4, 2.4), CFrame.new(sx, 1.2, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
	b:box('BusBody', V(-2.6, 1, -12), V(2.6, 9, 12), P.white, M.SmoothPlastic)
	b:box('BusBelt', V(-2.65, 1.6, -12.05), V(2.65, 3.6, 12.05), color, M.SmoothPlastic)
	decor(b:box('BusWindows', V(-2.7, 4.6, -11), V(2.7, 7.8, 11), C(52, 76, 112), M.SmoothPlastic))
	decor(b:box('BusWindscreen', V(-2.3, 3.8, -12.1), V(2.3, 7.8, -12.05), C(52, 76, 112), M.SmoothPlastic))
	b:box('BusRoof', V(-2.4, 9, -10), V(2.4, 9.6, 10), C(222, 226, 236), M.SmoothPlastic)
	local board = b:box('BusBoard', V(-1.9, 8.0, -12.2), V(1.9, 8.8, -12.05), C(30, 32, 40), M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Front, 30), 'Route', '1 DOWNTOWN', C(255, 190, 40), FONT.title, 0.08, 0.84)
	for _, x in { -1.8, 1.0 } do decor(b:box('Headlight', V(x, 2.2, -12.15), V(x + 0.8, 2.8, -12.05), C(255, 244, 200), M.Neon)) end
	return b
end
-- A food truck (cf: its centre on the ground, front -Z, serving hatch on its +X side): a coloured box van with a cab, a
-- striped awning over the open hatch, a counter, a roof sign with its food.
function City.foodTruck(c, cf, color, word)
	local t = c:at(cf):group('FoodTruck')
	for _, sx in { -2.4, 2.4 } do
		for _, z in { -6.2, 4.4 } do t:part('Wheel', V(0.9, 2.2, 2.2), CFrame.new(sx, 1.1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
	t:box('TruckBody', V(-2.7, 1, -4.5), V(2.7, 8, 7), color, M.SmoothPlastic)
	t:box('TruckCab', V(-2.6, 1, -8.6), V(2.6, 5.6, -4.5), color:Lerp(P.white, 0.25), M.SmoothPlastic)
	decor(t:box('CabGlass', V(-2.3, 3.6, -8.7), V(2.3, 5.3, -8.55), C(52, 76, 112), M.SmoothPlastic))
	t:box('Hatch', V(2.6, 3.4, -2.6), V(2.75, 6.6, 5.4), C(54, 46, 50), M.SmoothPlastic)
	t:box('Counter', V(2.7, 3.2, -2.8), V(3.6, 3.5, 5.6), P.white, M.SmoothPlastic)
	for k = 0, 3 do
		decor(t:box('Awning', V(2.7, 6.8, -2.8 + k * 2.1), V(4.6, 7.2, -0.7 + k * 2.1), k % 2 == 0 and P.white or C(240, 64, 60), M.SmoothPlastic))
	end
	local sign = t:box('TruckSign', V(-0.2, 8, -4.2), V(0.2, 10.2, 6.6), P.white, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		line(surface(sign, face, 16), 'Food', word, color:Lerp(P.black, 0.25), FONT.title, 0.08, 0.84, P.white, 2)
	end
	return t
end
-- A bus stop shelter (cf: the middle of its back on the ground, open toward -Z): steel posts, a pale glass back, a roof,
-- a bench, the BUS sign on a pole.
function City.busStop(c, cf)
	local s = c:at(cf):group('BusStop')
	for _, x in { -4.6, 4.6 } do s:box('ShelterPost', V(x - 0.25, 0, -2.6), V(x + 0.25, 8, 0.3), City.steelDark, M.SmoothPlastic) end
	local glass = s:box('ShelterGlass', V(-4.4, 0.6, -0.1), V(4.4, 7.6, 0.1), C(200, 230, 250), M.SmoothPlastic)
	glass.Transparency = 0.45
	s:box('ShelterRoof', V(-5.2, 8, -3.2), V(5.2, 8.6, 0.6), City.steel, M.SmoothPlastic)
	decor(s:box('ShelterRoofEdge', V(-5.2, 8.6, -3.2), V(5.2, 8.9, -2.8), City.yellow, M.SmoothPlastic))
	s:box('ShelterBench', V(-3.6, 1.6, -1.4), V(3.6, 2.0, -0.2), C(196, 132, 76), M.SmoothPlastic)
	s:box('ShelterPole', V(5.6, 0, -2.9), V(6.0, 10.5, -2.5), City.steel, M.SmoothPlastic)
	local plate = s:box('BusSign', V(5.0, 9, -3.0), V(6.6, 10.8, -2.4), C(40, 120, 220), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 30), 'Bus', 'BUS', P.white, FONT.title, 0.1, 0.8)
	return s
end

---------------------------------------------------------------------------------------------- pre-downtown blocks
-- (Oct 27 round 2, the owner: "make the second world not such high buildings ... make like pre downtown") The city's
-- buildings are 2-5 storey mid-rise blocks in warm saturated paint and brick, busy at street level: shops with striped
-- awnings and signs, apartments with rows of windows, small offices with ribbon windows, a corner diner, a parking lot.
-- Glass towers only as two far landmarks. A storey is 5 studs; a shop's ground floor 8 (glass, awning, sign).
City.Paint = { C(232, 112, 84), C(244, 186, 72), C(84, 176, 170), C(120, 170, 232), C(236, 132, 170), C(132, 200, 120), C(246, 224, 182), C(200, 104, 74) }
City.Awnings = { C(232, 64, 60), C(48, 140, 220), C(40, 170, 110), C(250, 180, 40), C(150, 90, 210) }
City.Words = { 'BAKERY', 'PIZZA', 'BOOKS', 'CAFE', 'MARKET', 'TOYS', 'SHOES', 'DONUTS', 'GAMES', 'FLOWERS', 'MUSIC', 'SPORTS' }
City.WindowGlass, City.ShopGlass = C(150, 206, 246), C(56, 84, 124)
-- One block over x0..x1, z0..z1 (this frame). o.kind: 'shop' (shopfronts under an awning and a sign, flats over them),
-- 'flats' (a plain ground floor with a door, windows above), 'office' (ribbon windows); o.floors: storeys over the ground
-- floor; o.tone picks the paint, the awning and the sign's word; o.faces: the faces with windows (the ones you see).
function City.block(c, x0, x1, z0, z1, o)
	local t, model = c:group(o.name or 'Block')
	local k = o.tone or 1
	local col = o.color or City.Paint[(k - 1) % #City.Paint + 1]
	local trim = o.trim or col:Lerp(P.white, 0.6)
	local kind = o.kind or 'flats'
	local g = kind == 'shop' and 8 or 6
	local n = o.floors or 2
	local top = g + n * 5
	sbox(t, 'BlockBody', V(x0, -1, z0), V(x1, top, z1), col)
	local function d(p) decor(p).CastShadow = false return p end
	d(sbox(t, 'BlockPlinth', V(x0 - 0.2, -1, z0 - 0.2), V(x1 + 0.2, 0.9, z1 + 0.2), col:Lerp(P.black, 0.22)))
	d(sbox(t, 'BlockBand', V(x0 - 0.25, g - 0.5, z0 - 0.25), V(x1 + 0.25, g, z1 + 0.25), trim))
	d(sbox(t, 'BlockCornice', V(x0 - 0.5, top, z0 - 0.5), V(x1 + 0.5, top + 1, z1 + 0.5), trim))
	for _, f in o.faces or { 'S' } do
		local box, u0, u1 = City.face(t, f, x0, x1, z0, z1)
		local bays = math.max(1, math.floor((u1 - u0) / 5.5))
		local bw = (u1 - u0) / bays
		-- the storeys over the ground floor
		for fl = 0, n - 1 do
			local y = g + fl * 5 + 1.1
			if kind == 'office' then
				d(box('Ribbon', u0 + 1, u1 - 1, y, y + 3, 0, 0.15, City.WindowGlass))
				for b = 1, bays - 1 do d(box('RibbonMullion', u0 + b * bw - 0.2, u0 + b * bw + 0.2, y, y + 3, 0, 0.25, trim)) end
			else
				for b = 0, bays - 1 do
					local m = u0 + (b + 0.5) * bw
					d(box('Window', m - 1.3, m + 1.3, y, y + 2.9, 0, 0.15, City.WindowGlass))
					d(box('Sill', m - 1.6, m + 1.6, y - 0.35, y, 0, 0.4, trim))
				end
			end
		end
		-- the ground floor
		if kind == 'shop' then
			local awn = City.Awnings[(k - 1) % #City.Awnings + 1]
			d(box('ShopGlass', u0 + 1, u1 - 1, 0.9, 5.2, 0, 0.12, City.ShopGlass))
			for b = 0, bays do d(box('ShopFrame', u0 + 1 + b * (u1 - u0 - 2) / bays - 0.2, u0 + 1 + b * (u1 - u0 - 2) / bays + 0.2, 0.9, 5.2, 0, 0.25, P.white)) end
			for b = 0, bays * 2 - 1 do
				local a0 = u0 + 1 + b * (u1 - u0 - 2) / (bays * 2)
				d(box('Awning', a0, a0 + (u1 - u0 - 2) / (bays * 2), 5.2, 5.8, 0, 2.6, b % 2 == 0 and awn or P.white))
			end
			local w = math.min(u1 - u0 - 4, 14)
			local m = (u0 + u1) / 2
			local sign = box('ShopSign', m - w / 2, m + w / 2, 5.95, 7.45, 0, 0.3, P.white)
			decor(sign)
			local face = ({ S = Enum.NormalId.Back, N = Enum.NormalId.Front, E = Enum.NormalId.Right, W = Enum.NormalId.Left })[f]
			local word = o.word or City.Words[(k - 1) % #City.Words + 1]
			line(surface(sign, face, 12), 'Shop', word, awn:Lerp(P.black, 0.15), FONT.title, 0.06, 0.88, P.white, 2)
		elseif kind == 'office' then
			d(box('LobbyGlass', u0 + 1, u1 - 1, 0.9, g - 1.2, 0, 0.12, City.ShopGlass))
		else
			local m = (u0 + u1) / 2
			d(box('Door', m - 1.4, m + 1.4, 0.9, 5, 0, 0.15, col:Lerp(P.black, 0.45)))
			d(box('DoorHood', m - 2, m + 2, 5, 5.4, 0, 1.2, trim))
			for b = 0, bays - 1 do
				local wm = u0 + (b + 0.5) * bw
				if math.abs(wm - m) > 3 then d(box('Window', wm - 1.3, wm + 1.3, 2, 4.6, 0, 0.15, City.WindowGlass)) end
			end
		end
	end
	-- on the roof: a plant box, and a water tank on every other block
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	d(t:box('RoofBox', V(cx - 3, top + 1, cz - 2.5), V(cx + 3, top + 3.2, cz + 2.5), C(150, 156, 172), M.SmoothPlastic))
	if k % 2 == 0 then
		d(t:box('TankLegs', V(cx + 4, top + 1, cz - 1), V(cx + 6, top + 3, cz + 1), C(110, 80, 60), M.SmoothPlastic))
		d(t:box('Tank', V(cx + 3.6, top + 3, cz - 1.4), V(cx + 6.4, top + 6, cz + 1.4), C(170, 112, 76), M.SmoothPlastic))
	end
	if o.noShadow then for _, p in model:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = false end end end
	return t, model
end
-- A corner diner (cf: the middle of its front on the ground, front -Z, 26 wide, 12 deep): one storey in cream with a red
-- band, a long window, a chrome roof edge, DINER on posts over the roof.
function City.diner(c, cf)
	local t = c:at(cf):group('Diner')
	sbox(t, 'DinerBody', V(-13, -1, 0), V(13, 7, 12), C(250, 236, 206))
	decor(sbox(t, 'DinerBand', V(-13.2, 1, -0.2), V(13.2, 2.2, 12.2), C(226, 56, 56))).CastShadow = false
	decor(t:box('DinerWindow', V(-11, 2.6, -0.15), V(7, 5.8, 0), C(56, 84, 124), M.SmoothPlastic)).CastShadow = false
	decor(t:box('DinerDoor', V(8.5, 0.9, -0.15), V(11.5, 5.8, 0), C(226, 56, 56), M.SmoothPlastic)).CastShadow = false
	decor(t:box('DinerRoofEdge', V(-13.5, 7, -0.5), V(13.5, 7.8, 12.5), C(206, 214, 228), M.SmoothPlastic)).CastShadow = false
	for _, x in { -6, 6 } do decor(t:box('SignPost', V(x - 0.3, 7.8, 4), V(x + 0.3, 10, 4.6), C(206, 214, 228), M.SmoothPlastic)) end
	local sign = t:box('DinerSign', V(-9, 10, 3.9), V(9, 14, 4.5), C(226, 56, 56), M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Front, 10), 'Diner', 'DINER', P.white, FONT.title, 0.08, 0.84, C(120, 20, 20), 3)
	decor(sign)
	return t
end
-- A parking lot over x0..x1, z0..z1, its top at y: asphalt with white bays across it, a pale kerb on three sides (open to
-- the street on `open`'s side), a few cars, the P sign.
function City.parking(c, x0, x1, z0, z1, seed, y, openX)
	local t = c:group('ParkingLot')
	sbox(t, 'Lot', V(x0, -1, z0), V(x1, y, z1), City.road:Lerp(P.white, 0.1))
	local kx = openX == x0 and x1 - 0.8 or x0
	for _, e in { { V(x0, -1, z0), V(x1, y + 0.4, z0 + 0.8) }, { V(x0, -1, z1 - 0.8), V(x1, y + 0.4, z1) }, { V(kx, -1, z0), V(kx + 0.8, y + 0.4, z1) } } do
		decor(sbox(t, 'LotKerb', e[1], e[2], City.kerb)).CastShadow = false
	end
	local r = Random.new(seed)
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), City.taxiYellow, C(120, 210, 90) }
	for z = z0 + 2, z1 - 6, 6 do
		decor(sbox(t, 'BayLine', V(x0 + 2, y, z), V(x1 - 2, y + 0.1, z + 0.3), City.line)).CastShadow = false
		if r:NextNumber() < 0.65 then
			local side = r:NextNumber() < 0.5 and 0.25 or 0.75
			car(t, CFrame.new(x0 + (x1 - x0) * side, y, z + 3.15) * CFrame.Angles(0, math.pi / 2, 0), cars[r:NextInteger(1, #cars)])
		end
	end
	local px = openX == x0 and x0 + 1.4 or x1 - 1.4
	t:box('ParkPole', V(px - 0.2, y, z0 + 1.4), V(px + 0.2, y + 9, z0 + 1.8), City.steel, M.SmoothPlastic)
	local plate = t:box('ParkSign', V(px - 1.4, y + 9, z0 + 1.5), V(px + 1.4, y + 11.8, z0 + 1.7), C(40, 110, 220), M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(plate, face, 20), 'P', 'P', P.white, FONT.title, 0.05, 0.9) end
	return t
end

---------------------------------------------------------------------------------------------- the plaza
-- Downtown's ring street round the plaza (map frame): the plaza's sidewalk x 88.5..96 (south: from the hedge's outer face
-- 5.5 deep), the road 96..110 (south: 12 wide), the far sidewalk 6 wide, the blocks past it on a paved base (over
-- f_areas' lots, low wall and ring road). The side streets run north past the avenue's blocks to z -220. Its levels: the
-- road's top 0.5, the sidewalks' 0.95 (over f_areas' lots behind the avenue, whose grass tops 0.4); the plaza's floor
-- is 0, behind its hedge.
City.Ring = { walk0 = 88.5, road0 = 96, road1 = 110, walk1 = 116, north = -220, road = 0.5, walk = 0.95 }
City.Blocks = {
	-- { z0, z1, kind, floors, tone } along the far side of the side streets (x 116..150; the west takes other tones, and
	-- the diner where the east has the parking lot)
	east = { { -170, -136, 'flats', 3, 1 }, { -130, -100, 'shop', 2, 2 }, { -94, -62, 'office', 4, 3 }, { -56, -30, 'flats', 3, 4 },
		{ -24, 8, 'lot', 0, 5 }, { 14, 42, 'shop', 3, 6 }, { 48, 78, 'flats', 4, 7 }, { 84, 114, 'shop', 2, 8 }, { 120, 156, 'flats', 3, 1 } },
	-- { x0, x1, kind, floors, tone } along the south street's far side (z from the far sidewalk, 30 deep)
	south = { { -114, -88, 'flats', 3, 3 }, { -82, -54, 'shop', 2, 4 }, { -48, -20, 'office', 4, 5 }, { -14, 14, 'shop', 3, 6 },
		{ 20, 48, 'flats', 2, 7 }, { 54, 82, 'shop', 3, 8 } },
	-- { z0, z1, kind, floors, tone } behind the avenue's blocks, fronting the side streets (|x| 64..88.5)
	north = { { -56, 0, 'shop', 2, 2 }, { -116, -62, 'flats', 3, 5 }, { -176, -122, 'office', 4, 1 } },
}
function City.skyline(L)
	local g = L:group('Surroundings')
	local R, Wh = City.Ring, Lobby.WH
	local RY, WY = R.road, R.walk
	local zs = Wh.z1 + 2.5 -- the hedge's outer face, south
	local zr0, zr1 = zs + 5.5, zs + 17.5 -- the south road
	local zf = zr1 + 6 -- the far sidewalk's back
	local function walk(a, b) sbox(g, 'Sidewalk', a, b, City.walk) end
	local function road(a, b) sbox(g, 'Road', a, b, City.road) end
	local function kerb(a, b) decor(sbox(g, 'KerbStone', a, b, City.kerb)).CastShadow = false end
	local function paint(a, b) decor(sbox(g, 'RoadLine', a, b, City.line)).CastShadow = false end
	local base = City.walk:Lerp(City.road, 0.25)
	-- the side streets and the south street meet in an L at each corner: each sidewalk and road ends where the other's
	-- begins, a kerb along every road edge, the kerbs meeting at the corners
	for _, s in { -1, 1 } do
		local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local a, b = X(R.walk0, R.road0)
		walk(V(a, -1, R.north), V(b, WY, zr0))
		a, b = X(R.road0, R.road1)
		road(V(a, -1, R.north), V(b, RY, zr0))
		a, b = X(R.road1, R.walk1)
		walk(V(a, -1, R.north), V(b, WY, zr1))
		-- along the plaza's north edge, from the avenue's blocks to the side street's sidewalk
		a, b = X(36, R.walk0)
		walk(V(a, -1, 0), V(b, WY, Wh.z0 - 2.5))
		kerb(V(s * (R.road0 - 0.6), -0.5, R.north), V(s * (R.road0 + 0.6), WY + 0.1, zr0 - 0.6))
		kerb(V(s * (R.road1 - 0.6), -0.5, R.north), V(s * (R.road1 + 0.6), WY + 0.1, zr1 + 0.6))
		for z = R.north + 4, zr0 - 16, 12 do paint(V(s * 102.7, RY, z), V(s * 103.3, RY + 0.12, z + 5)) end
		-- a crosswalk over the side street where it meets the south one: the plaza's sidewalk to the far one
		for k = 0, 4 do paint(V(s * (R.road0 + 1.2 + k * 2.6), RY, zr0 - 7), V(s * (R.road0 + 2.6 + k * 2.6), RY + 0.12, zr0 - 1.5)) end
		-- the blocks' paved base (their alleys and forecourts), behind the far sidewalk and behind the avenue
		a, b = X(R.walk1, R.walk1 + 34)
		sbox(g, 'CityBase', V(a, -1, R.north), V(b, WY, zf + 30), base)
		a, b = X(64, R.walk0)
		sbox(g, 'CityBase', V(a, -1, R.north), V(b, WY, 0), base)
	end
	walk(V(-R.walk0, -1, zs), V(R.walk0, WY, zr0))
	road(V(-R.road1, -1, zr0), V(R.road1, RY, zr1))
	walk(V(-R.walk1, -1, zr1), V(R.walk1, WY, zf))
	sbox(g, 'CityBase', V(-R.walk1, -1, zf), V(R.walk1, WY, zf + 30), base)
	kerb(V(-(R.road0 + 0.6), -0.5, zr0 - 0.6), V(R.road0 + 0.6, WY + 0.1, zr0 + 0.6))
	kerb(V(-(R.road1 + 0.6), -0.5, zr1 - 0.6), V(R.road1 + 0.6, WY + 0.1, zr1 + 0.6))
	for x = -106, 100, 12 do paint(V(x, RY, (zr0 + zr1) / 2 - 0.3), V(x + 5, RY + 0.12, (zr0 + zr1) / 2 + 0.3)) end
	-- the blocks
	local bx0, bx1 = R.walk1, R.walk1 + 34
	for _, s in { -1, 1 } do
		local street = s > 0 and 'W' or 'E'
		for i, b in City.Blocks.east do
			local x0, x1 = math.min(s * bx0, s * bx1), math.max(s * bx0, s * bx1)
			local tone = b[5] + (s > 0 and 0 or 3)
			if b[3] == 'lot' then
				if s > 0 then City.parking(g, x0, x1, b[1], b[2], 900 + i, WY + 0.15, x0)
				else City.diner(g:at(CFrame.new(0, WY, 0)), CFrame.new(-(bx0 + 0.5), 0, (b[1] + b[2]) / 2) * CFrame.Angles(0, -math.pi / 2, 0)) end
			else
				City.block(g, x0, x1, b[1], b[2], { kind = b[3], floors = b[4], tone = tone, faces = { street }, name = 'Block' })
			end
		end
		for _, b in City.Blocks.north do
			local x0, x1 = math.min(s * 64, s * R.walk0), math.max(s * 64, s * R.walk0)
			local side = s > 0 and 'E' or 'W'
			City.block(g, x0, x1, b[1], b[2], { kind = b[3], floors = b[4], tone = b[5] + (s > 0 and 1 or 4), faces = b[2] == 0 and { side, 'S' } or { side }, name = 'Block' })
		end
	end
	for _, b in City.Blocks.south do City.block(g, b[1], b[2], zf, zf + 30, { kind = b[3], floors = b[4], tone = b[5], faces = { 'N' }, name = 'Block' }) end
	City.diner(g:at(CFrame.new(0, WY, 0)), CFrame.new(100, 0, zf + 0.5))
	-- two far glass towers: the downtown still ahead, well behind the avenue, either side of the view up it
	City.tower(g, -112, -86, -200, -176, 92, { tone = 2, faces = { 'S', 'E' }, setback = 3, noShadow = true, name = 'Landmark' })
	City.tower(g, 88, 112, -196, -172, 76, { tone = 3, faces = { 'S', 'W' }, noShadow = true, name = 'Landmark' })
	-- the street's life: taxis and cars at the kerbs, trees in planters and lamps along the plaza's sidewalks
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), C(120, 210, 90) }
	for k, z in { -40, 6, 52, 88 } do
		for _, s in { -1, 1 } do
			local cf = CFrame.new(s * 99, RY, z + (s > 0 and 14 or 0)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0)
			if (k + (s > 0 and 1 or 0)) % 2 == 0 then City.taxi(g, cf) else car(g, cf, cars[k]) end
		end
	end
	for k, x in { -70, -20, 44, 86 } do
		local cf = CFrame.new(x, RY, zr0 + 3) * CFrame.Angles(0, math.pi / 2, 0)
		if k % 2 == 1 then City.taxi(g, cf) else car(g, cf, cars[k]) end
	end
	for _, s in { -1, 1 } do
		for z = 14, 90, 19 do City.planter(g, V(s * 92.2, WY, z), 700 + z + (s > 0 and 3 or 0)) end
		for z = 23.5, 80, 19 do City.lamp(g, V(s * 94.6, WY, z), s) end
	end
	for x = -80, 80, 20 do City.planter(g, V(x, WY, zs + 2.75), 760 + x, 3.6, 3.6) end
	return g
end
-- The hall's shell, swapped for the plaza: the pavers, the threshold onto the gate's forecourt, the planter wall with its
-- hedge round the edge, and the city round it.
function Lobby.hall(L)
	local Wh = Lobby.WH
	local h = L:group('Hall')
	local f = L:group('HallFloor')
	local gx, gz = 16, 16
	local ox, oz = SPAWN.X - 8, SPAWN.Z - 8
	local i0, i1 = math.floor((Wh.x0 - ox) / gx), math.ceil((Wh.x1 - ox) / gx) - 1
	local j0, j1 = math.floor((Wh.z0 - oz) / gz), math.ceil((Wh.z1 - oz) / gz) - 1
	for i = i0, i1 do
		for j = j0, j1 do
			local xa, xb = math.max(Wh.x0, ox + i * gx), math.min(Wh.x1, ox + (i + 1) * gx)
			local za, zb = math.max(Wh.z0, oz + j * gz), math.min(Wh.z1, oz + (j + 1) * gz)
			if xb - xa > 0.01 and zb - za > 0.01 then
				studs(f:box('Concrete', V(xa, -1, za), V(xb, 0, zb), (i + j) % 2 == 0 and City.paverA or City.paverB, M.Plastic))
			end
		end
	end
	f:box('Threshold', V(-Lobby.Bounds.mouth, -1, Lobby.N - 1), V(Lobby.Bounds.mouth, 0, Wh.z0), City.paverB, M.SmoothPlastic)
	-- the edge: the planter wall (2.4 high, a pale flush cap) with its hedge, west / east / south, and the north either side
	-- of the gate's forecourt (from the forecourt's own keep-in wall, |x| = mouth). The pieces butt at the corners and
	-- each layer's ring is laid as one ring (the hedge inset 0.4 from both faces, its top 0.8), so nothing overlaps or
	-- leaves a notch.
	local e = L:group('PlazaEdge')
	local xi, xo = Wh.x1, Wh.x1 + 2.5
	local zn0, zn1, zsi, zso = Wh.z0 - 2.5, Wh.z0, Wh.z1, Wh.z1 + 2.5
	local m = Lobby.Bounds.mouth
	local function ring(name, y0, y1, col, i, isDecor)
		local runs = {
			{ -xo + i, -xi - i, zn0 + i, zso - i }, { xi + i, xo - i, zn0 + i, zso - i }, -- west, east
			{ -xi - i, xi + i, zsi + i, zso - i }, -- south, between them
			{ -xi - i, -m - (i > 0 and i or 0), zn0 + i, zn1 - i }, { m + (i > 0 and i or 0), xi + i, zn0 + i, zn1 - i }, -- north
		}
		for _, r in runs do
			local p = sbox(e, name, V(r[1], y0, r[3]), V(r[2], y1, r[4]), col)
			if isDecor then decor(p).CastShadow = false end
		end
	end
	ring('PlanterWall', -1, 2.4, City.clay, 0)
	ring('PlanterCap', 2.4, 2.7, City.clayCap, 0, true)
	ring('Hedge', 2.7, 4.2, City.hedge, 0.4)
	ring('HedgeTop', 4.2, 4.7, City.hedgeTop, 0.8, true)
	City.skyline(L)
	return h
end
Lobby.outdoors = function() end -- (no cliffs downtown)
-- The plaza's props, along its edge only (the calm field stays clear): trees in the corners, benches by the south
-- edge, lamps by the north one and down the sides.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Wh = Lobby.WH
	for _, sx in { -1, 1 } do
		add('Scn_Tree_1', sx * (Wh.x1 - 5), Wh.z0 + 5, 0) add('Scn_Tree_2', sx * (Wh.x1 - 5), Wh.z1 - 5, 0)
		add('Scn_Bench', sx * 77, Wh.z1 - 2.4, 0) add('Scn_TrashCan', sx * 72.5, Wh.z1 - 2.2, 0)
		add('Scn_StreetLamp', sx * 66, Wh.z0 + 2.2, -90)
		add('Scn_StreetLamp', sx * (Wh.x1 - 2.4), 70, sx < 0 and 0 or 180)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 30, 0)
	end
	return list
end)()

-- (Oct 27 round 2, the owner: "make the leaderboards, portal placing way better, so people can actually see and reach
-- them, not just being one another") The band between the zones' platforms and the box dais carries a walk each way off
-- the south walk (the reference's: its portal west, its boards east, each by the path): west to the portal, standing at
-- the walk's end and turned to the crossing; east to a paved yard where the three boards stand on an arc round the
-- crossing (60 studs out, 12 degrees apart, clear of the gun stand's stairs), each turned to it: seen side by side from
-- the crossing, none behind another, and each with open yard in front of it. (The portal is behind the training block
-- from the crossing; its floating words show over the bays, and the south walk sees it straight down its own walk.)
do
	local Pz = Lobby.Plaza
	local zA, zB = Pz.z1 + 1.4, Pz.z1 + 10.2
	Lobby.PortalPath = { x0 = -62, z0 = zA, z1 = zB }
	Lobby.Plan.World2 = { x = -64, z = (zA + zB) / 2 + 2, look = Lobby.Centre, scale = 0.85 }
	City.BoardYard = { x0 = 30, x1 = 70, z0 = 68, z1 = Lobby.WH.z1 - 2 }
	local boards, cz = {}, Lobby.Centre.Z
	for _, deg in { 60, 48, 36 } do
		local a = math.rad(deg)
		table.insert(boards, { math.floor(60 * math.cos(a) * 10 + 0.5) / 10, math.floor((cz + 60 * math.sin(a)) * 10 + 0.5) / 10 })
	end
	Lobby.Plan.Boards = boards
	local paths = Lobby.paths
	function Lobby.paths()
		local list, Y = paths(), City.BoardYard
		table.insert(list, { Lobby.SpineHalf, Y.x0, zA, zB, 'Boards' })
		table.insert(list, { Y.x0, Y.x1, Y.z0, Y.z1, 'BoardYard' })
		return list
	end
end

-- The way back to the hood, where World 1 has its World 2 door (Lobby.Plan.World2, turned to the crossing): a warm brick
-- arch (the hood's brick) on a stone step, a soft orange glow filling it, THE HOOD on its lintel. Front -Z of cf faces
-- the plaza; cf is the bottom centre of its back. The model is World1Portal (HoodServer/WorldPortalService reads the number) and carries TravelWorld = 1.
function Lobby.world2(e, cf)
	local p, model = e:at(cf):group('World1Portal')
	model:SetAttribute('TravelWorld', 1)
	local brick, dark, trim = C(214, 112, 78), C(176, 86, 62), C(255, 222, 170)
	sbox(p, 'PortalStep', V(-9, 0, -5), V(9, 0.6, 0.6), City.edge)
	decor(sbox(p, 'PortalStepNosing', V(-9, 0.45, -5.2), V(9, 0.7, -4.8), City.edgeCap)).CastShadow = false
	for _, sx in { -1, 1 } do
		local xa, xb = sx * 5.4, sx * 8.4
		sbox(p, 'PortalPillar', V(xa, 0.6, -3), V(xb, 15, 0), brick)
		decor(sbox(p, 'PortalPillarBase', V(xa - sx * 0.3, 0.6, -3.3), V(xb + sx * 0.3, 2.6, 0.2), dark)).CastShadow = false
		for y = 4, 14, 3.4 do decor(sbox(p, 'PortalBrickBand', V(xa - sx * 0.05, y, -3.1), V(xb + sx * 0.05, y + 0.4, -2.95), dark)).CastShadow = false end
	end
	local lintel = sbox(p, 'PortalLintel', V(-9.2, 15, -3.4), V(9.2, 18.4, 0.2), brick)
	decor(sbox(p, 'PortalLintelCap', V(-9.6, 18.4, -3.8), V(9.6, 19.1, 0.4), trim)).CastShadow = false
	local board = p:box('PortalBoard', V(-6.8, 15.4, -3.5), V(6.8, 18, -3.4), C(40, 34, 40), M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Front, 14), 'Hood', 'THE HOOD', C(255, 206, 60), FONT.title, 0.1, 0.8, C(40, 24, 0), 3)
	local field = decor(p:box('PortalField', V(-5.4, 0.6, -1.7), V(5.4, 15, -1.3), C(255, 150, 96), M.Neon))
	field.Transparency, field.CastShadow = 0.35, false
	light(field, C(255, 170, 120), 0.5, 8)
	sbox(p, 'PortalBack', V(-8.4, 0.6, 0), V(8.4, 15, 0.6), dark)
	return model
end
-- The corners as World 1's (the portal turned to the crossing, the boards), the portal's floating words saying where it
-- goes, its slot under the city's name for it too.
do
	local corners = Lobby.corners
	function Lobby.corners(L)
		corners(L)
		local g = L.parent:FindFirstChild('World2Corner')
		local label = g and g:FindFirstChild('WorldLabel', true)
		if label then
			if label:FindFirstChild('Title') then label.Title.Text = 'The Hood' end
			if label:FindFirstChild('Soon') then label.Soon.Text = 'BACK TO WORLD 1' end
		end
		if g then g.Name = 'HoodPortalCorner' end
		Lobby.Slots.World1Portal = Lobby.Slots.World2Portal
	end
end
-- This world's boxes on the dais (Config/Shoes: World 2's two Cash boxes), World 1's list when it has none yet; two
-- boxes stand either side of the dais's middle.
do
	local list, slotX = Lobby.shoeBoxList, Lobby.boxSlotX
	function Lobby.shoeBoxList()
		local cfg = Lobby.sharedModule('Config', 'Shoes')
		if cfg and type(cfg.boxesForWorld) == 'function' then
			local ok, here = pcall(cfg.boxesForWorld, V2.World or 2)
			if ok and type(here) == 'table' and #here > 0 then return here end
		end
		return list()
	end
	function Lobby.boxSlotX(boxes, i)
		if #boxes == 2 then return ({ 9, -9 })[i] end
		return slotX(boxes, i)
	end
end
