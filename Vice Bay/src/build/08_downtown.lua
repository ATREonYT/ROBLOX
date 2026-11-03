-- 08 Downtown on the beach (x 300..1440): City Center supertall cluster, condo towers on Biscayne,
-- the Vice Bay Stock Exchange, Ocean Blvd art deco hotels. Architecture language: see src/lib/Towers.lua.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local VB = L.folder(workspace, "ViceBay")
	local B = L.folder(L.folder(VB, "Buildings"), "Downtown")
	local LM = L.folder(L.folder(VB, "Landmarks"), "Downtown")
	B:ClearAllChildren()
	LM:ClearAllChildren()
	L.seed(1440)
	-- terrain under downtown: pavers, not raw concrete
	workspace.Terrain:ReplaceMaterial(Region3.new(Vector3.new(300, -8, -1152), Vector3.new(1460, 4, 652)):ExpandToGrid(4), 4, M.Concrete, M.Pavement)

	local XS = { 300, 500, 700, 900, 1100, 1290, 1440 }
	local XIN = { [300] = 50, [500] = 34, [700] = 42, [900] = 42, [1100] = 34, [1290] = 42, [1440] = 50 } -- road half-width + sidewalk (wide streets for full-size cars)
	local ZS = { -1110, -980, -830, -620, -410, -200, 0, 200, 400 }
	local ZIN = { [-1110] = 42, [-980] = 34, [-830] = 42, [-620] = 34, [-410] = 42, [-200] = 34, [0] = 42, [200] = 34, [400] = 42 }
	local function block(i, j, j2)
		j2 = j2 or j
		local x0, x1 = XS[i] + XIN[XS[i]] + 3, XS[i + 1] - XIN[XS[i + 1]] - 3
		local z0, z1 = ZS[j] + ZIN[ZS[j]] + 3, ZS[j2 + 1] - ZIN[ZS[j2 + 1]] - 3
		return (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	end
	local N, S, E, W = 0, math.pi, -math.pi / 2, math.pi / 2
	local function tower(i, j, o)
		local cx, cz, bw, bd = block(i, j, o.j2)
		local yaw = o.yaw or N
		local cf = CFrame.new(cx, G, cz) * CFrame.Angles(0, yaw, 0)
		local swap = (yaw == W or yaw == E)
		o.pw = (swap and bd or bw) - 4
		o.pd = (swap and bw or bd) - 4
		-- chunky, city-filling towers: grow the footprint to nearly the whole block
		-- margins so nothing pokes past the podium / lot: balconies +7, exoskeleton ribs +15 each side,
		-- a rotating square needs its diagonal to fit
		local margin = (o.kind == "exo") and 34 or ((o.kind == "balcony") and 16 or 10)
		local aw, ad = o.pw - margin, o.pd - margin
		if o.entrance then ad = ad - 52 end -- leave a forecourt for the drop-off
		local g = o.grow or 1.7
		if o.kind == "twist" then
			o.w = math.min(aw, ad, o.w * g) / 1.42
			o.d = o.w
		else
			o.w = math.min(aw, o.w * g)
			o.d = math.min(ad, o.d * g)
		end
		return L.dtTower2(B, cf, o)
	end
	-- two towers sharing one podium (fills the block, reads as a dense skyline)
	local function pair(i, j, o)
		local cx, cz, bw, bd = block(i, j)
		local yaw = o.yaw or N
		local cf = CFrame.new(cx, G, cz) * CFrame.Angles(0, yaw, 0)
		local swap = (yaw == W or yaw == E)
		local pw, pd = (swap and bd or bw) - 10, (swap and bw or bd) - 10
		local m = Instance.new("Model")
		m.Name = o.name or "TowerPair"
		local ph = o.podiumH or 32
		L.podium(m, cf, pw, pd, ph, { deck = true, deckX = 0, sign = o.sign })
		local tw = pw / 2 - 12 -- leaves room for balcony slabs between the two towers
		local td = pd - 18
		local kinds = o.kinds or { o.kind, o.kind }
		for k, side in ipairs({ -1, 1 }) do
			local h = (k == 1) and o.h or o.h * L.r(0.68, 0.85)
			local tcf = cf * CFrame.new(side * (pw / 4), 0, 2)
			local roof = L.TOWERS[kinds[k]](m, tcf, tw, td, h, { y0 = ph, wave = o.wave, col = o.col })
			if o.heli == k and roof then
				local hp = L.helipad(m, tcf * CFrame.new(roof.x or 0, roof.y, roof.z or 0), math.min(roof.w, roof.d), roof.legs)
				L.poi(hp, "Helipad", (o.name or "Tower") .. " Helipad", {}, { iconDist = 900 })
			end
		end
		m.Parent = B
		L.lod(m)
		L.footprint(B, cf, pw, pd)
		return m
	end

	-- ===== CITY CENTER: the supertall cluster (Moscow-City scale, Miami language) =====
	tower(2, 3, { entrance = true, kind = "twist", w = 62, d = 62, h = 680, name = "Vice One (twist)", sign = "VICE ONE", turn = math.rad(100) })
	tower(3, 3, { entrance = true, kind = "stepped", w = 72, d = 66, h = 600, name = "Bayfront Tower (stepped crown)", sign = "BAYFRONT TOWER" })
	tower(4, 3, { kind = "exo", w = 54, d = 54, h = 560, name = "One Museum (exoskeleton)", sign = "ONE MUSEUM", heli = true })
	tower(2, 4, { kind = "sail", w = 76, d = 46, h = 620, name = "Mariner Sail", sign = "THE SAIL", podiumH = 36, deck = true })
	tower(3, 4, { entrance = true, kind = "xbrace", w = 66, d = 66, h = 520, name = "Exchange Tower (exposed frame)", sign = "830 BRICKELL", heli = true })
	tower(4, 4, { kind = "flatiron", w = 96, d = 104, h = 470, name = "Flatiron", sign = "THE FLATIRON" })
	tower(5, 3, { kind = "deco", w = 70, d = 60, h = 470, name = "Ocean Bank Building (art deco)", sign = "OCEAN BANK", col = C(220, 208, 186) })
	tower(5, 4, { entrance = true, kind = "glass", w = 58, d = 58, h = 440, spire = 60, name = "Southeast Financial", sign = "SOUTHEAST FINANCIAL" })

	-- ===== Biscayne Blvd condo wall (faces the park and the bay) =====
	for j = 2, 8 do
		local opts = {
			{ "slab", "round" }, { "taper", "balcony" }, { "jenga", "slab" }, { "round", "balcony" }, { "balcony", "jenga" }, { "sail", "slab" }, { "round", "glass" },
		}
		pair(1, j, { kinds = opts[j - 1], yaw = W, h = L.r(260, 380), wave = (j % 2 == 0), name = "Biscayne Condos " .. j, heli = (j % 3 == 0) and 1 or nil })
	end
	-- ===== north row (offices) =====
	tower(2, 2, { kind = "brutal", w = 70, d = 60, h = 300, name = "Dade County Building (brutalist)", sign = "COUNTY CENTER", heli = true })
	tower(3, 2, { kind = "frame", w = 66, d = 56, h = 290, name = "Brickell Frame", sign = "THE FRAME", heli = true })
	tower(4, 2, { entrance = true, kind = "glass", w = 64, d = 64, h = 340, spire = 30, name = "Vice Bay Tower" })
	tower(5, 2, { kind = "balcony", w = 60, d = 48, h = 260, wave = true, podiumH = 30, deck = true, name = "Collins Condos" })
	-- ===== south of the Exchange: twin towers on shared podiums =====
	tower(2, 5, { entrance = true, kind = "glass", w = 60, d = 56, h = 340, name = "Biscayne National Bank", sign = "BISCAYNE NATIONAL", heli = true })
	pair(2, 6, { kinds = { "slab", "round" }, h = 300, wave = true, name = "Riverside Pair" })
	pair(4, 5, { kinds = { "jenga", "brutal" }, h = 360, heli = 2, name = "Jenga & Bank" })
	tower(4, 6, { entrance = true, kind = "round", w = 62, d = 62, h = 300, name = "Grand Bay Hotel", sign = "GRAND BAY HOTEL", heli = true })
	pair(5, 5, { kinds = { "sail", "frame" }, h = 340, wave = true, heli = 2, name = "Sail & Frame" })
	pair(5, 6, { kinds = { "deco", "balcony" }, h = 280, wave = true, name = "Deco Pair" })
	for i = 2, 5 do
		local A = { "balcony", "taper", "glass", "slab", "round", "jenga", "brutal", "frame", "deco" }
		pair(i, 7, { kinds = { L.pick(A), L.pick(A) }, h = L.r(220, 320), wave = L.chance(0.5), heli = L.chance(0.4) and 1 or nil, name = "Brickell Pair " .. i })
		if i > 2 then pair(i, 8, { kinds = { L.pick(A), L.pick({ "balcony", "slab", "round" }) }, h = L.r(200, 280), wave = true, heli = L.chance(0.3) and 1 or nil, name = "Bayside Pair " .. i }) end
	end
	-- shore row (shallow lots): mid-rise offices
	for i = 1, 5 do
		local cx, cz, bw, bd = block(i, 1)
		L.office(B, CFrame.new(cx, G, cz), bw - 6, bd - 4, { h = L.r(70, 120) })
		L.footprint(B, CFrame.new(cx, G, cz), bw - 4, bd - 2)
	end

	-- ===== OCEAN BLVD: art deco hotels facing the beach, one glass condo tower per few blocks =====
	for j = 1, 8 do
		local cx, cz, bw, bd = block(6, j)
		if j == 3 or j == 6 then
			tower(6, j, { kind = (j == 3) and "round" or "slab", yaw = E, w = 44, d = 36, h = L.r(240, 320), wave = true, podiumH = 24, deck = true, name = "Oceanfront Condo " .. j, heli = (j == 6) })
		else
			local n = math.max(1, math.floor(bd / 44))
			for k = 0, n - 1 do
				local z = cz - bd / 2 + (k + 0.5) * bd / n
				local cf = CFrame.new(cx, G, z) * CFrame.Angles(0, E, 0)
				L.artdeco(B, cf, bd / n - 4, bw - 4, {})
				L.footprint(B, cf, bd / n - 2, bw - 2)
			end
		end
	end

	-- ===== VICE BAY STOCK EXCHANGE (superblock x 742..858, z -374..-36) =====
	do
		local ex = L.model(LM, "StockExchange")
		local c = CFrame.new(800, G, -290)
		local W2, D2, H = 112, 120, 46
		local stone, dark = C(232, 226, 212), C(40, 40, 44)
		-- plaza + steps
		L.D(ex, Vector3.new(116, 0.4, 336), CFrame.new(800, G + 0.2, -205), C(214, 206, 192), M.Concrete, "DowntownPavers")
		for k = 0, 3 do L.P(ex, Vector3.new(W2 + 8 - k * 2, 1, 8 - k * 2), c * CFrame.new(0, 0.5 + k, -D2 / 2 - 6 + k), stone, M.Sandstone, "DowntownStoneBlocks") end
		-- hollow hall (walk-in)
		local fy = 4
		L.P(ex, Vector3.new(W2, 4, D2), c * CFrame.new(0, 2, 0), stone, M.Sandstone, "DowntownStoneBlocks")
		L.P(ex, Vector3.new(W2 - 4, 0.4, D2 - 4), c * CFrame.new(0, fy + 0.2, 0), C(230, 226, 220), M.Marble, "LobbyMarble")
		L.P(ex, Vector3.new(W2, H, 3), c * CFrame.new(0, fy + H / 2, D2 / 2 - 1.5), stone, M.Sandstone, "DowntownStoneBlocks")
		for side = -1, 1, 2 do L.P(ex, Vector3.new(3, H, D2), c * CFrame.new(side * (W2 / 2 - 1.5), fy + H / 2, 0), stone, M.Sandstone, "DowntownStoneBlocks") end
		L.P(ex, Vector3.new(W2, 4, D2), c * CFrame.new(0, fy + H + 2, 0), stone, M.Sandstone, "DowntownStoneBlocks")
		-- front wall with a big doorway, set behind the colonnade
		local fz = -D2 / 2 + 10
		for side = -1, 1, 2 do L.P(ex, Vector3.new(W2 / 2 - 14, H, 2), c * CFrame.new(side * (W2 / 4 + 7), fy + H / 2, fz), stone, M.Sandstone, "DowntownStoneBlocks") end
		L.P(ex, Vector3.new(28, H - 24, 2), c * CFrame.new(0, fy + 24 + (H - 24) / 2, fz), stone, M.Sandstone, "DowntownStoneBlocks")
		L.D(ex, Vector3.new(26, 22, 0.3), c * CFrame.new(0, fy + 11, fz), C(60, 80, 90), M.Glass, nil, { Transparency = 0.6 })
		-- colonnade + entablature + pediment
		for k = 0, 9 do
			local x = -W2 / 2 + 6 + k * (W2 - 12) / 9
			L.Cyl(ex, H - 8, 4.4, c * CFrame.new(x, fy + (H - 8) / 2, -D2 / 2 + 3), stone, M.Marble, "LobbyMarble")
			L.P(ex, Vector3.new(6, 1.4, 6), c * CFrame.new(x, fy + H - 7.3, -D2 / 2 + 3), stone, M.Sandstone)
		end
		local ent = L.P(ex, Vector3.new(W2 + 2, 7, 10), c * CFrame.new(0, fy + H - 3, -D2 / 2 + 4), stone, M.Sandstone, "DowntownStoneBlocks")
		L.text(ent, Enum.NormalId.Front, "VICE BAY STOCK EXCHANGE", { font = Enum.Font.Merriweather, color = C(60, 54, 40), pps = 12, dist = 600, light = 1, size = UDim2.fromScale(0.9, 0.6), pos = UDim2.fromScale(0.05, 0.2) })
		L.W(ex, Vector3.new(10, 12, W2 / 2 + 1), c * CFrame.new(-W2 / 4, fy + H + 6.5, -D2 / 2 + 4) * CFrame.Angles(0, math.pi / 2, 0), stone, M.Sandstone, "DowntownStoneBlocks")
		L.W(ex, Vector3.new(10, 12, W2 / 2 + 1), c * CFrame.new(W2 / 4, fy + H + 6.5, -D2 / 2 + 4) * CFrame.Angles(0, -math.pi / 2, 0), stone, M.Sandstone, "DowntownStoneBlocks")
		-- LED ticker over the entrance (StockMarket script draws on its Back face, so turn it to face the street)
		local band = L.P(ex, Vector3.new(80, 4, 0.6), c * CFrame.new(0, fy + 26, fz - 1.4) * CFrame.Angles(0, math.pi, 0), C(8, 8, 10), M.SmoothPlastic)
		band.Name = "TickerBand"
		-- inside: big board, trading desks, terminals
		local board = L.P(ex, Vector3.new(80, 22, 1), c * CFrame.new(0, fy + 20, D2 / 2 - 3.6) * CFrame.Angles(0, math.pi, 0), C(6, 8, 12), M.SmoothPlastic)
		board.Name = "BoardScreen"
		for r = 0, 1 do
			for k = -2, 2 do
				local dc = c * CFrame.new(k * 18, fy, 10 + r * 20)
				L.B(ex, dc, 0, 0, 0, 12, 3.2, 5, C(70, 52, 40), M.Wood)
				L.BD(ex, dc, -3, 3.2, 1, 3, 2, 0.3, C(20, 20, 24), M.SmoothPlastic)
				L.BD(ex, dc, 3, 3.2, 1, 3, 2, 0.3, C(20, 20, 24), M.SmoothPlastic)
			end
		end
		local CS = game:GetService("CollectionService")
		for k = 1, 6 do
			local x = -W2 / 2 + 10 + (k - 1) * (W2 - 20) / 5
			local t = L.P(ex, Vector3.new(3, 5, 2), c * CFrame.new(x, fy + 2.5, -D2 / 2 + 22), C(30, 32, 36), M.Metal)
			t.Name = "Terminal" .. k
			local scr = L.D(ex, Vector3.new(2.6, 2, 0.1), c * CFrame.new(x, fy + 4, -D2 / 2 + 20.95), C(30, 220, 120), M.Neon)
			L.text(scr, Enum.NormalId.Front, "VBX ▲", { font = Enum.Font.Code, color = C(10, 30, 20), pps = 30 })
			CS:AddTag(t, "StockTerminal")
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Trade Stocks"
			pp.ObjectText = "VBX Terminal"
			pp.MaxActivationDistance = 8
			pp.RequiresLineOfSight = false
			pp.Parent = t
		end
		-- tower rising behind the hall
		L.dtTower2(LM, CFrame.new(800, G, -110), { kind = "glass", w = 70, d = 70, h = 420, spire = 50, podiumH = 0, pw = 112, pd = 140, name = "VBX Tower", col = C(52, 70, 92) })
		L.footprint(LM, c, W2 + 10, D2 + 20)
		L.poi((c * CFrame.new(0, fy, -D2 / 2 + 22)).Position, "Finance", "Vice Bay Stock Exchange", { Note = "Trade stocks at the terminals" }, { noPrompt = true })
	end

	-- ===== install the stock market scripts from the vault =====
	do
		local HS = game:GetService("HttpService")
		local function get(path)
			local was = HS.HttpEnabled
			HS.HttpEnabled = true
			local ok, res = pcall(function() return HS:GetAsync("http://127.0.0.1:8799/_vbsrc/scripts/" .. path, true) end)
			HS.HttpEnabled = was
			return ok and res or nil
		end
		local srv = get("StockMarket.server.lua")
		local cli = get("StockTradingUI.client.lua")
		if srv then
			local s = game.ServerScriptService:FindFirstChild("StockMarket") or Instance.new("Script")
			s.Name = "StockMarket"
			s.Source = srv
			s.Parent = game.ServerScriptService
		end
		if cli then
			local sps = game.StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
			local s = sps:FindFirstChild("StockTradingUI") or Instance.new("LocalScript")
			s.Name = "StockTradingUI"
			s.Source = cli
			s.Parent = sps
		end
	end

	local parts = 0
	for _, d in ipairs(B:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "downtown parts " .. parts
end
