--!strict
-- New Game Kit: CameraMath (vault note 28 Camera Playbook). Pure maths, no Instances: the
-- client camera script calls these every frame, and the specs prove the numbers offline.
--
--   CameraMath.Damp(halfLife, dt)            -> 0..1 blend that feels the same at 30 and 240 fps
--   CameraMath.SideOnDistance(height, fov)   -> how far back a side-on camera sits to show `height` studs
--   CameraMath.FovStack(base, kicks, caps)   -> one FOV owner: base + every named kick, capped
--   CameraMath.Trauma(t0, decay, elapsed)    -> trauma left after `elapsed` s (shake = trauma^2)
--   CameraMath.ShakeScale(fov, setting, reduced) -> shake multiplier (zoom, the player's setting, Reduced Motion)
--   CameraMath.Letterbox(screenH, frac)      -> whole-pixel bar height (UDim offsets must be integers)
-- Status: covered by tests/CameraMath.spec.luau (offline).

local CameraMath = {}

CameraMath.Defaults = {
	baseFov = 70,
	maxKick = 12, -- all gameplay FOV kicks together never add more than +12 degrees (note 27 §3)
	minFov = 35,
	maxFov = 105,
	shakeDecay = 1.25, -- per second (note 27 C22: 1.0 to 1.5)
	letterbox = 0.08, -- 8% of the screen height (C14)
}

local LN2 = math.log(2)

-- Frame-rate independent smoothing. dt is clamped so a hitch can't fling the camera.
function CameraMath.Damp(halfLife: number, dt: number): number
	if halfLife <= 0 then
		return 1
	end
	local d = math.clamp(dt, 0, 0.1)
	return 1 - math.exp(-d * LN2 / halfLife)
end

-- Distance from the subject so `height` studs fill the screen vertically at `fov` degrees.
function CameraMath.SideOnDistance(height: number, fov: number): number
	return (height / 2) / math.tan(math.rad(fov) / 2)
end

-- kicks: { [name] = degrees } (sprint, boost, rare-shot punch...). Positive kicks share one cap,
-- negative ones (zoom-ins) are allowed down to minFov. The result is always inside min..max.
function CameraMath.FovStack(base: number?, kicks: { [string]: number }, caps: { maxKick: number?, minFov: number?, maxFov: number? }?): number
	local d = CameraMath.Defaults
	local b = base or d.baseFov
	local up, down = 0, 0
	for _, v in kicks do
		if v > 0 then
			up += v
		else
			down += v
		end
	end
	local c = caps or {}
	up = math.min(up, c.maxKick or d.maxKick)
	return math.clamp(b + up + down, c.minFov or d.minFov, c.maxFov or d.maxFov)
end

function CameraMath.Trauma(start: number, decay: number?, elapsed: number): number
	return math.max(0, math.min(1, start) - (decay or CameraMath.Defaults.shakeDecay) * elapsed)
end

-- setting: the player's shake setting 0..1; reduced: GuiService.ReducedMotionEnabled.
-- Zoomed-in views (low FOV) shake less so a telephoto shot doesn't look like an earthquake.
function CameraMath.ShakeScale(fov: number, setting: number?, reduced: boolean?): number
	if reduced then
		return 0
	end
	local zoom = math.tan(math.rad(fov) / 2) / math.tan(math.rad(35))
	return math.clamp(zoom, 0, 1.5) * math.clamp(setting or 1, 0, 1)
end

function CameraMath.Letterbox(screenHeight: number, frac: number?): number
	return math.floor(screenHeight * (frac or CameraMath.Defaults.letterbox) + 0.5)
end

return CameraMath
