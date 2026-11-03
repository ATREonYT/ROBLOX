--!strict
-- Pure maths for the living neighbourhood (no Instances; tested by tools/tests/test_ambient_rules.py).
-- Paths are lists of {x, z} points (studs). A "path" table caches cumulative lengths so walking along it is cheap.
local AmbientRules = {}

export type Path = { pts: { { number } }, cum: { number }, total: number, loop: boolean, corners: { [number]: boolean } }

-- linear curve lookup: curve = { {x, y}, ... } sorted by x
function AmbientRules.curve(curve: { { number } }, x: number): number
	if x <= curve[1][1] then
		return curve[1][2]
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if x <= b[1] then
			local t = (x - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return curve[#curve][2]
end

-- how many of `max` people are out at this clock hour
function AmbientRules.crowd(max: number, hour: number, curve: { { number } }): number
	return math.clamp(math.floor(max * AmbientRules.curve(curve, hour % 24) + 0.5), 0, max)
end

function AmbientRules.path(pts: { { number } }, loop: boolean?, corners: { number }?): Path
	local cum = { 0 }
	local total = 0
	local n = #pts
	local last = if loop then n else n - 1
	for i = 1, last do
		local a, b = pts[i], pts[(i % n) + 1]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		cum[i + 1] = total
	end
	local set = {}
	for _, c in corners or {} do
		set[c] = true
	end
	return { pts = pts, cum = cum, total = total, loop = loop == true, corners = set }
end

-- segment index i such that cum[i] <= d < cum[i+1] (binary search)
local function segAt(p: Path, d: number): number
	local lo, hi = 1, #p.cum - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if p.cum[mid] <= d then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

-- wraps (loop) or clamps (open) a distance along the path
function AmbientRules.wrap(p: Path, d: number): number
	if p.total <= 0 then
		return 0
	end
	if p.loop then
		return d % p.total
	end
	return math.clamp(d, 0, p.total)
end

-- point and unit heading at distance d. Returns x, z, dx, dz, segment
function AmbientRules.sample(p: Path, d: number): (number, number, number, number, number)
	local n = #p.pts
	if n == 1 or p.total <= 0 then
		return p.pts[1][1], p.pts[1][2], 0, -1, 1
	end
	d = AmbientRules.wrap(p, d)
	local i = segAt(p, d)
	local a, b = p.pts[i], p.pts[(i % n) + 1]
	local len = p.cum[i + 1] - p.cum[i]
	local t = if len > 0 then (d - p.cum[i]) / len else 0
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local m = math.sqrt(dx * dx + dz * dz)
	if m > 0 then
		dx, dz = dx / m, dz / m
	else
		dx, dz = 0, -1
	end
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, dx, dz, i
end

-- distance along the path to the next flagged corner ahead of d (math.huge if none within `look`)
function AmbientRules.cornerAhead(p: Path, d: number, look: number): number
	local n = #p.pts
	d = AmbientRules.wrap(p, d)
	local i = segAt(p, d)
	local best = math.huge
	for k = 1, n do
		local j = i + k -- corner at the END of segment i is point i+1
		local idx = ((j - 1) % n) + 1
		if not p.loop and j > n then
			break
		end
		local at = if j <= #p.cum then p.cum[j] else p.total + p.cum[j - n]
		local dist = at - d
		if dist > look then
			break
		end
		if p.corners[idx] and dist >= 0 then
			best = dist
			break
		end
	end
	return best
end

-- the speed a car wants: cruise, eased down into corners, zero if blocked
function AmbientRules.targetSpeed(cruise: number, cornerDist: number, cfg: any, blockedDist: number?): number
	local v = cruise
	if cornerDist < cfg.CornerSlowDist then
		local t = math.clamp(cornerDist / cfg.CornerSlowDist, 0, 1)
		v = cruise * (cfg.CornerSpeed + (1 - cfg.CornerSpeed) * t)
	end
	if blockedDist and blockedDist < cfg.StopAhead then
		local t = math.clamp((blockedDist - 4) / math.max(cfg.StopAhead - 4, 1), 0, 1)
		v = math.min(v, cruise * t)
	end
	return v
end

-- move v toward target with separate accel / brake rates
function AmbientRules.approach(v: number, target: number, accel: number, brake: number, dt: number): number
	if v < target then
		return math.min(target, v + accel * dt)
	end
	return math.max(target, v - brake * dt)
end

-- nearest distance-along-path to a point (for spawning near the player); returns d, distance
function AmbientRules.nearest(p: Path, x: number, z: number): (number, number)
	local n = #p.pts
	local bestD, bestDist = 0, math.huge
	local last = if p.loop then n else n - 1
	for i = 1, last do
		local a, b = p.pts[i], p.pts[(i % n) + 1]
		local vx, vz = b[1] - a[1], b[2] - a[2]
		local len2 = vx * vx + vz * vz
		local t = if len2 > 0 then math.clamp(((x - a[1]) * vx + (z - a[2]) * vz) / len2, 0, 1) else 0
		local px, pz = a[1] + vx * t, a[2] + vz * t
		local dist = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if dist < bestDist then
			bestDist = dist
			bestD = p.cum[i] + math.sqrt(len2) * t
		end
	end
	return bestD, bestDist
end

-- can something appear at offset (dx, dz) from the camera without popping in view?
-- far enough away, or behind the camera (look = camera look vector on the ground)
function AmbientRules.hiddenSpawn(dx: number, dz: number, lookX: number, lookZ: number, minDist: number, behindDot: number): boolean
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= minDist then
		return true
	end
	if d < 1e-3 then
		return false
	end
	local lm = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lm < 1e-3 then
		return false
	end
	return (dx * lookX + dz * lookZ) / (d * lm) < behindDot
end

-- deterministic 0..1 noise from an integer and a seed (same answer on every client)
function AmbientRules.hash(i: number, seed: number): number
	-- Park-Miller steps; every product stays under 2^53 so doubles (Luau) and integers (tests) agree
	local h = (math.floor(i) * 7919 + math.floor(seed) * 104729 + 12345) % 2147483647
	h = (h * 48271) % 2147483647
	h = (h * 48271) % 2147483647
	return (h % 100000) / 100000
end

-- is window i lit at this hour? 0 = dark, 1 = warm, 2 = TV flicker. `day` changes the pattern each night.
function AmbientRules.windowState(i: number, hour: number, day: number, cfg: any): number
	local h = hour % 24
	local share = 0
	if h >= cfg.On or h < cfg.FadeStart then
		share = cfg.LitShare[1] + (cfg.LitShare[2] - cfg.LitShare[1]) * AmbientRules.hash(day, 7)
	elseif h < cfg.FadeEnd then
		local base = cfg.LitShare[1] + (cfg.LitShare[2] - cfg.LitShare[1]) * AmbientRules.hash(day, 7)
		local t = (h - cfg.FadeStart) / (cfg.FadeEnd - cfg.FadeStart)
		share = base + (cfg.LateShare - base) * t
	elseif h < cfg.MorningOn then
		share = cfg.LateShare
	elseif h < cfg.Off then
		share = cfg.MorningShare
	else
		return 0
	end
	local r = AmbientRules.hash(i, 1000 + day)
	if r >= share then
		return 0
	end
	-- the TV share is taken from the lit ones (the last to go dark: night owls watching TV)
	if r < math.min(cfg.TVShare, share) then
		return 2
	end
	return 1
end

-- indices of the `n` smallest values in `dists` (nil entries skipped); stable for ties
function AmbientRules.nearestN(dists: { number? }, n: number, maxCount: number): { number }
	local idx = {}
	for i = 1, maxCount do
		if dists[i] ~= nil then
			table.insert(idx, i)
		end
	end
	table.sort(idx, function(a, b)
		local da, db = dists[a] :: number, dists[b] :: number
		if da == db then
			return a < b
		end
		return da < db
	end)
	local out = {}
	for k = 1, math.min(n, #idx) do
		out[k] = idx[k]
	end
	return out
end

-- a "pure" colour = a fully saturated primary/secondary or pure white/black (we never use those)
function AmbientRules.isPure(r: number, g: number, b: number): boolean
	local function ext(v: number): boolean
		return v <= 8 or v >= 247
	end
	return ext(r) and ext(g) and ext(b)
end

-- how many people a corner group gets: `wanted` (nil = caller rolls 2-4) limited by free rigs; 0 = no group.
-- Never calls math.clamp with max < min (that crashed the loop when the pool ran low), and survives nil/NaN/inf.
function AmbientRules.groupSize(wanted: number?, free: number): number
	if free ~= free or free < 2 then
		return 0
	end
	local w = wanted
	if w == nil or w ~= w then
		w = 3
	end
	local hi = math.min(4, math.floor(free))
	return math.max(2, math.min(math.floor(w), hi))
end

-- which shop interior (if any) the point (x, y, z) is in. Survives the interiors being rebuilt or resized:
--   roof, floor   names of the part straight above / below the player and its ancestors (nil = sky / nothing)
--   shops    { key, model, by = "floor" | "roof", r, anchors = { {x, y, z}, ... } } (anchors = Locations Inside / Door)
-- Inside = there is a roof, and the `by` part (the shop's own floor, or its roof where the floor is terrain) belongs
-- to a model whose name starts with `model`, within `find` studs of an anchor (other buildings share names, e.g.
-- AutoShop, far away; a shell's roof overhangs the sidewalk, so floor wins where the shop has one).
-- Fallback for a renamed model: any roof within `r` of the first anchor (Inside; the Door is outside).
local function named(chain: { string }?, prefix: string): boolean
	for _, n in chain or {} do
		if string.sub(n, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function AmbientRules.shopAt(x: number, y: number, z: number, roof: { string }?, floor: { string }?, shops: { any }, find: number): string?
	if not roof then
		return nil
	end
	for _, s in shops do
		local d, inner = math.huge, math.huge
		for i, a in s.anchors do
			if math.abs(y - a[2]) < 24 then
				d = math.min(d, math.sqrt((x - a[1]) ^ 2 + (z - a[3]) ^ 2))
				if i == 1 then
					inner = d
				end
			end
		end
		if inner < s.r then
			return s.key
		end
		local part = if s.by == "roof" then roof else floor
		if d < find and named(part, s.model) then
			return s.key
		end
	end
	return nil
end

-- which chatter list fits: night after 20:00 or before 5:00
function AmbientRules.lineSet(hour: number): string
	local h = hour % 24
	return if h >= 20 or h < 5 then "Night" else "Day"
end

-- the head turn (radians, + = left) for a person at yaw `facing` looking toward (dx, dz); nil if behind them
function AmbientRules.lookYaw(faceX: number, faceZ: number, dx: number, dz: number): number?
	local a = math.atan2(-faceX, -faceZ)
	local b = math.atan2(-dx, -dz)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	if math.abs(d) > 1.6 then
		return nil
	end
	return math.clamp(d, -0.8, 0.8)
end

return AmbientRules
