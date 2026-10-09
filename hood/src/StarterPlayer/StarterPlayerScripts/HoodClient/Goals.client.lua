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
local TRACKER_Y = 2 -- (the line's centre on the reference's second line, measured at its size)
local tracker = Kit.new('Frame', { Name = 'Goal', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TRACKER_Y), Size = px(820, 36), BackgroundTransparency = 1, Visible = false, Parent = root })
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
	-- (brief 19) one short line like the reference's "Next RAID in: 3:26": where to go only when it fits at 21 px or more
	-- (the GOAL DONE moment and the Quest window always say it)
	local room = tracker.Size.X.Offset - CHIP_W - 14
	if whereText ~= '' and Kit.fitSize('Next goal: ' .. text .. whereText, LINE_SIZE, room, 8) < 21 then whereText = '' end
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
local MOMENT_Y, MOMENT_W = 50, 700 -- (LOOP: the moment's top, just under the goal line, and its width; design px)
local screen = { W = 1280, Phone = false } -- (the root's design width and whether it's a phone; relayout keeps it)

local function fadeOut(holder, labels, back)
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(holder, fade, { Position = holder.Position - UDim2.fromOffset(0, 24) }):Play()
	if back then TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play() end
	for _, t in labels do
		TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then TweenService:Create(s, fade, { Transparency = 1 }):Play() end
	end
end

-- (LOOP) PlayerGui's GoalMoment attribute is true while a moment is up: the HUD's notices drop below it meanwhile.
local function momentUp(on) pcall(function() player.PlayerGui:SetAttribute('GoalMoment', on) end) end
local function moment(info)
	holding = true
	momentUp(true)
	tracker.Visible = false
	-- (brief 18: the video's "GOAL DONE! / Wins Potion / NEXT GOAL / Hatch an egg - Eggs are in the lobby": gold
	-- headings and white lines in Gotham Black with a black stroke.) (LOOP: like the video it sits high, just under the
	-- top lines, at the video's text sizes (it was twice as big, in the middle of the screen, right over the next gate's
	-- sign and the goons), on a dark see-through backing like the video's reward banner, so it reads over anything.)
	-- (brief 19, LOOP: the backing is as wide as the longest line, not a fixed 700, and darker, so a gate sign's title
	-- doesn't show through one side of it)
	local cashText = '+' .. Format.compact(type(info.Reward) == 'number' and info.Reward or 0) .. ' Cash'
	local widest = math.max(Kit.textWidth('GOAL DONE!', 32), Kit.textWidth((info.Text or '') .. '   ' .. cashText, 26), Kit.textWidth('NEXT GOAL', 26),
		Kit.textWidth((info.NextText or '') .. ' - ' .. (info.NextWhere or ''), 24))
	local width = math.clamp(widest + 48, 360, MOMENT_W)
	-- (brief 19) on phones it keeps clear of the button column (left) and the Rewards gift (top right)
	local x = UDim.new(0.5, 0)
	if screen.Phone then
		local l, r = 230, screen.W - 370
		width = math.min(width, r - l)
		x = UDim.new(0, math.clamp(screen.W / 2, l + width / 2, r - width / 2))
	end
	local holder = Kit.new('Frame', { Name = 'GoalDone', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x.Scale, x.Offset, 0, MOMENT_Y), Size = px(width, 150), Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local back = Kit.new('Frame', { Name = 'Back', BackgroundColor3 = Kit.hex('10131E'), BackgroundTransparency = 0.28, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 76), ZIndex = 0, Parent = holder })
	Kit.corner(10).Parent = back
	local function goldText(t)
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFB020')), Parent = t })
		return t
	end
	local title = goldText(Kit.text({ Name = 'Title', Text = 'GOAL DONE!', TextSize = 32, Stroke = BLACK, StrokeThickness = 4, Position = px(0, 4), Size = UDim2.new(1, 0, 0, 36), Parent = holder }))
	local cash = '<font color="' .. GREEN .. '">' .. cashText .. '</font>'
	local reward = Kit.text({ Name = 'Reward', Text = escape(info.Text or '') .. '   ' .. cash, TextSize = 26, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = Color.white, RichText = true, Position = px(12, 40), Size = UDim2.new(1, -24, 0, 30), Parent = holder })
	reward.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 26, Parent = reward })
	local nextTitle = goldText(Kit.text({ Name = 'Next', Text = 'NEXT GOAL', TextSize = 26, Stroke = BLACK, StrokeThickness = 3.5, Position = px(0, 80), Size = UDim2.new(1, 0, 0, 30), Parent = holder }))
	local nextLine = Kit.text({ Name = 'NextLine', Text = escape(info.NextText or '') .. ' - ' .. escape(info.NextWhere or ''), TextSize = 24, Stroke = BLACK, StrokeThickness = 3.5, RichText = true, Position = px(12, 112), Size = UDim2.new(1, -24, 0, 30), Parent = holder })
	nextLine.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 24, Parent = nextLine })
	for _, t in { nextTitle, nextLine } do
		t.TextTransparency = 1
		t:FindFirstChildOfClass('UIStroke').Transparency = 1
	end
	Sound.play(chime, 1.5)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- A STAGE CLEARED or WAVE CLEARED banner arriving mid-moment takes the screen: this one steps aside at once and
	-- plays again, whole, once that banner is gone.
	local function interrupted() return busyUntil > os.clock() or fighting() end -- (LOOP: a fight starting too)
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
		momentUp(false)
		return false
	end
	if not hold(0.9) then return stepAside() end
	local show = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(back, show, { Size = UDim2.new(1, 0, 0, 150) }):Play() -- (the banner grows to take NEXT GOAL, like the video's)
	for _, t in { nextTitle, nextLine } do
		TweenService:Create(t, show, { TextTransparency = 0 }):Play()
		TweenService:Create(t:FindFirstChildOfClass('UIStroke'), show, { Transparency = 0 }):Play()
	end
	Sound.play(chime, 1.2)
	if not hold(2.9) then return stepAside() end
	fadeOut(holder, { title, reward, nextTitle, nextLine }, back)
	task.wait(0.45)
	holder:Destroy()
	holding = false
	momentUp(false)
	paintTracker(true)
	return true
end

local function drain()
	if running then return end
	running = true
	task.spawn(function()
		while #queue > 0 do
			-- (LOOP) A banner owns the screen, or a fight is on (the goons and the "N LEFT" pill own it): wait.
			while busyUntil > os.clock() or fighting() do task.wait(0.1) end
			-- Goals done meanwhile ("Walk to Stage 1", then "Beat Stage 1's goons" in the same fight) make one moment: the
			-- newest goal and NEXT GOAL, with all their Cash, so a stale "NEXT GOAL" never plays after it is done.
			local info = table.remove(queue, 1)
			while #queue > 0 do
				local newer = table.clone(table.remove(queue, 1))
				newer.Reward = (tonumber(newer.Reward) or 0) + (tonumber(info.Reward) or 0)
				info = newer
			end
			moment(info)
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
	screen.W, screen.Phone = w, math.min(abs.X, abs.Y) <= 500
	-- (brief 19) The line keeps clear of the HUD's Rewards gift (PC: the top-left slot, x 290..400 design px) and, on PC, of
	-- Roblox's player list under the top bar at the top right (~290 dp wide with our two leaderstats); on phones (no
	-- player list) of the counters' row at the top-left (x 0..390). Centred on the screen while it fits, else in the room.
	local phone = math.min(abs.X, abs.Y) <= 500
	local left = phone and 390 or 410
	local right = w - (phone and 16 or 290 / k)
	local tw = math.max(300, math.min(880, right - left))
	local cx = math.clamp(w / 2, left + tw / 2, math.max(left + tw / 2, right - tw / 2))
	tracker.Size = px(tw, 36)
	tracker.Position = UDim2.new(0, cx, 0, TRACKER_Y)
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
