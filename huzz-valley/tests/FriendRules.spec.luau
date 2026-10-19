-- Friend rewards (Shared/FriendRules, Config/Friends; owner, Oct 19: "add a friend knife (for inviting them) and add a
-- 10% coin boost when a friend is in"). Run from huzz-valley/ or the repo root: lune run tests/FriendRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local FriendRules = Env.load("huzz-valley/src/ReplicatedStorage/Shared/FriendRules.lua")
local Friends = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Friends.lua")
local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- +10% coins
check("no friend: the same pay", FriendRules.coins(50, false) == 50)
check("a friend: +10%", FriendRules.coins(50, true) == 55)
check("whole coins", FriendRules.coins(25, true) == 28 and FriendRules.coins(15, true) == 17)
check("never less", FriendRules.coins(1, true) >= 1 and FriendRules.coins(0, true) == 0)

-- the friend knife: a real knife, once per account, coins when already owned
local knife = CoinShop.get(Friends.Knife)
check("the friend knife is a real knife", knife ~= nil and knife.Slot == "Knife" and knife.Name == Friends.KnifeName)
check("not a Robux pass knife", knife and knife.Pass == nil)
local data = { Cosmetics = {}, Coins = 0 }
check("first friend: the knife", FriendRules.grant(data) == "Knife" and data.Cosmetics[Friends.Knife] == true)
check("only once", FriendRules.grant(data) == nil and data.Coins == 0)
local has = { Cosmetics = { [Friends.Knife] = true }, Coins = 10 }
check("already owned: coins instead", FriendRules.grant(has) == "Coins" and has.Coins == 10 + Friends.FriendKnifeCoins)
check("the coins line says the amount", string.find(Friends.CoinsToast, tostring(Friends.FriendKnifeCoins), 1, true) ~= nil)

print(string.format("FriendRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("FriendRules spec failed") end
