--!strict
-- World 1's economy in one place (brief 24; the pacing simulation is brief/out24/ECON2/pacing24.luau).
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

-- The pads' Cash, Stage 1 to the boss yard (16): +10 at Stage 1, growing every stage, round numbers that read exactly on
-- the pad's label (Format.compact). Brief 24: the early stages pay more (the Uzi, a box and the Shotgun come sooner), the
-- late ones about as before.
local PAD_CASH = { 10, 40, 70, 110, 160, 220, 300, 400, 520, 700, 900, 1200, 1500, 1900, 2400, 3000 }

-- The rebirth ladder (brief 24, "the start moves quicker, then slows down, like the other games"): NEED[n + 1] is the
-- Power rebirth n -> n + 1 needs. A focused free player's rebirths come at about 2:30, 5:40 (BAY 2 x4 opens), 9:00,
-- 13:00 ... and each one takes longer than the last: 2.5, 3, 3.5, 4, 4.5, 6.5, 8, 10.5, 12, 15.5, 17, 24, 32, 47
-- minutes (the pacing sim's table; a casual player's rise the same way, a little slower). The jumps follow the lanes: a rebirth that opens a lane (2, 4 ... 10) makes every
-- shot several times bigger, so the next need jumps with it.
local NEED = { 600, 4500, 30000, 80000, 300000, 500000, 2200000, 3500000, 12000000, 18000000, 40000000, 70000000, 180000000, 400000000 }

local Balance = {
 -- The currency's name, in one place (brief 23: the reference's "Wins" are our Cash; the pads say "+10 Cash").
 CashName = 'Cash',
 Version = 3, BaseRepPerSecond = 1, StudsPerStep = 6, MaxStepsPerSecond = 3,
 WallBase = 50, WallGrowth = 2.1, WallsPerMap = 10, MapThresholdGrowth = 40,
 BaseCrewSlots = 3, MaxSafeValue = 1e12,

 -- Shots (Shared/ShotRules).
 ShotBase = 1,

 -- Rebirths (Shared/RebirthRules.need): RebirthNeed[n + 1] (above: 600, 4.5K, 30K, 80K, 300K, 500K, 2.2M, 3.5M, 12M,
 -- 18M, 40M, 70M, 180M, 400M); past the list each one is RebirthGrowth times the last, times the multiplier step
 -- (n + 1) / n, two significant figures (850M, 1.8B, 3.9B ...). multiplier(n) = 1 + n x RebirthMultiplierPerLevel.
 -- RebirthBase is the first need (the HUD's fallback and the foundation's map list, Config/Maps, read it).
 RebirthNeed = NEED, RebirthBase = NEED[1], RebirthGrowth = 2, RebirthMultiplierPerLevel = 1,
 MaxRebirths = 1000, -- sanity cap for saves (need() passes the 1e12 Power cap long before this)

 -- Walk speed: Roblox's default 16, half a stud a second faster per rebirth, up to 24 (the old top look's speed).
 Walk = { Base = 16, PerRebirth = 0.5, Top = 24 },

 -- Stages 1-15 and the boss yard (16): each stage's Recommended Power (the gate's "Recommended Power: N" sign, and its
 -- goons' HP: EnemyRules.maxHp = HpShots x the kind's weight x this). Brief 24: Stages 1-4 come before the first rebirth
 -- (about 2 minutes), 5 and 6 with 1 rebirth (0.35 and 0.8 of that need), then one new stage a rebirth: stage s while you
 -- have r = s - 5 rebirths, at max(half that rebirth's need, 1.2 x the need before it), so it opens in the middle of the
 -- cycle and never falls to the Power the cycle before ended with. The boss yard comes with 11 rebirths, before the
 -- Champ Ring (12). The map builder reads this (code5/c_layout STAGE_POWER).
 StagePower = { 10, 60, 150, 350, 1600, 3600, 15000, 40000, 150000, 360000, 1100000, 2600000, 6000000, 14000000, 22000000, 48000000 },
 -- The pads (Shared/PadRules): the yellow Return pad's Cash per stage; the magenta pad pays PadRules.TenX times it.
 PadCash = PAD_CASH,
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

return table.freeze(Balance)
