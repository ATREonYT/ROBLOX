--!strict
-- The icon menu on the left: hidden until you press Menu/Toggle (or G / DPadLeft), then a 2-column grid of
-- big icon tiles slides out. Tiles come from Config/HUD.Menu. Also runs the Store and Emotes popups.
--   Menu.open()  Menu.close()  Menu.toggle()  Menu.isOpen()  Menu.openPanel("Store" | "Emotes")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.MTL.Net)
local Format = require(ReplicatedStorage.MTL.Format)
local Monetization = require(ReplicatedStorage.MTL.Config.Monetization)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Config = require(ReplicatedStorage.MTL.Config.HUD)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.HUD)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local H = Theme.HUD

local Menu = {}

local gui: any
local menuOpen = false
local panels: { [string]: Frame } = {}
local openPanelName: string? = nil
local emoteTrack: AnimationTrack? = nil

-- all UI sounds go through the shared Sfx module (Theme.Sfx), so the whole game sounds the same
local Sfx: any = nil
do
	local m = ReplicatedStorage.MTL.UI:FindFirstChild("Sfx")
	if m then
		local ok, mod = pcall(require, m)
		Sfx = if ok then mod else nil
	end
end
local function sound(name: string)
	if Sfx then
		pcall(Sfx.play, name)
	end
end

local function phone(): any
	local m = script.Parent:FindFirstChild("PhoneController")
	if not m then
		return nil
	end
	local ok, p = pcall(require, m)
	return if ok then p else nil
end

-- press feedback: lift + brighter border on hover, a quick squeeze on press (eased, no bounce-fest)
local HOVER = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function juice(button: GuiButton, scale: UIScale)
	local stroke = button:FindFirstChild("Stroke") :: UIStroke?
	local baseT = if stroke then stroke.Transparency else 0
	button.MouseEnter:Connect(function()
		sound("Hover")
		Motion.tween(scale, HOVER, { Scale = 1.04 })
		if stroke then
			Motion.tween(stroke, HOVER, { Transparency = 0.35 })
		end
	end)
	button.MouseLeave:Connect(function()
		Motion.tween(scale, HOVER, { Scale = 1 })
		if stroke then
			Motion.tween(stroke, HOVER, { Transparency = baseT })
		end
	end)
	button.MouseButton1Down:Connect(function()
		Motion.tween(scale, Motion.Fast, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		Motion.tween(scale, HOVER, { Scale = 1.04 })
	end)
end

---------------------------------------------------------------- tiles

local function allowed(entry: any): boolean
	local data = ClientData.get()
	if entry.path and (not data or data.Path ~= entry.path) then
		return false
	end
	if entry.requires then
		local stage = data and data.Story and data.Story.Stage
		if not stage or not StoryRules.reached(stage, entry.requires) then
			return false
		end
	end
	return true
end

local function refreshTiles()
	local grid = gui.Menu.Panel.Grid
	local shown = 0
	for _, entry in Config.Menu do
		local tile = grid:FindFirstChild("Tile_" .. entry.id)
		if tile then
			tile.Visible = allowed(entry)
			shown += if tile.Visible then 1 else 0
		end
	end
	local rows = math.ceil(shown / 2)
	grid.Size = UDim2.fromOffset(192, rows * 92 + math.max(rows - 1, 0) * 8)
end

local function run(entry: any)
	sound("Tap")
	if entry.action == "phone" then
		Menu.close()
		local p = phone()
		if p then
			p.toggle()
		end
	elseif entry.action == "app" then
		Menu.close()
		local p = phone()
		if p then
			p.open(entry.app)
		end
	elseif entry.action == "panel" then
		Menu.openPanel(entry.panel)
	elseif entry.action == "map" then
		-- the full-screen map (MinimapController); the phone's GPS app is the fallback
		Menu.close()
		local m = script.Parent:FindFirstChild("MinimapController")
		local ok, mm = false, nil
		if m then
			ok, mm = pcall(require, m)
		end
		if ok and mm and mm.openMap then
			mm.openMap()
		else
			local p = phone()
			if p then
				p.open("Map")
			end
		end
	end
end

local function buildTiles()
	local grid = gui.Menu.Panel.Grid
	local template = grid.TileTemplate
	for i, entry in Config.Menu do
		local tile = grid:FindFirstChild("Tile_" .. entry.id)
		if not tile then
			tile = template:Clone()
			tile.Name = "Tile_" .. entry.id
			tile.LayoutOrder = i
			tile.Label.Text = entry.label
			local img = H.Images[entry.id]
			local old = tile:FindFirstChild("Icon")
			if img and img ~= "" and old then
				-- Alex's icon art replaces the emoji
				local pos = old.Position
				old:Destroy()
				local ic = Build.icon(tile, "", 48, entry.id)
				ic.Position = pos
			elseif old then
				old.Text = entry.emoji
			end
			tile.Parent = grid
		end
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		juice(tile, scale)
		tile.Activated:Connect(function()
			run(entry)
		end)
	end
	refreshTiles()
end

---------------------------------------------------------------- open / close

function Menu.isOpen(): boolean
	return menuOpen
end

-- Opening: the button shrinks away and the panel slides out from the left edge in its place.
-- Closing (the ‹ tab on the panel, G, Esc, or picking a tile): the panel slides back and the button pops back.
local SLIDE_IN = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local OPEN_X = UDim2.new(0, 0, 0.5, 0)
local CLOSED_X = UDim2.new(0, -260, 0.5, 0)
local toggleScale: UIScale

function Menu.open()
	if menuOpen then
		return
	end
	menuOpen = true
	refreshTiles()
	local toggle = gui.Menu.Toggle
	Motion.tween(toggleScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }).Completed:Once(function()
		if menuOpen then
			toggle.Visible = false
		end
	end)
	local panel = gui.Menu.Panel
	panel.Pop.Scale = 1
	panel.Position = CLOSED_X
	panel.Visible = true
	Motion.tween(panel, SLIDE_IN, { Position = OPEN_X })
	-- tiles settle in one after another (small scale-up + fade)
	for _, tile in panel.Grid:GetChildren() do
		if tile:IsA("GuiButton") and tile.Visible then
			local sc = tile:FindFirstChildOfClass("UIScale")
			local ic = tile:FindFirstChild("Icon")
			if sc then
				sc.Scale = 0.85
				tile.BackgroundTransparency = 1
				if ic and ic:IsA("TextLabel") then
					ic.TextTransparency = 1
				end
				task.delay(0.04 + tile.LayoutOrder * 0.03, function()
					Motion.tween(sc, Motion.Normal, { Scale = 1 })
					Motion.tween(tile, Motion.Normal, { BackgroundTransparency = 0 })
					if ic and ic:IsA("TextLabel") then
						Motion.tween(ic, Motion.Normal, { TextTransparency = 0 })
					end
				end)
			end
		end
	end
	panel.Collapse.Modal = true -- frees the mouse in shift lock / first person
	sound("Open")
end

function Menu.close()
	if not menuOpen then
		return
	end
	menuOpen = false
	local panel = gui.Menu.Panel
	panel.Collapse.Modal = false
	Motion.tween(panel, SLIDE_OUT, { Position = CLOSED_X }).Completed:Once(function()
		if not menuOpen then
			panel.Visible = false
		end
	end)
	local toggle = gui.Menu.Toggle
	task.delay(0.12, function()
		if menuOpen then
			return
		end
		toggle.Visible = true
		Motion.tween(toggleScale, Motion.Spring, { Scale = 1 })
	end)
	sound("Close")
end

function Menu.toggle()
	if menuOpen then
		Menu.close()
	else
		Menu.open()
	end
end

---------------------------------------------------------------- popups (Store, Emotes)
-- An open popup dims and blurs the game behind it (Panels/Dim + a local BlurEffect); clicking the dim closes it.

local BLUR = 14
local blur: BlurEffect? = nil
local fitScale = 1

local function getBlur(): BlurEffect
	if blur and blur.Parent then
		return blur
	end
	local b = Instance.new("BlurEffect")
	b.Name = "MTL_MenuBlur"
	b.Size = 0
	b.Parent = Lighting
	blur = b
	return b
end

local function backdrop(on: boolean)
	local dim = gui.Panels.Dim
	if on then
		dim.Visible = true
		Motion.tween(dim, Motion.Normal, { BackgroundTransparency = 0.45 })
		Motion.tween(getBlur(), Motion.Normal, { Size = BLUR })
	else
		Motion.tween(getBlur(), Motion.Fast, { Size = 0 })
		Motion.tween(dim, Motion.Fast, { BackgroundTransparency = 1 }).Completed:Once(function()
			if openPanelName == nil then
				dim.Visible = false
			end
		end)
	end
end

local function closePanel()
	if not openPanelName then
		return
	end
	local p = panels[openPanelName]
	openPanelName = nil
	backdrop(false)
	sound("Close")
	if p then
		Motion.tween(p.Pop, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = fitScale * 0.85 }).Completed:Once(function()
			if openPanelName == nil or panels[openPanelName] ~= p then
				p.Visible = false
			end
		end)
	end
end

local function stopEmote()
	if emoteTrack then
		emoteTrack:Stop(0.25)
		emoteTrack = nil
	end
end

local function playEmote(e: any)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animate = char and char:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(e.anim)
	if not (hum and folder) then
		return
	end
	local anim = folder:FindFirstChildOfClass("Animation")
	if not anim then
		return
	end
	stopEmote()
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = (animator :: Animator):LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = string.sub(e.anim, 1, 5) == "dance"
	track:Play(0.2)
	emoteTrack = track
end

---------------------------------------------------------------- the Store

local priceCache: { [string]: string } = {}

-- "R$ 199", "OWNED", or "SOON" (id not set up yet). Asks Roblox once per item.
local function priceText(item: string): (string, boolean)
	local passId = Monetization.Passes[item]
	local productId = Monetization.Products[item]
	if passId and player:GetAttribute("MTL_Pass_" .. item) then
		return "OWNED", false
	end
	local id = passId or productId
	if not id or id == 0 then
		return "SOON", false
	end
	if priceCache[item] then
		return priceCache[item], true
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, if passId then Enum.InfoType.GamePass else Enum.InfoType.Product)
	end)
	local text = if ok and info and info.PriceInRobux then "R$ " .. tostring(info.PriceInRobux) else "BUY"
	priceCache[item] = text
	return text, true
end

local function refreshCard(card: Frame, def: any)
	local buy = card:FindFirstChild("Buy") :: TextButton
	buy.Text = "..."
	task.spawn(function()
		local text, canBuy = priceText(def.item)
		buy.Text = text
		-- buyable = the accent; owned / not set up yet = quiet
		buy.BackgroundColor3 = if canBuy then H.Money else H.Ink
		buy.TextColor3 = if canBuy then H.Paper elseif text == "OWNED" then H.Money else H.Muted
		buy:SetAttribute("CanBuy", canBuy)
	end)
end

local function buildStore(): Frame
	local p = Build.panel("Store", "Store", 860, 520)
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Position = UDim2.fromOffset(24, 50)
	sub.Size = UDim2.fromOffset(420, 20)
	sub.BackgroundTransparency = 1
	sub.FontFace = H.BodyFont
	sub.Text = "Upgrade your hustle. Every purchase supports the game."
	sub.TextColor3 = H.Muted
	sub.TextSize = 14
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = p
	local list = p.List
	list.UIListLayout:Destroy()
	list.Position = UDim2.fromOffset(24, 146)
	list.Size = UDim2.new(1, -48, 1, -166)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(236, 320)
	grid.CellPadding = UDim2.fromOffset(28, 24)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	-- your cash, top right next to the close button
	local cashChip = Instance.new("TextLabel")
	cashChip.Name = "Wallet"
	cashChip.AnchorPoint = Vector2.new(1, 0)
	cashChip.Position = UDim2.new(1, -66, 0, 14)
	cashChip.Size = UDim2.fromOffset(200, 40)
	cashChip.BackgroundTransparency = 1
	cashChip.FontFace = H.CashFont
	cashChip.TextColor3 = H.Money
	cashChip.TextSize = 26
	cashChip.TextXAlignment = Enum.TextXAlignment.Right
	cashChip.Text = "$0"
	cashChip.Parent = p
	local function wallet()
		local data = ClientData.get()
		if data then
			cashChip.Text = Format.cash(data.Cash or 0)
		end
	end
	wallet()
	ClientData.Changed:Connect(wallet)

	-- tabs
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(22, 84)
	tabs.Size = UDim2.new(1, -44, 0, 42)
	tabs.BackgroundTransparency = 1
	tabs.Parent = p
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 10)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs

	local cards: { [string]: Frame } = {}
	local function showTab(tabId: string)
		for _, t in Config.StoreTabs do
			local b = tabs:FindFirstChild("Tab_" .. t.id) :: TextButton
			local on = t.id == tabId
			Motion.tween(b, Motion.Fast, { BackgroundColor3 = if on then H.Accent else H.Ink2, TextColor3 = if on then H.Paper else H.Muted })
		end
		local order = 0
		for _, def in Config.Store do
			local card = cards[def.item]
			card.Visible = def.tab == tabId
			if card.Visible then
				order += 1
				card.LayoutOrder = order
				card.Pop.Scale = 0.94
				task.delay(order * 0.04, function()
					Motion.tween(card.Pop, Motion.Normal, { Scale = 1 })
				end)
				refreshCard(card, def)
			end
		end
		list.CanvasPosition = Vector2.zero
	end
	for i, t in Config.StoreTabs do
		local b = Build.storeTab(t.id, t.label)
		b.LayoutOrder = i
		b.Parent = tabs
		b.Activated:Connect(function()
			sound("Tap")
			showTab(t.id)
		end)
	end
	for _, def in Config.Store do
		local card = Build.storeCard(def)
		card.Parent = list
		cards[def.item] = card
		local buy = card:FindFirstChild("Buy") :: TextButton
		local press = buy:FindFirstChild("Press") :: UIScale
		local cardStroke = card:FindFirstChild("Stroke") :: UIStroke?
		buy.MouseEnter:Connect(function()
			if cardStroke then
				Motion.tween(cardStroke, Motion.Fast, { Transparency = 0.4 })
				Motion.tween(card.Pop, Motion.Fast, { Scale = 1.02 })
			end
			sound("Hover")
		end)
		buy.MouseLeave:Connect(function()
			if cardStroke then
				Motion.tween(cardStroke, Motion.Fast, { Transparency = H.LineTransparency })
				Motion.tween(card.Pop, Motion.Fast, { Scale = 1 })
			end
		end)
		buy.MouseButton1Down:Connect(function()
			Motion.tween(press, Motion.Fast, { Scale = 0.93 })
		end)
		buy.MouseButton1Up:Connect(function()
			Motion.tween(press, Motion.Spring, { Scale = 1 })
		end)
		buy.Activated:Connect(function()
			if buy:GetAttribute("CanBuy") then
				sound("Confirm")
				Net.get("PhoneAction"):FireServer({ type = "buy", item = def.item })
			else
				local hud = script.Parent:FindFirstChild("HUDController")
				local okH, HC = pcall(require, hud :: any)
				local why = if buy.Text == "OWNED" then "You already own this." else "Not on sale yet. Coming soon."
				if okH and HC and HC.refuse then
					HC.refuse(why)
				else
					sound("Error")
				end
			end
		end)
	end
	-- passes owned / bought while the store is open
	player.AttributeChanged:Connect(function(attr)
		if string.sub(attr, 1, 9) == "MTL_Pass_" then
			local item = string.sub(attr, 10)
			for _, def in Config.Store do
				if def.item == item then
					refreshCard(cards[item], def)
				end
			end
		end
	end)
	p:SetAttribute("Tab", Config.StoreTabs[1].id)
	showTab(Config.StoreTabs[1].id)
	return p
end

---------------------------------------------------------------- the emote wheel

local function buildEmotes(): Frame
	local p = Build.panel("Emotes", "Emotes", 440, 460)
	p.List:Destroy()
	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.new(0.5, 0, 0.5, 22)
	wheel.Size = UDim2.fromOffset(340, 340)
	wheel.BackgroundTransparency = 1
	wheel.Parent = p
	local hub = Instance.new("TextLabel")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(118, 118)
	hub.BackgroundColor3 = H.Ink2
	hub.FontFace = H.Font
	hub.TextColor3 = H.Paper
	hub.TextSize = 15
	hub.TextWrapped = true
	hub.Text = "Choose an emote"
	hub.Parent = wheel
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = hub
	local template = gui.Menu.Panel.Grid.TileTemplate
	local n = #Config.Emotes
	for i, e in Config.Emotes do
		local a = math.rad(-90 + (i - 1) * 360 / n)
		local tile = template:Clone()
		tile.Name = "Emote_" .. e.id
		tile.Visible = true
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Size = UDim2.fromOffset(84, 84)
		tile.Position = UDim2.new(0.5, math.cos(a) * 124, 0.5, math.sin(a) * 124)
		tile.Label.Visible = false
		tile.Icon.Text = e.emoji
		tile.Icon.Position = UDim2.fromScale(0.5, 0.5)
		tile.Parent = wheel
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		juice(tile, scale)
		tile.MouseEnter:Connect(function()
			hub.Text = e.label
		end)
		tile.MouseLeave:Connect(function()
			hub.Text = "Choose an emote"
		end)
		tile.Activated:Connect(function()
			sound("Tap")
			playEmote(e)
			closePanel()
		end)
	end
	return p
end

---------------------------------------------------------------- settings (volume, controls, display, rejoin)

local function saveSetting(key: string, value: any)
	Net.get("PhoneAction"):FireServer({ type = "setSetting", key = key, value = value })
end

local function settingValue(key: string): any
	local d = ClientData.get()
	return d and d.Settings and d.Settings[key]
end

local function mixer(): any
	local m = script.Parent:FindFirstChild("AudioMixer")
	local ok, mod = pcall(require, m :: any)
	return if ok then mod else nil
end

-- a draggable 0-100 slider; previews live, saves once on release
local function wireSlider(row: Frame, key: string)
	local track = row:FindFirstChild("Track") :: TextButton
	local fill = track:FindFirstChild("Fill") :: Frame
	local knob = track:FindFirstChild("Knob") :: Frame
	local value = row:FindFirstChild("Value") :: TextLabel
	local Mix = mixer()
	if Mix and not Mix.Groups[key] then
		Mix = nil -- not a volume (e.g. camera shake): no live preview, just save
	end
	local function show(pct: number)
		fill.Size = UDim2.fromScale(pct / 100, 1)
		knob.Position = UDim2.fromScale(pct / 100, 0.5)
		value.Text = string.format("%d%%", pct)
	end
	local saved = settingValue(key)
	show(if Mix then Mix.percent(key) elseif type(saved) == "number" then math.clamp(saved, 0, 100) else 100)
	local dragging = false
	local last = 0
	local function at(x: number)
		local pct = math.floor(math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * 20 + 0.5) * 5
		if pct ~= last then
			last = pct
			show(pct)
			if Mix then
				Mix.preview(key, pct)
			end
		end
	end
	track.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			last = -1
			at(input.Position.X)
			Motion.tween(knob, Motion.Fast, { Size = UDim2.fromOffset(22, 22) })
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			at(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			dragging = false
			Motion.tween(knob, Motion.Fast, { Size = UDim2.fromOffset(18, 18) })
			saveSetting(key, last)
			sound("Tap")
			-- the save comes back through ClientData; keep previewing until then so the slider doesn't jump
			task.delay(1.5, function()
				if not dragging and Mix then
					Mix.preview(key, nil)
				end
			end)
		end
	end)
end

-- a segmented choice: options { {value, text} }, current(): value, choose(value)
local function wireChoice(row: Frame, options: { any }, current: () -> any, choose: (any) -> ())
	local opts = row:FindFirstChild("Options") :: Frame
	local function paint()
		local cur = current()
		for _, o in options do
			local b = opts:FindFirstChild("Opt_" .. tostring(o.value)) :: TextButton
			local on = cur == o.value
			Motion.tween(b, Motion.Fast, { BackgroundTransparency = if on then 0 else 1, TextColor3 = if on then H.Paper else H.Muted })
		end
	end
	for _, o in options do
		local b = opts:FindFirstChild("Opt_" .. tostring(o.value)) :: TextButton
		b.Activated:Connect(function()
			sound("Tap")
			choose(o.value)
			task.delay(0.05, paint)
		end)
	end
	paint()
	ClientData.Changed:Connect(paint)
end

local function rejoin()
	sound("Confirm")
	local TeleportService = game:GetService("TeleportService")
	local ok = pcall(function()
		if game.JobId ~= "" and game.PrivateServerId == "" then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		else
			TeleportService:Teleport(game.PlaceId, player)
		end
	end)
	local hud = script.Parent:FindFirstChild("HUDController")
	local okH, H2 = pcall(require, hud :: any)
	if okH and H2 and H2.toast then
		H2.toast(if ok then "Rejoining..." else "Rejoin doesn't work in Studio. It will in the live game.")
	end
end

local function buildSettings(): Frame
	local p = Build.panel("Settings", "Settings", 520, 560)
	local list = p.List
	local order = 0
	local function add(inst: GuiObject)
		order += 1
		inst.LayoutOrder = order
		inst.Parent = list
	end

	add(Build.sectionTitle("Sound"))
	for _, v in {
		{ "MusicVol", "Music" },
		{ "SfxVol", "Effects" },
		{ "UIVol", "Interface" },
		{ "AmbVol", "City sounds" },
	} do
		local row = Build.slider(v[2])
		add(row)
		wireSlider(row, v[1])
	end

	add(Build.sectionTitle("Controls"))
	local sprintOpts = { { value = "Hold", text = "HOLD" }, { value = "Toggle", text = "TOGGLE" } }
	local sprint = Build.segmented("Sprint (Shift)", sprintOpts)
	add(sprint)
	wireChoice(sprint, sprintOpts, function()
		return if settingValue("SprintToggle") == true then "Toggle" else "Hold"
	end, function(v)
		saveSetting("SprintToggle", v == "Toggle")
	end)
	local hintOpts = { { value = "Auto", text = "AUTO" }, { value = "On", text = "ON" }, { value = "Off", text = "OFF" } }
	local hints = Build.segmented("Key hints", hintOpts)
	add(hints)
	wireChoice(hints, hintOpts, function()
		local v = settingValue("KeyHintsMode")
		return if v == 1 then "On" elseif v == 2 then "Off" else "Auto"
	end, function(v)
		-- "Auto" can't be saved as nil through setSetting, so it's stored as the number 0
		saveSetting("KeyHintsMode", if v == "On" then 1 elseif v == "Off" then 2 else 0)
	end)

	local shake = Build.slider("Camera shake")
	add(shake)
	wireSlider(shake, "Shake") -- CamShake (guns) reads Settings.Shake, x ReducedMotion

	add(Build.sectionTitle("Display"))
	local gfxOpts = { { value = 0, text = "AUTO" }, { value = 1, text = "LOW" }, { value = 2, text = "MED" }, { value = 3, text = "HIGH" } }
	local gfx = Build.segmented("Graphics", gfxOpts)
	add(gfx)
	wireChoice(gfx, gfxOpts, function()
		local v = settingValue("Graphics")
		return if type(v) == "number" then v else 0
	end, function(v)
		saveSetting("Graphics", v)
	end)
	local motionOpts = { { value = false, text = "OFF" }, { value = true, text = "ON" } }
	local motion = Build.segmented("Reduced motion", motionOpts)
	add(motion)
	wireChoice(motion, motionOpts, function()
		return settingValue("ReducedMotion") == true
	end, function(v)
		saveSetting("ReducedMotion", v)
	end)

	add(Build.sectionTitle("Server"))
	local rj = Instance.new("TextButton")
	rj.Name = "Rejoin"
	rj.Size = UDim2.new(1, -6, 0, 42)
	rj.BackgroundColor3 = H.Ink2
	rj.AutoButtonColor = false
	rj.FontFace = H.Font
	rj.Text = "REJOIN SERVER"
	rj.TextColor3 = H.Paper
	rj.TextSize = 14
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = rj
	local st = Instance.new("UIStroke")
	st.Name = "Stroke"
	st.Color = H.Line
	st.Transparency = H.LineTransparency
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = rj
	add(rj)
	local sc = Instance.new("UIScale")
	sc.Parent = rj
	juice(rj, sc)
	rj.Activated:Connect(rejoin)
	return p
end

-- popups shrink to fit small screens (phones), never grow past their design size
local function fit(p: Frame)
	local vp = workspace.CurrentCamera.ViewportSize
	local base = p:GetAttribute("BaseSize") :: Vector2?
	if not base then
		base = Vector2.new(p.Size.X.Offset, p.Size.Y.Offset)
		p:SetAttribute("BaseSize", base)
	end
	fitScale = math.clamp(math.min((vp.X - 40) / base.X, (vp.Y - 60) / base.Y), 0.5, 1)
end

function Menu.openPanel(name: string)
	if openPanelName == name then
		closePanel()
		return
	end
	local had = openPanelName ~= nil
	if had then
		local old = panels[openPanelName :: string]
		openPanelName = nil
		if old then
			old.Visible = false
		end
	end
	local p = panels[name]
	if not p then
		p = if name == "Store" then buildStore()
			elseif name == "Emotes" then buildEmotes()
			elseif name == "Settings" then buildSettings()
			else nil :: any
		if not p then
			return
		end
		p.ZIndex = 2
		p.Parent = gui.Panels
		p.Close.Activated:Connect(closePanel)
		panels[name] = p
	end
	Menu.close()
	openPanelName = name
	fit(p)
	p.Pop.Scale = fitScale * 0.85
	p.Visible = true
	Motion.tween(p.Pop, Motion.Spring, { Scale = fitScale })
	p.Close.Modal = true
	if not had then
		backdrop(true)
	end
	sound("Open")
end

---------------------------------------------------------------- init

function Menu.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:WaitForChild("MTL_HUD", 10)
	if not gui or not gui:FindFirstChild("Menu") then
		warn("[MTL Menu] MTL_HUD has no Menu (old HUD saved in StarterGui?)")
		return
	end
	buildTiles()
	gui.Panels.Dim.Activated:Connect(closePanel)

	local toggle = gui.Menu.Toggle
	toggleScale = Instance.new("UIScale")
	toggleScale.Parent = toggle
	juice(toggle, toggleScale)
	local collapse = gui.Menu.Panel.Collapse
	collapse.Activated:Connect(function()
		sound("Tap")
		Menu.close()
	end)
	toggle.Activated:Connect(function()
		if openPanelName then
			closePanel()
		end
		Menu.toggle()
	end)
	-- touch: no key hint
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		toggle.Key.Visible = false
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, k in Config.MenuKeys do
			if input.KeyCode == k then
				if openPanelName then
					closePanel()
				end
				Menu.toggle()
				return
			end
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closePanel()
			Menu.close()
		end
	end)

	ClientData.Changed:Connect(function()
		if menuOpen then
			refreshTiles()
		end
	end)
	UIState.Changed:Connect(function(state)
		if state.hideHUD then
			closePanel()
			Menu.close()
		end
	end)

	-- moving cancels an emote
	game:GetService("RunService").Heartbeat:Connect(function()
		if emoteTrack then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.MoveDirection.Magnitude > 0.1 or hum.Jump then
				stopEmote()
			end
		end
	end)
end

return Menu
