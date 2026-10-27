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
-- the Gold Deagle near the boss yard, the Mini Gun around it; the Neon Blaster and Diamond Cannon are after-the-world goals.)
local PAD_CASH = { 20, 80, 140, 220, 320, 440, 600, 800, 1000, 1400, 1800, 2400, 3000, 3800, 4800, 6000 }

-- The rebirth ladder (Oct 27, the owner: "not too quick, we want the first world to be like 25-30 minutes, then the next
-- worlds longer"). NEED[n + 1] is the Power rebirth n -> n + 1 needs. World 1 is 6 rebirths and 16 stages: a lane opens
-- with every rebirth (Config/Skins), and each rebirth brings two new stages (Stage 5 and 6 with 1 rebirth, 7 and 8 with
-- 2 ... 15 and the boss yard with 6), the first at 0.7 of that cycle's need and the second at the need itself, so the
-- run you make before you rebirth reaches it (one run less a cycle: every run starts at Stage 1). The
-- pacing sim (hood/tools/pacing; minutes from a new player, a free player who never stops):
--   rebirths at about 4.7, 8.4, 12, 15.7, 21, 26.7; the boss yard falls at about 34 for a player who runs every new stage
--   the moment it opens, 23 for one who trains up and runs once a rebirth: most players land in between, around 28;
--   a casual player (a third of the time idle) about 50.
-- The needs past the 6th are after the world, until World 2 is built (each about 2.2x the last, then RebirthRules.need's
-- own growth). World 2 and later get their own, longer ladders (WORLD_TARGETS below).
local NEED = { 1500, 20000, 60000, 140000, 350000, 600000, 3800000, 8500000, 18000000, 40000000, 90000000, 190000000, 430000000, 950000000 }

-- How long each world should take a player in the middle (the owner, Oct 27): World 1 25-30 minutes, later worlds
-- longer. Only World 1 is built; the sim's targets for the next ones.
local WORLD_TARGETS = { 27, 40, 55, 70, 90 }

local Balance = {
 -- The currency's name, in one place (brief 23: the reference's "Wins" are our Cash; the pads say "+20 Cash").
 CashName = 'Cash',
 Version = 3, BaseRepPerSecond = 1, StudsPerStep = 6, MaxStepsPerSecond = 3,
 WallBase = 50, WallGrowth = 2.1, WallsPerMap = 10, MapThresholdGrowth = 40,
 BaseCrewSlots = 3, MaxSafeValue = 1e12,

 -- Shots (Shared/ShotRules).
 ShotBase = 1,

 -- Rebirths (Shared/RebirthRules.need): RebirthNeed[n + 1] (above: 1.5K, 20K, 60K, 140K, 350K, 600K, then after the
 -- world 3.8M ... 950M); past the list each one is RebirthGrowth times the last, times the multiplier step
 -- (n + 1) / n, two significant figures (850M, 1.8B, 3.9B ...). multiplier(n) = 1 + n x RebirthMultiplierPerLevel.
 -- RebirthBase is the first need (the HUD's fallback and the foundation's map list, Config/Maps, read it).
 RebirthNeed = NEED, RebirthBase = NEED[1], WorldMinutes = WORLD_TARGETS, RebirthGrowth = 2, RebirthMultiplierPerLevel = 1,
 MaxRebirths = 1000, -- sanity cap for saves (need() passes the 1e12 Power cap long before this)

 -- Walk speed: Roblox's default 16, a stud and a half a second faster per rebirth, up to 24 at the 6th (the world's
 -- end). (Oct 27: every run walks the stages from Stage 1, so a quicker walk keeps the later runs from dragging.)
 Walk = { Base = 16, PerRebirth = 1.5, Top = 24 },

 -- Stages 1-15 and the boss yard (16): each stage's Recommended Power (the gate's "Recommended Power: N" sign, and its
 -- goons' HP: EnemyRules.maxHp = HpShots x the kind's weight x this). Oct 27 pacing: Stages 1-4 before the first
 -- rebirth, then two a rebirth (see NEED above), the boss yard with 6. The map builder reads this (code5/c_layout).
 StagePower = { 10, 60, 150, 350, 14000, 20000, 42000, 60000, 100000, 140000, 240000, 350000, 460000, 600000, 800000, 1500000 },
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
