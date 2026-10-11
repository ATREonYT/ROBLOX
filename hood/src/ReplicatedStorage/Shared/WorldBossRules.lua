-- (brief 29, P3b) The World Boss: a timed, server-wide boss everyone fights together (the reference's "WORLD BOSS /
-- SHOGUN / 0:26 / JOIN", refs29 section 6). Every Interval seconds of server time a giant crew boss lands on the World
-- Boss pier (code5/f4_finale Finale.arena: behind the lobby, outside the boundary wall); the invite (JOIN) shows Warn
-- seconds before. Everyone on the pier shoots it; its HP is set by who is there (each player's Power x ShotsEach, more
-- added as players join), and when it goes down the Cash pool is split by damage share (everyone who hit it gets at
-- least MinReward). If nobody beats it in FightTime it leaves (no pool). Pure rules: HoodServer/WorldBossService runs
-- it, HoodClient/WorldBoss draws it; the unit tests read this.
local EnemyRules = require(script.Parent.EnemyRules)
local R = {}
R.Interval = 8 * 60 -- a boss every 8 minutes of server time (every server agrees: it's the clock, not a timer)
R.Warn = 45 -- the invite shows this long before it lands
R.FightTime = 150 -- it leaves after this long
R.Arena = { X = 0, Z = 330, Half = 34 } -- the pier, map frame (centre and half its side)
R.Home = { 0, 322 } -- where it stands (map frame x, z)
R.Scale = 5 -- its size (Model:ScaleTo, absolute: a crew boss is 1.5)
R.ShotsEach = 120 -- its HP per player there: their Power x this
R.MinHp = 1000
R.Pool = { Base = 400, Each = 150, Max = 3000 } -- Cash: Base + Each per player who hit it
R.MinReward = 40
R.Tick = 0.1
-- Who comes (in turn): the crews' bosses, grown huge (their own moves; the look keys the server builds).
R.Roster = { 'muscle_boss', 'gangsters_boss', 'dockhands_boss', 'crooks_boss', 'ballers_boss', 'bullies_boss' }
R.MoveScale = 1.7 -- its moves' shapes are this much bigger than the crew boss's

-- The schedule: the next landing at or after `now` (server time), and what's on at `now`.
function R.nextAt(now: number): number
	return math.ceil(now / R.Interval) * R.Interval
end
function R.slotOf(at: number): number
	return math.floor(at / R.Interval + 0.5)
end
-- 'Wait' (counting down), 'Invite' (JOIN shows), 'Fight'; and the time the current part ends.
function R.phase(now: number, fightFrom: number?, over: boolean?): (string, number)
	if fightFrom and not over and now < fightFrom + R.FightTime then return 'Fight', fightFrom + R.FightTime end
	local at = R.nextAt(now)
	if fightFrom and math.abs(at - fightFrom) < 1 then at += R.Interval end
	if at - now <= R.Warn then return 'Invite', at end
	return 'Wait', at
end
-- "m:ss"
function R.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format('%d:%02d', s // 60, s % 60)
end
-- Which look a landing brings (by its slot), and its name.
function R.lookFor(slot: number): string
	return R.Roster[(math.floor(slot) % #R.Roster) + 1]
end
function R.titleOf(look: string): string
	return 'GIANT ' .. string.upper(EnemyRules.bossOf(look).Title)
end
-- Its HP for the players there (their Power), at least MinHp; join(hp, max, power) adds a newcomer's share.
function R.hpFor(powers: { number }): number
	local hp = 0
	for _, p in powers do hp += math.max(1, math.floor(tonumber(p) or 0)) * R.ShotsEach end
	return math.max(R.MinHp, hp)
end
function R.join(hp: number, max: number, power: number): (number, number)
	local add = math.max(1, math.floor(tonumber(power) or 0)) * R.ShotsEach
	return hp + add, max + add
end
-- The Cash pool for n players who hit it.
function R.pool(n: number): number
	return math.min(R.Pool.Max, R.Pool.Base + R.Pool.Each * math.max(0, n))
end
-- The rewards: { [id] = damage } -> { [id] = Cash } by damage share (floor), at least MinReward each; and each id's share.
function R.split(damage: { [any]: number }, pool: number): ({ [any]: number }, { [any]: number })
	local total = 0
	for _, d in damage do total += math.max(0, d) end
	local out, share = {}, {}
	if total <= 0 then return out, share end
	for id, d in damage do
		if d > 0 then
			share[id] = d / total
			out[id] = math.max(R.MinReward, math.floor(pool * d / total))
		end
	end
	return out, share
end
-- A move scaled up for the giant (a copy of the attack with bigger shapes).
function R.grow(a: any): any
	if not a then return nil end
	local k = R.MoveScale
	a.L = a.L and a.L * k or nil
	a.W = a.W and a.W * k or nil
	a.R = a.R and a.R * k or nil
	a.Ri = a.Ri and a.Ri * k or nil
	return a
end
return R
