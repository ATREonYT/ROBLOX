-- lune run tests/Playtime.spec.luau
-- The playtime coin boost (Config/Playtime, owner Oct 24 06:12): steps of +10% up to +100%.
local P = require("../src/ReplicatedStorage/Shared/Config/Playtime")
local ok, bad = 0, 0
local function check(cond, what)
	if cond then ok += 1 else bad += 1; print("FAIL " .. what) end
end
check(P.coins(50, 0) == 50, "no steps: the pay as it is")
check(P.coins(50, 3) == 65, "3 steps: +30%")
check(P.coins(50, 99) == 100, "never past Max (+100%)")
check(P.coins(50, -2) == 50, "never below the pay")
check(P.tag(3) == "+30% COINS" and P.tag(10) == "+100% COINS", "the tag's words")
check(P.Every >= 60 and P.Max * P.Step <= 1.0001, "a step takes at least a minute; at most double pay")
print(`Playtime: {ok} ok, {bad} failed`)
if bad > 0 then error("Playtime spec failed") end
