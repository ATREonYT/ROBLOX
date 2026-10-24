-- Old saves: the Oct 19 Knife Crate's pity counter and keys move into the owner's three knife crates (Shared/CrateSaves).
-- lune run tests/CrateSaves.spec.luau   (from huzz-valley/)
local process = require("@lune/process")
local CrateSaves = require("../src/ReplicatedStorage/Shared/CrateSaves")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- nothing old: nothing changes
local d0 = { Pity = { Dojo = 3 }, CrateKeys = {} }
check("a new save is left alone", CrateSaves.migrate(d0) == false and d0.Pity.Dojo == 3)

-- an old Knife count with no knife crate counts yet: into the Dojo Chest
local d1 = { Pity = { Knife = 27, Starter = 4 } }
check("an old save changes", CrateSaves.migrate(d1) == true)
check("its Knife count goes to the Dojo Chest", d1.Pity.Dojo == 27 and d1.Pity.Knife == nil)
check("other crates' counts stay", d1.Pity.Starter == 4)

-- into the crate with the highest count, keeping the higher number
local d2 = { Pity = { Knife = 12, Dojo = 2, Beast = 9 } }
CrateSaves.migrate(d2)
check("into the knife crate with the highest count (Beast)", d2.Pity.Beast == 12 and d2.Pity.Dojo == 2 and d2.Pity.Knife == nil)
local d3 = { Pity = { Knife = 5, Storm = 20 } }
CrateSaves.migrate(d3)
check("never lowers a count (Storm keeps 20)", d3.Pity.Storm == 20 and d3.Pity.Knife == nil)

-- keys carry over too
local d4 = { Pity = {}, CrateKeys = { Knife = 2, Dojo = 1 } }
CrateSaves.migrate(d4)
check("old Knife keys are added to the Dojo Chest", d4.CrateKeys.Dojo == 3 and d4.CrateKeys.Knife == nil)

-- running it again changes nothing
check("a second run does nothing", CrateSaves.migrate(d2) == false and d2.Pity.Beast == 12)

print(string.format("CrateSaves: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
