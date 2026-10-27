-- Player HUD for +1 Hood Evolution (brief 30, HUD): the soldier game's HUD copied one to one (bible §2.7, measured on
-- ref_W31.0 / ref_W03.0 and ref_ref29_hud_buttons_skins; every number is Shared/HudSpec), with our features in its slots:
--   left column     Shop (a wide gold bar, the basket, a rainbow "!"), then Shoes | Rebirth (the reference's Pets | Rebirth,
--                   with its % pill) and Items | Skins (Skins opens the inventory's guns: our gun skins)
--   bottom-left     the rank (its badge + name; the "+" lists the ranks), Rebirths, Cash (the reference's Wins; its "+"
--                   opens the Store's Cash Packs) and "Friend Boost: +N%" with the green invite "+"
--   bottom centre   the Power count over "Multiplier: x1", the cyan studded Level bar, the three Power packs with their
--                   Robux price on the top-right corner, and the Auto Fight pass in the reference's Autowin slot
--   right column    the x2 cards: 2x Cash (the reference's x2 Wins), 2x Power, 2x Speed, each "ONLY <Robux> n" under
--   top             named slots the extras fill: SpinSlot (top-left, Wheel.client), PlaytimeSlot, StarterSlot and
--                   MissionsSlot (top-right, Extras.client), and TopCentre's BossTimerSlot and FightChipSlot (FIGHTS)
--   windows         Rebirth, Quest (a tap on the goal line), Daily Rewards (from the Playtime window) and Ranks, through
--                   Shared/HudWindows (one window at a time across every script)
--   notices         Shared/HudToasts (the reference's two-line notices; never over an open window)
-- Motion like the reference and the user's phone screenshots: every button squashes when pressed and grows on hover
-- (UIMotion.button), the pieces pop in one after another when the HUD first shows, counters tick up, badges pulse, and a
-- light band sweeps across the things you can buy (never while a new player settles in: OnboardingQuiet). No flashing.
-- It only reads state: attributes the server sets and the profile snapshot.
print('[HoodHUD] start')
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')
local SocialService = game:GetService('SocialService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Skins = require(Shared.Config.Skins)
local Balance = require(Shared.Config.Balance)
local Guns = require(Shared.Config.Guns)
local Products = require(Shared.Config.Products)
local RobuxText = require(Shared.RobuxText) -- (ROBUX) the Robux sign before every Robux price
local Sell = { Style = require(Shared.TextStyle), FX = require(Shared.SellFX), Idle = require(Shared.UIIdle) } -- (ROBUX, rules 27-28: one local for both)
local Spec = require(Shared.HudSpec)
local Windows = require(Shared.HudWindows)
local Toasts = require(Shared.HudToasts)

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
local LevelRules = optional('LevelRules')
local GoalRules = optional('GoalRules')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, short = Kit.Color, Kit.short
local BLACK = Color.black
local px = UDim2.fromOffset
local hex = Kit.hex
local POWER = Kit.iconOr('Muscle', 'Power')
local iconOr = Kit.iconOr
local T = Spec.Tone

---------------------------------------------------------------------------------------------- state
local snapshot = {}
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
local function cashNow() return num('Cash', snapshot.Cash or 0) end
local function rebirthsNow() return num('Rebirths', snapshot.Rebirths or 0) end
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
local function totalMultiplier()
	local v = num('ShotMultiplier', nil)
	if v and v > 0 then return v end
	local gun = num('GunMultiplier', Guns.multiplier(player:GetAttribute('EquippedGun') or Guns.Starter))
	return rebirthMultiplier() * gun * math.max(1, num('ShoeMultiplier', 1)) * (player:GetAttribute('Pass_DoubleRep') == true and 2 or 1) * (1 + num('FriendBoost', 0))
end
-- 2 -> "x2", 2.25 -> "x2.3", 1234 -> "x1.2K" (the reference writes "Multiplier: x1", "x2 Wins")
local function times(x)
	if x >= 1000 then return 'x' .. short(x) end
	if math.abs(x - math.floor(x + 0.5)) < 0.05 then return 'x' .. string.format('%d', math.floor(x + 0.5)) end
	return 'x' .. string.format('%.1f', x)
end
local function quiet() return player:GetAttribute('OnboardingQuiet') == true end

---------------------------------------------------------------------------------------------- purchases
local function toast(text, tone, sub) Toasts.say(text, tone, sub) end
-- A Store item: Roblox's purchase prompt when the item is live (Products.canBuy), else it says so: "coming soon" is only
-- ever said for an item whose id really is still 0.
local function buy(key)
	local ok, why = Products.canBuy(key)
	local entry = Products.ByKey[key]
	if not ok then
		if why == 'noid' or why == 'off' then toast((entry and entry.Title or 'This') .. ' is coming soon!', 'blue') end
		return
	end
	local id = Products.idOf(key)
	pcall(function()
		if entry.Kind == 'Pass' then MarketplaceService:PromptGamePassPurchase(player, id) else MarketplaceService:PromptProductPurchase(player, id) end
	end)
end
local function openStore(at)
	local storeGui = playerGui:FindFirstChild('HoodStore')
	local open = storeGui and storeGui:FindFirstChild('Open')
	if open and open:IsA('BindableEvent') then
		Windows.close()
		open:Fire(at)
	else
		toast('The Store is loading...', 'blue')
	end
end
-- (brief 29, P5, the user's "Robux: ?") a pass card shows "?" for its price until Roblox's own prompt (which always shows
-- the real price) has been seen once, or at once while the item has no id yet.
local revealed, teasers = {}, {}
local function paintTeaser(key)
	local t = teasers[key]
	if not t then return end
	t.Hidden.Visible = revealed[key] ~= true
	t.Shown.Visible = revealed[key] == true
end
local function teaserPrice(key, size, props, parent)
	local entry = Products.ByKey[key]
	local hidden = Kit.only('?', size, props)
	local shown = Kit.only(entry.Price, size, props)
	hidden.Parent, shown.Parent = parent, parent
	Sell.FX.pulse(hidden, 0.05, 2.4)
	Sell.FX.pulse(shown, 0.05, 2.4)
	teasers[key] = { Hidden = hidden, Shown = shown }
	paintTeaser(key)
end
local function teaserBuy(key)
	if not revealed[key] and not Products.canBuy(key) then
		revealed[key] = true
		paintTeaser(key)
	end
	buy(key)
end
pcall(function()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id, bought)
		local key = Products.keyFor('Pass', id)
		if key and teasers[key] and not revealed[key] then
			revealed[key] = true
			paintTeaser(key)
		end
		if who == player and bought then toast('Thanks!', 'green', 'Your pass is on.') end
	end)
end)

---------------------------------------------------------------------------------------------- screen
if Kit.HidePlayerList then
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function() game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
			if ok then break end
			task.wait(0.5)
		end
	end)
end
local gui, root, fit = Spec.screen('HoodHUD', 5) -- (HudSpec: a reference px is a screen px at 720 tall)

local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.13)
	return Kit.text(props)
end
local function fillText(t, colors)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]), Parent = t })
	return t
end
-- A light band sweeping across something you can buy, every `every` seconds from `delay`; off while a new player settles in.
local shines = {}
local function shineOn(face, every, delay, sparkles)
	local rec = { Face = face, Every = every, Delay = delay or 0, Sparkles = sparkles }
	table.insert(shines, rec)
	return rec
end
local function paintShines()
	for _, rec in shines do
		if quiet() and rec.Stop then
			rec.Stop()
			rec.Stop = nil
		elseif not quiet() and not rec.Stop and rec.Face.Parent then
			rec.Stop = function() rec.Off = true end
			rec.Off = false
			task.delay(rec.Delay, function()
				if rec.Off or not rec.Face.Parent then return end
				local stopShine = Motion.shine(rec.Face, rec.Every, UDim.new(0, 3))
				local stopSparkles = rec.Sparkles and Sell.FX.sparkles(rec.Sparkles.Parent, rec.Sparkles) or nil
				rec.Stop = function() stopShine(); if stopSparkles then stopSparkles() end end
			end)
		end
	end
end
player:GetAttributeChangedSignal('OnboardingQuiet'):Connect(paintShines)

local actions = {}
local function call(name) return function() if actions[name] then actions[name]() end end end
-- a round count badge (the reference's cyan "1" on Items): a cyan disc, a black edge, a white number
local function countBadge(parent, name, size)
	local holder = Kit.new('Frame', { Name = name, BackgroundColor3 = hex('34D4F4'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = px(size, size), ZIndex = 12, Visible = false, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = holder
	Kit.stroke(BLACK, 2.5, true).Parent = holder
	Kit.gradient(hex('7AF0FF'), hex('1EB8E8'), 0.5).Parent = holder
	local text = label({ Name = 'Count', Text = '0', TextSize = math.floor(size * 0.72), StrokeThickness = 2.5, ZIndex = 13, Parent = holder })
	return holder, text
end

---------------------------------------------------------------------------------------------- left column
local column, shoesButton, rebirthPill, rebirthPillText, shoesCount, shoesCountText
do
	local C = Spec.Column
	local S = C.Square
	local row1, row2 = C.ShopH + C.ShopGap, C.ShopH + C.ShopGap + S + C.GapY
	local col2 = S + C.GapX
	column = Kit.new('Frame', { Name = 'Actions', BackgroundTransparency = 1, Position = px(C.X, C.Y), Size = px(C.ShopW, row2 + S), Parent = root })
	Kit.new('UIScale', { Name = 'LayoutScale', Parent = column })
	local function square(props)
		props.Radius = 5 -- (the reference's squares and Shop bar have softly rounded corners)
		local holder, _, _, caption = Kit.actionButton(props)
		holder.Parent = column
		Motion.button(holder, props.OnClick)
		local cs = caption:FindFirstChildOfClass('UIStroke')
		if cs then cs.Thickness = math.max(2.5, props.TextSize * 0.15) end
		return holder
	end
	-- (the reference's Shop bar: no dark inner line, its pale rim runs into the fill)
	local store = square({ Name = 'Store', Tone = T.shop, Width = C.ShopW, Height = C.ShopH, Position = px(0, 0), Text = 'Shop', TextSize = C.ShopText, LabelY = 0.7, Icon = iconOr('Basket', 'Shop'), Place = Spec.ShopArt, InnerLine = false, OnClick = call('Store') })
	shineOn(store.Body, 4.5, 0.4)
	-- the rainbow "!" (only while there is something new this session; the Store's first open clears it)
	local badge = Kit.new('Frame', { Name = 'Badge', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(C.Badge.X, C.Badge.Y), Size = px(C.Badge.W, C.Badge.H), ZIndex = 14, Parent = store })
	Kit.corner(6).Parent = badge
	Kit.stroke(BLACK, 3, true).Parent = badge
	Kit.new('UIGradient', { Rotation = 35, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex('FF3A6A')), ColorSequenceKeypoint.new(0.3, hex('FFD21A')), ColorSequenceKeypoint.new(0.55, hex('4AE04A')), ColorSequenceKeypoint.new(0.8, hex('3AA8FF')), ColorSequenceKeypoint.new(1, hex('B04AFF')) }), Parent = badge })
	label({ Name = 'Mark', Text = '!', TextSize = 24, StrokeThickness = 3, ZIndex = 15, Parent = badge })
	Motion.wobble(badge, 7, 1.4)
	playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
		if playerGui:GetAttribute('HoodWindow') == 'Store' then badge.Visible = false end
	end)
	-- MOCKUP30: the user's HUD artboard draws the Shoes tile red (its look wins where it covers a HUD element)
	shoesButton = square({ Name = 'Shoes', Tone = { top = hex('FF5A66'), base = hex('D8182C'), lip = hex('A00E1E'), stroke = hex('4A0B16'), rim = hex('FFB4BC') }, Width = S, Height = S, Position = px(0, row1), Text = 'Shoes', TextSize = C.SquareText, Icon = iconOr('Sneaker', 'Shop'), Place = 'hud', OnClick = call('Shoes') })
	local rebirthButton = square({ Name = 'Rebirth', Tone = T.rebirth, Width = S, Height = S, Position = px(col2, row1), Text = 'Rebirth', TextSize = C.SquareText - 1, Icon = 'Rebirth', Place = 'hud', OnClick = call('Rebirth') })
	square({ Name = 'Items', Tone = T.items, Width = S, Height = S, Position = px(0, row2), Text = 'Items', TextSize = C.SquareText, Icon = iconOr('Backpack', 'Shop'), Place = 'hud', OnClick = call('Items') })
	square({ Name = 'Skins', Tone = T.skins, Width = S, Height = S, Position = px(col2, row2), Text = 'Skins', TextSize = C.SquareText, Icon = iconOr('SkinsPistol', 'Gun'), Place = 'hud', OnClick = call('Skins') })
	-- the Rebirth "57%" pill: a lime capsule over the square's top-right corner
	local P = C.Pill
	rebirthPill = Kit.new('Frame', { Name = 'Percent', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -P.Right, 0, P.Y), Size = px(P.W, P.H), ZIndex = 14, Parent = rebirthButton })
	Kit.corner(UDim.new(0.5, 0)).Parent = rebirthPill
	Kit.stroke(BLACK, 2.5, true).Parent = rebirthPill
	Kit.fillGradient(T.pill).Parent = rebirthPill
	rebirthPillText = label({ Name = 'Text', Text = '0%', TextSize = P.TextSize, StrokeThickness = 2.5, ZIndex = 15, Parent = rebirthPill })
	-- new pairs to look at (PlayerGui ShoesNew, the inventory's count): the cyan count circle on the Shoes square
	shoesCount, shoesCountText = countBadge(shoesButton, 'Count', C.Count.Size)
	shoesCount.Position = UDim2.new(1, -C.Count.Right, 0, C.Count.Y)
	local function paintShoes()
		local n = playerGui:GetAttribute('ShoesNew')
		local fresh = type(n) == 'number' and n > 0
		shoesCount.Visible = fresh
		if fresh then
			shoesCountText.Text = n > 99 and '99+' or tostring(n)
			Motion.pop(shoesCount, 0.3)
		end
	end
	playerGui:GetAttributeChangedSignal('ShoesNew'):Connect(paintShoes)
	paintShoes()
end

---------------------------------------------------------------------------------------------- bottom-left
local counters, rankText, rebirthCount, rebirthIcon, cashCount, cashIcon, friendText, friendPlus
do
	local C = Spec.Counters
	counters = Kit.new('Frame', { Name = 'Counters', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = px(330, 180), Parent = root })
	Kit.new('UIScale', { Name = 'LayoutScale', Parent = counters })
	local H = 180
	local function row(name, spec, iconId)
		local r = Kit.new('Frame', { Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = px(0, H - spec.Above), Size = px(330, spec.TextSize + 14), Parent = counters })
		local icon = Kit.icon3d(iconId, spec.Icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, spec.IconX, 0.5, 0), ZIndex = 3 })
		icon.Parent = r
		local text = label({ Name = 'Value', Text = '0', TextSize = spec.TextSize, StrokeThickness = math.max(3, spec.TextSize * 0.15), TextXAlignment = Enum.TextXAlignment.Left, Position = px(spec.TextX, 0), Size = px(260, spec.TextSize + 14), ZIndex = 4, Parent = r })
		return r, icon, text
	end
	-- a lime "+" over an icon's bottom-right (the reference's rank and trophy rows): a tap target
	local function plus(r, icon, size, onClick)
		local b = Kit.new('TextButton', { Name = 'Plus', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, icon.Position.X.Offset + icon.Size.X.Offset - 4, 0.5, size * 0.42), Size = px(size + 8, size + 8), ZIndex = 6, Parent = r })
		-- (a chunky lime plus with one dark outline round the whole cross: the dark cross first, the lime one over it)
		for layer, look in { { 5, hex('16300A') }, { 0, hex('A6F02A') } } do
			for i, s in { { size, size * 0.38 }, { size * 0.38, size } } do
				local bar = Kit.new('Frame', { Name = 'Bar' .. layer .. i, BackgroundColor3 = look[2], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(s[1] + look[1], s[2] + look[1]), ZIndex = layer > 0 and 6 or 7, Parent = b })
				Kit.corner(2).Parent = bar
				if layer == 0 and i == 1 then Kit.gradient(hex('D8FF6A'), hex('6CD414'), 0.5).Parent = bar end
			end
		end
		-- (the hit covers the whole row, so the name or the number works too)
		local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(0, 220, 1, 0), ZIndex = 7, Parent = r })
		hit.Activated:Connect(function()
			Motion.pop(b, 0.3)
			onClick()
		end)
		return b
	end
	local rr, ri, rt = row('Rank', C.Rank, iconOr('Rank', 'Shield'))
	rankText = rt
	plus(rr, ri, 15, call('Ranks'))
	local br
	br, rebirthIcon, rebirthCount = row('Rebirths', C.Rebirths, 'Rebirth')
	fillText(rebirthCount, Spec.Text.rebirths)
	local cr
	cr, cashIcon, cashCount = row('Cash', C.Cash, 'Cash')
	fillText(cashCount, Spec.Text.gold)
	plus(cr, cashIcon, 15, function() openStore('Cash') end)
	-- MOCKUP30 BEGIN the user's HUD artboard draws Cash as a stat pill (dark, a green rim, the Cash caption over the
	-- number); its look wins over the slot, the slot and its names stay (Counters.Cash, Value, Plus)
	do
		local pill = Kit.new('Frame', { Name = 'StatPill', BackgroundColor3 = hex('10202E'), BackgroundTransparency = 0.08, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = px(224, 52), ZIndex = 2, Parent = cr })
		Kit.corner(12).Parent = pill
		Kit.stroke(Color.black, 3, true).Parent = pill
		local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, Position = px(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 2, Parent = pill })
		Kit.corner(9).Parent = rim
		Kit.stroke(hex('2CE04A'), 3, true).Parent = rim
		label({ Name = 'Caption', Text = 'Cash', TextSize = 15, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(C.Cash.TextX, -2), Size = px(120, 18), ZIndex = 4, Parent = cr })
		cashCount.Position = cashCount.Position + UDim2.fromOffset(0, 7)
	end
	-- MOCKUP30 END
	-- Friend Boost: "+10 % Power per friend here" (RetentionService's FriendBoost) and the green invite "+"
	local F = C.Friend
	local fr = Kit.new('Frame', { Name = 'FriendBoost', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = px(0, H - F.Above), Size = px(330, F.Plus + 2), Parent = counters })
	friendText = label({ Name = 'Text', Text = 'Friend Boost: +0%', TextSize = F.TextSize, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(F.TextX, 0), Size = px(240, F.Plus + 2), ZIndex = 4, RichText = true, Parent = fr })
	fillText(friendText, Spec.Text.friend)
	friendPlus = Kit.blockButton({ Name = 'Invite', Tone = T.friend, Width = F.Plus, Height = F.Plus + 2, Text = '+', TextSize = 28, Outline = 3, Studs = false, RimWidth = 2, ZIndex = 5 })
	friendPlus.AnchorPoint = Vector2.new(0, 0.5)
	friendPlus.Position = UDim2.new(0, 190, 0.5, 0)
	friendPlus.Parent = fr
	Motion.button(friendPlus, function()
		pcall(function()
			if SocialService:CanSendGameInviteAsync(player) then SocialService:PromptGameInvite(player) end
		end)
	end)
	local function paintFriend()
		local boost = num('FriendBoost', 0)
		local pct = math.floor(boost * 100 + 0.5)
		friendText.Text = 'Friend Boost: <font color="#FFD23A">+' .. pct .. '%</font>'
		-- (Oct 27, release fixes: on a small phone the text floor grows the words, so the + is placed after them at the size
		-- they are drawn at, not the design size; it covered "+0%" on a 667 x 375 screen)
		friendPlus.Position = UDim2.new(0, F.TextX + Kit.textWidth('Friend Boost: +' .. pct .. '%', friendText.TextSize) + 4, 0.5, 0)
	end
	player:GetAttributeChangedSignal('FriendBoost'):Connect(paintFriend)
	friendText:GetPropertyChangedSignal('TextSize'):Connect(paintFriend)
	paintFriend()
end

---------------------------------------------------------------------------------------------- bottom centre
local status, powerRow, powerIcon, powerLabel, multiplierLabel, boostChip, bar, fill, barText, packLabels, autoState
do
	local B = Spec.Bottom
	local W, H = B.BarW + B.AutoGap + B.AutoW + 20, B.PowerAbove + 20
	status = Kit.new('Frame', { Name = 'Status', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, -B.BarW / 2, 1, 0), Size = px(W, H), Parent = root })
	Kit.new('UIScale', { Name = 'LayoutScale', Parent = status })
	local function y(above) return H - above end
	-- the Power count: the orange arm and the number, centred over the bar
	powerRow = Kit.new('Frame', { Name = 'Power', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(B.BarW / 2, y(B.PowerAbove)), Size = px(160, 34), Parent = status })
	powerIcon = Kit.icon3d(POWER, B.PowerIcon + 4, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 3 })
	powerIcon.Parent = powerRow
	powerLabel = label({ Name = 'Value', Text = '0', TextSize = B.PowerText, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, B.PowerIcon + 6, 0.5, 0), Size = px(200, 34), ZIndex = 3, Parent = powerRow })
	multiplierLabel = fillText(label({ Name = 'Multiplier', Text = 'Multiplier: x1', TextSize = B.MultText, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(B.MultX, y(B.MultAbove)), Size = px(200, 22), ZIndex = 3, Parent = status }), Spec.Text.gold)
	-- a running timed boost: "2x Boost 14:59" in lilac over the multiplier
	boostChip = label({ Name = 'Boost', Text = '', TextSize = 16, StrokeThickness = 3, TextColor3 = hex('E7B6FF'), TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(B.MultX, y(B.MultAbove) - 20), Size = px(200, 20), ZIndex = 3, Visible = false, Parent = status })
	-- the Level bar: cyan, studded, "Level 2" left and "89 / 100" right
	bar, fill, barText = Kit.bar({ Name = 'RebirthBar', Width = B.BarW, Height = B.BarH, Tone = T.level, Value = 0, Left = 'Level 1', Right = '0 / 0', TextSize = 24, Track = 'dark', TrackColor = B.TrackColor, TrackTransparency = B.TrackTransparency, StudShade = B.BarStuds, Position = px(0, y(B.BarAbove)), ZIndex = 2 })
	bar.Parent = status
	-- (the reference's fill wears a bright near-white rim all round its filled part)
	local rimStroke = fill:FindFirstChild('Rim') and fill.Rim:FindFirstChildOfClass('UIStroke')
	if rimStroke then
		rimStroke.Color, rimStroke.Thickness, rimStroke.Transparency = hex('E8FFFF'), 3, 0.05
	end
	-- the three Power packs: a gradient bar with the orange arm over its left end, "+20K", the price on the top-right corner
	packLabels = {}
	for i, key in { 'PowerPack1', 'PowerPack2', 'PowerPack3' } do
		local entry = Products.ByKey[key]
		local x = (i - 1) * (B.PackW + B.PackGap)
		local holder = Kit.blockButton({ Name = key, Tone = T['pack' .. i], Width = B.PackW, Height = B.PackH, Position = px(x, y(B.PackAbove)), StudPattern = 'checker', RimWidth = 2, ZIndex = 2 })
		holder.Parent = status
		Kit.icon3d(POWER, 54, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 0.5, 1), ZIndex = 6 }).Parent = holder
		packLabels[key] = label({ Name = 'Amount', Text = '+0', TextSize = B.PackText, StrokeThickness = 3.5, Position = px(24, -1), Size = UDim2.new(1, -26, 1, 0), ZIndex = 7, Parent = holder.Body })
		local price = Kit.only(entry.Price, B.PackPrice, { Only = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 2, 0, 0), ZIndex = 8, MarkColor = hex('A6F02A'), PriceColors = ColorSequence.new(hex('D8FF5A'), hex('6CE01E')) })
		price.Parent = holder
		Motion.button(holder, function() buy(key) end)
		shineOn(holder.Body, 5.5, 1 + i * 0.35)
	end
	-- the reference's Autowin slot: a small dark button, a green play mark and its word; ours is the Auto Fight pass
	local auto = Kit.blockButton({ Name = 'AutoShoot', Tone = T.auto, Width = B.AutoW, Height = B.AutoH, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 4, Position = px(B.BarW + B.AutoGap, y(B.BarAbove)), ZIndex = 2 })
	auto.Parent = status
	auto.Body.BackgroundTransparency = 0.2
	local play = Kit.new('Frame', { Name = 'Play', BackgroundTransparency = 1, Position = px(4, 3), Size = px(20, 22), ZIndex = 6, Parent = auto.Body })
	for i = 0, 5 do
		-- a play triangle out of thin bars (no glyph), green with a dark edge
		local h = 20 - i * 3.4
		local f = Kit.new('Frame', { Name = 'Bar' .. i, BackgroundColor3 = hex('3AD83A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2 + i * 3, 0.5, 0), Size = px(3.4, h), ZIndex = 6, Parent = play })
		if i == 0 then Kit.gradient(hex('7CFF6A'), hex('22B022'), 0.5).Parent = f end
	end
	autoState = label({ Name = 'State', Text = '?', TextSize = 13, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Right, Position = px(24, 2), Size = px(B.AutoW - 30, 18), ZIndex = 7, Parent = auto.Body })
	label({ Name = 'Word', Text = 'Auto Fight', TextSize = 12, StrokeThickness = 2.5, Position = px(0, B.AutoH - 22), Size = px(B.AutoW - 5, 16), ZIndex = 7, Parent = auto.Body })
	local function paintAuto()
		local owned = player:GetAttribute('Pass_AutoShoot') == true
		local entry = Products.ByKey.AutoShoot
		autoState.Text = owned and 'ON' or (revealed.AutoShoot and entry and RobuxText.fmt(entry.Price) or (RobuxText.Mark .. '?'))
		autoState.TextColor3 = owned and hex('7CFF4F') or Color.white
	end
	player:GetAttributeChangedSignal('Pass_AutoShoot'):Connect(paintAuto)
	paintAuto()
	Motion.button(auto, function()
		if player:GetAttribute('Pass_AutoShoot') == true then
			toast('Auto Fight is on!', 'green', 'Your gun fires at goons by itself in the stages.')
			return
		end
		teaserBuy('AutoShoot')
		paintAuto()
	end)
end

---------------------------------------------------------------------------------------------- right column
local offers
do
	local O = Spec.Offers
	offers = Kit.new('Frame', { Name = 'Offers', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -O.Right, 0, O.Top), Size = px(O.W, 2 * O.Step + O.H + 20), Parent = root })
	Kit.new('UIScale', { Name = 'LayoutScale', Parent = offers })
	local function card(key, i, tone, iconId, title)
		local entry = Products.ByKey[key]
		if not entry then return end
		-- (the upper card draws over the lower one, so its price stays on top of the art the lower card raises)
		local holder, hit = Kit.blockButton({ Name = key, Tone = tone, Width = O.W, Height = O.H, Position = px(0, (i - 1) * O.Step), Radius = 6, RimWidth = 2, Outline = 3.5, Studs = 15, StudShade = 0.35, ZIndex = 9 - 2 * i })
		holder.Parent = offers
		-- (the reference's trophy / arm / winged shoe: big, centred behind the title and over the card's top edge)
		local icon = Kit.icon3d(iconId, nil, { ZIndex = 11 - 2 * i, Place = { Rule = Spec.OfferArt, W = O.W, H = O.H, X0 = 3.5, Y0 = 3.5 } })
		icon.Parent = holder.Body
		local head = label({ Name = 'Title', Text = title, TextSize = Kit.fitSize(title, O.TitleSize, O.W - 16, 16), StrokeThickness = 4.5, Position = px(2, -2), Size = UDim2.new(1, -4, 1, 0), ZIndex = 12 - 2 * i, Parent = holder.Body })
		-- (ROBUX, rule 27-28) the reference's "x2 Wins": white to light grey, a thick near-black outline, a dark foot; the
		-- art bobs gently and a few stars twinkle round the card (ref_W01.0_spawn_view_north)
		Sell.Style.apply(head, 'white', { Thickness = 4.5, Shadow = true })
		-- (Oct 27, the owner: "make the luck clovers spin left and right little") the art idles on UIIdle's one shared loop, by
		-- what it shows: the cash bobs, the arm breathes, the shoe rocks; staggered by its row
		Sell.Idle.icon(icon, iconId, i)
		hit.Position = px(0, -8)
		hit.Size = UDim2.new(1, 0, 1, 22)
		local lime = ColorSequence.new(hex('E8FF4A'), hex('4EE020'))
		teaserPrice(key, O.PriceSize, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 2), ZIndex = 14, OnlyColors = lime, MarkColor = hex('A6F02A'), PriceColors = lime }, holder)
		Motion.button(holder, function() teaserBuy(key) end)
		shineOn(holder.Body, 3.5, 1.2 + i * 0.6, { Parent = holder, Count = 2, Size = 15, ZIndex = 16, Every = 3.2, Seed = i })
		return holder
	end
	-- (the reference's pictures: the Wins trophy, the Power arm, a winged shoe; ours: the Cash stack, the arm with its bolt,
	-- the sneaker)
	card('DoubleCash', 1, T.offerGold, iconOr('Cash'), 'x2 Cash')
	card('DoubleRep', 2, T.offerCyan, iconOr('DoublePower', POWER), 'x2 Power')
	card('Speed2x', 3, T.offerGold, iconOr('Sneaker', 'Speed2x'), 'x2 Speed')
end

---------------------------------------------------------------------------------------------- top slots
-- Named frames the other scripts fill (sizes in design px; their content is centred in them). HUD.client moves them
-- with the layout and slides them aside with the rest of the HUD.
local slots = {}
do
	local function slot(name, anchor, pos, size)
		local f = Kit.new('Frame', { Name = name, BackgroundTransparency = 1, AnchorPoint = anchor, Position = pos, Size = size, Parent = root })
		Kit.new('UIScale', { Name = 'LayoutScale', Parent = f })
		slots[name] = f
		return f
	end
	local S, P, St, M, TC = Spec.Spin, Spec.Playtime, Spec.Starter, Spec.Missions, Spec.TopCentre
	slot('SpinSlot', Vector2.new(0.5, 0.5), UDim2.new(0, S.X, 0, S.Y), px(110, 110))
	slot('PlaytimeSlot', Vector2.new(0.5, 0), UDim2.new(1, -P.Right, 0, P.Y), px(120, 120))
	slot('StarterSlot', Vector2.new(0.5, 0), UDim2.new(1, -St.Right, 0, St.Y), px(150, 130))
	slot('MissionsSlot', Vector2.new(0.5, 0), UDim2.new(1, -M.Right, 0, M.Y), px(120, 110))
	local top = slot('TopCentre', Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, TC.BossY), px(TC.BossW, 90))
	Kit.new('Frame', { Name = 'BossTimerSlot', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = px(TC.BossW, TC.BossH), Parent = top })
	Kit.new('Frame', { Name = 'FightChipSlot', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TC.ChipY - TC.BossY), Size = px(TC.ChipW, TC.ChipH), Parent = top })
end

---------------------------------------------------------------------------------------------- the HUD's arrival
-- The first time the HUD shows: the column's buttons pop in one after another (0.05 s apart, Back Out from 0.4), the
-- cards slide in from the right, the bottom block rises. Once only.
local function arrive()
	local i = 0
	local function pop(g, from, delay)
		local s = Motion.scaleOf(g)
		s.Scale = from or 0.4
		task.delay(delay, function() Motion.tween(s, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
	end
	for _, name in { 'Store', 'Shoes', 'Rebirth', 'Items', 'Skins' } do
		local b = column:FindFirstChild(name)
		if b then i += 1 pop(b, 0.4, 0.05 * i) end
	end
	for k, c in offers:GetChildren() do
		if c:IsA('GuiObject') then
			local base = c.Position
			c.Position = base + px(60, 0)
			task.delay(0.12 + 0.06 * k, function() Motion.tween(c, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Position = base }) end)
		end
	end
	for _, name in { 'Rank', 'Rebirths', 'Cash', 'FriendBoost' } do
		local r = counters:FindFirstChild(name)
		if r then i += 1 pop(r, 0.6, 0.04 * i) end
	end
	-- (the bottom block: its bar and packs pop in, left to right)
	for _, name in { 'RebirthBar', 'PowerPack1', 'PowerPack2', 'PowerPack3', 'AutoShoot' } do
		local c = status:FindFirstChild(name)
		if c then i += 1 pop(c, 0.7, 0.04 * i) end
	end
end

---------------------------------------------------------------------------------------------- notices and moments
-- Server notices are plain strings: a colour from what they say, and the reference's two lines when the line has a short
-- exclaimed head ("Thanks! +5K Cash").
task.spawn(function()
	Net.get('Notice').OnClientEvent:Connect(function(message)
		message = tostring(message)
		if string.find(message, '^Rebirth %d+!') then return end -- (the rebirth moment says it big)
		if string.find(message, '^Bought ') and player:GetAttribute('OnboardingStep') == 'Gun' then return end
		local head, rest = Toasts.split(message)
		toast(head, Toasts.toneFor(message), rest)
	end)
end)
-- Lobby props that aren't built yet carry a ComingSoon prompt.
game:GetService('ProximityPromptService').PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute('ComingSoon') then toast((prompt.ObjectText ~= '' and prompt.ObjectText or 'This') .. ' is coming soon!', 'blue') end
end)

-- The rebirth moment: "Rebirth n!", the new multiplier and the lane it opened pop in the middle, then float away (< 2 s).
local lastMoment = 0
local function rebirthMoment(n, unlocked)
	if n <= lastMoment then return end
	lastMoment = n
	local holder = Kit.new('Frame', { Name = 'RebirthMoment', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = px(800, 170), ZIndex = 60, Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local title = fillText(label({ Name = 'Title', Text = 'Rebirth ' .. n .. '!', TextSize = 80, StrokeThickness = 7, Size = UDim2.new(1, 0, 0, 92), ZIndex = 61, Parent = holder }), { Color.white, hex('FF6B7A') })
	local text = times(rebirthMultiplier(n)) .. ' Power forever!'
	if type(unlocked) == 'string' and unlocked ~= '' then text ..= '  ' .. unlocked .. ' unlocked!' end
	local line = fillText(label({ Name = 'Multiplier', Text = text, TextSize = 38, StrokeThickness = 4.5, Position = px(0, 96), Size = UDim2.new(1, 0, 0, 46), ZIndex = 61, Parent = holder }), Spec.Text.gold)
	line.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 38, Parent = line })
	Motion.tween(scale, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	task.delay(1.45, function()
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
-- (Shared/HudWindows: one at a time across every script; the HUD steps away while one is open, like the reference)
-- (and while a Retention card, Before You Go! / Welcome back!, is up: PlayerGui HoodCard)
local function paintEnabled()
	local open, card = playerGui:GetAttribute('HoodWindow'), playerGui:GetAttribute('HoodCard')
	gui.Enabled = not ((type(open) == 'string' and open ~= '') or (type(card) == 'string' and card ~= ''))
end
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(paintEnabled)
playerGui:GetAttributeChangedSignal('HoodCard'):Connect(paintEnabled)
local rebirth, quest, ranks
do
	---------------------------------------------------------------- REBIRTH (the window the user copied, user_27)
	-- (brief 30: the numbers count up as it opens, the arrow bobs, the Rebirth button sweeps a light band when ready)
	local RB_FONT = Kit.Font.body
	-- (Oct 27, the owner's mockup) a 1200 x 660 window: on the left "Rebirth n+1" with a one-line subtitle, the Current
	-- and Next stat cards (Power multiplier and walk speed, the two things a rebirth changes) with a chunky ">>>" between
	-- them, the reset warning as a small red pill, the progress bar and the big Rebirth button (grey "Need X" until
	-- ready). On the right the Skip Rebirth card (from rebirth 4, brief 24: earlier rebirths are quick, a paid skip would
	-- be poor value) or, before that, a "You keep" card that says what a rebirth leaves alone.
	rebirth = Windows.make('Rebirth', { Title = 'Rebirth', Icon = 'Rebirth', Tone = 'headerCyan', Width = 1200, Height = 660, TitleSize = 68, Gloss = false })
	local rw = rebirth.Well
	local MAIN_W, SIDE_X, SIDE_W, SIDE_H = 744, 772, 392, 506
	local main = Kit.new('Frame', { Name = 'Main', BackgroundTransparency = 1, Position = px(0, 0), Size = px(MAIN_W, 520), ZIndex = 25, Parent = rw })
	local bigTitle = label({ Name = 'From', Text = 'Rebirth 1', TextSize = 56, StrokeThickness = 6, AnchorPoint = Vector2.new(0.5, 0), Position = px(MAIN_W / 2, 0), Size = px(MAIN_W, 62), ZIndex = 26, Parent = main })
	local subLine = label({ Name = 'Unlock', Text = '', FontFace = RB_FONT, TextSize = 23, StrokeThickness = 3, TextColor3 = hex('CFE0FF'), AnchorPoint = Vector2.new(0.5, 0), Position = px(MAIN_W / 2, 64), Size = px(MAIN_W, 30), ZIndex = 26, Parent = main })
	local CARD_W, CARD_H, CARD_Y = 296, 150, 106
	local function statCard(name, x, heading, next)
		local box = Kit.block({ Name = name, Tone = 'navyRow', Width = CARD_W, Height = CARD_H, Position = px(x, CARD_Y), Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 12, Studs = false, ZIndex = 25 })
		box.Parent = main
		label({ Name = 'Heading', Text = heading, FontFace = RB_FONT, TextSize = 24, StrokeThickness = 3, TextColor3 = next and hex('FFE04A') or hex('CFE0FF'), Position = px(0, 6), Size = UDim2.new(1, 0, 0, 30), ZIndex = 28, Parent = box.Body })
		local values = {}
		for i, icon in { POWER, iconOr('Speed2x', 'Arrow') } do
			local y = 40 + (i - 1) * 50
			Kit.icon3d(icon, 50, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(40, y + 24), ZIndex = 28 }).Parent = box.Body
			local v = label({ Name = i == 1 and 'Value' or 'Speed', Text = '', TextSize = 32, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(76, y + 4), Size = UDim2.new(1, -84, 0, 40), ZIndex = 28, Parent = box.Body })
			if next then fillText(v, { hex('E6FF6A'), hex('7CF03A') }) end
			values[i] = v
		end
		return values
	end
	local fromValues = statCard('FromBox', 0, 'Current', false)
	local toValues = statCard('ToBox', MAIN_W - CARD_W, 'Next Rebirth', true)
	do
		-- the chunky ">>>" (blue, thick outline), bobbing a little
		local arrow = label({ Name = 'Arrow', Text = '>>>', TextSize = 76, StrokeThickness = 7, Stroke = hex('0A1A4A'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(MAIN_W / 2, CARD_Y + CARD_H / 2), Size = px(150, 90), ZIndex = 27, Parent = main })
		fillText(arrow, { hex('8EE4FF'), hex('2A7CF0') })
		Motion.bob(arrow, 5, 1.1)
	end
	do
		-- the reset warning: white on a small red pill (red text on navy was hard to read)
		local pill = Kit.block({ Name = 'Warning', Tone = 'cardRed', Width = 372, Height = 38, AnchorPoint = Vector2.new(0.5, 0), Position = px(MAIN_W / 2, 270), Outline = 3, OutlineColor = Kit.Skin.outline, RimWidth = 2, Radius = 19, Studs = false, ZIndex = 26 })
		pill.Parent = main
		label({ Name = 'Text', Text = 'Rebirth resets your Power', FontFace = RB_FONT, TextSize = 22, StrokeThickness = 3, Stroke = Kit.Tone.cardRed.stroke, Size = UDim2.fromScale(1, 1), ZIndex = 29, Parent = pill.Body })
	end
	local RBAR_W, RBAR_H, RBAR_Y = 600, 64, 322
	local barHolder = Kit.new('Frame', { Name = 'ProgressHolder', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = px(MAIN_W / 2 + 20, RBAR_Y - 16), Size = px(RBAR_W + 80, RBAR_H + 32), ZIndex = 25, Parent = main })
	local rebirthBar, rebirthFill, rebirthBarText = Kit.bar({ Name = 'Progress', Width = RBAR_W, Height = RBAR_H, Tone = 'buyGreen', Track = 'dark', TrackColor = Kit.Skin.well, TrackTransparency = 0, Radius = 10, Value = 0, Text = '0 / 0 Power', TextSize = 32, Position = px(80, 16), Outline = 5, Studs = 20, ZIndex = 25 })
	rebirthBar.Parent = barHolder
	if rebirthBarText and rebirthBarText.Text then rebirthBarText.Text.FontFace = RB_FONT end
	do
		-- the badge over the bar's left end (the reference's XP shield, tilted) with the Power arm on it
		local badge = Kit.icon3d(iconOr('Shield', 'XP'), 92, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(52, 16 + RBAR_H / 2), ZIndex = 29 })
		badge.Rotation = -10
		badge.Parent = barHolder
		Kit.icon3d(POWER, 54, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(52, 13 + RBAR_H / 2), ZIndex = 33 }).Parent = barHolder
	end
	-- the side cards (built once; update shows one)
	local skipCard, keepCard
	do
		skipCard = Kit.block({ Name = 'SkipCard', Tone = 'cardPurple', Width = SIDE_W, Height = SIDE_H, Position = px(SIDE_X, 0), Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 14, Studs = false, ZIndex = 25 })
		skipCard.Parent = rw
		skipCard.Visible = false
		label({ Name = 'Title', Text = 'Skip Rebirth', TextSize = 40, StrokeThickness = 5, Stroke = Kit.Tone.cardPurple.stroke, Position = px(0, 10), Size = UDim2.new(1, 0, 0, 48), ZIndex = 28, Parent = skipCard.Body })
		label({ Name = 'Sub', Text = 'Rebirth now, without the Power', FontFace = RB_FONT, TextSize = 21, StrokeThickness = 3, Stroke = Kit.Tone.cardPurple.stroke, TextColor3 = hex('FFE9FF'), Position = px(0, 56), Size = UDim2.new(1, 0, 0, 28), ZIndex = 28, Parent = skipCard.Body })
		Kit.icon3d(iconOr('RebirthSkip', 'Rebirth'), 132, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 158), ZIndex = 28 }).Parent = skipCard.Body
		local lines = {}
		for i = 1, 4 do
			local y = 232 + (i - 1) * 36
			local dot = Kit.new('Frame', { Name = 'Dot' .. i, BackgroundColor3 = i == 4 and hex('FFD84A') or hex('7CF03A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(34, y + 15), Size = px(14, 14), ZIndex = 28, Parent = skipCard.Body })
			Kit.corner(UDim.new(0.5, 0)).Parent = dot
			Kit.stroke(Kit.Skin.outline, 2, true).Parent = dot
			lines[i] = label({ Name = 'Line' .. i, Text = '', FontFace = RB_FONT, TextSize = 21, StrokeThickness = 3, Stroke = Kit.Tone.cardPurple.stroke, TextXAlignment = Enum.TextXAlignment.Left, Position = px(52, y), Size = UDim2.new(1, -60, 0, 30), ZIndex = 28, Parent = skipCard.Body })
		end
		skipCard:SetAttribute('Lines', 4)
		rebirth.SkipLines = lines
		local entry = Products.ByKey.SkipRebirth
		if entry then
			local btn = Kit.robuxButton({ Name = 'Skip', Tone = 'buyGreen', Price = entry.Price, TextSize = 40, Width = 300, Height = 80, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 12, ZIndex = 28 })
			btn.Parent = skipCard.Body
			Motion.button(btn, function() buy('SkipRebirth') end)
		end
		keepCard = Kit.block({ Name = 'KeepCard', Tone = 'navyRow', Width = SIDE_W, Height = SIDE_H, Position = px(SIDE_X, 0), Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 14, Studs = false, ZIndex = 25 })
		keepCard.Parent = rw
		label({ Name = 'Title', Text = 'You keep', TextSize = 40, StrokeThickness = 5, Position = px(0, 12), Size = UDim2.new(1, 0, 0, 48), ZIndex = 28, Parent = keepCard.Body })
		for i, row in { { iconOr('CashMedium', 'Cash'), 'Your Cash' }, { iconOr('Gun_Pistol', 'Gun'), 'Your guns' }, { iconOr('Sneaker', 'Shoe'), 'Your shoes' }, { iconOr('Trophy', 'Rebirth'), 'Stages and goals' } } do
			local y = 78 + (i - 1) * 96
			local r = Kit.block({ Name = 'Keep' .. i, Tone = 'navyRow', Width = SIDE_W - 40, Height = 82, Position = px(20, y), Outline = 3, OutlineColor = Kit.Skin.outline, RimWidth = 2, Radius = 10, Studs = false, ZIndex = 27 })
			r.Parent = keepCard.Body
			Kit.icon3d(row[1], 64, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(48, 41), ZIndex = 30 }).Parent = r.Body
			label({ Name = 'Text', Text = row[2], TextSize = 28, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(92, 0), Size = UDim2.new(1, -100, 1, 0), ZIndex = 30, Parent = r.Body })
		end
	end
	local rebirthAction, stopShine
	local ACTION_Y, ACTION_W, ACTION_H = 414, 440, 92
	local function skipLive(n) return Products.ByKey.SkipRebirth ~= nil and n >= 4 end
	local counted = {} -- the numbers' last shown value, for the count-up
	local function countTo(l, value, fmt)
		local from = counted[l]
		counted[l] = value
		if from == nil or from == value then l.Text = fmt(value) return end
		l.Text = fmt(from) -- (never a blank first frame)
		Motion.countTo(l, from, value, 0.5, fmt)
	end
	local function powerText(x) return times(x) .. ' Power' end
	local function speedText(n)
		local ok, v = pcall(function() return RebirthRules.walkSpeed(n) end)
		return (ok and type(v) == 'number') and (string.format('%g', math.floor(v * 10 + 0.5) / 10) .. ' Speed') or ''
	end
	local function update(opening)
		local power, n = num('Power', 0), rebirthsNow()
		local need = rebirthNeed(n)
		bigTitle.Text = 'Rebirth ' .. (n + 1)
		if opening then counted[fromValues[1]], counted[toValues[1]] = 1, 1 end
		countTo(fromValues[1], rebirthMultiplier(n), powerText)
		countTo(toValues[1], rebirthMultiplier(n + 1), powerText)
		fromValues[2].Text = speedText(n)
		toValues[2].Text = speedText(n + 1)
		local unlock = player:GetAttribute('RebirthUnlock')
		local hasUnlock = type(unlock) == 'string' and unlock ~= ''
		subLine.Text = hasUnlock and ('Next rebirth opens ' .. unlock .. '!') or 'More Power from every shot, and a faster walk'
		subLine.TextColor3 = hasUnlock and hex('7CFF4F') or hex('CFE0FF')
		local frac = math.clamp(power / need, 0, 1)
		if opening then
			rebirthFill.Size = UDim2.fromScale(0, 1)
			Motion.tween(rebirthFill, 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = UDim2.fromScale(frac, 1) })
		else
			rebirthFill.Size = UDim2.fromScale(frac, 1)
		end
		rebirthBarText.Text.Text = short(power) .. ' / ' .. short(need) .. ' Power'
		local maxed = RebirthRules and type(RebirthRules.Max) == 'number' and n >= RebirthRules.Max
		local ready = power >= need and not maxed
		local skip = skipLive(n) and not maxed
		skipCard.Visible, keepCard.Visible = skip, not skip
		if skip then
			local L = rebirth.SkipLines
			L[1].Text = 'Rebirth right now'
			L[2].Text = times(rebirthMultiplier(n + 1)) .. ' Power on every shot'
			L[3].Text = 'Keeps your Cash, guns, shoes'
			L[4].Text = 'Your Power starts over'
		end
		local text = maxed and 'Max rebirths!' or (ready and 'Rebirth' or ('Need ' .. short(need - power)))
		local key = ready and 'ready' or 'locked'
		if rebirthAction and rebirthAction:GetAttribute('Key') == key then
			local l = rebirthAction:FindFirstChild('Label', true)
			if l then l.Text = text end
			return
		end
		if stopShine then stopShine() stopShine = nil end
		if rebirthAction then rebirthAction:Destroy() end
		rebirthAction = Kit.blockButton({
			Name = 'Action', Tone = ready and 'buyGreen' or 'slate', Disabled = maxed, Text = text, FontFace = RB_FONT, TextSize = ready and 56 or 44,
			Icon = 'Rebirth', IconSize = 70, IconInset = 26, Width = ACTION_W, Height = ACTION_H, Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 14, Studs = false,
			Position = px(MAIN_W / 2 - ACTION_W / 2, ACTION_Y), ZIndex = 26,
		})
		rebirthAction.Parent = main
		if not maxed then
			Motion.button(rebirthAction, function()
				local nowPower, nowNeed = num('Power', 0), rebirthNeed()
				if nowPower < nowNeed then
					toast('Need ' .. short(nowNeed - nowPower) .. ' more Power!', 'red')
					return
				end
				Net.get('Rebirth'):FireServer()
				Windows.close()
			end)
		end
		rebirthAction:SetAttribute('Key', key)
		if ready then stopShine = Motion.shine(rebirthAction.Body, 2.6, UDim.new(0, 3)) end
	end
	rebirth.Open = function() update(true) end
	rebirth.Update = function() update(false) end
end
do
	---------------------------------------------------------------- QUEST (the goal chain; a tap on the goal line opens it)
	quest = Windows.make('Quest', { Title = 'Goals', Icon = iconOr('Quest', 'Trophy'), Tone = 'headerBrown', Width = 940, Height = 642 })
	local questList = Kit.new('ScrollingFrame', {
		Name = 'Goals', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 24,
		ScrollBarThickness = 8, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = quest.Well,
	})
	questList:SetAttribute('NoStagger', true)
	Kit.new('UIListLayout', { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = questList })
	Kit.new('UIPadding', { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), Parent = questList })
	local function questRow(goal, state)
		local tone = state == 'done' and 'lime' or state == 'now' and 'gold' or 'navyRow'
		local row = Kit.block({ Name = goal.Id or 'Goal', Tone = tone, Width = 860, Height = 74, Outline = 4, OutlineColor = Kit.Skin.outline, Radius = 10, RimWidth = 3, Studs = Kit.studsAreCheap() and 34 or false, ZIndex = 25 })
		row.LayoutOrder = goal.Step or 0
		if state == 'done' then
			for i, b in { { 16, 30, 46, 40 }, { 34, 25, -48, 22 } } do
				local f = Kit.new('Frame', { Name = 'Tick' .. i, BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(b[2] + 10, 37 + (i == 1 and 6 or -2)), Size = px(b[1], 8), Rotation = b[3], ZIndex = 28, Parent = row.Body })
				Kit.stroke(BLACK, 3, true, 0, Enum.LineJoinMode.Miter).Parent = f
			end
		else
			label({ Name = 'Step', Text = tostring(goal.Step or ''), TextSize = 36, StrokeThickness = 4, Position = px(10, 0), Size = px(56, 74), ZIndex = 28, Parent = row.Body })
		end
		local text = label({ Name = 'Text', Text = goal.Text or '', TextSize = 26, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(74, 6), Size = px(640, 32), ZIndex = 28, Parent = row.Body })
		text.TextScaled = true
		Kit.new('UITextSizeConstraint', { MaxTextSize = 26, MinTextSize = 12, Parent = text })
		local where = label({ Name = 'Where', Text = goal.Where or '', TextSize = 19, StrokeThickness = 2.5, TextColor3 = hex('E8FBFF'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(74, 40), Size = px(640, 24), ZIndex = 28, Parent = row.Body })
		where.TextScaled = true
		Kit.new('UITextSizeConstraint', { MaxTextSize = 19, MinTextSize = 10, Parent = where })
		Kit.icon3d('Cash', 46, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -150, 0.5, 0), ZIndex = 28 }).Parent = row.Body
		fillText(label({ Name = 'Reward', Text = '+' .. short(goal.Reward or 0), TextSize = 30, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(1, -100, 0, 0), Size = px(96, 74), ZIndex = 28, Parent = row.Body }), { hex('F0FF8A'), hex('3CCB3C') })
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
			label({ Name = 'Loading', Text = 'Loading...', TextSize = 30, Size = px(860, 80), Parent = questList, ZIndex = 26 })
			return
		end
		for i, goal in GoalRules.List do
			questRow(goal, i < step and 'done' or i == step and 'now' or 'next').Parent = questList
		end
		task.defer(function() questList.CanvasPosition = Vector2.new(0, math.max(0, (step - 2) * (74 + 12))) end)
	end
	quest.Open = fillQuest
	quest.Update = fillQuest
end
do
	---------------------------------------------------------------- RANKS (the rank row's "+")
	-- The eight ranks (LevelRules.Ranks) as rows: the badge, the name in its colour, the level it needs and the Cash it pays;
	-- yours gold, the ones you passed ticked.
	ranks = Windows.make('Ranks', { Title = 'Ranks', Icon = iconOr('Rank', 'Shield'), Tone = 'headerCyan', Width = 760, Height = 600, Gloss = false })
	local list = Kit.new('Frame', { Name = 'List', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = ranks.Well })
	list:SetAttribute('NoStagger', true)
	local function fillRanks()
		for _, c in list:GetChildren() do c:Destroy() end
		if not LevelRules then return end
		local mine = LevelRules.rankIndex(num('BestLevel', 1))
		for i, r in LevelRules.Ranks do
			local state = i < mine and 'done' or i == mine and 'now' or 'next'
			local row = Kit.block({ Name = r.Id, Tone = state == 'now' and 'gold' or 'navyRow', Width = 680, Height = 50, Outline = 3.5, OutlineColor = Kit.Skin.outline, Radius = 8, RimWidth = 2, Studs = false, Position = px(18, (i - 1) * 56), ZIndex = 25 })
			row.Parent = list
			Kit.icon3d(iconOr('Rank', 'Shield'), 40, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 28 }).Parent = row.Body
			local name = label({ Name = 'Name', Text = r.Name, TextSize = 26, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(58, 0), Size = px(260, 50), ZIndex = 28, Parent = row.Body })
			name.TextColor3 = hex(string.sub(r.Color, 2))
			label({ Name = 'Level', Text = 'Level ' .. r.Level, TextSize = 22, StrokeThickness = 3, Position = px(320, 0), Size = px(150, 50), ZIndex = 28, Parent = row.Body })
			if (r.Cash or 0) > 0 then
				fillText(label({ Name = 'Cash', Text = '+' .. short(r.Cash) .. ' Cash', TextSize = 22, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Right, Position = px(470, 0), Size = px(190, 50), ZIndex = 28, Parent = row.Body }), { hex('F0FF8A'), hex('3CCB3C') })
			end
			row:SetAttribute('State', state)
			local s = Motion.scaleOf(row)
			s.Scale = 0.6
			task.delay(0.03 * i, function() Motion.tween(s, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
		end
	end
	ranks.Open = fillRanks
end
-- The Daily Rewards window keeps its look (the user's own mockup will restyle it): Shared/DailyWindow builds it.
local daily = require(Shared.DailyWindow)(Windows, { buy = buy, label = label, fillText = fillText })
do
	local open = Instance.new('BindableEvent')
	open.Name = 'OpenDaily'
	open.Parent = gui
	open.Event:Connect(function() if Windows.current() ~= daily then Windows.open(daily) end end)
	local openQuest = Instance.new('BindableEvent')
	openQuest.Name = 'OpenQuest'
	openQuest.Parent = gui
	openQuest.Event:Connect(function() Windows.toggle(quest) end)
end

actions.Store = function() openStore() end
actions.Rebirth = function() Windows.toggle(rebirth) end
actions.Ranks = function() Windows.toggle(ranks) end
local function openOther(guiName, arg)
	local g = playerGui:FindFirstChild(guiName)
	local open = g and g:FindFirstChild('Open')
	if open and open:IsA('BindableEvent') then
		Windows.close()
		open:Fire(arg)
		return true
	end
	return false
end
actions.Shoes = function() if not openOther('HoodInventory', 'Shoes') then toast('Shoes: loading...', 'blue') end end
actions.Items = function() if not openOther('HoodInventory', 'Items') then toast('Items: loading...', 'blue') end end
-- (the reference's Skins: our gun skins are the inventory's Guns tab)
actions.Skins = function() if not openOther('HoodInventory', 'Guns') then toast('Skins: loading...', 'blue') end end

do
	-- (brief 24, 28c) The unboxing moment (PlayerGui UnboxingCalm) calms the HUD like the soldier game: the column slides
	-- out left, the cards and the top-right extras right, the bottom block down, the wheel up, in 0.1 s; they come back in
	-- 0.2 s as the pair flies into the Shoes button.
	-- (Shoes.client flies the pair to where the Shoes square comes back to, reckoning 360 px at Kit's scale: the column
	-- steps that far in screen px, whatever the HUD's own scale)
	local function asideK()
		local abs = gui.AbsoluteSize
		if abs.X < 1 or abs.Y < 1 then return 1 end
		return Kit.scaleFor(abs) / Spec.scaleFor(abs)
	end
	playerGui:GetAttributeChangedSignal('UnboxingCalm'):Connect(function()
		local calm = playerGui:GetAttribute('UnboxingCalm') == true
		Motion.aside({ { column, px(-360 * asideK(), 0) }, { offers, px(320, 0) }, { status, px(0, 300) }, { slots.SpinSlot, px(0, -200) }, { slots.PlaytimeSlot, px(0, -260) }, { slots.StarterSlot, px(320, 0) }, { slots.MissionsSlot, px(320, 0) } }, calm, calm and 0.1 or 0.2)
	end)
end

local refreshCounters, refresh
do
	---------------------------------------------------------------------------------------------- live values
	local shownPower = Instance.new('NumberValue')
	shownPower.Changed:Connect(function(v) powerLabel.Text = short(v) end)
	local shownCash = Instance.new('NumberValue')
	shownCash.Changed:Connect(function(v) cashCount.Text = short(v) end)
	-- the Power count centred over the bar, but never over "Multiplier: x1" at its left (on phones its words grow)
	local function centrePower()
		local w = Spec.Bottom.PowerIcon + 6 + Kit.textWidth(powerLabel.Text, powerLabel.TextSize)
		powerRow.Size = px(w, 34)
		local clear = Spec.Bottom.MultX + Kit.textWidth(multiplierLabel.Text, multiplierLabel.TextSize) + 8 + w / 2
		powerRow.Position = px(math.max(Spec.Bottom.BarW / 2, clear), powerRow.Position.Y.Offset)
	end
	multiplierLabel:GetPropertyChangedSignal('Text'):Connect(centrePower)
	multiplierLabel:GetPropertyChangedSignal('TextSize'):Connect(centrePower)
	powerLabel:GetPropertyChangedSignal('Text'):Connect(centrePower)
	-- (brief 23, counter juice) every gain makes its counter jump and floats a small "+N" beside it; gains within 0.25 s add up
	local floating = {}
	local function gainFloat(key, row, x, amount, colors)
		local f = floating[key]
		if f and f.Label.Parent and os.clock() - f.At < 0.25 then
			f.Sum += amount
			f.Label.Text = '+' .. short(f.Sum)
			return
		end
		local l = fillText(label({ Name = 'Gain', Text = '+' .. short(amount), TextSize = 20, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, -4), Size = px(120, 26), ZIndex = 4, Parent = row }), colors)
		floating[key] = { Label = l, At = os.clock(), Sum = amount }
		Motion.tween(l, 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = UDim2.new(0, x + 6, 0.5, -30), TextTransparency = 1 })
		local st = l:FindFirstChildOfClass('UIStroke')
		if st then Motion.tween(st, 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Transparency = 1 }) end
		task.delay(0.8, function() l:Destroy() end)
	end
	local lastPower, lastCash, lastRebirths
	function refreshCounters()
		local cash, n = cashNow(), rebirthsNow()
		if lastCash == nil or cash < lastCash then
			shownCash.Value = cash
		elseif cash > lastCash then
			-- (the reference's Wins counter rolls to the new number, 0.5 s ease-out)
			Motion.tween(shownCash, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = cash })
			Motion.bump(counters.Cash, 0.18)
		end
		cashCount.Text = short(shownCash.Value)
		rebirthCount.Text = short(n)
		if lastRebirths and n > lastRebirths then
			Motion.pop(rebirthIcon, 0.3)
			task.delay(0.5, function() rebirthMoment(n) end)
		end
		lastCash, lastRebirths = cash, n
	end
	local wasReady = false
	function refresh()
		local power = num('Power', nil)
		if power == nil then return end
		local n = rebirthsNow()
		local need = rebirthNeed(n)
		if lastPower == nil then
			shownPower.Value = power
		elseif power < lastPower then
			Motion.tween(shownPower, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Value = power })
		elseif power > lastPower then
			Motion.tween(shownPower, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = power })
			Motion.bump(powerRow, 0.15)
			gainFloat('Power', powerRow, powerRow.Size.X.Offset + 6, power - lastPower, Spec.Text.gold)
		end
		powerLabel.Text = short(shownPower.Value)
		lastPower = power
		multiplierLabel.Text = 'Multiplier: ' .. times(totalMultiplier())
		centrePower()
		local ready = power >= need
		if LevelRules then
			local level, into, span, frac, maxed = LevelRules.progress(power)
			barText.Left.Text = 'Level ' .. level
			barText.Right.Text = ready and 'MAX - Rebirth!' or (maxed and 'MAX' or (short(into) .. ' / ' .. short(span)))
			fill.Size = UDim2.fromScale(ready and 1 or frac, 1)
			local rank = LevelRules.rankOf(num('BestLevel', level))
			rankText.Text = rank.Name
		else
			barText.Left.Text = 'Rebirth ' .. n
			barText.Right.Text = ready and 'MAX - Rebirth!' or (short(power) .. ' / ' .. short(need))
			fill.Size = UDim2.fromScale(math.clamp(power / need, 0, 1), 1)
		end
		local g = fill:FindFirstChildOfClass('UIGradient')
		if g then g.Color = Kit.fillGradient(ready and T.levelReady or T.level).Color end
		-- (brief 23: one number size on all three packs, the longest decides; brief 29: the server's amount)
		local size = Spec.Bottom.PackText
		for _, key in { 'PowerPack1', 'PowerPack2', 'PowerPack3' } do
			local l = packLabels[key]
			l.Text = '+' .. short(Products.powerAmount(key, need, power))
			size = math.min(size, Kit.fitSize(l.Text, Spec.Bottom.PackText, Spec.Bottom.PackW - 30, 12))
		end
		for _, key in { 'PowerPack1', 'PowerPack2', 'PowerPack3' } do packLabels[key].TextSize = size end
		local percent = math.clamp(math.floor(power / need * 100), 0, 100)
		rebirthPillText.Text = percent .. '%'
		if percent >= 100 and not wasReady then Motion.pop(rebirthPill, 0.35) end
		wasReady = percent >= 100
		local current = Windows.current()
		if current and current.Update then current.Update() end
	end
	-- a running timed boost: "2x Boost 14:59"
	task.spawn(function()
		while true do
			local level = num('PowerBoost', 1)
			local left = math.max(num('BoostEnds', 0), num('PartyEnds', 0)) - os.time()
			boostChip.Visible = level > 1 and left > 0
			if boostChip.Visible then boostChip.Text = times(level):sub(2) .. 'x Boost  ' .. string.format('%d:%02d', math.floor(left / 60), left % 60) end
			-- the Rebirth pill breathes while a rebirth is ready (a slow 1.0 -> 1.12 -> 1.0, never a flash)
			if wasReady and not quiet() then Motion.pop(rebirthPill, 0.12) end
			task.wait(1)
		end
	end)
	for _, key in { 'Power', 'BestLevel', 'GunMultiplier', 'EquippedGun', 'OwnedGuns', 'RebirthNeed', 'RebirthMultiplier', 'RebirthNextMultiplier', 'RebirthUnlock', 'ShoeMultiplier', 'ShotMultiplier', 'Pass_DoubleRep', 'GoalStep', 'FriendBoost' } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	for _, key in { 'Cash', 'Rebirths' } do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshCounters()
			refresh()
		end)
	end
	local function applyProfile(profile)
		if type(profile) ~= 'table' then return end
		snapshot.Cash = type(profile.Cash) == 'number' and profile.Cash or snapshot.Cash
		snapshot.Rebirths = type(profile.Rebirths) == 'number' and profile.Rebirths or snapshot.Rebirths
		refreshCounters()
		refresh()
	end
	task.spawn(function()
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
end

do
	---------------------------------------------------------------------------------------------- layout
	-- PC: the reference's places (HudSpec), the column and the bottom-left block on the left edge, the cards and the top
	-- extras on the right edge, the bottom block centred. Phones (the shorter side <= 500 px): the bottom-left is the
	-- thumbstick's and the bottom-right the jump button's, so the column, the counters and the cards are a little smaller
	-- and higher, the counters sit in one row under the column, and the bottom block slides left of the SHOOT button.
	local SHOOT_RIGHT, SHOOT_SIZE = 150, 112
	local function relayout()
		local abs = gui.AbsoluteSize
		if abs.X < 1 or abs.Y < 1 then return end
		fit(abs)
		local k = Spec.scaleFor(abs)
		local w, h = abs.X / k, abs.Y / k
		local phone = math.min(abs.X, abs.Y) <= 500
		local C = Spec.Column
		local small = phone and 0.9 or 1
		for _, f in { column, counters, offers, status, slots.SpinSlot, slots.PlaytimeSlot, slots.StarterSlot, slots.MissionsSlot } do
			f.LayoutScale.Scale = small
		end
		if phone then
			column.Position = px(C.X, 60)
			-- the counters: rank, rebirths and Cash one under the other beside the column, clear of the thumbstick
			counters.AnchorPoint = Vector2.new(0, 0)
			counters.Position = px(C.X + C.ShopW * small + 10, 60 + 60)
			-- (Oct 27, release fixes: the right column overlapped on phones: Playtime ran into Missions and the Starter Pack,
			-- Missions into the cards) a tidy block at the top right, in design px at the 0.9 phone scale: Playtime (108 wide)
			-- and the Starter Pack (135) side by side on top, Missions under Playtime, the offer cards under the Starter Pack
			-- (their pictures poke ~13 over a card), each at least 4 px clear of the next
			slots.StarterSlot.Position = UDim2.new(1, -82, 0, 0)
			slots.PlaytimeSlot.Position = UDim2.new(1, -214, 0, 0)
			slots.MissionsSlot.Position = UDim2.new(1, -214, 0, 112)
			offers.Position = UDim2.new(1, -Spec.Offers.Right, 0, 142)
		else
			column.Position = px(C.X, C.Y)
			counters.AnchorPoint = Vector2.new(0, 1)
			counters.Position = UDim2.new(0, 0, 1, 0)
			offers.Position = UDim2.new(1, -Spec.Offers.Right, 0, Spec.Offers.Top)
			-- (Oct 27, release fixes: on a computer the Starter Pack's slot (82..212) sat on the x2 Cash card (its picture pokes
			-- ~32 over its top at 179)) the Starter Pack moves up beside Playtime: Playtime (x -301..-181) and the Starter
			-- Pack (-169..-19) side by side on top, Missions under Playtime, the cards under the Starter Pack
			slots.StarterSlot.Position = UDim2.new(1, -Spec.Starter.Right, 0, Spec.Starter.Y)
			slots.PlaytimeSlot.Position = UDim2.new(1, -Spec.Playtime.Right, 0, Spec.Playtime.Y)
			slots.MissionsSlot.Position = UDim2.new(1, -Spec.Missions.Right, 0, Spec.Missions.Y)
		end
		-- the Spin wheel's glow reaches ~54 over its slot's centre: on a big screen (the HUD scaled up, Roblox's top bar not)
		-- it would run off the top, so it comes down just enough to stay on the screen
		local okI, inset = pcall(function() return game:GetService('GuiService'):GetGuiInset() end)
		local room = (okI and typeof(inset) == 'Vector2' and inset.Y or Spec.Inset) / k
		slots.SpinSlot.Position = UDim2.new(0, Spec.Spin.X, 0, math.max(Spec.Spin.Y, math.ceil(56 - room)))
		-- the bottom block centred, unless that would put the Auto Fight button under the SHOOT button (phones)
		local B = Spec.Bottom
		local shootLeft = (abs.X - SHOOT_RIGHT - SHOOT_SIZE) / k
		local x = w / 2 - B.BarW * small / 2
		if phone then x = math.min(x, shootLeft - 10 - (B.BarW + B.AutoGap + B.AutoW) * small) end
		status.Position = UDim2.new(0, x, 1, 0)
		-- (phones: the Autowin slot's word is shorter, so it can be big enough to read)
		local word = status.AutoShoot.Body:FindFirstChild('Word')
		if word then
			word.Text = phone and 'Auto' or 'Auto Fight'
			word.TextSize = phone and 18 or 12
		end
		-- (brief 28) phones: no word under Kit.PhoneMinText dp
		local floor = phone and k * small or nil
		for _, box in { column, status, offers, counters } do Kit.textFloor(box, floor) end
		Toasts.place()
	end
	gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
	gui.Parent = playerGui
	relayout()
	refreshCounters()
	refresh()
	paintShines()
	arrive()
	print('[HoodHUD] ready') -- (StudioCheck.client reads this and the start line to tell where a broken HUD stopped)
end
