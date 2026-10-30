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

-- the friend knife (Oct 24 06:38: "one knife for exmaple rewarded for inviting 5 friends"): his Thousand Blossom at the
-- 5th different friend who joins you, coins for the first, once per account, coins when already owned
local knife = CoinShop.get(Friends.Knife)
check("the friend knife is a real knife", knife ~= nil and knife.Slot == "Knife" and knife.Name == Friends.KnifeName)
check("not a Robux pass knife and never sold", knife and knife.Pass == nil and knife.NotForSale == true)
check("5 friends", Friends.Need == 5)
local data = { Cosmetics = {}, Coins = 0 }
check("no friend id: nothing", FriendRules.grant(data, nil) == nil and data.Coins == 0)
check("first friend: coins", FriendRules.grant(data, 101) == "Coins" and data.Coins == Friends.FirstCoins and not data.Cosmetics[Friends.Knife])
check("the same friend again: nothing", FriendRules.grant(data, 101) == nil and FriendRules.met(data) == 1)
check("2nd to 4th: counted", FriendRules.grant(data, 102) == "More" and FriendRules.grant(data, 103) == "More" and FriendRules.grant(data, 104) == "More" and FriendRules.met(data) == 4)
check("no knife before 5", not data.Cosmetics[Friends.Knife] and data.Coins == Friends.FirstCoins)
check("5th friend: the knife", FriendRules.grant(data, 105) == "Knife" and data.Cosmetics[Friends.Knife] == true and data.FriendKnife == true)
check("only once", FriendRules.grant(data, 106) == nil and data.Coins == Friends.FirstCoins)
local has = { Cosmetics = { [Friends.Knife] = true }, Coins = 10, FriendReward = true }
for id = 1, 4 do FriendRules.grant(has, id) end
check("already owned: coins instead", FriendRules.grant(has, 5) == "Coins" and has.Coins == 10 + Friends.FriendKnifeCoins)
local old = { Cosmetics = { CandyKnife = true }, Coins = 0, FriendReward = true }
check("an old save (got the Sakura Blade) keeps it, no second first-friend coins", FriendRules.grant(old, 9) == "More" and old.Cosmetics.CandyKnife and old.Coins == 0)
check("the coins line says the amount", string.find(Friends.CoinsToast, tostring(Friends.FirstCoins), 1, true) ~= nil)
check("the toast lines name the knife", string.find(Friends.KnifeToast, Friends.KnifeName, 1, true) ~= nil and string.find(Friends.InviteHint, Friends.KnifeName, 1, true) ~= nil)

print(string.format("FriendRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("FriendRules spec failed") end
