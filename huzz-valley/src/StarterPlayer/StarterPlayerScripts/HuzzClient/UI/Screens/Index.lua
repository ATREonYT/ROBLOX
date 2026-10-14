-- Character Index (design/pages/02, §7 of design/IMPLEMENTATION-PROMPT.md): All / Owned / Favourites tabs, a search
-- box and Tier / Sort dropdowns over one card grid, and a preview of the selected character on the right.
-- Ownership, equipping and favourites live on the server (ActionService); this screen only asks and redraws when
-- the new state arrives. Selection, equipped and favourite are three separate things.
-- Art: the kit's own pictures cropped from page 02 (assets/art/char-*.png) until real companion models exist.
-- Those crops still carry the kit's printed tier badge (and Aiko's star), so the live badge/star are drawn exactly
-- over them (ART below says where), and a locked card always shows the kit's dark silhouette, never coloured art.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local Index = {}

local W, H = 701, 320 -- every main window shares this size

-- Colours measured on page 02 that the shared theme doesn't have.
local COL = {
	Field = hex("1E3057"), Drop = hex("1A284E"), FieldRim = hex("0E1836"), Placeholder = hex("C3CBE3"),
	CardRim = hex("2D5380"), Band = hex("182C45"), ArtBack = hex("223B6E"), Select = hex("FCE24A"),
	Status = hex("D5D8F2"), Equipped = hex("C7C9F9"), LockedText = hex("9AA6BF"),
	Info = hex("1E314A"), Rule = hex("3A4F70"), PreviewBack = hex("1B2D4A"),
	Equip = hex("8C8FEA"), EquipText = hex("0A0D3A"), Menu = hex("16264A"), MenuRim = hex("2E4669"),
}

-- Button looks this screen adds to the Kit's set (registered here; Kit.lua stays the shared base).
local function look(fill: Color3, text: Color3, top: Color3, rim: Color3)
	return { Idle = fill, Hover = fill:Lerp(Color3.new(1, 1, 1), 0.1), Pressed = fill:Lerp(Color3.new(0, 0, 0), 0.1), Text = text, Top = top, Rim = rim }
end
Kit.Styles.IndexEquip = look(COL.Equip, COL.EquipText, hex("A3A6F6"), hex("111939")) -- periwinkle, dark navy text (UNEQUIP)
Kit.Styles.IndexFav = look(hex("274570"), C.Text, hex("34557F"), hex("3D5F8C")) -- the favourite square
Kit.Styles.IndexDrop = look(COL.Drop, C.Text, hex("24345C"), COL.FieldRim) -- Tier / Sort fields
Kit.Styles.IndexItem = look(COL.Menu, C.Text, COL.Menu, COL.Menu) -- dropdown rows

-- Where each crop's printed badge and star sit, in card px (card art 151 x 83). The live badge is drawn at least
-- as wide/tall as the printed one so it fully covers it; StarCover hides a printed star under the live one.
local ART = {
	CharAiko = { BadgeX = 113, BadgeR = 0, BadgeH = 22, Star = Vector2.new(4, 3), StarCover = hex("2A4592") },
	CharRen = { BadgeX = 98, BadgeR = 3, BadgeH = 24, Star = Vector2.new(5, 4) },
	CharSora = { BadgeX = 106, BadgeR = 0, BadgeH = 28, Star = Vector2.new(5, 4) },
	CharLocked = { BadgeX = 101, BadgeR = 0, BadgeH = 29, Star = Vector2.new(2, 5), StarCover = hex("283C5B") },
}
local FULL_ART = { Aiko = "CharAikoFull" } -- the big preview picture, where the kit has one

-- Grid geometry (window px): two columns of 151 x 112 cards, measured from page 02.
local GRID = { X = 12, Y = 80, W = 333, H = H - 80 - 4, Pad = 6 }
local CW, CH, ART_H, GAP_X, GAP_Y = 151, 112, 83, 15, 11

local SORTS = {
	{ Key = "NameAZ", Text = "Name A - Z", Short = "Name A - Z" },
	{ Key = "NameZA", Text = "Name Z - A", Short = "Name Z - A" },
	{ Key = "TierHigh", Text = "Tier high - low", Short = "Tier high" },
	{ Key = "TierLow", Text = "Tier low - high", Short = "Tier low" },
	{ Key = "Newest", Text = "Newest acquired", Short = "Newest" },
}

-- Screen state (kept while the window is closed, so reopening shows the same view).
local view = { Tab = "All", Search = "", Tier = "All", Sort = "NameAZ" }
local selected: string? = nil
local busy = false

local function owned(id: string): boolean return State.data.Characters[id] ~= nil end
local function equipped(id: string): boolean return State.data.Equipped == id end
local function favourite(id: string): boolean return State.data.FavChars[id] == true end
local function tierName(tier: string): string return Characters.TierNames[tier] or tier end
local function tierColor(tier: string): Color3 return Characters.TierColors[tier] or C.Slate end

-- The filtered, sorted list for the current view (search is case-insensitive and plain text, not a pattern).
local function visibleList(): { any }
	local list = {}
	local needle = string.lower(view.Search)
	for _, c in Characters.List do
		local keep = (view.Tab == "All") or (view.Tab == "Owned" and owned(c.Id)) or (view.Tab == "Favourites" and favourite(c.Id))
		if keep and view.Tier ~= "All" and c.Tier ~= view.Tier then keep = false end
		if keep and needle ~= "" and not string.find(string.lower(c.Name), needle, 1, true) then keep = false end
		if keep then table.insert(list, c) end
	end
	local function byName(a, b)
		if a.Name ~= b.Name then return a.Name < b.Name end
		return a.Id < b.Id
	end
	local sorters = {
		NameAZ = byName,
		NameZA = function(a, b)
			if a.Name ~= b.Name then return a.Name > b.Name end
			return a.Id < b.Id
		end,
		TierHigh = function(a, b)
			local ra, rb = Characters.tierRank(a.Tier), Characters.tierRank(b.Tier)
			if ra ~= rb then return ra > rb end
			return byName(a, b)
		end,
		TierLow = function(a, b)
			local ra, rb = Characters.tierRank(a.Tier), Characters.tierRank(b.Tier)
			if ra ~= rb then return ra < rb end
			return byName(a, b)
		end,
		-- newest first; owned without a time after those with one; characters you don't own last
		Newest = function(a, b)
			local ta, tb = State.data.Characters[a.Id], State.data.Characters[b.Id]
			local ka = if ta == nil then 2 elseif type(ta) == "number" then 0 else 1
			local kb = if tb == nil then 2 elseif type(tb) == "number" then 0 else 1
			if ka ~= kb then return ka < kb end
			if ka == 0 and ta ~= tb then return ta > tb end
			return byName(a, b)
		end,
	}
	table.sort(list, sorters[view.Sort] or byName)
	return list
end

-- A tier badge: coloured, white condensed caps. Never narrower/shorter than minW x h (AutomaticSize grows it to
-- fit longer names), anchored at its top-right corner.
local function badge(parent: Instance, tier: string, pos: UDim2, minW: number, h: number, textSize: number, z: number)
	local b = Kit.text({
		Name = "TierBadge", Text = tierName(tier), FontFace = F.Button, TextSize = textSize, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, BackgroundTransparency = 0, BackgroundColor3 = tierColor(tier),
		AnchorPoint = Vector2.new(1, 0), Position = pos, Size = UDim2.fromOffset(minW, h), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z, Parent = parent,
	})
	Kit.corner(3).Parent = b
	Kit.pad(6, 6, 0, 0).Parent = b
	return b
end

-- The character picture with only its top corners rounded (one rounded copy plus a square copy clipped below the
-- corners: ClipsDescendants clips square in Roblox), the live tier badge over the printed one, and a cover over a
-- printed star. scale = picture size / card art size. Returns the art's info (for the star position).
local function picture(parent: Instance, c, isOwned: boolean, w: number, h: number, scale: number, rounded: { top: boolean, bottom: boolean })
	local artName = if isOwned then c.Art else "CharLocked"
	local holder = new("Frame", { Name = "Art", Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.ArtBack, BackgroundTransparency = artName and 1 or 0, BorderSizePixel = 0, Parent = parent })
	local r = 4
	if artName then
		Kit.corner(r).Parent = Kit.art(artName, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = holder })
		-- square copies cover the corners that should stay square
		if not rounded.bottom then
			local lower = new("Frame", { Name = "Lower", Position = UDim2.fromOffset(0, r), Size = UDim2.new(1, 0, 1, -r), BackgroundTransparency = 1, ClipsDescendants = true, Parent = holder })
			Kit.art(artName, { Name = "Picture", Position = UDim2.fromOffset(0, -r), Size = UDim2.fromOffset(w, h), Parent = lower })
		end
	else
		-- owned, but the kit has no picture for this character yet (honest placeholder)
		Kit.corner(r).Parent = holder
		Kit.text({ Name = "NoArt", Text = "Picture coming soon", TextSize = math.floor(13 * scale), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = holder })
	end
	local info = artName and ART[artName] or { BadgeX = CW, BadgeR = 3, BadgeH = 22, Star = Vector2.new(5, 4) }
	local right = math.round(info.BadgeR * scale)
	local minW = math.max(36, math.round((CW - info.BadgeR - info.BadgeX) * scale))
	badge(holder, c.Tier, UDim2.new(1, -right, 0, 0), minW, math.round(info.BadgeH * scale), math.round(15 * scale), 3)
	if info.StarCover then
		local s = math.round(28 * scale)
		new("Frame", { Name = "StarCover", Position = UDim2.fromOffset(math.round((info.Star.X - 1) * scale), math.round((info.Star.Y - 1) * scale)), Size = UDim2.fromOffset(s, s), BackgroundColor3 = info.StarCover, BorderSizePixel = 0, ZIndex = 2, Parent = holder }, { Kit.corner(math.round(8 * scale)) })
	end
	return holder, info
end

-- Grid cards ------------------------------------------------------------------------------------------------------

type Card = { Instance: TextButton, Id: string, refresh: () -> () }
local cards: { Card } = {}
local onSelect: (string) -> () = function() end

local function card(parent: Instance, c, x: number, y: number): Card
	local btn = new("TextButton", { Name = c.Id, Text = "", AutoButtonColor = false, Selectable = true, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CH), BackgroundColor3 = COL.Band, BorderSizePixel = 0, Parent = parent }, { Kit.corner(4) })
	local rim = Kit.stroke(COL.CardRim, 1)
	rim.Name = "Rim"
	rim.Parent = btn
	Motion.bindButton(btn, function() return nil end) -- hover lift and press squish; the fill stays
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
	local name = Kit.name({ Name = "Name", Text = c.Name, TextSize = 16, Position = UDim2.fromOffset(9, ART_H), Size = UDim2.fromOffset(80, CH - ART_H), Parent = btn })
	local status = new("Frame", { Name = "Status", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, ART_H), Size = UDim2.fromOffset(90, CH - ART_H), BackgroundTransparency = 1, Parent = btn },
		{ Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	local statusIcon: ImageLabel? = nil
	local statusText = Kit.text({ Name = "Text", Text = "", FontFace = F.Body, TextSize = 15, TextColor3 = COL.Status, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextWrapped = false, LayoutOrder = 2, Parent = status })
	local favBtn = new("TextButton", { Name = "Favourite", Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), ZIndex = 6, Parent = btn })
	local star: ImageLabel? = nil
	local shown = { owned = nil :: boolean?, fav = nil :: boolean?, eq = nil :: boolean? }
	local info

	local function refresh()
		local isOwned, isFav, isEq = owned(c.Id), favourite(c.Id), equipped(c.Id)
		if isOwned ~= shown.owned then
			for _, ch in body:GetChildren() do ch:Destroy() end
			local _, i = picture(body, c, isOwned, CW, ART_H, 1, { top = true, bottom = false })
			info = i
			shown.fav = nil
		end
		if isFav ~= shown.fav then
			if star then star:Destroy() end
			local s = isFav and 26 or 21
			local at = info.Star + (isFav and Vector2.zero or Vector2.new(2, 2))
			star = Kit.icon(isFav and "FavouriteFilled" or "FavouriteOutline", { Name = "Star", Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(s, s), ZIndex = 4, Parent = btn })
			favBtn.Position = UDim2.fromOffset(info.Star.X - 3, info.Star.Y - 3)
		end
		if isOwned ~= shown.owned or isEq ~= shown.eq then
			if statusIcon then statusIcon:Destroy(); statusIcon = nil end
			if isOwned then
				statusIcon = Kit.icon(isEq and "CheckEquipped" or "CheckOwned", { Name = "Icon", Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, Parent = status })
				statusText.Text = isEq and "Equipped" or "Owned"
			else
				statusText.Text = ""
			end
		end
		shown.owned, shown.fav, shown.eq = isOwned, isFav, isEq
		local sel = selected == c.Id
		rim.Color = sel and COL.Select or COL.CardRim
		rim.Thickness = sel and 3 or 1
	end

	btn.Activated:Connect(function() onSelect(c.Id) end)
	favBtn.Activated:Connect(function()
		local on = not favourite(c.Id)
		local ok, why = State.action("FavoriteCharacter", c.Id, on)
		if not ok then Toast.show(why or "Couldn't change that favourite.") end
	end)
	refresh()
	return { Instance = btn, Id = c.Id, refresh = refresh }
end

-- Small helpers ---------------------------------------------------------------------------------------------------

-- A down chevron drawn from two bars (no image needed).
local function chevron(parent: Instance, order: number, color: Color3?, size: number?)
	local s = size or 9
	local f = new("Frame", { Name = "Chevron", BackgroundTransparency = 1, Size = UDim2.fromOffset(s + 1, math.ceil(s * 0.6)), LayoutOrder = order, Parent = parent })
	local len = math.ceil(s * 0.66)
	for i, rot in { 45, -45 } do
		new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(i == 1 and 0.3 or 0.7, 0, 0.5, 0), Size = UDim2.fromOffset(len, 2), Rotation = rot, BackgroundColor3 = color or C.Text, BorderSizePixel = 0, Parent = f })
	end
	return f
end

function Index.build(parent: Instance)
	local window = Kit.window({ Name = "Index", Title = "CHARACTER INDEX", Icon = "CollectionBook", Width = W, Height = H, TitleSize = 21, TitleX = 58, TitleOffsetY = 1, TitleWidth = 219, StudsTo = 300, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- Header: search, tier and sort (page 02 #3-#5, measured; the window is 7 px narrower than the page's, taken
	-- from the gaps on the right).
	local search = new("Frame", { Name = "Search", Position = UDim2.fromOffset(302, 9), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = COL.Field, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.FieldRim, 1) })
	Kit.icon("Search", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(15, 16), ZIndex = 2, Parent = search })
	local placeholder = Kit.text({ Name = "Placeholder", Text = "Search characters...", FontFace = F.Label, TextSize = 12, TextColor3 = COL.Placeholder, Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -36, 1, 0), TextWrapped = false, ZIndex = 2, Parent = search })
	local box: TextBox = new("TextBox", {
		Name = "Box", Text = "", PlaceholderText = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = F.Label, TextSize = 12,
		TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true,
		Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -36, 1, 0), ZIndex = 3, Parent = search,
	})

	local tierDrop = Kit.button({ Name = "TierFilter", Style = "IndexDrop", Text = "Tier: All", FontFace = F.Label, TextSize = 12, Gap = 10, Corner = 4, Position = UDim2.fromOffset(457, 9), Size = UDim2.fromOffset(81, 30), ZIndex = 2, Parent = panel })
	chevron(tierDrop.Instance:FindFirstChild("Content"), 3)
	local sortDrop = Kit.button({ Name = "Sort", Style = "IndexDrop", Text = "Sort: Name A - Z", FontFace = F.Label, TextSize = 11, Gap = 5, Corner = 4, Position = UDim2.fromOffset(544, 9), Size = UDim2.fromOffset(111, 30), ZIndex = 2, Parent = panel })
	chevron(sortDrop.Instance:FindFirstChild("Content"), 3)

	-- Card grid (left). Cards sit Pad px inside the scrolling frame so the selected card's yellow rim isn't clipped.
	local grid = new("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(GRID.X, GRID.Y), Size = UDim2.fromOffset(GRID.W, GRID.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Selectable = false, Parent = panel })

	local empty = new("Frame", { Name = "Empty", Position = UDim2.fromOffset(GRID.X, GRID.Y), Size = UDim2.fromOffset(GRID.W - 8, GRID.H - 10), BackgroundTransparency = 1, Visible = false, Parent = panel })
	local emptyTitle = Kit.name({ Name = "Title", Text = "No characters found", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), Parent = empty })
	local emptyHint = Kit.text({ Name = "Hint", Text = "", TextSize = 15, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 40), Parent = empty })
	local clearBtn = Kit.button({ Name = "ClearFilters", Text = "CLEAR FILTERS", Style = "IndexEquip", TextSize = 18, Corner = 4, Position = UDim2.new(0.5, 0, 0, 136), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(150, 34), Parent = empty })

	-- Preview (right): the picture (216 x 238 at the left of a backdrop that runs under the favourite square), then
	-- the info column over its right edge.
	local previewArt = new("Frame", { Name = "Preview", Position = UDim2.fromOffset(347, 78), Size = UDim2.fromOffset(286, 238), BackgroundColor3 = COL.PreviewBack, BorderSizePixel = 0, Parent = panel }, { Kit.corner(3) })
	local info = new("Frame", { Name = "Info", Position = UDim2.fromOffset(558, 133), Size = UDim2.fromOffset(139, 183), BackgroundColor3 = COL.Info, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(3) })
	local favBig = Kit.button({ Name = "Favourite", Style = "IndexFav", Text = "", Corner = 4, Position = UDim2.fromOffset(636, 59), Size = UDim2.fromOffset(49, 47), ZIndex = 3, Parent = panel })
	local favIcon: ImageLabel? = nil
	local nameRow = new("Frame", { Name = "NameRow", Position = UDim2.fromOffset(565, 117), Size = UDim2.fromOffset(128, 32), BackgroundTransparency = 1, ZIndex = 3, Parent = panel },
		{ Kit.list(Enum.FillDirection.Horizontal, 9, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local nameLabel = Kit.name({ Name = "Name", Text = "", TextSize = 26, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), LayoutOrder = 1, ZIndex = 3 })
	nameLabel.Parent = nameRow
	local nameBadge: TextLabel? = nil
	local statusRow = new("Frame", { Name = "StatusRow", Position = UDim2.fromOffset(565, 155), Size = UDim2.fromOffset(130, 25), BackgroundTransparency = 1, ZIndex = 3, Parent = panel },
		{ Kit.list(Enum.FillDirection.Horizontal, 7, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local statusIcon: ImageLabel? = nil
	local statusText = Kit.text({ Name = "Text", Text = "", FontFace = F.Button, TextSize = 22, TextColor3 = COL.Equipped, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 25), TextWrapped = false, LayoutOrder = 2, ZIndex = 3, Parent = statusRow })
	local line1 = Kit.text({ Name = "About", Text = "", TextSize = 16, LineHeight = 0.95, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(11, 54), Size = UDim2.fromOffset(122, 36), ZIndex = 3, Parent = info })
	new("Frame", { Name = "Rule", Position = UDim2.fromOffset(11, 93), Size = UDim2.fromOffset(113, 1), BackgroundColor3 = COL.Rule, BorderSizePixel = 0, ZIndex = 3, Parent = info })
	local source = Kit.text({ Name = "Source", Text = "", TextSize = 16, LineHeight = 0.95, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(11, 97), Size = UDim2.fromOffset(122, 40), ZIndex = 3, Parent = info })
	local action = Kit.button({ Name = "EquipAction", Style = "IndexEquip", Text = "UNEQUIP", TextSize = 20, Gap = 10, Corner = 5, Position = UDim2.fromOffset(566, 275), Size = UDim2.fromOffset(126, 38), ZIndex = 3, Parent = panel })
	local actionIcon: ImageLabel? = nil
	local actionKey = ""

	local shownPreview = ""
	local function refreshPreview()
		local c = selected and Characters.get(selected)
		local visible = c ~= nil
		for _, g in { previewArt, info, favBig.Instance, nameRow, statusRow, action.Instance } do g.Visible = visible end
		if not c then return end
		local isOwned, isEq, isFav = owned(c.Id), equipped(c.Id), favourite(c.Id)
		-- picture: the kit's full-size art when there is one, otherwise the card picture framed in the middle
		local key = c.Id .. (isOwned and "+" or "-")
		if key ~= shownPreview then
			shownPreview = key
			for _, ch in previewArt:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
			local full = isOwned and FULL_ART[c.Id]
			if full then
				Kit.corner(3).Parent = Kit.art(full, { Name = "Picture", Size = UDim2.fromOffset(216, 238), Parent = previewArt })
			else
				local s = 1.3
				local frame = new("Frame", { Name = "Framed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(108, 70), Size = UDim2.fromOffset(math.round(CW * s), math.round(ART_H * s)), BackgroundTransparency = 1, Parent = previewArt }, { Kit.stroke(COL.CardRim, 1) })
				picture(frame, c, isOwned, math.round(CW * s), math.round(ART_H * s), s, { top = true, bottom = true })
			end
		end
		nameLabel.Text = c.Name
		if nameBadge then nameBadge:Destroy() end
		nameBadge = badge(nameRow, c.Tier, UDim2.new(), 47, 28, 18, 3)
		;(nameBadge :: TextLabel).AnchorPoint = Vector2.zero
		;(nameBadge :: TextLabel).LayoutOrder = 2
		if statusIcon then statusIcon:Destroy() end
		statusIcon = Kit.icon(isOwned and "CheckEquipped" or "Lock", { Name = "Icon", Size = UDim2.fromOffset(isOwned and 25 or 20, isOwned and 25 or 23), LayoutOrder = 1, ZIndex = 3, Parent = statusRow })
		statusText.Text = isEq and "Equipped" or isOwned and "Owned" or "Locked"
		statusText.TextColor3 = isOwned and COL.Equipped or COL.LockedText
		line1.Text = isEq and "Selected companion." or isOwned and "In your collection." or "Not collected yet."
		source.Text = c.Source
		if favIcon then favIcon:Destroy() end
		favIcon = Kit.icon(isFav and "FavouriteFilled" or "FavouriteOutline", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(isFav and 31 or 26, isFav and 30 or 26), ZIndex = 3, Parent = favBig.Instance })
		-- one action: UNEQUIP (equipped), EQUIP (owned) or LOCKED (can't be equipped)
		local newKey = isEq and "Unequip" or isOwned and "Equip" or "Locked"
		if newKey ~= actionKey then
			actionKey = newKey
			action.setText(string.upper(newKey))
			action.setStyle(newKey == "Locked" and "Disabled" or "IndexEquip")
			action.setEnabled(newKey ~= "Locked")
			if actionIcon then actionIcon:Destroy() end
			local locked = newKey == "Locked"
			actionIcon = Kit.icon(locked and "Lock" or "ShirtBenefit", { Name = "Icon", Size = UDim2.fromOffset(locked and 18 or 26, locked and 21 or 24), LayoutOrder = 1, ImageColor3 = locked and Color3.new(1, 1, 1) or COL.EquipText, ZIndex = 3, Parent = action.Instance:FindFirstChild("Content") })
		end
	end

	local lastKey: string? = nil
	local function cardsInOrder()
		local list = {}
		for _, cd in cards do table.insert(list, cd.Instance) end
		return list
	end
	local function refresh(animate: boolean?)
		local list = visibleList()
		local ids = {}
		for _, c in list do table.insert(ids, c.Id) end
		local key = table.concat(ids, ",")
		if key ~= lastKey then
			lastKey = key
			for _, cd in cards do cd.Instance:Destroy() end
			cards = {}
			for i, c in list do
				local col, row = (i - 1) % 2, (i - 1) // 2
				table.insert(cards, card(grid, c, GRID.Pad + col * (CW + GAP_X), GRID.Pad + row * (CH + GAP_Y)))
			end
			local rows = math.ceil(#list / 2)
			grid.CanvasSize = UDim2.fromOffset(0, rows > 0 and (2 * GRID.Pad + rows * CH + (rows - 1) * GAP_Y) or 0)
			if animate then Motion.stagger(cardsInOrder()) end
		else
			for _, cd in cards do cd.refresh() end
		end
		-- empty results: say why, and offer one way out
		empty.Visible = #list == 0
		grid.Visible = #list > 0
		if #list == 0 then
			local filtered = view.Search ~= "" or view.Tier ~= "All"
			if view.Tab == "Favourites" and not filtered then
				emptyTitle.Text = "No favourites yet"
				emptyHint.Text = "Tap a star on a character to add it here."
			elseif view.Tab == "Owned" and not filtered then
				emptyTitle.Text = "No characters yet"
				emptyHint.Text = "Collect characters to see them here."
			else
				emptyTitle.Text = "No characters found"
				emptyHint.Text = "Nothing matches these filters."
			end
		end
		-- keep a sensible selection: the equipped one, else the first card
		if not selected or not Characters.get(selected) then
			selected = (State.data.Equipped ~= "" and Characters.get(State.data.Equipped) and State.data.Equipped) or (list[1] and list[1].Id) or nil
			for _, cd in cards do cd.refresh() end
		end
		local tierText = view.Tier == "All" and "All" or tierName(view.Tier)
		tierDrop.setText(#tierText > 3 and tierText or ("Tier: " .. tierText)) -- longer names drop "Tier:" to fit the field
		for _, s in SORTS do if s.Key == view.Sort then sortDrop.setText("Sort: " .. s.Short) end end
		refreshPreview()
	end

	onSelect = function(id: string)
		if selected == id then return end
		selected = id
		for _, cd in cards do cd.refresh() end
		refreshPreview()
		for _, cd in cards do if cd.Id == id then Motion.pop(cd.Instance) end end
	end

	-- Tabs (page 02 #6-#8).
	local tabs = Kit.tabs(panel, {
		{ Key = "All", Text = "ALL CHARACTERS", X = 14, Width = 192 },
		{ Key = "Owned", Text = "OWNED", X = 211, Width = 126 },
		{ Key = "Favourites", Text = "FAVOURITES", X = 342, Width = 157 },
	}, 49, 27, function(key)
		view.Tab = key
		refresh(true)
	end, 17)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		placeholder.Visible = box.Text == ""
		if view.Search ~= box.Text then
			view.Search = box.Text
			refresh(false)
		end
	end)

	-- Dropdowns: a list that opens over the cards; a click anywhere else (or closing the window) shuts it.
	local catcher = new("TextButton", { Name = "DropdownCatcher", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 29, Selectable = false, Parent = panel })
	local menu = new("Frame", { Name = "DropdownMenu", BackgroundColor3 = COL.Menu, BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.MenuRim, 1) })
	local openMenu: string? = nil
	local function closeMenu()
		openMenu = nil
		menu.Visible = false
		catcher.Visible = false
	end
	catcher.Activated:Connect(closeMenu)
	local function showMenu(name: string, anchor: GuiObject, options: { { Key: string, Text: string } }, current: string, pick: (string) -> ())
		if openMenu == name then closeMenu() return end
		for _, ch in menu:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		openMenu = name
		local rowH, pad = 24, 4
		local w = math.max(math.round(anchor.Size.X.Offset), 128)
		-- Kit buttons are positioned by their centre (Kit.place): line the menu's right edge up with the field's
		local right = math.round(anchor.Position.X.Offset + anchor.Size.X.Offset / 2)
		menu.Position = UDim2.fromOffset(math.min(right, W - 8) - w, 42)
		menu.Size = UDim2.fromOffset(w, #options * rowH + 2 * pad)
		for i, o in options do
			local b = Kit.button({ Name = o.Key, Text = o.Text, Style = o.Key == current and "Selected" or "IndexItem", FontFace = F.Label, TextSize = 13, Corner = 3, Position = UDim2.fromOffset(pad, pad + (i - 1) * rowH), Size = UDim2.fromOffset(w - 2 * pad, rowH - 2), ZIndex = 31, Parent = menu })
			b.onClick(function()
				closeMenu()
				pick(o.Key)
			end)
		end
		menu.Visible = true
		catcher.Visible = true
	end
	tierDrop.onClick(function()
		local options = { { Key = "All", Text = "All tiers" } }
		for i = #Characters.Tiers, 1, -1 do -- highest first
			local t = Characters.Tiers[i]
			table.insert(options, { Key = t, Text = tierName(t) })
		end
		showMenu("Tier", tierDrop.Instance, options, view.Tier, function(key)
			view.Tier = key
			refresh(true)
		end)
	end)
	sortDrop.onClick(function()
		showMenu("Sort", sortDrop.Instance, SORTS, view.Sort, function(key)
			view.Sort = key
			refresh(true)
		end)
	end)

	clearBtn.onClick(function()
		view.Search, view.Tier, view.Tab = "", "All", "All"
		box.Text = ""
		tabs.select("All")
		refresh(true)
	end)

	favBig.onClick(function()
		if not selected then return end
		local ok, why = State.action("FavoriteCharacter", selected, not favourite(selected))
		if not ok then Toast.show(why or "Couldn't change that favourite.") end
	end)
	action.onClick(function()
		if busy or not selected then return end
		local id = selected
		busy = true
		local ok, why
		if equipped(id) then
			ok, why = State.action("Unequip")
		elseif owned(id) then
			ok, why = State.action("Equip", id)
		else
			ok, why = false, "You haven't collected this character yet."
		end
		busy = false
		if not ok then Toast.show(why or "That didn't work. Try again.") end
	end)

	State.changed(function() refresh(false) end)

	ModalManager.register("Index", {
		window = window,
		-- arg = { Tier = "MTB" } opens the index filtered to that tier (from the Tiers page)
		onOpen = function(arg)
			closeMenu()
			if type(arg) == "table" and type(arg.Tier) == "string" and table.find(Characters.Tiers, arg.Tier) then
				view.Tab, view.Search, view.Tier = "All", "", arg.Tier
				box.Text = ""
				tabs.select("All")
				local list = visibleList()
				local pick = list[1] and list[1].Id
				for _, c in list do if owned(c.Id) then pick = c.Id; break end end
				if pick then selected = pick end
				lastKey = nil
				grid.CanvasPosition = Vector2.zero
			end
			refresh(false)
		end,
		onClose = closeMenu,
		firstSelect = function() return tabs.buttons.All.Instance end,
		items = cardsInOrder,
	})
	tabs.select(view.Tab)
	refresh(false)
	return window
end

return Index
