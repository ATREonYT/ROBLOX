--!strict
-- Pure helpers for missions and the meet (no Instances, unit-tested in tools/tests/test_story_rules.py).
local MissionRules = {}

-- Picks one meet spot. `roll` is a random number in [0, 1) (the server rolls it once and saves the result).
function MissionRules.pickSpot(spots: { any }, roll: number): any?
	if #spots == 0 then
		return nil
	end
	local i = math.clamp(math.floor(roll * #spots) + 1, 1, #spots)
	return spots[i]
end

function MissionRules.findSpot(spots: { any }, id: any): any?
	for _, s in spots do
		if s.Id == id then
			return s
		end
	end
	return nil
end

function MissionRules.stepIndex(def: any, stepId: any): number?
	for i, s in def.Steps do
		if s.id == stepId then
			return i
		end
	end
	return nil
end

function MissionRules.step(def: any, index: number): any?
	return def.Steps[index]
end

function MissionRules.isLast(def: any, index: number): boolean
	return index >= #def.Steps
end

-- A held step is long enough (server side; `share` forgives lag, e.g. 0.75).
function MissionRules.holdOk(needSeconds: number, elapsed: number, share: number): boolean
	return elapsed >= needSeconds * share
end

-- Flat (x/z) facing check: is the target in front of `look` within `minDot` (cosine) and within `range`?
function MissionRules.facingOk(fromX: number, fromZ: number, lookX: number, lookZ: number, toX: number, toZ: number, minDot: number, range: number): boolean
	local dx, dz = toX - fromX, toZ - fromZ
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > range then
		return false
	end
	if dist < 0.5 then
		return true
	end
	local ll = math.sqrt(lookX * lookX + lookZ * lookZ)
	if ll < 1e-6 then
		return false
	end
	local dot = (dx / dist) * (lookX / ll) + (dz / dist) * (lookZ / ll)
	return dot >= minDot
end

-- What the job pays before multipliers. escapeSeconds = alarm -> car (nil = not measured, no bonus).
function MissionRules.payout(def: any, escapeSeconds: number?): (number, number, boolean)
	local take = def.Pay or 0
	local clean = escapeSeconds ~= nil and def.CleanGetaway ~= nil and escapeSeconds <= def.CleanGetaway.Seconds
	local bonus = if clean then def.CleanGetaway.Bonus else 0
	return take, bonus, clean
end

-- The checklist the client shows: { {id, text, done, current} }.
function MissionRules.checklist(def: any, index: number): { any }
	local out = {}
	for i, s in def.Steps do
		table.insert(out, { id = s.id, text = s.text, done = i < index, current = i == index })
	end
	return out
end

-- "0:25"
function MissionRules.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

return MissionRules
