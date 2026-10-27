-- The Store's Codes box (brief 27): the RedeemCode remote (a RemoteFunction: the Store waits for the answer and shows it
-- on the box). The list and the rules are HoodServer/Codes (server only); this checks the call and saves the gift:
--   * the text must be a string; Codes.normalize refuses anything long or odd without a lookup
--   * a rate limit per player (Codes.Burst tries, then Codes.PerSecond)
--   * a loaded profile; each code once per player (the profile's Codes table, saved with the gift in the same profile)
--   * Cash goes on the profile and the Cash attribute; a boost joins HoodServer/Boosts' queue (StoreService publishes
--     the boost attributes every second)
-- The answer is always { Ok = boolean, Text = a short kid-safe line }; nothing here can error back to the client.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local Boosts = require(script.Parent.Boosts)
local Codes = require(script.Parent.Codes)
local Net = require(RS.Shared.Net)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end -- (Bootstrap made the remotes)

local limit = RateLimiter.new(Codes.Burst, Codes.PerSecond)
Players.PlayerRemoving:Connect(function(player) limit.remove(player) end)

local function answer(player, text)
	if not limit.allow(player) then return { Ok = false, Text = Codes.Text.slow } end
	if type(text) ~= 'string' then return { Ok = false, Text = Codes.Text.empty } end
	if #text > 64 then return { Ok = false, Text = Codes.Text.unknown } end
	local profile = Data.get(player)
	if not profile then return { Ok = false, Text = Codes.Text.loading } end
	local ok, line, change = Codes.redeem(profile.Data, text, os.time(), Boosts.add)
	if ok and change and change.Cash then player:SetAttribute('Cash', profile.Data.Cash) end
	if ok then Data.push(player) end
	return { Ok = ok, Text = line }
end

local function invoked(player, text)
	local ok, result = pcall(answer, player, text)
	if ok and type(result) == 'table' then return result end
	warn('[CodesService] ' .. tostring(result))
	return { Ok = false, Text = Codes.Text.busy }
end
local okHook, why = pcall(function() Net.get('RedeemCode').OnServerInvoke = invoked end)
if not okHook then warn('[CodesService] no RedeemCode remote: ' .. tostring(why)) end -- (an offline harness has no RemoteFunction callbacks)
