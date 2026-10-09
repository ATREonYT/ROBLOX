-- The Store window (brief 18: a 1:1 copy of the user's reference user_28, measured at its own size): a yellow-orange
-- studded header with the basket, "Store" in Gotham Black and a red-pink X, over the grey see-through body with one
-- scrolling list of every Robux item in Config/Products:
--   ~Gamepass~     big cards two to a row (475 x 290: the name, two big gold lines, the green Robux button, the art
--                  large on the right poking over the top edge), with VIP as the wide banner card (the reference's
--                  HACKER ZONE)
--   ~Power Packs~  ~Cash~  ~Boosts~   smaller cards three to a row in the same style
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
local GunModels = optional('Models', 'GunModels')
local BoxModels = optional('Models', 'BoxModels')
local ShoeModels = optional('Models', 'ShoeModels')
local IconModels = optional('Models', 'IconModels')
local RebirthRules = optional('RebirthRules')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, short, hex = Kit.Color, Kit.short, Kit.hex
local BLACK = Color.black
local px = UDim2.fromOffset
local iconOr = Kit.iconOr -- (the first id IconModels can show: an uploaded render or a live model)

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
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex('FFFBDC')), ColorSequenceKeypoint.new(0.6, hex('FFF2A8')), ColorSequenceKeypoint.new(1, hex('FFE27A')) }), Parent = t })
	local st = t:FindFirstChildOfClass('UIStroke')
	if st then st.Color = CARD_INK end
	return t
end

---------------------------------------------------------------------------------------------- window
-- The reference window, measured: 1040 x 672 with a 120 px header; the list fills the body's inside (1004 x 522).
local W, H = 1040, 672
local panel, well, closeHit, overlay = Kit.window(root, { Name = NAME, Title = 'Store', Icon = iconOr('BasketRed', 'Shop'), Tone = 'headerGold', Width = W, Height = H, TitleSize = 84 })
overlay.Visible = false
local isOpen = false
local function close()
	if not isOpen then return end
	isOpen = false
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
	local b = Kit.new('Frame', { Name = 'Box', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 41, Parent = noticeHolder })
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
-- What a card shows (Products' Art): a 3D icon, a gun, a shoe box, three boxes or a pair of shoes, as live models
-- in ViewportFrames (the offline previewer draws the matching renders from PreviewImage).
local function modelView(model, size, view, attr, z)
	local vp = Kit.viewport(model, size, { Direction = view, Yaw = 25, Pitch = 18, ZIndex = z })
	vp:SetAttribute('PreviewImage', attr)
	return vp
end
-- (brief 19) ICONS' offer-card renders, used once uploaded (the live models stay the fallback)
local CARD_ART = { DoubleRep = 'DoublePower', DoubleCash = 'DoubleCash', VIP = 'VIP', AutoShoot = 'AutoFight' }
local function artFor(entry, size, z)
	local w0 = typeof(size) == 'Vector2' and size.X or size
	local art = CARD_ART[entry.Key]
	if art and Kit.iconImage(art) ~= '' then return Kit.icon3d(art, w0, { ZIndex = z }) end
	local kind, id = entry.Art:match('^(%w+):(.+)$')
	local ok, node = pcall(function()
		if kind == 'gun' and GunModels then
			return modelView(GunModels.build(id, 1), size, typeof(GunModels.View) == 'Vector3' and GunModels.View or nil, 'gun:' .. id, z)
		elseif kind == 'box' and BoxModels then
			return modelView(BoxModels.build(id, 1), size, Vector3.new(-0.45, 0.42, -0.79).Unit, 'box:' .. id, z)
		elseif kind == 'boxes' and BoxModels then
			-- three boxes in a little pyramid
			local m = Instance.new('Model')
			for i, at in { CFrame.new(-2.5, 0, 0), CFrame.new(2.5, 0, 0), CFrame.new(0, 3.2, 0.4) } do
				local b = BoxModels.build(id, 1, at)
				b.Name = 'Box' .. i
				b.Parent = m
			end
			return modelView(m, size, Vector3.new(-0.3, 0.35, -0.89).Unit, 'boxes:' .. id, z)
		elseif kind == 'shoe' and ShoeModels then
			return modelView(ShoeModels.pair(id, 1), size, typeof(ShoeModels.View) == 'Vector3' and ShoeModels.View or nil, 'shoe:' .. id, z)
		end
		return nil
	end)
	if ok and node then return node end
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
-- (brief 19) The cards' faint studs only as a texture: as frames they were ~1.8K instances for 16 cards.
local CARD_STUDS = Kit.studsAreCheap() and 30 or false
local MARGIN, GAP = 21, 13 -- the cards' side margin and the gap between them
-- A section title like "~Gamepass~": the thin dark rule along the top of the body, then the title in italic Gotham
-- Black, centred.
local function sectionTitle(text, order, first)
	local f = Kit.new('Frame', { Name = 'Title_' .. text, BackgroundTransparency = 1, Size = px(INNER, first and 62 or 58), LayoutOrder = order, ZIndex = 24 })
	if first then
		Kit.new('Frame', { Name = 'Line', BackgroundColor3 = BLACK, BackgroundTransparency = 0.15, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(1, -40, 0, 2), ZIndex = 24, Parent = f })
	end
	label({ Name = 'Text', Text = text, TextSize = 36, StrokeThickness = 4.5, FontFace = Kit.Font.italic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -25), Size = UDim2.new(1, 0, 0, 44), ZIndex = 25, Parent = f })
	return f
end

-- A big gamepass card (the reference's "10x Power / Golden Zone"): the name, two big gold lines, the green Robux
-- button on the left; the art large on the right, poking over the top edge.
local BIG_W, BIG_H, BIG_GAP = 475, 290, 22
local function bigCard(entry, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = BIG_W, Height = BIG_H, Position = px(x, y), Outline = 5, RimWidth = 7, Studs = CARD_STUDS, StudTransparency = 0.8, StudShade = 0.45, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	-- (brief 19: the reference's art is huge, the card's height, poking ~25 px over its top edge)
	local art = artFor(entry, 258, z)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0, 352, 0, -30)
	art.Parent = card.Body
	label({ Name = 'Title', Text = entry.Title, TextSize = Kit.fitSize(entry.Title, 42, 270, 16), StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(32, 39), Size = px(300, 48), ZIndex = z + 1, Parent = card.Body })
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
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = INNER - 2 * MARGIN, Height = BANNER_H, Position = px(MARGIN, y), Outline = 5, RimWidth = 7, Studs = CARD_STUDS, StudTransparency = 0.8, StudShade = 0.45, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local art = artFor(entry, 220, z)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 22, 0.5, -26)
	art.Parent = card.Body
	local tone = Kit.toneOf(entry.Tone)
	label({ Name = 'Big', Text = entry.Big or entry.Title, TextSize = 96, TextColor3 = hex('0A0A0A'), Stroke = tone.glow or tone.rim or Color.white, StrokeThickness = 6, TextXAlignment = Enum.TextXAlignment.Left, Position = px(270, 8), Size = px(420, 106), ZIndex = z + 1, Parent = card.Body })
	local detail = gold(label({ Name = 'Detail', Text = entry.Detail or '', TextSize = 40, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(272, 112), Size = px(440, 50), ZIndex = z + 1, Parent = card.Body }))
	detail.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 40, Parent = detail })
	priceButton(card.Body, entry, 200, 72, UDim2.new(1, -28, 0.5, 0), Vector2.new(1, 0.5), z)
	return card
end

-- A small card (packs and boosts), three to a row: the art over the top, the amount or name, a detail line and the
-- price.
local SMALL_W, SMALL_H, SMALL_GAP = math.floor((INNER - 2 * MARGIN - 2 * GAP) / 3), 236, 26
local packLabels = {} -- [key] = TextLabel (power packs change with your next rebirth)
local function smallTitle(entry)
	if entry.Section == 'Power' then return '+' .. short(Products.powerAmount(entry.Key, rebirthNeed())) .. ' Power' end
	if entry.Section == 'Cash' then return '+' .. short(Products.cashAmount(entry.Key)) .. ' Cash' end
	return entry.Title
end
local function smallCard(entry, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = SMALL_W, Height = SMALL_H, Position = px(x, y), Outline = 5, RimWidth = 6, Studs = CARD_STUDS, StudTransparency = 0.8, StudShade = 0.45, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local art = artFor(entry, 116, z)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, -18)
	art.Parent = card.Body
	local title = label({ Name = 'Title', Text = smallTitle(entry), TextSize = 38, StrokeThickness = 5, Position = px(10, 96), Size = UDim2.new(1, -20, 0, 44), ZIndex = z + 1, Parent = card.Body })
	title.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 38, MinTextSize = 14, Parent = title })
	if entry.Section == 'Power' then packLabels[entry.Key] = title end
	local detail = entry.Detail or (entry.Section ~= 'Boost' and entry.Title) or ''
	local d = gold(label({ Name = 'Detail', Text = detail, TextSize = 24, StrokeThickness = 3.5, Position = px(10, 138), Size = UDim2.new(1, -20, 0, 28), ZIndex = z + 1, Parent = card.Body }))
	d.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 24, MinTextSize = 11, Parent = d })
	priceButton(card.Body, entry, 179, 56, UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1), z)
	return card
end

local sections = {} -- [section id or key] = the Frame to scroll to
local built = false
local function build()
	built = true
	table.clear(priceLabels)
	for _, child in list:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	local order = 0
	for s, section in Products.Sections do
		local items = {}
		for _, entry in Products.Catalog do
			if entry.Section == section.Id then table.insert(items, entry) end
		end
		if #items == 0 then continue end
		order += 1
		local title = sectionTitle(section.Title, order, s == 1)
		title.Parent = list
		sections[section.Id] = title
		order += 1
		local block = Kit.new('Frame', { Name = section.Id, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 24, Parent = list })
		local y = 12 -- (room for the art poking over the first row)
		if section.Id == 'Gamepass' then
			local col = 0
			for _, entry in items do
				if entry.Banner then
					if col == 1 then y += BIG_H + BIG_GAP; col = 0 end
					sections[entry.Key] = bannerCard(entry, y, block)
					y += BANNER_H + BIG_GAP
				else
					sections[entry.Key] = bigCard(entry, MARGIN + col * (BIG_W + GAP), y, block)
					col += 1
					if col == 2 then col = 0; y += BIG_H + BIG_GAP end
				end
			end
			if col == 1 then y += BIG_H + BIG_GAP end
		else
			for i, entry in items do
				local col = (i - 1) % 3
				sections[entry.Key] = smallCard(entry, MARGIN + col * (SMALL_W + GAP), y, block)
				if col == 2 or i == #items then y += SMALL_H + SMALL_GAP end
			end
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
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	Kit.fitWindow(panel, abs)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
