--[[
	Picks the game's girl, fairly: first a rarity by its Weight (Config/Round.Rarities; only
	rarities that have girls count), then any girl of that rarity with the same chance.
	The roller strip the players watch is built from the same draw: every name on it is a
	fresh honest pick, so the strip shows the real mix (lots of Commons, a rare Secret)
	with no planted near-misses. Pure Luau (no Roblox calls), tested in tests/GirlRoll.spec.luau.

	catalog: { { id, name, rarity, ... } }, rarities: Config/Round.Rarities,
	rand: function() -> number in [0, 1) (math.random by default).
]]
local GirlRoll = {}

local function groups(catalog, rarities)
	local byName, list, total = {}, {}, 0
	for _, r in rarities do
		byName[r.Name] = r
	end
	for _, girl in catalog do
		local g = list[girl.rarity]
		if not g then
			local r = byName[girl.rarity] or { Name = girl.rarity, Weight = 1 }
			g = { name = r.Name, weight = r.Weight, girls = {} }
			list[girl.rarity] = g
			total += g.weight
		end
		table.insert(g.girls, girl)
	end
	-- In the Rarities order (Common first), so the odds read in order.
	local ordered = {}
	for _, r in rarities do
		if list[r.Name] then
			table.insert(ordered, list[r.Name])
			list[r.Name] = nil
		end
	end
	for _, g in list do
		table.insert(ordered, g)
	end
	return ordered, total
end

-- The real chance of each rarity, in percent: { { name, chance } } in Rarities order.
function GirlRoll.odds(catalog, rarities)
	local ordered, total = groups(catalog, rarities)
	local out = {}
	for _, g in ordered do
		table.insert(out, { name = g.name, chance = if total > 0 then g.weight / total * 100 else 0 })
	end
	return out
end

function GirlRoll.pick(catalog, rarities, rand)
	rand = rand or math.random
	local ordered, total = groups(catalog, rarities)
	if #ordered == 0 then
		return nil
	end
	local roll = rand() * total
	local chosen = ordered[#ordered]
	for _, g in ordered do
		roll -= g.weight
		if roll < 0 then
			chosen = g
			break
		end
	end
	return chosen.girls[math.floor(rand() * #chosen.girls) + 1] or chosen.girls[1]
end

-- The roller strip: `length` honest picks with the winner at position `at`.
function GirlRoll.strip(catalog, rarities, winner, length, at, rand)
	local cells = {}
	for i = 1, length do
		cells[i] = if i == at then winner else GirlRoll.pick(catalog, rarities, rand)
	end
	return cells
end

return GirlRoll
