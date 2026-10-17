--[[
	Rewards for the girls you get and for playing well (owner: "unique perks for characters that you obtain,
	legendaries - mythics - secrets have better looking cosmetics you can equip, that make you stand out; also add
	titles, like keeper of secrets"). The items are in Config/CoinShop (the ones with Earn); this grants them:
	on join and every time your save changes, anything you've now earned becomes yours, and is worn if nothing is
	worn in that slot yet. They're never sold, so they can't be bought for Robux or coins.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local DataService = require(script.Parent.DataService)

local RewardService = {}

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

-- Whether a save has earned an item (its Earn rule). A rarer girl doesn't unlock the lower rewards: each rarity's
-- rewards are their own.
function RewardService.earned(data, item: CoinShop.Item, has: { [number]: boolean }, count: number): boolean
	local earn = item.Earn
	if not earn then return false end
	if earn.Rarity and not has[RANK[earn.Rarity] or 0] then return false end
	if earn.Girls and count < earn.Girls then return false end
	if earn.Stat and ((data.Stats or {})[earn.Stat] or 0) < (earn.Count or 1) then return false end
	return true
end

-- Grants whatever this player has newly earned. Returns the keys granted.
function RewardService.sync(player: Player): { string }
	local profile = DataService.get(player)
	if not profile then return {} end
	local data = profile.Data
	local has, count = {}, 0
	for id in data.Characters or {} do
		local c = Characters.get(id)
		if c and c.Rarity then
			count += 1
			has[RANK[c.Rarity] or 0] = true
		end
	end
	local new = {}
	for _, item in CoinShop.Items do
		if item.Earn and not data.Cosmetics[item.Key] and RewardService.earned(data, item, has, count) then
			table.insert(new, item.Key)
		end
	end
	if #new > 0 then
		DataService.update(player, function(d)
			for _, key in new do
				local item = CoinShop.get(key) :: CoinShop.Item
				d.Cosmetics[key] = true
				-- worn only if nothing is: never over a cosmetic you bought, nor a slot you emptied on purpose ("")
				if CoinShop.worn(d, item.Slot) == nil and d.Wear[item.Slot] ~= "" then d.Wear[item.Slot] = key end
			end
		end)
	end
	return new
end

-- On join (once the save loads) and once the girls are published (their rarities are known only then).
function RewardService.start()
	local Players = game:GetService("Players")
	local function joined(player: Player)
		task.spawn(function()
			if DataService.waitFor(player, 20) then RewardService.sync(player) end
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, p in Players:GetPlayers() do joined(p) end
	task.spawn(function()
		if ReplicatedStorage:WaitForChild("HuzzGirls", 60) then
			-- (wait until GirlService has added them to Config/Characters, so their rarities are known)
			local deadline = os.clock() + 30
			repeat
				task.wait(0.5)
				local known = false
				for _, c in Characters.List do
					if c.Rarity then known = true; break end
				end
			until known or os.clock() > deadline
			for _, p in Players:GetPlayers() do RewardService.sync(p) end
		end
	end)
end

return RewardService
