-- Checks the Shop's sections and filters and the Inventory (owner, Oct 21: "make this logical, and not everything mixed
-- together ... make the dances button the inventory button, which then will show you everything you currently own
-- ... And will allow you to equip it") through the real server + client code:
--   * the Shop only sells: no knives and no earned looks in it; STYLE has type chips (only the kinds sold) and OWNED /
--     NOT OWNED, inside the page; an owned look's OWNED opens the Inventory at its tab;
--   * the Inventory: the lobby's INVENTORY button where DANCES was; KNIVES shows the knives you own (best first) with
--     rarity chips; EQUIP wears it on the server, EQUIPPED takes it off; TITLES shows yours then the ones still to get,
--     locked with how; every title fits its card; GIRLS equips your companion; DANCES plays yours; ABILITIES holds both
--     sides' cards; whole pixels;
--   * DANCES in the Shop (cards, panel, BUY on the server) and ABILITIES (UI/AbilityCards) with its jump between STYLE
--     and PASSES; without that module the section and its jump hide and PASSES moves up.
-- From tools/preview: lune run harness.luau ../../src - @check_filters.luau setup_ui.luau
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local CoinShop = require(game.ReplicatedStorage.Shared.Config.CoinShop)
-- own the Dojo crate's ten knives (Common to Legendary) before the client starts
local Crates = require(game.ReplicatedStorage.Shared.Config.Crates)
local epic, common
local mine = {}
for _, it in Crates.get("Dojo").Items do
	local c = CoinShop.get(it.Id)
	mine[it.Id] = true
	if c.Rarity == "Epic" and not epic then epic = c end
	if c.Rarity == "Common" and not common then common = c end
end
DataService.update(player, function(d) for k in mine do d.Cosmetics[k] = true end end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local gui = player.PlayerGui.HuzzUI
local function settle() for _ = 1, 40 do __stepTweens(0.05) end task.wait(0.3) end
local function click(btn) __fireOn(btn, "Activated"); task.wait(0.2) end
local function wholePixels(root: Instance): boolean
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			for _, v in { d.Position.X.Offset, d.Position.Y.Offset, d.Size.X.Offset, d.Size.Y.Offset } do
				if v ~= math.floor(v) then print("  half pixel: " .. d:GetFullName()); return false end
			end
		end
	end
	return true
end

-- THE SHOP SELLS ONLY ----------------------------------------------------------------------------------------------
MM.open("Shop", "Style")
settle()
local panel = gui.Shop.Group.Panel
local body = panel.Products
local any = false
for _, it in CoinShop.Items do
	if (it.Slot == "Knife" or it.Unlock) and body:FindFirstChild(it.Key) then any = true; print("  in the Shop: " .. it.Key) end
end
check("no knives and no earned looks in the Shop", not any and body:FindFirstChild("KnivesFilters") == nil and panel:FindFirstChild("KnivesTab") == nil)
local srow = body:FindFirstChild("StyleFilters")
check("STYLE has its filter row under its header", srow ~= nil and srow.Position.Y.Offset == body.HeadStyle.Position.Y.Offset + body.HeadStyle.Size.Y.Offset)
local names = {}
for _, k in { "All", "Trail", "Title", "Tag", "Aura" } do
	local b = srow and srow:FindFirstChild("StyleType" .. k)
	if b then table.insert(names, b.Content.Label.Text) end
end
check(`type chips, only the kinds sold: {table.concat(names, ", ")}`, table.concat(names, ",") == "ALL,TRAILS,NAME COLOURS")
local sinside = true
for _, ch in (srow and srow:GetChildren() or {}) do
	if ch:IsA("GuiObject") then
		local left = ch.Position.X.Offset - ch.AnchorPoint.X * ch.Size.X.Offset
		if left < 0 or left + ch.Size.X.Offset > 795 then sinside = false; print("  outside: " .. ch.Name) end
	end
end
check("the chips fit the page, no OWNED / NOT OWNED (owning is the Inventory's)", sinside and srow ~= nil and srow:FindFirstChild("StyleOwnOwned") == nil and wholePixels(srow))
check("each kind under its own header (TRAILS, NAME COLOURS)", body:FindFirstChild("HeadStyleTrail") ~= nil and body:FindFirstChild("HeadStyleTag") ~= nil
	and body.HeadStyleTrail.Position.Y.Offset < body.HeadStyleTag.Position.Y.Offset)
click(srow.StyleTypeTag)
local onlyTags, nTags = true, 0
for _, it in CoinShop.Items do
	local c = body:FindFirstChild(it.Key)
	if c and c.Visible then if it.Slot == "Tag" then nTags += 1 else onlyTags = false end end
end
check(`NAME COLOURS shows only name colours ({nTags})`, onlyTags and nTags >= 2)
click(srow.StyleTypeAll)

-- THE INVENTORY ----------------------------------------------------------------------------------------------------
local left = gui.LobbyHud.Left
check("the lobby's INVENTORY button stands where DANCES was (between SHOP and MENU)", left:FindFirstChild("Inventory") ~= nil and left:FindFirstChild("Dances") == nil
	and left.Inventory.Position.Y.Offset > left.Shop.Position.Y.Offset and left.Inventory.Position.Y.Offset < left.Menu.Position.Y.Offset)
MM.close()
task.wait(0.3)
click(gui.LobbyHud.Left.Inventory)
settle()
local inv = gui:FindFirstChild("Inventory")
check("tapping it opens the Inventory", inv ~= nil and MM.current() == "Inventory" and inv.Visible)
local ip = inv.Group.Panel
local page = ip.Page
local tabNames = {}
for _, t in { "Girls", "Knives", "Trails", "Names", "Titles", "Auras", "Dances", "Abilities" } do
	local b = ip:FindFirstChild(t .. "Tab")
	if b and b.Position.Y.Offset + b.Size.Y.Offset <= 550 then table.insert(tabNames, b.Content.Label.Text) end
end
check(`its tabs, inside the window: {table.concat(tabNames, ", ")}`, #tabNames == 8)
click(ip.KnivesTab)
settle()
local content = page:FindFirstChild("Content")
local knives = {}
for _, c in (content and content:GetChildren() or {}) do
	local it = CoinShop.get(c.Name)
	if it and it.Slot == "Knife" and not c:FindFirstChild("Lock") then table.insert(knives, { card = c, item = it }) end
end
local nMine = 0
for key, v in DataService.get(player).Data.Cosmetics do
	local it = v == true and CoinShop.get(key)
	if it and it.Slot == "Knife" then nMine += 1 end
end
check(`KNIVES shows the knives you own, and only those ({#knives} of {nMine})`, #knives == nMine)
local inUse = 0
for _, k in knives do if k.card.Use:FindFirstChild("Label", true).Text == "EQUIPPED" then inUse += 1 end end
check(`... the knife the round gives you says EQUIPPED (never picked: {inUse})`, inUse == 1)
table.sort(knives, function(a, b)
	if math.abs(a.card.Position.Y.Offset - b.card.Position.Y.Offset) > 2 then return a.card.Position.Y.Offset < b.card.Position.Y.Offset end
	return a.card.Position.X.Offset < b.card.Position.X.Offset
end)
local RANK = { Exclusive = 1, Secret = 2, Mythic = 3, Legendary = 4, Epic = 5, Rare = 6, Uncommon = 7, Common = 8 }
local bestFirst = true
for i = 2, #knives do
	if (RANK[knives[i].item.Rarity] or 9) < (RANK[knives[i - 1].item.Rarity] or 9) then bestFirst = false end
end
check("... best first", bestFirst)
local chips = content and content:FindFirstChild("Chips")
check("... with rarity chips, ALL first", chips ~= nil and chips:FindFirstChild("ChipAll") ~= nil and chips:FindFirstChild("ChipEpic") ~= nil)
click(chips.ChipEpic)
settle()
content = page:FindFirstChild("Content")
local onlyEpic, nEpic = true, 0
for _, c in content:GetChildren() do
	local it = CoinShop.get(c.Name)
	if it and it.Slot == "Knife" and not c:FindFirstChild("Lock") then if it.Rarity == "Epic" then nEpic += 1 else onlyEpic = false end end
end
check(`EPIC shows only Epic knives ({nEpic})`, onlyEpic and nEpic >= 1)
local ec = content:FindFirstChild(epic.Key)
click(ec.Use)
task.wait(0.3)
local data = DataService.get(player).Data
check(`EQUIP wears it, on the server ({tostring(data.Wear.Knife)})`, data.Wear.Knife == epic.Key)
settle()
ec = page.Content:FindFirstChild(epic.Key)
check("... its button says EQUIPPED", ec ~= nil and ec.Use:FindFirstChild("Label", true).Text == "EQUIPPED")
click(ec.Use)
task.wait(0.3)
check("EQUIPPED again takes it off", data.Wear.Knife == "")
click(page.Content.Chips.ChipAll)
check("whole pixels in the Inventory", wholePixels(inv))

-- TITLES: yours, then the ones still to get (locked, how); every title inside its card
DataService.update(player, function(d) d.Cosmetics.TitleHero = true end)
task.wait(0.3)
click(ip.TitlesTab)
settle()
content = page.Content
local yours, lockedOk, fit = content:FindFirstChild("TitleHero"), true, true
for _, it in CoinShop.Items do
	if it.Slot == "Title" and it.Key ~= "TitleHero" then
		local c = content:FindFirstChild(it.Key)
		if not c or not c:FindFirstChild("Lock") or c.Use:FindFirstChild("Label", true).Text ~= "EARN IT" then lockedOk = false end
		if c and c.Line.Text ~= string.upper(it.Unlock) then lockedOk = false end
	end
	local c = content:FindFirstChild(it.Key)
	local w = c and c:FindFirstChild("Drawn") and c.Drawn:FindFirstChild("Word")
	if it.Slot == "Title" and w then
		local font = w.FontFace
		for _, word in string.split(w.Text, " ") do
			if require(UI.Kit).textWidth(word, font, w.TextSize) > c.Size.X.Offset - 16 then fit = false; print("  too wide: " .. w.Text) end
		end
		if w.Size.Y.Offset > 96 then fit = false; print("  too tall: " .. w.Text) end
	end
end
check("TITLES: the one you own says WEAR", yours ~= nil and not yours:FindFirstChild("Lock") and yours.Use:FindFirstChild("Label", true).Text ~= "EARN IT")
check("... the rest locked, with how to get them", lockedOk)
check("... every title fits its card (GIRL COLLECTOR, MYTHIC CHARMER, ...)", fit)

-- GIRLS: equip your companion; DANCES: play yours; ABILITIES: both sides
local Characters = require(game.ReplicatedStorage.Shared.Config.Characters)
-- (one of the girls you win in rounds, as HuzzServer/GirlService publishes her: a model with Id, Name and Rarity)
local girls = game.ReplicatedStorage:FindFirstChild("HuzzGirls") or Instance.new("Folder")
girls.Name = "HuzzGirls"; girls.Parent = game.ReplicatedStorage
local gm = Instance.new("Model"); gm.Name = "TestGirl"; gm:SetAttribute("Id", "TestGirl"); gm:SetAttribute("Name", "Test Girl"); gm:SetAttribute("Rarity", "Epic"); gm.Parent = girls
Characters.addGirls(girls)
local girl = Characters.get("TestGirl")
DataService.update(player, function(d) d.Characters[girl.Id] = d.Characters[girl.Id] or { At = 1 } end)
task.wait(0.3)
click(ip.GirlsTab)
settle()
local gc = page.Content:FindFirstChild("Girl" .. girl.Id)
check("GIRLS shows the girls you own", gc ~= nil)
if gc then
	click(gc.Use)
	task.wait(0.3)
	check(`EQUIP makes her your companion ({tostring(data.Equipped)})`, data.Equipped == girl.Id)
end
click(ip.DancesTab)
settle()
local anyDance = nil
for _, c in page.Content:GetChildren() do if string.sub(c.Name, 1, 5) == "Dance" then anyDance = c; break end end
check("DANCES shows the dances you own, with PLAY", anyDance ~= nil and anyDance.Use:FindFirstChild("Label", true).Text == "PLAY")
click(ip.AbilitiesTab)
settle()
local abs = page.Content:FindFirstChild("AbilitiesSlot")
check("ABILITIES holds both sides' cards", abs ~= nil and abs:FindFirstChild("RunnerAbilities") ~= nil and abs:FindFirstChild("CatcherAbilities") ~= nil)
local sells = false
for _, d in (abs and abs:GetDescendants() or {}) do if d.Name == "Buy" and d:IsA("GuiObject") and d.Visible then sells = true end end
check("... only the ones you own: no BUY buttons in the Inventory", abs ~= nil and not sells and abs.RunnerAbilities:FindFirstChild("Shield") ~= nil)
MM.close()
task.wait(0.3)
check("the Inventory's cards are never saved (RuntimeOnly)", page:FindFirstChild("Content") == nil)
-- an owned look in the Shop opens the Inventory at its tab
DataService.update(player, function(d) d.Cosmetics.TagPink = true end)
task.wait(0.3)
MM.open("Shop", "Style")
settle()
click(body.TagPink.Buy)
settle()
check("an owned look's OWNED opens the Inventory at NAMES", MM.current() == "Inventory" and ip.NamesTab:FindFirstChild("Rim") ~= nil and ip.NamesTab.Rim.Color == Color3.new(1, 1, 1))
MM.close()
task.wait(0.3)
MM.open("Shop", "Dances")
settle()

-- the jump buttons: HALLOWEEN first, then CRATES, DANCES, STYLE ... all inside the window's height
local order = { "Halloween", "Crates", "Dances", "Style", "Abilities", "Passes", "Aura", "Coins" }
local inOrder, fits = true, true
for i, k in order do
	local b = panel:FindFirstChild(k .. "Tab")
	if not b or b.Position.Y.Offset ~= panel.HalloweenTab.Position.Y.Offset + (i - 1) * 49 then inOrder = false end
	if b and b.Position.Y.Offset + b.Size.Y.Offset / 2 > 550 then fits = false end
end
check("jump buttons: HALLOWEEN, CRATES, DANCES, STYLE, ABILITIES, PASSES, AURA, COINS", inOrder)
check("... all inside the window's height", fits)

-- DANCES (owner, Oct 20 20:34: "make a seperate section for dances ... make them be able to be bought there"): the
-- Dance Pack, then every dance with a coin price; a tap slides its panel in with a preview and BUY; BUY is checked on
-- the server (coins taken once, never twice)
local Dances = require(game.ReplicatedStorage.Shared.Config.Dances)
local sold, cardsOk = 0, true
for _, d in Dances.List do
	if d.Coins then
		sold += 1
		local c = body:FindFirstChild("Dance" .. d.Id)
		if not c or c.Position.Y.Offset < body.HeadDances.Position.Y.Offset or c.Position.Y.Offset > body.HeadStyle.Position.Y.Offset then cardsOk = false end
	elseif not d.Starter and not d.Pack then
		print("  not sold anywhere: " .. d.Id)
		cardsOk = false
	end
end
check(`DANCES: every dance that isn't free has its card there ({sold})`, cardsOk and sold >= 8) -- (the 4 Dance Pack ones are Robux only since Oct 21)
check("... the Dance Pack on top of it", body:FindFirstChild("DancePack") ~= nil and body.DancePack.Position.Y.Offset == body.HeadDances.Position.Y.Offset + body.HeadDances.Size.Y.Offset)
local zombie = Dances.get("ZombieGroove")
local zc = body.DanceZombieGroove
DataService.update(player, function(d) d.Coins = zombie.Coins + 100 end)
task.wait(0.2)
check(`a dance card shows its coin price ({zc.Buy:FindFirstChild("Label", true).Text})`, zc.Buy:FindFirstChild("Label", true).Text == "2,000")
click(zc.Tap)
settle()
local side = panel.Side
check("tapping a dance slides its panel in: its name, a preview, BUY", side.Visible and side.Panel.DanceView.Visible and side.Panel.Title.Text == "ZOMBIE GROOVE"
	and side.Panel.DanceView.Backdrop.Still:GetAttribute("Art") == "DanceStillZombieGroove" and side.Panel.DanceView.Buy:FindFirstChild("Label", true).Text == "BUY 2,000")
click(side.Panel.DanceView.Buy)
local data = DataService.get(player).Data
check(`BUY: the dance is yours, the coins taken once ({data.Coins})`, data.Dances.ZombieGroove == true and data.Coins == 100)
settle()
check("... and its card says OWNED", zc.Buy:FindFirstChild("Label", true).Text == "OWNED" and side.Panel.DanceView.Buy:FindFirstChild("Label", true).Text == "YOURS!")
local Action = game.ReplicatedStorage.Remotes.Action
task.wait(0.25)
local okA = Action:InvokeServer("BuyDance", "ZombieGroove")
task.wait(0.25)
local okB = Action:InvokeServer("BuyDance", "Floss")
task.wait(0.25)
DataService.update(player, function(d) d.Coins = 10 end)
local okC, whyC = Action:InvokeServer("BuyDance", "Robot")
check(`the server refuses a dance you own, a free one, and one you can't afford ({whyC})`, okA == false and okB == false and okC == false and data.Coins == 10 and data.Dances.Robot ~= true)
click(side.Shade)
settle()

-- ABILITIES: UI/AbilityCards builds both sides in its slot, its jump between STYLE and PASSES
check("the ABILITIES jump shows, between STYLE and PASSES", panel.AbilitiesTab.Visible and body.HeadAbilities.Visible
	and panel.AbilitiesTab.Position.Y.Offset == panel.StyleTab.Position.Y.Offset + 49 and panel.PassesTab.Position.Y.Offset == panel.StyleTab.Position.Y.Offset + 98)
local abSlot = body:FindFirstChild("AbilitiesSlot")
check("... its section holds the runner and the catcher cards", abSlot ~= nil and abSlot.Visible and abSlot:FindFirstChild("RunnerAbilities") ~= nil
	and abSlot:FindFirstChild("CatcherAbilities") ~= nil and abSlot.RunnerAbilities:FindFirstChild("Lasso") == nil and abSlot.CatcherAbilities:FindFirstChild("Lasso") ~= nil)
check("... sized to its cards, and PASSES comes after it", abSlot ~= nil and abSlot.Size.Y.Offset >= abSlot.CatcherAbilities.Position.Y.Offset + abSlot.CatcherAbilities.Size.Y.Offset
	and body.HeadPasses.Position.Y.Offset >= abSlot.Position.Y.Offset + abSlot.Size.Y.Offset)
-- without the builder, a fresh Shop hides the section and its jump, and PASSES moves up into its place
local real = UI:FindFirstChild("AbilityCards")
if real then real.Parent = nil end
local sg = Instance.new("ScreenGui"); sg.Name = "Fresh"; sg.Parent = player.PlayerGui
local okB, err = pcall(function() require(UI.Screens.Shop).build(sg) end)
check("a Shop builds without AbilityCards: " .. tostring(err), okB)
local fresh = sg:FindFirstChild("Shop")
local fp = fresh and fresh.Group.Panel
check("... no ABILITIES jump or section", fp ~= nil and not fp.AbilitiesTab.Visible and not fp.Products.HeadAbilities.Visible)
check("... PASSES' jump moves up into its place", fp ~= nil and fp.PassesTab.Position.Y.Offset == fp.StyleTab.Position.Y.Offset + 49)
if real then real.Parent = UI end

print(string.format("filters: %d ok, %d failed", ok, failed))
