-- Hood props: the 9 training stations, each tier visibly better than the last.
-- Built by map builders (TheBlockV2) with their build context; never runs during gameplay.
--
-- Tier ladder (research_notes/Tiered props VFX and vibrant maps/prop_modeling_and_tiers.md):
-- every tier changes at least two of colour / material / size / ornaments / effects / pedestal, and a
-- brand-new channel arrives every 2-3 tiers: first light (Heavy), first particles (Speed), first moving
-- part (Double-End), then full-body glow + halo + floating gems for Gold and hue-cycling for the Ring.
--   1 Tire       junk rubber + wood gallows, cracked slab           grey
--   2 Tape       taped leather + scaffold pipes, pallet             green
--   3 Street     tagged canvas + street-sign post, curb, ground ring blue
--   4 Heavy      glossy leather + black steel, plinth, first light   purple
--   5 Speed      speed bag on chrome bracket, step plinth, sparkles  pink
--   6 DoubleEnd  neon bungees, octagon stage, sparks, orbiting ring  cyan
--   7 Pro        black/red/gold, industrial frame, embers, emblem    red
--   8 Gold       gold + diamonds, marble dais, god-ray, gems, halo   gold
--   9 Ring       hue-cycling ropes, belt hologram, confetti          rainbow
local Props = {}

local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material

Props.Rarity = {
	C(170, 174, 184), C(76, 217, 100), C(64, 156, 255), C(170, 85, 255), C(255, 90, 200),
	C(60, 230, 255), C(255, 60, 60), C(255, 200, 60), C(255, 255, 255),
}
Props.TierName = { 'COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'EXOTIC', 'SUPERIOR', 'MYTHIC', 'LEGENDARY', 'CHAMPION' }

-- Effect textures. Paste uploaded ids for hood/art/vfx/*.png here; empty entries fall back to textures
-- that ship with Roblox, so effects work before anything is uploaded.
Props.Textures = { sparkle = '', glow = '', star = '', ring = '', smoke = '', streak = '', shard = '', confetti = '', pow = '', lightning = '', energy = '' }
-- Textures that ship with the Roblox client (vfx_handbook.md, "built-in textures").
local BUILTIN = {
	sparkle = 'rbxasset://textures/particles/sparkles_main.dds', star = 'rbxasset://textures/particles/sparkles_main.dds',
	glow = 'rbxasset://textures/glow.png', streak = 'rbxasset://textures/glow.png', pow = 'rbxasset://textures/particles/sparkles_main.dds',
	smoke = 'rbxasset://textures/particles/smoke_main.dds', ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds',
	confetti = 'rbxasset://textures/particles/SquareParticle.png', shard = 'rbxasset://textures/particles/SquareParticle.png',
	energy = 'rbxasset://textures/glow.png', lightning = 'rbxasset://textures/glow.png',
}
local function textureFor(name)
	local id = Props.Textures[name]
	if id and id ~= '' then return id end
	return BUILTIN[name] or BUILTIN.sparkle
end

local function seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
local function cseq(a, b) return ColorSequence.new(a, b or a) end

-- ParticleEmitter at `pos` (in the ctx frame). `props` are set as-is. With `shell` (a Vector3 size) the
-- emitter sits on an invisible part of that size, so particles start on a shape around the prop instead
-- of inside it (a point emitter in the middle of a bag hides most of its particles in the bag).
local function emitter(c, name, pos, texture, props, shell)
	local holder = c:part(name .. 'FX', shell or V(0.2, 0.2, 0.2), CFrame.new(pos), C(255, 255, 255))
	holder.Transparency, holder.CanCollide, holder.CanTouch, holder.CanQuery, holder.CastShadow = 1, false, false, false, false
	local a = holder
	if not shell then
		a = Instance.new('Attachment')
		a.Parent = holder
	end
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Texture = textureFor(texture)
	e:SetAttribute('PreviewTexture', texture)
	e.LightInfluence = 0 -- glows stay bright at night; set 1 in props for lit things (confetti, smoke)
	for k, v in props do e[k] = v end
	e.Parent = a
	return e, holder
end

local function motion(inst, attrs)
	for k, v in attrs do inst:SetAttribute(k, v) end
	-- Spin and bob happen around the model's pivot: put it at the centre of the decoration.
	if inst:IsA('Model') then inst.WorldPivot = CFrame.new((inst:GetBoundingBox()).Position) end
	inst:AddTag('HoodMotion') -- animated on clients by HoodClient/WorldMotion
	return inst
end

---------------------------------------------------------------------------------------------- shared detail kit
-- Chain from a to b: alternating flat links, each turned 90 degrees from the last.
local function chain(c, a, b, link, color, material)
	local dir = b - a
	local n = math.max(1, math.floor(dir.Magnitude / link + 0.5))
	-- A straight-down chain is parallel to the default up vector, which makes lookAt degenerate.
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	for k = 0, n - 1 do
		local p0, p1 = a + dir * (k / n), a + dir * ((k + 1) / n)
		local cf = CFrame.lookAt((p0 + p1) / 2, p1, up) * CFrame.Angles(0, 0, (k % 2) * math.pi / 2)
		c:part('ChainLink', V(link * 0.55, link * 0.2, link * 1.15), cf, color, material or M.Metal)
	end
end

-- Faceted N-sided plinth: N/2 blocks rotated about Y, each as wide as one facet, so the outline is a
-- regular polygon with apothem r. Overlaps are the same colour, so they never show a seam.
local function polygonPlinth(c, name, center, r, y0, y1, color, material, sides)
	sides = sides or 8
	local w = 2 * r * math.tan(math.pi / sides)
	for k = 0, sides / 2 - 1 do
		c:part(name, V(w, y1 - y0, 2 * r), CFrame.new(center.X, (y0 + y1) / 2, center.Z) * CFrame.Angles(0, k * 2 * math.pi / sides, 0), color, material)
	end
end

-- Round bag hanging on the station axis: cylinder core, ellipsoid belly (the cartoon bulge), rounded
-- caps, seam bands, a strap with buckle, four D-rings and a chain spider up to a swivel.
-- Returns the swivel position (where the hanging chain starts).
local function bag(c, o)
	local x, z, bottom, r, h = o.x or 0, o.z or 1.2, o.bottom, o.radius, o.height
	local top = bottom + h
	-- Barrel profile: slimmer ends, a fatter middle (the cartoon bulge). Seam bands sit exactly on the two
	-- steps, so no curved surfaces ever intersect (that shows as a jagged seam).
	local mat = o.material or M.SmoothPlastic
	local belly = r * 1.08
	c:post('BagLower', r, h * 0.28, V(x, bottom, z), o.body, mat)
	c:post('BagBelly', belly, h * 0.44, V(x, bottom + h * 0.28, z), o.body, mat)
	c:post('BagUpper', r, h * 0.28, V(x, bottom + h * 0.72, z), o.body, mat)
	if o.highlight then c:post('BagShine', belly + 0.02, h * 0.1, V(x, bottom + h * 0.56, z), o.highlight, mat) end
	c:blob('BagTopCap', V(r * 1.96, r * 0.62, r * 1.96), V(x, top, z), o.cap, o.capMaterial or M.SmoothPlastic)
	c:blob('BagBottomCap', V(r * 1.96, r * 0.62, r * 1.96), V(x, bottom, z), o.cap, o.capMaterial or M.SmoothPlastic)
	for _, f in { 0.28, 0.72 } do c:post('SeamBand', belly + 0.07, 0.18, V(x, bottom + f * h - 0.09, z), o.seam, M.SmoothPlastic) end
	for _, f in o.bands or {} do c:post('SeamBand', (f > 0.28 and f < 0.72 and belly or r) + 0.07, 0.14, V(x, bottom + f * h - 0.07, z), o.seam, M.SmoothPlastic) end
	if o.strap then
		local sy = bottom + h * 0.5 - 0.22
		c:post('Strap', belly + 0.04, 0.44, V(x, sy, z), o.strap, M.Fabric)
		c:box('Buckle', V(x - 0.32, sy - 0.08, z - belly - 0.18), V(x + 0.32, sy + 0.52, z - belly + 0.02), o.metal, M.Metal)
	end
	-- D-rings on the top cap and a four-strand spider up to the swivel.
	local swivel = V(x, top + r * 0.35 + 1.3, z)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local ring = V(x + math.cos(a) * r * 0.62, top + r * 0.22, z + math.sin(a) * r * 0.62)
		c:part('DRing', V(0.14, 0.5, 0.5), CFrame.lookAt(ring, ring + V(math.cos(a), 0, math.sin(a))) * CFrame.Angles(0, math.pi / 2, 0), o.metal, M.Metal, Enum.PartType.Cylinder)
		c:bar('Spider', ring, swivel, 0.1, o.metal)
	end
	c:part('Swivel', V(0.55, 0.55, 0.55), CFrame.new(swivel), o.metal, M.Metal, Enum.PartType.Ball)
	return swivel
end

-- Nameplate on the pedestal front (the face toward -Z): rarity strip, name, multiplier and tier stars.
local function nameplate(c, kit, s, tier, y, width, front)
	local color = Props.Rarity[tier]
	local f = front or 4.05
	local plate = c:box('Nameplate', V(-width / 2, y, -f - 0.2), V(width / 2, y + 1.3, -f), C(24, 24, 30), M.SmoothPlastic)
	c:box('NameplateStrip', V(-width / 2, y - 0.2, -f - 0.25), V(width / 2, y, -f), color, tier >= 4 and M.Neon or M.SmoothPlastic)
	local g = kit.surface(plate, Enum.NormalId.Front, 50)
	kit.line(g, 'Title', string.upper(s.Name), C(255, 255, 255), kit.FONT.title, 0.04, 0.5, C(0, 0, 0), 2)
	kit.line(g, 'Detail', 'x' .. s.Multiplier .. '   ' .. string.rep('★', math.min(5, math.ceil(tier / 2))), color, kit.FONT.loud, 0.54, 0.42, C(0, 0, 0), 2)
end

-- Price/requirement label above the station, readable from any angle.
local function priceTag(c, kit, s, tier, y)
	local color = Props.Rarity[tier]
	local a = kit.billboard(c, V(0, y, 1.2), 6, 1.9, {
		{ 'Title', 'x' .. s.Multiplier .. ' POWER', color, kit.FONT.loud, 0, 0.56 },
		{ 'Detail', s.Required == 0 and 'FREE' or kit.compact(s.Required) .. ' POWER', C(255, 255, 255), kit.FONT.body, 0.58, 0.4 },
	})
	a.WorldLabel.MaxDistance = 70
	return a
end

-- Gallows: post on the back-left corner, arm over the bag, diagonal brace, foot plate.
local function gallows(c, o)
	local y0, top, w = o.y0, o.top, o.width or 0.9
	local postX, postZ = -3.0, 2.8
	c:box('Post', V(postX - w / 2, y0, postZ - w / 2), V(postX + w / 2, top, postZ + w / 2), o.color, o.material)
	c:box('Arm', V(postX + w / 2, top - w, 1.2 - w / 2), V(0.6, top, 1.2 + w / 2), o.color, o.material)
	c:box('ArmBack', V(postX - w / 2, top - w, 1.2 - w / 2), V(postX + w / 2, top, postZ - w / 2), o.color, o.material)
	c:bar('Brace', V(postX, top - 2.6, postZ - 0.2), V(postX + 1.9, top - w / 2, 1.2), w * 0.55, o.color, o.material)
	c:box('Foot', V(postX - w, y0, postZ - w), V(postX + w, y0 + 0.3, postZ + w), o.foot or o.color, o.material)
	if o.cap then c:box('PostCap', V(postX - w / 2 - 0.15, top, postZ - w / 2 - 0.15), V(postX + w / 2 + 0.15, top + 0.3, postZ + w / 2 + 0.15), o.cap, o.capMaterial or o.material) end
	return V(0, top - w, 1.2)
end

---------------------------------------------------------------------------------------------- tiers
-- The ladder (research_notes/Front page feel and gamey stages/hood_style_and_bags.md, "Bag ladder
-- redesign"): street junk (1-3), the gym classic (4-6), the pro (7), gold (8), the arena (9). Every tier
-- has its own silhouette and adds one new privilege on top of the ones before it.
local Build = {}
local IRON = C(43, 38, 51) -- black-plum, never pure black
local function crateAt(c, x, y, z, color)
	c:box('CrateBase', V(x - 0.8, y, z - 0.8), V(x + 0.8, y + 0.15, z + 0.8), color, M.SmoothPlastic)
	for _, s in { { V(-0.8, 0.15, -0.8), V(0.8, 1.4, -0.65) }, { V(-0.8, 0.15, 0.65), V(0.8, 1.4, 0.8) }, { V(-0.8, 0.15, -0.65), V(-0.65, 1.4, 0.65) }, { V(0.65, 0.15, -0.65), V(0.8, 1.4, 0.65) } } do
		c:box('CrateSide', V(x, y, z) + s[1], V(x, y, z) + s[2], color, M.SmoothPlastic)
	end
end

function Build.Starter(c, kit, s) -- "Corner Tire": the free bag that belongs to the sidewalk
	local T = 1
	-- Sidewalk slab with a chalk hopscotch, a milk-crate seat and a cardboard FREE sign.
	c:box('Slab', V(-4, 0, -4), V(4, 0.3, 4), C(216, 208, 194), M.Concrete)
	for k, col in { C(255, 210, 63), C(99, 191, 255), C(255, 143, 184) } do
		c:box('Chalk', V(1.7, 0.3, -3.7 + (k - 1) * 1.45), V(3.1, 0.33, -2.45 + (k - 1) * 1.45), col, M.SmoothPlastic)
	end
	crateAt(c, -2.6, 0.3, -2.6, C(47, 123, 255))
	local card = c:box('FreeSign', V(1.4, 0.3, 2.6), V(3.6, 2.2, 2.75), C(201, 163, 107), M.Cardboard)
	kit.line(kit.surface(card, Enum.NormalId.Front, 40), 'Text', 'FREE', C(230, 59, 46), kit.FONT.tag, 0.1, 0.8)
	-- A bent street lamp, still lit, does the hanging.
	c:post('LampBase', 0.75, 0.9, V(-3, 0.3, 2.8), IRON, M.Metal)
	c:post('LampPost', 0.4, 10.4, V(-3, 0.3, 2.8), IRON, M.Metal)
	c:bar('LampArm', V(-3, 10.6, 2.8), V(-1.0, 11.6, 1.6), 0.38, IRON)
	c:bar('LampArmBend', V(-1.0, 11.6, 1.6), V(1.4, 11.0, 1.2), 0.38, IRON)
	c:box('LampHood', V(0.5, 10.6, 0.4), V(2.4, 11.1, 2.0), IRON, M.Metal)
	local bulb = c:box('LampBulb', V(0.7, 10.4, 0.6), V(2.2, 10.6, 1.8), C(255, 226, 150), M.Neon)
	kit.light(bulb, C(255, 214, 140), 0.8, 10)
	local hook = V(0, 11.2, 1.2)
	-- Three fat tyres with cream whitewalls on a frayed rope; the middle one wears a chalk smiley.
	local top
	for k = 0, 2 do
		local y = 2.4 + k * 1.35
		local x = 0.12 * (k - 1)
		c:blob('Tire', V(3.6, 1.15, 3.6), V(x, y, 1.2), C(46, 46, 54), M.SmoothPlastic)
		c:post('TireHole', 0.75, 1.18, V(x, y - 0.59, 1.2), C(18, 18, 22), M.SmoothPlastic)
		c:post('Whitewall', 1.25, 1.1, V(x, y - 0.55, 1.2), C(255, 244, 222), M.SmoothPlastic)
		top = y + 0.57
	end
	-- Each smiley piece sits on the tyre's curved front: z from the flattened-sphere surface at that spot.
	local fy = 2.4 + 1.35
	local function onTire(x, dy)
		local k = 1 - (x / 1.8 - 0.12 / 1.8) ^ 2 - (dy / 0.575) ^ 2
		return 1.2 - 1.8 * math.sqrt(math.max(0, k))
	end
	local function dab(name, x, dy, w, h, color)
		local z = onTire(x, dy)
		c:box(name, V(x - w / 2, fy + dy - h / 2, z - 0.08), V(x + w / 2, fy + dy + h / 2, z + 0.04), color, M.SmoothPlastic)
	end
	for _, x in { -0.45, 0.45 } do dab('SmileEye', x, 0.16, 0.22, 0.22, C(255, 244, 222)) end
	for k = -1, 1 do dab('SmileMouth', k * 0.3, -0.2 + math.abs(k) * 0.08, 0.26, 0.11, C(255, 244, 222)) end
	for _, x in { -0.85, 0.85 } do dab('SmileCheek', x, -0.04, 0.26, 0.14, C(255, 143, 184)) end
	c:bar('Rope', V(0, top, 1.2), hook, 0.24, C(196, 154, 100), M.Fabric)
	c:blob('Knot', V(0.7, 0.7, 0.7), V(0, top + 0.25, 1.2), C(186, 144, 92), M.Fabric)
	for _, a in { -0.5, 0.4 } do c:bar('Fray', V(0, top + 0.1, 1.2), V(math.sin(a) * 0.6, top - 0.5, 1.2 + math.cos(a) * 0.3), 0.08, C(196, 154, 100), M.Fabric) end
	nameplate(c, kit, s, T, 0.35, 5)
	priceTag(c, kit, s, T, 13)
	return { pad = V(8, 0.3, 8) }
end

function Build.Tape(c, kit, s) -- "Patched Duffel": first bright accent, first sound
	local T = 2
	-- Pallet base with a boombox on a crate.
	for _, x in { -3.2, 0, 3.2 } do c:box('PalletRunner', V(x - 0.5, 0, -4), V(x + 0.5, 0.35, 4), C(160, 118, 74), M.WoodPlanks) end
	for k = 0, 4 do c:box('PalletBoard', V(-4, 0.35, -4 + k * 1.64), V(4, 0.6, -4 + k * 1.64 + 1.3), C(196, 154, 100), M.WoodPlanks) end
	crateAt(c, 2.8, 0.6, -2.4, C(255, 63, 127))
	c:at(CFrame.new(0, 0.6, 0)):box('BoomboxBody', V(1.6, 1.4, -2.9), V(4.0, 2.6, -1.9), IRON, M.SmoothPlastic)
	for _, x in { 2.2, 3.4 } do
		c:part('BoomboxCone', V(0.08, 0.9, 0.9), CFrame.new(x, 2.6, -2.95) * CFrame.Angles(0, math.pi / 2, 0), C(26, 26, 30), M.SmoothPlastic, Enum.PartType.Cylinder)
		c:part('BoomboxRing', V(0.06, 1.05, 1.05), CFrame.new(x, 2.6, -2.92) * CFrame.Angles(0, math.pi / 2, 0), C(76, 217, 100), M.Neon, Enum.PartType.Cylinder)
	end
	-- Sidewalk-shed scaffold in street-sign green, with orange clamps.
	local green = C(31, 138, 76)
	c:post('Pipe', 0.34, 10.4, V(-3, 0.6, 2.8), green, M.Metal)
	c:post('PipeB', 0.34, 10.4, V(3, 0.6, 2.8), green, M.Metal)
	c:rod('PipeTop', 0.34, 6.4, CFrame.new(0, 10.9, 2.8), green, M.Metal)
	c:part('PipeArm', V(1.9, 0.68, 0.68), CFrame.new(0, 10.9, 1.9) * CFrame.Angles(0, math.pi / 2, 0), green, M.Metal, Enum.PartType.Cylinder)
	for _, x in { -3, 3 } do c:bar('PipeBrace', V(x, 7.6, 2.8), V(x * 0.4, 10.9, 2.8), 0.4, green, M.Metal) end
	for _, p in { V(-3, 10.9, 2.8), V(3, 10.9, 2.8), V(0, 10.9, 2.8) } do c:part('Clamp', V(0.9, 0.9, 0.9), CFrame.new(p), C(255, 140, 40), M.Metal, Enum.PartType.Ball) end
	-- The duffel: olive, lumpy, leaning 5 degrees, wrapped in silver tape with green zip ties.
	local pivot = V(0, 9.6, 1.2)
	local lean = CFrame.new(pivot) * CFrame.Angles(0, 0, math.rad(5)) * CFrame.new(-pivot)
	local d = c:at(lean)
	local olive, tape, tie = C(122, 139, 58), C(201, 206, 214), C(76, 217, 100)
	local swivel = bag(d, { bottom = 2.3, radius = 1.3, height = 4.8, body = olive, cap = C(96, 110, 44), seam = C(96, 110, 44), metal = C(160, 160, 150), material = M.Fabric })
	d:blob('Lump', V(2.2, 1.8, 2.2), V(0.55, 3.6, 1.0), olive, M.Fabric)
	d:blob('Lump', V(2.0, 1.6, 2.0), V(-0.5, 5.4, 1.4), olive, M.Fabric)
	for k, ang in { -0.16, 0.1, -0.05, 0.14 } do
		d:part('TapeBand', V(0.42, 2.98, 2.98), CFrame.new(0, 2.9 + (k - 1) * 1.15, 1.2) * CFrame.Angles(ang, 0, math.pi / 2), tape, M.Foil, Enum.PartType.Cylinder)
	end
	for _, a in { 0.35, -0.35 } do d:part('TapeX', V(1.3, 0.28, 0.06), CFrame.new(-0.4, 5.0, 1.2 - 1.42) * CFrame.Angles(0, 0, a), tape, M.Foil) end
	d:part('TapeTail', V(0.42, 1.2, 0.06), CFrame.new(0.8, 2.6, 1.2 - 1.42) * CFrame.Angles(0, 0, 0.35), tape, M.Foil)
	for _, y in { 3.3, 5.6 } do d:part('ZipTie', V(0.2, 2.86, 2.86), CFrame.new(0, y, 1.2) * CFrame.Angles(0, 0, math.pi / 2), tie, M.Neon, Enum.PartType.Cylinder) end
	chain(c, lean * swivel, V(0, 10.6, 1.2), 0.5, C(150, 140, 120))
	nameplate(c, kit, s, T, 0.65, 5.2)
	priceTag(c, kit, s, T, 13)
	return { pad = V(8, 0.6, 8) }
end

function Build.Street(c, kit, s) -- "Tagged Canvas": paint, graphics and the first glow
	local T = 3
	local blue = Props.Rarity[T]
	-- Curb base with a blue painted edge and a faint neon ground ring.
	c:box('Curb', V(-4, 0, -4), V(4, 0.7, 4), C(206, 204, 198), M.Concrete)
	c:box('CurbStripe', V(-4.05, 0.45, -4.05), V(4.05, 0.68, 4.05), blue, M.SmoothPlastic)
	c:box('CurbTop', V(-3.95, 0.7, -3.95), V(3.95, 0.72, 3.95), C(214, 212, 206), M.Concrete)
	local ring = c:post('GroundRing', 2.6, 0.04, V(0, 0.72, 1.2), blue, M.Neon)
	ring.Transparency = 0.5
	-- Chain-link backdrop with blue privacy slats and a tag.
	local chain_ = C(184, 192, 204)
	for _, x in { -4, 4 } do c:post('FencePost', 0.2, 8.6, V(x, 0.72, 3.7), chain_, M.Metal) end
	c:box('FenceRail', V(-4, 9.2, 3.6), V(4, 9.4, 3.8), chain_, M.Metal)
	local mesh = c:box('FenceMesh', V(-3.9, 0.9, 3.67), V(3.9, 9.2, 3.73), chain_, M.DiamondPlate)
	mesh.Transparency = 0.55
	for k = 0, 6 do c:box('FenceSlat', V(-3.6 + k * 1.2, 1.0, 3.62), V(-3.2 + k * 1.2, 9.0, 3.66), blue, M.SmoothPlastic) end
	local tagPanel = c:box('FenceTag', V(-3.4, 5.6, 3.55), V(3.4, 8.4, 3.58), C(255, 255, 255), M.SmoothPlastic)
	tagPanel.Transparency = 1
	kit.line(kit.surface(tagPanel, Enum.NormalId.Front, 30), 'Tag', 'STAY UP', C(255, 93, 162), kit.FONT.tag, 0.05, 0.9, C(26, 26, 30), 4)
	-- Green street-sign pole with crossed blades and a lamp arm over the bag.
	local green = C(31, 138, 76)
	c:post('SignPole', 0.36, 10.6, V(-3, 0.72, 2.8), green, M.Metal)
	c:post('PoleBase', 0.6, 0.6, V(-3, 0.72, 2.8), green, M.Metal)
	local signA = c:box('SignA', V(-4.6, 8.0, 2.4), V(-1.4, 8.9, 2.55), green, M.SmoothPlastic)
	c:box('SignB', V(-3.08, 8.95, 1.0), V(-2.92, 9.85, 4.2), green, M.SmoothPlastic)
	kit.line(kit.surface(signA, Enum.NormalId.Front, 40), 'Street', 'BLOCK ST', C(255, 255, 255), kit.FONT.body, 0.1, 0.8)
	c:box('LampArm', V(-3, 10.8, 0.85), V(0.5, 11.32, 1.55), green, M.Metal)
	c:bar('ArmBrace', V(-3, 9.2, 2.6), V(-1.4, 10.82, 1.2), 0.3, green, M.Metal)
	-- Clean blue canvas cylinder, 2.8 across, with a bubble-letter tag patch and paint splats.
	local swivel = bag(c, { bottom = 2.2, radius = 1.4, height = 5.2, body = C(64, 156, 255), cap = C(26, 26, 30), seam = C(255, 255, 255), metal = C(184, 192, 204), material = M.Fabric, bands = { 0.5 } })
	local patch = c:box('TagPatch', V(-1.1, 4.1, 1.2 - 1.55), V(1.1, 5.5, 1.2 - 1.45), C(255, 210, 63), M.SmoothPlastic)
	kit.line(kit.surface(patch, Enum.NormalId.Front, 60), 'Tag', 'BLOCK', C(255, 93, 162), kit.FONT.loud, 0.08, 0.84, C(26, 26, 30), 3)
	for k, col in { C(255, 93, 162), C(255, 210, 63), C(46, 196, 182), C(142, 92, 247) } do
		local a = k * 1.4 + 0.3
		c:blob('PaintSplat', V(0.7, 0.55, 0.7), V(math.cos(a) * 1.5, 2.9 + k * 0.85, 1.2 + math.sin(a) * 1.5), col, M.SmoothPlastic)
	end
	chain(c, swivel, V(0, 10.8, 1.2), 0.5, C(184, 192, 204))
	nameplate(c, kit, s, T, 0.95, 5.4)
	priceTag(c, kit, s, T, 14)
	return { pad = V(8, 0.72, 8) }
end

function Build.Heavy(c, kit, s) -- "The Classic": pedestal + the first real light, a big size jump
	local T = 4
	local purple = Props.Rarity[T]
	c:box('Plinth', V(-4, 0, -4), V(4, 0.9, 4), C(150, 156, 166), M.DiamondPlate)
	c:box('PlinthEdge', V(-4.06, 0.62, -4.06), V(4.06, 0.78, 4.06), purple, M.Neon)
	-- Gym poster board behind: BLOCK BOXING CLUB with a pair of painted red gloves.
	for _, x in { -3.4, 3.4 } do c:box('PosterLeg', V(x - 0.2, 0.9, 3.7), V(x + 0.2, 9.4, 3.9), IRON, M.Metal) end
	local poster = c:box('Poster', V(-3.6, 5.0, 3.55), V(3.6, 9.2, 3.7), C(255, 244, 222), M.SmoothPlastic)
	local pg = kit.surface(poster, Enum.NormalId.Front, 30)
	kit.line(pg, 'Club', 'BLOCK BOXING CLUB', C(214, 40, 52), kit.FONT.loud, 0.06, 0.34, C(26, 26, 30), 2)
	kit.line(pg, 'Since', 'TRAIN • FIGHT • RISE', C(26, 26, 30), kit.FONT.title, 0.78, 0.16)
	for _, x in { -1.1, 1.1 } do c:blob('PosterGlove', V(1.6, 1.8, 0.4), V(x, 6.8, 3.5), C(214, 40, 52), M.SmoothPlastic) end
	-- Black steel gallows with welded gussets and bolts.
	local hook = gallows(c, { y0 = 0.9, top = 11.8, width = 1.0, color = C(36, 38, 46), material = M.Metal, cap = C(120, 126, 136) })
	for _, y in { 1.2, 10.6 } do c:wedge('Gusset', V(0.3, 1.1, 1.1), CFrame.new(-2.35, y + 0.55, 2.8) * CFrame.Angles(0, -math.pi / 2, 0), C(36, 38, 46), M.Metal) end
	for _, y in { 3, 6, 9 } do c:part('Bolt', V(0.16, 0.34, 0.34), CFrame.new(-3, y, 2.28) * CFrame.Angles(0, math.pi / 2, 0), C(201, 209, 220), M.Metal, Enum.PartType.Cylinder) end
	-- Fat glossy red heavy bag, 3.2 across and 6 tall, white caps, black strap, chunky chrome hardware.
	local swivel = bag(c, { bottom = 2.0, radius = 1.6, height = 6.0, body = C(214, 40, 52), cap = C(245, 245, 245), seam = C(150, 24, 34), strap = C(30, 30, 36), metal = C(201, 209, 220) })
	chain(c, swivel, hook, 0.6, C(201, 209, 220))
	local glow = c:box('UplightLens', V(-0.6, 0.9, 2.9), V(0.6, 1.1, 3.4), purple, M.Neon)
	kit.light(glow, purple, 1.6, 13)
	nameplate(c, kit, s, T, 1.05, 5.6)
	priceTag(c, kit, s, T, 15)
	return { pad = V(8, 0.9, 8) }
end

function Build.Speed(c, kit, s) -- "Speed Rig": chrome and the first particles
	local T = 5
	local pink = Props.Rarity[T]
	c:box('Plinth', V(-4, 0, -4), V(4, 0.7, 4), C(236, 232, 240), M.SmoothPlastic)
	c:box('Step', V(-3.2, 0.7, -3.2), V(3.2, 1.2, 3.6), C(222, 216, 228), M.SmoothPlastic)
	c:box('PlinthTrim', V(-4.06, 0.5, -4.06), V(4.06, 0.68, 4.06), pink, M.Neon)
	-- Padded backboard: a frame with six tufted pink pads.
	local chrome = C(201, 209, 220)
	c:box('Backboard', V(-3.6, 1.2, 3.0), V(3.6, 10.6, 3.6), C(60, 40, 70), M.SmoothPlastic)
	for col = 0, 2 do
		for row = 0, 1 do
			c:blob('Pad', V(2.1, 3.9, 0.7), V(-2.3 + col * 2.3, 3.5 + row * 4.4, 2.95), C(255, 179, 224), M.Fabric)
		end
	end
	-- Round rebound platform on chrome brackets, the oversized teardrop under it.
	c:part('Platform', V(0.6, 5.4, 5.4), CFrame.new(0, 9.0, -0.1) * CFrame.Angles(0, 0, math.pi / 2), C(196, 122, 58), M.WoodPlanks, Enum.PartType.Cylinder)
	c:part('PlatformRim', V(0.3, 5.7, 5.7), CFrame.new(0, 8.65, -0.1) * CFrame.Angles(0, 0, math.pi / 2), chrome, M.Metal, Enum.PartType.Cylinder)
	for _, x in { -1.6, 1.6 } do c:bar('Bracket', V(x, 8.6, 3.0), V(x * 0.6, 8.6, 0.4), 0.36, chrome, M.Metal) end
	c:post('SwivelMount', 0.38, 0.5, V(0, 8.0, -0.1), chrome, M.Metal)
	c:blob('SpeedBag', V(2.2, 3.0, 2.2), V(0, 6.1, -0.1), pink, M.SmoothPlastic)
	c:blob('SpeedBagTop', V(1.5, 1.4, 1.5), V(0, 7.4, -0.1), C(255, 227, 244), M.SmoothPlastic)
	c:post('SpeedBagSeam', 1.12, 0.16, V(0, 6.0, -0.1), C(200, 50, 150), M.SmoothPlastic)
	-- Round timer clock on the backboard: red and green lights around "3:00".
	c:part('ClockBody', V(0.4, 2.4, 2.4), CFrame.new(2.4, 11.6, 3.2) * CFrame.Angles(0, math.pi / 2, 0), C(26, 26, 30), M.SmoothPlastic, Enum.PartType.Cylinder)
	local face = c:box('ClockFace', V(1.6, 10.8, 2.95), V(3.2, 12.4, 3.0), C(26, 26, 30), M.SmoothPlastic)
	kit.line(kit.surface(face, Enum.NormalId.Front, 60), 'Time', '3:00', C(255, 80, 80), kit.FONT.loud, 0.2, 0.6)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		c:part('ClockLight', V(0.25, 0.25, 0.25), CFrame.new(2.4 + math.cos(a) * 1.05, 11.6 + math.sin(a) * 1.05, 2.95), k % 2 == 0 and C(255, 70, 70) or C(80, 255, 120), M.Neon, Enum.PartType.Ball)
	end
	c:bar('ClockMount', V(2.4, 10.4, 3.3), V(2.4, 10.6, 3.3), 0.3, chrome, M.Metal)
	emitter(c, 'Sparkles', V(0, 6.1, -0.1), 'sparkle', {
		Rate = 6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.4, 1), SpreadAngle = Vector2.new(180, 180),
		Size = seq({ { 0, 0 }, { 0.3, 0.55 }, { 1, 0 } }), Transparency = seq({ { 0, 0.1 }, { 1, 0.6 } }),
		Color = cseq(C(255, 220, 245), pink), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}, V(3.4, 3.8, 3.4))
	nameplate(c, kit, s, T, 0.85, 5.6)
	priceTag(c, kit, s, T, 14.5)
	return { pad = V(8, 1.2, 8) }
end

function Build.DoubleEnd(c, kit, s) -- "Live Wire": an arch, electricity, the first moving part
	local T = 6
	local cyan = Props.Rarity[T]
	polygonPlinth(c, 'Stage', V(0, 0, 0.2), 4.5, 0, 0.7, C(40, 48, 74), M.SmoothPlastic)
	polygonPlinth(c, 'StageTop', V(0, 0, 0.2), 3.6, 0.7, 1.3, C(56, 66, 100), M.SmoothPlastic)
	polygonPlinth(c, 'StageTrim', V(0, 0, 0.2), 3.66, 1.12, 1.22, cyan, M.Neon)
	-- Arch frame 7 wide and 13 tall with a HIGH VOLTAGE plate.
	local frame = C(40, 48, 74)
	for _, x in { -3.5, 3.5 } do
		c:box('Upright', V(x - 0.45, 1.3, 0.75), V(x + 0.45, 13.4, 1.65), frame, M.Metal)
		c:box('UprightNeon', V(x - 0.5, 2, 0.7), V(x + 0.5, 2.3, 1.7), cyan, M.Neon)
	end
	c:box('Header', V(-4.1, 13.4, 0.6), V(4.1, 14.4, 1.8), frame, M.Metal)
	local plate = c:box('VoltPlate', V(-2.6, 13.5, 0.45), V(2.6, 14.3, 0.6), C(255, 210, 63), M.SmoothPlastic)
	kit.line(kit.surface(plate, Enum.NormalId.Front, 50), 'Text', '⚡ HIGH VOLTAGE ⚡', C(26, 26, 30), kit.FONT.loud, 0.1, 0.8)
	c:post('FloorAnchor', 0.55, 0.3, V(0, 1.3, 1.2), C(201, 209, 220), M.Metal)
	-- The ball: navy, 2.6 across, a cyan neon belt, riding between electric bungees.
	local ballY = 6.8
	c:blob('Ball', V(2.6, 2.8, 2.6), V(0, ballY, 1.2), C(36, 48, 90), M.SmoothPlastic)
	c:post('BallStripe', 1.34, 0.32, V(0, ballY - 0.16, 1.2), cyan, M.Neon)
	local cordTop, cordBottom = V(0, 13.4, 1.2), V(0, 1.6, 1.2)
	c:bar('BungeeTop', V(0, ballY + 1.4, 1.2), cordTop, 0.16, cyan, M.Neon)
	c:bar('BungeeBottom', V(0, ballY - 1.4, 1.2), cordBottom, 0.16, cyan, M.Neon)
	local function beam(a, b, width)
		local pa = c:part('BeamEnd', V(0.2, 0.2, 0.2), CFrame.new(a), C(255, 255, 255))
		local pb = c:part('BeamEnd', V(0.2, 0.2, 0.2), CFrame.new(b), C(255, 255, 255))
		for _, p in { pa, pb } do p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false end
		local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
		a0.Parent, a1.Parent = pa, pb
		local bm = Instance.new('Beam')
		bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Texture = textureFor('lightning')
		bm:SetAttribute('PreviewTexture', 'lightning')
		bm.TextureMode = Enum.TextureMode.Wrap
		bm.TextureLength = 3
		bm.TextureSpeed = 2
		bm.Width0, bm.Width1 = width, width
		bm.FaceCamera = true
		bm.LightEmission = 0.6
		bm.Color = cseq(cyan)
		bm.Transparency = seq({ { 0, 0.35 }, { 1, 0.35 } })
		bm.Parent = pa
	end
	beam(V(0, ballY + 1.4, 1.2), cordTop, 0.9)
	beam(V(0, ballY - 1.4, 1.2), cordBottom, 0.9)
	beam(V(-3.5, 13.0, 0.5), V(3.5, 13.0, 0.5), 0.6) -- an arc of lightning across the header
	local orbit, orbitModel = c:group('OrbitRing')
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		orbit:part('OrbitChip', V(0.55, 0.2, 0.3), CFrame.new(math.cos(a) * 2.3, ballY, 1.2 + math.sin(a) * 2.3) * CFrame.Angles(0, -a, 0), cyan, M.Neon)
	end
	motion(orbitModel, { Spin = 90 })
	emitter(c, 'Sparks', V(0, ballY, 1.2), 'streak', {
		Rate = 5, Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(180, 180), Drag = 6,
		Size = seq({ { 0, 0.5 }, { 1, 0 } }), Color = cseq(C(220, 255, 255), cyan), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}, V(2.8, 2.8, 2.8))
	nameplate(c, kit, s, T, 0.12, 5.8, 4.55)
	priceTag(c, kit, s, T, 16.5)
	return { pad = V(9, 1.3, 9) }
end

-- Tall tapered "banana" bag body (Pro): stacked cylinders, wider in the middle, with bands and piping.
local function banana(c, o)
	local radii = { 1.05, 1.18, 1.3, 1.32, 1.26, 1.14 }
	local h = o.height / #radii
	for k, r in radii do c:post('BananaBody', r, h, V(0, o.bottom + (k - 1) * h, 1.2), o.body, M.SmoothPlastic) end
	c:blob('BananaBottom', V(2.1, 0.9, 2.1), V(0, o.bottom, 1.2), o.body, M.SmoothPlastic)
	c:blob('BananaTop', V(2.4, 0.9, 2.4), V(0, o.bottom + o.height, 1.2), o.cap, M.SmoothPlastic)
	for k = 1, #radii - 1 do
		local r = math.max(radii[k], radii[k + 1])
		c:post('BananaBand', r + 0.06, 0.22, V(0, o.bottom + k * h - 0.11, 1.2), k % 2 == 1 and o.band or o.piping, M.SmoothPlastic)
	end
	local swivel = V(0, o.bottom + o.height + 1.4, 1.2)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local ring = V(math.cos(a) * 0.75, o.bottom + o.height + 0.3, 1.2 + math.sin(a) * 0.75)
		c:part('DRing', V(0.16, 0.6, 0.6), CFrame.lookAt(ring, ring + V(math.cos(a), 0, math.sin(a))) * CFrame.Angles(0, math.pi / 2, 0), o.metal, M.Metal, Enum.PartType.Cylinder)
		c:bar('Spider', ring, swivel, 0.11, o.metal)
	end
	c:part('Swivel', V(0.8, 0.8, 0.8), CFrame.new(swivel), o.metal, M.Metal, Enum.PartType.Ball)
	return swivel
end

function Build.Pro(c, kit, s) -- "Pro Banana": stage, spotlight, embers, taller than you
	local T = 7
	local red = Props.Rarity[T]
	local black = C(30, 30, 36)
	local gold = C(255, 200, 60)
	c:box('Stage1', V(-5, 0, -5), V(5, 0.6, 5), black, M.SmoothPlastic)
	c:box('Stage2', V(-4.4, 0.6, -4.2), V(4.4, 1.1, 4.6), C(40, 40, 48), M.SmoothPlastic)
	c:box('Stage3', V(-3.8, 1.1, -3.4), V(3.8, 1.5, 4.4), C(52, 52, 62), M.SmoothPlastic)
	c:box('StageEdge', V(-5.06, 0.42, -5.06), V(5.06, 0.58, 5.06), red, M.Neon)
	for _, x in { -4.6, 4.6 } do
		c:box('CornerPost', V(x - 0.3, 0.6, -4.9), V(x + 0.3, 2.8, -4.3), black, M.Metal)
		c:box('CornerCap', V(x - 0.36, 2.8, -4.96), V(x + 0.36, 3.1, -4.24), red, M.Neon)
	end
	-- Vertical fight-night banner behind the bag.
	local banner = c:box('FightBanner', V(1.4, 2.4, 4.3), V(4.2, 13.4, 4.5), red, M.Fabric)
	local bg = kit.surface(banner, Enum.NormalId.Front, 30)
	kit.line(bg, 'Top', 'FIGHT', C(255, 255, 255), kit.FONT.loud, 0.04, 0.12, black, 2)
	kit.line(bg, 'Mid', 'NIGHT', gold, kit.FONT.loud, 0.17, 0.12, black, 2)
	kit.line(bg, 'Sub', 'THE BLOCK', C(255, 255, 255), kit.FONT.title, 0.84, 0.08, black, 2)
	c:box('BannerRod', V(1.2, 13.4, 4.25), V(4.4, 13.7, 4.55), gold, M.Metal)
	-- Heavy industrial gallows with red neon strips and gold bolts, taller than before.
	local hook = gallows(c, { y0 = 1.5, top = 14.2, width = 1.2, color = black, material = M.Metal, cap = red, capMaterial = M.Neon })
	c:box('PostStrip', V(-3.66, 2.0, 2.14), V(-3.54, 13.6, 2.26), red, M.Neon)
	for _, y in { 3.5, 7, 10.5 } do c:part('Bolt', V(0.16, 0.36, 0.36), CFrame.new(-3, y, 2.16) * CFrame.Angles(0, math.pi / 2, 0), gold, M.Metal, Enum.PartType.Cylinder) end
	-- The banana: 8 tall, black with red bands and gold piping, a gold PRO plate.
	local swivel = banana(c, { bottom = 2.4, height = 8.0, body = black, cap = red, band = red, piping = gold, metal = gold })
	local logo = c:box('LogoPlate', V(-0.8, 6.6, 1.2 - 1.32 - 0.22), V(0.8, 7.8, 1.2 - 1.32 - 0.08), gold, M.Metal)
	kit.line(kit.surface(logo, Enum.NormalId.Front, 60), 'Logo', 'PRO', black, kit.FONT.loud, 0.08, 0.84)
	chain(c, swivel, hook, 0.6, gold)
	emitter(c, 'Embers', V(0, 1.7, 1.2), 'glow', {
		Rate = 10, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(20, 20),
		Size = seq({ { 0, 0.45 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Color = cseq(C(255, 220, 120), C(255, 60, 30)), LightEmission = 1, Acceleration = V(0, 1.5, 0),
		Shape = Enum.ParticleEmitterShape.Disc,
	}, V(5.6, 0.2, 5.6))
	c:box('Spotlamp', V(-0.5, 13.0, 0.7), V(0.5, 13.4, 1.7), black, M.Metal)
	local lens = c:box('SpotLens', V(-0.4, 12.9, 0.8), V(0.4, 13.0, 1.6), C(255, 240, 220), M.Neon)
	local spot = Instance.new('SpotLight')
	spot.Face, spot.Angle, spot.Range, spot.Brightness, spot.Color = Enum.NormalId.Bottom, 50, 18, 2, C(255, 236, 220)
	spot.Parent = lens
	local emblem, emblemModel = c:group('FloorEmblem')
	for k = 0, 3 do emblem:part('EmblemArm', V(5.2, 0.06, 0.55), CFrame.new(0, 1.53, 1.2) * CFrame.Angles(0, k * math.pi / 4, 0), red, M.Neon) end
	motion(emblemModel, { Spin = 25 })
	nameplate(c, kit, s, T, 0.2, 6.4, 5.05)
	priceTag(c, kit, s, T, 17.5)
	return { pad = V(10, 1.5, 10) }
end

function Build.Gold(c, kit, s) -- "Golden Wrecking Ball": gold, gems, halo, a red carpet and an arch
	local T = 8
	local gold = Props.Rarity[T]
	local marble = C(244, 242, 236)
	-- 12-sided marble dais with gold rings, and a red carpet runner up to it.
	polygonPlinth(c, 'Dais', V(0, 0, 0.4), 5.6, 0, 0.6, marble, M.Marble, 12)
	polygonPlinth(c, 'DaisGold', V(0, 0, 0.4), 5.66, 0.45, 0.56, gold, M.Neon, 12)
	polygonPlinth(c, 'DaisTop', V(0, 0, 0.4), 4.6, 0.6, 1.2, marble, M.Marble, 12)
	polygonPlinth(c, 'DaisTopGold', V(0, 0, 0.4), 4.66, 1.05, 1.16, gold, M.Neon, 12)
	c:box('Carpet', V(-1.6, 0, -8.6), V(1.6, 0.08, -5.0), C(200, 16, 46), M.Fabric)
	for _, x in { -1.75, 1.6 } do c:box('CarpetTrim', V(x, 0, -8.6), V(x + 0.15, 0.1, -5.0), gold, M.SmoothPlastic) end
	-- White marble arch with gold caps: two columns and a header the chain hangs from.
	for _, x in { -3.6, 3.6 } do
		c:post('Column', 0.75, 13.2, V(x, 1.2, 2.6), marble, M.Marble)
		c:post('ColumnBase', 1.0, 0.6, V(x, 1.2, 2.6), gold, M.SmoothPlastic)
		c:post('ColumnCap', 1.0, 0.6, V(x, 13.8, 2.6), gold, M.SmoothPlastic)
	end
	c:box('ArchHeader', V(-4.4, 14.4, 1.6), V(4.4, 15.6, 3.6), marble, M.Marble)
	c:box('ArchGold', V(-4.5, 15.6, 1.5), V(4.5, 15.9, 3.7), gold, M.SmoothPlastic)
	c:box('ArchArm', V(-0.5, 14.4, 0.6), V(0.5, 15.2, 1.6), gold, M.SmoothPlastic)
	local hook = V(0, 14.4, 1.2)
	-- The wrecking ball: a gold teardrop with a highlight band, a ring of diamonds and a crown topper.
	local cy = 5.2
	c:blob('GoldBall', V(4.6, 4.6, 4.6), V(0, cy, 1.2), C(255, 196, 40), M.SmoothPlastic)
	c:blob('GoldTear', V(2.8, 3.2, 2.8), V(0, cy + 2.3, 1.2), C(255, 196, 40), M.SmoothPlastic)
	c:post('GoldShine', 2.32, 0.5, V(0, cy + 0.5, 1.2), C(255, 232, 130), M.SmoothPlastic)
	c:post('GoldSeam', 2.33, 0.18, V(0, cy - 0.3, 1.2), C(214, 140, 16), M.SmoothPlastic)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		c:part('Diamond', V(0.36, 0.36, 0.36), CFrame.new(math.cos(a) * 2.34, cy - 0.3, 1.2 + math.sin(a) * 2.34) * CFrame.Angles(math.pi / 4, a, math.pi / 4), C(170, 245, 255), M.Neon)
	end
	local crownY = cy + 4.0
	c:post('CrownBand', 0.9, 0.5, V(0, crownY, 1.2), gold, M.SmoothPlastic)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		c:wedge('CrownPoint', V(0.3, 0.8, 0.5), CFrame.new(math.cos(a) * 0.75, crownY + 0.9, 1.2 + math.sin(a) * 0.75) * CFrame.Angles(0, -a + math.pi / 2, 0), gold, M.SmoothPlastic)
		c:part('CrownGem', V(0.22, 0.22, 0.22), CFrame.new(math.cos(a) * 0.92, crownY + 0.25, 1.2 + math.sin(a) * 0.92), C(255, 60, 90), M.Neon, Enum.PartType.Ball)
	end
	local swivel = V(0, crownY + 1.6, 1.2)
	c:part('Swivel', V(0.8, 0.8, 0.8), CFrame.new(swivel), gold, M.Metal, Enum.PartType.Ball)
	chain(c, swivel, hook, 0.6, gold, M.SmoothPlastic)
	-- Glow, sparkles, a god-ray, a turning halo and floating gems.
	local core = c:part('GlowCore', V(0.2, 0.2, 0.2), CFrame.new(0, cy, 1.2), gold)
	core.Transparency, core.CanCollide, core.CanQuery, core.CanTouch = 1, false, false, false
	kit.light(core, C(255, 214, 120), 1.8, 18)
	emitter(c, 'GoldSparkles', V(0, cy + 1, 1.2), 'sparkle', {
		Rate = 14, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(180, 180),
		Size = seq({ { 0, 0 }, { 0.25, 0.7 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 1, 0.4 } }),
		Color = cseq(C(255, 255, 220), gold), LightEmission = 0.7, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, RotSpeed = NumberRange.new(-90, 90),
	}, V(6, 7, 6))
	local base = c:part('RayBase', V(0.2, 0.2, 0.2), CFrame.new(0, 1.3, 1.2), gold)
	local tip = c:part('RayTip', V(0.2, 0.2, 0.2), CFrame.new(0, 18, 1.2), gold)
	for _, p in { base, tip } do p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false end
	local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
	a0.Parent, a1.Parent = base, tip
	local ray = Instance.new('Beam')
	ray.Attachment0, ray.Attachment1 = a0, a1
	ray.Texture = textureFor('energy')
	ray:SetAttribute('PreviewTexture', 'energy')
	ray.Width0, ray.Width1 = 6.5, 3
	ray.FaceCamera = true
	ray.LightEmission = 0.5
	ray.Color = cseq(C(255, 230, 150))
	ray.Transparency = seq({ { 0, 0.55 }, { 1, 1 } })
	ray.Parent = base
	local halo, haloModel = c:group('Halo')
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		halo:part('HaloSegment', V(0.9, 0.22, 0.28), CFrame.new(math.cos(a) * 1.8, 17.2, 1.2 + math.sin(a) * 1.8) * CFrame.Angles(0, -a + math.pi / 2, 0), gold, M.Neon)
	end
	motion(haloModel, { Spin = 40, Bob = 0.25, BobPeriod = 2.4 })
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.5
		local gem, gemModel = c:group('FloatingGem')
		gem:part('Gem', V(0.6, 0.6, 0.6), CFrame.new(math.cos(a) * 3.4, 4.8 + k * 0.8, 1.2 + math.sin(a) * 3.4) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C(255, 240, 150), M.Neon)
		motion(gemModel, { Bob = 0.4, BobPeriod = 1.8 + k * 0.3, Spin = 60 })
	end
	nameplate(c, kit, s, T, 0.2, 6.6, 5.65)
	priceTag(c, kit, s, T, 19.5)
	return { pad = V(11, 1.2, 11) }
end

-- The Champ Ring: tier 9. `size` is the half-width of the canvas.
function Props.ring(c, kit, s, size)
	local T = 9
	local h = 3
	local half = size
	local navy = C(26, 32, 64)
	c:box('Apron', V(-half - 2, 0, -half - 2), V(half + 2, h - 0.3, half + 2), navy, M.SmoothPlastic)
	c:box('ApronTrim', V(-half - 2.05, h - 0.75, -half - 2.05), V(half + 2.05, h - 0.45, half + 2.05), C(255, 200, 60), M.Neon)
	for _, side in { -1, 1 } do
		local skirt = c:box('Skirt', V(-half - 2.06, 0.3, side * (half + 2)), V(half + 2.06, h - 0.8, side * (half + 2.06)), C(214, 40, 52), M.Fabric)
		local g = kit.surface(skirt, side > 0 and Enum.NormalId.Back or Enum.NormalId.Front, 30)
		kit.line(g, 'Brand', 'CHAMP RING', C(255, 255, 255), kit.FONT.loud, 0.12, 0.76, C(0, 0, 0), 2)
	end
	local zone = c:box('TrainingZone', V(-half - 2, h - 0.3, -half - 2), V(half + 2, h, half + 2), C(236, 238, 244), M.Fabric)
	zone.Name = 'TrainingZone'
	c:part('CanvasLogo', V(0.06, half * 1.2, half * 1.2), CFrame.new(0, h + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), C(255, 200, 60), M.Fabric, Enum.PartType.Cylinder)
	-- Corner posts with padded turnbuckles (red, blue, white, white).
	local eq, eqModel = c:group('Equipment')
	local corners = { { -1, -1, C(226, 56, 62) }, { 1, 1, C(56, 116, 232) }, { -1, 1, C(250, 250, 252) }, { 1, -1, C(250, 250, 252) } }
	for _, k in corners do
		local x, z = k[1] * half, k[2] * half
		eq:post('CornerPost', 0.45, 6, V(x, h, z), C(200, 206, 214), M.Metal)
		eq:box('CornerPad', V(x - 0.6, h + 1.0, z - 0.6), V(x + 0.6, h + 5.35, z + 0.6), k[3], M.Fabric)
		eq:blob('PostCap', V(1.0, 0.6, 1.0), V(x, h + 6, z), C(255, 200, 60), M.Foil)
	end
	-- Hue-cycling neon ropes (the top tier's new channel), four rows.
	local ropes, ropesModel = c:group('Ropes')
	for row = 1, 4 do
		local y = h + 0.4 + row * 1.15
		for i, e in { { V(-1, 0, -1), V(1, 0, -1) }, { V(1, 0, -1), V(1, 0, 1) }, { V(1, 0, 1), V(-1, 0, 1) }, { V(-1, 0, 1), V(-1, 0, -1) } } do
			local rope = ropes:bar('Rope', e[1] * half + V(0, y, 0), e[2] * half + V(0, y, 0), 0.38, Color3.fromHSV(((row - 1) * 0.15 + i * 0.05) % 1, 0.75, 1), M.Neon)
			rope.CanCollide = true
		end
	end
	motion(ropesModel, { Hue = 6 })
	-- Steps at a neutral corner.
	for k = 1, 3 do c:box('RingStep', V(half + 2 + (3 - k) * 1.2, 0, -3), V(half + 2 + (4 - k) * 1.2, k * 1.0, 3), C(200, 206, 214), M.DiamondPlate) end
	-- Truss with spotlights.
	local T2 = half + 4
	for _, k in corners do eq:box('TrussTower', V(k[1] * T2 - 0.5, 0, k[2] * T2 - 0.5), V(k[1] * T2 + 0.5, 16, k[2] * T2 + 0.5), C(30, 32, 40), M.Metal) end
	for _, z in { -T2, T2 } do eq:box('TrussBeam', V(-T2 - 0.5, 16, z - 0.5), V(T2 + 0.5, 17, z + 0.5), C(30, 32, 40), M.Metal) end
	for _, x in { -T2, T2 } do eq:box('TrussBeam', V(x - 0.5, 16, -T2 + 0.5), V(x + 0.5, 17, T2 - 0.5), C(30, 32, 40), M.Metal) end
	for _, x in { -half * 0.5, half * 0.5 } do
		for _, z in { -T2, T2 } do
			eq:box('LampCan', V(x - 0.7, 15.1, z - 0.7), V(x + 0.7, 16, z + 0.7), C(30, 32, 40), M.Metal)
			local lens = eq:box('LampLens', V(x - 0.55, 15.0, z - 0.55), V(x + 0.55, 15.1, z + 0.55), C(255, 250, 230), M.Neon)
			local spot = Instance.new('SpotLight')
			spot.Face, spot.Angle, spot.Range, spot.Brightness = Enum.NormalId.Bottom, 60, 20, 1.6
			spot.Parent = lens
		end
	end
	-- Championship belt hologram turning over the ring.
	local belt, beltModel = c:group('BeltHologram')
	local by = h + 9
	belt:box('BeltStrap', V(-3.2, by - 0.45, -0.12), V(3.2, by + 0.45, 0.12), C(255, 200, 60), M.Neon).Transparency = 0.25
	belt:part('BeltPlate', V(0.3, 2.2, 2.2), CFrame.new(0, by, 0) * CFrame.Angles(0, math.pi / 2, math.pi / 2), C(255, 230, 120), M.Neon, Enum.PartType.Cylinder).Transparency = 0.15
	belt:part('BeltGem', V(0.7, 0.7, 0.7), CFrame.new(0, by, -0.2) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C(255, 70, 90), M.Neon)
	for _, x in { -2.2, 2.2 } do belt:part('SidePlate', V(0.25, 1.1, 1.1), CFrame.new(x, by, 0) * CFrame.Angles(0, math.pi / 2, math.pi / 2), C(255, 230, 120), M.Neon, Enum.PartType.Cylinder).Transparency = 0.2 end
	motion(beltModel, { Spin = 45, Bob = 0.4, BobPeriod = 3 })
	c.parent:SetAttribute('HitPoint', c:world(CFrame.new(0, h + 3, 0)).Position)
	c.parent:SetAttribute('HitColor', Color3.fromRGB(255, 200, 60))
	-- Confetti drifting down inside the ring.
	emitter(c, 'Confetti', V(0, h + 13, 0), 'confetti', {
		Rate = 10, Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(60, 60),
		Acceleration = V(0, -2.2, 0), Drag = 0.6, Size = seq({ { 0, 0.45 }, { 1, 0.45 } }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 70, 160)), ColorSequenceKeypoint.new(0.33, C(60, 230, 255)), ColorSequenceKeypoint.new(0.66, C(255, 220, 60)), ColorSequenceKeypoint.new(1, C(120, 255, 120)) }),
		RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Box, LightInfluence = 1,
	})
	local sign = c:box('Sign', V(-7, 17.3, -T2 - 0.4), V(7, 21.3, -T2 + 0.2), C(20, 20, 26), M.SmoothPlastic)
	local g = kit.surface(sign, Enum.NormalId.Front, 30)
	kit.line(g, 'Title', 'CHAMP RING x' .. s.Multiplier, C(255, 200, 60), kit.FONT.loud, 0.05, 0.56, C(0, 0, 0), 2)
	kit.line(g, 'Detail', kit.compact(s.Required) .. ' POWER  ★★★★★', C(255, 255, 255), kit.FONT.body, 0.64, 0.3)
	-- Lightbox frame around the sign.
	for _, e in { { V(-7.3, 21.3, -T2 - 0.5), V(7.3, 21.6, -T2 + 0.25) }, { V(-7.3, 17.0, -T2 - 0.5), V(7.3, 17.3, -T2 + 0.25) }, { V(-7.3, 17.3, -T2 - 0.5), V(-7, 21.3, -T2 + 0.25) }, { V(7, 17.3, -T2 - 0.5), V(7.3, 21.3, -T2 + 0.25) } } do
		c:box('SignNeon', e[1], e[2], C(255, 200, 60), M.Neon)
	end
	-- The arena: bleachers with a bobbing crowd on both sides, and sweeping spotlights on the truss.
	local shirts = { C(255, 93, 162), C(255, 210, 63), C(51, 195, 240), C(142, 92, 247), C(46, 196, 182), C(255, 140, 40), C(250, 250, 252) }
	local skins = { C(255, 220, 180), C(222, 170, 120), C(160, 104, 70), C(110, 70, 50) }
	for side, sx in { -1, 1 } do
		for row = 0, 2 do
			local xa, xb = sx * (T2 + 2 + row * 2), sx * (T2 + 4 + row * 2)
			c:box('Bleacher', V(math.min(xa, xb), 0, -T2 + 1), V(math.max(xa, xb), (row + 1) * 1.2, T2 - 1), C(60, 66, 90), M.SmoothPlastic)
			-- Gold nosing along the edge facing the ring.
			c:box('BleacherNose', V(xa - sx * 0.05, (row + 1) * 1.2 - 0.2, -T2 + 0.95), V(xa + sx * 0.25, (row + 1) * 1.2 + 0.05, T2 - 0.95), C(255, 200, 60), M.SmoothPlastic)
			for k = 0, 5 do
				local z = -T2 + 2.5 + k * (2 * T2 - 5) / 5
				local fx, y = (xa + xb) / 2, (row + 1) * 1.2
				local fan, fanModel = c:group('Fan')
				fan:box('FanBody', V(fx - 0.55, y, z - 0.45), V(fx + 0.55, y + 1.6, z + 0.45), shirts[(k + row * 3 + side) % #shirts + 1], M.SmoothPlastic)
				fan:part('FanHead', V(1.0, 1.0, 1.0), CFrame.new(fx, y + 2.1, z), skins[(k + row + side) % #skins + 1], M.SmoothPlastic, Enum.PartType.Ball)
				motion(fanModel, { Bob = 0.3, BobPeriod = 0.7 + ((k + row) % 3) * 0.15 })
			end
		end
	end
	for i, k in corners do
		local lamp, lampModel = c:group('SweepLight')
		local base = V(k[1] * T2, 17, k[2] * T2)
		local tilt = CFrame.new(base + V(0, 1.0, 0)) * CFrame.Angles(math.rad(-35), 0, 0)
		lamp:post('SweepBase', 0.55, 0.5, base, C(30, 32, 40), M.Metal)
		lamp:part('SweepHead', V(1.1, 1.1, 1.8), tilt, C(30, 32, 40), M.Metal)
		local lens = lamp:part('SweepLens', V(0.9, 0.9, 0.1), tilt * CFrame.new(0, 0, -0.92), C(255, 250, 230), M.Neon)
		local spot = Instance.new('SpotLight')
		spot.Face, spot.Angle, spot.Range, spot.Brightness, spot.Color = Enum.NormalId.Front, 30, 32, 2, C(255, 244, 220)
		spot.Parent = lens
		motion(lampModel, { Spin = 30 + i * 6 })
	end
	return eqModel
end

local HIT_POINT = { Starter = V(0, 3.8, 1.2), Tape = V(0, 4.8, 1.2), Street = V(0, 4.8, 1.2), Heavy = V(0, 5.0, 1.2), Speed = V(0, 6.1, -0.1), DoubleEnd = V(0, 6.8, 1.2), Pro = V(0, 6.4, 1.2), Gold = V(0, 5.2, 1.2) }

-- Build station `s` (a Skins.Stations entry) at tier index `tier` in context `c` (origin = pad centre,
-- -Z toward the aisle). Returns the station model.
function Props.station(c, kit, s, tier)
	local st, model = c:group('Training_' .. s.Id)
	local fn = Build[s.Id]
	local info = fn(st, kit, s)
	-- The mat that counts for training sits on top of the pedestal.
	local h = info.pad.X / 2 - 0.6
	local zone = st:box('TrainingZone', V(-h, info.pad.Y, -h), V(h, info.pad.Y + 0.06, h), Props.Rarity[tier], M.SmoothPlastic)
	zone.Transparency, zone.CanCollide, zone.CastShadow = 1, false, false
	model:SetAttribute('Tier', tier)
	-- Where a punch lands (clients put sparks and numbers here).
	local hit = HIT_POINT[s.Id] or V(0, 5, 1.2)
	model:SetAttribute('HitPoint', st:world(CFrame.new(hit)).Position)
	model:SetAttribute('HitColor', Props.Rarity[tier])
	return model
end

return Props
