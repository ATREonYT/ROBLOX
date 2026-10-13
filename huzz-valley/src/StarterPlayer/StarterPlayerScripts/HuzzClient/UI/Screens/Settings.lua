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

local C = Theme.Colors
local new = Kit.new

local SettingsScreen = {}

local W, H = 701, 262
local ROW_X, ROW_W, ROW_H, ROW_Y0, ROW_STEP = 12, 677, 44, 52, 49
local COL = { A = 405, B = 501, C = 597 } -- left edges of the three choice buttons (window coords)

local syncers: { () -> () } = {}

local function save(key: string, value: any)
	task.spawn(function()
		local ok, why = State.setSetting(key, value)
		if not ok then Toast.show(why or "That setting couldn't be saved.") end
	end)
end

local function row(parent: Instance, i: number, icon: string, title: string, desc: string)
	local r = new("Frame", { Name = "Row" .. i, Position = UDim2.fromOffset(ROW_X, ROW_Y0 + (i - 1) * ROW_STEP), Size = UDim2.fromOffset(ROW_W, ROW_H), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(C.RowBorder, 1, 0.35) })
	Kit.icon(icon, { Name = "Icon", Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(30, 30), Parent = r })
	Kit.name({ Name = "Title", Text = title, TextSize = 16, Position = UDim2.fromOffset(56, 4), Size = UDim2.fromOffset(330, 20), TextWrapped = false, Parent = r })
	Kit.text({ Name = "Desc", Text = desc, TextSize = 12.5, TextColor3 = C.SubText, Position = UDim2.fromOffset(56, 23), Size = UDim2.fromOffset(330, 16), TextWrapped = false, Parent = r })
	return r
end

-- Three-way choice (Everyone / Friends / Nobody).
local function choice(r: Frame, key: string)
	local seg = Kit.segmented(r, {
		{ Value = "Everyone", Text = "Everyone", X = COL.A - ROW_X, Width = 89 },
		{ Value = "Friends", Text = "Friends", X = COL.B - ROW_X, Width = 89 },
		{ Value = "Nobody", Text = "Nobody", X = COL.C - ROW_X, Width = 80 },
	}, 7, 30, function(v) save(key, v) end)
	table.insert(syncers, function() seg.set(State.setting(key)) end)
end

-- ON / OFF (selected ON is periwinkle, selected OFF is peach, as in the reference).
local function onOff(r: Frame, key: string, x: number?, wOn: number?, wOff: number?)
	local x0 = (x or COL.A) - ROW_X
	local seg = Kit.segmented(r, {
		{ Value = true, Text = "ON", X = x0, Width = wOn or 136, Selected = "Action" },
		{ Value = false, Text = "OFF", X = x0 + (wOn or 136) + 8, Width = wOff or 128 },
	}, 7, 30, function(v) save(key, v) end)
	table.insert(syncers, function() seg.set(State.setting(key) == true) end)
end

local function buildAudio(page: Frame)
	local defs = {
		{ "MasterVolume", "AudioSpeaker", "Master Volume", "Overall game volume." },
		{ "MusicVolume", "AudioMusic", "Music Volume", "Background music volume." },
		{ "EffectsVolume", "AudioWaveform", "Effects Volume", "Sound effects volume." },
	}
	for i, d in defs do
		local key = d[1]
		local r = row(page, i, d[2], d[3], d[4])
		local pct = Kit.text({ Name = "Percent", Text = "", FontFace = Theme.Fonts.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, BackgroundColor3 = C.Pill, Position = UDim2.fromOffset(COL.C - ROW_X, 7), Size = UDim2.fromOffset(80, 30), Parent = r })
		Kit.corner(3).Parent = pct
		local slider = Kit.slider({
			Name = "Slider", Parent = r, Position = UDim2.fromOffset(COL.A - ROW_X, 17), Size = UDim2.fromOffset(COL.C - COL.A - 22, 10),
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
	local r = row(page, 4, "Monitor", "Mute While Unfocused", "Mute audio when the game window is not active.")
	onOff(r, "MuteUnfocused")
end

local function buildControls(page: Frame)
	local function keyRow(i: number, icon: string, title: string, desc: string, key: string?, fixed: string?)
		local r = row(page, i, icon, title, desc)
		local box = Kit.text({ Name = "Key", Text = fixed or "", FontFace = Theme.Fonts.Button, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.1, BackgroundColor3 = C.Pill, Position = UDim2.fromOffset(COL.A - ROW_X, 7), Size = UDim2.fromOffset(150, 30), Parent = r })
		Kit.corner(3).Parent = box
		local change = Kit.button({ Name = "Change", Text = key and "Change" or "SOON", Style = key and "Action" or "Disabled", TextSize = 15, Corner = 3, Position = UDim2.fromOffset(COL.C - ROW_X - 30, 7), Size = UDim2.fromOffset(110, 30), Parent = r })
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
	keyRow(3, "DancesNote", "Dances", "Play your unlocked dances.", nil, "G")
	local r = row(page, 4, "ControlsKeyboard", "Show Key Hints", "Show key hints on screen while playing.")
	onOff(r, "ShowKeyHints", COL.A, 71, 71)
	local reset = Kit.button({ Name = "Reset", Text = "Reset Bindings", Style = "Tab", TextSize = 14, Corner = 3, Position = UDim2.fromOffset(COL.C - ROW_X - 30, 7), Size = UDim2.fromOffset(110, 30), Parent = r })
	reset.onClick(function()
		for _, k in Settings.KeyFields do save(k, Settings.Defaults[k]) end
		Toast.show("Key bindings reset.")
	end)
end

local function buildSocial(page: Frame)
	choice(row(page, 1, "InventoryVisibility", "Inventory visibility", "Who can see your owned characters and cosmetics?"), "InventoryVisibility")
	choice(row(page, 2, "Envelope", "Invite requests", "Who can send you party invites?"), "InviteRequests")
	onOff(row(page, 3, "CompanionEffects", "Show companion effects", "Show visual effects from your equipped companion."), "CompanionEffects")
	onOff(row(page, 4, "Monitor", "Reduced motion", "Minimise camera motion and visual effects."), "ReducedMotion")
end

function SettingsScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Settings", Title = "SETTINGS", Icon = "SettingsGear", Width = W, Height = H, StudsTo = 268, Parent = parent, OnClose = function() ModalManager.close() end })
	local pages = {}
	for name, build in { Audio = buildAudio, Controls = buildControls, Social = buildSocial } do
		local page = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = window.Panel })
		build(page)
		pages[name] = page
	end
	Kit.text({ Name = "SaveNote", Text = "Changes save automatically.", TextSize = 10.5, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -2), Size = UDim2.fromOffset(300, 16), Parent = window.Panel })
	local tabs
	local function show(key: string)
		for name, page in pages do page.Visible = name == key end
	end
	tabs = Kit.tabs(window.Header, {
		{ Key = "Audio", Text = "AUDIO", X = 276, Width = 128 },
		{ Key = "Controls", Text = "CONTROLS", X = 409, Width = 128 },
		{ Key = "Social", Text = "SOCIAL", X = 542, Width = 108 },
	}, 8, 31, show, 15)
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
