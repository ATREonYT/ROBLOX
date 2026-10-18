--[[
	The Secret girl's arrival (owner: "crazy vfx for when a secret girl is chosen: a cutscene plays, its all crazy and
	then she ends up landing inside the map, and she then floats up above it and then the players go into the
	game"; Oct 17: "make the cutscene look one to one as the reference"). The timing, the shots and the camera as
	plain numbers (pure: no Roblox instances), so the game (HuzzClient/Gameplay/SecretReveal builds the effects) and
	the offline film (tools/preview/motion3d/secret_scene.luau) show the same. The shot list follows the owner's
	reference beat by beat (design/vfx/ref3, beat sheet docs/secret-beats.md); she arrives instead of being there.
	  0.0  wide shot of the spot: night on your screen (set on the cut), purple haze in the sky, stars, motes,
	       drifting crystals; 0.3 a small orb of light; 0.5 a little starburst on it
	  0.75 beam A strikes down (a wide violet haze, a magenta glow, a crackling white core); shards fly
	  1.25 red-pink slashes cross the screen (four); 1.4 glowing "ladder" blocks climb beam A
	  1.9  beam B strikes: twin beams; 2.15 two big glowing eyes open between them, a glint line through them
	  2.63 the hit-stop
	  2.75 IMPACT: a split-second manga frame, light rays and four-point sparkles, a soft bloom; she appears in
	       white, drops and lands (3.15): rings, a dome, purple smoke
	  3.3  low and wide on her, drifting round; 4.4 / 4.9 / 5.3 crescent slashes swirl round her
	  5.3  the camera swoops in close to her face from the side; 6.3 back out wide, crystals drifting down, a star
	       flare on her at 6.75
	  7.0  speed streaks rush past while the camera pushes in, right into her face (9.6: an eye glint)
	  10.0 a soft bloom swell (the one cut, under it: wide); red streak lines sweep across; 10.95 a swarm of
	       butterflies, the camera moves in among them
	  11.45 a pink star flare grows on her with crackling light; 12.25 the BURST (rays, flare, a pink cloud)
	  12.4 she floats up to her place over the map (she stays there all game), the camera tilting up after her;
	       13.4 the sun comes back up
	  14.0 a quick dip to black hands the camera back to you (no black bars), and the game goes on
	The camera is one smooth move round the front of her (KEYS, below), not a string of hard cuts.
	Flashes (kid-safe, at most one a second): soft pulses at 2.75, 10.0 and 12.25 only, measured on the film.
	Reduced Motion: the same shots without shake, kicks, the impact frame, the pulses or the crackle.
]]
local SecretReveal = {}

SecretReveal.LENGTH = 14.5
SecretReveal.BUILD = 0.3 -- the orb appears
SecretReveal.SPARK = 0.5 -- a little starburst on it (the reference's 0.5 s)
SecretReveal.BEAM_A = 0.75 -- the first beam strikes down
SecretReveal.SLASHES = { 1.25, 1.45, 1.65, 1.85 } -- red-pink slashes, one after another
SecretReveal.LADDER = { 1.4, 1.95 } -- glowing blocks climb beam A
SecretReveal.BEAM_B = 1.9 -- the second beam: twin beams
SecretReveal.EYES = 2.15 -- two glowing eyes open between the beams, until the impact
SecretReveal.HOLD = 2.63 -- the hit-stop
SecretReveal.IMPACT = 2.75
SecretReveal.FRAME = 0.09 -- the impact frame: a split second of manga lines
SecretReveal.LAND = 3.15
SecretReveal.SWINGS = { 4.4, 4.9, 5.3 } -- crescent slashes swirl round her
SecretReveal.FLARE = 6.75 -- a star flare on her
SecretReveal.STREAKS = { 7.0, 9.35 } -- speed streaks rush past
SecretReveal.GLINT = 9.6 -- an eye glint in the close-up
SecretReveal.SWELL = 10.0 -- a soft bloom swell
SecretReveal.RED = { 10.1, 10.25, 10.4, 10.55, 10.7 } -- red streak lines sweep across
SecretReveal.SWARM = 10.95 -- butterflies burst out round her
SecretReveal.GROW = { 11.45, 12.25 } -- a pink star flare grows on her, crackling
SecretReveal.BURST = 12.25 -- the second impact
SecretReveal.RISE = 12.4
SecretReveal.RETURN = 14.0
SecretReveal.ORB_HEIGHT = 8 -- studs over the landing spot, scaled with her (Config/Round.Showcase.Scale / 3)
SecretReveal.ORB_MAX = 2.7
SecretReveal.NIGHT = 0 -- midnight
SecretReveal.DAWN = 13.4 -- the night starts to clear (the reference is still night at 13.6)
SecretReveal.BACK = 1.1 -- seconds from DAWN for the day (and the colour) to come back (ends with the cutscene)

-- The camera (owner, Oct 18: "a bit chopy still and the camera is still not very logical"): ONE designed move, not
-- eleven hard cuts. Keyframes round her, and the camera glides between them on a smooth curve (no stops, no
-- overshoot: a monotone cubic per number). It always stays in front of her (she faces you; the old over-the-shoulder
-- shot looked out from behind her at an empty red sky), follows what matters (the orb, her drop, her rise) and cuts
-- only once, on purpose, under the bloom swell at 10.0 (CUTS). Each key: time, angle round her (degrees from your
-- side, + = to her left on screen), flat distance (studs x k), eye height (studs x k) + `ef` x her face height, look
-- point over what the camera follows (studs x k) + `lf` x (face - middle), field of view.
--   t      ang   dist  eye  ef   look  lf   fov
SecretReveal.CUTS = { 10.0 }
SecretReveal.KEYS = {
	{ -- the arrival: one slow push from the wide shot up to the orb, down with her, and round her
		{ 0.0, -12, 50, 9, 0, -3, 0, 70 }, -- wide on the spot: night falls, the orb appears
		{ 0.75, -8, 44, 7.5, 0, 0, 0, 68 }, -- beam A strikes: lower, looking up
		{ 1.9, -3, 38.5, 6, 0, 1.5, 0, 64 }, -- beam B: twin beams, the eyes open
		{ 2.6, 0, 35, 6, 0, 1.5, 0, 61 }, -- easing into the hit-stop
		{ 2.75, 1, 34.5, 6.2, 0, 1.2, 0, 60 }, -- IMPACT: still, she drops (the look follows her down)
		{ 3.5, 4, 35, 3.5, 0, 1, 0, 64 }, -- settled low and wide after the landing
		{ 5.25, 13, 33, 3, 0, 1.5, 0, 63 }, -- a slow drift round her while the crescents swirl
		{ 5.95, 38, 12, 0, 0.85, 0, 0.8, 56 }, -- swoops in close to her face from the side (the reference's close beat)
		{ 6.3, 42, 11, 0, 0.85, 0, 0.8, 55 }, -- holds close, still turning
		{ 6.95, 37, 30, 3, 0, 2, 0, 68 }, -- pulls back wide: the star flare on her
		{ 9.1, 34, 19, 4.5, 0, 1.5, 0, 56 }, -- the speed-streak push
		{ 9.6, 31, 9, 0, 0.9, 0, 1, 48 }, -- right into her face: the eye glint
		{ 10.0, 29, 8.5, 0, 0.9, 0, 1, 47 },
	},
	{ -- after the swell: wide, into the swarm, back for the burst, then tilting up with her rise
		{ 10.0, 14, 36, 5, 0, 1, 0, 70 }, -- red streak lines sweep across
		{ 10.95, 8, 30, 6, 0, 1.5, 0, 70 }, -- butterflies burst out
		{ 11.4, 3, 17, 8.5, 0, 2, 0, 74 }, -- among them
		{ 12.2, -2, 27, 7, 0, 1.5, 0, 62 }, -- back out as the flare grows: the burst framed
		{ 12.4, -3, 28.5, 6.8, 0, 1.2, 0, 62 }, -- she starts to rise
		{ 14.0, -8, 50, 12.5, 0, 0, 0, 66 }, -- tilted up after her, pulled back over the map
		{ 14.5, -9, 53, 13.5, 0, 0, 0, 66 }, -- (still drifting under the dip to black)
	},
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

-- One of the twin beams: how far its strike has come down (0..1) and how strong it is (0..1). They strike from
-- the sky in 0.18 s, hold, and melt into the impact.
function SecretReveal.beam(t: number, at: number): (number, number)
	if t < at then return 0, 0 end
	local reach = easeOut((t - at) / 0.18)
	local fade = 1 - smooth((t - SecretReveal.IMPACT) / 0.2) -- (gone 0.2 s after the impact: dark by 3 s, like the reference)
	return reach, math.min(1, (t - at) / 0.08) * fade
end

-- The ladder blocks on beam A (0..1).
function SecretReveal.ladder(t: number): number
	local a, b = SecretReveal.LADDER[1], SecretReveal.LADDER[2]
	if t < a or t > b then return 0 end
	return math.min(1, (t - a) / 0.1, (b - t) / 0.15)
end

-- Her height over the landing spot (studs, before scaling), or nil while she isn't there yet.
-- `top` is how high she floats for the game (Config/Round.Showcase.Height).
function SecretReveal.height(t: number, top: number): number?
	if t < SecretReveal.IMPACT then return nil end
	if t < SecretReveal.LAND then -- drops from the orb to the ground
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
	if x < 0.1 then return SecretReveal.NIGHT + (5.2 - SecretReveal.NIGHT) * smooth(x / 0.1) end
	if x < 0.85 then return 5.2 + 2 * (x - 0.1) / 0.75 end
	return (7.2 + (target - 7.2) * smooth((x - 0.85) / 0.15)) % 24
end

-- How much of the cutscene's look is on (0..1): the night sky, the purple haze, the stronger bloom and the grade.
function SecretReveal.night(t: number): number
	if t < 0 then return 0 end
	if t < SecretReveal.DAWN then return smooth(t / 0.4) end
	return 1 - smooth((t - SecretReveal.DAWN) / SecretReveal.BACK)
end

-- The soft brightness pulses (0..1): the impact, the swell and the burst. Never two within a second.
function SecretReveal.pulse(t: number): number
	return math.max(pop(t, SecretReveal.IMPACT, 0.05, 0.4), 0.7 * pop(t, SecretReveal.SWELL, 0.12, 0.45), pop(t, SecretReveal.BURST, 0.05, 0.5))
end

-- The world's grade: brightness, saturation, tint amount (0..1), the pulse (0..1) and contrast. At night the world
-- goes dark and grey (the reference's ground is near-black navy, not green); the effects glow through it.
function SecretReveal.grade(t: number): (number, number, number, number, number)
	local dim = SecretReveal.night(t)
	return -0.15 * dim, -0.3 * dim, 0.4 * dim, SecretReveal.pulse(t), 0.06 * dim
end

-- Is the impact frame on screen? (one short hold right at the impact; never with Reduced Motion)
function SecretReveal.impactFrame(t: number, calm: boolean): boolean
	return not calm and t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + SecretReveal.FRAME
end

-- How bright one slash is (0..1): it snaps on, then thins out over a third of a second.
function SecretReveal.slash(t: number, at: number): number
	return pop(t, at, 0.04, 0.36)
end

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

-- The camera's field of view: from the keys, with a soft widening kick at the impact and the burst.
function SecretReveal.fov(t: number, calm: boolean): number
	local base = curve(run(t), 8, t)
	if not calm then
		base += 8 * kick(t, SecretReveal.IMPACT, 0.18, 0.7) + 6 * kick(t, SecretReveal.BURST, 0.18, 0.7)
	end
	return base
end

-- How hard the camera shakes (studs-ish magnitude; 0 = still): a low rumble while the beams build, bumps on the
-- strikes, the impact, the landing and the burst. Small, and turned into a slow wobble by `shakeAt` (a fast
-- 12 Hz jitter read as stutter).
function SecretReveal.shake(t: number): number
	local s = 0
	if t >= SecretReveal.BEAM_A and t < SecretReveal.HOLD then s = 0.05 + 0.08 * clamp01((t - SecretReveal.BEAM_A) / 1.9) end
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
