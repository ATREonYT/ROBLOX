-- Three of the soldier game's HUD extras (brief 30, HUD; the user's choice): Playtime Rewards, Missions and the Starter
-- Pack. The server decides everything (HoodServer/HudExtrasService through the HudExtras remote; the rules are
-- Shared/HudExtrasRules); this shows it:
--   * Playtime Rewards (HoodHUD's PlaytimeSlot, ref_W31.0: the purple gift with a red "!" over "Playtime / Rewards" in
--     gold, centred 241 px in from the right edge): six gifts that open with your playtime this visit; the window shows
--     each one's real time left, "Claim!" on the open ones, a tick on the taken ones, and the way to the Daily Rewards
--   * Missions (MissionsSlot, ref_W03.0: the scroll, "Missions" and "0/3" in gold under the Playtime gift): three small
--     tasks with their progress bars and rewards; a finished one waits for its Claim and a new one takes its place
--   * Starter Pack (StarterSlot, ref_W31.0: "Starter Pack" in white over the crate, 94 px in from the right edge): a
--     one-time bundle for new players; its price rolls up when it first shows and its parts cross-fade under it (the
--     reference's "3 -> 395 -> 399" and "RPG / +60K/Power"); gone once it is bought. The window lists the parts exactly as
--     granted and the Buy button opens Roblox's own prompt (it says "coming soon" only while its id is 0).
-- Motion like the user's phone references: every button squashes and grows (UIMotion.button), badges pop when they light
-- and the ready ones wobble, windows pop and stagger in (HudWindows), cards and rows pop one after another, a light band
-- sweeps the Buy button. Nothing flashes, nothing opens by itself.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local RobuxText = require(Shared.RobuxText) -- (ROBUX) the Robux sign before every Robux price
local Sell = { Style = require(Shared.TextStyle), FX = require(Shared.SellFX) } -- (ROBUX, rules 27-28)
local Format = require(Shared.Format)
local Spec = require(Shared.HudSpec)
local Windows = require(Shared.HudWindows)
local Toasts = require(Shared.HudToasts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px, hex, Color = UDim2.fromOffset, Kit.hex, Kit.Color
local BLACK = Color.black
local GOLD = { hex('FFF27A'), hex('FFA81A') }
local LIME = { hex('C8FF4A'), hex('5CE01E') }

local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.14)
	return Kit.text(props)
end
local function gradient(t, c)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(c[1], c[2]), Parent = t })
	return t
end
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
local function ask(action, arg)
	local ok, res = pcall(function() return Net.get('HudExtras'):InvokeServer(action, arg) end)
	return ok and type(res) == 'table' and res or nil
end
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format('%d:%02d', seconds // 60, seconds % 60)
end
-- a red "!" badge (the reference's: a red rounded square, a black edge, a white "!")
local function bang(parent, pos)
	local b = Kit.new('Frame', { Name = 'Badge', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = px(26, 30), ZIndex = 8, Visible = false, Parent = parent })
	Kit.corner(6).Parent = b
	Kit.stroke(BLACK, 2.5, true).Parent = b
	Kit.gradient(hex('FF5A5A'), hex('D80E1E'), 0.5).Parent = b
	label({ Name = 'Mark', Text = '!', TextSize = 22, StrokeThickness = 2.5, ZIndex = 9, Parent = b })
	return b
end
-- a HUD extra's button in its slot: a holder with Hit and Body (UIMotion.button), the picture in the Body
local function hudButton(slot, onClick)
	local holder = Kit.new('Frame', { Name = 'Button', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = slot })
	Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = holder })
	local body = Kit.new('Frame', { Name = 'Body', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = holder })
	holder:SetAttribute('Lip', 2)
	Motion.button(holder, onClick)
	return holder, body
end
local state, stateAt = nil, 0
local painters = {}
local function refresh()
	local res = ask('State')
	if res and res.State then
		state, stateAt = res.State, os.clock()
		for _, p in painters do pcall(p) end
	end
	return res
end
local function claimed(res)
	if res and res.State then
		state, stateAt = res.State, os.clock()
		for _, p in painters do pcall(p) end
	end
end

local hud = playerGui:WaitForChild('HoodHUD', 60)
local hudRoot = hud and hud:WaitForChild('Root', 10)
local function slotOf(name) return hudRoot and hudRoot:WaitForChild(name, 10) end

---------------------------------------------------------------------------------------------- PLAYTIME REWARDS
local playtime
do
	local P = Spec.Playtime
	playtime = Windows.make('Playtime', { Title = 'Playtime Rewards', Icon = Kit.iconOr('PlaytimeGift', 'Rewards'), Tone = 'headerMagenta', Width = 900, Height = 610, Gloss = false })
	local slot = slotOf('PlaytimeSlot')
	if slot then
		local _, body = hudButton(slot, function() Windows.toggle(playtime) end)
		local gift = Kit.icon3d(Kit.iconOr('PlaytimeGift', 'Rewards'), P.Icon + 4, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -2), ZIndex = 3 })
		gift.Parent = body
		local cap = gradient(label({ Name = 'Caption', Text = 'Playtime\nRewards', TextSize = P.Caption, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 67), Size = px(130, 44), ZIndex = 4, Parent = body }), GOLD)
		cap.LineHeight = 0.9
		local badge = bang(body, UDim2.new(0.5, 34, 0, 12))
		local wobble
		local function paint()
			local ready = num('PlaytimeReady', 0) > 0 or player:GetAttribute('DailyReady') == true
			if ready and not badge.Visible then Motion.pop(badge, 0.4) end
			badge.Visible = ready
			if ready and not wobble then
				wobble = Motion.wobble(gift, 6, 1.6)
			elseif not ready and wobble then
				wobble:Cancel()
				wobble = nil
				gift.Rotation = 0
			end
		end
		for _, name in { 'PlaytimeReady', 'DailyReady' } do player:GetAttributeChangedSignal(name):Connect(paint) end
		paint()
	end
	-- the window: six reward tiles in two rows, then the line and Daily Rewards
	local well = playtime.Well
	local CW, CH, GAP = 268, 196, 14
	local cards = Kit.new('Frame', { Name = 'Gifts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = px(3 * CW + 2 * GAP, 2 * CH + GAP), ZIndex = 24, Parent = well })
	cards:SetAttribute('NoStagger', true)
	-- (Oct 27, the owner's UI mockup) solid coloured reward tiles, by how long they take: blue, purple, red, gold
	local CARD_TONES = { 'cardBlue', 'cardBlue', 'cardPurple', 'cardPurple', 'cardRed', 'cardGold' }
	local note = label({ Name = 'Note', Text = 'Gifts open as you play. They start again on your next visit.', FontFace = Kit.Font.body, TextSize = 19, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(16, 2 * CH + GAP + 22), Size = px(560, 44), ZIndex = 26, Parent = well })
	note.TextWrapped = true
	local daily = Kit.blockButton({ Name = 'DailyButton', Tone = 'cardBlue', Width = 230, Height = 60, Text = 'Daily Rewards', TextSize = 26, Outline = 4, RimWidth = 2, Radius = 6, Studs = 18, Position = px(3 * CW + 2 * GAP - 236 + 20, 2 * CH + GAP + 16), ZIndex = 26 })
	daily.Parent = well
	local dailyBadge = bang(daily, UDim2.new(1, -4, 0, 4))
	Motion.button(daily, function()
		local ev = hud and hud:FindFirstChild('OpenDaily')
		if ev then ev:Fire() end
	end)
	local function tick(parent, size, z)
		local holder = Kit.new('Frame', { Name = 'Check', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = px(size, size), ZIndex = z, Parent = parent })
		for _, b in { { 0.2, 0.46, 0.3, 0.6, 45 }, { 0.2, 0.78, 0.6, 0.48, -45 } } do
			local f = Kit.new('Frame', { BackgroundColor3 = hex('46E052'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[3], b[4]), Size = px(size * b[1], size * b[2]), Rotation = b[5], ZIndex = z, Parent = holder })
			Kit.new('UIStroke', { Color = hex('0E3A14'), Thickness = 4, LineJoinMode = Enum.LineJoinMode.Miter, Parent = f })
		end
		return holder
	end
	local built = {}
	local function paint(opening)
		dailyBadge.Visible = player:GetAttribute('DailyReady') == true
		local pt = state and state.Playtime
		if not pt then return end
		local played = pt.Seconds + (os.clock() - stateAt)
		for i, g in pt.Gifts do
			local key = (g.Taken and 'T' or g.Ready and 'R' or 'L') .. i
			local card = built[i]
			local left = math.max(0, g.Left - (os.clock() - stateAt))
			local open = g.Ready or (not g.Taken and left <= 0)
			if card and card:GetAttribute('Key') == key and not opening then
				local t = card:FindFirstChild('Left', true)
				if t then t.Text = clock(left) end
				continue
			end
			if card then card:Destroy() end
			local col, row = (i - 1) % 3, (i - 1) // 3
			card = Kit.block({ Name = 'Gift' .. i, Tone = CARD_TONES[i] or 'cardBlue', Width = CW, Height = CH, Position = px(col * (CW + GAP), row * (CH + GAP)), Outline = 5, OutlineColor = Kit.Skin.outline, Radius = 12, RimWidth = 3, Studs = false, ZIndex = 25 })
			card:SetAttribute('Key', key)
			card.Parent = cards
			built[i] = card
			label({ Name = 'Time', Text = g.Minutes .. ' min', TextSize = 30, StrokeThickness = 4, Position = px(0, 4), Size = UDim2.new(1, 0, 0, 34), ZIndex = 28, Parent = card.Body })
			local pic = Kit.icon3d(g.Icon, 76, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 80), ZIndex = 28 })
			pic.Parent = card.Body
			local what = label({ Name = 'What', Text = table.concat(g.Lines, ' + '), TextSize = 18, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 134), Size = UDim2.new(1, -12, 0, 40), ZIndex = 28, Parent = card.Body })
			what.TextWrapped = true
			if g.Taken then
				tick(card.Body, 80, 30).Position = UDim2.new(0.5, 0, 0, 80)
			elseif open then
				gradient(label({ Name = 'Claim', Text = 'Claim!', TextSize = 42, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.new(1, 0, 0, 52), ZIndex = 31, Parent = card.Body }), LIME)
				local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 33, Parent = card })
				card:SetAttribute('Lip', 3)
				Motion.button(card, function() claimed(ask('ClaimGift', i)) end)
				local _ = hit
			else
				-- the real time left, in a dark pill over the picture
				local pill = Kit.new('Frame', { Name = 'LeftPill', BackgroundColor3 = hex('0B1230'), BackgroundTransparency = 0.15, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -24), Size = px(110, 32), ZIndex = 30, Parent = card.Body })
				Kit.corner(UDim.new(0.5, 0)).Parent = pill
				Kit.stroke(BLACK, 2.5, true).Parent = pill
				label({ Name = 'Left', Text = clock(left), TextSize = 22, StrokeThickness = 3, ZIndex = 31, Parent = pill })
				what.Position = UDim2.new(0.5, 0, 0, 126)
			end
			if opening then
				local s = Motion.scaleOf(card)
				s.Scale = 0.5
				task.delay(0.04 * i, function() Motion.tween(s, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
			end
		end
		local _ = played
	end
	table.insert(painters, function() if Windows.current() == playtime then paint(false) end end)
	playtime.Open = function()
		paint(true)
		task.spawn(function()
			refresh()
			if Windows.current() == playtime then paint(false) end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.current() == playtime then paint(false) end
		end
	end)
end

---------------------------------------------------------------------------------------------- MISSIONS
local missions
do
	local M = Spec.Missions
	missions = Windows.make('Missions', { Title = 'Missions', Icon = Kit.iconOr('Missions', 'Quest'), Tone = 'headerBrown', Width = 900, Height = 584, Gloss = false })
	local slot = slotOf('MissionsSlot')
	if slot then
		local _, body = hudButton(slot, function() Windows.toggle(missions) end)
		local scroll = Kit.icon3d(Kit.iconOr('Missions', 'Quest'), M.Icon + 6, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 3 })
		scroll.Parent = body
		gradient(label({ Name = 'Caption', Text = 'Missions', TextSize = M.Caption, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = px(130, 26), ZIndex = 4, Parent = body }), GOLD)
		local count = gradient(label({ Name = 'Count', Text = '0/3', TextSize = M.Caption, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 84), Size = px(80, 26), ZIndex = 4, Parent = body }), GOLD)
		local badge = bang(body, UDim2.new(0.5, 30, 0, 8))
		local bob
		local function paint()
			local n = num('MissionsReady', 0)
			count.Text = n .. '/3'
			if n > 0 and not badge.Visible then
				Motion.pop(badge, 0.4)
				Motion.pop(count, 0.3)
			end
			badge.Visible = n > 0
			if n > 0 and not bob then
				bob = Motion.wobble(scroll, 6, 1.4)
			elseif n <= 0 and bob then
				bob:Cancel()
				bob = nil
				scroll.Rotation = 0
			end
		end
		player:GetAttributeChangedSignal('MissionsReady'):Connect(paint)
		paint()
	end
	local well = missions.Well
	local list = Kit.new('Frame', { Name = 'List', BackgroundTransparency = 1, Size = px(864, 400), ZIndex = 24, Parent = well })
	list:SetAttribute('NoStagger', true)
	local footer = gradient(label({ Name = 'Done', Text = '', TextSize = 22, StrokeThickness = 3, Position = px(0, 400), Size = px(864, 28), ZIndex = 26, Parent = well }), GOLD)
	local ICON = { Goons = 'Skull', Shots = 'Gun', Boxes = 'ShoeBox', Clears = 'Trophy', CashOuts = 'Cash', Spins = 'SpinWheel' }
	local ROW_TONE = Kit.Tone.navyRow -- (Oct 27, the owner's UI mockup: dark rows)
	local function paint(opening)
		for _, c in list:GetChildren() do c:Destroy() end
		local m = state and state.Missions
		if not m then
			label({ Name = 'Loading', Text = 'Loading...', TextSize = 28, Size = px(864, 80), ZIndex = 26, Parent = list })
			return
		end
		footer.Text = 'Missions done: ' .. Format.compact(m.Done) .. '   New ones come as you finish them!'
		for i, t in m.List do
			local done = t.Have >= t.Goal
			local row = Kit.block({ Name = 'Mission' .. i, Tone = ROW_TONE, Width = 864, Height = 120, Outline = 4, OutlineColor = done and hex('7CE82A') or Kit.Skin.outline, RimWidth = 2, Radius = 10, Studs = false, Position = px(0, (i - 1) * 132), ZIndex = 25 })
			row.Parent = list
			Kit.icon3d(Kit.iconOr(ICON[t.Kind] or 'Quest', 'Quest'), 84, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 28 }).Parent = row.Body
			label({ Name = 'Text', Text = t.Text, TextSize = 28, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(108, 12), Size = px(480, 34), ZIndex = 28, Parent = row.Body })
			-- the progress bar: lime on a dark track, "6 / 10"
			local bar, fill = Kit.bar({ Name = 'Progress', Width = 410, Height = 36, Tone = 'buyGreen', TrackColor = Kit.Skin.well, TrackTransparency = 0, Radius = 8, Value = 0, Text = Format.compact(t.Have) .. ' / ' .. Format.compact(t.Goal), TextSize = 20, Track = 'dark', Position = px(108, 58), ZIndex = 27 })
			bar.Parent = row.Body
			local frac = math.clamp(t.Have / math.max(1, t.Goal), 0, 1)
			if opening then
				Motion.tween(fill, 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = UDim2.fromScale(frac, 1) })
			else
				fill.Size = UDim2.fromScale(frac, 1)
			end
			-- the reward, and Claim when it is done
			Kit.icon3d(t.Icon, 50, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 600, 0, 40), ZIndex = 28 }).Parent = row.Body
			gradient(label({ Name = 'Reward', Text = table.concat(t.Lines, ' + '), TextSize = 22, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 600, 0, 84), Size = px(160, 26), ZIndex = 28, Parent = row.Body }), LIME)
			if done then
				local b = Kit.blockButton({ Name = 'Claim', Tone = 'lime', Width = 150, Height = 64, Text = 'Claim!', TextSize = 30, Outline = 4, RimWidth = 2, Radius = 6, Studs = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 28 })
				b.Parent = row.Body
				Motion.button(b, function() claimed(ask('ClaimMission', i)) end)
				Motion.shine(b.Body, 2.5, UDim.new(0, 6))
			end
			if opening then
				local s = Motion.scaleOf(row)
				s.Scale = 0.6
				task.delay(0.05 * i, function() Motion.tween(s, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
			end
		end
	end
	table.insert(painters, function() if Windows.current() == missions then paint(false) end end)
	missions.Open = function()
		paint(true)
		task.spawn(function()
			refresh()
			if Windows.current() == missions then paint(false) end
		end)
	end
end

---------------------------------------------------------------------------------------------- STARTER PACK
local starter
do
	local St = Spec.Starter
	local entry = Products.ByKey.StarterPack
	starter = Windows.make('Starter', { Title = 'Starter Pack', Icon = Kit.iconOr('StarterCrate', 'Rewards'), Tone = 'headerGold', Width = 820, Height = 560 })
	local function buy()
		local ok, why = Products.canBuy('StarterPack')
		if not ok then
			if why == 'noid' or why == 'off' then Toasts.say('The Starter Pack is coming soon!', 'blue') end
			return
		end
		if player:GetAttribute('StarterOwned') == true then return end
		pcall(function() MarketplaceService:PromptProductPurchase(player, Products.idOf('StarterPack')) end)
	end
	local slot = slotOf('StarterSlot')
	if slot and entry then
		local holder, body = hudButton(slot, function() Windows.toggle(starter) end)
		local caption = label({ Name = 'Caption', Text = 'Starter Pack', TextSize = St.Caption, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = px(150, 24), ZIndex = 4, Parent = body })
		local crate = Kit.icon3d(Kit.iconOr('StarterCrate', 'Rewards'), St.Icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), ZIndex = 3 })
		crate.Parent = body
		-- (ROBUX, rules 27-28) the reference's Starter Pack: the white outlined caption, the crate bobbing, stars round it
		Sell.Style.apply(caption, 'white', { Thickness = 3.5, Shadow = true })
		Motion.bob(crate, 4, 2.4)
		Sell.FX.sparkles(body, { Count = 2, Size = 16, ZIndex = 5, Every = 3, Inset = 0.15 })
		local function paint()
			holder.Visible = player:GetAttribute('StarterOwned') ~= true
		end
		player:GetAttributeChangedSignal('StarterOwned'):Connect(paint)
		paint()
		task.spawn(function()
			while player:GetAttribute('StarterOwned') ~= true and slot.Parent do
				task.wait(6 + math.random() * 2)
				if player:GetAttribute('OnboardingQuiet') ~= true then Motion.pop(crate, 0.08) end
			end
		end)
	end
	-- the window: the crate on its rays, the three parts as dark cards, the price button
	local well = starter.Well
	Kit.sunburst(260, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(140, 150), ZIndex = 24, Rays = 16, Alpha = 0.16 }).Parent = well
	local hero = Kit.icon3d(Kit.iconOr('StarterCrate', 'Rewards'), 220, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(140, 150), ZIndex = 25 })
	hero.Parent = well
	Motion.bob(hero, 6, 1.8)
	gradient(label({ Name = 'Head', Text = 'A great start!', TextSize = 40, StrokeThickness = 5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(290, 6), Size = px(480, 46), ZIndex = 26, Parent = well }), GOLD)
	label({ Name = 'Sub', Text = 'All three in one purchase, once per player.', FontFace = Kit.Font.body, TextSize = 19, StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(290, 52), Size = px(480, 26), ZIndex = 26, Parent = well })
	local partsFrame = Kit.new('Frame', { Name = 'Parts', BackgroundTransparency = 1, Position = px(290, 92), Size = px(480, 196), ZIndex = 25, Parent = well })
	partsFrame:SetAttribute('NoStagger', true)
	local CARDS = { 'cardGreen', 'cardRed', 'cardPurple' } -- (Oct 27, the owner's UI mockup: solid coloured tiles; Cash green, the potion red, the box purple)
	local buyButton = Kit.robuxButton({ Name = 'Buy', Tone = 'lime', Width = 300, Height = 86, Price = entry and entry.Price or '?', TextSize = 44, Outline = 5, Radius = 8, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 312), ZIndex = 26 })
	buyButton.Parent = well
	Motion.button(buyButton, buy)
	Motion.shine(buyButton.Body, 3, UDim.new(0, 8))
	local buyPrice = buyButton:FindFirstChild('Label', true)
	local ownedLine = gradient(label({ Name = 'Owned', Text = 'OWNED', TextSize = 44, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 324), Size = px(300, 60), ZIndex = 27, Visible = false, Parent = well }), LIME)
	local function paint(opening)
		for _, c in partsFrame:GetChildren() do c:Destroy() end
		local s = state and state.Starter
		local lines = s and s.Lines or {}
		local icons = { 'CashMedium', 'PotionRed', s and s.Box and ('Box_' .. s.Box) or 'ShoeBox' }
		for i = 1, 3 do
			local c = Kit.block({ Name = 'Part' .. i, Tone = CARDS[i], Width = 150, Height = 196, Outline = 4, OutlineColor = Kit.Skin.outline, Radius = 12, RimWidth = 3, Studs = false, Position = px((i - 1) * 164, 0), ZIndex = 25 })
			c.Parent = partsFrame
			Kit.icon3d(Kit.iconOr(icons[i], 'Rewards'), 96, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 72), ZIndex = 28 }).Parent = c.Body
			local t = label({ Name = 'What', Text = lines[i] or '', TextSize = 20, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -10, 0, 50), ZIndex = 28, Parent = c.Body })
			t.TextWrapped = true
			if opening then
				local sc = Motion.scaleOf(c)
				sc.Scale = 0.5
				task.delay(0.06 * i, function() Motion.tween(sc, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end)
			end
		end
		local owned = player:GetAttribute('StarterOwned') == true
		buyButton.Visible = not owned
		ownedLine.Visible = owned
		-- (the reference's rolling price: it counts up to the real price as the window opens)
		if opening and buyPrice and entry then
			buyPrice.Text = '0'
			Motion.countTo(buyPrice, 0, entry.Price, 0.8, function(v) return RobuxText.commas(v) end)
			-- (and it always ends on the real price, even if the roll is cut short)
			task.delay(0.8, function() if buyPrice.Parent then buyPrice.Text = RobuxText.commas(entry.Price) end end)
		end
	end
	table.insert(painters, function() if Windows.current() == starter then paint(false) end end)
	starter.Open = function()
		paint(true)
		task.spawn(function()
			refresh()
			if Windows.current() == starter then paint(false) end
		end)
	end
	player:GetAttributeChangedSignal('StarterOwned'):Connect(function()
		if Windows.current() == starter then paint(false) end
	end)
end
