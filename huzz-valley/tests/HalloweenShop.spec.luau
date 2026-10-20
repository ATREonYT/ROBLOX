-- The Halloween shop's prices (Config/HalloweenShop, Shared/CrateRoll.expectedOpens): the average number of opens is
-- exact (checked against a long seeded run with the real pity), a direct knife costs 3x its crate's average, and every
-- Robux item is a Developer Product with Id 0 until the owner makes it (never an invented ID).
-- lune run tests/HalloweenShop.spec.luau   (from huzz-valley/)
local CrateRoll = require("../src/ReplicatedStorage/Shared/CrateRoll")
local Env = require("../tools/preview/motion3d/env")
local Crates = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Crates.lua")
local Shop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/HalloweenShop.lua")
local Products = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Products.lua")
local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")
local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- 1. expectedOpens: no pity = 1 / chance; a tiny crate worked by hand; a long seeded run agrees
local flat = { Items = { { Rarity = "Common", Weight = 3 }, { Rarity = "Legendary", Weight = 1 } } }
check("no pity: 1 / chance", math.abs(CrateRoll.expectedOpens(flat, flat.Items[2]) - 4) < 1e-9)
local two = { Pity = { After = 2, Rarity = "Legendary" }, Items = { { Rarity = "Common", Weight = 1 }, { Rarity = "Legendary", Weight = 1 } } }
-- (half the time on the 1st open, else certain on the 2nd: 1.5)
check("pity 2, half chance: 1.5 opens", math.abs(CrateRoll.expectedOpens(two, two.Items[2]) - 1.5) < 1e-9)
local state = 4242
local function rand()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
for _, id in { "Witch", "Sweets" } do
	local crate = Crates.get(id)
	check(`{id}: the crate exists, lives on the Halloween page`, crate ~= nil and crate.Home == "HalloweenShop")
	-- (owner, Oct 20 20:34, his picture 2034-ablt1: CANDY CRATE 250 coins / 49 Aura, WITCH CRATE 350 / 79)
	local price = ({ Witch = { 79, 350 }, Sweets = { 49, 250 } })[id]
	check(`{id}: 6 knives, {price[1]} Aura or {price[2]} coins, pity 40`, crate ~= nil and #crate.Items == 6 and crate.Price == price[1] and crate.CoinPrice == price[2] and crate.Pity.After == 40)
	local mythic
	for _, it in crate.Items do if it.Rarity == "Mythic" then mythic = it end end
	local pity, opens, got, n = 0, 0, 0, 0
	while got < 4000 do
		local item; item, pity = CrateRoll.roll(crate, pity, rand)
		opens += 1
		if item == mythic then got += 1; n += opens; opens = 0 end
	end
	-- (the chain starts fresh only after a top prize; a Mythic always is one, so each run between Mythics starts fresh)
	local want = CrateRoll.expectedOpens(crate, mythic)
	check(`{id}: the Mythic takes {string.format("%.1f", want)} opens on average (run: {string.format("%.1f", n / got)})`, math.abs(n / got - want) / want < 0.05)
end

-- 2. the knives: the Legendary and Mythic of each set, Aura price = 3x the crate's average, Robux products with Id 0
-- (priced from the crates' 120 Aura of Oct 19, HalloweenShop.PriceBasis: the owner kept the knives as they were when he
-- cut the crates' prices on Oct 20 20:34)
check("the knives' price basis stays 120 Aura", Shop.PriceBasis == 120)
print("Halloween shop prices (Aura = 3 x average opens x 120 Aura, to the nearest 100):")
check("4 knives", #Shop.Knives == 4)
for _, k in Shop.Knives do
	local item = CoinShop.get(k.Key)
	local crate = Crates.get(k.Crate)
	check(`{k.Key}: a Halloween knife`, item ~= nil and item.Slot == "Knife" and item.Set ~= nil)
	check(`{k.Key}: the top of its set`, item ~= nil and (item.Rarity == "Legendary" or item.Rarity == "Mythic"))
	local avg = k.Opens * Shop.PriceBasis
	check(`{k.Key}: 3x its average cost`, math.abs(k.Aura - 3 * avg) <= 50)
	local p = Products.get(k.Robux)
	check(`{k.Key}: a Robux product`, p ~= nil and p.Kind == "Knife" and p.Knife == k.Key)
	check(`{k.Key}: Id 0 (the owner makes it)`, p ~= nil and p.Id == 0 and Products.status(p) == "NoId")
	print(string.format("  %-18s %-9s %5.1f opens = %5d Aura on average -> %6d Aura, %d R$", k.Key, item and item.Rarity or "?", k.Opens, math.round(avg), k.Aura, p and p.Price or 0))
end
for _, c in Shop.Crates do
	local p = Products.get(c.Robux)
	check(`{c.Crate}: a Robux crate key`, p ~= nil and p.Kind == "CrateKey" and p.Crate == c.Crate)
	check(`{c.Crate}: key Id 0`, p ~= nil and p.Id == 0 and Products.status(p) == "NoId")
	print(string.format("  %-18s crate      120 Aura an open, a key %d R$", c.Crate, p and p.Price or 0))
end
local legend, mythic = Shop.knife("CovenKatana"), Shop.knife("GrandWitchScythe")
check("a Mythic costs more than a Legendary", legend and mythic and mythic.Aura > legend.Aura)

-- 3. Robux never buys nothing: no prompt for a knife you own (or without an ID, or not this page's); a receipt that
-- still arrives for an owned knife gives its crate's keys worth its price (Keys: Aura is never sold for Robux)
local reaper = table.clone(Products.get("HalloweenCandyReaper")); reaper.Id = 555 -- (as if the owner set its ID)
local key = table.clone(Products.get("SweetsCrateKey")); key.Id = 444
local fresh = { Cosmetics = {}, Wear = {} }
local owner = { Cosmetics = { CandyReaper = true }, Wear = { Knife = "VineDagger" }, CrateKeys = { Sweets = 1 } }
check("prompt: a knife you don't own, with its ID", (Shop.canPrompt(fresh, reaper)) == true)
local okP, whyP = Shop.canPrompt(owner, reaper)
check(`prompt: never for a knife you own ({whyP})`, okP == false and tostring(whyP):find("own") ~= nil)
okP, whyP = Shop.canPrompt(fresh, Products.get("HalloweenCandyReaper"))
check(`prompt: never without an ID ({whyP})`, okP == false and tostring(whyP):find("coming soon") ~= nil)
check("prompt: never for another page's product", (Shop.canPrompt(fresh, Products.get("Spins10"))) == false and (Shop.canPrompt(fresh, nil)) == false)
check("prompt: a crate key, even with keys already", (Shop.canPrompt(owner, key)) == true)
local reaperEntry = Shop.knife("CandyReaper")
check(`refund keys: Mythic {reaperEntry.Keys} (249 / 25 R$), Legendary {Shop.knife("CovenKatana").Keys} (149 / 25 R$)`, reaperEntry.Keys == 10 and Shop.knife("CovenKatana").Keys == 6)
local okG, what = Shop.grant(fresh, reaper)
check("receipt: the knife, worn", okG == true and what == "knife" and fresh.Cosmetics.CandyReaper == true and fresh.Wear.Knife == "CandyReaper")
local note
okG, what, note = Shop.grant(owner, reaper)
check(`receipt for a knife you own: {reaperEntry.Keys} Sweets keys instead, knife and worn knife untouched`, okG == true and what == "keys" and owner.CrateKeys.Sweets == 1 + reaperEntry.Keys and owner.Wear.Knife == "VineDagger")
check(`... and the player is told which knife, how many keys, which crate ({note})`, note == "You already had Candy Reaper, so you got 10 Candy Crate keys instead.")
check("a normal knife receipt needs no extra line", select(3, Shop.grant({ Cosmetics = {}, Wear = {} }, reaper)) == nil)
-- taken off sale after it was bought: no new prompts, but a paid receipt is still granted (never "not processed")
local offKnife = table.clone(reaper); offKnife.OnSale = false
local offKey = table.clone(key); offKey.OnSale = false
check("off sale: no new prompt", (Shop.canPrompt({ Cosmetics = {} }, offKnife)) == false and (Shop.canPrompt({ Cosmetics = {} }, offKey)) == false)
local late = { Cosmetics = {}, Wear = {} }
check("off sale: a paid knife receipt is still granted", (Shop.grant(late, offKnife)) == true and late.Cosmetics.CandyReaper == true)
check("off sale: a paid key receipt is still granted", (Shop.grant(late, offKey)) == true and late.CrateKeys.Sweets == 1)
okG, what = Shop.grant(owner, key)
check("receipt: a crate key adds one", okG == true and what == "key" and owner.CrateKeys.Sweets == 2 + reaperEntry.Keys)
check("receipt: never another page's product", (Shop.grant(fresh, Products.get("Spins10"))) == false)

print(string.format("HalloweenShop: %d passed, %d failed", passed, failed))
if failed > 0 then error("HalloweenShop spec failed") end
