---------------------------------------------------------------------------------------------- the downtown plaza (World 2)
-- World 2's lobby (runs after e4_warehouse, so it replaces the warehouse's shell): the same plan as World 1's (e3_plaza:
-- spawn on the spine facing the Stage 1 gate north, the training block west, the gun stand east, the box dais south, the
-- portal SW, the boards SE, the special-sale spots and the chests before the gate), inside the owner's "C" hall
-- (city/e6_hall.lua: its shell, floor and props; the keep-in walls are f_areas' invisible ones on Lobby.Bounds):
--   Outside  a ring street (light stone sidewalks, asphalt with white dashes, taxis and cars) and downtown round it (Oct
--            27 round 3, the owner: "make the buildings taller"): glass and warm stone towers 55-95 high on shop podiums
--            (awnings and signs on the street), a diner; they show through the hall's door, windows and skylights.
--   Portal   the way back: a brick arch onto the hood (the travel itself is the services'), where World 1 has its World 2
--            door (SW, its own walk off the south walk); the boards in World 1's straight row SE (see below)
-- The builders below (City.highrise, City.block, City.shopfront, City.diner, City.parking, City.tower, City.taxi, City.bus,
-- City.foodTruck, City.busStop, City.planter, City.lamp) are the avenue's too (city/f5_avenue.lua).

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
---------------------------------------------------------------------------------------------- downtown highrises
-- (Oct 27 round 3, the owner: "make the buildings taller, make it the size of the first world, and then make the look in
-- general way better") Downtown's towers: a warm studded stone podium (one shop storey, 8 high, with shopfronts,
-- striped awnings and signs on its street faces), and over it either a glass body (sky-blue, teal or violet glass in a
-- white mullion grid) or a warm painted stone one (a window band each storey, piers over them), a bright crown band and
-- a plant room on the roof (a mast with a red tip from 110 up). A storey is 5 studs. Only the podium casts a shadow
-- unless o.shadow.
City.Stone = { C(240, 214, 170), C(232, 170, 124), C(246, 232, 204), C(214, 150, 120), C(236, 196, 140), C(222, 184, 160) }
City.Crown = { C(232, 64, 60), C(48, 140, 220), C(40, 170, 110), C(250, 180, 40), C(150, 90, 210), C(255, 120, 60) }
-- One window band a storey on face f of a stone body, and piers over them every ~7 studs (and at both corners).
function City.ribbons(c, f, a0, a1, b0, b1, ya, yb, trim)
	local box, u0, u1 = City.face(c, f, a0, a1, b0, b1)
	local function d(p) decor(p).CastShadow = false return p end
	for y = ya + 1.2, yb - 3.6, 5 do d(box('WindowBand', u0 + 0.8, u1 - 0.8, y, y + 2.8, 0, 0.15, City.WindowGlass)) end
	local n = math.max(1, math.floor((u1 - u0) / 7 + 0.5))
	for q = 0, n do
		local u = u0 + (u1 - u0) * q / n
		d(box('Pier', math.max(u0, u - 0.55), math.min(u1, u + 0.55), ya, yb, 0, 0.3, trim))
	end
end
-- A highrise over x0..x1, z0..z1 (this frame), h high. o: kind ('glass' | 'stone'), tone, faces (window faces), shops
-- (podium faces with shopfronts), setback (studs the top third steps in), podium (its height, 8), shadow, name, word;
-- stone, glassColor, crown (colour overrides) and neon (a glowing strip up each corner, its colour).
function City.highrise(c, x0, x1, z0, z1, h, o)
	o = o or {}
	local t, model = c:group(o.name or 'Highrise')
	local k = o.tone or 1
	local kind = o.kind or 'glass'
	local ph = o.podium or 8
	local stone = o.stone or City.Stone[(k - 1) % #City.Stone + 1]
	local gl = o.glassColor or City.glass[(k - 1) % #City.glass + 1]
	local crown = o.crown or City.Crown[(k - 1) % #City.Crown + 1]
	local trim = stone:Lerp(P.white, 0.55)
	local faces = o.faces or { 'S' }
	local podium = sbox(t, 'Podium', V(x0, -1, z0), V(x1, ph, z1), kind == 'glass' and City.base[(k - 1) % #City.base + 1] or stone:Lerp(P.black, 0.08))
	decor(sbox(t, 'PodiumCornice', V(x0 - 0.4, ph, z0 - 0.4), V(x1 + 0.4, ph + 0.8, z1 + 0.4), trim)).CastShadow = false
	for n, f in o.shops or {} do City.shopfront(t, f, x0, x1, z0, z1, k + n, n == 1 and o.word or nil) end
	local function mass(a0, a1, b0, b1, ya, yb)
		if kind == 'glass' then
			t:box('TowerGlass', V(a0, ya, b0), V(a1, yb, b1), gl, M.SmoothPlastic)
			for _, f in faces do City.grid(t, f, a0, a1, b0, b1, ya, yb, o.pitch or 5) end
		else
			t:box('TowerStone', V(a0, ya, b0), V(a1, yb, b1), stone, M.SmoothPlastic)
			for _, f in faces do City.ribbons(t, f, a0, a1, b0, b1, ya, yb, trim) end
		end
		-- the top: a bright belt round the last storey and a calm light parapet over the roof (seen from above, the
		-- roofs stay quiet)
		decor(t:box('TowerBelt', V(a0 - 0.35, yb - 1.6, b0 - 0.35), V(a1 + 0.35, yb - 0.2, b1 + 0.35), crown, M.SmoothPlastic))
		decor(t:box('TowerCrown', V(a0 - 0.3, yb, b0 - 0.3), V(a1 + 0.3, yb + 1.6, b1 + 0.3), C(214, 218, 228), M.SmoothPlastic))
		-- o.neon: a steady glowing strip up each corner (the luxury district's pink)
		if o.neon then
			for _, q in { { a0, b0 }, { a0, b1 }, { a1, b0 }, { a1, b1 } } do
				decor(t:box('TowerNeon', V(q[1] - 0.45, ya, q[2] - 0.45), V(q[1] + 0.45, yb - 1.6, q[2] + 0.45), o.neon, M.Neon)).CastShadow = false
			end
		end
	end
	local i, y0 = 1.2, ph + 0.8
	local a0, a1, b0, b1 = x0 + i, x1 - i, z0 + i, z1 - i
	if o.setback and h - y0 > 40 then
		local ys = math.floor((y0 + (h - y0) * 0.62) / 5) * 5 + 0.8
		mass(a0, a1, b0, b1, y0, ys)
		local sb = o.setback
		a0, a1, b0, b1 = a0 + sb, a1 - sb, b0 + sb, b1 - sb
		mass(a0, a1, b0, b1, ys + 1.6, h)
	else
		mass(a0, a1, b0, b1, y0, h)
	end
	local cx, cz = (a0 + a1) / 2, (b0 + b1) / 2
	local rw, rd = math.min(6, (a1 - a0) / 3), math.min(5, (b1 - b0) / 3)
	decor(t:box('RoofPlant', V(cx - rw, h + 1.6, cz - rd), V(cx + rw, h + 5.2, cz + rd), City.roofDark, M.SmoothPlastic))
	if h >= 110 then
		decor(t:box('RoofMast', V(cx - 0.4, h + 5.2, cz - 0.4), V(cx + 0.4, h + 18, cz + 0.4), City.steel, M.SmoothPlastic))
		decor(t:box('RoofMastTip', V(cx - 0.7, h + 18, cz - 0.7), V(cx + 0.7, h + 19.4, cz + 0.7), C(240, 60, 50), M.SmoothPlastic))
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p ~= podium and not o.shadow then p.CastShadow = false end
	end
	if o.noShadow then podium.CastShadow = false end
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
-- A shopfront on face f of a block x0..x1, z0..z1 (this frame): the shop glass in white frames, a striped awning at 5.2,
-- a white sign with the shop's word in the awning's colour (tone k picks both). The ground floor is 8 high.
function City.shopfront(t, f, x0, x1, z0, z1, k, word)
	local function d(p) decor(p).CastShadow = false return p end
	local box, u0, u1 = City.face(t, f, x0, x1, z0, z1)
	local bays = math.max(1, math.floor((u1 - u0) / 5.5))
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
	line(surface(sign, face, 12), 'Shop', word or City.Words[(k - 1) % #City.Words + 1], awn:Lerp(P.black, 0.15), FONT.title, 0.06, 0.88, P.white, 2)
end
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
			City.shopfront(t, f, x0, x1, z0, z1, k, o.word)
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
-- 5.5 deep), the road 96..110 (south: 12 wide), the far sidewalk 6 wide, the towers past it on a paved base (over
-- f_areas' lots). Its levels: the road's top 0.5, the sidewalks' 0.95; the plaza's floor is 0, behind its hedge. North of
-- z = 0 the side streets go on up the whole avenue with the towers along them (City.skylineFar, f5_avenue).
-- (Oct 27 round 3, the owner: "make the buildings taller") the blocks round the plaza are towers now: glass and warm stone
-- on shop podiums, 55-95 high, their shops on the street.
City.Ring = { walk0 = 88.5, road0 = 96, road1 = 110, walk1 = 116, north = 0, road = 0.5, walk = 0.95 }
City.Blocks = {
	-- { z0, z1, kind, height, tone } along the far side of the side streets (x 116..150; the west takes other tones)
	-- (Oct 27 round 5, the owner: "make way less buildings": one tower a side and two to the south, gaps between; was 14)
	east = { { 34, 62, 'glass', 85, 1 } },
	-- { x0, x1, kind, height, tone } along the south street's far side (z from the far sidewalk, 30 deep)
	south = { { -80, -52, 'stone', 70, 6 }, { 52, 80, 'glass', 90, 3 } },
}
function City.skyline(L)
	local g = L:group('Surroundings')
	local R, Wh = City.Ring, Lobby.WH
	local RY, WY = R.road, R.walk
	local zs = Wh.z1 + 2.5 -- the hall's outer face, south
	local zr0, zr1 = zs + 5.5, zs + 17.5 -- the south road
	local zf = zr1 + 6 -- the far sidewalk's back
	City.Ring.zf = zf
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
		-- along the plaza's north edge, from the avenue's towers to the side street's sidewalk
		a, b = X(36, R.walk0)
		walk(V(a, -1, 0), V(b, WY, Wh.z0 - 2.5))
		kerb(V(s * (R.road0 - 0.6), -0.5, R.north), V(s * (R.road0 + 0.6), WY + 0.1, zr0 - 0.6))
		kerb(V(s * (R.road1 - 0.6), -0.5, R.north), V(s * (R.road1 + 0.6), WY + 0.1, zr1 + 0.6))
		for z = R.north + 4, zr0 - 16, 12 do paint(V(s * 102.7, RY, z), V(s * 103.3, RY + 0.12, z + 5)) end
		-- a crosswalk over the side street where it meets the south one: the plaza's sidewalk to the far one
		for k = 0, 4 do paint(V(s * (R.road0 + 1.2 + k * 2.6), RY, zr0 - 7), V(s * (R.road0 + 2.6 + k * 2.6), RY + 0.12, zr0 - 1.5)) end
		-- the towers' paved base (their alleys and forecourts), behind the far sidewalk
		a, b = X(R.walk1, 206)
		sbox(g, 'CityBase', V(a, -1, R.north), V(b, WY, zf + 30), base)
	end
	walk(V(-R.walk0, -1, zs), V(R.walk0, WY, zr0))
	road(V(-R.road1, -1, zr0), V(R.road1, RY, zr1))
	walk(V(-R.walk1, -1, zr1), V(R.walk1, WY, zf))
	sbox(g, 'CityBase', V(-R.walk1, -1, zf), V(R.walk1, WY, zf + 30), base)
	kerb(V(-(R.road0 + 0.6), -0.5, zr0 - 0.6), V(R.road0 + 0.6, WY + 0.1, zr0 + 0.6))
	kerb(V(-(R.road1 + 0.6), -0.5, zr1 - 0.6), V(R.road1 + 0.6, WY + 0.1, zr1 + 0.6))
	for x = -106, 100, 12 do paint(V(x, RY, (zr0 + zr1) / 2 - 0.3), V(x + 5, RY + 0.12, (zr0 + zr1) / 2 + 0.3)) end
	-- the towers, their shops on the street (no shadows over the plaza)
	local bx0, bx1 = R.walk1, R.walk1 + 34
	local t = g:at(CFrame.new(0, WY, 0))
	for _, s in { -1, 1 } do
		local street = s > 0 and 'W' or 'E'
		for _, b in City.Blocks.east do
			local x0, x1 = math.min(s * bx0, s * bx1), math.max(s * bx0, s * bx1)
			local tone = b[5] + (s > 0 and 0 or 3)
			City.highrise(t, x0, x1, b[1], b[2], b[4] + (s > 0 and 0 or 10), { kind = b[3], tone = tone, faces = { street, 'S' }, shops = { street }, setback = b[4] >= 80 and 3 or nil, noShadow = true, name = 'Tower' })
		end
	end
	for _, b in City.Blocks.south do City.highrise(t, b[1], b[2], zf, zf + 30, b[4], { kind = b[3], tone = b[5], faces = { 'N' }, shops = { 'N' }, setback = b[4] >= 80 and 3 or nil, noShadow = true, name = 'Tower' }) end
	-- the corner diner between the south towers, on the spine's line behind the box dais
	City.diner(t, CFrame.new(0, 0, zf + 0.5))
	-- the street's life: taxis and cars at the kerbs, trees in planters and lamps along the plaza's sidewalks
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), C(120, 210, 90) }
	for k, z in { 6, 52, 88 } do
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
-- (Oct 27, the owner's "C" for World 2's lobby) The hall round the plan, its floor and its props: city/e6_hall.lua
-- (it calls City.skyline, so downtown stands round the hall's walls).

-- (Oct 27 round 3, the owner: "please make the leaderboards not be behind each other") The portal and the boards stand
-- where World 1's do (e3_plaza's Lobby.Plan): the portal SW off the south walk on its own path; the three boards in one
-- straight row past the dais's east end, each turned to the crossing, along the front of their own path east off the
-- south walk. No yard of their own. (Oct 27 release fixes) World 1's row starts at x 26, where World 2's first board
-- (POWER) cut 2.8 studs into the box dais (its east end at x 24.1): here the row is x 31, 51, 71 (20 apart).
Lobby.Plan.Boards = { { 31, 86 }, { 51, 86 }, { 71, 86 } }

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
