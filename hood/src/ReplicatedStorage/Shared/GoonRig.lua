-- The stage goons' look (brief 18): cartoon rival-crew kids from the block, built from boxes like everything else in the
-- hood (classic blocky proportions: a 2-stud torso, 1-stud arms and legs, a chunky square head), in their crew's colours:
-- a hoodie (hood bunched at the back, front pocket, white drawstrings), jeans, white sneakers, a bandana headband or a
-- backwards cap or a beanie, and an angry-but-silly face (big eyes, slanted brows, a frown). Runners are smaller,
-- Bruisers bigger and wider, the Boss twice the size in black and gold with shades and a chain. No weapons: they punch.
--   GoonRig.build(kind, crew, variant, parent) -> rig (a Model of anchored, non-colliding, non-query parts)
--   GoonRig.pose(rig, root, p)  places every part for a pose: root = CFrame on the ground (facing its LookVector);
--     p = { walk = phase (rad), stride = 0..1, lean, twist, punch = right arm forward 0..1, windup = 0..1,
--           flinch, ko = 0..1 (falls flat on its back), arms = idle style 0..1 (crossed), bob, look = head pitch }
--   rig.Height (studs to the top of the head), rig.Head (the head part: tags and stars hang over it)
-- Client-side only (Waves.client); the offline renders build them in the harness too.
local GoonRig = {}
local C = Color3.fromRGB

GoonRig.Crews = {
	Red = { Hoodie = C(222, 58, 58), Trim = C(156, 30, 40), Band = C(36, 34, 46), Pants = C(58, 76, 128), Cap = C(36, 34, 46) },
	Green = { Hoodie = C(64, 182, 96), Trim = C(32, 116, 62), Band = C(255, 214, 64), Pants = C(64, 64, 78), Cap = C(255, 214, 64) },
	Purple = { Hoodie = C(140, 76, 214), Trim = C(88, 42, 146), Band = C(70, 226, 236), Pants = C(44, 48, 66), Cap = C(70, 226, 236) },
	Orange = { Hoodie = C(255, 146, 44), Trim = C(198, 94, 22), Band = C(48, 130, 236), Pants = C(72, 82, 104), Cap = C(48, 130, 236) },
	Yellow = { Hoodie = C(255, 214, 56), Trim = C(206, 152, 24), Band = C(36, 34, 46), Pants = C(54, 60, 78), Cap = C(36, 34, 46) },
	Boss = { Hoodie = C(40, 40, 52), Trim = C(255, 202, 64), Band = C(255, 202, 64), Pants = C(34, 34, 44), Cap = C(255, 202, 64) },
}
-- Cartoon skin tones, taken in turn.
GoonRig.Skins = { C(255, 214, 170), C(222, 164, 112), C(168, 110, 72), C(112, 72, 48), C(244, 190, 140) }
GoonRig.Ink = C(30, 26, 40)

local Scale = { Goon = 1, Runner = 0.88, Bruiser = 1.3, Boss = 2.1 }
local Wide = { Goon = 1, Runner = 0.94, Bruiser = 1.18, Boss = 1.12 } -- (torso width on top of the scale)

local function part(model, name, size, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Builds a goon. `variant` (any whole number) picks the skin tone and the headwear.
function GoonRig.build(kind, crew, variant, parent)
	local s = Scale[kind] or 1
	local w = Wide[kind] or 1
	local look = GoonRig.Crews[crew] or GoonRig.Crews.Red
	local v = variant or 1
	local skin = GoonRig.Skins[(v - 1) % #GoonRig.Skins + 1]
	local boss = kind == 'Boss'
	local model = Instance.new('Model')
	model.Name = 'Goon_' .. kind
	local rig = { Model = model, Kind = kind, Scale = s, Segments = {}, Parts = {}, Height = 5.3 * s }
	-- seg: name -> list of { part, offset (CFrame in the joint's frame, unscaled studs; scaled here) }
	local function add(seg, name, size, offset, color, material, shape)
		local p = part(model, name, size * s, color, material, shape)
		local off = offset - offset.Position + offset.Position * s
		rig.Segments[seg] = rig.Segments[seg] or {}
		table.insert(rig.Segments[seg], { p, off })
		table.insert(rig.Parts, p)
		return p
	end
	local V, CF = Vector3.new, CFrame.new
	local tw = 2 * w -- torso width
	-- Legs (joint at the hip, y 2): jeans, a darker cuff, white sneakers with a coloured sole stripe.
	for _, side in { 'L', 'R' } do
		local seg = 'Leg' .. side
		add(seg, 'Jeans', V(0.98, 1.6, 0.98), CF(0, -0.8, 0), look.Pants)
		add(seg, 'Cuff', V(1.02, 0.18, 1.02), CF(0, -1.5, 0), look.Pants:Lerp(C(0, 0, 0), 0.25))
		add(seg, 'Shoe', V(1.04, 0.42, 1.34), CF(0, -1.79, -0.15), C(246, 246, 250))
		add(seg, 'Sole', V(1.06, 0.12, 1.38), CF(0, -1.94, -0.15), look.Trim)
		add(seg, 'Toe', V(0.7, 0.2, 0.2), CF(0, -1.74, -0.83), boss and look.Trim or C(214, 218, 226))
	end
	-- Torso (joint at the waist, y 2): the hoodie, its pocket, drawstrings, the hood bunched behind the neck.
	add('Torso', 'Hoodie', V(tw, 2, 1), CF(0, 1, 0), look.Hoodie)
	add('Torso', 'Hem', V(tw + 0.04, 0.26, 1.04), CF(0, 0.13, 0), look.Trim)
	add('Torso', 'Pocket', V(tw * 0.62, 0.5, 0.08), CF(0, 0.62, -0.53), look.Trim)
	add('Torso', 'Hood', V(tw * 0.62, 0.62, 0.42), CF(0, 2.02, 0.42), look.Trim)
	add('Torso', 'Collar', V(tw * 0.7, 0.2, 0.86), CF(0, 2.05, -0.02), look.Trim)
	if boss then
		-- A big gold chain with a dollar-free medallion (a plain gold disc), over the hoodie.
		for k = -2, 2 do add('Torso', 'Chain', V(0.22, 0.22, 0.1), CF(k * 0.32, 1.7 - math.abs(k) * -0.1 - (2 - math.abs(k)) * 0.12, -0.54), C(255, 214, 80), Enum.Material.Neon) end
		add('Torso', 'Medal', V(0.1, 0.62, 0.62), CF(0, 1.12, -0.56) * CFrame.Angles(0, math.pi / 2, 0), C(255, 202, 64), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	else
		for _, x in { -0.28, 0.28 } do add('Torso', 'String', V(0.09, 0.62, 0.07), CF(x, 1.55, -0.53), C(250, 250, 252)) end
	end
	-- Arms (joint at the shoulder, y 3.5 = torso joint + 1.5): sleeve, a cuff in the trim colour, a hand.
	for _, side in { 'L', 'R' } do
		local seg = 'Arm' .. side
		add(seg, 'Sleeve', V(0.96, 1.5, 0.96), CF(0, -0.25, 0), look.Hoodie)
		add(seg, 'SleeveCuff', V(1.0, 0.2, 1.0), CF(0, -1.0, 0), look.Trim)
		add(seg, 'Hand', V(0.8, 0.42, 0.8), CF(0, -1.3, 0), skin)
	end
	-- Head (joint at the neck, y 4): a chunky block, the face on its front (-Z), the headwear.
	local hs = boss and 1.3 or 1.25
	rig.Head = add('Head', 'Head', V(hs, hs, hs), CF(0, hs / 2, 0), skin)
	local fz = -hs / 2 - 0.02
	local eyeY = hs * 0.56
	if boss then
		add('Head', 'Shades', V(hs * 0.92, 0.3, 0.08), CF(0, eyeY, fz - 0.02), C(20, 20, 26), Enum.Material.Glass)
		add('Head', 'ShadesGlint', V(0.18, 0.08, 0.04), CF(-hs * 0.24, eyeY + 0.06, fz - 0.07), C(255, 255, 255), Enum.Material.Neon)
	else
		for _, x in { -1, 1 } do
			add('Head', 'Eye', V(0.3, 0.3, 0.06), CF(x * hs * 0.21, eyeY, fz), C(255, 255, 255))
			add('Head', 'Pupil', V(0.15, 0.2, 0.05), CF(x * hs * 0.21 - x * 0.03, eyeY - 0.02, fz - 0.03), GoonRig.Ink)
			-- cross brows: slanted down toward the nose (a cartoon scowl)
			add('Head', 'Brow', V(0.4, 0.11, 0.06), CF(x * hs * 0.21, eyeY + 0.24, fz - 0.01) * CFrame.Angles(0, 0, x * 0.45), GoonRig.Ink)
		end
	end
	add('Head', 'Mouth', V(0.38, 0.08, 0.05), CF(0.04, hs * 0.26, fz) * CFrame.Angles(0, 0, 0.12), C(90, 40, 40))
	local wear = boss and 'Cap' or ({ 'Band', 'Cap', 'Band', 'Beanie' })[(v - 1) % 4 + 1]
	if kind == 'Bruiser' then wear = 'Beanie' end
	if wear == 'Band' then
		-- A bandana headband, knot and two tails at the back.
		add('Head', 'Bandana', V(hs + 0.08, 0.26, hs + 0.08), CF(0, hs * 0.86, 0), look.Band)
		add('Head', 'Knot', V(0.26, 0.22, 0.18), CF(0, hs * 0.86, hs / 2 + 0.12), look.Band)
		add('Head', 'Tail', V(0.16, 0.42, 0.08), CF(-0.14, hs * 0.86 - 0.24, hs / 2 + 0.18) * CFrame.Angles(0, 0, 0.3), look.Band)
		add('Head', 'Tail', V(0.16, 0.36, 0.08), CF(0.14, hs * 0.86 - 0.2, hs / 2 + 0.18) * CFrame.Angles(0, 0, -0.35), look.Band)
	elseif wear == 'Cap' then
		-- A backwards cap: crown, a button on top, the brim over the back of the neck.
		add('Head', 'CapCrown', V(hs + 0.08, 0.36, hs + 0.08), CF(0, hs + 0.12, 0), look.Cap)
		add('Head', 'CapButton', V(0.2, 0.08, 0.2), CF(0, hs + 0.34, 0), look.Trim)
		add('Head', 'CapBrim', V(hs * 0.8, 0.1, 0.6), CF(0, hs - 0.02, hs / 2 + 0.28), look.Cap)
	else
		-- A beanie with a turned-up band and a pom.
		add('Head', 'Beanie', V(hs + 0.08, 0.5, hs + 0.08), CF(0, hs + 0.1, 0), look.Band)
		add('Head', 'BeanieBand', V(hs + 0.12, 0.2, hs + 0.12), CF(0, hs - 0.1, 0), look.Band:Lerp(C(0, 0, 0), 0.2))
		add('Head', 'Pom', V(0.32, 0.32, 0.32), CF(0, hs + 0.48, 0), C(250, 250, 252), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	-- The parts' resting transparencies (a knocked-out goon fades by setting them).
	rig.Rest = {}
	for _, p in rig.Parts do rig.Rest[p] = p.Transparency end
	if parent then model.Parent = parent end
	return rig
end

-- Every segment's frame for a pose, then every part; one BulkMoveTo.
local lists = setmetatable({}, { __mode = 'k' })
function GoonRig.pose(rig, root, p)
	p = p or {}
	local s = rig.Scale
	local A = CFrame.Angles
	local walk, stride = p.walk or 0, math.clamp(p.stride or 0, 0, 1)
	local swing = math.sin(walk) * 0.75 * stride
	local bob = (p.bob or 0) + math.abs(math.cos(walk)) * 0.18 * stride * s
	-- Knocked out: the whole body tips back about its heels, flat on the ground at ko = 1.
	local ko = math.clamp(p.ko or 0, 0, 1)
	local base = root
	if ko > 0 then base = root * CFrame.new(0, 0, 0.6 * s) * A(ko * math.pi / 2 * 0.98, 0, 0) * CFrame.new(0, 0, -0.6 * s) end
	local hips = base * CFrame.new(0, 2 * s + bob, 0)
	local lean = (p.lean or 0) + 0.12 * stride - (p.flinch or 0)
	local waist = hips * A(-lean, (p.twist or 0), 0)
	local frames = {}
	frames.LegL = hips * CFrame.new(-0.5 * s, 0, 0) * A(swing, 0, 0)
	frames.LegR = hips * CFrame.new(0.5 * s, 0, 0) * A(-swing, 0, 0)
	frames.Torso = waist
	local tw = (Wide[rig.Kind] or 1)
	local shoulderX = (tw + 0.5) * s
	local crossed = math.clamp(p.arms or 0, 0, 1) * (1 - stride)
	local punch, windup = math.clamp(p.punch or 0, 0, 1), math.clamp(p.windup or 0, 0, 1)
	local armSwing = -swing * 0.9
	local ko2 = ko * 2.6 -- (arms fly up as it falls)
	-- Left arm: swings, crosses over the chest at idle, guards up in a fight.
	frames.ArmL = waist * CFrame.new(-shoulderX, 1.5 * s, 0) * A(armSwing + crossed * 1.35 + (p.guard or 0) * 1.1 + ko2, 0, -0.08 + crossed * 0.62 - ko * 0.3)
	-- Right arm: pulled back on the wind-up, straight out on the punch.
	local r = -armSwing + crossed * 1.2 + (p.guard or 0) * 0.7 - windup * 1.1 + punch * (1.65 + windup * 1.1) + ko2
	frames.ArmR = waist * CFrame.new(shoulderX, 1.5 * s, 0) * A(r, 0, 0.08 - crossed * 0.62 + ko * 0.3)
	frames.Head = waist * CFrame.new(0, 2 * s, 0) * A(-(p.look or 0) + lean * 0.3, 0, 0)
	local list = lists[rig]
	if not list then
		list = { parts = {}, cframes = {} }
		for _, segName in { 'LegL', 'LegR', 'Torso', 'ArmL', 'ArmR', 'Head' } do
			for _, e in rig.Segments[segName] or {} do table.insert(list.parts, e[1]) end
		end
		lists[rig] = list
	end
	local k = 0
	for _, segName in { 'LegL', 'LegR', 'Torso', 'ArmL', 'ArmR', 'Head' } do
		local f = frames[segName]
		for _, e in rig.Segments[segName] or {} do
			k += 1
			list.cframes[k] = f * e[2]
		end
	end
	local ok = pcall(function() workspace:BulkMoveTo(list.parts, list.cframes, Enum.BulkMoveMode.FireCFrameChanged) end)
	if not ok then
		-- (no BulkMoveTo: the offline harness. It keeps Position apart from CFrame, so both are written.)
		for i, part in list.parts do
			part.CFrame = list.cframes[i]
			pcall(function() part.Position = list.cframes[i].Position end)
		end
	end
end

-- Hides or shows the whole goon (fading by `t` 0..1 toward invisible).
function GoonRig.fade(rig, t)
	for _, p in rig.Parts do p.Transparency = (rig.Rest[p] or 0) + (1 - (rig.Rest[p] or 0)) * math.clamp(t, 0, 1) end
end

return GoonRig
