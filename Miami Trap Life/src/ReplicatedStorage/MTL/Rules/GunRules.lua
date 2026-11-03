--!strict
-- Pure gun maths and rules (no Instances, no Vector3), shared by GunService and GunController and unit-tested
-- by tools/tests/test_gun_rules.py. Angles in degrees unless a name says Rad.
local GunRules = {}

---------------------------------------------------------------- who may do what

-- Can this player take this gun out? mode = "Live" | "Intimidate".
function GunRules.canEquip(path: string, mode: string, onShift: boolean, inSafe: boolean, alive: boolean): (boolean, string?)
	if not alive then
		return false, "You're down"
	end
	if mode == "Intimidate" then
		return true, nil -- story guns: any path, safe zones too (the robbery happens inside the store)
	end
	if path ~= "Criminal" then
		return false, "Guns are for the Criminal lifestyle (phone: Settings)"
	end
	if onShift then
		return false, "Not while you're on shift"
	end
	if inSafe then
		return false, "Safe zone: guns stay holstered here"
	end
	return true, nil
end

-- Can a shot from attacker hurt this target?
--   target = { isPlayer, path, safe, damageable (NPC attribute MTL_Damageable), self }
function GunRules.canDamage(mode: string, attackerPath: string, attackerSafe: boolean, target: any): (boolean, string?)
	if mode ~= "Live" then
		return false, "no-damage gun"
	end
	if target.self then
		return false, "self"
	end
	if not target.isPlayer then
		return target.damageable == true, if target.damageable then nil else "protected NPC"
	end
	if attackerPath ~= "Criminal" then
		return false, "attacker not criminal"
	end
	if target.path ~= "Criminal" then
		return false, "target is a civilian"
	end
	if attackerSafe or target.safe then
		return false, "safe zone"
	end
	return true, nil
end

---------------------------------------------------------------- damage

-- Linear falloff: 100% up to FalloffStart, FalloffMin from FalloffEnd on.
function GunRules.falloff(def: any, distance: number): number
	local s, e = def.FalloffStart or 0, def.FalloffEnd or def.Range or 1
	if distance <= s then
		return 1
	end
	if distance >= e or e <= s then
		return def.FalloffMin or 1
	end
	local a = (distance - s) / (e - s)
	return 1 + ((def.FalloffMin or 1) - 1) * a
end

function GunRules.damage(def: any, distance: number, head: boolean): number
	if distance > (def.Range or 0) then
		return 0
	end
	local d = def.Damage * GunRules.falloff(def, distance) * (if head then def.HeadMult or 1 else 1)
	return math.floor(d * 10 + 0.5) / 10
end

-- Shots to kill `health` at a distance with body shots (balance tests + the shop card).
function GunRules.shotsToKill(def: any, health: number, distance: number, head: boolean?): number
	local per = GunRules.damage(def, distance, head == true) * (def.Pellets or 1)
	if per <= 0 then
		return math.huge
	end
	return math.ceil(health / per - 1e-9)
end

function GunRules.timeToKill(def: any, health: number, distance: number): number
	local n = GunRules.shotsToKill(def, health, distance)
	return (n - 1) * GunRules.fireInterval(def)
end

---------------------------------------------------------------- fire rate

function GunRules.fireInterval(def: any): number
	return 60 / def.RPM
end

-- Server-side token bucket. tokens refill at RPM/60 / tolerance per second, at most `burst`.
function GunRules.newBucket(burst: number, now: number)
	return { tokens = burst, t = now }
end

function GunRules.rateAllow(bucket: any, def: any, now: number, tolerance: number, burst: number): boolean
	local rate = (def.RPM / 60) / tolerance
	bucket.tokens = math.min(burst, bucket.tokens + math.max(0, now - bucket.t) * rate)
	bucket.t = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

---------------------------------------------------------------- spread

-- state = { aiming, moving, airborne, bloom }
function GunRules.spread(def: any, state: any): number
	local s = def.Spread
	local base = if state.aiming then s.Aim else s.Hip
	if state.moving then
		base += s.Move * (if state.aiming then 0.5 else 1)
	end
	if state.airborne then
		base += s.Air
	end
	return base + math.clamp(state.bloom or 0, 0, s.MaxBloom or 0)
end

-- The widest cone this gun can ever have (server angle check).
function GunRules.maxSpread(def: any): number
	local s = def.Spread
	return math.max(s.Hip, s.Aim) + s.Move + s.Air + (s.MaxBloom or 0) + (def.PelletSpread or 0)
end

function GunRules.bloomAfterShot(def: any, bloom: number): number
	return math.min((def.Spread.MaxBloom or 0), bloom + (def.Spread.Bloom or 0))
end

function GunRules.bloomRecover(def: any, bloom: number, dt: number): number
	return math.max(0, bloom - (def.Spread.Recover or 0) * dt)
end

-- A random direction inside a cone, uniform over the disc. u1, u2 in [0, 1).
-- Returns (pitchRad, yawRad) to apply as CFrame.Angles(pitch, yaw, 0) on the aim CFrame.
function GunRules.coneOffset(maxDeg: number, u1: number, u2: number): (number, number)
	local r = math.rad(maxDeg) * math.sqrt(u1)
	local a = 2 * math.pi * u2
	return r * math.cos(a), r * math.sin(a)
end

-- Angle between two direction vectors given as numbers.
function GunRules.angle(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number
	local la = math.sqrt(ax * ax + ay * ay + az * az)
	local lb = math.sqrt(bx * bx + by * by + bz * bz)
	if la < 1e-6 or lb < 1e-6 then
		return 180
	end
	local c = math.clamp((ax * bx + ay * by + az * bz) / (la * lb), -1, 1)
	return math.deg(math.acos(c))
end

---------------------------------------------------------------- recoil

-- Camera kick for one shot: (up, side) degrees. sideRand in [-1, 1].
function GunRules.recoilKick(def: any, sideRand: number, scale: number?): (number, number)
	local r = def.Recoil
	local k = scale or 1
	return r.Up * k, r.Side * sideRand * k
end

-- Split a kick: `stay` part moves the camera for good (full-auto climbs), `bounce` part springs back.
function GunRules.recoilSplit(def: any, up: number): (number, number)
	local ret = math.clamp(def.Recoil.Return or 0.7, 0, 1)
	return up * (1 - ret), up * ret
end

-- Damped spring toward 0. s = { x, v }. stiffness k, damping ratio z (1 = critical). Sub-stepped for stability.
function GunRules.springStep(s: any, k: number, z: number, dt: number)
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	local c = 2 * math.sqrt(k) * z
	for _ = 1, steps do
		local a = -k * s.x - c * s.v
		s.v += a * h
		s.x += s.v * h
	end
	return s
end

-- Launch speed so the spring's peak is about `peak` (critically damped peak = v0 / (w * e)).
function GunRules.kickVelocity(peak: number, k: number): number
	return peak * math.sqrt(k) * math.exp(1)
end

---------------------------------------------------------------- ammo

-- Reload: fill the mag from the reserve. Returns newMag, newReserve.
function GunRules.reload(mag: number, magSize: number, reserve: number): (number, number)
	local need = math.max(0, magSize - mag)
	local take = math.min(need, math.max(0, reserve))
	return mag + take, reserve - take
end

function GunRules.canReload(mag: number, magSize: number, reserve: number): boolean
	return mag < magSize and reserve > 0
end

---------------------------------------------------------------- hit checks

-- Distance from a point (in the box's local space) to a box of half-size (hx, hy, hz). 0 = inside.
function GunRules.boxDistance(lx: number, ly: number, lz: number, hx: number, hy: number, hz: number): number
	local dx = math.max(math.abs(lx) - hx, 0)
	local dy = math.max(math.abs(ly) - hy, 0)
	local dz = math.max(math.abs(lz) - hz, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Lag-comp history: indices of the samples to test for a shot at time t (server clock) given "now".
-- times = ascending list. Returns the list of indices whose time is inside [max(now-maxRewind, t-window), now].
function GunRules.rewindSamples(times: { number }, t: number, now: number, maxRewind: number, window: number): { number }
	local from = math.max(now - maxRewind, math.min(t, now) - window)
	local out = {}
	for i, ti in times do
		if ti >= from and ti <= now + 1e-6 then
			table.insert(out, i)
		end
	end
	return out
end

-- In a fight = shot at or got hit by a player within FightSeconds.
function GunRules.inFight(lastCombat: number?, now: number, seconds: number): boolean
	return lastCombat ~= nil and now - lastCombat < seconds
end

-- Is a point inside a round config zone? (x, z distance, y within height)
function GunRules.inZone(px: number, py: number, pz: number, cx: number, cy: number, cz: number, radius: number, height: number): boolean
	local dx, dz = px - cx, pz - cz
	return dx * dx + dz * dz <= radius * radius and math.abs(py - cy) <= height
end

-- Shop: can the player buy this gun? owned = already have it.
function GunRules.canBuyGun(def: any, level: number, cash: number, path: string, owned: boolean): (boolean, string?)
	if path ~= "Criminal" then
		return false, "Criminal lifestyle only"
	end
	if owned then
		return false, "Already yours"
	end
	if level < (def.Level or 1) then
		return false, "Level " .. tostring(def.Level)
	end
	if cash < def.Price then
		return false, "Not enough cash"
	end
	return true, nil
end

function GunRules.canBuyAmmo(pack: any, reserve: number, cash: number, path: string, ownsUser: boolean): (boolean, string?)
	if path ~= "Criminal" then
		return false, "Criminal lifestyle only"
	end
	if not ownsUser then
		return false, "You don't have a gun for this"
	end
	if reserve >= pack.Max then
		return false, "Full"
	end
	if cash < pack.Price then
		return false, "Not enough cash"
	end
	return true, nil
end

-- Crosshair gap in pixels for a cone of `deg` on a screen `height` px tall with vertical fov `fov`.
function GunRules.crosshairGap(deg: number, fov: number, height: number): number
	return math.tan(math.rad(deg)) / math.tan(math.rad(fov / 2)) * height / 2
end

return GunRules
