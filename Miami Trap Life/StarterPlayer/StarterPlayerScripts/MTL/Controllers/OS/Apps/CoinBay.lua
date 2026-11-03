--!strict
-- CoinBay (Liberty OS app). The meme coin market: coin list (new / holding / blue chips), a live candle chart,
-- the signals a careful trader reads (holders, dev wallet, top 10, curve, buzz), and buy / sell.
-- Server half: Services/CoinService (every number re-checked there). Vault: Desk Computer Empire §6.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Coins = require(ReplicatedStorage.MTL.Config.Coins)
local OSRules = require(ReplicatedStorage.MTL.Rules.OSRules)
local Format = require(ReplicatedStorage.MTL.Format)

local App = {}

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, button, corner, stroke = ui.new, ui.text, ui.button, ui.corner, ui.stroke

	local state: any = { market = nil, tab = "New", sel = nil, chart = nil, amount = 100, alive = true }
	local rowsById: { [string]: any } = {}

	---------------------------------------------------------------- layout
	local left = new("Frame", { Parent = root, Name = "List", Size = UDim2.new(0, 330, 1, 0), BackgroundColor3 = L.Panel, BorderSizePixel = 0 })
	new("Frame", { Parent = left, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })
	local center = new("Frame", { Parent = root, Name = "Chart", Position = UDim2.fromOffset(330, 0), Size = UDim2.new(1, -660, 1, 0), BackgroundTransparency = 1 })
	local right = new("Frame", { Parent = root, Name = "Trade", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 330, 1, 0), BackgroundColor3 = L.Panel, BorderSizePixel = 0 })
	new("Frame", { Parent = right, Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })

	-- mood strip
	local mood = new("Frame", { Parent = left, Name = "Mood", Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 54), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
	local moodTag = text(mood, "", { name = "Tag", font = L.Head, size = 18, pos = UDim2.fromOffset(12, 4), sizeU = UDim2.new(1, -24, 0, 22) })
	local moodLine = text(mood, "", { name = "Line", size = 12, color = L.Dim, pos = UDim2.fromOffset(12, 26), sizeU = UDim2.new(1, -24, 0, 24), wrap = true })

	-- tabs
	local tabs = new("Frame", { Parent = left, Name = "Tabs", Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -28, 0, 30), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	local tabButtons: { [string]: TextButton } = {}
	local list = new("ScrollingFrame", {
		Parent = left,
		Name = "Rows",
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = L.Dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- chart header
	local head = new("Frame", { Parent = center, Name = "Head", Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1 })
	local hGlyph = new("Frame", { Parent = head, Name = "Glyph", Position = UDim2.fromOffset(22, 18), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(3), stroke() })
	local hGlyphText = text(hGlyph, "", { font = L.Head, size = 26, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
	local hTicker = text(head, "Pick a coin", { name = "Ticker", font = L.Head, size = 30, pos = UDim2.fromOffset(88, 14), sizeU = UDim2.new(0.5, 0, 0, 34) })
	local hName = text(head, "", { name = "Name", size = 14, color = L.Dim, pos = UDim2.fromOffset(88, 50), sizeU = UDim2.new(0.5, 0, 0, 18) })
	local hPrice = text(head, "", { name = "Price", font = L.Head, size = 34, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -22, 0, 10), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 40) })
	local hChange = text(head, "", { name = "Change", font = L.Bold, size = 16, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -22, 0, 52), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 20) })
	local plot = new("Frame", { Parent = center, Name = "Plot", Position = UDim2.fromOffset(22, 100), Size = UDim2.new(1, -110, 1, -150), BackgroundColor3 = L.Panel, BackgroundTransparency = 0.35, BorderSizePixel = 0, ClipsDescendants = true }, { corner(), stroke() })
	local axis = new("Frame", { Parent = center, Name = "Axis", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 100), Size = UDim2.new(0, 80, 1, -150), BackgroundTransparency = 1 })
	local foot = text(center, "", { name = "Foot", size = 12, color = L.Dim, pos = UDim2.new(0, 22, 1, -40), sizeU = UDim2.new(1, -44, 0, 18) })
	local banner = new("Frame", { Parent = center, Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, ZIndex = 20 })
	local bannerBig = text(banner, "", { font = L.Head, size = 64, color = L.Money, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 72), pos = UDim2.fromOffset(0, 8), z = 21 })
	local bannerSub = text(banner, "", { font = L.Bold, size = 18, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 82), z = 21 })

	-- signals + trade (right)
	local sig = new("Frame", { Parent = right, Name = "Signals", Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 250), BackgroundTransparency = 1 })
	text(sig, "SIGNALS", { font = L.Head, size = 18, sizeU = UDim2.new(1, 0, 0, 22) })
	local function meterRow(y: number, label: string): (TextLabel, Frame, TextLabel)
		text(sig, label, { size = 13, color = L.Dim, pos = UDim2.fromOffset(0, y), sizeU = UDim2.new(0.6, 0, 0, 18) })
		local val = text(sig, "-", { font = L.Bold, size = 14, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, 0, 0, y), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 18) })
		local track = new("Frame", { Parent = sig, Position = UDim2.fromOffset(0, y + 21), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = L.Panel3, BorderSizePixel = 0 })
		local fill = new("Frame", { Parent = track, Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = L.Select, BorderSizePixel = 0 })
		local note = text(sig, "", { size = 11, color = L.Dim, pos = UDim2.fromOffset(0, y + 26), sizeU = UDim2.new(1, 0, 0, 14) })
		return val, fill, note
	end
	local sHolders, fHolders, nHolders = meterRow(34, "Holders")
	local sDev, fDev, nDev = meterRow(80, "Dev wallet")
	local sTop, fTop, nTop = meterRow(126, "Top 10 hold")
	local sCurve, fCurve, nCurve = meterRow(172, "Curve filled")
	local sBuzz, fBuzz, _ = meterRow(218, "Clout buzz")
	_ = nCurve

	local trade = new("Frame", { Parent = right, Name = "TradeBox", Position = UDim2.fromOffset(16, 284), Size = UDim2.new(1, -32, 1, -300), BackgroundTransparency = 1 })
	text(trade, "TRADE", { font = L.Head, size = 18, sizeU = UDim2.new(1, 0, 0, 22) })
	local posLine = text(trade, "You don't hold this coin.", { name = "Position", size = 14, pos = UDim2.fromOffset(0, 28), sizeU = UDim2.new(1, 0, 0, 36), wrap = true })
	local pnlLine = text(trade, "", { name = "PnL", font = L.Head, size = 22, pos = UDim2.fromOffset(0, 62), sizeU = UDim2.new(1, 0, 0, 26) })
	local amountBox = new("TextBox", {
		Parent = trade,
		Name = "Amount",
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = L.Panel2,
		Text = "100",
		PlaceholderText = "$ amount",
		Font = L.Head,
		TextSize = 22,
		TextColor3 = L.Text,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, { corner(), stroke(), new("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	amountBox.TextXAlignment = Enum.TextXAlignment.Left
	local presets = new("Frame", { Parent = trade, Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	local limitLine = text(trade, "", { name = "Limit", size = 12, color = L.Dim, pos = UDim2.fromOffset(0, 180), sizeU = UDim2.new(1, 0, 0, 16) })
	local buyBtn: TextButton
	local sellBtns: { TextButton } = {}
	local msgLine = text(trade, "", { name = "Msg", size = 13, color = L.Gold, pos = UDim2.fromOffset(0, 300), sizeU = UDim2.new(1, 0, 0, 36), wrap = true })

	---------------------------------------------------------------- data helpers
	local function coinById(id: string): any?
		if not state.market then
			return nil
		end
		for _, c in state.market.coins do
			if c.id == id then
				return c
			end
		end
		for _, c in state.market.chips do
			if c.id == id then
				return c
			end
		end
		return nil
	end

	local function posById(id: string): any?
		if not state.market then
			return nil
		end
		for _, p in state.market.pos do
			if p.id == id then
				return p
			end
		end
		return nil
	end

	local function age(launchAt: number?): string
		if not launchAt or not state.market then
			return ""
		end
		local s = state.market.now - launchAt
		if s < 60 then
			return math.floor(s) .. "s"
		elseif s < 3600 then
			return math.floor(s / 60) .. "m"
		end
		return math.floor(s / 3600) .. "h"
	end

	local function sparkline(parent: Frame, pts: { number }, color: Color3)
		for _, ch in parent:GetChildren() do
			ch:Destroy()
		end
		if #pts < 2 then
			return
		end
		local lo, hi = math.huge, -math.huge
		for _, p in pts do
			lo = math.min(lo, p)
			hi = math.max(hi, p)
		end
		local span = math.max(hi - lo, hi * 0.001)
		for i = 1, #pts do
			local y = 1 - (pts[i] - lo) / span
			new("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 1) / (#pts - 1), y * 0.85 + 0.075), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = color, BorderSizePixel = 0 })
		end
	end

	---------------------------------------------------------------- the chart
	local function drawChart()
		for _, ch in plot:GetChildren() do
			if ch.Name == "Candle" or ch.Name == "Grid" or ch.Name == "Last" then
				ch:Destroy()
			end
		end
		for _, ch in axis:GetChildren() do
			ch:Destroy()
		end
		local ch = state.chart
		if not ch or #ch.candles == 0 then
			return
		end
		local cs = ch.candles
		local lo, hi = math.huge, -math.huge
		for _, k in cs do
			lo = math.min(lo, k[3])
			hi = math.max(hi, k[2])
		end
		local pad = (hi - lo) * 0.08 + hi * 0.0005
		lo -= pad
		hi += pad
		local function y(p: number): number
			return 1 - (p - lo) / (hi - lo)
		end
		for g = 0, 4 do
			local gy = g / 4
			new("Frame", { Parent = plot, Name = "Grid", Position = UDim2.fromScale(0, gy), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = 0.94, BorderSizePixel = 0 })
			text(axis, OSRules.price(hi - (hi - lo) * gy), { size = 11, color = L.Dim, pos = UDim2.new(0, 6, gy, -8), sizeU = UDim2.new(1, -6, 0, 16) })
		end
		local n = Coins.ChartCandles
		local w = 1 / n
		local offset = n - #cs
		for i, k in cs do
			local up = k[4] >= k[1]
			local col = if up then L.Money else L.Loss
			local x = (offset + i - 0.5) * w
			local top, bot = y(math.max(k[1], k[4])), y(math.min(k[1], k[4]))
			new("Frame", { Parent = plot, Name = "Candle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, y(k[2])), Size = UDim2.new(0, 1, y(k[3]) - y(k[2]), 0), BackgroundColor3 = col, BorderSizePixel = 0 })
			new("Frame", { Parent = plot, Name = "Candle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, top), Size = UDim2.new(w * 0.7, 0, math.max(bot - top, 0.003), 0), BackgroundColor3 = col, BorderSizePixel = 0 })
		end
		local last = cs[#cs][4]
		local ly = y(last)
		new("Frame", { Parent = plot, Name = "Last", Position = UDim2.fromScale(0, ly), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Text, BackgroundTransparency = 0.75, BorderSizePixel = 0 })
		local tag = new("Frame", { Parent = axis, Position = UDim2.new(0, 0, ly, -10), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = if cs[#cs][4] >= cs[#cs][1] then L.Money else L.Loss, BorderSizePixel = 0 }, { corner() })
		text(tag, OSRules.price(last), { font = L.Bold, size = 11, color = Color3.new(0, 0, 0), align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
	end

	---------------------------------------------------------------- panels
	local function setMeter(fill: Frame, x: number, color: Color3?)
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(x, 0, 1), 1) }):Play()
		if color then
			fill.BackgroundColor3 = color
		end
	end

	local function drawSignals(c: any?)
		local s = c and c.signals
		if not s then
			for _, v in { sHolders, sDev, sTop, sCurve, sBuzz } do
				v.Text = "-"
			end
			nDev.Text = if c then "Blue chip: no dev wallet" else ""
			return
		end
		sHolders.Text = tostring(s.holders)
		setMeter(fHolders, s.holders / 900)
		nHolders.Text = if s.dead then "Dead" elseif s.listed then "Listed: holders keep coming" else ""
		sDev.Text = string.format("%.1f%%", s.dev)
		setMeter(fDev, s.dev / 30, if s.devActive then L.Loss elseif s.dev > 15 then L.Warn else L.Select)
		nDev.Text = if s.devActive then "⚠ Dev wallet is moving coins" elseif s.dev > 15 then "Big dev bag: rug risk" else "Small dev bag"
		nDev.TextColor3 = if s.devActive then L.Loss else L.Dim
		sDev.TextColor3 = if s.devActive then L.Loss else L.Text
		sTop.Text = string.format("%.0f%%", s.top10)
		setMeter(fTop, s.top10 / 70, if s.top10 > 30 then L.Warn else L.Select)
		nTop.Text = if s.top10 > 30 then "Over 30%: a few wallets can dump it" else "Spread out"
		sCurve.Text = s.curve .. "%"
		setMeter(fCurve, s.curve / 100)
		sBuzz.Text = tostring(s.buzz)
		setMeter(fBuzz, s.buzz / 100, Color3.fromRGB(255, 90, 160))
	end

	local function drawTrade()
		local c = state.sel and coinById(state.sel)
		local p = state.sel and posById(state.sel)
		local m = state.market
		if not c then
			posLine.Text = "Pick a coin on the left."
			pnlLine.Text = ""
		elseif p then
			posLine.Text = string.format("You hold %s %s (cost %s)", Format.short(p.qty), c.ticker, Format.cash(math.floor(p.cost)))
			local pl = p.value - p.cost
			pnlLine.Text = string.format("%s%s  (%s)", if pl >= 0 then "+" else "-", Format.cash(math.floor(math.abs(pl))), OSRules.pct(if p.cost > 0 then pl / p.cost else 0))
			pnlLine.TextColor3 = if pl >= 0 then L.Money else L.Loss
		else
			posLine.Text = "You don't hold " .. c.ticker .. "."
			pnlLine.Text = ""
		end
		if m then
			limitLine.Text = string.format("Limit %s per coin · %d/%d coins · fee %d%%", Format.cash(m.cap), m.open, m.maxOpen, math.floor(m.fee * 100))
		end
		for _, b in sellBtns do
			b.Visible = p ~= nil
		end
		local dead = c and c.signals and c.signals.dead
		buyBtn.Visible = c ~= nil and not dead
	end

	local function drawHeader()
		local c = state.sel and coinById(state.sel)
		if not c then
			return
		end
		hGlyph.BackgroundColor3 = L.Panel2
		hGlyphText.Text = c.glyph
		hGlyphText.TextColor3 = c.color
		hTicker.Text = "$" .. c.ticker
		hName.Text = c.name .. (if c.launchAt then "  ·  launched " .. age(c.launchAt) .. " ago" else "")
		hPrice.Text = OSRules.price(c.price)
		local ch = if c.start then c.price / c.start - 1 else (c.day or 0)
		hChange.Text = OSRules.pct(ch) .. (if c.start then " since launch" else " today")
		hChange.TextColor3 = if ch >= 0 then L.Money else L.Loss
	end

	local function rowFor(c: any, order: number)
		local row = new("TextButton", { Parent = list, Name = "Row_" .. c.id, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = L.Panel, BackgroundTransparency = 0, AutoButtonColor = false, Text = "", LayoutOrder = order, BorderSizePixel = 0 })
		local sel = new("Frame", { Parent = row, Name = "Sel", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = L.Select, BorderSizePixel = 0, Visible = state.sel == c.id })
		local g = new("Frame", { Parent = row, Position = UDim2.fromOffset(14, 11), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(3) })
		text(g, c.glyph, { font = L.Head, size = 18, color = c.color, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
		text(row, "$" .. c.ticker, { font = L.Bold, size = 15, pos = UDim2.fromOffset(60, 9), sizeU = UDim2.new(0, 120, 0, 20) })
		local sub = text(row, if c.launchAt then age(c.launchAt) else c.name, { name = "Age", size = 12, color = L.Dim, pos = UDim2.fromOffset(60, 31), sizeU = UDim2.new(0, 120, 0, 16) })
		local price = text(row, OSRules.price(c.price), { name = "Price", font = L.Bold, size = 14, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0, 9), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 110, 0, 20) })
		local ch = if c.start then c.price / c.start - 1 else (c.day or 0)
		local chg = text(row, OSRules.pct(ch), { name = "Chg", font = L.Bold, size = 12, color = if ch >= 0 then L.Money else L.Loss, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0, 31), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 110, 0, 16) })
		local spark = new("Frame", { Parent = row, Name = "Spark", Position = UDim2.fromOffset(150, 14), Size = UDim2.fromOffset(52, 30), BackgroundTransparency = 1 })
		if c.spark then
			sparkline(spark, c.spark, if ch >= 0 then L.Money else L.Loss)
		end
		if c.signals and c.signals.dead then
			chg.Text = "RUGGED"
			chg.TextColor3 = L.Loss
		elseif c.signals and c.signals.listed then
			sub.Text = "LISTED"
			sub.TextColor3 = L.Gold
		end
		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = L.Panel2
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = L.Panel
		end)
		row.Activated:Connect(function()
			api.tap()
			ui.click()
			App._select(c.id)
		end)
		rowsById[c.id] = { row = row, price = price, chg = chg, sel = sel, coin = c }
	end

	local function drawList()
		for _, ch in list:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		rowsById = {}
		local m = state.market
		if not m then
			return
		end
		local items = {}
		if state.tab == "New" then
			items = m.coins
		elseif state.tab == "Chips" then
			items = m.chips
		else
			for _, p in m.pos do
				local c = coinById(p.id)
				if c then
					table.insert(items, c)
				end
			end
		end
		for i, c in items do
			rowFor(c, i)
		end
		if #items == 0 then
			text(list, if state.tab == "Holding" then "You don't hold any coins yet." else "Nothing here.", { size = 14, color = L.Dim, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 60) })
		end
		for id, b in tabButtons do
			b.BackgroundColor3 = if id == state.tab then L.Select else L.Panel3
			b.TextColor3 = if id == state.tab then Color3.new(0, 0, 0) else L.Text
		end
	end

	local function drawAll()
		local m = state.market
		if m then
			moodTag.Text = string.upper(m.mood) .. " MARKET"
			moodTag.TextColor3 = if m.mood == "Bull" then L.Money elseif m.mood == "Bear" then L.Loss else L.Gold
			moodLine.Text = m.moodLine
		end
		drawList()
		drawHeader()
		drawSignals(state.sel and coinById(state.sel))
		drawTrade()
		drawChart()
	end

	local function loadMarket()
		local res = api.request("market")
		if not state.alive then
			return
		end
		if not res or not res.ok then
			msgLine.Text = res and res.err or "Can't reach CoinBay"
			return
		end
		state.market = res
		if not state.sel and #res.coins > 0 then
			state.sel = res.coins[1].id
		end
		drawAll()
	end

	function App._select(id: string)
		state.sel = id
		for cid, r in rowsById do
			r.sel.Visible = cid == id
		end
		drawHeader()
		drawSignals(coinById(id))
		drawTrade()
		task.spawn(function()
			local res = api.request("chart", { id = id })
			if res and res.ok and state.alive and state.sel == id then
				state.chart = res
				drawChart()
			end
			api.request("watch", { id = id })
		end)
	end

	---------------------------------------------------------------- buttons
	for i, t in { { "New", "NEW" }, { "Holding", "HOLDING" }, { "Chips", "BLUE CHIPS" } } do
		tabButtons[t[1]] = button(tabs, t[2], function()
			state.tab = t[1]
			drawList()
		end, { sizeU = UDim2.new(0, if i == 3 then 112 else 88, 1, 0), size = 12, order = i })
	end
	for i, v in { 100, 500, 1000 } do
		button(presets, "$" .. v, function()
			amountBox.Text = tostring(v)
		end, { sizeU = UDim2.new(0.25, -5, 1, 0), size = 13, order = i })
	end
	button(presets, "MAX", function()
		local m = state.market
		if not m then
			return
		end
		local p = state.sel and posById(state.sel)
		local room = m.cap - (if p then p.cost else 0)
		local d = api.data()
		amountBox.Text = tostring(math.max(0, math.floor(math.min(room, d and d.Cash or 0))))
	end, { sizeU = UDim2.new(0.25, -5, 1, 0), size = 13, order = 4 })

	local function showBanner(big: string, sub: string, color: Color3)
		banner.Visible = true
		bannerBig.Text = big
		bannerBig.TextColor3 = color
		bannerSub.Text = sub
		banner.Size = UDim2.new(1, 0, 0, 0)
		TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Size = UDim2.new(1, 0, 0, 120) }):Play()
		task.delay(2.6, function()
			if banner.Parent then
				local tw = TweenService:Create(banner, TweenInfo.new(0.2), { Size = UDim2.new(1, 0, 0, 0) })
				tw:Play()
				tw.Completed:Wait()
				banner.Visible = false
			end
		end)
	end

	buyBtn = button(trade, "BUY", function()
		if not state.sel then
			return
		end
		local usd = math.floor(tonumber(amountBox.Text) or 0)
		msgLine.Text = "..."
		local res = api.request("buy", { id = state.sel, usd = usd })
		if res and res.ok then
			msgLine.Text = ""
			state.market = res.market
			api.notify(string.format("Bought %s of $%s", Format.cash(usd), (coinById(state.sel) or { ticker = "?" }).ticker), L.Money)
			drawAll()
		else
			msgLine.Text = res and res.err or "Failed"
		end
	end, { name = "Buy", sizeU = UDim2.new(1, 0, 0, 44), pos = UDim2.fromOffset(0, 204), color = Color3.fromRGB(46, 120, 60), size = 18 })
	for i, f in { 0.25, 0.5, 1 } do
		local b = button(trade, if f == 1 then "SELL ALL" else ("SELL " .. math.floor(f * 100) .. "%"), function()
			if not state.sel then
				return
			end
			local id = state.sel
			local res = api.request("sell", { id = id, frac = f })
			if res and res.ok then
				state.market = res.market
				msgLine.Text = ""
				if res.tag == "escaped" then
					showBanner("GOT OUT", "Sold before the rug · +" .. Format.cash(res.proceeds), L.Gold)
				elseif res.mult >= 5 then
					showBanner(string.format("%.1fx", res.mult), "+" .. Format.cash(res.proceeds), L.Money)
				else
					api.notify(string.format("Sold for %s (%.2fx)", Format.cash(res.proceeds), res.mult), if res.mult >= 1 then L.Money else L.Loss)
				end
				drawAll()
			else
				msgLine.Text = res and res.err or "Failed"
			end
		end, { name = "Sell", sizeU = UDim2.new(1 / 3, -5, 0, 36), pos = UDim2.new((i - 1) / 3, if i == 1 then 0 else 2, 0, 256), color = Color3.fromRGB(110, 40, 40), size = 13 })
		table.insert(sellBtns, b)
	end
	foot.Text = "1 candle = 10 s · new coin every " .. math.floor(Coins.LaunchEvery / 60) .. " min · most coins rug: watch the dev wallet"

	---------------------------------------------------------------- live ticks
	local function onPush(data: any)
		if not state.alive or not state.market or type(data) ~= "table" then
			return
		end
		state.market.now = data.t or state.market.now
		for id, tick in data.prices or {} do
			local c = coinById(id)
			if c then
				c.price = tick.price
				if tick.signals then
					c.signals = tick.signals
				end
				local r = rowsById[id]
				if r then
					r.price.Text = OSRules.price(c.price)
					local ch = if c.start then c.price / c.start - 1 else (c.day or 0)
					if not (c.signals and c.signals.dead) then
						r.chg.Text = OSRules.pct(ch)
						r.chg.TextColor3 = if ch >= 0 then L.Money else L.Loss
					else
						r.chg.Text = "RUGGED"
						r.chg.TextColor3 = L.Loss
					end
				end
			end
		end
		for _, p in state.market.pos do
			local c = coinById(p.id)
			if c then
				p.price = c.price
				p.value = p.qty * c.price
			end
		end
		if data.candle and state.chart and data.candle.id == state.sel then
			local cs = state.chart.candles
			local lastK = state.chart.lastK
			if lastK == nil or data.candle.k > lastK then
				if lastK ~= nil then
					table.insert(cs, data.candle.c)
					if #cs > Coins.ChartCandles then
						table.remove(cs, 1)
					end
				else
					cs[#cs] = data.candle.c
				end
				state.chart.lastK = data.candle.k
			else
				cs[#cs] = data.candle.c
			end
			drawChart()
		end
		drawHeader()
		drawSignals(state.sel and coinById(state.sel))
		drawTrade()
	end

	task.spawn(loadMarket)
	-- the list itself refreshes every 30 s (new launches)
	task.spawn(function()
		while state.alive do
			task.wait(30)
			if state.alive then
				loadMarket()
			end
		end
	end)

	return {
		push = onPush,
		unmount = function()
			state.alive = false
			task.spawn(function()
				api.request("unwatch")
			end)
		end,
	}
end

return App
