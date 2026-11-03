-- 33: Stock Exchange upgrade - LED ticker wrapping the hall (both sides + back, like the NYSE / Nasdaq
-- facade tickers), VBX banners between the columns (NYSE-style), and the stock scripts re-installed
-- (server sets text, VBTicker.client scrolls every band locally).
return function(L)
	local C, M = L.C, L.M
	local G = L.G
	local ex = workspace.ViceBay.Landmarks:FindFirstChild("StockExchange", true)
	if not ex then return "no StockExchange model" end
	for _, d in ipairs(ex:GetChildren()) do if d:GetAttribute("VB33") then d:Destroy() end end
	local c = CFrame.new(800, G, -290)
	local W2, D2, H, fy = 112, 120, 46, 4
	local y = fy + H - 7
	local function mark(p) p:SetAttribute("VB33", true) return p end
	local function band(pos, dir, len)
		local cf = CFrame.lookAt(pos, pos + dir)
		local b = mark(L.P(ex, Vector3.new(len, 4.4, 0.6), cf, C(8, 8, 10), M.SmoothPlastic))
		b.Name = "TickerWrap"
		b.CanCollide = false
		for _, dy in ipairs({ -2.5, 2.5 }) do mark(L.D(ex, Vector3.new(len + 0.4, 0.6, 1), cf * CFrame.new(0, dy, 0.1), C(30, 30, 34), M.Metal)) end
	end
	band((c * CFrame.new(-(W2 / 2 + 0.35), y, 0)).Position, Vector3.new(-1, 0, 0), D2 - 2)
	band((c * CFrame.new(W2 / 2 + 0.35, y, 0)).Position, Vector3.new(1, 0, 0), D2 - 2)
	band((c * CFrame.new(0, y, D2 / 2 + 0.35)).Position, Vector3.new(0, 0, 1), W2 - 2)
	-- NYSE-style banners between the outer column pairs
	for _, x in ipairs({ -33.3, 33.3 }) do
		local bcf = c * CFrame.new(x, fy + H - 22, -D2 / 2 + 0.6)
		local ban = mark(L.D(ex, Vector3.new(8, 26, 0.15), bcf, C(18, 36, 86), M.Fabric))
		L.text(ban, Enum.NormalId.Front, "VBX", { font = Enum.Font.Merriweather, color = C(226, 192, 110), size = UDim2.fromScale(0.9, 0.2), pos = UDim2.fromScale(0.05, 0.12), pps = 10, dist = 600, light = 0.6 })
		L.text(ban, Enum.NormalId.Front, "VICE BAY\nSTOCK\nEXCHANGE\n— EST. 1926 —", { font = Enum.Font.Merriweather, color = C(236, 230, 214), size = UDim2.fromScale(0.86, 0.36), pos = UDim2.fromScale(0.07, 0.42), pps = 10, dist = 400, light = 0.6 })
		mark(L.D(ex, Vector3.new(9, 0.5, 0.5), bcf * CFrame.new(0, 13.2, 0), C(180, 150, 80), M.Metal))
	end
	-- re-install the scripts from the vault
	local HS = game:GetService("HttpService")
	local function get(path)
		local was = HS.HttpEnabled
		HS.HttpEnabled = true
		local ok, res = pcall(function() return HS:GetAsync("http://127.0.0.1:8799/_vbsrc/scripts/" .. path, true) end)
		HS.HttpEnabled = was
		return ok and res or nil
	end
	local srv, tick = get("StockMarket.server.lua"), get("VBTicker.client.lua")
	if srv then
		local s = game.ServerScriptService:FindFirstChild("StockMarket") or Instance.new("Script")
		s.Name = "StockMarket"
		s.Source = srv
		s.Parent = game.ServerScriptService
	end
	if tick then
		local sps = game.StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
		local s = sps:FindFirstChild("VBTicker") or Instance.new("LocalScript")
		s.Name = "VBTicker"
		s.Source = tick
		s.Parent = sps
	end
	return string.format("exchange: wrap bands 3, banners 2 | server %s, ticker %s", srv and "ok" or "MISSING", tick and "ok" or "MISSING")
end
