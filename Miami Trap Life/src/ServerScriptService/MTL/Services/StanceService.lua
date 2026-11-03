--!strict
-- Stance (Quality pass, Benchmark Gap List 1.3): crouching, seen by everyone.
-- The client's Crouch controller poses its own character at once and asks here (Net StanceAction {crouch = bool}).
-- This puts the character attribute MTL_Stance = "Crouch" on (or off) so every other client poses that character too.
-- The server refuses a crouch while you're dead, seated, or carrying a job prop, and a respawn always starts standing.
-- Rate limited (a crouch spammer can't flood attribute changes to everyone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)

local StanceService = {}

local MIN_GAP = 0.15 -- seconds between accepted changes
local last: { [Player]: number } = {}

local function setStance(player: Player, on: boolean)
	local char = player.Character
	if not char then
		return
	end
	if on then
		local h = char:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 or h.Sit or char:GetAttribute("MTL_WalkSpeedBeforeCarry") ~= nil then
			return
		end
	end
	char:SetAttribute("MTL_Stance", if on then "Crouch" else nil)
end

function StanceService.isCrouching(player: Player): boolean
	local char = player.Character
	return char ~= nil and char:GetAttribute("MTL_Stance") == "Crouch"
end

function StanceService.stand(player: Player)
	setStance(player, false)
end

function StanceService.init()
	Net.get("StanceAction").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or type(payload.crouch) ~= "boolean" then
			return
		end
		local t = os.clock()
		if payload.crouch and t - (last[player] or 0) < MIN_GAP then
			return -- standing up is never refused
		end
		last[player] = t
		setStance(player, payload.crouch)
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return StanceService
