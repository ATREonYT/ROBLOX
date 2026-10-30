--[[
	The playtime coin boost (Config/Playtime): counts each player's time playing in this server (not while AFK,
	player attribute HuzzAfk) and adds a step every Playtime.Every seconds, up to Max. Attributes: HuzzPlayStacks
	(steps so far) and HuzzPlayNextAt (server time of the next step; nil while AFK or at the top). Gone when they
	leave, unless they're back in this server within KeepFor seconds (the AFK rejoin, Gameplay/AfkRejoin).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Playtime = require(ReplicatedStorage:WaitForChild("Shared").Config.Playtime)

local PlaytimeService = {}

local played: { [Player]: { stacks: number, seconds: number } } = {}
local left: { [number]: { stacks: number, seconds: number, at: number } } = {} -- by UserId, for a quick rejoin

local function show(p: Player, s)
	p:SetAttribute("HuzzPlayStacks", s.stacks)
	local afk = p:GetAttribute("HuzzAfk") == true
	local nextAt = if afk or s.stacks >= Playtime.Max then nil else Workspace:GetServerTimeNow() + (Playtime.Every - s.seconds)
	local old = p:GetAttribute("HuzzPlayNextAt")
	-- (only when it moves by more than a second: no attribute traffic every tick)
	if nextAt == nil or old == nil or math.abs(old - nextAt) > 1 then p:SetAttribute("HuzzPlayNextAt", nextAt) end
end

local function join(p: Player)
	local back = left[p.UserId]
	left[p.UserId] = nil
	local s = if back and os.clock() - back.at <= Playtime.KeepFor then { stacks = back.stacks, seconds = back.seconds } else { stacks = 0, seconds = 0 }
	played[p] = s
	show(p, s)
end

-- The game pay for this player with their playtime steps on top.
function PlaytimeService.coins(player: Player, amount: number): number
	local s = played[player]
	return Playtime.coins(amount, s and s.stacks or 0)
end

function PlaytimeService.start()
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		if not played[p] then join(p) end
	end
	Players.PlayerRemoving:Connect(function(p)
		local s = played[p]
		played[p] = nil
		if s then left[p.UserId] = { stacks = s.stacks, seconds = s.seconds, at = os.clock() } end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(now - last, 5)
			last = now
			for p, s in played do
				if p.Parent ~= Players then continue end
				if p:GetAttribute("HuzzAfk") ~= true and s.stacks < Playtime.Max then
					s.seconds += dt
					if s.seconds >= Playtime.Every then
						s.seconds -= Playtime.Every
						s.stacks += 1
						if s.stacks >= Playtime.Max then s.seconds = 0 end
					end
				end
				show(p, s)
			end
			for id, b in left do
				if now - b.at > Playtime.KeepFor then left[id] = nil end
			end
		end
	end)
end

return PlaytimeService
