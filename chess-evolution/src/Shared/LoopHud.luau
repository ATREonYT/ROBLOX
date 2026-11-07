--!strict
-- +1 Chess Evolution: the "ChessLoop" ScreenGui. It holds the right-hand rail (Promote, Shop,
-- Daily, Gifts, Codes) and one shared panel with a page for each. tools/build_place.luau
-- builds it and saves src/StarterGui/ChessLoop.rbxm, so Alex can see and edit it in Studio.
-- LoopClient reuses these parts.
-- Vault rules used: 09 Owner Taste Rules (see-through panels with floating titles, small
-- premium buttons, no emoji, no VIP, close only with X), 30 UI and UX §3/§5 (one panel at a
-- time, tap areas >= 44 px), 21 Money (prices shown, "Coming soon" never prompts).
local Loop = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local C = {
	promote = Color3.fromRGB(255, 196, 40),
	shop = Color3.fromRGB(70, 210, 80),
	daily = Color3.fromRGB(40, 200, 240),
	gift = Color3.fromRGB(255, 110, 190),
	codes = Color3.fromRGB(170, 80, 240),
	panel = Color3.fromRGB(30, 30, 48),
	tile = Color3.fromRGB(56, 58, 84),
	grey = Color3.fromRGB(110, 116, 132),
}
Loop.Colors = C

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(parent: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, parent)
end

local function outline(parent: Instance, t: number?)
	new("UIStroke", { Thickness = t or 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function label(parent: Instance, name: string, textValue: string, size: UDim2, pos: UDim2, props: { [string]: any }?): TextLabel
	local t = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = WHITE,
		TextScaled = true,
		Text = textValue,
		Size = size,
		Position = pos,
	}, parent)
	new("UIStroke", { Thickness = 2.5, Color = INK, Name = "Outline" }, t)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	return t
end

-- Flat, bevelled button: coloured face, darker lip below, dark outline (note 09).
local function button(parent: Instance, name: string, textValue: string, color: Color3, size: UDim2, pos: UDim2): TextButton
	local b = new("TextButton", {
		Name = name,
		Size = size,
		Position = pos,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	round(b, 10)
	outline(b, 3)
	new("UIScale", { Name = "Press" }, b)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
	}, b)
	label(b, "Label", textValue, UDim2.new(1, -12, 0.7, 0), UDim2.new(0, 6, 0.15, 0))
	return b
end
Loop.Button = button

local function tile(parent: Instance, name: string, order: number, size: UDim2): Frame
	local f = new("Frame", { Name = name, LayoutOrder = order, Size = size, BackgroundColor3 = C.tile, BackgroundTransparency = 0.1 }, parent)
	round(f, 10)
	outline(f, 2.5)
	return f
end

function Loop.Build(config: any): ScreenGui
	local gui = new("ScreenGui", { Name = "ChessLoop", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 })

	-- Right rail --------------------------------------------------------------
	local rail = new("Frame", { Name = "LoopRail", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(132, 300) }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }, rail)
	local promote = button(rail, "PromoteBtn", "PROMOTE", C.promote, UDim2.fromOffset(132, 62), UDim2.new())
	promote.LayoutOrder = 1;
	(promote:FindFirstChild("Label") :: TextLabel).Size = UDim2.new(1, -12, 0.42, 0);
	(promote:FindFirstChild("Label") :: TextLabel).Position = UDim2.new(0, 6, 0.08, 0)
	local track = new("Frame", { Name = "Track", BackgroundColor3 = INK, BackgroundTransparency = 0.25, Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 1, -22) }, promote)
	round(track, 7)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color3.fromRGB(110, 235, 90), Size = UDim2.fromScale(0, 1) }, track)
	round(fill, 7)
	label(track, "Pct", "0%", UDim2.fromScale(1, 1.3), UDim2.fromScale(0, -0.15))
	-- ready glow ring (breathes slower than once a second; no flashing)
	local rows = {
		{ "ShopBtn", "SHOP", C.shop },
		{ "DailyBtn", "DAILY", C.daily },
		{ "GiftBtn", "GIFTS", C.gift },
		{ "CodesBtn", "CODES", C.codes },
	}
	for i, r in rows do
		local b = button(rail, r[1], r[2], r[3], UDim2.fromOffset(112, 46), UDim2.new())
		b.LayoutOrder = i + 1
		-- a small dot says "something to claim" (no number spam, no flashing)
		local dot = new("Frame", { Name = "Dot", Visible = false, BackgroundColor3 = Color3.fromRGB(255, 60, 60), Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 4, 0, 4) }, b)
		round(dot, 8)
		outline(dot, 2)
	end

	-- One shared panel ---------------------------------------------------------
	local dim = new("Frame", { Name = "Dim", Visible = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 20, Active = true }, gui)
	local panel = new("Frame", { Name = "Panel", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(470, 330), BackgroundColor3 = C.panel, BackgroundTransparency = 0.12, ZIndex = 21 }, gui)
	round(panel, 16)
	outline(panel, 3.5)
	new("UIScale", { Name = "Pop" }, panel)
	local title = label(panel, "Title", "", UDim2.fromOffset(330, 48), UDim2.new(0.5, -165, 0, -30), { ZIndex = 23 })
	title.TextColor3 = C.promote
	local close = button(panel, "Close", "X", Color3.fromRGB(240, 70, 70), UDim2.fromOffset(44, 44), UDim2.new(1, -30, 0, -14))
	close.ZIndex = 24
	local status = label(panel, "Status", "", UDim2.new(1, -40, 0, 24), UDim2.new(0, 20, 1, -32), { ZIndex = 23 })
	local _ = dim

	local function page(name: string): Frame
		return new("Frame", { Name = name, Visible = false, BackgroundTransparency = 1, Size = UDim2.new(1, -32, 1, -76), Position = UDim2.new(0, 16, 0, 30), ZIndex = 22 }, panel)
	end

	-- Promote: before -> after (note 13 §2E)
	local pPromote = page("Promote")
	label(pPromote, "Before", "+0% Power", UDim2.new(0.42, 0, 0, 34), UDim2.new(0, 0, 0, 6))
	label(pPromote, "Arrow", ">", UDim2.new(0.16, 0, 0, 34), UDim2.new(0.42, 0, 0, 6), { TextColor3 = C.promote })
	label(pPromote, "After", "+50% Power", UDim2.new(0.42, 0, 0, 34), UDim2.new(0.58, 0, 0, 6), { TextColor3 = Color3.fromRGB(110, 235, 90) })
	label(pPromote, "WinsLine", "+0% Wins  >  +25% Wins", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 46))
	label(pPromote, "NeedPower", "Power 0 / 400", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 86))
	label(pPromote, "NeedWins", "Wins 0 / 20", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 114))
	label(pPromote, "Note", "Power and Wins go back to 0. Sets and treadmills stay.", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 146), { TextColor3 = Color3.fromRGB(200, 204, 220) })
	button(pPromote, "Go", "PROMOTE", C.promote, UDim2.fromOffset(200, 54), UDim2.new(0.5, -100, 1, -58))

	-- Shop: plain pass cards; price always shown, "Coming soon" when the pass isn't made yet
	local pShop = page("Shop")
	local shopList = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, pShop)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, shopList)
	for key, pass in config.Passes do
		local card = tile(shopList, key, pass.order, UDim2.fromOffset(136, 212))
		label(card, "Name", pass.name, UDim2.new(1, -12, 0, 30), UDim2.new(0, 6, 0, 8), { TextColor3 = C.promote })
		label(card, "Text", pass.text, UDim2.new(1, -16, 0, 70), UDim2.new(0, 8, 0, 44), { TextWrapped = true, TextColor3 = Color3.fromRGB(220, 224, 236) })
		label(card, "Price", `R$ {pass.price}`, UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 0, 122), { TextColor3 = Color3.fromRGB(110, 235, 90) })
		button(card, "Buy", "BUY", C.shop, UDim2.new(1, -16, 0, 44), UDim2.new(0, 8, 1, -54))
	end

	-- Daily: 7 tiles
	local pDaily = page("Daily")
	local dGrid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 160) }, pDaily)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, dGrid)
	for i, wins in config.Daily do
		local t = tile(dGrid, "Day" .. i, i, UDim2.new())
		label(t, "Day", `Day {i}`, UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 6), { TextColor3 = Color3.fromRGB(200, 204, 220) })
		label(t, "Amount", `+{wins}`, UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 0, 32), { TextColor3 = C.promote })
	end
	button(pDaily, "Claim", "CLAIM", C.daily, UDim2.fromOffset(200, 54), UDim2.new(0.5, -100, 1, -58))

	-- Gifts: playtime tiles
	local pGift = page("Gifts")
	local gGrid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, pGift)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 104), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, gGrid)
	for i, g in config.Playtime do
		local t = new("TextButton", { Name = "Gift" .. i, LayoutOrder = i, BackgroundColor3 = C.tile, BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "" }, gGrid)
		round(t, 10)
		outline(t, 2.5)
		new("UIScale", { Name = "Press" }, t)
		label(t, "Amount", `+{g.wins}`, UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 0, 14), { TextColor3 = C.promote })
		label(t, "Wins", "Wins", UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 44), { TextColor3 = Color3.fromRGB(200, 204, 220) })
		label(t, "When", `{g.min}:00`, UDim2.new(1, -8, 0, 24), UDim2.new(0, 4, 1, -32))
	end

	-- Codes
	local pCodes = page("Codes")
	local box = new("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.new(0, 20, 0, 40),
		BackgroundColor3 = Color3.fromRGB(246, 238, 220),
		FontFace = FONT,
		TextSize = 28,
		TextColor3 = INK,
		PlaceholderText = "Type a code",
		PlaceholderColor3 = Color3.fromRGB(150, 140, 130),
		Text = "",
		ClearTextOnFocus = false,
	}, pCodes)
	round(box, 10)
	outline(box, 3)
	button(pCodes, "Redeem", "REDEEM", C.codes, UDim2.fromOffset(200, 54), UDim2.new(0.5, -100, 1, -58))

	local _s = status
	return gui
end

return Loop
