---------------------------------------------------------------------------------------------- the districts' props (World 2)
-- (Oct 27, the owner's districts mockup, docs/refs/world2/owner_world2_districts_oct27.png: "don't make it exactly like
-- this ... make the models look more low poly/cartoony") Five districts, three stages each, every prop our own chunky
-- blocks in clean saturated colours (no copies of the mockup's models):
--   City Streets (1-3)       black lanterns, trees in planters, red brick and grey towers
--   Modern Plaza (4-6)       glass towers, light plaza tiles, fountains, planters
--   Construction Zone (7-9)  sand ground, red steel frames with yellow scaffolds, yellow tower cranes, barriers, cones,
--                            sand piles, brick pallets
--   Transit Area (10-12)     an elevated train line on concrete piers over the left side, a station with an escalator,
--                            a train (the street court stays on the right: EnemyRules.Courts has the crew there)
--   Luxury District (13-15)  dark glass towers with pink neon edges, palms, pink lines along the run, a fountain, the red
--                            BOSS gateway before gate 16 (the CEO tower and its rooftop beyond)
-- City.avenueStage (f5_avenue) calls these by district.

City.D = {
	lantern = C(44, 48, 62), lanternGlow = C(255, 214, 120),
	brick = { C(198, 88, 68), C(182, 76, 60), C(208, 104, 80) }, grey = { C(150, 156, 172), C(132, 140, 160), C(168, 172, 186) },
	plazaTile = C(222, 228, 238), water = C(84, 196, 250), waterTop = C(170, 232, 255), fountainStone = C(236, 238, 244),
	sand = C(238, 204, 128), sandDark = C(214, 176, 100), red = C(214, 62, 52), redDark = C(176, 46, 40),
	yellow = C(252, 198, 40), yellowDark = C(214, 160, 24), concrete = C(178, 182, 194), concreteLight = C(204, 208, 218),
	white = C(244, 246, 250), trainBlue = C(40, 110, 220), trainRed = C(226, 54, 60), window = C(46, 70, 108),
	pink = C(255, 70, 190), pinkSoft = C(244, 132, 206), luxGlass = C(70, 92, 176), luxPlanter = C(64, 60, 92),
	trunk = C(196, 150, 96), trunkDark = C(170, 124, 76), frond = C(70, 190, 76), frondDark = C(48, 150, 62),
}

---------------------------------------------------------------------------------------------- City Streets
-- A black street lantern (pos: its foot on the ground): a stepped foot, a slim post, a warm glowing lamp box under a cap.
function City.lantern(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('Lantern')
	sbox(g, 'LanternFoot', V(-0.9, 0, -0.9), V(0.9, 1, 0.9), K.lantern)
	g:box('LanternPost', V(-0.35, 1, -0.35), V(0.35, 9, 0.35), K.lantern, M.SmoothPlastic)
	g:box('LanternCollar', V(-0.7, 9, -0.7), V(0.7, 9.5, 0.7), K.lantern, M.SmoothPlastic)
	decor(g:box('LanternGlow', V(-0.8, 9.5, -0.8), V(0.8, 11.3, 0.8), K.lanternGlow, M.Neon)).CastShadow = false
	g:box('LanternCap', V(-1.1, 11.3, -1.1), V(1.1, 11.9, 1.1), K.lantern, M.SmoothPlastic)
	g:box('LanternTop', V(-0.4, 11.9, -0.4), V(0.4, 12.6, 0.4), K.lantern, M.SmoothPlastic)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'LanternFoot' and p.Name ~= 'LanternPost' then decor(p) end end
	return g
end

---------------------------------------------------------------------------------------------- Modern Plaza
-- A square stepped fountain (pos: its centre on the ground): a stone basin with a rim and water in it, a pedestal with
-- a second bowl, a water column with a bright cap. rim: the rim's colour (the luxury one is pink).
function City.fountain(c, pos, rim, r)
	local K = City.D
	r = r or 5
	local g = c:at(CFrame.new(pos)):group('Fountain')
	sbox(g, 'FountainBasin', V(-r, 0, -r), V(r, 1.0, r), K.fountainStone)
	decor(g:box('FountainWater', V(-r + 0.7, 1.0, -r + 0.7), V(r - 0.7, 1.4, r - 0.7), K.water, M.SmoothPlastic)).CastShadow = false
	for _, e in { { -r, -r, r, -r + 0.7 }, { -r, r - 0.7, r, r }, { -r, -r + 0.7, -r + 0.7, r - 0.7 }, { r - 0.7, -r + 0.7, r, r - 0.7 } } do
		sbox(g, 'FountainRim', V(e[1], 1.0, e[2]), V(e[3], 1.9, e[4]), rim or K.fountainStone)
	end
	sbox(g, 'FountainPedestal', V(-1.1, 1.4, -1.1), V(1.1, 4.2, 1.1), K.fountainStone)
	sbox(g, 'FountainBowl', V(-2.6, 4.2, -2.6), V(2.6, 4.9, 2.6), rim or K.fountainStone)
	decor(g:box('FountainWater', V(-2.1, 4.9, -2.1), V(2.1, 5.1, 2.1), K.water, M.SmoothPlastic)).CastShadow = false
	local col = decor(g:box('FountainJet', V(-0.45, 5.1, -0.45), V(0.45, 8.2, 0.45), K.waterTop, M.SmoothPlastic))
	col.CastShadow, col.Transparency = false, 0.2
	local cap = decor(g:box('FountainSpray', V(-1.0, 8.2, -1.0), V(1.0, 8.8, 1.0), K.waterTop, M.SmoothPlastic))
	cap.CastShadow, cap.Transparency = false, 0.25
	return g
end

---------------------------------------------------------------------------------------------- Construction Zone
-- A building going up over x0..x1, z0..z1 (this frame), h high: a concrete pad, red steel columns on a grid (some a storey
-- short: still going up), beams round and across every storey, concrete floors on the lower third, a yellow scaffold up
-- the face toward the street (face: 'W' at x0 or 'E' at x1).
function City.steelFrame(c, x0, x1, z0, z1, h, face, seed)
	local K = City.D
	local g = c:group('SteelFrame')
	local r = Random.new(seed or 1)
	sbox(g, 'FramePad', V(x0, -1, z0), V(x1, 1.2, z1), K.concrete)
	local st = 6
	local top = math.max(2, math.floor((h - 1.2) / st)) * st + 1.2
	local nx, nz = math.max(2, math.floor((x1 - x0) / 7 + 0.5)), math.max(2, math.floor((z1 - z0) / 7 + 0.5))
	local xs, zs = {}, {}
	for i = 0, nx do table.insert(xs, x0 + 1 + (x1 - x0 - 2) * i / nx) end
	for j = 0, nz do table.insert(zs, z0 + 1 + (z1 - z0 - 2) * j / nz) end
	local reach = {}
	for i, x in xs do
		reach[i] = {}
		for j, z in zs do
			local edge = i == 1 or i == #xs or j == 1 or j == #zs
			local t = top - ((not edge or r:NextNumber() < 0.35) and r:NextInteger(0, 1) * st or 0)
			reach[i][j] = t
			g:box('FrameColumn', V(x - 0.6, 1.2, z - 0.6), V(x + 0.6, t, z + 0.6), K.red, M.SmoothPlastic)
		end
	end
	for y = 1.2 + st, top, st do
		for j, z in zs do
			for i = 1, #xs - 1 do
				if reach[i][j] >= y and reach[i + 1][j] >= y then g:box('FrameBeam', V(xs[i], y - 0.9, z - 0.45), V(xs[i + 1], y, z + 0.45), K.redDark, M.SmoothPlastic) end
			end
		end
		for i, x in xs do
			for j = 1, #zs - 1 do
				if reach[i][j] >= y and reach[i][j + 1] >= y then g:box('FrameBeam', V(x - 0.45, y - 0.9, zs[j]), V(x + 0.45, y, zs[j + 1]), K.redDark, M.SmoothPlastic) end
			end
		end
		if y <= 1.2 + (top - 1.2) / 3 + 0.1 then
			sbox(g, 'FrameFloor', V(xs[1] - 0.6, y - 0.9, zs[1] - 0.6), V(xs[#xs] + 0.6, y - 0.3, zs[#zs] + 0.6), K.concreteLight)
		end
	end
	-- the scaffold: yellow standards every ~4 studs, a plank deck and a rail every storey, two storeys up the face
	local fx = face == 'W' and x0 - 2.2 or x1 + 2.2
	local sh = math.min(top, 1.2 + st * 3)
	for z = z0 + 1, z1 - 1, 4 do
		for _, dx in { -0.9, 0.9 } do decor(g:box('ScaffoldPole', V(fx + dx - 0.2, 1.2, z - 0.2), V(fx + dx + 0.2, sh + 2, z + 0.2), K.yellow, M.SmoothPlastic)) end
	end
	for y = 1.2 + st, sh, st do
		decor(sbox(g, 'ScaffoldDeck', V(fx - 1.2, y - 0.4, z0 + 0.6), V(fx + 1.2, y, z1 - 0.6), C(196, 150, 96)))
		decor(g:box('ScaffoldRail', V(fx + (face == 'W' and -1.3 or 1.1), y + 1.6, z0 + 0.6), V(fx + (face == 'W' and -1.1 or 1.3), y + 1.9, z1 - 0.6), K.yellowDark, M.SmoothPlastic))
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = p.Name == 'FramePad' or p.Name == 'FrameColumn' or p.Name == 'FrameFloor' end end
	return g
end

-- A yellow tower crane: a lattice mast at (x, z) on a concrete foot, the cab and the slewing ring on top, a long jib
-- toward dir (+1 / -1 in x) with its trolley, the cable and a red beam hanging from it, the short counter-jib behind with
-- its concrete weights, the ties from the peak.
function City.crane(c, x, z, h, dir, len)
	local K = City.D
	local g = c:at(CFrame.new(x, 0, z)):group('TowerCrane')
	len = len or 30
	local a = 1.6 -- the mast's half width
	sbox(g, 'CraneFoot', V(-3, -1, -3), V(3, 1.4, 3), K.concrete)
	for _, q in { { -a, -a }, { a, -a }, { -a, a }, { a, a } } do
		g:box('CraneMast', V(q[1] - 0.3, 1.4, q[2] - 0.3), V(q[1] + 0.3, h, q[2] + 0.3), K.yellow, M.SmoothPlastic)
	end
	for y = 4, h - 1, 3.5 do
		for _, s in { -1, 1 } do
			decor(g:box('CraneRung', V(-a, y - 0.15, s * a - 0.15), V(a, y + 0.15, s * a + 0.15), K.yellowDark, M.SmoothPlastic))
			decor(g:box('CraneRung', V(s * a - 0.15, y - 0.15, -a), V(s * a + 0.15, y + 0.15, a), K.yellowDark, M.SmoothPlastic))
		end
		-- one diagonal per face, alternating (the lattice's zigzag)
		local lean = math.atan2(2 * a, 3.5) * ((math.floor(y / 3.5) % 2 == 0) and 1 or -1)
		local dl = math.sqrt(3.5 ^ 2 + (2 * a) ^ 2)
		for _, s in { -1, 1 } do
			decor(g:part('CraneBrace', V(0.25, dl, 0.25), CFrame.new(0, y + 1.75, s * a) * CFrame.Angles(0, 0, lean), K.yellowDark, M.SmoothPlastic))
			decor(g:part('CraneBrace', V(0.25, dl, 0.25), CFrame.new(s * a, y + 1.75, 0) * CFrame.Angles(lean, 0, 0), K.yellowDark, M.SmoothPlastic))
		end
	end
	g:box('CraneRing', V(-2.2, h, -2.2), V(2.2, h + 1, 2.2), K.lantern, M.SmoothPlastic)
	g:box('CraneCab', V(-dir * 0.2 - (dir > 0 and 0 or 3.4), h + 1, 1.0), V(-dir * 0.2 + (dir > 0 and 3.4 or 0), h + 4, 3.6), K.yellow, M.SmoothPlastic)
	decor(g:box('CraneCabGlass', V(math.min(dir * 3.2, dir * 3.5), h + 2.2, 1.2), V(math.max(dir * 3.2, dir * 3.5), h + 3.6, 3.4), K.window, M.SmoothPlastic))
	-- the jib (two bottom chords and a top chord, rungs between) and the counter-jib
	local function chord(name, u0, u1, y, zz, w)
		local lo, hi = math.min(u0, u1), math.max(u0, u1)
		return g:box(name, V(lo, y - w, zz - w), V(hi, y + w, zz + w), K.yellow, M.SmoothPlastic)
	end
	local yb = h + 1.4
	for _, zz in { -1.1, 1.1 } do chord('CraneJib', -dir * 10, dir * len, yb, zz, 0.25) end
	chord('CraneJib', -dir * 10, dir * len, yb + 2.4, 0, 0.25)
	for u = -8, len, 3 do
		decor(g:box('CraneJibRung', V(dir * u - 0.15, yb - 0.2, -1.1), V(dir * u + 0.15, yb + 0.2, 1.1), K.yellowDark, M.SmoothPlastic))
		for _, zz in { -1.1, 1.1 } do
			decor(g:part('CraneJibBrace', V(0.2, 2.6, 0.2), CFrame.new(dir * u, yb + 1.2, zz / 2) * CFrame.Angles(math.atan2(-zz, 2.4), 0, 0), K.yellowDark, M.SmoothPlastic))
		end
	end
	sbox(g, 'CraneWeight', V(math.min(-dir * 10, -dir * 6), yb - 3.4, -1.6), V(math.max(-dir * 10, -dir * 6), yb - 0.3, 1.6), K.concrete)
	g:box('CranePeak', V(-0.6, h + 1, -0.6), V(0.6, h + 9, 0.6), K.yellow, M.SmoothPlastic)
	local peak = V(0, h + 9, 0)
	for _, tip in { V(dir * len * 0.7, yb + 2.4, 0), V(-dir * 9, yb + 2.4, 0) } do
		local m = (peak + tip) / 2
		decor(g:part('CraneTie', V(0.15, 0.15, (tip - peak).Magnitude), CFrame.lookAt(m, tip), K.lantern, M.SmoothPlastic))
	end
	-- the trolley, the cable, the hook and its load (a red beam)
	local tx = dir * len * 0.62
	decor(g:box('CraneTrolley', V(tx - 1.2, yb - 0.9, -1.2), V(tx + 1.2, yb - 0.25, 1.2), K.lantern, M.SmoothPlastic))
	local hy = math.max(24, h * 0.45)
	decor(g:box('CraneCable', V(tx - 0.08, hy + 1.2, -0.08), V(tx + 0.08, yb - 0.9, 0.08), K.lantern, M.SmoothPlastic))
	decor(g:box('CraneHook', V(tx - 0.6, hy, -0.6), V(tx + 0.6, hy + 1.2, 0.6), K.yellow, M.SmoothPlastic))
	decor(g:box('CraneLoad', V(tx - 0.7, hy - 1.6, -5), V(tx + 0.7, hy - 0.2, 5), K.red, M.SmoothPlastic))
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then p.CastShadow = p.Name == 'CraneMast' or p.Name == 'CraneFoot' end end
	return g
end

-- Site props (cf / pos on the ground): a red-and-white jersey barrier, a sand pile, a pallet of bricks.
function City.barrier(c, cf)
	local g = c:at(cf):group('Barrier')
	for k = 0, 2 do sbox(g, 'BarrierBlock', V(-3 + k * 2, 0, -0.6), V(-1 + k * 2, 2.2, 0.6), k % 2 == 0 and City.D.red or City.D.white) end
	sbox(g, 'BarrierFoot', V(-3.1, 0, -0.9), V(3.1, 0.6, 0.9), City.D.concrete)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end
function City.sandPile(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('SandPile')
	sbox(g, 'Sand', V(-3.2, 0, -2.6), V(3.2, 1.2, 2.6), K.sandDark)
	sbox(g, 'Sand', V(-2.2, 1.2, -1.8), V(2.2, 2.2, 1.8), K.sand)
	sbox(g, 'Sand', V(-1.1, 2.2, -0.9), V(1.1, 2.9, 0.9), K.sand)
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end
function City.bricks(c, pos)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('BrickPallet')
	sbox(g, 'Pallet', V(-2, 0, -1.6), V(2, 0.5, 1.6), C(176, 128, 82))
	for k = 0, 5 do
		local cx, cz, cy = -1.1 + (k % 2) * 2.2, k < 4 and -0.8 or 0.8, k < 4 and 0.5 or 1.5
		if k >= 2 and k < 4 then cz = 0.8 end
		sbox(g, 'BrickStack', V(cx - 0.9, cy, cz - 0.7), V(cx + 0.9, cy + 1.0, cz + 0.7), k % 3 == 0 and K.brick[2] or K.brick[1])
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	return g
end

---------------------------------------------------------------------------------------------- Transit Area
-- The elevated line over the left side (x xa..xb, z' za..zb of a stage, its deck top at y): a concrete deck with kerbs
-- and two rails, hammerhead piers at the given z'.
City.Rail = { xa = -35, xb = -23, y = 24.2, piers = { 26, 46 } }
function City.viaduct(d, top, za, zb, ends)
	local K, R = City.D, City.Rail
	local g = d:group('Viaduct')
	local xa, xb, y = R.xa, R.xb, R.y
	sbox(g, 'ViaductDeck', V(xa, y - 2.2, top - zb), V(xb, y, top - za), K.concrete)
	decor(g:box('ViaductSkirt', V(xa - 0.2, y - 2.6, top - zb), V(xb + 0.2, y - 2.2, top - za), K.trainBlue, M.SmoothPlastic)).CastShadow = false
	for _, x in { xa, xb - 0.7 } do sbox(g, 'ViaductKerb', V(x, y, top - zb), V(x + 0.7, y + 1.2, top - za), K.concreteLight) end
	local mid = (xa + xb) / 2
	for _, x in { mid - 1.6, mid + 1.6 } do decor(g:box('Rail', V(x - 0.2, y, top - zb), V(x + 0.2, y + 0.4, top - za), City.steel, M.SmoothPlastic)) end
	for _, zp in R.piers do
		sbox(g, 'PierFoot', V(mid - 2.6, -0.5, top - zp - 2.6), V(mid + 2.6, P.street.kerb + 1, top - zp + 2.6), K.concrete)
		sbox(g, 'Pier', V(mid - 2, P.street.kerb + 1, top - zp - 2), V(mid + 2, y - 4.2, top - zp + 2), K.concreteLight)
		sbox(g, 'PierHead', V(xa + 1, y - 4.2, top - zp - 2.4), V(xb - 1, y - 2.2, top - zp + 2.4), K.concrete)
	end
	for _, e in ends or {} do
		sbox(g, 'RailBuffer', V(mid - 2.4, y, top - e - 0.8), V(mid + 2.4, y + 1.6, top - e + 0.8), K.trainRed)
	end
	return g
end
-- A train of n cars on the line, its nose at z' zp heading -Z (up the track): white bodies with a blue band and a red
-- stripe, a dark window band, a grey roof, dark bogies; the lead car's nose sloped.
function City.train(d, top, zp, n)
	local K, R = City.D, City.Rail
	local g = d:group('Train')
	local x, y = (R.xa + R.xb) / 2, R.y + 0.4
	local cl, gap = 15, 0.8
	for k = 0, n - 1 do
		local z0 = top - zp + k * (cl + gap)
		local z1 = z0 + cl
		local function B(name, a0, ya, a1, yb2, za, zb, col, isDecor)
			local p = g:box(name, V(x + a0, y + ya, za), V(x + a1, y + yb2, zb), col, M.SmoothPlastic)
			if isDecor then decor(p).CastShadow = false end
			return p
		end
		B('TrainBogie', -1.6, 0, 1.6, 0.9, z0 + 1.5, z1 - 1.5, K.lantern)
		B('TrainBody', -2.1, 0.9, 2.1, 5.6, z0, z1, K.white)
		B('TrainBand', -2.2, 1.5, 2.2, 2.5, z0 + 0.2, z1 - 0.2, K.trainBlue, true)
		B('TrainStripe', -2.2, 2.5, 2.2, 2.85, z0 + 0.2, z1 - 0.2, K.trainRed, true)
		B('TrainWindows', -2.2, 3.2, 2.2, 4.7, z0 + 1, z1 - 1, K.window, true)
		B('TrainRoof', -1.8, 5.6, 1.8, 6.1, z0 + 0.5, z1 - 0.5, K.concreteLight, true)
		if k == 0 then
			-- the nose: a wedge sloping down to the front, its windscreen dark
			g:wedge('TrainNose', V(4.2, 3.1, 3), CFrame.new(x, y + 4.15, z0 - 1.5), K.white, M.SmoothPlastic)
			B('TrainNoseBase', -2.1, 0.9, 2.1, 2.6, z0 - 3, z0, K.white)
			B('TrainNoseBand', -2.2, 1.5, 2.2, 2.5, z0 - 3, z0, K.trainBlue, true)
		end
	end
	return g
end
-- The station on the line (z' za..zb): a blue canopy on posts over the deck with a METRO sign toward the street, and an
-- escalator up from the paved strip (x -22.6..-18.6, z' zLow on the ground to zHigh at the deck).
function City.station(d, top, za, zb, zHigh, zLow)
	local K, R = City.D, City.Rail
	local g = d:group('Station')
	local y = R.y
	for zp = za, zb, 8 do
		for _, x in { R.xa + 0.35, R.xb - 0.35 } do g:box('CanopyPost', V(x - 0.3, y + 1.2, top - zp - 0.3), V(x + 0.3, y + 6.4, top - zp + 0.3), City.steel, M.SmoothPlastic) end
	end
	sbox(g, 'Canopy', V(R.xa - 0.8, y + 6.4, top - zb - 1), V(R.xb + 0.8, y + 7.2, top - za + 1), K.trainBlue)
	local sign = g:box('StationSign', V(R.xb + 0.8, y + 5.2, top - (za + zb) / 2 - 7), V(R.xb + 1.1, y + 7.2, top - (za + zb) / 2 + 7), K.white, M.SmoothPlastic)
	decor(sign).CastShadow = false
	line(surface(sign, Enum.NormalId.Right, 12), 'Metro', 'METRO', K.trainBlue, FONT.title, 0.06, 0.88, P.white, 2)
	-- the escalator: a solid grey body under the slope, a dark step band on it, blue glass sides with black rails, a
	-- landing onto the deck
	local x0, x1 = R.xb + 0.4, R.xb + 4.4
	local y0 = P.street.kerb
	local run, rise = zLow - zHigh, y - y0
	local zl, zh = top - zLow, top - zHigh
	g:wedge('Escalator', V(x1 - x0, rise, run), CFrame.new((x0 + x1) / 2, y0 + rise / 2, (zl + zh) / 2), K.concrete, M.SmoothPlastic)
	local a, b = V(0, y0, zl), V(0, y, zh)
	local len = (b - a).Magnitude
	local up = CFrame.lookAt((a + b) / 2, b)
	decor(g:part('EscalatorSteps', V(x1 - x0 - 1.2, 0.2, len), CFrame.new((x0 + x1) / 2, 0, 0) * up * CFrame.new(0, 0.1, 0), K.lantern, M.SmoothPlastic)).CastShadow = false
	for _, x in { x0 + 0.25, x1 - 0.25 } do
		local side = g:part('EscalatorSide', V(0.3, 2.4, len), CFrame.new(x, 0, 0) * up * CFrame.new(0, 1.3, 0), K.water, M.Glass)
		side.Transparency, side.CastShadow = 0.35, false
		decor(g:part('EscalatorRail', V(0.5, 0.4, len), CFrame.new(x, 0, 0) * up * CFrame.new(0, 2.6, 0), K.lantern, M.SmoothPlastic)).CastShadow = false
	end
	sbox(g, 'EscalatorLanding', V(R.xb - 0.2, y - 2.2, zh), V(x1, y, zh + 4), K.concrete)
	return g
end

---------------------------------------------------------------------------------------------- Luxury District
-- A palm (pos: its foot): a trunk of six chunky segments leaning a little, two tones, a crown of seven drooping fronds,
-- three coconuts.
function City.palm(c, pos, seed, s)
	local K = City.D
	local r = Random.new(seed or 1)
	s = s or 1
	local g = c:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber() * math.pi * 2, 0)):group('Palm')
	local lean = 0.12 + r:NextNumber() * 0.12
	local x, y = 0, 0
	for k = 1, 6 do
		local w = (1.5 - k * 0.06) * s
		sbox(g, 'PalmTrunk', V(x - w / 2, y, -w / 2), V(x + w / 2, y + 2.1 * s, w / 2), k % 2 == 0 and K.trunk or K.trunkDark)
		y += 2.1 * s
		x += lean * k * 0.35 * s
	end
	local topCf = CFrame.new(x, y + 0.2, 0)
	sbox(g, 'PalmHeart', V(x - 0.9 * s, y, -0.9 * s), V(x + 0.9 * s, y + 0.9 * s, 0.9 * s), K.frondDark)
	for k = 0, 6 do
		local a = k * math.pi * 2 / 7 + r:NextNumber() * 0.3
		local base = topCf * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-18), 0, 0)
		local col = k % 2 == 0 and K.frond or K.frondDark
		g:part('PalmFrond', V(1.4 * s, 0.35 * s, 5 * s), base * CFrame.new(0, 0, -2.5 * s), col, M.SmoothPlastic)
		g:part('PalmFrondTip', V(1.0 * s, 0.3 * s, 3 * s), base * CFrame.new(0, 0, -5 * s) * CFrame.Angles(math.rad(-38), 0, 0) * CFrame.new(0, 0, -1.4 * s), col, M.SmoothPlastic)
	end
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		g:box('Coconut', V(x + math.cos(a) * 0.7 * s - 0.4 * s, y - 0.9 * s, math.sin(a) * 0.7 * s - 0.4 * s), V(x + math.cos(a) * 0.7 * s + 0.4 * s, y - 0.1 * s, math.sin(a) * 0.7 * s + 0.4 * s), C(120, 84, 50), M.SmoothPlastic)
	end
	for _, p in g.parent:GetDescendants() do if p:IsA('BasePart') and p.Name ~= 'PalmTrunk' then decor(p) end end
	return g
end
-- A dark square planter with a pink glowing rim and a palm in it (pos: its centre on the ground).
function City.palmPlanter(c, pos, seed)
	local K = City.D
	local g = c:at(CFrame.new(pos)):group('PalmPlanter')
	sbox(g, 'PlanterBox', V(-2.6, 0, -2.6), V(2.6, 1.6, 2.6), K.luxPlanter)
	decor(g:box('PlanterNeon', V(-2.75, 1.6, -2.75), V(2.75, 1.85, 2.75), K.pink, M.Neon)).CastShadow = false
	decor(sbox(g, 'PlanterSoil', V(-2.2, 1.6, -2.2), V(2.2, 1.9, 2.2), C(110, 84, 64)))
	City.palm(g, V(0, 1.9, 0), seed, 0.85)
	return g
end
-- The red BOSS gateway over the run just before gate 16 (stage 15, z' zp): two red towers on the strips, a lintel over
-- the street with BOSS on it (facing the way you come), steady red neon round it.
function City.bossGate(d, top, zp)
	local K = City.D
	local g = d:group('BossGate')
	local z0, z1 = top - zp - 2, top - zp + 2
	local red, dark = C(226, 40, 52), C(150, 24, 36)
	for _, s in { -1, 1 } do
		local a, b = s * 22.5, s * 27.5
		sbox(g, 'BossTower', V(math.min(a, b), -0.5, z0), V(math.max(a, b), 36, z1), red)
		sbox(g, 'BossTowerBase', V(math.min(a, b) - 0.5, -0.5, z0 - 0.5), V(math.max(a, b) + 0.5, 2.5, z1 + 0.5), dark)
		local e = s * 22
		decor(g:box('BossNeon', V(math.min(e, e + s * 0.5) , 2.5, z1 - 0.2), V(math.max(e, e + s * 0.5), 30, z1 + 0.3), C(255, 60, 70), M.Neon)).CastShadow = false
	end
	sbox(g, 'BossLintel', V(-27.5, 30, z0), V(27.5, 38, z1), red)
	decor(g:box('BossNeon', V(-22.4, 29.6, z1 - 0.2), V(22.4, 30.1, z1 + 0.3), C(255, 60, 70), M.Neon)).CastShadow = false
	local sign = g:box('BossSign', V(-11, 31, z1), V(11, 37, z1 + 0.3), dark, M.SmoothPlastic)
	decor(sign).CastShadow = false
	line(surface(sign, Enum.NormalId.Back, 10), 'Boss', 'BOSS', P.white, FONT.title, 0.04, 0.92, C(120, 0, 20), 4)
	return g
end
