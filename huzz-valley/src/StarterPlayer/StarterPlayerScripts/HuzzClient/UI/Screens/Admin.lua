-- The owner's admin panel (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any
-- girl to spawn when i want it to do so"). A small ADMIN button in the bottom-left corner, shown only when the server
-- marked you as the game's owner (Player attribute HuzzAdmin: HuzzServer/AdminService, Studio or the place's
-- creator), opens a window with two lists:
--   KNIVES: every knife (Config/CoinShop); GIVE puts it in your knives and you wear it.
--   GIRLS:  every girl in this place (ReplicatedStorage.HuzzGirls); SPAWN makes her yours and your companion (she
--           appears behind you at once), NEXT GAME makes her the next game's girl (the roller stops on her).
-- The buttons only ask the server ("Admin" remote); it checks again who you are, and its answer shows as a message.
-- The window and the button are saved parts like every screen; the rows are made the first time it opens (the girls
-- are whatever the place has).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local RoundConfig = require(Shared.Config.Round)
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local new = Kit.new

local Admin = {}

local W, H = 701, 320
local COL = { { X = 16, Title = "KNIVES" }, { X = 357, Title = "GIRLS" } }
local LIST_Y, LIST_W, LIST_H, ROW_H = 84, 328, 226, 34

local rarityColor: { [string]: Color3 } = {}
local rarityOrder: { [string]: number } = {}
for i, r in RoundConfig.Rarities do rarityColor[r.Name], rarityOrder[r.Name] = r.Color, i end
rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (as in the Shop: near-black reads badly on the dark window)
rarityColor.Exclusive = Color3.fromRGB(255, 170, 230)
rarityOrder.Exclusive = #RoundConfig.Rarities + 1

local function row(list: Instance, i: number, key: string, name: string, rarity: string, buttons: { { Text: string, Width: number, Verb: string } }, send: (string, string) -> ())
	local r = new("Frame", { Name = key, Position = UDim2.fromOffset(0, (i - 1) * (ROW_H + 4)), Size = UDim2.new(1, -10, 0, ROW_H), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, Parent = list }, { Kit.corner(4), Kit.stroke(C.RowBorder, 1) })
	local right = 0
	for j = #buttons, 1, -1 do
		local b = buttons[j]
		right += b.Width + 4
		local btn = Kit.button({ Name = b.Verb, Text = b.Text, TextSize = 12, Style = if b.Verb == "NextGirl" then "Slate" else "Action", Position = UDim2.new(1, -right, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(b.Width, ROW_H - 8), Corner = 3, Parent = r })
		btn.onClick(function() send(b.Verb, key) end)
	end
	local label = Kit.text({ Name = "Label", Text = name, FontFace = Theme.Fonts.Name, TextSize = 14, TextWrapped = false, Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -(right + 12), 0, 17), Parent = r })
	Kit.fitLine(label, LIST_W - 10 - right - 14, 14, 10, true)
	Kit.text({ Name = "Rarity", Text = string.upper(rarity), FontFace = Theme.Fonts.Button, TextSize = 10, TextColor3 = rarityColor[rarity] or C.Text, TextWrapped = false, Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -(right + 12), 0, 12), Parent = r })
end

function Admin.build(parent: Instance)
	local window = Kit.window({ Name = "Admin", Title = "ADMIN", Icon = "SettingsGear", Width = W, Height = H, TitleX = 63, TitleWidth = 112, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local lists = {}
	for i, col in COL do
		Kit.text({ Name = col.Title .. "Title", Text = col.Title, FontFace = Theme.Fonts.Heading, TextSize = 18, TextWrapped = false, Position = UDim2.fromOffset(col.X + 2, 55), Size = UDim2.fromOffset(LIST_W, 24), Parent = panel })
		local list = new("ScrollingFrame", { Name = col.Title .. "List", Position = UDim2.fromOffset(col.X, LIST_Y), Size = UDim2.fromOffset(LIST_W, LIST_H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
		Kit.attach(Kit.pad(2, 2, 2, 2), list) -- (the rows' rims are outside them; a ScrollingFrame clips square)
		lists[i] = list
	end

	-- the corner button, only for the owner (the server sets HuzzAdmin; it checks every request again anyway)
	local toggle = Kit.button({ Name = "AdminToggle", Style = "Slate", Text = "ADMIN", TextSize = 14, Position = UDim2.new(0, 12, 1, -12), AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(84, 30), Parent = parent })
	local player = Players.LocalPlayer
	local function showToggle()
		toggle.Instance.Visible = player ~= nil and player:GetAttribute("HuzzAdmin") == true
	end
	showToggle()
	if player then player:GetAttributeChangedSignal("HuzzAdmin"):Connect(showToggle) end
	toggle.onClick(function()
		if player and player:GetAttribute("HuzzAdmin") == true then ModalManager.open("Admin") end
	end)

	local remote = Net.get("Admin") :: RemoteEvent
	local function send(verb: string, key: string) remote:FireServer(verb, key) end
	remote.OnClientEvent:Connect(function(ok, message)
		Toast.show(tostring(message or (if ok then "Done." else "That didn't work.")))
	end)

	local filled = false
	local function fill()
		if filled then return end
		filled = true
		local knives = {}
		for _, item in CoinShop.Items do
			if item.Slot == "Knife" then table.insert(knives, item) end
		end
		table.sort(knives, function(a, b) return (a.Order or 0) < (b.Order or 0) end)
		for i, item in knives do
			row(lists[1], i, item.Key, item.Name, item.Rarity or "Common", { { Text = "GIVE", Width = 64, Verb = "GiveKnife" } }, send)
		end
		local girls = {}
		local folder = ReplicatedStorage:FindFirstChild("HuzzGirls")
		for _, m in (folder and folder:GetChildren() or {}) do
			local id = m:GetAttribute("Id")
			if type(id) == "string" then
				table.insert(girls, { id = id, name = tostring(m:GetAttribute("Name") or id), rarity = tostring(m:GetAttribute("Rarity") or "Common") })
			end
		end
		table.sort(girls, function(a, b)
			local ra, rb = rarityOrder[a.rarity] or 0, rarityOrder[b.rarity] or 0
			if ra ~= rb then return ra > rb end
			return a.name < b.name
		end)
		for i, g in girls do
			row(lists[2], i, g.id, g.name, g.rarity, { { Text = "SPAWN", Width = 64, Verb = "SpawnGirl" }, { Text = "NEXT GAME", Width = 86, Verb = "NextGirl" } }, send)
		end
		if #girls == 0 then
			Kit.text({ Name = "None", Text = "No girls in this place yet.", TextSize = 14, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20), Parent = lists[2] })
		end
	end

	ModalManager.register("Admin", {
		window = window,
		onOpen = function()
			if player and player:GetAttribute("HuzzAdmin") ~= true then ModalManager.close(); return end
			fill()
		end,
	})
	return window
end

return Admin
