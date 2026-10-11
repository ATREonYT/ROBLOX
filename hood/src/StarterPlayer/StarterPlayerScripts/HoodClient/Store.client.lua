-- The Store window (brief 27: like the user's video A, our items and our honesty rules). ONE scrolling window and no
-- header bar: a big "Shop" title with its basket floats over the window's top-left edge, a red square X sits on its
-- top-right corner, and a thin frame holds a see-through dark body (the world blurs behind it). Plain white section
-- titles, in this order:
--   Exclusive     one big card per Robux shoe box: the real 3D box on the left (it turns when you point at it), its
--                 shoes as real 3D pairs with their true drop chances, and x8 (rainbow) / x3 (yellow) / x1 (green) price
--                 buttons; a bundle shows the one-by-one price it saves on, struck through (Count x the single price)
--   Gamepasses    VIP as the wide card, the three Power passes (2x Power and the two Robux lanes) 3-up with big art,
--                 the rest 2-up with a one-line subtitle
--   Boosts        3-up; Cash Packs 3-up; Power Packs 3-up
--   Codes         a dark box with an "Enter code" field and a green REDEEM (HoodServer/CodesService: each code once per
--                 player, a small Cash or boost gift; the answer shows on the box)
-- Items come from Config/Products (only Wired rows show). A tap on a price prompts Roblox's purchase only when the item
-- is live (Products.canBuy: the master switch, an id and Wired); otherwise "Coming soon!" pops over the list. Nothing
-- errors with every id still 0. With an id the card asks Roblox for the live price. A pass you own shows "Owned" (the
-- Pass_<Key> attribute StoreService sets). No stock counters, no countdowns, no made-up "was" prices, no NEW! tags.
-- The HUD opens it through the BindableEvent HoodStore.Open (optionally with a section id, a catalog key or 'Codes' to
-- scroll to); PlayerGui's HoodWindow attribute keeps one window open at a time.
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
local ShoeRules = optional('ShoeRules')
local Shoes = optional('Config', 'Shoes')
local Net = optional('Net')
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
local function gradient(t, top, bottom)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = t })
	return t
end

---------------------------------------------------------------------------------------------- window
local Win = Kit.shopWindow(root, { Name = NAME, Title = 'Shop', Icon = iconOr('BasketRed', 'Shop') })
local overlay, panel, list = Win.Overlay, Win.Panel, Win.List
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
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(0, Kit.ShopWindow.Top), Size = UDim2.new(1, 0, 1, -Kit.ShopWindow.Top), ZIndex = 21, Parent = panel })
Motion.button(Win.CloseButton, close)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= NAME then close() end
end)
Kit.new('UIListLayout', { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16), Parent = list })

-- "Coming soon!" and friends: a big outlined line across the middle of the window for a moment.
local noticeHolder = Kit.new('Frame', { Name = 'Notice', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, Kit.ShopWindow.Top / 2), Size = px(Kit.ShopWindow.W - 40, 60), ZIndex = 40, Parent = panel })
local NOTICE = { green = hex('7CFF4F'), red = hex('FF6B6B'), blue = hex('5AE0FF') }
local noticeCount = 0
local function notice(text, tone)
	noticeCount += 1
	local mine = noticeCount
	for _, c in noticeHolder:GetChildren() do c:Destroy() end
	local b = Kit.new('Frame', { Name = 'Box', BackgroundColor3 = hex('0E1020'), BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 41, Parent = noticeHolder })
	Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0), NumberSequenceKeypoint.new(0.82, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = b })
	label({ Name = 'Text', Text = text, TextSize = Kit.fitSize(text, 40, Kit.ShopWindow.W - 80, 20), StrokeThickness = 5, TextColor3 = NOTICE[tone or 'blue'] or NOTICE.blue, Size = UDim2.fromScale(1, 1), ZIndex = 45, Parent = b })
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
-- What a card shows (Products' Art). Menu pictures stay the drawn PNGs (Kit.icon3d: ART2's upload, or its flat stand-in
-- while that can't draw): 'icon:<id>'. ITEMS are their real 3D models (brief 27, Kit.model3d): 'box:<id>', 'gun:<id>',
-- 'shoe:<id>'.
local function artFor(entry, size, z)
	local kind, id = (entry.Art or ''):match('^(%w+):(.+)$')
	if kind == 'box' or kind == 'gun' or kind == 'shoe' then return Kit.model3d(kind, id, size, { ZIndex = z }) end
	local icon = kind == 'icon' and id or 'Shop'
	if icon == 'Power' then icon = iconOr('Muscle', 'Power') end
	return Kit.icon3d(icon, size, { ZIndex = z })
end

-- Price buttons, live prices and owned passes. tone: the button's colour (the green Robux button by default; the box
-- bundles' rainbow and yellow).
local priceLabels = {} -- [key] = { label, ... }
-- opts: Was (a bundle's real one-by-one price: struck through inside the button, left of the price), TextSize.
local STRUCK = hex('DCDCE6') -- (light grey with a dark edge: readable on every button colour; the red strike over it)
local function priceButton(parent, entry, w, h, pos, anchor, z, tone, opts)
	opts = opts or {}
	if owns(entry) then
		local chip = Kit.block({ Name = 'Owned', Tone = 'lime', Width = w, Height = h, Studs = false, Outline = 3.5, RimWidth = 3, Radius = 8, OutlineColor = Kit.Tone.lime.stroke, Position = pos, AnchorPoint = anchor, ZIndex = z })
		label({ Name = 'Text', Text = 'Owned', TextSize = math.floor(h * 0.56), Stroke = Kit.Tone.lime.stroke, Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = chip.Body })
		chip.Parent = parent
		return chip
	end
	local holder, _, l = Kit.robuxButton({ Name = 'Buy', Tone = tone, Price = entry.Price, TextSize = opts.TextSize, Width = w, Height = h, Position = pos, AnchorPoint = anchor, Outline = 3.5, RimWidth = 3, Radius = 8, ZIndex = z })
	holder.Parent = parent
	local row = holder.Body:FindFirstChild('Price')
	if opts.Was and row then
		local size = opts.WasSize or 22 -- (>= 14 dp on a phone, ~20 px on a PC)
		local text = tostring(opts.Was)
		local tw = Kit.textWidth(text, size)
		local total = tw + 6 + row.Size.X.Offset
		row.AnchorPoint = Vector2.new(0, 0.5)
		row.Position = UDim2.new(0.5, -total / 2 + tw + 6, 0.5, 0)
		local was = label({ Name = 'Was', Text = text, TextSize = size, TextColor3 = STRUCK, StrokeThickness = 2, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -total / 2, 0.5, 0), Size = px(tw, size + 4), ZIndex = z + 5, Parent = holder.Body })
		local line = Kit.new('Frame', { Name = 'Strike', BackgroundColor3 = hex('FF2A2A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 4, 0, 2), Rotation = -10, ZIndex = z + 6, Parent = was })
		Kit.stroke(hex('3A0000'), 1, true, 0, Enum.LineJoinMode.Miter).Parent = line
	end
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
-- "SAVE n%" (brief 27, the lead): a bundle's real saving, Products.savings (from Count x the single price, or the sum of
-- the parts), never typed in. A yellow tag, white letters with a dark edge, 0.45 x a price button's height.
local function saveBadge(parent, key, pos, anchor, z)
	local _, pct = Products.savings(key)
	if not pct then return nil end
	local text = 'SAVE ' .. pct .. '%'
	local size = 22 -- (>= 12 dp on a phone)
	local b = Kit.new('Frame', { Name = 'Save', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = anchor, Position = pos, Size = px(Kit.textWidth(text, size) + 8, 30), ZIndex = z, Parent = parent })
	Kit.corner(7).Parent = b
	Kit.stroke(hex('3A2400'), 2.5, true).Parent = b
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFE04A'), hex('FFA61A')), Parent = b })
	label({ Name = 'Text', Text = text, TextSize = size, Stroke = hex('3A2400'), StrokeThickness = 2, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = b })
	return b
end
-- Odds as people read them: "62%", "9.5%", "0.45%", "0.5%" (no trailing zeros).
local function pctText(chance)
	local t = string.format('%.2f', tonumber(chance) or 0)
	t = string.gsub(t, '0+$', '')
	t = string.gsub(t, '%.$', '')
	return t .. '%'
end

---------------------------------------------------------------------------------------------- cards
-- Measured on video A (its window 720 px wide at 1280): cards with rounded corners, a black outline, a saturated fill
-- with a faint stud tile and diagonal light stripes, the art big and over the edge, the title white with a dark edge in
-- the card's own colour, a one-line subtitle, the green price button.
local LW = Win.ListW -- the list's content width
local MARGIN, GAP = 12, 12
local CW = LW - 2 * MARGIN -- a full-width card
local THIRD = math.floor((CW - 2 * GAP) / 3)
local HALF = math.floor((CW - GAP) / 2)
local BTN_H = 58 -- (>= 36 px on a phone's screen)
local SUB = hex('8CEBFF') -- the subtitles' cyan (video A's)
local function card(entry, tone, w, h, x, y, parent)
	local c = Kit.block({ Name = entry.Key or 'Card', Tone = tone, Width = w, Height = h, Position = px(x, y), Outline = 3.5, Radius = 10, RimWidth = 3, Studs = 26, StudSparse = true, StudShade = 0.55, Gloss = true, ZIndex = 25 })
	c.Parent = parent
	local gloss = c.Body:FindFirstChild('Gloss')
	if gloss and gloss:IsA('ImageLabel') then gloss.ImageTransparency = math.max(gloss.ImageTransparency, 0.55) end -- (8-15% stripes)
	return c
end
local function title(parent, text, size, tone, props)
	props = props or {}
	local t = label({ Name = props.Name or 'Title', Text = text, TextSize = Kit.fitSize(text, size, props.Width or 300, props.Min or 18), Stroke = Kit.toneOf(tone).stroke or BLACK, StrokeThickness = math.max(3, size * 0.11),
		TextXAlignment = props.Align or Enum.TextXAlignment.Center, AnchorPoint = props.Anchor or Vector2.new(0.5, 0), Position = props.Position, Size = px(props.Width or 300, size + 8), ZIndex = props.ZIndex or 31, Parent = parent })
	return t
end
local function subtitle(parent, text, size, tone, props)
	props = props or {}
	local t = label({ Name = props.Name or 'Sub', Text = text, TextSize = Kit.fitSize(text, size, props.Width or 300, 15), TextColor3 = props.Color or SUB, Stroke = Kit.toneOf(tone).stroke or BLACK, StrokeThickness = math.max(2.5, size * 0.12),
		TextXAlignment = props.Align or Enum.TextXAlignment.Center, AnchorPoint = props.Anchor or Vector2.new(0.5, 0), Position = props.Position, Size = px(props.Width or 300, size + 6), ZIndex = props.ZIndex or 31, Parent = parent })
	return t
end

local sections = {} -- [section id, catalog key or box id] = the Frame to scroll to
local function sectionTitle(text, order)
	local f = Kit.new('Frame', { Name = 'Title_' .. text, BackgroundTransparency = 1, Size = px(LW, 52), LayoutOrder = order, ZIndex = 24 })
	label({ Name = 'Text', Text = text, TextSize = 40, StrokeThickness = 4.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 2), Size = UDim2.new(1, 0, 0, 48), ZIndex = 25, Parent = f })
	return f
end

-- Exclusive: one card per Robux box (video A's egg card). The 3D box, the whole model, fills the card's left part and
-- stands up to BOX_POP px over its top edge (the first one into the section title's room, the next over the gap and the
-- card above's bottom border, as video A's egg does); the shoes (real 3D pairs, one shared viewport, centred on their
-- rarity splats) with their true chances; the x8 / x3 / x1 buttons, biggest first, each bundle with its real
-- one-by-one price struck through inside the button and its "SAVE n%".
local BOX_H, BOX_POP, BOX_GAP = 290, 28, 14
local BOX_FOOT = 11 -- (px kept clear under the box: it stands on its card, not on the card's bottom border)
local BUNDLE_TONE = { [8] = 'rainbow', [3] = 'gold' } -- (x1: the green Robux button)
local function boxTone(first)
	return first.Tone == 'cardPurple' and 'storeMagenta' or 'storeBlue'
end
local function chanceColor(shoe)
	local r = Shoes and Shoes.RarityById and shoe and Shoes.RarityById[shoe.Rarity]
	return r and r.Color or Color.white
end
-- A splat centred under an item (its cloud ~1.15x the item: the texture's cloud is ~72% of its square, centred at 0.52 /
-- 0.46 of it).
local function itemSplat(parent, cx, cy, itemW, color, kind, rot, z, on)
	local size = math.floor(itemW * 1.15 / 0.72 + 0.5)
	local sp = Kit.splat(size, color, { Kind = kind, On = on, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx - 0.02 * size, cy + 0.04 * size), Rotation = rot or 0, ZIndex = z })
	sp.Parent = parent
	return sp
end
-- over: the box cards' top layer (their buttons, counts and SAVE badges), drawn over every box card, so a box standing
-- over the card above (its halo, its wings) always stays under that card's buttons.
local function boxCard(rows, y, parent, over)
	local first = rows[1]
	local boxId = first.Box or (first.Art or ''):match('^box:(.+)$') or ''
	local box = Shoes and Shoes.BoxById and Shoes.BoxById[boxId]
	local tone = boxTone(first)
	local c = card({ Key = 'Box_' .. boxId }, tone, CW, BOX_H, MARGIN, y, parent)
	local z = 28
	local left = math.floor(CW * 0.38) -- (the box's side of the card)
	-- the real box, the WHOLE model (topper and sparkles too) framed to fill the card's left part and BOX_POP over it,
	-- BOX_FOOT clear of its bottom: nothing is cut. Its camera looks down a little more (24 degrees) and nearly flat-on
	-- (FOV 14), so a halo on top reads as a ring, not a bar.
	local art = Kit.model3d('box', boxId, Vector2.new(left, BOX_H + BOX_POP - BOX_FOOT), { ZIndex = z, Whole = true, Fill = 0.99, MaxReach = 0.99, Overflow = 1, Pitch = 24, Fov = 14, Priority = 5, PreviewKind = 'boxhero' })
	art.Position = px(-3, -BOX_POP - 3)
	art.Parent = c.Body
	local artHit = Kit.new('TextButton', { Name = 'ArtHit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = px(left, BOX_H), ZIndex = 34, Parent = c.Body })
	Kit.model3dHover(art, artHit)
	artHit.Activated:Connect(function()
		Kit.model3dActive(art, 'tap', true)
		task.delay(2, function() Kit.model3dActive(art, 'tap', false) end)
	end)
	local right = CW - left - 14
	local t = title(c.Body, (box and box.Name) or first.Title, 40, tone, { Position = px(left + right / 2, 2), Width = right })
	if tone == 'storeMagenta' then gradient(t, hex('FFF6B0'), hex('F8CF4A')) end
	-- the odds row: every shoe of the box, rarest last, with its chance
	if box and type(box.Shoes) == 'table' then
		local n = #box.Shoes
		local pitch = right / n
		local cell = math.min(100, math.floor(pitch) + 6)
		local items = {}
		for _, sid in box.Shoes do
			local shoe = Shoes.ById and Shoes.ById[sid]
			table.insert(items, { Id = sid, Rarity = shoe and shoe.Rarity })
		end
		local cy = 102
		local tagsShown = 0 -- (how many of the row's name tags show: the title hides while any does)
		local models = Kit.model3dRow('shoe', items, cell, pitch, { ZIndex = z + 1, Position = px(left + pitch / 2 - cell / 2, cy - cell / 2), Priority = 4 })
		models.Parent = c.Body
		for i, sid in box.Shoes do
			local shoe = Shoes.ById and Shoes.ById[sid]
			local secret = shoe and shoe.Rank == #(Shoes.Rarities or {})
			local cx = left + (i - 0.5) * pitch
			itemSplat(c.Body, cx, cy, cell * Kit.Studio.shoe.Fill, chanceColor(shoe):Lerp(Kit.toneOf(tone).base, 0.15), secret and 'rainbow' or nil, (i * 37) % 360, z, Kit.toneOf(tone).base)
			local hit = Kit.new('TextButton', { Name = 'Hit_' .. sid, Text = '', AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy + 12), Size = px(pitch, cell + 24), ZIndex = 34, Parent = c.Body })
			Kit.model3dItemHover(models, i, hit)
			local chance = type(box.Chances) == 'table' and box.Chances[i]
			if chance then
				local cl = label({ Name = 'Chance' .. i, Text = pctText(chance), TextSize = 22, StrokeThickness = 3.5, TextColor3 = secret and Color.white or chanceColor(shoe):Lerp(Color.white, 0.25), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, 152), Size = px(pitch + 10, 28), ZIndex = z + 3, Parent = c.Body })
				if secret then Kit.new('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex('FF5A7A')), ColorSequenceKeypoint.new(0.35, hex('FFE24A')), ColorSequenceKeypoint.new(0.65, hex('5AE07A')), ColorSequenceKeypoint.new(1, hex('5AB8FF')) }), Parent = cl }) end
			end
			-- the name, while the pointer is on it (brief 28: over the box's title, which steps aside meanwhile, so the two
			-- never overlap)
			local tag = label({ Name = 'NameTag', Text = shoe and shoe.Name or sid, TextSize = 18, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = px(cx, 44), Size = px(160, 22), ZIndex = 40, Parent = c.Body })
			tag.Visible = false
			local function show(on)
				if tag.Visible == on then return end
				tag.Visible = on
				tagsShown = math.max(0, tagsShown + (on and 1 or -1))
				t.Visible = tagsShown == 0
			end
			hit.MouseEnter:Connect(function() show(true) end)
			hit.MouseLeave:Connect(function() show(false) end)
			hit.Activated:Connect(function()
				show(true)
				Kit.model3dItemActive(models, i, 'tap', true)
				task.delay(1.6, function()
					if tag.Parent then show(false) end
					Kit.model3dItemActive(models, i, 'tap', false)
				end)
			end)
		end
	end
	-- the buttons: x8 | x3 | x1 (rainbow, yellow, green); over each, its count and (a bundle) "SAVE n%"; inside a bundle's
	-- button, its real one-by-one price struck through
	table.sort(rows, function(a, b) return (a.Count or 1) > (b.Count or 1) end)
	local gap = 8
	-- (the single box's button is narrower: the bundles' get room for their count, SAVE badge and struck price)
	local single = #rows > 1 and 96 or nil
	local bundles = #rows - (single and 1 or 0)
	local bw = math.floor((right - (#rows - 1) * gap - (single or 0)) / math.max(1, bundles))
	local by = BOX_H - BTN_H - 10
	-- (on the top layer, at this card's body's place in it)
	local layer = over or c.Body
	local ox, oy = 0, 0
	if over then ox, oy = MARGIN + c.Body.Position.X.Offset, y + c.Body.Position.Y.Offset end
	local x = left
	for _, r in ipairs(rows) do
		local count = r.Count or 1
		local w = (count == 1 and single) or bw
		local whole = Products.savings(r.Key)
		priceButton(layer, r, w, BTN_H, px(ox + x, oy + by), Vector2.zero, z + 2, BUNDLE_TONE[count], { Was = whole, TextSize = 28 })
		label({ Name = 'Count' .. count, Text = 'x' .. count, TextSize = 24, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(ox + x, oy + by - 17), Size = px(50, 30), ZIndex = z + 6, Parent = layer })
		saveBadge(layer, r.Key, px(ox + x + w, oy + by - 17), Vector2.new(1, 0.5), z + 6)
		sections[r.Key] = c
		x += w + gap
	end
	return c
end

-- The wide pass card (VIP; video A's "2x Wins"): the art at the left over the edge, the name, the subtitle, the price.
local WIDE_H = 150
local function wideCard(entry, y, parent)
	local tone = entry.Tone
	local c = card(entry, tone, CW, WIDE_H, MARGIN, y, parent)
	local z = 28
	local art = artFor(entry, 176, z)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = px(104, WIDE_H / 2 - 4)
	art.Parent = c.Body
	title(c.Body, entry.Title, 56, tone, { Align = Enum.TextXAlignment.Left, Anchor = Vector2.zero, Position = px(206, 14), Width = 300 })
	subtitle(c.Body, entry.Sub or entry.Detail or '', 26, tone, { Align = Enum.TextXAlignment.Left, Anchor = Vector2.zero, Position = px(208, 82), Width = CW - 208 - 230 })
	priceButton(c.Body, entry, 190, 62, px(CW - 22, WIDE_H / 2), Vector2.new(1, 0.5), z + 2)
	return c
end

-- A 3-up card (the Power lanes, the boosts, the packs; video A's "VIP Target" and potion cards): the name and its
-- subtitle on top, the art big in the middle (over 55% of the card's height), the price button at the bottom.
local TALL_H = 262
local ART_Y = 136 -- (the art's centre on a 3-up card)
local function tallCard(entry, x, y, parent, sub, subColor)
	local tone = entry.Tone or 'cardGold'
	local c = card(entry, tone, THIRD, TALL_H, x, y, parent)
	local z = 28
	title(c.Body, entry.Title, 32, tone, { Position = px(THIRD / 2, 6), Width = THIRD - 14 })
	subtitle(c.Body, sub or entry.Sub or '', 22, tone, { Position = px(THIRD / 2, 42), Width = THIRD - 14, Color = subColor })
	-- video A's white sunburst behind the art (static)
	local burst = Kit.sunburst(THIRD - 16, { ZIndex = z - 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(THIRD / 2 - 3, ART_Y - 3) })
	burst.Parent = c.Body
	-- the art sized by what it draws: its picture ~52% of the card's height (Kit.place on the icon's drawn bounds)
	local kind, id = (entry.Art or ''):match('^(%w+):(.+)$')
	local icon = kind == 'icon' and id or 'Shop'
	if icon == 'Power' then icon = iconOr('Muscle', 'Power') end
	local rule = { W = (THIRD - 30) / TALL_H, H = 0.52, X = 0.5, XH = 0, Y = ART_Y / TALL_H }
	local art = Kit.icon3d(icon, nil, { ZIndex = z, Place = { Rule = rule, W = THIRD, H = TALL_H, X0 = 3.5, Y0 = 3.5 } })
	art.Parent = c.Body
	local whole = Products.savings(entry.Key)
	priceButton(c.Body, entry, THIRD - 44, BTN_H, px(THIRD / 2, TALL_H - 12), Vector2.new(0.5, 1), z + 2, nil, whole and { Was = whole, TextSize = 32 } or nil)
	-- (a bundle: "SAVE n%" on the button's top-right corner)
	if whole then saveBadge(c.Body, entry.Key, px(THIRD - 14, TALL_H - 12 - BTN_H - 2), Vector2.new(1, 0.5), z + 6) end
	return c
end

-- A 2-up pass card (video A's "+2 Pets"): the art big at the left, over the edge; the name and a one-line subtitle at
-- the right; the price button under them.
local HALF_H = 160
local function halfCard(entry, x, y, parent)
	local tone = entry.Tone
	local c = card(entry, tone, HALF, HALF_H, x, y, parent)
	local z = 28
	local art = artFor(entry, 168, z)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = px(76, HALF_H / 2 - 2)
	art.Parent = c.Body
	local w = HALF - 152
	title(c.Body, entry.Title, 38, tone, { Align = Enum.TextXAlignment.Right, Anchor = Vector2.new(1, 0), Position = px(HALF - 14, 6), Width = w })
	subtitle(c.Body, entry.Sub or entry.Detail or '', 22, tone, { Align = Enum.TextXAlignment.Right, Anchor = Vector2.new(1, 0), Position = px(HALF - 14, 50), Width = w })
	priceButton(c.Body, entry, 168, BTN_H, px(HALF - 16, HALF_H - 12), Vector2.new(1, 1), z + 2)
	return c
end

-- Packs: the amount is the subtitle (Power packs follow your next rebirth).
local packLabels = {} -- [key] = TextLabel
local PILE = { 'Tiny', 'Small', 'Medium', 'Large' }
local function packAmount(entry)
	if entry.Section == 'Power' then return '+' .. short(Products.powerAmount(entry.Key, rebirthNeed())) .. ' Power' end
	return '+' .. short(Products.cashAmount(entry.Key)) .. ' Cash'
end

-- Codes (video A's last box): a dark inset, a line, the blue "Enter code" field and the green REDEEM; the server's
-- answer shows on the line for a few seconds.
local CODES_H = 214
local codeBox, codeLine, redeemBusy
local CODE_HINT = 'Got a code? Type it here for a free gift!'
local function codesCard(y, parent)
	local c = Kit.new('Frame', { Name = 'Codes', BackgroundColor3 = hex('06070C'), BackgroundTransparency = 0.45, BorderSizePixel = 0, Position = px(MARGIN, y), Size = px(CW, CODES_H), ZIndex = 25, Parent = parent })
	Kit.corner(14).Parent = c
	Kit.stroke(BLACK, 3, true).Parent = c
	local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, Position = px(2, 2), Size = UDim2.new(1, -4, 1, -4), ZIndex = 25, Parent = c })
	Kit.corner(12).Parent = rim
	Kit.stroke(hex('DCE0EC'), 2, true, 0.45).Parent = rim
	codeLine = label({ Name = 'Line', Text = CODE_HINT, TextSize = 24, StrokeThickness = 3, TextColor3 = hex('FFE24A'), Position = px(0, 16), Size = px(CW, 30), ZIndex = 27, Parent = c })
	local field = Kit.new('Frame', { Name = 'Field', BackgroundColor3 = hex('3398F0'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = px(CW / 2, 58), Size = px(CW - 90, 62), ZIndex = 26, Parent = c })
	Kit.corner(6).Parent = field
	Kit.stroke(hex('0B2A55'), 2.5, true).Parent = field
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('4AAEFF'), hex('2A86E6')), Parent = field })
	-- ("Enter code" is a label of its own, like the inventory's Search box: it hides while you type)
	local placeholder = label({ Name = 'Placeholder', Text = 'Enter code', TextSize = 30, TextColor3 = hex('E4F2FF'), Stroke = hex('0B2A55'), StrokeThickness = 2.5, Size = UDim2.fromScale(1, 1), ZIndex = 27, Parent = field })
	codeBox = Kit.new('TextBox', {
		Name = 'Input', BackgroundTransparency = 1, Text = '', PlaceholderText = '', ClearTextOnFocus = false,
		FontFace = Kit.Font.display, TextSize = 30, TextColor3 = Color.white, Size = UDim2.new(1, -24, 1, 0), Position = px(12, 0), ZIndex = 28, Parent = field,
	})
	Kit.stroke(hex('0B2A55'), 2.5).Parent = codeBox
	local function focused()
		local ok, f = pcall(function() return codeBox:IsFocused() end)
		return ok and f == true
	end
	local function typed() placeholder.Visible = codeBox.Text == '' and not focused() end
	codeBox:GetPropertyChangedSignal('Text'):Connect(typed)
	codeBox.Focused:Connect(function() placeholder.Visible = false end)
	codeBox.FocusLost:Connect(typed)
	local redeem = Kit.blockButton({ Name = 'Redeem', Tone = 'lime', OutlineColor = Kit.Tone.lime.stroke, Width = 240, Height = 62, Text = 'REDEEM', TextSize = 32, Studs = false, Outline = 3.5, RimWidth = 3, Radius = 8, AnchorPoint = Vector2.new(0.5, 0), Position = px(CW / 2, 134), ZIndex = 27 })
	redeem.Parent = c
	local saying = 0
	local function say(text, color)
		saying += 1
		local mine = saying
		codeLine.Text = text
		codeLine.TextColor3 = color
		Motion.pop(codeLine, 0.12)
		task.delay(4, function()
			if mine == saying and codeLine.Parent then
				codeLine.Text = CODE_HINT
				codeLine.TextColor3 = hex('FFE24A')
			end
		end)
	end
	local function submit()
		local text = string.gsub(codeBox.Text or '', '^%s+', '')
		text = string.gsub(text, '%s+$', '')
		if text == '' then
			say('Type a code first!', hex('FFB4B4'))
			return
		end
		if redeemBusy then return end
		redeemBusy = true
		say('Checking...', hex('C8F6FF'))
		task.spawn(function()
			local ok, answer = pcall(function()
				local remote = Net and Net.get('RedeemCode')
				assert(remote, 'no remote')
				return remote:InvokeServer(text)
			end)
			redeemBusy = false
			if ok and type(answer) == 'table' and type(answer.Text) == 'string' then
				say(answer.Text, answer.Ok and hex('7CFF4F') or hex('FFB4B4'))
				if answer.Ok then
					codeBox.Text = ''
					placeholder.Visible = not focused()
				end
			else
				say('Codes are resting. Try again soon!', hex('FFB4B4'))
			end
		end)
	end
	Motion.button(redeem, submit)
	codeBox.FocusLost:Connect(function(enter) if enter then submit() end end)
	return c
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
	for _, section in Products.Sections do
		local items = {}
		for _, entry in Products.Catalog do
			-- (brief 22, lead) only what can really be bought: a row shows once its effect is Wired
			if entry.Section == section.Id and entry.Wired == true then table.insert(items, entry) end
		end
		if #items == 0 then continue end
		order += 1
		local head = sectionTitle(section.Title, order)
		head.Parent = list
		sections[section.Id] = head
		order += 1
		local block = Kit.new('Frame', { Name = section.Id, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 24, Parent = list })
		local y = 0
		if section.Id == 'Box' then
			-- one card a box, its bundles as buttons, in catalog order (room above each for the box standing out of it)
			local byBox, boxes = {}, {}
			for _, entry in items do
				local id = entry.Box or (entry.Art or ''):match('^box:(.+)$') or entry.Key
				if not byBox[id] then byBox[id] = {}; table.insert(boxes, id) end
				table.insert(byBox[id], entry)
			end
			-- (no room added for the boxes standing out of their cards: the first stands in the section title's room)
			local over = Kit.new('Frame', { Name = 'BoxButtons', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 26 + #boxes, Parent = block })
			for k, id in boxes do
				sections[id] = boxCard(byBox[id], y, block, over)
				sections[id].ZIndex += k -- (each card over the one before: its box stands over that card's bottom edge)
				y += BOX_H + BOX_GAP
			end
		elseif section.Id == 'Gamepass' then
			-- VIP wide, the Power passes 3-up, the rest 2-up
			local lanes, rest = {}, {}
			for _, entry in items do
				if entry.Banner then
					sections[entry.Key] = wideCard(entry, y, block)
					y += WIDE_H + GAP
				elseif entry.Lane then
					table.insert(lanes, entry)
				else
					table.insert(rest, entry)
				end
			end
			for i, entry in lanes do
				local col = (i - 1) % 3
				sections[entry.Key] = tallCard(entry, MARGIN + col * (THIRD + GAP), y, block)
				if col == 2 or i == #lanes then y += TALL_H + GAP end
			end
			for i, entry in rest do
				local col = (i - 1) % 2
				local alone = col == 0 and i == #rest
				sections[entry.Key] = halfCard(entry, alone and math.floor((LW - HALF) / 2) or MARGIN + col * (HALF + GAP), y, block)
				if col == 1 or i == #rest then y += HALF_H + GAP end
			end
		else
			-- Boosts, Cash Packs, Power Packs: 3-up, a short last row centred
			local n = #items
			for i, entry in items do
				local col = (i - 1) % 3
				local inRow = math.min(3, n - (i - 1 - col))
				local x0 = math.floor((LW - (inRow * THIRD + (inRow - 1) * GAP)) / 2)
				local sub, subColor
				if section.Id == 'Cash' or section.Id == 'Power' then
					sub, subColor = packAmount(entry), section.Id == 'Cash' and hex('B4FF8A') or hex('FFE27A')
				end
				local tile = entry
				if (section.Id == 'Cash' or section.Id == 'Power') and not (entry.Title or ''):find('Pack') then tile = table.clone(entry); tile.Title = (PILE[i] or 'Big') .. ' Pack' end
				if section.Id == 'Cash' or section.Id == 'Power' then
					-- (the pile grows pack by pack in ART2's art)
					local artId = (entry.Art or ''):match('^icon:(.+)$')
					if tile == entry then tile = table.clone(entry) end
					tile.Art = 'icon:' .. iconOr((section.Id == 'Power' and 'Power' or 'Cash') .. (PILE[i] or 'Large'), artId or '', section.Id == 'Power' and 'Muscle' or 'Cash')
				end
				local c = tallCard(tile, x0 + col * (THIRD + GAP), y, block, sub, subColor)
				if section.Id == 'Power' then packLabels[entry.Key] = c.Body:FindFirstChild('Sub') end
				sections[entry.Key] = c
				if col == 2 or i == n then y += TALL_H + GAP end
			end
		end
		block.Size = px(LW, y + 6)
	end
	-- Codes, last
	order += 1
	local head = sectionTitle('Codes', order)
	head.Parent = list
	sections.Codes = head
	order += 1
	local block = Kit.new('Frame', { Name = 'CodesBlock', BackgroundTransparency = 1, LayoutOrder = order, Size = px(LW, CODES_H + 8), ZIndex = 24, Parent = list })
	codesCard(0, block)
	-- the drawn scroll bar: the list's content height (its padding and blocks)
	local total = 18
	for _, child in list:GetChildren() do
		if child:IsA('GuiObject') then total += child.Size.Y.Offset end
	end
	Win.SetContent(total)
	fetchPrices()
end
local function paintPacks()
	for key, l in packLabels do
		local entry = Products.ByKey[key]
		if l and l.Parent and entry then l.Text = packAmount(entry) end
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
-- The window keeps its design size where it fits (~56% of a PC screen's width, like video A's) and shrinks onto smaller
-- screens (Kit.fitWindow, the floating title included). Phones (the camera's short side <= 500) get the whole safe
-- screen, the topbar row included, so the window is as big as it can be; its X stays well under Roblox's top bar.
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
	Win.SetBar(phone and 12 or 7) -- (~8 dp on a phone, ~6 px on a PC)
	if phone then
		-- (a little smaller, at the right and a little low: the title clears Roblox's buttons at the top left and the X
		-- stays under the top bar's row)
		local s = fitter:FindFirstChild('FitScale')
		if s then s.Scale *= 0.96 end
		fitter.AnchorPoint = Vector2.new(1, 0.5)
		fitter.Position = UDim2.new(1, -16, 0.5, 10)
	else
		fitter.AnchorPoint = Vector2.new(0.5, 0.5)
		fitter.Position = UDim2.new(0.5, 0, 0.5, 2)
	end
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
