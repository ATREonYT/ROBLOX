---------------------------------------------------------------------------------------------- the downtown avenue (World 2)
-- World 2's stages (runs after f2_stages and f3_waves; its buildStages is the one V2.Build calls). (Oct 27 round 3, the
-- owner: "make the buildings taller, make it the size of the first world, and then make the look in general way
-- better") World 1's track: 15 stages of 64 studs, gate 16, the boss yard (here the rooftop, Stage 16: The CEO's crew).
-- The cross-section is World 1's (f_areas, P.street, in the city's colours from a2_city): the asphalt run |x| < 8.5 with
-- white dashes, the stone sidewalks to 16.5, the paved strip to the tower fronts at 36. Each stage adds (z' = studs
-- past its own gate):
--   towers   two highrises a side (z' 0..28 and 28..56, fronts at |x| 36, back to 64; City.highrise): a shop podium
--            with awnings and signs on the street, glass or warm stone above, 45 high by the lobby and taller every
--            stage, up to ~140 by Stage 15; a one-storey shop row each side at z' 56..64 out to |x| 22, framing the next
--            gate the way World 1's end buildings do
--   street   solid white edge lines, a zebra crosswalk kerb to kerb at z' 13..19 with a stop line and a tall signal
--            (its lights high over the road, out of the camera's way), steel lamps
--   district three stages each (the owner's Oct 27 mockup; props in city/f4_districts.lua): City Streets (red brick
--            and grey towers, lanterns, a bus stop, taxis, food trucks), Modern Plaza (glass, light tiles, a fountain),
--            Construction Zone (sand, steel frames with scaffolds, a crane, barriers), Transit Area (the elevated line,
--            the station and its escalator, a train; the fenced street court on the right, where EnemyRules.Courts has
--            the crew), Luxury District (dark glass with pink neon, palms, pink lines, a sky bridge, the BOSS gateway)
-- Past gate 16: the rooftop (City.rooftop), the CEO tower behind it. Round it all: the side streets and two more rows
-- of towers either side, taller up the track (City.skylineFar). World 1's hood edges (its grass lots, low wall and ring
-- road, f_areas) give way to the city's paved base (the buildGround wrapper below).

-- The city's extra shop words (the podiums' signs).
for _, w in { 'COFFEE', 'DELI', 'SUSHI', 'GYM', 'HOTEL', 'PHONES', 'SNEAKERS', 'ARCADE', 'JUICE', 'BAGELS', 'NOODLES', 'SALON' } do table.insert(City.Words, w) end

-- A tall signal at pos (on the sidewalk's back edge): a steel pole, a mast arm reaching `dir` (+1 / -1 in x) over the
-- road, two yellow three-lamp heads hanging from it at 15-19 (over a player's head and camera), facing +Z (the way you
-- come), the red lit.
function City.signal(c, pos, dir)
	local t = c:at(CFrame.new(pos)):group('Signal')
	sbox(t, 'SignalBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), City.steelDark)
	t:box('SignalPole', V(-0.55, 1.2, -0.55), V(0.55, 21, 0.55), City.steel, M.SmoothPlastic)
	decor(t:box('SignalArm', V(math.min(0, dir * 13), 20.2, -0.35), V(math.max(0, dir * 13), 20.9, 0.35), City.steel, M.SmoothPlastic))
	for _, hx in { dir * 5.5, dir * 11.5 } do
		decor(t:box('SignalHanger', V(hx - 0.15, 19, -0.15), V(hx + 0.15, 20.2, 0.15), City.steelDark, M.SmoothPlastic))
		decor(t:box('SignalHead', V(hx - 0.9, 14.6, -0.6), V(hx + 0.9, 19, 0.6), City.yellow, M.SmoothPlastic))
		for k, c3 in { C(255, 60, 50), C(96, 84, 50), C(50, 76, 56) } do
			local y = 19 - k * 1.42
			decor(t:box('SignalLamp', V(hx - 0.55, y + 0.1, 0.6), V(hx + 0.55, y + 1.2, 0.72), c3, k == 1 and M.Neon or M.SmoothPlastic)).CastShadow = false
			decor(t:box('SignalHood', V(hx - 0.65, y + 1.2, 0.6), V(hx + 0.65, y + 1.38, 1.15), C(30, 32, 38), M.SmoothPlastic)).CastShadow = false
		end
	end
	return t
end
-- A cinema marquee on face f of a podium (City.face): a deep yellow canopy over the doors with a white sign band on its
-- three sides (the word on the front), a row of warm bulbs under its lip (steady, no flashing), a tall blade sign above.
function City.marquee(c, f, x0, x1, z0, z1, word)
	local box, u0, u1 = City.face(c, f, x0, x1, z0, z1)
	local m, w = (u0 + u1) / 2, math.min(9, (u1 - u0) / 2 - 1)
	local function d(p) decor(p).CastShadow = false return p end
	d(box('CinemaDoors', m - w + 1, m + w - 1, 0.9, 5.2, 0, 0.14, City.doorGlass))
	decor(box('Marquee', m - w, m + w, 5.4, 6.6, 0, 4.4, C(255, 196, 40)))
	local sign = box('MarqueeSign', m - w - 0.1, m + w + 0.1, 6.6, 9.4, 3.2, 4.5, P.white)
	decor(sign)
	local face = ({ S = Enum.NormalId.Back, N = Enum.NormalId.Front, E = Enum.NormalId.Right, W = Enum.NormalId.Left })[f]
	line(surface(sign, face, 12), 'Cinema', word, C(214, 40, 60), FONT.title, 0.06, 0.88, P.white, 2)
	for b = 0, math.floor(w * 2 / 1.6) do
		local u = m - w + 0.5 + b * 1.6
		if u < m + w - 0.3 then d(box('MarqueeBulb', u - 0.22, u + 0.22, 5.1, 5.4, 4.0, 4.4, C(255, 244, 200))).Material = M.Neon end
	end
end
-- A green news stand (cf: its centre on the ground, front -Z): a kiosk with a striped roof and racks of papers.
function City.newsStand(c, cf)
	local t = c:at(cf):group('NewsStand')
	sbox(t, 'KioskBody', V(-2.6, 0, -1.8), V(2.6, 4.4, 1.8), C(40, 150, 100))
	decor(t:box('KioskWindow', V(-2, 1.6, -1.9), V(2, 3.8, -1.8), City.doorGlass, M.SmoothPlastic)).CastShadow = false
	for k = 0, 5 do decor(t:box('KioskRoof', V(-3 + k, 4.4, -2.4), V(-2 + k, 5, 2.2), k % 2 == 0 and C(232, 64, 60) or P.white, M.SmoothPlastic)) end
	for k, col in { C(250, 250, 250), C(250, 210, 60), C(120, 190, 250) } do
		decor(t:box('Papers', V(-2.2 + (k - 1) * 1.5, 0.8, -2.3), V(-1.0 + (k - 1) * 1.5, 1.5, -1.8), col, M.SmoothPlastic))
	end
	return t
end

---------------------------------------------------------------------------------------------- the stages
-- The districts (three stages each; the owner's mockup, city/f4_districts.lua): the name, glass's share of the towers,
-- an extra height (studs).
City.Looks = {
	{ name = 'City Streets', glass = 0.25, lift = 0 },
	{ name = 'Modern Plaza', glass = 1.0, lift = 4 },
	{ name = 'Construction Zone', glass = 0.5, lift = 6 },
	{ name = 'Transit Area', glass = 0.6, lift = 8 },
	{ name = 'Luxury District', glass = 1.0, lift = 16 },
}
-- How tall a front tower stands: ~45 on Stage 1, ~6 more each stage (taller up the track), varied per tower, in whole
-- storeys over the podium.
function City.heightAt(i, slot, s)
	local L = City.Looks[lookOf(math.clamp(i, 1, STAGES))] or City.Looks[1]
	local v = ((i * 3 + slot * 2 + (s > 0 and 1 or 0)) % 4) * 5
	return 8.8 + math.floor((30 + i * 6 + v + L.lift) / 5) * 5
end
function City.kindAt(i, slot, s)
	local L = City.Looks[lookOf(math.clamp(i, 1, STAGES))] or City.Looks[1]
	local r = ((i * 7 + slot * 5 + (s > 0 and 3 or 0)) % 10) / 10
	return r < L.glass and 'glass' or 'stone'
end

-- The Park Courts' street court (stages 10-12, the right side; EnemyRules.Courts: the chain-link at x 22, z' 3..55, its
-- gateway at z' 23..27.5, the players' tunnel at x 26.6, z' 52 with its mouth toward the gate): a fenced court on a park
-- apron, hoops at both ends, floodlights, a mural wall at the back, trees outside the fence.
City.Courts = { { court = C(52, 112, 210), key = C(36, 86, 170) }, { court = C(226, 120, 52), key = C(196, 92, 40) }, { court = C(40, 160, 110), key = C(30, 126, 86) } }
function City.court(d, top, at, i)
	local ST = P.street
	local K = City.Courts[trioOf(i)]
	local x0, x1, za, zb = 22, 62.4, 3, 55
	District.floor(d, top, 1, ST.road + ST.walk, 64, 0, 56, ST.kerb + 0.08, C(96, 176, 96), 'CourtGround')
	local y = ST.kerb + 0.08
	sbox(d, 'CourtBorder', V(30, y - 0.3, top - 6), V(60, y + 0.06, top - 52), C(236, 232, 222))
	sbox(d, 'Court', V(31.5, y - 0.2, top - 7.5), V(58.5, y + 0.12, top - 50.5), K.court)
	local function mark(a0, b0, a1, b1) decor(d:box('CourtLine', V(a0, y + 0.12, top - b1), V(a1, y + 0.16, top - b0), P.white, M.SmoothPlastic)).CastShadow = false end
	mark(31.5, 7.5, 58.5, 7.9); mark(31.5, 50.1, 58.5, 50.5); mark(31.5, 7.5, 31.9, 50.5); mark(58.1, 7.5, 58.5, 50.5); mark(31.5, 28.8, 58.5, 29.2)
	for _, e in { { 7.9, 17 }, { 41, 50.1 } } do
		decor(d:box('CourtKey', V(41, y + 0.12, top - e[2]), V(49, y + 0.14, top - e[1]), K.key, M.SmoothPlastic)).CastShadow = false
	end
	for _, hp in { { 7, math.pi }, { 51, 0 } } do District.hoop(d, CFrame.new(V(45, y, top - hp[1])) * CFrame.Angles(0, hp[2], 0)) end
	chainLink(d, V(x0, ST.kerb, top - za), V(x0, ST.kerb, top - zb), 10, { { 23, 27.5 } })
	chainLink(d, V(x0, ST.kerb, top - za), V(x1, ST.kerb, top - za), 10)
	chainLink(d, V(x0, ST.kerb, top - zb), V(x1, ST.kerb, top - zb), 10)
	District.backWall(d, top, 1, x1, 0, 56, 14)
	local mural = ghost(d:box('Mural', V(x1 - 0.08, ST.kerb + 3, top - 12), V(x1 - 0.02, ST.kerb + 12, top - 44), P.white, M.SmoothPlastic))
	line(surface(mural, Enum.NormalId.Left, 12), 'Mural', ({ 'DOWNTOWN HOOPS', 'GAME ON', 'NEXT UP' })[trioOf(i)], ({ C(255, 210, 60), C(255, 96, 206), C(70, 220, 255) })[trioOf(i)], FONT.tag, 0.1, 0.8, P.black, 4).Rotation = -4
	for _, fl in { { 24, 5 }, { 60, 5 }, { 24, 53 }, { 60, 53 } } do District.floodlight(d, CFrame.lookAt(at(fl[1], fl[2]), at(45, 29)), 22) end
	for k, zp in ipairs({ 8, 47 }) do tree(d, at(19.4, zp), i * 100 + k, 0.8, 30 * k) end
	-- the players' tunnel (PropModels 'CourtTunnel', as World 1's courts), its mouth toward the gate
	local props = Armory.optional('PropModels')
	local okT, tunnel = false, nil
	if props and props.build then okT, tunnel = pcall(props.build, 'CourtTunnel', 1) end
	if okT and tunnel and tunnel.PrimaryPart then
		tunnel.Name = 'PlayersTunnel'
		local goal = d:world(CFrame.new(at(26.6, 50.4) + V(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0))
		local delta = goal * tunnel.PrimaryPart.CFrame:Inverse()
		for _, p in tunnel:GetDescendants() do
			if p:IsA('BasePart') then
				p.CFrame = delta * p.CFrame
				p.Anchored, p.CanTouch, p.CanQuery = true, false, false
				p.CanCollide = p.Name == 'Wall' or p.Name == 'Back' or p.Name == 'Post'
			end
		end
		tunnel.Parent = d.parent
	end
end

-- One stage of the avenue: World 1's stage group with its hidden fight marker (District.base), then the city on it, in
-- its district's dress (city/f4_districts.lua).
function City.avenueStage(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local K = City.D
	local look = lookOf(i)
	local cw0, cw1 = 13, 19 -- the crosswalk (z'), between the centre dashes at z' 7..11 and 23..27
	local ground = ({ nil, K.plazaTile, K.sand, nil, C(232, 222, 238) })[look] -- the district's ground on the paved strips
	local siteSide = i % 2 == 0 and 1 or -1 -- the construction zone's crane side
	for _, s in { -1, 1 } do
		local street = s < 0 and 'E' or 'W'
		local function x(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local court = look == 4 and s > 0
		if ground then District.floor(d, top, s, ST.road + ST.walk, FRONT, 0, ST.endZ, ST.kerb + 0.08, ground, 'DistrictGround') end
		-- the towers (this side's tones offset, so facing towers differ); Stage 1's first pair also shops on the plaza
		if not court then
			local xa, xb = x(FRONT, FRONT + DEPTH)
			for slot = 1, 2 do
				local z0, z1 = top - 28 * slot, top - 28 * (slot - 1)
				local h = City.heightAt(i, slot, s)
				local tone = i * 2 + slot + (s > 0 and 3 or 0)
				local name = slot == 1 and 'TowerA' or 'TowerB'
				if look == 3 and slot == 2 then
					-- the construction zone's back lots: a building going up (a crane over the one on the crane side)
					City.steelFrame(d, xa, xb, z0, z1, 40 + ((i + (s > 0 and 1 or 0)) % 3) * 6, street, i * 10 + s)
					if s == siteSide then City.crane(d, s * 46.75, top - 38.75, 84 + trioOf(i) * 4, -s, 34) end
				else
					local shops = (i == 1 and slot == 1) and { street, 'S' } or { street }
					local word = City.Words[(i * 5 + slot * 3 + (s > 0 and 7 or 0)) % #City.Words + 1]
					local o = { kind = City.kindAt(i, slot, s), tone = tone, faces = { street, 'S' }, shops = shops, word = word, setback = h >= 80 and 3 or nil, shadow = true, name = name }
					if look == 1 then -- red brick and grey
						local brick = (slot + (s > 0 and 1 or 0) + i) % 2 == 0
						o.stone = brick and K.brick[(i % 3) + 1] or K.grey[(i + slot) % 3 + 1]
						o.crown = brick and C(250, 206, 120) or C(232, 64, 60)
					elseif look == 2 then -- clean glass, a white crown
						o.crown = C(244, 246, 250)
					elseif look == 5 then -- dark blue glass, pink neon up the corners
						o.kind, o.glassColor = 'glass', ({ C(70, 92, 176), C(96, 76, 168), C(58, 108, 176) })[(i + slot) % 3 + 1]
						o.crown, o.neon = K.pink, K.pink
					end
					City.highrise(d, xa, xb, z0, z1, h, o)
				end
			end
		end
		local pa, pb = x(ST.open, FRONT + DEPTH)
		City.block(d, pa, pb, top - SLEN, top - ST.endZ, { kind = 'shop', floors = 0, tone = i * 2 + (s > 0 and 3 or 6), faces = { street, 'S' }, name = 'ShopRow' })
		-- the solid edge line along the run, broken at the crosswalk (the luxury district's glows pink)
		for _, r in { { 0, cw0 - 0.5 }, { cw1 + 0.5, SLEN } } do
			local e = decor(sbox(d, 'LaneEdge', V(s * 7.2, 0, top - r[2]), V(s * 7.7, 0.12, top - r[1]), City.line))
			e.CastShadow = false
			if look == 5 then e.Color, e.Material = K.pink, M.Neon end
		end
		-- lamps on the sidewalk (the old streets' black lanterns), their arms over the run
		for _, zp in { 9, 30 } do
			if look == 1 then City.lantern(d, at(s * 15.4, zp)) else City.lamp(d, at(s * 15.4, zp), -s) end
		end
	end
	if look == 4 then City.court(d, top, at, i) end
	-- the crosswalk, kerb to kerb (7 bars over the 17-stud run), a stop line before it, its signal
	District.zebra(d, V(-7.0, 0, top - (cw0 + cw1) / 2), 1.4, cw1 - cw0, V(7 / 3, 0, 0), 7)
	decor(sbox(d, 'StopLine', V(-7.1, 0, top - cw0 + 1.0), V(7.1, 0.12, top - cw0 + 1.6), City.line)).CastShadow = false
	local ls = i % 2 == 1 and 1 or -1
	City.signal(d, at(ls * 15.6, cw0 - 1.5), -ls)
	-- the street's life, by district; on the sidewalks' back half and the paved strip, z' 2..42 (the crew and the next
	-- gate's pads keep z' 44..64 clear)
	local seed = 800 + i * 10
	local t = trioOf(i)
	local function planters(list) for _, p in list do City.planter(d, at(p[1], p[2]), seed + p[2]) end end
	if look == 1 then
		if i == 1 then City.busStop(d, CFrame.new(at(-20.2, 21)) * CFrame.Angles(0, -math.pi / 2, 0)) end
		City.taxi(d, CFrame.new(at(-19.6, 36)))
		City.foodTruck(d, CFrame.new(at(27.5, 22)) * CFrame.Angles(0, math.pi, 0), ({ C(240, 96, 60), C(60, 150, 240), C(250, 180, 40) })[t], ({ 'TACOS', 'ICE CREAM', 'BURGERS' })[t])
		planters({ { -19.6, 5 }, { 19.6, 5 }, { -27, 40 }, { 26, 40 }, { -27, 12 } })
	elseif look == 2 then
		local fs = i % 2 == 0 and 1 or -1
		City.fountain(d, at(fs * 26, 25))
		City.taxi(d, CFrame.new(at(-fs * 19.6, 30)))
		planters({ { -19.6, 5 }, { 19.6, 5 }, { -fs * 28, 12 }, { -27, 41 }, { 27, 41 } })
		City.planter(d, at(-fs * 28, 22), seed + 3, 8, 4)
	elseif look == 3 then
		for _, s in { -1, 1 } do
			City.barrier(d, CFrame.new(at(s * 19.2, 9)) * CFrame.Angles(0, math.pi / 2, 0))
			if Stations then for _, zp in { 4, 24, 36 } do Stations.cone(d:at(CFrame.new(at(s * 9.4, zp))), CFrame.new()) end end
		end
		City.sandPile(d, at(-siteSide * 27, 16))
		City.bricks(d, at(siteSide * 27, 20))
		City.bricks(d, at(-siteSide * 28, 34))
		City.barrier(d, CFrame.new(at(siteSide * 28, 38)) * CFrame.Angles(0, math.pi / 2, 0))
	elseif look == 4 then
		City.viaduct(d, top, 0, SLEN, ({ { 1 }, nil, { SLEN - 1 } })[t])
		if t == 1 then City.station(d, top, 4, 28, 10, 36)
		else City.taxi(d, CFrame.new(at(-19.6, 30))) end
		if t == 2 then City.train(d, top, 6, 3) elseif t == 3 then City.train(d, top, 22, 2) end
		planters({ { -19.6, 5 }, { -27, 18 }, { -27, 38 } })
	else
		for _, p in { { -19.6, 5 }, { 19.6, 5 }, { -27, 40 }, { 27, 40 }, { 27, 14 }, { -27, 14 } } do City.palmPlanter(d, at(p[1], p[2]), seed + p[2] + (p[1] > 0 and 1 or 0)) end
		if i == 14 then City.fountain(d, at(-26, 27), K.pinkSoft) end
		car(d, CFrame.new(at(i % 2 == 0 and 19.6 or -19.6, 26)), K.pinkSoft)
		if i == 14 then -- a glass sky bridge over the avenue between the two towers' upper floors
			local y0 = City.heightAt(i, 1, -1) - 22
			local b = d:group('SkyBridge')
			b:box('BridgeGlass', V(-FRONT - 1, y0, top - 18), V(FRONT + 1, y0 + 6, top - 10), City.glass[2], M.SmoothPlastic)
			decor(b:box('BridgeDeck', V(-FRONT - 1, y0 - 1.2, top - 18.4), V(FRONT + 1, y0, top - 9.6), City.steelDark, M.SmoothPlastic))
			decor(b:box('BridgeRoof', V(-FRONT - 1, y0 + 6, top - 18.4), V(FRONT + 1, y0 + 6.8, top - 9.6), K.pink, M.SmoothPlastic))
			for xx = -FRONT + 6, FRONT - 6, 6 do
				for _, zz in { top - 18.15, top - 9.85 } do decor(b:box('BridgeMullion', V(xx - 0.25, y0, zz - 0.15), V(xx + 0.25, y0 + 6, zz + 0.15), City.mullion, M.SmoothPlastic)) end
			end
		end
		if i == STAGES then City.bossGate(d, top, 51) end
	end
	return d
end

---------------------------------------------------------------------------------------------- the rooftop (Stage 16)
-- (GoalRules' World 2 chain: "Reach the rooftop", "Beat The CEO", "on the rooftop, Stage 16") Past gate 16: the CEO
-- tower's podium roof, World 1's boss yard frame (|x| < 36, z BOSS_TOP..BOSS_END). Its floor is a blue-grey roof deck in
-- big two-tone tiles with a helipad (a dark disc, a yellow ring, a white H) in the middle; a glass parapet on a stone kerb round its sides and far
-- end (invisible walls over it); along the edges, clear of the fight: rooftop plant (AC units with fans,
-- vents, a dish); the CHAMP BAY (the Champ Ring's lane, as World 1's warehouse has it) in the near right corner; the
-- stage's two cash pads before the far parapet; the CEO tower rising behind it with a gold CEO sign over its doors. The crew waits
-- in front of the far parapet (EnemyRules.Spots[16]); the fight marker stays hidden, like World 1's.
function City.rooftop(ctx)
	local b, model = ctx:group('Rooftop')
	model:SetAttribute('Stage', 16)
	local function zp(v) return BOSS_TOP - v end
	local D = BOSS_TOP - BOSS_END -- 96
	local deckY = 0.12
	-- the deck: 16 x 16 tiles, two close tones, a darker frame round it
	for x = -FRONT, FRONT - 1, 16 do
		for v = 0, D - 1, 16 do
			local tone = ((x + FRONT) // 16 + v // 16) % 2 == 0 and C(132, 146, 186) or C(124, 138, 178)
			sbox(b, 'RoofDeck', V(x, -0.5, zp(math.min(v + 16, D))), V(math.min(x + 16, FRONT), deckY, zp(v)), tone)
		end
	end
	-- the helipad: a yellow ring, a white H, in the middle of the deck (z' 46)
	local hz = zp(46)
	decor(b:part('Helipad', V(0.1, 30, 30), CFrame.new(0, deckY + 0.05, hz) * CFrame.Angles(0, 0, math.pi / 2), C(70, 78, 104), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	for q = 0, 23 do
		local a0, a1 = q / 24 * math.pi * 2, (q + 1) / 24 * math.pi * 2
		local p0, p1 = V(math.cos(a0) * 13, deckY + 0.12, hz + math.sin(a0) * 13), V(math.cos(a1) * 13, deckY + 0.12, hz + math.sin(a1) * 13)
		decor(b:part('HelipadRing', V(1.4, 0.08, (p1 - p0).Magnitude + 0.1), CFrame.lookAt((p0 + p1) / 2, p1), City.yellow, M.SmoothPlastic)).CastShadow = false
	end
	for _, r in { { -4.5, -3, -5.5, 5.5 }, { 3, 4.5, -5.5, 5.5 }, { -3, 3, -0.75, 0.75 } } do
		decor(b:box('HelipadH', V(r[1], deckY + 0.08, hz + r[3]), V(r[2], deckY + 0.16, hz + r[4]), P.white, M.SmoothPlastic)).CastShadow = false
	end
	-- the parapet: a stone kerb, glass panels, a steel rail, along both sides and the far end (open at the gate)
	local function parapet(a, c2)
		local lo, hi = V(math.min(a.X, c2.X), 0, math.min(a.Z, c2.Z)), V(math.max(a.X, c2.X), 0, math.max(a.Z, c2.Z))
		sbox(b, 'ParapetKerb', lo + V(0, -0.5, 0), hi + V(0, 1.4, 0), C(206, 198, 186))
		-- the glass: the kerb's length, a third of its thickness, in its middle
		local thinX = hi.X - lo.X <= 1.01
		local glass = decor(b:box('ParapetGlass', V(thinX and lo.X + 0.35 or lo.X, 1.4, thinX and lo.Z or lo.Z + 0.35), V(thinX and hi.X - 0.35 or hi.X, 4.6, thinX and hi.Z or hi.Z - 0.35), C(170, 220, 250), M.SmoothPlastic))
		glass.Transparency, glass.CastShadow = 0.5, false
		decor(b:box('ParapetRail', lo + V(0, 4.6, 0), hi + V(0, 5.1, 0), City.steel, M.SmoothPlastic))
		invisibleWall(b, lo, hi + V(0, 30, 0))
	end
	parapet(V(-FRONT, 0, zp(0)), V(-FRONT + 1, 0, zp(D)))
	parapet(V(FRONT - 1, 0, zp(0)), V(FRONT, 0, zp(D)))
	parapet(V(-FRONT + 1, 0, zp(D - 1)), V(FRONT - 1, 0, zp(D)))
	-- rooftop plant along the sides (z' 26..70) and the far corners
	local plant = b:group('RoofPlant')
	local function ac(xc, v, k)
		local g = plant:at(CFrame.new(xc, deckY, zp(v)))
		sbox(g, 'ACUnit', V(-2.4, 0, -2), V(2.4, 3.2, 2), C(206, 212, 222))
		for _, fz in { -1, 1 } do
			decor(g:part('ACFan', V(0.12, 2.4, 2.4), CFrame.new(fz * 1.2, 3.25, 0) * CFrame.Angles(0, 0, math.pi / 2), C(80, 88, 104), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		end
		decor(g:box('ACStripe', V(-2.45, 0.6, -2.05), V(2.45, 0.9, 2.05), ({ City.yellow, C(48, 140, 220), C(232, 64, 60) })[k % 3 + 1], M.SmoothPlastic)).CastShadow = false
	end
	for k, v in ipairs({ 28, 36, 60, 68 }) do ac(k % 2 == 0 and 31 or -31, v, k) end
	ac(-31, 48, 3)
	local dish = plant:at(CFrame.new(31, deckY, zp(48)))
	sbox(dish, 'DishBase', V(-1.2, 0, -1.2), V(1.2, 1, 1.2), City.steelDark)
	dish:box('DishPole', V(-0.3, 1, -0.3), V(0.3, 4, 0.3), City.steel, M.SmoothPlastic)
	decor(dish:part('Dish', V(0.4, 5, 5), CFrame.new(0, 5.2, 0) * CFrame.Angles(0, math.rad(200), math.rad(40)), P.white, M.SmoothPlastic, Enum.PartType.Cylinder))
	-- the CHAMP BAY (the Champ Ring's lane, as World 1's warehouse): a steel deck in the near right corner with the lane's
	-- TrainingZone, a hazard edge, a big target and the bay's sign
	local ring = SKINS.StationById.Ring
	local bay = b:at(CFrame.new(26, deckY, zp(14))):group('Training_' .. ring.Id)
	sbox(bay, 'BayDeck', V(-7, 0, -7), V(7, 1, 7), C(70, 74, 90))
	for k = 0, 6 do decor(bay:box('BayEdge', V(-7 + k * 2, 1, 6.6), V(-6 + k * 2, 1.06, 7), City.yellow, M.SmoothPlastic)).CastShadow = false end
	local zone = bay:box('TrainingZone', V(-5, 1, -5), V(5, 1.25, 5), C(236, 238, 244), M.Fabric)
	zone.Name = 'TrainingZone'
	local target = bay:at(CFrame.new(6.2, 1, 0)):group('Equipment')
	target:box('TargetStand', V(-0.3, 0, -0.3), V(0.3, 5, 0.3), City.steelDark, M.Metal)
	for k, r2 in ipairs({ { 7, C(232, 48, 52) }, { 5, P.white }, { 3, C(232, 48, 52) }, { 1.2, City.yellow } }) do
		decor(target:part('Target', V(0.2 + k * 0.05, r2[1], r2[1]), CFrame.new(-0.2 - k * 0.05, 7.4, 0), r2[2], M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	local plate = bay:box('Nameplate', V(-6, 9.6, 6.2), V(6, 12.4, 6.6), C(24, 32, 56), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 24), 'Name', 'CHAMP BAY', City.yellow, FONT.title, 0.1, 0.8, P.black, 3)
	for _, x in { -5.6, 5.6 } do bay:box('PlatePost', V(x - 0.25, 1, 6.25), V(x + 0.25, 9.6, 6.55), City.steelDark, M.Metal) end
	local vfx = Armory.optional('HoodVFX')
	if vfx then vfx.station(zone, 9, nil, V(10, 12, 12)) end
	-- the stage's pads (beat the crew, then cash out, like before every gate) and the hidden fight marker
	local bz = BOSS_END + 22
	GATE.pads(b, 16, 15, bz - 7, deckY, 5.6, 11)
	fightPad(b, 16, V(0, deckY, bz), P.padRed, 6, 14, nil, true)
	-- the flanks past the parapet (|x| 36..64): the podium's lower roof, gravel and plant, up to the next towers
	for _, s in { -1, 1 } do
		sbox(b, 'FlankRoof', V(math.min(s * FRONT, s * (FRONT + DEPTH)), -1, BOSS_END), V(math.max(s * FRONT, s * (FRONT + DEPTH)), 0.95, BOSS_TOP), C(176, 178, 188))
		for k, v in ipairs({ 20, 52, 84 }) do
			local g = plant:at(CFrame.new(s * 50, 0.95, zp(v)))
			sbox(g, 'Vent', V(-3, 0, -3), V(3, 2.6, 3), C(200, 206, 216))
			decor(g:box('VentCap', V(-3.4, 2.6, -3.4), V(3.4, 3.2, 3.4), ({ City.yellow, C(48, 140, 220), C(232, 64, 60) })[k], M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the CEO tower behind the far parapet: the tallest glass on the map, a gold CEO sign over its doors, facing the deck
	local ceoZ0, ceoZ1 = BOSS_END - 72, BOSS_END - 4
	local t = City.highrise(b, -40, 40, ceoZ0, ceoZ1, 196, { kind = 'glass', tone = 2, faces = { 'S', 'E', 'W' }, setback = 6, name = 'CEOTower' })
	local sign = t:box('CEOSign', V(-18, 16, ceoZ1 - 1.1), V(18, 28, ceoZ1 - 0.7), C(255, 196, 40), M.SmoothPlastic)
	decor(sign)
	line(surface(sign, Enum.NormalId.Back, 6), 'CEO', 'CEO', P.white, FONT.title, 0.06, 0.88, C(120, 70, 0), 4)
	return b
end

---------------------------------------------------------------------------------------------- the city round the track
-- North of the plaza's ring (City.skyline, e5_plaza) the side streets run on up the whole avenue to the CEO tower's
-- block, the city's paved base under everything: an inner row of towers between the avenue's and the side street
-- (|x| 64..88.5), an outer row past it (|x| 116..166), a far row of plain glass silhouettes (|x| 170..206), and a row
-- across the north end either side of the CEO tower. Each row stands taller than the one inside it, and taller up the
-- track. No shadows (they'd only fall on roofs).
function City.skylineFar(ctx)
	local g = ctx:group('Skyline')
	local R = City.Ring
	local RY, WY = R.road, R.walk
	local zN = BOSS_END - 40 -- the side streets' north end, where the north row closes them
	local base = City.walk:Lerp(City.road, 0.25)
	local function stageAt(z) return math.clamp(math.floor(-z / SLEN) + 1, 1, STAGES) end
	for _, s in { -1, 1 } do
		local function X(a, b) return math.min(s * a, s * b), math.max(s * a, s * b) end
		local a, b = X(FRONT + DEPTH, R.walk0)
		sbox(g, 'CityBase', V(a, -1, zN), V(b, WY, 0), base)
		a, b = X(R.walk0, R.road0)
		sbox(g, 'Sidewalk', V(a, -1, zN), V(b, WY, 0), City.walk)
		a, b = X(R.road0, R.road1)
		sbox(g, 'Road', V(a, -1, zN), V(b, RY, 0), City.road)
		a, b = X(R.road1, R.walk1)
		sbox(g, 'Sidewalk', V(a, -1, zN), V(b, WY, 0), City.walk)
		a, b = X(R.walk1, 206)
		sbox(g, 'CityBase', V(a, -1, zN), V(b, WY, 0), base)
		for _, kx in { R.road0, R.road1 } do decor(sbox(g, 'KerbStone', V(s * (kx - 0.6), -0.5, zN), V(s * (kx + 0.6), WY + 0.1, 0), City.kerb)).CastShadow = false end
		for z = -8, zN + 6, -12 do decor(sbox(g, 'RoadLine', V(s * 102.7, RY, z - 5), V(s * 103.3, RY + 0.12, z), City.line)).CastShadow = false end
		-- the rows: inner (its faces to the avenue, over the front towers, and south), outer (to the side street and
		-- south), far (plain silhouettes)
		local inner = s > 0 and 'W' or 'E'
		local outer = s > 0 and 'W' or 'E'
		local z, k = -2, 0
		while z - 24 > zN do
			k += 1
			local len = 26 + ((k * 7 + (s > 0 and 3 or 0)) % 4) * 4
			local z1, z0 = z, math.max(zN + 2, z - len)
			local h = City.heightAt(stageAt(z0), 2, s) + 18 + ((k * 5) % 3) * 8
			local xa, xb = X(FRONT + DEPTH + 1, R.walk0 - 1.5)
			City.highrise(g, xa, xb, z0, z1, h, { kind = (k + (s > 0 and 1 or 0)) % 3 == 0 and 'stone' or 'glass', tone = k + (s > 0 and 2 or 5), faces = { inner, 'S' }, setback = h >= 90 and 2 or nil, pitch = 6, name = 'InnerTower' })
			z = z0 - 4
		end
		z, k = -2, 0
		while z - 30 > zN do
			k += 1
			local len = 32 + ((k * 5 + (s > 0 and 1 or 0)) % 3) * 8
			local z1, z0 = z, math.max(zN + 2, z - len)
			local h = City.heightAt(stageAt(z0), 1, s) + 34 + ((k * 7) % 4) * 8
			local xa, xb = X(R.walk1 + 1.5, R.walk1 + 46)
			City.highrise(g, xa, xb, z0, z1, h, { kind = k % 3 == 1 and 'stone' or 'glass', tone = k + (s > 0 and 4 or 1), faces = { outer, 'S' }, setback = h >= 100 and 3 or nil, pitch = 6, name = 'OuterTower' })
			z = z0 - 5
		end
		local fz = 140
		k = 0
		while fz - 30 > zN do
			k += 1
			local len = 30 + (k % 3) * 10
			local h = City.heightAt(stageAt(fz - len), 1, s) + 56 + (k % 4) * 12
			local xa, xb = X(172, 204)
			City.highrise(g, xa, xb, fz - len, fz, h, { kind = k % 4 == 2 and 'stone' or 'glass', tone = k * 3 + (s > 0 and 1 or 0), faces = { outer }, pitch = 8, name = 'FarTower' })
			fz -= len + 6
		end
	end
	-- the north end: the city's base round the CEO tower, a row of towers across either side of it
	sbox(g, 'CityBase', V(-206, -1, zN - 80), V(206, WY, zN), base)
	sbox(g, 'CityBase', V(-(FRONT + DEPTH), -1, zN), V(FRONT + DEPTH, WY, BOSS_END), base)
	for k, xs in ipairs({ { 46, 84 }, { 90, 128 }, { 134, 172 } }) do
		for _, s in { -1, 1 } do
			local xa, xb = math.min(s * xs[1], s * xs[2]), math.max(s * xs[1], s * xs[2])
			City.highrise(g, xa, xb, zN - 46, zN - 4, 150 + k * 10 + (s > 0 and 8 or 0), { kind = (k + (s > 0 and 1 or 0)) % 2 == 0 and 'stone' or 'glass', tone = k * 2 + (s > 0 and 1 or 0), faces = { 'S' }, setback = 3, pitch = 6, name = 'NorthTower' })
		end
	end
	return g
end

-- The ground: World 1's (f_areas) for the street, its forecourt and the keep-in walls, without its hood edges (the grass
-- lots, the low boundary wall, the ring road round it, the boss yard's paving under the rooftop's deck), which the city's paved base and towers replace.
local hoodGround = buildGround
local function buildGround(ctx)
	local g = hoodGround(ctx)
	local ground = g and g.parent
	if ground then
		for _, p in ground:GetChildren() do
			if p:IsA('BasePart') and (p.Material == M.Grass or p.Name == 'Wall' or p.Name == 'WallCap' or p.Name == 'Paving') then p:Destroy() end
		end
	end
	local ring = ctx.parent:FindFirstChild('RingRoad')
	if ring then ring:Destroy() end
	return g
end

local function buildStages(ctx)
	for i = 1, STAGES do City.avenueStage(ctx, i) end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do
		local model = stageGate(gates, i)
		model:SetAttribute('WallId', 'HoodW' .. (V2.World or 2) .. 'Stage' .. i)
		model:SetAttribute('World', V2.World or 2)
		-- (round 3) World 2's Power reads in the billions: Lune (the place builder, tools/place) stores a whole-number
		-- attribute as a 32-bit integer and wraps anything past 2,147,483,647 (gate 4's 2.15B came out negative), so a
		-- whole Required that big carries 1/1024 more, which keeps it a real number in the place file (signs round it)
		local req = STAGE_POWER[i]
		if type(req) == 'number' and req >= 2 ^ 31 and req % 1 == 0 then model:SetAttribute('Required', req + 2 ^ -10) end
		local name = model:FindFirstChild('GateWorldName', true)
		if name then
			name.Text = 'WORLD ' .. (V2.World or 2)
			-- (round 3) the board's lobby side carries the name too (the owner's board is blank there): a plate on its
			-- south face, the same words facing the plaza
			local face = name.Parent and name.Parent.Parent
			if face and face:IsA('BasePart') then
				local back = face:Clone()
				back.Name = 'GateBoardBack'
				local at, lz = face.CFrame.Position, (V2.Origin * CFrame.new(0, 0, model:GetAttribute('LineZ'))).Position.Z
				back.CFrame = CFrame.new(at.X, at.Y, 2 * lz - at.Z)
				pcall(function() back.Position = back.CFrame.Position end)
				local gui = back:FindFirstChildOfClass('SurfaceGui')
				if gui then gui.Face = Enum.NormalId.Back end
				back.Parent = face.Parent
			end
		end
	end
	City.rooftop(ctx)
	City.skylineFar(ctx)
end
