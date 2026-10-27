--!strict
-- Which world this server is (Config/Worlds; each world is its own place running these scripts). The map's Build sets
-- the workspace attribute HoodWorld in the place it builds; no attribute (World 1's place, the offline tests) is 1.
--   WorldInfo.current()      1 or 2 ...
--   WorldInfo.get(id)        that world's Config/Worlds entry, or nil
--   WorldInfo.beaten(profileData, id)    the best crew stage beaten in that world
--   WorldInfo.unlocked(profileData, id)  true once the stage that unlocks world id was beaten (World 1 is always open)
local Worlds = require(script.Parent.Config.Worlds)
local WorldInfo = {}

function WorldInfo.current(): number
	local ok, v = pcall(function() return workspace:GetAttribute('HoodWorld') end)
	if ok and type(v) == 'number' and v % 1 == 0 and Worlds[v] then return v end
	return 1
end

function WorldInfo.get(id: any): any
	return type(id) == 'number' and Worlds[id] or nil
end

-- The best crew stage beaten in world id (the profile's top-level Waves while you are in it, else the saved set in
-- data.Worlds: HoodServer/WorldData).
function WorldInfo.beaten(data: any, id: any): number
	if type(data) ~= 'table' or type(id) ~= 'number' then return 0 end
	local set
	if (data.CurrentWorld or 1) == id then set = data else set = type(data.Worlds) == 'table' and data.Worlds['W' .. id] end
	local cleared = type(set) == 'table' and type(set.Waves) == 'table' and set.Waves.Cleared
	return type(cleared) == 'number' and cleared or 0
end

function WorldInfo.unlocked(data: any, id: any): boolean
	local w = WorldInfo.get(id)
	if not w then return false end
	local need = w.UnlockedBy
	if not need then return true end
	return WorldInfo.beaten(data, need.World) >= need.Stage
end

return WorldInfo
