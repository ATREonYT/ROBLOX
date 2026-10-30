--!strict
-- The evolution ladder. Adding rank 13+ later is a new table entry, nothing else.
-- Requirement curve and multiplier rule come straight from the project brief §2.

export type Rank = {
	Name: string,
	Requirement: number, -- lifetime-this-run Productivity needed to hold this rank
	-- Appearance band drives which prop/outfit set AppearanceService applies.
	-- 1 = intern band, 2 = cheap suit, 3 = tailored, 4 = sharp+gold, 5 = chairman
	Band: number,
	Blurb: string, -- one-liner shown on the rank-up screen
}

local Ranks: { Rank } = {
	{ Name = "Unpaid Intern", Requirement = 0, Band = 1, Blurb = "You have a lanyard. It is not even your lanyard." },
	{ Name = "Mail Clerk", Requirement = 100, Band = 1, Blurb = "The mail moves because of you." },
	{ Name = "Junior Associate", Requirement = 500, Band = 1, Blurb = "You have a desk. Well, half a desk." },
	{ Name = "Analyst", Requirement = 1500, Band = 2, Blurb = "You analyze. Nobody asks what." },
	{ Name = "Senior Analyst", Requirement = 4000, Band = 2, Blurb = "Same job, but louder keyboard." },
	{ Name = "Team Lead", Requirement = 10000, Band = 2, Blurb = "Your calendar is now a weapon." },
	{ Name = "Manager", Requirement = 25000, Band = 3, Blurb = "You circle back. You touch base." },
	{ Name = "Senior Manager", Requirement = 60000, Band = 3, Blurb = "You manage managers now." },
	{ Name = "Director", Requirement = 150000, Band = 3, Blurb = "Restructuring is now on the table." },
	{ Name = "Vice President", Requirement = 1000000, Band = 4, Blurb = "The elevator greets you by name." },
	{ Name = "Chief Executive", Requirement = 25000000, Band = 4, Blurb = "Your signature moves markets." },
	{ Name = "Chairman", Requirement = 500000000, Band = 5, Blurb = "The building was named after you all along." },
}

local RanksModule = {}

RanksModule.List = Ranks

-- Permanent Productivity multiplier per rank: 1 + (rankIndex - 1) * 0.25.
-- Written as a function so rank 13+ needs no new math anywhere.
function RanksModule.multiplierFor(rankIndex: number): number
	return 1 + (rankIndex - 1) * 0.25
end

-- The rank a player with this much Productivity should hold.
function RanksModule.rankForProductivity(productivity: number): number
	local rank = 1
	for index, entry in Ranks do
		if productivity >= entry.Requirement then
			rank = index
		else
			break
		end
	end
	return rank
end

-- Productivity needed for the rank after this one (math.huge at the cap,
-- so progress bars can just clamp instead of special-casing).
function RanksModule.nextRequirement(rankIndex: number): number
	local nextRank = Ranks[rankIndex + 1]
	return if nextRank then nextRank.Requirement else math.huge
end

return RanksModule
