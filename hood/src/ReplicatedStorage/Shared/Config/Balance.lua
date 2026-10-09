--!strict
-- World 1's economy in one place (brief 17; the pacing simulation is brief/out17/LOGIC/pacing.luau).
--   Power only comes from shooting: at the ranges and at the stage target waves. One shot pays
--     ShotBase x the lane's Multiplier x the rebirth multiplier x the gun x the shoes (x the 2x Power pass, x a timed boost)
--   (Shared/ShotRules; a stage target counts as a x1 lane). Nothing is paid per second.
--   A rebirth resets Power to 0 and raises the rebirth multiplier by one (1x, 2x, 3x ...); each one asks for more Power
--   (Shared/RebirthRules.need). Lanes unlock by rebirths (Config/Skins.Stations).
--   Stage gates ask for Power (StagePower, read by the map builder) and pay Cash once (StageCash); each stage's target
--   wave pays Cash on its first clear (WaveCash) and a little on every later clear (WaveRepeatShare of StageCash).
--   Cash buys guns (Config/Guns) and shoe boxes (Config/Shoes).
-- The older fields (Wall*, MapThresholdGrowth, BaseRepPerSecond, ...) belong to the foundation's map list (Config/Maps)
-- and RepMath; the game doesn't pace with them.
local Balance = {
 Version = 2, BaseRepPerSecond = 1, StudsPerStep = 6, MaxStepsPerSecond = 3,
 WallBase = 50, WallGrowth = 2.1, WallsPerMap = 10, MapThresholdGrowth = 40,
 BaseCrewSlots = 3, MaxSafeValue = 1e12,

 -- Shots (Shared/ShotRules).
 ShotBase = 1,

 -- Rebirths (Shared/RebirthRules): need(n) = RebirthBase x RebirthGrowth^n x multiplier(n), two significant figures;
 -- multiplier(n) = 1 + n x RebirthMultiplierPerLevel. So 2K, 7.5K, 21K, 50K, 120K, 260K, 550K, 1.2M ... (the first one
 -- about 2.5 minutes of shooting at BAY 1 with the first guns; each later one faster at first thanks to the new lane).
 RebirthBase = 2000, RebirthGrowth = 1.85, RebirthMultiplierPerLevel = 1,
 MaxRebirths = 1000, -- sanity cap for saves (need() passes the 1e12 Power cap long before this)

 -- Walk speed: Roblox's default 16, half a stud a second faster per rebirth, up to 24 (the old top look's speed).
 Walk = { Base = 16, PerRebirth = 0.5, Top = 24 },

 -- Stage gates 1-15 and the boss yard (16): the Power each gate asks for. Each gate is reachable in the rebirth cycle
 -- the pacing aims it at (stages 1-5 before the first rebirth, then about one new stage a rebirth, the boss yard at 12),
 -- about 80% of that cycle's rebirth need. The map builder reads this (code5/c_layout STAGE_POWER).
 StagePower = { 10, 60, 250, 800, 1600, 6000, 17000, 40000, 95000, 210000, 440000, 950000, 2000000, 4000000, 8000000, 34000000 },
 -- Cash for a gate's first pass, and for the first clear of the target wave in the stage behind it.
 StageCash = { 20, 30, 50, 75, 120, 180, 280, 430, 650, 1000, 1600, 2500, 3800, 6000, 9000, 14000 },
 WaveCash = { 8, 12, 20, 30, 50, 70, 110, 170, 260, 400, 650, 1000, 1500, 2400, 3600, 5500 },
 -- A wave cleared again (it comes back WaveRules.RespawnDelay seconds after a clear, the next time you walk in) pays this
 -- share of the stage's gate Cash (at least 1): World 1's repeatable Cash, 1 at Stage 1 up to 700 in the boss yard.
 WaveRepeatShare = 0.05,
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
