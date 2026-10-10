-- Rebirths (brief 17; the rules are Shared/RebirthRules). A ModuleScript: Bootstrap starts it, and the store's
-- server script can call RebirthService.rebirth(player, { Free = true }) for a "Skip Rebirth" purchase.
--   Remote Rebirth (client -> server, no arguments, one every RebirthRules.Cooldown seconds): with Power at least
--   RebirthRules.need(Rebirths), Power goes back to 0 and Rebirths goes up by one. Cash, guns, shoes, stage clears
--   (gates you passed stay open: StageRules), cleared waves and goals are all kept. Every shot's Power is multiplied by
--   RebirthRules.multiplier(Rebirths); lanes open at their Rebirths (Config/Skins.Stations); walk speed rises a little.
--   Answers: a Notice, and to that player the remote Cinematic { Kind = 'Rebirth', Rebirths, Multiplier, Unlocked =
--   the lane this rebirth opened (its Name) or nil }.
-- Player attributes (RebirthService.publish; LobbyService calls it with every sync, so they follow Power):
--   Rebirths, RebirthMultiplier, RebirthNextMultiplier, RebirthNeed (Power for the next one), RebirthReady (bool),
--   RebirthUnlock (Name of the lane the next rebirth opens, '' for none).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local Net = require(RS.Shared.Net)
local Format = require(RS.Shared.Format)
local RebirthRules = require(RS.Shared.RebirthRules)

local RebirthService = {}
local limit = RateLimiter.new(1, 1 / RebirthRules.Cooldown)
local started = false

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function notice(player, text)
	Net.get('Notice'):FireClient(player, text)
end

-- The rebirth attributes from a profile's data (and Power, so a rebirth shows at once).
function RebirthService.publish(player, data)
	local n = RebirthRules.count(data.Rebirths)
	local lane = RebirthRules.nextUnlock(n)
	set(player, 'Power', data.Rep)
	set(player, 'Rebirths', n)
	set(player, 'RebirthMultiplier', RebirthRules.multiplier(n))
	set(player, 'RebirthNextMultiplier', RebirthRules.multiplier(n + 1))
	set(player, 'RebirthNeed', RebirthRules.need(n))
	set(player, 'RebirthReady', RebirthRules.canRebirth(data.Rep, n))
	set(player, 'RebirthUnlock', lane and lane.Name or '')
end

-- Rebirths a player now. opts.Free skips the Power check (a paid skip; the caller dedupes its receipts). Returns true,
-- or false and why: 'profile' (not loaded), 'power' (not enough), 'max'.
function RebirthService.rebirth(player, opts)
	local profile = Data.get(player)
	if not profile then return false, 'profile' end
	local data = profile.Data
	local n = RebirthRules.count(data.Rebirths)
	local ok, why = RebirthRules.apply(data, type(opts) == 'table' and opts.Free == true)
	if not ok then return false, why end
	if type(data.Onboarding) == 'table' then data.Onboarding.Rebirthed = true end
	RebirthService.publish(player, data)
	local stats = player:FindFirstChild('leaderstats')
	local power = stats and stats:FindFirstChild('Power')
	if power then power.Value = 0 end
	Data.push(player)
	local lane = RebirthRules.nextUnlock(n) -- (the lane that opens at n + 1)
	local multiplier = RebirthRules.multiplier(n + 1)
	Net.get('Cinematic'):FireClient(player, { Kind = 'Rebirth', Rebirths = n + 1, Multiplier = multiplier, Unlocked = lane and lane.Name or nil })
	notice(player, 'Rebirth ' .. (n + 1) .. '! Every shot pays x' .. multiplier .. (lane and (' and ' .. lane.Name .. ' is open!') or '.'))
	-- Every fifth rebirth is news for the whole server.
	if (n + 1) % 5 == 0 then
		for _, other in Players:GetPlayers() do
			if other ~= player then notice(other, player.DisplayName .. ' reached Rebirth ' .. (n + 1) .. '!') end
		end
	end
	return true, nil
end

function RebirthService.start()
	if started then return end
	started = true
	Net.get('Rebirth').OnServerEvent:Connect(function(player)
		if not limit.allow(player) then return end
		local profile = Data.get(player)
		if not profile then return end
		local ok, why = RebirthService.rebirth(player)
		if not ok and why == 'power' then
			local need = RebirthRules.need(profile.Data.Rebirths)
			notice(player, 'Need ' .. Format.compact(math.max(1, math.ceil(need - profile.Data.Rep))) .. ' more Power to rebirth')
		end
	end)
	Players.PlayerRemoving:Connect(function(player) limit.remove(player) end)
end

return RebirthService
