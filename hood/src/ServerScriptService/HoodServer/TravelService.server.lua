-- Travel (brief 22; runs, brief 23): the World window's trips (HoodClient/World.client).
-- One remote, Travel(target, world?): World 1's two trips, StageRules.Trips: 'Lobby' (the hall's spawn) and 'Stage1'
-- (just inside the Stage 1 gate: a fresh run). Both end the run you are on (every gate shuts again, the goons come
-- back). The furthest-stage trip is gone: a run is fought from Stage 1. Everything is checked here: a known target,
-- World 1 only (worlds 2-5 aren't built: "coming soon"), a rate limit, a loaded profile and a live character. The trip
-- itself is StageService's teleport (its StageTravel BindableFunction), so where you land and the run's end come from
-- one place (StageRules.travelTarget).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local StageRules = require(RS.Shared.StageRules)
local RateLimiter = require(script.Parent.RateLimiter)

local TARGETS = {}
for _, trip in StageRules.Trips do TARGETS[trip.Target] = true end
local limit = RateLimiter.new(2, 0.5) -- two trips at once, then one every 2 s
local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

-- StageService's teleport (it exists once the map's stage gates are read; nil on a map without them).
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
