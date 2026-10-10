-- The Store window (brief 22: a 1:1 copy of the user's references ref22_store_limited / _packs / _boosts and user_28,
-- measured at their own size): a yellow-orange studded header with the basket, "Store" in Gotham Black and a red-pink
-- X, over the see-through body with one scrolling list of every Robux item in Config/Products, in this order:
--   ~Shoe Boxes~   one card a Robux box (the reference's egg card): its name, the box art, its shoes over rarity splats
--                  with their chances, Buy 8 | Buy 3 | Buy 1 with the one-by-one price struck through
--   ~Gamepass~     big cards two to a row (user_28), VIP as the wide banner card
--   ~Boosts~       the wide rainbow Boost Bundle, then potion half cards
--   ~Cash Packs~ / ~Power Packs~   orange pack cards two to a row (Tiny .. Large)
-- A tap on a price prompts Roblox's purchase only when the item is live (Products.canBuy: the master switch, an id
-- and Wired); otherwise a "Coming soon!" notice pops over the list. Nothing errors with every id still 0. With an
-- id the card asks Roblox for the live price. A pass you own shows "Owned" (the Pass_<Key> attribute StoreService
-- sets). The HUD opens it through the BindableEvent HoodStore.Open (optionally with a section id or catalog key
-- to scroll to); PlayerGui's HoodWindow attribute keeps one window open at a time.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Products = require(Shared.Config.Products)
local Balance = require(Shared.Config.Balance)

local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and type(result) == 'table' and result or nil
end
local RebirthRules = optional('RebirthRules')
-- (brief 22) Roblox's player list (top right, under the topbar) would sit over the window's X: hidden while the Store is
-- open, through UI4's shared switch so the inventory, World and HUD windows agree (UIKit.HidePlayerList: hidden for good)
local InventoryKit = optional('InventoryKit')
local function coverPlayerList(on)
	if InventoryKit and type(InventoryKit.coverPlayerList) == 'function' then InventoryKit.coverPlayerList('Store', on) end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, short, hex = Kit.Color, Kit.short, Kit.hex
local BLACK = Color.black
local px = UDim2.fromOffset
local iconOr = Kit.iconOr -- (the first id IconModels knows: an uploaded PNG or a flat stand-in row)

local NAME = 'Store'
local gui, root, fit = Kit.screen('HoodStore', nil, 8)
local openEvent = Instance.new('BindableEvent')
openEvent.Name = 'Open'
openEvent.Parent = gui

---------------------------------------------------------------------------------------------- data
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
-- The Power your next rebirth needs (the server's attribute, else the shared rule): power packs are sized from it.
local function rebirthNeed()
	local v = num('RebirthNeed', nil)
	if v and v > 0 then return v end
	local n = num('Rebirths', 0)
	if RebirthRules and type(RebirthRules.need) == 'function' then
		local ok, r = pcall(RebirthRules.need, n)
		if ok and type(r) == 'number' then return r end
	end
	return math.floor((Balance.RebirthBase or 2500) * (Balance.RebirthRequirementGrowth or 2.3) ^ n + 0.5)
end
local function owns(entry) return entry.Kind == 'Pass' and player:GetAttribute('Pass_' .. entry.Key) == true end

-- Outlined display text: a black stroke ~12% of the size, like every label of the reference.
local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	return Kit.text(props)
end
-- (brief 19) The reference's big card lines ("Golden / Zone") are a pale cream gold with a dark brown outline.
local CARD_INK = hex('2B1D02')
local function gold(t)
	-- (brief 19 r7, UICRITIC P2-7: the reference's fill is ~#FCE47A, more saturated than cream)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex('FFF6B0')), ColorSequenceKeypoint.new(0.55, hex('FDE27A')), ColorSequenceKeypoint.new(1, hex('F8CF4A')) }), Parent = t })
	local st = t:FindFirstChildOfClass('UIStroke')
	if st then st.Color = CARD_INK end
	return t
end

---------------------------------------------------------------------------------------------- window
-- The reference window, measured: 1040 x 672 with a 120 px header; the list fills the body's inside (1004 x 522).
local W, H = 1040, 672
-- (r7, UICRITIC P3-5: user_28's header is 7 design px taller than the Rebirth window's, over the same body)
local panel, well, closeHit, overlay = Kit.window(root, { Name = NAME, Title = 'Store', Icon = iconOr('BasketRed', 'Shop'), Tone = 'headerGold', Width = W, Height = H, TitleSize = 84, HeaderHeight = 131, HeaderOverlap = 7 })
overlay.Visible = false
local isOpen = false
local function close()
	if not isOpen then return end
	isOpen = false
	coverPlayerList(false)
	Motion.blur(NAME, false)
	Motion.close(overlay, panel)
	if playerGui:GetAttribute('HoodWindow') == NAME then playerGui:SetAttribute('HoodWindow', '') end
end
local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
backdrop.Activated:Connect(close)
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
Motion.button(closeHit.Parent, close)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= NAME then close() end
end)

local list = Kit.new('ScrollingFrame', {
	Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 24,
	ScrollBarThickness = 10, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = well,
})
Kit.new('UIListLayout', { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 18), Parent = list })

-- "Coming soon!" and friends: a big outlined line across the middle of the list for a moment.
local noticeHolder = Kit.new('Frame', { Name = 'Notice', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(900, 60), ZIndex = 40, Parent = well })
local NOTICE = { green = hex('7CFF4F'), red = hex('FF4B4B'), blue = hex('5AE0FF') }
local noticeCount = 0
local function notice(text, tone)
	noticeCount += 1
	local mine = noticeCount
	for _, c in noticeHolder:GetChildren() do c:Destroy() end
	-- (r7, UICRITIC P3-16) on the video's fading dark band, so it reads over the cards
	local b = Kit.new('Frame', { Name = 'Box', BackgroundColor3 = hex('0E1020'), BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 41, Parent = noticeHolder })
	Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0), NumberSequenceKeypoint.new(0.82, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = b })
	label({ Name = 'Text', Text = text, TextSize = Kit.fitSize(text, 44, 880, 20), StrokeThickness = 5.5, TextColor3 = NOTICE[tone or 'blue'] or NOTICE.blue, Size = UDim2.fromScale(1, 1), ZIndex = 45, Parent = b })
	Motion.toast(b, 2.4)
	task.delay(2.9, function() if mine == noticeCount then for _, c in noticeHolder:GetChildren() do c:Destroy() end end end)
end

local function buy(key)
	local entry = Products.ByKey[key]
	if not entry then return end
	if owns(entry) then
		notice('You own ' .. entry.Title .. '!', 'green')
		return
	end
	if not Products.canBuy(key) then
		notice(entry.Title .. ' is coming soon!', 'blue')
		return
	end
	local id = Products.idOf(key)
	local ok = pcall(function()
		if entry.Kind == 'Pass' then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if not ok then notice('The Store is busy, try again!', 'red') end
end

---------------------------------------------------------------------------------------------- art
-- (brief 24: "the UI shouldn't look 3D") What a card shows (Products' Art), always a flat PNG (Kit.icon3d: ART2's upload,
-- or its flat 2D stand-in while that can't draw; never a live model): 'icon:<id>' an icon, 'gun:<id>' Gun_<id>,
-- 'box:<id>' Box_<id>, 'boxes:<id>' three Box_<id> stacked, 'shoe:<id>' Shoe_<id>.
local function artFor(entry, size, z)
	local w0 = typeof(size) == 'Vector2' and size.X or size
	local kind, id = (entry.Art or ''):match('^(%w+):(.+)$')
	if kind == 'gun' then return Kit.icon3d('Gun_' .. id, w0, { ZIndex = z }) end
	if kind == 'box' then return Kit.icon3d('Box_' .. id, w0, { ZIndex = z }) end
	if kind == 'shoe' then return Kit.icon3d('Shoe_' .. id, w0, { ZIndex = z }) end
	if kind == 'boxes' then
		-- three boxes in a little pyramid, one picture each
		local holder = Kit.new('Frame', { Name = 'Boxes_' .. id, BackgroundTransparency = 1, Size = px(w0, w0), ZIndex = z })
		for i, at in { { 0.5, 0.34 }, { 0.3, 0.66 }, { 0.7, 0.66 } } do
			-- (the top one first and lowest, the two in front over it)
			local b = Kit.icon3d('Box_' .. id, math.floor(w0 * 0.56), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at[1], at[2]), ZIndex = z + (i == 1 and 0 or 5) })
			b.Parent = holder
		end
		return holder
	end
	local icon = kind == 'icon' and id or 'Shop'
	if icon == 'Power' then icon = iconOr('Muscle', 'Power') end
	return Kit.icon3d(icon, w0, { ZIndex = z })
end

-- Price buttons, live prices and owned passes.
local priceLabels = {} -- [key] = { label, ... }
local function priceButton(parent, entry, w, h, pos, anchor, z)
	if owns(entry) then
		local chip = Kit.block({ Name = 'Owned', Tone = 'lime', Width = w, Height = h, Studs = false, Outline = 4, RimWidth = 3, Position = pos, AnchorPoint = anchor, ZIndex = z })
		label({ Name = 'Text', Text = 'Owned', TextSize = math.floor(h * 0.62), Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = chip.Body })
		chip.Parent = parent
		return chip
	end
	local holder, _, l = Kit.robuxButton({ Name = 'Buy', Price = entry.Price, Width = w, Height = h, Position = pos, AnchorPoint = anchor, Outline = 4, RimWidth = 3, ZIndex = z })
	holder.Parent = parent
	priceLabels[entry.Key] = priceLabels[entry.Key] or {}
	table.insert(priceLabels[entry.Key], l)
	Motion.button(holder, function() buy(entry.Key) end)
	return holder
end
local livePrices = {}
local function fetchPrices()
	for _, entry in Products.Catalog do
		local id = Products.idOf(entry.Key)
		if id ~= 0 and livePrices[entry.Key] == nil then
			livePrices[entry.Key] = false
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, entry.Kind == 'Pass' and Enum.InfoType.GamePass or Enum.InfoType.Product)
				end)
				local price = ok and type(info) == 'table' and info.PriceInRobux
				if type(price) == 'number' then
					livePrices[entry.Key] = price
					for _, l in priceLabels[entry.Key] or {} do
						if l.Parent then l.Text = tostring(price) end
					end
				end
			end)
		end
	end
end

---------------------------------------------------------------------------------------------- cards
local INNER = 1004 -- the list's width (the body's inside)
-- (brief 19 r7) The cards' faint checker studs, always (as frames before the upload: one Frame a stud, built only when the
-- Store first opens).
local CARD_STUDS = 30
local MARGIN, GAP = 21, 13 -- the cards' side margin and the gap between them
-- A section title like "~Gamepass~": the thin dark rule along the top of the body, then the title in italic Gotham
-- Black, centred.
local function sectionTitle(text, order, first)
	-- (brief 22: ref22's titles sit straight on the body, no rule, 40 px italic)
	local f = Kit.new('Frame', { Name = 'Title_' .. text, BackgroundTransparency = 1, Size = px(INNER, first and 50 or 56), LayoutOrder = order, ZIndex = 24 })
	label({ Name = 'Text', Text = text, TextSize = 38, StrokeThickness = 4.5, FontFace = Kit.Font.italic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, 0, 0, 46), ZIndex = 25, Parent = f })
	return f
end

-- A big gamepass card (the reference's "10x Power / Golden Zone"): the name, two big gold lines, the green Robux
-- button on the left; the art large on the right, poking over the top edge.
local BIG_W, BIG_H, BIG_GAP = 475, 290, 22
local ART_PASS = 240 -- (brief 24) every gamepass card's art, one size
-- A pass's Sticker on its art: big outlined gold text, tilted, like the reference's "x8" over its pets.
local function sticker(parent, entry, pos, z)
	if type(entry.Sticker) ~= 'string' or entry.Sticker == '' then return nil end
	local size = Kit.fitSize(entry.Sticker, 58, 150, 28)
	local t = gold(label({ Name = 'Sticker', Text = entry.Sticker, TextSize = size, StrokeThickness = math.max(4, size * 0.13), AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = px(170, size + 10), Rotation = -10, ZIndex = z, Parent = parent }))
	local st = t:FindFirstChildOfClass('UIStroke')
	if st then st.Color = BLACK end
	return t
end
local function bigCard(entry, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = BIG_W, Height = BIG_H, Position = px(x, y), Outline = 5, RimWidth = 7, Studs = CARD_STUDS, StudSparse = true, StudTransparency = 0.8, StudShade = 0.6, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	-- (brief 19: the reference's art is huge, the card's height, poking ~25 px over its top edge; brief 24: every pass's
	-- art at one size, ART_PASS, and its Sticker ('2x', 'x100') stuck on it: ART2's card art carries no text)
	local art = artFor(entry, ART_PASS, z)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0, 352, 0, -22)
	art.Parent = card.Body
	sticker(card.Body, entry, px(352 + ART_PASS * 0.3, ART_PASS * 0.72 - 22), z + 6)
	-- (r7, UICRITIC P2-7: the reference's title is white with a thin olive-brown edge, lighter than the gold lines)
	label({ Name = 'Title', Text = entry.Title, TextSize = Kit.fitSize(entry.Title, 42, 270, 16), Stroke = hex('5A4600'), StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(32, 39), Size = px(300, 48), ZIndex = z + 1, Parent = card.Body })
	local lines = string.split(entry.Big or '', '\n')
	for i, text in lines do
		gold(label({ Name = 'Big' .. i, Text = text, TextSize = Kit.fitSize(text, 52, 250, 20), StrokeThickness = 5.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(26, 102 + (i - 1) * 61), Size = px(270, 62), ZIndex = z + 1, Parent = card.Body }))
	end
	priceButton(card.Body, entry, 179, 67, px(29, 195), Vector2.zero, z)
	return card
end

-- The wide banner card (VIP, the reference's HACKER ZONE): the art on the left, the huge black name with a light
-- glow edge, the line under it and the price on the right.
local BANNER_H = 210
local function bannerCard(entry, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = INNER - 2 * MARGIN, Height = BANNER_H, Position = px(MARGIN, y), Outline = 5, RimWidth = 7, Studs = CARD_STUDS, StudSparse = true, StudTransparency = 0.8, StudShade = 0.6, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local art = artFor(entry, ART_PASS, z)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 14, 0.5, -20)
	art.Parent = card.Body
	sticker(card.Body, entry, px(14 + ART_PASS * 0.8, BANNER_H * 0.5 - 20 + ART_PASS * 0.22), z + 6)
	local tone = Kit.toneOf(entry.Tone)
	label({ Name = 'Big', Text = entry.Big or entry.Title, TextSize = 96, TextColor3 = hex('0A0A0A'), Stroke = tone.glow or tone.rim or Color.white, StrokeThickness = 6, TextXAlignment = Enum.TextXAlignment.Left, Position = px(270, 8), Size = px(420, 106), ZIndex = z + 1, Parent = card.Body })
	local detail = gold(label({ Name = 'Detail', Text = entry.Detail or '', TextSize = 40, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(272, 112), Size = px(440, 50), ZIndex = z + 1, Parent = card.Body }))
	detail.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 40, Parent = detail })
	priceButton(card.Body, entry, 200, 72, UDim2.new(1, -28, 0.5, 0), Vector2.new(1, 0.5), z)
	return card
end

---------------------------------------------------------------------------------------------- brief 22 cards
local sections = {} -- [section id or key] = the Frame to scroll to
-- Measured on the user's ref22_store_* pictures (the same 1.485 ref px a design px as user_28; positions from each card's
-- top-left). Every card: the Store's studded block family, a black outline, checker studs.
local Shoes = optional('Config', 'Shoes')
local CARD_W = INNER - 2 * MARGIN -- 962: the reference's egg card and Boost Bundle (961)
local function toneFor(entry, fallback)
	local t = entry.Tone
	if entry.Section == 'Box' then return t == 'cardPurple' and 'storeMagenta' or 'storeBlue' end
	return Kit.Tone[t] and t or fallback
end
-- A struck-through Robux price (ref22: red "⏣1432" with a red line across): the honest one-by-one price.
local function strikePrice(parent, value, size, pos, anchor, z)
	local text = tostring(value)
	local glyph = math.floor(size * 1.05)
	local tw = Kit.textWidth(text, size)
	local row = Kit.new('Frame', { Name = 'Was', BackgroundTransparency = 1, AnchorPoint = anchor, Position = pos, Size = px(glyph + 2 + tw, size + 6), ZIndex = z, Parent = parent })
	Kit.robux(glyph, { Color = hex('FF2A2A'), Inner = hex('C80A0A'), Core = hex('5A0000'), Edge = hex('5A0000'), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = z }).Parent = row
	label({ Name = 'Price', Text = text, TextSize = size, TextColor3 = hex('FF2A2A'), Stroke = hex('5A0000'), StrokeThickness = math.max(2, size * 0.12), TextXAlignment = Enum.TextXAlignment.Left, Position = px(glyph + 2, 0), Size = px(tw, size + 6), ZIndex = z, Parent = row })
	local line = Kit.new('Frame', { Name = 'Strike', BackgroundColor3 = hex('E81010'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, 6, 0, math.max(3, size * 0.1)), Rotation = -14, ZIndex = z + 1, Parent = row })
	Kit.stroke(hex('5A0000'), 1.5, true, 0, Enum.LineJoinMode.Miter).Parent = line
	return row
end
-- A shoe's art (ART2's Shoe_<id> PNG or its flat stand-in), a box's art (Box_<id>).
local function shoeArt(id, size, z) return Kit.icon3d('Shoe_' .. id, size, { ZIndex = z, Bare = true }) end -- (on its splat)
local function boxArt(id, size, z) return Kit.icon3d('Box_' .. id, size, { ZIndex = z }) end

-- ~Shoe Boxes~ (ref22_store_limited's egg card, 962 x 354): the name huge at the top-left, the box art large at the
-- bottom-left, its shoes over rarity splats with their drop chance (the rarest last and biggest), and one green Robux
-- button per bundle (Buy 8 | Buy 3 | Buy 1) with the honest one-by-one price struck through over the bundles.
local BOX_H = 348
-- A rarity splat that would vanish into the card (the Rare blue on the blue Exclusive card) is drawn a shade deeper,
-- like the reference's deep-blue splat on its blue card.
local function splatColor(c, base)
	local d = math.abs(c.R - base.R) + math.abs(c.G - base.G) + math.abs(c.B - base.B)
	if d >= 0.5 then return c end
	-- (UICRITIC2 r1 #2: about 15% darker and more saturated, e.g. #0A6CFF-ish on the blue card)
	local h, sat, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, sat * 1.3 + 0.05), v * 0.85)
end
local function boxCard(rows, y, parent)
	local first = rows[1]
	local boxId = first.Box or (first.Art or ''):match('^box:(.+)$') or ''
	local box = Shoes and Shoes.BoxById and Shoes.BoxById[boxId]
	local card = Kit.block({ Name = 'Box_' .. boxId, Tone = toneFor(first), Width = CARD_W, Height = BOX_H, Position = px(MARGIN, y), Outline = 6, RimWidth = 6, Studs = CARD_STUDS, StudSparse = true, StudShade = 0.75, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local magenta = toneFor(first) == 'storeMagenta'
	local title = label({ Name = 'Title', Text = (box and box.Name) or first.Title, TextSize = 70, StrokeThickness = 6, TextXAlignment = Enum.TextXAlignment.Left, Position = px(26, -2), Size = px(640, 86), ZIndex = z + 4, Parent = card.Body })
	if magenta then gold(title) end -- (the reference's 2nd card title is gold)
	-- (UICRITIC2 r1 #1: the ref's egg is ~330 px wide, runs off the card's left edge and ~7 px past its bottom, and the
	-- first pet overlaps it; ICONS' box PNGs keep ~14% clear on the left and ~2% below. The list clips 21 px out from
	-- the card, so the art pokes out ~7 px, clear of that edge.)
	-- (brief 24: ART2's chunky box fills 0.879 of its square, so at 316 px it shows whole, its lid clear of the title)
	local art = boxArt(boxId, 316, z)
	art.AnchorPoint = Vector2.new(0, 1)
	art.Position = UDim2.new(0, -34, 1, 14)
	art.Parent = card.Body
	-- the shoes, rarest last and biggest (ref: ~120 px pets at 140 px steps over their splats, the 1% one ~168 px;
	-- ICONS' shoe PNGs fill ~90% of their square)
	if box and type(box.Shoes) == 'table' then
		local n = #box.Shoes
		local Rarity = Shoes.RarityById or {}
		for i, sid in box.Shoes do
			local last = i == n
			local size = last and 186 or 130 -- (ICONS' round-2 shoes fill ~88% of their square)
			local cx = last and 858 or (690 - (n - 1 - i) * 140)
			local cy = last and 136 or 140
			local shoe = Shoes.ById and Shoes.ById[sid]
			local rarity = shoe and Rarity[shoe.Rarity]
			local secret = shoe and shoe.Rank == #(Shoes.Rarities or {})
			-- (ref22: the splat shows 15-25% beyond the pet on every side; ICONS' shoes fill ~96% of their square, the splat
			-- ~79% of its own: UICRITIC2 r2 #1)
			local splat = Kit.splat(size * (last and 1.3 or 1.45), splatColor(rarity and rarity.Color or Color.white, Kit.toneOf(toneFor(first)).base), { Kind = secret and 'rainbow' or nil, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy - 4), Rotation = (i * 37) % 360, ZIndex = z }) -- (centred on the shoe: UICRITIC2 r4)
			splat.Parent = card.Body
			local a = shoeArt(sid, size, z + 1)
			a.AnchorPoint = Vector2.new(0.5, 0.5)
			a.Position = px(cx, cy - 4)
			a.Parent = card.Body
			local chance = type(box.Chances) == 'table' and box.Chances[i]
			if chance then
				local t = (chance >= 1 and string.format('%d', math.floor(chance + 0.5)) or string.format('%.1f', chance)) .. '%'
				label({ Name = 'Chance' .. i, Text = t, TextSize = last and 50 or 31, StrokeThickness = last and 5 or 3.5, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = px(math.min(cx + size * 0.5 + 6, CARD_W - 20), last and 190 or 194), Size = px(130, 40), ZIndex = z + 3, Parent = card.Body }) -- (r2 #4: clear of the struck prices)
			end
		end
	end
	-- the buttons: the biggest bundle first (left), like the reference's Buy 8 | Buy 3 | Buy 1
	table.sort(rows, function(a, b) return (a.Count or 1) > (b.Count or 1) end)
	local single
	for _, r in rows do if (r.Count or 1) == 1 then single = r end end
	local BW, BH, BY = 190, 81, 238
	for i, r in rows do
		local x = CARD_W - 10 - 35 - (#rows - i + 1) * BW - (#rows - i) * 15
		priceButton(card.Body, r, BW, BH, px(x, BY), Vector2.zero, z + 2)
		local buyText = gold(label({ Name = 'Buy' .. (r.Count or 1), Text = 'Buy ' .. (r.Count or 1), TextSize = 30, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x + BW / 2, BY + BH + 4), Size = px(BW, 36), ZIndex = z + 6, Parent = card.Body }))
		buyText.Name = 'Buy' .. (r.Count or 1)
		local was = r.WasPrice or (single and (r.Count or 1) > 1 and (r.Count or 1) * single.Price) or nil
		if was then strikePrice(card.Body, was, 32, px(x + BW - 6, BY - 8), Vector2.new(1, 0.5), z + 7) end
		sections[r.Key] = card
	end
	return card
end

-- ~Boosts~ (ref22_store_boosts): the wide rainbow Boost Bundle (962 x 270: the potion burst left, the name in two huge
-- lines, its parts as "- 2 x2 Power Boosts" lines, the struck one-by-one price and the green button), then half cards
-- (474 x 300: a big potion bottom-left, the name top-right, the button bottom-right).
local BUNDLE_H, HALF_W, HALF_H = 270, math.floor((CARD_W - 13) / 2), 300
local function bundleLines(entry)
	-- (UICRITIC2 r1 #4: the ref's bullets are short, "- 2 Win Boosts") built from the parts: "- 2x Power, 30 min"
	local seconds = tonumber(Products.BoostDurationSeconds) or 900
	if type(entry.Bundle) == 'table' and #entry.Bundle > 0 then
		local counts, order = {}, {}
		for _, key in entry.Bundle do
			if not counts[key] then table.insert(order, key) end
			counts[key] = (counts[key] or 0) + 1
		end
		local lines = {}
		for _, key in order do
			local part = Products.ByKey[key]
			table.insert(lines, '- ' .. ((part and part.Title) or key) .. ', ' .. math.floor(counts[key] * seconds / 60 + 0.5) .. ' min')
		end
		return lines
	end
	if type(entry.Lines) == 'table' then return entry.Lines end
	local counts, order = {}, {}
	for _, key in entry.Bundle or {} do
		if not counts[key] then table.insert(order, key) end
		counts[key] = (counts[key] or 0) + 1
	end
	local lines = {}
	for _, key in order do
		local part = Products.ByKey[key]
		local name = part and part.Title or key
		table.insert(lines, '- ' .. counts[key] .. ' ' .. name .. (counts[key] > 1 and ' Boosts' or ' Boost'))
	end
	return lines
end
local function bundleCard(entry, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = 'bundleRainbow', Width = CARD_W, Height = BUNDLE_H, Position = px(MARGIN, y), Outline = 5, RimWidth = 5, Studs = CARD_STUDS, StudSparse = true, StudShade = 0.7, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	-- (UICRITIC2 r2 #3: the ref's potion fills the card's height left of the title and runs ~10 px over its top-left)
	local art = Kit.icon3d(iconOr('BoostBundle', 'PotionRed', 'Evolve'), 266, { ZIndex = z })
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = px(112, 124)
	art.Rotation = -12
	art.Parent = card.Body
	label({ Name = 'Title', Text = 'Boost\nBundle', TextSize = 68, StrokeThickness = 6, TextXAlignment = Enum.TextXAlignment.Left, Position = px(140, -20), Size = px(330, 170), ZIndex = z + 2, Parent = card.Body }).LineHeight = 0.92
	for i, line in bundleLines(entry) do
		local l = label({ Name = 'Line' .. i, Text = line, TextSize = 35, StrokeThickness = 3.5, FontFace = Kit.Font.body, TextXAlignment = Enum.TextXAlignment.Left, Position = px(476, 14 + (i - 1) * 60), Size = px(450, 46), ZIndex = z + 2, Parent = card.Body })
		l.TextSize = Kit.fitSize(line, 35, 450, 18)
	end
	if entry.WasPrice then strikePrice(card.Body, entry.WasPrice, 46, px(476, 196), Vector2.new(0, 0.5), z + 3) end
	priceButton(card.Body, entry, 248, 79, px(683, 158), Vector2.zero, z + 2)
	return card
end
local POTION = { [2] = 'PotionRed', [3] = 'PotionGold' }
local function halfCard(entry, x, y, parent)
	local level = entry.Boost or tonumber((entry.Title or ''):match('(%d)x')) or 2
	local tone = level >= 3 and 'potionGold' or entry.Key == 'BlockParty' and 'storeMagenta' or 'potionRed'
	local card = Kit.block({ Name = entry.Key, Tone = tone, Width = HALF_W, Height = HALF_H, Position = px(x, y), Outline = 5, RimWidth = 5, Studs = CARD_STUDS, StudSparse = true, StudShade = 0.7, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local artId = (entry.Art or ''):match('^icon:(.+)$')
	-- (ref22_store_boosts: the potion's cork ~34 px under the card's top, its liquid star showing above the bottom;
	-- UICRITIC2 r2 #2: 0.8x of round 1)
	local art = Kit.icon3d(iconOr(artId or '', POTION[level] or 'PotionRed', entry.Key == 'BlockParty' and 'Rewards' or 'Evolve'), 232, { ZIndex = z })
	art.Position = px(7, 16) -- (UICRITIC2 r3: ~10 px higher, so the liquid band shows like the ref's)
	art.Parent = card.Body
	local t = label({ Name = 'Title', Text = entry.Title, TextSize = 50, StrokeThickness = 4.5, FontFace = Kit.Font.body, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = px(HALF_W - 40, 72), ZIndex = z + 2, Parent = card.Body })
	t.TextSize = Kit.fitSize(entry.Title, 66, 250, 24) -- (UICRITIC2 r1 #5: fitted to the free width right of the potion, like the ref's "2x Win")
	priceButton(card.Body, entry, 190, 79, UDim2.new(1, -22, 1, -24), Vector2.new(1, 1), z + 2)
	return card
end

-- ~Cash Packs~ / ~Power Packs~ (ref22_store_packs, 452 x 277, two to a row): the gold-edged name, the pile art growing
-- with the pack, "+5K Cash" and the green button.
local PACK_W, PACK_H, PACK_GAP = 452, 277, 12
local packLabels = {} -- [key] = TextLabel (power packs change with your next rebirth)
local PILE = { 'Tiny', 'Small', 'Medium', 'Large' }
local function packAmount(entry)
	if entry.Section == 'Power' then return '+' .. short(Products.powerAmount(entry.Key, rebirthNeed())) .. ' Power' end
	return '+' .. short(Products.cashAmount(entry.Key)) .. ' Cash'
end
local function packCard(entry, i, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = 'packOrange', Width = PACK_W, Height = PACK_H, Position = px(x, y), Outline = 5, RimWidth = 5, Studs = CARD_STUDS, StudSparse = true, StudShade = 0.7, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local title = entry.Title
	if not (title or ''):find('Pack') then title = (PILE[i] or 'Big') .. ' Pack' end
	gold(label({ Name = 'Title', Text = title, TextSize = Kit.fitSize(title, 52, PACK_W - 50, 24), StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(30, 14), Size = px(PACK_W - 40, 62), ZIndex = z + 2, Parent = card.Body }))
	local pile = (entry.Section == 'Power' and 'Power' or 'Cash') .. (PILE[i] or 'Large')
	local artId = (entry.Art or ''):match('^icon:(.+)$')
	-- (ref22_store_packs: every pile at the left, fuller pack by pack; brief 24: one picture size for every pack, the
	-- pile itself grows in ART2's art)
	local art = Kit.icon3d(iconOr(pile, artId or '', entry.Section == 'Power' and 'Muscle' or 'Cash'), 206, { ZIndex = z })
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = px(112, 168)
	art.Parent = card.Body
	local amount = label({ Name = 'Amount', Text = packAmount(entry), TextSize = 37, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(318, 128), Size = px(240, 46), ZIndex = z + 2, Parent = card.Body })
	amount.TextSize = Kit.fitSize(amount.Text, 37, 236, 18)
	if entry.Section == 'Power' then packLabels[entry.Key] = amount end
	priceButton(card.Body, entry, 187, 77, px(240, 174), Vector2.zero, z + 2)
	return card
end

local built = false
local function build()
	built = true
	table.clear(priceLabels)
	table.clear(packLabels)
	for _, child in list:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	local order = 0
	for s, section in Products.Sections do
		local items = {}
		for _, entry in Products.Catalog do
			-- (brief 22, lead) only what can really be bought: a row shows once its effect is Wired
			if entry.Section == section.Id and entry.Wired == true then table.insert(items, entry) end
		end
		if #items == 0 then continue end
		order += 1
		local title = sectionTitle(section.Title, order, s == 1)
		title.Parent = list
		sections[section.Id] = title
		order += 1
		local block = Kit.new('Frame', { Name = section.Id, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 24, Parent = list })
		local y = section.Id == 'Gamepass' and 12 or 4 -- (room for the gamepass art poking over the first row; ref22's cards sit closer)
		if section.Id == 'Gamepass' then
			local col = 0
			for _, entry in items do
				if entry.Banner then
					if col == 1 then y += BIG_H + BIG_GAP; col = 0 end
					sections[entry.Key] = bannerCard(entry, y - 7, block) -- (r7, UICRITIC P3-6: the reference's banner sits 7 px closer)
					y += BANNER_H + BIG_GAP - 7
				else
					sections[entry.Key] = bigCard(entry, MARGIN + col * (BIG_W + GAP), y, block)
					col += 1
					if col == 2 then col = 0; y += BIG_H + BIG_GAP end
				end
			end
			if col == 1 then y += BIG_H + BIG_GAP end
		elseif section.Id == 'Box' then
			-- one card a box, its bundles as buttons, in catalog order
			local byBox, boxes = {}, {}
			for _, entry in items do
				local id = entry.Box or (entry.Art or ''):match('^box:(.+)$') or entry.Key
				if not byBox[id] then byBox[id] = {}; table.insert(boxes, id) end
				table.insert(byBox[id], entry)
			end
			for _, id in boxes do
				sections[id] = boxCard(byBox[id], y, block)
				y += BOX_H + 13
			end
			y += 9
		elseif section.Id == 'Boost' then
			local col = 0
			for _, entry in items do
				if entry.Wide or entry.Bundle then
					if col == 1 then y += HALF_H + 13; col = 0 end
					sections[entry.Key] = bundleCard(entry, y, block)
					y += BUNDLE_H + 13
				else
					local x = MARGIN + col * (HALF_W + 13)
					sections[entry.Key] = halfCard(entry, x, y, block)
					col += 1
					if col == 2 then col = 0; y += HALF_H + 13 end
				end
			end
			if col == 1 then y += HALF_H + 13 end
			y += 9
		else
			-- Cash / Power packs: two to a row, centred; a short last row centred too
			local x0 = (INNER - (2 * PACK_W + PACK_GAP)) / 2
			for i, entry in items do
				local col = (i - 1) % 2
				local alone = col == 0 and i == #items
				local x = alone and (INNER - PACK_W) / 2 or x0 + col * (PACK_W + PACK_GAP)
				sections[entry.Key] = packCard(entry, i, x, y, block)
				if col == 1 or i == #items then y += PACK_H + PACK_GAP end
			end
			y += 9
		end
		block.Size = px(INNER, y)
	end
	fetchPrices()
end
local function paintPacks()
	for key, l in packLabels do
		if l.Parent then l.Text = '+' .. short(Products.powerAmount(key, rebirthNeed())) .. ' Power' end
	end
end
for _, key in { 'RebirthNeed', 'Rebirths' } do
	player:GetAttributeChangedSignal(key):Connect(function() if isOpen then paintPacks() end end)
end
-- A pass bought (or found owned) while the Store exists: rebuild so its card says Owned.
for _, entry in Products.Catalog do
	if entry.Kind == 'Pass' then
		player:GetAttributeChangedSignal('Pass_' .. entry.Key):Connect(function() built = false; if isOpen then build() end end)
	end
end

local function scrollTo(at)
	local target = at and sections[at]
	if not target then
		list.CanvasPosition = Vector2.zero
		return
	end
	task.defer(function()
		local y = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 8
		list.CanvasPosition = Vector2.new(0, math.max(0, y))
	end)
end
local function open(at)
	if isOpen then
		scrollTo(at)
		return
	end
	isOpen = true
	coverPlayerList(true)
	playerGui:SetAttribute('HoodWindow', NAME)
	if not built then build() end
	paintPacks()
	Motion.blur(NAME, true)
	Motion.open(overlay, panel, 1)
	scrollTo(at)
end
openEvent.Event:Connect(open)

---------------------------------------------------------------------------------------------- layout
-- The reference's 1040 x 672 window keeps its size where it fits and shrinks onto smaller screens (Kit.fitWindow).
-- (brief 22, UICRITIC2 r1 #6) Phones: the whole safe screen, the topbar row included (like UI4's windows), so the
-- window grows from ~59% to ~71% of the width; it sits 12 dp from the safe right edge so its header clears Roblox's
-- top-left buttons. Phone = the camera's short side <= 500 (not the GUI's, which changes with the insets).
local fitter = panel.Parent
local function shortSide(abs)
	local ok, vs = pcall(function() return workspace.CurrentCamera.ViewportSize end)
	if ok and typeof(vs) == 'Vector2' and vs.X > 1 and vs.Y > 1 then return math.min(vs.X, vs.Y) end
	return math.min(abs.X, abs.Y)
end
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	local phone = shortSide(abs) <= 500
	local insets = phone and Enum.ScreenInsets.DeviceSafeInsets or Enum.ScreenInsets.CoreUISafeInsets
	if gui.ScreenInsets ~= insets then
		gui.ScreenInsets = insets
		abs = gui.AbsoluteSize -- (Roblox may update it a frame later; its change runs relayout again)
	end
	fit(abs)
	Kit.fitWindow(panel, abs)
	if phone then
		fitter.AnchorPoint = Vector2.new(1, 0.5)
		fitter.Position = UDim2.new(1, -12 / Kit.scaleFor(abs), 0.5, 0)
	else
		fitter.AnchorPoint = Vector2.new(0.5, 0.5)
		fitter.Position = UDim2.new(0.5, 0, 0.5, 4)
	end
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
