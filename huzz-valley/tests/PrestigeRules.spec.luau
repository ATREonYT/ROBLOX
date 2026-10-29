-- Prestige (Shared/PrestigeRules; owner, Oct 19: "if you get more than one of the same girl, make a button which makes
-- them prestige that gives them cooler vfx"). Run from huzz-valley/ or the repo root: lune run tests/PrestigeRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local P = Env.load("huzz-valley/src/ReplicatedStorage/Shared/PrestigeRules.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local data = { Characters = { G1 = 1 }, Copies = { G1 = { Normal = 1 } }, Prestige = {} } -- (one copy: Shared/CombineRules)
check("starts at 0", P.level(data, "G1") == 0 and P.copies(data, "G1") == 0)
local ok, why = P.can(data, "G1")
check("no copy: can't", not ok and why == "Win her again to prestige her.")
ok, why = P.can(data, "G2")
check("not owned: can't", not ok and why == "You don't own her yet.")
check("bad id refused", (P.can(data, 5)) == false and (P.apply(data, nil)) == nil)
P.addCopy(data, "G1")
check("a won copy counts", P.copies(data, "G1") == 1)
check("prestige 1 spends the copy", P.apply(data, "G1") == 1 and P.copies(data, "G1") == 0)
for _ = 1, 5 do P.addCopy(data, "G1") end
check("up to 3", P.apply(data, "G1") == 2 and P.apply(data, "G1") == 3)
local lv, w = P.apply(data, "G1")
check("never past 3", lv == nil and w == "She's at top prestige!" and P.level(data, "G1") == 3)
check("spare copies kept at the top", P.copies(data, "G1") == 3)
check("an old save (no tables) works", P.level({}, "G1") == 0 and P.copies({}, "G1") == 0)
local C = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CombineRules.lua")
local old = { Characters = { G1 = 1 }, Dupes = { G1 = 1 } } -- (an Oct 19 save: one girl and a spare copy)
C.migrate(old)
check("an old save's spare copy carries over", P.copies(old, "G1") == 1 and old.Dupes == nil)
check("an old save prestiges", P.apply(old, "G1") == 1 and old.Prestige.G1 == 1 and C.count(old, "G1", "Normal") == 1)
-- the combine machine shares the copies: prestige never takes her last one
local mixed = { Characters = { G1 = 1 }, Copies = { G1 = { Normal = 1, Gold = 1 } } }
check("a Normal next to a Gold is spare", P.copies(mixed, "G1") == 1)
local lone = { Characters = { G1 = 1 }, Copies = { G1 = { Silver = 1 } } }
check("no Normal copy: none spare", P.copies(lone, "G1") == 0 and (P.apply(lone, "G1")) == nil)

-- cooler effects: one tier up per level, capped at Mythic, Secret stays Secret
check("Common 0 = Common", P.effectRarity("Common", 0) == "Common")
check("Common 1 = Uncommon", P.effectRarity("Common", 1) == "Uncommon")
check("Rare 3 = Mythic", P.effectRarity("Rare", 3) == "Mythic")
check("Epic 3 capped at Mythic", P.effectRarity("Epic", 3) == "Mythic")
check("Mythic stays Mythic", P.effectRarity("Mythic", 3) == "Mythic")
check("Secret stays Secret", P.effectRarity("Secret", 2) == "Secret")
check("unknown rarity unchanged", P.effectRarity("", 2) == "")
check("label", P.label(2) == "PRESTIGE 2/3")

print(string.format("PrestigeRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("PrestigeRules spec failed") end
