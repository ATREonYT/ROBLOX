--!strict
-- Story beats that arrive through the phone. Kept apart from PhoneService (pure phone plumbing) and StoryService
-- (the stage machine) so neither has to require the other. The Story thread extends THIS file for later stages.
--   Arrive  -> text from Mr. Patel ("you start today, come inside")
--   FirstShift, Level 3 (Levels.CriminalTeaseLevel) -> one short text from "Unknown" so the call at Level 4 isn't
--              out of nowhere. Once (skipped if the Unknown thread already has anything in it).
--   TheCall -> the unknown number rings. "I'm in" moves the story to GangMeet. Declined / missed / hung up:
--              the call waits in Recents with a call-back button and the objective says so. Never forced.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage.MTL.Config.Levels)
local PhoneRules = require(ReplicatedStorage.MTL.Rules.PhoneRules)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local PhoneService = require(script.Parent.PhoneService)
local Notify = require(script.Parent.Notify)

local PhoneStory = {}

local RECRUIT = "Recruit"
local NUDGE_SECONDS = 90 -- after a declined / missed call, one text from Unknown (once per server session)
local nudged: { [Player]: boolean } = {}

local function hasText(player: Player, contact: string): boolean
	local data = DataService.get(player)
	local thread = data and data.Phone.Texts and data.Phone.Texts[contact]
	return thread ~= nil and #thread > 0
end

local function canCallBack(player: Player, callId: string): boolean
	local data = DataService.get(player)
	return data ~= nil and PhoneRules.findCallBack(data.Phone.Recents or {}, callId) ~= nil
end

local function ringRecruit(player: Player, delaySeconds: number)
	task.delay(delaySeconds, function()
		if player.Parent and StoryService.stage(player) == "TheCall" and not PhoneService.isInCall(player) then
			PhoneService.call(player, RECRUIT)
		end
	end)
end

function PhoneStory.init()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		nudged[player] = nil
	end)
	-- 1. Arrive: the boss texts you (once; a rejoin keeps the old text in Messages)
	StoryService.onEnter("Arrive", function(player, resumed)
		if resumed and hasText(player, "Patel") then
			return
		end
		task.wait(1.5)
		PhoneService.text(player, "Patel", "Hey, it's Mr. Patel from Liberty Food Mart. You start today!")
		task.wait(1.2)
		PhoneService.text(player, "Patel", "Come inside the store, I'll show you the shelves.")
	end)

	-- 2. FirstShift: the tease. Waits out the level-up banner, then buzzes once.
	EconomyService.LevelUp:Connect(function(player, level)
		-- the tease comes one level before this player's call (A/B: call at 4 -> tease at 3, call at 3 -> tease at 2)
		local call = StoryService.callLevel(player)
		local tease = math.min(Levels.CriminalTeaseLevel, call - 1)
		if level ~= tease or level >= call then
			return
		end
		task.delay(4, function()
			if player.Parent and StoryService.stage(player) == "FirstShift" and not hasText(player, "Unknown") then
				PhoneService.text(player, "Unknown", "saw you working at Patel's. you move quick.")
				task.wait(1.4)
				PhoneService.text(player, "Unknown", "keep your phone on.")
			end
		end)
	end)

	-- 3. TheCall: ring. Resumed with a call waiting in Recents -> just remind; otherwise ring again.
	StoryService.onEnter("TheCall", function(player, resumed)
		if resumed and canCallBack(player, RECRUIT) then
			Notify.objective(player, "Call back the unknown number")
			return
		end
		ringRecruit(player, if resumed then 6 else 3)
	end)

	PhoneService.CallEnded:Connect(function(player, callId, outcome)
		if callId ~= RECRUIT or StoryService.stage(player) ~= "TheCall" then
			return
		end
		if outcome == "accept" then
			PhoneService.textFromMe(player, "Unknown", "I'm in.")
			StoryService.advance(player, "TheCall")
		else
			Notify.objective(player, "Call back the unknown number")
			if outcome == "missed" then
				Notify.toast(player, "Missed call: Unknown number")
			end
			-- one gentle nudge later, so the story doesn't just go quiet (never a second ring: the player chooses)
			if not nudged[player] then
				nudged[player] = true
				task.delay(NUDGE_SECONDS, function()
					if player.Parent and StoryService.stage(player) == "TheCall" and not PhoneService.isInCall(player) then
						PhoneService.text(player, "Unknown", "offer's still open. call me back when you're ready.")
					end
				end)
			end
		end
	end)
end

return PhoneStory
