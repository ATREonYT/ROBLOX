-- Reasons to come back, and honest offers (brief 29, P5). The Daily Rewards window and the HUD's buttons are HUD.client's; the
-- rules are Shared/RetentionRules and the server is HoodServer/RetentionService. This script draws the small cards:
--   * Welcome back   a card with the Power you earned while away (up to 8 h) and a "Claim", plus the 2x Offline Robux
--                    offer with its real price. Only from the second visit; never in a new player's first minutes.
--   * Before You Go! (the reference's) when the Roblox menu opens (GuiService.MenuOpened): "You earn Power while offline!",
--                    IN 8 HOURS +X Power, TOMORROW's daily reward, OK!. A reminder, not a wall: nothing blocks input, it fades
--                    by itself, at most once every 10 minutes.
--   * Friend Boost   the small chip bottom-left: +10 % Power per friend in the server, up to +50 %, with a "+" to invite.
--   * Offers         a small "2x Power 15 min" chip after 30 s of grinding at a range, and one after a knock-out, each with
--                    the REAL price on it, closable, once in a long while, and only for a product that is really on sale
--                    (Products.canBuy). Nothing counts down, nothing is "limited". None in a new player's first minutes.
-- The daily window itself opens by itself once per visit from the second one (HoodHUD.OpenDaily), never on a first join.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local GuiService = game:GetService('GuiService')
local MarketplaceService = game:GetService('MarketplaceService')
local SocialService = game:GetService('SocialService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px, hex, Color = UDim2.fromOffset, Kit.hex, Kit.Color
local POWER = Kit.iconOr('Muscle', 'Power')

local gui, root, fit = Kit.screen('HoodRetention', nil, 9)
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X >= 1 and abs.Y >= 1 then fit(abs) end
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()

local function label(props)
	props.Stroke = props.Stroke or Color.black
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	return Kit.text(props)
end
local function gradient(t, top, bottom)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = t })
	return t
end
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
local function quiet() return player:GetAttribute('OnboardingQuiet') == true end
local function windowOpen()
	local w = playerGui:GetAttribute('HoodWindow')
	return (type(w) == 'string' and w ~= '') or playerGui:GetAttribute('Unboxing') == true
end

---------------------------------------------------------------------------------------------- the server's state
local state, stateAt = nil, 0
local function ask(action)
	local ok, res = pcall(function() return Net.get('Retention'):InvokeServer(action) end)
	return ok and type(res) == 'table' and res or nil
end
local function fetch()
	local res = ask('State')
	if res and res.State then state, stateAt = res.State, os.clock() end
	return state
end

---------------------------------------------------------------------------------------------- the two cards
local CARD_W, CARD_H = 700, 580
local card -- the card on screen (nil when none): { Dim, Kind }
local function closeCard()
	local c = card
	card = nil
	if c and c.Dim.Parent then c.Dim:Destroy() end
end
-- The dimmed world and the card's frame: title, subtitle and room for two columns. Input passes through the dim
-- (Active false), so nothing is blocked; only the buttons take clicks.
local function makeCard(kind, title, titleTop, titleBottom, subtitle)
	closeCard()
	local dim = Kit.new('Frame', { Name = kind, BackgroundColor3 = Color.ink, BackgroundTransparency = 0.5, BorderSizePixel = 0, Active = false, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = root })
	local holder = Kit.new('Frame', { Name = 'Card', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(CARD_W, CARD_H), ZIndex = 41, Parent = dim })
	gradient(label({ Name = 'Title', Text = title, TextSize = 84, StrokeThickness = 9, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = px(CARD_W, 100), ZIndex = 42, Parent = holder }), titleTop, titleBottom)
	label({ Name = 'Subtitle', Text = subtitle, TextSize = 38, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = px(CARD_W, 50), ZIndex = 42, Parent = holder })
	card = { Dim = dim, Kind = kind, Holder = holder }
	return holder
end
-- One column: a gradient header, a big icon, a value line (and an optional small line).
local function column(holder, cx, header, headerTop, headerBottom, iconId, value, small)
	gradient(label({ Name = 'Header', Text = header, TextSize = 34, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, 176), Size = px(300, 42), ZIndex = 42, Parent = holder }), headerTop, headerBottom)
	Kit.icon3d(iconId, 150, { AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, 222), ZIndex = 42 }).Parent = holder
	label({ Name = 'Value', Text = value, TextSize = 42, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, 382), Size = px(320, 52), ZIndex = 42, Parent = holder })
	if small and small ~= '' then label({ Name = 'Small', Text = small, TextSize = 22, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, 432), Size = px(320, 30), ZIndex = 42, Parent = holder }) end
end
local function bigButton(holder, text, tone, cx, w, onClick)
	local b = Kit.blockButton({ Name = text, Tone = tone, Width = w, Height = 84, Text = text, TextSize = 52, ZIndex = 44 })
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = px(cx, 478)
	b.Parent = holder
	Motion.button(b, onClick)
	return b
end
local function tomorrowText(st)
	local d = st and st.Daily
	if not d then return 'a daily reward' end
	local day = d.Day
	local c = d.Cards and d.Cards[day]
	local line = c and c.Lines and c.Lines[1] or 'a reward'
	return 'Day ' .. day .. ': ' .. line
end

---------------------------------------------------------------- BEFORE YOU GO!
local lastBeforeYouGo = -math.huge
local function showBeforeYouGo()
	if card or quiet() or windowOpen() then return end
	if os.clock() - lastBeforeYouGo < 600 then return end
	local st = state
	if not st or not st.Offline then return end
	lastBeforeYouGo = os.clock()
	local holder = makeCard('BeforeYouGo', 'Before You Go!', hex('FF6A5A'), hex('E02020'), 'You earn Power while offline!')
	local ready = st.Daily and st.Daily.Ready
	column(holder, 190, 'IN ' .. st.Offline.CapHours .. ' HOURS', hex('F4F030'), hex('7CE030'), POWER, '+' .. Format.compact(st.Offline.EightHours) .. ' Power', 'Come back to claim it')
	column(holder, 510, ready and 'TODAY' or 'TOMORROW', hex('FFF04A'), hex('FFB020'), ready and 'Rewards' or 'PotionGold', ready and 'Daily reward' or 'Daily reward', tomorrowText(st))
	local dim = card.Dim
	bigButton(holder, 'OK!', 'lime', CARD_W / 2, 250, closeCard)
	-- a reminder, not a wall: it fades by itself
	task.delay(14, function() if card and card.Dim == dim then closeCard() end end)
end
pcall(function() GuiService.MenuOpened:Connect(function() task.spawn(function()
	if not state or os.clock() - stateAt > 120 then fetch() end
	showBeforeYouGo()
end) end) end)

---------------------------------------------------------------- WELCOME BACK
local function buy(key)
	local entry = Products.ByKey[key]
	if not Products.canBuy(key) then
		return false, (entry and entry.Title or 'This') .. ' is coming soon!'
	end
	local id = Products.idOf(key)
	pcall(function()
		if entry.Kind == 'Pass' then MarketplaceService:PromptGamePassPurchase(player, id) else MarketplaceService:PromptProductPurchase(player, id) end
	end)
	return true
end
local welcomed = false
local afterWelcome -- (forward)
local function showWelcomeBack(st)
	local pending = st.Offline.Pending
	local holder = makeCard('WelcomeBack', 'Welcome back!', hex('9CFF5A'), hex('3CC820'), 'You earned Power while you were away!')
	column(holder, 190, 'WHILE AWAY', hex('F4F030'), hex('7CE030'), POWER, '+' .. Format.compact(pending) .. ' Power', 'Up to ' .. st.Offline.CapHours .. ' hours count')
	local entry = Products.ByKey.OfflineX2
	column(holder, 510, '2x OFFLINE', hex('FFF04A'), hex('FFB020'), 'PotionGold', '+' .. Format.compact(pending * 2) .. ' Power', 'Pay once, get it doubled')
	local dim = card.Dim
	local say = label({ Name = 'Say', Text = '', TextSize = 22, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = px(CARD_W / 2, 556), Size = px(CARD_W, 26), ZIndex = 44, Parent = holder })
	bigButton(holder, 'Claim', 'lime', 190, 250, function()
		local res = ask('ClaimOffline')
		if res and res.State then state, stateAt = res.State, os.clock() end
		if card and card.Dim == dim then closeCard() end
		afterWelcome()
	end)
	if entry then
		-- the offer, with its real price on the button
		local b = Kit.robuxButton({ Name = 'X2', Tone = 'gold', Width = 250, Height = 84, Price = entry.Price, TextSize = 46, ZIndex = 44 })
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = px(510, 478)
		b.Parent = holder
		Motion.button(b, function()
			local ok, why = buy('OfflineX2')
			if not ok then say.Text = why end
		end)
	end
end
afterWelcome = function() end

pcall(function()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, bought)
		if bought and Products.keyFor('Product', id) == 'OfflineX2' then
			task.delay(2, function()
				fetch()
				if card and card.Kind == 'WelcomeBack' then closeCard() end
			end)
		end
	end)
end)

---------------------------------------------------------------------------------------------- friend boost chip
do
	local chip = Kit.new('Frame', { Name = 'FriendBoost', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -142), Size = px(330, 34), ZIndex = 5, Parent = root })
	local text = label({ Name = 'Text', Text = 'Friend Boost: +0%', TextSize = 22, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(0, 0), Size = px(250, 34), ZIndex = 6, Parent = chip })
	local plus = Kit.blockButton({ Name = 'Invite', Tone = 'lime', Width = 34, Height = 34, Text = '+', TextSize = 26, Outline = 3, Studs = false, ZIndex = 6 })
	plus.Position = px(238, 0)
	plus.Parent = chip
	local function paint()
		local boost = num('FriendBoost', 0)
		text.Text = 'Friend Boost: +' .. math.floor(boost * 100 + 0.5) .. '%'
		text.TextColor3 = boost > 0 and hex('FFE24A') or Color.white
		plus.Position = px(Kit.textWidth(text.Text, 22) + 12, 0)
	end
	player:GetAttributeChangedSignal('FriendBoost'):Connect(paint)
	paint()
	-- (the "+" asks Roblox to open its own invite sheet; a player who can't invite just sees nothing happen)
	Motion.button(plus, function()
		pcall(function()
			if SocialService:CanSendGameInviteAsync(player) then SocialService:PromptGameInvite(player) end
		end)
	end)
	-- the chip steps aside with the HUD while a window or the unboxing moment is up
	local function place() chip.Visible = not windowOpen() end
	playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(place)
	playerGui:GetAttributeChangedSignal('Unboxing'):Connect(place)
end

---------------------------------------------------------------------------------------------- contextual offers
-- A small chip: a title, a line, the REAL price on a button, a close X. Gone after `ttl` seconds. At most one at a time.
local chipUp = false
local function offerChip(key, title, line, ttl)
	local entry = Products.ByKey[key]
	if chipUp or quiet() or windowOpen() or not entry or not Products.canBuy(key) then return false end
	chipUp = true
	local block = Kit.block({ Name = 'Offer', Tone = 'cardPurple', Width = 430, Height = 74, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -200), Outline = 4, Studs = 18, ZIndex = 30 })
	block.Parent = root
	label({ Name = 'Title', Text = title, TextSize = 26, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(12, 4), Size = px(250, 34), ZIndex = 33, Parent = block.Body })
	label({ Name = 'Line', Text = line, TextSize = 17, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(12, 38), Size = px(250, 24), ZIndex = 33, Parent = block.Body })
	local price = Kit.robuxButton({ Name = 'Price', Tone = 'lime', Width = 128, Height = 46, Price = entry.Price, TextSize = 26, ZIndex = 32 })
	price.AnchorPoint = Vector2.new(1, 0.5)
	price.Position = px(398 - 8, 34)
	price.Parent = block.Body
	local function gone()
		if chipUp then
			chipUp = false
			block:Destroy()
		end
	end
	Motion.button(price, function()
		buy(key)
		gone()
	end)
	local close = Kit.blockButton({ Name = 'Close', Tone = 'red', Width = 30, Height = 30, Text = 'X', TextSize = 20, Outline = 3, Studs = false, ZIndex = 34 })
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = px(430 - 12, 4)
	close.Parent = block.Body
	Motion.button(close, gone)
	task.delay(ttl or 14, gone)
	return true
end

local function boostRunning() return num('PowerBoost', 1) > 1 end
local lastRangeOffer, lastKoOffer = -math.huge, -math.huge
-- Grinding at a range for 30 s: one quiet "2x Power" chip, at most every 15 minutes (never while a boost is running).
task.spawn(function()
	local since
	while task.wait(1) do
		local station = player:GetAttribute('TrainingStation')
		if type(station) == 'string' and station ~= '' then
			since = since or os.clock()
			if os.clock() - since >= 30 and not boostRunning() and os.clock() - lastRangeOffer > 900 then
				if offerChip('RepBoost2x', '2x Power, 15 min', 'Every shot pays double while you train.', 12) then lastRangeOffer = os.clock() end
			end
		else
			since = nil
		end
	end
end)
-- A knock-out: you are put back at the start of the street healed, so "try again" is already happening; the chip only
-- offers a boost for the next go. At most every 5 minutes.
pcall(function()
	Net.get('WaveState').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'KO' and not boostRunning() and os.clock() - lastKoOffer > 300 then
			if offerChip('RepBoost2x', 'Try again with 2x Power?', 'You are back at the start, healed.', 12) then lastKoOffer = os.clock() end
		end
	end)
end)

-- (a hook for the offline renderer and tests: BindableEvent HoodRetention.Show('BeforeYouGo' | 'WelcomeBack') runs the same
-- functions the real triggers do; it only ever draws this player's own card)
do
	local ev = Instance.new('BindableEvent')
	ev.Name = 'Show'
	ev.Parent = gui
	ev.Event:Connect(function(kind)
		task.spawn(function()
			if not state then fetch() end
			if kind == 'BeforeYouGo' then
				lastBeforeYouGo = -math.huge
				showBeforeYouGo()
			elseif kind == 'WelcomeBack' and state then
				showWelcomeBack(state)
			end
		end)
	end)
end

---------------------------------------------------------------------------------------------- a visit starts
task.spawn(function()
	while player:GetAttribute('ProfileReady') ~= true do task.wait(0.5) end
	local st
	for _ = 1, 20 do
		st = fetch()
		if st then break end
		task.wait(1)
	end
	if not st or st.Joins < 2 then return end -- (a first visit gets no popups at all)
	local function openDaily()
		if not st.Daily or not st.Daily.Ready or quiet() then return end
		local hud = playerGui:FindFirstChild('HoodHUD')
		local ev = hud and hud:FindFirstChild('OpenDaily')
		if ev and not windowOpen() and not card then ev:Fire() end
	end
	afterWelcome = function()
		task.delay(1.5, function()
			fetch()
			st = state or st
			openDaily()
		end)
	end
	task.wait(5)
	if quiet() or windowOpen() then return end
	if st.Offline and st.Offline.Pending > 0 and not welcomed then
		welcomed = true
		showWelcomeBack(st)
	else
		openDaily()
	end
end)
