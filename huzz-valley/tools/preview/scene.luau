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
	d.XP = tonumber(cfg.XP) or d.XP -- (the winner page's level bar)
	-- the daily quests window: the spin quest done (CLAIM), the first daily one half way
	if cfg.SCREEN == "DailyQuests" then
		local DailyRules = require(game.ReplicatedStorage.Shared.DailyRules)
		local DailyQuests = require(game.ReplicatedStorage.Shared.Config.DailyQuests)
		local now = workspace:GetServerTimeNow()
		d.Daily = DailyRules.roll(nil, now)
		local s, d1 = DailyQuests.get(d.Daily.Q.S.Id), DailyQuests.get(d.Daily.Q.D1.Id)
		DailyRules.add(d.Daily, s.Stat, s.Target, now)
		DailyRules.add(d.Daily, d1.Stat, math.max(1, d1.Target // 2), now)
	end
	-- DUPES="id=n,...", PRESTIGE="id=n,...": spare copies and prestige levels of girls (the Index's PRESTIGE)
	for id, n in string.gmatch(cfg.DUPES or "", "([^,=]+)=(%d+)") do d.Dupes[id] = tonumber(n) end
	for id, n in string.gmatch(cfg.PRESTIGE or "", "([^,=]+)=(%d+)") do d.Prestige[id] = tonumber(n) end
end)
-- CRATEPITY=n: opens since the Starter Crate's Legendary (29 = the next open is one).
if cfg.CRATEPITY then DataService.update(player, function(d) d.Pity.Starter = tonumber(cfg.CRATEPITY) end) end
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
if cfg.FRIEND then player:SetAttribute("HuzzFriendBoost", true) end -- (a friend in the server: "+10% COINS")
if cfg.PASSES then
	local owned = {}
	for key in string.gmatch(cfg.PASSES, "[^,]+") do owned[key] = true end
	DataService.setExtra(player, "Passes", owned)
end
for k, v in cfg.SETTINGS or {} do
	DataService.update(player, function(d) d.Settings[k] = v end)
end
-- GIRLS=true: won girls with long names, one of each rarity (the overflow check: badges and names must fit);
-- the first two are owned, the first equipped. SELECT=<id> picks one in the Index after it opens.
-- GIRL="<name>" swaps the made-up prize / results girl for a long name.
local TEST_GIRLS = {
	{ "t_kurumi", "Kurumi Tokisaki", "Legendary" }, { "t_unc", "Uncommon Girl 10", "Uncommon" }, { "t_akane", "Akane", "Common" },
	{ "t_mitsuri", "Mitsuri Kanroji", "Secret" }, { "t_miku", "Hatsune Miku", "Mythic" }, { "t_zero", "Zero Two", "Epic" }, { "t_rem", "Rem", "Rare" },
}
if cfg.GIRLS then
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("HuzzGirls") or Instance.new("Folder")
	folder.Name = "HuzzGirls"
	folder.Parent = RS
	for i, g in TEST_GIRLS do
		local m = Instance.new("Model"); m.Name = "TestGirl" .. i
		local head = Instance.new("Part"); head.Name = "Head"; head.Parent = m
		m:SetAttribute("Id", g[1]); m:SetAttribute("Name", g[2]); m:SetAttribute("Rarity", g[3]); m.Parent = folder
	end
	require(RS.Shared.Config.Characters).addGirls(folder)
	DataService.update(player, function(d)
		d.Characters.t_kurumi, d.Characters.t_unc = os.time(), os.time()
		d.Equipped = "t_kurumi"
	end)
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
-- POWERS="Runner"|"Catcher": the ability cards and dash bar as in the owner's pictures (design/owner-oct19):
-- Runner = pic c (this round's Shield, waiting on the line: WAIT FOR ROUND, DASH PAUSED); Catcher = pic b (Bear Trap
-- and Slow Wave ready, CATCH READY). POWERSTATE="Stunned" (a catcher 1 s into a dive's stun), "Carrying" (a runner
-- with the girl: Speed Boost's card too, dash recharging), "Cooldown" (Q charging, the knife charging).
if cfg.POWERS then
	local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
	_G.__serverClock = function() return 1000 end -- (a still clock: the harness's own one jumps about)
	local now = workspace:GetServerTimeNow()
	local runner = cfg.POWERS == "Runner"
	round:SetAttribute("Stage", "Running")
	player:SetAttribute("HuzzRole", cfg.POWERS)
	player:SetAttribute("HuzzStatus", if runner then "Active" else "")
	player:SetAttribute("PowerName1", if runner then (cfg.ABILITY or "Shield") else "BearTrap")
	player:SetAttribute("PowerName2", if runner then "SpeedBoost" else "SlowWave")
	player:SetAttribute("PowerReady1", 0)
	player:SetAttribute("PowerReady2", 0)
	player:SetAttribute("HuzzFrozen", runner and cfg.POWERSTATE == nil)
	if cfg.POWERSTATE == "Stunned" then
		player:SetAttribute("DashReady", now + 1.6)
		player:SetAttribute("StunnedFrom", now - 1)
		player:SetAttribute("StunnedUntil", now + 1)
	elseif cfg.POWERSTATE == "Carrying" then
		round:SetAttribute("HolderId", player.UserId)
		player:SetAttribute("DashReady", now + 1)
	elseif cfg.POWERSTATE == "Cooldown" then
		player:SetAttribute("PowerReady1", now + 4)
		player:SetAttribute("KnifeReady", now + 0.4)
	end
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
	round:SetAttribute("GirlName", cfg.GIRL or "Sakura Hoshino")
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
	__fireOn(round, "OnClientEvent", "Announce", { text = cfg.MESSAGE or "Messi is safe", color = Color3.fromRGB(110, 236, 140) })
	Hud.refresh()
	-- COUNT=<seconds left>: the 3-2-1 instead (e.g. 2.6 = "3" settled after its pop), with the line-up news
	if cfg.COUNT then
		__fireOn(round, "OnClientEvent", "Announce", { text = "Messi chose CHICKEN. Everyone runs!", color = Color3.new(1, 1, 1) })
		round:SetAttribute("Stage", "Countdown")
		round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + tonumber(cfg.COUNT))
		Hud.refresh()
	end
end
-- ROLL=<seconds into the spin>: the girl roller, with a made-up strip of the placeholder names.
if cfg.ROLL then
	local rarities = { "Common", "Common", "Uncommon", "Common", "Rare", "Common", "Uncommon", "Epic", "Common", "Legendary" }
	local cells = {}
	for i = 1, 30 do
		local r = rarities[(i * 7) % #rarities + 1]
		cells[i] = { name = if cfg.GIRL then `{r} Girl {(i % 4) + 10}` else `{r} Girl {(i % 4) + 1}`, rarity = r }
	end
	cells[26] = { name = cfg.GIRL or "Sakura Hoshino", rarity = "Epic" }
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
-- RESULTS="Win"|"Lose"|"Bot": the results window filled with a made-up game.
if cfg.RESULTS then
	require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Screens.Results).fill({
		outcome = cfg.RESULTS, girl = cfg.GIRL or "Zero Two", rarity = "Mythic", gotGirl = cfg.RESULTS == "Win",
		crossed = 3, catches = 0, rescues = 2, heroes = 1, coins = 50, aura = if cfg.RESULTS == "Win" then 3 else 0,
		-- the winner page (owner's picture a): everyone's numbers, the winning side, your XP
		team = if cfg.RESULTS == "Win" then (cfg.TEAM or "Runners") else "Catchers", bot = cfg.RESULTS == "Bot" or nil,
		xp = if cfg.RESULTS == "Win" then 105 else 65, heroPaid = 0, level = if cfg.RESULTS == "Win" then 4 else nil,
		board = {
			{ user = 1, name = "emyu", crossed = 2, catches = 3, rescues = 0, heroes = 0, won = true },
			{ user = 2, name = "Enooo", crossed = 0, catches = 11, rescues = 1, heroes = 0, won = true },
			{ user = 3, name = "Aloninja", crossed = 3, catches = 1, rescues = 2, heroes = 1, won = false },
			{ user = 4, name = "tailsteam62", crossed = 4, catches = 1, rescues = 0, heroes = 0, won = false },
		},
	})
	workspace:SetAttribute("NextRoundAt", workspace:GetServerTimeNow() + 12)
end
if cfg.SCREEN and cfg.SCREEN ~= "Hud" then
	assert(MM.open(cfg.SCREEN, cfg.TAB), "no screen " .. tostring(cfg.SCREEN))
end
if cfg.SELECT then
	task.wait(0.2)
	local cardButton = pg:WaitForChild("HuzzUI"):FindFirstChild(cfg.SELECT, true)
	assert(cardButton, "no card " .. tostring(cfg.SELECT))
	__fireOn(cardButton, "Activated")
	task.wait(0.2)
end
-- CRATE_T=<seconds>: the crate opening (SCREEN="CrateOpen", TAB=crate id) that far into its timeline (frames of 1/30 s).
if cfg.CRATE_T then
	for _ = 1, math.round(tonumber(cfg.CRATE_T) * 30) do __fireOn(game:GetService("RunService"), "RenderStepped", 1 / 30) end
end
for _ = 1, 40 do __stepTweens(0.05) end
task.wait(0.6) -- staggered slide-ins start on real-time delays; let them start, then finish them
for _ = 1, 40 do __stepTweens(0.05) end
-- SCROLL=<points> shows a scrolled list (the renderer draws from the top): moves a ScrollingFrame's cards up.
if cfg.SCROLL then
	for _, d in pg:GetDescendants() do
		if d:IsA("ScrollingFrame") and d.Visible then
			for _, ch in d:GetChildren() do
				if ch:IsA("GuiObject") then ch.Position = ch.Position - UDim2.fromOffset(0, cfg.SCROLL) end
			end
		end
	end
end
-- Shine streaks (UI/Effects) pause off the edge, as they rest most of the time; SHINE=<offset> freezes them mid-sweep.
for _, d in pg:GetDescendants() do
	if d.Name == "Band" and d:IsA("UIGradient") then d.Offset = Vector2.new(tonumber(cfg.SHINE) or -1, 0) end
end
task.wait(0.1)
return pg:WaitForChild("HuzzUI")
