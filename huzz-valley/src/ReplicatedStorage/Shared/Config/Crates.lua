--!strict
--[[
	Crates / cases (owner: "I will add them later"; then "create a good case opening animation"): opened with Aura,
	decided on the server (ActionService "OpenCrate" -> Shared/CrateRoll). Kid-safe rules (root CLAUDE.md): every crate
	shows its odds (CrateRoll.odds, Shop > CRATES) and a pity counter (the top prize is guaranteed after Pity.After
	opens without it); no timers, no fake stock. Aura is only earned in the game (never sold for Robux).

	To add one, add a block like Starter's below to Crates.List:
	  Id      a short unique name ("Starter")
	  Price   Aura per open
	  Items   what can come out: Kind "Cosmetic" (a Config/CoinShop key or a Robux cosmetic key), "Dance" (a
	          Config/Dances id) or "Coins" (Amount); Rarity (Config/Round.Rarities names) and Weight (chance share)
	  Pity    { After = 30, Rarity = "Legendary" }: open 29 without a Legendary or better and the 30th one is one
	  Duplicate  coins given back when you already own what came out: one number, or one per rarity
	The opening screen (UI/Screens/CrateOpen) spins a reel of these items; Shop > CRATES lists every item's chance.
]]
export type CrateItem = { Kind: "Cosmetic" | "Dance" | "Coins", Id: string?, Amount: number?, Name: string, Rarity: string, Weight: number }
export type Crate = { Id: string, Name: string, Price: number, Items: { CrateItem }, Pity: { After: number, Rarity: string }?, Duplicate: (number | { [string]: number })? }

local Crates = {}

Crates.List = {
	-- CLAUDE'S FIRST PICK, waiting on the owner's own crate design (his to-do: "crate contents"). Only things that
	-- already exist in the game: coin shop looks (Config/CoinShop), the Robot dance (Config/Dances; also on the reward
	-- track) and coins. No Dance Pack dances (the pass sells them) and no reward, pass or Spin Wheel items.
	-- Odds by rarity: Common 50%, Uncommon 27%, Rare 15%, Epic 6%, Legendary 2%; a Legendary at the latest on the
	-- 30th open. Price: 50 Aura (about 2 to 3 games of stars; the wheel pays 25 Aura where it pays 250 coins).
	-- A look you already own pays coins back, more for rarer ones (about half its coin shop price or less).
	{
		Id = "Starter", Name = "Starter Crate", Price = 50,
		Duplicate = { Common = 50, Uncommon = 100, Rare = 200, Epic = 400, Legendary = 1000 },
		Pity = { After = 30, Rarity = "Legendary" },
		Items = {
			{ Kind = "Coins", Amount = 150, Name = "150 Coins", Rarity = "Common", Weight = 20 },
			{ Kind = "Cosmetic", Id = "RustyShiv", Name = "Rusty Shiv", Rarity = "Common", Weight = 10 },
			{ Kind = "Cosmetic", Id = "BoxCutter", Name = "Box Cutter", Rarity = "Common", Weight = 10 },
			{ Kind = "Cosmetic", Id = "TagPink", Name = "Pink Name", Rarity = "Common", Weight = 10 },
			{ Kind = "Coins", Amount = 400, Name = "400 Coins", Rarity = "Uncommon", Weight = 9 },
			{ Kind = "Cosmetic", Id = "JadeKunai", Name = "Jade Kunai", Rarity = "Uncommon", Weight = 9 },
			{ Kind = "Cosmetic", Id = "MintTrail", Name = "Mint Trail", Rarity = "Uncommon", Weight = 9 },
			{ Kind = "Cosmetic", Id = "ThunderFang", Name = "Thunder Fang", Rarity = "Rare", Weight = 5 },
			{ Kind = "Cosmetic", Id = "OceanTrail", Name = "Ocean Trail", Rarity = "Rare", Weight = 5 },
			{ Kind = "Dance", Id = "Robot", Name = "Robot", Rarity = "Rare", Weight = 5 },
			{ Kind = "Cosmetic", Id = "CandyTrail", Name = "Candy Trail", Rarity = "Epic", Weight = 3 },
			{ Kind = "Cosmetic", Id = "StormKunai", Name = "Storm Kunai", Rarity = "Epic", Weight = 3 },
			{ Kind = "Cosmetic", Id = "VoidFang", Name = "Void Fang", Rarity = "Legendary", Weight = 1 },
			{ Kind = "Cosmetic", Id = "GalaxyTrail", Name = "Galaxy Trail", Rarity = "Legendary", Weight = 1 },
		},
	},
} :: { Crate }

-- The opening reel the server builds (Shared/CrateRoll.strip): Length cards, the prize on card At (so a few honest
-- cards still show past it when it stops).
Crates.Reel = { Length = 48, At = 40 }

local byId: { [string]: Crate } = {}
for _, c in Crates.List do
	assert(not byId[c.Id], "duplicate crate " .. c.Id)
	byId[c.Id] = c
end

function Crates.get(id: string): Crate?
	return byId[id]
end

return Crates
