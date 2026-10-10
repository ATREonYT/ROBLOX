-- Stage waves (brief 18, runs brief 23): every stage street and the Boss Yard (16) holds a small wave of cartoon
-- rival-crew goons (Shared/EnemyRules: who, where, how tough, how they chase and punch). Pure bookkeeping shared by
-- WaveService (which decides), Waves.client (which shows and aims) and the unit tests:
--   Each player has their own wave per stage. A hit deals your Power as damage (EnemyRules.damage); the server pays the
--   x1 shot's "+N" Power for it. The last goon down clears the wave and opens the next gate for the rest of the run
--   (HoodServer/Runs, StageRules.gateOpen). A cleared wave stays down until the run ends (back in the lobby: the session
--   is reset and every crew stands again). The first clear of a stage EVER pays a little Cash (Balance.WaveCash; the
--   saved best is WaveCleared), a later one repeatReward (ECON: 0 now, the pads before the gate pay instead).
local ShotRules = require(script.Parent.ShotRules)
local Balance = require(script.Parent.Config.Balance)
local EnemyRules = require(script.Parent.EnemyRules)

local WaveRules = {}

WaveRules.Range = EnemyRules.FightRange -- studs from you to a goon for a shot (the server adds EnemyRules.Slack)
WaveRules.LastDepth = 120 -- the last gate's arena (the Boss Yard) runs this far past its line
WaveRules.MaxStage = 64 -- sanity cap on stage numbers from the network
WaveRules.MaxIndex = 32 -- and on goon indices
-- (Older names, kept for readers of the target waves: the lineups and HP are EnemyRules' now.)
WaveRules.Lineups = EnemyRules.Lineups
WaveRules.maxHp = EnemyRules.maxHp

local function int(v: any): number?
	if type(v) ~= 'number' or v ~= v or v % 1 ~= 0 then return nil end
	return v
end

-- Cash for a stage's first clear ever (Balance.WaveCash; ECON: 0 now, the pad is the run's one big number; 0 for a
-- stage the table doesn't know).
function WaveRules.reward(stage: any): number
	local s = int(stage)
	return s and Balance.WaveCash[s] or 0
end

-- Cash for clearing a stage's wave again (a later run): Balance.WaveRepeatShare of the stage's gate Cash (0 is fine:
-- the CLEAR! moment then shows no Cash).
function WaveRules.repeatReward(stage: any): number
	return math.max(0, math.floor(Balance.stageCash(int(stage)) * (Balance.WaveRepeatShare or 0)))
end

-- The stage whose arena `pos` (map frame) stands in: past gate i's line and before gate i+1's, on the street
-- (|X| within the gate's HalfWidth + 2). `gates` as StageRules.fromModels returns them (sorted by Stage).
function WaveRules.stageAt(gates: { any }, pos: Vector3): number?
	for n, g in gates do
		local after = gates[n + 1]
		local far = after and after.Z or (g.Z - WaveRules.LastDepth)
		if math.abs(pos.X) <= g.HalfWidth + 2 and pos.Z < g.Z and pos.Z >= far then return g.Stage end
	end
	return nil
end

-- The WaveCleared a player has: their saved best, carried on through stages that have no goons (a map without waves in
-- some stages never blocks a gate on them). hasWave: stage -> truthy.
function WaveRules.effective(saved: any, hasWave: { [number]: any }, lastStage: number): number
	local c = math.max(0, int(saved) or 0)
	while c < lastStage and not hasWave[c + 1] do c += 1 end
	return c
end

-- Profiles from before the waves: every stage up to the furthest gate they had passed counts as cleared, so the
-- next gate asks only for its Power, as it did when they last played (nobody is re-locked). Reads the World 1 wall
-- ids (HoodW1Stage<N>) from ClearedWalls.
function WaveRules.legacy(clearedWalls: any): number
	local best = 0
	if type(clearedWalls) ~= 'table' then return 0 end
	for id, on in clearedWalls do
		if on == true and type(id) == 'string' then
			local n = tonumber(string.match(id, '^HoodW1Stage(%d+)$'))
			if n and n > best and n <= WaveRules.MaxStage then best = n end
		end
	end
	return best
end

-- Makes a profile's Waves table safe: { Cleared = whole number 0..MaxStage }.
function WaveRules.sanitize(waves: any): any
	if type(waves) ~= 'table' then return { Cleared = 0 } end
	waves.Cleared = math.clamp(int(waves.Cleared) or 0, 0, WaveRules.MaxStage)
	return waves
end

-- A fresh wave of `enemies` ({ {Kind, Home}, ... } in index order; plain kind names work too, standing at the origin) in
-- a stage: each goon's HP, and the goons themselves (EnemyRules.new) on their spots.
function WaveRules.spawn(stage: number, enemies: { any }): any
	local w = { Stage = stage, HP = {}, Max = {}, Goons = {}, Left = #enemies, Cleared = #enemies == 0, Away = false }
	for i, e in enemies do
		local kind = type(e) == 'table' and e.Kind or e
		local home = type(e) == 'table' and e.Home or Vector3.zero
		local hp = EnemyRules.maxHp(stage, kind)
		w.HP[i], w.Max[i] = hp, hp
		w.Goons[i] = EnemyRules.new(kind, home, (i - 1) / math.max(1, #enemies))
	end
	return w
end

-- Damage on goon `index`: returns (hit, downed, cleared). A goon already down, or a cleared wave, takes nothing.
function WaveRules.hit(w: any, index: number, damage: number): (boolean, boolean, boolean)
	local hp = w.HP[index]
	if type(hp) ~= 'number' or hp <= 0 or w.Cleared then return false, false, false end
	hp = math.max(0, hp - math.max(0, damage))
	w.HP[index] = hp
	if hp > 0 then return true, false, false end
	local g = w.Goons and w.Goons[index]
	if g then g.State = EnemyRules.Down end
	w.Left = math.max(0, w.Left - 1)
	if w.Left == 0 then
		w.Cleared = true
		return true, true, true
	end
	return true, true, false
end

---------------------------------------------------------------------------------------------- one player's waves
-- WaveRules.session(world, clock, arenas): the server keeps one per player (world and arenas from EnemyRules.world).
-- :move(stage) as they walk (0/nil = not in a stage with goons) spawns a wave the first time they enter that stage in a
-- run; an unfinished wave keeps its HP while they step out (its goons walk home); a cleared one stays down for the rest
-- of the run. :reset() ends the run (every crew stands again, fresh). :tick(dt, you) runs the goons; :shoot(stage,
-- index, from, damage) checks a shot and applies it; :knockout() sends the goons home calm.
local Session = {}
Session.__index = Session

function WaveRules.session(world: { [number]: { any } }, clock: () -> number, arenas: { [number]: any }?): any
	return setmetatable({ World = world, Arenas = arenas or {}, Clock = clock, Stage = 0, Waves = {}, Tokens = ShotRules.Burst, Last = clock(), CalmUntil = -math.huge }, Session)
end

-- Returns the wave when it was (re)spawned by this move.
function Session:move(stage: number?): any
	local s = (stage and self.World[stage]) and stage or 0
	if s == self.Stage then return nil end
	local old = self.Waves[self.Stage]
	if old then
		old.Away = true
		if old.Goons then EnemyRules.sendHome(old.Goons) end
	end
	self.Stage = s
	if s == 0 then return nil end
	local w = self.Waves[s]
	local fresh = nil
	if not w then
		w = WaveRules.spawn(s, self.World[s])
		self.Waves[s] = w
		fresh = w
	end
	w.Away = false
	return fresh
end

-- The run ended: every crew stands again, fresh, the next time you walk in (you are back in the lobby), and nobody is
-- calm after an old KO.
function Session:reset()
	self.Waves = {}
	self.Stage = 0
	self.CalmUntil = -math.huge
end

-- The wave you're in now (nil outside a stage with goons).
function Session:current(): any
	return self.Stage ~= 0 and self.Waves[self.Stage] or nil
end

-- Token bucket at the shot rate (ShotRules.Burst at once, refilling ShotRules.PerSecond).
function Session:allow(): boolean
	local now = self.Clock()
	self.Tokens = math.min(ShotRules.Burst, self.Tokens + math.max(0, now - self.Last) * ShotRules.PerSecond)
	self.Last = now
	if self.Tokens < 1 then return false end
	self.Tokens -= 1
	return true
end

-- Wakes goon `index` of wave `w` and the goons near it (a shot or a sighting). Returns the indices that noticed.
local function wake(w: any, index: number): { number }
	local g = w.Goons and w.Goons[index]
	if not g or g.State ~= EnemyRules.Idle then return {} end
	EnemyRules.alert(g, 0)
	local list = EnemyRules.callPack(w.Goons, g)
	table.insert(list, 1, index)
	return list
end

-- Returns ok, why (when not ok: 'bad', 'rate', 'stage', 'target', 'range', 'down'), the wave, downed, cleared.
-- `from` is the shooter's position in the map frame (the goons' frame).
function Session:shoot(stage: any, index: any, from: Vector3, damage: number): (boolean, string?, any, boolean, boolean)
	if not int(stage) or not int(index) or stage < 1 or stage > WaveRules.MaxStage or index < 1 or index > WaveRules.MaxIndex then
		return false, 'bad', nil, false, false
	end
	if not self:allow() then return false, 'rate', nil, false, false end
	if stage ~= self.Stage then return false, 'stage', nil, false, false end
	local w = self.Waves[stage]
	local g = w and w.Goons and w.Goons[index]
	if not w or not g then return false, 'target', nil, false, false end
	if typeof(from) ~= 'Vector3' or (Vector3.new(g.Pos.X - from.X, 0, g.Pos.Z - from.Z)).Magnitude > WaveRules.Range + EnemyRules.Slack then
		return false, 'range', w, false, false
	end
	local hit, downed, cleared = WaveRules.hit(w, index, damage)
	if not hit then return false, 'down', w, false, false end
	if not downed then w.Woke = wake(w, index) end
	if cleared then w.ClearedAt = self.Clock() end
	return true, nil, w, downed, cleared
end

-- Runs every wave that has goons up and about: the one you stand in (they chase `you`, your position in the map frame,
-- or nil when you can't be chased) and any you left (they walk home). Returns the events: { Stage, Kind = 'notice' |
-- 'punch' | 'home', Index, Landed (punch), Damage (punch) }, and the stages whose goons moved this tick.
function Session:tick(dt: number, you: Vector3?): ({ any }, { [number]: boolean })
	local events, moved = {}, {}
	local now = self.Clock()
	for stage, w in self.Waves do
		if not w.Cleared and w.Goons then
			local here = stage == self.Stage and not w.Away
			local target = here and you or nil
			local busy = false
			for i, g in w.Goons do
				if g.State ~= EnemyRules.Down and (g.State ~= EnemyRules.Idle or target) then
					local before = g.Pos
					local was = g.State
					local ev, landed = EnemyRules.step(g, dt, target, now, self.CalmUntil, self.Arenas[stage], w.Goons)
					if ev == 'notice' then
						table.insert(events, { Stage = stage, Kind = 'notice', Index = i })
						for _, j in EnemyRules.callPack(w.Goons, g) do table.insert(events, { Stage = stage, Kind = 'notice', Index = j }) end
					elseif ev == 'punch' then
						table.insert(events, { Stage = stage, Kind = 'punch', Index = i, Landed = landed == true, Damage = EnemyRules.punch(g.Kind) })
					elseif ev == 'home' then
						table.insert(events, { Stage = stage, Kind = 'home', Index = i })
					end
					if g.Pos ~= before or g.State ~= was then busy = true end
				end
			end
			if busy then moved[stage] = true end
		end
	end
	return events, moved
end

-- You were knocked out: every goon walks home and ignores you for EnemyRules.Calm seconds.
function Session:knockout()
	self.CalmUntil = self.Clock() + EnemyRules.Calm
	for _, w in self.Waves do
		if w.Goons then EnemyRules.sendHome(w.Goons) end
	end
end

-- The goons of wave `w` as the 'Moves' message sends them: { x, z, state, x, z, state, ... } (map frame, 0.01 studs).
function WaveRules.pack(w: any): { number }
	local d = {}
	for i, g in w.Goons or {} do
		d[3 * i - 2] = math.floor(g.Pos.X * 100 + 0.5) / 100
		d[3 * i - 1] = math.floor(g.Pos.Z * 100 + 0.5) / 100
		d[3 * i] = g.State
	end
	return d
end

---------------------------------------------------------------------------------------------- aiming (client)
-- Which goon a shot goes to (the soft aim assist): `list` = { [key] = { Pos, Up } }, standing at `from` and looking
-- along `look` (the camera). Only goons that are up and within Range count; the nearest wins (a goon in front of you
-- counts a little nearer than one behind), and the one you were shooting keeps the trigger while it stays in range, so an
-- HP bar drains one goon at a time.
function WaveRules.pick(list: { [any]: any }, from: Vector3, look: Vector3, current: any): any
	local best, bestScore = nil, math.huge
	local l = Vector3.new(look.X, 0, look.Z)
	l = l.Magnitude > 1e-3 and l.Unit or Vector3.new(0, 0, -1)
	for key, t in list do
		local d = Vector3.new(t.Pos.X - from.X, 0, t.Pos.Z - from.Z)
		local dist = d.Magnitude
		if t.Up and dist <= WaveRules.Range then
			local facing = dist > 1e-3 and d.Unit:Dot(l) or 1
			local score = dist * (1.25 - 0.25 * facing)
			if key == current then score -= 1000 end
			if score < bestScore then best, bestScore = key, score end
		end
	end
	return best
end

return WaveRules
