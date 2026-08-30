--!strict
-- Interns (the pet system, §7). Hired from the Coffee Machine with Wins.
-- Odds are published in the UI and MUST sum to exactly 100 — there is a unit
-- check for this. Wins are never sold for Robux, which keeps the machine
-- outside the paid-random-item rules; keep it that way.
-- ⚠ Rates and the roster are INVENTED (brief defines rarities + the Consultant).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type InternDef = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	PerSecond: number, -- passive Productivity/sec before multipliers
	Special: string?, -- machine-readable perk hook (only "KeepProductivity" today)
	Blurb: string,
}

local InternsModule = {}

-- Chance (in %) of each rarity per hire. Must sum to 100.
local rarityOdds: { [Rarity]: number } = {
	Common = 55,
	Uncommon = 25,
	Rare = 12,
	Epic = 6,
	Legendary = 2,
}
InternsModule.RarityOdds = rarityOdds

local rarityOrder: { Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
InternsModule.RarityOrder = rarityOrder

-- UI + model tint per rarity.
local rarityColors: { [Rarity]: { number } } = {
	Common = { 178, 178, 178 },
	Uncommon = { 88, 200, 92 },
	Rare = { 70, 140, 255 },
	Epic = { 170, 80, 255 },
	Legendary = { 255, 195, 40 },
}
InternsModule.RarityColors = rarityColors

InternsModule.Roster = {
	{ Id = "CoffeeRunner", Name = "Coffee Runner", Rarity = "Common", PerSecond = 2, Blurb = "Two sugars. Runs everywhere." },
	{ Id = "StaplerKid", Name = "Stapler Kid", Rarity = "Common", PerSecond = 3, Blurb = "Owns one red stapler. Guards it." },
	{ Id = "FilingIntern", Name = "Filing Intern", Rarity = "Common", PerSecond = 4, Blurb = "Alphabetizes in their sleep." },
	{ Id = "SpreadsheetWhiz", Name = "Spreadsheet Whiz", Rarity = "Uncommon", PerSecond = 9, Blurb = "VLOOKUP is a personality." },
	{ Id = "NoteTaker", Name = "Note Taker", Rarity = "Uncommon", PerSecond = 12, Blurb = "Minutes so good they feel like hours." },
	{ Id = "CodeMonkey", Name = "Code Monkey", Rarity = "Rare", PerSecond = 28, Blurb = "It works on their machine." },
	{ Id = "SlideProdigy", Name = "Slide Deck Prodigy", Rarity = "Rare", PerSecond = 35, Blurb = "Transitions that move markets." },
	{ Id = "Overachiever", Name = "Overachiever", Rarity = "Epic", PerSecond = 90, Blurb = "CC's your boss's boss. Politely." },
	{ Id = "CeoNephew", Name = "Nephew of the CEO", Rarity = "Epic", PerSecond = 110, Blurb = "Hired for 'culture fit'." },
	{
		Id = "Consultant",
		Name = "The Consultant",
		Rarity = "Legendary",
		PerSecond = 260,
		Special = "KeepProductivity",
		Blurb = "Keeps 25% of your Productivity through a Restructure. Bills by the hour.",
	},
	{ Id = "FutureFounder", Name = "Future Founder", Rarity = "Legendary", PerSecond = 400, Blurb = "Already pitching your job as a startup." },
} :: { InternDef }

local byId: { [string]: InternDef } = {}
local byRarity: { [Rarity]: { InternDef } } = {}
for _, intern in InternsModule.Roster do
	byId[intern.Id] = intern
	local bucket = byRarity[intern.Rarity]
	if not bucket then
		bucket = {}
		byRarity[intern.Rarity] = bucket
	end
	table.insert(bucket, intern)
end

function InternsModule.get(id: string): InternDef?
	return byId[id]
end

function InternsModule.ofRarity(rarity: Rarity): { InternDef }
	return byRarity[rarity] or {}
end

-- True when any EQUIPPED intern carries the given special (server checks this
-- for the Consultant's Restructure carry-over).
function InternsModule.hasSpecialEquipped(owned: { { Uid: string, Id: string } }, equippedUids: { string }, special: string): boolean
	for _, uid in equippedUids do
		for _, intern in owned do
			if intern.Uid == uid then
				local def = byId[intern.Id]
				if def and def.Special == special then
					return true
				end
			end
		end
	end
	return false
end

return InternsModule
