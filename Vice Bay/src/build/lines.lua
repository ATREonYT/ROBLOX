-- Vice Bay mainland street plan (one network so every junction is real)
-- returns the list of polylines; L.net(lines) turns it into a graph
return function(L)
	local lines = {}
	local rng = Random.new(305)
	local function ln(style, pts, o)
		o = o or {}
		local t = { style = style, pts = pts, name = o.name, cul = o.cul, cul0 = o.cul0, w = o.w }
		table.insert(lines, t)
		return t
	end
	-- crooked street: straight run with small sideways jogs (hood streets are never ruler-straight)
	local function wob(x0, z0, x1, z1, n, amp)
		local pts = { { x0, z0 } }
		local dx, dz = x1 - x0, z1 - z0
		local len = math.sqrt(dx * dx + dz * dz)
		local px, pz = -dz / len, dx / len
		for k = 1, n - 1 do
			local t = k / n + (rng:NextNumber() - 0.5) * 0.08
			local o = (rng:NextNumber() - 0.5) * 2 * amp
			table.insert(pts, { x0 + dx * t + px * o, z0 + dz * t + pz * o })
		end
		table.insert(pts, { x1, z1 })
		return pts
	end
	L.wob = wob

	-- ========== LIBERTY HEIGHTS (hood) x -1790..-935 ==========
	-- boundary avenues
	ln("GLADES", { { -1790, -1110 }, { -1790, 1100 } }, { name = "Glades Rd" })
	ln("HOODA", { { -935, -1110 }, { -935, 1100 } }, { name = "Railroad Ave" })
	ln("HOODA", { { -1370, -1110 }, { -1374, -700 }, { -1366, -130 }, { -1370, 300 }, { -1368, 1100 } }, { name = "Liberty Blvd" })
	ln("HOOD", { { -1790, -1110 }, { -1500, -1112 }, { -935, -1110 } }, { name = "Shore Rd W" })
	ln("HOODA", { { -1790, -830 }, { -935, -830 } }, { name = "North Ave W" })
	ln("HOODA", { { -1790, -410 }, { -935, -410 } }, { name = "Flagler St W" })
	ln("HOODA", { { -1790, -130 }, { -1500, -136 }, { -1200, -124 }, { -935, -130 } }, { name = "Liberty Ave" })
	-- river bank roads (river runs ~z 150-260 here)
	ln("HOOD", { { -1790, 126 }, { -1750, 130 }, { -1450, 82 }, { -1150, 140 }, { -935, 190 } }, { name = "N River Dr W" })
	ln("HOOD", { { -1790, 272 }, { -1450, 222 }, { -1150, 282 }, { -935, 332 } }, { name = "S River Dr W" })
	-- minor east-west streets (crooked)
	-- (streets were widened for full-size cars: every other minor street became a narrow back alley)
	ln("ALLEY", wob(-1790, -975, -935, -978, 4, 4), { name = "NW 79 Alley" })
	ln("HOOD", wob(-1790, -690, -935, -694, 4, 7), { name = "NW 71 St" })
	ln("ALLEY", wob(-1790, -552, -935, -550, 4, 4), { name = "NW 66 Alley" })
	ln("ALLEY", wob(-1790, -268, -935, -270, 4, 4), { name = "NW 58 Alley" })
	ln("ALLEY", wob(-1790, 6, -935, 12, 5, 4), { name = "NW 50 Alley" })
	-- minor north-south streets (north of the river)
	ln("HOOD", { { -1650, -1110 }, { -1655, -830 }, { -1642, -410 }, { -1652, -130 }, { -1648, 102 } }, { name = "NW 17 Ave" })
	ln("HOOD", { { -1230, -1110 }, { -1238, -552 }, { -1226, -130 }, { -1232, 130 } }, { name = "NW 10 Ave" })
	-- cul-de-sacs into the deep blocks
	ln("HOOD", { { -1580, -410 }, { -1576, -486 } }, { cul = true, name = "Palm Ct" })
	-- south of the river
	ln("HOOD", wob(-1790, 420, -935, 430, 4, 6), { name = "NW 36 St" })
	ln("HOODA", { { -1790, 560 }, { -935, 560 } }, { name = "NW 20 St W" })
	ln("ALLEY", wob(-1790, 700, -935, 704, 4, 4), { name = "NW 14 Alley" })
	ln("HOOD", wob(-1790, 830, -935, 834, 4, 6), { name = "NW 11 St" })
	ln("HOOD", { { -1650, 240 }, { -1646, 560 }, { -1652, 960 } }, { name = "NW 17 Ave S" })
	ln("HOOD", { { -1230, 270 }, { -1226, 560 }, { -1232, 960 } }, { name = "NW 10 Ave S" })

	-- ========== PORT DISTRICT z 960..1140 ==========
	ln("PORT", { { -1790, 960 }, { -935, 960 }, { -720, 960 }, { -100, 960 } }, { name = "Port Blvd" })
	ln("PORT", { { -1790, 1080 }, { -100, 1080 } }, { name = "Port Rd" })
	ln("PORT", { { -500, 960 }, { -500, 1080 } }, { name = "Dock St" })
	ln("PORT", { { -130, 890 }, { -130, 1080 } }, { name = "Terminal Way" })

	-- ========== TRACKS + I-95 CORRIDOR x -930..-748: only a few streets cross ==========
	ln("HABA", { { -935, -1110 }, { -720, -1110 } }, { name = "Shore Rd X" })
	ln("HABA", { { -935, -830 }, { -720, -830 } }, { name = "North Ave X" })
	ln("HABA", { { -935, -410 }, { -720, -410 } }, { name = "Flagler St X" })
	ln("HOOD", { { -935, 190 }, { -720, 250 } }, { name = "N River Dr X" })
	ln("HOODA", { { -935, 560 }, { -720, 560 } }, { name = "NW 20 St X" })

	-- I-95 at-grade ends (the elevated part is built by 06_highway)
	ln("HWYE", { { -810, -1110 }, { -810, -1066 } }, { name = "I-95 N End" })
	ln("HWYE", { { -810, -1110 }, { -810, -1170 } }, { name = "Sol Expressway Ramp" })
	ln("HWYE", { { -810, 960 }, { -810, 930 } }, { name = "I-95 S End" })

	-- ========== WYNWOOD / MIDTOWN (north of river) x -720..300 ==========
	ln("HABA", { { -720, -1110 }, { -720, 960 } }, { name = "I-95 Frontage Rd" })
	ln("WYNA", { { -720, -1110 }, { 300, -1110 } }, { name = "Shore Rd" })
	ln("WYNA", { { -720, -830 }, { 300, -830 } }, { name = "North Ave" })
	ln("WYNA", { { -720, -410 }, { 300, -410 } }, { name = "Flagler St" })
	ln("WYN", { { -720, -975 }, { 300, -975 } }, { name = "NW 36 St" })
	ln("WYN", { { -720, -690 }, { 300, -690 } }, { name = "NW 29 St" })
	ln("WYN", { { -720, -552 }, { -80, -552 } }, { name = "NW 26 St" })
	ln("WYN", { { -720, -270 }, { -80, -270 } }, { name = "NW 22 St" })
	ln("WYN", { { -720, -130 }, { -80, -130 } }, { name = "NW 20 St" })
	ln("WYN", { { -720, 10 }, { 300, 10 } }, { name = "NW 17 St" })
	ln("WYN", { { -720, 250 }, { -400, 310 }, { -100, 360 }, { 200, 412 }, { 300, 432 } }, { name = "N River Dr" })
	ln("WYN", { { -560, -1110 }, { -560, 280 } }, { name = "NW 5 Ave" })
	ln("WYN", { { -400, -1110 }, { -400, 310 } }, { name = "NW 3 Ave" })
	ln("WYN", { { -240, -1110 }, { -240, 334 } }, { name = "NW 2 Ave" })
	ln("WYNA", { { -80, -1110 }, { -80, 364 } }, { name = "Miami Ave" })
	ln("WYN", { { 80, -1110 }, { 80, -690 } }, { name = "NE 2 Ave N" })
	ln("WYN", { { 80, 10 }, { 80, 392 } }, { name = "NE 2 Ave S" })
	-- Bayside Central Park fills x -80..300, z -690..10 (Flagler crosses it as a park drive)
	ln("BLVD", { { 300, -1110 }, { 300, 650 } }, { name = "Biscayne Blvd" })

	-- ========== LITTLE HABANA (south of river) x -720..300 ==========
	ln("HAB", { { -720, 390 }, { -400, 450 }, { -100, 500 }, { 200, 552 }, { 300, 572 } }, { name = "S River Dr" })
	ln("HABA", { { -935, 650 }, { -720, 650 }, { 300, 650 } }, { name = "Calle Ocho" })
	ln("HAB", { { -720, 780 }, { 300, 780 } }, { name = "SW 9 St" })
	ln("HAB", { { -720, 890 }, { 300, 890 } }, { name = "SW 11 St" })
	ln("HAB", { { -560, 420 }, { -560, 960 } }, { name = "SW 17 Ave" })
	ln("HAB", { { -400, 450 }, { -400, 960 } }, { name = "SW 15 Ave" })
	ln("HAB", { { -240, 476 }, { -240, 960 } }, { name = "SW 12 Ave" })
	ln("HAB", { { 80, 532 }, { 80, 890 } }, { name = "SW 8 Ave" })
	ln("HAB", { { 220, 546 }, { 220, 890 } }, { name = "SW 6 Ave" })

	-- ========== DOWNTOWN (on the beach) x 300..1440 ==========
	ln("BLVD", { { 1440, -1110 }, { 1440, 600 } }, { name = "Ocean Blvd" })
	ln("DT", { { 300, -1110 }, { 1440, -1110 } }, { name = "Shore Rd E" })
	ln("DTS", { { 300, -980 }, { 1440, -980 } }, { name = "NE 14 St" })
	ln("DT", { { 300, -830 }, { 1440, -830 } }, { name = "North Ave E" })
	ln("DTS", { { 300, -620 }, { 1440, -620 } }, { name = "NE 8 St" })
	ln("DT", { { 300, -410 }, { 1440, -410 } }, { name = "Flagler St E" })
	ln("DTS", { { 300, -200 }, { 700, -200 } }, { name = "NE 3 St W" })
	ln("DTS", { { 900, -200 }, { 1440, -200 } }, { name = "NE 3 St E" })
	ln("DT", { { 300, 0 }, { 1440, 0 } }, { name = "SE 1 St" })
	ln("DTS", { { 300, 200 }, { 1440, 200 } }, { name = "SE 4 St" })
	ln("DT", { { 500, 400 }, { 1440, 400 } }, { name = "SE 8 St" })
	ln("DTS", { { 300, 432 }, { 500, 490 }, { 760, 552 }, { 1000, 600 }, { 1440, 600 } }, { name = "Riverwalk Dr" })
	ln("DTS", { { 500, -1110 }, { 500, 490 } }, { name = "NE 2 Ave E" })
	ln("DT", { { 700, -1110 }, { 700, 540 } }, { name = "Brickell Ave" })
	ln("DT", { { 900, -1110 }, { 900, 580 } }, { name = "Bayfront Ave" })
	ln("DTS", { { 1100, -1110 }, { 1100, 600 } }, { name = "Collins Ave" })
	ln("DT", { { 1290, -1110 }, { 1290, 600 } }, { name = "Washington Ave" })
	-- south bank by the river mouth (marina side)
	ln("HAB", { { 300, 650 }, { 500, 632 }, { 760, 692 }, { 960, 752 } }, { name = "Quay Rd" })
	ln("HAB", { { 960, 752 }, { 960, 990 } }, { name = "Marina Way" })
	ln("HAB", { { 300, 890 }, { 960, 890 } }, { name = "Harbor St" })
	return lines
end
