-- The Daily Rewards window (brief 29, P5: the reference's window), moved out of HUD.client unchanged in brief 30 so the HUD
-- stays under Roblox's local limit. Its look is kept as it is: the user's own UI mockup will restyle it (brief 30 scope).
-- Seven navy cards with a rarity-coloured border (blue, purple, red), "Day N" over the reward and what it is under it; a
-- claimed day wears a big green tick, today's says "Claim!", Day 7 is the tall card; "Reward ready to claim!" under them.
-- Everything comes from the server (RetentionService 'State'; the numbers are Shared/RetentionRules and are the ones granted).
-- After a missed day: "Restore streak" (a small Robux product, its real price on the button) or start again at Day 1.
--   require(DailyWindow)(Windows, { buy, label, fillText }) -> the HudWindows window
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')
local Kit = require(RS.Shared.UIKit)
local Motion = require(RS.Shared.UIMotion)
local Net = require(RS.Shared.Net)
local Products = require(RS.Shared.Config.Products)

return function(Windows, helpers)
	local buy, label, fillText = helpers.buy, helpers.label, helpers.fillText
	local Color, hex, px = Kit.Color, Kit.hex, UDim2.fromOffset
	local BLACK = Color.black
	local POWER = Kit.iconOr('Muscle', 'Power')
	local function body(parent, text, props)
		props = props or {}
		return Kit.text({
			Name = props.Name or 'Body', Text = text, FontFace = props.FontFace or Kit.Font.body, TextSize = props.TextSize or 18, TextColor3 = props.Color or Color.white,
			Stroke = props.Stroke or BLACK, StrokeThickness = props.StrokeThickness or 2, TextXAlignment = props.Align or Enum.TextXAlignment.Center,
			TextYAlignment = props.YAlign or Enum.TextYAlignment.Center, TextWrapped = true, Position = props.Position, Size = props.Size,
			AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 25, Parent = parent,
		})
	end
	local rewards = Windows.make('Rewards', { Title = 'Daily Rewards', Icon = 'Rewards', Tone = 'headerCyan', Width = 940, Height = 690, TitleSize = 64, Gloss = false })
	local CARD_W, CARD_H, CARD_GAP, BIG_W = 184, 170, 12, 230
	local DAYS_W, DAYS_H = 3 * CARD_W + 3 * CARD_GAP + BIG_W, 2 * CARD_H + CARD_GAP
	local days = Kit.new('Frame', { Name = 'Days', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = px(DAYS_W, DAYS_H), ZIndex = 24, Parent = rewards.Well })
	local RARITY = { blue = hex('3FA9FF'), purple = hex('A455FF'), red = hex('FF4A3A') }
	local CARD_TONE = { top = hex('243C7C'), base = hex('1A2A5E'), lip = hex('2C4690'), stroke = hex('0B1230') }
	local readyLine = fillText(label({ Name = 'Ready', Text = '', TextSize = 40, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, DAYS_H + 12), Size = px(820, 48), ZIndex = 26, Parent = rewards.Well }), { hex('B8FF5A'), hex('4FD81A') })
	local noteLine = body(rewards.Well, '', { Name = 'Note', TextSize = 19, Position = px(18, DAYS_H + 64), Size = UDim2.new(1, -300, 0, 50), Align = Enum.TextXAlignment.Left, ZIndex = 26 })
	local restoreSlot = Kit.new('Frame', { Name = 'RestoreSlot', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, DAYS_H + 62), Size = px(250, 54), ZIndex = 26, Parent = rewards.Well })
	local groupSlot = Kit.new('Frame', { Name = 'GroupSlot', BackgroundTransparency = 1, Position = px(14, DAYS_H + 130), Size = UDim2.new(1, -28, 0, 60), ZIndex = 26, Parent = rewards.Well })
	local dailyState, dailyBusy, dailyAt = nil, false, 0
	local function askRetention(action)
		local ok, res = pcall(function() return Net.get('Retention'):InvokeServer(action) end)
		return ok and type(res) == 'table' and res or nil
	end
	local function checkMark(parent, size, z)
		local holder = Kit.new('Frame', { Name = 'Check', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = px(size, size), ZIndex = z, Parent = parent })
		local function bar(w, h, x, y, rot)
			local f = Kit.new('Frame', { BackgroundColor3 = hex('46E052'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, y, 0), Size = px(w, h), Rotation = rot, ZIndex = z, Parent = holder })
			Kit.new('UIStroke', { Color = hex('0E3A14'), Thickness = 4, LineJoinMode = Enum.LineJoinMode.Miter, Parent = f })
		end
		bar(size * 0.2, size * 0.46, 0.3, 0.6, 45)
		bar(size * 0.2, size * 0.78, 0.6, 0.48, -45)
		return holder
	end
	local function iconOfCard(card)
		if card.Big then return 'Rewards', 132 end
		local line = card.Lines[1] or ''
		if line:find('Cash') then return Kit.iconOr('Cash'), 84 end
		if line:find('^%d+x Power') then return line:find('^3') and 'PotionGold' or 'PotionRed', 88 end
		return POWER, 84
	end
	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds))
		return string.format('%dh %02dm', seconds // 3600, (seconds % 3600) // 60)
	end
	local claimDaily, claimGroup
	local function paintDaily()
		for _, c in days:GetChildren() do c:Destroy() end
		local st = dailyState and dailyState.Daily
		if not st then
			readyLine.Text = 'Loading...'
			return
		end
		for day = 1, 7 do
			local card = st.Cards[day]
			local big = card.Big
			local claimed, ready
			if st.Ready then
				claimed, ready = day < st.Day, day == st.Day
			else
				claimed, ready = day <= st.Claimed, false
			end
			local col, row = (day - 1) % 3, day <= 3 and 0 or 1
			local tile = Kit.block({ Name = 'Day' .. day, Tone = CARD_TONE, Width = big and BIG_W or CARD_W, Height = big and DAYS_H or CARD_H, Position = big and px(3 * (CARD_W + CARD_GAP), 0) or px(col * (CARD_W + CARD_GAP), row * (CARD_H + CARD_GAP)), Outline = 5, OutlineColor = RARITY[card.Rarity] or RARITY.blue, Studs = false, Rim = false, Flat = false, ZIndex = 25 })
			tile.Parent = days
			label({ Name = 'Day', Text = 'Day ' .. day, TextSize = big and 38 or 30, StrokeThickness = 4, Position = px(0, 8), Size = UDim2.new(1, 0, 0, 36), ZIndex = 28, Parent = tile.Body })
			local id, size = iconOfCard(card)
			Kit.icon3d(id, size, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, big and 150 or 84), ZIndex = 28 }).Parent = tile.Body
			label({ Name = 'What', Text = table.concat(card.Lines, '\n'), TextSize = big and 21 or 17, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -10, 0, big and 84 or 40), ZIndex = 28, TextWrapped = true, Parent = tile.Body })
			if claimed then
				checkMark(tile.Body, big and 120 or 92, 30).Position = UDim2.new(0.5, 0, 0, big and 150 or 84)
			elseif ready then
				fillText(label({ Name = 'Claim', Text = 'Claim!', TextSize = big and 48 or 40, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, big and 150 or 84), Size = UDim2.new(1, 0, 0, 52), ZIndex = 31, Parent = tile.Body }), { hex('B8FF5A'), hex('4FD81A') })
				local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 33, Parent = tile.Body })
				hit.Activated:Connect(function() claimDaily() end)
			end
		end
		if st.Ready then
			readyLine.Text = 'Reward ready to claim!'
		else
			readyLine.Text = 'Next reward in ' .. clock((st.Wait or 0) - (os.clock() - dailyAt))
		end
		for _, c in restoreSlot:GetChildren() do c:Destroy() end
		if st.Ready and st.Missed and st.CanRestore then
			local entry = Products.ByKey.RestoreStreak
			noteLine.Text = 'You missed a day. Restore your streak to carry on from Day ' .. st.RestoreDay .. ', or just claim Day 1 and start again.'
			local holder = Kit.robuxButton({ Name = 'Restore', Tone = 'lime', Width = 250, Height = 54, Price = entry.Price, TextSize = 26, ZIndex = 27 })
			holder.Parent = restoreSlot
			label({ Name = 'Cap', Text = 'Restore streak', TextSize = 17, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = px(250, 20), ZIndex = 28, Parent = restoreSlot })
			Motion.button(holder, function() buy('RestoreStreak') end)
		elseif st.Ready and st.Missed then
			noteLine.Text = 'You missed a few days, so the streak starts again at Day 1. Claim it now!'
		elseif st.Ready then
			noteLine.Text = 'Come back every day: Day 7 is the big one.'
		else
			noteLine.Text = 'Claimed today. Come back tomorrow for the next day.'
		end
		for _, c in groupSlot:GetChildren() do c:Destroy() end
		local g = dailyState.Group
		if g and g.On then
			local line = g.Claimed and 'Group reward taken. Thanks for being in the group!' or ('Group reward: join our Roblox group, then press Claim. You get ' .. table.concat(g.Lines, ' + ') .. '.')
			body(groupSlot, line, { Name = 'GroupText', TextSize = 18, Position = px(0, 0), Size = UDim2.new(1, -200, 1, 0), Align = Enum.TextXAlignment.Left, ZIndex = 26 })
			if not g.Claimed then
				local b = Kit.blockButton({ Name = 'GroupClaim', Tone = 'lime', Width = 170, Height = 52, Text = 'Claim', TextSize = 28, ZIndex = 27 })
				b.AnchorPoint = Vector2.new(1, 0.5)
				b.Position = UDim2.new(1, 0, 0.5, 0)
				b.Parent = groupSlot
				Motion.button(b, function() claimGroup() end)
			end
		end
	end
	local function refreshDaily()
		local res = askRetention('State')
		if res and res.State then
			dailyState, dailyAt = res.State, os.clock()
			paintDaily()
		end
	end
	local function claim(action)
		if dailyBusy then return end
		dailyBusy = true
		local res = askRetention(action)
		dailyBusy = false
		if res and res.State then
			dailyState, dailyAt = res.State, os.clock()
			paintDaily()
		end
	end
	claimDaily = function() claim('ClaimDaily') end
	claimGroup = function() claim('ClaimGroup') end
	rewards.Open = function()
		paintDaily()
		task.spawn(refreshDaily)
	end
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, bought)
			if bought and Products.keyFor('Product', id) == 'RestoreStreak' then
				task.delay(2, function() if Windows.current() == rewards then refreshDaily() end end)
			end
		end)
	end)
	task.spawn(function()
		while task.wait(1) do
			if Windows.current() == rewards and dailyState and dailyState.Daily and not dailyState.Daily.Ready then paintDaily() end
		end
	end)
	return rewards
end
