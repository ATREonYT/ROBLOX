-- Which built map the game runs on. The server and every client use this, so they always agree.
--   The Block V2 when it is built and switched on (TheBlockV2.SetActive(true), which Build does),
--   otherwise the original Block with its SimulatorLobby.
-- Lobby is the container that holds Training_<Id> stations, Morphs and Leaderboards (searched recursively).
-- Frame is the map's own frame: training zones and player positions are compared in it.
local ActiveMap = {}

local function resolve()
	local v2 = workspace:FindFirstChild('TheBlockV2')
	if v2 and v2:GetAttribute('Active') then
		return { Id = 'V2', Root = v2, Lobby = v2, Frame = v2:GetAttribute('Origin') and CFrame.new(v2:GetAttribute('Origin')) or CFrame.new() }
	end
	local block = workspace:FindFirstChild('TheBlock')
	local lobby = block and block:FindFirstChild('SimulatorLobby')
	if lobby then
		local yawValue = block:FindFirstChild('MapYawValue')
		local yaw = block:GetAttribute('MapYaw') or (yawValue and yawValue.Value) or 0
		return { Id = 'Block', Root = block, Lobby = lobby, Frame = CFrame.Angles(0, yaw, 0) }
	end
	return nil
end

function ActiveMap.get() return resolve() end

-- Waits up to `timeout` seconds (default 20) for a map to exist; nil if none appears.
function ActiveMap.wait(timeout)
	local started = os.clock()
	repeat
		local m = resolve()
		if m then return m end
		task.wait(0.25)
	until os.clock() - started > (timeout or 20)
	return nil
end

-- Recursive lookup that keeps retrying, for clients where parts stream in over time.
function ActiveMap.find(container, name, timeout)
	local started = os.clock()
	repeat
		local found = container:FindFirstChild(name, true)
		if found then return found end
		task.wait(0.25)
	until os.clock() - started > (timeout or 10)
	return nil
end

return ActiveMap
