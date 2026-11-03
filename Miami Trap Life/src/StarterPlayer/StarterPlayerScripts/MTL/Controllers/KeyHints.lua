--!strict
-- Keybind hints that follow what you're doing (LihFolk build list #5): a short column of [key] + action beside
-- the minimap. On foot / aiming a gun / in a car / on the phone / crouched each show their own set.
-- Keyboard only (touch has on-screen buttons, gamepads get their own glyphs later).
-- Settings.KeyHintsMode: 0/nil = auto (gone after 10 minutes in the session), 1 = always, 2 = never.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Build = require(ReplicatedStorage.MTL.UI.Build.HUD)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer

local KeyHints = {}

local AUTO_HIDE_AFTER = 10 * 60 -- seconds of play this session
local started = os.clock()

local gui: ScreenGui
local list: Frame
local shownKey = ""

local function optional(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

local Gun: any, Phone: any, Crouch: any

local function setting(key: string): any
	local d = ClientData.get()
	return d and d.Settings and d.Settings[key]
end

-- the hint set for right now: { {key, text} }
local function current(): { { string } }
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if Phone and Phone.isOpen and Phone.isOpen() then
		return { { "M", "Put phone away" }, { "Esc", "Back" } }
	end
	if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
		return { { "W S", "Drive / brake" }, { "A D", "Steer" }, { "Space", "Get out" } }
	end
	if hum and hum.Sit then
		return { { "Space", "Stand up" } }
	end
	local gunId = Gun and Gun.equipped and Gun.equipped()
	if gunId then
		if Gun.isAiming and Gun.isAiming() then
			return { { "LMB", "Shoot" }, { "R", "Reload" }, { "RMB", "Stop aiming" } }
		end
		return { { "RMB", "Aim" }, { "R", "Reload" }, { "1", "Put away" }, { "Shift", "Sprint" } }
	end
	local sprintText = if setting("SprintToggle") == true then "Sprint (toggle)" else "Sprint"
	if Crouch and Crouch.isCrouching and Crouch.isCrouching() then
		return { { "C", "Stand up" }, { "Shift", sprintText } }
	end
	return { { "Shift", sprintText }, { "C", "Crouch" }, { "E", "Interact" }, { "M", "Phone" }, { "G", "Menu" } }
end

local function wanted(): boolean
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return false
	end
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then
		return false
	end
	if UIState.get().hideHUD then
		return false
	end
	local mode = setting("KeyHintsMode") -- 0 / nil auto, 1 always, 2 never (the Settings panel)
	if mode == 2 then
		return false
	elseif mode == 1 then
		return true
	end
	return os.clock() - started < AUTO_HIDE_AFTER
end

-- sits beside the minimap (to its right, bottom-aligned), clear of the menu button and the hotbar;
-- without a minimap it takes the bottom-left corner
local function place()
	local mm = player.PlayerGui:FindFirstChild("MTL_Minimap") :: ScreenGui?
	local right: number?, bottom: number? = nil, nil
	if mm and mm.Enabled then
		local inset = if mm.IgnoreGuiInset then 0 else game:GetService("GuiService"):GetGuiInset().Y
		for _, c in mm:GetChildren() do
			if c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.Y > 40 then
				local r = c.AbsolutePosition.X + c.AbsoluteSize.X
				local b = c.AbsolutePosition.Y + c.AbsoluteSize.Y + inset
				right = if right then math.max(right, r) else r
				bottom = if bottom then math.max(bottom, b) else b
			end
		end
	end
	if right and bottom then
		list.Position = UDim2.fromOffset(right + 14, bottom)
	else
		list.Position = UDim2.new(0, 18, 1, -18)
	end
end

local function refresh()
	local on = wanted()
	if not on then
		if list.Visible then
			list.Visible = false
			shownKey = ""
		end
		return
	end
	place()
	local set = current()
	local key = ""
	for _, h in set do
		key ..= h[1] .. h[2] .. "|"
	end
	if key == shownKey and list.Visible then
		return
	end
	shownKey = key
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, h in set do
		local row = Build.keyHint(h[1], h[2])
		row.LayoutOrder = i
		row.Parent = list
		-- each row slides in a few px and fades, one after another
		local k, t = row:FindFirstChild("Key") :: TextLabel, row:FindFirstChild("Text") :: TextLabel
		k.TextTransparency, t.TextTransparency = 1, 1
		k.BackgroundTransparency = 1
		task.delay(i * 0.03, function()
			Motion.tween(k, Motion.Normal, { TextTransparency = 0, BackgroundTransparency = 0.12 })
			Motion.tween(t, Motion.Normal, { TextTransparency = 0 })
		end)
	end
	list.Visible = true
end

function KeyHints.init()
	Gun = optional("GunController")
	Phone = optional("PhoneController")
	Crouch = optional("Crouch")
	gui = Instance.new("ScreenGui")
	gui.Name = "MTL_KeyHints"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")
	list = Instance.new("Frame")
	list.Name = "Hints"
	list.AnchorPoint = Vector2.new(0, 1)
	list.Size = UDim2.fromOffset(260, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Visible = false
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = list
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(0.25)
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		pcall(refresh)
	end)
end

return KeyHints
