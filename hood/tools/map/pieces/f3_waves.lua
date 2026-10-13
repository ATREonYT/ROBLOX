---------------------------------------------------------------------------------------------- stage crews' hangouts
-- Brief 18: every stage holds a crew of cartoon rival goons (Shared/EnemyRules: who and where; each player's client draws
-- its own goons, Shared/GoonRig, and the server runs them, WaveService). The map only dresses the spot each crew hangs out
-- at, so the street reads as their turf: a milk crate with a boombox on it (two speaker cones, a cassette deck, a
-- stripe in the crew's colour), a second crate to sit on, a few soda cans, and a paint splat in the crew's colour on
-- the sidewalk. Nothing here blocks the street: everything stands on the sidewalk beside the crew (|x| 10..16) or on
-- the court, behind the goons' line. (brief 30: the warehouse has no armchair: its strongest is just a strong enemy.)
-- (The old cartoon target waves are gone; HoodClient/Waves hides any a map built before brief 18 still carries.)
local Waves = {}
Waves.Ground = 0.6 -- the sidewalk top (P.street.kerb)
Waves.Crew = {
	Red = C(222, 58, 58), Green = C(64, 182, 96), Purple = C(140, 76, 214), Orange = C(255, 146, 44), Yellow = C(255, 214, 56), Boss = C(255, 202, 64),
}
Waves.Wood = { lit = C(232, 196, 140), dark = C(136, 86, 48) }

-- Parts: a cylinder lying along the frame's Z (a disc facing -Z), an upright cylinder standing on a point.
function Waves.disc(c, name, r, thick, centre, color, material)
	return decor(c:part(name, V(thick, 2 * r, 2 * r), CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.can(c, name, r, h, foot, color, material)
	return decor(c:part(name, V(h, 2 * r, 2 * r), CFrame.new(foot + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.trim(c, name, a, b, color) return decor(c:box(name, a, b, color, M.SmoothPlastic)) end

-- A blue milk crate (slots on its sides, a darker rim), from y0, its footprint centred on the frame's origin.
function Waves.crate(c, y0, color)
	local blue = color or C(52, 98, 204)
	local rim = blue:Lerp(C(0, 0, 0), 0.3)
	local h = 1.5
	sbox(c, 'MilkCrate', V(-1.3, y0, -1.0), V(1.3, y0 + h, 1.0), blue)
	Waves.trim(c, 'MilkCrateRim', V(-1.36, y0 + h - 0.25, -1.06), V(1.36, y0 + h, 1.06), rim)
	for _, x in { -0.75, 0, 0.75 } do
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, -1.04), V(x + 0.24, y0 + 0.95, -1.0), rim:Lerp(C(0, 0, 0), 0.3))
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, 1.0), V(x + 0.24, y0 + 0.95, 1.04), rim:Lerp(C(0, 0, 0), 0.3))
	end
	return y0 + h
end

-- A big boombox (front -Z): charcoal case, a lighter face plate, two speaker cones in chrome rims, a cassette deck,
-- four coloured buttons, a chrome carry handle and a stripe in the crew's colour.
function Waves.boombox(c, y0, stripe)
	local y1 = y0 + 2.5
	decor(c:box('Case', V(-2.1, y0, -0.5), V(2.1, y1, 0.55), C(50, 52, 62), M.SmoothPlastic))
	Waves.trim(c, 'FacePlate', V(-1.98, y0 + 0.12, -0.58), V(1.98, y1 - 0.12, -0.5), C(74, 78, 92))
	Waves.trim(c, 'Stripe', V(-2.12, y0 + 0.18, -0.6), V(2.12, y0 + 0.42, 0.57), stripe)
	local cy = (y0 + y1) / 2 + 0.1
	for _, x in { -1.18, 1.18 } do
		Waves.disc(c, 'SpeakerRim', 0.98, 0.1, V(x, cy, -0.6), C(204, 208, 218))
		Waves.disc(c, 'Grille', 0.86, 0.1, V(x, cy, -0.63), C(34, 36, 44))
		Waves.disc(c, 'Cone', 0.5, 0.1, V(x, cy, -0.67), C(70, 72, 84))
		Waves.disc(c, 'DustCap', 0.2, 0.1, V(x, cy, -0.71), C(150, 154, 166))
	end
	Waves.trim(c, 'Deck', V(-0.5, cy - 0.05, -0.62), V(0.5, cy + 0.6, -0.56), C(30, 32, 40))
	Waves.trim(c, 'Cassette', V(-0.36, cy + 0.08, -0.66), V(0.36, cy + 0.46, -0.6), C(222, 222, 228))
	for k, col in { C(236, 64, 64), C(250, 206, 56), C(70, 200, 100), C(70, 140, 240) } do
		local x = -0.6 + (k - 1) * 0.4
		Waves.trim(c, 'Button', V(x - 0.13, y1, -0.35), V(x + 0.13, y1 + 0.16, -0.05), col)
	end
	local chrome = C(204, 208, 218)
	for _, x in { -1.4, 1.4 } do Waves.trim(c, 'HandlePost', V(x - 0.14, y1, -0.12), V(x + 0.14, y1 + 0.62, 0.16), chrome) end
	Waves.trim(c, 'Handle', V(-1.54, y1 + 0.5, -0.14), V(1.54, y1 + 0.78, 0.18), chrome)
end

-- A paint splat on the ground in the crew's colour (three overlapping blobs and two drips, a white rim), lying flat.
function Waves.splat(c, y, color)
	local rim = C(250, 250, 252)
	local blobs = { { 0, 0, 2.2 }, { 1.1, 0.6, 1.4 }, { -0.9, -0.7, 1.2 } }
	for k, b in blobs do
		decor(c:part('SplatRim', V(0.04, b[3] + 0.3, b[3] + 0.3), CFrame.new(b[1], y + 0.02, b[2]) * CFrame.Angles(0, 0, math.pi / 2), rim, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		decor(c:part('Splat', V(0.05, b[3], b[3]), CFrame.new(b[1], y + 0.03 + k * 0.001, b[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
	for _, d in { { 1.9, 1.3, 0.5 }, { -1.8, 0.9, 0.4 } } do
		decor(c:part('Drip', V(0.05, d[3], d[3]), CFrame.new(d[1], y + 0.03, d[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- One crew's hangout, at the frame `cf` (on the sidewalk; its -Z faces the street): the boombox on its crate, a crate to
-- sit on beside it, three soda cans, the splat in front.
function Waves.hangout(c, cf, crew)
	local h = c:at(cf)
	local color = Waves.Crew[crew] or Waves.Crew.Red
	local top = Waves.crate(h, Waves.Ground)
	Waves.boombox(h, top, color)
	local seat = h:at(CFrame.new(3.4, 0, 0.4) * CFrame.Angles(0, math.rad(12), 0))
	Waves.crate(seat, Waves.Ground, C(236, 120, 40))
	for k, col in { C(226, 54, 60), C(62, 188, 98), C(52, 118, 226) } do
		Waves.can(h, 'SodaCan', 0.24, 0.62, V(-2.0 + k * 0.42, Waves.Ground, -1.4 + (k % 2) * 0.3), col)
	end
	Waves.splat(h:at(CFrame.new(-3.4, 0, -0.3)), Waves.Ground, color)
end

-- The boss's armchair (front -Z): big red cushions, gold trim, on four stubby gold feet.
function Waves.throne(c, cf)
	local t = c:at(cf)
	local red, deep, gold = C(208, 40, 52), C(150, 24, 36), C(255, 202, 64)
	local y = 0.06
	for _, x in { -2.6, 2.6 } do for _, z in { -1.8, 1.8 } do sbox(t, 'Foot', V(x - 0.3, y, z - 0.3), V(x + 0.3, y + 0.6, z + 0.3), gold) end end
	sbox(t, 'Seat', V(-3, y + 0.6, -2.2), V(3, y + 2.2, 2.2), red)
	Waves.trim(t, 'SeatPiping', V(-3.05, y + 2.0, -2.25), V(3.05, y + 2.25, 2.25), gold)
	sbox(t, 'Back', V(-3, y + 2.2, 1.2), V(3, y + 7.2, 2.2), deep)
	Waves.trim(t, 'BackPiping', V(-3.05, y + 7.0, 1.15), V(3.05, y + 7.4, 2.25), gold)
	for _, x in { -3, 2.2 } do
		sbox(t, 'Arm', V(x, y + 2.2, -2.2), V(x + 0.8, y + 4.0, 1.2), red)
		Waves.trim(t, 'ArmPiping', V(x - 0.05, y + 3.85, -2.25), V(x + 0.85, y + 4.1, 1.25), gold)
	end
	Waves.trim(t, 'Cushion', V(-2.2, y + 2.2, -2.0), V(2.2, y + 2.7, 1.2), C(236, 70, 82))
	-- a gold crown badge on the backrest
	Waves.trim(t, 'CrownBase', V(-0.9, y + 5.2, 1.12), V(0.9, y + 5.6, 1.2), gold)
	for _, x in { -0.75, 0, 0.75 } do Waves.trim(t, 'CrownPoint', V(x - 0.18, y + 5.6, 1.12), V(x + 0.18, y + 6.3, 1.2), gold) end
end

-- Where each stage's hangout goes: on the sidewalk of the side most of the crew stands toward, a few steps in front of
-- the nearest of them (clear of the next gate's pads, which fill the sidewalks from z' ~48), or on the court where the
-- Courts' crews hang out.
function Waves.spotFor(spots, stage)
	local sx, near = 0, math.huge
	for _, s in spots do sx += s[1]; near = math.min(near, s[2]) end
	sx = sx / #spots
	if stage >= 10 and stage <= 12 then return 33, near - 5, 1 end -- (on the court, by the two there)
	local side = sx >= 0 and 1 or -1
	if stage >= 7 and stage <= 9 then return side * 12.9, near - 7, side end -- (the Alley: tight against the wall)
	return side * 12.8, near - 7, side
end

function Waves.build(ctx)
	-- (Optional: a place or src without Shared.EnemyRules builds without the hangouts instead of stopping the build.)
	local module = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('EnemyRules')
	local ok, rules = false, nil
	if module then ok, rules = pcall(require, module) end
	if not ok or type(rules) ~= 'table' then
		warn('[TheBlockV2] No Shared.EnemyRules: crew hangouts skipped')
		return nil
	end
	Waves.Rules = rules
	local all = ctx:group('Waves')
	for stage = 1, STAGES do
		local spots = rules.Spots[stage]
		if spots then
			local g = all:group('Hangout' .. stage)
			local x, zp, side = Waves.spotFor(spots, stage)
			local top = stageTop(stage)
			-- turned to face across the street (toward the crew), a few degrees off square
			local yaw = (side > 0 and math.pi / 2 or -math.pi / 2) + math.rad((stage * 7) % 9 - 4)
			Waves.hangout(g, CFrame.new(x, 0, top - zp) * CFrame.Angles(0, yaw, 0), rules.Crews[stage])
		end
	end
	return all
end
V2.Waves = Waves -- (the unit tests and integ_waves read it)
