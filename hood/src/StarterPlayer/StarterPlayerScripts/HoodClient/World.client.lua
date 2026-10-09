-- The World window (brief 22, UI4): the HUD's World square opens it (PlayerGui.HoodWorld.Open, a BindableEvent; a
-- second tap closes it). The inventory's look (Shared/InventoryKit: a studded header with the globe, the title and the
-- red X over the dark see-through studded body), smaller:
--   World 1   "The Block": two trips, Lobby (the hall's spawn) and your furthest stage ("Stage n": just past the furthest
--             stage gate you have cleared), the same places the LOBBY and FURTHEST pads send you. The server checks
--             every trip (HoodServer/TravelService -> StageService's pad teleport, StageRules.travelTarget).
--   Worlds 2-5  locked cards, "Coming soon".
-- Reads StagesCleared (StageService). Sets PlayerGui `HoodWindow` = 'World' while open (one window at a time).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local IK = require(Shared.InventoryKit)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px = UDim2.fromOffset
local hex = Kit.hex
local label = IK.label
local blank = IK.blank

local WW, WH = 760, 478
local gui, root, fitRoot = Kit.screen('HoodWorld', nil, 8)
IK.fullScreen(gui)
local openEvent = Instance.new('BindableEvent')
openEvent.Name = 'Open'
openEvent.Parent = gui

local W = IK.frame(root, { Name = 'World', Title = 'World', Icon = { 'World', 'Rewards' }, Tone = 'world', Search = false, Tabs = false, Index = false, Bar = false, Width = WW, Height = WH, FitW = WW, FitH = WH, FitX = 0 })
W.Overlay.Visible = false
local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = W.Overlay })
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = W.Pop })
local content = W.Content

-- Answers ("Clear Stage 1 first", "coming soon") just over the window.
local sayLabel = label({ Name = 'Say', Text = '', TextSize = 26, StrokeThickness = 3.5, TextColor3 = hex('5AE0FF'), AnchorPoint = Vector2.new(0.5, 1), Position = px(WW / 2, -8), Size = px(WW, 34), ZIndex = 40, Parent = W.Pop })
local saying = 0
local function say(text)
	saying += 1
	local mine = saying
	sayLabel.Text = text
	Motion.pop(sayLabel, 0.12)
	task.delay(3, function() if mine == saying then sayLabel.Text = '' end end)
end

local isOpen = false
local function close()
	if not isOpen then return end
	isOpen = false
	Motion.blur('World', false)
	IK.coverPlayerList('World', false)
	Motion.close(W.Overlay, W.Pop)
	if playerGui:GetAttribute('HoodWindow') == 'World' then playerGui:SetAttribute('HoodWindow', '') end
end

---------------------------------------------------------------------------------------------- World 1
local CARD = { X = 24, Y = 104, W = WW - 48, H = 150 }
local card = IK.block({ Name = 'World1', Tone = 'tabOn', Width = CARD.W, Height = CARD.H, Outline = 4.5, RimWidth = 3, StudShade = 0.7, Position = px(CARD.X, CARD.Y), ZIndex = 26 })
card.Parent = content
local globe = IK.icon({ 'World', 'Rewards' }, 132, { ZIndex = 30 })
globe.AnchorPoint = Vector2.new(0, 0.5)
globe.Position = px(-14, CARD.H / 2 - 6)
globe.Parent = card.Body
label({ Name = 'Title', Text = 'World 1', TextSize = 40, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(126, 22), Size = px(240, 46), ZIndex = 31, Parent = card.Body })
local sub = label({ Name = 'Name', Text = IK.WorldNames[1], TextSize = 24, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(128, 70), Size = px(240, 30), ZIndex = 31, Parent = card.Body })
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFF27A'), hex('FFA81A')), Parent = sub })
label({ Name = 'You', Text = "You're here", TextSize = 18, StrokeThickness = 2.5, TextColor3 = hex('7CFF4F'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(128, 102), Size = px(240, 24), ZIndex = 31, Parent = card.Body })

local tripButtons = {}
local function travel(trip)
	if not trip.Open then
		say('Clear Stage 1 first!')
		return
	end
	Net.get('Travel'):FireServer(trip.Target, 1)
	close()
end
local function paintTrips()
	for _, b in tripButtons do b:Destroy() end
	table.clear(tripButtons)
	local info = IK.worlds(player:GetAttribute('StagesCleared'))[1]
	for i, trip in info.Trips do
		-- (UICRITIC2 r1: the family's "go" buttons are studded green with a black outline, never grey)
		local holder = Kit.blockButton({
			Name = trip.Target, Tone = 'grass', Width = 176, Height = 68, Text = trip.Text, TextSize = 30, Outline = 4, RimWidth = 3, Studs = IK.Layout.StudPitch, StudPattern = 'recessed',
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(16 + (2 - i) * 192), 0.5, -8), ZIndex = 31,
		})
		holder.Parent = card.Body
		label({ Name = 'Caption', Text = i == 1 and 'Spawn' or 'Best stage', TextSize = 17, StrokeThickness = 2.5, TextColor3 = hex('E8FBFF'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = px(176, 22), ZIndex = 33, Parent = holder })
		Motion.button(holder, function() travel(trip) end)
		table.insert(tripButtons, holder)
	end
end

---------------------------------------------------------------------------------------------- worlds 2-5
IK.titleLine(content, 'More Worlds', 296, { Width = WW, ZIndex = 26, TextSize = 26 })
local LOCK = { W = 164, H = 150, Y = 318 }
local gap = (CARD.W - 4 * LOCK.W) / 3
-- A padlock: a grey shackle (a ring's top) over a gold body with a keyhole, black-outlined like everything else.
local function padlock(parent, x, y)
	local shackle = blank({ Name = 'Shackle', AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y - 14), Size = px(30, 34), ZIndex = 32, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = shackle
	Kit.stroke(hex('D9D4CC'), 7, true).Parent = shackle
	local lockBody = blank({ Name = 'Lock', BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y + 6), Size = px(46, 36), ZIndex = 33, Parent = parent })
	Kit.corner(6).Parent = lockBody
	Kit.stroke(Kit.Color.black, 3, true).Parent = lockBody
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFE76A'), hex('FFA20C')), Parent = lockBody })
	blank({ Name = 'Hole', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.black, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(6, 14), ZIndex = 34, Parent = lockBody })
end
for _, w in IK.worlds(0) do
	if w.World >= 2 then
		local i = w.World - 1
		local c = IK.block({ Name = 'World' .. w.World, Tone = 'locked', Width = LOCK.W, Height = LOCK.H, Outline = 4.5, RimWidth = 3, StudShade = 0.5, Position = px(CARD.X + (i - 1) * (LOCK.W + gap), LOCK.Y), ZIndex = 26 })
		c.Parent = content
		padlock(c.Body, LOCK.W / 2 - 4.5, 38)
		label({ Name = 'Title', Text = 'World ' .. w.World, TextSize = 26, StrokeThickness = 3.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = px(LOCK.W, 30), ZIndex = 31, Parent = c.Body })
		label({ Name = 'Name', Text = w.Name, TextSize = 17, StrokeThickness = 2.5, TextColor3 = hex('C8D0DC'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = px(LOCK.W - 10, 22), ZIndex = 31, Parent = c.Body })
		local soon = label({ Name = 'Soon', Text = 'Coming soon', TextSize = 18, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = px(LOCK.W, 22), ZIndex = 31, Parent = c.Body })
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFF27A'), hex('FFA81A')), Parent = soon })
		local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36, Parent = c })
		hit.Activated:Connect(function()
			Motion.pop(c, 0.06)
			say('Coming soon!')
		end)
	end
end

---------------------------------------------------------------------------------------------- open / close
local function open()
	if isOpen then
		close()
		return
	end
	isOpen = true
	paintTrips()
	playerGui:SetAttribute('HoodWindow', 'World')
	Motion.blur('World', true)
	IK.coverPlayerList('World', true)
	Motion.open(W.Overlay, W.Pop, 1)
end
openEvent.Event:Connect(open)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= 'World' then close() end
end)
player:GetAttributeChangedSignal('StagesCleared'):Connect(function()
	if isOpen then paintTrips() end
end)
backdrop.Activated:Connect(close)
Motion.button(W.CloseButton, close)

local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fitRoot(abs)
	IK.fit(W, abs)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
paintTrips()
