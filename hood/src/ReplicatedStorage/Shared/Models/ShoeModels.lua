-- The 60 shoes of the 10 shoe boxes (Config/Shoes.lua ids), built from plain Parts, wedges, cylinders and balls.
-- Chunky high-top sneakers in the game's classic block style, after the Blender mock-ups in the shoe brief.
-- (brief 21) Plus the 10 exclusive shoes of the two Robux boxes (Exclusive, Grail; Rare..Secret, no Commons): the
-- same kit and accents in premium finishes (chrome, gold, hologram, rainbow) no Cash shoe wears.
--
--   ShoeModels.shoe(id, side, scale) -> Model   one shoe ('L' or 'R'); PrimaryPart `Fit` is an invisible box the size
--                                              of a canonical R15 foot (1, 0.3, 1), centred where the foot goes, toe -Z
--   ShoeModels.pair(id, scale) -> Model        both shoes side by side (displays, followers); PrimaryPart `Root` sits at
--                                              the soles' centre, so the pivot is on the ground between the shoes
--   ShoeModels.wear(character, id, opts?) -> cleanup()
--                                              welds the pair onto an R15 (feet, and the lower legs for the collar) or
--                                              an R6 character (leg bottoms), scaled to the real parts
--   ShoeModels.fx(model, rarity, opts?)        rarity particles and light (optional eye candy, client side)
--   ShoeModels.viewport(id, size?) -> ViewportFrame   the pair, framed like the mock-ups (inventory, chance boards)
--   ShoeModels.Ids (the 60 Cash-box shoes, box by box), ShoeModels.ExclusiveIds (the 10 Robux-box shoes),
--   ShoeModels.AllIds (all 70), ShoeModels.Meta[id] = { Name, Box, Rarity, RarityName, Parts } (all 70),
--   ShoeModels.Rarities
--
-- How a shoe is made: one shared sneaker kit (sole and midsole stripe, toe cap, toe box, inclined lace panel with
-- eyestays, laces and eyelets, quarter and ankle panels, padded collar, tongue, heel counter and tab, side logo,
-- a studded outsole) dressed per shoe by a
-- definition (colours, sole build, panels) and a few accents (wings, flames, crystals, drips, crowns, stars, splats,
-- bubbles, coins...). Every part is authored once for the RIGHT shoe in "foot space" (studs, ground at y = 0, the
-- foot's centre at x = z = 0, outer side +X, toe -Z) and mirrored for the left shoe. Parts are recorded as specs
-- first, so the same shoe can be built anchored (displays) or welded and stretched per axis onto a real foot (wear).
--
-- Fit on a character: the canonical R15 foot is 1 x 0.3 x 1 and both feet touch at the body's centre line, so each
-- shoe hangs over its foot on the OUTER side only (inner faces stay on the foot's inner plane): the two shoes never
-- cut into each other. Parts flagged `shaft` (collar, tongue, ankle panel and what sits on them) ride the lower leg
-- on R15, so the high top doesn't swing through the shin when the ankle bends.
-- Part budget: <= 60 per shoe (a worn or follower pair <= 120). Common ~40, Secret ~60.
local ShoeModels = {}

local V, C = Vector3.new, Color3.fromRGB
local CF, ANG = CFrame.new, CFrame.Angles
local rad = math.rad

local RARITIES = { 'Common', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret' }
ShoeModels.Rarities = RARITIES
-- The disc colours under each pair in the mock-ups (Secret is rainbow; white stands in for it).
ShoeModels.RarityColors = { C(176, 182, 194), C(64, 144, 255), C(168, 96, 255), C(255, 156, 40), C(255, 70, 80), C(255, 255, 255) }
ShoeModels.BoxIds = { 'Street', 'Graffiti', 'Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold' }
local RAINBOW = { C(255, 70, 90), C(255, 170, 40), C(255, 236, 70), C(80, 230, 120), C(60, 190, 255), C(170, 100, 255) }
ShoeModels.Rainbow = RAINBOW

---------------------------------------------------------------------------------------------- palette & materials
local K = {
	white = C(244, 244, 247), snow = C(250, 250, 252), cream = C(238, 234, 226), grey = C(196, 200, 210),
	lining = C(206, 210, 218), ink = C(28, 28, 36), black = C(40, 40, 50), silver = C(200, 206, 216),
	gold = C(255, 196, 52), goldDark = C(214, 150, 30), red = C(222, 40, 48), pink = C(255, 110, 190),
}
ShoeModels.Palette = K
-- Material kinds: Roblox material, reflectance, transparency, casts a shadow.
local KIND = {
	smooth = { Enum.Material.SmoothPlastic, 0, 0, true },
	plastic = { Enum.Material.Plastic, 0, 0, true },
	fabric = { Enum.Material.Fabric, 0, 0, true },
	gloss = { Enum.Material.SmoothPlastic, 0.08, 0, true },
	metal = { Enum.Material.Metal, 0.25, 0, true },
	gold = { Enum.Material.Foil, 0.1, 0, true },
	neon = { Enum.Material.Neon, 0, 0, false },
	glass = { Enum.Material.Glass, 0.15, 0.3, false },
	ice = { Enum.Material.Glass, 0.1, 0.12, false },
}
ShoeModels.Kinds = KIND

local function dark(c, t) return c:Lerp(C(0, 0, 0), t or 0.2) end
local function light(c, t) return c:Lerp(C(255, 255, 255), t or 0.25) end

---------------------------------------------------------------------------------------------- spec builder
-- B collects part specs for the RIGHT shoe. Positions are foot space (ground y = 0). opts.shaft: rides the lower leg.
local Builder = {}
Builder.__index = Builder

local function newBuilder(def)
	return setmetatable({ def = def, list = {} }, Builder)
end
function Builder:add(cls, shape, name, size, cf, color, kind, opts)
	opts = opts or {}
	local spec = {
		cls = cls, shape = shape, name = name, size = size, cf = cf, color = color, kind = kind or 'smooth',
		shaft = opts.shaft or self.shaft, text = opts.text, transp = opts.transp, studsBottom = opts.studsBottom,
	}
	table.insert(self.list, spec)
	return spec
end
function Builder:box(name, size, pos, color, kind, rot, opts)
	return self:add('Part', 'Block', name, size, CF(pos) * (rot or CFrame.identity), color, kind, opts)
end
-- WedgePart: the slope runs from the top of its +Z face down to the bottom of its -Z face.
function Builder:wedge(name, size, pos, color, kind, rot, opts)
	return self:add('WedgePart', nil, name, size, CF(pos) * (rot or CFrame.identity), color, kind, opts)
end
local AXIS = { x = CFrame.identity, y = ANG(0, 0, rad(90)), z = ANG(0, rad(90), 0) }
-- Cylinder along `axis` ('x' | 'y' | 'z', or a CFrame rotation whose X is the axis).
function Builder:cyl(name, length, d, pos, color, kind, axis, opts)
	local r = type(axis) == 'string' and AXIS[axis] or axis or AXIS.x
	return self:add('Part', 'Cylinder', name, V(length, d, d), CF(pos) * r, color, kind, opts)
end
function Builder:ball(name, d, pos, color, kind, opts)
	return self:add('Part', 'Ball', name, V(d, d, d), CF(pos), color, kind, opts)
end
-- A flat isosceles triangle (two wedges back to back): base along local Z, apex up local Y, thickness local X.
-- `cf` places the base centre.
function Builder:tooth(name, base, height, thick, cf, color, kind, opts)
	local a = self:add('WedgePart', nil, name, V(thick, height, base / 2), cf * CF(0, height / 2, -base / 4), color, kind, opts)
	local b = self:add('WedgePart', nil, name, V(thick, height, base / 2), cf * CF(0, height / 2, base / 4) * ANG(0, math.pi, 0), color, kind, opts)
	return a, b
end
-- Run fn with every part flagged as riding the lower leg.
function Builder:onShaft(fn)
	local was = self.shaft
	self.shaft = true
	fn()
	self.shaft = was
end

-- Mirror a right-shoe CFrame into the left shoe (x -> -x). Every primitive used is symmetric in its local X, so the
-- mirrored rotation (M R M) gives the mirror image.
local function mirrorX(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CF(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end
-- Text must not read backwards on the left shoe: mirror it back about its own centre along the face's horizontal.
local function unmirrorText(cf, text)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	if text.face == 'x' then -- side face: flip along z about the text centre
		local zc = text.centre.Z
		return CF(x, y, 2 * zc - z, r00, r01, -r02, r10, r11, -r12, -r20, -r21, r22)
	end
	local xc = -text.centre.X -- front/back face: undo the x mirror about the (mirrored) text centre
	return CF(2 * xc - x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

---------------------------------------------------------------------------------------------- the sneaker kit
-- Layout (right shoe): main pieces keep their inner faces on the foot's inner plane (x = -0.5) and hang out on the
-- outer side. Numbers are studs at scale 1 on a canonical foot.
local L = {
	XI = -0.503, -- inner face of the enclosing pieces (the foot's inner face is x = -0.5)
	XO = 0.655, -- outer face of the quarter panel
	ZT = -0.98, -- sole toe tip
	ZH = 0.645, -- sole heel end
	SOLE = { 0.18, 0.22, 0.24, 0.26, 0.27, 0.3 }, -- sole height by rarity (platforms rise like the pictures)
}
L.XC = (L.XI + L.XO) / 2
ShoeModels.Layout = L

-- Sole: a rounded toe in plan (a vertical cylinder the sole's width) and a square heel; an outsole band from Rare
-- up; the midsole stripe all round. (The toe's circle is placed so the foot's front corners stay inside it.)
local function stadium(B, name, w, h, xc, y, zt, zh, color, kind, studs)
	local r = w / 2
	local zc = zt + r
	B:box(name, V(w, h, zh - zc), V(xc, y, (zc + zh) / 2), color, kind, nil, { studsBottom = studs })
	B:cyl(name .. 'Toe', h - 0.002, w, V(xc, y - 0.001, zc), color, kind, 'y')
end
local function buildSole(B, d, U)
	local XI, XO = L.XI, L.XO
	local x0, x1 = XI - 0.005, XO + 0.035
	local w, xc = x1 - x0, (x0 + x1) / 2
	local zt, zh = L.ZT, L.ZH
	local base = d.base -- outsole band colour (nil = one-piece sole)
	local hb = base and math.min(0.09, U * 0.36) or 0
	local top = U - hb
	stadium(B, 'Sole', w, top, xc, hb + top / 2, zt, zh, d.sole, d.soleKind, not base)
	if base then
		stadium(B, 'Outsole', w + 0.03, hb, xc, hb / 2, zt - 0.015, zh + 0.015, base, d.baseKind, true)
	end
	-- the stripe: a band just proud of the sole all round, near its top; neon from Epic up
	local sh = d.stripeH or (d.rarity >= 4 and 0.055 or 0.04)
	local sy = hb + top * 0.6
	if d.rainbowStripe then
		-- Secret: a rainbow band in segments along the shoe (the toe round in its own colour)
		local sw = w + 0.026
		local zc = zt - 0.013 + sw / 2
		B:cyl('StripeRainbow', sh, sw, V(xc, sy, zc), RAINBOW[(d.rainbowOffset or 0) % #RAINBOW + 1], 'neon', 'y')
		local n = 3
		for i = 1, n do
			local z0 = zc + (zh + 0.013 - zc) * (i - 1) / n
			local z1 = zc + (zh + 0.013 - zc) * i / n
			B:box('StripeRainbow', V(sw + (i % 2) * 0.004, sh + (i % 2) * 0.003, z1 - z0), V(xc, sy, (z0 + z1) / 2), RAINBOW[(i + (d.rainbowOffset or 0)) % #RAINBOW + 1], 'neon')
		end
	else
		stadium(B, 'Stripe', w + 0.026, sh, xc, sy, zt - 0.013, zh + 0.013, d.stripe, d.stripeKind or (d.rarity >= 3 and 'neon' or 'smooth'))
	end
	if d.stripe2 then
		stadium(B, 'Stripe2', w + 0.012, 0.03, xc, hb + 0.03, zt - 0.006, zh + 0.006, d.stripe2, d.stripe2Kind or 'smooth')
	end
end

-- Toe cap, toe box and the laces. In plan the toe is round: a white rubber cap disc, then the coloured toe box, a disc
-- tipped forward so it slopes from the cap up into the ankle. The laces sit on one inclined panel in front of the
-- shin (eyestays either side, a strip of tongue between), crossing over it like a real high-top.
local function buildFront(B, d, U)
	local XC = L.XC
	B:cyl('ToeCap', 0.28, 1.12, V(XC, U + 0.1, L.ZT + 0.025 + 0.56), d.toe, d.toeKind, 'y')
	local tilt = rad(24)
	local tb = CF(XC, U + 0.33, -0.43) * ANG(-tilt, 0, 0)
	B:add('Part', 'Cylinder', 'ToeBox', V(0.16, 1.02, 1.02), tb * AXIS.y, d.toeBox or d.upper, d.upperKind)
	-- slope frame on the toe box's top: local Z up the slope, local Y its normal
	local S = tb * CF(0, 0.08, 0)
	B.slope, B.slopeLen = S * CF(0, 0, -0.42), 0.42
	local ey = d.eyestay or dark(d.upper, 0.14)
	local ek, lk = d.upperKind, d.laceKind
	-- the lace panel (shaft): one inclined panel from the toe box up to the collar, in front of the shin. Eyestays
	-- either side, a strip of tongue between them, laces crossing over it; the tongue stands up above it.
	local lean = rad(27)
	local F0 = CF(XC, U + 0.27, -0.745) * ANG(lean, 0, 0) -- local Y up the panel, local -Z out of it
	local plen = 0.47
	B.lacePanel, B.lacePanelLen = F0, plen
	local hx = 0.27
	B:onShaft(function()
		for _, sx in { -1, 1 } do
			local c = F0 * CF(sx * 0.255, plen / 2, -0.02)
			B:box('Eyestay', V(0.15, plen, 0.1), c.Position, ey, ek, c.Rotation)
		end
		local c = F0 * CF(0, plen / 2, -0.005)
		B:box('TongueStrip', V(0.37, plen, 0.08), c.Position, d.tongue or d.upper, d.tongueKind or d.upperKind, c.Rotation)
		-- the tongue: stands up from behind the panel's top, past the collar
		local tcf = CF(XC, U + 0.76, -0.59) * ANG(rad(-6), 0, 0)
		B:box('Tongue', V(0.46, 0.56, 0.09), tcf.Position, d.tongue or d.upper, d.tongueKind or d.upperKind, tcf.Rotation)
		local lcf = tcf * CF(0, 0.15, -0.05)
		B.tongueFront = tcf * CF(0, 0, -0.045)
		if d.tongueLabel ~= false then
			B:box('TongueLabel', V(0.3, 0.14, 0.02), lcf.Position, d.tongueLabel or d.collar, d.tongueLabelKind or 'smooth', lcf.Rotation)
		end
		-- laces: three eyelet rows, crossed bars between them, a straight bar on top
		local rows = { plen * 0.2, plen * 0.52, plen * 0.84 }
		for i = 1, #rows - 1 do
			local y0, y1 = rows[i], rows[i + 1]
			local ds = y1 - y0
			local l = math.sqrt((2 * hx) ^ 2 + ds * ds) + 0.07
			local a = math.atan2(ds, 2 * hx)
			for j, sgn in { 1, -1 } do
				local cf = F0 * CF(0, (y0 + y1) / 2, -0.095 - (j - 1) * 0.016) * ANG(0, 0, sgn * a)
				B:box('Lace', V(l, 0.11, 0.045), cf.Position, d.lace, lk, cf.Rotation)
			end
		end
		local cf = F0 * CF(0, rows[#rows], -0.103)
		B:box('Lace', V(2 * hx + 0.1, 0.11, 0.045), cf.Position, d.lace, lk, cf.Rotation)
		for _, y in rows do
			for _, sx in { -1, 1 } do
				B:ball('Eyelet', 0.095, (F0 * CF(sx * hx, y, -0.075)).Position, d.eyelet, d.eyeletKind or 'metal')
			end
		end
	end)
end

-- Quarter panel and rounded heel counter (foot); the ankle panel, padded collar, lining and heel tab (shaft). The
-- collar is tipped strongly (high at the heel, low at the front) so the upper's top line falls from the heel to the
-- tongue: the classic high-top silhouette, with the shin coming out of the opening.
L.TILT = -7
L.COLLAR_Y = 0.86 -- collar centre height above the sole top (at the opening's middle)
local function buildUpper(B, d, U)
	local XI, XO, XC = L.XI, L.XO, L.XC
	-- quarter: the low body round the foot
	B:box('Quarter', V(XO - XI, 0.42, 1.12), V(XC, U + 0.21, -0.06), d.upper, d.upperKind)
	-- heel counter: the back panel, its own tone
	B:box('HeelCounter', V(XO - XI + 0.014, 0.46, 0.17), V(XC, U + 0.23, 0.56), d.heel or dark(d.upper, 0.22), d.heelKind or d.upperKind)
	-- the collar frame: tipped about the opening's middle
	local cy = U + L.COLLAR_Y
	local pivot = V(0, cy, 0.035)
	local T = CF(pivot) * ANG(rad(L.TILT), 0, 0) * CF(-pivot)
	B.T = T
	local function at(x, y, z) return T * CF(x, y, z) end
	local slope = math.tan(rad(-L.TILT))
	B:onShaft(function()
		-- the ankle panel wraps the shin (a second tone of the upper). Its top is the floor of the shoe's opening; the
		-- back wall and two side wedges rise from it to the tipped collar, so the opening is a real (shaded) hollow.
		local ax0, ax1 = XI - 0.004, XO + 0.016
		local ac = d.ankle or d.upper
		local ak = d.ankleKind or d.upperKind
		local depth, zc = 1.135, 0.06
		local zb0, zb1 = zc - depth / 2, zc + depth / 2
		local yfloor = cy + (zb0 - pivot.Z) * slope - 0.1
		local ybot = U + 0.26
		B:box('Ankle', V(ax1 - ax0, yfloor - ybot, depth), V((ax0 + ax1) / 2, (yfloor + ybot) / 2, zc), ac, ak)
		local rise = slope * depth + 0.06
		B:wedge('AnkleWall', V(ax1 - 0.5, rise, depth), V((ax1 + 0.5) / 2, yfloor + rise / 2, zc), ac, ak)
		B:wedge('AnkleWall', V(0.09, rise, depth), V(ax0 + 0.045, yfloor + rise / 2, zc), ac, ak)
		B:box('AnkleBack', V(ax1 - ax0 - 0.002, rise + 0.02, zb1 - 0.5), V((ax0 + ax1) / 2, yfloor + (rise + 0.02) / 2, (zb1 + 0.5) / 2), ac, ak)
		-- lining: the floor of the hollow, dark (inside the shin when worn)
		B:box('Lining', V(0.9, 0.02, 0.96), V(0.0, yfloor + 0.01, 0.03), d.lining or C(70, 74, 88), 'smooth')
		-- padded collar: fat tubes and corner balls round the opening (the shin is x, z in -0.5..0.5). The front tube
		-- is thinner (the tongue stands in front of it); the inner tube sits half in the shin so it never pokes into
		-- the other shoe.
		local cd = 0.3
		local xo = 0.52 -- outer tube: centred just outside the shin's face, half of it hugging the shin when worn
		local zz = 0.515
		local zf = -0.53
		local xi = -0.41 -- inner tube: thinner, inside the shin, never into the other shoe
		local col, ck = d.collar, d.collarKind
		local function tube(name, len, dia, x, y, z, axis)
			B:add('Part', 'Cylinder', name, V(len, dia, dia), at(x, y, z) * AXIS[axis], col, ck)
		end
		tube('Collar', xo - xi, 0.22, (xo + xi) / 2, cy - 0.03, zf, 'x')
		tube('Collar', xo - xi, cd, (xo + xi) / 2, cy, zz, 'x')
		tube('Collar', zz - zf, cd, xo, cy, (zz + zf) / 2, 'z')
		tube('Collar', zz - zf, 0.18, xi, cy - 0.04, (zz + zf) / 2, 'z')
		for _, p in { V(xo, cy - 0.01, zf), V(xo, cy, zz), V(xi, cy - 0.03, zf), V(xi, cy - 0.01, zz) } do
			B:ball('CollarCorner', (p.X > 0 and p.Z > 0) and cd or 0.24, at(p.X, p.Y, p.Z).Position, col, ck)
		end
		-- heel tab: a little loop standing up at the back of the collar
		local tab = d.tab or d.collar
		local hcf = at(XC, cy + 0.17, zz + 0.1)
		B:box('HeelTab', V(0.2, 0.22, 0.045), hcf.Position, tab, d.tabKind, hcf.Rotation)
		B:box('HeelTabHole', V(0.1, 0.08, 0.055), (hcf * CF(0, 0.04, 0)).Position, dark(tab, 0.45), 'smooth', hcf.Rotation)
		B.collarY, B.collarZ = cy, zz
		B.collarBack = at(XC, cy, zz)
		B.collarAt = at
		-- a point dy above the collar's centre line at (x, z), following its tilt
		B.cat = function(x, dy, z) return at(x, cy + (dy or 0), z).Position end
	end)
end

---------------------------------------------------------------------------------------------- accents
-- Side face of the ankle panel (outer, x = +side), the "canvas" for logos and prints.
local SIDE_X = L.XO + 0.016
local A = {}
ShoeModels.Accents = A
-- Frame on the outer side face at (y, z): x out of the face, rotation about X tilts within the face.
local function sideCF(y, z, out, tilt)
	return CF(SIDE_X + (out or 0.02), y, z) * ANG(rad(tilt or 0), 0, 0)
end
-- A flat disc on the side face.
local function sideDisc(B, name, d, y, z, color, kind, out, thick)
	return B:cyl(name, thick or 0.035, d, V(SIDE_X + (out or 0.018), y, z), color, kind, 'x')
end

-- "+1" glyph on the side face, centred at (y, z), height h. Reads left to right from outside on both shoes.
function A.plusOne(B, y, z, h, color, kind, out)
	local t = h * 0.22
	local text = { face = 'x', centre = V(0, y, z) }
	local x = SIDE_X + (out or 0.04)
	-- '+' on the left (toward the heel on the right shoe = screen-left from outside)
	local pz = z + h * 0.36
	B:box('GlyphPlus', V(0.03, t, h * 0.62), V(x, y, pz), color, kind, nil, { text = text })
	B:box('GlyphPlus', V(0.032, h * 0.62, t), V(x, y, pz), color, kind, nil, { text = text })
	-- '1' on the right (toward the toe)
	local oz = z - h * 0.3
	B:box('GlyphOne', V(0.03, h, t), V(x, y, oz), color, kind, nil, { text = text })
	B:box('GlyphOne', V(0.031, t * 0.95, h * 0.3), V(x, y + h * 0.36, oz + h * 0.14), color, kind, ANG(rad(-35), 0, 0), { text = text })
end

-- A standing "+1" (front-facing), e.g. on top of the tongue. cf = the glyph's centre, facing -Z. 4 parts.
function A.plusOneFront(B, cf, h, color, kind)
	local t = h * 0.24
	local text = { face = 'z', centre = cf.Position }
	-- '+' on the left as seen from the front (screen-left is +X when looking at the toe)
	local pc = cf * CF(h * 0.34, 0, 0)
	B:box('GlyphPlus', V(h * 0.62, t, 0.07), pc.Position, color, kind, cf.Rotation, { text = text })
	B:box('GlyphPlus', V(t, h * 0.62, 0.072), pc.Position, color, kind, cf.Rotation, { text = text })
	local oc = cf * CF(-h * 0.3, 0, 0)
	B:box('GlyphOne', V(t, h, 0.07), oc.Position, color, kind, cf.Rotation, { text = text })
	local fc = cf * CF(-h * 0.3 + h * 0.13, h * 0.36, 0) * ANG(0, 0, rad(-35))
	B:box('GlyphOne', V(h * 0.3, t * 0.95, 0.071), fc.Position, color, kind, fc.Rotation, { text = text })
end

-- The side logo: a round badge with a glyph.
function A.logo(B, d)
	local lg = d.logo
	if not lg then return end
	B:onShaft(function()
		local U = B.U
		local y, z = U + 0.42, 0.08
		local kind = lg.kind or 'disc'
		if kind == 'disc' then
			sideDisc(B, 'Logo', 0.32, y, z, lg.color, lg.mat)
			if lg.glyph == 'plus1' then
				A.plusOne(B, y, z, 0.17, lg.glyphColor or K.white, 'smooth', 0.042)
			elseif lg.glyph == 'plus' then
				local x = SIDE_X + 0.04
				B:box('GlyphPlus', V(0.03, 0.05, 0.18), V(x, y, z), lg.glyphColor or K.white)
				B:box('GlyphPlus', V(0.032, 0.18, 0.05), V(x, y, z), lg.glyphColor or K.white)
			elseif lg.glyph == 'dot' then
				sideDisc(B, 'LogoDot', 0.14, y, z, lg.glyphColor or K.white, 'smooth', 0.03, 0.03)
			end
		elseif kind == 'bolt' then
			A.bolt(B, y, z, 0.36, lg.color, lg.mat)
		elseif kind == 'zigzag' then
			A.zigzag(B, y - 0.02, z, 0.8, lg.color, lg.mat)
		elseif kind == 'star' then
			A.star(B, sideCF(y, z, 0.022), 0.4, lg.color, lg.mat)
		elseif kind == 'sparkle' then
			A.sparkle(B, sideCF(y, z, 0.022), 0.42, lg.color, lg.mat)
		elseif kind == 'moon' then
			A.moon(B, y, z, 0.34, lg.color, lg.mat, d.ankle or d.upper)
		elseif kind == 'gem' then
			A.gem(B, sideCF(y, z, 0.02), 0.3, lg.color, lg.mat)
		elseif kind == 'flame' then
			A.flame(B, sideCF(y - 0.12, z + 0.05, 0.022, 0), 0.5, lg.color, lg.color2 or K.gold, lg.mat)
		elseif kind == 'plus1' then
			A.plusOne(B, y, z, 0.3, lg.color, lg.mat, 0.03)
		elseif kind == 'drop' then
			A.drop(B, sideCF(y, z, 0.022), 0.3, lg.color, lg.mat)
		elseif kind == 'heart' then
			A.heart(B, sideCF(y, z, 0.022), 0.32, lg.color, lg.mat)
		elseif kind == 'snowflake' then
			A.snowflake(B, sideCF(y, z, 0.022), 0.4, lg.color, lg.mat)
		elseif kind == 'wave' then
			A.wave(B, y, z, 0.8, lg.color, lg.mat)
		end
	end)
end

-- Lightning bolt on the side face (three slanted strokes).
function A.bolt(B, y, z, h, color, kind, out)
	local cf = sideCF(y, z, out or 0.022)
	local w = h * 0.2
	B:box('Bolt', V(0.035, h * 0.5, w), (cf * CF(0, h * 0.24, h * 0.05)).Position, color, kind, ANG(rad(-25), 0, 0))
	B:box('Bolt', V(0.036, w * 0.9, h * 0.4), (cf * CF(0, 0.0, 0)).Position, color, kind, ANG(rad(-10), 0, 0))
	B:box('Bolt', V(0.035, h * 0.5, w), (cf * CF(0, -h * 0.24, -h * 0.05)).Position, color, kind, ANG(rad(-25), 0, 0))
end
-- A zigzag "tag" line along the side face.
function A.zigzag(B, y, z, len, color, kind, out)
	local n = 4
	local seg = len / n
	for i = 1, n do
		local zc = z + len / 2 - seg * (i - 0.5)
		local up = (i % 2 == 0) and 1 or -1
		B:box('Zigzag', V(0.03, 0.06, seg * 1.25), V(SIDE_X + (out or 0.02), y, zc), color, kind, ANG(rad(up * 35), 0, 0))
	end
end
-- A chunky five-point star: a centre disc and five 90-degree points. `cf` = centre on a face, X = face normal.
function A.star(B, cf, size, color, kind)
	local r = size / 2
	local s = r * 0.62
	for i = 0, 4 do
		local a = rad(90 + 72 * i)
		local p = cf * CF(0, math.sin(a) * r * 0.55, math.cos(a) * r * 0.55)
		B:box('Star', V(0.03, s, s), p.Position, color, kind, cf.Rotation * ANG(-(a - rad(90)) + rad(45), 0, 0))
	end
	B:cyl('Star', 0.034, r * 0.95, cf.Position, color, kind, cf.Rotation)
end
-- A four-point sparkle (two long thin diamonds crossed).
function A.sparkle(B, cf, size, color, kind)
	local s = size * 0.36
	B:box('Sparkle', V(0.03, s, s), cf.Position, color, kind, cf.Rotation * ANG(rad(45), 0, 0))
	B:box('Sparkle', V(0.032, size * 0.9, size * 0.14), cf.Position, color, kind, cf.Rotation)
	B:box('Sparkle', V(0.031, size * 0.14, size * 0.9), cf.Position, color, kind, cf.Rotation)
end
-- Snowflake: three crossed bars and a centre.
function A.snowflake(B, cf, size, color, kind)
	for i = 0, 2 do
		B:box('Snowflake', V(0.03 + i * 0.002, size, size * 0.12), cf.Position, color, kind, cf.Rotation * ANG(rad(i * 60), 0, 0))
	end
	B:cyl('Snowflake', 0.036, size * 0.3, cf.Position, color, kind, cf.Rotation)
end
-- A heart: two discs and a diamond.
function A.heart(B, cf, size, color, kind)
	local r = size * 0.3
	for _, sz in { -1, 1 } do
		B:cyl('Heart', 0.032, r * 2, (cf * CF(0, r * 0.45, sz * r * 0.72)).Position, color, kind, cf.Rotation)
	end
	B:box('Heart', V(0.03, r * 2.05, r * 2.05), (cf * CF(0, -r * 0.35, 0)).Position, color, kind, cf.Rotation * ANG(rad(45), 0, 0))
end
-- A drop (slime, paint): a disc with a point on top.
function A.drop(B, cf, size, color, kind)
	local r = size * 0.36
	B:cyl('Drop', 0.034, r * 2, (cf * CF(0, -size * 0.12, 0)).Position, color, kind, cf.Rotation)
	B:box('Drop', V(0.03, r * 1.42, r * 1.42), (cf * CF(0, size * 0.1, 0)).Position, color, kind, cf.Rotation * ANG(rad(45), 0, 0))
end
-- A cut gem seen from the side: a diamond with a lighter table.
function A.gem(B, cf, size, color, kind)
	B:box('Gem', V(0.04, size * 0.72, size * 0.72), cf.Position, color, kind or 'glass', cf.Rotation * ANG(rad(45), 0, 0))
	B:box('GemTable', V(0.05, size * 0.3, size * 0.3), (cf * CF(0.01, size * 0.06, 0)).Position, light(color, 0.45), 'neon', cf.Rotation * ANG(rad(45), 0, 0))
end
-- Crescent moon: a disc with a disc of the panel colour biting it.
function A.moon(B, y, z, size, color, kind, bg)
	sideDisc(B, 'Moon', size, y, z, color, kind, 0.018, 0.035)
	sideDisc(B, 'MoonBite', size * 0.8, y + size * 0.14, z - size * 0.16, bg, 'smooth', 0.03, 0.03)
end
-- Wave line (three arcs as tilted bars) along the side.
function A.wave(B, y, z, len, color, kind)
	local n = 3
	local seg = len / n
	for i = 1, n do
		local zc = z + len / 2 - seg * (i - 0.5)
		B:box('Wave', V(0.03, 0.07, seg * 0.62), V(SIDE_X + 0.02, y + 0.04, zc + seg * 0.18), color, kind, ANG(rad(28), 0, 0))
		B:box('Wave', V(0.031, 0.07, seg * 0.55), V(SIDE_X + 0.021, y + 0.04, zc - seg * 0.24), color, kind, ANG(rad(-38), 0, 0))
	end
end
-- Flame on a face: tongues of two colours (outer and core), each a disc with a diamond point.
function A.flame(B, cf, h, outer, core, kind)
	local tongues = { { 0, 1 }, { 0.2, 0.7 }, { -0.2, 0.62 } }
	for _, t in tongues do
		local r = h * 0.2 * (0.6 + 0.4 * t[2])
		local base = cf * CF(0, 0, t[1] * h)
		B:cyl('Flame', 0.03, r * 2, (base * CF(0, r, 0)).Position, outer, kind, cf.Rotation)
		B:box('Flame', V(0.029, r * 1.42, r * 1.42), (base * CF(0, r + h * 0.28 * t[2], 0)).Position, outer, kind, cf.Rotation * ANG(rad(45), 0, 0))
	end
	B:cyl('FlameCore', 0.036, h * 0.18, (cf * CF(0.004, h * 0.14, 0)).Position, core, 'neon', cf.Rotation)
end

-- Paint splats: discs of several colours with satellite dots, on the side face.
function A.splats(B, d, spots)
	B:onShaft(function()
		for _, s in spots do
			sideDisc(B, 'Splat', s[3], B.U + s[1], s[2], s[4], s[5] or 'smooth', 0.017 + (s[6] or 0) * 0.004, 0.03)
		end
	end)
end
-- Checker print on the ankle panel's outer side (a 2-colour panel with squares).
function A.checker(B, d, a, b)
	B:onShaft(function()
		local U = B.U
		local s = 0.25
		for i = 0, 3 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					B:box('Check', V(0.03, s, s), V(SIDE_X + 0.012, U + 0.38 + j * s, 0.56 - i * s - s / 2), b)
				end
			end
		end
	end)
end
-- Drips hanging from the collar on the outer side and the back (paint, slime, frosting).
function A.drips(B, d, color, kind, n, long)
	B:onShaft(function()
		local spots = { { 'side', 0.32, 0.36 }, { 'side', -0.08, 0.5 }, { 'side', -0.38, 0.28 }, { 'back', 0.28, 0.42 }, { 'back', -0.18, 0.3 } }
		for i = 1, math.min(n or 3, #spots) do
			local s = spots[i]
			local h = s[3] * (long or 1)
			if s[1] == 'side' then
				local x = SIDE_X + 0.03
				local y0 = B.cat(0.6, -0.06, s[2]).Y
				B:box('Drip', V(0.045, h, 0.1), V(x, y0 - h / 2, s[2]), color, kind)
				B:ball('DripEnd', 0.14, V(x - 0.012, y0 - h, s[2]), color, kind)
			else
				local z = 0.648
				local y0 = B.cat(0, -0.06, 0.6).Y
				B:box('Drip', V(0.1, h, 0.045), V(L.XC + s[2], y0 - h / 2, z), color, kind)
				B:ball('DripEnd', 0.14, V(L.XC + s[2], y0 - h, z - 0.012), color, kind)
			end
		end
	end)
end
-- Wings on the outer side of the ankle, fanning up and back: a round covert at the root and four broad feathers with
-- round tips, overlapping like a cartoon wing. style 'ice' gives square tips (icicles), 'flame' pointed ones.
function A.wings(B, d, color, color2, kind, scale, style)
	B:onShaft(function()
		local k = scale or 1
		local root = CF(B.cat(0.72, -0.06, 0.26)) * ANG(0, rad(62), 0)
		B:cyl('WingRoot', 0.07, 0.56 * k, (root * CF(0.03, 0.06, 0.1)).Position, color2 or color, kind, root.Rotation)
		local feathers = { { 0.92, 18 }, { 0.88, 33 }, { 0.78, 48 }, { 0.64, 63 } }
		local w = 0.3 * k
		for i, f in feathers do
			local len = f[1] * k
			local fcf = root * ANG(rad(-f[2]), 0, 0)
			local c = (i % 2 == 0 and color2) or color
			local x = 0.012 * i
			local body = fcf * CF(x, 0, len / 2)
			B:box('Feather', V(0.05, w, len), body.Position, c, kind, body.Rotation)
			local tip = fcf * CF(x, 0, len)
			if style == 'flame' then
				-- a pointed tip: one wedge whose slope runs out to the point
				local t = tip * CF(0, 0, w * 0.6) * ANG(rad(90), 0, 0)
				B:wedge('FeatherTip', V(0.05, w * 1.2, w), t.Position, c, kind, t.Rotation)
			elseif style ~= 'ice' then
				B:cyl('FeatherTip', 0.05, w, tip.Position, c, kind, tip.Rotation)
			end
		end
	end)
end
-- Flames rising off the back and the outer side of the collar (Inferno). Flat teeth of two tones.
function A.collarFlames(B, d, outer, core, kind)
	B:onShaft(function()
		local spots = { { B.cat(L.XC - 0.2, 0.04, 0.58), 0.55, 0 }, { B.cat(L.XC + 0.16, 0.04, 0.6), 0.8, 0 },
			{ B.cat(0.62, 0.04, 0.2), 0.62, 90 }, { B.cat(0.62, 0.04, -0.18), 0.48, 90 } }
		for i, s in spots do
			local cf = CF(s[1]) * ANG(0, rad(s[3]), 0) * ANG(0, 0, rad((i % 2 == 0) and -10 or 12))
			B:tooth('FlameTooth', 0.32, s[2], 0.06, cf, outer, kind)
			if i % 2 == 0 then B:tooth('FlameCore', 0.17, s[2] * 0.55, 0.075, cf, core, 'neon') end
		end
	end)
end
-- Crystal shards round the collar (ice, gems): flat teeth turned to show their edge, glass.
function A.crystals(B, d, color, kind, n, h)
	B:onShaft(function()
		local spots = {
			{ B.cat(L.XC + 0.35, -0.02, 0.52), 0.55, 15, -12 }, { B.cat(L.XC - 0.15, -0.02, 0.58), 0.7, -10, 0 }, { B.cat(0.6, -0.02, 0.0), 0.62, 80, 18 },
			{ B.cat(0.6, -0.02, -0.36), 0.45, 100, 14 }, { B.cat(L.XC + 0.2, -0.02, 0.6), 0.42, 30, -24 }, { B.cat(L.XC - 0.38, -0.02, 0.44), 0.4, -40, -10 },
		}
		for i = 1, math.min(n or 4, #spots) do
			local s = spots[i]
			local cf = CF(s[1]) * ANG(0, rad(s[3]), 0) * ANG(0, 0, rad(s[4]))
			B:tooth('Crystal', 0.22, s[2] * (h or 1), 0.16, cf, (i % 2 == 0) and light(color, 0.35) or color, kind or 'ice')
		end
	end)
end
-- A small crown: a band, three diamond points (cubes turned 45 degrees, half sunk in the band) with gem balls on top,
-- and a jewel on the band's front. cf = the crown's base centre, facing -Z. 8 parts.
function A.crown(B, cf, size, color, gem, kind)
	local w = size
	B:box('CrownBand', V(w, w * 0.26, w * 0.42), (cf * CF(0, w * 0.13, 0)).Position, color, kind or 'gold', cf.Rotation)
	for i = -1, 1 do
		local h = i == 0 and 0.34 or 0.27
		local s = w * h
		local p = cf * CF(i * w * 0.33, w * 0.26, 0)
		B:box('CrownPoint', V(w * 0.3, s, s), p.Position, color, kind or 'gold', p.Rotation * ANG(rad(45), 0, 0) * ANG(0, 0, 0))
		B:ball('CrownGem', w * 0.13, (p * CF(0, s * 0.71, 0)).Position, gem, 'smooth')
	end
	B:ball('CrownJewel', w * 0.15, (cf * CF(0, w * 0.13, -w * 0.21)).Position, gem, 'neon')
end
-- Speckles (stars on a galaxy print, sprinkles): tiny pieces on the outer side.
function A.speckles(B, d, list, kind)
	B:onShaft(function()
		for _, s in list do
			local cf = sideCF(B.U + s[1], s[2], 0.018, s[5] or 45)
			B:box(s[6] or 'Speckle', V(0.025, s[3], s[7] or s[3]), cf.Position, s[4], kind or 'neon', cf.Rotation)
		end
	end)
end
-- A heel strip (glows from Legendary): a vertical band down the back of the heel counter, seen from the camera.
function A.heelStrip(B, d, color, kind)
	B:box('HeelStrip', V(0.12, 0.42, 0.02), V(L.XC, B.U + 0.25, 0.655), color, kind or 'neon')
end
-- Rainbow stripes round the ankle panel (Secret): two segments on the outer side and one across the back. 3 parts.
function A.rainbowBand(B, d, y, offset)
	B:onShaft(function()
		local o = offset or 0
		for i = 1, 2 do
			local z1 = 0.62 - (i - 1) * 0.56
			B:box('RainbowBand', V(0.03, 0.07, 0.56), V(SIDE_X + 0.012, B.U + y, z1 - 0.28), RAINBOW[(i + o - 1) % #RAINBOW + 1], 'neon')
		end
		B:box('RainbowBand', V(1.15, 0.07, 0.03), V(L.XC + 0.01, B.U + y, 0.643), RAINBOW[(o + 2) % #RAINBOW + 1], 'neon')
	end)
end
-- Toe badge: a motif on the vamp/toe box front (mock-ups put stars, drops, crowns, gems on the toe).
function A.toeBadge(B, d, kind, color, mat, size)
	-- a badge on the front of the rubber toe cap: X = out of the toe (-Z), Y = up
	local p = V(L.XC, B.U + 0.12, L.ZT + 0.025 - 0.012)
	local cf = CFrame.fromMatrix(p, V(0, 0, -1), V(0, 1, 0), V(1, 0, 0))
	size = math.min(size or 0.26, 0.28)
	local s = size or 0.3
	if kind == 'star' then A.star(B, cf, s, color, mat)
	elseif kind == 'sparkle' then A.sparkle(B, cf, s * 1.2, color, mat)
	elseif kind == 'crown' then A.crown(B, CF(cf.Position + V(0, -0.06, -0.05)), s * 1.45, color, C(230, 40, 60), mat)
	elseif kind == 'drop' then A.drop(B, cf, s, color, mat)
	elseif kind == 'heart' then A.heart(B, cf, s, color, mat)
	elseif kind == 'gem' then A.gem(B, cf, s, color, mat)
	elseif kind == 'flame' then A.flame(B, cf * CF(0, -s * 0.4, 0), s * 1.1, color, K.gold, mat)
	elseif kind == 'snowflake' then A.snowflake(B, cf, s, color, mat)
	end
end

---------------------------------------------------------------------------------------------- definitions
-- Per shoe: Name, Box, Rarity (1..6) and the look. Colours: upper (main), ankle (second tone), heel, collar, tongue,
-- lace, eyelet, toe (toe cap), sole, base (outsole band from Rare), stripe (midsole line). `upperKind` etc. set
-- materials; `deco(B, d)` adds the accents. Defaults fill what a definition leaves out.
local DEFS = {}
local ORDER = {}
local function def(id, t)
	t.Id = id
	DEFS[id] = t
	table.insert(ORDER, id)
end

-- 01 Street --------------------------------------------------------------------------------------------------------
def('FreshCanvas', { Name = 'Fresh Canvas', Box = 'Street', rarity = 1,
	upper = C(240, 240, 243), ankle = C(232, 233, 238), heel = C(222, 224, 230), collar = K.snow, tongue = C(236, 236, 240),
	upperKind = 'fabric', lace = K.snow, stripe = K.ink, logo = { color = C(222, 40, 48), glyph = 'plus1' }, tongueLabel = C(222, 40, 48),
})
def('RedRocket', { Name = 'Red Rocket', Box = 'Street', rarity = 2,
	upper = C(214, 38, 44), ankle = C(196, 30, 38), heel = C(30, 30, 38), collar = C(30, 30, 38), tongue = C(226, 52, 56), tab = C(30, 30, 38),
	base = C(30, 30, 38), stripe = K.ink, logo = { kind = 'bolt', color = C(255, 196, 40) }, tongueLabel = C(255, 196, 40),
})
def('Checkmate', { Name = 'Checkmate', Box = 'Street', rarity = 3,
	upper = C(34, 34, 42), ankle = C(238, 238, 242), heel = C(30, 30, 38), collar = C(30, 30, 38), tongue = C(30, 30, 38), tab = C(222, 40, 48),
	toeBox = C(238, 238, 242), base = C(214, 36, 44), stripe = C(255, 96, 96), tongueLabel = C(222, 40, 48), eyestay = C(34, 34, 42),
	deco = function(B, d)
		A.checker(B, d, d.ankle, C(34, 34, 42))
		B:onShaft(function() A.bolt(B, B.U + 0.42, -0.25, 0.42, C(232, 40, 48), 'smooth', 0.04) end)
		A.toeBadge(B, d, 'star', C(232, 40, 48), 'smooth', 0.28)
	end,
})
def('ChromeKicks', { Name = 'Chrome Kicks', Box = 'Street', rarity = 4, fx = { tex = 'sparkle', colors = { C(255, 120, 160), C(255, 190, 210) } },
	upper = C(222, 228, 238), ankle = C(204, 212, 226), heel = C(30, 30, 38), collar = C(30, 30, 38), tongue = C(230, 234, 242), upperKind = 'metal',
	lace = C(240, 70, 90), eyelet = K.gold, eyeletKind = 'gold', sole = C(36, 36, 46), base = C(24, 24, 30), stripe = C(255, 70, 90), toe = C(36, 36, 46),
	tongueLabel = C(240, 70, 90),
	deco = function(B, d)
		B:onShaft(function()
			A.sparkle(B, sideCF(B.U + 0.44, 0.1, 0.03), 0.42, C(255, 120, 160), 'neon')
			A.sparkle(B, sideCF(B.U + 0.24, -0.28, 0.03), 0.22, C(255, 170, 200), 'neon')
		end)
		A.heelStrip(B, d, C(255, 70, 90))
	end,
})
def('StreetAngel', { Name = 'Street Angel', Box = 'Street', rarity = 5, fx = { tex = 'sparkle', colors = { C(255, 250, 230), C(255, 214, 110) } },
	upper = C(246, 246, 250), ankle = C(236, 238, 244), heel = C(255, 200, 70), collar = C(255, 200, 60), collarKind = 'gold', tongue = C(255, 204, 70),
	tongueKind = 'gold', toe = C(255, 204, 70), toeKind = 'gold', eyelet = K.gold, eyeletKind = 'gold', sole = C(250, 246, 236), base = C(240, 190, 60),
	stripe = C(255, 250, 230), tab = C(255, 200, 60), tongueLabel = K.snow,
	deco = function(B, d)
		A.wings(B, d, C(250, 250, 255), C(232, 236, 248), 'smooth', 1.15)
		A.heelStrip(B, d, C(255, 236, 160))
	end,
})
def('BlockRoyalty', { Name = 'Block Royalty', Box = 'Street', rarity = 6,
	upper = C(34, 30, 44), ankle = C(28, 26, 36), heel = C(222, 40, 48), collar = C(222, 44, 52), tongue = C(28, 26, 36), upperKind = 'gloss',
	lace = C(255, 210, 60), rainbowLaces = true, eyelet = K.gold, eyeletKind = 'gold', sole = C(232, 70, 40), base = C(200, 50, 30), rainbowStripe = true,
	toe = C(34, 30, 44), toeKind = 'gloss', tongueLabel = false,
	deco = function(B, d)
		A.rainbowBand(B, d, 0.3, 0)
		B:onShaft(function()
			A.crown(B, B.tongueFront * CF(0, 0.3, -0.03), 0.52, C(255, 200, 50), C(232, 40, 60))
		end)
		A.toeBadge(B, d, 'star', C(255, 210, 60), 'gold', 0.3)
	end,
})

-- 02 Graffiti ------------------------------------------------------------------------------------------------------
def('SprayTag', { Name = 'Spray Tag', Box = 'Graffiti', rarity = 1,
	upper = C(232, 92, 164), ankle = C(220, 82, 152), heel = C(204, 70, 140), collar = K.snow, tongue = C(240, 110, 176),
	lace = C(255, 206, 50), stripe = K.ink, logo = { color = C(40, 196, 210), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(40, 196, 210),
})
def('DripTag', { Name = 'Drip Tag', Box = 'Graffiti', rarity = 2,
	upper = C(42, 184, 204), ankle = C(34, 166, 188), heel = C(236, 96, 160), collar = C(236, 96, 160), tongue = C(52, 196, 214), tab = C(236, 96, 160),
	base = C(236, 96, 160), stripe = C(236, 96, 160), logo = { kind = 'zigzag', color = C(255, 206, 50) }, tongueLabel = C(255, 206, 50),
	deco = function(B, d) A.drips(B, d, C(236, 96, 160), 'smooth', 2, 0.8) end,
})
def('PaintSplash', { Name = 'Paint Splash', Box = 'Graffiti', rarity = 3,
	upper = C(36, 34, 46), ankle = C(30, 28, 40), heel = C(236, 96, 160), collar = C(36, 34, 46), tongue = C(36, 34, 46), tab = C(236, 96, 160),
	base = C(236, 96, 160), stripe = C(255, 120, 200), tongueLabel = C(120, 230, 90),
	deco = function(B, d)
		A.splats(B, d, { { 0.5, 0.25, 0.26, C(236, 96, 160) }, { 0.32, -0.12, 0.2, C(120, 230, 90), nil, 1 }, { 0.55, -0.3, 0.12, C(70, 170, 255) },
			{ 0.22, 0.4, 0.12, C(255, 206, 50) }, { 0.18, 0.08, 0.08, C(236, 96, 160), nil, 1 } })
		A.toeBadge(B, d, 'star', C(236, 96, 160), 'smooth', 0.3)
		A.drips(B, d, C(236, 96, 160), 'smooth', 2, 0.7)
	end,
})
def('NeonBomb', { Name = 'Neon Bomb', Box = 'Graffiti', rarity = 4,
	upper = C(236, 60, 150), ankle = C(220, 44, 136), heel = C(30, 28, 40), collar = C(30, 28, 40), tongue = C(244, 80, 164), upperKind = 'gloss',
	lace = C(120, 230, 255), sole = C(30, 28, 40), base = C(24, 22, 32), stripe = C(100, 230, 255), toe = C(30, 28, 40), tongueLabel = C(120, 230, 255),
	deco = function(B, d)
		B:onShaft(function()
			A.sparkle(B, sideCF(B.U + 0.44, 0.12, 0.03), 0.44, C(150, 240, 255), 'neon')
			A.sparkle(B, sideCF(B.U + 0.26, -0.28, 0.03), 0.24, C(220, 250, 255), 'neon')
		end)
		A.drips(B, d, C(100, 230, 255), 'neon', 2, 0.7)
		A.heelStrip(B, d, C(100, 230, 255))
	end,
})
def('WildStyle', { Name = 'Wild Style', Box = 'Graffiti', rarity = 5,
	upper = C(40, 44, 70), ankle = C(34, 38, 62), heel = C(236, 96, 160), collar = C(236, 96, 160), tongue = C(236, 96, 160), tab = C(236, 96, 160),
	sole = C(236, 96, 160), base = C(200, 70, 140), stripe = C(130, 255, 110), toe = C(120, 220, 90), tongueLabel = C(130, 255, 110),
	deco = function(B, d)
		A.splats(B, d, { { 0.48, 0.2, 0.26, C(120, 220, 90) }, { 0.26, -0.2, 0.18, C(120, 220, 90), nil, 1 }, { 0.2, 0.42, 0.1, C(236, 96, 160) } })
		A.drips(B, d, C(130, 255, 110), 'neon', 4, 1.1)
		A.toeBadge(B, d, 'star', C(130, 255, 110), 'neon', 0.3)
	end,
})
def('Masterpiece', { Name = 'Masterpiece', Box = 'Graffiti', rarity = 6,
	upper = C(52, 34, 90), ankle = C(44, 28, 78), heel = C(255, 110, 190), collar = C(70, 46, 120), tongue = C(52, 34, 90), upperKind = 'gloss',
	rainbowLaces = true, sole = C(240, 90, 160), base = C(200, 60, 130), rainbowStripe = true, rainbowOffset = 2, toe = C(70, 46, 120), tongueLabel = C(255, 200, 60),
	deco = function(B, d)
		A.splats(B, d, { { 0.5, 0.26, 0.24, RAINBOW[1], 'neon' }, { 0.3, -0.05, 0.2, RAINBOW[4], 'neon', 1 }, { 0.55, -0.32, 0.13, RAINBOW[6], 'neon' },
			{ 0.2, 0.36, 0.11, RAINBOW[3], 'neon', 1 } })
		A.drips(B, d, RAINBOW[5], 'neon', 4, 1.1)
		A.toeBadge(B, d, 'sparkle', RAINBOW[2], 'neon', 0.3)
	end,
})

-- 03 Frost ---------------------------------------------------------------------------------------------------------
def('IceCold', { Name = 'Ice Cold', Box = 'Frost', rarity = 1,
	upper = C(112, 178, 228), ankle = C(100, 166, 220), heel = C(90, 152, 208), collar = K.snow, tongue = C(124, 188, 234), stripe = K.ink,
	logo = { color = C(240, 248, 255), glyph = 'dot', glyphColor = C(90, 152, 208) }, tongueLabel = K.snow,
})
def('SnowDay', { Name = 'Snow Day', Box = 'Frost', rarity = 2,
	upper = C(36, 92, 178), ankle = C(30, 80, 164), heel = C(150, 210, 250), collar = K.snow, tongue = C(46, 104, 190), tab = C(150, 210, 250),
	base = C(150, 210, 250), stripe = C(110, 190, 245), logo = { kind = 'zigzag', color = C(160, 220, 255) }, tongueLabel = C(160, 220, 255),
})
def('Flurry', { Name = 'Flurry', Box = 'Frost', rarity = 3,
	upper = C(170, 212, 245), ankle = C(150, 198, 238), heel = C(40, 100, 190), collar = C(40, 100, 190), tongue = C(40, 100, 190), tab = C(40, 100, 190),
	base = C(120, 190, 245), stripe = C(170, 235, 255), toe = C(232, 242, 252), tongueLabel = K.snow,
	deco = function(B, d)
		B:onShaft(function()
			A.snowflake(B, sideCF(B.U + 0.46, 0.18, 0.025), 0.3, K.snow, 'smooth')
			A.snowflake(B, sideCF(B.U + 0.3, -0.22, 0.025), 0.2, K.snow, 'smooth')
		end)
		A.toeBadge(B, d, 'star', C(40, 100, 190), 'smooth', 0.3)
	end,
})
def('Glacier', { Name = 'Glacier', Box = 'Frost', rarity = 4,
	upper = C(40, 120, 220), ankle = C(34, 104, 200), heel = C(170, 225, 255), collar = C(24, 80, 170), tongue = C(140, 200, 250), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(70, 140, 225), base = C(30, 90, 180), stripe = C(220, 245, 255), toe = C(200, 230, 255), toeKind = 'ice',
	tongueLabel = K.snow,
	deco = function(B, d)
		A.crystals(B, d, C(190, 235, 255), 'ice', 4, 0.9)
		B:onShaft(function() B:box('IcePanel', V(0.03, 0.3, 0.52), V(SIDE_X + 0.016, B.U + 0.4, 0.1), C(190, 235, 255), 'ice') end)
		A.heelStrip(B, d, C(200, 240, 255))
	end,
})
def('BlizzardKing', { Name = 'Blizzard King', Box = 'Frost', rarity = 5,
	upper = C(30, 80, 170), ankle = C(26, 70, 152), heel = C(150, 210, 250), collar = C(24, 66, 150), tongue = C(24, 66, 150), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(40, 96, 190), base = C(20, 56, 130), stripe = C(220, 245, 255), toe = C(30, 80, 170), toeKind = 'gloss',
	tongueLabel = K.snow,
	deco = function(B, d)
		A.wings(B, d, C(214, 238, 255), C(170, 215, 250), 'ice', 1.1, 'ice')
		B:onShaft(function() A.snowflake(B, sideCF(B.U + 0.36, -0.18, 0.025), 0.26, K.snow, 'neon') end)
		A.toeBadge(B, d, 'snowflake', K.snow, 'neon', 0.3)
	end,
})
def('AbsoluteZero', { Name = 'Absolute Zero', Box = 'Frost', rarity = 6,
	upper = C(24, 40, 96), ankle = C(20, 34, 84), heel = C(120, 220, 255), collar = C(40, 70, 150), tongue = C(24, 40, 96), upperKind = 'gloss',
	rainbowLaces = true, sole = C(140, 210, 250), base = C(60, 140, 220), rainbowStripe = true, rainbowOffset = 3, toe = C(24, 40, 96), toeKind = 'gloss',
	tongueLabel = C(150, 230, 255),
	deco = function(B, d)
		A.crystals(B, d, C(170, 235, 255), 'ice', 5, 1.15)
		A.rainbowBand(B, d, 0.28, 3)
	end,
})

-- 04 Lava ----------------------------------------------------------------------------------------------------------
def('Ember', { Name = 'Ember', Box = 'Lava', rarity = 1,
	upper = C(238, 140, 34), ankle = C(226, 126, 26), heel = C(212, 112, 22), collar = K.snow, tongue = C(244, 152, 44), stripe = K.ink,
	logo = { color = C(36, 32, 40), glyph = 'dot', glyphColor = C(255, 200, 60) }, tongueLabel = C(36, 32, 40),
})
def('HotStep', { Name = 'Hot Step', Box = 'Lava', rarity = 2,
	upper = C(186, 34, 34), ankle = C(168, 28, 30), heel = C(32, 32, 50), collar = C(32, 32, 44), tongue = C(200, 44, 44), tab = C(32, 32, 44),
	base = C(240, 130, 30), stripe = C(32, 32, 50), logo = { kind = 'flame', color = C(255, 196, 50), color2 = C(255, 240, 160) }, tongueLabel = C(255, 196, 50),
})
def('MagmaCrack', { Name = 'Magma Crack', Box = 'Lava', rarity = 3,
	upper = C(36, 30, 34), ankle = C(30, 26, 30), heel = C(240, 110, 30), collar = C(36, 30, 34), tongue = C(36, 30, 34), tab = C(240, 110, 30),
	base = C(36, 30, 34), stripe = C(255, 120, 40), toe = C(236, 236, 240), tongueLabel = C(255, 140, 40),
	deco = function(B, d)
		A.speckles(B, d, { { 0.48, 0.22, 0.04, C(255, 130, 40), 20, 'Crack', 0.36 }, { 0.36, -0.02, 0.04, C(255, 130, 40), -30, 'Crack', 0.3 },
			{ 0.24, 0.3, 0.035, C(255, 160, 60), 60, 'Crack', 0.22 }, { 0.56, -0.3, 0.035, C(255, 130, 40), -60, 'Crack', 0.2 } }, 'neon')
		A.toeBadge(B, d, 'flame', C(255, 120, 30), 'smooth', 0.36)
	end,
})
def('Obsidian', { Name = 'Obsidian', Box = 'Lava', rarity = 4,
	upper = C(30, 26, 32), ankle = C(24, 22, 28), heel = C(255, 110, 30), collar = C(30, 26, 32), tongue = C(30, 26, 32), upperKind = 'gloss',
	lace = C(255, 120, 40), eyelet = K.gold, eyeletKind = 'gold', sole = C(30, 26, 32), base = C(22, 20, 26), stripe = C(255, 120, 40), toe = C(30, 26, 32),
	toeKind = 'gloss', tongueLabel = C(255, 120, 40),
	deco = function(B, d)
		B:onShaft(function() A.flame(B, sideCF(B.U + 0.18, 0.05, 0.022), 0.62, C(255, 120, 40), C(255, 220, 120), 'neon') end)
		A.heelStrip(B, d, C(255, 120, 40))
	end,
})
def('Inferno', { Name = 'Inferno', Box = 'Lava', rarity = 5,
	upper = C(230, 70, 30), ankle = C(210, 56, 24), heel = C(30, 26, 32), collar = C(30, 26, 32), tongue = C(30, 26, 32), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(36, 30, 34), base = C(240, 110, 30), stripe = C(255, 150, 50), toe = C(30, 26, 32), toeKind = 'gloss',
	tongueLabel = C(255, 200, 60),
	deco = function(B, d)
		A.collarFlames(B, d, C(255, 110, 40), C(255, 220, 90), 'neon')
		A.speckles(B, d, { { 0.44, 0.1, 0.04, C(255, 220, 90), 25, 'Crack', 0.4 }, { 0.26, -0.22, 0.04, C(255, 220, 90), -40, 'Crack', 0.28 } }, 'neon')
	end,
})
def('Phoenix', { Name = 'Phoenix', Box = 'Lava', rarity = 6,
	upper = C(40, 22, 26), ankle = C(34, 18, 22), heel = C(255, 120, 40), collar = C(60, 26, 30), tongue = C(40, 22, 26), upperKind = 'gloss',
	rainbowLaces = true, sole = C(240, 110, 40), base = C(200, 70, 30), rainbowStripe = true, rainbowOffset = 0, toe = C(40, 22, 26), toeKind = 'gloss',
	tongueLabel = C(255, 200, 60),
	deco = function(B, d)
		A.wings(B, d, C(255, 120, 50), C(255, 190, 70), 'neon', 1.15, 'flame')
		A.rainbowBand(B, d, 0.28, 1)
	end,
})

-- 05 Toxic ---------------------------------------------------------------------------------------------------------
def('SlimeTime', { Name = 'Slime Time', Box = 'Toxic', rarity = 1,
	upper = C(124, 212, 64), ankle = C(112, 198, 54), heel = C(100, 184, 46), collar = K.snow, tongue = C(136, 222, 76), stripe = K.ink,
	logo = { color = C(80, 60, 160), glyph = 'dot', glyphColor = C(160, 240, 90) }, tongueLabel = C(80, 60, 160),
})
def('GlowStick', { Name = 'Glow Stick', Box = 'Toxic', rarity = 2,
	upper = C(88, 64, 172), ankle = C(76, 54, 156), heel = C(130, 230, 70), collar = C(130, 230, 70), tongue = C(98, 74, 184), tab = C(130, 230, 70),
	base = C(130, 230, 70), stripe = C(130, 230, 70), logo = { kind = 'bolt', color = C(140, 240, 80) }, tongueLabel = C(140, 240, 80),
})
def('Ooze', { Name = 'Ooze', Box = 'Toxic', rarity = 3,
	upper = C(40, 40, 92), ankle = C(34, 34, 80), heel = C(120, 220, 70), collar = C(40, 40, 92), tongue = C(40, 40, 92), tab = C(120, 220, 70),
	base = C(120, 220, 70), stripe = C(150, 255, 90), tongueLabel = C(140, 240, 80),
	deco = function(B, d)
		A.drips(B, d, C(130, 230, 70), 'smooth', 3, 0.9)
		A.toeBadge(B, d, 'drop', C(130, 230, 70), 'smooth', 0.34)
		A.splats(B, d, { { 0.24, 0.3, 0.14, C(130, 230, 70) }, { 0.2, -0.3, 0.1, C(130, 230, 70) } })
	end,
})
def('Reactor', { Name = 'Reactor', Box = 'Toxic', rarity = 4,
	upper = C(130, 226, 70), ankle = C(118, 212, 60), heel = C(40, 40, 92), collar = C(40, 40, 92), tongue = C(140, 236, 80), upperKind = 'gloss',
	lace = C(40, 40, 92), eyelet = K.gold, eyeletKind = 'gold', sole = C(40, 40, 92), base = C(30, 30, 72), stripe = C(160, 255, 90), toe = C(40, 40, 92),
	tongueLabel = C(40, 40, 92),
	deco = function(B, d)
		B:onShaft(function()
			A.bolt(B, B.U + 0.44, 0.12, 0.44, C(200, 255, 140), 'neon', 0.035)
			A.bolt(B, B.U + 0.3, -0.24, 0.26, C(200, 255, 140), 'neon', 0.035)
		end)
		A.heelStrip(B, d, C(170, 255, 100))
	end,
})
def('ToxicTitan', { Name = 'Toxic Titan', Box = 'Toxic', rarity = 5,
	upper = C(40, 40, 96), ankle = C(34, 34, 84), heel = C(130, 230, 70), collar = C(60, 54, 140), tongue = C(60, 54, 140), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(40, 40, 96), base = C(130, 230, 70), stripe = C(160, 255, 90), toe = C(130, 230, 70), toeKind = 'gloss',
	tongueLabel = C(160, 255, 90),
	deco = function(B, d)
		A.drips(B, d, C(150, 255, 90), 'neon', 5, 1.2)
		A.splats(B, d, { { 0.24, 0.28, 0.16, C(150, 255, 90), 'neon' }, { 0.2, -0.32, 0.12, C(150, 255, 90), 'neon' } })
	end,
})
def('Mutant', { Name = 'Mutant', Box = 'Toxic', rarity = 6,
	upper = C(30, 34, 80), ankle = C(26, 30, 70), heel = C(130, 230, 70), collar = C(50, 50, 120), tongue = C(30, 34, 80), upperKind = 'gloss',
	rainbowLaces = true, sole = C(130, 230, 70), base = C(80, 180, 50), rainbowStripe = true, rainbowOffset = 4, toe = C(30, 34, 80), toeKind = 'gloss',
	tongueLabel = C(160, 255, 90),
	deco = function(B, d)
		B:onShaft(function()
			-- two friendly cartoon eyes on stalks peeking over the collar
			for i, p in { B.cat(L.XC + 0.3, 0.3, 0.45), B.cat(L.XC - 0.18, 0.4, 0.5) } do
				B:box('EyeStalk', V(0.07, 0.36 + i * 0.06, 0.07), p - V(0, 0.2 + i * 0.03, 0), C(130, 230, 70))
				B:ball('Eye', 0.3, p, K.snow)
				B:ball('Pupil', 0.13, p + V(0, 0.02, -0.11), K.ink)
			end
		end)
		A.drips(B, d, C(150, 255, 90), 'neon', 3, 1)
		A.rainbowBand(B, d, 0.28, 4)
	end,
})

-- 06 Candy ---------------------------------------------------------------------------------------------------------
def('Bubblegum', { Name = 'Bubblegum', Box = 'Candy', rarity = 1,
	upper = C(244, 160, 196), ankle = C(236, 148, 188), heel = C(226, 136, 178), collar = K.snow, tongue = C(248, 172, 204), stripe = K.ink,
	logo = { color = C(120, 140, 240), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(120, 140, 240),
})
def('CottonCandy', { Name = 'Cotton Candy', Box = 'Candy', rarity = 2,
	upper = C(150, 206, 244), ankle = C(136, 194, 238), heel = C(244, 120, 176), collar = C(244, 120, 176), tongue = C(162, 214, 248), tab = C(244, 120, 176),
	base = C(244, 120, 176), stripe = C(244, 120, 176), logo = { kind = 'zigzag', color = K.snow }, tongueLabel = C(244, 120, 176),
})
def('Sprinkles', { Name = 'Sprinkles', Box = 'Candy', rarity = 3,
	upper = C(248, 236, 244), ankle = C(244, 200, 222), heel = C(150, 140, 240), collar = C(150, 140, 240), tongue = C(150, 140, 240), tab = C(150, 140, 240),
	base = C(244, 120, 176), stripe = C(255, 130, 190), tongueLabel = C(244, 120, 176),
	deco = function(B, d)
		A.speckles(B, d, { { 0.5, 0.3, 0.035, C(255, 90, 140), 30, 'Sprinkle', 0.14 }, { 0.38, 0.05, 0.035, C(90, 190, 255), -40, 'Sprinkle', 0.14 },
			{ 0.56, -0.18, 0.035, C(255, 210, 60), 70, 'Sprinkle', 0.14 }, { 0.26, -0.32, 0.035, C(120, 220, 120), 10, 'Sprinkle', 0.14 },
			{ 0.24, 0.36, 0.035, C(170, 110, 255), -70, 'Sprinkle', 0.14 } }, 'smooth')
		B:onShaft(function() A.heart(B, sideCF(B.U + 0.4, -0.02, 0.022), 0.3, C(244, 90, 150), 'smooth') end)
		A.toeBadge(B, d, 'heart', C(244, 90, 150), 'smooth', 0.3)
	end,
})
def('Gummy', { Name = 'Gummy', Box = 'Candy', rarity = 4,
	upper = C(222, 52, 130), ankle = C(204, 40, 118), heel = K.snow, collar = K.snow, tongue = C(232, 70, 144), upperKind = 'gloss',
	lace = C(255, 200, 225), eyelet = K.gold, eyeletKind = 'gold', sole = C(250, 200, 222), base = C(222, 52, 130), stripe = C(255, 180, 215),
	toe = C(250, 220, 234), tongueLabel = K.snow,
	deco = function(B, d)
		A.drips(B, d, K.snow, 'smooth', 5, 0.75)
		B:onShaft(function() A.heart(B, sideCF(B.U + 0.36, 0.0, 0.022), 0.3, K.snow, 'smooth') end)
		A.heelStrip(B, d, C(255, 170, 210))
	end,
})
def('SugarRush', { Name = 'Sugar Rush', Box = 'Candy', rarity = 5,
	upper = C(196, 36, 92), ankle = C(176, 28, 80), heel = C(255, 200, 225), collar = C(176, 28, 80), tongue = C(176, 28, 80), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(250, 210, 228), base = C(210, 60, 120), stripe = C(255, 220, 238), toe = C(196, 36, 92), toeKind = 'gloss',
	tongueLabel = K.snow,
	deco = function(B, d)
		A.wings(B, d, C(255, 226, 240), C(255, 200, 226), 'smooth', 1.1)
		A.speckles(B, d, { { 0.42, -0.25, 0.035, C(255, 220, 90), 30, 'Sprinkle', 0.13 }, { 0.24, -0.05, 0.035, C(110, 210, 255), -40, 'Sprinkle', 0.13 },
			{ 0.2, 0.38, 0.035, K.snow, 60, 'Sprinkle', 0.13 } }, 'smooth')
	end,
})
def('CandyKingdom', { Name = 'Candy Kingdom', Box = 'Candy', rarity = 6,
	upper = C(214, 50, 140), ankle = C(196, 40, 126), heel = C(255, 220, 240), collar = C(196, 40, 126), tongue = C(214, 50, 140), upperKind = 'gloss',
	rainbowLaces = true, sole = C(255, 170, 205), base = C(220, 90, 150), rainbowStripe = true, rainbowOffset = 5, toe = C(214, 50, 140), toeKind = 'gloss',
	tongueLabel = K.snow,
	deco = function(B, d)
		B:onShaft(function()
			-- a lollipop stuck in the back of the collar, and a gumball balloon
			local base = B.cat(L.XC + 0.35, 0, 0.58)
			B:box('LollyStick', V(0.06, 0.7, 0.06), base + V(0, 0.3, 0), K.snow)
			B:cyl('Lolly', 0.08, 0.5, base + V(0, 0.82, 0), C(150, 120, 255), 'smooth', 'z')
			B:cyl('LollySwirl', 0.1, 0.26, base + V(0, 0.82, 0), K.snow, 'smooth', 'z')
			B:ball('Gumball', 0.36, B.cat(L.XC - 0.28, 0.55, 0.5), C(255, 120, 170), 'gloss')
			B:box('GumballString', V(0.03, 0.32, 0.03), B.cat(L.XC - 0.28, 0.2, 0.5), K.snow)
		end)
		A.rainbowBand(B, d, 0.28, 5)
		A.toeBadge(B, d, 'heart', C(255, 220, 240), 'neon', 0.3)
	end,
})

-- 07 Ocean ---------------------------------------------------------------------------------------------------------
def('Wave', { Name = 'Wave', Box = 'Ocean', rarity = 1,
	upper = C(30, 150, 200), ankle = C(24, 138, 188), heel = C(20, 124, 172), collar = K.snow, tongue = C(40, 162, 210), stripe = K.ink,
	logo = { color = K.snow, glyph = 'dot', glyphColor = C(30, 150, 200) }, tongueLabel = K.snow,
})
def('Coral', { Name = 'Coral', Box = 'Ocean', rarity = 2,
	upper = C(236, 112, 94), ankle = C(224, 100, 84), heel = C(40, 170, 200), collar = C(40, 170, 200), tongue = C(244, 124, 104), tab = C(40, 170, 200),
	base = C(40, 170, 200), stripe = C(40, 170, 200), logo = { kind = 'wave', color = K.snow }, tongueLabel = C(40, 170, 200),
})
def('Tidal', { Name = 'Tidal', Box = 'Ocean', rarity = 3,
	upper = C(24, 90, 130), ankle = C(20, 78, 116), heel = C(90, 210, 240), collar = C(20, 70, 110), tongue = C(20, 70, 110), tab = C(90, 210, 240),
	base = C(60, 180, 220), stripe = C(120, 230, 255), tongueLabel = C(120, 230, 255),
	deco = function(B, d)
		B:onShaft(function()
			A.wave(B, B.U + 0.46, 0.05, 0.9, C(200, 240, 255), 'smooth')
			A.wave(B, B.U + 0.26, 0.05, 0.9, C(90, 200, 235), 'smooth')
		end)
		A.toeBadge(B, d, 'star', C(110, 200, 255), 'smooth', 0.3)
	end,
})
def('Pearl', { Name = 'Pearl', Box = 'Ocean', rarity = 4,
	upper = C(40, 150, 180), ankle = C(30, 130, 164), heel = C(20, 60, 100), collar = C(20, 60, 100), tongue = C(160, 220, 235), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(40, 150, 180), base = C(20, 60, 100), stripe = C(170, 245, 255), toe = C(20, 60, 100),
	tongueLabel = K.snow,
	deco = function(B, d)
		-- a big pink pearl sitting on the toe in a gold cup
		local p = (B.slope * CF(0, 0.12, B.slopeLen * 0.14)).Position
		B:cyl('PearlCup', 0.08, 0.34, p - V(0, 0.08, 0), K.gold, 'gold', 'y')
		B:ball('Pearl', 0.3, p + V(0, 0.06, 0), C(255, 220, 236), 'gloss')
		B:onShaft(function()
			B:ball('Bubble', 0.16, V(SIDE_X + 0.05, B.U + 0.5, 0.2), C(200, 245, 255), 'glass')
			B:ball('Bubble', 0.1, V(SIDE_X + 0.05, B.U + 0.3, -0.05), C(200, 245, 255), 'glass')
		end)
		A.heelStrip(B, d, C(150, 240, 255))
	end,
})
def('DeepSea', { Name = 'Deep Sea', Box = 'Ocean', rarity = 5,
	upper = C(24, 60, 120), ankle = C(20, 50, 104), heel = C(80, 220, 240), collar = C(20, 50, 104), tongue = C(20, 50, 104), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(24, 60, 120), base = C(16, 40, 86), stripe = C(90, 235, 255), toe = C(24, 60, 120), toeKind = 'gloss',
	tongueLabel = C(90, 235, 255),
	deco = function(B, d)
		B:onShaft(function()
			A.wave(B, B.U + 0.36, 0.05, 0.95, C(90, 235, 255), 'neon')
			-- two fins on the back of the collar
			for _, f in { { L.XC - 0.15, 0.6, 0 }, { L.XC + 0.28, 0.45, 0 } } do
				B:tooth('Fin', 0.34, f[2], 0.06, CF(B.cat(f[1], 0.04, 0.52)) * ANG(0, rad(90), 0) * ANG(0, 0, rad(-14)), C(80, 220, 240), 'neon')
			end
		end)
	end,
})
def('Atlantis', { Name = 'Atlantis', Box = 'Ocean', rarity = 6,
	upper = C(20, 70, 110), ankle = C(16, 60, 96), heel = C(90, 230, 220), collar = C(30, 100, 140), tongue = C(20, 70, 110), upperKind = 'gloss',
	rainbowLaces = true, sole = C(60, 200, 210), base = C(30, 140, 170), rainbowStripe = true, rainbowOffset = 1, toe = C(20, 70, 110), toeKind = 'gloss',
	tongueLabel = C(255, 140, 170),
	deco = function(B, d)
		B:onShaft(function()
			-- coral branches on the back of the collar
			for i, c in { { L.XC - 0.2, 0.5, -10, C(255, 120, 150) }, { L.XC + 0.2, 0.62, 12, C(255, 150, 120) }, { L.XC + 0.5, 0.4, 24, C(255, 120, 150) } } do
				local cf = CF(B.cat(c[1], 0, 0.56)) * ANG(0, 0, rad(c[3]))
				B:box('Coral', V(0.08, c[2], 0.08), (cf * CF(0, c[2] / 2, 0)).Position, c[4], 'smooth', cf.Rotation)
				B:ball('CoralTip', 0.13, (cf * CF(0, c[2], 0)).Position, c[4], 'smooth')
			end
			-- a little jellyfish friend floating by the side
			local j = B.cat(1.05, 0.35, 0.05)
			B:ball('Jelly', 0.34, j, C(220, 180, 255), 'glass')
			for k = -1, 1 do B:box('JellyLeg', V(0.04, 0.28, 0.04), j + V(0, -0.26, k * 0.08), C(220, 180, 255), 'neon') end
		end)
		A.rainbowBand(B, d, 0.28, 1)
	end,
})

-- 08 Gem -----------------------------------------------------------------------------------------------------------
def('EmeraldKick', { Name = 'Emerald Kick', Box = 'Gem', rarity = 1,
	upper = C(30, 140, 72), ankle = C(26, 128, 64), heel = C(22, 116, 58), collar = K.snow, tongue = C(36, 152, 80), stripe = K.ink,
	logo = { color = C(255, 200, 50), glyph = 'dot', glyphColor = C(30, 140, 72), mat = 'gold' }, tongueLabel = C(255, 200, 50),
})
def('RubyRunner', { Name = 'Ruby Runner', Box = 'Gem', rarity = 2,
	upper = C(176, 26, 48), ankle = C(160, 20, 42), heel = C(255, 200, 50), collar = C(255, 200, 50), collarKind = 'gold', tongue = C(190, 34, 56),
	tab = C(255, 200, 50), base = C(255, 196, 50), stripe = C(255, 196, 50), logo = { kind = 'gem', color = C(240, 244, 255) }, tongueLabel = C(255, 200, 50),
})
def('Facet', { Name = 'Facet', Box = 'Gem', rarity = 3,
	upper = C(30, 150, 80), ankle = C(60, 190, 110), heel = C(20, 90, 50), collar = C(20, 90, 50), tongue = C(20, 90, 50), tab = C(20, 90, 50),
	base = C(60, 200, 130), stripe = C(130, 255, 180), tongueLabel = C(150, 255, 190),
	deco = function(B, d)
		-- facets: lighter and darker diamonds on the side
		A.speckles(B, d, { { 0.48, 0.22, 0.24, C(90, 220, 140), 45, 'Facet' }, { 0.3, -0.06, 0.22, C(20, 110, 60), 45, 'Facet' },
			{ 0.52, -0.32, 0.18, C(120, 240, 170), 45, 'Facet' }, { 0.22, 0.42, 0.14, C(20, 110, 60), 45, 'Facet' } }, 'smooth')
		A.toeBadge(B, d, 'gem', C(80, 230, 140), 'glass', 0.32)
	end,
})
def('DiamondStep', { Name = 'Diamond Step', Box = 'Gem', rarity = 4,
	upper = C(214, 230, 244), ankle = C(196, 216, 236), heel = C(255, 200, 50), collar = C(255, 200, 50), collarKind = 'gold', tongue = C(230, 240, 250),
	upperKind = 'gloss', eyelet = K.gold, eyeletKind = 'gold', sole = C(220, 236, 250), base = C(255, 196, 50), stripe = C(230, 250, 255),
	toe = C(255, 200, 50), toeKind = 'gold', tongueLabel = C(150, 220, 255),
	deco = function(B, d)
		A.speckles(B, d, { { 0.48, 0.22, 0.22, C(240, 250, 255), 45, 'Facet' }, { 0.3, -0.08, 0.2, C(170, 200, 230), 45, 'Facet' },
			{ 0.52, -0.32, 0.16, C(240, 250, 255), 45, 'Facet' } }, 'smooth')
		A.toeBadge(B, d, 'gem', C(210, 240, 255), 'glass', 0.34)
		A.heelStrip(B, d, C(200, 240, 255))
	end,
})
def('CrystalCrown', { Name = 'Crystal Crown', Box = 'Gem', rarity = 5,
	upper = C(24, 120, 66), ankle = C(20, 104, 56), heel = C(130, 255, 190), collar = C(16, 80, 44), tongue = C(16, 80, 44), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(24, 120, 66), base = C(14, 70, 40), stripe = C(130, 255, 180), toe = C(24, 120, 66), toeKind = 'gloss',
	tongueLabel = C(255, 90, 110),
	deco = function(B, d)
		A.crystals(B, d, C(150, 255, 200), 'glass', 6, 1.05)
		B:onShaft(function() A.gem(B, sideCF(B.U + 0.42, 0.06, 0.02), 0.28, C(255, 70, 100), 'glass') end)
		A.toeBadge(B, d, 'gem', C(255, 70, 100), 'glass', 0.28)
	end,
})
def('PrismCore', { Name = 'Prism Core', Box = 'Gem', rarity = 6,
	upper = C(20, 70, 44), ankle = C(16, 60, 38), heel = C(150, 255, 210), collar = C(16, 60, 38), tongue = C(20, 70, 44), upperKind = 'gloss',
	rainbowLaces = true, sole = C(60, 200, 130), base = C(30, 140, 90), rainbowStripe = true, rainbowOffset = 3, toe = C(20, 70, 44), toeKind = 'gloss',
	tongueLabel = C(200, 160, 255),
	deco = function(B, d)
		B:onShaft(function()
			for i, c in { { B.cat(L.XC + 0.38, 0.02, 0.5), 0.75, 10, RAINBOW[5] }, { B.cat(L.XC - 0.2, 0, 0.56), 0.6, -14, RAINBOW[6] },
				{ B.cat(0.6, 0, -0.25), 0.55, 18, RAINBOW[1] }, { B.cat(0.6, 0, 0.15), 0.45, 24, RAINBOW[3] } } do
				B:tooth('Prism', 0.28, c[2], 0.2, CF(c[1]) * ANG(0, rad(i * 50), 0) * ANG(0, 0, rad(c[3])), c[4], 'glass')
			end
		end)
		A.rainbowBand(B, d, 0.28, 3)
		A.toeBadge(B, d, 'gem', C(220, 240, 255), 'glass', 0.32)
	end,
})

-- 09 Galaxy --------------------------------------------------------------------------------------------------------
def('NightSky', { Name = 'Night Sky', Box = 'Galaxy', rarity = 1,
	upper = C(40, 70, 176), ankle = C(34, 62, 162), heel = C(30, 54, 148), collar = K.snow, tongue = C(48, 80, 188), stripe = K.ink,
	logo = { color = C(60, 200, 220), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(60, 200, 220),
})
def('Comet', { Name = 'Comet', Box = 'Galaxy', rarity = 2,
	upper = C(104, 72, 196), ankle = C(92, 62, 180), heel = C(220, 222, 236), collar = C(226, 228, 240), tongue = C(114, 82, 206), tab = C(226, 228, 240),
	base = C(150, 120, 230), stripe = C(150, 120, 230), logo = { kind = 'moon', color = C(255, 200, 50), mat = 'gold' }, tongueLabel = C(255, 200, 50),
})
def('Nebula', { Name = 'Nebula', Box = 'Galaxy', rarity = 3,
	upper = C(30, 28, 70), ankle = C(26, 24, 60), heel = C(170, 150, 255), collar = C(24, 22, 40), tongue = C(24, 22, 40), tab = C(170, 150, 255),
	base = C(150, 130, 230), stripe = C(190, 170, 255), tongueLabel = C(190, 170, 255),
	deco = function(B, d)
		A.splats(B, d, { { 0.44, 0.15, 0.3, C(90, 60, 170) }, { 0.3, -0.2, 0.22, C(150, 70, 170), nil, 1 } })
		A.speckles(B, d, { { 0.56, 0.35, 0.05, K.snow, 45 }, { 0.4, 0.42, 0.04, K.snow, 45 }, { 0.5, -0.05, 0.05, C(220, 210, 255), 45 },
			{ 0.22, 0.1, 0.04, K.snow, 45 }, { 0.58, -0.36, 0.04, K.snow, 45 } }, 'neon')
		A.toeBadge(B, d, 'star', C(190, 170, 255), 'smooth', 0.3)
	end,
})
def('Supernova', { Name = 'Supernova', Box = 'Galaxy', rarity = 4,
	upper = C(110, 70, 210), ankle = C(94, 58, 190), heel = C(30, 26, 60), collar = C(30, 26, 60), tongue = C(130, 90, 225), upperKind = 'gloss',
	lace = C(214, 200, 255), eyelet = K.gold, eyeletKind = 'gold', sole = C(30, 26, 60), base = C(22, 20, 44), stripe = C(200, 180, 255), toe = C(30, 26, 60),
	tongueLabel = K.snow,
	deco = function(B, d)
		B:onShaft(function()
			A.star(B, sideCF(B.U + 0.44, 0.1, 0.03), 0.34, K.snow, 'neon')
			A.star(B, sideCF(B.U + 0.26, -0.26, 0.03), 0.2, C(230, 220, 255), 'neon')
		end)
		A.heelStrip(B, d, C(200, 180, 255))
	end,
})
def('CosmicWings', { Name = 'Cosmic Wings', Box = 'Galaxy', rarity = 5,
	upper = C(30, 28, 80), ankle = C(26, 24, 68), heel = C(170, 140, 255), collar = C(24, 22, 50), tongue = C(24, 22, 50), upperKind = 'gloss',
	eyelet = K.gold, eyeletKind = 'gold', sole = C(30, 28, 80), base = C(20, 18, 50), stripe = C(190, 170, 255), toe = C(30, 28, 80), toeKind = 'gloss',
	tongueLabel = C(190, 170, 255),
	deco = function(B, d)
		A.wings(B, d, C(110, 70, 220), C(70, 50, 170), 'smooth', 1.15)
		A.speckles(B, d, { { 0.5, 0.3, 0.05, K.snow, 45 }, { 0.36, -0.1, 0.05, K.snow, 45 }, { 0.22, 0.2, 0.04, C(220, 210, 255), 45 } }, 'neon')
	end,
})
def('BlackHole', { Name = 'Black Hole', Box = 'Galaxy', rarity = 6,
	upper = C(22, 20, 32), ankle = C(18, 16, 26), heel = C(170, 120, 255), collar = C(34, 30, 52), tongue = C(22, 20, 32), upperKind = 'gloss',
	rainbowLaces = true, sole = C(40, 36, 70), base = C(24, 22, 44), rainbowStripe = true, rainbowOffset = 5, toe = C(22, 20, 32), toeKind = 'gloss',
	tongueLabel = C(200, 170, 255),
	deco = function(B, d)
		B:onShaft(function()
			-- a glowing ring round the ankle, tilted like an orbit, and a dark core on the side
			local cf = CF(L.XC + 0.05, B.U + 0.5, 0.05) * ANG(rad(12), 0, rad(-14))
			B:cyl('OrbitRing', 0.025, 2.0, cf.Position, C(200, 160, 255), 'neon', cf.Rotation * AXIS.y, { transp = 0.35 })
			sideDisc(B, 'HoleGlow', 0.34, B.U + 0.42, 0.08, C(190, 120, 255), 'neon', 0.016, 0.03)
			sideDisc(B, 'HoleCore', 0.22, B.U + 0.42, 0.08, C(8, 6, 14), 'smooth', 0.03, 0.03)
		end)
		A.speckles(B, d, { { 0.56, 0.36, 0.05, K.snow, 45 }, { 0.2, -0.3, 0.05, K.snow, 45 } }, 'neon')
		A.toeBadge(B, d, 'star', C(255, 220, 120), 'neon', 0.3)
	end,
})

-- 10 Gold ----------------------------------------------------------------------------------------------------------
def('GoldRush', { Name = 'Gold Rush', Box = 'Gold', rarity = 1,
	upper = C(222, 180, 52), ankle = C(210, 166, 44), heel = C(196, 152, 38), collar = K.snow, tongue = C(230, 190, 64), stripe = K.ink,
	logo = { color = C(84, 56, 170), glyph = 'plus', glyphColor = C(255, 210, 70) }, tongueLabel = C(84, 56, 170),
})
def('Royal', { Name = 'Royal', Box = 'Gold', rarity = 2,
	upper = C(64, 44, 156), ankle = C(54, 36, 140), heel = C(255, 200, 50), collar = C(255, 200, 50), collarKind = 'gold', tongue = C(74, 52, 168),
	tab = C(255, 200, 50), base = C(255, 196, 50), stripe = C(255, 196, 50), logo = { kind = 'plus1', color = C(255, 200, 50), mat = 'gold' },
	tongueLabel = C(255, 200, 50),
})
def('Monogram', { Name = 'Monogram', Box = 'Gold', rarity = 3,
	upper = C(54, 36, 130), ankle = C(46, 30, 116), heel = C(255, 200, 50), collar = C(46, 30, 116), tongue = C(46, 30, 116), tab = C(255, 200, 50),
	base = C(255, 196, 50), stripe = C(255, 220, 110), tongueLabel = C(255, 200, 50),
	deco = function(B, d)
		B:onShaft(function()
			A.plusOne(B, B.U + 0.44, 0.22, 0.22, C(255, 200, 50), 'gold', 0.03)
			A.plusOne(B, B.U + 0.28, -0.2, 0.16, C(255, 200, 50), 'gold', 0.03)
		end)
		A.toeBadge(B, d, 'crown', C(255, 200, 50), 'gold', 0.28)
	end,
})
def('TwentyFourKarat', { Name = '24 Karat', Box = 'Gold', rarity = 4,
	upper = C(255, 196, 50), ankle = C(240, 180, 40), heel = K.snow, collar = K.snow, tongue = C(255, 200, 60), upperKind = 'gold', tongueKind = 'gold',
	lace = C(84, 56, 170), eyelet = K.gold, eyeletKind = 'gold', sole = K.snow, base = C(255, 196, 50), stripe = C(255, 220, 110), tongueLabel = C(84, 56, 170),
	deco = function(B, d)
		B:onShaft(function() A.plusOne(B, B.U + 0.42, 0.08, 0.3, C(84, 56, 170), 'smooth', 0.03) end)
		A.heelStrip(B, d, C(255, 230, 140))
	end,
})
def('KingsCrown', { Name = "King's Crown", Box = 'Gold', rarity = 5,
	upper = C(64, 44, 156), ankle = C(54, 36, 140), heel = C(255, 200, 50), collar = C(54, 36, 140), tongue = C(54, 36, 140), upperKind = 'gloss',
	lace = C(255, 210, 70), eyelet = K.gold, eyeletKind = 'gold', sole = C(255, 196, 50), soleKind = 'gold', base = C(220, 150, 30), stripe = C(255, 230, 140),
	toe = C(255, 200, 50), toeKind = 'gold', tongueLabel = C(230, 40, 60),
	deco = function(B, d)
		B:onShaft(function()
			A.crown(B, CF(B.cat(L.XC + 0.02, 0.12, B.collarZ)) * ANG(0, math.pi, 0), 0.62, C(255, 200, 50), C(230, 40, 60))
		end)
		A.wings(B, d, C(255, 214, 90), C(240, 180, 50), 'gold', 1.05)
	end,
})
def('PlusOneInfinity', { Name = '+1 Infinity', Box = 'Gold', rarity = 6,
	upper = C(50, 34, 120), ankle = C(42, 28, 104), heel = C(255, 200, 50), collar = C(60, 42, 140), tongue = C(50, 34, 120), upperKind = 'gloss',
	rainbowLaces = true, sole = C(255, 196, 50), soleKind = 'gold', base = C(214, 150, 30), rainbowStripe = true, rainbowOffset = 2, toe = C(50, 34, 120),
	toeKind = 'gloss', tongueLabel = false,
	deco = function(B, d)
		B:onShaft(function()
			-- the infinity sign: two glowing rings side by side over the heel (rainbow), and a gold +1 on the side
			for i, sz in { -1, 1 } do
				local p = B.cat(L.XC + sz * 0.2, 0.42, 0.62)
				B:cyl('Infinity', 0.06, 0.4, p, RAINBOW[i == 1 and 1 or 5], 'neon', 'z')
				B:cyl('InfinityHole', 0.08, 0.2, p, C(50, 34, 120), 'smooth', 'z')
			end
			B:box('InfinityPost', V(0.06, 0.3, 0.06), B.cat(L.XC, 0.16, 0.62), K.gold, 'gold')
			A.plusOne(B, B.U + 0.42, 0.08, 0.3, C(255, 200, 50), 'gold', 0.03)
			A.plusOneFront(B, B.tongueFront * CF(0, 0.47, -0.02), 0.36, C(255, 200, 50), 'gold')
		end)
		A.rainbowBand(B, d, 0.22, 2)
	end,
})

-- Robux boxes (brief 21) ---------------------------------------------------------------------------------------------
-- Their own list, so Ids stays the 60 Cash-box shoes box by box.
local EXCLUSIVE = {}
local function xdef(id, t)
	t.Id = id
	DEFS[id] = t
	table.insert(EXCLUSIVE, id)
end
local ICE, PINKGLOW = C(90, 230, 255), C(255, 140, 220)
-- Exclusive Box: chrome, midnight, rainbow and hologram, ice-blue light.
xdef('SilverStreak', { Name = 'Silver Streak', Box = 'Exclusive', rarity = 2,
	upper = C(214, 222, 234), ankle = C(196, 206, 222), heel = C(40, 44, 62), collar = C(40, 44, 62), tongue = C(224, 230, 242), tab = ICE,
	upperKind = 'metal', base = C(40, 44, 62), stripe = ICE, logo = { kind = 'bolt', color = ICE, mat = 'neon' }, tongueLabel = ICE,
})
xdef('MidnightChrome', { Name = 'Midnight Chrome', Box = 'Exclusive', rarity = 3,
	upper = C(34, 36, 54), ankle = C(28, 30, 46), heel = C(204, 212, 226), collar = C(28, 30, 46), tongue = C(34, 36, 54), upperKind = 'gloss',
	lace = ICE, toe = C(204, 212, 226), toeKind = 'metal', sole = C(204, 210, 224), base = C(28, 30, 46), stripe = ICE, tab = ICE,
	tongueLabel = ICE,
	deco = function(B, d)
		B:onShaft(function() A.zigzag(B, B.U + 0.42, 0.06, 0.8, ICE, 'neon') end)
		A.toeBadge(B, d, 'sparkle', ICE, 'neon', 0.28)
	end,
})
xdef('RainbowDrip', { Name = 'Rainbow Drip', Box = 'Exclusive', rarity = 4, fx = { tex = 'sparkle', colors = { C(255, 120, 200), C(120, 220, 255), C(255, 236, 120) } },
	upper = C(246, 246, 250), ankle = C(236, 238, 244), heel = C(255, 90, 160), collar = C(255, 90, 160), tongue = C(246, 246, 250), upperKind = 'gloss',
	rainbowLaces = true, rainbowStripe = true, sole = K.snow, base = C(80, 200, 255), toe = C(80, 200, 255), tongueLabel = C(255, 90, 160),
	deco = function(B, d)
		A.drips(B, d, C(255, 90, 160), 'gloss', 3, 1.1)
		A.speckles(B, d, { { 0.5, 0.25, 0.07, RAINBOW[1], 45 }, { 0.36, -0.05, 0.07, RAINBOW[3], 45 }, { 0.22, 0.3, 0.06, RAINBOW[4], 45 },
			{ 0.46, -0.35, 0.06, RAINBOW[5], 45 }, { 0.26, -0.25, 0.06, RAINBOW[6], 45 } }, 'neon')
		A.heelStrip(B, d, C(120, 220, 255))
	end,
})
xdef('Hologram', { Name = 'Hologram', Box = 'Exclusive', rarity = 5, fx = { tex = 'sparkle', colors = { C(170, 240, 255), C(255, 170, 230) } },
	upper = C(226, 236, 255), ankle = C(214, 226, 250), heel = PINKGLOW, collar = C(120, 230, 240), tongue = C(232, 240, 255), upperKind = 'gloss',
	lace = C(255, 170, 230), sole = C(240, 244, 255), base = C(120, 230, 240), stripe = PINKGLOW, toe = C(214, 226, 250), toeKind = 'gloss',
	tongueLabel = C(120, 230, 240),
	deco = function(B, d)
		A.wings(B, d, C(170, 240, 255), C(255, 170, 230), 'gloss', 1.1)
		A.heelStrip(B, d, PINKGLOW)
		A.toeBadge(B, d, 'gem', C(120, 230, 240), 'glass', 0.26)
	end,
})
xdef('PlatinumWings', { Name = 'Platinum Wings', Box = 'Exclusive', rarity = 6,
	upper = C(226, 232, 242), ankle = C(208, 216, 230), heel = ICE, collar = C(70, 80, 110), tongue = C(226, 232, 242), upperKind = 'metal',
	rainbowLaces = true, eyelet = K.gold, eyeletKind = 'gold', sole = C(240, 244, 250), base = ICE, rainbowStripe = true, rainbowOffset = 3,
	toe = C(208, 216, 230), toeKind = 'metal', tongueLabel = false,
	deco = function(B, d)
		A.wings(B, d, C(250, 250, 255), C(200, 236, 255), 'smooth', 1.25)
		A.rainbowBand(B, d, 0.26, 3)
		A.toeBadge(B, d, 'gem', ICE, 'glass', 0.28)
	end,
})
-- Grail Box: gold, starlight, sun flares and royal purple.
local SUN, GOLDEN, ROYAL = C(255, 120, 60), C(255, 205, 60), C(80, 40, 160)
xdef('GoldenHour', { Name = 'Golden Hour', Box = 'Grail', rarity = 2,
	upper = C(255, 196, 52), ankle = C(240, 176, 40), heel = SUN, collar = K.snow, tongue = C(255, 206, 72), tab = SUN, upperKind = 'gold',
	base = SUN, stripe = C(255, 150, 80), logo = { kind = 'sparkle', color = SUN }, tongueLabel = SUN,
})
xdef('Starlight', { Name = 'Starlight', Box = 'Grail', rarity = 3,
	upper = C(28, 34, 90), ankle = C(24, 28, 76), heel = C(255, 214, 80), collar = C(24, 28, 76), tongue = C(28, 34, 90), tab = C(255, 214, 80),
	lace = C(240, 240, 255), base = C(255, 200, 60), stripe = C(255, 224, 120), tongueLabel = C(255, 214, 80),
	deco = function(B, d)
		B:onShaft(function() A.star(B, sideCF(B.U + 0.44, 0.12, 0.03), 0.34, C(255, 214, 80), 'gold') end)
		A.speckles(B, d, { { 0.56, 0.35, 0.05, K.snow, 45 }, { 0.3, -0.2, 0.05, C(255, 236, 160), 45 }, { 0.2, 0.3, 0.04, K.snow, 45 },
			{ 0.5, -0.36, 0.04, C(255, 236, 160), 45 } }, 'neon')
		A.toeBadge(B, d, 'star', C(255, 214, 80), 'gold', 0.28)
	end,
})
xdef('SolarFlare', { Name = 'Solar Flare', Box = 'Grail', rarity = 4, fx = { tex = 'ember', colors = { C(255, 200, 60), C(255, 120, 40) } },
	upper = C(255, 176, 40), ankle = C(255, 150, 30), heel = C(60, 30, 20), collar = C(60, 30, 20), tongue = C(255, 190, 60), upperKind = 'gloss',
	lace = C(255, 240, 200), eyelet = K.gold, eyeletKind = 'gold', sole = C(60, 30, 20), base = C(255, 90, 40), stripe = C(255, 220, 90),
	toe = C(255, 90, 40), tongueLabel = C(255, 70, 40),
	deco = function(B, d)
		A.collarFlames(B, d, C(255, 110, 40), C(255, 230, 90), 'smooth')
		B:onShaft(function() A.flame(B, sideCF(B.U + 0.3, 0.05, 0.022, 0), 0.5, C(255, 90, 40), K.gold, 'smooth') end)
	end,
})
xdef('AstroCrown', { Name = 'Astro Crown', Box = 'Grail', rarity = 5, fx = { tex = 'star', colors = { C(255, 214, 90), C(190, 150, 255) } },
	upper = ROYAL, ankle = C(66, 32, 140), heel = GOLDEN, collar = C(30, 20, 60), tongue = C(30, 20, 60), upperKind = 'gloss',
	lace = C(255, 214, 80), eyelet = K.gold, eyeletKind = 'gold', sole = C(30, 20, 60), base = C(255, 196, 50), stripe = C(190, 150, 255),
	toe = GOLDEN, toeKind = 'gold', tongueLabel = C(255, 214, 80),
	deco = function(B, d)
		B:onShaft(function()
			A.crown(B, CF(B.cat(L.XC + 0.02, 0.12, B.collarZ)) * ANG(0, math.pi, 0), 0.62, GOLDEN, C(120, 220, 255))
		end)
		A.wings(B, d, C(190, 150, 255), GOLDEN, 'smooth', 1.05)
		A.speckles(B, d, { { 0.2, 0.25, 0.05, K.snow, 45 }, { 0.3, -0.3, 0.05, K.snow, 45 } }, 'neon')
	end,
})
xdef('TheGrail', { Name = 'The Grail', Box = 'Grail', rarity = 6,
	upper = C(255, 200, 56), ankle = C(240, 180, 40), heel = C(170, 90, 255), collar = C(110, 50, 190), tongue = C(255, 206, 72), upperKind = 'gold',
	tongueKind = 'gold', rainbowLaces = true, sole = K.snow, base = C(170, 90, 255), rainbowStripe = true, rainbowOffset = 4,
	toe = C(170, 90, 255), toeKind = 'gloss', tongueLabel = false,
	deco = function(B, d)
		A.wings(B, d, C(250, 250, 255), C(232, 236, 248), 'smooth', 1.2)
		A.rainbowBand(B, d, 0.26, 4)
		B:onShaft(function() A.plusOneFront(B, B.tongueFront * CF(0, 0.47, -0.02), 0.36, C(170, 90, 255), 'gloss') end)
		A.toeBadge(B, d, 'gem', C(170, 90, 255), 'glass', 0.28)
	end,
})

ShoeModels.Ids = ORDER
ShoeModels.ExclusiveIds = EXCLUSIVE
ShoeModels.AllIds = table.move(EXCLUSIVE, 1, #EXCLUSIVE, #ORDER + 1, table.clone(ORDER))
ShoeModels.Defs = DEFS
local ALIAS = { ['24Karat'] = 'TwentyFourKarat', Karat24 = 'TwentyFourKarat', ['PlusOne Infinity'] = 'PlusOneInfinity', KingSCrown = 'KingsCrown' }
local function resolve(id)
	local d = DEFS[id] or DEFS[ALIAS[id] or '']
	assert(d, 'ShoeModels: unknown shoe id ' .. tostring(id))
	return d
end

---------------------------------------------------------------------------------------------- recipe
-- Fill the defaults for a definition (by rarity), once.
local function filled(d)
	if d._filled then return d end
	local r = d.rarity
	d.sole = d.sole or K.white
	d.toe = d.toe or d.sole
	d.collar = d.collar or K.snow
	d.lace = d.lace or K.snow
	d.eyelet = d.eyelet or K.silver
	d.stripe = d.stripe or K.ink
	if not d.tab and d.logo and d.rarity == 1 then d.tab = d.logo.color end
	d._filled = true
	return d
end

-- The specs of the right shoe for a definition.
local function recipe(d)
	d = filled(d)
	local B = newBuilder(d)
	local U = L.SOLE[d.rarity]
	B.U = U
	buildSole(B, d, U)
	buildUpper(B, d, U)
	buildFront(B, d, U)
	if d.rainbowLaces then
		local i = 0
		for _, s in B.list do
			if s.name == 'Lace' then
				i += 1
				s.color = RAINBOW[(i - 1) % #RAINBOW + 1]
				s.kind = 'smooth'
			end
		end
	end
	A.logo(B, d)
	if d.deco then d.deco(B, d) end
	return B.list
end

-- Specs are cached per id (they're plain data and never change).
local cache = {}
local function specs(id)
	local d = resolve(id)
	local list = cache[d.Id]
	if not list then
		list = recipe(d)
		cache[d.Id] = list
	end
	return list, d
end
ShoeModels._specs = specs

---------------------------------------------------------------------------------------------- building
-- Scale a part-local CFrame by a per-axis factor, keeping its rotation, and the size by the same factor seen along
-- the piece's own axes (as SkinArt does).
local function scaled(cf, size, f)
	if f == V(1, 1, 1) then return cf, size end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local sx = r00 * r00 * f.X + r10 * r10 * f.Y + r20 * r20 * f.Z
	local sy = r01 * r01 * f.X + r11 * r11 * f.Y + r21 * r21 * f.Z
	local sz = r02 * r02 * f.X + r12 * r12 * f.Y + r22 * r22 * f.Z
	return CF(x * f.X, y * f.Y, z * f.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22), V(size.X * sx, size.Y * sy, size.Z * sz)
end

local FIT = V(1, 0.3, 1)
local MIN = 0.01
-- Make one part from a spec. `cf` is final (world or host-relative), `size` final.
local function makePart(spec, cf, size)
	local p
	if spec.cls == 'WedgePart' then
		p = Instance.new('WedgePart')
	else
		p = Instance.new('Part')
		if spec.shape == 'Cylinder' then
			p.Shape = Enum.PartType.Cylinder
		elseif spec.shape == 'Ball' then
			p.Shape = Enum.PartType.Ball
		end
	end
	local k = KIND[spec.kind] or KIND.smooth
	p.Name = spec.name
	p.Size = V(math.max(size.X, MIN), math.max(size.Y, MIN), math.max(size.Z, MIN))
	p.CFrame = cf
	p.Color = spec.color
	p.Material = k[1]
	p.Reflectance = k[2]
	p.Transparency = spec.transp or k[3]
	-- small pieces, glow and glass cast no shadow (cheaper, cleaner)
	p.CastShadow = k[4] and math.max(size.X, size.Y, size.Z) > 0.3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	if spec.shaft then p:SetAttribute('Shaft', true) end
	if spec.studsBottom then p.BottomSurface = Enum.SurfaceType.Studs end
	return p
end

-- A spec's CFrame relative to the Fit box (the foot's centre), for one side.
local function fitCF(spec, side)
	local cf = spec.cf
	if side == 'L' then
		cf = mirrorX(cf)
		if spec.text then cf = unmirrorText(cf, spec.text) end
	end
	return CF(0, -FIT.Y / 2, 0) * cf
end

local function newFit(k)
	local fit = Instance.new('Part')
	fit.Name = 'Fit'
	fit.Size = FIT * k
	fit.Transparency = 1
	fit.CastShadow = false
	fit.Anchored = true
	fit.CanCollide = false
	fit.CanTouch = false
	fit.CanQuery = false
	fit.Massless = true
	return fit
end

-- One shoe as an anchored Model. side 'L' | 'R'; scale 1 = on a canonical R15 foot. Pivot = Fit.
function ShoeModels.shoe(id: string, side: string?, scale: number?): Model
	local list, d = specs(id)
	side = side == 'L' and 'L' or 'R'
	local k = scale or 1
	local m = Instance.new('Model')
	m.Name = d.Id .. '_' .. side
	local fit = newFit(k)
	fit.CFrame = CFrame.identity
	fit.Parent = m
	for _, s in list do
		local cf = fitCF(s, side)
		makePart(s, CF(cf.Position * k) * cf.Rotation, s.size * k).Parent = m
	end
	m.PrimaryPart = fit
	m:SetAttribute('ShoeId', d.Id)
	m:SetAttribute('Side', side)
	m:SetAttribute('Rarity', d.rarity)
	m:SetAttribute('Scale', k)
	return m
end

ShoeModels.PairGap = 0.62 -- foot centres at +-0.56 on displays (worn feet are at +-0.5)
-- Both shoes, right shoe at +X (as worn, toes toward -Z). PrimaryPart `Root` = the soles' centre on the ground.
function ShoeModels.pair(id: string, scale: number?): Model
	local _, d = specs(id)
	local k = scale or 1
	local m = Instance.new('Model')
	m.Name = d.Id
	local root = Instance.new('Part')
	root.Name = 'Root'
	root.Size = V(0.2, 0.2, 0.2) * k
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CastShadow = false
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Parent = m
	for _, side in { 'L', 'R' } do
		local shoe = ShoeModels.shoe(d.Id, side, k)
		local at = CF((side == 'R' and 1 or -1) * ShoeModels.PairGap * k, FIT.Y / 2 * k, 0)
		for _, p in shoe:GetDescendants() do
			if p:IsA('BasePart') then p.CFrame = at * p.CFrame end
		end
		shoe.Parent = m
	end
	m.PrimaryPart = root
	m:SetAttribute('ShoeId', d.Id)
	m:SetAttribute('Rarity', d.rarity)
	m:SetAttribute('Scale', k)
	return m
end

-- Unanchor and weld every part of a shoe/pair model to its PrimaryPart (for followers moved by physics).
function ShoeModels.weld(model: Model): Model
	local root = model.PrimaryPart
	assert(root, 'ShoeModels.weld: model has no PrimaryPart')
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') and d ~= root then
			local w = Instance.new('WeldConstraint')
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
		end
	end
	root.Anchored = false
	return model
end

---------------------------------------------------------------------------------------------- wearing
-- The evolution looks' own shoe pieces (SkinArt): hidden while shoes are worn (they sit inside the shoe anyway).
local COSTUME_SHOE = {
	Sole = true, Shoe = true, ToeCap = true, Swoosh = true, HighTop = true, Boot = true, BootShaft = true, BootLace = true,
	ShoeToe = true, Wingtip = true, LeftFootCover = true, RightFootCover = true,
	-- low bands on the shins (socks, trouser cuffs): inside the shoe, but they poke through its front face
	Sock = true, SockStripe = true, JoggerCuff = true, JeanCuff = true, PegCuff = true,
}
ShoeModels.CostumeShoePieces = COSTUME_SHOE
local function hideCostumeShoes(costume, hidden)
	for _, p in costume:GetDescendants() do
		if p:IsA('BasePart') and COSTUME_SHOE[p.Name] and p:GetAttribute('ShoeHidden') == nil then
			p:SetAttribute('ShoeHidden', p.Transparency)
			p.Transparency = 1
			table.insert(hidden, p)
		end
	end
end

local wornState = setmetatable({}, { __mode = 'k' })

-- Weld the pair onto a character. R15: shoe body to Left/RightFoot, the shaft (collar, tongue, ankle panel) to
-- Left/RightLowerLeg. R6: everything to the bottom of Left/Right Leg. Scaled per axis to the real parts.
-- opts.noFx: skip the rarity effects. Returns cleanup() (also called by wearing another pair).
function ShoeModels.wear(character: Model, id: string, opts: { noFx: boolean? }?): () -> ()
	opts = opts or {}
	local list, d = specs(id)
	local old = wornState[character]
	if old then old() end
	local stale = character:FindFirstChild('HoodShoes')
	if stale then stale:Destroy() end
	local r15 = character:FindFirstChild('LeftFoot') ~= nil or character:FindFirstChild('RightFoot') ~= nil
	local m = Instance.new('Model')
	m.Name = 'HoodShoes'
	m:SetAttribute('ShoeId', d.Id)
	local fxHosts = {}
	for _, side in { 'L', 'R' } do
		local word = side == 'L' and 'Left' or 'Right'
		local foot, leg, f, fLeg, anchorFoot, anchorLeg
		if r15 then
			foot = character:FindFirstChild(word .. 'Foot')
			leg = character:FindFirstChild(word .. 'LowerLeg')
			if foot and foot:IsA('BasePart') then
				f = foot.Size / FIT
				if leg and leg:IsA('BasePart') then
					local fl = leg.Size / V(1, 1.193, 1)
					fLeg = V(math.max(f.X, fl.X), f.Y, math.max(f.Z, fl.Z))
				end
			end
		else
			foot = character:FindFirstChild(word .. ' Leg')
			if foot and foot:IsA('BasePart') then
				f = V(foot.Size.X, foot.Size.Y / 2, foot.Size.Z)
				-- the Fit box's centre sits 0.15 (scaled) above the leg's bottom face
				anchorFoot = CF(0, -foot.Size.Y / 2 + FIT.Y / 2 * f.Y, 0)
			end
		end
		if foot and foot:IsA('BasePart') and f then
			for _, s in list do
				local host, c0, size = foot, nil, nil
				local cf = fitCF(s, side)
				if r15 and s.shaft and leg and leg:IsA('BasePart') and fLeg then
					-- shaft pieces: measured from the top of the foot = the bottom of the lower leg
					host = leg
					anchorLeg = CF(0, -leg.Size.Y / 2, 0)
					local rel, sz = scaled(CF(0, -FIT.Y / 2, 0) * cf, s.size, fLeg)
					c0, size = anchorLeg * rel, sz
				else
					local rel, sz = scaled(cf, s.size, f)
					c0, size = (anchorFoot or CFrame.identity) * rel, sz
				end
				local p = makePart(s, host.CFrame * c0, size)
				p.Name = s.name
				p.Anchored = false
				p.CastShadow = false
				local w = Instance.new('Weld')
				w.Name = 'ShoeWeld'
				w.Part0 = host
				w.Part1 = p
				w.C0 = c0
				w.Parent = p
				p.Parent = m
			end
			table.insert(fxHosts, { foot, (anchorFoot or CFrame.identity), f })
		end
	end
	m.Parent = character
	-- hide the look's own shoe pieces, now and whenever the look is re-dressed
	local hidden = {}
	local costume = character:FindFirstChild('BlockCostume')
	if costume then hideCostumeShoes(costume, hidden) end
	local conn
	pcall(function()
		conn = character.ChildAdded:Connect(function(child)
			if child.Name == 'BlockCostume' then hideCostumeShoes(child, hidden) end
		end)
	end)
	if not opts.noFx and d.rarity >= 3 then
		for i, h in fxHosts do ShoeModels.fx(m, d.rarity, { worn = true, host = h[1], at = h[2], scale = h[3], box = d.Box, id = d.Id, light = i == #fxHosts }) end
	end
	local done = false
	local function cleanup()
		if done then return end
		done = true
		if conn then conn:Disconnect() end
		for _, p in hidden do
			if p.Parent then
				local t = p:GetAttribute('ShoeHidden')
				if type(t) == 'number' then p.Transparency = t end
				p:SetAttribute('ShoeHidden', nil)
			end
		end
		m:Destroy()
		if wornState[character] == cleanup then wornState[character] = nil end
	end
	wornState[character] = cleanup
	return cleanup
end

---------------------------------------------------------------------------------------------- effects
-- Theme particles per box (texture names from hood/art/vfx; in game each falls back to a Roblox built-in until the
-- sheets are uploaded into HoodVFX.Textures). Colours: the box's own.
local THEME = {
	Street = { tex = 'star', colors = { C(255, 110, 120), C(255, 150, 130) } },
	Graffiti = { tex = 'glow', colors = { C(255, 110, 190), C(110, 230, 255), C(150, 255, 110) } },
	Frost = { tex = 'snow', colors = { C(230, 245, 255), C(170, 220, 255) } },
	Lava = { tex = 'ember', colors = { C(255, 170, 60), C(255, 90, 40) } },
	Toxic = { tex = 'glow', colors = { C(160, 255, 90), C(110, 230, 70) } },
	Candy = { tex = 'confetti', colors = { C(255, 140, 200), C(150, 200, 255), C(255, 230, 120) } },
	Ocean = { tex = 'bubble', colors = { C(190, 240, 255), C(120, 220, 255) } },
	Gem = { tex = 'shard', colors = { C(150, 255, 200), C(220, 250, 255) } },
	Galaxy = { tex = 'star', colors = { C(220, 210, 255), C(170, 140, 255) } },
	Gold = { tex = 'sparkle', colors = { C(255, 220, 90), C(255, 190, 40) } },
	Exclusive = { tex = 'sparkle', colors = { C(170, 240, 255), C(255, 170, 230) } },
	Grail = { tex = 'star', colors = { C(255, 220, 90), C(200, 150, 255) } },
}
ShoeModels.Themes = THEME
local BUILTIN = {
	star = 'rbxasset://textures/particles/sparkles_main.dds', sparkle = 'rbxasset://textures/particles/sparkles_main.dds',
	glow = 'rbxasset://textures/glow.png', snow = 'rbxasset://textures/particles/sparkles_main.dds', ember = 'rbxasset://textures/glow.png',
	confetti = 'rbxasset://textures/particles/sparkles_main.dds', bubble = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
	shard = 'rbxasset://textures/particles/sparkles_main.dds', softglow = 'rbxasset://textures/glow.png', ray = 'rbxasset://textures/glow.png',
	ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
}
local okVFX, HoodVFX = pcall(function()
	local m = script.Parent.Parent:FindFirstChild('HoodVFX')
	return m and require(m)
end)
local function setTexture(e, name)
	local id = okVFX and HoodVFX and HoodVFX.Textures and HoodVFX.Textures[name]
	e.Texture = (id and id ~= '') and id or BUILTIN[name] or BUILTIN.glow
	e:SetAttribute('PreviewTexture', name)
end
local function nseq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
local function cseq(colors)
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local k = {}
	for i, c in colors do table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)) end
	return ColorSequence.new(k)
end
local function emitter(parent, name, tex, props)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 0.6
	e.Rotation = NumberRange.new(0, 360)
	for key, v in props do (e :: any)[key] = v end
	setTexture(e, tex)
	e.Parent = parent
	return e
end

-- Rarity effects on a shoe, a pair or worn shoes. Escalates like the mock-ups: Epic themed particles, Legendary
-- + a soft glow and a light, Mythic + a light shaft, Secret + rainbow colours and a ground ring.
-- opts.worn (smaller, sparser), opts.host/at/scale (worn: the foot part to weld the emitter box to).
-- Live particles (display pair): Epic ~6, Legendary ~14, Mythic ~22, Secret ~32; worn about half per foot.
function ShoeModels.fx(model: Instance, rarity: any, opts: { [string]: any }?): Part?
	opts = opts or {}
	local r = type(rarity) == 'number' and rarity or table.find(RARITIES, rarity) or 1
	if r < 2 then return nil end
	local sid = opts.id or model:GetAttribute('ShoeId')
	local sdef = sid and DEFS[sid]
	local box = opts.box or (sdef and sdef.Box) or 'Street'
	local theme = THEME[box] or THEME.Street
	if sdef and sdef.fx then theme = { tex = sdef.fx.tex or theme.tex, colors = sdef.fx.colors or theme.colors } end
	local worn = opts.worn
	-- the emitter box: round the pair (display) or round one foot's shoe (worn)
	local holder = Instance.new('Part')
	holder.Name = 'ShoeFX'
	holder.Transparency = 1
	holder.CastShadow = false
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Massless = true
	local k
	if worn and opts.host then
		local f = opts.scale or V(1, 1, 1)
		k = (f.X + f.Z) / 2
		holder.Size = V(1.4, 1.1, 1.6) * k
		local c0 = (opts.at or CFrame.identity) * CF(0, 0.45 * f.Y, -0.1 * f.Z)
		holder.CFrame = opts.host.CFrame * c0
		holder.Anchored = false
		local w = Instance.new('Weld')
		w.Part0 = opts.host
		w.Part1 = holder
		w.C0 = c0
		w.Parent = holder
	else
		local root = model:IsA('Model') and model.PrimaryPart or model
		k = (model:GetAttribute('Scale') or 1)
		local isPair = model:IsA('Model') and model:FindFirstChild('Root') ~= nil
		holder.Size = (isPair and V(2.6, 1.4, 1.8) or V(1.4, 1.4, 1.8)) * k
		local base = root and root.CFrame or CFrame.identity
		local up = isPair and 0.7 * k or 0.55 * k
		holder.CFrame = base * CF(0, up, -0.1 * k)
		holder.Anchored = root == nil or root.Anchored
		if root and not root.Anchored then
			local w = Instance.new('WeldConstraint')
			w.Part0 = root
			w.Part1 = holder
			w.Parent = holder
		end
	end
	holder.Parent = model
	local secret = r >= 6
	local colors = secret and RAINBOW or theme.colors
	local dens = worn and 0.45 or 1
	local sz = (worn and 0.75 or 1) * k
	-- 1. themed particles drifting up (Epic+): stars, snow, embers, bubbles, coins...
	if r >= 3 then
		local rate = ({ 0, 0, 3, 5, 7, 10 })[r] * dens
		local s = ({ 0, 0, 0.32, 0.38, 0.42, 0.48 })[r] * sz
		emitter(holder, 'ShoeMotes', theme.tex, {
			Rate = rate, Lifetime = NumberRange.new(1.3, 2.1), Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(25, 25),
			Acceleration = V(0, box == 'Frost' and -0.4 or 0.6, 0), Drag = 0.6, RotSpeed = NumberRange.new(-60, 60),
			Size = nseq({ { 0, 0 }, { 0.2, s, s * 0.3 }, { 0.8, s * 0.8 }, { 1, 0 } }),
			Transparency = nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.75, 0.2 }, { 1, 1 } }),
			Color = cseq(colors), LightEmission = (box == 'Ocean' or box == 'Candy') and 0.3 or 0.8, Brightness = 1.2,
			ZOffset = 0.5, EmissionDirection = Enum.NormalId.Top,
		})
	elseif r == 2 then
		emitter(holder, 'ShoeGlint', 'sparkle', {
			Rate = 0.8 * dens, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0), RotSpeed = NumberRange.new(-40, 40),
			Size = nseq({ { 0, 0 }, { 0.4, 0.35 * sz }, { 1, 0 } }), Color = ColorSequence.new(C(255, 255, 255)), LightEmission = 1, ZOffset = 1,
		})
	end
	-- 2. soft glow behind and a light (Legendary+)
	if r >= 4 then
		local glow = secret and C(255, 255, 255) or theme.colors[1]
		local hot = 1 - math.max(0, 0.299 * glow.R + 0.587 * glow.G + 0.114 * glow.B - 0.55)
		emitter(holder, 'ShoeGlow', 'softglow', {
			Rate = 0.8, Lifetime = NumberRange.new(2.2), Speed = NumberRange.new(0), Rotation = NumberRange.new(0),
			Size = nseq({ { 0, (worn and 2.0 or 2.7) * k }, { 1, (worn and 2.3 or 3.0) * k } }),
			-- pale additive glows stack to white in daylight: keep the halo faint (dimmer still for pale colours)
			Transparency = nseq({ { 0, 1 }, { 0.4, 1 - hot * (worn and 0.14 or 0.2) }, { 0.6, 1 - hot * (worn and 0.14 or 0.2) }, { 1, 1 } }),
			Color = secret and cseq(RAINBOW) or ColorSequence.new(glow), LightEmission = 1, ZOffset = -1, Shape = Enum.ParticleEmitterShape.Box,
		})
		if not worn or (r >= 5 and opts.light ~= false) then
			local l = Instance.new('PointLight')
			l.Name = 'ShoeLight'
			l.Color = glow
			-- a soft pool of the shoe's colour, not a floodlight: pale floors wash out under bright lights
			l.Brightness = ({ 0, 0, 0, 0.45, 0.6, 0.75 })[r] * (worn and 0.7 or 1)
			l.Range = (worn and 4 or 5.5) * k
			l.Shadows = false
			l.Parent = holder
		end
	end
	-- 3. a light shaft rising from the shoes (Mythic+, displays and followers only)
	if r >= 5 and not worn then
		emitter(holder, 'ShoeRays', 'ray', {
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Rate = 1.2, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(0.05),
			Rotation = NumberRange.new(0), Size = nseq({ { 0, 3.2 * k }, { 1, 3.6 * k } }),
			Transparency = nseq({ { 0, 1 }, { 0.4, 0.55 }, { 0.6, 0.55 }, { 1, 1 } }),
			Color = secret and cseq(RAINBOW) or cseq({ C(255, 255, 255), theme.colors[1] }), LightEmission = 1, ZOffset = -0.5,
		})
	end
	-- 4. Secret: a rainbow ring on the ground and extra sparkles
	if secret and not (worn and opts.light == false) then
		local base = Instance.new('Attachment')
		base.Name = 'ShoeFXBase'
		base.CFrame = CF(0, -holder.Size.Y / 2 + 0.05 * k, 0)
		base.Parent = holder
		emitter(base, 'ShoeRing', 'ring', {
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NumberRange.new(0.01), Rate = worn and 0.4 or 0.7,
			Lifetime = NumberRange.new(1.6), Rotation = NumberRange.new(0), EmissionDirection = Enum.NormalId.Top,
			Size = nseq({ { 0, 0.8 * k }, { 1, (worn and 2.2 or 3.4) * k } }), Transparency = nseq({ { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } }),
			Color = cseq(RAINBOW), LightEmission = 1,
		})
		emitter(holder, 'ShoeSparkle', 'sparkle', {
			Rate = 5 * dens, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.3, 1), RotSpeed = NumberRange.new(-90, 90),
			Size = nseq({ { 0, 0 }, { 0.4, 0.3 * sz, 0.1 * sz }, { 1, 0 } }), Color = cseq(RAINBOW), LightEmission = 1, Brightness = 2, ZOffset = 1,
		})
	end
	return holder
end

---------------------------------------------------------------------------------------------- viewport
ShoeModels.View = V(-0.45, 0.38, -0.8).Unit -- from the pair toward the camera (front, a little to the right, above), as the mock-ups
function ShoeModels.viewport(id: string, size: UDim2?): ViewportFrame
	local _, d = specs(id)
	local vf = Instance.new('ViewportFrame')
	vf.Name = d.Id
	vf.Size = size or UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = C(170, 172, 182)
	vf.LightColor = C(255, 248, 236)
	vf.LightDirection = V(0.5, -1, 0.6)
	local m = ShoeModels.pair(d.Id, 1)
	m.Parent = vf
	local cam = Instance.new('Camera')
	cam.FieldOfView = 30
	local centre = V(0, 0.65, -0.1)
	local radius = 1.75
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2))
	cam.CFrame = CFrame.lookAt(centre + ShoeModels.View * dist, centre)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

---------------------------------------------------------------------------------------------- meta
ShoeModels.Meta = {}
for _, id in ShoeModels.AllIds do
	local d = DEFS[id]
	ShoeModels.Meta[id] = { Name = d.Name, Box = d.Box, Rarity = d.rarity, RarityName = RARITIES[d.rarity] }
end
-- Part count of one shoe (the Fit box not counted), computed on first use.
function ShoeModels.parts(id: string): number
	local list = specs(id)
	return #list
end
setmetatable(ShoeModels.Meta, {})
for _, id in ShoeModels.AllIds do
	setmetatable(ShoeModels.Meta[id], { __index = function(t, key)
		if key == 'Parts' then
			local n = ShoeModels.parts(id)
			rawset(t, 'Parts', n)
			return n
		end
		return nil
	end })
end

return ShoeModels
