--!strict
-- Every tunable number that isn't rank/floor/gear/rival/intern content.
-- ⚠ Values marked INVENTED are not in the project brief — they were chosen to
-- hit the brief's pacing target (first Restructure ≈ 20 minutes, 5-6 ranks in
-- the first 10) and verified with the offline pacing simulation in tests/.
-- Tune them here, never in service code.

local Balance = {
	-- ── Clicking ────────────────────────────────────────────────────────────
	BaseClickGain = 1, -- the "+1" itself
	-- Server-side hard cap on processed clicks. Auto-clickers above this rate
	-- are silently wasted, which is the whole anti-cheat strategy (§14).
	MaxClicksPerSecond = 20,
	-- Client-side click cooldown before Coffee gear (INVENTED, feels-based).
	BaseClickCooldown = 0.30,

	-- ── Crits (INVENTED — pure feedback juice, incomes already balanced) ───
	CritChance = 0.10, -- orange popup, 3x
	BigCritChance = 0.02, -- big popup, 10x, own sound
	CritMultiplier = 3,
	BigCritMultiplier = 10,

	-- ── Idle income ─────────────────────────────────────────────────────────
	IdleTickSeconds = 1, -- how often the server grants chair + intern income

	-- ── Restructure (§6, exact) ─────────────────────────────────────────────
	RestructureBaseCost = 150000,
	RestructureCostPerOwned = 75000,
	RestructureBonusPerOwned = 0.15, -- +15% Productivity gain, additive, permanent
	RestructureMinRank = 9, -- Director

	-- ── Gear (§8, exact) ────────────────────────────────────────────────────
	GearCostGrowth = 1.12, -- cost = base * 1.12 ^ owned

	-- ── Rivals ──────────────────────────────────────────────────────────────
	RivalTickHz = 5, -- server replication rate for rival state (§13.8)
	RivalReachStuds = 28, -- max distance for an out-work click to count
	RivalRespawnSeconds = 8, -- INVENTED
	BossRespawnSeconds = 20, -- INVENTED

	-- ── Interns ─────────────────────────────────────────────────────────────
	BaseInternSlots = 3, -- §7
	CoffeeMachineCost = 75, -- Wins per hire (INVENTED)
	ConsultantKeepFraction = 0.25, -- the Consultant's Restructure carry-over (§7)

	-- ── Data safety (§13.9) ─────────────────────────────────────────────────
	MaxNumber = 1e300, -- clamp ceiling on every profile write

	-- ── State replication ───────────────────────────────────────────────────
	StateSyncHz = 4, -- max full-state pushes per second per player
}

return Balance
