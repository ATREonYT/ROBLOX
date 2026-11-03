-- Vice Bay Stock Exchange (server)
-- Live-ticking fictional stocks, buy/sell through VBX terminals, saves holdings.
-- Cash: uses leaderstats.Cash (created if missing). To plug in your own money system,
-- replace getCash/setCash below.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DSS = game:GetService("DataStoreService")
local CS = game:GetService("CollectionService")

local TICK = 4 -- seconds between price moves
local STOCKS = {
	{ sym = "VBX",  name = "Vice Bay Exchange Index", price = 1250, vol = 0.006, drift = 0.0004 },
	{ sym = "BSCN", name = "Biscayne National Bank",  price = 84,   vol = 0.012, drift = 0.0003 },
	{ sym = "PRST", name = "Prestige Motors",         price = 212,  vol = 0.02,  drift = 0.0002 },
	{ sym = "VOLT", name = "Bayside EV",              price = 47,   vol = 0.035, drift = 0.0006 },
	{ sym = "VUE",  name = "The Vue Developments",    price = 63,   vol = 0.025, drift = 0.0005 },
	{ sym = "RIDE", name = "RideHub",                 price = 18,   vol = 0.04,  drift = 0.0 },
	{ sym = "CRTR", name = "Creator House Media",     price = 9.5,  vol = 0.06,  drift = 0.0002 },
	{ sym = "NEON", name = "Neon Entertainment",       price = 31,   vol = 0.03,  drift = 0.0001 },
	{ sym = "SUNC", name = "Suncoast Freight",        price = 55,   vol = 0.015, drift = 0.0002 },
	{ sym = "YCHT", name = "Vice Bay Yachts",         price = 140,  vol = 0.022, drift = 0.0003 },
}
local NEWS = {
	{ "VOLT", 0.12, "Bayside EV wins city fleet contract" },
	{ "VOLT", -0.10, "Bayside EV recalls 2,000 scooters" },
	{ "VUE", 0.10, "The Vue tops out Midtown tower" },
	{ "VUE", -0.12, "Condo market cools, The Vue delays project" },
	{ "RIDE", 0.15, "RideHub surge pricing hits record weekend" },
	{ "RIDE", -0.15, "RideHub drivers strike downtown" },
	{ "CRTR", 0.25, "Creator House video goes viral" },
	{ "CRTR", -0.2, "Creator House loses top streamer" },
	{ "BSCN", 0.06, "Biscayne National beats earnings" },
	{ "BSCN", -0.08, "Biscayne National under investigation" },
	{ "PRST", 0.08, "Prestige Motors sells out new hypercar" },
	{ "NEON", 0.1, "NEON club books world-famous DJ" },
	{ "YCHT", 0.09, "Boat show season lifts Vice Bay Yachts" },
	{ "SUNC", -0.07, "Port congestion slows Suncoast Freight" },
}

-- remotes
local folder = RS:FindFirstChild("ViceBayRemotes") or Instance.new("Folder")
folder.Name = "ViceBayRemotes"
folder.Parent = RS
local function remote(class, name)
	local r = folder:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end
local evUpdate = remote("RemoteEvent", "StockUpdate")
local fnTrade = remote("RemoteFunction", "StockTrade")
local fnQuery = remote("RemoteFunction", "StockQuery")
local evNews = remote("RemoteEvent", "StockNews")

-- state
local bySym = {}
for _, s in ipairs(STOCKS) do
	s.open = s.price
	s.hist = { s.price }
	bySym[s.sym] = s
end
local holdings = {} -- [userId] = {sym = qty}
local store = nil
pcall(function() store = DSS:GetDataStore("ViceBay_Stocks_v1") end)

-- cash helpers (swap these for your own economy)
local function cashValue(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = plr
	end
	local c = ls:FindFirstChild("Cash")
	if not c then
		c = Instance.new("IntValue")
		c.Name = "Cash"
		c.Value = 1500
		c.Parent = ls
	end
	return c
end
local function getCash(plr) return cashValue(plr).Value end
local function setCash(plr, v) cashValue(plr).Value = math.floor(v) end

local function round2(x) return math.floor(x * 100 + 0.5) / 100 end
local function snapshot()
	local t = {}
	for _, s in ipairs(STOCKS) do
		table.insert(t, { sym = s.sym, name = s.name, price = round2(s.price), change = round2((s.price - s.open) / s.open * 100), hist = s.hist })
	end
	return t
end

-- price engine
local function step()
	for _, s in ipairs(STOCKS) do
		local shock = (math.random() + math.random() + math.random() - 1.5) / 1.5 -- ~N(0,1)-ish
		s.price = math.max(0.5, s.price * (1 + s.drift + s.vol * shock))
		table.insert(s.hist, round2(s.price))
		if #s.hist > 60 then table.remove(s.hist, 1) end
	end
	if math.random() < 0.04 then
		local n = NEWS[math.random(1, #NEWS)]
		local s = bySym[n[1]]
		s.price = math.max(0.5, s.price * (1 + n[2]))
		evNews:FireAllClients(n[1], n[3], n[2])
		_G.ViceBayLastNews = n[1] .. ": " .. n[3]
	end
end

-- world displays (ticker band + big board)
local function findPart(name)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then return d end
	end
end
local board = findPart("BoardScreen")
-- every ticker band on the building (front band + the wrap-around bands). The server only sets the text;
-- the scrolling runs on each client (StarterPlayerScripts.VBTicker) so nothing streams over the network.
local tickerLabels = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "TickerBand" or d.Name == "TickerWrap") then
		local g = Instance.new("SurfaceGui")
		g.Name = "TickerGui"
		g.Face = (d.Name == "TickerBand") and Enum.NormalId.Back or Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.LightInfluence = 0
		g.Brightness = 1.6
		g.MaxDistance = 900
		g.ClipsDescendants = true
		g.Parent = d
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
		bg.ClipsDescendants = true
		bg.Parent = g
		local t = Instance.new("TextLabel")
		t.Name = "TickerScroll"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(3, 0, 1, 0)
		t.Position = UDim2.fromScale(math.random() * -1.5, 0)
		t.Font = Enum.Font.Code
		t.TextScaled = true
		t.RichText = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Color3.fromRGB(255, 220, 120)
		t.Parent = bg
		table.insert(tickerLabels, t)
	end
end
local boardRows = {}
if board then
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 0
	g.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
	bg.Parent = g
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.12)
	title.Text = "VICE BAY STOCK EXCHANGE  ·  LIVE"
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(220, 190, 110)
	title.Parent = bg
	for i, s in ipairs(STOCKS) do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = (i % 2 == 0) and 0.85 or 1
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Size = UDim2.fromScale(0.96, 0.08)
		row.Position = UDim2.fromScale(0.02, 0.12 + (i - 1) * 0.085)
		row.Font = Enum.Font.Code
		row.TextScaled = true
		row.RichText = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Parent = bg
		boardRows[s.sym] = row
	end
end
local function refreshDisplays()
	local parts = {}
	for _, s in ipairs(STOCKS) do
		local ch = (s.price - s.open) / s.open * 100
		local col = ch >= 0 and "#3CE07A" or "#FF5A5A"
		local arrow = ch >= 0 and "▲" or "▼"
		table.insert(parts, string.format('%s <font color="%s">%.2f %s%.2f%%</font>', s.sym, col, s.price, arrow, math.abs(ch)))
		local row = boardRows[s.sym]
		if row then
			row.Text = string.format('  %-5s %-26s <font color="%s">%10.2f   %s %6.2f%%</font>', s.sym, s.name, col, s.price, arrow, math.abs(ch))
		end
	end
	local txt = table.concat(parts, "     ·     ") .. ((_G.ViceBayLastNews and ("     ·     NEWS: " .. _G.ViceBayLastNews)) or "")
	for _, t in ipairs(tickerLabels) do t.Text = txt end
end

-- trading
local function portfolio(plr)
	return holdings[plr.UserId] or {}
end
fnQuery.OnServerInvoke = function(plr)
	return { stocks = snapshot(), holdings = portfolio(plr), cash = getCash(plr) }
end
fnTrade.OnServerInvoke = function(plr, sym, qty, side)
	local s = bySym[sym]
	qty = math.floor(tonumber(qty) or 0)
	if not s or qty <= 0 or qty > 100000 then return false, "Invalid order" end
	local h = holdings[plr.UserId] or {}
	holdings[plr.UserId] = h
	local cost = s.price * qty
	if side == "buy" then
		if getCash(plr) < cost then return false, "Not enough cash" end
		setCash(plr, getCash(plr) - cost)
		h[sym] = (h[sym] or 0) + qty
		s.price = s.price * (1 + math.min(0.02, qty * 0.00002)) -- small market impact
	elseif side == "sell" then
		if (h[sym] or 0) < qty then return false, "You don't own that many shares" end
		h[sym] -= qty
		if h[sym] == 0 then h[sym] = nil end
		setCash(plr, getCash(plr) + cost)
		s.price = math.max(0.5, s.price * (1 - math.min(0.02, qty * 0.00002)))
	else
		return false, "Invalid side"
	end
	return true, string.format("%s %d %s @ $%.2f", side == "buy" and "Bought" or "Sold", qty, sym, s.price), { holdings = h, cash = getCash(plr) }
end

-- persistence
Players.PlayerAdded:Connect(function(plr)
	cashValue(plr)
	if store then
		local ok, data = pcall(function() return store:GetAsync("u" .. plr.UserId) end)
		if ok and type(data) == "table" then holdings[plr.UserId] = data end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	if store then pcall(function() store:SetAsync("u" .. plr.UserId, holdings[plr.UserId] or {}) end) end
	holdings[plr.UserId] = nil
end)
game:BindToClose(function()
	if not store then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(function() store:SetAsync("u" .. plr.UserId, holdings[plr.UserId] or {}) end)
	end
end)

-- terminals open the client UI
for _, t in ipairs(CS:GetTagged("StockTerminal")) do
	local pp = t:FindFirstChildOfClass("ProximityPrompt")
	if pp then pp.Triggered:Connect(function(plr) evUpdate:FireClient(plr, snapshot(), true) end) end
end

-- day cycle: reset "open" every 10 minutes so % change stays meaningful
task.spawn(function()
	while true do
		task.wait(600)
		for _, s in ipairs(STOCKS) do s.open = s.price end
	end
end)

refreshDisplays()
while true do
	task.wait(TICK)
	step()
	refreshDisplays()
	evUpdate:FireAllClients(snapshot(), false)
end
