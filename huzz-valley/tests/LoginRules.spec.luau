-- Daily login rewards (Shared/LoginRules, Config/DailyLogin; owner, Oct 24 06:12: "lets make daily rewards", 06:38:
-- his Stormfang Chokuto "to be at day 7 of daily logins"). Run from huzz-valley/ or the repo root:
-- lune run tests/LoginRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local LoginRules = Env.load("huzz-valley/src/ReplicatedStorage/Shared/LoginRules.lua")
local DailyLogin = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/DailyLogin.lua")
local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local DAY = DailyLogin.DayLength
local T0 = 20380 * DAY + 9 * 3600 -- a morning (09:00 UTC)

check("7 days", #DailyLogin.Days == 7)
local seven = DailyLogin.Days[7]
local knife = CoinShop.get(seven.Id)
check("day 7 is his Stormfang Chokuto", seven.Kind == "Knife" and seven.Id == "StormfangChokuto" and knife ~= nil and knife.Slot == "Knife" and knife.Name == seven.Name)
check("never sold", knife and knife.NotForSale == true and knife.Pass == nil)
for i, r in DailyLogin.Days do
	check("day " .. i .. " is a kind we give", r.Kind == "Coins" or r.Kind == "Aura" or r.Kind == "Spins" or (r.Kind == "Knife" and CoinShop.get(r.Id) ~= nil))
	check("day " .. i .. " has a name", type(r.Name) == "string" and #r.Name > 0)
end

local data = { Coins = 0, Aura = 0, Spins = 0, Cosmetics = {} }
local i, ready = LoginRules.next(data.Login, T0)
check("a new save: day 1, ready", i == 1 and ready)
local r = LoginRules.claim(data, T0)
check("day 1 gives its coins", r == DailyLogin.Days[1] and data.Coins == DailyLogin.Days[1].Amount)
local again, why = LoginRules.claim(data, T0 + 3600)
check("once a day", again == nil and type(why) == "string")
i, ready = LoginRules.next(data.Login, T0 + 3600)
check("then day 2 waits", i == 2 and not ready)
check("the wait runs to the next day", LoginRules.wait(T0) == DAY - 9 * 3600)
LoginRules.claim(data, T0 + DAY)
check("day 2 the next day", data.Aura == DailyLogin.Days[2].Amount)
-- a missed day keeps your place (no streak to lose)
LoginRules.claim(data, T0 + 5 * DAY)
check("after missed days: day 3, not day 1", data.Spins == DailyLogin.Days[3].Amount and data.Login.Count == 3)
for d = 4, 6 do LoginRules.claim(data, T0 + (d + 3) * DAY) end
check("days 4-6", data.Login.Count == 6 and not data.Cosmetics.StormfangChokuto)
local r7, given = LoginRules.claim(data, T0 + 10 * DAY)
check("day 7: the knife", r7 == seven and given == "Knife" and data.Cosmetics.StormfangChokuto == true)
i = LoginRules.next(data.Login, T0 + 11 * DAY)
check("then back to day 1", i == 1)
for d = 1, 6 do LoginRules.claim(data, T0 + (10 + d) * DAY) end
local c0 = data.Coins
local _, g2 = LoginRules.claim(data, T0 + 17 * DAY)
check("day 7 again with the knife owned: coins", g2 == "Coins" and data.Coins == c0 + seven.Owned)
check("day 7 only once too", LoginRules.claim(data, T0 + 17 * DAY + 60) == nil)

print(string.format("LoginRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("LoginRules spec failed") end
