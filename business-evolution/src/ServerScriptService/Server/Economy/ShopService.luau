--!strict
-- The gear counter (§8). One remote, one job: swap Wins for the next tier on a
-- ladder. All pricing comes from Config/Gear so the shop can never disagree
-- with the numbers the client renders; the client is only ever told the
-- OUTCOME via a state push — it greys out unaffordable cards itself, so a
-- rejected purchase needs no error remote at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Config.Gear)

local t = require(ReplicatedStorage.Packages.t)

type GearOwned = { Keyboard: number, Chair: number, Coffee: number }

local ShopService = {}

-- Explicit branches instead of data.Gear[ladderId]: dynamic string indexing
-- would let a doctored client poke keys that aren't ladders, and it defeats
-- strict typing. Three ladders is small enough to spell out.
local function ownedTier(gear: GearOwned, ladderId: string): number?
	if ladderId == "Keyboard" then
		return gear.Keyboard
	elseif ladderId == "Chair" then
		return gear.Chair
	elseif ladderId == "Coffee" then
		return gear.Coffee
	end
	return nil
end

local function setOwnedTier(gear: GearOwned, ladderId: string, tier: number)
	if ladderId == "Keyboard" then
		gear.Keyboard = tier
	elseif ladderId == "Chair" then
		gear.Chair = tier
	elseif ladderId == "Coffee" then
		gear.Coffee = tier
	end
end

local function onRequestPurchaseGear(player: Player, ladderId: string)
	local data = DataService.get(player)
	if not data then
		return -- profile still loading; a stock client can't buy yet anyway
	end

	local owned = ownedTier(data.Gear, ladderId)
	if owned == nil then
		return -- not a real ladder id; only a tampered client can send this
	end

	local cost = Gear.nextTierCost(ladderId, owned)
	if cost == nil or data.Wins < cost then
		-- Maxed ladder or too poor. A fresh state push re-greys a client whose
		-- affordability display drifted (e.g. it clicked just as Wins changed).
		DataService.pushState(player)
		return
	end

	-- No yields between the check above and this mutation, so the balance can
	-- never be spent twice by a double-fired remote.
	DataService.update(player, function(live)
		live.Wins -= cost
		setOwnedTier(live.Gear, ladderId, owned + 1)
	end)

	-- Broadcast (not sendTo): Fx is the world-visible channel, and every client
	-- filters by UserId to decide whether the moment is theirs.
	Net.sendAll("Fx", { Kind = "Purchase", UserId = player.UserId })
	-- Immediate push so the new tier appears the same frame as the buy click,
	-- instead of on the next throttled sync tick.
	DataService.pushState(player)
end

function ShopService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function ShopService:Start()
	Net.bind("RequestPurchaseGear", 3, 5, t.tuple(t.string), onRequestPurchaseGear)
end

return ShopService
