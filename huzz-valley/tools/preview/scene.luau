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
__copyStarterGui(player)
if cfg.SCALE then workspace:SetAttribute("UIPreviewScale", tonumber(cfg.SCALE)) end
if cfg.ROUND then workspace:SetAttribute("NextRoundAt", workspace:GetServerTimeNow() + tonumber(cfg.ROUND) + 0.5) end
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
DataService.update(player, function(d)
	d.Coins = tonumber(cfg.COINS) or 12450
	d.Aura = tonumber(cfg.GEMS) or 320
	for key in string.gmatch(cfg.OWN or "", "[^,]+") do d.Cosmetics[key] = true end
end)
-- SPINS=n, FREEIN=seconds to the free spin, PITY=spins since a Legendary, BOOST=seconds of x2 coins: the Spin the
-- Wheel's saved state (SCREEN="SpinWheel").
if cfg.SPINS then
	DataService.update(player, function(d)
		d.Spins = tonumber(cfg.SPINS)
		d.FreeSpinAt = os.time() + (tonumber(cfg.FREEIN) or 0)
		d.SpinPity = tonumber(cfg.PITY) or 0
		d.Boosts = { Coins = os.time() + (tonumber(cfg.BOOST) or 0), Aura = 0 }
	end)
end
if cfg.PASSES then
	local owned = {}
	for key in string.gmatch(cfg.PASSES, "[^,]+") do owned[key] = true end
	DataService.setExtra(player, "Passes", owned)
end
for k, v in cfg.SETTINGS or {} do
	DataService.update(player, function(d) d.Settings[k] = v end)
end
-- VOTE="mapA,mapB,countA,countB,myVote": a map vote in progress (page 15)
if cfg.VOTE then
	local v = string.split(cfg.VOTE, ",")
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	round:SetAttribute("VoteA", v[1]); round:SetAttribute("VoteB", v[2])
	round:SetAttribute("VoteCountA", tonumber(v[3])); round:SetAttribute("VoteCountB", tonumber(v[4]))
	round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 8.5)
	if v[5] then player:SetAttribute("HuzzVote", v[5]) end
end
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
-- NEXTMAP=true (with VOTE=...): the vote running, its window closed: the NEXT MAP panel at the top left.
if cfg.NEXTMAP then
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	round:SetAttribute("Stage", "Voting")
	task.wait(0.1)
	MM.close()
	task.wait(0.1)
	require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.NextMap).refresh()
end
-- POWERS="Runner"|"Catcher": a round running, slot 1 used up, slot 2 ready.
if cfg.POWERS then
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	round:SetAttribute("Stage", "Running")
	player:SetAttribute("HuzzRole", cfg.POWERS)
	player:SetAttribute("HuzzStatus", if cfg.POWERS == "Runner" then "Active" else "")
	player:SetAttribute("PowerReady1", -1) -- used up this round
	player:SetAttribute("PowerReady2", 0)
	require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.PowerBar).refresh()
end
-- HERO=true: the picked runner's Chicken or Hero choice (5 seconds left), with the power tiles under it.
-- WHEEL=true: the G dance wheel open, with two favourites and one dance playing.
if cfg.WHEEL then
	local State = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.State)
	State.data.FavDances = { SwingTime = true, Robot = true }
	State.data.Dances.SwingTime, State.data.Dances.Robot = true, true
	require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.DanceWheel).setOpen(true)
end
if cfg.HERO then
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	local Config = require(game.ReplicatedStorage.Shared.Config.Round)
	local now = workspace:GetServerTimeNow()
	round:SetAttribute("Stage", "Picking")
	round:SetAttribute("Round", 1)
	round:SetAttribute("GirlName", "Sakura Hoshino")
	round:SetAttribute("PickId", player.UserId)
	round:SetAttribute("PickAt", now - Config.Pick.Roulette - (Config.Pick.ChooseTime - 5))
	round:SetAttribute("EndsAt", now + 5)
	player:SetAttribute("HuzzRole", "Runner")
	player:SetAttribute("HuzzStatus", "Active")
	player:SetAttribute("HuzzFrozen", true)
	player:SetAttribute("PowerReady1", 0)
	player:SetAttribute("PowerReady2", 0)
	local Screens = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens
	require(Screens.HeroChoice).refresh()
	require(Screens.PowerBar).refresh()
end
-- ROUNDHUD="Hero"|"Chicken"|"Catcher": a round running with the in-round HUD (timer, role, prize card), a banner.
if cfg.ROUNDHUD then
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	round:SetAttribute("Stage", "Running")
	round:SetAttribute("Round", 2)
	round:SetAttribute("Streak", 1)
	round:SetAttribute("Crossings", 3)
	round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 23.5)
	round:SetAttribute("GirlName", "Sakura Hoshino")
	round:SetAttribute("GirlRarity", "Legendary")
	player:SetAttribute("HuzzRole", if cfg.ROUNDHUD == "Catcher" then "Catcher" else "Runner")
	player:SetAttribute("HuzzStatus", if cfg.ROUNDHUD == "Catcher" then "" else "Active")
	player:SetAttribute("HuzzHero", cfg.ROUNDHUD == "Hero")
	player:SetAttribute("PowerReady1", 0)
	player:SetAttribute("PowerReady2", 0)
	local Hud = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.RoundHud)
	Hud.start()
	Hud.refresh()
	require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.PowerBar).refresh()
	-- (one ScreenGui is exported: the round HUD's root goes into the main UI for the picture)
	pg:WaitForChild("HuzzRoundHud").Root.Parent = pg:WaitForChild("HuzzUI")
	round:SetAttribute("Stage", "Running")
	__fireOn(round, "OnClientEvent", "Announce", { text = "Messi is safe", color = Color3.fromRGB(110, 236, 140) })
	Hud.refresh()
end
-- ROLL=<seconds into the spin>: the girl roller, with a made-up strip of the placeholder names.
if cfg.ROLL then
	local rarities = { "Common", "Common", "Uncommon", "Common", "Rare", "Common", "Uncommon", "Epic", "Common", "Legendary" }
	local cells = {}
	for i = 1, 30 do
		local r = rarities[(i * 7) % #rarities + 1]
		cells[i] = { name = `{r} Girl {(i % 4) + 1}`, rarity = r }
	end
	cells[26] = { name = "Sakura Hoshino", rarity = "Epic" }
	cells[27] = { name = "Mythic Girl 1", rarity = "Mythic" }
	cells[25] = { name = "Secret Girl 1", rarity = "Secret" }
	local odds = { { name = "Common", chance = 50 }, { name = "Uncommon", chance = 25 }, { name = "Rare", chance = 13 },
		{ name = "Epic", chance = 7 }, { name = "Legendary", chance = 3.5 }, { name = "Mythic", chance = 1.2 }, { name = "Secret", chance = 0.3 } }
	local Roll = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.GirlRoll)
	local start = workspace:GetServerTimeNow() - tonumber(cfg.ROLL)
	Roll.show({ cells = cells, stop = 26, start = start, spin = 5.5, odds = odds })
	for _ = 1, 20 do __stepTweens(0.05) end
	Roll.render(workspace:GetServerTimeNow())
end
if cfg.SCREEN and cfg.SCREEN ~= "Hud" then
	assert(MM.open(cfg.SCREEN, cfg.TAB), "no screen " .. tostring(cfg.SCREEN))
end
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.6) -- staggered slide-ins start on real-time delays; let them start, then finish them
for _ = 1, 40 do __stepTweens(0.05) end
-- Shine streaks (UI/Effects) pause off the edge, as they rest most of the time; SHINE=<offset> freezes them mid-sweep.
for _, d in pg:GetDescendants() do
	if d.Name == "Band" and d:IsA("UIGradient") then d.Offset = Vector2.new(tonumber(cfg.SHINE) or -1, 0) end
end
task.wait(0.1)
return pg:WaitForChild("HuzzUI")
