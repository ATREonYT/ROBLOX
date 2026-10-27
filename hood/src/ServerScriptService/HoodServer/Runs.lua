-- The run (brief 23), the server's one copy of it: every trip out of the lobby is a run. Beat a stage's crew and the
-- next gate opens for you (WaveService calls Runs.clear); go back to the lobby (a pad, a World trip, a respawn, walking
-- back in) and the run ends (StageService calls Runs.reset): every gate closes again and your goons come back fresh
-- (WaveService hears it through Runs.onReset). Nothing here is saved: a rejoin is a fresh run.
-- Player attributes (Stages.client, Waves.client and the goals read them):
--   RunCleared  the highest stage whose crew you have beaten this run (0 = none)
--   RunStage    the furthest gate open for you this run (StageRules.runStage: RunCleared + 1, at most the last gate)
-- A stage without goons never holds a run up: it counts as beaten as soon as the one before it is (WaveService tells
-- Runs which stages have crews; on a map with gates and no goons at all every gate is open).
-- The module is the server's tracker; Runs.new() makes a separate one (the unit tests).
local RS = game:GetService('ReplicatedStorage')
local StageRules = require(RS.Shared.StageRules)

local function tracker()
	local Runs = {}
	Runs.LastGate = math.huge -- the map's last gate (StageService sets it once it has read them)

	local crews, lastCrew = nil, 0 -- [stage] = true for stages with goons (Runs.setCrews); nil = not told yet
	local state = {} -- [player] = { Cleared (beaten this run), Started, Paid = { [stage] = true } }
	local hooks = {}

	local function set(player, name, value)
		if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
	end
	local function of(player)
		local s = state[player]
		if not s then
			s = { Cleared = 0, Started = false, Paid = {} }
			state[player] = s
		end
		return s
	end
	-- Beaten this run, carried on through stages that have no goons.
	local function effective(c)
		if not crews then return c end
		while c < lastCrew and not crews[c + 1] do c += 1 end
		return c
	end
	local function publish(player, s)
		local c = effective(s.Cleared)
		set(player, 'RunCleared', c)
		set(player, 'RunStage', StageRules.runStage(c, Runs.LastGate))
	end

	-- WaveService: which stages have a crew (stage -> a non-empty list or true) and the last stage with gates.
	function Runs.setCrews(hasCrew, lastStage)
		crews, lastCrew = {}, lastStage or 0
		for stage, list in hasCrew or {} do
			if type(stage) == 'number' and (type(list) ~= 'table' or #list > 0) then crews[stage] = true end
		end
		for player, s in state do publish(player, s) end
	end

	-- The highest stage beaten this run, and the furthest gate open.
	function Runs.cleared(player) return effective(of(player).Cleared) end
	function Runs.stage(player) return StageRules.runStage(Runs.cleared(player), Runs.LastGate) end
	function Runs.publish(player) publish(player, of(player)) end

	-- You walked into a stage: a run is on (so the lobby can end it).
	function Runs.start(player)
		of(player).Started = true
	end

	-- A crew beaten: returns true when it opened a gate that was shut this run.
	function Runs.clear(player, stage)
		local s = of(player)
		s.Started = true
		if type(stage) ~= 'number' or stage ~= stage or stage <= s.Cleared then return false end
		local before = effective(s.Cleared)
		s.Cleared = stage
		publish(player, s)
		return effective(stage) > before
	end

	-- A pad pays once a run: true the first time for that stage, and only once its crew is down.
	function Runs.claim(player, stage)
		local s = of(player)
		if not StageRules.padReady(stage, effective(s.Cleared)) or s.Paid[stage] then return false end
		s.Paid[stage] = true
		return true
	end

	-- The run ends (why: 'pad', 'trip', 'respawn', 'lobby'): every gate shuts again and the goons come back. Returns true
	-- when there was a run to end (a player standing in the lobby with nothing started costs nothing).
	function Runs.reset(player, why)
		local s = of(player)
		if not s.Started and s.Cleared == 0 and next(s.Paid) == nil then
			publish(player, s)
			return false
		end
		s.Cleared, s.Started, s.Paid = 0, false, {}
		publish(player, s)
		for _, fn in hooks do
			local ok, err = pcall(fn, player, why)
			if not ok then warn('[Runs] ' .. tostring(err)) end
		end
		return true
	end

	-- fn(player, why) runs whenever a run ends.
	function Runs.onReset(fn) table.insert(hooks, fn) end
	-- The player left: their run is gone.
	function Runs.forget(player) state[player] = nil end

	return Runs
end

local Runs = tracker()
Runs.new = tracker -- (StageService calls Runs.forget when a player leaves)

return Runs
