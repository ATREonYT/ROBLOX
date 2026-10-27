---------------------------------------------------------------------------------------------- training stations
-- Shooting-range lanes (the game trains with guns). Each lane keeps the bag stations' frame and themes: a long
-- flat studded mat (7 x 18) in a low two-tone rim with stepped pixel corners and a stamped row of X's on the
-- aisle face. The aisle end of the mat is the shooter's box (the TrainingZone); a waist-high bench marks the
-- firing line; the targets stand in the far half in front of a backstop at the outer end, and from tier 3 a
-- grooved truss gantry (the old gallows' truss) spans the lane over them. Every tier keeps its theme and its
-- effects and adds one new thing, so each lane reads as better than the last:
--   1 stone   a crate stack (3-2-1) with a painted bullseye; soda bottles and cans on a plank shelf
--   2 red     a carnival booth (bulb pillars, striped awning, roof sign); bullseye boards pop up on spring posts (rain)
--   3 lava    a forge with a glowing mouth and a burning chimney; a gong and plates under an L gallows (fire)
--   4 arcane  a billboard on legs (marquee bulbs, spotlights, starburst); a spinner disc, balloons (comets)
--   5 shadow  a pixel arch with a dark neon-lit opening; neon plates, the main one swinging from the keystone
--   6 frost   an ice castle (turrets, battlements, icicles); an ice bullseye on a pillar, ice blocks (snow, sparkles)
--   7 toxic   stacked shipping containers with a hazard sign; a toxic barrel stack with a target face, bottles
--   8 gold    a winners' podium (1-2-3) with a rayed backdrop; a giant trophy (main), the turning crown, gold bottles
-- Every main target's centre sits ~5.8 over the mat, above the shooter's head from the follow camera.
-- Cartoon targets only: bottles, cans, bullseyes, plates, balloons, ice, barrels. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~11.5,
-- labels float to ~16. opts.vfx = false skips effects, opts.tier overrides the tier, opts.labelLift raises the
-- label stack (the lobby staggers neighbouring stacks); opts.side is ignored.
-- Contract (Lobby.client, Shoot.client, LobbyRules): Training_<Id> > TrainingZone (the shooter's box,
-- invisible), Equipment > Targets > Target<i> (Hinge = the pivot part, Swing = the parts that move; attributes
-- Knock = Tip | Swing | Spin | Pop | Shatter | Fly, Hit = the sound it makes, ShardColor, Aim = world centre
-- where shots land, Main on the HitPoint target),
-- Equipment > Gear (stands, fence, gantry), Sign (BillboardGui with Chip + TextLabels Cost, Detail, Power),
-- attributes Tier, HitPoint (the main target's centre), HitColor. Equipment has no Hinge of its own, so
-- nothing sways while you stand there: Shoot.client knocks each target back when a shot lands on it.
local Stations = {}

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (stamped band, studded lip; rimTopMat Neon = a
-- glowing lip without studs); mat: the inset surface; frame (+frameMat): bench, gantry and stands; groove:
-- the stamped X's colour (nil = a darker shade of the face); text: the "xN Power" colour; glow: hit sparks;
-- edge: a thin neon line inside the rim (shadow); labelLift: the label stack sits this much higher (gold's crown). Colours from the bag stations the critics signed off.
-- Tiers 5-7 follow the reference's right row: shadow (x8), frost (x12), toxic (x18).
-- (Oct 27, the owner: "make the colors the same also as the references ... make it feel more cartoony";
-- ref_STILL_training_lanes_superhero.png) every bay is ONE bright hue: the mat in it, the gantry and stands in it, a
-- darker cut of it as the outline rim, a lighter one on the lip. Eight hues like the reference's (grey, red, orange,
-- purple, blue, cyan, green, yellow), each the one its theme's props and effects already suit (the name picks them),
-- so the colour alone tells the bays apart from across the hall.
local function hue(name, base, text)
	return { name = name, rim = base:Lerp(C(0, 0, 0), 0.45), rimTop = base:Lerp(C(255, 255, 255), 0.35), mat = base,
		frame = base:Lerp(C(0, 0, 0), 0.12), groove = base:Lerp(C(0, 0, 0), 0.22), trim = base:Lerp(C(0, 0, 0), 0.45),
		wallCap = base:Lerp(C(255, 255, 255), 0.5), text = text or base:Lerp(C(255, 255, 255), 0.2), glow = base:Lerp(C(255, 255, 255), 0.3) }
end
Stations.Themes = {
	(function() local t = hue('stone', C(150, 158, 178), C(255, 255, 255)) t.glow = C(255, 236, 200) return t end)(), -- BAY 1 x1: grey
	hue('red', C(240, 40, 44), C(255, 80, 80)), -- BAY 2 x4: red (red rain)
	hue('lava', C(255, 134, 22)), -- BAY 3 x10: orange (fire)
	hue('arcane', C(160, 64, 240), C(200, 130, 255)), -- BAY 4 x20: purple
	hue('shadow', C(40, 112, 250), C(110, 170, 255)), -- BAY 5 x35: blue
	hue('frost', C(36, 206, 250)), -- BAY 6 x50: cyan (snow)
	hue('toxic', C(56, 214, 64), C(110, 255, 100)), -- PRO BAY x100: green
	(function() local t = hue('gold', C(255, 214, 24), C(255, 222, 50)) t.trim = C(175, 18, 48) t.labelLift = 0.3 return t end)(), -- GOLD BAY x250: yellow
	-- (B30) 9: the HEAD LANE, the gold lane's kit in a richer cut (a crimson rim under a gold lip, a pale-gold mat) and its
	-- label in the reference's 250x cyan (#2EC8E0, ref_W06.5_train_aisle_endcap_250x.jpg)
	{ name = 'gold', rim = C(178, 22, 52), rimTop = C(255, 222, 60), mat = C(255, 240, 150), frame = C(245, 192, 0), groove = C(214, 160, 30),
		trim = C(175, 18, 48), wallCap = C(255, 244, 200), text = C(46, 200, 224), glow = C(255, 230, 110), labelLift = 0.3 },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.BOX_Z = -3.2 -- the shooter's box runs from the aisle end to here
Stations.BENCH_Z = -2.75 -- the bench's centre line (it is 0.9 deep)
Stations.BENCH_H = 2.3 -- bench top over the mat: waist height, under the held gun
Stations.FIELD_Z0, Stations.FIELD_Z1 = -1.9, 8.4 -- the target field (effects fill it)
Stations.BACK_Z = 8.5 -- the backstop's front face
Stations.GANTRY_Z = 6.4 -- the gantry's centre line (hanging targets hang from it)
Stations.GANTRY_Y = 8.6 -- underside of the gantry beam
Stations.LABEL = V(0, 12.6, 4.4) -- the label stack, over the dummy (B30: about an avatar's height over its head, the reference's)
Stations.Style = 'themed' -- (B31) 'themed': the old themed bays without side walls; 'soldier': B30's soldier pads
Stations.THEMED_LABEL = V(0, 14.4, 3.6) -- the themed bays' label stack, over their gear (as before 39b16b0)
Stations.StampId = '' -- set from HoodVFX.Textures.stamp at build time ('' until the PNG is uploaded)
-- (B35, the owner: "make the layout of the shooting ranges better ... way more optimal") the compact bay: each themed lane
-- is built at its full 20 and then pulled together along its length (Stations.compact) to what shooting needs, 13 deep:
-- the shooter's box shrinks to 3 studs at the bench, and the empty strip between the bench and the targets goes. Pieces
-- in front of `Front1` move back by Front, the bench and its marks (up to `Cut`) by Bench, everything past it forward by
-- Back; a straight piece that spans a cut (the rim, the mat, the box, the effects field) is stretched between its ends.
Stations.Compact = { Front = 3.5, Back = 3.5, Bench = -0.3, Cut = -1.5, Front1 = -7 }
-- (Oct 27, the owner: "make the shooting ranges longer") the bays in the rows keep their full 20; only the head lane,
-- which closes the aisle against the west wall, is still pulled together (CompactOnly).
Stations.CompactOnly = { Head = true }
Stations.LaneHalf = Stations.HALF_Z -- a row bay's half length (10); the lobby lays out on it
Stations.HeadHalf = Stations.HALF_Z - Stations.Compact.Back -- the compact head lane's half length (6.5)

---------------------------------------------------------------------------------------------- stamp and X
-- The groove colour on a face: the theme's own, or the face colour darkened (critic: grooves keep the face's
-- hue, so gold stays lemon and never turns olive).
function Stations.grooveFor(t, base) return t.groove or base:Lerp(C(0, 0, 0), 0.45) end

-- The reference's embossed X on a block face: a Texture tiled every su x sv studs (one X per panel). stamp.png
-- draws the groove in white and Color3 tints it. With no uploaded id the Texture draws nothing in Studio; the
-- offline renderer draws hood/art/vfx/stamp.png (PreviewTexture), and barX cuts the X in geometry meanwhile.
function Stations.stamp(part, faces, su, sv, tint, alpha)
	for _, face in faces do
		local t = Instance.new('Texture')
		t.Name = 'Stamp'
		t.Face = face
		t.Texture = Stations.StampId
		t.StudsPerTileU, t.StudsPerTileV = su or 2, sv or 2
		t.Transparency = 1 - (alpha or 1)
		t.Color3 = tint or part.Color:Lerp(C(0, 0, 0), 0.45)
		t:SetAttribute('PreviewTexture', 'stamp')
		t.Parent = part
	end
end
Stations.SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Before stamp.png is uploaded a Texture draws nothing, so the X is cut in geometry on the faces players see
-- most (the rim's aisle face, the bench front, the backstop front): two thin bars per X, 0.02 proud, in the
-- groove colour. Skipped once the id is set. `cf` is the face centre with -Z out of the face; w x h is one X.
function Stations.barX(c, cf, w, h, color)
	local ang, L = math.atan2(w, h), math.sqrt(w * w + h * h) - 0.08
	for _, dir in { -1, 1 } do
		decor(c:part('StampBar', V(0.12, L, 0.04), cf * CFrame.new(0, 0, -0.01) * CFrame.Angles(0, 0, dir * ang), color, M.SmoothPlastic)).CastShadow = false
	end
end
-- n X's side by side across a face `w` wide and `h` tall centred on `cf` (stamp + geometry fallback).
function Stations.panelX(c, part, cf, w, h, n, tint)
	Stations.stamp(part, { Enum.NormalId.Front }, w / n, h, tint)
	if Stations.StampId == '' then
		for k = 0, n - 1 do Stations.barX(c, cf * CFrame.new(-w / 2 + (k + 0.5) * w / n, 0, 0), w / n - 0.12, h - 0.12, tint) end
	end
end

-- A truss beam along the local +Y of `cf` (cf = centre of the base), len long, w x d thick: a solid beam in the
-- frame colour with thin grooves 0.02 proud (a tie line every `cell` studs and an X in every cell) on the faces
-- listed ('-x', '+x', '-z', '+z' in cf's frame), so from a distance it reads as one solid block.
function Stations.truss(c, name, cf, len, w, d, color, groove, cell, faces, material)
	c:part(name .. 'Core', V(w, len, d), cf * CFrame.new(0, len / 2, 0), color, material)
	local n = math.max(1, math.floor(len / cell + 0.5))
	local seg, g = len / n, 0.16
	for _, f in faces do
		local onX = f:sub(2) == 'x'
		local s = f:sub(1, 1) == '-' and -1 or 1
		local span = (onX and d or w) - 0.24 -- grooves stop short of the corners
		local off = (onX and w or d) / 2 + 0.01
		local L = math.sqrt(span * span + seg * seg)
		local ang = math.atan2(span, seg)
		for k = 0, n do
			local y = math.clamp(k * seg, g / 2 + 0.05, len - g / 2 - 0.05)
			c:part(name .. 'Tie', onX and V(0.04, g, span) or V(span, g, 0.04), cf * CFrame.new(onX and s * off or 0, y, onX and 0 or s * off), groove)
		end
		for k = 0, n - 1 do
			for _, dir in { -1, 1 } do
				local at = CFrame.new(onX and s * off or 0, (k + 0.5) * seg, onX and 0 or s * off)
				local turn = onX and CFrame.Angles(dir * ang, 0, 0) or CFrame.Angles(0, 0, dir * ang)
				c:part(name .. 'Groove', onX and V(0.04, L, g) or V(g, L, 0.04), cf * at * turn, groove)
			end
		end
	end
end

---------------------------------------------------------------------------------------------- shapes
-- Round disc facing -Z (a cylinder lying along the frame's Z): centre `cf`, radius r, thickness th.
function Stations.disc(c, name, cf, r, th, color, material)
	return c:part(name, V(th, 2 * r, 2 * r), cf * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Upright cylinder standing on `pos`.
function Stations.can(c, name, pos, r, h, color, material)
	return c:part(name, V(h, 2 * r, 2 * r), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Bullseye whose back sits on the plane z = 0 of `cf` (facing -Z): rings outer to inner from `colors`, each a
-- little prouder than the last so no two share a face. Returns the outer ring.
function Stations.bullseye(c, cf, r, colors, material)
	local n, outer = #colors, nil
	for i, col in colors do
		local th = 0.08 + 0.035 * i
		local p = Stations.disc(c, 'Ring', cf * CFrame.new(0, 0, 0.02 - th / 2), r * (n - i + 1) / n, th, col, type(material) == 'table' and material[i] or material)
		outer = outer or p
	end
	return outer
end
-- Two squares turned 45 degrees: an eight-point starburst facing -Z, centred on `cf`.
function Stations.starburst(c, cf, s, th, color, material)
	c:part('Burst', V(s, s, th), cf, color, material)
	c:part('Burst', V(s, s, th + 0.02), cf * CFrame.Angles(0, 0, math.pi / 4), color, material)
end
-- Soda bottle (a body with a white label and a coloured stripe, a shoulder, a neck and a cap) standing on `pos`,
-- scale s (1.5 tall). opts: label, stripe, cap colours and the body material.
function Stations.bottle(c, pos, s, color, opts)
	opts = opts or {}
	Stations.can(c, 'Bottle', pos, 0.3 * s, 0.9 * s, color, opts.material)
	Stations.can(c, 'BottleLabel', pos + V(0, 0.22 * s, 0), 0.315 * s, 0.36 * s, opts.label or C(255, 255, 255))
	Stations.can(c, 'BottleStripe', pos + V(0, 0.36 * s, 0), 0.325 * s, 0.07 * s, opts.stripe or color)
	Stations.can(c, 'BottleShoulder', pos + V(0, 0.9 * s, 0), 0.22 * s, 0.16 * s, color, opts.material)
	Stations.can(c, 'BottleNeck', pos + V(0, 1.06 * s, 0), 0.11 * s, 0.34 * s, color, opts.material)
	Stations.can(c, 'BottleCap', pos + V(0, 1.4 * s, 0), 0.14 * s, 0.1 * s, opts.cap or C(255, 255, 255))
	return 1.5 * s
end
-- Soda can (silver lips, a wide white label band) standing on `pos`; r wide, h tall. face: radius of a red and
-- white bullseye sticker on its front (-Z), for the can you are meant to hit.
function Stations.tin(c, pos, r, h, color, band, face)
	Stations.can(c, 'Can', pos, r, h, color)
	Stations.can(c, 'CanLabel', pos + V(0, h * 0.3, 0), r + 0.015, h * 0.4, band or C(255, 255, 255))
	for _, y in { 0, h - 0.07 } do Stations.can(c, 'CanLip', pos + V(0, y, 0), r + 0.03, 0.07, C(214, 220, 230), M.Metal) end
	if face then Stations.bullseye(c, CFrame.new(pos + V(0, h * 0.5, -r - 0.04)), face, { C(230, 50, 50), C(255, 255, 255), C(230, 50, 50) }) end
end
-- Drum (two proud bands and a lid) standing on `pos`.
function Stations.drum(c, pos, r, h, color, band, lid, material)
	Stations.can(c, 'Drum', pos, r, h, color, material)
	for _, y in { 0.22, 0.7 } do Stations.can(c, 'DrumBand', pos + V(0, h * y - 0.09, 0), r + 0.05, 0.18, band) end
	Stations.can(c, 'DrumLid', pos + V(0, h, 0), r - 0.06, 0.06, lid or band)
end
-- Party balloon (an egg, a knot, a shine) with its string down to `foot`.
function Stations.balloon(c, pos, r, color, foot)
	c:blob('Balloon', V(2 * r, 2.3 * r, 2 * r), pos, color, M.SmoothPlastic)
	c:blob('BalloonShine', V(0.5 * r, 0.7 * r, 0.3 * r), pos + V(0.45 * r, 0.5 * r, -0.85 * r), C(255, 255, 255), M.SmoothPlastic)
	c:part('BalloonKnot', V(0.25 * r, 0.25 * r, 0.25 * r), CFrame.new(pos - V(0, 1.2 * r, 0)) * CFrame.Angles(0, 0, math.pi / 4), color)
	if foot then c:bar('BalloonString', pos - V(0, 1.25 * r, 0), foot, 0.06, C(250, 250, 250), M.SmoothPlastic) end
end
-- Easel: two chunky front legs and a back leg on darker feet, under a ledge `y` up that a board stands on.
function Stations.easel(c, x, z, y, w, color)
	local Y = Stations.MAT_Y
	local foot = color:Lerp(C(0, 0, 0), 0.35)
	for _, sx in { -1, 1 } do
		local a = V(x + sx * (w / 2 + 0.3), Y + 0.25, z + 0.2)
		c:bar('EaselLeg', a, V(x + sx * w / 3, y + 0.1, z + 0.12), 0.4, color, M.SmoothPlastic)
		c:box('EaselFoot', a - V(0.32, 0.25, 0.32), a + V(0.32, 0.05, 0.32), foot)
	end
	local back = V(x, Y + 0.25, z + 1.2 + (y - Y) * 0.12)
	c:bar('EaselLeg', back, V(x, y + 0.35, z + 0.2), 0.36, color, M.SmoothPlastic)
	c:box('EaselFoot', back - V(0.3, 0.25, 0.3), back + V(0.3, 0.05, 0.3), foot)
	c:box('EaselLedge', V(x - w / 2 - 0.15, y - 0.25, z - 0.15), V(x + w / 2 + 0.15, y, z + 0.35), color)
end
-- Ice cube: pale glassy block, a snow cap and a white diagonal shine on its front.
function Stations.ice(c, name, cf, s, color)
	local p = c:part(name, V(s, s, s), cf, color or C(170, 236, 255), M.SmoothPlastic)
	p.Transparency, p.Reflectance = 0.12, 0.15
	c:part('IceCap', V(s - 0.12, 0.1, s - 0.12), cf * CFrame.new(0, s / 2 + 0.04, 0), C(250, 254, 255))
	c:part('IceShine', V(0.12, s * 0.7, 0.04), cf * CFrame.new(-s * 0.18, 0, -s / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	return p
end
-- Icicle hanging from `top` (the centre of its top edge): a wedge turned so its triangle faces -Z, wide at
-- the top, its point at the bottom.
function Stations.icicle(c, top, len, w, color)
	return decor(c:wedge('Icicle', V(0.2, len, w), CFrame.new(top - V(0, len / 2, 0)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), color or C(205, 246, 255)))
end
-- Steel plate (square, a hot or neon border and a centre spot) facing -Z, centred on `cf`.
function Stations.plate(c, cf, w, face, edge, edgeMat, spot)
	c:part('Plate', V(w, w, 0.22), cf, face, M.Metal)
	for _, e in { { 0, w / 2 - 0.08, w, 0.16 }, { 0, -w / 2 + 0.08, w, 0.16 }, { w / 2 - 0.08, 0, 0.16, w - 0.32 }, { -w / 2 + 0.08, 0, 0.16, w - 0.32 } } do
		c:part('PlateEdge', V(e[3], e[4], 0.26), cf * CFrame.new(e[1], e[2], -0.03), edge, edgeMat)
	end
	if spot then Stations.disc(c, 'PlateSpot', cf * CFrame.new(0, 0, -0.1), w * 0.2, 0.1, spot, edgeMat) end
end
-- Gold nugget like the reference's: a flat bevelled slab (a low core with sloping wedges round it) with a
-- smaller centred lump on top, lemon gold, never an amber pile.
function Stations.nugget(c, x, z, s, turn)
	local Y, col = Stations.MAT_Y, C(255, 228, 0)
	local cf = CFrame.new(x, Y, z) * CFrame.Angles(0, turn or 0, 0)
	local function lump(at, w, h, d, slope)
		c:part('Nugget', V(w, h, d), at * CFrame.new(0, h / 2, 0), col)
		for k = 0, 3 do
			local len = (k % 2 == 0) and w or d
			local out = (k % 2 == 0) and d / 2 or w / 2
			c:wedge('NuggetSlope', V(len, h, slope), at * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h / 2, -(out + slope / 2)), col)
		end
	end
	lump(cf, 1.3 * s, 0.32 * s, 1.0 * s, 0.4 * s)
	lump(cf * CFrame.new(0, 0.32 * s, 0), 0.75 * s, 0.18 * s, 0.55 * s, 0.25 * s)
end
-- A ring of eight slabs (outer apothem a, slab thickness th, height h) standing on `cf` (the base centre).
function Stations.ring8(c, name, cf, a, th, h, color, material)
	local w = 2 * a * math.tan(math.pi / 8) + 0.02
	for k = 0, 7 do c:part(name, V(w, h, th), cf * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, h / 2, -a + th / 2), color, material) end
end
-- The gold lane's crown on the gantry: a deep-gold band of eight slabs on a white rim, tall and short points
-- (white tips on the tall ones), ruby and sapphire gems round the band; ~2.8 wide, ~1.9 tall. It turns slowly.
function Stations.crown(g, at)
	local cc, crown = g:group('Crown')
	local body, deep, white = C(245, 190, 0), C(222, 150, 0), C(255, 252, 235)
	Stations.ring8(cc, 'CrownRim', at, 1.42, 0.3, 0.22, white)
	Stations.ring8(cc, 'CrownBand', at * CFrame.new(0, 0.2, 0), 1.35, 0.3, 0.75, body)
	for k = 0, 7 do
		local face = at * CFrame.Angles(0, k * math.pi / 4, 0)
		local tall = k % 2 == 0
		local s = tall and 0.78 or 0.52
		local cy = 0.95 + s * 0.25
		cc:part('CrownPoint', V(s, s, 0.24), face * CFrame.new(0, cy, -1.22) * CFrame.Angles(0, 0, math.pi / 4), tall and body or deep)
		if tall then cc:part('CrownTip', V(0.3, 0.3, 0.3), face * CFrame.new(0, cy + s * 0.71, -1.22), white, M.SmoothPlastic, Enum.PartType.Ball) end
		cc:part('CrownGem', V(0.3, 0.3, 0.16), face * CFrame.new(0, 0.58, -1.36) * CFrame.Angles(0, 0, math.pi / 4), tall and C(235, 30, 70) or C(50, 110, 255), M.Glass)
	end
	for _, p in crown:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	crown.WorldPivot = cc:world(at)
	crown:SetAttribute('Spin', 40)
	crown:AddTag('HoodMotion')
	return crown
end
-- A blocky painted digit (seven segments, 1.3 x h) lying on the mat at `z0` (its foot, nearest the aisle),
-- readable from the aisle end: its top points down the lane.
Stations.DIGITS = { [1] = 'bc', [2] = 'abged', [3] = 'abgcd', [4] = 'fgbc', [5] = 'afgcd', [6] = 'afgedc', [7] = 'abc', [8] = 'abcdefg', [9] = 'abcdfg' }
function Stations.digit(c, n, z0, h, color)
	local Y, W, t = Stations.MAT_Y, 1.3, 0.34
	local seg = {
		a = { -W / 2, W / 2, h - t, h }, g = { -W / 2, W / 2, h / 2 - t / 2, h / 2 + t / 2 }, d = { -W / 2, W / 2, 0, t },
		f = { -W / 2, -W / 2 + t, h / 2, h }, e = { -W / 2, -W / 2 + t, 0, h / 2 }, b = { W / 2 - t, W / 2, h / 2, h }, c = { W / 2 - t, W / 2, 0, h / 2 },
	}
	for ch in string.gmatch(Stations.DIGITS[n] or '', '.') do
		local s = seg[ch]
		-- Digit space (u right, v up) seen from the aisle: u = -x, v = z - z0.
		local p = decor(c:box('LaneDigit', V(-s[2], Y, z0 + s[3]), V(-s[1], Y + 0.03, z0 + s[4]), color, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.15
	end
end

---------------------------------------------------------------------------------------------- targets
-- A target the client can knock: Equipment > Targets > Target<i> with a Hinge (the pivot, a ghost part at
-- `pivot`) and a Swing model (build the visible target into the returned context). knock: 'Tip' (tips back about
-- the hinge's X axis with a little hop), 'Swing' (swings on its hanger), 'Spin' (spins about the hinge's Y axis),
-- 'Pop' (bursts into confetti and grows back), 'Shatter' (bursts into shards and grows back), 'Fly' (flies off
-- spinning and pops back). `aim` is where shots land (local), `main` marks the HitPoint target, `hit` names the
-- sound it makes (Ding steel, Tock wood, Glass, Tin, Pop, Ice, Barrel), `shard` colours its shards/confetti.
function Stations.target(k, pivot, aim, knock, main, hit, shard)
	local n = #k.list + 1
	local tc, model = k.targets:group('Target' .. n)
	ghost(tc:part('Hinge', V(0.2, 0.2, 0.2), pivot, P.white))
	local sw = tc:group('Swing')
	model:SetAttribute('Knock', knock)
	model:SetAttribute('Hit', hit or 'Ding')
	if shard then model:SetAttribute('ShardColor', shard) end
	model:SetAttribute('Aim', tc:world(CFrame.new(aim)).Position)
	if main then
		model:SetAttribute('Main', true)
		k.main = model
		k.mainAim = aim
	end
	table.insert(k.list, model)
	return sw, model
end

---------------------------------------------------------------------------------------------- frame pieces
-- The ring the mat sits in: a lower band (its aisle face stamped with a row of X's) under a lighter studded lip
-- (a glowing neon lip on toxic), both with two-step pixel corners.
function Stations.rim(st, t)
	local MX, MZ = Stations.HALF_X - 1, Stations.HALF_Z - 1
	local function ring(name, y0, y1, inset, color, top, material)
		local X, Z = Stations.HALF_X - inset, Stations.HALF_Z - inset
		local bars = {
			{ V(-MX, y0, -Z), V(MX, y1, -MZ), Enum.NormalId.Front }, { V(-MX, y0, MZ), V(MX, y1, Z), Enum.NormalId.Back },
			{ V(-X, y0, -MZ), V(-MX, y1, MZ), Enum.NormalId.Left }, { V(MX, y0, -MZ), V(X, y1, MZ), Enum.NormalId.Right },
		}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do table.insert(bars, { V(sx * MX, y0, sz * MZ), V(sx * (X - 0.5), y1, sz * (Z - 0.5)) }) end
		end
		for _, b in bars do
			local p = st:box(name, b[1], b[2], color, material)
			if top and not material then studs(p) elseif not top and b[3] then Stations.stamp(p, { b[3] }, (y1 - y0) * 2.4, y1 - y0, Stations.grooveFor(t, color)) end
		end
	end
	ring('RimBase', 0, 0.45, 0, t.rim, false)
	ring('Rim', 0.45, Stations.RIM_Y, 0.12, t.rimTop, true, t.rimTopMat)
	-- a glowing strip along the lip's aisle face in the lane's hit colour: the lane's interactive outline, where you
	-- step on (toxic's lip glows already)
	if t.rimTopMat ~= M.Neon then
		decor(st:box('RimGlow', V(-MX + 0.1, 0.47, -Stations.HALF_Z + 0.07), V(MX - 0.1, 0.57, -Stations.HALF_Z + 0.14), t.edge or t.glow, M.Neon)).CastShadow = false
	end
end

-- The shooter's end: a waist-high bench across the lane (a dark kick plate, a stamped front with four X's, a
-- band in the theme's trim colour, a studded top in the lip colour) with an ammo box, a few shells and ear
-- muffs on it; in front of it a yellow and black hazard stripe (the firing line); in the box two shoe prints and
-- (brief 29: no number painted on the mat).
function Stations.bench(st, t, tier)
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	local body = t.frame
	local mat = t.frameMat == M.Neon and M.SmoothPlastic or (t.frameMat or M.SmoothPlastic)
	if t.frameMat == M.Neon then body = t.rim end -- a neon bench would glare: toxic gets its rim green
	local kick = body:Lerp(C(0, 0, 0), 0.35)
	g:box('BenchKick', V(-3.45, Y, z - 0.47), V(3.45, Y + 0.32, z + 0.4), kick)
	local front = g:box('BenchFront', V(-3.4, Y + 0.32, z - 0.42), V(3.4, Y + h - 0.62, z + 0.42), body, mat)
	Stations.panelX(g, front, CFrame.new(0, Y + 0.32 + (h - 0.94) / 2, z - 0.42), 6.8, h - 0.94, 3, Stations.grooveFor(t, body))
	g:box('BenchBand', V(-3.42, Y + h - 0.62, z - 0.46), V(3.42, Y + h - 0.3, z + 0.3), t.trim or t.rimTop, t.trim and M.SmoothPlastic or t.rimTopMat)
	local top = g:box('BenchTop', V(-3.6, Y + h - 0.3, z - 0.62), V(3.6, Y + h, z + 0.5), t.rimTop, t.rimTopMat)
	if not t.rimTopMat then studs(top) end
	local d = st:group('BenchProps')
	local y = Y + h
	-- Ammo box (olive, a yellow stripe and a handle).
	decor(d:box('AmmoBox', V(2.15, y, z - 0.3), V(3.05, y + 0.48, z + 0.22), C(86, 104, 58)))
	decor(d:box('AmmoStripe', V(2.13, y + 0.3, z - 0.32), V(3.07, y + 0.38, z + 0.24), C(250, 200, 40)))
	decor(d:box('AmmoHandle', V(2.45, y + 0.48, z - 0.08), V(2.75, y + 0.56, z), C(40, 44, 40)))
	-- A few brass shells lying about.
	for i, s in { { 1.45, -0.15, 0.3 }, { 1.7, 0.08, 1.4 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(s[1], y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), i == 2 and C(232, 176, 72) or C(244, 194, 80), M.Metal, Enum.PartType.Cylinder))
	end
	-- Ear muffs: two dark cups joined by a yellow band.
	local yellow = C(255, 210, 50)
	for _, sx in { -1, 1 } do
		decor(d:blob('EarCup', V(0.5, 0.55, 0.55), V(-2.6 + sx * 0.42, y + 0.28, z - 0.05), C(50, 52, 60), M.SmoothPlastic))
	end
	decor(d:box('EarArch', V(-3.0, y + 0.5, z - 0.12), V(-2.2, y + 0.64, z + 0.02), yellow)) -- (resting on the cups)
	-- Painted on the mat: the box outline (white on dark mats, the groove colour on pale ones), the hazard
	-- stripe and two shoe prints.
	local m = t.mat
	local pale = 0.299 * m.R + 0.587 * m.G + 0.114 * m.B > 0.7
	local edge = pale and Stations.grooveFor(t, m) or C(250, 250, 245)
	local x0, x1, b0, b1, w = -3.25, 3.25, -8.75, -3.9, 0.14
	for _, b in { { V(x0, Y, b0), V(x1, Y + 0.03, b0 + w) }, { V(x0, Y, b0), V(x0 + w, Y + 0.03, b1) }, { V(x1 - w, Y, b0), V(x1, Y + 0.03, b1) } } do
		local p = decor(st:box('BoxLine', b[1], b[2], edge, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.2
	end
	local fire = decor(st:box('FiringLine', V(-3.5, Y, -3.9), V(3.5, Y + 0.03, -3.5), C(255, 214, 30), M.SmoothPlastic))
	fire.CastShadow = false
	local fg = surface(fire, Enum.NormalId.Top, 20)
	for i = 0, 8 do
		local f = Instance.new('Frame')
		f.Name = 'FiringStripe'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = C(30, 30, 36)
		f.Position, f.Size = UDim2.fromScale((i + 0.2) / 9, 0), UDim2.fromScale(0.5 / 9, 1)
		f.Parent = fg
	end
	for _, sx in { -1, 1 } do
		local x = sx * 0.45
		local sole = decor(st:box('ShoePrint', V(x - 0.3, Y, -5.1), V(x + 0.3, Y + 0.03, -4.0), edge, M.SmoothPlastic))
		sole.CastShadow, sole.Transparency = false, 0.25
	end
	-- (brief 29: no lane number painted on the mat any more; the label says what the lane is)
end

-- The lane's side walls, like the video's lanes walled at the sides (ours hood walls, not sandbags): a low wall on
-- each long side of the rim from just inside the aisle end to the backstop, a dark plinth, the body and a pale
-- studded cap (base, body, cap), a gate pier with a taller cap at the aisle end. Each theme its own wall: brick
-- with a concrete cap (stone), navy block (red), basalt (lava), painted block (arcane), obsidian (shadow), ice with
-- snow (frost), a container's teal steel with a hazard cap (toxic), cream stone on velvet with gold (gold).
-- Walls break round the gantry feet (lanes with a gantry).
Stations.Walls = {
	stone = { body = C(178, 86, 68), base = C(118, 58, 48), cap = C(216, 212, 204), course = C(214, 200, 188), courses = 2 },
	red = { body = C(48, 54, 100), base = C(26, 30, 66), cap = C(240, 62, 86) },
	lava = { body = C(78, 56, 60), base = C(48, 34, 38), cap = C(255, 150, 50) },
	arcane = { body = C(124, 52, 172), base = C(80, 30, 112), cap = C(240, 124, 212) },
	shadow = { body = C(44, 32, 62), base = C(22, 16, 34), cap = C(96, 60, 146) },
	frost = { body = C(150, 222, 248), base = C(30, 110, 210), cap = C(248, 252, 255) },
	toxic = { body = C(26, 72, 66), base = C(14, 42, 40), cap = C(255, 214, 30) },
	gold = { body = C(255, 244, 216), base = C(150, 15, 40), cap = C(255, 214, 40) },
}
Stations.WALL_TOP = 2.55 -- the walls' top over the deck (the bench is 2.7)
function Stations.walls(st, t)
	local w = Stations.Walls[t.name] or Stations.Walls.stone
	local g = st:group('Walls')
	local top, z0, z1 = Stations.WALL_TOP, -8.5, Stations.BACK_Z
	local runs = { { z0 + 0.9, z1 } }
	if t.name ~= 'stone' and t.name ~= 'red' then
		runs = { { z0 + 0.9, Stations.GANTRY_Z - 0.62 }, { Stations.GANTRY_Z + 0.62, z1 } }
	end
	for _, sx in { -1, 1 } do
		local function X(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		for _, r in runs do
			local a0, a1 = X(3.66, 4.5)
			local b0, b1 = X(3.76, 4.42)
			g:box('WallBase', V(a0, Stations.RIM_Y, r[1]), V(a1, 1.0, r[2]), w.base)
			g:box('Wall', V(b0, 1.0, r[1]), V(b1, top - 0.3, r[2]), w.body)
			-- a course line half way up (mortar on brick, a seam on the rest)
			local nc = w.courses or 1
			for k = 1, nc do
				local my = 1.0 + (top - 1.3) * k / (nc + 1)
				decor(g:box('WallCourse', V(b0 - 0.04, my - 0.07, r[1] + 0.05), V(b1 + 0.04, my + 0.07, r[2] - 0.05), w.course or w.base)).CastShadow = false
			end
			studs(g:box('WallCap', V(a0, top - 0.3, r[1]), V(a1, top, r[2]), w.cap))
		end
		-- the gate pier at the aisle end
		local p0, p1 = X(3.62, 4.5)
		g:box('WallPier', V(p0, Stations.RIM_Y, z0), V(p1, top + 0.35, z0 + 0.9), w.base)
		studs(g:box('WallPierCap', V(p0, top + 0.35, z0 - 0.06), V(p1, top + 0.7, z0 + 0.96), w.cap))
	end
	-- a hood prop on the left pier's cap, the lane's own
	local prop = Stations.Hood[t.name]
	if prop then prop(g, CFrame.new(-4.08, top + 0.7, z0 + 0.45)) end
end

-- Small hood props (chunky, a few parts each) standing on `cf` (its top centre of the surface they sit on, -Z out
-- toward the aisle): a traffic cone, a boombox, a milk crate of sodas, a sneaker box, spray cans, a cooler.
Stations.Hood = {}
function Stations.cone(g, cf, color)
	color = color or C(255, 120, 30)
	g:part('ConeFoot', V(0.85, 0.12, 0.85), cf * CFrame.new(0, 0.06, 0), C(40, 40, 46))
	for i, e in { { 0.62, 0.35, color }, { 0.46, 0.3, C(250, 250, 245) }, { 0.32, 0.32, color }, { 0.18, 0.16, color } } do
		local y = 0.12 + (i == 1 and 0 or i == 2 and 0.35 or i == 3 and 0.65 or 0.97)
		g:part('Cone', V(e[1], e[2], e[1]), cf * CFrame.new(0, y + e[2] / 2, 0), e[3])
	end
end
function Stations.boombox(g, cf, body, trim)
	body, trim = body or C(40, 42, 50), trim or C(235, 50, 60)
	g:part('Boombox', V(1.05, 0.55, 0.5), cf * CFrame.new(0, 0.3, 0), body)
	g:part('BoomboxBand', V(1.07, 0.12, 0.52), cf * CFrame.new(0, 0.5, 0), trim)
	local face = CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's axis turned to face -Z, the aisle)
	for _, dx in { -0.27, 0.27 } do
		g:part('BoomboxSpeaker', V(0.06, 0.4, 0.4), cf * CFrame.new(dx, 0.27, -0.26) * face, C(20, 20, 24), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('BoomboxCone', V(0.08, 0.18, 0.18), cf * CFrame.new(dx, 0.27, -0.27) * face, C(150, 156, 170), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	g:part('BoomboxHandle', V(0.8, 0.12, 0.12), cf * CFrame.new(0, 0.72, 0), C(20, 20, 24))
end
function Stations.milkcrate(g, cf, color, sodas)
	g:part('MilkCrate', V(0.86, 0.6, 0.86), cf * CFrame.new(0, 0.3, 0), color)
	g:part('MilkCrateRim', V(0.9, 0.12, 0.9), cf * CFrame.new(0, 0.6, 0), color:Lerp(C(255, 255, 255), 0.25))
	for i, c in sodas or {} do
		local x = (i - (#sodas + 1) / 2) * 0.3
		g:part('Soda', V(0.18, 0.42, 0.18), cf * CFrame.new(x, 0.75, 0.05 * i), c)
		g:part('SodaCap', V(0.1, 0.08, 0.1), cf * CFrame.new(x, 1.0, 0.05 * i), C(250, 250, 245))
	end
end
function Stations.sneakerBox(g, cf, color)
	g:part('ShoeBox', V(0.62, 0.42, 0.98), cf * CFrame.new(0, 0.21, 0), color)
	g:part('ShoeBoxLid', V(0.66, 0.12, 1.02), cf * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(-8)), C(250, 250, 245))
	g:part('Sneaker', V(0.36, 0.22, 0.8), cf * CFrame.new(0.05, 0.65, 0), C(250, 250, 245))
	g:part('SneakerSole', V(0.38, 0.08, 0.82), cf * CFrame.new(0.05, 0.52, 0), color:Lerp(C(0, 0, 0), 0.3))
	g:part('SneakerSwoosh', V(0.37, 0.07, 0.42), cf * CFrame.new(0.05, 0.66, 0.08), color)
end
function Stations.sprayCans(g, cf, colors)
	for i, c in colors do
		local at = cf * CFrame.new((i - 2) * 0.27, 0, (i % 2) * 0.18 - 0.09)
		g:part('SprayCan', V(0.48, 0.24, 0.24), at * CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.pi / 2), c, M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('SprayCap', V(0.12, 0.2, 0.2), at * CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.pi / 2), C(250, 250, 245), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
end
function Stations.cooler(g, cf, color)
	g:part('Cooler', V(0.8, 0.5, 1.0), cf * CFrame.new(0, 0.25, 0), color)
	g:part('CoolerLid', V(0.84, 0.14, 1.04), cf * CFrame.new(0, 0.57, 0), C(250, 250, 245))
	g:part('CoolerHandle', V(0.12, 0.1, 0.6), cf * CFrame.new(0, 0.69, 0), C(40, 44, 54))
end
Stations.Hood.stone = function(g, cf) Stations.cone(g, cf) end
Stations.Hood.red = function(g, cf) Stations.boombox(g, cf) end
Stations.Hood.lava = function(g, cf) Stations.milkcrate(g, cf, C(240, 110, 30), { C(235, 55, 60), C(60, 140, 240) }) end
Stations.Hood.arcane = function(g, cf) Stations.sneakerBox(g, cf, C(240, 90, 180)) end
Stations.Hood.shadow = function(g, cf) Stations.sprayCans(g, cf, { C(160, 80, 255), C(30, 28, 40), C(255, 90, 200) }) end
Stations.Hood.frost = function(g, cf) Stations.cooler(g, cf, C(40, 130, 230)) end
Stations.Hood.toxic = function(g, cf) Stations.milkcrate(g, cf, C(30, 160, 60), { C(60, 220, 90), C(60, 220, 90) }) end
Stations.Hood.gold = function(g, cf) Stations.boombox(g, cf, C(245, 196, 30), C(150, 15, 40)) end

-- The backstop's body: a wall across the outer end with a stepped top (two steps each side, like the rim's
-- pixel corners), its front stamped with X's. Returns the three blocks (base, step, top).
function Stations.wall(c, t, color, material, h, groove)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	h = h or 5.6
	groove = groove or Stations.grooveFor(t, color)
	local base = c:box('Backstop', V(-4.3, 0, z0), V(4.3, Y + h, z1), color, material)
	local step = c:box('BackstopStep', V(-2.9, Y + h, z0 + 0.15), V(2.9, Y + h + 0.8, z1), color, material)
	local top = c:box('BackstopTop', V(-1.5, Y + h + 0.8, z0 + 0.3), V(1.5, Y + h + 1.4, z1), color, material)
	if material ~= M.Neon then
		Stations.panelX(c, base, CFrame.new(0, (Y + h) / 2, z0), 8.6, Y + h, 3, groove)
		-- caps over every exposed top, a lighter tone a little proud of the front (finished edges)
		local cap = t.wallCap or t.trim or t.rimTop
		for _, b in { { -4.36, -2.9, Y + h, z0 - 0.08 }, { 2.9, 4.36, Y + h, z0 - 0.08 }, { -2.96, -1.5, Y + h + 0.8, z0 + 0.07 },
			{ 1.5, 2.96, Y + h + 0.8, z0 + 0.07 }, { -1.56, 1.56, Y + h + 1.4, z0 + 0.22 } } do
			c:box('BackstopCap', V(b[1], b[3], b[4]), V(b[2], b[3] + 0.16, z1 + 0.02), cap, M.SmoothPlastic)
		end
	end
	return base, step, top
end
-- Thin lines along the wall's front: up both sides and along the top edge of each step (trim or neon).
function Stations.wallLines(c, h, color, material, th)
	local Y, z = Stations.MAT_Y, Stations.BACK_Z
	th = th or 0.14
	local lines = {
		{ V(-4.3, 0.6, z - 0.06), V(-4.3 + th, Y + h, z + 0.05) }, { V(4.3 - th, 0.6, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-4.3, Y + h - th, z - 0.06), V(-2.9, Y + h, z + 0.05) }, { V(2.9, Y + h - th, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-2.9, Y + h + 0.8 - th, z + 0.09), V(-1.5, Y + h + 0.8, z + 0.2) }, { V(1.5, Y + h + 0.8 - th, z + 0.09), V(2.9, Y + h + 0.8, z + 0.2) },
		{ V(-1.5, Y + h + 1.4 - th, z + 0.24), V(1.5, Y + h + 1.4, z + 0.35) },
	}
	for _, b in lines do
		local p = decor(c:box('WallLine', b[1], b[2], color, material))
		if material == M.Neon then p.CastShadow = false end
	end
end

-- The truss gantry over the targets: two grooved truss posts on stamped feet at the lane's edges and a grooved
-- truss beam across, capped. Hanging targets hang from its underside (GANTRY_Y) on its centre line. neon: lines
-- on the posts' front edges and under the beam (shadow, gold, frost); look.width (default 0.14) and look.backing
-- (a dark strip 0.34 wide just behind each line, so it reads without bloom on a bright frame).
function Stations.gantry(g, t, neon, look)
	look = look or {}
	local nw, back = look.width or 0.14, look.backing
	local nz0, nz1 = back and 0.49 or 0.47, back and 0.35 or 0.33
	local Y, z, y0 = Stations.MAT_Y, Stations.GANTRY_Z, Stations.GANTRY_Y
	local W = 0.8
	local frame, fm = t.frame, t.frameMat or M.SmoothPlastic
	local groove = Stations.grooveFor(t, frame)
	local foot = frame:Lerp(C(0, 0, 0), 0.12)
	for _, sx in { -1, 1 } do
		local x = sx * 3.9
		Stations.stamp(g:box('GantryFoot', V(x - 0.55, 0.05, z - 0.6), V(x + 0.55, Y + 0.75, z + 0.6), fm == M.Neon and t.rim or foot), Stations.SIDES, 1.1, Y + 0.7, groove)
		Stations.truss(g, 'GantryPost', CFrame.new(x, Y + 0.75, z), y0 - Y - 0.75, W, W, frame, groove, 3.9, { '-z' }, fm)
		g:box('GantryCap', V(x - 0.55, y0 + W, z - 0.55), V(x + 0.55, y0 + W + 0.25, z + 0.55), fm == M.Neon and t.rim or frame)
		-- A small gusset under each end of the beam.
		g:wedge('GantryGusset', V(0.5, 0.8, 0.8), CFrame.new(x - sx * 0.8, y0 - 0.4, z) * CFrame.Angles(0, sx * math.pi / 2, 0), frame, fm)
		if neon then
			for _, ex in { 3.5, 4.3 } do
				if back then decor(g:box('GantryNeonBack', V(sx * ex - 0.17, Y + 0.76, z - 0.47), V(sx * ex + 0.17, y0 + 0.79, z - 0.31), back)).CastShadow = false end
				decor(g:box('GantryNeon', V(sx * ex - nw / 2, Y + 0.8, z - nz0), V(sx * ex + nw / 2, y0 + 0.75, z - nz1), neon, M.Neon)).CastShadow = false
			end
		end
	end
	Stations.truss(g, 'GantryBeam', CFrame.new(-4.35, y0 + W / 2, z) * CFrame.Angles(0, 0, -math.pi / 2), 8.7, W, W, frame, groove, 4.35, { '-z' }, fm)
	if neon then
		if back then decor(g:box('GantryNeonBack', V(-3.55, y0 - 0.17, z - 0.47), V(3.55, y0 + 0.17, z - 0.31), back)).CastShadow = false end
		decor(g:box('GantryNeon', V(-3.5, y0 - nw / 2, z - nz0), V(3.5, y0 + nw / 2, z - nz1), neon, M.Neon)).CastShadow = false
	end
end

-- Hang a target from the gantry's underside at x: two short chains down to the target's top `top`.
function Stations.chains(c, x, top, span)
	local y0 = Stations.GANTRY_Y
	for _, sx in { -1, 1 } do
		c:box('Chain', V(x + sx * span - 0.08, top - 0.05, Stations.GANTRY_Z - 0.08), V(x + sx * span + 0.08, y0 + 0.02, Stations.GANTRY_Z + 0.08), C(52, 54, 66))
	end
	c:box('Hook', V(x - span - 0.15, y0 - 0.14, Stations.GANTRY_Z - 0.15), V(x + span + 0.15, y0, Stations.GANTRY_Z + 0.15), C(52, 54, 66))
end

---------------------------------------------------------------------------------------------- lanes
-- One builder per theme: the backstop's dressing, the stands and the targets. `k` holds st (the station),
-- gear (Equipment > Gear), targets (Equipment > Targets), list, t, tier and burners (parts that get flames).
-- Every main target's centre sits ~5.8 over the mat (local y ~6.2): above the shooter's head from the follow
-- camera, so the thing you shoot is never hidden behind your own avatar.
-- (Oct 27, the owner: "make different shooting ranges, follow same concepts of how you made these, but change them up,
-- make different designs") each bay has its own backstop silhouette and its own kind of target, all built from chunky
-- blocks in the bay's one hue with a dark outline (Stations.chunk), like the reference's frames: a crate stack (stone),
-- a carnival booth (red), a forge with a chimney under a gallows (lava), a billboard on legs (arcane), a pixel arch
-- (shadow), an ice castle (frost), stacked shipping containers (toxic), a winners' podium (gold).
Stations.Lanes = {}
Stations.SODA = { red = C(235, 55, 60), orange = C(255, 150, 30), blue = C(60, 140, 240), lime = C(130, 220, 60) }

-- A chunky block with a dark outline: the box a..b in `color`, and just behind its front face (-Z, toward the aisle) a
-- plate `o` bigger all round in `edge`, so from the aisle and from above the block reads with a thick dark rim, the
-- reference's outlined frames. Returns the block.
function Stations.chunk(c, name, a, b, color, edge, material, o)
	o = o or 0.16
	local p = c:box(name, a, b, color, material)
	c:box(name .. 'Edge', V(a.X - o, math.max(0, a.Y - o), a.Z + 0.08), V(b.X + o, b.Y + o, math.min(b.Z - 0.02, a.Z + 0.4)), edge)
	return p
end
-- A blocky digit standing on a face (seven segments, h tall), `cf` the centre of its foot on the face, -Z out of it:
-- readable from the aisle.
function Stations.faceDigit(c, n, cf, h, color)
	local W, th = h * 0.6, h * 0.2
	local seg = {
		a = { -W / 2, W / 2, h - th, h }, g = { -W / 2, W / 2, h / 2 - th / 2, h / 2 + th / 2 }, d = { -W / 2, W / 2, 0, th },
		f = { -W / 2, -W / 2 + th, h / 2, h }, e = { -W / 2, -W / 2 + th, 0, h / 2 }, b = { W / 2 - th, W / 2, h / 2, h }, c = { W / 2 - th, W / 2, 0, h / 2 },
	}
	for ch in string.gmatch(Stations.DIGITS[n] or '', '.') do
		local s = seg[ch]
		-- (u runs to the viewer's right, which is -x for someone at the aisle looking down the lane)
		decor(c:part('Digit', V(s[2] - s[1], s[4] - s[3], 0.1), cf * CFrame.new(-(s[1] + s[2]) / 2, (s[3] + s[4]) / 2, -0.05), color, M.SmoothPlastic)).CastShadow = false
	end
end

-- 1 Stone (grey): a CRATE STACK, six chunky stamped crates in a 3-2-1 pyramid with a painted bullseye on the top one;
-- soda bottles and cans on a plank shelf in front of it; a crate of spare sodas and a tyre stack.
function Stations.Lanes.stone(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local wood, soda, edge = t.frame, Stations.SODA, t.trim
	local back = k.st:group('Backstop')
	local z1 = Stations.HALF_Z - 0.1
	local crates = {
		{ -4.3, -1.5, 0, Y + 2.6, 8.5 }, { -1.4, 1.4, 0, Y + 2.6, 8.3 }, { 1.5, 4.3, 0, Y + 2.6, 8.6 },
		{ -2.85, -0.05, Y + 2.6, Y + 5.2, 8.75 }, { 0.05, 2.85, Y + 2.6, Y + 5.2, 8.6 },
		{ -1.4, 1.4, Y + 5.2, Y + 7.8, 8.9 },
	}
	for i, b in crates do
		local col = i % 2 == 0 and t.rimTop or t.frame:Lerp(C(0, 0, 0), 0.08)
		local p = Stations.chunk(back, 'Crate', V(b[1], b[3], b[5]), V(b[2], b[4] - 0.3, z1), col, edge)
		studs(back:box('CrateLid', V(b[1] - 0.04, b[4] - 0.3, b[5] - 0.04), V(b[2] + 0.04, b[4], z1), t.wallCap))
		local h = b[4] - 0.3 - b[3]
		Stations.panelX(back, p, CFrame.new((b[1] + b[2]) / 2, b[3] + h / 2, b[5]), b[2] - b[1] - 0.5, h - 0.4, 1, Stations.grooveFor(t, col))
	end
	Stations.bullseye(back, CFrame.new(0, Y + 6.4, 8.86), 1.0, { C(250, 250, 245), C(230, 50, 50), C(250, 250, 245), C(230, 50, 50) })
	-- The shelf: two posts, two rails and a deep top rail at chest height the targets stand on.
	local fz, top = 5.0, Y + 4.4
	for _, sx in { -1, 1 } do Stations.chunk(g, 'FencePost', V(sx * 3.05 - 0.28, Y, fz - 0.28), V(sx * 3.05 + 0.28, top + 0.15, fz + 0.28), wood:Lerp(C(0, 0, 0), 0.15), edge, nil, 0.1) end
	for _, ry in { 1.3, 2.9 } do g:box('FenceRail', V(-3.45, Y + ry, fz - 0.15), V(3.45, Y + ry + 0.35, fz + 0.15), wood) end
	Stations.chunk(g, 'FenceShelf', V(-3.5, top - 0.25, fz - 0.95), V(3.5, top, fz + 0.95), t.rimTop, edge, nil, 0.1)
	-- Targets, left to right: soda bottle, can, the big cola can with a bullseye (main), can, bottle. Bottles
	-- shatter, small cans fly off; the big can rocks back on its back edge and stays (it is the one you shoot
	-- every other shot, so it is always there).
	local items = {
		{ -2.75, 'bottle', soda.orange, 1.25, nil, C(255, 255, 255) }, { -1.5, 'tin', soda.blue, 0.55, 1.25 }, { 0, 'tin', soda.red, 0.88, 2.0, true },
		{ 1.5, 'tin', soda.lime, 0.55, 1.25 }, { 2.75, 'bottle', soda.blue, 1.25, nil, C(255, 214, 40) },
	}
	for _, it in items do
		local base = V(it[1], top, fz)
		local h = it[2] == 'bottle' and 1.5 * it[4] or it[5]
		local bottle = it[2] == 'bottle'
		local main = it[6] == true
		local hinge = main and V(0, 0, it[4]) or V(0, 0, 0.2)
		local sw, model = Stations.target(k, CFrame.new(base + hinge), base + V(0, h / 2, 0), bottle and 'Shatter' or (main and 'Tip' or 'Fly'), main, bottle and 'Glass' or 'Tin', it[3])
		if main then model:SetAttribute('TipMin', 0) end
		if bottle then Stations.bottle(sw, base, it[4], it[3], { stripe = it[3], cap = it[6] })
		else Stations.tin(sw, base, it[4], it[5], it[3], C(255, 255, 255), it[6] and 0.75 or nil) end
	end
	-- Story props: a crate of spare sodas, a stack of old tyres, a can that already fell.
	local crate = Stations.chunk(g, 'Crate', V(-3.3, Y, 1.3), V(-1.7, Y + 1.1, 2.7), t.rimTop, edge, nil, 0.1)
	Stations.stamp(crate, Stations.SIDES, 1.6, 1.1, Stations.grooveFor(t, t.rimTop))
	local colors = { soda.red, soda.orange, soda.blue, soda.lime }
	for n, x in { -2.95, -2.5, -2.05 } do Stations.bottle(g, V(x, Y + 1.1, 1.8 + (n % 2) * 0.45), 0.55, colors[n]) end
	for i, y in { 0, 0.5 } do
		local at = CFrame.new(2.55 + i * 0.12, Y + y + 0.25, 1.9) * CFrame.Angles(0, 0, math.pi / 2)
		g:part('Tyre', V(0.5, 1.7, 1.7), at, C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('TyreHub', V(0.52, 0.8, 0.8), at, C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
	end
	g:part('FallenCan', V(0.95, 0.84, 0.84), CFrame.new(1.2, Y + 0.42, 3.2) * CFrame.Angles(0, 0.6, 0), soda.blue, M.SmoothPlastic, Enum.PartType.Cylinder)
end

-- 2 Red: a CARNIVAL BOOTH, two chunky pillars with lit bulbs under a header with a scalloped red-and-white awning and a
-- round bullseye sign on the roof, a darker red back wall; three bullseye boards pop up on spring posts, the two small
-- ones from a striped counter, the big one (main) from the floor behind it.
function Stations.Lanes.red(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge, white, gold = t.trim, C(250, 250, 245), C(255, 214, 40)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	back:box('BoothBack', V(-3.45, 0, z0 + 0.7), V(3.45, Y + 8.0, z1), t.groove)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 3.4, sx * 4.4), math.max(sx * 3.4, sx * 4.4)
		Stations.chunk(back, 'BoothPillar', V(a, 0, z0), V(b, Y + 8.0, z1), t.frame, edge)
		-- three bulbs up the pillar's front, always lit (nothing blinks)
		for i = 1, 3 do decor(back:part('Bulb', V(0.4, 0.4, 0.4), CFrame.new(sx * 3.9, Y + 1.9 * i, z0 - 0.12), C(255, 240, 190), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	end
	Stations.chunk(back, 'BoothHeader', V(-4.45, Y + 8.0, z0 - 0.9), V(4.45, Y + 9.1, z1), t.mat, edge)
	studs(back:box('BoothRoof', V(-4.45, Y + 9.1, z0 - 0.9), V(4.45, Y + 9.35, z1), t.rimTop))
	-- the awning: eight flaps in turn white and red, each with a stepped (pixel) scallop at its foot
	local fz = z0 - 1.0
	for i = 0, 7 do
		local x = -4.45 + (i + 0.5) * 8.9 / 8
		local col = i % 2 == 0 and white or t.mat
		back:box('Awning', V(x - 0.556, Y + 7.3, fz - 0.1), V(x + 0.556, Y + 8.05, fz + 0.1), col)
		back:box('AwningTip', V(x - 0.34, Y + 6.95, fz - 0.1), V(x + 0.34, Y + 7.3, fz + 0.1), col)
	end
	-- the roof sign: a round bullseye on a short post
	back:box('SignPost', V(-0.25, Y + 9.35, z0 + 0.3), V(0.25, Y + 10.0, z0 + 0.8), edge)
	Stations.disc(back, 'SignBoard', CFrame.new(0, Y + 10.9, z0 + 0.55), 1.2, 0.3, edge)
	Stations.bullseye(back, CFrame.new(0, Y + 10.9, z0 + 0.4), 1.05, { white, t.mat, white, gold })
	-- the counter (striped, studded top) the small boards pop up from
	local cz0, cz1, ch = 3.6, 4.5, Y + 1.5
	Stations.chunk(g, 'Counter', V(-3.8, Y, cz0), V(3.8, ch, cz1), t.frame, edge)
	g:box('CounterStripe', V(-3.84, Y + 0.6, cz0 - 0.04), V(3.84, Y + 0.95, cz1 + 0.04), white)
	studs(g:box('CounterTop', V(-3.9, ch, cz0 - 0.1), V(3.9, ch + 0.2, cz1 + 0.05), t.rimTop))
	local rings = { white, t.mat, white, t.mat, gold }
	-- A spring post: a chunky post with a coil (dark and silver bands) under the board.
	local function spring(x, z, y0, y1)
		Stations.chunk(g, 'SpringPost', V(x - 0.22, y0, z - 0.22), V(x + 0.22, y1 - 0.6, z + 0.22), edge, edge:Lerp(C(0, 0, 0), 0.4), nil, 0.08)
		for i = 0, 2 do g:box('Spring', V(x - 0.3, y1 - 0.6 + i * 0.2, z - 0.3), V(x + 0.3, y1 - 0.48 + i * 0.2, z + 0.3), i % 2 == 0 and C(200, 206, 216) or C(50, 52, 60)) end
	end
	for _, b in { { 0, 6.0, Y, Y + 4.0, 1.78, true }, { -2.55, 4.05, ch + 0.2, ch + 2.1, 1.0 }, { 2.55, 4.05, ch + 0.2, ch + 1.7, 1.0 } } do
		local x, bz, ledge, r = b[1], b[2], b[4], b[5]
		spring(x, bz + 0.3, b[3], ledge)
		local sw = Stations.target(k, CFrame.new(x, ledge, bz + 0.1), V(x, ledge + r, bz), 'Tip', b[6], 'Tock')
		Stations.disc(sw, 'Board', CFrame.new(x, ledge + r, bz + 0.12), r + 0.14, 0.18, edge)
		Stations.bullseye(sw, CFrame.new(x, ledge + r, bz + 0.03), r, rings)
	end
end

-- 3 Lava (orange): a FORGE, a brick furnace with a glowing arched mouth, a stepped left shoulder and a tall chimney on
-- the right that burns at the top; a chunky L-shaped gallows (the reference's frame) hangs a hot gong (main) and a hot
-- plate; a second plate on a post and a burning barrel.
function Stations.Lanes.lava(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge, hot, core, soot = t.trim, C(255, 110, 20), C(255, 225, 90), C(70, 36, 22)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local h = Y + 5.6
	Stations.chunk(back, 'Furnace', V(-4.3, 0, z0), V(4.3, h, z1), t.frame, edge)
	for _, y in { 1.8, 3.6 } do decor(back:box('Course', V(-4.26, Y + y - 0.07, z0 - 0.04), V(4.26, Y + y + 0.07, z0 + 0.1), t.groove)).CastShadow = false end
	studs(back:box('FurnaceCap', V(-4.36, h, z0 - 0.06), V(4.36, h + 0.3, z1), t.rimTop))
	-- the mouth: a dark stepped arch with the fire inside
	back:box('Mouth', V(-1.7, Y + 0.2, z0 - 0.06), V(1.7, Y + 2.7, z0 + 0.3), soot)
	back:box('MouthArch', V(-1.1, Y + 2.7, z0 - 0.06), V(1.1, Y + 3.2, z0 + 0.3), soot)
	decor(back:box('MouthFire', V(-1.35, Y + 0.2, z0 - 0.1), V(1.35, Y + 1.7, z0 + 0.1), hot, M.Neon)).CastShadow = false
	decor(back:box('MouthCoals', V(-1.5, Y + 0.2, z0 - 0.14), V(1.5, Y + 0.6, z0 + 0.1), core, M.Neon)).CastShadow = false
	for _, c in { { -4.2, -2.1, Y + 4.4 }, { 2.3, 4.2, Y + 1.2 } } do
		decor(back:box('LavaCrack', V(c[1], c[3] - 0.08, z0 - 0.08), V(c[2], c[3] + 0.08, z0 + 0.1), hot, M.Neon)).CastShadow = false
	end
	-- the left shoulder and the chimney (it burns at the top: HoodVFX's flames on the coals)
	Stations.chunk(back, 'Shoulder', V(-4.3, h + 0.3, z0 + 0.4), V(-1.4, h + 1.4, z1), t.mat, edge)
	Stations.chunk(back, 'Chimney', V(1.9, h + 0.3, z0 + 0.4), V(3.9, Y + 10.4, z1), t.mat, edge)
	back:box('ChimneyBand', V(1.8, Y + 8.2, z0 + 0.3), V(4.0, Y + 8.5, z1 + 0.04), edge)
	Stations.chunk(back, 'ChimneyTop', V(1.7, Y + 10.4, z0 + 0.25), V(4.1, Y + 10.9, z1), edge, soot)
	local coal = decor(back:part('Coals', V(0.08, 0.9, 0.9), CFrame.new(2.9, Y + 10.93, (z0 + 0.4 + z1) / 2) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
	table.insert(k.burners, coal)
	-- The gallows: a post on a foot at the left edge, an arm across the lane at the gantry's height, a brace.
	local z, top = Stations.GANTRY_Z, Stations.GANTRY_Y
	Stations.chunk(g, 'GallowsFoot', V(-4.45, Y, z - 0.8), V(-3.25, Y + 0.6, z + 0.8), edge, soot, nil, 0.1)
	Stations.chunk(g, 'GallowsPost', V(-4.3, Y + 0.6, z - 0.45), V(-3.4, top + 0.9, z + 0.45), t.frame, edge)
	Stations.chunk(g, 'GallowsArm', V(-3.4, top, z - 0.45), V(3.5, top + 0.9, z + 0.45), t.frame, edge)
	g:box('GallowsCap', V(-4.4, top + 0.9, z - 0.55), V(3.6, top + 1.15, z + 0.55), t.rimTop)
	g:bar('GallowsBrace', V(-3.45, top - 1.7, z), V(-1.9, top + 0.05, z), 0.5, t.frame, M.SmoothPlastic)
	-- Plates: a big round gong (main) and a square plate under the arm.
	local function gong(sw, x, cy, r)
		Stations.disc(sw, 'GongRim', CFrame.new(x, cy, z), r, 0.25, edge)
		Stations.disc(sw, 'GongHot', CFrame.new(x, cy, z - 0.05), r * 0.8, 0.3, hot, M.Neon)
		Stations.disc(sw, 'GongCore', CFrame.new(x, cy, z - 0.1), r * 0.42, 0.34, core, M.Neon)
		Stations.chains(sw, x, cy + r - 0.1, r * 0.45)
	end
	local sw = Stations.target(k, CFrame.new(0, top, z), V(0, 6.2, z), 'Swing', true, 'Ding')
	gong(sw, 0, 6.2, 1.62)
	local s2 = Stations.target(k, CFrame.new(2.5, top, z), V(2.5, 4.9, z), 'Swing', false, 'Ding')
	Stations.plate(s2, CFrame.new(2.5, 4.9, z), 1.3, edge, hot, M.Neon, core)
	Stations.chains(s2, 2.5, 4.9 + 0.65, 0.42)
	-- a plate on a post at the left, in front of the gallows
	g:box('PlatePost', V(-2.6, Y, 4.4), V(-2.2, Y + 2.6, 4.8), edge)
	local s3 = Stations.target(k, CFrame.new(-2.4, Y + 2.6, 4.4), V(-2.4, Y + 3.25, 4.25), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(-2.4, Y + 3.25, 4.25), 1.3, edge, hot, M.Neon, core)
	-- A burning barrel (flames come from HoodVFX on its open top).
	local pos = V(2.9, Y, 2.6)
	Stations.drum(g, pos, 0.62, 1.7, t.frame, edge, soot)
	local coals = decor(g:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
	table.insert(k.burners, coals)
end

-- 4 Arcane (purple): a BILLBOARD up on two legs over a catwalk, marquee bulbs along its top, two spotlights leaning
-- over it, a pale starburst behind a big spinner disc (main) on a post; two balloons to pop and bobbing balloon bunches
-- on the board's top corners.
function Stations.Lanes.arcane(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local edge = t.trim
	local back = k.st:group('Backstop')
	local z0 = Stations.BACK_Z
	local b0, b1 = Y + 3.2, Y + 9.6 -- the board's foot and top
	for _, sx in { -1, 1 } do
		Stations.chunk(back, 'BillboardLeg', V(sx * 2.7 - 0.45, 0, z0 + 0.5), V(sx * 2.7 + 0.45, b0, z0 + 1.35), t.frame, edge)
	end
	studs(back:box('Catwalk', V(-4.4, b0 - 0.3, z0 - 0.3), V(4.4, b0, z0 + 1.35), t.rimTop))
	Stations.chunk(back, 'Billboard', V(-4.4, b0, z0 + 0.3), V(4.4, b1, z0 + 1.2), t.groove, edge, nil, 0.12)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z0 + 0.22), 4.2, 0.16, t.rimTop)
	-- marquee bulbs along the top (always lit) and two spotlights on arms over the board
	for i = 0, 7 do decor(back:part('Bulb', V(0.36, 0.36, 0.36), CFrame.new(-3.85 + i * 1.1, b1 - 0.35, z0 + 0.16), C(255, 240, 200), M.Neon, Enum.PartType.Ball)).CastShadow = false end
	for _, sx in { -1, 1 } do
		back:bar('LampArm', V(sx * 2.9, b1, z0 + 0.8), V(sx * 2.9, b1 + 0.9, z0 - 0.2), 0.22, edge, M.SmoothPlastic)
		local lamp = CFrame.new(sx * 2.9, b1 + 0.75, z0 - 0.5) * CFrame.Angles(math.rad(35), 0, 0)
		back:part('Lamp', V(0.7, 0.6, 0.8), lamp, edge)
		decor(back:part('LampGlow', V(0.5, 0.06, 0.6), lamp * CFrame.new(0, -0.31, 0), C(255, 250, 220), M.Neon)).CastShadow = false
	end
	-- Spinner: a chunky post with a big ringed disc on a hub; it turns slowly and spins when hit.
	local sz = 6.0
	Stations.chunk(g, 'SpinnerPost', V(-0.22, Y, sz + 0.3), V(0.22, Y + 5.8, sz + 0.75), t.frame, edge, nil, 0.1)
	g:box('SpinnerFoot', V(-0.75, Y, sz - 0.2), V(0.75, Y + 0.35, sz + 1.2), edge)
	local sw = Stations.target(k, CFrame.new(0, Y + 5.8, sz), V(0, Y + 5.8, sz), 'Spin', true, 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(0, Y + 5.8, sz + 0.12), 1.8, 0.16, edge)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, sz + 0.03), 1.66, { C(255, 255, 255), C(255, 100, 200), C(255, 255, 255), t.mat, C(255, 220, 60) })
	-- Balloons to pop, tied to little weights.
	for _, b in { { -2.6, 4.4, Y + 4.2, C(255, 90, 170) }, { 2.65, 5.1, Y + 4.9, C(80, 200, 255) } } do
		local pos = V(b[1], b[3], b[2])
		g:box('BalloonWeight', V(b[1] - 0.22, Y, b[2] - 0.22), V(b[1] + 0.22, Y + 0.35, b[2] + 0.22), C(255, 214, 60))
		local s2 = Stations.target(k, CFrame.new(pos), pos, 'Pop', false, 'Pop', b[4])
		Stations.balloon(s2, pos, 0.62, b[4], V(b[1], Y + 0.35, b[2]))
	end
	-- Bunches of three on the board's top corners (they bob; not targets).
	for _, sx in { -1, 1 } do
		local bc, bunch = g:group('BalloonBunch')
		local foot = V(sx * 3.9, b1, z0 + 0.75)
		for i, c in { C(255, 90, 170), C(255, 220, 60), C(120, 220, 255) } do
			local a = (i - 2) * 0.6
			Stations.balloon(bc, foot + V(math.sin(a) * 1.0 - sx * 0.15, 0.95 + math.cos(a) * 0.35, -0.2 * i), 0.6, c, foot)
		end
		for _, p in bunch:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
		bunch.WorldPivot = bc:world(CFrame.new(foot))
		bunch:SetAttribute('Bob', 0.14)
		bunch:SetAttribute('BobPeriod', 2.6 + sx * 0.3)
		bunch:AddTag('HoodMotion')
	end
end

-- 5 Shadow (blue): a PIXEL ARCH, two chunky piers under a stepped lintel and crown with stepped inner corners and a pale
-- keystone, a dark navy void inside, neon along the opening; the main plate (dark, neon rings) swings from a
-- bracket out of the keystone; two square plates on posts.
function Stations.Lanes.shadow(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, dark, void = C(120, 200, 255), C(20, 30, 74), C(12, 20, 54)
	local edge = t.trim
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local open = Y + 7.6 -- the opening's top
	back:box('ArchVoid', V(-2.5, 0, z1 - 0.5), V(2.5, open, z1), void)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 2.5, sx * 4.3), math.max(sx * 2.5, sx * 4.3)
		Stations.chunk(back, 'ArchPier', V(a, 0, z0), V(b, open, z1), t.frame, edge)
		-- the stepped corners of the opening
		local c0, c1 = math.min(sx * 1.6, sx * 2.5), math.max(sx * 1.6, sx * 2.5)
		Stations.chunk(back, 'ArchStep', V(c0, open - 1.0, z0 + 0.1), V(c1, open, z1), t.frame, edge, nil, 0.1)
		decor(back:box('ArchNeon', V(sx * 2.5 - 0.09, Y, z0 - 0.06), V(sx * 2.5 + 0.09, open - 1.0, z0 + 0.04), neon, M.Neon)).CastShadow = false
		decor(back:box('ArchNeon', V(c0, open - 1.09, z0 + 0.04), V(c1, open - 0.91, z0 + 0.14), neon, M.Neon)).CastShadow = false
	end
	-- the lintel and a narrower crown over it (the arch's stepped outer curve), a pale keystone through both
	Stations.chunk(back, 'ArchLintel', V(-4.3, open, z0), V(4.3, open + 0.9, z1), t.frame, edge)
	decor(back:box('ArchNeon', V(-1.6, open - 0.09, z0 + 0.04), V(1.6, open + 0.09, z0 + 0.14), neon, M.Neon)).CastShadow = false
	studs(back:box('ArchCap', V(-4.36, open + 0.9, z0 - 0.06), V(4.36, open + 1.15, z1), t.rimTop))
	Stations.chunk(back, 'ArchCrown', V(-2.9, open + 1.15, z0 + 0.15), V(2.9, open + 1.9, z1), t.frame, edge)
	studs(back:box('ArchCap', V(-2.96, open + 1.9, z0 + 0.09), V(2.96, open + 2.15, z1), t.rimTop))
	Stations.chunk(back, 'Keystone', V(-0.85, open + 0.2, z0 - 0.2), V(0.85, open + 2.9, z1), t.rimTop, edge)
	-- The bracket out of the keystone the main plate hangs from.
	Stations.chunk(g, 'Bracket', V(-0.4, Stations.GANTRY_Y, Stations.GANTRY_Z - 0.4), V(0.4, Stations.GANTRY_Y + 0.8, z0), t.frame, edge, nil, 0.1)
	-- Main: a round dark plate with neon rings.
	local cy, gz = 6.2, Stations.GANTRY_Z
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, gz), V(0, cy, gz), 'Swing', true, 'Ding')
	Stations.disc(sw, 'PlateRim', CFrame.new(0, cy, gz + 0.04), 1.72, 0.2, neon, M.Neon)
	Stations.disc(sw, 'Plate', CFrame.new(0, cy, gz - 0.02), 1.5, 0.26, dark, M.Metal)
	Stations.disc(sw, 'PlateRing', CFrame.new(0, cy, gz - 0.06), 0.95, 0.3, neon, M.Neon)
	Stations.disc(sw, 'PlateInner', CFrame.new(0, cy, gz - 0.1), 0.8, 0.34, dark, M.Metal)
	Stations.disc(sw, 'PlateSpot', CFrame.new(0, cy, gz - 0.14), 0.32, 0.38, neon, M.Neon)
	Stations.chains(sw, 0, cy + 1.62, 0.65)
	-- Two square plates on chunky posts at the sides.
	for _, p in { { -2.6, 4.6, 2.6, 1.3 }, { 2.6, 4.1, 3.2, 1.2 } } do
		Stations.chunk(g, 'PlatePost', V(p[1] - 0.22, Y, p[2] + 0.12), V(p[1] + 0.22, Y + p[3], p[2] + 0.56), t.frame, edge, nil, 0.08)
		local s2 = Stations.target(k, CFrame.new(p[1], Y + p[3], p[2] + 0.1), V(p[1], Y + p[3] + p[4] / 2, p[2]), 'Tip', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], Y + p[3] + p[4] / 2, p[2]), p[4], dark, neon, M.Neon, neon)
	end
end

-- 6 Frost (cyan): an ICE CASTLE, a curtain wall of offset ice blocks with crenellations and icicles between two chunky
-- cyan turrets (white battlements, dark arrow slits, a deep-blue neon snowflake on each); an ice bullseye on a tall ice
-- pillar (main) and ice blocks on pedestals.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, deep = C(248, 252, 255), C(170, 232, 252), C(130, 212, 245), C(25, 120, 235)
	local glow, navy, edge = C(40, 150, 255), C(12, 40, 100), t.trim
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	local wallTop = Y + 5.2
	for row, xs in { { -2.8, -0.95, 0.95, 2.8 }, { -2.8, -1.9, 0, 1.9, 2.8 } } do
		local y0, y1 = row == 1 and 0 or Y + 2.6, row == 1 and Y + 2.6 or wallTop
		for i = 1, #xs - 1 do
			local p = back:box('IceWall', V(xs[i] + 0.03, y0, z0 + 0.3 + ((i + row) % 2) * 0.08), V(xs[i + 1] - 0.03, y1 - 0.04, z1), (i + row) % 2 == 0 and iceA or iceB)
			p.Reflectance = 0.15
		end
	end
	studs(back:box('WallSnow', V(-2.85, wallTop, z0 + 0.25), V(2.85, wallTop + 0.25, z1), snow))
	for _, x in { -2.1, -0.7, 0.7, 2.1 } do studs(back:box('Merlon', V(x - 0.4, wallTop + 0.25, z0 + 0.35), V(x + 0.4, wallTop + 1.05, z1), iceA)) end
	for i = 0, 5 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-2.5 + i * 1.0, wallTop - 0.02, z0 + 0.22), len, 0.34)
	end
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 2.8, sx * 4.4), math.max(sx * 2.8, sx * 4.4)
		Stations.chunk(back, 'Turret', V(a, 0, z0), V(b, Y + 7.6, z1), t.frame, edge)
		studs(back:box('TurretCap', V(a - 0.15, Y + 7.6, z0 - 0.15), V(b + 0.15, Y + 8.1, z1), snow))
		for _, m in { 0.2, 1.05 } do
			local x0 = math.min(sx * (2.8 + m), sx * (2.8 + m + 0.55))
			studs(back:box('Merlon', V(x0, Y + 8.1, z0), V(x0 + 0.55, Y + 8.9, z1), snow))
		end
		back:box('ArrowSlit', V(sx * 3.6 - 0.16, Y + 5.3, z0 - 0.04), V(sx * 3.6 + 0.16, Y + 6.8, z0 + 0.1), navy)
		-- a deep-blue neon snowflake on the turret (six arms, a twin branch on each)
		local fc = CFrame.new(sx * 3.6, Y + 2.9, z0 - 0.08) * CFrame.Angles(0, 0, math.rad(15))
		for a2 = 0, 2 do
			local arm = fc * CFrame.Angles(0, 0, a2 * math.pi / 3)
			decor(back:part('Snowflake', V(1.4, 0.26, 0.1), arm, glow, M.Neon)).CastShadow = false
			for _, s in { -1, 1 } do
				local at = arm * CFrame.new(s * 0.42, 0, -0.01) * CFrame.Angles(0, 0, s * math.pi / 3) * CFrame.new(s * 0.15, 0, 0)
				decor(back:part('Snowflake', V(0.32, 0.18, 0.1), at, glow, M.Neon)).CastShadow = false
			end
		end
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	Stations.chunk(g, 'IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), t.frame, edge, nil, 0.1)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, edge)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, mz + 0.03), 1.72, { snow, deep, snow, deep, C(255, 255, 255) })
	-- Ice blocks on pedestals at the sides.
	for _, b in { { -2.6, 4.5, 2.6, 0.95 }, { 2.6, 5.0, 3.2, 0.9 } } do
		Stations.chunk(g, 'IcePedestal', V(b[1] - 0.5, Y, b[2] - 0.5), V(b[1] + 0.5, Y + b[3] - 0.14, b[2] + 0.5), t.frame, edge, nil, 0.1)
		g:box('IcePedestalCap', V(b[1] - 0.62, Y + b[3] - 0.14, b[2] - 0.62), V(b[1] + 0.62, Y + b[3], b[2] + 0.62), snow)
		local cy = Y + b[3] + b[4] / 2
		-- (Hinged on the block's back edge and never rocking forward, so it tips off its cap, never into it.)
		local s2, block = Stations.target(k, CFrame.new(b[1], Y + b[3], b[2] + 0.6), V(b[1], cy, b[2]), 'Tip', false, 'Ice')
		block:SetAttribute('TipMin', 0)
		Stations.ice(s2, 'IceBlock', CFrame.new(b[1], cy, b[2]) * CFrame.Angles(0, math.rad(b[1] > 0 and 20 or -15), 0), b[4])
	end
end

-- 7 Toxic (green): SHIPPING CONTAINERS, a long ribbed container across the back with locking bars on its doors and a
-- shorter one stacked on it off to the left (a hazard band, a neon drip sign), a hazard diamond on a pole on the free
-- end; a big toxic barrel with a target face on a pallet and two crates (main), green bottles on a shelf, a barrel on
-- the floor and glowing puddles.
function Stations.Lanes.toxic(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, edge, yellow, ink = C(150, 255, 80), t.trim, C(255, 214, 30), C(30, 30, 36)
	local deep = t.trim:Lerp(C(0, 0, 0), 0.25)
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	-- the bottom container
	local h1 = Y + 3.6
	Stations.chunk(back, 'Container', V(-4.4, 0, z0 - 0.3), V(4.4, h1, z1), t.frame, edge)
	for i = 0, 4 do
		local x = -3.7 + i * 1.15
		back:box('Rib', V(x - 0.16, 0.35, z0 - 0.42), V(x + 0.16, h1 - 0.3, z0 - 0.28), t.mat)
	end
	back:box('DoorSeam', V(2.85, 0.3, z0 - 0.36), V(2.95, h1 - 0.25, z0 - 0.28), edge)
	for _, x in { 2.2, 3.6 } do
		back:box('LockBar', V(x - 0.09, 0.4, z0 - 0.5), V(x + 0.09, h1 - 0.35, z0 - 0.3), C(205, 212, 220))
		back:box('LockHandle', V(x - 0.09, Y + 1.3, z0 - 0.62), V(x + 0.34, Y + 1.5, z0 - 0.42), C(205, 212, 220))
	end
	-- the top container, set back and off to the left
	local h2 = h1 + 3.0
	Stations.chunk(back, 'Container', V(-4.2, h1, z0 + 0.15), V(1.5, h2, z1), t.rimTop, edge)
	for i = 0, 3 do
		local x = -3.5 + i * 1.3
		back:box('Rib', V(x - 0.15, h1 + 0.3, z0 + 0.03), V(x + 0.15, h2 - 0.75, z0 + 0.17), t.mat)
	end
	back:box('HazardBand', V(-4.2, h2 - 0.6, z0 + 0.02), V(1.5, h2 - 0.1, z0 + 0.17), yellow)
	for i = 0, 5 do
		decor(back:part('HazardBar', V(0.33, 0.7, 0.05), CFrame.new(-3.75 + i * 0.95, h2 - 0.35, z0 + 0.0) * CFrame.Angles(0, 0, math.rad(40)), ink))
	end
	-- the drip sign on the top container (a neon drop on a dark plate), left of the barrel stack
	local sx, sy = -2.9, h1 + 1.2
	Stations.disc(back, 'SignPlate', CFrame.new(sx, sy, z0 + 0.0), 1.0, 0.14, deep)
	Stations.disc(back, 'Drip', CFrame.new(sx, sy - 0.2, z0 - 0.1), 0.6, 0.14, neon, M.Neon)
	decor(back:part('DripTip', V(0.85, 0.85, 0.14), CFrame.new(sx, sy + 0.14, z0 - 0.1) * CFrame.Angles(0, 0, math.pi / 4), neon, M.Neon))
	-- the hazard diamond on a pole on the bottom container's free end
	local px = 3.0
	back:box('SignPole', V(px - 0.12, h1, z0 + 0.7), V(px + 0.12, h1 + 2.6, z0 + 0.94), edge)
	back:part('HazardSign', V(1.3, 1.3, 0.14), CFrame.new(px, h1 + 3.1, z0 + 0.6) * CFrame.Angles(0, 0, math.pi / 4), yellow)
	back:part('HazardSignMark', V(0.22, 0.6, 0.06), CFrame.new(px, h1 + 3.2, z0 + 0.5), ink)
	back:part('HazardSignDot', V(0.22, 0.22, 0.06), CFrame.new(px, h1 + 2.7, z0 + 0.5), ink)
	-- Main: a big toxic barrel with a target face, on a pallet and two stamped crates.
	local mz = 6.0
	g:box('Pallet', V(-1.05, Y, mz - 1.05), V(1.05, Y + 0.35, mz + 1.05), C(150, 105, 60))
	local crate = Stations.chunk(g, 'Crate', V(-0.95, Y + 0.35, mz - 0.95), V(0.95, Y + 2.35, mz + 0.95), deep, ink, nil, 0.1)
	Stations.stamp(crate, Stations.SIDES, 1.9, 2.0, t.frame)
	local crate2 = g:part('Crate', V(1.6, 1.8, 1.6), CFrame.new(0.05, Y + 3.25, mz) * CFrame.Angles(0, math.rad(8), 0), t.frame)
	Stations.stamp(crate2, Stations.SIDES, 1.6, 1.8, edge)
	local base = Y + 4.15
	local sw, drum = Stations.target(k, CFrame.new(0, base, mz + 0.95), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	drum:SetAttribute('TipMin', 0) -- (rocks back on its back edge, never into the crate)
	Stations.drum(sw, V(0, base, mz), 0.95, 2.5, neon, deep, edge, M.Neon)
	Stations.bullseye(sw, CFrame.new(0, base + 1.25, mz - 1.02), 0.75, { C(255, 255, 255), deep, neon }, { M.SmoothPlastic, M.SmoothPlastic, M.Neon })
	-- Green bottles on a little shelf (they shatter), and a barrel on the floor.
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), edge) end
	Stations.chunk(g, 'Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), t.rimTop, edge, nil, 0.08)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', neon)
		Stations.bottle(s2, b, 0.95, C(90, 220, 110), { label = deep, stripe = neon, material = M.Neon })
	end
	local s3, floorDrum = Stations.target(k, CFrame.new(2.7, Y, 5.26), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	floorDrum:SetAttribute('TipMin', 0)
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, neon, deep, edge, M.Neon)
	-- Glowing puddles on the mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), neon, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane (yellow): a WINNERS' PODIUM, three gold steps (1 in the middle, 2 on the left, 3 on the right)
-- with crimson numbers and cream caps, a tall stepped gold backdrop with rays and a velvet disc behind step 1; a giant
-- gold trophy with a bullseye on its cup (main) stands on step 1, the turning crown on step 2, gold bottles on step 3;
-- a gold plate on a post, lemon nuggets on an amber rug.
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, cream = C(255, 222, 40), C(245, 190, 0), C(255, 252, 235), C(235, 30, 70), C(255, 248, 220)
	local velvet, rays = t.trim, C(255, 238, 130)
	local back = k.st:group('Backstop')
	local z1 = Stations.HALF_Z - 0.1
	-- the backdrop
	Stations.chunk(back, 'Backdrop', V(-2.7, 0, 9.2), V(2.7, Y + 8.6, z1), deep, velvet)
	Stations.chunk(back, 'BackdropTop', V(-1.5, Y + 8.6, 9.35), V(1.5, Y + 9.6, z1), deep, velvet)
	Stations.starburst(back, CFrame.new(0, Y + 6.2, 9.12), 4.4, 0.12, rays)
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 6.2, 9.0), 2.0, 0.14, velvet, M.Fabric)
	back:part('Gem', V(0.55, 0.55, 0.25), CFrame.new(0, Y + 9.1, 9.25) * CFrame.Angles(0, 0, math.pi / 4), ruby, M.Glass)
	-- the steps: { x0, x1, top, front z, number }
	local steps = { { -1.5, 1.5, Y + 3.0, 7.1, 1 }, { -4.4, -1.5, Y + 2.0, 7.5, 2 }, { 1.5, 4.4, Y + 1.2, 7.7, 3 } }
	for _, s in steps do
		Stations.chunk(back, 'Podium', V(s[1], 0, s[4]), V(s[2], s[3], 9.2 + (s[5] == 1 and 0 or 0.7)), s[5] == 1 and gold or deep, velvet)
		studs(back:box('PodiumCap', V(s[1] - 0.05, s[3], s[4] - 0.05), V(s[2] + 0.05, s[3] + 0.25, 9.2 + (s[5] == 1 and 0 or 0.7)), cream))
		local dh = math.min(1.7, s[3] - 0.5)
		Stations.faceDigit(back, s[5], CFrame.new((s[1] + s[2]) / 2, (s[3] - dh) / 2, s[4]), dh, velvet)
	end
	-- Main: the trophy on step 1 (rocks back on its back edge when hit).
	local T, tz = Y + 3.25, 8.15
	local sw, trophy = Stations.target(k, CFrame.new(0, T, 8.8), V(0, T + 2.6, tz - 0.7), 'Tip', true, 'Ding')
	trophy:SetAttribute('TipMin', 0)
	sw:box('TrophyBase', V(-0.95, T, tz - 0.6), V(0.95, T + 0.5, tz + 0.6), velvet)
	sw:box('TrophyStem', V(-0.3, T + 0.5, tz - 0.25), V(0.3, T + 1.2, tz + 0.25), deep)
	sw:box('TrophyKnot', V(-0.55, T + 1.2, tz - 0.35), V(0.55, T + 1.45, tz + 0.35), gold)
	sw:box('TrophyFoot', V(-0.9, T + 1.45, tz - 0.5), V(0.9, T + 1.85, tz + 0.5), deep)
	sw:box('TrophyCup', V(-1.3, T + 1.85, tz - 0.7), V(1.3, T + 3.4, tz + 0.7), gold).Reflectance = 0.15
	sw:box('TrophyRim', V(-1.45, T + 3.4, tz - 0.8), V(1.45, T + 3.7, tz + 0.8), deep)
	for _, sx in { -1, 1 } do
		local a, b = math.min(sx * 1.3, sx * 1.95), math.max(sx * 1.3, sx * 1.95)
		local o0, o1 = math.min(sx * 1.65, sx * 1.95), math.max(sx * 1.65, sx * 1.95)
		sw:box('TrophyHandle', V(a, T + 3.0, tz - 0.15), V(b, T + 3.3, tz + 0.15), deep)
		sw:box('TrophyHandle', V(o0, T + 2.1, tz - 0.15), V(o1, T + 3.0, tz + 0.15), deep)
		sw:box('TrophyHandle', V(a, T + 2.1, tz - 0.15), V(b, T + 2.4, tz + 0.15), deep)
	end
	Stations.bullseye(sw, CFrame.new(0, T + 2.6, tz - 0.72), 0.7, { white, velvet, white, ruby })
	-- The crown turns on step 2; gold bottles stand on step 3 (they shatter).
	Stations.crown(g, CFrame.new(-2.95, Y + 2.25, 8.6))
	for _, x in { 2.35, 3.55 } do
		local b = V(x, Y + 1.45, 8.4)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', gold)
		Stations.bottle(s2, b, 0.95, gold, { label = white, stripe = ruby, cap = ruby })
	end
	-- A gold plate on a post at the front left.
	g:box('PlatePost', V(-2.8, Y, 5.15), V(-2.4, Y + 3.0, 5.55), velvet)
	local s3 = Stations.target(k, CFrame.new(-2.6, Y + 3.0, 5.15), V(-2.6, Y + 3.65, 5.05), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(-2.6, Y + 3.65, 5.05), 1.3, gold, deep, M.SmoothPlastic, white)
	-- An amber rug with a velvet border over the target field (so the lemon nuggets read), and the nuggets on it.
	local rug = studs(g:box('Rug', V(-3.3, Y, 0.4), V(3.3, Y + 0.04, 6.8), C(210, 140, 0)))
	rug.CanCollide = false
	for _, b in { { V(-3.3, Y, 0.4), V(3.3, Y + 0.05, 0.6) }, { V(-3.3, Y, 6.6), V(3.3, Y + 0.05, 6.8) }, { V(-3.3, Y, 0.4), V(-3.1, Y + 0.05, 6.8) }, { V(3.1, Y, 0.4), V(3.3, Y + 0.05, 6.8) } } do
		decor(g:box('RugBorder', b[1], b[2], velvet, M.Fabric)).CastShadow = false
	end
	local d = g:group('Nuggets')
	Stations.nugget(d, -1.9, 1.6, 1.0, 0.4)
	Stations.nugget(d, 1.3, 2.9, 0.9, 1.3)
	Stations.nugget(d, 0.6, 5.6, 0.8, 2.2)
end

-- Floating labels over the targets, the superhero game's training lanes (BRIEF23, ref_lanes_spread.png and
-- ref_training_lanes.png), three rows top to bottom: "Unlocked" (green) or "Locked" (red), small; the rebirth icon and the
-- rebirths the lane needs (a Robux lane: the Robux icon and its price); the big "Nx Power" in the lane's own colour
-- (the theme's text tint) with a dark outline. The words come from Shared/RebirthRules.laneLabel (ECON's Skins.Stations
-- fields: Rebirths, Multiplier, Pass, RobuxPrice). The icon is IconModels.Images.Rebirth / .Robux; until one is uploaded
-- the number's text carries a glyph instead (the Glyph attribute). The client repaints Detail as you rebirth or buy the
-- lane, and Cost and Power from the config (Lobby.client).
-- LOBBY6 (BRIEF24): every row in the references' Montserrat Black with a dark outline. A Robux lane's stack is bigger
-- (16 x 10.4 studs) with its price in lime; the best lane (the highest multiplier, opts.best) also wears a tilted BEST!
-- at its top right.
-- (B30: the lanes stand on a 10.4 pitch now, the soldier plaza's; a stack no wider than its lane's pitch, so neighbours
-- don't run into each other, ref_STILL_lanes_spread_soldier.png; a Robux lane's a little bigger)
Stations.LabelSize, Stations.PromoLabelSize = V(10.2, 6.8, 0), V(11.6, 7.8, 0)
---------------------------------------------------------------------------------------------- the soldier lane
-- (B30, the user: "make it like the references ... how the boxes look etc."; bible 2.2, ref_STILL_1x_lane_pad_zoom.jpg,
-- ref_STILL_lanes_spread_soldier.png, ref_W13.5_south_row_labels_zoom.jpg) Every lane is the soldier game's training
-- pad, in its tier's colour: a chunky studded pad with a stepped, notched edge (the outer rim a shade darker, ragged
-- with blocks that stick out and gaps that don't; an inner raised panel the player stands on, notched at the aisle end),
-- a straw dummy with a bullseye on its chest on a post in a round sandy base near the far end, sandbags piled behind
-- it, a couple of small things lying on the pad (a little ammo chest, a brick, spent shells). No walls, no bench, no
-- gantry: the black silhouettes of the locked lanes read like the reference's. A Robux lane adds a soft gold haze rising
-- off its pad and a glowing halo ring over its dummy's head.
-- Stations.Pads[tier] = { pad, rim } (the reference: 1x terracotta, then a colour per tier; Robux lanes in their own).
Stations.Pads = {
	{ C(204, 94, 43), C(150, 62, 30) }, -- 1 BAY 1 x1: the reference's terracotta
	{ C(156, 160, 176), C(108, 112, 128) }, -- 2 BAY 2 x4: grey
	{ C(120, 174, 214), C(68, 114, 164) }, -- 3 BAY 3 x10: light blue
	{ C(156, 98, 200), C(104, 60, 142) }, -- 4 BAY 4 x20: purple
	{ C(220, 124, 54), C(158, 82, 36) }, -- 5 BAY 5 x35: orange
	{ C(196, 236, 226), C(126, 184, 176) }, -- 6 BAY 6 x50: mint white
	{ C(56, 174, 178), C(32, 118, 122) }, -- 7 PRO BAY x100: teal (Skins)
	{ C(236, 190, 72), C(182, 132, 40) }, -- 8 GOLD BAY x250: gold
	{ C(255, 226, 124), C(178, 22, 52) }, -- 9 HEAD LANE x500: pale gold on crimson
}
Stations.DUMMY_Z = 5.4 -- the dummy's post (z), on its round base
function Stations.soldier(st, k, tier, paid)
	local pad, rim = table.unpack(Stations.Pads[tier] or Stations.Pads[1])
	local HX, HZ, Y = Stations.HALF_X, Stations.HALF_Z, Stations.MAT_Y
	local r = Random.new(tier * 31 + 7)
	-- the rim: a darker studded slab under the whole pad, its edge stepped (blocks out, notches in) along the sides
	local rx, rz = HX - 0.45, HZ - 0.45
	studs(st:box('Rim', V(-rx, 0, -rz + 0.9), V(rx, Y - 0.12, rz), rim, M.Plastic), true)
	-- (B30 final, ref_STILL_1x_lane_pad_zoom: the aisle end steps down and out: a lower studded tongue in the middle, the
	-- corners cut back a stud)
	local tw, to = r:NextNumber(1.9, 2.6), r:NextNumber(-0.5, 0.5)
	studs(st:box('RimTongue', V(to - tw, 0, -rz), V(to + tw, Y - 0.22, -rz + 0.9), rim:Lerp(C(0, 0, 0), 0.1), M.Plastic), true)
	for _, sx in { -1, 1 } do
		local z = -rz + 0.6
		while z < rz - 1.2 do
			local len = r:NextNumber(1.2, 2.6)
			if r:NextNumber() < 0.55 then
				local a, b = sx * (rx - 0.05), sx * (rx + r:NextNumber(0.3, 0.6))
				studs(st:box('RimStep', V(math.min(a, b), 0, z), V(math.max(a, b), Y - 0.2 - r:NextNumber(0, 0.08), math.min(z + len, rz - 0.6)), rim:Lerp(C(0, 0, 0), 0.06), M.Plastic), true)
			end
			z += len + r:NextNumber(0.3, 0.9)
		end
	end
	for _, sz in { -1, 1 } do
		local x = -rx + 0.5
		while x < rx - 1 do
			local len = r:NextNumber(1.0, 2.2)
			if r:NextNumber() < 0.5 then
				local a, b = sz * (rz - 0.05), sz * (rz + r:NextNumber(0.3, 0.6))
				studs(st:box('RimStep', V(x, 0, math.min(a, b)), V(math.min(x + len, rx - 0.5), Y - 0.2 - r:NextNumber(0, 0.08), math.max(a, b)), rim:Lerp(C(0, 0, 0), 0.06), M.Plastic), true)
			end
			x += len + r:NextNumber(0.3, 0.8)
		end
	end
	-- the inner raised panel (where you stand), in two pieces either side of the notch at the aisle end
	local px, pz0, pz1 = HX - 1.15, -HZ + 1.05, HZ - 1.1
	studs(st:box('Mat', V(-px, Y - 0.12, pz0 + 1.0), V(px, Y, pz1), pad, M.Plastic))
	studs(st:box('Mat', V(-px, Y - 0.12, pz0), V(-1.0, Y, pz0 + 1.0), pad, M.Plastic))
	studs(st:box('Mat', V(1.0, Y - 0.12, pz0), V(px, Y, pz0 + 1.0), pad, M.Plastic))
	-- a paler line of blocks along the panel's sides (its stepped edge catching the light)
	for _, sx in { -1, 1 } do
		local a, b = sx * (px - 0.35), sx * px
		st:box('MatEdge', V(math.min(a, b), Y, pz0 + 0.4), V(math.max(a, b), Y + 0.06, pz1 - 0.4), pad:Lerp(P.white, 0.18), M.SmoothPlastic)
	end
	-- the dummy's round sandy base and its post (gear: never moves)
	local dz = Stations.DUMMY_Z
	local sand, sandDark, wood = C(222, 186, 118), C(186, 148, 88), C(92, 64, 40)
	studs(k.gear:part('DummyBase', V(0.28, 2.8, 2.8), CFrame.new(0, Y + 0.14, dz) * CFrame.Angles(0, 0, math.pi / 2), sand, M.Plastic, Enum.PartType.Cylinder))
	k.gear:part('DummyBaseRim', V(0.2, 3.1, 3.1), CFrame.new(0, Y + 0.08, dz) * CFrame.Angles(0, 0, math.pi / 2), sandDark, M.SmoothPlastic, Enum.PartType.Cylinder)
	k.gear:box('DummyPost', V(-0.26, Y + 0.25, dz - 0.26), V(0.26, Y + 3.0, dz + 0.26), wood, M.SmoothPlastic)
	-- the dummy (the target: it sways back on its post when a shot lands): a chunky straw body as wide as a player, a
	-- head, a burlap band, the bullseye on its chest facing the shooter
	local pivot = CFrame.new(0, Y + 2.8, dz)
	local aim = V(0, Y + 4.5, dz - 0.75)
	local sw = Stations.target(k, pivot, aim, 'Swing', true, 'Ding', C(214, 186, 120))
	local straw, strawDark, burlap = C(214, 186, 120), C(176, 146, 84), C(150, 116, 74)
	studs(sw:box('DummyBody', V(-1.25, Y + 3.0, dz - 0.62), V(1.25, Y + 5.8, dz + 0.62), straw, M.Plastic), true)
	sw:box('DummyBand', V(-1.3, Y + 3.0, dz - 0.67), V(1.3, Y + 3.45, dz + 0.67), burlap, M.SmoothPlastic)
	sw:box('DummyShoulders', V(-1.6, Y + 5.2, dz - 0.5), V(1.6, Y + 5.8, dz + 0.5), strawDark, M.SmoothPlastic)
	studs(sw:box('DummyHead', V(-0.72, Y + 5.8, dz - 0.62), V(0.72, Y + 7.15, dz + 0.62), straw, M.Plastic), true)
	sw:box('DummyStraw', V(-0.5, Y + 7.15, dz - 0.4), V(0.5, Y + 7.45, dz + 0.4), strawDark, M.SmoothPlastic)
	Stations.bullseye(sw, CFrame.new(0, Y + 4.5, dz - 0.64), 1.0, { P.white, C(230, 40, 50), P.white, C(230, 40, 50) }, M.SmoothPlastic)
	k.mainAim = aim
	-- sandbags walled behind the dummy (B30 final, ref_STILL_1x_lane_pad_zoom: a pillow wall the pad's width, wrapping its
	-- back corners): a row of five, four on top, two on top of those, and one turned at each back corner
	local bag = C(167, 136, 107)
	local function sandbag(x, y, z, yaw, tone)
		k.gear:at(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)):blob('Sandbag', V(2.1, 1.05, 1.45), V(0, 0, 0), tone, M.SmoothPlastic)
	end
	local bz = HZ - 1.75
	for n = 0, 4 do sandbag(-3.7 + n * 1.85, Y + 0.52, bz + r:NextNumber(-0.12, 0.12), r:NextNumber(-6, 6), n % 2 == 0 and bag or bag:Lerp(P.white, 0.08)) end
	for n = 0, 3 do sandbag(-2.78 + n * 1.85, Y + 1.5, bz + 0.05, r:NextNumber(-8, 8), n % 2 == 1 and bag or bag:Lerp(C(0, 0, 0), 0.06)) end
	for n = 0, 1 do sandbag(-0.93 + n * 1.85, Y + 2.45, bz + 0.1, r:NextNumber(-8, 8), bag:Lerp(P.white, 0.05 * n)) end
	for _, sx in { -1, 1 } do sandbag(sx * (HX - 0.6), Y + 0.52, bz - 1.8, 90 + r:NextNumber(-8, 8), bag:Lerp(C(0, 0, 0), 0.04)) end
	-- (B30 final: the reference's tufts and cactus on the pad, as warehouse debris: a traffic cone and a small crate)
	local side = r:NextNumber() < 0.5 and -1 or 1
	local function prop(p) p.CanCollide, p.CanQuery, p.CastShadow = false, false, false return p end
	local cx0, cz0 = side * (px - 0.75), -HZ + 3.2 + r:NextNumber(0, 1.5)
	prop(k.gear:box('ConeFoot', V(cx0 - 0.5, Y, cz0 - 0.5), V(cx0 + 0.5, Y + 0.14, cz0 + 0.5), C(40, 40, 46), M.SmoothPlastic))
	for n, t in { { 0.38, 0.32, C(240, 110, 30) }, { 0.3, 0.26, P.white }, { 0.22, 0.3, C(240, 110, 30) } } do
		local y0 = Y + 0.14 + (n - 1) * 0.29
		prop(k.gear:post('Cone', t[1], t[2], V(cx0, y0, cz0), t[3], M.SmoothPlastic))
	end
	local bx, bz2 = -side * (px - 0.9), -HZ + 6.5 + r:NextNumber(0, 2)
	prop(k.gear:box('Crate', V(bx - 0.6, Y, bz2 - 0.6), V(bx + 0.6, Y + 1.0, bz2 + 0.6), C(176, 132, 80), M.WoodPlanks))
	prop(k.gear:box('CrateBand', V(bx - 0.62, Y + 0.42, bz2 - 0.62), V(bx + 0.62, Y + 0.58, bz2 + 0.62), C(120, 86, 50), M.SmoothPlastic))
	-- small things on the pad: a little ammo chest, a loose brick, a few spent shells
	local cx, cz = (r:NextNumber() < 0.5 and -1 or 1) * 2.4, 2.2
	k.gear:box('AmmoChest', V(cx - 0.7, Y, cz - 0.45), V(cx + 0.7, Y + 0.7, cz + 0.45), C(96, 112, 64), M.SmoothPlastic)
	k.gear:box('AmmoChestLid', V(cx - 0.74, Y + 0.7, cz - 0.49), V(cx + 0.74, Y + 0.86, cz + 0.49), C(76, 90, 50), M.SmoothPlastic)
	k.gear:box('AmmoChestLatch', V(cx - 0.12, Y + 0.45, cz - 0.52), V(cx + 0.12, Y + 0.75, cz - 0.46), C(214, 186, 92), M.SmoothPlastic)
	k.gear:box('Brick', V(-cx * 0.9 - 0.4, Y, 0.6), V(-cx * 0.9 + 0.4, Y + 0.32, 1.0), C(170, 80, 60), M.SmoothPlastic)
	for n = 1, 3 do
		local sx, szz = r:NextNumber(-2.6, 2.6), r:NextNumber(-1, 3.8)
		k.gear:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(sx, Y + 0.07, szz) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0), C(232, 186, 70), M.SmoothPlastic)
	end
	if paid then
		-- the Robux lane: a soft gold haze rising off the pad, a glowing halo ring over the dummy's head (in the swing, so it
		-- sways with the dummy), and a light
		local hz = ghost(st:box('LaneHaze', V(-px + 0.4, Y, pz0 + 0.6), V(px - 0.4, Y + 0.1, pz1 - 0.6), P.white))
		hz.CastShadow = false
		local e = Instance.new('ParticleEmitter')
		e.Name = 'LaneHaze'
		e.Texture = 'rbxasset://textures/particles/smoke_main.dds'
		e:SetAttribute('PreviewTexture', 'mist')
		e.LightInfluence, e.LightEmission = 0, 0.35
		e.Rate = 3
		e.Lifetime = NumberRange.new(1.8, 2.8)
		e.Speed = NumberRange.new(0.8, 1.6)
		e.SpreadAngle = Vector2.new(10, 10)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = V(0, 0.4, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(0.5, 3.0), NumberSequenceKeypoint.new(1, 3.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.66), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(255, 236, 150), C(255, 196, 50))
		e.ZOffset = -1
		e.Parent = hz
		local l = Instance.new('PointLight')
		l.Color, l.Brightness, l.Range, l.Shadows = C(255, 210, 90), 1, 12, false
		l.Parent = hz
		for n = 0, 7 do
			local a = n * math.pi / 4
			decor(sw:part('Halo', V(0.72, 0.18, 0.22), CFrame.new(math.cos(a) * 0.95, Y + 8.0, dz + math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), C(255, 226, 90), M.Neon)).CastShadow = false
		end
	end
end

function Stations.labelText(s, open)
	local okR, Rules = pcall(function() return require(ReplicatedStorage.Shared.RebirthRules) end)
	if okR and type(Rules) == 'table' and Rules.laneLabel then
		local okL, top, state, power = pcall(Rules.laneLabel, s, open)
		if okL then return top, state, power, Rules.RobuxMark end
	end
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	return paid and RobuxText.fmt(s.RobuxPrice) or tostring(s.Rebirths or 0), open and 'Unlocked' or 'Locked', tostring(s.Multiplier) .. 'x Power', nil
end
-- (brief 29, the user: "floating text with no board, like the reference") Three rows of plain outlined text, no pill and
-- no chip: a small "Locked" (red) / "Unlocked" (green), the rebirth icon with the rebirths the lane needs (a Robux lane:
-- the Robux icon and its price, in lime), and the big "Nx Power" in the lane's own colour. The icon and its number sit
-- as one pair, centred. Names: Icon, Cost, Detail, Power (and Best), so Lobby.client and LabelFade treat it like the rest.
-- (B30, the user: "the fonts ... like the references"; ref_W13.5_south_row_labels_zoom.jpg) The fills: a vertical gradient on
-- every word (the client sets the hue of Locked/Unlocked; the gradient only shades it), the multiplier in its tier's pair.
Stations.TextGrad = {
	white = { C(255, 255, 255), C(217, 222, 232) }, lime = { C(232, 255, 74), C(78, 224, 32) }, -- (B31: TextStyle's white and price presets)
	-- the multiplier's fill per tier (Skins order): x1 white, x4 white, x10 light blue, x20 purple (#B050DF), x35 orange
	-- (#EF7C20), x50 mint white, PRO x100 teal, GOLD x250 gold to orange, HEAD x500 cyan (#2EC8E0)
	tiers = {
		{ C(255, 255, 255), C(206, 210, 222) }, { C(255, 255, 255), C(196, 200, 214) }, { C(200, 240, 255), C(100, 180, 255) },
		{ C(222, 160, 255), C(176, 80, 223) }, { C(255, 196, 110), C(239, 124, 32) }, { C(236, 255, 246), C(160, 236, 210) },
		{ C(170, 250, 250), C(40, 200, 210) }, { C(255, 236, 110), C(255, 150, 30) }, { C(170, 244, 255), C(46, 200, 224) },
	},
}
function Stations.fill(label, pair)
	local g = Instance.new('UIGradient')
	g.Color = ColorSequence.new(pair[1], pair[2])
	g.Rotation = 90
	g.Parent = label
	return g
end
function Stations.labels(st, s, t, at, opts)
	opts = opts or {}
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	local sign = ghost(st:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(at), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
	local size = paid and Stations.PromoLabelSize or Stations.LabelSize
	g.Size = UDim2.fromScale(size.X, size.Y) -- (a lane pitch wide: the row's labels read from the hall's spine)
	g.MaxDistance = paid and 44 or 34 -- (B31 PLAZA, critic 3: a lane's stack reads up close, 24 -> 34 studs, a Robux lane 30 -> 44;
	-- the next lane to open from 65 to 105 (Lobby.client's bands; HoodClient/LabelFade sets MaxDistance itself))
	g:SetAttribute('FadeNear', paid and 30 or 24)
	g:SetAttribute('FadeFar', paid and 44 or 34)
	g.LightInfluence = 0
	g.Parent = sign
	local ink = C(14, 12, 22)
	local function text(name, value, color, x, y, w, h, stroke, grad)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		l.FontFace = FONT.title -- (the references' Montserrat Black)
		l.Text = value
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 1
		local u = Instance.new('UIStroke')
		u.Color, u.Thickness, u.LineJoinMode = ink, stroke, Enum.LineJoinMode.Round
		u.Parent = l
		if grad then Stations.fill(l, grad) end
		l.Parent = g
		return l
	end
	local open = not paid and (s.Rebirths or 0) == 0
	local top, state, power, mark = Stations.labelText(s, open)
	-- the number alone (the icon says what it counts)
	local number = paid and tostring(s.RobuxPrice or '') or tostring(s.Rebirths or 0)
	local okI, icons = pcall(function() return require(ReplicatedStorage.Shared.Models.IconModels) end)
	-- (ROBUX / B31: a Robux lane's price is one string, the Robux sign and the number in the same lime fill and outline)
	local image = not paid and okI and type(icons) == 'table' and icons.Images and icons.Images.Rebirth
	local rowY, rowH = 0.2, 0.27
	-- (a Robux lane: "ONLY <Robux> 99" in lime, the reference's paid lanes; the pair sits right of the word)
	local pairX0 = nil -- (lobby round 1: the price alone, centred, no "ONLY" before it)
	local numberColor = P.white
	local cost
	if type(image) == 'string' and image ~= '' then
		-- the pair: a square icon the row's height, then the number, centred together
		local iconW = rowH * size.Y / size.X
		local numW = 0.085 * math.max(1, #number) + 0.03
		local x0 = pairX0 or (0.5 - (iconW + 0.015 + numW) / 2)
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.BackgroundTransparency = 1
		icon.Image = image
		icon.Position, icon.Size = UDim2.fromScale(x0, rowY), UDim2.fromScale(iconW, rowH)
		local a = Instance.new('UIAspectRatioConstraint')
		a.Parent = icon
		icon.Parent = g
		cost = text('Cost', number, numberColor, x0 + iconW + 0.015, rowY + 0.01, numW, rowH - 0.02, 3, paid and Stations.TextGrad.lime or Stations.TextGrad.white)
		cost.TextXAlignment = Enum.TextXAlignment.Left
		cost:SetAttribute('Glyph', '')
	else
		-- no icon yet: the glyph in the text (the Robux sign Roblox's fonts draw, or the rebirth arrows)
		cost = text('Cost', paid and RobuxText.fmt(s.RobuxPrice) or ('\u{1F504} ' .. number), numberColor, paid and 0.46 or 0.25, rowY + 0.01, paid and 0.4 or 0.5, rowH - 0.02, 3, paid and Stations.TextGrad.lime or Stations.TextGrad.white)
		if paid then cost.TextXAlignment = Enum.TextXAlignment.Left end
		cost:SetAttribute('Glyph', paid and RobuxText.Mark or '\u{1F504}')
	end
	local _ = top
	-- the state word, the smallest (the client sets its hue: salmon Locked, green Unlocked; the gradient shades it)
	text('Detail', state, open and C(40, 235, 90) or C(232, 106, 106), 0.25, 0.02, 0.5, 0.16, 3, { C(255, 255, 255), C(214, 214, 222) })
	-- the multiplier, the biggest, in its tier's gradient
	local tier = 1
	local skins = SKINS or require(ReplicatedStorage.Shared.Config.Skins)
	for i, row in skins.Stations do if row.Id == s.Id then tier = i end end
	local tg = Stations.TextGrad.tiers[math.clamp(tier, 1, #Stations.TextGrad.tiers)]
	if s.Id == 'Head' then tg = Stations.TextGrad.tiers[9] end
	text('Power', power, P.white, 0, 0.5, 1, 0.5, paid and 4 or 3.5, tg)
	if opts.best then
		-- BEST!: plain tilted words over the top right corner (brief 29: no red tag behind them), yellow with a deep red outline
		local best = text('Best', 'BEST!', C(255, 236, 72), 0.72, 0.02, 0.26, 0.17, 3.5)
		best.Rotation = 10
		best:FindFirstChildOfClass('UIStroke').Color = C(110, 10, 20)
	end
	shadowAll(g)
	return sign
end

-- The Robux lanes' promotion (LOBBY6, BRIEF24: "remove the VIP structure over the vip shooting ranges ... and promote
-- it better"; the green x250 lane of ref_training_lanes.png and user_33.png): no gate, no posts, no plate. The lane
-- glows in its own colour like the reference's best lane: a neon frame hugging the rim's foot, a soft halo strip on the
-- floor outside it, bright streaks rising off the whole mat (the reference's rising green streaks) and sparkles in the
-- lane's colour over the target field. Its label (Stations.labels) is the big one, with the Robux icon and price and, on the best
-- lane, BEST!. Built only for a lane with a Pass. Budget: streaks 9/s x ~1.9 s + sparkles 6/s x ~1.7 s, about 27 live
-- particles a lane, all small; no PointLight of its own (the theme's is the one).
function Stations.promo(st, t, s, VFX)
	local g = st:group('Promo')
	local X, Z = Stations.HALF_X, Stations.HALF_Z
	local glow = t.glow or t.text or P.white
	local function frame(name, o, w, h, alpha)
		for _, b in { { V(-X - o - w, 0, -Z - o - w), V(X + o + w, h, -Z - o) }, { V(-X - o - w, 0, Z + o), V(X + o + w, h, Z + o + w) },
			{ V(-X - o - w, 0, -Z - o), V(-X - o, h, Z + o) }, { V(X + o, 0, -Z - o), V(X + o + w, h, Z + o) } } do
			local p = decor(g:box(name, b[1], b[2], glow, M.Neon))
			p.CastShadow, p.Transparency = false, alpha
		end
	end
	-- (B30, the user: "tone down the glow like the reference"; bible M4: a paid lane is its pad's colour and a soft sparkle,
	-- ref_W13.5_train_row_south_25_4_10_100.jpg: no neon frame, no halo, no rising streaks)
	local _ = frame
	local field = ghost(g:box('PromoAuraField', V(-X + 1, Stations.MAT_Y, -Z + 1.2), V(X - 1, Stations.MAT_Y + 0.2, Z - 1.2), P.white))
	field.CastShadow = false
	local function seq(points)
		local k = {}
		for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
		return NumberSequence.new(k)
	end
	local _f, _s = field, seq
	-- sparkles over the target field in the lane's colour
	local box = ghost(g:box('PromoSparkleBox', V(-X + 1, Stations.MAT_Y, -2), V(X - 1, Stations.MAT_Y + 0.2, Z - 1.5), P.white))
	box.CastShadow = false
	local sp = Instance.new('ParticleEmitter')
	sp.Name = 'PromoSparkles'
	sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sp:SetAttribute('PreviewTexture', 'sparkle')
	sp.Color = ColorSequence.new(P.white, glow)
	sp.LightEmission, sp.LightInfluence = 1, 0
	sp.Rate = 6
	sp.Lifetime = NumberRange.new(1.2, 2.2)
	sp.Speed = NumberRange.new(1, 2.4)
	sp.SpreadAngle = Vector2.new(20, 20)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Size = seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } })
	sp.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
	sp.Rotation = NumberRange.new(0, 360)
	sp.Parent = box
	local _ = s
	return g
end

-- Build station `stationId` (a Skins.Stations id; not Ring) in ctx (see the frame above). Returns the model.
function Stations.build(ctx, stationId, opts)
	opts = opts or {}
	local skins = SKINS or require(ReplicatedStorage.Shared.Config.Skins)
	local s = assert(skins.StationById[stationId], 'unknown station ' .. tostring(stationId))
	local tier = opts.tier
	if not tier then
		for i, row in skins.Stations do if row.Id == stationId then tier = i end end
	end
	tier = math.clamp(tier, 1, #Stations.Themes)
	local t = Stations.Themes[tier]
	local vfxModule = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('HoodVFX')
	local okVfx, VFX = pcall(require, vfxModule)
	if not okVfx then VFX = nil end
	Stations.StampId = VFX and VFX.Textures and VFX.Textures.stamp or ''
	local st, model = ctx:group('Training_' .. stationId)
	model:SetAttribute('Theme', t.name)
	model:SetAttribute('Silhouette', true) -- (Lobby.client blacks the whole lane out while it is locked)

	local Y, MX, MZ = Stations.MAT_Y, Stations.HALF_X - 1, Stations.HALF_Z - 1
	local paid = type(s.Pass) == 'string' and s.Pass ~= ''
	local eq, gear, k
	if Stations.Style == 'soldier' then
		-- (B30) the soldier game's training pad (Stations.soldier): the pad, the dummy target, the sandbags, the bits
		local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
		zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
		eq = st:group('Equipment')
		gear = eq:group('Gear')
		k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
		Stations.soldier(st, k, tier, paid)
	else
		-- (B31 LOOK, the user: "bring back the old shooting ranges just with the side barriers removed, they look better")
		-- the themed bays as they were before 39b16b0 ($S/diag_ranges.jpg): the stepped rim, the flat inset mat with its
		-- darker border, the waist-high bench, each theme's kit (Stations.Lanes) and effects. No side walls
		-- (Stations.walls is not built), so a bay is open at both long sides.
		Stations.rim(st, t)
		local mat = st:box('Mat', V(-MX + 0.45, 0, -MZ + 0.45), V(MX - 0.45, Y, MZ - 0.45), t.mat, t.matMat or M.Plastic)
		if mat.Material == M.Plastic then studs(mat) end
		local ring = t.mat:Lerp(C(0, 0, 0), 0.2)
		for _, b in { { V(-MX, 0, -MZ), V(MX, Y, -MZ + 0.45) }, { V(-MX, 0, MZ - 0.45), V(MX, Y, MZ) },
			{ V(-MX, 0, -MZ + 0.45), V(-MX + 0.45, Y, MZ - 0.45) }, { V(MX - 0.45, 0, -MZ + 0.45), V(MX, Y, MZ - 0.45) } } do
			local p = st:box('MatBorder', b[1], b[2], ring, t.matMat or M.Plastic)
			if p.Material == M.Plastic then studs(p) end
		end
		if t.edge then
			for _, b in { { V(-MX, Y, -MZ), V(MX, Y + 0.14, -MZ + 0.08) }, { V(-MX, Y, MZ - 0.08), V(MX, Y + 0.14, MZ) },
				{ V(-MX, Y, -MZ), V(-MX + 0.08, Y + 0.14, MZ) }, { V(MX - 0.08, Y, -MZ), V(MX, Y + 0.14, MZ) } } do
				decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.Neon)).CastShadow = false
			end
		end
		local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
		zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
		Stations.bench(st, t, tier)
		eq = st:group('Equipment')
		gear = eq:group('Gear')
		k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
		local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
		lane(k)
	end
	-- Small things on the gear and every target never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	-- (LOBBY6) the best lane: the highest multiplier of all (Gold Bay, x250) wears BEST! on its label
	local best = true
	for _, row in skins.Stations do
		if row ~= s and (row.Multiplier or 0) >= (s.Multiplier or 0) then best = false end
	end
	local labelAt = Stations.Style == 'soldier' and Stations.LABEL or Stations.THEMED_LABEL
	Stations.labels(st, s, t, labelAt + V(0, (t.labelLift or 0) + (opts.labelLift or 0), 0), { best = best })
	if paid then
		if Stations.Style ~= 'soldier' then Stations.promo(st, t, s, VFX) end
		model:SetAttribute('Pass', s.Pass) -- (a Robux lane: Lobby.client keeps it in colour while locked)
	end
	if best then model:SetAttribute('Best', true) end
	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(k.mainAim or (Stations.Style == 'soldier' and V(0, 4.6, Stations.DUMMY_Z) or V(0, 4.2, 6)))).Position)
	model:SetAttribute('HitColor', t.glow)
	if Stations.Style ~= 'soldier' and opts.vfx ~= false and VFX then
		-- the theme's effects fill the target field (not the shooter's box), from the bench to the backstop
		local z0, z1 = Stations.FIELD_Z0, Stations.FIELD_Z1
		local field = ghost(st:box('Field', V(-MX, Y - 0.05, z0), V(MX, Y, z1), P.white))
		field.CanCollide = false
		local mainPart = k.main and k.main:FindFirstChild('Swing') and k.main.Swing:FindFirstChildWhichIsA('BasePart', true)
		if VFX.theme then
			VFX.theme(field, t.name, V(2 * MX, 10, z1 - z0), { parent = model, tier = tier, color = t.glow, bag = mainPart, burners = k.burners })
		else
			VFX.station(field, tier, t.glow, V(2 * MX, 10, z1 - z0), { parent = model })
		end
	end
	if Stations.Compact and Stations.Style ~= 'soldier' and (not Stations.CompactOnly or Stations.CompactOnly[stationId]) then Stations.compact(model, st:world(CFrame.new())) end
	return model
end

-- Pull a built lane together along its length (Stations.Compact): `frame` is the lane's frame in the world. Moves every
-- part, the models' pivots (the bobbing bunting, the crown) and the world points the client reads (Aim, HitPoint).
function Stations.compact(model, frame)
	local K = Stations.Compact
	local function f(z)
		if z < K.Front1 then return z + K.Front end
		if z < K.Cut then return z + K.Bench end
		return z - K.Back
	end
	local function shiftOf(z) return f(z) - z end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = frame:ToObjectSpace(p.CFrame)
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
			local s = p.Size
			local hz = (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) / 2
			local z0, z1 = rel.Z - hz, rel.Z + hz
			-- which of the part's own axes runs along the lane (only a straight piece is stretched)
			local axis = (math.abs(r20) > 0.999 and 'X') or (math.abs(r21) > 0.999 and 'Y') or (math.abs(r22) > 0.999 and 'Z') or nil
			local spans = axis and z1 - z0 > 2.5 and ((z0 < K.Cut and z1 > K.Cut) or (z0 < K.Front1 and z1 > K.Front1))
			if spans then
				local a, b = f(z0), f(z1)
				if b - a > 0.2 then
					local len = b - a
					p.Size = axis == 'X' and V(len, s.Y, s.Z) or (axis == 'Y' and V(s.X, len, s.Z) or V(s.X, s.Y, len))
					p.CFrame = frame * (CFrame.new(rel.X, rel.Y, (a + b) / 2) * rel.Rotation)
				else
					p.CFrame = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel
				end
			else
				p.CFrame = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel
			end
		end
	end
	for _, m in model:GetDescendants() do
		if m:IsA('Model') then
			local ok, pivot = pcall(function() return m.WorldPivot end)
			if ok and pivot and not m.PrimaryPart then
				local rel = frame:ToObjectSpace(pivot)
				pcall(function() m.WorldPivot = frame * CFrame.new(0, 0, shiftOf(rel.Z)) * rel end)
			end
		end
	end
	for _, inst in { model, table.unpack(model:GetDescendants()) } do
		for _, name in { 'Aim', 'HitPoint' } do
			local v = inst:GetAttribute(name)
			if typeof(v) == 'Vector3' then
				local rel = frame:PointToObjectSpace(v)
				inst:SetAttribute(name, frame:PointToWorldSpace(V(rel.X, rel.Y, f(rel.Z))))
			end
		end
	end
end
