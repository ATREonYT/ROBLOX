---------------------------------------------------------------------------------------------- the downtown avenue (World 2)
-- World 2's stages (runs after f2_stages; its buildStages is the one V2.Build calls). The cross-section is World 1's
-- (f_areas, P.street, in the city's colours from a2_city): the asphalt run |x| < 8.5 with white dashes, the stone
-- sidewalks to 16.5, the paved strip to the tower fronts at 36. Each stage adds (z' = studs past its own gate):
--   towers   two glass towers a side (z' 0..28 and 28..56, fronts at |x| 36, back to 64), taller every stage, their lobby
--            doors and canopies on the avenue; a low glass pavilion each side at z' 56..64 out to |x| 22, framing the
--            next gate the way World 1's end buildings do
--   street   solid white edge lines, a zebra crosswalk at z' 22..28 with a traffic light over it, tall steel lamps
--   life     taxis in the lay-bys, a bus stop (and a bus on Stage 2), two food trucks, planters with trimmed trees
-- Gates 1-3 are World 1's builder (f2's stageGate) with World 2's wall ids (HoodW2Stage<i>) and WORLD 2 on gate 1's
-- board; gate 3 stands shut in front of the HQ tower that closes the avenue until the rest of the world is built.

-- One stage of the avenue: World 1's stage group with its hidden fight marker (District.base), then the city on it.
function City.avenueStage(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local k = ST.kerb
	local tall = { { 34, 46 }, { 58, 76 } } -- (low by the lobby, so the gate keeps its sky; the skyline rises behind)
	local hs = tall[i] or { 60 + i * 10, 80 + i * 10 }
	for _, s in { -1, 1 } do
		local street = s < 0 and 'E' or 'W'
		local function x(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		-- the towers (this side's tones offset, so facing towers differ)
		local xa, xb = x(FRONT, FRONT + DEPTH)
		City.tower(d, xa, xb, top - 28, top, hs[1], { tone = i + (s > 0 and 1 or 2), faces = { street, 'S' }, door = street, baseH = 9, name = 'TowerA' })
		City.tower(d, xa, xb, top - 56, top - 28, hs[2], { tone = i + (s > 0 and 2 or 3), faces = { street, 'S' }, door = street, baseH = 9, setback = 4, name = 'TowerB' })
		local pa, pb = x(ST.open, FRONT + DEPTH)
		City.tower(d, pa, pb, top - SLEN, top - ST.endZ, 15, { tone = i + 3, faces = { street, 'S' }, baseH = 6, pitch = 3, name = 'Pavilion' })
		-- the solid white edge line along the run
		decor(sbox(d, 'LaneEdge', V(s * 7.2, 0, top - SLEN), V(s * 7.7, 0.12, top), City.line)).CastShadow = false
		-- lamps on the sidewalk, their arms over the run
		for _, zp in { 9, 41 } do City.lamp(d, at(s * 15.4, zp), -s) end
	end
	-- the crosswalk and its traffic light (one side, alternating by stage)
	District.zebra(d, V(-6.25, 0, top - 25), 1.4, 6, V(2.5, 0, 0), 6)
	decor(sbox(d, 'StopLine', V(-7.2, 0, top - 30.2), V(7.2, 0.12, top - 29.6), City.line)).CastShadow = false
	local ls = i % 2 == 1 and 1 or -1
	District.trafficLight(d, at(ls * 10.6, 20.5), -ls)
	-- the street's life, set per stage
	if i == 1 then
		City.busStop(d, CFrame.new(at(-20.2, 19)) * CFrame.Angles(0, -math.pi / 2, 0))
		City.taxi(d, CFrame.new(at(-19.6, 36)))
		City.taxi(d, CFrame.new(at(-19.6, 48)))
		City.foodTruck(d, CFrame.new(at(27.5, 18)) * CFrame.Angles(0, math.pi, 0), C(240, 96, 60), 'TACOS')
		City.taxi(d, CFrame.new(at(19.6, 44)))
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { 19.6, 32 }, { -27, 52 }, { 26, 52 } } do City.planter(d, at(p[1], p[2]), 800 + i * 10 + p[2]) end
	else
		City.foodTruck(d, CFrame.new(at(-27.5, 22)), C(60, 150, 240), 'ICE CREAM')
		City.taxi(d, CFrame.new(at(-19.6, 46)))
		City.bus(d, CFrame.new(at(19.8, 20)), C(40, 120, 220))
		City.busStop(d, CFrame.new(at(21.4, 42)) * CFrame.Angles(0, math.pi / 2, 0))
		City.foodTruck(d, CFrame.new(at(29, 44)) * CFrame.Angles(0, math.pi, 0), C(250, 180, 40), 'BURGERS')
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { -19.6, 34 }, { -27, 52 } } do City.planter(d, at(p[1], p[2]), 800 + i * 10 + p[2]) end
	end
	return d
end
-- The HQ tower closing the avenue behind the last gate (until the rest of the world is built): wide, the tallest,
-- its doors and DOWNTOWN over them facing the avenue.
function City.hq(ctx)
	local z = gateZ(STAGES + 1)
	local t, model = City.tower(ctx:group('Downtown'), -64, 64, z - 52, z - 1.6, 128, { tone = 1, faces = { 'S', 'E', 'W' }, door = 'S', baseH = 14, setback = 8, name = 'HQTower' })
	local plate = t:box('HQSign', V(-18, 14.9, z - 1.4), V(18, 19.6, z - 1.2), P.white, M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Back, 10), 'Name', 'DOWNTOWN', C(40, 120, 220), FONT.title, 0.08, 0.84, P.white, 2)
	return model
end
local function buildStages(ctx)
	for i = 1, STAGES do City.avenueStage(ctx, i) end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do
		local model = stageGate(gates, i)
		model:SetAttribute('WallId', 'HoodW' .. (V2.World or 2) .. 'Stage' .. i)
		model:SetAttribute('World', V2.World or 2)
		local board = model:FindFirstChild('GateWorldName', true)
		if board then board.Text = 'WORLD ' .. (V2.World or 2) end
	end
	City.hq(ctx)
end
