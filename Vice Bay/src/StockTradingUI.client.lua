-- Vice Bay Stock Exchange (client trading UI)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local remotes = RS:WaitForChild("ViceBayRemotes")
local evUpdate = remotes:WaitForChild("StockUpdate")
local fnTrade = remotes:WaitForChild("StockTrade")
local fnQuery = remotes:WaitForChild("StockQuery")
local evNews = remotes:WaitForChild("StockNews")

local GOLD = Color3.fromRGB(220, 190, 110)
local UP, DOWN = Color3.fromRGB(60, 224, 122), Color3.fromRGB(255, 90, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "VBXTrading"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.fromScale(0.5, 0.5)
win.Size = UDim2.fromScale(0.62, 0.72)
win.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
local sz = Instance.new("UISizeConstraint", win); sz.MinSize = Vector2.new(340, 300); sz.MaxSize = Vector2.new(900, 640)
local stroke = Instance.new("UIStroke", win); stroke.Color = GOLD; stroke.Thickness = 2

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 8)
title.Size = UDim2.new(1, -80, 0, 34)
title.Text = "VICE BAY STOCK EXCHANGE"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = GOLD
title.Parent = win

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 8)
close.Size = UDim2.fromOffset(44, 44)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextScaled = true
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
close.Parent = win
Instance.new("UICorner", close)
close.Activated:Connect(function() gui.Enabled = false end)

local cashLbl = Instance.new("TextLabel")
cashLbl.BackgroundTransparency = 1
cashLbl.Position = UDim2.new(0, 16, 0, 46)
cashLbl.Size = UDim2.new(1, -32, 0, 24)
cashLbl.Font = Enum.Font.GothamMedium
cashLbl.TextScaled = true
cashLbl.TextXAlignment = Enum.TextXAlignment.Left
cashLbl.TextColor3 = Color3.fromRGB(200, 200, 205)
cashLbl.Parent = win

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 12, 0, 78)
list.Size = UDim2.new(0.58, -18, 1, -90)
list.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = win
Instance.new("UICorner", list)
local lay = Instance.new("UIListLayout", list); lay.Padding = UDim.new(0, 4)

local side = Instance.new("Frame")
side.Position = UDim2.new(0.58, 0, 0, 78)
side.Size = UDim2.new(0.42, -12, 1, -90)
side.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
side.Parent = win
Instance.new("UICorner", side)

local selLbl = Instance.new("TextLabel")
selLbl.BackgroundTransparency = 1
selLbl.Position = UDim2.fromOffset(12, 10)
selLbl.Size = UDim2.new(1, -24, 0, 50)
selLbl.Font = Enum.Font.GothamBold
selLbl.TextScaled = true
selLbl.TextWrapped = true
selLbl.TextColor3 = Color3.new(1, 1, 1)
selLbl.Text = "Pick a stock"
selLbl.Parent = side

local chart = Instance.new("Frame")
chart.Position = UDim2.fromOffset(12, 66)
chart.Size = UDim2.new(1, -24, 0, 90)
chart.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
chart.ClipsDescendants = true
chart.Parent = side

local qty = Instance.new("TextBox")
qty.Position = UDim2.new(0, 12, 0, 166)
qty.Size = UDim2.new(1, -24, 0, 44)
qty.PlaceholderText = "Shares"
qty.Text = "10"
qty.Font = Enum.Font.GothamMedium
qty.TextScaled = true
qty.TextColor3 = Color3.new(1, 1, 1)
qty.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
qty.ClearTextOnFocus = false
qty.Parent = side
Instance.new("UICorner", qty)

local function button(text, col, x)
	local b = Instance.new("TextButton")
	b.Position = UDim2.new(x, x == 0 and 12 or 6, 0, 218)
	b.Size = UDim2.new(0.5, -18, 0, 48)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = col
	b.Parent = side
	Instance.new("UICorner", b)
	return b
end
local buyB = button("BUY", Color3.fromRGB(30, 140, 80), 0)
local sellB = button("SELL", Color3.fromRGB(170, 50, 50), 0.5)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 12, 0, 274)
status.Size = UDim2.new(1, -24, 0, 40)
status.Font = Enum.Font.Gotham
status.TextScaled = true
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(200, 200, 205)
status.Text = ""
status.Parent = side

local state = { stocks = {}, holdings = {}, cash = 0 }
local selected = nil
local rows = {}

local function drawChart(hist, col)
	chart:ClearAllChildren()
	if not hist or #hist < 2 then return end
	local lo, hi = math.huge, -math.huge
	for _, v in ipairs(hist) do lo = math.min(lo, v); hi = math.max(hi, v) end
	if hi - lo < 1e-6 then hi = lo + 1 end
	local n = #hist
	for i = 1, n do
		local bar = Instance.new("Frame")
		local h = (hist[i] - lo) / (hi - lo)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new((i - 1) / n, 0, 1, 0)
		bar.Size = UDim2.new(1 / n, -1, 0.1 + h * 0.85, 0)
		bar.BackgroundColor3 = col
		bar.BorderSizePixel = 0
		bar.Parent = chart
	end
end

local function render()
	local total = state.cash
	for _, s in ipairs(state.stocks) do total += (state.holdings[s.sym] or 0) * s.price end
	cashLbl.Text = string.format("Cash $%s   ·   Net worth $%s", string.format("%.0f", state.cash), string.format("%.0f", total))
	for i, s in ipairs(state.stocks) do
		local r = rows[s.sym]
		if not r then
			r = Instance.new("TextButton")
			r.Size = UDim2.new(1, -8, 0, 40)
			r.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
			r.Font = Enum.Font.Code
			r.TextScaled = true
			r.RichText = true
			r.TextXAlignment = Enum.TextXAlignment.Left
			r.TextColor3 = Color3.new(1, 1, 1)
			r.LayoutOrder = i
			r.Parent = list
			Instance.new("UICorner", r)
			r.Activated:Connect(function() selected = s.sym; render() end)
			rows[s.sym] = r
		end
		local col = s.change >= 0 and "#3CE07A" or "#FF5A5A"
		local own = state.holdings[s.sym] or 0
		r.Text = string.format(' %-5s <font color="%s">$%.2f %+.2f%%</font>%s', s.sym, col, s.price, s.change, own > 0 and string.format("  · own %d", own) or "")
		r.BackgroundColor3 = (selected == s.sym) and Color3.fromRGB(50, 46, 30) or Color3.fromRGB(26, 28, 36)
		if selected == s.sym then
			selLbl.Text = string.format("%s · %s\n$%.2f", s.sym, s.name, s.price)
			drawChart(s.hist, s.change >= 0 and UP or DOWN)
		end
	end
end

local function trade(sideName)
	if not selected then status.Text = "Select a stock first"; return end
	local ok, msg, data = fnTrade:InvokeServer(selected, tonumber(qty.Text), sideName)
	status.Text = msg or ""
	status.TextColor3 = ok and UP or DOWN
	if ok and data then state.holdings = data.holdings; state.cash = data.cash end
	render()
end
buyB.Activated:Connect(function() trade("buy") end)
sellB.Activated:Connect(function() trade("sell") end)

evUpdate.OnClientEvent:Connect(function(stocks, open)
	state.stocks = stocks
	if open then
		local d = fnQuery:InvokeServer()
		state.holdings = d.holdings; state.cash = d.cash
		selected = selected or stocks[1].sym
		gui.Enabled = true
	end
	if gui.Enabled then render() end
end)

-- breaking news toast
evNews.OnClientEvent:Connect(function(sym, text, move)
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, 0, 0, 12)
	t.Size = UDim2.fromScale(0.5, 0.05)
	t.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = move >= 0 and UP or DOWN
	t.Text = string.format("VBX NEWS · %s %s%d%% · %s", sym, move >= 0 and "+" or "", math.floor(move * 100), text)
	local holder = plr.PlayerGui:FindFirstChild("VBXNews") or Instance.new("ScreenGui")
	holder.Name = "VBXNews"; holder.ResetOnSpawn = false; holder.Parent = plr.PlayerGui
	t.Parent = holder
	Instance.new("UICorner", t)
	task.delay(6, function() t:Destroy() end)
end)
