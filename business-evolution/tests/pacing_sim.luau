--!strict
-- Offline first-session pacing simulation. Answers one question with only the
-- shipped config numbers: does a brand-new player hit the brief's beats?
--
--   * rank 5 by ~minute 10
--   * Restructure-ready (rank 9 / 150K Productivity) between minutes 12 and 35
--
-- The income formulas are re-derived here from the documented Stack math
-- instead of requiring Server/Economy/Stack.luau, because Stack requires
-- `game` services and this file must run in the plain Luau CLI:
--
--   click  = BaseClickGain * keyboardMult * rankMult * (1 + 0.15 * restructures)
--   idle   = (chairRate * (1 + idleBonus) + internsPerSec) * rankMult * restructMult
--   damage = productivity * rankMult * keyboardMult * internMult * restructMult
--
-- Deliberately conservative — the model excludes crits (expected +38% on every
-- click), Payday pad bonuses and intern hires, so a real player should only
-- ever be AHEAD of this table. The Mailroom boss IS farmed (respawn-aware):
-- DESIGN-MAP calls the recurring boss "the Wins faucet", so leaving him out
-- would misrepresent the intended Wins economy.

local Balance = require("../src/ReplicatedStorage/Shared/Config/Balance")
local Ranks = require("../src/ReplicatedStorage/Shared/Config/Ranks")
local Gear = require("../src/ReplicatedStorage/Shared/Config/Gear")
local Rivals = require("../src/ReplicatedStorage/Shared/Config/Rivals")
local Format = require("../src/ReplicatedStorage/Shared/Util/Format")

type Case = { name: string, run: () -> () }

-- ── Player model (assumptions, not config) ──────────────────────────────────
local EAGER_CLICKS_PER_SECOND = 3 -- fresh-player enthusiasm, first two minutes
local SETTLED_CLICKS_PER_SECOND = 2 -- sustainable tap rate afterwards
local EAGER_UNTIL_SECONDS = 120
local DISCOVERY_SECONDS = 60 -- player finds the training desks + wing at min 1
local SECONDS_BETWEEN_FIGHTS = 15 -- walk back to the wing, pick a desk, engage
local MAX_CLICKS_PER_KILL = 20 -- players skip rivals that feel spongier than this

local SESSION_MINUTES = 35

type MinuteRow = {
	Minute: number,
	Rank: number,
	Productivity: number,
	Wins: number,
	Keyboard: number,
	Chair: number,
	Coffee: number,
}

type SimResult = {
	Rows: { MinuteRow },
	RankAtMinute10: number,
	-- Fractional minute when the player first holds rank 9 AND can afford the
	-- first Restructure; nil when the session ends before that.
	ReadyMinute: number?,
}

local function clickRate(second: number): number
	return if second < EAGER_UNTIL_SECONDS then EAGER_CLICKS_PER_SECOND else SETTLED_CLICKS_PER_SECOND
end

local function runSimulation(): SimResult
	local productivity = 0
	local wins = 0
	local rank = 1
	local restructures = 0 -- stays 0: the sim ends at the FIRST restructure
	local gear = { Keyboard = 0, Chair = 0, Coffee = 0 }

	local mailroom = Rivals.ByFloor.Mailroom

	local fightSecondsLeft = 0
	local fightReward = 0
	local fightTargetIndex = 0
	local lastFightEnd = -SECONDS_BETWEEN_FIGHTS
	-- Second at which each ladder slot is back at its desk. Only the boss's
	-- longer timer really bites, but tracking all of them keeps the cadence honest.
	local respawnAt: { [number]: number } = {}

	local rows: { MinuteRow } = {}
	local readySecond: number? = nil

	for second = 1, SESSION_MINUTES * 60 do
		local rankMult = Ranks.multiplierFor(rank)
		local restructMult = 1 + Balance.RestructureBonusPerOwned * restructures
		local keyboardMult = Gear.keyboardMultiplier(gear.Keyboard)
		local clickIncome = Balance.BaseClickGain * keyboardMult * rankMult * restructMult
		local idleIncome = Gear.chairIdleRate(gear.Chair) * rankMult * restructMult

		-- Chair income never stops; the chair earns even while out-working.
		productivity += idleIncome

		if fightSecondsLeft > 0 then
			-- Out-work clicks hit the rival instead of earning Productivity.
			fightSecondsLeft -= 1
			if fightSecondsLeft == 0 then
				wins += fightReward
				lastFightEnd = second
				local beaten = mailroom[fightTargetIndex]
				local respawnSeconds = if beaten.IsBoss then Balance.BossRespawnSeconds else Balance.RivalRespawnSeconds
				respawnAt[fightTargetIndex] = second + respawnSeconds
			end
		else
			local clickEquivalents = clickRate(second)
			if second >= DISCOVERY_SECONDS then
				-- Standing at the tier-1 training desk while manually clicking;
				-- the two stack by design (DESIGN-MAP hub rules).
				clickEquivalents += Balance.TrainingTierRates[1]
			end
			productivity += clickEquivalents * clickIncome

			-- Every so often the player walks into the wing and out-works the
			-- toughest rival they can beat in a reasonable number of clicks.
			if second >= DISCOVERY_SECONDS and second - lastFightEnd >= SECONDS_BETWEEN_FIGHTS then
				-- No interns hired in this model, so internMult stays 1.
				local damage = math.max(1, productivity * rankMult * keyboardMult * restructMult)
				local targetIndex = 0
				for index, def in mailroom do
					local alive = (respawnAt[index] or 0) <= second
					if alive and math.ceil(def.Workload / damage) <= MAX_CLICKS_PER_KILL then
						-- Highest beatable slot wins; the boss sits at the top
						-- of the ladder so he is farmed whenever he is back up.
						targetIndex = index
					end
				end
				if targetIndex > 0 then
					local def = mailroom[targetIndex]
					local clicksNeeded = math.ceil(def.Workload / damage)
					fightSecondsLeft = math.max(1, math.ceil(clicksNeeded / clickRate(second)))
					fightReward = def.Wins
					fightTargetIndex = targetIndex
				end
			end
		end

		-- Shopping: grab the cheapest next tier on any ladder while affordable.
		-- This mirrors how players actually spend — smallest number first.
		while true do
			local cheapestLadder: string? = nil
			local cheapestCost = math.huge
			for ladderId, owned in gear :: { [string]: number } do
				local cost = Gear.nextTierCost(ladderId, owned)
				if cost and cost < cheapestCost then
					cheapestLadder = ladderId
					cheapestCost = cost
				end
			end
			if cheapestLadder and wins >= cheapestCost then
				wins -= cheapestCost
				gear[cheapestLadder] += 1
			else
				break
			end
		end

		rank = Ranks.rankForProductivity(productivity)

		local restructureCost = Balance.RestructureBaseCost + Balance.RestructureCostPerOwned * restructures
		if not readySecond and rank >= Balance.RestructureMinRank and productivity >= restructureCost then
			readySecond = second
		end

		if second % 60 == 0 then
			table.insert(rows, {
				Minute = second / 60,
				Rank = rank,
				Productivity = productivity,
				Wins = wins,
				Keyboard = gear.Keyboard,
				Chair = gear.Chair,
				Coffee = gear.Coffee,
			})
		end
	end

	return {
		Rows = rows,
		RankAtMinute10 = rows[10].Rank,
		ReadyMinute = if readySecond then readySecond / 60 else nil,
	}
end

-- The simulation is deterministic, so run it once and let every case read the
-- same result — reruns would only slow the suite down.
local cachedResult: SimResult? = nil
local function results(): SimResult
	if not cachedResult then
		cachedResult = runSimulation()
	end
	return cachedResult :: SimResult
end

local cases: { Case } = {}

table.insert(cases, {
	name = "first-session minute-by-minute table",
	run = function()
		local sim = results()
		print("  min | rank | title            | productivity | wins  | gear K/C/Cf")
		print("  ----+------+------------------+--------------+-------+------------")
		for _, row in sim.Rows do
			print(("  %3d | %4d | %-16s | %12s | %5s | %d/%d/%d"):format(
				row.Minute,
				row.Rank,
				Ranks.List[row.Rank].Name,
				Format.abbreviate(row.Productivity),
				Format.abbreviate(row.Wins),
				row.Keyboard,
				row.Chair,
				row.Coffee
			))
		end
		if sim.ReadyMinute then
			-- Format.commas here (not abbreviate) because this is a diagnostic
			-- exact threshold, not a player-facing currency display.
			print(("  restructure-ready (rank %d + %s Productivity) at minute %.1f"):format(
				Balance.RestructureMinRank,
				Format.commas(Balance.RestructureBaseCost),
				sim.ReadyMinute
			))
		else
			print("  restructure-ready: NOT reached this session")
		end
	end,
})

table.insert(cases, {
	name = "rank 5 or better by minute 10",
	run = function()
		local sim = results()
		if sim.RankAtMinute10 < 5 then
			error(("pacing miss: rank %d at minute 10 (target: 5). Early click/idle income is too low — see the table above."):format(
				sim.RankAtMinute10
			))
		end
	end,
})

table.insert(cases, {
	name = "restructure-ready between minutes 12 and 35",
	run = function()
		local sim = results()
		if not sim.ReadyMinute then
			local last = sim.Rows[#sim.Rows]
			error(("pacing miss: session ends at minute %d with %s Productivity, short of the %s Restructure target."):format(
				last.Minute,
				Format.commas(last.Productivity),
				Format.commas(Balance.RestructureBaseCost)
			))
		end
		local ready = sim.ReadyMinute :: number
		if ready < 12 then
			error(("pacing miss: restructure-ready at minute %.1f — faster than the 12-minute floor; mid-game income is too generous."):format(ready))
		end
		if ready > 35 then
			error(("pacing miss: restructure-ready at minute %.1f — slower than the 35-minute ceiling."):format(ready))
		end
	end,
})

return { name = "pacing_sim", cases = cases }
