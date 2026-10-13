-- Shop (design/pages/01, 07, 08): Passes / Cosmetics / Coins tabs over one stationary window.
-- Buy buttons only open Roblox's purchase prompt; the server grants (ShopService). Each button shows exactly one
-- state: price (buyable), "..." (prompt open), OWNED, or SOON (the item's content isn't in the game yet).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)

local C, T = Theme.Colors, Theme.Text
local new = Kit.new

local Shop = {}

local W, H = 701, 315
local BODY_Y, BODY_X, BODY_W = 91, 18, 668

local pending: { [string]: boolean } = {}
local livePrice: { [string]: number } = {}

local function priceOf(p) return livePrice[p.Key] or p.Price end

-- One buy button's look for a product right now.
local function buttonState(p): (string, string, string?)
	if State.owns(p.Key) then return "OWNED", "Disabled", "CheckEquipped" end
	if pending[p.Key] then return "...", "Disabled", nil end
	if Products.status(p) == "Soon" then return "SOON", "Disabled", nil end
	return Format.robux(priceOf(p)), "Action", nil
end

local refreshButtons: { () -> () } = {}

local function buy(p)
	if State.owns(p.Key) or pending[p.Key] then return end
	local status = Products.status(p)
	if status == "Soon" then
		Toast.show(p.Name .. " is coming soon.")
		return
	elseif status == "NoId" then
		Toast.show("This item isn't on sale yet.")
		warn(string.format("[Shop] %s has no %s ID in Shared/Config/Products.lua", p.Key, p.Kind == "Pass" and "Game Pass" or "Developer Product"))
		return
	end
	pending[p.Key] = true
	for _, f in refreshButtons do f() end
	local player = Players.LocalPlayer
	local ok = pcall(function()
		if p.Kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, p.Id)
		else
			MarketplaceService:PromptProductPurchase(player, p.Id)
		end
	end)
	if not ok then
		pending[p.Key] = nil
		Toast.show("The purchase couldn't open. Try again.")
	else
		task.delay(90, function() -- never leave a button stuck if Roblox doesn't report back
			if pending[p.Key] then pending[p.Key] = nil; for _, f in refreshButtons do f() end end
		end)
	end
	for _, f in refreshButtons do f() end
end

local function onPromptClosed(id: number, isPass: boolean)
	for _, list in { Products.Passes, Products.Cosmetics, Products.Coins } do
		for _, p in list do
			if p.Id == id and (p.Kind == "Pass") == isPass then pending[p.Key] = nil end
		end
	end
	for _, f in refreshButtons do f() end
end

-- The price/owned button, kept in sync with ownership and pending state.
local function buyButton(parent: Instance, p, props)
	local b = Kit.button({ Name = "Buy", Parent = parent, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, TextSize = props.TextSize or T.Button, IconAfter = true, IconSize = props.IconSize or 22 })
	local icon: ImageLabel? = nil
	local function refresh()
		if not b.Instance.Parent then return end
		local text, style, iconName = buttonState(p)
		b.setText(text)
		b.setFont(text:sub(1, #Format.RobuxMark) == Format.RobuxMark and Theme.Fonts.Number or Theme.Fonts.Button) -- prices: Montserrat Bold
		b.setStyle(style)
		if iconName and not icon then
			icon = Kit.icon(iconName, { Name = "Icon", Size = UDim2.fromOffset(props.IconSize or 22, props.IconSize or 22), LayoutOrder = 3, Parent = b.Instance:FindFirstChild("Content") })
		elseif not iconName and icon then
			icon:Destroy()
			icon = nil
		end
	end
	b.onClick(function() buy(p) end)
	table.insert(refreshButtons, refresh)
	refresh()
	return b
end

-- Art block on the left of a row: the player's avatar with the product's icon in front (no catalogue models yet).
local function art(parent: Instance, p, size: Vector2, iconSize: number)
	local f = new("Frame", { Name = "Art", Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = Color3.fromHex("2D4F8E"), BorderSizePixel = 0, ClipsDescendants = true, Parent = parent }, { Kit.corner(4) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("3A63A8"), Color3.fromHex("1F3A6E")), Parent = f })
	Kit.icon("Avatar", { Name = "Avatar", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 6), Size = UDim2.fromOffset(size.Y * 1.05, size.Y * 1.05), Parent = f })
	if p.Icon ~= "Avatar" then
		Kit.icon(p.Icon, { Name = "ProductIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 4), Size = UDim2.fromOffset(iconSize, iconSize), ZIndex = 2, Parent = f })
	end
	return f
end

local function card(parent: Instance, name: string, pos: Vector2, size: Vector2)
	return new("Frame", { Name = name, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, Parent = parent }, { Kit.corner(5), Kit.stroke(C.RowBorder, 1.5, 0.2) })
end

-- Passes: broad rows (reference 01).
local function buildPasses(body: Frame)
	for i, p in Products.Passes do
		local row = card(body, p.Key, Vector2.new(0, (i - 1) * 108), Vector2.new(BODY_W, 98))
		art(row, p, Vector2.new(171, 98), 58)
		Kit.name({ Name = "Name", Text = p.Name, TextSize = T.Name, Position = UDim2.fromOffset(183, 10), Size = UDim2.fromOffset(140, 32), Parent = row })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = T.Blurb, Position = UDim2.fromOffset(183, 44), Size = UDim2.fromOffset(140, 42), TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.0, Parent = row })
		new("Frame", { Name = "Divider", Position = UDim2.fromOffset(327, 22), Size = UDim2.fromOffset(2, 54), BackgroundColor3 = C.Divider, BorderSizePixel = 0, Parent = row })
		for j, b in p.Benefits or {} do
			local y = 19 + (j - 1) * 33
			Kit.icon(b.Icon, { Name = "BenefitIcon" .. j, Position = UDim2.fromOffset(343, y), Size = UDim2.fromOffset(26, 26), Parent = row })
			Kit.text({ Name = "Benefit" .. j, Text = b.Text, TextSize = T.Label, Position = UDim2.fromOffset(392, y), Size = UDim2.fromOffset(112, 26), TextWrapped = false, Parent = row })
		end
		if p.Giftable then
			buyButton(row, p, { Position = UDim2.new(1, -63, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(102, 47), TextSize = 25 })
			local gift = Kit.button({ Name = "Gift", Style = "Disabled", Icon = "GiftBenefit", IconSize = 30, Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(44, 47), Parent = row })
			gift.onClick(function() Toast.show("Gifting unavailable for now.") end)
		else
			buyButton(row, p, { Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(135, 41), TextSize = 22 })
		end
	end
end

-- Cosmetics: 2 x 2 cards (reference 07).
local function buildCosmetics(body: Frame)
	local cw, ch = (BODY_W - 10) / 2, 101
	for i, p in Products.Cosmetics do
		local col, rowN = (i - 1) % 2, (i - 1) // 2
		local c = card(body, p.Key, Vector2.new(col * (cw + 10), rowN * (ch + 10)), Vector2.new(cw, ch))
		art(c, p, Vector2.new(112, ch), 0)
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 18, Position = UDim2.fromOffset(122, 8), Size = UDim2.fromOffset(cw - 130, 24), Parent = c })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, Position = UDim2.fromOffset(122, 32), Size = UDim2.fromOffset(cw - 130, 32), TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		buyButton(c, p, { Position = UDim2.new(0, 122, 1, -8), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(cw - 132, 25), TextSize = 15, IconSize = 16 })
	end
end

-- Coins: 3 tall cards (reference 08).
local function buildCoins(body: Frame)
	local cw, ch = (BODY_W - 20) / 3, 212
	for i, p in Products.Coins do
		local c = card(body, p.Key, Vector2.new((i - 1) * (cw + 10), 0), Vector2.new(cw, ch))
		local s = 50 + i * 12
		Kit.icon(p.Icon, { Name = "Art", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cw / 2, 56), Size = UDim2.fromOffset(s, s), Parent = c })
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 26), Parent = c })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 136), Size = UDim2.new(1, -16, 0, 30), Parent = c })
		buyButton(c, p, { Position = UDim2.new(0.5, 0, 1, -9), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -18, 0, 28), TextSize = 16, IconSize = 18 })
	end
end

local BUILD = { Passes = buildPasses, Cosmetics = buildCosmetics, Coins = buildCoins }

function Shop.build(parent: Instance)
	local window = Kit.window({ Name = "Shop", Title = "SHOP", Icon = "ShopCart", Width = W, Height = H, StudsTo = 352, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(360, 8), Width = 112, Parent = header })
	local gems = Kit.pill({ Name = "Gems", Icon = "CurrencyGem", Position = UDim2.fromOffset(490, 8), Width = 112, Parent = header })
	Kit.studs(header, 610, 650, 18)

	local body = new("ScrollingFrame", { Name = "Products", Position = UDim2.fromOffset(BODY_X, BODY_Y), Size = UDim2.fromOffset(BODY_W + 6, H - BODY_Y - 10), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })

	local tabs
	local function show(key: string)
		refreshButtons = {}
		for _, ch in body:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		body.CanvasPosition = Vector2.zero
		BUILD[key](body)
	end
	tabs = Kit.tabs(panel, {
		{ Key = "Passes", Text = "PASSES", X = 14, Width = 204 },
		{ Key = "Cosmetics", Text = "COSMETICS", X = 226, Width = 211 },
		{ Key = "Coins", Text = "COINS", X = 446, Width = 239 },
	}, 51, 30, show)

	local function openTab(key: string)
		if tabs.selected() ~= key then tabs.select(key); show(key) end
	end
	coins.plus.onClick(function() openTab("Coins") end)
	gems.plus.onClick(function() Toast.show("Gem packs aren't for sale.") end)

	State.changed(function(data)
		coins.setAmount(Format.commas(data.Coins))
		gems.setAmount(Format.commas(data.Gems))
		for _, f in refreshButtons do f() end
	end)
	coins.setAmount(Format.commas(State.data.Coins))
	gems.setAmount(Format.commas(State.data.Gems))

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id) if player == Players.LocalPlayer then onPromptClosed(id, true) end end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id) if Players.LocalPlayer and userId == Players.LocalPlayer.UserId then onPromptClosed(id, false) end end)

	-- Live Robux prices for items that are set up (the configured price shows until then).
	task.spawn(function()
		for _, list in { Products.Passes, Products.Cosmetics, Products.Coins } do
			for _, p in list do
				if Products.status(p) == "Ready" then
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.Id, p.Kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
					if ok and info and type(info.PriceInRobux) == "number" then livePrice[p.Key] = info.PriceInRobux end
				end
			end
		end
		for _, f in refreshButtons do f() end
	end)

	ModalManager.register("Shop", {
		window = window,
		onOpen = function(tab) openTab(tab or tabs.selected() or "Passes") end,
		firstSelect = function() return tabs.buttons.Passes.Instance end,
	})
	tabs.select("Passes")
	show("Passes")
	return window
end

return Shop
