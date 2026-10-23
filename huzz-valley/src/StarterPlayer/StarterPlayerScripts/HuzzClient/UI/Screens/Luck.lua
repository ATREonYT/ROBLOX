-- The LUCK window (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products ... make a button to clearly
-- show the luck boost, and make it clearly seen"). Our kit's window: the server's luck now, big and green, and yours;
-- the luck ladder (owner, Oct 23 17:32: "make it so that you have to buy x2 luck then x3 luck, etc. so they can't just
-- buy x10 luck ... make a bigger button to buy the luck"): a row of steps, x2 to x10 (Config/Products.Luck: add rows
-- there and they show here), lit up to YOUR boost, and ONE big BUY button for your next step only, with its
-- Robux price (Roblox's live price once it loads), so each buy costs more than the last. Then the girl odds at this
-- luck, every rarity, so a kid always sees what luck changes before paying. Everyone's boosts add up into the
-- server's luck (17:53: x5 and x3 make x8; when the x5 buyer leaves it's x3), up to the top.
-- Opened by the LUCK button and the SERVER LUCK sign (Screens/LobbyHud). The server decides (ActionService
-- "PromptLuck" -> HuzzServer/LuckService): Id 0 = "coming soon", never a purchase; only the next step opens one.
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
local Effects = require(UI.Effects)
local ShopStyle = require(UI.ShopStyle)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts
local GREEN = Color3.fromHex("3FD24A")
local MAX = (Round.Luck and Round.Luck.Max) or 10

local LuckScreen = {}

local W = 460
local STEP_ROW, BUY_ROW = 36, 92 -- (the ladder row; the big BUY button and the line under it)
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
	local items = table.clone(Products.Luck)
	table.sort(items, function(a, b) return (a.Amount or 1) < (b.Amount or 1) end)
	local oddsRows = math.ceil(#Round.Rarities / 2)
	local H = 47 + 104 + STEP_ROW + BUY_ROW + 26 + oddsRows * ODDS_ROW + 18
	local window = Kit.window({ Name = "Luck", Title = "LUCK", Icon = "AuraStar", Width = W, Height = H, TitleX = 56, TitleWidth = 70, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local y = 47 + 10
	local big = line({ Name = "ServerLuck", Text = "SERVER LUCK x1", FontFace = F.Heading, TextSize = 30, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(W - 32, 36), ZIndex = 3, Parent = panel }, 2.5)
	local yours = line({ Name = "Yours", Text = "", FontFace = F.Name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y + 38), Size = UDim2.fromOffset(W - 32, 20), ZIndex = 3, Parent = panel })
	line({ Name = "About", Text = "Rarer girls come up more for everyone here. Everyone's boosts add up, to x" .. MAX .. ". Yours goes up one step at a time and lasts until you leave.", FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(24, y + 60), Size = UDim2.fromOffset(W - 48, 34), ZIndex = 3, Parent = panel }, 1)
	y += 104

	-- the ladder: one step per product, lit up to the server's luck; the next one has a gold rim
	local stepW, stepGap = 40, 6
	local rowW = #items * stepW + (#items - 1) * stepGap
	local steps = {}
	for i, p in items do
		local step = new("Frame", { Name = "Step" .. p.Key, Position = UDim2.fromOffset((W - rowW) // 2 + (i - 1) * (stepW + stepGap), y), Size = UDim2.fromOffset(stepW, 26), BackgroundColor3 = C.Row, BorderSizePixel = 0, ZIndex = 3, Parent = panel }, { Kit.corner(6) })
		local rim = Kit.attach(Kit.stroke(C.TitleStroke, 2), step) :: UIStroke
		local word = line({ Name = "Word", Text = LuckScreen.word(p.Amount or 1), FontFace = F.Number, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = step }, 1.2)
		steps[i] = { p = p, frame = step, rim = rim, word = word }
	end
	y += STEP_ROW

	-- the one big BUY button: the next step and its price
	local buy = Kit.button({ Name = "Buy", Text = "", Style = "Action", FontFace = F.Button, TextSize = 26, Corner = 10, RimThickness = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W // 2, y), Size = UDim2.fromOffset(340, 64), ZIndex = 5, Parent = panel })
	-- his clover (Oct 23 17:53: "make this used for the button to buy the luck") on the button's left end, with the
	-- step it buys written on it
	local clover = Kit.art("LuckClover", { Name = "Clover", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 32), Size = UDim2.fromOffset(78, 78), ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = buy.Instance })
	local cloverText = ShopStyle.chunky({ Name = "Step", Text = "", TextSize = 24, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 1, 0.5, -3), Size = UDim2.new(1, 0, 0, 30), Rotation = -8, ZIndex = 8, Parent = clover }, 3)
	Effects.rock(clover, { degrees = 5, seconds = 1.4 })
	local after = line({ Name = "After", Text = "", FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y + 66), Size = UDim2.fromOffset(W - 32, 18), ZIndex = 3, Parent = panel }, 1)
	y += BUY_ROW

	-- the girl odds at this luck
	line({ Name = "OddsTitle", Text = "GIRL ODDS NOW", FontFace = F.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(W - 32, 22), ZIndex = 3, Parent = panel }, 1.5)
	y += 26
	local cells = {}
	local colW = (W - 48) // 2
	for i, r in Round.Rarities do
		local col, rowN = (i - 1) // oddsRows, (i - 1) % oddsRows
		local name = line({ Name = r.Name, Text = r.Name, FontFace = F.Name, TextSize = 15, TextColor3 = if r.Name == "Secret" then Color3.fromRGB(235, 235, 245) else r.Color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24 + col * (colW + 8), y + rowN * ODDS_ROW), Size = UDim2.fromOffset(colW - 70, ODDS_ROW), ZIndex = 3, Parent = panel }, 1.2)
		local chance = line({ Name = r.Name .. "Chance", Text = "", FontFace = F.Number, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(24 + col * (colW + 8) + colW - 70, y + rowN * ODDS_ROW), Size = UDim2.fromOffset(70, ODDS_ROW), ZIndex = 3, Parent = panel }, 1.2)
		cells[r.Name] = { name = name, chance = chance }
	end

	local pending = false
	local price: { [string]: number } = {} -- Roblox's live prices (the config's until they load)
	local function priceOf(p) return price[p.Key] or p.Price end
	local shown = 1
	local function refresh()
		local server = tonumber(Workspace:GetAttribute("HuzzServerLuck")) or 1
		local mine = tonumber(player:GetAttribute("HuzzLuck")) or 1
		big.Text = "SERVER LUCK " .. LuckScreen.word(server)
		if server > shown then Motion.pop(big) end
		shown = server
		yours.Text = if mine > 1 then `Your boost: {LuckScreen.word(mine)}` else "You have no boost yet."
		local nextOne = Products.nextLuck(mine)
		local full = server >= MAX
		for _, st in steps do
			local k = st.p.Amount or 1
			local lit, isNext = k <= mine, nextOne ~= nil and not full and st.p.Key == nextOne.Key
			st.frame.BackgroundColor3 = if lit then GREEN else C.Row
			st.frame.BackgroundTransparency = if lit or isNext then 0 else 0.35
			st.rim.Color = if isNext then Color3.fromHex("FFD23F") else C.TitleStroke
			st.rim.Thickness = if isNext then 3 else 2
			st.word.TextTransparency = if lit or isNext then 0 else 0.45
		end
		cloverText.Text = if full or not nextOne then `{math.floor(server)}x` else `{nextOne.Amount or 1}x`
		if full or not nextOne then
			buy.setText(`MAX LUCK {LuckScreen.word(server)}`)
			buy.setStyle("Selected")
			after.Text = if full then "The server's luck is at the top." else "Your boost is at the top."
		else
			buy.setText(if pending then "..." else `BUY {LuckScreen.word(nextOne.Amount or 1)} LUCK   {Format.RobuxMark} {priceOf(nextOne)}`)
			buy.setStyle("Action")
			local later = Products.nextLuck(nextOne.Amount)
			local gives = (nextOne.Amount or 1) - (if mine > 1 then mine else 0) -- (how much it adds to the server)
			after.Text = if server + gives > MAX then `The server stops at {LuckScreen.word(MAX)}.`
				elseif later then `Server goes to {LuckScreen.word(server + gives)}. Then {LuckScreen.word(later.Amount or 1)} for {Format.RobuxMark} {priceOf(later)}`
				else `Server goes to {LuckScreen.word(server + gives)}. This is the last step.`
		end
		for _, o in LuckScreen.odds(server) do
			local c = cells[o.name]
			if c then c.chance.Text = percent(o.chance) end
		end
	end

	buy.onClick(function()
		if pending then return end
		local server = tonumber(Workspace:GetAttribute("HuzzServerLuck")) or 1
		local p = Products.nextLuck(tonumber(player:GetAttribute("HuzzLuck")) or 1)
		if server >= MAX or not p then
			Toast.show(`Server luck is already at the top ({LuckScreen.word(MAX)}).`)
			return
		end
		local status = Products.status(p)
		if status ~= "Ready" then
			Toast.show(`{p.Name} for Robux is coming soon.`)
			if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
			return
		end
		pending = true
		refresh()
		task.spawn(function()
			local ok, why = State.action("PromptLuck", p.Key) -- (the server checks again and opens Roblox's prompt)
			if not ok then
				pending = false
				Toast.show(why or "The purchase couldn't open. Try again.")
			else
				task.delay(90, function() if pending then pending = false; refresh() end end)
			end
			refresh()
		end)
	end)
	pcall(function()
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId)
			if userId ~= player.UserId then return end
			pending = false
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
		firstSelect = function() return buy.Instance end,
	})
	refresh()
	return window.Holder
end

return LuckScreen
