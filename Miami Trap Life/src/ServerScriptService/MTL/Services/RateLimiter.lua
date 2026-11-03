--!strict
-- Per-player token bucket for client->server remotes. RateLimiter.new(perSecond, burst):allow(player) -> bool
local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local all = {}

function RateLimiter.new(perSecond: number, burst: number?)
	local self = setmetatable({ rate = perSecond, burst = burst or perSecond, buckets = {} }, RateLimiter)
	table.insert(all, self)
	return self
end

function RateLimiter:allow(player: Player): boolean
	local now = os.clock()
	local b = self.buckets[player]
	if not b then
		b = { tokens = self.burst, t = now }
		self.buckets[player] = b
	end
	b.tokens = math.min(self.burst, b.tokens + (now - b.t) * self.rate)
	b.t = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in all do
		limiter.buckets[player] = nil
	end
end)

return RateLimiter
