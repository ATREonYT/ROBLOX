-- Check: the Oct 20 bug hunt fixes, offline.
--   1. A full window (the Shop) closes when you're pulled into a round (HuzzRole Runner/Catcher, or the line-up
--      starts for you), so the round HUD and HERO/CHICKEN show; the picked runner's Menu side panel closes for the
--      pick; a player in the lobby keeps their window. Escape closes a window even when Roblox already handled it.
--   5. A paid receipt for a product taken off sale since (OnSale false) is still granted, once, and answered
--      "granted" only after the save.
--   6. A crate window closed while the server answers: no reel in a hidden window, a toast says the prize.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_bughunt.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
DataService.update(me, function(d) d.Aura, d.Coins = 500, 100 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.4)
local Client = game.StarterPlayer.StarterPlayerScripts.HuzzClient
local MM = require(Client.UI.ModalManager)
local Toast = require(Client.UI.Toast)
local toasts = {}
local realShow = Toast.show
Toast.show = function(text, ...)
	table.insert(toasts, text)
	return realShow(text, ...)
end
local round = RS.Remotes.Round
local function setRole(role)
	me:SetAttribute("HuzzRole", role)
	__fireOn(me, "Attr_HuzzRole")
	task.wait(0.05)
end
local function setStage(stage, pickId)
	if pickId ~= nil then
		round:SetAttribute("PickId", pickId)
		__fireOn(round, "Attr_PickId")
	end
	round:SetAttribute("Stage", stage)
	__fireOn(round, "Attr_Stage")
	task.wait(0.05)
end

-- 1. pulled into a round
setRole("Lobby"); setStage("Rolling", 0)
MM.open("Shop")
check("the Shop opens in the lobby", MM.current() == "Shop")
setStage("Lineup")
check("a lobby player (watching) keeps the Shop through the line-up", MM.current() == "Shop")
setRole("Runner")
check("becoming a runner closes the Shop", MM.current() == nil)
check("MenuOpen is false again (shift lock and the round HUD come back)", me:GetAttribute("MenuOpen") ~= true)
MM.open("Index")
setStage("Countdown"); setStage("Lineup")
check("the next line-up closes a window opened in between", MM.current() == nil)
MM.open("Menu")
check("the Menu side panel opens in a round", MM.current() == "Menu")
setStage("Picking", 5) -- (someone else picked)
check("someone else's pick leaves the Menu side panel open", MM.current() == "Menu")
setStage("Lineup", 0)
MM.open("Menu")
setStage("Picking", me.UserId)
check("your own HERO/CHICKEN pick closes the Menu side panel", MM.current() == nil)
for _ = 1, 3 do __fireOn(game:GetService("RunService"), "RenderStepped", 1 / 30) end
local hero = me.PlayerGui.HuzzUI:FindFirstChild("HeroChoice", true)
check("HERO/CHICKEN shows", hero ~= nil and hero.Visible == true)
setRole("Catcher"); setStage("Running")
MM.open("Dances")
setRole("Lobby"); setStage("GameOver", 0)
for _ = 1, 3 do __fireOn(game:GetService("RunService"), "RenderStepped", 1 / 30) end -- (the pick panel lets go)
check("the pick is over (HuzzChoosing off)", me:GetAttribute("HuzzChoosing") ~= true)
-- Escape that Roblox already handled (processed = true) still closes the window
MM.open("Settings")
__fireOn(UserInputService, "InputBegan", { KeyCode = Enum.KeyCode.Escape, UserInputType = Enum.UserInputType.Keyboard }, true)
check("Escape closes a window even when Roblox handled the key", MM.current() == nil)

-- 5. a receipt for a product taken off sale after it was paid for
local ShopService = require(HS.ShopService)
local Products = require(RS.Shared.Config.Products)
local base = Products.get("Coins500")
local offSale = table.clone(base)
offSale.Id, offSale.OnSale = 424242, false
local realBy = Products.byProductId
Products.byProductId = function(id) if id == 424242 then return offSale end return realBy(id) end
local data = DataService.get(me).Data
local coins0 = data.Coins
local decision = ShopService._processReceipt({ PlayerId = me.UserId, ProductId = 424242, PurchaseId = "bughunt-1" })
check(`an off-sale product's paid receipt is granted ({decision})`, decision == Enum.ProductPurchaseDecision.PurchaseGranted)
check(`its coins arrive ({coins0} -> {data.Coins})`, data.Coins == coins0 + base.Amount)
check("the receipt is in the save", table.find(DataService.get(me).LastSavedData.Receipts or {}, "bughunt-1") ~= nil)
ShopService._processReceipt({ PlayerId = me.UserId, ProductId = 424242, PurchaseId = "bughunt-1" })
check("the same receipt again grants nothing", data.Coins == coins0 + base.Amount)
local unknown = ShopService._processReceipt({ PlayerId = me.UserId, ProductId = 777777, PurchaseId = "bughunt-2" })
check("an unknown product is never answered granted", unknown == Enum.ProductPurchaseDecision.NotProcessedYet)
-- (Oct 20 14:07: an Aura pack's receipt gives its Aura once, only after the save)
local auraPack = table.clone(Products.get("Aura200"))
auraPack.Id = 434343
Products.byProductId = function(id) if id == 434343 then return auraPack end return realBy(id) end
local auraBefore = data.Aura or 0
local d2 = ShopService._processReceipt({ PlayerId = me.UserId, ProductId = 434343, PurchaseId = "bughunt-aura" })
check(`an Aura pack's receipt is granted ({d2})`, d2 == Enum.ProductPurchaseDecision.PurchaseGranted and data.Aura == auraBefore + 200)
check("... and saved", table.find(DataService.get(me).LastSavedData.Receipts or {}, "bughunt-aura") ~= nil)
ShopService._processReceipt({ PlayerId = me.UserId, ProductId = 434343, PurchaseId = "bughunt-aura" })
check("the same Aura receipt again grants nothing", data.Aura == auraBefore + 200)
Products.byProductId = realBy

-- 6. the crate window closed while the server answers
local Action = RS.Remotes.Action
local realInvoke = Action.OnServerInvoke
local aura0 = data.Aura
Action.OnServerInvoke = function(player, verb, ...)
	if verb == "OpenCrate" then MM.close() end -- (the kid shuts it, or a round takes over, mid-call)
	return realInvoke(player, verb, ...)
end
table.clear(toasts)
local sounds0 = #_G.__sounds
MM.open("CrateOpen", "Starter")
task.wait(0.3)
Action.OnServerInvoke = realInvoke
check("the crate was opened once (Aura taken)", data.Aura < aura0)
check("the window stays closed", MM.current() == nil)
local saidPrize = false
for _, t in toasts do
	if string.find(t, "You got") or string.find(t, "again:") then saidPrize = true end
end
check(`a toast says the prize ({table.concat(toasts, " | ")})`, saidPrize)
local skip = me.PlayerGui.HuzzUI:FindFirstChild("CrateOpen") and me.PlayerGui.HuzzUI.CrateOpen:FindFirstChild("Skip", true)
check("no reel playing in the hidden window (no Skip button)", skip == nil or skip.Visible == false)
-- and it opens normally next time
MM.open("CrateOpen", "Starter")
task.wait(0.3)
check("the next open plays as usual", MM.current() == "CrateOpen")

print(`bug hunt checks: {ok} ok, {fails} failed`)
