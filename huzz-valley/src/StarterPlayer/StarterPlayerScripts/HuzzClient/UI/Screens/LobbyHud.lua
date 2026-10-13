-- Lobby HUD (design/pages/13): left column (Index, Tiers, Dances, Menu), coin and gem balances bottom-left,
-- settings top-right, and the next-round countdown top-centre. Hidden while a window is open.
-- The countdown only shows when the round system sets Workspace attribute "NextRoundAt" (server time, seconds);
-- there is no round system yet, so it stays hidden rather than showing a made-up timer.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Scale = require(UI.Scale)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local MainMenu = require(script.Parent.MainMenu)

local C = Theme.Colors
local new = Kit.new

local LobbyHud = {}
local PAGE_H = 347

local function group(parent: Instance, name: string, anchor: Vector2, pos: UDim2, size: Vector2)
	local f = new("Frame", { Name = name, AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Parent = parent })
	Scale.bind(new("UIScale", { Parent = f }), function() return Scale.hud(PAGE_H) end)
	return f
end

-- A square HUD button with its label underneath (reference: 69 x 59).
local function squareButton(parent: Instance, name: string, icon: string, y: number, onClick: () -> ())
	local b = Kit.button({ Name = name, Style = "Tab", Text = "", Position = UDim2.fromOffset(23, y), Size = UDim2.fromOffset(54, 56), Corner = 5, Parent = parent })
	b.Instance:FindFirstChild("Content"):Destroy()
	Kit.stroke(C.Ink, 1.5, 0.2).Parent = b.Instance
	Kit.icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(36, 36), Parent = b.Instance })
	Kit.text({ Name = "Label", Text = name, FontFace = Theme.Fonts.Label, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 14), Parent = b.Instance })
	b.onClick(onClick)
	return b
end

function LobbyHud.build(parent: Instance)
	local root = new("Frame", { Name = "LobbyHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })

	local left = group(root, "Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), Vector2.new(100, 300))
	squareButton(left, "Index", "CollectionBook", 30, function() MainMenu.go("Index") end)
	squareButton(left, "Tiers", "TierCrown", 94, function() MainMenu.go("Tiers") end)
	squareButton(left, "Dances", "DancesNote", 158, function() MainMenu.go("Dances") end)
	local menu = squareButton(left, "Menu", "MainMenuLines", 222, function() ModalManager.toggle("Menu") end)
	local hint = Kit.text({ Name = "KeyHint", Text = "", FontFace = Theme.Fonts.Button, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.DarkText, BackgroundTransparency = 0, BackgroundColor3 = C.SelectedTab, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 3, Parent = menu.Instance })
	Kit.corner(3).Parent = hint

	local bottom = group(root, "Balances", Vector2.new(0, 1), UDim2.fromScale(0, 1), Vector2.new(300, 50))
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(23, 8), Width = 131, Height = 32, TextSize = 14, Parent = bottom })
	local gems = Kit.pill({ Name = "Gems", Icon = "CurrencyGem", Position = UDim2.fromOffset(161, 8), Width = 131, Height = 32, TextSize = 14, Parent = bottom })
	coins.plus.onClick(function() ModalManager.open("Shop", "Coins") end)
	gems.plus.onClick(function() Toast.show("Gem packs aren't for sale.") end)

	local topRight = group(root, "TopRight", Vector2.new(1, 0), UDim2.fromScale(1, 0), Vector2.new(84, 70))
	local gear = Kit.button({ Name = "Settings", Style = "Tab", Text = "", Position = UDim2.fromOffset(4, 28), Size = UDim2.fromOffset(50, 46), Corner = 5, Icon = "SettingsGear", IconSize = 32, Parent = topRight })
	Kit.stroke(C.Ink, 1.5, 0.2).Parent = gear.Instance
	gear.onClick(function() ModalManager.toggle("Settings") end)

	local top = group(root, "Round", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), Vector2.new(261, 70))
	local banner = new("Frame", { Name = "NextRound", Position = UDim2.fromOffset(0, 21), Size = UDim2.fromOffset(261, 42), BackgroundColor3 = C.Pill, BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, Parent = top }, { Kit.corner(6), Kit.stroke(C.Header, 2.5) })
	local bannerText = Kit.text({ Name = "Text", Text = "", FontFace = Theme.Fonts.Number, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextWrapped = false, Parent = banner })

	task.spawn(function()
		while root.Parent do
			local at = workspace:GetAttribute("NextRoundAt")
			if type(at) == "number" then
				banner.Visible = true
				bannerText.Text = "NEXT ROUND  " .. Format.clock(at - workspace:GetServerTimeNow())
			else
				banner.Visible = false
			end
			task.wait(0.25)
		end
	end)

	local function sync(data)
		coins.setAmount(Format.commas(data.Coins))
		gems.setAmount(Format.commas(data.Gems))
		local showHints = State.setting("ShowKeyHints") == true
		hint.Visible = showHints
		hint.Text = tostring(State.setting("MenuKey"))
	end
	State.changed(sync)
	sync(State.data)
	ModalManager.changed(function(current) root.Visible = current == nil end)
	return root
end

return LobbyHud
