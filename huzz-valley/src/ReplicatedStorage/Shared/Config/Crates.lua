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
	  Colors  the drawn box's colour, { top, bottom } hex (UI/CrateArt.paint); none = the kit purple
	  Home    the page that sells it when it isn't Shop > CRATES ("HalloweenShop": the two Halloween stands' page)
	The opening screen (UI/Screens/CrateOpen) spins a reel of these items; Shop > CRATES lists every item's chance.
	Owner, Oct 19: "knifes, dances, from crates". The Knife Crate and the Halloween Crate are filled from Config/CoinShop
	(knivesFrom below), so a knife added or renamed there follows by itself; the Dance Crate holds the Robot and seven
	crate-only dances from his 200-dance pack (Config/Dances, Crate = true: never free, never in the Dance Pack).
]]
export type CrateItem = { Kind: "Cosmetic" | "Dance" | "Coins", Id: string?, Amount: number?, Name: string, Rarity: string, Weight: number }
export type Crate = { Id: string, Name: string, Price: number, Colors: { string }?, Items: { CrateItem }, Pity: { After: number, Rarity: string }?, Duplicate: (number | { [string]: number })?, Home: string? }

local CoinShop = require(script.Parent.CoinShop)

local Crates = {}

-- Chance share per item by rarity (the crate's odds are these over their total, shown exactly in the Shop).
local KNIFE_WEIGHT = { Common = 12, Uncommon = 10, Rare = 6, Epic = 4, Legendary = 2, Mythic = 1 }
local HALLOWEEN_WEIGHT = { Common = 40, Uncommon = 24, Rare = 14, Epic = 6, Legendary = 2, Mythic = 1 }
-- Coins back for a knife you own already (about a third of its coin shop price or less).
local KNIFE_DUPLICATE = { Common = 60, Uncommon = 150, Rare = 300, Epic = 600, Legendary = 1200, Mythic = 2500 }

-- The coin shop knives that `pick` accepts, in the shop's order, as crate items weighted by rarity. Never the Game
-- Pass knives, the quest knives, the Spin Wheel's or any reward (they stay where they are earned).
local function knivesFrom(pick: (any) -> boolean, weights: { [string]: number }): { CrateItem }
	local list = {}
	for _, it in CoinShop.Items do
		if it.Slot == "Knife" and not it.Pass and not it.NotForSale and not it.Unlock and not it.Earn and it.Rarity and weights[it.Rarity] and pick(it) then
			table.insert(list, it)
		end
	end
	table.sort(list, function(a, b) return a.Order < b.Order end)
	local items: { CrateItem } = {}
	for _, it in list do
		table.insert(items, { Kind = "Cosmetic", Id = it.Key, Name = it.Name, Rarity = it.Rarity :: string, Weight = weights[it.Rarity :: string] })
	end
	return items
end

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
	-- Owner, Oct 19: "knifes ... from crates". His 30 knives that the coin shop sells (26: not the three quest knives
	-- or the Spin Wheel's Celestial Edge). Odds by rarity: Common 41.8%, Uncommon 29.9%, Rare 17.9%, Epic 8%,
	-- Legendary 2%, Mythic 0.5%; a Legendary or the Mythic at the latest on the 40th open. 100 Aura.
	{
		Id = "Knife", Name = "Knife Crate", Price = 100, Colors = { "4FA8FF", "1F4FA8" },
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesFrom(function(it) return it.Set == nil end, KNIFE_WEIGHT),
	},
	-- His 18 Halloween knives (Pumpkin, Witch and Candy sets, Oct 19). Odds by rarity: Common 46%, Uncommon 27.6%,
	-- Rare 16.1%, Epic 6.9%, Legendary 2.3%, Mythic 1.1%; a Legendary or a Mythic at the latest on the 40th. 120 Aura.
	{
		Id = "Halloween", Name = "Halloween Crate", Price = 120, Colors = { "FF7A1E", "A8360C" },
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesFrom(function(it) return it.Set ~= nil end, HALLOWEEN_WEIGHT),
	},
	-- Owner, Oct 19 17:41: "make a halloween shop when you press on one of the two crates. and then you can buy the
	-- crates". His two lobby stands (WITCH'S BREW and SWEETS & TREATS) each sell their own set's crate on the Halloween
	-- shop page (Home; Screens/HalloweenShop), not in Shop > CRATES: the 6 Witch knives and the 6 Candy knives, with
	-- the Halloween Crate's odds by rarity (Common 46%, Uncommon 27.6%, Rare 16.1%, Epic 6.9%, Legendary 2.3%,
	-- Mythic 1.1%), its pity (a Legendary or the Mythic at the latest on the 40th) and its price (120 Aura).
	{
		Id = "Witch", Name = "Witch's Brew Crate", Price = 120, Colors = { "B45CFF", "4E1E8C" }, Home = "HalloweenShop",
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesFrom(function(it) return it.Set == "Witch" end, HALLOWEEN_WEIGHT),
	},
	{
		Id = "Sweets", Name = "Sweets & Treats Crate", Price = 120, Colors = { "FF80C4", "B0306E" }, Home = "HalloweenShop",
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesFrom(function(it) return it.Set == "Candy" end, HALLOWEEN_WEIGHT),
	},
	-- Owner, Oct 19: "dances, from crates". The Robot plus seven dances only crates give (Config/Dances, Crate = true).
	-- Odds: Common 50%, Uncommon 27%, Rare 15%, Epic 6%, Legendary 2%; the Legendary at the latest on the 30th. 80 Aura.
	{
		Id = "Dance", Name = "Dance Crate", Price = 80, Colors = { "FF6FC0", "A8307E" },
		Duplicate = { Common = 50, Uncommon = 100, Rare = 200, Epic = 400, Legendary = 1000 },
		Pity = { After = 30, Rarity = "Legendary" },
		Items = {
			{ Kind = "Dance", Id = "BoogieBlast", Name = "Boogie Blast", Rarity = "Common", Weight = 25 },
			{ Kind = "Dance", Id = "HeadBanger", Name = "Head Banger", Rarity = "Common", Weight = 25 },
			{ Kind = "Dance", Id = "TheTwist", Name = "The Twist", Rarity = "Uncommon", Weight = 13.5 },
			{ Kind = "Dance", Id = "ZanyZig", Name = "Zany Zig", Rarity = "Uncommon", Weight = 13.5 },
			{ Kind = "Dance", Id = "Robot", Name = "Robot", Rarity = "Rare", Weight = 7.5 },
			{ Kind = "Dance", Id = "PowerMoves", Name = "Power Moves", Rarity = "Rare", Weight = 7.5 },
			{ Kind = "Dance", Id = "Showstopper", Name = "Showstopper", Rarity = "Epic", Weight = 6 },
			{ Kind = "Dance", Id = "ZombieGroove", Name = "Zombie Groove", Rarity = "Legendary", Weight = 2 },
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
