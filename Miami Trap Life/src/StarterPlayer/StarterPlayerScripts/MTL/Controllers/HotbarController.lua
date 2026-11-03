--!strict
-- The hotbar at the bottom centre (MTL_HUD/Hotbar): round slots with the key number above.
--   Slot 1 = your fists (puts any gun away), then the guns you own (GunController, keys 2-6),
--   then any Roblox Tools in your Backpack (next free numbers). Replaces the gun piece's WeaponBar and the
--   default Roblox backpack bar, so there is only one row of slots on screen.
-- Gun keys live in Config/Guns.Keys (Slots start at Two, One is in Holster).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Config = require(ReplicatedStorage.MTL.Config.HUD)
local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local H = Theme.HUD

local Hotbar = {}

local gui: any
local guns: any = nil -- GunController (optional)
local lastKey = ""
local TOOL_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

type SlotSpec = { id: string, key: number, name: string, emoji: string, image: string?, active: boolean, press: () -> () }

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function equippedTool(): Tool?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Tool")
end

local function backpackTools(): { Tool }
	local list = {}
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, t in bp:GetChildren() do
			if t:IsA("Tool") then
				table.insert(list, t)
			end
		end
	end
	local held = equippedTool()
	if held then
		table.insert(list, held)
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function specs(): { SlotSpec }
	local out: { SlotSpec } = {}
	local state = guns and guns.state() or {}
	local gunList = state.guns or {}
	local equippedGun = guns and guns.equipped()
	local held = equippedTool()
	table.insert(out, {
		id = "Fists",
		key = 1,
		name = "Fists",
		emoji = Config.Hotbar.FistsEmoji,
		image = H.Images.Fists,
		active = equippedGun == nil and held == nil,
		press = function()
			if guns then
				guns.holster()
			end
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:UnequipTools()
			end
		end,
	})
	for i, g in gunList do
		local def = Guns.Defs[g.id]
		local id = g.id
		table.insert(out, {
			id = "Gun_" .. id,
			key = i + 1,
			name = if def then def.Display else id,
			emoji = Config.Hotbar.GunEmoji,
			image = H.Images["Gun_" .. id],
			active = equippedGun == id,
			press = function()
				if not guns then
					return
				end
				if guns.equipped() == id then
					guns.holster()
				else
					guns.equip(id)
				end
			end,
		})
	end
	for j, tool in backpackTools() do
		local t = tool
		table.insert(out, {
			id = "Tool_" .. t.Name,
			key = #gunList + 1 + j,
			name = t.Name,
			emoji = "🎒",
			image = if t.TextureId ~= "" then t.TextureId else nil,
			active = t == held,
			press = function()
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				if t.Parent == char then
					hum:UnequipTools()
				else
					if guns then
						guns.holster()
					end
					hum:EquipTool(t)
				end
			end,
		})
	end
	return out
end

local current: { SlotSpec } = {}

local function styleSlot(slot: any, s: SlotSpec)
	local disc = slot.Disc
	-- selected: a bright ring and the item's name above; others: a faint ring
	disc.Stroke.Color = if s.active then H.Gold else H.Line
	disc.Stroke.Transparency = if s.active then 0 else 0.7
	disc.Stroke.Thickness = if s.active then 3 else 2
	slot.ItemName.Visible = s.active and s.id ~= "Fists"
	slot.ItemName.Text = string.upper(s.name)
	slot.Key.TextColor3 = if s.active then H.Gold else H.Paper
	slot.Key.Visible = not touchOnly()
end

local function refresh()
	local list = specs()
	current = list
	-- rebuild only when the set of slots changes; otherwise just restyle
	local sig = {}
	for _, s in list do
		table.insert(sig, s.id .. (if s.active then "*" else ""))
	end
	local key = table.concat(sig, "|")
	if key == lastKey then
		return
	end
	local bar = gui.Hotbar
	local template = bar.SlotTemplate
	local want: { [string]: boolean } = {}
	for i, s in list do
		local name = "Slot_" .. s.id
		want[name] = true
		local slot = bar:FindFirstChild(name)
		local wasActive = slot and slot:GetAttribute("Active")
		if not slot then
			slot = template:Clone()
			slot.Name = name
			slot.Visible = true
			local old = slot.Disc:FindFirstChild("Icon")
			if s.image and s.image ~= "" and old then
				old:Destroy()
				local img = Instance.new("ImageLabel")
				img.Name = "Icon"
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.5, 0.5)
				img.Size = UDim2.fromOffset(44, 44)
				img.BackgroundTransparency = 1
				img.Image = s.image
				img.Parent = slot.Disc
			elseif old then
				old.Text = s.emoji
			end
			slot.Parent = bar
			local id = s.id
			slot.Activated:Connect(function()
				for _, c in current do
					if c.id == id then
						c.press()
					end
				end
			end)
			slot.Pop.Scale = 0.5
			Motion.tween(slot.Pop, Motion.Spring, { Scale = 1 })
		end
		slot.LayoutOrder = i
		slot.Key.Text = tostring(s.key)
		styleSlot(slot, s)
		if s.active and not wasActive then
			slot.Pop.Scale = 1.15
			Motion.tween(slot.Pop, Motion.Spring, { Scale = 1 })
		end
		slot:SetAttribute("Active", s.active)
	end
	for _, c in bar:GetChildren() do
		if c:IsA("GuiButton") and c.Name ~= "SlotTemplate" and not want[c.Name] then
			c:Destroy()
		end
	end
	lastKey = key
end

-- keep the bar clear of the phone peeking in the bottom-right corner (~340 px)
local function fit()
	local cam = workspace.CurrentCamera
	local bar = gui.Hotbar
	local width = (#current * 76) * (bar.Scale.Scale)
	local vw = cam.ViewportSize.X
	local right = vw / 2 + width / 2
	local shift = math.max(0, right - (vw - 350))
	bar.Position = UDim2.new(0.5, -shift, 1, -10)
end

function Hotbar.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:WaitForChild("MTL_HUD", 10)
	if not gui or not gui:FindFirstChild("Hotbar") then
		warn("[MTL Hotbar] MTL_HUD has no Hotbar (old HUD saved in StarterGui?)")
		return
	end
	local mod = script.Parent:FindFirstChild("GunController")
	if mod then
		local ok, g = pcall(require, mod)
		if ok then
			guns = g
			g.Changed:Connect(refresh)
		end
	end
	-- one bar on screen: hide the default backpack and the gun piece's own bar
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	task.spawn(function()
		local gunGui = pg:WaitForChild("MTL_Gun", 10)
		local wb = gunGui and gunGui:FindFirstChild("WeaponBar")
		if wb then
			wb:Destroy()
		end
	end)

	-- tool keys (guns handle their own keys in GunController)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UIState.get().lockControls then
			return
		end
		for _, s in current do
			if string.sub(s.id, 1, 5) == "Tool_" and TOOL_KEYS[s.key] == input.KeyCode then
				s.press()
				return
			end
		end
		-- key 1 also drops a held tool (GunController holsters guns on it)
		if input.KeyCode == Enum.KeyCode.One and equippedTool() then
			current[1].press()
		end
	end)

	local function watchChar(char: Model)
		char.ChildAdded:Connect(refresh)
		char.ChildRemoved:Connect(refresh)
	end
	if player.Character then
		watchChar(player.Character)
	end
	player.CharacterAdded:Connect(watchChar)
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			c.ChildAdded:Connect(refresh)
			c.ChildRemoved:Connect(refresh)
		end
	end)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		bp.ChildAdded:Connect(refresh)
		bp.ChildRemoved:Connect(refresh)
	end

	refresh()
	-- the gun list can change without an equip (bought / given), so check twice a second as well
	task.spawn(function()
		while true do
			task.wait(0.5)
			refresh()
			fit()
		end
	end)
	gui.Hotbar.Visible = true
end

return Hotbar
