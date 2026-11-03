--!strict
-- Builds the MTL_Mission ScreenGui (Piece 3): mission tracker, hold prompt, aim meter, crew barks, alarm edges,
-- payout screen and the offer card. Used two ways, same as HUD/Phone/Job:
--   1. Edit time: tools/Install.lua saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: MissionController builds it only if PlayerGui has no MTL_Mission
-- MissionController finds things BY NAME. Keep these names when reskinning:
--   Tracker/Accent, Tracker/Body/{Kicker, Name, Steps, Timer}
--   Prompt (button)/{Key, Verb, Bar/Fill}      Meter/{Label, Bar/Fill}      AimButton
--   Bark/{Speaker, Line}      Alarm/{Top, Bottom, Left, Right}
--   Payout/{Dim, Card/{Kicker, Title, Rows, Total/{Label, Value}, XP, Note, Continue}}
--   Offer/{Dim, Card/{Kicker, Title, Sub, Tiles, Later}}
-- Runtime pieces (rows, tiles) come from Mission.stepRow / Mission.payoutRow / Mission.offerTile below.
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local M = Theme.Mission

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

local function stroke(t: number?, color: Color3?)
	return new("UIStroke", { Color = color or C.Stroke, Transparency = t or C.StrokeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke()
	return new("UIStroke", { Color = C.Shadow, Transparency = 0.5, Thickness = 1.5 })
end

local function pad(l: number, t: number?)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingRight = UDim.new(0, l),
		PaddingTop = UDim.new(0, t or l),
		PaddingBottom = UDim.new(0, t or l),
	})
end

local function list(gap: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

local function label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = C.Text,
		TextSize = 14,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base)
end

local function bar(name: string, parent: Instance, props: { [string]: any }, fillColor: Color3): Frame
	local b = new("Frame", {
		Name = name,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(UDim.new(1, 0)) })
	for k, v in props do
		(b :: any)[k] = v
	end
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = fillColor, BorderSizePixel = 0, Parent = b }, { corner(UDim.new(1, 0)) })
	return b
end

local function fullScreen(name: string, parent: Instance): Frame
	local f = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = parent })
	new("Frame", {
		Name = "Dim",
		-- reaches up under the Roblox top bar too (this screen keeps IgnoreGuiInset = false for the tracker)
		Position = UDim2.fromOffset(0, -80),
		Size = UDim2.new(1, 0, 1, 80),
		BackgroundColor3 = M.Dim,
		BackgroundTransparency = M.DimTransparency,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = f,
	})
	return f
end

local function card(parent: Instance, width: number): Frame
	return new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = M.Card,
		BackgroundTransparency = 0.04,
		ZIndex = 21,
		Parent = parent,
	}, { corner(UDim.new(0, 16)), stroke(0.85), pad(22, 20), list(10, false, Enum.HorizontalAlignment.Center), new("UIScale", { Name = "Pop" }) })
end

local function button(parent: Instance, name: string, text: string, primary: boolean, order: number): TextButton
	return new("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = if primary then C.Accent else M.Tile,
		BackgroundTransparency = if primary then 0 else 0.2,
		AutoButtonColor = true,
		FontFace = Theme.Fonts.Bold,
		Text = text,
		TextColor3 = if primary then C.Glass else C.TextDim,
		TextSize = 16,
		ZIndex = 22,
		Parent = parent,
	}, { corner(Theme.CornerSmall) })
end

local Mission = {}

function Mission.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Mission",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8, -- above the HUD (5) and job (6), below the phone (10). Payout/offer hide the phone.
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})

	-- tracker: top right, where the job panel sits (no shift can run during a mission)
	local tracker = new("Frame", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		Visible = false,
		Parent = gui,
	}, { corner(), stroke() })
	new("Frame", { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = M.Accent, BorderSizePixel = 0, Parent = tracker })
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = tracker,
	}, { pad(14, 12), list(6) })
	label({ Name = "Kicker", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), Text = "MISSION", FontFace = Theme.Fonts.Bold, TextColor3 = M.Accent, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	label({ Name = "MissionName", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), Text = "", FontFace = Theme.Fonts.Display, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	new("Frame", { Name = "Steps", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body }, { list(4) })
	label({ Name = "Timer", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), Text = "", FontFace = Theme.Fonts.Mono, TextColor3 = C.Gold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = body })

	-- hold prompt: bottom centre. It is also the touch/mouse button (press and hold).
	local prompt = new("TextButton", {
		Name = "Prompt",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(230, 58),
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { corner(UDim.new(0, 14)), stroke(0.8), new("UIScale", { Name = "Pop" }) })
	label({
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -4),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.Text,
		BackgroundTransparency = 0,
		Text = "E",
		FontFace = Theme.Fonts.Display,
		TextColor3 = C.Glass,
		TextSize = 18,
		Parent = prompt,
	}).Parent = prompt
	corner(Theme.CornerSmall).Parent = prompt.Key
	label({
		Name = "Verb",
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -66, 0, 26),
		Text = "Hold",
		FontFace = Theme.Fonts.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = prompt,
	})
	bar("Bar", prompt, { Position = UDim2.new(0, 56, 1, -16), Size = UDim2.new(1, -70, 0, 6) }, M.Meter)

	-- aim meter: just under the screen centre (the crosshair)
	local meter = new("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 46),
		Size = UDim2.fromOffset(220, 34),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	label({ Name = "Label", Size = UDim2.new(1, 0, 0, 16), Text = "AIM AT THE CLERK", FontFace = Theme.Fonts.Bold, TextSize = 13, TextColor3 = C.Text, Parent = meter }).Parent = meter
	textStroke().Parent = meter.Label
	bar("Bar", meter, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 7) }, M.Meter)

	-- touch only: the aim button (fallback aim when the Guns piece isn't installed)
	new("TextButton", {
		Name = "AimButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.62, 0),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Display,
		Text = "AIM",
		TextColor3 = C.Text,
		TextSize = 16,
		Visible = false,
		Parent = gui,
	}, { corner(UDim.new(1, 0)), stroke(0.6) })

	-- crew barks during play: bottom centre, above the prompt
	local bark = new("Frame", {
		Name = "Bark",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Glass,
		BackgroundTransparency = C.GlassTransparency,
		Visible = false,
		Parent = gui,
	}, { corner(UDim.new(1, 0)), stroke(), pad(16, 0), list(8, true) })
	bark.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	label({ Name = "Speaker", LayoutOrder = 1, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, FontFace = Theme.Fonts.Display, TextSize = 15, TextColor3 = M.Accent, Parent = bark })
	label({ Name = "Line", LayoutOrder = 2, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, FontFace = Theme.Fonts.Bold, TextSize = 15, Parent = bark })

	-- alarm: red pulsing screen edges while escaping
	local alarm = new("Frame", { Name = "Alarm", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 0, Parent = gui })
	local function edge(name: string, pos: UDim2, size: UDim2, rot: number)
		new("Frame", {
			Name = name,
			Position = pos,
			Size = size,
			BackgroundColor3 = M.Alarm,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = alarm,
		}, {
			new("UIGradient", {
				Rotation = rot,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	edge("Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), 90)
	edge("Bottom", UDim2.fromScale(0, 0.86), UDim2.fromScale(1, 0.14), -90)
	edge("Left", UDim2.fromScale(0, 0), UDim2.fromScale(0.1, 1), 0)
	edge("Right", UDim2.fromScale(0.9, 0), UDim2.fromScale(0.1, 1), 180)

	-- payout screen
	local payout = fullScreen("Payout", gui)
	local pc = card(payout, 380)
	label({ Name = "Kicker", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), Text = "JOB DONE", FontFace = Theme.Fonts.Bold, TextColor3 = M.Accent, TextSize = 13, ZIndex = 22, Parent = pc })
	label({ Name = "Title", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 34), Text = "Liberty Food Mart", FontFace = Theme.Fonts.Display, TextSize = 28, ZIndex = 22, Parent = pc })
	new("Frame", { Name = "Rows", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 22, Parent = pc }, { list(6) })
	local total = new("Frame", { Name = "Total", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, ZIndex = 22, Parent = pc })
	new("Frame", { Name = "Rule", Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Stroke, BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 22, Parent = total })
	label({ Name = "Label", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0.5, 0, 0, 40), Text = "YOU GOT", FontFace = Theme.Fonts.Bold, TextColor3 = C.TextDim, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = total })
	label({ Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.new(0.6, 0, 0, 44), Text = "$0", FontFace = Theme.Fonts.Display, TextColor3 = C.Accent, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = total })
	label({ Name = "XP", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 18), Text = "", FontFace = Theme.Fonts.Bold, TextColor3 = C.AccentAlt, TextSize = 15, ZIndex = 22, Parent = pc })
	label({ Name = "Note", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = C.TextDim, TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = pc })
	button(pc, "Continue", "CONTINUE", true, 7)

	-- offer card (dismissable, no timers)
	local offer = fullScreen("Offer", gui)
	local oc = card(offer, 460)
	label({ Name = "Kicker", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), Text = "LEVEL UP YOUR TAKE", FontFace = Theme.Fonts.Bold, TextColor3 = C.Gold, TextSize = 13, ZIndex = 22, Parent = oc })
	label({ Name = "Title", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), Text = "Double every dollar", FontFace = Theme.Fonts.Display, TextSize = 24, ZIndex = 22, Parent = oc })
	label({ Name = "Sub", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = C.TextDim, TextSize = 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = oc })
	new("Frame", { Name = "Tiles", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, ZIndex = 22, Parent = oc }, { list(12, true, Enum.HorizontalAlignment.Center) })
	button(oc, "Later", "Maybe later", false, 5)

	return gui
end

-- One checklist row in the tracker. state: "done" | "current" | "todo"
function Mission.stepRow(text: string, state: string): Frame
	local row = new("Frame", { Name = "Step", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 })
	local color = if state == "done" then M.Done elseif state == "current" then C.Text else M.Pending
	new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = if state == "current" then M.Accent else color,
		BackgroundTransparency = if state == "todo" then 0.6 else 0,
		Parent = row,
	}, { corner(UDim.new(1, 0)) })
	label({
		Name = "Text",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Text = if state == "done" then text .. "  ✓" else text,
		FontFace = if state == "current" then Theme.Fonts.Bold else Theme.Fonts.Body,
		TextColor3 = color,
		TextSize = 14,
		TextTransparency = if state == "done" then 0.25 else 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	return row
end

-- One line on the payout card: "Register take ........ $1,500"
function Mission.payoutRow(text: string, value: string, color: Color3?): Frame
	local row = new("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, ZIndex = 22 })
	label({ Name = "Label", Size = UDim2.new(0.6, 0, 1, 0), Text = text, TextColor3 = C.TextDim, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = row })
	label({ Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = value, FontFace = Theme.Fonts.Bold, TextColor3 = color or C.Text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22, Parent = row })
	return row
end

-- One offer tile: icon, title, sub, price button. The controller fills Price/Buy text.
function Mission.offerTile(title: string, sub: string, icon: string?): Frame
	local tile = new("Frame", {
		Name = "Tile",
		Size = UDim2.fromOffset(196, 150),
		BackgroundColor3 = M.Tile,
		ZIndex = 22,
	}, { corner(UDim.new(0, 12)), stroke(0.8, M.TileHighlight), pad(12, 12) })
	new("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = M.TileHighlight,
		BackgroundTransparency = if icon and icon ~= "rbxassetid://0" then 1 else 0,
		Image = if icon and icon ~= "rbxassetid://0" then icon else "",
		ZIndex = 22,
		Parent = tile,
	}, { corner(UDim.new(0, 8)) })
	label({ Name = "Title", Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 22), Text = title, FontFace = Theme.Fonts.Display, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = tile })
	label({ Name = "Sub", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), Text = sub, TextColor3 = C.TextDim, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = tile })
	new("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = M.TileHighlight,
		AutoButtonColor = true,
		FontFace = Theme.Fonts.Bold,
		Text = "...",
		TextColor3 = C.Glass,
		TextSize = 15,
		ZIndex = 23,
		Parent = tile,
	}, { corner(Theme.CornerSmall) })
	return tile
end

return Mission
