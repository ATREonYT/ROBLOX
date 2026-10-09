-- Player HUD for +1 Hood Evolution: a 1:1 copy of the user's reference simulator HUD (brief 18, user_26 and the
-- soldier game's video), with our features in its slots:
--   left column    the wide Store block, then Shoes | Rebirth and Guns | Quest (the reference's Pets | Rebirth,
--                  Items | Quest; Shoes.client puts its button in the slot named ShoesSlot): square studded blocks,
--                  black outlines, big 3D icons popping out of their tops, captions low on their faces; the column is
--                  centred on the screen like the reference's
--   counters       bottom-left: Rebirths (the reference's small rebirth row) and Cash (its big trophy row)
--   right column   offer cards: 2x Cash in the "2x Wins" slot, 2x Power in the "+2x Power" slot, "ONLY <Robux> n"
--   bottom-centre  "Multiplier: Nx", the Power icon and count, the studded bar (the reference's "Level 175 .. MAX LEVEL";
--                  here your next rebirth), three Robux power packs, and the Auto Fight pass in the "2x Speed" slot
--   top            the hint in the reference's first timer line ("Next DOCTOR DOOM boss fight in: 9:07"); Goals.client's
--                  goal line is the second ("Next RAID in: 3:26"); the daily Rewards gift in the top-left event slot
--   windows        Rebirth (like user_27), Guns, Quest (the goal chain) and Rewards as Kit.windows; the Store is
--                  Store.client's, Shoes is Shoes.client's
-- Every size is measured on the reference at its own size (2000x1144 px = 1516x867 dp, where UIKit's UIScale is 1.124,
-- so one design px here is 1.48 reference px) and authored in UIKit's design pixels; Kit.screen fits it to any screen.
-- It only reads state: player attributes the server sets (LobbyService: Power, TrainingStation, Cash, Rebirths; the
-- rebirth service: RebirthNeed, RebirthMultiplier; GunService: EquippedGun, GunMultiplier, OwnedGuns; ShoeService:
-- ShoeMultiplier; StoreService: Pass_<Key>; GoalService: GoalStep) and the profile snapshot.
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
local GoalRules = optional('GoalRules')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, Tone, short = Kit.Color, Kit.Tone, Kit.short
local BLACK = Color.black
local px = UDim2.fromOffset
local hex = Kit.hex
-- The Power icon: the reference's orange flexed arm once IconModels has it, else our glove. iconOr(a, b, ...): the first
-- id IconModels can show (an uploaded render or a live model; brief 19: ICONS adds renders like Sneaker or DoubleCash).
local POWER = Kit.iconOr('Muscle', 'Power')
local iconOr = Kit.iconOr

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
local placeToasts -- (forward)
local function buy(key)
	local ok = Products.canBuy(key)
	local entry = Products.ByKey[key]
	if not ok then
		toast((entry and entry.Title or 'This') .. ' is coming soon!', 'blue')
		return
	end
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

-- Outlined display text: black stroke ~12% of the size, like every label of the reference.
local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	return Kit.text(props)
end
-- A top -> bottom gradient on a label's fill (the reference's gold numbers, its white -> pink rebirth count).
local function fillText(t, top, bottom)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = t })
	return t
end

---------------------------------------------------------------------------------------------- left column
-- The reference: a wide Store block (187 x 66) over 81 px squares, 15 apart side by side and 13 apart row to row; the
-- icons fill most of each square and rise over its top edge. (Every size is the whole look, outline included.)
local SQ, GAP_X, GAP_Y = 81, 15, 13
local WIDE_W, WIDE_H, WIDE_GAP = 187, 66, 15
local GRID_X = math.floor((WIDE_W - (2 * SQ + GAP_X)) / 2)
local ROW1 = WIDE_H + WIDE_GAP
local ROW2 = ROW1 + SQ + GAP_Y
local COLUMN_W, COLUMN_H = WIDE_W, ROW2 + SQ
local LEFT, POP, ICON = 24, 14, 84 -- (LEFT: the reference's 36 px margin at its size)
local column = Kit.new('Frame', { Name = 'Actions', BackgroundTransparency = 1, Position = px(LEFT, 160), Size = px(COLUMN_W, COLUMN_H), Parent = root })
local actions = {} -- filled with the button callbacks once the windows exist
local function call(name) return function() if actions[name] then actions[name]() end end end

local function actionButton(props)
	local holder, hit, icon, caption = Kit.actionButton(props)
	holder.Parent = column
	Motion.button(holder, props.OnClick)
	return holder, icon, caption, hit
end
local storeButton = actionButton({ Name = 'Store', Tone = 'gold', Width = WIDE_W, Height = WIDE_H, Position = px(0, 0), Text = 'Store', TextSize = 24, LabelY = 0.72, Icon = iconOr('Basket', 'Shop'), IconSize = 86, IconX = -5, Pop = 26, OnClick = call('Store') })
Motion.shine(storeButton.Body, 4, UDim.new(0, 3))
-- (Shoes.client builds its Shoes button in this slot, the reference's Pets square, with the same Kit.actionButton)
Kit.new('Frame', { Name = 'ShoesSlot', BackgroundTransparency = 1, Position = px(GRID_X, ROW1), Size = px(SQ, SQ), Parent = column })
local rebirthButton = actionButton({ Name = 'Rebirth', Tone = 'coral', Width = SQ, Height = SQ, Position = px(GRID_X + SQ + GAP_X, ROW1), Text = 'Rebirth', TextSize = 19, Icon = 'Rebirth', IconSize = ICON, Pop = POP, OnClick = call('Rebirth') })
actionButton({ Name = 'Guns', Tone = 'gold', Width = SQ, Height = SQ, Position = px(GRID_X, ROW2), Text = 'Guns', TextSize = 21, Icon = 'Gun', IconSize = ICON, Pop = POP, OnClick = call('Guns') })
actionButton({ Name = 'Quest', Tone = 'brown', Width = SQ, Height = SQ, Position = px(GRID_X + SQ + GAP_X, ROW2), Text = 'Quest', TextSize = 20, Icon = iconOr('Quest', 'Trophy'), IconSize = ICON, Pop = POP, OnClick = call('Quest') })
-- "100%" over Rebirth's right edge, like the reference: how close the next rebirth is; it wobbles when you can rebirth.
local rebirthBadge = Kit.sticker(rebirthButton, { Name = 'Percent', Text = '0%', TextSize = 24, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 22, 0.56, 0), Width = 90, ZIndex = 9 })
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

-- Counters (the reference's bottom-left: an icon and a big outlined number each; Rebirths in its small rebirth row,
-- Cash in its big gold trophy row).
local COUNTERS_W, COUNTERS_H = 300, 128
local counters = Kit.new('Frame', { Name = 'Counters', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = px(COUNTERS_W, COUNTERS_H), Parent = root })
local function counter(name, iconId, centreY, iconSize, iconX, textSize, top, bottom)
	local row = Kit.new('Frame', { Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = px(0, centreY), Size = px(COUNTERS_W, textSize + 12), Parent = counters })
	local icon = Kit.icon3d(iconId, iconSize, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, iconX, 0.5, 0), ZIndex = 2 })
	icon.Parent = row
	local value = fillText(label({ Name = 'Value', Text = '0', TextSize = textSize, TextXAlignment = Enum.TextXAlignment.Left, Position = px(81, 0), Size = UDim2.new(1, -81, 1, 0), ZIndex = 2, Parent = row }), top, bottom)
	return value, icon
end
local rebirthCount, rebirthIcon = counter('Rebirths', 'Rebirth', 12 + 22, 42, 24, 32, Color.white, hex('F28A8A'))
-- (brief 19) Cash in the reference's gold trophy row: its "67.2K" gold (yellow -> orange), not green
local cashCount, cashIcon = counter('Cash', 'Cash', COUNTERS_H - 12 - 44 + 24, 56, 16, 39, hex('FFE84A'), hex('FF9A10'))
-- On PC the rows sit where the reference's 2nd row (its "0") and trophy row are: 117 and 66 design px over the bottom.
local COUNTER_PC_Y = { Rebirths = COUNTERS_H + 2 - 117, Cash = COUNTERS_H + 2 - 66 }
-- Phones: side by side in one row under Roblox's top bar, over the column (the bottom-left is the thumbstick's).
local COUNTER_PHONE = { Rebirths = px(0, 28), Cash = px(112, 28) }

-- The daily Rewards gift in the reference's top-left event slot (its "VILLAINS / 1:30 PM" shop): the icon and a caption.
local rewardsSpot = Kit.new('Frame', { Name = 'RewardsGift', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 345, 0, -26), Size = px(110, 104), Parent = root })
do
	local icon = Kit.icon3d('Rewards', 78, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 3 })
	icon.Parent = rewardsSpot
	label({ Name = 'Caption', Text = 'Rewards', TextSize = 24, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = px(160, 28), ZIndex = 4, Parent = rewardsSpot })
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = rewardsSpot })
	hit.Activated:Connect(call('Rewards'))
end

---------------------------------------------------------------------------------------------- right column
-- Offer cards like the reference's "2x Wins / ONLY 9" and "+2x Power": a studded block 198 x 69, a big 3D icon behind
-- the name poking over its top edge, "ONLY <Robux> price" over its bottom edge. A tap buys (or says it's coming soon).
local OFFER_W, OFFER_H, OFFER_STEP = 198, 69, 92
local offers = Kit.new('Frame', { Name = 'Offers', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 236), Size = px(OFFER_W, OFFER_STEP + OFFER_H + 16), Parent = root })
local function offerCard(key, i, tone, iconId)
	local entry = Products.ByKey[key]
	if not entry then return end
	local holder, hit = Kit.blockButton({ Name = key, Tone = tone, Width = OFFER_W, Height = OFFER_H, Position = px(0, (i - 1) * OFFER_STEP) })
	holder.Parent = offers
	local icon = Kit.icon3d(iconId, 92, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -10, 0, -14), ZIndex = 5 })
	icon.Parent = holder.Body
	local title = entry.Offer or entry.Title
	label({ Name = 'Title', Text = title, TextSize = Kit.fitSize(title, 33, OFFER_W - 24, 14), StrokeThickness = 4, Position = px(4, -1), Size = UDim2.new(1, -8, 1, 0), ZIndex = 7, Parent = holder.Body })
	hit.Position = px(0, -8)
	hit.Size = UDim2.new(1, 0, 1, 20)
	local only = Kit.only(entry.Price, 24, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 1), ZIndex = 8 })
	only.Parent = holder
	Motion.button(holder, function() buy(key) end)
	return holder
end
-- (ICONS' 2x Cash / 2x Power card art once uploaded; the bill stack and the arm until then)
offerCard('DoubleCash', 1, 'gold', Kit.iconImage('DoubleCash') ~= '' and 'DoubleCash' or 'Cash')
offerCard('DoubleRep', 2, 'fire', Kit.iconImage('DoublePower') ~= '' and 'DoublePower' or POWER)

---------------------------------------------------------------------------------------------- bottom-centre
-- The reference's bottom block: "Multiplier: 22.3x" over the bar's left end, the Power icon and count centred over the
-- bar, the studded bar 410 x 44 ("Level 175 .. MAX LEVEL"; here your next rebirth), three Robux power packs 119 x 43
-- under it, and the "2x Speed" pass (our Auto Fight) 27 px right of the bar.
local BAR_W, BAR_H, BAR_TOP = 410, 44, 50
local PACK_W, PACK_H, PACK_GAP, PACK_TOP = 119, 43, 13, 50 + 44 + 7
local SIDE_GAP, SIDE_W, SIDE_H = 27, 125, 48
local STATUS_W, STATUS_H = BAR_W + SIDE_GAP + SIDE_W, PACK_TOP + PACK_H + 4
local status = Kit.new('Frame', { Name = 'Status', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, -BAR_W / 2, 1, -10), Size = px(STATUS_W, STATUS_H), Parent = root })
local multiplierLabel = fillText(label({ Name = 'Multiplier', Text = 'Multiplier: 1x', TextSize = 16, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), Position = px(3, BAR_TOP - 1), Size = px(260, 24), ZIndex = 3, Parent = status }), hex('FFE24A'), hex('FF9A10'))
local powerRow = Kit.new('Frame', { Name = 'Power', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(BAR_W / 2, BAR_TOP - 25), Size = px(200, 34), Parent = status })
local powerIcon = Kit.icon3d(POWER, 36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 3 })
powerIcon.Parent = powerRow
local powerLabel = fillText(label({ Name = 'Value', Text = '...', TextSize = 24, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = px(200, 34), ZIndex = 3, Parent = powerRow }), hex('FFE24A'), hex('FF9A10'))
local function centrePower(text)
	local w = 40 + Kit.textWidth(text, 24)
	powerRow.Size = px(w, 34)
end

-- A running timed boost (StoreService: PowerBoost, and BoostEnds / PartyEnds as os.time) shows over the multiplier
-- with its time left: "2x Boost 14:59".
local boostChip = label({ Name = 'Boost', Text = '', TextSize = 18, StrokeThickness = 3, TextColor3 = hex('E7B6FF'), TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), Position = px(3, BAR_TOP - 24), Size = px(200, 22), ZIndex = 3, Parent = status })
boostChip.Visible = false
local function paintBoost()
	local level = num('PowerBoost', 1)
	local ends = math.max(num('BoostEnds', 0), num('PartyEnds', 0))
	local left = ends - os.time()
	boostChip.Visible = level > 1 and left > 0
	if boostChip.Visible then
		boostChip.Text = times(level) .. ' Boost  ' .. string.format('%d:%02d', math.floor(left / 60), left % 60)
	end
end
task.spawn(function()
	while true do
		paintBoost()
		task.wait(1)
	end
end)

local bar, fill, barText = Kit.bar({ Name = 'RebirthBar', Width = BAR_W, Height = BAR_H, Tone = 'level', Value = 0, Left = 'Rebirth 1', Right = '0 / 0', TextSize = 22, Position = px(0, BAR_TOP), ZIndex = 2 })
bar.Parent = status
local fillGradient = fill:FindFirstChildOfClass('UIGradient')
local function setFillTone(name)
	local t = Tone[name]
	fillGradient.Color = ColorSequence.new(t.top, t.base)
end

-- Power packs: the flexed arm over the left end, "+N" right-aligned, the Robux price under the right corner.
local PACKS = { 'PowerPack1', 'PowerPack2', 'PowerPack3' }
local PACK_TONES = { 'lemon', 'cherry', 'rainbow' }
local packLabels = {}
local packs = Kit.new('Frame', { Name = 'Packs', BackgroundTransparency = 1, Position = px(math.floor((BAR_W - (3 * PACK_W + 2 * PACK_GAP)) / 2), PACK_TOP), Size = px(3 * PACK_W + 2 * PACK_GAP, PACK_H + 12), Parent = status })
for i, key in PACKS do
	local entry = Products.ByKey[key]
	local holder = Kit.blockButton({ Name = key, Tone = PACK_TONES[i], Width = PACK_W, Height = PACK_H, Position = px((i - 1) * (PACK_W + PACK_GAP), 0), StudPattern = 'checker' })
	holder.Parent = packs
	Kit.icon3d(POWER, 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -12, 0.5, 2), ZIndex = 6 }).Parent = holder.Body
	packLabels[key] = label({ Name = 'Amount', Text = '+0', TextSize = 26, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Right, Position = px(36, -2), Size = UDim2.new(1, -45, 1, 0), ZIndex = 7, Parent = holder.Body })
	local price = Kit.only(entry.Price, 16, { Only = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 2, 1, 2), ZIndex = 8, MarkColor = hex('A6F02A'), PriceColors = ColorSequence.new(hex('C8FF4A'), hex('5AD81A')) })
	price.Parent = holder
	Motion.button(holder, function() buy(key) end)
end
local function paintPacks(need)
	for _, key in PACKS do
		local l = packLabels[key]
		l.Text = '+' .. short(Products.powerAmount(key, need))
		l.TextSize = Kit.fitSize(l.Text, 26, PACK_W - 50, 12)
	end
end
-- The Auto Fight pass in the reference's "2x Speed" slot: a sunset gradient block and "ONLY <Robux> n" under it.
do
	local entry = Products.ByKey.AutoShoot
	if entry then
		local holder = Kit.blockButton({ Name = 'AutoShoot', Tone = 'sunset', Width = SIDE_W, Height = SIDE_H, Position = px(BAR_W + SIDE_GAP, BAR_TOP - 2), Text = entry.Offer or entry.Title, TextSize = 22 })
		holder.Parent = status
		-- (the reference's 2x Speed price is all lime: ONLY, the mark and the number)
		local lime = ColorSequence.new(hex('8CFF5A'), hex('5EE83A'))
		Kit.only(entry.Price, 15, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 1), ZIndex = 8, OnlyColors = lime, MarkColor = hex('7DF04E'), PriceColors = lime }).Parent = holder
		Motion.button(holder, function() buy('AutoShoot') end)
	end
end

---------------------------------------------------------------------------------------------- top-centre
-- The hint sits where the reference's first timer line does (beside Roblox's own top bar buttons): white outlined
-- text with the key words in colour.
local HINT_Y = -21 -- (centred on the reference's first line, measured at its size)
local hint = label({ Name = 'Hint', Text = '', TextSize = 21, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, HINT_Y), Size = px(820, 28), RichText = true, Parent = root })
hint.TextScaled = true
Kit.new('UITextSizeConstraint', { MaxTextSize = 21, MinTextSize = 11, Parent = hint })

-- Notices: plain outlined lines in the middle-top (like the video's "FREE AUTOWIN!"), newest on top, three at most,
-- coloured by meaning.
local NOTICE = { green = hex('7CFF4F'), red = hex('FF4B4B'), orange = hex('FFC21A'), blue = hex('5AE0FF'), purple = hex('E3A6FF') }
local toastStack = Kit.new('Frame', { Name = 'Toasts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = px(900, 140), ZIndex = 40, Parent = noticeRoot })
Kit.new('UIListLayout', { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastStack })
local toastCount = 0
-- Notices sit in the upper middle; while a window is open (the HUD is away) they move up into the top band, clear of it.
local toastY = 115
-- (LOOP) While Goals.client's GOAL DONE moment is up (PlayerGui GoalMoment; it takes design px 50..200 at the top centre),
-- they sit under it: "Bought Snub Revolver!" landed right on "GOAL DONE!".
local MOMENT_BOTTOM = 208
placeToasts = function()
	local open = playerGui:GetAttribute('HoodWindow')
	local windowOpen = type(open) == 'string' and open ~= ''
	local moment = playerGui:GetAttribute('GoalMoment') == true
	toastStack.Position = UDim2.new(0.5, 0, 0, windowOpen and -50 or (moment and math.max(toastY, MOMENT_BOTTOM)) or toastY)
end
playerGui:GetAttributeChangedSignal('GoalMoment'):Connect(function() placeToasts() end)
toast = function(text, tone)
	text = tostring(text)
	toastCount += 1
	local slot = Kit.new('Frame', { Name = 'Toast' .. toastCount, BackgroundTransparency = 1, Size = px(900, 40), LayoutOrder = -toastCount, Parent = toastStack })
	local t = label({ Name = 'Toast', Text = text, TextSize = 30, StrokeThickness = 4, TextColor3 = NOTICE[tone or 'green'] or NOTICE.green, Size = UDim2.fromScale(1, 1), ZIndex = 44, Parent = slot })
	t.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 30, MinTextSize = 14, Parent = t })
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
	local holder = Kit.new('Frame', { Name = 'RebirthMoment', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = px(800, 170), ZIndex = 60, Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local title = fillText(label({ Name = 'Title', Text = 'Rebirth ' .. n .. '!', TextSize = 80, StrokeThickness = 7, Size = UDim2.new(1, 0, 0, 92), ZIndex = 61, Parent = holder }), Color.white, hex('FF6B7A'))
	local text = times(rebirthMultiplier(n)) .. ' Power forever!'
	if type(unlocked) == 'string' and unlocked ~= '' then text ..= '  ' .. unlocked .. ' unlocked!' end
	local line = fillText(label({ Name = 'Multiplier', Text = text, TextSize = 38, StrokeThickness = 4.5, Position = px(0, 96), Size = UDim2.new(1, 0, 0, 46), ZIndex = 61, Parent = holder }), hex('FFE24A'), hex('FF9A10'))
	line.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 38, Parent = line })
	Motion.tween(scale, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	task.delay(2.2, function()
		if not holder.Parent then return end
		Motion.tween(holder, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = UDim2.fromScale(0.5, 0.34) })
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
local windows = {}
local function closePanel()
	local p = current
	if not p then return end
	current = nil
	Motion.blur(p.Name, false)
	Motion.close(p.Overlay, p.Panel)
	if playerGui:GetAttribute('HoodWindow') == p.Name then playerGui:SetAttribute('HoodWindow', '') end
end
-- Like the reference (user_27/28 show the floor where its offers and bottom bar would be), the HUD steps away while
-- any window is open and comes back when it closes.
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local open = playerGui:GetAttribute('HoodWindow')
	if current and open ~= current.Name then closePanel() end
	gui.Enabled = not (type(open) == 'string' and open ~= '')
	if placeToasts then placeToasts() end
end)
local function makePanel(name, title, icon, tone, w, h, titleSize)
	local panel, well, closeHit, overlay, header = Kit.window(panelRoot, { Name = name, Title = title, Icon = icon, Tone = tone, Width = w, Height = h, TitleSize = titleSize or 72 })
	overlay.Visible = false
	-- Taps beside the window close it; taps on the window itself stop there.
	local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
	backdrop.Activated:Connect(closePanel)
	Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
	Motion.button(closeHit.Parent, closePanel)
	local p = { Name = name, Overlay = overlay, Panel = panel, Well = well, Header = header }
	table.insert(windows, p)
	return p
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
	Motion.open(p.Overlay, p.Panel, 1)
end

local function body(parent, text, props)
	props = props or {}
	return Kit.text({
		Name = props.Name or 'Body', Text = text, FontFace = props.FontFace or Kit.Font.body, TextSize = props.TextSize or 18, TextColor3 = props.Color or Color.white,
		Stroke = props.Stroke or BLACK, StrokeThickness = props.StrokeThickness or 2, TextXAlignment = props.Align or Enum.TextXAlignment.Center,
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
-- Measured on the reference: a 940 x 642 window; "Rebirth n" over a 285 x 87 cyan box with the Power icon and "Nx", a
-- green 3D arrow, "Rebirth n+1" over "(N+1)x"; "Rebirth resets your power" in red; a 656 x 84 bar with the Power icon
-- as its badge (the reference's XP shield); the Rebirth button and Skip Rebirth (once its product id is set), 314 x 83.
-- (Positions are in the window's Content frame: 18 px in from the sides, 132 px down from the top.)
local RB_W, RB_H = 940, 642
local rebirth = makePanel('Rebirth', 'Rebirth', 'Rebirth', 'headerCyan', RB_W, RB_H, 68)
local rw = rebirth.Well
local BOX_W, BOX_H, BOX_Y = 285, 87, 77
local FROM_X, TO_X = 79, 539
local fromTitle = label({ Name = 'From', Text = 'Rebirth 0', TextSize = 32, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(FROM_X + BOX_W / 2, 50), Size = px(BOX_W + 80, 48), ZIndex = 26, Parent = rw })
local toTitle = label({ Name = 'To', Text = 'Rebirth 1', TextSize = 32, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(TO_X + BOX_W / 2, 50), Size = px(BOX_W + 80, 48), ZIndex = 26, Parent = rw })
local function multiplierBox(name, x)
	local box = Kit.block({ Name = name, Tone = 'aqua', Width = BOX_W, Height = BOX_H, Position = px(x, BOX_Y), Outline = 5, RimWidth = 3, Studs = 20, StudPattern = 'checker', ZIndex = 25 })
	box.Parent = rw
	Kit.icon3d(POWER, 78, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 28 }).Parent = box.Body
	local value = label({ Name = 'Value', Text = '1x', TextSize = 38, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(98, -1), Size = UDim2.new(1, -102, 1, 0), ZIndex = 28, Parent = box.Body })
	return value
end
local fromValue = multiplierBox('FromBox', FROM_X)
local toValue = multiplierBox('ToBox', TO_X)
-- The green arrow between them (the reference's studded green arrow, pointing up and to the right): ICONS' Arrow render
-- once uploaded, else the Evolve icon model turned 45 degrees with a black outline copy behind it, like Kit.icon3d's.
local arrow
if Kit.iconImage('Arrow') ~= '' then
	arrow = Kit.icon3d('Arrow', 128, { ZIndex = 27 })
elseif IconModels and type(IconModels.build) == 'function' then
	local ok, model = pcall(IconModels.build, 'Evolve', 1)
	if ok and typeof(model) == 'Instance' then
		-- (seen from the front, screen-right is world -X)
		pcall(function() model:PivotTo(CFrame.Angles(0, 0, math.pi / 4)) end)
		local look = { Direction = typeof(IconModels.View) == 'Vector3' and IconModels.View or nil, ZIndex = 28 }
		arrow = Kit.new('Frame', { BackgroundTransparency = 1, Size = px(128, 128), ZIndex = 27 })
		local edge = Kit.viewport(model:Clone(), 128, look)
		edge.Name = 'Outline'
		edge.ImageColor3 = hex('0C0A34')
		edge.AnchorPoint = Vector2.new(0.5, 0.5)
		edge.Position = UDim2.fromScale(0.5, 0.5)
		edge.Size = UDim2.fromScale(1.1, 1.1)
		edge.ZIndex = 27
		edge.Parent = arrow
		local vp = Kit.viewport(model, 128, look)
		vp.Size = UDim2.fromScale(1, 1)
		vp.Parent = arrow
		arrow:SetAttribute('PreviewImage', 'icon3d:Evolve')
		arrow:SetAttribute('PreviewRotate', 45)
	end
end
arrow = arrow or label({ Name = 'Arrow', Text = '>', TextSize = 80, TextColor3 = Tone.green.top, StrokeThickness = 6, Size = px(128, 128), Rotation = -45, ZIndex = 27 })
arrow.Name = 'Arrow'
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = px(454, BOX_Y + BOX_H / 2)
arrow.Parent = rw
-- (the lane the next rebirth opens, under the right box: "Unlocks BAY 3!")
local unlockLine = label({ Name = 'Unlock', Text = '', TextSize = 22, TextColor3 = hex('7CFF4F'), StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(TO_X + BOX_W / 2, BOX_Y + BOX_H + 22), Size = px(BOX_W + 60, 28), ZIndex = 26, Parent = rw })
label({ Name = 'Warning', Text = 'Rebirth resets your power', TextSize = 32, TextColor3 = hex('F00606'), StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(452, 228), Size = px(860, 46), ZIndex = 26, Parent = rw })
local RBAR_X, RBAR_Y, RBAR_W, RBAR_H = 138, 265, 656, 84
local rebirthBar, rebirthFill, rebirthBarText = Kit.bar({ Name = 'Progress', Width = RBAR_W, Height = RBAR_H, Tone = 'aqua', Value = 0, Text = '0 / 0 Power', TextSize = 36, Position = px(RBAR_X, RBAR_Y), Outline = 5, Studs = 20, ZIndex = 25 })
rebirthBar.Parent = rw
-- the badge over the bar's left end (the reference's XP shield, tilted): ICONS' Shield render once uploaded, else a shield
-- of frames (a square top and a diamond point: black edge, a light blue band, the navy face), the Power arm on it
local function shield(w, h, z)
	local holder = Kit.new('Frame', { Name = 'Badge', BackgroundTransparency = 1, Size = px(w, h), ZIndex = z })
	if Kit.iconImage('Shield') ~= '' then
		local img = Kit.icon3d('Shield', math.max(w, h), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z })
		img.Parent = holder
		return holder
	end
	for i, look in { { 0, BLACK }, { 5, hex('6AB0FF') }, { 10, hex('1E48C8') } } do
		local inset, color = look[1], look[2]
		local top = Kit.new('Frame', { Name = 'Top' .. i, BackgroundColor3 = color, BorderSizePixel = 0, Position = px(inset, inset), Size = px(w - 2 * inset, h * 0.6 - inset), ZIndex = z + i - 1, Parent = holder })
		Kit.corner(math.max(2, 14 - inset)).Parent = top
		local side = (w - 2 * inset) / math.sqrt(2)
		Kit.new('Frame', { Name = 'Point' .. i, BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = px(w / 2, h - inset * 1.41 - (w - 2 * inset) / 2), Size = px(side, side), ZIndex = z + i - 1, Parent = holder })
		if i == 3 then Kit.gradient(hex('3A78F0'), color, 0.5).Parent = top end
	end
	return holder
end
do
	local badge = shield(98, 112, 29)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = px(RBAR_X - 30, RBAR_Y + RBAR_H / 2)
	badge.Rotation = -10
	badge.Parent = rw
	Kit.icon3d(POWER, 70, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.44, 0), ZIndex = 33 }).Parent = badge
end
local rebirthAction, skipAction
local confirmUntil = 0
local ACTION_Y, ACTION_W, ACTION_H = 385, 314, 83
-- (brief 19) Skip Rebirth sits beside Rebirth like the reference's, id or not: with no product id yet a tap says it's
-- coming soon (Products.canBuy), like every Store card.
local function skipLive() return Products.ByKey.SkipRebirth ~= nil end
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
	local text = maxed and 'Max rebirths!' or confirming and 'Tap again!' or (ready and 'Rebirth' or ('Need ' .. short(need - power)))
	local key = (ready and 'ready' or 'locked') .. (confirming and '+confirm' or '') .. (skip and '+skip' or '')
	if rebirthAction and rebirthAction:GetAttribute('Key') == key then
		local l = rebirthAction:FindFirstChild('Label', true)
		if l then l.Text = text end
		return
	end
	rebirthAction = actionIn(rw, rebirthAction, {
		-- (brief 19) the reference's button is the cyan block whatever the state; not ready, it says what's missing and a tap
		-- says how to get there (grey only at the last rebirth)
		Name = 'Action', Tone = confirming and 'gold' or 'aqua', Disabled = maxed, Text = text, TextSize = ready and 51 or 40,
		Icon = 'Rebirth', IconSize = 64, IconInset = 22, Width = ACTION_W, Height = ACTION_H, Outline = 5, RimWidth = 3, Studs = 20, StudPattern = 'checker',
		Position = skip and px(105, ACTION_Y) or px(452 - ACTION_W / 2, ACTION_Y),
	}, function()
		local nowPower, nowNeed = num('Power', 0), rebirthNeed()
		if nowPower < nowNeed then
			toast('Train to ' .. short(nowNeed) .. ' Power to rebirth!', 'orange')
			return
		end
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
			Name = 'Skip', Tone = 'aqua', Text = 'Skip Rebirth', TextSize = 33, Icon = Kit.iconImage('RebirthSkip') ~= '' and 'RebirthSkip' or 'Rebirth', IconSize = 60, IconInset = 18, Width = ACTION_W, Height = ACTION_H,
			Outline = 5, RimWidth = 3, Studs = 20, StudPattern = 'checker', Position = px(480, ACTION_Y),
		}, function() buy('SkipRebirth') end)
		Kit.only(entry.Price, 38, { Only = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 30, 0, 4), ZIndex = 32, MarkColor = hex('A6F02A'), PriceColors = ColorSequence.new(hex('E8FF4A'), hex('8AE82A')) }).Parent = skipAction
	end
end
rebirth.Open = function()
	confirmUntil = 0
	rebirthUpdate()
end
rebirth.Update = rebirthUpdate

---------------------------------------------------------------- GUNS
-- Every gun of the ladder: its model, name and multiplier, and EQUIPPED / OWNED / its Cash price, on studded cards like
-- the Store's. Guns are bought and equipped at the ARMORY (the server checks you stand at the gun), so this window
-- shows the way there.
local guns = makePanel('Guns', 'Guns', 'Gun', 'headerGold', 940, 642)
label({ Name = 'Note', Text = 'Buy and equip guns at the Armory!', TextSize = 28, StrokeThickness = 3.5, Position = px(0, 0), Size = UDim2.new(1, 0, 0, 36), ZIndex = 26, Parent = guns.Well })
local gunGrid = Kit.new('ScrollingFrame', {
	Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, 42), Size = UDim2.new(1, 0, 1, -42), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = guns.Well,
})
local GUN_W, GUN_H = 162, 200
Kit.new('UIGridLayout', { CellSize = px(GUN_W, GUN_H), CellPadding = px(14, 18), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = gunGrid })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = gunGrid })
local function gunTone(gun)
	local c = gun.Color
	return { top = c:Lerp(Color.white, 0.45), base = c, lip = c:Lerp(BLACK, 0.3), stroke = c:Lerp(BLACK, 0.7), rim = c:Lerp(Color.white, 0.6) }
end
local function gunCard(gun, owned, cash)
	local card = Kit.block({ Name = gun.Id, Tone = gunTone(gun), Width = GUN_W, Height = GUN_H, Outline = 4, RimWidth = 3, Studs = Kit.studsAreCheap() and 26 or false, ZIndex = 25 })
	card.LayoutOrder = gun.Tier
	local art
	local image = GunModels and type(GunModels.Images) == 'table' and GunModels.Images[gun.Id]
	if type(image) == 'string' and image ~= '' then
		-- (an uploaded gun render: one ImageLabel instead of a live model of ~40 parts)
		art = Kit.new('ImageLabel', { BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, Size = px(150, 92), ZIndex = 28 })
	elseif GunModels and type(GunModels.build) == 'function' then
		local ok, model = pcall(GunModels.build, gun.Id, 1)
		if ok and typeof(model) == 'Instance' then
			local view = typeof(GunModels.View) == 'Vector3' and GunModels.View or nil
			art = Kit.viewport(model, Vector2.new(150, 92), { Direction = view, Yaw = -70, Pitch = 12, ZIndex = 28 })
		end
	end
	art = art or Kit.icon3d('Gun', 92, { ZIndex = 28 })
	art:SetAttribute('PreviewImage', 'gun:' .. gun.Id)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 2)
	art.Parent = card.Body
	local name = label({ Name = 'Title', Text = gun.Name, TextSize = 21, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 94), Size = UDim2.new(1, -10, 0, 26), ZIndex = 28, Parent = card.Body })
	name.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 21, Parent = name })
	fillText(label({ Name = 'Multiplier', Text = times(gun.Multiplier) .. ' Power', TextSize = 22, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(1, -8, 0, 26), ZIndex = 28, Parent = card.Body }), hex('FFE24A'), hex('FF9A10'))
	local state = GunRules and owned and GunRules.state(owned, gun.Id) or ((player:GetAttribute('EquippedGun') or Guns.Starter) == gun.Id and 'Equipped' or 'Locked')
	local chip = Kit.block({ Name = 'State', Tone = state == 'Equipped' and 'lime' or state == 'Owned' and 'aqua' or 'dark', Width = GUN_W - 24, Height = 36, Studs = false, Outline = 3, RimWidth = 2, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), ZIndex = 28 })
	chip.Parent = card.Body
	if state == 'Equipped' or state == 'Owned' then
		label({ Name = 'Text', Text = state, TextSize = 21, StrokeThickness = 3, Size = UDim2.fromScale(1, 1), ZIndex = 31, Parent = chip.Body })
	else
		Kit.icon3d('Cash', 36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), ZIndex = 31, Outline = false }).Parent = chip.Body
		label({ Name = 'Text', Text = gun.Cost <= 0 and 'Free' or short(gun.Cost), TextSize = 21, StrokeThickness = 3, TextColor3 = cash >= gun.Cost and hex('7CFF4F') or Color.white, Position = px(18, 0), Size = UDim2.new(1, -18, 1, 0), ZIndex = 31, Parent = chip.Body })
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

---------------------------------------------------------------- QUEST (the goal chain)
-- The reference's Quest square opens our goal chain (GoalService decides; GoalRules has the list): every goal as a
-- studded row, the ones you've done ticked, the current one gold, the rest waiting, each with the Cash it pays.
local quest = makePanel('Quest', 'Quest', iconOr('Quest', 'Trophy'), 'headerGold', 940, 642)
local questList = Kit.new('ScrollingFrame', {
	Name = 'Goals', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = quest.Well,
})
Kit.new('UIListLayout', { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = questList })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), Parent = questList })
local function questRow(goal, state)
	local tone = state == 'done' and 'lime' or state == 'now' and 'gold' or 'dark'
	-- (brief 19: 20 rows: studs only as a texture, and the live Cash icon without its outline copy; ~1.3K instances saved)
	local row = Kit.block({ Name = goal.Id or 'Goal', Tone = tone, Width = 860, Height = 74, Outline = 4, RimWidth = 3, Studs = Kit.studsAreCheap() and 34 or false, ZIndex = 25 })
	row.LayoutOrder = goal.Step or 0
	label({ Name = 'Step', Text = state == 'done' and '✓' or tostring(goal.Step or ''), FontFace = state == 'done' and Kit.Font.body or nil, TextSize = 36, StrokeThickness = 4, Position = px(10, 0), Size = px(56, 74), ZIndex = 28, Parent = row.Body })
	local text = label({ Name = 'Text', Text = goal.Text or '', TextSize = 26, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(74, 6), Size = px(640, 32), ZIndex = 28, Parent = row.Body })
	text.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 26, MinTextSize = 12, Parent = text })
	local where = label({ Name = 'Where', Text = goal.Where or '', TextSize = 19, StrokeThickness = 2.5, TextColor3 = state == 'dark' and Color.white or hex('E8FBFF'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(74, 40), Size = px(640, 24), ZIndex = 28, Parent = row.Body })
	where.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 19, MinTextSize = 10, Parent = where })
	Kit.icon3d('Cash', 46, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -150, 0.5, 0), ZIndex = 28, Outline = false }).Parent = row.Body
	fillText(label({ Name = 'Reward', Text = '+' .. short(goal.Reward or 0), TextSize = 30, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(1, -100, 0, 0), Size = px(96, 74), ZIndex = 28, Parent = row.Body }), hex('F0FF8A'), hex('3CCB3C'))
	return row
end
local shownStep
local function fillQuest()
	local step = num('GoalStep', nil)
	if shownStep == step and questList:FindFirstChildWhichIsA('Frame') then return end
	shownStep = step
	for _, child in questList:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	if not GoalRules or type(GoalRules.List) ~= 'table' or not step then
		label({ Name = 'Loading', Text = 'Your goals are on their way...', TextSize = 30, Size = px(860, 80), Parent = questList, ZIndex = 26 })
		return
	end
	for i, goal in GoalRules.List do
		questRow(goal, i < step and 'done' or i == step and 'now' or 'next').Parent = questList
	end
	-- (brief 19) open on the goal you're on, one done row above it, not on the first goals you finished long ago
	-- (deferred: AutomaticCanvasSize grows the canvas after this frame's layout)
	task.defer(function() questList.CanvasPosition = Vector2.new(0, math.max(0, (step - 2) * (74 + 12))) end)
end
quest.Open = fillQuest
quest.Update = fillQuest

---------------------------------------------------------------- REWARDS
local rewards = makePanel('Rewards', 'Rewards', 'Rewards', 'headerCyan', 900, 560)
local days = Kit.new('Frame', { Name = 'Days', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = px(7 * 104 + 6 * 12, 140), ZIndex = 24, Parent = rewards.Well })
Kit.new('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = days })
-- The day tiles hold 3D icons, so they are built the first time the window opens.
rewards.Open = function()
	if days:FindFirstChild('Day1') then return end
	for day = 1, 7 do
		local big = day == 7
		local tile = Kit.block({ Name = 'Day' .. day, Tone = big and 'gold' or 'aqua', Width = 104, Height = 136, Outline = 4, RimWidth = 3, Studs = 24, ZIndex = 25 })
		tile.LayoutOrder = day
		tile.Parent = days
		label({ Name = 'Day', Text = 'Day ' .. day, TextSize = 22, StrokeThickness = 3, Position = px(0, 6), Size = UDim2.new(1, 0, 0, 26), ZIndex = 28, Parent = tile.Body })
		Kit.icon3d(big and 'Rewards' or 'Cash', big and 78 or 66, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 78), ZIndex = 28 }).Parent = tile.Body
	end
end
label({ Name = 'Note', Text = 'Log in every day for bigger rewards!', TextSize = 32, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176), Size = px(820, 40), ZIndex = 26, Parent = rewards.Well })
label({ Name = 'Soon', Text = 'Daily rewards arrive in the next update', TextSize = 24, StrokeThickness = 3, TextColor3 = hex('5AE0FF'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 220), Size = px(820, 30), ZIndex = 26, Parent = rewards.Well })
actionIn(rewards.Well, nil, { Name = 'Claim', Tone = 'lime', Disabled = true, Text = 'Coming soon', TextSize = 40, Width = 314, Height = 83, Outline = 5, RimWidth = 3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10) })

actions.Store = function()
	closePanel()
	openStore()
end
actions.Rebirth = function() openPanel(rebirth) end
actions.Guns = function() openPanel(guns) end
actions.Quest = function() openPanel(quest) end
actions.Rewards = function() openPanel(rewards) end

---------------------------------------------------------------------------------------------- live values
local shown = Instance.new('NumberValue') -- the Power the HUD is showing; tweens up for the count-up
shown.Changed:Connect(function(v)
	powerLabel.Text = short(v)
	centrePower(powerLabel.Text)
end)

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
-- The hint, in the reference's "Next DOCTOR DOOM boss fight in: 9:07" style: white words, the key ones coloured.
local GREEN, GOLD, RED, CYAN = '#7CFF4F', '#FFD21A', '#FF4B4B', '#5AE0FF'
local function c(color, text) return '<font color="' .. color .. '">' .. text .. '</font>' end
local clearUntil = 0 -- (Waves.client holds "CLEAR!" in the fight pill for 2.4 s after a wave falls)
local function hintText(power)
	-- In a stage with goons up, the fight's "N LEFT" counter takes the hint's place at the top centre.
	local waveLeft = player:GetAttribute('WaveLeft')
	if (type(waveLeft) == 'number' and waveLeft > 0) or os.clock() < clearUntil then return '' end
	local station = player:GetAttribute('TrainingStation') or ''
	local need = rebirthNeed()
	local goal = power >= need and (c(GREEN, 'Rebirth ready!') .. ' Tap Rebirth') or ('Rebirth at ' .. c(GREEN, short(need)) .. ' Power')
	local gun = 'Gun ' .. c(GOLD, times(gunMultiplier()))
	if station:find('Locked:') then
		local lane = Skins.StationById[station:sub(8)]
		return c(RED, (lane and lane.Name or 'This range') .. ' needs ' .. (lane and lockText(lane) or 'more'))
	end
	-- A new player follows Lobby.client's floor guide (its GuidePhase, in the guide's gold): first to the free
	-- lane, then, once Stage 1 is open, out through the door, even from the lane.
	local phase = player:GetAttribute('GuidePhase')
	if phase == 'exit' then
		return 'The street is open! Head through the ' .. c(GOLD, 'door') .. ' ▸'
	end
	if station == '' then
		if phase == 'lane' or (phase == nil and rebirthsNow() == 0 and power < need * 0.25) then
			local lane = Skins.StationById[player:GetAttribute('BestLane') or ''] or Skins.Stations[1]
			if not player:GetAttribute('BestLane') then
				for _, s in Skins.Stations do
					if laneOpen(s) and s.Multiplier >= lane.Multiplier then lane = s end
				end
			end
			return 'Stand at ' .. c(GOLD, string.upper(lane.Name)) .. ' to shoot! (' .. times(lane.Multiplier) .. ')'
		end
		return 'Stand at a range to shoot  •  ' .. goal
	end
	-- In a lane: the gun fires by itself; the range's multiplier (in the lane's colour) and your gun's, side by side.
	local range = Skins.StationById[station]
	if range then
		-- (brief 19: as short as the reference's timer line; the bottom block shows the whole multiplier)
		return c(GREEN, 'Auto-shooting!') .. '  •  Range ' .. c('#' .. rangeColor(station, range):ToHex(), times(range.Multiplier)) .. '  •  ' .. goal
	end
	return gun .. '  •  ' .. goal
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
	centrePower(powerLabel.Text)
	lastPower = power
	multiplierLabel.Text = 'Multiplier: ' .. times(totalMultiplier())
	local ready = power >= need
	barText.Left.Text = 'Rebirth ' .. n
	barText.Right.Text = ready and 'READY!' or (short(power) .. ' / ' .. short(need))
	fill.Size = UDim2.fromScale(math.clamp(power / need, 0, 1), 1)
	setFillTone(ready and 'lime' or 'level')
	paintPacks(need)
	local percent = math.clamp(math.floor(power / need * 100), 0, 100)
	rebirthBadge.Text = percent .. '%'
	setRebirthReady(percent >= 100)
	hint.Text = hintText(power)
	if current and current.Update then current.Update() end
end
for _, key in { 'Power', 'TrainingStation', 'TrainingNeed', 'BestLane', 'GunMultiplier', 'EquippedGun', 'OwnedGuns', 'GuidePhase', 'WaveLeft', 'RebirthNeed', 'RebirthMultiplier', 'RebirthNextMultiplier', 'RebirthUnlock', 'ShoeMultiplier', 'ShotMultiplier', 'Pass_DoubleRep', 'GoalStep' } do
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
	Net.get('Notice').OnClientEvent:Connect(function(message)
		-- (LOOP) Your own "Rebirth 3! Every shot pays x4" is what the rebirth moment says in big letters: once is enough.
		if string.find(tostring(message), '^Rebirth %d+!') then return end
		toast(message, noticeTone(tostring(message)))
	end)
	Net.get('Cinematic').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'Rebirth' and type(info.Rebirths) == 'number' then rebirthMoment(info.Rebirths, info.Unlocked) end
	end)
	Net.get('ProfileUpdated').OnClientEvent:Connect(applyProfile)
	Net.get('WaveState').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'Cleared' then
			clearUntil = os.clock() + 2.4
			refresh()
			task.delay(2.45, refresh)
		end
	end)
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
-- PC, like the reference: the column centred on the screen (its middle 26 px above the root's, the top bar's half),
-- the offers on the same middle, the counters and the bottom block on the bottom edge. Phones keep the column and
-- the counters high (clear of the thumbstick) and slide the bottom block left of the round SHOOT button (unscaled real
-- pixels: 112 wide, 150 from the right edge) that Waves.client shows in a fight.
local SHOOT_RIGHT, SHOOT_SIZE = 150, 112
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	panelFit(panelGui.AbsoluteSize.X > 0 and panelGui.AbsoluteSize or abs)
	noticeFit(noticeGui.AbsoluteSize.X > 0 and noticeGui.AbsoluteSize or abs)
	for _, p in windows do Kit.fitWindow(p.Panel, panelGui.AbsoluteSize.X > 0 and panelGui.AbsoluteSize or abs) end
	local k = Kit.scaleFor(abs)
	local w, h = abs.X / k, abs.Y / k
	local phone = math.min(abs.X, abs.Y) <= 500
	local middle = h / 2 - 26
	if phone then
		counters.AnchorPoint = Vector2.new(0, 0)
		counters.Position = px(0, -6)
		for name, at in COUNTER_PHONE do
			local row = counters:FindFirstChild(name)
			if row then row.Position = at end
		end
		column.Position = px(LEFT, 118)
		offers.Position = UDim2.new(1, -16, 0, 96)
		rewardsSpot.Position = UDim2.new(1, -305, 0, 70) -- (the reference's Playtime Reward slot: Roblox hides the player list on phones)
	else
		counters.AnchorPoint = Vector2.new(0, 1)
		counters.Position = UDim2.new(0, 0, 1, -2)
		for name, y in COUNTER_PC_Y do
			local row = counters:FindFirstChild(name)
			if row then row.Position = px(0, y) end
		end
		column.Position = px(LEFT, math.floor(h * 0.221)) -- (the reference's Store top: 159 of 720)
		offers.Position = UDim2.new(1, -22, 0, math.floor(middle - 98))
		rewardsSpot.Position = UDim2.new(0, 345, 0, -26)
	end
	-- the bar centred on the screen, unless that would put the pass button under the SHOOT button
	local shootLeft = (abs.X - SHOOT_RIGHT - SHOOT_SIZE) / k
	local x = math.min(w / 2 - BAR_W / 2, shootLeft - 10 - STATUS_W)
	status.Position = UDim2.new(0, x, 1, -10)
	-- (brief 19) The hint keeps clear of the Rewards gift (PC: the top-left slot, x 290..400) and Roblox's top-right buttons;
	-- on phones of the counters' row (x 0..390). Centred on the screen while it fits, else in the room between.
	local left = phone and 390 or 410
	local right = w - (phone and 16 or 110 / k)
	local hw = math.max(300, math.min(820, right - left))
	local cx = math.clamp(w / 2, left + hw / 2, math.max(left + hw / 2, right - hw / 2))
	hint.Size = px(hw, 28)
	hint.Position = UDim2.new(0, cx, 0, HINT_Y)
	toastY = math.floor(h * 0.16)
	placeToasts()
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
panelGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
panelGui.Parent = playerGui
noticeGui.Parent = playerGui
relayout()
refreshCounters()
refresh()
