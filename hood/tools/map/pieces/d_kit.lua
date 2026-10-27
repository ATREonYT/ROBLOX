---------------------------------------------------------------------------------------------- asset kit
-- The concept's "Asset Kit (simple Roblox parts)". All positions are in the given context's frame.
local function plank(c, name, a, b, width, thick, color, material)
	return c:part(name, V(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or M.SmoothPlastic)
end

-- The reference street's props (ref1_street.png): chunky blocks, studded on every face, sized from the picture.
-- A studded box between two corners (the street kit's only brick).
local function sbox(c, name, a, b, color, isDecor)
	local p = studs(c:box(name, a, b, color, M.Plastic), true)
	if isDecor then decor(p) end
	return p
end
-- Tree of stacked green cubes on a short grey trunk, measured from the picture (top ~15.8 above the grass, crown
-- ~7 wide and ~12 tall, trunk ~3 wide and ~3.8 tall): three tiers that step in and wander a little, darker below and
-- lighter toward the sunlit top, a cap, a thin side block, and a soil pit round the trunk. seed varies it; yaw
-- (degrees) turns it (the picture's trees stand at an angle to the street).
local function tree(c, pos, seed, scale, yaw, simple)
	local r = Random.new(seed)
	local s = scale or 1
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or r:NextInteger(0, 3) * 90), 0)):group('Tree')
	local leaf, dark = P.st.leaf, P.st.leafDark
	local function B(name, a, b, col) return sbox(t, name, a * s, b * s, col) end
	local function off() return r:NextInteger(-1, 1) * 0.5 end
	if not simple then -- (simple: the ring road's trees behind the buildings skip the small parts)
		decor(sbox(t, 'TreePit', V(-2.4, -0.05, -2.4) * s, V(2.4, 0.15, 2.4) * s, C(110, 84, 64)))
		B('TrunkRing', V(-1.7, 0, -1.7), V(1.7, 0.7, 1.7), P.st.trunk:Lerp(P.black, 0.2))
	end
	B('Trunk', V(-1.5, 0, -1.5), V(1.5, 3.8, 1.5), P.st.trunk)
	B('Crown', V(-3.5, 3.8, -3.5), V(3.5, 8.6, 3.5), dark)
	local x2, z2 = off(), off()
	B('Crown', V(-3 + x2, 8.6, -3 + z2), V(3 + x2, 12.4, 3 + z2), leaf)
	local x3, z3 = x2 + off(), z2 + off()
	B('Crown', V(-2.2 + x3, 12.4, -2.2 + z3), V(2.2 + x3, 14.8, 2.2 + z3), leaf:Lerp(P.white, 0.1))
	B('CrownTop', V(-1.3 + x3, 14.8, -1.3 + z3), V(1.3 + x3, 15.8, 1.3 + z3), leaf:Lerp(P.white, 0.16))
	if not simple then B('CrownSide', V(3.5, 6.6, -1.5), V(4.3, 10.6, 1.5), dark:Lerp(P.black, 0.08)) end
	return t
end
-- Low hedge of two stacked green blocks (the ones on the reference's grass), long along Z: a darker lower block on a
-- dark green foot, a lighter top block.
local function hedge(c, pos, len)
	len = len or 6
	local h = c:at(CFrame.new(pos)):group('Hedge')
	decor(sbox(h, 'HedgeFoot', V(-1.8, -0.05, -len / 2 - 0.2), V(1.8, 0.3, len / 2 + 0.2), P.st.grassEdge))
	sbox(h, 'Hedge', V(-1.6, 0, -len / 2), V(1.6, 2.2, len / 2), P.st.hedge:Lerp(P.black, 0.08))
	sbox(h, 'Hedge', V(-1.2, 2.2, -len / 2), V(1.2, 3.8, len / 2 - 2), P.st.hedge:Lerp(P.st.leaf, 0.5):Lerp(P.white, 0.06))
	return h
end
-- Wooden plank fence along Z at x from z0 to z1 (the picture's front-yard fence, ~8 tall): 2-stud planks, 1 thick,
-- alternating light / dark wood (the light ones in two tones), every other plank stepped toward the street (side = the
-- street's direction, +1 or -1), each capped with a steep wedge that slopes down toward the street, heights jittered;
-- a dark post with a light cap every four planks. gaps = { { za, zb } } (world z) leave gateways: a tall post either
-- side and a plank gate standing open into the yard.
local function fence(c, x, z0, z1, side, h, gaps)
	h = h or 6.8
	local f = c:group('Fence')
	local n = math.max(1, math.floor(math.abs(z1 - z0) / 2 + 0.5))
	local w = (z1 - z0) / n
	local function inGap(za, zb)
		for _, g in gaps or {} do
			if math.max(za, zb) > math.min(g[1], g[2]) + 0.05 and math.min(za, zb) < math.max(g[1], g[2]) - 0.05 then return true end
		end
		return false
	end
	-- (Oct 27 review) an invisible keep-in cap over each run of planks, from just under their tops to 40 up (like
	-- City.court's): nobody stands on the fence and drops into a yard strip behind it that has no way back out (World 1's
	-- Stage 1, the strip between the right fence and the house; tools/checks/city_reach.luau with REACH_MAP)
	local runA, runB = nil, nil
	local function cap()
		if not runA then return end
		local lo, hi = x - 0.9 + math.min(0, side * 0.5), x + 0.9 + math.max(0, side * 0.5)
		local p = f:box('Boundary', V(lo, h - 0.6, math.min(runA, runB)), V(hi, 40, math.max(runA, runB)), P.white, M.SmoothPlastic)
		p.Transparency = 1
		p.CastShadow = false
		runA = nil
	end
	for k = 0, n - 1 do
		local za, zb = z0 + k * w, z0 + (k + 1) * w
		if inGap(za, zb) then cap() else runA, runB = runA or za, zb end
		if not inGap(za, zb) then
			local col = P.st.fence[k % #P.st.fence + 1]
			local xm = x + (k % 2 == 1 and side * 0.5 or 0)
			local hk = h + ((k * 7) % 3 - 1) * 0.4
			sbox(f, 'FencePlank', V(xm - 0.5, 0, za), V(xm + 0.5, hk, zb), col)
			-- (a wedge rises toward its local +Z: turn that away from the street)
			studs(f:wedge('FencePlankTop', V(math.abs(w), 1.8, 1), CFrame.new(xm, hk + 0.9, (za + zb) / 2) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0), col, M.Plastic), true)
			if k % 4 == 0 and k > 0 and not inGap(za - 1, za + 1) then
				local p0, p1 = x - 0.7 + math.min(0, side * 0.5), x + 0.7 + math.max(0, side * 0.5)
				sbox(f, 'FencePost', V(p0, 0, za - 0.7), V(p1, h + 2.2, za + 0.7), P.st.plankDark)
				sbox(f, 'FencePostCap', V(p0 - 0.2, h + 2.2, za - 0.9), V(p1 + 0.2, h + 2.7, za + 0.9), P.st.fence[1], true)
			end
		end
	end
	cap()
	for _, g in gaps or {} do
		local ga, gb = math.min(g[1], g[2]), math.max(g[1], g[2])
		for _, zp in { ga, gb } do
			sbox(f, 'GatePost', V(x - 0.8, 0, zp - 0.8), V(x + 0.8, h + 3, zp + 0.8), P.st.plankDark)
			sbox(f, 'GatePostCap', V(x - 1.0, h + 3, zp - 1.0), V(x + 1.0, h + 3.6, zp + 1.0), P.st.fence[1], true)
		end
		-- the gate leaf, hinged on the far post and swung ~70 degrees into the yard
		local leaf = f:at(CFrame.new(x, 0, gb - 0.8) * CFrame.Angles(0, side * math.rad(70), 0))
		local len = gb - ga - 1.8
		sbox(leaf, 'GateLeaf', V(-0.3, 0.8, -len), V(0.3, h - 0.4, 0), P.st.fence[3], true)
		for _, y in { 2, h - 1.8 } do sbox(leaf, 'GateBatten', V(-0.45, y, -len + 0.2), V(0.45, y + 0.6, -0.2), P.st.plankDark, true) end
	end
	return f
end
-- Low white picket fence along Z (a front-garden boundary): pointed pickets on two rails, square posts with caps every
-- ~6 studs; gaps = { { za, zb } } leave gateways between posts. side = the street's direction.
local function picketFence(c, x, z0, z1, side, gaps)
	local f = c:group('PicketFence')
	local white, rail = C(240, 240, 234), C(206, 206, 200)
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local function inGap(z)
		for _, g in gaps or {} do if z > math.min(g[1], g[2]) - 0.6 and z < math.max(g[1], g[2]) + 0.6 then return true end end
		return false
	end
	-- rails run between gaps
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			for _, y in { 1.4, 3.2 } do decor(f:box('PicketRail', V(x - side * 0.25 - 0.2, y, a), V(x - side * 0.25 + 0.2, y + 0.4, b), rail, M.Plastic)) end
			for z = a, b + 0.01, math.max(1, (b - a) / math.max(1, math.floor((b - a) / 6 + 0.5))) do
				sbox(f, 'PicketPost', V(x - 0.5, 0, z - 0.5), V(x + 0.5, 4.8, z + 0.5), white)
				sbox(f, 'PicketPostCap', V(x - 0.65, 4.8, z - 0.65), V(x + 0.65, 5.2, z + 0.65), rail, true)
			end
		end
	end
	for z = za + 0.9, zb - 0.6, 1.25 do
		if not inGap(z) then
			sbox(f, 'Picket', V(x - 0.2, 0, z - 0.35), V(x + 0.2, 3.9, z + 0.35), white)
			f:wedge('PicketTip', V(0.4, 0.6, 0.7), CFrame.new(x, 4.2, z) * CFrame.Angles(0, math.pi / 2, 0), white, M.SmoothPlastic)
		end
	end
	return f
end
-- Low brick garden wall along Z with a stone coping and an iron railing on top; brick piers with stone caps and ball
-- finials at its ends and either side of each gateway (gaps = { { za, zb } }). side = the street's direction.
local function gardenWall(c, x, z0, z1, side, gaps)
	local f = c:group('GardenWall')
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			sbox(f, 'GardenWall', V(x - 0.6, 0, a), V(x + 0.6, 3.0, b), P.st.brickDark)
			sbox(f, 'GardenCoping', V(x - 0.85, 3.0, a), V(x + 0.85, 3.45, b), P.st.trim)
			for z = a + 1, b - 0.9, 1.6 do decor(f:box('GardenRailBar', V(x - 0.1, 3.45, z - 0.1), V(x + 0.1, 5.4, z + 0.1), P.iron, M.Plastic)) end
			decor(f:box('GardenRail', V(x - 0.15, 5.2, a), V(x + 0.15, 5.5, b), P.iron, M.Plastic))
		end
	end
	for _, z in cuts do
		sbox(f, 'GardenPier', V(x - 1.0, 0, z - 1.0), V(x + 1.0, 4.4, z + 1.0), P.st.brick)
		sbox(f, 'GardenPierCap', V(x - 1.2, 4.4, z - 1.2), V(x + 1.2, 4.9, z + 1.2), P.st.trim, true)
		decor(f:part('GardenFinial', V(1.1, 1.1, 1.1), CFrame.new(x, 5.45, z), P.st.trim, M.Plastic, Enum.PartType.Ball))
	end
	return f
end
-- Tall street lamp (~27 studs) in three navy tones: a dark plinth, a studded base block with a lighter service
-- door, a square pole with two dark collars, a cap and finial, and a 1-stud arm out over the sidewalk (a rising strut,
-- then level) ending in a small head with a lighter rim and a thin warm light under its tip. dir points at the road.
local function lantern(c, pos, dir)
	dir = dir or V(1, 0, 0)
	local l = c:at(CFrame.lookAt(pos, pos - dir)):group('Lamp') -- (lookAt's -Z points away from the road: the arm runs along local +Z)
	local col, dark, lite = P.st.lamp, P.st.lampDark, P.st.lampLight
	sbox(l, 'LampPlinth', V(-2.1, -0.2, -2.1), V(2.1, 0.7, 2.1), dark)
	sbox(l, 'LampBase', V(-1.7, 0.7, -1.7), V(1.7, 2.8, 1.7), col)
	sbox(l, 'LampDoor', V(-0.7, 1.0, 1.7), V(0.7, 2.4, 1.85), lite, true)
	sbox(l, 'LampPole', V(-0.9, 2.8, -0.9), V(0.9, 26.4, 0.9), col)
	for _, y in { 6, 21.6 } do sbox(l, 'LampCollar', V(-1.15, y, -1.15), V(1.15, y + 0.6, 1.15), dark, true) end
	sbox(l, 'LampCap', V(-1.2, 26.4, -1.2), V(1.2, 27.4, 1.2), dark)
	sbox(l, 'LampFinial', V(-0.5, 27.4, -0.5), V(0.5, 28.2, 0.5), col, true)
	studs(decor(l:bar('LampStrut', V(0, 22.4, 0.6), V(0, 25.2, 4), 1, col, M.Plastic)), true)
	sbox(l, 'LampArm', V(-0.5, 24.7, 3.4), V(0.5, 25.7, 10.4), col, true)
	sbox(l, 'LampHead', V(-0.7, 24.6, 8.2), V(0.7, 25.9, 10.9), col, true)
	sbox(l, 'LampHeadRim', V(-0.8, 24.25, 8.0), V(0.8, 24.6, 11.1), lite, true)
	decor(l:box('LampGlow', V(-0.45, 24.1, 9.4), V(0.45, 24.25, 10.7), P.st.lampGlow, M.Neon)).CastShadow = false
	return l
end
-- Small flower: a green stem and four dark blue petals round a yellow eye (~2 wide, 2.6 tall).
local function flower(c, pos, seed)
	local r = Random.new(seed or 1)
	local f = c:at(CFrame.new(pos) * CFrame.Angles(math.rad(r:NextNumber(-8, 8)), math.rad(r:NextNumber(0, 90)), math.rad(r:NextNumber(-8, 8)))):group('Flower')
	decor(f:box('Stem', V(-0.25, 0, -0.25), V(0.25, 2.1, 0.25), P.st.stem, M.Plastic))
	decor(f:box('Leaf', V(0.25, 0.7, -0.2), V(0.9, 1.0, 0.2), P.st.stem, M.Plastic))
	decor(f:box('Petal', V(-1.1, 2.1, -0.4), V(1.1, 2.5, 0.4), P.st.petal, M.Plastic))
	decor(f:box('Petal', V(-0.4, 2.1, -1.1), V(0.4, 2.5, 1.1), P.st.petal, M.Plastic))
	decor(f:box('Eye', V(-0.3, 2.5, -0.3), V(0.3, 2.7, 0.3), P.st.petalEye, M.Plastic))
	return f
end
-- Tuft of grass blades (three thin green sticks).
local function tuft(c, pos, seed)
	local r = Random.new(seed or 1)
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(r:NextNumber(0, 180)), 0)):group('Tuft')
	for k, d in { V(-0.5, 0, 0), V(0.1, 0, 0.3), V(0.6, 0, -0.2) } do
		local hgt = 1.0 + k * 0.25
		decor(t:part('Blade', V(0.28, hgt, 0.28), CFrame.new(d + V(0, hgt / 2, 0)) * CFrame.Angles(math.rad(r:NextNumber(-12, 12)), 0, math.rad(r:NextNumber(-12, 12))), P.st.grass:Lerp(P.black, 0.18), M.Plastic))
	end
	return t
end
-- The reference's big green dumpster (8 long along Z, 5 deep, 6 tall), studded, in three greens: the body, two
-- darker ribs down the front and a darker rim; side bars, black wheels, rubbish heaped over it in small orange, brown
-- and dark bits, and its lid flung open from the back (+X) edge, leaning out over the street side. The front, the
-- street side, faces local -X.
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local col, dark = P.st.dumpster, P.st.dumpsterDark
	sbox(d, 'DumpsterBody', V(-2.5, 0.7, -4), V(2.5, 5.6, 4), col)
	sbox(d, 'DumpsterRim', V(-2.8, 5.2, -4.3), V(2.8, 6.0, 4.3), dark, true)
	for _, z in { -1.6, 1.6 } do sbox(d, 'DumpsterRib', V(-2.75, 0.9, z - 0.4), V(-2.5, 5.2, z + 0.4), dark, true) end
	for _, z in { -4.25, 4.0 } do sbox(d, 'DumpsterBar', V(-1.6, 3.6, z), V(1.6, 4.1, z + 0.25), P.st.gutter, true) end
	for _, x in { -1.8, 1.8 } do
		for _, z in { -3.2, 3.2 } do decor(d:part('DumpsterWheel', V(0.6, 1.1, 1.1), CFrame.new(x, 0.55, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	decor(d:box('DumpsterInside', V(-2.3, 5.5, -3.8), V(2.3, 5.9, 3.8), C(52, 44, 40), M.Plastic))
	local r = Random.new(7)
	local bits = { P.st.garbage, P.st.garbage, C(120, 76, 46), C(60, 56, 54), C(250, 170, 60) }
	for k = 1, 14 do
		local x, z, sz = r:NextNumber(-1.9, 1.6), r:NextNumber(-3.3, 3.0), r:NextNumber(0.6, 1.1)
		decor(d:box('Rubbish', V(x, 5.8, z), V(x + sz, 5.9 + r:NextNumber(0.3, 0.9), z + sz), bits[k % #bits + 1], M.Plastic)).CastShadow = false
	end
	-- the lid, hinged on the back top edge, leaning ~25 degrees past upright toward the street
	local lid = d:at(CFrame.new(2.8, 6.0, 0) * CFrame.Angles(0, 0, math.rad(-65)))
	sbox(lid, 'DumpsterLid', V(-5.4, 0, -4.3), V(0, 0.5, 4.3), dark, true)
	sbox(lid, 'DumpsterLidRib', V(-4.6, 0.5, -3.6), V(-0.6, 0.8, 3.6), col, true)
	return d
end
-- Hood street furniture, in the same chunky studded style. Fire hydrant: red barrel on a darker foot, collar and cap,
-- side nozzles and a silver front cap.
local function hydrant(c, pos)
	local h = c:at(CFrame.new(pos)):group('Hydrant')
	local red, dark = C(226, 56, 48), C(168, 36, 34)
	sbox(h, 'HydrantFoot', V(-1, 0, -1), V(1, 0.5, 1), dark)
	sbox(h, 'HydrantBody', V(-0.7, 0.5, -0.7), V(0.7, 2.6, 0.7), red)
	sbox(h, 'HydrantCollar', V(-0.85, 2.6, -0.85), V(0.85, 2.9, 0.85), dark)
	sbox(h, 'HydrantCap', V(-0.5, 2.9, -0.5), V(0.5, 3.5, 0.5), red)
	sbox(h, 'HydrantNozzles', V(-1.1, 1.5, -0.35), V(1.1, 2.1, 0.35), dark, true)
	sbox(h, 'HydrantFront', V(-0.35, 1.45, -1.05), V(0.35, 2.15, -0.7), C(206, 208, 214), true)
	return h
end
-- A heap of black trash bags: lumpy studded blocks, each tied off with a small knot.
local function trashBags(c, cf, n)
	local t = c:at(cf):group('TrashBags')
	local spots = { { 0, 0, 0, 2.2, 1.8 }, { 1.7, 0, 0.9, 1.8, 1.5 }, { 0.6, 1.6, 0.4, 1.7, 1.4 }, { -1.5, 0, 0.6, 1.6, 1.4 } }
	for k = 1, n or 3 do
		local s = spots[k]
		local b = t:at(CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, k * 0.7, (k % 2 - 0.5) * 0.25))
		sbox(b, 'TrashBag', V(-s[4] / 2, 0, -s[4] / 2), V(s[4] / 2, s[5], s[4] / 2), C(44, 46, 54))
		sbox(b, 'TrashBagKnot', V(-0.3, s[5], -0.3), V(0.3, s[5] + 0.5, 0.3), C(30, 32, 38), true)
	end
	return t
end
-- Wheelie bin: a dark green studded body on two wheels with a darker lid and handle (front = local -X).
local function wheelieBin(c, cf, color)
	local b = c:at(cf):group('WheelieBin')
	color = color or C(40, 120, 70)
	sbox(b, 'BinBody', V(-1.2, 0.5, -1.3), V(1.2, 3.8, 1.3), color)
	sbox(b, 'BinLid', V(-1.4, 3.8, -1.4), V(1.5, 4.2, 1.4), color:Lerp(P.black, 0.25))
	sbox(b, 'BinHandle', V(1.2, 3.4, -1.0), V(1.6, 3.8, 1.0), C(30, 32, 36), true)
	for _, z in { -0.9, 0.9 } do decor(b:part('BinWheel', V(0.5, 1, 1), CFrame.new(1.0, 0.5, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	return b
end
-- A boombox (the hood touch on a crate): black case, two silver-rimmed speakers, a handle on top (front = local -Z).
local function boombox(c, cf)
	local b = c:at(cf):group('Boombox')
	sbox(b, 'BoomboxCase', V(-1.5, 0, -0.5), V(1.5, 1.5, 0.5), C(36, 38, 44))
	for _, x in { -0.8, 0.8 } do
		decor(b:part('BoomboxSpeaker', V(0.12, 1.0, 1.0), CFrame.new(x, 0.75, -0.55) * CFrame.Angles(0, math.pi / 2, 0), C(190, 194, 202), M.Plastic, Enum.PartType.Cylinder))
		decor(b:part('BoomboxCone', V(0.14, 0.6, 0.6), CFrame.new(x, 0.75, -0.6) * CFrame.Angles(0, math.pi / 2, 0), C(60, 62, 70), M.Plastic, Enum.PartType.Cylinder))
	end
	sbox(b, 'BoomboxHandle', V(-1.1, 1.5, -0.15), V(1.1, 1.9, 0.15), C(190, 194, 202), true)
	return b
end
-- Wooden crate with darker edge planks; pallets for under them.
local function crate(c, cf, size)
	size = size or 3
	local h = size / 2
	local k = c:at(cf):group('Crate')
	k:box('Crate', V(-h, 0, -h), V(h, size, h), P.crate, M.WoodPlanks)
	for _, y in { 0.15, size - 0.45 } do k:box('CrateBand', V(-h - 0.05, y, -h - 0.05), V(h + 0.05, y + 0.3, h + 0.05), P.woodDark, M.Wood) end
	for _, x in { -h - 0.05, h - 0.25 } do k:box('CrateEdge', V(x, 0, -h - 0.05), V(x + 0.3, size, -h + 0.25), P.woodDark, M.Wood) end
	return k
end
local function pallet(c, cf)
	local p = c:at(cf):group('Pallet')
	for _, x in { -1.6, 0, 1.6 } do p:box('PalletBlock', V(x - 0.3, 0, -1.6), V(x + 0.3, 0.5, 1.6), P.woodDark, M.Wood) end
	for z = -1.6, 1.6, 0.8 do p:box('PalletSlat', V(-2, 0.5, z - 0.3), V(2, 0.8, z + 0.3), P.crate, M.WoodPlanks) end
	return p
end
-- A parked bike leaning on its stand (along local Z): black wheels with silver hubs, a coloured frame (two tubes and
-- the fork), a black seat and silver handlebar.
local function bike(c, cf, color)
	local k = c:at(cf * CFrame.Angles(0, 0, math.rad(8))):group('Bike')
	color = color or C(230, 60, 60)
	for _, z in { -1.7, 1.7 } do
		decor(k:part('BikeWheel', V(0.3, 2.3, 2.3), CFrame.new(0, 1.15, z), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder))
		decor(k:part('BikeHub', V(0.36, 0.6, 0.6), CFrame.new(0, 1.15, z), C(200, 204, 210), M.Plastic, Enum.PartType.Cylinder))
	end
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.4, -0.2), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 2.4, -0.2), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, -1.7), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.9, 1.2), 0.25, color, M.Plastic))
	decor(k:box('BikeSeat', V(-0.3, 2.5, 1.0), V(0.3, 2.75, 1.7), C(30, 30, 34), M.Plastic))
	decor(k:box('BikeBars', V(-0.9, 2.9, -1.45), V(0.9, 3.1, -1.25), C(200, 204, 210), M.Plastic))
	decor(k:bar('BikeStem', V(0, 2.5, -1.3), V(0, 2.95, -1.35), 0.25, C(200, 204, 210), M.Plastic))
	return k
end
-- Corner-store produce crates on a pallet: open wooden crates (studded, darker rims) heaped with fruit blocks.
local function storeCrates(c, cf, n)
	local k = c:at(cf):group('StoreCrates')
	pallet(k, CFrame.new())
	local fruit = { C(236, 64, 52), C(255, 170, 40), C(130, 210, 60), C(255, 222, 70) }
	local spots = { { -1.1, 0.8, -0.2 }, { 1.1, 0.8, 0.1 }, { 0, 2.4, 0 } }
	for j = 1, n or 3 do
		local p = spots[j]
		local b = k:at(CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, (j - 2) * 0.12, 0))
		sbox(b, 'Crate', V(-1.0, 0, -1.3), V(1.0, 1.6, 1.3), P.crate)
		sbox(b, 'CrateRim', V(-1.05, 1.3, -1.35), V(1.05, 1.65, 1.35), P.woodDark, true)
		for q = 0, 3 do
			local fx, fz = (q % 2) * 0.9 - 0.45, (q // 2) * 1.1 - 0.55
			decor(b:box('Fruit', V(fx - 0.4, 1.55, fz - 0.45), V(fx + 0.4, 2.1, fz + 0.45), fruit[(j + q) % #fruit + 1], M.Plastic))
		end
	end
	return k
end
-- A plywood board with a spray-painted tag, leaning back against whatever is behind it (front = local -Z):
-- the board, two darker battens and the tag.
local function graffitiBoard(c, cf, text, color)
	local k = c:at(cf * CFrame.Angles(math.rad(-10), 0, 0)):group('GraffitiBoard')
	local board = sbox(k, 'Board', V(-3, 0, -0.15), V(3, 4.6, 0.15), C(214, 172, 116))
	for _, y in { 0.8, 3.8 } do sbox(k, 'Batten', V(-3.1, y - 0.25, 0.15), V(3.1, y + 0.25, 0.4), C(160, 118, 72), true) end
	local g = surface(board, Enum.NormalId.Front, 20)
	line(g, 'Tag', text, color, FONT.tag, 0.12, 0.76, P.black, 3).Rotation = -8
	return k
end
-- Shipping container (19.6 long along local Z) with ridges down both long sides and door bars at one end.
local function container(c, cf, color)
	local k = c:at(cf):group('Container')
	k:box('ContainerBody', V(-4, 0, -9.8), V(4, 8.6, 9.8), color, M.SmoothPlastic)
	for z = -8, 8.1, 3.2 do
		for _, x in { -4.15, 4 } do k:box('ContainerRidge', V(x, 0.4, z - 0.4), V(x + 0.15, 8.2, z + 0.4), color:Lerp(P.black, 0.15), M.SmoothPlastic) end
	end
	k:box('ContainerTopRim', V(-4.1, 8.4, -9.85), V(4.1, 8.7, 9.85), color:Lerp(P.black, 0.2), M.SmoothPlastic)
	for _, x in { -1.4, 1.4 } do k:box('ContainerDoorBar', V(x - 0.12, 0.6, 9.8), V(x + 0.12, 8, 9.95), color:Lerp(P.black, 0.3), M.SmoothPlastic) end
	return k
end
-- Low-poly sedan (front toward -Z).
local function car(c, cf, color)
	local k = c:at(cf):group('Car')
	for _, x in { -2.1, 2.1 } do
		for _, z in { -3.3, 3.3 } do
			k:part('Wheel', V(0.8, 2, 2), CFrame.new(x, 1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(k:part('Hubcap', V(0.84, 1, 1), CFrame.new(x, 1, z), P.frame, M.Metal, Enum.PartType.Cylinder))
		end
	end
	k:box('CarBody', V(-2.3, 1, -5.2), V(2.3, 2.9, 5.2), color, M.SmoothPlastic)
	k:box('CarCabin', V(-2.0, 2.9, -2.0), V(2.0, 4.6, 2.8), color, M.SmoothPlastic)
	decor(k:box('CarGlass', V(-2.05, 3.1, -2.05), V(2.05, 4.4, 2.85), P.glass, M.SmoothPlastic))
	for _, z in { -5.4, 5.1 } do k:box('Bumper', V(-2.35, 0.9, z), V(2.35, 1.6, z + 0.3), P.frame, M.Metal) end
	for _, x in { -1.9, 1.0 } do
		decor(k:box('Headlight', V(x, 2.1, -5.25), V(x + 0.9, 2.6, -5.2), C(255, 244, 200), M.Neon))
		decor(k:box('TailLight', V(x, 2.1, 5.2), V(x + 0.9, 2.6, 5.25), C(220, 40, 40), M.SmoothPlastic))
	end
	return k
end
-- Chain-link fence along a straight line, with optional gaps { from, to } (distance along the line).
local function chainLink(c, a, b, h, gaps)
	local dir = b - a
	local len = dir.Magnitude
	local u = dir.Unit
	local n = math.max(1, math.ceil(len / 8))
	local posts = {}
	for k = 0, n do
		local t = len * k / n
		local open = false
		for _, g in gaps or {} do if t > g[1] - 1 and t < g[2] + 1 then open = true end end
		if not open then table.insert(posts, t) end
	end
	for _, g in gaps or {} do table.insert(posts, g[1]); table.insert(posts, g[2]) end
	for _, t in posts do c:post('FencePost', 0.25, h + 0.2, a + u * t, P.iron, M.Metal) end
	local pieces = { { 0, len } }
	for _, g in gaps or {} do
		local nextPieces = {}
		for _, p in pieces do
			if g[2] <= p[1] or g[1] >= p[2] then table.insert(nextPieces, p)
			else
				if g[1] > p[1] then table.insert(nextPieces, { p[1], g[1] }) end
				if g[2] < p[2] then table.insert(nextPieces, { g[2], p[2] }) end
			end
		end
		pieces = nextPieces
	end
	for _, p in pieces do
		if p[2] - p[1] > 0.3 then
			local p0, p1 = a + u * p[1], a + u * p[2]
			local mid, up = (p0 + p1) / 2, V(0, (h - 0.4) / 2 + 0.2, 0)
			local mesh = c:part('ChainLink', V(0.1, h - 0.4, (p1 - p0).Magnitude), CFrame.lookAt(mid + up, p1 + up), C(70, 74, 82), M.DiamondPlate)
		mesh.Name = 'ChainLink'
			mesh.Transparency = 0.45
			mesh.CastShadow = false
			decor(plank(c, 'FenceRail', p0 + V(0, h, 0), p1 + V(0, h, 0), 0.25, 0.25, P.iron, M.Metal))
		end
	end
end

-- Fight pad: a glowing coloured square with a white border and its number painted on top. hidden: only an
-- invisible marker with the same model, tag and attributes (the reference street's road has no pad on it).
local function fightPad(c, n, pos, color, district, size, label, hidden)
	size = size or PAD_SIZE
	local h = size / 2
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	model:SetAttribute('Fight', n)
	model:SetAttribute('District', district)
	model:AddTag('HoodFightPad')
	if hidden then
		local marker = ghost(pad:box('PadMarker', V(-h, 0, -h), V(h, 0.2, h), color, M.SmoothPlastic))
		marker.CastShadow = false
		return model, pad
	end
	pad:box('PadBorder', V(-h - 0.5, 0, -h - 0.5), V(h + 0.5, 0.3, h + 0.5), P.white, M.SmoothPlastic)
	local top = pad:box('Pad', V(-h + 0.3, 0, -h + 0.3), V(h - 0.3, 0.36, h - 0.3), color, M.SmoothPlastic)
	decor(pad:box('PadGlow', V(-h, 0.3, -h), V(h, 0.33, h), color:Lerp(P.white, 0.35), M.Neon)).CastShadow = false
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), P.white, FONT.loud, 0.18, 0.64, C(20, 24, 40), 6)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color, 1.2, 10, 120
	glow.Parent = top
	return model, pad
end
-- District banner: a solid coloured sign floating over the walk, readable from both sides.
local function banner(c, text, pos, color, w)
	w = w or 24
	local b = c:at(CFrame.new(pos)):group('DistrictBanner')
	local sign = b:box('Banner', V(-w / 2, 0, -0.8), V(w / 2, 7, 0.8), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local g = surface(sign, face, 20)
		pcall(function() g.MaxDistance = 80 end) -- (a stage ahead at most, so banners don't stack through the lobby door)
		line(g, 'Title', text, P.white, FONT.loud, 0.1, 0.8, color:Lerp(P.black, 0.55), 5)
	end
	return b
end

-- A pad's slab, as on the reference street: a flat slab (opts: w, d (size; default 7 x 4), y (the floor it sits on), h
-- (thickness), material (default Neon), base (colour of a thin dark plate under it, showing as a rim), shade + rim (the
-- slab's sides take the darker shade and the top gets a neon edge in rim around an inset top in the pad's colour),
-- sparkle (a few rising sparkles), arrow (+1/-1: two glowing chevrons on the top pointing along Z)). Returns the slab
-- (the only solid part) and every part it made; each carries BaseTransparency, BaseColor and BaseMaterial for the clients
-- (HoodClient/Stages dims a pad that can't pay yet).
local function padSlab(g, name, x, z, color, opts)
	local w, d, y, h = opts.w or 7, opts.d or 4, opts.y or 0, opts.h or 0.42
	local parts = {}
	if opts.base then
		table.insert(parts, decor(g:box(name .. 'Base', V(x - w / 2 - 0.3, y, z - d / 2 - 0.3), V(x + w / 2 + 0.3, y + 0.15, z + d / 2 + 0.3), opts.base, M.SmoothPlastic)))
		y += 0.15
	end
	local pad = g:box(name, V(x - w / 2, y, z - d / 2), V(x + w / 2, y + h, z + d / 2), opts.shade or color, opts.material or M.Neon)
	table.insert(parts, pad)
	if opts.rim then
		local rim = decor(g:box(name .. 'Rim', V(x - w / 2, y + h, z - d / 2), V(x + w / 2, y + h + 0.05, z + d / 2), opts.rim, M.Neon))
		rim.CastShadow = false
		local top = decor(g:box(name .. 'Top', V(x - w / 2 + 0.35, y + h + 0.05, z - d / 2 + 0.35), V(x + w / 2 - 0.35, y + h + 0.1, z + d / 2 - 0.35), color, opts.material or M.Neon))
		table.insert(parts, rim)
		table.insert(parts, top)
		-- Two glowing chevrons on the top pointing where the pad sends you (opts.arrow: +1 toward +Z, -1 toward -Z).
		if opts.arrow then
			local f = opts.arrow
			for _, za in { z + f * 0.4, z + f * 2.2 } do
				for _, sx in { -1, 1 } do
					local c = V(x + sx * 0.5, y + h + 0.12, za - f * 0.5)
					local bar = decor(g:part(name .. 'Chevron', V(0.4, 0.05, 1.5), CFrame.lookAt(c, c + V(sx, 0, -f)), opts.rim, M.Neon))
					bar.CastShadow = false
					table.insert(parts, bar)
				end
			end
		end
		if opts.sparkle then
			local sp = Instance.new('ParticleEmitter')
			sp.Name = 'PadSparkles'
			sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
			sp.Rate = 5
			sp.Lifetime, sp.Speed = NumberRange.new(0.8, 1.4), NumberRange.new(1.5, 3)
			sp.SpreadAngle = Vector2.new(12, 12)
			sp.EmissionDirection = Enum.NormalId.Top
			sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			sp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			sp.Color = ColorSequence.new(opts.rim)
			sp.LightEmission = 1
			sp.Parent = top
		end
	end
	for _, p in parts do
		p:SetAttribute('BaseTransparency', 0)
		p:SetAttribute('BaseColor', p.Color)
		p:SetAttribute('BaseMaterial', p.Material.Name)
	end
	return pad, parts, y + h
end
-- Teleport pad (a slab with a prompt; StageService handles the targets StageRules.travelTarget knows). opts as padSlab's,
-- plus title + sub (a floating label read up close, sub in labelColor, both in font) or bare (no floating label).
local function teleportPad(g, name, x, z, color, target, label, opts)
	opts = opts or {}
	local pad, _, topY = padSlab(g, name, x, z, color, opts)
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'Teleport'
	prompt.ActionText = 'Teleport'
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', target)
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	if opts.title then
		-- Read up close only: HoodClient/LabelFade fades it with the distance (kind Pad) and sets MaxDistance itself.
		local anchor = ghost(g:part(name .. 'Label', V(0.2, 0.2, 0.2), CFrame.new(x, topY + 4.6, z), P.white))
		anchor:SetAttribute('BaseTransparency', 1)
		local gui = Instance.new('BillboardGui')
		gui.Name = 'WorldLabel'
		gui.Size = UDim2.fromScale(9.5, 3.1)
		gui.MaxDistance = 45
		gui.LightInfluence = 0
		gui.Parent = anchor
		-- (the world's text face, the references' Montserrat Black, with a near-black outline)
		line(gui, 'Title', opts.title, C(240, 242, 248), opts.font or FONT.title, 0, 0.58, C(16, 18, 30), 3)
		line(gui, 'Sub', opts.sub or '', opts.labelColor or color, opts.font or FONT.title, 0.6, 0.36, C(16, 18, 30), 2)
	elseif not opts.bare then
		billboard(g, V(x, topY + 3, z), 6, 1.4, { { 'Title', label, P.white, opts.font or FONT.title, 0, 1 } }).WorldLabel.MaxDistance = 50
	end
	return pad
end
-- A stage pad (brief 23, the reference's two pads before every gate): step on it, no prompt. The slab is tagged
-- HoodStagePad with attributes Stage (the crew stage it pays for) and Kind ('Return': yellow, + the stage's Cash and back
-- to the lobby; 'TenX': magenta, 10x that with the 10x Cash pass); StageService pays and HoodClient/Stages paints it
-- (dim until the crew is down, then lit) and writes its label. opts as padSlab's, plus label: { big, small, price,
-- color } (the label's first words; the client keeps them current) and font.
-- The label (the reference's "2M Wins / 10x Wins"): a BillboardGui WorldLabel on the anchor <name>Label, big words in
-- the pad's colour over small white ones (and the pass's Robux price on the magenta pad), a thick dark outline; it fades
-- and pops with the distance (HoodClient/LabelFade, kind Pad: FadeNear / FadeFar below).
-- (CRITIC3 r2: "+10 Cash" reads from the gate you came in by, ~60 studs, as the reference's pad words read down the
-- corridor; the next stage's pads, 64 further, stay hidden)
-- (Px: a few pixels on top of the studs, so far away the words keep a readable size on screen; up close the studs rule.)
-- (brief 28: the pads stand just in front of their gate, so the label's top meets the gate sign's foot (7.4 studs up)
-- seen from the stage's entry: it sits a stud lower, with fewer extra pixels, and HoodClient/Stages lifts a far sign a
-- little, so "+100 Cash", the sign's lines and "+10 Cash" each read on their own.)
local PAD_LABEL = { W = 11, H = 4.6, PxW = 72, PxH = 22, Up = 3.4, Near = 60, Far = 80, Ink = C(26, 14, 38) }
local function stagePad(g, name, x, z, color, stage, kind, opts)
	local pad, parts, topY = padSlab(g, name, x, z, color, opts)
	pad.CanTouch = true
	pad:SetAttribute('Stage', stage)
	pad:SetAttribute('Kind', kind)
	pad:AddTag('HoodStagePad')
	local label = opts.label or {}
	local anchor = ghost(g:part(name .. 'Label', V(0.2, 0.2, 0.2), CFrame.new(x, topY + PAD_LABEL.Up, z), P.white))
	anchor:SetAttribute('BaseTransparency', 1)
	local gui = Instance.new('BillboardGui')
	gui.Name = 'WorldLabel'
	gui.Size = UDim2.new(PAD_LABEL.W, PAD_LABEL.PxW, PAD_LABEL.H, PAD_LABEL.PxH)
	gui.MaxDistance = PAD_LABEL.Far + 15
	gui.LightInfluence = 0
	gui:SetAttribute('FadeNear', PAD_LABEL.Near)
	gui:SetAttribute('FadeFar', PAD_LABEL.Far)
	gui.Parent = anchor
	local font = opts.font or FONT.title
	local big = line(gui, 'Title', label.big or '', label.color or color, font, 0, 0.52, PAD_LABEL.Ink, 3.5)
	big:SetAttribute('BaseColor', big.TextColor3)
	local small = line(gui, 'Sub', label.small or '', P.white, font, 0.5, 0.29, PAD_LABEL.Ink, 2.5)
	small:SetAttribute('BaseColor', small.TextColor3)
	local price = line(gui, 'Price', label.price or '', C(120, 236, 96), font, 0.78, 0.22, PAD_LABEL.Ink, 2)
	price.Visible = label.price ~= nil and label.price ~= ''
	return pad, parts
end
