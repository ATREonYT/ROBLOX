--!strict
--[[
	The coin shop (owner's call: "make the coins usable"; they chose cosmetics): looks only, nothing that changes how
	the game plays. Bought and worn on the server (ActionService "BuyWithCoins" / "Wear"); shown to everyone.
	Every item is made from colours in code (no uploaded pictures needed), so all of it works today.
	  Slot   Trail = a streak behind you as you run; Tag = your name's colour over your head; Knife = the catcher's knife.
	  Colors two or three colours (a gradient); Rainbow = cycles through the colours.
	  Price  coins. Tune freely; the earn rate is in Config/Round (coins per round) and the quests.
	One item per slot is worn at a time; buying one wears it. Sunset Trail (a Robux cosmetic) is a Trail too.
	NotForSale: won elsewhere (the Spin Knife is the Spin the Wheel's Legendary): never sold for coins, and the ITEMS
	tab only shows it once you own it.
	Rewards (owner: "unique perks for characters that you obtain, legendaries - mythics - secrets have better
	looking cosmetics you can equip, that make you stand out; also add titles, like keeper of secrets"): never sold.
	  Earn   what unlocks it: { Rarity = "Secret" } own a girl that rare; { Stat = "Heroes", Count = 10 } a counter
	         in Stats (Config/Progression); { Girls = 10 } own that many girls. HuzzServer/RewardService grants it
	         (on join and whenever your save changes) and wears it if that slot is empty.
	  Rarity the colour the card and the title use (Config/Round.Rarities), shown on the card.
	  Aura   a glow round your body (HuzzServer/CosmeticsService builds it, everyone sees it).
	  Title  words over your name in the lobby (HuzzServer/NameTagService); your role shows there during a game.
	Pose and Outfit are the Robux cosmetics' slots (Crown Pose, Midnight Outfit in Config/Products).
	Knives: the owner's 30 models (see the Knives block below), shown in rarity order after the rewards.
	Pass: the Game Pass knives (owner, Oct 18: "im going to make them into gamepasses shown with the character of the
	  person playing, equipped with some exclusive knifes", then "here are the gamepass knives"): Pass = the
	  Config/Products pass that gives it. Never sold for coins (NotForSale), shown in ITEMS only once you own it, and
	  given only by HuzzServer/ShopService when Roblox says you own that pass. The lobby stands show them in your hand.
]]
export type Earn = { Rarity: string?, Stat: string?, Count: number?, Girls: number? }
export type Item = { Key: string, Slot: "Trail" | "Tag" | "Knife" | "Aura" | "Title", Name: string, Price: number, Colors: { Color3 }, Rainbow: boolean?, Order: number, NotForSale: boolean?, Unlock: string?, Earn: Earn?, Rarity: string?, Art: string?, Model: string?, Studs: number?, Glow: Color3?, Pass: string? }

local Products = require(script.Parent.Products)

local rgb = Color3.fromRGB
local hex = Color3.fromHex
local CoinShop = {}

CoinShop.Slots = { "Trail", "Tag", "Knife", "Aura", "Title", "Pose", "Outfit" }
CoinShop.SlotNames = { Trail = "TRAIL", Tag = "NAME COLOUR", Knife = "KNIFE", Aura = "AURA", Title = "TITLE", Pose = "POSE", Outfit = "OUTFIT" }

local LEGEND, MYTHIC = rgb(255, 190, 60), rgb(255, 84, 120)
local SECRET = { rgb(150, 110, 255), rgb(255, 90, 200), rgb(90, 220, 255) }

CoinShop.Items = {
	-- Trails
	{ Key = "MintTrail", Art = "ItemMintTrail", Slot = "Trail", Name = "Mint Trail", Price = 400, Colors = { rgb(140, 255, 210), rgb(60, 200, 160) }, Order = 1 },
	{ Key = "OceanTrail", Art = "ItemOceanTrail", Slot = "Trail", Name = "Ocean Trail", Price = 750, Colors = { rgb(120, 220, 255), rgb(40, 110, 255) }, Order = 2 },
	{ Key = "CandyTrail", Art = "ItemCandyTrail", Slot = "Trail", Name = "Candy Trail", Price = 1000, Colors = { rgb(255, 150, 210), rgb(170, 120, 255) }, Order = 3 },
	{ Key = "GalaxyTrail", Art = "ItemGalaxyTrail", Slot = "Trail", Name = "Galaxy Trail", Price = 2500, Colors = { rgb(120, 90, 255), rgb(255, 90, 200), rgb(90, 220, 255) }, Rainbow = true, Order = 4 },
	-- Name colours
	{ Key = "TagPink", Art = "ItemPinkName", Slot = "Tag", Name = "Pink Name", Price = 300, Colors = { rgb(255, 130, 200), rgb(255, 130, 200) }, Order = 5 },
	{ Key = "TagSky", Art = "ItemSkyName", Slot = "Tag", Name = "Sky Name", Price = 300, Colors = { rgb(110, 210, 255), rgb(110, 210, 255) }, Order = 6 },
	{ Key = "TagLime", Art = "ItemLimeName", Slot = "Tag", Name = "Lime Name", Price = 300, Colors = { rgb(150, 245, 110), rgb(150, 245, 110) }, Order = 7 },
	{ Key = "TagRainbow", Art = "ItemRainbowName", Slot = "Tag", Name = "Rainbow Name", Price = 1500, Colors = { rgb(255, 110, 110), rgb(255, 220, 90), rgb(110, 240, 140), rgb(110, 180, 255), rgb(200, 120, 255) }, Rainbow = true, Order = 8 },
	-- Rewards from the girls you get (rarest first, so they lead the ITEMS tab) and from playing well.
	{ Key = "TitleSecret", Slot = "Title", Name = "Keeper of Secrets", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = 16 },
	{ Key = "AuraSecret", Art = "ItemVoidHalo", Slot = "Aura", Name = "Void Halo", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = 17 },
	{ Key = "TrailSecret", Art = "ItemSecretComet", Slot = "Trail", Name = "Secret Comet", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = 18 },
	{ Key = "TitleMythic", Slot = "Title", Name = "Mythic Charmer", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { MYTHIC, rgb(255, 170, 200) }, Order = 19 },
	{ Key = "AuraMythic", Art = "ItemMythicBlaze", Slot = "Aura", Name = "Mythic Blaze", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { rgb(255, 150, 190), MYTHIC, rgb(150, 20, 70) }, Order = 20 },
	{ Key = "TrailMythic", Art = "ItemMythicStreak", Slot = "Trail", Name = "Mythic Streak", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { rgb(255, 200, 220), MYTHIC, rgb(150, 20, 70) }, Order = 21 },
	{ Key = "TitleLegend", Slot = "Title", Name = "Legend Hunter", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { LEGEND, rgb(255, 240, 190) }, Order = 22 },
	{ Key = "AuraLegend", Art = "ItemLegendGlow", Slot = "Aura", Name = "Legend Glow", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { rgb(255, 245, 200), LEGEND, rgb(255, 130, 40) }, Order = 23 },
	{ Key = "TrailLegend", Art = "ItemLegendStreak", Slot = "Trail", Name = "Legend Streak", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { rgb(255, 250, 220), LEGEND, rgb(255, 130, 40) }, Order = 24 },
	{ Key = "TitleCollector", Slot = "Title", Name = "Girl Collector", Price = 0, Earn = { Girls = 10 }, Unlock = "Own 10 girls", Colors = { rgb(255, 150, 210), rgb(255, 150, 210) }, Order = 25 },
	{ Key = "TitleHero", Slot = "Title", Name = "Huss Hero", Price = 0, Earn = { Stat = "Heroes", Count = 10 }, Unlock = "Make 10 hero runs", Colors = { rgb(91, 224, 122), rgb(91, 224, 122) }, Order = 26 },
	{ Key = "TitleGuardian", Slot = "Title", Name = "Guardian", Price = 0, Earn = { Stat = "Rescues", Count = 25 }, Unlock = "Save 25 friends", Colors = { rgb(110, 210, 255), rgb(110, 210, 255) }, Order = 27 },
	-- Knives (catchers hold theirs, everyone wears one on the back): the owner's own 30 models (design/knives/Knives,
	-- baked by tools/knives/bake_knives.py into tools/knives/knives.json), Common to Mythic. Model = the .glb it comes
	-- from; Studs = its length pommel to tip in the game; Glow = its glowing parts' colour (effects: Shared/KnifeLook);
	-- Colors = its blade and guard colours (the stand-in knife is painted in them until the owner's models are imported:
	-- tools/knives/setup_knives.lua). Prices by rarity against the pay (25 coins a game, 50 a win): 200 / 500 / 1,000 /
	-- 2,000 / 4,000 / 8,000. The quest knives (Unlock) and the Spin Knife (NotForSale) keep their keys and rules on the
	-- model that fits: Rookie = Training Kunai, Hunter = Hunter's Hook, Moonlit = Hollow Moon, Spin = Celestial Edge.
	-- Ice, Candy and Shadow Knife (sold before) are now Ice Shard, Sakura Blade and Shadow Cleaver, so saves keep them.
	{ Key = "RustyShiv", Slot = "Knife", Name = "Rusty Shiv", Rarity = "Common", Price = 200, Model = "01_Common_Rusty_Shiv", Studs = 2.48, Art = "KnifeRustyShiv", Colors = { hex("8a7a6a"), hex("8a8a90") }, Order = 101 },
	{ Key = "KitchenCleaver", Slot = "Knife", Name = "Kitchen Cleaver", Rarity = "Common", Price = 200, Model = "02_Common_Kitchen_Cleaver", Studs = 2.42, Art = "KnifeKitchenCleaver", Colors = { hex("a9adb3"), hex("8a8a90") }, Order = 102 },
	{ Key = "RookieKnife", Slot = "Knife", Name = "Training Kunai", Rarity = "Common", Price = 0, Unlock = "Quest: Collect 15 Aura stars (chapter 2)", Model = "03_Common_Training_Kunai", Studs = 2.44, Art = "KnifeRookieKnife", Colors = { hex("5d636b"), hex("5d636b") }, Order = 103 },
	{ Key = "FieldKnife", Slot = "Knife", Name = "Field Knife", Rarity = "Common", Price = 200, Model = "04_Common_Field_Knife", Studs = 2.57, Art = "KnifeFieldKnife", Colors = { hex("9aa0a6"), hex("444444") }, Order = 104 },
	{ Key = "PlainTanto", Slot = "Knife", Name = "Plain Tanto", Rarity = "Common", Price = 200, Model = "05_Common_Plain_Tanto", Studs = 2.57, Art = "KnifePlainTanto", Colors = { hex("b0b4ba"), hex("3a3a3a") }, Order = 105 },
	{ Key = "BoxCutter", Slot = "Knife", Name = "Box Cutter", Rarity = "Common", Price = 200, Model = "06_Common_Box_Cutter", Studs = 2.4, Art = "KnifeBoxCutter", Colors = { hex("c8ccd0"), hex("333333") }, Order = 106 },
	{ Key = "BoneKnife", Slot = "Knife", Name = "Bone Knife", Rarity = "Common", Price = 200, Model = "07_Common_Bone_Knife", Studs = 2.45, Art = "KnifeBoneKnife", Colors = { hex("e8dcc0"), hex("8a8a90") }, Order = 107 },
	{ Key = "ScoutDagger", Slot = "Knife", Name = "Scout Dagger", Rarity = "Common", Price = 200, Model = "08_Common_Scout_Dagger", Studs = 2.57, Art = "KnifeScoutDagger", Colors = { hex("9ca2a8"), hex("5a4a3a") }, Order = 108 },
	{ Key = "JadeKunai", Slot = "Knife", Name = "Jade Kunai", Rarity = "Uncommon", Price = 500, Model = "09_Uncommon_Jade_Kunai", Studs = 2.51, Art = "KnifeJadeKunai", Colors = { hex("4fa37a"), hex("c9a640") }, Order = 109 },
	{ Key = "CrimsonTanto", Slot = "Knife", Name = "Crimson Tanto", Rarity = "Uncommon", Price = 500, Model = "10_Uncommon_Crimson_Tanto", Studs = 2.68, Art = "KnifeCrimsonTanto", Colors = { hex("d8dade"), hex("b8231c") }, Order = 110 },
	{ Key = "SerratedFang", Slot = "Knife", Name = "Serrated Fang", Rarity = "Uncommon", Price = 500, Model = "11_Uncommon_Serrated_Fang", Studs = 2.64, Art = "KnifeSerratedFang", Colors = { hex("9aa6b0"), hex("2c3e50") }, Order = 111 },
	{ Key = "HunterKnife", Slot = "Knife", Name = "Hunter's Hook", Rarity = "Uncommon", Price = 0, Unlock = "Quest: Catch 10 runners (chapter 3)", Model = "12_Uncommon_Hunter_s_Hook", Studs = 2.56, Art = "KnifeHunterKnife", Colors = { hex("a0a6ad"), hex("5a3a1c") }, Order = 112 },
	{ Key = "NightTanto", Slot = "Knife", Name = "Night Tanto", Rarity = "Uncommon", Price = 500, Model = "13_Uncommon_Night_Tanto", Studs = 2.66, Art = "KnifeNightTanto", Colors = { hex("2b2f36"), hex("111111") }, Order = 113 },
	{ Key = "IceKnife", Slot = "Knife", Name = "Ice Shard", Rarity = "Uncommon", Price = 500, Glow = hex("a8d8f0"), Model = "14_Uncommon_Ice_Shard", Studs = 2.61, Art = "KnifeIceKnife", Colors = { hex("a8d8f0"), hex("a8d8f0") }, Order = 114 },
	{ Key = "CopperCleaver", Slot = "Knife", Name = "Copper Cleaver", Rarity = "Uncommon", Price = 500, Model = "15_Uncommon_Copper_Cleaver", Studs = 2.53, Art = "KnifeCopperCleaver", Colors = { hex("b87333"), hex("b87333") }, Order = 115 },
	{ Key = "SpiritKunai", Slot = "Knife", Name = "Spirit Kunai", Rarity = "Rare", Price = 1000, Glow = hex("4fd8ff"), Model = "16_Rare_Spirit_Kunai", Studs = 2.58, Art = "KnifeSpiritKunai", Colors = { hex("e8eef2"), hex("c9d4dc") }, Order = 116 },
	{ Key = "ThunderFang", Slot = "Knife", Name = "Thunder Fang", Rarity = "Rare", Price = 1000, Glow = hex("fff6a0"), Model = "17_Rare_Thunder_Fang", Studs = 2.72, Art = "KnifeThunderFang", Colors = { hex("f0d040"), hex("d4a020") }, Order = 117 },
	{ Key = "CandyKnife", Slot = "Knife", Name = "Sakura Blade", Rarity = "Rare", Price = 1000, Glow = hex("ff9ec4"), Model = "18_Rare_Sakura_Blade", Studs = 2.83, Art = "KnifeCandyKnife", Colors = { hex("f4f4f4"), hex("d4a020") }, Order = 118 },
	{ Key = "VenomKris", Slot = "Knife", Name = "Venom Kris", Rarity = "Rare", Price = 1000, Glow = hex("b6ff5a"), Model = "19_Rare_Venom_Kris", Studs = 2.74, Art = "KnifeVenomKris", Colors = { hex("3f7a22"), hex("d4a020") }, Order = 119 },
	{ Key = "FrostFang", Slot = "Knife", Name = "Frost Fang", Rarity = "Rare", Price = 1000, Glow = hex("7fd4ff"), Model = "20_Rare_Frost_Fang", Studs = 2.73, Art = "KnifeFrostFang", Colors = { hex("cfeaff"), hex("d4a020") }, Order = 120 },
	{ Key = "EmberEdge", Slot = "Knife", Name = "Ember Edge", Rarity = "Rare", Price = 1000, Glow = hex("ff6a1a"), Model = "21_Rare_Ember_Edge", Studs = 2.72, Art = "KnifeEmberEdge", Colors = { hex("2a2224"), hex("d4a020") }, Order = 121 },
	{ Key = "MoonlitKnife", Slot = "Knife", Name = "Hollow Moon", Rarity = "Epic", Price = 0, Unlock = "Quest: Win 10 games (chapter 4)", Glow = hex("9a4fff"), Model = "22_Epic_Hollow_Moon", Studs = 2.89, Art = "KnifeMoonlitKnife", Colors = { hex("1a1a22"), hex("d4a020") }, Order = 122 },
	{ Key = "ShadowKnife", Slot = "Knife", Name = "Shadow Cleaver", Rarity = "Epic", Price = 2000, Glow = hex("e8e8ff"), Model = "23_Epic_Shadow_Cleaver", Studs = 3.08, Art = "KnifeShadowKnife", Colors = { hex("141418"), hex("2a2a30") }, Order = 123 },
	{ Key = "StormKunai", Slot = "Knife", Name = "Storm Kunai", Rarity = "Epic", Price = 2000, Glow = hex("6ad0ff"), Model = "24_Epic_Storm_Kunai", Studs = 2.82, Art = "KnifeStormKunai", Colors = { hex("2a3a6a"), hex("6ad0ff") }, Order = 124 },
	{ Key = "BloodMoonTanto", Slot = "Knife", Name = "Blood Moon Tanto", Rarity = "Epic", Price = 2000, Glow = hex("ff2a3a"), Model = "25_Epic_Blood_Moon_Tanto", Studs = 2.98, Art = "KnifeBloodMoonTanto", Colors = { hex("e8e8e8"), hex("d4a020") }, Order = 125 },
	{ Key = "TwinFang", Slot = "Knife", Name = "Twin Fang", Rarity = "Epic", Price = 2000, Glow = hex("3affb0"), Model = "26_Epic_Twin_Fang", Studs = 2.83, Art = "KnifeTwinFang", Colors = { hex("3a3a4a"), hex("d4a020") }, Order = 126 },
	{ Key = "SolarReaper", Slot = "Knife", Name = "Solar Reaper", Rarity = "Legendary", Price = 4000, Glow = hex("ffb020"), Model = "27_Legendary_Solar_Reaper", Studs = 3.03, Art = "KnifeSolarReaper", Colors = { hex("fff2c0"), hex("d4a020") }, Order = 127 },
	{ Key = "VoidFang", Slot = "Knife", Name = "Void Fang", Rarity = "Legendary", Price = 4000, Glow = hex("c04fff"), Model = "28_Legendary_Void_Fang", Studs = 3.07, Art = "KnifeVoidFang", Colors = { hex("0e0a16"), hex("d4a020") }, Order = 128 },
	{ Key = "SpinKnife", Slot = "Knife", Name = "Celestial Edge", Rarity = "Legendary", Price = 0, NotForSale = true, Glow = hex("7fe8ff"), Model = "29_Legendary_Celestial_Edge", Studs = 3.21, Art = "KnifeSpinKnife", Colors = { hex("f8f8ff"), hex("d4a020") }, Order = 129 },
	{ Key = "AbyssEclipse", Slot = "Knife", Name = "Abyss Eclipse", Rarity = "Mythic", Price = 8000, Glow = hex("ff2a3a"), Model = "30_Mythic_Abyss_Eclipse", Studs = 3.3, Art = "KnifeAbyssEclipse", Colors = { hex("08080c"), hex("d4a020") }, Order = 130 },
	-- The 5 Game Pass knives (his design/knives/gamepass/Gamepass_Knives.glb, rarity "Exclusive": a tier above Mythic
	-- with Mythic's calm effects, Shared/KnifeLook). Each is its own Game Pass (owner Oct 18: "these are going to be the
	-- gamepasses users can buy"; Config/Products: Hunter Knife = Crimson Requiem, Moonlit = Hollow Eclipse, Sunrise =
	-- Celestial Seraph, Inferno = Dragon's Maw, Frost = Frostbound Oath), Order = his card order; the lobby stands show
	-- one each. Model = the file / node; baked like the 30 (tools/knives).
	{ Key = "CelestialSeraph", Slot = "Knife", Name = "Celestial Seraph", Rarity = "Exclusive", Price = 0, NotForSale = true, Pass = "SunriseKnifePass", Glow = hex("3ac0ff"), Model = "Gamepass_Knives/Celestial_Seraph", Studs = 3.18, Art = "KnifeCelestialSeraph", Colors = { hex("d4dde4"), hex("e8b830") }, Order = 133 },
	{ Key = "CrimsonRequiem", Slot = "Knife", Name = "Crimson Requiem", Rarity = "Exclusive", Price = 0, NotForSale = true, Pass = "HunterKnifePass", Glow = hex("ff3344"), Model = "Gamepass_Knives/Crimson_Requiem", Studs = 3.3, Art = "KnifeCrimsonRequiem", Colors = { hex("783b47"), hex("a8141f") }, Order = 131 },
	{ Key = "HollowEclipse", Slot = "Knife", Name = "Hollow Eclipse", Rarity = "Exclusive", Price = 0, NotForSale = true, Pass = "MoonlitKnifePass", Glow = hex("e4ecff"), Model = "Gamepass_Knives/Hollow_Eclipse", Studs = 3.3, Art = "KnifeHollowEclipse", Colors = { hex("27272f"), hex("2c2c34") }, Order = 132 },
	{ Key = "DragonsMaw", Slot = "Knife", Name = "Dragon's Maw", Rarity = "Exclusive", Price = 0, NotForSale = true, Pass = "InfernoKnifePass", Glow = hex("ff7a1a"), Model = "Gamepass_Knives/Dragons_Maw", Studs = 3.17, Art = "KnifeDragonsMaw", Colors = { hex("2a110d"), hex("2a110d") }, Order = 134 },
	{ Key = "FrostboundOath", Slot = "Knife", Name = "Frostbound Oath", Rarity = "Exclusive", Price = 0, NotForSale = true, Pass = "FrostKnifePass", Glow = hex("5ae6ff"), Model = "Gamepass_Knives/Frostbound_Oath", Studs = 3.21, Art = "KnifeFrostboundOath", Colors = { hex("aee6f9"), hex("d8dee8") }, Order = 135 },
} :: { Item }

local byKey: { [string]: Item } = {}
for _, item in CoinShop.Items do
	assert(not byKey[item.Key], "duplicate coin item " .. item.Key)
	byKey[item.Key] = item
end

function CoinShop.get(key: string): Item?
	return byKey[key]
end

-- The items a Game Pass gives (Pass = its Config/Products key), in shop order.
function CoinShop.passItems(passKey: string): { Item }
	local out = {}
	for _, item in CoinShop.Items do
		if item.Pass == passKey then table.insert(out, item) end
	end
	table.sort(out, function(a, b) return a.Order < b.Order end)
	return out
end

-- What to give a save for the passes it owns (owned: { [passKey] = true }, checked with Roblox by ShopService):
-- the keys it doesn't have yet. Pure, so the spec checks it.
function CoinShop.passGrants(cosmetics: { [string]: any }, owned: { [string]: boolean }): { string }
	local out = {}
	for _, item in CoinShop.Items do
		if item.Pass and owned[item.Pass] == true and not cosmetics[item.Key] then table.insert(out, item.Key) end
	end
	return out
end

-- A ColorSequence through the item's colours (for trails, name gradients and previews).
function CoinShop.sequence(item: Item): ColorSequence
	local keys = {}
	local n = #item.Colors
	for i, c in item.Colors do
		table.insert(keys, ColorSequenceKeypoint.new(if n == 1 then 0 else (i - 1) / (n - 1), c))
	end
	if n == 1 then table.insert(keys, ColorSequenceKeypoint.new(1, item.Colors[1])) end
	return ColorSequence.new(keys)
end

-- What's worn in a slot, from a save (or the client's copy of it): Wear[slot] when you own it, "" = taken off,
-- and nil = never chosen, so an owned Robux cosmetic for that slot (Config/Products) is worn.
function CoinShop.worn(data: { [string]: any }, slot: string): string?
	local owned = data.Cosmetics or {}
	local key = (data.Wear or {})[slot]
	if key == "" then return nil end
	if key ~= nil then return if owned[key] then key else nil end
	for _, p in Products.Cosmetics do
		if p.Slot == slot and owned[p.Key] then return p.Key end
	end
	return nil
end

return CoinShop
