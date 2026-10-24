-- The winner page's standings (Shared/Standings) and XP parts (Config/Progression.xpParts); owner, Oct 19: "winner
-- page" (his picture a). Run from huzz-valley/ or the repo root: lune run tests/Standings.spec.luau
local Env = require("../tools/preview/motion3d/env")
local S = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Standings.lua")
local Progression = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Progression.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local board = {
	{ user = 1, name = "emyu", crossed = 2, catches = 3, rescues = 0, heroes = 0, won = true },
	{ user = 2, name = "Enooo", crossed = 0, catches = 11, rescues = 0, heroes = 0, won = true },
	{ user = 3, name = "Aloninja", crossed = 1, catches = 1, rescues = 1, heroes = 0, won = false },
	{ user = 4, name = "Zed", crossed = 4, catches = 1, rescues = 0, heroes = 1, won = false },
	{ user = 5, name = "Nobody", crossed = 0, catches = 0, rescues = 0, heroes = 0, won = false },
}
local c = S.top(board, "Catches")
check("catches: 3 shown", #c == 3)
check("catches: #1 Enooo 11", c[1].entry.name == "Enooo" and c[1].value == 11 and S.placeText(c[1]) == "#1")
check("catches: #2 emyu 3", c[2].entry.name == "emyu" and S.placeText(c[2]) == "#2")
check("catches: a tie is Joint #3 (as in his picture)", c[3].value == 1 and S.placeText(c[3]) == "Joint #3")
check("catches text", S.text("Catches", 11) == "11 Catches" and S.text("Catches", 1) == "1 Catch")
local sv = S.top(board, "Survival")
check("survival: most crossings first", sv[1].entry.name == "Zed" and sv[1].value == 4 and S.text("Survival", 4) == "4 Crossings")
check("survival: nobody with 0", #sv == 3 and sv[3].entry.name == "Aloninja")
local m = S.top(board, "MVP")
check("mvp: points", S.value(board[2], "MVP") == 3 * 11 + 5 and m[1].entry.name == "Enooo")
check("mvp: no joint when different", not m[1].joint and S.placeText(m[1]) == "#1")
check("nobody scored: empty", #S.top({ board[5] }, "Catches") == 0)
check("a tie at the top shares #1", S.placeText(S.top({ board[3], board[4] }, "Catches")[2]) == "Joint #1")
check("bad numbers are 0", S.value({ crossed = "x", catches = -2 }, "MVP") == 0)
check("default tab", S.defaultTab("Catchers") == "Catches" and S.defaultTab("Runners") == "Survival" and S.defaultTab("Runners", true) == "MVP")
check("the same order every time", S.top(board, "Catches")[3].entry.name == c[3].entry.name)

-- XP parts add up to the game's XP
for _, case in { { true, { Crossings = 3, Catches = 2, Rescues = 1, HeroPaid = 1 } }, { false, {} }, { true, { Catches = 11 } } } do
	local total = 0
	for _, p in Progression.xpParts(case[1], case[2]) do total += p.XP end
	check("xp parts add up", total == Progression.gameXP(case[1], case[2]))
end
local parts = Progression.xpParts(false, { Crossings = 2 })
check("xp parts leave out 0", #parts == 2 and parts[2].Name == "Crossings")

print(string.format("Standings: %d passed, %d failed", passed, failed))
if failed > 0 then error("Standings spec failed") end
