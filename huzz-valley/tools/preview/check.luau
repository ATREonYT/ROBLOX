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
check("HUD hidden while open", gui.LobbyHud.Visible == false)
MM.close()
for _ = 1, 10 do __stepTweens(0.05) end
check("close returns to play", MM.current() == nil and gui.LobbyHud.Visible == true and player:GetAttribute("MenuOpen") == false)
check("unbuilt screens refuse to open", MM.open("Dances") == false)

-- Shop buttons: owned shows OWNED, unconfigured shows a price but never prompts, not-on-sale shows SOON.
_G.__prompts = {}
MM.open("Shop", "Cosmetics")
local products = gui.Shop.Group.Panel.Products
local function label(key) return products[key].Buy.Content.Label.Text end
check("owned cosmetic says OWNED", label("SunsetTrail") == "OWNED")
check("not-on-sale says SOON", label("CrownPose") == "SOON")
__fireOn(products.BlossomAura.Buy, "Activated")
task.wait(0.05)
check("item without an ID never prompts", #_G.__prompts == 0)
MM.close()

print(string.format("checks: %d ok, %d failed", ok, failed))
return nil
