-- The goal chain on your screen (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go"). The server
-- decides (GoalService, Shared/GoalRules); this shows it.
--   Tracker (brief 29: specific, not vague): three short lines at the top centre, under the HUD's hint: a gold "NEXT
--     GOAL" (with the Cash it pays in a green chip), what to do (the key words green) and where or how, in light blue,
--     always shown. It reads the attributes GoalStep, GoalText, GoalWhere and GoalReward the server keeps on you.
--   The moment: when a goal completes (remote Goal), "GOAL DONE!" pops at the top centre with the Cash it paid on one
--     dark band that fades out at both ends, then "NEXT GOAL: ..." under it, holds, and floats away; the tracker then
--     shows the new goal. It waits for a STAGE CLEARED or WAVE CLEARED banner on screen to finish first.
--     (brief 23, CRITIC3) It never covers a stage pad's label or the HUD's bottom bar: it sits in the top band (96
--     design px), and while a pad label on screen would reach into it, it drops its NEXT GOAL line (the tracker says it
--     right after), or moves down to just above the bottom bar.
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

local Spec = require(RS.Shared.HudSpec)
local gui, root, fit = Spec.screen('HoodGoals', 7) -- (HudSpec: a reference px is a screen px at 720 tall)

---------------------------------------------------------------------------------------------- tracker
-- (brief 30, HUD: copied from ref_W49.5 / ref_W45.0, measured at 720 px tall; the lead's r8 note: one short line) The
-- reference's goal tracker: no box; "NEXT GOAL" in gold (cap 18 px, centred 91 px down the screen = 33 under the top bar)
-- and 49 px under it ONE short white line, the goal itself (GoalRules keeps every Text to 28 characters), with what it pays
-- beside it: the Cash picture and "+25" in gold. Where to go is the tutorial's arrows' and the goal list's job (a tap on
-- the tracker opens HUD.client's Quest window, which lists every goal with its "where").
local BLACK = Color.black
local TRACKER_W, TRACKER_Y = 460, 19 -- (the head's top: its centre at 33)
local HEAD_SIZE, LINE_SIZE, REWARD_SIZE, CASH_ICON = 24, 26, 24, 34
local LINE_Y = 49 -- (the line's centre under the head's)
local TRACKER_H = 14 + LINE_Y + 20
local tracker = Kit.new('TextButton', { Name = 'Goal', Text = '', AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TRACKER_Y), Size = px(TRACKER_W, TRACKER_H), BackgroundTransparency = 1, Visible = false, Parent = root })
local trackerScale = Kit.new('UIScale', { Parent = tracker })
local function gold(t)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFB020')), Parent = t })
	return t
end
local head = gold(Kit.text({ Name = 'Head', Text = 'NEXT GOAL', TextSize = HEAD_SIZE, Stroke = BLACK, StrokeThickness = 3.5, Position = px(0, 0), Size = px(TRACKER_W, 28), ZIndex = 2, Parent = tracker }))
local row = Kit.new('Frame', { Name = 'Row', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 14 + LINE_Y), Size = px(TRACKER_W, 36), ZIndex = 2, Parent = tracker })
local line = Kit.text({ Name = 'Line', Text = '', TextSize = LINE_SIZE, Stroke = BLACK, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(0, 0), Size = px(300, 36), ZIndex = 2, Parent = row })
local cashIcon = Kit.icon3d('Cash', CASH_ICON, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 2 })
cashIcon.Parent = row
local rewardText = gold(Kit.text({ Name = 'Reward', Text = '', TextSize = REWARD_SIZE, Stroke = BLACK, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(0, 0), Size = px(80, 36), ZIndex = 2, Parent = row }))
tracker.Activated:Connect(function()
	local hud = player.PlayerGui:FindFirstChild('HoodHUD')
	local ev = hud and hud:FindFirstChild('OpenQuest')
	if ev then ev:Fire() end
end)
-- The goal, then the Cash picture and "+25", centred together on one line (shrunk only if it would not fit).
local function place(text, reward)
	local rw = reward and Kit.textWidth(reward, REWARD_SIZE) or 0
	local extra = reward and (8 + CASH_ICON - 4 + rw) or 0
	local W = tracker.Size.X.Offset
	row.Size = px(W, 36)
	line.TextSize = Kit.fitSize(text, LINE_SIZE, W - extra, 14)
	local stroke = line:FindFirstChildOfClass('UIStroke')
	if stroke then stroke.Thickness = math.max(2.5, line.TextSize * 0.135) end
	local tw = Kit.textWidth(text, line.TextSize)
	local total = tw + extra
	local x0 = (W - total) / 2
	line.Position = px(x0, 0)
	line.Size = px(tw, 36)
	cashIcon.Visible, rewardText.Visible = reward ~= nil, reward ~= nil
	if reward then
		cashIcon.Position = UDim2.new(0, x0 + tw + 8, 0.5, 0)
		rewardText.Text = reward
		rewardText.Position = px(x0 + tw + 8 + CASH_ICON - 4, 0)
		rewardText.Size = px(rw, 36)
	end
end

local unboxUntil = 0 -- (just after a ShoeOpened, before Shoes.client's unboxing moment sets PlayerGui Unboxing)
local function unboxing()
	return os.clock() < unboxUntil or (player:FindFirstChildOfClass('PlayerGui') ~= nil and player.PlayerGui:GetAttribute('Unboxing') == true)
end
-- (CRITIC4 r1: one message at a time) just after an unboxing, the guide's callout (Onboarding.client's "GUN!" after the
-- gift) goes first: GOAL DONE waits a beat for it, then while it is up (2 s at most).
local settleUntil = 0
local function boardUp() -- (Shoes.client's box chance board: PlayerGui BoxBoard)
	return player:FindFirstChildOfClass('PlayerGui') ~= nil and player.PlayerGui:GetAttribute('BoxBoard') == true
end
local function calloutUp()
	local g = player:FindFirstChildOfClass('PlayerGui') and player.PlayerGui:FindFirstChild('HoodOnboarding')
	return g ~= nil and g:FindFirstChild('Callout', true) ~= nil
end

local holding = false -- while a GOAL DONE moment is up, the tracker waits
-- (brief 18) In a fight the "N LEFT" counter owns the top centre (FightUI), so the goal line steps aside.
local clearUntil = 0 -- (and for the 2.4 s Waves.client holds "CLEAR!" after a wave falls)
local function fighting()
	local left = player:GetAttribute('WaveLeft')
	return (type(left) == 'number' and left > 0) or os.clock() < clearUntil
end
local allDoneAt = nil
local function paintTracker(pop)
	local step, text, reward = player:GetAttribute('GoalStep'), player:GetAttribute('GoalText'), player:GetAttribute('GoalReward')
	if type(step) ~= 'number' or type(text) ~= 'string' then
		tracker.Visible = false
		return
	end
	local done = type(reward) ~= 'number' or reward <= 0
	if done then
		-- the whole chain is done: say so for a while, then get out of the way
		allDoneAt = allDoneAt or os.clock()
		head.Text = 'ALL GOALS DONE!'
		local where = player:GetAttribute('GoalWhere')
		line.Text = type(where) == 'string' and where ~= '' and where or ''
		place(line.Text, nil)
		tracker.Visible = not holding and not fighting() and not unboxing() and not boardUp() and os.clock() - allDoneAt < 12
		if tracker.Visible then task.delay(12.5, function() paintTracker(false) end) end
		return
	end
	allDoneAt = nil
	head.Text = 'NEXT GOAL'
	line.Text = text
	place(text, '+' .. Format.compact(reward))
	tracker.Visible = not holding and not fighting() and not unboxing() and not boardUp()
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
-- (brief 23) the moment's top (the goal line's place: the tracker hides while it is up), its widest, its height with and
-- without the NEXT GOAL line, and how far its low place stays over the screen's bottom (the HUD's Power count and bar
-- take the bottom ~175 design px); design px
local MOMENT_Y, MOMENT_W, MOMENT_H, MOMENT_SHORT, MOMENT_LOW = 19, 640, 210, 110, 184
local screen = { W = 1280, H = 720, Phone = false } -- (the root's design size and whether it's a phone; relayout keeps it)

-- (brief 23, CRITIC3: GOAL DONE landed on the pads' "+10 Cash / Return" labels at the end of a stage) The stage pads'
-- labels (parts tagged HoodStagePad, label <Name>Label > WorldLabel) on screen, as rectangles in the Root's design px.
local CollectionService = game:GetService('CollectionService')
local GuiService = game:GetService('GuiService')
local function padRects()
	local cam = workspace.CurrentCamera
	local rects = {}
	if not cam then return rects end
	local ok = pcall(function()
		local k = Spec.scaleFor(gui.AbsoluteSize)
		local inset = GuiService:GetGuiInset()
		local tanHalf = math.tan(math.rad(cam.FieldOfView / 2))
		local vh = cam.ViewportSize.Y
		for _, pad in CollectionService:GetTagged('HoodStagePad') do
			local anchor = pad.Parent and pad.Parent:FindFirstChild(pad.Name .. 'Label')
			local g = anchor and anchor:FindFirstChildWhichIsA('BillboardGui')
			if g and g.Enabled and anchor:IsA('BasePart') then
				local p, on = cam:WorldToViewportPoint(anchor.CFrame.Position)
				local far = g:GetAttribute('FadeFar') or g.MaxDistance
				if on and p.Z > 0.5 and p.Z < math.min(far, 200) then
					local perStud = vh / (2 * p.Z * tanHalf)
					local hw = (g.Size.X.Scale * perStud + g.Size.X.Offset) / 2
					local hh = (g.Size.Y.Scale * perStud + g.Size.Y.Offset) / 2
					table.insert(rects, { (p.X - hw - inset.X) / k, (p.Y - hh - inset.Y) / k, (p.X + hw - inset.X) / k, (p.Y + hh - inset.Y) / k })
				end
			end
		end
	end)
	return ok and rects or {}
end
-- Where the moment goes now: the top band whole, the top band without its NEXT GOAL line, or whole just over the
-- bottom bar; the first that no pad label reaches into (else the short top one). Returns top y, whether whole.
local function momentPlace(cx, width)
	local rects = padRects()
	local function clear(y, h)
		for _, r in rects do
			if r[1] < cx + width / 2 + 8 and r[3] > cx - width / 2 - 8 and r[2] < y + h + 8 and r[4] > y - 8 then return false end
		end
		return true
	end
	if clear(MOMENT_Y, MOMENT_H) then return MOMENT_Y, true end
	if clear(MOMENT_Y, MOMENT_SHORT) then return MOMENT_Y, false end
	local low = screen.H - MOMENT_LOW - MOMENT_H
	if low > MOMENT_H and clear(low, MOMENT_H) then return low, true end
	return MOMENT_Y, false
end

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
	-- (brief 30, HUD: ref_W45.0_next_goal_where.jpg at 720 px) "GOAL DONE!" gold (centred 33 under the top bar), the reward
	-- with its picture in white 63 px under it, "NEXT GOAL" gold 127 under, the next goal and where in white 177 under (it
	-- wraps like the tracker); no box, no band, the thick outlines carry it.
	local cashText = '+' .. Format.compact(type(info.Reward) == 'number' and info.Reward or 0) .. ' Cash'
	local nextPlain = info.NextText or ''
	local width = math.clamp(math.max(Kit.textWidth('GOAL DONE!', 26), Kit.textWidth(cashText, 28) + 50, 460) + 20, 340, MOMENT_W)
	local x = UDim.new(0.5, 0)
	if screen.Phone then
		local l, r = 300, screen.W - 330
		width = math.min(width, r - l)
		x = UDim.new(0, math.clamp(screen.W / 2, l + width / 2, r - width / 2))
	end
	local cx = x.Scale * screen.W + x.Offset
	local top, whole = momentPlace(cx, width)
	local holder = Kit.new('Frame', { Name = 'GoalDone', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x.Scale, x.Offset, 0, top), Size = px(width, MOMENT_H), Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local back = nil
	local function goldText(t)
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFB020')), Parent = t })
		return t
	end
	local title = goldText(Kit.text({ Name = 'Title', Text = 'GOAL DONE!', TextSize = 26, Stroke = BLACK, StrokeThickness = 4, Position = px(0, 0), Size = UDim2.new(1, 0, 0, 28), Parent = holder }))
	local rewardW = 46 + Kit.textWidth(cashText, 28)
	local rewardRow = Kit.new('Frame', { Name = 'RewardRow', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 14 + 63), Size = px(rewardW, 40), ZIndex = 2, Parent = holder })
	local cashIcon = Kit.icon3d('Cash', 44, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -6, 0.5, 0), ZIndex = 2 })
	cashIcon.Parent = rewardRow
	local reward = Kit.text({ Name = 'Reward', Text = cashText, TextSize = 28, Stroke = BLACK, StrokeThickness = 4, TextColor3 = Color.white, TextXAlignment = Enum.TextXAlignment.Left, Position = px(46, 0), Size = UDim2.new(1, -46, 1, 0), ZIndex = 2, Parent = rewardRow })
	local nextHead = goldText(Kit.text({ Name = 'NextHead', Text = 'NEXT GOAL', TextSize = 24, Stroke = BLACK, StrokeThickness = 3.5, Position = px(0, 127), Size = UDim2.new(1, 0, 0, 28), Parent = holder }))
	local nextLine = Kit.text({ Name = 'NextLine', Text = nextPlain, TextSize = 26, Stroke = BLACK, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 14 + 127 + 49), Size = px(460, 36), Parent = holder })
	nextLine.TextSize = Kit.fitSize(nextPlain, 26, 450, 14)
	for _, t in { nextHead, nextLine } do
		t.Visible = whole
		t.TextTransparency = 1
		t:FindFirstChildOfClass('UIStroke').Transparency = 1
	end
	-- Pad labels move with the camera: the moment keeps out of their way while it is up.
	local alive = true
	task.spawn(function()
		while alive and holder.Parent do
			task.wait(0.1)
			if not alive or not holder.Parent then break end
			local y, w2 = momentPlace(cx, width)
			nextLine.Visible, nextHead.Visible = w2, w2
			if math.abs(holder.Position.Y.Offset - y) > 1 then
				TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(x.Scale, x.Offset, 0, y) }):Play()
			end
		end
	end)
	Sound.play(chime, 1.5)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- A STAGE CLEARED or WAVE CLEARED banner arriving mid-moment takes the screen: this one steps aside at once and
	-- plays again, whole, once that banner is gone.
	local function interrupted() return busyUntil > os.clock() or fighting() or unboxing() end -- (LOOP: a fight starting too; brief 24: the unboxing moment)
	local function hold(t)
		local untilT = os.clock() + t
		while os.clock() < untilT do
			if interrupted() then return false end
			task.wait(0.05)
		end
		return true
	end
	local function stepAside()
		alive = false
		holder:Destroy()
		table.insert(queue, 1, info)
		holding = false
		momentUp(false)
		return false
	end
	if not hold(0.9) then return stepAside() end
	local show = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, t in { nextHead, nextLine } do
		TweenService:Create(t, show, { TextTransparency = 0 }):Play()
		TweenService:Create(t:FindFirstChildOfClass('UIStroke'), show, { Transparency = 0 }):Play()
	end
	Sound.play(chime, 1.2)
	if not hold(2.9) then return stepAside() end
	cashIcon.Visible = false
	alive = false
	fadeOut(holder, { title, reward, nextHead, nextLine }, back)
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
			local afterBox = false
			while busyUntil > os.clock() or fighting() or unboxing() do
				afterBox = afterBox or unboxing()
				task.wait(0.1)
			end
			if afterBox then settleUntil = math.max(settleUntil, os.clock() + 0.5) end
			while os.clock() < settleUntil or (os.clock() < settleUntil + 2 and calloutUp()) do task.wait(0.1) end
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
		-- (brief 23, STAGES / CRITIC3: a pad's big "+10 Cash" cash-out has the screen to itself too)
		if type(info) == 'table' and (info.Kind == 'StageClear' or info.Kind == 'CashOut') then busyUntil = math.max(busyUntil, os.clock() + 2.3) end
	end)
	Net.get('WaveState').OnClientEvent:Connect(function(info)
		if type(info) == 'table' and info.Kind == 'Cleared' then
			busyUntil = math.max(busyUntil, os.clock() + 2.3)
			clearUntil = os.clock() + 2.4
			paintTracker(false)
			task.delay(2.45, function() paintTracker(false) end)
		end
	end)
	-- (Shoes.client's unboxing moment owns the middle of the screen while PlayerGui Unboxing is on: brief 24, 3 to 5.5 s
	-- by rarity, shorter when tapped; this covers the moment between the remote and that attribute)
	local opened = Net.get('ShoeOpened')
	if opened then
		opened.OnClientEvent:Connect(function()
			busyUntil = math.max(busyUntil, os.clock() + 0.6)
			unboxUntil = os.clock() + 0.6 -- (r7, UICRITIC P2-5: the goal line steps away too)
			paintTracker(false)
			task.delay(0.65, function() paintTracker(false) end)
		end)
	end
end)

---------------------------------------------------------------------------------------------- layout
-- As wide as the HUD's hint line may be (clear of the left button column), sized to the goal's text.
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	local k = Spec.scaleFor(abs)
	local w = abs.X / k
	screen.W, screen.H, screen.Phone = w, abs.Y / k, math.min(abs.X, abs.Y) <= 500
	-- (brief 19 r7) Centred like the reference's second line and no wider than it, which keeps it clear of the Rewards gift
	-- (top right) and, on phones, of the counters' row at the top-left (x < 340).
	local phone = screen.Phone
	tracker.Size = px(math.max(300, math.min(TRACKER_W, w - 2 * (phone and 340 or 20))), TRACKER_H)
	tracker.Position = UDim2.new(0.5, 0, 0, TRACKER_Y)
	paintTracker(false)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
-- (brief 18) the goal line steps away while a window is open, like the reference's top lines and the HUD
local playerGui = player:WaitForChild('PlayerGui')
local function paintEnabled()
	local open, card = playerGui:GetAttribute('HoodWindow'), playerGui:GetAttribute('HoodCard')
	gui.Enabled = not ((type(open) == 'string' and open ~= '') or (type(card) == 'string' and card ~= ''))
end
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(paintEnabled)
playerGui:GetAttributeChangedSignal('HoodCard'):Connect(paintEnabled) -- (brief 30: and under a Retention card)
-- (brief 19 r7, UICRITIC P2-5) Shoes.client's unboxing moment owns the top of the screen while PlayerGui's Unboxing is on
playerGui:GetAttributeChangedSignal('Unboxing'):Connect(function()
	if playerGui:GetAttribute('Unboxing') ~= true then settleUntil = os.clock() + 0.5 end
	paintTracker(false)
end)
-- (CRITIC4 r1) Shoes.client's box chance board (PlayerGui BoxBoard) stands where the goal line is: it steps away too.
playerGui:GetAttributeChangedSignal('BoxBoard'):Connect(function() paintTracker(false) end)
gui.Parent = playerGui
relayout()
paintTracker(false)
