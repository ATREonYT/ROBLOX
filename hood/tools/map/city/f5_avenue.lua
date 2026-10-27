---------------------------------------------------------------------------------------------- the downtown avenue (World 2)
-- World 2's stages (runs after f2_stages; its buildStages is the one V2.Build calls). The cross-section is World 1's
-- (f_areas, P.street, in the city's colours from a2_city): the asphalt run |x| < 8.5 with white dashes, the stone
-- sidewalks to 16.5, the paved strip to the building fronts at 36. Each stage adds (z' = studs past its own gate):
--   blocks   (Oct 27 round 2, the owner: "not such high buildings ... make like pre downtown") two mid-rise blocks a side
--            (z' 0..28 and 28..56, fronts at |x| 36, back to 64): shops with awnings and signs, flats and small offices
--            over them, 3 storeys by the lobby, up to 5 on Stage 2; a one-storey shop row each side at z' 56..64 out to
--            |x| 22, framing the next gate the way World 1's end buildings do
--   street   solid white edge lines, a zebra crosswalk kerb to kerb at z' 13..19 (between the centre dashes) with a
--            traffic light before it, tall steel lamps
--   life     taxis in the lay-bys, a bus stop (and a bus on Stage 2), food trucks, planters with trimmed trees
-- Gates 1-3 are World 1's builder (f2's stageGate) with World 2's wall ids (HoodW2Stage<i>) and WORLD 2 on gate 1's
-- board; gate 3 stands shut in front of the office block that closes the avenue until the rest of the world is built.

-- One stage of the avenue: World 1's stage group with its hidden fight marker (District.base), then the city on it.
City.AvenueBlocks = {
	-- per stage: { kind, floors } for block A (z' 0..28) and block B (z' 28..56)
	{ { 'shop', 1 }, { 'flats', 2 } },
	{ { 'office', 3 }, { 'shop', 4 } },
}
function City.avenueStage(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local plan = City.AvenueBlocks[i] or City.AvenueBlocks[#City.AvenueBlocks]
	local cw0, cw1 = 13, 19 -- the crosswalk (z'), between the centre dashes at z' 7..11 and 23..27
	for _, s in { -1, 1 } do
		local street = s < 0 and 'E' or 'W'
		local function x(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		-- the blocks (this side's tones offset, so facing blocks differ)
		local xa, xb = x(FRONT, FRONT + DEPTH)
		City.block(d, xa, xb, top - 28, top, { kind = plan[1][1], floors = plan[1][2], tone = i * 3 + (s > 0 and 1 or 2), faces = { street, 'S' }, name = 'BlockA' })
		City.block(d, xa, xb, top - 56, top - 28, { kind = plan[2][1], floors = plan[2][2], tone = i * 3 + (s > 0 and 4 or 6), faces = { street }, name = 'BlockB' })
		local pa, pb = x(ST.open, FRONT + DEPTH)
		City.block(d, pa, pb, top - SLEN, top - ST.endZ, { kind = 'shop', floors = 0, tone = i * 2 + (s > 0 and 3 or 6), faces = { street, 'S' }, name = 'ShopRow' })
		-- the solid white edge line along the run, broken at the crosswalk
		for _, r in { { 0, cw0 - 0.5 }, { cw1 + 0.5, SLEN } } do
			decor(sbox(d, 'LaneEdge', V(s * 7.2, 0, top - r[2]), V(s * 7.7, 0.12, top - r[1]), City.line)).CastShadow = false
		end
		-- lamps on the sidewalk, their arms over the run
		for _, zp in { 9, 41 } do City.lamp(d, at(s * 15.4, zp), -s) end
	end
	-- the crosswalk, kerb to kerb (7 bars over the 17-stud run), a stop line before it, its traffic light
	District.zebra(d, V(-7.0, 0, top - (cw0 + cw1) / 2), 1.4, cw1 - cw0, V(7 / 3, 0, 0), 7)
	decor(sbox(d, 'StopLine', V(-7.1, 0, top - cw0 + 1.0), V(7.1, 0.12, top - cw0 + 1.6), City.line)).CastShadow = false
	local ls = i % 2 == 1 and 1 or -1
	District.trafficLight(d, at(ls * 10.6, cw0 - 2.5), -ls)
	-- the street's life, set per stage
	if i == 1 then
		City.busStop(d, CFrame.new(at(-20.2, 21)) * CFrame.Angles(0, -math.pi / 2, 0))
		City.taxi(d, CFrame.new(at(-19.6, 36)))
		City.taxi(d, CFrame.new(at(-19.6, 48)))
		City.foodTruck(d, CFrame.new(at(27.5, 20)) * CFrame.Angles(0, math.pi, 0), C(240, 96, 60), 'TACOS')
		City.taxi(d, CFrame.new(at(19.6, 44)))
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { 19.6, 32 }, { -27, 52 }, { 26, 52 } } do City.planter(d, at(p[1], p[2]), 800 + i * 10 + p[2]) end
	else
		City.foodTruck(d, CFrame.new(at(-27.5, 24)), C(60, 150, 240), 'ICE CREAM')
		City.taxi(d, CFrame.new(at(-19.6, 46)))
		City.bus(d, CFrame.new(at(19.8, 22)), C(40, 120, 220))
		City.busStop(d, CFrame.new(at(21.4, 44)) * CFrame.Angles(0, math.pi / 2, 0))
		City.foodTruck(d, CFrame.new(at(29, 46)) * CFrame.Angles(0, math.pi, 0), C(250, 180, 40), 'BURGERS')
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { -19.6, 34 }, { -27, 52 } } do City.planter(d, at(p[1], p[2]), 800 + i * 10 + p[2]) end
	end
	return d
end
-- The office block closing the avenue behind the last gate (until the rest of the world is built): wide, 5 storeys,
-- its lobby glass behind the gate and DOWNTOWN on its roof, facing the avenue.
function City.hq(ctx)
	local z = gateZ(STAGES + 1)
	-- (the ground behind it, beside the f_areas paving under the old boss yard's place, |x| 36..64)
	for _, s in { -1, 1 } do sbox(ctx, 'CityBase', V(s * FRONT, -1, BOSS_END + 4), V(s * (FRONT + DEPTH), 0.95, z - 52), City.walk:Lerp(City.road, 0.25)) end
	local t, model = City.block(ctx:group('Downtown'), -64, 64, z - 52, z - 1.6, { kind = 'office', floors = 4, color = C(240, 214, 170), trim = P.white, tone = 2, faces = { 'S' }, name = 'HQ' })
	local top = 6 + 4 * 5
	local plate = t:box('HQSign', V(-22, top + 1, z - 3.2), V(22, top + 6.5, z - 2.8), C(40, 120, 220), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Back, 10), 'Name', 'DOWNTOWN', P.white, FONT.title, 0.08, 0.84, C(10, 40, 90), 3)
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
