--!strict
-- The Coffee Machine (§7): the pet system. Hires cost Wins (never Robux, which
-- keeps the machine outside the paid-random-item rules), and every roll happens
-- HERE — the client only ever learns the result, so published odds are
-- provably the real odds.
--
-- Rendering contract: interns of OTHER players aren't in your ClientState, so
-- InternRenderer reads a character attribute instead. This service owns that
-- attribute — "EquippedInternIds", the equipped interns' def ids (not uids)
-- comma-joined in equip order — and refreshes it on every roster change and on
-- every respawn.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Interns = require(Shared.Config.Interns)

local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

local ATTRIBUTE_NAME = "EquippedInternIds"

local InternService = {}

local trove = Trove.new()
-- One child trove per loaded player holds their CharacterAdded connection, so
-- a leaver's connection dies without touching anyone else's.
local playerTroves: { [Player]: Trove.Trove } = {}

-- Weighted rarity roll straight off the published odds table. Percentages sum
-- to exactly 100 (unit-checked in config), so the cumulative walk always lands.
local function rollRarity(): Interns.Rarity
	local roll = math.random() * 100
	local cumulative = 0
	for _, rarityName in Interns.RarityOrder do
		-- Bridge through `any`: the old Luau solver widens the config's string
		-- singletons when iterating across the module boundary, and a direct
		-- union-to-union cast is rejected. The annotation restores the real type.
		local rarity: Interns.Rarity = rarityName :: any
		cumulative += Interns.RarityOdds[rarity]
		if roll < cumulative then
			return rarity
		end
	end
	-- Float edge: roll == 100 exactly. Give the top rarity rather than erroring
	-- on a one-in-2^53 event.
	return Interns.RarityOrder[#Interns.RarityOrder] :: any
end

-- Two-stage roll (§7): rarity by odds, then uniform WITHIN the rarity — so
-- adding roster entries never quietly shifts the published rarity odds.
local function rollIntern(): Interns.InternDef
	local pool = Interns.ofRarity(rollRarity())
	if #pool == 0 then
		-- A rarity with an empty bucket is a config mistake; falling back to the
		-- full roster keeps a paid hire from vanishing while it gets fixed.
		pool = Interns.Roster
	end
	return pool[math.random(#pool)]
end

-- Rebuild the character attribute InternRenderer watches. Written even when
-- empty ("") so unequipping the last intern actually clears the display.
local function refreshEquippedAttribute(player: Player)
	local character = player.Character
	if not character then
		return -- next CharacterAdded writes it fresh
	end
	local data = DataService.get(player)
	local defIds: { string } = {}
	if data then
		for _, uid in data.EquippedInterns do
			for _, owned in data.Interns do
				if owned.Uid == uid then
					table.insert(defIds, owned.Id)
					break
				end
			end
		end
	end
	character:SetAttribute(ATTRIBUTE_NAME, table.concat(defIds, ","))
end

local function onRequestHireIntern(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Balance.CoffeeMachineCost
	if data.Wins < cost then
		-- A push re-greys the HIRE button on a client whose Wins display drifted.
		DataService.pushState(player)
		return
	end

	local def = rollIntern()
	-- GUID (not a counter) so duplicates of the same intern stay tellable-apart
	-- forever, even across merged saves.
	local uid = HttpService:GenerateGUID(false)
	local passes = DataService.passesFor(player)

	DataService.update(player, function(live)
		live.Wins -= cost
		table.insert(live.Interns, { Uid = uid, Id = def.Id })
		-- Auto-equip while there's room: a fresh hire that silently sits in the
		-- drawer reads as a broken purchase to a new player.
		if #live.EquippedInterns < Stack.internSlots(live, passes) then
			table.insert(live.EquippedInterns, uid)
		end
	end)

	refreshEquippedAttribute(player)
	-- The roller gets the reveal payload; everyone gets the world-visible pop.
	Net.sendTo(player, "InternRollResult", { InternId = def.Id, Uid = uid, Rarity = def.Rarity })
	Net.sendAll("Fx", { Kind = "InternHired", UserId = player.UserId })
	DataService.pushState(player)
end

local function onRequestEquipIntern(player: Player, uid: string, equip: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end

	-- The uid must be one of THIS player's hires; anything else is a client
	-- guessing at other people's GUIDs.
	local ownsUid = false
	for _, owned in data.Interns do
		if owned.Uid == uid then
			ownsUid = true
			break
		end
	end
	if not ownsUid then
		return
	end

	local alreadyEquipped = table.find(data.EquippedInterns, uid) ~= nil
	if equip then
		if alreadyEquipped then
			return -- double-equipping one uid would double its income
		end
		local passes = DataService.passesFor(player)
		if #data.EquippedInterns >= Stack.internSlots(data, passes) then
			DataService.pushState(player)
			return
		end
		DataService.update(player, function(live)
			table.insert(live.EquippedInterns, uid)
		end)
	else
		if not alreadyEquipped then
			return
		end
		DataService.update(player, function(live)
			local index = table.find(live.EquippedInterns, uid)
			if index then
				table.remove(live.EquippedInterns, index)
			end
		end)
	end

	refreshEquippedAttribute(player)
	DataService.pushState(player)
end

local function watchPlayer(player: Player)
	if playerTroves[player] then
		return
	end
	local playerTrove = trove:Extend()
	-- Cast: the old Luau solver can't prove two instantiations of Trove's
	-- generic-method type are identical; the value really is a Trove.
	playerTroves[player] = playerTrove :: any

	-- Attributes live on the character MODEL, so every respawn starts blank and
	-- must be restamped or everyone's interns vanish on death.
	playerTrove:Connect(player.CharacterAdded, function()
		refreshEquippedAttribute(player)
	end)
	refreshEquippedAttribute(player)
end

local function unwatchPlayer(player: Player)
	local playerTrove = playerTroves[player]
	if playerTrove then
		playerTroves[player] = nil
		playerTrove:Destroy()
	end
end

-- Briefcases: the egg stands in the hub. Spend Wins, roll a rarity from that
-- briefcase's published odds, then a uniform pick inside the rarity. The roll
-- happens here on the server so a client can never choose its own outcome.
local function onOpenEgg(player: Player, eggId: string)
	local data = DataService.get(player)
	local egg = Eggs.get(eggId)
	if not (data and egg) then
		return
	end
	if data.Wins < egg.Cost then
		Net.sendTo(player, "ClickResult", {
			Amount = 0,
			Crit = "none",
			Kind = "locked",
			Label = ("Need %d Wins"):format(egg.Cost),
		})
		return
	end

	local rarity = Eggs.rollRarity(egg, math.random())
	local pool = Interns.ofRarity(rarity :: any)
	if #pool == 0 then
		return -- a briefcase listing a rarity nothing occupies; nothing to give
	end
	local def = pool[math.random(1, #pool)]
	local uid = HttpService:GenerateGUID(false)

	DataService.update(player, function(live)
		live.Wins -= egg.Cost
		table.insert(live.Interns, { Uid = uid, Id = def.Id })
	end)

	-- Auto-equip while there is room: a pet you cannot see is a pet you did
	-- not feel like you got.
	local passes = DataService.passesFor(player)
	if #data.EquippedInterns < Stack.internSlots(data, passes) then
		DataService.update(player, function(live)
			table.insert(live.EquippedInterns, uid)
		end)
	end
	refreshEquippedAttribute(player)

	Net.sendTo(player, "InternRollResult", { InternId = def.Id, Uid = uid, Rarity = rarity })
	Net.sendAll("Fx", { Kind = "InternHired", UserId = player.UserId })
	DataService.pushState(player)
end

function InternService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function InternService:Start()
	Net.bind("RequestOpenEgg", 2, 3, t.tuple(t.string), onOpenEgg)
	Net.bind("RequestHireIntern", 2, 3, t.tuple(), onRequestHireIntern)
	Net.bind("RequestEquipIntern", 5, 8, t.tuple(t.string, t.boolean), onRequestEquipIntern)

	-- PlayerLoaded (not PlayerAdded): the attribute is derived from profile
	-- data, so watching before the profile exists would only stamp "".
	-- Casts: DataService's Signals are unparameterized Signal.new() values,
	-- which the solver can't match against Trove's SignalLike shape.
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		watchPlayer(player)
	end)
	trove:Connect(DataService.PlayerUnloading :: any, function(player: Player)
		unwatchPlayer(player)
	end)
end

return InternService
