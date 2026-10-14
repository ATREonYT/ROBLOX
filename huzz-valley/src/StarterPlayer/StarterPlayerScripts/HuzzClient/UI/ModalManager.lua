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

type Screen = { window: any, onOpen: ((any) -> ())?, onClose: (() -> ())?, firstSelect: (() -> GuiObject?)?, items: (() -> { GuiObject })?, side: boolean? }
local screens: { [string]: Screen } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}
local blur: BlurEffect

-- Updates the open flag, tells listeners, and blurs the world only for full windows (a side panel such as
-- the Menu sits over the HUD's side buttons and leaves the game in view).
local function changed()
	local p = Players.LocalPlayer
	if p then p:SetAttribute("MenuOpen", current ~= nil) end
	for _, fn in listeners do task.spawn(fn, current) end
	local full = current ~= nil and not (screens[current] and screens[current].side)
	Motion.tween(blur, "blur", 0.2, { Size = full and 8 or 0 })
end

function ModalManager.mount(screenGui: ScreenGui)
	blur = Lighting:FindFirstChild("HuzzMenuBlur") :: BlurEffect or Instance.new("BlurEffect")
	blur.Name = "HuzzMenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	-- No dim layer: on phones it only covered the safe area and left grey bands at the sides. The blur alone
	-- covers the whole screen.
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
	Motion.close(w.Group, w.OpenScale, function()
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
	Motion.open(w.Group, w.OpenScale, UDim2.fromScale(0.5, 0.5))
	if s.items then Motion.stagger(s.items()) end
	changed()
	if UserInputService.GamepadEnabled and s.firstSelect then GuiService.SelectedObject = s.firstSelect() end
	return true
end

function ModalManager.close()
	local name = current
	if not name then return end
	current = nil
	hide(name)
	if GuiService.SelectedObject then GuiService.SelectedObject = nil end
	changed()
end

function ModalManager.toggle(name: string, arg: any?)
	if current == name then ModalManager.close() else ModalManager.open(name, arg) end
end

function ModalManager.current(): string? return current end
function ModalManager.has(name: string): boolean return screens[name] ~= nil end
function ModalManager.isSide(name: string?): boolean return name ~= nil and screens[name] ~= nil and screens[name].side == true end
function ModalManager.changed(fn: (string?) -> ()) table.insert(listeners, fn) end

return ModalManager
