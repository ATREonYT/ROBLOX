--!strict
-- Pure rules for Liberty OS (both sides). Gates: is an app open for this save snapshot, and if not, why.
local OSRules = {}

export type Gate = { level: number?, path: string?, own: { string }?, stage: string? }

-- data = the save (server) or the public snapshot (client). Returns ok, reason ("Level 8", "Criminal life only",
-- "Own a stash house").
function OSRules.gate(gate: Gate?, data: any, ownedTitle: ((string) -> string)?): (boolean, string?)
	if not gate or not data then
		return true, nil
	end
	if gate.level and (data.Level or 1) < gate.level then
		return false, "Level " .. gate.level
	end
	if gate.path and data.Path ~= gate.path then
		return false, gate.path .. " life only"
	end
	if gate.own then
		local owned = data.Realty and data.Realty.Owned or {}
		for _, id in gate.own do
			if owned[id] then
				return true, nil
			end
		end
		local first = gate.own[1]
		return false, "Buy " .. (if ownedTitle then ownedTitle(first) else first)
	end
	return true, nil
end

-- The cap on one coin position for a level (Config/Coins.MaxPosition, sorted by level).
function OSRules.coinCap(level: number, table_: { { level: number, cap: number } }): number
	local cap = 0
	for _, row in table_ do
		if level >= row.level then
			cap = row.cap
		end
	end
	return cap
end

-- "2:14 PM" from minutes after midnight.
function OSRules.clock(minutes: number): string
	local m = math.floor(minutes) % 1440
	local h = math.floor(m / 60)
	local mm = m % 60
	local suffix = if h >= 12 then "PM" else "AM"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, mm, suffix)
end

-- Price formatting for tiny coin prices: $0.0000412 -> "$0.0₄412" style is too clever; keep 3 significant digits.
function OSRules.price(p: number): string
	if p >= 1 then
		return string.format("$%.2f", p)
	elseif p <= 0 then
		return "$0"
	end
	local digits = math.max(2, math.ceil(-math.log10(p)) + 2)
	return string.format("$%." .. digits .. "f", p)
end

function OSRules.pct(x: number): string
	local s = string.format("%+.1f%%", x * 100)
	return s
end

return OSRules
