-- Preview snippet: starts the server and the client UI, opens one screen, returns the ScreenGui for export.
-- Reads these globals (set by run.sh through env.luau): SCREEN, TAB, SCALE, OWN, COINS, GEMS.
local cfg = __previewConfig or {}
local Players = game:GetService("Players")
local player = Instance.new("Player")
player.Name = "Tester"
player.UserId = 1
player.Parent = Players
Players.LocalPlayer = player
local pg = Instance.new("PlayerGui"); pg.Parent = player
if cfg.SCALE then workspace:SetAttribute("UIPreviewScale", tonumber(cfg.SCALE)) end
if cfg.ROUND then workspace:SetAttribute("NextRoundAt", workspace:GetServerTimeNow() + tonumber(cfg.ROUND) + 0.5) end
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
DataService.update(player, function(d)
	d.Coins = tonumber(cfg.COINS) or 12450
	d.Gems = tonumber(cfg.GEMS) or 320
	for key in string.gmatch(cfg.OWN or "", "[^,]+") do d.Cosmetics[key] = true end
end)
if cfg.PASSES then
	local owned = {}
	for key in string.gmatch(cfg.PASSES, "[^,]+") do owned[key] = true end
	DataService.setExtra(player, "Passes", owned)
end
for k, v in cfg.SETTINGS or {} do
	DataService.update(player, function(d) d.Settings[k] = v end)
end
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
if cfg.SCREEN and cfg.SCREEN ~= "Hud" then
	assert(MM.open(cfg.SCREEN, cfg.TAB), "no screen " .. tostring(cfg.SCREEN))
end
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.6) -- staggered slide-ins start on real-time delays; let them start, then finish them
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.1)
return pg:WaitForChild("HuzzUI")
