-- Friend rewards as plain rules (pure: no Instances), used by HuzzServer/FriendService and tests/FriendRules.spec.
-- Config/Friends holds the numbers and the friend knife (owner, Oct 19: "add a friend knife (for inviting them) and
-- add a 10% coin boost when a friend is in").
local Friends = require(script.Parent.Config.Friends)

local FriendRules = {}

-- The coin pay with the friend boost: +10% while a friend is in, rounded to whole coins (never less than the pay).
function FriendRules.coins(amount: number, friendIn: boolean): number
	if not friendIn or amount <= 0 then return amount end
	return math.max(amount, math.floor(amount * Friends.CoinBoost + 0.5))
end

-- How many different friends have joined you (counted for the knife).
function FriendRules.met(data: any): number
	local n = 0
	for _ in (type(data) == "table" and data.FriendsMet) or {} do n += 1 end
	return n
end

-- A friend (UserId `friendId`) joined a server you're in: counted once per friend. The first friend ever gives
-- FirstCoins, the Need-th the friend knife (coins if already owned). Changes `data`; returns "Coins", "Knife",
-- "More" (counted, nothing given) or nil (already counted, or the knife's done).
function FriendRules.grant(data: any, friendId: number?): string?
	if type(friendId) ~= "number" or data.FriendKnife then return nil end
	data.FriendsMet = data.FriendsMet or {}
	local id = tostring(friendId)
	if data.FriendsMet[id] then return nil end
	data.FriendsMet[id] = true
	data.Cosmetics = data.Cosmetics or {}
	if FriendRules.met(data) >= Friends.Need then
		data.FriendKnife = true
		data.FriendsMet = nil -- (done: the list isn't needed any more)
		if data.Cosmetics[Friends.Knife] then
			data.Coins = (data.Coins or 0) + Friends.FriendKnifeCoins
			return "Coins"
		end
		data.Cosmetics[Friends.Knife] = true
		return "Knife"
	end
	if not data.FriendReward then
		data.FriendReward = true
		data.Coins = (data.Coins or 0) + Friends.FirstCoins
		return "Coins"
	end
	return "More"
end

return FriendRules
