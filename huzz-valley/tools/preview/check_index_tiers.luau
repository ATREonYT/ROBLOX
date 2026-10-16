-- Drives the Index and Tiers screens through their real buttons and checks the saved profile / client state.
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1; print("ok   " .. name) else failed += 1; print("FAIL " .. name) end
end
local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local profile = DataService.get(player)
DataService.update(player, function(d) d.Characters.Ren = os.time() + 5 end) -- a second owned companion, newer than Aiko
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local State, MM = require(UI.State), require(UI.ModalManager)
local gui = player.PlayerGui:WaitForChild("HuzzUI")
local function settle() task.wait(0.25) end
local function click(b) __fireOn(b, "Activated"); settle() end

check("Index opens", MM.open("Index") == true and MM.current() == "Index")
local panel = gui.Index.Group.Panel
local grid, action = panel.Grid, panel.EquipAction
local function cardIds()
	local list = {}
	for _, ch in grid:GetChildren() do if ch:IsA("TextButton") and ch.Visible then table.insert(list, { ch.Name, ch.Position.Y.Offset * 1000 + ch.Position.X.Offset }) end end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	local names = {}
	for _, v in list do table.insert(names, v[1]) end
	return table.concat(names, ",")
end
local function label(b) return b.Content.Label.Text end
check("all characters, name A-Z", cardIds() == "Aiko,Hina,Ren,Sora")
check("Aiko selected and equipped: UNEQUIP", label(action) == "UNEQUIP" and panel.NameRow:FindFirstChild("Name").Text == "Aiko")
click(action)
check("UNEQUIP saves no companion", profile.Data.Equipped == "" and State.data.Equipped == "" and label(action) == "EQUIP")
click(action)
check("EQUIP saves Aiko again", profile.Data.Equipped == "Aiko" and label(action) == "UNEQUIP")
click(grid.Ren)
check("selecting Ren changes the preview only", panel.NameRow:FindFirstChild("Name").Text == "Ren" and label(action) == "EQUIP" and profile.Data.Equipped == "Aiko")
check("selected card wears the yellow rim", grid.Ren.Rim.Thickness == 3 and grid.Aiko.Rim.Thickness == 1)
click(action)
check("EQUIP Ren saves Ren", profile.Data.Equipped == "Ren" and grid.Ren.Status.Text.Text == "Equipped" and grid.Aiko.Status.Text.Text == "Owned")
click(panel.Favourite)
check("preview star favourites Ren", profile.Data.FavChars.Ren == true and State.data.FavChars.Ren == true)
click(grid.Aiko.Favourite)
check("card star favourites Aiko", profile.Data.FavChars.Aiko == true)
check("Ren still selected after the card star", panel.NameRow:FindFirstChild("Name").Text == "Ren")
click(panel.FavouritesTab)
check("Favourites tab shows the two favourites", cardIds() == "Aiko,Ren")
click(grid.Aiko.Favourite)
check("unfavourite removes it from Favourites", profile.Data.FavChars.Aiko == nil and cardIds() == "Ren")
click(panel.OwnedTab)
check("Owned tab shows owned only", cardIds() == "Aiko,Ren")
local box = panel.Search.Box
box.Text = "REN"; __fireOn(box, "Prop_Text"); settle()
check("search is case-insensitive and combines with the tab", cardIds() == "Ren" and panel.Search.Placeholder.Visible == false)
box.Text = "sora"; __fireOn(box, "Prop_Text"); settle()
check("search + Owned with no match shows the empty message", cardIds() == "" and panel.Empty.Visible == true)
click(panel.Empty.ClearFilters)
check("Clear filters resets search, tier and tab", cardIds() == "Aiko,Hina,Ren,Sora" and box.Text == "" and panel.Empty.Visible == false)
click(panel.TierFilter)
check("tier dropdown opens over the cards", panel.DropdownMenu.Visible == true and panel.DropdownMenu.ZIndex > grid.ZIndex)
click(panel.DropdownCatcher)
check("outside click closes it", panel.DropdownMenu.Visible == false)
click(panel.TierFilter)
click(panel.DropdownMenu.Stacy)
check("tier filter STACY shows Hina", cardIds() == "Hina" and label(panel.TierFilter) == "STACY" and panel.DropdownMenu.Visible == false)
click(panel.TierFilter); click(panel.DropdownMenu.All)
click(panel.Sort); click(panel.DropdownMenu.TierHigh)
check("sort tier high-low", cardIds() == "Hina,Aiko,Ren,Sora" and label(panel.Sort) == "Sort: Tier high")
click(panel.Sort); click(panel.DropdownMenu.Newest)
check("sort newest: owned newest first, unowned last by name", cardIds() == "Ren,Aiko,Hina,Sora")
click(panel.Sort); click(panel.DropdownMenu.NameZA)
check("sort name Z-A", cardIds() == "Sora,Ren,Hina,Aiko")
click(grid.Hina)
check("locked Hina: LOCKED and disabled", label(action) == "LOCKED" and action:GetAttribute("Disabled") == true and panel.StatusRow.Text.Text == "Locked")
check("locked card shows the silhouette, not coloured art", grid.Hina.Body.Art.Picture:GetAttribute("PreviewFile") == "assets/art/char-locked.png")
click(action)
check("locked can't be equipped", profile.Data.Equipped == "Ren")

-- Tiers
check("Tiers opens", MM.open("Tiers") == true and MM.current() == "Tiers")
local tp = gui.Tiers.Group.Panel
local function count(row) return row.Count.Have.Text .. row.Count.Rest.Text end
check("tier rows highest first", tp.TrueEve.Position.Y.Offset < tp.Stacy.Position.Y.Offset and tp.Stacy.Position.Y.Offset < tp.Sub1.Position.Y.Offset)
check("counts from the catalogue: MTB 1/1, Sub5 1/1, Sub3 0/1, HTB 0/0", count(tp.MTB) == "1 / 1" and count(tp.Sub5) == "1 / 1" and count(tp.Sub3) == "0 / 1" and count(tp.HTB) == "0 / 0")
check("opens on the highest collected tier (MTB)", tp.TierPanel.TierName.Text == "MTB" and tp.TierPanel.Label.Text == "Highest Collected")
click(tp.Sub5)
check("selecting SUB5 updates the panel", tp.TierPanel.TierName.Text == "SUB 5" and tp.TierPanel.Label.Text == "Selected Tier")
click(tp.ViewInIndex)
check("VIEW IN INDEX opens the Index filtered to SUB 5", MM.current() == "Index" and cardIds() == "Ren" and label(panel.TierFilter) == "SUB 5")
DataService.update(player, function(d) d.Characters.Sora = os.time() end); settle()
MM.open("Tiers"); settle()
check("tier counts update when ownership changes", count(tp.Sub3) == "1 / 1")
-- Every tier row shows its crown (each crown picture exists under the name the Tiers page asks for).
local crownsOk = true
for _, row in tp:GetDescendants() do
	if row.Name == "Crown" and row:IsA("ImageLabel") then
		local art = row:GetAttribute("Art")
		if not game.ReplicatedStorage.Shared.Images.Art:FindFirstChild(art) then crownsOk = false; print("missing crown " .. tostring(art)) end
	end
end
check("every tier crown has a picture", crownsOk)
print(string.format("index checks: %d ok, %d failed", ok, failed))
return gui
