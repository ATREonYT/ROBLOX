--!strict
-- Config + pure-util unit tests. Everything required here is plain Luau with
-- zero Roblox API usage, so this runs in the stock `luau` CLI. Service modules
-- (Stack, DataService, ...) touch `game` and are deliberately NOT required.

local Balance = require("../src/ReplicatedStorage/Shared/Config/Balance")
local Ranks = require("../src/ReplicatedStorage/Shared/Config/Ranks")
local Floors = require("../src/ReplicatedStorage/Shared/Config/Floors")
local Gear = require("../src/ReplicatedStorage/Shared/Config/Gear")
local Interns = require("../src/ReplicatedStorage/Shared/Config/Interns")
local Severance = require("../src/ReplicatedStorage/Shared/Config/Severance")
local Format = require("../src/ReplicatedStorage/Shared/Util/Format")
local Sanitize = require("../src/ReplicatedStorage/Shared/Util/Sanitize")

type Case = { name: string, run: () -> () }

-- assert with a "got vs expected" message, because a bare `assertion failed!`
-- from a table-driven test tells you nothing about which row broke.
local function expectEqual(got: any, expected: any, label: string)
	if got ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(got)), 2)
	end
end

-- Float comparisons need a tolerance: perk bonuses stack by repeated addition
-- of decimals like 0.05, which is not exactly representable in binary.
local function expectNear(got: number, expected: number, label: string)
	if math.abs(got - expected) > 1e-9 then
		error(("%s: expected ~%s, got %s"):format(label, tostring(expected), tostring(got)), 2)
	end
end

local function expectContains(text: string?, fragment: string, label: string)
	if not text or not text:find(fragment, 1, true) then
		error(("%s: expected %q inside %s"):format(label, fragment, tostring(text)), 2)
	end
end

local cases: { Case } = {}

local function case(name: string, run: () -> ())
	table.insert(cases, { name = name, run = run })
end

-- ── Interns ─────────────────────────────────────────────────────────────────

case("intern rarity odds sum to exactly 100", function()
	-- The odds are published in the UI as percentages (§7); anything but a
	-- total of 100 is either lying to players or a broken roll table.
	local total = 0
	for _, odds in Interns.RarityOdds do
		total += odds
	end
	expectEqual(total, 100, "sum of RarityOdds")
end)

case("every roster rarity has published odds", function()
	for _, intern in Interns.Roster do
		local odds = Interns.RarityOdds[intern.Rarity]
		if not odds or odds <= 0 then
			error(("roster intern %s has rarity %s with no positive odds"):format(intern.Id, intern.Rarity))
		end
	end
	-- And the display order must cover every odds bucket, or the UI would
	-- silently hide a rarity that can actually roll.
	for rarity in Interns.RarityOdds do
		if not table.find(Interns.RarityOrder, rarity) then
			error(("rarity %s has odds but is missing from RarityOrder"):format(rarity))
		end
	end
end)

case("every rarity in odds has at least one roster intern", function()
	-- Walk RarityOrder (a plain array) rather than the odds map: the previous
	-- case already proves every odds key appears in RarityOrder. The string
	-- casts are because the Rarity singleton union does not survive the CLI's
	-- require-by-string boundary under the analyzer.
	local odds = Interns.RarityOdds :: any
	local ofRarity = Interns.ofRarity :: (string) -> { any }
	for _, rarity in Interns.RarityOrder do
		local chance = odds[rarity]
		if chance and chance > 0 and #ofRarity(rarity) == 0 then
			error(("rarity %s can roll (%d%%) but has no interns to pick from"):format(rarity, chance))
		end
	end
end)

-- ── Ranks ───────────────────────────────────────────────────────────────────

case("rank requirements start at 0 and strictly increase", function()
	expectEqual(Ranks.List[1].Requirement, 0, "first rank requirement")
	for index = 2, #Ranks.List do
		local previous = Ranks.List[index - 1].Requirement
		local current = Ranks.List[index].Requirement
		if current <= previous then
			error(("rank %d (%s) requirement %s is not above rank %d's %s"):format(
				index, Ranks.List[index].Name, tostring(current), index - 1, tostring(previous)))
		end
	end
end)

case("rankForProductivity boundary cases", function()
	expectEqual(Ranks.rankForProductivity(0), 1, "rank at 0")
	expectEqual(Ranks.rankForProductivity(99), 1, "rank at 99")
	-- Exactly hitting a requirement must grant the rank (>= not >), or players
	-- would sit one click short of every promotion.
	expectEqual(Ranks.rankForProductivity(100), 2, "rank at 100")
	expectEqual(Ranks.rankForProductivity(149999), 8, "rank just under Director")
	expectEqual(Ranks.rankForProductivity(150000), 9, "rank at Director threshold")
	expectEqual(Ranks.rankForProductivity(500e6 - 1), 11, "rank just under Chairman")
	expectEqual(Ranks.rankForProductivity(500e6), 12, "rank at 500M (Chairman)")
end)

case("rank helpers: multiplierFor and nextRequirement", function()
	expectNear(Ranks.multiplierFor(1), 1, "multiplier at rank 1")
	expectNear(Ranks.multiplierFor(9), 3, "multiplier at rank 9")
	expectEqual(Ranks.nextRequirement(1), 100, "requirement after rank 1")
	-- math.huge at the cap lets progress bars clamp instead of special-casing.
	expectEqual(Ranks.nextRequirement(#Ranks.List), math.huge, "requirement after top rank")
end)

-- ── Gear ────────────────────────────────────────────────────────────────────

case("nextTierCost follows BaseCost * growth^owned and stops at max", function()
	-- Gear.luau keeps the growth factor as a literal so it stays requirable
	-- offline; this pins the literal to Balance so they can never drift apart.
	expectNear(Balance.GearCostGrowth, 1.12, "Balance.GearCostGrowth")
	for _, ladder in Gear.Ladders do
		for owned = 0, #ladder.Tiers - 1 do
			local tier = ladder.Tiers[owned + 1]
			local expected = math.floor(tier.BaseCost * Balance.GearCostGrowth ^ owned + 0.5)
			local got = Gear.nextTierCost(ladder.Id, owned)
			expectEqual(got, expected, ("%s cost with %d owned"):format(ladder.Id, owned))
		end
		expectEqual(Gear.nextTierCost(ladder.Id, #ladder.Tiers), nil, ladder.Id .. " cost at max")
		expectEqual(Gear.nextTierCost(ladder.Id, 99), nil, ladder.Id .. " cost past max")
	end
	expectEqual(Gear.nextTierCost("Typewriter", 0), nil, "cost on unknown ladder")
end)

case("gear stat helpers fall back safely at tier 0", function()
	expectEqual(Gear.keyboardMultiplier(0), 1, "keyboard multiplier unowned")
	expectNear(Gear.keyboardMultiplier(1), 1.2, "keyboard multiplier tier 1")
	expectEqual(Gear.chairIdleRate(0), 0, "chair idle unowned")
	-- Compare against the config table, not a pinned number: chair Values are
	-- tunable balance knobs, and this case is about the helper's indexing.
	local chairLadder = Gear.getLadder("Chair")
	assert(chairLadder, "Chair ladder must exist")
	expectEqual(Gear.chairIdleRate(2), chairLadder.Tiers[2].Value, "chair idle tier 2")
	expectEqual(Gear.coffeeCooldownMultiplier(0), 1, "coffee multiplier unowned")
	expectNear(Gear.coffeeCooldownMultiplier(5), 0.35, "coffee multiplier tier 5")
end)

-- ── Floors ──────────────────────────────────────────────────────────────────

case("canEnter: the starting floor is always open", function()
	local ok, reason = Floors.canEnter("Mailroom", 1, 0, {})
	expectEqual(ok, true, "fresh player enters Mailroom")
	expectEqual(reason, nil, "no lock reason on Mailroom")
end)

case("canEnter: rank gate blocks and unblocks", function()
	local ok, reason = Floors.canEnter("CubicleFarm", 3, 0, { "Mailroom" })
	expectEqual(ok, false, "rank 3 into CubicleFarm")
	expectContains(reason, "rank 4", "rank-gate reason")

	ok = Floors.canEnter("CubicleFarm", 4, 0, { "Mailroom" })
	expectEqual(ok, true, "rank 4 + boss into CubicleFarm")
end)

case("canEnter: boss gate blocks until that floor's boss is beaten", function()
	local ok, reason = Floors.canEnter("CubicleFarm", 4, 0, {})
	expectEqual(ok, false, "no Mailroom boss kill")
	expectContains(reason, "Mailroom", "boss-gate reason names the floor")
end)

case("canEnter: restructure gate blocks and unblocks", function()
	local bosses = { "Mailroom", "CubicleFarm" }
	local ok, reason = Floors.canEnter("OpenPlan", 12, 1, bosses)
	expectEqual(ok, false, "1 restructure into OpenPlan")
	expectContains(reason, "2 Restructures", "restructure-gate reason")

	ok = Floors.canEnter("OpenPlan", 12, 2, bosses)
	expectEqual(ok, true, "2 restructures + bosses into OpenPlan")
end)

case("canEnter: unknown floor is refused, not errored", function()
	-- The id ultimately comes from a client remote, so garbage must come back
	-- as a polite (false, reason) instead of a server error.
	local ok, reason = Floors.canEnter("Atrium", 99, 99, { "Mailroom" })
	expectEqual(ok, false, "unknown floor")
	expectContains(reason, "Unknown floor", "unknown-floor reason")
end)

-- ── Severance ───────────────────────────────────────────────────────────────

case("effects: empty perk list means neutral effects", function()
	local effects = Severance.effects({})
	expectNear(effects.WinsBonus, 0, "WinsBonus")
	expectEqual(effects.ExtraInternSlots, 0, "ExtraInternSlots")
	expectNear(effects.RivalHeadStart, 0, "RivalHeadStart")
	expectNear(effects.IdleBonus, 0, "IdleBonus")
	expectEqual(effects.SkipFirstRank, false, "SkipFirstRank")
	expectNear(effects.ClickBonus, 0, "ClickBonus")
end)

case("effects: repeatable perks stack additively", function()
	local owned = {
		"GoldenParachute", "GoldenParachute",
		"Networking", "Networking", "Networking",
		"CornerOffice", "CornerOffice",
		"LinkedInfluencer",
		"InsiderKnowledge",
		"Nepotism",
	}
	local effects = Severance.effects(owned)
	expectNear(effects.WinsBonus, 0.20, "WinsBonus x2")
	expectEqual(effects.ExtraInternSlots, 3, "ExtraInternSlots x3")
	expectNear(effects.IdleBonus, 0.10, "IdleBonus x2")
	expectNear(effects.ClickBonus, 0.05, "ClickBonus x1")
	expectNear(effects.RivalHeadStart, 0.10, "RivalHeadStart")
	expectEqual(effects.SkipFirstRank, true, "SkipFirstRank")
end)

case("offerablePool drops owned non-repeatables only", function()
	local pool = Severance.offerablePool({})
	expectEqual(#pool, #Severance.List, "fresh pool offers everything")

	pool = Severance.offerablePool({ "Nepotism", "InsiderKnowledge", "GoldenParachute" })
	expectEqual(table.find(pool, "Nepotism"), nil, "owned Nepotism removed")
	expectEqual(table.find(pool, "InsiderKnowledge"), nil, "owned InsiderKnowledge removed")
	if not table.find(pool, "GoldenParachute") then
		error("repeatable GoldenParachute must stay offerable after being picked")
	end
	expectEqual(#pool, #Severance.List - 2, "pool size after two non-repeatables")
end)

-- ── Format ──────────────────────────────────────────────────────────────────

case("abbreviate covers the display boundaries", function()
	expectEqual(Format.abbreviate(0), "0", "abbreviate 0")
	expectEqual(Format.abbreviate(999), "999", "abbreviate 999")
	expectEqual(Format.abbreviate(1000), "1K", "abbreviate 1000")
	expectEqual(Format.abbreviate(1234), "1.23K", "abbreviate 1234")
	expectEqual(Format.abbreviate(1.5e6), "1.5M", "abbreviate 1.5M")
	expectEqual(Format.abbreviate(2.5e15), "2.5Qa", "abbreviate 2.5Qa")
	expectEqual(Format.abbreviate(-1234), "-1.23K", "abbreviate negative")
	-- NaN can only reach the display through a bug elsewhere, but the label
	-- must still render something instead of crashing the HUD.
	expectEqual(Format.abbreviate(0 / 0), "0", "abbreviate NaN")
end)

case("commas groups thousands", function()
	expectEqual(Format.commas(0), "0", "commas 0")
	expectEqual(Format.commas(999), "999", "commas 999")
	expectEqual(Format.commas(1000), "1,000", "commas 1000")
	expectEqual(Format.commas(1234567), "1,234,567", "commas 1234567")
	expectEqual(Format.commas(-1234567), "-1,234,567", "commas negative")
end)

-- ── Sanitize ────────────────────────────────────────────────────────────────

case("stat squashes NaN/inf and clamps the range", function()
	expectEqual(Sanitize.stat(0 / 0), 0, "NaN -> default fallback")
	expectEqual(Sanitize.stat(0 / 0, 7), 7, "NaN -> explicit fallback")
	expectEqual(Sanitize.stat(math.huge), 0, "inf -> fallback")
	expectEqual(Sanitize.stat(-math.huge, 3), 3, "-inf -> fallback")
	expectEqual(Sanitize.stat(-5), 0, "negative clamps to 0")
	expectEqual(Sanitize.stat(1e301), 1e300, "overflow clamps to MaxNumber")
	expectEqual(Sanitize.stat(42), 42, "sane value passes through")
end)

case("validateSavable accepts the profile template shape", function()
	-- Inline copy of DataService.Template: DataService itself requires `game`
	-- services, so it cannot load under the plain Luau CLI. If the template
	-- shape changes there, mirror it here — this is the save-safety canary.
	local template = {
		DataVersion = 1,
		Productivity = 0,
		Wins = 0,
		Rank = 1,
		Restructures = 0,
		BestRank = 1,
		TotalClicks = 0,
		Gear = { Keyboard = 0, Chair = 0, Coffee = 0 },
		Severance = {},
		PendingSeverance = {},
		Interns = {},
		EquippedInterns = {},
		BossesDefeated = {},
		PurchaseLog = {},
		FirstJoinTime = 0,
	}
	local ok, why = Sanitize.validateSavable(template)
	expectEqual(ok, true, "template is savable (" .. tostring(why) .. ")")

	-- A populated profile must pass too — arrays of tables are the shape
	-- Interns/Severance actually take at runtime.
	local populated = {
		DataVersion = 1,
		Productivity = 123456,
		Wins = 789,
		Rank = 5,
		Restructures = 2,
		BestRank = 9,
		TotalClicks = 4200,
		Gear = { Keyboard = 3, Chair = 2, Coffee = 1 },
		Severance = { "GoldenParachute", "GoldenParachute" },
		PendingSeverance = {},
		Interns = { { Uid = "abc", Id = "CoffeeRunner" }, { Uid = "def", Id = "Consultant" } },
		EquippedInterns = { "abc" },
		BossesDefeated = { "Mailroom" },
		PurchaseLog = { "grant_StarterPack" },
		FirstJoinTime = 1756500000,
	}
	ok, why = Sanitize.validateSavable(populated)
	expectEqual(ok, true, "populated profile is savable (" .. tostring(why) .. ")")
end)

case("validateSavable rejects unsavable shapes", function()
	-- Real userdata (Vector3 etc.) does not exist outside Roblox, so a function
	-- value stands in for "not a JSON type" here; typeof() reports both the
	-- same way (a non-primitive kind name).
	local withFunction = { Gear = { Keyboard = function() end } }
	local ok, why = Sanitize.validateSavable(withFunction)
	expectEqual(ok, false, "function value refused")
	expectContains(why, "function", "function reason")

	local mixedKeys = { [1] = "a", Name = "b" }
	ok, why = Sanitize.validateSavable(mixedKeys)
	expectEqual(ok, false, "mixed keys refused")
	expectContains(why, "mixes", "mixed-key reason")

	-- Sparse arrays JSON-encode as objects and come back as string-keyed maps.
	local sparse: { [number]: number } = {}
	sparse[1] = 1
	sparse[2] = 2
	sparse[4] = 4
	ok, why = Sanitize.validateSavable({ PurchaseLog = sparse })
	expectEqual(ok, false, "sparse array refused")
	expectContains(why, "sparse", "sparse reason")

	ok, why = Sanitize.validateSavable({ Productivity = 0 / 0 })
	expectEqual(ok, false, "NaN refused")
	expectContains(why, "NaN", "NaN reason")
end)

return { name = "config_spec", cases = cases }
