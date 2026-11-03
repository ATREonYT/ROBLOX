--!strict
-- Liberty OS "Freight": your warehouses (stock bar, crates sold), SOURCE (1-3 crates from the Port) and SELL (the
-- sale curve: the more you sell at once, the more each crate pays), the live run, and upgrades.
-- Server half: Services/FreightService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Format = require(ReplicatedStorage.MTL.Format)
local Freight = require(ReplicatedStorage.MTL.Config.Freight)
local FreightRules = require(ReplicatedStorage.MTL.Rules.FreightRules)

local App = {}

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, button, corner, stroke = ui.new, ui.text, ui.button, ui.corner, ui.stroke
	local orange = Color3.fromRGB(255, 140, 60)
	local alive = true
	local st: any = nil
	local sel: string? = nil
	local sellN = 1

	local side = new("Frame", { Parent = root, Name = "Warehouses", Size = UDim2.new(0, 320, 1, 0), BackgroundColor3 = L.Panel, BorderSizePixel = 0 }, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }),
	})
	new("Frame", { Parent = root, Position = UDim2.fromOffset(320, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })
	local main = new("Frame", { Parent = root, Name = "Main", Position = UDim2.fromOffset(321, 0), Size = UDim2.new(1, -321, 1, 0), BackgroundTransparency = 1 }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 30), PaddingTop = UDim.new(0, 24) }),
	})

	local draw: () -> ()
	local function call(action: string, args: any)
		local res = api.request(action, args)
		if res and res.ok then
			st = res
			draw()
			return res
		end
		api.notify(res and res.err or "Failed", L.Loss)
		return nil
	end

	local function warehouse(): any
		for _, w in st.warehouses do
			if w.id == sel then
				return w
			end
		end
		return nil
	end

	local function section(y: number, title: string): Frame
		text(main, title, { font = L.Head, size = 18, pos = UDim2.fromOffset(0, y), sizeU = UDim2.new(1, 0, 0, 22) })
		return new("Frame", { Parent = main, Position = UDim2.fromOffset(0, y + 28), Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
	end

	draw = function()
		for _, ch in side:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for _, ch in main:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local head = new("Frame", { Parent = side, Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 0 })
		text(head, "FREIGHT", { font = L.Head, size = 26, color = orange, pos = UDim2.fromOffset(20, 10), sizeU = UDim2.new(1, -40, 0, 30) })
		text(head, "Liberty Imports · grey-market goods", { size = 12, color = L.Dim, pos = UDim2.fromOffset(20, 40), sizeU = UDim2.new(1, -40, 0, 16) })
		for i, w in st.warehouses do
			if not sel and w.owned then
				sel = w.id
			end
			local r = new("TextButton", { Parent = side, Size = UDim2.new(1, 0, 0, 82), BackgroundColor3 = if w.id == sel then L.Panel2 else L.Panel, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = i })
			text(r, w.title, { font = L.Bold, size = 15, color = if w.owned then L.Text else L.Dim, pos = UDim2.fromOffset(20, 12), sizeU = UDim2.new(1, -40, 0, 20) })
			if w.owned then
				text(r, string.format("%d / %d crates", w.crates, w.cap), { size = 12, color = L.Dim, pos = UDim2.fromOffset(20, 34), sizeU = UDim2.new(1, -40, 0, 16) })
				local track = new("Frame", { Parent = r, Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 0, 6), BackgroundColor3 = L.Panel3, BorderSizePixel = 0 }, { corner(3) })
				local fill = new("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = orange, BorderSizePixel = 0 }, { corner(3) })
				TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(w.crates / math.max(1, w.cap), 1) }):Play()
			else
				text(r, "Not owned · Royce Realty", { size = 12, color = L.Dim, pos = UDim2.fromOffset(20, 34), sizeU = UDim2.new(1, -40, 0, 16) })
			end
			r.Activated:Connect(function()
				if w.owned then
					api.tap()
					ui.click()
					sel = w.id
					sellN = 1
					draw()
				end
			end)
		end

		local w = warehouse()
		if not w then
			text(main, "Buy a warehouse on Royce Realty to start Freight.", { size = 18, color = L.Dim, sizeU = UDim2.new(1, 0, 0, 40) })
			return
		end
		text(main, w.title, { font = L.Head, size = 34, sizeU = UDim2.new(1, 0, 0, 40) })
		text(main, string.format("%s  ·  %d crates sold all-time", w.area, w.sold), { size = 14, color = L.Dim, pos = UDim2.fromOffset(0, 42), sizeU = UDim2.new(1, 0, 0, 18) })

		-- the live run
		local j = st.job
		local y = 76
		if j then
			local box = new("Frame", { Parent = main, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.fromRGB(60, 40, 20), BorderSizePixel = 0 }, { corner(), stroke(0.5, orange) })
			local line = if j.kind == "source" then (if j.stage == "load" then string.format("Pick up %d crates at the Port · %d loaded", j.n, j.step) else "Drive the crates back to the " .. w.title) else string.format("Selling %d crates · drop %d", j.n, j.step + 1)
			text(box, "ON A RUN", { font = L.Bold, size = 12, color = orange, pos = UDim2.fromOffset(16, 6), sizeU = UDim2.new(0.6, 0, 0, 16) })
			text(box, line, { font = L.Bold, size = 15, pos = UDim2.fromOffset(16, 24), sizeU = UDim2.new(0.75, 0, 0, 22) })
			button(box, "CANCEL", function()
				call("cancel", {})
			end, { anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -12, 0.5, 0), sizeU = UDim2.fromOffset(100, 32), size = 13 })
			y += 70
		end

		-- source
		local src = section(y, "SOURCE  ·  buy crates at the Port")
		for n = 1, Freight.SourceMax do
			local price = st.source[n] or st.source[tostring(n)]
			local can = j == nil and w.crates + n <= w.cap
			local b = button(src, "", function()
				if can then
					call("source", { prop = w.id, n = n })
				end
			end, { pos = UDim2.new((n - 1) / 3, if n == 1 then 14 else 7, 0, 14), sizeU = UDim2.new(1 / 3, -14, 1, -28), color = if can then L.Panel3 else L.Panel2 })
			text(b, n .. " CRATE" .. (if n > 1 then "S" else ""), { font = L.Head, size = 22, color = if can then L.Text else L.Dim, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 18), sizeU = UDim2.new(1, 0, 0, 26) })
			text(b, Format.cash(price * n), { font = L.Bold, size = 16, color = if can then L.Money else L.Dim, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 50), sizeU = UDim2.new(1, 0, 0, 20) })
			text(b, "+" .. Freight.XP.Sourced * n .. " XP", { size = 12, color = L.Gold, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 72), sizeU = UDim2.new(1, 0, 0, 16) })
		end
		y += 166

		-- sell: a slider-ish stepper + the curve
		local sl = section(y, "SELL  ·  the bigger the sale, the more each crate pays")
		sl.Size = UDim2.new(1, 0, 0, 170)
		sellN = math.clamp(sellN, if w.crates > 0 then 1 else 0, w.crates)
		local nLabel = text(sl, "", { font = L.Head, size = 40, pos = UDim2.fromOffset(20, 12), sizeU = UDim2.new(0.4, 0, 0, 46) })
		local each = text(sl, "", { font = L.Bold, size = 15, color = L.Dim, pos = UDim2.fromOffset(20, 60), sizeU = UDim2.new(0.5, 0, 0, 20) })
		local total = text(sl, "", { font = L.Head, size = 40, color = L.Money, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -20, 0, 12), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 46) })
		local dropsL = text(sl, "", { size = 13, color = L.Dim, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -20, 0, 62), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 18) })
		local function refresh()
			nLabel.Text = sellN .. " crate" .. (if sellN == 1 then "" else "s")
			if sellN > 0 then
				local e = FreightRules.each(sellN, Freight.SellCurve)
				each.Text = Format.cash(e) .. " each"
				total.Text = Format.cash(e * sellN)
				local dn = FreightRules.drops(sellN, Freight.Drops)
				dropsL.Text = dn .. " drop" .. (if dn == 1 then "" else "s") .. " on the map"
			else
				each.Text = "No stock"
				total.Text = "$0"
				dropsL.Text = ""
			end
		end
		refresh()
		local steps = new("Frame", { Parent = sl, Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 50), BackgroundTransparency = 1 }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, d in { { "-10", -10 }, { "-1", -1 }, { "+1", 1 }, { "+10", 10 }, { "ALL", 1e9 } } do
			button(steps, d[1], function()
				sellN = math.clamp(sellN + d[2], if w.crates > 0 then 1 else 0, w.crates)
				refresh()
			end, { sizeU = UDim2.new(0, 64, 1, 0), order = i, size = 14 })
		end
		button(steps, "SELL", function()
			if sellN > 0 and not st.job then
				call("sell", { prop = w.id, n = sellN })
			end
		end, { sizeU = UDim2.new(1, -5 * 72, 1, 0), order = 9, color = Color3.fromRGB(46, 120, 60), size = 18 })
		y += 216

		-- upgrades
		text(main, "UPGRADES", { font = L.Head, size = 18, pos = UDim2.fromOffset(0, y), sizeU = UDim2.new(1, 0, 0, 22) })
		for i, u in w.upgrades do
			local r = new("Frame", { Parent = main, Position = UDim2.new((i - 1) / 2, if i == 1 then 0 else 7, 0, y + 28), Size = UDim2.new(0.5, -7, 0, 78), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
			text(r, u.title, { font = L.Bold, size = 15, pos = UDim2.fromOffset(14, 10), sizeU = UDim2.new(0.6, 0, 0, 20) })
			text(r, u.blurb, { size = 12, color = L.Dim, pos = UDim2.fromOffset(14, 32), sizeU = UDim2.new(0.62, 0, 0, 36), wrap = true, valign = Enum.TextYAlignment.Top })
			if u.owned then
				text(r, "HIRED", { font = L.Bold, size = 14, color = L.Select, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0.5, -10), anchor = Vector2.new(1, 0), sizeU = UDim2.fromOffset(100, 20) })
			else
				button(r, Format.cash(u.price), function()
					call("upgrade", { prop = w.id, id = u.id })
				end, { anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -12, 0.5, 0), sizeU = UDim2.fromOffset(110, 34), size = 14, color = if (st.level or 1) >= u.level then L.Panel3 else L.Panel2 })
				if (st.level or 1) < u.level then
					text(r, "Level " .. u.level, { size = 11, color = L.Gold, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 1, -16), anchor = Vector2.new(1, 0), sizeU = UDim2.fromOffset(100, 14) })
				end
			end
		end
	end

	task.spawn(function()
		local res = api.request("state")
		if not alive then
			return
		end
		if res and res.ok then
			st = res
			draw()
		else
			text(main, res and res.err or "Can't load Freight", { color = L.Dim, sizeU = UDim2.new(1, 0, 0, 40) })
		end
	end)

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
