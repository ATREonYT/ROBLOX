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
local BODY_Y, BODY_X, BODY_W = 94, 18, 668

local pending: { [string]: boolean } = {}
local livePrice: { [string]: number } = {}

local function priceOf(p) return livePrice[p.Key] or p.Price end

-- One buy button's look for a product right now.
local function buttonState(p, wordPrice: boolean?): (string, string, string?)
	if State.owns(p.Key) then return "OWNED", "Disabled", "CheckEquipped" end
	if pending[p.Key] then return "...", "Disabled", nil end
	if Products.status(p) == "Soon" then return "SOON", "Disabled", nil end
	-- The reference writes "99 Robux" on cosmetics and coins, and the Robux sign + number on the big pass button.
	return if wordPrice then Format.commas(priceOf(p)) .. " Robux" else Format.robux(priceOf(p)), "Action", nil
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
		local text, style, iconName = buttonState(p, props.WordPrice)
		b.setText(text)
		b.setFont(if text:find("%d") then Theme.Fonts.Number else Theme.Fonts.Button) -- prices: Montserrat Bold
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

-- Product picture: the kit's own art for this product, filling the block (left of rows, top of coin cards).
local function art(parent: Instance, p, size: Vector2)
	local f = new("Frame", { Name = "Art", Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = Color3.fromHex("2D4F8E"), BorderSizePixel = 0, ClipsDescendants = true, Parent = parent }, { Kit.corner(4) })
	Kit.art(p.Art, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = f })
	return f
end

-- A row/card: #213451 -> #243954 fill with a 1 px #2E4669 rim (coin cards: #193A5C with a 1.5 px #2C5786 rim).
local function card(parent: Instance, name: string, pos: Vector2, size: Vector2, coin: boolean?)
	local f = new("Frame", { Name = name, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = coin and C.CoinCard or Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(coin and C.CoinCardRim or C.RowBorder, coin and 1.5 or 1) })
	if not coin then new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = f }) end
	return f
end

-- Passes: broad rows (reference 01).
local function buildPasses(body: Frame)
	local y = 0
	for i, p in Products.Passes do
		local h = i == 1 and 97 or 103 -- the reference's two rows differ slightly
		local row = card(body, p.Key, Vector2.new(0, y), Vector2.new(BODY_W, h))
		y += h + 10
		art(row, p, Vector2.new(171, h))
		Kit.name({ Name = "Name", Text = p.Name, TextSize = T.Name, Position = UDim2.fromOffset(183, 9), Size = UDim2.fromOffset(150, 32), Parent = row })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = T.Blurb, Position = UDim2.fromOffset(183, 44), Size = UDim2.fromOffset(140, 42), TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.0, Parent = row })
		new("Frame", { Name = "Divider", Position = UDim2.fromOffset(327, 22), Size = UDim2.fromOffset(2, 54), BackgroundColor3 = C.Divider, BorderSizePixel = 0, Parent = row })
		local bx = p.Giftable and -10 or 0 -- rows with a gift button start their benefits 10 px further left
		for j, b in p.Benefits or {} do
			local by = 19 + (j - 1) * 33
			Kit.icon(b.Icon, { Name = "BenefitIcon" .. j, Position = UDim2.fromOffset(343 + bx, by), Size = UDim2.fromOffset(26, 26), Parent = row })
			Kit.text({ Name = "Benefit" .. j, Text = b.Text, TextSize = T.Label, Position = UDim2.fromOffset(392 + bx, by), Size = UDim2.fromOffset(112, 26), TextWrapped = false, Parent = row })
		end
		if p.Giftable then
			buyButton(row, p, { Position = UDim2.new(1, -63, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(103, 51), TextSize = 25 })
			local gift = Kit.button({ Name = "Gift", Style = "Disabled", Icon = "GiftAction", IconSize = 32, Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(44, 51), Parent = row })
			gift.onClick(function() Toast.show("Gifting unavailable for now.") end)
		else
			buyButton(row, p, { Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(135, 41), TextSize = 24, IconSize = 26 })
		end
	end
end

-- Cosmetics: 2 x 2 cards (reference 07).
local function buildCosmetics(body: Frame)
	local cw, ch = 321, 101
	for i, p in Products.Cosmetics do
		local col, rowN = (i - 1) % 2, (i - 1) // 2
		local c = card(body, p.Key, Vector2.new(3 + col * (cw + 10), rowN * (ch + 8)), Vector2.new(cw, ch))
		art(c, p, Vector2.new(160, ch))
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 18, Position = UDim2.fromOffset(170, 7), Size = UDim2.fromOffset(cw - 178, 24), Parent = c })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, Position = UDim2.fromOffset(170, 30), Size = UDim2.fromOffset(cw - 178, 32), TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		buyButton(c, p, { Position = UDim2.new(0, 170, 1, -8), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(cw - 178, 30), TextSize = 17, IconSize = 18, WordPrice = true })
	end
end

-- Coins: 3 tall cards (reference 08).
local function buildCoins(body: Frame)
	local cw, ch = (BODY_W - 20) / 3, 211
	for i, p in Products.Coins do
		local c = card(body, p.Key, Vector2.new((i - 1) * (cw + 10), 0), Vector2.new(cw, ch), true)
		local a = art(c, p, Vector2.new(cw, 106))
		a.BackgroundColor3 = C.CoinArt
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 26), Parent = c })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 137), Size = UDim2.new(1, -16, 0, 30), Parent = c })
		buyButton(c, p, { Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -22, 0, 36), TextSize = 20, IconSize = 20, WordPrice = true })
	end
end

local BUILD = { Passes = buildPasses, Cosmetics = buildCosmetics, Coins = buildCoins }

function Shop.build(parent: Instance)
	local window = Kit.window({ Name = "Shop", Title = "SHOP", Icon = "ShopCart", Width = W, Height = H, TitleWidth = 101, StudsTo = 352, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(357, 6), Width = 121, Parent = header })
	local gems = Kit.pill({ Name = "Gems", Icon = "CurrencyGem", Position = UDim2.fromOffset(493, 6), Width = 108, Parent = header })
	Kit.studs(header, 612, 650, 16)

	local body = new("ScrollingFrame", { Name = "Products", Position = UDim2.fromOffset(BODY_X, BODY_Y), Size = UDim2.fromOffset(BODY_W + 6, H - BODY_Y - 10), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })

	local tabs
	local function show(key: string)
		refreshButtons = {}
		for _, ch in body:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		body.CanvasPosition = Vector2.zero
		BUILD[key](body)
	end
	tabs = Kit.tabs(panel, {
		{ Key = "Passes", Text = "PASSES", X = 16, Width = 187 },
		{ Key = "Cosmetics", Text = "COSMETICS", X = 207, Width = 230 },
		{ Key = "Coins", Text = "COINS", X = 441, Width = 246 },
	}, 54, 30, show)

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
