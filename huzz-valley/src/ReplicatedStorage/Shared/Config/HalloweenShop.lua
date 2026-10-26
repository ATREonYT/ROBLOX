--!strict
--[[
	The Halloween shop (owner, Oct 19 17:41: "make a halloween shop when you press on one of the two crates. and then
	you can buy the crates, or the best knifes for either aura or robux"). Pressing either lobby stand (WITCH'S BREW or
	SWEETS & TREATS, Config/LobbyProps Opens) opens the Shop at its crate (Screens/Shop; one page since Oct 20 14:31, owner: "make it
	all logically connected an all close to eachother"; the crates in CRATES, the knives in KNIVES):
	  Crates  the two stands' crates (Config/Crates Witch and Sweets): open one for its Aura price, or buy a crate key
	          with Robux (Config/Products.Halloween, Kind "CrateKey"); a key opens that crate once instead of Aura.
	          Odds and the pity counter always show, as in Shop > CRATES.
	  Knives  the best knife of each rarity at the top of each set (Legendary and Mythic): bought straight away with
	          Aura (ActionService "BuyHalloweenKnife") or Robux (Config/Products.Halloween, Kind "Knife").
	Aura price of a knife = Markup x the Aura it costs on average to get it from its own crate (Shared/CrateRoll
	.expectedOpens x HalloweenShop.PriceBasis, pity counted), rounded to the nearest 100. tests/HalloweenShop.spec.luau prints
	and checks the numbers: Legendary 11,800 Aura, Mythic 23,600 Aura. Robux prices sit in Config/Products.Halloween.
]]
local Crates = require(script.Parent.Crates)
local Products = require(script.Parent.Products)
local CrateRoll = require(script.Parent.Parent.CrateRoll)

local HalloweenShop = {}

HalloweenShop.Markup = 3 -- a direct knife costs about 3x what its crate costs on average (the coordinator's default)

-- The crates on the page, left to right (each matches a stand: Config/LobbyProps), with their Robux key product and
-- the picture they show: one of his own crate pictures (owner, Oct 20 14:07: "make the halloween shop have the images
-- of the crates from the ones i sent you before"), with that crate's 3D model when the picture can't be drawn.
-- Since Oct 20 20:34 (owner: "make the halloween crates be changed out by the sweet and the cauldron pictures that i
-- sent you right now") each crate shows its own picture from Config/Crates (Picture): Candy = his candy coffin,
-- Witch = his witch cauldron.
HalloweenShop.Crates = {
	{ Crate = "Witch", Robux = "WitchCrateKey" },
	{ Crate = "Sweets", Robux = "SweetsCrateKey" },
}

-- The crate price the knives' Aura prices were set from (120 Aura, Oct 19). The owner cut the crates to 79 and 49 Aura
-- on Oct 20 20:34 but said "keep the halloween knifes", so the knives keep their prices.
HalloweenShop.PriceBasis = 120

-- The knives on the page (Config/CoinShop keys), with the crate their price comes from and their Robux product.
HalloweenShop.Knives = {
	{ Key = "CovenKatana", Crate = "Witch", Robux = "HalloweenCovenKatana" },
	{ Key = "GrandWitchScythe", Crate = "Witch", Robux = "HalloweenGrandWitchScythe" },
	{ Key = "SugarRushKatana", Crate = "Sweets", Robux = "HalloweenSugarRushKatana" },
	{ Key = "CandyReaper", Crate = "Sweets", Robux = "HalloweenCandyReaper" },
} :: { { Key: string, Crate: string, Robux: string, Aura: number?, Opens: number?, Keys: number? } }

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
	k.Aura = math.round(HalloweenShop.Markup * (k.Opens :: number) * HalloweenShop.PriceBasis / 100) * 100
end

-- A Robux knife bought by someone who owns it already (a stale page, or bought on another server first) gives crate
-- keys for its own crate worth what it costs instead: its Robux price / the key's, rounded (149 R$ = 6 keys, 249 R$
-- = 10). Keys, not Aura (Aura has its own packs, Products.Aura). So a purchase always gives something.
for _, k in HalloweenShop.Knives do
	local knifeProduct = Products.get(k.Robux)
	local keyProduct = nil
	for _, c in HalloweenShop.Crates do
		if c.Crate == k.Crate then keyProduct = Products.get(c.Robux) end
	end
	assert(knifeProduct and keyProduct and keyProduct.Price > 0, `Halloween shop: {k.Key} needs its Robux knife and its crate's key`)
	k.Keys = math.max(1, math.round(knifeProduct.Price / keyProduct.Price))
end

function HalloweenShop.knife(key: string)
	for _, k in HalloweenShop.Knives do
		if k.Key == key then return k end
	end
	return nil
end

local function onPage(p: any): boolean
	for _, c in HalloweenShop.Crates do if c.Robux == p.Key then return true end end
	for _, k in HalloweenShop.Knives do if k.Robux == p.Key then return true end end
	return false
end

-- May the server open Roblox's purchase prompt for this Robux product? Only this page's products, only with a real
-- ID (Id 0 = "coming soon"), and never a knife you own (ShopService.promptHalloween asks this before prompting).
function HalloweenShop.canPrompt(data: any, p: any): (boolean, string?)
	if type(p) ~= "table" or not onPage(p) then return false, "That isn't sold here." end
	if Products.status(p) ~= "Ready" then return false, `{p.Name} for Robux is coming soon.` end
	if p.Kind == "Knife" and data.Cosmetics and data.Cosmetics[p.Knife] then return false, "You own this already." end
	return true
end

-- What a paid receipt for this page's product gives (ShopService's ProcessReceipt, inside its save write). Returns
-- false only for a product that isn't this page's (never granted). A crate key: +1 key. A knife: the knife, worn; one
-- you own already: its Keys of its own crate instead (never Robux for nothing). The second result says which; the
-- third is the line to show the player when a knife became keys. Granted even if the item was taken off sale after
-- it was bought (OnSale only stops new prompts: canPrompt): a purchase already paid for always gives something.
function HalloweenShop.grant(data: any, p: any): (boolean, string?, string?)
	if type(p) ~= "table" or not onPage(p) then return false, nil, nil end
	data.CrateKeys = data.CrateKeys or {}
	if p.Kind == "CrateKey" then
		if not Crates.get(p.Crate or "") then return false, nil, nil end
		data.CrateKeys[p.Crate] = (data.CrateKeys[p.Crate] or 0) + 1
		return true, "key", nil
	elseif p.Kind == "Knife" then
		local k = HalloweenShop.knife(p.Knife or "")
		if not k then return false, nil, nil end
		data.Cosmetics = data.Cosmetics or {}
		if data.Cosmetics[k.Key] then
			data.CrateKeys[k.Crate] = (data.CrateKeys[k.Crate] or 0) + (k.Keys :: number)
			local crate = Crates.get(k.Crate)
			return true, "keys", `You already had {p.Name}, so you got {k.Keys} {crate and crate.Name or k.Crate} keys instead.`
		end
		data.Cosmetics[k.Key] = true
		data.Wear = data.Wear or {}
		data.Wear.Knife = k.Key
		return true, "knife", nil
	end
	return false, nil, nil
end

return HalloweenShop
