--!strict
-- New Game Kit: PlaytimeGifts (free gifts for staying in this session)
-- Install: ServerScriptService/Kit/PlaytimeGifts (ModuleScript)
--
-- Real timers only (kid-safe rule: no fake countdowns). The server stamps the
-- session start; the client counts down from the SessionStart attribute and the
-- server checks the time again on claim. Gifts reset each session.
--   gifts = { { minutes = 1, reward = <Rewards format> }, ... } (ascending minutes)
-- Remote: PlaytimeGifts.Claim(index) -> Net.Result
-- Attributes: SessionStart (server os.time), GiftsClaimed (bit mask, UI only)
-- Status: runs in the offline Lune harness (tools/sim.luau); not yet run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local T = Net.T

export type Gift = { minutes: number, reward: Rewards.Reward }
export type Config = { gifts: { Gift } }

local PlaytimeGifts = {}

local gifts: { Gift } = {}
local sessions: { [Player]: { start: number, claimed: { [number]: boolean } } } = {}

local function mask(claimed: { [number]: boolean }): number
	local m = 0
	for i in claimed do
		m += 2 ^ (i - 1)
	end
	return m
end

local function claim(player: Player, index: number): Net.Result
	local session = sessions[player]
	if not session or not PlayerData.Get(player) then
		return Net.fail("NotReady")
	end
	local gift = gifts[index]
	if session.claimed[index] then
		return Net.fail("AlreadyClaimed")
	end
	if os.time() - session.start < gift.minutes * 60 then
		return Net.fail("NotEligible")
	end
	local ok, code = Rewards.CanGrant(player, gift.reward)
	if not ok then
		return Net.fail(code or "BagFull")
	end
	-- Mark and grant in one synchronous block.
	session.claimed[index] = true
	Rewards.Grant(player, gift.reward, `playtime:{index}`)
	player:SetAttribute("GiftsClaimed", mask(session.claimed))
	return Net.ok({ index = index })
end

function PlaytimeGifts.Init(config: Config)
	local last = 0
	for i, gift in config.gifts do
		assert(gift.minutes > last, `PlaytimeGifts: gift {i} minutes must be ascending`)
		last = gift.minutes
		Rewards.Validate(`PlaytimeGifts[{i}]`, gift.reward)
	end
	assert(#config.gifts <= 24, "PlaytimeGifts: at most 24 gifts")
	gifts = config.gifts
	Net.Handle("PlaytimeGifts.Claim", {
		rate = { burst = 4, perSecond = 2 },
		args = { T.integer(1, math.max(#gifts, 1)) },
		handler = claim,
	})
	PlayerData.Loaded:Connect(function(player: Player)
		sessions[player] = { start = os.time(), claimed = {} }
		player:SetAttribute("SessionStart", sessions[player].start)
		player:SetAttribute("GiftsClaimed", 0)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
end

return PlaytimeGifts
