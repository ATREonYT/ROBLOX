--!strict
--[[
	The Halloween shop (owner, Oct 19 17:41: "make a halloween shop when you press on one of the two crates. and then
	you can buy the crates, or the best knifes for either aura or robux"). Pressing either lobby stand (WITCH'S BREW or
	SWEETS & TREATS, Config/LobbyProps Opens) opens Screens/HalloweenShop:
	  Crates  the two stands' crates (Config/Crates Witch and Sweets): open one for its Aura price, or buy a crate key
	          with Robux (Config/Products.Halloween, Kind "CrateKey"); a key opens that crate once instead of Aura.
	          Odds and the pity counter always show, as in Shop > CRATES.
	  Knives  the best knife of each rarity at the top of each set (Legendary and Mythic): bought straight away with
	          Aura (ActionService "BuyHalloweenKnife") or Robux (Config/Products.Halloween, Kind "Knife").
	Aura price of a knife = Markup x the Aura it costs on average to get it from its own crate (Shared/CrateRoll
	.expectedOpens x the crate's price, pity counted), rounded to the nearest 100. tests/HalloweenShop.spec.luau prints
	and checks the numbers: Legendary 11,800 Aura, Mythic 23,600 Aura. Robux prices sit in Config/Products.Halloween.
]]
local Crates = require(script.Parent.Crates)
local CrateRoll = require(script.Parent.Parent.CrateRoll)

local HalloweenShop = {}

HalloweenShop.Markup = 3 -- a direct knife costs about 3x what its crate costs on average (the coordinator's default)

-- The crates on the page, left to right (each matches a stand: Config/LobbyProps), with their Robux key product.
HalloweenShop.Crates = {
	{ Crate = "Witch", Robux = "WitchCrateKey" },
	{ Crate = "Sweets", Robux = "SweetsCrateKey" },
}

-- The knives on the page (Config/CoinShop keys), with the crate their price comes from and their Robux product.
HalloweenShop.Knives = {
	{ Key = "CovenKatana", Crate = "Witch", Robux = "HalloweenCovenKatana" },
	{ Key = "GrandWitchScythe", Crate = "Witch", Robux = "HalloweenGrandWitchScythe" },
	{ Key = "SugarRushKatana", Crate = "Sweets", Robux = "HalloweenSugarRushKatana" },
	{ Key = "CandyReaper", Crate = "Sweets", Robux = "HalloweenCandyReaper" },
} :: { { Key: string, Crate: string, Robux: string, Aura: number?, Opens: number? } }

-- Work out each knife's Aura price once, from its crate.
for _, k in HalloweenShop.Knives do
	local crate = Crates.get(k.Crate)
	assert(crate, "Halloween shop: unknown crate " .. k.Crate)
	local item = nil
	for _, it in crate.Items do
		if it.Id == k.Key then item = it end
	end
	assert(item, `Halloween shop: {k.Key} isn't in the {k.Crate} crate`)
	k.Opens = CrateRoll.expectedOpens(crate, item)
	k.Aura = math.round(HalloweenShop.Markup * (k.Opens :: number) * crate.Price / 100) * 100
end

function HalloweenShop.knife(key: string)
	for _, k in HalloweenShop.Knives do
		if k.Key == key then return k end
	end
	return nil
end

return HalloweenShop
