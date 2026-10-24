-- Check: server luck reaches the girl roll, end to end (owner, Oct 23 16:52: "make the server luck actually affect
-- the chances"). A paid x10 receipt goes through ShopService's ProcessReceipt, then GirlService's roll, strip and
-- odds use it; 2000 real rolls land near the shown odds; a lower boost after it gives nothing more.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_luck.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local ShopService = require(HS.ShopService)
local GirlService = require(HS.GirlService)
local LuckService = require(HS.LuckService)
local Products = require(RS.Shared.Config.Products)

local function commonShare()
	local common, n = 0, 2000
	for _ = 1, n do
		local g = GirlService.roll()
		if g and g.rarity == "Common" then common += 1 end
	end
	return common / n * 100
end
local function shownCommon()
	local _, odds = GirlService.strip(GirlService.roll(), 10, 5)
	for _, o in odds do if o.name == "Common" then return o.chance end end
	return -1
end
-- (no girl models offline: one stand-in girl per rarity, as the real catalog has girls in every rarity)
local Round = require(RS.Shared.Config.Round)
if #GirlService.catalog == 0 then
	for i, r in Round.Rarities do
		table.insert(GirlService.catalog, { id = "g" .. i, key = "g" .. i, name = "Girl " .. i, rarity = r.Name })
	end
end
check(`the catalog has girls ({#GirlService.catalog})`, #GirlService.catalog > 0)
local before, shown0 = commonShare(), shownCommon()
print(`[luck] x1: Common shown {string.format("%.1f", shown0)}%, rolled {string.format("%.1f", before)}%`)
check("with no luck about half the girls are Common", shown0 > 45 and shown0 < 60 and math.abs(before - shown0) < 5)

-- the ladder (Oct 23 17:32: "you have to buy x2 luck then x3 luck, etc. so they can't just buy x10 luck")
local okJump, whyJump = LuckService.prompt(me, "Luck10")
check(`x10 can't be bought first ({whyJump})`, okJump == false and tostring(whyJump):find("x2") ~= nil)
check("the next step at x1 is x2", Products.nextLuck(1).Key == "Luck2")
local _, why2 = LuckService.prompt(me, "Luck2")
check(`x2 is allowed at x1 ({why2})`, why2 == nil or not tostring(why2):find("first"))
ShopService._processReceipt({ PlayerId = me.UserId, ProductId = Products.get("Luck2").Id, PurchaseId = "luck-0" })
check(`after x2 the next is x3 ({Products.nextLuck(LuckService.of(me)).Key})`, Products.nextLuck(LuckService.of(me)).Key == "Luck3")
local okBack = LuckService.prompt(me, "Luck2")
check("x2 again is refused", okBack == false)
check("each step costs more than the one before", (function()
	local last = 0
	for k = 1, 9 do local n = Products.nextLuck(k); if n.Price <= last then return false end; last = n.Price end
	return Products.nextLuck(10) == nil
end)())
local p10 = Products.get("Luck10")
local d = ShopService._processReceipt({ PlayerId = me.UserId, ProductId = p10.Id, PurchaseId = "luck-1" })
check(`the x10 receipt is granted ({d})`, d == Enum.ProductPurchaseDecision.PurchaseGranted)
check(`server luck is x10 ({LuckService.server()}, attribute {workspace:GetAttribute("HuzzServerLuck")})`, LuckService.server() == 10 and workspace:GetAttribute("HuzzServerLuck") == 10)
local after, shown10 = commonShare(), shownCommon()
print(`[luck] x10: Common shown {string.format("%.1f", shown10)}%, rolled {string.format("%.1f", after)}%`)
check("at x10 the strip's odds show far fewer Commons", shown10 > 0 and shown10 < 15)
check("... and the real rolls follow them", math.abs(after - shown10) < 5)

local p3 = Products.get("Luck3")
ShopService._processReceipt({ PlayerId = me.UserId, ProductId = p3.Id, PurchaseId = "luck-2" })
check("a lower boost after it keeps x10", LuckService.server() == 10)

-- stacking (17:53: "if one person who bought 5x luck, leaves a server with 8x luck, the luck turns into 3x luck if the
-- other guy who bought 3x stays"): everyone's boosts add up; a buyer's leaves with them
local a = Instance.new("Player"); a.Name = "A"; a.UserId = 91; a.Parent = Players
local b = Instance.new("Player"); b.Name = "B"; b.UserId = 92; b.Parent = Players
__fireOn(Players, "PlayerAdded", a); __fireOn(Players, "PlayerAdded", b)
me.Parent = nil; __fireOn(Players, "PlayerRemoving", me); task.wait(0.1)
check(`with only A and B (no boosts) the server is x1 ({LuckService.server()})`, LuckService.server() == 1)
LuckService.add(a, 5); LuckService.add(b, 3)
check(`x5 + x3 = x8 ({LuckService.server()})`, LuckService.server() == 8 and workspace:GetAttribute("HuzzServerLuck") == 8)
a.Parent = nil; __fireOn(Players, "PlayerRemoving", a); task.wait(0.1)
check(`the x5 buyer leaves: x3 ({LuckService.server()}, attribute {workspace:GetAttribute("HuzzServerLuck")})`, LuckService.server() == 3 and workspace:GetAttribute("HuzzServerLuck") == 3)
LuckService.add(b, 10)
local c = Instance.new("Player"); c.Name = "C"; c.UserId = 93; c.Parent = Players; __fireOn(Players, "PlayerAdded", c)
LuckService.add(c, 4)
check(`never above x10 ({LuckService.server()})`, LuckService.server() == 10)
local okFull = LuckService.prompt(c, "Luck5")
check("no buying at the top", okFull == false)
me.Parent = Players; __fireOn(Players, "PlayerAdded", me); b.Parent = nil; c.Parent = nil
__fireOn(Players, "PlayerRemoving", b); __fireOn(Players, "PlayerRemoving", c); task.wait(0.1)

-- SKIP (skip game) (Oct 23 19:33: "you dont get teleported into the game if you select it"): your own choice while
-- waiting; it lasts one game and keeps you out of it
local Skip = require(HS.SkipService)
local Action = RS.Remotes.Action
local function tap(who, on) task.wait(0.3); return Action.OnServerInvoke(who, "SkipVote", on) end -- (ActionService: one action at a time)
check("SKIP is shut outside the wait", workspace:GetAttribute("HuzzSkipVotes") == nil)
local okShut = tap(me, true)
check("a skip outside the wait is refused", okShut == false and not Skip.sitting(me.UserId))
Skip.open()
check("the wait opens it", workspace:GetAttribute("HuzzSkipVotes") == 0)
local friend = Instance.new("Player"); friend.Name = "Friend"; friend.UserId = 79; friend.Parent = Players
__fireOn(Players, "PlayerAdded", friend)
task.wait(0.1)
tap(me, true)
check("I skip: only me", Skip.sitting(me.UserId) and not Skip.sitting(friend.UserId) and me:GetAttribute("HuzzSkip") == true and workspace:GetAttribute("HuzzSkipVotes") == 1)
check("one of two skipping: the game still happens", not Skip.everyone())
tap(me, false)
check("tapping again: I play after all", not Skip.sitting(me.UserId) and me:GetAttribute("HuzzSkip") == nil)
tap(me, true)
Skip.close()
check("the game starts: my skip stands", Skip.sitting(me.UserId) and workspace:GetAttribute("HuzzSkipVotes") == nil)
local okLate = tap(friend, true)
check("no skipping once the game started", okLate == false and not Skip.sitting(friend.UserId))
Skip.open()
tap(me, true); tap(friend, true)
check("everyone skips: no game", Skip.everyone())
Skip.clear()
check("after the game everyone plays again", not Skip.sitting(me.UserId) and me:GetAttribute("HuzzSkip") == nil and not Skip.everyone())
print(`{ok} ok, {fails} failed`)
