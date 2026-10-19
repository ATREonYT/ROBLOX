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

-- The friend reward on a save, once per account: the friend knife, or coins when it's already owned.
-- Changes `data` and returns "Knife", "Coins" or nil (already given).
function FriendRules.grant(data: any): string?
	if data.FriendReward then return nil end
	data.FriendReward = true
	data.Cosmetics = data.Cosmetics or {}
	if data.Cosmetics[Friends.Knife] then
		data.Coins = (data.Coins or 0) + Friends.FriendKnifeCoins
		return "Coins"
	end
	data.Cosmetics[Friends.Knife] = true
	return "Knife"
end

return FriendRules
