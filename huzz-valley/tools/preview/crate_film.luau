-- Crate opening film snippet (crate_film.sh): Shop > CRATES, OPEN on a crate whose pity counter is full (so the film
-- shows the Legendary moment, honestly: "Legendary guaranteed on your next open!"), the whole opening at 30 fps, then
-- OPEN AGAIN with a tap to skip. One UI frame per step to __framesDir (frame_0001.json ...), drawn by shoot_frames.js.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
DataService.update(player, function(d) d.Coins, d.Aura = 1250, 160; d.Pity.Starter = 29 end)
workspace:SetAttribute("UIPreviewScale", 1.5)
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
		__fireOn(RunService, "RenderStepped", 1 / 30)
		n += 1
		__exportUI(gui, string.format("%s/frame_%04d.json", __framesDir, n))
	end
end
local mouse = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }
local function click(btn, hold)
	__fireOn(btn, "MouseEnter")
	frames(4)
	__fireOn(btn, "InputBegan", mouse)
	frames(hold or 3)
	__fireOn(btn, "InputEnded", mouse)
	__fireOn(btn, "Activated")
end

MM.open("Shop", "Crates")
frames(30)
click(gui.Shop:FindFirstChild("Products", true).Starter.Open)
frames(262) -- the whole opening: shake, pop, spin, land, the Legendary, the buttons
click(gui.CrateOpen.Group.Bottom.OpenAgain)
frames(40)
__fireOn(gui.CrateOpen.Group.Skip, "Activated") -- tap to skip
frames(45)
print("frames:", n)
return nil
