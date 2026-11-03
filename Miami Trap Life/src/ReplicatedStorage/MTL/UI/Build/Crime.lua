--!strict
-- Builds the MTL_Crime ScreenGui: heat stars, the dirty-cash pill, the crime tracker card, the wash bar, the aim ring,
-- Marcus's shop, the BOOKED card and a black fade for doors. Same two uses as HUD/Dropped:
--   1. Edit time: saved into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: CrimeController builds it only if PlayerGui has no MTL_Crime
-- CrimeController finds things BY NAME. Keep these names when reskinning:
--   Side/Heat/Star1..3, Side/Heat/Lose/Fill, Side/Dirty/Amount, Run/Title, Run/Sub, Run/Bar/Fill,
--   Wash/Title, Wash/Sub, Wash/Bar/Fill, Wash/Cancel, Aim/Ring/Fill, Aim/Text, Booked/Title, Booked/Sub, Booked/Bar/Fill,
--   Shop/List, Shop/Fence, Shop/Close, Shop/Cash, Fade
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local DIRTY = Color3.fromRGB(150, 200, 90) -- a sicker green than clean money
local STAR = Color3.fromRGB(255, 205, 80)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function glass(props: { [string]: any }, radius: UDim?): any
	props.BackgroundColor3 = props.BackgroundColor3 or C.Glass
	props.BackgroundTransparency = props.BackgroundTransparency or C.GlassTransparency
	local f = new(props.ClassName or "Frame", props)
	new("UICorner", { CornerRadius = radius or UDim.new(0, 12), Parent = f })
	new("UIStroke", { Color = C.Stroke, Transparency = C.StrokeTransparency, Thickness = 1, Parent = f })
	return f
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.Text
	props.FontFace = props.FontFace or Theme.Fonts.Bold
	props.TextSize = props.TextSize or 16
	return new("TextLabel", props)
end

local function bar(parent: Instance, y: number, color: Color3, height: number?): Frame
	local b = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.new(1, -32, 0, height or 6),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = b,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return b
end

local Crime = {}

function Crime.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Crime",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 12, -- over the HUD (10), under the phone and cutscenes
	})

	-- right side, under the cash/XP block: heat stars + dirty cash
	local side = new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 112),
		Size = UDim2.fromOffset(170, 80),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIScale", { Name = "Scale" }),
	})
	-- five wanted stars (Config/Crime.Heat.Max), filled from the right like the classic GTA row
	local STARS = 5
	local heat = new("Frame", { Name = "Heat", LayoutOrder = 1, Size = UDim2.fromOffset(160, 40), BackgroundTransparency = 1, Visible = false, Parent = side })
	for i = 1, STARS do
		label({
			Name = "Star" .. i,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(STARS - i) * 31, 0, 0),
			Size = UDim2.fromOffset(30, 30),
			Text = "★",
			TextSize = 28,
			FontFace = Theme.Fonts.Display,
			TextColor3 = STAR,
			TextTransparency = 0.75,
			TextStrokeTransparency = 0.4,
			Parent = heat,
		})
	end
	local lose = new("Frame", {
		Name = "Lose",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 34),
		Size = UDim2.new(1, -8, 0, 4),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.45,
		Parent = heat,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 170, 255), Parent = lose }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local dirty = glass({ Name = "Dirty", LayoutOrder = 2, Size = UDim2.fromOffset(150, 32), Visible = false, Parent = side }, UDim.new(1, 0))
	label({
		Name = "Tag",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 50, 1, 0),
		Text = "DIRTY",
		TextSize = 12,
		TextColor3 = DIRTY,
		FontFace = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dirty,
	})
	label({
		Name = "Amount",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = "$0",
		TextSize = 18,
		TextColor3 = DIRTY,
		FontFace = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = dirty,
	})

	-- the crime tracker (bottom centre, over the hotbar)
	local run = glass({
		Name = "Run",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(320, 66),
		Visible = false,
		Parent = gui,
	})
	new("UIScale", { Name = "Scale", Parent = run })
	label({ Name = "Title", Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -32, 0, 20), Text = "STICKUP", TextSize = 15, FontFace = Theme.Fonts.Display, TextColor3 = Color3.fromRGB(255, 120, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = run })
	label({ Name = "Sub", Position = UDim2.fromOffset(16, 29), Size = UDim2.new(1, -32, 0, 18), Text = "", TextSize = 14, FontFace = Theme.Fonts.Body, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = run })
	bar(run, 52, DIRTY, 5)

	-- washing at the back counter
	local wash = glass({
		Name = "Wash",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(340, 92),
		Visible = false,
		Parent = gui,
	})
	label({ Name = "Title", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 22), Text = "WASHING $0", TextSize = 18, FontFace = Theme.Fonts.Display, TextColor3 = DIRTY, TextXAlignment = Enum.TextXAlignment.Left, Parent = wash })
	label({ Name = "Sub", Position = UDim2.fromOffset(16, 33), Size = UDim2.new(1, -32, 0, 18), Text = "", TextSize = 14, FontFace = Theme.Fonts.Body, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = wash })
	bar(wash, 58, C.Accent, 8)
	local cancel = new("TextButton", {
		Name = "Cancel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(64, 24),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.5,
		Text = "Stop",
		TextColor3 = C.TextDim,
		FontFace = Theme.Fonts.Bold,
		TextSize = 13,
		AutoButtonColor = true,
		Parent = wash,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local _ = cancel

	-- aim ring (holding a clerk at gunpoint)
	local aim = new("Frame", {
		Name = "Aim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(280, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	label({ Name = "Text", Size = UDim2.new(1, 0, 0, 22), Text = "HANDS WHERE I CAN SEE THEM", TextSize = 16, FontFace = Theme.Fonts.Display, TextStrokeTransparency = 0.5, Parent = aim })
	local ring = new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.new(0.8, 0, 0, 6),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.4,
		Parent = aim,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Danger, Parent = ring }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- Marcus's back-door shop
	local shop = glass({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 430),
		Visible = false,
		Parent = gui,
	}, UDim.new(0, 16))
	new("UIScale", { Name = "Scale", Parent = shop })
	label({ Name = "Title", Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -90, 0, 28), Text = "MARCUS", TextSize = 24, FontFace = Theme.Fonts.Display, TextXAlignment = Enum.TextXAlignment.Left, Parent = shop })
	label({ Name = "Sub", Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 18), Text = "Back door, Cash 4 Gold. Clean cash for tools.", TextSize = 13, FontFace = Theme.Fonts.Body, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = shop })
	label({ Name = "Cash", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 20), Size = UDim2.fromOffset(120, 22), Text = "$0", TextSize = 16, FontFace = Theme.Fonts.Display, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = shop })
	new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.5,
		Text = "✕",
		TextColor3 = C.Text,
		FontFace = Theme.Fonts.Bold,
		TextSize = 16,
		Parent = shop,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", {
		Name = "List",
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 0, 280),
		BackgroundTransparency = 1,
		Parent = shop,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("TextButton", {
		Name = "Fence",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -32, 0, 46),
		BackgroundColor3 = DIRTY,
		Text = "Nothing to fence",
		TextColor3 = Color3.fromRGB(16, 24, 12),
		FontFace = Theme.Fonts.Display,
		TextSize = 17,
		AutoButtonColor = true,
		Parent = shop,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 12) }) })

	-- BOOKED
	local booked = new("CanvasGroup", {
		Name = "Booked",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(380, 130),
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = 0.1,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIStroke", { Color = Color3.fromRGB(120, 170, 255), Transparency = 0.5, Thickness = 1 }),
	})
	label({ Name = "Title", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), Text = "BOOKED", TextSize = 40, FontFace = Theme.Fonts.Display, TextColor3 = Color3.fromRGB(120, 170, 255), Parent = booked })
	label({ Name = "Sub", Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 40), Text = "", TextSize = 15, FontFace = Theme.Fonts.Body, TextColor3 = C.TextDim, TextWrapped = true, Parent = booked })
	bar(booked, 110, Color3.fromRGB(120, 170, 255), 4)

	-- door fade
	new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	return gui
end

return Crime
