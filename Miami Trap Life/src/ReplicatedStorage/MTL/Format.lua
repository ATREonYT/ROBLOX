--!strict
local Format = {}

-- 1234567 -> "$1,234,567"
function Format.cash(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-$" else "$") .. out
end

-- 1500 -> "1.5K", 2300000 -> "2.3M"
function Format.short(n: number): string
	local a = math.abs(n)
	local s
	if a >= 1e9 then
		s = string.format("%.1fB", n / 1e9)
	elseif a >= 1e6 then
		s = string.format("%.1fM", n / 1e6)
	elseif a >= 1e4 then
		s = string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n + 0.5))
	end
	return (s:gsub("%.0([BMK])$", "%1"))
end

-- studs -> "120 m", rounded to 5 (shown 1 stud = 1 m, like most RP games; real scale reads too small)
function Format.distance(studs: number): string
	if studs >= 1000 then
		return string.format("%.1f km", studs / 1000)
	end
	return string.format("%d m", math.floor(studs / 5 + 0.5) * 5)
end

return Format
