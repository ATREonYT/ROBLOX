-- ═══════════════════════════════════════════════════════════════════════════
-- STACK SPEC — executes the real multiplier stack (§9 of the brief):
--   total = (rank x gear x intern x restructure) x robux
-- The Robux factor sitting OUTSIDE the earned parenthesis is the one property
-- the brief is emphatic about, so it gets checked directly rather than assumed.
-- ═══════════════════════════════════════════════════════════════════════════

local Stack = __require("Stack")
local Balance = __require("Balance")
local Ranks = __require("Ranks")
local Gear = __require("Gear")

local passed, failed = 0, 0
local failures = {}

local function check(name, condition, detail)
	if condition then
		passed += 1
		print(("  PASS  %s"):format(name))
	else
		failed += 1
		local line = ("  FAIL  %s%s"):format(name, if detail then " — " .. detail else "")
		print(line)
		table.insert(failures, line)
	end
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-9) * math.max(1, math.abs(b))
end

-- A blank player: rank 1, no gear, no interns, no perks, no restructures.
local function fresh()
	return {
		Rank = 1,
		Restructures = 0,
		Gear = { Keyboard = 0, Chair = 0, Coffee = 0 },
		Severance = {},
		Interns = {},
		EquippedInterns = {},
	}
end

local NO_PASSES = {}

print("═══ MULTIPLIER STACK ═══\n")

-- ── Baseline ──────────────────────────────────────────────────────────────
check("a fresh click is worth exactly the base gain",
	near(Stack.clickIncome(fresh(), NO_PASSES), Balance.BaseClickGain))
check("a fresh player earns nothing while idle",
	Stack.idlePerSecond(fresh(), NO_PASSES) == 0)

-- ── Rank multiplier: 1 + (rank-1) * 0.25 ──────────────────────────────────
local rankOk = true
for rank = 1, #Ranks.List do
	local data = fresh()
	data.Rank = rank
	local want = Balance.BaseClickGain * (1 + (rank - 1) * 0.25)
	if not near(Stack.clickIncome(data, NO_PASSES), want) then rankOk = false end
end
check("click income tracks the rank multiplier at every rank", rankOk)

-- ── Gear multiplier ───────────────────────────────────────────────────────
local gearOk = true
for tier = 1, 5 do
	local data = fresh()
	data.Gear.Keyboard = tier
	local want = Balance.BaseClickGain * Gear.keyboardMultiplier(tier)
	if not near(Stack.clickIncome(data, NO_PASSES), want) then gearOk = false end
end
check("click income tracks every keyboard tier", gearOk)

-- ── Restructure bonus: +15% each, ADDITIVE (brief §6) ─────────────────────
local additiveOk = true
for count = 0, 20 do
	local data = fresh()
	data.Restructures = count
	local want = Balance.BaseClickGain * (1 + Balance.RestructureBonusPerOwned * count)
	if not near(Stack.clickIncome(data, NO_PASSES), want) then additiveOk = false end
end
check("restructure bonus is additive, not compounding", additiveOk,
	"10 restructures must be 2.5x, never 1.15^10 = 4.05x")

-- ── THE key property: Robux sits OUTSIDE the earned parenthesis ───────────
-- Whatever the earned multipliers are, the paid one must be a clean doubling.
local loaded = fresh()
loaded.Rank = 9
loaded.Gear = { Keyboard = 4, Chair = 3, Coffee = 2 }
loaded.Restructures = 7
loaded.Severance = { "LinkedInfluencer", "LinkedInfluencer", "CornerOffice" }

local earnedClick = Stack.clickIncome(loaded, NO_PASSES)
local paidClick = Stack.clickIncome(loaded, { DoubleProductivity = true })
check("2x Productivity exactly doubles click income for a loaded account",
	near(paidClick, earnedClick * 2),
	("earned %.4f, paid %.4f"):format(earnedClick, paidClick))

local freshEarned = Stack.clickIncome(fresh(), NO_PASSES)
local freshPaid = Stack.clickIncome(fresh(), { DoubleProductivity = true })
check("the paid multiplier is the same 2x for a brand-new account",
	near(freshPaid / freshEarned, paidClick / earnedClick),
	"paid power must not compound with earned power")

-- Same check on the idle faucet.
loaded.Interns = { { Uid = "a", Id = "CodeMonkey" }, { Uid = "b", Id = "Consultant" } }
loaded.EquippedInterns = { "a", "b" }
local earnedIdle = Stack.idlePerSecond(loaded, NO_PASSES)
local paidIdle = Stack.idlePerSecond(loaded, { DoubleProductivity = true })
check("2x Productivity exactly doubles idle income", near(paidIdle, earnedIdle * 2))

-- ── Interns feed the idle faucet only when equipped ───────────────────────
local benched = fresh()
benched.Gear.Chair = 2
benched.Interns = { { Uid = "x", Id = "FutureFounder" } }
local benchedIdle = Stack.idlePerSecond(benched, NO_PASSES)
benched.EquippedInterns = { "x" }
local equippedIdle = Stack.idlePerSecond(benched, NO_PASSES)
check("an owned-but-unequipped intern earns nothing", equippedIdle > benchedIdle,
	"equipping must change income")
check("the equipped intern adds exactly its published rate",
	near(equippedIdle - benchedIdle, 400), -- FutureFounder = 400/sec at rank 1, 0 restructures
	("delta was %.2f"):format(equippedIdle - benchedIdle))

-- ── Wins: Golden Parachute stacks, 2x Wins multiplies ─────────────────────
check("base wins award is unmodified", Stack.winsAward(100, fresh(), NO_PASSES) == 100)
local parachuted = fresh()
parachuted.Severance = { "GoldenParachute", "GoldenParachute" }
check("two Golden Parachutes give +20% Wins", Stack.winsAward(100, parachuted, NO_PASSES) == 120)
check("2x Wins doubles on top of perks",
	Stack.winsAward(100, parachuted, { DoubleWins = true }) == 240)

-- ── Restructure cost: linear, never exponential (brief §6) ────────────────
local linearOk = true
for owned = 0, 100 do
	local want = Balance.RestructureBaseCost + Balance.RestructureCostPerOwned * owned
	if Stack.restructureCost(owned) ~= want then linearOk = false end
end
check("restructure cost stays linear to 100 rebirths", linearOk)
-- The failure mode the brief calls out by name.
check("cost at rebirth 1000 is still sane (no exponential blowup)",
	Stack.restructureCost(1000) < 1e9,
	("got %.0f"):format(Stack.restructureCost(1000)))

-- ── Intern slots ──────────────────────────────────────────────────────────
check("base slots match Balance", Stack.internSlots(fresh(), NO_PASSES) == Balance.BaseInternSlots)
local networked = fresh()
networked.Severance = { "Networking", "Networking" }
check("each Networking perk adds a slot",
	Stack.internSlots(networked, NO_PASSES) == Balance.BaseInternSlots + 2)
check("the slots gamepass adds three",
	Stack.internSlots(fresh(), { InternSlots = true }) == Balance.BaseInternSlots + 3)

-- ── Out-work damage ───────────────────────────────────────────────────────
check("out-work damage scales with the player's productivity",
	Stack.outworkDamage(1000, fresh(), NO_PASSES) > Stack.outworkDamage(100, fresh(), NO_PASSES))
check("a zero-productivity player still chips a rival (never a hard block)",
	Stack.outworkDamage(0, fresh(), NO_PASSES) >= 1,
	"the brief forbids a fail state: the bar must always move a little")

-- ── Click cooldown ────────────────────────────────────────────────────────
check("coffee shortens the click cooldown",
	Stack.clickCooldown({ Gear = { Keyboard = 0, Chair = 0, Coffee = 5 } })
		< Stack.clickCooldown({ Gear = { Keyboard = 0, Chair = 0, Coffee = 0 } }))

-- ── Sanity: nothing produces NaN or infinity at the extremes ──────────────
local extreme = fresh()
extreme.Rank = #Ranks.List
extreme.Gear = { Keyboard = 5, Chair = 5, Coffee = 5 }
extreme.Restructures = 10000
extreme.Severance = { "LinkedInfluencer", "CornerOffice", "GoldenParachute" }
local values = {
	Stack.clickIncome(extreme, { DoubleProductivity = true }),
	Stack.idlePerSecond(extreme, { DoubleProductivity = true }),
	Stack.outworkDamage(1e12, extreme, { DoubleProductivity = true }),
	Stack.winsAward(1e6, extreme, { DoubleWins = true }),
}
local finite = true
for _, v in values do
	if v ~= v or v == math.huge or v < 0 then finite = false end
end
check("extreme accounts still produce finite, positive numbers", finite)

print("\n═══════════════════════════════════════")
if failed > 0 then
	error(("stack spec: %d of %d checks failed"):format(failed, passed + failed), 0)
else
	print(("%d passed, 0 failed"):format(passed))
end
