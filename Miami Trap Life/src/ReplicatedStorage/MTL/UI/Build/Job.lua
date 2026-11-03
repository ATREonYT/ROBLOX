--!strict
-- Builds the MTL_Job ScreenGui (Piece 2): the job panel, the task minigames, the shift/check-in card and the
-- reward fly-ups. Used two ways, same as HUD/Phone:
--   1. Edit time: tools/Install.lua saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: JobController builds it only if PlayerGui has no MTL_Job
-- JobController finds things BY NAME. Keep these names when reskinning:
--   Panel/Accent, Panel/Body/{JobTitle, Task, Steps, Progress/Fill, ProgressText, Status, Hint, Action}
--   Minigame/{Title, Close, ActionButton, Hold/Bar/Fill, Hold/Percent, Timing/Track/Zone, Timing/Track/Needle,
--             Timing/Pips, Sequence/Ticket, Sequence/Buttons}
--   Card/{Title, Body, Primary, Secondary}    Flash    Fly
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local J = Theme.Job

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

local function corner(r: UDim?)
	return new("UICorner", { CornerRadius = r or Theme.Corner })
end

local function stroke(t: number?)
	return new("UIStroke", { Color = C.Stroke, Transparency = t or C.StrokeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function pad(n: number)
	return new("UIPadding", { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n), PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n) })
end

local function text(name: string, props: { [string]: any }): TextLabel
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = C.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end

local function button(name: string, label: string, primary: boolean, props: { [string]: any }?): TextButton
	local base: { [string]: any } = {
		Name = name,
		AutoButtonColor = true,
		BackgroundColor3 = if primary then C.Accent else Theme.Phone.Card,
		FontFace = Theme.Fonts.Bold,
		Text = label,
		TextColor3 = if primary then C.Glass else C.Text,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 38),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return new("TextButton", base, { corner(Theme.CornerSmall) })
end

local Build = {}

function Build.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Job",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6, -- above the HUD (5), below the phone (10)
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, -- same space as MTL_HUD (fly-ups land on its cash label)
	})

	-- job panel: top-right, under the cash/level block
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		Visible = false,
		Parent = gui,
	}, { corner(), stroke() })
	new("Frame", {
		Name = "Accent", -- strip on the left edge: green on shift, grey off, red when leaving
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(0, 3, 1, -20),
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Parent = panel,
	}, { corner(UDim.new(1, 0)) })
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = panel,
	}, { pad(12), new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	panel = body -- the rows below go inside Body
	text("JobTitle", { LayoutOrder = 1, Text = "STOCKER  ·  LIBERTY FOOD MART", TextColor3 = C.TextDim, TextSize = 11, FontFace = Theme.Fonts.Bold, Parent = panel })
	text("Task", {
		LayoutOrder = 2,
		Text = "Grab a box from the stockroom",
		FontFace = Theme.Fonts.Bold,
		TextSize = 17,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = panel,
	})
	text("Steps", { LayoutOrder = 3, Text = "Step 1 of 2", TextColor3 = J.Marker, TextSize = 12, FontFace = Theme.Fonts.Bold, Parent = panel })
	new("Frame", {
		Name = "Progress",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = J.Track,
		BorderSizePixel = 0,
		Parent = panel,
	}, {
		corner(UDim.new(1, 0)),
		new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0 }, { corner(UDim.new(1, 0)) }),
	})
	text("ProgressText", { LayoutOrder = 5, Text = "Shift 0 / 8  ·  $0", TextColor3 = C.TextDim, TextSize = 12, Parent = panel })
	text("Status", { LayoutOrder = 6, Text = "", TextColor3 = C.Gold, TextSize = 13, FontFace = Theme.Fonts.Bold, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = panel })
	text("Hint", { LayoutOrder = 7, Text = "", TextColor3 = C.TextDim, TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = panel })
	button("Action", "Clock in", true, { LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 32), TextSize = 13, Visible = false, Parent = panel })

	-- minigame: bottom centre (clear of the thumbstick and the jump button on phones)
	local mg = new("Frame", {
		Name = "Minigame",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		Visible = false,
		Parent = gui,
	}, {
		corner(),
		stroke(),
		pad(14),
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		new("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge) }),
		new("UIScale", { Name = "Scale" }),
	})
	text("Title", { LayoutOrder = 1, Text = "MOPPING", FontFace = Theme.Fonts.Display, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 26), Parent = mg })
	button("Close", "X", false, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -4),
		Size = UDim2.fromOffset(28, 28),
		TextSize = 13,
		BackgroundTransparency = 0.4,
		Parent = mg,
	})

	-- hold
	local hold = new("Frame", { Name = "Hold", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Visible = false, Parent = mg })
	new("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = J.Track, BorderSizePixel = 0, Parent = hold }, {
		corner(UDim.new(1, 0)),
		new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0 }, { corner(UDim.new(1, 0)) }),
	})
	text("Percent", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 14), Text = "", TextSize = 11, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = hold })

	-- timing
	local timing = new("Frame", { Name = "Timing", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Visible = false, Parent = mg })
	local track = new("Frame", { Name = "Track", Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = J.Track, BorderSizePixel = 0, ClipsDescendants = false, Parent = timing }, { corner(UDim.new(0, 6)) })
	new("Frame", { Name = "Zone", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.22, 1), BackgroundColor3 = J.Zone, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = track }, { corner(UDim.new(0, 6)) })
	new("Frame", { Name = "Needle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1, 10), BackgroundColor3 = J.Needle, BorderSizePixel = 0, ZIndex = 3, Parent = track }, { corner(UDim.new(1, 0)) })
	new("Frame", { Name = "Pips", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = timing }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
	})

	-- sequence
	local seq = new("Frame", { Name = "Sequence", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = mg }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	new("Frame", { Name = "Ticket", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(245, 240, 225), Parent = seq }, {
		corner(Theme.CornerSmall),
		pad(8),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	new("Frame", { Name = "Buttons", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = seq }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.333, -6, 0, 40), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	button("ActionButton", "HOLD  [E]", true, { LayoutOrder = 9, Size = UDim2.new(0.6, 0, 0, 46), TextSize = 17, Parent = mg })

	-- centre card: shift complete / check in
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	}, {
		corner(),
		stroke(),
		pad(16),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIScale", { Name = "Scale" }),
	})
	text("Title", { LayoutOrder = 1, Text = "SHIFT COMPLETE", FontFace = Theme.Fonts.Display, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 26), Parent = card })
	text("Body", { LayoutOrder = 2, Text = "", TextColor3 = C.TextDim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	button("Primary", "Next shift", true, { LayoutOrder = 3, Parent = card })
	button("Secondary", "Clock out", false, { LayoutOrder = 4, Parent = card })

	-- big centre word after a task (PERFECT / SLOPPY)
	text("Flash", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(400, 40),
		Text = "",
		FontFace = Theme.Fonts.Display,
		TextSize = 34,
		TextColor3 = J.Perfect,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = gui,
	})
	gui.Flash:SetAttribute("Note", "PERFECT / SLOPPY pop")
	new("UIStroke", { Color = C.Shadow, Transparency = 0.4, Thickness = 2, Parent = gui.Flash })

	-- reward fly-ups (+$8 from the shelf to the cash counter)
	new("Frame", { Name = "Fly", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })

	return gui
end

return Build
