--!strict
-- Pure Freight maths (both sides; unit-testable in tools/tests).
local FreightRules = {}

-- $ per crate for a sale of n crates (linear between the curve points, flat past the ends).
function FreightRules.each(n: number, curve: { { number } }): number
	if n <= curve[1][1] then
		return curve[1][2]
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if n <= b[1] then
			local t = (n - a[1]) / (b[1] - a[1])
			return math.floor(a[2] + (b[2] - a[2]) * t + 0.5)
		end
	end
	return curve[#curve][2]
end

function FreightRules.total(n: number, curve: { { number } }): number
	return FreightRules.each(n, curve) * n
end

function FreightRules.drops(n: number, table_: { { number } }): number
	local d = 1
	for _, row in table_ do
		if n >= row[1] then
			d = row[2]
		end
	end
	return d
end

-- Split n crates over d drops as evenly as possible (first drops take the remainder).
function FreightRules.split(n: number, d: number): { number }
	local out = {}
	local base = math.floor(n / d)
	local extra = n - base * d
	for i = 1, d do
		out[i] = base + (if i <= extra then 1 else 0)
	end
	return out
end

return FreightRules
