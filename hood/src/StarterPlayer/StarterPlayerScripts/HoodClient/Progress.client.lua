-- Level-ups and rank-ups on your screen (brief 29, P4; the rules are Shared/LevelRules, the server is HoodServer/Levels).
--   Level up (the reference's V3 @ 9 s): a small toast at the top centre, "Level 6 > Level 7", on a thin dark strip, with a
--     brief yellow bloom at the top edge. Levels come often (the first ones with every shot), so it is deliberately minor and
--     joins into one while they keep coming ("Level 3 > Level 6"). The bloom is one flash of 0.25 s at most, never more
--     than one a second (the kid-safe rule), and not at all with Reduced Motion.
--   Rank up (the user's reference screenshot): a dark band across the middle with the world visible above and below, a big gold
--     "RANK UP!", "Street Kid > Hustler" between the old and the new rank mark (the new one glowing), two studded reward
--     cards with a NEW tag (the rank, and the Cash it paid), "Press to Close". It is short: in 0.3 s, out by 2.0 s, and it
--     never blocks: the game runs under it, a tap on "Press to Close" ends it sooner, and it waits (up to 25 s) for a window,
--     the unboxing or a fight to finish rather than cover them.
-- Everything is flat 2D UIKit (Montserrat Black through Kit.Font, studded blocks), no 3D stand-ins.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Kit = require(RS.Shared.UIKit)
local Net = require(RS.Shared.Net)
local LevelRules = require(RS.Shared.LevelRules)
local Format = require(RS.Shared.Format)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px, hex, BLACK = UDim2.fromOffset, Kit.hex, Kit.Color.black
local GOLD = hex('FFD21F')

local gui, root, fit = Kit.screen('HoodProgress', nil, 12)
local function tween(obj, t, props, style, dir)
	local ok, tw = pcall(TweenService.Create, TweenService, obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	if ok then tw:Play() end
	return tw
end
local function reduced() return player:GetAttribute('ReducedMotion') == true end
local function fade(label, t) -- text and its outline out
	tween(label, t, { TextTransparency = 1 })
	local st = label:FindFirstChildOfClass('UIStroke')
	if st then tween(st, t, { Transparency = 1 }) end
end

---------------------------------------------------------------------------------------------- level up
local TOAST_W, TOAST_H, TOAST_Y = 250, 30, 116 -- (at least under the goal tracker's lines, which end ~100 down at the HUD's scale; this screen's scale is up to 8% smaller on a computer)
local toast = Kit.new('Frame', { Name = 'LevelToast', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOAST_Y), Size = px(TOAST_W, TOAST_H), BackgroundColor3 = hex('0B0D18'), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = root })
Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0.2), NumberSequenceKeypoint.new(0.82, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = toast })
local toastText = Kit.text({ Name = 'Text', Text = '', TextSize = 19, Stroke = BLACK, StrokeThickness = 3, TextColor3 = hex('FFF27A'), ZIndex = 6, Parent = toast })
local bloom = Kit.new('Frame', { Name = 'Bloom', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = hex('FFE24A'), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = root })
Kit.new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = bloom })
bloom.Visible = false

local lastLevel, toastFrom, toastToken, lastBloom = nil, nil, 0, -10
-- (brief 32, FEEL) Where the toast sits: just under whatever the goal line has up at the top centre (its NEXT GOAL tracker,
-- or the bigger GOAL DONE moment), never on top of its words: filmed, "Level 1 > Level 2" sat on "Reach Level 6 in BAY 1".
local function toastY()
	local goals = playerGui:FindFirstChild('HoodGoals')
	local bottom = nil
	if goals and goals.Enabled ~= false then
		for _, name in { 'GoalDone', 'Goal' } do
			for _, d in goals:GetDescendants() do
				if d.Name == name and d:IsA('GuiObject') and d.Visible and d.AbsoluteSize.Y > 0 then
					local cx = d.AbsolutePosition.X + d.AbsoluteSize.X / 2
					local mid = goals.AbsoluteSize.X / 2
					if math.abs(cx - mid) < goals.AbsoluteSize.X * 0.2 and d.AbsolutePosition.Y < goals.AbsoluteSize.Y * 0.5 then
						bottom = math.max(bottom or 0, d.AbsolutePosition.Y + d.AbsoluteSize.Y)
					end
				end
			end
		end
	end
	local k = (toast.AbsoluteSize.Y > 0) and (toast.AbsoluteSize.Y / TOAST_H) or 1
	if not bottom or k <= 0 then return TOAST_Y end
	local y = (bottom + 6 * k - root.AbsolutePosition.Y) / k
	return math.max(TOAST_Y, math.floor(y + 0.5))
end
local function levelUp(from, to)
	local wasShown = toast.Visible
	toastFrom = (wasShown and toastFrom) or from
	toastText.Text = 'Level ' .. toastFrom .. '  >  Level ' .. to
	toast.Visible = true
	local st = toastText:FindFirstChildOfClass('UIStroke')
	-- (brief 32: it eases in, 0.15 s, rather than appearing whole in one frame)
	local fadeIn = wasShown and 0.08 or 0.15
	tween(toast, fadeIn, { BackgroundTransparency = 0 })
	tween(toastText, fadeIn, { TextTransparency = 0 })
	if st then tween(st, fadeIn, { Transparency = 0 }) end
	toastToken += 1
	local mine = toastToken
	local y = toastY()
	if reduced() then
		toast.Position = UDim2.new(0.5, 0, 0, y)
	else
		if not wasShown then toast.Position = UDim2.new(0.5, 0, 0, y - 8) end
		tween(toast, 0.18, { Position = UDim2.new(0.5, 0, 0, y) }, Enum.EasingStyle.Back)
		if os.clock() - lastBloom >= 1.2 then -- one flash, 0.25 s at most, never more than one a second
			lastBloom = os.clock()
			bloom.Visible, bloom.BackgroundTransparency = true, 0.45
			tween(bloom, 0.25, { BackgroundTransparency = 1 })
			task.delay(0.28, function() bloom.Visible = false end)
		end
	end
	task.delay(1.5, function()
		if mine ~= toastToken then return end
		tween(toast, 0.25, { BackgroundTransparency = 1 })
		fade(toastText, 0.25)
		task.delay(0.3, function()
			if mine == toastToken then toast.Visible = false end
		end)
	end)
end
-- (Oct 27, flow: "one voice at a time") No level toast in the first minute of a visit (the first shots level you up every
-- second or two: the counter and the Level bar tick, quietly), and none while another moment owns the screen.
local MomentQueue = require(RS.Shared.MomentQueue)
local QUIET_FIRST = 60
local joinedAt = os.clock()
local function onPower()
	local p = player:GetAttribute('Power')
	if type(p) ~= 'number' then return end
	local level = LevelRules.levelOf(p)
	if lastLevel and level > lastLevel and os.clock() - joinedAt >= QUIET_FIRST and not MomentQueue.busy() then levelUp(lastLevel, level) end
	lastLevel = level -- (a rebirth lowers it: no toast, just the new base)
end
player:GetAttributeChangedSignal('Power'):Connect(onPower)
onPower()

---------------------------------------------------------------------------------------------- rank up
local TONES = { 'grey', 'green', 'blue', 'purple', 'orange', 'red', 'gold', 'pink' }
-- The rank mark: `count` stacked chevrons (two bars each, a black edge), the way military ranks read.
local function chevrons(parent, count, color, size, glow)
	local holder = Kit.new('Frame', { Name = 'Mark', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(size, size), Parent = parent })
	if count <= 0 then count = 1 end
	local gap = size * 0.2
	local top = size * 0.5 - (count - 1) * gap * 0.5 - size * 0.12
	for i = 1, count do
		local y = top + (i - 1) * gap
		for _, s in { -1, 1 } do
			local bar = Kit.new('Frame', { Name = 'Bar', AnchorPoint = Vector2.new(0.5, 0.5), Position = px(size * 0.5 + s * size * 0.17, y), Size = px(size * 0.5, size * 0.13), Rotation = s * 24, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 8, Parent = holder })
			Kit.stroke(glow and hex('FFF6B0') or BLACK, glow and 3 or 2.5).Parent = bar
		end
	end
	return holder
end

local function card(index, rankIdx, kind, amount)
	local rank = LevelRules.Ranks[rankIdx]
	local c = Kit.block({ Name = kind, Tone = kind == 'Rank' and TONES[rankIdx] or 'green', Width = 150, Height = 170, Outline = 4, RimWidth = 3, Studs = Kit.studsAreCheap() and 34 or false, ZIndex = 8 })
	if kind == 'Rank' then
		chevrons(c.Body, rank.Chevrons, hex(string.sub(rank.Color, 2)), 96, true).Position = UDim2.new(0.5, 0, 0.42, 0)
		Kit.text({ Name = 'Name', Text = rank.Name, TextSize = 24, Stroke = BLACK, StrokeThickness = 3, Position = UDim2.new(0, 0, 1, -42), Size = UDim2.new(1, 0, 0, 34), ZIndex = 9, Parent = c.Body })
	else
		Kit.icon3d('Cash', 84, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0), ZIndex = 9 }).Parent = c.Body
		Kit.text({ Name = 'Name', Text = '+' .. Format.compact(amount), TextSize = 30, Stroke = BLACK, StrokeThickness = 3.5, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 40), ZIndex = 9, Parent = c.Body })
	end
	local tag = Kit.block({ Name = 'New', Tone = 'red', Width = 58, Height = 26, Outline = 3, Studs = false, ZIndex = 12 })
	tag.Position = UDim2.new(0, -10, 0, -12)
	Kit.text({ Name = 'T', Text = 'NEW', TextSize = 16, Stroke = BLACK, StrokeThickness = 2.5, ZIndex = 13, Parent = tag.Body })
	tag.Parent = c
	return c
end

local current -- the rank-up on screen: { Holder, Token }
local function close(token)
	if not current or current.Token ~= token then return end
	local holder = current.Holder
	current = nil
	tween(holder.Band, 0.25, { BackgroundTransparency = 1 })
	for _, d in holder:GetDescendants() do
		if d:IsA('TextLabel') then fade(d, 0.2) end
	end
	tween(holder.Cards, 0.25, { Position = UDim2.new(0.5, 0, 0.5, 80) })
	task.delay(0.3, function() holder:Destroy() end)
end
local function showRank(info)
	if current then close(current.Token) end
	local token = (current and current.Token or 0) + 1
	local from, to = LevelRules.Ranks[info.From] or LevelRules.Ranks[1], LevelRules.Ranks[info.To] or LevelRules.Ranks[2]
	local holder = Kit.new('Frame', { Name = 'RankUp', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local band = Kit.new('Frame', { Name = 'Band', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 400), BackgroundColor3 = hex('070912'), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 20, Parent = holder })
	Kit.new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0), NumberSequenceKeypoint.new(0.88, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = band })
	local title = Kit.text({ Name = 'Title', Text = 'RANK UP!', TextSize = 84, Stroke = hex('5A2E00'), StrokeThickness = 8, TextColor3 = GOLD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -140), Size = px(700, 96), ZIndex = 24, Parent = holder })
	local scale = Kit.new('UIScale', { Scale = reduced() and 1 or 0.3, Parent = title })
	-- "Street Kid > Hustler" between the old mark (dim) and the new one (glowing)
	local row = Kit.new('Frame', { Name = 'Line', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -66), Size = px(760, 56), ZIndex = 22, Parent = holder })
	local oldMark = chevrons(row, math.max(from.Chevrons, 1), hex('8E94A6'), 46, false)
	oldMark.Position = UDim2.new(0, 28, 0.5, 0)
	local newMark = chevrons(row, to.Chevrons, hex(string.sub(to.Color, 2)), 56, true)
	newMark.Position = UDim2.new(1, -34, 0.5, 0)
	Kit.text({ Name = 'Ranks', Text = from.Name .. '  >  ' .. to.Name, TextSize = 38, Stroke = BLACK, StrokeThickness = 4.5, Position = px(60, 0), Size = px(640, 56), ZIndex = 24, Parent = row })
	local cards = Kit.new('Frame', { Name = 'Cards', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(360, 170), ZIndex = 22, Parent = holder })
	Kit.new('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 24), Parent = cards })
	local rankCard = card(1, info.To, 'Rank')
	rankCard.LayoutOrder, rankCard.Parent = 1, cards
	if (info.Cash or 0) > 0 then
		local cashCard = card(2, info.To, 'Cash', info.Cash)
		cashCard.LayoutOrder, cashCard.Parent = 2, cards
	end
	cards.Position = UDim2.new(0.5, 0, 0.5, 52)
	local hit = Kit.new('TextButton', { Name = 'Close', Text = 'Press to Close', FontFace = Kit.Font.display, TextSize = 20, TextColor3 = Kit.Color.white, BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 172), Size = px(220, 30), ZIndex = 25, Parent = holder })
	Kit.stroke(BLACK, 3).Parent = hit
	current = { Holder = holder, Token = token }
	hit.Activated:Connect(function() close(token) end)
	-- in: the band is there at once, the title pops, the cards rise one after the other (0.3 s)
	if not reduced() then
		band.Size = UDim2.new(1, 0, 0, 40)
		tween(band, 0.25, { Size = UDim2.new(1, 0, 0, 400) }, Enum.EasingStyle.Back)
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		cards.Position = UDim2.new(0.5, 0, 0.5, 106)
		task.delay(0.08, function() tween(cards, 0.25, { Position = UDim2.new(0.5, 0, 0.5, 52) }, Enum.EasingStyle.Back) end)
	end
	task.delay(1.75, function() close(token) end) -- (out by 2.0 s)
end

-- Waits for the screen to be free (a window, the unboxing or a fight), at most 25 s, then shows it.
local function busy()
	local w = playerGui:GetAttribute('HoodWindow')
	local stage, left = player:GetAttribute('WaveStage'), player:GetAttribute('WaveLeft')
	return (type(w) == 'string' and w ~= '') or playerGui:GetAttribute('Unboxing') == true or (type(stage) == 'number' and stage > 0 and type(left) == 'number' and left > 0)
end
local queue, running = {}, false
local function drain()
	if running then return end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local info = table.remove(queue, 1)
			-- (Oct 27, flow) its turn in the one moment queue, on a free screen (25 s at most, as before)
			local token = MomentQueue.acquire('RankUp', { Ready = function() return not busy() end, Timeout = 25 })
			if token then
				showRank(info)
				task.wait(2.1)
				MomentQueue.release(token)
			end
		end
		running = false
	end)
end
Net.get('RankUp').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or type(info.To) ~= 'number' then return end
	table.insert(queue, { From = info.From, To = info.To, Cash = type(info.Cash) == 'number' and info.Cash or 0 })
	drain()
end)
-- (for the checks and previews: the screen on demand)
gui:SetAttribute('ShowRank', 0)
gui:GetAttributeChangedSignal('ShowRank'):Connect(function()
	local to = gui:GetAttribute('ShowRank')
	if type(to) == 'number' and to >= 2 and to <= #LevelRules.Ranks then
		showRank({ From = to - 1, To = to, Cash = LevelRules.Ranks[to].Cash })
	end
end)

gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)
