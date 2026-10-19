-- Dances, after the owner's Oct 17 mockup (design/ui-oct17/shop-items-coins-dances.png, bottom right): ALL / OWNED
-- / FAVOURITES tabs, a search box and a Name A-Z / Z-A sort over a 3 column card grid, with the selected dance shown
-- large on the right (big picture, name, one line about it, PLAY and STOP). PLAY performs the dance on the player's
-- own avatar (UI/DancePlayer: other players see it too); STOP ends it. A dance whose animation isn't published yet
-- says so and never pretends to play. Locked dances (Dance Pack pass, reward track) can't be played; tapping PLAY
-- says how to get them. The star on a card saves it as a favourite (server-checked, ActionService FavoriteDance).
-- Each card glows in its dance's colour (Config/Dances Color) with glowing notes (assets/art/dance-fx-*, ours) and
-- shows your avatar frozen in the dance's most telling moment (UI/DancePose: a still picture, so the grid never
-- lags). Until that picture can be made (no character yet, or the dance not published in the live game) a white
-- blocky figure in the same pose stands in (assets/art/dance-still-*, ours), tinted like the mockup's figures. The
-- big picture shows your avatar actually dancing (a copy in a ViewportFrame) once the dance can play.
-- Layout numbers are the mockup's, measured and scaled to the 701 x 320 window (x 0.77).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Products = require(Shared.Config.Products)
local Progression = require(Shared.Config.Progression)
local Crates = require(Shared.Config.Crates)
local AnimationLibrary = require(Shared.AnimationLibrary)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local DancePlayer = require(UI.DancePlayer)
local DancePose = require(UI.DancePose)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)

local DancesScreen = {}

local W, H = 701, 320 -- every main window shares this size
local RIM = 6 -- room inside the scrolling grid for the cards' rims and the selected card's glow
local GRID = { PanelX = 10, PanelY = 83, PanelW = 377, PanelH = 215, Pad = 5, CardW = 116, CardH = 98, GapX = 8, GapY = 8, Band = 23, Cols = 3, PicH = 77 }
local PREVIEW = { X = 395, Y = 48, W = 298, H = 259, ArtX = 4, ArtY = 5, ArtH = 157, BtnY = 252, BtnH = 49, PlayX = 405, PlayW = 134, StopX = 552, StopW = 131 }

-- Measured from the mockup.
local COL = {
	Card = hex("10133A"), CardRim = hex("3A5590"), Band = hex("0B1238"), Selected = hex("E7A0FF"), Halo = hex("B15CF0"),
	Panel = hex("0B1236"), PanelRim = hex("26386E"),
	Field = hex("1B2B54"), FieldRim = hex("0E1C44"), FieldTop = hex("2C3D6E"), FieldText = hex("E3E8F7"), Hint = hex("C3CBE6"),
	PreviewTop = hex("142050"), PreviewBottom = hex("0E1640"), PreviewRim = hex("4969AF"),
	ArtTop = hex("16122E"), ArtBottom = hex("0C0A1E"), ArtRim = hex("2B3874"), Blurb = hex("C9CDF5"),
	Menu = hex("1B2B54"), MenuPick = hex("2C4475"), Locked = hex("1A2140"),
}

local function owned(id: string): boolean return State.data.Dances[id] == true end
local function favourite(id: string): boolean return State.data.FavDances[id] == true end
local function colorOf(d): Color3 return Dances.Colors[d.Color] or Dances.Colors.Violet end

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

-- The crate a dance can come out of (owner, Oct 19: "dances, from crates"), or nil.
local function crateFor(id: string): string?
	for _, c in Crates.List do
		for _, it in c.Items do
			if it.Kind == "Dance" and it.Id == id then return c.Name end
		end
	end
	return nil
end

-- How a locked dance is unlocked, in one short line.
local function howToGet(d): string
	local level = rewardLevel(d.Id)
	local crate = crateFor(d.Id)
	local pack = if d.Pack then "the Dance Pack" .. (if packSoon() then " (coming soon)" else "") elseif crate then "the " .. crate else nil
	if level and pack then return string.format("Unlock %s at Level %d, or with %s.", d.Name, level, pack) end
	if level then return string.format("Unlock %s at Level %d on the reward track.", d.Name, level) end
	if pack then return string.format("Get %s with %s.", d.Name, pack) end
	return d.Name .. " can't be unlocked yet."
end

-- Performing on the live avatar (UI/DancePlayer: walking away stops it, as the G wheel's dances) --------------
local function playDance(d)
	if not owned(d.Id) then
		Toast.show(howToGet(d))
		return
	end
	local ok, why = DancePlayer.play(d.Id)
	if not ok then Toast.show(why or "That dance couldn't play.") end
end
local stopDance = DancePlayer.stop

-- Header fields ----------------------------------------------------------------------------------------------------
-- A dark field in the purple header (search, sort): navy fill, dark rim, a faint lighter top line.
local function field(parent: Instance, class: string, name: string, x: number, w: number)
	local f = new(class, { Name = name, Position = UDim2.fromOffset(x, 6), Size = UDim2.fromOffset(w, 31), BackgroundColor3 = COL.Field, BorderSizePixel = 0, Parent = parent }, { Kit.corner(5), Kit.stroke(COL.FieldRim, 1) })
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

-- The glowing backdrop of a dance picture: a dark fill lit in the dance's colour, the soft glow (floor light, halos)
-- and the crisp notes and sparkles on top, all tinted. Returns the frame the figure goes in.
local function glow(parent: Instance, d, size: Vector2, pos: Vector2, corner: number)
	local color = colorOf(d)
	local back = new("Frame", { Name = "Glow", Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = parent }, { Kit.corner(corner) })
	new("UIGradient", { Name = "Light", Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COL.ArtBottom), ColorSequenceKeypoint.new(0.55, color:Lerp(COL.ArtBottom, 0.72)), ColorSequenceKeypoint.new(1, color:Lerp(COL.ArtBottom, 0.5)),
	}), Parent = back })
	Kit.art("DanceFxGlow", { Name = "FxGlow", Size = UDim2.fromScale(1, 1), ImageColor3 = color, Parent = back })
	Kit.art("DanceFxCore", { Name = "FxCore", Size = UDim2.fromScale(1, 1), ImageColor3 = color:Lerp(WHITE, 0.55), Parent = back })
	return back
end

-- The dance's figure: the white stand-in (tinted, or a dark silhouette with a lock when locked), and your avatar in
-- the same pose over it (the whole picture area: UI/DancePose frames it) once that picture is ready; then the
-- stand-in hides.
local function figure(parent: Instance, d, size: Vector2, pos: Vector2, area: Vector2, mine: boolean, lockSize: number)
	local color = colorOf(d)
	local still = Kit.art("DanceStill" .. d.Id, { Name = "Figure", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), ImageColor3 = if mine then color:Lerp(WHITE, 0.62) else COL.Locked, ZIndex = 2, Parent = parent })
	if not mine then
		Kit.icon("Lock", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, pos.Y + math.floor(size.Y / 2)), Size = UDim2.fromOffset(lockSize, math.round(lockSize * 1.18)), ZIndex = 3, Parent = parent })
	end
	local player = Players.LocalPlayer
	if player and player.Character then
		local vp = DancePose.picture(parent, d.Id, { Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(area.X, area.Y), ZIndex = 2 }, not mine)
		local function ready() if vp.Parent and vp:FindFirstChildOfClass("Model") then still.Visible = false end end
		pcall(function() vp.ChildAdded:Connect(ready) end) -- (the offline harness has no ChildAdded)
		ready()
	end
	return still
end

function DancesScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Dances", Title = "DANCES", Icon = "DancesNote", Width = W, Height = H, TitleX = 61, TitleOffsetY = 2, TitleSize = 26, TitleWidth = 114, StudsTo = 344, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header

	local tab, query, ascending, selected = "All", "", true, nil :: string?
	local rebuild: (boolean?) -> ()

	-- Search (header coords: the header starts 4 px inside the window).
	local search = field(header, "Frame", "Search", 352, 135)
	Kit.icon("Search", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(15, 16), Parent = search })
	local hint = Kit.text({ Name = "Hint", Text = "Search dances...", FontFace = Theme.Fonts.Label, TextSize = 11, TextColor3 = COL.Hint, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), TextWrapped = false, Parent = search })
	local box: TextBox = new("TextBox", { Name = "Box", Text = "", PlaceholderText = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = Theme.Fonts.Label, TextSize = 11, TextColor3 = COL.FieldText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), ClipsDescendants = true, Parent = search })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		hint.Visible = box.Text == ""
		query = box.Text
		rebuild()
	end)

	-- Sort: opens a small menu under itself (closes on a pick, a second tap, or a tap anywhere else).
	local sort = field(header, "TextButton", "Sort", 500, 136)
	local sortLabel = Kit.text({ Name = "Label", Text = "Sort: Name A - Z", FontFace = Theme.Fonts.Label, TextSize = 11, TextColor3 = COL.FieldText, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -26, 1, 0), TextWrapped = false, Parent = sort })
	chevron(sort, 121)
	local catcher = new("TextButton", { Name = "MenuCatcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 19, Visible = false, Parent = panel })
	local menu = new("Frame", { Name = "SortMenu", Position = UDim2.fromOffset(504, 44), Size = UDim2.fromOffset(136, 62), BackgroundColor3 = COL.Menu, BorderSizePixel = 0, ZIndex = 20, Visible = false, Parent = panel }, { Kit.corner(4), Kit.stroke(COL.FieldRim, 1) })
	local function setMenu(open: boolean)
		menu.Visible = open
		catcher.Visible = open
	end
	local options = {}
	for i, opt in { { true, "Name A - Z" }, { false, "Name Z - A" } } do
		local b = new("TextButton", { Name = if opt[1] then "AToZ" else "ZToA", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(3, 3 + (i - 1) * 28), Size = UDim2.fromOffset(130, 27), BackgroundColor3 = COL.MenuPick, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 21, Parent = menu }, { Kit.corner(3) })
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

	-- The grid: a darker inset panel holding a scrolling 3 column grid (two rows show). A ScrollingFrame clips
	-- square and would cut the cards' rims and the selected glow, so it is padded by RIM.
	new("Frame", { Name = "GridPanel", Position = UDim2.fromOffset(GRID.PanelX, GRID.PanelY), Size = UDim2.fromOffset(GRID.PanelW, GRID.PanelH), BackgroundColor3 = COL.Panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = panel }, { Kit.corner(6), Kit.stroke(COL.PanelRim, 1) })
	local gridW = GRID.Cols * GRID.CardW + (GRID.Cols - 1) * GRID.GapX
	local gridX, gridY = GRID.PanelX + GRID.Pad, GRID.PanelY + GRID.Pad
	local grid = new("ScrollingFrame", { Name = "Grid", Position = UDim2.fromOffset(gridX - RIM, gridY - RIM), Size = UDim2.fromOffset(gridW + 2 * RIM, 2 * GRID.CardH + GRID.GapY + 2 * RIM), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
	Kit.attach(Kit.pad(RIM, RIM, RIM, RIM), grid)
	local empty = Kit.text({ Name = "Empty", Text = "", TextSize = 16, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(gridX, gridY + 80), Size = UDim2.fromOffset(gridW, 40), Visible = false, Parent = panel })

	-- The preview: a navy card with the selected dance's big picture on top, its name and one line underneath, and
	-- PLAY and STOP side by side along the bottom.
	local preview = new("Frame", { Name = "Preview", Position = UDim2.fromOffset(PREVIEW.X, PREVIEW.Y), Size = UDim2.fromOffset(PREVIEW.W, PREVIEW.H), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = panel }, { Kit.corner(6), Kit.stroke(COL.PreviewRim, 1) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.PreviewTop, COL.PreviewBottom), Parent = preview })
	local artW = PREVIEW.W - 2 * PREVIEW.ArtX
	local artBox = new("Frame", { Name = "ArtBox", Position = UDim2.fromOffset(PREVIEW.ArtX, PREVIEW.ArtY), Size = UDim2.fromOffset(artW, PREVIEW.ArtH), BackgroundColor3 = COL.ArtBottom, BorderSizePixel = 0, Parent = preview }, { Kit.corner(5), Kit.stroke(COL.ArtRim, 1) })
	local previewName = Kit.name({ Name = "DanceName", Text = "", FontFace = Theme.Fonts.Heading, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 150), Size = UDim2.fromOffset(PREVIEW.W - 8, 26), ZIndex = 3, Parent = preview })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = previewName })
	local previewBlurb = Kit.text({ Name = "Blurb", Text = "", FontFace = Theme.Fonts.Label, TextSize = 12, TextColor3 = COL.Blurb, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(6, 177), Size = UDim2.fromOffset(PREVIEW.W - 12, 20), Parent = preview })

	local play = Kit.button({ Name = "Play", Text = "PLAY", Icon = "Play", IconSize = 20, Gap = 12, TextSize = 24, FontFace = Theme.Fonts.Heading, Style = "DancePlay", Corner = 6, Position = UDim2.fromOffset(PREVIEW.PlayX, PREVIEW.BtnY), Size = UDim2.fromOffset(PREVIEW.PlayW, PREVIEW.BtnH), Parent = panel })
	local stop = Kit.button({ Name = "Stop", Text = "STOP", Icon = "Stop", IconSize = 14, Gap = 14, TextSize = 22, FontFace = Theme.Fonts.Heading, Style = "Slate", Corner = 6, Position = UDim2.fromOffset(PREVIEW.StopX, PREVIEW.BtnY), Size = UDim2.fromOffset(PREVIEW.StopW, PREVIEW.BtnH), Parent = panel })

	-- Your avatar doing the selected dance: a copy of your character in a ViewportFrame (a WorldModel inside, so
	-- its Animator runs), seen from the front. Rebuilt only when the dance or your character changes.
	local stage = new("ViewportFrame", { Name = "Stage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 180, 200), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.8), Visible = false, ZIndex = 3, Parent = artBox }, { Kit.corner(5) })
	local shownDance, shownChar = nil, nil
	-- A still copy of your character for a ViewportFrame: no scripts, name tags or effects, standing at the origin.
	local function avatarCopy(character: Model): Model
		local was = character.Archivable
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = was
		for _, x in copy:GetDescendants() do
			if x:IsA("LuaSourceContainer") or x:IsA("BillboardGui") or x:IsA("ParticleEmitter") or x:IsA("Highlight") or x:IsA("Trail") or x:IsA("Beam") or x:IsA("Light") then x:Destroy() end
		end
		local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		copy:PivotTo(CFrame.new(0, 0, 0))
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		return copy
	end
	local function showDancer(d): boolean
		local player = Players.LocalPlayer
		local character = player and player.Character
		local id = AnimationLibrary.id("Dance_" .. d.Id, d.AnimationId)
		if not character or id == "" then
			stage.Visible = false
			return false
		end
		stage.Visible = true
		if shownDance == d.Id and shownChar == character then return true end
		shownDance, shownChar = d.Id, character
		for _, ch in stage:GetChildren() do
			if not ch:IsA("UICorner") then ch:Destroy() end
		end
		local ok = pcall(function()
			local world = Instance.new("WorldModel")
			world.Parent = stage
			local copy = avatarCopy(character)
			copy.Parent = world
			local cam = Instance.new("Camera")
			cam.FieldOfView = 34
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -11.5), Vector3.new(0, -0.2, 0))
			cam.Parent = stage
			stage.CurrentCamera = cam
			local humanoid = copy:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local t = (animator :: Animator):LoadAnimation(animation)
			t.Looped = true
			t:Play(0)
		end)
		if not ok then stage.Visible = false end
		return ok
	end

	local function showPreview()
		for _, n in { "Glow", "Figure", "Lock", "Dancer" } do
			local old = artBox:FindFirstChild(n)
			while old do old:Destroy(); old = artBox:FindFirstChild(n) end
		end
		local d = selected and Dances.get(selected)
		if not d then
			previewName.Text = ""
			previewBlurb.Text = "Pick a dance."
			stage.Visible = false
			return
		end
		local mine = owned(d.Id)
		glow(artBox, d, Vector2.new(artW, PREVIEW.ArtH), Vector2.zero, 5)
		-- the figure stands on the glowing floor, as big as the box allows
		local fig = figure(artBox, d, Vector2.new(128, 128), Vector2.new(math.floor((artW - 128) / 2), 14), Vector2.new(artW - 2, PREVIEW.ArtH - 2), mine, 30)
		if mine and showDancer(d) then
			fig.Visible = false -- (your avatar is dancing it)
			local still = artBox:FindFirstChild("Dancer")
			if still then still:Destroy() end
		else
			stage.Visible = false
		end
		previewName.Text = d.Name
		previewBlurb.Text = if mine then d.Blurb else "Locked. " .. (if rewardLevel(d.Id) then "Reach Level " .. rewardLevel(d.Id) .. "." elseif d.Pack then "Get it with the Dance Pack." elseif crateFor(d.Id) then "Get it from the " .. crateFor(d.Id) .. "." else "")
	end

	local cards: { [string]: any } = {}
	local picked = false -- (the player chose a card: keep it)
	local function select(id: string)
		selected, picked = id, true
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
		local c = new("TextButton", { Name = d.Id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(GRID.CardW, GRID.CardH), BackgroundColor3 = COL.Card, BorderSizePixel = 0, Parent = grid }, { Kit.corner(6) })
		local rim = Kit.stroke(COL.CardRim, 1.5)
		rim = Kit.attach(rim, c)
		-- the selected card's soft outer glow: a wider see-through ring just outside the rim
		local halo = new("Frame", { Name = "Halo", Position = UDim2.fromOffset(-3, -3), Size = UDim2.new(1, 6, 1, 6), BackgroundTransparency = 1, Visible = false, Parent = c }, { Kit.corner(8) })
		new("UIStroke", { Name = "Glow", Color = COL.Halo, Thickness = 3, Transparency = 0.45, Parent = halo })
		Motion.bindButton(c, function() return nil end)
		glow(c, d, Vector2.new(GRID.CardW - 2, GRID.PicH), Vector2.new(1, 1), 5)
		figure(c, d, Vector2.new(72, 72), Vector2.new(math.floor((GRID.CardW - 72) / 2), 4), Vector2.new(GRID.CardW - 2, GRID.PicH), mine, 22)
		local band = new("Frame", { Name = "Band", Position = UDim2.new(0, 1, 1, -GRID.Band - 1), Size = UDim2.new(1, -2, 0, GRID.Band), BackgroundColor3 = COL.Band, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 2, Parent = c }, { Kit.corner(5) })
		Kit.name({ Name = "Name", Text = d.Name, TextSize = 12, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -12, 1, -1), ZIndex = 3, Parent = band })
		-- favourite star: filled when favourited; an outline on the selected card so it can be favourited
		local star = new("TextButton", { Name = "Star", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = c })
		local filled = Kit.icon("FavouriteFilled", { Name = "Filled", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 19), ZIndex = 3, Parent = star })
		local outline = Kit.icon("FavouriteOutline", { Name = "Outline", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 19), ZIndex = 3, Parent = star })
		local api = {}
		function api.setSelected(on: boolean)
			rim.Color = if on then COL.Selected else COL.CardRim
			rim.Thickness = if on then 2 else 1.5
			halo.Visible = on
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
			local col, row = (i - 1) % GRID.Cols, (i - 1) // GRID.Cols
			card(d, col * (GRID.CardW + GRID.GapX), row * (GRID.CardH + GRID.GapY)).LayoutOrder = i
		end
		empty.Visible = #list == 0
		empty.Text = if query ~= "" then "No dances match \"" .. query .. "\"." elseif tab == "Favourites" then "Tap the star on a dance to add it here." else "No dances here yet."
		if animate then Motion.stagger(items()) end
		showPreview()
	end

	local tabs = Kit.tabs(panel, {
		{ Key = "All", Text = "ALL", X = 14, Width = 118 },
		{ Key = "Owned", Text = "OWNED", X = 134, Width = 121 },
		{ Key = "Favourites", Text = "FAVOURITES", X = 257, Width = 122 },
	}, 50, 29, function(key)
		tab = key
		setMenu(false)
		grid.CanvasPosition = Vector2.zero
		rebuild(true)
	end, 13)

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
		player.CharacterAdded:Connect(function() task.defer(showPreview) end) -- (the stage copies the new avatar)
	end

	-- Until the player picks one, the selected dance is the first one they own (as shown): the save arrives after
	-- the window is built.
	local function firstOwned(): string?
		for _, d in visible() do
			if owned(d.Id) then return d.Id end
		end
		return nil
	end
	-- Rebuilding remakes every card (each with an avatar picture), so only when what the cards show changed (owned
	-- and favourite dances, the Dance Pack), and only while the window is open (critic: every coin or star update, and
	-- every move of a volume slider, rebuilt it).
	local function signature(): string
		local parts = { if State.owns("DancePack") then "P" else "" }
		for _, set in { State.data.Dances or {}, State.data.FavDances or {} } do
			local keys = {}
			for k, v in set do if v then table.insert(keys, tostring(k)) end end
			table.sort(keys)
			table.insert(parts, table.concat(keys, ","))
		end
		return table.concat(parts, "|")
	end
	local shown, dirty, firstDone = signature(), false, false
	-- (the cards picture your avatar: once it spawns or its look finishes loading, redraw them on the next open)
	if player then
		player.CharacterAdded:Connect(function() dirty = true end)
		pcall(function() player.CharacterAppearanceLoaded:Connect(function() dirty = true end) end)
	end
	State.changed(function()
		local now = signature()
		if now == shown then return end
		shown = now
		if not picked then selected = firstOwned() or selected end
		-- (once when the save first arrives, so the cards are right before anyone opens it)
		if window.Holder.Visible or not firstDone then rebuild(false) else dirty = true end
		firstDone = true
	end)

	ModalManager.register("Dances", {
		window = window,
		onOpen = function(arg)
			if type(arg) == "string" and tabs.buttons[arg] and tabs.selected() ~= arg then
				tabs.select(arg)
				tab = arg
				dirty = true
			end
			if dirty then
				dirty = false
				rebuild(false)
			end
		end,
		onClose = function()
			setMenu(false)
		end,
		firstSelect = function() return tabs.buttons.All.Instance end,
		items = items,
	})
	tabs.select("All")
	-- start on the first dance the player owns (or the first one shown)
	selected = firstOwned() or (Dances.List[1] and Dances.List[1].Id)
	rebuild(false)
	return window
end

return DancesScreen
