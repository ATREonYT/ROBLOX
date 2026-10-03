-- Hood UI kit: design tokens and factories for the cartoony "sticker" look.
--
-- Everything is authored in pixels on a 1280x720 design canvas. Kit.screen() puts a Root frame in the
-- ScreenGui with one UIScale that fits that canvas to the real screen (bigger on phones), so components
-- only use Offset sizes plus Scale positions/AnchorPoints to pin themselves to edges.
--
-- The look, from the research notes (research_notes/.../ui_visual_design.md):
--   * every element reads as a physical object: ink outline, lit top, darker bottom lip, hard shadow
--   * colour means something: yellow = primary/Power, green = buy/Cash, red = close, blue = info
--   * three fonts at most, a fixed type scale, a fixed spacing and radius scale
--   * illustrated sticker icons (hood/art/icons), never emoji
-- Not wired into the game yet: UIKitDemo builds sample screens with it.
local Kit = {}

local function hex(h)
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
Kit.hex = hex

---------------------------------------------------------------------------------------------- tokens
Kit.Color = {
	ink = hex('1C1830'), -- every outer outline and hard shadow
	asphalt = hex('2B2E45'), -- dark wells, bar tracks
	asphaltLine = hex('FFD23F'),
	cardboard = hex('FFEFD2'), -- default panel body
	cardboardInset = hex('F4D9A8'),
	cardboardEdge = hex('C99A5B'),
	brick = hex('E2553D'),
	brickLip = hex('9C2F22'),
	concrete = hex('D9D4CC'),
	tape = hex('F3E6C4'),
	white = hex('FFFFFF'),
	power = hex('FFC21A'),
	cash = hex('3FD46B'),
}
-- Function colours: top highlight / base / bottom lip / outline-and-text-stroke.
Kit.Tone = {
	yellow = { top = hex('FFE76A'), base = hex('FFC21A'), lip = hex('D57D00'), stroke = hex('5A2E00') },
	green = { top = hex('8CF06A'), base = hex('43C24A'), lip = hex('23802C'), stroke = hex('123F17') },
	red = { top = hex('FF8A8A'), base = hex('FF4757'), lip = hex('B01E35'), stroke = hex('4A0B16') },
	blue = { top = hex('7CCBFF'), base = hex('2F9BFF'), lip = hex('1A5FB4'), stroke = hex('0B2A55') },
	purple = { top = hex('D7A6FF'), base = hex('A64DFF'), lip = hex('6A22B8'), stroke = hex('2A0B4E') },
	cardboard = { top = hex('FFF8EA'), base = hex('FFEFD2'), lip = hex('C99A5B'), stroke = hex('5C3A12') },
	grey = { top = hex('E6E2DC'), base = hex('C4BFB8'), lip = hex('8D877F'), stroke = hex('3A3631') },
}
-- Cross-industry rarity ladder (white, green, blue, purple, gold), extended upward.
Kit.Rarity = {
	{ name = 'COMMON', color = hex('B8BEC8') },
	{ name = 'UNCOMMON', color = hex('5BD45B') },
	{ name = 'RARE', color = hex('3D9BFF') },
	{ name = 'EPIC', color = hex('A64DFF') },
	{ name = 'LEGENDARY', color = hex('FFB020') },
	{ name = 'MYTHIC', color = hex('FF3B5C') },
}
Kit.Font = {
	display = Font.new('rbxasset://fonts/families/LuckiestGuy.json'),
	number = Font.new('rbxasset://fonts/families/BuilderSans.json', Enum.FontWeight.ExtraBold),
	body = Font.new('rbxasset://fonts/families/BuilderSans.json', Enum.FontWeight.Bold),
	tag = Font.new('rbxasset://fonts/families/PermanentMarker.json'),
}
Kit.Text = { title = 40, cta = 30, button = 24, label = 18, small = 15 } -- at the 1280x720 design size
Kit.Space = { xs = 4, s = 8, m = 16, l = 24, xl = 32 }
Kit.Radius = { s = 8, m = 14, l = 22 }
Kit.Stroke = { outline = 3, heavy = 4 }
Kit.Lip = 6 -- depth of the darker bottom lip on raised things
Kit.Shadow = 4 -- hard drop shadow, straight down

-- Uploaded icon images (hood/art/icons). Paste the asset ids here after uploading; an empty id falls back
-- to a lettered badge so screens still work before the upload.
Kit.Icons = {
	power = '', cash = '', outfits = '', crew = '', rebirth = '', gift = '', codes = '',
	trophy = '', settings = '', stages = '', train = '',
}
local ICON_FALLBACK = {
	power = { 'P', 'yellow' }, cash = { '$', 'green' }, outfits = { 'D', 'red' }, crew = { 'C', 'yellow' }, rebirth = { 'R', 'purple' },
	gift = { 'G', 'red' }, codes = { '#', 'blue' }, trophy = { '1', 'yellow' }, settings = { 'S', 'grey' }, stages = { 'GO', 'green' }, train = { 'T', 'red' },
}

---------------------------------------------------------------------------------------------- building blocks
-- new('Frame', {props}, {children}) with Parent set last.
local function new(class, props, children)
	local inst = Instance.new(class)
	local parent = props and props.Parent
	for k, v in props or {} do
		if k ~= 'Parent' then inst[k] = v end
	end
	for _, child in children or {} do child.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end
Kit.new = new

local function corner(r) return new('UICorner', { CornerRadius = typeof(r) == 'UDim' and r or UDim.new(0, r) }) end
local function stroke(color, thickness, border, transparency)
	return new('UIStroke', {
		Color = color, Thickness = thickness, Transparency = transparency or 0, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	})
end
local function vgradient(top, bottom, split)
	-- Light from the top only: one angle everywhere.
	return new('UIGradient', {
		Rotation = 90,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(split or 0.5, bottom), ColorSequenceKeypoint.new(1, bottom) }),
	})
end
local function blank(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	return new('Frame', props)
end
Kit.corner, Kit.stroke, Kit.gradient = corner, stroke, vgradient

-- Text with a stroke ~10% of its size, in the colour of whatever it sits on.
function Kit.text(props)
	local size = props.TextSize or Kit.Text.label
	local strokeColor = props.Stroke
	props.Stroke = nil
	local t = new('TextLabel', {
		Name = props.Name or 'Label', BackgroundTransparency = 1, BorderSizePixel = 0,
		FontFace = props.FontFace or Kit.Font.display, TextSize = size, TextColor3 = props.TextColor3 or Kit.Color.white,
		Text = props.Text or '', Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center, TextWrapped = props.TextWrapped or false,
		ZIndex = props.ZIndex or 1, Rotation = props.Rotation or 0, RichText = props.RichText or false,
	})
	if strokeColor then stroke(strokeColor, math.max(1.5, size * 0.1)).Parent = t end
	t.Parent = props.Parent
	return t
end

-- A sticker icon. Uses the uploaded image when there is one, otherwise a lettered badge.
function Kit.icon(name, size, props)
	props = props or {}
	local id = Kit.Icons[name] or ''
	local holder = blank({ Name = 'Icon_' .. name, Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 1, Rotation = props.Rotation or 0 })
	if id ~= '' or props.Preview ~= false then
		local img = new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = id, ScaleType = Enum.ScaleType.Fit, ZIndex = props.ZIndex or 1, Parent = holder })
		img:SetAttribute('PreviewImage', name) -- the offline previewer draws hood/art/icons/<name>.png here
		if id ~= '' then return holder end
	end
	local fb = ICON_FALLBACK[name] or { '?', 'grey' }
	local tone = Kit.Tone[fb[2]]
	local badge = blank({ Name = 'Fallback', Size = UDim2.fromScale(0.82, 0.82), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0, BackgroundColor3 = tone.base, ZIndex = props.ZIndex or 1, Parent = holder }, nil)
	corner(UDim.new(0.5, 0)).Parent = badge
	stroke(Kit.Color.white, size * 0.06, true).Parent = badge
	Kit.text({ Text = fb[1], TextSize = size * 0.5, Stroke = tone.stroke, ZIndex = (props.ZIndex or 1) + 1, Parent = badge })
	if props.Preview == false then return holder end
	badge.Visible = false -- only shown in game while the image id is empty (UIKit.useFallbacks)
	return holder
end
-- In game, call once at startup: shows lettered badges for icons that have no uploaded image yet.
function Kit.useFallbacks(root)
	for _, d in root:GetDescendants() do
		if d.Name == 'Fallback' and d.Parent and d.Parent:FindFirstChild('Image') and d.Parent.Image.Image == '' then
			d.Visible = true
			d.Parent.Image.Visible = false
		end
	end
end

---------------------------------------------------------------------------------------------- screen + scaling
-- ScreenGui with a Root frame sized to the 1280x720 design canvas and a UIScale that fits it to the screen.
-- Phones (short side <= 500, Roblox's own TouchJump rule) get a 1.3x bonus so touch targets stay >= ~44 pt.
Kit.Reference = Vector2.new(1280, 720)
function Kit.scaleFor(abs)
	local k = math.min(abs.X / Kit.Reference.X, abs.Y / Kit.Reference.Y)
	if math.min(abs.X, abs.Y) <= 500 then k *= 1.3 end
	return math.clamp(k, 0.5, 1.6)
end
function Kit.screen(name, parent, displayOrder)
	local gui = new('ScreenGui', {
		Name = name, ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = displayOrder or 0,
	})
	local root = blank({ Name = 'Root', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = new('UIScale', { Parent = root })
	local function fit(abs)
		local k = Kit.scaleFor(abs)
		scale.Scale = k
		root.Size = UDim2.fromScale(1 / k, 1 / k) -- after scaling, Root exactly fills the screen
	end
	gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
	gui.Parent = parent
	if parent then fit(gui.AbsoluteSize) end -- only meaningful once it is on screen
	return gui, root, fit
end

---------------------------------------------------------------------------------------------- components
-- Raised button: ink-outlined lip, gradient body, gloss band, highlight line, outlined label, optional icon.
-- Returns holder; holder.Hit is the TextButton that takes input. UIMotion.button() adds the press feel.
function Kit.button(props)
	local tone = Kit.Tone[props.Disabled and 'grey' or props.Tone or 'yellow']
	local w, h = props.Width or 168, props.Height or 60
	local r = props.Radius or Kit.Radius.m
	local rPx = typeof(r) == 'UDim' and (r.Scale * math.min(w, h) + r.Offset) or r -- pills pass UDim.new(0.5, 0)
	local lip = props.Lip or Kit.Lip
	local holder = blank({ Name = props.Name or 'Button', Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = props.ZIndex or 1 })
	local z = props.ZIndex or 1
	local shadow = blank({ Name = 'Shadow', BackgroundTransparency = 0.55, BackgroundColor3 = Kit.Color.ink, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, Kit.Shadow), ZIndex = z, Parent = holder })
	corner(r).Parent = shadow
	local lipFrame = blank({ Name = 'Lip', BackgroundTransparency = 0, BackgroundColor3 = tone.lip, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = holder })
	corner(r).Parent = lipFrame
	stroke(Kit.Color.ink, Kit.Stroke.outline, true).Parent = lipFrame
	local body = blank({ Name = 'Body', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.new(1, 0, 1, -lip), ZIndex = z + 2, Parent = holder })
	corner(r).Parent = body
	vgradient(tone.top, tone.base, 0.55).Parent = body
	local gloss = blank({ Name = 'Gloss', BackgroundTransparency = 0.78, BackgroundColor3 = Kit.Color.white, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(1, -10, 0.45, -3), ZIndex = z, Parent = body })
	corner(math.max(2, rPx - 4)).Parent = gloss
	gloss.Visible = not props.Disabled
	local line = blank({ Name = 'Highlight', BackgroundTransparency = 0.25, BackgroundColor3 = Kit.Color.white, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(1, -2 * rPx, 0, 3), ZIndex = z, Parent = body })
	corner(UDim.new(0.5, 0)).Parent = line
	local textSize = props.TextSize or Kit.Text.button
	local textLeft = 0
	if props.Icon then
		local s = props.IconSize or math.floor((h - lip) * 0.86)
		Kit.icon(props.Icon, s, { Position = UDim2.new(0, props.IconInset or 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 1 }).Parent = body
		textLeft = s + (props.IconInset or 6)
	end
	if props.Text then
		Kit.text({ Name = 'Label', Text = props.Text, TextSize = textSize, FontFace = props.FontFace or Kit.Font.display, Stroke = tone.stroke, Size = UDim2.new(1, -textLeft - 8, 1, 0), Position = UDim2.new(0, textLeft + 4, 0, 1), ZIndex = z + 1, Parent = body })
	end
	local hit = new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = holder })
	holder:SetAttribute('Lip', lip)
	return holder, hit
end

-- Currency pill: sticker icon overlapping the left end, abbreviated number, green "+" on the right end.
function Kit.currency(props)
	local w, h = props.Width or 230, props.Height or 46
	local iconSize = props.IconSize or math.floor(h * 1.35)
	local holder = blank({ Name = props.Name or 'Currency', Size = UDim2.fromOffset(w, iconSize), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0 })
	local dark = props.Style ~= 'light'
	local body = blank({ Name = 'Body', BackgroundTransparency = 0, BackgroundColor3 = dark and Kit.Color.asphalt or Kit.Color.cardboard, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, iconSize * 0.45, 0.5, 0), Size = UDim2.new(1, -iconSize * 0.45, 0, h), Parent = holder })
	corner(UDim.new(0.5, 0)).Parent = body
	stroke(Kit.Color.ink, Kit.Stroke.outline, true).Parent = body
	vgradient(dark and Kit.hex('3A3E5C') or Kit.Color.white, dark and Kit.Color.asphalt or Kit.Color.cardboard, 0.5).Parent = body
	local line = blank({ Name = 'Highlight', BackgroundTransparency = dark and 0.8 or 0.2, BackgroundColor3 = Kit.Color.white, Position = UDim2.new(0, iconSize * 0.45, 0, 4), Size = UDim2.new(1, -iconSize * 0.45 - h * 0.6, 0, 3), Parent = body })
	corner(UDim.new(0.5, 0)).Parent = line
	local value = Kit.text({
		Name = 'Value', Text = props.Text or '0', FontFace = Kit.Font.number, TextSize = props.TextSize or math.floor(h * 0.62),
		TextColor3 = dark and Kit.Color.white or Kit.Color.ink, Stroke = dark and Kit.Color.ink or nil,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, iconSize * 0.62, 0, 0), Size = UDim2.new(1, -iconSize * 0.62 - h, 1, 0), Parent = body,
	})
	if props.Plus ~= false then
		local plus = Kit.button({ Name = 'Plus', Tone = 'green', Width = h - 8, Height = h - 6, Radius = UDim.new(0.5, 0), Lip = 4, Text = '+', TextSize = math.floor(h * 0.62), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, -1) })
		plus.Parent = body
	end
	Kit.icon(props.Icon or 'power', iconSize, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 2 }).Parent = holder
	return holder, value
end

-- Square side button with a sticker icon, a label overlapping the bottom edge, and an optional badge.
function Kit.sideButton(props)
	local s = props.Size or 76
	local tone = Kit.Tone[props.Tone or 'cardboard']
	local holder, hit = Kit.button({ Name = props.Name, Tone = props.Tone or 'cardboard', Width = s, Height = s, Radius = Kit.Radius.l * 0.8, Lip = 6, LayoutOrder = props.LayoutOrder, Position = props.Position, AnchorPoint = props.AnchorPoint })
	Kit.icon(props.Icon, math.floor(s * 0.86), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -4), ZIndex = 3, Rotation = props.Tilt or 0 }).Parent = holder.Body
	if props.Text then
		Kit.text({ Name = 'Caption', Text = props.Text, TextSize = Kit.Text.small + 1, Stroke = Kit.Color.ink, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 16, 0, 20), ZIndex = 5, Parent = holder })
	end
	if props.Badge then
		local badge = blank({ Name = 'Badge', BackgroundTransparency = 0, BackgroundColor3 = Kit.Tone.red.base, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26), ZIndex = 6, Parent = holder })
		corner(UDim.new(0.5, 0)).Parent = badge
		stroke(Kit.Color.ink, 2.5, true).Parent = badge
		Kit.text({ Text = tostring(props.Badge), TextSize = 17, Stroke = Kit.Tone.red.stroke, ZIndex = 6, Parent = badge })
	end
	return holder, hit, tone
end

-- Progress bar: asphalt track with road-line dashes, gradient fill with a gloss band, outlined text on top.
function Kit.progress(props)
	local w, h = props.Width or 360, props.Height or 26
	local tone = Kit.Tone[props.Tone or 'yellow']
	local track = blank({ Name = props.Name or 'Progress', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.asphalt, Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0 })
	corner(UDim.new(0.5, 0)).Parent = track
	stroke(Kit.Color.ink, Kit.Stroke.outline, true).Parent = track
	for x = 0.1, 0.95, 0.1 do
		local dash = blank({ BackgroundTransparency = 0.7, BackgroundColor3 = Kit.Color.asphaltLine, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromOffset(10, 3), Parent = track })
		corner(UDim.new(0.5, 0)).Parent = dash
	end
	local fill = blank({ Name = 'Fill', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.fromScale(math.clamp(props.Value or 0, 0.06, 1), 1), ZIndex = 2, Parent = track })
	corner(UDim.new(0.5, 0)).Parent = fill
	vgradient(tone.top, tone.base, 0.5).Parent = fill
	local gloss = blank({ BackgroundTransparency = 0.6, BackgroundColor3 = Kit.Color.white, Position = UDim2.new(0, h * 0.4, 0, 3), Size = UDim2.new(1, -h * 0.8, 0, math.max(2, h * 0.16)), ZIndex = 3, Parent = fill })
	corner(UDim.new(0.5, 0)).Parent = gloss
	local label = props.Text and Kit.text({ Name = 'Text', Text = props.Text, FontFace = Kit.Font.number, TextSize = props.TextSize or math.floor(h * 0.7), Stroke = Kit.Color.ink, ZIndex = 4, Parent = track })
	return track, fill, label
end

-- Popup panel: dimmed backdrop, cardboard body with an inner well, brick header ribbon held by tape, red X.
function Kit.modal(root, props)
	local overlay = blank({ Name = (props.Name or 'Modal') .. 'Overlay', BackgroundTransparency = 0.5, BackgroundColor3 = Kit.Color.ink, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local w, h = props.Width or 860, props.Height or 520
	local panel = blank({ Name = props.Name or 'Modal', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.cardboard, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 18), Size = UDim2.fromOffset(w, h), ZIndex = 21, Parent = overlay })
	corner(Kit.Radius.l).Parent = panel
	stroke(Kit.Color.ink, Kit.Stroke.heavy, true).Parent = panel
	local shadow = blank({ Name = 'Shadow', BackgroundTransparency = 0.45, BackgroundColor3 = Kit.Color.ink, AnchorPoint = panel.AnchorPoint, Position = UDim2.new(0.5, 0, 0.5, 18 + 8), Size = panel.Size, ZIndex = 20, Parent = overlay })
	corner(Kit.Radius.l).Parent = shadow
	local edge = blank({ Name = 'Edge', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.cardboardEdge, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, Kit.Radius.l + 8), ZIndex = 21, Parent = panel })
	corner(Kit.Radius.l).Parent = edge
	local face = blank({ Name = 'Face', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.cardboard, Size = UDim2.new(1, 0, 1, -8), ZIndex = 22, Parent = panel })
	corner(Kit.Radius.l).Parent = face
	local well = blank({ Name = 'Content', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.cardboardInset, Position = UDim2.fromOffset(Kit.Space.m, 52), Size = UDim2.new(1, -2 * Kit.Space.m, 1, -52 - Kit.Space.m - 8), ZIndex = 23, Parent = panel })
	corner(Kit.Radius.m).Parent = well
	stroke(Kit.hex('E2C08A'), 2, true).Parent = well
	-- Header ribbon overlapping the top edge, with two strips of tape.
	local ribbonW = props.TitleWidth or 340
	local ribbon = blank({ Name = 'Header', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.brickLip, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(ribbonW, 62), ZIndex = 24, Parent = panel })
	corner(Kit.Radius.m).Parent = ribbon
	stroke(Kit.Color.ink, Kit.Stroke.heavy, true).Parent = ribbon
	local ribbonFace = blank({ Name = 'Face', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.new(1, 0, 1, -6), ZIndex = 24, Parent = ribbon })
	corner(Kit.Radius.m).Parent = ribbonFace
	vgradient(Kit.hex('F07A62'), Kit.Color.brick, 0.5).Parent = ribbonFace
	Kit.text({ Name = 'Title', Text = props.Title or 'TITLE', TextSize = Kit.Text.title, Stroke = Kit.Color.brickLip, Position = UDim2.fromOffset(0, 3), ZIndex = 25, Parent = ribbonFace })
	for _, side in { -1, 1 } do
		local tape = blank({ Name = 'Tape', BackgroundTransparency = 0.12, BackgroundColor3 = Kit.Color.tape, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * (ribbonW / 2 - 8), 0, 4), Size = UDim2.fromOffset(54, 20), Rotation = side * 14, ZIndex = 26, Parent = ribbon })
		stroke(Kit.hex('D9C9A0'), 1.5, true).Parent = tape
	end
	local close, closeHit = Kit.button({ Name = 'Close', Tone = 'red', Width = 56, Height = 58, Radius = UDim.new(0.5, 0), Lip = 6, Text = 'X', TextSize = 30, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -10, 0, 8), ZIndex = 26 })
	close.Parent = panel
	return panel, well, closeHit, overlay
end

-- Item card for shops and inventories. state: 'locked' | 'owned' | 'equipped' | nil
function Kit.card(props)
	local w, h = props.Width or 150, props.Height or 192
	local rarity = Kit.Rarity[props.Rarity or 1]
	local card = blank({ Name = props.Name or 'Card', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.fromOffset(w, h), LayoutOrder = props.LayoutOrder or 0, ZIndex = props.ZIndex or 1 })
	local z = props.ZIndex or 1
	corner(Kit.Radius.m).Parent = card
	local selected = props.Selected
	stroke(selected and Kit.Color.power or Kit.Color.ink, selected and 5 or Kit.Stroke.outline, true).Parent = card
	local light = rarity.color:Lerp(Kit.Color.white, 0.55)
	vgradient(light, rarity.color:Lerp(Kit.Color.cardboardInset, 0.25), 0.7).Parent = card
	-- Rays behind the item for Legendary and up.
	if (props.Rarity or 1) >= 5 then
		for k = 0, 5 do
			local ray = blank({ BackgroundTransparency = 0.72, BackgroundColor3 = Kit.Color.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(14, math.min(w, h) - 18), Rotation = k * 30, ZIndex = z, Parent = card })
			corner(UDim.new(0.5, 0)).Parent = ray
		end
	end
	local art = new('ImageLabel', { Name = 'Art', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(w - 24, h - 74), ScaleType = Enum.ScaleType.Fit, Image = props.Image or '', ZIndex = z + 1, Parent = card })
	if props.Preview then art:SetAttribute('PreviewImage', props.Preview) end
	-- Locked looks keep their name a secret; long names step down a size instead of overflowing.
	local title = props.State == 'locked' and '???' or (props.Title or 'ITEM')
	local titleSize = #title <= 9 and 19 or (#title <= 12 and 16 or 14)
	Kit.text({ Name = 'ItemName', Text = title, TextSize = titleSize, Stroke = rarity.color:Lerp(Kit.Color.ink, 0.6), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -38), Size = UDim2.new(1, -10, 0, 22), ZIndex = z + 2, Parent = card })
	-- Price pill (or the state when owned).
	local pill = blank({ Name = 'Price', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.asphalt, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 26), ZIndex = z + 2, Parent = card })
	corner(UDim.new(0.5, 0)).Parent = pill
	stroke(Kit.Color.ink, 2.5, true).Parent = pill
	local state = props.State
	if state == 'equipped' or state == 'owned' then
		pill.BackgroundColor3 = state == 'equipped' and Kit.Tone.yellow.base or Kit.Tone.green.base
		Kit.text({ Text = state == 'equipped' and 'WEARING' or 'OWNED', TextSize = 16, Stroke = state == 'equipped' and Kit.Tone.yellow.stroke or Kit.Tone.green.stroke, ZIndex = z + 3, Parent = pill })
	else
		Kit.icon('power', 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -6, 0.5, 0), ZIndex = z + 3 }).Parent = pill
		Kit.text({ Text = props.Price or 'FREE', FontFace = Kit.Font.number, TextSize = 17, Stroke = Kit.Color.ink, Position = UDim2.fromOffset(10, 0), ZIndex = z + 3, Parent = pill })
	end
	local tag = blank({ Name = 'Rarity', BackgroundTransparency = 0, BackgroundColor3 = rarity.color, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(-6, 14), Size = UDim2.fromOffset(math.max(70, #rarity.name * 9 + 14), 22), Rotation = -6, ZIndex = z + 3, Parent = card })
	corner(6).Parent = tag
	stroke(Kit.Color.ink, 2, true).Parent = tag
	Kit.text({ Text = rarity.name, TextSize = 13, Stroke = rarity.color:Lerp(Kit.Color.ink, 0.6), ZIndex = z + 4, Parent = tag })
	if state == 'locked' then
		local shade = blank({ Name = 'Locked', BackgroundTransparency = 0.3, BackgroundColor3 = Kit.Color.ink, Size = UDim2.new(1, 0, 1, -62), ZIndex = z + 1, Parent = card })
		corner(Kit.Radius.m).Parent = shade
		local shackle = blank({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, -18), Size = UDim2.fromOffset(30, 34), ZIndex = z + 6, Parent = shade })
		corner(UDim.new(0.5, 0)).Parent = shackle
		stroke(Kit.Color.concrete, 7, true).Parent = shackle
		local lock = blank({ BackgroundTransparency = 0, BackgroundColor3 = Kit.Tone.yellow.base, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(46, 36), ZIndex = z + 7, Parent = shade })
		corner(8).Parent = lock
		stroke(Kit.Color.ink, 3, true).Parent = lock
		blank({ BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.ink, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 14), ZIndex = z + 8, Parent = lock })
	end
	return card
end

-- Speech-bubble objective card for the tutorial / next step.
function Kit.objective(props)
	local w, h = props.Width or 420, props.Height or 74
	local holder = blank({ Name = props.Name or 'Objective', Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero })
	local shadow = blank({ Name = 'Shadow', BackgroundTransparency = 0.55, BackgroundColor3 = Kit.Color.ink, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, Kit.Shadow), ZIndex = 1, Parent = holder })
	corner(Kit.Radius.m).Parent = shadow
	local card = blank({ Name = 'Card', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.cardboard, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = holder })
	corner(Kit.Radius.m).Parent = card
	stroke(Kit.Color.ink, Kit.Stroke.outline, true).Parent = card
	if props.Icon then Kit.icon(props.Icon, 64, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -16, 0.5, -4), ZIndex = 3, Rotation = -8 }).Parent = card end
	Kit.text({ Name = 'Step', Text = props.Text or '', FontFace = Kit.Font.body, TextSize = Kit.Text.label, TextColor3 = Kit.Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -72, 0, 26), ZIndex = 2, Parent = card })
	local bar = Kit.progress({ Width = w - 72, Height = 22, Value = props.Value, Text = props.Progress, Position = UDim2.fromOffset(60, 40), Tone = 'yellow' })
	bar.ZIndex = 2
	bar.Parent = card
	return holder
end

-- Short stacking notification.
function Kit.toast(props)
	local tone = Kit.Tone[props.Tone or 'green']
	local holder = blank({ Name = 'Toast', BackgroundTransparency = 0, BackgroundColor3 = tone.base, Size = UDim2.fromOffset(props.Width or 320, 44), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero })
	corner(UDim.new(0.5, 0)).Parent = holder
	stroke(Kit.Color.ink, Kit.Stroke.outline, true).Parent = holder
	vgradient(tone.top, tone.base, 0.6).Parent = holder
	if props.Icon then Kit.icon(props.Icon, 52, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -8, 0.5, 0), ZIndex = 2 }).Parent = holder end
	Kit.text({ Text = props.Text or '', TextSize = Kit.Text.label + 2, Stroke = tone.stroke, Position = UDim2.fromOffset(props.Icon and 22 or 0, 1), ZIndex = 2, Parent = holder })
	return holder
end

-- 1234 -> "1.2K", 15300000 -> "15.3M"
function Kit.short(n)
	local units = { 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx' }
	if n < 1000 then return tostring(math.floor(n)) end
	local i = math.min(#units, math.floor(math.log10(n) / 3))
	local v = n / 10 ^ (i * 3)
	local s = v >= 100 and string.format('%d', v) or string.format('%.1f', math.floor(v * 10) / 10):gsub('%.0$', '')
	return s .. units[i]
end

return Kit
