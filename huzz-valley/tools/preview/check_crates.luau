-- Check: crates end to end offline (Config/Crates, ActionService "OpenCrate", Shop > CRATES, Screens/CrateOpen; owner
-- Oct 19: "create a good case opening animation"). The crate holds only things that exist; the Shop shows every item's
-- chance and the pity counter; the server takes the Aura once, gives the prize and answers with it and an honest reel;
-- the screen animates to exactly that prize, ticks, never flashes (no rays, beams, rings or sparks either: owner, Oct 20
-- 07:51 "feels too ai"), fades the prize's name in and runs one glint round its rim, can be skipped, opens again, and
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
			-- (his three knife crates also hold the quest knives and the wheel's Celestial Edge: owner, Oct 20, "make all of
			-- the knifes earned either through crates/bought/ or robux"; never a pass knife or a reward)
			local extra = crate.Model ~= nil and c ~= nil and c.Slot == "Knife"
			check(`{crate.Id}: {it.Id} is a normal look (not a reward, pass, quest or wheel prize)`, c ~= nil and not c.Earn and not c.Pass and (extra or (not c.NotForSale and not c.Unlock)))
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
local State = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.State)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")

-- 2. Shop > CRATES (one page since Oct 20 14:31, like his reference video): every crate a card (title, picture, the
-- pity line, OPEN with Aura, KEY for Robux where it has one, the "i"), then each crate's every chance under the cards
MM.open("Shop", "Crates")
task.wait(0.2)
local shop = gui:FindFirstChild("Shop")
local body = shop and shop:FindFirstChild("Products", true)
local card = body and body:FindFirstChild("CardStarter")
check("Shop has a CRATES jump button", shop ~= nil and shop:FindFirstChild("CratesTab", true) ~= nil)
check("the crate card shows", card ~= nil)
check("OPEN shows the Aura price", card ~= nil and card.Open:FindFirstChild("Label", true).Text == "OPEN " .. crate.Price)
local rows, sum = 0, 0
for _, ch in (body and body:FindFirstChild("SectionStarter") and body.SectionStarter:GetChildren() or {}) do
	if string.match(ch.Name, "^Odds%d+$") then
		rows += 1
		sum += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0
	end
end
check(`every item's chance is listed ({rows} of {#crate.Items})`, rows == #crate.Items)
check(`the chances add to 100 ({sum})`, math.abs(sum - 100) < 0.5)
check("the pity counter shows", card ~= nil and card.Pity.Text == "IN 30 OPENS" and card.PityLabel.Text == "GUARANTEED LEGENDARY")
-- every crate (owner, Oct 19: "knifes, dances, from crates"), the Halloween stands' too, has its card and its own
-- section with every item's chance, one under the other; no pass knives in any crate
local spans = {}
local lowestCard = 0
for _, cr in Crates.List do
	local cc = body and body:FindFirstChild("Card" .. cr.Id)
	check(`{cr.Id}: its card in CRATES`, cc ~= nil)
	if cc then lowestCard = math.max(lowestCard, cc.Position.Y.Offset + cc.Size.Y.Offset) end
	local sec = body and body:FindFirstChild("Section" .. cr.Id)
	local n, total = 0, 0
	for _, ch in (sec and sec:GetChildren() or {}) do
		if string.match(ch.Name, "^Odds%d+$") then
			n += 1
			total += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0
		end
	end
	check(`{cr.Id}: its section lists all {#cr.Items} chances ({n})`, sec ~= nil and n == #cr.Items)
	check(`{cr.Id}: shown chances add to about 100 ({total})`, math.abs(total - 100) < 1.5)
	if sec then table.insert(spans, { cr.Id, sec.Position.Y.Offset, sec.Position.Y.Offset + sec.Size.Y.Offset }) end
	for _, it in cr.Items do
		local c = it.Kind == "Cosmetic" and CoinShop.get(it.Id)
		if c then check(`{cr.Id}: {it.Id} is no pass knife`, c.Pass == nil) end
	end
end
-- the odds sections stand under the cards, one under the other, never overlapping
table.sort(spans, function(x, y) return x[2] < y[2] end)
check("every chance shows under the crate cards", #spans > 0 and spans[1][2] > lowestCard)
for i = 2, #spans do
	check(`{spans[i][1]}: its section sits below {spans[i - 1][1]}'s`, spans[i][2] > spans[i - 1][3])
end
local halloweenCrate, danceCrate = Crates.get("Halloween"), Crates.get("Dance")
-- his three knife crates (Oct 20): ten of his knives each, all 30 between them, each its card with his own picture
-- (cut to the crate, never recoloured), and under it the pity line, OPEN with Aura, KEY for Robux; the "i" on it
local inKnifeCrates = {}
for _, id in { "Dojo", "Storm", "Beast" } do
	local kc = Crates.get(id)
	check(`the {id} crate holds ten knives ({kc and #kc.Items})`, kc ~= nil and #kc.Items == 10)
	for _, it in (kc and kc.Items or {}) do inKnifeCrates[it.Id] = true end
	local cardK = body and body:FindFirstChild("Card" .. id)
	if cardK then
		local box = cardK:FindFirstChild("HisPicture")
		local pic = box and box:FindFirstChild("Picture")
		check(`{id}: his own picture, cut to the crate`, pic ~= nil and pic:IsA("ImageLabel") and pic:GetAttribute("Art") == "CrateCard" .. id and box.ClipsDescendants and pic.ImageColor3 == Color3.new(1, 1, 1))
		local under = true
		for _, n in { "Open", "BuyKey", "Pity" } do
			local e = cardK:FindFirstChild(n)
			if not e or not box or e.Position.Y.Offset < box.Position.Y.Offset + box.Size.Y.Offset then under = false end
		end
		check(`{id}: the pity line, OPEN and KEY sit under his picture`, under)
		check(`{id}: OPEN with Aura shows its price`, cardK:FindFirstChild("Open") ~= nil and cardK.Open:FindFirstChild("Label", true).Text == "OPEN " .. kc.Price)
		check(`{id}: the pity line shows`, cardK:FindFirstChild("Pity") ~= nil and cardK.Pity.Text == "IN 40 OPENS" and cardK.PityLabel.Text == "GUARANTEED LEGENDARY")
		check(`{id}: KEY for Robux shows its price`, cardK:FindFirstChild("BuyKey") ~= nil and cardK.BuyKey:FindFirstChild("Price", true).Text == "25")
		check(`{id}: the odds button`, cardK:FindFirstChild("Odds") ~= nil)
	end
end
-- the Halloween stands' crates: his pictures (Witch's Brew = his Beast, Sweets & Treats = his Dojo), a HALLOWEEN tag
for id, art in { Witch = "CrateCardBeast", Sweets = "CrateCardDojo" } do
	local cardH = body and body:FindFirstChild("Card" .. id)
	local pic = cardH and cardH:FindFirstChild("HisPicture") and cardH.HisPicture:FindFirstChild("Picture")
	check(`{id}: his {art} picture`, pic ~= nil and pic:GetAttribute("Art") == art)
	check(`{id}: the HALLOWEEN tag and its KEY`, cardH ~= nil and cardH:FindFirstChild("Tag") ~= nil and cardH:FindFirstChild("BuyKey") ~= nil)
end
local nKnives = 0
for _ in inKnifeCrates do nKnives += 1 end
check(`his three crates hold all 30 of his knives ({nKnives})`, nKnives == 30)
if body and body:FindFirstChild("CardDojo") and body:FindFirstChild("CardStorm") and body:FindFirstChild("CardBeast") then
	local a, b2, c3 = body.CardDojo, body.CardStorm, body.CardBeast
	check("his three cards lead the row, left to right", a.Position.Y.Offset == b2.Position.Y.Offset and b2.Position.Y.Offset == c3.Position.Y.Offset and a.Position.X.Offset < b2.Position.X.Offset and b2.Position.X.Offset < c3.Position.X.Offset)
	check("the cards fit the page side by side", c3.Position.X.Offset + c3.Size.X.Offset <= 795)
	-- KEY while its product has no ID: "coming soon", and never a purchase prompt
	local toasts = {}
	local Toast = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Toast)
	local oldShow = Toast.show
	Toast.show = function(t, ...) table.insert(toasts, t); return oldShow(t, ...) end
	local prompts = 0
	local MPS = game:GetService("MarketplaceService")
	local oldPrompt = MPS.PromptProductPurchase
	pcall(function() MPS.PromptProductPurchase = function() prompts += 1 end end)
	__fireOn(a.BuyKey, "Activated")
	task.wait(0.1)
	Toast.show = oldShow
	pcall(function() MPS.PromptProductPurchase = oldPrompt end)
	check(`KEY with no product ID says coming soon ({toasts[1]})`, toasts[1] ~= nil and string.find(toasts[1], "coming soon") ~= nil)
	check("KEY with no product ID opens no purchase", prompts == 0)
	-- the server refuses too
	local okP, whyP = require(HS.ShopService).promptCrateKey(me, "DojoCrateKey")
	check(`the server won't prompt a crate key with no ID ({whyP})`, okP == false and string.find(whyP or "", "coming soon") ~= nil)
	local okH = require(HS.ShopService).promptCrateKey(me, "WitchCrateKey")
	check("the crate key prompt only takes the knife crates' keys", okH == false)
	-- the "i" scrolls the page to that crate's every chance
	__fireOn(c3.Odds, "Activated")
	for _ = 1, 40 do __stepTweens(0.05) end
	task.wait(0.3)
	check(`the "i" scrolls to the Beast's chances ({body.CanvasPosition.Y})`, math.abs(body.CanvasPosition.Y - (body.SectionBeast.Position.Y.Offset + 4)) <= 1)
end
check(`the Halloween Crate holds his 18 Halloween knives ({halloweenCrate and #halloweenCrate.Items})`, halloweenCrate ~= nil and #halloweenCrate.Items == 18)
local danceOnly = 0
for _, it in (danceCrate and danceCrate.Items or {}) do
	local d = it.Kind == "Dance" and Dances.get(it.Id)
	if d and d.Crate then danceOnly += 1 end
end
check(`the Dance Crate has its own dances ({danceOnly})`, danceOnly == 7)

-- 3. OPEN: the screen opens, the server takes the Aura once and answers with the prize and an honest reel
local Action = RS.Remotes.Action
local answers = {}
local realInvoke = Action.InvokeServer
local flashes, ticks = {}, 0
local coinsBefore = State.shown("Coins")
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
local glintMoves, glintMax = 0, -1
local minX = math.huge
local function frames(n)
	for _ = 1, n do
		__fireOn(RunService, "RenderStepped", 1 / 30)
		if strip then minX = math.min(minX, strip.Position.X.Offset) end
		if flash and flash.Visible and not wasFlash then table.insert(flashes, os.clock()) end
		wasFlash = flash ~= nil and flash.Visible
		if screen and screen:FindFirstChild("Hint", true).Visible then hintSeen = true end
		local g = screen and screen:FindFirstChild("Glint", true)
		if g and g:IsA("UIGradient") and g.Offset.X > -0.99 then glintMoves += 1; glintMax = math.max(glintMax, g.Offset.X) end
	end
end
frames(40) -- 1.3 s: shake, pop, the reel opens and starts
check("the crate popped and the reel is spinning", screen.Group.Crate.Visible == false and screen.Group.Reel.Visible == true)
check("TAP TO SKIP shows while it spins", hintSeen)
check("the odds by rarity show under the reel while it spins", screen.Group.Odds.Visible and screen.Group.Odds.Chip1.Visible and screen.Group.Odds.Chip1.Label.Text == "COMMON 50%")
-- the HUD's coins wait for the prize (a duplicate's coins would give it away)
DataService.update(me, function(d) d.Coins += 5 end)
task.wait(0.1)
check(`the HUD's coins are held while it spins ({State.shown("Coins")} = {coinsBefore})`, State.shown("Coins") == coinsBefore and (State.data.Coins or 0) ~= coinsBefore)
frames(153) -- to 6.43 s: the prize has just come up (6.25 s)
local pname = screen.Group.Prize.Card.PrizeName
check(string.format("the prize's name fades in, not at once (%.2f)", pname.TextTransparency), screen.Group.Prize.Visible and pname.TextTransparency > 0.3)
frames(37) -- to 7.67 s: the buttons come back
check("its name has faded in", pname.TextTransparency < 0.01 and pname.Outline.Transparency < 0.01)
check(string.format("one glint runs round the prize card's rim (%d frames, to %.2f)", glintMoves, glintMax), glintMoves >= 10 and glintMoves <= 22 and glintMax > 0.8)
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
-- the honest settle: it ran a little past its stop and came back, and at its furthest the marker was still on the prize
local furthest = centre - (minX + (Crates.Reel.At - 1) * 162)
check(`the reel ran past and settled back ({reelX - minX} px)`, reelX - minX >= 10 and reelX - minX <= 40)
check(`at its furthest the marker was still on the prize card ({furthest})`, furthest >= 10 and furthest <= 140)
check("the HUD shows the coins once the prize shows", State.shown("Coins") == State.data.Coins)
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
check(`no flash ({#flashes} flashes)`, #flashes == 0)
local shapes = {}
for _, n in { "CrateRays", "Flash", "PrizeRays", "Burst", "Ring1", "Ring2", "Spark1" } do
	if screen:FindFirstChild(n, true) then table.insert(shapes, n) end
end
check(`no rays, beams, rings, sparks or flash on the screen ({table.concat(shapes, ", ")})`, #shapes == 0)

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
card = gui.Shop:FindFirstChild("Products", true):FindFirstChild("CardStarter")
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
