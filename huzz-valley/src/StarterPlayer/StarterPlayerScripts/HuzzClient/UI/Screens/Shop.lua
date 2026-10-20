-- Shop (design/pages/01, 07; ITEMS and COINS after the owner's Oct 17 mockup): Passes / Cosmetics / Items / Crates / Coins
-- tabs over one stationary window. PASSES opens on the 5 knife Game Pass cards (owner, Oct 18: "please add the knifes
-- into the ui for the gamepass menu, these are going to be the gamepasses users can buy"; his mockup
-- design/knives/Five_Elemental_Knife_Cards.png), with the VIP and Dance Pack banners under them.
-- Buy buttons only open Roblox's purchase prompt; the server grants (ShopService). Each button shows exactly one
-- state: Robux badge + price, "..." (prompt open) or OWNED (a cosmetic you own: WEAR / WEARING, tap to switch). Items that aren't on sale yet show their price like the
-- reference but only say "coming soon" when tapped; they never open a purchase.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local RoundConfig = require(Shared.Config.Round)
local Format = require(Shared.Format)
local KnifeLook = require(Shared.KnifeLook)
local Crates = require(Shared.Config.Crates)
local CrateRoll = require(Shared.CrateRoll)
local UI = script.Parent.Parent
local CrateArt = require(UI.CrateArt)
local Crate3D = require(UI.Crate3D)
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
	if State.owns(p.Key) and p.Slot then -- a cosmetic you own: put it on or take it off here
		if CoinShop.worn(State.data, p.Slot) == p.Key then return "WEARING", "Selected", nil, false end
		return "WEAR", "Tab", nil, false
	end
	if State.owns(p.Key) then return "OWNED", "Disabled", "CheckEquipped", false end
	if pending[p.Key] then return "...", "Disabled", nil, false end
	return Format.commas(priceOf(p)), "Action", nil, true
end

local refreshButtons: { () -> () } = {}

local function buy(p)
	if State.owns(p.Key) and p.Slot then
		local worn = CoinShop.worn(State.data, p.Slot) == p.Key
		local ok, why = State.action("Wear", p.Slot, if worn then nil else p.Key)
		if not ok then Toast.show(why or "Couldn't change that.") end
		return
	end
	if State.owns(p.Key) or pending[p.Key] then return end
	local status = Products.status(p)
	if status == "Soon" then
		Toast.show(p.Name .. " is coming soon.") -- shown with its price, but never sold until it gives something
		return
	elseif status == "NoId" then
		Toast.show(p.Name .. " is coming soon.") -- (no ID yet: never a purchase prompt)
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
		if priced and props.Label then text = props.Label end -- (the knife cards say BUY, like his mockup)
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

-- The knife Game Pass cards, one-to-one with his mockup (Five_Elemental_Knife_Cards.png, 2113 px: cards 403 x 715,
-- 17 px apart), scaled by 0.2993 so a whole card fits the window's body (120 x 214): a dark purple panel with a thin
-- lighter rim, the knife art with its element glow (his own art, cut by tools/icons/cut_pass_knife_cards.py), the
-- name fading from white to the element's colour with a soft glow, KNIFE under it, and a violet BUY with the Robux mark.
-- Colours measured on the mockup (Config/Products Card). BUY opens Roblox's prompt only once the pass has its ID.
local KNIFE_CARD = { W = 120, H = 214, Gap = 6, Art = Vector2.new(118, 147), NameY = 149, NameH = 16, SubY = 165,
	ButtonX = 5, ButtonY = 178, ButtonW = 110, ButtonH = 31 }
local function buildKnifeCards(body: Frame): number
	local K = KNIFE_CARD
	local passes = Products.knifePasses()
	local x0 = math.floor((BODY_W - (#passes * K.W + (#passes - 1) * K.Gap)) / 2)
	for i, p in passes do
		local look = p.Card
		local c = new("Frame", { Name = p.Key, Position = UDim2.fromOffset(x0 + (i - 1) * (K.W + K.Gap), 1), Size = UDim2.fromOffset(K.W, K.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body }, { Kit.corner(5), Kit.stroke(look.Rim, 1) })
		new("UIGradient", { Rotation = 90, Parent = c, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, look.Top), ColorSequenceKeypoint.new(0.69, look.Top), ColorSequenceKeypoint.new(1, look.Bottom),
		}) })
		Kit.attach(Kit.corner(4), Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(K.Art.X, K.Art.Y), Parent = c }))
		local title = Kit.name({ Name = "Name", Text = p.Name, FontFace = Theme.Fonts.Heading, TextSize = 15, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, K.NameY), Size = UDim2.fromOffset(K.W - 8, K.NameH), ZIndex = 2, Parent = c })
		Kit.fitLine(title, K.W - 10, 15, 10, true)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), look.Name), Parent = title })
		new("UIStroke", { Name = "Glow", Color = look.Glow, Thickness = 1.5, Transparency = 0.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = title }) -- (the mockup's soft glow round the name)
		Kit.text({ Name = "Kind", Text = "KNIFE", FontFace = Theme.Fonts.Button, TextSize = 9, TextColor3 = look.Sub, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(0, K.SubY), Size = UDim2.fromOffset(K.W, 10), Parent = c })
		buyButton(c, p, { Position = UDim2.fromOffset(K.ButtonX, K.ButtonY), Size = UDim2.fromOffset(K.ButtonW, K.ButtonH), TextSize = 16, BadgeScale = 1.4, IconSize = 16, Style = "PassViolet", Corner = 4, Label = "BUY" })
		Effects.shine(c, { every = 5, delay = (i - 1) * 0.7, corner = 5, strength = 0.22, z = 5 })
		-- alive (owner, Oct 19: "better knife animations ... in the gamepass sections"): its element's colour glowing
		-- softly over the knife, a few of its petals / sparks / embers / ice bits floating up, a small lift under the mouse
		local el = KnifeLook.element(p.Knife)
		if el then
			local shape = if el.name == "Petals" or el.name == "Feathers" then "petal" elseif el.name == "Frost" then "diamond" else "dot"
			Effects.pulse(c, { colour = el.light, position = UDim2.fromOffset(1, 1), size = UDim2.fromOffset(K.Art.X, K.Art.Y), corner = 4, z = 2 })
			Effects.motes(c, { colour = el.emit[1].colours[1], shape = shape, count = 7,
				area = Rect.new(8, 20, K.Art.X - 6, K.Art.Y - 4), z = 3, seed = i })
		end
		Effects.lift(c)
	end
	return if #passes > 0 then 1 + K.H + 12 else 0
end

-- Passes: broad rows, after the owner's pass banners (design/shop/pass-banners.png): deep see-through navy with a
-- glowing rim in the pass's colour, the banner's character picture at the left, a big title with a soft colour
-- fade and a short line under it, the blurb tinted, and the price button in the same colour.
local function buildPasses(body: Frame)
	local y = buildKnifeCards(body)
	local banners = {}
	for _, p in Products.Passes do
		if not p.Knife then table.insert(banners, p) end
	end
	for i, p in banners do
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
		Kit.fitLine(title, 140, if #p.Name > 6 then 20 else 27, 15, true) -- (DANCE PACK still ran 2 px over at 20)
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
		Kit.fitLine(Kit.name({ Name = "Name", Text = p.Name, TextSize = 17, Position = UDim2.fromOffset(170, 6), Size = UDim2.fromOffset(cw - 178, 22), Parent = c }), cw - 178, 17, 12, true)
		Kit.text({ Name = "Blurb", Text = p.Blurb, TextSize = 14, LineHeight = 0.9, Position = UDim2.fromOffset(170, 31), Size = UDim2.fromOffset(cw - 178, 28), TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		buyButton(c, p, { Position = UDim2.new(0, 170, 1, -8), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(cw - 178, 30), TextSize = 19, IconSize = 22 })
	end
end

-- COINS: 3 tall cards after the owner's Oct 17 mockup (design/ui-oct17, bottom left), measured there and scaled to
-- the window (x 0.759): the title on top, the big picture (coin pile, bag, chest: Config/Products Art, cut from the
-- mockup as placeholders) filling the card down to the price button. The prices are Robux, so the button keeps the
-- Robux mark (the mockup's coin icon would tell kids they cost coins). Our header and tabs are the ITEMS tab's (7 px
-- lower than the mockup's), so the cards start under them and use the room down to the window's bottom edge.
local COIN_BODY = { X = 15, Y = 88, H = H - 88 - 8 } -- (window px; the cards and their rims sit inside this)
local COIN = { X = { 21, 246, 472 }, Y = 4, W = 212, H = 216, ArtH = 162, ButtonX = 10, ButtonY = 163, ButtonH = 44,
	Fill = Color3.fromHex("10143F"), FillBottom = Color3.fromHex("121644"), Rim = Color3.fromHex("5250AA"), Glow = Color3.fromHex("1A1114") }

-- The picture, top corners rounded to the card's inner radius and bottom corners square: one rounded copy, and a
-- square copy clipped to everything below the corners (ClipsDescendants clips square, so no background shows).
local function coinArt(parent: Instance, p, w: number, h: number)
	local r = 5
	local panel = new("Frame", { Name = "Art", Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = parent })
	Kit.attach(Kit.corner(r), Kit.art(p.Art, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = panel }))
	local lower = new("Frame", { Name = "Lower", Position = UDim2.fromOffset(0, r), Size = UDim2.new(1, 0, 1, -r), BackgroundTransparency = 1, ClipsDescendants = true, Parent = panel })
	Kit.art(p.Art, { Name = "Picture", Position = UDim2.fromOffset(0, -r), Size = UDim2.fromOffset(w, h), Parent = lower })
	return panel
end

local function buildCoins(body: Frame)
	for i, p in Products.Coins do
		local c = new("Frame", { Name = p.Key, Position = UDim2.fromOffset(COIN.X[i] - COIN_BODY.X, COIN.Y), Size = UDim2.fromOffset(COIN.W, COIN.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body }, { Kit.corner(6), Kit.stroke(COIN.Rim, 2) })
		-- navy card; its dark warm top matches the picture's own glow, so the rounded corners never show a seam
		new("UIGradient", { Rotation = 90, Parent = c, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, COIN.Glow), ColorSequenceKeypoint.new(0.7, COIN.Glow),
			ColorSequenceKeypoint.new(0.76, COIN.Fill), ColorSequenceKeypoint.new(1, COIN.FillBottom),
		}) })
		coinArt(c, p, COIN.W, COIN.ArtH)
		Effects.shine(c, { every = 5, delay = (i - 1) * 0.9, corner = 6, strength = 0.28, z = 5 })
		-- the mockup's titles are heavy, with a dark outline over the glow
		local title = Kit.name({ Name = "Name", Text = p.Name, FontFace = Theme.Fonts.Heading, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 9), Size = UDim2.new(1, 0, 0, 26), ZIndex = 2, Parent = c })
		new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = title })
		buyButton(c, p, { Position = UDim2.fromOffset(COIN.ButtonX, COIN.ButtonY), Size = UDim2.fromOffset(COIN.W - 2 * COIN.ButtonX, COIN.ButtonH), TextSize = 23, BadgeScale = 1.55, Style = "ItemBuy", Corner = 6 })
	end
end

-- ITEMS: the coin shop (Config/CoinShop; owner: "make the coins usable"). Looks only: trails, name colours, knife
-- skins and the girls' rewards. Picture cards after the owner's Oct 17 mockup (design/ui-oct17): four to a row, the
-- name and slot on top, a big picture (Config/CoinShop Art; drawn here for items without one), and one button: the
-- coin price (buy and wear it), WEAR (owned), or WEARING (tap to take it off). The server decides.
local ITEM = { W = 161, H = 170, Gap = 8, ArtY = 39, ArtH = 89, KnifeArtH = 124, Swatch = 64, Fill = Color3.fromHex("0B1C3E"), FillBottom = Color3.fromHex("0A1537"), Rim = Color3.fromHex("2B4E8C"), Slot = Color3.fromHex("AEB4F0") }
local rarityColor = {}
for _, r in RoundConfig.Rarities do rarityColor[r.Name] = r.Color end
rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (near-black in the roller; violet reads on the dark window)
rarityColor.Exclusive = Color3.fromRGB(255, 170, 230) -- the Game Pass knives, once owned (as in the admin panel; knife check, Oct 19: their card had no rarity colour)
local function swatch(parent: Instance, item: CoinShop.Item)
	local f = new("Frame", { Name = "Swatch", Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(ITEM.Swatch, ITEM.Swatch), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = parent }, { Kit.corner(8) })
	if item.Slot == "Trail" then
		-- a streak fading out behind a runner: the colours along it, solid at the front
		local streak = new("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, 22), Rotation = -20, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f }, { Kit.corner(11) })
		new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }), Parent = streak })
	elseif item.Slot == "Aura" then
		-- a glowing ring with a bright core: the aura's colours round it
		local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, Parent = f }, { Kit.corner(23) })
		new("UIStroke", { Name = "Glow", Color = Color3.new(1, 1, 1), Thickness = 5, Parent = ring }, {
			new("UIGradient", { Name = "Colours", Rotation = 45, Color = CoinShop.sequence(item) }),
		})
		local core = new("Frame", { Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f }, { Kit.corner(10) })
		new("UIGradient", { Name = "Colours", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), item.Colors[1]), Parent = core })
	elseif item.Slot == "Title" then
		-- the title itself, small, in its colours (as it shows over your name)
		local word = Kit.text({ Name = "Word", Text = string.upper(item.Name), FontFace = Theme.Fonts.Heading, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = item.Colors[1], Position = UDim2.fromOffset(4, 16), Size = UDim2.new(1, -8, 0, 32), Parent = f })
		new("UIStroke", { Name = "Outline", Color = C.Frame, Thickness = 1.5, Parent = word })
		if #item.Colors > 2 then
			word.TextColor3 = Color3.new(1, 1, 1)
			new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Parent = word })
		end
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
		local col, rowN = (i - 1) % 4, (i - 1) // 4
		local c = new("Frame", { Name = item.Key, Position = UDim2.fromOffset(-2 + col * (ITEM.W + ITEM.Gap), rowN * (ITEM.H + ITEM.Gap)), Size = UDim2.fromOffset(ITEM.W, ITEM.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body }, { Kit.corner(6), Kit.stroke(ITEM.Rim, 2) })
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(ITEM.Fill, ITEM.FillBottom), Parent = c })
		local tint = item.Rarity and rarityColor[item.Rarity]
		if tint then -- the girls' rewards: a rim in the rarity's colour, so they stand out
			local rim = c:FindFirstChildOfClass("UIStroke")
			if rim then rim.Color, rim.Thickness = tint, 2 end
		end
		local knifeArt = item.Slot == "Knife" and item.Art ~= nil -- (the owner's knives: the picture fills the card)
		if (tint or not item.Art) and not knifeArt then -- a soft glow from the top in the item's colour (pictures carry their own glow)
			new("Frame", { Name = "Glow", Size = UDim2.new(1, 0, 0.75, 0), BackgroundColor3 = tint or item.Colors[1], BackgroundTransparency = if tint then 0.8 else 0.86, BorderSizePixel = 0, ZIndex = 0, Parent = c }, {
				Kit.corner(6), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
			})
		end
		if knifeArt then
			-- the owner's knife (a render of his model, tools/knives/compose_cards.py) behind the name and rarity, like
			-- his mock-up (design/knives/knifepictures-mockup.png); the square picture is cropped a little top and bottom
			Kit.attach(Kit.corner(5), Kit.art(item.Art :: string, { Name = "Picture", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(ITEM.W - 4, ITEM.KnifeArtH), Parent = c }))
		elseif item.Art then
			Kit.art(item.Art, { Name = "Picture", Position = UDim2.fromOffset(2, ITEM.ArtY), Size = UDim2.fromOffset(ITEM.W - 4, ITEM.ArtH), Parent = c })
		elseif item.Slot == "Title" then
			-- the title itself, big, in its colours (as it shows over your name)
			local word = Kit.text({ Name = "Word", Text = string.upper(item.Name), FontFace = Theme.Fonts.Heading, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = item.Colors[1], Position = UDim2.fromOffset(12, ITEM.ArtY + 14), Size = UDim2.fromOffset(ITEM.W - 24, ITEM.ArtH - 28), Parent = c })
			new("UIStroke", { Name = "Outline", Color = C.Frame, Thickness = 2, Parent = word })
			if #item.Colors > 2 then
				word.TextColor3 = Color3.new(1, 1, 1)
				new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Parent = word })
			end
		else
			-- no picture yet (knives): the drawn swatch, bigger, in the middle of the picture area
			local holder = new("Frame", { Name = "Drawn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, ITEM.ArtY + 45), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Parent = c })
			local sw = swatch(holder, item)
			sw.Position, sw.Size, sw.BackgroundTransparency = UDim2.new(), UDim2.fromScale(1, 1), 1
			new("UIScale", { Scale = 1.6, Parent = sw:FindFirstChild("Knife") or sw })
		end
		Kit.fitLine(Kit.name({ Name = "Name", Text = item.Name, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 7), Size = UDim2.fromOffset(ITEM.W - 8, 18), Parent = c }), ITEM.W - 8, 14, 10, true)
		local slotText = CoinShop.SlotNames[item.Slot]
		if item.Rarity then slotText = string.upper(item.Rarity) .. " · " .. slotText end
		Kit.fitLine(Kit.text({ Name = "Slot", Text = slotText, FontFace = Theme.Fonts.Label, TextSize = 11, TextColor3 = tint or ITEM.Slot, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 25), Size = UDim2.fromOffset(ITEM.W - 8, 12), TextWrapped = false, Parent = c }), ITEM.W - 8, 11, 8, true) -- (LEGENDARY · TITLE: the rarity must stay on the card)
		local b = Kit.button({ Name = "Buy", Text = "", Icon = "CurrencyCoin", IconSize = 26, Gap = 8, TextSize = 20, FontFace = Theme.Fonts.Number, Style = "ItemBuy", Corner = 5, Position = UDim2.fromOffset(7, ITEM.H - 42), Size = UDim2.fromOffset(ITEM.W - 14, 36), Parent = c })
		local icon = b.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local function refresh()
			local owned = State.data.Cosmetics[item.Key] == true
			local worn = CoinShop.worn(State.data, item.Slot) == item.Key
			if icon then icon.Visible = not owned and not item.Unlock end
			if not owned and item.Unlock then
				b.setText("EARN IT") -- (quest knives: never sold; the tap says where)
				b.setStyle("Disabled")
			elseif not owned then
				b.setText(Format.commas(item.Price))
				b.setStyle(if (State.data.Coins or 0) >= item.Price then "ItemBuy" else "Disabled")
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
				local worn = CoinShop.worn(State.data, item.Slot) == item.Key
				ok, why = State.action("Wear", item.Slot, if worn then nil else item.Key)
				if not ok then Toast.show(why or "Couldn't change that.") end
			end
		end)
		table.insert(refreshButtons, refresh)
		refresh()
	end
end

-- CRATES (owner: "create a good case opening animation"; his crate shop mockup, Oct 20, 03:48: "Here are the ui mock
-- ups", design/owner-oct20/0348-crate-shop-mockup.png). On top, his three knife crates as the mockup draws them: three
-- cards in a row (rounded navy panels with a lighter rim and a faint square pattern at the top), each with his own 3D
-- crate in a ViewportFrame (UI/Crate3D; as he built them: the Storm Vault and the Beast Chest open as on the mockup,
-- the Dojo Chest shut), sparkle diamonds round it and a wide violet BUY with the Robux mark under it (Config/Products.Crates:
-- Id 0 until the owner makes the products, so BUY only says "coming soon" and never opens a purchase). Not on the
-- mockup, kept small: OPEN with Aura (the price, the old way to open) and the pity line, and an "i" that scrolls to
-- the crate's odds (kid-safe: never hidden odds). Until his model is there (the harness, a slow join) the card draws
-- the plain crate (CrateArt).
-- Below the cards, each crate's every item with its exact chance; then the crates without a model (Starter, Dance)
-- as before: the crate card on the left (pity counter, OPEN with Aura), its odds beside it. OPEN goes to the opening
-- screen (Screens/CrateOpen), which asks the server; not in a round or a cutscene.
local CRATE = { W = 206, H = 212, OddsX = 216, RowW = 222, RowH = 29, RowGap = 1, ColGap = 8, SectionGap = 12 }
-- the mockup's card, scaled from 695 x 679 px to 214 px wide (its BUY: 19 px in, 553-670 px down: 6, 166-202 here)
local CARD = { X = 4, W = 214, H = 209, Gap = 8, Corner = 9, ViewH = 150, BuyX = 6, BuyY = 166, BuyH = 36, LineY = 145, LineH = 17,
	Fill = Color3.fromHex("1E2852"), Rim = Color3.fromHex("353F8C"), Buy = Color3.fromHex("6A5CF6"), BuyTop = Color3.fromHex("A79FFF"),
	BuyRim = Color3.fromHex("1C1562") }
-- the sparkle diamonds round each crate (the mockup's orange, cyan, yellow, pink and white): x, y, size, colour
local SPARKLES = {
	{ 0.14, 0.14, 11, "FF9A3C" }, { 0.84, 0.12, 12, "5FE3FF" }, { 0.08, 0.50, 8, "FFE15C" }, { 0.92, 0.42, 12, "FF6FC8" },
	{ 0.82, 0.66, 7, "FFFFFF" }, { 0.20, 0.70, 6, "FFFFFF" },
}

local function canOpenHere(): boolean
	local player = Players.LocalPlayer
	local role = player:GetAttribute("HuzzRole")
	if role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true or player:GetAttribute("HuzzCinematic") == true then
		Toast.show("Open crates in the lobby.")
		return false
	end
	return true
end

-- OPEN: a key (bought with Robux) first, else Aura
local function openCrate(crate)
	if not canOpenHere() then return end
	local keys = (State.data.CrateKeys or {})[crate.Id] or 0
	local have = State.data.Aura or 0
	if keys <= 0 and have < crate.Price then
		Toast.show(`You need {crate.Price - have} more Aura. Collect stars on the field!`)
		return
	end
	ModalManager.open("CrateOpen", crate.Id)
end

-- every item of a crate and its exact chance, rarest last, in `cols` columns of `rowW` px from (x, y) in `parent`
local function oddsRows(parent: Instance, crate, x: number, y: number, cols: number, rowW: number): number
	local odds = CrateRoll.odds(crate)
	local rows = math.ceil(#odds / cols)
	for i, o in odds do
		local col, r = (i - 1) // rows, (i - 1) % rows
		local it = o.item
		local row = new("Frame", { Name = "Odds" .. i, Position = UDim2.fromOffset(x + col * (rowW + CRATE.ColGap), y + r * (CRATE.RowH + CRATE.RowGap)), Size = UDim2.fromOffset(rowW, CRATE.RowH), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, Parent = parent }, { Kit.corner(5) })
		new("Frame", { Name = "RarityBar", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = CrateArt.color(it.Rarity), BorderSizePixel = 0, ZIndex = 2, Parent = row }, { Kit.corner(2) })
		CrateArt.picture(row, it, 40, 25, 4, UDim2.fromOffset(8, 2), 2)
		local nameW = rowW - 118
		local nm = Kit.name({ Name = "Name", Text = it.Name, FontFace = Theme.Fonts.Name, TextSize = 13, Position = UDim2.fromOffset(54, 1), Size = UDim2.fromOffset(nameW, 15), ZIndex = 3, Parent = row })
		Kit.fitLine(nm, nameW, 13, 10, true)
		local rr = Kit.text({ Name = "Rarity", Text = string.upper(it.Rarity), FontFace = Theme.Fonts.Heading, TextSize = 9, TextColor3 = CrateArt.color(it.Rarity), TextWrapped = false, Position = UDim2.fromOffset(54, 16), Size = UDim2.fromOffset(nameW, 11), ZIndex = 3, Parent = row })
		new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1, Parent = rr })
		Kit.text({ Name = "Chance", Text = string.format("%g%%", math.floor(o.chance * 10 + 0.5) / 10), FontFace = Theme.Fonts.Number, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Position = UDim2.fromOffset(rowW - 62, 0), Size = UDim2.fromOffset(54, CRATE.RowH), ZIndex = 3, Parent = row })
	end
	return rows * (CRATE.RowH + CRATE.RowGap) - CRATE.RowGap
end

-- the pity line: "LEGENDARY IN 40" (or "LEGENDARY NEXT!"), from the save
local function pityLine(crate): string
	local left = CrateRoll.left(crate, (State.data.Pity or {})[crate.Id] or 0)
	local top = string.upper(crate.Pity and crate.Pity.Rarity or "")
	if left == nil then return "" end
	return if left <= 1 then `{top} NEXT!` else `{top} IN {left}`
end

-- the BUY under each of his crates (Config/Products.Crates; while its Id is 0 it only says "coming soon")
local function buyKey(crate)
	local p = Products.crateKey(crate.Id)
	if not p then Toast.show("Coming soon.") return end
	if pending[p.Key] then return end
	local status = Products.status(p)
	if status ~= "Ready" then
		Toast.show(`{p.Name} for Robux is coming soon.`)
		if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
		return
	end
	pending[p.Key] = true
	local ok, why = State.action("PromptCrateKey", p.Key) -- (the server checks it again and opens Roblox's prompt)
	if not ok then
		pending[p.Key] = nil
		Toast.show(why or "The purchase couldn't open. Try again.")
		return
	end
	task.delay(90, function() pending[p.Key] = nil end) -- (never stuck if Roblox doesn't report back)
end

-- One of the mockup's cards for a crate with his model.
local function modelCard(body: Instance, crate, i: number, x: number, onOdds: () -> ())
	local card = new("Frame", { Name = "Card" .. crate.Id, Position = UDim2.fromOffset(x, 1), Size = UDim2.fromOffset(CARD.W, CARD.H), BackgroundColor3 = CARD.Fill, BorderSizePixel = 0, Parent = body }, { Kit.corner(CARD.Corner), Kit.stroke(CARD.Rim, 2) })
	-- the faint square pattern at the card's top, fading out by the middle
	local pattern = Kit.studPattern(card, 0.16)
	new("UIGradient", { Name = "Fade", Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.42, 0.75), NumberSequenceKeypoint.new(0.62, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = pattern })
	local stage = new("Frame", { Name = "Stage", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(CARD.W, CARD.ViewH), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
	for n, s in SPARKLES do
		local d = new("Frame", { Name = "Sparkle" .. n, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(s[1], 0, s[2], 0), Size = UDim2.fromOffset(s[3], s[3]), Rotation = 45, BackgroundColor3 = Color3.fromHex(s[4]), BorderSizePixel = 0, ZIndex = 2, Parent = stage }, { Kit.corner(1) })
		d:SetAttribute("Sparkle", true)
	end
	-- his crate, as he built it (the plain crate until his model is there)
	local view = Crate3D.new(stage, crate, "Card", { ZIndex = 3 }) -- (as he built it: the Storm Vault and Beast Chest open)
	if not view then
		CrateArt.paint(CrateArt.crate(stage, 108, UDim2.fromOffset(CARD.W // 2, 78), "CratePicture"), crate)
	end
	-- odds: the "i" in the top right corner scrolls down to every item's chance
	local info = Kit.button({ Name = "Odds", Text = "i", Style = "Slate", FontFace = Theme.Fonts.Heading, TextSize = 13, Corner = 9, Position = UDim2.fromOffset(CARD.W - 25, 7), Size = UDim2.fromOffset(18, 18), ZIndex = 5, Parent = card })
	info.onClick(onOdds)
	-- the slim line over BUY: OPEN with Aura (or a key), and the pity counter
	local open = Kit.button({ Name = "Open", Text = `OPEN {crate.Price}`, Icon = "AuraStar", IconAfter = true, IconSize = 13, Gap = 3, TextSize = 11, FontFace = Theme.Fonts.Heading, Style = "Selected", Corner = 5, Position = UDim2.fromOffset(CARD.BuyX, CARD.LineY), Size = UDim2.fromOffset(84, CARD.LineH), ZIndex = 5, Parent = card })
	open.onClick(function() openCrate(crate) end)
	local top = crate.Pity and crate.Pity.Rarity or ""
	local pity = Kit.text({ Name = "Pity", Text = "", FontFace = Theme.Fonts.Heading, TextSize = 10, TextColor3 = CrateArt.color(top), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Position = UDim2.fromOffset(CARD.BuyX + 88, CARD.LineY), Size = UDim2.fromOffset(CARD.W - 2 * CARD.BuyX - 88, CARD.LineH), ZIndex = 5, Parent = card })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.2, Parent = pity })
	-- the mockup's BUY: wide, rounded, violet, the Robux mark and a white bold BUY
	local buy = Kit.button({ Name = "Buy", Text = "BUY", Style = "CrateBuy", FontFace = Theme.Fonts.Heading, TextSize = 20, Gap = 6, Corner = 8, RimThickness = 2, Position = UDim2.fromOffset(CARD.BuyX, CARD.BuyY), Size = UDim2.fromOffset(CARD.W - 2 * CARD.BuyX, CARD.BuyH), ZIndex = 5, Parent = card })
	local content = buy.Instance:FindFirstChild("Content")
	if content then
		-- (the mockup's mark: big, in the dark navy of the price buttons' Robux mark)
		Kit.text({ Name = "RobuxMark", Text = Format.RobuxMark, FontFace = Theme.Fonts.Number, TextSize = 30, TextColor3 = C.RobuxBadge, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, ZIndex = 5, Parent = content })
	end
	local label = buy.Instance:FindFirstChild("Label", true)
	local outline = label and label:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then outline.Thickness, outline.Transparency = 1.5, 0 end
	buy.onClick(function() buyKey(crate) end)
	local function refresh()
		local keys = (State.data.CrateKeys or {})[crate.Id] or 0
		pity.Text = pityLine(crate)
		open.setText(if keys > 0 then `OPEN · {keys} KEY{if keys > 1 then "S" else ""}` else `OPEN {crate.Price}`)
		local icon = open.Instance:FindFirstChild("Icon", true)
		if icon then (icon :: GuiObject).Visible = keys <= 0 end
		open.setStyle(if keys > 0 or (State.data.Aura or 0) >= crate.Price then "Selected" else "Disabled")
	end
	table.insert(refreshButtons, refresh)
	refresh()
	return card
end

-- A crate without a model (the Starter and Dance crates): the plain crate card, the pity counter and OPEN, its odds
-- in two columns beside it.
local function plainSection(body: Instance, crate, y: number): number
	local rowsNeeded = math.ceil(#crate.Items / 2)
	local sectionH = math.max(CRATE.H, rowsNeeded * (CRATE.RowH + CRATE.RowGap) - CRATE.RowGap)
	local section = new("Frame", { Name = "Section" .. crate.Id, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CRATE.OddsX + 2 * CRATE.RowW + CRATE.ColGap, sectionH), BackgroundTransparency = 1, Parent = body })
	local c = new("Frame", { Name = crate.Id, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(CRATE.W, CRATE.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = section }, { Kit.corner(6), Kit.stroke(COIN.Rim, 2) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("1B1850"), COIN.FillBottom), Parent = c })
	Effects.rays(c, UDim2.fromOffset(CRATE.W // 2, 82), 160, { color = C.Accent, transparency = 0.7, seconds = 18, z = 1, name = "CrateRays" })
	CrateArt.paint(CrateArt.crate(c, 100, UDim2.fromOffset(CRATE.W // 2, 80), "CratePicture"), crate)
	Effects.shine(c, { every = 5, corner = 6, strength = 0.25, z = 9 })
	local title = Kit.name({ Name = "Name", Text = crate.Name, FontFace = Theme.Fonts.Heading, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 24), ZIndex = 3, Parent = c })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = title })
	local top = crate.Pity and crate.Pity.Rarity or ""
	local pityHead = Kit.text({ Name = "PityLabel", Text = `GUARANTEED {string.upper(top)}`, FontFace = Theme.Fonts.Heading, TextSize = 11, TextColor3 = CrateArt.color(top), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(0, 131), Size = UDim2.new(1, 0, 0, 13), ZIndex = 3, Parent = c })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.2, Parent = pityHead })
	local pityText = Kit.name({ Name = "Pity", Text = "", FontFace = Theme.Fonts.Name, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 16), ZIndex = 3, Parent = c })
	local track = new("Frame", { Name = "PityTrack", Position = UDim2.fromOffset(14, 162), Size = UDim2.fromOffset(CRATE.W - 28, 6), BackgroundColor3 = C.TrackRim, BorderSizePixel = 0, ZIndex = 3, Parent = c }, { Kit.corner(3) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = CrateArt.color(top), BorderSizePixel = 0, ZIndex = 3, Parent = track }, { Kit.corner(3) })
	local b = Kit.button({ Name = "Open", Text = `OPEN {crate.Price}`, Icon = "AuraStar", IconAfter = true, IconSize = 24, Gap = 6, TextSize = 21, FontFace = Theme.Fonts.Heading, Style = "Selected", Corner = 6, Position = UDim2.fromOffset(9, 172), Size = UDim2.fromOffset(CRATE.W - 18, 34), ZIndex = 4, Parent = c })
	local function refresh()
		local pity = (State.data.Pity or {})[crate.Id] or 0
		local left = CrateRoll.left(crate, pity)
		pityText.Text = if left == nil then "" elseif left <= 1 then "on your next open!" else `in {left} opens`
		fill.Size = UDim2.fromScale(if crate.Pity then math.clamp(pity / crate.Pity.After, 0, 1) else 0, 1)
		b.setStyle(if (State.data.Aura or 0) >= crate.Price then "Selected" else "Disabled")
	end
	b.onClick(function() openCrate(crate) end)
	table.insert(refreshButtons, refresh)
	refresh()
	oddsRows(section, crate, CRATE.OddsX, 0, 2, CRATE.RowW)
	return sectionH
end

local function buildCrates(body: Frame)
	local withModel, plain = {}, {}
	for _, crate in Crates.List do
		if crate.Home then continue end -- (sold on its own page: the Halloween stands' crates, Screens/HalloweenShop)
		table.insert(if crate.Model then withModel else plain, crate)
	end
	-- his crates' cards, then each one's odds (the "i" scrolls there)
	local y = 1
	local oddsAt: { [string]: number } = {}
	if #withModel > 0 then y = CARD.H + 1 + CRATE.SectionGap + 4 end
	local rowW = (#withModel > 0) and (CARD.W * 3 + CARD.Gap * 2 - 2 * CRATE.ColGap) // 3 or CRATE.RowW
	for _, crate in withModel do
		local section = new("Frame", { Name = "Section" .. crate.Id, Position = UDim2.fromOffset(CARD.X, y), Size = UDim2.fromOffset(CARD.W * 3 + CARD.Gap * 2, 22), BackgroundTransparency = 1, Parent = body })
		oddsAt[crate.Id] = y
		local head = Kit.name({ Name = "Name", Text = string.upper(crate.Name), FontFace = Theme.Fonts.Heading, TextSize = 15, Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(330, 20), Parent = section })
		new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = head })
		local top = crate.Pity and crate.Pity.Rarity or ""
		local pityHead = Kit.text({ Name = "PityLabel", Text = "", FontFace = Theme.Fonts.Heading, TextSize = 11, TextColor3 = CrateArt.color(top), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Position = UDim2.fromOffset(330, 3), Size = UDim2.fromOffset(CARD.W * 3 + CARD.Gap * 2 - 332, 16), Parent = section })
		new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.2, Parent = pityHead })
		local function refresh()
			local left = CrateRoll.left(crate, (State.data.Pity or {})[crate.Id] or 0)
			pityHead.Text = if left == nil then "" elseif left <= 1 then `GUARANTEED {string.upper(top)} ON YOUR NEXT OPEN` else `GUARANTEED {string.upper(top)} IN {left} OPENS`
		end
		table.insert(refreshButtons, refresh)
		refresh()
		local h = oddsRows(section, crate, 0, 24, 3, rowW)
		section.Size = UDim2.fromOffset(section.Size.X.Offset, 24 + h)
		y += 24 + h + CRATE.SectionGap
	end
	for i, crate in withModel do
		modelCard(body, crate, i, CARD.X + (i - 1) * (CARD.W + CARD.Gap), function()
			body.CanvasPosition = Vector2.new(0, math.max(0, (oddsAt[crate.Id] or 0) - 2))
		end)
	end
	for _, crate in plain do
		y += plainSection(body, crate, y) + CRATE.SectionGap
	end
end

local BUILD = { Passes = buildPasses, Cosmetics = buildCosmetics, Items = buildItems, Coins = buildCoins, Crates = buildCrates }

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
		if key == "Coins" then -- the coin cards follow the mockup's own margins
			body.Position, body.Size = UDim2.fromOffset(COIN_BODY.X - RIM, COIN_BODY.Y - RIM), UDim2.fromOffset(W - 2 * COIN_BODY.X + 2 * RIM, COIN_BODY.H + 2 * RIM)
		else
			body.Position, body.Size = UDim2.fromOffset(BODY_X - RIM, BODY_Y - RIM), UDim2.fromOffset(BODY_W + 6 + 2 * RIM, H - BODY_Y - 10 + 2 * RIM)
		end
		BUILD[key](body)
		Motion.stagger(cards())
	end
	tabs = Kit.tabs(panel, {
		{ Key = "Passes", Text = "PASSES", X = 16, Width = 131 },
		{ Key = "Cosmetics", Text = "COSMETICS", X = 151, Width = 131 },
		{ Key = "Items", Text = "ITEMS", X = 286, Width = 131 }, -- the coin shop
		{ Key = "Crates", Text = "CRATES", X = 421, Width = 131 }, -- opened with Aura (five tabs now: the kit had four)
		{ Key = "Coins", Text = "COINS", X = 556, Width = 131 },
	}, 52, 30, show) -- y 52: the tab row's top in references 01, 07 and 08 (51 window-relative, plus its 1 px rim)

	local function openTab(key: string)
		if tabs.selected() ~= key then tabs.select(key); show(key) end
	end
	coins.plus.onClick(function() openTab("Coins") end)
	gems.plus.onClick(function() Toast.show("Get Aura from the stars on the field, by winning games and from quests.") end)

	-- A reward you've just earned (Config/CoinShop Earn): say so once, and where to find it.
	local known: { [string]: boolean }? = nil
	State.changed(function(data)
		if data.Loaded then
			local first = known == nil
			known = known or {}
			local names = {}
			for _, item in CoinShop.Items do
				if item.Earn and data.Cosmetics[item.Key] and not (known :: any)[item.Key] then
					(known :: any)[item.Key] = true
					table.insert(names, item.Name)
				end
			end
			if not first and #names > 0 then
				local list = if #names == 1 then names[1] else table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
				Toast.show(`You unlocked {list}! Wear {if #names == 1 then "it" else "them"} from Shop > Items.`)
			end
		end
		coins.setAmount(Format.commas(State.shown("Coins")))
		gems.setAmount(Format.commas(data.Aura or 0))
		for _, f in refreshButtons do f() end
	end)
	coins.setAmount(Format.commas(State.shown("Coins")))
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
