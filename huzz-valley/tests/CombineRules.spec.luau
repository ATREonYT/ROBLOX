-- The Combine machine's rules and the save change (Shared/CombineRules; owner, Oct 20 14:57: "take two of the same
-- girl, and then it creates the same skin, but first in silver, then gold, and then diamond. make it so that you need
-- to have both of the types to go up"). Run from huzz-valley/ or the repo root: lune run tests/CombineRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local C = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CombineRules.lua")
local Config = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Combine.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- the ladder
check("grades in order", table.concat(C.Grades, ",") == "Normal,Silver,Gold,Diamond")
check("next", C.next("Normal") == "Silver" and C.next("Silver") == "Gold" and C.next("Gold") == "Diamond")
check("Diamond is the top", C.next("Diamond") == nil and C.next("Bronze") == nil and C.next(nil) == nil)
check("every grade has a look", Config.Grades.Normal and Config.Grades.Silver.Hair and Config.Grades.Gold.Fx and Config.Grades.Diamond.Material)
check("labels", C.label("Gold") == "GOLD" and C.label("Normal") == "")

-- two of the same girl at the same grade make one a grade up
local data = { Characters = { A = 1, B = 2 }, Copies = { A = { Normal = 2 }, B = { Normal = 1 } } }
check("two Normal: can", (C.can(data, "A", "Normal")))
local ok, why = C.can(data, "B", "Normal")
check("one Normal: can't, says so", not ok and why == "You need 2 Normal. You have 1.")
ok, why = C.can(data, "Z", "Normal")
check("not owned: can't", not ok and why == "You don't own her yet.")
check("bad input refused", (C.can(data, 5, "Normal")) == false and (C.can(data, "A", "Bronze")) == false and (C.can(data, "A", nil)) == false)
check("A Normal -> Silver", C.apply(data, "A", "Normal") == "Silver")
check("both Normal copies spent, one Silver", C.count(data, "A", "Normal") == 0 and C.count(data, "A", "Silver") == 1 and data.Copies.A.Normal == nil)
check("still owned, shows Silver", C.owns(data, "A") and C.best(data, "A") == "Silver")
check("merges counted", data.Combines == 1)
check("a Silver alone can't go up", (C.can(data, "A", "Silver")) == false)
-- different girls never mix: B's copy doesn't help A
C.add(data, "B", "Silver")
check("another girl's Silver doesn't count", (C.can(data, "A", "Silver")) == false and C.count(data, "A", "Silver") == 1)
-- different grades never mix: a Normal and a Silver of A can't make anything
C.add(data, "A", "Normal")
check("a Normal and a Silver can't combine", (C.can(data, "A", "Normal")) == false and (C.can(data, "A", "Silver")) == false)
-- all the way up
C.add(data, "A", "Silver")
check("two Silver -> Gold", C.apply(data, "A", "Silver") == "Gold" and C.count(data, "A", "Silver") == 0)
C.add(data, "A", "Gold")
check("two Gold -> Diamond", C.apply(data, "A", "Gold") == "Diamond" and C.best(data, "A") == "Diamond")
C.add(data, "A", "Diamond")
local top, topWhy = C.apply(data, "A", "Diamond")
check("two Diamond: nothing (the top)", top == nil and topWhy == "Diamond is the top!" and C.count(data, "A", "Diamond") == 2)
check("the Normal copy is still there", C.count(data, "A", "Normal") == 1 and C.total(data, "A") == 3)
-- three copies: one left after a merge
local three = { Characters = { A = 1 }, Copies = { A = { Normal = 3 } } }
C.apply(three, "A", "Normal")
check("three Normal: one left", C.count(three, "A", "Normal") == 1 and C.count(three, "A", "Silver") == 1)

-- winning her: add
local fresh = { Characters = {}, Copies = {} }
check("first copy is new", C.add(fresh, "G", nil, 123) == true and fresh.Characters.G == 123 and C.count(fresh, "G", "Normal") == 1)
check("second copy isn't new", C.add(fresh, "G") == false and C.count(fresh, "G", "Normal") == 2 and fresh.Characters.G == 123)
check("add on a save with no tables", C.add({}, "G") == true)
check("best of a girl you don't own is nil", C.best(fresh, "Q") == nil)

-- old saves: Characters + Dupes (the Oct 19 prestige copies) become Copies, once
local old = { Characters = { A = 1, B = 2, C = 3 }, Dupes = { A = 2, C = 0 }, Equipped = "A" }
check("migrate changes the three girls", C.migrate(old) == 3)
check("A: 1 + 2 spares", C.count(old, "A", "Normal") == 3)
check("B: one copy", C.count(old, "B", "Normal") == 1)
check("C: zero spares = one copy", C.count(old, "C", "Normal") == 1)
check("Dupes emptied and gone", old.Dupes == nil)
check("equipped girl untouched", old.Equipped == "A")
check("second migrate changes nothing", C.migrate(old) == 0 and C.count(old, "A", "Normal") == 3)
local weird = { Characters = { A = 1 }, Copies = { A = { Normal = 0, Bronze = 4, Gold = 1.7 }, Gone = { Normal = 5 } } }
C.migrate(weird)
check("junk grades dropped, counts made whole", weird.Copies.A.Bronze == nil and weird.Copies.A.Normal == nil and weird.Copies.A.Gold == 1)
check("copies of a girl no longer owned dropped", weird.Copies.Gone == nil)
local empty = { Characters = { A = 1 }, Copies = { A = {} } }
C.migrate(empty)
check("an owned girl with no copies gets one", C.count(empty, "A", "Normal") == 1)
check("migrate on nothing", C.migrate(nil) == 0 and C.migrate({}) == 0)

-- the window's list
local list = { { Id = "A", Name = "Yui", Model = "GA" }, { Id = "B", Name = "Ami", Model = "GB" }, { Id = "K", Name = "Kit girl" } }
local d2 = { Characters = { A = 1, B = 1, K = 1 }, Copies = { A = { Normal = 1, Silver = 2 }, B = { Normal = 1 }, K = { Normal = 5 } } }
local rows = C.choices(d2, list)
check("only real girls listed", #rows == 2)
check("ready girls first", rows[1].id == "A" and rows[1].ready == "Silver" and rows[2].ready == nil)
check("counts shown", rows[1].counts.Silver == 2 and rows[1].counts.Diamond == 0 and rows[1].best == "Silver")

-- the merge timeline stays short (owner: "not too long"): Shared/CombineMotion
local M = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CombineMotion.lua")
check("merge 3 to 4 s to the reveal's end", M.REVEAL_END >= 2.5 and M.REVEAL_END <= 4 and M.LENGTH <= 4.5)
check("one flash only", #M.FLASHES == 1)

print(string.format("CombineRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("CombineRules spec failed") end
