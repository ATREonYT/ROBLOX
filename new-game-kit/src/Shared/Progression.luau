--!strict
-- New Game Kit: Progression (the "level-up every second" layer, vault note 13 §2B and 14 §3)
-- Install: ReplicatedStorage/Kit/Progression (ModuleScript)
-- Splits the grind toward one goal (e.g. the Power a rebirth needs) into small levels that
-- grow slowly, so a level-up lands about every second early on. A display only: it changes
-- nothing the player earns.
--   Progression.Level(have, goal)          -> level, intoLevel, levelSize (levelSize 0 at max)
--   Progression.LevelStart(goal, level)    -> amount needed to reach that level
--   local s = Progression.Streak(1.5); s:Hit(now) -> 1, 2, 3 ... ("Level Up! [x3]")
-- Status: covered by tests/Progression.spec.luau (offline).

local Progression = {}

Progression.MAX_LEVEL = 20
Progression.CURVE = 1.3 -- >1: early levels small, late ones bigger (Stone Skipping: 10,10,10,12,14,...)

function Progression.LevelStart(goal: number, level: number, maxLevel: number?, curve: number?): number
	local max = maxLevel or Progression.MAX_LEVEL
	if level <= 1 then
		return 0
	end
	if level >= max then
		return goal
	end
	return math.ceil(goal * ((level - 1) / (max - 1)) ^ (curve or Progression.CURVE))
end

function Progression.Level(have: number, goal: number, maxLevel: number?, curve: number?): (number, number, number)
	local max = maxLevel or Progression.MAX_LEVEL
	if goal <= 0 or have >= goal then
		return max, 0, 0
	end
	local level = 1
	while level < max and have >= Progression.LevelStart(goal, level + 1, max, curve) do
		level += 1
	end
	local from = Progression.LevelStart(goal, level, max, curve)
	return level, have - from, Progression.LevelStart(goal, level + 1, max, curve) - from
end

-- Level-ups crossed between two amounts (one tick can cross several: show the biggest).
function Progression.LevelsGained(before: number, after: number, goal: number, maxLevel: number?, curve: number?): number
	local a = Progression.Level(before, goal, maxLevel, curve)
	local b = Progression.Level(after, goal, maxLevel, curve)
	return math.max(0, b - a)
end

export type Streak = { Hit: (Streak, now: number, count: number?) -> number, Reset: (Streak) -> (), window: number, last: number, count: number }

-- Counts hits that come within `window` seconds of each other ("Level Up! [x13]").
function Progression.Streak(window: number?): Streak
	local s = { window = window or 1.5, last = -math.huge, count = 0 }
	function s.Hit(self: Streak, now: number, count: number?): number
		if now - self.last > self.window then
			self.count = 0
		end
		self.count += count or 1
		self.last = now
		return self.count
	end
	function s.Reset(self: Streak)
		self.count = 0
		self.last = -math.huge
	end
	return s :: any
end

return Progression
