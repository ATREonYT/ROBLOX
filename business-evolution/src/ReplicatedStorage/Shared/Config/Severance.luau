--!strict
-- Severance Package perk cards (§6). On each Restructure the server offers
-- three of these; the player CHOOSES one — never random-for-money, which is
-- what keeps this outside the paid-random-item rules.
-- Perks may be picked more than once and stack additively where numeric.

export type PerkDef = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- short emoji-ish label the card UI renders big
	Repeatable: boolean,
}

local Perks: { PerkDef } = {
	{
		Id = "GoldenParachute",
		Name = "Golden Parachute",
		Description = "+10% Wins from every rival, forever",
		Icon = "🪂",
		Repeatable = true,
	},
	{
		Id = "Networking",
		Name = "Networking",
		Description = "+1 Intern slot",
		Icon = "🤝",
		Repeatable = true,
	},
	{
		Id = "InsiderKnowledge",
		Name = "Insider Knowledge",
		Description = "Rivals start with 10% of their Workload already done",
		Icon = "🕵️",
		Repeatable = false,
	},
	{
		Id = "CornerOffice",
		Name = "Corner Office",
		Description = "+5% idle Productivity per second",
		Icon = "🏢",
		Repeatable = true,
	},
	{
		Id = "Nepotism",
		Name = "Nepotism",
		Description = "Start every Restructure at Mail Clerk instead of Unpaid Intern",
		Icon = "👔",
		Repeatable = false,
	},
	{
		Id = "LinkedInfluencer",
		Name = "LinkedInfluencer",
		Description = "+5% Productivity per click, forever",
		Icon = "📣",
		Repeatable = true,
	},
}

local SeveranceModule = {}

SeveranceModule.List = Perks

local byId: { [string]: PerkDef } = {}
for _, perk in Perks do
	byId[perk.Id] = perk
end

function SeveranceModule.get(id: string): PerkDef?
	return byId[id]
end

local function countOwned(owned: { string }, id: string): number
	local count = 0
	for _, ownedId in owned do
		if ownedId == id then
			count += 1
		end
	end
	return count
end

-- Ids the player is still allowed to be offered (non-repeatables drop out).
function SeveranceModule.offerablePool(owned: { string }): { string }
	local pool: { string } = {}
	for _, perk in Perks do
		if perk.Repeatable or countOwned(owned, perk.Id) == 0 then
			table.insert(pool, perk.Id)
		end
	end
	return pool
end

-- Aggregate perk effects into one struct the economy services read.
function SeveranceModule.effects(owned: { string }): {
	WinsBonus: number,
	ExtraInternSlots: number,
	RivalHeadStart: number,
	IdleBonus: number,
	SkipFirstRank: boolean,
	ClickBonus: number,
}
	local effects = {
		WinsBonus = 0,
		ExtraInternSlots = 0,
		RivalHeadStart = 0,
		IdleBonus = 0,
		SkipFirstRank = false,
		ClickBonus = 0,
	}
	for _, id in owned do
		if id == "GoldenParachute" then
			effects.WinsBonus += 0.10
		elseif id == "Networking" then
			effects.ExtraInternSlots += 1
		elseif id == "InsiderKnowledge" then
			effects.RivalHeadStart = 0.10
		elseif id == "CornerOffice" then
			effects.IdleBonus += 0.05
		elseif id == "Nepotism" then
			effects.SkipFirstRank = true
		elseif id == "LinkedInfluencer" then
			effects.ClickBonus += 0.05
		end
	end
	return effects
end

return SeveranceModule
