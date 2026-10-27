-- A table keyed by Instances (GUI objects, parts, models, characters) that keeps each entry while its instance lives and
-- drops it when the instance is destroyed. Use it wherever a script remembers something per instance.
-- Why not a weak table ({ __mode = 'k' }): Roblox can collect an instance's Lua handle while the instance itself still
-- exists, and a weak-keyed entry then vanishes at random. The owner's Huzz Valley shipped that bug (Oct 19); here it
-- would double tweens, stack hit-flash Highlights toward Roblox's 255 limit, or lose what a character wore.
-- Reads and writes are plain table ones (map[inst] = v, map[inst]); entries may also be cleared by hand (map[inst] = nil).
-- Keys that aren't instances are stored as in any table. (pcall: the offline preview's instances have no signals, so
-- there the entries simply stay until cleared.)
local InstanceMap = {}

function InstanceMap.new()
	local watching = {}
	local map = {}
	return setmetatable(map, {
		__newindex = function(t, k, v)
			rawset(t, k, v)
			if v == nil or watching[k] or typeof(k) ~= 'Instance' then return end
			local ok, conn = pcall(function()
				return k.Destroying:Connect(function()
					rawset(t, k, nil)
					local c = watching[k]
					watching[k] = nil
					if c then c:Disconnect() end
				end)
			end)
			if ok then watching[k] = conn end
		end,
	})
end

return InstanceMap
