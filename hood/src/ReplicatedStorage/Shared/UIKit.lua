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
-- Kit.window (studded coloured header with a big 3D icon, title and a red X over a dark see-through body),
-- Kit.bar (studded progress bar), Kit.robux / Kit.robuxButton (the green Robux price button) and Kit.studs.
-- Used by HoodClient/HUD, Store, Shoes, Goals and Waves; UIKitDemo builds sample screens with the older pieces.
local Kit = {}

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
	-- (brief 18) The reference UI (user_26-28 and the video) is set in Gotham Black: flat-cut terminals, a straight R leg,
	-- a flagged 1, mixed case. Every label, number and title uses it; `italic` is the Store's "~Gamepass~"; `body` the
	-- few small detail lines.
	display = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy),
	italic = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	loud = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy),
	number = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy),
	body = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold),
	tag = Font.new('rbxasset://fonts/families/PermanentMarker.json'),
}
Kit.Text = { title = 40, cta = 30, button = 24, label = 18, small = 15 } -- at the 1280x720 design size

-- (brief 19 r7) The reference hides Roblox's player list (nothing at its top right). Ours is the user's call: flip this to
-- true and HUD.client hides it (StarterGui:SetCoreGuiEnabled(PlayerList, false)); the HUD's layout is right either way.
Kit.HidePlayerList = false
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

---------------------------------------------------------------------------------------------- 3D icons
-- Chunky 3D icons made in Blender live in Shared/Models/IconModels (build(id, scale) -> Model centred on its
-- origin, front facing -Z; Images[id] = uploaded render id or ''). Kit.icon3d shows, in order of preference:
-- the uploaded render (an ImageLabel, cheapest), the live model in a ViewportFrame, or an emoji, so screens
-- work before the module or the uploads exist.
Kit.IconEmoji = {
	Shop = '🛍️', Rebirth = '🔄', Rewards = '🎁', PVP = '👊', Evolve = '⬆️', Cash = '💵', Power = '💪', Trophy = '🏆', Gun = '🔫',
}
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
-- The uploaded render of an icon ('' when none yet).
function Kit.iconImage(id)
	local models = Kit.iconModels()
	local image = models and type(models.Images) == 'table' and models.Images[id]
	return type(image) == 'string' and image or ''
end
-- Whether IconModels can show `id` at all: an uploaded image or a live model.
function Kit.hasIcon(id)
	local models = Kit.iconModels()
	if not models then return false end
	return Kit.iconImage(id) ~= '' or (type(models.Meta) == 'table' and models.Meta[id] ~= nil)
end
-- The first of the ids IconModels can show (e.g. Kit.iconOr('DoubleCash', 'Cash')), else the last one.
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
-- The stand-ins: the live 3D model for an icon, the frame glyph for the Robux mark, round blobs for a splat. Where
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

-- Cartoon light for ViewportFrames: a key light from the camera's upper left. (brief 19 r7) Ambient 150 + LightColor 255
-- is what the user's Studio frame user_24 shows the live icons with: their own colours (the yellow glove's median at 0.86
-- of its Color3, highlights at 0.96, shade at 0.62). (Round 1 dimmed it to 128 + 235 from an offline estimate that
-- turned out to be ~3x too dark; Studio is the evidence.)
function Kit.lightViewport(vp, camCFrame)
	vp.Ambient = Color3.fromRGB(150, 150, 162)
	vp.LightColor = Color3.fromRGB(255, 250, 238)
	vp.LightDirection = camCFrame:VectorToWorldSpace(Vector3.new(0.55, -1, -0.75))
end

-- Points a ViewportFrame camera at model so it just fills the frame: every corner of its bounding box is
-- projected and the camera backs off until all of them fit (with a small margin).
-- props: Direction (Vector3 from the model toward the camera) or Yaw / Pitch in degrees (orbit away from the
-- front view; the front faces -Z), Fov (vertical), Aspect (frame width / height, default 1), Zoom (>1 = closer),
-- Focus (a Vector3 to aim at instead of the bounding-box centre).
-- (brief 22 r2) props.Tight: frame the VISIBLE parts' corners instead of the bounding box, centred on their silhouette.
-- The box fit leaves a live icon small and off-centre when the model carries an invisible root / fit part or is seen
-- across its diagonal (a live shoe filled ~0.73 of its square and ran off the bottom); this fills it the way ICONS'
-- renders do (Margin, default 1.06: how much room is left round the silhouette). Returns the camera CFrame and fov,
-- so an offline renderer can use exactly the same view (Kit.frameFor).
function Kit.frameFor(model, props)
	props = props or {}
	local fov = props.Fov or 30
	local orbit = CFrame.Angles(0, math.rad(props.Yaw or 0), 0) * CFrame.Angles(math.rad(props.Pitch or 0), 0, 0)
	local back = props.Direction and props.Direction.Unit or orbit:VectorToWorldSpace(Vector3.new(0, 0, -1)) -- from the focus toward the camera
	local up = (Vector3.yAxis - back * back:Dot(Vector3.yAxis)).Unit
	local right = back:Cross(up)
	local tanV = math.tan(math.rad(fov / 2))
	local tanH = tanV * (props.Aspect or 1)
	local points = {}
	if props.Tight then
		for _, d in model:GetDescendants() do
			if d:IsA('BasePart') and d.Transparency < 0.99 then
				local cf, h = d.CFrame, d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							table.insert(points, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
						end
					end
				end
			end
		end
	end
	local focus = props.Focus
	if #points == 0 then
		local box, ext = model:GetBoundingBox()
		focus = focus or box.Position
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					table.insert(points, box:PointToWorldSpace(ext * Vector3.new(sx, sy, sz)))
				end
			end
		end
	elseif not focus then
		-- the middle of the silhouette across the view (and of the depth)
		local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		for _, p in points do
			for i, q in { p:Dot(right), p:Dot(up), p:Dot(back) } do
				lo[i], hi[i] = math.min(lo[i], q), math.max(hi[i], q)
			end
		end
		focus = right * (lo[1] + hi[1]) / 2 + up * (lo[2] + hi[2]) / 2 + back * (lo[3] + hi[3]) / 2
	end
	local dist = 0
	for _, p in points do
		local v = p - focus
		dist = math.max(dist, v:Dot(back) + math.max(math.abs(v:Dot(right)) / tanH, math.abs(v:Dot(up)) / tanV))
	end
	dist = dist * (props.Margin or 1.06) / (props.Zoom or 1)
	return CFrame.lookAt(focus + back * dist, focus), fov
end
function Kit.frameModel(vp, model, props)
	local cf, fov = Kit.frameFor(model, props)
	local cam = vp:FindFirstChildOfClass('Camera') or new('Camera', { Parent = vp })
	cam.FieldOfView = fov
	cam.CFrame = cf
	vp.CurrentCamera = cam
	Kit.lightViewport(vp, cam.CFrame)
	return cam
end

-- A transparent ViewportFrame showing model (parented into it), framed with Kit.frameModel.
-- size: a number (square) or a Vector2 (width, height).
function Kit.viewport(model, size, props)
	props = table.clone(props or {})
	local w, h = size, size
	if typeof(size) == 'Vector2' then w, h = size.X, size.Y end
	props.Aspect = props.Aspect or w / h
	local vp = new('ViewportFrame', {
		Name = props.Name or 'Model3D', BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 1,
	})
	model.Parent = vp
	Kit.frameModel(vp, model, props)
	return vp
end

-- A 3D icon by IconModels id (Shop, Rebirth, Rewards, PVP, Evolve, Cash, Power, Trophy, Gun), seen from the
-- same side as its Blender render (IconModels.View) so live icons and uploaded images match.
-- props: Position, AnchorPoint, ZIndex, Yaw / Pitch (instead of the render's view), Zoom, Fallback (text to
-- show when nothing else exists).
-- (brief 22 r2) A live icon is framed on its visible silhouette (Kit.frameFor, Tight) with IconMargin round it, so with
-- its 1.09x outline copy it fills ~89% of the square like ICONS' renders. LiveZoom (>1 closer) is what is left per id
-- after that (Shoe_ / Box_ ids by prefix): World and Rebirth are drawn smaller, like their padded renders.
Kit.IconMargin = 1.2
-- (measured against ICONS' round-3 renders and live models: each live icon's silhouette, outline copy included, vs
-- its PNG's; clamped to 0.9-1.5. The potions, BoostBundle and Cash/Power piles: ICONS' values for their rebuilt live models)
Kit.LiveZoom = {
	Arrow = 1.41, AutoFight = 1.09, Backpack = 1.07, BasketRed = 0.9, BoostBundle = 1.07, Box_ = 1.09, Cash = 1.13,
	CashLarge = 1.03, CashMedium = 1.02, CashSmall = 1.05, CashTiny = 1.07, DoubleCash = 1.13, DoublePower = 1.07,
	Favorite = 1.06, Muscle = 1.06, PVP = 0.92, PotionGold = 1.11, PotionRed = 1.11, Power = 1.06, PowerLarge = 1.1,
	PowerMedium = 1.05, PowerPack1 = 1.06, PowerPack2 = 1.1, PowerPack3 = 1.16, PowerSmall = 1.05, PowerTiny = 1.11,
	Quest = 1.07, Rebirth = 0.94, RebirthSkip = 0.94, Robux = 1.03, Search = 1.09, Shield = 0.92, ShoeBox = 1.06,
	ShoePile = 0.9, Shoe_ = 1.27, Skull = 1.16, Sneaker = 1.05, Trophy = 0.92, VIP = 0.9, World = 1.43, XP = 0.92,
}
function Kit.liveZoom(id)
	return Kit.LiveZoom[id] or Kit.LiveZoom[string.match(id, '^(%a+_)') or ''] or nil
end
-- (brief 22) a live Shoe_<id> (IconModels: one right shoe) and Box_<id> seen exactly like ICONS' renders (their view in
-- Roblox space, model to camera): the shoe from above with the toe and laces at the front-left, the box from the
-- front-right
Kit.ShoeView = Vector3.new(-0.665, 0.311, -0.68)
Kit.BoxView = Vector3.new(0.36, 0.27, -0.89)
-- The camera props Kit.icon3d gives a live id (an offline renderer passes them to Kit.frameFor to draw the same view).
function Kit.iconLook(id, props, models)
	props = props or {}
	models = models or Kit.iconModels()
	local view = (string.match(id, '^Shoe_') and Kit.ShoeView) or (string.match(id, '^Box_') and Kit.BoxView) or (not (props.Yaw or props.Pitch) and models and typeof(models.View) == 'Vector3' and models.View) or nil
	return { Direction = view, Yaw = props.Yaw or 18, Pitch = props.Pitch or 19, Zoom = props.Zoom or Kit.liveZoom(id), Tight = true, Margin = Kit.IconMargin, ZIndex = props.ZIndex or 1 }
end
-- The live stand-in of icon `id` in holder: IconModels' model in a ViewportFrame over its outline copy (at holder's
-- ZIndex, the model one over), else an emoji. `locked` draws both black (InventoryKit's silhouettes). Every part it
-- adds carries the attribute LiveIcon, so a late upload can take them away again (Kit.icon3d's restore).
local function liveIcon(holder, id, size, props, locked)
	local z = holder.ZIndex
	local models = Kit.iconModels()
	if models and type(models.build) == 'function' then
		local ok, model = pcall(models.build, id, 1)
		if ok and typeof(model) == 'Instance' then
			local look = Kit.iconLook(id, props, models)
			look.ZIndex = z
			-- (brief 18) The reference's icons carry a thick dark outline (so do the Blender renders): a black copy of the
			-- live model, a little bigger, behind it. One extra ViewportFrame per icon; Outline = false skips it (brief 19:
			-- and icons under 34 px, where it would be a 1-2 px line for twice the parts).
			if props.Outline ~= false and size >= 34 and not locked then
				local edge = Kit.viewport(model:Clone(), size, look)
				edge.Name = 'Outline'
				edge.ImageColor3 = Kit.hex('0C0A1E') -- (brief 22: the near-black of ICONS' round-2 outlines)
				edge.AnchorPoint = Vector2.new(0.5, 0.5)
				edge.Position = UDim2.fromScale(0.5, 0.5)
				edge.Size = UDim2.fromScale(1.09, 1.09)
				edge:SetAttribute('LiveIcon', true)
				edge.Parent = holder
			end
			local vp = Kit.viewport(model, size, look)
			vp.Size = UDim2.fromScale(1, 1)
			vp.ZIndex = z + 1 -- (over its outline copy)
			if locked then vp.ImageColor3 = Color3.new(0, 0, 0) end
			vp:SetAttribute('LiveIcon', true)
			vp.Parent = holder
			return
		end
	end
	local t = Kit.text({ Name = 'Fallback', Text = props.Fallback or Kit.IconEmoji[id] or '?', FontFace = Kit.Font.body, TextSize = math.floor(size * 0.8), ZIndex = z, Parent = holder })
	t:SetAttribute('LiveIcon', true)
end
function Kit.icon3d(id, size, props)
	props = props or {}
	local holder = blank({ Name = 'Icon3D_' .. id, Size = UDim2.fromOffset(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex or 1 })
	local z = props.ZIndex or 1
	local image = Kit.iconImage(id)
	if image ~= '' then
		-- (brief 19) ICONS' uploaded render: one ImageLabel, the outline and gloss baked in. ImageColor3 / Rotation from props.
		local img = new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = props.Color or Color3.new(1, 1, 1), Rotation = props.Rotation or 0, ZIndex = z, Parent = holder })
		img:SetAttribute('PreviewImage', 'icon3d:' .. id) -- the offline previewer draws hood/art/icons3d/<id>.png here
		-- (brief 23) an upload that never arrives (in review, rejected) swaps to the live model; back if it comes later
		Kit.watchImage(img, function()
			img.Visible = false
			holder:SetAttribute('PreviewImage', 'icon3d:' .. id)
			liveIcon(holder, id, size, props, holder:GetAttribute('PreviewSilhouette') == true or img.ImageColor3 == Color3.new(0, 0, 0))
		end, function()
			for _, d in holder:GetChildren() do
				if d:GetAttribute('LiveIcon') then d:Destroy() end
			end
			holder:SetAttribute('PreviewImage', nil)
			img.Visible = true
		end)
		return holder
	end
	holder:SetAttribute('PreviewImage', 'icon3d:' .. id) -- the offline previewer draws the Blender render here
	liveIcon(holder, id, size, props, false)
	return holder
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
		local img = new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, ImageColor3 = (kind == nil and color) or Kit.Color.white, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
		img:SetAttribute('PreviewImage', 'ui:' .. file)
		-- (brief 23) the blobs while the uploaded texture doesn't load (Kit.watchImage)
		Kit.watchImage(img, function()
			img.Visible = false
			blobs(img.ImageTransparency)
		end, function()
			for _, d in holder:GetChildren() do
				if d ~= img then d:Destroy() end
			end
			img.Visible = true
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
		Kit.studs(body, { Width = w - 2 * O, Height = h - 2 * O, Pitch = props.Studs or 15, Color = props.StudColor or tone.lip, Transparency = props.StudTransparency or 0.66, Pattern = pattern ~= 'plain' and pattern or nil, Shade = props.StudShade or 0.8, Sparse = props.StudSparse, ZIndex = z + 1 })
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
	return holder, hit
end

-- The HUD's square action button (the reference's Store / World / Rebirth ... column): a studded block with a big
-- 3D icon filling most of it and popping out of its top edge, and an outlined caption low on its face. props: Name,
-- Tone, Width, Height, Position, AnchorPoint, ZIndex, Text, TextSize, LabelY (the caption's centre as a fraction of the
-- height, 0.82), Icon (an icon3d id) or IconNode (any GuiObject), IconSize, IconX (px off centre), Pop (px the icon
-- rises over the top edge). The hit area grows to cover the icon. Returns holder, hit, icon, caption.
function Kit.actionButton(props)
	local w, h = props.Width or 81, props.Height or 81
	local pop = props.Pop or 12
	local holder, hit = Kit.blockButton({ Name = props.Name, Tone = props.Tone, Width = w, Height = h, Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex, Studs = props.Studs or 15, RimWidth = props.RimWidth or 3, InnerLine = props.InnerLine ~= false })
	local z = (props.ZIndex or 1) + 3
	local size = props.IconSize or math.floor(math.min(w, h) * 0.88)
	local icon = props.IconNode or Kit.icon3d(props.Icon or 'Shop', size, {})
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, props.IconX or 0, 0, -pop)
	local base = icon.ZIndex
	icon.ZIndex = z
	for _, d in icon:GetDescendants() do
		if d:IsA('GuiObject') then d.ZIndex = z + math.max(0, d.ZIndex - base) end -- (keeps a 3D icon over its outline)
	end
	icon.Parent = holder.Body
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

-- The width of a line of display text, for labels laid out next to each other without AutomaticSize: Gotham Black's
-- advance per character in em (measured on its open twin, Montserrat Black), 0.6 em for anything else, plus a stroke's
-- allowance. Rich-text tags are skipped.
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
	local text = tostring(price)
	local onlyW, priceW = Kit.textWidth('ONLY', size), Kit.textWidth(text, size)
	local glyph = math.floor(size * 1.25) -- (the reference's mark is as tall as the outlined letters)
	local row = blank({ Name = props.Name or 'Only', AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5), Position = props.Position or UDim2.new(), Size = UDim2.fromOffset(onlyW + glyph + 2 + priceW, size + 6), ZIndex = z })
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
	local text = tostring(p.Price or '?')
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
	local track = blank({ Name = 'Track', BackgroundTransparency = dark and 0.25 or 0, BackgroundColor3 = dark and hex('3A3446') or Kit.Color.white, Position = UDim2.fromOffset(O, O), Size = UDim2.new(1, -2 * O, 1, -2 * O), ZIndex = z, Parent = holder })
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

-- A window like the reference's Store and Rebirth (user_27/28, measured at their size): a studded header in the
-- window's colour (a big 3D icon, the title in Gotham Black, a red-pink square X) over a grey see-through body with a
-- light inner band, both with a thick black outline; no dimming (the world behind is blurred, UIMotion.blur). The
-- window keeps the reference's size (it covers most of the screen) and shrinks to fit small screens (Kit.fitWindow).
-- props: Name, Title, Icon (an icon3d id) or IconNode (any GuiObject), Tone (the header), Width (940), Height (642),
-- HeaderHeight (120), TitleSize (80).
-- Returns panel, well (the body's inside, to fill), closeHit, overlay, header. UIMotion.open/close animate it.
Kit.Window = { Outline = 10, Header = 120, Rim = 8, Inset = 18 }
function Kit.window(root, props)
	local w, h = props.Width or 940, props.Height or 642
	local hh = props.HeaderHeight or Kit.Window.Header
	local O, RIM = Kit.Window.Outline, Kit.Window.Rim
	local overlay = blank({ Name = (props.Name or 'Window') .. 'Overlay', BackgroundTransparency = 1, BackgroundColor3 = Kit.Color.ink, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	-- (Fit holds the window's size and the UIScale that shrinks it onto small screens; the panel inside takes UIMotion's pop)
	local fitter = blank({ Name = 'Fit', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.fromOffset(w, h), ZIndex = 21, Parent = overlay })
	new('UIScale', { Name = 'FitScale', Parent = fitter })
	local panel = blank({ Name = props.Name or 'Window', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = fitter })
	-- the body: grey and see-through, with a light band inside its outline
	local bodyTop = hh - 6 - (props.HeaderOverlap or 0) -- (HeaderOverlap: a taller header over the same body, user_28's)
	-- (the reference's body darkens what's behind it by about a third and keeps it visible: a near-black at 0.68)
	local frame = blank({ Name = 'Frame', BackgroundTransparency = 0.58, BackgroundColor3 = hex('12141C'), Position = UDim2.fromOffset(O, bodyTop + O), Size = UDim2.new(1, -2 * O, 1, -bodyTop - 2 * O), ZIndex = 21, Parent = panel })
	corner(5).Parent = frame
	stroke(Kit.Color.black, O, true).Parent = frame
	local band = blank({ Name = 'Rim', Position = UDim2.fromOffset(RIM, RIM), Size = UDim2.new(1, -2 * RIM, 1, -2 * RIM), ZIndex = 21, Parent = frame })
	stroke(Kit.Color.white, RIM, true, 0.5).Parent = band -- (brief 22, UICRITIC2: a translucent white band, ~50%, like the reference's)
	local inset = Kit.Window.Inset
	local well = blank({ Name = 'Content', Position = UDim2.fromOffset(inset, bodyTop + inset), Size = UDim2.new(1, -2 * inset, 1, -bodyTop - 2 * inset), ZIndex = 22, Parent = panel })
	-- the header
	-- (brief 19 r7) the header's studs are the reference's raised / recessed checker, at its strongest; the diagonal gloss
	-- only where the reference has it (the Store's; props.Gloss = false for Rebirth and Rewards)
	local header = Kit.block({ Name = 'Header', Tone = props.Tone or 'headerGold', Width = w, Height = hh, Outline = O, Radius = 5, Studs = 34, StudPattern = 'checker', StudShade = 0.9, Gloss = props.Gloss ~= false, RimWidth = 6, ZIndex = 23 })
	header.Parent = panel
	local iconSize = props.IconSize or math.floor(hh * 0.95)
	local icon = props.IconNode or (props.Icon and Kit.icon3d(props.Icon, iconSize, { ZIndex = 27 }))
	if icon then
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 14, 0.5, 0)
		icon.Parent = header
	end
	local left = icon and (14 + iconSize + 8) or 30
	local titleSize = props.TitleSize or 80
	Kit.text({
		Name = 'Title', Text = props.Title or 'Title', TextSize = titleSize, Stroke = Kit.Color.black, StrokeThickness = math.max(4, titleSize * 0.075),
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -left - hh, 1, 0), ZIndex = 27, Parent = header.Body,
	})
	local xs = math.floor(hh * 0.68)
	local close, closeHit = Kit.blockButton({ Name = 'Close', Tone = 'rose', Width = xs, Height = xs, Text = 'X', TextSize = math.floor(xs * 0.6), Studs = false, Outline = 5, RimWidth = 3, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(hh - xs) / 2 - 6, 0.5, 0), ZIndex = 27 })
	close.Parent = header
	panel:SetAttribute('DesignW', w)
	panel:SetAttribute('DesignH', h)
	return panel, well, closeHit, overlay, header
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
