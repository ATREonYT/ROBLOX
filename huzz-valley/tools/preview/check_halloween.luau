-- Check: the Halloween shop end to end offline (owner, Oct 19 17:41: "make a halloween shop when you press on one of
-- the two crates. and then you can buy the crates, or the best knifes for either aura or robux"). Since Oct 20 14:31
-- ("make it all logically connected an all close to eachother") it is part of the one Shop page, not its own window.
--   1. his two stands open the Shop at their crate (a stand saved before it had a menu gets its prompt and click; an
--      old stand saved as "HalloweenShop" opens the Shop too);
--   2. the page: both crates in CRATES with the HALLOWEEN tag, every chance (adding to 100) and the pity counter; the
--      Halloween knives in KNIVES as pictures, each with its Aura price and its Robux price;
--   3. Aura buys on the server: not enough Aura, already owned, a double tap (bought once, paid once), a knife that
--      isn't sold here; the crate opens for Aura from the page;
--   4. Robux: with Id 0 a tap only says "coming soon" and never prompts; with an Id it prompts; a receipt grants once
--      (a crate key, used before Aura; a knife, worn) and only after the save.
-- From tools/preview: lune run harness.luau ../../src - @check_halloween.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- pretend the owner made two of the products (the shipped config has every Id = 0)
local P = RS.Shared.Config.Products
P.Source = P.Source:gsub('(Key = "WitchCrateKey".-Id = )0', '%1444'):gsub('(Key = "HalloweenCandyReaper".-Id = )0', '%1555')

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 1; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local Crates = require(RS.Shared.Config.Crates)
local HalloweenShop = require(RS.Shared.Config.HalloweenShop)
local Products = require(RS.Shared.Config.Products)
local Format = require(RS.Shared.Format)
local LobbyProps = require(RS.Shared.Config.LobbyProps)
local profile = DataService.get(me)
local data = profile.Data

-- 1. the two stands open it, also a stand saved in his place before it had a menu
check("WITCH'S BREW opens the Shop at its crate", LobbyProps.Props.Witch_Brew_Cauldron.Opens == "Shop" and LobbyProps.Props.Witch_Brew_Cauldron.Section == "Witch")
check("SWEETS & TREATS opens the Shop at its crate", LobbyProps.Props.Sweets_Treats_Coffin.Opens == "Shop" and LobbyProps.Props.Sweets_Treats_Coffin.Section == "Sweets")
local folder = workspace:FindFirstChild("HuzzLobbyProps") or Instance.new("Folder")
folder.Name = "HuzzLobbyProps"
folder.Parent = workspace
local old = Instance.new("Model"); old.Name = "LobbyProp"
old:SetAttribute("Prop", "Sweets_Treats_Coffin"); old:SetAttribute("Title", "SWEETS &\nTREATS")
local pad = Instance.new("Part"); pad.Name = "Pad"; pad.Anchored = true; pad.CFrame = CFrame.new(0, 13, 0); pad.Parent = old
local prop = Instance.new("Model"); prop.Name = "Prop"; prop.Parent = old
old.Parent = folder
require(HS.LobbyPropService).start()
local prompt = pad:FindFirstChild("PropPrompt")
check("an old saved stand gets its prompt", prompt ~= nil and prompt:GetAttribute("HuzzOpens") == "Shop" and prompt.ActionText == "Halloween Shop")
check("... and its click", prop:FindFirstChild("PropClick") ~= nil and old:GetAttribute("Opens") == "Shop")
require(HS.LobbyPropService).start() -- (started again: still one prompt)
local prompts = 0
for _, ch in pad:GetChildren() do if ch.Name == "PropPrompt" then prompts += 1 end end
check("never a second prompt", prompts == 1)

DataService.update(me, function(d) d.Aura, d.Coins = 300, 0 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local State = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.State)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")
local okS, err = pcall(function() require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.LobbyProps).start() end)
check("the stands' script starts: " .. tostring(err), okS)
task.wait(0.1)
__fireOn(game:GetService("ProximityPromptService"), "PromptTriggered", prompt, me)
task.wait(0.2)
check(`pressing the stand opens the Shop ({MM.current()})`, MM.current() == "Shop")

-- 2. the page: both crates in CRATES (tagged HALLOWEEN) with their odds and pity, the knives with both prices
local shopWin = gui:FindFirstChild("Shop")
check("no separate Halloween window any more", gui:FindFirstChild("HalloweenShop") == nil)
local panel = shopWin and shopWin.Group.Panel
local body = panel and panel:FindFirstChild("Products")
local function settle() for _ = 1, 40 do __stepTweens(0.05) end task.wait(0.3) end
settle()
local sweetsCard = body and body:FindFirstChild("CardSweets")
check(`the Sweets stand scrolls the page to its crate ({body and body.CanvasPosition.Y})`, sweetsCard ~= nil and math.abs(body.CanvasPosition.Y - (sweetsCard.Position.Y.Offset - 8 + 4)) <= 1)
-- an old stand saved in his place as "HalloweenShop" still opens the Shop
MM.close()
task.wait(0.2)
prompt:SetAttribute("HuzzOpens", "HalloweenShop")
__fireOn(game:GetService("ProximityPromptService"), "PromptTriggered", prompt, me)
task.wait(0.2)
check(`an old "HalloweenShop" stand opens the Shop ({MM.current()})`, MM.current() == "Shop")
local side = panel and panel:FindFirstChild("Side")
check("the stand slides its crate's panel in", side ~= nil and side.Visible and side.Panel:FindFirstChild("CrateSweets") ~= nil and side.Panel.CrateSweets.Visible)
for _, entry in HalloweenShop.Crates do
	local crate = Crates.get(entry.Crate)
	local view = side and side.Panel:FindFirstChild("Crate" .. entry.Crate)
	local n, total = 0, 0
	for _, ch in (view and view.Odds:GetChildren() or {}) do
		if string.match(ch.Name, "^Odds%d+$") then n += 1; total += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0 end
	end
	check(`{entry.Crate}: all {#crate.Items} chances in its panel ({n})`, n == #crate.Items)
	check(`{entry.Crate}: chances add to about 100 ({total})`, math.abs(total - 100) < 1.5)
	local card = body and body:FindFirstChild("Card" .. entry.Crate)
	check(`{entry.Crate}: pity shows ({card and card.Pity.Text})`, card ~= nil and card.Pity.Text == "LEGENDARY IN 40 OPENS" and view ~= nil and view.PityLabel.Text == "GUARANTEED LEGENDARY")
	check(`{entry.Crate}: coins or Aura in its panel`, view ~= nil and view.PayCoins:FindFirstChild("Label", true).Text == tostring(crate.CoinPrice) and view.Open:FindFirstChild("Label", true).Text == tostring(crate.Price))
	check(`{entry.Crate}: a Robux key with its price`, view ~= nil and view.BuyKey:FindFirstChild("Price", true).Text == tostring(Products.get(entry.Robux).Price) and view.BuyKey:FindFirstChild("RobuxBadge", true) ~= nil)
	check(`{entry.Crate}: in HALLOWEEN, above CRATES`, card ~= nil and card.Position.Y.Offset < body.HeadCrates.Position.Y.Offset and crate.Home == "HalloweenShop")
	-- (Oct 20 20:34: his candy coffin and witch cauldron, cut out onto the Shop's one backdrop)
	local pic = card and card:FindFirstChild("Backdrop") and card.Backdrop:FindFirstChild("Crate")
	check(`{entry.Crate}: his {crate.Picture} picture`, pic ~= nil and pic:GetAttribute("Art") == crate.Picture)
	check(`{entry.Crate}: the old pictures are gone`, card ~= nil and card:FindFirstChild("CratePicture") == nil and card:FindFirstChild("HisPicture") == nil)
end
check("Candy and Witch: his own new pictures", Crates.get("Sweets").Picture == "CrateCardCutCandy" and Crates.get("Witch").Picture == "CrateCardCutWitch")
local function knifeCard(key) return body and body:FindFirstChild("Halloween" .. key) end
local hw = knifeCard(HalloweenShop.Knives[1].Key)
check("the Halloween knives sit in HALLOWEEN (under its crates, above CRATES)", hw ~= nil and hw.Position.Y.Offset > body.CardSweets.Position.Y.Offset and hw.Position.Y.Offset < body.HeadCrates.Position.Y.Offset)
for _, entry in HalloweenShop.Knives do
	local card = knifeCard(entry.Key)
	check(`{entry.Key}: shown as his picture`, card ~= nil and card:FindFirstChild("Picture") ~= nil)
	check(`{entry.Key}: its Aura price ({card and card.BuyAura:FindFirstChild("Label", true).Text})`, card ~= nil and card.BuyAura:FindFirstChild("Label", true).Text == Format.commas(entry.Aura))
	check(`{entry.Key}: its Robux price`, card ~= nil and card.BuyRobux:FindFirstChild("Price", true).Text == tostring(Products.get(entry.Robux).Price))
end

-- 3. Aura buys, all checked on the server
local Action = RS.Remotes.Action
local function act(...) task.wait(1.1); return Action:InvokeServer(...) end -- (past the actions' rate limit)
local covenAura = HalloweenShop.knife("CovenKatana").Aura
local okA, why = act("BuyHalloweenKnife", "CovenKatana")
check(`not enough Aura: refused and nothing taken ({why})`, okA == false and data.Aura == 300 and not data.Cosmetics.CovenKatana and tostring(why):find("more Aura") ~= nil)
check("a knife not sold here is refused", (act("BuyHalloweenKnife", "VineDagger")) == false and (act("BuyHalloweenKnife", 42)) == false)
DataService.update(me, function(d) d.Aura = covenAura + 50 end)
-- a double tap: two buys at once, one knife and one payment
task.wait(1.1)
local results = {}
task.spawn(function() results[1] = Action:InvokeServer("BuyHalloweenKnife", "CovenKatana") end)
task.spawn(function() results[2] = Action:InvokeServer("BuyHalloweenKnife", "CovenKatana") end)
task.wait(0.3)
check(`a double tap buys it once ({tostring(results[1])}, {tostring(results[2])})`, (results[1] == true) ~= (results[2] == true))
check("paid once", data.Aura == 50 and data.Cosmetics.CovenKatana == true)
check("worn straight away", data.Wear.Knife == "CovenKatana")
DataService.update(me, function(d) d.Aura = covenAura * 2 end)
okA, why = act("BuyHalloweenKnife", "CovenKatana")
check(`already owned: refused, nothing taken ({why})`, okA == false and data.Aura == covenAura * 2 and tostring(why):find("own") ~= nil)
task.wait(0.2)
local coven = knifeCard("CovenKatana")
check("the card says OWNED and hides its Robux price", coven.BuyAura:FindFirstChild("Label", true).Text == "OWNED" and coven.BuyRobux.Visible == false)

-- the page's own Aura buy button (the client asks; the server decides)
DataService.update(me, function(d) d.Aura = HalloweenShop.knife("SugarRushKatana").Aura end)
task.wait(1.1)
__fireOn(knifeCard("SugarRushKatana").BuyAura, "Activated")
task.wait(0.3)
check("the page's Aura button buys the knife", data.Cosmetics.SugarRushKatana == true and data.Aura == 0)

-- 4. Robux: Id 0 never prompts, an ID prompts, a receipt grants once
_G.__prompts = {}
__fireOn(knifeCard("GrandWitchScythe").BuyRobux, "Activated")
task.wait(0.1)
check("a Robux knife with Id 0 only says coming soon", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
__fireOn(panel.HalloweenTab, "Activated")
task.wait(0.1)
__fireOn(side.Panel.CrateSweets.BuyKey, "Activated")
task.wait(0.1)
check("a Robux key with Id 0 only says coming soon", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
__fireOn(side.Panel.CrateWitch.BuyKey, "Activated")
task.wait(0.1)
check("a key with its ID opens Roblox's prompt", #_G.__prompts == 1 and _G.__prompts[1][2] == 444)
local function receipt(id, purchase) return MarketplaceService.ProcessReceipt({ PlayerId = 1, ProductId = id, PurchaseId = purchase }) end
check("a key receipt is granted after the save", receipt(444, "h1") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Witch == 1)
check("the same receipt never grants twice", receipt(444, "h1") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Witch == 1)
check("a knife receipt gives the knife, worn", receipt(555, "h2") == Enum.ProductPurchaseDecision.PurchaseGranted and data.Cosmetics.CandyReaper == true and data.Wear.Knife == "CandyReaper")
-- never Robux for nothing: the server won't prompt a knife you own; a late receipt for one gives keys instead
local promptsBefore = #_G.__prompts
local okR, whyR = act("PromptHalloween", "HalloweenCandyReaper")
check(`the server never prompts a knife you own ({whyR})`, okR == false and #_G.__prompts == promptsBefore)
check("nor a product without its ID", (act("PromptHalloween", "SweetsCrateKey")) == false and #_G.__prompts == promptsBefore)
local sweets0 = data.CrateKeys.Sweets or 0
check("a receipt for a knife you own gives its crate's keys", receipt(555, "h3") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Sweets == sweets0 + HalloweenShop.knife("CandyReaper").Keys)
check("... the server sets the line for the player", tostring(me:GetAttribute("HuzzShopNotice")):find("You already had Candy Reaper") ~= nil)
__fireOn(me, "Attr_HuzzShopNotice") -- (the harness fires attribute signals only when asked)
task.wait(0.2)
check(`... and says so on screen ({gui.Toast.Text})`, gui.Toast.Text == "You already had Candy Reaper, so you got 10 Candy Crate keys instead.")
-- taken off sale while a purchase was on its way: the paid receipt is still granted (OnSale only stops new prompts)
local reaperProduct = Products.get("HalloweenCandyReaper")
reaperProduct.OnSale = false
local sweets1 = data.CrateKeys.Sweets
check("a paid receipt is granted after the item went off sale", receipt(555, "h4") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Sweets == sweets1 + HalloweenShop.knife("CandyReaper").Keys)
reaperProduct.OnSale = true
check("the receipts are in the saved data", table.find(profile.LastSavedData.Receipts, "h1") ~= nil and table.find(profile.LastSavedData.Receipts, "h2") ~= nil)
task.wait(0.2)
check(`the crate shows its key ({body.CardWitch.Open:FindFirstChild("Label", true).Text})`, body.CardWitch.Open:FindFirstChild("Label", true).Text == "OPEN (1 KEY)")
MM.open("Shop", "Witch")
task.wait(0.4)
check(`... and its panel USE KEY ({side.Panel.CrateWitch.PayCoins:FindFirstChild("Label", true).Text})`, side.Panel.CrateWitch.PayCoins:FindFirstChild("Label", true).Text == "USE KEY (1)" and not side.Panel.CrateWitch.Open.Visible)

-- the crate: a key is used before Aura; then Aura; then "not enough"
DataService.update(me, function(d) d.Aura = 130 end)
local okO, res = act("OpenCrate", "Witch")
check("an open uses the key, not Aura", okO == true and type(res) == "table" and data.Aura == 130 and (data.CrateKeys.Witch or 0) == 0)
okO = act("OpenCrate", "Witch")
check(`the next open costs 79 Aura ({data.Aura})`, okO == true and data.Aura == 51)
okO, res = act("OpenCrate", "Witch")
check(`not enough Aura: no open ({res})`, okO == false and data.Aura == 51)
check("pity counts every open", data.Pity.Witch == 2 or data.Pity.Witch == 1 or data.Pity.Witch == 0)

-- the page's OPEN starts the opening screen for that crate
DataService.update(me, function(d) d.Aura = 500 end)
task.wait(1.2)
MM.open("Shop", "Sweets")
task.wait(0.2)
local sweetsKeys = data.CrateKeys.Sweets or 0 -- (the keys from the owned knife's receipt above)
task.wait(0.3)
__fireOn(side.Panel.CrateSweets.PayCoins, "Activated")
task.wait(0.4)
check(`its panel's button plays the crate opening with a key ({MM.current()})`, MM.current() == "CrateOpen" and data.Aura == 500 and (data.CrateKeys.Sweets or 0) == sweetsKeys - 1)
MM.close()

print(string.format("halloween shop: %d ok, %d failed", ok, fails))
