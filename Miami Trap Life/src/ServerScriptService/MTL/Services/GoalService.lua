--!strict
-- Story Piece 4: FreePlay goals (Master Plan §1 stage 13). Config/Goals + Rules/GoalRules do the thinking; this
-- service, for players in FreePlay:
--   * keeps the HUD objective line on the top unfinished goal ("Goal: Turn the power on  ($120 / $300)")
--   * rewards each goal ONCE when it's first done (XP through EconomyService, so 2x XP applies; saved in
--     Goals.Done[id] before anything is paid, so it can never pay twice) with a banner
-- The phone's Goals app (Apps/Goals.lua) shows the full list from the same rules.
--   GoalService.refresh(player)   re-check now (other systems may call it after a big change)
--   GoalService.GoalDone: Signal(player, goalId)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.MTL.Signal)
local Goals = require(ReplicatedStorage.MTL.Config.Goals)
local GoalRules = require(ReplicatedStorage.MTL.Rules.GoalRules)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local Notify = require(script.Parent.Notify)

local GoalService = {}
GoalService.GoalDone = Signal.new() -- (player, goalId)

local lastObjective: { [Player]: string } = {}
local CHECK_EVERY = 1.5

local function log(...)
	print("[MTL Goals]", ...)
end

function GoalService.refresh(player: Player)
	if StoryService.stage(player) ~= "FreePlay" then
		lastObjective[player] = nil
		return
	end
	local d = DataService.get(player)
	if not d then
		return
	end
	d.Goals = d.Goals or { Done = {} }
	d.Goals.Done = d.Goals.Done or {}
	local fresh = GoalRules.newlyDone(d)
	if #fresh > 0 then
		local xp = 0
		for _, e in fresh do
			d.Goals.Done[e.id] = os.time() -- recorded first: never paid twice
		end
		DataService.push(player)
		for _, e in fresh do
			if e.reward > 0 then
				xp += EconomyService.addXP(player, e.reward, "Goal:" .. e.id)
			end
			GoalService.GoalDone:Fire(player, e.id)
			log(player.Name, "goal done", e.id)
		end
		if #fresh == 1 then
			Notify.banner(player, "GOAL DONE", fresh[1].title .. (if xp > 0 then ("  ·  +" .. xp .. " XP") else ""))
		else
			Notify.banner(player, "GOALS DONE", #fresh .. " goals" .. (if xp > 0 then ("  ·  +" .. xp .. " XP") else ""))
		end
	end
	local text = GoalRules.objective(d, Goals.ObjectivePrefix)
	if text ~= lastObjective[player] then
		lastObjective[player] = text
		Notify.objective(player, text)
	end
end

function GoalService.init()
	StoryService.onEnter("FreePlay", function(player)
		lastObjective[player] = nil
		task.wait(1)
		GoalService.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastObjective[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(GoalService.refresh, player)
				if not ok then
					warn("[MTL Goals] refresh failed:", err)
				end
			end
		end
	end)
	log("ready:", #Goals.List, "goals")
end

return GoalService
