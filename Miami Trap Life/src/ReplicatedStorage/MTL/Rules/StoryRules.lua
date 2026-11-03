--!strict
-- Pure helpers over the stage list in Config/Story.
local Story = require(script.Parent.Parent.Config.Story)

local StoryRules = {}

local indexOf: { [string]: number } = {}
for i, id in Story.Stages do
	indexOf[id] = i
end

function StoryRules.index(stage: string): number?
	return indexOf[stage]
end

function StoryRules.isValid(stage: any): boolean
	return type(stage) == "string" and indexOf[stage] ~= nil
end

function StoryRules.first(): string
	return Story.Stages[1]
end

function StoryRules.nextOf(stage: string): string?
	local i = indexOf[stage]
	return if i then Story.Stages[i + 1] else nil
end

-- true when `stage` is `target` or later
function StoryRules.reached(stage: string, target: string): boolean
	local a, b = indexOf[stage], indexOf[target]
	return a ~= nil and b ~= nil and a >= b
end

-- Free play (switching path, all apps) is open from MissionDone on.
function StoryRules.freePlayOpen(stage: string): boolean
	return StoryRules.reached(stage, "MissionDone")
end

return StoryRules
