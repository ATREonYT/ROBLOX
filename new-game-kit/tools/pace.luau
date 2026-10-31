--!nonstrict
-- New Game Kit: pacing check (vault notes 12 §3 and 14 §7). Plays the economy in Config
-- second by second with a bot that plays well but not perfectly, and checks each beat
-- against Config.Pacing (time from join, in seconds; a beat passes within `tolerance`).
--   lune run tools/pace.luau            (from the game folder; under a second)
-- It uses the server's own formulas: income = (perSecond + Income upgrade + taps) times
-- every multiplier (rebirths 1 + n*bonus, upgrades 1 + level*perLevel, pets 1 + sum of boosts,
-- multiplied together, as Currency.combineMultipliers does). Pets count at their average boost.
-- It is a model, not the server: change a formula in src/Server and this file together.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Config = luau.load(fs.readFile("src/Config/GameConfig.luau"), { debugName = "GameConfig" })()
local P = Config.Pacing
if not P then
	print("[KitPace] no Config.Pacing: skipped")
	process.exit(0)
end

local TAPS = P.botTapsPerSecond or 4 -- a kid tapping, not an auto-clicker
local inc, up, reb = Config.Income, Config.Upgrades.upgrades, Config.Rebirth
local egg = Config.Eggs.eggs[P.egg or "Basic"]

-- Average pet boost from one hatch of the egg (weights inside each tier, tiers by weight).
local avgBoost = 0
do
	local total = 0
	for _, tier in egg.tiers do
		total += tier.weight
	end
	for _, tier in egg.tiers do
		local w = 0
		for _, item in tier.items do
			w += item.weight
		end
		for _, item in tier.items do
			avgBoost += (tier.weight / total) * (item.weight / w) * (Config.Pets.boosts[item.id] or 0)
		end
	end
end

local s = { t = 0, coins = 0, levels = {}, pets = 0, rebirths = 0 }
local beats = {}
local function mark(name)
	if beats[name] == nil then
		beats[name] = s.t
	end
end
local function level(key)
	return s.levels[key] or 0
end
local function mult()
	local m = 1 + s.rebirths * reb.bonusPerRebirth
	for key, def in up do
		if def.effect.kind == "multiplier" and def.effect.currency == inc.currency then
			m *= 1 + level(key) * def.effect.perLevel
		end
	end
	return m * (1 + s.pets * avgBoost)
end
local function perSecond(levels, pets)
	local saved, savedPets = s.levels, s.pets
	s.levels, s.pets = levels or s.levels, pets or s.pets
	local base = inc.perSecond + (up.Income and level("Income") * up.Income.effect.perLevel or 0) + (inc.tap or 0) * TAPS
	local v = base * mult()
	s.levels, s.pets = saved, savedPets
	return v
end
local function upgradeCost(key)
	local def = up[key]
	return math.floor(def.baseCost * def.growth ^ level(key))
end
local function rebirthCost()
	return math.floor(reb.baseCost * reb.growth ^ s.rebirths)
end

-- One buy per second at most: the best gain per coin among the upgrades that pay and a pet.
local function shop()
	local best, bestScore, bestCost = nil, 0, 0
	local now = perSecond()
	for key, def in up do
		if level(key) < def.maxLevel and (def.effect.kind == "multiplier" or key == "Income") then
			local cost = upgradeCost(key)
			local after = table.clone(s.levels)
			after[key] = level(key) + 1
			local score = (perSecond(after) - now) / cost
			if cost <= s.coins and score > bestScore then
				best, bestScore, bestCost = key, score, cost
			end
		end
	end
	if s.pets < (Config.Inventory.maxEquipped or 3) then
		local cost = egg.price.amount
		local score = (perSecond(nil, s.pets + 1) - now) / cost
		if cost <= s.coins and score > bestScore then
			best, bestScore, bestCost = "Pet", score, cost
		end
	end
	if best then
		s.coins -= bestCost
		if best == "Pet" then
			s.pets += 1
			mark("firstHatch")
		else
			s.levels[best] = level(best) + 1
		end
		mark("firstPurchase")
	end
end

local LIMIT = P.maxSeconds or 3 * 3600
local wanted = #(P.rebirths or {})
while s.t < LIMIT and s.rebirths < wanted do
	s.t += 1
	s.coins += perSecond()
	mark("firstPayoff")
	-- Save for the rebirth once it's within reach (a kid sees "94%"), otherwise shop.
	if s.coins >= rebirthCost() then
		s.rebirths += 1
		s.coins = 0
		for key, def in up do
			if def.keepOnRebirth == false then
				s.levels[key] = 0
			end
		end
		beats["rebirth" .. s.rebirths] = s.t
	elseif s.coins < rebirthCost() * (P.saveAt or 0.6) then
		shop()
	end
end

local tol = P.tolerance or 0.3
local passed, failed = 0, 0
-- "first…" beats are deadlines (sooner is fine); rebirths must land near their time both ways,
-- or the game is too slow or runs out of content too fast.
local function check(name, target)
	local got = beats[name]
	local deadline = string.sub(name, 1, 5) == "first"
	local ok = got ~= nil and (if deadline then got <= target * (1 + tol) else math.abs(got - target) <= target * tol)
	if ok then
		passed += 1
	else
		failed += 1
	end
	print(string.format("  %s %-14s target %5ds  got %s", if ok then "ok  " else "FAIL", name, target, if got then string.format("%5ds", got) else "never"))
end
print(`[KitPace] bot taps {TAPS}/s; average pet +{math.floor(avgBoost * 100)}%; tolerance {math.floor(tol * 100)}%`)
for _, name in { "firstPayoff", "firstPurchase", "firstHatch" } do
	if P[name] then
		check(name, P[name])
	end
end
for i, target in P.rebirths or {} do
	check("rebirth" .. i, target)
end
print(`[KitPace] {passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
