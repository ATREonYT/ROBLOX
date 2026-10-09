-- Player HUD for +1 Hood Evolution, laid out like the user's reference simulator HUD (brief 17, user_26):
--   left column    a wide Store button, then Rebirth | Shoes and Guns | Rewards: square studded blocks with thick
--                  ink outlines and big 3D icons popping out of their tops (Shoes.client puts its SHOES button in
--                  the slot named ShoesSlot); the Rebirths and Cash counters under it (over it on phones)
--   right column   offer cards (2x Power, 2x Cash, VIP) with "ONLY <Robux> price" under each
--   bottom-centre  "Multiplier: Nx", the Power icon and count, the studded rebirth bar ("Rebirth n" .. "power /
--                  need") and three Robux power-pack buttons
--   top-centre     one hint line (how to train, your multipliers, when you can rebirth) and the notices
--   windows        Rebirth (like user_27), Guns and Rewards as Kit.windows; the Store is Store.client's
-- Authored in UIKit's 1280x720 design pixels; Kit.screen's UIScale fits it to any screen.
-- It only reads state: player attributes the server sets (LobbyService: Power, TrainingStation, Cash, Rebirths;
-- the rebirth service: RebirthNeed, RebirthMultiplier; GunService: EquippedGun, GunMultiplier, OwnedGuns;
-- ShoeService: ShoeMultiplier; StoreService: Pass_<Key>) and the profile snapshot. No looks: players wear their own
-- avatar, so there is no EVOLVE button, no look ladder and no "new look" banner any more.
-- Windows tell each other apart through PlayerGui's HoodWindow attribute: opening one closes the others.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local ActiveMap = require(Shared.ActiveMap)
local Skins = require(Shared.Config.Skins)
local Balance = require(Shared.Config.Balance)
local Guns = require(Shared.Config.Guns)
local Products = require(Shared.Config.Products)

-- Modules other parts of the build add; the HUD works without them.
local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and type(result) == 'table' and result or nil
end
local GunRules = optional('GunRules')
local GunModels = optional('Models', 'GunModels')
local IconModels = optional('Models', 'IconModels')
local RebirthRules = optional('RebirthRules')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, Tone, short = Kit.Color, Kit.Tone, Kit.short
local px = UDim2.fromOffset

---------------------------------------------------------------------------------------------- state
local snapshot = {} -- Cash and Rebirths from the profile snapshot, until the attributes arrive
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
local function cashNow() return num('Cash', snapshot.Cash or 0) end
local function rebirthsNow() return num('Rebirths', snapshot.Rebirths or 0) end
-- The Power the rebirth from n to n + 1 needs: the server's attribute for your own count, else the shared rule.
local function rebirthNeed(n)
	n = n or rebirthsNow()
	if n == rebirthsNow() then
		local v = num('RebirthNeed', nil)
		if v and v > 0 then return v end
	end
	if RebirthRules and type(RebirthRules.need) == 'function' then
		local ok, v = pcall(RebirthRules.need, n)
		if ok and type(v) == 'number' then return v end
	end
	return math.floor((Balance.RebirthBase or 2500) * (Balance.RebirthRequirementGrowth or 2.3) ^ n + 0.5)
end
-- The Power multiplier n rebirths give.
local function rebirthMultiplier(n)
	n = n or rebirthsNow()
	local attr = (n == rebirthsNow() and 'RebirthMultiplier') or (n == rebirthsNow() + 1 and 'RebirthNextMultiplier') or nil
	local v = attr and num(attr, nil)
	if v and v > 0 then return v end
	if RebirthRules and type(RebirthRules.multiplier) == 'function' then
		local ok, v = pcall(RebirthRules.multiplier, n)
		if ok and type(v) == 'number' then return v end
	end
	return 1 + n * (Balance.RebirthMultiplierPerLevel or 1)
end
local function gunMultiplier() return num('GunMultiplier', Guns.multiplier(player:GetAttribute('EquippedGun') or Guns.Starter)) end
-- Everything that multiplies a shot except the range you stand in: the server's own figure when it publishes
-- one, else rebirths x gun x shoes (x2 with the 2x Power pass).
local function totalMultiplier()
	local v = num('ShotMultiplier', nil)
	if v and v > 0 then return v end
	return rebirthMultiplier() * gunMultiplier() * math.max(1, num('ShoeMultiplier', 1)) * (player:GetAttribute('Pass_DoubleRep') == true and 2 or 1)
end
-- 2 -> "2x", 2.25 -> "2.3x", 1234 -> "1.2Kx"
local function times(x)
	if x >= 1000 then return short(x) .. 'x' end
	if math.abs(x - math.floor(x + 0.5)) < 0.05 then return string.format('%d', math.floor(x + 0.5)) .. 'x' end
	return string.format('%.1f', x) .. 'x'
end

---------------------------------------------------------------------------------------------- purchases
-- A Store item: prompt Roblox's purchase when the item is live (Products.canBuy), else say it's coming.
local toast -- (forward)
local function buy(key)
	local ok = Products.canBuy(key)
	if not ok then
		local entry = Products.ByKey[key]
		toast((entry and entry.Title or 'This') .. ' is coming soon!', 'blue')
		return
	end
	local entry = Products.ByKey[key]
	local id = Products.idOf(key)
	pcall(function()
		if entry.Kind == 'Pass' then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
end
-- The Store window (Store.client) opens on a BindableEvent in its ScreenGui; `at` = a section or a catalog key.
local function openStore(at)
	local storeGui = playerGui:FindFirstChild('HoodStore')
	local open = storeGui and storeGui:FindFirstChild('Open')
	if open and open:IsA('BindableEvent') then
		open:Fire(at)
	else
		toast('The Store is loading...', 'blue')
	end
end

---------------------------------------------------------------------------------------------- screen
local gui, root, fit = Kit.screen('HoodHUD', nil, 5)
-- The windows live in their own ScreenGui over the goal line (HoodGoals is 7), like the Store and Shoes windows (8).
local panelGui, panelRoot, panelFit = Kit.screen('HoodPanels', nil, 8)
-- Notices sit over everything (a purchase's "Thanks!" arrives while the Store is open).
local noticeGui, noticeRoot, noticeFit = Kit.screen('HoodNotices', nil, 10)

---------------------------------------------------------------------------------------------- left column
-- Reference proportions: a wide Store block over 2-wide rows of square blocks; icons pop out of each top edge.
local LEFT, SQ, GAP, WIDE_H, POP = 16, 96, 14, 72, 18
local COLUMN = 2 * SQ + GAP
local ROW1 = WIDE_H + GAP + POP
local ROW2 = ROW1 + SQ + GAP + POP
local COLUMN_H = ROW2 + SQ
local column = Kit.new('Frame', { Name = 'Actions', BackgroundTransparency = 1, Position = px(LEFT, 120), Size = px(COLUMN, COLUMN_H), Parent = root })
local actions = {} -- filled with the button callbacks once the windows exist
local function call(name) return function() if actions[name] then actions[name]() end end end

local function actionButton(props)
	local holder, hit, icon, caption = Kit.actionButton(props)
	holder.Parent = column
	Motion.button(holder, props.OnClick)
	return holder, icon, caption, hit
end
local storeButton = actionButton({ Name = 'Store', Tone = 'orange', Width = COLUMN, Height = WIDE_H, Position = px(0, POP), Text = 'Store', TextSize = 30, Icon = 'Shop', IconSize = 84, Pop = 24, Studs = 20, OnClick = call('Store') })
Motion.shine(storeButton.Body, 4, UDim.new(0, 6))
local rebirthButton = actionButton({ Name = 'Rebirth', Tone = 'red', Width = SQ, Height = SQ, Position = px(0, ROW1), Text = 'Rebirth', TextSize = 22, Icon = 'Rebirth', IconSize = 80, Pop = POP, OnClick = call('Rebirth') })
-- (Shoes.client builds its SHOES button in this slot, with the same Kit.actionButton)
Kit.new('Frame', { Name = 'ShoesSlot', BackgroundTransparency = 1, Position = px(SQ + GAP, ROW1), Size = px(SQ, SQ), Parent = column })
actionButton({ Name = 'Guns', Tone = 'blue', Width = SQ, Height = SQ, Position = px(0, ROW2), Text = 'Guns', TextSize = 22, Icon = 'Gun', IconSize = 82, Pop = POP, OnClick = call('Guns') })
actionButton({ Name = 'Rewards', Tone = 'purple', Width = SQ, Height = SQ, Position = px(SQ + GAP, ROW2), Text = 'Rewards', TextSize = 22, Icon = 'Rewards', IconSize = 80, Pop = POP, OnClick = call('Rewards') })
-- "100%" on Rebirth, like the reference: how close the next rebirth is; it wobbles when you can rebirth.
local rebirthBadge = Kit.sticker(rebirthButton, { Name = 'Percent', Text = '0%', TextSize = 24, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 14, 0.62, 0), Rotation = 0, ZIndex = 9 })
local badgeWobble
local function setRebirthReady(ready)
	rebirthBadge.TextColor3 = ready and Tone.green.top or Color.white
	if ready and not badgeWobble then
		badgeWobble = Motion.wobble(rebirthBadge, 8, 0.8)
	elseif not ready and badgeWobble then
		badgeWobble:Cancel()
		badgeWobble = nil
		rebirthBadge.Rotation = 0
	end
end

-- Counters (the reference's bottom-left: an icon and a big outlined number each).
local counters = Kit.new('Frame', { Name = 'Counters', BackgroundTransparency = 1, Position = px(LEFT, 0), Size = px(COLUMN + 40, 104), Parent = root })
local function counter(name, iconId, y, tint)
	local row = Kit.new('Frame', { Name = name, BackgroundTransparency = 1, Position = px(0, y), Size = px(COLUMN + 40, 50), Parent = counters })
	local icon = Kit.icon3d(iconId, 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -6, 0.5, 0), ZIndex = 2 })
	icon.Parent = row
	local value = Kit.text({ Name = 'Value', Text = '0', TextSize = 40, TextColor3 = tint, Stroke = Color.ink, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(56, 0), Size = UDim2.new(1, -56, 1, 0), ZIndex = 2, Parent = row })
	return value, icon
end
local rebirthCount, rebirthIcon = counter('Rebirths', 'Rebirth', 0, Kit.hex('FF8A8A'))
local cashCount, cashIcon = counter('Cash', 'Cash', 52, Tone.green.top)

---------------------------------------------------------------------------------------------- right column
-- Offer cards like the reference's "2x Wins / ONLY 9": a studded block, the 3D icon over its top, the name, and
-- "ONLY <Robux> price" over its bottom edge. A tap buys (or says it's coming soon).
local OFFER_W, OFFER_H = 186, 60
local offers = Kit.new('Frame', { Name = 'Offers', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 120), Size = px(OFFER_W, 3 * (OFFER_H + 64)), Parent = root })
local function offerCard(key, i)
	local entry = Products.ByKey[key]
	if not entry then return end
	local y = (i - 1) * (OFFER_H + 64) + 36
	local holder, hit = Kit.blockButton({ Name = key, Tone = entry.Tone, Width = OFFER_W, Height = OFFER_H, Position = px(0, y), Studs = 18 })
	holder.Parent = offers
	local art = entry.Art:match('^icon:(.+)$') or (entry.Art:find('^gun:') and 'Gun') or 'Shop'
	-- (the icon over the card's top edge, the name over the icon's lower half, like the reference's "2x Wins")
	local icon = Kit.icon3d(art, 76, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -34), ZIndex = 6 })
	icon.Parent = holder.Body
	Kit.text({ Name = 'Title', Text = entry.Offer or entry.Title, TextSize = 32, Stroke = Color.ink, StrokeThickness = 4.5, Position = px(4, 12), Size = UDim2.new(1, -8, 1, -14), ZIndex = 7, Parent = holder.Body })
	hit.Position = px(0, -34)
	hit.Size = UDim2.new(1, 0, 1, 34)
	-- "ONLY  <Robux> 199" in green over the bottom edge
	local price = tostring(entry.Price)
	local onlyW, priceW = Kit.textWidth('ONLY', 22), Kit.textWidth(price, 22)
	local row = Kit.new('Frame', { Name = 'Only', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 8, 1, -8), Size = px(onlyW + 26 + priceW, 28), ZIndex = 8, Parent = holder })
	local only = Kit.text({ Name = 'Only', Text = 'ONLY', TextSize = 22, Stroke = Color.ink, StrokeThickness = 3.5, TextColor3 = Tone.green.top, TextXAlignment = Enum.TextXAlignment.Left, Size = px(onlyW, 28), ZIndex = 8, Parent = row })
	Kit.gradient(Kit.hex('E8FF6A'), Tone.green.top, 0.6).Parent = only
	Kit.robux(22, { Color = Tone.green.top, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, onlyW + 2, 0.5, 0), ZIndex = 8 }).Parent = row
	Kit.text({ Name = 'Price', Text = price, TextSize = 22, Stroke = Color.ink, StrokeThickness = 3.5, TextColor3 = Tone.green.top, TextXAlignment = Enum.TextXAlignment.Left, Position = px(onlyW + 26, 0), Size = px(priceW, 28), ZIndex = 8, Parent = row })
	Motion.button(holder, function() buy(key) end)
	return holder
end
local OFFERS = { 'DoubleRep', 'DoubleCash', 'VIP' } -- (the passes that work today; Auto Shoot waits in the Store)
for i, key in OFFERS do offerCard(key, i) end

---------------------------------------------------------------------------------------------- bottom-centre
-- The reference's bottom block: "Multiplier: 22.3x" over the left of the bar, the Power icon and count over its
-- middle, the studded bar ("Level 175 .. MAX LEVEL"; here: your next rebirth), and three Robux power packs.
local BAR_W, BAR_H, TOP_H, PACK_H = 560, 46, 54, 46
local STATUS_H = TOP_H + BAR_H + 12 + PACK_H + 14
local status = Kit.new('Frame', { Name = 'Status', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = px(BAR_W, STATUS_H), Parent = root })
local multiplierLabel = Kit.text({ Name = 'Multiplier', Text = 'Multiplier: 1x', TextSize = 22, Stroke = Color.ink, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), Position = px(4, TOP_H), Size = px(220, 28), ZIndex = 3, Parent = status })
Kit.gradient(Kit.hex('FFE76A'), Kit.hex('FF9A1F'), 0.7).Parent = multiplierLabel
local powerRow = Kit.new('Frame', { Name = 'Power', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 30, 0, TOP_H + 4), Size = px(300, TOP_H + 6), Parent = status })
local powerIcon = Kit.icon3d('Power', 58, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -6, 0.5, 0), ZIndex = 3 })
powerIcon.Parent = powerRow
local powerLabel = Kit.text({ Name = 'Value', Text = '...', TextSize = 46, Stroke = Color.ink, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -4, 0.5, 0), Size = px(220, 56), ZIndex = 3, Parent = powerRow })
Kit.gradient(Kit.hex('FFF6B0'), Kit.hex('FFC21A'), 0.6).Parent = powerLabel

-- A running timed boost (StoreService: PowerBoost, and BoostEnds / PartyEnds as os.time) shows over the multiplier
-- with its time left: "2x Boost 14:59".
local boostChip = Kit.block({ Name = 'Boost', Tone = 'purple', Width = 176, Height = 30, Studs = 14, Shadow = 3, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 0, TOP_H - 30), ZIndex = 3 })
boostChip.Visible = false
boostChip.Parent = status
local boostText = Kit.text({ Name = 'Text', Text = '', TextSize = 20, Stroke = Color.ink, StrokeThickness = 3, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = boostChip.Body })
local function paintBoost()
	local level = num('PowerBoost', 1)
	local ends = math.max(num('BoostEnds', 0), num('PartyEnds', 0))
	local left = ends - os.time()
	boostChip.Visible = level > 1 and left > 0
	if boostChip.Visible then
		boostText.Text = times(level) .. ' Boost  ' .. string.format('%d:%02d', math.floor(left / 60), left % 60)
	end
end
task.spawn(function()
	while true do
		paintBoost()
		task.wait(1)
	end
end)

local bar, fill, barText = Kit.bar({ Name = 'RebirthBar', Width = BAR_W, Height = BAR_H, Tone = 'orange', Value = 0, Left = 'Rebirth 1', Right = '0 / 0', TextSize = 28, Position = px(0, TOP_H), ZIndex = 2 })
bar.Parent = status
local fillGradient = fill:FindFirstChildOfClass('UIGradient')
local function setFillTone(name)
	local t = Tone[name]
	fillGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.top), ColorSequenceKeypoint.new(0.7, t.base), ColorSequenceKeypoint.new(1, t.base) })
end

-- Power packs: "+N" with the Power icon, and the Robux price tucked under the right corner.
local PACKS = { 'PowerPack1', 'PowerPack2', 'PowerPack3' }
local packLabels = {}
local packs = Kit.new('Frame', { Name = 'Packs', BackgroundTransparency = 1, Position = px(0, TOP_H + BAR_H + 12), Size = px(BAR_W, PACK_H + 14), Parent = status })
local PACK_W = math.floor((BAR_W - 2 * 12) / 3)
for i, key in PACKS do
	local entry = Products.ByKey[key]
	local holder = Kit.blockButton({ Name = key, Tone = entry.Tone, Width = PACK_W, Height = PACK_H, Position = px((i - 1) * (PACK_W + 12), 0), Studs = 16 })
	holder.Parent = packs
	Kit.icon3d('Power', 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -12, 0.5, -4), ZIndex = 6 }).Parent = holder.Body
	packLabels[key] = Kit.text({ Name = 'Amount', Text = '+0', TextSize = 30, Stroke = Color.ink, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Right, Position = px(40, -3), Size = UDim2.new(1, -52, 1, 0), ZIndex = 7, Parent = holder.Body })
	local price = tostring(entry.Price)
	local tag = Kit.new('Frame', { Name = 'Price', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 1, -10), Size = px(20 + Kit.textWidth(price, 18), 22), ZIndex = 8, Parent = holder })
	Kit.robux(18, { Color = Tone.green.top, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 8 }).Parent = tag
	Kit.text({ Name = 'Label', Text = price, TextSize = 18, TextColor3 = Tone.green.top, Stroke = Color.ink, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(20, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 8, Parent = tag })
	Motion.button(holder, function() buy(key) end)
end
local function paintPacks(need)
	for _, key in PACKS do packLabels[key].Text = '+' .. short(Products.powerAmount(key, need)) end
end

---------------------------------------------------------------------------------------------- top-centre
local hint = Kit.text({ Name = 'Hint', Text = '', TextSize = 28, Stroke = Color.ink, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = px(820, 36), RichText = true, Parent = root })
hint.TextScaled = true
Kit.new('UITextSizeConstraint', { MaxTextSize = 28, MinTextSize = 12, Parent = hint })

-- Notices stack under the hint, newest on top, three at most: small studded blocks in the notice's colour.
-- (They start at y 92: Goals.client's NEXT GOAL line sits between the hint and them, y 50..86.)
local toastStack = Kit.new('Frame', { Name = 'Toasts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 94), Size = px(720, 170), ZIndex = 40, Parent = noticeRoot })
Kit.new('UIListLayout', { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastStack })
local toastCount = 0
toast = function(text, tone)
	text = tostring(text)
	toastCount += 1
	local width = math.clamp(Kit.textWidth(text, 22) + 40, 220, 700)
	local slot = Kit.new('Frame', { Name = 'Toast' .. toastCount, BackgroundTransparency = 1, Size = px(width, 46), LayoutOrder = -toastCount, Parent = toastStack })
	local t = Kit.block({ Name = 'Toast', Tone = tone or 'green', Width = width, Height = 42, Studs = 16, Shadow = 3, ZIndex = 41 })
	Kit.text({ Name = 'Text', Text = text, TextSize = 22, Stroke = Color.ink, StrokeThickness = 3, Position = px(10, -1), Size = UDim2.new(1, -20, 1, 0), ZIndex = 44, Parent = t.Body })
	t.Parent = slot
	Motion.toast(t, 3)
	task.delay(3.5, function() slot:Destroy() end)
	local slots = {}
	for _, s in toastStack:GetChildren() do
		if s:IsA('Frame') then table.insert(slots, s) end
	end
	table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 4, #slots do slots[i]:Destroy() end
end
-- Server notices are plain strings; pick a colour from what they say.
local function noticeTone(text)
	local lower = string.lower(text)
	if lower:find('rebirth') and not lower:find('need') then return 'red' end
	if lower:find('equipped') or lower:find('bought') or lower:find('cleared') or lower:find('thanks') then return 'green' end
	if lower:find('reach') or lower:find('walk') or lower:find('need') or lower:find('first') or lower:find('find') then return 'orange' end
	if lower:find('later build') or lower:find('soon') then return 'blue' end
	return 'purple'
end

-- The rebirth moment: "Rebirth n!", the new multiplier and the lane it opened pop up in the middle, then float
-- away. The server's Cinematic { Kind = 'Rebirth' } starts it; a Rebirths rise with no Cinematic does too.
local lastMoment = 0
local function rebirthMoment(n, unlocked)
	if n <= lastMoment then return end
	lastMoment = n
	local holder = Kit.new('Frame', { Name = 'RebirthMoment', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = px(700, 170), ZIndex = 60, Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local title = Kit.text({ Name = 'Title', Text = 'Rebirth ' .. n .. '!', TextSize = 84, Stroke = Color.ink, StrokeThickness = 7, Size = UDim2.new(1, 0, 0, 96), ZIndex = 61, Parent = holder })
	Kit.gradient(Color.white, Kit.hex('FF6B7A'), 0.55).Parent = title
	local text = times(rebirthMultiplier(n)) .. ' Power forever!'
	if type(unlocked) == 'string' and unlocked ~= '' then text ..= '  ' .. unlocked .. ' unlocked!' end
	local line = Kit.text({ Name = 'Multiplier', Text = text, TextSize = 40, TextColor3 = Tone.yellow.top, Stroke = Color.ink, StrokeThickness = 4.5, Position = px(0, 100), Size = UDim2.new(1, 0, 0, 48), ZIndex = 61, Parent = holder })
	line.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 40, Parent = line })
	Motion.tween(scale, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	task.delay(2.2, function()
		Motion.tween(holder, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = UDim2.fromScale(0.5, 0.38) })
		for _, t in { title, line } do
			Motion.tween(t, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { TextTransparency = 1 })
			local s = t:FindFirstChildOfClass('UIStroke')
			if s then Motion.tween(s, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Transparency = 1 }) end
		end
		task.wait(0.45)
		holder:Destroy()
	end)
end

---------------------------------------------------------------------------------------------- windows
-- One window open at a time across every script: PlayerGui's HoodWindow attribute names the open one.
local current -- the open window
local function closePanel()
	local p = current
	if not p then return end
	current = nil
	Motion.blur(p.Name, false)
	Motion.close(p.Overlay, p.Panel)
	if playerGui:GetAttribute('HoodWindow') == p.Name then playerGui:SetAttribute('HoodWindow', '') end
end
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local open = playerGui:GetAttribute('HoodWindow')
	if current and open ~= current.Name then closePanel() end
end)
local function makePanel(name, title, icon, tone, w, h)
	local panel, well, closeHit, overlay, header = Kit.window(panelRoot, { Name = name, Title = title, Icon = icon, Tone = tone, Width = w, Height = h })
	overlay.Visible = false
	-- Taps on the dimmed backdrop close the window; taps on the window itself stop there.
	local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
	backdrop.Activated:Connect(closePanel)
	Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
	Motion.button(closeHit.Parent, closePanel)
	return { Name = name, Overlay = overlay, Panel = panel, Well = well, Header = header }
end
local function openPanel(p)
	if current == p then
		closePanel()
		return
	end
	if current then
		Motion.blur(current.Name, false)
		current.Overlay.Visible = false
		current = nil
	end
	current = p
	playerGui:SetAttribute('HoodWindow', p.Name)
	if p.Open then p.Open() end
	Motion.blur(p.Name, true)
	Motion.open(p.Overlay, p.Panel, 0.35)
end

local function body(parent, text, props)
	props = props or {}
	return Kit.text({
		Name = props.Name or 'Body', Text = text, FontFace = Kit.Font.body, TextSize = props.TextSize or 18, TextColor3 = props.Color or Color.white,
		Stroke = props.Stroke, StrokeThickness = props.StrokeThickness, TextXAlignment = props.Align or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center, TextWrapped = true, Position = props.Position, Size = props.Size,
		AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 25, Parent = parent,
	})
end
-- Replace a window's action button (a block button bakes its tone in, so state changes rebuild it).
local function actionIn(parent, old, props, onClick)
	if old then old:Destroy() end
	props.ZIndex = props.ZIndex or 26
	local holder = Kit.blockButton(props)
	holder.Parent = parent
	if not props.Disabled and onClick then Motion.button(holder, onClick) end
	return holder
end

---------------------------------------------------------------- REBIRTH (user_27)
-- "Rebirth n" over a box with the Power icon and "Nx", a green arrow, "Rebirth n+1" over "(N+1)x"; "Rebirth resets
-- your Power" in red; the bar toward the requirement; the Rebirth button, and Skip Rebirth once its product id is set.
local RB_W, RB_H = 660, 484
local rebirth = makePanel('Rebirth', 'Rebirth', 'Rebirth', 'cyan', RB_W, RB_H)
local rw = rebirth.Well
local WELL_W = RB_W - 24
local BOX_W, BOX_H = 236, 76
local fromTitle = Kit.text({ Name = 'From', Text = 'Rebirth 0', TextSize = 34, Stroke = Color.ink, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 24 + BOX_W / 2, 0, 12), Size = px(BOX_W + 40, 40), ZIndex = 26, Parent = rw })
local toTitle = Kit.text({ Name = 'To', Text = 'Rebirth 1', TextSize = 34, Stroke = Color.ink, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -24 - BOX_W / 2, 0, 12), Size = px(BOX_W + 40, 40), ZIndex = 26, Parent = rw })
local function multiplierBox(name, x, anchor)
	local box = Kit.block({ Name = name, Tone = 'cyan', Width = BOX_W, Height = BOX_H, Position = x, AnchorPoint = anchor, Studs = 20, ZIndex = 25 })
	box.Parent = rw
	Kit.icon3d('Power', 78, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, -2), ZIndex = 28 }).Parent = box.Body
	local value = Kit.text({ Name = 'Value', Text = '1x', TextSize = 46, Stroke = Color.ink, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(92, -2), Size = UDim2.new(1, -96, 1, 0), ZIndex = 28, Parent = box.Body })
	return value
end
local fromValue = multiplierBox('FromBox', px(24, 56), Vector2.zero)
local toValue = multiplierBox('ToBox', UDim2.new(1, -24, 0, 56), Vector2.new(1, 0))
-- The green arrow between them: the Evolve icon model turned to point right.
local arrow
if IconModels and type(IconModels.build) == 'function' then
	local ok, model = pcall(IconModels.build, 'Evolve', 1)
	if ok and typeof(model) == 'Instance' then
		pcall(function() model:PivotTo(CFrame.Angles(0, 0, math.pi / 2)) end)
		arrow = Kit.viewport(model, 104, { Direction = typeof(IconModels.View) == 'Vector3' and IconModels.View or nil, ZIndex = 27 })
	end
end
arrow = arrow or Kit.text({ Name = 'Arrow', Text = '>', TextSize = 80, TextColor3 = Tone.green.top, Stroke = Color.ink, StrokeThickness = 6, Size = px(104, 104), ZIndex = 27 })
arrow.Name = 'Arrow'
arrow:SetAttribute('PreviewImage', 'icon3d:EvolveRight')
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.new(0.5, 0, 0, 56 + BOX_H / 2)
arrow.Parent = rw
-- (the lane the next rebirth opens, under the right box: "Unlocks BAY 3!")
local unlockLine = Kit.text({ Name = 'Unlock', Text = '', TextSize = 22, TextColor3 = Tone.green.top, Stroke = Color.ink, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -24 - BOX_W / 2, 0, 56 + BOX_H + 6), Size = px(BOX_W + 40, 26), ZIndex = 26, Parent = rw })
local warning = Kit.text({ Name = 'Warning', Text = 'Rebirth resets your Power', TextSize = 32, TextColor3 = Kit.hex('FF3B3B'), Stroke = Color.ink, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Size = px(WELL_W - 20, 38), ZIndex = 26, Parent = rw })
body(rw, 'You keep your Cash, guns, shoes and cleared stages', { Name = 'Keeps', TextSize = 18, Stroke = Color.ink, StrokeThickness = 2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 202), Size = px(WELL_W - 40, 22), ZIndex = 26 })
local RBAR_W = WELL_W - 120
local BAR_Y = 234
local rebirthBar, rebirthFill, rebirthBarText = Kit.bar({ Name = 'Progress', Width = RBAR_W, Height = 48, Tone = 'cyan', Value = 0, Text = '0 / 0 Power', TextSize = 30, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 26, 0, BAR_Y), ZIndex = 25 })
rebirthBar.Parent = rw
Kit.icon3d('Power', 92, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 26 - RBAR_W / 2 - 4, 0, BAR_Y + 24), ZIndex = 29 }).Parent = rw
local rebirthAction, skipAction
local confirmUntil = 0
local ACTION_Y = 300
local function skipLive() return Products.idOf('SkipRebirth') ~= 0 end
local function rebirthUpdate()
	local power, n = num('Power', 0), rebirthsNow()
	local need = rebirthNeed(n)
	fromTitle.Text = 'Rebirth ' .. n
	toTitle.Text = 'Rebirth ' .. (n + 1)
	fromValue.Text = times(rebirthMultiplier(n))
	toValue.Text = times(rebirthMultiplier(n + 1))
	local unlock = player:GetAttribute('RebirthUnlock')
	unlockLine.Text = (type(unlock) == 'string' and unlock ~= '') and ('Unlocks ' .. unlock .. '!') or ''
	rebirthFill.Size = UDim2.fromScale(math.clamp(power / need, 0, 1), 1)
	rebirthBarText.Text.Text = short(power) .. ' / ' .. short(need) .. ' Power'
	local maxed = RebirthRules and type(RebirthRules.Max) == 'number' and n >= RebirthRules.Max
	local ready = power >= need and not maxed
	local confirming = ready and os.clock() < confirmUntil
	local skip = skipLive() and not maxed
	local text = maxed and 'Max rebirths!' or confirming and 'Tap again!' or (ready and 'Rebirth' or ('Need ' .. short(need - power) .. ' more'))
	local key = (ready and 'ready' or 'locked') .. (confirming and '+confirm' or '') .. (skip and '+skip' or '')
	if rebirthAction and rebirthAction:GetAttribute('Key') == key then
		local label = rebirthAction:FindFirstChild('Label', true)
		if label then label.Text = text end
		return
	end
	local w = skip and 260 or 300
	rebirthAction = actionIn(rw, rebirthAction, {
		Name = 'Action', Tone = confirming and 'orange' or 'blue', Disabled = not ready, Text = text, TextSize = ready and 38 or 26,
		Icon = 'Rebirth', IconSize = 70, IconInset = 2, Width = w, Height = 70, Studs = 20,
		AnchorPoint = Vector2.new(0.5, 0), Position = skip and UDim2.new(0.5, -WELL_W / 4 + 6, 0, ACTION_Y) or UDim2.new(0.5, 0, 0, ACTION_Y),
	}, function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.get('Rebirth'):FireServer()
			closePanel()
		else
			confirmUntil = os.clock() + 4
			task.delay(4.1, function() if current == rebirth then rebirthUpdate() end end)
		end
		rebirthUpdate()
	end)
	rebirthAction:SetAttribute('Key', key)
	if skipAction then
		skipAction:Destroy()
		skipAction = nil
	end
	if skip then
		local entry = Products.ByKey.SkipRebirth
		skipAction = actionIn(rw, nil, {
			Name = 'Skip', Tone = 'cyan', Text = 'Skip Rebirth', TextSize = 28, Icon = 'Rebirth', IconSize = 64, IconInset = 2, Width = 260, Height = 70, Studs = 20,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, WELL_W / 4 - 6, 0, ACTION_Y),
		}, function() buy('SkipRebirth') end)
		local price = Kit.new('Frame', { Name = 'Price', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 22, 0, 2), Size = px(34 + Kit.textWidth(entry.Price, 30), 40), ZIndex = 32, Parent = skipAction })
		Kit.robux(32, { Color = Tone.green.top, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 32 }).Parent = price
		Kit.text({ Name = 'Label', Text = tostring(entry.Price), TextSize = 30, TextColor3 = Kit.hex('E8FF6A'), Stroke = Color.ink, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(34, 0), Size = UDim2.new(1, -34, 1, 0), ZIndex = 32, Parent = price })
	end
end
rebirth.Open = function()
	confirmUntil = 0
	rebirthUpdate()
end
rebirth.Update = rebirthUpdate

---------------------------------------------------------------- GUNS
-- Every gun of the ladder: its model, name and multiplier, and EQUIPPED / OWNED / its Cash price. Guns are bought
-- and equipped at the ARMORY (the server checks you stand at the gun), so this window shows the way there.
local guns = makePanel('Guns', 'Guns', 'Gun', 'blue', 820, 500)
body(guns.Well, 'Buy and equip guns at the Armory: a better gun = more Power every shot!', { Name = 'Note', TextSize = 18, Stroke = Color.ink, StrokeThickness = 2, Position = px(12, 6), Size = UDim2.new(1, -24, 0, 26), ZIndex = 26 })
local gunGrid = Kit.new('ScrollingFrame', {
	Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(6, 38), Size = UDim2.new(1, -12, 1, -44), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = guns.Well,
})
Kit.new('UIGridLayout', { CellSize = px(142, 178), CellPadding = px(10, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = gunGrid })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), Parent = gunGrid })
local function gunTone(gun)
	local c = gun.Color
	return { top = c:Lerp(Color.white, 0.45), base = c, lip = c:Lerp(Color.ink, 0.35), stroke = c:Lerp(Color.ink, 0.7) }
end
local function gunCard(gun, owned, cash)
	local card = Kit.block({ Name = gun.Id, Tone = gunTone(gun), Width = 142, Height = 178, Studs = 18, ZIndex = 25 })
	card.LayoutOrder = gun.Tier
	local art
	if GunModels and type(GunModels.build) == 'function' then
		local ok, model = pcall(GunModels.build, gun.Id, 1)
		if ok and typeof(model) == 'Instance' then
			local view = typeof(GunModels.View) == 'Vector3' and GunModels.View or nil
			art = Kit.viewport(model, Vector2.new(136, 82), { Direction = view, Yaw = -70, Pitch = 12, ZIndex = 28 })
		end
	end
	art = art or Kit.icon3d('Gun', 82, { ZIndex = 28 })
	art:SetAttribute('PreviewImage', 'gun:' .. gun.Id)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 4)
	art.Parent = card.Body
	local name = Kit.text({ Name = 'Title', Text = gun.Name, TextSize = 20, Stroke = Color.ink, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.new(1, -10, 0, 24), ZIndex = 28, Parent = card.Body })
	name.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 20, Parent = name })
	Kit.text({ Name = 'Multiplier', Text = times(gun.Multiplier) .. ' Power', TextSize = 20, TextColor3 = Tone.yellow.top, Stroke = Color.ink, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.new(1, -8, 0, 22), ZIndex = 28, Parent = card.Body })
	local state = GunRules and owned and GunRules.state(owned, gun.Id) or ((player:GetAttribute('EquippedGun') or Guns.Starter) == gun.Id and 'Equipped' or 'Locked')
	local chip = Kit.block({ Name = 'State', Tone = state == 'Equipped' and 'green' or state == 'Owned' and 'blue' or 'dark', Width = 120, Height = 32, Studs = false, Shadow = 2, Rim = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), ZIndex = 28 })
	chip.Parent = card.Body
	if state == 'Equipped' or state == 'Owned' then
		Kit.text({ Name = 'Text', Text = state, TextSize = 20, Stroke = Color.ink, StrokeThickness = 3, Size = UDim2.fromScale(1, 1), ZIndex = 31, Parent = chip.Body })
	else
		Kit.icon3d('Cash', 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), ZIndex = 31 }).Parent = chip.Body
		Kit.text({ Name = 'Text', Text = gun.Cost <= 0 and 'Free' or short(gun.Cost), TextSize = 21, TextColor3 = cash >= gun.Cost and Tone.green.top or Color.white, Stroke = Color.ink, StrokeThickness = 3, Position = px(16, 0), Size = UDim2.new(1, -16, 1, 0), ZIndex = 31, Parent = chip.Body })
	end
	return card
end
-- Gun cards hold live 3D models, so they are rebuilt only when what they show changes.
local function gunsKey()
	local cash, affordable = cashNow(), 0
	for _, gun in Guns.List do
		if cash >= gun.Cost then affordable += 1 end
	end
	return tostring(player:GetAttribute('OwnedGuns')) .. '|' .. tostring(player:GetAttribute('EquippedGun')) .. '|' .. affordable
end
local shownGuns
local function fillGuns()
	shownGuns = gunsKey()
	for _, child in gunGrid:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	local owned = GunRules and GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
	local cash = cashNow()
	for _, gun in Guns.List do gunCard(gun, owned, cash).Parent = gunGrid end
end
guns.Open = fillGuns
guns.Update = function()
	if gunsKey() ~= shownGuns then fillGuns() end
end

---------------------------------------------------------------- REWARDS
local rewards = makePanel('Rewards', 'Rewards', 'Rewards', 'purple', 680, 400)
local days = Kit.new('Frame', { Name = 'Days', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = px(7 * 80 + 6 * 8, 120), ZIndex = 24, Parent = rewards.Well })
Kit.new('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = days })
-- The day tiles hold 3D icons, so they are built the first time the window opens.
rewards.Open = function()
	if days:FindFirstChild('Day1') then return end
	for day = 1, 7 do
		local big = day == 7
		local tile = Kit.block({ Name = 'Day' .. day, Tone = big and 'orange' or 'cyan', Width = 80, Height = 112, Studs = 16, ZIndex = 25 })
		tile.LayoutOrder = day
		tile.Parent = days
		Kit.text({ Name = 'Day', Text = 'Day ' .. day, TextSize = 20, Stroke = Color.ink, StrokeThickness = 3, Position = px(0, 4), Size = UDim2.new(1, 0, 0, 22), ZIndex = 28, Parent = tile.Body })
		Kit.icon3d(big and 'Rewards' or 'Cash', big and 66 or 56, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 64), ZIndex = 28 }).Parent = tile.Body
		Kit.text({ Name = 'Lock', Text = '?', TextSize = 22, Stroke = Color.ink, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 22), ZIndex = 28, Parent = tile.Body })
	end
end
body(rewards.Well, 'Log in every day for bigger and bigger rewards. Daily rewards arrive in the next update!', { TextSize = 20, Stroke = Color.ink, StrokeThickness = 2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = px(560, 52) })
actionIn(rewards.Well, nil, { Name = 'Claim', Tone = 'green', Disabled = true, Text = 'Coming soon', TextSize = 30, Width = 300, Height = 64, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18) })

actions.Store = function()
	closePanel()
	openStore()
end
actions.Rebirth = function() openPanel(rebirth) end
actions.Guns = function() openPanel(guns) end
actions.Rewards = function() openPanel(rewards) end

---------------------------------------------------------------------------------------------- live values
local shown = Instance.new('NumberValue') -- the Power the HUD is showing; tweens up for the count-up
shown.Changed:Connect(function(v) powerLabel.Text = short(v) end)

-- A range's own colour for the hint (its label's "xN Power" colour, which the built lane carries as TextColor;
-- the station row's colour until the lane has streamed in).
local laneColor = {}
local function rangeColor(id, row)
	if laneColor[id] then return laneColor[id] end
	local map = ActiveMap.get()
	local lane = map and map.Lobby and map.Lobby:FindFirstChild('Training_' .. id, true)
	local c = lane and lane:GetAttribute('TextColor')
	if typeof(c) == 'Color3' then laneColor[id] = c return c end
	return row.Color or Color3.new(1, 1, 1)
end
-- Ranges open by rebirths (Skins.Stations[i].Rebirths; the server's TrainingNeed is the count the lane you stand
-- in needs, BestLane your best open lane).
local function laneOpen(lane)
	return rebirthsNow() >= (type(lane.Rebirths) == 'number' and lane.Rebirths or 0)
end
local function lockText(lane)
	local n = num('TrainingNeed', 0)
	if n <= 0 then n = type(lane.Rebirths) == 'number' and lane.Rebirths or 0 end
	return n .. (n == 1 and ' rebirth' or ' rebirths')
end
local function hintText(power)
	-- In a stage with targets up, Waves.client's "N LEFT" counter takes the hint's place at the top centre.
	local waveLeft = player:GetAttribute('WaveLeft')
	if type(waveLeft) == 'number' and waveLeft > 0 then return '' end
	local station = player:GetAttribute('TrainingStation') or ''
	local need = rebirthNeed()
	local goal = power >= need and '<font color="#8CF06A">Rebirth ready!</font> Tap Rebirth'
		or ('Rebirth at <font color="#8CF06A">' .. short(need) .. '</font>')
	local gun = '<font color="#FFE76A">Gun ' .. times(gunMultiplier()) .. '</font>'
	if station:find('Locked:') then
		local lane = Skins.StationById[station:sub(8)]
		return '<font color="#FF8A8A">' .. (lane and lane.Name or 'This range') .. ' needs ' .. (lane and lockText(lane) or 'more') .. '</font>  •  ' .. goal
	end
	-- A new player follows Lobby.client's floor guide (its GuidePhase, in the guide's gold): first to the free
	-- lane, then, once Stage 1 is open, out through the door, even from the lane.
	local phase = player:GetAttribute('GuidePhase')
	if phase == 'exit' then
		return 'The street is open! Head through the <font color="#F0BA50">door</font> ▸'
	end
	if station == '' then
		if phase == 'lane' or (phase == nil and rebirthsNow() == 0 and power < need * 0.25) then
			local lane = Skins.StationById[player:GetAttribute('BestLane') or ''] or Skins.Stations[1]
			if not player:GetAttribute('BestLane') then
				for _, s in Skins.Stations do
					if laneOpen(s) and s.Multiplier >= lane.Multiplier then lane = s end
				end
			end
			return 'Go to <font color="#F0BA50">' .. string.upper(lane.Name) .. '</font> and shoot! (' .. times(lane.Multiplier) .. ')'
		end
		return 'Step into a shooting range  •  ' .. gun .. '  •  ' .. goal
	end
	-- In a lane: the range's multiplier (in the lane's colour) and your gun's, side by side. A narrow hint (phones:
	-- under 700 design px) gets the short form, so the line stays big enough to read.
	local range = Skins.StationById[station]
	if range then
		local multipliers = '<font color="#' .. rangeColor(station, range):ToHex() .. '">Range ' .. times(range.Multiplier)
			.. '</font>  •  ' .. gun
		if hint.Size.X.Offset < 700 then return 'Tap SHOOT  •  ' .. multipliers end
		return 'Click / tap to shoot  •  ' .. multipliers .. '  •  ' .. goal
	end
	return 'Click / tap to shoot  •  ' .. gun .. '  •  ' .. goal
end

local lastPower, lastCash, lastRebirths
local function refreshCounters()
	local cash, n = cashNow(), rebirthsNow()
	cashCount.Text = short(cash)
	rebirthCount.Text = short(n)
	if lastCash and cash > lastCash then Motion.pop(cashIcon, 0.3) end
	if lastRebirths and n > lastRebirths then
		Motion.pop(rebirthIcon, 0.3)
		task.delay(0.5, function() rebirthMoment(n) end)
	end
	lastCash, lastRebirths = cash, n
end
local function refresh()
	local power = num('Power', nil)
	if power == nil then
		hint.Text = 'Getting your block ready...'
		return
	end
	local n = rebirthsNow()
	local need = rebirthNeed(n)
	if lastPower == nil then
		shown.Value = power
	elseif power < lastPower then
		Motion.tween(shown, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Value = power }) -- also stops a running count-up
	elseif power > lastPower then
		Motion.tween(shown, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = power })
		Motion.pop(powerLabel, 0.07)
	end
	powerLabel.Text = short(shown.Value)
	lastPower = power
	multiplierLabel.Text = 'Multiplier: ' .. times(totalMultiplier())
	local ready = power >= need
	barText.Left.Text = 'Rebirth ' .. n
	barText.Right.Text = ready and 'Rebirth ready!' or (short(power) .. ' / ' .. short(need))
	fill.Size = UDim2.fromScale(math.clamp(power / need, 0, 1), 1)
	setFillTone(ready and 'green' or 'orange')
	paintPacks(need)
	local percent = math.clamp(math.floor(power / need * 100), 0, 100)
	rebirthBadge.Text = percent .. '%'
	setRebirthReady(percent >= 100)
	hint.Text = hintText(power)
	if current and current.Update then current.Update() end
end
for _, key in { 'Power', 'TrainingStation', 'TrainingNeed', 'BestLane', 'GunMultiplier', 'EquippedGun', 'OwnedGuns', 'GuidePhase', 'WaveLeft', 'RebirthNeed', 'RebirthMultiplier', 'RebirthNextMultiplier', 'RebirthUnlock', 'ShoeMultiplier', 'ShotMultiplier', 'Pass_DoubleRep' } do
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
for _, key in { 'Cash', 'Rebirths' } do
	player:GetAttributeChangedSignal(key):Connect(function()
		refreshCounters()
		refresh()
	end)
end

-- Notices from the server, the profile snapshot and its updates (Cash and Rebirths before the attributes land).
local function applyProfile(profile)
	if type(profile) ~= 'table' then return end
	snapshot.Cash = type(profile.Cash) == 'number' and profile.Cash or snapshot.Cash
	snapshot.Rebirths = type(profile.Rebirths) == 'number' and profile.Rebirths or snapshot.Rebirths
	refreshCounters()
	refresh()
end
-- Lobby props that aren't built yet (reward crates, the WORLD 2 portal) carry a ComingSoon prompt.
game:GetService('ProximityPromptService').PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute('ComingSoon') then toast((prompt.ObjectText ~= '' and prompt.ObjectText or 'This') .. ' is coming soon!', 'blue') end
end)
-- A finished purchase: say thanks (the server grants it and the attributes update the screen).
pcall(function()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, bought)
		if who == player and bought then toast('Thanks! Your pass is on.', 'green') end
	end)
end)
task.spawn(function()
	Net.get('Notice').OnClientEvent:Connect(function(message) toast(message, noticeTone(tostring(message))) end)
	Net.get('Cinematic').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'Rebirth' and type(info.Rebirths) == 'number' then rebirthMoment(info.Rebirths, info.Unlocked) end
	end)
	Net.get('ProfileUpdated').OnClientEvent:Connect(applyProfile)
	for _ = 1, 10 do
		local ok, response = pcall(function() return Net.get('RequestSnapshot'):InvokeServer() end)
		if ok and type(response) == 'table' and response.Ready then
			applyProfile(response.Profile)
			break
		end
		task.wait(2)
	end
end)

---------------------------------------------------------------------------------------------- layout
-- Shoot.client's round SHOOT button (unscaled real pixels: 112 wide, 150 from the right edge) sits at the
-- bottom right while you train. On narrow screens the bottom block slides left to stay clear of it.
-- PC: the column sits at the reference's height with the counters under it; phones keep it high (clear of the
-- thumbstick) with the counters over it.
local SHOOT_RIGHT, SHOOT_SIZE = 150, 112
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	panelFit(panelGui.AbsoluteSize.X > 0 and panelGui.AbsoluteSize or abs)
	noticeFit(noticeGui.AbsoluteSize.X > 0 and noticeGui.AbsoluteSize or abs)
	local k = Kit.scaleFor(abs)
	local w, h = abs.X / k, abs.Y / k
	local phone = math.min(abs.X, abs.Y) <= 500
	if phone then
		counters.Position = px(LEFT, 4)
		column.Position = px(LEFT, 110)
		offers.Position = UDim2.new(1, -16, 0, 0)
	else
		local top = math.max(60, math.floor(h * 0.24))
		column.Position = px(LEFT, top)
		counters.Position = px(LEFT, top + COLUMN_H + 22)
		offers.Position = UDim2.new(1, -16, 0, math.max(60, math.floor(h * 0.2)))
	end
	local barWidth = BAR_W
	local shootLeft = (abs.X - SHOOT_RIGHT - SHOOT_SIZE) / k
	local x = math.min(w / 2, shootLeft - 12 - barWidth / 2)
	status.Position = UDim2.new(0, x, 1, -8)
	hint.Size = px(math.max(360, math.min(900, w - 2 * (LEFT + COLUMN + 24))), 36)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
panelGui.Parent = playerGui
noticeGui.Parent = playerGui
relayout()
refreshCounters()
refresh()
