-- Check: crates end to end offline (Config/Crates, ActionService "OpenCrate", Shop > CRATES, Screens/CrateOpen; owner
-- Oct 19: "create a good case opening animation"). The crate holds only things that exist; the Shop shows every crate on
-- one backdrop and, in the panel a tap slides in, every item's chance, the pity counter and the buttons that pay; the server takes the Aura once, gives the prize and answers with it and an honest reel;
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
-- (the shipped config has the owner's real crate key IDs since Oct 23 21:10: the Dojo key goes back to 0 here, so the
-- "no ID yet: coming soon, never a purchase" path is still tested)
for _, p in require(RS.Shared.Config.Products).Crates do if p.Key == "DojoCrateKey" then p.Id = 0 end end
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
-- (owner, Oct 20 20:34: "remove the two crates that dont have pictures, the starter one"; dances are sold one by one now)
check("the Starter and Dance crates are gone", Crates.get("Starter") == nil and Crates.get("Dance") == nil)
-- the crate the rest of this check opens: his Candy Crate (49 Aura or 250 coins, his 20:34 picture)
local crate = Crates.get("Sweets")
check("the Candy Crate is live: 49 Aura or 250 coins", crate ~= nil and crate.Name == "Candy Crate" and crate.Price == 49 and crate.CoinPrice == 250)
check("the Witch Crate: 79 Aura or 350 coins", Crates.get("Witch") ~= nil and Crates.get("Witch").Name == "Witch Crate" and Crates.get("Witch").Price == 79 and Crates.get("Witch").CoinPrice == 350)
check("the Halloween Crate: 99 Aura or 500 coins", Crates.get("Halloween") ~= nil and Crates.get("Halloween").Price == 99 and Crates.get("Halloween").CoinPrice == 500)

DataService.update(me, function(d) d.Aura, d.Coins = 120, 1000 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local State = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.State)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")

-- 2. the Shop (Oct 20 20:34): HALLOWEEN on top (his three Halloween crates), CRATES (his three knife crates); every
-- crate a card on the same backdrop, with no odds on the page; a tap slides its panel in with every chance, the pity
-- counter and the buttons that pay
MM.open("Shop", "Crates")
task.wait(0.2)
local shop = gui:FindFirstChild("Shop")
local body = shop and shop:FindFirstChild("Products", true)
local side = shop and shop:FindFirstChild("Side", true)
check("Shop has HALLOWEEN, CRATES and DANCES jump buttons", shop ~= nil and shop:FindFirstChild("HalloweenTab", true) ~= nil and shop:FindFirstChild("CratesTab", true) ~= nil and shop:FindFirstChild("DancesTab", true) ~= nil)
local chancesOnPage = 0
for _, d in (body and body:GetDescendants() or {}) do
	if d.Name == "Chance" or string.match(d.Name, "^Section") or d.Name == "HeadOdds" then chancesOnPage += 1 end
end
check(`no chances on the page itself ({chancesOnPage})`, chancesOnPage == 0)
local card = body and body:FindFirstChild("CardSweets")
local backSize, backFill = nil, nil
local sameBack = true
for _, cr in Crates.List do
	local cc = body and body:FindFirstChild("Card" .. cr.Id)
	check(`{cr.Id}: its card`, cc ~= nil)
	local bd = cc and cc:FindFirstChild("Backdrop")
	local pic = bd and bd:FindFirstChild("Crate")
	check(`{cr.Id}: his crate cut out ({cr.Picture}) on the backdrop`, pic ~= nil and pic:IsA("ImageLabel") and pic:GetAttribute("Art") == cr.Picture and pic.ImageColor3 == Color3.new(1, 1, 1))
	if bd then
		local fill = bd:FindFirstChild("Fill")
		backSize = backSize or bd.Size
		backFill = backFill or (fill and fill.Color)
		if bd.Size ~= backSize or not fill or fill.Color ~= backFill then sameBack = false end
	end
	check(`{cr.Id}: OPEN on its card`, cc ~= nil and cc:FindFirstChild("Open") ~= nil and cc.Open:FindFirstChild("Label", true).Text == "OPEN")
	check(`{cr.Id}: its pity line`, cc ~= nil and cc:FindFirstChild("Pity") ~= nil and cc.Pity.Text == "LEGENDARY IN 40 OPENS")
	check(`{cr.Id}: its own panel`, side ~= nil and side.Panel:FindFirstChild("Crate" .. cr.Id) ~= nil)
	for _, it in cr.Items do
		local c = it.Kind == "Cosmetic" and CoinShop.get(it.Id)
		if c then check(`{cr.Id}: {it.Id} is no pass knife`, c.Pass == nil) end
	end
end
check("every crate stands on the same backdrop", sameBack and backSize ~= nil)
check("the Candy card says both prices", card ~= nil and card.Price.Text == "250 COINS OR 49 AURA")
-- his Halloween crates first, in his picture's order, above CRATES; his knife crates under the CRATES header
local function row(ids)
	local prev = nil
	for _, id in ids do
		local c = body and body:FindFirstChild("Card" .. id)
		if not c or (prev and (c.Position.Y.Offset ~= prev.Position.Y.Offset or c.Position.X.Offset <= prev.Position.X.Offset)) then return false end
		prev = c
	end
	return prev ~= nil and prev.Position.X.Offset + prev.Size.X.Offset <= 795
end
check("Candy, Witch, Halloween side by side", row({ "Sweets", "Witch", "Halloween" }))
check("Dojo, Storm, Beast side by side", row({ "Dojo", "Storm", "Beast" }))
check("HALLOWEEN sits above CRATES", body ~= nil and body.CardHalloween.Position.Y.Offset < body.HeadCrates.Position.Y.Offset and body.HeadCrates.Position.Y.Offset < body.CardDojo.Position.Y.Offset)
check("the featured banner is his Halloween Crate", body ~= nil and body:FindFirstChild("Featured") ~= nil and body.Featured.Position.Y.Offset == 0 and body.Featured.Title.Text == "HALLOWEEN CRATE")
local inKnifeCrates = {}
for _, id in { "Dojo", "Storm", "Beast" } do
	local kc = Crates.get(id)
	check(`the {id} crate holds ten knives ({kc and #kc.Items})`, kc ~= nil and #kc.Items == 10)
	for _, it in (kc and kc.Items or {}) do inKnifeCrates[it.Id] = true end
end
local nKnives = 0
for _ in inKnifeCrates do nKnives += 1 end
check(`his three crates hold all 30 of his knives ({nKnives})`, nKnives == 30)
local halloweenCrate = Crates.get("Halloween")
check(`the Halloween Crate holds his 18 Halloween knives ({halloweenCrate and #halloweenCrate.Items})`, halloweenCrate ~= nil and #halloweenCrate.Items == 18)

-- the panel: tap the Candy card's OPEN; it slides in with every chance (adding to 100), the pity and the buttons
local function settle() for _ = 1, 30 do __stepTweens(0.05) end; task.wait(0.35) end
__fireOn(card.Open, "Activated")
settle()
local view = side and side.Panel:FindFirstChild("CrateSweets")
check("OPEN slides the Candy Crate's panel in", side ~= nil and side.Visible and view ~= nil and view.Visible and side.Panel.Position.X.Offset == side.Size.X.Offset - side.Panel.Size.X.Offset)
check("... its name on top", side ~= nil and side.Panel.Title.Text == "CANDY CRATE")
local rows, sum = 0, 0
for _, ch in (view and view.Odds:GetChildren() or {}) do
	if string.match(ch.Name, "^Odds%d+$") then
		rows += 1
		sum += tonumber(string.match(ch.Chance.Text, "[%d%.]+")) or 0
	end
end
check(`every item's chance is listed ({rows} of {#crate.Items})`, rows == #crate.Items)
check(`the chances add to 100 ({sum})`, math.abs(sum - 100) < 1.5)
check("the pity counter shows", view ~= nil and view.Pity.Text == "IN 40 OPENS OR SOONER" and view.PityLabel.Text == "GUARANTEED LEGENDARY")
check("pay with coins (250) or Aura (49)", view ~= nil and view.PayCoins:FindFirstChild("Label", true).Text == "250" and view.Open:FindFirstChild("Label", true).Text == "49")
check("... and its Robux KEY", view ~= nil and view:FindFirstChild("BuyKey") ~= nil)
-- the buttons and the chances sit inside the panel, the list scrolls when long
local inside = true
for _, n in { "PayCoins", "Open", "BuyKey", "Odds" } do
	local e = view and view:FindFirstChild(n)
	local x0 = e and e.Position.X.Offset - e.AnchorPoint.X * e.Size.X.Offset
	local y0 = e and e.Position.Y.Offset - e.AnchorPoint.Y * e.Size.Y.Offset
	if not e or x0 < 0 or x0 + e.Size.X.Offset > side.Panel.Size.X.Offset or y0 + e.Size.Y.Offset > side.Panel.Size.Y.Offset then inside = false; print("outside:", n, x0, y0) end
end
check("the buttons and the chances fit the panel", inside)
-- the dark page beside it closes it
__fireOn(side.Shade, "Activated")
settle()
check("tapping beside the panel closes it", not side.Visible)
-- the Dojo's KEY while its product has no ID: "coming soon", and never a purchase prompt
__fireOn(body.CardDojo.Open, "Activated")
settle()
local dojoView = side.Panel.CrateDojo
check("the Dojo's panel: OPEN 100 and KEY", dojoView.Visible and dojoView.Open:FindFirstChild("Label", true).Text == "OPEN 100" and dojoView:FindFirstChild("BuyKey") ~= nil and dojoView:FindFirstChild("PayCoins") == nil)
local toasts = {}
local Toast = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.Toast)
local oldShow = Toast.show
Toast.show = function(t, ...) table.insert(toasts, t); return oldShow(t, ...) end
local prompts = 0
local MPS = game:GetService("MarketplaceService")
local oldPrompt = MPS.PromptProductPurchase
pcall(function() MPS.PromptProductPurchase = function() prompts += 1 end end)
__fireOn(dojoView.BuyKey, "Activated")
task.wait(0.1)
Toast.show = oldShow
pcall(function() MPS.PromptProductPurchase = oldPrompt end)
check(`KEY with no product ID says coming soon ({toasts[1]})`, toasts[1] ~= nil and string.find(toasts[1], "coming soon") ~= nil)
check("KEY with no product ID opens no purchase", prompts == 0)
local okP, whyP = require(HS.ShopService).promptCrateKey(me, "DojoCrateKey")
check(`the server won't prompt a crate key with no ID ({whyP})`, okP == false and string.find(whyP or "", "coming soon") ~= nil)
local okH = require(HS.ShopService).promptCrateKey(me, "WitchCrateKey")
check("the crate key prompt only takes the knife crates' keys", okH == false)
__fireOn(side.Panel.Close, "Activated")
settle()
check("its X closes it", not side.Visible)
-- the Halloween Crate has no Robux key: coins and Aura only
__fireOn(body.CardHalloween.Open, "Activated")
settle()
check("the Halloween Crate's panel: 500 coins or 99 Aura, no KEY", side.Panel.CrateHalloween.Visible and side.Panel.CrateHalloween.PayCoins:FindFirstChild("Label", true).Text == "500" and side.Panel.CrateHalloween:FindFirstChild("BuyKey") == nil)
-- opened at a crate (a stand, BACK from the opening): its card and its panel
MM.close()
task.wait(0.1)
MM.open("Shop", "Witch")
task.wait(0.4)
settle()
check("opened at the Witch Crate: its panel slides in", side.Visible and side.Panel.CrateWitch.Visible)

-- 3. OPEN: from the panel; the server takes the Aura once and answers with the prize and an honest reel
MM.open("Shop", "Sweets")
task.wait(0.4)
settle()
view = side.Panel.CrateSweets
local Action = RS.Remotes.Action
local answers = {}
local realInvoke = Action.InvokeServer
local flashes, ticks = {}, 0
local coinsBefore = State.shown("Coins")
__fireOn(view.Open, "Activated")
task.wait(0.3)
check("the panel's Aura button goes to the opening screen", MM.current() == "CrateOpen")
local screen = gui:FindFirstChild("CrateOpen")
check(`Aura taken once (120 -> 71: {data.Aura})`, data.Aura == 71)
local pityAfter = data.Pity.Sweets
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
check("the odds by rarity show under the reel while it spins", screen.Group.Odds.Visible and screen.Group.Odds.Chip1.Visible and string.sub(screen.Group.Odds.Chip1.Label.Text, 1, 6) == "COMMON")
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
check(`OPEN AGAIN took 49 more (71 -> 22: {data.Aura})`, data.Aura == 22)
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
local okOpen, why = Action:InvokeServer("OpenCrate", "Sweets")
check("22 Aura can't open a 49 crate", okOpen == false and type(why) == "string" and string.find(why, "more Aura") ~= nil)
check("nothing taken", data.Aura == 22)

-- 5b. coins (owner, Oct 20 20:34: his Halloween crates cost coins or Aura): taken once; a crate without a coin price refuses
DataService.update(me, function(d) d.Coins = 300 end)
task.wait(0.25)
local okC, resC = Action:InvokeServer("OpenCrate", "Sweets", "Coins")
check(`250 coins open the Candy Crate (300 -> 50 + its coins back: {data.Coins})`, okC == true and type(resC) == "table" and data.Coins == 50 + resC.coins and data.Aura == 22)
task.wait(0.25)
local okC2, whyC2 = Action:InvokeServer("OpenCrate", "Sweets", "Coins")
check("50 coins can't open it again", okC2 == false and string.find(whyC2 or "", "more coins") ~= nil)
task.wait(0.25)
local okC3, whyC3 = Action:InvokeServer("OpenCrate", "Dojo", "Coins")
check(`the Dojo opens with Aura only ({whyC3})`, okC3 == false)
-- knives aren't sold for coins any more (owner: "make the knifes not be bought but opened from crates")
local someKnife
for _, it in CoinShop.Items do if it.Slot == "Knife" and not it.Pass and not it.Unlock and not it.NotForSale and not data.Cosmetics[it.Key] then someKnife = it; break end end
DataService.update(me, function(d) d.Coins = 100000 end)
task.wait(0.25)
local okK, whyK = Action:InvokeServer("BuyWithCoins", someKnife.Key)
check(`a knife can't be bought for coins ({whyK})`, okK == false and data.Cosmetics[someKnife.Key] ~= true and data.Coins == 100000)
DataService.update(me, function(d) d.Coins = 1000 end)

-- 6. pity: 29 opens without a Legendary, the 30th is one
DataService.update(me, function(d) d.Aura = 500; d.Pity.Sweets = 39 end)
task.wait(0.2)
local okP, res = Action:InvokeServer("OpenCrate", "Sweets")
check("pity: the 40th open is a Legendary or better", okP == true and type(res) == "table" and (res.rarity == "Legendary" or res.rarity == "Mythic") and res.pity == 0 and res.left == 40)
check("the answer's reel holds the prize at its spot", okP and res.strip[res.at] == res.index and #res.strip == Crates.Reel.Length)

-- 7. duplicates pay coins back
DataService.update(me, function(d)
	for _, it in crate.Items do
		if it.Kind == "Cosmetic" then d.Cosmetics[it.Id] = true elseif it.Kind == "Dance" then d.Dances[it.Id] = true end
	end
end)
local coinsBefore = data.Coins
task.wait(0.2)
local okD, dup = Action:InvokeServer("OpenCrate", "Sweets")
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
__fireOn(gui.Shop:FindFirstChild("Products", true).CardSweets.Open, "Activated")
settle()
__fireOn(side.Panel.CrateSweets.Open, "Activated")
task.wait(0.3)
check("no crate opens during the cutscene", MM.current() ~= "CrateOpen" and data.Aura == auraBefore)
me:SetAttribute("HuzzCinematic", false)
me:SetAttribute("HuzzRole", "Runner")
MM.open("CrateOpen", "Sweets")
task.wait(0.3)
check("no crate opens in a round", MM.current() ~= "CrateOpen" and data.Aura == auraBefore)
me:SetAttribute("HuzzRole", "Lobby")
-- the cutscene starting mid-spin closes the screen (the prize is kept)
MM.open("CrateOpen", "Sweets")
task.wait(0.3)
frames(20)
me:SetAttribute("HuzzCinematic", true)
__fireOn(me, "Attr_HuzzCinematic") -- (the harness doesn't fire attribute signals by itself)
task.wait(0.1)
check("the cutscene closes the opening (prize kept)", MM.current() ~= "CrateOpen" and data.Aura == auraBefore - crate.Price)
me:SetAttribute("HuzzCinematic", false)

print(`crates: {ok} ok, {fails} failed`)
