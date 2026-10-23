--[[
	Passes every player's body stamp on to every screen (Shared/MotionStamps; owner, Oct 23 08:36: "make the desync
	the most precise it can be"). Each screen sends its own (Gameplay/MotionSend: server time, where, how fast, the
	speed its keys ask for, pushed or not) on the Motion UnreliableRemoteEvent; this checks it and sends it straight on
	to everyone with the character it belongs to (Gameplay/OthersAhead draws them from it). The Practice Bot's body
	(the server moves it) gets its stamps from here, 20 a second.
	Checked, so a stamp can only say what the body really does: sane numbers; taken within the last second by the
	server's clock; the body alive, unanchored and not lying caught; where it says within Config Near studs of the
	server's own copy (both are about the same moment: the stamp left half a ping ago, and so did the copy); no faster
	than its top speed allows (its keys' speed never over its WalkSpeed, the body's own speed never over a dive's or a
	huss's push); at most 40 a second per player (extra ones are dropped). A stamp only moves where a body is drawn: the
	server's rules still judge every catch on its own copy (Shared/TouchHit), and a refused stamp just isn't passed on.
	MotionRelay.latest(player or model) -> the newest checked stamp (RoundService.screenHit moves the runner's on to
	the claim's moment when the server's copy hasn't got there yet).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MotionStamps = require(Shared.MotionStamps)
local C = MotionStamps.Config

local MotionRelay = {}
local MAX_RATE = 40 -- stamps a second we take from one player
local latest = {} -- Player or bot Model -> stamp (a plain table, cleared on leave)
local budget = {} -- Player -> { tokens, at }

local function allow(p, now: number): boolean
	local b = budget[p]
	if not b then
		b = { tokens = 4, at = now }
		budget[p] = b
	end
	b.tokens = math.min(4, b.tokens + (now - b.at) * MAX_RATE)
	b.at = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

local function flat(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Is this stamp something the body could really be doing? (root = the server's copy of it)
function MotionRelay.check(stamp, root: BasePart, humanoid: Humanoid?, serverNow: number): boolean
	if not stamp then return false end
	if math.abs(serverNow - stamp.t) > 1 then return false end
	if root.Anchored or (humanoid and humanoid.Health <= 0) then return false end
	if (stamp.p - root.Position).Magnitude > C.Near + flat(root.AssemblyLinearVelocity) * 0.1 then return false end
	local walk = if humanoid then humanoid.WalkSpeed else 0
	if flat(stamp.g) > walk + 2 then return false end
	if flat(stamp.v) > C.MaxSpeed then return false end
	return true
end

function MotionRelay.latest(who): any
	return latest[who]
end

function MotionRelay.start()
	local remote = require(Shared.Net).get("Motion")
	remote.OnServerEvent:Connect(function(player, t, p, v, g, push)
		if not allow(player, os.clock()) then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or character:GetAttribute("DownedAt") ~= nil then return end
		local stamp = MotionStamps.read(t, p, v, g, push)
		if not MotionRelay.check(stamp, root, character:FindFirstChildOfClass("Humanoid"), Workspace:GetServerTimeNow()) then
			return
		end
		latest[player] = stamp
		remote:FireAllClients(character, stamp.t, stamp.p, stamp.v, stamp.g, stamp.push)
	end)
	Players.PlayerRemoving:Connect(function(p)
		latest[p] = nil
		budget[p] = nil
	end)
	-- the Practice Bot (and any other server-moved body tagged HuzzBot): stamped here, 20 a second
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < C.Every then return end
		acc = 0
		local now = Workspace:GetServerTimeNow()
		for model in latest do
			if typeof(model) == "Instance" and model:IsA("Model") and model.Parent == nil then latest[model] = nil end
		end
		for _, bot in CollectionService:GetTagged("HuzzBot") do
			local root = bot:IsA("Model") and bot:FindFirstChild("HumanoidRootPart")
			local h = bot:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and h and not root.Anchored then
				local v = root.AssemblyLinearVelocity
				local stamp = { t = now, p = root.Position, v = Vector3.new(v.X, 0, v.Z), g = h.MoveDirection * h.WalkSpeed, push = false }
				latest[bot] = stamp
				remote:FireAllClients(bot, stamp.t, stamp.p, stamp.v, stamp.g, stamp.push)
			end
		end
	end)
end

return MotionRelay
