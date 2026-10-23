--[[
	SKIP: the wait before a game, cut short by a vote (owner, Oct 23 16:52: "make a skip round"). Free for everyone.
	  - Open only during the wait (the map vote, or the intermission with one map): RoundService opens it and asks
	    SkipService.wanted() while it waits. A tap toggles your vote (ActionService "SkipVote").
	  - More than half the players here must want it (1 of 1, 2 of 2 or 3, 3 of 4 or 5 ...). Then the wait ends at once
	    and the next game starts as usual (the map vote still counts the votes cast).
	  - Shown on everyone's screen: Workspace attributes "HuzzSkipVotes" and "HuzzSkipNeed" (nil while closed), and
	    each player's "HuzzSkip" (true once they voted). Read by Screens/LobbyHud's SKIP button.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SkipService = {}
local open = false
local votes: { [number]: boolean } = {} -- UserId -> true

local function need(): number
	return math.floor(#Players:GetPlayers() / 2) + 1
end

local function count(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if votes[p.UserId] then n += 1 end
	end
	return n
end

local function publish()
	Workspace:SetAttribute("HuzzSkipVotes", if open then count() else nil)
	Workspace:SetAttribute("HuzzSkipNeed", if open then need() else nil)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzSkip", if open and votes[p.UserId] then true else nil)
	end
end

function SkipService.open()
	open = true
	table.clear(votes)
	publish()
end

function SkipService.close()
	open = false
	table.clear(votes)
	publish()
end

-- True once more than half the players here voted to skip.
function SkipService.wanted(): boolean
	return open and count() >= need()
end

function SkipService.vote(player: Player, on: any): (boolean, string?)
	if not open then return false, "You can skip only while waiting for the next game." end
	votes[player.UserId] = if on == false then nil else true
	publish()
	return true
end

function SkipService.start()
	Players.PlayerAdded:Connect(function() if open then publish() end end)
	Players.PlayerRemoving:Connect(function(p)
		votes[p.UserId] = nil
		task.defer(function() if open then publish() end end)
	end)
	publish()
end

return SkipService
