--!strict
-- Pure tutorial logic (no Instances; tested in tools/tests/test_tutorial_rules.py). Config: Config/Tutorial.lua.
local TutorialRules = {}

local function indexOf(list: { string }, v: string): number?
	for i, s in list do
		if s == v then
			return i
		end
	end
	return nil
end

-- The step to show now: (index, step) or nil.
--   steps = Config/Tutorial.Steps, doneCount = Settings.Tutorial (0..#steps or Skipped), stage = the story stage,
--   order = Config/Story.Stages. Steps whose stages are all behind the player are passed over (count as done);
--   a step whose stages are still ahead waits (nil).
function TutorialRules.current(steps: { any }, doneCount: number?, stage: string?, order: { string }): (number?, any?)
	local done = doneCount or 0
	if done >= #steps or stage == nil then
		return nil, nil
	end
	local here = indexOf(order, stage)
	if not here then
		return nil, nil
	end
	for i = done + 1, #steps do
		local step = steps[i]
		local last = 0
		local first = math.huge
		for _, s in step.stages or {} do
			local k = indexOf(order, s)
			if k then
				last = math.max(last, k)
				first = math.min(first, k)
			end
		end
		if indexOf(step.stages or {}, stage) then
			return i, step
		elseif here < first then
			return nil, nil -- not there yet: wait
		end
		-- here > last: this step's moment has passed, look at the next one
	end
	return nil, nil
end

-- How many steps count as done once the story is at `stage` (used to save progress when steps are passed over).
function TutorialRules.passed(steps: { any }, doneCount: number?, stage: string?, order: { string }): number
	local done = doneCount or 0
	if done >= #steps then
		return done
	end
	local i = TutorialRules.current(steps, done, stage, order)
	if i then
		return i - 1
	end
	-- nothing to show: either waiting for a later stage, or everything has passed
	local here = stage and indexOf(order, stage) or 0
	local n = done
	for k = done + 1, #steps do
		local first = math.huge
		for _, s in steps[k].stages or {} do
			first = math.min(first, indexOf(order, s) or math.huge)
		end
		if (here :: number) < first then
			break
		end
		n = k
	end
	return n
end

-- The text for the player's device: body may be a string or { kb, touch, pad }.
function TutorialRules.text(value: any, device: string): string
	if type(value) == "string" then
		return value
	elseif type(value) == "table" then
		return value[device] or value.kb or ""
	end
	return ""
end

-- Key chips for the device (touch shows none unless the step lists some).
function TutorialRules.keys(step: any, device: string): { string }
	local keys = step.keys
	if type(keys) ~= "table" then
		return {}
	end
	return keys[device] or {}
end

function TutorialRules.finished(steps: { any }, doneCount: number?): boolean
	return (doneCount or 0) >= #steps
end

return TutorialRules
