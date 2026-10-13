-- Reasons to come back, and honest offers (brief 29, P5). The Daily Rewards window and the HUD's buttons are HUD.client's; the
-- rules are Shared/RetentionRules and the server is HoodServer/RetentionService. This script draws the small cards:
--   * Welcome back   a card with the Power you earned while away (up to 8 h) and a "Claim", plus the 2x Offline Robux
--                    offer with its real price. Only from the second visit; never in a new player's first minutes.
--   * Before You Go! (the reference's) when the Roblox menu opens (GuiService.MenuOpened): "You earn Power while offline!",
--                    IN 8 HOURS +X Power, TOMORROW's daily reward, OK!. A reminder, not a wall: nothing blocks input, it fades
--                    by itself, at most once every 10 minutes.
--   (brief 30: the Friend Boost line moved into HUD.client's bottom-left block, the reference's place for it)
--   * Offers         a small "2x Power 15 min" chip after 30 s of grinding at a range, and one after a knock-out, each with
--                    the REAL price on it, closable, once in a long while, and only for a product that is really on sale
--                    (Products.canBuy). Nothing counts down, nothing is "limited". None in a new player's first minutes.
-- The daily window itself opens by itself once per visit from the second one (HoodHUD.OpenDaily), never on a first join.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local GuiService = game:GetService('GuiService')
local MarketplaceService = game:GetService('MarketplaceService')

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
-- (brief 30) Copied from the reference's Before You Go! (ref_ref29_before_you_go.jpg, measured on its 1772 x 1604 crop and
-- scaled 0.48 so the whole card fits under the top bar): no frame at all, the world dimmed to half; the title in red with a
-- dark red edge (cap 46 px), a white line under it, two columns (a gold heading, a big picture, a white value), and the
-- big lime studded OK! button 225 x 88. Motion like the user's phone references: the dim fades in, the title drops in
-- from 0.6 (Back Out), the columns pop one after the other, the pictures bob, the button pops last and a light band
-- sweeps it. While a card is up PlayerGui HoodCard names it, so notices keep clear of it (Shared/HudToasts).
local CARD_W, CARD_H = 640, 640
local card -- the card on screen (nil when none): { Dim, Kind }
local function closeCard()
	local c = card
	card = nil
	if c and c.Dim.Parent then
		Motion.tween(c.Dim, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		Motion.tween(Motion.scaleOf(c.Holder), 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Scale = 0.85 })
		task.delay(0.16, function() c.Dim:Destroy() end)
	end
	if playerGui:GetAttribute('HoodCard') == (c and c.Kind) then playerGui:SetAttribute('HoodCard', '') end
end
local function popIn(g, from, delay, time)
	local s = Motion.scaleOf(g)
	s.Scale = from
	task.delay(delay, function() Motion.tween(s, time or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
end
-- The dimmed world and the card: title and subtitle. Input passes through the dim (Active false): nothing is blocked; only
-- the buttons take clicks.
local function makeCard(kind, title, titleTop, titleBottom, titleEdge, subtitle)
	closeCard()
	local dim = Kit.new('Frame', { Name = kind .. 'Dim', BackgroundColor3 = Color.ink, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = root })
	Motion.tween(dim, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0.42 })
	local holder = Kit.new('Frame', { Name = kind, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(CARD_W, CARD_H), ZIndex = 41, Parent = dim })
	holder:SetAttribute('DesignW', CARD_W)
	holder:SetAttribute('DesignH', CARD_H)
	local fitScale = Kit.new('UIScale', { Name = 'FitScale', Parent = holder })
	local t = gradient(label({ Name = 'Title', Text = title, TextSize = 66, Stroke = titleEdge, StrokeThickness = 6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = px(CARD_W + 80, 80), ZIndex = 42, Parent = holder }), titleTop, titleBottom)
	local sub = label({ Name = 'Subtitle', Text = subtitle, TextSize = 32, StrokeThickness = 4.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 92), Size = px(CARD_W + 80, 40), ZIndex = 42, Parent = holder })
	popIn(t, 0.6, 0, 0.32)
	popIn(sub, 0.7, 0.06, 0.28)
	card = { Dim = dim, Kind = kind, Holder = holder, FitScale = fitScale }
	playerGui:SetAttribute('HoodCard', kind)
	-- (small screens: the card shrinks to fit, never grows)
	local abs = gui.AbsoluteSize
	local k = Kit.scaleFor(abs)
	if abs.Y > 0 then fitScale.Scale = math.min(1, (abs.Y / k - 16) / CARD_H, (abs.X / k - 24) / CARD_W) end
	return holder
end
-- One column: a gold heading, a big picture, a white value (and an optional small line). i: its place in the stagger.
local function column(holder, cx, i, header, headerTop, headerBottom, iconId, value, small, valueSize)
	local col = Kit.new('Frame', { Name = 'Column' .. i, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, 200), Size = px(300, 300), ZIndex = 42, Parent = holder })
	gradient(label({ Name = 'Header', Text = header, TextSize = 34, StrokeThickness = 4.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = px(320, 42), ZIndex = 42, Parent = col }), headerTop, headerBottom)
	local icon = Kit.icon3d(iconId, 128, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), ZIndex = 42 })
	icon.Parent = col
	Motion.bob(icon, 5, 1.6 + i * 0.2)
	label({ Name = 'Value', Text = value, TextSize = valueSize or 30, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 202), Size = px(330, 44), ZIndex = 42, Parent = col })
	if small and small ~= '' then label({ Name = 'Small', Text = small, TextSize = 20, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 236), Size = px(330, 26), ZIndex = 42, Parent = col }) end
	popIn(col, 0.5, 0.12 + i * 0.08, 0.3)
	return col
end
local function bigButton(holder, text, tone, cx, w, onClick, i)
	local b = Kit.blockButton({ Name = text, Tone = tone, Width = w, Height = 88, Text = text, TextSize = 54, Outline = 6, RimWidth = 3, Studs = 22, Radius = 10, ZIndex = 44 })
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = px(cx, 520)
	b.Parent = holder
	local l = b:FindFirstChild('Label', true)
	if l then
		local st = l:FindFirstChildOfClass('UIStroke')
		if st then st.Thickness = 6 end
	end
	Motion.button(b, onClick)
	popIn(b, 0.4, 0.3 + (i or 0) * 0.06, 0.32)
	task.delay(0.7, function() if b.Parent then Motion.shine(b.Body, 3, UDim.new(0, 8)) end end)
	return b
end
-- a window opening (the HUD's, the Store, the inventory) closes the card: one thing on screen at a time
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local w = playerGui:GetAttribute('HoodWindow')
	if type(w) == 'string' and w ~= '' and card then closeCard() end
end)
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
	local holder = makeCard('BeforeYouGo', 'Before You Go!', hex('FF5A4A'), hex('F02C2C'), hex('5A0808'), 'You earn Power while offline!')
	local ready = st.Daily and st.Daily.Ready
	column(holder, 170, 1, 'IN ' .. st.Offline.CapHours .. ' HOURS', hex('FFF24A'), hex('FFC21A'), POWER, '+' .. Format.compact(st.Offline.EightHours) .. ' Power', 'Come back to claim it')
	column(holder, 470, 2, ready and 'TODAY' or 'TOMORROW', hex('FFF24A'), hex('FFC21A'), ready and 'Rewards' or 'PotionGold', 'Daily reward', tomorrowText(st), 36)
	local dim = card.Dim
	bigButton(holder, 'OK!', 'lime', CARD_W / 2, 225, closeCard)
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
	local holder = makeCard('WelcomeBack', 'Welcome back!', hex('C8FF5A'), hex('46D020'), hex('0E3A06'), 'You earned Power while you were away!')
	column(holder, 170, 1, 'WHILE AWAY', hex('FFF24A'), hex('FFC21A'), POWER, '+' .. Format.compact(pending) .. ' Power', 'Up to ' .. st.Offline.CapHours .. ' hours count')
	local entry = Products.ByKey.OfflineX2
	column(holder, 470, 2, '2x OFFLINE', hex('FFF24A'), hex('FFC21A'), 'PotionGold', '+' .. Format.compact(pending * 2) .. ' Power', 'Pay once, get it doubled')
	local dim = card.Dim
	local say = label({ Name = 'Say', Text = '', TextSize = 22, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = px(CARD_W / 2, 614), Size = px(CARD_W, 26), ZIndex = 44, Parent = holder })
	bigButton(holder, 'Claim', 'lime', 170, 225, function()
		local res = ask('ClaimOffline')
		if res and res.State then state, stateAt = res.State, os.clock() end
		if card and card.Dim == dim then closeCard() end
		afterWelcome()
	end)
	if entry then
		-- the offer, with its real price on the button
		local b = Kit.robuxButton({ Name = 'X2', Tone = 'gold', Width = 225, Height = 88, Price = entry.Price, TextSize = 46, Outline = 6, Radius = 10, ZIndex = 44 })
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = px(470, 520)
		b.Parent = holder
		popIn(b, 0.4, 0.36, 0.32)
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
