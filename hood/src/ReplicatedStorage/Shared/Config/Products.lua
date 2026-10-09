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
-- Wired now: DoubleRep, DoubleCash and VIP (Pass_* attributes; HoodServer/Boosts and the overhead tag apply them), the
-- Power and Cash packs, the timed boosts and Block Party (StoreService; PowerBoost), SkipRebirth (RebirthService).
-- Not yet: AutoShoot, Lucky, TripleOpen, ExtraEquip (their cards say "Coming soon!" until someone builds the effect).
local Products = {}
Products.Enabled = true -- master switch: false = every card says "Coming soon!"

-- Game pass ids (0 = not created yet).
Products.Passes = {
	DoubleRep = 0, -- 2x Power on every shot (key kept from the first build)
	DoubleCash = 0, -- 2x Cash from gates, waves and goals
	AutoShoot = 0, -- shoots for you while you stand in a range
	VIP = 0, -- VIP tag + 1.5x Cash
	Lucky = 0, -- luckier shoe boxes
	TripleOpen = 0, -- open 3 shoe boxes at once
	ExtraEquip = 0, -- +1 shoe pair on (4 instead of 3); replaces the old crew-slot pass
}
-- Developer product ids (0 = not created yet).
Products.DeveloperProducts = {
	PowerPack1 = 0, PowerPack2 = 0, PowerPack3 = 0, -- +Power, sized from your next rebirth (Products.powerAmount)
	SmallCash = 0, MediumCash = 0, LargeCash = 0, -- +Cash (Products.cashAmount)
	RepBoost2x = 0, RepBoost3x = 0, -- 15 minutes of x2 / x3 Power
	BlockParty = 0, -- x2 Power for everyone in the server, 15 minutes
	SkipRebirth = 0, -- rebirth now without the Power (the Rebirth window shows it only once this id is set)
}
Products.BoostDurationSeconds = 900

-- The Store's cards, in order. Kind: 'Pass' | 'Product'. Section: 'Gamepass' (big cards; Banner = the wide one),
-- 'Power', 'Cash', 'Boost' (small cards), 'Rebirth' (only in the Rebirth window). Art: what the card shows
-- ('icon:<IconModels id>', 'gun:<Guns id>', 'box:<Shoes box id>', 'boxes:<id>' = three boxes, 'shoe:<Shoes id>').
-- Tone: a UIKit tone. Big: the card's big second line. Offer: the short line on the HUD's offer card. Sticker:
-- big text stuck on the art ('2x').
Products.Catalog = {
	{ Key = 'DoubleRep', Kind = 'Pass', Section = 'Gamepass', Title = '2x Power', Big = 'Forever', Detail = 'Every shot pays double', Price = 199, Art = 'icon:Power', Tone = 'orange', Offer = '2x Power', Sticker = '2x', Wired = true },
	{ Key = 'DoubleCash', Kind = 'Pass', Section = 'Gamepass', Title = '2x Cash', Big = 'Forever', Detail = 'Double Cash from gates, waves and goals', Price = 149, Art = 'icon:Cash', Tone = 'green', Offer = '2x Cash', Sticker = '2x', Wired = true },
	{ Key = 'VIP', Kind = 'Pass', Section = 'Gamepass', Banner = true, Title = 'VIP', Big = 'VIP', Detail = 'Gold name tag + 1.5x Cash', Price = 249, Art = 'icon:Trophy', Tone = 'purple', Wired = true },
	{ Key = 'AutoShoot', Kind = 'Pass', Section = 'Gamepass', Title = 'Auto Shoot', Big = 'Hands free', Detail = 'Shoots for you in any range', Price = 99, Art = 'gun:Uzi', Tone = 'red', Offer = 'Auto Shoot', Wired = false },
	{ Key = 'Lucky', Kind = 'Pass', Section = 'Gamepass', Title = 'Lucky', Big = 'Boxes', Detail = 'Better odds in every shoe box', Price = 129, Art = 'box:Galaxy', Tone = 'teal', Wired = false },
	{ Key = 'TripleOpen', Kind = 'Pass', Section = 'Gamepass', Title = 'Triple Open', Big = 'x3 Boxes', Detail = 'Open 3 shoe boxes at once', Price = 179, Art = 'boxes:Street', Tone = 'blue', Sticker = 'x3', Wired = false },
	{ Key = 'ExtraEquip', Kind = 'Pass', Section = 'Gamepass', Title = '+1 Shoe Slot', Big = '4 Pairs On', Detail = 'Wear 4 pairs at once', Price = 99, Art = 'shoe:Comet', Tone = 'pink', Sticker = '+1', Wired = false },
	{ Key = 'PowerPack1', Kind = 'Product', Section = 'Power', Title = 'Power Pack', Price = 19, Art = 'icon:Power', Tone = 'yellow', Pack = 0.1, Wired = true },
	{ Key = 'PowerPack2', Kind = 'Product', Section = 'Power', Title = 'Power Crate', Price = 69, Art = 'icon:Power', Tone = 'red', Pack = 0.5, Wired = true },
	{ Key = 'PowerPack3', Kind = 'Product', Section = 'Power', Title = 'Power Truck', Price = 199, Art = 'icon:Power', Tone = 'purple', Pack = 2.5, Wired = true },
	{ Key = 'SmallCash', Kind = 'Product', Section = 'Cash', Title = 'Cash Stack', Price = 29, Art = 'icon:Cash', Tone = 'green', Cash = 1000, Wired = true },
	{ Key = 'MediumCash', Kind = 'Product', Section = 'Cash', Title = 'Cash Bag', Price = 129, Art = 'icon:Cash', Tone = 'teal', Cash = 6000, Wired = true },
	{ Key = 'LargeCash', Kind = 'Product', Section = 'Cash', Title = 'Cash Van', Price = 399, Art = 'icon:Cash', Tone = 'blue', Cash = 25000, Wired = true },
	{ Key = 'RepBoost2x', Kind = 'Product', Section = 'Boost', Title = 'x2 Power', Detail = '15 minutes', Price = 39, Art = 'icon:Evolve', Tone = 'orange', Sticker = 'x2', Wired = true },
	{ Key = 'RepBoost3x', Kind = 'Product', Section = 'Boost', Title = 'x3 Power', Detail = '15 minutes', Price = 69, Art = 'icon:Evolve', Tone = 'red', Sticker = 'x3', Wired = true },
	{ Key = 'BlockParty', Kind = 'Product', Section = 'Boost', Title = 'Block Party', Detail = 'x2 Power for the whole server, 15 min', Price = 149, Art = 'icon:Rewards', Tone = 'purple', Wired = true },
	{ Key = 'SkipRebirth', Kind = 'Product', Section = 'Rebirth', Title = 'Skip Rebirth', Detail = 'Rebirth now', Price = 99, Art = 'icon:Rebirth', Tone = 'blue', Wired = true },
}
Products.ByKey = {}
for i, entry in Products.Catalog do
	entry.Order = i
	Products.ByKey[entry.Key] = entry
end
Products.Sections = {
	{ Id = 'Gamepass', Title = '~Gamepasses~' },
	{ Id = 'Power', Title = '~Power Packs~' },
	{ Id = 'Cash', Title = '~Cash~' },
	{ Id = 'Boost', Title = '~Boosts~' },
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

return Products
