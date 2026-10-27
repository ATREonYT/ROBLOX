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
-- Brief 17 (the user's reference HUD, Store and Rebirth windows) adds the "studded block" family used by every
-- screen now: Kit.block / Kit.blockButton (square-ish, thick ink outline, flat tone gradient, a faint stud grid),
-- Kit.window (studded coloured header with a big icon, title and a red X over a dark see-through body),
-- Kit.bar (studded progress bar), Kit.robux / Kit.robuxButton (the green Robux price button) and Kit.studs.
-- Used by HoodClient/HUD, Store, Shoes, Goals and Waves; UIKitDemo builds sample screens with the older pieces.
local Kit = {}
local Fonts = require(script.Parent.Fonts)
local ImageLoader = require(script.Parent.ImageLoader) -- (round 3: the packed pictures, drawn in game)

local function hex(h)
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
Kit.hex = hex

---------------------------------------------------------------------------------------------- tokens
Kit.Color = {
	ink = hex('1C1830'), -- every outer outline and hard shadow
	black = hex('060608'), -- (brief 18) the reference's outlines and text strokes are plain black
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
	cyan = { top = hex('9CF6FF'), base = hex('22C7EE'), lip = hex('1484A8'), stroke = hex('083A52') },
	cardboard = { top = hex('FFF8EA'), base = hex('FFEFD2'), lip = hex('C99A5B'), stroke = hex('5C3A12') },
	grey = { top = hex('E6E2DC'), base = hex('C4BFB8'), lip = hex('8D877F'), stroke = hex('3A3631') },
	-- (brief 17) the reference's Store orange and two deeper card colours
	orange = { top = hex('FFD84A'), base = hex('FF9A1F'), lip = hex('C9620A'), stroke = hex('5A2600') },
	pink = { top = hex('FF9AD5'), base = hex('F2459E'), lip = hex('A8186A'), stroke = hex('4A0830') },
	teal = { top = hex('7DF2C8'), base = hex('19B98A'), lip = hex('0C7A5A'), stroke = hex('063A2B') },
	dark = { top = hex('4A5170'), base = hex('2E3349'), lip = hex('1F2335'), stroke = hex('0E1020') },
	-- (brief 18) colours sampled from the user's reference HUD (user_26), Rebirth (user_27) and Store (user_28), top of
	-- the fill -> bottom; `lip` is the faint stud outline, `rim` the light band inside the black outline.
	gold = { top = hex('FFD150'), base = hex('FFA20C'), lip = hex('D27A00'), stroke = hex('5A2E00'), rim = hex('FFE29A') }, -- Store, Items, 2x Wins
	-- (brief 22: re-sampled on ref22_hud_buttons, top -> bottom of each square's fill)
	coral = { top = hex('F67079'), base = hex('C15751'), lip = hex('983A38'), stroke = hex('4A0B16'), rim = hex('FFA8AE') }, -- Rebirth
	magenta = { top = hex('E585F5'), base = hex('AA11C0'), lip = hex('7E0A8E'), stroke = hex('2A0B4E'), rim = hex('F0AEF8') }, -- Pets (our Shoes)
	sky = { top = hex('7BB5FB'), base = hex('1F70BF'), lip = hex('175494'), stroke = hex('0B2A55'), rim = hex('8DB8E2') }, -- Heros (our Guns)
	grass = { top = hex('B9EF48'), base = hex('3BBA16'), lip = hex('2A8A0E'), stroke = hex('123F17'), rim = hex('D2F68A') }, -- World
	brown = { top = hex('F3A682'), base = hex('AF4E24'), lip = hex('86381A'), stroke = hex('3A1A08'), rim = hex('F8C4A8') }, -- Quest
	items = { top = hex('FCD164'), base = hex('F4A423'), lip = hex('C47A10'), stroke = hex('5A2E00'), rim = hex('FFE29A') }, -- Items
	fire = { top = hex('FF5E52'), base = hex('FFC130'), lip = hex('D8602A'), stroke = hex('5A1A00'), rim = hex('FF9A8A') }, -- +2x Power (red top, yellow bottom)
	level = { top = hex('FFBB26'), base = hex('FF413B'), lip = hex('D0401A'), stroke = hex('5A1400'), rim = hex('FFD27A') }, -- the Level bar
	lemon = { top = hex('F8EC72'), base = hex('F3B740'), lip = hex('C99A20'), stroke = hex('5A4600'), rim = hex('FFF6B0') }, -- +1B pack
	cherry = { top = hex('EF7E83'), base = hex('E6343A'), lip = hex('A8161C'), stroke = hex('4A0B10'), rim = hex('F6A6A8') }, -- +10B pack
	aqua = { top = hex('5AF2EC'), base = hex('1E78B4'), lip = hex('146090'), stroke = hex('062C48'), rim = hex('8AF8FF') }, -- Rebirth window boxes, bar, buttons
	lime = { top = hex('E6FF10'), base = hex('36E402'), lip = hex('20A000'), stroke = hex('0E3A00'), rim = hex('A8FF6A') }, -- the green Robux price button
	rose = { top = hex('FF0A8E'), base = hex('FF0A1E'), lip = hex('B00010'), stroke = hex('4A0010'), rim = hex('FF6AB0') }, -- the red X
	-- the two window headers: Rebirth (cyan -> blue, a bright cyan rim) and Store (yellow-orange, a bright yellow rim)
	-- (brief 19 r7, UICRITIC P2-3) straight top -> bottom like the reference's (user_27 #02B6E4 -> #0173EA, user_28
	-- #FFBA01 -> #FC9A01, measured down the header): an angled gradient on a 10:1 header reads sideways
	headerCyan = { top = hex('06BCEC'), base = hex('0174EA'), lip = hex('0A5CB8'), stroke = hex('062C48'), rim = hex('10F0FF'), rot = 90 },
	headerGold = { top = hex('FFBE0A'), base = hex('FA9800'), lip = hex('C87400'), stroke = hex('5A2E00'), rim = hex('FFE600'), rot = 90 },
	headerMagenta = { top = hex('E07AF4'), base = hex('8C16C4'), lip = hex('6A0E96'), stroke = hex('2A0B4E'), rim = hex('F6A8FF'), rot = 90 },
	headerBrown = { top = hex('E09A70'), base = hex('B06440'), lip = hex('8A4A2C'), stroke = hex('3A1A08'), rim = hex('F2BE9A'), rot = 90 }, -- (the Quest window, like the HUD's Quest square)
	-- Store cards (user_28): Golden Zone orange, Galaxy Zone purple, Hacker Zone green
	cardGold = { top = hex('FFDA68'), base = hex('FCA526'), lip = hex('E08A10'), stroke = hex('5A2E00'), rim = hex('FFD27A') },
	cardPurple = { top = hex('EC94F8'), base = hex('AE26C0'), lip = hex('8A1A9E'), stroke = hex('2A0B4E'), rim = hex('F2B0FA') },
	cardGreen = { top = hex('D4FA78'), base = hex('66D212'), lip = hex('4AA80A'), stroke = hex('123F17'), rim = hex('E4FCA8'), glow = hex('4CF028') }, -- (glow: the HACKER ZONE banner's bright green text edge)
	cardBlue = { top = hex('8AD4FF'), base = hex('2A86E6'), lip = hex('1A64B8'), stroke = hex('0B2A55'), rim = hex('B4E4FF') },
	cardRed = { top = hex('FF8A80'), base = hex('E8303A'), lip = hex('B01E28'), stroke = hex('4A0B16'), rim = hex('FFB0A8') },
	cardTeal = { top = hex('8AF6D4'), base = hex('16B48A'), lip = hex('0C8A68'), stroke = hex('063A2B'), rim = hex('B4FAE4') },
	cardPink = { top = hex('FFA4D8'), base = hex('EC3E98'), lip = hex('B81A70'), stroke = hex('4A0830'), rim = hex('FFC4E4') },
	-- (brief 22) the Store's new cards, sampled on ref22_store_*: the egg card's blue and magenta, the packs' orange (a strong
	-- yellow -> orange ramp), the two potion half cards (a muted red, gold) and the Boost Bundle's purple -> red sweep
	storeBlue = { top = hex('1AA4FE'), base = hex('0A95FF'), lip = hex('0A6EC0'), stroke = hex('062C48'), rim = hex('63BFFF') },
	storeMagenta = { top = hex('F64CF4'), base = hex('E62CE6'), lip = hex('A812AA'), stroke = hex('4A0A4A'), rim = hex('FF98F8') },
	packOrange = { top = hex('FFC42B'), base = hex('FF8B01'), lip = hex('D06800'), stroke = hex('5A2E00'), rim = hex('FEE15E') },
	potionRed = { top = hex('E26C76'), base = hex('D23739'), lip = hex('982428'), stroke = hex('3A0A0E'), rim = hex('F2A0A8') },
	potionGold = { top = hex('FEC503'), base = hex('FFAE01'), lip = hex('C87400'), stroke = hex('5A2E00'), rim = hex('FFE07A') },
	bundleRainbow = { top = hex('B100DF'), base = hex('EA2D04'), lip = hex('8A0070'), stroke = hex('3A0030'), rim = hex('FF9AEA'), rot = 0,
		seq = { { 0, hex('B100DF') }, { 0.4, hex('FF00B1') }, { 0.65, hex('FE0250') }, { 1, hex('EA2D04') } } },
	-- horizontal gradients: the +100B pack's rainbow and the 2x Speed button
	rainbow = { top = hex('F20D18'), base = hex('1E6AF0'), lip = hex('8A1A9E'), stroke = hex('2A0B4E'), rim = hex('FFFFFF'), rot = 0,
		seq = { { 0, hex('F20D18') }, { 0.22, hex('F26D1D') }, { 0.4, hex('F8C311') }, { 0.58, hex('98EB22') }, { 0.76, hex('22E0E0') }, { 1, hex('1E6AF0') } } },
	sunset = { top = hex('F91284'), base = hex('E8E04A'), lip = hex('B01060'), stroke = hex('4A0830'), rim = hex('FF8AC4'), rot = 0,
		seq = { { 0, hex('F91284') }, { 0.35, hex('FF2020') }, { 0.7, hex('FF9A10') }, { 1, hex('F2E640') } } },
}
-- (Oct 27) The owner's UI mockup (hood/docs/refs/ui/owner_ui_windows_oct27.png), "tuned to the game": every window is a
-- dark navy body with a faint blue square tile, a thick near-black outline and rounded corners, under a bright yellow
-- header bar (lighter on top) with the icon breaking out at its left, the title in white Montserrat Black and a red
-- square X; tabs are dark pills with the open one bright blue; side menus dark rows, the open one blue; buttons green
-- (do it), grey (secondary) or red (delete); progress bars a dark trough with a green fill and a centred label.
Kit.Skin = {
	outline = hex('0B0E1C'), -- the windows' outline: a near-black navy
	bodyTop = hex('26315A'), bodyBase = hex('1A2240'), -- the body, top -> bottom (sampled ~#232E52 -> #1A2340)
	tile = hex('9DB8FF'), tileShade = 0.12, -- the faint square tile over the body (tint, strength)
	rim = hex('3C4C86'), -- the thin light line inside the outline
	well = hex('10152C'), -- dark wells: bar troughs
	corner = 14, -- body corner radius
	headerCorner = 10,
}
Kit.Tone.headerYellow = { top = hex('FFEA5C'), base = hex('F7B400'), lip = hex('D08A00'), stroke = hex('5A3A00'), rim = hex('FFF7B8'), rimLow = hex('E8A200'), rot = 90 }
Kit.Tone.headerRed = { top = hex('FF6A6A'), base = hex('E01E2C'), lip = hex('A8161C'), stroke = hex('4A0B10'), rim = hex('FFB4B4'), rimLow = hex('C0141E'), rot = 90 } -- (delete / are you sure)
Kit.Tone.closeRed = { top = hex('FF5C5C'), base = hex('E3101E'), lip = hex('9A0A12'), stroke = hex('3A0008'), rim = hex('FFA0A0'), rot = 90 }
Kit.Tone.navyRow = { top = hex('2F3B68'), base = hex('212B50'), lip = hex('18203C'), stroke = hex('0B0E1C'), rim = hex('48598F'), rot = 90 } -- idle tabs, menu rows, stat cards
Kit.Tone.tabBlue = { top = hex('5EC4FF'), base = hex('1A7CF2'), lip = hex('1258B8'), stroke = hex('06204A'), rim = hex('AEE0FF'), rot = 90 } -- the open tab / row
Kit.Tone.buyGreen = { top = hex('92F64E'), base = hex('2FBE1E'), lip = hex('1E8A12'), stroke = hex('0E3A06'), rim = hex('CCFFA6'), rot = 90 } -- primary buttons, bar fills
Kit.Tone.slate = { top = hex('97A1B6'), base = hex('646E86'), lip = hex('444C60'), stroke = hex('1A1E2A'), rim = hex('C2C9D8'), rot = 90 } -- secondary buttons
-- Cross-industry rarity ladder (white, green, blue, purple, gold), extended upward.
Kit.Rarity = {
	{ name = 'COMMON', color = hex('B8BEC8') },
	{ name = 'UNCOMMON', color = hex('5BD45B') },
	{ name = 'RARE', color = hex('3D9BFF') },
	{ name = 'EPIC', color = hex('A64DFF') },
	{ name = 'LEGENDARY', color = hex('FFB020') },
	{ name = 'MYTHIC', color = hex('FF3B5C') },
}
-- (brief 28) Every face comes from Shared/Fonts: Montserrat, the family the user's references set their whole UI in
-- (Fonts.lua has the evidence). Titles, names, buttons and numbers are its Black; window titles and small lines Bold.
-- The old keys stay so every screen keeps working; `tag` (was PermanentMarker) and `reveal` (was FredokaOne, the shoe
-- names in the reveal) are the title face now too.
Kit.Font = {
	display = Fonts.Title,
	heading = Fonts.Heading, -- window titles ("Store", "Rebirth"): Bold, as the references' are
	italic = Fonts.Italic, -- the Store's "~Gamepass~" section heads
	loud = Fonts.Title,
	number = Fonts.Number,
	body = Fonts.Body,
	tag = Fonts.Title,
	reveal = Fonts.Title,
}
Kit.Text = { title = 40, cta = 30, button = 24, label = 18, small = 15 } -- at the 1280x720 design size

-- (brief 19 r7) The reference hides Roblox's player list (nothing at its top right). (brief 30, the lead: hidden, like the
-- reference: the Playtime gift and the Starter Pack sit in that corner) HUD.client hides it
-- (StarterGui:SetCoreGuiEnabled(PlayerList, false)); false shows it again.
Kit.HidePlayerList = true
-- The width (design px) Roblox's player list takes at the top right under the top bar on this screen: ~285 dp with our
-- two leaderstats on PC; 0 when hidden, and on phones (Roblox keeps it collapsed there).
function Kit.playerListRoom(abs)
	if Kit.HidePlayerList or math.min(abs.X, abs.Y) <= 500 then return 0 end
	return 285 / Kit.scaleFor(abs)
end
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
local function stroke(color, thickness, border, transparency, join)
	return new('UIStroke', {
		Color = color, Thickness = thickness, Transparency = transparency or 0, LineJoinMode = join or Enum.LineJoinMode.Round,
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
	local strokeWidth = props.StrokeThickness -- (optional: the reference's titles carry a heavier outline)
	props.Stroke = nil
	local t = new('TextLabel', {
		Name = props.Name or 'Label', BackgroundTransparency = 1, BorderSizePixel = 0,
		FontFace = props.FontFace or Kit.Font.display, TextSize = size, TextColor3 = props.TextColor3 or Kit.Color.white,
		Text = props.Text or '', Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center, TextWrapped = props.TextWrapped or false,
		ZIndex = props.ZIndex or 1, Rotation = props.Rotation or 0, RichText = props.RichText or false,
	})
	if strokeColor then stroke(strokeColor, strokeWidth or math.max(1.5, size * 0.1)).Parent = t end
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

---------------------------------------------------------------------------------------------- icons (brief 24: flat)
-- The user (brief 24): "the UI shouldn't look 3D". Every picture in every screen is a flat PNG: ART2's cartoon icons in
-- Shared/Models/IconModels (Images[id] = the uploaded id; one framing for all of them: a 512 canvas, the art centred,
-- its longer side ~86% of it, so every icon drawn at one size reads the same size). There are no ViewportFrames and no
-- live part models in any screen any more. While an image can't draw (not uploaded yet, still in Roblox's review,
-- rejected), Kit.icon3d shows a FLAT 2D stand-in (Kit.flatIcon): a rounded block in the icon's colour with the PNGs'
-- dark ink outline and a simple white glyph, from ART2's IconModels.Fallback[id] = { Color, Glyph, Text?, Ink?, Accent? }
-- (Kit.FlatDefault until a row exists). Families need no rows: Shoe_<ShoeId>, Box_<BoxId> and Gun_<GunId> take their
-- colours from Config.Shoes / Config.Guns. (The name icon3d stays: every screen calls it.)
local iconModels -- the module, or false once we know it is missing
function Kit.iconModels()
	if iconModels == nil then
		iconModels = false
		local folder = script.Parent:FindFirstChild('Models')
		local module = folder and folder:FindFirstChild('IconModels')
		if module then
			local ok, result = pcall(require, module)
			if ok and type(result) == 'table' then iconModels = result end
		end
	end
	return iconModels or nil
end
-- The uploaded image of an icon ('' when none yet).
function Kit.iconImage(id)
	local models = Kit.iconModels()
	local image = models and type(models.Images) == 'table' and models.Images[id]
	return type(image) == 'string' and image or ''
end
-- Whether IconModels knows `id`: an uploaded image or a Fallback row (ART2's IconModels.has; families: an image).
function Kit.hasIcon(id)
	if type(id) ~= 'string' or id == '' then return false end
	local models = Kit.iconModels()
	if models and type(models.has) == 'function' then
		local ok, v = pcall(models.has, id)
		if ok and v then return true end
	end
	if Kit.iconImage(id) ~= '' then return true end
	local rows = models and type(models.Fallback) == 'table' and models.Fallback
	return (rows and type(rows[id]) == 'table') or Kit.FlatDefault[id] ~= nil
end
-- The first of the ids IconModels knows (e.g. Kit.iconOr('DoubleCash', 'Cash')), else the last one.
function Kit.iconOr(...)
	local ids = { ... }
	for _, id in ids do
		if Kit.hasIcon(id) then return id end
	end
	return ids[#ids]
end

-- (brief 23) Uploaded images that never arrive. Roblox shows an uploaded image only once moderation has approved it, and
-- never if it was rejected: the owner's Studio showed World, Shoes, Guns and Items blank while Store, Rebirth and Quest
-- drew. So every uploaded image Kit draws is watched, once per image id, and nothing on screen is ever blank:
--   * ContentProvider:PreloadAsync (Kit.Preloader) fetches it; its status callback (Enum.AssetFetchStatus) settles it:
--     Failure / TimedOut = missing for good, Success = the image shows (it is in the cache now);
--   * a label on screen that hasn't drawn after Kit.ImageGrace (0.2 s; ImageLabel.IsLoaded) shows its stand-in at once
--     and gets the image back the moment the fetch succeeds;
--   * with no answer after Kit.ImageWait seconds, or "Success" while a label on screen still doesn't draw, the image
--     counts as missing for now (stand-ins everywhere) and comes back if it arrives later.
-- The stand-ins: the flat 2D stand-in for an icon (brief 24), the frame glyph for the Robux mark, round blobs for a splat. Where
-- neither PreloadAsync nor IsLoaded can be read (an offline harness), the image is kept.
-- Kit.ImageStatus[content id]: 'checking', 'fetched' (Success, checked on screen at the deadline), 'slow' (its stand-in
-- shows while it still loads), 'ok' or 'failed'.
Kit.ImageWait = 4
Kit.ImageGrace = 0.2
Kit.ImageStatus = {}
local imageWatch = {} -- content id -> { { Label, Fail, Restore, Swapped }, ... } until it settles
local function swapEntry(e, missing)
	if not e.Label.Parent or e.Swapped == missing then return end
	e.Swapped = missing
	local fn = missing and e.Fail or e.Restore
	if fn then
		local ok, err = pcall(fn, e.Label)
		if not ok then warn('[UIKit] image stand-in: ' .. tostring(err)) end
	end
end
local function swapImages(content, missing)
	for _, e in imageWatch[content] or {} do swapEntry(e, missing) end
end
local function settleImage(content, state)
	local now = Kit.ImageStatus[content]
	if now == 'ok' or now == 'failed' then return end
	Kit.ImageStatus[content] = state
	swapImages(content, state == 'failed')
	imageWatch[content] = nil
end
-- How an image is fetched: calls back (content id, Enum.AssetFetchStatus). (A test may replace it.)
function Kit.Preloader(content, callback)
	game:GetService('ContentProvider'):PreloadAsync({ content }, callback)
end
-- Whether a label would be drawn now: it and its ancestors Visible, in an enabled ScreenGui / BillboardGui / SurfaceGui.
local function onScreen(label)
	local x = label
	while x do
		if x:IsA('LayerCollector') then return x.Enabled and x.Parent ~= nil end
		if x:IsA('GuiObject') and not x.Visible then return false end
		x = x.Parent
	end
	return false
end
-- Whether a label has drawn its image: true / false, or nil where ImageLabel.IsLoaded can't be read. (A test may replace it.)
function Kit.IsLoaded(label)
	local ok, v = pcall(function() return label.IsLoaded end)
	if not ok then return nil end
	return v == true
end
-- An entry that is on screen and still blank after the grace: its stand-in now, the image back on Success.
local function graceCheck(content, e)
	task.delay(Kit.ImageGrace, function()
		if Kit.ImageStatus[content] ~= 'checking' or e.Swapped or not e.Label.Parent then return end
		if Kit.IsLoaded(e.Label) == false and onScreen(e.Label) then swapEntry(e, true) end
	end)
end
-- Watches `label` (an ImageLabel with an uploaded Image): fail(label) shows its stand-in, restore(label) undoes it.
function Kit.watchImage(label, fail, restore)
	local content = label.Image
	if type(content) ~= 'string' or not string.find(content, '%d') then return end
	local state = Kit.ImageStatus[content]
	if state == 'ok' then return end
	if state == 'failed' then
		fail(label)
		return
	end
	local entry = { Label = label, Fail = fail, Restore = restore, Swapped = false }
	if state then
		local list = imageWatch[content]
		for i = #list, 1, -1 do
			if not list[i].Label.Parent then table.remove(list, i) end -- (labels since destroyed)
		end
		table.insert(list, entry)
		if state == 'slow' then swapEntry(entry, true) elseif state == 'checking' then graceCheck(content, entry) end
		return
	end
	Kit.ImageStatus[content] = 'checking'
	imageWatch[content] = { entry }
	graceCheck(content, entry)
	local preloads, due = true, false
	task.spawn(function()
		local ok = pcall(Kit.Preloader, content, function(_, status)
			if status == Enum.AssetFetchStatus.Success then
				local now = Kit.ImageStatus[content]
				if now == 'checking' or now == 'slow' then
					-- the image is in the cache: back on screen at once (still checked on screen at the deadline)
					Kit.ImageStatus[content] = 'fetched'
					swapImages(content, false)
				end
				if due then settleImage(content, 'ok') end
			elseif status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
				settleImage(content, 'failed')
			end
		end)
		preloads = ok
	end)
	task.delay(Kit.ImageWait, function()
		due = true
		local now = Kit.ImageStatus[content]
		if now ~= 'checking' and now ~= 'fetched' then return end
		local readable, blank = false, false
		for _, e in imageWatch[content] or {} do
			local loaded = Kit.IsLoaded(e.Label)
			if loaded then
				settleImage(content, 'ok')
				return
			end
			readable = readable or loaded ~= nil
			blank = blank or (loaded == false and e.Label.Parent ~= nil and onScreen(e.Label))
		end
		if (now == 'fetched' and not blank) or (not readable and not preloads) then
			settleImage(content, 'ok') -- (fetched and nothing on screen blank; or nothing here can tell: keep the image)
			return
		end
		-- no answer yet, or "fetched" while a label on screen still draws nothing: the stand-in for now
		Kit.ImageStatus[content] = 'slow'
		swapImages(content, true)
	end)
end

-- (brief 24) The flat stand-ins' rows until ART2's IconModels.Fallback has them (and for ids it doesn't cover):
-- { Color = the block, Glyph = a Kit.Glyphs name, Text = a short sticker, Ink = the glyph's fill (white by default),
-- Accent = its details (the block's colour by default) }. (The gamepass card art has no text: the Store puts each pass's
-- Sticker, '2x' / 'x100', on it.)
Kit.FlatInk = hex('060632') -- (the PNGs' ink: ART2's outline colour, the references' measured outline)
do
	local function row(color, glyph, text, ink, accent)
		return { Color = hex(color), Glyph = glyph, Text = text, Ink = ink and hex(ink) or nil, Accent = accent and hex(accent) or nil }
	end
	Kit.FlatDefault = {
		Shop = row('FF9A1F', 'basket'), Basket = row('FF9A1F', 'basket'), BasketRed = row('E8364A', 'basket'),
		Rebirth = row('E2484E', 'cycle'), RebirthSkip = row('2EB84A', 'cycle'), Rewards = row('E8364A', 'gift', nil, nil, 'FFD23F'),
		PVP = row('E8364A', 'fist'), Evolve = row('3FC23A', 'arrow'), Arrow = row('3FC23A', 'arrow'),
		Cash = row('3FB84A', 'cash'), CashTiny = row('3FB84A', 'cash'), CashSmall = row('3FB84A', 'cash'), CashMedium = row('3FB84A', 'cash'),
		CashLarge = row('3FB84A', 'cash'), DoubleCash = row('3FB84A', 'cash'), TenXCash = row('EC3E98', 'cash'),
		Power = row('FF9A1F', 'arm'), Muscle = row('FF9A1F', 'arm'), PowerTiny = row('FF9A1F', 'arm'), PowerSmall = row('FF9A1F', 'arm'),
		PowerMedium = row('FF9A1F', 'arm'), PowerLarge = row('FF9A1F', 'arm'), PowerPack1 = row('F3B740', 'arm'), PowerPack2 = row('E6343A', 'arm'),
		PowerPack3 = row('A64DFF', 'arm'), DoublePower = row('FF6A1F', 'arm'),
		Trophy = row('FFB020', 'trophy'), Gun = row('2F7FE0', 'gun'), Quest = row('C0683A', 'scroll', nil, nil, 'E8364A'),
		Sneaker = row('B83AD0', 'shoe', nil, nil, 'E8364A'), ShoePile = row('B83AD0', 'shoe', nil, nil, 'E8364A'), ShoeBox = row('FF8A2A', 'box'),
		Robux = row('7DE84A', 'hex'), Shield = row('2F6BE0', 'shield'), XP = row('2F6BE0', 'shield', 'XP'), Skull = row('5A5F70', 'skull'),
		VIP = row('FFB020', 'crown', nil, nil, 'E8364A'), AutoFight = row('E8364A', 'gun'), World = row('3BBA16', 'globe', nil, '5AB8FF'),
		Backpack = row('F4A423', 'bag', nil, nil, 'E8603A'), Delete = row('E8203A', 'x'), Favorite = row('FFB020', 'star', nil, 'FFE24A'),
		Search = row('2F7FE0', 'search'), PotionRed = row('D23739', 'potion'), PotionGold = row('FFAE01', 'potion'),
		BoostBundle = row('B100DF', 'potion'), Lucky = row('19B98A', 'clover', nil, 'FFE24A'), TripleOpen = row('2A86E6', 'box'),
		ExtraEquip = row('EC3E98', 'shoe'), ProBay = row('16B48A', 'arm'), GoldBay = row('FFB020', 'arm'),
	}
end
-- Config, for the families' colours (loaded on first use; the stand-ins still draw without it).
local configs = {}
local function config(name)
	if configs[name] == nil then
		configs[name] = false
		local folder = script.Parent:FindFirstChild('Config')
		local module = folder and folder:FindFirstChild(name)
		if module then
			local ok, result = pcall(require, module)
			if ok and type(result) == 'table' then configs[name] = result end
		end
	end
	return configs[name] or nil
end
-- The stand-in's look for `id`: ART2's row, else the family's colours, else Kit.FlatDefault, else a grey block with the
-- id's first letter.
function Kit.flatSpec(id)
	id = tostring(id)
	local models = Kit.iconModels()
	local rows = models and type(models.Fallback) == 'table' and models.Fallback
	local own = rows and rows[id]
	if type(own) == 'table' and typeof(own.Color) == 'Color3' then return own end
	local shoeId = string.match(id, '^Shoe_(.+)$')
	if shoeId then
		local Shoes = config('Shoes')
		local s = Shoes and Shoes.ById and Shoes.ById[shoeId]
		if s then
			local r = Shoes.RarityById and Shoes.RarityById[s.Rarity]
			local c = s.Colors or {}
			return { Color = r and r.Color or hex('B8BEC8'), Glyph = 'shoe', Ink = c.Main, Accent = c.Accent, Sole = c.Sole }
		end
		return { Color = hex('B83AD0'), Glyph = 'shoe' }
	end
	local boxId = string.match(id, '^Box_(.+)$')
	if boxId then
		local Shoes = config('Shoes')
		local b = Shoes and Shoes.BoxById and Shoes.BoxById[boxId]
		local c = b and b.Color or hex('FF8A2A')
		return { Color = c, Glyph = 'box', Accent = c:Lerp(Color3.new(0, 0, 0), 0.2) }
	end
	local gunId = string.match(id, '^Gun_(.+)$')
	if gunId then
		local Guns = config('Guns')
		local g = Guns and Guns.ById and Guns.ById[gunId]
		return { Color = g and g.Color or hex('2F7FE0'), Glyph = 'gun' }
	end
	return Kit.FlatDefault[id] or { Color = hex('8A92A6'), Glyph = 'text', Text = string.upper(string.sub(id, 1, 1)) }
end

-- The glyphs, drawn with plain frames in a square box (0..1 both ways): { centre x, centre y, width, height, corner
-- (a fraction of the shorter side; 0.5 = round), rotation, tone, detail }. tone: nil = the fill (white, or the row's
-- Ink), 'a' = the accent, 'b' = the block's colour (a hole), 'k' = the ink, 's' = a shoe's sole. The shapes are drawn
-- twice, an ink copy a little bigger under the fill, so the glyph has ONE outline round its whole silhouette; `detail`
-- parts go on top with a thin outline of their own.
Kit.Glyphs = {
	-- (CRITIC4 r1: a flexed arm like ref u27: the forearm up the left from the elbow to the fist, the upper arm along the
	-- bottom with the round bicep on it; one short crease on the fist, in the block's colour)
	arm = { { 0.28, 0.52, 0.29, 0.58, 0.45, 3 }, { 0.38, 0.22, 0.46, 0.36, 0.48, 12 }, { 0.6, 0.78, 0.74, 0.3, 0.5, 0 }, { 0.7, 0.6, 0.46, 0.46, 0.5, 0 },
		{ 0.29, 0.75, 0.32, 0.32, 0.5, 0 }, { 0.5, 0.27, 0.05, 0.16, 0.5, 20, 'b', true } },
	dumbbell = { { 0.5, 0.5, 0.74, 0.14, 0.3, -20 }, { 0.26, 0.59, 0.2, 0.6, 0.2, -20 }, { 0.74, 0.41, 0.2, 0.6, 0.2, -20 }, { 0.12, 0.64, 0.12, 0.4, 0.3, -20 },
		{ 0.88, 0.36, 0.12, 0.4, 0.3, -20 }, { 0.26, 0.59, 0.06, 0.4, 0.5, -20, 'a', true }, { 0.74, 0.41, 0.06, 0.4, 0.5, -20, 'a', true } },
	cash = { { 0.46, 0.42, 0.84, 0.46, 0.14, -10 }, { 0.54, 0.6, 0.84, 0.46, 0.14, 0 }, { 0.54, 0.6, 0.24, 0.24, 0.5, 0, 'a', true },
		{ 0.25, 0.6, 0.08, 0.08, 0.5, 0, 'a', true }, { 0.83, 0.6, 0.08, 0.08, 0.5, 0, 'a', true } },
	coin = { { 0.5, 0.5, 0.84, 0.84, 0.5, 0 }, { 0.5, 0.5, 0.5, 0.5, 0.5, 0, 'a', true } },
	cycle = { { 0.5, 0.5, 0.86, 0.86, 0.5, 0 }, { 0.8, 0.26, 0.3, 0.3, 0.08, 45 }, { 0.5, 0.5, 0.38, 0.38, 0.5, 0, 'b', true }, { 0.2, 0.72, 0.16, 0.1, 0.3, 45, 'b', true } },
	basket = { { 0.5, 0.64, 0.84, 0.52, 0.16, 0 }, { 0.5, 0.38, 0.98, 0.16, 0.4, 0 }, { 0.5, 0.12, 0.56, 0.1, 0.5, 0 }, { 0.25, 0.24, 0.1, 0.28, 0.5, 0 },
		{ 0.75, 0.24, 0.1, 0.28, 0.5, 0 }, { 0.35, 0.66, 0.08, 0.32, 0.5, 0, 'a', true }, { 0.5, 0.66, 0.08, 0.32, 0.5, 0, 'a', true }, { 0.65, 0.66, 0.08, 0.32, 0.5, 0, 'a', true } },
	globe = { { 0.5, 0.5, 0.9, 0.9, 0.5, 0 }, { 0.36, 0.38, 0.36, 0.26, 0.5, -20, 'a', true }, { 0.66, 0.66, 0.3, 0.22, 0.5, 15, 'a', true }, { 0.7, 0.27, 0.14, 0.12, 0.5, 0, 'a', true } },
	shoe = { { 0.5, 0.78, 1, 0.16, 0.5, 0, 's' }, { 0.42, 0.6, 0.7, 0.3, 0.3, 0 }, { 0.76, 0.65, 0.4, 0.22, 0.5, 0 }, { 0.2, 0.48, 0.26, 0.34, 0.4, 0 },
		{ 0.4, 0.42, 0.22, 0.2, 0.4, -18 }, { 0.5, 0.63, 0.36, 0.09, 0.5, -14, 'a', true }, { 0.48, 0.47, 0.1, 0.05, 0.5, 25, 's', true }, { 0.58, 0.51, 0.1, 0.05, 0.5, 25, 's', true } },
	gun = { { 0.56, 0.38, 0.84, 0.22, 0.15, 0 }, { 0.32, 0.64, 0.22, 0.44, 0.2, 14 }, { 0.46, 0.5, 0.3, 0.14, 0.2, 0 }, { 0.88, 0.38, 0.08, 0.1, 0.5, 0, 'k', true },
		{ 0.47, 0.6, 0.1, 0.1, 0.5, 0, 'b', true }, { 0.56, 0.31, 0.5, 0.05, 0.5, 0, 'a', true } },
	bag = { { 0.5, 0.58, 0.74, 0.72, 0.3, 0 }, { 0.5, 0.15, 0.32, 0.14, 0.5, 0 }, { 0.5, 0.4, 0.76, 0.26, 0.3, 0, 'a', true }, { 0.5, 0.73, 0.42, 0.22, 0.2, 0, 'a', true } },
	scroll = { { 0.5, 0.5, 0.86, 0.4, 0.18, -28 }, { 0.19, 0.69, 0.25, 0.25, 0.5, -28 }, { 0.81, 0.31, 0.25, 0.25, 0.5, -28 }, { 0.5, 0.5, 0.14, 0.48, 0.1, -28, 'a', true } },
	box = { { 0.5, 0.64, 0.82, 0.52, 0.1, 0 }, { 0.5, 0.35, 0.94, 0.22, 0.12, 0, 'a' }, { 0.5, 0.66, 0.44, 0.18, 0.2, 0, nil, true } },
	potion = { { 0.5, 0.65, 0.74, 0.64, 0.5, 0 }, { 0.5, 0.28, 0.28, 0.28, 0.2, 0 }, { 0.5, 0.13, 0.38, 0.13, 0.3, 0, 'a' }, { 0.5, 0.74, 0.56, 0.34, 0.5, 0, 'a', true },
		{ 0.38, 0.55, 0.1, 0.1, 0.5, 0, nil, true } },
	x = { { 0.5, 0.5, 0.96, 0.3, 0.25, 45 }, { 0.5, 0.5, 0.96, 0.3, 0.25, -45 } },
	arrow = { { 0.5, 0.68, 0.34, 0.52, 0.12, 0 }, { 0.5, 0.38, 0.54, 0.54, 0.1, 45 } },
	trophy = { { 0.5, 0.34, 0.66, 0.48, 0.35, 0 }, { 0.19, 0.32, 0.24, 0.24, 0.5, 0 }, { 0.81, 0.32, 0.24, 0.24, 0.5, 0 }, { 0.5, 0.64, 0.14, 0.24, 0.1, 0 },
		{ 0.5, 0.83, 0.56, 0.14, 0.25, 0 }, { 0.19, 0.32, 0.1, 0.1, 0.5, 0, 'b', true }, { 0.81, 0.32, 0.1, 0.1, 0.5, 0, 'b', true }, { 0.5, 0.36, 0.2, 0.2, 0.5, 0, 'a', true } },
	gift = { { 0.5, 0.65, 0.82, 0.54, 0.08, 0 }, { 0.5, 0.38, 0.94, 0.18, 0.1, 0 }, { 0.37, 0.2, 0.26, 0.18, 0.5, -22, 'a' }, { 0.63, 0.2, 0.26, 0.18, 0.5, 22, 'a' },
		{ 0.5, 0.6, 0.15, 0.62, 0, 0, 'a', true } },
	hex = { { 0.5, 0.5, 0.8, 0.46, 0, 0 }, { 0.5, 0.5, 0.8, 0.46, 0, 60 }, { 0.5, 0.5, 0.8, 0.46, 0, 120 }, { 0.5, 0.5, 0.26, 0.26, 0.12, 0, 'b', true } },
	shield = { { 0.5, 0.38, 0.76, 0.5, 0.18, 0 }, { 0.5, 0.6, 0.52, 0.52, 0.1, 45 }, { 0.5, 0.46, 0.3, 0.3, 0.5, 0, 'a', true } },
	skull = { { 0.5, 0.42, 0.82, 0.7, 0.5, 0 }, { 0.5, 0.74, 0.5, 0.3, 0.25, 0 }, { 0.33, 0.46, 0.24, 0.26, 0.5, 0, 'k', true }, { 0.67, 0.46, 0.24, 0.26, 0.5, 0, 'k', true },
		{ 0.5, 0.63, 0.1, 0.1, 0.2, 45, 'k', true }, { 0.42, 0.8, 0.04, 0.14, 0.5, 0, 'k', true }, { 0.58, 0.8, 0.04, 0.14, 0.5, 0, 'k', true } },
	search = { { 0.4, 0.4, 0.64, 0.64, 0.5, 0 }, { 0.75, 0.75, 0.42, 0.16, 0.5, 45 }, { 0.4, 0.4, 0.38, 0.38, 0.5, 0, 'b', true } },
	-- (CRITIC4 r1: not a castle: three tall points with balls on their tips, a band, gems)
	crown = { { 0.21, 0.46, 0.3, 0.3, 0.06, 45 }, { 0.5, 0.42, 0.34, 0.34, 0.06, 45 }, { 0.79, 0.46, 0.3, 0.3, 0.06, 45 }, { 0.5, 0.67, 0.64, 0.24, 0.06, 0 },
		{ 0.5, 0.85, 0.94, 0.2, 0.3, 0 }, { 0.21, 0.22, 0.15, 0.15, 0.5, 0 }, { 0.5, 0.15, 0.17, 0.17, 0.5, 0 }, { 0.79, 0.22, 0.15, 0.15, 0.5, 0 },
		{ 0.5, 0.85, 0.14, 0.14, 0.5, 45, 'a', true }, { 0.25, 0.85, 0.09, 0.09, 0.5, 0, 'a', true }, { 0.75, 0.85, 0.09, 0.09, 0.5, 0, 'a', true } },
	bolt = { { 0.58, 0.3, 0.26, 0.5, 0.1, 22 }, { 0.42, 0.7, 0.26, 0.5, 0.1, 22 }, { 0.5, 0.5, 0.52, 0.16, 0.1, -12 } },
	lock = { { 0.5, 0.66, 0.74, 0.52, 0.16, 0 }, { 0.5, 0.34, 0.52, 0.52, 0.5, 0 }, { 0.5, 0.37, 0.26, 0.3, 0.5, 0, 'b', true }, { 0.5, 0.67, 0.1, 0.2, 0.3, 0, 'k', true } },
	-- (CRITIC4 r1: PVP's boxing glove: the round mitt, the thumb, the cuff)
	fist = { { 0.54, 0.4, 0.7, 0.62, 0.48, -10 }, { 0.24, 0.5, 0.24, 0.36, 0.5, -24 }, { 0.5, 0.8, 0.5, 0.26, 0.2, -10, 'a' },
		{ 0.34, 0.52, 0.05, 0.22, 0.5, -24, 'b', true }, { 0.5, 0.7, 0.5, 0.05, 0.5, -10, 'k', true } },
	-- (CRITIC4 r1: Lucky's clover: four round leaves and a stem)
	clover = { { 0.49, 0.26, 0.38, 0.38, 0.5, 0 }, { 0.26, 0.49, 0.38, 0.38, 0.5, 0 }, { 0.72, 0.49, 0.38, 0.38, 0.5, 0 }, { 0.49, 0.72, 0.38, 0.38, 0.5, 0 },
		{ 0.74, 0.82, 0.08, 0.34, 0.5, -40 }, { 0.49, 0.49, 0.16, 0.16, 0.5, 45, 'b', true } },
}
-- Draws glyph `kind` in a `box` px square centred in parent, from ZIndex z (scale: the square as a fraction of the
-- parent instead, so it follows a holder drawn at another size, e.g. in a BillboardGui). colours: { Fill, Accent, Base,
-- Sole, Text }. 'star' is the outlined text star, 'text' (and any name Kit.Glyphs lacks) is colours.Text.
function Kit.glyph(parent, kind, colours, box, z, scale)
	local holder = blank({ Name = 'Glyph', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = scale and UDim2.fromScale(scale, scale) or UDim2.fromOffset(box, box), ZIndex = z, Parent = parent })
	local ink = Kit.FlatInk
	local t = math.max(1.5, box * 0.07)
	local parts = Kit.Glyphs[kind]
	if not parts then
		local text = kind == 'star' and '★' or tostring(colours.Text or '?')
		local size = kind == 'star' and math.floor(box * 1.25) or Kit.fitSize(text, math.floor(box * 0.82), box * 1.1, 8)
		Kit.text({ Name = 'Text', Text = text, TextSize = size, TextColor3 = colours.Fill, Stroke = ink, StrokeThickness = t, ZIndex = z + 1, Parent = holder })
		return holder
	end
	local function tone(name)
		if name == 'a' then return colours.Accent end
		if name == 'b' then return colours.Base end
		if name == 'k' then return ink end
		if name == 's' then return colours.Sole or Kit.Color.white end
		return colours.Fill
	end
	local function part(p, grow, color, zz, edge)
		local f = blank({ BackgroundTransparency = 0, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.new(p[3], grow, p[4], grow), Rotation = p[6] or 0, ZIndex = zz, Parent = holder })
		if (p[5] or 0) > 0 then corner(UDim.new(p[5], 0)).Parent = f end
		if edge then stroke(ink, edge, true, 0, Enum.LineJoinMode.Round).Parent = f end
		return f
	end
	for _, p in parts do
		if not p[8] then part(p, 2 * t, ink, z) end
	end
	for _, p in parts do
		if not p[8] then part(p, 0, tone(p[7]), z + 1) end
	end
	for _, p in parts do
		if p[8] then part(p, 0, tone(p[7]), z + 2, p[7] ~= 'k' and math.max(1, t * 0.5) or nil) end
	end
	return holder
end

-- The flat stand-in of icon `id` in holder (filling it): the rounded block, its ink outline and one soft highlight, the
-- glyph and the row's sticker text. props.Locked: a dark silhouette block (things you don't own yet). Every part sits in
-- one frame with the attribute Flat, so a late upload takes it away again (Kit.icon3d's restore).
-- props.Bare: no block, the glyph alone and bigger in the icon's own colours (a picture sitting on a splat or a slab:
-- the inventory's items, the unboxing's pairs; the splat is its backdrop), black when Locked.
function Kit.flatIcon(holder, id, size, props)
	props = props or {}
	local spec = Kit.flatSpec(id)
	local locked = props.Locked == true
	local z = holder.ZIndex
	local base = locked and hex('262A38') or spec.Color
	local white, black = Kit.Color.white, Color3.new(0, 0, 0)
	local root = blank({ Name = 'Flat', Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
	root:SetAttribute('Flat', true)
	root:SetAttribute('Bare', props.Bare == true)
	if props.Bare and spec.Glyph ~= 'text' then
		local fill = locked and hex('16161E') or spec.Ink or spec.Color
		local colours = { Fill = fill, Accent = locked and fill or spec.Accent or fill:Lerp(white, 0.5), Base = locked and fill or fill:Lerp(black, 0.4), Sole = locked and fill or spec.Sole }
		Kit.glyph(root, spec.Glyph, colours, math.floor(size * 0.86), z, 0.86)
		return root
	end
	local block = blank({ Name = 'Block', BackgroundTransparency = 0, BackgroundColor3 = white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), ZIndex = z, Parent = root })
	corner(UDim.new(0.24, 0)).Parent = block
	stroke(Kit.FlatInk, math.max(1.5, size * 0.045), true).Parent = block
	new('UIGradient', { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, base:Lerp(white, 0.3)), ColorSequenceKeypoint.new(0.55, base), ColorSequenceKeypoint.new(1, base:Lerp(black, 0.2)) }), Parent = block })
	if size >= 30 and not locked then
		local shine = blank({ Name = 'Highlight', BackgroundTransparency = 0.55, BackgroundColor3 = white, Position = UDim2.fromScale(0.12, 0.08), Size = UDim2.fromScale(0.36, 0.09), Rotation = -10, ZIndex = z, Parent = block })
		corner(UDim.new(0.5, 0)).Parent = shine
	end
	local colours = locked and { Fill = hex('3E4558'), Accent = hex('323848'), Base = base, Sole = hex('3E4558'), Text = '?' }
		or { Fill = spec.Ink or white, Accent = spec.Accent or base, Base = base, Sole = spec.Sole, Text = spec.Text }
	Kit.glyph(root, spec.Glyph or 'text', colours, math.floor(size * 0.6), z + 1, 0.6)
	if spec.Text and spec.Glyph ~= 'text' and not locked and size >= 28 then
		local ts = Kit.fitSize(spec.Text, math.floor(size * 0.34), size * 0.62, 8)
		Kit.text({ Name = 'Sticker', Text = spec.Text, TextSize = ts, Stroke = Kit.FlatInk, StrokeThickness = math.max(1.5, ts * 0.16), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.7, 0.78), Size = UDim2.fromScale(0.7, 0.4), Rotation = -8, ZIndex = z + 4, Parent = root })
	end
	return root
end

-- An icon by IconModels id: its uploaded PNG (one ImageLabel), or the flat stand-in while that can't draw.
-- props: Position, AnchorPoint, ZIndex, Color (ImageColor3), Rotation, Locked (a black silhouette of the PNG / a dark
-- stand-in), Bare (true by default: the stand-in without its block; false asks for the block: Kit.flatIcon), Place (brief 25:
-- { Rule, W, H, X0, Y0 }, Kit.place: sized and moved to where the reference puts its picture; size is then ignored).
-- Returns the holder, `size` square.
function Kit.icon3d(id, size, props)
	props = props or {}
	local z = props.ZIndex or 1
	local place = props.Place
	-- (brief 25, CRITIC4: "a tile on a tile") the references never put a picture on a block of its own: the stand-in is
	-- the bare glyph unless the caller asks for the block (Bare = false: a plain backdrop, e.g. a sheet of icons)
	local bare = props.Bare ~= false
	local image = Kit.iconImage(id)
	if place then size = Kit.placeSize(id, image ~= '', bare, place) end
	local holder = blank({ Name = 'Icon3D_' .. id, Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z })
	holder:SetAttribute('IconId', id)
	local black = Color3.new(0, 0, 0)
	local packed = ImageLoader.packed('Icons', id) ~= nil
	if image ~= '' or packed then
		-- ART2's PNG: one ImageLabel, outline and shading baked in; the uploaded id, else (round 3) the packed pixels
		-- drawn in game by Shared/ImageLoader, so every icon and item picture shows without an upload
		local img = new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = props.Locked and black or props.Color or Color3.new(1, 1, 1), Rotation = props.Rotation or 0, ZIndex = z, Parent = holder })
		img:SetAttribute('PreviewImage', 'icon3d:' .. id) -- the offline previewer draws hood/art/icons3d/<id>.png here
		local function flat()
			img.Visible = false
			local has = false
			for _, d in holder:GetChildren() do
				if d:GetAttribute('Flat') then has = true end
			end
			if not has then
				local f = Kit.flatIcon(holder, id, holder.Size.X.Offset, { Locked = img.ImageColor3 == black, Bare = bare })
				f.Rotation = img.Rotation
				Kit.replace(holder)
			end
		end
		local function unflat()
			for _, d in holder:GetChildren() do
				if d:GetAttribute('Flat') then d:Destroy() end
			end
			img.Visible = true
			Kit.replace(holder)
		end
		local function drawPacked()
			if not packed then return flat() end
			img.Image = ''
			ImageLoader.apply(img, 'Icons', id, '', { onShow = unflat, onFail = flat })
		end
		if image == '' then
			drawPacked()
		else
			-- (brief 23/24) an upload that never arrives (in review, rejected) swaps to the packed picture (or the flat
			-- stand-in); back to the upload if it comes later
			Kit.watchImage(img, drawPacked, function()
				ImageLoader.apply(img, 'Icons', id, image, { onShow = unflat })
			end)
		end
	else
		local f = Kit.flatIcon(holder, id, size, { Locked = props.Locked, Bare = bare })
		f.Rotation = props.Rotation or 0
	end
	if place then Kit.place(holder, place) end
	return holder
end

---------------------------------------------------------------------------------------------- picture placement
-- (brief 25, "it's not in place where it has to be, especially the pictures") Where the references put a picture on its
-- button, measured as fractions of the button's HEIGHT h (its whole look, outline included). The picture's DRAWN
-- content (not its square) fits a W x H box (in h); its centre sits X of the button's width plus XH (in h) across and
-- Y (in h) down from the button's top; Top (in h, optional): the content's top is at least that high (it pops out).
-- Content bounds: ART2's IconModels.Bounds[id] (the PNG's alpha box), the flat stand-in's glyph, else a centred square.
-- Every rule is a contain fit (the drawn box fits inside both W and H). TopAt (in h, optional): the content's top sits
-- exactly there (Y is then ignored).
Kit.Place = {
	-- ref22_hud_buttons (a square, B = 179 ref px): the globe 0.89 B wide and 0.16 B over the top; the dog, mask and
	-- backpack 0.80-0.85 B tall, 0.13-0.15 B over; the scroll 0.87 B wide; every picture centred 0.28 B down
	hud = { W = 0.92, H = 0.87, X = 0.5, XH = 0, Y = 0.28, Top = -0.12 },
	-- the Store bar (145 ref px tall, 2.88 h wide): the basket 1.21 h wide and 0.81 h tall, centred 0.2 h down and 0.07 h
	-- left of the bar's centre (its handle 0.21 h over the top). (Every rule is a contain fit: a picture taller than the
	-- reference's is held to its height, so nothing stands higher over its bar than the reference's)
	-- (the basket's bottom hides behind the "Store" label: its TOP is the line that matters, so it is anchored there and
	-- may be up to 1.05 h tall; TopAt: the content's top, in h, from the bar's top)
	-- (CRITIC4, DRAW's deeper basket: H up to 1.2 h for the reference's width; ClipTop: the picture is drawn in a frame
	-- from that height, in h, down to the bar's bottom edge, so a deep basket never shows under the bar)
	storeBar = { W = 1.21, H = 1.2, X = 0.5, XH = -0.07, Y = 0.2, TopAt = -0.21, ClipTop = -0.45 },
	-- user_26's +1B / +10B / +100B packs (65 ref px tall): the arm 1.0 h wide and 0.92 h tall, centred 0.34 h in from the
	-- left edge (it hangs 0.17 h out) and 0.48 h down
	pack = { W = 1.0, H = 0.95, X = 0, XH = 0.34, Y = 0.48 },
	-- user_26's 2x Wins / +2x Power cards (101 ref px tall): the trophy / arm 1.1 h wide and 0.97 h tall, centred 0.37 h
	-- down and 0.08 h right of the centre, 0.11 h over the top, behind the title
	offer = { W = 1.1, H = 0.97, X = 0.5, XH = 0.08, Y = 0.37, Top = -0.1 },
	-- ref22_store_*'s window header (170 ref px tall): the basket 0.85 h wide and 0.79 h tall, centred 0.62 h in from the
	-- header's left end and 0.51 h down; the title starts right after it (Kit.window)
	windowHeader = { W = 0.85, H = 0.8, X = 0, XH = 0.62, Y = 0.51 },
	-- (Oct 27) the owner's UI mockup: the window's icon breaks out of the yellow bar's left end, about 1.3x the bar's
	-- height, its top about a third of the bar over the bar's top edge
	breakout = { W = 1.3, H = 1.3, X = 0, XH = 0.72, Y = 0.36 },
	-- ref22_pets_window's header (132 ref px tall): the backpack 1.04 h wide and 0.95 h tall, centred 0.8 h in from the
	-- header's left end and 0.52 h down
	header = { W = 1.04, H = 0.95, X = 0, XH = 0.8, Y = 0.52 },
	-- its side tabs (95 ref px tall, 115 the open one): the mask / crystal / egg 0.82-0.98 h tall, the paw 1.13 h wide,
	-- centred across and about 0.43 h down, from up to 0.08 h over the tab's top down to the caption
	tab = { W = 1.15, H = 0.9, X = 0.5, XH = 0, Y = 0.43, Top = -0.06 },
	-- user_28's gamepass cards (430 ref px tall): the punching bag and its post 0.79 h wide and 0.98 h tall, centred 0.75
	-- of the card's width across and 0.42 h down, 0.07 h over the top
	passCard = { W = 0.79, H = 0.98, X = 0.75, XH = 0, Y = 0.42, Top = -0.07 },
	-- the wide banner card (user_28's HACKER ZONE): the art at the left end, the card's height and a little more
	bannerCard = { W = 1.0, H = 1.0, X = 0, XH = 0.64, Y = 0.42 },
	-- ref22_store_packs' Tiny..Large Pack cards (410 ref px tall, 1.63 h wide): the pile 0.66 h wide and 0.51 h tall,
	-- centred 0.236 of the card's width across and 0.57 h down (the piles grow in the art)
	packCard = { W = 0.66, H = 0.53, X = 0.236, XH = 0, Y = 0.57 },
	-- user_26's counters (a row h = the number's size + 12: the trophy 66 x 65 ref px next to 45 px tall digits, its
	-- centre 1.4 digit heights in from the left edge): the picture 0.95 h wide and 0.85 h tall, centred 0.88 h in
	counter = { W = 0.95, H = 0.85, X = 0, XH = 0.88, Y = 0.5 },
}
local InstanceMap = require(script.Parent.InstanceMap) -- (not a weak table: see InstanceMap)
local placed = InstanceMap.new()
-- The drawn content of a picture, as { x0, y0, x1, y1 } of its square.
local function glyphBounds(kind)
	local parts = Kit.Glyphs[kind]
	if not parts then return { 0.1, 0.1, 0.9, 0.9 } end
	local x0, y0, x1, y1 = 1, 1, 0, 0
	for _, p in parts do
		if not p[8] then
			x0, x1 = math.min(x0, p[1] - p[3] / 2), math.max(x1, p[1] + p[3] / 2)
			y0, y1 = math.min(y0, p[2] - p[4] / 2), math.max(y1, p[2] + p[4] / 2)
		end
	end
	return { math.max(0, x0), math.max(0, y0), math.min(1, x1), math.min(1, y1) }
end
function Kit.contentBounds(id, imaged, bare)
	if imaged then
		local models = Kit.iconModels()
		local b = models and type(models.Bounds) == 'table' and models.Bounds[id]
		if type(b) == 'table' and #b == 4 then return b end
		return { 0.06, 0.06, 0.94, 0.94 }
	end
	local spec = Kit.flatSpec(id)
	if bare and spec.Glyph ~= 'text' then
		local g = glyphBounds(spec.Glyph)
		return { 0.07 + 0.86 * g[1], 0.07 + 0.86 * g[2], 0.07 + 0.86 * g[3], 0.07 + 0.86 * g[4] }
	end
	return { 0.08, 0.08, 0.92, 0.92 }
end
local function ruleOf(place)
	local rule = place.Rule
	if type(rule) == 'string' then rule = Kit.Place[rule] end
	return rule
end
-- The square's size for picture `id` placed by `place` = { Rule (a Kit.Place name or a table), W, H (the button's
-- whole size), X0, Y0 (where the holder's parent sits inside the button: a block's Body is inset by its outline) }.
function Kit.placeSize(id, imaged, bare, place)
	local rule = ruleOf(place)
	local b = Kit.contentBounds(id, imaged, bare)
	local cw, ch = math.max(0.05, b[3] - b[1]), math.max(0.05, b[4] - b[2])
	return math.floor(math.min(rule.W * place.H / cw, rule.H * place.H / ch) + 0.5)
end
-- Sizes and moves an icon3d holder so its drawn content lands where `place` says (and remembers it: the holder is
-- placed again if its picture swaps between the PNG and the flat stand-in).
function Kit.place(holder, place)
	local rule = ruleOf(place)
	if not rule then return holder end
	placed[holder] = place
	local id = holder:GetAttribute('IconId') or string.match(holder.Name, '^Icon3D_(.+)$') or ''
	local img = holder:FindFirstChild('Image')
	local flat
	for _, d in holder:GetChildren() do
		if d:GetAttribute('Flat') then flat = d end
	end
	local imaged = img ~= nil and img.Visible and not flat
	local bare = flat and flat:GetAttribute('Bare') == true or (not flat and place.Bare ~= false)
	local b = Kit.contentBounds(id, imaged, bare)
	local cw, ch = math.max(0.05, b[3] - b[1]), math.max(0.05, b[4] - b[2])
	local h = place.H
	local size = math.min(rule.W * h / cw, rule.H * h / ch)
	local cx = (rule.X or 0.5) * place.W + (rule.XH or 0) * h
	local cy = rule.Y * h
	if rule.TopAt then
		cy = rule.TopAt * h + ch * size / 2
	elseif rule.Top and cy - ch * size / 2 > rule.Top * h then
		cy = rule.Top * h + ch * size / 2
	end
	local function round(v) return math.floor(v + 0.5) end -- (a UDim's offset is a whole pixel)
	holder.AnchorPoint = Vector2.zero
	holder.Size = UDim2.fromOffset(round(size), round(size))
	holder.Position = UDim2.fromOffset(round(cx - (b[1] + b[3]) / 2 * size - (place.X0 or 0)), round(cy - (b[2] + b[4]) / 2 * size - (place.Y0 or 0)))
	return holder
end
-- The x (in the holder's parent) where a placed picture's drawn content ends.
function Kit.contentRight(holder)
	local id = holder:GetAttribute('IconId') or ''
	local img = holder:FindFirstChild('Image')
	local flat
	for _, d in holder:GetChildren() do
		if d:GetAttribute('Flat') then flat = d end
	end
	local b = Kit.contentBounds(id, img ~= nil and img.Visible and not flat, flat == nil or flat:GetAttribute('Bare') == true)
	return holder.Position.X.Offset + b[3] * holder.Size.X.Offset
end
function Kit.replace(holder)
	local place = placed[holder]
	if place then Kit.place(holder, place) end
end
-- Black (props.Locked) or not: turns an icon3d holder into its silhouette after the fact (the PNG tinted black, or the
-- stand-in rebuilt dark).
function Kit.setLocked(holder, locked)
	local img = holder:FindFirstChild('Image')
	if img and img:IsA('ImageLabel') then img.ImageColor3 = locked and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end
	for _, d in holder:GetChildren() do
		if d:GetAttribute('Flat') then
			local id = string.match(holder.Name, '^Icon3D_(.+)$')
			local bare = d:GetAttribute('Bare') == true
			d:Destroy()
			if id then Kit.flatIcon(holder, id, holder.Size.X.Offset, { Locked = locked, Bare = bare }) end
		end
	end
end

---------------------------------------------------------------------------------------------- 3D items (brief 27)
-- The user (brief 27): "in the inventory you see the actual 3d model, not a sketch ... make them presentable ... fine
-- tuned". ITEMS show as their real part-built models (Shared/Models: a ShoeModels pair, GunModels, BoxModels) in a
-- ViewportFrame; the HUD and menu ICONS (buttons, potions, cash, passes, tabs) stay the drawn PNGs (Kit.icon3d).
--   Kit.model3d(kind, id, size, opts) -> holder   kind 'shoe' | 'gun' | 'box'; size a number (square) or a Vector2.
--       opts: Name, Position, AnchorPoint, ZIndex, LayoutOrder, Locked (a black silhouette of the same model: a thing you
--       don't own yet), Rarity (a shoe's rarity: ShoeFX's glow behind it from Epic up, rays from Legendary up), Fill (how
--       much of the item's body fills the cell; the studio's by default), MaxReach (how far the whole model may reach,
--       share of the cell), Overflow (the viewport's size over the cell's: the studio's or Kit.Model3DOverflow by
--       default, room for a decoration past the cell's edge), Whole (framed on the whole model, decorations too, so it
--       fits a viewport the size of its cell: the Store's hero boxes), Pitch / Fov (the cell's own camera: the hero
--       boxes look down a little more, nearly flat-on, so a halo reads as a ring), YWeight (a gun's height weight: the
--       Guns tab's gun in hand), Priority (higher gets a live viewport first).
--   Kit.model3dActive(holder, reason, on)   the gentle spin and bob while any reason ('hover', 'select', ...) is on
--   Kit.model3dHover(holder, button)        the pointer (or a gamepad's selection) on `button` spins the item
--   Kit.model3dDim(holder, on)              faded (a search that doesn't match it)
--   Kit.model3dStats()                      { Registered, Live, Built, Cap, Driver, Parts } (tests, the shot tools)
--   Kit.frame3d(model, back, fov, aspect, fill) -> camera CFrame, distance, focus, fill reached (pure maths)
-- ONE studio per kind (Kit.Studio): the camera's yaw and pitch round the item's show side, the FOV, how much of the cell
-- the item fills (framed on its VISIBLE parts' corners, so every shoe looks as big as every other shoe), the key light (in
-- camera space: from the upper front-left), its colour and the ambient (a ViewportFrame has one light; the ambient is the
-- fill). A model that can't build shows the item's drawn PNG (its flat stand-in while that can't load) instead.
-- Performance (phones): a cell builds its model only once it is near the screen (Kit.Model3DBuilds a frame), at most
-- Kit.Model3DCap live viewports (24 on PC, 12 on a phone; any more show their PNG), viewports scrolled away are hidden,
-- ones in a closed window don't count, and ONE shared render-step connection does all of it: it turns the active items
-- (one or two) and checks what is on screen ~7 times a second; it disconnects once nothing is registered. Built models
-- beyond Kit.Model3DKeep are freed, least recently shown first.
do
	local V3 = Vector3.new
	-- yaw: degrees from Side toward Toward; pitch: degrees down onto the item. Key: the light's travel in camera space
	-- (x right, y up, -z into the picture): steeply from above and in front, on the side the item's main face (Side) is
	-- turned to (a shoe's long side looks right, a gun's and a box's front left), so the top is brightest, the main face
	-- ~25% darker and the end face (Toward) in the ambient's shade. Spin: degrees a second while active; Bob: the share of
	-- the cell's height it rises and falls, at BobHz.
	-- (CRITIC5 r1) Framed on the item's BODY (Body: which parts count), so wings, spikes, lollipops and box toppers don't make
	-- a decorated item look smaller than a plain one; the whole model still stays inside MaxReach of the cell (a shoe's
	-- 1.3: a decoration may spill 15% of the cell past its edge, into the viewport's overflow; nothing is clipped). Guns
	-- are framed on max(length, YWeight x height), so a stubby pistol isn't drawn bigger than a long rifle.
	-- The light: a ViewportFrame has ONE directional light and an ambient, so the key comes steeply from above and in
	-- front (tops and top edges bright, side faces clearly darker) over a ~45% ambient (no black faces).
	local SHOE_BODY = { Outsole = true, OutsoleToe = true, Sole = true, SoleToe = true, Stripe = true, StripeToe = true, ToeBox = true, ToeCap = true,
		Quarter = true, HeelCounter = true, HeelTab = true, Ankle = true, AnkleBack = true, AnkleSide = true, AnkleWall = true, Collar = true,
		CollarCorner = true, Lining = true, Tongue = true, TongueTop = true, TongueStrip = true, Eyestay = true, Flash = true }
	local function inTopper(part)
		local x = part.Parent
		while x and x:IsA('Model') do
			if x.Name == 'Topper' then return true end
			x = x.Parent
		end
		return false
	end
	Kit.Studio = {
		-- the pair from the left shoe's outer side, turned toward the toes: the classic sneaker shot (the right shoe peeks
		-- out behind it)
		shoe = { Side = V3(-1, 0, 0), Toward = V3(0, 0, -1), Yaw = 32, Pitch = 15, Fov = 26, Fill = 0.8, MaxReach = 1.3,
			Body = function(part) return SHOE_BODY[part.Name] == true end,
			Key = V3(-0.42, -1.1, -0.5), Light = Color3.fromRGB(255, 250, 240), Ambient = Color3.fromRGB(112, 116, 132), Spin = 40, Bob = 0.025, BobHz = 0.5 },
		-- the gun's right side (muzzle to the right), turned a little toward the muzzle
		gun = { Side = V3(1, 0, 0), Toward = V3(0, 0, -1), Yaw = 27, Pitch = 13, Fov = 26, Fill = 0.8, MaxReach = 0.97, YWeight = 1.8,
			Key = V3(0.42, -1.2, -0.5), Light = Color3.fromRGB(255, 252, 246), Ambient = Color3.fromRGB(124, 128, 144), Spin = 40, Bob = 0.025, BobHz = 0.5 },
		-- the box's name plate, turned toward its left side, from a little above (the lid and its topper show). Framed on
		-- its tub: the topper (the box's identity) may rise up to 22% of the cell past its top edge, and a tall one sets
		-- the tub up to 10% of the cell lower (Drop) before it would shrink the box; its viewport is 1.5x the cell.
		box = { Side = V3(0, 0, -1), Toward = V3(-1, 0, 0), Yaw = 30, Pitch = 17, Fov = 26, Fill = 0.8, MaxReach = 1.45, Overflow = 1.5, Drop = 0.2,
			Body = function(part) return not inTopper(part) end,
			Key = V3(0.5, -1.1, -0.55), Light = Color3.fromRGB(255, 248, 234), Ambient = Color3.fromRGB(114, 114, 128), Spin = 36, Bob = 0.025, BobHz = 0.5 },
	}
	-- A viewport is Kit.Model3DOverflow x its cell (centred), so a decoration reaching past the cell (a wing, a topper: up
	-- to MaxReach 1.3, 15% of the cell past its edge) spills over the edge instead of being cut there; the camera's FOV is
	-- widened to match, so the item itself is framed for its cell.
	Kit.Model3DOverflow = 1.36
	local function widen(fov, k) return math.deg(2 * math.atan(math.tan(math.rad(fov / 2)) * k)) end
	Kit.widenFov = widen
	Kit.Model3DCap = { PC = 24, Phone = 12 }
	-- the most parts drawn at once in live viewports; past it the least-seen cells (a card scrolled mostly away) show
	-- their drawn picture
	Kit.Model3DParts = { PC = 6000, Phone = 1500 }
	Kit.Model3DBuilds = 3 -- models built a frame at most (the rest wait a frame)
	Kit.Model3DKeep = 40 -- built models kept for cells that aren't showing
	Kit.Model3DCheck = 0.15 -- seconds between on-screen checks (and at once when a list scrolls)
	Kit.Model3DShow = 12 -- px: a cell shows its live viewport once it is this close to the screen (a cell nearer than
	-- one cell's size is built, ready, but not drawn)
	local PREFIX = { shoe = 'Shoe_', gun = 'Gun_', box = 'Box_' }
	Kit.Model3DPrefix = PREFIX

	-- The unit direction from an item toward the camera for `kind`'s studio (or a preset table).
	function Kit.studioView(kind, pitch)
		local s = type(kind) == 'table' and kind or Kit.Studio[kind] or Kit.Studio.shoe
		local yaw = math.rad(s.Yaw)
		pitch = math.rad(pitch or s.Pitch)
		local flat = (s.Side.Unit * math.cos(yaw) + s.Toward.Unit * math.sin(yaw)).Unit
		return (flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)).Unit
	end

	local modules = {}
	local function models(name)
		if modules[name] == nil then
			modules[name] = false
			local folder = script.Parent:FindFirstChild('Models')
			local m = folder and folder:FindFirstChild(name)
			if m then
				local ok, result = pcall(require, m)
				if ok and type(result) == 'table' then modules[name] = result end
			end
		end
		return modules[name] or nil
	end
	local STRIP = { 'ParticleEmitter', 'Light', 'Beam', 'Trail', 'Sound', 'LuaSourceContainer', 'Fire', 'Smoke', 'Sparkles', 'Attachment' }
	-- The item's display model: the real game model, still and stripped for a viewport (no effects, no invisible fit boxes).
	-- Returns the Model and its part count, or nil and why.
	Kit.LodMin = 0.25 -- (a phone's small cell: parts whose largest side is under this many studs are left out)
	function Kit.build3d(kind, id, lod)
		local ok, model = pcall(function()
			if kind == 'shoe' then return models('ShoeModels').pair(id, 1) end
			if kind == 'gun' then return models('GunModels').build(id, 1) end
			if kind == 'box' then return models('BoxModels').build(id, 1) end
			error('unknown kind ' .. tostring(kind))
		end)
		if not ok or typeof(model) ~= 'Instance' then return nil, tostring(model) end
		local parts, full = 0, 0
		for _, d in model:GetDescendants() do
			if d.Parent == nil then continue end
			local strip = false
			for _, cls in STRIP do
				if d:IsA(cls) then strip = true; break end
			end
			if strip then
				d:Destroy()
			elseif d:IsA('BasePart') then
				if d.Transparency >= 0.99 then
					if model.PrimaryPart == d then pcall(function() model.PrimaryPart = nil end) end
					d:Destroy()
				else
					full += 1
					local sz = d.Size
					if lod and math.max(sz.X, sz.Y, sz.Z) < Kit.LodMin then
						d:Destroy()
					else
						d.Anchored = true
						d.CastShadow = false
						parts += 1
					end
				end
			end
		end
		model:SetAttribute('Parts', parts)
		return model, parts, full
	end

	-- The corners of a model's visible parts.
	local function corners(model, keep)
		local pts = {}
		local list = model:IsA('BasePart') and { model } or model:GetDescendants()
		for _, d in list do
			if d:IsA('BasePart') and d.Transparency < 0.99 and (not keep or keep(d)) then
				local cf, h = d.CFrame, d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do table.insert(pts, cf:PointToWorldSpace(V3(sx * h.X, sy * h.Y, sz * h.Z))) end
					end
				end
			end
		end
		return pts
	end
	Kit.corners3d = corners
	-- The basis of a view along `back` (model -> camera): right, up.
	local function basis(back)
		local up = (Vector3.yAxis - back * back:Dot(Vector3.yAxis)).Unit
		return up:Cross(back), up
	end
	-- The camera distance at which every point (seen from `focus` along `back`) lies within `fill` of the frame.
	local function distanceFor(pts, focus, back, right, up, tanH, tanV, fill, yWeight)
		local d = 0
		local yw = yWeight or 1
		for _, p in pts do
			local v = p - focus
			d = math.max(d, v:Dot(back) + math.max(math.abs(v:Dot(right)) / (fill * tanH), yw * math.abs(v:Dot(up)) / (fill * tanV)))
		end
		return d
	end
	-- Frames the visible parts seen along `back` (unit, model -> camera) with vertical `fov` (degrees) in a cell `aspect`
	-- (w / h) wide: the camera backs off until the silhouette fills `fill` of the cell along its longer side, and the
	-- silhouette is centred. Returns the camera CFrame, its distance, the focus and the fill reached ({ x, y } half-extents
	-- of the silhouette in the frame, 0..1).
	function Kit.frame3d(model, back, fov, aspect, fill, pts, opts)
		opts = opts or {}
		back = back.Unit
		local all = pts or corners(model)
		pts = opts.Body and corners(model, opts.Body) or all
		if #pts == 0 then pts = all end
		local right, up = basis(back)
		local tanV = math.tan(math.rad(fov / 2))
		local tanH = tanV * (aspect or 1)
		fill = fill or 0.8
		if #pts == 0 then
			local cf = model:GetPivot()
			return CFrame.lookAt(cf.Position + back * 10, cf.Position), 10, cf.Position, { 0, 0 }
		end
		local lo, hi = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
		for _, p in pts do lo, hi = lo:Min(p), hi:Max(p) end
		local focus = (lo + hi) / 2
		local d, reach = 0, { 0, 0 }
		local yw = opts.YWeight
		for _ = 1, 4 do
			d = distanceFor(pts, focus, back, right, up, tanH, tanV, fill, yw)
			-- the silhouette's box in the frame at that distance, and the shift that centres it
			local x0, x1, y0, y1, depthSum = math.huge, -math.huge, math.huge, -math.huge, 0
			for _, p in pts do
				local v = p - focus
				local depth = math.max(1e-3, d - v:Dot(back))
				local nx, ny = v:Dot(right) / (depth * tanH), v:Dot(up) / (depth * tanV)
				x0, x1, y0, y1 = math.min(x0, nx), math.max(x1, nx), math.min(y0, ny), math.max(y1, ny)
				depthSum += depth
			end
			local depth = depthSum / #pts
			reach = { (x1 - x0) / 2, (y1 - y0) / 2 }
			focus += right * ((x0 + x1) / 2) * depth * tanH + up * ((y0 + y1) / 2) * depth * tanV
		end
		d = distanceFor(pts, focus, back, right, up, tanH, tanV, fill, yw)
		-- (Drop: a decoration rising past MaxReach first sets the body lower in the cell, up to Drop of its half-height, as
		-- far as the decoration needs and the bottom allows)
		if opts.MaxReach and opts.Drop and all ~= pts then
			local dropped = 0
			for _ = 1, 3 do
				local top, bottom, topDepth = -math.huge, math.huge, d
				for _, p in all do
					local v = p - focus
					local depth = math.max(1e-3, d - v:Dot(back))
					local ny = v:Dot(up) / (depth * tanV)
					if ny > top then top, topDepth = ny, depth end
					bottom = math.min(bottom, ny)
				end
				local shift = math.min(top - opts.MaxReach, opts.MaxReach + bottom)
				shift = math.min(shift, opts.Drop - dropped)
				if shift <= 1e-4 then break end
				dropped += shift
				focus += up * (shift * topDepth * tanV)
			end
		end
		-- the whole model (decorations too) stays inside MaxReach of the cell: nothing is clipped
		if opts.MaxReach and all ~= pts then
			local need = distanceFor(all, focus, back, right, up, tanH, tanV, opts.MaxReach)
			if need > d then
				-- (pushed back for a big decoration: the body's fill actually reached at that distance)
				d = need
				local rx, ry = 0, 0
				for _, p in pts do
					local v = p - focus
					local depth = math.max(1e-3, d - v:Dot(back))
					rx, ry = math.max(rx, math.abs(v:Dot(right)) / (depth * tanH)), math.max(ry, math.abs(v:Dot(up)) / (depth * tanV))
				end
				reach = { rx, ry }
			end
		end
		return CFrame.lookAt(focus + back * d, focus), d, focus, reach
	end
	-- frame3d's options for a studio (and a cell's own MaxReach, e.g. the Store's hero box)
	function Kit.studioFrame(studio, maxReach, cell)
		cell = cell or {}
		if cell.Whole then return { YWeight = cell.YWeight or studio.YWeight } end -- (framed on the whole model: nothing spills)
		return { Body = studio.Body, YWeight = cell.YWeight or studio.YWeight, MaxReach = maxReach or studio.MaxReach, Drop = studio.Drop }
	end

	---------------------------------------------------------------- the shared driver
	local registry = InstanceMap.new() -- holder -> entry
	local order, driverConn = 0, nil
	local acc, dirty, clock = 0, true, 0
	local stats = { Live = 0, Built = 0, Cap = Kit.Model3DCap.PC, Parts = 0 }
	local scrolls = InstanceMap.new() -- ScrollingFrame -> its CanvasPosition connection
	-- (a list that scrolls re-checks at once, so a cell coming into view shows on that frame, not up to 0.15 s later)
	local function watchScroll(h)
		local a = h.Parent
		while a and not a:IsA('LayerCollector') do
			if a:IsA('ScrollingFrame') and not scrolls[a] then
				local ok, conn = pcall(function() return a:GetPropertyChangedSignal('CanvasPosition'):Connect(function() dirty = true end) end)
				scrolls[a] = ok and conn or true
			end
			a = a.Parent
		end
	end
	-- A phone (its screen's short side <= 500, Kit.scaleFor's rule): the camera's view, else the ScreenGui's size.
	local function phone(gui)
		local ok, vs = pcall(function() return workspace.CurrentCamera.ViewportSize end)
		if not (ok and typeof(vs) == 'Vector2' and vs.X > 1) then
			if not gui then
				-- (nothing on screen yet: the player's screen, from any of their ScreenGuis)
				pcall(function() gui = game:GetService('Players').LocalPlayer:FindFirstChildOfClass('PlayerGui'):FindFirstChildWhichIsA('ScreenGui') end)
			end
			local okG, gs = pcall(function() return gui.AbsoluteSize end)
			vs = okG and typeof(gs) == 'Vector2' and gs or Vector2.new(1280, 720)
		end
		return vs.X > 1 and math.min(vs.X, vs.Y) <= 500
	end
	function Kit.model3dCap(gui) return phone(gui) and Kit.Model3DCap.Phone or Kit.Model3DCap.PC end
	-- Drawn now: the gui and its ancestors visible, in an enabled ScreenGui (or any LayerCollector): that collector.
	local function shown(gui)
		local x = gui
		while x do
			if x:IsA('LayerCollector') then return x.Enabled and x.Parent ~= nil and x end
			if x:IsA('GuiObject') and not x.Visible then return false end
			x = x.Parent
		end
		return false
	end
	-- Inside (or within `margin` px of) every clipping ancestor's box: a ScrollingFrame or a ClipsDescendants frame.
	-- True where the sizes can't be read (zero: an offline harness).
	-- (a test may replace Kit.AbsBox to put cells on and off screen)
	function Kit.AbsBox(g)
		local ok, p, s = pcall(function() return g.AbsolutePosition, g.AbsoluteSize end)
		if ok and typeof(s) == 'Vector2' and s.X > 0 and s.Y > 0 then return p, s end
		return nil
	end
	local function box(g) return Kit.AbsBox(g) end
	local function near(gui, margin)
		local p, s = box(gui)
		if not p then return true end
		local x0, y0, x1, y1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
		local a = gui.Parent
		while a and not a:IsA('LayerCollector') do
			if a:IsA('GuiObject') and (a.ClipsDescendants or a:IsA('ScrollingFrame')) then
				local ap, as = box(a)
				if ap and (x1 < ap.X - margin or x0 > ap.X + as.X + margin or y1 < ap.Y - margin or y0 > ap.Y + as.Y + margin) then return false end
			end
			a = a.Parent
		end
		return true
	end
	-- The share of the gui's area on screen, inside every clipping ancestor (1 where sizes can't be read).
	local function seenShare(gui)
		local p, s = box(gui)
		if not p or s.X * s.Y <= 0 then return 1 end
		local x0, y0, x1, y1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
		local a = gui.Parent
		while a and not a:IsA('LayerCollector') do
			if a:IsA('GuiObject') and (a.ClipsDescendants or a:IsA('ScrollingFrame')) then
				local ap, as = box(a)
				if ap then
					x0, y0 = math.max(x0, ap.X), math.max(y0, ap.Y)
					x1, y1 = math.min(x1, ap.X + as.X), math.min(y1, ap.Y + as.Y)
				end
			end
			a = a.Parent
		end
		return math.max(0, x1 - x0) * math.max(0, y1 - y0) / (s.X * s.Y)
	end
	local function showFlat(h, e, on)
		if e.Row then
			if on and not e.Flat then
				e.Flat = blank({ Name = 'Flat2D', Size = UDim2.fromScale(1, 1), ZIndex = e.Z + 1, Parent = h })
				for i, it in e.Items do
					local f = Kit.icon3d(PREFIX[e.Kind] .. it.Id, e.Cell, { ZIndex = e.Z + 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(Kit.model3dRowX(i, e.Cell, e.Pitch), e.H / 2), Locked = it.Locked })
					if it.Locked then f:SetAttribute('PreviewSilhouette', true) end
					f.Parent = e.Flat
				end
			end
			if e.Flat then e.Flat.Visible = on end
			return
		end
		if on and not e.Flat then
			e.Flat = Kit.icon3d(PREFIX[e.Kind] .. e.Id, math.min(e.W, e.H), { ZIndex = e.Z + 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Locked = e.Locked })
			e.Flat.Name = 'Flat2D'
			if e.Locked then e.Flat:SetAttribute('PreviewSilhouette', true) end
			e.Flat.Parent = h
		end
		if e.Flat then e.Flat.Visible = on end
	end
	local function aim(e, angle, bob)
		local s = e.Studio
		local back, focus, d = e.Back, e.Focus, e.Dist
		if e.Act > 0 then
			local k = e.Act * e.Act * (3 - 2 * e.Act) -- (smoothstep: eases into and out of the spin)
			back = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(e.Back)
			focus = e.Focus:Lerp(e.Pivot, k) + Vector3.yAxis * (bob * e.FrameH * k)
			d = e.Dist + (e.SpinDist - e.Dist) * k
		end
		local cf = CFrame.lookAt(focus + back * d, focus)
		e.Camera.CFrame = cf
		e.Viewport.LightDirection = cf:VectorToWorldSpace(s.Key.Unit)
	end
	-- The spin's distance: the farthest of the needed ones over a full turn round the item's own upright axis.
	local function spinFrame(e)
		if e.SpinDist then return end
		local pts = corners(e.Model)
		local lo, hi = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
		for _, p in pts do lo, hi = lo:Min(p), hi:Max(p) end
		local c = (lo + hi) / 2
		e.Pivot = V3(c.X, e.Focus.Y, c.Z)
		local tanV = math.tan(math.rad(e.Fov / 2))
		local tanH = tanV * (e.W / e.H)
		local fill = (e.MaxReach or e.Studio.MaxReach or 0.97) / (1 + 2 * e.Studio.Bob) -- (the whole model, with room for the bob)
		local d = e.Dist
		for i = 0, 15 do
			local back = CFrame.Angles(0, i * math.pi / 8, 0):VectorToWorldSpace(e.Back)
			local right, up = basis(back)
			d = math.max(d, distanceFor(pts, e.Pivot, back, right, up, tanH, tanV, fill))
		end
		e.SpinDist = d
	end
	local buildRow -- (below)
	local function build(e)
		if e.Row then return buildRow(e) end
		local model, parts, full = Kit.build3d(e.Kind, e.Id, e.Lod)
		e.PartsFull = full
		if not model then
			e.Failed = true
			warn('[UIKit] model3d ' .. e.Kind .. ' ' .. tostring(e.Id) .. ': ' .. tostring(parts))
			return
		end
		e.Model, e.Parts = model, parts
		e.Back = Kit.studioView(e.Studio, e.CamPitch)
		local cf, d, focus = Kit.frame3d(model, e.Back, e.Fov, e.W / e.H, e.Fill, nil, Kit.studioFrame(e.Studio, e.MaxReach, e))
		e.Dist, e.Focus = d, focus
		e.FrameH = 2 * d * math.tan(math.rad(e.Fov / 2))
		e.Camera.CFrame = cf
		e.Viewport.LightDirection = cf:VectorToWorldSpace(e.Studio.Key.Unit)
		model.Parent = e.Viewport
		stats.Built += 1
	end
	local function free(e)
		if e.Row and e.Model then
			for _, it in e.Items do
				if it.Model then it.Model:Destroy(); it.Model = nil end
			end
		end
		if e.Model then
			if not e.Row then e.Model:Destroy() end
			e.Model, e.SpinDist = nil, nil
			stats.Built -= 1
		end
	end
	local function setLive(e, on)
		e.Live = on
		e.Viewport.Visible = on and e.Model ~= nil
		if on then e.Seen = clock end
	end
	local function pass()
		local want, screen = {}, nil
		for h, e in registry do
			local lc = h.Parent ~= nil and shown(h)
			screen = screen or lc or nil
			if not lc then
				-- (a closed window, a cached cell put aside: draws nothing anyway; its viewport stays as it was, so a window
				-- that opens again shows its items at once)
				e.Want, e.Live = false, false
			else
				-- (near: within a cell of the clip, so a scrolled-in item is built and ready; inside: on screen now, the only
				-- ones drawn, served first)
				e.Want = near(h, e.Row and e.H or math.max(e.W, e.H))
				e.Inside = e.Want and near(h, Kit.Model3DShow)
				e.Share = e.Inside and math.floor(seenShare(h) * 10 + 0.5) / 10 or 0 -- (to a tenth: a steady order)
				if not e.Watched then e.Watched = true; watchScroll(h) end
				if e.Want then table.insert(want, h) else setLive(e, false); showFlat(h, e, false) end
			end
		end
		local cap = Kit.model3dCap(screen)
		stats.Cap = cap
		-- (a phone's small cells, under ~80 px on screen, build without their tiny trim)
		local small = cap == Kit.Model3DCap.Phone
		local scale = 1
		if small and screen then
			local okS, gs = pcall(function() return screen.AbsoluteSize end)
			if okS and typeof(gs) == 'Vector2' and gs.X > 1 then scale = Kit.scaleFor(gs) end
		end
		table.sort(want, function(ha, hb)
			local a, b = registry[ha], registry[hb]
			if (a.Act > 0 or next(a.Reasons) ~= nil) ~= (b.Act > 0 or next(b.Reasons) ~= nil) then return a.Act > 0 or next(a.Reasons) ~= nil end
			if a.Inside ~= b.Inside then return a.Inside end
			if a.Share ~= b.Share then return a.Share > b.Share end -- (the most-seen first: a sliver of a card comes last)
			if a.Priority ~= b.Priority then return a.Priority > b.Priority end
			return a.Order < b.Order
		end)
		local builds, live, parts, partsFull, shown = 0, 0, 0, 0, 0
		local budget, over = small and Kit.Model3DParts.Phone or Kit.Model3DParts.PC, 0
		for _, h in want do
			local e = registry[h]
			if e.Inside then shown += 1 end
			if e.Failed or (e.Inside and shown > cap) then
				setLive(e, false)
				showFlat(h, e, true)
			else
				if not e.Model and builds < Kit.Model3DBuilds then
					local _, sz = box(h)
					local px = sz and math.min(sz.Y, e.Row and sz.Y or sz.X) or math.min(e.Row and e.Cell or e.W, e.H) * scale
					e.Lod = small and px < 80 and e.Kind ~= 'gun' -- (guns are few parts already)
					build(e)
					builds += 1
				end
				if e.Failed then
					showFlat(h, e, true)
				elseif e.Model and not e.Inside then
					setLive(e, false) -- (built and ready just off screen: not drawn)
					showFlat(h, e, false)
					e.Seen = clock
				elseif live > 0 and parts + (e.Parts or 0) > budget then
					setLive(e, false) -- (over the parts budget: its drawn picture)
					showFlat(h, e, true)
					over += 1
				elseif e.Model then
					setLive(e, true)
					showFlat(h, e, false)
					live += 1
					parts += e.Parts or 0
					partsFull += e.PartsFull or e.Parts or 0
				else
					dirty = true -- (its turn to build comes next frame)
				end
			end
			-- (brief 29, the user: "the shoe pictures in the inventory are gone") a cell that is on screen but still has no live
			-- model after 2 s (a build that never came, a viewport that did not show) draws its flat picture instead of an
			-- empty splat
			if e.Inside and not e.Live then
				e.Waiting = e.Waiting or clock
				if clock - e.Waiting > 2 then
					showFlat(h, e, true)
					if not e.Warned then
						e.Warned = true
						warn('[UIKit] model3d ' .. tostring(e.Kind) .. ' ' .. tostring(e.Id) .. ' is on screen but not live after 2 s (model built: ' .. tostring(e.Model ~= nil) .. ', failed: ' .. tostring(e.Failed == true) .. ', cap ' .. tostring(stats.Cap) .. '): showing its flat picture')
					end
				end
			else
				e.Waiting = nil
			end
		end
		stats.Live, stats.Parts, stats.PartsFull, stats.Over, stats.Budget = live, parts, partsFull, over, budget
		-- free the models longest unseen past the keep
		if stats.Built > Kit.Model3DKeep then
			local idle = {}
			for _, e in registry do
				if e.Model and not e.Live and not e.Want then table.insert(idle, e) end -- (never one just off screen: next to show)
			end
			table.sort(idle, function(a, b) return (a.Seen or 0) < (b.Seen or 0) end)
			for i = 1, math.min(#idle, stats.Built - Kit.Model3DKeep) do free(idle[i]) end
		end
	end
	local failedPasses = 0
	local moving = InstanceMap.new() -- holder -> true while it spins or eases back
	local function step(dt)
		dt = math.min(tonumber(dt) or 0, 0.1)
		clock += dt
		acc += dt
		if dirty or acc >= Kit.Model3DCheck then
			dirty, acc = false, 0
			local ok, err = pcall(pass)
			if not ok then
				warn('[UIKit] model3d: ' .. tostring(err))
				-- (brief 29) a pass that keeps failing leaves every cell as it was, empty: after the second failure in a row they
				-- all fall back to their flat pictures (and stay there)
				failedPasses += 1
				if failedPasses >= 2 then
					for h, e in registry do
						e.Failed = true
						pcall(showFlat, h, e, true)
					end
				end
			else
				failedPasses = 0
			end
		end
		for h in moving do
			local e = registry[h]
			local on = e and next(e.Reasons) ~= nil
			if e and e.Row then
				local any = false
				for _, it in e.Items do
					local want = next(it.Reasons) ~= nil
					if it.Model and e.Live and (want or it.Act > 0) then
						it.Act = math.clamp(it.Act + (want and dt or -dt) / 0.35, 0, 1)
						if want then
							it.Angle = (it.Angle + e.Studio.Spin * dt) % 360
						else
							local a = it.Angle > 180 and it.Angle - 360 or it.Angle
							it.Angle = (a * math.exp(-6 * dt)) % 360
						end
						it.T += dt
						local k = it.Act * it.Act * (3 - 2 * it.Act)
						local bob = e.Studio.Bob * math.sin(it.T * 2 * math.pi * e.Studio.BobHz) * e.CellStuds * k
						if it.Act == 0 and not want then it.Angle, it.T, bob = 0, 0, 0 end
						pcall(function() it.Model:PivotTo(CFrame.new(it.Centre + Vector3.yAxis * bob) * CFrame.Angles(0, math.rad(it.Angle), 0)) end)
					end
					any = any or want or it.Act > 0
				end
				if not any then moving[h] = nil end
			elseif not e then
				moving[h] = nil
			elseif e.Model and e.Live then
				if on and not e.SpinDist then pcall(spinFrame, e) end
				on = on and e.SpinDist ~= nil
				e.Act = math.clamp(e.Act + (on and dt or -dt) / 0.35, 0, 1)
				if on then
					e.Angle = (e.Angle + e.Studio.Spin * dt) % 360
				else
					-- back to the show side the short way round
					local a = e.Angle > 180 and e.Angle - 360 or e.Angle
					e.Angle = (a * math.exp(-6 * dt)) % 360
				end
				e.T += dt
				local ok = pcall(aim, e, e.Angle, e.Studio.Bob * math.sin(e.T * 2 * math.pi * e.Studio.BobHz))
				if not ok then e.Act = 0 end
				if e.Act == 0 and not on then
					e.Angle, e.T = 0, 0
					pcall(aim, e, 0, 0)
					moving[h] = nil
				end
			elseif not on then
				moving[h] = nil
			end
		end
		if next(registry) == nil and driverConn then
			driverConn:Disconnect()
			driverConn = nil
		end
	end
	Kit.model3dStep = step -- (an offline harness can step it)
	local function ensureDriver()
		if driverConn then return end
		-- (PreRender on a client; where it can't be used, the next one that can: tests step Kit.model3dStep themselves)
		local RunService = game:GetService('RunService')
		for _, name in { 'PreRender', 'RenderStepped', 'Heartbeat' } do
			local ok, conn = pcall(function() return RunService[name]:Connect(step) end)
			if ok and conn then
				driverConn = conn
				return
			end
		end
	end
	function Kit.model3dStats()
		local n = 0
		for _ in registry do n += 1 end
		return { Registered = n, Live = stats.Live, Built = stats.Built, Cap = stats.Cap, Driver = driverConn ~= nil, Parts = stats.Parts, PartsFull = stats.PartsFull or stats.Parts, Over = stats.Over or 0, Budget = stats.Budget }
	end

	---------------------------------------------------------------- the cell
	-- ShoeFX's ladder (lazily: its glow strength, rays and rainbow for the backdrop)
	local shoeFX
	local function tierOf(rarity)
		if rarity == nil then return nil end
		if shoeFX == nil then
			shoeFX = false
			local m = script.Parent:FindFirstChild('ShoeFX')
			if m then
				local ok, r = pcall(require, m)
				if ok and type(r) == 'table' then shoeFX = r end
			end
		end
		return shoeFX and shoeFX.tier(rarity) or nil
	end
	-- The rarity hint behind a shoe: a soft glow (3 rings) from Epic, rays from Legendary, rainbow for Secret.
	local function rarityGlow(holder, tier, w, h, z)
		if not tier or tier.Glow < 0.3 then return end
		local rainbow = tier.Rainbow and shoeFX and shoeFX.Rainbow or nil
		local glow = blank({ Name = 'RarityGlow', Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
		local s = math.min(w, h)
		if tier.Rays > 8 then
			local rays = blank({ Name = 'Rays', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = glow })
			local n = math.min(8, math.floor(tier.Rays / 2))
			for i = 1, n do
				local c = rainbow and rainbow[(i - 1) % #rainbow + 1] or tier.Accent
				local ray = blank({ BackgroundTransparency = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, math.max(3, s * 0.07), 1.05, 0), Rotation = (i - 1) * 180 / n, ZIndex = z, Parent = rays })
				new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = ray })
			end
		end
		for i, k in { 0.92, 0.7, 0.48 } do
			local c = rainbow and rainbow[i * 2 - 1] or tier.Color:Lerp(Kit.Color.white, (i - 1) * 0.25)
			local ring = blank({ Name = 'Glow' .. i, BackgroundTransparency = 1 - tier.Glow * (0.16 + 0.1 * i), BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(s * k, s * k * 0.86), ZIndex = z, Parent = glow })
			corner(UDim.new(0.5, 0)).Parent = ring
		end
	end
	function Kit.model3d(kind, id, size, opts)
		opts = opts or {}
		local studio = Kit.Studio[kind] or Kit.Studio.shoe
		local w, h = size, size
		if typeof(size) == 'Vector2' then w, h = size.X, size.Y end
		local z = opts.ZIndex or 1
		local holder = blank({ Name = opts.Name or ('Model3D_' .. tostring(kind) .. '_' .. tostring(id)), Size = UDim2.fromOffset(w, h), Position = opts.Position or UDim2.new(), AnchorPoint = opts.AnchorPoint or Vector2.zero, LayoutOrder = opts.LayoutOrder or 0, ZIndex = z })
		holder:SetAttribute('Model3D', tostring(kind))
		holder:SetAttribute('ItemId', tostring(id))
		if kind == 'shoe' and opts.Rarity ~= nil and not opts.Locked then
			rarityGlow(holder, tierOf(opts.Rarity), w, h, z)
		end
		if not PREFIX[kind] then
			local flat = Kit.icon3d(tostring(id), math.min(w, h), { ZIndex = z + 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			flat.Name = 'Flat2D'
			flat.Parent = holder
			return holder
		end
		local over = opts.Overflow or studio.Overflow or Kit.Model3DOverflow
		local vp = new('ViewportFrame', {
			Name = 'Viewport', BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(over, over), ZIndex = z + 1,
			Ambient = studio.Ambient, LightColor = studio.Light, LightDirection = V3(0, -1, 0), Visible = false, Parent = holder,
		})
		vp:SetAttribute('PreviewImage', 'm3d:' .. (opts.PreviewKind or kind) .. ':' .. tostring(id)) -- (the offline shot tools draw its studio render)
		if opts.Locked then
			-- (a thing you don't own yet: the same model, black; its stand-in is the drawn PNG's silhouette)
			vp.ImageColor3 = Color3.new(0, 0, 0)
			vp:SetAttribute('PreviewSilhouette', true)
		end
		local fov = opts.Fov or studio.Fov
		local cam = new('Camera', { Name = 'Camera', FieldOfView = widen(fov, over), Parent = vp })
		vp.CurrentCamera = cam
		order += 1
		local e = { Viewport = vp, Camera = cam, Kind = kind, Id = id, Studio = studio, W = w, H = h, Z = z, Fill = opts.Fill or studio.Fill,
			Priority = opts.Priority or 0, Order = order, Locked = opts.Locked == true, MaxReach = opts.MaxReach, Over = over, Whole = opts.Whole == true, YWeight = opts.YWeight, CamPitch = opts.Pitch, Fov = fov, Act = 0, Angle = 0, T = 0, Reasons = {}, Live = false, Want = false }
		registry[holder] = e
		pcall(function()
			holder.Destroying:Connect(function()
				if registry[holder] then
					registry[holder] = nil
					free(e)
				end
			end)
		end)
		dirty = true
		ensureDriver()
		return holder
	end
	-- The spin while any reason is on ('hover', 'select', ...); it eases back to the show side when the last one goes.
	function Kit.model3dActive(holder, reason, on)
		local e = holder and registry[holder]
		if not e then return end
		e.Reasons[reason or 'select'] = on and true or nil
		if on then moving[holder] = true end
		dirty = true
		ensureDriver()
	end
	function Kit.model3dHover(holder, button)
		if not (holder and button) then return end
		pcall(function()
			button.MouseEnter:Connect(function() Kit.model3dActive(holder, 'hover', true) end)
			button.MouseLeave:Connect(function() Kit.model3dActive(holder, 'hover', false) end)
			button.SelectionGained:Connect(function() Kit.model3dActive(holder, 'hover', true) end)
			button.SelectionLost:Connect(function() Kit.model3dActive(holder, 'hover', false) end)
		end)
	end
	---------------------------------------------------------------- rows: one viewport for a row of items
	-- A row of items (an odds row, a grid row) shares ONE ViewportFrame: every item is placed in it so it looks exactly as
	-- in its own cell (turned to face the camera along its own ray, so each is seen from the studio's angle, and scaled so
	-- its silhouette fills the same share of its square cell). The row camera is nearly orthographic (Kit.RowFov), so the
	-- items at the ends aren't stretched. A pointed-at item turns on its own (Model:PivotTo: only that model moves).
	Kit.RowFov = 3 -- (a long row is ~7 cells wide: its ends are ~10 degrees off the axis, so items there stay true)
	local TYPICAL = { shoe = 2.6, gun = 3, box = 5 } -- (studs: the row's cell is about the item's size, so the scale is ~1)
	-- The x of item i's cell centre in a row (cell px square, pitch px apart).
	function Kit.model3dRowX(i, cell, pitch) return cell / 2 + (i - 1) * pitch end
	buildRow = function(e)
		local studio = e.Studio
		local back = Kit.studioView(studio)
		local tanV = math.tan(math.rad(Kit.RowFov / 2))
		local hs = (TYPICAL[e.Kind] or 3) / e.Fill -- (the cell's height in studs at the focal plane)
		local d = hs / (2 * tanV)
		local camPos = back * d
		local cf = CFrame.lookAt(camPos, Vector3.zero)
		local right = cf.RightVector
		e.CellStuds = hs
		e.Camera.FieldOfView = widen(Kit.RowFov, e.VH / e.H) -- (the viewport is taller than the row: the row's cells keep Kit.RowFov)
		e.Camera.CFrame = cf
		e.Viewport.LightDirection = cf:VectorToWorldSpace(studio.Key.Unit)
		local parts, built = 0, 0
		for i, it in e.Items do
			local model, n, full = Kit.build3d(e.Kind, it.Id, e.Lod)
			if model then
				e.PartsFull = (e.PartsFull or 0) + full
				local P = right * ((Kit.model3dRowX(i, e.Cell, e.Pitch) - e.W / 2) * hs / e.H)
				local backI = (camPos - P).Unit
				local pts = corners(model)
				local lo, hi = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
				for _, p in pts do lo, hi = lo:Min(p), hi:Max(p) end
				local c = (lo + hi) / 2
				-- turned to face the camera along its own ray (the studio's view for every item)
				local axis = back:Cross(backI)
				local q = CFrame.identity
				if axis.Magnitude > 1e-6 then q = CFrame.fromAxisAngle(axis.Unit, math.asin(math.clamp(axis.Magnitude, -1, 1))) end
				local turn = CFrame.new(c) * q * CFrame.new(-c)
				-- its BODY's silhouette seen along that ray (centre and size); the whole model stays inside the cell
				local r, u = basis(backI)
				local function extents(list)
					local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
					for _, p in list do
						local v = turn:PointToWorldSpace(p) - c
						x0, x1, y0, y1 = math.min(x0, v:Dot(r)), math.max(x1, v:Dot(r)), math.min(y0, v:Dot(u)), math.max(y1, v:Dot(u))
					end
					return x0, x1, y0, y1
				end
				local bodyPts = studio.Body and corners(model, studio.Body) or pts
				if #bodyPts == 0 then bodyPts = pts end
				local x0, x1, y0, y1 = extents(bodyPts)
				local sc = c + r * ((x0 + x1) / 2) + u * ((y0 + y1) / 2)
				-- (cos: an item off the axis is seen a little wider on the flat picture; this keeps every item the same size)
				local cos = backI:Dot(back)
				local yw = studio.YWeight or 1
				local k = e.Fill * hs / math.max(1e-3, (x1 - x0) / cos, yw * (y1 - y0))
				local ax0, ax1, ay0, ay1 = extents(pts)
				local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
				local reachX = math.max(mx - ax0, ax1 - mx) * 2 / cos
				local reachY = math.max(my - ay0, ay1 - my) * 2
				local room = (studio.MaxReach or 0.97) * hs
				-- (sideways a decoration may use the gap to the next cell: the viewport runs a margin past the row's ends)
				local roomX = room * math.max(1, e.Pitch / e.Cell)
				k = math.min(k, roomX / math.max(1e-3, reachX), room / math.max(1e-3, reachY))
				for _, part in model:GetDescendants() do
					if part:IsA('BasePart') then
						local pcf = turn * part.CFrame
						part.Size *= k
						part.CFrame = CFrame.new(P + (pcf.Position - sc) * k) * pcf.Rotation
						if it.Locked then
							-- (a thing you don't own yet: a black silhouette of it)
							part.Color = Color3.new(0, 0, 0)
							part.Material = Enum.Material.SmoothPlastic
							part.Reflectance = 0
						end
					elseif part:IsA('SpecialMesh') then
						part.Offset *= k
						if part.MeshType == Enum.MeshType.FileMesh then part.Scale *= k end
					elseif it.Locked and (part:IsA('Decal') or part:IsA('SurfaceGui')) then
						part:Destroy()
					end
				end
				pcall(function() model.WorldPivot = CFrame.new(P) end)
				it.Model, it.Centre, it.Parts = model, P, n
				model.Parent = e.Viewport
				parts += n
				built += 1
				if it.Dim then Kit.model3dItemDim(e.Holder, i, true) end
			end
		end
		if built == 0 then
			e.Failed = true
			return
		end
		e.Model, e.Parts = true, parts
		stats.Built += 1
	end
	-- A row of items in one viewport: list = { { Id, Locked?, Rarity?, Dim? }, ... }, each in a `cell` px square, `pitch`
	-- px apart (the row is pitch x (n - 1) + cell wide). opts: Name, Position, AnchorPoint, ZIndex, LayoutOrder, Fill,
	-- Priority, Glow (false: no rarity glows). Returns the holder; Kit.model3dRowX(i, cell, pitch) is item i's centre.
	function Kit.model3dRow(kind, list, cell, pitch, opts)
		opts = opts or {}
		local studio = Kit.Studio[kind] or Kit.Studio.shoe
		local n = #list
		local w, h = math.floor(pitch * math.max(0, n - 1) + cell + 0.5), cell
		local z = opts.ZIndex or 1
		local holder = blank({ Name = opts.Name or ('Model3DRow_' .. tostring(kind)), Size = UDim2.fromOffset(w, h), Position = opts.Position or UDim2.new(), AnchorPoint = opts.AnchorPoint or Vector2.zero, LayoutOrder = opts.LayoutOrder or 0, ZIndex = z })
		holder:SetAttribute('Model3D', tostring(kind))
		-- (the viewport runs a margin past the row's ends, so the end items' decorations aren't cut)
		local margin = math.ceil(math.max(cell, pitch) * (studio.MaxReach or 0.97) / 2 - cell / 2) + 2
		local over = studio.Overflow or Kit.Model3DOverflow
		local vy = math.floor(cell * (over - 1) / 2 + 0.5) -- (and over and under it, like a single cell's)
		local vp = new('ViewportFrame', {
			Name = 'Viewport', BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(-margin, -vy), Size = UDim2.new(1, 2 * margin, 1, 2 * vy), ZIndex = z + 1,
			Ambient = studio.Ambient, LightColor = studio.Light, LightDirection = V3(0, -1, 0), Visible = false, Parent = holder,
		})
		local cam = new('Camera', { Name = 'Camera', FieldOfView = Kit.RowFov, Parent = vp })
		vp.CurrentCamera = cam
		local items = {}
		for i, it in list do
			local x = Kit.model3dRowX(i, cell, pitch)
			if kind == 'shoe' and it.Rarity ~= nil and not it.Locked and opts.Glow ~= false then
				local spot = blank({ Name = 'Glow' .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, h / 2), Size = UDim2.fromOffset(cell, cell), ZIndex = z, Parent = holder })
				rarityGlow(spot, tierOf(it.Rarity), cell, cell, z)
			end
			-- (each item's cell, for the offline shot tools: they draw its studio render there)
			local mark = blank({ Name = 'Cell' .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + margin, h / 2 + vy), Size = UDim2.fromOffset(cell * over, cell * over), ZIndex = z + 1, Parent = vp })
			mark:SetAttribute('PreviewM3D', 'm3d:' .. kind .. ':' .. tostring(it.Id))
			if it.Locked then mark:SetAttribute('PreviewSilhouette', true) end
			items[i] = { Id = tostring(it.Id), Locked = it.Locked == true, Dim = it.Dim == true, Act = 0, Angle = 0, T = 0, Reasons = {}, Mark = mark }
		end
		order += 1
		local e = { Row = true, Items = items, Holder = holder, Viewport = vp, Camera = cam, Kind = kind, Studio = studio, W = w, H = h, Cell = cell, Pitch = pitch, Z = z, VH = h + 2 * vy, Fov = studio.Fov,
			Fill = opts.Fill or studio.Fill, Priority = opts.Priority or 0, Order = order, Act = 0, Angle = 0, T = 0, Reasons = {}, Live = false, Want = false }
		registry[holder] = e
		pcall(function()
			holder.Destroying:Connect(function()
				if registry[holder] then
					registry[holder] = nil
					free(e)
				end
			end)
		end)
		dirty = true
		ensureDriver()
		return holder
	end
	-- Item i of a row turns while any reason is on; hover on a button turns it; dim fades it (a search).
	function Kit.model3dItemActive(holder, i, reason, on)
		local e = holder and registry[holder]
		local it = e and e.Row and e.Items[i]
		if not it then return end
		it.Reasons[reason or 'select'] = on and true or nil
		if on then moving[holder] = true end
		ensureDriver()
	end
	function Kit.model3dItemHover(holder, i, button)
		if not (holder and button) then return end
		pcall(function()
			button.MouseEnter:Connect(function() Kit.model3dItemActive(holder, i, 'hover', true) end)
			button.MouseLeave:Connect(function() Kit.model3dItemActive(holder, i, 'hover', false) end)
			button.SelectionGained:Connect(function() Kit.model3dItemActive(holder, i, 'hover', true) end)
			button.SelectionLost:Connect(function() Kit.model3dItemActive(holder, i, 'hover', false) end)
		end)
	end
	function Kit.model3dItemDim(holder, i, on)
		local e = holder and registry[holder]
		local it = e and e.Row and e.Items[i]
		if not it then return end
		it.Dim = on and true or false
		it.Mark:SetAttribute('PreviewT', on and 0.75 or nil)
		if not it.Model then return end
		for _, part in it.Model:GetDescendants() do
			if part:IsA('BasePart') then
				if part:GetAttribute('BaseT') == nil then part:SetAttribute('BaseT', part.Transparency) end
				local base = part:GetAttribute('BaseT')
				part.Transparency = on and (1 - (1 - base) * 0.25) or base
			end
		end
	end

	function Kit.model3dDim(holder, on)
		for _, d in holder:GetDescendants() do
			if d:IsA('ViewportFrame') then d.ImageTransparency = on and 0.75 or 0 end
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
-- (brief 28) Phones: no text smaller than Kit.PhoneMinText dp on the screen. Kit.textFloor(container, scale) raises each
-- label under container whose TextSize x scale (every UIScale above it, the screen's included) is under that, keeping
-- its own size in the attribute BaseTextSize; with scale nil the raised labels go back to their own size. Labels that
-- are big enough are never touched (so code that sizes a label itself keeps doing so). TextScaled labels and anything
-- under an instance with NoTextFloor = true (rows laid out from their text's width, like Kit.only) are left alone.
Kit.PhoneMinText = 11
function Kit.textFloor(container, scale, min)
	min = min or Kit.PhoneMinText
	for _, d in container:GetDescendants() do
		if (d:IsA('TextLabel') or d:IsA('TextButton')) and not d.TextScaled then
			local skip = false
			local x = d.Parent
			while x and x ~= container do
				if x:GetAttribute('NoTextFloor') then skip = true break end
				x = x.Parent
			end
			local base = d:GetAttribute('BaseTextSize')
			if skip then
				continue
			elseif scale and scale > 0 then
				local want = math.ceil(min / scale - 1e-6)
				if (base or d.TextSize) < want then
					if not base then d:SetAttribute('BaseTextSize', d.TextSize) end
					d.TextSize = want
				end
			elseif base then
				d.TextSize = base
				d:SetAttribute('BaseTextSize', nil)
			end
		end
	end
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

---------------------------------------------------------------------------------------------- studded blocks (brief 17/18)
-- The reference game's look (the user's HUD, Store and Rebirth pictures, measured at their own 2000x1144 size): square
-- blocks with a thick black outline, a fill lit from the top (two colours of one hue), a faint grid of studs (the plates
-- the whole game is built from), a light band just inside the outline and NO drop shadow. Buttons, cards, window headers
-- and bars all use it, so every screen reads as one family. Plain UI shapes only: no textures.

local function toneOf(t)
	if type(t) == 'table' then return t end
	return Kit.Tone[t or 'gold'] or Kit.Tone.gold
end
Kit.toneOf = toneOf

-- A tone's fill as a UIGradient: `seq` (a horizontal multi-stop, e.g. the rainbow pack) or top -> base, at the tone's
-- `rot` (90 = straight down, the default).
function Kit.fillGradient(tone)
	local keys = {}
	if tone.seq then
		for _, k in tone.seq do table.insert(keys, ColorSequenceKeypoint.new(k[1], k[2])) end
	else
		keys = { ColorSequenceKeypoint.new(0, tone.top), ColorSequenceKeypoint.new(1, tone.base) }
	end
	return new('UIGradient', { Rotation = tone.rot or 90, Color = ColorSequence.new(keys) })
end

-- (brief 19) Uploaded UI textures (ICONS' hood/art/ui). hood/tools/upload_assets.py rewrites the quoted id of every line
-- shaped `Kit.<Name> = '<id>' -- hood/art/ui/<file>.png` from the file named in its comment; paste ids by hand the same
-- way. '' = not uploaded: everything still draws, with UI frames instead. Set, Kit.studs draws ONE tiled ImageLabel per
-- block instead of a frame (or two) per stud: the HUD's biggest instance cost after the live icon models.
Kit.StudBevel = 'rbxassetid://139282026688556' -- hood/art/ui/stud_bevel.png
Kit.StudChecker = 'rbxassetid://118305896629632' -- hood/art/ui/stud_checker.png
Kit.StudTile = 'rbxassetid://73170865063856' -- hood/art/ui/stud_tile.png
Kit.GlossBand = 'rbxassetid://138159080318845' -- hood/art/ui/gloss_band.png
Kit.GlossStripes = 'rbxassetid://101972782810941' -- hood/art/ui/gloss_stripes.png
Kit.Splat = 'rbxassetid://102123425905753' -- hood/art/ui/splat.png
Kit.SplatRainbow = 'rbxassetid://138967590529890' -- hood/art/ui/splat_rainbow.png
Kit.SplatBlack = 'rbxassetid://101192232825527' -- hood/art/ui/splat_black.png
--   StudBevel: one stud per tile, pre-shaded (a white highlight and a black shadow in its alpha): drawn white, it gives
--     the reference's light top-left and dark bottom-right edges on any colour. The default stud.
--   StudChecker: 2 x 2 studs, raised and recessed alternating (the reference's level bar, its Rebirth boxes and buttons),
--     pre-shaded the same way; tile = 2 pitches.
--   StudTile: one greyscale stud per tile, tinted with the block's lip colour (used when StudBevel is missing).
--   GlossStripes: one seamless 45-degree light stripe, tiled every ~3 stud pitches: the window headers' repeated bands.
--   GlossBand: two diagonal light bands stretched over the face (used when GlossStripes is missing).
--   Splat / SplatRainbow / SplatBlack (brief 22): the paint splat behind a pet / shoe / item (ref22's inventory and Store
--     egg card): white (tinted by rarity), rainbow (Secret), black (the "+n" slot). Kit.splat draws them.
Kit.TextureFiles = { stud_bevel = 'StudBevel', stud_checker = 'StudChecker', stud_tile = 'StudTile', gloss_band = 'GlossBand', gloss_stripes = 'GlossStripes',
	splat = 'Splat', splat_rainbow = 'SplatRainbow', splat_black = 'SplatBlack' } -- (file -> field)
-- Whether studs are one cheap tiled image (some stud texture is uploaded): long lists add studs only then.
function Kit.studsAreCheap() return Kit.StudBevel ~= '' or Kit.StudTile ~= '' end

-- A stud grid over parent, clipped to it: one small square outline per stud. props: Width / Height (design px of the
-- area; default the parent's Offset size), Pitch (px between stud centres, 15: the HUD's 22 reference px; windows use
-- bigger ones, like the reference), Size (stud side, half the pitch), Color, Transparency (0.6), Thickness, Inset (px
-- kept clear at the edges, 2), ZIndex.
function Kit.studs(parent, props)
	props = props or {}
	local w = props.Width or parent.Size.X.Offset
	local h = props.Height or parent.Size.Y.Offset
	local pitch = props.Pitch or 15
	local s = props.Size or math.floor(pitch * 0.5 + 0.5)
	local inset = props.Inset or 2
	local z = props.ZIndex or parent.ZIndex
	local color = props.Color or Kit.Color.white
	local transparency = props.Transparency or 0.6
	local aw, ah = math.max(0, w - 2 * inset), math.max(0, h - 2 * inset)
	-- (brief 19) an uploaded texture: one ImageLabel tiles the whole grid, offset so whole studs sit centred like the frame
	-- grid's. props.Pattern = 'checker' asks for the raised / recessed 2 x 2 tile; Shade (0..1, default 0.7 = an
	-- ImageTransparency of 0.3) is how strongly the pre-shaded tiles draw.
	-- (brief 22, ICONS r1) StudBevel is the HUD blocks' recessed stud, drawn white at ImageTransparency >= 0.2; the
	-- checker (window headers, the level bar, the Rebirth boxes) stays at >= 0.45 (UICRITIC2: low contrast).
	local file, image, tilePitch, tint, alpha, floor
	if props.Pattern == 'checker' and Kit.StudChecker ~= '' then
		file, image, tilePitch, tint, alpha, floor = 'stud_checker', Kit.StudChecker, pitch * 2, Kit.Color.white, 1 - (props.Shade or 0.7), 0.45
	elseif Kit.StudBevel ~= '' then
		file, image, tilePitch, tint, alpha, floor = 'stud_bevel', Kit.StudBevel, pitch, Kit.Color.white, 1 - (props.Shade or 0.7), 0.2
	elseif Kit.StudTile ~= '' then
		file, image, tilePitch, tint, alpha, floor = 'stud_tile', Kit.StudTile, pitch, color, math.max(0, transparency - (props.TileBoost or 0.12)), 0
	end
	if image then
		if props.Tint then tint = props.Tint end -- (Oct 27: the windows' faint blue tile)
		-- (brief 22, UICRITIC2: the reference's grid fills the whole block from its top-left corner, the first stud half a
		-- pitch in, and is low-contrast) one tiled ImageLabel over the whole face
		local tile = new('ImageLabel', {
			Name = 'Studs', BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tilePitch, tilePitch),
			ImageColor3 = tint, ImageTransparency = math.max(alpha, props.MinAlpha or floor), Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = z, Parent = parent,
		})
		tile:SetAttribute('PreviewImage', 'ui:' .. file) -- (the offline previewer draws hood/art/ui/<file>.png)
		return tile
	end
	local holder = blank({ Name = 'Studs', Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 1, -2 * inset), ClipsDescendants = true, ZIndex = z, Parent = parent })
	local cols, rows = math.max(1, math.floor(aw / pitch)), math.max(1, math.floor(ah / pitch))
	local filled = props.Filled
	if filled == nil then filled = pitch >= 24 end
	local shade = props.Shade or 0.7
	local light = props.Light or Kit.Color.white
	local ox, oy = (aw - (cols - 1) * pitch) / 2, (ah - (rows - 1) * pitch) / 2 -- (the grid centred, whole studs only)
	local recessed = props.Pattern == 'recessed'
	if props.Pattern == 'checker' or recessed then
		-- (brief 22, UICRITIC2) like the texture: the grid from the top-left corner, the first stud half a pitch in
		cols, rows = math.max(1, math.ceil(aw / pitch)), math.max(1, math.ceil(ah / pitch))
		ox, oy = pitch / 2 - inset, pitch / 2 - inset
	end
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local at = UDim2.fromOffset(math.floor(ox + c * pitch), math.floor(oy + r * pitch))
			local raised = (r + c) % 2 == 0
			if recessed then
				-- (brief 22, UICRITIC2 r0 #5 / ICONS r1: the HUD blocks' studs are all alike, recessed, about 10% darker than
				-- the fill) one faint dark Frame a stud; on big surfaces (pitch >= 24) props.Sparse keeps every other one
				if not (filled and raised and props.Sparse) then
					blank({ Name = 'Stud', BackgroundTransparency = filled and 0.9 or 0.87, BackgroundColor3 = Kit.Color.black, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
				end
			elseif props.Pattern == 'checker' then
				-- (brief 22, UICRITIC2: the reference's studs are recessed and low-contrast: a darker outline about 10% off
				-- the fill, every other one with a slightly darker face) a Frame + its UIStroke a stud; on big surfaces
				-- (pitch >= 24: cards) one faint Frame a stud, and props.Sparse keeps only every other one (long lists).
				if filled then
					if not raised or not props.Sparse then
						blank({ Name = 'Stud', BackgroundTransparency = raised and math.min(0.95, transparency + 0.1) or transparency, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
					end
				elseif raised then
					local stud = blank({ Name = 'Stud', AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
					stroke(color, props.Thickness or math.max(1.2, pitch * 0.09), true, transparency, Enum.LineJoinMode.Miter).Parent = stud
				else
					-- (the recessed alternate: just a faint darker face, one instance)
					blank({ Name = 'Stud', BackgroundTransparency = 1 - (1 - transparency) * 0.55, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
				end
			elseif filled then
				-- a stud is a small square outline, like the reference's plates (Frame + UIStroke: two instances a stud); big
				-- surfaces (pitch >= 24: window cards and rows) get a faint filled square instead, one instance a stud
				blank({ Name = 'Stud', BackgroundTransparency = math.min(0.95, transparency + 0.16), BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
			else
				local stud = blank({ Name = 'Stud', AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(s, s), ZIndex = z, Parent = holder })
				stroke(color, props.Thickness or math.max(1.2, pitch * 0.09), true, transparency).Parent = stud
			end
		end
	end
	return holder
end

-- (brief 22) A paint splat (ref22: behind every pet in the inventory and the Store's egg card): `size` square, tinted
-- `color`; props.Kind = 'rainbow' (Secret) or 'black' (the "+n" slot), Position, AnchorPoint, ZIndex, Rotation. The
-- uploaded texture when there is one, else six overlapping round blobs in the colour (12 instances).
-- Two colours' hues within `deg` degrees (both colourful: a grey or a near-white has no hue to clash).
function Kit.hueNear(a, b, deg)
	local function hsv(c)
		local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
		local d = mx - mn
		if d < 1e-6 then return 0, 0 end
		local h
		if mx == c.R then h = ((c.G - c.B) / d) % 6 elseif mx == c.G then h = (c.B - c.R) / d + 2 else h = (c.R - c.G) / d + 4 end
		return h * 60, d / mx
	end
	local ha, sa = hsv(a)
	local hb, sb = hsv(b)
	if sa < 0.25 or sb < 0.25 then return false end
	local diff = math.abs(ha - hb) % 360
	return math.min(diff, 360 - diff) <= deg
end
-- props.On: the colour it sits on (a card); within 30 degrees of the splat's hue, the splat gets a darker rim so it
-- doesn't vanish into the card (CRITIC5 r2: the blue Rare splat on the blue Exclusive card).
function Kit.splat(size, color, props)
	props = props or {}
	local z = props.ZIndex or 1
	local kind = props.Kind
	local image = kind == 'rainbow' and Kit.SplatRainbow or kind == 'black' and Kit.SplatBlack or Kit.Splat
	local holder = blank({ Name = 'Splat', Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, Rotation = props.Rotation or 0, ZIndex = z })
	local c = kind == 'black' and hex('15151C') or color or Kit.Color.white
	-- (brief 22 r2: like ICONS' texture, a lobed splash ~80% of the square with loose drops, not three big discs)
	local function blobs(transparency)
		local rainbow = { hex('FF4FA0'), hex('5AD8FF'), hex('FFE24A'), hex('A65CFF'), hex('FF9A2E'), hex('5BE37A') }
		for i, b in { { 0.5, 0.52, 0.56 }, { 0.32, 0.36, 0.34 }, { 0.69, 0.35, 0.3 }, { 0.68, 0.69, 0.3 }, { 0.33, 0.7, 0.26 }, { 0.14, 0.62, 0.09 } } do
			local blob = blank({ Name = 'Blob' .. i, BackgroundTransparency = transparency or 0, BackgroundColor3 = kind == 'rainbow' and rainbow[i] or c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromScale(b[3], b[3]), ZIndex = z, Parent = holder })
			corner(UDim.new(0.5, 0)).Parent = blob
		end
	end
	if image ~= '' then
		local file = kind == 'rainbow' and 'splat_rainbow' or kind == 'black' and 'splat_black' or 'splat'
		local edge
		if kind == nil and props.On and Kit.hueNear(c, props.On, 30) then
			-- (made first: drawn under the splat, 4 px out all round)
			edge = new('ImageLabel', { Name = 'Edge', BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = c:Lerp(Color3.new(0, 0, 0), 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 1, 8), ZIndex = z, Parent = holder })
			edge:SetAttribute('PreviewImage', 'ui:' .. file)
		end
		local img = new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = (kind == nil and color) or Kit.Color.white, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
		img:SetAttribute('PreviewImage', 'ui:' .. file)
		-- (brief 23) the blobs while the uploaded texture doesn't load (Kit.watchImage)
		Kit.watchImage(img, function()
			img.Visible = false
			if edge then edge.Visible = false end
			blobs(img.ImageTransparency)
		end, function()
			for _, d in holder:GetChildren() do
				if d ~= img and d ~= edge then d:Destroy() end
			end
			img.Visible = true
			if edge then edge.Visible = true end
		end)
		return holder
	end
	blobs(0)
	return holder
end

-- Two soft diagonal light bands across a block (the reference's Store header and big cards).
function Kit.gloss(parent, props)
	props = props or {}
	if Kit.GlossStripes ~= '' then
		-- (brief 19) ICONS' seamless stripe, tiled every Pitch px (default 102: three of the headers' 34 px studs)
		local pitch = props.Pitch or 102
		local img = new('ImageLabel', { Name = 'Gloss', BackgroundTransparency = 1, Image = Kit.GlossStripes, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(pitch, pitch), ImageTransparency = props.ImageTransparency or 0, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex or parent.ZIndex, Parent = parent })
		img:SetAttribute('PreviewImage', 'ui:gloss_stripes')
		return img
	end
	if Kit.GlossBand ~= '' then
		-- (brief 19) ICONS' uploaded band texture, stretched over the face: one ImageLabel
		local img = new('ImageLabel', { Name = 'Gloss', BackgroundTransparency = 1, Image = Kit.GlossBand, ScaleType = Enum.ScaleType.Stretch, ImageTransparency = props.ImageTransparency or 0, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex or parent.ZIndex, Parent = parent })
		img:SetAttribute('PreviewImage', 'ui:gloss_band')
		return img
	end
	local band = blank({ Name = 'Gloss', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.fromScale(1, 1), ZIndex = props.ZIndex or parent.ZIndex, Parent = parent })
	corner(props.Radius or 3).Parent = band
	local a = props.Transparency or 0.86
	new('UIGradient', {
		Rotation = props.Rotation or 24,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.21, a), NumberSequenceKeypoint.new(0.36, a),
			NumberSequenceKeypoint.new(0.37, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(0.56, a + (1 - a) * 0.35),
			NumberSequenceKeypoint.new(0.63, a + (1 - a) * 0.35), NumberSequenceKeypoint.new(0.64, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	return band
end

-- A studded block. props: Name, Tone (a Kit.Tone name or a {top, base, lip, stroke, rim?, rot?, seq?} table), Width,
-- Height, Position, AnchorPoint, LayoutOrder, ZIndex, Radius (0: the reference's corners are square; > 0 rounds them),
-- Outline (3), Studs (pitch in px, or false; 15), StudColor / StudTransparency (the frame and tinted-tile studs),
-- StudPattern ('checker': the raised / recessed tile) / StudShade (the pre-shaded tiles' strength), Gloss (the diagonal
-- bands), Shadow (px straight down, 0: the reference has none), Rim (false = no light inner band) / RimWidth (2), Flat.
-- Returns holder; holder.Body is the face to put content in.
---------------------------------------------------------------------------------------------- the owner's UI pictures
-- (Oct 27, round 3; the owner: "directly import the images of the ui ... the ones you make aren't the same") Buttons,
-- tabs, tiles, cards, bars, the header bar, the X and the window body wear pieces cut from the owner's UI mockup
-- (hood/tools/ui/cut_mockup.py -> hood/art/ui_owner, packed into Shared/Images/Ui by hood/tools/ui/pack_images.py),
-- 9-sliced (SliceCenter) so they stretch without blurring their corners, and drawn in game by Shared/ImageLoader (no
-- upload). The words stay ours (live Montserrat over the piece). While a piece can't be drawn (Studio's Game Settings >
-- Security > "Allow Mesh / Image APIs" off, or the picture memory full) the drawn look underneath shows instead.
Kit.ImageLoader = ImageLoader
Kit.UseOwnerSkins = true
-- A tone's pieces: { small (buttons, pills, rows), big (h >= Kit.SkinBig: tiles and cards) }.
Kit.SkinBig = 110
Kit.SkinPieces = {
	buyGreen = { 'btn_green', 'tile_green' }, green = { 'btn_green', 'tile_green' }, cardGreen = { 'btn_green', 'tile_green' },
	lime = { 'price_green', 'tile_green' },
	slate = { 'btn_grey', 'tile_grey' }, grey = { 'btn_grey', 'tile_grey' }, disabled = { 'btn_grey', 'tile_grey' },
	red = { 'btn_red', 'tile_red' }, cardRed = { 'btn_red', 'tile_red' },
	gold = { 'btn_yellow', 'tile_yellow' }, yellow = { 'btn_yellow', 'tile_yellow' }, cardGold = { 'btn_yellow', 'tile_yellow' },
	blue = { 'tab_on_blue', 'tile_blue' }, cardBlue = { 'tab_on_blue', 'tile_blue' }, tabBlue = { 'tab_on_blue', 'tile_blue' }, cyan = { 'tab_on_blue', 'tile_blue' },
	purple = { 'tile_purple', 'tile_purple' }, cardPurple = { 'tile_purple', 'tile_purple' }, magenta = { 'tile_purple', 'tile_purple' },
	navyRow = { 'tab_off', 'stat_card' }, navy = { 'tab_off', 'stat_card' }, dark = { 'tab_off', 'stat_card' },
	closeRed = { 'close', 'close' },
}
-- The tile for a shoe rarity (Config/Shoes.Rarities' Id).
Kit.RarityPiece = { Common = 'tile_grey', Rare = 'tile_blue', Epic = 'tile_purple', Legendary = 'tile_yellow', Mythic = 'tile_red', Secret = 'tile_secret' }
function Kit.skinPiece(tone, h)
	if not Kit.UseOwnerSkins or type(tone) ~= 'string' then return nil end
	local row = Kit.SkinPieces[tone]
	if not row then return nil end
	local piece = (h or 0) >= Kit.SkinBig and row[2] or row[1]
	return ImageLoader.meta('Ui', piece) and piece or nil
end
-- The drawn look's parts a piece covers (hidden while it shows).
local LOOK = { Studs = true, Gloss = true, Rim = true, TopBand = true, IdleBorder = true, Border = true }
local function skinLook(face, skinImg, on, keep)
	local saved = skinImg:GetAttribute('SavedT')
	if not on then
		if saved == nil then skinImg:SetAttribute('SavedT', face.BackgroundTransparency) end
		if not keep.Fill then face.BackgroundTransparency = 1 end
	elseif saved ~= nil then
		face.BackgroundTransparency = saved
	end
	for _, c in face:GetChildren() do
		if c:IsA('UIStroke') and not keep.Stroke then
			c.Enabled = on
		elseif LOOK[c.Name] and c:IsA('GuiObject') and not keep[c.Name] then
			c.Visible = on
		elseif c.Name == 'Face' and c:IsA('GuiObject') and not keep.Face then
			-- (an ArtKit.framed card's inner face: it holds the item and its words, so only its fill and line go)
			if c:GetAttribute('SavedT') == nil then c:SetAttribute('SavedT', c.BackgroundTransparency) end
			c.BackgroundTransparency = on and c:GetAttribute('SavedT') or 1
			local st = c:FindFirstChildOfClass('UIStroke')
			if st then st.Enabled = on end
		end
	end
	skinImg:SetAttribute('Shown', not on)
	if skinImg:GetAttribute('Piece') == 'close' then
		-- (the owner's X carries its own white cross: our "X" label steps aside while it shows)
		local label = face:FindFirstChild('Label')
		if label then label.Visible = on end
	end
end
-- Lays piece `piece` over `face` (a block's face Frame; its look stays underneath while the picture can't be drawn).
-- props: Out (px the face's outline reaches outside it: the piece carries its own outline and covers that too),
-- Height (the whole look's height, for the slice scale), SliceScale, TileScale (tile pieces), Radius (a UICorner on the
-- piece), Keep { Stroke, Fill, Rim, ... } (parts of the drawn look kept under the piece). Returns the ImageLabel.
function Kit.skin(face, piece, props)
	local meta = ImageLoader.meta('Ui', piece)
	if not meta then return nil end
	props = props or {}
	local out = props.Out or 0
	local h = props.Height or (face.Size.Y.Offset + 2 * out)
	local img = new('ImageLabel', { Name = 'Skin', BackgroundTransparency = 1, Image = '', Position = UDim2.fromOffset(-out, -out), Size = UDim2.new(1, 2 * out, 1, 2 * out), ZIndex = math.max(0, face.ZIndex - 1), Parent = face })
	img:SetAttribute('Piece', piece)
	img:SetAttribute('SkinH', h)
	if props.Radius and props.Radius > 0 then corner(props.Radius).Parent = img end
	local keep = props.Keep or {}
	Kit.reskin(img, piece, { SliceScale = props.SliceScale, TileScale = props.TileScale, Keep = keep })
	return img
end
-- Points a skin at another piece (a tab turning on, a button turning grey).
function Kit.reskin(img, piece, props)
	if not img then return end
	local meta = ImageLoader.meta('Ui', piece)
	if not meta then return end
	props = props or {}
	local face = img.Parent
	img:SetAttribute('Piece', piece)
	if meta.Mode == 'tile' then
		img.ScaleType = Enum.ScaleType.Tile
		local k = props.TileScale or 1
		img.TileSize = UDim2.fromOffset(math.max(4, math.floor(meta.W * k + 0.5)), math.max(4, math.floor(meta.H * k + 0.5)))
	elseif meta.Mode == 'whole' then
		img.ScaleType = Enum.ScaleType.Stretch
	else
		img.ScaleType = Enum.ScaleType.Slice
		local s = meta.Slice
		img.SliceCenter = Rect.new(s[1], s[2], s[3], s[4])
		img.SliceScale = props.SliceScale or math.clamp((img:GetAttribute('SkinH') or meta.H) / meta.H, 0.15, 3)
	end
	local keep = props.Keep or {}
	ImageLoader.apply(img, 'Ui', piece, '', {
		onShow = function() skinLook(face, img, false, keep) end,
		onFail = function() skinLook(face, img, true, keep) end,
	})
end

function Kit.block(props)
	local tone = toneOf(props.Tone)
	local w, h = props.Width or 160, props.Height or 60
	-- (brief 19) the reference's blocks have crisp square corners: no UICorner and a mitred outline (Radius > 0 rounds)
	local r = props.Radius or 0
	local z = props.ZIndex or 1
	local holder = blank({ Name = props.Name or 'Block', Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = z })
	local sh = props.Shadow or 0
	if sh > 0 then
		local shadow = blank({ Name = 'Shadow', BackgroundTransparency = 0.45, BackgroundColor3 = Kit.Color.ink, Position = UDim2.fromOffset(0, sh), Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
		corner(r).Parent = shadow
	end
	-- (brief 18) Width x Height is the block's whole look, outline included (the reference was measured that way): a
	-- UIStroke draws outside its frame, so the face is inset by the outline's width.
	local O = props.Outline or 3
	local body = blank({ Name = 'Body', BackgroundTransparency = 0, BackgroundColor3 = props.Flat and tone.base or Kit.Color.white, Position = UDim2.fromOffset(O, O), Size = UDim2.new(1, -2 * O, 1, -2 * O), ZIndex = z + 1, Parent = holder })
	if r > 0 then corner(r).Parent = body end
	stroke(props.OutlineColor or Kit.Color.black, O, true, 0, r > 0 and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter).Parent = body
	if not props.Flat then Kit.fillGradient(tone).Parent = body end
	if props.Studs ~= false then
		-- (brief 22) the reference's recessed studs on every block ('checker': the raised / recessed tile of the window
		-- headers and the Rebirth boxes; 'plain': none of these, the old centred outline grid)
		local pattern = props.StudPattern or 'recessed'
		local studs = Kit.studs(body, { Width = w - 2 * O, Height = h - 2 * O, Pitch = props.Studs or 15, Color = props.StudColor or tone.lip, Transparency = props.StudTransparency or 0.66, Pattern = pattern ~= 'plain' and pattern or nil, Shade = props.StudShade or 0.8, Sparse = props.StudSparse, ZIndex = z + 1 })
		if r > 0 and studs and studs:IsA('ImageLabel') then corner(r).Parent = studs end -- (Oct 27: the tile stays inside rounded corners)
	end
	if props.Gloss then Kit.gloss(body, { ZIndex = z + 1, Radius = r }) end
	if props.Rim ~= false then
		local rw = props.RimWidth or 2
		local rim = blank({ Name = 'Rim', Position = UDim2.fromOffset(rw, rw), Size = UDim2.new(1, -2 * rw, 1, -2 * rw), ZIndex = z + 1, Parent = body })
		if r > rw then corner(r - rw).Parent = rim end
		stroke(tone.rim or Kit.Color.white, rw, true, tone.rim and 0.25 or 0.6, r > rw and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter).Parent = rim
		if props.InnerLine then
			-- (brief 22: the reference's squares: outline, a light rim, then a thin darker line before the fill)
			local line = blank({ Name = 'InnerLine', Position = UDim2.fromOffset(rw, rw), Size = UDim2.new(1, -2 * rw, 1, -2 * rw), ZIndex = z + 1, Parent = rim })
			stroke(tone.lip or Kit.Color.black, 1, true, 0.35, Enum.LineJoinMode.Miter).Parent = line
		end
	end
	-- (round 3) the owner's piece for this tone over the drawn look (props.Skin: a piece name, or false for none)
	local piece = props.Skin ~= false and (type(props.Skin) == 'string' and props.Skin or Kit.skinPiece(props.Tone, h)) or nil
	if piece then Kit.skin(body, piece, { Out = O, Height = h }) end
	holder:SetAttribute('Tone', type(props.Tone) == 'string' and props.Tone or '')
	return holder
end

-- A Kit.block that presses (UIMotion.button: holder.Hit takes the input, holder.Body dips). Extra props: Text,
-- TextSize, TextColor3, FontFace, Icon (an icon3d id) / IconSize / IconInset, Disabled (grey, and the caller doesn't
-- hook UIMotion.button). Returns holder, hit.
function Kit.blockButton(props)
	local p = table.clone(props)
	if p.Disabled then p.Tone = 'grey' end
	local holder = Kit.block(p)
	local body = holder.Body
	local h = p.Height or 60
	local z = (p.ZIndex or 1) + 2
	local textLeft = 0
	if p.Icon then
		local s = p.IconSize or math.floor(h * 0.95)
		Kit.icon3d(p.Icon, s, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, p.IconInset or -4, 0.5, 0), ZIndex = z }).Parent = body
		textLeft = s + (p.IconInset or -4) - 4
	end
	if p.Text then
		local size = p.TextSize or Kit.Text.button
		local room = (p.Width or 160) - textLeft - 14
		size = Kit.fitSize(p.Text, size, room, 10)
		Kit.text({
			Name = 'Label', Text = p.Text, TextSize = size, FontFace = p.FontFace or Kit.Font.display, TextColor3 = p.TextColor3 or (p.Disabled and Kit.hex('EDEAE4')) or Kit.Color.white,
			Stroke = Kit.Color.black, StrokeThickness = math.max(1.5, size * 0.12), Position = UDim2.new(0, textLeft + 4, 0, 0), Size = UDim2.new(1, -textLeft - 8, 1, -1), ZIndex = z, Parent = body,
		})
	end
	local hit = new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 3, Parent = holder })
	holder:SetAttribute('Lip', 3)
	-- (round 3) the owner's X carries its own white cross: our "X" label steps aside while it shows (skinLook)
	local skin = body:FindFirstChild('Skin')
	local label = body:FindFirstChild('Label')
	if skin and label and skin:GetAttribute('Piece') == 'close' then label.Visible = skin:GetAttribute('Shown') ~= true end
	return holder, hit
end

-- The HUD's square action button (the reference's Store / World / Rebirth ... column): a studded block with a big
-- icon filling most of it and popping out of its top edge, and an outlined caption low on its face. props: Name,
-- Tone, Width, Height, Position, AnchorPoint, ZIndex, Text, TextSize, LabelY (the caption's centre as a fraction of the
-- height, 0.82), Icon (an icon3d id) or IconNode (any GuiObject), IconSize, IconX (px off centre), Pop (px the icon
-- rises over the top edge). The hit area grows to cover the icon. Returns holder, hit, icon, caption.
function Kit.actionButton(props)
	local w, h = props.Width or 81, props.Height or 81
	local pop = props.Pop or 12
	local holder, hit = Kit.blockButton({ Name = props.Name, Tone = props.Tone, Width = w, Height = h, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex, Studs = props.Studs or 15, RimWidth = props.RimWidth or 3, InnerLine = props.InnerLine ~= false, Radius = props.Radius })
	local z = (props.ZIndex or 1) + 3
	local icon
	local clip
	if props.Place and not props.IconNode then
		-- (brief 25) the picture where the reference puts it (Kit.Place[props.Place]): big, popping out of the top
		local rule = type(props.Place) == 'table' and props.Place or Kit.Place[props.Place] -- (brief 30: a rule table works too)
		local place = { Rule = props.Place, W = w, H = h, X0 = 3, Y0 = 3 }
		if rule and rule.ClipTop then
			-- clipped at the button's bottom edge (the frame spans the button's width, from ClipTop down)
			local top = math.floor(rule.ClipTop * h)
			clip = new('Frame', { Name = 'PictureClip', BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(-3, top - 3), Size = UDim2.fromOffset(w, h - top), ZIndex = z, Parent = holder.Body })
			place.X0, place.Y0 = 0, top
		end
		icon = Kit.icon3d(props.Icon or 'Shop', nil, { Place = place })
		pop = math.max(0, -(icon.Position.Y.Offset + place.Y0) - 4)
	else
		local size = props.IconSize or math.floor(math.min(w, h) * 0.88)
		icon = props.IconNode or Kit.icon3d(props.Icon or 'Shop', size, {})
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, props.IconX or 0, 0, -pop)
	end
	local base = icon.ZIndex
	icon.ZIndex = z
	for _, d in icon:GetDescendants() do
		if d:IsA('GuiObject') then d.ZIndex = z + math.max(0, d.ZIndex - base) end -- (keeps the icon's layers in order)
	end
	icon.Parent = clip or holder.Body
	local textSize = props.TextSize or 22
	local caption = Kit.text({
		Name = 'Caption', Text = props.Text or '', TextSize = textSize, Stroke = Kit.Color.black, StrokeThickness = math.max(2, textSize * 0.13),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, props.LabelY or 0.82, 0), Size = UDim2.new(1, 12, 0, textSize + 4), ZIndex = z + 1, Parent = holder.Body,
	})
	hit.Position = UDim2.fromOffset(0, -pop)
	hit.Size = UDim2.new(1, 0, 1, pop)
	return holder, hit, icon, caption
end

-- An outlined sticker on a corner of a button ("100%", "!"): props Text, TextSize, TextColor3, AnchorPoint, Position,
-- Rotation, Width.
function Kit.sticker(parent, props)
	local size = props.TextSize or 24
	return Kit.text({
		Name = props.Name or 'Sticker', Text = props.Text or '', TextSize = size, TextColor3 = props.TextColor3, Stroke = Kit.Color.black, StrokeThickness = math.max(2, size * 0.13),
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0.5), Position = props.Position or UDim2.new(1, 8, 0, 4), Size = UDim2.fromOffset(props.Width or 80, size + 6),
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Right, Rotation = props.Rotation or 0, ZIndex = props.ZIndex or 8, Parent = parent,
	})
end

-- The Robux mark (the reference's lime hexagon-ish coin with a square hole): a rounded ring round a small square,
-- black-edged so it reads on any colour. props: Color (lime), Position, AnchorPoint, ZIndex, LayoutOrder. Returns a
-- `size` square Frame.
-- The mark drawn with frames (before the upload, or while the uploaded glyph doesn't load): the reference's mark is a
-- pointy-topped hexagon (black-edged) with a dark square in its middle. A hexagon is three rectangles turned 0 / 60 /
-- 120 degrees (R across the corners: R * sqrt(3) wide, R tall).
local function robuxFrames(holder, size, color, props)
	local z = holder.ZIndex
	local function hexagon(name, r, c, zz)
		for i, rot in { 0, 60, 120 } do
			blank({ Name = name .. i, BackgroundTransparency = 0, BackgroundColor3 = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(r * 1.732, r), Rotation = rot, ZIndex = zz, Parent = holder })
		end
	end
	-- black edge, the coloured ring, a darker (or `Inner`) hexagon inside it, and the square core (`Core`, black)
	local R = size * 0.5
	local edge = math.max(1.5, size * 0.1)
	hexagon('Edge', R, props.Edge or Kit.Color.black, z)
	hexagon('Face', R - edge, color, z)
	if size >= 14 then hexagon('Inner', (R - edge) * 0.62, props.Inner or color:Lerp(Kit.Color.black, 0.3), z) end
	local core = blank({ Name = 'Core', BackgroundTransparency = 0, BackgroundColor3 = props.Core or Kit.Color.black, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.max(3, size * 0.26), math.max(3, size * 0.26)), ZIndex = z, Parent = holder })
	corner(math.max(1, math.floor(size * 0.05))).Parent = core
end
function Kit.robux(size, props)
	props = props or {}
	local color = props.Color or Kit.Tone.lime.top
	local z = props.ZIndex or 1
	local holder = blank({ Name = 'Robux', Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = z })
	-- (brief 19) ICONS' uploaded glyph (white, black outline baked in) tinted to `color`: one ImageLabel.
	local image = Kit.iconImage('Robux')
	if image ~= '' then
		local img = new('ImageLabel', { Name = 'Glyph', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = color, ZIndex = z, Parent = holder })
		img:SetAttribute('PreviewImage', 'icon3d:Robux')
		-- (brief 23) the frame mark while the uploaded glyph doesn't load (Kit.watchImage)
		Kit.watchImage(img, function()
			img.Visible = false
			robuxFrames(holder, size, img.ImageColor3, props)
		end, function()
			for _, d in holder:GetChildren() do
				if d ~= img then d:Destroy() end
			end
			img.Visible = true
		end)
		return holder
	end
	robuxFrames(holder, size, color, props)
	return holder
end

-- The width of a line of display text, for labels laid out next to each other without AutomaticSize: Montserrat Black's
-- advance per character in em (Fonts.Title; the Bold faces are narrower, so it is safe for them too), 0.6 em for anything
-- else, plus a stroke's allowance. Rich-text tags are skipped.
local ADVANCE = {}
do
	local widths = { [' '] = 0.30, ['!'] = 0.31, ['"'] = 0.53, ['#'] = 0.74, ['$'] = 0.66, ['%'] = 0.80, ['&'] = 0.78, ["'"] = 0.29, ['('] = 0.38, [')'] = 0.38,
		['*'] = 0.49, ['+'] = 0.63, [','] = 0.30, ['-'] = 0.40, ['.'] = 0.30, ['/'] = 0.37, [':'] = 0.30, [';'] = 0.30, ['?'] = 0.60, ['~'] = 0.63, ['|'] = 0.32 }
	local rows = {
		{ '0123456789', { 0.69, 0.42, 0.61, 0.61, 0.71, 0.61, 0.66, 0.65, 0.68, 0.66 } },
		{ 'ABCDEFGHIJKLM', { 0.84, 0.77, 0.71, 0.83, 0.67, 0.64, 0.77, 0.80, 0.35, 0.57, 0.77, 0.62, 0.95 } },
		{ 'NOPQRSTUVWXYZ', { 0.80, 0.85, 0.73, 0.85, 0.74, 0.66, 0.66, 0.78, 0.79, 1.21, 0.76, 0.70, 0.69 } },
		{ 'abcdefghijklm', { 0.64, 0.70, 0.61, 0.70, 0.65, 0.44, 0.71, 0.70, 0.33, 0.33, 0.70, 0.33, 1.04 } },
		{ 'nopqrstuvwxyz', { 0.70, 0.68, 0.70, 0.70, 0.46, 0.57, 0.45, 0.70, 0.63, 0.96, 0.65, 0.63, 0.57 } },
	}
	for _, row in rows do
		for i = 1, #row[1] do widths[row[1]:sub(i, i)] = row[2][i] end
	end
	widths[utf8.char(0xE002)] = 0.85 -- (ROBUX) the Robux sign (RobuxText.Mark): about a cap-height hexagon and its gap
	ADVANCE = widths
end
function Kit.textWidth(text, size)
	local plain = tostring(text):gsub('<[^>]->', '')
	local em = 0
	for _, code in utf8.codes(plain) do
		em += ADVANCE[utf8.char(code)] or 0.6
	end
	return math.ceil(em * size + size * 0.18)
end
-- The biggest text size (<= maxSize, >= minSize) at which `text` fits on one line in `width` design px.
function Kit.fitSize(text, maxSize, width, minSize)
	local w = Kit.textWidth(text, 100) / 100
	if w <= 0 then return maxSize end
	return math.max(minSize or 8, math.min(maxSize, math.floor(width / w)))
end

-- "ONLY <Robux> 199" (the reference's price under the offer cards and 2x Speed): ONLY in a yellow -> green gradient,
-- the mark and the price in gold -> orange, all black-outlined (props OnlyColors / MarkColor / PriceColors restyle it:
-- the 2x Speed slot's is all lime; Only = false drops the word). Returns a Frame `size` tall, as wide as its text.
function Kit.only(price, size, props)
	props = props or {}
	local z = props.ZIndex or 8
	local text = type(price) == 'number' and require(script.Parent.RobuxText).commas(price) or tostring(price) -- (ROBUX: 1,499)
	local onlyW, priceW = Kit.textWidth('ONLY', size), Kit.textWidth(text, size)
	local glyph = math.floor(size * 1.25) -- (the reference's mark is as tall as the outlined letters)
	local row = blank({ Name = props.Name or 'Only', AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5), Position = props.Position or UDim2.new(), Size = UDim2.fromOffset(onlyW + glyph + 2 + priceW, size + 6), ZIndex = z })
	row:SetAttribute('NoTextFloor', true) -- (laid out from its text's width: pick its size instead)
	if props.Only ~= false then
		local only = Kit.text({ Name = 'Only', Text = 'ONLY', TextSize = size, Stroke = Kit.Color.black, StrokeThickness = math.max(2, size * 0.14), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(onlyW, size + 6), ZIndex = z, Parent = row })
		new('UIGradient', { Color = props.OnlyColors or ColorSequence.new(hex('F2F020'), hex('3CF000')), Parent = only })
	else
		row.Size = UDim2.fromOffset(glyph + 2 + priceW, size + 6)
		onlyW = 0
	end
	Kit.robux(glyph, { Color = props.MarkColor or hex('E8D020'), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, onlyW, 0.5, 0), ZIndex = z }).Parent = row
	local label = Kit.text({ Name = 'Price', Text = text, TextSize = size, Stroke = Kit.Color.black, StrokeThickness = math.max(2, size * 0.14), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(onlyW + glyph + 2, 0), Size = UDim2.fromOffset(priceW, size + 6), ZIndex = z, Parent = row })
	new('UIGradient', { Rotation = 90, Color = props.PriceColors or ColorSequence.new(hex('FFD21A'), hex('FF8A10')), Parent = label })
	return row, label
end

-- The reference's green price button: the Robux mark and the price in white. props as Kit.blockButton plus Price (a
-- number or text). Returns holder, hit, label.
function Kit.robuxButton(props)
	local p = table.clone(props)
	p.Tone = p.Tone or 'lime'
	p.Text = nil
	p.Studs = p.Studs or false
	p.Outline = p.Outline or 3
	-- (brief 19 r7, UICRITIC P2-7) the reference's price button is outlined in its own dark green, not black
	local ink = toneOf(p.Tone).stroke or Kit.Color.black
	p.OutlineColor = p.OutlineColor or ink
	local holder, hit = Kit.blockButton(p)
	local h = p.Height or 44
	local z = (p.ZIndex or 1) + 2
	local size = p.TextSize or math.floor(h * 0.66)
	local text = type(p.Price) == 'number' and require(script.Parent.RobuxText).commas(p.Price) or tostring(p.Price or '?') -- (ROBUX: 1,499)
	local glyph = math.floor(size * 1.12)
	local tw = Kit.textWidth(text, size)
	local row = blank({ Name = 'Price', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(glyph + 2 + tw, h), ZIndex = z, Parent = holder.Body })
	-- (the reference's mark: a white hexagon with dark-green linework and a dark-green square in the middle)
	Kit.robux(glyph, { Color = Kit.Color.white, Inner = Kit.Color.white, Core = ink, Edge = ink, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = z }).Parent = row
	local label = Kit.text({ Name = 'Label', Text = text, TextSize = size, Stroke = ink, StrokeThickness = math.max(2, size * 0.12), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(glyph + 2, 0), Size = UDim2.new(0, tw, 1, -1), ZIndex = z, Parent = row })
	return holder, hit, label
end

-- A studded progress bar like the reference's level bar: a dark see-through track, a tone fill, studs over both and
-- outlined text at the left, the right and/or the centre. props: Name, Width, Height, Tone (the fill), Value (0..1),
-- Left, Right, Text, TextSize, Position, AnchorPoint, LayoutOrder, ZIndex, Radius, Outline.
-- Returns the bar (its whole look, outline included), fill, labels ({ Left, Right, Text }; only the ones asked for).
function Kit.bar(props)
	local w, h = props.Width or 400, props.Height or 40
	local tone = toneOf(props.Tone or 'level')
	local z = props.ZIndex or 1
	local r = props.Radius or 0
	-- (the holder is the bar's whole look, outline included; the track inside it carries the outline, the fill, the studs)
	local O = props.Outline or 3
	local holder = blank({ Name = props.Name or 'Bar', Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = z })
	-- (brief 19) the empty part is light, like the reference family's level bar (ref1_hall_a: white past the blue fill)
	local dark = props.Track == 'dark'
	local track = blank({ Name = 'Track', BackgroundTransparency = props.TrackTransparency or (dark and 0.25 or 0), BackgroundColor3 = props.TrackColor or (dark and hex('3A3446') or Kit.Color.white), Position = UDim2.fromOffset(O, O), Size = UDim2.new(1, -2 * O, 1, -2 * O), ZIndex = z, Parent = holder })
	w, h = w - 2 * O, h - 2 * O
	if r > 0 then corner(r).Parent = track end
	stroke(Kit.Color.black, O, true, 0, r > 0 and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter).Parent = track
	if not dark then vgradient(hex('FFFFFF'), hex('D5DAE4'), 0.45).Parent = track end
	local fill = blank({ Name = 'Fill', BackgroundTransparency = 0, BackgroundColor3 = Kit.Color.white, Size = UDim2.fromScale(math.clamp(props.Value or 0, 0, 1), 1), ZIndex = z, Parent = track })
	if r > 0 then corner(r).Parent = fill end
	Kit.fillGradient(tone).Parent = fill
	Kit.studs(track, { Width = w, Height = h, Pitch = props.Studs or 15, Color = Kit.Color.black, Transparency = 0.84, Pattern = 'checker', Shade = props.StudShade or 0.6, ZIndex = z })
	local rim = blank({ Name = 'Rim', Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), ZIndex = z, Parent = fill })
	stroke(tone.rim or Kit.Color.white, 2, true, 0.35, Enum.LineJoinMode.Miter).Parent = rim
	-- (round 3) the owner's trough and green fill (a non-green bar keeps its drawn fill)
	if Kit.UseOwnerSkins and props.Skin ~= false then
		Kit.skin(track, 'bar_trough', { Out = O, Height = h + 2 * O })
		if (props.Tone == 'buyGreen' or props.Tone == 'green' or props.Tone == 'lime') then
			track.ClipsDescendants = false
			Kit.skin(fill, 'bar_fill', { Height = h })
		end
	end
	local size = props.TextSize or math.floor(h * 0.62)
	local labels = {}
	local function label(name, text, align, pos, anchor, width)
		labels[name] = Kit.text({
			Name = name, Text = text, TextSize = size, Stroke = Kit.Color.black, StrokeThickness = math.max(2, size * 0.13), TextXAlignment = align,
			AnchorPoint = anchor, Position = pos, Size = UDim2.new(width, -26, 1, -1), ZIndex = z + 1, Parent = holder,
		})
	end
	if props.Left then label('Left', props.Left, Enum.TextXAlignment.Left, UDim2.fromOffset(14, 0), Vector2.zero, 0.62) end
	if props.Right then label('Right', props.Right, Enum.TextXAlignment.Right, UDim2.new(1, -14, 0, 0), Vector2.new(1, 0), 0.62) end
	if props.Text then label('Text', props.Text, Enum.TextXAlignment.Center, UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0), 1) end
	return holder, fill, labels
end

-- (Oct 27) A window like the owner's UI mockup (hood/docs/refs/ui/owner_ui_windows_oct27.png): a bright yellow header
-- bar (lighter on top, a faint tile, a thick dark outline) with the window's icon breaking out over its left end, the
-- title in white Montserrat Black with a thick dark outline and a red square X at its right end, over a dark navy body
-- with a faint blue square tile, a thick outline and rounded corners (Kit.windowBody). No dimming (the world behind is
-- blurred, UIMotion.blur). The window keeps its design size and shrinks to fit small screens (Kit.fitWindow).
-- props: Name, Title, Icon (an icon3d id) or IconNode (any GuiObject), Tone ('headerRed' for a delete / are-you-sure
-- window; any other tone is the yellow bar, like every window of the mockup), Width (940), Height (642), HeaderHeight
-- (Kit.Window.Header), TitleSize (80).
-- Returns panel, well (the body's inside, to fill), closeHit, overlay, header. UIMotion.open/close animate it.
Kit.Window = { Outline = 6, Header = 104, Rim = 3, Inset = 18, TileScale = 0.9 } -- (TileScale: the owner's body tile, round 3)
function Kit.window(root, props)
	local w, h = props.Width or 940, props.Height or 642
	local hh = props.HeaderHeight or Kit.Window.Header
	local O = Kit.Window.Outline
	local overlay = blank({ Name = (props.Name or 'Window') .. 'Overlay', BackgroundTransparency = 1, BackgroundColor3 = Kit.Color.ink, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	-- (Fit holds the window's size and the UIScale that shrinks it onto small screens; the panel inside takes UIMotion's pop)
	local fitter = blank({ Name = 'Fit', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.fromOffset(w, h), ZIndex = 21, Parent = overlay })
	new('UIScale', { Name = 'FitScale', Parent = fitter })
	local panel = blank({ Name = props.Name or 'Window', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = fitter })
	-- the body: navy, opaque, the tile, the outline; it runs up under the header so their corners meet
	local bodyTop = hh - 14 - (props.HeaderOverlap or 0) -- (HeaderOverlap: a taller header over the same body)
	local frame = blank({ Name = 'Frame', Position = UDim2.fromOffset(O, bodyTop + O), Size = UDim2.new(1, -2 * O, 1, -bodyTop - 2 * O), ZIndex = 21, Parent = panel })
	Kit.windowBody(frame, w - 2 * O, h - bodyTop - 2 * O, { Outline = O })
	local inset = Kit.Window.Inset
	local top = hh + 12
	local well = blank({ Name = 'Content', Position = UDim2.fromOffset(inset, top), Size = UDim2.new(1, -2 * inset, 1, -top - inset), ZIndex = 22, Parent = panel })
	-- the header: the yellow bar (the red one for a delete window), a faint tile, no diagonal gloss
	local tone = (props.Tone == 'headerRed' or props.Tone == 'danger') and 'headerRed' or 'headerYellow'
	local header = Kit.block({ Name = 'Header', Tone = tone, Width = w, Height = hh, Outline = O, OutlineColor = Kit.Skin.outline, Radius = Kit.Skin.headerCorner, Studs = 30, StudShade = 0.22, RimWidth = 4, ZIndex = 23 })
	header.Parent = panel
	Kit.headerBand(header, tone)
	-- (round 3) the owner's yellow header fill with its studs, repeated along the bar (our outline and corners kept)
	local headMeta = tone == 'headerYellow' and Kit.UseOwnerSkins and ImageLoader.meta('Ui', 'header')
	if headMeta then Kit.skin(header.Body, 'header', { TileScale = (hh - 2 * O) / headMeta.H, Radius = Kit.Skin.headerCorner, Keep = { Stroke = true } }) end
	local icon = props.IconNode
	local left = 30
	if icon then
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 14, 0.5, -math.floor(hh * 0.12))
		icon.Parent = header
		left = 14 + (props.IconSize or math.floor(hh * 1.1)) + 8
	elseif props.Icon then
		-- the picture breaks out of the bar's left end and over its top edge (Kit.Place.breakout)
		icon = Kit.icon3d(props.Icon, nil, { ZIndex = 27, Place = { Rule = 'breakout', W = w, H = hh } })
		icon.Parent = header
		left = math.floor(Kit.contentRight(icon) + hh * 0.06 - O)
	end
	local titleSize = props.TitleSize or 80
	Kit.text({
		Name = 'Title', Text = props.Title or 'Title', FontFace = Kit.Font.display, TextSize = titleSize, Stroke = Kit.Skin.outline, StrokeThickness = math.max(4, titleSize * 0.09),
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(left, -2), Size = UDim2.new(1, -left - hh, 1, 0), ZIndex = 27, Parent = header.Body,
	})
	local xs = math.floor(hh * 0.7)
	local close, closeHit = Kit.blockButton({ Name = 'Close', Tone = 'closeRed', Width = xs, Height = xs, Text = 'X', TextSize = math.floor(xs * 0.62), Studs = false, Outline = 5, OutlineColor = Kit.Skin.outline, RimWidth = 3, Radius = 8, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(hh - xs) / 2 - 2, 0.5, 0), ZIndex = 27 })
	close.Parent = header
	panel:SetAttribute('DesignW', w)
	panel:SetAttribute('DesignH', h)
	return panel, well, closeHit, overlay, header
end

-- (Oct 27) Paints `frame` as a window body of the mockup: a navy top -> bottom gradient (opaque), the faint blue square
-- tile, a thick near-black outline, rounded corners and a thin light line inside the outline. `w` x `h`: the frame's
-- design size (for the tile). props: Outline (5), OutlineColor, Radius (Kit.Skin.corner), Pitch (the tile's, 28),
-- Transparency (0), Top / Base (Color3s: another body colour), Tile (false: none). Returns frame.
function Kit.windowBody(frame, w, h, props)
	props = props or {}
	local S = Kit.Skin
	local r = props.Radius or S.corner
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BackgroundColor3 = Kit.Color.white
	new('UIGradient', { Name = 'BodyGradient', Rotation = 90, Color = ColorSequence.new(props.Top or S.bodyTop, props.Base or S.bodyBase), Parent = frame })
	if r > 0 then corner(r).Parent = frame end
	stroke(props.OutlineColor or S.outline, props.Outline or 5, true, 0, r > 0 and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter).Parent = frame
	if props.Tile ~= false then
		local tile = Kit.studs(frame, { Width = w, Height = h, Pitch = props.Pitch or 28, Tint = S.tile, Color = S.tile, Transparency = 0.9, Shade = S.tileShade, MinAlpha = 0.84, Filled = true, ZIndex = frame.ZIndex })
		if tile and tile:IsA('ImageLabel') and r > 0 then corner(r).Parent = tile end
	end
	local rw = 2
	local rim = blank({ Name = 'Rim', Position = UDim2.fromOffset(rw, rw), Size = UDim2.new(1, -2 * rw, 1, -2 * rw), ZIndex = frame.ZIndex, Parent = frame })
	if r > rw then corner(r - rw).Parent = rim end
	stroke(S.rim, rw, true, 0.25, r > rw and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter).Parent = rim
	-- (round 3) the owner's body: his navy square tile, repeated (our outline, corners and light inner line kept)
	if Kit.UseOwnerSkins and props.Tile ~= false and not props.Top then
		Kit.skin(frame, 'body_tile', { TileScale = Kit.Window.TileScale, Radius = r, Keep = { Stroke = true, Rim = true } })
	end
	return frame
end

-- (Oct 27) The mockup's header bars are lighter on their top half: a soft band over a Kit.block's face, fading out toward
-- its middle. tone: the block's (its rim colour tints the band).
function Kit.headerBand(block, tone)
	local body = block and block:FindFirstChild('Body')
	if not body then return end
	local t = toneOf(tone)
	local band = blank({ Name = 'TopBand', BackgroundTransparency = 0, BackgroundColor3 = t.rim or Kit.Color.white, Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.46, 0), ZIndex = body.ZIndex, Parent = body })
	corner(math.max(2, Kit.Skin.headerCorner - 4)).Parent = band
	new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }), Parent = band })
	return band
end

-- (Oct 27) A row of the mockup's pill tabs: dark navy pills with white outlined labels, the open one bright blue. Each
-- pill is as wide as its label needs, the row scaled to `Width`. props: Items { { Id, Text } }, Width (600), Height (42),
-- Gap (8), TextSize (Height * 0.48), Selected (an Id), Position, AnchorPoint, ZIndex, Name, OnSelect(id), Wire
-- (function(pill, fn): how a pill takes taps, e.g. UIMotion.button; default its Hit's Activated), OnTone and OnPiece (the
-- open pill's tone and skin piece: 'tabBlue' / 'tab_on_blue'; the Shop's is gold, as on the owner's mockup).
-- Returns holder, set(id) (paints the open one, no callback), pills { [id] = holder }.
function Kit.tabs(parent, props)
	local items = props.Items or {}
	local h, gap = props.Height or 42, props.Gap or 8
	local w = props.Width or 600
	local z = props.ZIndex or 1
	local size = props.TextSize or math.floor(h * 0.48)
	local holder = blank({ Name = props.Name or 'Tabs', Size = UDim2.fromOffset(w, h), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z, Parent = parent })
	local want, total = {}, 0
	for i, it in items do
		want[i] = Kit.textWidth(it.Text or it.Id, size) + 30
		total += want[i]
	end
	local room = w - gap * math.max(0, #items - 1)
	local k = total > 0 and room / total or 1
	local pills = {}
	local function paint(pill, on)
		local tone = Kit.Tone[on and (props.OnTone or 'tabBlue') or 'navyRow']
		local body = pill:FindFirstChild('Body')
		local g = body and body:FindFirstChildOfClass('UIGradient')
		if g then g.Color = ColorSequence.new(tone.top, tone.base) end
		local rim = body and body:FindFirstChild('Rim')
		local rs = rim and rim:FindFirstChildOfClass('UIStroke')
		if rs then rs.Color = tone.rim end
		local sk = body and body:FindFirstChild('Skin')
		local piece = on and (props.OnPiece or 'tab_on_blue') or 'tab_off'
		if sk and sk:GetAttribute('Piece') ~= piece then Kit.reskin(sk, piece) end
		pill:SetAttribute('On', on)
	end
	local function set(id)
		for key, p in pills do paint(p, key == id) end
		holder:SetAttribute('Selected', id)
	end
	local x = 0
	for i, it in items do
		local pw = math.floor(want[i] * k)
		local pill, hit = Kit.blockButton({ Name = 'Tab_' .. it.Id, Tone = 'navyRow', Width = pw, Height = h, Text = it.Text or it.Id, TextSize = size, Studs = false, Outline = 3, OutlineColor = Kit.Skin.outline, RimWidth = 2, Radius = math.floor(h * 0.28), Position = UDim2.fromOffset(x, 0), ZIndex = z })
		pill.Parent = holder
		pills[it.Id] = pill
		x += pw + gap
		local function pick()
			set(it.Id)
			if props.OnSelect then props.OnSelect(it.Id) end
		end
		if props.Wire then props.Wire(pill, pick) else hit.Activated:Connect(pick) end
	end
	if #items > 0 then set(props.Selected or items[1].Id) end
	return holder, set, pills
end

-- Shrinks a Kit.window to fit the screen (gui's AbsoluteSize): the window keeps its design size where it fits and
-- scales down (never up) with a margin where it doesn't, e.g. on phones.
function Kit.fitWindow(panel, abs)
	local fitter = panel.Parent
	local scale = fitter and fitter:FindFirstChild('FitScale')
	if not scale or abs.X < 1 or abs.Y < 1 then return end
	local k = Kit.scaleFor(abs)
	local rootW, rootH = abs.X / k, abs.Y / k
	local w = panel:GetAttribute('DesignW') or fitter.Size.X.Offset
	local h = panel:GetAttribute('DesignH') or fitter.Size.Y.Offset
	scale.Scale = math.min(1, (rootW - 24) / w, (rootH - 10) / h)
end

-- (brief 27) The Store like the user's video A: ONE scrolling window and no header bar. A big "Shop" title with its basket
-- floats over the window's top-left edge and a red square X over its top-right corner; a thin frame (a dark line with a
-- light line inside it, rounded corners) holds a see-through dark body (the world, blurred by UIMotion.blur, shows
-- through) with a faint stud tile. props: Name, Title ('Shop'), Icon (an icon3d id: the basket), Width / Height (the
-- body, Kit.ShopWindow.W / H), TitleSize. Returns { Overlay, Fit, Panel (what UIMotion.open pops), Frame (the body), List
-- (the ScrollingFrame to fill, ListW wide), Close (the X's hit), CloseButton, Title, Icon }. Kit.fitWindow(out.Panel, abs)
-- shrinks the whole of it (title included) onto small screens. Measured on video A at 1280 wide: the window ~56% of the
-- screen's width and ~61% of its height, the title's cap ~7% of the height, the X ~60 px.
Kit.ShopWindow = { W = 800, H = 474, Top = 58, Corner = 16, Line = 3, Light = 4, Pad = 12, Bar = 7 }
function Kit.shopWindow(root, props)
	props = props or {}
	local SW = Kit.ShopWindow
	local w, h, top = props.Width or SW.W, props.Height or SW.H, SW.Top
	local overlay = blank({ Name = (props.Name or 'Shop') .. 'Overlay', Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local fitter = blank({ Name = 'Fit', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h + top), ZIndex = 21, Parent = overlay })
	new('UIScale', { Name = 'FitScale', Parent = fitter })
	local panel = blank({ Name = props.Name or 'Shop', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = fitter })
	-- the body: a near-black at half strength, the dark line round it, the light line inside that
	local frame = blank({ Name = 'Frame', BackgroundTransparency = 0.5, BackgroundColor3 = hex('0C0E16'), Position = UDim2.fromOffset(0, top), Size = UDim2.fromOffset(w, h), ZIndex = 21, Parent = panel })
	corner(SW.Corner).Parent = frame
	stroke(Kit.Color.black, SW.Line, true).Parent = frame
	local rim = blank({ Name = 'Rim', Position = UDim2.fromOffset(SW.Light, SW.Light), Size = UDim2.new(1, -2 * SW.Light, 1, -2 * SW.Light), ZIndex = 21, Parent = frame })
	corner(SW.Corner - SW.Light).Parent = rim
	stroke(hex('DCE0EC'), SW.Light, true, 0.15).Parent = rim
	if Kit.studsAreCheap() then
		-- (the faint stud tile of the reference's body: one tiled image, its corners rounded with the frame)
		local tile = Kit.studs(frame, { Width = w, Height = h, Pitch = 30, Color = Kit.Color.white, Transparency = 0.9, Shade = 0.1, MinAlpha = 0.86, ZIndex = 21 })
		if tile then corner(SW.Corner).Parent = tile end
	end
	local pad = SW.Pad
	-- (the list's own scroll bar is invisible but still takes drags; a drawn one shows where you are, over the cards' margin)
	local list = new('ScrollingFrame', {
		Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(pad, top + pad), Size = UDim2.fromOffset(w - 2 * pad, h - 2 * pad), ZIndex = 24,
		ScrollBarThickness = SW.Bar, ScrollBarImageColor3 = Kit.Color.white, ScrollBarImageTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.None, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel,
	})
	local trackH = h - 2 * pad - 8
	local track = blank({ Name = 'ScrollTrack', BackgroundTransparency = 0.6, BackgroundColor3 = Kit.Color.black, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(w - pad + 2, top + pad + 4), Size = UDim2.fromOffset(SW.Bar, trackH), ZIndex = 30, Parent = panel })
	corner(UDim.new(0.5, 0)).Parent = track
	local thumb = blank({ Name = 'Thumb', BackgroundTransparency = 0.08, BackgroundColor3 = hex('E8ECF4'), Size = UDim2.new(1, 0, 0, 40), ZIndex = 31, Parent = track })
	corner(UDim.new(0.5, 0)).Parent = thumb
	local contentH = h
	-- where the drawn bar's thumb sits: its height is the share of the list in view, its place the scroll
	local function placeThumb()
		local view = list.Size.Y.Offset
		local th = math.clamp(trackH * view / math.max(view, contentH), 36, trackH)
		local maxY = math.max(1, contentH - view)
		local f = math.clamp(list.CanvasPosition.Y / maxY, 0, 1)
		thumb.Size = UDim2.new(1, 0, 0, th)
		thumb.Position = UDim2.fromOffset(0, math.floor(f * (trackH - th) + 0.5))
		track.Visible = contentH > view + 1
	end
	list:GetPropertyChangedSignal('CanvasPosition'):Connect(placeThumb)
	-- the floating title and its basket, over the top-left edge
	local titleSize = props.TitleSize or 80
	local iconSize = math.floor(titleSize * 1.2)
	local icon = Kit.icon3d(props.Icon or 'Shop', iconSize, { ZIndex = 31, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(iconSize * 0.36, top - 12), Rotation = -6 })
	icon.Parent = panel
	local title = Kit.text({
		Name = 'Title', Text = props.Title or 'Shop', FontFace = Kit.Font.heading, TextSize = titleSize, Stroke = Kit.Color.black, StrokeThickness = math.max(4, titleSize * 0.075),
		-- (its box hugs the letters, so it never sits over the list's first line)
		TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(math.floor(iconSize * 0.82), top - 14), Size = UDim2.fromOffset(w * 0.6, math.floor(titleSize * 0.82)), ZIndex = 32, Parent = panel,
	})
	-- the red square X over the top-right corner
	local xs = props.CloseSize or 64
	local close, closeHit = Kit.blockButton({ Name = 'Close', Tone = 'rose', Width = xs, Height = xs, Text = 'X', TextSize = math.floor(xs * 0.66), Studs = false, Outline = 4, RimWidth = 3, Radius = 8, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w - 10, top + 4), ZIndex = 32 })
	close.Parent = panel
	panel:SetAttribute('DesignW', w)
	panel:SetAttribute('DesignH', h + top)
	return {
		Overlay = overlay, Fit = fitter, Panel = panel, Frame = frame, List = list, ListW = w - 2 * pad, Close = closeHit, CloseButton = close, Title = title, Icon = icon,
		-- the list's content height (the caller knows it: its blocks' sizes) and the bar's width (thicker on phones)
		SetContent = function(height) contentH = height; placeThumb() end,
		SetBar = function(width)
			track.Size = UDim2.fromOffset(width, trackH)
			list.ScrollBarThickness = width
		end,
		PlaceThumb = placeThumb,
	}
end

-- (brief 27, CRITIC5) Video A's white sunburst behind a card's art: `n` soft rays (bars through the centre, faded at the
-- middle and the ends) at `alpha`, static. A `size` square. props: Position, AnchorPoint, ZIndex, Rays (14), Alpha (0.15),
-- Color.
function Kit.sunburst(size, props)
	props = props or {}
	local z = props.ZIndex or 1
	local holder = blank({ Name = 'Sunburst', Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = z })
	local bars = math.floor((props.Rays or 14) / 2)
	local a = 1 - (props.Alpha or 0.15)
	for i = 1, bars do
		local bar = blank({ Name = 'Ray' .. i, BackgroundTransparency = 0, BackgroundColor3 = props.Color or Kit.Color.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, math.max(4, math.floor(size * 0.09)), 1, 0), Rotation = (i - 1) * 180 / bars, ZIndex = z, Parent = holder })
		new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, a), NumberSequenceKeypoint.new(0.38, a), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.62, a), NumberSequenceKeypoint.new(0.92, a), NumberSequenceKeypoint.new(1, 1) }), Parent = bar })
	end
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
