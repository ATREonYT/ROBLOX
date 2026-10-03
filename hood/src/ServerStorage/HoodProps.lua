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
	for k = 0, n - 1 do
		local p0, p1 = a + dir * (k / n), a + dir * ((k + 1) / n)
		local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, (k % 2) * math.pi / 2)
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
local function nameplate(c, kit, s, tier, y, width)
	local color = Props.Rarity[tier]
	local plate = c:box('Nameplate', V(-width / 2, y, -4.25), V(width / 2, y + 1.3, -4.05), C(24, 24, 30), M.SmoothPlastic)
	c:box('NameplateStrip', V(-width / 2, y - 0.2, -4.3), V(width / 2, y, -4.05), color, tier >= 4 and M.Neon or M.SmoothPlastic)
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
local Build = {}

function Build.Starter(c, kit, s) -- the Tire Bag
	local T = 1
	-- Cracked concrete slab, flush.
	c:box('Slab', V(-4, 0, -4), V(4, 0.3, 4), C(170, 168, 160), M.Concrete)
	c:bar('Crack', V(-3.2, 0.31, -2.6), V(-0.4, 0.31, -0.6), 0.12, C(110, 108, 102), M.Concrete)
	c:bar('Crack', V(-0.4, 0.31, -0.6), V(1.4, 0.31, -1.8), 0.1, C(110, 108, 102), M.Concrete)
	local hook = gallows(c, { y0 = 0.3, top = 10.2, width = 0.9, color = C(132, 92, 58), material = M.Wood, foot = C(104, 70, 46) })
	for _, y in { 4.2, 7.6, 9.6 } do c:part('Bolt', V(0.2, 0.36, 0.36), CFrame.new(-3.0, y, 2.32) * CFrame.Angles(0, math.pi / 2, 0), C(90, 70, 60), M.CorrodedMetal, Enum.PartType.Cylinder) end
	-- Three stacked tyres with treads, sidewalls and dark holes, on a rope.
	local top
	for k = 0, 2 do
		local y = 2.3 + k * 1.3 -- centre of this tyre; 0.25-stud gaps show the rope between tyres
		c:blob('Tire', V(3.4, 1.05, 3.4), V(0.1 * (k - 1), y, 1.2), C(44, 44, 50), M.SmoothPlastic)
		c:post('TireHole', 0.7, 1.08, V(0.1 * (k - 1), y - 0.54, 1.2), C(16, 16, 20), M.SmoothPlastic)
		c:post('Whitewall', 1.18, 1.0, V(0.1 * (k - 1), y - 0.5, 1.2), C(206, 206, 210), M.SmoothPlastic).Transparency = 0
		top = y + 0.52
	end
	c:bar('Rope', V(0, top, 1.2), hook, 0.22, C(186, 150, 96), M.Fabric)
	c:blob('Knot', V(0.6, 0.6, 0.6), V(0, top + 0.25, 1.2), C(176, 140, 88), M.Fabric)
	nameplate(c, kit, s, T, 0.35, 5)
	priceTag(c, kit, s, T, 12)
	return { pad = V(8, 0.3, 8) }
end

function Build.Tape(c, kit, s)
	local T = 2
	-- Pallet: two runners and five top boards.
	for _, x in { -3.2, 0, 3.2 } do c:box('PalletRunner', V(x - 0.5, 0, -4), V(x + 0.5, 0.35, 4), C(150, 112, 70), M.WoodPlanks) end
	for k = 0, 4 do c:box('PalletBoard', V(-4, 0.35, -4 + k * 1.64), V(4, 0.6, -4 + k * 1.64 + 1.3), C(196, 156, 104), M.WoodPlanks) end
	-- Scaffold pipe frame with clamps.
	local steel = C(150, 158, 168)
	c:post('Pipe', 0.32, 10, V(-3, 0.6, 2.8), steel, M.Metal)
	c:rod('PipeArm', 0.32, 4.2, CFrame.new(-1.0, 10.1, 1.2) * CFrame.Angles(0, 0, 0), steel, M.Metal)
	c:part('PipeArmBack', V(1.9, 0.64, 0.64), CFrame.new(-3, 10.1, 2.0) * CFrame.Angles(0, math.pi / 2, 0), steel, M.Metal, Enum.PartType.Cylinder)
	c:bar('PipeBrace', V(-3, 7.4, 2.8), V(-1.2, 10, 1.2), 0.42, steel, M.Metal)
	for _, p in { V(-3, 10.1, 2.8), V(-3, 10.1, 1.2), V(-3, 7.4, 2.8) } do c:part('Clamp', V(0.85, 0.85, 0.85), CFrame.new(p), C(200, 150, 50), M.Metal, Enum.PartType.Ball) end
	c:box('PipeFoot', V(-3.8, 0.6, 2.0), V(-2.2, 0.9, 3.6), C(90, 96, 104), M.Metal)
	-- Worn leather bag, patched with duct tape.
	local swivel = bag(c, { bottom = 2.4, radius = 1.25, height = 4.4, body = C(150, 92, 60), cap = C(120, 72, 48), seam = C(110, 66, 42), metal = C(130, 120, 110) })
	local tape = C(196, 200, 206)
	for k, ang in { -0.18, 0.12, -0.06 } do
		local y = 2.4 + 1.1 + (k - 1) * 1.2
		c:part('TapeBand', V(0.5, 2.78, 2.78), CFrame.new(0, y + 0.2, 1.2) * CFrame.Angles(ang, 0, math.pi / 2), tape, M.Foil, Enum.PartType.Cylinder)
	end
	c:box('TapePatch', V(-0.55, 4.6, -0.3), V(0.55, 5.4, -0.2), tape, M.Foil)
	c:part('TapeTail', V(0.4, 1.1, 0.06), CFrame.new(0.9, 3.0, -0.15) * CFrame.Angles(0, 0, 0.35), tape, M.Foil)
	chain(c, swivel, V(0, 9.78, 1.2), 0.5, C(120, 96, 80), M.CorrodedMetal)
	nameplate(c, kit, s, T, 0.65, 5.2)
	priceTag(c, kit, s, T, 12)
	return { pad = V(8, 0.6, 8) }
end

function Build.Street(c, kit, s)
	local T = 3
	local blue = Props.Rarity[T]
	-- Curb-style concrete base with a painted blue edge and a faint ground ring.
	c:box('Curb', V(-4, 0, -4), V(4, 0.7, 4), C(206, 204, 198), M.Concrete)
	c:box('CurbStripe', V(-4.05, 0.45, -4.05), V(4.05, 0.7, 4.05), blue, M.SmoothPlastic)
	c:box('CurbTop', V(-3.95, 0.7, -3.95), V(3.95, 0.72, 3.95), C(214, 212, 206), M.Concrete)
	local ring = c:post('GroundRing', 2.6, 0.04, V(0, 0.72, 1.2), blue, M.Neon)
	ring.Transparency = 0.5
	-- Street-sign post: green pole, two crossed street signs, a lamp-arm over the bag.
	local green = C(36, 132, 76)
	c:post('SignPole', 0.36, 10.4, V(-3, 0.72, 2.8), green, M.Metal)
	c:post('PoleBase', 0.6, 0.6, V(-3, 0.72, 2.8), green, M.Metal)
	local signA = c:box('SignA', V(-4.6, 8.0, 2.6), V(-1.4, 8.9, 2.75), green, M.SmoothPlastic)
	c:box('SignB', V(-3.08, 8.95, 1.2), V(-2.92, 9.85, 4.4), green, M.SmoothPlastic)
	local gA = kit.surface(signA, Enum.NormalId.Front, 40)
	kit.line(gA, 'Street', 'BLOCK ST', C(255, 255, 255), kit.FONT.body, 0.1, 0.8)
	c:box('LampArm', V(-3, 10.6, 0.85), V(0.5, 11.12, 1.55), green, M.Metal)
	c:bar('ArmBrace', V(-3, 9.0, 2.6), V(-1.4, 10.62, 1.2), 0.3, green, M.Metal)
	-- Blue canvas bag with tag stripes.
	local swivel = bag(c, { bottom = 2.3, radius = 1.3, height = 4.6, body = C(44, 92, 196), cap = C(28, 52, 120), seam = C(240, 240, 250), metal = C(170, 176, 186), material = M.Fabric, bands = { 0.2, 0.5, 0.8 } })
	c:post('TagStripe', 1.42, 0.3, V(0, 3.6, 1.2), C(255, 70, 160), M.Fabric)
	chain(c, swivel, V(0, 10.6, 1.2), 0.5, C(170, 176, 186))
	nameplate(c, kit, s, T, 0.95, 5.4)
	priceTag(c, kit, s, T, 13)
	return { pad = V(8, 0.72, 8) }
end

function Build.Heavy(c, kit, s)
	local T = 4
	local purple = Props.Rarity[T]
	-- Diamond-plate plinth with a purple neon edge (first glowing trim).
	c:box('Plinth', V(-4, 0, -4), V(4, 0.9, 4), C(150, 156, 166), M.DiamondPlate)
	c:box('PlinthEdge', V(-4.06, 0.62, -4.06), V(4.06, 0.78, 4.06), purple, M.Neon)
	-- Black steel gallows with welded gussets and bolts.
	local black = C(36, 38, 46)
	local hook = gallows(c, { y0 = 0.9, top = 11.2, width = 1.0, color = black, material = M.Metal, cap = C(120, 126, 136) })
	for _, y in { 1.2, 10.0 } do c:wedge('Gusset', V(0.3, 1.1, 1.1), CFrame.new(-2.35, y + 0.55, 2.8) * CFrame.Angles(0, -math.pi / 2, 0), black, M.Metal) end
	for _, y in { 3, 6, 9 } do c:part('Bolt', V(0.16, 0.34, 0.34), CFrame.new(-3, y, 2.28) * CFrame.Angles(0, math.pi / 2, 0), C(170, 176, 186), M.Metal, Enum.PartType.Cylinder) end
	-- Classic glossy red heavy bag.
	local red = C(214, 40, 52)
	local swivel = bag(c, { bottom = 2.4, radius = 1.5, height = 5.4, body = red, cap = C(245, 245, 245), seam = C(150, 24, 34), strap = C(30, 30, 34), metal = C(200, 206, 214) })
	chain(c, swivel, hook, 0.55, C(200, 206, 214))
	-- First light: purple uplight behind the bag.
	local glow = c:box('UplightLens', V(-0.6, 0.9, 3.0), V(0.6, 1.1, 3.6), purple, M.Neon)
	kit.light(glow, purple, 1.4, 12)
	nameplate(c, kit, s, T, 1.05, 5.6)
	priceTag(c, kit, s, T, 14)
	return { pad = V(8, 0.9, 8) }
end

function Build.Speed(c, kit, s)
	local T = 5
	local pink = Props.Rarity[T]
	-- One-step plinth with pink trim.
	c:box('Plinth', V(-4, 0, -4), V(4, 0.7, 4), C(236, 232, 240), M.SmoothPlastic)
	c:box('Step', V(-3.2, 0.7, -3.2), V(3.2, 1.2, 3.6), C(222, 216, 228), M.SmoothPlastic)
	c:box('PlinthTrim', V(-4.06, 0.5, -4.06), V(4.06, 0.7, 4.06), pink, M.Neon)
	-- Chrome post with a wooden rebound platform.
	local chrome = C(210, 216, 226)
	c:post('Post', 0.42, 7.2, V(0, 1.2, 3.4), chrome, M.Metal)
	c:box('Bracket', V(-0.35, 7.6, 1.0), V(0.35, 8.0, 3.4), chrome, M.Metal)
	c:bar('BracketBrace', V(0, 5.8, 3.4), V(0, 7.62, 1.8), 0.32, chrome, M.Metal)
	c:box('Platform', V(-2.6, 8.0, -1.0), V(2.6, 8.8, 3.2), C(170, 112, 60), M.WoodPlanks)
	c:box('PlatformRim', V(-2.75, 7.75, -1.15), V(2.75, 8.0, 3.35), C(120, 76, 40), M.Wood)
	c:post('SwivelMount', 0.38, 0.5, V(0, 7.25, 1.2), chrome, M.Metal)
	-- Teardrop speed bag.
	c:blob('SpeedBag', V(2.1, 2.9, 2.1), V(0, 5.6, 1.2), pink, M.SmoothPlastic)
	c:blob('SpeedBagTip', V(1.0, 1.0, 1.0), V(0, 6.95, 1.2), C(255, 150, 220), M.SmoothPlastic)
	c:post('SpeedBagSeam', 1.07, 0.16, V(0, 5.5, 1.2), C(200, 50, 150), M.SmoothPlastic)
	-- First particles: a light shimmer of pink sparkles around the bag.
	emitter(c, 'Sparkles', V(0, 5.6, 1.2), 'sparkle', {
		Rate = 6, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.4, 1), SpreadAngle = Vector2.new(180, 180),
		Size = seq({ { 0, 0 }, { 0.3, 0.55 }, { 1, 0 } }), Transparency = seq({ { 0, 0.1 }, { 1, 0.6 } }),
		Color = cseq(C(255, 220, 245), pink), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}, V(3.4, 3.8, 3.4))
	nameplate(c, kit, s, T, 0.85, 5.6)
	priceTag(c, kit, s, T, 11)
	return { pad = V(8, 1.2, 8) }
end

function Build.DoubleEnd(c, kit, s)
	local T = 6
	local cyan = Props.Rarity[T]
	-- Two-step octagon stage with cyan neon trim.
	polygonPlinth(c, 'Stage', V(0, 0, 0.2), 4, 0, 0.7, C(40, 48, 70), M.SmoothPlastic)
	polygonPlinth(c, 'StageTop', V(0, 0, 0.2), 3.2, 0.7, 1.3, C(56, 66, 96), M.SmoothPlastic)
	polygonPlinth(c, 'StageTrim', V(0, 0, 0.2), 3.26, 1.12, 1.22, cyan, M.Neon)
	-- Overhead beam on two posts; the ball rides between neon bungees.
	local frame = C(30, 34, 46)
	for _, x in { -3.2, 3.2 } do c:box('Upright', V(x - 0.4, 1.3, 2.4), V(x + 0.4, 10.6, 3.2), frame, M.Metal) end
	c:box('Header', V(-3.6, 10.6, 2.4), V(3.6, 11.4, 3.2), frame, M.Metal)
	c:box('HeaderArm', V(-0.4, 10.6, 0.8), V(0.4, 11.2, 2.4), frame, M.Metal)
	c:post('FloorAnchor', 0.5, 0.3, V(0, 1.3, 1.2), C(200, 206, 214), M.Metal)
	local ballY = 5.6
	c:blob('Ball', V(1.9, 2.1, 1.9), V(0, ballY, 1.2), C(36, 40, 70), M.SmoothPlastic)
	c:post('BallStripe', 0.99, 0.28, V(0, ballY - 0.14, 1.2), cyan, M.Neon)
	-- Electric bungees: neon cords with beams of lightning along them.
	local cordTop, cordBottom = V(0, 10.6, 1.2), V(0, 1.6, 1.2)
	c:bar('BungeeTop', V(0, ballY + 1.05, 1.2), cordTop, 0.14, cyan, M.Neon)
	c:bar('BungeeBottom', V(0, ballY - 1.05, 1.2), cordBottom, 0.14, cyan, M.Neon)
	local function beam(a, b)
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
		bm.Width0, bm.Width1 = 0.9, 0.9
		bm.FaceCamera = true
		bm.LightEmission = 0.6
		bm.Color = cseq(cyan)
		bm.Transparency = seq({ { 0, 0.35 }, { 1, 0.35 } })
		bm.Parent = pa
	end
	beam(V(0, ballY + 1.1, 1.2), cordTop)
	beam(V(0, ballY - 1.1, 1.2), cordBottom)
	-- First moving part: a ring of cyan chips orbiting the ball.
	local orbit, orbitModel = c:group('OrbitRing')
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		orbit:part('OrbitChip', V(0.5, 0.18, 0.28), CFrame.new(math.cos(a) * 1.9, ballY, 1.2 + math.sin(a) * 1.9) * CFrame.Angles(0, -a, 0), cyan, M.Neon)
	end
	motion(orbitModel, { Spin = 90 })
	emitter(c, 'Sparks', V(0, ballY, 1.2), 'streak', {
		Rate = 5, Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(180, 180), Drag = 6,
		Size = seq({ { 0, 0.5 }, { 1, 0 } }), Color = cseq(C(220, 255, 255), cyan), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}, V(2.2, 2.2, 2.2))
	nameplate(c, kit, s, T, 0.12, 5.6)
	priceTag(c, kit, s, T, 13)
	return { pad = V(8, 1.3, 8) }
end

function Build.Pro(c, kit, s)
	local T = 7
	local red = Props.Rarity[T]
	local black = C(28, 28, 34)
	-- Stage: three steps, corner posts with red neon caps.
	c:box('Stage1', V(-4, 0, -4), V(4, 0.6, 4), black, M.SmoothPlastic)
	c:box('Stage2', V(-3.5, 0.6, -3.2), V(3.5, 1.1, 3.8), C(40, 40, 48), M.SmoothPlastic)
	c:box('Stage3', V(-3.0, 1.1, -2.4), V(3.0, 1.5, 3.6), C(52, 52, 62), M.SmoothPlastic)
	c:box('StageEdge', V(-4.06, 0.42, -4.06), V(4.06, 0.6, 4.06), red, M.Neon)
	for _, x in { -3.6, 3.6 } do
		c:box('CornerPost', V(x - 0.3, 0.6, -3.9), V(x + 0.3, 2.8, -3.3), black, M.Metal)
		c:box('CornerCap', V(x - 0.36, 2.8, -3.96), V(x + 0.36, 3.1, -3.24), red, M.Neon)
	end
	-- Heavy industrial gallows with red neon strips and gold bolts.
	local hook = gallows(c, { y0 = 1.5, top = 12.0, width = 1.2, color = black, material = M.Metal, cap = red, capMaterial = M.Neon })
	c:box('PostStrip', V(-3.66, 2.0, 2.18), V(-3.54, 11.4, 2.3), red, M.Neon)
	for _, y in { 3.5, 7, 10.5 } do c:part('Bolt', V(0.16, 0.36, 0.36), CFrame.new(-3, y, 2.16) * CFrame.Angles(0, math.pi / 2, 0), C(255, 200, 60), M.Metal, Enum.PartType.Cylinder) end
	-- Black pro bag with red and gold bands, a logo plate and gold hardware.
	local gold = C(255, 196, 50)
	local swivel = bag(c, { bottom = 2.9, radius = 1.35, height = 6.0, body = C(30, 30, 36), cap = red, seam = gold, strap = red, metal = gold, bands = { 0.12, 0.3, 0.7, 0.88 } })
	local logo = c:box('LogoPlate', V(-0.8, 5.2, 1.2 - 1.35 * 1.08 - 0.2), V(0.8, 6.4, 1.2 - 1.35 * 1.08 - 0.08), gold, M.Metal)
	local g = kit.surface(logo, Enum.NormalId.Front, 60)
	kit.line(g, 'Logo', 'PRO', C(30, 30, 36), kit.FONT.loud, 0.08, 0.84)
	chain(c, swivel, hook, 0.6, gold)
	-- Embers rising, a spotlight from the arm, and a slow-turning floor emblem.
	emitter(c, 'Embers', V(0, 1.7, 1.2), 'glow', {
		Rate = 10, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(20, 20),
		Size = seq({ { 0, 0.45 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Color = cseq(C(255, 220, 120), C(255, 60, 30)), LightEmission = 1, Acceleration = V(0, 1.5, 0),
		Shape = Enum.ParticleEmitterShape.Disc, -- a ring around the bag's base
	}, V(5.2, 0.2, 5.2))
	local lamp = c:box('Spotlamp', V(-0.5, 11.0, 0.7), V(0.5, 11.4, 1.7), black, M.Metal)
	local lens = c:box('SpotLens', V(-0.4, 10.9, 0.8), V(0.4, 11.0, 1.6), C(255, 240, 220), M.Neon)
	local spot = Instance.new('SpotLight')
	spot.Face, spot.Angle, spot.Range, spot.Brightness, spot.Color = Enum.NormalId.Bottom, 50, 16, 2, C(255, 236, 220)
	spot.Parent = lens
	local emblem, emblemModel = c:group('FloorEmblem')
	for k = 0, 3 do
		emblem:part('EmblemArm', V(4.6, 0.06, 0.5), CFrame.new(0, 1.53, 1.2) * CFrame.Angles(0, k * math.pi / 4, 0), red, M.Neon)
	end
	motion(emblemModel, { Spin = 25 })
	nameplate(c, kit, s, T, 0.0, 6)
	priceTag(c, kit, s, T, 14.5)
	return { pad = V(8, 1.5, 8) }
end

function Build.Gold(c, kit, s)
	local T = 8
	local gold = Props.Rarity[T]
	local marble = C(244, 242, 236)
	-- Round marble dais with gold steps and trim.
	polygonPlinth(c, 'Dais', V(0, 0, 0.4), 4.0, 0, 0.6, marble, M.Marble, 12)
	polygonPlinth(c, 'DaisGold', V(0, 0, 0.4), 4.06, 0.45, 0.6, gold, M.Neon, 12)
	polygonPlinth(c, 'DaisTop', V(0, 0, 0.4), 3.3, 0.6, 1.2, marble, M.Marble, 12)
	polygonPlinth(c, 'DaisTopGold', V(0, 0, 0.4), 3.36, 1.05, 1.2, gold, M.Neon, 12)
	-- Marble gallows with gold caps and a gold arm.
	local hook = gallows(c, { y0 = 1.2, top = 12.4, width = 1.1, color = marble, material = M.Marble, cap = gold, capMaterial = M.SmoothPlastic })
	c:box('ArmGold', V(-2.45, 12.35, 0.6), V(0.65, 12.55, 1.8), gold, M.SmoothPlastic)
	for _, y in { 2.6, 6.5, 10.4 } do c:box('PostBand', V(-3.63, y, 2.17), V(-2.37, y + 0.35, 3.43), gold, M.SmoothPlastic) end
	-- The gold bag: foil body, white caps, diamond studs, gold chain.
	local swivel = bag(c, { bottom = 2.7, radius = 1.55, height = 5.8, body = C(255, 196, 40), highlight = C(255, 232, 130), cap = C(255, 248, 225), seam = C(214, 140, 16), metal = gold })
	-- Diamonds set into both seam bands.
	for _, y in { 2.7 + 5.8 * 0.28, 2.7 + 5.8 * 0.72 } do
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local rr = 1.55 * 1.08 + 0.16
			c:part('Diamond', V(0.3, 0.3, 0.3), CFrame.new(math.cos(a) * rr, y, 1.2 + math.sin(a) * rr) * CFrame.Angles(math.pi / 4, a, math.pi / 4), C(170, 245, 255), M.Neon)
		end
	end
	chain(c, swivel, hook, 0.6, gold, M.SmoothPlastic)
	-- Full-body glow: gold light, rising sparkles, a god-ray beam, a turning halo and floating gems.
	local core = c:part('GlowCore', V(0.2, 0.2, 0.2), CFrame.new(0, 5.6, 1.2), gold)
	core.Transparency, core.CanCollide, core.CanQuery, core.CanTouch = 1, false, false, false
	kit.light(core, C(255, 214, 120), 1.6, 16)
	emitter(c, 'GoldSparkles', V(0, 5.6, 1.2), 'sparkle', {
		Rate = 14, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(180, 180),
		Size = seq({ { 0, 0 }, { 0.25, 0.7 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 1, 0.4 } }),
		Color = cseq(C(255, 255, 220), gold), LightEmission = 0.7, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, RotSpeed = NumberRange.new(-90, 90),
	}, V(4.6, 6.6, 4.6))
	local base = c:part('RayBase', V(0.2, 0.2, 0.2), CFrame.new(0, 1.3, 1.2), gold)
	local tip = c:part('RayTip', V(0.2, 0.2, 0.2), CFrame.new(0, 15, 1.2), gold)
	for _, p in { base, tip } do p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false end
	local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
	a0.Parent, a1.Parent = base, tip
	local ray = Instance.new('Beam')
	ray.Attachment0, ray.Attachment1 = a0, a1
	ray.Texture = textureFor('energy')
	ray:SetAttribute('PreviewTexture', 'energy')
	ray.Width0, ray.Width1 = 5.5, 2.5
	ray.FaceCamera = true
	ray.LightEmission = 0.5
	ray.Color = cseq(C(255, 230, 150))
	ray.Transparency = seq({ { 0, 0.55 }, { 1, 1 } })
	ray.Parent = base
	local halo, haloModel = c:group('Halo')
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		halo:part('HaloSegment', V(0.85, 0.2, 0.26), CFrame.new(math.cos(a) * 1.6, 13.4, 1.2 + math.sin(a) * 1.6) * CFrame.Angles(0, -a + math.pi / 2, 0), gold, M.Neon)
	end
	motion(haloModel, { Spin = 40, Bob = 0.25, BobPeriod = 2.4 })
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.5
		local gem, gemModel = c:group('FloatingGem')
		gem:part('Gem', V(0.5, 0.5, 0.5), CFrame.new(math.cos(a) * 3.0, 4.8 + k * 0.7, 1.2 + math.sin(a) * 3.0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C(255, 240, 150), M.Neon)
		motion(gemModel, { Bob = 0.4, BobPeriod = 1.8 + k * 0.3, Spin = 60 })
	end
	nameplate(c, kit, s, T, 0.2, 6.2)
	priceTag(c, kit, s, T, 16)
	return { pad = V(8, 1.2, 8) }
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
		eq:box('CornerPad', V(x - 0.6, h + 1.0, z - 0.6), V(x + 0.6, h + 5.2, z + 0.6), k[3], M.Fabric)
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
	-- Confetti drifting down inside the ring.
	emitter(c, 'Confetti', V(0, h + 13, 0), 'confetti', {
		Rate = 10, Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(60, 60),
		Acceleration = V(0, -2.2, 0), Drag = 0.6, Size = seq({ { 0, 0.45 }, { 1, 0.45 } }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 70, 160)), ColorSequenceKeypoint.new(0.33, C(60, 230, 255)), ColorSequenceKeypoint.new(0.66, C(255, 220, 60)), ColorSequenceKeypoint.new(1, C(120, 255, 120)) }),
		RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Box, LightInfluence = 1,
	})
	local sign = c:box('Sign', V(-7, 17, -T2 - 0.4), V(7, 21, -T2 + 0.2), C(20, 20, 26), M.SmoothPlastic)
	local g = kit.surface(sign, Enum.NormalId.Front, 30)
	kit.line(g, 'Title', 'CHAMP RING x' .. s.Multiplier, C(255, 200, 60), kit.FONT.loud, 0.05, 0.56, C(0, 0, 0), 2)
	kit.line(g, 'Detail', kit.compact(s.Required) .. ' POWER  ★★★★★', C(255, 255, 255), kit.FONT.body, 0.64, 0.3)
	return eqModel
end

-- Build station `s` (a Skins.Stations entry) at tier index `tier` in context `c` (origin = pad centre,
-- -Z toward the aisle). Returns the station model.
function Props.station(c, kit, s, tier)
	local st, model = c:group('Training_' .. s.Id)
	local fn = Build[s.Id]
	local info = fn(st, kit, s)
	-- The mat that counts for training sits on top of the pedestal.
	local zone = st:box('TrainingZone', V(-3.4, info.pad.Y, -3.4), V(3.4, info.pad.Y + 0.06, 3.4), Props.Rarity[tier], M.SmoothPlastic)
	zone.Transparency, zone.CanCollide, zone.CastShadow = 1, false, false
	model:SetAttribute('Tier', tier)
	return model
end

return Props
