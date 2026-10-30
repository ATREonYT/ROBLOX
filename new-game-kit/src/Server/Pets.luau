--!strict
-- New Game Kit: Pets (equipped-pet boost + collection index)
-- Install: ServerScriptService/Kit/Pets (ModuleScript)
--
-- Pets are Inventory uniques (hatched by EggHatch, equipped with Inventory.Equip).
-- This module adds what every pet simulator has on top:
--   boost: each equipped pet adds `boosts[itemId]` to one currency's multiplier
--          (0.25 = +25%); the sum of equipped pets is applied once.
--   index: the first time a player gets a pet it is "discovered"; an optional
--          reward is granted per discovery (the collection book).
-- Main wires EggHatch.Hatched and Inventory grants into Pets.Discover.
-- Remotes: none (equip with Inventory.Equip / Inventory.Unequip).
-- Attributes: PetBoost (current multiplier), Discovered (count) - UI only.
-- Status: runs in the offline Lune harness (tools/sim.luau); not yet run in Studio.

local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Rewards = require(script.Parent.Rewards)

export type Config = {
	currency: string, -- the currency pets boost
	boosts: { [string]: number }, -- itemId -> added multiplier per equipped pet
	discoverReward: Rewards.Reward?,
}

local Pets = {}

local cfg: Config? = nil

-- Pure: 1 + sum of boosts of the equipped item ids.
function Pets.boostFor(itemIds: { string }, boosts: { [string]: number }): number
	local total = 1
	for _, itemId in itemIds do
		total += boosts[itemId] or 0
	end
	return total
end

function Pets.Multiplier(player: Player): number
	local c = cfg :: Config
	local items = {}
	for _, uid in Inventory.GetEquipped(player) do
		local unique = Inventory.GetUnique(player, uid)
		if unique then
			table.insert(items, unique.Item)
		end
	end
	return Pets.boostFor(items, c.boosts)
end

function Pets.IsDiscovered(player: Player, itemId: string): boolean
	local profile = PlayerData.Get(player)
	return profile ~= nil and profile.Data.Pets.Discovered[itemId] == true
end

-- Record a pet as discovered; grants the discover reward once per pet.
function Pets.Discover(player: Player, itemId: string)
	local c = cfg :: Config
	local profile = PlayerData.Get(player)
	if not profile or c.boosts[itemId] == nil or profile.Data.Pets.Discovered[itemId] then
		return
	end
	profile.Data.Pets.Discovered[itemId] = true
	PlayerData.MarkDirty(profile)
	local count = 0
	for _ in profile.Data.Pets.Discovered do
		count += 1
	end
	player:SetAttribute("Discovered", count)
	if c.discoverReward and Rewards.CanGrant(player, c.discoverReward) then
		Rewards.Grant(player, c.discoverReward, `discover:{itemId}`)
	end
end

function Pets.Init(config: Config)
	assert(Currency.Exists(config.currency), `Pets: unknown currency {config.currency}`)
	for itemId, boost in config.boosts do
		local def = Inventory.GetDef(itemId)
		assert(def and def.equippable, `Pets: {itemId} must be an equippable Inventory item`)
		assert(type(boost) == "number" and boost >= 0 and boost <= 100, `Pets {itemId}: boost 0..100`)
	end
	if config.discoverReward then
		Rewards.Validate("Pets.discoverReward", config.discoverReward)
	end
	cfg = config
	PlayerData.RegisterSlice("Pets", function()
		return { Discovered = {} }
	end)
	Currency.AddMultiplier(config.currency, Pets.Multiplier)
	local function publish(player: Player)
		player:SetAttribute("PetBoost", Pets.Multiplier(player))
	end
	Inventory.Changed:Connect(publish)
	PlayerData.Loaded:Connect(function(player: Player, profile: PlayerData.Profile)
		local count = 0
		for _ in profile.Data.Pets.Discovered do
			count += 1
		end
		player:SetAttribute("Discovered", count)
		publish(player)
	end)
end

return Pets
