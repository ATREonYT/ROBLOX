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
-- A square HUD button (reference 13: 66 x 60, navy gradient #2B3575 -> #152242, light top line, dark ring).
local function squareButton(parent: Instance, name: string, icon: string, y: number, onClick: () -> ())
	local b = Kit.button({ Name = name, Style = "Hud", Text = "", Position = UDim2.fromOffset(25, y), Size = UDim2.fromOffset(66, 60), Corner = 5, RimThickness = 1.5, Parent = parent })
	b.Instance:FindFirstChild("Content"):Destroy()
	b.Instance.BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.HudTop), ColorSequenceKeypoint.new(0.5, C.HudMid), ColorSequenceKeypoint.new(1, C.HudBottom) }), Parent = b.Instance })
	Kit.icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(38, 38), Parent = b.Instance })
	Kit.text({ Name = "Label", Text = name, FontFace = Theme.Fonts.Label, TextSize = 13.5, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 14), Parent = b.Instance })
	b.onClick(onClick)
	return b
end

function LobbyHud.build(parent: Instance)
	local root = new("Frame", { Name = "LobbyHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })

	local left = group(root, "Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), Vector2.new(100, 300))
	squareButton(left, "Index", "CollectionBook", 32, function() MainMenu.go("Index") end)
	squareButton(left, "Tiers", "TierCrown", 98, function() MainMenu.go("Tiers") end)
	squareButton(left, "Dances", "DancesNote", 164, function() MainMenu.go("Dances") end)
	local menu = squareButton(left, "Menu", "MainMenuLines", 233, function() ModalManager.toggle("Menu") end)
	local hint = Kit.text({ Name = "KeyHint", Text = "", FontFace = Theme.Fonts.Button, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.DarkText, BackgroundTransparency = 0, BackgroundColor3 = C.SelectedTab, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 3, Parent = menu.Instance })
	Kit.corner(3).Parent = hint

	local bottom = group(root, "Balances", Vector2.new(0, 1), UDim2.fromScale(0, 1), Vector2.new(300, 50))
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(23, 7), Width = 131, Height = 32, TextSize = 14, PlusStyle = "HudPlus", Parent = bottom })
	local gems = Kit.pill({ Name = "Gems", Icon = "CurrencyGem", Position = UDim2.fromOffset(161, 7), Width = 131, Height = 32, TextSize = 14, PlusStyle = "HudPlus", Parent = bottom })
	coins.plus.onClick(function() ModalManager.open("Shop", "Coins") end)
	gems.plus.onClick(function() Toast.show("Gem packs aren't for sale.") end)

	local topRight = group(root, "TopRight", Vector2.new(1, 0), UDim2.fromScale(1, 0), Vector2.new(84, 70))
	local gear = Kit.button({ Name = "Settings", Style = "Hud", Text = "", Position = UDim2.fromOffset(1, 31), Size = UDim2.fromOffset(53, 44), Corner = 5, Icon = "SettingsGear", IconSize = 34, RimThickness = 1.5, Parent = topRight })
	gear.Instance.BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.HudTop), ColorSequenceKeypoint.new(0.5, C.HudMid), ColorSequenceKeypoint.new(1, C.HudBottom) }), Parent = gear.Instance })
	gear.onClick(function() ModalManager.toggle("Settings") end)

	local top = group(root, "Round", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), Vector2.new(261, 70))
	-- Reference 13: a purple bar with a darker seam low down, a dark rim, two studs at each end, "NEXT ROUND" small
	-- and the clock bigger.
	local banner = new("Frame", { Name = "NextRound", Position = UDim2.fromOffset(2, 21.5), Size = UDim2.fromOffset(257, 40), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = top }, { Kit.corner(6), Kit.stroke(C.BannerRim, 2) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Banner), ColorSequenceKeypoint.new(0.72, C.Banner), ColorSequenceKeypoint.new(0.75, C.BannerSeam), ColorSequenceKeypoint.new(1, C.BannerSeam) }), Parent = banner })
	Kit.studs(banner, 8, 44, 14)
	Kit.studs(banner, 213, 249, 14)
	local row = new("Frame", { Name = "Text", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = banner }, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Kit.text({ Name = "Label", Text = "NEXT ROUND", FontFace = Theme.Fonts.Button, TextSize = 17, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, Parent = row })
	local bannerText = Kit.text({ Name = "Clock", Text = "", FontFace = Theme.Fonts.Number, TextSize = 25, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 2, Parent = row })

	task.spawn(function()
		while root.Parent do
			local at = workspace:GetAttribute("NextRoundAt")
			if type(at) == "number" then
				banner.Visible = true
				bannerText.Text = Format.clock(at - workspace:GetServerTimeNow())
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
