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
	if g and g:IsA("GuiObject") then g.Visible = true end
end
-- Moving effects (UI/Effects) are saved at rest: shine streaks hidden off the edge, rays hidden and unturned, so
-- they never get in the way of clicking things in Studio. The game starts them again.
for _, d in player.PlayerGui.HuzzUI:GetDescendants() do
	if d.Name == "Shine" and d:IsA("Frame") then
		d.Visible = false
		local band = d:FindFirstChild("Band")
		if band then band.Offset = Vector2.new(-1, 0) end
	elseif d:IsA("ImageLabel") and d:GetAttribute("Art") == "LightRays" then
		d.Visible, d.Rotation, d.ImageTransparency = false, 0, 1
	elseif d.Name == "Icon" and d.Parent and d.Parent.Name == "Spin" and d:IsA("GuiObject") then
		d.Rotation = 0 -- (the HUD wheel icon spins while a free spin waits)
	elseif d.Name == "Breathe" and d:IsA("UIScale") then
		d.Scale = 1
	end
end
-- The stand-in glyphs UI/ImageLoader puts on pictures it can't draw (no EditableImage in Lune) are never saved: in
-- the game they are made again only where a picture really can't be drawn.
local stand: { Instance } = {}
for _, d in player.PlayerGui.HuzzUI:GetDescendants() do
	if d:GetAttribute("NoPicture") then table.insert(stand, d) end
end
for _, d in stand do d:Destroy() end
return nil
