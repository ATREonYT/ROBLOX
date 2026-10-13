-- ArtKit (brief 30, MOCKUP): the reusable pieces of the user's seven World 1 shoe UI artboards (the handoff
-- "World1-Shoe-UI-Handoff"), as native Roblox UI. The studded look: thick near-black outlines, saturated vertical
-- gradients (cyan headers, green / blue / orange / red / grey buttons), dark navy studded bodies, dark inset cards with a
-- thick coloured frame, big heavy white text with a dark outline. Text is always a real TextLabel over the art.
--
-- Every size is in ARTBOARD pixels: a screen is laid out with the artboard's own numbers and one UIScale fits the whole
-- panel to the screen (ArtKit.fit). On a small screen (a phone) the scale never drops below the point where the smallest
-- text would read under ArtKit.MinScreenText px: the panel keeps that scale and its body scrolls instead.
--
--   ArtKit.text(parent, text, props)            outlined text (Size, X, Y, W, H, Color, Align, Font, Gradient, Z ...)
--   ArtKit.block(parent, props)                 a rounded block: Tone gradient or Fill, Outline, Studs, Gloss
--   ArtKit.framed(parent, props)                a dark inset card in a thick coloured frame (Border, Inner, Glow)
--   ArtKit.button(parent, props)                a studded button with icon + label; states via ArtKit.setState
--   ArtKit.closeX(parent, props)                the red square X
--   ArtKit.panel(parent, props) -> P            header (icon, title, X) + scrolling body + fixed footer
--   ArtKit.fit(P, absSize) / ArtKit.place(P, x, y, scale)
--   ArtKit.shoeArt(parent, id, props)           the shoe's original PNG (Shoe_<Id>), fit/contain, never cropped
--   ArtKit.boxArt(parent, boxId, props)         the box's PNG (Box_<Id>)
--   ArtKit.pill / toggle / tabs / dropdown / search / glyphs (tick, check, padlock, chevron, arrow, info, radio,
--   sparkle, crown, gift, book, sunburst)
--   ArtKit.rarity(idOrRank) -> { Id, Name, Color, Rank, Rainbow }   the ONE rarity colour map (Config/Shoes.Rarities)
--   ArtKit.Family[boxId]                         the four World 1 box families (display names Street / Graffiti / Chrome /
--                                                 Crown, brief 30 rule 12) and their colours
--   ArtKit.shoeName(id), ArtKit.boxName(boxId)   spaced display names (the handoff's table = Config/Shoes names)
local Shared = script.Parent
local Kit = require(Shared.UIKit)
local Fonts = require(Shared.Fonts)
local Shoes = require(Shared.Config.Shoes)
local Motion = require(Shared.UIMotion)

local ArtKit = {}
local hex, new = Kit.hex, Kit.new
local px = UDim2.fromOffset
local WHITE = Color3.new(1, 1, 1)

ArtKit.Ink = hex('05070D') -- every outline
ArtKit.MinScreenText = 11 -- screen px: no text smaller than this (phones scroll instead)
ArtKit.Font = { Title = Fonts.Title, Body = Fonts.Body }

-- Tones, sampled on the artboards: top -> base of the vertical gradient, `rim` the light line inside the outline,
-- `text` the colour of a label on it.
ArtKit.Tone = {
	cyan = { top = hex('5EF2FE'), base = hex('0898F6'), rim = hex('C8FDFF') },
	green = { top = hex('5CF566'), base = hex('0CC628'), rim = hex('B6FFBA') },
	blue = { top = hex('34ACFF'), base = hex('0064EC'), rim = hex('A8DCFF') },
	red = { top = hex('FF4255'), base = hex('DC0820'), rim = hex('FFA4AE') },
	orange = { top = hex('FFAA30'), base = hex('F0520A'), rim = hex('FFD89A') },
	yellow = { top = hex('FFE24A'), base = hex('F0A206'), rim = hex('FFF4AE') },
	grey = { top = hex('DCE0E6'), base = hex('9AA2B0'), rim = hex('F6F8FA') },
	disabled = { top = hex('8C95A4'), base = hex('6B7484'), rim = hex('AEB6C2'), text = hex('C2C8D2') },
	dark = { top = hex('20304A'), base = hex('142236'), rim = hex('34506E') },
	purple = { top = hex('C866FF'), base = hex('7A1AD8'), rim = hex('E6B8FF') },
	magenta = { top = hex('FF5AD6'), base = hex('BE10A0'), rim = hex('FFB8F0') },
	pink = { top = hex('FF6CC8'), base = hex('E4168C'), rim = hex('FFC0E6') },
	navy = { top = hex('163450'), base = hex('0D2438'), rim = hex('23506E') },
	gold = { top = hex('FFE65A'), base = hex('FFB000'), rim = hex('FFF6B8') },
}
local function toneOf(t)
	if type(t) == 'string' then return ArtKit.Tone[t] or ArtKit.Tone.blue end
	return t
end
ArtKit.toneOf = toneOf

---------------------------------------------------------------------------------------------- names, rarity, families
-- The four World 1 box families (the handoff: Street white/red, Graffiti pink/cyan, Chrome silver/charcoal/cyan, Crown
-- purple/gold). Keyed by the config box id (Exclusive is shown as Chrome, Grail as Crown: brief 30 rule 12).
ArtKit.Family = {
	Street = { Id = 'Street', Name = 'Street', Box = 'Street Box', Card = { hex('F2384A'), hex('A40E22') }, Border = hex('FF6A4A'), Head = 'cyan', Body = nil },
	Graffiti = { Id = 'Graffiti', Name = 'Graffiti', Box = 'Graffiti Box', Card = { hex('F64CE0'), hex('8E1898') }, Border = hex('FF5AE6'), Head = 'cyan', Body = hex('F0288E') },
	Exclusive = { Id = 'Exclusive', Name = 'Chrome', Box = 'Chrome Box', Card = { hex('1E86F0'), hex('0C2E72') }, Border = hex('32D2FF'), Head = 'cyan', Body = nil },
	Grail = { Id = 'Grail', Name = 'Crown', Box = 'Crown Box', Card = { hex('A43CF4'), hex('4A1490') }, Border = hex('B65CFF'), Head = 'purple', Body = nil },
}
ArtKit.FamilyOrder = { 'Street', 'Graffiti', 'Exclusive', 'Grail' }
function ArtKit.boxName(boxId)
	local f = ArtKit.Family[boxId]
	if f then return f.Box end
	local box = Shoes.BoxById[boxId]
	return box and box.Name or tostring(boxId)
end
function ArtKit.familyName(boxId)
	local f = ArtKit.Family[boxId]
	return f and f.Name or ArtKit.boxName(boxId)
end
function ArtKit.shoeName(id)
	local s = Shoes.ById[id]
	return s and s.Name or tostring(id)
end

-- The one rarity map: Config/Shoes.Rarities (Common grey, Rare blue, Epic purple, Legendary orange, Mythic red,
-- Secret rainbow). Every screen reads this; nothing infers a rarity from a border.
function ArtKit.rarity(x)
	local r
	if type(x) == 'number' then r = Shoes.Rarities[x]
	elseif type(x) == 'string' then r = Shoes.RarityById[x] or (Shoes.ById[x] and Shoes.RarityById[Shoes.ById[x].Rarity]) end
	r = r or Shoes.Rarities[1]
	return { Id = r.Id, Name = r.Name, Color = r.Color, Rank = r.Rank, Rainbow = r.Rank == #Shoes.Rarities }
end
function ArtKit.rainbowSeq()
	local keys = {}
	for i, c in Shoes.Rainbow do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#Shoes.Rainbow - 1), c)) end
	return ColorSequence.new(keys)
end

---------------------------------------------------------------------------------------------- primitives
local function corner(parent, r)
	return new('UICorner', { CornerRadius = typeof(r) == 'UDim' and r or UDim.new(0, r), Parent = parent })
end
local function stroke(parent, color, thickness, border, transparency)
	return new('UIStroke', {
		Color = color, Thickness = thickness, Transparency = transparency or 0, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual, Parent = parent,
	})
end
local function vgrad(parent, top, base, split)
	return new('UIGradient', { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(split or 1, base), ColorSequenceKeypoint.new(1, base) }), Parent = parent })
end
ArtKit.corner, ArtKit.stroke, ArtKit.vgrad = corner, stroke, vgrad

local function rect(props)
	return (props.Pos or px(props.X or 0, props.Y or 0)), (props.Box or px(props.W or 100, props.H or 40))
end
function ArtKit.frame(parent, props)
	props = props or {}
	local pos, size = rect(props)
	local f = new('Frame', {
		Name = props.Name or 'Frame', BackgroundColor3 = props.Fill or WHITE, BackgroundTransparency = props.Fill and (props.Transparency or 0) or 1,
		BorderSizePixel = 0, Position = pos, Size = size, AnchorPoint = props.Anchor or Vector2.zero, Rotation = props.Rotation or 0,
		ZIndex = props.Z or 1, ClipsDescendants = props.Clip or false, Visible = props.Visible ~= false, Parent = parent,
	})
	if props.Radius then corner(f, props.Radius) end
	return f
end

-- Outlined text. props: Size (text px), X, Y, W, H (or Pos / Box), Anchor, Color, Align ('Left' | 'Center' | 'Right'),
-- YAlign, Font, Stroke (false: none), StrokeColor, StrokeW, Gradient { top, bottom } or a ColorSequence, Wrap, Z, Name,
-- Fit (shrink the size until the text fits W on one line).
function ArtKit.text(parent, text, props)
	props = props or {}
	local size = props.Size or 28
	local w = props.W or 200
	text = tostring(text or '')
	if props.Fit and not props.Wrap then size = Kit.fitSize(text, size, w - 4, props.MinSize or 12) end
	local pos, box = rect({ Pos = props.Pos, Box = props.Box, X = props.X, Y = props.Y, W = w, H = props.H or math.floor(size * 1.25) })
	local l = new('TextLabel', {
		Name = props.Name or 'Text', BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
		FontFace = props.Font or Fonts.Title, TextSize = size, TextColor3 = props.Color or WHITE,
		TextXAlignment = Enum.TextXAlignment[props.Align or 'Center'], TextYAlignment = Enum.TextYAlignment[props.YAlign or 'Center'],
		TextWrapped = props.Wrap or false, RichText = props.Rich or false, TextTransparency = props.Transparency or 0,
		Position = pos, Size = box, AnchorPoint = props.Anchor or Vector2.zero, ZIndex = props.Z or 1, Parent = parent,
	})
	if props.Stroke ~= false then
		stroke(l, props.StrokeColor or ArtKit.Ink, props.StrokeW or math.max(1.5, math.floor(size * 0.12 + 0.5)), false, props.StrokeT)
	end
	if props.Gradient then
		local g = props.Gradient
		new('UIGradient', { Rotation = props.GradientRot or 90, Color = typeof(g) == 'ColorSequence' and g or ColorSequence.new(g[1], g[2]), Parent = l })
	end
	return l
end

-- A rounded block. props: X, Y, W, H, Anchor, Tone (name or table: a vertical gradient) or Fill (flat), Radius (12),
-- Outline (4; 0 = none), OutlineColor, Studs (pitch px, or false), StudShade, Gloss (a soft light band over the top
-- half, default on with a Tone), Rim (the light line inside the outline, default on with a Tone), Z, Name.
function ArtKit.block(parent, props)
	local tone = props.Tone and toneOf(props.Tone)
	local w, h = props.W or 100, props.H or 40
	local graded = (tone and not props.Fill) or props.Gradient ~= nil
	local f = ArtKit.frame(parent, { Name = props.Name or 'Block', X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Fill = graded and WHITE or (props.Fill or ArtKit.Tone.navy.base), Transparency = props.Transparency, Radius = props.Radius or 12, Z = props.Z })
	if tone and not props.Fill then vgrad(f, tone.top, tone.base, props.Split) end
	if props.Gradient then
		local g = props.Gradient
		new('UIGradient', { Rotation = props.GradientRot or 90, Color = typeof(g) == 'ColorSequence' and g or ColorSequence.new(g[1], g[2]), Parent = f })
	end
	local o = props.Outline or 4
	if o > 0 then stroke(f, props.OutlineColor or ArtKit.Ink, o, true) end
	if props.Studs then
		local s = Kit.studs(f, { Pitch = props.Studs, Width = w, Height = h, Shade = props.StudShade or 0.82, ZIndex = f.ZIndex })
		if s and s:IsA('ImageLabel') then corner(s, props.Radius or 12) end
	end
	if tone and props.Gloss ~= false then
		local g = ArtKit.frame(f, { Name = 'Gloss', X = 5, Y = 4, W = w - 10, H = math.floor(h * 0.42), Fill = WHITE, Transparency = 0.82, Radius = math.max(2, (props.Radius or 12) - 4), Z = f.ZIndex })
		new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = g })
	end
	if tone and props.Rim ~= false then
		local inset = 3
		local r = ArtKit.frame(f, { Name = 'Rim', X = inset, Y = inset, W = w - 2 * inset, H = h - 2 * inset, Radius = math.max(2, (props.Radius or 12) - inset), Z = f.ZIndex })
		stroke(r, tone.rim, 2, true, 0.45)
	end
	return f
end

-- A dark inset card in a thick coloured frame (the artboards' item cards). props: X, Y, W, H, Border (Color3 or
-- 'rainbow'), BorderW (6), Inner (Color3: the card's face, default near-black navy), Radius (14), Outline (3), Glow
-- (Color3: a soft halo outside the frame, the selected card), Z, Name. Returns the outer frame and the inner face.
ArtKit.CardFace = hex('141A22')
function ArtKit.framed(parent, props)
	local w, h = props.W or 200, props.H or 200
	local bw = props.BorderW or 6
	local r = props.Radius or 14
	local outer = ArtKit.frame(parent, { Name = props.Name or 'Card', X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Fill = (props.Border == 'rainbow' or props.BorderGradient) and WHITE or (props.Border or hex('2EC8F4')), Radius = r, Z = props.Z })
	if props.BorderGradient then new('UIGradient', { Rotation = 90, Color = ColorSequence.new(props.BorderGradient[1], props.BorderGradient[2]), Parent = outer }) end
	if props.Border == 'rainbow' then new('UIGradient', { Rotation = 35, Color = ArtKit.rainbowSeq(), Parent = outer }) end
	stroke(outer, props.OutlineColor or ArtKit.Ink, props.Outline or 3, true)
	if props.Glow then
		local glow = ArtKit.frame(outer, { Name = 'Glow', X = -7, Y = -7, W = w + 14, H = h + 14, Fill = props.Glow, Transparency = 0.55, Radius = r + 6, Z = math.max(0, (props.Z or 1) - 1) })
		glow.ZIndex = (props.Z or 1) - 1
	end
	local face = ArtKit.frame(outer, { Name = 'Face', X = bw, Y = bw, W = w - 2 * bw, H = h - 2 * bw, Fill = props.InnerGradient and WHITE or (props.Inner or ArtKit.CardFace), Radius = math.max(3, r - bw + 2), Z = props.Z })
	stroke(face, ArtKit.Ink, 2, true, 0.2)
	if props.InnerGradient then
		local g = props.InnerGradient
		new('UIGradient', { Rotation = props.InnerRot or 90, Color = typeof(g) == 'ColorSequence' and g or ColorSequence.new(g[1], g[2]), Parent = face })
	end
	return outer, face
end

---------------------------------------------------------------------------------------------- art
-- The shoe's original PNG (hood/art/icons3d/Shoe_<Id>.png through IconModels), contain-fit by its DRAWN content
-- (IconModels.Bounds: the PNG's alpha box), so only empty margins are trimmed: nothing stretches or clips. props: X, Y,
-- W, H (the box it fits), Anchor, Z, Locked (a black silhouette: undiscovered), Name, Scale (of the fit, default 1).
local DEFAULT_BOUNDS = { Shoe = { 0.074, 0.21, 0.926, 0.79 }, Box = { 0.14, 0.074, 0.86, 0.926 } }
local function boundsOf(id, kind)
	local models = Kit.iconModels()
	local b = models and type(models.Bounds) == 'table' and models.Bounds[id]
	if type(b) == 'table' and #b == 4 and b[3] > b[1] and b[4] > b[2] then return b end
	return DEFAULT_BOUNDS[kind]
end
local function artIn(parent, id, kind, props)
	props = props or {}
	local w, h = props.W or 120, props.H or 120
	local holder = ArtKit.frame(parent, { Name = props.Name or id, X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Z = props.Z })
	local b = boundsOf(id, kind)
	local bw, bh = b[3] - b[1], b[4] - b[2]
	local side = math.min(w / bw, h / bh) * (props.Scale or 1)
	local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
	local icon = Kit.icon3d(id, math.floor(side), { ZIndex = props.Z or 1, Locked = props.Locked, AnchorPoint = Vector2.new(cx, cy), Position = UDim2.fromScale(0.5, 0.5) })
	icon.Parent = holder
	return holder, icon
end
function ArtKit.shoeArt(parent, id, props)
	return artIn(parent, 'Shoe_' .. tostring(id), 'Shoe', props)
end
-- A box's PNG (Box_<Id>); props as shoeArt.
function ArtKit.boxArt(parent, boxId, props)
	return artIn(parent, 'Box_' .. tostring(boxId), 'Box', props)
end
-- Any icon3d picture (Cash, Sneaker, Search, Delete, Favorite, Rewards, Basket, ShoeBox ...), contain-fit in a square.
function ArtKit.icon(parent, id, props)
	props = props or {}
	local s = props.S or 48
	local icon = Kit.icon3d(id, s, { ZIndex = props.Z or 1, AnchorPoint = props.Anchor or Vector2.new(0.5, 0.5), Position = props.Pos or px(props.X or 0, props.Y or 0), Locked = props.Locked })
	icon.Parent = parent
	return icon
end

---------------------------------------------------------------------------------------------- glyphs (drawn, never emoji)
local function bar(parent, cx, cy, w, h, rot, color, z, outline)
	local f = ArtKit.frame(parent, { Name = 'Bar', Pos = px(cx, cy), W = w, H = h, Anchor = Vector2.new(0.5, 0.5), Fill = color, Radius = math.floor(math.min(w, h) / 2), Rotation = rot, Z = z })
	if outline then stroke(f, outline, math.max(1.5, math.floor(math.min(w, h) * 0.28)), true) end
	return f
end
-- a tick (two bars), `s` square, centred at (x, y)
function ArtKit.tick(parent, x, y, s, color, z, outline)
	local g = ArtKit.frame(parent, { Name = 'Tick', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	bar(g, s * 0.32, s * 0.62, s * 0.2, s * 0.48, -45, color or WHITE, z, outline or ArtKit.Ink)
	bar(g, s * 0.6, s * 0.48, s * 0.2, s * 0.86, 40, color or WHITE, z, outline or ArtKit.Ink)
	return g
end
-- the green rounded check box (the bundle's list, the reward card's tick)
function ArtKit.check(parent, x, y, s, z)
	local b = ArtKit.block(parent, { Name = 'Check', Pos = px(x, y), Anchor = Vector2.new(0.5, 0.5), W = s, H = s, Tone = 'green', Radius = math.floor(s * 0.22), Outline = math.max(2, math.floor(s * 0.08)), Gloss = false, Z = z })
	ArtKit.tick(b, s / 2, s / 2 + 1, s * 0.78, WHITE, z, ArtKit.Ink)
	return b
end
-- a padlock: a rounded body and a shackle ring
function ArtKit.padlock(parent, x, y, s, z, color)
	local g = ArtKit.frame(parent, { Name = 'Padlock', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local sh = ArtKit.frame(g, { Name = 'Shackle', X = s * 0.24, Y = s * 0.02, W = s * 0.52, H = s * 0.6, Radius = UDim.new(0.5, 0), Z = z })
	stroke(sh, ArtKit.Ink, math.max(2, s * 0.2), true)
	local sh2 = ArtKit.frame(g, { Name = 'Shackle2', X = s * 0.24, Y = s * 0.02, W = s * 0.52, H = s * 0.6, Radius = UDim.new(0.5, 0), Z = z })
	stroke(sh2, color or WHITE, math.max(1, s * 0.1), true)
	local body = ArtKit.frame(g, { Name = 'Body', X = s * 0.1, Y = s * 0.4, W = s * 0.8, H = s * 0.56, Fill = color or WHITE, Radius = math.floor(s * 0.12), Z = z })
	stroke(body, ArtKit.Ink, math.max(2, s * 0.08), true)
	ArtKit.frame(body, { Name = 'Hole', Pos = UDim2.fromScale(0.5, 0.48), Anchor = Vector2.new(0.5, 0.5), W = s * 0.12, H = s * 0.22, Fill = ArtKit.Ink, Radius = 2, Z = z })
	return g
end
-- a chevron '>' (dir 1) or '<' (dir -1)
function ArtKit.chevron(parent, x, y, s, dir, z, color)
	local g = ArtKit.frame(parent, { Name = 'Chevron', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local d = dir or 1
	bar(g, s * 0.5, s * 0.32, s * 0.2, s * 0.5, -45 * d, color or WHITE, z, ArtKit.Ink)
	bar(g, s * 0.5, s * 0.68, s * 0.2, s * 0.5, 45 * d, color or WHITE, z, ArtKit.Ink)
	return g
end
-- a left arrow (Back)
function ArtKit.arrow(parent, x, y, s, z, color)
	local g = ArtKit.frame(parent, { Name = 'Arrow', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	bar(g, s * 0.58, s * 0.5, s * 0.7, s * 0.22, 0, color or WHITE, z, ArtKit.Ink)
	bar(g, s * 0.3, s * 0.34, s * 0.22, s * 0.52, 45, color or WHITE, z, ArtKit.Ink)
	bar(g, s * 0.3, s * 0.66, s * 0.22, s * 0.52, -45, color or WHITE, z, ArtKit.Ink)
	return g
end
-- the round (i)
function ArtKit.info(parent, x, y, s, z)
	local c = ArtKit.frame(parent, { Name = 'Info', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Radius = UDim.new(0.5, 0), Z = z })
	stroke(c, hex('C8D2E0'), math.max(2, s * 0.1), true)
	ArtKit.text(c, 'i', { Size = math.floor(s * 0.72), X = 0, Y = 0, W = s, H = s, Color = hex('C8D2E0'), Stroke = false, Z = z })
	return c
end
-- a radio button: a ring, a dot when on
function ArtKit.radio(parent, x, y, s, on, z)
	local c = ArtKit.frame(parent, { Name = 'Radio', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Fill = on and WHITE or hex('1A2636'), Radius = UDim.new(0.5, 0), Z = z })
	stroke(c, on and ArtKit.Ink or hex('3E5068'), math.max(2, s * 0.1), true)
	if on then ArtKit.frame(c, { Name = 'Dot', Pos = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), W = s * 0.5, H = s * 0.5, Fill = ArtKit.Ink, Radius = UDim.new(0.5, 0), Z = z }) end
	return c
end
-- a 4-point sparkle
function ArtKit.sparkle(parent, x, y, s, z, color)
	local g = ArtKit.frame(parent, { Name = 'Sparkle', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local c = color or WHITE
	ArtKit.frame(g, { Name = 'V', Pos = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), W = s * 0.16, H = s, Fill = c, Radius = UDim.new(0.5, 0), Z = z })
	ArtKit.frame(g, { Name = 'H', Pos = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), W = s, H = s * 0.16, Fill = c, Radius = UDim.new(0.5, 0), Z = z })
	ArtKit.frame(g, { Name = 'Core', Pos = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), W = s * 0.34, H = s * 0.34, Fill = c, Rotation = 45, Radius = 3, Z = z })
	return g
end
-- a little crown (three points on a band)
function ArtKit.crown(parent, x, y, s, z, color)
	local g = ArtKit.frame(parent, { Name = 'Crown', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local c = color or hex('FFC81E')
	for i, cx in { 0.18, 0.5, 0.82 } do
		local p = ArtKit.frame(g, { Name = 'Point' .. i, Pos = UDim2.fromScale(cx, i == 2 and 0.3 or 0.38), Anchor = Vector2.new(0.5, 0.5), W = s * 0.2, H = s * 0.5, Fill = c, Radius = UDim.new(0.5, 0), Rotation = (i - 2) * 22, Z = z })
		stroke(p, ArtKit.Ink, math.max(1.5, s * 0.06), true)
	end
	local band = ArtKit.frame(g, { Name = 'Band', X = s * 0.08, Y = s * 0.5, W = s * 0.84, H = s * 0.34, Fill = c, Radius = 4, Z = z })
	stroke(band, ArtKit.Ink, math.max(1.5, s * 0.06), true)
	return g
end
-- a gift box (purple box, pink ribbon and bow), the artboards' gift
function ArtKit.gift(parent, x, y, s, z)
	local g = ArtKit.frame(parent, { Name = 'Gift', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local function part(name, ax, ay, w, h, color, rot)
		local f = ArtKit.frame(g, { Name = name, X = s * ax, Y = s * ay, W = s * w, H = s * h, Fill = color, Radius = math.max(2, s * 0.06), Rotation = rot or 0, Z = z })
		stroke(f, ArtKit.Ink, math.max(2, s * 0.06), true)
		return f
	end
	part('BowL', 0.18, 0.02, 0.3, 0.24, hex('FF4FA8'), -25)
	part('BowR', 0.52, 0.02, 0.3, 0.24, hex('FF4FA8'), 25)
	part('Box', 0.1, 0.42, 0.8, 0.54, hex('7C4CF0'))
	part('Lid', 0.04, 0.26, 0.92, 0.22, hex('9C70FF'))
	part('Ribbon', 0.42, 0.26, 0.16, 0.7, hex('FF5AB4'))
	return g
end
-- an open book (Collection)
function ArtKit.book(parent, x, y, s, z)
	local g = ArtKit.frame(parent, { Name = 'Book', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	for i, ax in { 0.06, 0.5 } do
		local p = ArtKit.frame(g, { Name = 'Page' .. i, X = s * ax, Y = s * 0.18, W = s * 0.44, H = s * 0.66, Fill = WHITE, Radius = 3, Z = z })
		stroke(p, ArtKit.Ink, math.max(2, s * 0.07), true)
	end
	return g
end
-- a cube (Boxes tab)
function ArtKit.cube(parent, x, y, s, z)
	local g = ArtKit.frame(parent, { Name = 'Cube', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local top = ArtKit.frame(g, { Name = 'Top', Pos = UDim2.fromScale(0.5, 0.3), Anchor = Vector2.new(0.5, 0.5), W = s * 0.5, H = s * 0.5, Fill = WHITE, Rotation = 45, Radius = 3, Z = z })
	stroke(top, ArtKit.Ink, math.max(2, s * 0.07), true)
	local front = ArtKit.frame(g, { Name = 'Front', X = s * 0.15, Y = s * 0.42, W = s * 0.7, H = s * 0.46, Fill = hex('DDE4EE'), Radius = 3, Z = z })
	stroke(front, ArtKit.Ink, math.max(2, s * 0.07), true)
	return g
end
-- a trash bin (Delete)
function ArtKit.trash(parent, x, y, s, z)
	local g = ArtKit.frame(parent, { Name = 'Trash', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local lid = ArtKit.frame(g, { Name = 'Lid', X = s * 0.12, Y = s * 0.12, W = s * 0.76, H = s * 0.14, Fill = WHITE, Radius = 2, Z = z })
	stroke(lid, ArtKit.Ink, math.max(2, s * 0.07), true)
	local knob = ArtKit.frame(g, { Name = 'Knob', X = s * 0.38, Y = s * 0.02, W = s * 0.24, H = s * 0.12, Fill = WHITE, Radius = 2, Z = z })
	stroke(knob, ArtKit.Ink, math.max(2, s * 0.06), true)
	local body = ArtKit.frame(g, { Name = 'Can', X = s * 0.2, Y = s * 0.3, W = s * 0.6, H = s * 0.64, Fill = WHITE, Radius = 4, Z = z })
	stroke(body, ArtKit.Ink, math.max(2, s * 0.07), true)
	for i = 1, 3 do ArtKit.frame(body, { Name = 'Slit' .. i, X = s * (0.1 + (i - 1) * 0.16), Y = s * 0.1, W = s * 0.07, H = s * 0.44, Fill = ArtKit.Ink, Radius = 2, Z = z }) end
	return g
end
-- a calendar page with its day number (Daily Rewards)
function ArtKit.calendar(parent, x, y, s, z, day)
	local g = ArtKit.frame(parent, { Name = 'Calendar', Pos = px(x, y), W = s, H = s, Anchor = Vector2.new(0.5, 0.5), Z = z })
	local page = ArtKit.frame(g, { Name = 'Page', X = s * 0.08, Y = s * 0.16, W = s * 0.84, H = s * 0.78, Fill = WHITE, Radius = math.floor(s * 0.1), Z = z })
	stroke(page, ArtKit.Ink, math.max(2, s * 0.06), true)
	new('UIGradient', { Rotation = 90, Color = ColorSequence.new(WHITE, hex('C8D6EA')), Parent = page })
	local top = ArtKit.frame(g, { Name = 'Top', X = s * 0.08, Y = s * 0.16, W = s * 0.84, H = s * 0.26, Fill = hex('F0283C'), Radius = math.floor(s * 0.1), Z = z })
	stroke(top, ArtKit.Ink, math.max(2, s * 0.06), true)
	for i, rx in { 0.28, 0.66 } do
		local ring = ArtKit.frame(g, { Name = 'Ring' .. i, X = s * rx, Y = s * 0.04, W = s * 0.08, H = s * 0.22, Fill = WHITE, Radius = 3, Z = z })
		stroke(ring, ArtKit.Ink, math.max(2, s * 0.05), true)
	end
	ArtKit.text(page, tostring(day or 31), { Size = math.floor(s * 0.4), X = 0, Y = s * 0.22, W = s * 0.84, H = s * 0.54, Color = hex('1A2440'), Stroke = false, Z = z })
	return g
end
-- a sunburst behind art (Kit.sunburst's soft rays) plus a radial glow
function ArtKit.sunburst(parent, x, y, s, z, color, alpha)
	local sb = Kit.sunburst(s, { Position = px(x, y), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z, Rays = 16, Alpha = alpha or 0.22, Color = color or WHITE })
	sb.Parent = parent
	local glow = ArtKit.frame(parent, { Name = 'Glow', Pos = px(x, y), Anchor = Vector2.new(0.5, 0.5), W = s * 0.62, H = s * 0.62, Fill = color or WHITE, Transparency = 0.7, Radius = UDim.new(0.5, 0), Z = z })
	new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = glow })
	return sb
end

---------------------------------------------------------------------------------------------- buttons
-- A studded button: the block, an optional icon (Icon: an icon3d id; Glyph: function(parent, x, y, size, z)), the
-- label. props: Text, Tone, X, Y, W, H, Anchor, TextSize, IconSize, Name, Z, Radius, Studs (false: flat), OnClick,
-- TextColor, Align ('Center'), Gap (px between icon and text).
-- States (ArtKit.setState): normal | hover / pressed (UIMotion.button) | disabled | selected | loading | claimed.
local BUTTONS = setmetatable({}, { __mode = 'k' })
function ArtKit.button(parent, props)
	local w, h = props.W or 200, props.H or 64
	local z = props.Z or 1
	local holder = ArtKit.frame(parent, { Name = props.Name or ('Button_' .. tostring(props.Text or '')), X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Z = z })
	holder:SetAttribute('Lip', 3)
	local body = ArtKit.block(holder, { Name = 'Body', X = 0, Y = 0, W = w, H = h, Tone = props.Tone or 'green', Radius = props.Radius or 12, Outline = props.Outline or 4, Studs = props.Studs ~= false and 22 or nil, StudShade = 0.88, Z = z })
	local size = props.TextSize or math.floor(h * 0.5)
	local text = tostring(props.Text or '')
	local iconS = (props.Icon or props.Glyph) and (props.IconSize or math.floor(h * 0.72)) or 0
	local gap = (iconS > 0 and text ~= '') and (props.Gap or 10) or 0
	local tw = text ~= '' and Kit.textWidth(text, size) or 0
	local maxTw = w - 20 - iconS - gap
	if tw > maxTw and text ~= '' then
		size = Kit.fitSize(text, size, maxTw, 12)
		tw = Kit.textWidth(text, size)
	end
	local total = iconS + gap + tw
	local x0 = props.Align == 'Left' and 14 or math.floor((w - total) / 2)
	local icon
	if props.Icon then
		icon = ArtKit.icon(body, props.Icon, { S = iconS, X = x0 + iconS / 2, Y = h / 2, Z = z })
	elseif props.Glyph then
		icon = props.Glyph(body, x0 + iconS / 2, h / 2, iconS, z)
	end
	local label = ArtKit.text(body, text, { Name = 'Label', Size = size, X = x0 + iconS + gap - 4, Y = 0, W = tw + 8, H = h, Color = props.TextColor, Z = z, StrokeW = props.StrokeW })
	local hit = new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = holder })
	local info = { Holder = holder, Body = body, Label = label, Icon = icon, Tone = props.Tone or 'green', Text = text, OnClick = props.OnClick, State = 'normal' }
	BUTTONS[holder] = info
	Motion.button(holder, function()
		local st = info.State
		if st == 'disabled' or st == 'loading' or st == 'claimed' then return end
		if info.OnClick then info.OnClick() end
	end)
	return holder, hit
end
function ArtKit.buttonInfo(holder) return BUTTONS[holder] end
function ArtKit.setText(holder, text)
	local info = BUTTONS[holder]
	if not info then return end
	info.Text = text
	info.Label.Text = text
end
function ArtKit.onClick(holder, fn)
	local info = BUTTONS[holder]
	if info then info.OnClick = fn end
end
-- normal | disabled (grey, no input) | selected (a gold glow ring) | loading ('...' and no input) | claimed (dim + no input)
function ArtKit.setState(holder, state, text)
	local info = BUTTONS[holder]
	if not info then return end
	info.State = state
	holder:SetAttribute('State', state)
	local body = info.Body
	local tone = toneOf(state == 'disabled' and 'disabled' or info.Tone)
	local g = body:FindFirstChildOfClass('UIGradient')
	body.BackgroundColor3 = g and WHITE or tone.base
	if g then g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, tone.top), ColorSequenceKeypoint.new(1, tone.base) }) end
	info.Label.TextColor3 = state == 'disabled' and (tone.text or hex('C2C8D2')) or WHITE
	info.Label.Text = text or (state == 'loading' and (info.Text .. '...') or info.Text)
	local ring = holder:FindFirstChild('SelectedRing')
	if state == 'selected' and not ring then
		ring = ArtKit.frame(holder, { Name = 'SelectedRing', X = -6, Y = -6, W = holder.Size.X.Offset + 12, H = holder.Size.Y.Offset + 12, Radius = 16, Z = holder.ZIndex })
		stroke(ring, hex('FFE04A'), 4, true)
	elseif state ~= 'selected' and ring then
		ring:Destroy()
	end
	if info.Icon then
		for _, d in info.Icon:GetDescendants() do
			if d:IsA('ImageLabel') then d.ImageTransparency = state == 'disabled' and 0.45 or 0 end
		end
	end
	body.BackgroundTransparency = 0
end

-- The red square X (close): props X, Y, S (side), Anchor, Z, OnClick.
function ArtKit.closeX(parent, props)
	local s = props.S or 80
	local holder = ArtKit.button(parent, { Name = 'Close', Text = 'X', Tone = 'red', X = props.X, Y = props.Y, Pos = props.Pos, W = s, H = props.H or s, Anchor = props.Anchor, TextSize = math.floor(s * 0.66), Radius = 8, Outline = 4, Studs = false, Z = props.Z, OnClick = props.OnClick })
	return holder
end

-- A rounded pill (rarity, tags): props X, Y, W, H, Text, Color (Color3 or 'rainbow'), TextSize, TextColor, Z, Anchor,
-- Outline, Glyph (function(parent, x, y, s, z)), Name. Returns the frame and its label.
function ArtKit.pill(parent, props)
	local w, h = props.W or 160, props.H or 40
	local rainbow = props.Color == 'rainbow'
	local c = rainbow and WHITE or (props.Color or hex('3A4A60'))
	local f = ArtKit.frame(parent, { Name = props.Name or 'Pill', X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Fill = props.Shade == false and c or WHITE, Radius = props.Radius or math.floor(h * 0.32), Z = props.Z })
	if rainbow then
		new('UIGradient', { Rotation = 0, Color = ArtKit.rainbowSeq(), Parent = f })
	elseif props.Shade ~= false then
		new('UIGradient', { Rotation = 90, Color = ColorSequence.new(c:Lerp(WHITE, 0.25), c:Lerp(Color3.new(0, 0, 0), 0.12)), Parent = f })
	end
	stroke(f, props.OutlineColor or ArtKit.Ink, props.Outline or 3, true)
	local x0, gw = 0, 0
	if props.Glyph then
		gw = math.floor(h * 0.8)
		props.Glyph(f, 10 + gw / 2, h / 2, gw, props.Z)
		x0 = 10 + gw
	end
	local label = ArtKit.text(f, props.Text or '', { Name = 'Label', Size = props.TextSize or math.floor(h * 0.62), X = x0, Y = 0, W = w - x0, H = h, Color = props.TextColor, Stroke = props.TextStroke, Z = props.Z, Fit = true, MinSize = 10 })
	return f, label
end
-- A rarity pill: the rarity's colour (Secret: the rainbow) and its name (or `text`).
function ArtKit.rarityPill(parent, rarityId, props)
	local r = ArtKit.rarity(rarityId)
	props = table.clone(props or {})
	props.Color = r.Rainbow and 'rainbow' or r.Color
	props.Text = props.Text or r.Name
	props.Name = props.Name or 'Rarity'
	return ArtKit.pill(parent, props)
end

-- The Auto Open switch: a dark pill with its label, a white knob and OFF / ON. props X, Y, W, H, Label, On, Z, OnClick.
-- Returns the holder; ArtKit.setToggle(holder, on, disabled).
function ArtKit.toggle(parent, props)
	local w, h = props.W or 220, props.H or 64
	local z = props.Z or 1
	local holder = ArtKit.frame(parent, { Name = props.Name or 'Toggle', X = props.X, Y = props.Y, W = w, H = h, Pos = props.Pos, Anchor = props.Anchor, Z = z })
	holder:SetAttribute('Lip', 2)
	local body = ArtKit.block(holder, { Name = 'Body', X = 0, Y = 0, W = w, H = h, Fill = hex('16222F'), Radius = 12, Outline = 4, Z = z })
	stroke(ArtKit.frame(body, { Name = 'Rim', X = 3, Y = 3, W = w - 6, H = h - 6, Radius = 9, Z = z }), hex('2C3E52'), 2, true)
	local ts = props.TextSize or math.floor(h * 0.34)
	local trackW = math.min(h * 1.48, w * 0.42)
	local tw = w - trackW - 18
	ArtKit.text(body, props.Label or 'Auto Open', { Name = 'Label', Size = ts, X = 8, Y = 0, W = tw, H = h, Z = z, Fit = true, MinSize = 10 })
	local track = ArtKit.frame(body, { Name = 'Track', X = w - trackW - 8, Y = h * 0.2, W = trackW, H = h * 0.6, Fill = hex('0A121C'), Radius = UDim.new(0.5, 0), Z = z })
	stroke(track, hex('2C3E52'), 2, true)
	local knob = ArtKit.frame(track, { Name = 'Knob', X = 2, Y = 2, W = h * 0.56 - 4, H = h * 0.56 - 4, Fill = WHITE, Radius = UDim.new(0.5, 0), Z = z })
	new('UIGradient', { Rotation = 90, Color = ColorSequence.new(WHITE, hex('BAC4D0')), Parent = knob })
	local state = ArtKit.text(track, 'OFF', { Name = 'State', Size = math.floor(h * 0.3), X = h * 0.56, Y = 0, W = trackW - h * 0.6, H = h * 0.6, Z = z, StrokeW = 2, Fit = true, MinSize = 10 })
	local hit = new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = holder })
	local info = { Holder = holder, Body = body, Track = track, Knob = knob, State = state, On = false, Disabled = false, OnClick = props.OnClick, H = h, TrackW = trackW }
	BUTTONS[holder] = info
	Motion.button(holder, function()
		if info.Disabled then return end
		if info.OnClick then info.OnClick() end
	end)
	ArtKit.setToggle(holder, props.On == true, props.Disabled == true)
	return holder, hit
end
function ArtKit.setToggle(holder, on, disabled)
	local info = BUTTONS[holder]
	if not info then return end
	info.On, info.Disabled = on, disabled == true
	local h = info.H
	info.Knob.Position = on and px(info.TrackW - (h * 0.56 - 4) - 2, 2) or px(2, 2)
	info.State.Text = on and 'ON' or 'OFF'
	info.State.Position = on and px(4, 0) or px(h * 0.56, 0)
	info.Track.BackgroundColor3 = on and hex('12B82E') or hex('0A121C')
	holder:SetAttribute('On', on)
	for _, d in info.Body:GetDescendants() do
		if d:IsA('TextLabel') then d.TextTransparency = info.Disabled and 0.5 or 0 end
	end
end

-- A row of tabs: props X, Y, W, H, Items { { Id, Text, Tone } }, Gap, Selected (id), SelectedTone ('green'),
-- IdleFill, TextSize, Z, OnSelect(id). Returns the holder and set(id).
function ArtKit.tabs(parent, props)
	local items = props.Items
	local n = #items
	local gap = props.Gap or 8
	local w, h = props.W or 600, props.H or 56
	local tw = (w - gap * (n - 1)) / n
	local z = props.Z or 1
	local holder = ArtKit.frame(parent, { Name = props.Name or 'Tabs', X = props.X, Y = props.Y, W = w, H = h, Z = z })
	local buttons = {}
	local function set(id)
		for _, it in items do
			local b = buttons[it.Id]
			local on = it.Id == id
			local info = BUTTONS[b]
			if info then
				info.Tone = on and (props.SelectedTone or 'green') or (it.Tone or props.IdleTone or 'navy')
				ArtKit.setState(b, 'normal')
				local rim = info.Body:FindFirstChild('Rim')
				local o = info.Body:FindFirstChildOfClass('UIStroke')
				if o then o.Color = (on or not props.IdleBorder) and ArtKit.Ink or props.IdleBorder end
				if rim then rim.Visible = true end
				if info.IdleBorder then info.IdleBorder.Visible = not on end
			end
		end
		holder:SetAttribute('Selected', id)
	end
	for i, it in items do
		local b = ArtKit.button(holder, { Name = 'Tab_' .. it.Id, Text = it.Text, Tone = it.Tone or 'navy', X = (i - 1) * (tw + gap), Y = 0, W = tw, H = h, TextSize = props.TextSize or math.floor(h * 0.56), Radius = props.Radius or 10, Outline = 3, Studs = props.Studs, Icon = it.Icon, Glyph = it.Glyph, IconSize = it.IconSize, Z = z, OnClick = function()
			set(it.Id)
			if props.OnSelect then props.OnSelect(it.Id) end
		end })
		buttons[it.Id] = b
		if props.IdleBorder then
			local inner = ArtKit.frame(BUTTONS[b].Body, { Name = 'IdleBorder', X = 2, Y = 2, W = tw - 4, H = h - 4, Radius = (props.Radius or 10) - 2, Z = z })
			stroke(inner, props.IdleBorder, 3, true)
			BUTTONS[b].IdleBorder = inner
		end
	end
	set(props.Selected or items[1].Id)
	return holder, set, buttons
end

-- A dark field with a blue border and a chevron (Sort / Filter): props X, Y, W, H, Text, Z, OnClick. Returns holder.
function ArtKit.dropdown(parent, props)
	local w, h = props.W or 220, props.H or 60
	local z = props.Z or 1
	local holder = ArtKit.frame(parent, { Name = props.Name or 'Dropdown', X = props.X, Y = props.Y, W = w, H = h, Z = z })
	holder:SetAttribute('Lip', 2)
	local body = ArtKit.field(holder, { X = 0, Y = 0, W = w, H = h, Z = z })
	local label = ArtKit.text(body, props.Text or '', { Name = 'Label', Size = props.TextSize or 26, X = 16, Y = 0, W = w - 60, H = h, Align = 'Left', Z = z, Fit = true, MinSize = 12 })
	local ch = ArtKit.frame(body, { Name = 'ChevronDown', Pos = px(w - 30, h / 2), Anchor = Vector2.new(0.5, 0.5), W = 26, H = 26, Rotation = 90, Z = z })
	ArtKit.chevron(ch, 13, 13, 24, 1, z)
	new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = holder })
	holder:SetAttribute('Lip', 1)
	BUTTONS[holder] = { Holder = holder, Body = body, Label = label, State = 'normal', OnClick = props.OnClick, Text = props.Text or '', Tone = 'dark' }
	Motion.button(holder, function() local i = BUTTONS[holder]; if i.OnClick then i.OnClick() end end)
	return holder, label
end
-- The dark input well with a blue border (search, dropdowns, capacity).
function ArtKit.field(parent, props)
	local f = ArtKit.frame(parent, { Name = props.Name or 'Body', X = props.X, Y = props.Y, W = props.W, H = props.H, Pos = props.Pos, Anchor = props.Anchor, Fill = props.Fill or hex('0C2234'), Radius = props.Radius or 12, Z = props.Z })
	stroke(f, ArtKit.Ink, props.Outline or 4, true)
	local rim = ArtKit.frame(f, { Name = 'Border', X = 3, Y = 3, W = props.W - 6, H = props.H - 6, Radius = (props.Radius or 12) - 3, Z = props.Z })
	stroke(rim, props.Border or hex('0A72C4'), props.BorderW or 4, true)
	return f
end
-- The search box: a magnifier and a TextBox. props X, Y, W, H, Placeholder, Z, OnChanged(text). Returns holder, box.
function ArtKit.search(parent, props)
	local w, h = props.W or 320, props.H or 60
	local z = props.Z or 1
	local f = ArtKit.field(parent, { Name = props.Name or 'Search', X = props.X, Y = props.Y, W = w, H = h, Z = z })
	ArtKit.icon(f, 'Search', { S = math.floor(h * 0.7), X = 12 + h * 0.35, Y = h / 2, Z = z })
	local box = new('TextBox', {
		Name = 'Box', Text = '', PlaceholderText = props.Placeholder or 'Search...', PlaceholderColor3 = hex('8C9AAE'), ClearTextOnFocus = false,
		FontFace = Fonts.Title, TextSize = props.TextSize or 26, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(h + 8, 0), Size = px(w - h - 18, h), ZIndex = z, Parent = f,
	})
	-- (the placeholder as a drawn label too: the offline preview draws TextBoxes' Text only)
	local ph = ArtKit.text(f, props.Placeholder or 'Search...', { Name = 'Placeholder', Size = props.TextSize or 26, X = h + 8, Y = 0, W = w - h - 18, H = h, Align = 'Left', Color = hex('8C9AAE'), Z = z, StrokeW = 2 })
	box:GetPropertyChangedSignal('Text'):Connect(function()
		ph.Visible = box.Text == ''
		if props.OnChanged then props.OnChanged(box.Text) end
	end)
	return f, box
end

---------------------------------------------------------------------------------------------- the panel
-- A window from the artboards. props:
--   Name, W, H                   its artboard size
--   Head                         header height (the header block spans 0..Head)
--   Foot                         footer height (pinned at the bottom; 0 = none)
--   Title, TitleSize, TitleX, TitleW, TitleGradient    the header's title
--   HeadTone                     'cyan' (default) | 'purple' | a tone table
--   Body                         the body's fill (Color3, default the dark navy) and BodyStuds (pitch)
--   Icon / IconBox {x, y, w, h}  the header picture (icon3d id) and where it sits (it may pop over the top edge)
--   IconNode                     function(parent, x, y, w, h, z) drawing the header picture instead
--   Close                        function: the red X (CloseBox {x, y, s}); nil = no X
--   MinText                      the smallest text on the panel in artboard px (default 18): the phone floor
-- Returns P = { Fit, Panel, Shell, Header, Title, Content (scrolling body), Foot, CloseButton, W, H, Head, FootH,
--   c(x, y) -> UDim2 (a body point, in panel coordinates), f(x, y) -> UDim2 (a footer point) }.
function ArtKit.panel(parent, props)
	local W, H = props.W, props.H
	local head, foot = props.Head or 90, props.Foot or 0
	local fit = ArtKit.frame(parent, { Name = (props.Name or 'Art') .. 'Fit', W = W, H = H, Pos = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), Z = props.Z or 30 })
	new('UIScale', { Name = 'FitScale', Parent = fit })
	local panel = ArtKit.frame(fit, { Name = props.Name or 'Art', Box = UDim2.fromScale(1, 1), Z = props.Z or 30 })
	local z = props.Z or 30
	-- the shell: the dark studded body inside the thick outline
	local shell = ArtKit.block(panel, { Name = 'Shell', X = 0, Y = 0, W = W, H = H, Fill = props.Body or ArtKit.Tone.navy.base, Gradient = props.BodyGradient, GradientRot = props.BodyRot, Radius = 16, Outline = 5, Z = z })
	local studs = Kit.studs(shell, { Pitch = props.BodyStuds or 26, Width = W, Height = H, Shade = props.BodyShade or 0.9, ZIndex = z })
	if studs and studs:IsA('ImageLabel') then corner(studs, 16) end
	local rim = ArtKit.frame(shell, { Name = 'Rim', X = 4, Y = 4, W = W - 8, H = H - 8, Radius = 13, Z = z })
	stroke(rim, props.RimColor or hex('1E5A78'), 3, true, 0.25)
	-- the header
	local tone = toneOf(props.HeadTone or 'cyan')
	local header = ArtKit.block(panel, { Name = 'Header', X = 0, Y = 0, W = W, H = head, Tone = tone, Radius = 14, Outline = 5, Studs = 22, StudShade = 0.84, Z = z + 1 })
	local tx = props.TitleX or 150
	local title = ArtKit.text(header, props.Title or '', { Name = 'Title', Size = props.TitleSize or 52, X = tx, Y = props.TitleY or 0, W = props.TitleW or (W - tx - 110), H = head, Align = props.TitleAlign or 'Left', Gradient = props.TitleGradient, Z = z + 1, Fit = true, StrokeW = math.floor((props.TitleSize or 52) * 0.13) })
	local content = new('ScrollingFrame', {
		Name = 'Content', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, head), Size = px(W, H - head - foot),
		CanvasSize = px(0, H - head - foot), ScrollBarThickness = 8, ScrollBarImageColor3 = hex('7FD8FF'), ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = z + 2, Parent = panel,
	})
	local footer = ArtKit.frame(panel, { Name = 'Foot', X = 0, Y = H - foot, W = W, H = foot, Z = z + 3 })
	local iconHolder
	if props.Icon or props.IconNode then
		local b = props.IconBox or { 14, -14, 120, 120 }
		iconHolder = ArtKit.frame(panel, { Name = 'HeadIcon', X = b[1], Y = b[2], W = b[3], H = b[4], Z = z + 4 })
		if props.IconNode then
			props.IconNode(iconHolder, b[3] / 2, b[4] / 2, math.min(b[3], b[4]), z + 4)
		else
			local ic = Kit.icon3d(props.Icon, math.min(b[3], b[4]), { ZIndex = z + 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			ic.Parent = iconHolder
		end
	end
	local closeButton
	if props.Close then
		local cb = props.CloseBox or { W - 92, 10, 80 }
		closeButton = ArtKit.closeX(panel, { X = cb[1], Y = cb[2], S = cb[3], H = cb[4], Z = z + 4, OnClick = props.Close })
	end
	local P = { Fit = fit, Panel = panel, Shell = shell, Header = header, Title = title, Content = content, Foot = footer, CloseButton = closeButton, Icon = iconHolder,
		W = W, H = H, Head = head, FootH = foot, MinText = props.MinText or 18, Z = z }
	function P.c(x, y) return px(x, y - head) end
	function P.f(x, y) return px(x, y - (H - foot)) end
	return P
end

-- Fit a panel to a screen (`abs`: the ScreenGui's AbsoluteSize in px). The panel scales to fit with a margin (at most
-- opts.Max, 1.25); below the scale where its smallest text (P.MinText) would read under MinScreenText px, it keeps
-- that scale (as far as its width allows) and its body scrolls. Returns the scale.
function ArtKit.fit(P, abs, opts)
	opts = opts or {}
	if not abs or abs.X < 2 or abs.Y < 2 then return 1 end
	local m = opts.Margin or 10
	local availW, availH = abs.X - 2 * m, abs.Y - 2 * m
	local s = math.min(availW / P.W, availH / P.H, opts.Max or 1.25)
	local floor = ArtKit.MinScreenText / P.MinText
	if s < floor then s = math.min(floor, availW / P.W) end
	local visH = math.min(P.H, math.floor(availH / s))
	P.Fit.Size = px(P.W, visH)
	P.Fit.AnchorPoint = Vector2.new(0.5, 0.5)
	P.Fit.Position = UDim2.fromScale(0.5, 0.5)
	P.Fit.FitScale.Scale = s
	P.Shell.Size = px(P.W, visH)
	for _, d in P.Shell:GetChildren() do
		if d.Name == 'Rim' and d:IsA('Frame') then d.Size = px(P.W - 8, visH - 8) end
	end
	P.Content.Size = px(P.W, math.max(40, visH - P.Head - P.FootH))
	P.Content.CanvasSize = px(0, P.H - P.Head - P.FootH)
	P.Foot.Position = px(0, visH - P.FootH)
	P.Scale, P.VisH = s, visH
	if P.OnFit then
		-- (a screen with its own scrolling grid: the body stays put and the grid takes the height that is left)
		P.Content.CanvasSize = px(0, math.max(40, visH - P.Head - P.FootH))
		P.OnFit(visH)
	end
	return s
end
-- Put a panel at a fixed spot at a fixed scale (the side-by-side shots: artboard px = screen px at scale 1).
function ArtKit.place(P, x, y, scale)
	P.Fit.AnchorPoint = Vector2.zero
	P.Fit.Position = px(x, y)
	P.Fit.Size = px(P.W, P.H)
	P.Fit.FitScale.Scale = scale or 1
	P.Shell.Size = px(P.W, P.H)
	P.Content.Size = px(P.W, P.H - P.Head - P.FootH)
	P.Foot.Position = px(0, P.H - P.FootH)
end

-- A full-screen dim behind a panel that stops taps reaching the world (onTap: optional).
function ArtKit.dim(parent, z, onTap, transparency)
	local d = new('TextButton', { Name = 'Dim', Text = '', AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = transparency or 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z or 29, Parent = parent })
	if onTap then d.Activated:Connect(onTap) end
	return d
end

-- The pop-in of a panel (the references' motion: 0.85 -> 1.03 -> 1 with a quick fade of the dim).
function ArtKit.popIn(P)
	local s = Motion.scaleOf(P.Panel)
	s.Scale = 0.86
	local t = Motion.tween(s, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.03 })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then Motion.tween(s, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, { Scale = 1 }) end
	end)
end

return ArtKit
