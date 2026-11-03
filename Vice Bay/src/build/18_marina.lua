-- 18 Vice Bay Marina (rebuild of the basin x 1000..1640, z 652..1060; the breakwater + lighthouse from 11 stay).
-- Luxury superyacht marina: travertine quay with palms, gated aluminium gangways, white concrete floating
-- pontoons with numbered finger berths, service pedestals and lights, a fixed superyacht pier with three
-- 130-240 stud superyachts, the Vice Bay Yacht Club (glass pavilion, rooftop bar + helipad), the yacht dealer,
-- harbour master tower and a fuel dock.
return function(L)
	local M, C = L.M, L.C
	local G, W = L.G, L.WATER
	local VB = L.folder(workspace, "ViceBay")
	local MA = L.folder(L.folder(VB, "Landmarks"), "Marina")
	for _, c in ipairs(MA:GetChildren()) do if c.Name ~= "Lighthouse" then c:Destroy() end end
	for _, n in ipairs({ "Marina Dock A", "Marina Dock B", "Marina Dock C", "Marina Dock D" }) do
		local p = VB:FindFirstChild("POIs") and VB.POIs:FindFirstChild(n)
		if p then p:Destroy() end
	end
	L.seed(1818)
	local WHITE = C(244, 244, 240)
	local TRAV = C(222, 210, 190)
	local QZ = 652 -- quay edge
	-- ===== 1. the quay: travertine promenade, planters with royal palms, bollards, benches, lamps =====
	local quay = L.model(MA, "Quay")
	L.P(quay, Vector3.new(640, 1, 16), CFrame.new(1320, G + 0.2, QZ - 8), TRAV, M.CeramicTiles, "PlazaTiles") -- Riverwalk Dr sidewalk ends at z 634
	L.P(quay, Vector3.new(640, 8, 2), CFrame.new(1320, G - 3.6, QZ - 1), C(206, 202, 194), M.Concrete, "ConcretePlain")
	L.D(quay, Vector3.new(640, 0.3, 1.2), CFrame.new(1320, G + 0.85, QZ - 0.8), C(180, 170, 152), M.Marble, "LobbyMarble")
	for x = 1010, 1630, 36 do
		L.B(quay, CFrame.new(x, G + 0.7, QZ - 9), 0, 0, 0, 5, 2.4, 5, C(200, 192, 178), M.Concrete, "BoardFormedConcrete")
		L.palm(quay, Vector3.new(x, G + 3.1, QZ - 9), L.r(34, 42), "royal")
		L.B(quay, CFrame.new(x + 18, G + 0.7, QZ - 2.5), 0, 0, 0, 1.4, 2, 1.4, C(40, 40, 42), M.Metal)
		local lp = CFrame.new(x + 18, G + 0.7, QZ - 12)
		L.Cyl(quay, 14, 0.5, lp * CFrame.new(0, 7, 0), C(40, 40, 42), M.Metal)
		L.D(quay, Vector3.new(1.6, 0.6, 1.6), lp * CFrame.new(0, 14.2, 0), C(255, 236, 200), M.Neon)
		if (x // 36) % 2 == 0 then L.bench(quay, CFrame.new(x + 9, G + 0.7, QZ - 7)) end
	end
	-- ===== 2. pontoon spines with finger berths =====
	local spines = { { x = 1130, name = "A" }, { x = 1300, name = "B" } }
	local Z0, Z1 = QZ + 14, 960
	local yachts, boats, open = 0, 0, 0
	for si, sp in ipairs(spines) do
		local cf0 = CFrame.new(sp.x, W, Z0) * CFrame.Angles(0, math.pi, 0) -- runs toward +Z (south)
		L.pontoon(MA, cf0, Z1 - Z0, 10, { name = "Pontoon" .. sp.name, berth = 26 })
		-- gangway from the quay: aluminium ramp with rails + a glass security gate with a card reader
		local ga = Vector3.new(sp.x, G + 0.9, QZ - 2)
		local gb = Vector3.new(sp.x, W + 2.2, Z0 + 2)
		local gw = L.model(MA, "Gangway" .. sp.name)
		L.P(gw, Vector3.new(5, 0.4, (gb - ga).Magnitude), CFrame.lookAt((ga + gb) / 2, gb), C(196, 198, 202), M.DiamondPlate, "MetalPlate")
		for sd = -1, 1, 2 do L.bar(gw, ga + Vector3.new(sd * 2.5, 3.4, 0), gb + Vector3.new(sd * 2.5, 3.4, 0), 0.25, C(220, 222, 226), M.Metal) end
		local gc = CFrame.new(sp.x, G + 0.7, QZ - 6)
		for sd = -1, 1, 2 do L.B(gw, gc, sd * 4.2, 0, 0, 1.2, 8, 1.2, C(30, 30, 32), M.Metal) end
		L.B(gw, gc, 0, 7, 0, 9.6, 1, 1.2, C(30, 30, 32), M.Metal)
		L.B(gw, gc, 0, 0, 0, 7, 6, 0.2, C(170, 200, 210), M.Glass, nil, { Transparency = 0.5, CanCollide = false })
		local gs = L.BD(gw, gc, 0, 7.1, -0.65, 9, 0.8, 0.1, C(30, 30, 32), M.Metal)
		L.label(gs, Enum.NormalId.Front, "PONTOON " .. sp.name .. "  •  OWNERS & GUESTS ONLY", { font = Enum.Font.GothamMedium, color = C(222, 196, 140), light = 0.2 })
		L.B(gw, gc, 4.2, 3, -0.8, 0.6, 1, 0.3, C(20, 20, 20), M.Metal)
		L.D(gw, Vector3.new(0.3, 0.3, 0.1), gc * CFrame.new(4.2, 3.8, -0.98), C(60, 255, 120), M.Neon)
		-- finger piers (concrete, 28 long) on both sides every 26, numbered
		local n = 0
		for z = Z0 + 20, Z1 - 12, 26 do
			for _, sd in ipairs({ -1, 1 }) do
				if not (si == 1 and sd < 0 and z < 845) then -- keep clear of the yacht club deck
					n += 1
					local fc = CFrame.new(sp.x + sd * (5 + 14), W, z)
					L.P(MA, Vector3.new(28, 1.8, 3.4), fc * CFrame.new(0, 0.9, 0), C(214, 212, 206), M.Concrete, "ConcretePlain")
					L.D(MA, Vector3.new(28, 0.5, 0.4), fc * CFrame.new(0, 0.9, 1.9), C(40, 40, 42), M.Rubber)
					L.D(MA, Vector3.new(28, 0.5, 0.4), fc * CFrame.new(0, 0.9, -1.9), C(40, 40, 42), M.Rubber)
					local tag = L.D(MA, Vector3.new(3, 0.05, 2), fc * CFrame.new(sd * 12, 1.83, 0), WHITE, M.SmoothPlastic, nil, { Transparency = 1 })
					L.label(tag, Enum.NormalId.Top, string.format("%s%02d", sp.name, n), { font = Enum.Font.GothamBlack, color = C(30, 60, 110), light = 1, rot = sd > 0 and 90 or -90 })
					L.D(MA, Vector3.new(0.5, 0.5, 1.4), fc * CFrame.new(sd * 13, 2.1, 1.2), C(230, 230, 232), M.Metal)
					-- the berth (between this finger and the next one): yacht, sport boat or empty
					local r = L.rng:NextNumber()
					-- most berths stay EMPTY so players can park the yachts they drive; a few boats for life
					local len = (r < 0.12) and L.r(44, 54) or L.r(24, 34)
					local bc = CFrame.new(sp.x + sd * (6.5 + len / 2), W, z + 13) * CFrame.Angles(0, sd > 0 and math.pi / 2 or -math.pi / 2, 0)
					if r < 0.12 then
						L.yacht(MA, bc, len, "motor")
						yachts += 1
					elseif r < 0.3 then
						L.boat(MA, bc, len, L.pick({ WHITE, C(30, 30, 34), C(20, 50, 90), WHITE, C(200, 196, 186) }))
						boats += 1
					else
						-- open berth for a player's yacht (tagged so the boat system can park / spawn here)
						local bp = Instance.new("Part")
						bp.Name = "MarinaBerth"
						bp.Anchored, bp.CanCollide, bp.CanTouch, bp.Transparency = true, false, false, 1
						bp.Size = Vector3.new(60, 8, 22)
						bp.CFrame = CFrame.new(sp.x + sd * (6.5 + 30), W, z + 13)
						bp:SetAttribute("Berth", string.format("%s%02d", sp.name, n))
						game:GetService("CollectionService"):AddTag(bp, "MarinaBerth")
						bp.Parent = MA
						open += 1
					end
				end
			end
		end
		L.poi(Vector3.new(sp.x, G, QZ - 8), "Dock", "Marina Pontoon " .. sp.name)
	end
	-- ===== 3. superyacht pier (fixed, 18 wide) with three superyachts alongside =====
	local PX = 1470
	local pier = L.model(MA, "SuperyachtPier")
	L.P(pier, Vector3.new(18, 2.4, 330), CFrame.new(PX, G - 0.6, QZ + 165), C(214, 210, 202), M.Concrete, "ConcretePlain")
	L.D(pier, Vector3.new(14, 0.1, 326), CFrame.new(PX, G + 0.65, QZ + 165), TRAV, M.CeramicTiles, "PlazaTiles")
	for z = QZ + 10, QZ + 320, 30 do
		for _, sd in ipairs({ -1, 1 }) do
			L.B(pier, CFrame.new(PX + sd * 7.6, G + 0.6, z), 0, 0, 0, 1.6, 1.8, 1.6, C(40, 40, 42), M.Metal)
			L.P(pier, Vector3.new(3, 16, 3), CFrame.new(PX + sd * 7.6, G - 9, z), C(150, 146, 136), M.Concrete)
		end
		local lp = CFrame.new(PX, G + 0.6, z + 15)
		L.Cyl(pier, 12, 0.5, lp * CFrame.new(0, 6, 0), C(40, 40, 42), M.Metal)
		L.D(pier, Vector3.new(1.6, 0.6, 1.6), lp * CFrame.new(0, 12.2, 0), C(255, 236, 200), M.Neon)
		L.B(pier, CFrame.new(PX + 6, G + 0.6, z + 8), 0, 0, 0, 1.4, 4, 1.4, WHITE, M.SmoothPlastic)
		L.D(pier, Vector3.new(1.5, 0.5, 1.5), CFrame.new(PX + 6, G + 4.9, z + 8), C(40, 140, 220), M.Neon)
	end
	local function superyacht(len, zc, side, nm)
		local y = L.yacht(pier, CFrame.new(PX, W, zc), len, "super")
		if not y then return end
		local cfm, sz = y:GetBoundingBox()
		local beam = math.min(sz.X, sz.Z)
		local off = side * (9 + beam / 2 + 1.5)
		y:PivotTo(y:GetPivot() + Vector3.new(PX + off - cfm.X, 0, 0))
		y.Name = nm
		-- passerelle (gangway) from the pier onto the aft deck
		local a = Vector3.new(PX + side * 8.5, G + 0.7, zc + len * 0.32)
		local b = Vector3.new(PX + side * 14, G + 4, zc + len * 0.32)
		L.P(pier, Vector3.new(3, 0.3, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C(230, 232, 236), M.Metal)
		local plate = L.D(pier, Vector3.new(10, 3, 0.2), CFrame.new(PX + side * 8.9, G + 3, zc + len * 0.25) * CFrame.Angles(0, side * math.pi / 2, 0), C(20, 24, 30), M.Metal)
		L.label(plate, Enum.NormalId.Front, nm, { font = Enum.Font.Merriweather, color = C(222, 196, 140), light = 0.2 })
		L.supercar(pier, CFrame.new(PX - side * 2, G + 0.7, zc + len * 0.32 - 10), nil, false)
	end
	superyacht(240, QZ + 160, 1, "M/Y VICE ROYALE")
	superyacht(150, QZ + 95, -1, "M/Y SOL")
	superyacht(130, QZ + 255, -1, "M/Y CORAL")
	L.poi(Vector3.new(PX, G, QZ + 30), "Dock", "Superyacht Pier")
	L.poi(Vector3.new(PX, G, QZ + 60), "Job", "Superyacht Deckhand", { Job = "Deckhand", Pay = 85 })

	-- ===== 4. Vice Bay Yacht Club on the west deck (on piles) =====
	local pc = CFrame.new(1054, G, 740) -- clear of the widened Marina Way
	local club = L.model(MA, "ViceBayYachtClub")
	L.P(club, Vector3.new(84, 2, 170), pc * CFrame.new(0, -0.4, 0), C(206, 202, 194), M.Concrete, "ConcretePlain")
	L.D(club, Vector3.new(82, 0.1, 168), pc * CFrame.new(0, 0.65, 0), TRAV, M.CeramicTiles, "PlazaTiles")
	for x = -38, 38, 19 do for z = -80, 80, 20 do L.P(club, Vector3.new(2.4, 16, 2.4), pc * CFrame.new(x, -9, z), C(150, 146, 136), M.Concrete) end end
	-- glass pavilion (two storeys), white slabs with deep overhangs, wood soffits
	local bc = pc * CFrame.new(-6, 0.7, -38)
	L.P(club, Vector3.new(56, 0.6, 50), bc * CFrame.new(0, 0.3, 0), C(232, 228, 220), M.Marble, "LobbyMarble")
	for _, lv in ipairs({ { 0, 14 }, { 15, 12 } }) do
		local y0, h = lv[1], lv[2]
		local GC = C(150, 180, 190)
		local panes = {
			{ Vector3.new(21, h, 0.4), CFrame.new(-15.5, 0, -23) }, { Vector3.new(21, h, 0.4), CFrame.new(15.5, 0, -23) },
			{ Vector3.new(52, h, 0.4), CFrame.new(0, 0, 23) }, { Vector3.new(0.4, h, 46), CFrame.new(-26, 0, 0) }, { Vector3.new(0.4, h, 46), CFrame.new(26, 0, 0) },
		}
		if y0 > 0 then panes[1] = { Vector3.new(52, h, 0.4), CFrame.new(0, 0, -23) } panes[2] = nil end
		for _, pn in pairs(panes) do
			local gl = L.P(club, pn[1], bc * pn[2] * CFrame.new(0, y0 + h / 2 + 0.6, 0), GC, M.Glass, nil, { Transparency = 0.55, Reflectance = 0.2 })
			if L.glassFaces then L.windowGrid(gl, Enum.NormalId.Front, { col = 6, row = h }) L.windowGrid(gl, Enum.NormalId.Back, { col = 6, row = h }) L.windowGrid(gl, Enum.NormalId.Left, { col = 6, row = h }) L.windowGrid(gl, Enum.NormalId.Right, { col = 6, row = h }) end
		end
		if y0 > 0 then L.P(club, Vector3.new(52, 0.8, 46), bc * CFrame.new(0, y0 + 0.2, 0), C(232, 228, 220), M.Marble, "LobbyMarble") end
		L.P(club, Vector3.new(62, 1.4, 56), bc * CFrame.new(0, y0 + h + 1.3, 2), WHITE, M.Concrete, "ConcretePlain")
		L.D(club, Vector3.new(61, 0.1, 55), bc * CFrame.new(0, y0 + h + 0.55, 2), C(170, 128, 86), M.WoodPlanks, "WoodPlanksOld")
		L.D(club, Vector3.new(62.2, 0.25, 0.25), bc * CFrame.new(0, y0 + h + 0.6, 30), C(255, 226, 180), M.Neon)
	end
	L.P(club, Vector3.new(8, 32, 10), bc * CFrame.new(-24, 16, 18), C(196, 186, 168), M.Sandstone, "DowntownStoneBlocks")
	-- door gap through the ground-floor glass (front), reception, lounge, bar
	local gate = L.D(club, Vector3.new(8, 10, 0.4), bc * CFrame.new(0, 5.6, -23.2), C(30, 30, 32), M.Metal, nil, { Transparency = 1 })
	local sgn = L.P(club, Vector3.new(34, 3.4, 0.4), bc * CFrame.new(0, 31.5, -26.2), C(20, 24, 30), M.Metal)
	L.label(sgn, Enum.NormalId.Front, "VICE BAY YACHT CLUB", { font = Enum.Font.Merriweather, color = C(222, 196, 140), light = 0.1, bright = 1.4, dist = 700 })
	local F = L.F
	if F then
		F.rug(club, bc * CFrame.new(0, 0.6, 4), 22, 14)
		F.sofa(club, bc * CFrame.new(-6, 0.6, 8), 12)
		F.sofa(club, bc * CFrame.new(-6, 0.6, 0) * CFrame.Angles(0, math.pi, 0), 12)
		F.coffeeTable(club, bc * CFrame.new(-6, 0.6, 4), 5, 3)
		F.armchair(club, bc * CFrame.new(6, 0.6, 4) * CFrame.Angles(0, -math.pi / 2, 0))
		for k = 0, 3 do F.plant(club, bc * CFrame.new(-22 + k * 14, 0.6, 20), 1.4) end
		F.art(club, bc * CFrame.new(-17.8, 8, 18) * CFrame.Angles(0, math.pi / 2, 0), 8, 5)
		for k = 0, 2 do F.pendant(club, bc * CFrame.new(-10 + k * 10, 10.5, 4), k == 1) end
	end
	-- bar counter + stools
	local bar = bc * CFrame.new(14, 0.6, 12)
	L.B(club, bar, 0, 0, 0, 3, 3.8, 18, C(30, 30, 32), M.Marble, "LobbyMarble")
	L.B(club, bar, 0, 3.8, 0, 3.6, 0.3, 18.4, C(232, 228, 220), M.Marble, "LobbyMarble")
	L.D(club, Vector3.new(0.2, 0.3, 17), bar * CFrame.new(-1.6, 0.3, 0), C(255, 200, 120), M.Neon)
	for k = -3, 3 do
		local st = bar * CFrame.new(-3.4, 0, k * 2.6)
		L.B(club, st, 0, 2.6, 0, 1.6, 0.3, 1.6, C(150, 110, 70), M.Wood)
		L.B(club, st, 0, 0, 0, 0.2, 2.6, 0.2, C(196, 160, 90), M.Metal)
	end
	L.B(club, bar, 5, 0, 0, 1.4, 9, 18, C(80, 56, 40), M.WoodPlanks, "WoodPlanksOld")
	for k = -3, 3 do L.D(club, Vector3.new(0.6, 1.4, 0.6), bar * CFrame.new(4.2, 6 + (k % 2) * 1.6, k * 2.4), L.pick({ C(120, 160, 90), C(200, 160, 80), C(160, 60, 60), C(230, 230, 220) }), M.Glass, nil, { Transparency = 0.2 }) end
	L.poi((bar * CFrame.new(-4, 0, 0)).Position, "Job", "Yacht Club Bartender", { Job = "Bartender", Pay = 55 })
	-- rooftop: bar terrace with umbrellas + helipad
	local roofY = 15 + 12 + 2
	for k = 0, 3 do L.umbrella(club, bc * CFrame.new(-18 + k * 9, roofY, -14)) end
	L.helipad(club, bc * CFrame.new(10, roofY, 6), 30, 3)
	local rail = function(a, b) L.bar(club, a, b, 0.25, C(220, 222, 226), M.Metal) L.P(club, Vector3.new(0.15, 3, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -1.6, 0), C(170, 200, 210), M.Glass, nil, { Transparency = 0.6 }) end
	local yR = (bc * CFrame.new(0, roofY + 3.4, 0)).Y
	rail(Vector3.new(bc.X - 30, yR, bc.Z - 25), Vector3.new(bc.X + 30, yR, bc.Z - 25))
	rail(Vector3.new(bc.X - 30, yR, bc.Z + 29), Vector3.new(bc.X + 30, yR, bc.Z + 29))
	L.poi((bc * CFrame.new(10, roofY, 6)).Position, "Helipad", "Yacht Club Helipad", {}, { iconDist = 900 })
	-- restaurant terrace on the deck facing the berths: tables + umbrellas, infinity pool along the edge
	for k = 0, 5 do
		local tc = pc * CFrame.new(24 + (k % 2) * 8, 0.7, -50 + k * 10)
		L.B(club, tc, 0, 0, 0, 0.4, 2.8, 0.4, C(30, 30, 32), M.Metal)
		L.B(club, tc, 0, 2.8, 0, 3.6, 0.2, 3.6, WHITE, M.Marble)
		L.umbrella(club, tc)
	end
	L.BD(club, pc, -6, 0.5, 30, 60, 0.3, 14, C(40, 170, 200), M.Glass, nil, { Transparency = 0.15, CanCollide = false })
	L.BD(club, pc, -6, 0.45, 30, 61, 0.1, 15, C(30, 110, 140), M.SmoothPlastic)
	for k = -2, 2 do L.B(club, pc * CFrame.new(-6 + k * 10, 0.7, 42), 0, 0, 0, 2.4, 0.9, 6, WHITE, M.Fabric) end
	-- yacht dealer showroom (south end of the deck)
	local sc = pc * CFrame.new(-4, 0.7, 64)
	L.P(club, Vector3.new(60, 0.4, 36), sc * CFrame.new(0, 0.2, 0), C(236, 232, 226), M.Marble, "LobbyMarble")
	local sg = L.P(club, Vector3.new(60, 16, 36), sc * CFrame.new(0, 8.4, 0), C(150, 190, 200), M.Glass, nil, { Transparency = 0.6, CanCollide = false })
	L.P(club, Vector3.new(64, 1.4, 40), sc * CFrame.new(0, 17, 0), WHITE, M.Concrete, "ConcretePlain")
	L.boat(club, sc * CFrame.new(-12, 1.2, 0) * CFrame.Angles(0, 0.5, 0), 30, C(30, 30, 34))
	L.boat(club, sc * CFrame.new(14, 1.2, 0) * CFrame.Angles(0, -0.4, 0), 26, WHITE)
	local ds = L.P(club, Vector3.new(36, 3, 0.4), sc * CFrame.new(0, 19.4, -18), C(20, 24, 30), M.Metal)
	L.label(ds, Enum.NormalId.Front, "VICE BAY YACHTS & BOATS", { font = Enum.Font.Merriweather, color = C(222, 196, 140), light = 0.1, dist = 600 })
	L.poi(sc.Position, "Dealer", "Vice Bay Yachts & Boats", { Tier = 5, PriceMin = 40000, PriceMax = 6000000 })

	-- ===== 5. harbour master tower + fuel dock (south-west) =====
	local hm = CFrame.new(1090, G, 990)
	L.P(MA, Vector3.new(40, 2, 34), hm * CFrame.new(0, -0.4, 0), C(206, 202, 194), M.Concrete, "ConcretePlain")
	for x = -16, 16, 16 do for z = -14, 14, 14 do L.P(MA, Vector3.new(2.4, 16, 2.4), hm * CFrame.new(x, -9, z), C(150, 146, 136), M.Concrete) end end
	L.B(MA, hm, -8, 0.6, 0, 16, 28, 14, WHITE, M.Plaster, "StuccoWhite")
	local tg = L.P(MA, Vector3.new(18, 8, 16), hm * CFrame.new(-8, 32.6, 0), C(120, 160, 180), M.Glass, nil, { Transparency = 0.4 })
	L.P(MA, Vector3.new(20, 1, 18), hm * CFrame.new(-8, 37.1, 0), WHITE, M.Concrete)
	L.Cyl(MA, 10, 0.5, hm * CFrame.new(-8, 42.6, 0), C(200, 200, 204), M.Metal)
	L.D(MA, Vector3.new(1, 1, 1), hm * CFrame.new(-8, 47.8, 0), C(255, 60, 60), M.Neon, nil, { Shape = Enum.PartType.Ball })
	L.storeSign(MA, hm * CFrame.new(-8, 22, -7.4), 14, "HARBOUR MASTER", { style = "classy", blade = false, h = 2.4 })
	L.poi((hm * CFrame.new(-8, 0, -10)).Position, "Job", "Boat Tours Captain", { Job = "Captain", Pay = 75 })
	local fd = CFrame.new(1090, W, 1022)
	L.pontoon(MA, fd * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 30), 60, 10, { berth = 20, name = "FuelDock" })
	for k = -1, 1 do
		local pcf = CFrame.new(1090 + k * 16, W + 2.1, 1019)
		L.B(MA, pcf, 0, 0, 0, 2, 5, 1.4, WHITE, M.Metal)
		L.BD(MA, pcf, 0, 3, -0.75, 1.6, 1, 0.1, C(200, 30, 30), M.SmoothPlastic)
		L.B(MA, pcf, 0, 0, 0.9, 0.3, 3, 0.3, C(30, 30, 30), M.Rubber)
	end
	local fs = L.P(MA, Vector3.new(20, 3, 0.4), hm * CFrame.new(12, 8, 16), C(200, 30, 30), M.SmoothPlastic)
	L.label(fs, Enum.NormalId.Back, "MARINE FUEL  •  DIESEL  •  GAS", { font = Enum.Font.GothamBlack, color = WHITE, light = 0.2 })
	L.B(MA, hm, 12, 0.6, 16, 0.8, 10, 0.8, C(60, 60, 64), M.Metal)
	L.poi(Vector3.new(1090, G, 1015), "Gas", "Marina Fuel Dock")
	-- tenders + jet skis rafted on the fuel pontoon
	for k = 0, 2 do L.boat(MA, CFrame.new(1070 + k * 18, W, 1036) * CFrame.Angles(0, math.pi / 2, 0), 16, L.pick({ WHITE, C(240, 200, 40), C(30, 30, 34) })) end

	local parts = 0
	for _, d in ipairs(MA:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return string.format("marina: yachts %d boats %d open berths %d parts %d", yachts, boats, open, parts)
end
