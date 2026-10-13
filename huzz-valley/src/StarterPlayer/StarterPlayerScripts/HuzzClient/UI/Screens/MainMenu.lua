-- Main menu (design/pages/12): a left-side list of every window. Screens that aren't built yet say so.
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local new = Kit.new

local MainMenu = {}

local W, H = 269, 255
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
	local window = Kit.window({ Name = "Menu", Title = "MENU", Icon = "MainMenuLines", Width = W, Height = H, HeaderHeight = 40, TitleX = 52, StudsTo = 214, Parent = parent, OnClose = function() ModalManager.close() end })
	window.Holder.AnchorPoint = Vector2.new(0, 0.5)
	window.Holder.Position = UDim2.new(0.07, 0, 0.5, 0) -- reference 12: panel starts 7% in from the left
	for i, e in MainMenu.Entries do
		local b = Kit.button({ Name = e.Key, Style = "Row", Text = "", Position = UDim2.fromOffset(11, 46 + (i - 1) * 34), Size = UDim2.fromOffset(W - 22, 30), Corner = 3, Parent = window.Panel })
		b.Instance:FindFirstChild("Content"):Destroy()
		Kit.icon(e.Icon, { Name = "Icon", Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(24, 24), Parent = b.Instance })
		Kit.text({ Name = "Label", Text = e.Text, FontFace = Theme.Fonts.Name, TextSize = 15, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -70, 1, 0), Parent = b.Instance })
		Kit.text({ Name = "Chevron", Text = ">", FontFace = Theme.Fonts.Button, TextSize = 18, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(16, 30), Parent = b.Instance })
		b.onClick(function() MainMenu.go(e.Key) end)
		if i == 1 then window.FirstRow = b.Instance end
	end
	ModalManager.register("Menu", { window = window, firstSelect = function() return window.FirstRow end })
	return window
end

return MainMenu
