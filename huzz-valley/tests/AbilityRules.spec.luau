-- Bought abilities (Shared/AbilityRules, Config/Powers; owner, Oct 20 15:13: "Please then make the abilities be bought,
-- add a few more abilities, but make them well made"). Prices, owning, buying, the loadout, the runner's random pick,
-- cooldowns and old saves. Run from huzz-valley/ or the repo root: lune run tests/AbilityRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local A = Env.load("huzz-valley/src/ReplicatedStorage/Shared/AbilityRules.lua")
local Powers = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Powers.lua")
local fs = require("@lune/fs")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- Prices: every shop ability has a side, a price that fits the coin pay, a cooldown, a counter, a picture or glyph
local Round = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua")
local game, win = Round.Pay.Played, Round.Pay.Won
local runners, catchers, newOnes = 0, 0, 0
for side, list in Powers.Shop do
	for _, name in list do
		local d = Powers[name]
		check(name .. " is in Config/Powers", type(d) == "table")
		check(name .. " is on the " .. side .. " side", d.Side == side)
		check(name .. " has a name, card, text and colour", type(d.Name) == "string" and type(d.Card) == "string" and type(d.Text) == "string" and typeof(d.Accent) == "Color3")
		check(name .. " has a picture or a glyph", type(d.Icon) == "string" or (type(d.Emoji) == "string" and d.Emoji ~= ""))
		check(name .. " says how to beat it", type(d.Counter) == "string" and #d.Counter > 0)
		check(name .. " has a cooldown (or once a round)", d.OncePerRound == true or (type(d.Cooldown) == "number" and d.Cooldown >= 8))
		check(name .. " has a wind-up and a sound", type(Powers.Fx[name]) == "table" and type(Powers.Fx[name].Sound) == "string")
		if d.Starter then
			check(name .. ": a starter costs nothing", d.Price == 0)
		else
			-- between 8 and 40 games' pay: reachable, never a grind
			-- (a game's pay on average: played, and a win half the time; since Oct 21 the pay is lower, owner)
			local avg = game + win / 2
			check(string.format("%s: %d coins is 8 to 40 games' pay", name, d.Price), d.Price >= 8 * avg and d.Price <= 40 * avg)
			check(name .. ": a round number", d.Price % 50 == 0)
		end
		if side == "Runner" then runners += 1 else catchers += 1 end
		if not d.Icon then newOnes += 1 end
		-- (his power pictures, owner Oct 20 20:34: each has a packed picture and his tile's colour)
		if d.Icon and name ~= "SpeedBoost" then
			local file = "assets/icons/" .. d.Icon:gsub("^Ability", "ability"):gsub("(%l)(%u)", "%1-%2"):lower() .. ".png"
			local ok = pcall(fs.readFile, Env.root .. "/huzz-valley/" .. file)
			check(name .. ": his picture " .. file .. " and a Tile colour", ok and typeof(d.Tile) == "Color3")
		end
	end
end
check("6 runner and 4 catcher abilities", runners == 6 and catchers == 4)
check("every ability shows a picture, none a bare glyph (owner Oct 20 20:34: his pictures)", newOnes == 0)
check("Speed Boost is free and never in the shop", Powers.SpeedBoost.Free == true and not table.find(Powers.Shop.Runner, "SpeedBoost"))
check("win pay is more than game pay (sanity)", win > game)

-- Owning
local fresh = { Coins = 0, Abilities = {}, Loadout = {} }
check("a fresh save owns Shield", A.owns(fresh, "Shield"))
check("a fresh save owns Bear Trap and Slow Wave", A.owns(fresh, "BearTrap") and A.owns(fresh, "SlowWave"))
check("a fresh save owns Speed Boost (free)", A.owns(fresh, "SpeedBoost"))
check("a fresh save doesn't own Invisible", not A.owns(fresh, "Invisible"))
check("unknown names aren't owned", not A.owns(fresh, "Fly") and not A.owns(fresh, 5) and not A.owns(fresh, nil) and not A.owns(fresh, "Fx") and not A.owns(fresh, "Keys"))
check("a save with no tables works", A.owns({}, "Shield") and not A.owns({}, "Radar"))

-- Buying
local s = { Coins = 400, Abilities = {}, Loadout = {} }
local ok, why = A.buy(s, "Radar")
check("too few coins: refused and says how many more", not ok and why == "You need 350 more coins." and s.Coins == 400 and not A.owns(s, "Radar"))
s.Coins = 2000
ok = A.buy(s, "Radar")
check("buying takes the price and owns it", ok and s.Coins == 1250 and A.owns(s, "Radar"))
ok, why = A.buy(s, "Radar")
check("can't buy twice", not ok and why == "You own this already." and s.Coins == 1250)
ok, why = A.buy(s, "Shield")
check("a starter can't be bought", not ok and why == "You own this already.")
ok, why = A.buy(s, "SpeedBoost")
check("Speed Boost can't be bought", not ok and why == "Unknown ability." and s.Coins == 1250)
ok, why = A.buy(s, "Fx")
check("a config table that isn't an ability can't be bought", not ok and why == "Unknown ability.")
ok = A.buy(s, { "Radar" })
check("a table as a name is refused", not ok and s.Coins == 1250)
local noTable = { Coins = 600 }
check("buying into an old save without the table works", (A.buy(noTable, "Invisible")) and noTable.Abilities.Invisible == true and noTable.Coins == 100)
local broken = { Coins = "lots", Abilities = {} }
check("bad coins count as none", not (A.buy(broken, "Invisible")))

-- Loadout
local l = A.loadout(fresh)
check("default loadout: Shield, Bear Trap, Slow Wave", l.Runner == "Shield" and l.CatcherQ == "BearTrap" and l.CatcherE == "SlowWave")
local e = { Coins = 0, Abilities = { Lasso = true }, Loadout = {} }
ok = A.equip(e, "CatcherQ", "Lasso")
l = A.loadout(e)
check("equip an owned catcher ability on Q", ok and l.CatcherQ == "Lasso" and l.CatcherE == "SlowWave")
ok = A.equip(e, "CatcherE", "Lasso")
l = A.loadout(e)
check("the same one on E swaps them (never two the same)", ok and l.CatcherE == "Lasso" and l.CatcherQ == "SlowWave")
ok, why = A.equip(e, "CatcherQ", "Radar")
check("can't equip one you don't own", not ok and why == "Buy it first.")
ok, why = A.equip(e, "Runner", "BearTrap")
check("can't put a catcher ability on the runner", not ok and why == "That one is for catchers.")
ok, why = A.equip(e, "CatcherQ", "Shield")
check("can't put a runner ability on the catcher", not ok and why == "That one is for runners.")
ok, why = A.equip(e, "Runner", "SpeedBoost")
check("Speed Boost is never a loadout pick", not ok)
ok, why = A.equip(e, "Pocket", "Shield")
check("unknown slot refused", not ok and why == "Unknown slot.")
ok = A.equip(e, "Runner", "Shield")
check("equip Shield on the runner", ok and A.loadout(e).Runner == "Shield")
ok = A.equip(e, "Runner", "Random")
check("Random back on the runner", ok and A.loadout(e).Runner == "Random")
ok = A.equip(e, "CatcherQ", "Random")
check("Random isn't a catcher pick", not ok)
local stale = { Abilities = {}, Loadout = { Runner = "Invisible", CatcherQ = "Lasso", CatcherE = "Lasso" } }
l = A.loadout(stale)
check("a loadout with ones you don't own plays the defaults", l.Runner == "Shield" and l.CatcherQ == "BearTrap" and l.CatcherE == "SlowWave")
local twin = { Abilities = { Radar = true }, Loadout = { CatcherQ = "Radar", CatcherE = "Radar" } }
l = A.loadout(twin)
check("a saved twin is split", l.CatcherQ == "Radar" and l.CatcherE ~= "Radar" and l.CatcherE ~= nil)
local twin2 = { Abilities = {}, Loadout = { CatcherQ = "SlowWave", CatcherE = "SlowWave" } }
l = A.loadout(twin2)
check("a saved twin of defaults is split", l.CatcherQ ~= l.CatcherE)
check("a junk loadout plays the defaults", A.loadout({ Loadout = { Runner = 7, CatcherQ = {}, CatcherE = "Fx" } }).CatcherE == "SlowWave")

-- Slots: which power is on Q / E for each role
l = A.loadout(e)
check("runner Q is this round's pick", A.slot("Runner", 1, l, "Glitchy") == "Glitchy")
check("runner E is Speed Boost", A.slot("Runner", 2, l, "Glitchy") == "SpeedBoost")
check("catcher Q / E from the loadout", A.slot("Catcher", 1, l) == l.CatcherQ and A.slot("Catcher", 2, l) == l.CatcherE)
check("no slot 3", A.slot("Runner", 3, l) == nil and A.slot(nil, 1, l) == nil)

-- The runner's pick
local r = { Abilities = { Invisible = true, Glitchy = true }, Loadout = { Runner = "Random" } }
local seen, never = {}, true
local last = nil
for i = 1, 200 do
	local p = A.runnerPick(r, last, function(n) return (i * 7) % n + 1 end)
	seen[p] = true
	if p == last then never = false end
	if not A.owns(r, p) or Powers[p].Side ~= "Runner" then never = false end
	last = p
end
check("Random picks only owned runner abilities, never twice in a row", never and seen.Shield and seen.Invisible and seen.Glitchy and not seen.BodyDouble)
check("Random with only Shield owned is Shield", A.runnerPick(fresh, "Shield") == "Shield")
r.Loadout.Runner = "Glitchy"
check("a chosen pick is always that one", A.runnerPick(r, "Glitchy") == "Glitchy")

-- Cooldowns
check("ready at 0", A.canUse(0, 5) and A.canUse(nil, 5))
check("not before it's ready", not A.canUse(10, 9))
check("a press a moment early still counts", A.canUse(10, 10 - A.GRACE + 0.01))
check("used up for the round", not A.canUse(-1, 1e9) and A.left(-1, 0) == math.huge)
check("next ready = cooldown later", A.nextReady("Radar", 100) == 100 + Powers.Radar.Cooldown)
check("Shield: once a round", A.nextReady("Shield", 100) == -1)
check("left counts down", A.left(110, 104) == 6 and A.left(100, 104) == 0)

-- Old saves
local old = { Coins = 50, Cosmetics = {} } -- (made before abilities were bought: no Abilities table)
local gave = A.migrate(old, false)
-- (owner, Oct 22: everyone starts with Shield only, the rest are bought: an old save gets nothing for free now)
check("an old save gets Shield and nothing free", not gave and A.owns(old, "Shield") and not A.owns(old, "Invisible") and not A.owns(old, "Glitchy") and not A.owns(old, "BodyDouble"))
check("an old save gets none of the new ones", not A.owns(old, "BananaPeel") and not A.owns(old, "SmokeBomb") and not A.owns(old, "Radar") and not A.owns(old, "Lasso"))
check("an old save keeps its coins", old.Coins == 50)
check("an old save plays Shield", A.loadout(old).Runner == "Shield")
check("running it again gives nothing", not A.migrate(old, true))
local new = { Coins = 0, Abilities = {}, Loadout = {} }
check("a new save gets no free extras", not A.migrate(new, true) and not A.owns(new, "Invisible"))
check("migrate never throws on junk", not A.migrate(nil, false) and not A.migrate(5, false))

-- The Lasso's pull: the runner's screen makes it; the server checks it and pulls them itself if it didn't happen
local L = Powers.Lasso
check("pulled all the way counts", A.pulled(0, 0, 7, 0, 20, 0, 7))
check("pulled most of the way counts (they may run back a little after)", A.pulled(0, 0, 3, 0, 20, 0, 7))
check("not moved: not pulled", not A.pulled(0, 0, 0, 0, 20, 0, 7))
check("moved away from the catcher: not pulled", not A.pulled(0, 0, -5, 0, 20, 0, 7))
check("moved sideways only: not pulled", not A.pulled(0, 0, 0, 6, 20, 0, 7))
check("a pull of 0 (blocked or already close) needs nothing", A.pulled(0, 0, -9, 0, 20, 0, 0))
check("works on any heading", A.pulled(0, 0, 3, 3, 10, 10, 7) and not A.pulled(0, 0, -3, -3, 10, 10, 7))
check("hussed off before the pull began, then pulled from there: counts (furthest back seen, low)",
	A.pulled(0, 0, -4, 0, 20, 0, 7, A.pullProgress(0, 0, -7, 0, 20, 0)) and not A.pulled(0, 0, -7, 0, 20, 0, 7, -7))
local x, z = A.pullSpot(0, 0, 20, 0, 7)
check("the server's pull ends dist toward the catcher", math.abs(x - 7) < 1e-6 and math.abs(z) < 1e-6)
x, z = A.pullSpot(0, 0, 3, 4, 7)
check("never past where the catcher stood", math.abs(x - 3) < 1e-6 and math.abs(z - 4) < 1e-6)
x, z = A.pullSpot(2, 2, 2, 2, 7)
check("no direction: stays put", x == 2 and z == 2)
check("checked after the pull and a round trip", A.pullCheckAfter(L.PullTime, 0.1) > L.PullTime + 0.2 and A.pullCheckAfter(L.PullTime, nil) > L.PullTime)
check("a slow connection waits at most 1 s more", A.pullCheckAfter(L.PullTime, 5) <= L.PullTime + 1.2)
check("the pull is short enough to judge in a moment (PullTime)", L.PullTime <= 0.5 and L.Pull <= 10)
check("a lasso pull moves only a runner still in play during a run", A.pullHolds("Active", "Running") and A.pullHolds("Active", "HeroRun"))
check("never a safe, caught, downed or out runner (sim Oct 20: pulled back out of the safe zone)",
	not A.pullHolds("Safe", "Running") and not A.pullHolds("Caught", "Running") and not A.pullHolds("Downed", "Running") and not A.pullHolds(nil, "Running"))
check("and never once the round has ended", not A.pullHolds("Active", "RoundOver") and not A.pullHolds("Active", "Lineup") and not A.pullHolds("Active", nil))
local effects = fs.readFile(Env.root .. "/huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/PowerEffects.lua")
check("the runner's screen lets go of the pull the frame it stops holding", string.find(effects, "or not pullHolds(me) then", 1, true) ~= nil and string.find(effects, "root.Anchored or not pullHolds(me) then return end", 1, true) ~= nil)
local powerSrc = fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/PowerService.lua")
check("the server's fallback pull is dropped when it stops holding or the round ends", string.find(powerSrc, "pull.round == roundNo", 1, true) ~= nil
	and string.find(powerSrc, "AbilityRules.pullHolds(match.status[runner]", 1, true) ~= nil and string.find(powerSrc, '"lasso", holds)', 1, true) ~= nil
	and string.find(powerSrc, "PlaceService.lastMoveAt(pl) >= pull.hitClock - 1", 1, true) ~= nil) -- (and when the server moved them round the catch)

-- the server uses these (not its own copies of the rules)
check("PowerService checks every lasso pull and pulls skipped ones through PlaceService", string.find(fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/PowerService.lua"), "PlaceService.place(p, CFrame.new(spot)", 1, true) ~= nil)
local bot = fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/PracticeBot.lua")
check("the Practice Bot loses Invisible runners and slows in smoke", string.find(bot, "not hidden(t)", 1, true) ~= nil and string.find(bot, "function PracticeBot.slow", 1, true) ~= nil)
local power = fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/PowerService.lua")
check("PowerService picks slots with AbilityRules", string.find(power, "AbilityRules.slot", 1, true) ~= nil and string.find(power, "AbilityRules.canUse", 1, true) ~= nil)
local action = fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/ActionService.lua")
check("ActionService buys and equips with AbilityRules", string.find(action, "AbilityRules.buy", 1, true) ~= nil and string.find(action, "AbilityRules.equip", 1, true) ~= nil)
local data = fs.readFile(Env.root .. "/huzz-valley/src/ServerScriptService/HuzzServer/DataService.lua")
check("DataService saves Abilities and Loadout, and migrates old saves", string.find(data, "Abilities = {}", 1, true) ~= nil and string.find(data, "AbilityRules.migrate", 1, true) ~= nil)

print(string.format("AbilityRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("AbilityRules spec failed") end
