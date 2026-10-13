-- Main menu (design/pages/12): a left-side list of every window. Screens that aren't built yet say so.
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local new = Kit.new

local MainMenu = {}

local W, H = 199, 275 -- measured on reference 12
MainMenu.Entries = {
	{ Key = "Shop", Text = "Shop", Icon = "ShopCart" },
	{ Key = "Index", Text = "Index", Icon = "CollectionBook" },
	{ Key = "Tiers", Text = "Tiers", Icon = "TierCrown" },
	{ Key = "Dances", Text = "Dances", Icon = "DancesNote" },
	{ Key = "Progression", Text = "Progression", Icon = "RewardsTrophy" },
	{ Key = "Settings", Text = "Settings", Icon = "SettingsGear" },
}

-- Opens a screen by key, or explains that it isn't built yet.
function MainMenu.go(key: string, arg: any?)
	if not ModalManager.open(key, arg) then Toast.show(key .. " is coming in the next build.") end
end

function MainMenu.build(parent: Instance)
	local window = Kit.window({ Name = "Menu", Title = "MENU", Icon = "MainMenuLines", Width = W, Height = H, HeaderHeight = 36, TitleX = 40, TitleSize = 26, TitleWidth = 84, StudsTo = 158, CloseSize = Vector2.new(30, 30), PanelColor = C.MenuPanel, Parent = parent, OnClose = function() ModalManager.close() end })
	window.Holder.AnchorPoint = Vector2.new(0, 0)
	window.Holder.Position = UDim2.fromScale(0.04, 0.04) -- reference 12: top-left at (31, 13) of the 768 x 329 page
	for i, e in MainMenu.Entries do
		local b = Kit.button({ Name = e.Key, Style = "MenuRow", Text = "", Position = UDim2.fromOffset(9, 44.5 + (i - 1) * 37.6), Size = UDim2.fromOffset(W - 17, 34.5), Corner = 3, Parent = window.Panel })
		b.Instance:FindFirstChild("Content"):Destroy()
		Kit.icon(e.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = b.Instance })
		Kit.text({ Name = "Label", Text = e.Text, FontFace = Theme.Fonts.Name, TextSize = 16, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -72, 1, 0), TextWrapped = false, Parent = b.Instance })
		Kit.text({ Name = "Chevron", Text = ">", FontFace = Theme.Fonts.Heading, TextSize = 22, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(14, 34), Parent = b.Instance })
		b.onClick(function() MainMenu.go(e.Key) end)
		if i == 1 then window.FirstRow = b.Instance end
	end
	ModalManager.register("Menu", { window = window, firstSelect = function() return window.FirstRow end })
	return window
end

return MainMenu
