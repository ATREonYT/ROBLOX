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
print(string.format("CrateRoll: %d passed, %d failed", passed, failed))
if failed > 0 then error("CrateRoll spec failed") end
