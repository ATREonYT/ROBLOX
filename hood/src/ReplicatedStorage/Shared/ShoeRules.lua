--!strict
-- Shoe boxes and shoes (the game's eggs and pets): pure rules over a profile's Shoes table, so ShoeService (which
-- enforces them), Shoes.client (which only labels and paints with them) and the unit tests all agree. No Instances.
--
--   Shoes table (saved in the profile): { Owned = { [shoeId] = copies }, Equipped = { shoeId, ... }, Opened = n }
--     Owned     how many pairs of each shoe you have (whole numbers >= 1; 0 is never stored)
--     Equipped  up to MaxEquipped ids, each no more often than you own it (two copies of a shoe can both be on)
--     Opened    boxes opened ever (the goal chain's "Open a shoe box")
--   Opening a box: stand within Range of its BoxPoint, pay its Price, have room in the rack (MaxOwned pairs); one
--   uniform roll picks the rarity by weight (Config.Shoes.Rarities) and so the shoe (each box has one per rarity).
--   Bonus: every equipped pair adds its Bonus percent; the total multiplies the Power each shot pays (ShotRules.pay's
--   shoe multiplier, 1 + total / 100). The best equipped pair (highest Bonus) is the one worn; the others follow.
local Shoes = require(script.Parent.Config.Shoes)

local ShoeRules = {}
ShoeRules.Range = 12 -- studs from your HumanoidRootPart to a box's BoxPoint for an open to count
ShoeRules.MaxEquipped = Shoes.MaxEquipped
ShoeRules.MaxOwned = Shoes.MaxOwned
ShoeRules.MaxCopies = 999 -- sanity cap per shoe in a save
ShoeRules.OpenBurst = 1 -- opens the server lets through at once
ShoeRules.OpenPerSecond = 0.8 -- and the rate it refills at (one open every 1.25 s: the unboxing moment's length)
ShoeRules.ActionBurst = 6 -- equip / unequip / equip best / recycle requests at once
ShoeRules.ActionPerSecond = 4
ShoeRules.RecycleShare = 0.1 -- recycling a spare pair gives back this share of its box's price
ShoeRules.Actions = { Equip = true, Unequip = true, EquipBest = true, Recycle = true }

local function int(v: any): number?
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge or v % 1 ~= 0 then return nil end
	return v
end

function ShoeRules.new()
	return { Owned = {}, Equipped = {}, Opened = 0 }
end

-- Makes a Shoes table safe to use in place (unknown ids dropped, counts whole and capped, Equipped only what you
-- own, at most MaxEquipped, Opened a whole number). Returns the same table, or a new one for a non-table.
function ShoeRules.sanitize(shoes: any)
	if type(shoes) ~= 'table' then return ShoeRules.new() end
	local owned = type(shoes.Owned) == 'table' and shoes.Owned or {}
	local clean = {}
	for id, n in owned do
		local count = int(n)
		if type(id) == 'string' and Shoes.ById[id] and count and count >= 1 then clean[id] = math.min(count, ShoeRules.MaxCopies) end
	end
	local equipped, used = {}, {}
	if type(shoes.Equipped) == 'table' then
		for i = 1, #shoes.Equipped do
			local id = shoes.Equipped[i]
			if #equipped >= ShoeRules.MaxEquipped then break end
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
-- The shoe a uniform roll r in [0, 1) gives from a box (nil for an unknown box), and its rarity.
function ShoeRules.roll(boxId: any, r: any): (string?, string?)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return nil, nil end
	local x = (type(r) == 'number' and r == r) and math.clamp(r, 0, 0.999999999) or 0
	local pick = x * Shoes.TotalWeight
	local acc = 0
	for rank, rarity in Shoes.Rarities do
		acc += rarity.Weight
		if pick < acc then return box.Shoes[rank], rarity.Id end
	end
	return box.Shoes[1], Shoes.Rarities[1].Id
end

-- A box's six shoes with their chances (percent), Common first: { { Id, Rarity, Chance } }.
function ShoeRules.chances(boxId: any)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	local list = {}
	if not box then return list end
	for rank, id in box.Shoes do
		local rarity = Shoes.Rarities[rank]
		table.insert(list, { Id = id, Rarity = rarity.Id, Chance = rarity.Chance })
	end
	return list
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

-- Can this player open box `boxId` now? true, or false and why: 'unknown' (no such box), 'far' (not at the box),
-- 'cash' (can't afford it), 'full' (the rack holds MaxOwned pairs).
function ShoeRules.canOpen(shoes, cash: any, boxId: any, distance: any): (boolean, string?)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return false, 'unknown' end
	if not near(distance) then return false, 'far' end
	if type(cash) ~= 'number' or cash ~= cash or cash < box.Price then return false, 'cash' end
	if ShoeRules.count(shoes) >= ShoeRules.MaxOwned then return false, 'full' end
	return true, nil
end

-- Adds the shoe roll r gives to the rack (call after canOpen; the caller takes the Cash). Returns the shoe id and
-- whether it is a new one for you. While a slot is free the new pair goes straight on.
function ShoeRules.open(shoes, boxId: string, r: number): (string?, boolean)
	local id = ShoeRules.roll(boxId, r)
	if not id then return nil, false end
	local fresh = ShoeRules.copies(shoes, id) == 0
	shoes.Owned[id] = math.min(ShoeRules.copies(shoes, id) + 1, ShoeRules.MaxCopies)
	shoes.Opened = math.min(shoes.Opened + 1, 1e9)
	if #shoes.Equipped < ShoeRules.MaxEquipped then table.insert(shoes.Equipped, id) end
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
-- copy you own is already on), 'full' (MaxEquipped pairs are on: take one off first).
function ShoeRules.canEquip(shoes, id: any): (boolean, string?)
	if type(id) ~= 'string' or not Shoes.ById[id] then return false, 'unknown' end
	local copies = ShoeRules.copies(shoes, id)
	if copies == 0 then return false, 'locked' end
	if ShoeRules.equippedCount(shoes, id) >= copies then return false, 'all' end
	if #shoes.Equipped >= ShoeRules.MaxEquipped then return false, 'full' end
	return true, nil
end

function ShoeRules.equip(shoes, id: any): (boolean, string?)
	local ok, why = ShoeRules.canEquip(shoes, id)
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

-- The best MaxEquipped pairs you own (copies count: three of one shoe can all be on).
function ShoeRules.best(shoes): { string }
	local ids = {}
	for id in shoes.Owned do table.insert(ids, id) end
	table.sort(ids, ShoeRules.before)
	local list = {}
	for _, id in ids do
		for _ = 1, shoes.Owned[id] do
			if #list >= ShoeRules.MaxEquipped then return list end
			table.insert(list, id)
		end
	end
	return list
end

-- Puts the best pairs on. Returns whether anything changed.
function ShoeRules.equipBest(shoes): boolean
	local before = ShoeRules.equippedList(shoes)
	local best = ShoeRules.best(shoes)
	shoes.Equipped = best
	if #before ~= #best then return true end
	for i, id in best do
		if before[i] ~= id then return true end
	end
	return false
end

---------------------------------------------------------------------------------------------- recycling
-- Cash a recycled pair of `id` gives back (a tenth of its box's price, at least 1).
function ShoeRules.refund(id: any): number
	local shoe = type(id) == 'string' and Shoes.ById[id]
	local box = shoe and Shoes.BoxById[shoe.Box]
	if not box then return 0 end
	return math.max(1, math.floor(box.Price * ShoeRules.RecycleShare))
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
