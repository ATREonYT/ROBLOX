-- Travel (brief 22): the World window's trips (HoodClient/World.client).
-- One remote, Travel(target, world?): target 'Lobby' (the hall's spawn) or 'Furthest' (just past the furthest stage
-- gate you have cleared): the same two places World 1's LOBBY and FURTHEST pads send you. Everything is checked here:
-- a known target, World 1 only (worlds 2-5 aren't built: "coming soon"), a rate limit, a loaded profile and a live
-- character. The trip itself is StageService's own pad teleport (its StageTravel BindableFunction), so where you land
-- and what is unlocked come from one rule, StageRules.travelTarget: a 'Furthest' trip before any cleared stage is
-- refused there with the pad's own notice.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)

local TARGETS = { Lobby = true, Furthest = true }
local limit = RateLimiter.new(2, 0.5) -- two trips at once, then one every 2 s
local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

-- StageService's pad teleport (it exists once the map's stage gates are read; nil on a map without them).
local function stageTravel()
	local stage = script.Parent:FindFirstChild('StageService')
	local fn = stage and stage:FindFirstChild('StageTravel')
	return fn and fn:IsA('BindableFunction') and fn or nil
end

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end

Net.get('Travel').OnServerEvent:Connect(function(player, target, world)
	if type(target) ~= 'string' or not TARGETS[target] then return end
	if world ~= nil and world ~= 1 then
		if type(world) == 'number' and world % 1 == 0 and world >= 2 and world <= 5 then notice(player, 'World ' .. world .. ' is coming soon!') end
		return
	end
	if not limit.allow(player) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if not humanoid or humanoid.Health <= 0 then return end
	local travel = stageTravel()
	if not travel then
		notice(player, 'Travel is not open on this map yet.')
		return
	end
	local ok, result = pcall(travel.Invoke, travel, player, target)
	if not ok then warn('[TravelService] ' .. tostring(result)) end
end)

Players.PlayerRemoving:Connect(function(player) limit.remove(player) end)
