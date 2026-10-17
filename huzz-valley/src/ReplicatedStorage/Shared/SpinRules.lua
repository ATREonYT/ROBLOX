--!strict
-- Spin the Wheel rules (pure; tests/SpinWheel.spec.luau). The server (HuzzServer/SpinService) runs spin() inside
-- DataService.update; the screen (UI/Screens/SpinWheel) uses the counting and landing maths.
-- Saved fields: Spins (owned), FreeSpinAt (os.time when the next free spin is ready; 0 = ready), SpinPity (spins
-- since the last Legendary), Boosts = { Coins = until, Aura = until } (os.time).
local SpinRules = {}

local SLICE = 45 -- 8 slices

-- How many spins you can use now: the free one (0 or 1) and the ones you own.
function SpinRules.available(data: any, now: number): (number, number)
	local free = if (data.FreeSpinAt or 0) <= now then 1 else 0
	return free, math.max(0, math.floor(data.Spins or 0))
end

-- Seconds until the free spin is ready (0 = ready now).
function SpinRules.freeIn(data: any, now: number): number
	return math.max(0, (data.FreeSpinAt or 0) - now)
end

-- "14m 47s" / "47s".
function SpinRules.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local m, s = seconds // 60, seconds % 60
	return if m > 0 then string.format("%dm %02ds", m, s) else string.format("%ds", s)
end

-- Spins left until the guaranteed Legendary (1 = the next spin is one).
function SpinRules.pityLeft(data: any, after: number): number
	return math.max(1, after - (data.SpinPity or 0))
end

-- x2 while a boost of that kind lasts.
function SpinRules.boost(data: any, kind: string, now: number): number
	local b = data.Boosts
	return if type(b) == "table" and type(b[kind]) == "number" and b[kind] > now then 2 else 1
end

-- What one result gives. Returns the line to show and whether it was a duplicate (turned into coins).
function SpinRules.give(data: any, item: any, now: number, duplicateCoins: number): (string, boolean)
	if item.Kind == "Coins" then
		data.Coins = (data.Coins or 0) + item.Amount
	elseif item.Kind == "Aura" then
		data.Aura = (data.Aura or 0) + item.Amount
	elseif item.Kind == "Boost" then
		data.Boosts = data.Boosts or {}
		local from = math.max(now, data.Boosts[item.Boost] or 0)
		data.Boosts[item.Boost] = from + item.Minutes * 60 -- another boost adds its minutes
	elseif item.Kind == "Knife" then
		data.Cosmetics = data.Cosmetics or {}
		if data.Cosmetics[item.Key] then
			data.Coins = (data.Coins or 0) + duplicateCoins
			return `{item.Name} (owned): {duplicateCoins} Coins`, true
		end
		data.Cosmetics[item.Key] = true
		data.Wear = data.Wear or {}
		if data.Wear.Knife == nil then data.Wear.Knife = item.Key end -- (wear it if no knife is worn)
	end
	return item.Name, false
end

-- Uses `count` spins (the free one first, then owned ones), rolls each with roll(pity) -> (item, newPity), and gives
-- the results. Returns false and why if there aren't enough spins (nothing changes then), else true and
-- { rolls = { { Slot, Key, Name, Rarity, Text, Duplicate } }, usedFree }.
function SpinRules.spin(data: any, wheel: any, count: number, now: number, roll: (number) -> (any, number)): (boolean, any)
	if type(count) ~= "number" or count ~= count or count < 1 or count ~= math.floor(count) then return false, "Pick a spin." end
	local free, owned = SpinRules.available(data, now)
	if free + owned < count then
		local short = count - (free + owned)
		if free + owned == 0 then
			return false, `No spins left. Free spin in {SpinRules.clock(SpinRules.freeIn(data, now))}.`
		end
		return false, `You need {short} more spin{if short == 1 then "" else "s"}.`
	end
	local usedFree = free == 1
	if usedFree then data.FreeSpinAt = now + wheel.FreeEvery end
	data.Spins = owned - (count - (if usedFree then 1 else 0))
	local rolls = {}
	local pity = data.SpinPity or 0
	for _ = 1, count do
		local item
		item, pity = roll(pity)
		local text, dup = SpinRules.give(data, item, now, wheel.Duplicate)
		table.insert(rolls, { Slot = item.Slot, Key = item.Key, Name = item.Name, Rarity = item.Rarity, Text = text, Duplicate = dup })
	end
	data.SpinPity = pity
	return true, { rolls = rolls, usedFree = usedFree }
end

-- The roll the wheel stops on: the rarest one (the first of the rarest), so a multi-spin lands on its best prize.
function SpinRules.best(rolls: { any }, rank: { [string]: number }): number
	local at, top = 1, -1
	for i, r in rolls do
		local k = rank[r.Rarity] or 0
		if k > top then at, top = i, k end
	end
	return at
end

-- The wheel's rotation (degrees, clockwise) that puts slice `slot` under the top pointer, `offset` degrees off its
-- middle (keep |offset| under 22.5), after at least `turns` full turns forward from `current`.
function SpinRules.landRotation(current: number, slot: number, turns: number, offset: number): number
	local want = -(slot - 1) * SLICE - offset -- slice centre at the top
	local base = current + turns * 360
	local diff = (want - base) % 360
	return base + diff
end

-- Which slice is under the pointer at this rotation (1-8).
function SpinRules.slotAt(rotation: number): number
	local a = (-rotation) % 360 -- the wheel angle that sits at the top
	return math.floor(((a + SLICE / 2) % 360) / SLICE) + 1
end

-- Counts slice edges that have passed the pointer (changes by one at each edge: the tick).
function SpinRules.edges(rotation: number): number
	return math.floor((rotation + SLICE / 2) / SLICE)
end

return SpinRules
