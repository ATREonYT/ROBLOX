--[[
	The Divine girl's arrival (owner, Oct 26: "for the divine, can you please make an animation that isnt the same as a
	secret, and make it even more crazy ... make it completely different from the secret animation ... make this way
	smoother and more fitting and better looking than the secret animation"). Drawn in the reference's anime style
	(17:42: "follow the animation styles as references given before, right now it looks too ai made"; design/vfx/ref3
	and design/vfx/vysvex-green-reference.mp4): a dark night so the gold reads, hard shapes, fast in and snapping out.
	"Fallen Star" (18:34: "remove the very basic ai looking effects of the start, and continuation, make it different,
	try it differently"): the perfect neon rings, the portal, the stick-straight spears and the flat streaks of the
	"Heaven's Gate" version are gone. A star falls out of the night and crashes on the spot, the ground cracks open
	with light, a whirlwind of golden crescents rises out of the crater and winds tighter and faster round the spot
	until a slash cuts it open and she bursts out of it, spinning, curved wings of light snapping open. She ascends in
	a spiral of gold and ends as a star twinkling over the map. ONE camera move with no cut.
	Pure numbers (no Roblox instances), as Shared/SecretReveal: HuzzClient/Gameplay/DivineReveal builds the effects
	and tools/preview/motion3d/secret_scene.luau (DIVINE=1) films the same.
	  0.0  NIGHT       the world falls to a deep blue night; gold embers drift up; the camera low, looking up
	  0.15 STAR        a star twinkles on high, growing
	  0.55 FALL        it falls, faster and faster, a long gold tail behind it, the camera tilting down with it
	  1.4  CRASH       it hits: the impact frame (0.12 s, black ink on white), a shockwave, gold shards fly, cracks of
	                   light race out over the ground
	  1.55 WHIRLWIND   golden crescents rise out of the crater and whirl round the spot, lightning jumping from them
	                   to the cracks; tighter, taller and faster; 2.85 three slashes cross the picture
	  3.6  BURST       a crescent slash cuts it open and she bursts out, spinning to a stop, lit white, wings snapping
	                   open, a crown halo; star flares, feathers, a ring of light
	  4.4  SETTLE      she settles from her hover to the ground
	  4.9  NAME        DIVINE and 8 stars in gold with a shine sweeping over, her name; the camera circles in to her face
	  7.6  ASCENSION   the wings beat once; 8.1 a small burst
	  8.2  RISE        she rises to her place over the map in a spiral of gold, the wings fade into sparkles, the night
	                   lifts; 9.7 she twinkles like the star she came as; 10.4 a soft golden fade hands the camera back
	Flashes (kid-safe, at most one a second): the impact frame at 1.4, the burst at 3.6, a small swell at 8.1, the warm
	fade at 10.4. Reduced Motion: the same shot without shake, kicks, swells or the impact frame.
]]
local DivineReveal = {}

DivineReveal.LENGTH = 11.0
DivineReveal.STAR = 0.15 -- the star twinkles on high
DivineReveal.FALL = 0.55 -- it falls (over FALL_TIME s)
DivineReveal.FALL_TIME = 0.85
DivineReveal.CRASH = 1.4 -- it hits the spot
DivineReveal.CRACK_TIME = 0.35 -- the cracks race out
DivineReveal.VORTEX = 1.55 -- the whirlwind rises out of the crater
DivineReveal.SLASHES = { 2.85, 3.0, 3.15 } -- gold slashes across the picture as it winds up
DivineReveal.BURST = 3.6 -- it bursts open and she is there
DivineReveal.APPEAR = DivineReveal.BURST
DivineReveal.WINGS = DivineReveal.BURST
DivineReveal.SWINGS = { 3.6, 3.74, 3.88 } -- the crescent slashes round her as it bursts
DivineReveal.TOUCH = 4.4 -- she settles on the ground
DivineReveal.NAME = 4.9
DivineReveal.NAME_OUT = 7.3
DivineReveal.ASCEND = 7.6 -- the wings beat once
DivineReveal.SWELL = 8.1 -- a small burst
DivineReveal.RISE = 8.2
DivineReveal.TWINKLE = 9.7 -- she twinkles over the map
DivineReveal.CLOSE = 8.6 -- the night starts to lift (the day is back by CLOSE + BACK)
DivineReveal.BACK = 1.6
DivineReveal.RETURN = 10.4
DivineReveal.DIP = Color3.fromRGB(255, 240, 205) -- the hand-back fades through warm cream, not black
DivineReveal.DIP_DOWN = 0.3
DivineReveal.FRAME = 0.12 -- the impact frame (seconds on screen)
DivineReveal.NIGHT = 0 -- midnight

-- Sizes in studs, before scaling with her (x Config/Round.Showcase.Scale / 3).
DivineReveal.APPEAR_HEIGHT = 3 -- her feet over the floor as she bursts out (she settles from there)
DivineReveal.STAR_FROM = { 20, 62, 30 } -- where the star falls from: studs to the right, up, and behind the spot (seen from the camera)
DivineReveal.CROWN_RADIUS = 1.9

-- The cracks of light: how many, and each one's segments (studs) and how far its turns wander (degrees).
DivineReveal.CRACKS = 9
DivineReveal.CRACK_SEGMENTS = { 3.2, 3.6, 3.4, 3, 2.6 }
DivineReveal.CRACK_WANDER = 28

-- The whirlwind: how many crescents, each one's arc (degrees); its radius (studs) as it rises and when it's tight.
DivineReveal.ARCS = 12
DivineReveal.ARC_SPAN = 120
DivineReveal.VORTEX_WIDE = 9
DivineReveal.VORTEX_TIGHT = 3.4

-- Her wings: one entry per feather from her shoulder to the wing tip (HuzzClient/Gameplay/DivineReveal lays them
-- along the wing's leading edge); its width (studs). (ang and len: the old fan layout, kept for reference.)
DivineReveal.FEATHERS = {
	{ ang = 18, len = 0.95, w = 1.2 }, { ang = 33, len = 1.25, w = 1.4 }, { ang = 48, len = 1.45, w = 1.5 },
	{ ang = 63, len = 1.5, w = 1.5 }, { ang = 78, len = 1.4, w = 1.4 }, { ang = 94, len = 1.22, w = 1.3 },
	{ ang = 110, len = 1.0, w = 1.15 }, { ang = 126, len = 0.75, w = 1.0 },
}
DivineReveal.FOLDED = 8 -- every feather's angle when folded

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function easeOut(x: number): number
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
DivineReveal.smooth = smooth
DivineReveal.easeOut = easeOut

-- A quick-in, slow-out envelope (0..1): `rise` seconds up from `at`, then down over `fall` seconds (both eased).
local function pop(t: number, at: number, rise: number, fall: number): number
	local x = t - at
	if x < 0 or x > rise + fall then return 0 end
	if x < rise then return smooth(x / rise) end
	return 1 - smooth((x - rise) / fall)
end
DivineReveal.pop = pop

-- How much of the night look is on (0..1): a quick fall to dark on the opening cut (never a flash), lifting from CLOSE.
function DivineReveal.heaven(t: number): number
	if t < 0 then return 0 end
	if t < DivineReveal.CLOSE then return smooth(t / 0.15) end
	return 1 - smooth((t - DivineReveal.CLOSE) / DivineReveal.BACK)
end
DivineReveal.dusk = DivineReveal.heaven

-- The time of day on your screen: midnight, back to the game's own `day` from CLOSE through a short dawn (as
-- Shared/SecretReveal.clock: spread out, so it never reads as a flash).
function DivineReveal.clock(t: number, day: number): number
	local back = DivineReveal.CLOSE + DivineReveal.BACK
	if t < 0 or t >= back then return day end
	if t < DivineReveal.CLOSE then return DivineReveal.NIGHT end
	local x = (t - DivineReveal.CLOSE) / DivineReveal.BACK
	local target = if day < 7.2 then day + 24 else day
	if x < 0.08 then return DivineReveal.NIGHT + (5.2 - DivineReveal.NIGHT) * smooth(x / 0.08) end
	if x < 0.62 then return 5.2 + 2 * (x - 0.08) / 0.54 end
	return (7.2 + (target - 7.2) * smooth((x - 0.62) / 0.38)) % 24
end

-- The falling star: how far along its fall (0..1, speeding up all the way), how bright (0..1: it twinkles in from
-- STAR, gone at CRASH) and how long its tail is (0..1).
function DivineReveal.star(t: number): (number, number, number)
	if t < DivineReveal.STAR or t >= DivineReveal.CRASH then return 0, 0, 0 end
	local s = clamp01((t - DivineReveal.FALL) / DivineReveal.FALL_TIME) ^ 2.2
	return s, smooth((t - DivineReveal.STAR) / 0.3), smooth((t - DivineReveal.FALL) / 0.3)
end

-- The cracks of light: how far they have run out (0..1) and how bright (0..1: flaring with the crash, breathing with
-- the whirlwind, flaring again with the burst, gone as she rises).
function DivineReveal.cracks(t: number): (number, number)
	if t < DivineReveal.CRASH then return 0, 0 end
	local grow = easeOut((t - DivineReveal.CRASH) / DivineReveal.CRACK_TIME)
	local glow = 0.6 + 0.4 * pop(t, DivineReveal.CRASH, 0.03, 0.5) + 0.3 * pop(t, DivineReveal.BURST, 0.03, 0.5)
	glow += 0.15 * smooth((t - DivineReveal.VORTEX) / (DivineReveal.BURST - DivineReveal.VORTEX)) * (1 - smooth((t - DivineReveal.BURST) / 0.4))
	return grow, math.min(1, glow) * (1 - smooth((t - DivineReveal.RISE) / 0.8))
end

-- The whirlwind: how tall (0..1 of its full height), its radius (studs, before scaling), how far round it has spun
-- (radians: it winds faster and faster up to the burst), how strong (0..1) and how far it has flown apart (0..1, after
-- the burst). After RISE the same crescents spiral up round her as she ascends (`spiral` 0..1).
function DivineReveal.vortex(t: number): (number, number, number, number, number, number)
	local tall = easeOut((t - DivineReveal.VORTEX) / 0.9)
	local tight = smooth((t - DivineReveal.VORTEX) / (DivineReveal.BURST - DivineReveal.VORTEX))
	local radius = DivineReveal.VORTEX_WIDE + (DivineReveal.VORTEX_TIGHT - DivineReveal.VORTEX_WIDE) * tight
	local function speed(x: number): number
		if x < DivineReveal.BURST then return 3 + 9 * smooth((x - DivineReveal.VORTEX) / (DivineReveal.BURST - DivineReveal.VORTEX)) end
		if x < DivineReveal.RISE - 0.3 then return 4 end
		return 7
	end
	local turn, x = 0, DivineReveal.VORTEX
	while x < t do
		local dx = math.min(0.05, t - x)
		turn += speed(x + dx / 2) * dx
		x += dx
	end
	local out = easeOut((t - DivineReveal.BURST) / 0.45)
	local alpha = smooth((t - DivineReveal.VORTEX) / 0.3) * (1 - smooth((t - DivineReveal.BURST) / 0.4))
	local spiral = smooth((t - DivineReveal.RISE + 0.2) / 0.4) * (1 - smooth((t - DivineReveal.RETURN + 0.7) / 0.6))
	return tall, radius, turn, alpha, out, spiral
end

-- The lightning jumping from the whirlwind to the cracks (on or off).
function DivineReveal.bolts(t: number): boolean
	return t >= DivineReveal.VORTEX + 0.35 and t < DivineReveal.BURST
end

-- The impact frame (black ink claws on white paper) as the star hits. Reduced Motion: none.
function DivineReveal.impactFrame(t: number, calm: boolean): boolean
	return not calm and t >= DivineReveal.CRASH and t < DivineReveal.CRASH + DivineReveal.FRAME
end

-- One slash, a crescent swing or a star flare (0..1): snaps on, then thins out.
function DivineReveal.slash(t: number, at: number): number
	return pop(t, at, 0.04, 0.36)
end
function DivineReveal.swing(t: number, at: number): number
	return pop(t, at, 0.05, 0.35)
end

-- Her height over the floor (studs, before scaling), or nil before she bursts out. She settles from her hover to the
-- ground, then rises to `top` (Config/Round Showcase.Height).
function DivineReveal.height(t: number, top: number): number?
	if t < DivineReveal.APPEAR then return nil end
	if t < DivineReveal.TOUCH then
		return DivineReveal.APPEAR_HEIGHT * (1 - smooth((t - DivineReveal.APPEAR) / (DivineReveal.TOUCH - DivineReveal.APPEAR)))
	end
	if t < DivineReveal.RISE then return 0 end
	return top * smooth((t - DivineReveal.RISE) / (DivineReveal.RETURN - DivineReveal.RISE))
end

-- How much she is lit white (0..1): fully as she bursts out, settling to a gold rim.
function DivineReveal.glow(t: number): number
	if t < DivineReveal.APPEAR then return 0 end
	return 1 - smooth((t - DivineReveal.APPEAR - 0.1) / 0.9)
end

-- Her wings: how open (0..1, snapping open with a little overshoot as she bursts out; one beat at ASCEND) and how
-- visible (0..1, gone into sparkles as she rises).
function DivineReveal.wings(t: number): (number, number)
	if t < DivineReveal.WINGS then return 0, 0 end
	local x = (t - DivineReveal.WINGS) / 0.45
	local open = easeOut(x) + 0.08 * math.sin(math.clamp(x, 0, 2) * math.pi) * (1 - clamp01(x - 1))
	open -= 0.42 * pop(t, DivineReveal.ASCEND, 0.18, 0.32)
	local seen = smooth((t - DivineReveal.WINGS) / 0.12) * (1 - smooth((t - DivineReveal.RISE - 0.5) / 0.8))
	return math.max(open, 0), seen
end

-- Her name card (0..1) and the shine over it (-1..2: crosses twice).
function DivineReveal.name(t: number): number
	if t < DivineReveal.NAME or t > DivineReveal.NAME_OUT then return 0 end
	return math.min(easeOut((t - DivineReveal.NAME) / 0.35), smooth((DivineReveal.NAME_OUT - t) / 0.35))
end
function DivineReveal.shine(t: number): number
	local x = t - DivineReveal.NAME - 0.35
	if x < 0 then return -1 end
	if x < 0.9 then return -1 + 2.4 * smooth(x / 0.9) end
	x -= 1.1
	if x < 0 then return 2 end
	return if x < 0.9 then -1 + 2.4 * smooth(x / 0.9) else 2
end

-- The brightness swells (0..1): the crash, the burst and the small one at SWELL. Never two within a second.
function DivineReveal.pulse(t: number): number
	return math.max(0.6 * pop(t, DivineReveal.CRASH, 0.05, 0.5), 0.5 * pop(t, DivineReveal.BURST, 0.05, 0.6), 0.3 * pop(t, DivineReveal.SWELL, 0.06, 0.6))
end

-- The world's grade: brightness, saturation, tint amount (0..1, towards cool moonlight, so the gold stands out), the
-- pulse (0..1) and contrast (hard, as the reference).
function DivineReveal.grade(t: number): (number, number, number, number, number)
	local on = DivineReveal.heaven(t)
	return -0.05 * on, 0.15 * on, 0.5 * on, DivineReveal.pulse(t), 0.28 * on
end

-- The camera: ONE smooth move with no cut. It starts low, looking up at the star, tilts down with its fall, pulls in
-- as the whirlwind winds up, takes her as she bursts out and keeps circling her the same way (the angle only ever
-- grows), in to her face for her name, then cranes up after her. Each key: time, angle round her (degrees from your
-- side), flat distance (studs x k), eye height (studs x k over the floor), look height (studs x k), follow (0 = the
-- look height is over the floor, 1 = over her middle), field of view.
--   t      ang   dist  eye   look  fol  fov
DivineReveal.CUTS = {}
DivineReveal.KEYS = {
	{
		{ 0.0, -40, 52, 3, 26, 0, 72 }, -- low and wide, looking up into the night: a star twinkles
		{ 0.6, -37, 50, 3, 27, 0, 72 }, -- it starts to fall
		{ 1.2, -31, 46, 4, 8, 0, 70 }, -- tilting down with it
		{ 1.45, -28, 44, 5, 4, 0, 72 }, -- the crash
		{ 2.3, -19, 36, 6, 8, 0, 66 }, -- the whirlwind rising out of the crater
		{ 3.2, -8, 27, 7, 9, 0, 60 }, -- pulling in as it winds tighter
		{ 3.6, -2, 25, 6, 0.6, 1, 62 }, -- it bursts: her
		{ 4.4, 12, 25, 5, 1, 1, 60 }, -- she settles
		{ 5.6, 34, 22, 7, 2.8, 1, 50 }, -- circling her while her name holds
		{ 7.2, 60, 12, 12, 4.6, 1, 40 }, -- pushed in to her face (the reference's close-up)
		{ 8.2, 76, 27, 4, 4, 1, 58 }, -- back and low as the wings beat: she will rise above
		{ 9.4, 90, 40, 17, 0, 1, 64 }, -- craning up after her
		{ 10.4, 100, 44, 30, 0, 1, 60 }, -- up with her over the map
		{ 11.0, 104, 45, 31, 0, 1, 60 }, -- (still drifting under the fade)
	},
}

-- A smooth curve through one column of the keys at time t: cubic Hermite with Fritsch-Butland slopes (never
-- overshoots a key; as Shared/SecretReveal).
local function curve(keys: { { number } }, col: number, t: number): number
	local n = #keys
	if t <= keys[1][1] then return keys[1][col] end
	if t >= keys[n][1] then return keys[n][col] end
	local i = 1
	while keys[i + 1][1] <= t do i += 1 end
	local function delta(j: number): number
		return (keys[j + 1][col] - keys[j][col]) / (keys[j + 1][1] - keys[j][1])
	end
	local function slope(j: number): number
		if j == 1 then return delta(1) end
		if j == n then return delta(n - 1) end
		local d0, d1 = delta(j - 1), delta(j)
		if d0 * d1 <= 0 then return 0 end
		local h0, h1 = keys[j][1] - keys[j - 1][1], keys[j + 1][1] - keys[j][1]
		return 3 * (h0 + h1) / ((2 * h1 + h0) / d0 + (h1 + 2 * h0) / d1)
	end
	local h = keys[i + 1][1] - keys[i][1]
	local s = (t - keys[i][1]) / h
	local s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * keys[i][col] + (s3 - 2 * s2 + s) * h * slope(i)
		+ (-2 * s3 + 3 * s2) * keys[i + 1][col] + (s3 - s2) * h * slope(i + 1)
end
DivineReveal.curve = curve

-- The camera's angle round her at time t (degrees): she turns part of the way with it after the touchdown (facing).
function DivineReveal.angle(t: number): number
	return curve(DivineReveal.KEYS[1], 2, t)
end

-- Which way she faces, in radians round from facing you: she bursts out of the whirlwind spinning, one full turn
-- slowing to a stop facing you; after she settles she turns half of the camera's circling, so you always see her face.
function DivineReveal.facing(t: number): number
	local turn = 2 * math.pi * (1 - easeOut((t - DivineReveal.APPEAR) / 0.9))
	-- (turning by -a about her up axis faces her towards a camera at angle a: Shared/DivineReveal.camera)
	local follow = 0.5 * smooth((t - DivineReveal.TOUCH) / 0.8)
	return turn - follow * math.rad(DivineReveal.angle(t))
end

local function kick(t: number, at: number, rise: number, fall: number): number
	return pop(t, at, rise, fall)
end

-- The field of view: from the keys, with widening kicks on the crash, the burst and the small swell.
function DivineReveal.fov(t: number, calm: boolean): number
	local base = curve(DivineReveal.KEYS[1], 7, t)
	if not calm then
		base += 6 * kick(t, DivineReveal.CRASH, 0.15, 0.8) + 5 * kick(t, DivineReveal.BURST, 0.15, 0.8) + 3 * kick(t, DivineReveal.SWELL, 0.25, 0.8)
	end
	return base
end

-- How hard the camera shakes: a hum as the whirlwind winds up, the crash, the burst, settling and the wing beat.
function DivineReveal.shake(t: number): number
	local s = 0
	if t >= DivineReveal.VORTEX and t < DivineReveal.BURST + 0.3 then
		s += 0.08 * smooth((t - DivineReveal.VORTEX) / (DivineReveal.BURST - DivineReveal.VORTEX)) * (1 - smooth((t - DivineReveal.BURST) / 0.3))
	end
	s += 0.32 * pop(t, DivineReveal.CRASH, 0.04, 0.8) + 0.24 * pop(t, DivineReveal.BURST, 0.04, 0.7) + 0.06 * pop(t, DivineReveal.TOUCH, 0.05, 0.4)
	s += 0.1 * pop(t, DivineReveal.ASCEND + 0.15, 0.05, 0.4) + 0.1 * pop(t, DivineReveal.SWELL, 0.05, 0.6)
	return s
end

DivineReveal.SHAKE_HZ = 3.5
function DivineReveal.shakeAt(t: number, seed: number): (number, number, number, number, number)
	local s = DivineReveal.shake(t)
	if s <= 0 then return 0, 0, 0, 0, 0 end
	local n = t * DivineReveal.SHAKE_HZ
	return math.noise(n, seed) * s * 0.06, math.noise(seed, n) * s * 0.06, math.noise(n, n + seed) * s * 0.025,
		math.noise(n + 3.7, seed) * s * 0.5, math.noise(seed, n + 3.7) * s * 0.5
end

-- The camera: eye and look-at, relative to the landing spot `at`, looking from `dir` (a flat unit Vector3 towards the
-- viewer), with her height `h` (unscaled studs; before she appears, the height she will appear at), her scale `k` and
-- half height `mid` (studs).
function DivineReveal.camera(t: number, at: Vector3, dir: Vector3, h: number, k: number, mid: number?): (Vector3, Vector3)
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up)
	local m = mid or 7.5 * k
	local keys = DivineReveal.KEYS[1]
	local a = math.rad(curve(keys, 2, t))
	local eye = at + (dir * math.cos(a) + side * math.sin(a)) * curve(keys, 3, t) * k + up * curve(keys, 4, t) * k
	local follow = clamp01(curve(keys, 6, t))
	local herMid = (if t < DivineReveal.APPEAR then DivineReveal.APPEAR_HEIGHT else h) * k + m
	local look = at + up * (curve(keys, 5, t) * k + follow * herMid)
	return eye, look
end

-- Framing on every map: the same plan as the Secret one (Shared/SecretReveal "Framing on every map"), on this
-- timeline (no cut, so one shot).
DivineReveal.DIRECTIONS = 16
DivineReveal.SAMPLE_STEP = 0.2
DivineReveal.COARSE_STEP = 0.8
DivineReveal.FINALISTS = 2
DivineReveal.MAX_FOV = 90
DivineReveal.RATE = 0.5

function DivineReveal.sampleTimes(step: number?): { number }
	local every = step or DivineReveal.SAMPLE_STEP
	local out = {}
	for i = 0, math.floor(DivineReveal.LENGTH / every + 0.5) do
		table.insert(out, i * every)
	end
	return out
end

function DivineReveal.directions(): { Vector3 }
	local out = {}
	for i = 0, DivineReveal.DIRECTIONS - 1 do
		local a = 2 * math.pi * i / DivineReveal.DIRECTIONS
		table.insert(out, Vector3.new(math.sin(a), 0, math.cos(a)))
	end
	return out
end

function DivineReveal.score(reaches: { number }, dir: Vector3, prefer: Vector3?): number
	local sum, low = 0, 1
	for _, r in reaches do
		sum += r
		low = math.min(low, r)
	end
	local mean = if #reaches > 0 then sum / #reaches else 1
	local toward = if prefer then (dir:Dot(prefer) + 1) / 2 else 0
	return 0.6 * mean + 0.4 * low + 0.06 * toward
end

function DivineReveal.finalists(dirs: { Vector3 }, reaches: { { number } }, prefer: Vector3?): { number }
	local order = {}
	for i in dirs do
		table.insert(order, i)
	end
	table.sort(order, function(a, b)
		return DivineReveal.score(reaches[a], dirs[a], prefer) > DivineReveal.score(reaches[b], dirs[b], prefer)
	end)
	return { table.unpack(order, 1, math.min(DivineReveal.FINALISTS, #order)) }
end

function DivineReveal.pickDirection(dirs: { Vector3 }, reaches: { { number } }, prefer: Vector3?): number
	local best, bestScore = 1, -math.huge
	for i, d in dirs do
		local s = DivineReveal.score(reaches[i], d, prefer)
		if s > bestScore + 1e-9 then
			best, bestScore = i, s
		end
	end
	return best
end

-- The reach to use at each sample: never more than what is clear there or either side, eased in ahead of time and
-- out slowly at RATE of the distance a second (one shot: no cut).
function DivineReveal.planReach(times: { number }, reaches: { number }): { number }
	local n = #times
	local out = {}
	for i = 1, n do
		local low = reaches[i]
		for j = math.max(1, i - 1), math.min(n, i + 1) do
			low = math.min(low, reaches[j])
		end
		out[i] = math.clamp(low, 0.05, 1)
	end
	for i = n - 1, 1, -1 do
		out[i] = math.min(out[i], out[i + 1] + DivineReveal.RATE * (times[i + 1] - times[i]))
	end
	for i = 2, n do
		out[i] = math.min(out[i], out[i - 1] + DivineReveal.RATE * (times[i] - times[i - 1]))
	end
	return out
end

function DivineReveal.reachAt(times: { number }, plan: { number }, t: number): number
	local n = #times
	if n == 0 then return 1 end
	if t <= times[1] then return plan[1] end
	if t >= times[n] then return plan[n] end
	local i = 1
	while times[i + 1] < t do i += 1 end
	return plan[i] + (plan[i + 1] - plan[i]) * smooth((t - times[i]) / (times[i + 1] - times[i]))
end

function DivineReveal.wideFov(fov: number, reach: number): number
	if reach >= 0.999 then return fov end
	local half = math.atan(math.tan(math.rad(fov) / 2) / math.max(reach, 0.05))
	return math.min(math.deg(half) * 2, math.max(fov, DivineReveal.MAX_FOV))
end

return DivineReveal
