-- The OPTIONAL "Hot Target" corner game (brief 29, P4). The user: "the grinding at ranges dont force it, make it optional because
-- people might start calling us out for trying to make them addicted". So:
--   * It is closed on every join and stays closed until the player opens it: one small, quiet round button at the bottom right.
--     The button never pulses, glows, badges or counts anything, and nothing here ever pops up on its own.
--   * Open, it is a small corner panel (never a full window, the world keeps running and the ranges keep shooting): a 3x3 grid
--     with one glowing cell; tap it for a small bonus, and the glow moves on. Miss it, ignore it, close it: nothing is lost.
--     No streak, no combo, no timer to beat, no daily anything, no sounds. The bonus is capped hard by the server
--     (Shared/HotTargetRules: 20 a minute, 2 shots' worth each), and it only counts while you train in an open range.
--   * One honest product hook: the timed "2x bonus" (player attribute HotTargetBoostEnds, set by HoodServer/HotTarget.grantBoost). The
--     panel shows its chip only while it runs; there is no buy button here until the store wires its product.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Kit = require(RS.Shared.UIKit)
local Net = require(RS.Shared.Net)
local Rules = require(RS.Shared.HotTargetRules)
local ShotRules = require(RS.Shared.ShotRules)
local Format = require(RS.Shared.Format)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px, hex, BLACK = UDim2.fromOffset, Kit.hex, Kit.Color.black
local gui, root, fit = Kit.screen('HoodHotTarget', nil, 5)

---------------------------------------------------------------------------------------------- the button
local BTN = 52
local button = Kit.new('TextButton', { Name = 'Open', Text = '', AutoButtonColor = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = px(BTN, BTN), BackgroundColor3 = hex('20243A'), BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 3, Parent = root })
Kit.corner(BTN / 2).Parent = button
Kit.stroke(hex('6C7396'), 2.5, true).Parent = button
-- a drawn target: three rings and a dot, flat
for i, d in { 36, 24, 12 } do
	local ring = Kit.new('Frame', { Name = 'Ring' .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(d, d), BackgroundColor3 = i == 3 and hex('FF5A4A') or hex('20243A'), BackgroundTransparency = i == 3 and 0 or 1, BorderSizePixel = 0, ZIndex = 4, Parent = button })
	Kit.corner(d / 2).Parent = ring
	if i < 3 then Kit.stroke(hex('E8ECFA'), 2.5, true).Parent = ring end
end

---------------------------------------------------------------------------------------------- the panel
local PW, PH, CELL, GAP = 220, 236, 48, 6
local panel = Kit.new('Frame', { Name = 'Panel', AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -72), Size = px(PW, PH), BackgroundColor3 = hex('14161F'), BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, ZIndex = 6, Parent = root })
Kit.corner(12).Parent = panel
Kit.stroke(hex('5A5F70'), 2, true).Parent = panel
Kit.text({ Name = 'Title', Text = 'Hot Target', TextSize = 24, Stroke = BLACK, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(14, 8), Size = px(160, 30), ZIndex = 7, Parent = panel })
Kit.text({ Name = 'Note', Text = 'Optional. Tap the glow for a bonus.', TextSize = 13, Stroke = BLACK, StrokeThickness = 2, TextColor3 = hex('B8BEC8'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(14, 36), Size = px(PW - 28, 18), ZIndex = 7, Parent = panel })
local closeBtn = Kit.new('TextButton', { Name = 'Close', Text = 'X', FontFace = Kit.Font.display, TextSize = 18, TextColor3 = Kit.Color.white, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = px(PW - 8, 8), Size = px(28, 28), BackgroundColor3 = hex('3A3F58'), BorderSizePixel = 0, ZIndex = 8, Parent = panel })
Kit.corner(6).Parent = closeBtn
local grid = Kit.new('Frame', { Name = 'Grid', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = px(PW / 2, 58), Size = px(3 * CELL + 2 * GAP, 3 * CELL + 2 * GAP), ZIndex = 7, Parent = panel })
local cells = {}
for i = 1, Rules.Cells do
	local col, row = (i - 1) % 3, (i - 1) // 3
	local cell = Kit.new('TextButton', { Name = 'Cell' .. i, Text = '', AutoButtonColor = false, Position = px(col * (CELL + GAP), row * (CELL + GAP)), Size = px(CELL, CELL), BackgroundColor3 = hex('2A2F48'), BorderSizePixel = 0, ZIndex = 8, Parent = grid })
	Kit.corner(8).Parent = cell
	local edge = Kit.stroke(hex('3F4566'), 2, true)
	edge.Parent = cell
	cells[i] = { Button = cell, Edge = edge }
end
local status = Kit.text({ Name = 'Status', Text = '', TextSize = 14, Stroke = BLACK, StrokeThickness = 2, TextColor3 = hex('E8ECFA'), Position = px(8, 204), Size = px(PW - 16, 16), ZIndex = 7, Parent = panel })
local chip = Kit.text({ Name = 'Boost', Text = '', TextSize = 14, Stroke = BLACK, StrokeThickness = 2, TextColor3 = hex('FFD21F'), Position = px(8, 218), Size = px(PW - 16, 16), ZIndex = 7, Parent = panel })

---------------------------------------------------------------------------------------------- the game
local hot, glowAt, left = 1, 0, Rules.PerMinute
local rng = Random.new()
local open = false
local function inLane() return ShotRules.counts(player:GetAttribute('TrainingStation')) end
local function paint()
	local live = open and inLane() and left > 0
	for i, c in cells do
		local hotNow = live and i == hot
		c.Button.BackgroundColor3 = hotNow and hex('FF9A1F') or hex('2A2F48')
		c.Edge.Color = hotNow and hex('FFE29A') or hex('3F4566')
		c.Edge.Thickness = hotNow and 3 or 2
	end
	status.Text = (not inLane()) and 'Stand in a range to play' or left <= 0 and 'Enough for now. Your gun keeps shooting!' or ''
	local ends = player:GetAttribute('HotTargetBoostEnds')
	local secs = type(ends) == 'number' and ends - os.time() or 0
	chip.Text = secs > 0 and string.format('2x bonus  %d:%02d', secs // 60, secs % 60) or ''
end
local function moveGlow()
	local nextCell = hot
	while nextCell == hot do nextCell = rng:NextInteger(1, Rules.Cells) end
	hot, glowAt = nextCell, os.clock()
	paint()
end
local function float(cell, text)
	local l = Kit.text({ Name = 'Gain', Text = text, TextSize = 20, Stroke = BLACK, StrokeThickness = 3, TextColor3 = hex('FFF27A'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(CELL, 24), ZIndex = 12, Parent = cell })
	TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, -0.2), TextTransparency = 1 }):Play()
	local st = l:FindFirstChildOfClass('UIStroke')
	if st then TweenService:Create(st, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
	task.delay(0.65, function() l:Destroy() end)
end
for i, c in cells do
	c.Button.Activated:Connect(function()
		if not (open and inLane() and left > 0) then return end
		if i ~= hot then return end -- (a wrong tap costs nothing and does nothing)
		pcall(function() Net.get('HotTarget'):FireServer() end)
		moveGlow()
	end)
end
Net.get('HotTarget').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' then return end
	if type(info.Left) == 'number' then left = info.Left end
	if type(info.Gain) == 'number' and info.Gain > 0 then float(cells[hot].Button, '+' .. Format.compact(info.Gain)) end
	paint()
end)
-- the glow moves on by itself now and then, so ignoring it never "loses" anything (no timer to beat)
task.spawn(function()
	while true do
		task.wait(0.4)
		if open then
			if os.clock() - glowAt >= Rules.GlowSeconds then moveGlow() else paint() end
			left = math.min(Rules.PerMinute, left + (left < Rules.PerMinute and 0.1 or 0)) -- (the cap's minute refills as it passes)
		end
	end
end)

local function setOpen(on)
	open = on
	panel.Visible = on
	if on then moveGlow() end
end
button.Activated:Connect(function() setOpen(not open) end)
closeBtn.Activated:Connect(function() setOpen(false) end)
-- a window (Shop, Items ...) covers the corner: the panel steps aside while one is open
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	local w = playerGui:GetAttribute('HoodWindow')
	gui.Enabled = not (type(w) == 'string' and w ~= '') and playerGui:GetAttribute('Unboxing') ~= true
end)
gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)
gui:SetAttribute('Open', false)
gui:GetAttributeChangedSignal('Open'):Connect(function() setOpen(gui:GetAttribute('Open') == true) end) -- (for the checks and previews)
