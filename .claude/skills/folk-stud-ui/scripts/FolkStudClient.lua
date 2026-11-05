-- FolkStudClient (LocalScript in StarterPlayerScripts): runs the rail and the windows built into StarterGui. The windows start closed.
local M = require(game:GetService("ReplicatedStorage"):WaitForChild("FolkStudUI"))
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local shop, quests, rebirth = pg:WaitForChild("FolkShop"), pg:WaitForChild("FolkQuests"), pg:WaitForChild("FolkRebirth")
local backpack, index, settings = pg:WaitForChild("FolkBackpack"), pg:WaitForChild("FolkIndex"), pg:WaitForChild("FolkSettings")
M.live(shop, { buy = function(offer) end, gift = function(offer) end })   -- connect to MarketplaceService, and grant on the server
M.live(quests, {
	go = function(id) M.show(quests, false) end,   -- then point the player at the quest
	claim = function(id) M.setQuest(quests, id, nil, nil, "done") end,   -- sample only: ask the server, which checks progress and pays, then show its answer
})
M.live(rebirth, { rebirth = function() end, skip = function() end, gift = function() end })
M.live(backpack, {
	pick = function(id) M.selectItem(backpack, id) end,
	use = function(id) M.equipItem(backpack, id) end,   -- sample only: ask the server, then show its answer. Open and Use items need the game's own code
})
M.live(index, {
	pick = function(id) M.selectItem(index, id) end,
	claim = function() end,   -- ask the server, which checks and pays
})
M.settingsLive(settings, {
	change = function(id, value) end,   -- apply it, and save it through the server
	press = function(id) end,
})
M.hudLive(pg:WaitForChild("FolkHud"), { FolkShop = shop, FolkQuests = quests, FolkRebirth = rebirth, FolkBackpack = backpack, FolkIndex = index, FolkSettings = settings })
