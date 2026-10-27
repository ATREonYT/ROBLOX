---------------------------------------------------------------------------------------------- the downtown plaza (World 2)
-- World 2's lobby (runs after e4_warehouse, so it replaces the warehouse's shell): the same plan as World 1's (e3_plaza:
-- spawn on the spine facing the Stage 1 gate north, the training block west, the gun stand east, the box dais south, the
-- portal SW, the boards SE, the special-sale spots and the chests before the gate), out in the open in a downtown plaza:
--   Floor    one calm field of warm sand pavers (16 x 16, two close tones, faint studs), the zones on World 1's raised
--            light grey platforms on it, the walks over it
--   Edge     a low terracotta planter wall with a trimmed hedge on top all round (the keep-in walls are f_areas' invisible
--            ones on Lobby.Bounds), open to the north on the gate's forecourt
--   Outside  a ring street (light stone sidewalks, asphalt with white dashes, taxis and cars) and glass-and-steel towers
--            on warm stone bases all round, 30-110 studs high: the skyline over the hedge, sky above it
--   Portal   the way back: a brick arch onto the hood (the travel itself is the services'), where World 1 has its World 2 door
-- The builders below (City.tower, City.taxi, City.bus, City.foodTruck, City.busStop, City.planter, City.lamp) are the
-- avenue's too (city/f5_avenue.lua).

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

---------------------------------------------------------------------------------------------- the plaza
-- Downtown's ring street and skyline round the plaza (map frame): sidewalk x 88.5..96, the road 96..110, the far
-- sidewalk 110..116, the towers past it (over f_areas' low wall at 124); the same to the south from z 96.5.
City.Ring = { walk0 = 88.5, road0 = 96, road1 = 110, walk1 = 116, south = 96.5 }
City.Skyline = {
	-- { x0, x1, z0, z1, h, tone, faces } on the east side (the west mirrors it); faces: the ones you see from the plaza
	east = {
		{ 116, 150, -66, -32, 104, 3 }, { 116, 150, -26, 8, 72, 1 }, { 116, 150, 14, 46, 112, 2 },
		{ 116, 150, 52, 80, 82, 4 }, { 116, 150, 86, 116, 64, 1 }, { 116, 150, 122, 154, 92, 3 },
	},
	south = { { -110, -82, 124, 156, 70, 2 }, { -76, -46, 124, 156, 96, 4 }, { -40, -14, 124, 156, 60, 1 }, { -8, 22, 124, 156, 84, 3 },
		{ 28, 56, 124, 156, 66, 2 }, { 62, 90, 124, 156, 100, 1 }, { 96, 110, 124, 156, 58, 4 } },
	-- behind the avenue's towers, either side of the gate (seen over the plaza's north edge)
	north = { { 66, 94, -52, -8, 86, 2 }, { 66, 94, -112, -58, 118, 4 } },
}
function City.skyline(L)
	local g = L:group('Surroundings')
	local R = City.Ring
	-- the ring street: sidewalks (light stone, a pale kerb on the road edge), the asphalt with a white dashed centre line
	local function walk(a, b) sbox(g, 'Sidewalk', a, b, City.walk) end
	local function road(a, b) sbox(g, 'Road', a, b, City.road) end
	for _, s in { -1, 1 } do
		walk(V(s * R.walk0, -1, -4), V(s * R.road0, 0.45, R.south))
		road(V(s * R.road0, -1, -70), V(s * R.road1, 0, 104))
		walk(V(s * R.road1, -1, -70), V(s * R.walk1, 0.45, 124))
		walk(V(s * 36, -1, -4), V(s * R.walk0, 0.45, 3.5)) -- (the strip along the plaza's north edge, to the avenue's towers)
		for _, x in { R.road0, R.road1 } do decor(sbox(g, 'KerbStone', V(s * (x - 0.6), -0.5, -70), V(s * (x + 0.6), 0.55, x == R.road0 and R.south or 124), City.kerb)).CastShadow = false end
		for z = -66, 100, 12 do decor(sbox(g, 'RoadDash', V(s * 102.7, 0, z), V(s * 103.3, 0.12, z + 5), City.line)).CastShadow = false end
	end
	walk(V(-R.road0, -1, R.south), V(R.road0, 0.45, 104))
	road(V(-R.road1, -1, 104), V(R.road1, 0, 118))
	walk(V(-R.walk1, -1, 118), V(R.walk1, 0.45, 124))
	for x = -106, 100, 12 do decor(sbox(g, 'RoadDash', V(x, 0, 110.7), V(x + 5, 0.12, 111.3), City.line)).CastShadow = false end
	-- crosswalks where the side streets meet the south one
	for _, s in { -1, 1 } do
		for k = 0, 4 do decor(sbox(g, 'Zebra', V(s * (R.road0 + 1 + k * 2.6), 0, 98), V(s * (R.road0 + 2.4 + k * 2.6), 0.12, 103.4), City.line)).CastShadow = false end
	end
	-- the towers
	for _, s in { -1, 1 } do
		local side = s > 0 and 'W' or 'E'
		for _, b in City.Skyline.east do
			City.tower(g, s * b[1], s * b[2], b[3], b[4], b[5], { tone = b[6] + (s > 0 and 0 or 1), faces = { side, 'S', 'N' }, setback = b[5] >= 90 and 4 or nil, noShadow = true })
		end
		for _, b in City.Skyline.north do
			City.tower(g, s * b[1], s * b[2], b[3], b[4], b[5], { tone = b[6] + (s > 0 and 1 or 0), faces = { 'S', side }, setback = b[5] >= 90 and 4 or nil, noShadow = true })
		end
	end
	for _, b in City.Skyline.south do
		City.tower(g, b[1], b[2], b[3], b[4], b[5], { tone = b[6], faces = { 'N' }, setback = b[5] >= 90 and 4 or nil, noShadow = true, door = 'N' })
	end
	-- the street's life: taxis and cars at the kerbs, trees in planters and lamps along the plaza's sidewalk
	local cars = { C(214, 52, 52), P.white, C(52, 102, 214), C(120, 210, 90) }
	for k, z in { -40, 6, 52, 88 } do
		for _, s in { -1, 1 } do
			local cf = CFrame.new(s * 99, 0, z + (s > 0 and 14 or 0)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0)
			if (k + (s > 0 and 1 or 0)) % 2 == 0 then City.taxi(g, cf) else car(g, cf, cars[k]) end
		end
	end
	for k, x in { -70, -20, 44, 86 } do
		local cf = CFrame.new(x, 0, 107) * CFrame.Angles(0, math.pi / 2, 0)
		if k % 2 == 1 then City.taxi(g, cf) else car(g, cf, cars[k]) end
	end
	for _, s in { -1, 1 } do
		for z = 14, 90, 19 do City.planter(g, V(s * 92.2, 0.45, z), 700 + z + (s > 0 and 3 or 0)) end
		for z = 23.5, 80, 19 do City.lamp(g, V(s * 94.6, 0.45, z), s) end
	end
	for x = -80, 80, 20 do City.planter(g, V(x, 0.45, 100.2), 760 + x) end
	-- (no shade from out here on the plaza: the towers cast none, like World 1's cliffs)
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
	-- the edge: the planter wall (2.4 high, a pale cap) with its hedge, west / east / south, and the north either side of
	-- the gate's forecourt
	local e = L:group('PlazaEdge')
	local function wall(a, b)
		sbox(e, 'PlanterWall', V(a.X, -1, a.Z), V(b.X, 2.4, b.Z), City.clay)
		decor(sbox(e, 'PlanterCap', V(a.X - 0.2, 2.4, a.Z - 0.2), V(b.X + 0.2, 2.7, b.Z + 0.2), City.clayCap)).CastShadow = false
		sbox(e, 'Hedge', V(a.X + 0.4, 2.7, a.Z + 0.4), V(b.X - 0.4, 4.2, b.Z - 0.4), City.hedge)
		decor(sbox(e, 'HedgeTop', V(a.X + 0.8, 4.2, a.Z + 0.8), V(b.X - 0.8, 4.7, b.Z - 0.8), City.hedgeTop))
	end
	local x1, zs = Wh.x1 + 2.5, Wh.z1 + 2.5
	wall(V(-x1, 0, Wh.z0 - 2.5), V(-Wh.x1, 0, zs))
	wall(V(Wh.x1, 0, Wh.z0 - 2.5), V(x1, 0, zs))
	wall(V(-Wh.x1, 0, Wh.z1), V(Wh.x1, 0, zs))
	for _, s in { -1, 1 } do wall(V(s * (Lobby.Bounds.mouth + 1), 0, Wh.z0 - 2.5), V(s * Wh.x1, 0, Wh.z0)) end
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
		add('Scn_Bench', sx * 62, Wh.z1 - 2.4, 0) add('Scn_TrashCan', sx * 56.5, Wh.z1 - 2.2, 0)
		add('Scn_StreetLamp', sx * 66, Wh.z0 + 2.2, -90)
		add('Scn_StreetLamp', sx * (Wh.x1 - 2.4), 70, sx < 0 and 0 or 180)
		add('Scn_Bush_1', sx * (Wh.x1 - 3), 30, 0)
	end
	return list
end)()

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
