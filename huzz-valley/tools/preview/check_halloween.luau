-- Check: the Halloween shop end to end offline (owner, Oct 19 17:41: "make a halloween shop when you press on one of
-- the two crates. and then you can buy the crates, or the best knifes for either aura or robux").
--   1. his two stands open it (a stand saved before it had a menu gets its prompt and click);
--   2. the page: both crates with every chance (adding to 100) and the pity counter, the four knives as pictures,
--      each with its Aura price and its Robux price;
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
check("WITCH'S BREW opens the Halloween shop", LobbyProps.Props.Witch_Brew_Cauldron.Opens == "HalloweenShop")
check("SWEETS & TREATS opens the Halloween shop", LobbyProps.Props.Sweets_Treats_Coffin.Opens == "HalloweenShop")
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
check("an old saved stand gets its prompt", prompt ~= nil and prompt:GetAttribute("HuzzOpens") == "HalloweenShop" and prompt.ActionText == "Halloween Shop")
check("... and its click", prop:FindFirstChild("PropClick") ~= nil and old:GetAttribute("Opens") == "HalloweenShop")
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
check(`pressing the stand opens the Halloween shop ({MM.current()})`, MM.current() == "HalloweenShop")

-- 2. the page: the Shop's size, both crates with their odds and pity, the four knives as pictures with both prices
local page = gui:FindFirstChild("HalloweenShop")
local shopWin = gui:FindFirstChild("Shop")
check("the page shows", page ~= nil and page.Visible)
check("the Shop's size", page and shopWin and page.Size == shopWin.Size)
local panel = page and page.Group.Panel
local cratesPage = panel and panel:FindFirstChild("Crates")
for _, entry in HalloweenShop.Crates do
	local crate = Crates.get(entry.Crate)
	local sec = cratesPage and cratesPage:FindFirstChild("Section" .. entry.Crate)
	local n, total = 0, 0
	for _, ch in (sec and sec:GetChildren() or {}) do
		if string.match(ch.Name, "^Odds%d+$") then n += 1; total += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0 end
	end
	check(`{entry.Crate}: all {#crate.Items} chances shown ({n})`, n == #crate.Items)
	check(`{entry.Crate}: chances add to about 100 ({total})`, math.abs(total - 100) < 1.5)
	local card = sec and sec:FindFirstChild(entry.Crate)
	check(`{entry.Crate}: pity shows ({card and card.Pity.Text})`, card ~= nil and card.Pity.Text == "in 40 opens" and card.PityLabel.Text == "GUARANTEED LEGENDARY")
	check(`{entry.Crate}: OPEN for its Aura price`, card ~= nil and card.Open.Content.Label.Text == "OPEN " .. crate.Price)
	check(`{entry.Crate}: a Robux key with its price`, card ~= nil and card.BuyKey.Content.Price.Text == tostring(Products.get(entry.Robux).Price) and card.BuyKey.Content.RobuxBadge.Text == Format.RobuxMark)
	check(`{entry.Crate}: not in Shop > CRATES (its own page)`, crate.Home == "HalloweenShop")
end
__fireOn(panel.KnivesTab, "Activated")
task.wait(0.1)
local knivesPage = panel:FindFirstChild("Knives")
check("KNIVES tab shows the knives", knivesPage.Visible and not cratesPage.Visible)
for _, entry in HalloweenShop.Knives do
	local card = knivesPage:FindFirstChild(entry.Key)
	check(`{entry.Key}: shown as his picture`, card ~= nil and card:FindFirstChild("Picture") ~= nil)
	check(`{entry.Key}: its Aura price ({card and card.BuyAura.Content.Label.Text})`, card ~= nil and card.BuyAura.Content.Label.Text == Format.commas(entry.Aura))
	check(`{entry.Key}: its Robux price`, card ~= nil and card.BuyRobux.Content.Price.Text == tostring(Products.get(entry.Robux).Price))
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
local coven = knivesPage:FindFirstChild("CovenKatana")
check("the card says OWNED and hides its Robux price", coven.BuyAura.Content.Label.Text == "OWNED" and coven.BuyRobux.Visible == false)

-- the page's own Aura buy button (the client asks; the server decides)
DataService.update(me, function(d) d.Aura = HalloweenShop.knife("SugarRushKatana").Aura end)
task.wait(1.1)
__fireOn(knivesPage.SugarRushKatana.BuyAura, "Activated")
task.wait(0.3)
check("the page's Aura button buys the knife", data.Cosmetics.SugarRushKatana == true and data.Aura == 0)

-- 4. Robux: Id 0 never prompts, an ID prompts, a receipt grants once
_G.__prompts = {}
__fireOn(knivesPage.GrandWitchScythe.BuyRobux, "Activated")
task.wait(0.1)
check("a Robux knife with Id 0 only says coming soon", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
__fireOn(panel.CratesTab, "Activated")
task.wait(0.1)
__fireOn(cratesPage.SectionSweets.Sweets.BuyKey, "Activated")
task.wait(0.1)
check("a Robux key with Id 0 only says coming soon", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
__fireOn(cratesPage.SectionWitch.Witch.BuyKey, "Activated")
task.wait(0.1)
check("a key with its ID opens Roblox's prompt", #_G.__prompts == 1 and _G.__prompts[1][2] == 444)
local function receipt(id, purchase) return MarketplaceService.ProcessReceipt({ PlayerId = 1, ProductId = id, PurchaseId = purchase }) end
check("a key receipt is granted after the save", receipt(444, "h1") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Witch == 1)
check("the same receipt never grants twice", receipt(444, "h1") == Enum.ProductPurchaseDecision.PurchaseGranted and data.CrateKeys.Witch == 1)
check("a knife receipt gives the knife, worn", receipt(555, "h2") == Enum.ProductPurchaseDecision.PurchaseGranted and data.Cosmetics.CandyReaper == true and data.Wear.Knife == "CandyReaper")
check("the receipts are in the saved data", table.find(profile.LastSavedData.Receipts, "h1") ~= nil and table.find(profile.LastSavedData.Receipts, "h2") ~= nil)
task.wait(0.2)
check(`the crate shows USE KEY ({cratesPage.SectionWitch.Witch.Open.Content.Label.Text})`, cratesPage.SectionWitch.Witch.Open.Content.Label.Text == "USE KEY (1)")

-- the crate: a key is used before Aura; then Aura; then "not enough"
DataService.update(me, function(d) d.Aura = 130 end)
local okO, res = act("OpenCrate", "Witch")
check("an open uses the key, not Aura", okO == true and type(res) == "table" and data.Aura == 130 and (data.CrateKeys.Witch or 0) == 0)
okO = act("OpenCrate", "Witch")
check("the next open costs 120 Aura", okO == true and data.Aura == 10)
okO, res = act("OpenCrate", "Witch")
check(`not enough Aura: no open ({res})`, okO == false and data.Aura == 10)
check("pity counts every open", data.Pity.Witch == 2 or data.Pity.Witch == 1 or data.Pity.Witch == 0)

-- the page's OPEN starts the opening screen for that crate
DataService.update(me, function(d) d.Aura = 500 end)
task.wait(1.2)
MM.open("HalloweenShop", "Crates")
task.wait(0.2)
__fireOn(cratesPage.SectionSweets.Sweets.Open, "Activated")
task.wait(0.4)
check(`OPEN plays the crate opening ({MM.current()})`, MM.current() == "CrateOpen" and data.Aura == 380)
MM.close()

print(string.format("halloween shop: %d ok, %d failed", ok, fails))
