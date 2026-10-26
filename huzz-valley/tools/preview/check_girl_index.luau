-- Won anime girls show in the Index: a card drawn from her model, her rarity on the badge, equip when owned.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1; print("ok   " .. name) else failed += 1; print("FAIL " .. name) end
end
local folder = Instance.new("Folder"); folder.Name = "HuzzGirls"; folder.Parent = RS
for i, g in { { "user_mika", "Mika", "Legendary" }, { "user_rin", "Rin", "Common" } } do
	local m = Instance.new("Model"); m.Name = "G" .. i
	local head = Instance.new("Part"); head.Name = "Head"; head.Parent = m
	m:SetAttribute("Id", g[1]); m:SetAttribute("Name", g[2]); m:SetAttribute("Rarity", g[3]); m.Parent = folder
end
local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
local Characters = require(RS.Shared.Config.Characters)
Characters.addGirls(folder) -- (the server's GirlService does this from its own catalog)
DataService.update(player, function(d) d.Characters.user_mika = os.time() end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local State, MM = require(UI.State), require(UI.ModalManager)
local gui = player.PlayerGui:WaitForChild("HuzzUI")
check("Index opens", MM.open("Index") == true)
task.wait(0.3)
local grid = gui.Index.Group.Panel.Grid
check("Mika has a card", grid:FindFirstChild("user_mika") ~= nil)
check("Rin has a card", grid:FindFirstChild("user_rin") ~= nil)
local mika = grid:FindFirstChild("user_mika")
check("Mika drawn from her model", mika and mika:FindFirstChild("Model", true) ~= nil and mika:FindFirstChild("Model", true):IsA("ViewportFrame"))
local badge = mika and mika:FindFirstChild("TierBadge", true)
check("badge says LEGENDARY", badge and badge.Text == "LEGENDARY")
__fireOn(mika, "Activated"); task.wait(0.3)
__fireOn(gui.Index.Group.Panel.EquipAction, "Activated"); task.wait(0.3)
check("Mika can be equipped", State.data.Equipped == "user_mika")
local rin = grid:FindFirstChild("user_rin")
__fireOn(rin, "Activated"); task.wait(0.3)
check("Rin locked (not owned)", gui.Index.Group.Panel.StatusRow.Text.Text == "Locked")
print(`girl index: {ok} ok, {failed} failed`)
return ""
