-- lune run tests/Knives.spec.luau   (from huzz-valley/)
-- The owner's 30 knives (Oct 18): all 30 in the coin shop's Knife slot with their own names and rarities, in rarity
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

local baked = serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json"))
local knives = {}
for _, item in CoinShop.Items do
	if item.Slot == "Knife" then table.insert(knives, item) end
end
table.sort(knives, function(a, b) return a.Order < b.Order end)
check("30 knives in the Knife slot", #knives == 30)
check("30 knife models baked", #baked == 30)

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
check("Uncommon: a sheen only", KnifeLook.fx("Uncommon").sheen and not KnifeLook.fx("Uncommon").glow)
check("Rare: a soft glow, no sparkles", KnifeLook.fx("Rare").glow and not KnifeLook.fx("Rare").sparkles)
check("Epic: sparkles and the tinted slash, not on the back", KnifeLook.fx("Epic").sparkles and KnifeLook.fx("Epic").trailTint and not KnifeLook.fx("Epic").back)
for _, r in KnifeLook.ORDER do
	local f = KnifeLook.fx(r)
	check(r .. ": at most 4 sparkles a second", (f.sparkles or 0) <= 4 and KnifeLook.MAX_SPARKLES <= 4)
	check(r .. ": a small light", not f.glow or f.glow.range <= 4.5)
	check(r .. ": the sheen is a glint now and then (no flashing)", (f.sheen or 0) <= 1)
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
