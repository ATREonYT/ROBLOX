--!strict
-- Per-world progress in one saved profile (Oct 27, World 2: each world is its own place sharing the profile).
-- Power, Cash, rebirths, guns and shoes carry over; a world's own progress (Waves: the best crew beaten, Goals: the goal
-- chain's step, ClearedWalls: the gates passed) does not. The top-level fields always belong to data.CurrentWorld; the
-- other worlds' sets wait in data.Worlds['W<id>']. Loading in another world swaps them (enter), so a saved profile is
-- always consistent whichever place saved it. A first visit's goals start unsynced (GoalRules.advance skips, unpaid,
-- the goals already met: the lanes and guns you bring along). Pure: ProfileSchema.migrate calls it with Shared/WorldInfo.current().
local WorldData = {}
WorldData.Keys = { 'Waves', 'Goals', 'ClearedWalls' }

local function fresh()
	local okG, GoalRules = pcall(function() return require(game:GetService('ReplicatedStorage').Shared.GoalRules) end)
	return { Waves = { Cleared = 0 }, Goals = { Step = 1, Synced = false, Chain = okG and GoalRules.Chain or 1 }, ClearedWalls = {} }
end

function WorldData.enter(data: any, world: number)
	if type(data) ~= 'table' then return data end
	if type(data.Worlds) ~= 'table' then data.Worlds = {} end
	local current = type(data.CurrentWorld) == 'number' and data.CurrentWorld % 1 == 0 and data.CurrentWorld >= 1 and data.CurrentWorld or 1
	if current ~= world then
		local out = {}
		for _, k in WorldData.Keys do out[k] = data[k] end
		data.Worlds['W' .. current] = out
		local saved = data.Worlds['W' .. world]
		local base = fresh()
		for _, k in WorldData.Keys do
			data[k] = type(saved) == 'table' and type(saved[k]) == 'table' and saved[k] or base[k]
		end
		data.Worlds['W' .. world] = nil
	end
	data.CurrentWorld = world
	return data
end

return WorldData
