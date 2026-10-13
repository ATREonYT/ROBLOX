-- Only one main window is open at a time. Opening another switches to it (no stacking, no second blur);
-- Close / Escape / gamepad B returns to play. While a window is open the player's "MenuOpen" attribute is true,
-- so gameplay input (dash, tag) can ignore clicks meant for the menu.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Motion = require(script.Parent.Motion)
local Scale = require(script.Parent.Scale)

local ModalManager = {}

type Screen = { window: any, onOpen: ((any) -> ())?, onClose: (() -> ())?, firstSelect: (() -> GuiObject?)? }
local screens: { [string]: Screen } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}
local blur: BlurEffect
local dim: Frame?

local function setOpenFlag(on: boolean)
	local p = Players.LocalPlayer
	if p then p:SetAttribute("MenuOpen", on) end
	for _, fn in listeners do task.spawn(fn, current) end
	Motion.tween(blur, "blur", 0.2, { Size = on and 8 or 0 })
	if dim then Motion.tween(dim, "dim", 0.2, { BackgroundTransparency = on and 0.75 or 1 }) end
end

function ModalManager.mount(screenGui: ScreenGui)
	blur = Lighting:FindFirstChild("HuzzMenuBlur") :: BlurEffect or Instance.new("BlurEffect")
	blur.Name = "HuzzMenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local d = Instance.new("Frame")
	d.Name = "Dim"
	d.BackgroundColor3 = Color3.new(0, 0, 0)
	d.BackgroundTransparency = 1
	d.BorderSizePixel = 0
	d.Size = UDim2.fromScale(1, 1)
	d.ZIndex = 0
	d.Parent = screenGui
	dim = d
	UserInputService.InputBegan:Connect(function(input, processed)
		if not current then return end
		if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
			ModalManager.close()
		end
	end)
end

function ModalManager.register(name: string, screen: Screen)
	screens[name] = screen
	local w = screen.window
	Scale.bind(w.Holder:FindFirstChild("FitScale"), function() return Scale.window(w.Width, w.Height) end)
end

local function hide(name: string, instant: boolean?)
	local s = screens[name]
	if not s then return end
	if s.onClose then s.onClose() end
	local w = s.window
	if instant then
		w.Group.Visible = false
		w.Holder.Visible = false
		return
	end
	Motion.close(w.Group, function()
		if current ~= name then w.Holder.Visible = false end
	end)
end

-- Opens a window (arg goes to its onOpen, e.g. which tab). Opening the open window just passes the new arg.
function ModalManager.open(name: string, arg: any?)
	local s = screens[name]
	if not s then return false end
	if current == name then
		if s.onOpen then s.onOpen(arg) end
		return true
	end
	local previous = current
	current = name
	if previous then hide(previous, true) end
	local w = s.window
	w.Holder.Visible = true
	if s.onOpen then s.onOpen(arg) end
	Motion.open(w.Group, w.OpenScale, UDim2.fromScale(0, 0))
	if not previous then setOpenFlag(true) else for _, fn in listeners do task.spawn(fn, current) end end
	if UserInputService.GamepadEnabled and s.firstSelect then GuiService.SelectedObject = s.firstSelect() end
	return true
end

function ModalManager.close()
	local name = current
	if not name then return end
	current = nil
	hide(name)
	if GuiService.SelectedObject then GuiService.SelectedObject = nil end
	setOpenFlag(false)
end

function ModalManager.toggle(name: string, arg: any?)
	if current == name then ModalManager.close() else ModalManager.open(name, arg) end
end

function ModalManager.current(): string? return current end
function ModalManager.has(name: string): boolean return screens[name] ~= nil end
function ModalManager.changed(fn: (string?) -> ()) table.insert(listeners, fn) end

return ModalManager
