-- Starts the Huzz Valley UI and applies the player's settings (audio, reduced motion, menu key, VIP chat tag).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent:WaitForChild("UI")
local Report = require(UI:WaitForChild("Report"))
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Scale = require(UI.Scale)
local SettingsConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Settings)
local Screens = UI.Screens

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
-- The UI is saved in StarterGui as real parts (edit them in Studio); Roblox copies it into PlayerGui and the screens
-- below reuse those parts instead of making new ones. If it's missing, the same code builds the whole UI itself.
local gui = playerGui:FindFirstChild("HuzzUI")
if not gui and game:GetService("StarterGui"):FindFirstChild("HuzzUI") then gui = playerGui:WaitForChild("HuzzUI", 10) end
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "HuzzUI"
	-- (built here because the saved one didn't arrive in time: if Roblox copies it in later, drop that dead copy)
	pcall(function() -- (guarded: the offline preview's PlayerGui has no ChildAdded)
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == "HuzzUI" and child ~= gui then child:Destroy() end
		end)
	end)
end
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui
Scale.setRoot(gui)
-- Rounded corners: our save tool can't write a UICorner's size the way every Studio reads it, so each saved corner
-- also carries its size in the attribute HuzzRadius. Put it back where the corner came out at Roblox's 8 px default
-- (a corner the owner changed in Studio keeps their size).
pcall(function()
	for _, d in gui:GetDescendants() do
		local r = d:IsA("UICorner") and d:GetAttribute("HuzzRadius")
		if typeof(r) == "UDim" and d.CornerRadius == UDim.new(0, 8) and r ~= d.CornerRadius then
			(d :: UICorner).CornerRadius = r
		end
	end
end)

-- Each part starts on its own: if one fails, the rest still work and the problem shows on screen.
Report.mount(gui)
Report.run("Window manager", ModalManager.mount, gui)
Report.run("Toast", Toast.mount, gui)
for _, name in { "LobbyHud", "MainMenu", "Shop", "Settings", "Index", "Tiers", "Dances", "Progression", "MapVote", "GirlRoll", "PowerBar", "HeroChoice", "HowToPlay", "DanceWheel", "NextMap", "SpinWheel", "CrateOpen", "Results", "Admin" } do
	local module = Screens:FindFirstChild(name)
	if module then Report.run(name, function() require(module).build(gui) end) end
end
Report.run("State", State.start)

-- In Studio only: which build this is, small in the bottom right corner (and in Output), so a recording shows whether
-- the newest code ran. An old date means Rojo or an old file put old scripts back: pull in GitHub Desktop first.
Report.run("Build stamp", function()
	if not game:GetService("RunService"):IsStudio() then return end
	local build = game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config:FindFirstChild("Build")
	local stamp = if build then require(build).Stamp else "unknown"
	print("[Huzz] Build " .. stamp)
	local label = Instance.new("TextLabel")
	label.Name = "HuzzBuildStamp"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -6, 1, -4)
	label.Size = UDim2.fromOffset(220, 14)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 11
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.35
	label.TextStrokeTransparency = 0.6
	label.Text = "build " .. stamp
	label.ZIndex = 50
	label.Parent = gui
end)

-- Audio: Master / Music / Effects sound groups (made by the server's Bootstrap).
local focused = true
local function applyAudio()
	local master = SoundService:FindFirstChild("Master") :: SoundGroup?
	if not master then return end
	local mute = State.setting("MuteUnfocused") and not focused
	master.Volume = if mute then 0 else State.setting("MasterVolume") / 100
	local music, effects = master:FindFirstChild("Music") :: SoundGroup?, master:FindFirstChild("Effects") :: SoundGroup?
	local interface = master:FindFirstChild("Interface") :: SoundGroup?
	if music then music.Volume = State.setting("MusicVolume") / 100 end
	if effects then effects.Volume = State.setting("EffectsVolume") / 100 end
	if interface then interface.Volume = State.setting("InterfaceVolume") / 100 end
end
UserInputService.WindowFocusReleased:Connect(function() focused = false; applyAudio() end)
UserInputService.WindowFocused:Connect(function() focused = true; applyAudio() end)
SoundService.DescendantAdded:Connect(function(d) if d:IsA("SoundGroup") then applyAudio() end end)

State.changed(function()
	Motion.reduced = State.setting("ReducedMotion") == true
	Effects.setCalm(Motion.reduced) -- (shine, rays and pulses stop too)
	applyAudio()
end)
applyAudio()

-- The Open Menu key (rebindable in Settings > Controls). Ignored while typing in chat or a text box.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if UserInputService:GetFocusedTextBox() then return end
	-- A key saved before Q / E / H became the round moves' keys falls back to M.
	local menuKey = State.setting("MenuKey")
	if SettingsConfig.ReservedKeys[menuKey] then menuKey = "M" end
	if input.KeyCode.Name == menuKey then ModalManager.toggle("Menu") end
end)

-- VIP chat tag: the server sets the "VIP" attribute from real Game Pass ownership.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender and sender:GetAttribute("VIP") then
		props.PrefixText = '<font color="#F8C56E">[VIP]</font> ' .. message.PrefixText
	end
	return props
end
