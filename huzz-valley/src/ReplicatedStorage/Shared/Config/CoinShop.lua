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
]]
export type Earn = { Rarity: string?, Stat: string?, Count: number?, Girls: number? }
export type Item = { Key: string, Slot: "Trail" | "Tag" | "Knife" | "Aura" | "Title", Name: string, Price: number, Colors: { Color3 }, Rainbow: boolean?, Order: number, NotForSale: boolean?, Unlock: string?, Earn: Earn?, Rarity: string? }

local Products = require(script.Parent.Products)

local rgb = Color3.fromRGB
local CoinShop = {}

CoinShop.Slots = { "Trail", "Tag", "Knife", "Aura", "Title", "Pose", "Outfit" }
CoinShop.SlotNames = { Trail = "TRAIL", Tag = "NAME COLOUR", Knife = "KNIFE", Aura = "AURA", Title = "TITLE", Pose = "POSE", Outfit = "OUTFIT" }

local LEGEND, MYTHIC = rgb(255, 190, 60), rgb(255, 84, 120)
local SECRET = { rgb(150, 110, 255), rgb(255, 90, 200), rgb(90, 220, 255) }

CoinShop.Items = {
	-- Trails
	{ Key = "MintTrail", Slot = "Trail", Name = "Mint Trail", Price = 400, Colors = { rgb(140, 255, 210), rgb(60, 200, 160) }, Order = 1 },
	{ Key = "OceanTrail", Slot = "Trail", Name = "Ocean Trail", Price = 750, Colors = { rgb(120, 220, 255), rgb(40, 110, 255) }, Order = 2 },
	{ Key = "CandyTrail", Slot = "Trail", Name = "Candy Trail", Price = 1000, Colors = { rgb(255, 150, 210), rgb(170, 120, 255) }, Order = 3 },
	{ Key = "GalaxyTrail", Slot = "Trail", Name = "Galaxy Trail", Price = 2500, Colors = { rgb(120, 90, 255), rgb(255, 90, 200), rgb(90, 220, 255) }, Rainbow = true, Order = 4 },
	-- Name colours
	{ Key = "TagPink", Slot = "Tag", Name = "Pink Name", Price = 300, Colors = { rgb(255, 130, 200), rgb(255, 130, 200) }, Order = 5 },
	{ Key = "TagSky", Slot = "Tag", Name = "Sky Name", Price = 300, Colors = { rgb(110, 210, 255), rgb(110, 210, 255) }, Order = 6 },
	{ Key = "TagLime", Slot = "Tag", Name = "Lime Name", Price = 300, Colors = { rgb(150, 245, 110), rgb(150, 245, 110) }, Order = 7 },
	{ Key = "TagRainbow", Slot = "Tag", Name = "Rainbow Name", Price = 1500, Colors = { rgb(255, 110, 110), rgb(255, 220, 90), rgb(110, 240, 140), rgb(110, 180, 255), rgb(200, 120, 255) }, Rainbow = true, Order = 8 },
	-- Knives (catchers)
	{ Key = "IceKnife", Slot = "Knife", Name = "Ice Knife", Price = 800, Colors = { rgb(170, 230, 255), rgb(60, 160, 255) }, Order = 9 },
	{ Key = "CandyKnife", Slot = "Knife", Name = "Candy Knife", Price = 800, Colors = { rgb(255, 160, 215), rgb(255, 90, 170) }, Order = 10 },
	{ Key = "ShadowKnife", Slot = "Knife", Name = "Shadow Knife", Price = 1500, Colors = { rgb(40, 34, 60), rgb(170, 90, 255) }, Order = 11 },
	-- Quest knives: earned in the lore quests (Config/Progression), never sold. Unlock says where they come from.
	{ Key = "RookieKnife", Slot = "Knife", Name = "Rookie Knife", Price = 0, Unlock = "Quest: Collect 15 Aura stars (chapter 2)", Colors = { rgb(255, 230, 140), rgb(255, 170, 60) }, Order = 12 },
	{ Key = "HunterKnife", Slot = "Knife", Name = "Hunter Knife", Price = 0, Unlock = "Quest: Catch 10 runners (chapter 3)", Colors = { rgb(255, 120, 110), rgb(150, 20, 40) }, Order = 13 },
	{ Key = "MoonlitKnife", Slot = "Knife", Name = "Moonlit Knife", Price = 0, Unlock = "Quest: Win 10 games (chapter 4)", Colors = { rgb(220, 235, 255), rgb(120, 140, 255), rgb(200, 120, 255) }, Rainbow = true, Order = 14 },
	{ Key = "SpinKnife", Slot = "Knife", Name = "Spin Knife", Price = 0, NotForSale = true, Colors = { rgb(255, 80, 180), rgb(130, 90, 255), rgb(80, 220, 255) }, Rainbow = true, Order = 15 }, -- (Spin the Wheel only)
	-- Rewards from the girls you get (rarest first, so they lead the ITEMS tab) and from playing well.
	{ Key = "TitleSecret", Slot = "Title", Name = "Keeper of Secrets", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = -30 },
	{ Key = "AuraSecret", Slot = "Aura", Name = "Void Halo", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = -29 },
	{ Key = "TrailSecret", Slot = "Trail", Name = "Secret Comet", Price = 0, Rarity = "Secret", Earn = { Rarity = "Secret" }, Unlock = "Get a Secret girl", Colors = SECRET, Rainbow = true, Order = -28 },
	{ Key = "TitleMythic", Slot = "Title", Name = "Mythic Charmer", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { MYTHIC, rgb(255, 170, 200) }, Order = -27 },
	{ Key = "AuraMythic", Slot = "Aura", Name = "Mythic Blaze", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { rgb(255, 150, 190), MYTHIC, rgb(150, 20, 70) }, Order = -26 },
	{ Key = "TrailMythic", Slot = "Trail", Name = "Mythic Streak", Price = 0, Rarity = "Mythic", Earn = { Rarity = "Mythic" }, Unlock = "Get a Mythic girl", Colors = { rgb(255, 200, 220), MYTHIC, rgb(150, 20, 70) }, Order = -25 },
	{ Key = "TitleLegend", Slot = "Title", Name = "Legend Hunter", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { LEGEND, rgb(255, 240, 190) }, Order = -24 },
	{ Key = "AuraLegend", Slot = "Aura", Name = "Legend Glow", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { rgb(255, 245, 200), LEGEND, rgb(255, 130, 40) }, Order = -23 },
	{ Key = "TrailLegend", Slot = "Trail", Name = "Legend Streak", Price = 0, Rarity = "Legendary", Earn = { Rarity = "Legendary" }, Unlock = "Get a Legendary girl", Colors = { rgb(255, 250, 220), LEGEND, rgb(255, 130, 40) }, Order = -22 },
	{ Key = "TitleCollector", Slot = "Title", Name = "Girl Collector", Price = 0, Earn = { Girls = 10 }, Unlock = "Own 10 girls", Colors = { rgb(255, 150, 210), rgb(255, 150, 210) }, Order = -21 },
	{ Key = "TitleHero", Slot = "Title", Name = "Huss Hero", Price = 0, Earn = { Stat = "Heroes", Count = 10 }, Unlock = "Make 10 hero runs", Colors = { rgb(91, 224, 122), rgb(91, 224, 122) }, Order = -20 },
	{ Key = "TitleGuardian", Slot = "Title", Name = "Guardian", Price = 0, Earn = { Stat = "Rescues", Count = 25 }, Unlock = "Save 25 friends", Colors = { rgb(110, 210, 255), rgb(110, 210, 255) }, Order = -19 },
} :: { Item }

local byKey: { [string]: Item } = {}
for _, item in CoinShop.Items do
	assert(not byKey[item.Key], "duplicate coin item " .. item.Key)
	byKey[item.Key] = item
end

function CoinShop.get(key: string): Item?
	return byKey[key]
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
