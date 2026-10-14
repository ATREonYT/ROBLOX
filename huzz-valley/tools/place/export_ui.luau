-- Builds the UI as a new player first sees it (no window open), so harness.luau can save it into StarterGui
-- (HUZZ_UI_OUT). Run by build_place.sh with HUZZ_FRESH=1, so it builds from nothing rather than from the old copy.
local Players = game:GetService("Players")
local player = Instance.new("Player")
player.Name = "Player"
player.UserId = 1
player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.1)
-- Each window is hidden twice (the window and its inner Group, for the open animation). Leave only the window's own
-- Visible to tick in Studio; the game hides both again when it starts.
for _, w in player.PlayerGui.HuzzUI:GetChildren() do
	local g = w:FindFirstChild("Group")
	if g and g:IsA("CanvasGroup") then g.Visible = true end
end
return nil
