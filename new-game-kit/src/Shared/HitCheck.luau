--!strict
-- New Game Kit: HitCheck (vault "Realistic City RP/04 Combat - Fists, Weapons and Server Hit Validation")
-- Install: ReplicatedStorage/Kit/HitCheck (ModuleScript). Pure maths: no remotes, no raycasts of its own.
--
-- The client shoots and swings so it FEELS instant (its own tracer, sound, recoil, hit marker).
-- Then it tells the server "I fired weapon W from here, in this direction, at time T, and I think I hit X".
-- The server runs these checks with ITS OWN positions before any damage happens:
--
--   local history = HitCheck.History.new(1.0)       -- one per character, server side
--   history:Push(now, rootPosition)                 -- every Heartbeat (or every 2nd)
--   history:At(t)                                   -> Vector3? where that character was at time t (rewind)
--
--   HitCheck.Shot(weapon, claim, ctx)               -> ok, reason
--     weapon = { range, fireInterval, spreadDeg, magazine }
--     claim  = { origin: Vector3, direction: Vector3 (unit), targetPos: Vector3? }
--     ctx    = { headPos (server), lastShotAt, now, ammo, targetAt (rewound server pos or nil),
--                lineOfSight: boolean? (server Raycast result: true = nothing in the way) }
--   HitCheck.Melee(move, ctx)                       -> ok, reason   (fists, bat: range + front cone)
--   HitCheck.Damage(weapon, distance, part)         -> number       (falloff, head x1.5 cap)
--
-- Reasons are for logs and a per-player strike counter, never for kicking on one miss
-- (LihFolk "False Positives Lag and Fair Enforcement"). Server Authority (full release
-- July 2026) stops speed and teleport hacks but NOT fake hit reports, so these checks stay.
-- Status: covered by tests/HitCheck.spec.luau (offline).

local HitCheck = {}

HitCheck.Tolerance = {
	originStuds = 6, -- how far the claimed muzzle may sit from the server's head position (lag + arm length)
	angleExtraDeg = 4, -- added to the weapon's own spread for lag
	targetStuds = 7, -- claimed hit point vs where the server (rewound) had the target
	fireRateSlack = 0.85, -- a shot may come 15% early (network bunching), never more
	maxRewind = 0.4, -- seconds; older claims are refused (stops "shoot from the past")
	meleeExtraStuds = 2.5,
}

export type Weapon = { range: number, fireInterval: number, spreadDeg: number?, magazine: number?, damage: number?, falloffStart: number? }
export type Claim = { origin: Vector3, direction: Vector3, targetPos: Vector3? }
export type ShotContext = {
	headPos: Vector3,
	now: number,
	lastShotAt: number?,
	ammo: number?,
	targetAt: Vector3?,
	lineOfSight: boolean?,
	alive: boolean?,
}

local function dot(a: Vector3, b: Vector3): number
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

local function finite(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

function HitCheck.AngleDeg(a: Vector3, b: Vector3): number
	local m = a.Magnitude * b.Magnitude
	if m == 0 then
		return 180
	end
	local c = math.clamp(dot(a, b) / m, -1, 1)
	return math.deg(math.acos(c))
end

function HitCheck.Shot(weapon: Weapon, claim: Claim, ctx: ShotContext): (boolean, string)
	if ctx.alive == false then
		return false, "Dead"
	end
	if not finite(claim.origin) or not finite(claim.direction) or claim.direction.Magnitude < 0.5 then
		return false, "BadData"
	end
	if ctx.lastShotAt and ctx.now - ctx.lastShotAt < weapon.fireInterval * HitCheck.Tolerance.fireRateSlack then
		return false, "TooFast"
	end
	if weapon.magazine ~= nil and (ctx.ammo or 0) <= 0 then
		return false, "NoAmmo"
	end
	if (claim.origin - ctx.headPos).Magnitude > HitCheck.Tolerance.originStuds then
		return false, "OriginFar"
	end
	if claim.targetPos == nil then
		return true, "Miss" -- a valid shot that hit nothing: spend ammo, no damage
	end
	local targetPos = claim.targetPos :: Vector3
	if not finite(targetPos) then
		return false, "BadData"
	end
	local toTarget = targetPos - claim.origin
	if toTarget.Magnitude > weapon.range then
		return false, "OutOfRange"
	end
	local allowed = (weapon.spreadDeg or 0) + HitCheck.Tolerance.angleExtraDeg
	if toTarget.Magnitude > 1 and HitCheck.AngleDeg(claim.direction, toTarget) > allowed then
		return false, "Angle"
	end
	if ctx.targetAt == nil then
		return false, "NoHistory"
	end
	if (targetPos - (ctx.targetAt :: Vector3)).Magnitude > HitCheck.Tolerance.targetStuds then
		return false, "TargetFar"
	end
	if ctx.lineOfSight == false then
		return false, "Blocked"
	end
	return true, "Hit"
end

export type Move = { range: number, coneDeg: number, cooldown: number }
export type MeleeContext = {
	attackerPos: Vector3,
	attackerLook: Vector3,
	targetPos: Vector3,
	now: number,
	lastSwingAt: number?,
	alive: boolean?,
}

function HitCheck.Melee(move: Move, ctx: MeleeContext): (boolean, string)
	if ctx.alive == false then
		return false, "Dead"
	end
	if ctx.lastSwingAt and ctx.now - ctx.lastSwingAt < move.cooldown * HitCheck.Tolerance.fireRateSlack then
		return false, "TooFast"
	end
	local offset = ctx.targetPos - ctx.attackerPos
	if offset.Magnitude > move.range + HitCheck.Tolerance.meleeExtraStuds then
		return false, "OutOfRange"
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(ctx.attackerLook.X, 0, ctx.attackerLook.Z)
	if flat.Magnitude > 1 and HitCheck.AngleDeg(look, flat) > move.coneDeg / 2 + 10 then
		return false, "Behind"
	end
	return true, "Hit"
end

-- Linear falloff from falloffStart to range (down to 50%); head hits x1.5.
function HitCheck.Damage(weapon: Weapon, distance: number, part: string?): number
	local base = weapon.damage or 10
	local start = weapon.falloffStart or weapon.range
	local scale = 1
	if distance > start and weapon.range > start then
		scale = 1 - 0.5 * math.clamp((distance - start) / (weapon.range - start), 0, 1)
	end
	if part == "Head" then
		scale *= 1.5
	end
	return math.floor(base * scale + 0.5)
end

-- Position history for lag-compensated ("rewound") checks.
local History = {}
History.__index = History
HitCheck.History = History

export type Sample = { t: number, p: Vector3 }

function History.new(keepSeconds: number?)
	return setmetatable({ keep = keepSeconds or 1, samples = {} :: { Sample } }, History)
end

function History:Push(t: number, p: Vector3)
	local samples = self.samples
	table.insert(samples, { t = t, p = p })
	while #samples > 2 and t - samples[1].t > self.keep do
		table.remove(samples, 1)
	end
end

-- Where the character was at time t (linear blend between samples). nil when t is too old
-- (past Tolerance.maxRewind from the newest sample) or there is no data.
function History:At(t: number): Vector3?
	local samples = self.samples
	local n = #samples
	if n == 0 then
		return nil
	end
	local newest = samples[n]
	if newest.t - t > HitCheck.Tolerance.maxRewind then
		return nil
	end
	if t >= newest.t then
		return newest.p
	end
	for i = n, 2, -1 do
		local a, b = samples[i - 1], samples[i]
		if t >= a.t and t <= b.t then
			local span = b.t - a.t
			local k = if span > 0 then (t - a.t) / span else 0
			return a.p + (b.p - a.p) * k
		end
	end
	return samples[1].p
end

return HitCheck
