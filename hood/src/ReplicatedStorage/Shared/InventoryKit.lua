-- InventoryKit (brief 22, UI4): the inventory window's rules and widgets, after the user's reference inventory
-- (ref22_pets_window: a cyan studded header with a backpack, the title, a "Search..." box and a red X; blue studded tabs
-- down its left side; a dark see-through studded body with "Equipped n/3", pets over paint splats and a stacked grid;
-- an "Index" button under it and a delete / favourite bar). HoodClient/Inventory.client and HoodClient/World.client
-- build their windows from it; UIKit is only read.
--
-- Pure (no Instances, unit tested in ServerStorage/UnitTest/Cases/Inventory_Test):
--   InventoryKit.Tabs, tabId(name)          the four tabs (Guns, Your Shoes, Items, Boxes) and a name -> tab id
--   matches(name, query)                    the Search box's rule: every word of the query is in the name (any case)
--   stack(rack)                             your pairs, one entry per shoe: { Id, Copies, On }, best first
--   search(list, query, nameOf)             the entries whose name matches
--   index(world, rack)                      every shoe of a world's boxes, box by box, owned or not, and the counts
--   boosts(queue, now, partyEnds)           the timed boosts running and waiting (StoreService's BoostQueue), time left
--   timeText(seconds)                       "9:07", "1:02:03"
--   passes(attributes)                      the Store's game passes with whether you own each
--   guns(ownedText, equipped)               every gun with its state (Equipped / Owned / Locked)
--   worlds(stagesCleared)                   the World window's cards: World 1 (Lobby, your furthest stage), 2..5 soon
-- Client (Instances):
--   open(tab) / openWorld()                 fire PlayerGui.HoodInventory.Open / HoodWorld.Open (the HUD's squares do)
--   Layout, Tone                            the measured sizes (design px; 1 design px = 1.8 reference px) and colours
--   splat, shoeIcon, gunIcon, boxIcon, icon, label, slot, divider, frame
local InventoryKit = {}

local Shared = script.Parent
local Kit = require(Shared.UIKit)
local Shoes = require(Shared.Config.Shoes)
local ShoeRules = require(Shared.ShoeRules)
local Products = require(Shared.Config.Products)
local Guns = require(Shared.Config.Guns)

local hex = Kit.hex
local px = UDim2.fromOffset

---------------------------------------------------------------------------------------------- pure rules
-- The tabs, top to bottom (the reference's Heros / Your Pets / Items / Eggs slots). Title: the header's word on that tab.
InventoryKit.Tabs = {
	{ Id = 'Guns', Label = 'Guns', Title = 'Guns', Icon = 'Gun' },
	{ Id = 'Shoes', Label = 'Your Shoes', Short = 'Shoes', Title = 'Shoes', Icon = 'ShoePile' },
	{ Id = 'Items', Label = 'Items', Title = 'Items', Icon = 'Backpack' },
	{ Id = 'Boxes', Label = 'Boxes', Title = 'Boxes', Icon = 'ShoeBox' },
}
local TAB_ALIAS = { guns = 'Guns', gun = 'Guns', shoes = 'Shoes', shoe = 'Shoes', ['your shoes'] = 'Shoes', items = 'Items', item = 'Items', passes = 'Items', boosts = 'Items', boxes = 'Boxes', box = 'Boxes', index = 'Shoes' }
-- A tab id for anything the HUD might pass ('Shoes', 'shoes', 'Your Shoes'...); nil for an unknown name.
function InventoryKit.tabId(name)
	if type(name) ~= 'string' then return nil end
	return TAB_ALIAS[string.lower((name:gsub('^%s+', ''):gsub('%s+$', '')))]
end

local function words(s)
	local list = {}
	for w in string.gmatch(string.lower(s), '%S+') do table.insert(list, w) end
	return list
end
-- Does `name` match the Search box's `query`? Every word of the query must appear in the name, in any case, as plain
-- text (no patterns); an empty or blank query matches everything.
function InventoryKit.matches(name, query)
	if type(query) ~= 'string' then return true end
	local want = words(query)
	if #want == 0 then return true end
	local hay = string.lower(type(name) == 'string' and name or '')
	for _, w in want do
		if not string.find(hay, w, 1, true) then return false end
	end
	return true
end

-- Your rack as the grid under "Equipped" shows it (like the reference's: the pets you have on sit in the row above, the
-- grid holds the rest): one entry per shoe with pairs NOT on, { Id, Copies (pairs not on: the "x2"), On (pairs on),
-- Total }, best first (ShoeRules.before: bonus, rarity, box). Duplicates stack into one entry; a shoe whose every pair
-- is on only shows in the row above.
function InventoryKit.stack(rack)
	local list = {}
	for id, total in rack.Owned do
		local on = ShoeRules.equippedCount(rack, id)
		if Shoes.ById[id] and total - on > 0 then table.insert(list, { Id = id, Copies = total - on, On = on, Total = total }) end
	end
	table.sort(list, function(a, b) return ShoeRules.before(a.Id, b.Id) end)
	return list
end

-- The entries whose name matches the query (a new list, same order). nameOf(entry) -> name; default the shoe's name.
function InventoryKit.search(list, query, nameOf)
	nameOf = nameOf or function(e)
		local s = Shoes.ById[e.Id]
		return s and s.Name or e.Id
	end
	local out = {}
	for _, e in list do
		if InventoryKit.matches(nameOf(e), query) then table.insert(out, e) end
	end
	return out
end

-- The Index: every shoe of `world`'s boxes in dais order (Shoes.boxesForWorld), commonest first in each box, and
-- whether you own it. Returns { Boxes = { { Box, Shoes = { { Id, Owned, Copies } }, Owned, Total } }, Owned, Total }.
function InventoryKit.index(world, rack)
	local out = { Boxes = {}, Owned = 0, Total = 0 }
	for _, box in Shoes.boxesForWorld(world or Shoes.ActiveWorld) do
		local row = { Box = box, Shoes = {}, Owned = 0, Total = #box.Shoes }
		for _, id in box.Shoes do
			local copies = rack and ShoeRules.copies(rack, id) or 0
			table.insert(row.Shoes, { Id = id, Owned = copies > 0, Copies = copies })
			if copies > 0 then row.Owned += 1 end
		end
		out.Owned += row.Owned
		out.Total += row.Total
		table.insert(out.Boxes, row)
	end
	return out
end

-- The timed boosts (SHOP2: BoostQueue = 'Level:Until,...' in run order, the first one running, each level keeping its
-- own time) and the server's Block Party (PartyEnds). Returns { { Level, Left (seconds), Running, Party } }: the running
-- one first, then the waiting ones (entry i runs from max(now, Until of i-1) to its Until), then the party. Malformed or
-- finished entries are skipped.
function InventoryKit.boosts(queue, now, partyEnds)
	local list = {}
	now = type(now) == 'number' and now or 0
	local from = now
	for level, untilText in string.gmatch(type(queue) == 'string' and queue or '', '(%d+%.?%d*):(%d+)') do
		local lv, ends = tonumber(level), tonumber(untilText)
		if lv and ends and lv > 1 and ends > from then
			table.insert(list, { Level = lv, Left = ends - from, Running = #list == 0 })
			from = ends
		end
	end
	if type(partyEnds) == 'number' and partyEnds > now then table.insert(list, { Level = 2, Left = partyEnds - now, Running = true, Party = true }) end
	return list
end

-- 547 -> "9:07", 3723 -> "1:02:03", negatives -> "0:00".
function InventoryKit.timeText(seconds)
	local s = math.max(0, math.floor(tonumber(seconds) or 0))
	local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
	if h > 0 then return string.format('%d:%02d:%02d', h, m, s % 60) end
	return string.format('%d:%02d', m, s % 60)
end

-- The Store's game passes in catalog order, each { Entry, Owned } (Owned: the server's Pass_<Key> attribute).
-- attrs: a table of attributes (player:GetAttributes()) or a function(name) -> value.
function InventoryKit.passes(attrs)
	local get = type(attrs) == 'function' and attrs or function(k) return type(attrs) == 'table' and attrs[k] or nil end
	local list = {}
	for _, entry in Products.Catalog do
		if entry.Kind == 'Pass' then table.insert(list, { Entry = entry, Owned = get('Pass_' .. entry.Key) == true }) end
	end
	-- (owned first, then the catalog order)
	table.sort(list, function(a, b)
		if a.Owned ~= b.Owned then return a.Owned end
		return a.Entry.Order < b.Entry.Order
	end)
	return list
end

-- Every gun of the ladder with its state, from GunService's attributes (OwnedGuns 'Id,Id', EquippedGun):
-- { Gun, State = 'Equipped' | 'Owned' | 'Locked' } in ladder order. The starter is always owned.
function InventoryKit.guns(ownedText, equipped)
	local owned = { [Guns.Starter] = true }
	for id in string.gmatch(type(ownedText) == 'string' and ownedText or '', '[^,%s]+') do
		if Guns.ById[id] then owned[id] = true end
	end
	if type(equipped) ~= 'string' or not owned[equipped] then equipped = Guns.Starter end
	local list = {}
	for _, gun in Guns.List do
		table.insert(list, { Gun = gun, State = gun.Id == equipped and 'Equipped' or owned[gun.Id] and 'Owned' or 'Locked' })
	end
	return list
end

-- The World window's cards: World 1 is open, worlds 2-5 are coming. (brief 23: World 1's trips, Lobby and "Start a
-- run", are StageRules.Trips, the rule the server checks; World.client reads them there.)
InventoryKit.WorldNames = { 'The Block', 'The Suburbs', 'Uptown', 'The Hills', 'Downtown' }
function InventoryKit.worlds()
	local list = {}
	for i, name in InventoryKit.WorldNames do
		table.insert(list, { World = i, Name = name, Open = i == 1 })
	end
	return list
end

---------------------------------------------------------------------------------------------- client: open
local function playerGui()
	local Players = game:GetService('Players')
	local p = Players.LocalPlayer
	return p and p:FindFirstChildOfClass('PlayerGui')
end
local function fire(guiName, ...)
	local pg = playerGui()
	local gui = pg and pg:FindFirstChild(guiName)
	local open = gui and gui:FindFirstChild('Open')
	if open and open:IsA('BindableEvent') then
		open:Fire(...)
		return true
	end
	return false
end
-- Opens (or, on the tab it shows, closes) the inventory on a tab: 'Guns' | 'Shoes' | 'Items' | 'Boxes'. False while
-- Inventory.client hasn't built its window yet.
function InventoryKit.open(tab) return fire('HoodInventory', tab) end
function InventoryKit.openWorld() return fire('HoodWorld') end

---------------------------------------------------------------------------------------------- look: sizes and colours
-- Measured on ref22_pets_window (2000 x 1114) at 1 design px = 1.8 reference px: the window (header + body, outlines
-- included) 937 x 516 like the Store's 940, its tabs hanging off the left side, the Index button and the bar under it.
InventoryKit.Layout = {
	-- (the body's top outline sits under the header's, so the dark band between them is the reference's 8 px; its light
	-- rim runs down the sides and along the bottom only)
	W = 937, H = 516, Header = 81, BodyTop = 75.6, Outline = 5.5, Rim = 6.3,
	-- tabs: right edges under the window's outline; the open one bigger, the ones below it pushed down
	TabW = 139.5, TabH = 54, TabOnW = 167, TabOnH = 65, TabTop = 76, TabGap = 20, TabOutline = 4.2,
	-- header pieces
	Icon = 84, IconX = 62, IconY = 39, TitleX = 134, HeaderTitleSize = 41,
	-- (the search box's outer edge, its two-band border included: a dark teal edge, then a grey one)
	Search = { X = 450, Y = 16.7, W = 395, H = 46.7, TextSize = 26, TextX = 21, Edge = 3.3, Inner = 2.2 },
	Close = { X = 864, Y = 10, W = 60, H = 60.5, TextSize = 34, Lip = 5 },
	-- body: the "Equipped" line, the equipped row, the line under it, the grid
	TitleY = 119, TitleSize = 28, LineY = 124, Line2Y = 307,
	RowY = 218, GridY = 312, PassTitleY = 334, PassRowY = 416, Pitch = 140.5, Slot = { W = 140, H = 168, Icon = 100, Splat = 166, CY = 62, SplatDY = 10, SplatDX = -3 },
	ValueSize = 35, BadgeSize = 35,
	-- under the window
	Index = { X = 0, Y = 528, W = 186, H = 64, TextSize = 34 },
	Bar = { X = 651, Y = 533, W = 292, H = 77, IconSize = 54, Gap = 68 },
	-- everything together (the tabs' 161 px to the left), centred on the screen
	Fit = { W = 1109, H = 610, X = 166 },
	StudPitch = 29,
}
local L = InventoryKit.Layout

-- Colours sampled from the reference (top of a fill -> bottom; rim = the light band inside the outline).
InventoryKit.Tone = {
	-- (header: its bottom rim is a mid cyan, `rimLow`, and a dark band runs over its bottom outline, as the reference's)
	header = { top = hex('52D5FF'), base = hex('007CFC'), lip = hex('0A78D0'), stroke = hex('062C48'), rim = hex('7CFCFA'), rimLow = hex('2FB4FF'), rot = 90 },
	tabOn = { top = hex('4FD2FF'), base = hex('0A8EFE'), lip = hex('0A78D0'), stroke = hex('062C48'), rim = hex('86F9F8'), rimLow = hex('39BDFF'), rot = 90 },
	tabOff = { top = hex('2B7E9C'), base = hex('07579A'), lip = hex('0A3F6A'), stroke = hex('062C48'), rim = hex('4E9A9C'), rimLow = hex('1D729A'), rot = 90 },
	index = { top = hex('B4E2FA'), base = hex('3F93CF'), lip = hex('2A78B4'), stroke = hex('00344E'), rim = hex('C8FDFF'), rimLow = hex('3DADED'), rot = 90 },
	bar = { top = hex('0A97C0'), base = hex('0A84BA'), lip = hex('0A4C80'), stroke = hex('062C48'), rim = hex('70B4DA'), rot = 90 },
	world = { top = hex('9AE85A'), base = hex('3FAE0C'), lip = hex('2A8000'), stroke = hex('123F17'), rim = hex('C8F8A0'), rot = 90 },
	lobby = { top = hex('7CD8FF'), base = hex('1E86E8'), lip = hex('1460B0'), stroke = hex('0B2A55'), rim = hex('B4ECFF'), rot = 90 },
	stage = { top = hex('FF7CF4'), base = hex('C81AD0'), lip = hex('8A0E96'), stroke = hex('3A0640'), rim = hex('FFB4FA'), rot = 90 },
	locked = { top = hex('5A6172'), base = hex('2E3344'), lip = hex('1F2335'), stroke = hex('0E1020'), rim = hex('7C8498'), rot = 90 },
	-- the red X: magenta at the top going red, no light rim, a dark red lip along the bottom
	close = {
		top = hex('FF00FF'), base = hex('FF0016'), lip = hex('760006'), stroke = hex('4A0010'), rot = 62, -- (magenta from the top-left corner)
		seq = { { 0, hex('FF00F8') }, { 0.1, hex('FF00B4') }, { 0.42, hex('FF0040') }, { 1, hex('FF0016') } },
	},
}
InventoryKit.Color = {
	body = hex('0B1522'), bodyT = 0.38, -- the body: a near-black navy at 62% over the blurred world (UICRITIC2 r1: the ref's #284B5D over water)
	bodyRim = hex('FFFFFF'), bodyRimT = 0.77, -- (the reference's rim: the body lightened by about a quarter)
	line = hex('FFFFFF'), lineT = 0.85, -- the faint light lines round "Equipped"
	search = hex('03284A'), searchT = 0.5, searchEdge = hex('124452'), searchInner = hex('3A4248'), placeholder = hex('808080'),
	navy = hex('00344E'),
	black = hex('000000'),
	plus = hex('121218'),
}
-- The rarity colour of a shoe's splat (Secret: the rainbow splat). Common's light grey reads as smoke on the dark
-- body: its splat is the reference's warm beige-grey (UICRITIC2 r2).
InventoryKit.SplatColor = { Common = hex('B9AE9A') }
function InventoryKit.rarityColor(id)
	local s = Shoes.ById[id]
	local r = s and Shoes.RarityById[s.Rarity] or Shoes.Rarities[1]
	return InventoryKit.SplatColor[r.Id] or r.Color, r.Rank == #Shoes.Rarities
end

---------------------------------------------------------------------------------------------- widgets
local new = Kit.new
local function blank(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	return new('Frame', props)
end
InventoryKit.blank = blank

-- Outlined Gotham Black like every label of the reference: white, a black stroke ~12% of the size.
function InventoryKit.label(props)
	props.Stroke = props.Stroke or Kit.Color.black
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	return Kit.text(props)
end
local label = InventoryKit.label

-- A paint splat behind an item: Kit.splat's uploaded texture (ICONS' splat.png, tinted) once there is one; until then
-- a cloud of round blobs with a few drops flying off, like the reference's (9 frames). props: Kind (nil | 'rainbow' |
-- 'black'), Position, AnchorPoint, ZIndex, Rotation, Transparency.
-- (the cloud covers ~0.75 of the square like ICONS' splat.png, so the fallback and the upload are the same size)
local BLOBS = {
	{ 0.5, 0.52, 0.52 }, { 0.33, 0.39, 0.33 }, { 0.68, 0.35, 0.31 }, { 0.71, 0.65, 0.31 }, { 0.33, 0.68, 0.31 }, { 0.51, 0.25, 0.25 },
	{ 0.13, 0.55, 0.07 }, { 0.89, 0.48, 0.06 }, { 0.8, 0.86, 0.05 },
}
local RAINBOW = { hex('FF4F7A'), hex('FFA43A'), hex('FFE84A'), hex('58E07A'), hex('4AB8FF'), hex('A86CFF') }
function InventoryKit.splat(size, color, props)
	props = props or {}
	if (props.Kind == 'rainbow' and Kit.SplatRainbow ~= '') or (props.Kind == 'black' and Kit.SplatBlack ~= '') or (props.Kind == nil and Kit.Splat ~= '') then
		local s = Kit.splat(size, color, props)
		if props.Transparency and s:FindFirstChild('Image') then s.Image.ImageTransparency = props.Transparency end
		return s
	end
	local z = props.ZIndex or 1
	local holder = blank({ Name = 'Splat', Size = px(size, size), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, Rotation = props.Rotation or 0, ZIndex = z })
	local c = props.Kind == 'black' and InventoryKit.Color.plus or color or Kit.Color.white
	for i, b in BLOBS do
		local blob = blank({
			Name = 'Blob' .. i, BackgroundTransparency = props.Transparency or 0, BackgroundColor3 = props.Kind == 'rainbow' and RAINBOW[(i - 1) % #RAINBOW + 1] or c,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromScale(b[3], b[3]), ZIndex = z, Parent = holder,
		})
		Kit.corner(UDim.new(0.5, 0)).Parent = blob
	end
	return holder
end

-- (brief 24) Every picture is a flat PNG (Kit.icon3d: ART2's upload, or its flat 2D stand-in while that can't draw):
-- no live models, no ViewportFrames. A thing you don't own yet is its black silhouette (props.Locked). props.Bare: the
-- stand-in without its block (an item on a splat, like the reference's pets); shoes and guns are bare by default.
local function icon3d(id, size, props)
	local holder = Kit.icon3d(id, size, { ZIndex = props.ZIndex, Locked = props.Locked, Bare = props.Bare, Place = props.Place })
	if props.Locked then holder:SetAttribute('PreviewSilhouette', true) end
	return holder
end

-- A shoe's icon: ART2's Shoe_<id> PNG (one right shoe, the toe and laces to the front-left, a thick outline), or its
-- flat stand-in in the shoe's colours. props: ZIndex, Locked (a black silhouette).
function InventoryKit.shoeIcon(id, size, props)
	props = table.clone(props or {})
	if props.Bare == nil then props.Bare = true end
	local holder = icon3d('Shoe_' .. tostring(id), size, props)
	holder.Name = 'Shoe_' .. tostring(id)
	return holder
end

-- A gun's icon: ART2's Gun_<id> PNG (side view, muzzle to the right), or its flat stand-in in the gun's colour.
function InventoryKit.gunIcon(id, size, props)
	props = table.clone(props or {})
	if props.Bare == nil then props.Bare = true end
	local holder = icon3d('Gun_' .. tostring(id), size, props)
	holder.Name = 'Gun_' .. tostring(id)
	return holder
end

-- A shoe box's icon: ART2's Box_<id> PNG, or its flat stand-in in the box's colour.
function InventoryKit.boxIcon(id, size, props)
	props = props or {}
	local holder = icon3d('Box_' .. tostring(id), size, props)
	holder.Name = 'Box_' .. tostring(id)
	return holder
end

-- Any IconModels icon, the first of the ids it can show (Kit.iconOr), with the silhouette option.
function InventoryKit.icon(ids, size, props)
	props = props or {}
	local id = type(ids) == 'table' and Kit.iconOr(table.unpack(ids)) or ids
	return icon3d(id, size, props)
end

-- One item of the reference's rows: the splat, the item over it, its value low over its bottom edge ("x8"; ours
-- "+15%"), and a count badge at the top right ("x2"). props: Name, Icon (a GuiObject, `Icon` px square), Color / Kind
-- (the splat), Value, ValueColor, Badge, BadgeColor, Position, AnchorPoint, LayoutOrder, ZIndex, Locked, Dim (a faint
-- splat: an empty slot). Returns holder, hit.
function InventoryKit.slot(props)
	local S = L.Slot
	local z = props.ZIndex or 1
	local holder = blank({ Name = props.Name or 'Slot', Size = px(S.W, S.H), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0, ZIndex = z })
	-- (UICRITIC2 r2: the item sits ON its splat, which shows ~1.2x its width on both sides and a little more below,
	-- under the value; each one turned and nudged its own way, from the slot's order. ICONS' splat.png's cloud covers
	-- 0.72 x 0.80 of its square, centred at 0.52 / 0.46: hence SplatDX / SplatDY)
	local j = props.Jitter or props.LayoutOrder or 0
	local jx, jy = ((j * 37) % 9) - 4 + (S.SplatDX or 0), ((j * 53) % 5) - 2
	if props.Splat ~= false then
		local splat = InventoryKit.splat(props.SplatSize or S.Splat, props.Color, { Kind = props.Kind, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(S.W / 2 + jx, S.CY + (S.SplatDY or 0) + jy), ZIndex = z, Transparency = props.Dim and 0.7 or nil, Rotation = props.SplatRotation or (((j * 71) % 50) - 25) })
		splat.Parent = holder
	end
	if props.Icon then
		props.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		props.Icon.Position = px(S.W / 2, S.CY)
		props.Icon.Parent = holder
	end
	if props.Text then
		-- (the "+3" of the black splat: centred on it)
		label({ Name = 'Text', Text = props.Text, TextSize = props.TextSize or L.ValueSize, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(S.W / 2, S.CY + 2), Size = px(S.W, 44), ZIndex = z + 3, Parent = holder })
	end
	if props.Value then
		local v = label({ Name = 'Value', Text = props.Value, TextSize = props.ValueSize or L.ValueSize, TextColor3 = props.ValueColor, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(S.W / 2, S.CY + 52), Size = px(S.W + 30, 42), ZIndex = z + 3, Parent = holder })
		v.TextSize = Kit.fitSize(props.Value, props.ValueSize or L.ValueSize, props.ValueWidth or S.W + 20, props.ValueWidth and 14 or 16)
	end
	if props.Badge then
		label({ Name = 'Badge', Text = props.Badge, TextSize = props.BadgeSize or L.BadgeSize, TextColor3 = props.BadgeColor, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(S.W / 2 + 34, S.CY - 39), Size = px(90, 42), ZIndex = z + 4, Parent = holder })
	end
	local hit = new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(10, 0), Size = px(S.W - 20, S.CY + 70), ZIndex = z + 6, Parent = holder })
	return holder, hit
end

-- Dims a slot's item and labels (a search that doesn't match it): or puts them back.
function InventoryKit.dim(holder, on)
	for _, d in holder:GetDescendants() do
		if d:IsA('ImageLabel') then
			if d:GetAttribute('BaseT') == nil then d:SetAttribute('BaseT', d.ImageTransparency) end
			d.ImageTransparency = on and 0.75 or d:GetAttribute('BaseT')
		elseif d:IsA('Frame') and d:FindFirstAncestor('Flat') then
			-- (brief 24) a flat stand-in's shapes and their outlines
			if d:GetAttribute('BaseT') == nil then d:SetAttribute('BaseT', d.BackgroundTransparency) end
			d.BackgroundTransparency = on and math.max(0.75, d:GetAttribute('BaseT')) or d:GetAttribute('BaseT')
			local st = d:FindFirstChildOfClass('UIStroke')
			if st then st.Transparency = on and 0.75 or 0 end
		elseif d:IsA('TextLabel') then
			if d:GetAttribute('BaseT') == nil then d:SetAttribute('BaseT', d.TextTransparency) end
			d.TextTransparency = on and 0.6 or d:GetAttribute('BaseT')
			local st = d:FindFirstChildOfClass('UIStroke')
			if st then st.Transparency = on and 0.6 or 0 end
		end
	end
	holder:SetAttribute('Dimmed', on and true or nil)
end

-- The reference's faint light line beside a title: fading out toward its far end (Fade = 'left' | 'right' | 'both').
function InventoryKit.divider(parent, props)
	local f = blank({ Name = props.Name or 'Line', BackgroundTransparency = 0, BackgroundColor3 = InventoryKit.Color.line, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint or Vector2.new(0, 0.5), ZIndex = props.ZIndex or 1, Parent = parent })
	local t = props.Transparency or InventoryKit.Color.lineT
	local keys
	if props.Fade == 'left' then
		keys = { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, t + (1 - t) * 0.3), NumberSequenceKeypoint.new(1, t) }
	elseif props.Fade == 'right' then
		keys = { NumberSequenceKeypoint.new(0, t), NumberSequenceKeypoint.new(0.45, t + (1 - t) * 0.3), NumberSequenceKeypoint.new(1, 1) }
	else
		keys = { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.04, t), NumberSequenceKeypoint.new(0.96, t), NumberSequenceKeypoint.new(1, 1) }
	end
	new('UIGradient', { Transparency = NumberSequence.new(keys), Parent = f })
	return f
end

-- A title between two fading lines ("Equipped  3/3"). Returns the label.
function InventoryKit.titleLine(parent, text, y, props)
	props = props or {}
	local size = props.TextSize or L.TitleSize
	local w = props.Width or L.W
	local z = props.ZIndex or 1
	local t = label({ Name = props.Name or 'Title', Text = text, TextSize = size, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(w / 2, y), Size = px(w - 40, size + 8), ZIndex = z + 1, Parent = parent })
	local tw = Kit.textWidth(text, size)
	local gap = 22
	local x0 = props.LineInset or 10
	local lineY = y + (props.LineDY or 5)
	InventoryKit.divider(parent, { Name = 'LineL', Fade = 'left', Position = px(x0, lineY), Size = px(math.max(0, w / 2 - tw / 2 - gap - x0), 8), ZIndex = z, Transparency = props.LineT })
	InventoryKit.divider(parent, { Name = 'LineR', Fade = 'right', Position = px(w / 2 + tw / 2 + gap, lineY), Size = px(math.max(0, w / 2 - tw / 2 - gap - x0), 8), ZIndex = z, Transparency = props.LineT })
	return t
end

-- The reference's blocks are lit from above: a light rim on top, a darker bottom. Over a Kit.block's face (holder.Body):
-- a `Dark` px band along the bottom (DarkColor, black by default) and over it a `Rim` px band of RimColor (the bottom
-- of the light rim, recoloured). Inset: px kept clear at each end (a rounded block's corners).
function InventoryKit.bottomEdge(holder, props)
	local body = holder:FindFirstChild('Body')
	if not body then return end
	local dark, inset = props.Dark or 0, props.Inset or 0
	if dark > 0 then
		blank({ Name = 'BottomDark', BackgroundTransparency = 0, BackgroundColor3 = props.DarkColor or Kit.Color.black, Position = UDim2.new(0, inset, 1, -dark), Size = UDim2.new(1, -2 * inset, 0, dark), ZIndex = props.ZIndex, Parent = body })
	end
	if props.Rim and props.RimColor then
		blank({ Name = 'BottomRim', BackgroundTransparency = 0, BackgroundColor3 = props.RimColor, Position = UDim2.new(0, inset, 1, -dark - props.Rim), Size = UDim2.new(1, -2 * inset, 0, props.Rim), ZIndex = props.ZIndex, Parent = body })
	end
end

-- A studded block in one of InventoryKit.Tone's colours (Kit.block with the reference's 29 px stud pitch).
function InventoryKit.block(props)
	local p = table.clone(props)
	if type(p.Tone) == 'string' and InventoryKit.Tone[p.Tone] then p.Tone = InventoryKit.Tone[p.Tone] end
	if p.Studs == nil then p.Studs = L.StudPitch end
	p.StudPattern = p.StudPattern or 'recessed'
	return Kit.block(p)
end

-- The whole window (ref22_pets_window, measured): returns a table with
--   Overlay (full screen, transparent), Fit (the composition, UIScale FitScale), Panel (the window), Header (block),
--   Title (label), Icon (holder), Search (TextBox) / Placeholder, Close (hit), Body (the see-through body frame),
--   Content (a frame over the body, window coordinates), Tabs (frame left of the window), Index (holder, hit),
--   Bar (holder)
-- props: Name, Title, Icon (ids list), Tone (header), Search (true), Tabs (true), Index (true), Bar (true), Width,
-- Height (the window; default 937 x 516), FitW / FitH / FitX (the composition), BodyStuds (true).
function InventoryKit.frame(root, props)
	local W, H = props.Width or L.W, props.Height or L.H
	local O = L.Outline
	local overlay = blank({ Name = (props.Name or 'Window') .. 'Overlay', Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local fitW, fitH = props.FitW or L.Fit.W, props.FitH or L.Fit.H
	local fit = blank({ Name = 'Fit', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(fitW, fitH), ZIndex = 21, Parent = overlay })
	new('UIScale', { Name = 'FitScale', Parent = fit })
	-- (Pop: what UIMotion.open springs; the whole composition, so the tabs and buttons come with the window)
	local pop = blank({ Name = props.Name or 'Window', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = fit })
	local panel = blank({ Name = 'Panel', Position = px(props.FitX or L.Fit.X, 0), Size = px(W, H), ZIndex = 22, Parent = pop })
	-- the body: black at 70% over the world, a light band inside its black outline, faint recessed studs
	local bodyTop = L.BodyTop
	local body = blank({ Name = 'Body', BackgroundTransparency = InventoryKit.Color.bodyT, BackgroundColor3 = InventoryKit.Color.body, Position = px(O, bodyTop + O), Size = px(W - 2 * O, H - bodyTop - 2 * O), ZIndex = 22, Parent = panel })
	Kit.stroke(Kit.Color.black, O, true, 0, Enum.LineJoinMode.Miter).Parent = body
	-- (a UIStroke draws outside its frame: the rim's frame is inset by its width so the band lies inside the face, and
	-- its top edge is pushed up under the header: the reference has no light band there)
	local R, up = L.Rim, L.Rim + 8
	local rim = blank({ Name = 'Rim', Position = px(R, R - up), Size = UDim2.new(1, -2 * R, 1, -2 * R + up), ZIndex = 22, Parent = body })
	Kit.stroke(InventoryKit.Color.bodyRim, R, true, InventoryKit.Color.bodyRimT, Enum.LineJoinMode.Miter).Parent = rim
	if props.BodyStuds ~= false then
		Kit.studs(body, { Width = W - 2 * O, Height = H - bodyTop - 2 * O, Pitch = L.StudPitch, Size = 15, Color = Kit.Color.white, Transparency = 0.8, Shade = 0.32, Inset = 6, Filled = true, ZIndex = 22 })
	end
	local content = blank({ Name = 'Content', Size = px(W, H), ZIndex = 24, Parent = panel })
	-- the header: cyan studded, the backpack overflowing at the left, the title, the search box, the red X
	local headerTone = InventoryKit.Tone[props.Tone or 'header'] or InventoryKit.Tone.header
	local header = InventoryKit.block({ Name = 'Header', Tone = headerTone, Width = W, Height = L.Header, Outline = O, RimWidth = 4, Studs = L.StudPitch, StudShade = 0.75, Gloss = true, ZIndex = 26 })
	header.Parent = panel
	-- the reference's header bottom: a mid-cyan rim over a dark band that joins the outline (13 reference px of dark in all)
	InventoryKit.bottomEdge(header, { Rim = 4, RimColor = headerTone.rimLow, Dark = 1.6, ZIndex = 28 })
	-- (its diagonal shine is a faint wide band: the kit's gloss at a little over half strength)
	local gloss = header.Body:FindFirstChild('Gloss')
	if gloss and gloss:IsA('ImageLabel') then
		gloss.ImageTransparency = 1 - (1 - gloss.ImageTransparency) * 0.55
	elseif gloss then
		gloss.BackgroundTransparency = 0.45
	end
	-- (brief 25) the header's picture where ref22_pets_window's backpack is: Kit.Place.header, on the header block
	local iconHolder = blank({ Name = 'IconSpot', Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = header })
	local function setIcon(ids)
		for _, c in iconHolder:GetChildren() do c:Destroy() end
		local icon = InventoryKit.icon(ids, nil, { ZIndex = 30, Place = { Rule = 'header', W = W, H = L.Header } })
		icon.Parent = iconHolder
	end
	setIcon(props.Icon or { 'Backpack', 'Sneaker' })
	local title = label({ Name = 'Title', Text = props.Title or '', TextSize = L.HeaderTitleSize, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(L.TitleX, 2), Size = px(310, L.Header - 2), ZIndex = 30, Parent = header })
	local out = { Overlay = overlay, Fit = fit, Pop = pop, Panel = panel, Header = header, Title = title, Body = body, Content = content, SetIcon = setIcon }
	if props.Search ~= false then
		local S = L.Search
		-- S is the box's outer edge; the outer (dark teal) border is a UIStroke outside the frame, the grey one inside it
		local e, tx = S.Edge, S.TextX - S.Edge
		local box = blank({ Name = 'SearchBox', BackgroundTransparency = InventoryKit.Color.searchT, BackgroundColor3 = InventoryKit.Color.search, Position = px(S.X + e, S.Y + e), Size = px(S.W - 2 * e, S.H - 2 * e), ZIndex = 30, Parent = header })
		Kit.corner(3).Parent = box
		Kit.stroke(InventoryKit.Color.searchEdge, e, true).Parent = box
		local inner = blank({ Name = 'Inner', Position = px(S.Inner, S.Inner), Size = UDim2.new(1, -2 * S.Inner, 1, -2 * S.Inner), ZIndex = 30, Parent = box })
		Kit.stroke(InventoryKit.Color.searchInner, S.Inner, true, 0.1, Enum.LineJoinMode.Miter).Parent = inner
		local placeholder = label({ Name = 'Placeholder', Text = 'Search...', TextSize = S.TextSize, TextColor3 = InventoryKit.Color.placeholder, StrokeThickness = 2.2, TextXAlignment = Enum.TextXAlignment.Left, Position = px(tx, 0), Size = UDim2.new(1, -tx - 8, 1, 0), ZIndex = 31, Parent = box })
		local input = new('TextBox', {
			Name = 'Input', BackgroundTransparency = 1, Text = '', PlaceholderText = '', ClearTextOnFocus = false, FontFace = Kit.Font.display, TextSize = S.TextSize,
			TextColor3 = Kit.Color.white, TextXAlignment = Enum.TextXAlignment.Left, Position = px(tx, 0), Size = UDim2.new(1, -tx - 8, 1, 0), ZIndex = 32, Parent = box,
		})
		Kit.stroke(Kit.Color.black, 3).Parent = input
		out.Search, out.Placeholder = input, placeholder
	end
	local C = L.Close
	local close, closeHit = Kit.blockButton({ Name = 'Close', Tone = InventoryKit.Tone.close, Width = C.W, Height = C.H, Text = 'X', TextSize = C.TextSize, Studs = false, Outline = 3.5, Rim = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(L.W - C.X - C.W), 0, C.Y), ZIndex = 30 })
	close.Parent = header
	InventoryKit.bottomEdge(close, { Dark = C.Lip, DarkColor = InventoryKit.Tone.close.lip, ZIndex = 31 })
	out.CloseButton, out.Close = close, closeHit
	if props.Tabs ~= false then
		out.Tabs = blank({ Name = 'Tabs', Position = px(0, 0), Size = px(L.Fit.X + 6, H), ZIndex = 21, Parent = pop })
		out.TopClear = L.TabTop - 8 -- (the first tab's icon pokes a little over its slab)
	end
	if props.Index ~= false then
		local I = L.Index
		local holder, hit = Kit.blockButton({ Name = 'Index', Tone = InventoryKit.Tone.index, Width = I.W, Height = I.H, Text = 'Index', TextSize = I.TextSize, Outline = 4, OutlineColor = InventoryKit.Color.navy, Radius = 3, RimWidth = 3, Studs = L.StudPitch, StudPattern = 'recessed', StudShade = 0.6, Position = px((props.FitX or L.Fit.X) + I.X, I.Y), ZIndex = 22 })
		holder.Parent = pop
		InventoryKit.bottomEdge(holder, { Rim = 3, RimColor = InventoryKit.Tone.index.rimLow, Inset = 3, ZIndex = 24 })
		out.Index, out.IndexHit = holder, hit
	end
	if props.Bar ~= false then
		local B = L.Bar
		local bar = InventoryKit.block({ Name = 'Bar', Tone = 'bar', Width = B.W, Height = B.H, Outline = 5.5, RimWidth = 3, StudShade = 0.7, Position = px((props.FitX or L.Fit.X) + B.X, B.Y), ZIndex = 22 })
		bar.Parent = pop
		out.Bar = bar
	end
	panel:SetAttribute('DesignW', fitW)
	panel:SetAttribute('DesignH', fitH)
	return out
end

-- One side tab: a studded slab, its icon over the top half, its name on its bottom edge; the open one brighter and
-- 1.19x bigger. Returns holder, hit.
function InventoryKit.tab(props)
	local on = props.On
	local w, h = on and L.TabOnW or L.TabW, on and L.TabOnH or L.TabH
	local tone = InventoryKit.Tone[on and 'tabOn' or 'tabOff']
	local holder, hit = Kit.blockButton({ Name = props.Name or 'Tab', Tone = tone, Width = w, Height = h, Outline = L.TabOutline, RimWidth = 3, Studs = L.StudPitch, StudPattern = 'recessed', StudShade = on and 0.75 or 0.55, Position = props.Position, AnchorPoint = Vector2.new(1, 0), ZIndex = props.ZIndex or 21 })
	local z = (props.ZIndex or 21) + 4
	InventoryKit.bottomEdge(holder, { Rim = 3, RimColor = tone.rimLow, ZIndex = z - 2 })
	-- (brief 25) the picture where ref22_pets_window's tab pictures are: Kit.Place.tab (the slab's part out from under the
	-- window: its right 4 px tuck under the window's outline)
	local icon = InventoryKit.icon(props.Icon or { 'Sneaker' }, nil, { ZIndex = z, Place = { Rule = 'tab', W = w - 4, H = h, X0 = L.TabOutline, Y0 = L.TabOutline } })
	icon.Parent = holder.Body
	-- The name, centred on the part of the slab out from under the window (its right 4 px tuck under the outline). A
	-- phone's readable size can't fit a long name there: the short one (props.Short) is used instead.
	local size = math.max(on and 19 or 17, props.LabelSize or 0)
	local room = w - 4 + (on and 14 or 8)
	local text = props.Text or ''
	if props.Short and Kit.textWidth(text, size) > room then text = props.Short end
	label({ Name = 'Caption', Text = text, TextSize = Kit.fitSize(text, size, room, 12), StrokeThickness = on and 3 or 2.6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -2, 1, on and -6 or -5), Size = UDim2.new(1, 20, 0, size + 6), ZIndex = z + 1, Parent = holder.Body })
	-- (the hit area also covers the icon's overflow)
	return holder, hit, icon
end

-- (brief 22) The inventory composition fills the screen like the reference frame (its window is 84% of the width): the
-- windows' ScreenGuis use ScreenInsets.DeviceSafeInsets (the topbar row is used, a phone's notch is not) and the whole
-- composition scales to fit, up or down. InventoryKit.scaleFor(abs) is that scale for the inventory's composition; a
-- smaller window (World) uses the same scale so both read as one family, shrinking further only if it doesn't fit.
function InventoryKit.scaleFor(abs)
	local k = Kit.scaleFor(abs)
	local rootW, rootH = abs.X / k, abs.Y / k
	return math.min((rootW - 2) / L.Fit.W, (rootH - 4) / L.Fit.H), rootW, rootH
end
-- out.TopClear (design px from the composition's top to the highest thing at its left, e.g. the tabs' icons): Roblox's
-- topbar buttons sit over the screen's top-left corner, so on short screens (phones) the composition shrinks and steps
-- down until that part is below the topbar row (58 dp).
function InventoryKit.fit(out, abs)
	local scale = out.Fit and out.Fit:FindFirstChild('FitScale')
	if not scale or abs.X < 1 or abs.Y < 1 then return end
	local s, rootW, rootH = InventoryKit.scaleFor(abs)
	local fw, fh = out.Fit.Size.X.Offset, out.Fit.Size.Y.Offset
	s = math.min(s, (rootW - 2) / fw, (rootH - 4) / fh)
	local dy = 0
	if out.TopClear then
		local top = 58 / Kit.scaleFor(abs)
		local y0 = (rootH - fh * s) / 2
		if y0 + out.TopClear * s < top then
			s = math.min(s, (rootH - 4 - top) / (fh - out.TopClear))
			y0 = top - out.TopClear * s
			dy = y0 + fh * s / 2 - rootH / 2
		end
	end
	scale.Scale = s
	out.Fit.Position = UDim2.new(0.5, 0, 0.5, dy)
	out.Scale = s * Kit.scaleFor(abs) -- (screen dp per design px)
end
-- A label size that stays readable on screen: at least `minDp` dp of cap height (Gotham Black's cap ~0.7 em) at the
-- composition's scale, never under `size`. (UICRITIC2 r2: phones' tab labels came out ~8 dp.)
function InventoryKit.readable(out, size, minDp)
	local k = out and out.Scale or 1
	return math.max(size, math.ceil((minDp or 10) / 0.7 / math.max(0.1, k)))
end
-- Puts a window's ScreenGui on the whole safe screen (the topbar row included).
function InventoryKit.fullScreen(gui)
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
end

-- While a full-size window is open Roblox's player list (top right, under the topbar) would sit over its X: it is hidden
-- and comes back when the last such window closes. With UIKit.HidePlayerList it stays hidden for good (the HUD's call).
-- (InventoryKit.setPlayerList is the one CoreGui call, swappable for the unit tests)
local covering = {}
function InventoryKit.setPlayerList(shown)
	pcall(function() game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, shown) end)
end
function InventoryKit.coverPlayerList(owner, on)
	covering[owner] = on and true or nil
	if Kit.HidePlayerList then return end
	InventoryKit.setPlayerList(next(covering) == nil)
end

return InventoryKit
