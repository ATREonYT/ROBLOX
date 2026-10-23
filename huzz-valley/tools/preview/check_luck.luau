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
check("with no luck most girls are Common", shown0 > 70 and math.abs(before - shown0) < 5)

local p10 = Products.get("Luck10")
local d = ShopService._processReceipt({ PlayerId = me.UserId, ProductId = p10.Id, PurchaseId = "luck-1" })
check(`the x10 receipt is granted ({d})`, d == Enum.ProductPurchaseDecision.PurchaseGranted)
check(`server luck is x10 ({LuckService.server()}, attribute {workspace:GetAttribute("HuzzServerLuck")})`, LuckService.server() == 10 and workspace:GetAttribute("HuzzServerLuck") == 10)
local after, shown10 = commonShare(), shownCommon()
print(`[luck] x10: Common shown {string.format("%.1f", shown10)}%, rolled {string.format("%.1f", after)}%`)
check("at x10 the strip's odds show far fewer Commons", shown10 > 0 and shown10 < 35)
check("... and the real rolls follow them", math.abs(after - shown10) < 5)

local p3 = Products.get("Luck3")
ShopService._processReceipt({ PlayerId = me.UserId, ProductId = p3.Id, PurchaseId = "luck-2" })
check("a lower boost after it keeps x10", LuckService.server() == 10)

-- SKIP (Oct 23 16:52 "make a skip round"): a free vote while waiting for a game; more than half and the wait ends
local Skip = require(HS.SkipService)
local Action = RS.Remotes.Action
local function tap(who, on) task.wait(0.3); return Action.OnServerInvoke(who, "SkipVote", on) end -- (ActionService: one action at a time)
check("SKIP is shut outside the wait", workspace:GetAttribute("HuzzSkipNeed") == nil and not Skip.wanted())
local okShut = tap(me, true)
check("a vote outside the wait is refused", okShut == false)
Skip.open()
check(`the wait opens it (0/{workspace:GetAttribute("HuzzSkipNeed")})`, workspace:GetAttribute("HuzzSkipVotes") == 0 and workspace:GetAttribute("HuzzSkipNeed") == 1)
local friend = Instance.new("Player"); friend.Name = "Friend"; friend.UserId = 79; friend.Parent = Players
__fireOn(Players, "PlayerAdded", friend)
task.wait(0.1)
check(`two players need two ({workspace:GetAttribute("HuzzSkipNeed")})`, workspace:GetAttribute("HuzzSkipNeed") == 2)
tap(me, true)
check("one of two isn't enough", not Skip.wanted() and me:GetAttribute("HuzzSkip") == true and workspace:GetAttribute("HuzzSkipVotes") == 1)
tap(me, false)
check("tapping again takes it back", workspace:GetAttribute("HuzzSkipVotes") == 0 and me:GetAttribute("HuzzSkip") == nil)
tap(me, true)
tap(friend, true)
check("both want it: the wait ends", Skip.wanted())
Skip.close()
check("closing clears it", workspace:GetAttribute("HuzzSkipVotes") == nil and me:GetAttribute("HuzzSkip") == nil and not Skip.wanted())
print(`{ok} ok, {fails} failed`)
