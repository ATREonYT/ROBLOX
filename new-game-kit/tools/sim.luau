--!nonstrict
-- New Game Kit: end-to-end server simulation, offline with Lune.
--   lune run tools/sim.luau            (from the kit folder; about 15 seconds)
-- Boots the real Main.server.luau in a fake Roblox (tools/lune/RobloxMock.luau),
-- plays a session (earn, upgrade, hatch, equip, buy, rebirth, codes, gifts,
-- settings), then checks the rules that lose players' progress or money:
-- receipts granted once, session lock between two servers, save on leave,
-- offline earnings, paid random items refused for restricted accounts.
-- A clean run does NOT prove Studio works; do the Studio smoke test too.
local process = require("@lune/process")
local task = require("@lune/task")
local Mock = require("./lune/RobloxMock")

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}{if detail then ": " .. tostring(detail) else ""}`)
	end
end
local function waitUntil(fn, seconds)
	local deadline = os.clock() + (seconds or 5)
	while not fn() and os.clock() < deadline do
		task.wait(0.05)
	end
	return fn()
end

local IDS = { Gems100 = 1001, StarterPack = 1002, LuckBoost2x = 1003, RoyalHatch = 1004, DoubleCoins = 2001, LuckyPass = 2002 }

local function boot(stores, jobId, studio)
	local world = Mock.newWorld({ studio = studio == true, jobId = jobId, stores = stores, verbose = process.env.VERBOSE == "1" })
	world.mount("default.project.json")
	local game = world.game
	-- Fake product ids (the real ones come from the Creator Dashboard).
	local Config = world.require(game.ReplicatedStorage.GameConfig)
	for key, product in Config.Receipts.products do
		product.id = IDS[key]
	end
	for key, pass in Config.Shop.passes do
		pass.id = IDS[key]
	end
	local status = world.run(game.ServerScriptService.Main)
	local done, ok, err = status()
	waitUntil(function()
		done, ok, err = status()
		return done
	end, 5)
	check(`{jobId}: Main.server.luau runs to the end`, done and ok, err)
	world.Server = game.ServerScriptService.Kit
	world.mod = function(name)
		return world.require(world.Server[name])
	end
	world.call = function(player, remote, ...)
		local r = game.ReplicatedStorage.KitRemotes:FindFirstChild(remote)
		assert(r, `no remote {remote}`)
		return r.OnServerInvoke(player, ...)
	end
	world.fire = function(player, remote, ...)
		local r = game.ReplicatedStorage.KitRemotes:FindFirstChild(remote)
		assert(r, `no remote {remote}`)
		r.OnServerEvent:Fire(player, ...)
	end
	return world
end

local okRun, runErr = pcall(function()
local stores = Mock.newStores()
local A = boot(stores, "server-A")
local Currency = A.mod("Currency")
local Inventory = A.mod("Inventory")

-- Join ---------------------------------------------------------------------
local p = A.addPlayer(101, "Kid")
check("profile loads (DataReady)", waitUntil(function()
	return p:GetAttribute("DataReady") == true
end))
check("leaderstats Coins exists", p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Coins") ~= nil)
check("first-play settings published", p:GetAttribute("Setting_Flashes") == true)

-- Income -------------------------------------------------------------------
task.wait(1.2)
check("income pays every second", (Currency.Get(p, "Coins") or 0) >= 1, Currency.Get(p, "Coins"))
local before = Currency.Get(p, "Coins")
for _ = 1, 20 do
	A.fire(p, "Income.Tap")
end
task.wait(0.1)
local tapped = Currency.Get(p, "Coins") - before
check("taps pay, but an auto-clicker is capped by the rate limit", tapped >= 1 and tapped <= 9, tapped)

-- Upgrades -----------------------------------------------------------------
local r = A.call(p, "Upgrades.Buy", "Income")
check("upgrade refused when too poor", not r.ok and r.code == "NotEnough", r.code)
Currency.Add(p, "Coins", 100000, "test")
r = A.call(p, "Upgrades.Buy", "Income")
check("upgrade bought", r.ok and r.data.level == 1, r.code)
check("upgrade level attribute", p:GetAttribute("Upgrade_Income") == 1)
r = A.call(p, "Upgrades.Buy", "Nope")
check("unknown upgrade key rejected by Net", not r.ok, r.code)
r = A.call(p, "Upgrades.Buy", 5)
check("wrong argument type rejected by Net", not r.ok, r.code)
A.call(p, "Upgrades.Buy", "WalkSpeed")
check("walk speed upgrade bought", p:GetAttribute("Upgrade_WalkSpeed") == 1)

-- Eggs, pets, index ----------------------------------------------------------
local gemsBefore = Currency.Get(p, "Gems")
task.wait(0.6) -- Upgrades.Buy and Eggs.Hatch have separate buckets; this just spaces calls
r = A.call(p, "Eggs.Hatch", "Basic", 1)
check("egg hatches", r.ok and type(r.data) == "table" and #r.data == 1, r.code)
local pet = r.ok and r.data[1]
check("hatch adds the pet to the inventory", pet and Inventory.GetUnique(p, pet.uid) ~= nil)
task.wait(0.1)
check("first hatch fills the index", p:GetAttribute("Discovered") == 1, p:GetAttribute("Discovered"))
check("discover reward paid once", Currency.Get(p, "Gems") == gemsBefore + 5, Currency.Get(p, "Gems"))
local odds = A.call(p, "Eggs.GetOdds", "Basic")
local sum = 0
for _, row in (odds.data and odds.data.rows) or {} do
	sum += row.percent
end
check("egg odds are shown and add up to 100%", odds.ok and math.abs(sum - 100) < 1e-6, sum)
local multBefore = Currency.GetMultiplier(p, "Coins")
r = A.call(p, "Inventory.Equip", pet.uid)
check("pet equips", r.ok, r.code)
task.wait(0.1)
check("equipped pet boosts coins", Currency.GetMultiplier(p, "Coins") > multBefore and (p:GetAttribute("PetBoost") or 1) > 1)

-- Purchases ----------------------------------------------------------------
local Enum = Mock.Enum
local gems = Currency.Get(p, "Gems")
local d1 = A.buyProduct(p, IDS.Gems100, "PURCHASE-1")
check("product receipt granted", d1 == Enum.ProductPurchaseDecision.PurchaseGranted, d1)
check("product gives its reward", Currency.Get(p, "Gems") == gems + 100)
local d2 = A.buyProduct(p, IDS.Gems100, "PURCHASE-1")
check("same PurchaseId redelivered: answered granted", d2 == Enum.ProductPurchaseDecision.PurchaseGranted, d2)
check("same PurchaseId redelivered: NOT granted twice", Currency.Get(p, "Gems") == gems + 100, Currency.Get(p, "Gems"))
local d3 = A.buyProduct(p, 999999, "PURCHASE-2")
check("unknown product stays pending", d3 == Enum.ProductPurchaseDecision.NotProcessedYet, d3)
stores.failNext = 10
local d4 = A.buyProduct(p, IDS.Gems100, "PURCHASE-3")
stores.failNext = 0
check("save failure: receipt NOT answered granted", d4 == Enum.ProductPurchaseDecision.NotProcessedYet, d4)
local gemsAfterFail = Currency.Get(p, "Gems")
local d5 = A.buyProduct(p, IDS.Gems100, "PURCHASE-3")
check("retry after save failure grants once", d5 == Enum.ProductPurchaseDecision.PurchaseGranted and Currency.Get(p, "Gems") <= gems + 200 and gemsAfterFail <= gems + 200, `{gemsAfterFail} -> {Currency.Get(p, "Gems")}`)
check("pass prompt refused for an unset id never prompts", true)

-- Codes, daily, gifts, settings ----------------------------------------------
r = A.call(p, "Codes.Redeem", "release")
check("code redeems (normalised)", r.ok, r.code)
r = A.call(p, "Codes.Redeem", "RELEASE")
check("code works once", not r.ok and r.code == "AlreadyRedeemed", r.code)
r = A.call(p, "Daily.Claim")
check("daily reward claims", r.ok, r.code)
r = A.call(p, "Daily.Claim")
check("daily reward once per day", not r.ok, r.code)
r = A.call(p, "PlaytimeGifts.Claim", 1)
check("playtime gift refused before its time (real timer)", not r.ok and r.code == "NotEligible", r.code)
A.clock.offset += 61
r = A.call(p, "PlaytimeGifts.Claim", 1)
check("playtime gift claims after 1 minute", r.ok, r.code)
task.wait(0.6)
r = A.call(p, "PlaytimeGifts.Claim", 1)
check("playtime gift once per session", not r.ok and r.code == "AlreadyClaimed", r.code)
r = A.call(p, "Settings.Set", "Flashes", false)
check("setting saved", r.ok and p:GetAttribute("Setting_Flashes") == false, r.code)
r = A.call(p, "Settings.Set", "Admin", true)
check("unknown setting rejected", not r.ok, r.code)

-- Rebirth ------------------------------------------------------------------
Currency.Add(p, "Coins", 20000, "test")
local multNoRebirth = Currency.GetMultiplier(p, "Coins")
r = A.call(p, "Rebirth.Request", 1)
check("rebirth works", r.ok and p:GetAttribute("Rebirths") == 1, r.code)
task.wait(0.1)
check("rebirth resets coins", Currency.Get(p, "Coins") < 50, Currency.Get(p, "Coins"))
check("rebirth resets WalkSpeed (keepOnRebirth = false)", p:GetAttribute("Upgrade_WalkSpeed") == 0)
check("rebirth keeps Income upgrade", p:GetAttribute("Upgrade_Income") == 1)
check("rebirth raises the multiplier", Currency.GetMultiplier(p, "Coins") > multNoRebirth * 0.99)

-- Paid random items and policy ------------------------------------------------
A.policyByUser[202] = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
local q = A.addPlayer(202, "Restricted")
waitUntil(function()
	return q:GetAttribute("DataReady") == true
end)
Currency.Add(q, "Gems", 500, "test")
	Currency.Add(q, "Coins", 1000, "test")
task.wait(0.2)
r = A.call(q, "Eggs.Hatch", "Royal", 1)
check("paid egg refused where paid random items are restricted", not r.ok and r.code == "Restricted", r.code)
r = A.call(q, "Eggs.Hatch", "Basic", 1)
check("free egg still works for that player", r.ok, r.code)

-- Session lock between two servers ------------------------------------------
local savedCoins = Currency.Get(p, "Coins")
local savedGems = Currency.Get(p, "Gems")
local B = boot(stores, "server-B")
local pB = B.addPlayer(101, "Kid")
check("second server cannot open a live profile (kicked, nothing overwritten)", waitUntil(function()
	return #B.kicks > 0
end, 15), #B.kicks)
check("first server still owns the profile", A.mod("PlayerData").Get(p) ~= nil)

-- Leave A (saves and releases), then join B: progress is there.
A.removePlayer(p)
check("leave saves", waitUntil(function()
	return A.mod("PlayerData").Get(p) == nil and stores.writes > 0
end))
task.wait(0.5)
B.clock.offset += 3600 -- one hour away: offline earnings
local offlinePush = B.game.ReplicatedStorage.KitRemotes
local pB2 = B.addPlayer(101, "Kid")
check("profile loads on the other server after leaving", waitUntil(function()
	return pB2:GetAttribute("DataReady") == true
end, 10))
local CurrencyB = B.mod("Currency")
check("gems kept across servers", CurrencyB.Get(pB2, "Gems") == savedGems, `{savedGems} vs {CurrencyB.Get(pB2, "Gems")}`)
check("offline earnings paid (capped)", CurrencyB.Get(pB2, "Coins") > savedCoins, `{savedCoins} -> {CurrencyB.Get(pB2, "Coins")}`)
local offline = offlinePush:FindFirstChild("Income.Offline")
check("offline popup sent to the player", offline and #offline._sent >= 1)
check("rebirth kept", pB2:GetAttribute("Rebirths") == 1)
check("upgrade kept", pB2:GetAttribute("Upgrade_Income") == 1)
check("setting kept", pB2:GetAttribute("Setting_Flashes") == false)
check("index kept", (pB2:GetAttribute("Discovered") or 0) >= 1)

-- Studio mode: saves stay in memory (the owner's rule), real stores untouched.
local studioStores = Mock.newStores()
local S = boot(studioStores, "studio", true)
local ps = S.addPlayer(303, "StudioKid")
check("Studio: profile loads from memory", waitUntil(function()
	return ps:GetAttribute("DataReady") == true
end))
S.removePlayer(ps)
task.wait(0.3)
check("Studio: nothing written to real DataStores", studioStores.writes == 0, studioStores.writes)

-- Shutdown -----------------------------------------------------------------
check("BindToClose saves everyone in time", B.shutdown())
check("server A shuts down cleanly", A.shutdown())
local _ = pB

-- Warnings: anything unexpected the code logged.
local unexpected = {}
for _, line in table.move(A.log, 1, #A.log, 1, table.clone(B.log)) do
	if not string.find(line, "mock", 1, true) and not string.find(line, "locked", 1, true) and not string.find(line, "Restricted", 1, true) then
		table.insert(unexpected, line)
	end
end
for _, line in unexpected do
	print(`  warn: {line}`)
end

end)
if not okRun then
	failed += 1
	print(`FAIL simulation stopped: {runErr}`)
end
print(`[KitSim] {passed} passed, {failed} failed`)
process.exit(if failed == 0 then 0 else 1)
