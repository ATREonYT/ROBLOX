--!strict
-- The multiplier stack (§9) — the ONE place income math lives. Server-only on
-- purpose (§13.5): the client is told results, never formulas.
--
--   totalMultiplier = (rank × gear × intern × restructure) × robux
--
-- The Robux factor stays OUTSIDE the earned parenthesis so paid power scales
-- earned power instead of compounding with it.
--
-- Interpretation note (called out in the milestone report): the brief gives no
-- numeric rule for internMult inside the damage stack, so: each EQUIPPED
-- intern adds +10% to out-working. Interns' main job stays their passive
-- Productivity/sec, which is handled in idlePerSecond below.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Balance = require(Config.Balance)
local Ranks = require(Config.Ranks)
local Gear = require(Config.Gear)
local Interns = require(Config.Interns)
local Severance = require(Config.Severance)
local Skins = require(Config.Skins)

local _ = ServerScriptService -- (kept for symmetry; Stack has no service deps)

export type Passes = {
	DoubleProductivity: boolean?,
	DoubleWins: boolean?,
	InternSlots: boolean?,
	Delegate: boolean?,
}

-- Minimal slice of ProfileData that income math needs; typed loosely so the
-- offline pacing simulation can feed plain tables through it.
export type StackInput = {
	Rank: number,
	EquippedSkin: string?,
	Restructures: number,
	Gear: { Keyboard: number, Chair: number, Coffee: number },
	Severance: { string },
	Interns: { { Uid: string, Id: string } },
	EquippedInterns: { string },
}

local Stack = {}

local function robuxMultiplier(passes: Passes): number
	return if passes.DoubleProductivity then 2 else 1
end

local function restructureMultiplier(restructures: number): number
	return 1 + Balance.RestructureBonusPerOwned * restructures
end

local function equippedInternsPerSecond(data: StackInput): number
	local total = 0
	for _, uid in data.EquippedInterns do
		for _, owned in data.Interns do
			if owned.Uid == uid then
				local def = Interns.get(owned.Id)
				if def then
					total += def.PerSecond
				end
				break
			end
		end
	end
	return total
end

-- Productivity gained by one click (before crit rolls).
function Stack.clickIncome(data: StackInput, passes: Passes): number
	local effects = Severance.effects(data.Severance)
	-- The equipped skin is the biggest visible lever on click income, which is
	-- what makes the shop wall worth walking to.
	local skinMultiplier = Skins.multiplierFor(data.EquippedSkin or Skins.DefaultId)
	local earned = Ranks.multiplierFor(data.Rank)
		* Gear.keyboardMultiplier(data.Gear.Keyboard)
		* skinMultiplier
		* restructureMultiplier(data.Restructures)
		* (1 + effects.ClickBonus)
	return Balance.BaseClickGain * earned * robuxMultiplier(passes)
end

-- Passive Productivity per second: chair + equipped interns.
function Stack.idlePerSecond(data: StackInput, passes: Passes): number
	local effects = Severance.effects(data.Severance)
	local chair = Gear.chairIdleRate(data.Gear.Chair) * (1 + effects.IdleBonus)
	local interns = equippedInternsPerSecond(data)
	local earned = (chair + interns) * Ranks.multiplierFor(data.Rank) * restructureMultiplier(data.Restructures)
	return earned * robuxMultiplier(passes)
end

-- Damage one out-work click applies to a rival's Workload (§5):
-- playerProductivity × totalMultiplier.
function Stack.outworkDamage(productivity: number, data: StackInput, passes: Passes): number
	local internMult = 1 + 0.1 * #data.EquippedInterns
	local earned = Ranks.multiplierFor(data.Rank)
		* Gear.keyboardMultiplier(data.Gear.Keyboard)
		* Skins.multiplierFor(data.EquippedSkin or Skins.DefaultId)
		* internMult
		* restructureMultiplier(data.Restructures)
	return math.max(1, productivity * earned * robuxMultiplier(passes))
end

-- Wins actually granted for a rival worth `baseWins`.
function Stack.winsAward(baseWins: number, data: StackInput, passes: Passes): number
	local effects = Severance.effects(data.Severance)
	local amount = baseWins * (1 + effects.WinsBonus)
	if passes.DoubleWins then
		amount *= 2
	end
	return math.floor(amount + 0.5)
end

function Stack.restructureCost(restructures: number): number
	return Balance.RestructureBaseCost + Balance.RestructureCostPerOwned * restructures
end

function Stack.internSlots(data: StackInput, passes: Passes): number
	local effects = Severance.effects(data.Severance)
	local slots = Balance.BaseInternSlots + effects.ExtraInternSlots
	if passes.InternSlots then
		slots += 3
	end
	return slots
end

-- Seconds a client must wait between clicks (display/UX only — the server
-- token bucket in Net is the real enforcement).
function Stack.clickCooldown(data: StackInput): number
	return Balance.BaseClickCooldown * Gear.coffeeCooldownMultiplier(data.Gear.Coffee)
end

return Stack
