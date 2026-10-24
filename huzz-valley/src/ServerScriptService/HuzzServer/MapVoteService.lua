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

-- Runs the vote: returns the winning name. stillGoing() false (too few players) ends it early with nil; skip() true
-- (HuzzServer/SkipService: the players voted SKIP) ends it early with the votes cast so far.
function MapVoteService.run(nameA, nameB, seconds, stillGoing, skip)
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
		if skip and skip() then break end
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
	pcall(function() require(script.Parent.MapService).paintLobby(winner) end) -- (the lobby floor turns into the map's)
	return winner
end

local remote = Net.get("Vote") :: RemoteEvent
local lastVote: { [Player]: number } = {}
local latest: { [Player]: string } = {} -- a change that came too soon: applied when its 0.2 s is up
local function cast(player: Player, name: string)
	if votes[player] == name or not (open and (name == choices[1] or name == choices[2])) then return end
	lastVote[player] = os.clock()
	votes[player] = name
	player:SetAttribute("HuzzVote", name)
	recount()
end
remote.OnServerEvent:Connect(function(player, name)
	-- (one change every 0.2 s, each change is sent to every player; a quicker one waits its turn instead of being
	-- dropped, so the last tap always counts)
	if type(name) ~= "string" then return end
	local wait = 0.2 - (os.clock() - (lastVote[player] or 0))
	if wait <= 0 then
		latest[player] = nil
		cast(player, name)
	elseif latest[player] == nil then
		latest[player] = name
		task.delay(wait, function()
			local pick = latest[player]
			latest[player] = nil
			if pick and player.Parent then cast(player, pick) end
		end)
	else
		latest[player] = name
	end
end)
Players.PlayerRemoving:Connect(function(player)
	lastVote[player], latest[player] = nil, nil
	if votes[player] then
		votes[player] = nil
		recount()
	end
end)

return MapVoteService
