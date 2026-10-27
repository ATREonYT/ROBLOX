--!strict
-- Levels and ranks (brief 29, P4: "make it level up in levels, not strength"). Pure rules shared by HoodServer/Levels
-- (which keeps the best level and pays the rank rewards), the HUD (the "Level N" bar), Progress.client (the level-up
-- toast and the rank-up screen), the gate signs ("Recommended Level N"), the goals and the unit tests.
--
-- THE MAPPING: Power (the profile's Rep) is still the one number everything runs on: shots pay it, stage goons' HP and
-- every stage's Recommended Power are in it, a rebirth asks for it and resets it. A Level is only a curve over it:
--     the level you are = the highest L with Power >= T(L),   T(L) = 1.5^(L-1) - 1   (T(1) = 0)
-- so every 1.5x more Power is one more level, which is how the soldier game's levels read (many early, slower later):
-- the first shot is already Level 2, the stage 1 gate (10 Power) is Level 6, a first rebirth (1.5K) is Level 19, the
-- boss yard (1.5M) Level 36 and the 14th rebirth (950M) Level 52 (Oct 27 pacing). T is rounded to two significant figures from 100 up, so the bar's numbers read cleanly.
-- Nothing is stored for it: a level is always LevelRules.levelOf(Rep), so the economy, the gates and the saves are
-- exactly what they were. A rebirth resets Power, so it resets the level (the reference's "Level 5 MAX - Rebirth!").
--
-- RANKS stay: a rank is tied to the BEST level you ever reached (the profile's BestLevel, kept by HoodServer/Levels, never
-- lowered by a rebirth), so it only goes up: Rookie, Street Kid, Hustler, Enforcer, Shot Caller, Boss, Kingpin, Legend.
-- Crossing a rank's level pays its Cash once (the saved BestLevel makes "once" true) and shows the rank-up screen.
local Balance = require(script.Parent.Config.Balance)

local LevelRules = {}
LevelRules.Growth = 1.5 -- Power per level, as a factor
LevelRules.MaxLevel = 70 -- (T(70) is ~2.6e12, past the 1e12 Power cap)

-- T[L]: the Power that makes level L (1.5^(L-1) - 1, two significant figures from 100 up, always more than the one before).
local T: { number } = { 0 }
for l = 2, LevelRules.MaxLevel do
	local v = LevelRules.Growth ^ (l - 1) - 1
	if v >= 100 then v = Balance.round(v) else v = math.ceil(v - 1e-9) end
	T[l] = math.max(T[l - 1] + 1, v)
end
LevelRules.Thresholds = T

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- The level for a Power (junk and negatives are Level 1).
function LevelRules.levelOf(power: any): number
	local p = number(power, 0)
	local lo, hi = 1, LevelRules.MaxLevel
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if T[mid] <= p then lo = mid else hi = mid - 1 end
	end
	return lo
end

-- The Power level L starts at (L clamped to 1..MaxLevel).
function LevelRules.powerFor(level: any): number
	return T[math.clamp(math.floor(number(level, 1)), 1, LevelRules.MaxLevel)]
end

-- The bar: (level, into, span, fraction, maxed). into = Power past this level's start, span = Power from this level to the next.
function LevelRules.progress(power: any): (number, number, number, number, boolean)
	local p = math.max(0, number(power, 0))
	local l = LevelRules.levelOf(p)
	if l >= LevelRules.MaxLevel then return l, 0, 0, 1, true end
	local into, span = p - T[l], T[l + 1] - T[l]
	return l, into, span, math.clamp(into / span, 0, 1), false
end

-- The level the Recommended Power of stage s (Balance.StagePower) is: the gate sign's "Level N".
function LevelRules.stageLevel(stage: any): number
	local list = Balance.StagePower
	local s = math.clamp(math.floor(number(stage, 1)), 1, #list)
	return LevelRules.levelOf(list[s])
end

-- The level the rebirth from n to n + 1 asks for (RebirthRules.need as a level): "Rebirth at Level 16".
function LevelRules.rebirthLevel(n: any): number
	return LevelRules.levelOf(require(script.Parent.RebirthRules).need(n))
end

---------------------------------------------------------------------------------------------- ranks
-- Level = the best level that makes the rank; Cash = what the rank-up pays once; Chevrons = the rank mark's bars (0..7).
LevelRules.Ranks = {
	{ Id = 'Rookie', Name = 'Rookie', Level = 1, Cash = 0, Chevrons = 0, Color = '#B8BEC8' },
	{ Id = 'StreetKid', Name = 'Street Kid', Level = 10, Cash = 40, Chevrons = 1, Color = '#5BD45B' },
	{ Id = 'Hustler', Name = 'Hustler', Level = 16, Cash = 150, Chevrons = 2, Color = '#3D9BFF' },
	{ Id = 'Enforcer', Name = 'Enforcer', Level = 22, Cash = 500, Chevrons = 3, Color = '#A64DFF' },
	{ Id = 'ShotCaller', Name = 'Shot Caller', Level = 28, Cash = 1500, Chevrons = 4, Color = '#FF9A1F' },
	{ Id = 'Boss', Name = 'Boss', Level = 34, Cash = 5000, Chevrons = 5, Color = '#FF4757' },
	{ Id = 'Kingpin', Name = 'Kingpin', Level = 40, Cash = 15000, Chevrons = 6, Color = '#FFD21F' },
	{ Id = 'Legend', Name = 'Legend', Level = 46, Cash = 40000, Chevrons = 7, Color = '#FF6BD6' },
}

-- The rank (1..#Ranks) a best level makes.
function LevelRules.rankIndex(bestLevel: any): number
	local l = number(bestLevel, 1)
	local at = 1
	for i, r in LevelRules.Ranks do
		if l >= r.Level then at = i end
	end
	return at
end
function LevelRules.rankOf(bestLevel: any)
	return LevelRules.Ranks[LevelRules.rankIndex(bestLevel)]
end
-- The next rank above a best level, or nil at the top.
function LevelRules.nextRank(bestLevel: any)
	return LevelRules.Ranks[LevelRules.rankIndex(bestLevel) + 1]
end
-- The ranks a best level passes going from `before` to `after` (a list of rank indices, in order): what pays and shows.
function LevelRules.ranksCrossed(before: any, after: any): { number }
	local a, b = LevelRules.rankIndex(before), LevelRules.rankIndex(after)
	local list = {}
	for i = a + 1, b do table.insert(list, i) end
	return list
end

-- Your best level, from a profile's data (BestLevel if it is sane), never below the level you are at now or the level your
-- last rebirth needed (so a profile saved before BestLevel existed comes out right, and nobody loses a rank).
function LevelRules.bestOf(data: any): number
	local d = type(data) == 'table' and data or {}
	local best = math.clamp(math.floor(number(d.BestLevel, 1)), 1, LevelRules.MaxLevel)
	best = math.max(best, LevelRules.levelOf(d.Rep))
	local n = math.floor(number(d.Rebirths, 0))
	if n > 0 then best = math.max(best, LevelRules.rebirthLevel(n - 1)) end
	return best
end

-- The text over a player's head: "Hustler  Lv 17".
function LevelRules.tag(bestLevel: any, power: any): string
	return LevelRules.rankOf(bestLevel).Name .. '  Lv ' .. LevelRules.levelOf(power)
end

return LevelRules
