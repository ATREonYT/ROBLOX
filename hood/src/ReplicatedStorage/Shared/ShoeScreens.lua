-- ShoeScreens (brief 30, MOCKUP): the user's seven World 1 shoe UI artboards, screen by screen, built from Shared/ArtKit
-- in the artboards' own pixel numbers (each panel's origin is its top-left corner on the artboard). Pure UI over data and
-- callbacks: the client scripts (Shoes.client, Inventory.client, Store.client, Shared/DailyWindow) pass `ctx` and act;
-- the server decides. Every number shown comes from config (Config/Shoes odds and rarities, Config/Products prices,
-- ShoeRules capacity, RetentionService rewards); the artboards' illustrative numbers are never used.
--   boxes(parent, ctx)              02 left: the four box families, View Drops, the selected box's Open and price, Cash
--   drops(parent, boxId, ctx)       02 right (Street), 03 left (Graffiti), 07 (Chrome / Crown): the drop grid with its
--                                   rarity frames, Open 1 / Open 3 / Auto Open / View Odds / Back, the PityLine slot
--   reveal(parent, info, ctx)       03 right: the reveal card over the 3D opening, Equip / Keep / Open Again / Stop Opening
--   inventory(parent, ctx)          04 left: search, sort, filter, capacity, the cards, Equip Best, Lock, Delete (review)
--   detail(parent, id, ctx)         04 right: the pair, its tags, EQUIPPED, Unequip / Favourite / Lock / Back, the tabs
--   collection(parent, ctx)         05 left: the 22 designs, discovered or not, the family filter
--   gift(parent, ctx)               06: the player picker and the confirmed item / price review
--   confirm(parent, id, ctx)        06: Equip this pair? (Equip / Cancel), the Inventory Full box, the Bundle received box
--   bundleHero(parent, ctx)         01 left: the Featured hero card with the box cards and the price line (the Store)
--   bundleDetail(parent, ctx)       01 right: THE GRAIL BUNDLE: its three pairs, Purchase, Gift a Player, Back
--   shopPanel / purchaseStates      the artboards' whole panels (the Store's own window holds the hero in game)
-- Each returns a handle { P = the ArtKit panel (or Root), refresh = fn, ... }.
local Shared = script.Parent
local A = require(Shared.ArtKit)
local U = require(Shared.ShoeUIRules)
local Shoes = require(Shared.Config.Shoes)
local ShoeRules = require(Shared.ShoeRules)
local Products = require(Shared.Config.Products)
local Kit = require(Shared.UIKit)
-- (PITY: the visible pity counter; any label named PityLine is painted by PityUI.paint, the value from Shared/PityRules)
local PityUI
do
	local node = Shared:FindFirstChild('PityUI')
	local ok, m = pcall(function() return node and require(node) end)
	PityUI = ok and type(m) == 'table' and m or nil
end

local S = {}
local hex = Kit.hex
local px = UDim2.fromOffset
local WHITE = Color3.new(1, 1, 1)
local RobuxText = require(Shared.RobuxText) -- (ROBUX) the Robux sign before every Robux price
local SellFX = require(Shared.SellFX) -- (ROBUX, rule 28: the artboard's stars round the Chrome box)

local function short(n) return Kit.short(math.max(0, math.floor(n or 0))) end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
	return (out:gsub('^,', ''))
end
S.commas = commas
local function chanceOf(id, lucky) return ShoeRules.chanceText(ShoeRules.chanceOf(id, lucky)) end -- (lucky: the luck level)
local function call(fn, ...) if type(fn) == 'function' then return fn(...) end return nil end

-- the price of n opens of a box: '25 Cash' / '⏣99' (n = 1, 3)
function S.priceText(boxId, n)
	local box = Shoes.BoxById[boxId]
	if not box then return '' end
	if box.Robux then
		local key = box.Robux .. ((n or 1) > 1 and tostring(n) or '')
		local e = Products.ByKey[key]
		return e and RobuxText.fmt(e.Price) or ''
	end
	return short(box.Price * (n or 1)) .. ' Cash'
end

---------------------------------------------------------------------------------------------- the Auto Open / odds footer
local function noteLabel(parent, x, y, w, h, text, size, align, name)
	return A.text(parent, text, { Name = name or 'Note', Size = size or 16, X = x, Y = y, W = w, H = h, Align = align or 'Right', Color = hex('8FB4D8'), Font = A.Font.Body, StrokeW = 2, Z = parent.ZIndex + 1, Fit = true, MinSize = 10 })
end

---------------------------------------------------------------------------------------------- 02 left: the box browser
-- ctx: cash() -> number, selected (box id), select(id), viewDrops(id), open(id), addCash(), close()
function S.boxes(parent, ctx)
	local P = A.panel(parent, { Name = 'Boxes', W = 1090, H = 750, Head = 96, Foot = 107, Title = 'SHOE BOXES', TitleSize = 52, TitleX = 150, TitleW = 700, Icon = 'Box_Street', IconBox = { 15, -12, 115, 108 } })
	local z = P.Z + 3
	-- the Cash pill (in the X's place, as on the artboard): the real Cash, a green + (the Store's Cash Packs)
	local cash = A.block(P.Panel, { Name = 'Cash', X = 873, Y = 21, W = 195, H = 60, Fill = hex('0E1E30'), Radius = 12, Outline = 4, Z = P.Z + 4 })
	A.stroke(A.frame(cash, { Name = 'Rim', X = 3, Y = 3, W = 189, H = 54, Radius = 9, Z = P.Z + 4 }), hex('1E3A58'), 2, true)
	A.icon(cash, 'Cash', { S = 52, X = 36, Y = 30, Z = P.Z + 4 })
	local cashText = A.text(cash, '', { Name = 'Amount', Size = 26, X = 62, Y = 0, W = 82, H = 60, Align = 'Left', Z = P.Z + 4, Fit = true })
	local plus = A.button(cash, { Name = 'AddCash', Text = '+', Tone = 'green', X = 146, Y = 12, W = 38, H = 36, TextSize = 30, Radius = 18, Outline = 3, Studs = false, Z = P.Z + 4, OnClick = function() call(ctx.addCash) end })
	plus.Body:FindFirstChild('Label').Position = px(-1, -2)
	local sel = ctx.selected or 'Street'
	local cards = {}
	local rects = { Street = { 15, 113, 522, 255 }, Graffiti = { 548, 113, 527, 255 }, Exclusive = { 15, 380, 522, 253 }, Grail = { 548, 380, 527, 253 } }
	local preview = { Street = 'FreshCanvas', Graffiti = 'SprayTag', Exclusive = 'MidnightChrome', Grail = 'GoldenHour' }
	for _, id in A.FamilyOrder do
		local r = rects[id]
		local fam = A.Family[id]
		local card = A.framed(P.Content, { Name = 'Card_' .. id, Pos = P.c(r[1], r[2]), W = r[3], H = r[4], Border = fam.Border, BorderW = 6, Inner = fam.Card[2], InnerGradient = { fam.Card[1], fam.Card[2] }, InnerRot = 90, Radius = 16, Outline = 4, Z = z })
		local face = card:FindFirstChild('Face')
		local st = Kit.studs(face, { Pitch = 22, Width = r[3] - 12, Height = r[4] - 12, Shade = 0.86, ZIndex = z })
		if st and st:IsA('ImageLabel') then A.corner(st, 12) end
		A.boxArt(face, id, { X = 12, Y = 26, W = 252, H = 206, Z = z })
		if Shoes.BoxById[id] and Shoes.BoxById[id].Robux then
			-- (ROBUX) the Robux boxes twinkle, like the artboard's Chrome Box (UI-Artboard-02): stars over the box art only
			local over = A.frame(face, { Name = 'Stars', X = 12, Y = 26, W = 252, H = 206, Z = z + 2 })
			SellFX.sparkles(over, { Count = 2, Size = 20, ZIndex = z + 2, Every = 3.2, Inset = 0.12, Color = hex('DFF8FF'), Seed = #id })
		end
		A.text(face, fam.Box, { Name = 'Name', Size = 44, X = 230, Y = 6, W = r[3] - 12 - 240, H = 56, Align = 'Right', Z = z, Fit = true })
		A.shoeArt(face, preview[id], { X = r[3] - 210, Y = 74, W = 175, H = 112, Z = z })
		A.button(face, { Name = 'ViewDrops', Text = 'View Drops', Tone = 'blue', X = r[3] - 246, Y = 184, W = 218, H = 52, TextSize = 26, Radius = 10, Outline = 4, Z = z, OnClick = function() call(ctx.viewDrops, id) end })
		local hit = Kit.new('TextButton', { Name = 'Select', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -260, 1, 0), ZIndex = z, Parent = face })
		hit.Activated:Connect(function()
			sel = id
			call(ctx.select, id)
			S._paintBoxes(cards, sel)
		end)
		cards[id] = card
	end
	-- the footer: the selected box, Open and its price
	local bar = A.block(P.Foot, { Name = 'Bar', X = 10, Y = 0, W = 1065, H = 95, Gradient = { hex('1660C8'), hex('0B2E6A') }, Radius = 14, Outline = 4, Z = z })
	A.stroke(A.frame(bar, { Name = 'Rim', X = 3, Y = 3, W = 1059, H = 89, Radius = 11, Z = z }), hex('2EC8F4'), 3, true)
	local selIcon = A.frame(bar, { Name = 'SelectedBox', X = 30, Y = 0, W = 125, H = 95, Z = z })
	local selName = A.text(bar, '', { Name = 'SelectedName', Size = 38, X = 160, Y = 0, W = 250, H = 95, Align = 'Left', Z = z, Fit = true })
	local open = A.button(bar, { Name = 'Open', Text = 'Open', Tone = 'green', X = 425, Y = 10, W = 315, H = 77, TextSize = 44, Z = z, OnClick = function() call(ctx.open, sel) end })
	local priceWell = A.block(bar, { Name = 'Price', X = 758, Y = 15, W = 300, H = 66, Fill = hex('0C1E36'), Radius = 10, Outline = 3, Z = z })
	local priceText = A.text(priceWell, '', { Name = 'Text', Size = 24, X = 0, Y = 0, W = 300, H = 66, Color = hex('B8D4F0'), Z = z, Fit = true })
	local H = { P = P, Cards = cards, Open = open }
	function H.refresh()
		cashText.Text = short(call(ctx.cash) or 0)
		for _, c in selIcon:GetChildren() do c:Destroy() end
		A.boxArt(selIcon, sel, { X = 0, Y = 4, W = 125, H = 86, Z = z })
		selName.Text = A.boxName(sel)
		priceText.Text = S.priceText(sel, 1)
		-- (ROBUX, rule 28) a Robux box's price: big, in lime, the Robux sign first; a Cash note stays small and blue-grey
		local robuxBox = Shoes.BoxById[sel] and Shoes.BoxById[sel].Robux ~= nil
		priceText.TextColor3 = robuxBox and hex('B8F838') or hex('B8D4F0')
		priceText.TextSize = robuxBox and 40 or 24
		local st = call(ctx.openState, sel, 1) or 'normal'
		A.setState(open, st == 'disabled' and 'disabled' or 'normal', Shoes.BoxById[sel] and Shoes.BoxById[sel].Robux and 'Buy' or 'Open')
		S._paintBoxes(cards, sel)
	end
	function H.select(id) sel = id; H.refresh() end
	H.refresh()
	return H
end
function S._paintBoxes(cards, sel)
	for id, card in cards do
		local glow = card:FindFirstChild('SelGlow')
		if id == sel and not glow then
			glow = A.frame(card, { Name = 'SelGlow', X = -8, Y = -8, W = card.Size.X.Offset + 16, H = card.Size.Y.Offset + 16, Radius = 22, Z = card.ZIndex })
			A.stroke(glow, hex('FFE04A'), 5, true)
		elseif id ~= sel and glow then
			glow:Destroy()
		end
	end
end

---------------------------------------------------------------------------------------------- drops (02 right, 03 left, 07)
-- The three artboard layouts: Street (02 right), Graffiti (03 left), Chrome / Crown (07). A later box uses Street's.
local LAYOUT = {
	street = { W = 834, H = 750, Head = 96, Foot = 104, Icon = { 13, -12, 110, 108 }, TitleX = 138, TitleSize = 64, Close = { 733, 13, 85, 75 },
		Cards = { { 18, 113, 258, 253 }, { 288, 113, 260, 253 }, { 560, 113, 260, 253 }, { 18, 378, 258, 253 }, { 288, 378, 260, 253 }, { 560, 378, 260, 253 } } },
	graffiti = { W = 1035, H = 852, Head = 117, Foot = 125, Icon = { 20, -10, 165, 142 }, TitleX = 215, TitleSize = 70, Close = { 933, 22, 84, 78 },
		Cards = { { 30, 142, 313, 272 }, { 360, 142, 313, 272 }, { 687, 142, 318, 272 }, { 30, 430, 313, 272 }, { 360, 430, 313, 272 }, { 687, 430, 318, 272 } } },
	wide = { W = 968, H = 744, Head = 133, Foot = 107, Icon = { 10, -17, 245, 207 }, TitleX = 295, TitleSize = 84, Close = { 860, 17, 88, 93 },
		Cards = { { 15, 145, 305, 240 }, { 328, 145, 307, 240 }, { 645, 145, 307, 240 }, { 15, 395, 460, 230 }, { 485, 395, 465, 230 } } },
}
S.Layout = LAYOUT
local function variantOf(boxId)
	if boxId == 'Graffiti' then return 'graffiti' end
	if boxId == 'Exclusive' or boxId == 'Grail' then return 'wide' end
	return 'street'
end
S.variantOf = variantOf

-- one drop card; returns { Card, Pill/Bar label, set(odds) }
local function dropCard(parent, r, id, variant, z, lucky)
	local shoe = Shoes.ById[id]
	local rar = A.rarity(shoe.Rarity)
	local secret = rar.Rainbow
	local w, h = r[3], r[4]
	local c = {}
	if variant == 'street' then
		local card, face = A.framed(parent, { Name = 'Drop_' .. id, Pos = r.Pos, W = w, H = h, Border = secret and 'rainbow' or hex('2EC8F4'), BorderW = 5, Inner = secret and hex('5A1A9A') or nil, InnerGradient = secret and { hex('7A2AC8'), hex('3A0E6A') } or nil, Radius = 14, Outline = 4, Glow = secret and hex('FF9AE8') or nil, Z = z })
		if secret then
			for _, sp in { { 22, 60, 26 }, { w - 30, 40, 22 }, { 30, h - 70, 20 }, { w - 26, h - 80, 26 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
		end
		A.text(face, shoe.Name, { Name = 'Name', Size = 28, X = 6, Y = 4, W = w - 22, H = 42, Z = z, Fit = true })
		A.shoeArt(face, id, { X = 12, Y = 48, W = w - 34, H = 140, Z = z })
		local pill, label = A.rarityPill(face, shoe.Rarity, { X = 6, Y = h - 58, W = w - 22, H = 42, TextSize = 26, Z = z, Outline = 3 })
		c.Card, c.Label, c.Pill = card, label, pill
		function c.set(odds) label.Text = odds and chanceOf(id, lucky) or rar.Name end
	elseif variant == 'graffiti' then
		local card, face = A.framed(parent, { Name = 'Drop_' .. id, Pos = r.Pos, W = w, H = h, Border = secret and 'rainbow' or rar.Color, BorderW = 7, Radius = 16, Outline = 4, Z = z })
		local pill, label = A.rarityPill(face, shoe.Rarity, { X = (w - 14) / 2 - 85, Y = 8, W = 170, H = 44, TextSize = 26, Z = z, Outline = 3 })
		if secret then
			A.crown(face, (w - 14) / 2 - 112, 30, 40, z)
			A.crown(face, (w - 14) / 2 + 112, 30, 40, z)
		end
		A.shoeArt(face, id, { X = 18, Y = 58, W = w - 50, H = 148, Z = z })
		A.text(face, shoe.Name, { Name = 'Name', Size = 32, X = 6, Y = h - 66, W = w - 26, H = 46, Z = z, Fit = true })
		c.Card, c.Label, c.Pill = card, label, pill
		-- (no View Odds on this artboard: the pill always carries the real chance)
		function c.set() label.Text = rar.Name .. ' ' .. chanceOf(id, lucky) end
	else
		local card, face = A.framed(parent, { Name = 'Drop_' .. id, Pos = r.Pos, W = w, H = h, Border = secret and hex('FF6AD8') or hex('2EC8F4'), BorderW = 6, Inner = secret and hex('5A1A9A') or nil, InnerGradient = secret and { hex('8A34D8'), hex('3A0E6A') } or nil, Radius = 16, Outline = 4, Glow = secret and hex('FFB0F0') or nil, Z = z })
		if secret then
			A.sunburst(face, (w - 12) / 2, (h - 12) * 0.42, w * 0.9, z, WHITE, 0.12)
			for _, sp in { { 40, 50, 34 }, { w - 60, 40, 30 }, { 50, h - 110, 24 }, { w - 50, h - 100, 34 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
		end
		A.shoeArt(face, id, { X = 20, Y = 14, W = w - 52, H = h - 82, Z = z })
		local bar = A.block(face, { Name = 'NameBar', X = 7, Y = h - 62, W = w - 26, H = 45, Tone = secret and 'magenta' or 'blue', Radius = 10, Outline = 3, Studs = false, Z = z })
		local label = A.text(bar, shoe.Name, { Name = 'Label', Size = 28, X = 6, Y = 0, W = w - 38, H = 45, Z = z, Fit = true })
		c.Card, c.Label, c.Bar = card, label, bar
		function c.set(odds)
			label.Text = odds and (rar.Name .. '  ' .. chanceOf(id, lucky)) or shoe.Name
			bar.BackgroundColor3 = WHITE
			local g = bar:FindFirstChildOfClass('UIGradient')
			if g then
				if odds and secret then g.Color = A.rainbowSeq()
				elseif odds then g.Color = ColorSequence.new(rar.Color:Lerp(WHITE, 0.25), rar.Color)
				else local t = secret and A.Tone.magenta or A.Tone.blue; g.Color = ColorSequence.new(t.top, t.base) end
				g.Rotation = (odds and secret) and 0 or 90
			end
		end
	end
	return c
end

-- ctx: lucky (bool), open(boxId, n), auto(boxId), autoOn() -> bool, autoAvailable(boxId) -> bool, back(), close(),
-- openState(boxId, n) -> 'normal' | 'disabled', pity(boxId) -> text | nil, odds (bool: start on the odds)
function S.drops(parent, boxId, ctx)
	local box = Shoes.BoxById[boxId]
	local variant = variantOf(boxId)
	local L = LAYOUT[variant]
	local fam = A.Family[boxId] or A.Family.Street
	local crown = boxId == 'Grail'
	local P = A.panel(parent, {
		Name = 'Drops_' .. boxId, W = L.W, H = L.H, Head = L.Head, Foot = L.Foot, Title = A.boxName(boxId), TitleSize = L.TitleSize, TitleX = L.TitleX,
		TitleW = L.Close[1] - L.TitleX - 20, HeadTone = crown and 'purple' or 'cyan', Body = variant == 'graffiti' and hex('E8268A') or nil,
		BodyGradient = variant == 'graffiti' and { hex('F2349A'), hex('D01C86') } or nil, RimColor = variant == 'graffiti' and hex('FF7AC8') or (crown and hex('8A3AD8') or nil),
		IconBox = L.Icon, IconNode = function(holder, cx, cy, s, z) A.boxArt(holder, boxId, { Pos = px(cx, cy), Anchor = Vector2.new(0.5, 0.5), W = L.Icon[3], H = L.Icon[4], Z = z }) end,
		Close = function() call(ctx.close) end, CloseBox = L.Close, MinText = 18,
	})
	local z = P.Z + 3
	local odds = ctx.odds == true
	local cards = {}
	for i, id in box.Shoes do
		local r = L.Cards[i]
		if r then
			local rr = { r[1], r[2], r[3], r[4], Pos = P.c(r[1], r[2]) }
			cards[i] = dropCard(P.Content, rr, id, variant, z, ctx.lucky)
		end
	end
	local foot = P.Foot
	local H = { P = P, Box = boxId, Cards = cards }
	local open1, open3, toggle, oddsButton, back, segDrops, segOdds, note, pity
	local function setOdds(on)
		odds = on
		for _, c in cards do c.set(on) end
		if oddsButton then A.setText(oddsButton, on and 'View Drops' or 'View Odds') end
		if segDrops then
			A.setState(segDrops, on and 'normal' or 'selected')
			A.buttonInfo(segDrops).Tone = on and 'dark' or (crown and 'magenta' or 'blue')
			A.buttonInfo(segOdds).Tone = on and (crown and 'magenta' or 'blue') or 'dark'
			A.setState(segDrops, 'normal')
			A.setState(segOdds, 'normal')
		end
	end
	if variant == 'street' then
		local strip = A.block(foot, { Name = 'Strip', X = 6, Y = -6, W = L.W - 12, H = L.Foot, Fill = hex('0D2A44'), Radius = 14, Outline = 3, Z = z })
		A.stroke(A.frame(strip, { Name = 'Rim', X = 3, Y = 3, W = L.W - 18, H = L.Foot - 6, Radius = 11, Z = z }), hex('2EC8F4'), 2, true, 0.3)
		open1 = A.button(foot, { Name = 'Open1', Text = 'Open 1', Tone = 'green', X = 18, Y = 4, W = 185, H = 68, TextSize = 36, Z = z, OnClick = function() call(ctx.open, boxId, 1) end })
		open3 = A.button(foot, { Name = 'Open3', Text = 'Open 3', Tone = 'orange', X = 213, Y = 4, W = 185, H = 68, TextSize = 36, Z = z, OnClick = function() call(ctx.open, boxId, 3) end })
		toggle = A.toggle(foot, { Name = 'AutoOpen', Label = 'Auto Open', X = 408, Y = 6, W = 225, H = 64, TextSize = 22, Z = z, OnClick = function() call(ctx.auto, boxId) end })
		oddsButton = A.button(foot, { Name = 'ViewOdds', Text = 'View Odds', Tone = 'blue', X = 643, Y = 6, W = 172, H = 64, TextSize = 28, Z = z, OnClick = function() setOdds(not odds) end })
		pity = noteLabel(foot, 22, 76, 390, 20, '', 15, 'Left', 'PityLine')
		note = noteLabel(foot, 420, 76, 395, 20, '', 15, 'Right')
	elseif variant == 'graffiti' then
		local well = A.block(foot, { Name = 'Well', X = 23, Y = 0, W = 820, H = 90, Fill = hex('1A1E2E'), Radius = 14, Outline = 4, Z = z })
		A.stroke(A.frame(well, { Name = 'Rim', X = 3, Y = 3, W = 814, H = 84, Radius = 11, Z = z }), hex('3A4258'), 2, true)
		A.boxArt(foot, boxId, { X = 28, Y = 0, W = 90, H = 90, Z = z + 1 })
		open1 = A.button(foot, { Name = 'Open1', Text = 'Open 1', Tone = 'green', X = 108, Y = 6, W = 232, H = 78, TextSize = 44, Z = z, OnClick = function() call(ctx.open, boxId, 1) end })
		open3 = A.button(foot, { Name = 'Open3', Text = 'Open 3', Tone = 'blue', X = 357, Y = 6, W = 216, H = 78, TextSize = 44, Z = z, OnClick = function() call(ctx.open, boxId, 3) end })
		toggle = A.toggle(foot, { Name = 'AutoOpen', Label = 'Auto Open', X = 585, Y = 9, W = 250, H = 72, TextSize = 26, Z = z, OnClick = function() call(ctx.auto, boxId) end })
		back = A.button(foot, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 853, Y = 6, W = 157, H = 78, TextSize = 42, Z = z, OnClick = function() call(ctx.back) end })
		pity = noteLabel(foot, 40, 95, 340, 24, '', 19, 'Left', 'PityLine')
		note = noteLabel(foot, 380, 95, 630, 24, '', 19, 'Right')
		pity.TextColor3, note.TextColor3 = hex('FFE0F2'), hex('FFE0F2')
	else
		local strip = A.block(foot, { Name = 'Strip', X = 6, Y = 0, W = L.W - 12, H = L.Foot - 6, Fill = crown and hex('3A1468') or hex('0D2A44'), Radius = 14, Outline = 4, Z = z })
		A.stroke(A.frame(strip, { Name = 'Rim', X = 3, Y = 3, W = L.W - 18, H = L.Foot - 12, Radius = 11, Z = z }), crown and hex('C04CFF') or hex('2EC8F4'), 3, true)
		local designs = A.block(foot, { Name = 'Designs', X = 18, Y = 10, W = 224, H = 80, Fill = crown and hex('2A0E4E') or hex('0E2034'), Radius = 10, Outline = 3, Z = z })
		A.text(designs, tostring(#box.Shoes), { Name = 'Count', Size = 46, X = 8, Y = 2, W = 44, H = 50, Z = z })
		A.text(designs, 'DESIGNS', { Name = 'Word', Size = 30, X = 52, Y = 6, W = 166, H = 42, Align = 'Left', Z = z, Fit = true })
		pity = noteLabel(designs, 4, 52, 216, 22, '', 14, 'Center', 'PityLine')
		open1 = A.button(foot, { Name = 'Open1', Text = 'Open 1', Tone = 'green', X = 255, Y = 13, W = 128, H = 73, TextSize = 30, Z = z, OnClick = function() call(ctx.open, boxId, 1) end })
		open3 = A.button(foot, { Name = 'Open3', Text = 'Open 3', Tone = 'orange', X = 393, Y = 13, W = 127, H = 73, TextSize = 30, Z = z, OnClick = function() call(ctx.open, boxId, 3) end })
		toggle = A.toggle(foot, { Name = 'AutoOpen', Label = 'Auto Open', X = 530, Y = 15, W = 170, H = 70, TextSize = 18, Z = z, OnClick = function() call(ctx.auto, boxId) end })
		back = A.button(foot, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 708, Y = 13, W = 87, H = 73, TextSize = 28, Z = z, OnClick = function() call(ctx.back) end })
		local seg = A.block(foot, { Name = 'DropsOdds', X = 808, Y = 15, W = 134, H = 70, Fill = hex('0E1A2A'), Radius = 10, Outline = 3, Z = z })
		segDrops = A.button(seg, { Name = 'Drops', Text = 'Drops', Tone = crown and 'magenta' or 'blue', X = 4, Y = 4, W = 62, H = 62, TextSize = 20, Radius = 8, Outline = 2, Studs = false, Z = z, OnClick = function() setOdds(false) end })
		segOdds = A.button(seg, { Name = 'Odds', Text = 'Odds', Tone = 'dark', X = 68, Y = 4, W = 62, H = 62, TextSize = 20, Radius = 8, Outline = 2, Studs = false, Z = z, OnClick = function() setOdds(true) end })
		note = noteLabel(foot, 255, 88, 690, 16, '', 13, 'Right')
	end
	H.Open1, H.Open3, H.Toggle, H.Back, H.OddsButton = open1, open3, toggle, back, oddsButton
	H.PityLine, H.Note = pity, note
	function H.refresh()
		setOdds(odds)
		local robux = box.Robux ~= nil
		note.Text = 'Open 1: ' .. S.priceText(boxId, 1) .. '  ·  Open 3: ' .. S.priceText(boxId, 3)
		if PityUI and PityUI.paint then PityUI.paint(pity, boxId) else pity.Text = call(ctx.pity, boxId) or '' end
		for n, b in { [1] = open1, [3] = open3 } do
			local st = call(ctx.openState, boxId, n) or 'normal'
			A.setState(b, st)
		end
		local on = call(ctx.autoOn) == true
		A.setToggle(toggle, on, robux or call(ctx.autoAvailable, boxId) == false)
	end
	H.setOdds = setOdds
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 03 right: the reveal card
-- info: ShoeOpened's payload (Shoe = the best pair; Shoes = every pair of the open). ctx: equip(), keep(), again(),
-- stop(), autoOn() -> bool, againState() -> 'normal' | 'disabled', lucky, equipped (bool: it went straight on)
local REVEAL_WORD = { Common = 'COMMON', Rare = 'RARE!', Epic = 'EPIC!', Legendary = 'LEGENDARY!', Mythic = 'MYTHIC!', Secret = 'SECRET!' }
function S.reveal(parent, info, ctx)
	local id = info.Shoe
	local shoe = Shoes.ById[id]
	local rar = A.rarity(shoe.Rarity)
	local W, Hh = 686, 854
	local P = A.panel(parent, { Name = 'Reveal', W = W, H = Hh, Head = 0, Foot = 0, Title = '', Body = hex('2A1470'), BodyGradient = { hex('3C1C8C'), hex('1E0E52') }, RimColor = hex('6A3AD8'), MinText = 18 })
	P.Header.Visible = false
	local root = P.Content
	local z = P.Z + 3
	A.sunburst(root, W / 2, 384, 820, z, rar.Rainbow and hex('FFD84A') or rar.Color:Lerp(WHITE, 0.3), 0.2)
	-- the rarity word on its banner, crowns either side for a Secret
	local word = REVEAL_WORD[rar.Id] or string.upper(rar.Name)
	local gold = { hex('FFF27A'), hex('FFB000') }
	local grad = rar.Rainbow and gold or { rar.Color:Lerp(WHITE, 0.55), rar.Color }
	A.text(root, word, { Name = 'Rarity', Size = 104, X = 60, Y = 40, W = W - 120, H = 130, Gradient = grad, StrokeColor = hex('3A0E5A'), StrokeW = 10, Z = z + 2, Fit = true })
	if rar.Rank >= 5 then
		A.crown(root, 58, 112, 74, z + 2)
		A.crown(root, W - 58, 112, 74, z + 2)
	end
	A.shoeArt(root, id, { X = 70, Y = 176, W = W - 140, H = 352, Z = z + 1 })
	for _, sp in { { 88, 400, 46 }, { 510, 236, 40 }, { 560, 470, 48 }, { 120, 210, 26 } } do A.sparkle(root, sp[1], sp[2], sp[3], z + 1, hex('FFF4B0')) end
	local name = A.text(root, shoe.Name, { Name = 'ShoeName', Size = 84, X = 20, Y = 528, W = W - 40, H = 104, StrokeColor = hex('2A0A48'), StrokeW = 9, Z = z + 2, Fit = true })
	local list = type(info.Shoes) == 'table' and info.Shoes or { id }
	local sub = rar.Name .. ' · ' .. chanceOf(id, ctx.lucky) .. ' · +' .. tostring(shoe.Bonus) .. '% Power'
	if #list > 1 then sub = sub .. '  ·  +' .. (#list - 1) .. ' more ' .. ((#list - 1) == 1 and 'pair' or 'pairs') end
	if info.New then sub = 'NEW!  ' .. sub end
	local equip = A.button(root, { Name = 'Equip', Text = info.Equipped and 'Equipped' or 'Equip', Tone = 'green', X = 24, Y = 636, W = 185, H = 84, TextSize = 42, Z = z + 2, OnClick = function() call(ctx.equip) end })
	local keep = A.button(root, { Name = 'Keep', Text = 'Keep', Tone = 'blue', X = 229, Y = 636, W = 200, H = 84, TextSize = 42, Z = z + 2, OnClick = function() call(ctx.keep) end })
	local again = A.button(root, { Name = 'OpenAgain', Text = 'Open Again', Tone = 'orange', X = 449, Y = 636, W = 213, H = 84, TextSize = 34, Z = z + 2, OnClick = function() call(ctx.again) end })
	local stop = A.button(root, { Name = 'StopOpening', Text = 'Stop Opening', Tone = 'dark', X = 214, Y = 736, W = 258, H = 54, TextSize = 24, Radius = 10, Studs = false, Z = z + 2, OnClick = function() call(ctx.stop) end })
	local note = A.text(root, sub, { Name = 'Note', Size = 19, X = 10, Y = 798, W = W - 20, H = 26, Color = hex('C8B8F0'), Font = A.Font.Body, StrokeW = 2, Z = z + 2, Fit = true })
	local H = { P = P, Equip = equip, Keep = keep, Again = again, Stop = stop, Name = name, Note = note }
	function H.refresh()
		if info.Equipped then A.setState(equip, 'claimed', 'Equipped') else A.setState(equip, 'normal') end
		A.setState(again, call(ctx.againState) or 'normal')
		-- Stop Opening is always reachable while Auto Open runs (and harmless otherwise: it just closes)
		local auto = call(ctx.autoOn) == true
		A.setText(stop, auto and 'Stop Opening' or 'Stop Opening')
		stop.Visible = true
	end
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 04 left: the inventory
local function equippedBadge(parent, x, y, w, h, z)
	local b = A.block(parent, { Name = 'EquippedBadge', X = x, Y = y, W = w, H = h, Fill = hex('0F2A16'), Radius = 12, Outline = 3, Z = z })
	A.stroke(A.frame(b, { Name = 'Rim', X = 3, Y = 3, W = w - 6, H = h - 6, Radius = 9, Z = z }), hex('2CE04A'), 3, true)
	A.tick(b, 32, h / 2, h * 0.86, hex('2CE04A'), z, A.Ink)
	A.text(b, 'Equipped', { Name = 'Label', Size = math.floor(h * 0.5), X = 56, Y = 0, W = w - 62, H = h, Z = z, Fit = true })
	return b
end
S.equippedBadge = equippedBadge

-- One inventory card. e: an entry from ShoeUIRules.inventory. opts: Selected, DeleteMode, Picked (in the delete
-- selection), Protected (why it can't be deleted), OnTap.
local function invCard(parent, pos, w, h, e, opts, z)
	local rar = A.rarity(e.Rank)
	local selected = opts.Selected
	-- (Oct 27, the owner's mockup: items on bright rarity tiles) the face is the rarity's colour, top-lit; the frame a
	-- darker band of it (yellow when selected)
	local tileFace = rar.Rainbow and A.rainbowSeq() or { rar.Color:Lerp(Color3.new(1, 1, 1), 0.28), rar.Color:Lerp(Color3.new(0, 0, 0), 0.12) }
	local band = selected and hex('FFD21E') or (rar.Rainbow and 'rainbow' or rar.Color:Lerp(Color3.new(0, 0, 0), 0.38))
	local card, face = A.framed(parent, { Name = 'Card_' .. e.Id, Pos = pos, W = w, H = h, Border = band, BorderW = 6, Radius = 16, Outline = 4, Piece = A.RarityPiece[rar.Id], InnerGradient = tileFace, InnerRot = rar.Rainbow and 35 or 90, Glow = selected and hex('FFC400') or nil, Z = z })
	local art = A.shoeArt(face, e.Id, { X = 14, Y = 14, W = w - 40, H = h - 84, Z = z })
	A.text(face, e.Name, { Name = 'Name', Size = 30, X = 6, Y = h - 70, W = w - 24, H = 46, Z = z, Fit = true })
	if e.On > 0 then equippedBadge(face, w - 222, -2, 206, 54, z + 1) end
	local x = 10
	if e.Count > 1 then
		A.pill(face, { Name = 'Count', X = x, Y = 8, W = 58, H = 34, Text = 'x' .. e.Count, Color = hex('2A3A52'), TextSize = 22, Z = z + 1 })
		x += 64
	end
	if e.Locked then A.padlock(face, x + 18, 26, 34, z + 1); x += 40 end
	if e.Favorite then A.icon(face, 'Favorite', { S = 38, X = x + 18, Y = 26, Z = z + 1 }) end
	if opts.DeleteMode then
		if opts.Protected then
			A.frame(face, { Name = 'Shade', X = 0, Y = 0, W = w - 12, H = h - 12, Fill = Color3.new(0, 0, 0), Transparency = 0.5, Radius = 10, Z = z + 2 })
			local why = ({ equipped = 'Equipped', lock = 'Locked', favorite = 'Favourite' })[opts.Protected] or 'Kept'
			A.pill(face, { Name = 'Kept', X = (w - 12) / 2 - 80, Y = (h - 12) / 2 - 22, W = 160, H = 44, Text = why, Color = hex('3A4A60'), TextSize = 24, Z = z + 3 })
		elseif opts.Picked then
			A.frame(face, { Name = 'Shade', X = 0, Y = 0, W = w - 12, H = h - 12, Fill = hex('E00A1E'), Transparency = 0.72, Radius = 10, Z = z + 2 })
			A.check(face, w - 46, 32, 46, z + 3)
		end
	end
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = card })
	hit.Activated:Connect(function() call(opts.OnTap) end)
	return card, art
end

-- ctx: rack() -> rack, slots() -> n, equipBest(), lock(id), delete(ids) (after the confirmed review), detail(id),
-- tab(name), close(), confirmDelete(review, onYes) (shows the review; onYes when confirmed)
function S.inventory(parent, ctx)
	local W, Hh = 1012, 839
	local P = A.panel(parent, { Name = 'Inventory', W = W, H = Hh, Head = 95, Foot = 124, Title = 'SHOE INVENTORY', TitleSize = 50, TitleX = 140, TitleW = 760, Icon = 'Sneaker', IconBox = { 10, -15, 118, 110 }, Close = function() call(ctx.close) end, CloseBox = { 918, 13, 84, 77 }, MinText = 20 })
	local z = P.Z + 3
	local state = { Query = '', Sort = 'Name', Filter = 'All', Selected = nil, DeleteMode = false, Picked = {} }
	local H = { P = P, State = state }
	local sortBtn, filterBtn
	A.search(P.Content, { Name = 'Search', X = 20, Y = 20, W = 328, H = 65, Placeholder = 'Search...', TextSize = 28, Z = z, OnChanged = function(t) state.Query = t; H.refresh() end })
	sortBtn = A.dropdown(P.Content, { Name = 'Sort', X = 360, Y = 20, W = 230, H = 65, Text = 'Sort: Name', TextSize = 26, Z = z, OnClick = function()
		local i = table.find(U.Sorts, state.Sort) or 1
		state.Sort = U.Sorts[i % #U.Sorts + 1]
		H.refresh()
	end })
	filterBtn = A.dropdown(P.Content, { Name = 'Filter', X = 602, Y = 20, W = 218, H = 65, Text = 'Filter: All', TextSize = 26, Z = z, OnClick = function()
		local i = table.find(U.Filters, state.Filter) or 1
		state.Filter = U.Filters[i % #U.Filters + 1]
		H.refresh()
	end })
	local capWell = A.field(P.Content, { Name = 'Capacity', X = 832, Y = 20, W = 165, H = 65, Z = z })
	local capText = A.text(capWell, '', { Name = 'Text', Size = 30, X = 0, Y = 0, W = 165, H = 65, Z = z, Fit = true })
	-- the grid scrolls on its own (the toolbar and the footer stay put)
	local GRID_Y = 98
	local grid = Kit.new('ScrollingFrame', { Name = 'Grid', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(8, GRID_Y), Size = px(W - 16, Hh - 95 - 124 - GRID_Y + 8), CanvasSize = px(0, 0), ScrollBarThickness = 8, ScrollBarImageColor3 = hex('7FD8FF'), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = z, Parent = P.Content })
	local empty = A.text(P.Content, '', { Name = 'Empty', Size = 28, X = 40, Y = 260, W = W - 80, H = 120, Wrap = true, Color = hex('B8D4F0'), Z = z })
	P.OnFit = function(visH)
		grid.Size = px(W - 16, math.max(120, visH - 95 - 124 - GRID_Y + 8))
	end
	-- the footer: Equip Best / Lock / Delete, or in Delete mode: Cancel / the count / Review
	local foot = P.Foot
	local equipBest = A.button(foot, { Name = 'EquipBest', Text = 'Equip Best', Tone = 'green', X = 20, Y = 12, W = 358, H = 90, TextSize = 38, Icon = 'Sneaker', IconSize = 72, Z = z, OnClick = function() call(ctx.equipBest) end })
	local lock = A.button(foot, { Name = 'Lock', Text = 'Lock', Tone = 'blue', X = 390, Y = 12, W = 290, H = 90, TextSize = 38, Glyph = function(p, x, y, s, zz) return A.padlock(p, x, y, s * 0.82, zz) end, IconSize = 66, Gap = 40, Z = z, OnClick = function()
		if state.Selected then call(ctx.lock, state.Selected) end
	end })
	local delete = A.button(foot, { Name = 'Delete', Text = 'Delete', Tone = 'red', X = 695, Y = 12, W = 300, H = 90, TextSize = 38, Glyph = function(p, x, y, s, zz) return A.trash(p, x, y, s * 0.8, zz) end, IconSize = 66, Gap = 40, Z = z, OnClick = function()
		state.DeleteMode, state.Picked = true, {}
		H.refresh()
	end })
	local cancel = A.button(foot, { Name = 'CancelDelete', Text = 'Cancel', Tone = 'grey', X = 20, Y = 12, W = 358, H = 90, TextSize = 38, Z = z, OnClick = function()
		state.DeleteMode, state.Picked = false, {}
		H.refresh()
	end })
	local pickLine = A.text(foot, '', { Name = 'PickLine', Size = 24, X = 390, Y = 12, W = 290, H = 90, Wrap = true, Color = hex('FFD0D6'), Font = A.Font.Body, Z = z })
	local review = A.button(foot, { Name = 'Review', Text = 'Review', Tone = 'red', X = 695, Y = 12, W = 300, H = 90, TextSize = 38, Glyph = function(p, x, y, s, zz) return A.trash(p, x, y, s * 0.8, zz) end, IconSize = 66, Gap = 30, Z = z, OnClick = function()
		local ids = {}
		for id in state.Picked do table.insert(ids, id) end
		local rack = call(ctx.rack)
		local rv = U.deleteReview(rack, ids)
		call(ctx.confirmDelete, rv, function()
			call(ctx.delete, rv.Delete)
			state.DeleteMode, state.Picked = false, {}
			H.refresh()
		end)
	end })
	H.EquipBest, H.Lock, H.Delete, H.Review, H.Cancel, H.Grid = equipBest, lock, delete, review, cancel, grid
	function H.refresh()
		local rack = call(ctx.rack)
		local list = U.inventory(rack, state)
		local n, max = U.capacity(rack)
		capText.Text = n .. ' / ' .. max
		capText.TextColor3 = n >= max and hex('FF6A6A') or WHITE
		A.setText(sortBtn, 'Sort: ' .. state.Sort)
		A.setText(filterBtn, 'Filter: ' .. state.Filter)
		for _, c in grid:GetChildren() do
			if c:IsA('GuiObject') then c:Destroy() end
		end
		local cw, ch, gx, gy = 315, 250, 328.5, 260
		for i, e in list do
			local col, row = (i - 1) % 3, (i - 1) // 3
			local _, why = U.canDelete(rack, e.Id)
			invCard(grid, px(12 + col * gx, 12 + row * gy), cw, ch, e, {
				Selected = not state.DeleteMode and state.Selected == e.Id, DeleteMode = state.DeleteMode, Picked = state.Picked[e.Id] == true, Protected = why,
				OnTap = function()
					if state.DeleteMode then
						if not why then state.Picked[e.Id] = not state.Picked[e.Id] or nil end
						H.refresh()
					elseif state.Selected == e.Id then
						call(ctx.detail, e.Id)
					else
						state.Selected = e.Id
						H.refresh()
					end
				end,
			}, z)
		end
		grid.CanvasSize = px(0, math.max(1, (#list + 2) // 3) * gy + 20)
		empty.Text = #list == 0 and (n == 0 and 'No shoes yet. Open a shoe box in the hall to get your first pair!' or 'No pairs match.') or ''
		local picked = 0
		for _ in state.Picked do picked += 1 end
		equipBest.Visible, lock.Visible, delete.Visible = not state.DeleteMode, not state.DeleteMode, not state.DeleteMode
		cancel.Visible, pickLine.Visible, review.Visible = state.DeleteMode, state.DeleteMode, state.DeleteMode
		pickLine.Text = picked == 0 and 'Tap pairs to delete. Locked, favourite and equipped pairs are kept.' or (picked .. (picked == 1 and ' pair' or ' pairs') .. ' picked')
		A.setText(review, picked > 0 and ('Review ' .. picked) or 'Review')
		A.setState(review, picked > 0 and 'normal' or 'disabled')
		local sel = state.Selected and rack.Owned[state.Selected] and state.Selected
		state.Selected = sel or nil
		A.setState(lock, sel and 'normal' or 'disabled', sel and (type(rack.Locked) == 'table' and rack.Locked[sel] and 'Unlock' or 'Lock') or 'Lock')
		A.setState(equipBest, n > 0 and 'normal' or 'disabled')
		A.setState(delete, n > 0 and 'normal' or 'disabled')
	end
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 04 right: the pair's detail
local function tabsRow(parent, x, y, sel, ctx, z)
	local items = {
		{ Id = 'Shoes', Text = 'Shoes', Icon = 'Sneaker', IconSize = 52 },
		{ Id = 'Boxes', Text = 'Boxes', Icon = 'ShoeBox', IconSize = 52 },
		{ Id = 'Collection', Text = 'Collection', Glyph = function(p, gx, gy, s, zz) return A.book(p, gx, gy, s * 0.86, zz) end, IconSize = 52 },
	}
	local holder, set, buttons = A.tabs(parent, { Name = 'Tabs', X = x, Y = y, W = 672, H = 82, Gap = 12, Items = items, Selected = sel, SelectedTone = 'blue', IdleTone = 'dark', IdleBorder = hex('22405E'), TextSize = 28, Radius = 14, Studs = false, Z = z, OnSelect = function(id) call(ctx.tab, id) end })
	return holder, set, buttons
end
S.tabsRow = tabsRow

-- ctx: rack(), equip(id) (asks for the Equip confirmation), unequip(id), favourite(id), lock(id), back(), tab(name), close()
function S.detail(parent, id, ctx)
	local W, Hh = 706, 839
	local shoe = Shoes.ById[id]
	local rar = A.rarity(shoe.Rarity)
	local fam = A.Family[shoe.Box]
	local P = A.panel(parent, { Name = 'Detail', W = W, H = Hh, Head = 95, Foot = 189, Title = string.upper(shoe.Name), TitleSize = 60, TitleX = 150, TitleW = 455, HeadTone = 'purple', Icon = 'Sneaker', IconBox = { 22, -15, 100, 110 }, Close = function() call(ctx.close) end, CloseBox = { 615, 13, 80, 77 }, RimColor = hex('7A3AD8'), MinText = 20 })
	local z = P.Z + 3
	local show = A.framed(P.Content, { Name = 'Showcase', Pos = P.c(18, 115), W = 670, H = 528, Border = hex('A84CF4'), BorderW = 6, InnerGradient = { hex('E046F4'), hex('6A1CC0') }, Inner = hex('9A2ADC'), Radius = 18, Outline = 4, Z = z })
	local face = show:FindFirstChild('Face')
	local st = Kit.studs(face, { Pitch = 26, Width = 658, Height = 516, Shade = 0.9, ZIndex = z })
	if st and st:IsA('ImageLabel') then A.corner(st, 14) end
	A.sunburst(face, 340, 200, 640, z, WHITE, 0.16)
	A.shoeArt(face, id, { X = 100, Y = 20, W = 520, H = 345, Z = z })
	for _, sp in { { 92, 220, 54 }, { 538, 92, 46 }, { 560, 296, 54 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
	local power = A.pill(face, { Name = 'Power', X = 12, Y = 12, W = 196, H = 42, Text = '+' .. shoe.Bonus .. '% Power', Color = hex('2A0E4E'), TextColor = hex('FFE04A'), TextSize = 24, Z = z })
	A.rarityPill(face, shoe.Rarity, { X = 111, Y = 384, W = 170, H = 52, TextSize = 28, Z = z, Outline = 4 })
	local famPill = A.pill(face, { Name = 'Collection', X = 293, Y = 384, W = 270, H = 52, Text = (fam and fam.Name or A.familyName(shoe.Box)) .. ' Collection', Color = hex('1A1430'), TextColor = hex('FFD21E'), TextSize = 24, Outline = 4, Glyph = function(p, x, y, s, zz) return A.crown(p, x, y, s, zz) end, Z = z })
	A.stroke(A.frame(famPill, { Name = 'Rim', X = 2, Y = 2, W = 266, H = 48, Radius = 14, Z = z }), hex('FFC81E'), 3, true)
	local equipBar = A.button(face, { Name = 'EquipBar', Text = 'EQUIPPED', Tone = 'green', X = 46, Y = 449, W = 570, H = 62, TextSize = 44, Glyph = function(p, x, y, s, zz) return A.tick(p, x, y, s, WHITE, zz, A.Ink) end, IconSize = 58, Gap = 22, Z = z, OnClick = function() call(ctx.equip, id) end })
	local foot = P.Foot
	local unequip = A.button(foot, { Name = 'Unequip', Text = 'Unequip', Tone = 'blue', X = 18, Y = 10, W = 184, H = 70, TextSize = 30, Icon = 'Sneaker', IconSize = 50, Gap = 6, Z = z, OnClick = function() call(ctx.unequip, id) end })
	local fav = A.button(foot, { Name = 'Favourite', Text = 'Favourite', Tone = 'yellow', X = 215, Y = 10, W = 173, H = 70, TextSize = 26, Icon = 'Favorite', IconSize = 50, Gap = 4, Z = z, OnClick = function() call(ctx.favourite, id) end })
	local lock = A.button(foot, { Name = 'Lock', Text = 'Lock', Tone = 'blue', X = 400, Y = 10, W = 138, H = 70, TextSize = 30, Glyph = function(p, x, y, s, zz) return A.padlock(p, x, y, s * 0.78, zz) end, IconSize = 50, Gap = 8, Z = z, OnClick = function() call(ctx.lock, id) end })
	local back = A.button(foot, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 548, Y = 10, W = 142, H = 70, TextSize = 30, Glyph = function(p, x, y, s, zz) return A.arrow(p, x, y, s * 0.8, zz) end, IconSize = 46, Gap = 8, Z = z, OnClick = function() call(ctx.back) end })
	tabsRow(foot, 18, 95, 'Shoes', ctx, z)
	local H = { P = P, Id = id, EquipBar = equipBar, Unequip = unequip, Favourite = fav, Lock = lock, Back = back }
	function H.refresh()
		local rack = call(ctx.rack)
		local owned = ShoeRules.copies(rack, id)
		local on = ShoeRules.equippedCount(rack, id)
		if on > 0 then
			A.setState(equipBar, on >= owned and 'claimed' or 'normal', on >= owned and 'EQUIPPED' or ('EQUIP ANOTHER (' .. on .. '/' .. owned .. ' on)'))
		else
			A.setState(equipBar, owned > 0 and 'normal' or 'disabled', 'EQUIP')
		end
		A.setState(unequip, on > 0 and 'normal' or 'disabled')
		local isFav = type(rack.Favorites) == 'table' and rack.Favorites[id] == true
		local isLock = type(rack.Locked) == 'table' and rack.Locked[id] == true
		A.setState(fav, owned > 0 and (isFav and 'selected' or 'normal') or 'disabled', isFav and 'Favourite' or 'Favourite')
		A.setState(lock, owned > 0 and (isLock and 'selected' or 'normal') or 'disabled', isLock and 'Locked' or 'Lock')
		power.Label.Text = '+' .. shoe.Bonus .. '% Power' .. (owned > 1 and ('  x' .. owned) or '')
	end
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 05 left: the collection
-- ctx: rack(), close(), open(id) (a discovered design's detail)
function S.collection(parent, ctx)
	local W, Hh = 982, 748
	local P = A.panel(parent, { Name = 'Collection', W = W, H = Hh, Head = 100, Foot = 40, Title = 'Collection', TitleSize = 60, TitleX = 142, TitleW = 380, Icon = 'ShoeBox', IconBox = { 10, -4, 120, 104 }, Close = function() call(ctx.close) end, CloseBox = { 887, 13, 83, 80 }, MinText = 18 })
	local z = P.Z + 3
	local count = A.text(P.Header, '', { Name = 'Designs', Size = 38, X = 520, Y = 0, W = 355, H = 100, Align = 'Right', Gradient = { hex('FFF27A'), hex('FFB000') }, Z = P.Z + 1, Fit = true })
	local family
	local grid = Kit.new('ScrollingFrame', { Name = 'Grid', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(8, 72), Size = px(W - 16, Hh - 100 - 40 - 72), CanvasSize = px(0, 0), ScrollBarThickness = 8, ScrollBarImageColor3 = hex('7FD8FF'), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = z, Parent = P.Content })
	P.OnFit = function(visH) grid.Size = px(W - 16, math.max(120, visH - 100 - 40 - 72)) end
	local footNote = A.text(P.Foot, '', { Name = 'Note', Size = 18, X = 0, Y = 0, W = W, H = 34, Color = hex('8FB4D8'), Font = A.Font.Body, StrokeW = 2, Z = z })
	local H = { P = P }
	A.tabs(P.Content, { Name = 'Families', X = 17, Y = 13, W = 943, H = 52, Gap = 8, Items = { { Id = 'All', Text = 'All' }, { Id = 'Street', Text = 'Street' }, { Id = 'Graffiti', Text = 'Graffiti' }, { Id = 'Chrome', Text = 'Chrome' }, { Id = 'Crown', Text = 'Crown' } },
		Selected = 'All', SelectedTone = 'blue', IdleTone = 'dark', IdleBorder = hex('2EA8D8'), TextSize = 28, Radius = 10, Studs = false, Z = z, OnSelect = function(id)
			family = id ~= 'All' and id or nil
			H.refresh()
		end })
	function H.refresh()
		local rack = call(ctx.rack)
		for _, c in grid:GetChildren() do
			if c:IsA('GuiObject') then c:Destroy() end
		end
		local list = U.collection(rack, family)
		local cw, ch, gx, gy = 150, 125, 158, 133
		for i, e in list do
			local col, row = (i - 1) % 6, (i - 1) // 6
			local rar = A.rarity(e.Rank)
			local card, face = A.framed(grid, { Name = 'Design_' .. e.Id, Pos = px(9 + col * gx, 8 + row * gy), W = cw, H = ch, Border = e.Discovered and (rar.Rainbow and 'rainbow' or hex('2EC8F4')) or hex('3A4A60'), BorderW = 4, Radius = 12, Outline = 3, Z = z })
			A.shoeArt(face, e.Id, { X = 6, Y = 2, W = cw - 20, H = 84, Z = z, Locked = not e.Discovered })
			A.text(face, e.Discovered and e.Name or '???', { Name = 'Name', Size = 18, X = 2, Y = ch - 38, W = cw - 12, H = 26, Z = z, Fit = true, MinSize = 11, Color = e.Discovered and WHITE or hex('8A98AC') })
			if e.Count > 1 then A.pill(face, { Name = 'Count', X = cw - 50, Y = 2, W = 40, H = 24, Text = 'x' .. e.Count, Color = hex('2A3A52'), TextSize = 16, Z = z + 1, Outline = 2 }) end
			if e.Discovered and e.Count == 0 then A.pill(face, { Name = 'Gone', X = 2, Y = 2, W = 54, H = 22, Text = 'seen', Color = hex('3A4A60'), TextSize = 14, Z = z + 1, Outline = 2 }) end
			local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = card })
			hit.Activated:Connect(function() if e.Count > 0 then call(ctx.open, e.Id) end end)
		end
		grid.CanvasSize = px(0, math.max(1, (#list + 5) // 6) * gy + 12)
		local found, total = U.discoveredCount(rack)
		count.Text = found .. ' / ' .. total .. ' Designs'
		local pairs_ = ShoeRules.count(rack)
		footNote.Text = 'Discovered ' .. found .. ' of ' .. total .. ' designs  ·  ' .. pairs_ .. (pairs_ == 1 and ' pair owned' or ' pairs owned')
	end
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 06: gift a player
-- ctx: players() -> { { UserId, Name, User } } (the others in this server), item = { Key, Title, Shoe | Box }, me (UserId),
-- confirm(target) (only after the review), back(), close()
function S.gift(parent, ctx)
	local W, Hh = 746, 461
	local P = A.panel(parent, { Name = 'Gift', W = W, H = Hh, Head = 78, Foot = 0, Title = 'GIFT A PLAYER', TitleSize = 44, TitleX = 110, TitleW = 540, IconNode = function(h, x, y, s, zz) A.icon(h, 'Rewards', { S = s, X = x, Y = y, Z = zz }) end, IconBox = { 22, 4, 76, 76 }, Close = function() call(ctx.close) end, CloseBox = { 670, 11, 62, 60 }, MinText = 18 })
	local z = P.Z + 3
	local item = ctx.item or {}
	local target = ctx.target
	local query = ''
	local H = { P = P, Reviewing = ctx.review == true }
	-- the list side
	local listSide = A.frame(P.Content, { Name = 'Pick', X = 0, Y = 0, W = 420, H = Hh - 78, Z = z })
	A.search(listSide, { Name = 'Search', X = 20, Y = 10, W = 385, H = 50, Placeholder = 'Search player...', TextSize = 22, Z = z, OnChanged = function(t) query = string.lower(t); H.refresh() end })
	local rows = Kit.new('ScrollingFrame', { Name = 'Players', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(14, 68), Size = px(398, 232), CanvasSize = px(0, 0), ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = z, Parent = listSide })
	local back = A.button(P.Content, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 20, Y = 308, W = 175, H = 58, TextSize = 30, Glyph = function(p, x, y, s, zz) return A.arrow(p, x, y, s * 0.8, zz) end, IconSize = 40, Gap = 14, Z = z, OnClick = function()
		if H.Reviewing then H.Reviewing = false; H.refresh() else call(ctx.back) end
	end })
	-- the item card and Continue
	local card, face = A.framed(P.Content, { Name = 'Item', X = 418, Y = 8, W = 312, H = 252, Border = hex('E04CF0'), BorderW = 6, InnerGradient = { hex('A23AF0'), hex('4A1490') }, Inner = hex('6A1CC0'), Radius = 16, Outline = 4, Z = z })
	A.sunburst(face, 150, 140, 300, z, WHITE, 0.14)
	A.text(face, item.Title or 'Pick an item', { Name = 'Title', Size = 28, X = 6, Y = 4, W = 288, H = 40, Z = z, Fit = true })
	if item.Shoe then A.shoeArt(face, item.Shoe, { X = 20, Y = 44, W = 260, H = 180, Z = z })
	elseif item.Box then A.boxArt(face, item.Box, { X = 40, Y = 44, W = 220, H = 180, Z = z })
	else A.icon(face, 'Rewards', { S = 150, X = 150, Y = 130, Z = z }) end
	for _, sp in { { 30, 200, 26 }, { 270, 60, 22 }, { 262, 210, 26 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
	local cont = A.button(P.Content, { Name = 'Continue', Text = 'Continue', Tone = 'green', X = 418, Y = 273, W = 312, H = 82, TextSize = 36, Z = z, OnClick = function()
		if not target then return end
		if ctx.pick then call(ctx.pick, target) return end -- (no item yet: the Store's old flow picks it next)
		if not H.Reviewing then
			H.Reviewing = true
			H.refresh()
		else
			local rv = U.giftReview(Products, item.Key, target, ctx.me)
			if rv.Ok then call(ctx.confirm, target) end
		end
	end })
	-- the review (replaces the list once a player is picked and Continue pressed: never sent without it)
	local reviewBox = A.block(P.Content, { Name = 'Review', X = 20, Y = 10, W = 385, H = 290, Fill = hex('122236'), Radius = 14, Outline = 4, Z = z })
	A.stroke(A.frame(reviewBox, { Name = 'Rim', X = 3, Y = 3, W = 379, H = 284, Radius = 11, Z = z }), hex('2EC8F4'), 3, true)
	local rvTitle = A.text(reviewBox, 'Send this gift?', { Name = 'Title', Size = 30, X = 10, Y = 10, W = 365, H = 40, Z = z, Fit = true })
	local rvBody = A.text(reviewBox, '', { Name = 'Body', Size = 22, X = 16, Y = 56, W = 353, H = 160, Wrap = true, Font = A.Font.Body, Color = hex('D8E6F4'), StrokeW = 2, Z = z })
	local rvPrice = A.text(reviewBox, '', { Name = 'Price', Size = 34, X = 10, Y = 222, W = 365, H = 50, Gradient = { hex('E8FF4A'), hex('5EE83A') }, Z = z, Fit = true })
	H.Continue, H.Back, H.Review = cont, back, reviewBox
	function H.refresh()
		for _, c in rows:GetChildren() do
			if c:IsA('GuiObject') then c:Destroy() end
		end
		local list = call(ctx.players) or {}
		local y = 0
		for _, p in list do
			local name = tostring(p.Name)
			if query == '' or string.find(string.lower(name), query, 1, true) or string.find(string.lower(tostring(p.User or '')), query, 1, true) then
				local on = target and target.UserId == p.UserId
				local row = A.block(rows, { Name = 'Player_' .. tostring(p.UserId), X = 6, Y = y + 4, W = 385, H = 72, Fill = on and hex('0A8CF0') or hex('16222F'), Radius = 12, Outline = 3, Z = z })
				if on then A.stroke(A.frame(row, { Name = 'Rim', X = 2, Y = 2, W = 381, H = 68, Radius = 10, Z = z }), hex('5EF2FE'), 3, true) end
				local face_ = Kit.new('ImageLabel', { Name = 'Avatar', BackgroundColor3 = hex('3A5070'), BorderSizePixel = 0, Image = 'rbxthumb://type=AvatarHeadShot&id=' .. tostring(p.UserId) .. '&w=150&h=150', Position = px(12, 5), Size = px(62, 62), ZIndex = z, Parent = row })
				A.corner(face_, UDim.new(0.5, 0))
				A.stroke(face_, A.Ink, 3, true)
				A.text(row, name, { Name = 'Name', Size = 22, X = 88, Y = 6, W = 230, H = 30, Align = 'Left', Z = z, Fit = true })
				A.text(row, '@' .. tostring(p.User or name), { Name = 'User', Size = 18, X = 88, Y = 36, W = 230, H = 26, Align = 'Left', Color = on and hex('D8F0FF') or hex('8C9AAE'), Font = A.Font.Body, StrokeW = 2, Z = z, Fit = true })
				A.radio(row, 348, 36, 32, on, z)
				local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = row })
				hit.Activated:Connect(function()
					target = { UserId = p.UserId, Name = name }
					H.refresh()
				end)
				y += 76
			end
		end
		if #list == 0 then
			A.text(rows, 'No one else is here yet. Invite a friend!', { Name = 'None', Size = 22, X = 10, Y = 20, W = 370, H = 90, Wrap = true, Font = A.Font.Body, Color = hex('B8D4F0'), Z = z })
		end
		rows.CanvasSize = px(0, y + 8)
		local rv = U.giftReview(Products, item.Key, target, ctx.me)
		listSide.Visible = not H.Reviewing
		reviewBox.Visible = H.Reviewing == true
		if H.Reviewing then
			rvTitle.Text = 'Send this gift?'
			local whyText = ({ notgiftable = 'This item can not be gifted yet.', soon = 'This item is coming soon.', unknown = 'Pick an item first.', nobody = 'Pick a player first.', self = 'Pick someone else.' })[rv.Why or ''] or ''
			rvBody.Text = (rv.Title or 'This item') .. ' for ' .. (target and target.Name or '?') .. '. You pay; they get it right away. Roblox asks you to confirm the purchase.' .. (whyText ~= '' and ('\n' .. whyText) or '')
			rvPrice.Text = rv.Price and RobuxText.fmt(rv.Price) or ''
			A.setText(cont, 'Confirm')
			A.setState(cont, rv.Ok and 'normal' or 'disabled', 'Confirm')
		else
			A.setState(cont, target and 'normal' or 'disabled', 'Continue')
		end
	end
	H.refresh()
	return H
end

---------------------------------------------------------------------------------------------- 06: confirmations
-- the purple "Selected Pair" card
local function pairCard(parent, x, y, w, h, id, caption, z, box)
	local card, face = A.framed(parent, { Name = 'SelectedPair', X = x, Y = y, W = w, H = h, Border = hex('E04CF0'), BorderW = 6, InnerGradient = { hex('B23AF0'), hex('4A1490') }, Inner = hex('6A1CC0'), Radius = 16, Outline = 4, Z = z })
	A.sunburst(face, (w - 12) / 2, h * 0.42, w * 1.1, z, WHITE, 0.12)
	A.text(face, box and A.boxName(id) or A.shoeName(id), { Name = 'Name', Size = 28, X = 6, Y = 6, W = w - 24, H = 40, Z = z, Fit = true })
	if box then A.boxArt(face, id, { X = 20, Y = 50, W = w - 52, H = h - 128, Z = z }) else A.shoeArt(face, id, { X = 8, Y = 46, W = w - 28, H = h - 120, Z = z }) end
	A.sparkle(face, 30, 70, 26, z)
	A.sparkle(face, w - 50, h - 100, 22, z)
	local pill = A.pill(face, { Name = 'Caption', X = 20, Y = h - 72, W = w - 52, H = 44, Text = caption, Color = hex('3A1468'), TextSize = 24, Z = z })
	return card, pill
end
S.pairCard = pairCard

-- the orange Inventory Full box (388 x 147): Manage Shoes / Back
function S.fullBox(parent, x, y, ctx, z)
	local b = A.block(parent, { Name = 'InventoryFull', X = x, Y = y, W = 388, H = 147, Fill = hex('16202E'), Radius = 14, Outline = 4, Z = z })
	A.stroke(A.frame(b, { Name = 'Rim', X = 3, Y = 3, W = 382, H = 141, Radius = 11, Z = z }), hex('FFA21E'), 4, true)
	local warn = A.frame(b, { Name = 'Warn', Pos = px(42, 46), Anchor = Vector2.new(0.5, 0.5), W = 50, H = 50, Fill = hex('FFC81E'), Radius = UDim.new(0.5, 0), Z = z })
	A.stroke(warn, A.Ink, 3, true)
	A.text(warn, '!', { Size = 36, X = 0, Y = 0, W = 50, H = 50, Color = A.Ink, Stroke = false, Z = z })
	A.text(b, 'Inventory Full', { Name = 'Title', Size = 26, X = 80, Y = 8, W = 290, H = 34, Align = 'Left', Z = z })
	local n, max = ShoeRules.count(call(ctx.rack) or { Owned = {} }), ShoeRules.MaxOwned
	A.text(b, 'Your shoe inventory is full (' .. n .. ' / ' .. max .. ').\nManage your shoes to continue.', { Name = 'Body', Size = 16, X = 80, Y = 40, W = 300, H = 44, Align = 'Left', Wrap = true, Font = A.Font.Body, StrokeW = 2, Z = z })
	A.button(b, { Name = 'ManageShoes', Text = 'Manage Shoes', Tone = 'blue', X = 20, Y = 84, W = 198, H = 50, TextSize = 24, Z = z, OnClick = function() call(ctx.manage) end })
	A.button(b, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 230, Y = 84, W = 144, H = 50, TextSize = 26, Z = z, OnClick = function() call(ctx.back) end })
	return b
end

-- the green "Bundle received!" box (440 x 322): its pairs, View Shoes / Done
function S.receivedBox(parent, x, y, ids, ctx, z)
	local b = A.block(parent, { Name = 'BundleReceived', X = x, Y = y, W = 440, H = 322, Gradient = { hex('1E5A26'), hex('0E1E16') }, Radius = 16, Outline = 4, Z = z })
	A.stroke(A.frame(b, { Name = 'Rim', X = 3, Y = 3, W = 434, H = 316, Radius = 13, Z = z }), hex('2CE04A'), 5, true)
	local c = A.frame(b, { Name = 'Badge', Pos = px(72, 38), Anchor = Vector2.new(0.5, 0.5), W = 56, H = 56, Fill = WHITE, Radius = UDim.new(0.5, 0), Z = z })
	A.stroke(c, A.Ink, 3, true)
	A.tick(c, 28, 29, 44, hex('22C83A'), z, A.Ink)
	A.text(b, ctx.title or 'Bundle received!', { Name = 'Title', Size = 34, X = 110, Y = 12, W = 320, H = 50, Align = 'Left', Z = z, Fit = true })
	A.text(b, 'Your new shoes have been added\nto your inventory!', { Name = 'Body', Size = 18, X = 10, Y = 62, W = 420, H = 46, Wrap = true, Font = A.Font.Body, StrokeW = 2, Z = z })
	local xs = { 12, 147, 292 }
	for i, id in ids do
		if xs[i] then
			local _, face = A.framed(b, { Name = 'Pair_' .. id, X = xs[i], Y = 110, W = i == 1 and 126 or 135, H = 124, Border = hex('2A3A52'), BorderW = 3, Radius = 12, Outline = 3, Z = z })
			A.shoeArt(face, id, { X = 4, Y = 4, W = (i == 1 and 126 or 135) - 14, H = 80, Z = z })
			A.text(face, A.shoeName(id), { Name = 'Name', Size = 18, X = 2, Y = 88, W = (i == 1 and 126 or 135) - 10, H = 26, Z = z, Fit = true, MinSize = 11 })
		end
	end
	A.button(b, { Name = 'ViewShoes', Text = 'View Shoes', Tone = 'green', X = 12, Y = 247, W = 223, H = 62, TextSize = 32, Z = z, OnClick = function() call(ctx.viewShoes) end })
	A.button(b, { Name = 'Done', Text = 'Done', Tone = 'grey', X = 247, Y = 247, W = 180, H = 62, TextSize = 32, Z = z, OnClick = function() call(ctx.done) end })
	return b
end

-- Equip this pair? (the CONFIRMATION panel). ctx: rack(), slots(), yes(), no(), close(); opts.showcase: draw the
-- Inventory Full box in its artboard slot (the side-by-side shot), else the slot shows what the equip changes.
function S.confirm(parent, id, ctx, opts)
	opts = opts or {}
	local W, Hh = 730, 415
	local P = A.panel(parent, { Name = 'Confirm', W = W, H = Hh, Head = 70, Foot = 0, Title = 'CONFIRMATION', TitleSize = 40, TitleX = 123, TitleW = 500, Icon = 'Sneaker', IconBox = { 20, -6, 86, 76 }, Close = function() call(ctx.no) end, CloseBox = { 658, 9, 62, 54 }, MinText = 16 })
	local z = P.Z + 3
	pairCard(P.Content, 16, 14, 302, 318, id, 'Selected Pair', z)
	local box = A.block(P.Content, { Name = 'Question', X = 330, Y = 10, W = 388, H = 167, Fill = hex('16202E'), Radius = 14, Outline = 4, Z = z })
	A.stroke(A.frame(box, { Name = 'Rim', X = 3, Y = 3, W = 382, H = 161, Radius = 11, Z = z }), hex('2E3E52'), 2, true)
	local rack = call(ctx.rack) or { Owned = {}, Equipped = {} }
	local plan = U.equipPlan(rack, id, call(ctx.slots))
	A.text(box, 'Equip this pair?', { Name = 'Title', Size = 32, X = 8, Y = 6, W = 372, H = 42, Z = z, Fit = true })
	local line = plan.Kind == 'swap' and ('This swaps ' .. A.shoeName(plan.Out) .. ' for ' .. A.shoeName(id) .. '.') or ('This will equip ' .. A.shoeName(id) .. '\nas your active pair.')
	A.text(box, line, { Name = 'Body', Size = 18, X = 10, Y = 48, W = 368, H = 46, Wrap = true, Font = A.Font.Body, StrokeW = 2, Z = z })
	local yes = A.button(box, { Name = 'Equip', Text = 'Equip', Tone = 'green', X = 10, Y = 104, W = 203, H = 53, TextSize = 32, Z = z, OnClick = function() call(ctx.yes, plan) end })
	A.button(box, { Name = 'Cancel', Text = 'Cancel', Tone = 'grey', X = 223, Y = 104, W = 157, H = 53, TextSize = 30, Z = z, OnClick = function() call(ctx.no) end })
	if plan.Kind == 'none' then A.setState(yes, 'disabled') end
	if opts.showcase then
		S.fullBox(P.Content, 330, 187, ctx, z)
	else
		local info = A.block(P.Content, { Name = 'Slots', X = 330, Y = 187, W = 388, H = 147, Fill = hex('16202E'), Radius = 14, Outline = 4, Z = z })
		A.stroke(A.frame(info, { Name = 'Rim', X = 3, Y = 3, W = 382, H = 141, Radius = 11, Z = z }), hex('2EA8F4'), 4, true)
		A.info(info, 42, 46, 46, z)
		local slots = ShoeRules.slotsOf(call(ctx.slots))
		local shoe = Shoes.ById[id]
		A.text(info, '+' .. shoe.Bonus .. '% Power', { Name = 'Title', Size = 26, X = 80, Y = 8, W = 290, H = 34, Align = 'Left', Gradient = { hex('FFF27A'), hex('FFB000') }, Z = z })
		A.text(info, 'Pairs on: ' .. #rack.Equipped .. ' / ' .. slots .. '. Your best pair is worn, the others follow you. Unequip keeps the pair.', { Name = 'Body', Size = 16, X = 80, Y = 42, W = 296, H = 96, Align = 'Left', YAlign = 'Top', Wrap = true, Font = A.Font.Body, StrokeW = 2, Z = z })
	end
	return { P = P, Yes = yes, Plan = plan }
end

-- the delete review: what goes, what is kept, the Cash back. ctx: yes(), no()
function S.deleteReview(parent, rv, ctx)
	local W, Hh = 730, 415
	local P = A.panel(parent, { Name = 'DeleteReview', W = W, H = Hh, Head = 70, Foot = 0, HeadTone = 'red', Title = 'DELETE PAIRS?', TitleSize = 40, TitleX = 110, TitleW = 520, IconNode = function(h, x, y, s, zz) A.trash(h, x, y, s * 0.8, zz) end, IconBox = { 20, 0, 76, 70 }, Close = function() call(ctx.no) end, CloseBox = { 658, 9, 62, 54 }, MinText = 16 })
	local z = P.Z + 3
	local strip = Kit.new('ScrollingFrame', { Name = 'Pairs', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(16, 12), Size = px(W - 32, 150), CanvasSize = px(math.max(1, #rv.Delete) * 138, 0), ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = z, Parent = P.Content })
	for i, id in rv.Delete do
		local _, face = A.framed(strip, { Name = 'Pair_' .. id, X = (i - 1) * 138, Y = 4, W = 130, H = 136, Border = hex('FF4A5A'), BorderW = 4, Radius = 12, Outline = 3, Z = z })
		A.shoeArt(face, id, { X = 4, Y = 4, W = 114, H = 86, Z = z })
		A.text(face, A.shoeName(id), { Name = 'Name', Size = 18, X = 2, Y = 94, W = 118, H = 28, Z = z, Fit = true, MinSize = 11 })
	end
	local kept = {}
	for _, k in rv.Kept do table.insert(kept, A.shoeName(k.Id) .. ' (' .. (({ equipped = 'equipped', lock = 'locked', favorite = 'favourite' })[k.Why] or 'kept') .. ')') end
	local line = #rv.Delete .. (#rv.Delete == 1 and ' pair goes' or ' pairs go') .. ' (one spare each), you get +' .. short(rv.Cash) .. ' Cash.'
	if #kept > 0 then line = line .. '\nKept: ' .. table.concat(kept, ', ') .. '.' end
	A.text(P.Content, line, { Name = 'Body', Size = 20, X = 20, Y = 170, W = W - 40, H = 80, Wrap = true, Font = A.Font.Body, StrokeW = 2, Z = z })
	local yes = A.button(P.Content, { Name = 'ConfirmDelete', Text = 'Delete', Tone = 'red', X = 20, Y = 262, W = 330, H = 70, TextSize = 36, Glyph = function(p, x, y, s, zz) return A.trash(p, x, y, s * 0.8, zz) end, IconSize = 52, Gap = 16, Z = z, OnClick = function() call(ctx.yes) end })
	A.button(P.Content, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 380, Y = 262, W = 330, H = 70, TextSize = 36, Glyph = function(p, x, y, s, zz) return A.arrow(p, x, y, s * 0.8, zz) end, IconSize = 44, Gap = 14, Z = z, OnClick = function() call(ctx.no) end })
	if #rv.Delete == 0 then A.setState(yes, 'disabled') end
	return { P = P, Yes = yes }
end

---------------------------------------------------------------------------------------------- 01: the bundle
-- the bundle's state: 'live' (Roblox's purchase can open), 'pending' (no product id yet: "Price pending", disabled)
function S.bundleLive() return Products.ByKey.GrailBundle ~= nil and (Products.canBuy('GrailBundle')) == true end
function S.bundlePrice()
	local e = Products.ByKey.GrailBundle
	return e and RobuxText.fmt(e.Price) or ''
end
local BUNDLE = function() return Products.bundleShoes and Products.bundleShoes('GrailBundle') or { 'TheGrail', 'AstroCrown', 'PlatinumWings' } end
S.bundleShoes = BUNDLE

-- The Featured hero: the bundle card (867 x 414) with View Bundle and Gift, the Street / Graffiti box cards and the price
-- line under it (867 x 654 in all). ctx: view(), gift(), drops(boxId)
function S.bundleHero(parent, ctx, x, y, z)
	z = z or 2
	local holder = A.frame(parent, { Name = 'BundleHero', X = x or 0, Y = y or 0, W = 867, H = 654, Z = z })
	local card, face = A.framed(holder, { Name = 'Hero', X = 0, Y = 0, W = 867, H = 414, BorderGradient = { hex('FFE04A'), hex('FF9A10') }, BorderW = 7, InnerGradient = { hex('E848F2'), hex('7A1CC8') }, InnerRot = 120, Inner = hex('B030E0'), Radius = 18, Outline = 4, Z = z })
	local st = Kit.studs(face, { Pitch = 26, Width = 853, Height = 400, Shade = 0.9, ZIndex = z })
	if st and st:IsA('ImageLabel') then A.corner(st, 14) end
	A.sunburst(face, 420, 200, 820, z, WHITE, 0.14)
	-- THE GRAIL in gold, BUNDLE in white
	local ts = 66
	local w1, w2 = Kit.textWidth('THE GRAIL', ts) + math.floor(ts * 0.18), Kit.textWidth('BUNDLE', ts)
	local x0 = math.floor((853 - (w1 + w2)) / 2)
	A.text(face, 'THE GRAIL', { Name = 'TitleGold', Size = ts, X = x0, Y = 6, W = w1, H = 76, Align = 'Left', Gradient = { hex('FFF27A'), hex('FFAA00') }, StrokeW = 9, StrokeColor = hex('2A0848'), Z = z + 1 })
	A.text(face, 'BUNDLE', { Name = 'TitleWhite', Size = ts, X = x0 + w1, Y = 6, W = w2 + 8, H = 76, Align = 'Left', StrokeW = 9, StrokeColor = hex('2A0848'), Z = z + 1 })
	for _, sp in { { 48, 52, 50 }, { 806, 40, 44 }, { 62, 240, 34 }, { 830, 226, 40 }, { 440, 98, 34 }, { 336, 150, 24 }, { 780, 140, 28 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
	A.pill(face, { Name = 'Tag', X = 641, Y = 79, W = 194, H = 36, Text = 'Exclusive bundle', Color = hex('FFC81E'), TextColor = hex('2A1400'), TextStroke = false, TextSize = 20, Z = z + 1 })
	local ids = BUNDLE()
	local spots = { { 58, 70, 330, 205, 188 }, { 392, 128, 200, 140, 458 }, { 598, 128, 226, 140, 700 } }
	for i, id in ids do
		local s = spots[i]
		if s then
			A.shoeArt(face, id, { X = s[1], Y = s[2], W = s[3], H = s[4], Z = z })
			A.text(face, A.shoeName(id), { Name = 'Name' .. i, Size = 28, Pos = px(s[5], 270), Anchor = Vector2.new(0.5, 0), W = 240, H = 36, Z = z + 1, Fit = true })
		end
	end
	local view = A.button(face, { Name = 'ViewBundle', Text = 'View Bundle', Tone = 'green', X = 17, Y = 315, W = 526, H = 80, TextSize = 46, Z = z + 1, OnClick = function() call(ctx.view) end })
	A.chevron(view.Body, 470, 40, 40, 1, z + 1)
	A.button(face, { Name = 'Gift', Text = 'Gift', Tone = 'grey', X = 557, Y = 315, W = 278, H = 80, TextSize = 46, Glyph = function(p, gx, gy, s, zz) return A.icon(p, 'Rewards', { S = s, X = gx, Y = gy, Z = zz }) end, IconSize = 70, Gap = 18, Z = z + 1, OnClick = function() call(ctx.gift) end })
	-- the two Cash box cards
	for i, id in { 'Street', 'Graffiti' } do
		local fam = A.Family[id]
		local bx = i == 1 and 2 or 440
		local mini, mface = A.framed(holder, { Name = 'Mini_' .. id, X = bx, Y = 430, W = 428, H = 162, Border = i == 1 and hex('FF6A3A') or hex('2EC8F4'), BorderW = 6, InnerGradient = i == 1 and { hex('B8182E'), hex('6A0E1E') } or { hex('1E86F0'), hex('0C3E9A') }, Inner = fam.Card[2], Radius = 16, Outline = 4, Z = z })
		local ms = Kit.studs(mface, { Pitch = 22, Width = 416, Height = 150, Shade = 0.88, ZIndex = z })
		if ms and ms:IsA('ImageLabel') then A.corner(ms, 12) end
		A.boxArt(mface, id, { X = 8, Y = 4, W = 168, H = 140, Z = z })
		A.text(mface, fam.Box, { Name = 'Name', Size = 34, X = 180, Y = 6, W = 228, H = 46, Align = 'Center', Z = z, Fit = true })
		local vd = A.button(mface, { Name = 'ViewDrops', Text = 'View Drops', Tone = 'green', X = 182, Y = 78, W = 226, H = 60, TextSize = 28, Z = z, OnClick = function() call(ctx.drops, id) end })
		A.chevron(vd.Body, 202, 30, 28, 1, z)
	end
	-- the price line
	local line = A.block(holder, { Name = 'PriceLine', X = 2, Y = 602, W = 865, H = 52, Fill = hex('122236'), Radius = 10, Outline = 3, Z = z })
	A.info(line, 34, 26, 34, z)
	local priceText = A.text(line, '', { Name = 'Text', Size = 22, X = 70, Y = 0, W = 780, H = 52, Align = 'Left', Color = hex('B8C8DA'), Font = A.Font.Body, StrokeW = 2, Z = z })
	local H = { Holder = holder, View = view, PriceText = priceText }
	function H.refresh()
		if S.bundleLive() then
			priceText.Text = 'The Grail Bundle: ' .. S.bundlePrice() .. '  ·  one purchase, three pairs'
		else
			priceText.Text = 'Price pending'
		end
	end
	H.refresh()
	return H
end

-- THE GRAIL BUNDLE (01 right). ctx: purchase(), gift(), back(), close(), pending() -> bool (a purchase on its way)
function S.bundleDetail(parent, ctx)
	local W, Hh = 818, 840
	local P = A.panel(parent, { Name = 'BundleDetail', W = W, H = Hh, Head = 85, Foot = 200, Title = 'THE GRAIL BUNDLE', TitleSize = 58, TitleX = 146, TitleW = 570, IconNode = function(h, x, y, s, zz) A.icon(h, 'Rewards', { S = s, X = x, Y = y, Z = zz }) end, IconBox = { 26, -6, 92, 92 }, Close = function() call(ctx.close) end, CloseBox = { 731, 11, 75, 67 }, MinText = 20 })
	local z = P.Z + 3
	local sec, sface = A.framed(P.Content, { Name = 'Pairs', Pos = P.c(16, 103), W = 785, H = 527, Border = hex('E04CF0'), BorderW = 6, InnerGradient = { hex('5E1CA8'), hex('34106A') }, Inner = hex('4A1488'), Radius = 18, Outline = 4, Z = z })
	local st = Kit.studs(sface, { Pitch = 26, Width = 773, Height = 515, Shade = 0.9, ZIndex = z })
	if st and st:IsA('ImageLabel') then A.corner(st, 14) end
	local ids = BUNDLE()
	local xs = { { 6, 243 }, { 262, 247 }, { 521, 245 } }
	for i, id in ids do
		local r = xs[i]
		if r then
			local _, f = A.framed(sface, { Name = 'Pair_' .. id, X = r[1], Y = 24, W = r[2], H = 282, Border = hex('E04CF0'), BorderW = 6, Radius = 16, Outline = 4, Z = z })
			A.shoeArt(f, id, { X = 6, Y = 20, W = r[2] - 24, H = 200, Z = z })
			A.text(f, A.shoeName(id), { Name = 'Name', Size = 28, X = 4, Y = 226, W = r[2] - 20, H = 40, Z = z, Fit = true })
		end
	end
	local inc = A.block(sface, { Name = 'Includes', X = 4, Y = 324, W = 765, H = 187, Fill = hex('12203A'), Radius = 14, Outline = 3, Z = z })
	local ist = Kit.studs(inc, { Pitch = 24, Width = 765, Height = 187, Shade = 0.92, ZIndex = z })
	if ist and ist:IsA('ImageLabel') then A.corner(ist, 12) end
	A.text(inc, 'Includes all ' .. #ids .. ' pairs', { Name = 'Title', Size = 32, X = 0, Y = 6, W = 765, H = 44, Z = z })
	for i, t in { 'Distinct styles', 'Winged designs', 'Permanent inventory items' } do
		A.check(inc, 165, 74 + (i - 1) * 43, 40, z)
		A.text(inc, t, { Name = 'Line' .. i, Size = 28, X = 208, Y = 54 + (i - 1) * 43, W = 520, H = 40, Align = 'Left', Z = z })
	end
	local foot = P.Foot
	local purchase = A.button(foot, { Name = 'Purchase', Text = 'Purchase', Tone = 'green', X = 21, Y = 10, W = 775, H = 70, TextSize = 38, Z = z, OnClick = function() call(ctx.purchase) end })
	A.button(foot, { Name = 'GiftAPlayer', Text = 'Gift a Player', Tone = 'blue', X = 21, Y = 93, W = 477, H = 80, TextSize = 44, Glyph = function(p, gx, gy, s, zz) return A.icon(p, 'Rewards', { S = s, X = gx, Y = gy, Z = zz }) end, IconSize = 72, Gap = 16, Z = z, OnClick = function() call(ctx.gift) end })
	A.button(foot, { Name = 'Back', Text = 'Back', Tone = 'grey', X = 516, Y = 93, W = 280, H = 80, TextSize = 44, Glyph = function(p, gx, gy, s, zz) return A.chevron(p, gx, gy, s * 0.7, -1, zz) end, IconSize = 56, Gap = 30, Z = z, OnClick = function() call(ctx.back) end })
	local H = { P = P, Purchase = purchase }
	function H.refresh()
		if call(ctx.pending) then
			A.setState(purchase, 'loading', 'Purchase pending...')
		elseif S.bundleLive() then
			A.setState(purchase, 'normal', 'Purchase · ' .. S.bundlePrice())
		else
			A.setState(purchase, 'disabled', 'Purchase · Price pending')
		end
	end
	H.refresh()
	return H
end

-- The artboard's whole Shop panel (01 left): the tabs, the hero and the price line (the side-by-side shot; in game the
-- Store window holds the hero in its Featured section).
function S.shopPanel(parent, ctx)
	local P = A.panel(parent, { Name = 'Shop', W = 898, H = 840, Head = 85, Foot = 0, Title = 'SHOP', TitleSize = 52, TitleX = 128, TitleW = 640, Icon = 'Basket', IconBox = { 8, -12, 112, 100 }, Close = function() call(ctx.close) end, CloseBox = { 804, 13, 84, 68 }, MinText = 20 })
	local z = P.Z + 3
	A.tabs(P.Content, { Name = 'Tabs', X = 16, Y = 12, W = 866, H = 60, Gap = 8, Items = { { Id = 'Featured', Text = 'Featured' }, { Id = 'Boxes', Text = 'Boxes' }, { Id = 'Boosts', Text = 'Boosts' } }, Selected = 'Featured', SelectedTone = 'blue', IdleTone = 'dark', TextSize = 38, Radius = 10, Z = z, OnSelect = function(id) call(ctx.tab, id) end })
	local hero = S.bundleHero(P.Content, ctx, 16, 88, z)
	return { P = P, Hero = hero }
end

-- The artboard's PURCHASE STATES panel (06): the shop card while the price is pending, and Bundle received!
function S.purchaseStates(parent, ctx)
	local W, Hh = 738, 415
	local P = A.panel(parent, { Name = 'PurchaseStates', W = W, H = Hh, Head = 70, Foot = 0, Title = 'PURCHASE STATES', TitleSize = 40, TitleX = 112, TitleW = 520, Icon = 'Basket', IconBox = { 18, -8, 84, 78 }, Close = function() call(ctx.close) end, CloseBox = { 662, 9, 62, 54 }, MinText = 16 })
	local z = P.Z + 3
	local shop = A.block(P.Content, { Name = 'ShopState', X = 17, Y = 10, W = 253, H = 322, Fill = hex('122236'), Radius = 14, Outline = 4, Z = z })
	A.icon(shop, 'ShoeBox', { S = 44, X = 40, Y = 26, Z = z })
	A.text(shop, 'Shop', { Name = 'Title', Size = 30, X = 70, Y = 4, W = 170, H = 44, Align = 'Left', Z = z })
	local _, f = A.framed(shop, { Name = 'BundleCard', X = 13, Y = 54, W = 228, H = 136, Border = hex('E04CF0'), BorderW = 5, InnerGradient = { hex('B23AF0'), hex('4A1490') }, Inner = hex('6A1CC0'), Radius = 12, Outline = 3, Z = z })
	A.text(f, 'The Grail Bundle', { Name = 'Name', Size = 22, X = 4, Y = 2, W = 210, H = 30, Z = z, Fit = true })
	A.shoeArt(f, 'TheGrail', { X = 20, Y = 30, W = 180, H = 92, Z = z })
	local field = A.field(shop, { Name = 'Price', X = 13, Y = 197, W = 228, H = 37, Z = z, Border = hex('2A3E58'), BorderW = 2 })
	A.text(field, S.bundleLive() and S.bundlePrice() or 'Price Pending', { Name = 'Text', Size = 20, X = 0, Y = 0, W = 228, H = 37, Color = hex('B8C8DA'), Z = z })
	local buy = A.button(shop, { Name = 'Purchase', Text = 'Purchase', Tone = 'green', X = 13, Y = 244, W = 228, H = 66, TextSize = 32, Z = z, OnClick = function() call(ctx.purchase) end })
	A.setState(buy, S.bundleLive() and 'normal' or 'disabled')
	S.receivedBox(P.Content, 282, 10, BUNDLE(), ctx, z)
	return { P = P }
end

---------------------------------------------------------------------------------------------- the box key panel
-- Walking up to a box (Shoes.client): the reference's egg panel (bible 2.7, ref_V5-01.5_egg_panel_E_R_T: the title and
-- the price, a 3+2 odds grid on soft rays, the key cards E Single lime / R Triple yellow / T Auto cyan with cream keycaps)
-- dressed in the artboards' look: a studded navy panel with a thick outline and a cyan header, dark inset odds cards in
-- their rarity frames, big outlined text, and the pity counter as a dark inset pill with a bar ("Epic+ in 7 opens", the
-- rarity colour on "Epic+"; PityRules / PityUI give the value). Design px of the 1280 x 720 canvas (UIKit). Returns
-- { Holder, Cards = { E, R, T = { Card, Cap, Letter, Label, Sub, Lock } }, PityLine, paint(boxId, state) } where state =
-- { cash, lucky, autoOn, owned = function(passKey), entry = function(key) -> Products row }.
S.KeyTones = { E = hex('B0F500'), R = hex('FFF200'), T = hex('14E8F8') }
local KEY_TONE = {
	E = { top = hex('DAFF5A'), base = hex('86CC00'), rim = hex('F0FFB0') },
	R = { top = hex('FFFA7A'), base = hex('F2C600'), rim = hex('FFFDC8') },
	T = { top = hex('8AF6FF'), base = hex('0CB8E0'), rim = hex('D2FCFF') },
}
local LOCKED_TONE = { top = hex('4A5468'), base = hex('2A3244'), rim = hex('6A7488') }
function S.keyPanel(parent, ctx)
	local W, PH = 372, 356
	local z = 2
	local holder = A.frame(parent, { Name = 'Panel', W = W, H = PH + 128, Pos = UDim2.new(0.5, 0, 0, 92), Anchor = Vector2.new(0.5, 0), Z = z, Visible = false })
	local shell = A.block(holder, { Name = 'Shell', X = 0, Y = 0, W = W, H = PH, Fill = A.Tone.navy.base, Transparency = 0.06, Radius = 16, Outline = 4, Z = z })
	local studs = Kit.studs(shell, { Pitch = 24, Width = W, Height = PH, Shade = 0.9, ZIndex = z })
	if studs and studs:IsA('ImageLabel') then A.corner(studs, 16) end
	A.stroke(A.frame(shell, { Name = 'Rim', X = 3, Y = 3, W = W - 6, H = PH - 6, Radius = 13, Z = z }), hex('1E5A78'), 3, true, 0.25)
	local head = A.block(holder, { Name = 'Header', X = 0, Y = 0, W = W, H = 62, Tone = 'cyan', Radius = 14, Outline = 4, Studs = 20, StudShade = 0.84, Z = z + 1 })
	local name = A.text(head, '', { Name = 'Name', Size = 36, X = 64, Y = 0, W = W - 74, H = 62, Align = 'Left', StrokeW = 5, Z = z + 1, Fit = true })
	local icon = A.frame(holder, { Name = 'BoxIcon', X = 4, Y = -12, W = 64, H = 76, Z = z + 2 })
	-- the price under the header (gold), a Cash note or the Robux mark
	local price = A.text(holder, '', { Name = 'Price', Size = 30, X = 16, Y = 64, W = W - 32, H = 38, Gradient = { hex('FFF27A'), hex('FFAE10') }, StrokeW = 4, Z = z + 1, Fit = true })
	-- the odds: 3 + 2 on soft rays
	local grid = A.frame(holder, { Name = 'Odds', X = 0, Y = 104, W = W, H = 196, Z = z + 1 })
	A.sunburst(grid, W / 2, 98, 380, z + 1, WHITE, 0.1)
	-- the pity pill: a dark inset well, a bar, "Epic+ in 7 opens"
	local pill = A.block(holder, { Name = 'Pity', X = 14, Y = 306, W = W - 28, H = 40, Fill = hex('0A1626'), Radius = 20, Outline = 3, Z = z + 1 })
	A.stroke(A.frame(pill, { Name = 'Rim', X = 2, Y = 2, W = W - 32, H = 36, Radius = 18, Z = z + 1 }), hex('22405E'), 2, true)
	local track = A.frame(pill, { Name = 'Track', X = 10, Y = 27, W = W - 48, H = 7, Fill = hex('1C2C44'), Radius = UDim.new(0.5, 0), Z = z + 1 })
	local fill = A.frame(track, { Name = 'Fill', X = 0, Y = 0, W = 0, H = 7, Fill = WHITE, Radius = UDim.new(0.5, 0), Z = z + 1 })
	local fillGrad = Kit.new('UIGradient', { Rotation = 0, Color = ColorSequence.new(hex('C27CFF'), hex('8A2BE2')), Parent = fill })
	local pityLine = A.text(pill, '', { Name = 'PityLine', Size = 19, X = 10, Y = 2, W = W - 48, H = 24, Rich = true, StrokeW = 3, Z = z + 1, Fit = false })
	-- the key cards under the panel
	local cards = {}
	local labels = { E = 'Single', R = 'Triple', T = 'Auto' }
	for i, key in { 'E', 'R', 'T' } do
		local x = 8 + (i - 1) * 122
		local card = A.frame(holder, { Name = 'Card' .. key, X = x, Y = PH + 10, W = 112, H = 112, Z = z })
		card:SetAttribute('Lip', 3)
		local body = A.block(card, { Name = 'Body', X = 0, Y = 0, W = 112, H = 112, Tone = KEY_TONE[key], Radius = 14, Outline = 4, Studs = 18, StudShade = 0.86, Z = z })
		local cap = A.block(body, { Name = 'Keycap', X = 30, Y = 8, W = 52, H = 48, Fill = hex('FFF6DC'), Radius = 10, Outline = 3, OutlineColor = hex('463E30'), Z = z })
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(WHITE, hex('E8DCC0')), Parent = cap })
		cap.BackgroundColor3 = WHITE
		local letter = A.text(cap, key, { Name = 'Letter', Size = 32, X = 0, Y = -1, W = 52, H = 48, Color = hex('3C4250'), Stroke = false, Z = z })
		local lock = A.padlock(body, 56, 32, 40, z)
		lock.Visible = false
		local label = A.text(body, labels[key], { Name = 'Label', Size = 24, X = 2, Y = 58, W = 108, H = 30, StrokeW = 4, Z = z, Fit = true })
		local sub = A.text(body, '', { Name = 'Sub', Size = 18, X = 2, Y = 86, W = 108, H = 22, StrokeW = 3, Z = z, Fit = true })
		local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 3, Parent = card })
		require(Shared.UIMotion).button(card, function() call(ctx.press, key) end)
		cards[key] = { Card = card, Body = body, Cap = cap, Letter = letter, Label = label, Sub = sub, Lock = lock, Hit = hit }
	end
	local H = { Holder = holder, Cards = cards, Name = name, Price = price, PityLine = pityLine, PityFill = fill }
	local shownBox
	local function cardState(c, key, label, sub, locked, on, subColor)
		c.Label.Text = label
		c.Sub.Text = sub or ''
		c.Sub.TextColor3 = subColor or WHITE
		c.Lock.Visible = locked
		c.Cap.Visible = not locked
		local tone = locked and LOCKED_TONE or KEY_TONE[key]
		local g = c.Body:FindFirstChildOfClass('UIGradient')
		if g then g.Color = ColorSequence.new(tone.top, tone.base) end
		local ring = c.Card:FindFirstChild('OnRing')
		if on and not ring then
			ring = A.frame(c.Card, { Name = 'OnRing', X = -6, Y = -6, W = 124, H = 124, Radius = 18, Z = z })
			A.stroke(ring, hex('7CFF4F'), 4, true)
		elseif not on and ring then
			ring:Destroy()
		end
	end
	function H.paint(boxId, st)
		local box = Shoes.BoxById[boxId]
		if not box then return end
		st = st or {}
		if shownBox ~= boxId then
			shownBox = boxId
			for _, c in icon:GetChildren() do c:Destroy() end
			A.boxArt(icon, boxId, { X = 0, Y = 0, W = 64, H = 76, Z = z + 2 })
			for _, c in grid:GetChildren() do
				if c.Name ~= 'Sunburst' and c.Name ~= 'Glow' then c:Destroy() end
			end
			local n = #box.Shoes
			for i, id in box.Shoes do
				local shoe = Shoes.ById[id]
				local rar = A.rarity(shoe.Rarity)
				local row = i <= 3 and 0 or 1
				local inRow = row == 0 and math.min(3, n) or (n - 3)
				local col = row == 0 and (i - 1) or (i - 4)
				local cw, gap = 108, 9
				local x0 = (W - (inRow * cw + (inRow - 1) * gap)) / 2
				local _, face = A.framed(grid, { Name = 'Odd' .. i, X = x0 + col * (cw + gap), Y = 4 + row * 98, W = cw, H = 92, Border = rar.Rainbow and 'rainbow' or rar.Color, BorderW = 4, Radius = 12, Outline = 3, Z = z + 1 })
				A.shoeArt(face, id, { X = 4, Y = 2, W = cw - 16, H = 50, Z = z + 1 })
				local chance = A.text(face, '', { Name = 'Chance', Size = 22, X = 0, Y = 52, W = cw - 8, H = 30, Z = z + 1, Fit = true })
				chance:SetAttribute('Shoe', id)
				A.text(face, '+' .. shoe.Bonus .. '%', { Name = 'Bonus', Size = 15, X = cw - 56, Y = -2, W = 50, H = 20, Align = 'Right', Color = hex('FFE04A'), StrokeW = 3, Z = z + 2 })
			end
		end
		for _, d in grid:GetDescendants() do
			if d.Name == 'Chance' and d:IsA('TextLabel') then d.Text = ShoeRules.chanceText(ShoeRules.chanceOf(d:GetAttribute('Shoe'), st.lucky)) end
		end
		name.Text = A.boxName(boxId)
		local cash = st.cash or 0
		if box.Robux then
			price.Text = S.priceText(boxId, 1) .. '  ·  Exclusive'
		else
			price.Text = short(box.Price) .. ' Cash'
			price.TextColor3 = WHITE
		end
		local priceGrad = price:FindFirstChildOfClass('UIGradient')
		local afford = box.Robux ~= nil or cash >= (box.Price or 0)
		if priceGrad then priceGrad.Color = afford and ColorSequence.new(hex('FFF27A'), hex('FFAE10')) or ColorSequence.new(hex('FFB0B0'), hex('FF5A5A')) end
		-- the pity pill
		local left, every = 0, 0
		if PityUI and PityUI.remaining then left = PityUI.remaining(boxId) end
		local okP, Pity = pcall(require, Shared.PityRules)
		if okP and Pity and Pity.boxEvery then every = Pity.boxEvery(boxId) or 0 end
		local rname = okP and Pity.rarityName and Pity.rarityName() or 'Epic'
		local rcol = A.rarity(rname).Color
		local hexc = string.format('#%02X%02X%02X', math.floor(rcol.R * 255 + 0.5), math.floor(rcol.G * 255 + 0.5), math.floor(rcol.B * 255 + 0.5))
		local tail = left <= 1 and ' on your next open!' or (' in ' .. left .. ' opens')
		pityLine.Text = '<font color="' .. hexc .. '">' .. rname .. '+</font>' .. tail
		pill.Visible = every > 0
		local frac = every > 0 and math.clamp((every - left) / every, 0, 1) or 0
		fill.Size = UDim2.new(frac, 0, 1, 0)
		fill.Visible = frac > 0
		fillGrad.Color = left <= 1 and ColorSequence.new(hex('B8FF6A'), hex('3EC81A')) or ColorSequence.new(rcol:Lerp(WHITE, 0.3), rcol)
		-- the keys
		local owned, entry = st.owned or function() return false end, st.entry or function() return nil end
		local function robuxSub(key)
			local e = entry(key)
			return e and RobuxText.fmt(e.Price) or 'SOON'
		end
		if box.Robux then
			cardState(cards.E, 'E', 'Buy', robuxSub(box.Robux), false, false, hex('B8F838'))
			cardState(cards.R, 'R', 'Buy 3', robuxSub(box.Robux .. '3'), false, false, hex('B8F838'))
			cardState(cards.T, 'T', 'Buy 8', robuxSub(box.Robux .. '8'), false, false, hex('B8F838'))
			return
		end
		cardState(cards.E, 'E', 'Single', short(box.Price), false, false, cash >= box.Price and WHITE or hex('FF8A8A'))
		if owned('TripleOpen') then
			cardState(cards.R, 'R', 'Triple', short(box.Price * 3), false, false, cash >= box.Price * 3 and WHITE or hex('FF8A8A'))
		else
			cardState(cards.R, 'R', 'Triple', robuxSub('TripleOpen'), true, false, hex('B8F838'))
		end
		if owned('AutoOpen') then
			cardState(cards.T, 'T', st.autoOn and 'Stop' or 'Auto', st.autoOn and 'ON' or short(box.Price), false, st.autoOn, st.autoOn and hex('7CFF4F') or WHITE)
		else
			cardState(cards.T, 'T', 'Auto', robuxSub('AutoOpen'), true, false, hex('B8F838'))
		end
	end
	return H
end

---------------------------------------------------------------------------------------------- 05 right: Daily Rewards
-- st: RetentionService's Daily state ({ Ready, Day, Claimed, Missed, CanRestore, RestoreDay, Wait, Cards = { [day] =
-- { Lines, Big } } }); ctx: claim(), restore(), restorePrice() -> text, group = { On, Claimed, Lines } | nil, claimGroup(),
-- close(), waitLeft() -> seconds. The rewards and their lines are the server's (Shared/RetentionRules), never the
-- artboard's.
local DAY_TONE = { 'green', 'cyan', 'yellow', 'magenta', 'purple', 'orange', 'magenta' }
local DAY_BORDER = { hex('2CE04A'), hex('2EC8F4'), hex('FFC81E'), hex('F23CC8'), hex('A84CF4'), hex('FF7A1E'), hex('F23CC8') }
local function dayIcon(card)
	local line = (card and card.Lines and card.Lines[1]) or ''
	if card and card.Big then return 'Rewards' end
	if line:find('Cash') then return 'CashBig' end
	if line:find('^%d+x Power') then return line:find('^3') and 'PotionGold' or 'PotionRed' end
	return 'Muscle'
end
function S.daily(parent, st, ctx)
	local W, Hh = 951, 748
	local P = A.panel(parent, { Name = 'Daily', W = W, H = Hh, Head = 123, Foot = 58, Title = 'Daily Rewards', TitleSize = 74, TitleX = 165, TitleW = 650, IconNode = function(h, x, y, s, zz) A.calendar(h, x, y, s, zz, 31) end, IconBox = { 18, 8, 120, 112 }, Close = function() call(ctx.close) end, CloseBox = { 840, 15, 95, 85 }, MinText = 18 })
	local z = P.Z + 3
	local H = { P = P }
	local cardsHolder = A.frame(P.Content, { Name = 'Days', X = 0, Y = 0, W = W, H = Hh - 123 - 58, Z = z })
	local strip = A.block(P.Foot, { Name = 'Status', X = 15, Y = 4, W = 920, H = 47, Fill = hex('12263A'), Radius = 10, Outline = 3, Z = z })
	local stripStuds = Kit.studs(strip, { Pitch = 22, Width = 920, Height = 47, Shade = 0.92, ZIndex = z })
	if stripStuds and stripStuds:IsA('ImageLabel') then A.corner(stripStuds, 8) end
	local status = A.text(strip, '', { Name = 'Text', Size = 22, X = 12, Y = 0, W = 896, H = 47, Color = hex('9CC8F0'), Font = A.Font.Body, StrokeW = 2, Z = z, Fit = true })
	local actions = A.frame(strip, { Name = 'Actions', X = 0, Y = 0, W = 920, H = 47, Z = z })
	local function card(day, data, state)
		local big = data and data.Big
		local x = big and 630 or ({ 15, 218, 423 })[(day - 1) % 3 + 1]
		local y = big and 24 or (day <= 3 and 24 or 300)
		local w = big and 305 or 195
		local h = big and 558 or (day <= 3 and 263 or 247)
		local outer, face = A.framed(cardsHolder, { Name = 'Day' .. day, X = x, Y = y, W = w, H = h, Border = DAY_BORDER[day], BorderW = 5, Radius = 14, Outline = 4,
			InnerGradient = big and { hex('E848F2'), hex('7A1CC8') } or nil, Inner = big and hex('B030E0') or nil, Z = z })
		local fw = w - 10
		if big then
			A.sunburst(face, fw / 2, h * 0.5, w * 1.6, z, WHITE, 0.14)
			for _, sp in { { 40, 130, 34 }, { fw - 40, 120, 30 }, { 50, 400, 30 }, { fw - 36, 380, 36 }, { fw / 2, 90, 26 } } do A.sparkle(face, sp[1], sp[2], sp[3], z) end
			A.text(face, 'Day ' .. day, { Name = 'Day', Size = 64, X = 0, Y = 12, W = fw, H = 76, Z = z })
			A.icon(face, dayIcon(data), { S = 210, X = fw / 2, Y = 262, Z = z })
		else
			local head = A.block(face, { Name = 'Strip', X = 0, Y = 0, W = fw, H = 54, Tone = DAY_TONE[day], Radius = 10, Outline = 0, Studs = false, Rim = false, Z = z })
			A.text(head, 'Day ' .. day, { Name = 'Day', Size = 38, X = 0, Y = 2, W = fw, H = 50, Z = z })
			A.icon(face, dayIcon(data), { S = 140, X = fw / 2, Y = 54 + (h - 54 - 60) / 2, Z = z })
		end
		local lines = data and data.Lines or {}
		local text = table.concat(lines, '\n')
		if state == 'ready' then
			local b = A.button(face, { Name = 'Claim', Text = 'Claim!', Tone = 'green', X = 10, Y = h - (big and 92 or 74), W = fw - 20, H = big and 70 or 56, TextSize = big and 44 or 36, Z = z + 1, OnClick = function() call(ctx.claim) end })
			H.ClaimButton = b
			if big then A.text(face, text, { Name = 'What', Size = 24, X = 6, Y = h - 210, W = fw - 12, H = 100, Wrap = true, Z = z }) end
		else
			A.text(face, text, { Name = 'What', Size = big and (#lines > 2 and 30 or 40) or (#lines > 1 and 18 or 22), X = 4, Y = h - (big and 150 or 60), W = fw - 8, H = big and 130 or 48, Wrap = true, Z = z, Fit = not big and #lines <= 1 })
		end
		if state == 'claimed' then
			-- (the artboard: the reward stays visible under a big green tick)
			A.frame(face, { Name = 'Done', X = 0, Y = big and 0 or 54, W = fw, H = h - 10 - (big and 0 or 54), Fill = Color3.new(0, 0, 0), Transparency = 0.8, Radius = 10, Z = z })
			local t = A.tick(face, fw / 2 + 4, big and 262 or (54 + (h - 54 - 60) / 2 + 6), big and 150 or 118, hex('3CE04A'), z + 1, A.Ink)
			t.Name = 'Claimed'
		end
		return outer
	end
	function H.paint(stNow)
		st = stNow or st
		for _, c in cardsHolder:GetChildren() do c:Destroy() end
		for _, c in actions:GetChildren() do c:Destroy() end
		H.ClaimButton = nil
		local d = type(st) == 'table' and (st.Daily or st) or nil
		if not d or not d.Cards then
			status.Text = 'Loading...'
			return
		end
		for day = 1, 7 do card(day, d.Cards[day], U.dayState(d, day)) end
		local wait = call(ctx.waitLeft) or d.Wait or 0
		local clock = string.format('%dh %02dm', math.floor(math.max(0, wait) / 3600), math.floor(math.max(0, wait) % 3600 / 60))
		status.Size = px(896, 47)
		if d.Ready and d.Missed and d.CanRestore then
			status.Text = 'You missed a day: restore your streak (Day ' .. tostring(d.RestoreDay) .. ') or claim Day 1.'
			status.Size = px(640, 47)
			A.button(actions, { Name = 'Restore', Text = 'Restore ' .. (call(ctx.restorePrice) or ''), Tone = 'yellow', X = 660, Y = 3, W = 254, H = 41, TextSize = 22, Studs = false, Z = z, OnClick = function() call(ctx.restore) end })
		elseif d.Ready then
			status.Text = d.Missed and 'The streak starts again at Day 1. Claim it now!' or 'Reward ready to claim!'
		else
			status.Text = 'Next reward in ' .. clock .. '  ·  come back every day: Day 7 is the big one'
		end
		local g = ctx.group or (type(st) == 'table' and st.Group) or nil
		if g and g.On and not g.Claimed and not (d.Ready and d.Missed and d.CanRestore) then
			status.Size = px(640, 47)
			A.button(actions, { Name = 'GroupClaim', Text = 'Group reward', Tone = 'blue', X = 660, Y = 3, W = 254, H = 41, TextSize = 22, Studs = false, Z = z, OnClick = function() call(ctx.claimGroup) end })
		end
	end
	H.paint(st)
	return H
end

return S
