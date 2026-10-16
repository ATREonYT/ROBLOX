--[[
	The map vote between games (design page 15): two maps, one vote per
	player (a new vote replaces the old one), live counts, a real deadline.
	Counts and names are attributes on the Round remote (VoteA, VoteB,
	VoteCountA, VoteCountB); each player's choice is their HuzzVote attribute.
	The most votes wins; a tie (or no votes) is settled at random.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local MapVoteService = {}
local RoundNet = Net.get("Round") :: RemoteEvent
local open = false
local choices = {} -- { nameA, nameB }
local votes = {} -- Player -> map name

local function recount()
	local counts = { 0, 0 }
	for _, name in votes do
		for i, c in choices do
			if c == name then
				counts[i] += 1
			end
		end
	end
	RoundNet:SetAttribute("VoteCountA", counts[1])
	RoundNet:SetAttribute("VoteCountB", counts[2])
	return counts
end

-- Runs the vote: returns the winning name. stillGoing() false (too few players) ends it early with nil.
function MapVoteService.run(nameA, nameB, seconds, stillGoing)
	choices, votes, open = { nameA, nameB }, {}, true
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzVote", nil)
	end
	RoundNet:SetAttribute("VoteWinner", nil) -- (Screens/NextMap shows the winner once it's set)
	RoundNet:SetAttribute("VoteA", nameA)
	RoundNet:SetAttribute("VoteB", nameB)
	recount()
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if stillGoing and not stillGoing() then
			open = false
			return nil
		end
		task.wait(0.1)
	end
	open = false
	local counts = recount()
	local winner
	if counts[1] == counts[2] then
		winner = choices[math.random(2)]
	else
		winner = if counts[1] > counts[2] then nameA else nameB
	end
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzVote", nil)
	end
	RoundNet:SetAttribute("VoteWinner", winner)
	return winner
end

local remote = Net.get("Vote") :: RemoteEvent
remote.OnServerEvent:Connect(function(player, name)
	if open and type(name) == "string" and (name == choices[1] or name == choices[2]) then
		votes[player] = name
		player:SetAttribute("HuzzVote", name)
		recount()
	end
end)
Players.PlayerRemoving:Connect(function(player)
	if votes[player] then
		votes[player] = nil
		recount()
	end
end)

return MapVoteService
