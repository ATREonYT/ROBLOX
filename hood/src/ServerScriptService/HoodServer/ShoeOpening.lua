-- The one place the server opens a shoe box (brief 21). A ModuleScript, so both ways of opening a box share it:
--   * ShoeService (the OpenShoeBox remote): a Cash box, after ShoeRules.canOpen and taking the Cash;
--   * StoreService (a developer-product receipt): a Robux box (ShoeRules.canGrant), paid in Robux; brief 22: also
--     Buy 3 / Buy 8 (openMany).
-- Either way the pairs are rolled here with the server's Random, added to the profile, the player's shoe attributes
-- are synced, the client gets ONE ShoeOpened (Shoes.client plays the same unboxing moment for both; a batch gets the
-- multi reveal) and a Legendary or better pair is news for the whole server.
--   ShoeOpening.sync(player, profile)            the shoe attributes from the profile (ShoeService documents them)
--   ShoeOpening.slots(player) / .lucky(player)    the +1 Shoe Slot and Lucky passes (Pass_* attributes, set by
--                                                StoreService on the server: a client can't fake them)
--   ShoeOpening.open(player, profile, boxId, r?) -> shoeId, info          one pair (r: a fixed roll in [0, 1) for tests)
--   ShoeOpening.openMany(player, profile, boxId, n, opts?) -> { shoeId }, info
--       n pairs (1..MaxBatch) from one box. opts.Rolls = { r, ... } fixes the rolls (tests); opts.Product = the
--       developer-product key, passed on to the client. A Lucky owner rolls a Cash box with the Lucky odds
--       (ShoeRules.weights; a Robux box never changes). Every roll is made before the profile changes, then all n
--       pairs go in at once; nothing after that can fail and nothing yields, so a receipt's grant and its purchase id
--       go into the same save. No rack check: a paid box is always given (the rack may pass MaxOwned). The caller
--       pushes the profile (Data.push) and checks whether the box may be opened at all.
-- ShoeOpened payload (agreed with UI4, brief 22): { Box, Shoe, Rarity, New, Count, Equipped } as always (on a batch:
-- the best pair of it, so an older client still plays one normal reveal), plus
--   Shoes    every pair in roll order: { { Shoe, Rarity, New, Count, Equipped } } (one entry on a single open)
--            New = the first pair of that shoe ever (in a batch only the first of duplicates), Count = copies right
--            after that roll, Equipped = it went straight onto a free slot
--   Buy      #Shoes (1, 3 or 8)
--   Best     the index in Shoes the top-level fields describe
--   Product  the developer-product key of a Robux open ('ShoeBoxGrail8'), nil for a Cash open
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local Shoes = require(RS.Shared.Config.Shoes)
local ShoeRules = require(RS.Shared.ShoeRules)

local ShoeOpening = {}
ShoeOpening.MaxBatch = 10 -- the most pairs one open may give (the Store sells 1, 3 and 8)
local rng = Random.new()

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
-- Pairs this player may have on: 3, or 4 with the +1 Shoe Slot pass.
function ShoeOpening.slots(player)
	return ShoeRules.slotsFor(player:GetAttribute('Pass_ExtraEquip'))
end
-- Does this player roll Cash boxes with the Lucky pass's odds?
function ShoeOpening.lucky(player)
	return player:GetAttribute('Pass_Lucky') == true
end

-- (brief 22) A save keeps up to ShoeRules.MaxSlots pairs on; only the player's own `slots` count. The extra one is
-- taken off (the weakest) only once StoreService has finished checking the passes (PassesChecked), so a +1 Shoe Slot
-- owner never loses the 4th pair while the check is still on its way at join.
function ShoeOpening.sync(player, profile)
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local slots = ShoeOpening.slots(player)
	if player:GetAttribute('PassesChecked') == true then ShoeRules.trim(shoes, slots) end
	local list = ShoeRules.equippedList(shoes)
	while #list > slots do table.remove(list) end
	local bonus = 0
	for _, id in list do bonus += Shoes.bonus(id) end
	set(player, 'ShoesEquipped', table.concat(list, ','))
	set(player, 'ShoeWorn', list[1] or '')
	set(player, 'ShoeBonus', bonus)
	set(player, 'ShoeMultiplier', 1 + bonus / 100)
	set(player, 'ShoesMax', slots)
	set(player, 'ShoesOwned', ShoeRules.ownedString(shoes))
	set(player, 'ShoesOpened', shoes.Opened)
end

-- Is pair a better than pair b for the reveal's headline? Rarer, then a bigger bonus (the first rolled keeps a tie).
local function better(a, b)
	local x, y = Shoes.ById[a], Shoes.ById[b]
	if x.Rank ~= y.Rank then return x.Rank > y.Rank end
	return x.Bonus > y.Bonus
end

function ShoeOpening.openMany(player, profile, boxId, n, opts)
	opts = type(opts) == 'table' and opts or {}
	local box = Shoes.BoxById[boxId]
	assert(box, 'unknown box ' .. tostring(boxId))
	assert(type(n) == 'number' and n % 1 == 0 and n >= 1 and n <= ShoeOpening.MaxBatch, 'bad open count ' .. tostring(n))
	local slots, lucky = ShoeOpening.slots(player), ShoeOpening.lucky(player)
	-- every roll first (pure), so nothing can fail once the profile starts to change
	local rolls = {}
	for i = 1, n do
		local r = type(opts.Rolls) == 'table' and opts.Rolls[i]
		if type(r) ~= 'number' or r ~= r then r = rng:NextNumber() end
		assert(ShoeRules.roll(box.Id, r, lucky), 'no roll for ' .. box.Id)
		rolls[i] = r
	end
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local ids, list, best = {}, {}, 1
	for i, r in rolls do
		local before = #shoes.Equipped
		local id, fresh = ShoeRules.open(shoes, box.Id, r, slots, lucky)
		ids[i] = id
		list[i] = { Shoe = id, Rarity = Shoes.ById[id].Rarity, New = fresh, Count = ShoeRules.copies(shoes, id), Equipped = #shoes.Equipped > before }
		if i > 1 and better(id, ids[best]) then best = i end
	end
	-- (from here on nothing may undo the grant: the attributes and messages can't fail it, even for a player who left)
	local top = list[best]
	local info = {
		Box = box.Id, Shoe = top.Shoe, Rarity = top.Rarity, New = top.New, Count = top.Count, Equipped = top.Equipped,
		Shoes = list, Buy = n, Best = best, Product = type(opts.Product) == 'string' and opts.Product or nil,
	}
	pcall(ShoeOpening.sync, player, profile)
	if player.Parent == Players then
		pcall(function() Net.get('ShoeOpened'):FireClient(player, info) end)
		-- Legendary and up are news for the whole server, like big stage clears (one line for a batch: its best pair).
		local shoe = Shoes.ById[top.Shoe]
		if shoe.Rank >= 4 then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					pcall(function() Net.get('Notice'):FireClient(other, player.DisplayName .. ' unboxed ' .. shoe.Name .. ' (' .. shoe.Rarity .. ')!') end)
				end
			end
		end
	end
	return ids, info
end

function ShoeOpening.open(player, profile, boxId, r)
	local ids, info = ShoeOpening.openMany(player, profile, boxId, 1, { Rolls = { r } })
	return ids[1], info
end

return ShoeOpening
