-- Stage gate rules: which gates a player has just cleared, and whether they slipped past one they
-- can't open yet. Used by the server's StageService; kept pure so the unit tests can drive it.
-- A gate is { Stage, WallId, Required, Z, HalfWidth }: stages run toward -Z in the map frame, and a
-- player counts as past a gate once they're on the street (|X| within HalfWidth + 2) beyond its line.
-- A gate you have passed once stays open for good: a rebirth resets your Power, never the map you have opened.
local StageRules = {}

StageRules.SLIP_DEPTH = 12 -- how far past a locked gate still counts as slipping through it

-- waveCleared (optional): the highest stage whose target wave the player has cleared (WaveService's WaveCleared).
-- Given, gate i (i >= 2) also needs it to be at least i - 1 (the targets in the stage before it are down); nil keeps
-- the Power-only rule. Gates in `cleared` (WallId -> true) are open whatever your Power.
function StageRules.check(gates, pos, power, cleared, waveCleared)
	local newly, blockedBy = {}, nil
	for _, g in gates do
		if math.abs(pos.X) <= g.HalfWidth + 2 and pos.Z < g.Z and not cleared[g.WallId] then
			local wavesDown = type(waveCleared) ~= 'number' or g.Stage <= 1 or waveCleared >= g.Stage - 1
			if power >= g.Required and wavesDown then
				table.insert(newly, g)
			elseif pos.Z > g.Z - StageRules.SLIP_DEPTH and not blockedBy then
				blockedBy = g
			end
		end
	end
	return newly, blockedBy
end

function StageRules.count(gates, cleared)
	local n = 0
	for _, g in gates do if cleared[g.WallId] then n += 1 end end
	return n
end

-- The furthest stage whose gate you have passed (0 for none).
function StageRules.furthest(gates, cleared)
	local best = 0
	for _, g in gates do if cleared[g.WallId] and g.Stage > best then best = g.Stage end end
	return best
end

-- Reads gate models (tagged 'HoodStageGate') into sorted gate tables.
function StageRules.fromModels(models)
	local gates = {}
	for _, m in models do
		table.insert(gates, {
			Stage = m:GetAttribute('Stage'), WallId = m:GetAttribute('WallId'), Required = m:GetAttribute('Required') or 0,
			Reward = m:GetAttribute('Reward') or 0, Z = m:GetAttribute('LineZ'), HalfWidth = m:GetAttribute('HalfWidth') or 20,
		})
	end
	table.sort(gates, function(a, b) return a.Stage < b.Stage end)
	return gates
end

return StageRules
