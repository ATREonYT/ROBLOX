--!strict
--[[
	Crates / cases (owner: "I will add them later"): opened with Aura, decided on the server (ActionService
	"OpenCrate" -> Shared/CrateRoll). Kid-safe rules (root CLAUDE.md): every crate shows its odds (CrateRoll.odds)
	and a pity counter (the top prize is guaranteed after Pity.After opens without it); no timers, no fake stock.

	To add one, copy the example below into Crates.List:
	  Id      a short unique name ("Starter")
	  Price   Aura per open
	  Items   what can come out: Kind "Cosmetic" (a Config/CoinShop key or a Robux cosmetic key), "Dance" (a
	          Config/Dances id) or "Coins" (Amount); Rarity (Config/Round.Rarities names) and Weight (chance share)
	  Pity    { After = 40, Rarity = "Legendary" }: open 40 without a Legendary or better and the next one is one
	  Duplicate  coins given back when you already own what came out
]]
export type CrateItem = { Kind: "Cosmetic" | "Dance" | "Coins", Id: string?, Amount: number?, Name: string, Rarity: string, Weight: number }
export type Crate = { Id: string, Name: string, Price: number, Items: { CrateItem }, Pity: { After: number, Rarity: string }?, Duplicate: number? }

local Crates = {}

Crates.List = {
	-- Example (not live until it's copied in):
	-- {
	-- 	Id = "Starter", Name = "Starter Crate", Price = 50, Duplicate = 150,
	-- 	Pity = { After = 30, Rarity = "Legendary" },
	-- 	Items = {
	-- 		{ Kind = "Coins", Amount = 300, Name = "300 Coins", Rarity = "Common", Weight = 50 },
	-- 		{ Kind = "Cosmetic", Id = "MintTrail", Name = "Mint Trail", Rarity = "Rare", Weight = 30 },
	-- 		{ Kind = "Dance", Id = "SwingTime", Name = "Swing Time", Rarity = "Epic", Weight = 15 },
	-- 		{ Kind = "Cosmetic", Id = "GalaxyTrail", Name = "Galaxy Trail", Rarity = "Legendary", Weight = 5 },
	-- 	},
	-- },
} :: { Crate }

local byId: { [string]: Crate } = {}
for _, c in Crates.List do
	assert(not byId[c.Id], "duplicate crate " .. c.Id)
	byId[c.Id] = c
end

function Crates.get(id: string): Crate?
	return byId[id]
end

return Crates
