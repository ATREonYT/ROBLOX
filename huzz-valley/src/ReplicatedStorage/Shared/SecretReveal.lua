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
	  3.3  wide low shot of her; 4.4 / 4.9 / 5.3 crescent slashes swirl round her
	  5.65 close over her shoulder; 6.2 wide again, crystals drifting down, a star flare on her at 6.75
	  7.0  speed streaks rush past while the camera pushes in; 9.35 close-up on her face, an eye glint
	  10.0 a soft bloom swell; red streak lines sweep across; 10.95 a swarm of butterflies
	  11.45 a pink star flare grows on her with crackling light; 12.25 the BURST (rays, flare, a pink cloud)
	  12.4 she floats up to her place over the map (she stays there all game); 13.4 the sun comes back up
	  14.0 the camera eases back to you (no hard cut, no black bars), and the game goes on
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

-- The shots (hard cuts between them, like the reference), by start time.
SecretReveal.SHOTS = {
	{ 0, "open" }, { 0.75, "beams" }, { 2.75, "impact" }, { 3.3, "wide" }, { 5.65, "shoulder" }, { 6.2, "wide2" },
	{ 7.0, "streaks" }, { 9.35, "face" }, { 10.0, "red" }, { 10.95, "swarm" }, { 11.45, "flare" }, { 12.4, "rise" },
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

-- Which shot is on, and the seconds since it started.
function SecretReveal.shot(t: number): (string, number)
	local name, from = SecretReveal.SHOTS[1][2], 0
	for _, s in SecretReveal.SHOTS do
		if t >= s[1] then name, from = s[2], s[1] end
	end
	return name, t - from
end

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
	local fade = 1 - smooth((t - SecretReveal.IMPACT - 0.15) / 0.5)
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

-- The world's grade: brightness, saturation, tint amount (0..1), the pulse (0..1) and contrast. Gentle: the
-- reference's night is a deep navy, not a saturated blue, and its pinks and reds stay red.
function SecretReveal.grade(t: number): (number, number, number, number, number)
	local dim = SecretReveal.night(t)
	return -0.04 * dim, -0.08 * dim, 0.4 * dim, SecretReveal.pulse(t), 0.04 * dim
end

-- Is the impact frame on screen? (one short hold right at the impact; never with Reduced Motion)
function SecretReveal.impactFrame(t: number, calm: boolean): boolean
	return not calm and t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + SecretReveal.FRAME
end

-- How bright one slash is (0..1): it snaps on, then thins out over a third of a second.
function SecretReveal.slash(t: number, at: number): number
	return pop(t, at, 0.04, 0.36)
end

-- The camera's field of view: per shot, with a push in on the beams, kicks at the impact and the burst.
function SecretReveal.fov(t: number, calm: boolean): number
	local name, x = SecretReveal.shot(t)
	local base = 70
	if name == "beams" then
		base = 70 - 10 * smooth(x / 2)
	elseif name == "impact" then
		base = 62
	elseif name == "shoulder" then
		base = 62
	elseif name == "streaks" then
		base = 66 - 14 * smooth(x / 2.35)
	elseif name == "face" then
		base = 48
	elseif name == "swarm" then
		base = 74
	elseif name == "flare" then
		base = 64 - 6 * smooth(x / 0.8)
	end
	if not calm then
		base += 16 * pop(t, SecretReveal.IMPACT, 0.06, 0.6) + 12 * pop(t, SecretReveal.BURST, 0.06, 0.6)
	end
	return base
end

-- How hard the camera shakes (studs-ish magnitude; 0 = still). Smooth noise is applied by the client.
function SecretReveal.shake(t: number): number
	local s = 0
	if t >= SecretReveal.BEAM_A and t < SecretReveal.HOLD then s = 0.06 + 0.1 * clamp01((t - SecretReveal.BEAM_A) / 1.9) end
	s += 0.25 * pop(t, SecretReveal.BEAM_A, 0.02, 0.3) + 0.2 * pop(t, SecretReveal.BEAM_B, 0.02, 0.3)
	s += 0.45 * pop(t, SecretReveal.IMPACT, 0.02, 0.7) + 0.3 * pop(t, SecretReveal.LAND, 0.02, 0.4)
	if t >= SecretReveal.STREAKS[1] and t < SecretReveal.STREAKS[2] then s += 0.06 end
	s += 0.45 * pop(t, SecretReveal.BURST, 0.02, 0.7)
	return s
end

-- The camera: eye and look-at, relative to the landing spot `at` (a Vector3), looking from `dir` (a flat unit
-- Vector3 from the spot towards the viewer), with her current height `h` and scale `k` (1 = Config/Round's 3x).
-- `mid` (studs, optional): half her height (the orb sits where her middle appears; her face is near 2 * mid).
-- Before the return; Gameplay/SecretReveal blends back to the player's own camera after RETURN.
function SecretReveal.camera(t: number, at: Vector3, dir: Vector3, h: number, k: number, mid: number?): (Vector3, Vector3)
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up)
	local m = mid or 7.5 * k
	local orbH = SecretReveal.ORB_HEIGHT * k + m
	local face = 2 * m - 1.6 * k
	local function round(deg: number, dist: number): Vector3
		local a = math.rad(deg)
		return (dir * math.cos(a) + side * math.sin(a)) * dist
	end
	local name, x = SecretReveal.shot(t)
	if name == "open" then
		return at + round(8, (48 - 3 * x) * k) + up * 8 * k, at + up * (orbH * 0.8)
	elseif name == "beams" then
		-- medium-wide, low, looking a touch up at the orb, pushing in (the reference's static beam shot)
		local p = smooth(x / 2)
		return at + round(6, (42 - 8 * p) * k) + up * 6 * k, at + up * (orbH + 1.5 * k)
	elseif name == "impact" then
		-- holding on the drop
		return at + round(6, 34 * k) + up * 8 * k, at + up * (h * k + m)
	elseif name == "wide" then
		-- wide, low, a slow drift round her
		return at + round(-16 + 10 * smooth(x / 2.35), 36 * k) + up * 3 * k, at + up * (m + 1 * k)
	elseif name == "shoulder" then
		-- close over her shoulder, looking past her (she faces you)
		return at - dir * 6 * k + side * 4.5 * k + up * (face - 1 * k), at + dir * 40 * k + side * 2 * k + up * (m + 2 * k)
	elseif name == "wide2" then
		return at + round(28, (30 + 3 * x) * k) + up * 2.5 * k, at + up * (m + 2 * k)
	elseif name == "streaks" then
		-- pushing in from the side while streaks rush past
		local p = smooth(x / 2.35)
		return at + round(34, (30 - 10 * p) * k) + up * (6 - 1.5 * p) * k, at + up * (m + 1.5 * k)
	elseif name == "face" then
		-- close-up on her face, a little from below
		return at + round(12, 9 * k) + up * (face - 1.2 * k), at + up * face
	elseif name == "red" then
		return at + round(-30, 38 * k) + up * 5 * k, at + up * (m + 1 * k)
	elseif name == "swarm" then
		return at + round(10 - 12 * x, 16 * k) + up * (m + 1 * k), at + up * (m + 2 * k)
	elseif name == "flare" then
		return at + round(4, (32 - 4 * smooth(x / 0.95)) * k) + up * 7 * k, at + up * (m + 1.5 * k)
	end
	-- "rise": tilting up after her as she rises, pulling back
	local p = smooth(x / (SecretReveal.RETURN - SecretReveal.RISE))
	return at + round(8, (30 + 22 * p) * k) + up * (6 + 6 * p) * k, at + up * (m + h * k)
end

return SecretReveal
