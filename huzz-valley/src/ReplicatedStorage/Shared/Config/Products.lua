--!strict
-- Every item the Shop sells. Prices and IDs are the owner's to set.
--
--   Id        the Game Pass ID (Kind = "Pass") or Developer Product ID (everything else) from the Creator Dashboard.
--             0 = not created yet: the button explains that and never opens a purchase prompt.
--   Price     the Robux price shown until the live price loads from Roblox (the live price always wins).
--   OnSale    false = the item shows "SOON" and cannot be bought, because what it gives does not exist in the game yet.
--             Turn it on only when buying it gives the player something real.
--   Art       a name from Config/Assets.Art: the product picture (cropped from the kit's pages).
--
-- Robux purchases are granted only by the server (ShopService), never by a client click.
export type Benefit = { Icon: string, Text: string }
export type Product = {
	Key: string,
	Kind: "Pass" | "Cosmetic" | "Coins" | "Aura" | "Spins" | "CrateKey" | "Knife" | "Luck",
	Name: string,
	Blurb: string,
	Id: number,
	Price: number,
	OnSale: boolean,
	Icon: string,
	Benefits: { Benefit }?,
	Art: string,
	Amount: number?, -- Coins packs: how many coins it gives; Aura packs: how much Aura; Spins packs: how many spins; Luck: the multiplier
	Giftable: boolean?,
	Slot: string?, -- Cosmetics: where it's worn (Config/CoinShop.Slots); owners tap WEAR / WEARING in the Shop
	Why: string?, -- OnSale = false: what is missing, for the owner's checklist
	Knife: string?, -- knife Game Passes and Halloween knives: the Config/CoinShop knife it gives
	Crate: string?, -- crate keys (Halloween page and Shop > CRATES): the Config/Crates crate it opens once
	Card: any?, -- knife Game Passes: the card's colours
	GamePass: boolean?, -- a Halloween knife sold as a Game Pass (Id is a Game Pass ID)
}

local Products = {}

Products.Passes = {
	{
		Key = "VIP", Kind = "Pass", Name = "VIP", Blurb = "VIP chat tag\nand name tag.",
		Id = 2044922817, Price = 199, OnSale = true, Icon = "VipCrown", Art = "Vip", Accent = Color3.fromHex("7C6CF2"), ButtonStyle = "PassViolet",
		Benefits = { { Icon = "ChatBenefit", Text = "VIP Chat Tag" }, { Icon = "VipCrown", Text = "VIP Name Tag" } },
	},
	{
		Key = "DancePack", Kind = "Pass", Name = "Dance Pack", Blurb = "4 Robux-only\ndances.",
		Id = 2045504839, Price = 149, OnSale = true, Icon = "DancesNote", Art = "DancePack", Giftable = true, Accent = Color3.fromHex("E85BC4"), ButtonStyle = "PassPink",
		Benefits = { { Icon = "MusicBenefit", Text = "4 Dances" }, { Icon = "GiftBenefit", Text = "Robux Only" } },
		-- (on sale since Oct 21 17:25: its 4 dances are in HuzzAnimations, drawn by hand live until published)
	},
	-- The 5 knife Game Passes (owner, Oct 18: "please add the knifes into the ui for the gamepass menu, these are going
	-- to be the gamepasses users can buy"): each gives one knife from Gamepass_Knives.glb (Config/CoinShop Pass = this
	-- key; ShopService grants it only when Roblox says you own the pass). Cards after his mockup
	-- design/knives/Five_Elemental_Knife_Cards.png (Shop > PASSES, top row), named as he wrote them. Card colours are
	-- measured on the mockup: Glow = the name's glow and the element, Name = the name's fade at its foot, Sub = KNIFE.
	-- IDs and prices from the owner, Oct 21 17:25 (his Creator Dashboard).
	{ Key = "HunterKnifePass", Kind = "Pass", Name = "Hunter Knife", Blurb = "Exclusive knife:\nCrimson Requiem.", Knife = "CrimsonRequiem",
		Id = 2044508911, Price = 349, OnSale = true, Icon = "", Art = "PassKnifeHunter",
		Card = { Rim = Color3.fromHex("5F559E"), Glow = Color3.fromHex("FF2D6A"), Name = Color3.fromHex("FFC9DF"), Sub = Color3.fromHex("BC7FCA"), Top = Color3.fromHex("1F163D"), Bottom = Color3.fromHex("131335") } },
	{ Key = "MoonlitKnifePass", Kind = "Pass", Name = "Moonlit Knife", Blurb = "Exclusive knife:\nHollow Eclipse.", Knife = "HollowEclipse",
		Id = 2047484260, Price = 349, OnSale = true, Icon = "", Art = "PassKnifeMoonlit",
		Card = { Rim = Color3.fromHex("5C56A6"), Glow = Color3.fromHex("9C7CFF"), Name = Color3.fromHex("E2DAFF"), Sub = Color3.fromHex("9A88E9"), Top = Color3.fromHex("1E1C4D"), Bottom = Color3.fromHex("131840") } },
	{ Key = "SunriseKnifePass", Kind = "Pass", Name = "Sunrise Knife", Blurb = "Exclusive knife:\nCelestial Seraph.", Knife = "CelestialSeraph",
		Id = 2045210841, Price = 549, OnSale = true, Icon = "", Art = "PassKnifeSunrise",
		Card = { Rim = Color3.fromHex("6E699D"), Glow = Color3.fromHex("FFC85A"), Name = Color3.fromHex("FFEFB8"), Sub = Color3.fromHex("B0ABBB"), Top = Color3.fromHex("1D1E46"), Bottom = Color3.fromHex("12183D") } },
	{ Key = "InfernoKnifePass", Kind = "Pass", Name = "Inferno Knife", Blurb = "Exclusive knife:\nDragon's Maw.", Knife = "DragonsMaw",
		Id = 2045366826, Price = 549, OnSale = true, Icon = "", Art = "PassKnifeInferno",
		Card = { Rim = Color3.fromHex("5E5499"), Glow = Color3.fromHex("FF5A2A"), Name = Color3.fromHex("FBB39F"), Sub = Color3.fromHex("BC82C6"), Top = Color3.fromHex("20173F"), Bottom = Color3.fromHex("12163A") } },
	{ Key = "FrostKnifePass", Kind = "Pass", Name = "Frost Knife", Blurb = "Exclusive knife:\nFrostbound Oath.", Knife = "FrostboundOath",
		Id = 2045144868, Price = 749, OnSale = true, Icon = "", Art = "PassKnifeFrost",
		Card = { Rim = Color3.fromHex("4C54A8"), Glow = Color3.fromHex("4FB8FF"), Name = Color3.fromHex("C4F4FF"), Sub = Color3.fromHex("7BA9F3"), Top = Color3.fromHex("181D50"), Bottom = Color3.fromHex("0E1840") } },
} :: { Product }

-- Robux looks: none (owner, Oct 21: "do we need to make the gamepasses for the trails, outift, etc.? i think we can
-- remove the outfit and stuff like that"). The Sunset Trail, Blossom Aura, Crown Pose and Midnight Outfit never had
-- an ID, so nobody bought them. Trails, name colours, titles and auras are bought with coins or earned
-- (Config/CoinShop); the list stays so older code that loops over it still works.
Products.Cosmetics = {} :: { Product }

Products.Coins = {
	{ Key = "Coins500", Kind = "Coins", Name = "500 Coins", Blurb = "Get 500 coins\nto spend in game.", Id = 3720757750, Price = 49, Amount = 500, OnSale = true, Icon = "CurrencyCoin", Art = "CoinPack500" },
	{ Key = "Coins2000", Kind = "Coins", Name = "2,000 Coins", Blurb = "Get 2,000 coins\nto spend in game.", Id = 3720757955, Price = 149, Amount = 2000, OnSale = true, Icon = "CurrencyCoin", Art = "CoinPack2000" },
	{ Key = "Coins5000", Kind = "Coins", Name = "5,000 Coins", Blurb = "Get 5,000 coins\nto spend in game.", Id = 3720758047, Price = 299, Amount = 5000, OnSale = true, Icon = "CurrencyCoin", Art = "CoinPack5000" },
} :: { Product }

-- Aura packs (Shop > AURA; owner, Oct 20 14:07: "make a buy section for aura"). Developer Products: create each on the
-- Creator Dashboard at these prices and put its ID here; while Id = 0 the button shows its price and only says
-- "coming soon", never a purchase. Granted only in ShopService's ProcessReceipt. Amounts are Claude's pick, matched to
-- the crate keys (25 Robux = one 100 Aura open): 200 Aura for 49 is two opens at the key's price, the bigger packs a
-- little cheaper per open (700 for 149, 1,500 for 299). The owner's to change.
Products.Aura = {
	{ Key = "Aura200", Kind = "Aura", Name = "200 Aura", Blurb = "Get 200 Aura\nfor crates.", Id = 3720758244, Price = 49, Amount = 200, OnSale = true, Icon = "AuraStar", Art = "" },
	{ Key = "Aura700", Kind = "Aura", Name = "700 Aura", Blurb = "Get 700 Aura\nfor crates.", Id = 3720758355, Price = 149, Amount = 700, OnSale = true, Icon = "AuraStar", Art = "" },
	{ Key = "Aura1500", Kind = "Aura", Name = "1,500 Aura", Blurb = "Get 1,500 Aura\nfor crates.", Id = 3720758520, Price = 299, Amount = 1500, OnSale = true, Icon = "AuraStar", Art = "" },
} :: { Product }

-- Spin the Wheel spins (Screens/SpinWheel's purple buttons; the owner's prices, halved Oct 19: "spin prices lower"). Developer Products: create them on
-- the Creator Dashboard and put each ID here. While Id = 0 the button shows its price and only says "coming soon".
Products.Spins = {
	{ Key = "Spins1", Kind = "Spins", Name = "1 Spin", Blurb = "One more spin\non the wheel.", Id = 0, Price = 24, Amount = 1, OnSale = true, Icon = "SpinWheel", Art = "" },
	{ Key = "Spins10", Kind = "Spins", Name = "10 Spins", Blurb = "Ten more spins\non the wheel.", Id = 0, Price = 170, Amount = 10, OnSale = true, Icon = "SpinWheel", Art = "" },
	{ Key = "Spins100", Kind = "Spins", Name = "100 Spins", Blurb = "A hundred spins\non the wheel.", Id = 0, Price = 600, Amount = 100, OnSale = true, Icon = "SpinWheel", Art = "" },
} :: { Product }

-- The Halloween shop's Robux items (Config/HalloweenShop, sold in Screens/Shop; owner, Oct 19: "buy the crates, or
-- the best knifes for either aura or robux"). Developer Products: create each on the Creator Dashboard and put its ID
-- here. While Id = 0 the button shows its price and only says "coming soon", never a purchase. Prices are Claude's pick.
--   CrateKey  one free open of that crate (Config/Crates; saved as CrateKeys, used before Aura)
--   Knife     that Config/CoinShop knife, worn straight away. The owner made the four knives as Game Passes (Oct 21
--             17:25, GamePass = true): Roblox's pass prompt, given when Roblox says you own the pass (ShopService
--             refreshPasses), never through ProcessReceipt.
Products.Halloween = {
	{ Key = "WitchCrateKey", Kind = "CrateKey", Crate = "Witch", Name = "Witch Crate", Blurb = "One open of the\nWitch Crate.", Id = 3720757298, Price = 49, OnSale = true, Icon = "", Art = "" },
	{ Key = "SweetsCrateKey", Kind = "CrateKey", Crate = "Sweets", Name = "Candy Crate", Blurb = "One open of the\nCandy Crate.", Id = 3720757477, Price = 49, OnSale = true, Icon = "", Art = "" },
	{ Key = "HalloweenCovenKatana", Kind = "Knife", Knife = "CovenKatana", Name = "Coven Katana", Blurb = "Legendary knife.", GamePass = true, Id = 2046266840, Price = 149, OnSale = true, Icon = "", Art = "KnifeCovenKatana" },
	{ Key = "HalloweenGrandWitchScythe", Kind = "Knife", Knife = "GrandWitchScythe", Name = "Grand Witch Scythe", Blurb = "Mythic knife.", GamePass = true, Id = 2047484263, Price = 249, OnSale = true, Icon = "", Art = "KnifeGrandWitchScythe" },
	{ Key = "HalloweenSugarRushKatana", Kind = "Knife", Knife = "SugarRushKatana", Name = "Sugar Rush Katana", Blurb = "Legendary knife.", GamePass = true, Id = 2044724818, Price = 149, OnSale = true, Icon = "", Art = "KnifeSugarRushKatana" },
	{ Key = "HalloweenCandyReaper", Kind = "Knife", Knife = "CandyReaper", Name = "Candy Reaper", Blurb = "Mythic knife.", GamePass = true, Id = 2045792822, Price = 249, OnSale = true, Icon = "", Art = "KnifeCandyReaper" },
} :: { Product }

-- Shop > CRATES' BUY buttons (the owner's crate shop mockup, Oct 20: a violet BUY with the Robux mark under each of
-- his three knife crates): one open of that crate (Config/Crates; saved as CrateKeys, used before Aura). Developer
-- Products: while Id = 0 BUY only says "coming soon", never a purchase (ShopService.promptCrateKey checks it again).
-- Prices are Claude's pick (the Halloween crate keys' 25).
Products.Crates = {
	{ Key = "DojoCrateKey", Kind = "CrateKey", Crate = "Dojo", Name = "Shinobi Dojo Chest", Blurb = "One open of the\nShinobi Dojo Chest.", Id = 0, Price = 25, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
	{ Key = "StormCrateKey", Kind = "CrateKey", Crate = "Storm", Name = "Elemental Storm Vault", Blurb = "One open of the\nElemental Storm Vault.", Id = 0, Price = 25, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
	{ Key = "BeastCrateKey", Kind = "CrateKey", Crate = "Beast", Name = "Void Beast Chest", Blurb = "One open of the\nVoid Beast Chest.", Id = 0, Price = 25, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
} :: { Product }

-- Luck boosts (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products, and make it go up in price"; he
-- sends the real products and multipliers later: add a row per product, any Amount works). Amount = the multiplier.
-- Each buy multiplies the buyer's luck, which the whole server shares while they're here (Config/Round.Luck,
-- HuzzServer/LuckService, Screens/Luck). While Id = 0 the button shows its price and only says "coming soon".
-- Prices are Claude's pick until he sends his.
Products.Luck = {
	{ Key = "Luck2", Kind = "Luck", Name = "x2 Luck", Blurb = "x2 server luck\nwhile you're here.", Id = 0, Price = 49, Amount = 2, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
	{ Key = "Luck4", Kind = "Luck", Name = "x4 Luck", Blurb = "x4 server luck\nwhile you're here.", Id = 0, Price = 99, Amount = 4, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
	{ Key = "Luck8", Kind = "Luck", Name = "x8 Luck", Blurb = "x8 server luck\nwhile you're here.", Id = 0, Price = 199, Amount = 8, OnSale = true, Icon = "", Art = "", Why = "needs its Developer Product ID" },
} :: { Product }

Products.Tabs = { "Passes", "Cosmetics", "Items", "Crates", "Coins", "Aura" } -- (Items: the coin shop, Config/CoinShop)

local byKey: { [string]: Product } = {}
local byId: { [string]: Product } = {}
for _, list in { Products.Passes, Products.Cosmetics, Products.Coins, Products.Aura, Products.Spins, Products.Halloween, Products.Crates, Products.Luck } do
	for _, p in list do
		assert(not byKey[p.Key], "duplicate product key " .. p.Key)
		byKey[p.Key] = p
		if p.Id ~= 0 then
			local k = ((p.Kind == "Pass" or p.GamePass) and "pass:" or "product:") .. p.Id
			assert(not byId[k], "duplicate product id " .. k)
			byId[k] = p
		end
	end
end

-- Shop > CRATES' crate key product for a Config/Crates crate id (nil when it has none).
function Products.crateKey(crateId: string): Product?
	for _, p in Products.Crates do if p.Crate == crateId then return p end end
	return nil
end

function Products.get(key: string): Product?
	return byKey[key]
end

function Products.byProductId(id: number): Product?
	return byId["product:" .. id]
end

function Products.byPassId(id: number): Product?
	return byId["pass:" .. id]
end

-- The knife Game Passes in card order (Hunter, Moonlit, Sunrise, Inferno, Frost).
function Products.knifePasses(): { Product }
	local out = {}
	for _, p in Products.Passes do
		if p.Knife then table.insert(out, p) end
	end
	return out
end

-- What the buy button should do, from the item's setup alone (ownership is checked separately).
function Products.status(p: Product): "Ready" | "Soon" | "NoId"
	if not p.OnSale then return "Soon" end
	if p.Id == 0 then return "NoId" end
	return "Ready"
end

return Products
