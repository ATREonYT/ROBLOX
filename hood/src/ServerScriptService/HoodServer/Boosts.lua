-- What a player's passes and timed boosts multiply, read from the attributes the store sets on the server (UI's
-- StoreService: Pass_DoubleRep, Pass_DoubleCash, Pass_VIP, PowerBoost). Attributes a client sets on itself never reach the
-- server, so these can't be faked. Used by LobbyService and WaveService (Power per shot) and StageService, WaveService
-- and GoalService (Cash).
local RS = game:GetService('ReplicatedStorage')
local ShotRules = require(RS.Shared.ShotRules)

local Boosts = {}

-- x2 with the 2x Power pass, times a running timed boost (PowerBoost, 1..10).
function Boosts.power(player)
	return ShotRules.boost(player:GetAttribute('Pass_DoubleRep'), player:GetAttribute('PowerBoost'))
end

-- x2 with the x2 Cash pass, x1.5 with VIP (both: x3).
function Boosts.cash(player)
	return (player:GetAttribute('Pass_DoubleCash') == true and 2 or 1) * (player:GetAttribute('Pass_VIP') == true and 1.5 or 1)
end

-- Cash for a reward, with the pass (whole Cash).
function Boosts.cashFor(player, amount)
	return math.floor(math.max(0, amount) * Boosts.cash(player))
end

return Boosts
