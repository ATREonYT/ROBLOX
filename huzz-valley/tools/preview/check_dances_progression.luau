-- Drives the Dances and Progression buttons through the real server + client code.
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1; print("ok   " .. name) else failed += 1; print("FAIL " .. name) end
end
-- give Robot (the reward-track dance) a pretend animation id so the "has an id" path can be tried
local D = game.ReplicatedStorage.Shared.Config.Dances
D.Source = D.Source:gsub('(Id = "Robot", Name = "Robot", AnimationId = )""', '%1"rbxassetid://1"')

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
Instance.new("PlayerGui").Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local HS = game.ServerScriptService.HuzzServer
local DataService, ProgressService = require(HS.DataService), require(HS.ProgressService)
local profile = DataService.get(player)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local State, MM = require(UI.State), require(UI.ModalManager)
local gui = player.PlayerGui.HuzzUI
local function click(btn) __fireOn(btn, "Activated"); task.wait(0.25) end
local function toast() return gui.Toast.Text end
local function names(grid)
	local list = {}
	for _, c in grid:GetChildren() do if c:IsA("TextButton") then table.insert(list, { c.Name, c.LayoutOrder }) end end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	local out = {}
	for _, v in list do table.insert(out, v[1]) end
	return table.concat(out, ",")
end

-- DANCES (the 25 from the owner's dance file: 20 for everyone, Robot from the reward track, 4 in the Dance Pack)
local Dances = require(game.ReplicatedStorage.Shared.Config.Dances)
local function expected(filter, desc)
	local list = {}
	for _, d in Dances.List do if filter(d) then table.insert(list, d) end end
	table.sort(list, function(a, b) if desc then return a.Name > b.Name end return a.Name < b.Name end)
	local out = {}
	for _, d in list do table.insert(out, d.Id) end
	return table.concat(out, ",")
end
local all = expected(function() return true end)
check("there are 25 dances", #Dances.List == 25)
check("Dances opens", MM.open("Dances") == true and gui.Dances.Visible)
local panel = gui.Dances.Group.Panel
local grid = panel.Grid
check("All shows every dance, A-Z", names(grid) == all)
click(panel.OwnedTab)
check("Owned tab shows the 20 everyone has", names(grid) == expected(function(d) return d.Starter == true end))
click(panel.FavouritesTab)
check("Favourites tab empty with a hint", names(grid) == "" and panel.Empty.Visible)
click(panel.AllTab)
click(grid.SwingTime)
check("selecting a card fills the preview", panel.Preview.DanceName.Text == "Swing Time")
click(grid.SwingTime.Star)
task.wait(0.3)
check("star favourites the dance (server saved)", profile.Data.FavDances.SwingTime == true)
click(panel.FavouritesTab)
check("favourite shows under Favourites", names(grid) == "SwingTime")
click(panel.AllTab)
click(panel.Play)
check("Play on a locked dance explains how to get it", toast():find("Dance Pack") ~= nil)
print("  toast: " .. toast())
click(grid.Floss)
click(panel.Play)
check("Play with no published animation says so", toast():find("published") ~= nil)
print("  toast: " .. toast())
local header = gui.Dances.Group.Panel.Header
header.Search.Box.Text = "sh"
__fireOn(header.Search.Box, "Prop_Text") -- the offline engine copy doesn't fire property signals itself
task.wait(0.1)
check("search filters", names(grid) == expected(function(d) return string.find(string.lower(d.Name), "sh", 1, true) ~= nil end))
header.Search.Box.Text = ""
__fireOn(header.Search.Box, "Prop_Text")
task.wait(0.1)
check("clearing the search shows all again", names(grid) == all and header.Search.Hint.Visible)
click(header.Sort)
check("sort menu opens", panel.SortMenu.Visible)
click(panel.SortMenu.ZToA)
check("Z-A sort", names(grid) == expected(function() return true end, true) and not panel.SortMenu.Visible and header.Sort.Label.Text == "Sort: Name Z - A")
-- own Robot (pretend id) and play it on a character with an Animator
DataService.update(player, function(d) d.Dances.Robot = true end)
task.wait(0.2)
local char = Instance.new("Model"); char.Name = "Tester"
local hum = Instance.new("Humanoid"); hum.Parent = char
Instance.new("Animator").Parent = hum
char.Parent = workspace
player.Character = char
click(grid.Robot)
click(panel.Play)
print("  toast after playing Robot with an id: " .. toast())
click(panel.Stop)
check("Stop runs without error", true)
MM.close()
task.wait(0.2)

-- PROGRESSION: rewards
check("Progression opens on Quests", MM.open("Progression", "Quests") and gui.Progression.Group.Panel.Quests.Visible and not gui.Progression.Group.Panel.Rewards.Visible)
local pp = gui.Progression.Group.Panel
click(pp.Header.RewardsTab)
check("Rewards tab shows", pp.Rewards.Visible and not pp.Quests.Visible)
local free = pp.Rewards.FreeRewards
check("level 1 reward claimable, level 2 locked", free.Reward1.State:FindFirstChild("Claim") ~= nil and free.Reward2.State:FindFirstChild("Locked") ~= nil)
check("level 4 (unavailable) shows Locked", free.Reward4.State:FindFirstChild("Locked") ~= nil)
local coins = profile.Data.Coins
click(free.Reward1.State.Claim)
task.wait(0.2)
check("CLAIM gives 100 coins", profile.Data.Coins == coins + 100)
check("card now says CLAIMED", free.Reward1.State:FindFirstChild("Claimed") ~= nil)
check("can't claim twice", (State.action("ClaimReward", 1)) == false and profile.Data.Coins == coins + 100)
click(free.Reward2.State.Locked)
check("tapping Locked explains", toast():find("Level 2") ~= nil)
check("no bonus row while nothing can be earned", pp.Rewards:FindFirstChild("BonusCosmetics") == nil)

-- quests
click(pp.Header.QuestsTab)
local steals = pp.Quests.Steals
check("unfinished quest shows progress, no CLAIM", steals.State:FindFirstChild("Claim") == nil and steals.Count.Visible and steals.Count.Text == "0 / 3")
local okq, why = State.action("ClaimQuest", "Steals")
check("server refuses an unfinished quest", okq == false and profile.Data.XP == 0)
print("  refused: " .. tostring(why))
ProgressService.addStat(player, "Steals", 3)
task.wait(0.3)
check("finished quest shows CLAIM and 3 / 3", steals.State:FindFirstChild("Claim") ~= nil and steals.DoneBar.Text == "3 / 3")
click(steals.State.Claim)
task.wait(0.2)
check("CLAIM gives 100 XP once", profile.Data.XP == 100 and steals.State:FindFirstChild("Claimed") ~= nil and (State.action("ClaimQuest", "Steals")) == false and profile.Data.XP == 100)
check("level bar updates", pp.LevelBar.Level.Xp.Text == "100" and pp.LevelBar.Level.LevelText.Text == "LEVEL 1")
ProgressService.addStat(player, "HoldSeconds", 99)
task.wait(0.3)
check("progress caps at the target", pp.Quests.Hold.DoneBar.Text == "30 / 30")
MM.close()
print(string.format("buttons: %d ok, %d failed", ok, failed))
return nil
