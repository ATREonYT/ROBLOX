--!nonstrict
-- Every Robux item in the game, for the Store window (HoodClient/Store.client), the HUD's offer cards and power
-- buttons, the Rebirth window's Skip Rebirth and the server's StoreService.
--
-- WHAT THE OWNER SETS UP (create.roblox.com > your experience > Monetization):
--   * Passes: make one game pass per Passes key below and paste its id here.
--   * Developer Products: make one product per DeveloperProducts key below and paste its id here.
--   * Price: the Robux price the cards show until the live one loads (with an id, the client asks Roblox for the
--     real price, so a price changed on the website shows in game). Keep them in step anyway.
-- A card with id 0 still shows its price; tapping it says "Coming soon!" and nothing errors.
--
-- Wired = true only when the server really grants the item (HoodServer/StoreService: ownership attributes and
-- receipts) AND the game applies its effect. The client never prompts a purchase for an item that is not Wired, even
-- with an id: nobody can pay Robux for something that does nothing yet. Flip it when the effect ships.
-- (brief 23) RangeVIP1 / RangeVIP2 (the PRO BAY x100 and GOLD BAY x250 lanes: LobbyService opens and pays a Robux lane
-- only with its Pass_* attribute) and TenXCash (the magenta pad before each gate pays Shared/PadRules.reward(stage, true)
-- with Pass_TenXCash: StageService).
-- Wired now: DoubleRep, DoubleCash and VIP (Pass_* attributes; HoodServer/Boosts and the overhead tag apply them), the
-- Power and Cash packs, the timed boosts, the Boost Bundle and Block Party (StoreService; PowerBoost), SkipRebirth
-- (RebirthService). AutoShoot ("Auto Fight", brief 18: with Pass_AutoShoot your gun fires at stage goons on its own;
-- Waves.client). The Robux shoe boxes, one or a bundle of 3 or 8 (brief 21/22: StoreService opens them through
-- HoodServer/ShoeOpening, the same roll and unboxing as a Cash box; the dais prompt and the Store's 'Box' cards buy them).
-- The shoe passes (brief 22; ShoeOpening and ShoeService read the Pass_* attributes): ExtraEquip (+1 Shoe Slot, 4 pairs
-- on; ShoesMax tells the UI), Lucky (Cash boxes roll with ShoeRules.weights(boxId, true); every odds display shows the
-- owner ShoeRules.chances / chanceOf(..., true)) and TripleOpen (the dais's "Open x3" prompt: OpenShoeBox(boxId, 3), 3
-- at once for 3x the Price).
--
-- Honest prices (brief 22): a bundle's WasPrice is what its parts cost bought one by one (a box bundle: Count x the
-- single box's Price; the Boost Bundle: the sum of its parts' Price), so the struck-through number is a real price.
-- Nothing here is limited or timed: no "Limited Stock", no countdowns.
local Products = {}
Products.Enabled = true -- master switch: false = every card says "Coming soon!"
-- The Robux sign in text: U+E002, the character Roblox's own fonts draw as the Robux icon (written ⏣ in our docs; a
-- terminal prints it as nothing). World labels use it for prices: RebirthRules.laneLabel, PadRules.labels.
Products.RobuxMark = utf8.char(0xE002)

-- Game pass ids (0 = not created yet).
Products.Passes = {
	DoubleRep = 0, -- 2x Power on every shot (key kept from the first build)
	DoubleCash = 0, -- 2x Cash from the pads and goals
	AutoShoot = 0, -- (shown as "Auto Fight", brief 18) your gun fires at stage goons on its own
	VIP = 0, -- VIP tag + 1.5x Cash
	Lucky = 0, -- better odds for Epic and up in Cash shoe boxes
	TripleOpen = 0, -- open 3 Cash shoe boxes at once for 3x the Cash
	ExtraEquip = 0, -- +1 shoe pair on (4 instead of 3); replaces the old crew-slot pass
	-- (brief 23)
	TenXCash = 0, -- "10x Cash": the magenta pad before each gate pays 10x the yellow one (Shared/PadRules, StageService)
	RangeVIP1 = 0, -- "Pro Bay": the x100 Power lane, PRO BAY (Config/Skins.Stations Pass; LobbyService)
	RangeVIP2 = 0, -- "Gold Bay": the x250 Power lane, GOLD BAY
}
-- Developer product ids (0 = not created yet).
Products.DeveloperProducts = {
	PowerPack1 = 0, PowerPack2 = 0, PowerPack3 = 0, PowerPack4 = 0, -- +Power, sized from your next rebirth (Products.powerAmount)
	TinyCash = 0, SmallCash = 0, MediumCash = 0, LargeCash = 0, -- +Cash (Products.cashAmount)
	RepBoost2x = 0, RepBoost3x = 0, -- 15 minutes of 2x / 3x Power
	BoostBundle = 0, -- (brief 22) two 2x Power boosts + one 3x Power boost
	BlockParty = 0, -- x2 Power for everyone in the server, 15 minutes
	SkipRebirth = 0, -- rebirth now without the Power (the Rebirth window shows it only once this id is set)
	-- (brief 21) the Robux shoe boxes on World 1's dais: one roll from the box's own exclusive shoes (Config/Shoes);
	-- (brief 22) and the Store's Buy 3 / Buy 8 bundles of them
	ShoeBoxExclusive = 0, -- "Exclusive Box", 99 Robux
	ShoeBoxExclusive3 = 0, -- "3 Exclusive Boxes", 249 Robux
	ShoeBoxExclusive8 = 0, -- "8 Exclusive Boxes", 599 Robux
	ShoeBoxGrail = 0, -- "Grail Box", 199 Robux
	ShoeBoxGrail3 = 0, -- "3 Grail Boxes", 499 Robux
	ShoeBoxGrail8 = 0, -- "8 Grail Boxes", 1199 Robux
}
Products.BoostDurationSeconds = 900

-- The Store's cards, in order. Kind: 'Pass' | 'Product'. Section: the Store's sections (Products.Sections) or
-- 'Rebirth' (only in the Rebirth window). Art: what the card shows, always a flat PNG ('icon:<IconModels id>', 'gun:<Guns
-- id>' = Gun_<id>, 'box:<Shoes box id>' = Box_<id>, 'boxes:<id>' = three boxes, 'shoe:<Shoes id>' = Shoe_<id>; brief 24:
-- each gamepass has its own card art, ART2's DoublePower ... GoldBay). Tone: a UIKit tone. Title: the card's first
-- line (and the name notices use). Big: the card's big gold lines (the reference's "Golden / Zone"; \n splits them).
-- Offer: the short line on the HUD's offer card and pass button. Sticker: big text stuck on the art ('2x').
-- (brief 18: AutoShoot is shown as "Auto Fight", COMBAT's repurpose.)
-- brief 22 fields (UI3's Store reads them):
--   Box rows ('Box'): Box = the Shoes box id (one card per Box), Count = boxes it opens (1, 3, 8: the card's Buy 1 /
--     Buy 3 / Buy 8 buttons), WasPrice = Count x the Count-1 row's Price (nil on Count 1). The Count-1 row's Price is
--     the same number as its box's RobuxPrice in Config/Shoes.
--   Boost rows ('Boost'): Boost = the level a timed boost gives (2 = 2x Power) for BoostDurationSeconds. The bundle:
--     Bundle = the boost keys it grants (one entry per boost), Lines = its bullet lines, WasPrice = the sum of its
--     parts' Price, Wide = true (the wide card).
--   Cash rows: Cash = the amount. Power rows: Pack = the share of your next rebirth's Power (Products.powerAmount).
Products.Catalog = {
	-- ~Shoe Boxes~
	{ Key = 'ShoeBoxExclusive', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 1, Title = 'Exclusive Box', Detail = 'Exclusive shoes, no Commons', Price = 99, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxExclusive3', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 3, Title = 'Exclusive Box', Detail = '3 Exclusive Boxes', Price = 249, WasPrice = 297, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxExclusive8', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 8, Title = 'Exclusive Box', Detail = '8 Exclusive Boxes', Price = 599, WasPrice = 792, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxGrail', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 1, Title = 'Grail Box', Detail = 'The best exclusive shoes', Price = 199, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	{ Key = 'ShoeBoxGrail3', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 3, Title = 'Grail Box', Detail = '3 Grail Boxes', Price = 499, WasPrice = 597, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	{ Key = 'ShoeBoxGrail8', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 8, Title = 'Grail Box', Detail = '8 Grail Boxes', Price = 1199, WasPrice = 1592, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	-- ~Gamepass~
	{ Key = 'DoubleRep', Kind = 'Pass', Section = 'Gamepass', Title = '2x Power', Big = 'Every\nShot', Detail = 'Every shot pays double', Price = 199, Art = 'icon:DoublePower', Tone = 'cardGold', Offer = '2x Power', Sticker = '2x', Wired = true },
	{ Key = 'DoubleCash', Kind = 'Pass', Section = 'Gamepass', Title = '2x Cash', Big = 'Every\nStage', Detail = 'Double Cash from pads and goals', Price = 149, Art = 'icon:DoubleCash', Tone = 'cardPurple', Offer = '2x Cash', Sticker = '2x', Wired = true },
	{ Key = 'VIP', Kind = 'Pass', Section = 'Gamepass', Banner = true, Title = 'VIP', Big = 'VIP', Detail = 'GOLD TAG + 1.5x CASH', Price = 249, Art = 'icon:VIP', Tone = 'cardGreen', Wired = true },
	{ Key = 'AutoShoot', Kind = 'Pass', Section = 'Gamepass', Title = 'Auto Fight', Big = 'Hands\nFree', Detail = 'Fires at goons for you', Price = 99, Art = 'icon:AutoFight', Tone = 'cardRed', Offer = 'Auto Fight', Wired = true },
	{ Key = 'Lucky', Kind = 'Pass', Section = 'Gamepass', Title = 'Lucky', Big = 'Better\nBoxes', Detail = 'Better odds for Epic and up in Cash boxes', Price = 129, Art = 'icon:Lucky', Tone = 'cardTeal', Wired = true },
	{ Key = 'TripleOpen', Kind = 'Pass', Section = 'Gamepass', Title = 'Triple Open', Big = '3 Boxes\nat Once', Detail = 'Open 3 Cash boxes at once, for 3x the Cash', Price = 179, Art = 'icon:TripleOpen', Tone = 'cardBlue', Sticker = 'x3', Wired = true },
	{ Key = 'ExtraEquip', Kind = 'Pass', Section = 'Gamepass', Title = '+1 Shoe Slot', Big = '4 Pairs\nOn', Detail = 'Wear 4 pairs at once', Price = 99, Art = 'icon:ExtraEquip', Tone = 'cardPink', Sticker = '+1', Wired = true },
	-- (brief 23) the 10x Cash pad and the two Robux lanes. A lane row's Price is its station's RobuxPrice (Config/Skins).
	{ Key = 'TenXCash', Kind = 'Pass', Section = 'Gamepass', Title = '10x Cash', Big = '10x\nPads', Detail = 'The pink pad pays 10x Cash', Price = 199, Art = 'icon:TenXCash', Tone = 'cardPink', Offer = '10x Cash', Sticker = '10x', Wired = true },
	{ Key = 'RangeVIP1', Kind = 'Pass', Section = 'Gamepass', Title = 'Pro Bay', Big = 'x100\nPower', Detail = 'Your own x100 Power lane', Price = 99, Art = 'icon:ProBay', Tone = 'cardTeal', Offer = 'x100 Lane', Sticker = 'x100', Wired = true },
	{ Key = 'RangeVIP2', Kind = 'Pass', Section = 'Gamepass', Title = 'Gold Bay', Big = 'x250\nPower', Detail = 'The best lane: x250 Power', Price = 249, Art = 'icon:GoldBay', Tone = 'cardGold', Offer = 'x250 Lane', Sticker = 'x250', Wired = true },
	-- ~Boosts~ (two 2x + one 3x bought one by one: 39 + 39 + 69 = 147)
	{ Key = 'BoostBundle', Kind = 'Product', Section = 'Boost', Wide = true, Title = 'Boost Bundle', Detail = '45 minutes of boosts', Bundle = { 'RepBoost2x', 'RepBoost2x', 'RepBoost3x' }, Lines = { '- Two 2x Power Boosts', '- One 3x Power Boost' }, Price = 119, WasPrice = 147, Art = 'icon:BoostBundle', Tone = 'rainbow', Wired = true },
	{ Key = 'RepBoost2x', Kind = 'Product', Section = 'Boost', Title = '2x Power', Detail = '15 minutes', Boost = 2, Price = 39, Art = 'icon:PotionRed', Tone = 'cardRed', Wired = true },
	{ Key = 'RepBoost3x', Kind = 'Product', Section = 'Boost', Title = '3x Power', Detail = '15 minutes', Boost = 3, Price = 69, Art = 'icon:PotionGold', Tone = 'cardGold', Wired = true },
	{ Key = 'BlockParty', Kind = 'Product', Section = 'Boost', Title = 'Block Party', Detail = 'x2 Power for the whole server, 15 min', Price = 149, Art = 'icon:BlockParty', Tone = 'cardPurple', Wired = true },
	-- ~Cash Packs~ (Cash per Robux: 26, 29, 31, 34)
	{ Key = 'TinyCash', Kind = 'Product', Section = 'Cash', Title = 'Tiny Pack', Price = 19, Art = 'icon:CashTiny', Tone = 'cardGold', Cash = 500, Wired = true },
	{ Key = 'SmallCash', Kind = 'Product', Section = 'Cash', Title = 'Small Pack', Price = 49, Art = 'icon:CashSmall', Tone = 'cardGold', Cash = 1400, Wired = true },
	{ Key = 'MediumCash', Kind = 'Product', Section = 'Cash', Title = 'Medium Pack', Price = 129, Art = 'icon:CashMedium', Tone = 'cardGold', Cash = 4000, Wired = true },
	{ Key = 'LargeCash', Kind = 'Product', Section = 'Cash', Title = 'Large Pack', Price = 399, Art = 'icon:CashLarge', Tone = 'cardGold', Cash = 13500, Wired = true },
	-- ~Power Packs~ (share of the next rebirth per 100 Robux: 0.53, 0.61, 0.70, 0.75)
	{ Key = 'PowerPack1', Kind = 'Product', Section = 'Power', Title = 'Tiny Pack', Price = 19, Art = 'icon:PowerTiny', Tone = 'cardGold', Pack = 0.1, Wired = true },
	{ Key = 'PowerPack2', Kind = 'Product', Section = 'Power', Title = 'Small Pack', Price = 49, Art = 'icon:PowerSmall', Tone = 'cardGold', Pack = 0.3, Wired = true },
	{ Key = 'PowerPack3', Kind = 'Product', Section = 'Power', Title = 'Medium Pack', Price = 129, Art = 'icon:PowerMedium', Tone = 'cardGold', Pack = 0.9, Wired = true },
	{ Key = 'PowerPack4', Kind = 'Product', Section = 'Power', Title = 'Large Pack', Price = 399, Art = 'icon:PowerLarge', Tone = 'cardGold', Pack = 3, Wired = true },
	-- (the Rebirth window)
	{ Key = 'SkipRebirth', Kind = 'Product', Section = 'Rebirth', Title = 'Skip Rebirth', Detail = 'Rebirth now', Price = 99, Art = 'icon:Rebirth', Tone = 'aqua', Wired = true },
}
Products.ByKey = {}
for i, entry in Products.Catalog do
	entry.Order = i
	Products.ByKey[entry.Key] = entry
end
-- The Store's sections, top to bottom (brief 22, the reference's order).
Products.Sections = {
	{ Id = 'Box', Title = '~Shoe Boxes~' },
	{ Id = 'Gamepass', Title = '~Gamepass~' },
	{ Id = 'Boost', Title = '~Boosts~' },
	{ Id = 'Cash', Title = '~Cash Packs~' },
	{ Id = 'Power', Title = '~Power Packs~' },
}

-- The id for a catalog key (0 when unknown or not set yet).
function Products.idOf(key)
	local entry = Products.ByKey[key]
	if not entry then return 0 end
	local ids = entry.Kind == 'Pass' and Products.Passes or Products.DeveloperProducts
	local id = ids[key]
	return (type(id) == 'number' and id > 0 and id % 1 == 0) and id or 0
end

-- Whether the client may prompt this purchase now: true, or false and why ('unknown', 'off', 'noid', 'unwired').
function Products.canBuy(key)
	local entry = Products.ByKey[key]
	if not entry then return false, 'unknown' end
	if not Products.Enabled then return false, 'off' end
	if Products.idOf(key) == 0 then return false, 'noid' end
	if entry.Wired ~= true then return false, 'unwired' end
	return true
end

-- The catalog key for a purchased id ('Pass' or 'Product'), or nil.
function Products.keyFor(kind, id)
	if type(id) ~= 'number' or id <= 0 then return nil end
	for _, entry in Products.Catalog do
		if entry.Kind == kind and Products.idOf(entry.Key) == id then return entry.Key end
	end
	return nil
end

-- Round to two significant figures (12345 -> 12000), at least `floor`.
local function nice(n, floor)
	n = math.max(floor or 1, n)
	local p = 10 ^ math.max(0, math.floor(math.log10(n)) - 1)
	return math.floor(n / p + 0.5) * p
end

-- Power a pack gives: its Pack fraction of the Power your next rebirth needs (so a pack stays worth the same
-- at every stage of the game), rounded to two figures, at least 100. Client (the label) and server (the grant)
-- both call this with the same `need`.
function Products.powerAmount(key, need)
	local entry = Products.ByKey[key]
	if not entry or type(entry.Pack) ~= 'number' then return 0 end
	if type(need) ~= 'number' or need ~= need or need <= 0 then need = 1000 end
	return nice(need * entry.Pack, 100)
end

-- Cash a cash pack gives.
function Products.cashAmount(key)
	local entry = Products.ByKey[key]
	return entry and type(entry.Cash) == 'number' and entry.Cash or 0
end

-- The timed boosts a product grants, one entry per boost: { level, ... } (a boost row: its one level; the Boost
-- Bundle: its parts' levels, in order). Each runs Products.BoostDurationSeconds. Empty for anything else.
function Products.boostLevels(key)
	local entry = Products.ByKey[key]
	local levels = {}
	if not entry then return levels end
	if type(entry.Bundle) == 'table' then
		for _, part in entry.Bundle do
			local p = Products.ByKey[part]
			if p and type(p.Boost) == 'number' then table.insert(levels, p.Boost) end
		end
	elseif type(entry.Boost) == 'number' then
		table.insert(levels, entry.Boost)
	end
	return levels
end

-- The shoe box a product opens and how many: boxId, count (nil, 0 for anything else).
function Products.boxOpen(key)
	local entry = Products.ByKey[key]
	if not entry or entry.Section ~= 'Box' or type(entry.Box) ~= 'string' then return nil, 0 end
	return entry.Box, type(entry.Count) == 'number' and entry.Count or 1
end

return Products
