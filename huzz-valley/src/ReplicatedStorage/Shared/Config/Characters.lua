--!strict
-- The collectible companions and their tiers. A character's tier is fixed (collecting others never changes it).
--   Art      a name in Config/Assets.Art: the card picture (cropped from the kit's page 02 until real models exist).
--   Starter  owned by every new player.
--   Source   how to get it (shown on locked cards). Only real sources: no invented odds.
--   Rarity/Model  the anime girls you win in rounds (added by Characters.addGirls): her roller rarity and the key of
--                 her still model in ReplicatedStorage.HuzzGirls (pictures are drawn from it).
export type Character = { Id: string, Name: string, Tier: string, Art: string?, Starter: boolean?, Source: string, Order: number, Rarity: string?, Model: string? }

local Characters = {}

-- Lowest to highest.
Characters.Tiers = { "Sub1", "Sub3", "Sub5", "MTB", "HTB", "Stacy", "TrueEve" }
Characters.TierNames = { Sub1 = "SUB 1", Sub3 = "SUB 3", Sub5 = "SUB 5", MTB = "MTB", HTB = "HTB", Stacy = "STACY", TrueEve = "TRUE EVE" }
-- Badge colours per tier (from the kit's tier badges).
Characters.TierColors = {
	Sub1 = Color3.fromHex("7C86C9"), Sub3 = Color3.fromHex("8A8EE6"), Sub5 = Color3.fromHex("E5245A"),
	MTB = Color3.fromHex("A23BE8"), HTB = Color3.fromHex("E07A2A"), Stacy = Color3.fromHex("E5245A"), TrueEve = Color3.fromHex("F2B636"),
}

-- Only the anime girls you win (added by addGirls below). The kit's four mock-up companions (Aiko, Ren, Sora,
-- Hina) were placeholders and are gone (owner's call); DataService drops them from old saves.
Characters.Retired = { Aiko = true, Ren = true, Sora = true, Hina = true }
Characters.List = {
} :: { Character }

local byId: { [string]: Character } = {}
for _, c in Characters.List do byId[c.Id] = c end

-- Each roller rarity sits in the kit's tier of the same rank, so the Tier filter and sorts work for girls too.
Characters.RarityTier = { Common = "Sub1", Uncommon = "Sub3", Rare = "Sub5", Epic = "MTB", Legendary = "HTB", Mythic = "Stacy", Secret = "TrueEve" }

-- Adds the anime girls from ReplicatedStorage.HuzzGirls (GirlService.publish puts Id, Name and Rarity on each
-- copy). Safe to call again: only new girls are added. Returns true when the list changed.
function Characters.addGirls(folder: Instance?): boolean
	if not folder then return false end
	local added = false
	for _, model in folder:GetChildren() do
		local id, name, rarity = model:GetAttribute("Id"), model:GetAttribute("Name"), model:GetAttribute("Rarity")
		if type(id) == "string" and not byId[id] then
			local c: Character = {
				Id = id, Name = if type(name) == "string" then name else id, Rarity = rarity, Model = model.Name,
				Tier = Characters.RarityTier[rarity] or "Sub1", Source = "Win her in a round.", Order = 100 + #Characters.List,
			}
			table.insert(Characters.List, c)
			byId[id] = c
			added = true
		end
	end
	return added
end

function Characters.get(id: string): Character?
	return byId[id]
end

function Characters.tierRank(tier: string): number
	return table.find(Characters.Tiers, tier) or 0
end

return Characters
