---------------------------------------------------------------------------------------------- the warehouse (B33, B34)
-- B33 WAREHOUSE (the user: "bring back the warehouse ... it gives the game more personality"; rules 16, 19, 33), made
-- COMPACT in B34 (the user: "redo the lobby layout completely ... make it feel nice to play"; their pick: a smaller,
-- tidier warehouse, everything a few steps from the spawn). Runs after e3_plaza, which lays the zones out.
--   Floor    warm light concrete slabs (two tones, 16 x 16, faint studs), no grass inside; the walks lie on it.
--   Walls    chunky brick round x -86..86, z 6..94 (Oct 27; the training block and the head lane's stage clear of
--            the west wall), a dark brick skirting, cream pilasters every 16 studs, an open clerestory band showing the
--            cliffs and the hood blocks outside, one painted field per wall (west red behind the head lane, north blue
--            either side of the door, east teal behind the gun shop, south yellow behind the box dais), roller doors:
--            open ones onto the yard (the north one onto the Stage 1 gate, 6 studs out), shut slatted ones as detail.
--   Roof     open trusses (chords, posts and braces) and purlins, 31-37 up: no sheeting, so the HoodToy sun throws
--            stripes of shadow on the floor; the camera never meets it. The shell itself casts no shade.
--   Outside  the cliffs, trees and hood blocks, 12 studs past the walls (a grass yard between), seen through the doors.
-- (Oct 27, the owner: "keep the warehouse ... dont make it so cramped": 172 x 88, was 124 x 76; the spine on its middle
-- line like the reference's path, the zones a walk's width off it, calm floor round them; z0 still hugs the gate's wings)
Lobby.WH = { x0 = -86, x1 = 86, z0 = 6, z1 = 100,
	 t = 2, eave = 30, truss = 6, off = 12, bay = 16,
	win = { 17.6, 28.2 }, skirt = 3, -- (Oct 27 round 2: taller clerestory windows, more sky and cliffs over the walls)
	-- open doors: { wall, u0, u1, height } (u along the wall: z for west/east, x for north/south)
	-- (B34 fix round: the north door 28 high, so the Stage 1 gate's whole frame shows through it from the spawn)
	open = { { 'N', -24, 24, 28 }, { 'S', -46, -32, 16 }, { 'S', 32, 46, 16 }, { 'W', 58, 72, 16 } },
	shut = { { 'N', -66, -52, 14 }, { 'W', 12, 24, 14 }, { 'E', 64, 76, 14 } },
	-- one painted field per wall: { wall, u0, u1, y0, y1, colour key }
	-- (B34 fix round: one muted warm brick, no painted fields, stripes or posters: the walls stay quieter than the
	-- things you can use)
	fields = {},
}
Lobby.WHColors = { -- (Oct 27 round 2, the owner: "make the colors more bright ... like the reference": the reference's light green
	-- floor (e3's Lobby.Bright), warm vivid terracotta walls and cream trim instead of the dark brick, lighter steel)
	floorA = Lobby.Bright.floor, floorB = Lobby.Bright.floorB, grass = Lobby.Bright.floor,
	brick = C(238, 146, 92), brickLight = C(246, 162, 106), skirt = C(212, 116, 74), trim = C(255, 218, 168),
	steel = C(124, 132, 156), steelLight = C(158, 166, 188), slat = C(232, 228, 222), slatDark = C(212, 206, 198),
	drum = C(110, 118, 140), lamp = C(255, 236, 170),
	red = C(214, 70, 60), blue = C(60, 128, 214), teal = C(40, 172, 160), yellow = C(250, 196, 50),
}
-- (tutorial targets: gate 1 is reached through the north loading door; its arrows pass the doorway first)
Lobby.Door = 23
Lobby.DoorZ = Lobby.WH.z0 - 1

-- One wall's run as boxes: wall w ('N','S','W','E') from u0 to u1, built as bands between the holes' heights; each hole
-- { ua, ub, ya, yb }. The bands under the skirting height take the skirting colour.
function Lobby.whWall(h, w, u0, u1, holes)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local function box(ua, ub, ya, yb, color, name, inset)
		local i = inset or 0
		local a, b
		if w == 'N' then a, b = V(ua, ya, Wh.z0 - Wh.t), V(ub, yb, Wh.z0 + i)
		elseif w == 'S' then a, b = V(ua, ya, Wh.z1 - i), V(ub, yb, Wh.z1 + Wh.t)
		elseif w == 'W' then a, b = V(Wh.x0 - Wh.t, ya, ua), V(Wh.x0 + i, yb, ub)
		else a, b = V(Wh.x1 - i, ya, ua), V(Wh.x1 + Wh.t, yb, ub) end
		return h:box(name or 'Wall', a, b, color, M.SmoothPlastic)
	end
	local ys = { -1, Wh.skirt, Wh.eave }
	for _, hl in holes do table.insert(ys, hl[3]); table.insert(ys, hl[4]) end
	table.sort(ys)
	for i = 1, #ys - 1 do
		local ya, yb = ys[i], ys[i + 1]
		if yb - ya > 0.01 then
			local open = {}
			for _, hl in holes do if hl[3] <= ya + 0.01 and hl[4] >= yb - 0.01 then table.insert(open, hl) end end
			table.sort(open, function(a, b) return a[1] < b[1] end)
			local col = yb <= Wh.skirt + 0.01 and K.skirt or K.brick
			local u = u0
			for _, hl in open do
				if hl[1] > u + 0.01 then box(u, hl[1], ya, yb, col) end
				u = math.max(u, hl[2])
			end
			if u1 > u + 0.01 then box(u, u1, ya, yb, col) end
		end
	end
	return box
end

-- The shell: four walls with their clerestory, doors, pilasters, fields and cap; the open roof; hanging lamps.
function Lobby.warehouse(L, h)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local walls = {
		N = { Wh.x0, Wh.x1, Vector3.zAxis }, S = { Wh.x0, Wh.x1, -Vector3.zAxis },
		W = { Wh.z0 - Wh.t, Wh.z1 + Wh.t, Vector3.xAxis }, E = { Wh.z0 - Wh.t, Wh.z1 + Wh.t, -Vector3.xAxis },
	}
	-- the inner face's point at u along wall w, height y, d studs into the hall
	local function at(w, u, y, d)
		if w == 'N' then return V(u, y, Wh.z0 + d) elseif w == 'S' then return V(u, y, Wh.z1 - d)
		elseif w == 'W' then return V(Wh.x0 + d, y, u) else return V(Wh.x1 - d, y, u) end
	end
	local function face(w, ua, ub, ya, yb, d0, d1, color, name)
		local a, b = at(w, ua, ya, d0), at(w, ub, yb, d1)
		return h:box(name, a, b, color, M.SmoothPlastic)
	end
	for w, spec in walls do
		local u0, u1 = spec[1], spec[2]
		local doors = {}
		for _, d in Wh.open do if d[1] == w then table.insert(doors, { d[2], d[3], d[4], true }) end end
		for _, d in Wh.shut do if d[1] == w then table.insert(doors, { d[2], d[3], d[4], false }) end end
		local function inDoor(a, b)
			for _, d in doors do if b > d[1] - 1 and a < d[2] + 1 then return true end end
			return false
		end
		local function inField(a, b, y0)
			for _, f in Wh.fields do if f[1] == w and b > f[2] - 1 and a < f[3] + 1 and f[5] > y0 then return true end end
			return false
		end
		-- the holes: the open doors, and a clerestory window in every bay with no field reaching up into it
		local holes = {}
		for _, d in doors do if d[4] then table.insert(holes, { d[1], d[2], -1, d[3] }) end end
		local lo, hi = math.min(Wh.x0, Wh.z0), math.max(Wh.x1, Wh.z1)
		local bays = {}
		local b0 = math.ceil((u0 + 1) / Wh.bay) * Wh.bay
		for u = b0, u1 - Wh.bay, Wh.bay do
			if not inField(u + 3, u + 13, Wh.win[1]) and not (w == 'N' and math.abs(u + 8) < 30) then
				table.insert(holes, { u + 3, u + 13, Wh.win[1], Wh.win[2] })
				table.insert(bays, u)
			end
		end
		local _ = lo + hi
		Lobby.whWall(h, w, u0, u1, holes)
		-- window mullions and sills
		for _, u in bays do
			face(w, u + 7.5, u + 8.5, Wh.win[1], Wh.win[2], -Wh.t + 0.4, -0.4, K.steel, 'WallMullion')
			face(w, u + 2.6, u + 13.4, Wh.win[1] - 0.6, Wh.win[1], -Wh.t - 0.4, 0.5, K.trim, 'WallSill')
		end
		-- pilasters on the bay lines (none across a door), skirting-dark foot
		for u = b0, u1, Wh.bay do
			if u > u0 + 1 and u < u1 - 1 and not inDoor(u - 1, u + 1) and not inField(u - 1, u + 1, -1) then
				face(w, u - 1, u + 1, Wh.skirt, Wh.eave, 0, 0.8, K.trim, 'WallPilaster')
				face(w, u - 1.2, u + 1.2, 0, Wh.skirt, 0, 1.0, K.skirt, 'WallPilasterFoot')
			end
		end
		-- the cap along the top, inside and out
		face(w, u0, u1, Wh.eave, Wh.eave + 1.2, -Wh.t - 0.4, 0.6, K.trim, 'WallCap')
		-- doors: steel jambs and header, the drum box over each; open ones keep 2 studs of curtain showing, shut ones are
		-- a full slatted curtain set 0.6 into the opening
		for _, d in doors do
			local a, b, ht, isOpen = d[1], d[2], d[3], d[4]
			face(w, a - 1.4, a, 0, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorJamb')
			face(w, b, b + 1.4, 0, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorJamb')
			face(w, a, b, ht, ht + 1.4, -0.2, 0.7, K.steel, 'WallDoorHeader')
			face(w, a + 0.2, b - 0.2, ht - 2.2, ht, 0.1, 1.9, K.drum, 'WallDoorDrum')
			if isOpen then
				for k = 0, 1 do
					face(w, a + 0.3, b - 0.3, ht - 3.2 - k, ht - 2.2 - k, 0.9, 1.3, k % 2 == 0 and K.slat or K.slatDark, 'WallDoorSlat')
				end
				-- (B34 fix round: no hazard stripes on the jambs)
			else
				local y = 0
				local k = 0
				while y < ht - 2.2 - 0.01 do
					local y1 = math.min(y + 1, ht - 2.2)
					face(w, a, b, y, y1, 0.2, 0.6, k % 2 == 0 and K.slat or K.slatDark, 'WallDoorSlat')
					y, k = y1, k + 1
				end
				face(w, a + (b - a) / 2 - 1.5, a + (b - a) / 2 + 1.5, 0.6, 1.2, 0.6, 0.9, K.drum, 'WallDoorHandle')
			end
		end
		-- the painted fields, a trim frame round each
		for _, f in Wh.fields do
			if f[1] == w then
				face(w, f[2], f[3], f[4], f[5], 0, 0.3, K[f[6]], 'WallField')
				face(w, f[2] - 0.6, f[3] + 0.6, f[5], f[5] + 0.6, 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[2] - 0.6, f[3] + 0.6, f[4] - 0.6, f[4], 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[2] - 0.6, f[2], f[4], f[5], 0, 0.5, K.trim, 'WallFieldFrame')
				face(w, f[3], f[3] + 0.6, f[4], f[5], 0, 0.5, K.trim, 'WallFieldFrame')
			end
		end
		local _ = spec[3]
	end
	-- corner posts (outside the walls' ends) up to the cap
	for _, cx in { Wh.x0 - Wh.t, Wh.x1 } do
		for _, cz in { Wh.z0 - Wh.t, Wh.z1 } do
			h:box('WallCorner', V(cx - 0.6, -1, cz - 0.6), V(cx + Wh.t + 0.6, Wh.eave + 1.6, cz + Wh.t + 0.6), K.trim, M.SmoothPlastic)
		end
	end
	-- the shell throws no shade (no zone in its gloom); it stays solid and queryable (the tutorial's arrows raycast it)
	for _, p in h.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Name:find('^Wall') then p.CastShadow = false end
	end
	-- the open roof: a truss every 18 studs across the hall (east-west), purlins along it; it throws the sun's stripes
	local r = L:group('Roof')
	local y0, y1 = Wh.eave + 1.2, Wh.eave + 1.2 + Wh.truss
	local xa, xb = Wh.x0 - Wh.t, Wh.x1 + Wh.t
	local n = 20
	for z = Wh.z0 + 10, Wh.z1 - 6, 18 do
		r:box('RoofChord', V(xa, y0, z - 0.6), V(xb, y0 + 1.2, z + 0.6), K.steel, M.SmoothPlastic)
		r:box('RoofChord', V(xa, y1 - 1.2, z - 0.6), V(xb, y1, z + 0.6), K.steel, M.SmoothPlastic)
		local step = (xb - xa) / n
		for k = 0, n do
			local x = xa + k * step
			local px = math.clamp(x, xa + 0.5, xb - 0.5)
			r:box('RoofPost', V(px - 0.5, y0 + 1.2, z - 0.5), V(px + 0.5, y1 - 1.2, z + 0.5), K.steelLight, M.SmoothPlastic)
			if k < n then
				local a, b = V(x + 0.5, y0 + 1.2, z), V(x + step - 0.5, y1 - 1.2, z)
				if k % 2 == 1 then a, b = V(x + 0.5, y1 - 1.2, z), V(x + step - 0.5, y0 + 1.2, z) end
				r:bar('RoofBrace', a, b, 0.8, K.steelLight, M.SmoothPlastic)
			end
		end
	end
	for x = Wh.x0 + 8.65, Wh.x1 - 4, 17.3 do
		r:box('RoofPurlin', V(x - 0.6, y1, Wh.z0 - Wh.t), V(x + 0.6, y1 + 1.2, Wh.z1 + Wh.t), K.steel, M.SmoothPlastic)
	end
	-- hanging lamps under the trusses either side of the spine (chunky shade, a warm glowing underside)
	local lamps = L:group('HallLamps')
	for z = Wh.z0 + 10, Wh.z1 - 6, 18 do
		for _, x in { -46, 46 } do
			lamps:box('LampRod', V(x - 0.2, 24.6, z - 0.2), V(x + 0.2, y0, z + 0.2), K.drum, M.SmoothPlastic)
			lamps:box('LampShade', V(x - 1.6, 23.4, z - 1.6), V(x + 1.6, 24.6, z + 1.6), K.steel, M.SmoothPlastic)
			local g = lamps:box('LampGlow', V(x - 1.2, 23.1, z - 1.2), V(x + 1.2, 23.4, z + 1.2), K.lamp, M.Neon)
			light(g, K.lamp, 0.6, 26)
		end
	end
	for _, p in lamps.parent:GetDescendants() do
		if p:IsA('BasePart') then decor(p).CastShadow = false end
	end
	return h
end

-- (replaces the plaza's ground) Concrete inside, a grass yard outside, the shell, and the cliffs moved out past it.
function Lobby.hall(L)
	local Wh, K = Lobby.WH, Lobby.WHColors
	local h = L:group('Hall')
	-- the concrete: 16 x 16 slabs in two tones on the spawn's grid, the doorways' thresholds included
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
				studs(f:box('Concrete', V(xa, -1, za), V(xb, 0, zb), (i + j) % 2 == 0 and K.floorA or K.floorB, M.Plastic))
			end
		end
	end
	for _, d in Wh.open do
		local a, b, w = d[2], d[3], d[1]
		local t
		if w == 'N' then t = f:box('Threshold', V(a, -1, Wh.z0 - Wh.t), V(b, 0, Wh.z0), K.floorB, M.SmoothPlastic)
		elseif w == 'S' then t = f:box('Threshold', V(a, -1, Wh.z1), V(b, 0, Wh.z1 + Wh.t), K.floorB, M.SmoothPlastic)
		elseif w == 'W' then t = f:box('Threshold', V(Wh.x0 - Wh.t, -1, a), V(Wh.x0, 0, b), K.floorB, M.SmoothPlastic)
		else t = f:box('Threshold', V(Wh.x1, -1, a), V(Wh.x1 + Wh.t, 0, b), K.floorB, M.SmoothPlastic) end
		local _ = t
	end
	-- the yard outside: grass all round the shell, out under the cliffs
	local xa, xb, za, zb = Wh.x0 - Wh.t, Wh.x1 + Wh.t, Wh.z0 - Wh.t, Wh.z1 + Wh.t
	for _, r in { { -130, 130, Lobby.N - 1, za }, { -130, 130, zb, 160 }, { -130, xa, za, zb }, { xb, 130, za, zb } } do
		if r[4] - r[3] > 0.5 then studs(h:box('Grass', V(r[1], -1, r[3]), V(r[2], 0, r[4]), K.grass, M.Plastic)) end
	end
	Lobby.warehouse(L, h)
	Lobby.outdoors(L)
	return h
end

-- The plaza's cliffs, trees and hood blocks, built 12 studs further out (past the walls and a grass yard); the north row
-- of cliff tiles goes (the north wall stands there; the stage's street is behind it).
function Lobby.outdoors(L)
	local B, O = Lobby.Bounds, Lobby.WH.off
	local tiles = Lobby.cliffTiles
	Lobby.Bounds = { x = B.x + O, xw = B.xw + O, xe = B.xe + O, n = Lobby.WH.z0 - Lobby.WH.t, s = B.s + O, mouth = B.mouth }
	Lobby.cliffTiles = function(g, a, b, inward, k)
		if inward.Z > 0.5 then return end
		return tiles(g, a, b, inward, k)
	end
	local ok, err = pcall(Lobby.cliffs, L)
	Lobby.Bounds, Lobby.cliffTiles = B, tiles
	if not ok then warn('[Lobby] outdoors: ' .. tostring(err)) end
end

-- (rule 19: no grass inside) the scenery with purpose, only along the walls and round a reason (B34): a hoop by the
-- west door,
-- crates and drums in the two south corners, cones and a hydrant and a bin at the open south doors; trees and bushes
-- out in the yard, framed by the doors. Nothing on a walk, nothing between the zones.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Wh = Lobby.WH
	add('Scn_Hoop', Wh.x0 + 4, 54, -90) -- (by the west door)
	add('Scn_Crate', Wh.x0 + 3.4, Wh.z1 - 3.4, 0) add('Scn_Crate', Wh.x0 + 6.4, Wh.z1 - 3, 12) add('Scn_Barrel', Wh.x0 + 3.6, Wh.z1 - 7.4, 0)
	add('Scn_Crate', Wh.x1 - 3.4, Wh.z1 - 3.4, 0) add('Scn_Barrel', Wh.x1 - 3.6, Wh.z1 - 7.4, 0) add('Scn_Barrel', Wh.x1 - 6.2, Wh.z1 - 3.2, 20)
	for _, d in Wh.open do
		if d[1] == 'S' then add('Scn_Cone', d[2] + 2, Wh.z1 - 2.2, 0) add('Scn_Cone', d[3] - 2, Wh.z1 - 2.2, 0) end
	end
	add('Scn_Hydrant', -50, Wh.z1 - 2.4, 180) add('Scn_TrashCan', 28, Wh.z1 - 2.4, 180)
	-- out in the yard (framed by the doors and the clerestory)
	add('Scn_Tree_1', -56, Wh.z1 + 10, 0) add('Scn_Tree_2', 42, Wh.z1 + 10, 0) add('Scn_Tree_2', Wh.x1 + 12, 15, 0) add('Scn_Tree_1', Wh.x0 - 12, 78, 0)
	for _, x in { -70, -44, 34, 58 } do add('Scn_Bush_1', x, Wh.z1 + 5.6, 0) end
	add('Scn_Bush_1', Wh.x1 + 6, 4, -90) add('Scn_Bush_1', Wh.x1 + 6, 26, -90) add('Scn_Bush_1', Wh.x0 - 6, 64, 90) add('Scn_Bush_1', Wh.x0 - 6, 88, 90)
	return list
end)()
