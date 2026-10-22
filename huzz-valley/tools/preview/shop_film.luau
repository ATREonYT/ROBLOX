-- Shop motion film snippet (shop_film.sh; owner, Oct 20 20:34: "animate the ui more so it looks more intresting",
-- "make sure the ui has nice animations, make sure it has logical, smooth operations"): the Shop opens (cards pop in one
-- after another, the crates rock, the featured crate shines and its OPEN breathes), OPEN on the Candy Crate (the press
-- squish, its panel slides in with every chance), a tap beside it (it slides out), DANCES, a dance's panel. One UI
-- frame per step to __framesDir (frame_0001.json ...), drawn by shoot_frames.js at 30 fps.
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
DataService.update(player, function(d) d.Coins, d.Aura = 1250, 160; d.Pity.Sweets = 31 end)
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

MM.open("Shop", "Halloween")
frames(75) -- the pop-in, the rocking crates, the featured crate's shine and breathing OPEN
local body = gui.Shop:FindFirstChild("Products", true)
local side = gui.Shop:FindFirstChild("Side", true)
click(body.CardSweets.Open)
frames(50) -- the panel slides in: every chance, the pity, coins or Aura
__fireOn(side.Shade, "Activated")
frames(20)
click(gui.Shop:FindFirstChild("DancesTab", true))
frames(25)
__fireOn(body.DanceZombieWalk.Tap, "Activated")
frames(45)
print("frames:", n)
return nil
