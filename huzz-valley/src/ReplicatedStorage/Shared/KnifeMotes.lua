--[[
	Where a knife's glowing ball motes are, moment by moment (coordinator, Oct 20, after the owner's "make the vfx ...
	better for more high end ones": Huss Valley's MELON5MAN has two or three crisp cyan balls drifting round the
	blade, which soft particles can't match). Pure maths, no Instances: Gameplay/KnifeFxRange moves the balls with it
	on each screen, and tools/preview/motion3d/knife_vfx_scene.luau films the same numbers.

	KnifeMotes.at(i, n, t, seed, box, size, drift) -> (offset, rise, transparency)
	  i of n balls, t seconds (any clock), seed (a number per knife, so knives don't move in step), box = the blade's
	  box size (Shared/KnifeFx "KnifeFxArea": X thickness, Y along the blade, Z width), size = the ball's size,
	  drift = studs a second up (+) or down (-) for the theme (embers rise, snow sinks).
	  offset is in the blade box's own space (put it through KnifeFxArea.CFrame), rise is world studs up to add, and
	  transparency is the ball's (PEAK at full, 1 at the ends of each path).
	KnifeMotes.glint / firstGlint time each knife's glint (below).
	Each ball floats on one soft path of CYCLE seconds off the blade's edges (never inside it), wobbling a little,
	fading in over FADE seconds at the start and out over FADE at the end (smoothstep: never a pop or a blink), then
	starts a new path somewhere else. The n balls are spread evenly over the cycle, so 2 to 4 show at any moment.
]]
local KnifeMotes = {}

KnifeMotes.CYCLE = 3.2 -- seconds on one path
KnifeMotes.FADE = 0.8 -- seconds to fade in, and again to fade out (kid-safe: smoothstep over 0.8 s is never faster than
                      -- a straight 0.5 s fade)
KnifeMotes.PEAK = 0.1 -- transparency at full
KnifeMotes.SPREAD = 0.16 -- how far from the blade's side a ball floats, times the blade's length (about MELON5MAN's)

local function hash(n: number): number
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

function KnifeMotes.at(i: number, n: number, t: number, seed: number, box: Vector3, size: number, drift: number): (Vector3, number, number)
	local L, F = KnifeMotes.CYCLE, KnifeMotes.FADE
	local s = t + seed + (i - 1) / math.max(n, 1) * L
	local cycle = math.floor(s / L)
	local age = s - cycle * L
	local key = seed * 7.13 + i * 101.7 + cycle * 13.37
	-- where on this path: along the blade (not past its ends), off one of its two edges (Z, the blade's width: seen
	-- round the outline, never sitting on the flat), and a little in front or behind (X, the thickness)
	local along = (hash(key) - 0.5) * box.Y * 0.85
	local side = if hash(key + 1) < 0.5 then -1 else 1
	-- (a slow soft wobble round that point: a small loop, about 0.1 of the blade across; kept clear of the edge)
	local w = box.Y * 0.05
	local out = box.Z / 2 + size * 0.6 + w + hash(key + 2) * box.Y * KnifeMotes.SPREAD
	local across = (hash(key + 3) - 0.5) * (box.X + box.Y * KnifeMotes.SPREAD * 0.6)
	local a = age * (1.3 + hash(key + 4)) + key
	local offset = Vector3.new(across + math.cos(a) * w * 0.5, along + math.sin(a * 0.7) * w, side * out + math.sin(a) * w)
	local fade = math.clamp(math.min(age, L - age) / F, 0, 1)
	fade = fade * fade * (3 - 2 * fade)
	return offset, drift * age, 1 - (1 - KnifeMotes.PEAK) * fade
end

-- A knife's glint (the Sparkle on its gem, KnifeFx_glint, Rate 0): one at a time on a fixed timer, never closer
-- than GLINT_MIN seconds whatever the frame rate (kid-safe; a random Rate gave gaps under 1 s more than half the time).
-- KnifeMotes.glint(nextAt, t, every) -> (glint now?, the next time). firstGlint(t, every, seed): a new knife's first
-- glint is a whole interval away (so dropping and remaking a knife can't glint twice close together), offset by seed.
KnifeMotes.GLINT_MIN = 1.5
function KnifeMotes.glint(nextAt: number, t: number, every: number): (boolean, number)
	if t >= nextAt then
		return true, t + math.max(every, KnifeMotes.GLINT_MIN)
	end
	return false, nextAt
end
function KnifeMotes.firstGlint(t: number, every: number, seed: number): number
	local e = math.max(every, KnifeMotes.GLINT_MIN)
	return t + e + (seed % e)
end

return KnifeMotes
