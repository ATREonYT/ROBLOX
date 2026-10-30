-- The one place the server opens a shoe box (brief 21). A ModuleScript, so both ways of opening a box share it:
--   * ShoeService (the OpenShoeBox remote): a Cash box, after ShoeRules.canOpen and taking the Cash;
--   * StoreService (a developer-product receipt): a Robux box (ShoeRules.canGrant), paid in Robux; brief 22: also
--     Buy 3 / Buy 8 (openMany).
-- Either way the pairs are rolled here with the server's Random, added to the profile, the player's shoe attributes
-- are synced, the client gets ONE ShoeOpened (Shoes.client plays the same unboxing moment for both; a batch gets the
-- multi reveal) and a Legendary or better pair is news for the whole server.
--   ShoeOpening.sync(player, profile)            the shoe attributes from the profile (ShoeService documents them)
--   ShoeOpening.slots(player) / .lucky(player)    the +1 Shoe Slot and luck passes (Pass_* attributes, set by
--                                                StoreService on the server: a client can't fake them)
--   ShoeOpening.open(player, profile, boxId, r?) -> shoeId, info          one pair (r: a fixed roll in [0, 1) for tests)
--   ShoeOpening.shield(player, seconds?) / .unshield(player) / .shielded(player) / .sweep(now?)
--       (brief 28c) the opening plays where the player stands, so they are kept safe: every ShoeOpened puts an invisible
--       ForceField ('UnboxShield') on their character until the client says the moment is over (the UnboxDone remote,
--       ShoeService), the character dies or respawns, the player leaves, or ShieldSeconds (15) pass, whichever is first.
--       WaveService's punches already miss a character wearing a ForceField; Humanoid:TakeDamage does too.
--   ShoeOpening.openMany(player, profile, boxId, n, opts?) -> { shoeId }, info
--       n pairs (1..MaxBatch) from one box. opts.Rolls = { r, ... } fixes the rolls (tests); opts.Product = the
--       developer-product key, passed on to the client. A Lucky owner rolls a Cash box with the Lucky odds
--       (ShoeRules.weights; a Robux box never changes). Every roll is made before the profile changes, then all n
--       pairs go in at once; nothing after that can fail and nothing yields, so a receipt's grant and its purchase id
--       go into the same save. No rack check: a paid box is always given (the rack may pass MaxOwned). The caller
--       pushes the profile (Data.push) and checks whether the box may be opened at all.
-- (brief 30, PITY) The visible guarantee (Shared/PityRules; the counters are the profile's Pity.Boxes, one per box): every
-- open without Epic+ counts up that box's counter, the open at the threshold (PityRules.Boxes: 10 Cash boxes, 8 Robux
-- boxes) rolls among the box's Epic+ entries by their own relative weights, and Epic+ (natural or guaranteed) resets it. A
-- batch counts its opens in order, one by one, so the 2nd of a x3 can be the guaranteed one. Every open is a pity open,
-- whichever way it was paid (Cash, a receipt, a won box, the welcome gift). The ShoePity attribute (sync) shows the counters.
-- ShoeOpened payload (agreed with UI4, brief 22): { Box, Shoe, Rarity, New, Count, Equipped } as always (on a batch:
-- the best pair of it, so an older client still plays one normal reveal), plus
--   Shoes    every pair in roll order: { { Shoe, Rarity, New, Count, Equipped } } (one entry on a single open)
--            New = the first pair of that shoe ever (in a batch only the first of duplicates), Count = copies right
--            after that roll, Equipped = it went straight onto a free slot
--   Buy      #Shoes (1, 3 or 8)
--   Best     the index in Shoes the top-level fields describe
--   Product  the developer-product key of a Robux open ('ShoeBoxGrail8'), nil for a Cash open
--   Guaranteed  (brief 30) true on an open that was the guaranteed Epic+ one (per entry of Shoes, and on the top-level
--            fields for the pair they describe); the reveal shows a GUARANTEED! tag
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local Shoes = require(RS.Shared.Config.Shoes)
local ShoeRules = require(RS.Shared.ShoeRules)
local Pity = require(RS.Shared.PityRules)

local ShoeOpening = {}
ShoeOpening.MaxBatch = 10 -- the most pairs one open may give (the Store sells 1, 3 and 8)
ShoeOpening.ShieldSeconds = 15 -- (the longest opening, a Secret batch, is 14 s)
local rng = Random.new()

-- the opener's shield: player -> { field, expires (os.clock), character, died, respawn }
local shields = {}
function ShoeOpening.unshield(player)
	local s = shields[player]
	shields[player] = nil
	if not s then return end
	for _, c in { s.died, s.respawn } do pcall(function() c:Disconnect() end) end
	if s.field then s.field:Destroy() end
end
function ShoeOpening.shielded(player)
	local s = shields[player]
	return s ~= nil and s.field.Parent ~= nil and s.field.Parent == s.character
end
-- drops every shield past its time (now: os.clock(); tests pass a later one)
function ShoeOpening.sweep(now)
	now = now or os.clock()
	for player, s in shields do
		if s.expires <= now or s.field.Parent ~= s.character then ShoeOpening.unshield(player) end
	end
end
function ShoeOpening.shield(player, seconds)
	seconds = seconds or ShoeOpening.ShieldSeconds
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if not humanoid or humanoid.Health <= 0 then return nil end
	local s = shields[player]
	if not s or s.character ~= character or not s.field.Parent then
		ShoeOpening.unshield(player)
		local field = Instance.new('ForceField')
		field.Name = 'UnboxShield'
		field.Visible = false
		field.Parent = character
		s = { field = field, character = character }
		pcall(function() s.died = humanoid.Died:Connect(function() ShoeOpening.unshield(player) end) end)
		pcall(function() s.respawn = player.CharacterAdded:Connect(function() ShoeOpening.unshield(player) end) end)
		shields[player] = s
	end
	-- (a second opening while shielded keeps the one shield and moves its end)
	s.expires = math.max(s.expires or 0, os.clock() + seconds)
	task.delay(seconds + 0.05, function() ShoeOpening.sweep() end)
	return s.field
end
pcall(function() Players.PlayerRemoving:Connect(function(player) ShoeOpening.unshield(player) end) end)

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
-- Pairs this player may have on: 3, or 4 with the +1 Shoe Slot pass.
function ShoeOpening.slots(player)
	return ShoeRules.slotsFor(player:GetAttribute('Pass_ExtraEquip'))
end
-- This player's luck level for Cash boxes: 1, 2 (2x Luck, Pass_Lucky) or 4 (4x Luck, Pass_Luck4; supersedes 2x).
function ShoeOpening.lucky(player)
	return ShoeRules.luckOf(player)
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
	-- (brief 30) the pity counters the box panel and the odds board show ('Street:3,...'; '' = every counter at 0)
	profile.Data.Pity = Pity.sanitize(profile.Data.Pity)
	set(player, 'ShoePity', Pity.encode(profile.Data.Pity))
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
	-- (brief 30) the pity counter of this box, in order: an open the counter makes due rolls among Epic+ only (and is
	-- flagged Guaranteed); whatever came out then resets or counts up the counter for the next one in the batch.
	local pity = Pity.sanitize(profile.Data.Pity)
	profile.Data.Pity = pity
	local ids, list, best = {}, {}, 1
	for i, r in rolls do
		local before = #shoes.Equipped
		local due = Pity.due(pity, box.Id)
		local id, fresh = ShoeRules.open(shoes, box.Id, r, slots, lucky, due and Pity.minRank() or nil)
		Pity.record(pity, box.Id, Shoes.ById[id].Rank)
		ids[i] = id
		list[i] = { Shoe = id, Rarity = Shoes.ById[id].Rarity, New = fresh, Count = ShoeRules.copies(shoes, id), Equipped = #shoes.Equipped > before, Guaranteed = due }
		if i > 1 and better(id, ids[best]) then best = i end
	end
	-- (from here on nothing may undo the grant: the attributes and messages can't fail it, even for a player who left)
	local top = list[best]
	local info = {
		Box = box.Id, Shoe = top.Shoe, Rarity = top.Rarity, New = top.New, Count = top.Count, Equipped = top.Equipped, Guaranteed = top.Guaranteed, Luck = lucky, -- (Luck: the opener's luck level, for the reveal's odds)
		Shoes = list, Buy = n, Best = best, Product = type(opts.Product) == 'string' and opts.Product or nil,
	}
	pcall(ShoeOpening.sync, player, profile)
	if player.Parent == Players then
		pcall(function() Net.get('ShoeOpened'):FireClient(player, info) end)
		-- (the opening plays where they stand: safe until it is over)
		pcall(ShoeOpening.shield, player)
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
