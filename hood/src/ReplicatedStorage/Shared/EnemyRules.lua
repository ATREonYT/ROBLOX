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
local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

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
EnemyRules.ReturnMax = 15 -- (brief 24) a goon still not home this long after it turned back (caught on something) is put
-- back on its spot (Waves.client shows a poof)

-- State codes (WaveState 'Moves' sends them as numbers).
EnemyRules.Idle, EnemyRules.Alert, EnemyRules.Chase, EnemyRules.Windup, EnemyRules.Recover, EnemyRules.Return, EnemyRules.Down = 0, 1, 2, 3, 4, 5, 6

-- The kinds: tag name, HP weight, run speed (you walk 16+), reach, wind-up and recovery (s), punch damage, model scale.
EnemyRules.Kinds = {
	Goon = { Name = 'Goon', Hp = 1, Speed = 12, Reach = 3.8, Windup = 0.45, Recover = 0.9, Punch = 7, Scale = 1 },
	Runner = { Name = 'Runner', Hp = 0.6, Speed = 15, Reach = 3.5, Windup = 0.35, Recover = 0.8, Punch = 5, Scale = 0.88 },
	Bruiser = { Name = 'Bruiser', Hp = 2, Speed = 9, Reach = 4.6, Windup = 0.65, Recover = 1.1, Punch = 10, Scale = 1.3 },
	Boss = { Name = 'Boss', Hp = 7, Speed = 9, Reach = 6, Windup = 0.9, Recover = 1.3, Punch = 14, Scale = 2.1 },
}
EnemyRules.FinalBossHp = 10 -- (brief 29) the last stage's boss (World 1's final boss) is tougher than a crew's boss

-- Who stands in each stage (index order) and where (x, z' past the gate): a loose group in the middle of the street
-- (brief 23: z' 32..43, so the two pads before the next gate, on the sidewalks from z' 50, stay clear and show from the
-- stage's entry; the crew notices you as you walk in), each district's group in its own spots. The Block 1-3, Corner
-- Shop 4-6, The Alley 7-9 (narrow: |x| <= 13), The Courts 10-12 (two hang out on the court), The Yards 13-15, the Boss
-- Yard 16 (two goons by the gate, two past the Champ Ring, the boss on the BOSS pad).
-- (brief 29) Every crew holds two stages (the user's HoodEnemies roster): the 1st is its minions, the 2nd the same
-- minions plus their boss, at the back of the group. So every even stage has a 'Boss'.
local G, R, B, X = 'Goon', 'Runner', 'Bruiser', 'Boss'
EnemyRules.Lineups = {
	{ G, G, G },
	{ G, G, G, X },
	{ G, R, G },
	{ G, R, G, X },
	{ R, G, B, G },
	{ G, R, B, X },
	{ R, G, R, B },
	{ G, B, R, X },
	{ R, B, G, R },
	{ G, R, G, X },
	{ B, G, R, G },
	{ G, R, G, X },
	{ R, G, B, G, R },
	{ G, B, R, G, X },
	{ B, R, G, G, R },
	{ X, G, R, G, B },
}
EnemyRules.Spots = {
	{ { -6, 36 }, { 5, 38 }, { -0.5, 32 } },
	{ { -8, 34 }, { 7, 36 }, { -1, 40 }, { 3, 44 } },
	{ { -5, 32 }, { 7, 35 }, { 1, 39 } },
	{ { -9, 32 }, { -2, 37 }, { 5, 33 }, { 2, 43 } },
	{ { -10, 36 }, { -3, 32 }, { 4, 38 }, { 10, 33 } },
	{ { -8, 33 }, { -1, 38 }, { 6, 34 }, { 1, 44 } },
	{ { -6, 32 }, { 0, 37 }, { 6, 33 }, { -2, 42 } },
	{ { -7, 36 }, { -1, 32 }, { 6, 37 }, { 2, 42 } },
	{ { -6, 34 }, { 1, 39 }, { 7, 33 }, { -2, 43 } },
	{ { -7, 34 }, { 27.5, 37 }, { 30.5, 43 }, { 1, 40 } },
	{ { -8, 36 }, { -1, 32 }, { 27.5, 43 }, { 30.5, 37 } },
	{ { -6, 33 }, { 27.5, 36 }, { 30.5, 42 }, { 1, 40 } },
	{ { -10, 32 }, { -4, 37 }, { 2, 33 }, { 8, 38 }, { 13, 33 } },
	{ { -12, 36 }, { -6, 32 }, { 6, 33 }, { 11, 37 }, { 0, 41 } },
	{ { -11, 33 }, { -5, 38 }, { 1, 32 }, { 7, 37 }, { 12, 32 } },
	{ { 0, 74 }, { -12, 12 }, { 12, 14 }, { -22, 52 }, { 22, 54 } },
}
-- Places goons walk round (map-frame boxes in z', per stage): the Champ Ring and its bleachers in the Boss Yard.
EnemyRules.Blocks = { [16] = { { -17.5, 21, 17.5, 45.5 } } }
-- The stage's crew colours (GoonRig reads these): The Block red, Corner Shop green, The Alley purple, The Courts orange,
-- The Yards yellow, the Boss Yard's boss gold.
EnemyRules.Crews = { 'Red', 'Red', 'Red', 'Green', 'Green', 'Green', 'Purple', 'Purple', 'Purple', 'Orange', 'Orange', 'Orange', 'Yellow', 'Yellow', 'Yellow', 'Boss' }


---------------------------------------------------------------------------------------------- who they are (brief 29)
-- The user's HoodEnemies (ServerStorage/HoodEnemies: real Roblox avatars in catalog clothes, 8 crews x 2 stages, each
-- crew's boss joining on its 2nd stage). RosterStage maps our stage to the roster's: our 16 stages (15 streets + the
-- Boss Yard) are the roster's 16 in its order, except that the Ballers (roster 5-6) play on our basketball courts
-- (11-12, Court King on the court) and the Warehouse Muscle (roster 11-12) take stages 5-6. The Harbor Boss, World 1's
-- final boss, holds the Boss Yard. (Keep each crew's two stages together, its boss on the 2nd.)
EnemyRules.RosterStage = { 1, 2, 3, 4, 11, 12, 7, 8, 9, 10, 5, 6, 13, 14, 15, 16 }
-- The roster's crews in stage order (its Key: every look key is <crew>_1..3 or <crew>_boss).
EnemyRules.LookCrews = { 'bullies', 'crooks', 'ballers', 'little', 'gangsters', 'muscle', 'dockhands', 'harbor' }

-- Who stands in a stage, as EnemyLooks.forStage says it (the server asks EnemyLooks itself; the client, which can't
-- see ServerStorage, works it out here: the unit tests keep the two the same).
function EnemyRules.looksFor(stage: number): any
	local r = EnemyRules.RosterStage[stage] or stage
	local crew = EnemyRules.LookCrews[math.clamp(math.ceil(r / 2), 1, #EnemyRules.LookCrews)]
	return { crew = crew, minions = { crew .. '_1', crew .. '_2', crew .. '_3' }, boss = (r % 2 == 0) and (crew .. '_boss') or nil }
end

-- Each goon's look key, in lineup order: the Boss gets the crew's boss, the rest take the minions in turn.
function EnemyRules.cast(stage: number, lineup: { string }, looks: ((number) -> any)?): { string }
	local ok, who = false, nil
	if looks then ok, who = pcall(looks, stage) end
	if not ok or type(who) ~= 'table' or type(who.minions) ~= 'table' or #who.minions == 0 then who = EnemyRules.looksFor(stage) end
	local out, n = {}, 0
	for i, kind in lineup do
		if kind == 'Boss' then
			out[i] = who.boss or EnemyRules.looksFor(stage).boss or (EnemyRules.crewOf(who.minions[1]) .. '_boss')
		else
			n += 1
			out[i] = who.minions[(n - 1) % #who.minions + 1]
		end
	end
	return out
end
function EnemyRules.crewOf(look: string?): string
	return type(look) == 'string' and (look:match('^(.-)_[^_]+$') or look) or 'bullies'
end

---------------------------------------------------------------------------------------------- the courts (brief 29)
-- The Courts (stages 10-12, TheBlockV2's District.courts): the court on the right is fenced (chain-link at x 22, z'
-- 3..55, its gateway at z' 23..27.5), so a goon on the court goes out through the gateway, never through the wire.
-- Its crew waits in the players' tunnel at the court's far corner (PropModels 'CourtTunnel', mouth toward the gate)
-- and jogs out onto the court as you walk in (Waves.client draws the walk-out; the server has them on their spots).
local COURT = { Fence = { X = 22, Z0 = 3, Z1 = 55, Door = { 23, 27.5 } }, Tunnel = { 26.6, 52 }, Mouth = { 26.6, 45.4 } }
EnemyRules.Courts = { [10] = COURT, [11] = COURT, [12] = COURT }

-- Where to head for next on the way from pos to goal: the goal, or a fence's gateway when the fence is in between.
function EnemyRules.via(pos: Vector3, goal: Vector3, arena: any): Vector3
	for _, f in (arena and arena.Fences) or {} do
		local a, b = pos.X - f.X, goal.X - f.X
		if a * b < 0 then
			local z = pos.Z + (goal.Z - pos.Z) * a / (a - b)
			if z >= f.Z0 and z <= f.Z1 and not (z > f.D0 + 0.6 and z < f.D1 - 0.6) then
				local side = a > 0 and 1 or -1
				local dz = (f.D0 + f.D1) / 2
				local near = Vector3.new(f.X + side * 1.4, 0, dz)
				if Vector3.new(pos.X - near.X, 0, pos.Z - near.Z).Magnitude > 0.6 then return near end
				return Vector3.new(f.X - side * 1.4, 0, dz)
			end
		end
	end
	return goal
end

---------------------------------------------------------------------------------------------- boss fights (brief 29)
-- Every crew's boss has two big moves, and a third once it is down to half HP (phase 2, RageAt): each is shown first
-- as a RED shape on the ground (a lane, a circle, a cone) for Tele seconds (never under TeleMin: kids need time to
-- step out), then it lands: you take its Damage if you are still inside (shrunk by Fair studs: a near miss is a miss).
--   Line (Charge: the boss dashes down the lane; Roll: it sends a ball or barrel down it), Circle round the boss
--   (Stomp), Circle on the spot you stood (Throw: a thrown thing lands there; Volley: three of them; Leap: the boss
--   jumps onto it), Cone in front of it (Blast). In between it still chases and punches.
EnemyRules.Tele, EnemyRules.Dash = 7, 8 -- (state codes, after Down)
EnemyRules.TeleMin = 1.0
EnemyRules.RageAt = 0.5
EnemyRules.Fair = 0.8
EnemyRules.DashTime = 0.32
EnemyRules.BossFirst = 1.4 -- its first big move this long after it starts chasing
EnemyRules.Moves = {
	Charge = { Shape = 'Line', Length = 26, Width = 5, Damage = 16, Reach = 22 },
	Roll = { Shape = 'Line', Length = 34, Width = 4.5, Damage = 14, Reach = 30, Flight = 0.6 },
	Stomp = { Shape = 'Circle', At = 'Self', Radius = 10, Damage = 18, Reach = 13 },
	Throw = { Shape = 'Circle', At = 'You', Radius = 5.5, Damage = 15, Reach = 40, Flight = 0.75 },
	Volley = { Shape = 'Circle', At = 'You', Radius = 4.5, Damage = 15, Reach = 40, Count = 3, Spread = 7, Flight = 0.8 },
	Leap = { Shape = 'Circle', At = 'You', Radius = 8, Damage = 18, Reach = 36, Jump = true, Flight = 0.6 },
	Blast = { Shape = 'Cone', Length = 20, Angle = math.rad(70), Damage = 16, Reach = 18 },
}
-- Each boss's moves (phase 1), its rage move (phase 2 adds it), what it throws, and the moves' names on screen.
EnemyRules.Bosses = {
	bullies = { Title = 'Big Bully Brock', Moves = { 'Charge', 'Stomp' }, Rage = 'Throw', Prop = 'Dodgeball',
		Names = { Charge = 'SHOULDER CHARGE!', Stomp = 'BIG STOMP!', Throw = 'DODGEBALL!' } },
	crooks = { Title = 'The Ringleader', Moves = { 'Throw', 'Charge' }, Rage = 'Volley', Prop = 'MoneyBag',
		Names = { Throw = 'MONEY BAG!', Charge = 'SNEAK DASH!', Volley = 'BAG BARRAGE!' } },
	ballers = { Title = 'Court King', Moves = { 'Stomp', 'Roll' }, Rage = 'Leap', Prop = 'Basketball',
		Names = { Stomp = 'BALL SHOCKWAVE!', Roll = 'CHEST PASS!', Leap = 'SLAM DUNK!' } },
	little = { Title = 'Big Shot Boss', Moves = { 'Blast', 'Charge' }, Rage = 'Stomp', Prop = 'Dodgeball',
		Names = { Blast = 'BOOMBOX BLAST!', Charge = 'BIG SHOT RUSH!', Stomp = 'GROUND POUND!' } },
	gangsters = { Title = 'Furcoat Frankie', Moves = { 'Stomp', 'Throw' }, Rage = 'Charge', Prop = 'MoneyBag',
		Names = { Stomp = 'COAT SPIN!', Throw = 'CASH BAG!', Charge = 'FUR RUSH!' } },
	muscle = { Title = 'The Foreman', Moves = { 'Throw', 'Charge' }, Rage = 'Stomp', Prop = 'Crate',
		Names = { Throw = 'CRATE TOSS!', Charge = 'HARD HAT CHARGE!', Stomp = 'GROUND POUND!' } },
	dockhands = { Title = 'The Dockmaster', Moves = { 'Roll', 'Stomp' }, Rage = 'Volley', Prop = 'Barrel',
		Names = { Roll = 'BARREL ROLL!', Stomp = 'DECK STOMP!', Volley = 'CRATE RAIN!' }, Props = { Volley = 'Crate' } },
	harbor = { Title = 'The Harbor Boss', Moves = { 'Stomp', 'Charge' }, Rage = 'Volley', Prop = 'Barrel',
		Names = { Stomp = 'TIDAL STOMP!', Charge = 'HARBOR RUSH!', Volley = 'BARREL STORM!' } },
}
-- Telegraph and rest between big moves, by phase: slower and gentler first, quicker at half HP (never under TeleMin).
function EnemyRules.teleTime(phase: number?): number
	return math.max(EnemyRules.TeleMin, (phase or 1) >= 2 and 1.1 or 1.4)
end
function EnemyRules.bossRest(phase: number?): number
	return (phase or 1) >= 2 and 2.6 or 3.8
end
function EnemyRules.bossOf(look: string?): any
	return EnemyRules.Bosses[EnemyRules.crewOf(look)] or EnemyRules.Bosses.bullies
end
-- The moves a boss can use now (phase 2 adds its rage move).
function EnemyRules.movesOf(g: any): { string }
	local b = EnemyRules.bossOf(g.Look)
	local list = table.clone(b.Moves)
	if (g.Phase or 1) >= 2 and b.Rage then table.insert(list, b.Rage) end
	return list
end

-- A big move aimed at `you` (map frame) from boss g: { Move, Shape, O (origin), D (unit direction), L, W, R, A, P (circle
-- centres), Tele, Damage, Flight }, or nil when none fits (you're out of every move's reach). The boss takes its moves
-- in turn; with one out of reach it tries the next.
function EnemyRules.planAttack(g: any, you: Vector3, arena: any): any
	local list = EnemyRules.movesOf(g)
	local d = flat(you - g.Pos)
	local dist = d.Magnitude
	local dir = dist > 1e-3 and d.Unit or Vector3.new(0, 0, 1)
	for k = 0, #list - 1 do
		local n = ((g.MoveN or 0) + k) % #list + 1
		local name = list[n]
		local m = EnemyRules.Moves[name]
		if m and dist <= m.Reach then
			g.MoveN = n
			local a = { Move = name, Shape = m.Shape, O = g.Pos, D = dir, L = m.Length, W = m.Width, R = m.Radius, A = m.Angle, Tele = EnemyRules.teleTime(g.Phase), Damage = m.Damage, Flight = m.Flight, Jump = m.Jump }
			if m.At == 'You' then
				a.P = { EnemyRules.clamp(flat(you), arena) }
				for c = 2, m.Count or 1 do
					local ang = (c - 1.5) * 2.1 + (g.MoveN or 0)
					a.P[c] = EnemyRules.clamp(flat(you) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * m.Spread, arena)
				end
			elseif m.At == 'Self' then
				a.P = { g.Pos }
			end
			return a
		end
	end
	return nil
end

-- Is the point p (map frame) inside the attack's shape (shrunk by Fair)?
function EnemyRules.inAttack(a: any, p: Vector3): boolean
	if not a or typeof(p) ~= 'Vector3' then return false end
	local q = flat(p)
	local fair = EnemyRules.Fair
	if a.Shape == 'Line' then
		local rel = q - a.O
		local along = rel:Dot(a.D)
		local side = math.abs(rel.X * a.D.Z - rel.Z * a.D.X)
		return along >= -0.5 and along <= a.L - fair and side <= a.W / 2 - fair
	elseif a.Shape == 'Circle' then
		for _, c in a.P or {} do
			if (q - c).Magnitude <= a.R - fair then return true end
		end
		return false
	elseif a.Shape == 'Cone' then
		local rel = q - a.O
		local dist = rel.Magnitude
		if dist > a.L - fair then return false end
		if dist < 2 then return true end
		return math.acos(math.clamp(rel.Unit:Dot(a.D), -1, 1)) <= a.A / 2
	end
	return false
end

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
	local weight = (kind == 'Boss' and type(stage) == 'number' and stage >= #EnemyRules.Lineups) and EnemyRules.FinalBossHp or k.Hp
	local hp = EnemyRules.HpShots * weight * EnemyRules.recommended(stage)
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
--   (brief 29) `looks(stage)` (optional) says who they are: { minions = {key, ...}, boss = key? } as the server's
--   EnemyLooks.forStage gives it (default EnemyRules.looksFor, the same keys). Each goon gets Look (its HoodEnemies key)
--   and a court stage's arena its fence (Fences) and players' tunnel (Tunnel, Mouth); a goon living on the court walks
--   out of the tunnel (Walkout).
function EnemyRules.world(gates: { any }, lastDepth: number?, looks: ((number) -> any)?): ({ [number]: { any } }, { [number]: any })
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
			local court = EnemyRules.Courts[stage]
			if court then
				local f = court.Fence
				arena.Fences = { { X = f.X, Z0 = g.Z - f.Z1, Z1 = g.Z - f.Z0, D0 = g.Z - f.Door[2], D1 = g.Z - f.Door[1] } }
				arena.Tunnel = Vector3.new(court.Tunnel[1], 0, g.Z - court.Tunnel[2])
				arena.Mouth = Vector3.new(court.Mouth[1], 0, g.Z - court.Mouth[2])
			end
			local cast = EnemyRules.cast(stage, lineup, looks)
			local list = {}
			for i, kind in lineup do
				local spot = spots[i]
				if spot then
					local home = Vector3.new(math.clamp(spot[1], -arena.X, arena.X), 0, math.clamp(g.Z - spot[2], arena.Z1, arena.Z0))
					list[i] = { Kind = kind, Name = EnemyRules.tagName(stage, kind), Home = home, Look = cast[i], Walkout = (court and home.X > court.Fence.X) or nil }
				end
			end
			world[stage], arenas[stage] = list, arena
		end
	end
	return world, arenas
end

---------------------------------------------------------------------------------------------- one goon
-- A goon: { Kind, Home, Pos (Vector3, map frame, Y 0), State, T (timer), Slot (0..1: where round you it stands),
-- Look (its HoodEnemies key, brief 29) }.
function EnemyRules.new(kind: string, home: Vector3, slot: number?, look: string?): any
	return { Kind = kind, Home = home, Pos = home, State = EnemyRules.Idle, T = 0, Slot = slot or 0, Look = look }
end


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
	-- (brief 29) a fence in the way (the court's chain-link): through its gateway, not through the wire
	local wp = EnemyRules.via(pos, goal, arena)
	if wp ~= goal then goal, stopAt = wp, 0 end
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
-- 'home' (back on its spot), (brief 29, a boss) 'tele' (a big move starts: g.Atk) and 'blast' + landed (it lands), or nil.
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
		g.State, g.T, g.Atk = S.Return, 0, nil
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
		g.T += dt -- (how long it has been heading home)
		g.Pos = stepToward(g.Pos, g.Home, k.Speed, dt, 0, arena)
		if (g.Pos - g.Home).Magnitude < 0.05 or g.T >= S.ReturnMax then
			g.Pos, g.State, g.T = g.Home, S.Idle, 0
			return 'home'
		end
		return nil
	end
	local dist = (t - g.Pos).Magnitude
	if g.Kind == 'Boss' and g.State ~= S.Tele and g.State ~= S.Dash and g.State ~= S.Alert then
		-- (brief 29) a boss's big move: when it's rested and you're in a move's reach (between punches too)
		g.CD = (g.CD or S.BossFirst) - dt
		if g.CD <= 0 and (g.State == S.Chase or g.State == S.Recover) then
			local atk = S.planAttack(g, t, arena)
			if atk then
				g.Atk, g.State, g.T = atk, S.Tele, atk.Tele
				return 'tele'
			end
		end
	end
	if g.State == S.Tele then
		g.T -= dt
		if g.T > 0 then return nil end
		local atk = g.Atk
		local landed = atk ~= nil and S.inAttack(atk, t)
		g.CD = S.bossRest(g.Phase)
		g.State, g.T = S.Recover, k.Recover
		if atk and atk.Move == 'Charge' then
			-- down the lane (as far as the street lets it)
			g.DashFrom, g.DashTo = g.Pos, S.clamp(atk.O + atk.D * (atk.L - 2), arena)
			g.State, g.T = S.Dash, S.DashTime
		elseif atk and atk.Jump and atk.P then
			g.Pos = S.clamp(atk.P[1], arena) -- (it landed on the spot)
		end
		return 'blast', landed
	elseif g.State == S.Dash then
		g.T -= dt
		local a = 1 - math.max(0, g.T) / S.DashTime
		if g.DashFrom and g.DashTo then g.Pos = S.clamp(g.DashFrom:Lerp(g.DashTo, a), arena) end
		if g.T <= 0 then g.State, g.T, g.DashFrom, g.DashTo = S.Recover, k.Recover, nil, nil end
		return nil
	end
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

-- Every goon back to its spot: they walk home (your KO, where they keep their HP; or you left the stage, where
-- WaveRules.restore has made them whole first).
function EnemyRules.sendHome(goons: { any })
	for _, g in goons do
		if g.State ~= EnemyRules.Down and g.State ~= EnemyRules.Idle then g.State, g.T = EnemyRules.Return, 0 end
	end
end

return EnemyRules
