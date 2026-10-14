-- Starts the Huzz Valley UI and applies the player's settings (audio, reduced motion, menu key, VIP chat tag).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent:WaitForChild("UI")
local Report = require(UI:WaitForChild("Report"))
local Motion = require(UI.Motion)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Scale = require(UI.Scale)
local Screens = UI.Screens

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HuzzUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")
Scale.setRoot(gui)

-- Each part starts on its own: if one fails, the rest still work and the problem shows on screen.
Report.mount(gui)
Report.run("Window manager", ModalManager.mount, gui)
Report.run("Toast", Toast.mount, gui)
for _, name in { "LobbyHud", "MainMenu", "Shop", "Settings", "Index", "Tiers", "Dances", "Progression" } do
	local module = Screens:FindFirstChild(name)
	if module then Report.run(name, function() require(module).build(gui) end) end
end
Report.run("State", State.start)

-- Audio: Master / Music / Effects sound groups (made by the server's Bootstrap).
local focused = true
local function applyAudio()
	local master = SoundService:FindFirstChild("Master") :: SoundGroup?
	if not master then return end
	local mute = State.setting("MuteUnfocused") and not focused
	master.Volume = if mute then 0 else State.setting("MasterVolume") / 100
	local music, effects = master:FindFirstChild("Music") :: SoundGroup?, master:FindFirstChild("Effects") :: SoundGroup?
	if music then music.Volume = State.setting("MusicVolume") / 100 end
	if effects then effects.Volume = State.setting("EffectsVolume") / 100 end
end
UserInputService.WindowFocusReleased:Connect(function() focused = false; applyAudio() end)
UserInputService.WindowFocused:Connect(function() focused = true; applyAudio() end)
SoundService.ChildAdded:Connect(applyAudio)

State.changed(function()
	Motion.reduced = State.setting("ReducedMotion") == true
	applyAudio()
end)
applyAudio()

-- The Open Menu key (rebindable in Settings > Controls). Ignored while typing in chat or a text box.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode.Name == State.setting("MenuKey") then ModalManager.toggle("Menu") end
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
