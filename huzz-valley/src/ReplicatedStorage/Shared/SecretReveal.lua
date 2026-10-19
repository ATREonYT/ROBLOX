--[[
	The Secret girl's arrival (owner: "crazy vfx for when a secret girl is chosen: a cutscene plays, its all crazy and
	then she ends up landing inside the map, and she then floats up above it and then the players go into the
	game"; Oct 17: "make the cutscene look one to one as the reference"; Oct 19: "work on the secret animation a bit
	more, make it more detailed, especially the beams, and then the animation, make the duration of it logical").
	The timing, the beams' layout, the shots and the camera as plain numbers (pure: no Roblox instances), so the game
	(HuzzClient/Gameplay/SecretReveal builds the effects) and the offline film (tools/preview/motion3d/secret_scene.luau)
	show the same. Beat sheet with every time and why it is 10 s: docs/secret-beats.md.
	  0.0  ANTICIPATION  night falls on your screen, motes and crystals drift; 0.25 a small orb of light, sparks rush
	                     in; 0.45 a little starburst on it; 0.55-0.8 three hair-thin light threads fall (few)
	  0.95 BUILD         beam A strikes (layered: haze, glow, core, a crackling white filament, two strands winding
	                     round it, pulses climbing it, sparks shedding off); 1.3 red-pink slashes; 1.35 ladder rungs
	                     climb beam A; 1.7 beam B (twin beams); 2.1-2.5 six more beams strike in a ring (many);
	                     2.5 two big glowing eyes open between the twins
	  2.85 CONVERGE      every beam swings its foot into the point between the eyes, pinching thin, winding faster
	  3.3  hit-stop
	  3.42 BURST         a split-second manga frame, a shockwave (a dome, a ring on the ground, a ring facing you),
	                     light rays, sparkles; she appears in white, drops and lands (3.8): a ring, dust, a magic
	                     circle lights up under her
	  3.9  REVEAL HOLD   low and wide on her, crescents swirl round her; 4.5 her NAME (SECRET and 7 stars over it)
	                     with a star flare behind her, held to 6.3; 5.1 speed streaks while the camera pushes into her
	                     face (6.15 an eye glint)
	  6.4  FINALE        the one cut, under a soft bloom swell: wide; red streak lines; 6.55 butterflies; 6.85 a pink
	                     star flare grows on her, crackling; 7.6 the last burst (rays, a ring, a pink cloud)
	  7.75 HAND-BACK     she floats up to her place over the map (she stays there all game), the camera tilting up
	                     after her; 8.3 the sun comes back up; 9.5 a quick dip to black hands the camera back to you
	The camera is one smooth move round the front of her (KEYS, below) with one cut.
	Flashes (kid-safe, at most one a second): soft pulses at 3.42, 6.4 and 7.6 only, measured on the film.
	Reduced Motion: the same shots without shake, kicks, the impact frame, the pulses or the crackle.
]]
local SecretReveal = {}

SecretReveal.LENGTH = 10.0
SecretReveal.BUILD = 0.25 -- the orb appears
SecretReveal.SPARK = 0.45 -- a little starburst on it (the reference's 0.5 s)
SecretReveal.BEAM_A = 0.95 -- the first big beam strikes down
SecretReveal.SLASHES = { 1.3, 1.45, 1.6, 1.75 } -- red-pink slashes, one after another
SecretReveal.LADDER = { 1.35, 2.05 } -- glowing rungs climb beam A
SecretReveal.BEAM_B = 1.7 -- the second big beam: twin beams
SecretReveal.CHOIR = 2.1 -- six more beams strike in a ring, one after another until 2.5
SecretReveal.EYES = 2.5 -- two glowing eyes open between the beams, until the burst
SecretReveal.CONVERGE = 2.85 -- every beam swings its foot into the eyes' point
SecretReveal.HOLD = 3.3 -- the hit-stop
SecretReveal.IMPACT = 3.42 -- the burst: she appears
SecretReveal.FRAME = 0.09 -- the impact frame: a split second of manga lines
SecretReveal.LAND = 3.8
SecretReveal.SWINGS = { 4.0, 4.3, 4.6 } -- crescent slashes swirl round her
SecretReveal.NAME = 4.5 -- her name on screen
SecretReveal.NAME_OUT = 6.3 -- (gone by the cut)
SecretReveal.FLARE = 4.5 -- a star flare behind her as her name comes up
SecretReveal.STREAKS = { 5.1, 6.35 } -- speed streaks rush past
SecretReveal.GLINT = 6.15 -- an eye glint in the close-up
SecretReveal.SWELL = 6.4 -- a soft bloom swell (the cut)
SecretReveal.RED = { 6.45, 6.55, 6.65, 6.75, 6.85 } -- red streak lines sweep across
SecretReveal.SWARM = 6.55 -- butterflies burst out round her
SecretReveal.GROW = { 6.85, 7.6 } -- a pink star flare grows on her, crackling
SecretReveal.BURST = 7.6 -- the last burst
SecretReveal.RISE = 7.75
SecretReveal.RETURN = 9.5
SecretReveal.ORB_HEIGHT = 8 -- studs over the landing spot, scaled with her (Config/Round.Showcase.Scale / 3)
SecretReveal.ORB_MAX = 2.7
SecretReveal.NIGHT = 0 -- midnight
SecretReveal.DAWN = 8.3 -- the night starts to clear
SecretReveal.BACK = 1.2 -- seconds from DAWN for the day (and the colour) to come back (by RETURN)

-- Every beat with its time, for sounds and the beat sheet (docs/secret-beats.md lists the same).
SecretReveal.BEATS = {
	{ 0.0, "night falls (riser starts)" }, { 0.25, "orb appears" }, { 0.45, "starburst on the orb" },
	{ 0.55, "first light thread" }, { 0.95, "beam A strikes" }, { 1.3, "slashes (4, every 0.15 s)" },
	{ 1.35, "ladder rungs climb" }, { 1.7, "beam B strikes" }, { 2.1, "ring of 6 beams (every 0.08 s to 2.5)" },
	{ 2.5, "eyes open" }, { 2.85, "beams converge" }, { 3.3, "hit-stop (silence)" }, { 3.42, "BURST: she appears" },
	{ 3.8, "she lands" }, { 4.0, "crescent swings (4.0, 4.3, 4.6)" }, { 4.5, "her NAME + star flare" },
	{ 5.1, "speed streaks, push to her face" }, { 6.15, "eye glint" }, { 6.4, "cut + swell, red lines" },
	{ 6.55, "butterfly swarm" }, { 6.85, "flare grows, crackling" }, { 7.6, "LAST BURST" }, { 7.75, "she rises" },
	{ 8.3, "sun comes back up" }, { 9.5, "dip to black" }, { 9.7, "camera back to you" }, { 10.0, "end" },
}

-- The beams, in order of their strike: few (three threads), then the twins, then a ring of six (many), then all of
-- them converge. x = studs to her side (+ = right on your screen), z = studs towards you (- = behind her), tall =
-- studs up to where it comes from, w = its widest haze (studs), lean = degrees it leans out, bow = how much it bends,
-- helix = strands winding round it, crackle = a jagged white filament, ladder = rungs climb it, tone = its colours.
-- (studs before scaling with her: x Config/Round.Showcase.Scale / 3)
SecretReveal.PILLARS = {
	{ at = 0.55, x = -7, z = -12, tall = 52, w = 2.2, lean = 4, bow = 0.12, helix = 0, crackle = false, tone = "ice" },
	{ at = 0.68, x = 8, z = -15, tall = 50, w = 1.8, lean = 5, bow = 0.12, helix = 0, crackle = false, tone = "ice" },
	{ at = 0.8, x = 1, z = -24, tall = 56, w = 1.6, lean = 2, bow = 0.1, helix = 0, crackle = false, tone = "ice" },
	{ at = 0.95, x = -10, z = 0, tall = 46, w = 27, lean = 12, bow = 0.3, helix = 2, crackle = true, ladder = true, tone = "violet" },
	{ at = 1.7, x = 10, z = 0, tall = 42, w = 25, lean = 12, bow = 0.3, helix = 2, crackle = true, tone = "violet" },
	{ at = 2.1, x = -21, z = -6, tall = 44, w = 9, lean = 8, bow = 0.2, helix = 1, crackle = false, tone = "magenta" },
	{ at = 2.18, x = 21, z = -8, tall = 42, w = 9, lean = 8, bow = 0.2, helix = 1, crackle = false, tone = "magenta" },
	{ at = 2.26, x = -14, z = -18, tall = 52, w = 7, lean = 5, bow = 0.16, helix = 1, crackle = false, tone = "blue" },
	{ at = 2.34, x = 15, z = -19, tall = 52, w = 7, lean = 5, bow = 0.16, helix = 1, crackle = false, tone = "blue" },
	{ at = 2.42, x = -29, z = -15, tall = 38, w = 6, lean = 10, bow = 0.2, helix = 0, crackle = false, tone = "magenta" },
	{ at = 2.5, x = 29, z = -13, tall = 38, w = 6, lean = 10, bow = 0.2, helix = 0, crackle = false, tone = "magenta" },
}
-- The layers of one beam, outside in: share of its width, how see-through, and which of its tone's colours.
-- Without pictures each is a flat strip; stacked (and adding light) they fall off softly from a white-hot middle.
SecretReveal.LAYERS = {
	{ share = 1, alpha = 0.24, col = 1 }, -- outer haze
	{ share = 0.56, alpha = 0.34, col = 2 }, -- glow (pulses climb it)
	{ share = 0.28, alpha = 0.42, col = 3 }, -- inner glow (pulses climb it)
	{ share = 0.1, alpha = 0.6, col = 4 }, -- core
	{ share = 0.035, alpha = 0.95, col = 5 }, -- white-hot middle
}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function easeIn(x: number): number
	x = clamp01(x)
	return x * x
end
local function easeOut(x: number): number
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
SecretReveal.smooth = smooth

-- A quick-in, slow-out envelope (0..1): `rise` seconds up from `at`, then down over `fall` seconds.
function SecretReveal.pop(t: number, at: number, rise: number, fall: number): number
	local x = t - at
	if x < 0 or x > rise + fall then return 0 end
	if x < rise then return x / rise end
	return 1 - smooth((x - rise) / fall)
end
local pop = SecretReveal.pop

-- The orb's size (studs, 0 = gone; at most ORB_MAX) and how fast the lights circle it (radians per second).
function SecretReveal.orb(t: number): (number, number)
	if t < SecretReveal.BUILD or t >= SecretReveal.IMPACT then return 0, 0 end
	local x = clamp01((t - SecretReveal.BUILD) / (SecretReveal.HOLD - SecretReveal.BUILD))
	return 0.5 + 2.2 * easeIn(x), 2 + 7 * easeIn(x)
end

-- One beam: how far its strike has come down (0..1) and how strong it is (0..1). It strikes from the sky in 0.18 s,
-- holds, and is gone 0.15 s after the burst.
function SecretReveal.beam(t: number, at: number): (number, number)
	if t < at then return 0, 0 end
	local reach = easeOut((t - at) / 0.18)
	local fade = 1 - smooth((t - SecretReveal.IMPACT) / 0.15)
	return reach, math.min(1, (t - at) / 0.08) * fade
end

-- How far the beams have swung into the eyes' point (0..1): from CONVERGE to the hit-stop, slow then fast.
function SecretReveal.converge(t: number): number
	return easeIn((t - SecretReveal.CONVERGE) / (SecretReveal.HOLD - SecretReveal.CONVERGE))
end

-- How many beams are lit at time t (few, then many: checked in check_girl_fx).
function SecretReveal.beamsLit(t: number): number
	local n = 0
	for _, p in SecretReveal.PILLARS do
		local _, power = SecretReveal.beam(t, p.at)
		if power > 0.5 then n += 1 end
	end
	return n
end

-- Where the pulses on a beam are (0..1 from its foot up) at time t: three bright bands climbing it.
function SecretReveal.pulses(t: number, seed: number): { number }
	local speed = 0.9 + 0.8 * SecretReveal.converge(t) -- (faster as they converge)
	local out = {}
	for i = 0, 2 do
		table.insert(out, (t * speed + seed * 0.37 + i / 3) % 1)
	end
	table.sort(out)
	return out
end

-- The ladder rungs on beam A (0..1).
function SecretReveal.ladder(t: number): number
	local a, b = SecretReveal.LADDER[1], SecretReveal.LADDER[2]
	if t < a or t > b then return 0 end
	return math.min(1, (t - a) / 0.1, (b - t) / 0.15)
end

-- Her name card (0..1): pops in over 0.25 s at NAME, fades out over 0.3 s by NAME_OUT.
function SecretReveal.name(t: number): number
	if t < SecretReveal.NAME or t > SecretReveal.NAME_OUT then return 0 end
	return math.min(easeOut((t - SecretReveal.NAME) / 0.25), smooth((SecretReveal.NAME_OUT - t) / 0.3))
end

-- Her height over the landing spot (studs, before scaling), or nil while she isn't there yet.
-- `top` is how high she floats for the game (Config/Round.Showcase.Height).
function SecretReveal.height(t: number, top: number): number?
	if t < SecretReveal.IMPACT then return nil end
	if t < SecretReveal.LAND then -- drops from the burst to the ground
		return SecretReveal.ORB_HEIGHT * (1 - easeIn((t - SecretReveal.IMPACT) / (SecretReveal.LAND - SecretReveal.IMPACT)))
	end
	if t < SecretReveal.RISE then return 0 end
	return top * smooth((t - SecretReveal.RISE) / (SecretReveal.RETURN - SecretReveal.RISE))
end

-- The time of day on your screen (Lighting.ClockTime): night from the first frame (the camera cut hides the switch)
-- until she rises, then the sun comes back up to the game's own time `day`: quickly through the dark hours, then
-- most of the time on the dawn itself (5.2 to 7.2), so the screen brightens evenly (a straight sweep crossed dawn in
-- 0.1 s, a jump like a flash).
function SecretReveal.clock(t: number, day: number): number
	if t < 0 or t >= SecretReveal.DAWN + SecretReveal.BACK then return day end
	if t < SecretReveal.DAWN then return SecretReveal.NIGHT end
	local x = (t - SecretReveal.DAWN) / SecretReveal.BACK
	local target = if day < 7.2 then day + 24 else day
	if x < 0.08 then return SecretReveal.NIGHT + (5.2 - SecretReveal.NIGHT) * smooth(x / 0.08) end
	if x < 0.62 then return 5.2 + 2 * (x - 0.08) / 0.54 end
	return (7.2 + (target - 7.2) * smooth((x - 0.62) / 0.38)) % 24 -- (spread out: the last step into day read as a flash)
end

-- How much of the cutscene's look is on (0..1): the night sky, the purple haze, the stronger bloom and the grade.
function SecretReveal.night(t: number): number
	if t < 0 then return 0 end
	if t < SecretReveal.DAWN then return smooth(t / 0.15) end -- (a quick fall to dark on the opening cut: never a flash)
	return 1 - smooth((t - SecretReveal.DAWN) / SecretReveal.BACK)
end

-- The soft brightness pulses (0..1): the burst, the swell and the last burst. Never two within a second.
function SecretReveal.pulse(t: number): number
	return math.max(pop(t, SecretReveal.IMPACT, 0.05, 0.4), 0.6 * pop(t, SecretReveal.SWELL, 0.12, 0.4), pop(t, SecretReveal.BURST, 0.05, 0.5))
end

-- The world's grade: brightness, saturation, tint amount (0..1), the pulse (0..1) and contrast. At night the world
-- goes dark and grey (the reference's ground is near-black navy, not green); the effects glow through it.
function SecretReveal.grade(t: number): (number, number, number, number, number)
	local dim = SecretReveal.night(t)
	return -0.15 * dim, -0.3 * dim, 0.4 * dim, SecretReveal.pulse(t), 0.06 * dim
end

-- Is the impact frame on screen? (one short hold right at the burst; never with Reduced Motion)
function SecretReveal.impactFrame(t: number, calm: boolean): boolean
	return not calm and t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + SecretReveal.FRAME
end

-- How bright one slash is (0..1): it snaps on, then thins out over a third of a second.
function SecretReveal.slash(t: number, at: number): number
	return pop(t, at, 0.04, 0.36)
end

-- The camera (owner, Oct 18: "a bit chopy still and the camera is still not very logical"): ONE designed move, not
-- a string of hard cuts. Keyframes round her, and the camera glides between them on a smooth curve (no stops, no
-- overshoot: a monotone cubic per number). It always stays in front of her (she faces you), follows what matters
-- (the orb, her drop, her rise) and cuts only once, on purpose, under the bloom swell (CUTS). The story: wide on the
-- spot while the beams build, pushing in as they converge; low and wide as she lands; in to her whole body for her
-- name; into her face; the cut out wide for the finale; tilting up with her rise. Each key: time, angle round her
-- (degrees from your side, + = to her left on screen), flat distance (studs x k), eye height (studs x k) + `ef` x her
-- face height, look point over what the camera follows (studs x k) + `lf` x (face - middle), field of view.
--   t      ang   dist  eye  ef   look  lf   fov
SecretReveal.CUTS = { 6.4 }
SecretReveal.KEYS = {
	{ -- the arrival: wide while the beams build, in as they converge, down with her, then to her name and her face
		{ 0.0, -10, 50, 9, 0, -3, 0, 70 }, -- wide on the spot: night falls, the orb appears
		{ 0.95, -7, 41, 7, 0, 1, 0, 68 }, -- beam A strikes: lower, looking up
		{ 1.7, -4, 38, 6, 0, 2.5, 0, 68 }, -- beam B: twin beams (they fill the picture top to bottom, like the reference)
		{ 2.45, -2, 40, 5.5, 0, 3, 0, 70 }, -- the ring of beams: a touch wider so all of them show
		{ 3.25, 0, 34, 6, 0, 1.5, 0, 61 }, -- pushing in as they converge
		{ 3.42, 1, 33.5, 6.2, 0, 1.2, 0, 60 }, -- the burst: she drops (the look follows her down)
		{ 4.0, 4, 33, 3.5, 0, 1, 0, 63 }, -- settled low and wide after the landing
		{ 4.6, 8, 25, 3, 0, 0.5, 0, 56 }, -- in to her whole body as her name comes up
		{ 5.15, 12, 21.5, 3, 0, 0.6, 0.15, 54 }, -- a slow drift while her name holds
		{ 6.0, 22, 12, 0, 0.82, 0, 0.85, 50 }, -- the speed-streak push, into her face
		{ 6.4, 25, 10, 0, 0.88, 0, 1, 48 }, -- the eye glint
	},
	{ -- after the cut: wide for the finale, the burst framed, then tilting up with her rise
		{ 6.4, 12, 35, 5, 0, 1, 0, 70 }, -- red streak lines sweep across
		{ 6.95, 6, 29, 6, 0, 1.5, 0, 69 }, -- butterflies burst out, the flare grows
		{ 7.55, 0, 27, 7, 0, 1.5, 0, 62 }, -- the last burst framed
		{ 7.75, -1, 28.5, 6.8, 0, 1.2, 0, 62 }, -- she starts to rise
		{ 9.5, -8, 50, 12.5, 0, 0, 0, 66 }, -- tilted up after her, pulled back over the map
		{ 10.0, -9, 53, 13.5, 0, 0, 0, 66 }, -- (still drifting under the dip to black)
	},
}

-- A smooth curve through one column of a run of keys at time t: cubic Hermite with Fritsch-Butland slopes (the
-- curve never overshoots a key and never stops dead at one unless the move turns round there). A run starts and
-- ends moving (a cut lands mid-move, like film).
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

-- The run of keys on screen at time t (a new run starts at each cut).
local function run(t: number): { { number } }
	local keys = SecretReveal.KEYS[1]
	for _, r in SecretReveal.KEYS do
		if t >= r[1][1] then keys = r end
	end
	return keys
end

-- A soft kick (0..1): eases up over `rise`, back down over `fall` (no one-frame jump).
local function kick(t: number, at: number, rise: number, fall: number): number
	local x = t - at
	if x < 0 or x > rise + fall then return 0 end
	if x < rise then return smooth(x / rise) end
	return 1 - smooth((x - rise) / fall)
end

-- The camera's field of view: from the keys, with a soft widening kick at the burst and the last burst.
function SecretReveal.fov(t: number, calm: boolean): number
	local base = curve(run(t), 8, t)
	if not calm then
		base += 8 * kick(t, SecretReveal.IMPACT, 0.18, 0.7) + 6 * kick(t, SecretReveal.BURST, 0.18, 0.7)
	end
	return base
end

-- How hard the camera shakes (studs-ish magnitude; 0 = still): a low rumble growing while the beams build, bumps on
-- the big strikes, the burst, the landing and the last burst. Small, and turned into a slow wobble by `shakeAt`.
function SecretReveal.shake(t: number): number
	local s = 0
	if t >= SecretReveal.BEAM_A and t < SecretReveal.HOLD then s = 0.05 + 0.1 * clamp01((t - SecretReveal.BEAM_A) / (SecretReveal.HOLD - SecretReveal.BEAM_A)) end
	s += 0.2 * pop(t, SecretReveal.BEAM_A, 0.05, 0.35) + 0.16 * pop(t, SecretReveal.BEAM_B, 0.05, 0.35)
	s += 0.4 * pop(t, SecretReveal.IMPACT, 0.05, 0.7) + 0.25 * pop(t, SecretReveal.LAND, 0.05, 0.45)
	if t >= SecretReveal.STREAKS[1] and t < SecretReveal.STREAKS[2] then
		s += 0.05 * math.min(1, (t - SecretReveal.STREAKS[1]) / 0.3, (SecretReveal.STREAKS[2] - t) / 0.3)
	end
	s += 0.4 * pop(t, SecretReveal.BURST, 0.05, 0.7)
	return s
end

SecretReveal.SHAKE_HZ = 4.5 -- the wobble's speed: slow enough to read as a rumble, not a stutter
-- The shake as a small turn (pitch, yaw, roll in radians) and slide (right, up in studs) of the camera, from smooth
-- noise at SHAKE_HZ; `seed` makes every screen's wobble different.
function SecretReveal.shakeAt(t: number, seed: number): (number, number, number, number, number)
	local s = SecretReveal.shake(t)
	if s <= 0 then return 0, 0, 0, 0, 0 end
	local n = t * SecretReveal.SHAKE_HZ
	return math.noise(n, seed) * s * 0.06, math.noise(seed, n) * s * 0.06, math.noise(n, n + seed) * s * 0.025,
		math.noise(n + 3.7, seed) * s * 0.5, math.noise(seed, n + 3.7) * s * 0.5
end

-- What the camera follows, in studs over the landing spot before scaling: the orb, then her as she drops (a touch
-- behind her and settling softly, so the tilt doesn't stop dead on the landing), then her rise (`h`).
local function followHeight(t: number, h: number): number
	if t < SecretReveal.RISE then
		return SecretReveal.ORB_HEIGHT * (1 - smooth((t - SecretReveal.IMPACT) / (SecretReveal.LAND - SecretReveal.IMPACT + 0.2)))
	end
	return h
end

-- The camera: eye and look-at, relative to the landing spot `at` (a Vector3), looking from `dir` (a flat unit
-- Vector3 from the spot towards the viewer: she faces it), with her current height `h` and scale `k` (1 =
-- Config/Round's 3x). `mid` (studs, optional): half her height (the orb sits where her middle appears; her face is
-- near 2 * mid). Defined up to LENGTH: it keeps drifting under the hand-back's dip to black.
function SecretReveal.camera(t: number, at: Vector3, dir: Vector3, h: number, k: number, mid: number?): (Vector3, Vector3)
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up)
	local m = mid or 7.5 * k
	local face = 2 * m - 1.6 * k
	local keys = run(t)
	local a = math.rad(curve(keys, 2, t))
	local eye = at + (dir * math.cos(a) + side * math.sin(a)) * curve(keys, 3, t) * k
		+ up * (curve(keys, 4, t) * k + curve(keys, 5, t) * face)
	local look = at + up * (followHeight(t, h) * k + m + curve(keys, 6, t) * k + curve(keys, 7, t) * (face - m))
	return eye, look
end

return SecretReveal
