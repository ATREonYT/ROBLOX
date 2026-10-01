--!strict
-- Provisional values. Pacing simulation and tuning belong to milestone 2.
local Balance = {
 Version = 1, BaseRepPerSecond = 1, StudsPerStep = 6, MaxStepsPerSecond = 3,
 WallBase = 50, WallGrowth = 2.1, WallsPerMap = 10, MapThresholdGrowth = 40,
 RebirthBase = 2500, RebirthRequirementGrowth = 2.3, RebirthMultiplierPerLevel = 0.5,
 BaseCrewSlots = 3, MaxSafeValue = 1e12,
 PacingTargets = {
  FirstWall = {Min = 1, Max = 60}, FirstEvolution = {Min = 96, Max = 144},
  FirstCrew = {Min = 144, Max = 216}, FirstRebirth = {Min = 600, Max = 900},
  FirstMoveOut = {Min = 1500, Max = 2100}, Uptown = {Min = 7200, Max = 10800},
  Hills = {Min = 28800, Max = 36000},
 },
}
function Balance.wallThreshold(mapIndex: number, wallIndex: number): number
 assert(mapIndex >= 1 and mapIndex % 1 == 0, 'Invalid map index')
 assert(wallIndex >= 1 and wallIndex <= Balance.WallsPerMap and wallIndex % 1 == 0, 'Invalid wall index')
 local value = math.floor(Balance.WallBase * Balance.MapThresholdGrowth^(mapIndex-1) * Balance.WallGrowth^(wallIndex-1) + 0.5)
 assert(value <= Balance.MaxSafeValue, 'Wall threshold exceeds numeric budget')
 return value
end
return table.freeze(Balance)
