--!strict
-- When a foot lands, in time with the walk on screen (Oct 27, the owner: "make them sound exactly when a step is taken
-- on screen to not throw people off"). Roblox's own footsteps loop at a rate guessed from the walk speed, so they drift
-- off the legs; ours read the legs themselves. Every frame each foot's height under the character's root goes in; a
-- step is the frame the falling foot reaches the ground, i.e. crosses Low of its swing above the lowest point it has
-- had lately. That follows any walk or run animation (Roblox's, the owner's own, a faster pair of shoes) with no
-- timings to keep in step. Pure: HoodClient/Footsteps calls it, the unit tests read it.
--   FootstepRules.foot()                  a fresh foot's memory
--   FootstepRules.step(foot, h, dt, moving) -> true the frame this foot lands (h: its height under the root, in studs;
--                                         moving: on the ground and walking)
--   FootstepRules.soft(material)          true for the soft set (grass, dirt, sand, snow), false for the hard one
local R = {}
R.Swing = 0.15 -- studs: a foot must rise and fall at least this much (an idle sway or a shuffle makes no steps)
R.Low = 0.06 -- the landing line, as a share of the swing above the lowest point
R.Lift = 0.45 -- a foot must be lifted above this share of its swing before its next landing counts
R.Gap = 0.12 -- seconds: the fastest one foot can step again
R.Relax = 0.05 -- studs a second: the remembered lowest and highest points ease toward the foot (a new animation's range)

export type Foot = { lo: number?, hi: number, last: number, armed: boolean, ago: number }

function R.foot(): Foot
	return { lo = nil, hi = 0, last = 0, armed = false, ago = math.huge }
end

function R.step(f: Foot, h: number, dt: number, moving: boolean): boolean
	f.ago += dt
	local lo = f.lo
	if lo == nil then
		f.lo, f.hi, f.last = h, h, h
		return false
	end
	lo = math.min(lo + R.Relax * dt, h)
	local hi = math.max(f.hi - R.Relax * dt, h, lo)
	f.lo, f.hi = lo, hi
	local swing = hi - lo
	local line = lo + R.Low * swing
	if h >= lo + R.Lift * swing then f.armed = true end
	local landed = moving and f.armed and swing >= R.Swing and f.ago >= R.Gap and f.last > line and h <= line
	if landed then
		f.armed = false
		f.ago = 0
	end
	f.last = h
	return landed
end

local SOFT = { Grass = true, LeafyGrass = true, Ground = true, Sand = true, Mud = true, Snow = true, Salt = true }

function R.soft(material: EnumItem | string?): boolean
	if material == nil then return false end
	local name = if typeof(material) == 'EnumItem' then (material :: EnumItem).Name else material :: string
	return SOFT[name] == true
end

return R
