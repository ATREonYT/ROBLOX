-- Shop (design/pages/01, 07, 08): Passes / Cosmetics / Coins tabs over one stationary window.
-- Buy buttons only open Roblox's purchase prompt; the server grants (ShopService). Each button shows exactly one
-- state: Robux badge + price, "..." (prompt open) or OWNED. Items that aren't on sale yet show their price like the
-- reference but only say "coming soon" when tapped; they never open a purchase.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)

local C, T = Theme.Colors, Theme.Text
local new = Kit.new

local Shop = {}

local W, H = 701, 320 -- every main window shares this size
local BODY_Y, BODY_X, BODY_W = 94, 18, 668
local RIM = 4 -- padding inside the scrolling body so card rims (and the cosmetics cards' -2 x) aren't clipped

local pending: { [string]: boolean } = {}
local livePrice: { [string]: number } = {}

local function priceOf(p) return livePrice[p.Key] or p.Price end

-- One buy button's look for a product right now.
-- Returns text, style, icon, and whether the Robux badge shows. Every Robux price wears the badge (Roblox's own
-- Robux mark, U+E002). Items not on sale yet still show their price like the reference, but never open a purchase.
local function buttonState(p): (string, string, string?, boolean)
	if State.owns(p.Key) then return "OWNED", "Disabled", "CheckEquipped", false end
	if pending[p.Key] then return "...", "Disabled", nil, false end
	return Format.commas(priceOf(p)), "Action", nil, true
end

local refreshButtons: { () -> () } = {}

local function buy(p)
	if State.owns(p.Key) or pending[p.Key] then return end
	local status = Products.status(p)
	if status == "Soon" then
		Toast.show(p.Name .. " is coming soon.") -- shown with its price, but never sold until it gives something
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
	local b = Kit.button({ Name = "Buy", Parent = parent, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, TextSize = props.TextSize or T.Button, IconAfter = true, IconSize = props.IconSize or 22, Gap = 6, Corner = props.Corner })
	local textSize = props.TextSize or T.Button
	Effects.shine(b.Instance, { every = 4, delay = math.random() * 2, corner = props.Corner or Theme.Corner, z = 6 }) -- (a white glint every few seconds)
	local badge = Kit.text({ Name = "RobuxBadge", Text = Format.RobuxMark, FontFace = Theme.Fonts.Number, TextSize = math.floor(textSize * (props.BadgeScale or 1.5)), TextColor3 = C.RobuxBadge, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, Parent = b.Instance:FindFirstChild("Content") })
	local icon: ImageLabel? = nil
	local function refresh()
		if not b.Instance.Parent then return end
		local text, style, iconName, priced = buttonState(p)
		badge.Visible = priced
		b.setText(text)
		b.setFont(if text:find("%d") then Theme.Fonts.Number else Theme.Fonts.Button) -- prices: Montserrat Bold
		b.setStyle(if style == "Action" and props.Style then props.Style else style)
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

-- Product picture: the kit's own art for this product, filling the block at the left of a row/card. The rounding
-- is on the image itself (ClipsDescendants clips square in Roblox, so a rounded parent alone would show corners).
-- Only the left corners are rounded: a square copy, clipped to the right of the corner radius, covers the right ones.
-- A lit backdrop behind the see-through pictures (as the kit's cards have): blue at the top left into deep indigo.
local function backdrop(f: Instance, r: number)
	new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 0, Parent = f }, {
		Kit.corner(r),
		new("UIGradient", { Rotation = 60, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("4F78EC")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("3B47B8")), ColorSequenceKeypoint.new(1, Color3.fromHex("2A2475")) }) }),
	})
end

local function art(parent: Instance, p, size: Vector2)
	local r = 4
	local f = new("Frame", { Name = "Art", Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Parent = parent })
	backdrop(f, r)
	Kit.attach(Kit.corner(r), Kit.art(p.Art, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = f }))
	local right = new("Frame", { Name = "Right", Position = UDim2.fromOffset(r, 0), Size = UDim2.new(1, -r, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = f })
	Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(-r, 0), Size = UDim2.fromOffset(size.X, size.Y), Parent = right })
	return f
end

-- A row/card: #213451 -> #243954 fill with a 1 px #2E4669 rim.
local function card(parent: Instance, name: string, pos: Vector2, size: Vector2)
	local f = new("Frame", { Name = name, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(C.RowBorder, 1) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = f })
	return f
end

-- Passes: broad rows, after the owner's pass banners (design/shop/pass-banners.png): deep see-through navy with a
-- glowing rim in the pass's colour, the banner's character picture at the left, a big title with a soft colour
-- fade and a short line under it, the blurb tinted, and the price button in the same colour.
local function buildPasses(body: Frame)
	local y = 0
	for i, p in Products.Passes do
		local h = i == 1 and 97 or 103 -- the reference's two rows differ slightly
		local accent = p.Accent or C.Action
		local row = card(body, p.Key, Vector2.new(0, y), Vector2.new(BODY_W, h))
		row.BackgroundTransparency = Theme.Transparency.Row
		local fill = row:FindFirstChildOfClass("UIGradient")
		if fill then fill.Color = ColorSequence.new(Color3.fromHex("1A1B3D"), Color3.fromHex("121331")) end
		local rim = row:FindFirstChildOfClass("UIStroke")
		if rim then rim.Color, rim.Thickness = accent, 2 end
		-- a soft glow of the pass's colour from the left, behind everything
		new("Frame", { Name = "Glow", Size = UDim2.new(0.55, 0, 1, 0), BackgroundColor3 = accent, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 0, Parent = row }, {
			Kit.corner(4), new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		y += h + 10
		art(row, p, Vector2.new(171, h))
		Effects.shine(row, { every = 5, delay = (i - 1) * 1.2, corner = 4, strength = 0.28, z = 5 }) -- a slow streak across the whole banner
		local title = Kit.name({ Name = "Name", Text = string.upper(p.Name), FontFace = Theme.Fonts.Heading, TextSize = if #p.Name > 6 then 20 else 27, TextWrapped = false, Position = UDim2.fromOffset(183, 9), Size = UDim2.fromOffset(140, 32), Parent = row }) -- (long names smaller, so DANCE PACK ends before the divider)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), accent:Lerp(Color3.new(1, 1, 1), 0.55)), Parent = title })
		new("Frame", { Name = "Underline", Position = UDim2.fromOffset(184, 42), Size = UDim2.fromOffset(120, 2), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = row }, {
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = T.Blurb, TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.7), Position = UDim2.fromOffset(183, 49), Size = UDim2.fromOffset(140, 42), TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.0, Parent = row })
		new("Frame", { Name = "Divider", Position = UDim2.fromOffset(327, 15), Size = UDim2.fromOffset(2, h - 29), BackgroundColor3 = accent, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = row })
		local bx = p.Giftable and -10 or 0 -- rows with a gift button start their benefit text 10 px further left
		for j, b in p.Benefits or {} do
			local by = if i == 1 then 19 + (j - 1) * 33 else 25 + (j - 1) * 34
			Kit.icon(b.Icon, { Name = "BenefitIcon" .. j, Position = UDim2.fromOffset(343, by), Size = UDim2.fromOffset(26, 26), Parent = row })
			local benefit = Kit.text({ Name = "Benefit" .. j, Text = b.Text, TextSize = T.Label, TextScaled = true, Position = UDim2.fromOffset(392 + bx, by), Size = UDim2.fromOffset(112, 26), TextWrapped = false, Parent = row })
			new("UITextSizeConstraint", { Name = "Fit", MaxTextSize = math.round(T.Label * 0.86), Parent = benefit }) -- (shrinks a long line to its column)
		end
		if p.Giftable then
			buyButton(row, p, { Position = UDim2.new(1, -63, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(103, 51), TextSize = 27, BadgeScale = 1.7, Style = p.ButtonStyle })
			-- Fully purple gift button with the kit's gift art centred at its normal size (the gift itself still says
			-- "unavailable" until the Gift Picker exists).
			local gift = Kit.button({ Name = "Gift", Style = "Gift", Text = "", Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(44, 51), Parent = row })
			gift.Instance:FindFirstChild("Content"):Destroy()
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.GiftTop, C.GiftBottom), Parent = gift.Instance })
			Kit.icon("GiftAction", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 41), Parent = gift.Instance })
			gift.onClick(function() Toast.show("Gifting unavailable for now.") end)
		else
			buyButton(row, p, { Position = UDim2.new(1, -11, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(135, 41), TextSize = 24, IconSize = 26, Style = p.ButtonStyle })
		end
	end
end

-- Cosmetics: 2 x 2 cards (reference 07).
local function buildCosmetics(body: Frame)
	local cw, ch = 331, 101
	for i, p in Products.Cosmetics do
		local col, rowN = (i - 1) % 2, (i - 1) // 2
		local c = card(body, p.Key, Vector2.new(-2 + col * (cw + 10), rowN * (ch + 8)), Vector2.new(cw, ch))
		art(c, p, Vector2.new(160, ch))
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 17, Position = UDim2.fromOffset(170, 6), Size = UDim2.fromOffset(cw - 178, 22), Parent = c })
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, LineHeight = 0.9, Position = UDim2.fromOffset(170, 31), Size = UDim2.fromOffset(cw - 178, 28), TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		buyButton(c, p, { Position = UDim2.new(0, 170, 1, -8), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(cw - 178, 30), TextSize = 19, IconSize = 22 })
	end
end

-- Coins: 3 tall cards (reference 08), measured card by card. The reference's cards differ slightly in width and
-- button inset, so each card keeps its own numbers. X is window-relative inside the coin body; the window is 3 px
-- narrower than the reference, taken out of the two gaps and the last card. The reference page is 9 px taller than
-- the window, so every vertical number is the reference's times 0.96 (card 225 -> 216 tall; the art crops 1-2 px).
local COIN_BODY = { X = 15, Y = 91, H = H - 91 - 6 } -- the cards' rims sit 1 px inside this
local COIN_CARDS = {
	{ X = 16, W = 209, ButtonX = 9, ButtonW = 189, TextDX = 0 },
	{ X = 237, W = 206, ButtonX = 8, ButtonW = 189, TextDX = 1 },
	{ X = 455, W = 230, ButtonX = 13, ButtonW = 205, TextDX = 3 },
}
local COIN_H, COIN_ART_H = 216, 106

-- The kit's art, top corners rounded to the card's inner radius and bottom corners square: one rounded copy, and a
-- square copy clipped to everything below the corners (ClipsDescendants clips square, so no background shows).
local function coinArt(parent: Instance, p, w: number, h: number)
	local r = 4
	local panel = new("Frame", { Name = "Art", Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = parent })
	backdrop(panel, r)
	Kit.attach(Kit.corner(r), Kit.art(p.Art, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = panel }))
	local lower = new("Frame", { Name = "Lower", Position = UDim2.fromOffset(0, r), Size = UDim2.new(1, 0, 1, -r), BackgroundTransparency = 1, ClipsDescendants = true, Parent = panel })
	Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(0, -r), Size = UDim2.fromOffset(w, h), Parent = lower })
	return panel
end

local function buildCoins(body: Frame)
	local artEnd = COIN_ART_H / COIN_H
	for i, p in Products.Coins do
		local d = COIN_CARDS[i]
		local c = new("Frame", { Name = p.Key, Position = UDim2.fromOffset(d.X - COIN_BODY.X, 1), Size = UDim2.fromOffset(d.W, COIN_H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body }, { Kit.corner(4), Kit.stroke(C.CoinCardRim, 1) })
		new("UIGradient", { Rotation = 90, Parent = c, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.CoinCardShade), ColorSequenceKeypoint.new(artEnd, C.CoinCardShade),
			ColorSequenceKeypoint.new(artEnd + 0.07, C.CoinCard), ColorSequenceKeypoint.new(0.85, C.CoinCardBottom),
			ColorSequenceKeypoint.new(1, C.CoinCard),
		}) })
		coinArt(c, p, d.W, COIN_ART_H)
		Effects.shine(c, { every = 5, delay = (i - 1) * 0.9, corner = 4, strength = 0.28, z = 5 })
		Kit.name({ Name = "Name", Text = p.Name, TextSize = 20, TextColor3 = C.CoinText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(d.TextDX, 109), Size = UDim2.new(1, 0, 0, 26), Parent = c })
		local blurb = Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 13, TextColor3 = C.CoinBlurb, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.05, Position = UDim2.fromOffset(d.TextDX, 138), Size = UDim2.new(1, 0, 0, 32), Parent = c })
		local shadow = blurb:Clone() -- the reference's descriptions sit on the same soft drop as the names
		shadow.Name, shadow.TextColor3, shadow.TextTransparency, shadow.Position = "BlurbShadow", C.TextShadow, 0.5, blurb.Position + UDim2.fromOffset(0, 1)
		shadow = Kit.attach(shadow, c)
		blurb.ZIndex = 2
		local b = buyButton(c, p, { Position = UDim2.fromOffset(d.ButtonX, 175), Size = UDim2.fromOffset(d.ButtonW, 35), TextSize = 20, Style = "CoinAction", Corner = 4 })
		-- the reference's 1 px lighter bevel just inside the dark rim, all the way round
		new("Frame", { Name = "Bevel", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = b.Instance.ZIndex, Parent = b.Instance }, { Kit.corner(2), Kit.stroke(C.CoinBuyBevel, 1) })
	end
end

-- ITEMS: the coin shop (Config/CoinShop; owner: "make the coins usable"). Looks only: trails, name colours and
-- knife skins, three to a row. Each card shows a preview in the item's own colours, its name and slot, and one
-- button: the coin price (buy and wear it), WEAR (owned), or WEARING (tap to take it off). The server decides.
local ITEM = { W = 216, H = 92, Gap = 10, Swatch = 64 }
local function swatch(parent: Instance, item: CoinShop.Item)
	local f = new("Frame", { Name = "Swatch", Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(ITEM.Swatch, ITEM.Swatch), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = parent }, { Kit.corner(8) })
	if item.Slot == "Trail" then
		-- a streak fading out behind a runner: the colours along it, solid at the front
		local streak = new("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, 22), Rotation = -20, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f }, { Kit.corner(11) })
		new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }), Parent = streak })
	elseif item.Slot == "Tag" then
		local word = Kit.text({ Name = "Word", Text = "Aa", FontFace = Theme.Fonts.Heading, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = item.Colors[1], Size = UDim2.fromScale(1, 1), Parent = f })
		new("UIStroke", { Name = "Outline", Color = C.Frame, Thickness = 1.5, Parent = word })
		if #item.Colors > 2 then
			word.TextColor3 = Color3.new(1, 1, 1)
			new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Parent = word })
		end
	else
		-- a little knife: the blade in the skin's colour, the guard and handle under it
		local knife = new("Frame", { Name = "Knife", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 52), Rotation = 35, BackgroundTransparency = 1, Parent = f })
		new("Frame", { Name = "Blade", Size = UDim2.fromOffset(14, 30), BackgroundColor3 = item.Colors[1], BorderSizePixel = 0, Parent = knife }, { Kit.corner(7) })
		new("Frame", { Name = "Guard", Position = UDim2.fromOffset(-5, 30), Size = UDim2.fromOffset(24, 5), BackgroundColor3 = item.Colors[#item.Colors], BorderSizePixel = 0, Parent = knife }, { Kit.corner(2) })
		new("Frame", { Name = "Handle", Position = UDim2.fromOffset(3, 35), Size = UDim2.fromOffset(8, 17), BackgroundColor3 = C.Ink, BorderSizePixel = 0, Parent = knife }, { Kit.corner(3) })
	end
	return f
end

local function buildItems(body: Frame)
	local list = {}
	for _, item in CoinShop.Items do -- (prizes such as the Spin Knife show only once you own them)
		if not item.NotForSale or State.data.Cosmetics[item.Key] then table.insert(list, item) end
	end
	table.sort(list, function(a, b) return a.Order < b.Order end)
	for i, item in list do
		local col, rowN = (i - 1) % 3, (i - 1) // 3
		local c = card(body, item.Key, Vector2.new(-2 + col * (ITEM.W + ITEM.Gap), rowN * (ITEM.H + 8)), Vector2.new(ITEM.W, ITEM.H))
		swatch(c, item)
		Kit.name({ Name = "Name", Text = item.Name, TextSize = 16, Position = UDim2.fromOffset(84, 10), Size = UDim2.fromOffset(ITEM.W - 92, 20), Parent = c })
		Kit.text({ Name = "Slot", Text = CoinShop.SlotNames[item.Slot], FontFace = Theme.Fonts.Label, TextSize = 12, TextColor3 = C.SubText, Position = UDim2.fromOffset(84, 31), Size = UDim2.fromOffset(ITEM.W - 92, 16), TextWrapped = false, Parent = c })
		local b = Kit.button({ Name = "Buy", Text = "", Icon = "CurrencyCoin", IconSize = 20, Gap = 6, TextSize = 17, FontFace = Theme.Fonts.Number, Style = "Action", Position = UDim2.fromOffset(84, 52), Size = UDim2.fromOffset(ITEM.W - 94, 30), Parent = c })
		local icon = b.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local function refresh()
			local owned = State.data.Cosmetics[item.Key] == true
			local worn = (State.data.Wear or {})[item.Slot] == item.Key
			if icon then icon.Visible = not owned and not item.Unlock end
			if not owned and item.Unlock then
				b.setText("EARN IT") -- (quest knives: never sold; the tap says where)
				b.setStyle("Disabled")
			elseif not owned then
				b.setText(Format.commas(item.Price))
				b.setStyle(if (State.data.Coins or 0) >= item.Price then "Action" else "Disabled")
			else
				b.setText(if worn then "WEARING" else "WEAR")
				b.setStyle(if worn then "Selected" else "Tab")
			end
		end
		b.onClick(function()
			local owned = State.data.Cosmetics[item.Key] == true
			local ok, why
			if not owned and item.Unlock then
				Toast.show(`{item.Name}: {item.Unlock}`)
				return
			elseif not owned then
				ok, why = State.action("BuyWithCoins", item.Key)
				Toast.show(if ok then `{item.Name} is yours!` else (why or "Couldn't buy that."))
			else
				local worn = (State.data.Wear or {})[item.Slot] == item.Key
				ok, why = State.action("Wear", item.Slot, if worn then nil else item.Key)
				if not ok then Toast.show(why or "Couldn't change that.") end
			end
		end)
		table.insert(refreshButtons, refresh)
		refresh()
	end
end

local BUILD = { Passes = buildPasses, Cosmetics = buildCosmetics, Items = buildItems, Coins = buildCoins }

function Shop.build(parent: Instance)
	-- Flat (no CanvasGroup): the shine streaks keep moving, and a CanvasGroup would redraw the whole Shop for each.
	local window = Kit.window({ Name = "Shop", Flat = true, Title = "SHOP", Icon = "ShopCart", Width = W, Height = H, TitleX = 63, TitleOffsetY = 3, TitleWidth = 101, StudsTo = 352, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(357, 6), Width = 121, Parent = header })
	local gems = Kit.pill({ Name = "Aura", Icon = "AuraStar", Position = UDim2.fromOffset(493, 6), Width = 108, Parent = header })
	local gemIcon = gems.Instance:FindFirstChild("Icon")
	if gemIcon and gemIcon:IsA("ImageLabel") then gemIcon.ImageColor3 = Color3.new(1, 1, 1) end -- (the owner's Aura star, as drawn)
	Kit.studs(header, 612, 650, 16)

	local body = new("ScrollingFrame", { Name = "Products", Position = UDim2.fromOffset(BODY_X, BODY_Y), Size = UDim2.fromOffset(BODY_W + 6, H - BODY_Y - 10), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
	-- The cards' rims are drawn outside the cards, and a ScrollingFrame clips square: give them room on every side.
	Kit.attach(Kit.pad(RIM, RIM, RIM, RIM), body)

	-- the cards in reading order (top to bottom, left to right), for the slide-in
	local function cards()
		local list = {}
		for _, ch in body:GetChildren() do if ch:IsA("GuiObject") then table.insert(list, ch) end end
		table.sort(list, function(a, b) return a.Position.Y.Offset * 10000 + a.Position.X.Offset < b.Position.Y.Offset * 10000 + b.Position.X.Offset end)
		return list
	end
	local tabs
	local function show(key: string)
		refreshButtons = {}
		for _, ch in body:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		body.CanvasPosition = Vector2.zero
		if key == "Coins" then -- the coin cards follow reference 08's own margins
			body.Position, body.Size = UDim2.fromOffset(COIN_BODY.X - RIM, COIN_BODY.Y - RIM), UDim2.fromOffset(W - 2 * COIN_BODY.X + 2 * RIM, COIN_BODY.H + 2 * RIM)
		else
			body.Position, body.Size = UDim2.fromOffset(BODY_X - RIM, BODY_Y - RIM), UDim2.fromOffset(BODY_W + 6 + 2 * RIM, H - BODY_Y - 10 + 2 * RIM)
		end
		BUILD[key](body)
		Motion.stagger(cards())
	end
	tabs = Kit.tabs(panel, {
		{ Key = "Passes", Text = "PASSES", X = 16, Width = 150 },
		{ Key = "Cosmetics", Text = "COSMETICS", X = 170, Width = 170 },
		{ Key = "Items", Text = "ITEMS", X = 344, Width = 170 }, -- the coin shop
		{ Key = "Coins", Text = "COINS", X = 518, Width = 169 },
	}, 52, 30, show) -- y 52: the tab row's top in references 01, 07 and 08 (51 window-relative, plus its 1 px rim)

	local function openTab(key: string)
		if tabs.selected() ~= key then tabs.select(key); show(key) end
	end
	coins.plus.onClick(function() openTab("Coins") end)
	gems.plus.onClick(function() Toast.show("Get Aura from the stars on the field, by winning games and from quests.") end)

	State.changed(function(data)
		coins.setAmount(Format.commas(data.Coins))
		gems.setAmount(Format.commas(data.Aura or 0))
		for _, f in refreshButtons do f() end
	end)
	coins.setAmount(Format.commas(State.data.Coins))
	gems.setAmount(Format.commas(State.data.Aura or 0))

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
		items = cards,
	})
	tabs.select("Passes")
	show("Passes")
	return window
end

return Shop
