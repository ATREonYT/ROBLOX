-- The shared component set every screen is built from (one window, header, tab, button, pill, toggle and slider
-- style), so all 18 pages stay consistent. Sizes are reference px (see Theme.lua).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Report = require(script.Parent.Report)
local ImageLoader = require(script.Parent.ImageLoader)
local Sfx = require(script.Parent.Parent.Gameplay.Sfx)

local C = Theme.Colors
local Kit = {}

-- The UI lives in StarterGui as real parts the owner can edit in Studio. The scripts don't build a second copy:
-- when a part is made under a parent that already has an unused saved part of the same class and name (its
-- "twin"), the saved part is reused. Its look (LOOK below: position, size, colours, fonts, images, corners...)
-- stays as saved, so Studio edits show in the game; everything else (text, visibility, behaviour) comes from the
-- scripts. A fresh parent has no twins, so the same code also builds the UI from nothing.
-- Parts made or reused this session (never reused twice), and which of them came from StarterGui. These are plain
-- tables, not weak ones: a weak table can drop a part while it still exists (when no script holds it), which made
-- the reuse random. Entries go when the part is destroyed.
local used: { [Instance]: boolean } = {}
local reusedSet: { [Instance]: boolean } = {}
local function mark(inst: Instance, reused: boolean)
	if reused then reusedSet[inst] = true end
	if used[inst] then return end
	used[inst] = true
	pcall(function()
		inst.Destroying:Connect(function()
			used[inst] = nil
			reusedSet[inst] = nil
		end)
	end)
end
Kit.LOOK = {
	Position = true, Size = true, AnchorPoint = true, BackgroundColor3 = true, BackgroundTransparency = true,
	BorderSizePixel = true, TextColor3 = true, TextSize = true, FontFace = true, TextStrokeColor3 = true,
	TextStrokeTransparency = true, TextXAlignment = true, TextYAlignment = true, TextScaled = true, TextWrapped = true,
	LineHeight = true, Image = true, ImageColor3 = true, ImageTransparency = true, ScaleType = true, CornerRadius = true,
	Color = true, Thickness = true, Transparency = true, Rotation = true, PaddingLeft = true, PaddingRight = true,
	PaddingTop = true, PaddingBottom = true, Padding = true, CellSize = true, CellPadding = true, AspectRatio = true,
	ScrollBarThickness = true, ScrollBarImageColor3 = true,
}
-- Small style pieces (corners, rims, gradients, layouts): a saved one is reused even when the code made its own.
local MODIFIERS = {
	UICorner = true, UIStroke = true, UIGradient = true, UIPadding = true, UIListLayout = true, UIGridLayout = true,
	UIScale = true, UIAspectRatioConstraint = true, UISizeConstraint = true, UITextSizeConstraint = true,
}

local function twin(parent: Instance, class: string, name: string): Instance?
	for _, ch in parent:GetChildren() do
		if not used[ch] and ch.ClassName == class and ch.Name == name then return ch end
	end
	return nil
end

-- True when the part came from StarterGui (so its saved look wins over the code's).
function Kit.reused(inst: Instance): boolean
	return reusedSet[inst] == true
end

-- Puts a part the code made into `parent`, reusing a saved twin instead when there is one. For style pieces the
-- saved twin is kept (and returned); anything bigger is replaced by the code's part. Use the returned part.
function Kit.attach(child: Instance, parent: Instance): Instance
	local saved = twin(parent, child.ClassName, child.Name)
	if saved then
		if MODIFIERS[child.ClassName] and #child:GetChildren() == 0 then
			child:Destroy()
			mark(saved, true)
			return saved
		end
		saved:Destroy()
	end
	mark(child, false)
	child.Parent = parent
	return child
end

-- Instance helper: Kit.new("Frame", { Size = ..., Parent = ... }, { children }). Parent is set last.
function Kit.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local parent = props and props.Parent
	local inst = parent and twin(parent, class, props.Name or class)
	local reused = inst ~= nil
	if not inst then inst = Instance.new(class) end
	mark(inst, reused)
	for k, v in props or {} do
		if k ~= "Parent" and not (reused and Kit.LOOK[k]) then (inst :: any)[k] = v end
	end
	for _, child in children or {} do Kit.attach(child, inst) end
	if parent and not reused then inst.Parent = parent end
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

-- Gotham (the one font now, as Huss Valley) is about 15% wider than the narrow Roboto Condensed the body, tab and
-- button sizes were measured with, so those roles draw a little smaller and every layout still fits.
local NARROW = 0.86
local function narrowRole(font: any): boolean
	return rawequal(font, Theme.Fonts.Body) or rawequal(font, Theme.Fonts.Button) or rawequal(font, Theme.Fonts.Tab)
end

function Kit.text(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1, FontFace = Theme.Fonts.Body, TextColor3 = C.Text, TextSize = Theme.Text.Blurb,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true,
	}
	for k, v in props do p[k] = v end
	if narrowRole(p.FontFace) then
		p.TextSize = math.max(8, math.round(p.TextSize * NARROW))
	end
	return new("TextLabel", p)
end

-- Text widths, so names and rarity badges are sized to fit their column (owner: "the rarities ... go out of the
-- uis borders"). Roblox measures its own text (TextService; Gotham SSm is what the legacy Gotham fonts draw);
-- where it can't (the offline preview), Montserrat Bold's advance widths stand in (1/1000 em, characters 32-126):
-- the preview draws Montserrat for Gotham and it is a little wider, so what fits there fits in the game too.
local ADVANCE = { 283, 289, 437, 720, 638, 877, 728, 230, 357, 358, 434, 599, 262, 386, 262, 392, 679, 392, 590, 592,
	689, 595, 637, 620, 660, 637, 262, 262, 599, 599, 599, 588, 1035, 766, 765, 724, 826, 671, 639, 771, 808, 328, 541,
	740, 604, 955, 808, 844, 732, 844, 735, 638, 618, 788, 746, 1163, 714, 676, 671, 368, 392, 368, 600, 500, 600, 617,
	690, 591, 692, 631, 387, 700, 691, 301, 307, 655, 301, 1049, 691, 655, 690, 690, 431, 531, 435, 687, 598, 937, 595,
	598, 543, 391, 309, 391, 599 }
local okText, TextService = pcall(function() return game:GetService("TextService") end)
local function weightOf(font: any): string
	local ok, w = pcall(function() return font.Weight.Name end)
	return if ok and type(w) == "string" then w else "Regular"
end
local LEGACY = { Heavy = "GothamBlack", Black = "GothamBlack", ExtraBold = "GothamBlack", Bold = "GothamBold", SemiBold = "GothamBold", Medium = "GothamMedium" }
function Kit.textWidth(text: string, font: any, size: number): number
	local weight = weightOf(font)
	if okText and TextService then
		local ok, v = pcall(function()
			return TextService:GetTextSize(text, size, (Enum.Font :: any)[LEGACY[weight] or "Gotham"], Vector2.new(10000, 10000)).X
		end)
		if ok and type(v) == "number" and (v > 0 or text == "") then return v end
	end
	local k = if weight == "Heavy" or weight == "Black" or weight == "ExtraBold" then 1.04 elseif weight == "Bold" or weight == "SemiBold" then 1 else 0.97
	local w = 0
	for _, cp in utf8.codes(text) do w += ADVANCE[cp - 31] or 680 end
	return w / 1000 * size * k
end

-- Fits a one-line label into maxW px: the biggest text size from size down to minSize whose words fit, else
-- minSize and cut with "..." (TextTruncate, so Roblox never draws past the box either). Sets TextSize and the
-- label's width (keepBox: leaves the box as it is, e.g. a centred label); returns the width it takes.
function Kit.fitLine(label: TextLabel, maxW: number, size: number, minSize: number?, keepBox: boolean?): number
	local s, lo = size, math.min(minSize or size, size)
	local function width(at: number) return math.ceil(Kit.textWidth(label.Text, label.FontFace, at)) + 1 end
	while s > lo and width(s) > maxW do s -= 1 end
	local w = math.min(width(s), math.floor(maxW))
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextSize = s
	if not keepBox then label.Size = UDim2.new(0, w, label.Size.Y.Scale, label.Size.Y.Offset) end
	local sh = label.Parent and label.Parent:FindFirstChild(label.Name .. "Shadow") -- (Kit.name's drop shadow)
	if sh and sh:IsA("TextLabel") then
		sh.AutomaticSize, sh.TextWrapped, sh.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
		sh.TextSize, sh.Size = s, label.Size
	end
	return w
end

-- Fits a label on up to maxLines lines of maxW px (words wrap; a single word never breaks): the biggest size from
-- size down to minSize that fits. Sets TextSize, TextWrapped and the label's size (lines x 1.15 x size tall) and
-- returns the size and line count, or nil when even minSize doesn't fit (then nothing is changed).
function Kit.fitBlock(label: TextLabel, maxW: number, maxLines: number, size: number, minSize: number): (number?, number?)
	local words = string.split(label.Text, " ")
	for s = size, minSize, -1 do
		local lines, line = 1, ""
		for _, word in words do
			local try = if line == "" then word else line .. " " .. word
			if Kit.textWidth(try, label.FontFace, s) + 1 <= maxW then
				line = try
			elseif line ~= "" and Kit.textWidth(word, label.FontFace, s) + 1 <= maxW then
				lines, line = lines + 1, word
			else
				lines = maxLines + 1 -- (one word wider than the box)
				break
			end
		end
		if lines <= maxLines then
			label.AutomaticSize = Enum.AutomaticSize.None
			label.TextTruncate = Enum.TextTruncate.None
			label.TextWrapped = true
			label.TextSize = s
			label.Size = UDim2.fromOffset(math.floor(maxW), lines * math.ceil(s * 1.15))
			return s, lines
		end
	end
	return nil, nil
end

-- A rarity or tier badge: a coloured chip with white caps, as wide as its word (measured) but never wider than
-- MaxWidth: a long word drops to a smaller size first. Inside its box the word is TextScaled with its size as the
-- cap, so even if Roblox's font runs wider than measured it shrinks instead of spilling out. props: Name, Text,
-- Color, TextColor, Height, TextSize, MinTextSize, MaxWidth, Pad, Corner, Position, AnchorPoint, ZIndex,
-- LayoutOrder, Parent. Returns the label (its Size is set).
function Kit.badge(props: { [string]: any }): TextLabel
	local h, pad = props.Height or 22, props.Pad or 6
	local size, minSize = props.TextSize or 13, props.MinTextSize or 9
	local maxW = props.MaxWidth or 200
	local b = Kit.text({
		Name = props.Name or "Badge", Text = props.Text or "", FontFace = props.FontFace or Theme.Fonts.Button,
		TextColor3 = props.TextColor or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
		BackgroundTransparency = 0, BackgroundColor3 = props.Color or C.Slate, BorderSizePixel = 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position or UDim2.new(), ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0, Parent = props.Parent,
	})
	while size > minSize and math.ceil(Kit.textWidth(b.Text, b.FontFace, size)) + 2 * pad + 1 > maxW do size -= 1 end
	local w = math.min(math.ceil(Kit.textWidth(b.Text, b.FontFace, size)) + 2 * pad + 1, math.floor(maxW))
	-- (set after making it: a part reused from StarterGui keeps its saved look otherwise)
	b.AutomaticSize = Enum.AutomaticSize.None
	b.Size = UDim2.fromOffset(w, h)
	b.TextSize = size
	b.TextScaled = true
	b.TextTruncate = Enum.TextTruncate.None
	local limit = b:FindFirstChildOfClass("UITextSizeConstraint") or new("UITextSizeConstraint", { Parent = b })
	limit.MaxTextSize, limit.MinTextSize = size, math.min(minSize, size)
	local pads = b:FindFirstChildOfClass("UIPadding") or Kit.attach(Kit.pad(pad, pad, 0, 0), b)
	pads.PaddingLeft, pads.PaddingRight, pads.PaddingTop, pads.PaddingBottom = UDim.new(0, pad), UDim.new(0, pad), UDim.new(), UDim.new()
	if not b:FindFirstChildOfClass("UICorner") then Kit.attach(Kit.corner(props.Corner or 3), b) end
	return b
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
	sh = Kit.attach(sh, label.Parent) :: TextLabel
	label:GetPropertyChangedSignal("Text"):Connect(function() sh.Text = label.Text end)
	label:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = label.Visible end)
	-- (a label fitted to its column, Kit.fitLine, changes size: the shadow follows)
	for _, prop in { "TextSize", "Size", "TextTruncate", "AutomaticSize" } do
		label:GetPropertyChangedSignal(prop):Connect(function() (sh :: any)[prop] = (label :: any)[prop] end)
	end
	label:GetPropertyChangedSignal("Position"):Connect(function() sh.Position = label.Position + UDim2.fromOffset(0, dy) end)
	return sh
end

-- A window heading (SHOP, SETTINGS): Gotham Black caps, plain white with a dark outline and a soft drop (Huss Valley).
function Kit.title(props: { [string]: any }): TextLabel
	props.FontFace = props.FontFace or Theme.Fonts.Heading
	props.TextSize = props.TextSize or Theme.Text.Title
	props.TextWrapped = false
	local l = Kit.text(props)
	if l.Parent then
		local sh = shadowOf(l, C.TitleShadow, 0.45, 2)
		new("UIStroke", { Color = C.TitleShadow, Thickness = 1.2, Parent = sh })
	end
	new("UIStroke", { Color = C.TitleStroke, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l }) -- (Huss Valley: plain white, dark outline)
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
	if name == "Avatar" or (img.Image == "" and p.Image ~= "") then img.Image = p.Image end -- this player's avatar, or an ID added to Config/Assets after saving
	img:SetAttribute("Icon", name)
	if name ~= "Avatar" then
		img:SetAttribute("PreviewFile", "assets/icons/" .. kebab(name) .. ".png")
		ImageLoader.apply(img, "Icons", name, img.Image)
	end
	return img
end

-- A product picture from Config/Assets.Art (cropped from the kit's pages); fills its frame like the reference.
function Kit.art(name: string, props: { [string]: any }?): ImageLabel
	local p: { [string]: any } = { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = Assets.art(name) }
	for k, v in props or {} do p[k] = v end
	local img = new("ImageLabel", p)
	if img.Image == "" and p.Image ~= "" then img.Image = p.Image end
	img:SetAttribute("Art", name)
	img:SetAttribute("PreviewFile", "assets/art/" .. kebab(name) .. ".png")
	ImageLoader.apply(img, "Art", name, img.Image)
	return img
end

-- Swap the picture an art label shows (a map card whose map changes with each vote).
function Kit.setArt(img: ImageLabel, name: string)
	if img:GetAttribute("Art") == name then return end
	img:SetAttribute("Art", name)
	img:SetAttribute("PreviewFile", "assets/art/" .. kebab(name) .. ".png")
	img.Image = Assets.art(name)
	ImageLoader.clearStandIn(img) -- (the old picture's stand-in glyph)
	ImageLoader.apply(img, "Art", name, img.Image)
end

-- Swap the icon an icon label shows (a daily quest's reward: coin, Aura star or wheel).
function Kit.setIcon(img: ImageLabel, name: string)
	if img:GetAttribute("Icon") == name then return end
	img:SetAttribute("Icon", name)
	img:SetAttribute("PreviewFile", "assets/icons/" .. kebab(name) .. ".png")
	img.Image = Assets.icon(name)
	ImageLoader.clearStandIn(img)
	ImageLoader.apply(img, "Icons", name, img.Image)
end

local function lighten(c: Color3, a: number) return c:Lerp(Color3.new(1, 1, 1), a) end
local function darken(c: Color3, a: number) return c:Lerp(Color3.new(0, 0, 0), a) end
-- A button look: fill (idle / hover / pressed), label colour, the 1 px lighter line along its top, and its rim.
local function style(fill: Color3, text: Color3, top: Color3?, rim: Color3?)
	return { Idle = fill, Hover = lighten(fill, 0.10), Pressed = darken(fill, 0.10), Text = text, Top = top or lighten(fill, 0.12), Rim = rim or darken(fill, 0.55) }
end
Kit.Styles = {
	Action = { Idle = C.Action, Hover = C.ActionHover, Pressed = C.ActionPressed, Text = C.Text, Top = C.ActionTop, Rim = C.ActionRim },
	CoinAction = { Idle = C.CoinBuy, Hover = lighten(C.CoinBuy, 0.10), Pressed = darken(C.CoinBuy, 0.10), Text = C.Text, Top = C.CoinBuyTop, Rim = C.CoinBuyRim }, -- coin cards (08)
	ItemBuy = style(Color3.fromHex("6E52F8"), C.Text, Color3.fromHex("9C86FC"), Color3.fromHex("140A5C")), -- ITEMS cards (owner's Oct 17 mockup)
	CrateBuy = style(Color3.fromHex("6A5CF6"), C.Text, Color3.fromHex("A79FFF"), Color3.fromHex("1C1562")), -- Shop > CRATES' BUY (owner's crate shop mockup, Oct 20)
	DancePlay = style(Color3.fromHex("C24DFD"), C.Text, Color3.fromHex("FFACFF"), Color3.fromHex("3A0C74")), -- the Dances PLAY (Oct 17 mockup)
	Disabled = { Idle = C.Disabled, Hover = C.Disabled, Pressed = C.Disabled, Text = C.Text, Top = C.DisabledTop, Rim = C.ActionRim },
	Selected = style(C.SelectedTab, C.Text, C.SelectedTabTop, C.SelectedRim),
	Tab = style(C.InactiveTab, C.Text, C.InactiveTabTop, C.TabRim),
	HeaderTab = style(C.HeaderTab, C.Text, C.InactiveTabTop, C.HeaderTabRim),
	Segment = style(C.Segment, C.Text, C.SegmentTop, C.TabRim),
	Slate = style(C.Slate, C.Text, C.SlateTop, C.TabRim),
	Close = { Idle = C.Close, Hover = lighten(C.Close, 0.1), Pressed = darken(C.Close, 0.1), Text = C.Text, Top = C.CloseTop, Rim = C.CloseRim, NoShade = true },
	-- fill is white so the purple UIGradient (#B84FFA -> #9925F9) shows as measured; hover/press dim it slightly
	Gift = { Idle = Color3.new(1, 1, 1), Hover = Color3.fromRGB(245, 240, 255), Pressed = Color3.fromRGB(215, 205, 230), Text = C.Text, Top = Color3.fromHex("C774FB"), Rim = C.GiftRim, NoShade = true },
	Plus = style(C.Plus, C.Text, C.PlusTop, C.PlusRim),
	-- the shop's pass rows, after the owner's pass banners (design/shop/pass-banners.png)
	PassViolet = style(Color3.fromHex("6E5BF2"), C.Text, Color3.fromHex("9C8CFF"), Color3.fromHex("2E2385")),
	PassPink = style(Color3.fromHex("E24FA8"), C.Text, Color3.fromHex("FF8AD0"), Color3.fromHex("7E1C5C")),
	HudPlus = style(C.HudPlus, C.Text, C.PlusTop, C.PlusRim),
	Row = style(C.Row, C.Text, C.RowBorder, C.RowBorder),
	MenuRow = style(C.MenuRow, C.Text, C.MenuRowTop, C.MenuRowTop),
	-- HUD buttons are white tinted by their navy UIGradient, so these fills only brighten/dim that gradient
	Hud = { Idle = Color3.fromRGB(235, 235, 242), Hover = Color3.new(1, 1, 1), Pressed = Color3.fromRGB(200, 200, 212), Text = C.Text, Top = C.HudHighlight, Rim = C.HudRing, NoShade = true },
}

-- Places a button by its usual top-left (or given anchor) position, but anchors it at its centre, so the hover and
-- press scale grows and squishes around the middle. Offsets are rounded (Roblox stores whole pixels).
function Kit.place(btn: GuiObject, pos: UDim2, size: UDim2, anchor: Vector2?)
	local a = anchor or Vector2.zero
	local dx, dy = 0.5 - a.X, 0.5 - a.Y
	btn.Size = size
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.new(pos.X.Scale + dx * size.X.Scale, math.round(pos.X.Offset + dx * size.X.Offset), pos.Y.Scale + dy * size.Y.Scale, math.round(pos.Y.Offset + dy * size.Y.Offset))
end

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
		Name = props.Name or "Button", LayoutOrder = props.LayoutOrder or 0,
		AutoButtonColor = false, BorderSizePixel = 0, Text = "", BackgroundColor3 = st.Idle,
		Selectable = true, ZIndex = props.ZIndex or 1, Parent = props.Parent,
	}, { Kit.corner(props.Corner) })
	if not Kit.reused(btn) then Kit.place(btn, props.Position or UDim2.new(), props.Size, props.AnchorPoint) end
	local rim = Kit.stroke(st.Rim, props.RimThickness or 1)
	rim.Name = "Rim"
	rim = Kit.attach(rim, btn) :: UIStroke
	-- the shade (owner: "bland"): full colour on top, about a fifth darker at the foot, like a lit glossy key
	if not st.NoShade then
		new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(236, 236, 240)), ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 196, 208)) }), Parent = btn })
	end
	if styleName ~= "Close" and styleName ~= "Gift" then
		Kit.studPattern(btn, 0.22) -- (the studded look on every button: owner's call)
	end
	local top = new("Frame", { Name = "TopLine", BackgroundColor3 = st.Top, BorderSizePixel = 0, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 1), ZIndex = btn.ZIndex, Parent = btn })
	local row = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = btn.ZIndex, Parent = btn },
		{ Kit.list(Enum.FillDirection.Horizontal, props.Gap or 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local label = Kit.text({
		Name = "Label", Text = props.Text or "", FontFace = props.FontFace or Theme.Fonts.Button,
		TextSize = props.TextSize or Theme.Text.Button, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = st.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false, LayoutOrder = 2, ZIndex = btn.ZIndex, Parent = row,
	})
	-- the owner's table: buttons have a minimal outline (light labels only; dark text on gold stays clean)
	local outline = new("UIStroke", { Name = "Outline", Color = st.Rim, Thickness = 1, Transparency = 0.35, Enabled = st.Text.R + st.Text.G + st.Text.B > 1.5, Parent = label })
	if props.Icon then
		local s = props.IconSize or 22
		Kit.icon(props.Icon, { Name = "Icon", Size = UDim2.fromOffset(s, s), LayoutOrder = props.IconAfter and 3 or 1, ZIndex = btn.ZIndex, Parent = row })
	end
	-- an icon-only button keeps its icon dead centre (an empty label would still take a gap in the row)
	label.Visible = (props.Text or "") ~= ""
	local enabled = true
	local api = {} :: any
	local refresh = Motion.bindButton(btn, function(state) return Kit.Styles[styleName][state] end)
	function api.setStyle(name: string)
		styleName = name
		local s2 = Kit.Styles[name]
		Motion.tween(label, "text", Theme.Motion.Tab, { TextColor3 = s2.Text })
		top.BackgroundColor3 = s2.Top
		rim.Color = s2.Rim
		outline.Color, outline.Enabled = s2.Rim, s2.Text.R + s2.Text.G + s2.Text.B > 1.5
		refresh()
	end
	function api.setText(t: string)
		label.Text = t
		label.Visible = t ~= ""
	end
	function api.setFont(f: Font) label.FontFace = f end
	function api.setEnabled(on: boolean)
		enabled = on
		btn.Active = on
		btn:SetAttribute("Disabled", not on)
	end
	local handlers = {}
	function api.onClick(fn) table.insert(handlers, fn) end
	-- A mouse click sounds on press, not on release (owner: "make the sound for buttons not delayed"). Touch, keys
	-- and pads sound on Activated (a finger dragging to scroll must not click every button it starts on); the
	-- sounds are loaded ahead (Sfx), so that is instant too.
	-- One press, one sound (owner, Oct 18: "they sound glitchy"): the press is MouseButton1Down, which only the button
	-- on top gets (InputBegan can also fire on buttons under the mouse that sit behind an open window or another
	-- button, so one click could sound two or three times at once, a little out of step); a press that didn't end in a click (dragged off) doesn't stop the next one from
	-- sounding; and Sfx skips the same sound asked for again within 0.08 s.
	local pressedAt = -math.huge
	btn.MouseButton1Down:Connect(function()
		local ok, last = pcall(function() return UserInputService:GetLastInputType() end)
		if not (ok and last == Enum.UserInputType.MouseButton1) then return end -- (touch: on Activated)
		pressedAt = os.clock()
		Sfx.play(if enabled then "ui_click" else "ui_error")
	end)
	btn.Activated:Connect(function()
		if os.clock() - pressedAt > 2 then Sfx.play(if enabled then "ui_click" else "ui_error") end
		pressedAt = -math.huge
		if not enabled then return end
		for _, fn in handlers do task.spawn(Report.run, "Button " .. btn.Name, fn) end
	end)
	if props.OnClick then api.onClick(props.OnClick) end
	api.Instance = btn
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

-- The stud trim on a purple header: one tiled image (assets/icons/stud-tile.png, made by
-- tools/icons/make_stud_tile.py) repeated across the strip, so a strip is a single part instead of one per stud.
-- 9 px raised square studs on a 22 px pitch, as measured on the reference.
function Kit.studs(parent: Instance, x0: number, x1: number, y: number)
	-- Each strip in a parent gets its own name (Studs, Studs2, ...), so a saved strip is always reused by the same
	-- call: two same-named strips could swap places when the StarterGui copy is reused.
	local n = 0
	for _, ch in parent:GetChildren() do
		if used[ch] and ch.Name:match("^Studs%d*$") then n += 1 end
	end
	local count = math.max(0, math.floor((x1 - x0 + 13) / 22))
	return Kit.icon("StudTile", {
		Name = if n == 0 then "Studs" else "Studs" .. (n + 1),
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(22, 12),
		Position = UDim2.fromOffset(x0, y), Size = UDim2.fromOffset(math.max(0, count * 22 - 13), 12),
		Visible = false, Parent = parent, -- (owner: the whole panel is studded now, Kit.studPattern; strips stay hidden)
	})
end

-- The studded texture over a whole panel (owner's call: "the whole thing to have a studded background, everywhere
-- in the UI"): assets/icons/stud-pattern.png (tools/icons/make_stud_pattern.py), one raised square stud per 24 px
-- tile, white/black with alpha so it suits any colour. strength 0-1 (default 0.5). It copies the parent's rounded
-- corners (ClipsDescendants would clip square). Under everything else in the parent (ZIndex as the parent's).
-- Owner, Oct 21: "the studs are too big, make them actual size studs": 12 px a stud (was 24), like the bricks in the game.
Kit.STUD = 12
function Kit.studPattern(parent: GuiObject, strength: number?)
	local img = Kit.icon("StudPattern", {
		Name = "StudPattern", ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(Kit.STUD, Kit.STUD),
		Size = UDim2.fromScale(1, 1), ImageTransparency = 1 - (strength or 0.5), ZIndex = parent.ZIndex,
		Parent = parent,
	})
	local corner = parent:FindFirstChildOfClass("UICorner")
	if corner and not img:FindFirstChildOfClass("UICorner") then
		Kit.attach(new("UICorner", { CornerRadius = corner.CornerRadius }), img)
	end
	return img
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
	local inset = 4 -- the reference frame is 3.5 px; Roblox offsets are whole pixels
	local holder = new("Frame", { Name = props.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Visible = false, Parent = props.Parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	-- anchored at its centre so the open/close scale grows from the middle
	-- Flat = a plain Frame instead of a CanvasGroup (no open fade), for windows with ViewportFrames that must show.
	local group = new(if props.Flat then "Frame" else "CanvasGroup", { Name = "Group", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })
	-- (owner: more see-through) the dark frame is a stroke round the body, so the body itself can let the world show
	local panel = new("Frame", { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Frame, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = group }, { Kit.corner(6) })
	local fill = new("Frame", { Name = "Fill", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 1, -2 * inset), BackgroundColor3 = props.PanelColor or C.Panel, BackgroundTransparency = Theme.Transparency.Body, BorderSizePixel = 0, Parent = panel }, {
		Kit.corner(3),
		new("UIStroke", { Name = "Frame", Color = C.Frame, Thickness = inset, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIGradient", { Name = "Depth", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(178, 182, 204)) }),
	})
	Kit.studPattern(fill, 0.3)
	local header = new("Frame", { Name = "Header", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 0, hh - inset), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = Theme.Transparency.Header, BorderSizePixel = 0, Parent = panel }, { Kit.corner(3) })
	Kit.studPattern(header, 0.45)
	local g = {}
	for _, k in C.HeaderGradient do table.insert(g, ColorSequenceKeypoint.new(k[1], k[2])) end
	new("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(g), Parent = header })
	new("Frame", { Name = "TopLine", Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 1), BackgroundColor3 = C.HeaderTop, BorderSizePixel = 0, Parent = header })
	local ih = hh - inset
	local iconSize = ih - 4
	Kit.icon(props.Icon, { Name = "TitleIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize), Parent = header })
	local titleX = props.TitleX or 58
	local title = Kit.title({ Name = "Title", Text = props.Title, TextSize = props.TitleSize, Position = UDim2.fromOffset(titleX, props.TitleOffsetY or 0), Size = UDim2.new(0, 10, 1, -2), AutomaticSize = Enum.AutomaticSize.X, Parent = header })
	local titleEnd = titleX + (props.TitleWidth or math.ceil(#props.Title * (props.TitleSize or Theme.Text.Title) * 0.7)) + 10
	Kit.studs(header, titleEnd, props.StudsTo or (w - 56), math.floor(ih / 2) - 6)
	local cs = props.CloseSize or Vector2.new(31, 31) -- plus the 1.5 px rim: about 33 outside, as measured
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
	if props.Split then
		-- HUD pills: lighter top, darker foot from about two thirds down (reference 13)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("1F2F5C")), ColorSequenceKeypoint.new(0.65, Color3.fromHex("1B2A54")), ColorSequenceKeypoint.new(0.67, Color3.fromHex("0E1738")), ColorSequenceKeypoint.new(1, Color3.fromHex("141F48")) }), Parent = f })
	else
		-- header pills: a smooth gradient (reference 01)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("1C2C5E")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("16244F")), ColorSequenceKeypoint.new(1, Color3.fromHex("111B40")) }), Parent = f })
	end
	f.BackgroundTransparency = 0.1
	Kit.studPattern(f, 0.3)
	local s = h - 6
	Kit.icon(props.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(s, s), Parent = f })
	-- the amount is centred between the icon and the + button
	local amount = Kit.text({ Name = "Amount", Text = "0", FontFace = Theme.Fonts.Number, TextSize = props.TextSize or 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(s + 6, 0), Size = UDim2.new(1, -(s + 6) - 29, 1, 0), TextWrapped = false, Parent = f })
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
	-- A finger only drags once it moves sideways (8 px), so swiping up a scrolling list over a slider scrolls the list
	-- instead of changing the volume; a tap still sets it. The list stops scrolling while you drag.
	local touchFrom: Vector3? = nil
	local scroller: ScrollingFrame? = nil
	local function hold(on: boolean)
		scroller = scroller or track:FindFirstAncestorWhichIsA("ScrollingFrame")
		if scroller then scroller.ScrollingEnabled = not on end
	end
	local function begin(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 then
			dragging = true
			fromX(input.Position.X)
		elseif t == Enum.UserInputType.Touch then
			touchFrom = input.Position
		end
	end
	track.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(input)
		if touchFrom and input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - touchFrom
			if math.abs(d.X) > 8 and math.abs(d.X) > math.abs(d.Y) then
				touchFrom, dragging = nil, true
				hold(true)
			elseif math.abs(d.Y) > 8 then
				touchFrom = nil -- (a swipe up or down: the list scrolls)
			end
		end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if touchFrom and t == Enum.UserInputType.Touch then -- a tap
			fromX(touchFrom.X)
			touchFrom = nil
			if props.onCommit then props.onCommit(value) end
			return
		end
		if dragging and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			dragging = false
			hold(false)
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
