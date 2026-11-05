-- Sample content for FolkStudUI. Names, prices and art are placeholders. Any section can be left out, and its side tab goes with it.
-- local cfg = sampleShop(M); M.shop(game.StarterGui, cfg)
local function sampleShop(M)
	local c, a = M.COLOR, M.ART
	local mix = { { chance = "8%" }, { chance = "30%" }, { chance = "14%" }, { chance = "6%" }, { chance = "2%" } }
	local sword = { id = a.sword.id, rot = 0 }
	return {
		title = "Shop", icon = a.star,
		featured = { title = "THUNDER CRATE", tag = "NEW!", timer = { "ENDS IN", "1D 09H" }, hero = a.star,
			odds = { { rarity = "Rare", chance = "50%", art = sword }, { rarity = "Epic", chance = "30%", art = sword }, { rarity = "Legendary", chance = "15%", art = sword }, { rarity = "Mythic", chance = "4%", art = sword }, { rarity = "Divine", chance = "1%", art = sword } },
			goal = { "BONUS ITEM IN 50 CRATES", "0/50" },
			deals = { { id = "crate50", price = "2,999", sub = "50 CRATES", off = "-29%", best = true }, { id = "crate10", price = "749", sub = "10 CRATES", off = "-14%" }, { id = "crate3", price = "249", sub = "3 CRATES", off = "-6%" }, { id = "crate1", price = "99", sub = "1 CRATE" } } },
		crates = { { id = "rare", rank = "RARE", name = "Mystery Crate", color = c.blue, art = a.star, price = "149", contents = mix }, { id = "exclusive", rank = "EXCLUSIVE", name = "Mystery Crate", color = c.crimson, art = a.star, price = "349", contents = mix }, { id = "eternal", rank = "ETERNAL", name = "Mystery Crate", color = c.gold, art = a.star, price = "799", contents = mix } },
		bundle = { id = "starter", title = "STARTER PACK [OP]", limited = "LIMITED OFFER!", old = "449", price = "249", show = { a.sword, a.star, a.star },
			lines = { { "- STORM SABER [MYTHIC]", M.RARITY.Mythic }, { "- 500 GEMS [BONUS]", M.RARITY.Divine }, { "- LUCKY CHARM [LEGENDARY]", M.RARITY.Legendary } } },
		passes = { { id = "vip", title = "V.I.P", desc = "Safe zones and a\nV.I.P chat tag!", tag = "OP!", color = c.amber, art = a.star, price = "160" }, { id = "money2", title = "x2 Money", desc = "Every sale pays\ndouble, forever!", tag = "HOT!", color = c.green, art = a.star, price = "99" } },
	}
end
local function sampleRebirth()
	return { from = "Rebirth 0", to = "Rebirth 1", gainFrom = "x1 Money", gainTo = "x1.5 Money", warn = "Rebirthing resets your Strength to 0!", barText = "8/1K Strength", barFrac = 0.008, skip = "Skip Rebirth", skipSub = "KEEP STRENGTH!" }
end
local function sampleHud(M)
	return { buttons = { { label = "Shop", icon = M.ART.shop, color = M.COLOR.hudShop, opens = "FolkShop", tag = "NEW!" }, { label = "Quests", icon = M.ART.quest, color = M.COLOR.hudPurple, opens = "FolkQuests" }, { label = "Rebirth", icon = M.ART.rebirth, color = M.COLOR.hudBlue, opens = "FolkRebirth" }, { label = "Backpack", icon = M.ART.star, color = M.COLOR.green, opens = "FolkBackpack" }, { label = "Index", icon = M.ART.star, color = M.COLOR.pink, opens = "FolkIndex" }, { label = "Settings", icon = M.ART.star, color = M.COLOR.crimson, opens = "FolkSettings" } } }
end
local function sampleQuests(M)
	local c, a = M.COLOR, M.ART
	return { sections = {
		{ name = "Daily", timer = "RESETS IN 4H 12M", icon = a.star, color = c.green, quests = {
			{ id = "defeat", title = "Defeat 10 Enemies", desc = "Win fights on any island", have = 10, need = 10, reward = "+500", color = c.crimson, icon = a.sword },
			{ id = "roll", title = "Roll 5 Times", desc = "Try your luck at the dice", have = 3, need = 5, reward = "+250", color = c.blue, icon = a.star },
			{ id = "boss", title = "Beat a Boss", desc = "Any boss counts", have = 0, need = 1, reward = "+1K", color = c.pink, icon = a.star },
		} },
		{ name = "Weekly", timer = "RESETS IN 3D 09H", icon = a.sword, color = c.blue, quests = {
			{ id = "defeat500", title = "Defeat 500 Enemies", desc = "A long hunt", have = 120, need = 500, reward = "+5K", color = c.gold, icon = a.sword },
			{ id = "rebirth1", title = "Rebirth Once", desc = "Start over, stronger", have = 0, need = 1, reward = "+2K", color = c.green, icon = a.rebirth },
		} },
	} }
end
local function sampleBackpack(M)
	local c, a = M.COLOR, M.ART
	local long = { id = a.sword.id, rot = 0, scale = 1.2 }
	return { slots = "6/40 ITEMS", sections = {
		{ name = "Weapons", color = c.green, icon = a.sword, items = {
			{ id = "storm", name = "Storm Saber", rarity = "Divine", art = long, desc = "Crackles with every swing", stats = { { "DAMAGE", "1,250" }, { "SPEED", "1.8" } }, equipped = true },
			{ id = "ember", name = "Ember Edge", rarity = "Mythic", art = long, desc = "Leaves a trail of fire", stats = { { "DAMAGE", "840" }, { "SPEED", "1.5" } } },
			{ id = "gale", name = "Gale Blade", rarity = "Legendary", art = long, desc = "Light as the wind", stats = { { "DAMAGE", "520" }, { "SPEED", "2.1" } } },
			{ id = "iron", name = "Iron Edge", rarity = "Rare", art = long, desc = "Old, sharp and trusted", stats = { { "DAMAGE", "120" }, { "SPEED", "1.2" } } },
		} },
		{ name = "Items", color = c.orange, icon = a.star, items = {
			{ id = "chest", name = "Lucky Chest", rarity = "Epic", art = a.star, desc = "Holds a random blade", use = "OPEN", stats = { { "ROLLS", "3" }, { "LUCK", "x2" } } },
			{ id = "coins", name = "Coin Stack", rarity = "Common", art = a.star, desc = "Spend it right away", use = "USE", stats = { { "COINS", "+500" } } },
		} },
	} }
end
local function sampleIndex(M)
	local c, a = M.COLOR, M.ART
	local long = { id = a.sword.id, rot = 0, scale = 1.2 }
	return { claim = "CLAIM ALL! (1)", sections = {
		{ name = "Meadow", color = c.green, icon = a.sword, reward = "+500", rewardArt = a.star, items = {
			{ id = "m1", name = "Tin Blade", rarity = "Common", art = long, found = true, stats = { { "CHANCE", "40%" }, { "DAMAGE", "40" } } },
			{ id = "m2", name = "Iron Edge", rarity = "Rare", art = long, found = true, stats = { { "CHANCE", "15%" }, { "DAMAGE", "120" } } },
			{ id = "m3", name = "Frost Fang", rarity = "Epic", art = long, stats = { { "CHANCE", "4%" }, { "DAMAGE", "310" } } },
			{ id = "m4", name = "Gale Blade", rarity = "Legendary", art = long, stats = { { "CHANCE", "1%" }, { "DAMAGE", "520" } } },
		} },
		{ name = "Volcano", color = c.crimson, icon = a.star, reward = "CHEST", rewardArt = a.star, items = {
			{ id = "v1", name = "Ember Edge", rarity = "Mythic", art = long, stats = { { "CHANCE", "0.5%" }, { "DAMAGE", "840" } } },
			{ id = "v2", name = "Storm Saber", rarity = "Divine", art = long, stats = { { "CHANCE", "0.1%" }, { "DAMAGE", "1,250" } } },
		} },
	} }
end
local function sampleSettings(M)
	local c, a = M.COLOR, M.ART
	return { sections = {
		{ name = "Audio", color = c.green, icon = a.star, rows = {
			{ id = "music", kind = "slider", title = "Music", desc = "Background tracks", value = 70, color = c.blue },
			{ id = "sfx", kind = "slider", title = "Sound", desc = "Hits, clicks and rewards", value = 100, color = c.pink },
		} },
		{ name = "Gameplay", color = c.blue, icon = a.sword, rows = {
			{ id = "numbers", title = "Damage Numbers", desc = "Show numbers on hits", value = true, color = c.crimson, icon = a.sword },
			{ id = "low", title = "Low Detail", desc = "Runs better on old devices", value = false, color = c.green },
			{ id = "tutorial", kind = "button", title = "Replay Tutorial", desc = "Start the guide again", label = "REPLAY", color = c.gold },
		} },
	} }
end
return { shop = sampleShop, rebirth = sampleRebirth, hud = sampleHud, quests = sampleQuests, backpack = sampleBackpack, index = sampleIndex, settings = sampleSettings }
