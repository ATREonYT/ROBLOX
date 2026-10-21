-- Spin the Wheel: the shown odds are exact, the pity guarantees a Legendary by spin 40, the free spin comes once
-- every 15 minutes, owned spins count down, nothing changes when you can't spin, and the wheel lands on the slice
-- the server picked.  lune run tests/SpinWheel.spec.luau   (from huzz-valley/)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CrateRoll = require("../src/ReplicatedStorage/Shared/CrateRoll")
local SpinRules = require("../src/ReplicatedStorage/Shared/SpinRules")
local Wheel = luau.load(fs.readFile("src/ReplicatedStorage/Shared/Config/SpinWheel.lua"), { debugName = "SpinWheel", environment = { Color3 = roblox.Color3 } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- the wheel itself
check("8 slices", #Wheel.Items == 8)
local sum, legendary = 0, 0
for i, o in CrateRoll.odds(Wheel) do
	sum += o.chance
	check("odds shown = weight for " .. o.item.Key, math.abs(o.chance - o.item.Weight) < 1e-9)
	check("slot number for " .. o.item.Key, o.item.Slot == i)
	if o.item.Rarity == "Legendary" then legendary += 1 end
end
check("odds add to 100", math.abs(sum - 100) < 1e-9)
check("exactly one Legendary", legendary == 1)
check("pity at 40", Wheel.Pity.After == 40 and Wheel.Pity.Rarity == "Legendary")
check("free spin every 15 minutes", Wheel.FreeEvery == 900)

local state = 99
local function rand()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
local function roll(pity) return CrateRoll.roll(Wheel, pity, rand) end

-- honest odds over many spins (pity out of the way)
local free = table.clone(Wheel); free.Pity = { After = 1e9, Rarity = "Legendary" }
local counts, pity = {}, 0
local N = 50000
for _ = 1, N do
	local item; item, pity = CrateRoll.roll(free, pity, rand)
	counts[item.Key] = (counts[item.Key] or 0) + 1
end
for _, item in Wheel.Items do
	check(`{item.Key} comes up about {item.Weight}%`, math.abs((counts[item.Key] or 0) / N * 100 - item.Weight) < 0.8)
end

-- pity: never 40 spins in a row without the Legendary, and the counter resets on it
local longest, run = 0, 0
pity = 0
for _ = 1, 20000 do
	local item; item, pity = roll(pity)
	if item.Rarity == "Legendary" then run = 0 else run += 1 end
	longest = math.max(longest, run)
end
check("pity: at most 39 spins without a Legendary", longest <= 39)
local item, nextPity = CrateRoll.roll(Wheel, 39, function() return 0.99 end)
check("the 40th spin is the Legendary", item.Rarity == "Legendary" and nextPity == 0)

-- spending spins: the free one first, then owned ones; nothing changes when you can't
local T = 1000000
local d = { Coins = 0, Aura = 0, Spins = 0, FreeSpinAt = 0, SpinPity = 0, Boosts = {}, Cosmetics = {}, Wear = {} }
local ok, res = SpinRules.spin(d, Wheel, 1, T, roll)
check("a new player has a free spin", ok and res.usedFree == true and d.FreeSpinAt == T + 900 and d.Spins == 0)
check("pity counts the spin", d.SpinPity == (if res.rolls[1].Rarity == "Legendary" then 0 else 1))
local before = table.clone(d)
ok, res = SpinRules.spin(d, Wheel, 1, T + 60, roll)
check("no second free spin within 15 minutes", ok == false and d.FreeSpinAt == before.FreeSpinAt and d.Coins == before.Coins and d.SpinPity == before.SpinPity)
check("the refusal says when the free spin comes", type(res) == "string" and res:find("14m 00s") ~= nil)
ok = SpinRules.spin(d, Wheel, 1, T + 900, roll)
check("free again after 15 minutes", ok == true and d.FreeSpinAt == T + 1800)
d.Spins = 3
ok = SpinRules.spin(d, Wheel, 1, T + 901, roll)
check("an owned spin counts down", ok == true and d.Spins == 2 and d.FreeSpinAt == T + 1800)
ok, res = SpinRules.spin(d, Wheel, 5, T + 902, roll)
check("x5 refused with 2 spins, nothing taken", ok == false and d.Spins == 2 and res:find("3 more spins") ~= nil)
d.Spins = 4
local coinsBefore = d.Coins
ok, res = SpinRules.spin(d, Wheel, 5, T + 1800, roll)
check("x5 uses the free spin plus 4 owned", ok == true and d.Spins == 0 and res.usedFree and #res.rolls == 5)
check("x5 gives something", d.Coins > coinsBefore or d.Aura > 0 or (d.Boosts.Coins or 0) > 0)
check("bad counts refused", (SpinRules.spin(d, Wheel, 0, T, roll)) == false and (SpinRules.spin(d, Wheel, 2.5, T, roll)) == false and (SpinRules.spin(d, Wheel, 0 / 0, T, roll)) == false)

-- what each slice gives
local function only(key) return function(p) local it = Wheel.Items[Wheel.slotOf(key)]; return it, (if it.Rarity == "Legendary" then 0 else p + 1) end end
local g = { Coins = 0, Aura = 0, Spins = 10, FreeSpinAt = T + 999, SpinPity = 0, Boosts = {}, Cosmetics = {}, Wear = {} }
SpinRules.spin(g, Wheel, 1, T, only("Coins500")); check("the Coins500 slice: 250 coins (lowered Oct 21)", g.Coins == 250)
SpinRules.spin(g, Wheel, 1, T, only("Aura60")); check("the Aura60 slice: 40 Aura (lowered Oct 21)", g.Aura == 40)
SpinRules.spin(g, Wheel, 1, T, only("CoinBoost")); check("x2 coins for 15 minutes", g.Boosts.Coins == T + 900 and SpinRules.boost(g, "Coins", T + 899) == 2 and SpinRules.boost(g, "Coins", T + 900) == 1)
SpinRules.spin(g, Wheel, 1, T + 100, only("CoinBoost")); check("a second boost adds its minutes", g.Boosts.Coins == T + 1800)
check("no boost = x1", SpinRules.boost({}, "Coins", T) == 1)
SpinRules.spin(g, Wheel, 1, T, only("SpinKnife")); check("the Spin Knife is yours and worn", g.Cosmetics.SpinKnife == true and g.Wear.Knife == "SpinKnife" and g.SpinPity == 0)
local c0 = g.Coins
ok, res = SpinRules.spin(g, Wheel, 1, T, only("SpinKnife")); check("a second Spin Knife becomes 1500 coins", g.Coins == c0 + 1500 and res.rolls[1].Duplicate == true)
g.Wear.Knife = "IceKnife"; g.Cosmetics.SpinKnife = nil
SpinRules.spin(g, Wheel, 1, T, only("SpinKnife")); check("winning it keeps the knife you wear", g.Wear.Knife == "IceKnife")

-- the wheel lands on the server's slice, with the offset inside the slice
local rot = 0
for slot = 1, 8 do
	for _, off in { -20, 0, 20 } do
		local target = SpinRules.landRotation(rot, slot, 5, off)
		check(`lands on slice {slot} (offset {off})`, SpinRules.slotAt(target) == slot and target >= rot + 5 * 360 and target < rot + 6 * 360)
		rot = target
	end
end
check("slice under the pointer at rest", SpinRules.slotAt(0) == 1 and SpinRules.slotAt(-45) == 2 and SpinRules.slotAt(45) == 8)
check("one tick per slice edge", SpinRules.edges(22.4) == 0 and SpinRules.edges(22.6) == 1 and SpinRules.edges(360 + 22.6) == 9)
check("a multi-spin lands on its best prize", SpinRules.best({ { Rarity = "Common" }, { Rarity = "Epic" }, { Rarity = "Rare" }, { Rarity = "Epic" } }, CrateRoll.RANK) == 2)
check("clock text", SpinRules.clock(887) == "14m 47s" and SpinRules.clock(9) == "9s")
check("pity text count", SpinRules.pityLeft({ SpinPity = 28 }, 40) == 12 and SpinRules.pityLeft({ SpinPity = 39 }, 40) == 1)

print(string.format("SpinWheel: %d passed, %d failed", passed, failed))
if failed > 0 then error("SpinWheel spec failed") end
