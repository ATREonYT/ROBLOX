-- Motion preview snippet: plays a scripted session at 30 fps (open Shop, hover/press, switch tab, close, open
-- Settings...) and exports one UI frame per step to __framesDir (frame_0001.json ...). render via shoot_frames.js.
local Players = game:GetService("Players")
local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
DataService.update(player, function(d) d.Coins, d.Aura = 12450, 320 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local gui = player.PlayerGui.HuzzUI
for _ = 1, 20 do __stepTweens(0.05) end

local n = 0
local function frames(count)
	for _ = 1, count do
		task.wait(1 / 30) -- real time, so task.delay staggers advance too
		__stepTweens(1 / 30)
		n += 1
		__exportUI(gui, string.format("%s/frame_%04d.json", __framesDir, n))
	end
end
local mouse = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }
local function click(btn, hold)
	__fireOn(btn, "MouseEnter")
	frames(5)
	__fireOn(btn, "InputBegan", mouse)
	frames(hold or 4)
	__fireOn(btn, "InputEnded", mouse)
	__fireOn(btn, "Activated")
end

frames(10)
click(gui.LobbyHud.TopRight.Settings) -- open Settings with the gear
frames(22)
click(gui.Settings.Group.Panel.Header.AudioTab)
frames(20)
click(gui.Settings.Group.Panel.Header.Close)
frames(18)
MM.open("Shop")
frames(22)
click(gui.Shop.Group.Panel.CosmeticsTab)
frames(20)
click(gui.Shop.Group.Panel.Products.BlossomAura.Buy, 6)
frames(24)
click(gui.Shop.Group.Panel.Header.Close)
frames(18)
print("frames:", n)
return nil
