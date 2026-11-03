--!strict
-- Liberty OS "Royce Realty": listings down the left (owned ones stamped SOLD), the open listing on the right with
-- price, what it does, what it needs, BUY and SET GPS. Server half: Services/RealtyService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Format = require(ReplicatedStorage.MTL.Format)

local App = {}

local KIND = {
	freight = { tag = "WAREHOUSE", does = "Runs Freight: buy crates at the Port, sell them in bulk.", unit = "crates" },
	stash = { tag = "STASH", does = "Runs The Re-Up: bag up, runners, corners.", unit = "packs" },
	home = { tag = "HOME", does = "A better place to live, with its own desk PC.", unit = "" },
}

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, button, corner, stroke = ui.new, ui.text, ui.button, ui.corner, ui.stroke
	local alive = true
	local state: any = { sel = nil, data = nil }
	local brass = Color3.fromRGB(200, 170, 120)

	local list = new("ScrollingFrame", {
		Parent = root,
		Name = "Listings",
		Size = UDim2.new(0, 380, 1, 0),
		BackgroundColor3 = L.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = L.Dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("Frame", { Parent = root, Position = UDim2.fromOffset(380, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })
	local detail = new("Frame", { Parent = root, Name = "Listing", Position = UDim2.fromOffset(381, 0), Size = UDim2.new(1, -381, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true })

	-- the "photo": a drawn street front (sky gradient, the building block, windows) tinted per kind
	local function photo(parent: Instance, p: any, h: number): Frame
		local f = new("Frame", { Parent = parent, Name = "Photo", Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true }, {
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(52, 44, 84), Color3.fromRGB(214, 118, 92)) }),
		})
		local seed = #p.id * 7 + p.price % 13
		local bw = if p.kind == "freight" then 0.7 elseif p.kind == "home" then 0.32 else 0.42
		local bh = if p.kind == "freight" then 0.42 elseif p.kind == "home" then 0.86 else 0.6
		local body = new("Frame", { Parent = f, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(bw, bh), BackgroundColor3 = Color3.fromRGB(28, 26, 34), BorderSizePixel = 0 })
		local cols = if p.kind == "freight" then 9 else 5
		local rows = if p.kind == "home" then 9 else 3
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				local lit = ((r * 31 + c * 17 + seed) % 5) < 2
				new("Frame", { Parent = body, Position = UDim2.fromScale((c + 0.25) / cols, (r + 0.2) / (rows + 0.4)), Size = UDim2.fromScale(0.5 / cols, 0.45 / (rows + 0.4)), BackgroundColor3 = if lit then Color3.fromRGB(255, 196, 120) else Color3.fromRGB(46, 44, 56), BorderSizePixel = 0 })
			end
		end
		if p.kind == "freight" then
			new("Frame", { Parent = body, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.3, 0.45), BackgroundColor3 = Color3.fromRGB(70, 72, 80), BorderSizePixel = 0 })
		end
		new("Frame", { Parent = f, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0 })
		return f
	end

	local rows: { [string]: any } = {}
	local draw: () -> ()

	local function showDetail()
		for _, ch in detail:GetChildren() do
			ch:Destroy()
		end
		local p: any = nil
		for _, x in state.data.props do
			if x.id == state.sel then
				p = x
			end
		end
		if not p then
			return
		end
		local k = KIND[p.kind]
		photo(detail, p, 220)
		local body = new("Frame", { Parent = detail, Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 1, -220), BackgroundTransparency = 1 }, {
			new("UIPadding", { PaddingLeft = UDim.new(0, 32), PaddingRight = UDim.new(0, 32), PaddingTop = UDim.new(0, 20) }),
		})
		text(body, k.tag .. "  ·  " .. string.upper(p.area), { font = L.Bold, size = 12, color = brass, sizeU = UDim2.new(1, 0, 0, 16) })
		text(body, p.title, { font = L.Head, size = 38, pos = UDim2.fromOffset(0, 18), sizeU = UDim2.new(0.6, 0, 0, 46) })
		text(body, Format.cash(p.price), { font = L.Head, size = 38, color = L.Money, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, 0, 0, 18), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.4, 0, 0, 46) })
		text(body, p.size, { size = 14, color = L.Dim, pos = UDim2.fromOffset(0, 66), sizeU = UDim2.new(1, 0, 0, 18) })
		local blurb = text(body, p.blurb, { size = 17, pos = UDim2.fromOffset(0, 98), sizeU = UDim2.new(1, 0, 0, 50), wrap = true, valign = Enum.TextYAlignment.Top })
		blurb.LineHeight = 1.2
		local facts = k.does .. (if p.cap then "  Holds " .. p.cap .. " " .. k.unit .. "." else "")
		text(body, facts, { font = L.Bold, size = 14, pos = UDim2.fromOffset(0, 156), sizeU = UDim2.new(1, 0, 0, 40), wrap = true, valign = Enum.TextYAlignment.Top })
		text(body, "Level " .. p.level, { font = L.Bold, size = 14, color = L.Gold, pos = UDim2.fromOffset(0, 200), sizeU = UDim2.new(1, 0, 0, 18) })
		local bar = new("Frame", { Parent = body, Position = UDim2.fromOffset(0, 236), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 })
		local msg = text(body, "", { size = 13, color = L.Gold, pos = UDim2.fromOffset(0, 290), sizeU = UDim2.new(1, 0, 0, 18) })
		if p.owned then
			text(bar, "YOU OWN THIS", { font = L.Head, size = 22, color = L.Select, sizeU = UDim2.new(0.5, -6, 1, 0) })
		elseif p.can then
			button(bar, "BUY  " .. Format.cash(p.price), function()
				local res = api.request("buy", { id = p.id })
				if res and res.ok then
					state.data = res
					draw()
				else
					msg.Text = res and res.err or "Failed"
				end
			end, { sizeU = UDim2.new(0.5, -6, 1, 0), color = Color3.fromRGB(46, 120, 60), size = 18 })
		else
			text(bar, p.why or "Locked", { font = L.Bold, size = 16, color = L.Dim, sizeU = UDim2.new(0.5, -6, 1, 0) })
		end
		button(bar, "SET GPS", function()
			local res = api.request("gps", { id = p.id })
			if res and res.ok then
				api.notify("GPS set: " .. p.title, L.Select)
			else
				msg.Text = res and res.err or "Failed"
			end
		end, { pos = UDim2.new(0.5, 6, 0, 0), sizeU = UDim2.new(0.5, -6, 1, 0), size = 16 })
		detail.Position = UDim2.fromOffset(401, 0)
		TweenService:Create(detail, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromOffset(381, 0) }):Play()
	end

	draw = function()
		for _, ch in list:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		rows = {}
		local head = new("Frame", { Parent = list, Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = 0 })
		text(head, "ROYCE REALTY", { font = L.Head, size = 26, color = brass, pos = UDim2.fromOffset(20, 10), sizeU = UDim2.new(1, -40, 0, 30) })
		text(head, "Vice Bay property since 1987", { size = 12, color = L.Dim, pos = UDim2.fromOffset(20, 42), sizeU = UDim2.new(1, -40, 0, 16) })
		for i, p in state.data.props do
			local r = new("TextButton", { Parent = list, Name = "Prop_" .. p.id, Size = UDim2.new(1, 0, 0, 88), BackgroundColor3 = if p.id == state.sel then L.Panel2 else L.Panel, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = i })
			local thumb = new("Frame", { Parent = r, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(96, 64), BackgroundTransparency = 1, ClipsDescendants = true }, { corner() })
			photo(thumb, p, 64)
			text(r, p.title, { font = L.Bold, size = 15, pos = UDim2.fromOffset(126, 14), sizeU = UDim2.new(1, -140, 0, 20) })
			text(r, p.area, { size = 12, color = L.Dim, pos = UDim2.fromOffset(126, 36), sizeU = UDim2.new(1, -140, 0, 16) })
			local tag = text(r, if p.owned then "SOLD · YOURS" else Format.cash(p.price), { font = L.Bold, size = 14, pos = UDim2.fromOffset(126, 56), sizeU = UDim2.new(1, -140, 0, 18) })
			tag.TextColor3 = if p.owned then L.Select elseif p.can then L.Money else L.Dim
			if not p.owned and not p.can and p.why then
				text(r, p.why, { size = 11, color = L.Dim, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0, 58), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 150, 0, 14) })
			end
			new("Frame", { Parent = r, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = 0.94, BorderSizePixel = 0 })
			r.Activated:Connect(function()
				api.tap()
				ui.click()
				state.sel = p.id
				for id, x in rows do
					x.BackgroundColor3 = if id == p.id then L.Panel2 else L.Panel
				end
				showDetail()
			end)
			rows[p.id] = r
		end
		showDetail()
	end
	_ = stroke

	task.spawn(function()
		local res = api.request("list")
		if not alive then
			return
		end
		if res and res.ok then
			state.data = res
			state.sel = res.props[1] and res.props[1].id
			draw()
		else
			text(list, res and res.err or "Can't reach Royce Realty", { color = L.Dim, sizeU = UDim2.new(1, 0, 0, 60), align = Enum.TextXAlignment.Center })
		end
	end)

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
