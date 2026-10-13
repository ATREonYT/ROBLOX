-- The shared component set every screen is built from (one window, header, tab, button, pill, toggle and slider
-- style), so all 18 pages stay consistent. Sizes are reference px (see Theme.lua).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

local C = Theme.Colors
local Kit = {}

-- Instance helper: Kit.new("Frame", { Size = ..., Parent = ... }, { children }). Parent is set last.
function Kit.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	local parent
	for k, v in props or {} do
		if k == "Parent" then parent = v else (inst :: any)[k] = v end
	end
	for _, child in children or {} do child.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end
local new = Kit.new

function Kit.corner(r: number?) return new("UICorner", { CornerRadius = UDim.new(0, r or Theme.Corner) }) end
function Kit.stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", { Color = color or C.Border, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function Kit.pad(l: number, r: number?, t: number?, b: number?)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l), PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l) })
end
function Kit.list(dir: Enum.FillDirection, padding: number, h: Enum.HorizontalAlignment?, v: Enum.VerticalAlignment?)
	return new("UIListLayout", { FillDirection = dir, Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = h or Enum.HorizontalAlignment.Left, VerticalAlignment = v or Enum.VerticalAlignment.Top })
end

function Kit.text(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1, FontFace = Theme.Fonts.Body, TextColor3 = C.Text, TextSize = Theme.Text.Blurb,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true,
	}
	for k, v in props do p[k] = v end
	return new("TextLabel", p)
end

-- A window heading (SHOP, DANCES): Montserrat Black with a thin dark outline.
function Kit.title(props: { [string]: any }): TextLabel
	props.FontFace = props.FontFace or Theme.Fonts.Heading
	props.TextSize = props.TextSize or Theme.Text.Title
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Color = C.Ink, Thickness = props.TextSize >= 24 and 1.8 or 1.2, Parent = l })
	return l
end

-- A character name or product title: Montserrat Bold, no outline.
function Kit.name(props: { [string]: any }): TextLabel
	props.FontFace = props.FontFace or Theme.Fonts.Name
	props.TextWrapped = false
	return Kit.text(props)
end

-- An icon from Config/Assets. Blank until its image is imported (the "Icon" attribute names it for the preview).
-- "Avatar" shows the local player's avatar (Roblox thumbnail, no upload needed).
function Kit.icon(name: string, props: { [string]: any }?): ImageLabel
	local p: { [string]: any } = { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = Assets.icon(name) }
	if name == "Avatar" then
		local id = Players.LocalPlayer and Players.LocalPlayer.UserId or 1
		p.Image = string.format("rbxthumb://type=AvatarBust&id=%d&w=420&h=420", math.max(id, 1))
	end
	for k, v in props or {} do p[k] = v end
	local img = new("ImageLabel", p)
	img:SetAttribute("Icon", name)
	return img
end

local function lighten(c: Color3, a: number) return c:Lerp(Color3.new(1, 1, 1), a) end
local function darken(c: Color3, a: number) return c:Lerp(Color3.new(0, 0, 0), a) end
local function style(fill: Color3, text: Color3) return { Idle = fill, Hover = lighten(fill, 0.10), Pressed = darken(fill, 0.10), Text = text } end
Kit.Styles = {
	Action = { Idle = C.Action, Hover = C.ActionHover, Pressed = C.ActionPressed, Text = C.Text },
	Disabled = { Idle = C.Disabled, Hover = C.Disabled, Pressed = C.Disabled, Text = C.Text },
	Selected = style(C.SelectedTab, C.DarkText),
	Tab = style(C.InactiveTab, C.Text),
	Close = style(C.Close, C.Text),
	Gift = style(C.Gift, C.Text),
	Plus = style(C.Plus, C.Text),
	Row = style(C.Row, C.Text),
}

export type Button = {
	Instance: TextButton,
	setStyle: (string) -> (),
	setText: (string) -> (),
	setEnabled: (boolean) -> (),
	onClick: ((() -> ()) -> ()),
}

-- A button. props: Text, Style (Kit.Styles key), Size, Position, AnchorPoint, Parent, Name, TextSize, FontFace,
-- Icon (left of the text), IconSize, LayoutOrder. Clicks are ignored while disabled.
function Kit.button(props: { [string]: any }): Button
	local styleName = props.Style or "Action"
	local btn: TextButton = new("TextButton", {
		Name = props.Name or "Button", Size = props.Size, Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0,
		AutoButtonColor = false, BorderSizePixel = 0, Text = "", BackgroundColor3 = Kit.Styles[styleName].Idle,
		Selectable = true, ZIndex = props.ZIndex or 1,
	}, { Kit.corner(props.Corner) })
	local label = Kit.text({
		Name = "Label", Text = props.Text or "", FontFace = props.FontFace or Theme.Fonts.Button,
		TextSize = props.TextSize or Theme.Text.Button, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Kit.Styles[styleName].Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false, LayoutOrder = 2, ZIndex = btn.ZIndex,
	})
	new("UIStroke", { Name = "Outline", Color = C.Ink, Thickness = 1, Transparency = 0.6, Parent = label }) -- minimal outline
	local row = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = btn.ZIndex },
		{ Kit.list(Enum.FillDirection.Horizontal, props.Gap or 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center), label })
	row.Parent = btn
	if props.Icon then
		local s = props.IconSize or 22
		Kit.icon(props.Icon, { Name = "Icon", Size = UDim2.fromOffset(s, s), LayoutOrder = props.IconAfter and 3 or 1, ZIndex = btn.ZIndex, Parent = row })
	end
	local enabled = true
	local api = {} :: any
	local refresh = Motion.bindButton(btn, function(state) return Kit.Styles[styleName][state] end)
	function api.setStyle(name: string)
		styleName = name
		label.TextColor3 = Kit.Styles[name].Text
		refresh()
	end
	function api.setText(t: string) label.Text = t end
	function api.setFont(f: Font) label.FontFace = f end
	function api.setEnabled(on: boolean)
		enabled = on
		btn.Active = on
		btn:SetAttribute("Disabled", not on)
	end
	local handlers = {}
	function api.onClick(fn) table.insert(handlers, fn) end
	btn.Activated:Connect(function()
		if not enabled then return end
		for _, fn in handlers do task.spawn(fn) end
	end)
	if props.OnClick then api.onClick(props.OnClick) end
	api.Instance = btn
	btn.Parent = props.Parent
	return api :: Button
end

-- The red close square with a drawn white X (native, no image).
function Kit.closeButton(props: { [string]: any }): Button
	local b = Kit.button({ Name = "Close", Style = "Close", Size = props.Size or UDim2.fromOffset(32, 32), Position = props.Position, AnchorPoint = props.AnchorPoint, Parent = props.Parent, OnClick = props.OnClick })
	for _, rot in { 45, -45 } do
		new("Frame", { Name = "XBar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.62, 0, 0, 5), Rotation = rot, BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = b.Instance }, { Kit.corner(2) })
	end
	return b
end

-- Faint square studs along the purple header (the reference's stud trim). Native frames, no texture.
function Kit.studs(parent: Instance, x0: number, x1: number, y: number)
	local strip = new("Frame", { Name = "Studs", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(x0, y), Size = UDim2.fromOffset(math.max(0, x1 - x0), 10), Parent = parent },
		{ Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for i = 1, math.max(0, math.floor((x1 - x0) / 18)) do
		new("Frame", { Name = "Stud", LayoutOrder = i, Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.HeaderStud, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = strip }, { Kit.corner(2) })
	end
	return strip
end

export type Window = {
	Holder: Frame, Group: CanvasGroup, OpenScale: UIScale, Panel: Frame, Header: Frame, Body: Frame, Close: Button,
	Width: number, Height: number,
}

-- A main window: purple header (icon, title, studs, close) over the navy panel. props: Name, Title, Icon, Width,
-- Height, HeaderHeight, TitleX, StudsTo (x where the studs end), Parent, OnClose.
function Kit.window(props: { [string]: any }): Window
	local w, h, hh = props.Width, props.Height, props.HeaderHeight or 47
	local holder = new("Frame", { Name = props.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Visible = false, Parent = props.Parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	local group = new("CanvasGroup", { Name = "Group", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })
	local panel = new("Frame", { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = Theme.Transparency.Panel, BorderSizePixel = 0, Parent = group },
		{ Kit.corner(5), Kit.stroke(C.Ink, 2, 0.2) })
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, hh), BackgroundColor3 = C.Header, BorderSizePixel = 0, Parent = panel }, { Kit.corner(5) })
	new("Frame", { Name = "SquareBottom", Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.Header, BorderSizePixel = 0, Parent = header })
	local iconSize = hh - 12
	Kit.icon(props.Icon, { Name = "TitleIcon", Position = UDim2.fromOffset(13, 6), Size = UDim2.fromOffset(iconSize, iconSize), Parent = header })
	local title = Kit.title({ Name = "Title", Text = props.Title, Position = UDim2.fromOffset(props.TitleX or 63, 0), Size = UDim2.new(0, 10, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = header })
	local titleEnd = (props.TitleX or 63) + (props.TitleWidth or math.ceil(#props.Title * Theme.Text.Title * 0.8)) + 10 -- Montserrat Black caps are about 0.8 em wide
	Kit.studs(header, titleEnd, props.StudsTo or (w - 56), math.floor(hh / 2) - 5)
	local close = Kit.closeButton({ Position = UDim2.new(1, -12, 0, 7), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(hh - 14, hh - 14), Parent = header, OnClick = props.OnClose })
	local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(0, hh), Size = UDim2.new(1, 0, 1, -hh), BackgroundTransparency = 1, Parent = panel })
	title.ZIndex = 2
	return { Holder = holder, Group = group, OpenScale = openScale, Panel = panel, Header = header, Body = body, Close = close, Width = w, Height = h }
end

-- A row of tabs. defs = { { Key, Text, X, Width } }, all at the same y/height. onSelect(key) runs on user clicks.
function Kit.tabs(parent: Instance, defs: { any }, y: number, height: number, onSelect: (string) -> (), textSize: number?)
	local buttons, selected = {}, nil
	local api = {}
	function api.select(key: string)
		selected = key
		for k, b in buttons do b.setStyle(k == key and "Selected" or "Tab") end
	end
	function api.selected() return selected end
	for i, d in defs do
		local b = Kit.button({ Name = d.Key .. "Tab", Text = d.Text, Style = "Tab", FontFace = Theme.Fonts.Tab, Position = UDim2.fromOffset(d.X, y), Size = UDim2.fromOffset(d.Width, height), TextSize = textSize or Theme.Text.Tab, Corner = 3, LayoutOrder = i, Parent = parent })
		b.onClick(function()
			if selected == d.Key then return end
			api.select(d.Key)
			onSelect(d.Key)
		end)
		buttons[d.Key] = b
	end
	api.buttons = buttons
	return api
end

-- A currency balance pill with its + button. Returns { Instance, setAmount, plus (Button) }.
function Kit.pill(props: { [string]: any })
	local w = props.Width or 110
	local f = new("Frame", { Name = props.Name or "Pill", Position = props.Position, Size = UDim2.fromOffset(w, props.Height or 30), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundColor3 = C.Pill, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = props.Parent }, { Kit.corner(5), Kit.stroke(C.Ink, 1.5, 0.3) })
	local h = props.Height or 30
	Kit.icon(props.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(h + 2, h + 2), Parent = f })
	local amount = Kit.text({ Name = "Amount", Text = "0", FontFace = Theme.Fonts.Number, TextSize = props.TextSize or 15, Position = UDim2.fromOffset(h + 6, 0), Size = UDim2.new(1, -(h + 6) - 30, 1, 0), TextWrapped = false, Parent = f })
	local plus = Kit.button({ Name = "Plus", Text = "+", Style = "Plus", TextSize = 22, FontFace = Theme.Fonts.Number, Corner = 3, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(25, h - 8), Parent = f })
	return { Instance = f, plus = plus, setAmount = function(text: string) amount.Text = text end }
end

-- Segmented choice (Everyone / Friends / Nobody, ON / OFF). defs = { { Value, Text, X, Width, Selected = style } }.
function Kit.segmented(parent: Instance, defs: { any }, y: number, height: number, onPick: (any) -> ())
	local buttons = {}
	local api = {}
	function api.set(value: any)
		for _, d in defs do buttons[d].setStyle(d.Value == value and (d.Selected or "Selected") or "Tab") end
	end
	for _, d in defs do
		local b = Kit.button({ Name = tostring(d.Text), Text = d.Text, Style = "Tab", Position = UDim2.fromOffset(d.X, y), Size = UDim2.fromOffset(d.Width, height), TextSize = d.TextSize or 14, FontFace = Theme.Fonts.Button, Corner = 3, Parent = parent })
		b.onClick(function() onPick(d.Value) end)
		buttons[d] = b
	end
	api.buttons = buttons
	return api
end

-- A volume slider 0-100. onChange fires while dragging (apply locally); onCommit when released (save).
-- Gamepad: select the knob and use the D-pad left/right.
function Kit.slider(props: { [string]: any })
	local track = new("TextButton", { Name = props.Name or "Slider", Text = "", AutoButtonColor = false, Position = props.Position, Size = props.Size, BackgroundColor3 = C.Track, BorderSizePixel = 0, Selectable = false, Parent = props.Parent }, { Kit.corner(4) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Action, BorderSizePixel = 0, Parent = track }, { Kit.corner(4) })
	local knob = new("TextButton", { Name = "Knob", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.Text, BorderSizePixel = 0, Selectable = true, Parent = track }, { Kit.corner(9), Kit.stroke(C.Ink, 1.5, 0.3) })
	local value = 0
	local api = {}
	function api.set(v: number)
		value = math.clamp(math.floor(v + 0.5), 0, 100)
		fill.Size = UDim2.fromScale(value / 100, 1)
		knob.Position = UDim2.fromScale(value / 100, 0.5)
	end
	local dragging = false
	local function fromX(x: number)
		local a, s = track.AbsolutePosition.X, track.AbsoluteSize.X
		if s <= 0 then return end
		api.set((x - a) / s * 100)
		if props.onChange then props.onChange(value) end
	end
	local function begin(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end
	track.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			dragging = false
			if props.onCommit then props.onCommit(value) end
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if GuiService.SelectedObject ~= knob then return end
		local step = input.KeyCode == Enum.KeyCode.DPadRight and 5 or input.KeyCode == Enum.KeyCode.DPadLeft and -5 or 0
		if step ~= 0 then
			api.set(value + step)
			if props.onChange then props.onChange(value) end
			if props.onCommit then props.onCommit(value) end
		end
	end)
	api.Instance = track
	return api
end

return Kit
