--!strict
-- Versioned data migrations. When ProfileData's shape changes, bump
-- CURRENT_VERSION and add a numbered step that upgrades version N-1 → N.
-- Steps run in order on load, so a player away for a year still lands on
-- today's shape. Reconcile() handles ADDED fields; steps are for RESHAPED ones.

local Migrations = {}

Migrations.CURRENT_VERSION = 1

-- steps[n] upgrades data FROM version n-1 TO version n.
local steps: { [number]: (data: any) -> () } = {
	-- Example for the future:
	-- [2] = function(data)
	-- 	data.Gear.Monitor = 0 -- new fourth ladder
	-- end,
}

function Migrations.run(data: any): number
	local ran = 0
	local version = tonumber(data.DataVersion) or 1
	while version < Migrations.CURRENT_VERSION do
		local step = steps[version + 1]
		if step then
			step(data)
		end
		version += 1
		data.DataVersion = version
		ran += 1
	end
	return ran
end

return Migrations
