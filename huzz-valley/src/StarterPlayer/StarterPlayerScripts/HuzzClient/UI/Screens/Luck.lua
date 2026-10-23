-- The LUCK window (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products ... make a button to clearly
-- show the luck boost, and make it clearly seen"). Our kit's window: the server's luck now, big and green, and yours;
-- one tile per Luck product (Config/Products.Luck, his nine x2 to x10: add rows there and they show here, three to a
-- line) with its Robux price (Roblox's live price once it loads); then the girl odds at this luck, every rarity, so a
-- kid always sees what luck changes before paying. Tiles at or under the server's luck say ACTIVE / grey out.
-- Opened by the LUCK button (Screens/LobbyHud). The server decides (ActionService "PromptLuck" ->
-- HuzzServer/LuckService): Id 0 = "coming soon", never a purchase; only a boost above the server's luck opens one.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Round = require(Shared.Config.Round)
local GirlRoll = require(Shared.GirlRoll)
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Toast = require(UI.Toast)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts
local GREEN = Color3.fromHex("3FD24A")
local MAX = (Round.Luck and Round.Luck.Max) or 10

local LuckScreen = {}

local W = 460
local COLS, TILE_H, GAP = 3, 78, 8
local ODDS_ROW = 22

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

-- "x2", "x2.5": the multiplier as people say it
function LuckScreen.word(k: number): string
	return "x" .. (if k == math.floor(k) then tostring(math.floor(k)) else string.format("%.1f", k))
end

-- Each rarity's chance in percent at this luck, Common first (every rarity in Config/Round has girls).
function LuckScreen.odds(luck: number): { { name: string, chance: number, color: Color3 } }
	local list = GirlRoll.withLuck(Round.Rarities, luck)
	local total = 0
	for _, r in list do total += r.Weight end
	local out = {}
	for _, r in list do table.insert(out, { name = r.Name, chance = r.Weight / total * 100, color = r.Color }) end
	return out
end

local function percent(p: number): string
	return if p >= 10 then string.format("%.0f%%", p) elseif p >= 1 then string.format("%.1f%%", p) else string.format("%.2f%%", p)
end

function LuckScreen.build(parent: Instance)
	local player = Players.LocalPlayer
	local items = Products.Luck
	local tileRows = math.ceil(#items / COLS)
	local rowsH = tileRows * TILE_H + (tileRows - 1) * GAP
	local oddsRows = math.ceil(#Round.Rarities / 2)
	local H = 47 + 104 + rowsH + 14 + 26 + oddsRows * ODDS_ROW + 18
	local window = Kit.window({ Name = "Luck", Title = "LUCK", Icon = "AuraStar", Width = W, Height = H, TitleX = 56, TitleWidth = 70, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local y = 47 + 10
	local big = line({ Name = "ServerLuck", Text = "SERVER LUCK x1", FontFace = F.Heading, TextSize = 30, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(W - 32, 36), ZIndex = 3, Parent = panel }, 2.5)
	local yours = line({ Name = "Yours", Text = "", FontFace = F.Name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y + 38), Size = UDim2.fromOffset(W - 32, 20), ZIndex = 3, Parent = panel })
	local about = line({ Name = "About", Text = "Rarer girls come up more for everyone in this server. Your boost lasts until you leave. The highest boost counts.", FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(24, y + 60), Size = UDim2.fromOffset(W - 48, 34), ZIndex = 3, Parent = panel }, 1)
	y += 104

	-- one tile per product, three to a line: the luck big and green, BUY with the Robux price under it
	local rows = {}
	local tileW = (W - 40 - (COLS - 1) * GAP) // COLS
	for i, p in items do
		local col, rowN = (i - 1) % COLS, (i - 1) // COLS
		local tile = new("Frame", { Name = "Row" .. p.Key, Position = UDim2.fromOffset(20 + col * (tileW + GAP), y + rowN * (TILE_H + GAP)), Size = UDim2.fromOffset(tileW, TILE_H), BackgroundColor3 = C.Row, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3, Parent = panel }, { Kit.corner(8) })
		line({ Name = "Name", Text = LuckScreen.word(p.Amount or 1) .. " LUCK", FontFace = F.Heading, TextSize = 22, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(tileW - 8, 28), ZIndex = 4, Parent = tile }, 2)
		local buy = Kit.button({ Name = "Buy", Text = "", Style = "Action", FontFace = F.Button, TextSize = 17, Corner = 7, RimThickness = 2, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.fromOffset(tileW - 16, 34), ZIndex = 5, Parent = tile })
		rows[p.Key] = { p = p, buy = buy }
	end
	y += rowsH + 14

	-- the girl odds at this luck
	local oddsTitle = line({ Name = "OddsTitle", Text = "GIRL ODDS NOW", FontFace = F.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(W - 32, 22), ZIndex = 3, Parent = panel }, 1.5)
	y += 26
	local cells = {}
	local colW = (W - 48) // 2
	for i, r in Round.Rarities do
		local col, rowN = (i - 1) // oddsRows, (i - 1) % oddsRows
		local name = line({ Name = r.Name, Text = r.Name, FontFace = F.Name, TextSize = 15, TextColor3 = if r.Name == "Secret" then Color3.fromRGB(235, 235, 245) else r.Color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24 + col * (colW + 8), y + rowN * ODDS_ROW), Size = UDim2.fromOffset(colW - 70, ODDS_ROW), ZIndex = 3, Parent = panel }, 1.2)
		local chance = line({ Name = r.Name .. "Chance", Text = "", FontFace = F.Number, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(24 + col * (colW + 8) + colW - 70, y + rowN * ODDS_ROW), Size = UDim2.fromOffset(70, ODDS_ROW), ZIndex = 3, Parent = panel }, 1.2)
		cells[r.Name] = { name = name, chance = chance }
	end

	local pending: { [string]: boolean } = {}
	local price: { [string]: number } = {} -- Roblox's live prices (the config's until they load)
	local shown = 1
	local function refresh()
		local server = tonumber(Workspace:GetAttribute("HuzzServerLuck")) or 1
		local mine = tonumber(player:GetAttribute("HuzzLuck")) or 1
		big.Text = "SERVER LUCK " .. LuckScreen.word(server)
		if server > shown then Motion.pop(big) end
		shown = server
		yours.Text = if mine > 1 then `Your boost: {LuckScreen.word(mine)}` else "You have no boost yet."
		for _, e in rows do
			local p = e.p
			local k = p.Amount or 1
			e.buy.setText(if pending[p.Key] then "..." elseif k == server then "ACTIVE" elseif k < server then "-" else `{Format.RobuxMark} {price[p.Key] or p.Price}`)
			e.buy.setStyle(if k == server then "Selected" elseif k < server then "Disabled" else "Action")
		end
		for _, o in LuckScreen.odds(server) do
			local c = cells[o.name]
			if c then c.chance.Text = percent(o.chance) end
		end
	end

	for _, e in rows do
		e.buy.onClick(function()
			local p = e.p
			if pending[p.Key] then return end
			local server = tonumber(Workspace:GetAttribute("HuzzServerLuck")) or 1
			if (p.Amount or 1) <= server then
				Toast.show(if server >= MAX then `Server luck is already at the top ({LuckScreen.word(MAX)}).` else `Server luck is already {LuckScreen.word(server)}. Pick a bigger boost.`)
				return
			end
			local status = Products.status(p)
			if status ~= "Ready" then
				Toast.show(`{p.Name} for Robux is coming soon.`)
				if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
				return
			end
			pending[p.Key] = true
			refresh()
			task.spawn(function()
				local ok, why = State.action("PromptLuck", p.Key) -- (the server checks again and opens Roblox's prompt)
				if not ok then
					pending[p.Key] = nil
					Toast.show(why or "The purchase couldn't open. Try again.")
				else
					task.delay(90, function() if pending[p.Key] then pending[p.Key] = nil; refresh() end end)
				end
				refresh()
			end)
		end)
	end
	pcall(function()
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId)
			if userId ~= player.UserId then return end
			for k in pending do pending[k] = nil end
			refresh()
		end)
	end)
	task.spawn(function() -- the live prices, once (guarded: none offline or in some Studio setups)
		local MarketplaceService = game:GetService("MarketplaceService")
		for _, p in items do
			if p.Id ~= 0 then
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.Id, Enum.InfoType.Product)
				if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then price[p.Key] = info.PriceInRobux end
			end
		end
		refresh()
	end)
	Workspace:GetAttributeChangedSignal("HuzzServerLuck"):Connect(refresh)
	player:GetAttributeChangedSignal("HuzzLuck"):Connect(refresh)

	ModalManager.register("Luck", {
		window = window,
		onOpen = refresh,
		firstSelect = function() local first = items[1] and rows[items[1].Key]; return first and first.buy.Instance end,
	})
	refresh()
	return window.Holder
end

return LuckScreen
