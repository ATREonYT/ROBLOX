---------------------------------------------------------------------------------------------- layout
local FRONT = 36 -- building fronts at x = ±36, facing the middle
local DEPTH = 28 -- buildings run back to x = ±64
local WALL_X = 124 -- the low boundary wall (round the lobby hall, x +-74, and the stage districts, which reach x +-92..111)
local SLEN = 64 -- one stage
local STAGES = 15
local SPAWN_W, SPAWN_TOP = 74, 123 -- the lobby's old hall extents (x -74..74, z 5..123): today only the grass round it (f_areas) and e2's legacy builders read them; the compact warehouse's walls are e4's Lobby.WH (x -93..68, z 6..92)
local BOSS_TOP = -STAGES * SLEN -- -960
local BOSS_END = BOSS_TOP - 96 -- the boss yard runs to -1056
local SPAWN = V(0, 0, 36) -- the hall's crossing, where the spine meets the cross arm (on the floor); you land 3 south of it (Lobby.SpawnAt), facing north to the gate (B35: 39 studs from the gate)
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end -- 1..5: three stages share a look
local function trioOf(i) return (i - 1) % 3 + 1 end -- 1..3: place within the look
local function gateZ(i) return stageTop(i) end -- gate i opens stage i (16 opens the boss yard)
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each stage, and into the boss yard (16). Each step is harder than the last. Every lane trains
-- in the lobby (the Champ Ring is in the boss yard), so players come back between pushes. The numbers are the
-- economy's (Config/Balance.StagePower, paced with the rebirths); the list here is only a fallback without it.
local STAGE_POWER = { 10, 60, 250, 800, 1600, 6000, 17000, 40000, 95000, 210000, 440000, 950000, 2000000, 4000000, 8000000, 34000000 }
do
	local ok, Balance = pcall(function() return require(ReplicatedStorage.Shared.Config.Balance) end)
	if ok and type(Balance) == 'table' and type(Balance.StagePower) == 'table' and #Balance.StagePower == 16 then STAGE_POWER = table.clone(Balance.StagePower) end
end
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop

-- Every stage's pad in walking order, then the boss: the fight system can read them straight from here.
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
table.insert(V2.Fights, { Fight = 16, Stage = 16, Look = 6, X = 0, Z = BOSS_END + 22, Boss = true })
