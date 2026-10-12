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
-- (brief 23) RangeVIP1 / RangeVIP2 (the PRO BAY x100 and GOLD BAY x250 lanes; brief 30: RangeVIP3, the HEAD LANE x500
-- at the aisle's end: LobbyService opens and pays a Robux lane
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
-- Nothing here is limited or timed: no "Limited Stock", no made-up countdowns. (Brief 30: the one timer in the Store is the
-- weekly Featured pack's, and it is real: Products.featuredAt rotates it by the clock for everyone.)
local Balance = require(script.Parent.Balance)
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
	RangeVIP3 = 0, -- (brief 30) "Head Lane": the x500 Power lane that closes the training aisle, on its raised gold platform
	-- (brief 29, P5) the friction-removers
	AutoOpen = 0, -- "Auto Open": the box's T card opens box after box by itself (Shoes.client; free to stop any time)
	Speed2x = 0, -- "2x Speed": walk speed x Products.SpeedPassFactor (2), LobbyService.walk
	AutoCollect = 0, -- "Auto Collect": a street's pad Cash pays the moment its crew is down (StageService), no walk to the pad
}
-- Developer product ids (0 = not created yet).
Products.DeveloperProducts = {
	PowerPack1 = 0, PowerPack2 = 0, PowerPack3 = 0, PowerPack4 = 0, -- +Power, sized from your next rebirth (Products.powerAmount)
	PowerPackBig = 0, PowerPackMega = 0, -- (brief 30, round 2) Big 249 between Medium and Large, MEGA 999 on top
	TinyCash = 0, SmallCash = 0, MediumCash = 0, LargeCash = 0, -- +Cash (Products.cashAmount)
	BigCash = 0, MegaCash = 0, -- (brief 30, round 2) the 5th and 6th Cash Packs: Big 249 between Medium and Large, MEGA 999 on top
	RepBoost2x = 0, RepBoost3x = 0, -- 15 minutes of 2x / 3x Power
	BoostBundle = 0, -- (brief 22) two 2x Power boosts + one 3x Power boost
	BlockParty = 0, -- x2 Power for everyone in the server, 15 minutes
	SkipRebirth = 0, -- rebirth now without the Power (the Rebirth window shows it only once this id is set)
	-- (brief 29, P5)
	OfflineX2 = 0, -- "2x Offline Earnings": doubles what you earned while away (RetentionService / StoreReceipts)
	RestoreStreak = 0, -- "Restore Streak": keeps the daily-reward streak after a missed day (RetentionRules.restore)
	-- (brief 21) the Robux shoe boxes on World 1's dais: one roll from the box's own exclusive shoes (Config/Shoes);
	-- (brief 22) and the Store's Buy 3 / Buy 8 bundles of them
	-- (brief 30: shown as the Chrome Box and the Crown Box; the keys stay, so receipts keep working)
	ShoeBoxExclusive = 0, -- "Chrome Box", 99 Robux
	ShoeBoxExclusive3 = 0, -- "3 Chrome Boxes", 249 Robux
	ShoeBoxExclusive8 = 0, -- "8 Chrome Boxes", 599 Robux
	ShoeBoxGrail = 0, -- "Crown Box", 199 Robux
	ShoeBoxGrail3 = 0, -- "3 Crown Boxes", 499 Robux
	ShoeBoxGrail8 = 0, -- "8 Crown Boxes", 1199 Robux
	-- (brief 30) the Store's weekly Featured pack: one of these three is on sale at a time (Products.featuredAt)
	FeaturedPack1 = 0, -- "Street Pack": Cash + a 3x Power boost + a Chrome Box, 399 Robux
	FeaturedPack2 = 0, -- "Grail Pack": Cash + a 3x Power boost + a Crown Box, 449 Robux
	FeaturedPack3 = 0, -- "Sneaker Pack": more Cash + a 2x Power boost + a Chrome Box, 399 Robux
	-- HUD30 BEGIN (brief 30, HUD: the soldier HUD's extras; HoodServer/HudExtras grants them)
	StarterPack = 0, -- "Starter Pack": a one-time bundle for new players (Cash, 30 min of 2x Power, a Robux box), 149 Robux
	SpinPack = 0, -- "3 Spins": three more spins of the wheel, 39 Robux
	-- HUD30 END
	-- (brief 30) "The Grail Bundle": one pair each of The Grail, Astro Crown and Platinum Wings (Products.GrailBundlePrice)
	GrailBundle = 0,
}
-- (brief 30) The Grail Bundle's price: the one number the catalog row, the Store card and the docs use (the user set it:
-- R$1,499). It is sold at this price only: no countdown, no struck-through price, no sale.
Products.GrailBundlePrice = 1499
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
-- brief 27 display fields (the Store like video A): Sub = the card's one-line subtitle (a short, true summary); Lane =
--   true puts a pass in the 3-up row of big cards (the Power lanes); the other passes are 2-up cards, VIP (Banner) the
--   wide one.
Products.Catalog = {
	-- ~Featured~ (brief 30) the weekly deal: one of the three is on show at a time and the week's pick changes every Monday
	-- (Products.featuredAt). Each is ONE purchase that grants all three parts: Cash (scales with your best stage, like the
	-- Cash Packs), a timed Power boost (Boost = its level, BoostDurationSeconds) and Count of the Robux box Box.
	{ Key = 'FeaturedPack1', Kind = 'Product', Section = 'Featured', Title = 'Street Pack', Sub = 'The Block Starter!', Detail = 'Cash, a 3x Power boost and a Chrome Box', Price = 399, Cash = 6000, Boost = 3, Box = 'Exclusive', Count = 1, Art = 'icon:BoostBundle', Tone = 'cardPurple', Wired = true },
	{ Key = 'FeaturedPack2', Kind = 'Product', Section = 'Featured', Title = 'Grail Pack', Sub = 'Chase the Grail!', Detail = 'Cash, a 3x Power boost and a Crown Box', Price = 449, Cash = 4000, Boost = 3, Box = 'Grail', Count = 1, Art = 'icon:BoostBundle', Tone = 'cardBlue', Wired = true },
	-- (brief 30) The Grail Bundle (the user's bundle sheet): ONE purchase that adds one pair each of Shoes (to keep, like
	-- an opened box's) in one grant. Not part of the weekly rotation: always on show, at its one real price.
	{ Key = 'GrailBundle', Kind = 'Product', Section = 'Featured', Title = 'The Grail Bundle', Sub = 'One pair each of three dream shoes', Detail = 'The Grail, Astro Crown and Platinum Wings: one pair each', Shoes = { 'TheGrail', 'AstroCrown', 'PlatinumWings' }, Price = Products.GrailBundlePrice, Art = 'box:GrailBundle', Tone = 'cardPurple', Wired = true },
	{ Key = 'FeaturedPack3', Kind = 'Product', Section = 'Featured', Title = 'Sneaker Pack', Sub = 'Fresh kicks, fresh Cash!', Detail = 'Lots of Cash, a 2x Power boost and a Chrome Box', Price = 399, Cash = 12000, Boost = 2, Box = 'Exclusive', Count = 1, Art = 'icon:BoostBundle', Tone = 'cardGold', Wired = true },
	-- ~Shoe Boxes~
	{ Key = 'ShoeBoxExclusive', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 1, Title = 'Chrome Box', Detail = 'Exclusive shoes, no Commons', Price = 99, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxExclusive3', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 3, Title = 'Chrome Box', Detail = '3 Chrome Boxes', Price = 249, WasPrice = 297, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxExclusive8', Kind = 'Product', Section = 'Box', Box = 'Exclusive', Count = 8, Title = 'Chrome Box', Detail = '8 Chrome Boxes', Price = 599, WasPrice = 792, Art = 'box:Exclusive', Tone = 'cardBlue', Wired = true },
	{ Key = 'ShoeBoxGrail', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 1, Title = 'Crown Box', Detail = 'The best exclusive shoes', Price = 199, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	{ Key = 'ShoeBoxGrail3', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 3, Title = 'Crown Box', Detail = '3 Crown Boxes', Price = 499, WasPrice = 597, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	{ Key = 'ShoeBoxGrail8', Kind = 'Product', Section = 'Box', Box = 'Grail', Count = 8, Title = 'Crown Box', Detail = '8 Crown Boxes', Price = 1199, WasPrice = 1592, Art = 'box:Grail', Tone = 'cardPurple', Wired = true },
	-- ~Gamepass~
	{ Key = 'DoubleRep', Kind = 'Pass', Section = 'Gamepass', Title = '2x Power', Big = 'Every\nShot', Detail = 'Every shot pays double', Sub = 'On every shot', Lane = true, Price = 199, Art = 'icon:DoublePower', Tone = 'cardGold', Offer = '2x Power', Sticker = '2x', Wired = true },
	{ Key = 'DoubleCash', Kind = 'Pass', Section = 'Gamepass', Title = '2x Cash', Big = 'Every\nStage', Detail = 'Double Cash from pads and goals', Sub = 'Double pad Cash', Price = 149, Art = 'icon:DoubleCash', Tone = 'cardPurple', Offer = '2x Cash', Sticker = '2x', Wired = true },
	{ Key = 'VIP', Kind = 'Pass', Section = 'Gamepass', Banner = true, Title = 'VIP', Big = 'VIP', Detail = 'GOLD TAG + 1.5x CASH', Sub = 'A gold tag and 1.5x Cash', Price = 249, Art = 'icon:VIP', Tone = 'cardGreen', Wired = true },
	{ Key = 'AutoShoot', Kind = 'Pass', Section = 'Gamepass', Title = 'Auto Fight', Big = 'Hands\nFree', Detail = 'Fires at goons for you', Sub = 'Fires for you', Price = 99, Art = 'icon:AutoFight', Tone = 'cardRed', Offer = 'Auto Fight', Wired = true },
	{ Key = 'Lucky', Kind = 'Pass', Section = 'Gamepass', Title = 'Lucky', Big = 'Better\nBoxes', Detail = 'Better odds for Epic and up in Cash boxes', Sub = 'Better box odds', Price = 129, Art = 'icon:Lucky', Tone = 'cardTeal', Wired = true },
	{ Key = 'TripleOpen', Kind = 'Pass', Section = 'Gamepass', Title = 'Triple Open', Big = '3 Boxes\nat Once', Detail = 'Open 3 Cash boxes at once, for 3x the Cash', Sub = 'Open 3 at once', Price = 179, Art = 'icon:TripleOpen', Tone = 'cardBlue', Sticker = 'x3', Wired = true },
	{ Key = 'ExtraEquip', Kind = 'Pass', Section = 'Gamepass', Title = '+1 Shoe Slot', Big = '4 Pairs\nOn', Detail = 'Wear 4 pairs at once', Sub = 'Wear 4 pairs', Price = 99, Art = 'icon:ExtraEquip', Tone = 'cardPink', Sticker = '+1', Wired = true },
	-- (brief 23) the 10x Cash pad and the two Robux lanes. A lane row's Price is its station's RobuxPrice (Config/Skins).
	{ Key = 'TenXCash', Kind = 'Pass', Section = 'Gamepass', Title = '10x Cash', Big = '10x\nPads', Detail = 'The pink pad pays 10x Cash', Sub = 'Pink pad x10', Price = 199, Art = 'icon:TenXCash', Tone = 'cardPink', Offer = '10x Cash', Sticker = '10x', Wired = true },
	{ Key = 'RangeVIP1', Kind = 'Pass', Section = 'Gamepass', Title = 'Pro Bay', Big = 'x100\nPower', Detail = 'Your own x100 Power lane', Sub = 'x100 Power lane', Lane = true, Price = 99, Art = 'icon:ProBay', Tone = 'cardTeal', Offer = 'x100 Lane', Sticker = 'x100', Wired = true },
	{ Key = 'RangeVIP2', Kind = 'Pass', Section = 'Gamepass', Title = 'Gold Bay', Big = 'x250\nPower', Detail = 'Your own x250 Power lane', Sub = 'x250 Power lane', Lane = true, Price = 249, Art = 'icon:GoldBay', Tone = 'cardGold', Offer = 'x250 Lane', Sticker = 'x250', Wired = true },
	-- (brief 30) the soldier game's third paid lane: the head lane at the aisle's end (the reference's 250x on its gold stage)
	{ Key = 'RangeVIP3', Kind = 'Pass', Section = 'Gamepass', Title = 'Head Lane', Big = 'x500\nPower', Detail = 'The best lane: x500 Power', Sub = 'x500 Power lane', Lane = true, Price = 699, Art = 'icon:GoldBay', Tone = 'cardGold', Offer = 'x500 Lane', Sticker = 'x500', Wired = true },
	-- (brief 29, P5) removers of friction: the box's auto button, double walk speed, pads that pay by themselves
	{ Key = 'AutoOpen', Kind = 'Pass', Section = 'Gamepass', Title = 'Auto Open', Big = 'Open\nNon-Stop', Detail = 'The box T button opens boxes for you', Sub = 'Opens boxes for you', Price = 249, Art = 'icon:AutoOpen', Tone = 'cardTeal', Sticker = 'AUTO', Wired = true },
	{ Key = 'Speed2x', Kind = 'Pass', Section = 'Gamepass', Title = '2x Speed', Big = 'Run\nFaster', Detail = 'Walk and run twice as fast', Sub = 'Twice as fast', Price = 99, Art = 'icon:Speed2x', Tone = 'cardGold', Offer = '2x Speed', Sticker = '2x', Wired = true },
	{ Key = 'AutoCollect', Kind = 'Pass', Section = 'Gamepass', Title = 'Auto Collect', Big = 'Cash\nCollects Itself', Detail = 'A street\'s pad Cash pays the moment its crew is down', Sub = 'Pads pay by themselves', Price = 149, Art = 'icon:CashTiny', Tone = 'cardGreen', Offer = 'Auto Collect', Sticker = 'AUTO', Wired = true },
	-- ~Boosts~ (two 2x + one 3x bought one by one: 39 + 39 + 69 = 147)
	{ Key = 'BoostBundle', Kind = 'Product', Section = 'Boost', Wide = true, Title = 'Boost Bundle', Detail = '45 minutes of boosts', Sub = 'Two 2x + one 3x', Bundle = { 'RepBoost2x', 'RepBoost2x', 'RepBoost3x' }, Lines = { '- Two 2x Power Boosts', '- One 3x Power Boost' }, Price = 119, WasPrice = 147, Art = 'icon:BoostBundle', Tone = 'rainbow', Wired = true },
	{ Key = 'RepBoost2x', Kind = 'Product', Section = 'Boost', Title = '2x Power', Detail = '15 minutes', Sub = '15 minutes', Boost = 2, Price = 39, Art = 'icon:PotionRed', Tone = 'cardRed', Wired = true },
	{ Key = 'RepBoost3x', Kind = 'Product', Section = 'Boost', Title = '3x Power', Detail = '15 minutes', Sub = '15 minutes', Boost = 3, Price = 69, Art = 'icon:PotionGold', Tone = 'cardGold', Wired = true },
	{ Key = 'OfflineX2', Kind = 'Product', Section = 'Boost', Title = '2x Offline', Detail = 'Doubles the Power you earned while away', Sub = 'Doubles away Power', Price = 49, Art = 'icon:PotionGold', Tone = 'cardGreen', Offline = 2, Wired = true },
	{ Key = 'BlockParty', Kind = 'Product', Section = 'Boost', Title = 'Block Party', Detail = 'x2 Power for the whole server, 15 min', Sub = 'x2 for everyone', Price = 149, Art = 'icon:BlockParty', Tone = 'cardPurple', Wired = true },
	-- ~Cash Packs~ (Cash per Robux: 26.3, 28.6, 31.0, 32.1, 33.8, 34.5)
	{ Key = 'TinyCash', Kind = 'Product', Section = 'Cash', Title = 'Tiny Pack', Price = 19, Art = 'icon:CashTiny', Tone = 'cardGold', Cash = 500, Wired = true },
	{ Key = 'SmallCash', Kind = 'Product', Section = 'Cash', Title = 'Small Pack', Price = 49, Art = 'icon:CashSmall', Tone = 'cardGold', Cash = 1400, Wired = true },
	{ Key = 'MediumCash', Kind = 'Product', Section = 'Cash', Title = 'Medium Pack', Price = 129, Art = 'icon:CashMedium', Tone = 'cardGold', Cash = 4000, Wired = true },
	{ Key = 'BigCash', Kind = 'Product', Section = 'Cash', Title = 'Big Pack', Price = 249, Art = 'icon:CashBig', Tone = 'cardGold', Cash = 8000, Wired = true },
	{ Key = 'LargeCash', Kind = 'Product', Section = 'Cash', Title = 'Large Pack', Price = 399, Art = 'icon:CashLarge', Tone = 'cardGold', Cash = 13500, Wired = true },
	-- (the MEGA pack: 34,500 at 999 Robux, the most Cash per Robux of the six; with a Cash pack this size the Neon Blaster is one purchase away at stage 1, which is the ECON owner's call)
	{ Key = 'MegaCash', Kind = 'Product', Section = 'Cash', Title = 'Mega Pack', Price = 999, Art = 'icon:CashMega', Tone = 'cardGold', Cash = 34500, Wired = true },
	-- ~Power Packs~ (share of the next rebirth per 100 Robux: 0.53, 0.61, 0.70, 0.72, 0.75, 0.78)
	{ Key = 'PowerPack1', Kind = 'Product', Section = 'Power', Title = 'Tiny Pack', Price = 19, Art = 'icon:PowerTiny', Tone = 'cardGold', Pack = 0.1, Wired = true },
	{ Key = 'PowerPack2', Kind = 'Product', Section = 'Power', Title = 'Small Pack', Price = 49, Art = 'icon:PowerSmall', Tone = 'cardGold', Pack = 0.3, Wired = true },
	{ Key = 'PowerPack3', Kind = 'Product', Section = 'Power', Title = 'Medium Pack', Price = 129, Art = 'icon:PowerMedium', Tone = 'cardGold', Pack = 0.9, Wired = true },
	{ Key = 'PowerPackBig', Kind = 'Product', Section = 'Power', Title = 'Big Pack', Price = 249, Art = 'icon:PowerBig', Tone = 'cardGold', Pack = 1.8, Wired = true },
	{ Key = 'PowerPack4', Kind = 'Product', Section = 'Power', Title = 'Large Pack', Price = 399, Art = 'icon:PowerLarge', Tone = 'cardGold', Pack = 3, Wired = true },
	{ Key = 'PowerPackMega', Kind = 'Product', Section = 'Power', Title = 'Mega Pack', Price = 999, Art = 'icon:PowerMega', Tone = 'cardGold', Pack = 7.8, Wired = true },
	-- (the Daily Rewards window: offered only after a missed day, with its real price)
	{ Key = 'RestoreStreak', Kind = 'Product', Section = 'Streak', Title = 'Restore Streak', Detail = 'Keep your daily streak after a missed day', Price = 25, Art = 'icon:Rewards', Tone = 'cardPink', Wired = true },
	-- HUD30 BEGIN (brief 30, HUD) Shown in their own windows (HoodClient/Extras.client), never in the Store's list. The
	-- Starter Pack is one purchase per player (HudExtrasService hides it once owned and never prompts it again); its parts are
	-- Shared/HudExtrasRules.Starter, granted exactly as its card lists them. 3 Spins adds HudExtrasRules.Spin.PackSpins spins.
	{ Key = 'StarterPack', Kind = 'Product', Section = 'Starter', Title = 'Starter Pack', Detail = 'Cash, 30 min of 2x Power and a Robux shoe box', Price = 149, Art = 'icon:StarterCrate', Tone = 'cardGold', Once = true, Wired = true },
	{ Key = 'SpinPack', Kind = 'Product', Section = 'Spin', Title = '3 Spins', Detail = 'Three more spins of the wheel', Price = 39, Art = 'icon:SpinWheel', Tone = 'cardPurple', Wired = true },
	-- HUD30 END
	-- (the Rebirth window)
	{ Key = 'SkipRebirth', Kind = 'Product', Section = 'Rebirth', Title = 'Skip Rebirth', Detail = 'Rebirth now', Price = 99, Art = 'icon:Rebirth', Tone = 'aqua', Wired = true },
}
Products.ByKey = {}
for i, entry in Products.Catalog do
	entry.Order = i
	Products.ByKey[entry.Key] = entry
end
-- The Store's sections, top to bottom (brief 22, the reference's order; brief 27: video A's plain titles, the Robux
-- boxes first as its "Exclusive"; the Store adds its Codes box after these).
-- (brief 30, the Exclusive Shop reference) Featured first, then the passes, the packs, the boosts and the boxes.
Products.Sections = {
	{ Id = 'Featured', Title = 'Featured' },
	{ Id = 'Gamepass', Title = 'Gamepasses' },
	{ Id = 'Cash', Title = 'Cash Packs' },
	{ Id = 'Power', Title = 'Power Packs' },
	{ Id = 'Boost', Title = 'Boosts' },
	{ Id = 'Box', Title = 'Boxes' },
}

-- (brief 30) The weekly Featured pack. A REAL rotation: the same for everyone (it only reads the clock), turning over
-- every Monday 00:00 UTC (unix time 0 was a Thursday, hence the offset), cycling FeaturedKeys in order. The Store shows a
-- countdown only because this exists: when it reaches 0 the pack on show really is the next one. Returns the key on sale
-- at `now` (os.time / GetServerTimeNow), the seconds until it changes, and the week number.
Products.FeaturedKeys = { 'FeaturedPack1', 'FeaturedPack2', 'FeaturedPack3' }
Products.FeaturedSeconds = 7 * 86400
Products.FeaturedOffset = 4 * 86400
function Products.featuredAt(now)
	if type(now) ~= 'number' or now ~= now then now = os.time() end
	local span = Products.FeaturedSeconds
	local t = math.floor(now) - Products.FeaturedOffset
	local week = math.floor(t / span)
	return Products.FeaturedKeys[week % #Products.FeaturedKeys + 1], (week + 1) * span - t, week
end

-- (brief 30) What "Gift A Player" can send: the Cash Packs and the Robux boxes (never a pass, a boost or a Power pack).
function Products.giftable(key)
	local e = Products.ByKey[key]
	return e ~= nil and e.Kind == 'Product' and e.Wired == true and (e.Section == 'Cash' or e.Section == 'Box')
end

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

-- (brief 29, P5) Power a pack gives: the LARGER of its Pack share of the Power your next rebirth needs (so a pack is worth
-- the same at every stage of the game) and its CurrentShare of the Power you hold right now (so a pack is never small
-- next to what you have), rounded to two figures, at least 100. Client (the label) and server (the grant) both call this
-- with the same `need` and `current`; a pack never gives less than the rebirth-based amount that was on the card.
Products.CurrentShare = 1.5 -- x the pack's Pack share, of your current Power
function Products.powerAmount(key, need, current)
	local entry = Products.ByKey[key]
	if not entry or type(entry.Pack) ~= 'number' then return 0 end
	if type(need) ~= 'number' or need ~= need or need <= 0 then need = 1000 end
	local byNeed = need * entry.Pack
	local byCurrent = 0
	if type(current) == 'number' and current == current and current > 0 then byCurrent = current * entry.Pack * Products.CurrentShare end
	return nice(math.max(byNeed, byCurrent), 100)
end

-- (brief 29, P5) Cash a cash pack gives at `stage` (the best stage you have reached, 1 when unknown): its base amount x
-- (that stage's pad Cash / stage 1's pad Cash) ^ 0.6, so a pack keeps buying a similar number of pad runs as the stages
-- pay more, rounded to two figures. At stage 1 it is exactly the base amount.
Products.CashScaleExponent = 0.6
function Products.cashAmount(key, stage)
	local entry = Products.ByKey[key]
	if not entry or type(entry.Cash) ~= 'number' then return 0 end
	local pads = Balance.PadCash
	local n = type(stage) == 'number' and stage == stage and math.clamp(math.floor(stage), 1, #pads) or 1
	if n <= 1 then return entry.Cash end
	return nice(entry.Cash * (pads[n] / pads[1]) ^ Products.CashScaleExponent, entry.Cash)
end

-- Walk speed a 2x Speed owner gets: exactly x2 (LobbyService.walk), so the name is the truth.
Products.SpeedPassFactor = 2

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

-- (brief 27) What a bundle saves, from the REAL prices (never typed in): the one-by-one price it replaces (a box bundle:
-- Count x its box's single price; the Boost Bundle: the sum of its parts' prices) and the saving in whole percent,
-- round(100 x (1 - Price / one-by-one)). nil for anything that isn't a cheaper bundle. The Store shows the one-by-one
-- price struck through and "SAVE n%".
function Products.savings(key)
	local entry = Products.ByKey[key]
	if not entry or type(entry.Price) ~= 'number' then return nil end
	local whole
	if entry.Section == 'Box' and type(entry.Count) == 'number' and entry.Count > 1 then
		for _, e in Products.Catalog do
			if e.Section == 'Box' and e.Box == entry.Box and (e.Count or 1) == 1 then whole = entry.Count * e.Price end
		end
	elseif type(entry.Bundle) == 'table' then
		whole = 0
		for _, part in entry.Bundle do
			local p = Products.ByKey[part]
			if not p or type(p.Price) ~= 'number' then return nil end
			whole += p.Price
		end
	end
	if not whole or whole <= entry.Price then return nil end
	return whole, math.floor(100 * (1 - entry.Price / whole) + 0.5)
end

-- (brief 30) The shoes a bundle product adds, one pair each (a fresh list; nil for anything else).
function Products.bundleShoes(key)
	local entry = Products.ByKey[key]
	if not entry or type(entry.Shoes) ~= 'table' then return nil end
	return table.clone(entry.Shoes)
end

-- Is this one of the weekly Featured packs (the rotation), not an always-on Featured product like the Grail Bundle?
function Products.isWeekly(key)
	return table.find(Products.FeaturedKeys, key) ~= nil
end

-- The shoe box a product opens and how many: boxId, count (nil, 0 for anything else).
function Products.boxOpen(key)
	local entry = Products.ByKey[key]
	if not entry or (entry.Section ~= 'Box' and entry.Section ~= 'Featured') or type(entry.Box) ~= 'string' then return nil, 0 end
	return entry.Box, type(entry.Count) == 'number' and entry.Count or 1
end

return Products
