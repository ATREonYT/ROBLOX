-- Stage goons (brief 18): the soldier game's guards, copied as a system and made hood and kid-friendly. Cartoon rival-crew
-- goons stand in a loose group near each stage's far gate, notice you as you walk in ("!"), run at you, wind up and punch
-- (no weapons, no blood), take your shots, and get knocked out with stars and a poof. Pure rules shared by WaveService
-- (the server runs every goon as a plain point, 10 times a second: no Humanoids, no physics), Waves.client (draws your own
-- goons and aims) and the unit tests.
--   Damage per shot = your Power (damage(Power), at least 1). A goon's HP = HpShots x its kind's Hp x the stage's
--   Recommended Power (Balance.StagePower), so at the gate's Power a plain Goon takes HpShots shots ("Goon 1  40/40" at
--   Stage 1, like the video's "Guard 1 40/40") and every stage's goons are tougher than the last: more Power, more range time.
--   A punch takes Punch off your Humanoid's health (Roblox's own health bar). The punch that would finish you is a KO
--   instead (WaveService: back to the stage start, healed, shielded; the goons walk home and keep their HP).
-- Positions are the map frame's X and Z (stages run toward -Z; z' = studs past a stage's gate line).
local Balance = require(script.Parent.Config.Balance)

local EnemyRules = {}

EnemyRules.Tick = 0.1 -- the server's step (s)
EnemyRules.FightRange = 28 -- your gun reaches a goon this far (the aim assist's reach)
EnemyRules.Slack = 10 -- the server allows this much more than FightRange (the goon you see trails the server's a little)
EnemyRules.Notice = 34 -- a goon notices you this close (or when you shoot it) and calls the rest of its crew (the
-- Boss notices on its own: BossNotice, or a shot)
EnemyRules.BossNotice = 40
EnemyRules.NoticeDelay = 0.3 -- a beat between "!" and running (plus a little per goon, so they don't move as one)
EnemyRules.Calm = 3 -- after your KO the goons ignore you this long
EnemyRules.Shield = 3 -- and you wear a ForceField this long
EnemyRules.HpShots = 6 -- shots a plain Goon takes at its stage's Recommended Power
EnemyRules.Margin = 2 -- goons stay this far inside their stage's gate lines
EnemyRules.Edge = 2 -- and this far inside the street's sides (the gate's HalfWidth)
EnemyRules.Gap = 2.6 -- goons keep about this far apart (times their scale)
EnemyRules.Standoff = 0.7 -- a goon stops this share of its reach in front of you ...
EnemyRules.MinGap = 0.45 -- ... and never comes closer than this share
EnemyRules.MaxPunch = 40 -- sanity cap on one punch

-- State codes (WaveState 'Moves' sends them as numbers).
EnemyRules.Idle, EnemyRules.Alert, EnemyRules.Chase, EnemyRules.Windup, EnemyRules.Recover, EnemyRules.Return, EnemyRules.Down = 0, 1, 2, 3, 4, 5, 6

-- The kinds: tag name, HP weight, run speed (you walk 16+), reach, wind-up and recovery (s), punch damage, model scale.
EnemyRules.Kinds = {
	Goon = { Name = 'Goon', Hp = 1, Speed = 12, Reach = 3.8, Windup = 0.45, Recover = 0.9, Punch = 7, Scale = 1 },
	Runner = { Name = 'Runner', Hp = 0.6, Speed = 15, Reach = 3.5, Windup = 0.35, Recover = 0.8, Punch = 5, Scale = 0.88 },
	Bruiser = { Name = 'Bruiser', Hp = 2, Speed = 9, Reach = 4.6, Windup = 0.65, Recover = 1.1, Punch = 10, Scale = 1.3 },
	Boss = { Name = 'Boss', Hp = 7, Speed = 9, Reach = 6, Windup = 0.9, Recover = 1.3, Punch = 14, Scale = 2.1 },
}

-- Who stands in each stage (index order) and where (x, z' past the gate): a loose group in the middle of the street
-- (brief 23: z' 32..43, so the two pads before the next gate, on the sidewalks from z' 50, stay clear and show from the
-- stage's entry; the crew notices you as you walk in), each district's group in its own spots. The Block 1-3, Corner
-- Shop 4-6, The Alley 7-9 (narrow: |x| <= 13), The Courts 10-12 (two hang out on the court), The Yards 13-15, the Boss
-- Yard 16 (two goons by the gate, two past the Champ Ring, the boss on the BOSS pad).
local G, R, B = 'Goon', 'Runner', 'Bruiser'
EnemyRules.Lineups = {
	{ G, G, G },
	{ G, G, G },
	{ G, R, G },
	{ G, R, G, G },
	{ R, G, B, G },
	{ G, R, B, G },
	{ R, G, R, B },
	{ G, B, R, G },
	{ R, B, G, R },
	{ G, R, B, G },
	{ B, G, R, G },
	{ G, B, R, G },
	{ R, G, B, G, R },
	{ G, B, R, G, R },
	{ B, R, G, G, R },
	{ 'Boss', G, R, G, B },
}
EnemyRules.Spots = {
	{ { -6, 36 }, { 5, 38 }, { -0.5, 32 } },
	{ { -8, 34 }, { 7, 36 }, { -1, 40 } },
	{ { -5, 32 }, { 7, 35 }, { 1, 39 } },
	{ { -9, 32 }, { -2, 37 }, { 5, 33 }, { 11, 38 } },
	{ { -10, 36 }, { -3, 32 }, { 4, 38 }, { 10, 33 } },
	{ { -8, 33 }, { -1, 38 }, { 6, 34 }, { 12, 39 } },
	{ { -6, 32 }, { 0, 37 }, { 6, 33 }, { -2, 42 } },
	{ { -7, 36 }, { -1, 32 }, { 6, 37 }, { 2, 42 } },
	{ { -6, 34 }, { 1, 39 }, { 7, 33 }, { -2, 43 } },
	{ { -7, 34 }, { 1, 38 }, { 27.5, 37 }, { 30.5, 43 } },
	{ { -8, 36 }, { -1, 32 }, { 27.5, 43 }, { 30.5, 37 } },
	{ { -6, 33 }, { 2, 38 }, { 27.5, 36 }, { 30.5, 42 } },
	{ { -10, 32 }, { -4, 37 }, { 2, 33 }, { 8, 38 }, { 13, 33 } },
	{ { -12, 36 }, { -6, 32 }, { 0, 38 }, { 6, 33 }, { 11, 37 } },
	{ { -11, 33 }, { -5, 38 }, { 1, 32 }, { 7, 37 }, { 12, 32 } },
	{ { 0, 74 }, { -12, 12 }, { 12, 14 }, { -22, 52 }, { 22, 54 } },
}
-- Places goons walk round (map-frame boxes in z', per stage): the Champ Ring and its bleachers in the Boss Yard.
EnemyRules.Blocks = { [16] = { { -17.5, 21, 17.5, 45.5 } } }
-- The stage's crew colours (GoonRig reads these): The Block red, Corner Shop green, The Alley purple, The Courts orange,
-- The Yards yellow, the Boss Yard's boss gold.
EnemyRules.Crews = { 'Red', 'Red', 'Red', 'Green', 'Green', 'Green', 'Purple', 'Purple', 'Purple', 'Orange', 'Orange', 'Orange', 'Yellow', 'Yellow', 'Yellow', 'Boss' }

local function num(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- Damage one of your shots deals: your Power (whole), at least 1.
function EnemyRules.damage(power: any): number
	return math.max(1, math.floor(num(power, 0)))
end

-- A stage's Recommended Power (the gate's Power; 10 for a stage the table doesn't know).
function EnemyRules.recommended(stage: any): number
	local s = math.floor(num(stage, 1))
	local list = Balance.StagePower
	return list[math.clamp(s, 1, #list)] or 10
end

-- A goon's full HP: HpShots x the kind's weight x the stage's Recommended Power, rounded to read cleanly (5s from 20,
-- 50s from 200, two significant figures from 2000).
function EnemyRules.maxHp(stage: any, kind: string?): number
	local k = kind and EnemyRules.Kinds[kind] or EnemyRules.Kinds.Goon
	local hp = EnemyRules.HpShots * k.Hp * EnemyRules.recommended(stage)
	if hp >= 2000 then return Balance.round(hp) end
	local step = hp >= 200 and 50 or hp >= 20 and 5 or 1
	return math.max(1, math.floor(hp / step + 0.5) * step)
end

-- What a goon's punch takes off you.
function EnemyRules.punch(kind: string?): number
	local k = kind and EnemyRules.Kinds[kind] or EnemyRules.Kinds.Goon
	return math.clamp(k.Punch, 0, EnemyRules.MaxPunch)
end

-- The tag over a goon: "Goon 1", "Runner 7", "BOSS" (the video's "Guard 1").
function EnemyRules.tagName(stage: number, kind: string): string
	if kind == 'Boss' then return 'BOSS' end
	local k = EnemyRules.Kinds[kind]
	return (k and k.Name or kind) .. ' ' .. tostring(stage)
end

-- Every stage's goons from the map's gates (StageRules.fromModels, sorted): { [stage] = { {Kind, Name, Home = Vector3
-- (map frame, Y 0)}, ... } }, and each stage's arena { X = half width, Z0 = near edge (just past its gate), Z1 = far edge,
-- Top = the gate's Z, Blocks = boxes in the map frame }. The last gate's arena runs `lastDepth` past it.
function EnemyRules.world(gates: { any }, lastDepth: number?): ({ [number]: { any } }, { [number]: any })
	local world, arenas = {}, {}
	for n, g in gates do
		local stage = g.Stage
		local lineup, spots = EnemyRules.Lineups[stage], EnemyRules.Spots[stage]
		if type(stage) == 'number' and lineup and spots and type(g.Z) == 'number' then
			local after = gates[n + 1]
			local far = after and after.Z or (g.Z - (lastDepth or 96))
			local arena = { X = math.max(6, (g.HalfWidth or 20) - EnemyRules.Edge), Z0 = g.Z - EnemyRules.Margin, Z1 = far + EnemyRules.Margin, Top = g.Z, Blocks = {} }
			for _, b in EnemyRules.Blocks[stage] or {} do
				table.insert(arena.Blocks, { b[1], g.Z - b[4], b[3], g.Z - b[2] }) -- {x0, z0, x1, z1} with z0 < z1
			end
			local list = {}
			for i, kind in lineup do
				local spot = spots[i]
				if spot then
					local home = Vector3.new(math.clamp(spot[1], -arena.X, arena.X), 0, math.clamp(g.Z - spot[2], arena.Z1, arena.Z0))
					list[i] = { Kind = kind, Name = EnemyRules.tagName(stage, kind), Home = home }
				end
			end
			world[stage], arenas[stage] = list, arena
		end
	end
	return world, arenas
end

---------------------------------------------------------------------------------------------- one goon
-- A goon: { Kind, Home, Pos (Vector3, map frame, Y 0), State, T (timer), Slot (0..1: where round you it stands) }.
function EnemyRules.new(kind: string, home: Vector3, slot: number?): any
	return { Kind = kind, Home = home, Pos = home, State = EnemyRules.Idle, T = 0, Slot = slot or 0 }
end

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

-- Keeps a point inside the arena and out of its blocks (pushed out the nearest side).
function EnemyRules.clamp(p: Vector3, arena: any): Vector3
	if not arena then return p end
	local x, z = math.clamp(p.X, -arena.X, arena.X), math.clamp(p.Z, arena.Z1, arena.Z0)
	for _, b in arena.Blocks or {} do
		if x > b[1] and x < b[3] and z > b[2] and z < b[4] then
			local dl, dr, dn, df = x - b[1], b[3] - x, z - b[2], b[4] - z
			local m = math.min(dl, dr, dn, df)
			if m == dl then x = b[1] elseif m == dr then x = b[3] elseif m == dn then z = b[2] else z = b[4] end
		end
	end
	return Vector3.new(x, 0, z)
end

-- One step toward `goal` at `speed`, round the arena's blocks: a step that would enter a block slides along its side,
-- toward the corner nearer the goal.
local function stepToward(pos: Vector3, goal: Vector3, speed: number, dt: number, stopAt: number, arena: any): Vector3
	local d = flat(goal - pos)
	local dist = d.Magnitude
	if dist <= stopAt + 1e-3 then return pos end
	local move = math.min(speed * dt, dist - stopAt)
	local dir = d / dist
	local nextPos = pos + dir * move
	for _, b in (arena and arena.Blocks) or {} do
		if nextPos.X > b[1] and nextPos.X < b[3] and nextPos.Z > b[2] and nextPos.Z < b[4] then
			-- Which side we came at: the one we were outside of.
			-- Slide along the side it met: toward the goal when the goal lies past that side's end, else toward the
			-- nearer corner (which stays the nearer one as it goes, so it never dithers in the middle).
			local function way(p0, g0, lo, hi)
				if g0 <= lo or g0 >= hi then return g0 > p0 and 1 or -1 end
				return (p0 - lo) < (hi - p0) and -1 or 1
			end
			if pos.X > b[1] and pos.X < b[3] then -- (between its X edges: it met a Z side, so it slides along X)
				nextPos = Vector3.new(pos.X + way(pos.X, goal.X, b[1], b[3]) * move, 0, pos.Z)
			else
				nextPos = Vector3.new(pos.X, 0, pos.Z + way(pos.Z, goal.Z, b[2], b[4]) * move)
			end
		end
	end
	return EnemyRules.clamp(nextPos, arena)
end

-- Steps one goon by dt. `target` = your position (map frame) while you are in its stage and fair game, else nil.
-- `now` the clock, `calmUntil` (goons ignore you before it), `arena`, `others` (the wave's goons, for spacing).
-- Returns an event: 'notice' (it saw you), 'punch' + landed (its wind-up ended: true when you were still in reach),
-- 'home' (back on its spot), or nil.
function EnemyRules.step(g: any, dt: number, target: Vector3?, now: number, calmUntil: number?, arena: any, others: { any }?): (string?, boolean?)
	local k = EnemyRules.Kinds[g.Kind] or EnemyRules.Kinds.Goon
	local S = EnemyRules
	if g.State == S.Down then return nil end
	local calm = calmUntil and now < calmUntil
	local t = (target and not calm) and flat(target) or nil
	if g.State == S.Idle then
		if t and (t - g.Pos).Magnitude <= (g.Kind == 'Boss' and S.BossNotice or S.Notice) then
			S.alert(g, 0)
			return 'notice'
		end
		return nil
	end
	if not t and g.State ~= S.Return then
		g.State, g.T = S.Return, 0
	end
	if g.State == S.Alert then
		g.T -= dt
		if g.T <= 0 then g.State = S.Chase end
		return nil
	elseif g.State == S.Return then
		if t and (t - g.Pos).Magnitude <= S.Notice then
			g.State = S.Chase
			return nil
		end
		g.Pos = stepToward(g.Pos, g.Home, k.Speed, dt, 0, arena)
		if (g.Pos - g.Home).Magnitude < 0.05 then
			g.Pos, g.State = g.Home, S.Idle
			return 'home'
		end
		return nil
	end
	local dist = (t - g.Pos).Magnitude
	if g.State == S.Chase then
		-- Run at you and stop just in front of you (Standoff of its reach), coming at you from its own side (its Slot
		-- turns its approach a little), keeping off the other goons; never closer than MinGap of its reach.
		local standoff = k.Reach * S.Standoff
		local away = flat(g.Pos - t)
		local dir = away.Magnitude > 1e-3 and away.Unit or Vector3.new(0, 0, -1)
		local turnBy = (g.Slot - 0.5) * 0.6
		local c, sn = math.cos(turnBy), math.sin(turnBy)
		dir = Vector3.new(dir.X * c - dir.Z * sn, 0, dir.X * sn + dir.Z * c)
		local nextPos = stepToward(g.Pos, t + dir * standoff, k.Speed, dt, 0.2, arena)
		for _, o in others or {} do
			if o ~= g and o.State ~= S.Down and o.State ~= S.Idle then
				local ok = EnemyRules.Kinds[o.Kind] or k
				local gap = S.Gap * (k.Scale + ok.Scale) / 2
				local d = flat(nextPos - o.Pos)
				if d.Magnitude < gap and d.Magnitude > 1e-3 then nextPos += d.Unit * math.min(gap - d.Magnitude, k.Speed * dt) * 0.5 end
			end
		end
		local fromYou = flat(nextPos - t)
		local least = k.Reach * S.MinGap
		if fromYou.Magnitude < least then nextPos = t + (fromYou.Magnitude > 1e-3 and fromYou.Unit or dir) * least end
		g.Pos = EnemyRules.clamp(nextPos, arena)
		if (t - g.Pos).Magnitude <= k.Reach then g.State, g.T = S.Windup, k.Windup end
		return nil
	elseif g.State == S.Windup then
		g.T -= dt
		if g.T <= 0 then
			g.State, g.T = S.Recover, k.Recover
			return 'punch', dist <= k.Reach + 1.2
		end
		return nil
	elseif g.State == S.Recover then
		g.T -= dt
		if g.T <= 0 then g.State = S.Chase end
		return nil
	end
	return nil
end

-- A goon that saw you (or was shot): "!" and a short beat, then it runs. `order` staggers a group.
function EnemyRules.alert(g: any, order: number)
	if g.State ~= EnemyRules.Idle and g.State ~= EnemyRules.Return then return end
	g.State, g.T = EnemyRules.Alert, EnemyRules.NoticeDelay + 0.12 * (order or 0)
end

-- One goon noticing calls the rest of its crew (not the Boss: it waits for you), the nearer ones first, each a beat
-- later. Returns who was called.
function EnemyRules.callPack(goons: { any }, caller: any): { number }
	local list = {}
	for i, o in goons do
		if o ~= caller and o.State == EnemyRules.Idle and o.Kind ~= 'Boss' then table.insert(list, i) end
	end
	table.sort(list, function(a, b) return (goons[a].Home - caller.Home).Magnitude < (goons[b].Home - caller.Home).Magnitude end)
	for order, i in list do EnemyRules.alert(goons[i], order) end
	return list
end

-- Every goon back to its spot (your KO): they walk home and keep their HP.
function EnemyRules.sendHome(goons: { any })
	for _, g in goons do
		if g.State ~= EnemyRules.Down and g.State ~= EnemyRules.Idle then g.State, g.T = EnemyRules.Return, 0 end
	end
end

return EnemyRules
