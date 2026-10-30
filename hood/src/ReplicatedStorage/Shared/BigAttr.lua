-- Big whole numbers kept as attributes (Oct 27: World 2's gate Power reads in the billions).
-- Lune, which writes the place files (tools/place/build_place.sh), stores a whole-number attribute as a 32-bit integer,
-- so anything past 2,147,483,647 came out wrapped (World 2's gate 4 read negative in the built place). A whole number
-- that big is stored as its digits, a string, and read back with BigAttr.get / BigAttr.decode; every other value stays
-- as it is. Both worlds' maps write the gates' Required this way, and everything that reads it decodes it.
local BigAttr = {}

BigAttr.Limit = 2 ^ 31

-- The value to store for n.
function BigAttr.encode(n: any): any
	if type(n) == 'number' and n == n and math.abs(n) ~= math.huge and n % 1 == 0 and math.abs(n) >= BigAttr.Limit then
		return string.format('%.0f', n)
	end
	return n
end

-- The number a stored value stands for (a string of digits back to its number; anything else as it is).
function BigAttr.decode(v: any): any
	if type(v) == 'string' then return tonumber(v) end
	return v
end

function BigAttr.set(inst: Instance, name: string, n: any)
	inst:SetAttribute(name, BigAttr.encode(n))
end

function BigAttr.get(inst: Instance, name: string): any
	return BigAttr.decode(inst:GetAttribute(name))
end

return BigAttr
