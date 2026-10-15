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
P.Source = P.Source:gsub('(Key = "SunsetTrail".-Id = )0', '%1111'):gsub('(Key = "VIP".-Id = )0', '%1222')

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
	check("the StarterGui UI is reused, not doubled", #g:GetDescendants() == #savedUI:GetDescendants() + 2) -- + the error box and its padding
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
check("owned cosmetic says OWNED", label("SunsetTrail") == "OWNED")
check("not-on-sale shows its price", label("CrownPose") == "99")
__fireOn(products.BlossomAura.Buy, "Activated")
__fireOn(products.CrownPose.Buy, "Activated")
task.wait(0.05)
check("items without an ID or not on sale never prompt", #_G.__prompts == 0)
MM.close()

-- Companions, dances, rewards and quests (ActionService / ProgressService).
local ProgressService = require(HS.ProgressService)
local function act(...) local r, why = State.action(...); task.wait(0.2); return r, why end
check("starter companion owned and equipped", profile.Data.Characters.Aiko ~= nil and profile.Data.Equipped == "Aiko")
check("starter dance owned", State.data.Dances.Step == true)
check("can't equip a companion you don't own", (act("Equip", "Ren")) == false and profile.Data.Equipped == "Aiko")
check("unequip works", (act("Unequip")) == true and profile.Data.Equipped == "")
check("equip an owned companion", (act("Equip", "Aiko")) == true and profile.Data.Equipped == "Aiko")
check("favourite a companion", (act("FavoriteCharacter", "Hina", true)) == true and profile.Data.FavChars.Hina == true)
check("favourite a dance", (act("FavoriteDance", "Spin", true)) == true and profile.Data.FavDances.Spin == true)
check("bad action refused", (act("GiveMeCoins", 999)) == false)
local coins = profile.Data.Coins
check("level 1 reward claims once", (act("ClaimReward", 1)) == true and profile.Data.Coins == coins + 100 and (act("ClaimReward", 1)) == false and profile.Data.Coins == coins + 100)
check("level 2 reward locked at level 1", (act("ClaimReward", 2)) == false)
check("unfinished quest can't be claimed", (act("ClaimQuest", "Steals")) == false and profile.Data.XP == 0)
ProgressService.addStat(player, "Steals", 3)
check("finished quest gives XP once", (act("ClaimQuest", "Steals")) == true and profile.Data.XP == 100 and (act("ClaimQuest", "Steals")) == false and profile.Data.XP == 100)
check("client can't add stats", (act("addStat", "Steals", 99)) == false)
check("dance pack pass grants its dances", (function()
	DataService.setExtra(player, "Passes", { DancePack = true }); task.wait(0.1)
	local ok2 = State.data.Dances.Wave == true
	DataService.setExtra(player, "Passes", { VIP = true }); task.wait(0.1)
	return ok2
end)())

print(string.format("checks: %d ok, %d failed", ok, failed))
return nil
