--!strict
-- New Game Kit: client (HUD behaviour)
-- Install: StarterPlayer/StarterPlayerScripts/KitClient (LocalScript)
--
-- Reuses PlayerGui.KitHUD (saved in StarterGui by tools/build_place.luau) and
-- only builds it if missing. The client sends intent and draws the server's
-- answers: prices, odds, balances and timers all come from the server or from
-- Roblox (GetProductInfoAsync). Each panel starts on its own (pcall), so one
-- broken panel can't stop the rest; errors go to Output on [KitClient] lines.
-- Status: logic not run in Studio yet; the HUD parts are built and saved offline.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))
local Format = require(Shared:WaitForChild("Format"))
local HudBuilder = require(Shared:WaitForChild("HudBuilder"))
local Config = require(ReplicatedStorage:WaitForChild("GameConfig")) :: any

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- StarterGui copies KitHUD in when the character first spawns: wait for it,
-- and only build a copy if it never arrives (for example, it was deleted).
local hud = playerGui:WaitForChild("KitHUD", 15) :: any
if not hud then
	warn("[KitClient] KitHUD missing from StarterGui; building it in code")
	hud = HudBuilder.Build()
	hud.Parent = playerGui
end
local panels = hud.Panels

local function attr(name: string): any
	return player:GetAttribute(name)
end

-- Toast and popup --------------------------------------------------------------
local toastToken = 0
local function toast(text: string)
	toastToken += 1
	local token = toastToken
	hud.Toast.Text = text
	hud.Toast.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			hud.Toast.Visible = false
		end
	end)
end
local function showResult(result: Net.Result, okText: string?)
	if result.ok then
		if okText then
			toast(okText)
		end
	else
		toast(Feedback.Text(result.code))
	end
end
local function popup(title: string, message: string)
	hud.Popup.Title.Label.Text = title
	hud.Popup.Body.Message.Text = message
	hud.Popup.Visible = true
end
hud.Popup.Body.Ok.Face.Activated:Connect(function()
	hud.Popup.Visible = false
end)
hud.Popup.Close.Face.Activated:Connect(function()
	hud.Popup.Visible = false
end)

-- Button motion (skill: hover 0.3 s Back Out, press shrink, small growth) ------
local HOVER = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local UNHOVER = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local wired: { [Instance]: boolean } = {}
local function wireButton(face: Instance)
	if wired[face] or not face:IsA("TextButton") then
		return
	end
	wired[face] = true
	local scale = Instance.new("UIScale")
	scale.Parent = face
	face.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1.06 }):Play()
	end)
	face.MouseLeave:Connect(function()
		TweenService:Create(scale, UNHOVER, { Scale = 1 }):Play()
	end)
	face.MouseButton1Down:Connect(function()
		TweenService:Create(scale, PRESS, { Scale = 0.92 }):Play()
	end)
	face.MouseButton1Up:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
end
for _, d in hud:GetDescendants() do
	if d.Name == "Face" then
		wireButton(d)
	end
end
hud.DescendantAdded:Connect(function(d: Instance)
	if d.Name == "Face" then
		wireButton(d)
	end
end)

-- Panels: one open at a time ----------------------------------------------------
local refreshers: { [string]: () -> () } = {}
local openName: string? = nil
local function closeAll()
	for _, p in panels:GetChildren() do
		p.Visible = false
	end
	openName = nil
end
local function open(name: string)
	if openName == name then
		closeAll()
		return
	end
	closeAll()
	panels[name].Visible = true
	openName = name
	local refresh = refreshers[name]
	if refresh then
		task.spawn(refresh)
	end
end
for _, p in panels:GetChildren() do
	p.Close.Face.Activated:Connect(closeAll)
end
for _, entry in HudBuilder.Menu do
	local name = entry[1]
	hud.Menu[name].Face.Activated:Connect(function()
		open(name)
	end)
end

-- Rows ---------------------------------------------------------------------------
local function clearRows(list: Instance)
	for _, child in list:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
end
local function addRow(list: any, order: number, title: string, sub: string, action: string?, onAction: (() -> ())?): any
	local row = list.RowTemplate:Clone()
	row.Name = "Row"
	row.LayoutOrder = order
	row.Title.Text = title
	row.Sub.Text = sub
	if action and onAction then
		row.Action.Face.Label.Text = action
		row.Action.Face.Activated:Connect(onAction)
	else
		row.Action.Visible = false
	end
	row.Visible = true
	row.Parent = list
	return row
end

local function safely(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(`[KitClient] {name} failed: {err}`)
	end
end

-- Robux prices come from Roblox (regional pricing), never from config.
local priceCache: { [string]: string } = {}
local function robuxPrice(id: number, infoType: Enum.InfoType): string
	local key = `{infoType.Name}:{id}`
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
	local text = if ok and info and info.PriceInRobux then `R$ {info.PriceInRobux}` else "R$ ?"
	priceCache[key] = text
	return text
end

-- Top bar -------------------------------------------------------------------------
safely("TopBar", function()
	local function bind(attrName: string, pill: any)
		local function update()
			pill.Amount.Text = Format.Short(attr(attrName) or 0)
		end
		player:GetAttributeChangedSignal(attrName):Connect(update)
		update()
	end
	bind("Coins", hud.TopBar.Coins)
	bind("Gems", hud.TopBar.Gems)
	bind("Rebirths", hud.TopBar.Rebirths)
end)

-- Tap -------------------------------------------------------------------------------
safely("Tap", function()
	if (Config.Income.tap or 0) <= 0 then
		hud.Tap.Visible = false
		return
	end
	hud.Tap.Face.Activated:Connect(function()
		Net.Send("Income.Tap")
	end)
end)

-- Shop: coin items, passes, products (id 0 = not set up yet, so not shown) --------
safely("Shop", function()
	local list = panels.Shop.Body.List
	refreshers.Shop = function()
		clearRows(list)
		local order = 0
		for key, item in Config.Shop.items do
			order += 1
			local itemDef = Config.Inventory.items[item.reward.item or ""]
			addRow(list, order, if itemDef then itemDef.name else key, `{Format.Short(item.price.amount)} {item.price.currency}`, "Buy", function()
				showResult(Net.Request("Shop.Buy", key, 1), "Bought!")
			end)
		end
		for key, pass in Config.Shop.passes do
			if pass.id > 0 then
				order += 1
				local owned = attr(`Pass_{key}`) == true
				addRow(list, order, pass.name or key, if owned then "Owned" else robuxPrice(pass.id, Enum.InfoType.GamePass), if owned then nil else "Buy", function()
					showResult(Net.Request("Shop.PromptPass", key))
				end)
			end
		end
		for key, product in Config.Receipts.products do
			-- Paid random products are hidden where the account can't buy them.
			local blocked = product.paidRandom and attr("PaidRandomAllowed") ~= true
			if product.id > 0 and not blocked then
				order += 1
				local sub = robuxPrice(product.id, Enum.InfoType.Product)
				if product.paidRandom then
					sub ..= "  - odds in the Eggs menu"
				end
				addRow(list, order, product.name or key, sub, "Buy", function()
					showResult(Net.Request("Shop.PromptProduct", key))
				end)
			end
		end
	end
end)

-- Eggs: every egg shows its odds before you hatch (kid-safe rule) ---------------
safely("Eggs", function()
	local list = panels.Eggs.Body.List
	refreshers.Eggs = function()
		clearRows(list)
		local order = 0
		for eggId, egg in Config.Eggs.eggs do
			local odds = Net.Request("Eggs.GetOdds", eggId)
			order += 1
			local price = `{Format.Short(egg.price.amount)} {egg.price.currency}`
			if odds.ok and odds.data.allowed == false then
				addRow(list, order, egg.name, odds.data.restrictedNote or "Not available", nil, nil)
			else
				addRow(list, order, egg.name, price, "Hatch", function()
					local result = Net.Request("Eggs.Hatch", eggId, 1)
					if result.ok then
						local names = {}
						for _, r in result.data do
							table.insert(names, `{r.item} ({r.tier})`)
						end
						popup("YOU GOT", table.concat(names, ", "))
					else
						showResult(result)
					end
				end)
			end
			if odds.ok then
				for _, row in odds.data.rows do
					order += 1
					local r = addRow(list, order, `   {row.id}`, `{row.tier}: {row.text}`, nil, nil)
					r.Size = UDim2.new(1, 0, 0, 44)
				end
				if odds.data.pity then
					order += 1
					addRow(list, order, "   Pity", odds.data.pity.rule, nil, nil)
				end
			end
		end
	end
	-- Live odds while a luck boost is active.
	Net.On("Eggs.OddsChanged", function()
		if openName == "Eggs" then
			refreshers.Eggs()
		end
	end)
end)

-- Pets: equip, see the boost and the index ---------------------------------------
safely("Pets", function()
	local list = panels.Pets.Body.List
	refreshers.Pets = function()
		clearRows(list)
		local snap = Net.Request("Inventory.Snapshot")
		if not snap.ok then
			showResult(snap)
			return
		end
		local total = 0
		for _ in Config.Pets.boosts do
			total += 1
		end
		addRow(list, 0, `Boost x{string.format("%.2f", attr("PetBoost") or 1)}`, `Index: {attr("Discovered") or 0}/{total} pets found`, nil, nil)
		for i, unique in snap.data.uniques do
			local boost = Config.Pets.boosts[unique.item] or 0
			local def = Config.Inventory.items[unique.item]
			addRow(list, i, if def then def.name else unique.item, `+{math.floor(boost * 100)}% coins`, if unique.equipped then "Unequip" else "Equip", function()
				local remote = if unique.equipped then "Inventory.Unequip" else "Inventory.Equip"
				showResult(Net.Request(remote, unique.uid))
				refreshers.Pets()
			end)
		end
	end
end)

-- Upgrades (cost shown = the server's formula; the server decides) --------------
safely("Upgrades", function()
	local list = panels.Upgrades.Body.List
	refreshers.Upgrades = function()
		clearRows(list)
		local order = 0
		for key, def in Config.Upgrades.upgrades do
			order += 1
			local level = attr(`Upgrade_{key}`) or 0
			local maxed = level >= def.maxLevel
			local cost = math.floor(def.baseCost * def.growth ^ level)
			addRow(list, order, `{def.name}  Lv {level}`, if maxed then "MAX" else `{Format.Short(cost)} {def.currency}`, if maxed then nil else "Buy", function()
				showResult(Net.Request("Upgrades.Buy", key))
				refreshers.Upgrades()
			end)
		end
	end
end)

-- Rebirth ---------------------------------------------------------------------------
safely("Rebirth", function()
	local body = panels.Rebirth.Body
	refreshers.Rebirth = function()
		local c = Config.Rebirth
		local n = attr("Rebirths") or 0
		local cost = math.floor(c.baseCost * c.growth ^ n)
		body.Info.Text = `Costs {Format.Short(cost)} {c.currency}.\nYour coins reset, your pets stay.\nBoost x{1 + n * c.bonusPerRebirth} -> x{1 + (n + 1) * c.bonusPerRebirth}`
	end
	body.Confirm.Face.Activated:Connect(function()
		showResult(Net.Request("Rebirth.Request", 1), "Rebirth!")
		refreshers.Rebirth()
	end)
end)

-- Gifts: daily reward + playtime gifts with REAL countdowns ------------------------
safely("Gifts", function()
	local list = panels.Gifts.Body.List
	refreshers.Gifts = function()
		clearRows(list)
		local daily = Net.Request("Daily.Status")
		if daily.ok then
			local d = daily.data
			addRow(list, 0, `Daily reward (day {d.nextStreak})`, if d.canClaim then d.reward else `Next in {Format.Clock(d.secondsUntilReset)}`, if d.canClaim then "Claim" else nil, function()
				showResult(Net.Request("Daily.Claim"), "Claimed!")
				refreshers.Gifts()
			end)
		end
		local start = attr("SessionStart") or 0
		local claimed = attr("GiftsClaimed") or 0
		for i, gift in Config.PlaytimeGifts.gifts do
			local done = (claimed // 2 ^ (i - 1)) % 2 == 1
			local left = start + gift.minutes * 60 - workspace:GetServerTimeNow()
			local row = addRow(list, i, `Gift {i}`, if done then "Claimed" elseif left > 0 then Format.Clock(left) else "Ready!", if done then nil else "Claim", function()
				showResult(Net.Request("PlaytimeGifts.Claim", i), "Claimed!")
				refreshers.Gifts()
			end)
			row:SetAttribute("GiftIndex", i)
		end
	end
	-- Tick the countdowns once a second while the panel is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if openName == "Gifts" then
				local start = attr("SessionStart") or 0
				for _, row in list:GetChildren() do
					local i = row:GetAttribute("GiftIndex")
					if i and row.Sub.Text ~= "Claimed" then
						local left = start + Config.PlaytimeGifts.gifts[i].minutes * 60 - workspace:GetServerTimeNow()
						row.Sub.Text = if left > 0 then Format.Clock(left) else "Ready!"
					end
				end
			end
		end
	end)
end)

-- Codes -------------------------------------------------------------------------------
safely("Codes", function()
	local body = panels.Codes.Body
	body.Redeem.Face.Activated:Connect(function()
		local text = body.Input.Text
		if #text > 0 then
			showResult(Net.Request("Codes.Redeem", text), "Code redeemed!")
		end
	end)
end)

-- Settings ------------------------------------------------------------------------------
safely("Settings", function()
	local list = panels.Settings.Body.List
	refreshers.Settings = function()
		clearRows(list)
		local order = 0
		for key in Config.Settings.defaults do
			order += 1
			local on = attr(`Setting_{key}`) == true
			addRow(list, order, key, if on then "On" else "Off", if on then "Turn off" else "Turn on", function()
				showResult(Net.Request("Settings.Set", key, not on))
				refreshers.Settings()
			end)
		end
	end
end)

-- Offline earnings popup ------------------------------------------------------------
safely("Offline", function()
	Net.On("Income.Offline", function(amount: number, seconds: number)
		popup("WELCOME BACK!", `You earned {Format.Short(amount)} coins while you were away ({Format.Clock(seconds)}).`)
	end)
end)
