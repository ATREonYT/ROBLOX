--[[
	The Secret girl's arrival (owner: "crazy vfx for when a secret girl is chosen: a cutscene plays, its all crazy and
	then she ends up landing inside the map, and she then floats up above it and then the players go into the
	game"). The timing and the camera as plain numbers (pure: no Roblox instances), so the game
	(HuzzClient/Gameplay/SecretReveal builds the effects) and an offline video show the same.
	After docs/vfx-guide.md 6.3: build-up (55-65% of the time), one impact, aftermath.
	  0.0  wide shot of the middle of the map: it's night (your screen only, set on the cut so nothing visibly
	       changes) under a violet grade, the reference's dark purple sky, until she rises; a hum starts
	  0.4  an orb of light grows over the spot, sparks rush into it, lights circle it faster and faster, a pillar
	       of light rises; the camera pushes in
	  1.2  two curved crescents of light rise either side; from 1.75 bright lines slash across between them
	  2.05 two glowing eyes open in the dark where she'll appear (the owner's Oct 17 reference, design/vfx/ref3)
	  2.6  everything holds for a split second (the hit-stop)
	  2.72 IMPACT: a split-second manga impact frame (dark lines on white), then the orb bursts (star burst,
	       sparks, crystal shards, speed streaks, shock ring); she appears as a white silhouette in the air; a soft
	       brightness pulse right after (frame and pulse are one moment: the only flash, kid-safe); camera kicks out
	  2.72 she drops to the ground ...
	  3.1  ... and lands: a ring and a dome burst out, dust; the camera cuts low to her
	  3.1  slow orbit round her in the dark; blue butterflies drift up round her
	  5.0  she floats up to her place over the map (where she stays all game); the camera tilts up after her and
	       the sun comes back up (night to day over 1.6 s: a sunrise, no pop)
	  7.0  the camera eases back to you (no hard cut, no black bars), and the game goes on
	Reduced Motion: the same shots without shake, the kick, the impact frame or the brightness pulse.
]]
local SecretReveal = {}

SecretReveal.LENGTH = 7.5
SecretReveal.BUILD = 0.4 -- the orb starts growing
SecretReveal.HOLD = 2.6 -- the hit-stop
SecretReveal.IMPACT = 2.72
SecretReveal.LAND = 3.1
SecretReveal.RISE = 5.0
SecretReveal.RETURN = 7.0
SecretReveal.CRESCENTS = 1.2 -- two curved beams of light rise on either side of the orb (owner's Oct 17 reference)
SecretReveal.SLASHES = { 1.75, 1.95, 2.15, 2.35 } -- bright lines slash across between them, one after another
SecretReveal.EYES = 2.05 -- two glowing eyes open in the dark where she'll appear, until the impact
SecretReveal.FRAME = 0.09 -- the impact frame: a split second of black-on-white manga lines (the cutscene's one flash)
SecretReveal.ORB_HEIGHT = 8 -- studs over the landing spot, scaled with her (Config/Round.Showcase.Scale / 3)

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

SecretReveal.ORB_MAX = 2.7
-- The orb's size (studs, 0 = gone; at most ORB_MAX) and how fast the lights circle it (radians per second).
function SecretReveal.orb(t: number): (number, number)
	if t < SecretReveal.BUILD or t >= SecretReveal.IMPACT then return 0, 0 end
	local x = clamp01((t - SecretReveal.BUILD) / (SecretReveal.HOLD - SecretReveal.BUILD))
	return 0.5 + 2.2 * easeIn(x), 2 + 7 * easeIn(x) -- (at most 2.7: a bigger glowing ball hid the eyes over it)
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

-- The time of day on your screen (Lighting.ClockTime): night from the first frame (a camera cut hides the switch)
-- until she rises, then the sun comes back up to the game's own time `day`. A ColorCorrection can't make a sunny sky
-- dark purple without dimming the light effects just as much (filmed: tools/preview/motion3d/secret_scene.luau).
SecretReveal.NIGHT = 0 -- midnight
SecretReveal.BACK = 1.6 -- seconds from RISE for the day (and the colour) to come back
function SecretReveal.clock(t: number, day: number): number
	if t < 0 or t >= SecretReveal.RISE + SecretReveal.BACK then return day end
	if t < SecretReveal.RISE then return SecretReveal.NIGHT end
	-- through the dark hours quickly, then most of the time on the dawn itself (5.2 to 7.2), so the screen brightens
	-- evenly over about a second (a straight sweep crossed dawn in 0.1 s: a jump like a flash), then up to `day`
	local x = (t - SecretReveal.RISE) / SecretReveal.BACK
	local target = if day < 7.2 then day + 24 else day
	if x < 0.1 then return SecretReveal.NIGHT + (5.2 - SecretReveal.NIGHT) * smooth(x / 0.1) end
	if x < 0.85 then return 5.2 + 2 * (x - 0.1) / 0.75 end
	return (7.2 + (target - 7.2) * smooth((x - 0.85) / 0.15)) % 24
end

-- The world's grade: brightness, saturation, tint amount (0..1), the impact pulse (0..1) and contrast.
-- On from the start until she rises (the reference stays night all through), off over the sunrise.
function SecretReveal.grade(t: number): (number, number, number, number, number)
	local dim = if t < SecretReveal.RISE then smooth(t / 0.4) else 1 - smooth((t - SecretReveal.RISE) / SecretReveal.BACK)
	local pulse = 0
	if t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + 0.45 then
		local x = (t - SecretReveal.IMPACT) / 0.45
		pulse = if x < 0.11 then x / 0.11 else 1 - smooth((x - 0.11) / 0.89)
	end
	return -0.06 * dim, 0.1 * dim, dim, pulse, 0.12 * dim
end

-- Is the impact frame on screen? (one short hold right at the impact; never with Reduced Motion)
function SecretReveal.impactFrame(t: number, calm: boolean): boolean
	return not calm and t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + SecretReveal.FRAME
end

-- How bright one crossing slash is (0..1): it snaps on, then thins out over a third of a second.
function SecretReveal.slash(t: number, at: number): number
	local x = t - at
	if x < 0 or x > 0.4 then return 0 end
	if x < 0.04 then return x / 0.04 end
	return 1 - smooth((x - 0.04) / 0.36)
end

-- The camera's field of view: pushes in during the build-up, kicks out at the impact, settles.
function SecretReveal.fov(t: number, calm: boolean): number
	if t < SecretReveal.BUILD then return 70 end
	if t < SecretReveal.IMPACT then return 70 - 12 * smooth((t - SecretReveal.BUILD) / (SecretReveal.HOLD - SecretReveal.BUILD)) end
	if calm then return 58 + 12 * smooth((t - SecretReveal.IMPACT) / 0.6) end
	local x = t - SecretReveal.IMPACT
	if x < 0.06 then return 58 + 24 * (x / 0.06) end
	return 70 + 12 * (1 - easeOut((x - 0.06) / 0.6))
end

-- How hard the camera shakes (studs-ish magnitude; 0 = still). Smooth noise is applied by the client.
function SecretReveal.shake(t: number): number
	if t >= SecretReveal.BUILD and t < SecretReveal.HOLD then return 0.06 + 0.12 * easeIn((t - SecretReveal.BUILD) / (SecretReveal.HOLD - SecretReveal.BUILD)) end
	if t >= SecretReveal.IMPACT and t < SecretReveal.IMPACT + 0.7 then return 0.45 * (1 - (t - SecretReveal.IMPACT) / 0.7) end
	if t >= SecretReveal.LAND and t < SecretReveal.LAND + 0.4 then return 0.3 * (1 - (t - SecretReveal.LAND) / 0.4) end
	return 0
end

-- The camera: eye and look-at, relative to the landing spot `at` (a Vector3), looking from `dir` (a flat unit
-- Vector3 from the spot towards the viewer), with her current height `h` and scale `k` (1 = Config/Round's 3x).
-- `mid` (studs, optional): half her height, so the build-up looks straight at the orb (it sits where her middle
-- appears) and the eyes over it stay in frame.
-- Before the return; Gameplay/SecretReveal blends back to the player's own camera after RETURN.
function SecretReveal.camera(t: number, at: Vector3, dir: Vector3, h: number, k: number, mid: number?): (Vector3, Vector3)
	local up = Vector3.new(0, 1, 0)
	local side = dir:Cross(up)
	local orbH = SecretReveal.ORB_HEIGHT * k
	if t < SecretReveal.IMPACT then
		-- wide, then pushing in on the orb
		local x = smooth((t - SecretReveal.BUILD) / (SecretReveal.HOLD - SecretReveal.BUILD))
		local dist = (44 - 14 * x) * k
		return at + dir * dist + up * (10 + 2 * x) * k + side * 4 * k, at + up * (orbH + (mid or 0))
	elseif t < SecretReveal.LAND then
		-- holding on the drop
		return at + dir * 30 * k + up * 11 * k + side * 4 * k, at + up * (h + 4 * k)
	elseif t < SecretReveal.RISE then
		-- low hero angle, orbiting slowly round her (25 degrees)
		local a = math.rad(-12 + 25 * smooth((t - SecretReveal.LAND) / (SecretReveal.RISE - SecretReveal.LAND)))
		local d = (dir * math.cos(a) + side * math.sin(a)) * 22 * k
		return at + d + up * 2.5 * k, at + up * 7 * k
	else
		-- tilting up after her as she rises, pulling back
		local x = smooth((t - SecretReveal.RISE) / (SecretReveal.RETURN - SecretReveal.RISE))
		local a = math.rad(13)
		local d = (dir * math.cos(a) + side * math.sin(a)) * (22 + 26 * x) * k
		return at + d + up * (2.5 + 8 * x) * k, at + up * (7 * k + h)
	end
end

return SecretReveal
