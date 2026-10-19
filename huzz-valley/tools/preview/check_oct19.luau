-- Check: the owner's Oct 19 rewards and screens offline, through the real server code and the saved UI.
--   Daily quests (his picture d): the window lists the spin quest first with "NEW IN", then two daily quests, a real
--     reset clock; a finished quest claims once, gives what it says, and the HUD QUESTS button wears "!" until then.
--   Winner page (his picture a): RUNNERS / CATCHERS WIN, the tab's line, MVP / Survival / Catches top 3 with ties
--     ("Joint #3"), XP parts adding up, the level bar from the save.
--   Prestige: a spare copy lets PRESTIGE raise her level (server-checked), up to 3; the companion carries the level.
--   Friend rewards: the HUD has INVITE and shows "+10% COINS" with a friend in; the reward is once per account.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_oct19.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder"); folder.Name = "HuzzGirls"; folder.Parent = RS
for i, g in { { "user_mika", "Mika", "Rare" }, { "user_rin", "Rin", "Common" } } do
	local m = Instance.new("Model"); m.Name = "G" .. i
	local head = Instance.new("Part"); head.Name = "Head"; head.Parent = m
	m:SetAttribute("Id", g[1]); m:SetAttribute("Name", g[2]); m:SetAttribute("Rarity", g[3]); m.Parent = folder
end
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local Characters = require(RS.Shared.Config.Characters)
Characters.addGirls(folder)
local DailyRules = require(RS.Shared.DailyRules)
local DailyQuests = require(RS.Shared.Config.DailyQuests)
local Friends = require(RS.Shared.Config.Friends)
local Progression = require(RS.Shared.Config.Progression)
local data = DataService.get(me).Data
DataService.update(me, function(d) d.Characters.user_mika = os.time(); d.XP = 1073 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local State = require(UI.State)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")
local Action = RS.Remotes.Action

-- 1. daily quests window
check("QUESTS opens", MM.open("DailyQuests") == true)
task.wait(0.2)
local win = gui:FindFirstChild("DailyQuests")
local panel = win and win:FindFirstChild("Panel", true)
check("RESETS IN shows a real clock", panel and string.match(panel.Resets.Text, "^RESETS IN %d") ~= nil)
check("three rows", panel and panel:FindFirstChild("Quest1") and panel:FindFirstChild("Quest2") and panel:FindFirstChild("Quest3"))
check("the spin quest comes first with NEW IN", panel and panel.Quest1.NewIn.Visible and string.match(panel.Quest1.NewIn.Text, "^NEW IN") ~= nil and panel.Quest1.Reward.Text == "+1 SPIN")
check("the daily rows have no NEW IN", panel and not panel.Quest2.NewIn.Visible and not panel.Quest3.NewIn.Visible)
check("no Robux refresh or auto complete", panel and panel:FindFirstChild("Refresh", true) == nil and panel:FindFirstChild("AutoComplete", true) == nil)
local hud = gui:FindFirstChild("LobbyHud")
local questsBtn = hud and hud:FindFirstChild("Quests", true)
check("HUD has QUESTS", questsBtn ~= nil)
check("HUD has INVITE", hud and hud:FindFirstChild("Invite", true) ~= nil)
-- finish the spin quest on the server, as a game would
local now = os.time()
local spinQ = DailyQuests.get(DailyRules.view(data.Daily, now)[1].quest.Id)
local ProgressService = require(HS.ProgressService)
ProgressService.addStat(me, spinQ.Stat, spinQ.Target)
task.wait(1.3)
check("the quest is ready", DailyRules.ready(data.Daily, os.time()) >= 1)
check("HUD QUESTS shows !", questsBtn and questsBtn:FindFirstChild("ReadyTag") and questsBtn.ReadyTag.Visible)
check("its button says CLAIM", panel.Quest1.Claim:FindFirstChild("Label", true).Text == "CLAIM")
local spinsBefore = data.Spins or 0
local okC = Action:InvokeServer("ClaimDaily", "S")
check("claim gives +1 spin", okC == true and data.Spins == spinsBefore + 1)
task.wait(1.1) -- (ActionService turns away clicks closer than its gap: "Too fast.")
local okAgain, why = Action:InvokeServer("ClaimDaily", "S")
if why ~= "Already claimed." then print("claim again said", okAgain, why) end
check("only once", okAgain == false and why == "Already claimed.")
task.wait(1.1)
local okBad, whyBad = Action:InvokeServer("ClaimDaily", "D1")
check("an unfinished quest is refused", okBad == false and whyBad == "Not finished yet.")
task.wait(1.1)
local okKey, whyKey = Action:InvokeServer("ClaimDaily", { 1 })
check("a made-up key is refused", okKey == false and whyKey == "Unknown quest.")
task.wait(1.2)
check("CLAIMED after", panel.Quest1.Claim:FindFirstChild("Label", true).Text == "CLAIMED")
MM.close()
task.wait(0.2)

-- 2. winner page
local Results = require(UI.Screens.Results)
local board = {
	{ user = 1, name = "emyu", crossed = 2, catches = 3, rescues = 0, heroes = 0, won = true },
	{ user = 2, name = "Enooo", crossed = 0, catches = 11, rescues = 0, heroes = 0, won = true },
	{ user = 3, name = "Aloninja", crossed = 1, catches = 1, rescues = 0, heroes = 0, won = false },
	{ user = 4, name = "Zed", crossed = 4, catches = 1, rescues = 0, heroes = 0, won = false },
}
Results.fill({ outcome = "Win", team = "Catchers", board = board, xp = 95, crossed = 0, catches = 3, rescues = 0, heroPaid = 0, coins = 75, aura = 3, girl = "Mika", gotGirl = true, rarity = "Rare" })
check("winner page opens", MM.open("Results") == true)
task.wait(0.2)
local rp = gui.Results:FindFirstChild("Panel", true)
check("CATCHERS WIN", rp.Outcome.Text == "CATCHERS WIN")
check("opens on Catches: Most Catches", rp.Sub.Text == "Most Catches")
check("#1 Enooo, 11 Catches", rp.Place1.Rank.Text == "#1" and rp.Place1.PlayerName.Text == "Enooo" and rp.Place1.Stat.Text == "11 Catches")
check("#2 emyu", rp.Place2.Rank.Text == "#2" and rp.Place2.PlayerName.Text == "emyu")
check("a tie: Joint #3", rp.Place3.Rank.Text == "Joint #3" and rp.Place3.Stat.Text == "1 Catch")
check("each card has an avatar spot and a stand-in", rp.Place1:FindFirstChild("Avatar") ~= nil and rp.Place1:FindFirstChild("Fallback") ~= nil)
__fireOn(rp:FindFirstChild("SurvivalTab", true), "Activated")
task.wait(0.1)
check("Survival tab: Most Crossings, Zed first", rp.Sub.Text == "Most Crossings" and rp.Place1.PlayerName.Text == "Zed" and rp.Place1.Stat.Text == "4 Crossings")
local parts = 0
for n in string.gmatch(rp.XPParts.Text, "%+(%d+)") do parts += tonumber(n) end
check("XP parts add up to +95 XP (played 40, catches 15, win 40)", rp.XPGain.Text == "+95 XP" and parts == 95)
local level, into, per = Progression.level(1073)
check("level bar from the save", rp.LevelBand.From.Text == `Lvl {level}` and rp.LevelBand.To.Text == `Lvl {level + 1}` and rp.LevelBand.Track.Amount.Text == `{into}/{per} XP`)
check("the girl line", rp.GirlLine.Text == "Mika is yours!")
Results.fill({ outcome = "Win", team = "Runners", board = {}, xp = 40 })
check("RUNNERS WIN with nobody crossing: a plain line, no cards", rp.Outcome.Text == "RUNNERS WIN" and not rp.Place1.Visible and rp.Empty.Visible)
MM.close()
task.wait(0.2)

-- 3. prestige
task.wait(1.1)
local okNo, whyNo = Action:InvokeServer("Prestige", "user_mika")
check("no spare copy: refused", okNo == false and whyNo == "Win her again to prestige her.")
task.wait(1.1)
local okRin, whyRin = Action:InvokeServer("Prestige", "user_rin")
check("not owned: refused", okRin == false and whyRin == "You don't own her yet.")
DataService.update(me, function(d) d.Dupes.user_mika = 1; d.Equipped = "user_mika" end)
task.wait(0.2)
MM.open("Index")
task.wait(0.3)
local ip = gui.Index:FindFirstChild("Panel", true)
__fireOn(ip.Grid:FindFirstChild("user_mika"), "Activated")
task.wait(0.2)
check("PRESTIGE shows with a spare copy", ip.Prestige.Visible and ip.PrestigeSpare.Text == "1 spare copy")
__fireOn(ip.Prestige, "Activated")
task.wait(0.4)
check("PRESTIGE 1/3 saved", data.Prestige.user_mika == 1 and (data.Dupes.user_mika or 0) == 0)
check("the Index says PRESTIGE 1/3", ip.PrestigeLevel.Text == "PRESTIGE 1/3" and not ip.Prestige.Visible)
check("her companion carries the level", me:GetAttribute("HuzzCompanionPrestige") == 1)
MM.close()

-- 4. friend rewards
local FriendRules = require(RS.Shared.FriendRules)
me:SetAttribute("HuzzFriendBoost", true)
task.wait(0.4)
check("+10% COINS shows with a friend in", hud:FindFirstChild("FriendBoost", true).Visible and hud:FindFirstChild("FriendBoost", true).Label.Text == Friends.BoostTag)
check("the friend boost pays 10% more", require(HS.FriendService).coins(me, 50) == 55)
me:SetAttribute("HuzzFriendBoost", false)
task.wait(0.4)
check("and hides without one", not hud:FindFirstChild("FriendBoost", true).Visible)
local give
DataService.update(me, function(d) give = FriendRules.grant(d) end)
check("the friend knife once", give == "Knife" and data.Cosmetics[Friends.Knife] == true and data.FriendReward == true)
DataService.update(me, function(d) give = FriendRules.grant(d) end)
check("never twice", give == nil)

print(`oct19: {ok} ok, {fails} failed`)
