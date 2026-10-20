--!strict
--[[
	How the owner's 3D knife crates open (owner, Oct 20: "make these crates for the opening of the normal knifes ...
	and make the opening animations look appropriate"; 07:51: "make the opening animation of the crates feel more
	premium, right now it feels too ai, as now they have the circle around the knife when it opens, remove it, add s
	nice animation for the knife when it starts rising up from the crater"; 15:13: "please make the case opening
	animation way, way better, right now its so vague and doesnt look good, remove so much glow from the crates, and
	then make it feel premium"). Pure maths, no Instances (tests/CrateMotion.spec.luau), used by UI/Crate3D (the crate
	in the opening screen) and the offline film (tools/preview/motion3d/crate_open_scene.luau), so both move the same.

	Premium = weight, one clear moment, and quiet everywhere else (the way console and mobile reveals read): a fixed
	shot on the crate, three heavy hops, a latch, the lid flung open with a bounce, the knife out big and sharp in
	front of a dark backdrop, its rarity told by ONE colour, the name landing with a short punch. No haze, motes,
	glints, rings or glowing crate. The timeline, in seconds from the server's answer (CrateMotion.T):
	  0.3, 0.82, 1.3  three hops, each heavier: up, a tip to one side, a thud and a small bounce; still between them
	  1.8             the latch pops: the lid cracks about 11 deg with a small jolt and a thin line of light in the rarity colour shows
	  2.2             the lid is flung open (a spring: fast, about 9% past open, back, still in 0.55 s); the crate
	                  rocks back a touch from its weight; the backdrop behind takes the rarity colour (0.6 s fade)
	  2.3 - 3.2       the knife comes out: up from inside, then towards you, growing to full size, a three quarter
	                  turn that ends on its profile, leaning into a diagonal; it stops sharp (3% past, back); the crate
	                  falls into shadow so the knife is the only bright thing; a thin light rim outlines the blade
	  3.25            its name lands (a short scale punch), the rarity tag, NEW! or the coins, then the buttons
	After that it hovers: a tiny bob and sway (the camera never moves on its own: a slow 6% push-in, then still).
	Kid-safe: nothing flashes (the backdrop's colour fades in over 0.6 s; the light inside ramps up and down); reduced
	motion: no hops, no swing, the knife simply there.
]]
local CrateMotion = {}

CrateMotion.T = {
	Hops = { 0.3, 0.82, 1.3 }, -- three hops, each heavier (a thud on each landing: Lands)
	HopLen = 0.36,
	Crack = 1.8, -- the latch pops: the lid lifts a little and its light shows
	CrackLen = 0.1,
	Open = 2.2, -- the lid is flung open
	OpenLen = 0.55,
	Rise = 2.3, -- the knife comes out
	RiseLen = 0.9,
	Reveal = 3.25, -- its name lands (UI/Screens/CrateOpen)
	TintLen = 0.6, -- the backdrop takes the rarity colour from Open
}
CrateMotion.HopUp = 0.2 -- how long a hop takes to land (s)
CrateMotion.HopPower = { 0.6, 0.8, 1 }
CrateMotion.HopLift = 0.06 -- crate heights at the strongest hop
CrateMotion.HopRoll = math.rad(5) -- its tip to one side at the strongest hop
CrateMotion.Lands = {} :: { number } -- when each hop lands (a thud)
for i, at in CrateMotion.T.Hops do CrateMotion.Lands[i] = at + CrateMotion.HopUp end
CrateMotion.LidOpen = math.rad(100) -- how far the top swings back from shut (radians)
CrateMotion.LidCrack = math.rad(11) -- how far it lifts when the latch pops (critic, Oct 20: 7 deg did not read)
CrateMotion.Push = 0.06 -- how much nearer the camera is by the reveal (a slow push-in from the start)
-- the knife's path, in the crate's own frame (crate heights up from its bottom, crate depths forward from its middle):
-- from inside the crate (small), up out of it, then forward towards you at full size, leaning into a diagonal
CrateMotion.Knife = { FromY = 0.32, ToY = 1.05, Forward = 0.62, Len = 1.3, StartScale = 0.5, Turn = 0.75, Lean = math.rad(22) }
CrateMotion.Dim = 0.5 -- how dark the crate gets behind the knife (0 = as lit, 1 = black)
CrateMotion.PunchFrom = 1.3 -- the name lands from this scale
CrateMotion.PunchLen = 0.22

local function clamp01(x: number): number return math.clamp(x, 0, 1) end
local function easeOut(u: number, p: number): number return 1 - (1 - u) ^ p end
local function smooth(u: number): number return u * u * (3 - 2 * u) end
local function easeOutBack(u: number, k: number): number
	return 1 + (k + 1) * (u - 1) ^ 3 + k * (u - 1) ^ 2
end
CrateMotion.easeOut = easeOut

-- The crate's own motion at time t: { tilt (radians about its right-left axis: + leans back), roll (radians, side to
-- side), lift (crate heights up) }. Three hops, still between them; a small rock back as the lid is flung open.
-- Calm (Motion.reduced): never moves.
function CrateMotion.shake(t: number, calm: boolean?): { tilt: number, roll: number, lift: number }
	local tilt, roll, lift = 0, 0, 0
	if calm then return { tilt = 0, roll = 0, lift = 0 } end
	local T, up = CrateMotion.T, CrateMotion.HopUp
	for i, at in T.Hops do
		local d = t - at
		if d >= 0 and d < T.HopLen then
			local s = CrateMotion.HopPower[i]
			local side = if i % 2 == 1 then 1 else -1
			local h = CrateMotion.HopLift * s
			if d < up * 0.5 then -- (up fast)
				lift = h * easeOut(d / (up * 0.5), 2)
			elseif d < up then -- (down like a weight)
				lift = h * (1 - ((d - up * 0.5) / (up * 0.5)) ^ 2)
			else -- (a small bounce after the thud)
				lift = h * 0.16 * math.sin(math.pi * (d - up) / (T.HopLen - up))
			end
			local air = math.sin(math.pi * clamp01(d / up))
			local after = if d > up then math.sin(math.pi * (d - up) / (T.HopLen - up)) else 0
			roll = side * s * CrateMotion.HopRoll * (air - 0.25 * after)
			tilt = s * math.rad(2) * air
		end
	end
	local j = (t - T.Crack) / 0.14 -- (the latch pops: a small jolt, down and forward, then still)
	if j > 0 and j < 1 then
		lift -= 0.012 * math.sin(math.pi * j)
		tilt -= math.rad(1.5) * math.sin(math.pi * j)
	end
	local k = (t - T.Open) / 0.35 -- (the lid's weight rocks it back a touch, and it dips)
	if k > 0 and k < 1 then
		tilt += math.rad(2.5) * math.sin(math.pi * k) * (1 - k)
		lift -= 0.012 * math.sin(math.pi * k)
	end
	return { tilt = tilt, roll = roll, lift = lift }
end

-- How far the top is open at time t (radians about the back hinge; 0 = shut): the latch pops it up a little, it
-- holds, then it is flung open like a weight on a spring (fast, about 9% past open, back) and rests open.
CrateMotion.LidZeta, CrateMotion.LidOmega = 0.6, 13
function CrateMotion.lid(t: number): number
	local T = CrateMotion.T
	if t <= T.Crack then return 0 end
	if t < T.Open then return CrateMotion.LidCrack * easeOut(clamp01((t - T.Crack) / T.CrackLen), 3) end
	local tau = t - T.Open
	if tau >= T.OpenLen then return CrateMotion.LidOpen end
	local z, w = CrateMotion.LidZeta, CrateMotion.LidOmega
	local wd = w * math.sqrt(1 - z * z)
	local x = 1 - math.exp(-z * w * tau) * (math.cos(wd * tau) + (z * w / wd) * math.sin(wd * tau))
	local land = smooth(clamp01((tau - 0.7 * T.OpenLen) / (0.3 * T.OpenLen))) -- (rests exactly open at the end)
	x = x * (1 - land) + land
	return CrateMotion.LidCrack + (CrateMotion.LidOpen - CrateMotion.LidCrack) * x
end

-- How much nearer the camera is at time t (1 = where it starts): a slow, smooth push-in up to the reveal, then still.
function CrateMotion.push(t: number, calm: boolean?): number
	if calm then return 1 + CrateMotion.Push end
	return 1 + CrateMotion.Push * smooth(clamp01(t / CrateMotion.T.Reveal))
end

-- The fixed shot (the opening's ViewportFrame fills the screen): straight in front of the crate, a little above,
-- looking down Down; Half = half the screen's height in crate heights at the start, LookY = the point it looks at
-- (crate heights up), low on the crate so the knife has room over it and the words room under it.
CrateMotion.Camera = { Fov = 30, Down = math.rad(12), LookY = 0.28, Half = 1.75 }
-- The camera for a crate `h` studs tall at a push-in `push`: the look point's height, and the eye's height and its
-- distance in front (-Z), all in studs in the crate's own frame (bottom middle at 0).
function CrateMotion.camera(h: number, push: number): (number, number, number)
	local C = CrateMotion.Camera
	local dist = C.Half * h / math.tan(math.rad(C.Fov / 2)) / push
	local look = C.LookY * h
	return look, look + math.sin(C.Down) * dist, -math.cos(C.Down) * dist
end
-- Where a point (crate frame, studs) lands on the screen for that camera: x and y as fractions of the screen (0,0 top
-- left; aspect = width / height), and its depth. (The camera looks along +Z, so screen right is the crate's -X.)
function CrateMotion.project(lookY: number, eyeY: number, eyeZ: number, x: number, y: number, z: number, aspect: number): (number, number, number)
	local fy, fz = lookY - eyeY, -eyeZ
	local n = math.sqrt(fy * fy + fz * fz)
	fy, fz = fy / n, fz / n
	local ry, rz = y - eyeY, z - eyeZ
	local depth = ry * fy + rz * fz
	local up = ry * fz - rz * fy
	local k = math.tan(math.rad(CrateMotion.Camera.Fov / 2))
	return 0.5 + (-x / (depth * k * aspect)) * 0.5, 0.5 - (up / (depth * k)) * 0.5, depth
end

-- The knife at time t: { up (0 = inside the crate .. 1 = its show height), fwd (0 = over the crate's middle .. 1 =
-- in front of it, towards you), spin (radians about its length; 0 = its profile facing you), scale (of its show
-- size), tilt (radians, its lean), seen }. Up out of the crate fast, easing out with a 3% overshoot (a sharp stop
-- that settles), towards you once it is out, a three quarter turn from edge-on to its profile, leaning into a
-- diagonal; then a tiny bob and sway.
function CrateMotion.knife(t: number, calm: boolean?): { up: number, fwd: number, spin: number, scale: number, tilt: number, seen: boolean }
	local T, K = CrateMotion.T, CrateMotion.Knife
	if t < T.Rise then return { up = 0, fwd = 0, spin = 0, scale = 0, tilt = 0, seen = false } end
	if calm then return { up = 1, fwd = 1, spin = 0, scale = 1, tilt = K.Lean, seen = true } end
	local u = clamp01((t - T.Rise) / T.RiseLen)
	local after = math.max(0, t - (T.Rise + T.RiseLen))
	local hover = smooth(clamp01(after / 0.6)) -- (the hover eases in, so it never jolts)
	local up = easeOutBack(u, 0.9) + math.sin(after * 1.7) * 0.012 * hover
	local fwd = easeOut(clamp01((u - 0.2) / 0.8), 3)
	local spin = -2 * math.pi * K.Turn * (1 - easeOut(u, 2.2)) + math.sin(after * 0.8) * math.rad(6) * hover
	return { up = up, fwd = fwd, spin = spin, scale = K.StartScale + (1 - K.StartScale) * easeOut(u, 3), tilt = K.Lean * easeOut(u, 2), seen = true }
end

-- Where the knife's middle is for a knife() pose: (crate heights up from the crate's bottom, crate depths forward of
-- its middle: + is towards the camera).
function CrateMotion.knifeSpot(k: { up: number, fwd: number }): (number, number)
	local K = CrateMotion.Knife
	return K.FromY + (K.ToY - K.FromY) * k.up, K.Forward * k.fwd
end

-- The one light from inside (0 = none .. 1): a thin line of the rarity colour through the gap when the latch pops,
-- held, still there as the lid swings, then gone (0.35 s) so it never sits as a flat slab inside the open crate.
function CrateMotion.spill(t: number): number
	local T = CrateMotion.T
	if t < T.Crack then return 0 end
	return smooth(clamp01((t - T.Crack) / 0.15)) * (1 - smooth(clamp01((t - T.Open - 0.12) / 0.35)))
end

-- The backdrop's rarity colour (0 = the neutral dark .. 1 = its rarity colour behind the knife): it fades in as the
-- lid opens, over TintLen (a fade, never a flash).
function CrateMotion.tint(t: number, calm: boolean?): number
	if calm then return if t >= CrateMotion.T.Rise then 1 else 0 end
	return smooth(clamp01((t - CrateMotion.T.Open) / CrateMotion.T.TintLen))
end

-- How strong the backdrop's rarity colour is by rarity: quieter for the common ones (a pale Common colour washed the
-- whole screen grey), full from Epic up.
CrateMotion.PoolStrength = { Common = 0.5, Uncommon = 0.7, Rare = 0.85 }
function CrateMotion.poolStrength(rarity: string?): number
	return (rarity and CrateMotion.PoolStrength[rarity]) or 1
end

-- The crate's name at the top (0 .. 1 shown): it gives the top of the screen to the knife as the lid opens (critic,
-- Oct 20: it lingered over the knife's tip).
function CrateMotion.title(t: number, calm: boolean?): number
	if calm then return if t >= CrateMotion.T.Rise then 0 else 1 end
	return 1 - smooth(clamp01((t - CrateMotion.T.Open) / 0.3))
end

-- How far the crate has fallen into shadow (0 .. 1 of Dim): as the knife comes out, so only the knife is bright.
function CrateMotion.dim(t: number, calm: boolean?): number
	local T = CrateMotion.T
	if calm then return if t >= T.Rise then 1 else 0 end
	return smooth(clamp01((t - T.Rise - 0.15) / (T.RiseLen - 0.15)))
end

-- The thin light rim round the knife's outline (0 .. 1): it comes up as the knife rises. Light on its edges, never a
-- glow round it.
function CrateMotion.rim(t: number, calm: boolean?): number
	local T = CrateMotion.T
	if calm then return if t >= T.Rise then 1 else 0 end
	return easeOut(clamp01((t - T.Rise) / (T.RiseLen * 0.6)), 2)
end

-- A word landing at time `at`: its scale (PunchFrom down to 1, a hair under, back) and how shown it is (0 .. 1, a
-- quick fade so it never pops in a single frame). Calm: simply there.
function CrateMotion.punch(t: number, at: number, calm: boolean?): (number, number)
	local d = t - at
	if d < 0 then return CrateMotion.PunchFrom, 0 end
	if calm then return 1, 1 end
	local u = clamp01(d / CrateMotion.PunchLen)
	return CrateMotion.PunchFrom + (1 - CrateMotion.PunchFrom) * easeOutBack(u, 1.2), clamp01(d / 0.08)
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

-- A knife whose main colour (its first Config/CoinShop Colors entry) is this dark gets a wider light rim, so a black
-- blade (Hollow Moon, Void Fang) shows its whole shape on the dark backdrop.
CrateMotion.DarkKnife = 0.3
function CrateMotion.isDark(knife: Color3?): boolean
	return knife ~= nil and CrateMotion.luminance(knife) < CrateMotion.DarkKnife
end
-- The rim's width (fraction of the knife's length, each side) and how far its colour is lifted to white from the
-- rarity colour: a thin cool edge for every knife, wider on a dark blade.
function CrateMotion.rimWidth(knife: Color3?): number
	return if CrateMotion.isDark(knife) then 0.016 else 0.009
end
CrateMotion.RimWhite = 0.75

-- His model parts that are glow decorations, not the knife itself: hidden in the opening (owner, Oct 20 07:51: "they
-- have the circle around the knife when it opens, remove it": his knives' aura_ring and aura_shard parts).
function CrateMotion.isAura(name: string): boolean
	return string.sub(string.lower(name), 1, 5) == "aura_"
end

return CrateMotion
