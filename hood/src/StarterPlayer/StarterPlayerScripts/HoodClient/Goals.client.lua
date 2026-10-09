-- The goal chain on your screen (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go"). The server
-- decides (GoalService, Shared/GoalRules); this shows it.
--   Tracker: one line at the top centre, under the HUD's hint: "NEXT GOAL: Clear Stage 1's targets - in the side
--     yard past the door", with the Cash it pays in a green chip. It reads the attributes GoalStep, GoalText,
--     GoalWhere and GoalReward the server keeps on you.
--   The moment: when a goal completes (remote Goal), "GOAL DONE!" pops big in the middle of the screen with the
--     Cash it paid, then "NEXT GOAL" and where to go, holds, and floats away; the tracker then shows the new goal.
--     It waits for a STAGE CLEARED or WAVE CLEARED banner on screen to finish first.
-- Styled like the HUD: UIKit's display font with a thick ink outline, colour by meaning (green done/Cash, yellow
-- next, white the goal, light blue where).
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local RS = game:GetService('ReplicatedStorage')
local Kit = require(RS.Shared.UIKit)
local Net = require(RS.Shared.Net)
local Format = require(RS.Shared.Format)

local player = Players.LocalPlayer
local Color, Tone = Kit.Color, Kit.Tone
local px = UDim2.fromOffset

local gui, root, fit = Kit.screen('HoodGoals', nil, 7)

---------------------------------------------------------------------------------------------- tracker
-- (brief 18) The reference's second timer line ("Next RAID in: 3:26  [SKIP]", user_26): no box, white Gotham Black
-- with a black stroke and the key words in colour; the Cash the goal pays in a chip like its SKIP button (see-through
-- teal, a dark teal edge). One line, like the video's "NEXT GOAL: Hatch an egg - Eggs are in the lobby".
local BLACK = Color.black
local GREEN = '#5CE08A' -- the reference's "DOCTOR DOOM" green
local LINE_SIZE, CHIP_W, CHIP_H = 28, 84, 30
local tracker = Kit.new('Frame', { Name = 'Goal', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = px(820, 36), BackgroundTransparency = 1, Visible = false, Parent = root })
local trackerScale = Kit.new('UIScale', { Parent = tracker })
local line = Kit.text({ Name = 'Line', Text = '', TextSize = LINE_SIZE, Stroke = BLACK, StrokeThickness = 3.5, RichText = true, Position = px(0, 0), Size = px(600, 34), ZIndex = 2, Parent = tracker })
local chip = Kit.new('Frame', { Name = 'Reward', AnchorPoint = Vector2.new(0, 0.5), Position = px(610, 17), Size = px(CHIP_W, CHIP_H), BackgroundColor3 = Kit.hex('3E9A92'), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 2, Parent = tracker })
Kit.corner(2).Parent = chip
Kit.stroke(Kit.hex('133E48'), 2.5, true).Parent = chip
Kit.icon3d('Cash', 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -4, 0.5, 0), ZIndex = 3 }).Parent = chip
local chipText = Kit.text({ Name = 'Cash', Text = '+0', TextSize = 20, Stroke = BLACK, StrokeThickness = 2.5, Position = px(24, 0), Size = UDim2.new(1, -26, 1, 0), ZIndex = 3, Parent = chip })
-- The line and its chip sit side by side, centred together (the line sized to its text).
local function place(plain, withChip)
	local width = tracker.Size.X.Offset
	local room = width - (withChip and CHIP_W + 14 or 0)
	line.TextSize = Kit.fitSize(plain, LINE_SIZE, room, 12)
	local stroke = line:FindFirstChildOfClass('UIStroke')
	if stroke then stroke.Thickness = math.max(2, line.TextSize * 0.125) end
	local textW = math.min(Kit.textWidth(plain, line.TextSize), room)
	local total = textW + (withChip and CHIP_W + 14 or 0)
	local x0 = (width - total) / 2
	line.Position = px(x0, 0)
	line.Size = px(textW, 34)
	chip.Position = px(x0 + textW + 14, 17)
end

local function escape(s) return (tostring(s):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')) end

local holding = false -- while a GOAL DONE moment is up, the tracker waits
-- (brief 18) In a fight the "N LEFT" counter owns the top centre (FightUI), so the goal line steps aside.
local clearUntil = 0 -- (and for the 2.4 s Waves.client holds "CLEAR!" after a wave falls)
local function fighting()
	local left = player:GetAttribute('WaveLeft')
	return (type(left) == 'number' and left > 0) or os.clock() < clearUntil
end
local allDoneAt = nil
local function paintTracker(pop)
	local step, text, where, reward = player:GetAttribute('GoalStep'), player:GetAttribute('GoalText'), player:GetAttribute('GoalWhere'), player:GetAttribute('GoalReward')
	if type(step) ~= 'number' or type(text) ~= 'string' then
		tracker.Visible = false
		return
	end
	local done = type(reward) ~= 'number' or reward <= 0
	if done then
		-- The whole chain is done: say so for a while, then get out of the way.
		allDoneAt = allDoneAt or os.clock()
		line.Text = '<font color="' .. GREEN .. '">' .. escape(text) .. '</font>'
		place(text, false)
		chip.Visible = false
		tracker.Visible = not holding and not fighting() and os.clock() - allDoneAt < 12
		if tracker.Visible then task.delay(12.5, function() paintTracker(false) end) end
		return
	end
	allDoneAt = nil
	local whereText = (type(where) == 'string' and where ~= '') and (' - ' .. where) or ''
	line.Text = 'Next goal: <font color="' .. GREEN .. '">' .. escape(text) .. '</font>' .. escape(whereText)
	place('Next goal: ' .. text .. whereText, true)
	chipText.Text = '+' .. Format.compact(reward)
	chipText.TextSize = Kit.fitSize(chipText.Text, 20, CHIP_W - 30, 10)
	chip.Visible = true
	tracker.Visible = not holding and not fighting()
	if pop and tracker.Visible then
		trackerScale.Scale = 1.15
		TweenService:Create(trackerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end
for _, name in { 'GoalStep', 'GoalText', 'GoalWhere', 'GoalReward', 'WaveLeft' } do
	player:GetAttributeChangedSignal(name):Connect(function() paintTracker(false) end)
end

---------------------------------------------------------------------------------------------- the moment
local Sound = require(RS.Shared.Config.Sound) -- (COMBAT: every game sound behind one switch, off for now)
local chime = Sound.new('rbxasset://sounds/electronicpingshort.wav', 0.55, gui)
-- Other big banners (StageClear from the server, WAVE CLEARED, an unboxing) own the middle of the screen for a while.
local busyUntil = 0
local queue, running = {}, false

local function fadeOut(holder, labels)
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	for _, t in labels do
		TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then TweenService:Create(s, fade, { Transparency = 1 }):Play() end
	end
end

local function moment(info)
	holding = true
	tracker.Visible = false
	-- (brief 18: the video's "GOAL DONE! / Wins Potion / NEXT GOAL / Hatch an egg - Eggs are in the lobby": no boxes,
	-- gold headings and white lines in Gotham Black with a black stroke, centred in the upper third)
	local holder = Kit.new('Frame', { Name = 'GoalDone', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = px(860, 236), Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local function goldText(t)
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFB020')), Parent = t })
		return t
	end
	local title = goldText(Kit.text({ Name = 'Title', Text = 'GOAL DONE!', TextSize = 46, Stroke = BLACK, StrokeThickness = 5, Size = UDim2.new(1, 0, 0, 52), Parent = holder }))
	local cash = '<font color="' .. GREEN .. '">+' .. Format.compact(type(info.Reward) == 'number' and info.Reward or 0) .. ' Cash</font>'
	local reward = Kit.text({ Name = 'Reward', Text = escape(info.Text or '') .. '   ' .. cash, TextSize = 34, Stroke = BLACK, StrokeThickness = 4, TextColor3 = Color.white, RichText = true, Position = px(0, 56), Size = UDim2.new(1, 0, 0, 42), Parent = holder })
	reward.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 34, Parent = reward })
	local nextTitle = goldText(Kit.text({ Name = 'Next', Text = 'NEXT GOAL', TextSize = 40, Stroke = BLACK, StrokeThickness = 4.5, Position = px(0, 110), Size = UDim2.new(1, 0, 0, 46), Parent = holder }))
	local nextLine = Kit.text({ Name = 'NextLine', Text = escape(info.NextText or '') .. ' - ' .. escape(info.NextWhere or ''), TextSize = 32, Stroke = BLACK, StrokeThickness = 4, RichText = true, Position = px(0, 160), Size = UDim2.new(1, 0, 0, 76), TextWrapped = true, Parent = holder })
	nextLine.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 32, Parent = nextLine })
	for _, t in { nextTitle, nextLine } do
		t.TextTransparency = 1
		t:FindFirstChildOfClass('UIStroke').Transparency = 1
	end
	Sound.play(chime, 1.5)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- A STAGE CLEARED or WAVE CLEARED banner arriving mid-moment takes the screen: this one steps aside at once and
	-- plays again, whole, once that banner is gone.
	local function interrupted() return busyUntil > os.clock() end
	local function hold(t)
		local untilT = os.clock() + t
		while os.clock() < untilT do
			if interrupted() then return false end
			task.wait(0.05)
		end
		return true
	end
	local function stepAside()
		holder:Destroy()
		table.insert(queue, 1, info)
		holding = false
		return false
	end
	if not hold(0.9) then return stepAside() end
	local show = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, t in { nextTitle, nextLine } do
		TweenService:Create(t, show, { TextTransparency = 0 }):Play()
		TweenService:Create(t:FindFirstChildOfClass('UIStroke'), show, { Transparency = 0 }):Play()
	end
	Sound.play(chime, 1.2)
	if not hold(2.9) then return stepAside() end
	fadeOut(holder, { title, reward, nextTitle, nextLine })
	task.wait(0.45)
	holder:Destroy()
	holding = false
	paintTracker(true)
	return true
end

local function drain()
	if running then return end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local wait = busyUntil - os.clock()
			if wait > 0 then task.wait(wait) end
			moment(table.remove(queue, 1))
		end
		running = false
	end)
end

task.spawn(function()
	Net.get('Goal').OnClientEvent:Connect(function(info)
		if type(info) ~= 'table' or info.Kind ~= 'Done' then return end
		table.insert(queue, info)
		drain()
	end)
	Net.get('Cinematic').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'StageClear' then busyUntil = math.max(busyUntil, os.clock() + 2.3) end
	end)
	Net.get('WaveState').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'Cleared' then
			busyUntil = math.max(busyUntil, os.clock() + 2.3)
			clearUntil = os.clock() + 2.4
			paintTracker(false)
			task.delay(2.45, function() paintTracker(false) end)
		end
	end)
	-- (Shoes.client's unboxing moment owns the middle of the screen for 4 to 5 s)
	local opened = Net.get('ShoeOpened')
	if opened then opened.OnClientEvent:Connect(function() busyUntil = math.max(busyUntil, os.clock() + 5.2) end) end
end)

---------------------------------------------------------------------------------------------- layout
-- As wide as the HUD's hint line may be (clear of the left button column), sized to the goal's text.
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	local k = Kit.scaleFor(abs)
	local w = abs.X / k
	tracker.Size = px(math.max(360, math.min(880, w - 2 * 250)), 36)
	paintTracker(false)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
-- (brief 18) the goal line steps away while a window is open, like the reference's top lines and the HUD
local playerGui = player:WaitForChild('PlayerGui')
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local open = playerGui:GetAttribute('HoodWindow')
	gui.Enabled = not (type(open) == 'string' and open ~= '')
end)
gui.Parent = playerGui
relayout()
paintTracker(false)
