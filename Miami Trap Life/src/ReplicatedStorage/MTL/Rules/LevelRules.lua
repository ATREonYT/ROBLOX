--!strict
-- Pure level maths (no Instances), shared by EconomyService, the HUD and the tests.
local Levels = require(script.Parent.Parent.Config.Levels)

local LevelRules = {}

-- XP needed to go from `level` to `level + 1`.
function LevelRules.need(level: number): number
	if level >= Levels.MaxLevel then
		return math.huge
	end
	return math.floor(Levels.Base + Levels.Scale * (math.max(level, 1) - 1) ^ Levels.Power + 0.5)
end

-- Total XP from Level 1 to reach `level`.
function LevelRules.totalTo(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += LevelRules.need(l)
	end
	return total
end

-- Adds XP. Returns newLevel, newXP (XP inside the level), and the list of levels gained (in order).
function LevelRules.add(level: number, xp: number, amount: number): (number, number, { number })
	local gained = {}
	xp += math.max(0, amount)
	while level < Levels.MaxLevel and xp >= LevelRules.need(level) do
		xp -= LevelRules.need(level)
		level += 1
		table.insert(gained, level)
	end
	if level >= Levels.MaxLevel then
		xp = 0
	end
	return level, xp, gained
end

-- 0..1 progress through the current level (for the HUD bar).
function LevelRules.progress(level: number, xp: number): number
	local need = LevelRules.need(level)
	if need == math.huge then
		return 1
	end
	return math.clamp(xp / need, 0, 1)
end

function LevelRules.unlocks(level: number): { string }
	return Levels.Unlocks[level] or {}
end

return LevelRules
