-- The goal chain on your screen (the soldier game's "GOAL DONE! ... / NEXT GOAL: ... - where to go"). The server
-- decides (GoalService, Shared/GoalRules); this shows it.
--   Tracker: one line at the top centre, under the HUD's hint: "NEXT GOAL: Clear Stage 1's targets - in the side
--     yard past the door", with the Cash it pays in a green chip. It reads the attributes GoalStep, GoalText,
--     GoalWhere and GoalReward the server keeps on you.
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

local gui, root, fit = Kit.screen('HoodGoals', nil, 7)

---------------------------------------------------------------------------------------------- tracker
-- (brief 18) The reference's second timer line ("Next RAID in: 3:26  [SKIP]", user_26): no box, white Gotham Black
-- with a black stroke and the key words in colour; the Cash the goal pays in a chip like its SKIP button (see-through
-- teal, a dark teal edge). One line, like the video's "NEXT GOAL: Hatch an egg - Eggs are in the lobby".
local BLACK = Color.black
local GREEN = '#5CE08A' -- the reference's "DOCTOR DOOM" green
local LINE_SIZE, CHIP_W, CHIP_H = 25, 84, 30 -- (r7: the reference's second line, cap 26 ref px = text 25 design px)
local TRACKER_Y = 2 -- (the line's centre on the reference's second line, measured at its size)
-- (brief 19 r7, UICRITIC P2-1) centred and no wider than the reference's line (~620 ref px with its chip = 420 design px)
local TRACKER_W = 420
local PREFIX = 'Goal: ' -- (as short as the reference's "Next RAID in:")
local tracker = Kit.new('Frame', { Name = 'Goal', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TRACKER_Y), Size = px(TRACKER_W, 36), BackgroundTransparency = 1, Visible = false, Parent = root })
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
-- (brief 19 r7) Like the reference's "Next RAID in: 3:26", only the key word is in colour: the name in the goal (from its
-- first capitalised word after the verb: "Stand in BAY 1", "Get the Pump Shotgun"), else its last word ("Buy a gun").
local function keyed(text)
	local words = string.split(tostring(text), ' ')
	local at
	for i = 2, #words do
		if words[i]:match('^[%u%d]') then at = i break end
	end
	if #words == 1 then at = 1 end
	at = at or #words
	local head = table.concat(words, ' ', 1, at - 1)
	local key = table.concat(words, ' ', at)
	return (head ~= '' and escape(head) .. ' ' or '') .. '<font color="' .. GREEN .. '">' .. escape(key) .. '</font>'
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
		tracker.Visible = not holding and not fighting() and not unboxing() and not boardUp() and os.clock() - allDoneAt < 12
		if tracker.Visible then task.delay(12.5, function() paintTracker(false) end) end
		return
	end
	allDoneAt = nil
	local whereText = (type(where) == 'string' and where ~= '') and (' - ' .. where) or ''
	-- (brief 19) one short line like the reference's "Next RAID in: 3:26": where to go only when it fits at 21 px or more
	-- (the GOAL DONE moment and the Quest window always say it)
	local room = tracker.Size.X.Offset - CHIP_W - 14
	if whereText ~= '' and Kit.fitSize(PREFIX .. text .. whereText, LINE_SIZE, room, 8) < 21 then whereText = '' end
	line.Text = PREFIX .. keyed(text) .. escape(whereText)
	place(PREFIX .. text .. whereText, true)
	chipText.Text = '+' .. Format.compact(reward)
	chipText.TextSize = Kit.fitSize(chipText.Text, 20, CHIP_W - 30, 10)
	chip.Visible = true
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
local MOMENT_Y, MOMENT_W, MOMENT_H, MOMENT_SHORT, MOMENT_LOW = 2, 640, 96, 64, 184
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
		local k = Kit.scaleFor(gui.AbsoluteSize)
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
	local cashText = '+' .. Format.compact(type(info.Reward) == 'number' and info.Reward or 0) .. ' Cash'
	local nextPlain = 'NEXT GOAL: ' .. (info.NextText or '') .. ((info.NextWhere or '') ~= '' and (' - ' .. info.NextWhere) or '')
	local widest = math.max(Kit.textWidth('GOAL DONE!', 30), Kit.textWidth(cashText, 24) + 34, Kit.textWidth(nextPlain, 22))
	local width = math.clamp(widest + 48, 340, MOMENT_W)
	-- (brief 19) on phones it keeps clear of the button column (left) and the Rewards gift (top right); (brief 23) and of the
	-- HUD's counters row at the top left (Rebirths and Cash side by side, x < 340), like the goal line
	local x = UDim.new(0.5, 0)
	if screen.Phone then
		local l, r = 340, screen.W - 370
		width = math.min(width, r - l)
		x = UDim.new(0, math.clamp(screen.W / 2, l + width / 2, r - width / 2))
	end
	local cx = x.Scale * screen.W + x.Offset
	local top, whole = momentPlace(cx, width)
	local holder = Kit.new('Frame', { Name = 'GoalDone', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x.Scale, x.Offset, 0, top), Size = px(width, MOMENT_H), Parent = root })
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	-- (brief 19 r7, UICRITIC P2-4) the video's look: "GOAL DONE!" gold on the scene, then ONE dark band that fades out at
	-- both ends holding the reward (the Cash icon and "+20 Cash" in white), then NEXT GOAL and the next line on the scene.
	-- No card behind it all; the thick strokes keep it readable over anything. (brief 23: tighter, 96 px in all, and the
	-- NEXT GOAL line is one line: "NEXT GOAL: Step on the yellow pad - by the gate")
	local back = Kit.new('Frame', { Name = 'Back', BackgroundColor3 = Kit.hex('0E1020'), BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = px(0, 33), Size = UDim2.new(1, 0, 0, 31), ZIndex = 0, Parent = holder })
	Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0), NumberSequenceKeypoint.new(0.78, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = back })
	local function goldText(t)
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFB020')), Parent = t })
		return t
	end
	local title = goldText(Kit.text({ Name = 'Title', Text = 'GOAL DONE!', TextSize = 30, Stroke = BLACK, StrokeThickness = 4, Position = px(0, 0), Size = UDim2.new(1, 0, 0, 33), Parent = holder }))
	local rewardW = 32 + Kit.textWidth(cashText, 24)
	local rewardRow = Kit.new('Frame', { Name = 'RewardRow', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 33), Size = px(rewardW, 31), ZIndex = 2, Parent = holder })
	local cashIcon = Kit.icon3d('Cash', 32, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -4, 0.5, 0), ZIndex = 2 })
	cashIcon.Parent = rewardRow
	local reward = Kit.text({ Name = 'Reward', Text = cashText, TextSize = 24, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = Color.white, TextXAlignment = Enum.TextXAlignment.Left, Position = px(32, 0), Size = UDim2.new(1, -32, 1, 0), ZIndex = 2, Parent = rewardRow })
	-- (the gold "NEXT GOAL:" and the goal on one line, where to go after it)
	local nextLine = Kit.text({ Name = 'NextLine', Text = '<font color="#FFD84A">NEXT GOAL:</font> ' .. escape(info.NextText or '') .. ((info.NextWhere or '') ~= '' and (' - ' .. escape(info.NextWhere)) or ''), TextSize = 22, Stroke = BLACK, StrokeThickness = 3.5, RichText = true, Position = px(10, 67), Size = UDim2.new(1, -20, 0, 28), Parent = holder })
	nextLine.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 22, MinTextSize = 12, Parent = nextLine })
	nextLine.Visible = whole
	nextLine.TextTransparency = 1
	nextLine:FindFirstChildOfClass('UIStroke').Transparency = 1
	-- Pad labels move with the camera: the moment keeps out of their way while it is up.
	local alive = true
	task.spawn(function()
		while alive and holder.Parent do
			task.wait(0.1)
			if not alive or not holder.Parent then break end
			local y, w2 = momentPlace(cx, width)
			nextLine.Visible = w2
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
	TweenService:Create(nextLine, show, { TextTransparency = 0 }):Play()
	TweenService:Create(nextLine:FindFirstChildOfClass('UIStroke'), show, { Transparency = 0 }):Play()
	Sound.play(chime, 1.2)
	if not hold(2.9) then return stepAside() end
	cashIcon.Visible = false
	alive = false
	fadeOut(holder, { title, reward, nextLine }, back)
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
	local k = Kit.scaleFor(abs)
	local w = abs.X / k
	screen.W, screen.H, screen.Phone = w, abs.Y / k, math.min(abs.X, abs.Y) <= 500
	-- (brief 19 r7) Centred like the reference's second line and no wider than it, which keeps it clear of the Rewards gift
	-- (top right) and, on phones, of the counters' row at the top-left (x < 340).
	local phone = screen.Phone
	tracker.Size = px(math.max(300, math.min(TRACKER_W, w - 2 * (phone and 340 or 20))), 36)
	tracker.Position = UDim2.new(0.5, 0, 0, TRACKER_Y)
	paintTracker(false)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
-- (brief 18) the goal line steps away while a window is open, like the reference's top lines and the HUD
local playerGui = player:WaitForChild('PlayerGui')
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local open = playerGui:GetAttribute('HoodWindow')
	gui.Enabled = not (type(open) == 'string' and open ~= '')
end)
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
