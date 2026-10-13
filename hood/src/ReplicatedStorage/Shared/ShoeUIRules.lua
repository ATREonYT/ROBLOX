--!strict
-- ShoeUIRules (brief 30, MOCKUP): the pure rules behind the user's shoe UI mockups (the handoff's "Control rules"), so the
-- screens (Shared/ShoeScreens), the client scripts and the unit tests agree. No Instances. The server stays the
-- authority: these only decide what the UI offers and how it asks (ShoeService / ShoeFavorites re-check everything).
--   inventory(rack, opts)        the cards: search (by display name), sort (Name | Rarity | Power), filter (All, a family,
--                                Equipped, Locked, Favourites); one card a design with its copies
--   canDelete(rack, id)          Delete protection: equipped (every copy on), locked, favourite pairs are never deleted
--   deleteReview(rack, ids)      the review before a Delete: what goes, what is kept and why, the Cash back
--   equipPlan(rack, id, slots)   Equip exactly ONE pair: a free slot takes it, else it swaps out exactly one (the weakest
--                                by the configured bonus); Unequip keeps the pair (ownership never changes)
--   bestBy(rack, slots)          Equip Best compares the configured effect (the bonus), never colour or rarity alone
--   autoStop(info, rack, cash, box)   why Auto Open stops: the rarity threshold, not enough Cash, a full rack
--   collection(rack, family)     the 22 World 1 designs, discovered (ever had) separately from the copies owned now
--   giftReview(key, target)      the review before a gift (never sent without it): what, to whom, the price, or why not
--   bundleArrived(before, after, ids)   the bundle's receipt has landed: each of its pairs went up by one
local Shoes = require(script.Parent.Config.Shoes)
local ShoeRules = require(script.Parent.ShoeRules)

local R = {}

-- Auto Open stops by itself on a pair of this rank or rarer (4 = Legendary): the configured rarity threshold.
R.AutoStopRank = 4
R.Sorts = { 'Name', 'Rarity', 'Power' }
R.Filters = { 'All', 'Street', 'Graffiti', 'Chrome', 'Crown', 'Equipped', 'Locked', 'Favourites' }
-- the families by their display name (brief 30 rule 12: Exclusive is shown as Chrome, Grail as Crown)
R.FamilyBox = { Street = 'Street', Graffiti = 'Graffiti', Chrome = 'Exclusive', Crown = 'Grail' }

local function lower(s: string): string return string.lower(s) end

-- One card per design you own: { Id, Name, Box, Rank, Bonus, Count, On (copies equipped), Locked, Favorite }.
function R.inventory(rack: any, opts: any): { any }
	opts = type(opts) == 'table' and opts or {}
	local query = type(opts.Query) == 'string' and lower(opts.Query) or ''
	local filter = opts.Filter or 'All'
	local sort = opts.Sort or 'Name'
	local out = {}
	for id, n in rack.Owned do
		local s = Shoes.ById[id]
		if s and n >= 1 then
			local on = ShoeRules.equippedCount(rack, id)
			local locked = type(rack.Locked) == 'table' and rack.Locked[id] == true
			local fav = type(rack.Favorites) == 'table' and rack.Favorites[id] == true
			local keep = query == '' or string.find(lower(s.Name), query, 1, true) ~= nil
			if keep and filter ~= 'All' then
				if R.FamilyBox[filter] then keep = s.Box == R.FamilyBox[filter]
				elseif filter == 'Equipped' then keep = on > 0
				elseif filter == 'Locked' then keep = locked
				elseif filter == 'Favourites' then keep = fav end
			end
			if keep then table.insert(out, { Id = id, Name = s.Name, Box = s.Box, Rank = s.Rank, Bonus = s.Bonus, Count = n, On = on, Locked = locked, Favorite = fav }) end
		end
	end
	table.sort(out, function(a, b)
		if sort == 'Rarity' and a.Rank ~= b.Rank then return a.Rank > b.Rank end
		if sort == 'Power' and a.Bonus ~= b.Bonus then return a.Bonus > b.Bonus end
		if sort ~= 'Name' and a.Bonus ~= b.Bonus then return a.Bonus > b.Bonus end
		return a.Name < b.Name
	end)
	return out
end

-- Pairs held / room (the "12 / 100" capacity).
function R.capacity(rack: any): (number, number)
	return ShoeRules.count(rack), ShoeRules.MaxOwned
end

-- Can one pair of `id` be deleted? false and why: 'equipped' (every copy is on), 'lock', 'favorite', 'unknown',
-- 'none' (none owned). The server's Recycle runs the same check (ShoeRules.canRecycle).
function R.canDelete(rack: any, id: any): (boolean, string?)
	local ok, why = ShoeRules.canRecycle(rack, id)
	if why == 'locked' then why = 'none' end
	return ok, why
end

-- The review before a Delete: { Delete = { ids }, Kept = { { Id, Why } }, Cash = refund total }. Each selected design
-- gives up ONE spare pair; protected ones are listed as kept, never deleted.
function R.deleteReview(rack: any, ids: { string }): any
	local out = { Delete = {}, Kept = {}, Cash = 0 }
	local seen = {}
	for _, id in ids do
		if not seen[id] then
			seen[id] = true
			local ok, why = R.canDelete(rack, id)
			if ok then
				table.insert(out.Delete, id)
				out.Cash += ShoeRules.refund(id)
			else
				table.insert(out.Kept, { Id = id, Why = why })
			end
		end
	end
	return out
end

-- The pair Equip Best compares by: the configured bonus (ShoeRules.best).
function R.bestBy(rack: any, slots: number?): { string }
	return ShoeRules.best(rack, slots)
end

-- Equip exactly one pair: { Kind = 'equip' } (a free slot), { Kind = 'swap', Out = id } (every slot is on: exactly one
-- comes off, the weakest by bonus) or { Kind = 'none', Why = 'all' | 'none' | 'unknown' }.
function R.equipPlan(rack: any, id: any, slots: number?): any
	local s = type(id) == 'string' and Shoes.ById[id]
	if not s then return { Kind = 'none', Why = 'unknown' } end
	local copies = ShoeRules.copies(rack, id)
	if copies == 0 then return { Kind = 'none', Why = 'none' } end
	if ShoeRules.equippedCount(rack, id) >= copies then return { Kind = 'none', Why = 'all' } end
	local cap = ShoeRules.slotsOf(slots)
	if #rack.Equipped < cap then return { Kind = 'equip' } end
	local worst, worstBonus = nil, math.huge
	for _, e in rack.Equipped do
		local b = Shoes.bonus(e)
		if b < worstBonus then worst, worstBonus = e, b end
	end
	return { Kind = 'swap', Out = worst }
end

-- Apply an equip plan to a rack table (what the server does with the plan's one or two actions, in order).
function R.applyEquip(rack: any, id: string, slots: number?): boolean
	local plan = R.equipPlan(rack, id, slots)
	if plan.Kind == 'swap' then
		ShoeRules.unequip(rack, plan.Out)
		return (ShoeRules.equip(rack, id, slots))
	elseif plan.Kind == 'equip' then
		return (ShoeRules.equip(rack, id, slots))
	end
	return false
end

-- Why Auto Open stops after this reveal (nil: keep going). info: ShoeOpened's payload; box: the Config box; cash: Cash
-- now. 'rarity' (a pair at the threshold or rarer came out), 'cash' (can't pay the next one), 'full' (no room).
function R.autoStop(info: any, rack: any, cash: any, box: any): string?
	local best = type(info) == 'table' and Shoes.ById[info.Shoe]
	if best and best.Rank >= R.AutoStopRank then return 'rarity' end
	if type(info) == 'table' and type(info.Shoes) == 'table' then
		for _, id in info.Shoes do
			local s = Shoes.ById[id]
			if s and s.Rank >= R.AutoStopRank then return 'rarity' end
		end
	end
	if not box or box.Robux or type(box.Price) ~= 'number' then return 'cash' end
	if type(cash) ~= 'number' or cash < box.Price then return 'cash' end
	if ShoeRules.count(rack) + 1 > ShoeRules.MaxOwned then return 'full' end
	return nil
end

-- The Collection: World 1's designs (the four families, in box order), each { Id, Name, Box, Rank, Discovered (ever had:
-- the ShoesDiscovered set or owned now), Count (owned now) }, for one family (display name) or all.
function R.collection(rack: any, family: string?): { any }
	local out = {}
	local want = family and R.FamilyBox[family]
	for _, box in Shoes.boxesForWorld(1) do
		if not want or box.Id == want then
			for _, id in box.Shoes do
				local s = Shoes.ById[id]
				local count = ShoeRules.copies(rack, id)
				local found = count > 0 or (type(rack.Discovered) == 'table' and rack.Discovered[id] == true)
				table.insert(out, { Id = id, Name = s.Name, Box = box.Id, Rank = s.Rank, Discovered = found, Count = count })
			end
		end
	end
	return out
end
function R.discoveredCount(rack: any): (number, number)
	local all = R.collection(rack, nil)
	local n = 0
	for _, e in all do
		if e.Discovered then n += 1 end
	end
	return n, #all
end

-- The review before a gift: { Ok, Why ('nobody' | 'self' | 'unknown' | 'notgiftable' | 'soon'), Title, Price, To }.
-- products: Config/Products; target: { UserId, Name } or nil; me: the buyer's UserId.
function R.giftReview(products: any, key: any, target: any, me: any): any
	local e = products.ByKey[key]
	if not e then return { Ok = false, Why = 'unknown' } end
	local out = { Ok = false, Title = e.Title, Price = e.Price, Key = key }
	if type(target) ~= 'table' or type(target.UserId) ~= 'number' then out.Why = 'nobody' return out end
	if target.UserId == me then out.Why = 'self' return out end
	out.To = target.Name
	if not products.giftable(key) then out.Why = 'notgiftable' return out end
	local ok = products.canBuy(key)
	if not ok then out.Why = 'soon' return out end
	out.Ok = true
	return out
end

-- Has a bundle's receipt landed? before / after: { [id] = copies } (e.g. two racks' Owned); every id went up by one.
function R.bundleArrived(before: any, after: any, ids: { string }): boolean
	if #ids == 0 then return false end
	for _, id in ids do
		if (after[id] or 0) < (before[id] or 0) + 1 then return false end
	end
	return true
end

-- A daily card's state: 'claimed' | 'ready' | 'locked' (the Daily Rewards state from RetentionService).
function R.dayState(daily: any, day: number): string
	if type(daily) ~= 'table' then return 'locked' end
	if daily.Ready then
		if day < (daily.Day or 1) then return 'claimed' end
		if day == daily.Day then return 'ready' end
		return 'locked'
	end
	return day <= (daily.Claimed or 0) and 'claimed' or 'locked'
end

return R
