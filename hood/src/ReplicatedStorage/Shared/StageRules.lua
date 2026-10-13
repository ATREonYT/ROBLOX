-- Stage gates and runs (brief 23), the pure rules: used by the server's StageService (and WaveService, TravelService),
-- the clients (Stages, World) and the unit tests.
-- A gate is { Stage, WallId, Required, Z, HalfWidth }: stages run toward -Z in the map frame, and a player counts as
-- past a gate once they're on the street (|X| within HalfWidth + 2) beyond its line.
-- THE RUN: every trip out of the lobby is a run. A gate opens when you beat the crew of goons in the stage before it,
-- every run (gate 1, lobby -> Stage 1, is always open); going back to the lobby ends the run and every gate closes again.
-- Power no longer opens anything: a gate's Required is the "Recommended Power" on its sign (it is what beats the goons).
-- Run state per player (HoodServer/Runs keeps it, never saved): RunCleared, the highest stage whose crew you have beaten
-- this run (0 = none), and from it RunStage, the furthest gate open this run.
local StageRules = {}

StageRules.LOBBY_MARGIN = 3 -- studs past gate 1's line (on the lobby side) that already count as the lobby

local function whole(v)
	return type(v) == 'number' and v == v and v % 1 == 0 and v or nil
end

-- The furthest gate open in a run where `cleared` is the highest stage beaten: the next one (gate 1 always), at most
-- the last gate on the map.
function StageRules.runStage(cleared, lastGate)
	local c = math.max(0, whole(cleared) or 0)
	local last = whole(lastGate) or math.huge
	return math.clamp(c + 1, 1, math.max(1, last))
end

-- Gate `stage` is open in a run where `cleared` is the highest stage beaten (the crew of the stage before it is down).
function StageRules.gateOpen(stage, cleared)
	local s = whole(stage)
	if not s then return false end
	return s <= 1 or (whole(cleared) or 0) >= s - 1
end

-- A stage's pads (yellow Return, magenta 10x Cash) pay once its crew is down this run.
function StageRules.padReady(stage, cleared)
	local s = whole(stage)
	return s ~= nil and s >= 1 and (whole(cleared) or 0) >= s
end

-- Where you stand against the gates, in a run whose furthest open gate is `open` (RunStage):
--   newly      the open gates you are past that `passed` (WallId -> true: gates ever passed, saved) doesn't have yet;
--   blockedBy  the first gate past `open` that you stand beyond (at any depth): the server puts you back in front of it.
function StageRules.check(gates, pos, open, passed)
	local newly, blockedBy = {}, nil
	passed = type(passed) == 'table' and passed or {}
	open = type(open) == 'number' and open or 1
	for _, g in gates do
		if math.abs(pos.X) <= g.HalfWidth + 2 and pos.Z < g.Z then
			if g.Stage <= open then
				if not passed[g.WallId] then table.insert(newly, g) end
			elseif not blockedBy then
				blockedBy = g
			end
		end
	end
	return newly, blockedBy
end

-- On the lobby side of gate 1 (any X): being here ends a run.
function StageRules.inLobby(gates, pos)
	local first = gates[1]
	return first ~= nil and pos.Z > first.Z + StageRules.LOBBY_MARGIN
end

function StageRules.count(gates, cleared)
	local n = 0
	for _, g in gates do if cleared[g.WallId] then n += 1 end end
	return n
end

-- The furthest stage whose gate you have ever passed (0 for none).
function StageRules.furthest(gates, cleared)
	local best = 0
	for _, g in gates do if cleared[g.WallId] and g.Stage > best then best = g.Stage end end
	return best
end

-- World 1's trips (the World window's buttons, HoodClient/World): both end the run you are on. Lobby: the hall's spawn.
-- Stage1: just inside the Stage 1 gate, a fresh run.
StageRules.Trips = {
	{ Target = 'Lobby', Text = 'Lobby', Caption = 'Spawn' },
	{ Target = 'Stage1', Text = 'Stage 1', Caption = 'Start a run' },
}
StageRules.TripLand = 12 -- a Stage 1 trip lands this far past the gate's line

-- Where a trip goes: 'Lobby' -> 'Lobby'; 'Stage1' -> the Stage 1 gate (you land TripLand past it), or nil, 'locked' on a
-- map without gates; anything else (the retired 'Furthest' too) -> nil, 'unknown'. StageService and TravelService
-- both go through this.
function StageRules.travelTarget(gates, target)
	if target == 'Lobby' then return 'Lobby', nil end
	if target ~= 'Stage1' then return nil, 'unknown' end
	for _, g in gates or {} do
		if g.Stage == 1 then return g, nil end
	end
	return nil, 'locked'
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
