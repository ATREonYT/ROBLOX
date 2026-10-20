--!strict
--[[
	How the owner's 3D knife crates open (owner, Oct 20: "make these crates for the opening of the normal knifes ...
	and make the opening animations look appropriate"; 07:51: "make the opening animation of the crates feel more
	premium, right now it feels too ai, as now they have the circle around the knife when it opens, remove it, add s
	nice animation for the knife when it starts rising up from the crater"). Pure maths, no Instances
	(tests/CrateMotion.spec.luau), used by UI/Crate3D (the crate in the opening screen) and the offline film
	(tools/preview/motion3d/crate_open_scene.luau), so both move the same way.

	Premium = restraint and timing: no circles, rings, rays or bursts; light and slow movement instead. No Huss Valley
	crate opening was among his references (the uploads are rounds, the lobby and the Secret cutscene), so the beats are
	ours. The timeline, in seconds from the server's answer (CrateMotion.T):
	  0 - 2.1    build-up: the crate rocks and hops a little harder and faster, a knock on each hop (closer and closer)
	  2.1        it cracks: the top lifts a few degrees and light spills out of the gap in the prize's rarity colour
	             (his glow parts take it); the shaking stops
	  2.1 - 2.6  a short pause, cracked
	  2.6        the top swings open on its back hinge with a soft overshoot (0.6 s)
	  2.75-4.35  his knife rises out slowly with a strong ease-out, leaning a little and making one slow turn, and
	             settles facing you into a gentle hover (a small bob and sway); the camera eases in a touch as it rises
	  from 2.35  a few small motes in the rarity colour drift up out of the crate, one at a time (never a burst)
	  4.2        one soft glint runs along the blade as it settles (one, not a flash)
	  4.45       the reveal (UI/Screens/CrateOpen): the name and rarity fade in, then NEW or the coins back
	A dark knife (Hollow Moon, Shadow Cleaver) gets a soft light right behind its blade (rimLight), shaped like the
	blade, never a disc.
	Kid-safe: no flashes at all (the glint is a small moving sheen); reduced motion: no shake, no motes, no glint, the
	knife simply there.
]]
local CrateMotion = {}

CrateMotion.T = {
	Build = 2.1, -- build-up length
	Crack = 2.1, -- the top lifts a little and light spills out
	CrackLen = 0.2,
	Open = 2.6, -- after a short pause, it swings open
	OpenLen = 0.6,
	Rise = 2.75,
	RiseLen = 1.6,
	Glint = 4.2,
	GlintLen = 0.55,
	Reveal = 4.45,
}
-- the knocks of the build-up (a tick sound and a hop each), closer and closer together
CrateMotion.Ticks = { 0.3, 0.72, 1.05, 1.32, 1.53, 1.7, 1.83, 1.93, 2.01 }
CrateMotion.LidOpen = math.rad(100) -- how far the top swings back from shut (radians)
CrateMotion.LidCrack = math.rad(9) -- how far it lifts when it cracks
CrateMotion.Turns = 1 -- whole turns the knife makes as it rises (one slow turn)
CrateMotion.Push = 0.08 -- how much nearer the camera eases as the knife rises
CrateMotion.Motes = 6

local function clamp01(x: number): number return math.clamp(x, 0, 1) end
local function easeOut(u: number, p: number): number return 1 - (1 - u) ^ p end
local function smooth(u: number): number return u * u * (3 - 2 * u) end
local function easeOutBack(u: number, k: number): number
	return 1 + (k + 1) * (u - 1) ^ 3 + k * (u - 1) ^ 2
end
CrateMotion.easeOut = easeOut

-- The build-up at time t: { tilt (radians, about the crate's right-left axis: + leans back), roll (radians, side to
-- side), lift (crate heights up), grow (scale) }. It stops as the top cracks. Calm (Motion.reduced): never moves.
function CrateMotion.shake(t: number, calm: boolean?): { tilt: number, roll: number, lift: number, grow: number }
	local T = CrateMotion.T
	local stop = T.Crack + 0.15
	if calm or t <= 0 or t >= stop + 0.25 then return { tilt = 0, roll = 0, lift = 0, grow = 1 } end
	local u = clamp01(t / T.Build)
	local power = u * u -- (builds up)
	-- a steady rattle that speeds up (5 to 15 a second) and grows
	local phase = 2 * math.pi * (5 * t + 5 * t * t / T.Build) -- (5 + 10 t / Build a second, added up, so the speed-up stays smooth)
	local roll = math.sin(phase) * math.rad(1 + 5 * power)
	local tilt = math.cos(phase * 0.5) * math.rad(0.5 + 2.5 * power)
	-- a small hop on each knock: up fast, down with a little bounce
	local lift = 0
	for i, at in CrateMotion.Ticks do
		local d = t - at
		if d >= 0 and d < 0.22 then
			local k = d / 0.22
			lift = math.max(lift, math.sin(k * math.pi) * (0.015 + 0.045 * i / #CrateMotion.Ticks))
			roll += math.sin(k * math.pi) * math.rad(2.5) * (if i % 2 == 0 then 1 else -1) * (0.4 + 0.6 * i / #CrateMotion.Ticks)
		end
	end
	local grow = 1 + 0.04 * power
	if t > T.Crack then -- (it cracks: the shaking dies in 0.15 s, it settles back to its size)
		local s = clamp01((t - T.Crack) / 0.15)
		roll, tilt, lift = roll * (1 - s), tilt * (1 - s), lift * (1 - s)
		grow = 1 + 0.04 * (1 - smooth(clamp01((t - T.Crack) / 0.4)))
		if t >= stop then roll, tilt, lift = 0, 0, 0 end
	end
	return { tilt = tilt, roll = roll, lift = lift, grow = grow }
end

-- How far the top is open at time t (radians about the back hinge; 0 = shut): it cracks a little, waits, then
-- swings open with a soft overshoot.
function CrateMotion.lid(t: number): number
	local T = CrateMotion.T
	if t <= T.Crack then return 0 end
	if t < T.Open then return CrateMotion.LidCrack * easeOut(clamp01((t - T.Crack) / T.CrackLen), 3) end
	local u = clamp01((t - T.Open) / T.OpenLen)
	return CrateMotion.LidCrack + (CrateMotion.LidOpen - CrateMotion.LidCrack) * easeOutBack(u, 0.9)
end

-- How much nearer the camera is at time t (1 = where it starts): it eases in a touch as the knife rises.
function CrateMotion.push(t: number, calm: boolean?): number
	if calm then return 1 end
	local T = CrateMotion.T
	return 1 + CrateMotion.Push * smooth(clamp01((t - T.Rise) / T.RiseLen))
end

-- The knife at time t: { up (0 = inside the crate, 1 = its show spot over it), spin (radians about up), scale (0..1
-- of its show size), tilt (radians, its lean), seen (drawn at all) }. It rises slowly with a strong ease-out, leaning
-- a little more as it comes out, makes one slow turn and ends facing you, then hovers: a small bob and sway.
function CrateMotion.knife(t: number, calm: boolean?): { up: number, spin: number, scale: number, tilt: number, seen: boolean }
	local T = CrateMotion.T
	if t < T.Rise then return { up = 0, spin = 0, scale = 0, tilt = 0, seen = false } end
	if calm then return { up = 1, spin = 2 * math.pi * CrateMotion.Turns, scale = 1, tilt = math.rad(10), seen = true } end
	local u = clamp01((t - T.Rise) / T.RiseLen)
	local after = math.max(0, t - (T.Rise + T.RiseLen))
	local hover = smooth(clamp01(after / 0.8)) -- (the hover eases in, so it never jolts)
	local up = easeOut(u, 3) + math.sin(after * 1.9) * 0.022 * hover
	local spin = 2 * math.pi * CrateMotion.Turns * easeOut(u, 3) + math.sin(after * 0.8) * math.rad(9) * hover
	local tilt = math.rad(10) + math.rad(8) * (1 - easeOut(u, 2))
	return { up = up, spin = spin, scale = 0.6 + 0.4 * easeOut(u, 3), tilt = tilt, seen = true }
end

-- How bright the light inside is at time t (0..1) and how much it has taken the prize's colour (0..1): a dim green
-- glow while it builds up; as it cracks, the light spills out in the rarity colour and grows as it opens.
function CrateMotion.glow(t: number): (number, number)
	local T = CrateMotion.T
	local build = clamp01(t / T.Build)
	if t < T.Crack then return 0.2 + 0.25 * build * build, 0 end
	local s = clamp01((t - T.Crack) / 0.25)
	local o = clamp01((t - T.Open) / T.OpenLen)
	return 0.45 + 0.3 * smooth(s) + 0.25 * smooth(o), smooth(s)
end

-- The lit layer just under the top (0 = none .. 1): it is the moment's light only while the top is cracked; it
-- fades out over SpillFade once the top swings open, so it never reads as a flat slab inside the open crate.
CrateMotion.SpillFade = 0.4
function CrateMotion.spill(t: number): number
	local T = CrateMotion.T
	if t < T.Crack then return 0 end
	return smooth(clamp01((t - T.Crack) / 0.25)) * (1 - smooth(clamp01((t - T.Open) / CrateMotion.SpillFade)))
end

-- One small glint along the blade as the knife settles: where it is (0 = the bottom of the knife, 1 = its tip) and
-- how bright (0..1), or nil when there is none. Only once, never in reduced motion.
function CrateMotion.glint(t: number, calm: boolean?): (number?, number)
	local T = CrateMotion.T
	local u = (t - T.Glint) / T.GlintLen
	if calm or u <= 0 or u >= 1 then return nil, 0 end
	return smooth(u), math.sin(math.pi * u) * 0.9
end

-- A little hash (0..1) so the motes look scattered but play the same every time.
local function hash(i: number, k: number): number
	local x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- The motes drifting up out of the open crate at time t: { x, z (crate widths/depths from its middle), y (crate
-- heights from its bottom), alpha (0..1), size (crate heights) } for each one showing. One at a time, each drifts up
-- and fades over 2.4 s, then a new one starts; none in reduced motion.
function CrateMotion.motes(t: number, calm: boolean?): { { x: number, y: number, z: number, alpha: number, size: number } }
	local out = {}
	if calm then return out end
	local T = CrateMotion.T
	local life, every = 2.4, 2.7
	for i = 1, CrateMotion.Motes do
		local born = T.Crack + 0.25 + (i - 1) * 0.42
		if t > born then
			local loop = math.floor((t - born) / every)
			local p = ((t - born) - loop * every) / life
			if p < 1 then
				local r1, r2, r3 = hash(i, loop), hash(i + 17, loop), hash(i + 31, loop)
				local x = (r1 - 0.5) * 0.55 + math.sin(p * math.pi * 1.5 + i) * 0.04
				table.insert(out, { x = x, z = (r2 - 0.5) * 0.35, y = 0.8 + 1.1 * easeOut(p, 1.6), alpha = math.sin(math.pi * p) ^ 1.5 * 0.85, size = 0.022 + 0.014 * r3 })
			end
		end
	end
	return out
end

--[[
	Which parts of his crate swing open, and the hinge. `parts` = { { name, y, z, sy, sz, group? } } (centre and size
	along the up and front-back axes, in the crate's own frame: front towards -Z, as all three of his crates are
	built; group = the name of the nameless "Node<n>" group of his .glb the part sits in, if any); `body` = the name of
	its main box (Config/Crates Model.Body). His file's own lid group wins: when a group holds a part named "...lid..."
	(the Storm Vault's lid, the Beast Chest's jaw with its teeth and horns), exactly the parts of such groups open.
	Otherwise (the Dojo Chest: no lid group, its roof is its top) everything whose centre is over the body's top, or
	whose name has "lid", opens, but not his sparkles and petals floating round it. His light inside (glow_inside)
	never does. The hinge runs along the back of the
	body's top. Returns the indices that open and the hinge's y and z (nothing opens when there is no such body).
]]
function CrateMotion.split(parts: { { name: string, y: number, z: number, sy: number, sz: number, group: string? } }, body: string): ({ number }, number, number)
	local top, back = -math.huge, -math.huge
	local found = false
	for _, p in parts do
		local base = string.gsub(string.gsub(p.name, "_Node$", ""), "_%d+$", "")
		if base == body then
			top = math.max(top, p.y + p.sy / 2)
			back = math.max(back, p.z + p.sz / 2)
			found = true
		end
	end
	local out = {}
	if not found then return out, 0, 0 end
	local lidGroups: { [string]: boolean } = {}
	for _, p in parts do
		if p.group and string.find(string.lower(p.name), "lid", 1, true) then lidGroups[p.group] = true end
	end
	if next(lidGroups) then
		for i, p in parts do
			if p.group and lidGroups[p.group] then table.insert(out, i) end
		end
		return out, top, back
	end
	for i, p in parts do
		local base = string.gsub(string.gsub(p.name, "_Node$", ""), "_%d+$", "")
		local inside = string.sub(base, 1, 11) == "glow_inside"
		local loose = string.find(base, "sparkle", 1, true) ~= nil or string.find(base, "petal", 1, true) ~= nil -- (floating in the air round it)
		if not inside and not loose and base ~= body and (p.y > top + 0.005 or string.find(base, "lid", 1, true) ~= nil) then
			table.insert(out, i)
		end
	end
	return out, top, back
end

-- How light a colour looks (0 black .. 1 white).
function CrateMotion.luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- A knife whose main colour (its first Config/CoinShop Colors entry) is this dark reads as a thin dark sliver against
-- the dark screen, so it gets a soft light behind its blade.
CrateMotion.DarkKnife = 0.3
function CrateMotion.isDark(knife: Color3?): boolean
	return knife ~= nil and CrateMotion.luminance(knife) < CrateMotion.DarkKnife
end

-- The soft light right behind a dark knife's blade at time t (0 = none .. 1), shaped like the blade by the caller
-- (never a disc), in its rarity colour lifted towards white (RimWhite). Fades in as the knife rises; 0 for the rest.
-- (critic, Oct 20: Hollow Moon still read as a thin dark sliver on navy at 0.55 and 0.7 white: now clearly lit)
CrateMotion.RimWhite = 0.88
CrateMotion.RimStrength = 0.92
function CrateMotion.rimLight(t: number, knife: Color3?): number
	if not CrateMotion.isDark(knife) then return 0 end
	return CrateMotion.RimStrength * easeOut(clamp01((t - CrateMotion.T.Rise) / (CrateMotion.T.RiseLen * 0.8)), 2)
end

-- How much brighter the whole crate view gets as the knife rises and hovers (0 .. 1 of a gentle lift towards white
-- light): a little for every knife, fully for a dark one, so a black blade shows its shape. Nothing before it rises.
function CrateMotion.viewLift(t: number, knife: Color3?): number
	local u = clamp01((t - CrateMotion.T.Rise) / CrateMotion.T.RiseLen)
	return smooth(u) * (if CrateMotion.isDark(knife) then 1 else 0.35)
end

return CrateMotion
