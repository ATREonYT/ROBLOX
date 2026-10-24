-- lune run tests/AdminRules.spec.luau   (from huzz-valley/)
-- The owner's admin panel (Oct 18: "give me a admin command panel ... so i can get any knife or any girl to spawn"):
-- only the game's owner may use it (Studio, the place's creator, or the owner of the group that made it), and a
-- request from anyone else is refused before anything happens, whatever it asks for. The real server code refusing
-- a non-admin and granting the owner: tools/preview/check_admin.luau.
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Admin = Env.load(SHARED .. "AdminRules.lua")
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- who
check("a stranger in the live game is refused", not Admin.isAdmin({ studio = false, userId = 111, creatorId = 999, creatorType = "User" }))
check("the place's creator is an admin", Admin.isAdmin({ studio = false, userId = 999, creatorId = 999, creatorType = "User" }))
check("Studio (his own testing) is an admin", Admin.isAdmin({ studio = true, userId = 111, creatorId = 999, creatorType = "User" }))
check("a group game: the group's owner (rank 255) is an admin", Admin.isAdmin({ studio = false, userId = 5, creatorId = 77, creatorType = "Group", groupRank = 255 }))
check("a group game: a member below owner (254) is refused", not Admin.isAdmin({ studio = false, userId = 5, creatorId = 77, creatorType = "Group", groupRank = 254 }))
check("a group game: someone outside the group is refused", not Admin.isAdmin({ studio = false, userId = 5, creatorId = 77, creatorType = "Group", groupRank = 0 }))
check("a group game: a user whose id equals the group id is still refused", not Admin.isAdmin({ studio = false, userId = 77, creatorId = 77, creatorType = "Group", groupRank = 0 }))
check("no creator known (unpublished place, live) refuses everyone", not Admin.isAdmin({ studio = false, userId = 0, creatorId = 0, creatorType = "User" }))
check("no information refuses", not Admin.isAdmin({}))

-- what: a non-admin is refused for every verb, even with a real knife or girl
local function girl(id) return if id == "Girl_E2B52D" then { id = id } else nil end
for verb, arg in { GiveKnife = "CrimsonRequiem", SpawnGirl = "Girl_E2B52D", NextGirl = "Girl_E2B52D" } do
	local ok, why = Admin.check(false, verb, arg, CoinShop.get, girl)
	check("non-admin " .. verb .. " is refused (says why)", ok == false and type(why) == "string")
	check("admin " .. verb .. " " .. arg .. " is allowed", Admin.check(true, verb, arg, CoinShop.get, girl) == true)
end
check("an unknown verb is refused", not Admin.check(true, "GiveGems", "1000", CoinShop.get, girl))

-- Oct 21 15:22: him and thebiglion12 in the live game (Config/Admins), and the gifts
local Admins = Env.load(SHARED .. "Config/Admins.lua")
local Products = Env.load(SHARED .. "Config/Products.lua")
check("thebiglion12 in the live game is an admin (by username, any capitals)", Admin.isAdmin({ studio = false, userId = 5, creatorId = 999, creatorType = "User", name = "TheBigLion12", admins = Admins }))
check("the owner by username is an admin even if the game is a group's", Admin.isAdmin({ studio = false, userId = 6, creatorId = 77, creatorType = "Group", groupRank = 0, name = "ATRE_playzYT", admins = Admins }))
check("someone else with the list there is still refused", not Admin.isAdmin({ studio = false, userId = 7, creatorId = 999, creatorType = "User", name = "thebiglion13", admins = Admins }))
check("a user ID on the list is an admin", Admin.isAdmin({ studio = false, userId = 42, creatorId = 999, creatorType = "User", name = "x", admins = { UserIds = { 42 }, Names = {} } }))
check("a 0 user ID on the list lets nobody in", not Admin.isAdmin({ studio = false, userId = 0, creatorId = 999, creatorType = "User", admins = { UserIds = { 0 }, Names = {} } }))
check("coins: a whole number 1..1,000,000", Admin.check(true, "GiveCoins", "5000", CoinShop.get, girl) and not Admin.check(true, "GiveCoins", "0", CoinShop.get, girl)
	and not Admin.check(true, "GiveCoins", "2.5", CoinShop.get, girl) and not Admin.check(true, "GiveCoins", "99999999", CoinShop.get, girl) and not Admin.check(true, "GiveCoins", "lots", CoinShop.get, girl))
check("aura: the same", Admin.check(true, "GiveAura", "700", CoinShop.get, girl) and not Admin.check(true, "GiveAura", "-5", CoinShop.get, girl))
check("every game pass can be given", (function()
	for _, p in Products.Passes do
		if not Admin.check(true, "GivePass", p.Key, CoinShop.get, girl, Products.get) then return false end
	end
	return #Products.Passes > 0
end)())
check("a developer product isn't a pass", not Admin.check(true, "GivePass", "Coins500", CoinShop.get, girl, Products.get))
check("all knives: only 'all'", Admin.check(true, "AllKnives", "all", CoinShop.get, girl) and not Admin.check(true, "AllKnives", "x", CoinShop.get, girl))
check("a non-admin can't give coins", not Admin.check(false, "GiveCoins", "5", CoinShop.get, girl))
check("a knife that doesn't exist is refused", not Admin.check(true, "GiveKnife", "Nope", CoinShop.get, girl))
check("a trail isn't a knife", not Admin.check(true, "GiveKnife", "MintTrail", CoinShop.get, girl))
check("a girl that isn't in the place is refused", not Admin.check(true, "SpawnGirl", "Nobody", CoinShop.get, girl))
check("a missing or odd argument is refused", not Admin.check(true, "GiveKnife", nil, CoinShop.get, girl) and not Admin.check(true, "GiveKnife", 5, CoinShop.get, girl) and not Admin.check(true, "GiveKnife", string.rep("x", 200), CoinShop.get, girl))
check("every knife in the shop can be given", (function()
	for _, item in CoinShop.Items do
		if item.Slot == "Knife" and not Admin.check(true, "GiveKnife", item.Key, CoinShop.get, girl) then return false end
	end
	return true
end)())

-- END GAME (owner, Oct 24 06:57: "make a admin command to end the game")
check("an admin can end the game", Admin.check(true, "EndGame", "now", CoinShop.get, girl) == true)
check("a stranger can't end the game", not Admin.check(false, "EndGame", "now", CoinShop.get, girl))
check("end game takes only 'now'", not Admin.check(true, "EndGame", "later", CoinShop.get, girl))
print(`AdminRules: {passed} ok, {failed} failed`)
if failed > 0 then error("AdminRules spec failed") end
