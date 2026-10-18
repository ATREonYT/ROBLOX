--!strict
--[[
	The Spin the Wheel (owner: "make the spin the wheel give more, and make it once every 15 minutes a free spin,
	but if they want to buy they can"). Server: HuzzServer/SpinService. Screen: UI/Screens/SpinWheel.
	Rules in Shared/SpinRules (pure, tests/SpinWheel.spec.luau); the roll is Shared/CrateRoll (shown odds + pity).

	Items are the 8 slices, clockwise from the top. Weight = the chance in percent (they add up to 100, and the
	Odds list shows each one exactly). Kind:
	  Coins  Amount coins          Aura  Amount Aura
	  Boost  x2 coins from games for Minutes (stacks: another one adds its minutes)
	  Knife  the Spin Knife skin (Config/CoinShop "SpinKnife" = the owner's Celestial Edge model, only from here); already owned = Duplicate coins
	Pity: after Pity.After - 1 spins in a row without a Legendary, the next spin is one (shown on the screen).
	Earnings for scale (Config/Round.Pay): 25 coins a game, 50 more for a win; coin shop looks cost 200 to 8,000.
]]
local SpinWheel = {}

SpinWheel.FreeEvery = 15 * 60 -- seconds between free spins
SpinWheel.Multi = { 5, 10 } -- the Spin x5 / Spin x10 buttons
SpinWheel.Duplicate = 1500 -- coins instead of the Spin Knife when you own it already
SpinWheel.Pity = { After = 40, Rarity = "Legendary" }

local hex = Color3.fromHex
-- Slice colours (also drawn into the HUD icon by tools/icons/make_spin_wheel.py).
SpinWheel.Colors = { Legendary = hex("FF4FAE"), A = hex("2F9BFF"), B = hex("7A4DFF") }

SpinWheel.Items = {
	{ Key = "SpinKnife", Kind = "Knife", Name = "Celestial Edge", Big = "SPIN", Small = "KNIFE", Rarity = "Legendary", Weight = 1, Color = "Legendary" },
	{ Key = "Coins100", Kind = "Coins", Amount = 100, Name = "100 Coins", Big = "100", Small = "COINS", Rarity = "Common", Weight = 28, Color = "A" },
	{ Key = "Aura25", Kind = "Aura", Amount = 25, Name = "25 Aura", Big = "25", Small = "AURA", Rarity = "Uncommon", Weight = 16, Color = "B" },
	{ Key = "Coins500", Kind = "Coins", Amount = 500, Name = "500 Coins", Big = "500", Small = "COINS", Rarity = "Rare", Weight = 10, Color = "A" },
	{ Key = "CoinBoost", Kind = "Boost", Boost = "Coins", Minutes = 15, Name = "x2 Coins 15m", Big = "x2", Small = "15 MIN", Rarity = "Uncommon", Weight = 12, Color = "B" },
	{ Key = "Coins250", Kind = "Coins", Amount = 250, Name = "250 Coins", Big = "250", Small = "COINS", Rarity = "Common", Weight = 22, Color = "A" },
	{ Key = "Aura60", Kind = "Aura", Amount = 60, Name = "60 Aura", Big = "60", Small = "AURA", Rarity = "Rare", Weight = 7, Color = "B" },
	{ Key = "Coins1000", Kind = "Coins", Amount = 1000, Name = "1,000 Coins", Big = "1000", Small = "COINS", Rarity = "Epic", Weight = 4, Color = "A" },
}

-- Rarity colours for the Odds list and the reward popup.
SpinWheel.RarityColors = {
	Common = hex("D9E1F5"), Uncommon = hex("5BE07A"), Rare = hex("4FB4FF"), Epic = hex("B57BFF"), Legendary = hex("FF6FC0"),
}

for i, item in SpinWheel.Items do
	(item :: any).Slot = i
end

function SpinWheel.slotOf(key: string): number?
	for i, item in SpinWheel.Items do
		if item.Key == key then return i end
	end
	return nil
end

return SpinWheel
