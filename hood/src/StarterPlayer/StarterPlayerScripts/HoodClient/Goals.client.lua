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
local NEXT, WHERE = '#FFE76A', '#9CF6FF' -- "NEXT GOAL" yellow, the where-to-go light blue

local gui, root, fit = Kit.screen('HoodGoals', nil, 7)

---------------------------------------------------------------------------------------------- tracker
local tracker = Kit.new('Frame', { Name = 'Goal', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = px(720, 36), BackgroundColor3 = Color.asphalt, BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false, Parent = root })
Kit.corner(UDim.new(0.5, 0)).Parent = tracker
Kit.stroke(Color.ink, 2.5, true).Parent = tracker
local trackerScale = Kit.new('UIScale', { Parent = tracker })
local flag = Kit.text({ Name = 'Flag', Text = '🏁', FontFace = Kit.Font.body, TextSize = 22, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = px(26, 26), Parent = tracker })
flag.ZIndex = 2
local line = Kit.text({ Name = 'Line', Text = '', TextSize = 22, Stroke = Color.ink, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Position = px(42, 1), Size = UDim2.new(1, -124, 1, 0), ZIndex = 2, Parent = tracker })
line.TextScaled = true
Kit.new('UITextSizeConstraint', { MaxTextSize = 22, MinTextSize = 11, Parent = line })
local chip = Kit.new('Frame', { Name = 'Reward', AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = px(74, 26), BackgroundColor3 = Tone.green.base, BorderSizePixel = 0, ZIndex = 2, Parent = tracker })
Kit.corner(UDim.new(0.5, 0)).Parent = chip
Kit.stroke(Color.ink, 2, true).Parent = chip
Kit.gradient(Tone.green.top, Tone.green.base, 0.55).Parent = chip
local chipText = Kit.text({ Name = 'Cash', Text = '+0', TextSize = 18, Stroke = Tone.green.stroke, ZIndex = 3, Parent = chip })

local function escape(s) return (tostring(s):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')) end
local function goalLine(text, where)
	return '<font color="' .. NEXT .. '">NEXT GOAL:</font> ' .. escape(text) .. ' <font color="' .. WHERE .. '">- ' .. escape(where) .. '</font>'
end

local holding = false -- while a GOAL DONE moment is up, the tracker waits
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
		line.Text = '<font color="#8CF06A">' .. escape(text) .. '</font> <font color="' .. WHERE .. '">- ' .. escape(where or '') .. '</font>'
		chip.Visible = false
		tracker.Visible = not holding and os.clock() - allDoneAt < 12
		if tracker.Visible then task.delay(12.5, function() paintTracker(false) end) end
		return
	end
	allDoneAt = nil
	line.Text = goalLine(text, where or '')
	chipText.Text = '+' .. Format.compact(reward)
	chip.Visible = true
	tracker.Visible = not holding
	if pop and tracker.Visible then
		trackerScale.Scale = 1.15
		TweenService:Create(trackerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end
for _, name in { 'GoalStep', 'GoalText', 'GoalWhere', 'GoalReward' } do
	player:GetAttributeChangedSignal(name):Connect(function() paintTracker(false) end)
end

---------------------------------------------------------------------------------------------- the moment
local chime = Instance.new('Sound')
chime.SoundId = 'rbxasset://sounds/electronicpingshort.wav'
chime.Volume = 0.55
chime.Parent = gui
-- Other big banners (StageClear from the server, WAVE CLEARED) own the middle of the screen for ~2.3 s.
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
	local holder = Kit.new('Frame', { Name = 'GoalDone', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = px(760, 224), Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local title = Kit.text({ Name = 'Title', Text = 'GOAL DONE!', TextSize = 58, Stroke = Color.ink, Size = UDim2.new(1, 0, 0, 64), Parent = holder })
	title:FindFirstChildOfClass('UIStroke').Thickness = 5
	Kit.gradient(Color.white, Tone.green.top, 0.45).Parent = title -- (white lit top into green, like the STAGE CLEARED banner)
	local cash = '<font color="#8CF06A">+' .. Format.compact(type(info.Reward) == 'number' and info.Reward or 0) .. ' CASH</font>'
	local reward = Kit.text({ Name = 'Reward', Text = escape(info.Text or '') .. '   ' .. cash, TextSize = 30, Stroke = Color.ink, TextColor3 = Color.white, RichText = true, Position = px(0, 66), Size = UDim2.new(1, 0, 0, 38), Parent = holder })
	reward.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 30, Parent = reward })
	local nextTitle = Kit.text({ Name = 'Next', Text = 'NEXT GOAL', TextSize = 32, Stroke = Color.ink, TextColor3 = Tone.yellow.top, Position = px(0, 118), Size = UDim2.new(1, 0, 0, 36), Parent = holder })
	local nextLine = Kit.text({ Name = 'NextLine', Text = escape(info.NextText or '') .. ' <font color="' .. WHERE .. '">- ' .. escape(info.NextWhere or '') .. '</font>', TextSize = 26, Stroke = Color.ink, RichText = true, Position = px(0, 156), Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, Parent = holder })
	nextLine.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 26, Parent = nextLine })
	for _, t in { nextTitle, nextLine } do
		t.TextTransparency = 1
		t:FindFirstChildOfClass('UIStroke').Transparency = 1
	end
	chime.PlaybackSpeed = 1.5
	chime:Play()
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
	chime.PlaybackSpeed = 1.2
	chime:Play()
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
		if type(info) == 'table' and info.Kind == 'Cleared' then busyUntil = math.max(busyUntil, os.clock() + 2.3) end
	end)
end)

---------------------------------------------------------------------------------------------- layout
-- As wide as the HUD's hint line may be (clear of the left button column), sized to the goal's text.
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	local k = Kit.scaleFor(abs)
	local w = abs.X / k
	tracker.Size = px(math.max(360, math.min(760, w - 2 * (16 + 224 + 24))), 36)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = player:WaitForChild('PlayerGui')
relayout()
paintTracker(false)
