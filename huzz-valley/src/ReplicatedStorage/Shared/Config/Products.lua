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
	Kind: "Pass" | "Cosmetic" | "Coins",
	Name: string,
	Blurb: string,
	Id: number,
	Price: number,
	OnSale: boolean,
	Icon: string,
	Benefits: { Benefit }?,
	Art: string,
	Amount: number?, -- Coins packs: how many coins it gives
	Giftable: boolean?,
	Why: string?, -- OnSale = false: what is missing, for the owner's checklist
}

local Products = {}

Products.Passes = {
	{
		Key = "VIP", Kind = "Pass", Name = "VIP", Blurb = "Exclusive chat tag\nand cosmetics.",
		Id = 0, Price = 199, OnSale = true, Icon = "VipCrown", Art = "Vip",
		Benefits = { { Icon = "ChatBenefit", Text = "VIP Chat Tag" }, { Icon = "ShirtBenefit", Text = "Exclusive Cosmetics" } },
	},
	{
		Key = "DancePack", Kind = "Pass", Name = "Dance Pack", Blurb = "4 dances +\nthemed items.",
		Id = 0, Price = 149, OnSale = false, Icon = "DancesNote", Art = "DancePack", Giftable = true,
		Benefits = { { Icon = "MusicBenefit", Text = "4 Exclusive Dances" }, { Icon = "GiftBenefit", Text = "Dance Themed Items" } },
		Why = "needs the 4 dance animations",
	},
} :: { Product }

Products.Cosmetics = {
	{ Key = "SunsetTrail", Kind = "Cosmetic", Name = "Sunset Trail", Blurb = "Warm trail effect\nfor your avatar.", Id = 0, Price = 99, OnSale = true, Icon = "Avatar", Art = "SunsetTrail" },
	{ Key = "BlossomAura", Kind = "Cosmetic", Name = "Blossom Aura", Blurb = "Gentle petals\nthat follow you.", Id = 0, Price = 99, OnSale = true, Icon = "Avatar", Art = "BlossomAura" },
	{ Key = "CrownPose", Kind = "Cosmetic", Name = "Crown Pose", Blurb = "Victory pose\nfor your avatar.", Id = 0, Price = 99, OnSale = false, Icon = "Avatar", Art = "CrownPose", Why = "needs the victory pose animation" },
	{ Key = "MidnightOutfit", Kind = "Cosmetic", Name = "Midnight Outfit", Blurb = "Sleek dark look\nfor any occasion.", Id = 0, Price = 99, OnSale = false, Icon = "Avatar", Art = "MidnightOutfit", Why = "needs the outfit's clothing assets" },
} :: { Product }

Products.Coins = {
	{ Key = "Coins500", Kind = "Coins", Name = "500 Coins", Blurb = "Get 500 coins\nto spend in game.", Id = 0, Price = 49, Amount = 500, OnSale = false, Icon = "CurrencyCoin", Art = "Coins500", Why = "coins have nothing to buy yet" },
	{ Key = "Coins2000", Kind = "Coins", Name = "2,000 Coins", Blurb = "Get 2,000 coins\nto spend in game.", Id = 0, Price = 149, Amount = 2000, OnSale = false, Icon = "CurrencyCoin", Art = "Coins2000", Why = "coins have nothing to buy yet" },
	{ Key = "Coins5000", Kind = "Coins", Name = "5,000 Coins", Blurb = "Get 5,000 coins\nto spend in game.", Id = 0, Price = 299, Amount = 5000, OnSale = false, Icon = "CurrencyCoin", Art = "Coins5000", Why = "coins have nothing to buy yet" },
} :: { Product }

Products.Tabs = { "Passes", "Cosmetics", "Coins" }

local byKey: { [string]: Product } = {}
local byId: { [string]: Product } = {}
for _, list in { Products.Passes, Products.Cosmetics, Products.Coins } do
	for _, p in list do
		assert(not byKey[p.Key], "duplicate product key " .. p.Key)
		byKey[p.Key] = p
		if p.Id ~= 0 then
			local k = (p.Kind == "Pass" and "pass:" or "product:") .. p.Id
			assert(not byId[k], "duplicate product id " .. k)
			byId[k] = p
		end
	end
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

-- What the buy button should do, from the item's setup alone (ownership is checked separately).
function Products.status(p: Product): "Ready" | "Soon" | "NoId"
	if not p.OnSale then return "Soon" end
	if p.Id == 0 then return "NoId" end
	return "Ready"
end

return Products
