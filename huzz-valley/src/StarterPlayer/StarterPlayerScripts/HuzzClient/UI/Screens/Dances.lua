-- Dances (design/pages/03): All / Owned / Favourites tabs, a search box and a Name A-Z / Z-A sort over one 2 x 2
-- card grid, with the selected dance shown large on the right. PLAY performs the dance on the player's own avatar
-- (the character's Animator, so other players see it too); STOP ends it. Starting another dance stops the last one,
-- and the dance stops on respawn and when the window closes. A dance whose animation the owner hasn't supplied yet
-- says so and never pretends to play. Locked dances can't be played. The preview shows your own avatar doing the
-- selected dance (a copy in a ViewportFrame), so the 25 dances need no pictures. Each card shows your avatar frozen
-- in that dance's most telling moment (Config/DancePoses, from tools/preview/motion3d/dance_poses.luau), and the
-- selected card dances; a locked dance shows that pose as a dark silhouette.
-- Layout numbers are reference px (design/pages/03, window-relative; that page's header is the same 47 px).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Products = require(Shared.Config.Products)
local Progression = require(Shared.Config.Progression)
local AnimationLibrary = require(Shared.AnimationLibrary)
local DancePoses = require(Shared.Config.DancePoses)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local DancePlayer = require(UI.DancePlayer)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex

local DancesScreen = {}

local W, H = 701, 320 -- every main window shares this size
local RIM = 4 -- room inside the scrolling grid for the cards' rims and the 3 px selected outline
local GRID = { X = 17, Y = 86, CardW = 180, CardH = 105, GapX = 9, GapY = 9, Band = 29 }
local PREVIEW = { X = 400, Y = 47, W = 297, H = 262, Pad = 10, ArtH = 132, Gap = 9, BtnH = 38 }

-- Measured from reference 03.
local COL = {
	Card = hex("1E3A66"), CardRim = hex("3E6699"), Band = hex("10233F"), Selected = Theme.Colors.Accent,
	Field = hex("1B2B54"), FieldRim = hex("0E1C44"), FieldTop = hex("2C3D6E"), FieldText = hex("E3E8F7"), Hint = hex("C3CBE6"),
	PreviewTop = hex("26395E"), PreviewBottom = hex("182640"), PreviewLine = hex("3A5585"),
	ArtTop = hex("3557A0"), ArtBottom = hex("223B6E"),
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
	Kit.attach(Kit.pad(RIM, RIM, RIM, RIM), grid)
	local empty = Kit.text({ Name = "Empty", Text = "", TextSize = 16, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(GRID.X, GRID.Y + 70), Size = UDim2.fromOffset(2 * GRID.CardW + GRID.GapX, 40), Visible = false, Parent = panel })

	-- The preview: a navy card with the selected dance's picture on top, its name and a line of help underneath, and
	-- Play and Stop side by side along the bottom (equal widths, inside the card).
	local preview = new("Frame", { Name = "Preview", Position = UDim2.fromOffset(PREVIEW.X, PREVIEW.Y), Size = UDim2.fromOffset(PREVIEW.W, PREVIEW.H), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = panel }, { Kit.corner(6), Kit.stroke(COL.CardRim, 1) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.PreviewTop, COL.PreviewBottom), Parent = preview })
	new("Frame", { Name = "TopLine", Position = UDim2.fromOffset(6, 1), Size = UDim2.new(1, -12, 0, 1), BackgroundColor3 = COL.PreviewLine, BorderSizePixel = 0, Parent = preview })
	local artBox = new("Frame", { Name = "ArtBox", Position = UDim2.fromOffset(PREVIEW.Pad, PREVIEW.Pad), Size = UDim2.fromOffset(PREVIEW.W - 2 * PREVIEW.Pad, PREVIEW.ArtH), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = preview }, { Kit.corner(5), Kit.stroke(COL.CardRim, 1) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.ArtTop, COL.ArtBottom), Parent = artBox }) -- blue backdrop behind the see-through picture
	local textX, textW = PREVIEW.Pad + 4, PREVIEW.W - 2 * PREVIEW.Pad - 8
	local previewName = Kit.name({ Name = "DanceName", Text = "", TextSize = 20, Position = UDim2.fromOffset(textX, PREVIEW.Pad + PREVIEW.ArtH + 8), Size = UDim2.fromOffset(textW, 24), Parent = preview })
	local previewBlurb = Kit.text({ Name = "Blurb", Text = "", TextSize = 15, LineHeight = 1.0, TextColor3 = C.SubText, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(textX, PREVIEW.Pad + PREVIEW.ArtH + 34), Size = UDim2.fromOffset(textW, 36), Parent = preview })

	local btnW = math.floor((PREVIEW.W - 2 * PREVIEW.Pad - PREVIEW.Gap) / 2)
	local btnY = PREVIEW.Y + PREVIEW.H - PREVIEW.Pad - PREVIEW.BtnH
	local play = Kit.button({ Name = "Play", Text = "PLAY", Icon = "Play", IconSize = 18, Gap = 10, TextSize = 21, Style = "Action", Position = UDim2.fromOffset(PREVIEW.X + PREVIEW.Pad, btnY), Size = UDim2.fromOffset(btnW, PREVIEW.BtnH), Parent = panel })
	local stop = Kit.button({ Name = "Stop", Text = "STOP", Icon = "Stop", IconSize = 16, Gap = 10, TextSize = 21, Style = "Slate", Position = UDim2.fromOffset(PREVIEW.X + PREVIEW.W - PREVIEW.Pad - btnW, btnY), Size = UDim2.fromOffset(btnW, PREVIEW.BtnH), Parent = panel })

	-- Your avatar doing the selected dance: a copy of your character in a ViewportFrame (a WorldModel inside, so
	-- its Animator runs), seen from the front. Rebuilt only when the dance or your character changes.
	local stage = new("ViewportFrame", { Name = "Stage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 180, 200), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.8), Visible = false, Parent = artBox }, { Kit.corner(5) })
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
		local old = artBox:FindFirstChild("Picture")
		if old then old:Destroy() end
		local d = selected and Dances.get(selected)
		if not d then
			previewName.Text = ""
			previewBlurb.Text = "Pick a dance."
			stage.Visible = false
			return
		end
		local mine = owned(d.Id)
		local big = mine and PREVIEW_ART[d.Id]
		if mine and showDancer(d) then
			-- (your avatar is dancing it)
		elseif big then
			Kit.attach(Kit.corner(5), Kit.art(big, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = artBox }))
		else
			-- no picture and no avatar to show (not published yet, outside Studio): the note, or the locked silhouette
			if mine and not d.Art then
				Kit.icon("DancesNote", { Name = "Picture", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), Parent = artBox })
			else
				Kit.attach(Kit.corner(5), Kit.art(if mine and d.Art then d.Art else "DanceLocked", { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = artBox }))
			end
		end
		previewName.Text = d.Name
		if not mine then stage.Visible = false end
		previewBlurb.Text = if mine then "Press PLAY, or G anywhere for your dance wheel." else "Locked. " .. (if rewardLevel(d.Id) then "Reach Level " .. rewardLevel(d.Id) .. "." elseif d.Pack then "Dance Pack." else "")
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

	-- Card dancers: one avatar copy per dance, kept between redraws of the grid (rebuilt when your character
	-- changes), frozen on its pose; the selected card's copy dances. Built one per frame so opening never hitches.
	-- A dance that can't play here (not published yet, outside Studio) keeps the music note.
	local dancers: { [string]: { vp: ViewportFrame, char: Model, track: AnimationTrack? } } = {}
	local broken: { [string]: Model } = {} -- dances whose copy couldn't be built for this character: the note
	local function note(parent: Instance)
		Kit.icon("DancesNote", { Name = "Note", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, math.floor((GRID.CardH - GRID.Band) / 2) + 1), Size = UDim2.fromOffset(52, 52), Parent = parent })
	end
	local function freeze(e, dance: boolean, poseAt: number)
		local track = e.track
		if not track then return end
		if dance then
			track:AdjustSpeed(1)
		else
			track:AdjustSpeed(0)
			if track.Length > 0 then track.TimePosition = math.min(poseAt, track.Length - 0.01) end
		end
	end
	local function cardDancer(d, parent: GuiObject, mine: boolean, selectedNow: boolean): boolean
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local id = AnimationLibrary.id("Dance_" .. d.Id, d.AnimationId)
		if not character or id == "" or broken[d.Id] == character then return false end
		local e = dancers[d.Id]
		if e and e.char ~= character then
			e.vp:Destroy()
			e = nil
		end
		local poseAt = DancePoses[d.Id] or 0
		if not e then
			local vp = new("ViewportFrame", { Name = "Dancer", BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 180, 200), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.8) })
			vp:SetAttribute("RuntimeOnly", true)
			local entry = { vp = vp, char = character, track = nil }
			dancers[d.Id] = entry
			e = entry
			task.spawn(function()
				task.wait(0.03 * (d.Order or 1)) -- (one copy per frame or so)
				if dancers[d.Id] ~= entry then return end
				local ok, err = pcall(function()
					local world = Instance.new("WorldModel")
					world.Parent = vp
					local copy = avatarCopy(character)
					copy.Parent = world
					local cam = Instance.new("Camera")
					cam.FieldOfView = 30
					cam.CFrame = CFrame.lookAt(Vector3.new(-2.6, 0.9, -12.5), Vector3.new(0, -0.3, 0))
					cam.Parent = vp
					vp.CurrentCamera = cam
					local humanoid = copy:FindFirstChildOfClass("Humanoid") :: Humanoid
					local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
					local animation = Instance.new("Animation")
					animation.AnimationId = id
					local track = (animator :: Animator):LoadAnimation(animation)
					track.Looped = true
					track:Play(0)
					entry.track = track
					for _ = 1, 60 do -- (wait for it to load, then freeze on the pose)
						if track.Length > 0 then break end
						task.wait(0.05)
					end
					freeze(entry, selected == d.Id, poseAt)
				end)
				if not ok and dancers[d.Id] == entry then
					warn(`[HuzzUI] The {d.Name} card shows the note: {err}`)
					local host = vp.Parent
					vp:Destroy()
					dancers[d.Id] = nil
					broken[d.Id] = character
					if host then note(host) end
				end
			end)
		end
		e.vp.Position = UDim2.fromOffset(1, 1)
		e.vp.Size = UDim2.fromOffset(GRID.CardW - 2, GRID.CardH - GRID.Band)
		-- locked: the same pose as a dark silhouette (like the Index's locked girls)
		if mine then
			e.vp.Ambient, e.vp.LightColor, e.vp.ImageColor3 = Color3.fromRGB(180, 180, 200), Color3.fromRGB(255, 250, 240), Color3.new(1, 1, 1)
		else
			e.vp.Ambient, e.vp.LightColor, e.vp.ImageColor3 = Color3.new(0, 0, 0), Color3.new(0, 0, 0), hex("0B1426")
		end
		e.vp.Parent = parent
		freeze(e, selectedNow, poseAt)
		return true
	end

	local function card(d, x: number, y: number)
		local mine = owned(d.Id)
		local c = new("TextButton", { Name = d.Id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(GRID.CardW, GRID.CardH), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = grid }, { Kit.corner(4) })
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.ArtTop, COL.ArtBottom), Parent = c }) -- blue backdrop behind the see-through picture
		local rim = Kit.stroke(COL.CardRim, 1)
		rim = Kit.attach(rim, c)
		Motion.bindButton(c, function() return nil end)
		-- the picture runs a few px under the name band, so its rounded bottom corners never show
		if not d.Art and cardDancer(d, c, mine, selected == d.Id) then
			-- (your avatar, frozen mid-dance)
		elseif mine and not d.Art then
			-- no picture for this dance: the music note, big, on the blue backdrop
			note(c)
		else
			local pic = Kit.art(if mine and d.Art then d.Art else "DanceLocked", { Name = "Picture", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(GRID.CardW - 2, GRID.CardH - GRID.Band + 3), Parent = c })
			Kit.attach(Kit.corner(3), pic)
		end
		local band = new("Frame", { Name = "Band", Position = UDim2.new(0, 1, 1, -GRID.Band - 1), Size = UDim2.new(1, -2, 0, GRID.Band), BackgroundColor3 = COL.Band, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 2, Parent = c }, { Kit.corner(3) })
		Kit.name({ Name = "Name", Text = d.Name, TextSize = 17, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -16, 1, -2), ZIndex = 3, Parent = band })
		-- favourite star: filled when favourited; an outline on the selected card so it can be favourited
		local star = new("TextButton", { Name = "Star", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), Size = UDim2.fromOffset(30, 30), ZIndex = 3, Parent = c })
		local filled = Kit.icon("FavouriteFilled", { Name = "Filled", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 23), ZIndex = 3, Parent = star })
		local outline = Kit.icon("FavouriteOutline", { Name = "Outline", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 23), ZIndex = 3, Parent = star })
		local api = {}
		function api.setSelected(on: boolean)
			local e = dancers[d.Id]
			if e then freeze(e, on, DancePoses[d.Id] or 0) end
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
		for _, e in dancers do e.vp.Parent = nil end -- (kept for the new cards)
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
		player.CharacterAdded:Connect(function() task.defer(showPreview) end) -- (the stage copies the new avatar)
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
