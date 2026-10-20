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
	  Model   his 3D crate the opening shows (owner, Oct 20: "make these crates for the opening of the normal knifes"):
	          Set = the set Model in his Workspace > scrates > Standard_Crates (published to ReplicatedStorage >
	          HuzzCrates by Shared/CrateModels at game start and in the place build), Crate = the crate Model in it,
	          Body = its main box part (what stays put while the rest opens: Shared/CrateMotion.split), Built = how
	          far (degrees) his lid already stands open in his model (he built the Storm Vault and the Beast Chest
	          open, as his mockup draws them; the opening shuts it first, the shop shows it as he built it).
	          Without it (or before his model is there) the opening draws the plain crate and spins the reel.
	The opening screen (UI/Screens/CrateOpen) spins a reel of these items; Shop > CRATES lists every item's chance.
	Owner, Oct 19: "knifes, dances, from crates". His three knife crates (Oct 20) hold the knives he put beside each in
	his place (knivesNamed below: a spec checks the lists against his sets); the Halloween Crate is filled from
	Config/CoinShop (knivesFrom below), so a knife added or renamed there follows by itself; the Dance Crate holds the Robot and seven
	crate-only dances from his 200-dance pack (Config/Dances, Crate = true: never free, never in the Dance Pack).
]]
export type CrateItem = { Kind: "Cosmetic" | "Dance" | "Coins", Id: string?, Amount: number?, Name: string, Rarity: string, Weight: number }
export type CrateModel = { Set: string, Crate: string, Body: string, Built: number? }
export type Crate = { Id: string, Name: string, Price: number, Colors: { string }?, Items: { CrateItem }, Pity: { After: number, Rarity: string }?, Duplicate: (number | { [string]: number })?, Home: string?, Model: CrateModel? }

local CoinShop = require(script.Parent.CoinShop)

local Crates = {}

-- Chance share per item by rarity (the crate's odds are these over their total, shown exactly in the Shop).
local KNIFE_WEIGHT = { Common = 12, Uncommon = 10, Rare = 6, Epic = 4, Legendary = 2, Mythic = 1 }
-- The Void Beast Chest's own weights: his set holds three Epics but one Rare, so KNIFE_WEIGHT made Epic (18.5%) likelier
-- than Rare (9.2%). These keep every rarer tier rarer, with the same knives: C 40, U 30, R 15, E 10.5, L 3, M 1.5%.
local BEAST_WEIGHT = { Common = 40, Uncommon = 30, Rare = 30, Epic = 7, Legendary = 6, Mythic = 3 }
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

-- Named coin shop knives (in this order) as crate items weighted by rarity: his own crate sets (Oct 20), which also
-- hold the quest knives and the Spin Wheel's Celestial Edge (owner, Oct 20: "make all of the knifes earned either
-- through crates/bought/ or robux"). Never a Game Pass knife.
local function knivesNamed(keys: { string }, weights: { [string]: number }): { CrateItem }
	local items: { CrateItem } = {}
	for _, key in keys do
		local it = CoinShop.get(key)
		assert(it and it.Slot == "Knife" and not it.Pass and it.Rarity and weights[it.Rarity], "crate knife " .. key)
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
	-- His three knife crates (owner, Oct 20, 03:33: "here is the new one with updated crates, make these crates for the
	-- opening of the normal knifes"): each opens with his own 3D crate (Model) and holds the ten knives he laid out in
	-- front of it in his place (Workspace > scrates > Standard_Crates > <set>), all 30 of his knives between them.
	-- Odds by rarity, from KNIFE_WEIGHT (the Beast Chest: BEAST_WEIGHT) over each crate's items (exact chances in Shop > CRATES):
	--   Shinobi Dojo Chest:    Common 42.9%, Uncommon 35.7%, Rare 14.3%, Epic 4.8%, Legendary 2.4%
	--   Elemental Storm Vault: Common 45%, Uncommon 25%, Rare 22.5%, Epic 5%, Legendary 2.5%
	--   Void Beast Chest:      Common 40%, Uncommon 30%, Rare 15%, Epic 10.5%, Legendary 3%, Mythic 1.5% (BEAST_WEIGHT)
	-- A Legendary or better at the latest on the 40th open (each crate counts its own). 100 Aura each (the old Knife
	-- Crate's price). Colours (the plain crate drawn in Shop > CRATES until his UI pictures come): his crates' own.
	{
		Id = "Dojo", Name = "Shinobi Dojo Chest", Price = 100, Colors = { "E0525E", "7A1E2C" },
		Model = { Set = "dojo_set", Crate = "Shinobi_Dojo_Chest", Body = "chest_core" },
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesNamed({ "RookieKnife", "PlainTanto", "ScoutDagger", "JadeKunai", "CrimsonTanto", "NightTanto", "CandyKnife",
			"SpiritKunai", "BloodMoonTanto", "SpinKnife" }, KNIFE_WEIGHT),
	},
	{
		Id = "Storm", Name = "Elemental Storm Vault", Price = 100, Colors = { "4FA8FF", "1F4FA8" },
		Model = { Set = "storm_set", Crate = "Elemental_Storm_Vault", Body = "vault_body", Built = 31 }, -- (his lid stands 31 deg open: its front edge 0.75 studs over the body, 1.17 from the hinge)
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesNamed({ "KitchenCleaver", "FieldKnife", "BoxCutter", "IceKnife", "CopperCleaver", "ThunderFang", "FrostFang",
			"EmberEdge", "StormKunai", "SolarReaper" }, KNIFE_WEIGHT),
	},
	{
		Id = "Beast", Name = "Void Beast Chest", Price = 100, Colors = { "A35CFF", "3E1A6E" },
		Model = { Set = "beast_set", Crate = "Void_Beast_Chest", Body = "chest_body", Built = 15 }, -- (his jaw stands 15 deg open: shut, the upper teeth meet the lower ones)
		Duplicate = KNIFE_DUPLICATE,
		Pity = { After = 40, Rarity = "Legendary" },
		Items = knivesNamed({ "RustyShiv", "BoneKnife", "SerratedFang", "HunterKnife", "VenomKris", "MoonlitKnife", "ShadowKnife",
			"TwinFang", "VoidFang", "AbyssEclipse" }, BEAST_WEIGHT),
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
