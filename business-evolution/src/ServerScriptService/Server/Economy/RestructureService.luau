--!strict
-- The prestige loop (§6). Restructuring trades this run's Productivity and
-- Rank for a permanent multiplier plus one Severance perk card. The card offer
-- is stored in the profile (PendingSeverance) BEFORE the client ever sees it,
-- so a crash or rage-quit mid-pick can never eat the reward — the UI re-opens
-- the offer on the next join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)
local AppearanceService = require(ServerScriptService.Server.Progression.AppearanceService)

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Interns = require(Shared.Config.Interns)
local Severance = require(Shared.Config.Severance)

local t = require(ReplicatedStorage.Packages.t)

local OFFER_COUNT = 3

local RestructureService = {}

-- Draw up to three DISTINCT perk ids from the offerable pool. Fisher-Yates on
-- the pool copy, then take the front — sampling with rejection loops instead
-- could spin forever once the pool shrinks below three.
local function sampleSeveranceOffers(ownedIds: { string }): { string }
	local pool = Severance.offerablePool(ownedIds) -- fresh table; safe to shuffle in place
	for index = #pool, 2, -1 do
		local swap = math.random(index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	local offers: { string } = {}
	for index = 1, math.min(OFFER_COUNT, #pool) do
		table.insert(offers, pool[index])
	end
	return offers
end

local function onRequestRestructure(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- One offer at a time: a second Restructure before the first card is picked
	-- would overwrite the pending offer and silently void a reward.
	if #data.PendingSeverance > 0 then
		return
	end
	if data.Rank < Balance.RestructureMinRank then
		return
	end
	if data.Productivity < Stack.restructureCost(data.Restructures) then
		-- The client's big red button already tracks affordability; a push just
		-- corrects any drift that let the request through.
		DataService.pushState(player)
		return
	end

	-- The Consultant must be EQUIPPED at the moment of Restructure — owning one
	-- in the drawer doesn't count, which is what makes the slot choice matter.
	local keepFraction = 0
	if Interns.hasSpecialEquipped(data.Interns, data.EquippedInterns, "KeepProductivity") then
		keepFraction = Balance.ConsultantKeepFraction
	end
	local startRank = if Severance.effects(data.Severance).SkipFirstRank then 2 else 1

	DataService.update(player, function(live)
		live.Productivity = math.floor(live.Productivity * keepFraction)
		-- Kept Productivity may still clear early rank thresholds; RankService's
		-- poll re-promotes within a second, so no special-casing here.
		live.Rank = startRank
		live.Restructures += 1
		live.PendingSeverance = sampleSeveranceOffers(live.Severance)
	end)

	Net.sendAll("Fx", { Kind = "Restructure", UserId = player.UserId })
	-- Back to the intern look immediately — the demotion IS the joke, and
	-- waiting for a respawn would bury the punchline.
	AppearanceService.applyFor(player)
	DataService.pushState(player)
end

local function onRequestSeverance(player: Player, perkId: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Only the cards actually offered are pickable; anything else is a client
	-- poking at perks it wasn't dealt.
	if not table.find(data.PendingSeverance, perkId) then
		return
	end
	DataService.update(player, function(live)
		table.insert(live.Severance, perkId)
		-- Clearing the whole offer (not just the picked id) is what makes the
		-- choice a choice: the two passed-over cards are gone for good.
		live.PendingSeverance = {}
	end)
	DataService.pushState(player)
end

function RestructureService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function RestructureService:Start()
	Net.bind("RequestRestructure", 1, 2, t.tuple(), onRequestRestructure)
	Net.bind("RequestSeverance", 1, 2, t.tuple(t.string), onRequestSeverance)
end

return RestructureService
