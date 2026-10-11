-- The 60 shoes of the 10 shoe boxes (Config/Shoes.lua ids) and the 10 exclusive shoes of the two Robux boxes
-- (Exclusive, Grail; Rare..Secret, no Commons), built from plain Parts, wedges, cylinders, balls and ellipsoids (a Part
-- with a Sphere SpecialMesh: no upload). Chunky cartoon sneakers after the Blender mock-ups in the shoe brief.
-- (brief 28) Rebuilt as one cohesive, crafted sneaker: a single upper mass with flat walls and chamfered heel corners,
-- a two-layer sole with a toe spring, a rubber toe cap and a low dome, a lace bed with crossed round laces, a tall
-- tongue, a round padded collar ring with a dark lining, and flush colour skins. Rarity shows as one finish step per
-- tier (fabric, then a glossy toe cap, a silver heel counter, gold trims and the air window, a glowing midsole line, a
-- rainbow outsole). The rarity effects are Shared/ShoeFX.
--
--   ShoeModels.shoe(id, side, scale) -> Model   one shoe ('L' or 'R'); PrimaryPart `Fit` is an invisible box the size
--                                              of a canonical R15 foot (1, 0.3, 1), centred where the foot goes, toe -Z
--   ShoeModels.pair(id, scale) -> Model        both shoes side by side (displays, followers); PrimaryPart `Root` sits at
--                                              the soles' centre, so the pivot is on the ground between the shoes
--   ShoeModels.wear(character, id, opts?) -> cleanup()
--                                              welds the pair onto an R15 (feet, and the lower legs for the tongue) or
--                                              an R6 character (leg bottoms), scaled to the real parts and a size up
--                                              (WornChunk); adds the worn rarity effects (opts.noFx skips them,
--                                              opts.fxDensity thins them)
--   ShoeModels.fx(model, rarity, opts?)        rarity effects on a pair or shoe: ShoeFX.apply with the shoe's theme
--                                              (followers, displays; client side)
--   ShoeModels.viewport(id, size?) -> ViewportFrame   the pair, framed like the mock-ups (kept for old callers)
--   ShoeModels.Ids (the 60 Cash-box shoes, box by box), ShoeModels.ExclusiveIds (the 10 Robux-box shoes),
--   ShoeModels.AllIds (all 70), ShoeModels.Meta[id] = { Name, Box, Rarity, RarityName, Parts } (all 70),
--   ShoeModels.Rarities
--
-- How a shoe is made: one shared sneaker kit (outsole, midsole, toe cap and dome, quarter and heel, heel cup and
-- counter, lace bed with its strip and laces, tongue, collar ring with lining and pull loop) dressed per shoe by a
-- definition (colours, materials, panels) and a few accents (wings, flames, crystals, drips, crowns, stars, splats,
-- bubbles...). Every part is authored once for the RIGHT shoe in "foot space" (studs, ground at y = 0, the foot's centre
-- at x = z = 0, outer side +X, toe -Z) and mirrored for the left shoe. Parts are recorded as specs first, so the same
-- shoe can be built anchored (displays) or welded and stretched per axis onto a real foot (wear).
--
-- Fit on a character: the canonical R15 foot is 1 x 0.3 x 1 and both feet touch at the body's centre line, so each
-- shoe hangs over its foot on the OUTER side only (inner faces stay on the foot's inner plane, and the heel stays square
-- there): the two shoes never cut into each other or show the foot between them. The shoe is one rigid piece on the
-- foot; only the tongue (flagged `shaft`) rides the lower leg on R15, so it stays in front of the shin when the ankle
-- bends.
-- Part budget: <= 60 per shoe (a worn or follower pair <= 120). Now 46..57.
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
	gloss = { Enum.Material.SmoothPlastic, 0.04, 0, true },
	metal = { Enum.Material.Metal, 0.25, 0, true },
	gold = { Enum.Material.Foil, 0.08, 0, true }, -- (its colour is lifted toward a pale gold when built: polished, not mustard)
	neon = { Enum.Material.Neon, 0, 0, false },
	glass = { Enum.Material.Glass, 0.15, 0.3, false },
	ice = { Enum.Material.Glass, 0.1, 0.12, false },
	-- (brief 24) premium finishes
	chrome = { Enum.Material.Metal, 0.5, 0, true }, -- mirror chrome (mid grey: the sky's reflection brightens it)
	gem = { Enum.Material.Glass, 0.3, 0.12, false }, -- cut gems: shiny, a little see-through
	holo = { Enum.Material.SmoothPlastic, 0.15, 0, true }, -- hologram panels: pearly pastel with a sheen
	-- (brief 28) the rarity ladder's finishes
	rubber = { Enum.Material.SmoothPlastic, 0.15, 0, true }, -- a glossy rubber toe cap: a highlight band in the 3/4
	silver = { Enum.Material.Metal, 0.35, 0, true }, -- polished silver (Epic's heel counter)
}
ShoeModels.Kinds = KIND
local GOLD_LIFT = Color3.fromRGB(255, 232, 120)

local function dark(c, t) return c:Lerp(C(0, 0, 0), t or 0.2) end
local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
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
		shaft = opts.shaft or self.shaft, text = opts.text, transp = opts.transp, studsBottom = opts.studsBottom, mesh = opts.mesh,
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
-- An ellipsoid the size of `size` (a Block with a Sphere SpecialMesh: domes, pillows, feathers, bubbles).
function Builder:egg(name, size, pos, color, kind, rot, opts)
	opts = opts or {}
	opts.mesh = 'Sphere'
	return self:add('Part', 'Block', name, size, CF(pos) * (rot or CFrame.identity), color, kind, opts)
end
-- A flat isosceles triangle (two wedges back to back): base along local Z, apex up local Y, thickness local X.
-- `cf` places the base centre.
function Builder:tooth(name, base, height, thick, cf, color, kind, opts)
	local a = self:add('WedgePart', nil, name, V(thick, height, base / 2), cf * CF(0, height / 2, -base / 4), color, kind, opts)
	local b = self:add('WedgePart', nil, name, V(thick, height, base / 2), cf * CF(0, height / 2, base / 4) * ANG(0, math.pi, 0), color, kind, opts)
	return a, b
end
-- A vertical right-triangle prism (a wedge stood on end): the right angle at (cx, cz), one leg sx along X and one leg
-- sz along Z (signed), from y0 up to y1. With |sx| = |sz| its long face is a vertical 45-degree facet (a chamfered
-- corner). `frame` (optional) places it in another frame (the toe spring).
function Builder:vtri(name, y0, y1, cx, cz, sx, sz, color, kind, frame, opts)
	local Y, Z = V(sx > 0 and 1 or -1, 0, 0), V(0, 0, sz > 0 and -1 or 1)
	local c = V(cx, (y0 + y1) / 2, cz) + Y * (math.abs(sx) / 2) - Z * (math.abs(sz) / 2)
	local cf = CFrame.fromMatrix(c, Y:Cross(Z), Y, Z)
	if frame then cf = frame * cf end
	return self:add('WedgePart', nil, name, V(y1 - y0, math.abs(sx), math.abs(sz)), cf, color, kind, opts)
end
-- Run fn with every part flagged as riding the lower leg (the shin): only the tongue does, so it stays in front of the
-- shin when the ankle bends; everything else is one rigid shoe on the foot.
function Builder:onShin(fn)
	local was = self.shaft
	self.shaft = true
	fn()
	self.shaft = was
end
-- (kept for the accents: decoration rides the foot with the part it sits on)
function Builder:onShaft(fn)
	fn()
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
-- (brief 28) One cohesive cartoon sneaker, like a hit game's pets: one main mass in the upper colour (the quarter,
-- the heel and a low dome toe share one plan outline: flat walls, soft rounded corners), on one unified sole (a dark
-- outsole and a light midsole with the same outline, a rocker toe spring and the heel a little thicker than the toe).
-- A few big secondary forms grow out of it: the padded collar, the tongue, the toe cap. Colour blocks (heel counter,
-- toe cap, side flash, logo) are skins hugging the wall, never lumps; the laces are flat bars on the lace bed.
-- Layout (right shoe): the upper's inner face stays on the foot's inner plane (x = -0.5) round the ankle, the rest
-- hangs out on the outer side. Numbers are studs at scale 1 on a canonical foot.
local L = {
	XI = -0.503, -- inner face of the upper (the foot's inner face is x = -0.5)
	XO = 0.60, -- outer face of the upper
	ZT = -1.16, -- sole toe tip
	ZH = 0.72, -- sole heel end
	HB = 0.065, -- outsole (rubber) thickness
	U = 0.27, -- midsole top at the heel
	DROP = 0.04, -- the midsole top at the bend is this much lower (the heel is thicker than the toe)
	ZB = -0.16, -- the bend: ahead of it the sole springs up
	SPRING = 6, -- toe spring, degrees
	LIP = 0.045, -- the sole sticks out past the upper's outer wall by this
	REVEAL = 0.03, -- and past its toe and heel by this
	RH = 0.2, -- the sole's heel corner chamfer (the upper's is RH - REVEAL, parallel to it)
	YCB = 0.98, -- top of the upper's wall at the heel (the collar pad sits on it)
	YCF = 0.82, -- and at the front of the ankle: the top line falls toward the toe
	RC = 0.13, -- collar pad radius
	ZQ = -0.505, -- front face of the ankle (just ahead of the shin's)
	YT = 0.42, -- the toe's wall height: the rubber toe cap round its foot (a low lid rises above)
	DH = 0.2, -- the toe lid's rise (its lower half stays inside the toe's wall and the sole)
	SKIN = 0.012, -- how proud a colour skin stands of the wall it hugs
}
L.XC = (L.XI + L.XO) / 2
L.WU = L.XO - L.XI
L.SX0, L.SX1 = L.XI - 0.005, L.XO + L.LIP
L.ZHB = L.ZH - L.REVEAL -- the upper's heel back
L.ZHC = L.ZH - L.RH -- heel corner centres (sole and upper)
L.ZTC = L.ZT + L.REVEAL + L.WU / 2 -- the upper's toe circle centre
-- the wall's top line at z (it rises from the ankle's front to the heel corners, then stays level)
function L.wallTop(z)
	return L.YCF + (L.YCB - L.YCF) * math.clamp((z - L.ZQ) / (L.ZHC - L.ZQ), 0, 1)
end
ShoeModels.Layout = L

-- The toe spring: everything ahead of the bend is turned up about it. The pivot sits a hair above the ground so the
-- back of the toe circle (behind the bend, hidden in the heel half) never dips under the ground.
local function springFrame()
	local r = (L.SX1 - L.SX0) / 2 + 0.012
	local z0 = L.ZT + r - 0.012
	local sink = math.max(0, (z0 + r - L.ZB) * math.sin(rad(L.SPRING)))
	local p = V(0, sink + 0.001, L.ZB)
	return CF(p) * ANG(rad(L.SPRING), 0, 0) * CF(-V(0, 0, L.ZB))
end
L.TF = springFrame()

-- One sole layer (outsole or midsole): a rounded-corner heel half (its top pitched by the drop) and the toe half (a
-- full-width box and the round toe) turned up by the spring. grow: the outline grown by this much (the outsole's lip).
-- ring (optional): six colours for its pieces, toe first and round the outer side to the heel (Secret's rainbow sole).
local function soleLayer(B, name, grow, y0, topHeel, topBend, color, kind, studs, ring)
	local function col(i) return ring and ring[i] or color end
	local mk = ring and 'neon' or kind
	local x0, x1 = L.SX0 - grow, L.SX1 + grow
	local w, xc = x1 - x0, (x0 + x1) / 2
	local r = w / 2
	local zt, zh = L.ZT - grow, L.ZH + grow
	local z0 = zt + r -- toe circle centre
	local zc, rh = L.ZHC, L.RH + grow
	-- heel half: the top runs from topBend at the bend to topHeel at the heel corners
	local run, rise = zc - L.ZB, topHeel - topBend
	local th = math.atan2(rise, run)
	local len = math.sqrt(run * run + rise * rise)
	local hh = (topHeel + topBend) / 2 - y0
	local up = V(0, math.cos(th), -math.sin(th))
	local mid = V(xc, (topHeel + topBend) / 2, (zc + L.ZB) / 2) - up * (hh / 2)
	B:box(name, V(w, hh, len), mid, col(3), mk, ANG(-th, 0, 0), { studsBottom = studs })
	B:box(name, V(w - 2 * rh, topHeel - y0, zh - zc + 0.06), V(xc, (topHeel + y0) / 2, (zh + zc - 0.06) / 2), col(5), mk)
	-- (the heel's corners are 45-degree facets)
	B:vtri(name .. 'Heel', y0, topHeel, x0 + rh, zc, -rh, zh - zc, col(6), mk)
	B:vtri(name .. 'Heel', y0, topHeel, x1 - rh, zc, rh, zh - zc, col(4), mk)
	-- toe half (turned up)
	local TF = L.TF
	local h = topBend - y0
	local f = TF * CF(xc, y0 + h / 2, (z0 + L.ZB) / 2)
	B:box(name, V(w, h, L.ZB - z0), f.Position, col(2), mk, f.Rotation, { studsBottom = studs })
	local t = TF * CF(xc, y0 + h / 2, z0)
	B:cyl(name .. 'Toe', h, w, t.Position, col(1), mk, t.Rotation * AXIS.y)
end

local function buildSole(B, d)
	local U, HB = L.U, L.HB
	soleLayer(B, 'Outsole', 0.012, 0, HB, HB, d.base, d.baseKind, true, d.rainbowSole and RAINBOW or nil)
	soleLayer(B, 'Sole', 0, HB - 0.03, U, U - L.DROP, d.sole, d.soleKind)
	B.stripeY = (HB + U) / 2
	-- Legendary+: a glass air unit in the outer heel (a window in the midsole showing a light core)
	if d.air then
		local y = (HB + U - L.DROP * 0.3) / 2
		local h = (U - HB) * 0.62
		B:box('AirWindow', V(0.03, h, 0.42), V(L.SX1 - 0.008, y, 0.2), d.airCore or C(214, 226, 240), 'smooth')
		B:egg('AirBubble', V(0.06, h + 0.02, 0.48), V(L.SX1 + 0.004, y, 0.2), d.airColor or C(235, 248, 255), 'glass')
	end
end

-- The upper's main mass, all in the upper colour: the ankle (a box round the shin with soft front corners, square
-- under the collar), the heel (rounded back corners) and the toe (a round-fronted wall and a low dome, turned up with
-- the sole). A skin of the heel colour hugs the heel; the rubber toe cap hugs the toe.
local function buildUpper(B, d)
	local XI, XO, XC = L.XI, L.XO, L.XC
	local yb = L.U - L.DROP - 0.05 -- buried in the midsole everywhere
	local YF, YB = L.YCF, L.YCB
	local up, uk = d.upper, d.upperKind
	local rh = L.RH - L.REVEAL
	-- ankle: one full-width block from the ankle's front (square corners, both inside the toe cap's round) to the heel
	-- corners, up to the front height; a wedge on top rises to the heel's height
	B:box('Quarter', V(L.WU, YF - yb, L.ZHC - L.ZQ), V(XC, (YF + yb) / 2, (L.ZHC + L.ZQ) / 2), up, uk)
	B:wedge('Quarter', V(L.WU, YB - YF, L.ZHC - L.ZQ), V(XC, (YB + YF) / 2, (L.ZHC + L.ZQ) / 2), up, uk)
	-- heel: the back strip between the two 45-degree corner facets, at the heel's height
	local hcf = CF(XC, (YB + yb) / 2, (L.ZHB + L.ZHC - 0.05) / 2)
	B:box('HeelBack', V(L.WU - 2 * rh, YB - yb, L.ZHB - L.ZHC + 0.05), hcf.Position, up, uk, hcf.Rotation)
	B:vtri('HeelBack', yb, YB, XI + rh, L.ZHC, -rh, rh, up, uk)
	B:vtri('HeelBack', yb, YB, XO - rh, L.ZHC, rh, rh, up, uk)
	-- the heel cup: skins on the back and its two corner facets, thickest at the sole and thinning to nothing up the
	-- heel, so the heel narrows toward the collar (in the heel counter's colour when the shoe has one)
	do
		local cupH, cupT = d.heel and d.heel ~= up and (d.heelH or 0.24) or 0.42, 0.034
		local y0 = L.U - 0.01
		local cc, ck = d.heel or up, d.heelKind or uk
		local faces = {
			{ V(XC, 0, L.ZHB), V(0, 0, 1), L.WU - 2 * rh + 0.02 },
			{ V(XO - rh / 2, 0, (L.ZHC + L.ZHB) / 2), V(1, 0, 1).Unit, rh * 1.414 + 0.02 },
			{ V(XI + rh / 2, 0, (L.ZHC + L.ZHB) / 2), V(-1, 0, 1).Unit, rh * 1.414 + 0.02 },
		}
		for _, fc in faces do
			local n = fc[2]
			local Zl, Yl = -n, V(0, 1, 0)
			-- (a hair off the wall, so its thin top never fights the wall's face)
			local c = fc[1] + n * (cupT / 2 + 0.004) + V(0, y0 + cupH / 2, 0)
			B:add('WedgePart', nil, 'HeelCup', V(fc[3], cupH, cupT), CFrame.fromMatrix(c, Yl:Cross(Zl), Yl, Zl), cc, ck)
		end
	end
	-- toe: the round wall and its dome (turned up with the sole)
	local TF = L.TF
	local tb, tk = d.toeBox or up, d.toeBoxKind or uk
	-- (the round wall is the rubber toe cap: a bumper 0.02 proud of the walls with a small ledge under the dome; it
	-- holds the ankle's square front corners inside it and runs into the flat side walls at a clean angle)
	local tw = TF * CF(XC, (L.YT + yb) / 2, L.ZTC)
	B:cyl('ToeCap', L.YT - yb, L.WU + 0.04, tw.Position, d.toe, d.toeKind, tw.Rotation * AXIS.y)
	local td = TF * CF(XC, L.YT, L.ZTC)
	B:egg('ToeBox', V(L.WU, 2 * L.DH, L.WU), td.Position, tb, tk, td.Rotation)
	B.toeTop = (TF * CF(XC, L.YT + L.DH, L.ZTC)).Position
	local s = L.SKIN
	-- heel counter: a skin of the heel colour round the back, from the sole up to hy
	if d.heel and d.heel ~= up then
		local hy = L.U + (d.heelH or 0.24)
		local z0 = d.heelZ or (d.rarity >= 4 and -0.22 or -0.12)
		local hc, hk = d.heel or dark(up, 0.22), d.heelKind or uk
		-- (the sides sweep down to the sole toward the front: a wedge whose slope is the counter's top edge)
		B:wedge('HeelCounter', V(L.WU + 2 * s, hy - yb, L.ZHC - z0), V(XC, (hy + yb) / 2, (L.ZHC + z0) / 2), hc, hk)
		-- (round the back, the heel cup in the counter's colour is the counter)
		B.heelTop = hy
	end
	-- a seam line along the outer wall just above the midsole (where the upper is stitched to the sole)
	do
		local y0, y1 = L.U + 0.035, L.U - L.DROP + 0.035
		local a, b = V(XO + 0.008, y1, L.ZB), V(XO + 0.008, y0, L.ZHC - 0.02)
		local scf = CFrame.lookAt((a + b) / 2, b)
		B:box('Seam', V(0.02, 0.022, (b - a).Magnitude), scf.Position, d.seam or dark(up, 0.38), 'smooth', scf.Rotation)
	end
	-- Mythic's second glow: a neon line along the outer midsole (with the heel strip)
	if d.soleGlow then
		local y0 = (L.HB + L.U) / 2
		for _, x in { L.SX1 + 0.004, L.SX0 - 0.004 } do
			local a, b = V(x, y0 - L.DROP * 0.9, L.ZB + 0.02), V(x, y0, L.ZHC)
			local gcf = CFrame.lookAt((a + b) / 2, b)
			B:box('SoleGlow', V(0.016, 0.04, (b - a).Magnitude), gcf.Position, d.soleGlow, 'neon', gcf.Rotation)
		end
	end
	-- the side flash: a long tapered wedge on the outer wall, sweeping up toward the heel
	if d.flash ~= false then
		local fcf = CF(XO + 0.006, L.U + 0.2, 0.0) * ANG(rad(8), 0, 0)
		B:wedge('Flash', V(0.02, 0.2, 0.86), fcf.Position, d.flash, d.flashKind or 'smooth', fcf.Rotation)
	end
end

-- The front: the lace bed (the instep: a raised panel in the upper colour from the toe dome up to the collar) with four
-- flat bar laces, and the tongue standing up behind it, rounded on top, with a flush label.
local function buildFront(B, d)
	local XC = L.XC
	-- the bed runs from a point well down the dome's front slope to the collar's front; it is narrower than the toe, so
	-- the dome shows either side of it and its foot corners stay inside the dome
	local dz = 0.38
	local p0 = (L.TF * CF(XC, L.YT + L.DH * math.sqrt(1 - (dz / (L.WU / 2)) ^ 2), L.ZTC - dz)).Position
	local p1 = V(XC, L.YCF + 0.03, L.ZQ - 0.02)
	local ax = (p1 - p0).Unit
	local F0 = CFrame.fromMatrix(p0, V(1, 0, 0), ax) -- local Y up the bed, local -Z out of it
	local plen = (p1 - p0).Magnitude
	local bw = L.WU - 0.4
	-- the bed is the vamp itself (the upper's colour, its foot sunk in the dome); a flush strip runs down its middle under
	-- the laces, at least 0.3 apart from the laces in luma (darker under light laces, lighter under dark ones)
	local c = F0 * CF(0, plen / 2 - 0.02, 0.1)
	B:box('Eyestay', V(bw, plen + 0.04, 0.26), c.Position, d.eyestay or d.upper, d.eyestayKind or d.upperKind, c.Rotation)
	local strip = d.laceBed or d.tongue or d.upper
	for _ = 1, 8 do
		if math.abs(lum(strip) - lum(d.lace)) >= 0.3 then break end
		strip = lum(d.lace) > 0.5 and dark(strip, 0.18) or light(strip, 0.25)
	end
	local sc = F0 * CF(0, (plen + 0.03) / 2, -0.03 - 0.004)
	B:box('TongueStrip', V(bw * 0.84, plen - 0.03, 0.012), sc.Position, strip, d.laceBedKind or 'smooth', sc.Rotation)
	-- the tongue: stands up behind the bed's top, past the collar, rounded on top; it rides the shin, so it stays in
	-- front of it when the ankle bends
	B:onShin(function()
		local tcf = CF(XC, L.YCF + 0.13, L.ZQ - 0.07) * ANG(rad(-10), 0, 0)
		local tc, tk = d.tongue or d.upper, d.tongueKind or d.upperKind
		B:box('Tongue', V(0.46, 0.36, 0.1), tcf.Position, tc, tk, tcf.Rotation)
		B:cyl('TongueTop', 0.46, 0.1, (tcf * CF(0, 0.18, 0)).Position, tc, tk, tcf.Rotation)
		B.tongueFront = tcf * CF(0, 0.18, -0.05)
		if d.tongueLabel ~= false then
			local lcf = tcf * CF(0, 0.07, -0.054)
			B:box('TongueLabel', V(0.28, 0.12, 0.012), lcf.Position, d.tongueLabel or d.collar, d.tongueLabelKind or 'smooth', lcf.Rotation)
		end
	end)
	-- laces: round cords crossing in two X's up the strip and a straight one across the top, half sunk in the bed
	-- (the second cord of each X sits a hair further out, so the crossings never fight); from Legendary the top one is
	-- a gold aglet bar
	local hx, dia = bw * 0.36, 0.075
	local rows = { 0.06, 0.06 + (plen - 0.14) / 2, plen - 0.08 }
	for i = 1, 2 do
		local y0, y1 = rows[i], rows[i + 1]
		local dy = y1 - y0
		local len = math.sqrt((2 * hx) ^ 2 + dy * dy) + dia
		local ang = math.atan2(dy, 2 * hx)
		for j, sgn in { 1, -1 } do
			local lcf = F0 * CF(0, (y0 + y1) / 2, -0.032 - (j - 1) * 0.018) * ANG(0, 0, sgn * ang)
			B:cyl('Lace', len, dia, lcf.Position, d.lace, d.laceKind, lcf.Rotation)
		end
	end
	local top = F0 * CF(0, rows[3], -0.04)
	B:cyl(d.aglet and 'LaceAglet' or 'Lace', 2 * hx + dia + (d.aglet and 0.06 or 0), d.aglet and 0.1 or dia, top.Position, d.aglet or d.lace, d.aglet and 'gold' or d.laceKind, top.Rotation)
end

-- The padded collar round the opening: a ring of six round pads (front, both sides, the two chamfered back corners
-- and the back) following the wall's top line (higher at the heel), balls at the front corners, a dark lining inside,
-- and a pull loop standing up at the back.
local function buildCollar(B, d)
	local XC = L.XC
	local hw = 0.19 * math.sqrt(2) / 2 -- the pad's radius
	-- (each pad's centre line is inset from the wall's top edge so its outer side just overhangs the wall: the sides,
	-- the back, and the heel's corner facets, offset in parallel)
	local dO, dI, dB = hw - 0.025, hw - 0.015, hw - 0.02
	local xo, xi = L.XO - dO, L.XI + dI
	local zb, zf = L.ZHB - dB, L.ZQ + hw + 0.01
	local rh = L.RH - L.REVEAL
	local cO, cI = (dO + dB) / 2 * math.sqrt(2), (dI + dB) / 2 * math.sqrt(2)
	local col, ck = d.collar, d.collarKind
	local function at(x, z)
		-- a point on the pad's centre line: on the wall's top line, falling from the heel to the front
		return V(x, L.wallTop(z), z)
	end
	B:onShaft(function()
		-- the lining: the floor of the opening, dark, following the top line just under the pads
		local a0, a1 = at(XC, zf), at(XC, zb)
		local lcf = CFrame.lookAt((a0 + a1) / 2, a1)
		B:box('Lining', V(xo - xi, 0.02, (a1 - a0).Magnitude), lcf.Position, d.lining, 'smooth', lcf.Rotation)
		-- the ring: corner points in order, with the turn at each (90 at the front, 45 at the back's facets)
		local pts = { at(xi, zf), at(xo, zf), at(xo, L.ZHC - cO + dO), at(L.XO + L.ZHC - cO - zb, zb),
			at(L.XI - L.ZHC + cI + zb, zb), at(xi, L.ZHC - cI + dI) }
		local turn = { 90, 90, 45, 45, 45, 45 }
		for i = 1, 6 do
			local j = i % 6 + 1
			local pa, pb = pts[i], pts[j]
			local ax = (pb - pa).Unit
			-- round pads: past each 45-degree joint by the mitre's overlap; the front corners get a ball
			local ea = turn[i] == 45 and hw * math.tan(rad(22.5)) or 0
			local eb = turn[j] == 45 and hw * math.tan(rad(22.5)) or 0
			local s0, s1 = pa - ax * ea, pb + ax * eb
			B:cyl('Collar', (s1 - s0).Magnitude, 2 * hw, (s0 + s1) / 2, col, ck, CFrame.lookAt(s0, s1).Rotation * ANG(0, rad(90), 0))
			if turn[i] == 90 then B:ball('CollarCorner', 2 * hw, pa, col, ck) end
		end
		-- pull loop: a tab standing up out of the back pad, leaning back a little, with a hole through it
		-- (a shoe whose signature sits on the back of the collar, a crown, has no loop: tab = false)
		local back = at(XC, zb)
		if d.tab ~= false then
			local tab = d.tab or d.collar
			local tcf = CF(back + V(0, 0.07, hw * 0.35)) * ANG(rad(-12), 0, 0)
			B:box('HeelTab', V(0.24, 0.26, 0.05), (tcf * CF(0, 0.06, 0)).Position, tab, d.tabKind, tcf.Rotation)
			B:box('HeelTabHole', V(0.12, 0.09, 0.06), (tcf * CF(0, 0.1, 0)).Position, dark(tab, 0.55), 'smooth', tcf.Rotation)
		end
		B.collarY, B.collarZ = back.Y, zb
		B.collarBack = CF(back)
		-- a point dy above the collar's centre line at (x, z), following its tilt
		B.cat = function(x, dy, z) return at(x, z) + V(0, dy or 0, 0) end
	end)
end

---------------------------------------------------------------------------------------------- accents
-- Side face of the ankle panel (outer, x = +side), the "canvas" for logos and prints. Its middle swells into the
-- AnkleSide pillow: sideX(y, z) is the outer surface there (the flat face where the pillow sinks in).
local CUR -- the builder whose shoe is being decorated (recipe sets it)
local function sideX(y, z)
	return L.XO
end
ShoeModels.sideX = sideX
local A = {}
ShoeModels.Accents = A
-- Frame on the outer side face at (y, z): x out of the face, rotation about X tilts within the face.
local function sideCF(y, z, out, tilt)
	return CF(sideX(y, z) + (out or 0.02), y, z) * ANG(rad(tilt or 0), 0, 0)
end
-- A flat disc on the side face.
local function sideDisc(B, name, d, y, z, color, kind, out, thick)
	return B:cyl(name, thick or 0.035, d, V(sideX(y, z) + (out or 0.018), y, z), color, kind, 'x')
end

-- "+1" glyph on the side face, centred at (y, z), height h. Reads left to right from outside on both shoes.
function A.plusOne(B, y, z, h, color, kind, out)
	local t = h * 0.22
	local text = { face = 'x', centre = V(0, y, z) }
	local x = sideX(y, z) + (out or 0.04)
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
		local y, z = U + 0.34, 0.1
		local kind = lg.kind or 'disc'
		if kind == 'disc' then
			sideDisc(B, 'Logo', 0.32, y, z, lg.color, lg.mat)
			if lg.glyph == 'plus1' then
				A.plusOne(B, y, z, 0.17, lg.glyphColor or K.white, 'smooth', 0.042)
			elseif lg.glyph == 'plus' then
				local x = sideX(y, z) + 0.04
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
		B:box('Zigzag', V(0.03, 0.06, seg * 1.25), V(sideX(y, zc) + (out or 0.02), y, zc), color, kind, ANG(rad(up * 35), 0, 0))
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
		B:box('Wave', V(0.03, 0.07, seg * 0.62), V(sideX(y + 0.04, zc + seg * 0.18) + 0.02, y + 0.04, zc + seg * 0.18), color, kind, ANG(rad(28), 0, 0))
		B:box('Wave', V(0.031, 0.07, seg * 0.55), V(sideX(y + 0.04, zc - seg * 0.24) + 0.021, y + 0.04, zc - seg * 0.24), color, kind, ANG(rad(-38), 0, 0))
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
-- Checker print on the outer wall: a 2 x 4 board between the flash and the collar, every other square in colour b
-- (the wall shows through as the other colour). Flush squares; the top row tucks under the collar pad. 4 parts.
function A.checker(B, d, a, b)
	B:onShaft(function()
		local s = 0.19
		for i = 0, 3 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					B:box('Check', V(0.024, s, s), V(L.XO + 0.012, L.U + 0.25 + j * s, 0.38 - i * s), b)
				end
			end
		end
	end)
end
-- Drips running down from the collar on the outer wall (paint, slime, frosting): flush strips with a round end, like
-- a print on the wall (no bulges). n of them, long scales their length, colors cycles their colours. 2 parts each.
function A.drips(B, d, color, kind, n, long, colors)
	B:onShaft(function()
		local spots = { { 0.3, 0.34 }, { -0.06, 0.46 }, { -0.34, 0.26 }, { 0.12, 0.22 }, { -0.2, 0.36 } }
		for i = 1, math.min(n or 3, #spots) do
			local s = spots[i]
			local z = s[1]
			local h = s[2] * (long or 1)
			local c = colors and colors[(i - 1) % #colors + 1] or color
			local y0 = L.wallTop(z) - 0.08
			local x = L.XO + 0.009
			B:box('Drip', V(0.02, h, 0.09), V(x, y0 - h / 2, z), c, kind)
			B:cyl('DripEnd', 0.02, 0.13, V(x, y0 - h, z), c, kind, 'x')
		end
	end)
end
-- Wings on the outer side, rooted on a seated base at the back of the collar and fanning up and back behind the
-- collar line (they never cover the upper): a round covert and four broad feathers (ellipsoids), overlapping like a
-- cartoon wing. style 'ice' gives straight square feathers (icicles), 'flame' adds a pointed tip to each. 5-9 parts.
function A.wings(B, d, color, color2, kind, scale, style)
	B:onShaft(function()
		local k = 0.8 * (scale or 1)
		local root = CF(B.cat(L.XO - 0.02, 0.02, 0.36)) * ANG(0, rad(62), 0)
		B:egg('WingRoot', V(0.12, 0.42 * k, 0.48 * k), (root * CF(0.03, 0.04, 0.1)).Position, color2 or color, kind, root.Rotation)
		local feathers = { { 1.0, 20 }, { 0.92, 38 }, { 0.8, 56 }, { 0.64, 74 } }
		local w = 0.32 * k
		for i, f in feathers do
			local len = f[1] * k
			local fcf = root * ANG(rad(-f[2]), 0, 0)
			local c = (i % 2 == 0 and color2) or color
			local x = 0.014 * i
			local body = fcf * CF(x, 0, len / 2 + 0.04)
			if style == 'ice' then
				B:box('Feather', V(0.05, w * 0.8, len), body.Position, c, kind, body.Rotation)
			else
				B:egg('Feather', V(0.06, w, len + 0.12), body.Position, c, kind, body.Rotation)
			end
			if style == 'flame' then
				-- a pointed tip: one wedge whose slope runs out to the point
				local tcf = fcf * CF(x, 0, len + 0.04 + w * 0.5) * ANG(rad(90), 0, 0)
				B:wedge('FeatherTip', V(0.05, w * 1.0, w * 0.8), tcf.Position, c, kind, tcf.Rotation)
			end
		end
	end)
end
-- Flames rising off the back and the outer side of the collar (Inferno, Solar Flare): three flat teeth seated in the
-- pad, the tallest with a glowing core. 7 parts.
function A.collarFlames(B, d, outer, core, kind)
	B:onShaft(function()
		local spots = { { B.cat(L.XC - 0.12, 0.0, 0.44), 0.7, 0, 8 }, { B.cat(L.XO - 0.08, 0.0, 0.1), 0.6, 90, -10 },
			{ B.cat(L.XO - 0.08, 0.0, -0.22), 0.44, 90, 12 } }
		for i, s in spots do
			local cf = CF(s[1]) * ANG(0, rad(s[3]), 0) * ANG(0, 0, rad(s[4]))
			B:tooth('FlameTooth', 0.34, s[2], 0.06, cf, outer, kind)
			if i == 1 then B:cyl('FlameCore', 0.075, 0.16, (cf * CF(0, s[2] * 0.3, 0)).Position, core, 'neon', cf.Rotation * AXIS.z) end
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
-- A small crown: a band, three diamond points (cubes turned 45 degrees, half sunk in the band) and a jewel on the
-- band's front. cf = the crown's base centre, facing -Z. 5 parts.
function A.crown(B, cf, size, color, gem, kind)
	local w = size
	B:box('CrownBand', V(w, w * 0.28, w * 0.42), (cf * CF(0, w * 0.14, 0)).Position, color, kind or 'gold', cf.Rotation)
	for i = -1, 1 do
		local s = w * (i == 0 and 0.36 or 0.3)
		local p = cf * CF(i * w * 0.33, w * 0.28, 0)
		B:box('CrownPoint', V(w * 0.3, s, s), p.Position, color, kind or 'gold', p.Rotation * ANG(rad(45), 0, 0))
	end
	B:ball('CrownJewel', w * 0.16, (cf * CF(0, w * 0.14, -w * 0.2)).Position, gem, 'gem')
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
-- A heel strip (glows from Legendary): a flush band down the middle of the heel, from the sole to the collar.
function A.heelStrip(B, d, color, kind)
	local y0, y1 = L.U + 0.01, L.YCB - 0.04
	B:box('HeelStrip', V(0.12, y1 - y0, 0.02), V(L.XC, (y0 + y1) / 2, L.ZHB + L.SKIN + 0.006), color, kind or 'neon')
end
-- A rainbow flash (Secret): four thin bands stacked on the outer wall where the flash goes, sweeping up to the heel
-- (red, yellow, green, blue... spread over the rainbow from `offset`).
function A.rainbowFlash(B, d, offset)
	local o = offset or 0
	for i = 1, 4 do
		local fcf = CF(L.XO + 0.008, L.U + 0.12 + i * 0.058, 0.02) * ANG(rad(8), 0, 0)
		local c = RAINBOW[(o + math.floor((i - 1) * 1.6 + 0.5)) % #RAINBOW + 1]
		B:wedge('Flash', V(0.02, 0.06, 0.9 - i * 0.035), fcf.Position, c, 'neon', fcf.Rotation)
	end
end
-- Toe badge: a motif on the front of the toe dome, lying on its surface (X = out of the dome, Y = up the dome).
function A.toeBadge(B, d, kind, color, mat, size)
	local phi = rad(22)
	local R, H = L.WU / 2, L.DH
	local p = V(L.XC, L.YT + H * math.sin(phi), L.ZTC - R * math.cos(phi))
	local n = V(0, math.sin(phi) / H, -math.cos(phi) / R).Unit
	local up = V(0, -n.Z, n.Y)
	local cf = L.TF * CFrame.fromMatrix(p + n * 0.012, n, up, n:Cross(up))
	local s = math.min(size or 0.26, 0.28)
	if kind == 'star' then A.star(B, cf, s, color, mat)
	elseif kind == 'sparkle' then A.sparkle(B, cf, s * 1.2, color, mat)
	elseif kind == 'drop' then A.drop(B, cf, s, color, mat)
	elseif kind == 'heart' then A.heart(B, cf, s, color, mat)
	elseif kind == 'gem' then A.gem(B, cf, s, color, mat)
	elseif kind == 'flame' then A.flame(B, cf * CF(0, -s * 0.4, 0), s * 1.1, color, K.gold, mat)
	elseif kind == 'snowflake' then A.snowflake(B, cf, s, color, mat)
	elseif kind == 'bolt' then
		B:box('Bolt', V(0.03, s * 0.5, s * 0.2), (cf * CF(0, s * 0.24, -s * 0.05)).Position, color, mat, cf.Rotation * ANG(rad(25), 0, 0))
		B:box('Bolt', V(0.032, s * 0.18, s * 0.4), cf.Position, color, mat, cf.Rotation * ANG(rad(10), 0, 0))
		B:box('Bolt', V(0.03, s * 0.5, s * 0.2), (cf * CF(0, -s * 0.24, s * 0.05)).Position, color, mat, cf.Rotation * ANG(rad(25), 0, 0))
	end
end

---------------------------------------------------------------------------------------------- definitions
-- Per shoe: Name, Box, Rarity (1..6) and the look. Colours: upper (main), heel (counter), collar, tongue, lace,
-- laceBed (the strip under the laces), toe (toe cap), toeBox (the dome), sole (midsole), base (outsole), flash, tab,
-- tongueLabel. `upperKind` etc. set materials; `deco(B, d)` adds the accents. Defaults fill what a definition leaves out
-- (the rarity's finish step among them).
local DEFS = {}
local ORDER = {}
local function def(id, t)
	t.Id = id
	DEFS[id] = t
	table.insert(ORDER, id)
end

-- 01 Street --------------------------------------------------------------------------------------------------------
def('FreshCanvas', { Name = 'Fresh Canvas', Box = 'Street', rarity = 1,
	upper = C(242, 242, 245), collar = C(222, 40, 48), tongue = C(242, 242, 245), lace = K.snow, laceBed = C(222, 40, 48),
	toe = K.snow, sole = K.snow, base = C(54, 56, 66), flash = C(222, 40, 48), tab = K.snow,
	logo = { color = C(222, 40, 48), glyph = 'plus1' }, tongueLabel = C(222, 40, 48),
})
def('RedRocket', { Name = 'Red Rocket', Box = 'Street', rarity = 2,
	upper = C(214, 38, 44), collar = C(30, 30, 38), tongue = C(214, 38, 44), tab = C(30, 30, 38),
	lace = K.snow, toe = K.snow, sole = K.snow, base = C(30, 30, 38), flash = false,
	logo = { kind = 'bolt', color = C(255, 196, 40) }, tongueLabel = C(255, 196, 40),
})
def('Checkmate', { Name = 'Checkmate', Box = 'Street', rarity = 3,
	upper = C(242, 242, 245), collar = C(30, 30, 38), tongue = C(30, 30, 38), tab = C(222, 40, 48),
	lace = K.snow, toe = K.snow, sole = K.snow, base = C(214, 36, 44), flash = false, tongueLabel = C(222, 40, 48),
	deco = function(B, d)
		A.checker(B, d, d.upper, C(30, 30, 38))
		A.toeBadge(B, d, 'bolt', C(222, 40, 48), 'smooth', 0.26)
	end,
})
def('ChromeKicks', { Name = 'Chrome Kicks', Box = 'Street', rarity = 4, fx = { tex = 'sparkle', colors = { C(255, 120, 160), C(255, 190, 210) } },
	upper = C(214, 220, 232), upperKind = 'chrome', collar = C(30, 30, 38), tongue = C(214, 220, 232), tongueKind = 'chrome',
	lace = C(240, 70, 90), toe = C(36, 36, 46), sole = C(36, 36, 46), base = C(24, 24, 30), flash = C(240, 70, 90),
	deco = function(B, d)
		B:onShaft(function() A.sparkle(B, sideCF(L.U + 0.44, 0.12, 0.02), 0.42, C(255, 120, 160), 'neon') end)
	end,
})
def('StreetAngel', { Name = 'Street Angel', Box = 'Street', rarity = 5, fx = { tex = 'sparkle', colors = { C(255, 250, 230), C(255, 214, 110) } },
	upper = C(246, 246, 250), collar = C(255, 200, 60), collarKind = 'gold', tongue = C(255, 204, 70), tongueKind = 'gold',
	toe = C(255, 204, 70), toeKind = 'gold', sole = C(250, 244, 230), base = C(240, 190, 60), lace = K.snow, flash = false,
	heelGlow = C(255, 176, 40),
	deco = function(B, d)
		A.wings(B, d, C(250, 250, 255), C(232, 236, 248), 'smooth', 1.0)
	end,
})
def('BlockRoyalty', { Name = 'Block Royalty', Box = 'Street', rarity = 6,
	upper = C(34, 30, 44), upperKind = 'gloss', collar = C(222, 44, 52), tongue = C(34, 30, 44), heel = C(222, 44, 52),
	lace = C(255, 206, 70), laceKind = 'gold', toe = C(34, 30, 44), toeKind = 'gloss', sole = C(232, 60, 50), base = C(150, 30, 34), flash = false,
	tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 0)
		B:onShaft(function() A.crown(B, B.tongueFront * CF(0, -0.03, 0.05), 0.46, K.gold, C(232, 40, 60)) end)
	end,
})

-- 02 Graffiti ------------------------------------------------------------------------------------------------------
def('SprayTag', { Name = 'Spray Tag', Box = 'Graffiti', rarity = 1,
	upper = C(232, 92, 164), collar = K.snow, tongue = C(240, 110, 176), lace = C(255, 206, 50), toe = K.snow, sole = K.snow,
	logo = { color = C(40, 196, 210), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(40, 196, 210),
})
def('DripTag', { Name = 'Drip Tag', Box = 'Graffiti', rarity = 2,
	upper = C(42, 184, 204), collar = C(236, 96, 160), tongue = C(52, 196, 214), tab = K.snow, toe = K.snow, sole = K.snow,
	base = C(236, 96, 160), logo = { kind = 'zigzag', color = C(255, 206, 50) }, tongueLabel = C(255, 206, 50),
})
def('PaintSplash', { Name = 'Paint Splash', Box = 'Graffiti', rarity = 3,
	upper = C(36, 34, 46), collar = C(36, 34, 46), tongue = C(236, 96, 160), tab = C(236, 96, 160), toe = K.snow, sole = K.snow,
	base = C(236, 96, 160), tongueLabel = K.snow,
	deco = function(B, d)
		A.splats(B, d, { { 0.48, 0.26, 0.26, C(236, 96, 160) }, { 0.3, -0.08, 0.22, C(120, 230, 90), nil, 1 }, { 0.5, -0.3, 0.15, C(70, 170, 255) },
			{ 0.2, 0.4, 0.13, C(255, 206, 50), nil, 1 } })
		A.toeBadge(B, d, 'star', C(236, 96, 160), 'smooth', 0.26)
	end,
})
def('NeonBomb', { Name = 'Neon Bomb', Box = 'Graffiti', rarity = 4,
	upper = C(236, 60, 150), upperKind = 'gloss', collar = C(30, 28, 40), tongue = C(244, 80, 164), lace = C(120, 230, 255),
	toe = C(30, 28, 40), sole = C(30, 28, 40), base = C(24, 22, 32),
	deco = function(B, d)
		B:onShaft(function() A.sparkle(B, sideCF(L.U + 0.36, 0.1, 0.02), 0.44, C(150, 240, 255), 'neon') end)
	end,
})
def('WildStyle', { Name = 'Wild Style', Box = 'Graffiti', rarity = 5,
	upper = C(40, 44, 70), upperKind = 'gloss', collar = C(236, 96, 160), tongue = C(236, 96, 160), sole = C(236, 96, 160),
	base = C(200, 70, 140), toe = C(120, 220, 90), lace = K.snow, heelGlow = C(130, 255, 110),
	deco = function(B, d)
		A.splats(B, d, { { 0.5, 0.36, 0.22, C(120, 220, 90) }, { 0.22, -0.34, 0.16, C(236, 96, 160), nil, 1 } })
		A.drips(B, d, C(130, 255, 110), 'neon', 3, 1.0)
	end,
})
def('Masterpiece', { Name = 'Masterpiece', Box = 'Graffiti', rarity = 6,
	upper = C(52, 34, 90), upperKind = 'gloss', collar = C(70, 46, 120), tongue = C(52, 34, 90), sole = C(240, 90, 160),
	base = C(200, 60, 130), toe = C(70, 46, 120), toeKind = 'gloss', lace = C(255, 206, 70), tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 2)
		A.drips(B, d, RAINBOW[1], 'neon', 4, 0.8, { RAINBOW[1], RAINBOW[3], RAINBOW[5], RAINBOW[6] })
	end,
})

-- 03 Frost ---------------------------------------------------------------------------------------------------------
def('IceCold', { Name = 'Ice Cold', Box = 'Frost', rarity = 1,
	upper = C(112, 178, 228), collar = K.snow, tongue = C(124, 188, 234), toe = K.snow, sole = K.snow,
	logo = { color = C(240, 248, 255), glyph = 'dot', glyphColor = C(90, 152, 208) }, tab = C(90, 152, 208), tongueLabel = K.snow,
})
def('SnowDay', { Name = 'Snow Day', Box = 'Frost', rarity = 2,
	upper = C(36, 92, 178), collar = K.snow, tongue = C(46, 104, 190), tab = C(150, 210, 250), toe = K.snow, sole = K.snow,
	base = C(110, 180, 240), logo = { kind = 'zigzag', color = C(170, 225, 255) }, tongueLabel = C(170, 225, 255),
})
def('Flurry', { Name = 'Flurry', Box = 'Frost', rarity = 3,
	upper = C(170, 212, 245), collar = C(40, 100, 190), tongue = C(40, 100, 190), tab = C(40, 100, 190), toe = K.snow, sole = K.snow,
	base = C(90, 160, 235), tongueLabel = K.snow,
	deco = function(B, d)
		B:onShaft(function()
			A.snowflake(B, sideCF(L.U + 0.42, 0.18, 0.02), 0.32, K.snow, 'smooth')
			A.snowflake(B, sideCF(L.U + 0.22, -0.2, 0.02), 0.22, K.snow, 'smooth')
		end)
	end,
})
def('Glacier', { Name = 'Glacier', Box = 'Frost', rarity = 4,
	upper = C(40, 120, 220), upperKind = 'gloss', collar = C(24, 80, 170), tongue = C(140, 200, 250), sole = C(70, 140, 225),
	base = C(30, 90, 180), toe = C(200, 230, 255), toeKind = 'ice', lace = K.snow,
	deco = function(B, d) A.crystals(B, d, C(190, 235, 255), 'ice', 4, 0.85) end,
})
def('BlizzardKing', { Name = 'Blizzard King', Box = 'Frost', rarity = 5,
	upper = C(30, 80, 170), upperKind = 'gloss', collar = C(24, 66, 150), tongue = C(24, 66, 150), sole = C(40, 96, 190),
	base = C(20, 56, 130), toe = C(150, 210, 250), lace = K.snow, heelGlow = C(200, 240, 255),
	deco = function(B, d) A.wings(B, d, C(214, 238, 255), C(170, 215, 250), 'ice', 1.0, 'ice') end,
})
def('AbsoluteZero', { Name = 'Absolute Zero', Box = 'Frost', rarity = 6,
	upper = C(24, 40, 96), upperKind = 'gloss', collar = C(40, 70, 150), tongue = C(24, 40, 96), sole = C(140, 210, 250),
	base = C(60, 140, 220), toe = C(24, 40, 96), toeKind = 'gloss', lace = K.snow, tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 3)
		A.crystals(B, d, C(170, 235, 255), 'ice', 4, 1.0)
	end,
})

-- 04 Lava ----------------------------------------------------------------------------------------------------------
def('Ember', { Name = 'Ember', Box = 'Lava', rarity = 1,
	upper = C(238, 140, 34), collar = K.snow, tongue = C(244, 152, 44), toe = K.snow, sole = K.snow,
	logo = { color = C(36, 32, 40), glyph = 'dot', glyphColor = C(255, 200, 60) }, tongueLabel = C(36, 32, 40),
})
def('HotStep', { Name = 'Hot Step', Box = 'Lava', rarity = 2,
	upper = C(186, 34, 34), collar = C(32, 32, 44), tongue = C(200, 44, 44), tab = C(32, 32, 44), toe = K.snow, sole = K.snow,
	base = C(240, 130, 30), logo = { kind = 'flame', color = C(255, 196, 50), color2 = C(255, 240, 160) }, tongueLabel = C(255, 196, 50),
})
def('MagmaCrack', { Name = 'Magma Crack', Box = 'Lava', rarity = 3,
	upper = C(36, 30, 34), collar = C(36, 30, 34), tongue = C(36, 30, 34), tab = C(240, 110, 30), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(240, 110, 30), tongueLabel = C(255, 140, 40),
	deco = function(B, d)
		A.speckles(B, d, { { 0.4, 0.24, 0.045, C(255, 130, 40), 25, 'Crack', 0.38 }, { 0.28, -0.04, 0.045, C(255, 130, 40), -30, 'Crack', 0.32 },
			{ 0.46, -0.3, 0.04, C(255, 160, 60), -60, 'Crack', 0.22 } }, 'neon')
		A.toeBadge(B, d, 'drop', C(255, 120, 30), 'smooth', 0.24)
	end,
})
def('Obsidian', { Name = 'Obsidian', Box = 'Lava', rarity = 4,
	upper = C(30, 26, 32), upperKind = 'gloss', collar = C(30, 26, 32), tongue = C(30, 26, 32), lace = C(255, 120, 40),
	sole = C(30, 26, 32), base = C(22, 20, 26), toe = C(30, 26, 32), toeKind = 'gloss', airCore = C(255, 170, 90),
	deco = function(B, d)
		B:onShaft(function() A.flame(B, sideCF(L.U + 0.1, 0.06, 0.02), 0.56, C(255, 120, 40), C(255, 220, 120), 'neon') end)
	end,
})
def('Inferno', { Name = 'Inferno', Box = 'Lava', rarity = 5,
	upper = C(230, 70, 30), upperKind = 'gloss', collar = C(30, 26, 32), tongue = C(30, 26, 32), sole = C(36, 30, 34),
	base = C(240, 110, 30), toe = C(30, 26, 32), toeKind = 'gloss', lace = C(255, 200, 60), heelGlow = C(255, 150, 50),
	deco = function(B, d) A.collarFlames(B, d, C(255, 110, 40), C(255, 220, 90), 'neon') end,
})
def('Phoenix', { Name = 'Phoenix', Box = 'Lava', rarity = 6,
	upper = C(40, 22, 26), upperKind = 'gloss', collar = C(60, 26, 30), tongue = C(40, 22, 26), sole = C(240, 110, 40),
	base = C(200, 70, 30), toe = C(40, 22, 26), toeKind = 'gloss', lace = C(255, 190, 70), tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 0)
		A.wings(B, d, C(255, 120, 50), C(255, 190, 70), 'neon', 0.95, 'flame')
	end,
})

-- 05 Toxic ---------------------------------------------------------------------------------------------------------
def('SlimeTime', { Name = 'Slime Time', Box = 'Toxic', rarity = 1,
	upper = C(124, 212, 64), collar = K.snow, tongue = C(136, 222, 76), toe = K.snow, sole = K.snow,
	logo = { color = C(80, 60, 160), glyph = 'dot', glyphColor = C(160, 240, 90) }, tongueLabel = C(80, 60, 160),
})
def('GlowStick', { Name = 'Glow Stick', Box = 'Toxic', rarity = 2,
	upper = C(88, 64, 172), collar = C(130, 230, 70), tongue = C(98, 74, 184), tab = K.snow, toe = K.snow, sole = K.snow,
	base = C(130, 230, 70), logo = { kind = 'bolt', color = C(150, 245, 90) }, tongueLabel = C(150, 245, 90),
})
def('Ooze', { Name = 'Ooze', Box = 'Toxic', rarity = 3,
	upper = C(40, 40, 92), collar = C(40, 40, 92), tongue = C(40, 40, 92), tab = C(120, 220, 70), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(120, 220, 70), tongueLabel = C(140, 240, 80),
	deco = function(B, d)
		A.drips(B, d, C(130, 230, 70), 'smooth', 3, 0.9)
		A.toeBadge(B, d, 'drop', C(130, 230, 70), 'smooth', 0.28)
	end,
})
def('Reactor', { Name = 'Reactor', Box = 'Toxic', rarity = 4,
	upper = C(130, 226, 70), upperKind = 'gloss', collar = C(40, 40, 92), tongue = C(140, 236, 80), lace = C(40, 40, 92),
	sole = C(40, 40, 92), base = C(30, 30, 72), toe = C(40, 40, 92), airCore = C(200, 255, 140),
	deco = function(B, d)
		B:onShaft(function()
			A.bolt(B, L.U + 0.36, 0.14, 0.4, C(40, 40, 92), 'smooth', 0.02)
			A.bolt(B, L.U + 0.24, -0.22, 0.26, C(40, 40, 92), 'smooth', 0.02)
		end)
	end,
})
def('ToxicTitan', { Name = 'Toxic Titan', Box = 'Toxic', rarity = 5,
	upper = C(40, 40, 96), upperKind = 'gloss', collar = C(60, 54, 140), tongue = C(60, 54, 140), sole = C(40, 40, 96),
	base = C(130, 230, 70), toe = C(130, 230, 70), lace = K.snow, heelGlow = C(160, 255, 90),
	deco = function(B, d) A.drips(B, d, C(150, 255, 90), 'neon', 4, 1.0) end,
})
def('Mutant', { Name = 'Mutant', Box = 'Toxic', rarity = 6,
	upper = C(30, 34, 80), upperKind = 'gloss', collar = C(50, 50, 120), tongue = C(30, 34, 80), sole = C(130, 230, 70),
	base = C(80, 180, 50), toe = C(30, 34, 80), toeKind = 'gloss', lace = C(160, 255, 90), tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 4)
		B:onShaft(function()
			-- two friendly cartoon eyes on stalks, seated in the back of the collar
			for i, p in { B.cat(L.XC + 0.26, 0.32, B.collarZ), B.cat(L.XC - 0.16, 0.4, B.collarZ) } do
				B:box('EyeStalk', V(0.08, 0.36 + i * 0.06, 0.08), p - V(0, 0.2 + i * 0.03, 0), C(130, 230, 70))
				B:ball('Eye', 0.3, p, K.snow)
				B:ball('Pupil', 0.13, p + V(0, 0.02, -0.11), K.ink)
			end
		end)
	end,
})

-- 06 Candy ---------------------------------------------------------------------------------------------------------
def('Bubblegum', { Name = 'Bubblegum', Box = 'Candy', rarity = 1,
	upper = C(244, 160, 196), collar = K.snow, tongue = C(248, 172, 204), toe = K.snow, sole = K.snow,
	logo = { color = C(120, 140, 240), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(120, 140, 240),
})
def('CottonCandy', { Name = 'Cotton Candy', Box = 'Candy', rarity = 2,
	upper = C(150, 206, 244), collar = C(244, 120, 176), tongue = C(162, 214, 248), tab = K.snow, toe = K.snow, sole = K.snow,
	base = C(244, 120, 176), logo = { kind = 'zigzag', color = K.snow }, tongueLabel = C(244, 120, 176),
})
def('Sprinkles', { Name = 'Sprinkles', Box = 'Candy', rarity = 3,
	upper = C(248, 236, 244), collar = C(150, 140, 240), tongue = C(150, 140, 240), tab = C(244, 90, 150), toe = K.snow,
	sole = K.snow, base = C(244, 120, 176), lace = K.snow, tongueLabel = C(244, 90, 150),
	deco = function(B, d)
		B:onShaft(function() A.heart(B, sideCF(L.U + 0.34, 0.02, 0.02), 0.34, C(244, 90, 150), 'smooth') end)
		A.speckles(B, d, { { 0.5, 0.36, 0.05, C(90, 190, 255), 40, 'Sprinkle', 0.17 }, { 0.2, 0.3, 0.05, C(255, 200, 60), -50, 'Sprinkle', 0.17 },
			{ 0.48, -0.3, 0.05, C(120, 220, 120), 20, 'Sprinkle', 0.17 } }, 'smooth')
		A.toeBadge(B, d, 'heart', C(244, 90, 150), 'smooth', 0.24)
	end,
})
def('Gummy', { Name = 'Gummy', Box = 'Candy', rarity = 4,
	upper = C(222, 52, 130), upperKind = 'gloss', collar = K.snow, tongue = C(232, 70, 144), lace = C(255, 200, 225),
	sole = C(250, 200, 222), base = C(222, 52, 130), toe = C(250, 220, 234),
	deco = function(B, d) A.drips(B, d, K.snow, 'gloss', 4, 0.75) end,
})
def('SugarRush', { Name = 'Sugar Rush', Box = 'Candy', rarity = 5,
	upper = C(196, 36, 92), upperKind = 'gloss', collar = C(176, 28, 80), tongue = C(176, 28, 80), sole = C(250, 210, 228),
	base = C(210, 60, 120), toe = C(196, 36, 92), toeKind = 'gloss', lace = K.snow, heelGlow = C(255, 200, 226),
	deco = function(B, d) A.wings(B, d, C(255, 226, 240), C(255, 200, 226), 'smooth', 1.0) end,
})
def('CandyKingdom', { Name = 'Candy Kingdom', Box = 'Candy', rarity = 6,
	upper = C(214, 50, 140), upperKind = 'gloss', collar = C(196, 40, 126), tongue = C(214, 50, 140), sole = C(255, 170, 205),
	base = C(220, 90, 150), toe = C(214, 50, 140), toeKind = 'gloss', lace = K.snow, tongueLabel = false, tab = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 5)
		B:onShaft(function()
			-- a lollipop stuck in the back of the collar
			local base = B.cat(L.XC + 0.1, 0, B.collarZ)
			B:box('LollyStick', V(0.06, 0.6, 0.06), base + V(0, 0.24, 0), K.snow)
			B:cyl('Lolly', 0.08, 0.46, base + V(0, 0.68, 0), C(150, 120, 255), 'gloss', 'z')
			B:cyl('LollySwirl', 0.1, 0.24, base + V(0, 0.68, 0), K.snow, 'smooth', 'z')
		end)
	end,
})

-- 07 Ocean ---------------------------------------------------------------------------------------------------------
def('Wave', { Name = 'Wave', Box = 'Ocean', rarity = 1,
	upper = C(30, 150, 200), collar = K.snow, tongue = C(40, 162, 210), toe = K.snow, sole = K.snow,
	logo = { color = K.snow, glyph = 'dot', glyphColor = C(30, 150, 200) }, tab = C(30, 150, 200), tongueLabel = K.snow,
})
def('Coral', { Name = 'Coral', Box = 'Ocean', rarity = 2,
	upper = C(236, 112, 94), collar = C(40, 170, 200), tongue = C(244, 124, 104), tab = K.snow, toe = K.snow, sole = K.snow,
	base = C(40, 170, 200), logo = { kind = 'wave', color = K.snow }, tongueLabel = C(40, 170, 200),
})
def('Tidal', { Name = 'Tidal', Box = 'Ocean', rarity = 3,
	upper = C(24, 90, 130), collar = C(20, 70, 110), tongue = C(20, 70, 110), tab = C(90, 210, 240), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(60, 180, 220), tongueLabel = C(120, 230, 255),
	deco = function(B, d)
		B:onShaft(function() A.wave(B, L.U + 0.34, 0.06, 0.9, C(200, 240, 255), 'smooth') end)
		A.toeBadge(B, d, 'star', C(110, 200, 255), 'smooth', 0.26)
	end,
})
def('Pearl', { Name = 'Pearl', Box = 'Ocean', rarity = 4,
	upper = C(40, 150, 180), upperKind = 'gloss', collar = C(20, 60, 100), tongue = C(160, 220, 235), sole = C(40, 150, 180),
	base = C(20, 60, 100), toe = C(20, 60, 100), lace = K.snow,
	deco = function(B, d)
		-- a big pink pearl sitting on the toe in a gold cup
		local p = B.toeTop
		B:cyl('PearlCup', 0.08, 0.32, p + V(0, 0.02, 0), K.gold, 'gold', 'y')
		B:ball('Pearl', 0.28, p + V(0, 0.15, 0), C(255, 220, 236), 'gloss')
	end,
})
def('DeepSea', { Name = 'Deep Sea', Box = 'Ocean', rarity = 5,
	upper = C(24, 60, 120), upperKind = 'gloss', collar = C(20, 50, 104), tongue = C(20, 50, 104), sole = C(24, 60, 120),
	base = C(16, 40, 86), toe = C(24, 60, 120), toeKind = 'gloss', lace = K.snow, heelGlow = C(90, 235, 255),
	deco = function(B, d)
		B:onShaft(function()
			-- two fins standing up out of the back of the collar
			for _, f in { { L.XC - 0.14, 0.56 }, { L.XC + 0.24, 0.42 } } do
				B:tooth('Fin', 0.34, f[2], 0.06, CF(B.cat(f[1], 0.0, B.collarZ)) * ANG(0, rad(90), 0) * ANG(0, 0, rad(-14)), C(80, 220, 240), 'neon')
			end
		end)
	end,
})
def('Atlantis', { Name = 'Atlantis', Box = 'Ocean', rarity = 6,
	upper = C(20, 70, 110), upperKind = 'gloss', collar = C(30, 100, 140), tongue = C(20, 70, 110), sole = C(60, 200, 210),
	base = C(30, 140, 170), toe = C(20, 70, 110), toeKind = 'gloss', lace = C(255, 140, 170), tongueLabel = false, tab = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 1)
		B:onShaft(function()
			-- coral branches growing out of the back of the collar
			for _, c in { { L.XC - 0.22, 0.46, -12, C(255, 120, 150) }, { L.XC + 0.06, 0.6, 6, C(255, 150, 120) }, { L.XC + 0.32, 0.4, 20, C(255, 120, 150) } } do
				local cf = CF(B.cat(c[1], 0, B.collarZ)) * ANG(0, 0, rad(c[3]))
				B:box('Coral', V(0.09, c[2], 0.09), (cf * CF(0, c[2] / 2, 0)).Position, c[4], 'smooth', cf.Rotation)
				B:ball('CoralTip', 0.15, (cf * CF(0, c[2], 0)).Position, c[4], 'smooth')
			end
		end)
	end,
})

-- 08 Gem -----------------------------------------------------------------------------------------------------------
def('EmeraldKick', { Name = 'Emerald Kick', Box = 'Gem', rarity = 1,
	upper = C(30, 140, 72), collar = K.snow, tongue = C(36, 152, 80), toe = K.snow, sole = K.snow,
	logo = { color = C(255, 200, 50), glyph = 'dot', glyphColor = C(30, 140, 72), mat = 'gold' }, tongueLabel = C(255, 200, 50),
})
def('RubyRunner', { Name = 'Ruby Runner', Box = 'Gem', rarity = 2,
	upper = C(176, 26, 48), collar = C(255, 200, 50), collarKind = 'gold', tongue = C(190, 34, 56), tab = C(255, 200, 50),
	toe = K.snow, sole = K.snow, base = C(255, 196, 50), logo = { kind = 'gem', color = C(240, 244, 255) }, tongueLabel = C(255, 200, 50),
})
def('Facet', { Name = 'Facet', Box = 'Gem', rarity = 3,
	upper = C(30, 150, 80), collar = C(20, 90, 50), tongue = C(20, 90, 50), tab = C(20, 90, 50), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(60, 200, 130), tongueLabel = C(150, 255, 190),
	deco = function(B, d)
		A.speckles(B, d, { { 0.42, 0.22, 0.24, C(90, 220, 140), 45, 'Facet' }, { 0.26, -0.06, 0.2, C(20, 110, 60), 45, 'Facet' },
			{ 0.44, -0.3, 0.16, C(120, 240, 170), 45, 'Facet' } }, 'smooth')
		A.toeBadge(B, d, 'gem', C(80, 230, 140), 'gem', 0.28)
	end,
})
def('DiamondStep', { Name = 'Diamond Step', Box = 'Gem', rarity = 4,
	upper = C(214, 230, 244), upperKind = 'gloss', collar = C(255, 200, 50), collarKind = 'gold', tongue = C(230, 240, 250),
	sole = C(220, 236, 250), base = C(255, 196, 50), toe = C(255, 200, 50), toeKind = 'gold', lace = C(120, 170, 220),
	deco = function(B, d)
		A.speckles(B, d, { { 0.42, 0.2, 0.22, C(240, 250, 255), 45, 'Facet' }, { 0.26, -0.1, 0.18, C(170, 200, 230), 45, 'Facet' } }, 'smooth')
		A.toeBadge(B, d, 'gem', C(210, 240, 255), 'gem', 0.3)
	end,
})
def('CrystalCrown', { Name = 'Crystal Crown', Box = 'Gem', rarity = 5,
	upper = C(24, 120, 66), upperKind = 'gloss', collar = C(16, 80, 44), tongue = C(16, 80, 44), sole = C(24, 120, 66),
	base = C(14, 70, 40), toe = C(24, 120, 66), toeKind = 'gloss', lace = K.snow, heelGlow = C(130, 255, 190),
	deco = function(B, d) A.crystals(B, d, C(150, 255, 200), 'gem', 5, 1.0) end,
})
def('PrismCore', { Name = 'Prism Core', Box = 'Gem', rarity = 6,
	upper = C(20, 70, 44), upperKind = 'gloss', collar = C(16, 60, 38), tongue = C(20, 70, 44), sole = C(60, 200, 130),
	base = C(30, 140, 90), toe = C(20, 70, 44), toeKind = 'gloss', lace = K.snow, tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 3)
		B:onShaft(function()
			for i, c in { { B.cat(L.XC + 0.3, 0.0, B.collarZ), 0.7, 10, RAINBOW[5] }, { B.cat(L.XC - 0.18, 0, B.collarZ), 0.56, -14, RAINBOW[6] },
				{ B.cat(L.XO - 0.08, 0, 0.1), 0.5, 18, RAINBOW[1] } } do
				B:tooth('Prism', 0.28, c[2], 0.2, CF(c[1]) * ANG(0, rad(i * 50), 0) * ANG(0, 0, rad(c[3])), c[4], 'gem')
			end
		end)
	end,
})

-- 09 Galaxy --------------------------------------------------------------------------------------------------------
def('NightSky', { Name = 'Night Sky', Box = 'Galaxy', rarity = 1,
	upper = C(40, 70, 176), collar = K.snow, tongue = C(48, 80, 188), toe = K.snow, sole = K.snow,
	logo = { color = C(60, 200, 220), glyph = 'dot', glyphColor = K.snow }, tongueLabel = C(60, 200, 220),
})
def('Comet', { Name = 'Comet', Box = 'Galaxy', rarity = 2,
	upper = C(104, 72, 196), collar = C(226, 228, 240), tongue = C(114, 82, 206), tab = C(255, 200, 50), toe = K.snow, sole = K.snow,
	base = C(150, 120, 230), logo = { kind = 'moon', color = C(255, 200, 50), mat = 'gold' }, tongueLabel = C(255, 200, 50),
})
def('Nebula', { Name = 'Nebula', Box = 'Galaxy', rarity = 3,
	upper = C(30, 28, 70), collar = C(24, 22, 40), tongue = C(24, 22, 40), tab = C(170, 150, 255), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(150, 130, 230), tongueLabel = C(190, 170, 255),
	deco = function(B, d)
		A.splats(B, d, { { 0.42, 0.18, 0.32, C(90, 60, 170) }, { 0.26, -0.18, 0.24, C(150, 70, 170), nil, 1 } })
		B:onShaft(function() A.star(B, sideCF(L.U + 0.42, -0.06, 0.035), 0.24, K.snow, 'neon') end)
	end,
})
def('Supernova', { Name = 'Supernova', Box = 'Galaxy', rarity = 4,
	upper = C(110, 70, 210), upperKind = 'gloss', collar = C(30, 26, 60), tongue = C(130, 90, 225), lace = C(214, 200, 255),
	sole = C(30, 26, 60), base = C(22, 20, 44), toe = C(30, 26, 60), airCore = C(214, 200, 255),
	deco = function(B, d)
		B:onShaft(function() A.star(B, sideCF(L.U + 0.36, 0.1, 0.02), 0.4, K.snow, 'neon') end)
	end,
})
def('CosmicWings', { Name = 'Cosmic Wings', Box = 'Galaxy', rarity = 5,
	upper = C(30, 28, 80), upperKind = 'gloss', collar = C(24, 22, 50), tongue = C(24, 22, 50), sole = C(30, 28, 80),
	base = C(20, 18, 50), toe = C(30, 28, 80), toeKind = 'gloss', lace = K.snow, heelGlow = C(190, 170, 255),
	deco = function(B, d) A.wings(B, d, C(110, 70, 220), C(70, 50, 170), 'gloss', 1.0) end,
})
def('BlackHole', { Name = 'Black Hole', Box = 'Galaxy', rarity = 6,
	upper = C(22, 20, 32), upperKind = 'gloss', collar = C(34, 30, 52), tongue = C(22, 20, 32), sole = C(40, 36, 70),
	base = C(24, 22, 44), toe = C(22, 20, 32), toeKind = 'gloss', lace = C(200, 170, 255), tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 5)
		B:onShaft(function()
			-- the black hole: a glowing ring round a dark core, on the outer wall
			sideDisc(B, 'HoleGlow', 0.44, L.U + 0.42, 0.14, C(190, 120, 255), 'neon', 0.012, 0.024)
			sideDisc(B, 'HoleCore', 0.28, L.U + 0.42, 0.14, C(8, 6, 14), 'smooth', 0.02, 0.026)
		end)
	end,
})

-- 10 Gold ----------------------------------------------------------------------------------------------------------
def('GoldRush', { Name = 'Gold Rush', Box = 'Gold', rarity = 1,
	upper = C(222, 180, 52), collar = K.snow, tongue = C(230, 190, 64), toe = K.snow, sole = K.snow,
	logo = { color = C(84, 56, 170), glyph = 'plus', glyphColor = C(255, 210, 70) }, tongueLabel = C(84, 56, 170),
})
def('Royal', { Name = 'Royal', Box = 'Gold', rarity = 2,
	upper = C(64, 44, 156), collar = C(255, 200, 50), collarKind = 'gold', tongue = C(74, 52, 168), tab = C(255, 200, 50),
	toe = K.snow, sole = K.snow, base = C(255, 196, 50), logo = { kind = 'plus1', color = C(255, 200, 50), mat = 'gold' },
	tongueLabel = C(255, 200, 50),
})
def('Monogram', { Name = 'Monogram', Box = 'Gold', rarity = 3,
	upper = C(54, 36, 130), collar = C(46, 30, 116), tongue = C(46, 30, 116), tab = C(255, 200, 50), lace = K.snow, toe = K.snow,
	sole = K.snow, base = C(255, 196, 50), tongueLabel = C(255, 200, 50),
	deco = function(B, d)
		B:onShaft(function()
			A.plusOne(B, L.U + 0.4, 0.22, 0.24, C(255, 200, 50), 'gold', 0.02)
			A.plusOne(B, L.U + 0.2, -0.2, 0.18, C(255, 200, 50), 'gold', 0.02)
		end)
	end,
})
def('TwentyFourKarat', { Name = '24 Karat', Box = 'Gold', rarity = 4,
	upper = C(255, 196, 50), upperKind = 'gold', collar = K.snow, tongue = C(255, 200, 60), tongueKind = 'gold', lace = C(84, 56, 170),
	sole = K.snow, base = C(255, 196, 50), toe = K.snow, tab = C(84, 56, 170), tabKind = 'smooth', tongueLabel = C(84, 56, 170),
	deco = function(B, d)
		B:onShaft(function() A.plusOne(B, L.U + 0.34, 0.1, 0.3, C(84, 56, 170), 'smooth', 0.02) end)
	end,
})
def('KingsCrown', { Name = "King's Crown", Box = 'Gold', rarity = 5,
	upper = C(64, 44, 156), upperKind = 'gloss', collar = C(54, 36, 140), tongue = C(54, 36, 140), lace = C(255, 210, 70),
	sole = C(255, 196, 50), soleKind = 'gold', base = C(220, 150, 30), toe = C(255, 200, 50), toeKind = 'gold', tab = false,
	heelGlow = C(255, 230, 140),
	deco = function(B, d)
		B:onShaft(function()
			A.crown(B, CF(B.cat(L.XC, 0.06, B.collarZ)) * ANG(0, math.pi, 0), 0.5, C(255, 200, 50), C(230, 40, 60))
		end)
	end,
})
def('PlusOneInfinity', { Name = '+1 Infinity', Box = 'Gold', rarity = 6,
	upper = C(50, 34, 120), upperKind = 'gloss', collar = C(60, 42, 140), tongue = C(50, 34, 120), sole = C(255, 196, 50),
	soleKind = 'gold', base = C(214, 150, 30), toe = C(50, 34, 120), toeKind = 'gloss', lace = C(255, 206, 70), tongueLabel = false,
	tab = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 2)
		B:onShaft(function()
			-- the infinity sign: two glowing rings side by side over the heel, on a gold post seated in the collar
			for i, sz in { -1, 1 } do
				local p = B.cat(L.XC + sz * 0.19, 0.4, B.collarZ)
				B:cyl('Infinity', 0.06, 0.38, p, RAINBOW[i == 1 and 1 or 5], 'neon', 'z')
				B:cyl('InfinityHole', 0.08, 0.18, p, C(50, 34, 120), 'smooth', 'z')
			end
			B:box('InfinityPost', V(0.07, 0.24, 0.07), B.cat(L.XC, 0.1, B.collarZ), K.gold, 'gold')
		end)
	end,
})

-- Robux boxes (brief 21) ---------------------------------------------------------------------------------------------
-- Their own list, so Ids stays the 60 Cash-box shoes box by box. (brief 24) Premium finishes no Cash shoe wears, from
-- Rare up: mirror chrome, smooth gold, gems and hologram glass, glowing (neon) laces, flashes and stripes.
local EXCLUSIVE = {}
local function xdef(id, t)
	t.Id = id
	DEFS[id] = t
	table.insert(EXCLUSIVE, id)
end
local ICE, PINKGLOW = C(90, 230, 255), C(255, 140, 220)
local CHROME, CHROME2, NAVY = C(196, 204, 220), C(158, 168, 188), C(40, 44, 62)
-- Exclusive Box: chrome, midnight, rainbow and hologram, ice-blue light.
xdef('SilverStreak', { Name = 'Silver Streak', Box = 'Exclusive', rarity = 2,
	upper = CHROME, upperKind = 'chrome', collar = NAVY, tongue = NAVY, tab = ICE, tabKind = 'neon', lace = C(236, 250, 255),
	toe = NAVY, sole = K.snow, base = NAVY, flash = ICE, flashKind = 'neon', logo = { kind = 'bolt', color = ICE, mat = 'neon' },
	tongueLabel = ICE, tongueLabelKind = 'neon',
})
xdef('MidnightChrome', { Name = 'Midnight Chrome', Box = 'Exclusive', rarity = 3,
	upper = C(34, 36, 56), upperKind = 'gloss', collar = C(28, 30, 48), tongue = C(34, 36, 56), lace = ICE, toe = CHROME,
	toeKind = 'chrome', sole = CHROME2, soleKind = 'chrome', base = C(28, 30, 46), tab = ICE, tabKind = 'neon', tongueLabel = ICE,
	tongueLabelKind = 'neon',
	deco = function(B, d)
		B:onShaft(function() A.zigzag(B, L.U + 0.36, 0.06, 0.8, ICE, 'neon', 0.02) end)
		A.toeBadge(B, d, 'sparkle', ICE, 'neon', 0.26)
	end,
})
xdef('RainbowDrip', { Name = 'Rainbow Drip', Box = 'Exclusive', rarity = 4, fx = { tex = 'sparkle', colors = { C(255, 120, 200), C(120, 220, 255), C(255, 236, 120) } },
	upper = C(248, 248, 252), upperKind = 'gloss', collar = C(255, 90, 160), tongue = C(248, 248, 252), lace = C(255, 90, 160),
	sole = K.snow, base = C(80, 200, 255), toe = C(80, 200, 255), tongueLabel = C(255, 90, 160), tongueLabelKind = 'neon',
	deco = function(B, d) A.drips(B, d, RAINBOW[1], 'gloss', 4, 1.0, { RAINBOW[1], RAINBOW[3], RAINBOW[5], RAINBOW[6] }) end,
})
xdef('Hologram', { Name = 'Hologram', Box = 'Exclusive', rarity = 5, fx = { tex = 'sparkle', colors = { C(170, 240, 255), C(255, 170, 230) } },
	upper = C(186, 160, 255), upperKind = 'holo', collar = C(120, 230, 240), collarKind = 'gloss', tongue = C(240, 244, 255), tongueKind = 'gloss',
	lace = C(255, 150, 222), laceKind = 'neon', toe = C(214, 226, 250), toeKind = 'chrome', sole = C(244, 246, 255), base = C(255, 140, 220),
	laceBed = C(150, 120, 230), flash = C(120, 230, 240), flashKind = 'gloss', heelGlow = C(255, 150, 222),
	deco = function(B, d)
		A.wings(B, d, C(170, 240, 255), C(255, 170, 230), 'holo', 1.0)
	end,
})
xdef('PlatinumWings', { Name = 'Platinum Wings', Box = 'Exclusive', rarity = 6,
	upper = CHROME, upperKind = 'chrome', collar = C(70, 80, 110), collarKind = 'gloss', tongue = CHROME, tongueKind = 'chrome',
	lace = ICE, laceKind = 'neon', sole = C(244, 246, 252), base = C(70, 80, 110), toe = C(70, 80, 110), toeKind = 'gloss',
	tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 3)
		A.wings(B, d, C(252, 252, 255), CHROME2, 'chrome', 1.0)
	end,
})
-- Grail Box: gold, starlight, sun flares and royal purple.
local SUN, GOLDEN, ROYAL = C(255, 120, 60), C(255, 205, 60), C(80, 40, 160)
xdef('GoldenHour', { Name = 'Golden Hour', Box = 'Grail', rarity = 2,
	upper = C(255, 198, 56), upperKind = 'gold', collar = K.snow, tongue = C(255, 208, 76), tab = SUN, toe = K.snow, sole = K.snow,
	base = SUN, flash = SUN, flashKind = 'neon', logo = { kind = 'sparkle', color = SUN, mat = 'neon' }, tongueLabel = SUN,
})
xdef('Starlight', { Name = 'Starlight', Box = 'Grail', rarity = 3,
	upper = C(28, 34, 90), upperKind = 'gloss', collar = C(24, 28, 76), tongue = C(28, 34, 90), tab = GOLDEN, tabKind = 'gold',
	lace = C(240, 240, 255), sole = K.snow, base = C(255, 200, 60), toe = GOLDEN, toeKind = 'gold', tongueLabel = C(255, 214, 80),
	deco = function(B, d)
		B:onShaft(function() A.star(B, sideCF(L.U + 0.36, 0.1, 0.02), 0.38, C(255, 214, 80), 'gold') end)
	end,
})
xdef('SolarFlare', { Name = 'Solar Flare', Box = 'Grail', rarity = 4, fx = { tex = 'ember', colors = { C(255, 200, 60), C(255, 120, 40) } },
	upper = C(255, 176, 40), upperKind = 'gloss', collar = C(60, 30, 20), tongue = C(255, 190, 60), lace = C(255, 240, 200),
	sole = C(60, 30, 20), base = C(255, 90, 40), toe = C(255, 90, 40), toeKind = 'gloss', airCore = C(255, 220, 120),
	deco = function(B, d) A.collarFlames(B, d, C(255, 110, 40), C(255, 230, 90), 'neon') end,
})
xdef('AstroCrown', { Name = 'Astro Crown', Box = 'Grail', rarity = 5, fx = { tex = 'star', colors = { C(255, 214, 90), C(190, 150, 255) } },
	upper = ROYAL, upperKind = 'gloss', collar = C(30, 20, 60), tongue = C(30, 20, 60), lace = C(255, 214, 80), sole = C(30, 20, 60),
	base = C(255, 196, 50), toe = GOLDEN, toeKind = 'gold', tab = false, heelGlow = C(190, 150, 255),
	deco = function(B, d)
		B:onShaft(function()
			A.crown(B, CF(B.cat(L.XC, 0.06, B.collarZ)) * ANG(0, math.pi, 0), 0.5, GOLDEN, C(120, 220, 255))
		end)
	end,
})
xdef('TheGrail', { Name = 'The Grail', Box = 'Grail', rarity = 6,
	upper = C(255, 202, 60), upperKind = 'gold', collar = C(110, 50, 190), collarKind = 'gloss', tongue = C(255, 208, 76),
	tongueKind = 'gold', lace = C(170, 90, 255), sole = K.snow, base = C(170, 90, 255), toe = C(170, 90, 255), toeKind = 'gem',
	tongueLabel = false,
	deco = function(B, d)
		A.rainbowFlash(B, d, 4)
		A.wings(B, d, C(255, 236, 170), GOLDEN, 'gold', 1.0)
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
	d.stripe = d.stripe or K.ink
	-- the outsole: dark rubber under a light midsole, else the midsole's colour a quarter darker
	d.base = d.base or (lum(d.sole) > 0.7 and C(54, 56, 66) or dark(d.sole, 0.25))
	-- the lining inside the opening: dark (a hint of the collar's colour), so the opening reads as the inside of a
	-- shoe, not a lid
	d.lining = d.lining or dark(d.collar:Lerp(C(40, 40, 52), 0.6), 0.25)
	-- the finish ladder (a definition's own choices win), one showpiece per step:
	--   Common    matte canvas
	--   Rare      a leather sheen and a glossy rubber toe cap (a highlight band in the 3/4)
	--   Epic      + a polished silver heel counter (its side swoop and the heel cup)
	--   Legendary + the counter in gold, gold trims (pull loop, tongue label, the aglet bar on top of the laces) and
	--             the glass air window
	--   Mythic    + a neon line along the midsole on both sides, and its signature
	--   Secret    + a rainbow neon outsole and the rainbow flash, and its signature
	d.upperKind = d.upperKind or (r == 1 and 'fabric' or 'smooth')
	d.toeKind = d.toeKind or (r >= 2 and 'rubber' or 'smooth')
	if d.heel == nil and r >= 3 then
		d.heel, d.heelKind = r == 3 and C(210, 216, 226) or K.gold, r == 3 and 'silver' or 'gold'
		-- (on an upper of nearly the same tone the metal would vanish: it turns to mirror chrome, darker than a pale
		-- upper and bright where it catches the sky)
		local function near(a, b) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.45 end
		if near(d.upper, d.heel) then
			if r > 3 then
				d.heel, d.heelKind = C(196, 204, 220), 'chrome'
			else
				d.heel, d.heelKind = C(170, 178, 196), 'chrome'
			end
		end
	end
	d.heelH = d.heelH or 0.34
	if d.aglet == nil and r >= 4 then d.aglet = K.gold end
	if d.air == nil then d.air = r == 4 end
	if r == 5 and d.soleGlow == nil then d.soleGlow = d.glow or d.heelGlow or d.collar end
	d.heelGlow = nil
	if r == 6 and d.rainbowSole == nil then d.rainbowSole = true end
	d.baseKind = d.baseKind or 'plastic'
	d.soleKind = d.soleKind or 'smooth'
	if d.tab == nil and d.logo and d.rarity == 1 then d.tab = d.logo.color end
	if r >= 4 and d.tabKind == nil and d.tab ~= false then d.tab, d.tabKind = K.gold, 'gold' end
	if r == 3 and d.tabKind == nil then d.tabKind = 'metal' end
	if r >= 4 and d.tongueLabel == nil then d.tongueLabel, d.tongueLabelKind = K.gold, 'gold' end
	if d.flashKind == nil then d.flashKind = r == 3 and 'metal' or 'smooth' end
	-- the side flash: a Common's logo colour (its one accent), else the outsole's or the heel's tone
	-- (the side flash is a definition's choice: none by default, so a print or a logo owns the wall)
	if d.flash == nil then d.flash = false end
	d._filled = true
	return d
end

-- The specs of the right shoe for a definition.
local function recipe(d)
	d = filled(d)
	local B = newBuilder(d)
	CUR = B
	B.U = L.U
	buildSole(B, d)
	buildUpper(B, d)
	buildFront(B, d)
	buildCollar(B, d)
	if d.rainbowLaces then
		local i = 0
		for _, s in B.list do
			if s.name == 'Lace' or s.name == 'LaceBow' then
				i += 1
				s.color = RAINBOW[((d.rainbowOffset or 0) + 2 * (i - 1)) % #RAINBOW + 1]
				s.kind = 'smooth'
			end
		end
	end
	A.logo(B, d)
	if d.heelGlow then A.heelStrip(B, d, d.heelGlow, 'neon') end
	if d.deco then d.deco(B, d) end
	CUR = nil
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
	p.Color = spec.kind == 'gold' and spec.color:Lerp(GOLD_LIFT, 0.55) or spec.color
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
	if spec.mesh then
		local mesh = Instance.new('SpecialMesh')
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
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
-- (brief 24) Worn shoes are a size up: big cartoon sneakers that read from the follow camera. They grow away from the
-- inner side (the two shoes still meet at the body's centre line) and up from the ground (soles stay on it).
ShoeModels.WornChunk = V(1.12, 1.08, 1.1)
local function chunky(cf, size, side)
	local base = CF((side == 'L' and -1 or 1) * L.XI, -FIT.Y / 2, 0)
	local rel, sz = scaled(base:Inverse() * cf, size, ShoeModels.WornChunk)
	return base * rel, sz
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
function ShoeModels.wear(character: Model, id: string, opts: { noFx: boolean?, fxDensity: number? }?): () -> ()
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
				local cf, size0 = chunky(fitCF(s, side), s.size, side)
				if r15 and s.shaft and leg and leg:IsA('BasePart') and fLeg then
					-- shaft pieces: measured from the top of the foot = the bottom of the lower leg
					host = leg
					anchorLeg = CF(0, -leg.Size.Y / 2, 0)
					local rel, sz = scaled(CF(0, -FIT.Y / 2, 0) * cf, size0, fLeg)
					c0, size = anchorLeg * rel, sz
				else
					local rel, sz = scaled(cf, size0, f)
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
			table.insert(fxHosts, { Part = foot, At = anchorFoot or CFrame.identity, Scale = f, Side = side })
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
	if not opts.noFx and d.rarity >= 2 and #fxHosts > 0 then
		-- other players' feet get 60 % of the particles (every layer stays, so their rarity still reads)
		local density = opts.fxDensity
		if density == nil then
			local ok, other = pcall(function()
				local Players = game:GetService('Players')
				local me = Players.LocalPlayer
				return me ~= nil and Players:GetPlayerFromCharacter(character) ~= me
			end)
			if ok and other then density = 0.6 end
		end
		ShoeModels.fx(m, d.rarity, { context = 'worn', feet = fxHosts, id = d.Id, density = density })
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
-- The rarity effects live in Shared/ShoeFX (brief 24: one ladder for worn shoes, followers and the reveal's data).
-- ShoeModels only adds each shoe's own theme (its box's, or a definition's `fx` override) and the worn feet.
local FX -- Shared.ShoeFX, required on first use (false when missing)
local function shoeFX()
	if FX == nil then
		local ok, m = pcall(function()
			local node = script.Parent.Parent:FindFirstChild('ShoeFX')
			return node and require(node)
		end)
		FX = ok and type(m) == 'table' and m or false
	end
	return FX or nil
end
-- A shoe's particle theme: its box's (ShoeFX.Themes), or the definition's own `fx = { tex, colors }`.
local function themeOf(sdef)
	local F = shoeFX()
	local theme = F and F.Themes[sdef.Box] or { tex = 'sparkle', colors = { C(255, 255, 255) } }
	if sdef.fx then theme = { tex = sdef.fx.tex or theme.tex, colors = sdef.fx.colors or theme.colors } end
	return theme
end
ShoeModels.Themes = shoeFX() and shoeFX().Themes or {}

-- Rarity effects on a pair or a shoe (followers, displays): ShoeFX.apply with the shoe's theme. rarity: 1..6 or
-- 'Common'..'Secret'. opts are ShoeFX.apply's (context 'follower' by default). Returns the ShoeFX holder, or nil for a
-- Common (or without ShoeFX).
function ShoeModels.fx(model: Instance, rarity: any, opts: { [string]: any }?): BasePart?
	local F = shoeFX()
	if not F then return nil end
	local o = table.clone(opts or {})
	local sid = o.id or model:GetAttribute('ShoeId')
	local sdef = type(sid) == 'string' and DEFS[sid] or nil
	if sdef and not o.theme then o.theme = themeOf(sdef) end
	if o.worn and o.host then
		-- (the older per-foot form)
		o.context = 'worn'
		o.feet = o.feet or { { Part = o.host, At = o.at, Scale = o.scale } }
		o.scale = nil
	end
	return F.apply(model, rarity, o)
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
