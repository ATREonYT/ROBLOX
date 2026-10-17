-- The girl roll is fair: rarities come up at their stated chances, girls within a rarity evenly,
-- empty rarities never, and the strip holds the winner where the roller stops.
local GirlRoll = require("../src/ReplicatedStorage/Shared/GirlRoll")

local rarities = {
	{ Name = "Common", Weight = 50 }, { Name = "Uncommon", Weight = 25 }, { Name = "Rare", Weight = 13 },
	{ Name = "Epic", Weight = 7 }, { Name = "Legendary", Weight = 3.5 }, { Name = "Mythic", Weight = 1.2 },
	{ Name = "Secret", Weight = 0.3 },
}
local catalog = {}
for _, r in rarities do
	if r.Name ~= "Mythic" then -- one rarity with no girls
		for i = 1, (if r.Name == "Common" then 4 else 2) do
			table.insert(catalog, { id = r.Name .. i, name = r.Name .. " " .. i, rarity = r.Name })
		end
	end
end

math.randomseed(7)
local rand = math.random

local failed = 0
local function check(ok, msg)
	if not ok then
		failed += 1
		print("FAIL: " .. msg)
	end
end

-- Odds skip the empty rarity and add up to 100.
local odds = GirlRoll.odds(catalog, rarities)
local total, names = 0, {}
for _, o in odds do
	total += o.chance
	table.insert(names, o.name)
end
check(math.abs(total - 100) < 1e-6, "odds add up to 100")
check(table.concat(names, ",") == "Common,Uncommon,Rare,Epic,Legendary,Secret", "odds in order, no empty rarity")
check(math.abs(odds[1].chance - 50 / 98.8 * 100) < 1e-6, "Common chance is its weight share")

-- 200k draws land on every rarity at its chance (within 0.35 percentage points) and spread evenly.
local N = 200000
local counts, perGirl = {}, {}
for _ = 1, N do
	local g = GirlRoll.pick(catalog, rarities, rand)
	counts[g.rarity] = (counts[g.rarity] or 0) + 1
	perGirl[g.id] = (perGirl[g.id] or 0) + 1
end
for _, o in odds do
	local got = (counts[o.name] or 0) / N * 100
	check(math.abs(got - o.chance) < 0.35, `{o.name}: {got}% vs {o.chance}%`)
end
check(counts.Mythic == nil, "never an empty rarity")
check(counts.Secret and counts.Secret > 0, "Secrets do come up")
for i = 1, 4 do
	local share = perGirl["Common" .. i] / counts.Common
	check(math.abs(share - 0.25) < 0.02, "Commons evenly " .. share)
end

-- The strip: the winner sits where the roller stops, the rest are real girls.
local winner = catalog[#catalog]
local strip = GirlRoll.strip(catalog, rarities, winner, 40, 34, rand)
check(#strip == 40 and strip[34] == winner, "winner at the stop")
for _, g in strip do
	check(g ~= nil and g.rarity ~= nil, "every cell is a girl")
end
check(GirlRoll.pick({}, rarities, rand) == nil, "empty catalog -> nil")

print(if failed == 0 then "GirlRoll ok" else `GirlRoll: {failed} failed`)
if failed > 0 then
	error("GirlRoll tests failed")
end
