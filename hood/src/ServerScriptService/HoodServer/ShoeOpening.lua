-- The one place the server opens a shoe box (brief 21). A ModuleScript, so both ways of opening a box share it:
--   * ShoeService (the OpenShoeBox remote): a Cash box, after ShoeRules.canOpen and taking the Cash;
--   * StoreService (a developer-product receipt): a Robux box (ShoeRules.canGrant), paid in Robux.
-- Either way the pair is rolled here with the server's Random, added to the profile, the player's shoe attributes
-- are synced, the client gets ShoeOpened (Shoes.client plays the same unboxing moment for both) and a Legendary or
-- better pair is news for the whole server.
--   ShoeOpening.sync(player, profile)            the shoe attributes from the profile (ShoeService documents them)
--   ShoeOpening.open(player, profile, boxId, r?) -> shoeId, info
--       rolls (r: a fixed roll in [0, 1) for tests), adds the pair, syncs, tells the client. It changes the profile
--       before anything that could fail and never yields, so a receipt's grant and its purchase id go into the same
--       save. The caller pushes the profile (Data.push) and checks whether the box may be opened at all.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local Shoes = require(RS.Shared.Config.Shoes)
local ShoeRules = require(RS.Shared.ShoeRules)

local ShoeOpening = {}
local rng = Random.new()

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
function ShoeOpening.sync(player, profile)
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local list = ShoeRules.equippedList(shoes)
	local bonus = ShoeRules.bonus(shoes)
	set(player, 'ShoesEquipped', table.concat(list, ','))
	set(player, 'ShoeWorn', list[1] or '')
	set(player, 'ShoeBonus', bonus)
	set(player, 'ShoeMultiplier', 1 + bonus / 100)
	set(player, 'ShoesOwned', ShoeRules.ownedString(shoes))
	set(player, 'ShoesOpened', shoes.Opened)
end

function ShoeOpening.open(player, profile, boxId, r)
	local box = Shoes.BoxById[boxId]
	assert(box, 'unknown box ' .. tostring(boxId))
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local before = #shoes.Equipped
	local id, fresh = ShoeRules.open(shoes, box.Id, type(r) == 'number' and r or rng:NextNumber())
	assert(id, 'no roll for ' .. box.Id)
	local shoe = Shoes.ById[id]
	local info = {
		Box = box.Id, Shoe = id, Rarity = shoe.Rarity, New = fresh, Count = ShoeRules.copies(shoes, id), Equipped = #shoes.Equipped > before,
	}
	-- (from here on nothing may undo the grant: the attributes and messages can't fail it, even for a player who left)
	pcall(ShoeOpening.sync, player, profile)
	if player.Parent == Players then
		pcall(function() Net.get('ShoeOpened'):FireClient(player, info) end)
		-- Legendary and up are news for the whole server, like big stage clears.
		if shoe.Rank >= 4 then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					pcall(function() Net.get('Notice'):FireClient(other, player.DisplayName .. ' unboxed ' .. shoe.Name .. ' (' .. shoe.Rarity .. ')!') end)
				end
			end
		end
	end
	return id, info
end

return ShoeOpening
