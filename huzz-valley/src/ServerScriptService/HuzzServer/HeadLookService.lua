--[[
	Everyone's head turn, for everyone (owner, Oct 19 19:48: "make the users head move but make it follow mouse
	movements ... make it like the references of huss valley"). Each screen sends where its own head looks
	(Gameplay/HeadAim, the HeadLook remote: turn and tilt in whole degrees, ~5 times a second); this checks it and puts
	it on that player's character as HuzzLook = Vector2.new(turn, tilt), which every screen reads and springs to
	(Gameplay/PlayerMoves). Only looks: it never moves a body or changes a rule. Checked: two numbers, not NaN, clamped
	to a neck's reach (Config/Run.Loco.Look Max / Up / Down), at most 8 a second per player (extra ones are dropped).
]]
local HeadLookService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Run = require(Shared.Config.Run)

local LOOK = Run.Loco.Look
local MAX_RATE = 8 -- sends a second we take from one player (the screen sends Look.SendRate)

local budget = {} -- Player -> { tokens, at }

-- The (turn, tilt) to show for what a client sent, or nil when it isn't two sane numbers.
function HeadLookService.clean(turn, tilt): (number?, number?)
	if type(turn) ~= "number" or type(tilt) ~= "number" or turn ~= turn or tilt ~= tilt then
		return nil, nil
	end
	turn = math.floor(math.clamp(turn, -LOOK.Max, LOOK.Max) + 0.5)
	tilt = math.floor(math.clamp(tilt, -(LOOK.Down or 35), LOOK.Up or 30) + 0.5)
	return turn, tilt
end

-- May this player send now? (a token bucket: MAX_RATE a second, a burst of 2)
function HeadLookService.allow(p, now: number): boolean
	local b = budget[p]
	if not b then
		b = { tokens = 2, at = now }
		budget[p] = b
	end
	b.tokens = math.min(2, b.tokens + (now - b.at) * MAX_RATE)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function HeadLookService.start()
	local remote = require(Shared.Net).get("HeadLook") :: RemoteEvent -- (here: the rules above load offline too)
	remote.OnServerEvent:Connect(function(player, turn, tilt)
		if not HeadLookService.allow(player, os.clock()) then
			return
		end
		local t, u = HeadLookService.clean(turn, tilt)
		local character = player.Character
		if not t or not character then
			return
		end
		local v = Vector2.new(t, u)
		if character:GetAttribute("HuzzLook") ~= v then
			character:SetAttribute("HuzzLook", v)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		budget[p] = nil
	end)
end

return HeadLookService
