--!strict
--[[
	Old saves of crates that are gone. The Oct 19 Knife Crate became the owner's three knife crates (Oct 20: "make these
	crates for the opening of the normal knifes"): Shinobi Dojo Chest, Elemental Storm Vault, Void Beast Chest. A kid's
	pity counter for the Knife Crate (opens since its last Legendary) must not be lost: on load (HuzzServer/DataService)
	it moves into the knife crate with the highest count already (the Dojo Chest when none has one), keeping the higher
	of the two, and the old entry is cleared. Any crate keys for it (none were ever sold, but a save could hold one)
	go to that crate as well. Nothing else in a save counts per crate. Pure: tests/CrateSaves.spec.luau.
]]
local CrateSaves = {}

-- old crate id -> the crates that replaced it (the first one is the default)
CrateSaves.Retired = {
	Knife = { "Dojo", "Storm", "Beast" },
} :: { [string]: { string } }

-- Moves anything saved for a retired crate into its replacement. Returns true when the save changed.
function CrateSaves.migrate(data: any): boolean
	local changed = false
	data.Pity = data.Pity or {}
	data.CrateKeys = data.CrateKeys or {}
	for old, into in CrateSaves.Retired do
		local pity, keys = data.Pity[old], data.CrateKeys[old]
		if pity ~= nil or keys ~= nil then
			local target, best = into[1], -1
			for _, id in into do
				local n = data.Pity[id]
				if type(n) == "number" and n > best then target, best = id, n end
			end
			if type(pity) == "number" then
				data.Pity[target] = math.max(data.Pity[target] or 0, pity)
			end
			if type(keys) == "number" and keys > 0 then
				data.CrateKeys[target] = (data.CrateKeys[target] or 0) + keys
			end
			data.Pity[old], data.CrateKeys[old] = nil, nil
			changed = true
		end
	end
	return changed
end

return CrateSaves
