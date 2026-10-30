--[[
	SKIP (skip game): sit out the next game and stay in the lobby (owner, Oct 23 19:33: "you dont get teleported into
	the game if you select it, add in brackets (skip game)"). Free, and only for you.
	  - Open only during the wait (the map vote, or the intermission with one map): RoundService opens it, then closes
	    it when the game starts. A tap toggles your choice (ActionService "SkipVote").
	  - The choice lasts for that one game: RoundService leaves you out of it (no role, you stay in the lobby) and
	    clears every choice when the game ends. If everyone here skips, there is no game and the vote starts again.
	  - Players on the AFK zone (HuzzServer/AfkService) sit out too, every game, for as long as they stand there.
	  - Shown on everyone's screen: Workspace attribute "HuzzSkipVotes" (how many skip; nil while closed), and each
	    player's "HuzzSkip" (true while they sit out). Read by Screens/LobbyHud's SKIP button.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SkipService = {}
local open = false
local sitting: { [number]: boolean } = {} -- UserId -> true

-- Sitting out: chose SKIP, or standing on the AFK zone (HuzzServer/AfkService, attribute HuzzAfk) for as long as
-- they stay there.
local function sits(p: Player): boolean
	return sitting[p.UserId] == true or p:GetAttribute("HuzzAfk") == true
end

local function count(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if sits(p) then n += 1 end
	end
	return n
end

local function publish()
	Workspace:SetAttribute("HuzzSkipVotes", if open then count() else nil)
	Workspace:SetAttribute("HuzzSkipNeed", nil) -- (the old vote's attribute, from saved places)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzSkip", if sitting[p.UserId] then true else nil)
	end
end

-- The wait begins: everyone can choose again.
function SkipService.open()
	open = true
	table.clear(sitting)
	publish()
end

-- The game starts: no more changes, the choices stand until SkipService.clear().
function SkipService.close()
	open = false
	publish()
end

-- The game ended: everyone plays the next one unless they skip again.
function SkipService.clear()
	open = false
	table.clear(sitting)
	publish()
end

function SkipService.sitting(userId: number): boolean
	local p = Players:GetPlayerByUserId(userId)
	return sitting[userId] == true or (p ~= nil and sits(p))
end

-- True when every player here skips (then there is no game).
function SkipService.everyone(): boolean
	local all = Players:GetPlayers()
	return #all > 0 and count() == #all
end

function SkipService.vote(player: Player, on: any): (boolean, string?)
	if not open then return false, "You can skip only while waiting for the next game." end
	sitting[player.UserId] = if on == false then nil else true
	publish()
	return true
end

function SkipService.start()
	Players.PlayerAdded:Connect(function() if open then publish() end end)
	Players.PlayerRemoving:Connect(function(p)
		sitting[p.UserId] = nil
		task.defer(publish)
	end)
	publish()
end

return SkipService
