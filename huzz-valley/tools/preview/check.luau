-- Functional check (no pictures): drives the real server + client code and asserts the rules.
-- Run: sh check.sh   -> prints "checks: N ok, 0 failed"
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

-- Pretend the owner created two products (the shipped config has every Id = 0).
local P = game.ReplicatedStorage.Shared.Config.Products
P.Source = P.Source:gsub('(Key = "SunsetTrail".-Id = )0', '%1111'):gsub('(Key = "VIP".-Id = )0', '%1222'):gsub('(Key = "Spins10".-Id = )0', '%1333')

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
-- When the UI saved in StarterGui is used, an edit made to it in Studio must survive into the game.
local savedUI = game:GetService("StarterGui"):FindFirstChild("HuzzUI")
local reusing = savedUI ~= nil and not __fresh
if reusing then player.PlayerGui.HuzzUI.LobbyHud.Left.Index.Label.TextSize = 20 end
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local HS = game.ServerScriptService.HuzzServer
local DataService, SettingsService = require(HS.DataService), require(HS.SettingsService)
local profile = DataService.get(player)
check("profile loads", profile ~= nil)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local State, MM = require(UI.State), require(UI.ModalManager)
check("client got state", State.data.Loaded == true)
if reusing then
	local g = player.PlayerGui.HuzzUI
	-- (picture stand-ins are made at runtime where a picture can't be drawn, ImageLoader.standIn, and never saved)
	local live = 0
	for _, d in g:GetDescendants() do
		local standIn = false -- (a stand-in and everything in it: a glyph, or a knife's 3D view)
		local node = d
		while node and node ~= g do
			if node:GetAttribute("NoPicture") ~= nil or node.Name == "PopScale" then standIn = true break end -- (and a card's pop-in scale, UI/ShopStyle)
			node = node.Parent
		end
		if not standIn then live += 1 end
	end
	check("the StarterGui UI is reused, not doubled", live == #savedUI:GetDescendants() + 2 + (if g:FindFirstChild("HuzzBuildStamp") then 1 else 0)) -- + the error box and its padding (+ the Studio build stamp)
	check("a Studio edit to a saved part stays in the game", g.LobbyHud.Left.Index.Label.TextSize == 20)
end

-- Receipts: granted once, only for products on sale, and only answered after saving.
local receipt = { PlayerId = 1, ProductId = 111, PurchaseId = "p1" }
check("receipt granted", MarketplaceService.ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
check("cosmetic owned", profile.Data.Cosmetics.SunsetTrail == true)
check("client sees ownership", State.owns("SunsetTrail"))
profile.Data.Cosmetics.SunsetTrail = nil
check("same receipt not granted twice", MarketplaceService.ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted and profile.Data.Cosmetics.SunsetTrail == nil)
profile.Data.Cosmetics.SunsetTrail = true
check("unknown product not granted", MarketplaceService.ProcessReceipt({ PlayerId = 1, ProductId = 999, PurchaseId = "p2" }) == Enum.ProductPurchaseDecision.NotProcessedYet)

-- Game pass ownership comes from Roblox, and drives the VIP chat tag attribute.
_G.__owned = { [222] = true }
__fireOn(MarketplaceService, "PromptGamePassPurchaseFinished", player, 222, true)
task.wait(0.1)
check("VIP pass owned", State.owns("VIP") and player:GetAttribute("VIP") == true)

-- Settings: saved, validated, social checks.
check("valid setting saves", (State.setSetting("InventoryVisibility", "Nobody")) == true and profile.Data.Settings.InventoryVisibility == "Nobody")
task.wait(0.1)
check("bad value refused", (State.setSetting("InventoryVisibility", "Strangers")) == false and State.setting("InventoryVisibility") == "Nobody")
task.wait(0.1)
check("reserved key refused", (State.setSetting("MenuKey", "W")) == false)
task.wait(0.1)
check("menu key rebinds", (State.setSetting("MenuKey", "N")) == true and profile.Data.Settings.MenuKey == "N")
task.wait(0.1)
check("volume clamps", (State.setSetting("MusicVolume", 150)) == false)
local other = Instance.new("Player"); other.UserId = 2
check("Nobody blocks others", SettingsService.allows(player, other, "InventoryVisibility") == false)
check("owner always allowed", SettingsService.allows(player, player, "InventoryVisibility") == true)

-- One window at a time; HUD hidden while open; MenuOpen flag for gameplay input.
MM.open("Shop")
MM.open("Settings")
local gui = player.PlayerGui.HuzzUI
check("switching hides the old window", gui.Shop.Visible == false and gui.Settings.Visible == true)
check("menu flag set", player:GetAttribute("MenuOpen") == true)
for _ = 1, 10 do __stepTweens(0.05) end
check("HUD slides away while open", gui.LobbyHud.Left.Position.X.Offset <= -300)
MM.close()
for _ = 1, 10 do __stepTweens(0.05) end
check("close returns to play", MM.current() == nil and gui.LobbyHud.Left.Position.X.Offset == 0 and player:GetAttribute("MenuOpen") == false)
check("unbuilt screens refuse to open", MM.open("Recruitment") == false)

-- Shop buttons: owned shows OWNED, unconfigured shows a price but never prompts, not-on-sale shows SOON.
_G.__prompts = {}
MM.open("Shop", "Cosmetics")
local products = gui.Shop.Group.Panel.Products
local function label(key) return products[key].Buy.Content.Label.Text end
check("owned cosmetic you wear says WEARING", label("SunsetTrail") == "WEARING")
check("not-on-sale shows its price", label("CrownPose") == "99")
__fireOn(products.BlossomAura.Buy, "Activated")
__fireOn(products.CrownPose.Buy, "Activated")
task.wait(0.05)
check("items without an ID or not on sale never prompt", #_G.__prompts == 0)
MM.close()

-- The knife Game Pass cards (owner Oct 18: "add the knifes into the ui for the gamepass menu"): five in PASSES, named
-- as he wrote them, each with its picture and BUY; BUY says "coming soon" and never prompts without a pass ID.
_G.__prompts = {}
MM.open("Shop", "Passes")
products = gui.Shop.Group.Panel.Products
local cardNames = {}
for _, key in { "HunterKnifePass", "MoonlitKnifePass", "SunriseKnifePass", "InfernoKnifePass", "FrostKnifePass" } do
	local card = products:FindFirstChild(key)
	check(key .. " card: picture, knife line, BUY", card ~= nil and card:FindFirstChild("Picture") ~= nil and card.Line.Text:find("knife") ~= nil and card.Buy.Content.Label.Text == "BUY")
	if card then
		table.insert(cardNames, card.Title.Text)
		__fireOn(card.Buy, "Activated")
	end
end
task.wait(0.05)
check("the cards' names as he wrote them", table.concat(cardNames, ",") == "Hunter Knife,Moonlit Knife,Sunrise Knife,Inferno Knife,Frost Knife")
check("knife cards never prompt without a Game Pass ID", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
check("the VIP and Dance Pack banners are still there", products:FindFirstChild("VIP") ~= nil and products:FindFirstChild("DancePack") ~= nil)
MM.close()

-- Companions, dances, rewards and quests (ActionService / ProgressService).
local ProgressService = require(HS.ProgressService)
local function act(...) local r, why = State.action(...); task.wait(0.2); return r, why end
-- Companions are only the girls you win: two test girls, one owned.
local Characters = require(game.ReplicatedStorage.Shared.Config.Characters)
local testGirls = Instance.new("Folder")
for _, g in { { "g_mika", "Mika", "Epic" }, { "g_rin", "Rin", "Rare" } } do
	local m = Instance.new("Model"); m.Name = g[1]; m:SetAttribute("Id", g[1]); m:SetAttribute("Name", g[2]); m:SetAttribute("Rarity", g[3]); m.Parent = testGirls
end
Characters.addGirls(testGirls)
check("no placeholder companions (Aiko, Ren, Sora, Hina gone)", Characters.get("Aiko") == nil and Characters.get("Hina") == nil and profile.Data.Characters.Aiko == nil and profile.Data.Equipped == "")
require(HS.DataService).update(player, function(d) d.Characters.g_mika = os.time() end)
check("starter dance owned", State.data.Dances.Floss == true)
check("can't equip a companion you don't own", (act("Equip", "g_rin")) == false and profile.Data.Equipped == "")
check("equip an owned companion", (act("Equip", "g_mika")) == true and profile.Data.Equipped == "g_mika")
check("unequip works", (act("Unequip")) == true and profile.Data.Equipped == "")
check("favourite a companion", (act("FavoriteCharacter", "g_rin", true)) == true and profile.Data.FavChars.g_rin == true)
check("favourite a dance", (act("FavoriteDance", "Robot", true)) == true and profile.Data.FavDances.Robot == true)
check("bad action refused", (act("GiveMeCoins", 999)) == false)
local coins = profile.Data.Coins
check("level 1 reward claims once", (act("ClaimReward", 1)) == true and profile.Data.Coins == coins + 100 and (act("ClaimReward", 1)) == false and profile.Data.Coins == coins + 100)
check("level 2 reward locked at level 1", (act("ClaimReward", 2)) == false)
check("unfinished quest can't be claimed", (act("ClaimQuest", "Q1Rounds")) == false and profile.Data.XP == 0)
ProgressService.addStat(player, "Rounds", 3)
check("finished quest gives XP once", (act("ClaimQuest", "Q1Rounds")) == true and profile.Data.XP == 100 and (act("ClaimQuest", "Q1Rounds")) == false and profile.Data.XP == 100)
check("client can't add stats", (act("addStat", "Rounds", 99)) == false)
check("dance pack pass grants its dances", (function()
	DataService.setExtra(player, "Passes", { DancePack = true }); task.wait(0.1)
	local ok2 = State.data.Dances.SwingTime == true and State.data.Dances.Toprock == true
	DataService.setExtra(player, "Passes", { VIP = true }); task.wait(0.1)
	return ok2
end)())

-- The coin shop (Config/CoinShop) and Aura: the server checks the price, takes the coins and wears the item.
DataService.update(player, function(d) d.Coins = 100 end); task.wait(0.1)
check("coin shop: can't buy without the coins", (act("BuyWithCoins", "MintTrail")) == false and profile.Data.Cosmetics.MintTrail == nil and profile.Data.Coins == 100)
DataService.update(player, function(d) d.Coins = 1000 end); task.wait(0.1)
check("coin shop: buying takes the price and wears it", (act("BuyWithCoins", "MintTrail")) == true and profile.Data.Coins == 600 and profile.Data.Cosmetics.MintTrail == true and profile.Data.Wear.Trail == "MintTrail")
check("coin shop: can't buy it twice", (act("BuyWithCoins", "MintTrail")) == false and profile.Data.Coins == 600)
check("coin shop: take it off and wear it again", (act("Wear", "Trail", nil)) == true and profile.Data.Wear.Trail == "" and (act("Wear", "Trail", "MintTrail")) == true and profile.Data.Wear.Trail == "MintTrail")
check("coin shop: can't wear what you don't own", (act("Wear", "Tag", "TagPink")) == false)
-- Robux cosmetics go in their own slot; the girls' rewards are earned, worn if the slot is empty, never bought.
check("cosmetics: a Robux trail can be worn and taken off", (act("Wear", "Trail", "SunsetTrail")) == (profile.Data.Cosmetics.SunsetTrail == true))
check("cosmetics: a cosmetic only fits its own slot", (act("Wear", "Aura", "SunsetTrail")) == false)
check("rewards: never sold for coins", (act("BuyWithCoins", "TitleSecret")) == false and profile.Data.Cosmetics.TitleSecret == nil)
DataService.update(player, function(d) d.Stats.Heroes = 10 end); task.wait(0.3)
check("rewards: 10 hero runs earn the Huss Hero title, worn", profile.Data.Cosmetics.TitleHero == true and profile.Data.Wear.Title == "TitleHero")
check("rewards: a title needs no Secret girl to be locked", profile.Data.Cosmetics.TitleSecret == nil)
check("coin shop: can't wear an item in the wrong slot", (act("Wear", "Knife", "MintTrail")) == false)
check("Aura: gems became Aura and the client sees it", State.data.Aura ~= nil and profile.Data.Gems == nil)
check("crates: an unknown crate can't be opened", (act("OpenCrate", "Nope")) == false)

-- Spin the Wheel (SpinService, Shared/SpinRules, Screens/SpinWheel): one free spin per 15 minutes, owned spins
-- count down, bought spins only through ProcessReceipt, a pack without an ID never prompts.
local Wheel = require(game.ReplicatedStorage.Shared.Config.SpinWheel)
local SpinRules = require(game.ReplicatedStorage.Shared.SpinRules)
local SpinService = require(HS.SpinService)
local spinRemote = game.ReplicatedStorage.Remotes.Spin
local function spinNow(n) task.wait(0.85); local a, b = spinRemote:InvokeServer(n); task.wait(0.1); return a, b end
local d0 = profile.Data
check("spin: a new save has its free spin", d0.FreeSpinAt == 0 and d0.Spins == 0 and SpinRules.available(State.data, os.time()) == 1)
local worth = function() return d0.Coins + d0.Aura * 10 + (d0.Boosts.Coins or 0) + (if d0.Cosmetics.SpinKnife then 1 else 0) end
local w0 = worth()
local okS, res = spinNow(1)
check("spin: the free spin works and gives a prize", okS == true and res.usedFree == true and #res.rolls == 1 and worth() > w0)
check("spin: next free spin in 15 minutes", math.abs(d0.FreeSpinAt - (os.time() + Wheel.FreeEvery)) <= 2 and State.data.FreeSpinAt == d0.FreeSpinAt)
check("spin: the client is told which slice", Wheel.Items[res.rolls[res.land].Slot].Key == res.rolls[res.land].Key)
local before = d0.FreeSpinAt
okS, res = spinNow(1)
check("spin: no second free spin", okS == false and d0.FreeSpinAt == before and type(res) == "string")
DataService.update(player, function(d) d.Spins = 3 end)
okS = spinNow(1)
check("spin: an owned spin counts down", okS == true and d0.Spins == 2 and d0.FreeSpinAt == before)
okS = spinNow(5)
check("spin: x5 refused with 2 spins", okS == false and d0.Spins == 2)
check("spin: odd counts refused", (spinNow(7)) == false and (spinNow("lots")) == false and d0.Spins == 2)
DataService.update(player, function(d) d.Spins = 12 end)
okS, res = spinNow(10)
check("spin: x10 gives 10 prizes", okS == true and #res.rolls == 10 and d0.Spins == 2 and res.rolls[res.land] ~= nil)
DataService.update(player, function(d) d.Boosts.Coins = os.time() + 60 end)
check("spin: x2 Coins boost doubles round pay", SpinService.boost(player, "Coins") == 2 and SpinService.boost(player, "Aura") == 1)
check("spin: the Spin Knife can't be bought with coins", (act("BuyWithCoins", "SpinKnife")) == false)
-- buying spins: granted once per receipt, only by the server
local spins0 = d0.Spins
check("spin: a spins receipt grants 10 spins", MarketplaceService.ProcessReceipt({ PlayerId = 1, ProductId = 333, PurchaseId = "s1" }) == Enum.ProductPurchaseDecision.PurchaseGranted and d0.Spins == spins0 + 10)
check("spin: the same receipt again grants nothing", MarketplaceService.ProcessReceipt({ PlayerId = 1, ProductId = 333, PurchaseId = "s1" }) == Enum.ProductPurchaseDecision.PurchaseGranted and d0.Spins == spins0 + 10)
-- the screen: opens from the HUD button and the lobby wheel; the pack without an ID never prompts
__fireOn(gui.LobbyHud.Right.Spin, "Activated")
task.wait(0.1)
check("spin: the HUD SPIN button opens the wheel", MM.current() == "SpinWheel" and gui.SpinWheel.Visible == true)
local sw = gui.SpinWheel.Group
_G.__prompts = {}
__fireOn(sw.Right.BuySpins1, "Activated")
task.wait(0.05)
check("spin: buying with no product ID never prompts", #_G.__prompts == 0 and gui.Toast.Text:find("coming soon") ~= nil)
__fireOn(sw.Right.BuySpins10, "Activated")
task.wait(0.05)
check("spin: a set-up pack opens Roblox's prompt", #_G.__prompts == 1 and _G.__prompts[1][2] == 333)
check("spin: Spin! shows the count", sw.Bottom.Spin.Content.Label.Text == `Spin! ({d0.Spins})`)
check("spin: the pity counter shows", sw.Bottom.Pity.Count.Text:find("spin") ~= nil)
check("spin: the odds list shows every slice", #sw.OddsList:GetChildren() >= 8 and sw.OddsList.Row8.Chance.Text:match("%%$") ~= nil)
MM.close()
local model = Instance.new("Model"); model.Name = "Spin The Wheel"
local wheelPart = Instance.new("Part"); wheelPart.Name = "Base"; wheelPart.Parent = model
model.Parent = workspace
__fireOn(workspace, "DescendantAdded", model)
task.wait(0.1)
local prompt = wheelPart:FindFirstChild("HuzzSpinPrompt")
check("spin: the owner's wheel gets a prompt and a click", prompt ~= nil and prompt.ActionText == "Spin the Wheel" and wheelPart:FindFirstChild("HuzzSpinClick") ~= nil)
if prompt then __fireOn(prompt, "Triggered", player) end
task.wait(0.1)
check("spin: using the wheel opens the screen", MM.current() == "SpinWheel")
-- a spin on the screen lands on the server's slice and shows the prize
DataService.update(player, function(d) d.FreeSpinAt = 0 end)
task.wait(0.1)
__fireOn(sw.Bottom.Spin, "Activated")
task.wait(0.2)
check("spin: buttons wait while it spins", sw.Bottom.Spin.Content.Label.Text == "Spinning..." and sw.Bottom.Spin:GetAttribute("Disabled") == true)
task.wait(4.7)
__fireOn(game:GetService("RunService"), "RenderStepped", 1 / 60)
task.wait(0.8)
local landed = Wheel.Items[SpinRules.slotAt(sw.Wheel.Disc.Rotation)]
check("spin: the wheel stops on the prize it shows", sw.Reward.Visible == true and sw.Reward.One.PrizeName.Text:find(landed.Name, 1, true) == 1)
MM.close()

print(string.format("checks: %d ok, %d failed", ok, failed))
return nil
