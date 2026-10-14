-- Dances (design/pages/03): All / Owned / Favourites tabs, a search box and a Name A-Z / Z-A sort over one 2 x 2
-- card grid, with the selected dance shown large on the right. PLAY performs the dance on the player's own avatar
-- (the character's Animator, so other players see it too); STOP ends it. Starting another dance stops the last one,
-- and the dance stops on respawn and when the window closes. A dance whose animation the owner hasn't supplied yet
-- (AnimationId "") says so and never pretends to play. Locked dances can't be played.
-- Layout numbers are reference px (design/pages/03, window-relative; that page's header is the same 47 px).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Products = require(Shared.Config.Products)
local Progression = require(Shared.Config.Progression)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex

local DancesScreen = {}

local W, H = 701, 320 -- every main window shares this size
local RIM = 4 -- room inside the scrolling grid for the cards' rims and the 3 px selected outline
local GRID = { X = 17, Y = 86, CardW = 180, CardH = 105, GapX = 9, GapY = 9, Band = 29 }
local PREVIEW = { X = 400, Y = 47, W = 297, H = 262, ArtY = 17, ArtW = 212, ArtH = 206 }

-- Measured from reference 03.
local COL = {
	Card = hex("1E3A66"), CardRim = hex("3E6699"), Band = hex("10233F"), Selected = hex("F5DF55"),
	Field = hex("1B2B54"), FieldRim = hex("0E1C44"), FieldTop = hex("2C3D6E"), FieldText = hex("E3E8F7"), Hint = hex("C3CBE6"),
	PreviewTop = hex("213350"), PreviewMid = hex("1E3049"), Floor = hex("B9785E"), FloorBottom = hex("D6936F"),
	Menu = hex("1B2B54"), MenuPick = hex("2C4475"),
}

-- The big preview picture exists for Shuffle only (the kit's page 03); other dances show their card picture.
local PREVIEW_ART: { [string]: string } = { Shuffle = "DancePreview" }

local function owned(id: string): boolean return State.data.Dances[id] == true end
local function favourite(id: string): boolean return State.data.FavDances[id] == true end

-- The reward-track level that gives this dance, if any.
local function rewardLevel(id: string): number?
	for _, r in Progression.Rewards do
		if r.Kind == "Dance" and r.Id == id and not r.Unavailable then return r.Level end
	end
	return nil
end

local function packSoon(): boolean
	local pack = Products.get("DancePack")
	return pack == nil or Products.status(pack) ~= "Ready"
end

-- How a locked dance is unlocked, in one short line.
local function howToGet(d): string
	local level = rewardLevel(d.Id)
	local pack = if d.Pack then "the Dance Pack" .. (if packSoon() then " (coming soon)" else "") else nil
	if level and pack then return string.format("Unlock %s at Level %d, or with %s.", d.Name, level, pack) end
	if level then return string.format("Unlock %s at Level %d on the reward track.", d.Name, level) end
	if pack then return string.format("Get %s with %s.", d.Name, pack) end
	return d.Name .. " can't be unlocked yet."
end

-- Performing on the live avatar --------------------------------------------------------------------------------
local track: AnimationTrack? = nil

local function stopDance()
	local t = track
	track = nil
	if t then pcall(function() t:Stop(0.2) end) end
end

local function playDance(d)
	if not owned(d.Id) then
		Toast.show(howToGet(d))
		return
	end
	if d.AnimationId == "" then
		Toast.show("This dance's animation hasn't been added yet.")
		return
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		Toast.show("Your avatar isn't ready yet.")
		return
	end
	stopDance()
	local animation = Instance.new("Animation")
	animation.AnimationId = d.AnimationId
	local ok, loaded = pcall(function() return (animator :: Animator):LoadAnimation(animation) end)
	if not ok or not loaded then
		Toast.show("That dance couldn't load.")
		return
	end
	loaded.Looped = true
	loaded.Priority = Enum.AnimationPriority.Action
	loaded:Play(0.2)
	track = loaded
end

-- Header fields ----------------------------------------------------------------------------------------------------
-- A dark field in the purple header (search, sort): navy fill, dark rim, a faint lighter top line.
local function field(parent: Instance, class: string, name: string, x: number, w: number)
	local f = new(class, { Name = name, Position = UDim2.fromOffset(x, 7), Size = UDim2.fromOffset(w, 29), BackgroundColor3 = COL.Field, BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(COL.FieldRim, 1) })
	new("Frame", { Name = "TopLine", Position = UDim2.fromOffset(3, 0), Size = UDim2.new(1, -6, 0, 1), BackgroundColor3 = COL.FieldTop, BorderSizePixel = 0, Parent = f })
	if class == "TextButton" then
		f.Text = ""
		f.AutoButtonColor = false
		Motion.bindButton(f, function() return nil end)
	end
	return f
end

-- A small V drawn from two bars (the sort chevron).
local function chevron(parent: Instance, x: number)
	local holder = new("Frame", { Name = "Chevron", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Parent = parent })
	for i, rot in { 45, -45 } do
		new("Frame", { Name = "Bar" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, if i == 1 then -3 else 3, 0.5, 0), Size = UDim2.fromOffset(9, 2), Rotation = rot, BackgroundColor3 = COL.FieldText, BorderSizePixel = 0, Parent = holder }, { Kit.corner(1) })
	end
	return holder
end

function DancesScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Dances", Title = "DANCES", Icon = "DancesNote", Width = W, Height = H, TitleX = 61, TitleOffsetY = 2, TitleSize = 26, TitleWidth = 114, StudsTo = 356, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header

	local tab, query, ascending, selected = "All", "", true, nil :: string?
	local rebuild: (boolean?) -> ()

	-- Search (header coords: the header starts 4 px inside the window).
	local search = field(header, "Frame", "Search", 364, 138)
	Kit.icon("Search", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(15, 16), Parent = search })
	local hint = Kit.text({ Name = "Hint", Text = "Search dances...", FontFace = Theme.Fonts.Label, TextSize = 13, TextColor3 = COL.Hint, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), TextWrapped = false, Parent = search })
	local box: TextBox = new("TextBox", { Name = "Box", Text = "", PlaceholderText = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = Theme.Fonts.Label, TextSize = 13, TextColor3 = COL.FieldText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), ClipsDescendants = true, Parent = search })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		hint.Visible = box.Text == ""
		query = box.Text
		rebuild()
	end)

	-- Sort: opens a small menu under itself (closes on a pick, a second tap, or a tap anywhere else).
	local sort = field(header, "TextButton", "Sort", 507, 134)
	local sortLabel = Kit.text({ Name = "Label", Text = "Sort: Name A - Z", FontFace = Theme.Fonts.Label, TextSize = 12, TextColor3 = COL.FieldText, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -26, 1, 0), TextWrapped = false, Parent = sort })
	chevron(sort, 122)
	local catcher = new("TextButton", { Name = "MenuCatcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 19, Visible = false, Parent = panel })
	local menu = new("Frame", { Name = "SortMenu", Position = UDim2.fromOffset(511, 44), Size = UDim2.fromOffset(134, 62), BackgroundColor3 = COL.Menu, BorderSizePixel = 0, ZIndex = 20, Visible = false, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.FieldRim, 1) })
	local function setMenu(open: boolean)
		menu.Visible = open
		catcher.Visible = open
	end
	local options = {}
	for i, opt in { { true, "Name A - Z" }, { false, "Name Z - A" } } do
		local b = new("TextButton", { Name = if opt[1] then "AToZ" else "ZToA", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(3, 3 + (i - 1) * 28), Size = UDim2.fromOffset(128, 27), BackgroundColor3 = COL.MenuPick, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 21, Parent = menu }, { Kit.corner(3) })
		Kit.text({ Name = "Label", Text = opt[2], FontFace = Theme.Fonts.Label, TextSize = 13, TextColor3 = COL.FieldText, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -8, 1, 0), ZIndex = 21, Parent = b })
		b.Activated:Connect(function()
			ascending = opt[1]
			sortLabel.Text = "Sort: " .. opt[2]
			for asc, ob in options do ob.BackgroundTransparency = if asc == ascending then 0 else 1 end
			setMenu(false)
			rebuild(true)
		end)
		options[opt[1]] = b
	end
	options[true].BackgroundTransparency = 0
	sort.Activated:Connect(function() setMenu(not menu.Visible) end)
	catcher.Activated:Connect(function() setMenu(false) end)

	-- The grid. A ScrollingFrame clips square and would cut the cards' outside rims, so it is padded by RIM.
	local grid = new("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(GRID.X - RIM, GRID.Y - RIM), Size = UDim2.fromOffset(2 * GRID.CardW + GRID.GapX + 2 * RIM, 2 * GRID.CardH + GRID.GapY + 2 * RIM), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
	Kit.pad(RIM, RIM, RIM, RIM).Parent = grid
	local empty = Kit.text({ Name = "Empty", Text = "", TextSize = 16, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(GRID.X, GRID.Y + 70), Size = UDim2.fromOffset(2 * GRID.CardW + GRID.GapX, 40), Visible = false, Parent = panel })

	-- The preview: the selected dance large on the left of the pane, its name and a line of help on the right.
	local preview = new("Frame", { Name = "Preview", Position = UDim2.fromOffset(PREVIEW.X, PREVIEW.Y), Size = UDim2.fromOffset(PREVIEW.W, PREVIEW.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = panel }, { Kit.corner(3) })
	-- the art's blurred backdrop continues to the right, with its orange floor along the bottom (reference 03)
	local floorAt = (PREVIEW.ArtY + 169) / PREVIEW.H -- where the floor starts in the art
	new("UIGradient", { Rotation = 90, Parent = preview, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COL.PreviewTop), ColorSequenceKeypoint.new(floorAt - 0.04, COL.PreviewMid),
		ColorSequenceKeypoint.new(floorAt + 0.02, COL.Floor), ColorSequenceKeypoint.new(1, COL.FloorBottom),
	}) })
	local artBox = new("Frame", { Name = "ArtBox", Position = UDim2.fromOffset(0, PREVIEW.ArtY), Size = UDim2.fromOffset(PREVIEW.ArtW, PREVIEW.ArtH), BackgroundTransparency = 1, Parent = preview })
	local previewName = Kit.name({ Name = "DanceName", Text = "", TextSize = 20, Position = UDim2.fromOffset(PREVIEW.ArtW + 3, PREVIEW.ArtY + 80), Size = UDim2.fromOffset(PREVIEW.W - PREVIEW.ArtW - 6, 26), Parent = preview })
	local previewBlurb = Kit.text({ Name = "Blurb", Text = "", TextSize = 15, LineHeight = 1.0, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(PREVIEW.ArtW + 3, PREVIEW.ArtY + 107), Size = UDim2.fromOffset(PREVIEW.W - PREVIEW.ArtW - 6, 64), Parent = preview })

	local play = Kit.button({ Name = "Play", Text = "PLAY", Icon = "Play", IconSize = 20, Gap = 14, TextSize = 23, Style = "Action", Position = UDim2.fromOffset(412, 270), Size = UDim2.fromOffset(148, 37), Parent = panel })
	local stop = Kit.button({ Name = "Stop", Text = "STOP", Icon = "Stop", IconSize = 18, Gap = 14, TextSize = 23, Style = "Slate", Position = UDim2.fromOffset(575, 270), Size = UDim2.fromOffset(109, 37), Parent = panel })

	local function showPreview()
		for _, ch in artBox:GetChildren() do ch:Destroy() end
		local d = selected and Dances.get(selected)
		if not d then
			previewName.Text = ""
			previewBlurb.Text = "Pick a dance."
			return
		end
		local mine = owned(d.Id)
		local big = mine and PREVIEW_ART[d.Id]
		if big then
			Kit.art(big, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = artBox })
		else
			-- no large picture for this dance yet: its card picture, framed like a card
			local pic = Kit.art(if mine and d.Art then d.Art else "DanceLocked", { Name = "Picture", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 4, 0.5, -10), Size = UDim2.fromOffset(196, 78), Parent = artBox })
			Kit.corner(4).Parent = pic
			Kit.stroke(COL.CardRim, 1).Parent = pic
		end
		previewName.Text = d.Name
		previewBlurb.Text = if mine then "Play this dance with your avatar." else "Locked. " .. (if rewardLevel(d.Id) then "Reach Level " .. rewardLevel(d.Id) .. "." elseif d.Pack then "Dance Pack." else "")
	end

	local cards: { [string]: any } = {}
	local function select(id: string)
		selected = id
		for cid, c in cards do c.setSelected(cid == id) end
		showPreview()
	end

	local function toggleFavourite(id: string)
		task.spawn(function()
			local ok, why = State.action("FavoriteDance", id, not favourite(id))
			if not ok then Toast.show(why or "Couldn't change your favourites.") end
		end)
	end

	local function card(d, x: number, y: number)
		local mine = owned(d.Id)
		local c = new("TextButton", { Name = d.Id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(GRID.CardW, GRID.CardH), BackgroundColor3 = COL.Card, BorderSizePixel = 0, Parent = grid }, { Kit.corner(4) })
		local rim = Kit.stroke(COL.CardRim, 1)
		rim.Parent = c
		Motion.bindButton(c, function() return nil end)
		-- the picture runs a few px under the name band, so its rounded bottom corners never show
		local pic = Kit.art(if mine and d.Art then d.Art else "DanceLocked", { Name = "Picture", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(GRID.CardW - 2, GRID.CardH - GRID.Band + 3), Parent = c })
		Kit.corner(3).Parent = pic
		local band = new("Frame", { Name = "Band", Position = UDim2.new(0, 1, 1, -GRID.Band - 1), Size = UDim2.new(1, -2, 0, GRID.Band), BackgroundColor3 = COL.Band, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 2, Parent = c }, { Kit.corner(3) })
		Kit.name({ Name = "Name", Text = d.Name, TextSize = 17, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -16, 1, -2), ZIndex = 3, Parent = band })
		-- favourite star: filled when favourited; an outline on the selected card so it can be favourited
		local star = new("TextButton", { Name = "Star", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), Size = UDim2.fromOffset(30, 30), ZIndex = 3, Parent = c })
		local filled = Kit.icon("FavouriteFilled", { Name = "Filled", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 23), ZIndex = 3, Parent = star })
		local outline = Kit.icon("FavouriteOutline", { Name = "Outline", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 23), ZIndex = 3, Parent = star })
		local api = {}
		function api.setSelected(on: boolean)
			rim.Color = if on then COL.Selected else COL.CardRim
			rim.Thickness = if on then 3 else 1
			local fav = favourite(d.Id)
			filled.Visible = fav
			outline.Visible = on and not fav
			star.Visible = fav or on
		end
		star.Activated:Connect(function()
			Motion.pop(star)
			toggleFavourite(d.Id)
		end)
		c.Activated:Connect(function()
			setMenu(false)
			if selected ~= d.Id then select(d.Id) end
		end)
		cards[d.Id] = api
		api.setSelected(selected == d.Id)
		return c
	end

	local function visible()
		local q = string.lower(query)
		local list = {}
		for _, d in Dances.List do
			local inTab = tab == "All" or (tab == "Owned" and owned(d.Id)) or (tab == "Favourites" and favourite(d.Id))
			if inTab and (q == "" or string.find(string.lower(d.Name), q, 1, true)) then table.insert(list, d) end
		end
		table.sort(list, function(a, b)
			if ascending then return a.Name < b.Name end
			return a.Name > b.Name
		end)
		return list
	end

	local function items()
		local list = {}
		for _, ch in grid:GetChildren() do if ch:IsA("GuiButton") then table.insert(list, ch) end end
		table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		return list
	end

	function rebuild(animate: boolean?)
		cards = {}
		for _, ch in grid:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
		local list = visible()
		for i, d in list do
			local col, row = (i - 1) % 2, (i - 1) // 2
			card(d, col * (GRID.CardW + GRID.GapX), row * (GRID.CardH + GRID.GapY)).LayoutOrder = i
		end
		empty.Visible = #list == 0
		empty.Text = if query ~= "" then "No dances match \"" .. query .. "\"." elseif tab == "Favourites" then "Tap the star on a dance to add it here." else "No dances here yet."
		if animate then Motion.stagger(items()) end
		showPreview()
	end

	local tabs = Kit.tabs(panel, {
		{ Key = "All", Text = "ALL", X = 16, Width = 117 },
		{ Key = "Owned", Text = "OWNED", X = 138, Width = 107 },
		{ Key = "Favourites", Text = "FAVOURITES", X = 250, Width = 133 },
	}, 50, 29, function(key)
		tab = key
		setMenu(false)
		grid.CanvasPosition = Vector2.zero
		rebuild(true)
	end, 17)

	play.onClick(function()
		setMenu(false)
		local d = selected and Dances.get(selected)
		if not d then Toast.show("Pick a dance first.") return end
		playDance(d)
	end)
	stop.onClick(function()
		setMenu(false)
		stopDance()
	end)

	-- A new character starts without the old dance; forget the old track.
	local player = Players.LocalPlayer
	if player then
		player.CharacterAdded:Connect(stopDance)
		pcall(function() player.CharacterRemoving:Connect(stopDance) end) -- (missing from the offline preview's API copy)
	end

	State.changed(function() rebuild(false) end)

	ModalManager.register("Dances", {
		window = window,
		onOpen = function(arg)
			if type(arg) == "string" and tabs.buttons[arg] and tabs.selected() ~= arg then
				tabs.select(arg)
				tab = arg
				rebuild(false)
			end
		end,
		onClose = function()
			setMenu(false)
			stopDance()
		end,
		firstSelect = function() return tabs.buttons.All.Instance end,
		items = items,
	})
	tabs.select("All")
	-- start on the first dance the player owns (or the first one shown)
	local first = nil
	for _, d in visible() do
		if owned(d.Id) then first = d.Id break end
	end
	selected = first or (Dances.List[1] and Dances.List[1].Id)
	rebuild(false)
	return window
end

return DancesScreen
