-- Check: crates end to end offline (Config/Crates, ActionService "OpenCrate", Shop > CRATES, Screens/CrateOpen; owner
-- Oct 19: "create a good case opening animation"). The crate holds only things that exist; the Shop shows every item's
-- chance and the pity counter; the server takes the Aura once, gives the prize and answers with it and an honest reel;
-- the screen animates to exactly that prize, ticks, flashes at most once a second, can be skipped, opens again, and
-- won't open in a round or during the Secret cutscene. Pity and duplicates pay out as shown.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_crates.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local Crates = require(RS.Shared.Config.Crates)
local CoinShop = require(RS.Shared.Config.CoinShop)
local Dances = require(RS.Shared.Config.Dances)
local CrateRoll = require(RS.Shared.CrateRoll)
local data = DataService.get(me).Data

-- 1. the crate holds only things that exist and can be won (no rewards, passes, quest or wheel prizes, no free dances)
for _, crate in Crates.List do
	for _, it in crate.Items do
		if it.Kind == "Cosmetic" then
			local c = CoinShop.get(it.Id)
			check(`{crate.Id}: {it.Id} is in the coin shop`, c ~= nil)
			check(`{crate.Id}: {it.Id} is a normal look (not a reward, pass, quest or wheel prize)`, c ~= nil and not c.NotForSale and not c.Earn and not c.Pass and not c.Unlock)
			check(`{crate.Id}: {it.Id} keeps its shop name`, c ~= nil and c.Name == it.Name)
			check(`{crate.Id}: {it.Id} keeps its knife rarity`, c ~= nil and (c.Rarity == nil or c.Rarity == it.Rarity))
		elseif it.Kind == "Dance" then
			local d = Dances.get(it.Id)
			check(`{crate.Id}: dance {it.Id} exists`, d ~= nil)
			check(`{crate.Id}: dance {it.Id} isn't free or the Dance Pack's`, d ~= nil and not d.Starter and not d.Pack)
		else
			check(`{crate.Id}: coins have an amount`, it.Kind == "Coins" and (it.Amount or 0) > 0)
		end
	end
end
local crate = Crates.get("Starter")
check("the Starter Crate is live", crate ~= nil)

DataService.update(me, function(d) d.Aura, d.Coins = 120, 1000 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")

-- 2. Shop > CRATES: the crate, its price, every item's chance (adding to 100), the pity counter
MM.open("Shop", "Crates")
task.wait(0.2)
local shop = gui:FindFirstChild("Shop")
local body = shop and shop:FindFirstChild("Products", true)
local card = body and body:FindFirstChild("Starter")
check("Shop has a CRATES tab", shop ~= nil and shop:FindFirstChild("CratesTab", true) ~= nil)
check("the crate card shows", card ~= nil)
check("OPEN shows the Aura price", card ~= nil and card.Open:FindFirstChild("Label", true).Text == "OPEN " .. crate.Price)
local rows, sum = 0, 0
for _, ch in (body and body:GetChildren() or {}) do
	if string.match(ch.Name, "^Odds%d+$") then
		rows += 1
		sum += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0
	end
end
check(`every item's chance is listed ({rows} of {#crate.Items})`, rows == #crate.Items)
check(`the chances add to 100 ({sum})`, math.abs(sum - 100) < 0.5)
check("the pity counter shows", card ~= nil and card.Pity.Text == "in 30 opens" and card.PityLabel.Text == "GUARANTEED LEGENDARY")

-- 3. OPEN: the screen opens, the server takes the Aura once and answers with the prize and an honest reel
local Action = RS.Remotes.Action
local answers = {}
local realInvoke = Action.InvokeServer
local flashes, ticks = {}, 0
__fireOn(card.Open, "Activated")
task.wait(0.3)
check("OPEN goes to the opening screen", MM.current() == "CrateOpen")
local screen = gui:FindFirstChild("CrateOpen")
check("Aura taken once (120 -> 70)", data.Aura == 70)
local pityAfter = data.Pity.Starter
check("the pity counter moved", pityAfter == 1 or pityAfter == 0)
local strip = screen and screen:FindFirstChild("Strip", true)
local cardCount = 0
for _, ch in (strip and strip:GetChildren() or {}) do if ch:IsA("Frame") then cardCount += 1 end end
check(`the reel has its {Crates.Reel.Length} cards ({cardCount})`, cardCount == Crates.Reel.Length)
local prizeCard = strip and strip:FindFirstChild("Card" .. Crates.Reel.At)
local flash = screen and screen:FindFirstChild("Flash", true)
local soundsBefore = #_G.__sounds
local wasFlash, hintSeen = false, false
local function frames(n)
	for _ = 1, n do
		__fireOn(RunService, "RenderStepped", 1 / 30)
		if flash and flash.Visible and not wasFlash then table.insert(flashes, os.clock()) end
		wasFlash = flash ~= nil and flash.Visible
		if screen and screen:FindFirstChild("Hint", true).Visible then hintSeen = true end
	end
end
frames(40) -- 1.3 s: shake, pop, the reel opens and starts
check("the crate popped and the reel is spinning", screen.Group.Crate.Visible == false and screen.Group.Reel.Visible == true)
check("TAP TO SKIP shows while it spins", hintSeen)
frames(190) -- to 7.6 s: stops, lands, the prize shows, the buttons come back
for _, s in table.move(_G.__sounds, soundsBefore + 1, #_G.__sounds, 1, {}) do if s[1] == "spin_tick" then ticks += 1 end end
local prize = screen.Group.Prize
check("the prize shows", prize.Visible == true)
local shownName = prize.Card.PrizeName.Text
check("the reel stopped on the prize card", prizeCard ~= nil and prizeCard.Name and prizeCard:FindFirstChild("Name").Text == shownName)
local item
for _, it in crate.Items do if it.Name == shownName then item = it end end
check(`the shown prize is a real item ({shownName})`, item ~= nil)
check(`ticks played as cards passed ({ticks})`, ticks >= 15)
check("NEW! or the coins line shows", screen.Group.Status.Visible and screen.Group.Status.Text ~= "")
check("OPEN AGAIN and BACK show", screen.Group.Bottom.Visible)
local reelX = strip.Position.X.Offset
local centre = (1100 - 8) / 2
local cardX = reelX + (Crates.Reel.At - 1) * 162
check("the marker sits on the prize card", centre >= cardX + 10 and centre <= cardX + 140)
if item and item.Kind ~= "Coins" then
	local owned = if item.Kind == "Dance" then data.Dances else data.Cosmetics
	check("the prize is yours", owned[item.Id] == true)
end

-- 4. OPEN AGAIN and skip: tap mid-spin jumps to the prize; the Aura is taken once more
__fireOn(screen.Group.Bottom.OpenAgain, "Activated")
task.wait(0.3)
check("OPEN AGAIN took 50 more (70 -> 20)", data.Aura == 20)
frames(60)
__fireOn(screen.Group.Skip, "Activated")
frames(2)
check("a tap skips to the prize", screen.Group.Prize.Visible == true)
frames(30)
check("after a skip the buttons come back", screen.Group.Bottom.Visible == true)
check(`at most one flash a second ({#flashes} flashes)`, #flashes <= 1 or (flashes[2] - flashes[1]) >= 1)

-- 5. not enough Aura: refused, nothing taken
task.wait(0.2)
local okOpen, why = Action:InvokeServer("OpenCrate", "Starter")
check("20 Aura can't open a 50 crate", okOpen == false and type(why) == "string" and string.find(why, "more Aura") ~= nil)
check("nothing taken", data.Aura == 20)

-- 6. pity: 29 opens without a Legendary, the 30th is one
DataService.update(me, function(d) d.Aura = 500; d.Pity.Starter = 29 end)
task.wait(0.2)
local okP, res = Action:InvokeServer("OpenCrate", "Starter")
check("pity: the 30th open is a Legendary", okP == true and type(res) == "table" and res.rarity == "Legendary" and res.pity == 0 and res.left == 30)
check("the answer's reel holds the prize at its spot", okP and res.strip[res.at] == res.index and #res.strip == Crates.Reel.Length)

-- 7. duplicates pay coins back
DataService.update(me, function(d)
	for _, it in crate.Items do
		if it.Kind == "Cosmetic" then d.Cosmetics[it.Id] = true elseif it.Kind == "Dance" then d.Dances[it.Id] = true end
	end
end)
local coinsBefore = data.Coins
task.wait(0.2)
local okD, dup = Action:InvokeServer("OpenCrate", "Starter")
local dupItem = okD and crate.Items[dup.index]
if dupItem and dupItem.Kind ~= "Coins" then
	check("a duplicate says so", dup.new == false and dup.coins == CrateRoll.dupeCoins(crate, dupItem))
else
	check("a coin prize pays its amount", okD and dup.coins == dupItem.Amount)
end
check("the coins arrived", data.Coins == coinsBefore + (okD and dup.coins or -1))

-- 8. blocked during the Secret cutscene (and in a round): nothing opens, nothing is taken
MM.open("Shop", "Crates")
task.wait(0.2)
local auraBefore = data.Aura
me:SetAttribute("HuzzCinematic", true)
card = gui.Shop:FindFirstChild("Products", true):FindFirstChild("Starter")
__fireOn(card.Open, "Activated")
task.wait(0.3)
check("no crate opens during the cutscene", MM.current() ~= "CrateOpen" and data.Aura == auraBefore)
me:SetAttribute("HuzzCinematic", false)
me:SetAttribute("HuzzRole", "Runner")
MM.open("CrateOpen", "Starter")
task.wait(0.3)
check("no crate opens in a round", MM.current() ~= "CrateOpen" and data.Aura == auraBefore)
me:SetAttribute("HuzzRole", "Lobby")
-- the cutscene starting mid-spin closes the screen (the prize is kept)
MM.open("CrateOpen", "Starter")
task.wait(0.3)
frames(20)
me:SetAttribute("HuzzCinematic", true)
__fireOn(me, "Attr_HuzzCinematic") -- (the harness doesn't fire attribute signals by itself)
task.wait(0.1)
check("the cutscene closes the opening (prize kept)", MM.current() ~= "CrateOpen" and data.Aura == auraBefore - crate.Price)
me:SetAttribute("HuzzCinematic", false)

print(`crates: {ok} ok, {fails} failed`)
