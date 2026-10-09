-- The Store window (brief 17, like the user's reference user_28): an orange studded header with the Shop icon,
-- "Store" and a red X, over one scrolling list of every Robux item in Config/Products:
--   ~Gamepasses~   big cards in two columns (the art large on the right, the name, a big second line, a short
--                  detail and the green Robux button), with VIP as the wide banner card
--   ~Power Packs~  ~Cash~  ~Boosts~   smaller cards in three columns
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
local RebirthRules = optional('RebirthRules')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, Tone, short = Kit.Color, Kit.Tone, Kit.short
local px = UDim2.fromOffset

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

---------------------------------------------------------------------------------------------- window
local W, H = 900, 520
local panel, well, closeHit, overlay = Kit.window(root, { Name = NAME, Title = 'Store', Icon = 'Shop', Tone = 'orange', Width = W, Height = H })
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
	Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 24,
	ScrollBarThickness = 10, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = well,
})
Kit.new('UIListLayout', { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16), Parent = list })

-- "Coming soon!" and friends: a small studded notice over the top of the list for a moment.
local noticeHolder = Kit.new('Frame', { Name = 'Notice', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = px(520, 50), ZIndex = 40, Parent = well })
local noticeCount = 0
local function notice(text, tone)
	noticeCount += 1
	local mine = noticeCount
	for _, c in noticeHolder:GetChildren() do c:Destroy() end
	local width = math.clamp(Kit.textWidth(text, 24) + 40, 240, 600)
	local b = Kit.block({ Name = 'Box', Tone = tone or 'blue', Width = width, Height = 46, Studs = 16, Shadow = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 41 })
	Kit.text({ Name = 'Text', Text = text, TextSize = 24, Stroke = Color.ink, StrokeThickness = 3.5, Position = px(10, -1), Size = UDim2.new(1, -20, 1, 0), ZIndex = 45, Parent = b.Body })
	b.Parent = noticeHolder
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
local function artFor(entry, size, z)
	local kind, id = entry.Art:match('^(%w+):(.+)$')
	local w = typeof(size) == 'Vector2' and size.X or size
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
	return Kit.icon3d(kind == 'icon' and id or 'Shop', w, { ZIndex = z })
end
local function sticker(parent, entry, size, pos, z)
	if not entry.Sticker then return end
	local t = Kit.text({ Name = 'Sticker', Text = entry.Sticker, TextSize = size, Stroke = Color.ink, StrokeThickness = math.max(3, size * 0.14), AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = px(size * 2.2, size + 8), Rotation = -10, ZIndex = z, Parent = parent })
	Kit.gradient(Color.white, Kit.hex('FFE24A'), 0.55).Parent = t
	return t
end

-- Price buttons, live prices and owned passes.
local priceLabels = {} -- [key] = { label, ... }
local function priceButton(parent, entry, w, h, pos, anchor, z)
	if owns(entry) then
		local chip = Kit.block({ Name = 'Owned', Tone = 'green', Width = w, Height = h, Studs = false, Shadow = 3, Position = pos, AnchorPoint = anchor, ZIndex = z })
		Kit.text({ Name = 'Text', Text = 'Owned', TextSize = math.floor(h * 0.6), Stroke = Color.ink, StrokeThickness = 3.5, Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = chip.Body })
		chip.Parent = parent
		return chip
	end
	local holder, _, label = Kit.robuxButton({ Name = 'Buy', Price = entry.Price, Width = w, Height = h, Position = pos, AnchorPoint = anchor, Studs = 16, ZIndex = z })
	holder.Parent = parent
	priceLabels[entry.Key] = priceLabels[entry.Key] or {}
	table.insert(priceLabels[entry.Key], label)
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
					for _, label in priceLabels[entry.Key] or {} do
						if label.Parent then label.Text = tostring(price) end
					end
				end
			end)
		end
	end
end

---------------------------------------------------------------------------------------------- cards
local INNER = W - 24 - 8 - 24 -- the list's usable width (well, its margins and the scroll bar)
local function sectionTitle(text, order)
	local f = Kit.new('Frame', { Name = 'Title_' .. text, BackgroundTransparency = 1, Size = px(INNER, 50), LayoutOrder = order, ZIndex = 24 })
	Kit.new('Frame', { Name = 'Line', BackgroundColor3 = Color.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -20, 0, 3), ZIndex = 24, Parent = f })
	Kit.text({ Name = 'Text', Text = text, TextSize = 34, Stroke = Color.ink, StrokeThickness = 4, Position = px(0, 8), Size = UDim2.new(1, 0, 0, 40), ZIndex = 25, Parent = f })
	return f
end

-- A big gamepass card: the name, a big gradient line, the detail and the price on the left; the art on the right,
-- poking out over the top edge like the reference's zone lanterns.
local BIG_W, BIG_H = math.floor((INNER - 14) / 2), 196
local function bigCard(entry, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = BIG_W, Height = BIG_H, Position = px(x, y), Studs = 24, Gloss = true, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local artSize = 196
	local art = artFor(entry, artSize, z)
	art.AnchorPoint = Vector2.new(1, 0)
	art.Position = UDim2.new(1, 10, 0, -30)
	art.Parent = card.Body
	sticker(card.Body, entry, 46, UDim2.new(1, -60, 1, -46), z + 2)
	Kit.text({ Name = 'Title', Text = entry.Title, TextSize = 34, Stroke = Color.ink, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(18, 10), Size = px(BIG_W - 150, 40), ZIndex = z + 1, Parent = card.Body })
	local big = Kit.text({ Name = 'Big', Text = entry.Big or '', TextSize = 40, Stroke = Color.ink, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(18, 50), Size = px(BIG_W - artSize + 10, 46), ZIndex = z + 1, Parent = card.Body })
	Kit.gradient(Kit.hex('FFF6B0'), Kit.hex('FFC21A'), 0.6).Parent = big
	local detail = Kit.text({ Name = 'Detail', Text = entry.Detail or '', FontFace = Kit.Font.body, TextSize = 17, Stroke = Color.ink, StrokeThickness = 2, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Position = px(18, 98), Size = px(BIG_W - artSize - 8, 40), ZIndex = z + 1, Parent = card.Body })
	detail.TextWrapped = true
	priceButton(card.Body, entry, 160, 50, px(16, BIG_H - 62), Vector2.zero, z)
	return card
end

-- The wide banner card (VIP): art on the left, the big name, the detail and the price on the right.
local BANNER_H = 150
local function bannerCard(entry, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = INNER, Height = BANNER_H, Position = px(0, y), Studs = 24, Gloss = true, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local art = artFor(entry, 176, z)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 6, 0.5, -10)
	art.Parent = card.Body
	local big = Kit.text({ Name = 'Big', Text = entry.Big or entry.Title, TextSize = 84, Stroke = Color.ink, StrokeThickness = 8, TextXAlignment = Enum.TextXAlignment.Left, Position = px(196, 4), Size = px(300, 96), ZIndex = z + 1, Parent = card.Body })
	Kit.gradient(Kit.hex('FFF6B0'), Kit.hex('FFB020'), 0.6).Parent = big
	Kit.text({ Name = 'Detail', Text = entry.Detail or '', TextSize = 26, Stroke = Color.ink, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(200, 96), Size = px(INNER - 420, 34), ZIndex = z + 1, Parent = card.Body })
	priceButton(card.Body, entry, 180, 56, UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5), z)
	return card
end

-- A small card (packs and boosts): the art over the top, the amount or name, a detail line and the price.
local SMALL_W, SMALL_H = math.floor((INNER - 2 * 14) / 3), 184
local packLabels = {} -- [key] = TextLabel (power packs change with your next rebirth)
local function smallTitle(entry)
	if entry.Section == 'Power' then return '+' .. short(Products.powerAmount(entry.Key, rebirthNeed())) .. ' Power' end
	if entry.Section == 'Cash' then return '+' .. short(Products.cashAmount(entry.Key)) .. ' Cash' end
	return entry.Title
end
local function smallCard(entry, x, y, parent)
	local card = Kit.block({ Name = entry.Key, Tone = entry.Tone, Width = SMALL_W, Height = SMALL_H, Position = px(x, y), Studs = 20, ZIndex = 25 })
	card.Parent = parent
	local z = 28
	local art = artFor(entry, 104, z)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, -16)
	art.Parent = card.Body
	sticker(card.Body, entry, 34, UDim2.new(0.5, 52, 0, 62), z + 2)
	local title = Kit.text({ Name = 'Title', Text = smallTitle(entry), TextSize = 30, Stroke = Color.ink, StrokeThickness = 4, Position = px(8, 84), Size = UDim2.new(1, -16, 0, 34), ZIndex = z + 1, Parent = card.Body })
	title.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 30, Parent = title })
	if entry.Section == 'Power' then packLabels[entry.Key] = title end
	local detail = entry.Detail or (entry.Section ~= 'Boost' and entry.Title) or ''
	Kit.text({ Name = 'Detail', Text = detail, FontFace = Kit.Font.body, TextSize = 16, Stroke = Color.ink, StrokeThickness = 2, Position = px(8, 116), Size = UDim2.new(1, -16, 0, 18), ZIndex = z + 1, Parent = card.Body })
	priceButton(card.Body, entry, SMALL_W - 40, 40, UDim2.new(0.5, 0, 1, -10), Vector2.new(0.5, 1), z)
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
	for _, section in Products.Sections do
		local items = {}
		for _, entry in Products.Catalog do
			if entry.Section == section.Id then table.insert(items, entry) end
		end
		if #items == 0 then continue end
		order += 1
		local title = sectionTitle(section.Title, order)
		title.Parent = list
		sections[section.Id] = title
		order += 1
		local block = Kit.new('Frame', { Name = section.Id, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 24, Parent = list })
		local y = section.Id == 'Gamepass' and 34 or 20 -- (room for art poking over the first row)
		if section.Id == 'Gamepass' then
			local col = 0
			for _, entry in items do
				if entry.Banner then
					if col == 1 then y += BIG_H + 36; col = 0 end
					sections[entry.Key] = bannerCard(entry, y, block)
					y += BANNER_H + 36
				else
					sections[entry.Key] = bigCard(entry, col * (BIG_W + 14), y, block)
					col += 1
					if col == 2 then col = 0; y += BIG_H + 36 end
				end
			end
			if col == 1 then y += BIG_H + 36 end
		else
			for i, entry in items do
				local col = (i - 1) % 3
				sections[entry.Key] = smallCard(entry, col * (SMALL_W + 14), y, block)
				if col == 2 or i == #items then y += SMALL_H + 26 end
			end
		end
		block.Size = px(INNER, y)
	end
	fetchPrices()
end
local function paintPacks()
	for key, label in packLabels do
		if label.Parent then label.Text = '+' .. short(Products.powerAmount(key, rebirthNeed())) .. ' Power' end
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
	Motion.open(overlay, panel, 0.35)
	scrollTo(at)
end
openEvent.Event:Connect(open)

---------------------------------------------------------------------------------------------- layout
-- 900 x 520 design px fits every landscape screen down to small phones (UIKit's canvas is at least ~960 x 524).
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
