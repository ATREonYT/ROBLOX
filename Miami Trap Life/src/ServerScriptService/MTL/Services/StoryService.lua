--!strict
-- The story stage machine (Master Plan §1). Stages only move forward, only here.
-- Systems register what happens when a player ENTERS a stage with onEnter(stage, fn(player, resumed)).
-- `resumed` is true when the player rejoined mid-stage: re-send waypoints/texts, don't re-grant rewards.
--
-- Piece 0 wires the first two stages as the working example:
--   Arrive     -> objective + waypoint to the Food Mart door; arriving advances to FirstShift
--   FirstShift -> reaching Config.Levels.CriminalCallLevel advances to TheCall (the Phone/Story pieces handle the call)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.MTL.Config.Story)
local Levels = require(ReplicatedStorage.MTL.Config.Levels)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Signal = require(ReplicatedStorage.MTL.Signal)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)
local Analytics = require(script.Parent.Analytics)

local StoryService = {}
StoryService.StageChanged = Signal.new() -- (player, newStage, oldStage)

local enterHooks: { [string]: { (Player, boolean) -> () } } = {}

local function log(...)
	print("[MTL Story]", ...)
end

function StoryService.stage(player: Player): string?
	local data = DataService.get(player)
	return if data then data.Story.Stage else nil
end

function StoryService.reached(player: Player, target: string): boolean
	local s = StoryService.stage(player)
	return s ~= nil and StoryRules.reached(s, target)
end

-- Per-stage scratch data saved with the profile (e.g. which meet spot was picked).
function StoryService.data(player: Player): { [string]: any }?
	local data = DataService.get(player)
	return if data then data.Story.Data else nil
end

-- The level the unknown number calls at, for THIS player (A/B test: Config/Levels.CallLevelTest).
function StoryService.callLevel(player: Player): number
	local v = player:GetAttribute("MTL_CallLevel")
	return if type(v) == "number" then v else Levels.CriminalCallLevel
end

function StoryService.onEnter(stage: string, fn: (Player, boolean) -> ())
	assert(StoryRules.isValid(stage), "[MTL Story] unknown stage " .. stage)
	enterHooks[stage] = enterHooks[stage] or {}
	table.insert(enterHooks[stage], fn)
end

local function runEnter(player: Player, stage: string, resumed: boolean)
	player:SetAttribute("MTL_Stage", stage)
	local objective = Story.Objectives[stage]
	if objective and objective ~= "" then
		Notify.objective(player, objective)
	end
	for _, fn in enterHooks[stage] or {} do
		task.spawn(function()
			local ok, err = pcall(fn, player, resumed)
			if not ok then
				warn("[MTL Story] onEnter", stage, "failed:", err)
			end
		end)
	end
end

-- Moves the player from `fromStage` to the next stage. Does nothing if they aren't at `fromStage`
-- (so double calls and late events are harmless). Returns true if it moved.
function StoryService.advance(player: Player, fromStage: string): boolean
	local data = DataService.get(player)
	if not data or data.Story.Stage ~= fromStage then
		return false
	end
	local nextStage = StoryRules.nextOf(fromStage)
	if not nextStage then
		return false
	end
	data.Story.Done[fromStage] = os.time()
	data.Story.Stage = nextStage
	log(player.Name, fromStage, "->", nextStage)
	Analytics.onboarding(player, StoryRules.index(nextStage) :: number, nextStage)
	DataService.push(player)
	StoryService.StageChanged:Fire(player, nextStage, fromStage)
	runEnter(player, nextStage, false)
	return true
end

-- Studio/debug only: jump a player to any stage (used by threads to test their piece without replaying the story).
function StoryService.debugSet(player: Player, stage: string)
	assert(game:GetService("RunService"):IsStudio(), "[MTL Story] debugSet is Studio-only")
	local data = DataService.get(player)
	if data and StoryRules.isValid(stage) then
		data.Story.Stage = stage
		DataService.push(player)
		runEnter(player, stage, false)
	end
end

function StoryService.init()
	DataService.Ready:Connect(function(player, data)
		-- call-level A/B: assign once per save (only players who haven't had the call yet), remember it
		local test = Levels.CallLevelTest
		if test and test.Enabled then
			local sd = data.Story.Data
			if sd.CallTest == nil and not StoryRules.reached(data.Story.Stage, "TheCall") then
				sd.CallTest = if math.random() < (test.ShareB or 0.5) then "B" else "A"
				Analytics.custom(player, "CallLevelTest", if sd.CallTest == "B" then test.B else test.A, { Variant = sd.CallTest })
			end
			if sd.CallTest == "B" then
				player:SetAttribute("MTL_CallLevel", test.B)
			elseif sd.CallTest == "A" then
				player:SetAttribute("MTL_CallLevel", test.A)
			end
		end
		local stage = data.Story.Stage
		local isNew = stage == StoryRules.first() and data.Stats.Joins <= 1
		if isNew then
			Analytics.onboarding(player, 1, stage)
		end
		-- wait for the character so waypoints/cutscenes have someone to point at
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1)
		runEnter(player, stage, not isNew)
	end)

	-- Stage 1: Arrive -> walk to the Food Mart
	StoryService.onEnter("Arrive", function(player)
		WaypointService.set(player, "Story", Locations.FoodMart.Door, {
			label = "Liberty Food Mart",
			radius = Locations.FoodMart.Radius,
		})
	end)
	WaypointService.Arrived:Connect(function(player, id)
		if id == "Story" and StoryService.stage(player) == "Arrive" then
			StoryService.advance(player, "Arrive")
		end
	end)

	-- Stage 2: FirstShift -> the Jobs piece runs the shift; reaching the call level moves the story on
	EconomyService.LevelUp:Connect(function(player, level)
		if level >= StoryService.callLevel(player) then
			StoryService.advance(player, "FirstShift")
		end
	end)
	StoryService.onEnter("FirstShift", function(player)
		local data = DataService.get(player)
		if data and data.Level >= StoryService.callLevel(player) then
			StoryService.advance(player, "FirstShift") -- already high enough (e.g. levelled during a resume)
		end
	end)
end

return StoryService
