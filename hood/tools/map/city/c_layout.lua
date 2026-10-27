---------------------------------------------------------------------------------------------- layout (World 2: the city)
-- World 1's layout (pieces/c_layout.lua) with the city's own stage count: the golden slice builds Stage 1 and 2 of the
-- avenue and gate 3 (shut, in front of the HQ tower that closes the avenue for now). The lobby's plan is World 1's (the
-- same zones and slots, e3_plaza), so the shared builders read the same constants.
local FRONT = 36 -- tower fronts at x = ±36, facing the avenue
local DEPTH = 28 -- the avenue's towers run back to x = ±64
local WALL_X = 124 -- the low boundary wall (f_areas), hidden under the skyline towers that stand over it
local SLEN = 64 -- one stage
local STAGES = 2 -- (the golden slice: WORLD2.md, order of work 2; the other 14 come after the owner's yes)
local SPAWN_W, SPAWN_TOP = 74, 123 -- (World 1's legacy hall extents: f_areas' ground and e2's legacy builders read them)
local BOSS_TOP = -STAGES * SLEN -- -128: where the HQ tower closes the avenue (no boss yard in the slice)
local BOSS_END = BOSS_TOP - 96
local SPAWN = V(0, 0, 42) -- the plaza's crossing, the same as World 1's
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end
local function trioOf(i) return (i - 1) % 3 + 1 end
local function gateZ(i) return stageTop(i) end
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each of World 2's stages. WORLD2.md: "World 2's Stage 1 asks for about World 1's boss Power". The
-- numbers are the economy's (Config/Balance.Worlds[2].StagePower, the Oct 27 pacing pass); without
-- them, a stand-in that starts at World 1's boss Power and grows 1.55x a stage.
local STAGE_POWER = {}
do
	local ok, Balance = pcall(function() return require(ReplicatedStorage.Shared.Config.Balance) end)
	local w2 = ok and type(Balance) == 'table' and Balance.Worlds and Balance.Worlds[2] and Balance.Worlds[2].StagePower
	if type(w2) == 'table' and #w2 >= STAGES + 1 then
		STAGE_POWER = table.clone(w2)
	else
		local base = ok and type(Balance) == 'table' and type(Balance.StagePower) == 'table' and Balance.StagePower[16] or 220000
		for i = 1, 16 do STAGE_POWER[i] = math.floor(base * 1.55 ^ (i - 1) / 1000 + 0.5) * 1000 end
	end
end
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop

-- Every stage's pad in walking order (the slice has no boss yard).
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
