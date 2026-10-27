-- The doors between worlds (Oct 27, World 2: each world is its own place in the experience; Config/Worlds). Any model
-- in the map named World<N>Portal (World 1's lobby has World2Portal; the Business District's has World1Portal) gets a prompt.
-- Travelling is checked here: a known world with a place id, unlocked (World 2: World 1's boss yard beaten once,
-- Shared/WorldInfo), a rate limit, a loaded profile. The profile is released before the trip so the next place loads
-- it straight away (ProfileStore's session lock). Until the owner adds the place (PlaceId 0) the door says "coming soon".
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TeleportService = game:GetService('TeleportService')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local WorldInfo = require(RS.Shared.WorldInfo)
local RateLimiter = require(script.Parent.RateLimiter)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end

local limit = RateLimiter.new(1, 0.2) -- one try, then one every 5 s
-- (Oct 27) In a published server, say in Output which world has no place id yet (RELEASE.md: both worlds' ids go in
-- Config/Worlds), since its door says "coming soon" until then.
if game.PlaceId > 0 then
	for id = 1, 9 do
		local w = WorldInfo.get(id)
		if not w then break end
		if type(w.PlaceId) ~= 'number' or w.PlaceId <= 0 then
			warn(('[WorldPortalService] Config/Worlds has no PlaceId for World %d (%s): its door says "coming soon". This place is %d.'):format(id, tostring(w.Name), game.PlaceId))
		end
	end
end
local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

local function travel(player, world)
	if not limit.allow(player) then return end
	local w = WorldInfo.get(world)
	local profile = Data.get(player)
	if not w or not profile then return end
	if world == WorldInfo.current() then return end
	if not WorldInfo.unlocked(profile.Data, world) then
		notice(player, 'Beat the final boss to open ' .. w.Name .. '!')
		return
	end
	if type(w.PlaceId) ~= 'number' or w.PlaceId <= 0 then
		notice(player, w.Name .. ' is coming soon!')
		return
	end
	notice(player, 'Off to ' .. w.Name .. '!')
	Data.release(player)
	local ok, err = pcall(function()
		local options = Instance.new('TeleportOptions')
		TeleportService:TeleportAsync(w.PlaceId, { player }, options)
	end)
	if not ok then
		warn('[WorldPortalService] ' .. tostring(err))
		player:Kick('The trip to ' .. w.Name .. ' failed. Join again and your progress is safe.')
	end
end

local function hook(model: Instance)
	local world = tonumber(string.match(model.Name, '^World(%d+)Portal$'))
	if not world or not WorldInfo.get(world) then return end
	local part = model:FindFirstChild('World' .. world .. 'Door', true) or model:FindFirstChildWhichIsA('BasePart', true)
	if not part or part:FindFirstChildOfClass('ProximityPrompt') then return end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'WorldPrompt'
	prompt.ActionText = 'Travel'
	prompt.ObjectText = WorldInfo.get(world).Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(travel, player, world)
		if not ok then warn('[WorldPortalService] ' .. tostring(err)) end
	end)
end

for _, d in active.Root:GetDescendants() do
	if d:IsA('Model') then hook(d) end
end
