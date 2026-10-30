--!strict
-- New Game Kit: Income (cash per second, tap to earn, offline earnings)
-- Install: ServerScriptService/Kit/Income (ModuleScript)
--
-- Every hit simulator pays something every second and pays a little while the
-- player is away (a reason to come back tomorrow). All amounts go through
-- Currency.Earn, so rebirth, upgrade, pet and pass multipliers apply.
--   perSecond: base income per second (plus Upgrades.Value(perSecondUpgrade) if set)
--   tap:       base income per tap (Income.Tap remote, rate limited) - optional
--   offline:   { rate = 0.5, maxHours = 2 } pays rate * perSecond for up to maxHours away
-- Remote: Income.Tap() (fire-and-forget). Push: Income.Offline(amount, seconds) once on join.
-- Status: runs in the offline Lune harness (tools/sim.luau); not yet run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Currency = require(script.Parent.Currency)

export type Config = {
	currency: string,
	perSecond: number,
	perSecondStat: ((Player) -> number)?, -- set in Main, e.g. from an Upgrades stat
	tap: number?, -- 0 or nil: no tap remote
	tapsPerSecond: number?, -- default 8 (anti auto-clicker; extra taps are dropped)
	offline: { rate: number, maxHours: number }?,
}

local Income = {}

local cfg: Config? = nil
local offlinePush: Net.Push? = nil

-- Pure: offline payout for `seconds` away.
function Income.offlineAmount(perSecond: number, seconds: number, rate: number, maxHours: number): number
	if seconds <= 0 or perSecond <= 0 or rate <= 0 then
		return 0
	end
	local capped = math.min(seconds, maxHours * 3600)
	return math.floor(perSecond * capped * rate)
end

function Income.PerSecond(player: Player): number
	local c = cfg :: Config
	local base = c.perSecond
	if c.perSecondStat then
		local ok, extra = pcall(c.perSecondStat, player)
		if ok and type(extra) == "number" and extra == extra then
			base += extra
		end
	end
	return base
end

local function onLoaded(player: Player, profile: PlayerData.Profile)
	local c = cfg :: Config
	local state = profile.Data.Income
	local now = os.time()
	local away = if state.LastSeen > 0 then now - state.LastSeen else 0
	state.LastSeen = now
	PlayerData.MarkDirty(profile)
	if c.offline and away >= 60 then
		local base = Income.offlineAmount(Income.PerSecond(player), away, c.offline.rate, c.offline.maxHours)
		if base > 0 then
			local ok, amount = Currency.Earn(player, c.currency, base, "offline")
			if ok and offlinePush then
				offlinePush:Fire(player, amount, math.min(away, c.offline.maxHours * 3600))
			end
		end
	end
end

local function tick()
	local c = cfg :: Config
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.Get(player)
		if profile then
			local perSecond = Income.PerSecond(player)
			if perSecond > 0 then
				Currency.Earn(player, c.currency, perSecond, "income")
			end
			profile.Data.Income.LastSeen = now
		end
	end
end

function Income.Init(config: Config)
	assert(Currency.Exists(config.currency), `Income: unknown currency {config.currency}`)
	assert(config.perSecond >= 0, "Income: perSecond >= 0")
	if config.offline then
		assert(config.offline.rate >= 0 and config.offline.rate <= 1, "Income: offline.rate 0..1")
		assert(config.offline.maxHours > 0 and config.offline.maxHours <= 24, "Income: offline.maxHours 0..24")
	end
	cfg = config

	PlayerData.RegisterSlice("Income", function()
		return { LastSeen = 0 }
	end)
	offlinePush = Net.Push("Income.Offline")
	if (config.tap or 0) > 0 then
		local perSecond = config.tapsPerSecond or 8
		Net.Listen("Income.Tap", {
			rate = { burst = perSecond, perSecond = perSecond },
			args = {},
			handler = function(player: Player)
				if PlayerData.Get(player) then
					Currency.Earn(player, config.currency, config.tap :: number, "tap")
				end
			end,
		})
	end
	PlayerData.Loaded:Connect(onLoaded)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return Income
