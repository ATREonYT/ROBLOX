--!strict
-- THE currency formatter. Client and server both use this one module so a
-- number can never display differently in two places (§11).

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

-- 1234 → "1.23K", 1500000 → "1.5M", 999 → "999". Trailing zeros trimmed.
function Format.abbreviate(value: number): string
	if value ~= value then -- NaN guard: display should never crash on bad data
		return "0"
	end
	if value < 0 then
		return "-" .. Format.abbreviate(-value)
	end
	if value < 1000 then
		-- Below 1K show whole numbers only; fractional clicks don't exist.
		return tostring(math.floor(value))
	end
	local magnitude = math.floor(math.log10(value) / 3)
	magnitude = math.min(magnitude, #SUFFIXES - 1)
	local scaled = value / 1000 ^ magnitude
	local text: string
	if scaled >= 100 then
		text = ("%.0f"):format(scaled)
	elseif scaled >= 10 then
		text = ("%.1f"):format(scaled)
	else
		text = ("%.2f"):format(scaled)
	end
	-- "1.50" → "1.5", "2.00" → "2"
	text = text:gsub("%.?0+$", "")
	return text .. SUFFIXES[magnitude + 1]
end

-- Full thousands-separated form for tooltips: 1234567 → "1,234,567".
function Format.commas(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local text = tostring(math.floor(math.abs(value)))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. formatted
end

-- "2m 05s" style for respawn/cooldown labels.
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return ("%ds"):format(seconds)
	end
	return ("%dm %02ds"):format(seconds // 60, seconds % 60)
end

return Format
