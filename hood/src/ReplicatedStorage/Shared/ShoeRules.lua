--!strict
-- Shoe boxes and shoes (the game's eggs and pets): pure rules over a profile's Shoes table, so ShoeService (which
-- enforces them), Shoes.client (which only labels and paints with them) and the unit tests all agree. No Instances.
--
--   Shoes table (saved in the profile): { Owned = { [shoeId] = copies }, Equipped = { shoeId, ... }, Opened = n }
--     Owned     how many pairs of each shoe you have (whole numbers >= 1; 0 is never stored)
--     Equipped  up to MaxEquipped ids (MaxSlots with the +1 Shoe Slot pass), each no more often than you own it (two
--               copies of a shoe can both be on)
--     Opened    boxes opened ever (the goal chain's "Open a shoe box")
--   Opening a Cash box: it belongs to the world this server runs (Config.Shoes.ActiveWorld; later worlds' boxes
--   can't be opened here), stand within Range of its BoxPoint, pay its Price, have room in the rack (MaxOwned pairs);
--   one uniform roll picks a shoe by the box's own Weights (a Cash box: the Rarities' weights, one shoe per rarity; a
--   Robux box: its own odds, Rare..Secret). A Robux box never opens for Cash: its developer-product receipt opens it
--   (canGrant; StoreService -> HoodServer/ShoeOpening), wherever you stand and even with a full rack (it was paid).
--   Bonus: every equipped pair adds its Bonus percent; the total multiplies the Power each shot pays (ShotRules.pay's
--   shoe multiplier, 1 + total / 100). The best equipped pair (highest Bonus) is the one worn; the others follow.
--   Game passes (brief 22; the server reads them from Pass_* attributes and passes them in, default = no pass):
--     +1 Shoe Slot (ExtraEquip)  `slots` = MaxEquipped + ExtraSlots pairs on instead of MaxEquipped (canEquip, equip,
--                                best, equipBest, open take an optional `slots`); a save holds at most MaxSlots
--     Lucky                      `lucky` = Epic and rarer shoes weigh LuckyFactor x in a CASH box's roll (renormalised:
--                                weights, roll, chances take an optional `lucky`); a Robux box's odds never change
--     Triple Open (TripleOpen)   canOpen's optional `count` = 3: three opens at once, 3x the Price and room for 3
local Shoes = require(script.Parent.Config.Shoes)

local ShoeRules = {}
ShoeRules.Range = 12 -- studs from your HumanoidRootPart to a box's BoxPoint for an open to count
ShoeRules.MaxEquipped = Shoes.MaxEquipped -- pairs on without the +1 Shoe Slot pass
ShoeRules.ExtraSlots = 1 -- what the +1 Shoe Slot pass adds
ShoeRules.MaxSlots = ShoeRules.MaxEquipped + ShoeRules.ExtraSlots -- the most pairs any save may have on (ProfileSchema checks it)
ShoeRules.LuckyFactor = 2 -- the Lucky pass: Epic and rarer weigh this much more in a Cash box's roll
ShoeRules.LuckyRank = 3 -- (Epic)
ShoeRules.MaxOwned = Shoes.MaxOwned
ShoeRules.MaxCopies = 999 -- sanity cap per shoe in a save
ShoeRules.OpenBurst = 1 -- opens the server lets through at once
ShoeRules.OpenPerSecond = 0.8 -- and the rate it refills at (one open every 1.25 s: the unboxing moment's length)
ShoeRules.ActionBurst = 6 -- equip / unequip / equip best / recycle requests at once
ShoeRules.ActionPerSecond = 4
ShoeRules.RecycleShare = 0.1 -- recycling a spare pair gives back this share of its box's Value (Cash price)
ShoeRules.Actions = { Equip = true, Unequip = true, EquipBest = true, Recycle = true }

local function int(v: any): number?
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge or v % 1 ~= 0 then return nil end
	return v
end

-- A slot count made safe: a whole number from 1 to MaxSlots (default MaxEquipped).
function ShoeRules.slotsOf(slots: any): number
	local n = int(slots)
	return n and math.clamp(n, 1, ShoeRules.MaxSlots) or ShoeRules.MaxEquipped
end

-- The slots a player has: MaxEquipped, plus ExtraSlots with the +1 Shoe Slot pass.
function ShoeRules.slotsFor(extraEquip: any): number
	return extraEquip == true and ShoeRules.MaxEquipped + ShoeRules.ExtraSlots or ShoeRules.MaxEquipped
end

function ShoeRules.new()
	return { Owned = {}, Equipped = {}, Opened = 0 }
end

-- Makes a Shoes table safe to use in place (unknown ids dropped, counts whole and capped, Equipped only what you
-- own, at most `slots` (default MaxSlots: a save never loses a +1 Shoe Slot owner's 4th pair here; the server trims to
-- the player's own slots once it knows them), Opened a whole number). Returns the same table, or a new one for a
-- non-table.
function ShoeRules.sanitize(shoes: any, slots: number?)
	if type(shoes) ~= 'table' then return ShoeRules.new() end
	local owned = type(shoes.Owned) == 'table' and shoes.Owned or {}
	local clean = {}
	for id, n in owned do
		local count = int(n)
		if type(id) == 'string' and Shoes.ById[id] and count and count >= 1 then clean[id] = math.min(count, ShoeRules.MaxCopies) end
	end
	local cap = ShoeRules.slotsOf(slots or ShoeRules.MaxSlots)
	local equipped, used = {}, {}
	if type(shoes.Equipped) == 'table' then
		for i = 1, #shoes.Equipped do
			local id = shoes.Equipped[i]
			if #equipped >= cap then break end
			if type(id) == 'string' and clean[id] and (used[id] or 0) < clean[id] then
				used[id] = (used[id] or 0) + 1
				table.insert(equipped, id)
			end
		end
	end
	shoes.Owned = clean
	shoes.Equipped = equipped
	local opened = int(shoes.Opened)
	shoes.Opened = opened and math.clamp(opened, 0, 1e9) or 0
	return shoes
end

-- Pairs owned in all.
function ShoeRules.count(shoes): number
	local n = 0
	for _, c in shoes.Owned do n += c end
	return n
end

function ShoeRules.copies(shoes, id: any): number
	return type(id) == 'string' and shoes.Owned[id] or 0
end

function ShoeRules.equippedCount(shoes, id: any): number
	local n = 0
	for _, e in shoes.Equipped do
		if e == id then n += 1 end
	end
	return n
end

---------------------------------------------------------------------------------------------- boxes
-- The roll weights of a box, one per shoe in the Shoes order, and their total (nil for an unknown box). `lucky` (the
-- Lucky pass) makes Epic and rarer weigh LuckyFactor x in a Cash box; a Robux box keeps its published odds.
function ShoeRules.weights(boxId: any, lucky: any): ({ number }?, number)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return nil, 0 end
	local boost = lucky == true and not box.Robux
	local list, total = {}, 0
	for i, id in box.Shoes do
		local w = box.Weights[i]
		if boost and Shoes.ById[id].Rank >= ShoeRules.LuckyRank then w *= ShoeRules.LuckyFactor end
		list[i] = w
		total += w
	end
	return list, total
end

-- The shoe a uniform roll r in [0, 1) gives from a box (nil for an unknown box), and its rarity. The box's weights
-- (ShoeRules.weights; without Lucky they add up to Shoes.TotalWeight) split [0, 1) in the Shoes order, commonest first.
function ShoeRules.roll(boxId: any, r: any, lucky: any): (string?, string?)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return nil, nil end
	local weights, total = ShoeRules.weights(boxId, lucky)
	if not weights then return nil, nil end
	local x = (type(r) == 'number' and r == r) and math.clamp(r, 0, 0.999999999) or 0
	local pick = x * total
	local acc = 0
	for i, id in box.Shoes do
		acc += weights[i]
		if pick < acc then return id, Shoes.ById[id].Rarity end
	end
	local first = box.Shoes[1]
	return first, Shoes.ById[first].Rarity
end

-- A box's shoes with their chances (percent), commonest first: { { Id, Rarity, Chance } } (6 on a Cash box, 5 on a
-- Robux box). With `lucky` (a Lucky pass owner) a Cash box's real, better odds; every odds display passes it.
function ShoeRules.chances(boxId: any, lucky: any)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	local list = {}
	if not box then return list end
	local weights, total = ShoeRules.weights(boxId, lucky)
	if not weights then return list end
	local exact = total == Shoes.TotalWeight
	for i, id in box.Shoes do
		table.insert(list, { Id = id, Rarity = Shoes.ById[id].Rarity, Chance = exact and box.Chances[i] or weights[i] / total * 100 })
	end
	return list
end

-- The chance (percent) a shoe's own box gives it (0 for an unknown id); with `lucky`, a Lucky owner's real chance.
function ShoeRules.chanceOf(id: any, lucky: any): number
	local shoe = type(id) == 'string' and Shoes.ById[id]
	local box = shoe and Shoes.BoxById[shoe.Box]
	local i = box and table.find(box.Shoes, id)
	if not i then return 0 end
	if lucky == true then return ShoeRules.chances(box.Id, true)[i].Chance end
	return box.Chances[i]
end

-- Is this box on show (and openable) in `world` (default: the world this server runs)?
function ShoeRules.inWorld(boxId: any, world: any): boolean
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return false end
	return box.World == (world or Shoes.ActiveWorld)
end

-- "62%", "9.5%", "0.45%", "0.05%".
function ShoeRules.chanceText(chance: number): string
	if chance >= 10 or chance % 1 == 0 then return string.format('%d%%', math.floor(chance + 0.5)) end
	local s = string.format(chance >= 1 and '%.1f' or '%.2f', chance)
	return s .. '%'
end

local function near(distance: any): boolean
	return type(distance) == 'number' and distance == distance and distance >= 0 and distance <= ShoeRules.Range
end

-- Can this player open box `boxId` for Cash now, `count` at once (default 1; 3 with the Triple Open pass, which the
-- caller checks)? true, or false and why: 'unknown' (no such box), 'world' (it belongs to another world than `world`,
-- default the active one), 'robux' (a Robux box: only its receipt opens it), 'far' (not at the box), 'cash' (can't
-- afford count x its Price), 'full' (no room for count more pairs: the rack holds MaxOwned).
function ShoeRules.canOpen(shoes, cash: any, boxId: any, distance: any, world: any, count: any): (boolean, string?)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return false, 'unknown' end
	local n = int(count) or 1
	if n < 1 then return false, 'unknown' end
	if not ShoeRules.inWorld(boxId, world) then return false, 'world' end
	if box.Robux or type(box.Price) ~= 'number' then return false, 'robux' end
	if not near(distance) then return false, 'far' end
	if type(cash) ~= 'number' or cash ~= cash or cash < box.Price * n then return false, 'cash' end
	if ShoeRules.count(shoes) + n > ShoeRules.MaxOwned then return false, 'full' end
	return true, nil
end

-- Can a paid receipt for developer product `key` open a box? The box, or nil and why: 'unknown' (no Robux box for
-- that key). No distance, world or rack check: the Robux were paid, so the pair is always given (the rack may go past
-- MaxOwned; Cash opens wait until you recycle).
function ShoeRules.canGrant(key: any): (any, string?)
	local box = Shoes.boxForProduct(key)
	if not box or not box.Exclusive then return nil, 'unknown' end
	return box, nil
end

-- Adds the shoe roll r gives to the rack (call after canOpen or canGrant; the caller takes the Cash). Returns the shoe
-- id and whether it is a new one for you. While a slot is free (of `slots`, default MaxEquipped) the new pair goes
-- straight on. `lucky`: the Lucky pass's odds (ShoeRules.weights).
function ShoeRules.open(shoes, boxId: string, r: number, slots: number?, lucky: any): (string?, boolean)
	local id = ShoeRules.roll(boxId, r, lucky)
	if not id then return nil, false end
	local fresh = ShoeRules.copies(shoes, id) == 0
	shoes.Owned[id] = math.min(ShoeRules.copies(shoes, id) + 1, ShoeRules.MaxCopies)
	shoes.Opened = math.min(shoes.Opened + 1, 1e9)
	if #shoes.Equipped < ShoeRules.slotsOf(slots) then table.insert(shoes.Equipped, id) end
	return id, fresh
end

---------------------------------------------------------------------------------------------- equipping
-- Best first: higher Bonus, then rarer, then the pricier box, then by id (a stable order everywhere).
function ShoeRules.before(a: string, b: string): boolean
	local x, y = Shoes.ById[a], Shoes.ById[b]
	if not x or not y then return x ~= nil end
	if x.Bonus ~= y.Bonus then return x.Bonus > y.Bonus end
	if x.Rank ~= y.Rank then return x.Rank > y.Rank end
	if x.Tier ~= y.Tier then return x.Tier > y.Tier end
	return x.Id < y.Id
end

-- The equipped ids, best first (a copy).
function ShoeRules.equippedList(shoes): { string }
	local list = table.clone(shoes.Equipped)
	table.sort(list, ShoeRules.before)
	return list
end

-- The pair you wear (the best equipped one) or nil; the others follow you.
function ShoeRules.worn(shoes): string?
	return ShoeRules.equippedList(shoes)[1]
end

-- Can this player equip one more pair of `id`? false reasons: 'unknown', 'locked' (you don't own it), 'all' (every
-- copy you own is already on), 'full' (`slots` pairs are on, default MaxEquipped: take one off first).
function ShoeRules.canEquip(shoes, id: any, slots: number?): (boolean, string?)
	if type(id) ~= 'string' or not Shoes.ById[id] then return false, 'unknown' end
	local copies = ShoeRules.copies(shoes, id)
	if copies == 0 then return false, 'locked' end
	if ShoeRules.equippedCount(shoes, id) >= copies then return false, 'all' end
	if #shoes.Equipped >= ShoeRules.slotsOf(slots) then return false, 'full' end
	return true, nil
end

function ShoeRules.equip(shoes, id: any, slots: number?): (boolean, string?)
	local ok, why = ShoeRules.canEquip(shoes, id, slots)
	if ok then table.insert(shoes.Equipped, id) end
	return ok, why
end

-- Takes one pair of `id` off. false reasons: 'unknown', 'off' (none of it is on).
function ShoeRules.unequip(shoes, id: any): (boolean, string?)
	if type(id) ~= 'string' or not Shoes.ById[id] then return false, 'unknown' end
	local i = table.find(shoes.Equipped, id)
	if not i then return false, 'off' end
	table.remove(shoes.Equipped, i)
	return true, nil
end

-- The best `slots` pairs you own (default MaxEquipped; copies count: three of one shoe can all be on).
function ShoeRules.best(shoes, slots: number?): { string }
	local cap = ShoeRules.slotsOf(slots)
	local ids = {}
	for id in shoes.Owned do table.insert(ids, id) end
	table.sort(ids, ShoeRules.before)
	local list = {}
	for _, id in ids do
		for _ = 1, shoes.Owned[id] do
			if #list >= cap then return list end
			table.insert(list, id)
		end
	end
	return list
end

-- Puts the best pairs on (`slots` of them, default MaxEquipped). Returns whether anything changed.
function ShoeRules.equipBest(shoes, slots: number?): boolean
	local before = ShoeRules.equippedList(shoes)
	local best = ShoeRules.best(shoes, slots)
	shoes.Equipped = best
	if #before ~= #best then return true end
	for i, id in best do
		if before[i] ~= id then return true end
	end
	return false
end

-- Takes pairs off until at most `slots` are on, the weakest first (the +1 Shoe Slot pass gone). Returns whether
-- anything changed.
function ShoeRules.trim(shoes, slots: number?): boolean
	local cap = ShoeRules.slotsOf(slots)
	if #shoes.Equipped <= cap then return false end
	local list = ShoeRules.equippedList(shoes)
	shoes.Equipped = table.move(list, 1, cap, 1, {})
	return true
end

---------------------------------------------------------------------------------------------- recycling
-- Cash a recycled pair of `id` gives back (a tenth of its box's Value: the Cash price, or a Robux box's set value;
-- at least 1).
function ShoeRules.refund(id: any): number
	local shoe = type(id) == 'string' and Shoes.ById[id]
	local box = shoe and Shoes.BoxById[shoe.Box]
	local value = box and (box.Value or box.Price)
	if type(value) ~= 'number' then return 0 end
	return math.max(1, math.floor(value * ShoeRules.RecycleShare))
end

-- Can a spare pair of `id` be recycled? false reasons: 'unknown', 'locked' (none owned), 'equipped' (every copy is on).
function ShoeRules.canRecycle(shoes, id: any): (boolean, string?)
	if type(id) ~= 'string' or not Shoes.ById[id] then return false, 'unknown' end
	local copies = ShoeRules.copies(shoes, id)
	if copies == 0 then return false, 'locked' end
	if ShoeRules.equippedCount(shoes, id) >= copies then return false, 'equipped' end
	return true, nil
end

-- Removes one spare pair; returns the Cash to give back (0 when it can't be recycled).
function ShoeRules.recycle(shoes, id: any): number
	if not ShoeRules.canRecycle(shoes, id) then return 0 end
	local left = shoes.Owned[id] - 1
	shoes.Owned[id] = left > 0 and left or nil
	return ShoeRules.refund(id)
end

---------------------------------------------------------------------------------------------- bonus
-- Total bonus of the equipped pairs (percent).
function ShoeRules.bonus(shoes): number
	local total = 0
	for _, id in shoes.Equipped do total += Shoes.bonus(id) end
	return total
end

-- What the shoes multiply Power per shot by: 1 + bonus / 100.
function ShoeRules.multiplier(shoes): number
	return 1 + ShoeRules.bonus(shoes) / 100
end

-- "+15%" (a shoe or a total).
function ShoeRules.bonusText(percent: number): string
	return '+' .. tostring(math.floor(percent + 0.5)) .. '%'
end

---------------------------------------------------------------------------------------------- attributes
-- The rack as the ShoesOwned attribute: 'Id:copies,...' in the boxes' order (empty string for none).
function ShoeRules.ownedString(shoes): string
	local parts = {}
	for _, shoe in Shoes.List do
		local n = shoes.Owned[shoe.Id]
		if n then table.insert(parts, shoe.Id .. ':' .. n) end
	end
	return table.concat(parts, ',')
end

-- The reverse, for clients: a Shoes table from the ShoesOwned and ShoesEquipped attributes (sanitized).
function ShoeRules.fromAttributes(owned: any, equipped: any, opened: any)
	local shoes = { Owned = {}, Equipped = {}, Opened = type(opened) == 'number' and opened or 0 }
	for id, n in string.gmatch(type(owned) == 'string' and owned or '', '([^,:]+):(%d+)') do shoes.Owned[id] = tonumber(n) end
	for id in string.gmatch(type(equipped) == 'string' and equipped or '', '[^,]+') do table.insert(shoes.Equipped, id) end
	return ShoeRules.sanitize(shoes)
end

return ShoeRules
