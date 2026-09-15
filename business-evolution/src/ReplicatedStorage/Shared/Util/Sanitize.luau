--!strict
-- Number hygiene for everything that touches saved data (§13.9).
-- ProfileStore saves silently fail on NaN/inf, so every write funnels through
-- here rather than trusting call sites to remember.

local Sanitize = {}

local MAX = 1e300

-- Clamp to [0, 1e300] and squash NaN/inf to a safe fallback.
function Sanitize.stat(value: number, fallback: number?): number
	local safe = fallback or 0
	if typeof(value) ~= "number" then
		return safe
	end
	if value ~= value then -- NaN
		return safe
	end
	if value == math.huge or value == -math.huge then
		return safe
	end
	return math.clamp(value, 0, MAX)
end

-- Deep-check a table for JSON-unsafe values before it ever reaches a save.
-- Returns false + a path string for the first offender (used by tests and a
-- defensive assert in DataService).
function Sanitize.validateSavable(value: any, path: string?): (boolean, string?)
	local here = path or "Data"
	local kind = typeof(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, here .. " is NaN/inf"
		end
		return true, nil
	elseif kind == "string" or kind == "boolean" then
		return true, nil
	elseif kind == "table" then
		local sawNumberKey = false
		local sawStringKey = false
		for key, child in value do
			local keyKind = typeof(key)
			if keyKind == "number" then
				sawNumberKey = true
			elseif keyKind == "string" then
				sawStringKey = true
			else
				return false, here .. " has a " .. keyKind .. " key"
			end
			if sawNumberKey and sawStringKey then
				return false, here .. " mixes string and number keys"
			end
			local ok, why = Sanitize.validateSavable(child, here .. "." .. tostring(key))
			if not ok then
				return false, why
			end
		end
		if sawNumberKey then
			-- Sparse arrays JSON-encode as objects and corrupt on load.
			local count = 0
			for _ in value do
				count += 1
			end
			if count ~= #value then
				return false, here .. " is a sparse array"
			end
		end
		return true, nil
	end
	return false, here .. " is a " .. kind .. " (userdata is never savable)"
end

return Sanitize
