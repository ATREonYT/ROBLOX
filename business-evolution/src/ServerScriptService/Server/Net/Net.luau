--!strict
-- The single doorway for everything a client can ask the server to do (§13.4).
-- Every remote handler is registered through Net.bind, which enforces:
--   1. a token-bucket rate limit per player per remote
--   2. a `t` argument validator
-- Over-rate or malformed calls are DROPPED silently — never a kick, because
-- laggy players double-fire remotes and that must not read as cheating.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

type Bucket = {
	Tokens: number,
	LastRefill: number,
}

type Binding = {
	RatePerSecond: number,
	Burst: number,
	Buckets: { [Player]: Bucket },
}

local Net = {}

local bindings: { [string]: Binding } = {}
local trove = Trove.new()
local started = false

local function takeToken(binding: Binding, player: Player): boolean
	local bucket = binding.Buckets[player]
	local now = os.clock()
	if not bucket then
		bucket = { Tokens = binding.Burst, LastRefill = now }
		binding.Buckets[player] = bucket
	end
	local elapsed = now - bucket.LastRefill
	bucket.Tokens = math.min(binding.Burst, bucket.Tokens + elapsed * binding.RatePerSecond)
	bucket.LastRefill = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

-- Register the server handler for one client→server remote.
-- validator: a `t` check run against the argument tuple (use t.tuple(...)).
function Net.bind(
	remoteName: string,
	ratePerSecond: number,
	burst: number,
	validator: (...any) -> (boolean, string?),
	handler: (player: Player, ...any) -> ()
)
	local remote = remotesFolder:FindFirstChild(remoteName)
	assert(remote and remote:IsA("RemoteEvent"), ("Net.bind: no RemoteEvent named %q"):format(remoteName))
	assert(bindings[remoteName] == nil, ("Net.bind: %q bound twice"):format(remoteName))

	local binding: Binding = { RatePerSecond = ratePerSecond, Burst = burst, Buckets = {} }
	bindings[remoteName] = binding

	trove:Connect(remote.OnServerEvent, function(player: Player, ...)
		if not takeToken(binding, player) then
			return -- over rate: silently dropped
		end
		if not validator(...) then
			return -- malformed: silently dropped
		end
		handler(player, ...)
	end)
end

-- Server→client senders. Thin wrappers so services never touch instances.
function Net.sendTo(player: Player, remoteName: string, ...)
	local remote = remotesFolder:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, ...)
	end
end

function Net.sendAll(remoteName: string, ...)
	local remote = remotesFolder:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

function Net.Start()
	if started then
		return
	end
	started = true
	-- Buckets die with the player, or they'd leak across hundreds of joins (§13.11).
	trove:Connect(Players.PlayerRemoving, function(player)
		for _, binding in bindings do
			binding.Buckets[player] = nil
		end
	end)
end

return Net
