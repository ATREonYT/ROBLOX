--!strict
-- Number and price text used across the UI.
local Format = {}

-- U+E002 is the character Roblox's own fonts draw as the official Robux icon.
Format.RobuxMark = utf8.char(0xE002)

function Format.commas(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return (n < 0 and "-" or "") .. out
end

function Format.robux(n: number): string
	return Format.RobuxMark .. " " .. Format.commas(n)
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

return Format
