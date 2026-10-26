-- The Starter Pack opens by itself after your first game of the visit, but not from level 8 on
-- (Config/Products.StarterPopupMaxLevel; owner, Oct 25 21:40: "stop showing up after the users reach around level 7-8").
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
_G.__isStudio = true -- (live it also needs the pass ID; Studio shows it anyway)
local Players = game:GetService("Players")
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local Products = require(game.ReplicatedStorage.Shared.Config.Products)
local XPPer = require(game.ReplicatedStorage.Shared.Config.Progression).XPPerLevel
DataService.update(me, function(d) d.XP = XPPer * Products.StarterPopupMaxLevel end) -- level 8
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.4)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local opened = false
MM.changed(function(name) if name == "StarterPack" then opened = true end end)
local function playOne()
	for _ = 1, 3 do if MM.current() then MM.close() end task.wait(0.05) end
	me:SetAttribute("HuzzRole", "Runner"); __fireOn(me, "Attr_HuzzRole"); task.wait(0.1)
	me:SetAttribute("HuzzRole", nil); __fireOn(me, "Attr_HuzzRole"); task.wait(0.1)
	for _ = 1, 3 do if MM.current() and MM.current() ~= "StarterPack" then MM.close() end task.wait(0.05) end
	task.wait((Products.StarterPopupAfter or 8) + 0.6)
end
playOne()
check("a level 8 player doesn't get the Starter Pack popup", not opened)
DataService.update(me, function(d) d.XP = XPPer * (Products.StarterPopupMaxLevel - 1) end) -- level 7
task.wait(0.2)
for _ = 1, 3 do if MM.current() then MM.close() end task.wait(0.05) end
check("... not even when a window closes later", not opened)
playOne()
task.wait(1.5) -- (the pop-up waits for the lobby to settle)
check("a level 7 player still gets it after a game", opened)
print(string.format("checks: %d ok, %d failed", ok, fails))
