---------------------------------------------------------------------------------------------- the finale (brief 29, P3b)
-- Stage 16 is the Harbor Crew's warehouse (the user: "make it a well built warehouse map that doesn't have any boxing
-- ring"; brief 30: "Warehouse, no extras", "its just a strong last enemy before the second world"): one big
-- corrugated-steel hall in World 1's kit (the Yards' depot blue, studded concrete, the hazard yellow), the stage gate in
-- its front wall. Inside: a clear fight floor (|x| <= 31, marked in yellow, a big anchor painted in the middle), container
-- stacks and pallet racks along the walls, a parked forklift, the CHAMP BAY (the Champ Ring's lane: its TrainingZone, no
-- ring) in the near right corner, catwalks along both walls and across the back, an overhead crane with its hook,
-- hanging lamps under the roof trusses, skylights, and the loading dock along the back wall: two roller doors and,
-- between them, the WORLD 2 door (a stage gate's frame and haze, tagged HoodWorldDoor: HoodClient/Stages writes "Defeat
-- <name>" on it while the Harbor crew stands, flashes it white when the last one falls, then "WORLD 2 / Coming soon!").
-- The Harbor crew waits in front of it like every wave; the stage's two cash pads stand before it like every gate's.
-- (brief 30: no BOSS pad, ring, perch or reserve doors any more.) The props are BoxKit models (Shared/Models/PropModels).
--   Finale.yard(ctx)           the warehouse, stage 16 (f2_stages' bossYard calls it)
--   Finale.arena(ctx)          the World Boss pier: a self-contained arena behind the lobby, outside the boundary wall
--                              (Shared/WorldBossRules.Arena; reached by its JOIN, left by its Lobby pad)
--   Finale.board(ctx)          the World Boss countdown board (V2.Lobby.Slots.WorldBossBoard when the lobby has one)
local Finale = {}
V2.Finale = Finale
Finale.W, Finale.Wall = 47, 1.5 -- the hall's inner half-width and its walls' thickness
Finale.EH, Finale.RH = 28, 36 -- eaves and ridge
Finale.Walk = 18.5 -- the catwalks' deck
Finale.Perch = 82 -- z' (past the gate) of the cross catwalk
Finale.Doors = { -24, 24 } -- the dock's roller doors (x); the World 2 door between them (brief 30)
Finale.World = { Inner = 9.5, Outer = 13.5, H = 15 } -- the World 2 door's opening and frame (a stage gate's, smaller)
Finale.Steel = C(84, 106, 150) -- the hall (the Yards' depot blue, deeper)
Finale.Dark = C(46, 50, 60)
Finale.Hazard = C(250, 204, 40)
Finale.Floor = C(176, 178, 184)

-- A BoxKit prop (Shared/Models/PropModels) moved to cf in the ctx's frame, anchored; solid = which parts collide.
function Finale.prop(c, id, cf, scale, solid)
	local props = Armory.optional('PropModels')
	local ok, m = false, nil
	if props and props.build then ok, m = pcall(props.build, id, scale or 1) end
	if not ok or not m or not m.PrimaryPart then return nil end
	local delta = c:world(cf) * m.PrimaryPart.CFrame:Inverse()
	for _, p in m:GetDescendants() do
		if p:IsA('BasePart') then
			p.CFrame = delta * p.CFrame
			p.Anchored, p.CanTouch, p.CanQuery = true, false, false
			p.CanCollide = solid == true
		end
	end
	m.Parent = c.parent
	return m
end

-- Hazard stripes: n alternating yellow/black bars on the floor across a..b (x), at z (one bar deep d).
function Finale.stripes(c, name, x0, x1, z, d, y)
	local n = math.max(2, math.floor((x1 - x0) / 1.6))
	local w = (x1 - x0) / n
	for k = 0, n - 1 do
		local p = decor(c:box(name, V(x0 + k * w, y, z - d / 2), V(x0 + (k + 1) * w, y + 0.04, z + d / 2), k % 2 == 0 and Finale.Hazard or Finale.Dark, M.SmoothPlastic))
		p.CastShadow = false
	end
end

function Finale.yard(ctx)
	local T, E, W, EH, RH = BOSS_TOP, BOSS_END, Finale.W, Finale.EH, Finale.RH
	local function zp(d) return T - d end
	local b, model = ctx:group('BossYard')
	model:SetAttribute('Warehouse', true)
	local steel, dark, wallT = Finale.Steel, Finale.Dark, Finale.Wall
	local rib = steel:Lerp(P.white, 0.14)
	-- the floor (studded concrete), the annexes either side (x 48.5..64: the lots the street's buildings used to fill)
	sbox(b, 'HallFloor', V(-W - wallT, -0.4, E - wallT), V(W + wallT, 0.08, T - 0.2), Finale.Floor)
	for _, s in { -1, 1 } do
		sbox(b, 'Annex', V(s * (W + wallT), -0.4, E - wallT), V(s * 64, 14, T - 3), steel:Lerp(P.black, 0.18))
		sbox(b, 'AnnexRoof', V(s * (W + wallT - 0.3), 14, E - wallT - 0.3), V(s * 64.3, 14.8, T - 2.7), dark)
		for k = 1, 3 do sbox(b, 'RoofVent', V(s * 54, 14.8, zp(14 + k * 22)), V(s * 58, 16.6, zp(18 + k * 22)), C(150, 156, 166), true) end
	end
	-- the walls: the sides (a dark plinth, the panel, a clerestory glass band, ribs inside), the back
	local walls = b:group('Walls')
	for _, s in { -1, 1 } do
		local x0, x1 = s * W, s * (W + wallT)
		sbox(walls, 'Plinth', V(x0 - s * 0.3, 0, E), V(x1, 2.6, T - 1.7), dark)
		walls:box('WallLow', V(x0, 2.6, E), V(x1, 20, T - 1.7), steel, M.Plastic)
		walls:box('Clerestory', V(x0 + s * 0.2, 20, E), V(x1, 23.4, T - 1.7), P.st.glassA, M.Glass).Transparency = 0.35
		walls:box('WallHigh', V(x0, 23.4, E), V(x1, EH, T - 1.7), steel, M.Plastic)
		for z = T - 4, E + 2, -3.2 do decor(walls:box('WallRib', V(x0 - s * 0.3, 2.6, z - 0.4), V(x0, 20, z + 0.4), rib, M.Plastic)) end
	end
	sbox(walls, 'BackPlinth', V(-W - wallT, 0, E - wallT), V(W + wallT, 2.6, E + 0.3), dark)
	walls:box('BackWall', V(-W - wallT, 2.6, E - wallT), V(W + wallT, EH, E), steel, M.Plastic)
	-- the front: the façade either side of the gate, the header over it, the gable
	local front = b:group('Front')
	local zf0, zf1 = T - 0.2, T - 1.7
	for _, s in { -1, 1 } do
		sbox(front, 'Facade', V(s * 22.3, 0, zf1), V(s * (W + wallT), EH, zf0), steel)
		for x = 24, W, 3.2 do decor(front:box('FacadeRib', V(s * x - 0.4, 2.6, zf0), V(s * x + 0.4, EH - 1, zf0 + 0.3), rib, M.Plastic)) end
		front:wedge('Gable', V(wallT, RH - EH, W + wallT), CFrame.new(s * (W + wallT) / 2, EH + (RH - EH) / 2, (zf0 + zf1) / 2) * CFrame.Angles(0, -s * math.pi / 2, 0), steel, M.Plastic)
	end
	sbox(front, 'Header', V(-22.3, 21.6, zf1), V(22.3, EH, zf0), steel)
	local band = sbox(front, 'SignBand', V(-19, 22.4, zf0), V(19, 27.4, zf0 + 0.5), C(24, 32, 56))
	local g = surface(band, Enum.NormalId.Back, 16)
	line(g, 'Title', 'HARBOR CREW', Finale.Hazard, FONT.title, 0.06, 0.62, P.black, 3)
	line(g, 'Sub', 'WAREHOUSE  16', P.white, FONT.title, 0.68, 0.26, P.black, 2)
	for _, x in { -21, 21 } do
		sbox(front, 'FacadeLamp', V(x - 0.8, 19.6, zf0), V(x + 0.8, 20.1, zf0 + 1.4), dark, true)
		decor(front:box('FacadeLampGlow', V(x - 0.6, 19.5, zf0 + 0.2), V(x + 0.6, 19.6, zf0 + 1.2), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	-- the roof: two slopes in bays (corrugated, with a skylight every other bay), trusses, columns
	local roof = b:group('Roof')
	local run, rise = W + wallT + 0.6, RH - EH
	local slope = math.sqrt(run * run + rise * rise)
	local a = math.atan2(rise, run)
	local bays = 8
	local L = (T - 0.2) - (E - wallT)
	for _, s in { -1, 1 } do
		for k = 0, bays - 1 do
			local z0 = T - 0.2 - k * L / bays
			local glass = k % 2 == 1
			local p = roof:part(glass and 'Skylight' or 'RoofPanel', V(slope, 0.8, L / bays), CFrame.new(s * run / 2, EH + rise / 2 + 0.4, z0 - L / bays / 2) * CFrame.Angles(0, 0, -s * a), glass and P.st.glassA or steel:Lerp(P.black, 0.12), glass and M.Glass or M.Plastic)
			if glass then p.Transparency = 0.45 end
		end
	end
	roof:box('Ridge', V(-0.8, RH, E - wallT), V(0.8, RH + 0.9, T - 0.2), dark, M.Plastic)
	for d = 6, 90, 12 do
		local z = zp(d)
		decor(roof:bar('TrussChord', V(-W, EH - 0.4, z), V(W, EH - 0.4, z), 0.7, dark, M.Metal))
		for _, s in { -1, 1 } do
			decor(roof:bar('TrussTop', V(s * W, EH - 0.4, z), V(0, RH - 0.6, z), 0.7, dark, M.Metal))
			decor(roof:bar('TrussWeb', V(s * W / 2, EH - 0.4, z), V(s * W / 2, EH + rise / 2 - 0.6, z), 0.45, dark, M.Metal))
			decor(roof:bar('TrussWeb', V(s * W / 2, EH - 0.4, z), V(0, RH - 0.6, z), 0.45, dark, M.Metal))
			roof:box('Column', V(s * (W - 0.9), 0, z - 0.45), V(s * W, EH, z + 0.45), dark, M.Metal)
		end
		decor(roof:bar('TrussPost', V(0, EH - 0.4, z), V(0, RH - 0.6, z), 0.5, dark, M.Metal))
	end
	-- the floor: yellow walkway lines along its sides and across the near end. (brief 30: the big painted anchor in the
	-- middle is gone: a centrepiece on an empty floor read as a boss arena; the floor is a warehouse's, its props stand
	-- in clusters along the walls, bible S6.) Pallet bays: yellow corner marks on the floor under the wall clusters.
	local fl = b:group('FightFloor')
	for _, s in { -1, 1 } do decor(fl:box('FloorLine', V(s * 31 - 0.25, 0.08, zp(94)), V(s * 31 + 0.25, 0.12, zp(4)), Finale.Hazard, M.SmoothPlastic)).CastShadow = false end
	decor(fl:box('FloorLine', V(-31, 0.08, zp(4.25)), V(31, 0.12, zp(3.75)), Finale.Hazard, M.SmoothPlastic)).CastShadow = false
	for _, bay in { { -1, 81, 91 }, { 1, 81, 91 }, { -1, 40, 46 } } do
		local s, z0, z1 = bay[1], bay[2], bay[3]
		for _, zc in { z0, z1 } do
			decor(fl:box('BayMark', V(s * 22.5 - 0.2, 0.08, zp(zc) - 0.2), V(s * 22.5 + 0.2, 0.12, zp(zc) + 0.2 + (zc == z0 and -2 or 2)), Finale.Hazard, M.SmoothPlastic)).CastShadow = false
			decor(fl:box('BayMark', V(s * 22.5 - 0.2, 0.08, zp(zc) - 0.2), V(s * 22.5 + s * 2.4, 0.12, zp(zc) + 0.2), Finale.Hazard, M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the loading dock: three roller doors in the back wall, bumpers, a dock light and number over each, stripes
	local dock = b:group('Dock')
	for k, x in Finale.Doors do
		local d, dm = dock:group('DockDoor_' .. k)
		dm:SetAttribute('Dock', k)
		sbox(d, 'DoorFrame', V(x - 6.8, 0, E), V(x + 6.8, 14.4, E + 0.6), dark)
		local door = d:box('RollerDoor', V(x - 6, 0.08, E + 0.6), V(x + 6, 13.6, E + 0.9), C(178, 184, 194), M.Plastic)
		door:SetAttribute('Rest', door.CFrame)
		for y = 1.2, 13, 1.2 do decor(d:box('DoorSlat', V(x - 6, y, E + 0.9), V(x + 6, y + 0.25, E + 1.0), C(130, 136, 148), M.Plastic)) end
		for _, s in { -1, 1 } do sbox(d, 'Bumper', V(x + s * 7 - 0.7, 1.2, E + 0.6), V(x + s * 7 + 0.7, 3.4, E + 1.6), C(30, 32, 36), true) end
		local lamp = sbox(d, 'DockLamp', V(x - 1.2, 15, E), V(x + 1.2, 15.6, E + 1.2), dark, true)
		local glow = decor(d:box('DockLampGlow', V(x - 1, 14.9, E + 0.2), V(x + 1, 15, E + 1), C(255, 170, 60), M.Neon))
		glow.CastShadow = false
		local sign = d:box('DockSign', V(x - 2.4, 16.2, E), V(x + 2.4, 18.4, E + 0.3), Finale.Hazard, M.SmoothPlastic)
		line(surface(sign, Enum.NormalId.Back, 24), 'Sign', 'DOCK ' .. (k == 1 and 1 or 3), P.black, FONT.title, 0.1, 0.8)
		Finale.stripes(d, 'DockStripe', x - 6, x + 6, zp(92.5), 3, 0.08)
		local _ = lamp
	end
	-- along the left wall: container stacks (two high, one high) and a forklift, pallets and drums by the door
	local left = b:group('LeftSide')
	local colors = { C(196, 52, 42), C(44, 96, 186), C(46, 150, 90), C(232, 130, 40) }
	for k, st in ipairs({ { 30, 2 }, { 52, 1 }, { 74, 2 } }) do
		for lvl = 0, st[2] - 1 do District.container(left, CFrame.new(-43, 0.08 + lvl * 8.7, zp(st[1])) * CFrame.Angles(0, math.rad((k + lvl) % 2 * 2 - 1), 0), colors[(k + lvl) % #colors + 1]) end
	end
	Finale.prop(left, 'Forklift', CFrame.new(-38.5, 0.08, zp(13)) * CFrame.Angles(0, math.rad(-62), 0), 1, true)
	Finale.prop(left, 'PalletStack', CFrame.new(-44, 0.08, zp(8)) * CFrame.Angles(0, 0.1, 0), 1, true)
	Finale.prop(left, 'PalletStack', CFrame.new(-44, 0.08, zp(18)) * CFrame.Angles(0, -0.12, 0), 1, true)
	for k, dp in ipairs({ { -35, 88 }, { -36.6, 90 }, { -34.4, 91.4 } }) do
		local drum = left:post('Drum', 1.1, 3.4, V(dp[1], 0.08, zp(dp[2])), ({ C(40, 90, 200), C(200, 50, 40), C(40, 90, 200) })[k], M.Plastic)
		studs(drum)
	end
	-- along the right wall: pallet racks with pallets and crates; a cargo container by the dock
	local right = b:group('RightSide')
	for _, rz in { 34, 58 } do
		local r = right:at(CFrame.new(43.5, 0.08, zp(rz))):group('Rack')
		for _, x in { -2.5, 2.5 } do for _, z in { -9.5, 0, 9.5 } do r:box('Upright', V(x - 0.3, 0, z - 0.3), V(x + 0.3, 17, z + 0.3), C(40, 96, 186), M.Metal) end end
		for _, y in { 5.8, 11.6 } do for _, x in { -2.5, 2.5 } do r:box('Beam', V(x - 0.3, y - 0.5, -9.8), V(x + 0.3, y, 9.8), C(250, 140, 40), M.Metal) end end
		for _, y in { 5.8, 11.6 } do decor(r:box('Deck', V(-2.5, y - 0.3, -9.6), V(2.5, y - 0.1, 9.6), C(150, 156, 166), M.DiamondPlate)) end
		Finale.prop(r, 'PalletStack', CFrame.new(0, 0, -4.8) * CFrame.Angles(0, math.pi / 2, 0), 1, true)
		Finale.prop(r, 'PalletStack', CFrame.new(0, 11.5, 4.8) * CFrame.Angles(0, math.pi / 2, 0), 1)
		crate(r, CFrame.new(0, 7.1, -4.6) * CFrame.Angles(0, 0.2, 0), 2.6)
		crate(r, CFrame.new(0, 7.1, 4.4), 2.4)
		crate(r, CFrame.new(0, 1.3, 5), 2.6)
	end
	District.container(right, CFrame.new(43, 0.08, zp(80)) * CFrame.Angles(0, math.rad(1), 0), colors[3])
	-- the CHAMP BAY (the Champ Ring's lane, brief 29: no boxing ring): a steel deck in the near right corner with the
	-- lane's TrainingZone, a hazard edge, a big target at the wall and the bay's sign
	local ring = SKINS.StationById.Ring
	local bay, bayModel = b:at(CFrame.new(40, 0.08, zp(14))):group('Training_' .. ring.Id)
	sbox(bay, 'BayDeck', V(-7, 0, -8), V(7, 1, 8), C(70, 74, 90))
	Finale.stripes(bay, 'BayEdge', -7, 7, 8.4, 0.8, 0.0)
	local zone = bay:box('TrainingZone', V(-5, 1, -6), V(5, 1.25, 6), C(236, 238, 244), M.Fabric)
	zone.Name = 'TrainingZone'
	local target = bay:at(CFrame.new(6.4, 1, 0)):group('Equipment')
	target:box('TargetStand', V(-0.3, 0, -0.3), V(0.3, 5, 0.3), dark, M.Metal)
	for k, ring2 in ipairs({ { 7, C(232, 48, 52) }, { 5, P.white }, { 3, C(232, 48, 52) }, { 1.2, Finale.Hazard } }) do
		decor(target:part('Target', V(0.2 + k * 0.05, ring2[1], ring2[1]), CFrame.new(-0.2 - k * 0.05, 7.4, 0), ring2[2], M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	local plate = bay:box('Nameplate', V(-6, 9.6, 7.2), V(6, 12.4, 7.6), C(24, 32, 56), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 24), 'Name', 'CHAMP BAY', Finale.Hazard, FONT.title, 0.1, 0.8, P.black, 3)
	for _, x in { -5.6, 5.6 } do bay:box('PlatePost', V(x - 0.25, 1, 7.25), V(x + 0.25, 9.6, 7.55), dark, M.Metal) end
	local vfx = Armory.optional('HoodVFX')
	if vfx then vfx.station(zone, 9, nil, V(10, 12, 12)) end
	local _ = bayModel
	-- catwalks: along both walls and across the back, railings, hangers, a ladder
	local cw = b:group('Catwalks')
	local y = Finale.Walk
	local plate2 = C(92, 98, 112)
	for _, s in { -1, 1 } do
		cw:box('Catwalk', V(s * 39.5, y - 0.5, zp(92)), V(s * W, y, zp(4)), plate2, M.DiamondPlate)
		for d = 4, 92, 8 do cw:box('RailPost', V(s * 39.5 - 0.15, y, zp(d) - 0.15), V(s * 39.5 + 0.15, y + 3.4, zp(d) + 0.15), Finale.Hazard, M.Metal) end
		for _, h in { 1.7, 3.4 } do decor(cw:bar('Rail', V(s * 39.5, y + h, zp(4)), V(s * 39.5, y + h, zp(80)), 0.25, Finale.Hazard, M.Metal)) end
		for d = 8, 88, 16 do decor(cw:bar('Bracket', V(s * W, y - 4, zp(d)), V(s * 40.5, y - 0.5, zp(d)), 0.4, dark, M.Metal)) end
	end
	local p0, p1 = zp(Finale.Perch - 2.2), zp(Finale.Perch + 2.2)
	cw:box('CrossWalk', V(-39.5, y - 0.5, p1), V(39.5, y, p0), plate2, M.DiamondPlate)
	decor(cw:box('CrossKick', V(-39.5, y - 1.3, p0 - 0.2), V(39.5, y - 0.5, p0), Finale.Hazard, M.Metal))
	for x = -36, 36, 8 do cw:box('RailPost', V(x - 0.15, y, p0 - 0.15), V(x + 0.15, y + 3.4, p0 + 0.15), Finale.Hazard, M.Metal) end
	decor(cw:bar('Rail', V(-39.5, y + 3.4, p0), V(39.5, y + 3.4, p0), 0.25, Finale.Hazard, M.Metal))
	for _, x in { -30, -12, 12, 30 } do for _, z in { p0, p1 } do decor(cw:bar('Hanger', V(x, y, z), V(x, EH - 0.4, z), 0.25, dark, M.Metal)) end end
	for _, s in { -1, 1 } do cw:box('LadderRail', V(-45.6 + s * 1, 0, zp(94.2)), V(-45.6 + s * 1 + 0.3, y + 3, zp(94.5)), Finale.Hazard, M.Metal) end
	for k = 1, math.floor(y / 1.4) do decor(cw:box('LadderRung', V(-46.6, k * 1.4 - 0.15, zp(94.3)), V(-44.3, k * 1.4 + 0.15, zp(94.4)), Finale.Hazard, M.Metal)) end
	-- the overhead crane: runways on the columns, a yellow bridge across, the trolley, its cable and hook
	local cr = b:group('Crane')
	for _, s in { -1, 1 } do cr:box('Runway', V(s * 44.6 - 0.6, 24, zp(92)), V(s * 44.6 + 0.6, 25.2, zp(4)), dark, M.Metal) end
	local bz = zp(30) -- (over the near end, the hook parked by the left wall: the fight floor's air stays clear)
	cr:box('Bridge', V(-45, 25.2, bz - 1), V(45, 27, bz + 1), Finale.Hazard, M.Metal)
	for x = -40, 40, 8 do decor(cr:box('BridgeStripe', V(x, 25.2, bz - 1.05), V(x + 2.4, 27, bz + 1.05), Finale.Dark, M.Metal)) end
	cr:box('Trolley', V(-36.5, 23.4, bz - 1.6), V(-31.5, 25.2, bz + 1.6), dark, M.Metal)
	decor(cr:part('Cable', V(5.4, 0.25, 0.25), CFrame.new(-34, 23.4 - 2.7, bz) * CFrame.Angles(0, 0, math.pi / 2), C(30, 32, 36), M.Metal, Enum.PartType.Cylinder))
	Finale.prop(cr, 'CraneHook', CFrame.new(-34, 18, bz), 1.4)
	-- the hanging lamps (a few of them really light the floor; the skylights do the rest)
	local lamps = b:group('Lamps')
	local n = 0
	for _, d in { 18, 42, 66 } do
		for _, x in { -18, 18 } do
			n += 1
			local m = Finale.prop(lamps, 'HangingLamp', CFrame.new(x, EH - 0.8, zp(d)), 1.6)
			local bulb = m and m:FindFirstChild('Bulb', true)
			if bulb and n % 2 == 1 then light(bulb, C(255, 232, 190), 1.4, 34) end
		end
	end
	-- (brief 30) the World 2 door between the dock's roller doors, and the stage's two cash pads before it (like every
	-- gate's: 3 studs off its line, magenta 10x Cash on the left, yellow Return on the right), clear of its pillars.
	-- The fight's pad marker stays, hidden (the map's fight list reads it; nothing shows on the floor).
	-- (brief 30, bible S6) the far end where the crew waits, dressed in tight clusters either side of the World 2 door,
	-- outside the pads and the crew's spots: drums, a pallet stack and a cone on the left; a cargo container, two
	-- crates and a barrier on the right (the floor between stays clear)
	local far = b:group('FarEnd')
	for k, dp in ipairs({ { -25.6, 86 }, { -27.4, 87.8 }, { -25.2, 89.4 } }) do Arena.prop(far, 'Barrel', V(dp[1], 0.08 + 1.5, zp(dp[2])), k * 0.9, 1, true) end
	Arena.prop(far, 'PalletStack', V(-31.4, 0.08, zp(84.6)), 0.18, 1, true)
	Arena.prop(far, 'TrafficCone', V(-22.6, 0.08, zp(82.4)), 0.4, 1)
	Arena.prop(far, 'DropContainer', V(31.6, 0.08 + 3.75, zp(86.6)), math.rad(4), 1, true)
	Arena.prop(far, 'Crate', V(25.8, 0.08 + 1.3, zp(89.6)), 0.3, 1, true)
	Arena.prop(far, 'Crate', V(25.6, 0.08 + 3.9, zp(89.4)), -0.2, 1, true)
	Arena.prop(far, 'RoadBarrier', V(23.6, 0.08, zp(83.2)), 0.25, 1, true)
	Finale.worldDoor(b, E + 0.9)
	GATE.pads(b, 16, Finale.World.Outer + 4, E + 0.9 + 3 + 5.5, 0.14, 5.6, 11)
	fightPad(b, 16, V(0, 0.08, BOSS_END + 22), P.padRed, 6, 14, nil, true)
	return b
end

-- (brief 30) The World 2 door: a stage gate's studded pillars and hazard beam (GATE.frame), its pink haze and its lock
-- (GATE.hazeWall, GATE.lock) in the back wall, and its sign (a board in the opening, like GATE.sign): the white shut line
-- "Defeat <name>" (HoodClient/Stages writes the Harbor crew's strongest), then "WORLD 2" / "Coming soon!". World 2 isn't
-- built, so it stays shut: its lock stays on. Tagged HoodWorldDoor (attributes Stage = the stage whose crew it waits on,
-- LineZ).
function Finale.worldDoor(ctx, z)
	local W = Finale.World
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('WorldDoor')
	model:AddTag('HoodWorldDoor')
	model:SetAttribute('Stage', STAGES + 2) -- (the gate after Stage 16, the warehouse: STAGES counts the 15 street stages)
	model:SetAttribute('LineZ', z)
	GATE.frame(g, W.Inner, W.Outer, W.H)
	GATE.hazeWall(g, W.Inner, W.H, false)
	GATE.lock(g, W.Inner)
	local signW, signH = 2 * W.Inner - 1, 7.4
	local board = ghost(g:part('SignBoard', V(signW, signH, 0.1), CFrame.new(0, 6.6 + signH / 2, GATE.signZ), P.white))
	board.CastShadow = false
	local gui = surface(board, Enum.NormalId.Back, GATE.signPPS)
	gui.Name = 'GateSign'
	gui.AlwaysOnTop = false
	local function put(name, text, y, h, color, ink, share)
		local px = signH * GATE.signPPS * h
		local t = line(gui, name, text, color, GATE.font, y, h, ink, math.max(3, math.floor(px * share + 0.5)))
		t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
		t.TextWrapped = false
		t.ZIndex = 2
		return t
	end
	local title = put('Title', 'WORLD 2', 0, 0.5, GATE.title, GATE.titleInk, 0.075)
	local grad = Instance.new('UIGradient')
	grad.Color, grad.Rotation = GATE.titleShade, 90
	grad.Parent = title
	put('Sub', 'Coming soon!', 0.52, 0.3, GATE.sub, GATE.subInk, 0.1)
	local status = put('Status', 'Defeat the crew first', 0.3, 0.26, GATE.status, GATE.statusInk, 0.1)
	status.Position, status.Size = UDim2.fromScale(0.02, 0.3), UDim2.fromScale(0.96, 0.26)
	title.Visible, gui:FindFirstChild('Sub').Visible = false, false
	return g
end

---------------------------------------------------------------------------------------------- the world boss
-- The World Boss pier (Shared/WorldBossRules.Arena): a studded concrete deck over harbour water, behind the lobby and
-- outside the boundary wall, so nothing of the lobby or the stages moves for it. Containers at the corners, floodlights,
-- a WORLD BOSS banner, the spot players land on (WorldBossSpawn) and a Lobby pad home. Invisible walls keep everyone on
-- the deck.
function Finale.arena(ctx)
	local ok, Rules = pcall(function() return require(ReplicatedStorage.Shared.WorldBossRules) end)
	local A = ok and Rules.Arena or { X = 0, Z = 330, Half = 34 }
	local a, model = ctx:at(CFrame.new(A.X, 0, A.Z)):group('WorldBossArena')
	model:SetAttribute('WorldBoss', true)
	local H = A.Half
	local water = decor(a:box('Water', V(-H - 60, -3, -H - 60), V(H + 60, -1.2, H + 60), C(40, 116, 196), M.SmoothPlastic))
	water.Transparency = 0.1
	sbox(a, 'Deck', V(-H - 4, -1.6, -H - 4), V(H + 4, 0.08, H + 4), Finale.Floor)
	for _, s in { -1, 1 } do
		decor(a:box('DeckEdge', V(-H - 4, 0.08, s * (H + 3.6) - 0.4), V(H + 4, 0.14, s * (H + 3.6) + 0.4), Finale.Hazard, M.SmoothPlastic))
		decor(a:box('DeckEdge', V(s * (H + 3.6) - 0.4, 0.08, -H - 4), V(s * (H + 3.6) + 0.4, 0.14, H + 4), Finale.Hazard, M.SmoothPlastic))
		ghost(a:box('Edge', V(-H - 4, 0, s * (H + 4)), V(H + 4, 14, s * (H + 4) + s * 1), P.white, M.SmoothPlastic))
		ghost(a:box('Edge', V(s * (H + 4), 0, -H - 4), V(s * (H + 4) + s * 1, 14, H + 4), P.white, M.SmoothPlastic))
	end
	-- (brief 30: the reference's detail level, bible 2.4) timber fenders down the deck's sides, mooring bollards (BoxKit)
	-- along the edges with rope coils by some, dock lamps, crate and drum clusters by the containers, the dockside crane
	-- on the west edge with its boom over the water, and a tugboat moored off the east side
	for _, s in { -1, 1 } do
		sbox(a, 'Fender', V(-H - 4.6, -2.4, s * (H + 4) - 0.6), V(H + 4.6, 0.0, s * (H + 4) + 0.6), C(110, 74, 44))
		sbox(a, 'Fender', V(s * (H + 4) - 0.6, -2.4, -H - 4.6), V(s * (H + 4) + 0.6, 0.0, H + 4.6), C(110, 74, 44))
	end
	for x = -H, H, 12 do
		for _, s in { -1, 1 } do
			for _, pos in { V(x, 0.08, s * (H + 2.6)), V(s * (H + 2.6), 0.08, x) } do
				if not Arena.prop(a, 'Bollard', pos, 0, 1, true) then a:post('Bollard', 0.7, 1.6, pos, Finale.Dark, M.Metal) end
			end
		end
	end
	for k, rc in ipairs({ { -H + 1.6, H + 2.4 }, { H - 1.4, -H - 2.2 }, { H + 2.4, 12 }, { -H - 2.2, -24 } }) do Arena.prop(a, 'RopeCoil', V(rc[1], 0.08, rc[2]), k * 1.3, 1) end
	for _, lp in { { 1, -18 }, { 1, 18 }, { -1, 24 } } do Arena.prop(a, 'DockLamp', V(lp[1] * (H + 1.4), 0.08, lp[2]), lp[1] * math.pi / 2, 1, true) end
	Arena.prop(a, 'DockCrane', V(-H + 10, 0.08, -2), math.pi / 2, 1, true)
	Arena.prop(a, 'Tugboat', V(H + 17, -2.1, -6), math.rad(4), 1, true)
	for k, cr in ipairs({ { 22.6, 27.2, 0 }, { 25.4, 26.4, 0 }, { 23.8, 27, 2.6 } }) do Arena.prop(a, 'Crate', V(cr[1], 0.08 + 1.3 + cr[3], cr[2]), k * 0.35, 1, true) end
	Arena.prop(a, 'PalletStack', V(-24.2, 0.08, 27.4), 0.2, 1, true)
	Arena.prop(a, 'PalletStack', V(22.6, 0.08, -27.6), -0.15, 1, true)
	for k, dp in ipairs({ { 25.6, -24.4 }, { 27.2, -22.8 }, { 24.8, -22.4 } }) do Arena.prop(a, 'Barrel', V(dp[1], 0.08 + 1.5, dp[2]), k, 1, true) end
	local colors = { C(196, 52, 42), C(44, 96, 186), C(46, 150, 90), C(232, 130, 40) }
	for k, cn in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		District.container(a, CFrame.new(cn[1] * (H - 2), 0.08, cn[2] * (H - 12)) * CFrame.Angles(0, 0, 0), colors[k])
		District.floodlight(a, CFrame.lookAt(V(cn[1] * (H + 1), 0.08, cn[2] * (H + 1)), V(0, 0, 0)), 24)
	end
	-- the anchor painted in the middle, like the warehouse's
	decor(a:box('Mark', V(-1, 0.08, -9), V(1, 0.12, 9), C(226, 230, 238), M.SmoothPlastic))
	decor(a:part('MarkRing', V(0.04, 26, 26), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), C(232, 16, 28), M.SmoothPlastic, Enum.PartType.Cylinder)).Transparency = 0.6
	banner(a, 'WORLD BOSS', V(0, 16, -H - 2), C(216, 72, 40), 30)
	-- where JOIN puts you (the near side, facing in) and the pad back to the lobby
	local spawn = ghost(a:box('WorldBossSpawn', V(-3, 0.1, H - 6), V(3, 0.3, H), P.white, M.SmoothPlastic))
	spawn:SetAttribute('Spawn', true)
	teleportPad(a, 'WorldBossExit', 12, H - 2, C(255, 214, 56), 'Lobby', 'Lobby', { title = 'LOBBY', sub = 'Back to the hall' })
	-- a board on the pier too (the time left in the fight, the next one's countdown), facing the landing spot
	Finale.board(a, CFrame.new(-20, 9, -H + 1) * CFrame.Angles(0, math.pi, 0))
	return a
end

-- The countdown board (Shared/WorldBossRules; HoodClient/WorldBoss writes its lines): a framed dark board with WORLD
-- BOSS, the boss's name, NEXT IN m:ss / FIGHT NOW! and a line on JOIN. Tagged HoodWorldBossBoard.
function Finale.board(ctx, at)
	local slots = V2.Lobby and V2.Lobby.Slots
	-- (P3 owns the lobby: a WorldBossBoard slot wins; else the hall's front wall, outside, by the door to the street)
	local cf = at or slots and slots.WorldBossBoard or CFrame.new(-30, 9, 4.4)
	local c, model = ctx:at(cf):group('WorldBossBoard')
	model:AddTag('HoodWorldBossBoard')
	c:box('BoardFrame', V(-9, -5, -0.6), V(9, 5, 0), Finale.Dark, M.Metal)
	local head = c:box('BoardHeader', V(-9, 3, -0.8), V(9, 5.6, -0.4), C(216, 72, 40), M.SmoothPlastic)
	local face = c:box('Board', V(-8.4, -4.4, -0.7), V(8.4, 2.8, -0.5), C(20, 22, 34), M.SmoothPlastic)
	face.Name = 'Board'
	line(surface(head, Enum.NormalId.Front, 20), 'Title', 'WORLD BOSS', P.white, FONT.title, 0.08, 0.84, P.black, 3)
	local g = surface(face, Enum.NormalId.Front, 24)
	g.Name = 'Lines'
	line(g, 'Name', 'GIANT BOSS', C(248, 232, 112), FONT.title, 0.04, 0.26, P.black, 3)
	line(g, 'Time', 'NEXT IN 0:00', P.white, FONT.title, 0.34, 0.36, P.black, 3)
	line(g, 'Hint', 'Press JOIN at the top when it starts!', C(69, 230, 255), FONT.title, 0.76, 0.18, P.black, 2)
	return c
end
