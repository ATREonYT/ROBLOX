--[[
	Where every body was over the last moment, so a catch is judged on what the catcher's screen showed (owner,
	Oct 19: "make the player to player touch WAY MORE accurate"). Other players reach a screen a little late (their
	network trip plus Roblox's smoothing), so a catcher swings at where a runner WAS; the server checks the knife
	against the runner's body at those moments instead of a generous distance (Shared/TouchHit, RoundService.stabNear).
	It keeps each player character's root (and any root asked about, e.g. the Practice Bot's) for Config/Round.Touch
	Keep seconds, sampled every server frame. Strong tables keyed by the root part, cleared when it leaves (never a
	weak table keyed by an Instance: entries vanish at random).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Round)
local KEEP = (Config.Touch and Config.Touch.Keep) or 0.6

local HitHistory = {}
local samples = {} -- root part -> { { t, cf }, ... } oldest first
local asked = {} -- root part -> true: kept even if it isn't a player's (the bot)

local function record(root: BasePart, now: number)
	local list = samples[root]
	if not list then
		list = {}
		samples[root] = list
	end
	table.insert(list, { t = now, cf = root.CFrame })
	while #list > 2 and now - list[1].t > KEEP do
		table.remove(list, 1)
	end
end

-- Start keeping this root's history (the Practice Bot's body asks on its first stab).
function HitHistory.track(root: BasePart)
	asked[root] = true
end

-- Where `root` was at clock time `t` (os.clock), blended between the two samples round it; its current CFrame if
-- there's no history yet or `t` is now.
function HitHistory.at(root: BasePart, t: number): CFrame
	local list = samples[root]
	if not list or #list == 0 or t >= list[#list].t then
		return root.CFrame
	end
	if t <= list[1].t then
		return list[1].cf
	end
	for i = #list - 1, 1, -1 do
		local a, b = list[i], list[i + 1]
		if t >= a.t then
			local k = (t - a.t) / math.max(b.t - a.t, 1e-4)
			return a.cf:Lerp(b.cf, k)
		end
	end
	return list[1].cf
end

-- Every place `root` was from clock time `from` to now (its samples in between, both ends blended, and now).
function HitHistory.between(root: BasePart, from: number): { CFrame }
	local out = { HitHistory.at(root, from) }
	for _, s in samples[root] or {} do
		if s.t > from then
			table.insert(out, s.cf)
		end
	end
	table.insert(out, root.CFrame)
	return out
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local seen = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			seen[root] = true
			record(root, now)
		end
	end
	for root in asked do
		if root.Parent then
			seen[root] = true
			record(root, now)
		else
			asked[root] = nil
		end
	end
	for root in samples do
		if not seen[root] then
			samples[root] = nil
		end
	end
end)

return HitHistory
