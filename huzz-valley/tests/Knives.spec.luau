-- lune run tests/Knives.spec.luau   (from huzz-valley/)
-- The owner's 30 knives (Oct 18): all 30 in the coin shop's Knife slot (and his 5 Game Pass knives, given only by
-- their pass; and his 18 Halloween knives, Oct 19: one group of three sets of 6, each set Common to Mythic in his
-- order, on the same price ladder, never "limited") with their own names and rarities, in rarity
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
local baked, bakedPass, bakedHalloween = {}, {}, {}
for _, b in bakedAll do
	table.insert(if b.rarity == "Exclusive" then bakedPass elseif string.find(b.file, "halloween/", 1, true) then bakedHalloween else baked, b)
end
local knives, passKnives, halloween = {}, {}, {}
for _, item in CoinShop.Items do
	if item.Slot == "Knife" then
		table.insert(if item.Pass then passKnives elseif item.Set then halloween else knives, item)
	end
end
table.sort(halloween, function(a, b) return a.Order < b.Order end)
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
	check(item.Key .. ": Exclusive", item.Rarity == "Exclusive" and KnifeLook.fx("Exclusive") == KnifeLook.fx("Mythic"))
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

-- his 18 Halloween knives (design/knives/halloween/Halloween_Knives.glb): coin knives like the 30, one group of three
-- sets of 6 in his rows, each set Common to Mythic in his order, priced on the same ladder, sold all year
check("18 Halloween knives in the Knife slot", #halloween == 18 and #bakedHalloween == 18)
check("the Halloween file is there", fs.isFile(ROOT .. "design/knives/halloween/Halloween_Knives.glb"))
local SETS = { "Pumpkin", "Witch", "Candy" }
for i, item in halloween do
	local b = bakedHalloween[i]
	local set, at = SETS[(i - 1) // 6 + 1], (i - 1) % 6 + 1
	check(item.Key .. ": baked from his Halloween file, his name", b ~= nil and b.key == item.Key and b.name == item.Name
		and item.Model == "Halloween_Knives/" .. b.node)
	check(item.Key .. ": in the " .. set .. " set, place " .. at, item.Set == set and b.set == set)
	check(item.Key .. ": rarity climbs in its set", item.Rarity == KnifeLook.ORDER[at] and item.Rarity == b.rarity)
	check(item.Key .. ": priced by rarity, for sale", item.Price == PRICE[item.Rarity] and not item.NotForSale and not item.Unlock and not item.Pass)
	check(item.Key .. ": its own length (" .. tostring(item.Studs) .. " studs)", item.Studs == b.studs and item.Studs >= 1 and item.Studs <= 3.3)
	check(item.Key .. ": Wide as baked", item.Wide == b.wide)
	check(item.Key .. ": a glow colour when its model glows", (item.Glow ~= nil) == (b.glow ~= nil))
	check(item.Key .. ": listed together, in his order", i == 1 or item.Order == halloween[i - 1].Order + 1)
	local kebab = string.lower((string.gsub(item.Key, "(%l)(%u)", "%1-%2")))
	check(item.Key .. ": card picture file", item.Art ~= nil and fs.isFile(ROOT .. "assets/art/knife-" .. kebab .. ".png"))
	check(item.Key .. ": card picture packed with the exact name", item.Art ~= nil and packed[item.Art .. ".lua"] == true)
	local words = string.lower(item.Name .. " " .. (item.Unlock or ""))
	check(item.Key .. ": no timer or limited wording (kid-safe)", not string.find(words, "limited") and not string.find(words, "left"))
end

-- effects: only the swing (owner, Oct 20: "please fix the knifes finally ... just make them be normal"): no glow,
-- sparkles, glints, embers or anything else on the knife; each rarity keeps what the one below has
check("the default knife: no effects", next(KnifeLook.fx(nil)) == nil)
check("Common: only a faint trail in its own colour", KnifeLook.fx("Common").trailTint and KnifeLook.fx("Common").trailSoft)
local keys = { "trailTint", "arc" }
for r = 2, #KnifeLook.ORDER do
	local lower, this = KnifeLook.fx(KnifeLook.ORDER[r - 1]), KnifeLook.fx(KnifeLook.ORDER[r])
	for _, k in keys do
		check(KnifeLook.ORDER[r] .. " keeps " .. k, lower[k] == nil or this[k] ~= nil)
	end
end
for _, r in KnifeLook.ORDER do
	local f = KnifeLook.fx(r)
	check(r .. ": nothing on the knife (no glow, sparkles, glint, embers, sheen)", f.glow == nil and f.sparkles == nil
		and f.glint == nil and f.embers == nil and f.sheen == nil and f.back == nil)
	local tl = KnifeLook.trailLook({ Rarity = r, Glow = roblox.Color3.fromRGB(255, 0, 0) }, nil)
	check(r .. ": the slash trail in its own colour", tl.colours[1].R > 0.9 and tl.colours[1].G < 0.5)
end
check("Epic and up: the slash arc", KnifeLook.fx("Epic").arc and not KnifeLook.fx("Rare").arc)
check("default knife: a faint white trail", KnifeLook.trailLook(nil, nil).colours[1] == roblox.Color3.new(1, 1, 1))
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

-- the knife effects (owner, Oct 20: "make the vfx for some swords way better ... better for more high end ones";
-- Huss Valley's restraint AND visibility: 2 to 4 clear motes in the gem's colour, the motif, a glowing gem, a glint;
-- Shared/KnifeLook.vfx)
do
	local V = KnifeLook.VFX
	local every = table.clone(knives)
	for _, list in { passKnives, halloween } do for _, it in list do table.insert(every, it) end end
	for _, item in every do
		local tier = V.TIER[item.Rarity or ""] or 0
		local hand, back, stand = KnifeLook.vfx(item, "hand"), KnifeLook.vfx(item, "back"), KnifeLook.vfx(item, "stand")
		if tier == 0 then
			check(item.Key .. ": " .. tostring(item.Rarity) .. " stays plain (no effects anywhere)", hand == nil and back == nil and stand == nil)
		else
			check(item.Key .. ": a theme tied to its name (" .. tostring(V.OF[item.Key]) .. ")", hand ~= nil and V.THEMES[V.OF[item.Key]] ~= nil)
			if hand then
				local function total(fx)
					local t, bad, glint = 0, 0, 0
					for _, e in (fx and fx.emit or {}) do
						t += e.rate
						if not string.find(e.tex, "^rbxasset://textures/particles/") then bad += 1 end
						if e.role == "glint" and e.tex == V.TEX.Sparkle and e.lock then glint = math.max(glint, e.rate) end
					end
					return t, bad, glint
				end
				local h, badH, glint = total(hand)
				local w, badW = total(back)
				check(item.Key .. string.format(": in hand a few a second (%.1f), only built-in pictures", h), h > 0 and h <= V.MaxTotal and badH == 0 and badW == 0)
				check(item.Key .. ": the gem's glint no more than one about every 2 s (kid-safe)", glint <= 0.6)
				check(item.Key .. string.format(": worn lighter than in hand (%.1f), no light, no burst", w), w <= h and (back == nil or (back.light == nil and back.burst == 0)))
				check(item.Key .. ": a light only from Legendary up", (hand.light ~= nil) == (tier >= 3))
				check(item.Key .. ": Rare is one subtle touch", tier ~= 1 or #hand.emit == 1)
				-- how many motes are on show at once (rate x mean life), and how big
				local shown, size, alpha = 0, 0, 0
				for _, e in hand.emit do
					if e.role == "motes" then shown, size, alpha = e.rate * (e.life[1] + e.life[2]) / 2, e.size, e.alpha end
				end
				if tier >= 3 then
					check(item.Key .. string.format(": 2 to 4 crisp ball motes in hand (%d) and worn (%d), the particle motes a light extra (%.1f on show)",
						hand.balls, back.balls, shown), hand.balls >= 2 and hand.balls <= 4 and back.balls >= 2 and back.balls <= 4 and shown <= 2.5)
				elseif tier == 2 then
					check(item.Key .. string.format(": Epic 1 or 2 ball motes (%d)", hand.balls), hand.balls >= 1 and hand.balls <= 2)
				elseif tier == 1 then
					check(item.Key .. string.format(": Rare one or two faint particle motes (%.1f on show), no balls", shown),
						shown >= 0.5 and shown <= 2 and alpha <= 0.6 and hand.balls == 0)
				end
				check(item.Key .. ": the gem glows solid from Epic up (a Neon ball, not a see-through bubble), never changing",
					(hand.glow ~= nil) == (tier >= 2) and (hand.glow == nil or hand.glow.Transparency <= 0.2))
			end
		end
	end
	-- the ball motes' paths (Shared/KnifeMotes, as Gameplay/KnifeFxRange moves them): soft fades, never a blink, never
	-- inside the blade, 2 to 4 showing at once with 3 balls
	local KnifeMotes = Env.load(SHARED .. "KnifeMotes.lua")
	local box, size = Vector3.new(0.12, 2.2, 0.45), 0.16
	local worstStep, inside, minShown, maxShown, peak = 0, 0, 99, 0, 1
	local last = {}
	for f = 0, 60 * 20 do
		local t = f / 60
		local shownNow = 0
		for i = 1, 3 do
			local offset, _, tr = KnifeMotes.at(i, 3, t, 2.5, box, size, 0.2)
			if last[i] then worstStep = math.max(worstStep, math.abs(tr - last[i])) end
			last[i] = tr
			peak = math.min(peak, tr)
			if tr < 0.6 then shownNow += 1 end
			if math.abs(offset.Z) < box.Z / 2 + size * 0.5 and math.abs(offset.X) < box.X / 2 + size * 0.5 then inside += 1 end
		end
		minShown, maxShown = math.min(minShown, shownNow), math.max(maxShown, shownNow)
	end
	check(string.format("ball motes fade softly (at most %.3f a frame at 60 fps: a 0.5 s fade or slower)", worstStep), worstStep <= 1 / 30 + 1e-6)
	check(string.format("ball motes reach full strength (transparency %.2f)", peak), peak <= 0.12)
	check(string.format("ball motes never sit inside the blade (%d frames)", inside), inside == 0)
	check(string.format("2 to 3 of 3 ball motes clearly showing at any moment (%d to %d)", minShown, maxShown), minShown >= 2 and maxShown <= 3)
	for name, theme in V.THEMES do
		check(name .. ": motes and a motif", theme.motes ~= nil and theme.motif ~= nil)
	end
end

print(`Knives: {passed} ok, {failed} failed`)
if failed > 0 then error("Knives spec failed") end
