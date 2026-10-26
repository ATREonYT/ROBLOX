-- Only one main window is open at a time. Opening another switches to it (no stacking, no second blur);
-- Close / Escape / gamepad B returns to play. While a window is open the player's "MenuOpen" attribute is true,
-- so gameplay input (dash, tag) can ignore clicks meant for the menu.
-- Escape: Roblox's own menu takes that key, so a game script often gets it already handled (or not at all). A window
-- closes on Escape whether or not Roblox handled it, and also when Roblox's menu opens (bug hunt, Oct 20).
-- Pulled into a round: a full window (the Shop...) closes when you become a runner or catcher, or the line-up or the
-- HERO/CHICKEN pick starts for you, since it hides the round's HUD (RoundHud) and would cover the pick. The picked
-- runner's side panel (the Menu) closes too, so nothing sits over HERO and CHICKEN (bug hunt, Oct 20).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Motion = require(script.Parent.Motion)
local Scale = require(script.Parent.Scale)
local ShopStyle = require(script.Parent.ShopStyle)
local Sfx = require(script.Parent.Parent.Gameplay.Sfx)

local ModalManager = {}

type Screen = { window: any, onOpen: ((any) -> ())?, onClose: (() -> ())?, firstSelect: (() -> GuiObject?)?, items: (() -> { GuiObject })?, side: boolean?, noBlur: boolean? }
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
	local s = current and screens[current]
	local full = s ~= nil and not (s.side or s.noBlur) -- noBlur: windows that pop up by themselves (the map vote)
	Motion.tween(blur, "blur", 0.2, { Size = full and 8 or 0 })
end

function ModalManager.mount(screenGui: ScreenGui)
	blur = Lighting:FindFirstChild("HuzzMenuBlur") :: BlurEffect or Instance.new("BlurEffect")
	blur.Name = "HuzzMenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	-- No dim layer: on phones it only covered the safe area and left grey bands at the sides. The blur alone
	-- covers the whole screen.
	UserInputService.InputBegan:Connect(function(input)
		if not current then return end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			if UserInputService:GetFocusedTextBox() then return end -- (Escape leaves a text box first)
			ModalManager.close()
		end
	end)
	pcall(function() -- (guarded: the offline preview's GuiService has no MenuOpened)
		GuiService.MenuOpened:Connect(function()
			if current then ModalManager.close() end
		end)
	end)
	task.spawn(ModalManager.watchRound) -- (its own thread: it waits for the Round remote)
end

-- Should the open window close now that the round needs the screen? role: HuzzRole; stage: the Round's Stage;
-- picked: this player is the HERO/CHICKEN runner; side: the open window is a side panel (the Menu).
function ModalManager.roundWants(role: string?, stage: string?, picked: boolean, side: boolean): boolean
	if role ~= "Runner" and role ~= "Catcher" then return false end -- (the lobby, or watching from the bench)
	if picked and stage == "Picking" then return true end -- (HERO and CHICKEN must show, side panel or not)
	return not side
end

-- Closes a window that's in the way when the round starts for this player (see the header).
function ModalManager.watchRound()
	local player = Players.LocalPlayer
	local ok, round = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net).get("Round")
	end)
	if not player or not ok or not round then return end
	local function check(trigger: boolean)
		if not current or not trigger then return end
		local s = screens[current]
		local stage = round:GetAttribute("Stage")
		local picked = round:GetAttribute("PickId") == player.UserId
		if ModalManager.roundWants(player:GetAttribute("HuzzRole"), stage, picked, s ~= nil and s.side == true) then
			ModalManager.close()
		end
	end
	player:GetAttributeChangedSignal("HuzzRole"):Connect(function()
		local role = player:GetAttribute("HuzzRole")
		check(role == "Runner" or role == "Catcher")
	end)
	round:GetAttributeChangedSignal("Stage"):Connect(function()
		local stage = round:GetAttribute("Stage")
		check(stage == "Lineup" or stage == "Picking")
	end)
	round:GetAttributeChangedSignal("PickId"):Connect(function()
		check(round:GetAttribute("Stage") == "Picking")
	end)
end

function ModalManager.register(name: string, screen: Screen)
	screens[name] = screen
	local w = screen.window
	Scale.bind(w.Holder:FindFirstChild("FitScale"), function() return Scale.window(w.Width, w.Height) end)
	-- every menu in the Shop's look (owner, Oct 21: "restyle the shops so they have animations for the ui"); the Shop
	-- is that look already, and a side panel (the Menu) keeps its own
	if name ~= "Shop" and not screen.side then ShopStyle.restyle(w.Holder) end
	-- and the bright look on every window, the Shop's too (owner, Oct 21: "yes, everywhere"; ShopStyle.brighten)
	if not screen.side then ShopStyle.brighten(w.Holder) end
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
	Sfx.play("ui_close")
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
	Sfx.play("ui_open")
	Motion.open(w.Group, w.OpenScale, UDim2.fromScale(0.5, 0.5))
	if s.items then
		Motion.stagger(s.items())
	elseif name ~= "Shop" and name ~= "Inventory" then -- (the Shop and the Inventory pop their own cards; the tabs stay put)
		task.defer(function()
			if current == name then ShopStyle.popIn(ShopStyle.cards(w.Panel or w.Group)) end
		end)
	end
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
