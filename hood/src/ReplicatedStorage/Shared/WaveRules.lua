-- Stage target waves: the soldier game's guard waves, the hood way (cartoon targets only, nothing human-shaped).
-- Pure rules shared by WaveService (which decides), Waves.client (which shows and aims) and the unit tests.
--   Every stage street and the boss yard (16) holds a small wave of targets (the map: TheBlockV2 Waves.build, Models
--   tagged HoodWaveTarget). Each player has their own wave per stage. A hit deals the shot's pay (ShotRules.pay at
--   x1, no range multiplier) as damage and pays it as Power, like the ranges. The last target down clears the wave:
--   the first clear of a stage pays Cash and opens the next gate (gate i needs WaveCleared >= i - 1, with WaveCleared
--   the highest stage whose wave you ever cleared); a later visit respawns the wave for Power only.
local ShotRules = require(script.Parent.ShotRules)

local WaveRules = {}

WaveRules.Range = 80 -- studs from you to a target for a shot to count
WaveRules.LastDepth = 120 -- the last gate's arena (the boss yard) runs this far past its line
WaveRules.MaxStage = 64 -- sanity cap on stage numbers from the network
WaveRules.MaxIndex = 32 -- and on target indices
-- A target's HP per stage (1-15 the streets, 16 the boss yard) for a weight-1 kind: about 10-25 shots with the gun and
-- look a player usually has by then (shots there deal 1-2 to start, ~100+ near the end of World 1).
WaveRules.HP = { 10, 24, 30, 36, 50, 60, 70, 80, 90, 120, 250, 400, 700, 1100, 1800, 2500 }
-- The kinds of target: the name on its tag and its HP weight. The first five stand anywhere; Sign (Corner Shop),
-- Bottles and Crates (The Alley), Backboard (The Courts) and Tyres (The Yards) belong to one district each.
WaveRules.Kinds = {
	Board = { Name = 'Board', Weight = 1 },
	Cans = { Name = 'Cans', Weight = 0.6 },
	Cone = { Name = 'Cone', Weight = 0.8 },
	Boombox = { Name = 'Boombox', Weight = 1.4 },
	Drum = { Name = 'Drum', Weight = 1.2 },
	Sign = { Name = 'Sign', Weight = 0.9 },
	Bottles = { Name = 'Bottles', Weight = 0.7 },
	Crates = { Name = 'Crates', Weight = 1.1 },
	Backboard = { Name = 'Backboard', Weight = 1 },
	Tyres = { Name = 'Tyres', Weight = 1.2 },
	MegaBoard = { Name = 'Mega Board', Weight = 3 },
}
-- Which targets stand in each stage, in index order (the map builder sets each one up in its district's own spot;
-- the server reads the map): The Block 1-3, Corner Shop 4-6, The Alley 7-9, The Courts 10-12, The Yards 13-15, the
-- boss yard 16.
WaveRules.Lineups = {
	{ 'Board', 'Cans', 'Cone' },
	{ 'Cans', 'Board', 'Cone' },
	{ 'Board', 'Cans', 'Cone', 'Boombox' },
	{ 'Cans', 'Sign', 'Board', 'Boombox' },
	{ 'Sign', 'Board', 'Cans', 'Boombox' },
	{ 'Cans', 'Board', 'Sign', 'Drum' },
	{ 'Cans', 'Bottles', 'Board', 'Crates' },
	{ 'Crates', 'Cans', 'Bottles', 'Board', 'Boombox' },
	{ 'Board', 'Cans', 'Crates', 'Bottles', 'Drum' },
	{ 'Board', 'Cans', 'Backboard', 'Cone', 'Boombox' },
	{ 'Backboard', 'Board', 'Cans', 'Cone', 'Drum' },
	{ 'Board', 'Backboard', 'Cans', 'Boombox', 'Cone' },
	{ 'Crates', 'Drum', 'Tyres', 'Drum', 'Board' },
	{ 'Tyres', 'Crates', 'Drum', 'Drum', 'Board' },
	{ 'Board', 'Crates', 'Tyres', 'Drum', 'Drum' },
	{ 'MegaBoard', 'Board', 'Boombox', 'Drum', 'Cans', 'Cone' },
}

local function int(v: any): number?
	if type(v) ~= 'number' or v ~= v or v % 1 ~= 0 then return nil end
	return v
end

-- A target's full HP in a stage, rounded to a number that reads cleanly on its tag (5s from 20, 50s from 200, 500s
-- from 2000).
function WaveRules.maxHp(stage: number, kind: string?): number
	local base = WaveRules.HP[math.clamp(math.floor(stage), 1, #WaveRules.HP)]
	local k = kind and WaveRules.Kinds[kind]
	local hp = math.max(1, base * (k and k.Weight or 1))
	local step = hp >= 2000 and 500 or hp >= 200 and 50 or hp >= 20 and 5 or 1
	return math.max(1, math.floor(hp / step + 0.5) * step)
end

-- Cash for a stage's first clear: 5% of the Power that stage's gate asks for (at least 5).
function WaveRules.reward(required: any): number
	local r = type(required) == 'number' and required == required and required or 0
	return math.max(5, math.floor(math.clamp(r, 0, 1e12) * 0.05))
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

-- Gate `stage` is open as far as waves go (the Power check is StageRules'): nil = no wave system here.
function WaveRules.gateOpen(stage: number, waveCleared: any): boolean
	if type(waveCleared) ~= 'number' or stage <= 1 then return true end
	return waveCleared >= stage - 1
end

-- The WaveCleared a player has: their saved best, carried on through stages that have no targets built (a map
-- without waves in some stages never blocks a gate on them). hasWave: stage -> truthy.
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

-- A fresh wave of `kinds` (index order) in a stage.
function WaveRules.spawn(stage: number, kinds: { string }): any
	local w = { Stage = stage, HP = {}, Max = {}, Left = #kinds, Cleared = #kinds == 0, Away = false }
	for i, kind in kinds do
		local hp = WaveRules.maxHp(stage, kind)
		w.HP[i], w.Max[i] = hp, hp
	end
	return w
end

-- Damage on target `index`: returns (hit, downed, cleared). A target already down, or a cleared wave, takes nothing.
function WaveRules.hit(w: any, index: number, damage: number): (boolean, boolean, boolean)
	local hp = w.HP[index]
	if type(hp) ~= 'number' or hp <= 0 or w.Cleared then return false, false, false end
	hp = math.max(0, hp - math.max(0, damage))
	w.HP[index] = hp
	if hp > 0 then return true, false, false end
	w.Left = math.max(0, w.Left - 1)
	if w.Left == 0 then
		w.Cleared = true
		return true, true, true
	end
	return true, true, false
end

-- Reads the map's targets into { [stage] = { { Kind, Pos (world), Name }, ... } } in index order; a stage whose
-- indices aren't 1..n, or a target with a bad attribute, is left out (warned once by the caller).
function WaveRules.worldFrom(models: { any }): ({ [number]: { any } }, { string })
	local byStage, bad = {}, {}
	for _, m in models do
		local stage, index, kind, aim = m:GetAttribute('Stage'), m:GetAttribute('Index'), m:GetAttribute('Kind'), m:GetAttribute('Aim')
		if int(stage) and int(index) and stage >= 1 and stage <= WaveRules.MaxStage and index >= 1 and index <= WaveRules.MaxIndex
			and type(kind) == 'string' and WaveRules.Kinds[kind] and typeof(aim) == 'Vector3' then
			byStage[stage] = byStage[stage] or {}
			byStage[stage][index] = { Kind = kind, Pos = aim, Name = WaveRules.Kinds[kind].Name, Model = m }
		else
			table.insert(bad, m.Name)
		end
	end
	local world = {}
	for stage, list in byStage do
		local n = 0
		for i in list do n = math.max(n, i) end
		local whole = true
		for i = 1, n do if not list[i] then whole = false end end
		if whole then world[stage] = list else table.insert(bad, 'stage ' .. stage) end
	end
	return world, bad
end

---------------------------------------------------------------------------------------------- one player's waves
-- WaveRules.session(world, clock): the server keeps one per player. :move(stage) as they walk (0 = not in a stage
-- with targets) spawns a wave the first time they enter that stage and again when they come back after clearing it;
-- an unfinished wave keeps its HP while they step out. :shoot(stage, index, from, damage) checks the shot (whole
-- numbers in range, the shot rate, standing in that stage, the target up and within Range of `from`) and applies it.
local Session = {}
Session.__index = Session

function WaveRules.session(world: { [number]: { any } }, clock: () -> number): any
	return setmetatable({ World = world, Clock = clock, Stage = 0, Waves = {}, Tokens = ShotRules.Burst, Last = clock() }, Session)
end

function Session:kinds(stage: number): { string }
	local list = {}
	for i, t in self.World[stage] or {} do list[i] = t.Kind end
	return list
end

-- Returns the wave when it was (re)spawned by this move.
function Session:move(stage: number?): any
	local s = (stage and self.World[stage]) and stage or 0
	if s == self.Stage then return nil end
	local old = self.Waves[self.Stage]
	if old then old.Away = true end
	self.Stage = s
	if s == 0 then return nil end
	local w = self.Waves[s]
	local fresh = nil
	if not w or (w.Cleared and w.Away) then
		w = WaveRules.spawn(s, self:kinds(s))
		self.Waves[s] = w
		fresh = w
	end
	w.Away = false
	return fresh
end

-- The wave you're in now (nil outside a stage with targets).
function Session:current(): any
	return self.Stage ~= 0 and self.Waves[self.Stage] or nil
end

-- Token bucket at the ranges' rate (ShotRules.Burst at once, refilling ShotRules.PerSecond).
function Session:allow(): boolean
	local now = self.Clock()
	self.Tokens = math.min(ShotRules.Burst, self.Tokens + math.max(0, now - self.Last) * ShotRules.PerSecond)
	self.Last = now
	if self.Tokens < 1 then return false end
	self.Tokens -= 1
	return true
end

-- Returns ok, why (when not ok: 'bad', 'rate', 'stage', 'target', 'range', 'down'), the wave, downed, cleared.
function Session:shoot(stage: any, index: any, from: Vector3, damage: number): (boolean, string?, any, boolean, boolean)
	if not int(stage) or not int(index) or stage < 1 or stage > WaveRules.MaxStage or index < 1 or index > WaveRules.MaxIndex then
		return false, 'bad', nil, false, false
	end
	if not self:allow() then return false, 'rate', nil, false, false end
	if stage ~= self.Stage then return false, 'stage', nil, false, false end
	local w, t = self.Waves[stage], (self.World[stage] or {})[index]
	if not w or not t then return false, 'target', nil, false, false end
	if typeof(from) ~= 'Vector3' or (t.Pos - from).Magnitude > WaveRules.Range then return false, 'range', w, false, false end
	local hit, downed, cleared = WaveRules.hit(w, index, damage)
	if not hit then return false, 'down', w, false, false end
	return true, nil, w, downed, cleared
end

---------------------------------------------------------------------------------------------- aiming (client)
-- Which target a shot goes to: `list` = { [key] = { Pos, Up } }, from the camera at `eye` looking along `look`,
-- standing at `from`. Only targets that are up and within Range count; the one nearest the middle of the screen
-- wins (each stud away adds a little), and the one you were shooting keeps the trigger while it stands in view
-- (within 50 degrees), so an HP bar drains one target at a time.
function WaveRules.pick(list: { [any]: any }, eye: Vector3, look: Vector3, from: Vector3, current: any): any
	local best, bestScore = nil, math.huge
	for key, t in list do
		if t.Up and (t.Pos - from).Magnitude <= WaveRules.Range - 2 then
			local to = t.Pos - eye
			local angle = to.Magnitude > 1e-3 and math.deg(math.acos(math.clamp(to.Unit:Dot(look.Unit), -1, 1))) or 0
			local score = angle + (t.Pos - from).Magnitude * 0.35
			if key == current and angle < 50 then score -= 1000 end
			if score < bestScore then best, bestScore = key, score end
		end
	end
	return best
end

return WaveRules
