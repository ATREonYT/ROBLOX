--!strict
-- +1 Chess Evolution: the duel screen, laid out like the reference tapping duel (Nov 8).
-- Bottom centre: a green (you) / red (rival) tug bar with a dark knob at the split, the two names
-- above its ends and "Click Fast!" under it. Mid screen: the 3-2-1-GO countdown.
-- The place keeps a saved copy in StarterGui (src/StarterGui/DuelBar.rbxm) so Alex can see and
-- edit it in Studio; ChessClient reuses that copy and only calls Build when it is missing.
local DuelBar = {}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local INK = Color3.fromRGB(22, 22, 28)

local function stroke(parent: Instance, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, color: Color3, size: UDim2, pos: UDim2, anchor: Vector2, align: Enum.TextXAlignment): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.TextXAlignment = align
	t.Size = size
	t.Position = pos
	t.AnchorPoint = anchor
	stroke(t, 3)
	t.Parent = parent
	return t
end

function DuelBar.Build(parent: Instance?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "DuelBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- the tug bar: 54.6% of the screen wide, its top at 75% of the height (measured on the reference)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.75)
	bar.Size = UDim2.fromScale(0.546, 0.078)
	bar.BackgroundColor3 = Color3.fromRGB(236, 72, 72)
	bar.BorderSizePixel = 0
	corner(bar, 6)
	stroke(bar, 4)
	bar.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(900, 64)
	size.MinSize = Vector2.new(260, 30)
	size.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundColor3 = Color3.fromRGB(86, 226, 62)
	fill.BorderSizePixel = 0
	corner(fill, 6)
	fill.Parent = bar

	-- a soft light band over both colours (the reference bar is glossy and studded)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Size = UDim2.fromScale(1, 0.45)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.78
	gloss.BorderSizePixel = 0
	gloss.ZIndex = 2
	corner(gloss, 6)
	gloss.Parent = bar

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.new(0, 16, 1, 10)
	knob.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	corner(knob, 4)
	stroke(knob, 2)
	knob.Parent = bar
	local knobScale = Instance.new("UIScale")
	knobScale.Name = "Pop"
	knobScale.Parent = knob

	label(bar, "You", "@you", Color3.new(1, 1, 1), UDim2.fromScale(0.5, 0.78), UDim2.new(0, 2, 0, -4), Vector2.new(0, 1), Enum.TextXAlignment.Left)
	label(bar, "Rival", "Rival", Color3.fromRGB(255, 70, 70), UDim2.fromScale(0.5, 0.78), UDim2.new(1, -2, 0, -4), Vector2.new(1, 1), Enum.TextXAlignment.Right)

	-- "Click Fast!" with a clicking cursor (Roblox's own cursor picture plus three yellow click lines)
	local hint = Instance.new("Frame")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0.845)
	hint.Size = UDim2.fromScale(0.32, 0.062)
	hint.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = hint
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.LayoutOrder = 1
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Parent = hint
	local cursor = Instance.new("ImageLabel")
	cursor.Name = "Cursor"
	cursor.BackgroundTransparency = 1
	cursor.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
	cursor.Size = UDim2.fromScale(1.15, 1.15)
	cursor.Position = UDim2.fromScale(0.2, 0.12)
	cursor.ZIndex = 2
	cursor.Parent = icon
	for i, a in { -150, -110, -70 } do
		local ray = Instance.new("Frame")
		ray.Name = "Ray" .. i
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.BackgroundColor3 = Color3.fromRGB(255, 205, 50)
		ray.BorderSizePixel = 0
		ray.Size = UDim2.fromScale(0.3, 0.09)
		local r = math.rad(a)
		ray.Position = UDim2.fromScale(0.3 + math.cos(r) * 0.32, 0.3 + math.sin(r) * 0.32)
		ray.Rotation = a
		corner(ray, 3)
		ray.Parent = icon
	end
	local iconScale = Instance.new("UIScale")
	iconScale.Name = "Pop"
	iconScale.Parent = icon
	local text = label(hint, "Text", "Click Fast!", Color3.new(1, 1, 1), UDim2.fromScale(0.62, 1), UDim2.new(), Vector2.new(), Enum.TextXAlignment.Left)
	text.LayoutOrder = 2
	text.AutomaticSize = Enum.AutomaticSize.None

	-- the countdown between the two players: gold digits, then a green GO!
	local count = label(gui, "Count", "3", Color3.fromRGB(255, 206, 52), UDim2.fromScale(0.16, 0.1), UDim2.fromScale(0.5, 0.4), Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
	count.Visible = false
	local grad = Instance.new("UIGradient")
	grad.Name = "Shade"
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
	grad.Parent = count
	local countScale = Instance.new("UIScale")
	countScale.Name = "Pop"
	countScale.Parent = count

	gui.Parent = parent
	return gui
end

return DuelBar
