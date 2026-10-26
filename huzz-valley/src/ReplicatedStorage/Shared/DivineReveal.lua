--[[
	The Divine girl's arrival (owner, Oct 26: "for the divine, can you please make an animation that isnt the same as a
	secret, and make it even more crazy ... make it completely different from the secret animation, check other games
	animations for the divine ones ... make this way smoother and more fitting and better looking than the secret
	animation"). "Heaven's Gate": where the Secret one is a violet night of beams striking and converging into a burst,
	this one is golden daylight: the sky opens, a halo gate comes down, she floats down a pillar of light, light wings
	open, one slow orbit round her, and she ascends to her place. Ideas taken from other games' top-rarity reveals:
	god rays through a hole in the clouds (Pet Simulator 99's Titanic hatch), a sigil drawing itself on the ground and
	the rarity title over everything (Sol's RNG's global cutscenes), a descent with wings and a halo (gacha games'
	top-tier pulls). Smoother than the Secret one by design: ONE camera move with no cut, every motion eased, and the
	big moments flow into each other (the halo she comes through becomes her crown).
	Pure numbers (no Roblox instances), as Shared/SecretReveal: HuzzClient/Gameplay/DivineReveal builds the effects
	and tools/preview/motion3d/divine_scene.luau films the same.
	  0.0  HUSH        warm golden light on your screen, gold motes rise; the camera low, looking up at the sky
	  0.3  SKY OPENS   a ring of cloud parts high over the spot, a disc of heaven's light grows in it
	  0.9  GOD RAYS    seven soft wide rays fan down out of it, sweeping slowly over the ground
	  1.2  HALO GATE   three golden rings with gems, tilted, turning against each other, come down out of the light
	  2.0  SIGIL       a golden circle draws itself round on the ground (rings, spokes, rune marks)
	  2.7  SPIN UP     the halo turns faster and faster; flakes of light start drifting down
	  3.1  PILLAR      one huge pillar of light falls through the halo to the ground: a shockwave, the first soft swell
	  3.5  DESCENT     she appears in the halo, lit white, and floats slowly down the pillar, turning round to you
	  4.7  WINGS       wings of light unfold behind her, a gust ring, a burst of light
	  5.2  TOUCHDOWN   she lands softly: three golden ripples; the halo has shrunk into a crown halo over her head
	  5.5  NAME        DIVINE and 8 stars in gold with a shine sweeping over, her name; the camera circles her slowly
	  7.7  ASCENSION   the wings beat once; 8.2 the second soft swell and a burst of light
	  8.3  RISE        she rises to her place over the map, the wings fade into sparkles, the sky closes, the colours
	                   come back; 10.4 a soft golden fade hands the camera back to you (not black)
	Flashes (kid-safe, at most one a second): soft swells at 3.1, 5.2 (small) and 8.2 only, and the warm fade at 10.4.
	Reduced Motion: the same shot without shake, kicks or swells.
]]
local DivineReveal = {}

DivineReveal.LENGTH = 11.0
DivineReveal.OPEN = 0.3 -- the clouds start to part
DivineReveal.RAYS = 0.9 -- the god rays fan down (one after another, every RAY_GAP s)
DivineReveal.RAY_GAP = 0.08
DivineReveal.HALO = 1.2 -- the halo gate comes down out of the light
DivineReveal.SIGIL = 2.0 -- the circle draws itself on the ground (over SIGIL_DRAW s)
DivineReveal.SIGIL_DRAW = 0.9
DivineReveal.SPIN = 2.7 -- the halo spins up
DivineReveal.PILLAR = 3.1 -- the pillar of light falls through it
DivineReveal.APPEAR = 3.5 -- she appears in the halo and floats down
DivineReveal.WINGS = 4.7 -- her wings unfold
DivineReveal.TOUCH = 5.2 -- she touches down
DivineReveal.RIPPLES = { 5.2, 5.45, 5.7 }
DivineReveal.NAME = 5.5
DivineReveal.NAME_OUT = 7.6
DivineReveal.ASCEND = 7.7 -- the wings beat once
DivineReveal.SWELL = 8.2 -- the second soft swell, a burst of light
DivineReveal.RISE = 8.3
DivineReveal.CLOSE = 8.6 -- the sky starts to close and the colours come back (by CLOSE + BACK)
DivineReveal.BACK = 1.6
DivineReveal.RETURN = 10.4
DivineReveal.DIP = Color3.fromRGB(255, 240, 205) -- the hand-back fades through warm cream, not black
DivineReveal.DIP_DOWN = 0.3 -- seconds into the fade (gentler than the Secret one's 0.2 to black)

-- Heights in studs over the floor, before scaling with her (x Config/Round.Showcase.Scale / 3).
DivineReveal.SKY = 72 -- the hole in the clouds
DivineReveal.HALO_FROM = 56 -- where the halo gate comes out of the light
DivineReveal.APPEAR_HEIGHT = 20 -- her feet when she appears in the halo
DivineReveal.GATE_RADIUS = 10 -- the halo gate's inner ring (its other two are 1.3x and 1.6x)
DivineReveal.CROWN_RADIUS = 1.9 -- the same ring as her crown halo
DivineReveal.SKY_RADIUS = 30 -- the hole in the clouds when fully open

-- The god rays: the angle round the spot (degrees, 0 = towards you), how far out their feet land (studs), their width
-- at the sky and at the ground (studs).
DivineReveal.RAY_FEET = {
	{ ang = -150, out = 26, w0 = 5, w1 = 13 }, { ang = -95, out = 20, w0 = 6, w1 = 15 }, { ang = -40, out = 24, w0 = 4, w1 = 11 },
	{ ang = 10, out = 18, w0 = 6, w1 = 16 }, { ang = 60, out = 25, w0 = 5, w1 = 12 }, { ang = 115, out = 21, w0 = 6, w1 = 14 },
	{ ang = 170, out = 27, w0 = 4, w1 = 12 },
}

-- The pillar's layers, outside in: width (studs) and how strong.
DivineReveal.PILLAR_LAYERS = {
	-- (first film, Oct 26: wider and stronger washed the whole picture out to cream)
	{ w = 12, alpha = 0.08 }, { w = 7, alpha = 0.14 }, { w = 3.6, alpha = 0.26 }, { w = 1.5, alpha = 0.55 }, { w = 0.5, alpha = 0.9 },
}

-- Her wings: each feather's angle when open (degrees out from straight up: 0 = up, 90 = straight out to her side),
-- its length (x her half height) and width (studs).
DivineReveal.FEATHERS = {
	{ ang = 18, len = 0.95, w = 1.2 }, { ang = 33, len = 1.25, w = 1.4 }, { ang = 48, len = 1.45, w = 1.5 },
	{ ang = 63, len = 1.5, w = 1.5 }, { ang = 78, len = 1.4, w = 1.4 }, { ang = 94, len = 1.22, w = 1.3 },
	{ ang = 110, len = 1.0, w = 1.15 }, { ang = 126, len = 0.75, w = 1.0 },
}
DivineReveal.FOLDED = 8 -- every feather's angle when folded (close together, up behind her)

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

-- How much of the heavenly look is on (0..1): golden light, haze, the stronger bloom and the warm grade.
function DivineReveal.heaven(t: number): number
	if t < 0 then return 0 end
	if t < DivineReveal.CLOSE then return smooth(t / 0.5) end
	return 1 - smooth((t - DivineReveal.CLOSE) / DivineReveal.BACK)
end

-- The time of day on your screen: golden dusk (DUSK) from the first frame (the camera cut hides the switch), the
-- low warm sun making the gold glow against a dimmer world (critic, Oct 26: "no darkness to contrast against"); back
-- to the game's own `day` from CLOSE, eased.
DivineReveal.DUSK = 17.3
function DivineReveal.clock(t: number, day: number): number
	if t < 0 then return day end
	local x = if t < DivineReveal.CLOSE then 1 else 1 - smooth((t - DivineReveal.CLOSE) / DivineReveal.BACK)
	return day + (DivineReveal.DUSK - day) * x
end
function DivineReveal.dusk(t: number): number
	if t < 0 then return 0 end
	return if t < DivineReveal.CLOSE then 1 else 1 - smooth((t - DivineReveal.CLOSE) / DivineReveal.BACK)
end

-- How far the clouds have parted (0..1): opening from OPEN, closing again from CLOSE.
function DivineReveal.skyOpen(t: number): number
	if t < DivineReveal.OPEN then return 0 end
	local open = easeOut((t - DivineReveal.OPEN) / 1.4)
	return open * (1 - smooth((t - DivineReveal.CLOSE) / 1.4))
end

-- One god ray (i from 1): how strong (0..1) and how far its foot has swept (degrees, a slow sway).
function DivineReveal.ray(t: number, i: number): (number, number)
	local at = DivineReveal.RAYS + (i - 1) * DivineReveal.RAY_GAP
	local on = smooth((t - at) / 0.5) * (1 - smooth((t - DivineReveal.CLOSE) / 1.2))
	-- (dimmer while the pillar is the star of the picture, and faint once she is on screen: the camera is in among
	-- them then, and up close they covered the whole picture in cream on the second film)
	on *= 1 - 0.45 * pop(t, DivineReveal.PILLAR, 0.3, 0.6) * (1 - smooth((t - DivineReveal.PILLAR - 0.3) / 0.3))
	on *= 1 - 0.75 * smooth((t - DivineReveal.APPEAR) / 0.8)
	return on, 14 * math.sin(t * 0.55 + i * 1.7) + 6 * t
end

-- The halo gate: its centre's height (studs over the floor, scaled), its inner radius (studs, scaled), how far it
-- turns (radians: it spins up from SPIN to the pillar, then slows), how bright (0..1), and how much it is a crown
-- (0 = the gate of three rings, 1 = one small ring over her head). `k` is her scale, `mid` her half height (studs),
-- `h` her height over the floor (unscaled studs, nil before she appears).
function DivineReveal.halo(t: number, k: number, mid: number, h: number?): (number, number, number, number, number)
	local gate = DivineReveal.APPEAR_HEIGHT * k + mid
	local y = DivineReveal.HALO_FROM * k + (gate - DivineReveal.HALO_FROM * k) * smooth((t - DivineReveal.HALO) / (DivineReveal.APPEAR - DivineReveal.HALO))
	local crown = smooth((t - DivineReveal.APPEAR) / (DivineReveal.TOUCH + 0.3 - DivineReveal.APPEAR))
	local headTop = (h or DivineReveal.APPEAR_HEIGHT) * k + 2 * mid + 1.1 * k
	if t >= DivineReveal.APPEAR then y = gate + (headTop - gate) * crown end
	local r = (DivineReveal.GATE_RADIUS + (DivineReveal.CROWN_RADIUS - DivineReveal.GATE_RADIUS) * crown) * k
	-- the spin: the integral of a speed that rises 0.6 -> 3.2 rad/s from SPIN to PILLAR and falls back to 0.9 by TOUCH
	local function speed(x: number): number
		if x < DivineReveal.SPIN then return 0.6 end
		if x < DivineReveal.PILLAR then return 0.6 + 2.6 * smooth((x - DivineReveal.SPIN) / (DivineReveal.PILLAR - DivineReveal.SPIN)) end
		return 0.9 + 2.3 * (1 - smooth((x - DivineReveal.PILLAR) / (DivineReveal.TOUCH - DivineReveal.PILLAR)))
	end
	local turn, step = 0, 0.05
	local x = DivineReveal.HALO
	while x < t do
		local dx = math.min(step, t - x)
		turn += speed(x + dx / 2) * dx
		x += dx
	end
	local alpha = smooth((t - DivineReveal.HALO) / 0.5) * (1 - smooth((t - DivineReveal.RISE - 0.8) / 0.9))
	return y, r, turn, alpha, crown
end

-- The circle on the ground: how much of it is drawn (0..1, clockwise from the front) and how bright (0..1).
function DivineReveal.sigil(t: number): (number, number)
	local drawn = smooth((t - DivineReveal.SIGIL) / DivineReveal.SIGIL_DRAW)
	local glow = smooth((t - DivineReveal.SIGIL) / 0.3) * (1 - smooth((t - DivineReveal.RISE) / 1.0))
	-- (it flares with the pillar, and breathes softly after: never blinks)
	return drawn, glow * (0.8 + 0.2 * pop(t, DivineReveal.PILLAR, 0.15, 0.8))
end

-- The pillar of light: how strong (0..1) and its width (x its layers' widths). It falls through the halo at PILLAR
-- (the drop takes 0.25 s: `reach` 0..1 from the sky down), narrows once she has landed and comes back softly to lift
-- her at RISE.
function DivineReveal.pillar(t: number): (number, number, number)
	local reach = easeOut((t - DivineReveal.PILLAR) / 0.25)
	local first = smooth((t - DivineReveal.PILLAR) / 0.12) * (1 - smooth((t - DivineReveal.TOUCH - 0.2) / 0.9))
	local lift = smooth((t - DivineReveal.RISE + 0.2) / 0.5) * (1 - smooth((t - DivineReveal.RETURN + 0.9) / 0.8))
	local power = math.max(first, 0.55 * lift)
	local width = if first >= 0.55 * lift then 0.55 + 0.45 * (1 - smooth((t - DivineReveal.TOUCH) / 0.8)) + 0.15 * pop(t, DivineReveal.PILLAR, 0.1, 0.5) else 0.5
	return power, width, reach
end

-- Her wings: how open (0..1, 1 = fully spread; a little overshoot as they snap open, one beat at ASCEND) and how
-- visible (0..1, gone into sparkles as she rises).
function DivineReveal.wings(t: number): (number, number)
	if t < DivineReveal.WINGS then return 0, 0 end
	local x = (t - DivineReveal.WINGS) / 0.6
	local open = easeOut(x) + 0.07 * math.sin(math.clamp(x, 0, 2) * math.pi) * (1 - clamp01(x - 1))
	open -= 0.42 * pop(t, DivineReveal.ASCEND, 0.18, 0.32) -- (one beat: in, then back out)
	local seen = smooth((t - DivineReveal.WINGS) / 0.25) * (1 - smooth((t - DivineReveal.RISE - 0.5) / 0.8))
	return math.max(open, 0), seen
end

-- Her height over the floor (studs, before scaling), or nil before she appears. She appears already drifting down
-- (never hanging still), slows the whole way and touches down softly; then rises to `top` (Config/Round
-- Showcase.Height).
function DivineReveal.height(t: number, top: number): number?
	if t < DivineReveal.APPEAR then return nil end
	if t < DivineReveal.TOUCH then
		local s = (t - DivineReveal.APPEAR) / (DivineReveal.TOUCH - DivineReveal.APPEAR)
		return DivineReveal.APPEAR_HEIGHT * (1 - s) ^ 2 * (1 + 0.6 * s)
	end
	if t < DivineReveal.RISE then return 0 end
	return top * smooth((t - DivineReveal.RISE) / (DivineReveal.RETURN - DivineReveal.RISE))
end

-- How much she is lit white (0..1): fully as she appears, settling to a warm golden rim by the touchdown.
function DivineReveal.glow(t: number): number
	if t < DivineReveal.APPEAR then return 0 end
	return 1 - smooth((t - DivineReveal.APPEAR - 0.1) / 0.9)
end

-- Her name card (0..1): rises in over 0.35 s at NAME, fades by NAME_OUT. `shine` (-1..2): where the sweep of light
-- over the title is (it crosses twice).
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

-- The soft brightness swells (0..1): the pillar, the touchdown (small) and the ascension. Never two within a second.
function DivineReveal.pulse(t: number): number
	return math.max(pop(t, DivineReveal.PILLAR, 0.08, 0.6), 0.35 * pop(t, DivineReveal.TOUCH, 0.1, 0.5), 0.7 * pop(t, DivineReveal.SWELL, 0.15, 0.6))
end

-- The world's grade: brightness, saturation, tint amount (0..1, towards warm gold), the pulse (0..1) and contrast.
-- Brighter and warmer, never dark (the Secret one goes to night).
function DivineReveal.grade(t: number): (number, number, number, number, number)
	local on = DivineReveal.heaven(t)
	return -0.04 * on, 0.05 * on, 0.8 * on, DivineReveal.pulse(t), 0.14 * on
end

-- The camera: ONE smooth move with no cut (smoother than the Secret one's cut: owner, Oct 26). It starts low,
-- looking up at the sky opening, tilts down with the halo, rides her descent, and keeps circling her the same way
-- the whole time (the angle only ever grows: no stop and turn back), in to her face for her name, then cranes up
-- after her as she ascends. Each key: time, angle round her (degrees from your side, + = to her left on screen),
-- flat distance (studs x k), eye height (studs x k over the floor), look height (studs x k), follow (0 = the look
-- height is over the floor, 1 = over her middle), field of view.
--   t      ang   dist  eye   look  fol  fov
DivineReveal.CUTS = {}
DivineReveal.KEYS = {
	{
		{ 0.0, -40, 50, 2.5, 26, 0, 74 }, -- low and wide, looking up at the sky over the spot: the warm light comes in
		{ 0.9, -34, 47, 3, 31, 0, 73 }, -- the sky opens, the rays fan down
		{ 1.7, -28, 45, 5, 30, 0, 70 }, -- the halo gate comes down out of the light
		{ 2.5, -22, 45, 10, 18, 0, 68 }, -- tilting down with it: the circle draws itself on the ground
		{ 3.1, -16, 47, 9, 24, 0, 72 }, -- wide for the pillar falling through the halo
		{ 3.5, -12, 39, 13, 2, 1, 64 }, -- she appears in the halo: the look takes her up and rides her down
		{ 4.2, -4, 33, 11, 1, 1, 60 }, -- floating down, turning round to you
		{ 4.9, 6, 31, 8, 1.5, 1, 63 }, -- her wings unfold (wide enough for both)
		{ 5.3, 14, 28, 4, 1.5, 1, 60 }, -- touchdown, low
		{ 6.4, 40, 24, 5, 2.5, 1, 52 }, -- circling her while her name holds
		{ 7.6, 66, 21, 7, 3.6, 1, 49 }, -- in to her face
		{ 8.3, 78, 27, 4, 4, 1, 58 }, -- back and low as the wings beat: she will rise above
		{ 9.4, 90, 40, 17, 0, 1, 64 }, -- craning up after her
		{ 10.4, 100, 44, 30, 0, 1, 60 }, -- up with her over the map (close enough that she still fills the picture)
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

-- Which way she faces, in radians round from facing you: her back to you as she appears, turning round to you on the
-- way down; after the touchdown she turns half of the camera's circling, so you always see her from the front.
function DivineReveal.facing(t: number): number
	local turn = math.pi * (1 - smooth((t - DivineReveal.APPEAR) / (DivineReveal.WINGS + 0.25 - DivineReveal.APPEAR)))
	-- (turning by -a about her up axis faces her towards a camera at angle a: Shared/DivineReveal.camera)
	local follow = 0.5 * smooth((t - DivineReveal.TOUCH) / 0.8)
	return turn - follow * math.rad(DivineReveal.angle(t))
end

local function kick(t: number, at: number, rise: number, fall: number): number
	return pop(t, at, rise, fall)
end

-- The field of view: from the keys, with soft widening kicks on the pillar and the ascension.
function DivineReveal.fov(t: number, calm: boolean): number
	local base = curve(DivineReveal.KEYS[1], 7, t)
	if not calm then
		base += 6 * kick(t, DivineReveal.PILLAR, 0.2, 0.8) + 4 * kick(t, DivineReveal.SWELL, 0.25, 0.8)
	end
	return base
end

-- How hard the camera shakes: much softer than the Secret one (heavenly, not violent): a hum as the halo spins up,
-- the pillar's hit, the touchdown and the wing beat.
function DivineReveal.shake(t: number): number
	local s = 0
	if t >= DivineReveal.SPIN and t < DivineReveal.PILLAR + 0.4 then
		s += 0.06 * smooth((t - DivineReveal.SPIN) / 0.4) * (1 - smooth((t - DivineReveal.PILLAR) / 0.4))
	end
	s += 0.28 * pop(t, DivineReveal.PILLAR, 0.05, 0.8) + 0.12 * pop(t, DivineReveal.TOUCH, 0.05, 0.4)
	s += 0.1 * pop(t, DivineReveal.ASCEND + 0.15, 0.05, 0.4) + 0.14 * pop(t, DivineReveal.SWELL, 0.05, 0.6)
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
