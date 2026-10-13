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

-- A soft dark copy one pixel under a label (the reference's names and headings sit on a slight drop shadow).
local function shadowOf(label: TextLabel, color: Color3, transparency: number, dy: number)
	local sh = label:Clone()
	for _, ch in sh:GetChildren() do ch:Destroy() end
	sh.Name = label.Name .. "Shadow"
	sh.TextColor3 = color
	sh.TextTransparency = transparency
	sh.Position = label.Position + UDim2.fromOffset(0, dy)
	sh.ZIndex = label.ZIndex
	label.ZIndex += 1
	sh.Parent = label.Parent
	label:GetPropertyChangedSignal("Text"):Connect(function() sh.Text = label.Text end)
	label:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = label.Visible end)
	return sh
end

-- A window heading (SHOP, SETTINGS): Montserrat Black caps, white with a lavender band through the middle, a thin
-- indigo outline and a heavier indigo drop underneath (all measured from the reference).
function Kit.title(props: { [string]: any }): TextLabel
	props.FontFace = props.FontFace or Theme.Fonts.Heading
	props.TextSize = props.TextSize or Theme.Text.Title
	props.TextWrapped = false
	local l = Kit.text(props)
	if l.Parent then
		local sh = shadowOf(l, C.TitleShadow, 0, 1.5)
		new("UIStroke", { Color = C.TitleShadow, Thickness = 1.2, Parent = sh })
	end
	new("UIStroke", { Color = C.TitleStroke, Thickness = 1.2, Parent = l })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, C.TitleBand), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }), Parent = l })
	return l
end

-- A character name or product title: Montserrat Bold, no outline, soft drop shadow.
function Kit.name(props: { [string]: any }): TextLabel
	props.FontFace = props.FontFace or Theme.Fonts.Name
	props.TextWrapped = false
	local l = Kit.text(props)
	if l.Parent then shadowOf(l, C.TextShadow, 0.5, 1) end
	return l
end

-- "CurrencyCoin" -> "currency-coin" (the asset file names).
local function kebab(name: string): string
	return (name:gsub("(%l)(%u)", "%1-%2"):gsub("(%a)(%d)", "%1-%2"):lower())
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
	if name ~= "Avatar" then img:SetAttribute("PreviewFile", "assets/icons/" .. kebab(name) .. ".png") end
	return img
end

-- A product picture from Config/Assets.Art (cropped from the kit's pages); fills its frame like the reference.
function Kit.art(name: string, props: { [string]: any }?): ImageLabel
	local p: { [string]: any } = { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = Assets.art(name) }
	for k, v in props or {} do p[k] = v end
	local img = new("ImageLabel", p)
	img:SetAttribute("PreviewFile", "assets/art/" .. kebab(name) .. ".png")
	return img
end

local function lighten(c: Color3, a: number) return c:Lerp(Color3.new(1, 1, 1), a) end
local function darken(c: Color3, a: number) return c:Lerp(Color3.new(0, 0, 0), a) end
-- A button look: fill (idle / hover / pressed), label colour, the 1 px lighter line along its top, and its rim.
local function style(fill: Color3, text: Color3, top: Color3?, rim: Color3?)
	return { Idle = fill, Hover = lighten(fill, 0.10), Pressed = darken(fill, 0.10), Text = text, Top = top or lighten(fill, 0.12), Rim = rim or darken(fill, 0.55) }
end
Kit.Styles = {
	Action = { Idle = C.Action, Hover = C.ActionHover, Pressed = C.ActionPressed, Text = C.Text, Top = C.ActionTop, Rim = C.ActionRim },
	Disabled = { Idle = C.Disabled, Hover = C.Disabled, Pressed = C.Disabled, Text = C.Text, Top = C.DisabledTop, Rim = C.ActionRim },
	Selected = style(C.SelectedTab, C.DarkText, C.SelectedTabTop, C.SelectedRim),
	Tab = style(C.InactiveTab, C.Text, C.InactiveTabTop, C.TabRim),
	HeaderTab = style(C.HeaderTab, C.Text, C.InactiveTabTop, C.HeaderTabRim),
	Segment = style(C.Segment, C.Text, C.SegmentTop, C.TabRim),
	Slate = style(C.Slate, C.Text, C.SlateTop, C.TabRim),
	Close = { Idle = C.Close, Hover = lighten(C.Close, 0.1), Pressed = darken(C.Close, 0.1), Text = C.Text, Top = C.CloseTop, Rim = C.CloseRim },
	-- fill is white so the purple UIGradient (#B84FFA -> #9925F9) shows as measured; hover/press dim it slightly
	Gift = { Idle = Color3.new(1, 1, 1), Hover = Color3.fromRGB(245, 240, 255), Pressed = Color3.fromRGB(215, 205, 230), Text = C.Text, Top = Color3.fromHex("C774FB"), Rim = C.GiftRim },
	Plus = style(C.Plus, C.Text, C.PlusTop, C.PlusRim),
	HudPlus = style(C.HudPlus, C.Text, C.PlusTop, C.PlusRim),
	Row = style(C.Row, C.Text, C.RowBorder, C.RowBorder),
	MenuRow = style(C.MenuRow, C.Text, C.MenuRowTop, C.MenuRowTop),
	Hud = { Idle = C.HudMid, Hover = lighten(C.HudMid, 0.1), Pressed = darken(C.HudMid, 0.1), Text = C.Text, Top = C.HudHighlight, Rim = C.HudRing },
}

export type Button = {
	Instance: TextButton,
	setStyle: (string) -> (),
	setText: (string) -> (),
	setFont: (Font) -> (),
	setEnabled: (boolean) -> (),
	onClick: ((() -> ()) -> ()),
}

-- A button. props: Text, Style (Kit.Styles key), Size, Position, AnchorPoint, Parent, Name, TextSize, FontFace,
-- Icon (left of the text; IconAfter puts it right), IconSize, LayoutOrder, Corner. Every button has the reference's
-- bevel: a 1 px lighter top line and a 1 px dark rim. Clicks are ignored while disabled.
function Kit.button(props: { [string]: any }): Button
	local styleName = props.Style or "Action"
	local st = Kit.Styles[styleName]
	local btn: TextButton = new("TextButton", {
		Name = props.Name or "Button", Size = props.Size, Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0,
		AutoButtonColor = false, BorderSizePixel = 0, Text = "", BackgroundColor3 = st.Idle,
		Selectable = true, ZIndex = props.ZIndex or 1,
	}, { Kit.corner(props.Corner) })
	local rim = Kit.stroke(st.Rim, props.RimThickness or 1)
	rim.Name = "Rim"
	rim.Parent = btn
	local top = new("Frame", { Name = "TopLine", BackgroundColor3 = st.Top, BorderSizePixel = 0, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 1), ZIndex = btn.ZIndex, Parent = btn })
	local label = Kit.text({
		Name = "Label", Text = props.Text or "", FontFace = props.FontFace or Theme.Fonts.Button,
		TextSize = props.TextSize or Theme.Text.Button, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = st.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false, LayoutOrder = 2, ZIndex = btn.ZIndex,
	})
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
		local s2 = Kit.Styles[name]
		label.TextColor3 = s2.Text
		top.BackgroundColor3 = s2.Top
		rim.Color = s2.Rim
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

-- The red close square: red gradient (#F31747 -> #DC0D3E), dark rim, drawn white X (native, no image).
function Kit.closeButton(props: { [string]: any }): Button
	local b = Kit.button({ Name = "Close", Style = "Close", Size = props.Size or UDim2.fromOffset(33, 34), Position = props.Position, AnchorPoint = props.AnchorPoint, Parent = props.Parent, OnClick = props.OnClick, RimThickness = 1.5 })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 218, 224)), Parent = b.Instance })
	for _, rot in { 45, -45 } do
		new("Frame", { Name = "XBar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.62, 0, 0, 5), Rotation = rot, BackgroundColor3 = C.Text, BorderSizePixel = 0, ZIndex = 2, Parent = b.Instance }, { Kit.corner(2) })
	end
	return b
end

-- The stud trim on a purple header: raised studs 9 x 11 on a 22 px pitch (lighter top, darker foot, 1 px shadow),
-- as measured on the reference.
function Kit.studs(parent: Instance, x0: number, x1: number, y: number)
	local strip = new("Frame", { Name = "Studs", BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y), Size = UDim2.fromOffset(math.max(0, x1 - x0), 12), Parent = parent },
		{ Kit.list(Enum.FillDirection.Horizontal, 13, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	for i = 1, math.max(0, math.floor((x1 - x0 + 13) / 22)) do
		local stud = new("Frame", { Name = "Stud", LayoutOrder = i, Size = UDim2.fromOffset(9, 11), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = strip }, { Kit.corner(2) })
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Stud, C.StudBottom), Parent = stud })
		new("Frame", { Name = "Shadow", Position = UDim2.new(0, 1, 1, 0), Size = UDim2.new(1, -2, 0, 1), BackgroundColor3 = C.StudShadow, BorderSizePixel = 0, Parent = stud })
	end
	return strip
end

export type Window = {
	Holder: Frame, Group: CanvasGroup, OpenScale: UIScale, Panel: Frame, Header: Frame, Body: Frame, Close: Button,
	Title: TextLabel, Width: number, Height: number,
}

-- A main window: a 3.5 px dark frame round everything; inside it the glossy purple header (icon, title, studs,
-- close) over the opaque navy panel. props: Name, Title, Icon, Width, Height, HeaderHeight, TitleX, TitleWidth,
-- StudsTo (x where the studs end), CloseSize, PanelColor, Parent, OnClose. Content goes in Panel (window coords).
function Kit.window(props: { [string]: any }): Window
	local w, h, hh = props.Width, props.Height, props.HeaderHeight or 47
	local inset = 3.5
	local holder = new("Frame", { Name = props.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Visible = false, Parent = props.Parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	local group = new("CanvasGroup", { Name = "Group", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })
	local panel = new("Frame", { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Frame, BorderSizePixel = 0, Parent = group }, { Kit.corner(6) })
	new("Frame", { Name = "Fill", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 1, -2 * inset), BackgroundColor3 = props.PanelColor or C.Panel, BorderSizePixel = 0, Parent = panel }, { Kit.corner(3) })
	local header = new("Frame", { Name = "Header", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 0, hh - inset), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = panel }, { Kit.corner(3) })
	local g = {}
	for _, k in C.HeaderGradient do table.insert(g, ColorSequenceKeypoint.new(k[1], k[2])) end
	new("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(g), Parent = header })
	new("Frame", { Name = "TopLine", Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 1), BackgroundColor3 = C.HeaderTop, BorderSizePixel = 0, Parent = header })
	-- The kit's own stud tile, faint across the whole header (as the kit asks), under the raised stud row.
	local tile = new("ImageLabel", { Name = "StudTexture", BackgroundTransparency = 1, Image = Assets.StudTile, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(Theme.StudTile, Theme.StudTile), Size = UDim2.fromScale(1, 1), Parent = header })
	tile:SetAttribute("PreviewFile", "assets/textures/square-stud-tile.png")
	local ih = hh - inset
	local iconSize = math.min(36, ih - 8)
	Kit.icon(props.Icon, { Name = "TitleIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize), Parent = header })
	local titleX = props.TitleX or 58
	local title = Kit.title({ Name = "Title", Text = props.Title, TextSize = props.TitleSize, Position = UDim2.fromOffset(titleX, 0), Size = UDim2.new(0, 10, 1, -2), AutomaticSize = Enum.AutomaticSize.X, Parent = header })
	local titleEnd = titleX + (props.TitleWidth or math.ceil(#props.Title * (props.TitleSize or Theme.Text.Title) * 0.7)) + 10
	Kit.studs(header, titleEnd, props.StudsTo or (w - 56), math.floor(ih / 2) - 6)
	local cs = props.CloseSize or Vector2.new(33, 34)
	local close = Kit.closeButton({ Position = UDim2.new(1, -7, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(cs.X, cs.Y), Parent = header, OnClose = nil, OnClick = props.OnClose })
	local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(0, hh), Size = UDim2.new(1, 0, 1, -hh), BackgroundTransparency = 1, Parent = panel })
	return { Holder = holder, Group = group, OpenScale = openScale, Panel = panel, Header = header, Body = body, Close = close, Title = title, Width = w, Height = h }
end

-- A row of tabs. defs = { { Key, Text, X, Width } }, all at the same y/height. onSelect(key) runs on user clicks.
-- style: "Tab" (in the body) or "HeaderTab" (inside the purple header).
function Kit.tabs(parent: Instance, defs: { any }, y: number, height: number, onSelect: (string) -> (), textSize: number?, style: string?)
	local buttons, selected = {}, nil
	local idle = style or "Tab"
	local api = {}
	function api.select(key: string)
		selected = key
		for k, b in buttons do b.setStyle(k == key and "Selected" or idle) end
	end
	function api.selected() return selected end
	for i, d in defs do
		local b = Kit.button({ Name = d.Key .. "Tab", Text = d.Text, Style = idle, FontFace = Theme.Fonts.Tab, Position = UDim2.fromOffset(d.X, y), Size = UDim2.fromOffset(d.Width, height), TextSize = textSize or Theme.Text.Tab, Corner = 3, LayoutOrder = i, Parent = parent })
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
-- props: Name, Icon, Position, Width, Height, TextSize, PlusStyle ("Plus" in windows, "HudPlus" on the HUD).
function Kit.pill(props: { [string]: any })
	local w, h = props.Width or 110, props.Height or 31
	local f = new("Frame", { Name = props.Name or "Pill", Position = props.Position, Size = UDim2.fromOffset(w, h), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = props.Parent }, { Kit.corner(5), Kit.stroke(C.PillRim, 1) })
	-- two-tone fill: a slightly lighter top half over a darker foot (the reference's glossy pill)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("1B2A44")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("1B2A44")), ColorSequenceKeypoint.new(0.51, Color3.fromHex("0B192F")), ColorSequenceKeypoint.new(1, Color3.fromHex("162647")) }), Parent = f })
	Kit.icon(props.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -3, 0.5, 0), Size = UDim2.fromOffset(h + 3, h + 3), Parent = f })
	local amount = Kit.text({ Name = "Amount", Text = "0", FontFace = Theme.Fonts.Number, TextSize = props.TextSize or 15, Position = UDim2.fromOffset(h + 4, 0), Size = UDim2.new(1, -(h + 4) - 30, 1, 0), TextWrapped = false, Parent = f })
	local plus = Kit.button({ Name = "Plus", Text = "+", Style = props.PlusStyle or "Plus", TextSize = 24, FontFace = Theme.Fonts.Number, Corner = 3, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -1, 0.5, 0), Size = UDim2.fromOffset(26, h - 2), Parent = f })
	return { Instance = f, plus = plus, setAmount = function(text: string) amount.Text = text end }
end

-- Segmented choice (Everyone / Friends / Nobody, ON / OFF). defs = { { Value, Text, X, Width, Selected = style } }.
function Kit.segmented(parent: Instance, defs: { any }, y: number, height: number, onPick: (any) -> (), textSize: number?)
	local buttons = {}
	local api = {}
	function api.set(value: any)
		for _, d in defs do buttons[d].setStyle(d.Value == value and (d.Selected or "Selected") or "Segment") end
	end
	for _, d in defs do
		local b = Kit.button({ Name = tostring(d.Text), Text = d.Text, Style = "Segment", Position = UDim2.fromOffset(d.X, y), Size = UDim2.fromOffset(d.Width, height), TextSize = textSize or d.TextSize or 15, FontFace = Theme.Fonts.Button, Corner = 3, Parent = parent })
		b.onClick(function() onPick(d.Value) end)
		buttons[d] = b
	end
	api.buttons = buttons
	return api
end

-- A volume slider 0-100. onChange fires while dragging (apply locally); onCommit when released (save).
-- Gamepad: select the knob and use the D-pad left/right.
function Kit.slider(props: { [string]: any })
	local track = new("TextButton", { Name = props.Name or "Slider", Text = "", AutoButtonColor = false, Position = props.Position, Size = props.Size, BackgroundColor3 = C.Track, BorderSizePixel = 0, Selectable = false, Parent = props.Parent }, { Kit.corner(7), Kit.stroke(C.TrackRim, 1) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.TrackFill, BorderSizePixel = 0, Parent = track }, { Kit.corner(7) })
	local knob = new("TextButton", { Name = "Knob", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.Knob, BorderSizePixel = 0, Selectable = true, ZIndex = 2, Parent = track }, { Kit.corner(12), Kit.stroke(C.KnobRim, 1) })
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
