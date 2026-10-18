--[[
	The leaderboards' rules, pure (no Instances), so tests/Leaderboards.spec.luau checks them and the place build can
	use them: how a value is written ("LEVEL 402", "2611" + trophy, "33.5K CATCHES" like Huss Valley's boards), the
	order (biggest first, one row per player), each player's numbers from their save, where the boards stand round a
	lobby when the owner hasn't placed any, and the slow turn towards your character (owner: "make them follow
	your character").
]]
local LeaderboardRules = {}

-- 874 -> "874", 33512 -> "33.5K", 231149 -> "231.1K", 2400000 -> "2.4M". Cut down, never rounded up (a board
-- never says more than you have).
function LeaderboardRules.compact(n: number): string
	n = math.max(0, math.floor(n))
	if n < 1000 then return tostring(n) end
	for _, step in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= step[1] then
			local tenths = math.floor(n * 10 / step[1])
			return string.format("%d.%d%s", tenths // 10, tenths % 10, step[2])
		end
	end
	return tostring(n)
end

-- The value text and an optional icon name for one board (Config/Leaderboards row).
function LeaderboardRules.format(def, n: number): (string, string?)
	n = math.max(0, math.floor(n or 0))
	if def.Format == "Level" then
		return "LEVEL " .. (if n < 100000 then tostring(n) else LeaderboardRules.compact(n)), nil
	elseif def.Format == "Trophy" then
		return (if n < 100000 then tostring(n) else LeaderboardRules.compact(n)), "RewardsTrophy"
	end
	local text = LeaderboardRules.compact(n)
	if def.Unit and def.Unit ~= "" then text ..= " " .. def.Unit end
	return text, nil
end

--[[
	One list from several (the saved top 50 and the players in this server): one row per player (their biggest
	value; a known name beats a blank one), biggest first, ties by who got there first in the lists, cut to `top`.
	Entries: { u = userId, n = name, v = value }.
]]
function LeaderboardRules.rank(lists: { { any } }, top: number): { any }
	local best, order = {}, {}
	local seq = 0
	for _, list in lists do
		for _, e in list do
			local u, v = tonumber(e.u), tonumber(e.v)
			if u and v and v >= 0 and u == u and v == v then
				v = math.floor(v)
				local had = best[u]
				if not had then
					seq += 1
					best[u] = { u = u, n = e.n or "", v = v, seq = seq }
					table.insert(order, best[u])
				else
					if v > had.v then had.v = v end
					if (had.n == nil or had.n == "") and e.n and e.n ~= "" then had.n = e.n end
				end
			end
		end
	end
	table.sort(order, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		return a.seq < b.seq
	end)
	local out = {}
	for i = 1, math.min(top, #order) do
		local e = order[i]
		out[i] = { u = e.u, n = e.n, v = e.v }
	end
	return out
end

-- Every board's number for one save (DataService profile.Data). Level comes from XP like Config/Progression.level.
function LeaderboardRules.values(data, xpPerLevel: number): { [string]: number }
	local stats = type(data.Stats) == "table" and data.Stats or {}
	local girls = 0
	if type(data.Characters) == "table" then
		for _ in data.Characters do girls += 1 end
	end
	local xp = tonumber(data.XP) or 0
	return {
		Level = 1 + math.floor(math.max(0, xp) / xpPerLevel),
		Wins = math.floor(tonumber(stats.Wins) or 0),
		Catches = math.floor(tonumber(stats.Catches) or 0),
		Rescues = math.floor(tonumber(stats.Rescues) or 0),
		Girls = girls,
	}
end

--[[
	Where the boards stand when the owner hasn't placed any and his podiums are taken (Shared/LeaderboardLook.layout
	puts the first ones on his grey podiums): along the lobby floor's back edge (the side away from the map, behind
	the spawn), clear of the spin wheel and stand blocks (west), the girl stand (middle) and the podiums (east);
	two go either side of the middle, more go 17 studs apart. Offsets from the floor's centre, in studs.
]]
function LeaderboardRules.defaultSpots(sizeX: number, sizeZ: number, count: number): { { X: number, Z: number } }
	local spots = {}
	if count <= 2 then
		-- one either side of the middle (his BasketBall lobby has a hoop right behind the spawn)
		for i = 1, count do
			table.insert(spots, { X = (if i == 1 then -0.2 else 0.22) * sizeX, Z = sizeZ / 2 - 7 })
		end
		return spots
	end
	local gap = math.min(17, (sizeX - 16) / math.max(1, count - 1))
	for i = 1, count do
		table.insert(spots, { X = (i - (count + 1) / 2) * gap, Z = sizeZ / 2 - 7 })
	end
	return spots
end

-- The yaw (radians, Roblox's: 0 = facing -Z) that makes a board at `fromX, fromZ` face a point.
function LeaderboardRules.yawTo(fromX: number, fromZ: number, toX: number, toZ: number): number
	return math.atan2(-(toX - fromX), -(toZ - fromZ))
end

-- One frame of the slow turn: eases `current` towards `target` the short way round (a little lag, never a snap).
function LeaderboardRules.turn(current: number, target: number, dt: number, rate: number): number
	local d = (target - current + math.pi) % (2 * math.pi) - math.pi
	local k = 1 - math.exp(-rate * math.max(dt, 0))
	local nextYaw = current + d * k
	return (nextYaw + math.pi) % (2 * math.pi) - math.pi
end

return LeaderboardRules
