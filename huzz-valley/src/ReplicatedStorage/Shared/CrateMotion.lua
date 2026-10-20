--!strict
--[[
	How the owner's 3D knife crates open (owner, Oct 20: "make these crates for the opening of the normal knifes ...
	and make the opening animations look appropriate"). Pure maths, no Instances (tests/CrateMotion.spec.luau), used
	by UI/Crate3D (the crate in the opening screen) and the offline film (tools/preview/motion3d/crate_open_scene.luau),
	so both move the same way.

	The timeline, in seconds from the server's answer (CrateMotion.T):
	  0 - 2.1   build-up: the crate sits, then rocks and jumps harder and faster, a knock on each tick (the ticks
	            come closer and closer), and leans back a little more each time; it grows a touch
	  2.1       it opens: everything above its body's top swings up and back on a hinge along the back edge (his
	            lid, roof or jaw as he built it, never redrawn), overshooting a little and settling (0.5 s); the light
	            inside takes the prize's rarity colour
	  2.25-3.35 the knife (his own model from the same set) rises out of it, spinning fast and slowing, growing to
	            full size, and stops facing you with a small tilt
	  3.35      the reveal (UI/Screens/CrateOpen): the name and rarity, NEW or the coins back; the knife keeps a slow
	            turn and a gentle bob
	Behind the knife as it rises, a soft light (CrateMotion.backlight) so even a black blade (Hollow Moon, Shadow
	Cleaver) stands out: nearly white for a dark knife, the rarity colour lifted towards white for the rest.
	Kid-safe: no flashes here (the screen's one soft flash for Epic and up is limited to one a second there).
]]
local CrateMotion = {}

CrateMotion.T = {
	Build = 2.1, -- build-up length (it opens at this moment)
	OpenLen = 0.5,
	Rise = 2.25,
	RiseLen = 1.1,
	Reveal = 3.35,
}
-- the knocks of the build-up (a tick sound and a jump each), closer and closer together
CrateMotion.Ticks = { 0.3, 0.72, 1.05, 1.32, 1.53, 1.7, 1.83, 1.93, 2.01 }
CrateMotion.LidOpen = math.rad(100) -- how far the top swings back from shut (radians)
CrateMotion.Spins = 3 -- full turns the knife makes as it rises

local function clamp01(x: number): number return math.clamp(x, 0, 1) end
local function easeOut(u: number, p: number): number return 1 - (1 - u) ^ p end
local function easeOutBack(u: number, k: number): number
	return 1 + (k + 1) * (u - 1) ^ 3 + k * (u - 1) ^ 2
end
CrateMotion.easeOut = easeOut

-- The build-up at time t: { tilt (radians, about the crate's right-left axis: + leans back), roll (radians, side to
-- side), lift (crate heights up), grow (scale) }. Calm (Motion.reduced): never moves.
function CrateMotion.shake(t: number, calm: boolean?): { tilt: number, roll: number, lift: number, grow: number }
	local T = CrateMotion.T
	if calm or t <= 0 or t >= T.Build + T.OpenLen then return { tilt = 0, roll = 0, lift = 0, grow = 1 } end
	local u = clamp01(t / T.Build)
	local power = u * u -- (builds up)
	-- a steady rattle that speeds up (5 to 15 a second) and grows
	local phase = 2 * math.pi * (5 * t + 5 * t * t / T.Build) -- (5 + 10 t / Build a second, added up, so the speed-up stays smooth)
	local roll = math.sin(phase) * math.rad(1 + 7 * power)
	local tilt = math.cos(phase * 0.5) * math.rad(0.5 + 3 * power)
	-- a jump on each knock: up fast, down with a small bounce
	local lift = 0
	for i, at in CrateMotion.Ticks do
		local d = t - at
		if d >= 0 and d < 0.22 then
			local k = d / 0.22
			lift = math.max(lift, math.sin(k * math.pi) * (0.02 + 0.06 * i / #CrateMotion.Ticks))
			roll += math.sin(k * math.pi) * math.rad(3) * (if i % 2 == 0 then 1 else -1) * (0.4 + 0.6 * i / #CrateMotion.Ticks)
		end
	end
	local grow = 1 + 0.06 * power
	if t > T.Build then -- (as it opens: the shake stops and it settles back to its size)
		local s = clamp01((t - T.Build) / T.OpenLen)
		roll, tilt, lift = roll * (1 - s), tilt * (1 - s), lift * (1 - s)
		grow = 1 + 0.06 * (1 - easeOut(s, 2))
	end
	return { tilt = tilt, roll = roll, lift = lift, grow = grow }
end

-- How far the top is open at time t (radians about the back hinge; 0 = shut).
function CrateMotion.lid(t: number): number
	local T = CrateMotion.T
	if t <= T.Build then return 0 end
	local u = clamp01((t - T.Build) / T.OpenLen)
	return CrateMotion.LidOpen * easeOutBack(u, 1.4)
end

-- The knife at time t: { up (0 = inside the crate, 1 = its show spot over it), spin (radians about up), scale (0..1
-- of its show size), tilt (radians, the lean it ends with), seen (drawn at all) }.
function CrateMotion.knife(t: number, calm: boolean?): { up: number, spin: number, scale: number, tilt: number, seen: boolean }
	local T = CrateMotion.T
	if t < T.Rise then return { up = 0, spin = 0, scale = 0, tilt = 0, seen = false } end
	local u = clamp01((t - T.Rise) / T.RiseLen)
	local after = math.max(0, t - (T.Rise + T.RiseLen))
	if calm then u = 1 end
	-- spins fast and slows to a stop facing you (Spins whole turns), then a slow turn either way and a gentle bob
	local spin = 2 * math.pi * CrateMotion.Spins * easeOut(u, 3) + math.sin(after * 0.9) * math.rad(18)
	local up = easeOutBack(u, 1.1) + math.sin(after * 2.2) * 0.03
	return { up = up, spin = spin, scale = 0.35 + 0.65 * easeOut(u, 2), tilt = math.rad(14) * easeOut(u, 2), seen = true }
end

-- How bright the light inside is at time t (0..1) and how much it has taken the prize's colour (0..1).
function CrateMotion.glow(t: number): (number, number)
	local T = CrateMotion.T
	local build = clamp01(t / T.Build)
	if t < T.Build then return 0.25 + 0.35 * build * build, 0 end
	local s = clamp01((t - T.Build) / 0.3)
	return 0.6 + 0.4 * s, s
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

-- A knife whose main colour (its first Config/CoinShop Colors entry) is this dark reads as a thin sliver on the
-- coloured light behind it, so it gets a nearly white light instead.
CrateMotion.DarkKnife = 0.3
function CrateMotion.isDark(knife: Color3?): boolean
	return knife ~= nil and CrateMotion.luminance(knife) < CrateMotion.DarkKnife
end

-- The light behind the knife at time t: how far its rarity colour is lifted towards white (the caller does
-- rarity:Lerp(white, mix)) and how see-through it is (0 = solid). Fades in as the knife rises, then stays.
-- The third number: how far the big light behind everything (UI CrateRays) is lifted towards white too, so a dark
-- knife stands on a pale disc (0 for the rest).
function CrateMotion.backlight(t: number, knife: Color3?): (number, number, number)
	local u = easeOut(math.clamp((t - CrateMotion.T.Rise) / (CrateMotion.T.RiseLen * 0.7), 0, 1), 2)
	local dark = CrateMotion.isDark(knife)
	return if dark then 0.8 else 0.4, 1 - 0.75 * u, if dark then 0.6 * u else 0
end

return CrateMotion
