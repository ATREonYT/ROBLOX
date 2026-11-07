--!strict
-- +1 Chess Evolution: the "ChessLoop" ScreenGui. It adds Shop, Promote, Rewards and Daily to the left grid
-- (same spot and size as ChessHUD's Rail) and holds one shared panel with a page for each.
-- tools/build_place.luau builds it and saves src/StarterGui/ChessLoop.rbxm, so Alex can see and edit it in Studio.
-- LoopClient reuses these parts.
-- Look: a coloured header bar across a see-through dark sheet, the reference's menus; studded slabs with
-- black outlines (Folk Stud rules). One panel at a time, tap areas >= 44 px, prices shown, "Coming soon" never prompts.
local Hud = require(script.Parent:WaitForChild("HudBuilder")) :: any

local Loop = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(16, 14, 22)
local WHITE = Color3.new(1, 1, 1)
local HC = Hud.Colors
local C = {
	promote = HC.slabPink,
	shop = HC.slabRed,
	daily = HC.slabGold,
	gift = Color3.fromRGB(235, 238, 245),
	codes = Color3.fromRGB(170, 80, 240),
	go = Color3.fromRGB(110, 240, 40),
	panel = Color3.fromRGB(38, 44, 40),
	tile = Color3.fromRGB(46, 66, 104),
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
	new("UIStroke", { Thickness = t or 3.5, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
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
		ZIndex = 6,
	}, parent)
	new("UIStroke", { Thickness = 3, Color = INK, LineJoinMode = Enum.LineJoinMode.Bevel, Name = "Outline" }, t)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	return t
end

-- Studded slab: gradient face, black outline, words on top.
local function button(parent: Instance, name: string, textValue: string, color: Color3, size: UDim2, pos: UDim2): TextButton
	local b = new("TextButton", {
		Name = name,
		Size = size,
		Position = pos,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, parent)
	round(b, 10)
	outline(b)
	new("UIScale", { Name = "Press" }, b)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
	}, b)
	Hud.Studs(b).ZIndex = 5
	label(b, "Label", textValue, UDim2.new(1, -12, 0.7, 0), UDim2.new(0, 6, 0.15, 0))
	return b
end
Loop.Button = button

local function tile(parent: Instance, name: string, order: number, size: UDim2): Frame
	local f = new("Frame", { Name = name, LayoutOrder = order, Size = size, BackgroundColor3 = C.tile, ZIndex = 4 }, parent)
	round(f, 10)
	outline(f)
	return f
end

-- A left-grid square: the icon fills it, and its word sits over the lower edge.
local function square(rail: Instance, name: string, textValue: string, color: Color3, x: number, y: number, key: string, w: number?, h: number?): TextButton
	local b = button(rail, name, textValue, color, UDim2.fromOffset(w or 97, h or 99), UDim2.fromOffset(x, y))
	local l = b:FindFirstChild("Label") :: TextLabel
	l.TextScaled = false
	l.TextSize = 27
	l.Size = UDim2.new(1, 8, 0, 32)
	l.Position = UDim2.new(0, -4, 1, -32)
	l.ZIndex = 8
	Hud.Icon(b, "Icon", key, UDim2.fromOffset(84, 84), UDim2.new(0.5, 0, 0, 2), 6, Vector2.new(0.5, 0))
	local dot = new("Frame", { Name = "Dot", Visible = false, BackgroundColor3 = Color3.fromRGB(255, 50, 50), Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), ZIndex = 9 }, b)
	round(dot, 11)
	outline(dot, 2.5)
	return b
end

-- Reference colours (Hud.Palette): the left grid, then the menus.
local function theme(gui: any)
	local P = Hud.Paint
	local rail = gui.LoopRail
	P(rail.ShopBtn, "red")
	P(rail.PromoteBtn, "pink")
	P(rail.GiftBtn, "white")
	P(rail.DailyBtn, "lemon")
	local panel = gui.Panel
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.5
	panel.Header.Size = UDim2.new(1, 0, 0, 76)
	panel.Header.Position = UDim2.new()
	panel.Title.Size = UDim2.fromOffset(300, 60)
	panel.Title.Position = UDim2.new(0.5, -120, 0, 8)
	panel.HeaderIcon.Size = UDim2.fromOffset(70, 70)
	panel.HeaderIcon.Position = UDim2.new(0.5, -158, 0, 3)
	P(panel.Close, "red");
	(panel.Close:FindFirstChild("Studs") :: any).Visible = false
	P(panel.CodesTab, "cyan")
	local promo = panel.Promote
	for _, n in { "BeforePlate", "AfterPlate" } do
		P(promo[n], "red")
	end
	for _, n in { "WinsBeforePlate", "WinsAfterPlate" } do
		P(promo[n], "cyan")
	end
	promo.Bar.Fill.BackgroundColor3 = Color3.fromHex("#E21228")
	P(panel.Codes.Redeem, "go")
	local cards = { DoublePower = "gold", DoubleWins = "blueCard", AutoTrain = "red", Pack1 = "red", Pack2 = "cyan", Pack3 = "rainbow" }
	for key, look in cards do
		local c = panel.Shop.List:FindFirstChild(key)
		if c then
			P(c, look, if look == "rainbow" then 0 else 90);
			(c:FindFirstChild("Name") :: any).TextColor3 = WHITE
		end
	end
	-- Daily tiles: dark and see-through, each with its own coloured rim; the last one stands out
	local rims = { "#FFC21F", "#8A7A28", "#1F7F8F", "#7A1F2A", "#8A7A28", "#7A1F2A", "#C81CFF" }
	for i, hex in rims do
		local t = panel.Daily.Grid:FindFirstChild("Day" .. i) :: any
		if t then
			t.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
			t.BackgroundTransparency = 0.2;
			(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromHex(hex);
			(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 5;
			(t:FindFirstChild("Studs") :: any).Visible = false
		end
	end
	for _, t in panel.Gifts.Grid:GetChildren() do
		if t:IsA("TextButton") then
			t.BackgroundTransparency = 0.2;
			(t:FindFirstChild("Studs") :: any).Visible = false
		end
	end
	Hud.Soften(gui)
end

function Loop.Build(config: any): ScreenGui
	local gui = new("ScreenGui", { Name = "ChessLoop", ResetOnSpawn = false, IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 })
	new("UIScale", { Name = "Scale" }, gui)

	-- Left grid --------------------------------------------------------------
	local rail = new("Frame", { Name = "LoopRail", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, Hud.RailX, Hud.RailY, 0), Size = UDim2.fromOffset(205, 410) }, gui)
	-- Shop: the wide red bar, its crown poking over the top edge
	local shop = button(rail, "ShopBtn", "Shop", C.shop, UDim2.fromOffset(204, 58), UDim2.fromOffset(0, 133))
	local shopWord = shop:FindFirstChild("Label") :: TextLabel
	shopWord.TextScaled = false
	shopWord.TextSize = 42
	shopWord.Size = UDim2.fromScale(1, 1)
	shopWord.Position = UDim2.new()
	shopWord.ZIndex = 8
	Hud.Icon(shop, "Icon", "crown", UDim2.fromOffset(70, 70), UDim2.new(0.5, 0, 0, -16), 6, Vector2.new(0.5, 0))
	local shopDot = new("Frame", { Name = "Dot", Visible = false, Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1 }, shop)
	local _ = shopDot
	local promote = square(rail, "PromoteBtn", "Promote", C.promote, 107, 203, "promote")
	square(rail, "GiftBtn", "Rewards", C.gift, 0, 312, "gift")
	square(rail, "DailyBtn", "Daily", C.daily, 107, 312, "calendar")
	-- promotion progress is kept for the client, and shown as words on the panel
	local track = new("Frame", { Name = "Track", Visible = false, Size = UDim2.fromOffset(1, 1) }, promote)
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1) }, track)
	new("TextLabel", { Name = "Pct", Text = "" }, track)

	-- One shared panel ---------------------------------------------------------
	local dim = new("Frame", { Name = "Dim", Visible = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Active = true }, gui)
	local panel = new("Frame", { Name = "Panel", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 560), BackgroundColor3 = C.panel, BackgroundTransparency = 0.2, ZIndex = 21 }, gui)
	round(panel, 18)
	outline(panel, 4.5)
	new("UIScale", { Name = "Pop" }, panel)
	local header = new("Frame", { Name = "Header", BackgroundColor3 = C.shop, Size = UDim2.new(1, -16, 0, 66), Position = UDim2.fromOffset(8, 8), ZIndex = 22 }, panel)
	round(header, 12)
	outline(header)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }, header)
	Hud.Studs(header).ZIndex = 22
	Hud.Icon(panel, "HeaderIcon", "crown", UDim2.fromOffset(62, 62), UDim2.new(0.5, -128, 0, 10), 24, Vector2.new(0.5, 0))
	local title = label(panel, "Title", "", UDim2.fromOffset(330, 54), UDim2.new(0.5, -165, 0, 14), { ZIndex = 24 })
	title.TextColor3 = WHITE
	local close = button(panel, "Close", "X", C.shop, UDim2.fromOffset(52, 52), UDim2.new(1, -66, 0, 15))
	close.ZIndex = 26
	-- Codes sit in the Shop's header, where the reference keeps its own extra button
	local codesTab = button(panel, "CodesTab", "Codes", Color3.fromRGB(40, 150, 255), UDim2.fromOffset(112, 46), UDim2.new(1, -188, 0, 18))
	codesTab.ZIndex = 26
	local status = label(panel, "Status", "", UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 1, -34), { ZIndex = 24 })
	local _s, _d = status, dim
	-- the rail no longer carries a Codes square; LoopClient hooks CodesTab
	for _, d in { "Label", "Studs" } do
		local c = codesTab:FindFirstChild(d) :: any
		c.ZIndex = 27
	end
	for _, d in { "Label", "Studs" } do
		local c = close:FindFirstChild(d) :: any
		c.ZIndex = 27
	end

	local function page(name: string): Frame
		return new("Frame", { Name = name, Visible = false, BackgroundTransparency = 1, Size = UDim2.new(1, -32, 1, -128), Position = UDim2.new(0, 16, 0, 84), ZIndex = 22 }, panel)
	end

	-- Promote: Before -> After, like the reference's rebirth window
	local pPromote = page("Promote")
	label(pPromote, "BeforeHead", "Before", UDim2.fromOffset(200, 36), UDim2.fromOffset(54, 0))
	label(pPromote, "AfterHead", "After", UDim2.fromOffset(200, 36), UDim2.fromOffset(474, 0))
	local function plate(name: string, color: Color3, x: number, y: number): TextLabel
		local f = new("Frame", { Name = name .. "Plate", BackgroundColor3 = color, Size = UDim2.fromOffset(300, 66), Position = UDim2.fromOffset(x, y), ZIndex = 4 }, pPromote)
		round(f, 10)
		outline(f)
		Hud.Studs(f, 0.55).ZIndex = 4
		return label(pPromote, name, "", UDim2.fromOffset(280, 48), UDim2.fromOffset(x + 10, y + 9))
	end
	plate("Before", HC.slabRed, 4, 38)
	plate("After", HC.slabRed, 424, 38)
	plate("WinsBefore", HC.slabBlue, 4, 118)
	plate("WinsAfter", HC.slabBlue, 424, 118)
	Hud.Icon(pPromote, "Arrow1", "arrow", UDim2.fromOffset(84, 60), UDim2.fromOffset(322, 41), 6)
	Hud.Icon(pPromote, "Arrow2", "arrow", UDim2.fromOffset(84, 60), UDim2.fromOffset(322, 121), 6)
	local pTrack = new("Frame", { Name = "Bar", BackgroundColor3 = WHITE, Size = UDim2.fromOffset(720, 48), Position = UDim2.fromOffset(4, 198), ZIndex = 4 }, pPromote)
	round(pTrack, 8)
	outline(pTrack)
	local pFill = new("Frame", { Name = "Fill", BackgroundColor3 = HC.slabRed, Size = UDim2.fromScale(0, 1), ZIndex = 4 }, pTrack)
	round(pFill, 8)
	label(pTrack, "Label", "", UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))
	label(pPromote, "Note", "Promoting resets your Power and Wins! Sets and treadmills stay.", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 254), { TextColor3 = Color3.fromRGB(120, 255, 200) })
	local go = button(pPromote, "Go", "Promote", C.go, UDim2.fromOffset(250, 68), UDim2.fromOffset(106, 292))
	local _go = go
	Hud.Rainbow(button(pPromote, "Skip", "Skip", WHITE, UDim2.fromOffset(250, 68), UDim2.fromOffset(372, 292)))

	-- Shop: wide offer banners that scroll under the header
	local pShop = page("Shop")
	pShop.Size = UDim2.new(1, -32, 1, -100)
	local shopList = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 22 }, pShop)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, shopList)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, shopList)
	local function banner(key: string, order: number, color: Color3, art: string, title: string, desc: string, price: number)
		local card = tile(shopList, key, order, UDim2.new(1, -24, 0, 126))
		card.BackgroundColor3 = color
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }, card)
		Hud.Studs(card, 0.55).ZIndex = 4
		Hud.Icon(card, "Art", art, UDim2.fromOffset(106, 106), UDim2.fromOffset(12, 10), 6)
		label(card, "Name", title, UDim2.fromOffset(330, 50), UDim2.fromOffset(126, 10), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 232, 80) })
		label(card, "Text", desc, UDim2.fromOffset(330, 50), UDim2.fromOffset(126, 62), { TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		label(card, "Price", `{Hud.Robux} {price}`, UDim2.fromOffset(190, 40), UDim2.new(1, -206, 0, 10), { TextColor3 = HC.priceGreen })
		button(card, "Buy", "BUY", C.go, UDim2.fromOffset(190, 62), UDim2.new(1, -206, 1, -72))
	end
	local bannerColors = { DoublePower = HC.slabRed, DoubleWins = Color3.fromRGB(240, 165, 20), AutoTrain = Color3.fromRGB(30, 150, 235) }
	local bannerArt = { DoublePower = "power", DoubleWins = "trophy", AutoTrain = "cursor" }
	for key, pass in config.Passes do
		banner(key, pass.order, bannerColors[key] or C.tile, bannerArt[key] or "crown", pass.name, pass.text, pass.price)
	end
	for i, pack in config.PowerPacks or {} do
		banner(pack.key, 10 + i, if i == 3 then Color3.fromRGB(150, 50, 230) else if i == 2 then HC.slabBlue else Color3.fromRGB(205, 30, 60), "power", pack.label, "Instant Power", pack.price)
	end

	-- Daily: three and three, with the big last day standing tall on the right
	local pDaily = page("Daily")
	local dGrid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 340) }, pDaily)
	for i, wins in config.Daily do
		local big = i == 7
		local col, row = (i - 1) % 3, (i - 1) // 3
		local t = tile(dGrid, "Day" .. i, i, if big then UDim2.fromOffset(196, 332) else UDim2.fromOffset(165, 160))
		t.Position = if big then UDim2.fromOffset(530, 4) else UDim2.fromOffset(4 + col * 174, 4 + row * 172)
		Hud.Studs(t, 0.6).ZIndex = 4
		label(t, "Day", if big then "Big Reward" else `Day {i}`, UDim2.new(1, -8, 0, if big then 36 else 28), UDim2.new(0, 4, 0, 6))
		local artSize = if big then 150 else 96
		Hud.Icon(t, "Art", "trophy", UDim2.fromOffset(artSize, artSize), UDim2.new(0.5, 0, 0, if big then 70 else 28), 6, Vector2.new(0.5, 0))
		local check = Hud.Icon(t, "Check", "check", UDim2.fromOffset(artSize, artSize), UDim2.new(0.5, 0, 0, if big then 70 else 28), 7, Vector2.new(0.5, 0))
		check.Visible = false
		local lock = Hud.Icon(t, "Lock", "lock", UDim2.fromOffset(artSize, artSize), UDim2.new(0.5, 0, 0, if big then 70 else 28), 7, Vector2.new(0.5, 0))
		lock.Visible = false
		label(t, "Amount", `+{wins} Wins`, UDim2.new(1, -8, 0, if big then 44 else 32), UDim2.new(0, 4, 1, if big then -60 else -42), { TextColor3 = Color3.fromRGB(255, 225, 60) })
	end
	button(pDaily, "Claim", "CLAIM", C.go, UDim2.fromOffset(200, 54), UDim2.new(0.5, -100, 1, -54))
	pDaily.Size = UDim2.new(1, -32, 1, -112)

	-- Rewards: playtime gifts
	local pGift = page("Gifts")
	local gGrid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, pGift)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(168, 196), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, gGrid)
	for i, g in config.Playtime do
		local t = new("TextButton", { Name = "Gift" .. i, LayoutOrder = i, BackgroundColor3 = C.tile, AutoButtonColor = false, Text = "", ZIndex = 4 }, gGrid)
		round(t, 10)
		outline(t)
		new("UIScale", { Name = "Press" }, t)
		Hud.Studs(t, 0.6).ZIndex = 4
		Hud.Icon(t, "Art", "gift", UDim2.fromOffset(84, 84), UDim2.new(0.5, 0, 0, 6), 6, Vector2.new(0.5, 0))
		label(t, "Amount", `+{g.wins}`, UDim2.new(1, -8, 0, 34), UDim2.new(0, 4, 0, 90), { TextColor3 = Color3.fromRGB(255, 225, 60) })
		label(t, "Wins", "Wins", UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 122))
		label(t, "When", `{g.min}:00`, UDim2.new(1, -8, 0, 32), UDim2.new(0, 4, 1, -40))
	end

	-- Codes
	local pCodes = page("Codes")
	local box = new("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -80, 0, 76),
		Position = UDim2.new(0, 40, 0, 90),
		BackgroundColor3 = Color3.fromRGB(246, 246, 246),
		FontFace = FONT,
		TextSize = 36,
		TextColor3 = INK,
		PlaceholderText = "Type a code",
		PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 5,
	}, pCodes)
	round(box, 10)
	outline(box)
	button(pCodes, "Redeem", "Redeem", C.go, UDim2.fromOffset(250, 68), UDim2.new(0.5, -125, 0, 200))

	theme(gui)
	return gui
end

return Loop
