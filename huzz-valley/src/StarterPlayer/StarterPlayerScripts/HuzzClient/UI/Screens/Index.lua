-- Character Index (design/pages/02, §7 of design/IMPLEMENTATION-PROMPT.md): All / Owned / Favourites tabs, a search
-- box and Tier / Sort dropdowns over one card grid, and a preview of the selected character on the right.
-- Ownership, equipping and favourites live on the server (ActionService); this screen only asks and redraws when
-- the new state arrives. Selection, equipped and favourite are three separate things.
-- Art: the kit's own pictures cropped from page 02 (assets/art/char-*.png) until real companion models exist.
-- Those crops still carry the kit's printed tier badge (and Aiko's star), so the live badge/star are drawn exactly
-- over them (ART below says where), and a locked card always shows the kit's dark silhouette, never coloured art.
-- Anime girls you win in rounds are listed too (Config/Characters.addGirls), drawn live from their real models.
-- PRESTIGE (owner, Oct 19: "if you get more than one of the same girl, make a button which makes them prestige that
-- gives them cooler vfx"): a girl won again saves a spare copy; the green PRESTIGE button on her picture spends one
-- and raises her to PRESTIGE 1/3, 2/3, 3/3 (shown top left of her picture). Rules: Shared/PrestigeRules.
-- The Combine machine (Oct 20): a girl shows her best grade, in her picture (Shared/GirlGrade) and as a SILVER / GOLD /
-- DIAMOND badge at the picture's bottom left (Shared/CombineRules.best; Config/Combine badge colours).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local RoundConfig = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local GirlPicture = require(UI.GirlPicture)
local PrestigeRules = require(Shared.PrestigeRules)
local CombineRules = require(Shared.CombineRules)
local CombineConfig = require(Shared.Config.Combine)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local Index = {}

local W, H = 701, 320 -- every main window shares this size

-- Colours measured on page 02 that the shared theme doesn't have.
local COL = {
	Field = hex("1E3057"), Drop = hex("1A284E"), FieldRim = hex("0E1836"), Placeholder = hex("C3CBE3"),
	CardRim = hex("2D5380"), Band = hex("182C45"), ArtBack = hex("223B6E"), ArtTop = hex("3557A0"), Select = Theme.Colors.Accent,
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

-- The card pictures are the owner's clean see-through renders (no printed badge or star), so every card uses the
-- same live badge and star spots, in card px (card art 151 x 83).
local CARD_ART = { BadgeX = 101, BadgeR = 3, BadgeH = 22, Star = Vector2.new(5, 4) }
-- The big preview picture (whole character); locked characters show the silhouette.
local FULL_ART: { [string]: string } = {} -- (the kit's mock-up companions had full pictures; won girls draw their model)

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
-- A girl's badge says her roller rarity in its colour (Secret is near-black, so it gets a deep violet).
local RARITY_COLOR = {}
for _, r in RoundConfig.Rarities do RARITY_COLOR[r.Name] = r.Color end
RARITY_COLOR.Secret = hex("2A1840")
local function badgeText(c): string return if c.Rarity then string.upper(c.Rarity) else tierName(c.Tier) end
local function badgeColor(c): Color3 return if c.Rarity then (RARITY_COLOR[c.Rarity] or C.Slate) else tierColor(c.Tier) end

-- A girl's picture: her still model in a ViewportFrame (UI/GirlPicture).
local function gradeOf(c): string? return if c.Model and owned(c.Id) then CombineRules.best(State.data, c.Id) else nil end
local function girlPicture(parent: Instance, c, isOwned: boolean, whole: boolean): ViewportFrame?
	return GirlPicture.draw(parent, c.Model, isOwned, whole, if isOwned then gradeOf(c) else nil)
end

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

-- A tier badge: coloured, white caps, as wide as its word (Kit.badge measures it) but never wider than maxW, so
-- LEGENDARY / UNCOMMON never run past the card or the window (owner's screenshot: COMMON stuck out of the Index).
-- Anchored at its top-right corner. textSize is the real size (Kit.badge doesn't narrow it).
local function badge(parent: Instance, c, pos: UDim2, maxW: number, h: number, textSize: number, z: number)
	return Kit.badge({
		Name = "TierBadge", Text = badgeText(c), Color = badgeColor(c), Height = h, TextSize = textSize,
		MinTextSize = math.max(8, textSize - 4), MaxWidth = maxW, AnchorPoint = Vector2.new(1, 0), Position = pos, ZIndex = z, Parent = parent,
	})
end

-- The character picture with only its top corners rounded (one rounded copy plus a square copy clipped below the
-- corners: ClipsDescendants clips square in Roblox) on its blue backdrop, and the live tier badge. scale = picture size / card art size. Returns the art's info (for the star position).
local function picture(parent: Instance, c, isOwned: boolean, w: number, h: number, scale: number, rounded: { top: boolean, bottom: boolean })
	local artName = if c.Model then nil elseif isOwned then c.Art else "CharLocked"
	-- a blue backdrop behind the see-through picture (lighter at the top, like the reference's card scenes)
	local holder = new("Frame", { Name = "Art", Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.ArtTop, COL.ArtBack), Parent = holder })
	local r = 4
	Kit.attach(Kit.corner(r), holder)
	new("Frame", { Name = "SquareFoot", Position = UDim2.new(0, 0, 1, -r), Size = UDim2.new(1, 0, 0, r), BackgroundColor3 = COL.ArtBack, BorderSizePixel = 0, Visible = not rounded.bottom, Parent = holder })
	if c.Model then
		if not girlPicture(holder, c, isOwned, false) then
			Kit.text({ Name = "NoArt", Text = "?", TextSize = math.floor(30 * scale), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = holder })
		end
	elseif artName then
		Kit.attach(Kit.corner(r), Kit.art(artName, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = holder }))
		-- square copies cover the corners that should stay square
		if not rounded.bottom then
			local lower = new("Frame", { Name = "Lower", Position = UDim2.fromOffset(0, r), Size = UDim2.new(1, 0, 1, -r), BackgroundTransparency = 1, ClipsDescendants = true, Parent = holder })
			Kit.art(artName, { Name = "Picture", Position = UDim2.fromOffset(0, -r), Size = UDim2.fromOffset(w, h), Parent = lower })
		end
	else
		-- owned, but the kit has no picture for this character yet (honest placeholder)
		Kit.text({ Name = "NoArt", Text = "Picture coming soon", TextSize = math.floor(13 * scale), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = holder })
	end
	local info = CARD_ART
	local right = math.round(info.BadgeR * scale)
	local maxW = w - right - math.round((info.Star.X + 30) * scale) -- (clear of the favourite star, top left)
	badge(holder, c, UDim2.new(1, -right, 0, 0), maxW, math.round(info.BadgeH * scale), math.round(13 * scale), 3)
	local grade = if isOwned then gradeOf(c) else nil
	if grade and CombineRules.label(grade) ~= "" then -- (the Combine machine's grade, bottom left)
		Kit.badge({
			Name = "GradeBadge", Text = CombineRules.label(grade), Color = CombineConfig.Grades[grade].Badge, TextColor = C.Frame,
			Height = math.round(18 * scale), TextSize = math.round(12 * scale), MinTextSize = 8, MaxWidth = w - 8,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, math.round(4 * scale), 1, -math.round(4 * scale)), ZIndex = 3, Parent = holder,
		})
	end
	return holder, info
end

-- Grid cards ------------------------------------------------------------------------------------------------------

type Card = { Instance: TextButton, Id: string, refresh: () -> () }
local cards: { Card } = {} -- the shown cards, in grid order
local cardById: { [string]: Card } = {}
local onSelect: (string) -> () = function() end

local function card(parent: Instance, c, x: number, y: number): Card
	local btn = new("TextButton", { Name = c.Id, Text = "", AutoButtonColor = false, Selectable = true, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CH), BackgroundColor3 = COL.Band, BorderSizePixel = 0, Parent = parent }, { Kit.corner(4) })
	local rim = Kit.stroke(COL.CardRim, 1)
	rim.Name = "Rim"
	rim = Kit.attach(rim, btn)
	Motion.bindButton(btn, function() return nil end) -- hover lift and press squish; the fill stays
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
	local name = Kit.name({ Name = "Name", Text = c.Name, TextSize = 16, Position = UDim2.fromOffset(9, ART_H), Size = UDim2.fromOffset(80, CH - ART_H), Parent = btn })
	local status = new("Frame", { Name = "Status", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, ART_H), Size = UDim2.fromOffset(90, CH - ART_H), BackgroundTransparency = 1, Parent = btn },
		{ Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	local statusIcon: ImageLabel? = nil
	local statusText = Kit.text({ Name = "Text", Text = "", FontFace = F.Body, TextSize = 15, TextColor3 = COL.Status, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextWrapped = false, LayoutOrder = 2, Parent = status })
	local favBtn = new("TextButton", { Name = "Favourite", Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), ZIndex = 6, Parent = btn })
	local star: ImageLabel? = nil
	local shown = { owned = nil :: boolean?, fav = nil :: boolean?, eq = nil :: boolean?, grade = nil :: string? }
	local info

	local function refresh()
		local isOwned, isFav, isEq = owned(c.Id), favourite(c.Id), equipped(c.Id)
		local grade = gradeOf(c)
		if isOwned ~= shown.owned or grade ~= shown.grade then
			shown.grade = grade
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
			-- The name fills the band left of the status, shrinking (16 to 13) and then cut with "..."; a name too long
			-- for that keeps only the status tick (no word), so it can use the room (long names spilled over "Owned").
			local word = isOwned and (isEq and "Equipped" or "Owned") or ""
			statusText.Text = word
			local function room(): number
				local w = if statusIcon then 20 else 0
				if statusText.Text ~= "" then w += 5 + math.ceil(Kit.textWidth(statusText.Text, statusText.FontFace, statusText.TextSize)) end
				return CW - 9 - 8 - w - 6
			end
			if word ~= "" and Kit.textWidth(c.Name, name.FontFace, 13) + 1 > room() then statusText.Text = "" end
			Kit.fitLine(name, room(), 16, 12)
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
	local window = Kit.window({ Name = "Index", Flat = true, Title = "CHARACTER INDEX", Icon = "CollectionBook", Width = W, Height = H, TitleSize = 21, TitleX = 58, TitleOffsetY = 1, TitleWidth = 219, StudsTo = 300, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- Header: search, tier and sort (page 02 #3-#5, measured; the window is 7 px narrower than the page's, taken
	-- from the gaps on the right).
	local search = new("Frame", { Name = "Search", Position = UDim2.fromOffset(302, 9), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = COL.Field, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.FieldRim, 1) })
	Kit.icon("Search", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(15, 16), ZIndex = 2, Parent = search })
	local placeholder = Kit.text({ Name = "Placeholder", Text = "Search characters...", FontFace = F.Label, TextSize = 12, TextColor3 = COL.Placeholder, Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -36, 1, 0), TextWrapped = false, ZIndex = 2, Parent = search })
	Kit.fitLine(placeholder, 114, 12, 10) -- (it ran a few px past the field)
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
	nameLabel = Kit.attach(nameLabel, nameRow)
	local nameBadge: TextLabel? = nil
	for _, old in nameRow:GetChildren() do -- (the badge used to sit in this row: drop a copy saved there)
		if old.Name == "TierBadge" then old:Destroy() end
	end
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
	-- prestige: her level top left of her picture, and the PRESTIGE button at its foot while a spare copy waits
	-- (150 wide: her rarity badge sits at the picture's top right, from x 515)
	local prestigeLine = Kit.text({ Name = "PrestigeLevel", Text = "", FontFace = F.Heading, TextSize = 15, TextColor3 = C.Accent, TextWrapped = false, Position = UDim2.fromOffset(355, 84), Size = UDim2.fromOffset(150, 20), ZIndex = 4, Visible = false, Parent = panel })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = prestigeLine })
	local spareLine = Kit.text({ Name = "PrestigeSpare", Text = "", FontFace = F.Name, TextSize = 12, TextColor3 = C.SubText, TextWrapped = false, Position = UDim2.fromOffset(355, 104), Size = UDim2.fromOffset(150, 16), ZIndex = 4, Visible = false, Parent = panel })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.2, LineJoinMode = Enum.LineJoinMode.Round, Parent = spareLine })
	local prestigeBtn = Kit.button({ Name = "Prestige", Style = "Selected", Text = "PRESTIGE", FontFace = F.Button, TextSize = 16, Corner = 5, RimThickness = 2, Position = UDim2.fromOffset(355, 276), Size = UDim2.fromOffset(132, 34), ZIndex = 4, Parent = panel })
	prestigeBtn.Instance.Visible = false

	local shownPreview = ""
	local function refreshPreview()
		local c = selected and Characters.get(selected)
		local visible = c ~= nil
		for _, g in { previewArt, info, favBig.Instance, nameRow, statusRow, action.Instance } do g.Visible = visible end
		prestigeLine.Visible, spareLine.Visible, prestigeBtn.Instance.Visible = false, false, false
		if not c then return end
		local isOwned, isEq, isFav = owned(c.Id), equipped(c.Id), favourite(c.Id)
		if isOwned then
			local level, copies = PrestigeRules.level(State.data, c.Id), PrestigeRules.copies(State.data, c.Id)
			prestigeLine.Visible = level > 0 or copies > 0
			prestigeLine.Text = PrestigeRules.label(level)
			spareLine.Visible = copies > 0 and level < PrestigeRules.Max
			spareLine.Text = if copies == 1 then "1 spare copy" else `{copies} spare copies`
			prestigeBtn.Instance.Visible = (PrestigeRules.can(State.data, c.Id))
		end
		-- picture: the whole character (or the locked silhouette); a character with no big picture shows its card
		local key = c.Id .. (isOwned and "+" or "-") .. (gradeOf(c) or "")
		if key ~= shownPreview then
			shownPreview = key
			for _, ch in previewArt:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
			local full = if c.Model then nil elseif isOwned then FULL_ART[c.Id] else "CharLockedFull"
			local girl = c.Model and new("Frame", { Name = "Girl", Size = UDim2.fromOffset(216, 238), BackgroundTransparency = 1, Parent = previewArt })
			local grade = gradeOf(c)
			if girl and grade and CombineRules.label(grade) ~= "" then -- (her Combine grade, bottom left of her picture)
				Kit.badge({ Name = "GradeBadge", Text = CombineRules.label(grade), Color = CombineConfig.Grades[grade].Badge, TextColor = C.Frame, Height = 22, TextSize = 14, MinTextSize = 9, MaxWidth = 120, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), ZIndex = 3, Parent = girl })
			end
			if girl and girlPicture(girl, c, isOwned, true) then
				-- her rarity glows up from the floor behind her
				local glow = new("Frame", { Name = "Glow", ZIndex = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = badgeColor(c), BorderSizePixel = 0, Parent = girl }, { Kit.corner(3) })
				new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = glow })
			elseif full then
				Kit.attach(Kit.corner(3), Kit.art(full, { Name = "Picture", Size = UDim2.fromOffset(216, 238), Parent = previewArt }))
			else
				local s = 1.3
				local frame = new("Frame", { Name = "Framed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(108, 70), Size = UDim2.fromOffset(math.round(CW * s), math.round(ART_H * s)), BackgroundTransparency = 1, Parent = previewArt }, { Kit.stroke(COL.CardRim, 1) })
				picture(frame, c, isOwned, math.round(CW * s), math.round(ART_H * s), s, { top = true, bottom = true })
			end
		end
		-- The name gets the whole column (128 px): one line from 26 down to 19; a longer name takes two lines (19 to
		-- 16) growing up from the row's foot; else one line down to 14, then "...". Her rarity badge sits on the
		-- picture's top right corner, as on her card: the column is too narrow for name and badge side by side
		-- (UNCOMMON alone is ~90 px at a readable size), which is how COMMON ended up past the window's edge.
		nameLabel.Text = c.Name
		local twoLines = false
		if Kit.textWidth(c.Name, nameLabel.FontFace, 19) + 1 > 128 and string.find(c.Name, " ") then
			twoLines = Kit.fitBlock(nameLabel, 128, 2, 19, 16) ~= nil
		end
		if not twoLines then Kit.fitLine(nameLabel, 128, 26, 14) end
		local rowH = if twoLines then nameLabel.Size.Y.Offset else 32
		nameLabel.Size = UDim2.fromOffset(nameLabel.Size.X.Offset, rowH)
		nameRow.Position, nameRow.Size = UDim2.fromOffset(565, 149 - rowH), UDim2.fromOffset(128, rowH)
		if nameBadge then nameBadge:Destroy() end
		nameBadge = nil
		if not previewArt:FindFirstChild("Framed") then -- (a card picture already wears its badge)
			nameBadge = badge(previewArt, c, UDim2.new(1, -6, 0, 3), 112, 22, 15, 3)
		end
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
			actionIcon = Kit.icon(locked and "Lock" or "ShirtEquip", { Name = "Icon", Size = UDim2.fromOffset(locked and 18 or 26, locked and 21 or 24), LayoutOrder = 1, ImageColor3 = locked and Color3.new(1, 1, 1) or COL.EquipText, ZIndex = 3, Parent = action.Instance:FindFirstChild("Content") })
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
			-- Cards are kept per character and only moved or hidden (each girl's card holds her 3D model, too
			-- costly to rebuild on every search key). Example cards saved in StarterGui are cleared once.
			if not next(cardById) then
				for _, ch in grid:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
			end
			local shown = {}
			cards = {}
			for i, c in list do
				local col, row = (i - 1) % 2, (i - 1) // 2
				local x, y = GRID.Pad + col * (CW + GAP_X), GRID.Pad + row * (CH + GAP_Y)
				local cd = cardById[c.Id]
				if cd then
					-- (a slide-in in progress, or Motion.stagger's remembered spot, would put it back)
					Motion.tween(cd.Instance, "slide", 0, { Position = UDim2.fromOffset(x, y) })
					cd.Instance:SetAttribute("HomePosition", UDim2.fromOffset(x, y))
					cd.refresh()
				else
					cd = card(grid, c, x, y)
					cardById[c.Id] = cd
				end
				cd.Instance.Visible = true
				shown[c.Id] = true
				table.insert(cards, cd)
			end
			for id, cd in cardById do
				if not shown[id] then cd.Instance.Visible = false end
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
	prestigeBtn.onClick(function()
		if busy or not selected then return end
		local id = selected
		busy = true
		prestigeBtn.setEnabled(false)
		local ok, result = State.action("Prestige", id)
		busy = false
		prestigeBtn.setEnabled(true)
		local c = Characters.get(id)
		if ok then
			Toast.show(`{c and c.Name or "She"} is {PrestigeRules.label(tonumber(result) or 1)}! Cooler effects.`)
			Motion.pop(previewArt)
		else
			Toast.show(result or "That didn't work. Try again.")
		end
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

	-- Girls replicate a moment after joining, so the list is topped up whenever the window opens or your save
	-- changes (a girl you just won is always in the folder by then).
	local function syncGirls()
		local girlFolder = GirlPicture.folder()
		if girlFolder and Characters.addGirls(girlFolder) then
			lastKey, shownPreview = nil, ""
		end
	end
	State.changed(function()
		syncGirls()
		refresh(false)
	end)
	syncGirls()

	ModalManager.register("Index", {
		window = window,
		-- arg = { Tier = "MTB" } opens the index filtered to that tier (from the Tiers page)
		onOpen = function(arg)
			closeMenu()
			syncGirls()
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
