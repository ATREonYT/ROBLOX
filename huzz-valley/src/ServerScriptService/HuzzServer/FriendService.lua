--[[
	Friend rewards (owner, Oct 19: "make friend rewards, add a friend knife (for inviting them) and add a 10% coin
	boost when a friend is in"; numbers and the placeholder knife in Config/Friends, rules in Shared/FriendRules).
	When someone joins, each player already here is checked with Roblox (Player:IsFriendsWith, guarded: it can fail
	or be slow). For each pair of friends:
	  * both carry the player attribute HuzzFriendBoost = true while the other is in the server (the lobby HUD shows
	    "+10% COINS"; RoundService adds 10% to their game pay through FriendService.coins);
	  * the one who was already here counts that friend once per account (the friend joined THEIR server, which is
	    what an invite does): coins for the first, the friend knife at Config/Friends.Need (Oct 24: 5, his Thousand
	    Blossom). HuzzFriendGift = "Coins:n" / "Knife:n" / "More:n" tells their HUD to say so; HuzzFriendsMet = n.
	Nothing here is bought; inviting opens Roblox's own window on the client (Screens/LobbyHud INVITE).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local FriendRules = require(ReplicatedStorage.Shared.FriendRules)
local Friends = require(ReplicatedStorage.Shared.Config.Friends)

local FriendService = {}

local friends: { [Player]: { [Player]: boolean } } = {} -- (both ways: friends[a][b] == friends[b][a])

local function areFriends(a: Player, b: Player): boolean
	local ok, yes = pcall(function() return a:IsFriendsWith(b.UserId) end)
	return ok and yes == true
end

local function refresh(p: Player)
	local any = false
	for other in friends[p] or {} do
		if other.Parent == Players then any = true; break end
	end
	p:SetAttribute("HuzzFriendBoost", any)
end

local function reward(host: Player, friend: Player)
	if not DataService.waitFor(host, 60) or host.Parent ~= Players then return end
	local given, met
	DataService.update(host, function(data)
		given = FriendRules.grant(data, friend.UserId)
		met = if data.FriendKnife then Friends.Need else FriendRules.met(data)
	end)
	host:SetAttribute("HuzzFriendsMet", met)
	-- (a fresh value each time, so the HUD's toast fires again for the next friend)
	if given then host:SetAttribute("HuzzFriendGift", given .. ":" .. tostring(met)) end
end

-- The game's coin pay for this player, with +10% while a friend plays in the server.
function FriendService.coins(player: Player, amount: number): number
	return FriendRules.coins(amount, player:GetAttribute("HuzzFriendBoost") == true)
end

function FriendService.start()
	Players.PlayerAdded:Connect(function(joiner)
		friends[joiner] = friends[joiner] or {}
		for _, host in Players:GetPlayers() do
			if host ~= joiner then
				task.spawn(function()
					if not areFriends(host, joiner) or host.Parent ~= Players or joiner.Parent ~= Players then return end
					friends[host] = friends[host] or {}
					friends[host][joiner], friends[joiner][host] = true, true
					refresh(host)
					refresh(joiner)
					reward(host, joiner)
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(leaver)
		local mine = friends[leaver]
		friends[leaver] = nil
		for other in mine or {} do
			if friends[other] then friends[other][leaver] = nil end
			if other.Parent == Players then refresh(other) end
		end
	end)
end

return FriendService
