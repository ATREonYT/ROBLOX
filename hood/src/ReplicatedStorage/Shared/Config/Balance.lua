--!strict
-- World 1's economy in one place (brief 24; re-paced Oct 27 to a 25-30 minute World 1 with hood/tools/pacing).
-- The loop (brief 23, a "run" game like the soldier and superhero games):
--   Power only comes from shooting: at the ranges (the lanes) and at the stage goons. One shot pays
--     ShotBase x the lane's Multiplier x the rebirth multiplier x the gun x the shoes (x the 2x Power pass, x a timed boost)
--   (Shared/ShotRules; a goon counts as a x1 lane). Nothing is paid per second.
--   A rebirth resets Power to 0 and raises the rebirth multiplier by one (1x, 2x, 3x ...); each one asks for more Power
--   (Shared/RebirthRules.need). Lanes open by rebirths, the two Robux lanes by their game pass (Config/Skins.Stations).
--   A run: Stage 1 onward; a stage's gate opens when you beat the goons of the stage before it, every run. Your shots deal
--   your Power, so Power is what beats the goons: StagePower is each stage's Recommended Power (the gate's sign, and the
--   goons' HP: Shared/EnemyRules.maxHp). Before every gate stand two pads: the yellow Return pad pays PadCash[stage] and
--   takes you home (the run ends), the magenta one 10x that with the 10x Cash pass (Shared/PadRules). The pad is the one
--   big Cash moment of a run (beating goons pays Power, not Cash); the goal chain pays a little on top.
--   Cash buys guns (Config/Guns) and shoe boxes (Config/Shoes).
-- The older fields (Wall*, MapThresholdGrowth, BaseRepPerSecond, ...) belong to the foundation's map list (Config/Maps)
-- and RepMath; the game doesn't pace with them.

-- The pads' Cash, Stage 1 to the boss yard (16): +20 at Stage 1, growing every stage, round numbers that read exactly on
-- the pad's label (Format.compact). (Oct 27 pacing: twice brief 24's, so the guns keep pace with a 25-30 minute World 1:
-- the Gold Deagle around rebirth 6, the Mini Gun near the boss; the Neon Blaster and Diamond Cannon come after it.)
local PAD_CASH = { 20, 80, 140, 220, 320, 440, 600, 800, 1000, 1400, 1800, 2400, 3000, 3800, 4800, 6000 }

-- The rebirth ladder (Oct 27, the owner: "not too quick, we want the first world to be like 25-30 minutes, then the next
-- worlds longer", then "more rebirths, up to like 50 for the shooting ranges also to work, we need them to stay in the
-- game for longer", and the final boss is the way to the next world). NEED[n + 1] is the Power rebirth n -> n + 1 needs.
--   World 1: 9 rebirths and 16 stages. Stages 1-4 before the first rebirth; two new stages with each of the first 3
--   rebirths (5-6, 7-8, 9-10), one with each of the next 5 (11-15), and the boss yard (16) in the 9th rebirth's cycle.
--   A cycle's last stage sits at its need, so the run you make before you rebirth reaches it.
--   After the boss (the World 2 door opens; until World 2 is built it stays shut): the ladder goes on to 50, each need
--   about 1.1x the last times the multiplier step, with the last lanes opening at 15, 30 and 50 (Config/Skins).
-- The pacing sim (hood/tools/pacing; minutes from a new player, a free player who never stops):
--   rebirths at about 4.3, 7.4, 10.4, 13.9, 17.3, 19.1, 21, 24.9, 30.3; the boss falls at about 33 for a player who runs
--   every new stage the moment it opens, 29 for one who trains up and runs once a rebirth (most players about 30); a
--   casual player (a third of the time idle) about 50. Rebirth 50 at about 4 hours (casual about 6).
local NEED = {
	1000, 3500, 8000, 16000, 30000, 55000, 90000, 130000, 180000, -- World 1 (rebirths 1-9)
	250000, 300000, 360000, 430000, 500000, 600000, 700000, 850000, 950000, 1100000, -- 10-19
	1300000, 1500000, 1700000, 2000000, 2300000, 2600000, 3000000, 3400000, 3900000, 4400000, -- 20-29
	5000000, 5500000, 6500000, 7500000, 8500000, 9500000, 11000000, 12000000, 14000000, 15000000, -- 30-39
	17000000, 20000000, 22000000, 25000000, 28000000, 32000000, 36000000, 40000000, 45000000, 50000000, -- 40-49
	55000000, -- 50
}

-- How long each world should take a player in the middle (the owner, Oct 27): World 1 25-30 minutes, later worlds
-- longer. Only World 1 is built; the sim's targets for the next ones.
local WORLD_TARGETS = { 27, 40, 55, 70, 90 }

-- World 2, Downtown (Oct 27; hood/docs/WORLD2.md): its own place, entered at about rebirth 9-10 (World 1's boss).
-- Two new stages with each rebirth from 10 to 17 (a cycle's first stage 60% of the way up its need, the second at it),
-- its ranges hit twice as hard (LaneBoost, Config/Skins), and the pads pay from 7K to 40K. The pacing sim (World 2
-- section): its boss about 40 minutes after the door for a player who runs every new stage, about 60 for a casual one.
local WORLD2 = {
	StagePower = { 280000, 300000, 340000, 360000, 400000, 430000, 470000, 500000, 560000, 600000, 660000, 700000, 790000, 850000, 910000, 950000 },
	PadCash = { 7000, 7900, 8800, 9900, 11100, 12500, 14100, 15800, 17700, 19900, 22400, 25100, 28200, 31700, 35600, 40000 },
	LaneBoost = 2,
}

-- Each world is its own place (Config/Worlds); this server's world picks its stages, pads and lane boost.
local WORLD = require(script.Parent.Parent.WorldInfo).current()

local Balance = {
 -- The currency's name, in one place (brief 23: the reference's "Wins" are our Cash; the pads say "+20 Cash").
 CashName = 'Cash',
 Version = 3, BaseRepPerSecond = 1, StudsPerStep = 6, MaxStepsPerSecond = 3,
 WallBase = 50, WallGrowth = 2.1, WallsPerMap = 10, MapThresholdGrowth = 40,
 BaseCrewSlots = 3, MaxSafeValue = 1e12,

 -- Shots (Shared/ShotRules).
 ShotBase = 1,

 -- Rebirths (Shared/RebirthRules.need): RebirthNeed[n + 1] (above: 1K, 3.5K, 8K ... 180K in World 1, then up to 55M at
 -- the 50th); past the list each one is RebirthGrowth times the last, times the multiplier step
 -- (n + 1) / n, two significant figures (60M, 70M, 80M ...). multiplier(n) = 1 + n x RebirthMultiplierPerLevel.
 -- RebirthBase is the first need (the HUD's fallback and the foundation's map list, Config/Maps, read it).
 RebirthNeed = NEED, RebirthBase = NEED[1], WorldMinutes = WORLD_TARGETS, RebirthGrowth = 1.1, RebirthMultiplierPerLevel = 1,
 MaxRebirths = 1000, -- sanity cap for saves (need(1000) is about 3.3e11, under the 1e12 Power cap)

 -- Walk speed: Roblox's default 16, a stud a second faster per rebirth, up to 24 at the 8th (near the boss). (Oct 27:
 -- every run walks the stages from Stage 1, so a quicker walk keeps the later runs from dragging.)
 Walk = { Base = 16, PerRebirth = 1, Top = 24 },

 -- Stages 1-15 and the boss yard (16): each stage's Recommended Power (the gate's "Recommended Power: N" sign, and its
 -- goons' HP: EnemyRules.maxHp = HpShots x the kind's weight x this). Oct 27 pacing: which rebirth brings which stage is
 -- under NEED above. The map builder reads this (code5/c_layout).
 StagePower = { 10, 60, 150, 350, 2400, 3500, 5500, 8000, 11000, 16000, 30000, 55000, 90000, 130000, 180000, 220000 },
 -- (Oct 27) every world's numbers; StagePower, PadCash and LaneBoost here are this server's world's (set below)
 Worlds = {},
 -- The pads (Shared/PadRules): the yellow Return pad's Cash per stage; the magenta pad pays PadRules.TenX times it.
 PadCash = PAD_CASH,
 LaneBoost = 1, -- the ranges' multiplier boost in this world (Config/Skins applies it)
 -- Beating a stage's goons pays no Cash, the first time or any later run (WaveRules.reward / repeatReward): the pad at
 -- the end of the run is the one big number (CRITIC3: fewer, bigger Cash moments). Kept for readers of the old field.
 WaveCash = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
 -- (brief 23) Gates pay nothing now: a gate opens every run when its goons are down (the pads pay instead). Kept at 0
 -- for readers of the old field (StageService's first-pass Cash).
 StageCash = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
 WaveRepeatShare = 0,
}

function Balance.wallThreshold(mapIndex: number, wallIndex: number): number
 assert(mapIndex >= 1 and mapIndex % 1 == 0, 'Invalid map index')
 assert(wallIndex >= 1 and wallIndex <= Balance.WallsPerMap and wallIndex % 1 == 0, 'Invalid wall index')
 local value = math.floor(Balance.WallBase * Balance.MapThresholdGrowth^(mapIndex-1) * Balance.WallGrowth^(wallIndex-1) + 0.5)
 assert(value <= Balance.MaxSafeValue, 'Wall threshold exceeds numeric budget')
 return value
end

-- Two significant figures, in steps of 5 from a leading 5 (9250 -> 9500, 26148 -> 26000, 1234567 -> 1200000).
function Balance.round(v: number): number
 if v ~= v or v <= 0 then return 0 end
 if v < 10 then return math.max(1, math.floor(v + 0.5)) end
 local e = 10 ^ (math.floor(math.log10(v)) - 1)
 if v / e >= 50 then e *= 5 end
 return math.floor(v / e + 0.5) * e
end

-- Cash for passing gate `stage` the first time (0 for a stage the table doesn't know).
function Balance.stageCash(stage: any): number
 return type(stage) == 'number' and Balance.StageCash[stage] or 0
end

Balance.Worlds[1] = { StagePower = Balance.StagePower, PadCash = PAD_CASH, LaneBoost = 1 }
Balance.Worlds[2] = WORLD2
if Balance.Worlds[WORLD] then
	Balance.StagePower = Balance.Worlds[WORLD].StagePower
	Balance.PadCash = Balance.Worlds[WORLD].PadCash
	Balance.LaneBoost = Balance.Worlds[WORLD].LaneBoost
end
Balance.World = WORLD

return table.freeze(Balance)
