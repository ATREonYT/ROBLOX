--!strict
-- The welcome scenes that bring a NEW player into the story (Research: Cinematic Cutscenes):
--   Arrive     (first join only) -> cutscene "Welcome": the city, you, Mr. Patel's text, hand-off at the spawn
--   FirstShift (first time only) -> cutscene "FirstDay": Mr. Patel meets you inside Liberty Food Mart
-- Both are skippable; skipping changes nothing else (the waypoint, texts and shift run as before, the tutorial
-- coach waits until the scene is over). Returning players (resumed) never see them again.
-- Studio: set workspace attribute MTL_SkipWelcome = true to skip both while testing other pieces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local StoryService = require(script.Parent.StoryService)
local CutsceneService = require(script.Parent.CutsceneService)

local StoryWelcome = {}

local function skipped(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("MTL_SkipWelcome") == true
end

-- The store scene's anchor: standing inside the door, looking into the store (local -Z = into the store).
function StoryWelcome.storeAnchor(): CFrame
	local door, inside = Locations.FoodMart.Door, Locations.FoodMart.Inside
	return CFrame.lookAt(door, Vector3.new(inside.X, door.Y, inside.Z))
end

function StoryWelcome.init()
	StoryService.onEnter("Arrive", function(player, resumed)
		if resumed or skipped() then
			return
		end
		CutsceneService.play(player, "Welcome", { anchor = CFrame.new(Locations.Spawn) })
	end)
	StoryService.onEnter("FirstShift", function(player, resumed)
		if resumed or skipped() then
			return
		end
		CutsceneService.play(player, "FirstDay", { anchor = StoryWelcome.storeAnchor() })
	end)
end

return StoryWelcome
