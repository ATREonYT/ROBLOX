--!strict
-- Crate maths (pure; tests/CrateRoll.spec.luau). The server rolls with it; the UI shows CrateRoll.odds.
-- Pity: after crate.Pity.After opens in a row without its Pity.Rarity (or better), the next open is guaranteed one.
local CrateRoll = {}

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
CrateRoll.RANK = RANK

local function rank(r: string): number
	return RANK[r] or 0
end

-- Each item with its chance in percent, as shown to the player (weights / total).
function CrateRoll.odds(crate: any): { { item: any, chance: number } }
	local total = 0
	for _, it in crate.Items do total += it.Weight end
	local out = {}
	for _, it in crate.Items do
		table.insert(out, { item = it, chance = if total > 0 then it.Weight / total * 100 else 0 })
	end
	return out
end

local function weighted(items: { any }, rand: () -> number): any
	local total = 0
	for _, it in items do total += it.Weight end
	local x = rand() * total
	for _, it in items do
		x -= it.Weight
		if x < 0 then return it end
	end
	return items[#items]
end

-- rand() returns [0, 1). Returns the item and the new pity count (opens since the last top prize).
function CrateRoll.roll(crate: any, pity: number, rand: () -> number): (any, number)
	local P = crate.Pity
	local top = if P then rank(P.Rarity) else math.huge
	local pool = crate.Items
	if P and pity + 1 >= P.After then
		local best = {}
		for _, it in crate.Items do
			if rank(it.Rarity) >= top then table.insert(best, it) end
		end
		if #best > 0 then pool = best end
	end
	local item = weighted(pool, rand)
	local nextPity = if rank(item.Rarity) >= top then 0 else pity + 1
	return item, nextPity
end

return CrateRoll
