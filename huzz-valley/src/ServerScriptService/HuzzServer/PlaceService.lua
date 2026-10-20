--[[
	Moves a player's body the way Roblox expects: its owner moves it (owner, Oct 20 15:13: "please make the DSYNC way,
	way better. right now on peoples screens it sometimes doesnt match up and the peoples locations are off on
	eachothers screens").
	A player's character is simulated by that player's own client (network ownership): it sends where the body is,
	the server and every other screen follow. When the server set the CFrame itself (PivotTo) while the body was
	moving, the owner kept sending positions from before the move until the change reached it, so the server and the
	other screens saw the body jump there, back, and there again, and a correction that ran every frame (keep a
	catcher out of the safe zones, keep a safe runner in, keep a runner on the line) kept fighting the owner's own
	movement from the server's older copy of where it was.
	Now:
	  - place(player, cf, why, still?): the owner is told to move (Net "Place": its character and the CFrame;
	    HuzzClient/Gameplay/PlaceSelf moves it, stops it and the next physics update carries it everywhere);
	  - the server watches for Config/Round.Place.Grace seconds plus the player's round trip: if its copy never came
	    within Near studs of the spot (an old client, a body not loaded yet), it moves the body itself, once, and says
	    so once in Output ([Huzz] Place);
	  - pending(player): a move is on its way and the server's copy isn't there yet (the every-frame corrections wait
	    for it instead of sending again, and go again as soon as it has arrived);
	  - still (optional): asked again just before the owner is told and before the server's own move; false drops the
	    move (the Lasso's fallback pull: never once the runner is safe or out);
	  - lastMoveAt(player): os.clock() of the last move sent them, 0 if none (the Lasso's fallback pull is dropped when
	    a move was sent just before the catch or since: it lands on their screen after the catch, PlaceSelf lets go of
	    the pull for it, and that move wins);
	  - a body whose root is anchored (lying caught, KnockdownService: the server owns it) is moved by the server.
	His place streams with StreamingIntegrityMode PauseOutsideLoadedArea: a body moved where nothing has loaded yet
	stands frozen until it has. So the spot is streamed in around the player first (RequestStreamAroundAsync, at most
	Place.StreamWait seconds) before the move.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Round)

local PlaceService = {}
PlaceService.fallbacks = 0 -- (moves the server had to make itself: the sim checks it stays 0)
local P = Config.Place or { Grace = 0.4, Near = 4, StreamWait = 1 }
local remote = Net.get("Place")
local waiting = {} -- player -> { cf, token } (a plain table, cleared on leave)
local token = 0
local told = {}
local movedAt = {} -- player -> os.clock() of the last move sent (a plain table, cleared on leave)

local function rootOf(character)
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	return if root and root:IsA("BasePart") then root else nil
end

-- The server moves the body itself (anchored roots, the fallback).
local function serverMove(character, cf)
	local root = rootOf(character)
	if root then
		pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
	end
	character:PivotTo(cf)
end

-- True while a move is on its way: asked, and the server's copy of the body isn't there yet (once it is, the next
-- correction can go at once).
function PlaceService.pending(player): boolean
	local w = waiting[player]
	if not w then
		return false
	end
	local root = rootOf(player.Character)
	if w.sent and root and (root.Position - w.cf.Position).Magnitude <= P.Near then
		waiting[player] = nil -- (arrived)
		return false
	end
	return true
end

function PlaceService.lastMoveAt(player): number
	return movedAt[player] or 0
end

function PlaceService.place(player, cf: CFrame, why: string?, still: (() -> boolean)?)
	local character = player and player.Character
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	movedAt[player] = os.clock()
	if root.Anchored then -- (the server owns an anchored body)
		serverMove(character, cf)
		return
	end
	token += 1
	local mine = token
	waiting[player] = { cf = cf, token = mine }
	task.spawn(function()
		-- (the spot loaded around them first, or their body stands frozen there: PauseOutsideLoadedArea)
		if P.StreamWait and P.StreamWait > 0 then
			pcall(function() player:RequestStreamAroundAsync(cf.Position, P.StreamWait) end)
		end
		if waiting[player] == nil or waiting[player].token ~= mine or player.Character ~= character then
			return
		end
		if still and not still() then
			waiting[player] = nil
			return
		end
		waiting[player].sent = true
		remote:FireClient(player, character, cf)
		local ok, ping = pcall(function() return player:GetNetworkPing() end)
		local rtt = if ok and type(ping) == "number" then math.clamp(ping * 2, 0, 1) else 0.3
		-- (watched every step, not only at the end: once there, the player runs on, and a check at the end alone
		-- pulled them back to the spot)
		local steps = math.max(1, math.ceil((P.Grace + rtt) / 0.05))
		for _ = 1, steps do
			task.wait(0.05)
			local w = waiting[player]
			if not (w and w.token == mine) or player.Character ~= character then
				return -- (a newer move, arrived through pending(), left, or respawned)
			end
			local r = rootOf(character)
			if not r or (r.Position - cf.Position).Magnitude <= P.Near then
				waiting[player] = nil -- (arrived)
				return
			end
		end
		waiting[player] = nil
		if still and not still() then
			return
		end
		serverMove(character, cf)
		PlaceService.fallbacks += 1
		local key = why or "move"
		if not told[key] then
			told[key] = true
			print(`[Huzz] Place: {player.Name}'s screen didn't move them ({key}); the server did`)
		end
	end)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	waiting[player] = nil
	movedAt[player] = nil
end)

return PlaceService
