--!strict
-- Training bags — the punching bags of the reference game, reskinned as things
-- a stressed office worker would actually hit: a stress ball on a stand, a
-- photocopier that has had enough, a filing cabinet full of Q3 forecasts.
--
-- THE HOOK (what the player is chasing): a bag's multiplier GROWS with your
-- Restructures. A bag labelled "x10" pays x10 at zero rebirths and much more
-- later, so the same bag stays worth hitting all game:
--
--   payout = BaseMultiplier * (1 + RebirthBonusPerRestructure * restructures)
--
-- Higher bags are gated on Restructures, so there is always a locked one in
-- view — the "you can't have this yet" signal the genre runs on.

export type Bag = {
	Id: string,
	Name: string,
	Flavour: string,
	BaseMultiplier: number, -- x this much Productivity per hit
	MinRestructures: number, -- 0 = open to everyone
	Color: { number }, -- the pad + bag tint
}

local TrainingBags = {}

-- Each Restructure adds this much of the base multiplier back on top.
-- 6 rebirths doubles every bag; 30 makes them 6x their printed value.
TrainingBags.RebirthBonusPerRestructure = 0.1667

-- How often a held/standing hit registers, in seconds. Slower than clicking,
-- but hands-free — the AFK-friendly half of the loop.
TrainingBags.HitInterval = 0.5

local Bags: { Bag } = {
	{
		Id = "StressBall",
		Name = "Stress Ball",
		Flavour = "Squeeze until the feeling passes.",
		BaseMultiplier = 2,
		MinRestructures = 0,
		Color = { 96, 200, 255 },
	},
	{
		Id = "Photocopier",
		Name = "The Photocopier",
		Flavour = "It jammed one time too many.",
		BaseMultiplier = 5,
		MinRestructures = 0,
		Color = { 120, 224, 130 },
	},
	{
		Id = "FilingCabinet",
		Name = "Q3 Filing Cabinet",
		Flavour = "Nobody has opened drawer four since 2019.",
		BaseMultiplier = 10,
		MinRestructures = 1,
		Color = { 255, 196, 40 },
	},
	{
		Id = "Printer",
		Name = "The Printer",
		Flavour = "PC LOAD LETTER.",
		BaseMultiplier = 25,
		MinRestructures = 3,
		Color = { 255, 140, 60 },
	},
	{
		Id = "Inbox",
		Name = "The Inbox",
		Flavour = "12,481 unread. All marked urgent.",
		BaseMultiplier = 50,
		MinRestructures = 6,
		Color = { 200, 90, 255 },
	},
	{
		Id = "Deadline",
		Name = "THE DEADLINE",
		Flavour = "It was yesterday. It is always yesterday.",
		BaseMultiplier = 150,
		MinRestructures = 12,
		Color = { 255, 70, 90 },
	},
	{
		Id = "Quarterly",
		Name = "Quarterly Review",
		Flavour = "Feedback is a gift. This one has teeth.",
		BaseMultiplier = 400,
		MinRestructures = 20,
		Color = { 70, 240, 200 },
	},
	{
		Id = "Merger",
		Name = "The Merger",
		Flavour = "Two companies enter. Your job leaves.",
		BaseMultiplier = 1000,
		MinRestructures = 30,
		Color = { 255, 215, 120 },
	},
}

TrainingBags.List = Bags

local byId: { [string]: Bag } = {}
for _, bag in Bags do
	byId[bag.Id] = bag
end

function TrainingBags.get(id: string): Bag?
	return byId[id]
end

-- The bag's multiplier for a player with this many Restructures. Locked bags
-- still report their value so the UI can advertise what you are missing.
function TrainingBags.multiplierFor(bag: Bag, restructures: number): number
	return bag.BaseMultiplier * (1 + TrainingBags.RebirthBonusPerRestructure * restructures)
end

function TrainingBags.isUnlocked(bag: Bag, restructures: number): boolean
	return restructures >= bag.MinRestructures
end

return TrainingBags
