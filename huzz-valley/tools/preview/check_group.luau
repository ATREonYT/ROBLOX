-- Check: the "join our group" reward (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the
-- style of our ui, and make the reward 5 free spins on the wheel"), through the real server code and the saved UI.
--   No group set (Config/Group.Id 0): COMING SOON on both buttons, CLAIM gives nothing, the HUD button only in Studio.
--   A group set: JOIN GROUP opens Roblox's join prompt; CLAIM before joining gives nothing; after joining it gives
--   Config/Group.Spins spins once, and the HUD button goes away.
--   It opens by itself after PopupAfter seconds in the lobby (Studio, no group set: so the owner sees it).
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_group.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Group = require(RS.Shared.Config.Group)
check("the owner's group number (Emergent Gaming, his link Oct 23 20:05)", Group.Id == 836119652)
Group.Id = 0 -- (first without a group, as before he sent it)
check("the reward is 5 spins", Group.Spins == 5)
Group.PopupAfter = 0.4 -- (quick, for the check)

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 79; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local DataService = require(game.ServerScriptService.HuzzServer.DataService)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local State = require(UI.State)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")
local Action = RS.Remotes.Action
local function spins() return DataService.get(me).Data.Spins or 0 end
local function click(btn) __fireOn(btn, "Activated"); task.wait(0.2) end

-- by itself, in Studio with no group set
task.wait(0.8)
check("it pops up by itself in the lobby (Studio)", MM.current() == "GroupReward")
local win = gui:FindFirstChild("GroupReward")
local panel = win and win:FindFirstChild("Panel", true)
check("the window is saved in StarterGui (HuzzUI.rbxm)", game.StarterGui:FindFirstChild("HuzzUI") ~= nil and game.StarterGui.HuzzUI:FindFirstChild("GroupReward") ~= nil)
check("says +5 SPINS", panel and panel.Amount.Text == "+5 SPINS")
check("no group set: JOIN GROUP says COMING SOON", panel and panel.Join:FindFirstChild("Label", true).Text == "COMING SOON")
check("no CLAIM button (owner, Oct 23 21:22: the spins come by themselves)", panel and panel:FindFirstChild("Claim") == nil)
check("no group set: the status line says so", panel and panel.Status.Text == "Our group is coming soon. Check back later!")
local hud = gui:FindFirstChild("LobbyHud")
local hudBtn = hud and hud:FindFirstChild("Group", true)
check("the HUD has a GROUP button (Studio)", hudBtn ~= nil and hudBtn.Visible)
local before = spins()
local okC, why = Action:InvokeServer("ClaimGroup")
check("no group set: CLAIM gives nothing (" .. tostring(why) .. ")", okC == false and spins() == before)
MM.close()

-- a group set (the owner's number in Config/Group); the server checks often here (Group.CheckEvery)
Group.Id = 4242
Group.CheckEvery = 0.3
MM.open("GroupReward")
task.wait(0.2)
local joinLabel = panel.Join:FindFirstChild("Label", true)
check("a group set: one JOIN GROUP button", joinLabel ~= nil and joinLabel.Text == "JOIN GROUP" and panel:FindFirstChild("Claim") == nil)
check("the status line says the spins come by themselves", string.find(panel.Status.Text, "by themselves", 1, true) ~= nil)
_G.__prompts = {}
click(panel.Join)
check("JOIN GROUP opens Roblox's join prompt for that group", _G.__prompts[1] and _G.__prompts[1][1] == "Group" and _G.__prompts[1][2] == 4242)
task.wait(1)
local okA, whyA = Action:InvokeServer("ClaimGroup")
check("not in the group: no spins, by asking or by waiting (" .. tostring(whyA) .. ")", okA == false and spins() == before)
_G.__groups = { [4242] = true } -- (he joins the group)
task.wait(1.5)
check(`in the group: +5 spins by themselves, nothing pressed ({spins() - before})`, spins() == before + 5)
task.wait(0.2)
local okD = Action:InvokeServer("ClaimGroup")
task.wait(1)
check("only once", okD == false and spins() == before + 5)
check("the window says JOINED", panel.Join:FindFirstChild("Label", true).Text == "JOINED")
check("the HUD button goes away once they're in", State.data.GroupReward == true and not hudBtn.Visible)
print(string.format("group reward: %d ok, %d failed", ok, fails))
