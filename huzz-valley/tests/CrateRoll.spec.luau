-- Crate maths: odds add to 100, the weights are honest, and pity guarantees the top prize on time.
-- lune run tests/CrateRoll.spec.luau   (from huzz-valley/)
local CrateRoll = require("../src/ReplicatedStorage/Shared/CrateRoll")
local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local crate = {
	Id = "Test", Price = 50, Pity = { After = 10, Rarity = "Legendary" },
	Items = {
		{ Kind = "Coins", Amount = 100, Name = "Coins", Rarity = "Common", Weight = 70 },
		{ Kind = "Cosmetic", Id = "A", Name = "A", Rarity = "Rare", Weight = 25 },
		{ Kind = "Cosmetic", Id = "B", Name = "B", Rarity = "Legendary", Weight = 5 },
	},
}
local sum = 0
for _, o in CrateRoll.odds(crate) do sum += o.chance end
check("odds add to 100", math.abs(sum - 100) < 1e-6)
-- a seeded generator
local state = 12345
local function rand()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
-- weights are honest over many opens (no pity in the way: huge After)
local free = table.clone(crate); free.Pity = { After = 1e9, Rarity = "Legendary" }
local counts, pity = { Common = 0, Rare = 0, Legendary = 0 }, 0
for _ = 1, 20000 do
	local item; item, pity = CrateRoll.roll(free, pity, rand)
	counts[item.Rarity] += 1
end
check("common about 70%", math.abs(counts.Common / 20000 - 0.70) < 0.02)
check("legendary about 5%", math.abs(counts.Legendary / 20000 - 0.05) < 0.01)
-- pity: never more than After-1 opens in a row without a Legendary
local longest, run = 0, 0
pity = 0
for _ = 1, 5000 do
	local item; item, pity = CrateRoll.roll(crate, pity, rand)
	if item.Rarity == "Legendary" then run = 0 else run += 1 end
	longest = math.max(longest, run)
end
check("pity: at most 9 opens without a Legendary", longest <= 9)
-- the pity counter resets on the top prize and counts otherwise
local item, nextPity = CrateRoll.roll(crate, 9, function() return 0 end)
check("10th open is the top prize", item.Rarity == "Legendary" and nextPity == 0)
item, nextPity = CrateRoll.roll(crate, 2, function() return 0 end)
check("a common open counts up", item.Rarity == "Common" and nextPity == 3)

-- opens left until the top prize is certain (shown as "Legendary guaranteed in N opens")
check("left: fresh crate shows After", CrateRoll.left(crate, 0) == 10)
check("left: 1 = the next open", CrateRoll.left(crate, 9) == 1)
check("left: no pity, no counter", CrateRoll.left({ Items = crate.Items }, 3) == nil)
-- duplicates pay coins back: one number, or one per rarity
check("dupe coins: a number", CrateRoll.dupeCoins({ Duplicate = 120 }, crate.Items[2]) == 120)
check("dupe coins: by rarity", CrateRoll.dupeCoins({ Duplicate = { Rare = 200 } }, crate.Items[2]) == 200)
check("dupe coins: none", CrateRoll.dupeCoins({}, crate.Items[2]) == 0)
check("indexOf finds the item", CrateRoll.indexOf(crate, crate.Items[3]) == 3)

-- The reel (kid-safe: honest filler, nothing planted): the prize sits where the server says, and every other card is
-- a plain draw with the shown odds (never pity: a reel near the guarantee still shows mostly Commons).
local strip = CrateRoll.strip(crate, 3, 48, 40, rand)
check("strip length", #strip == 48)
check("strip: prize at its spot", strip[40] == 3)
local tally, cards = { 0, 0, 0 }, 0
for _ = 1, 400 do
	local s = CrateRoll.strip(crate, 3, 48, 40, rand)
	for i, v in s do
		if i ~= 40 then tally[v] += 1; cards += 1 end
	end
end
check("strip filler: commons about 70%", math.abs(tally[1] / cards - 0.70) < 0.02)
check("strip filler: legendaries about 5%", math.abs(tally[3] / cards - 0.05) < 0.01)
-- next to the stop is no likelier to be the top prize than anywhere else (no near-miss teasing)
local beside, n = 0, 0
for _ = 1, 3000 do
	local s = CrateRoll.strip(crate, 1, 48, 40, rand)
	for _, i in { 39, 41 } do
		n += 1
		if s[i] == 3 then beside += 1 end
	end
end
check("strip: legendary beside the stop only at its real 5%", math.abs(beside / n - 0.05) < 0.012)

-- Every live crate: odds add to 100, every rarity is real, the guarantee is a real rarity in it, the reel
-- fits the prize. (That every item exists in CoinShop / Dances is checked in tools/preview/check_crates.luau.)
local Env = require("../tools/preview/motion3d/env") -- (Config/Crates reads Config/CoinShop through script.Parent)
local Crates = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Crates.lua")
for _, c in Crates.List do
	local total, hasTop = 0, false
	for _, it in c.Items do
		total += it.Weight
		check(c.Id .. ": " .. it.Name .. " has a real rarity", CrateRoll.RANK[it.Rarity] ~= nil)
		check(c.Id .. ": " .. it.Name .. " has a kind", it.Kind == "Coins" or it.Kind == "Cosmetic" or it.Kind == "Dance")
		if c.Pity and CrateRoll.RANK[it.Rarity] >= CrateRoll.RANK[c.Pity.Rarity] then hasTop = true end
	end
	check(c.Id .. ": weights add up", total > 0)
	check(c.Id .. ": has a pity counter", c.Pity ~= nil and c.Pity.After > 0)
	check(c.Id .. ": its guarantee can come out", hasTop)
	check(c.Id .. ": price in Aura", c.Price > 0)
end
check("reel: prize card inside the reel", Crates.Reel.At < Crates.Reel.Length and Crates.Reel.At > 5)
print(string.format("CrateRoll: %d passed, %d failed", passed, failed))
if failed > 0 then error("CrateRoll spec failed") end
