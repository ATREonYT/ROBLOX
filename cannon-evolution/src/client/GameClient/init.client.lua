--[[
	GameClient  (LocalScript)  ->  StarterPlayer > StarterPlayerScripts > GameClient
	Its child ModuleScripts are the UI: Kit, State, HUD, Effects, Popups and
	one module per panel (Shop, Cannons, Pets, Rebirth, Worlds, Upgrades,
	Missions, Rewards, Leaderboard, Settings).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Kit = require(script.Kit)
local State = require(script.State)

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Screen + scaling (designed at 1280x720, scaled to any screen)
---------------------------------------------------------------------------
local gui = Kit.new("ScreenGui", {
	Name = "MainUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local root = Kit.new("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1280, 720),
	Parent = gui,
})
local uiScale = Kit.new("UIScale", { Parent = root })
local function rescale()
	local view = Workspace.CurrentCamera.ViewportSize
	local s = math.min(view.X / 1280, view.Y / 720)
	uiScale.Scale = s
	root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- Dim and a soft blur behind open panels (blur like the Stone Skipping menus, Oct 30)
local blur = Kit.new("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = workspace.CurrentCamera })
local dim = Kit.new("TextButton", {
	Name = "Dim",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 15,
	Parent = root,
})

---------------------------------------------------------------------------
-- Sounds (fill ids in GameConfig.Sounds if you want them)
---------------------------------------------------------------------------
local soundIds = Config.Sounds or {}
for name, id in pairs(soundIds) do
	if id ~= "" then
		Kit.Sounds[name] = Kit.new("Sound", { SoundId = id, Volume = 0.5, Parent = gui })
	end
end

---------------------------------------------------------------------------
-- Panel manager
---------------------------------------------------------------------------
local ctx = {
	Kit = Kit,
	State = State,
	Config = Config,
	Root = root,
	Player = player,
	Panels = {},
}

local current = nil

function ctx.Close()
	if not current then
		return
	end
	local panel = current
	current = nil
	Kit.tween(Kit.scale(panel.Frame), 0.15, { Scale = 0.6 })
	Kit.tween(dim, 0.2, { BackgroundTransparency = 1 })
	Kit.tween(blur, 0.2, { Size = 0 })
	task.delay(0.15, function()
		if current ~= panel then
			panel.Frame.Visible = false
		end
		if not current then
			dim.Visible = false
		end
	end)
end

-- Close only if that panel is the one open (used when walking away from an egg)
function ctx.CloseIf(name)
	if current and current == ctx.Panels[name] then
		ctx.Close()
	end
end

function ctx.Open(name, tab, arg)
	local panel = ctx.Panels[name]
	if not panel then
		return
	end
	if current == panel then
		if tab and panel.OnOpen then
			panel.OnOpen(tab, arg)
		end
		return
	end
	if current then
		current.Frame.Visible = false
	end
	current = panel
	dim.Visible = true
	Kit.tween(dim, 0.2, { BackgroundTransparency = 0.7 })
	Kit.tween(blur, 0.2, { Size = 10 })
	panel.Frame.Visible = true
	local s = Kit.scale(panel.Frame)
	s.Scale = 0.6
	Kit.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.playSound("Open")
	if panel.OnOpen then
		panel.OnOpen(tab, arg)
	end
	if panel.Refresh then
		panel.Refresh()
	end
end

function ctx.Toggle(name, tab)
	if current == ctx.Panels[name] then
		ctx.Close()
	else
		ctx.Open(name, tab)
	end
end

function ctx.IsOpen(name)
	return current ~= nil and current == ctx.Panels[name]
end

dim.Activated:Connect(ctx.Close)

-- Request + show the server's message
function ctx.Request(action, ...)
	return State.Request(action, ...)
end

---------------------------------------------------------------------------
-- Build everything
---------------------------------------------------------------------------
local Popups = require(script.Popups)(ctx)
ctx.Popups = Popups
ctx.Notify = Popups.Notify

for _, name in ipairs({ "Shop", "Cannons", "Pets", "Rebirth", "Worlds", "Upgrades", "Missions", "Rewards", "Leaderboard", "Settings" }) do
	local panel = require(script:WaitForChild(name))(ctx)
	panel.Frame.Parent = root
	panel.Frame.ZIndex = 20
	ctx.Panels[name] = panel
	local close = panel.Frame:FindFirstChild("Close", true)
	if close then
		close.Activated:Connect(ctx.Close)
	end
end

require(script.HUD)(ctx)
require(script.Effects)(ctx)
require(script.Tutorial)(ctx)

-- Refresh the open panel whenever data changes
State.Changed:Connect(function(what)
	for _, panel in pairs(ctx.Panels) do
		if panel.Frame.Visible and panel.Refresh then
			panel.Refresh(what)
		elseif panel.AlwaysRefresh then
			panel.Refresh(what)
		end
	end
end)

-- "Before You Go!" when the Roblox menu opens
GuiService.MenuOpened:Connect(function()
	Popups.BeforeYouGo()
end)

-- Studio only: lets playtest checks open panels and tabs
if game:GetService("RunService"):IsStudio() then
	local debug = Instance.new("BindableFunction")
	debug.Name = "CannonUIDebug"
	debug.OnInvoke = function(name, tab, arg)
		if name == nil then
			local names = {}
			for n in pairs(ctx.Panels) do
				table.insert(names, n)
			end
			return names
		end
		ctx.Open(name, tab, arg)
		return true
	end
	debug.Parent = ctx.Player
end
