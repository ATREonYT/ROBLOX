-- Reasons to come back (brief 29, P5). The rules are Shared/RetentionRules, the profile changes HoodServer/Retention; this
-- is the glue:
--   * on a player's first loaded profile: counts the visit and works out the Power earned while away (Pending, up to 8 h)
--   * every 30 s stamps LastSeen (so a closed server still counts the time away)
--   * attributes for the client: DailyReady (a daily reward can be claimed), OfflinePending (Power waiting), RetentionJoins
--     (visits; the daily popup waits for the second one), FriendCount and FriendBoost (+10 % Power per friend here, max
--     +50 %; HoodServer/Boosts.power multiplies it into every shot)
--   * the Retention RemoteFunction: 'State', 'ClaimDaily', 'ClaimOffline', 'ClaimGroup' (the Group reward, once; ServerConfig.
--     GroupId, 0 = off; Player:IsInGroup). The answer is always { Ok, Text, State }.
-- Restore Streak and 2x Offline are Robux products: HoodServer/StoreReceipts grants them.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local Retention = require(script.Parent.Retention)
local RateLimiter = require(script.Parent.RateLimiter)
local ServerConfig = require(script.Parent.ServerConfig)
local Rules = require(RS.Shared.RetentionRules)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end -- (Bootstrap made the remotes)

local limit = RateLimiter.new(6, 2)
local joined = {} -- [player] = true once the visit is counted
local friends = {} -- [player] = { [other] = true | false }
local inGroup = {} -- [player] = true | false (cached)

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end

local function groupOn() return type(ServerConfig.GroupId) == 'number' and ServerConfig.GroupId > 0 end
local function memberOf(player)
	if not groupOn() then return false end
	if inGroup[player] == nil then
		local ok, res = pcall(player.IsInGroup, player, ServerConfig.GroupId)
		if not ok then return false end -- (not cached: ask again next time)
		inGroup[player] = res == true
	end
	return inGroup[player]
end

local function friendCount(player)
	local n = 0
	for other, isFriend in friends[player] or {} do
		if isFriend and other.Parent == Players then n += 1 end
	end
	return n
end
local function checkPairs(player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friends[player][other] == nil then
			friends[player][other] = false -- (placeholder: one lookup per pair)
			task.spawn(function()
				local ok, res = pcall(player.IsFriendsWith, player, other.UserId)
				if player.Parent == Players then friends[player][other] = ok and res == true end
			end)
		end
	end
end

-- Counts this visit once (the first time anything looks at the loaded profile: the loop below or the client's first ask).
local function join(player, profile)
	if joined[player] then return end
	joined[player] = true
	Retention.onJoin(profile, os.time())
end

local function refresh(player)
	local profile = Data.get(player)
	if not profile then return end
	local st = Rules.status(profile.Data, os.time())
	local r = profile.Data.Retention
	set(player, 'DailyReady', st.Ready)
	set(player, 'OfflinePending', r.Pending)
	set(player, 'RetentionJoins', r.Joins)
	local n = friendCount(player)
	set(player, 'FriendCount', n)
	set(player, 'FriendBoost', Rules.friendBoost(n))
end

local function stateOf(player, profile)
	return Retention.state(profile, os.time(), { GroupOn = groupOn(), InGroup = memberOf(player), Friends = friendCount(player) })
end

local function reply(player, profile, ok, text)
	if ok then
		player:SetAttribute('Cash', profile.Data.Cash)
		player:SetAttribute('Power', profile.Data.Rep)
		Data.push(player)
	end
	refresh(player)
	if type(text) == 'string' and text ~= '' then Net.get('Notice'):FireClient(player, text) end
	return { Ok = ok, Text = text, State = stateOf(player, profile) }
end

local function answer(player, action)
	if not limit.allow(player) then return { Ok = false, Text = 'Slow down a little!' } end
	local profile = Data.get(player)
	if not profile then return { Ok = false, Text = 'Still loading...' } end
	join(player, profile)
	local now = os.time()
	if action == 'ClaimDaily' then
		local ok, day, text = Retention.claimDaily(profile, now)
		if not ok then return reply(player, profile, false, 'Come back tomorrow for the next one!') end
		return reply(player, profile, true, 'Day ' .. day .. ': ' .. text)
	elseif action == 'ClaimOffline' then
		local ok, amount = Retention.claimOffline(profile)
		if not ok then return reply(player, profile, false, 'Nothing waiting right now.') end
		return reply(player, profile, true, '+' .. Format.compact(amount) .. ' Power')
	elseif action == 'ClaimGroup' then
		local ok, text = Retention.claimGroup(profile, memberOf(player), now, groupOn())
		if not ok then
			local why = text
			return reply(player, profile, false, why == 'off' and 'The group reward is not open yet.' or why == 'had' and 'You already took it. Thanks for being in the group!' or 'Join the group first, then press Claim.')
		end
		return reply(player, profile, true, 'Group reward: ' .. text)
	end
	return reply(player, profile, true, '')
end
local function invoked(player, action)
	local ok, result = pcall(answer, player, action)
	if ok and type(result) == 'table' then return result end
	warn('[RetentionService] ' .. tostring(result))
	return { Ok = false, Text = 'Something went wrong. Try again.' }
end
local okHook, why = pcall(function() Net.get('Retention').OnServerInvoke = invoked end)
if not okHook then warn('[RetentionService] no Retention remote: ' .. tostring(why)) end

---------------------------------------------------------------------------------------------- players
Players.PlayerRemoving:Connect(function(player)
	limit.remove(player)
	joined[player], friends[player], inGroup[player] = nil, nil, nil
	for _, map in friends do map[player] = nil end
end)

local lastStamp = 0
while true do
	task.wait(1)
	local stamp = os.clock() - lastStamp >= 30
	if stamp then lastStamp = os.clock() end
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			if not joined[player] then
				join(player, profile)
			elseif stamp then
				Retention.touch(profile, os.time())
			end
			if stamp or not friends[player] then checkPairs(player) end
			refresh(player)
		end
	end
end
