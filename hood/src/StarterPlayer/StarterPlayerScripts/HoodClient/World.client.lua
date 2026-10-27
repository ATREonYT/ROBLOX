-- The World window (brief 22, UI4): the HUD's World square opens it (PlayerGui.HoodWorld.Open, a BindableEvent; a
-- second tap closes it). (Oct 27) The owner's UI mockup look (Shared/InventoryKit: the yellow header bar with the globe
-- breaking out, the title and the red square X over the dark navy body), smaller:
--   This world (World 1 The Hood or World 2 Business District, Config/Worlds): two trips, StageRules.Trips (brief 23): Lobby
--             (the hall's spawn) and Stage 1 (just inside the Stage 1 gate: start a run). Both end the run you are on.
--             The server checks every trip (HoodServer/TravelService -> StageService's teleport, StageRules.travelTarget).
--   Other Worlds  the other world's card: what opens it, or "Coming soon" until its place is in the experience.
-- Sets PlayerGui `HoodWindow` = 'World' while open (one window at a time).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local IK = require(Shared.InventoryKit)
local StageRules = require(Shared.StageRules)
local WorldInfo = require(Shared.WorldInfo)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local px = UDim2.fromOffset
local hex = Kit.hex
local label = IK.label
local blank = IK.blank

local WW, WH = 760, 478
local HERE = WorldInfo.current() -- (Oct 27: the world this server is; its card is the top one)
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

-- Answers ("coming soon") just over the window.
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

---------------------------------------------------------------------------------------------- this world
local CARD = { X = 24, Y = 104, W = WW - 48, H = 150 }
local card = IK.block({ Name = 'Here', Tone = 'tabOn', Width = CARD.W, Height = CARD.H, Outline = 4.5, OutlineColor = Kit.Skin.outline, Radius = 12, RimWidth = 3, Studs = false, Position = px(CARD.X, CARD.Y), ZIndex = 26 })
card.Parent = content
local globe = IK.icon({ 'World', 'Rewards' }, 132, { ZIndex = 30 })
globe.AnchorPoint = Vector2.new(0, 0.5)
globe.Position = px(-14, CARD.H / 2 - 6)
globe.Parent = card.Body
label({ Name = 'Title', Text = 'World ' .. HERE, TextSize = 40, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(126, 22), Size = px(240, 46), ZIndex = 31, Parent = card.Body })
local sub = label({ Name = 'Name', Text = IK.WorldNames[HERE] or '', TextSize = 24, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(128, 70), Size = px(240, 30), ZIndex = 31, Parent = card.Body })
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFF27A'), hex('FFA81A')), Parent = sub })
-- (Oct 27: World 2 is the "Business District", longer than its slot at 24: it shrinks to fit, short of the trip buttons)
sub.TextScaled = true
Kit.new('UITextSizeConstraint', { MaxTextSize = 24, Parent = sub })
label({ Name = 'You', Text = "You're here", TextSize = 18, StrokeThickness = 2.5, TextColor3 = hex('7CFF4F'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(128, 102), Size = px(240, 24), ZIndex = 31, Parent = card.Body })

-- The trips: one green button each (the same for everyone; the server checks every trip).
for i, trip in StageRules.Trips do
	-- (UICRITIC2 r1: the family's "go" buttons are studded green with a black outline, never grey)
	local holder = Kit.blockButton({
		Name = trip.Target, Tone = 'grass', Width = 176, Height = 68, Text = trip.Text, TextSize = 30, Outline = 4, RimWidth = 3, Studs = IK.Layout.StudPitch, StudPattern = 'recessed',
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(16 + (#StageRules.Trips - i) * 192), 0.5, -8), ZIndex = 31,
	})
	holder.Parent = card.Body
	label({ Name = 'Caption', Text = trip.Caption, TextSize = 18, StrokeThickness = 2.5, TextColor3 = hex('E8FBFF'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = px(176, 22), ZIndex = 33, Parent = holder })
	Motion.button(holder, function()
		Net.get('Travel'):FireServer(trip.Target, 1)
		close()
	end)
end

---------------------------------------------------------------------------------------------- the other worlds
-- (Oct 27) The game's other worlds (Config/Worlds through IK.worlds: World 2 Business District from World 1, World 1 The Hood from
-- Business District) as the mockup's world tiles: the name on a bar across the top, then what opens it. Travel is the lobby's
-- door (HoodServer/WorldPortalService, which checks it); this card only says how, honestly: "Coming soon" until the
-- world's place is in the experience, a padlock and "Beat the final boss" while it is locked.
IK.titleLine(content, 'Other Worlds', 296, { Width = WW, ZIndex = 26, TextSize = 26 })
local OTHER = { Y = 318, H = 150, Gap = 16 }
-- A padlock: a grey shackle (a ring's top) over a gold body with a keyhole, outlined like everything else.
local function padlock(parent, x, y)
	local shackle = blank({ Name = 'Shackle', AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y - 14), Size = px(30, 34), ZIndex = 32, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = shackle
	Kit.stroke(hex('D9D4CC'), 7, true).Parent = shackle
	local lockBody = blank({ Name = 'Lock', BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y + 6), Size = px(46, 36), ZIndex = 33, Parent = parent })
	Kit.corner(6).Parent = lockBody
	Kit.stroke(Kit.Skin.outline, 3, true).Parent = lockBody
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFE76A'), hex('FFA20C')), Parent = lockBody })
	blank({ Name = 'Hole', BackgroundTransparency = 0, BackgroundColor3 = Kit.Skin.outline, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(6, 14), ZIndex = 34, Parent = lockBody })
end
local others = {}
for _, w in IK.worlds() do
	if w.World ~= HERE then table.insert(others, w) end
end
local OW = math.floor((CARD.W - math.max(0, #others - 1) * OTHER.Gap) / math.max(1, #others))
for k, w in others do
	local locked = not w.Open and w.Need ~= nil and w.Need.World == HERE
	local c = IK.block({ Name = 'World' .. w.World, Tone = locked and 'locked' or 'lobby', Width = OW, Height = OTHER.H, Outline = 4.5, OutlineColor = Kit.Skin.outline, Radius = 12, RimWidth = 3, Studs = false, Position = px(CARD.X + (k - 1) * (OW + OTHER.Gap), OTHER.Y), ZIndex = 26 })
	c.Parent = content
	-- the name bar across the top (the mockup's world tiles)
	local bar = blank({ Name = 'NameBar', BackgroundTransparency = 0.35, BackgroundColor3 = Kit.Skin.well, Size = UDim2.new(1, 0, 0, 44), ZIndex = 29, Parent = c.Body })
	Kit.corner(9).Parent = bar
	label({ Name = 'Title', Text = 'World ' .. w.World .. ': ' .. w.Name, TextSize = 28, StrokeThickness = 3.5, Size = UDim2.fromScale(1, 1), ZIndex = 31, Parent = bar })
	local line
	if not w.Live then
		line = 'Coming soon'
	elseif locked then
		line = 'Beat the final boss to open it'
	else
		line = 'Take the door in the lobby'
	end
	local x0 = 20
	if locked or not w.Live then
		padlock(c.Body, 48, 92)
		x0 = 92
	end
	local say1 = label({ Name = 'Soon', Text = line, TextSize = 24, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(x0, 64), Size = UDim2.new(1, -x0 - 12, 0, 30), ZIndex = 31, Parent = c.Body })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFF27A'), hex('FFA81A')), Parent = say1 })
	if locked and w.Need then
		label({ Name = 'Need', Text = 'Opens after World ' .. w.Need.World .. ', Stage ' .. w.Need.Stage, TextSize = 19, StrokeThickness = 2.5, TextColor3 = hex('C8D0E8'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(x0, 98), Size = UDim2.new(1, -x0 - 12, 0, 24), ZIndex = 31, Parent = c.Body })
	end
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36, Parent = c })
	hit.Activated:Connect(function()
		Motion.pop(c, 0.06)
		say(line .. '!')
	end)
end

---------------------------------------------------------------------------------------------- open / close
local function open()
	if isOpen then
		close()
		return
	end
	isOpen = true
	playerGui:SetAttribute('HoodWindow', 'World')
	Motion.blur('World', true)
	IK.coverPlayerList('World', true)
	Motion.open(W.Overlay, W.Pop, 1)
end
openEvent.Event:Connect(open)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= 'World' then close() end
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
