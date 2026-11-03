--!strict
-- Pure maths for stride sync (Controllers/StrideController.lua; tested by tools/tests/test_stride_rules.py).
--
-- The idea: while a foot is planted it should not move in the world. The root moves forward at v (ground speed);
-- the animation moves the planted foot backward relative to the root at u = a * rate, where a is the clip's authored
-- speed (studs/s at playback rate 1) and rate is our AdjustSpeed. The foot's world speed along the walking direction
-- is w = v - u. Feet stick when w = 0, i.e. rate = v / a. We don't know a for the player's avatar pack, so we
-- measure it: a = (v - w) / rate, and keep re-estimating it (feedback), which also absorbs avatar height/scale.
local StrideRules = {}

-- 0 at/below `start`, 1 at/above `stop`, smooth in between (smoothstep).
function StrideRules.runWeight(speed: number, start: number, stop: number): number
	if stop <= start then
		return if speed >= stop then 1 else 0
	end
	local t = math.clamp((speed - start) / (stop - start), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The clip's authored speed implied by one planted-foot measurement, or nil when the sample is unusable.
--   speed   = root ground speed along the walking direction (studs/s)
--   footVel = planted foot's world speed along the same direction (+ = sliding forward)
--   rate    = the playback rate that produced this frame
function StrideRules.authoredSpeed(speed: number, footVel: number, rate: number): number?
	if rate <= 0.05 or speed <= 0.5 then
		return nil
	end
	local u = speed - footVel -- how fast the animation carried the foot backward
	if u <= 0.25 then
		return nil
	end
	return u / rate
end

-- Moves an estimate toward a new sample, exponentially, by `gain` per second.
function StrideRules.follow(current: number, sample: number, gain: number, dt: number): number
	local k = 1 - math.exp(-gain * math.max(dt, 0))
	return current + (sample - current) * k
end

-- Learns a clip's authored speed. It's a constant of the clip, so the best estimate is a running mean of the samples;
-- `seconds` is how much evidence we have (returned updated). Early on each sample moves it a lot (a new avatar pack
-- settles in about a second); later it barely moves (a single foot measurement is noisy). `memory` caps the evidence
-- so a changed pack (or a rescaled avatar) is re-learned within a few seconds.
function StrideRules.learn(current: number, seconds: number, sample: number, dt: number, memory: number): (number, number)
	local n = math.min(seconds + dt, memory)
	return current + (sample - current) * (dt / math.max(n, dt)), n
end

-- One clip's own authored speed from a blended sample: take the other clip's share back out.
--   mixed = authored speed measured for the blend, other = the other clip's current estimate (nil = unknown),
--   w = the OTHER clip's weight. Unknown other clip, or too much of it in the mix: no sample.
function StrideRules.unblend(mixed: number, other: number?, w: number): number?
	if w <= 0.001 then
		return mixed
	end
	if not other or w > 0.4 then
		return nil
	end
	return (mixed - other * w) / (1 - w)
end

-- Playback rate that makes the planted foot stick at this speed.
function StrideRules.rateFor(speed: number, authored: number, minRate: number, maxRate: number): number
	if authored <= 0.01 then
		return minRate
	end
	return math.clamp(speed / authored, minRate, maxRate)
end

-- Authored speed of a walk/run blend: the weights mix the two clips, so their speeds mix the same way.
function StrideRules.blendAuthored(walkAuthored: number, runAuthored: number, runWeight: number): number
	return walkAuthored + (runAuthored - walkAuthored) * math.clamp(runWeight, 0, 1)
end

return StrideRules
