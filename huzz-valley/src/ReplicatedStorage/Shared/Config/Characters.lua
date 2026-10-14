--!strict
-- The collectible companions and their tiers. A character's tier is fixed (collecting others never changes it).
--   Art      a name in Config/Assets.Art: the card picture (cropped from the kit's page 02 until real models exist).
--   Starter  owned by every new player.
--   Source   how to get it (shown on locked cards). Only real sources: no invented odds.
export type Character = { Id: string, Name: string, Tier: string, Art: string?, Starter: boolean?, Source: string, Order: number }

local Characters = {}

-- Lowest to highest.
Characters.Tiers = { "Sub1", "Sub3", "Sub5", "MTB", "HTB", "Stacy", "TrueEve" }
Characters.TierNames = { Sub1 = "SUB 1", Sub3 = "SUB 3", Sub5 = "SUB 5", MTB = "MTB", HTB = "HTB", Stacy = "STACY", TrueEve = "TRUE EVE" }
-- Badge colours per tier (from the kit's tier badges).
Characters.TierColors = {
	Sub1 = Color3.fromHex("7C86C9"), Sub3 = Color3.fromHex("8A8EE6"), Sub5 = Color3.fromHex("E5245A"),
	MTB = Color3.fromHex("A23BE8"), HTB = Color3.fromHex("E07A2A"), Stacy = Color3.fromHex("E5245A"), TrueEve = Color3.fromHex("F2B636"),
}

Characters.List = {
	{ Id = "Aiko", Name = "Aiko", Tier = "MTB", Art = "CharAiko", Starter = true, Source = "Your first companion.", Order = 1 },
	{ Id = "Ren", Name = "Ren", Tier = "Sub5", Art = "CharRen", Source = "Unlock through matches.", Order = 2 },
	{ Id = "Sora", Name = "Sora", Tier = "Sub3", Art = "CharSora", Source = "Unlock through matches.", Order = 3 },
	{ Id = "Hina", Name = "Hina", Tier = "Stacy", Art = nil, Source = "Unlock through matches.", Order = 4 },
} :: { Character }

local byId: { [string]: Character } = {}
for _, c in Characters.List do byId[c.Id] = c end

function Characters.get(id: string): Character?
	return byId[id]
end

function Characters.tierRank(tier: string): number
	return table.find(Characters.Tiers, tier) or 0
end

return Characters
