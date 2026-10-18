-- Settings (design/pages/06, 09, 10): Audio / Controls / Social tabs in one window. Every change applies at once
-- (Main.client applies audio, motion, key hints and the menu key) and is saved by the server ("Changes save
-- automatically"). Options for features the game doesn't have yet are shown disabled with the reason.
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Settings = require(Shared.Config.Settings)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Scale = require(UI.Scale)
local Motion = require(UI.Motion)

local C = Theme.Colors
local new = Kit.new

local SettingsScreen = {}

-- Geometry per tab, measured from the references (06 Social is the approved page; 09/10 are taller with bigger rows).
local W = 701
-- One geometry for every tab, so the window never changes size (all main windows are 701 x 320).
local G = { H = 320, HH = 47, TabH = 31, TabText = 17, Tabs = { { 261, 125 }, { 390, 125 }, { 519, 125 } }, Close = Vector2.new(31, 31), Rows = { 56, 119, 182, 245 }, RowH = 54, TextX = 74, Cell = 59, TitleSize = 18 }
local GEOM = { Social = G, Audio = G }
GEOM.Controls = GEOM.Audio
local ROW_X = 12

local syncers: { () -> () } = {}

local function save(key: string, value: any)
	task.spawn(function()
		local ok, why = State.setSetting(key, value)
		if not ok then Toast.show(why or "That setting couldn't be saved.") end
	end)
end

-- One settings row (window coords). Audio/Controls rows have an icon cell with a divider; Social rows don't.
local function row(parent: Instance, g, i: number, icon: string, title: string, desc: string, width: number?)
	local y = g.Rows[i]
	local r = new("Frame", { Name = "Row" .. i, Position = UDim2.fromOffset(ROW_X, y), Size = UDim2.fromOffset(width or (W - 2 * ROW_X), g.RowH), BackgroundColor3 = g.Cell and C.CellRow or Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(C.RowBorder, 1) })
	if g.Cell then
		-- the icon sits in a darker inset panel (reference 09/10)
		new("Frame", { Name = "IconCell", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(0, g.Cell - 2, 1, -4), BackgroundColor3 = C.IconCell, BorderSizePixel = 0, Parent = r }, { Kit.corner(3) })
	else
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = r })
	end
	local iconSize = g.Cell and 37 or 30
	Kit.icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, g.Cell and math.floor((g.Cell + 2) / 2) or 27, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize), ZIndex = 2, Parent = r })
	local ty = g.Cell and 8 or 3
	Kit.name({ Name = "Title", Text = title, TextSize = g.TitleSize, Position = UDim2.fromOffset(g.TextX, ty), Size = UDim2.fromOffset(300, 22), Parent = r })
	Kit.text({ Name = "Desc", Text = desc, TextSize = 13, TextColor3 = C.SubText, Position = UDim2.fromOffset(g.TextX, ty + (g.Cell and 22 or 24)), Size = UDim2.fromOffset(300, 16), TextWrapped = false, Parent = r })
	return r, y
end

-- Three-way choice (Everyone / Friends / Nobody).
local function choice(r: Frame, key: string)
	local seg = Kit.segmented(r, {
		{ Value = "Everyone", Text = "Everyone", X = 391 - ROW_X, Width = 94 },
		{ Value = "Friends", Text = "Friends", X = 491 - ROW_X, Width = 93 },
		{ Value = "Nobody", Text = "Nobody", X = 590 - ROW_X, Width = 93 },
	}, math.floor((r.Size.Y.Offset - 30) / 2), 30, function(v) save(key, v) end, 15)
	table.insert(syncers, function() seg.set(State.setting(key)) end)
end

-- ON / OFF (selected ON is periwinkle, selected OFF is peach, as in the reference). x/widths in window coords.
local function onOff(r: Frame, key: string, x: number, wOn: number, xOff: number, wOff: number, h: number, textSize: number)
	local seg = Kit.segmented(r, {
		{ Value = true, Text = "ON", X = x - ROW_X, Width = wOn, Selected = "Action" },
		{ Value = false, Text = "OFF", X = xOff - ROW_X, Width = wOff },
	}, math.floor((r.Size.Y.Offset - h) / 2), h, function(v) save(key, v) end, textSize)
	table.insert(syncers, function() seg.set(State.setting(key) == true) end)
end

-- Audio (owner, Oct 18: "make the setting page have like an audio page ... so they can have many options (turn down
-- music, turn down sfx, master volume etc)"): six rows in a list that scrolls (the window keeps its size; the fifth
-- row peeks out at the bottom so you can tell there's more). Volumes act at once (Main sets the sound groups).
local AUDIO_ROWS = { 4, 62, 120, 178, 236, 294 }
local function buildAudio(page: Frame)
	local g = table.clone(GEOM.Audio)
	g.Rows = AUDIO_ROWS
	local top = GEOM.Audio.Rows[1] - 4
	local list = new("ScrollingFrame", {
		Name = "List", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, -2, 1, -top - 4), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, AUDIO_ROWS[#AUDIO_ROWS] + g.RowH + 6), ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.SubText, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	local defs = {
		{ "MasterVolume", "AudioSpeaker", "Master Volume", "Everything you hear in the game." },
		{ "MusicVolume", "AudioMusic", "Music Volume", "The background songs." },
		{ "EffectsVolume", "AudioWaveform", "Effects Volume", "Footsteps, catches, powers and cheers." },
		{ "InterfaceVolume", "ControlsMenu", "Button Sounds", "Clicks and menu sounds." },
	}
	for i, d in defs do
		local key = d[1]
		local r = row(list, g, i, d[2], d[3], d[4])
		local pct = Kit.text({ Name = "Percent", Text = "", FontFace = Theme.Fonts.Number, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = C.PercentBox, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 591 - ROW_X, 0.5, 0), Size = UDim2.fromOffset(88, 34), Parent = r })
		Kit.attach(Kit.corner(3), pct)
		Kit.attach(Kit.stroke(C.KeyBoxRim, 1, 0.4), pct)
		local slider = Kit.slider({
			Name = "Slider", Parent = r, Position = UDim2.new(0, 302 - ROW_X, 0.5, -7), Size = UDim2.fromOffset(267, 14),
			onChange = function(v)
				pct.Text = v .. "%"
				State.data.Settings[key] = v -- apply now (Main listens); saved on release
				State.apply({})
			end,
			onCommit = function(v) save(key, v) end,
		})
		table.insert(syncers, function()
			local v = State.setting(key)
			slider.set(v)
			pct.Text = v .. "%"
		end)
	end
	-- Background music on or off, and a button for the next song (Gameplay/Music)
	local r = row(list, g, 5, "MusicBenefit", "Background Music", "Songs play in a random order.")
	local skip = Kit.button({ Name = "NextSong", Text = "Next Song", Style = "Slate", TextSize = 15, Corner = 3, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 302 - ROW_X, 0.5, 0), Size = UDim2.fromOffset(120, 35), Parent = r })
	skip.onClick(function()
		local ok, Music = pcall(require, UI.Parent:WaitForChild("Gameplay"):WaitForChild("Music", 2))
		if not (ok and Music and Music.skip()) then Toast.show("No songs to play yet.") end
	end)
	onOff(r, "MusicOn", 437, 118, 564, 116, 35, 18)
	r = row(list, g, 6, "Monitor", "Mute While Unfocused", "Mute audio when the game window is not active.")
	onOff(r, "MuteUnfocused", 437, 118, 564, 116, 35, 18)
end

local function buildControls(page: Frame)
	local g = GEOM.Controls
	local function keyRow(i: number, icon: string, title: string, desc: string, key: string?, fixed: string?)
		local r = row(page, g, i, icon, title, desc)
		local box = Kit.text({ Name = "Key", Text = fixed or "", FontFace = Theme.Fonts.Button, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = C.KeyBox, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 397 - ROW_X, 0.5, 0), Size = UDim2.fromOffset(133, 33), Parent = r })
		Kit.attach(Kit.corner(3), box)
		Kit.attach(Kit.stroke(C.KeyBoxRim, 1), box)
		local change = Kit.button({ Name = "Change", Text = key and "Change" or "FIXED", Style = key and "Action" or "Disabled", TextSize = 17, Corner = 3, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 545 - ROW_X, 0.5, 0), Size = UDim2.fromOffset(138, 34), Parent = r })
		if not key then
			box.TextTransparency = 0.5
			change.onClick(function() Toast.show(title .. " arrives with matches.") end)
			return
		end
		local listening = false
		table.insert(syncers, function() if not listening then box.Text = State.setting(key) end end)
		change.onClick(function()
			if listening then return end
			listening = true
			box.Text = "Press a key..."
			change.setText("Cancel")
			local conn
			conn = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				conn:Disconnect()
				listening = false
				change.setText("Change")
				local name = input.KeyCode.Name
				if input.KeyCode == Enum.KeyCode.Escape then
					box.Text = State.setting(key)
					return
				end
				if Settings.ReservedKeys[name] then
					Toast.show(name .. " is used by Roblox or movement.")
					box.Text = State.setting(key)
					return
				end
				box.Text = name
				save(key, name)
			end)
		end)
	end
	keyRow(1, "ControlsDash", "Dash", "Quick movement boost.", nil, "SPACE")
	keyRow(2, "ControlsMenu", "Open Menu", "Open the main menu.", "MenuKey")
	keyRow(3, "AudioMusic", "Dances", "Play your unlocked dances.", nil, "G")
	local r, y = row(page, g, 4, "ControlsKeyboard", "Show Key Hints", "Show key hints on screen while playing.", 531 - ROW_X)
	onOff(r, "ShowKeyHints", 335, 95, 437, 89, 35, 18)
	-- Reset Bindings sits in its own cell to the right of the row.
	local cell = new("Frame", { Name = "ResetCell", Position = UDim2.fromOffset(535, y), Size = UDim2.fromOffset(157, g.RowH), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = page }, { Kit.corner(4), Kit.stroke(C.RowBorder, 1) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = cell })
	local reset = Kit.button({ Name = "Reset", Text = "Reset Bindings", Style = "Slate", TextSize = 17, Corner = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(140, 40), Parent = cell })
	reset.onClick(function()
		for _, k in Settings.KeyFields do save(k, Settings.Defaults[k]) end
		Toast.show("Key bindings reset.")
	end)
end

local function buildSocial(page: Frame)
	local g = GEOM.Social
	choice(row(page, g, 1, "InventoryVisibility", "Inventory visibility", "Who can see your owned characters and cosmetics?"), "InventoryVisibility")
	choice(row(page, g, 2, "Envelope", "Invite requests", "Who can send you party invites?"), "InviteRequests")
	onOff(row(page, g, 3, "CompanionEffects", "Show companion effects", "Show visual effects from your equipped companion."), "CompanionEffects", 391, 140, 540, 143, 30, 16)
	onOff(row(page, g, 4, "Monitor", "Reduced motion", "Minimise camera motion and visual effects."), "ReducedMotion", 391, 140, 540, 143, 30, 16)
	Kit.text({ Name = "SaveNote", Text = "Changes save automatically.", TextSize = 14, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -3), Size = UDim2.fromOffset(300, 16), Parent = page })
end

function SettingsScreen.build(parent: Instance)
	local g0 = GEOM.Social
	local window = Kit.window({ Name = "Settings", Title = "SETTINGS", Icon = "SettingsGear", Width = W, Height = g0.H, HeaderHeight = g0.HH, TitleSize = 30, TitleWidth = 157, StudsTo = 297, Parent = parent, OnClose = function() ModalManager.close() end })
	local pages = {}
	for name, build in { Audio = buildAudio, Controls = buildControls, Social = buildSocial } do
		local page = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = window.Panel })
		build(page)
		pages[name] = page
	end
	local tabs
	local defs = {
		{ Key = "Audio", Text = "AUDIO" }, { Key = "Controls", Text = "CONTROLS" }, { Key = "Social", Text = "SOCIAL" },
	}
	for i, d in defs do d.X, d.Width = g0.Tabs[i][1] - 4, g0.Tabs[i][2] end
	-- The window takes each tab's measured size (the references for Audio/Controls are taller than Social).
	local function layout(key: string)
		local g = GEOM[key]
		window.Height = g.H
		window.Holder.Size = UDim2.fromOffset(W, g.H)
		window.Header.Size = UDim2.new(1, -8, 0, g.HH - 4)
		local ih = g.HH - 4
		-- studs fill the gap between the title and the first tab, which differs per tab
		window.Header.Studs:Destroy()
		Kit.studs(window.Header, 58 + 157 + 6, g.Tabs[1][1] - 8, math.floor(ih / 2) - 6)
		Kit.place(window.Close.Instance, UDim2.new(1, -7, 0.5, 0), UDim2.fromOffset(g.Close.X, g.Close.Y), Vector2.new(1, 0.5))
		for i, d in defs do
			local b = tabs.buttons[d.Key].Instance
			Kit.place(b, UDim2.fromOffset(g.Tabs[i][1] - 4, math.floor((ih - g.TabH) / 2)), UDim2.fromOffset(g.Tabs[i][2], g.TabH))
			b.Content.Label.TextSize = g.TabText
		end
		window.Holder.FitScale.Scale = Scale.window(W, g.H)
	end
	local function rows(key: string)
		local list = {}
		for _, ch in pages[key]:GetChildren() do if ch:IsA("Frame") then table.insert(list, ch) end end
		table.sort(list, function(a, b) return (a:GetAttribute("HomePosition") or a.Position).Y.Offset < (b:GetAttribute("HomePosition") or b.Position).Y.Offset end)
		return list
	end
	local function show(key: string)
		for name, page in pages do page.Visible = name == key end
		layout(key)
		Motion.stagger(rows(key))
	end
	tabs = Kit.tabs(window.Header, defs, 0, g0.TabH, show, g0.TabText, "HeaderTab")
	local function sync() for _, f in syncers do f() end end
	State.changed(sync)
	sync()
	ModalManager.register("Settings", {
		window = window,
		onOpen = function(tab)
			local key = tab or tabs.selected() or "Social"
			tabs.select(key)
			show(key)
		end,
		firstSelect = function() return tabs.buttons.Audio.Instance end,
	})
	tabs.select("Social")
	show("Social")
	return window
end

return SettingsScreen
