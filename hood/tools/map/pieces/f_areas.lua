---------------------------------------------------------------------------------------------- ground
-- Light grey paving in 8-stud slabs over the whole walk, a darker cross-street band at every district
-- line, grass behind the buildings, the low boundary wall and the ring road with its cars and trees. The
-- warehouse lobby (e2_lobby) lays its own floor; out here there's only the forecourt between its door and
-- the Stage 1 gate, and grass round the building.
local function invisibleWall(c, a, b)
	local w = c:box('Boundary', a, b, P.white, M.SmoothPlastic)
	w.Transparency = 1
	w.CastShadow = false
	return w
end
local function buildGround(ctx)
	assert(Lobby, 'TheBlockV2: e2_lobby.lua (the warehouse lobby) is missing from the assembly')
	local g = ctx:group('Ground')
	-- Paving under the boss yard.
	local function pave(x0, x1, z0, z1)
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - z0) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-FRONT, FRONT, BOSS_END, BOSS_TOP)
	-- The stage street from the warehouse door to the boss yard, the reference's cross-section (P.street): studded
	-- dark asphalt with a yellow dashed centre line, raised studded sidewalks, studded grass out to the buildings.
	local ST = P.street
	local zA, zB = BOSS_TOP, Lobby.N - 1
	local road, walk = ST.road, ST.road + ST.walk
	sbox(g, 'Road', V(-road, -1, zA), V(road, 0, zB), P.st.road)
	for _, s in { -1, 1 } do
		sbox(g, 'Sidewalk', V(s * road, -1, zA), V(s * walk, ST.kerb, zB), P.st.walk)
		sbox(g, 'Grass', V(s * walk, -1, zA), V(s * FRONT, ST.kerb, zB), P.st.grass)
	end
	-- Centre dashes 1 x 4 every 16 studs, standing a little proud like the picture's (7..11 past each gate, ...).
	for z = -7, zA + 4, -16 do sbox(g, 'RoadDash', V(-0.5, 0, z - 4), V(0.5, 0.2, z), P.st.dash, true) end
	-- Second tones and finished edges: a darker gutter strip along each kerb, light kerb stones capping the sidewalk's
	-- road edge, darker slab joints across the sidewalk every 8 studs, and a darker green edging where the grass starts.
	for _, s in { -1, 1 } do
		sbox(g, 'RoadGutter', V(s * (road - 1.2), -0.5, zA), V(s * (road - 0.05), 0.03, zB), P.st.roadDark, true)
		sbox(g, 'KerbStone', V(s * (road - 0.05), -0.5, zA), V(s * (road + 1), ST.kerb + 0.08, zB), P.st.kerbStone, true)
		sbox(g, 'GrassEdge', V(s * walk, ST.kerb - 0.2, zA), V(s * (walk + 0.8), ST.kerb + 0.04, zB), P.st.grassEdge, true)
		local k = 0
		for z = zB - 8, zA + 1, -8 do
			decor(g:box('WalkJoint', V(s * (road + 1), ST.kerb - 0.1, z - 0.15), V(s * walk, ST.kerb + 0.02, z + 0.15), P.st.walkJoint, M.Plastic)).CastShadow = false
			-- every third slab a shade lighter, every fifth a shade darker (worn and newer paving)
			k += 1
			local tone = (k * (s > 0 and 2 or 1)) % 3 == 0 and P.st.walk:Lerp(P.white, 0.1) or (k % 5 == 0 and P.st.walk:Lerp(P.black, 0.07)) or nil
			if tone then decor(sbox(g, 'WalkSlab', V(s * (road + 1), ST.kerb - 0.1, z - 7.85), V(s * walk, ST.kerb + 0.025, z - 0.15), tone)).CastShadow = false end
		end
	end
	-- Grass behind the buildings and round the warehouse, inside the low boundary wall.
	local zIn0, zIn1 = BOSS_END - 6, SPAWN_TOP + 6
	for _, s in { -1, 1 } do
		g:box('Grass', V(s * (FRONT + DEPTH), -1, BOSS_END), V(s * WALL_X, 0.4, 0), P.grass, M.Grass)
		if not Lobby.Open then g:box('Grass', V(s * SPAWN_W, -1, 0), V(s * WALL_X, 0.4, SPAWN_TOP), P.grass, M.Grass) end -- (B31: the plaza's own field)
		g:box('Grass', V(s * FRONT, -1, 0), V(s * SPAWN_W, 0.4, Lobby.N - 1), P.grass, M.Grass)
		g:box('Wall', V(s * WALL_X, -1, zIn0 - 1.4), V(s * (WALL_X + 1.4), 3, zIn1 + 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(s * (WALL_X - 0.2), 3, zIn0 - 1.6), V(s * (WALL_X + 1.6), 3.5, zIn1 + 1.6), P.kerb, M.Concrete)
	end
	g:box('Grass', V(-WALL_X, -1, SPAWN_TOP), V(WALL_X, 0.4, zIn1), P.grass, M.Grass)
	g:box('Grass', V(-FRONT - DEPTH, -1, zIn0), V(FRONT + DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(-WALL_X, -1, zIn0), V(-FRONT - DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(FRONT + DEPTH, -1, zIn0), V(WALL_X, 0.4, BOSS_END), P.grass, M.Grass)
	for _, e in { { zIn1, 1 }, { zIn0, -1 } } do
		g:box('Wall', V(-WALL_X, -1, e[1]), V(WALL_X, 3, e[1] + e[2] * 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(-WALL_X + 0.2, 3, e[1] - e[2] * 0.2), V(WALL_X - 0.2, 3.5, e[1] + e[2] * 1.6), P.kerb, M.Concrete)
	end
	-- Ring road outside the wall: kerb, two lanes with a dashed centre line, kerb, a grass verge with
	-- trees. Each band runs down both long sides and across both ends; the ends take the corners.
	local road = ctx:group('RingRoad')
	local W0 = WALL_X + 1.4
	local zTop, zBot = zIn1 + 1.4, zIn0 - 1.4
	for _, band in { { 0, 4, P.kerb, M.Concrete, 0.4 }, { 4, 20, P.asphalt, M.Asphalt, 0 }, { 20, 24, P.kerb, M.Concrete, 0.4 }, { 24, 32, P.grass, M.Grass, 0.4 } } do
		local a, b, color, mat, top = band[1], band[2], band[3], band[4], band[5]
		for _, s in { -1, 1 } do road:box('Road', V(s * (W0 + a), -1, zBot - a), V(s * (W0 + b), top, zTop + a), color, mat) end
		if not Lobby.Open then road:box('Road', V(-(W0 + b), -1, zTop + a), V(W0 + b, top, zTop + b), color, mat) end -- (B31: under the south cliffs)
		road:box('Road', V(-(W0 + b), -1, zBot - b), V(W0 + b, top, zBot - a), color, mat)
	end
	for _, s in { -1, 1 } do
		for z = zBot, zTop - 5, 10 do decor(road:box('RoadDash', V(s * (W0 + 11.8), 0, z), V(s * (W0 + 12.2), 0.04, z + 5), P.roadLine, M.SmoothPlastic)) end
	end
	for x = -(W0 + 8), W0 + 3, 10 do
		if not Lobby.Open then decor(road:box('RoadDash', V(x, 0, zTop + 11.8), V(x + 5, 0.04, zTop + 12.2), P.roadLine, M.SmoothPlastic)) end
		decor(road:box('RoadDash', V(x, 0, zBot - 12.2), V(x + 5, 0.04, zBot - 11.8), P.roadLine, M.SmoothPlastic))
	end
	-- Trees on the verge and behind the buildings, cars parked at the kerb.
	local seed = 900
	for _, s in { -1, 1 } do
		for z = zBot - 20, zTop + 20, 22 do
			seed += 1
			tree(road, V(s * (W0 + 28), 0.4, z), seed, 1.0, nil, true)
		end
		for z = BOSS_END + 20, -10, 30 do
			seed += 1
			tree(road, V(s * (FRONT + DEPTH + 3), 0.4, z), seed, 0.85, nil, true)
		end
	end
	for x = -(W0 + 20), W0 + 20, 22 do
		seed += 1
		if not Lobby.Open then tree(road, V(x, 0.4, zTop + 28), seed, 1.0, nil, true) end
		tree(road, V(x, 0.4, zBot - 28), seed + 50, 1.0, nil, true)
	end
	local carColors = { C(252, 204, 40), P.white, C(214, 52, 52), C(52, 102, 214), C(252, 204, 40), C(230, 230, 232) }
	local spots = { { -1, 40 }, { -1, -110 }, { -1, -300 }, { -1, -520 }, { -1, -760 }, { -1, -980 }, { 1, 10 }, { 1, -190 }, { 1, -370 }, { 1, -610 }, { 1, -850 }, { 1, -1040 } }
	for k, sp in spots do
		car(road, CFrame.new(sp[1] * (W0 + 7.5), 0, sp[2]) * CFrame.Angles(0, sp[1] < 0 and math.pi or 0, 0), carColors[(k - 1) % #carColors + 1])
	end
	-- Keep players on the walk where no building closes it: round the warehouse (its walls already do, these
	-- go up past the eaves) and over the forecourt's wing walls.
	if Lobby.Open then
		-- (B31 PLAZA) the open plaza: walls on the cliffs' faces (the steps are solid too; these go up past them)
		local B = Lobby.Bounds
		for _, s in { -1, 1 } do
			local X = Lobby.edgeX(s)
			invisibleWall(g, V(s * X, 0, Lobby.N - 6), V(s * (X + 1), 60, B.s))
			invisibleWall(g, V(s * B.mouth, 0, B.n), V(s * X, 60, B.n + 1))
			invisibleWall(g, V(s * B.mouth, 0, 0.6), V(s * (B.mouth + 1), 60, B.n))
		end
		invisibleWall(g, V(-B.xw, 0, B.s), V(B.xe, 60, B.s + 1))
		invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
		return g
	end
	for _, s in { -1, 1 } do
		-- (B30 LOBBY: the west one leaves the head lane's alcove open, Lobby.Apse; the alcove's own walls close it)
		local A = s < 0 and Lobby.Apse
		if A then
			invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, A.z0 - 1))
			invisibleWall(g, V(s * SPAWN_W, 0, A.z1 + 1), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		else
			invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		end
		invisibleWall(g, V(s * 34.4, 0, 0.6), V(s * FRONT, 60, Lobby.N))
	end
	invisibleWall(g, V(-SPAWN_W, 0, SPAWN_TOP), V(SPAWN_W, 60, SPAWN_TOP + 1))
	invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
	return g
end

---------------------------------------------------------------------------------------------- spawn
-- The spawn is the warehouse lobby (e2_lobby): shooting ranges, the EVOLUTIONS podium, the armory,
-- the spawn badge, FurthestPad and the leaderboards are all built there.
local function buildSpawn(ctx, skins)
	return Lobby.build(ctx, skins)
end
