-- lune run tests/Knives.spec.luau   (from huzz-valley/)
-- The owner's 30 knives (Oct 18): all 30 in the coin shop's Knife slot (and his 5 Game Pass knives, given only by
-- their pass) with their own names and rarities, in rarity
-- order, priced by rarity; the quest knives and the Spin Knife sit on fitting models and are never sold; every knife
-- has its card picture (case-exact); the effects climb calmly with rarity; and a catcher's Space leap goes forward or
-- sideways, never back. Where a worn knife sits: tests/KnifeWear.spec.luau.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local Progression = Env.load(SHARED .. "Config/Progression.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeLeap = Env.load(SHARED .. "KnifeLeap.lua")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local bakedAll = serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json"))
local baked, bakedPass = {}, {}
for _, b in bakedAll do table.insert(if b.rarity == "Exclusive" then bakedPass else baked, b) end
local knives, passKnives = {}, {}
for _, item in CoinShop.Items do
	if item.Slot == "Knife" then table.insert(if item.Pass then passKnives else knives, item) end
end
table.sort(knives, function(a, b) return a.Order < b.Order end)
table.sort(passKnives, function(a, b) return a.Order < b.Order end)
check("30 shop knives in the Knife slot", #knives == 30)
check("30 knife models baked", #baked == 30)

-- the 5 Game Pass knives (owner, Oct 18: "here are the gamepass knives"): his models, never sold for coins, given
-- only by their pass, shown on the lobby stands
check("5 Game Pass knives", #passKnives == 5 and #bakedPass == 5)
local Products = Env.load(SHARED .. "Config/Products.lua")
local perPass, packedArt = {}, {}
for _, f in fs.readDir(ROOT .. "src/ReplicatedStorage/Shared/Images/Art") do packedArt[f] = true end
for _, item in passKnives do
	local b
	for _, x in bakedPass do if x.key == item.Key then b = x end end
	check(item.Key .. ": baked from his gamepass file", b ~= nil and b.name == item.Name and item.Model == "Gamepass_Knives/" .. b.node)
	check(item.Key .. ": the gamepass file is there", fs.isFile(ROOT .. "design/knives/gamepass/Gamepass_Knives.glb"))
	check(item.Key .. ": Exclusive", item.Rarity == "Exclusive" and KnifeLook.fx("Exclusive").embers ~= nil)
	check(item.Key .. ": never sold for coins", item.NotForSale == true and item.Price == 0 and item.Unlock == nil)
	local pass = Products.get(item.Pass)
	check(item.Key .. ": its pass is a real Config/Products pass", pass ~= nil and pass.Kind == "Pass")
	check(item.Key .. ": a glow colour", item.Glow ~= nil and b ~= nil and b.glow ~= nil)
	check(item.Key .. ": length 2.4 to 3.3 studs", item.Studs and item.Studs >= 2.4 and item.Studs <= 3.3 and b ~= nil and item.Studs == b.studs)
	local kebab = string.lower((string.gsub(item.Key, "(%l)(%u)", "%1-%2")))
	check(item.Key .. ": card picture", item.Art ~= nil and fs.isFile(ROOT .. "assets/art/knife-" .. kebab .. ".png") and packedArt[item.Art .. ".lua"] == true)
	perPass[item.Pass] = (perPass[item.Pass] or 0) + 1
end
-- each knife is its own Game Pass (owner Oct 18: "these are going to be the gamepasses users can buy"), mapped to
-- his card names: Hunter = Crimson Requiem, Moonlit = Hollow Eclipse, Sunrise = Celestial Seraph, Inferno = Dragon's
-- Maw, Frost = Frostbound Oath; VIP and Dance Pack give no knife now
local MAP = { HunterKnifePass = "CrimsonRequiem", MoonlitKnifePass = "HollowEclipse", SunriseKnifePass = "CelestialSeraph", InfernoKnifePass = "DragonsMaw", FrostKnifePass = "FrostboundOath" }
for passKey, knife in MAP do
	check(passKey .. " gives exactly " .. knife, perPass[passKey] == 1 and CoinShop.get(knife).Pass == passKey)
end
check("VIP and Dance Pack give no knife now", perPass.VIP == nil and perPass.DancePack == nil)
-- granted only for an owned pass, once
local g = CoinShop.passGrants({}, { HunterKnifePass = true })
check("owning Hunter Knife gives Crimson Requiem only", #g == 1 and g[1] == "CrimsonRequiem")
check("owning nothing gives nothing", #CoinShop.passGrants({}, {}) == 0)
check("a pass you don't own gives nothing (FrostKnifePass false)", #CoinShop.passGrants({}, { FrostKnifePass = false }) == 0)
check("already owned isn't given again", #CoinShop.passGrants({ CrimsonRequiem = true }, { HunterKnifePass = true }) == 0)

local rank = {}
for i, r in KnifeLook.ORDER do rank[r] = i end
local PRICE = { Common = 200, Uncommon = 500, Rare = 1000, Epic = 2000, Legendary = 4000, Mythic = 8000 }
local files = {}
for _, f in fs.readDir(ROOT .. "design/knives/Knives") do files[f] = true end
local packed = {}
for _, f in fs.readDir(ROOT .. "src/ReplicatedStorage/Shared/Images/Art") do packed[f] = true end
local byModel = {}
for i, item in knives do
	local b = baked[i]
	byModel[item.Model or ""] = item
	check(item.Key .. ": its model's file exists", item.Model ~= nil and files[item.Model .. ".glb"] == true)
	check(item.Key .. ": the model's own name and rarity", b ~= nil and b.file == item.Model and b.name == item.Name and b.rarity == item.Rarity and b.key == item.Key)
	check(item.Key .. ": rarity order", i == 1 or rank[item.Rarity] >= rank[knives[i - 1].Rarity])
	check(item.Key .. ": a known rarity", rank[item.Rarity] ~= nil)
	local sold = not item.Unlock and not item.NotForSale
	if sold then
		check(item.Key .. ": priced by rarity", item.Price == PRICE[item.Rarity])
	else
		check(item.Key .. ": an earned knife has no price", item.Price == 0)
	end
	check(item.Key .. ": length 2.4 to 3.3 studs", item.Studs and item.Studs >= 2.4 and item.Studs <= 3.3)
	check(item.Key .. ": a glow colour when its model glows", (item.Glow ~= nil) == (b and b.glow ~= nil))
	-- the card picture: assets/art/knife-<key>.png packed as Images/Art/<Art>.lua, names exact (Roblox is case-sensitive)
	local kebab = string.lower((string.gsub(item.Key, "(%l)(%u)", "%1-%2")))
	check(item.Key .. ": card picture file", item.Art ~= nil and fs.isFile(ROOT .. "assets/art/knife-" .. kebab .. ".png"))
	check(item.Key .. ": card picture packed with the exact name", item.Art ~= nil and packed[item.Art .. ".lua"] == true)
end
for r = 1, #KnifeLook.ORDER - 1 do
	check("prices climb with rarity " .. r, PRICE[KnifeLook.ORDER[r]] < PRICE[KnifeLook.ORDER[r + 1]])
end
check("a Common costs about 8 games of pay (25 a game)", PRICE.Common / 25 <= 10)

-- quest knives and the Spin Knife: same keys, fitting models, never for sale
local function mapped(key, model, rule)
	local item = CoinShop.get(key)
	check(key .. " is the " .. model .. " model", item ~= nil and item.Model == model)
	check(key .. " keeps its rule", item ~= nil and rule(item))
	check(key .. " isn't sold", item ~= nil and (item.Unlock ~= nil or item.NotForSale == true))
end
mapped("RookieKnife", "03_Common_Training_Kunai", function(i) return i.Unlock ~= nil and i.Unlock:find("chapter 2") ~= nil end)
mapped("HunterKnife", "12_Uncommon_Hunter_s_Hook", function(i) return i.Unlock ~= nil and i.Unlock:find("chapter 3") ~= nil end)
mapped("MoonlitKnife", "22_Epic_Hollow_Moon", function(i) return i.Unlock ~= nil and i.Unlock:find("chapter 4") ~= nil end)
mapped("SpinKnife", "29_Legendary_Celestial_Edge", function(i) return i.NotForSale == true end)
for _, key in { "IceKnife", "CandyKnife", "ShadowKnife" } do -- (owned in old saves: still there, now on his models)
	check(key .. " still exists for old saves", CoinShop.get(key) ~= nil and CoinShop.get(key).Model ~= nil)
end
check("the quest reward says the knife's name", Progression.rewardText({ XP = 1, Reward = { Kind = "Knife", Id = "HunterKnife" } }) == "Hunter's Hook")
local sold = 0
for _, item in knives do if not item.Unlock and not item.NotForSale then sold += 1 end end
check("26 knives for sale", sold == 26)

-- effects: calm, and each rarity has what the one below has
check("Common: no effects", next(KnifeLook.fx("Common")) == nil and next(KnifeLook.fx(nil)) == nil)
local keys = { "sheen", "glow", "sparkles", "trailTint", "back", "embers" }
for r = 2, #KnifeLook.ORDER do
	local lower, this = KnifeLook.fx(KnifeLook.ORDER[r - 1]), KnifeLook.fx(KnifeLook.ORDER[r])
	for _, k in keys do
		check(KnifeLook.ORDER[r] .. " keeps " .. k, lower[k] == nil or this[k] ~= nil)
	end
end
check("Uncommon: nothing on his model (the white sheen glint hid it, Oct 19)", next(KnifeLook.fx("Uncommon")) == nil)
for _, r in KnifeLook.ORDER do check(r .. ": no sheen glint", KnifeLook.fx(r).sheen == nil) end
check("Rare: a soft glow, no sparkles", KnifeLook.fx("Rare").glow and not KnifeLook.fx("Rare").sparkles)
check("Epic: sparkles and the tinted slash, not on the back", KnifeLook.fx("Epic").sparkles and KnifeLook.fx("Epic").trailTint and not KnifeLook.fx("Epic").back)
for _, r in KnifeLook.ORDER do
	local f = KnifeLook.fx(r)
	check(r .. ": at most 4 sparkles a second", (f.sparkles or 0) <= 4 and KnifeLook.MAX_SPARKLES <= 4)
	check(r .. ": a small light", not f.glow or f.glow.range <= 4.5)
end
check("Legendary: light range about 4, glow on the back", KnifeLook.fx("Legendary").glow.range == 4 and KnifeLook.fx("Legendary").back)
check("Mythic: a few embers", KnifeLook.fx("Mythic").embers and KnifeLook.fx("Mythic").embers <= 2)
check("trail short (about 0.1 s)", KnifeLook.TRAIL.Lifetime <= 0.15)

-- where a worn knife sits (back / side, R15 / R6, all 30 on real bodies): tests/KnifeWear.spec.luau

-- the catcher's Space leap: the way you steer, never back
do
	local look = Vector3.new(0, 0, -1)
	local function near(a, b) return a ~= nil and (a - b).Magnitude < 1e-3 end
	check("nothing held: forward", near(KnifeLeap.direction(look, Vector3.zero), look))
	check("W: forward", near(KnifeLeap.direction(look, look), look))
	check("D: sideways right", near(KnifeLeap.direction(look, Vector3.new(1, 0, 0)), Vector3.new(1, 0, 0)))
	check("A: sideways left", near(KnifeLeap.direction(look, Vector3.new(-1, 0, 0)), Vector3.new(-1, 0, 0)))
	check("S: forward, never back", near(KnifeLeap.direction(look, Vector3.new(0, 0, 1)), look))
	check("S + D: right, never back", near(KnifeLeap.direction(look, Vector3.new(1, 0, 1).Unit), Vector3.new(1, 0, 0)))
	local wa = KnifeLeap.direction(look, Vector3.new(-1, 0, -1).Unit)
	check("W + A: forward-left", wa ~= nil and wa.X < -0.5 and wa.Z < -0.5)
	local worst = 1
	for i = 0, 71 do
		local a = math.rad(i * 5)
		local d = KnifeLeap.direction(look, Vector3.new(math.sin(a), 0, -math.cos(a)))
		worst = math.min(worst, d:Dot(look))
		check("flat", math.abs(d.Y) < 1e-6 and math.abs(d.Magnitude - 1) < 1e-4)
	end
	check(string.format("never backwards in any direction held (worst %.2f)", worst), worst >= -1e-6)
	local tilted = KnifeLeap.direction(Vector3.new(0, -0.5, -1).Unit, Vector3.new(0, 0.3, 0))
	check("looking down / tiny input: still flat forward", near(tilted, Vector3.new(0, 0, -1)))
end

print(`Knives: {passed} ok, {failed} failed`)
if failed > 0 then error("Knives spec failed") end
