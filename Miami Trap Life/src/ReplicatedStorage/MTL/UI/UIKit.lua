--!strict
-- Themeable widgets for code-built screens (phone apps first; any menu can use them).
-- Everything reads colours/fonts from PhoneLook (the phone's look, matched to the HUD palette), so a reskin there
-- reskins every app.
-- Widgets are named (Header, Row, Button, Toggle...) so controllers and Alex can find them.
local Theme = require(script.Parent.PhoneLook) :: any
local Motion = require(script.Parent.Motion)
local Avatars = require(script.Parent.Avatars)

local C = Theme.Colors
local P = Theme.Phone

local UIKit = {}

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = UIKit.new

function UIKit.corner(r: UDim?): UICorner
	return new("UICorner", { CornerRadius = r or Theme.Corner })
end

function UIKit.stroke(transparency: number?, color: Color3?): UIStroke
	return new("UIStroke", {
		Color = color or C.Stroke,
		Transparency = transparency or C.StrokeTransparency,
		Thickness = C.StrokeThickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(all: number, top: number?, bottom: number?): UIPadding
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all),
		PaddingBottom = UDim.new(0, bottom or top or all),
	})
end

function UIKit.list(gap: number?, horizontal: boolean?): UIListLayout
	return new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Small press feedback for any button: darken on hover, shrink a touch on press.
function UIKit.feedback(button: GuiButton, base: Color3, hover: Color3?)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Motion.tween(button, Motion.Fast, { BackgroundColor3 = hover or base:Lerp(Color3.new(1, 1, 1), 0.08) })
	end)
	button.MouseLeave:Connect(function()
		Motion.tween(button, Motion.Fast, { BackgroundColor3 = base })
		Motion.tween(scale, Motion.Fast, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Motion.tween(scale, Motion.Fast, { Scale = 0.97 })
	end)
	button.MouseButton1Up:Connect(function()
		Motion.tween(scale, Motion.Fast, { Scale = 1 })
	end)
end

export type LabelOpts = { size: number?, dim: boolean?, bold: boolean?, wrap: boolean?, color: Color3?, align: Enum.TextXAlignment?, order: number?, name: string? }

function UIKit.label(parent: Instance, text: string, o: LabelOpts?): TextLabel
	local opts: LabelOpts = o or {}
	local size = opts.size or 14
	return new("TextLabel", {
		Name = opts.name or "Label",
		LayoutOrder = opts.order or 0,
		Size = UDim2.new(1, 0, 0, size + 6),
		AutomaticSize = if opts.wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		FontFace = if opts.bold then Theme.Fonts.Bold else Theme.Fonts.Body,
		Text = text,
		TextColor3 = opts.color or (if opts.dim then C.TextDim else C.Text),
		TextSize = size,
		TextWrapped = opts.wrap == true,
		TextTruncate = if opts.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		TextXAlignment = opts.align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

-- App header: [< Back]  Title  [right slot]. onBack nil = no back button.
function UIKit.header(parent: Instance, title: string, onBack: (() -> ())?): Frame
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -120, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = title,
		TextColor3 = C.Text,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	if onBack then
		local back = new("TextButton", {
			Name = "Back",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(64, 32),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Display,
			Text = "‹ Back",
			TextColor3 = C.TextDim,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		})
		back.Activated:Connect(onBack)
	end
	new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(64, 32),
		BackgroundTransparency = 1,
		Parent = header,
	})
	return header
end

-- Vertical scroll list that fills `parent` below an optional header (top px).
function UIKit.scroll(parent: Instance, top: number?, name: string?): ScrollingFrame
	local sf = new("ScrollingFrame", {
		Name = name or "List",
		Position = UDim2.fromOffset(0, top or 0),
		Size = UDim2.new(1, 0, 1, -(top or 0)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.TextDim,
		Parent = parent,
	}, { UIKit.list(6), UIKit.padding(10, 4, 16) })
	return sf
end

export type RowOpts = {
	title: string,
	sub: string?,
	right: string?,
	rightColor: Color3?,
	dot: Color3?, -- small dot on the left (unread, missed)
	glyph: string?, -- avatar letter
	contact: string?, -- a Story contact id: shows their face (UI/Avatars) instead of the letter
	glyphColor: Color3?,
	order: number?,
	onClick: (() -> ())?,
	name: string?,
}

-- A tappable list row: (avatar) Title / sub ............ right
function UIKit.row(parent: Instance, o: RowOpts): TextButton
	local row = new("TextButton", {
		Name = o.name or "Row",
		LayoutOrder = o.order or 0,
		Size = UDim2.new(1, 0, 0, if o.sub then 56 else 44),
		BackgroundColor3 = P.Card,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { UIKit.corner(Theme.CornerSmall) })
	local left = 12
	if o.dot then
		new("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = o.dot,
			BorderSizePixel = 0,
			Parent = row,
		})
		left = 18
	end
	if o.contact then
		Avatars.make(row, o.contact, 36, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, left, 0.5, 0) })
		left += 46
	elseif o.glyph then
		local av = new("TextLabel", {
			Name = "Avatar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, left, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = o.glyphColor or C.AccentAlt,
			FontFace = Theme.Fonts.Display,
			Text = o.glyph,
			TextColor3 = C.Text,
			TextSize = 15,
			Parent = row,
		}, { UIKit.corner(UDim.new(1, 0)) })
		left += av.Size.X.Offset + 10
	end
	local rightW = if o.right then 70 else 0
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(left, if o.sub then 9 else 0),
		Size = UDim2.new(1, -(left + rightW + 10), 0, if o.sub then 20 else 44),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = o.title,
		TextColor3 = C.Text,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	if o.sub then
		new("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(left, 29),
			Size = UDim2.new(1, -(left + rightW + 10), 0, 18),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Body,
			Text = o.sub,
			TextColor3 = C.TextDim,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	if o.right then
		new("TextLabel", {
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(rightW, 20),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Body,
			Text = o.right,
			TextColor3 = o.rightColor or C.TextDim,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
	UIKit.feedback(row, P.Card, P.CardHover)
	if o.onClick then
		row.Activated:Connect(o.onClick)
	end
	return row
end

export type ButtonOpts = { style: string?, order: number?, height: number?, onClick: (() -> ())?, name: string?, disabled: boolean? }

-- Full-width button. style: "primary" (accent), "secondary" (card), "danger".
function UIKit.button(parent: Instance, text: string, o: ButtonOpts?): TextButton
	local opts: ButtonOpts = o or {}
	local style = opts.style or "primary"
	local bg = if style == "primary" then C.Accent elseif style == "danger" then C.Danger else P.Card
	local fg = C.Text
	local btn = new("TextButton", {
		Name = opts.name or "Button",
		LayoutOrder = opts.order or 0,
		Size = UDim2.new(1, 0, 0, opts.height or 42),
		BackgroundColor3 = bg,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Display,
		Text = string.upper(text),
		TextColor3 = fg,
		TextSize = 16,
		Parent = parent,
	}, { UIKit.corner(Theme.CornerSmall) })
	if opts.disabled then
		btn.BackgroundTransparency = 0.6
		btn.TextTransparency = 0.4
		btn.Active = false
		btn.AutoButtonColor = false
	else
		UIKit.feedback(btn, bg)
		if opts.onClick then
			btn.Activated:Connect(opts.onClick)
		end
	end
	return btn
end

-- Label + switch. onChange(newValue) is called on tap; call `set(value)` on the returned table to update it.
function UIKit.toggle(parent: Instance, text: string, value: boolean, onChange: (boolean) -> (), order: number?)
	local row = new("TextButton", {
		Name = "Toggle",
		LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = P.Card,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, { UIKit.corner(Theme.CornerSmall) })
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = text,
		TextColor3 = C.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = C.AccentAlt,
		Parent = row,
	}, { UIKit.corner(UDim.new(1, 0)) })
	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = C.Text,
		Parent = track,
	}, { UIKit.corner(UDim.new(1, 0)) })
	local state = value
	local api = {}
	function api.set(v: boolean)
		state = v
		Motion.tween(track, Motion.Fast, { BackgroundColor3 = if v then C.Accent else C.AccentAlt })
		Motion.tween(knob, Motion.Fast, { Position = if v then UDim2.new(1, -22, 0.5, 0) else UDim2.new(0, 2, 0.5, 0) })
	end
	api.instance = row
	api.set(value)
	row.Activated:Connect(function()
		api.set(not state)
		onChange(state)
	end)
	return api
end

function UIKit.section(parent: Instance, text: string, order: number?): TextLabel
	local l = UIKit.label(parent, string.upper(text), { size = 13, dim = true, bold = true, order = order, name = "Section" })
	l.FontFace = Theme.Fonts.Display
	l.Size = UDim2.new(1, 0, 0, 26)
	l.TextYAlignment = Enum.TextYAlignment.Bottom
	return l
end

-- Centered grey text for empty lists.
function UIKit.empty(parent: Instance, text: string, order: number?): TextLabel
	local l = UIKit.label(parent, text, { dim = true, wrap = true, align = Enum.TextXAlignment.Center, order = order, name = "Empty" })
	l.Size = UDim2.new(1, 0, 0, 60)
	l.TextYAlignment = Enum.TextYAlignment.Center
	return l
end

-- A card frame with padding and a vertical list inside (for job cards, info blocks).
function UIKit.card(parent: Instance, order: number?, name: string?): Frame
	return new("Frame", {
		Name = name or "Card",
		LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = P.Card,
		Parent = parent,
	}, { UIKit.corner(Theme.Corner), UIKit.stroke(), UIKit.padding(12), UIKit.list(4) })
end

-- Red count bubble at the top-right of `parent`. n <= 0 hides it. Returns the label.
function UIKit.badge(parent: Instance, n: number): TextLabel
	local b = parent:FindFirstChild("Badge") :: TextLabel?
	if not b then
		b = new("TextLabel", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(20, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = P.Badge,
			FontFace = Theme.Fonts.Display,
			TextColor3 = C.Text,
			TextSize = 12,
			ZIndex = 5,
			Parent = parent,
		}, { UIKit.corner(UDim.new(1, 0)), new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }) })
	end
	assert(b)
	b.Visible = n > 0
	b.Text = if n > 99 then "99+" else tostring(n)
	return b
end

return UIKit
