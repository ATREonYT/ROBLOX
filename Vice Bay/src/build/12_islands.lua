-- 12 Islands. Star Island is the only one with a bridge (causeway from North Ave E across the beach).
-- Boat-only: Sunset Isles, Fisher Key (golf), Key Vice (lighthouse park), the Sandbar, Cayo Perdido (wreck), Bird Key.
return function(L)
	local M, C = L.M, L.C
	local G, W = L.G, L.WATER
	local T = workspace.Terrain
	local IS = L.folder(L.folder(workspace, "ViceBay"), "Islands")
	IS:ClearAllChildren()
	L.seed(777)
	local function island(cx, cz, rx, rz, grass)
		for x = -rx, rx, 8 do
			local hz = rz * math.sqrt(math.max(0, 1 - (x / rx) ^ 2))
			if hz > 2 then
				T:FillBlock(CFrame.new(cx + x, -12, cz), Vector3.new(8, 24, hz * 2), M.Sand)
				if grass and hz * 0.8 > 4 and math.abs(x) < rx * 0.82 then
					T:FillBlock(CFrame.new(cx + x, -2, cz), Vector3.new(8, 4, hz * 1.6), M.LeafyGrass)
				end
			end
		end
		task.wait()
	end
	local function scatterPalms(par, cx, cz, rx, rz, n, avoid)
		for _ = 1, n do
			local a, rr = L.r(0, 6.28), math.sqrt(L.r(0.05, 0.85))
			local p = Vector3.new(cx + math.cos(a) * rx * rr, G, cz + math.sin(a) * rz * rr)
			if not (avoid and avoid(p)) then L.palm(par, p, L.r(28, 44), L.chance(0.25) and "hero" or nil) end
		end
	end
	local function ringRoad(par, cx, cz, r, w)
		local pts = {}
		for k = 0, 40 do
			local a = k / 40 * math.pi * 2
			table.insert(pts, Vector3.new(cx + math.cos(a) * r, G + 0.3, cz + math.sin(a) * r))
		end
		L.road3D(par, pts, w, { name = "IslandDrive", barriers = false, lanes = 0, piers = false, var = "AsphaltPlain" })
	end

	-- ===== STAR ISLAND (bridged) =====
	local SX, SZ, SR = 2420, -830, 200
	island(SX, SZ, SR, SR, true)
	local star = L.model(IS, "StarIsland")
	ringRoad(star, SX, SZ, 110, 34)
	-- causeway: North Ave E continues across the beach and over the water
	local cw = {}
	local function smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
	for x = 1452, SX - SR + 10, 20 do
		local y = G + 0.3
		if x > 1700 and x < SX - SR - 20 then
			local t = (x - 1700) / (SX - SR - 20 - 1700)
			y = G + 0.3 + 18 * math.sin(math.pi * t) ^ 0.6
		end
		table.insert(cw, Vector3.new(x, y, -830))
	end
	table.insert(cw, Vector3.new(SX - 110 - 11, G + 0.3, -830))
	L.road3D(star, cw, 52, { name = "Star Island Causeway", median = true, lanes = 2, lights = 120, pierStep = 60, var = "AsphaltPlain" })
	L.cutSidewalk(CFrame.new(1472, G + 0.5, -830), Vector3.new(26, 3, 40))
	local LMf = workspace.ViceBay:FindFirstChild("Landmarks")
	local BEf = LMf and LMf:FindFirstChild("Beach")
	if BEf then
		for _, d in ipairs(BEf:GetDescendants()) do
			if d:IsA("Model") and d.Parent and math.abs(d:GetPivot().Position.Z + 830) < 26 and d:GetPivot().Position.X > 1450 then d:Destroy() end
		end
	end
	-- gatehouse at the island end of the causeway
	local gh = CFrame.new(SX - 140, G, -830)
	L.B(star, gh, 0, 0, -24, 10, 12, 10, C(244, 244, 240), M.Plaster, "StuccoWhite")
	L.B(star, gh, 0, 12, -24, 12, 1.2, 12, C(150, 84, 64), M.ClayRoofTiles, "RoofClayMission")
	L.sign(star, gh * CFrame.new(0, 15, -24) * CFrame.Angles(0, -math.pi / 2, 0), 16, 2.4, "STAR ISLAND", C(250, 250, 248), C(150, 120, 60), Enum.Font.Merriweather, { both = true })
	-- estates around the ring, fronts facing the drive, docks out back
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2 + 0.45
		if math.abs(math.cos(a) + 1) > 0.12 then -- keep the causeway side clear
			local p = Vector3.new(SX + math.cos(a) * 164, G, SZ + math.sin(a) * 164)
			local cf = CFrame.lookAt(p, Vector3.new(SX, G, SZ))
			local mega = (k == 2)
			L.mansion(star, cf, mega and 96 or 80, mega and 72 or 70, { dock = true, style = ({ "white", "noir", "med", "tropical", "white", "noir", "med" })[k + 1], name = mega and "Star Island Mega-Mansion" or ("Star Island Estate " .. k), price = mega and 12000000 or L.ri(4, 8) * 1000000 })
		end
	end
	scatterPalms(star, SX, SZ, 80, 80, 14)
	L.poi(Vector3.new(SX, G, SZ), "Job", "Star Island Pool & Garden", { Job = "Groundskeeper", Pay = 65 })

	-- ===== SUNSET ISLES (boat only): long strip of waterfront villas north of the city =====
	local SI = L.model(IS, "SunsetIsles")
	for x = 470, 1230, 8 do
		T:FillBlock(CFrame.new(x, -12, -1520), Vector3.new(8, 24, 184), M.Sand)
		T:FillBlock(CFrame.new(x, -2, -1520), Vector3.new(8, 4, 160), M.Grass)
	end
	L.road3D(SI, { Vector3.new(470, G + 0.3, -1520), Vector3.new(1230, G + 0.3, -1520) }, 32, { barriers = false, lanes = 0, piers = false, var = "AsphaltPlain" })
	for x = 520, 1180, 110 do
		local i = (x - 520) // 110
		L.mansion(SI, CFrame.new(x, G, -1468), 100, 68, { dock = true, name = "Sunset Isles Villa " .. (i * 2 + 1), price = 3200000 + i * 150000, style = ({ "white", "tropical", "noir", "med" })[i % 4 + 1] })
		L.mansion(SI, CFrame.new(x, G, -1572) * CFrame.Angles(0, math.pi, 0), 100, 68, { dock = true, name = "Sunset Isles Villa " .. (i * 2 + 2), price = 3400000 + i * 150000, style = ({ "med", "noir", "white", "tropical" })[i % 4 + 1] })
	end
	L.poi(Vector3.new(500, G, -1520), "Dock", "Sunset Isles Dock")

	-- ===== FISHER KEY (boat only): golf island with villas and a clubhouse =====
	local FX, FZ = 1450, 1700
	island(FX, FZ, 210, 200, true)
	local FK = L.model(IS, "FisherKey")
	for k = 0, 2 do
		local gc = CFrame.new(FX - 60 + k * 60, G, FZ - 20 + (k % 2) * 50)
		L.Cyl(FK, 0.14, 32, gc * CFrame.new(0, 0.07, 0), C(110, 176, 72), M.Grass)
		L.Cyl(FK, 8, 0.2, gc * CFrame.new(0, 4, 0), C(240, 240, 240), M.Metal)
		L.D(FK, Vector3.new(0.1, 1.6, 2.4), gc * CFrame.new(0, 7.2, 1.2), C(220, 30, 30), M.Fabric)
		L.Cyl(FK, 0.2, 12, gc * CFrame.new(18, 0.1, 10), C(236, 220, 170), M.Sand)
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.8
		local p = Vector3.new(FX + math.cos(a) * 150, G, FZ + math.sin(a) * 140)
		L.mansion(FK, CFrame.lookAt(p, Vector3.new(FX, G, FZ)), 80, 64, { dock = true, name = "Fisher Key Golf Villa " .. (k + 1), price = 5500000 + k * 250000, style = ({ "tropical", "white", "med", "noir" })[k + 1] })
	end
	L.B(FK, CFrame.new(FX + 40, G, FZ - 90), 0, 0, 0, 50, 16, 30, C(244, 240, 228), M.Plaster, "StuccoWhite")
	L.sign(FK, CFrame.new(FX + 40, G + 12, FZ - 105.3), 24, 3, "FISHER KEY CLUB", C(30, 70, 50), C(250, 250, 248), Enum.Font.Merriweather, {})
	scatterPalms(FK, FX, FZ, 170, 160, 26)
	L.poi(Vector3.new(FX, G, FZ - 190), "Dock", "Fisher Key Ferry")
	L.poi(Vector3.new(FX + 40, G, FZ - 110), "Job", "Fisher Key Ferry Captain", { Job = "Ferry Captain", Pay = 70 })

	-- ===== KEY VICE (boat only): long natural island with the lighthouse park =====
	local KX, KZ = 2700, 1100
	island(KX, KZ, 235, 410, true)
	local KV = L.model(IS, "KeyVice")
	scatterPalms(KV, KX, KZ, 200, 360, 50)
	for _ = 1, 40 do L.bush(KV, Vector3.new(KX + L.r(-180, 180), G, KZ + L.r(-330, 330)), L.r(4, 9)) end
	do
		local lc = CFrame.new(KX + 60, G, KZ - 330)
		L.Cyl(KV, 90, 14, lc * CFrame.new(0, 45, 0), C(250, 250, 248), M.Plaster)
		L.Cyl(KV, 10, 11, lc * CFrame.new(0, 95, 0), C(240, 250, 255), M.Glass, nil, { Transparency = 0.3 })
		L.Ball(KV, 5, lc * CFrame.new(0, 95, 0), C(255, 240, 180), M.Neon)
		L.Cyl(KV, 5, 13, lc * CFrame.new(0, 102, 0), C(30, 30, 32), M.Metal)
		L.B(KV, lc, 18, 0, 0, 20, 12, 16, C(250, 250, 248), M.Plaster, "StuccoWhite")
		L.poi(lc.Position, "Park", "Key Vice Lighthouse Park")
	end

	-- ===== THE SANDBAR (boat only): party sandbar with anchored boats =====
	local BX, BZ = 2850, -150
	for x = -90, 90, 8 do
		local hz = 60 * math.sqrt(math.max(0, 1 - (x / 90) ^ 2))
		if hz > 2 then T:FillBlock(CFrame.new(BX + x, -14, BZ), Vector3.new(8, 20, hz * 2), M.Sand) end
	end
	local SB = L.model(IS, "Sandbar")
	for _ = 1, 8 do L.boat(SB, CFrame.new(BX + L.r(-130, 130), W, BZ + L.r(70, 120) * (L.chance(0.5) and 1 or -1)) * CFrame.Angles(0, L.r(0, 6), 0), L.r(24, 36)) end
	L.yacht(SB, CFrame.new(BX - 140, W, BZ) * CFrame.Angles(0, 1.2, 0), 60, "motor")
	L.poi(Vector3.new(BX, G - 3, BZ), "Park", "The Sandbar")

	-- ===== CAYO PERDIDO (boat only): shipwreck island =====
	local CX, CZ = -1200, 1850
	island(CX, CZ, 120, 110, true)
	local CP = L.model(IS, "CayoPerdido")
	scatterPalms(CP, CX, CZ, 90, 80, 12)
	local wc = CFrame.new(CX + 120, W - 2, CZ + 30) * CFrame.Angles(0.15, 0.6, 0.25)
	L.P(CP, Vector3.new(30, 18, 120), wc, C(90, 60, 44), M.CorrodedMetal, "RustCoarse")
	L.P(CP, Vector3.new(20, 14, 30), wc * CFrame.new(0, 14, 30), C(120, 90, 70), M.CorrodedMetal, "RustySheet")
	L.P(CP, Vector3.new(2, 40, 2), wc * CFrame.new(0, 30, -10), C(80, 60, 44), M.Wood)
	L.poi(Vector3.new(CX + 90, G, CZ + 20), "Job", "Salvage Diver", { Job = "Salvage Diver", Pay = 90 })

	-- ===== BIRD KEY (boat only): mangroves + observation tower =====
	local BKX, BKZ = -300, -1620
	island(BKX, BKZ, 100, 90, true)
	local BK = L.model(IS, "BirdKey")
	for _ = 1, 50 do L.bush(BK, Vector3.new(BKX + L.r(-85, 85), G, BKZ + L.r(-75, 75)), L.r(5, 12), C(50, 86, 40)) end
	local tc = CFrame.new(BKX, G, BKZ)
	for _, q in ipairs({ { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }) do L.B(BK, tc, q[1], 0, q[2], 1, 30, 1, C(110, 86, 60), M.Wood) end
	L.B(BK, tc, 0, 30, 0, 14, 1, 14, C(150, 120, 86), M.WoodPlanks, "WoodPlanksOld")
	L.poi(tc.Position, "Park", "Bird Key")

	local parts = 0
	for _, d in ipairs(IS:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "islands parts " .. parts
end
