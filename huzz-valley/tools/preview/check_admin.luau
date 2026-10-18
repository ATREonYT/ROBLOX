-- Check: the owner's admin panel end to end offline (HuzzServer/AdminService, Screens/Admin; owner Oct 18: "give me a
-- admin command panel ... so i can get any knife or any girl to spawn"). A player who isn't the game's owner gets no
-- button and every request is refused with nothing given (the server decides, whatever the client sends); the owner
-- (Studio here) gets a knife given and worn, a girl as companion, a girl as the next game's girl; requests are rate
-- limited like the UI's other actions.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_admin.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

__roblox.implementMethod("HttpService", "JSONEncode", function(_, v) return __serde.encode("json", v) end)
__roblox.implementMethod("HttpService", "JSONDecode", function(_, s) return __serde.decode("json", s) end)
_G.__isStudio = false -- (the live game: only the place's creator; this player isn't it)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService, GirlService = require(HS.DataService), require(HS.GirlService)
-- two girls in the place (the real catalog comes from his models; RoundService fills it)
local function girl(id, name, rarity)
	local m = Instance.new("Model"); m.Name = id
	table.insert(GirlService.catalog, { id = id, name = name, rarity = rarity, template = m })
end
girl("Girl_TEST1", "Test One", "Rare")
girl("Girl_TEST2", "Test Two", "Secret")
GirlService.publish() -- (the copies the panel lists, ReplicatedStorage.HuzzGirls)

__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")
local toggle = gui and gui:FindFirstChild("AdminToggle")
check("the panel's button exists", toggle ~= nil)
check("not the owner: no HuzzAdmin", me:GetAttribute("HuzzAdmin") ~= true)
check("not the owner: the button is hidden", toggle ~= nil and toggle.Visible == false)

local remote = RS.Remotes.Admin
local replies = {}
remote.OnClientEvent:Connect(function(okReply, message, verb, arg) table.insert(replies, { ok = okReply, message = message, verb = verb, arg = arg }) end)
local function ask(verb, arg)
	task.wait(0.2) -- (past the rate limit)
	local n = #replies
	remote:FireServer(verb, arg)
	task.wait(0.1)
	return replies[n + 1]
end
local data = DataService.get(me).Data

-- a non-admin, whatever it sends: refused, nothing changes
local r = ask("GiveKnife", "CrimsonRequiem")
check("non-admin GiveKnife is refused", r ~= nil and r.ok == false and string.find(tostring(r.message), "owner") ~= nil)
check("non-admin: no knife given", not data.Cosmetics.CrimsonRequiem and data.Wear.Knife ~= "CrimsonRequiem")
r = ask("SpawnGirl", "Girl_TEST2")
check("non-admin SpawnGirl is refused", r ~= nil and r.ok == false)
check("non-admin: no girl given", data.Characters.Girl_TEST2 == nil and data.Equipped ~= "Girl_TEST2")
r = ask("NextGirl", "Girl_TEST2")
check("non-admin NextGirl is refused", r ~= nil and r.ok == false)
local rolls = {}
for _ = 1, 30 do rolls[GirlService.roll().id] = true end
check("non-admin: the roll stays random (both girls come up)", rolls.Girl_TEST1 and rolls.Girl_TEST2)

-- the owner (Studio): each command works
_G.__isStudio = true
me:SetAttribute("HuzzAdmin", true) -- (set on join; the server checks again on every request anyway)
__fireOn(me, "Attr_HuzzAdmin") -- (the harness doesn't fire attribute signals by itself)
task.wait(0.05)
check("the owner sees the button", toggle ~= nil and toggle.Visible == true)
r = ask("GiveKnife", "CrimsonRequiem")
check("admin GiveKnife works: " .. tostring(r and r.message), r ~= nil and r.ok == true)
check("the knife is yours and worn", data.Cosmetics.CrimsonRequiem == true and data.Wear.Knife == "CrimsonRequiem")
r = ask("SpawnGirl", "Girl_TEST1")
check("admin SpawnGirl works: " .. tostring(r and r.message), r ~= nil and r.ok == true)
check("she's yours and your companion", data.Characters.Girl_TEST1 ~= nil and data.Equipped == "Girl_TEST1")
r = ask("NextGirl", "Girl_TEST1")
check("admin NextGirl works: " .. tostring(r and r.message), r ~= nil and r.ok == true)
check("the next roll is her", GirlService.roll().id == "Girl_TEST1")
r = ask("GiveKnife", "MintTrail")
check("admin: a trail isn't a knife (refused)", r ~= nil and r.ok == false)
r = ask("GiveCoins", "1000000")
check("admin: an unknown command is refused", r ~= nil and r.ok == false)
-- two requests at once: the second is too fast
task.wait(0.2)
local n = #replies
remote:FireServer("GiveKnife", "IceKnife")
remote:FireServer("GiveKnife", "CandyKnife")
task.wait(0.1)
check("rate limited like the UI's actions", replies[n + 2] ~= nil and replies[n + 2].ok == false and replies[n + 2].message == "Too fast.")

-- the panel lists every knife and every girl
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
MM.open("Admin")
task.wait(0.1)
local window = gui and gui:FindFirstChild("Admin")
local knifeList = window and window:FindFirstChild("KNIVESList", true)
local girlList = window and window:FindFirstChild("GIRLSList", true)
local CoinShop = require(RS.Shared.Config.CoinShop)
local knives = 0
for _, item in CoinShop.Items do if item.Slot == "Knife" then knives += 1 end end
local function rows(list) local c = 0; for _, ch in (list and list:GetChildren() or {}) do if ch:IsA("Frame") then c += 1 end end; return c end
check("every knife has a row (" .. rows(knifeList) .. " of " .. knives .. ")", rows(knifeList) == knives)
check("every girl has a row", girlList ~= nil and girlList:FindFirstChild("Girl_TEST1") ~= nil and girlList:FindFirstChild("Girl_TEST2") ~= nil)
check("a girl row has SPAWN and NEXT GAME", girlList ~= nil and girlList.Girl_TEST1:FindFirstChild("SpawnGirl") ~= nil and girlList.Girl_TEST1:FindFirstChild("NextGirl") ~= nil)
_G.__isStudio = false

print(`admin panel: {ok} ok, {fails} failed`)
