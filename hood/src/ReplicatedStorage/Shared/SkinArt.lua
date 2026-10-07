-- The 15 looks (Config/Skins.lua List), built from plain parts: a blocky figure for displays and the same
-- costume welded onto real R15 / R6 characters.
--
-- How it works: every look is a recipe (Art.Looks[s.Look or s.Id]) that lays pieces on a canonical block
-- R15 rig (Art.Rig: standard Roblox block-rig part sizes, feet at the origin, facing -Z, head made bigger for
-- a toy look). Each piece belongs to ONE rig part and is stored relative to it, so:
--   * Art.mannequin / Art.posed build the rig as anchored parts (any pose, any scale) and place the pieces;
--   * Art.equip welds each piece to the matching part of a real character (R15 by name; R6 parts hold
--     several rig parts at fixed offsets), scaled to that part's size, so it follows animation and works on
--     scaled avatars. Pieces are Massless, CanCollide/CanTouch/CanQuery off, never anchored.
-- Recipes read the look's colours (Color = top, Accent, Trim, Pants, Skin, Hair), so a cloned look with a new
-- Color (the lobby's NPCs) still dresses correctly.
local Art = {}
local V, C = Vector3.new, Color3.fromRGB
local CF, ANG = CFrame.new, CFrame.Angles
local rad = math.rad

---------------------------------------------------------------------------------------------- the rig
-- Canonical part sizes and rest centres (studs, feet at y = 0). Torso 2..4, head centre 4.76 (the HUD
-- frames faces there). Lower arms/legs overlap the upper ones like the real rig.
Art.Rig = {
	Head = { V(1.5, 1.5, 1.25), V(0, 4.76, 0) },
	UpperTorso = { V(2, 1.6, 1), V(0, 3.2, 0) },
	LowerTorso = { V(2, 0.4, 1), V(0, 2.2, 0) },
	LeftUpperArm = { V(1, 1.169, 1), V(-1.5, 3.4155, 0) },
	LeftLowerArm = { V(1, 1.052, 1), V(-1.5, 2.826, 0) },
	LeftHand = { V(1, 0.3, 1), V(-1.5, 2.15, 0) },
	RightUpperArm = { V(1, 1.169, 1), V(1.5, 3.4155, 0) },
	RightLowerArm = { V(1, 1.052, 1), V(1.5, 2.826, 0) },
	RightHand = { V(1, 0.3, 1), V(1.5, 2.15, 0) },
	LeftUpperLeg = { V(1, 1.217, 1), V(-0.5, 1.3915, 0) },
	LeftLowerLeg = { V(1, 1.193, 1), V(-0.5, 0.8965, 0) },
	LeftFoot = { V(1, 0.3, 1), V(-0.5, 0.15, 0) },
	RightUpperLeg = { V(1, 1.217, 1), V(0.5, 1.3915, 0) },
	RightLowerLeg = { V(1, 1.193, 1), V(0.5, 0.8965, 0) },
	RightFoot = { V(1, 0.3, 1), V(0.5, 0.15, 0) },
}
-- Where a piece authored on a whole limb goes: split planes (rig y) between its parts, top part first.
local LIMBS = {
	Torso = { { 'UpperTorso', 'LowerTorso' }, { 2.4 } },
	LeftArm = { { 'LeftUpperArm', 'LeftLowerArm', 'LeftHand' }, { 3.05, 2.3 } },
	RightArm = { { 'RightUpperArm', 'RightLowerArm', 'RightHand' }, { 3.05, 2.3 } },
	LeftLeg = { { 'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot' }, { 1.05, 0.3 } },
	RightLeg = { { 'RightUpperLeg', 'RightLowerLeg', 'RightFoot' }, { 1.05, 0.3 } },
}
-- Joint pivots for posing (rig space) and which part each joint carries.
local JOINT = {
	Neck = V(0, 4.0, 0),
	LeftShoulder = V(-1.25, 3.7, 0), RightShoulder = V(1.25, 3.7, 0),
	LeftElbow = V(-1.5, 3.05, 0), RightElbow = V(1.5, 3.05, 0),
	LeftHip = V(-0.5, 2.0, 0), RightHip = V(0.5, 2.0, 0),
	LeftKnee = V(-0.5, 1.05, 0), RightKnee = V(0.5, 1.05, 0),
}
-- R6: which R6 part carries each rig part, and the R6 parts' canonical boxes.
local R6PART = {
	Head = 'Head', UpperTorso = 'Torso', LowerTorso = 'Torso',
	LeftUpperArm = 'Left Arm', LeftLowerArm = 'Left Arm', LeftHand = 'Left Arm',
	RightUpperArm = 'Right Arm', RightLowerArm = 'Right Arm', RightHand = 'Right Arm',
	LeftUpperLeg = 'Left Leg', LeftLowerLeg = 'Left Leg', LeftFoot = 'Left Leg',
	RightUpperLeg = 'Right Leg', RightLowerLeg = 'Right Leg', RightFoot = 'Right Leg',
}
local R6BOX = {
	Head = { V(1.5, 1.5, 1.25), V(0, 4.76, 0) }, Torso = { V(2, 2, 1), V(0, 3, 0) },
	['Left Arm'] = { V(1, 2, 1), V(-1.5, 3, 0) }, ['Right Arm'] = { V(1, 2, 1), V(1.5, 3, 0) },
	['Left Leg'] = { V(1, 2, 1), V(-0.5, 1, 0) }, ['Right Leg'] = { V(1, 2, 1), V(0.5, 1, 0) },
}
-- On R6 a lower part with its own colour (bare forearms, hands, socks, shoes) gets a thin cover: the
-- visible band of that part (rig y from..to), reaching 0.01 past the limb's end so the end caps don't flicker.
local R6COVER = {
	LowerTorso = { 1.99, 2.4 }, LeftLowerArm = { 2.3, 3.05 }, RightLowerArm = { 2.3, 3.05 }, LeftHand = { 1.99, 2.3 }, RightHand = { 1.99, 2.3 },
	LeftLowerLeg = { 0.3, 1.05 }, RightLowerLeg = { 0.3, 1.05 }, LeftFoot = { -0.01, 0.3 }, RightFoot = { -0.01, 0.3 },
}

---------------------------------------------------------------------------------------------- palette
local K = {
	white = C(248, 248, 244), ink = C(24, 24, 30), black = C(36, 36, 44), grey = C(140, 146, 158),
	gold = C(255, 200, 40), goldDark = C(232, 150, 20), silver = C(214, 220, 230), steel = C(120, 128, 142),
	denim = C(52, 98, 178), leather = C(46, 40, 42), brown = C(122, 74, 44), tan = C(196, 150, 96),
	red = C(232, 44, 52), cash = C(96, 206, 98), cashDark = C(52, 150, 66), lens = C(30, 40, 56),
	teal = C(40, 200, 210), ruby = C(230, 30, 70), sapphire = C(40, 110, 255), emerald = C(30, 210, 110),
}
Art.Palette = K
local MAT = {
	cloth = Enum.Material.SmoothPlastic, knit = Enum.Material.Fabric, fur = Enum.Material.Fabric,
	gold = Enum.Material.SmoothPlastic, metal = Enum.Material.SmoothPlastic, glass = Enum.Material.Glass, neon = Enum.Material.Neon,
	shiny = Enum.Material.SmoothPlastic, plastic = Enum.Material.SmoothPlastic,
}
local REFL = { shiny = 0.06, metal = 0.1, gold = 0.08, glass = 0.2 }

---------------------------------------------------------------------------------------------- recipe builder
-- W collects pieces. Positions are rig space (studs on the canonical rig); seg is a rig part name or a
-- whole limb (Torso, LeftArm, RightArm, LeftLeg, RightLeg), which splits axis-aligned pieces at the joints.
local Builder = {}
Builder.__index = Builder
local function newBuilder(s)
	return setmetatable({ s = s, pieces = {}, body = {} }, Builder)
end
local function partFor(limb, y)
	local l = LIMBS[limb]
	for i, plane in l[2] do
		if y >= plane then return l[1][i] end
	end
	return l[1][#l[1]]
end
function Builder:add(seg, name, size, pos, color, opt)
	opt = opt or {}
	local rot = opt.rot
	if LIMBS[seg] then
		local l = LIMBS[seg]
		local lo, hi = pos.Y - size.Y / 2, pos.Y + size.Y / 2
		if not rot and not opt.whole then
			-- Cut at every joint plane the piece crosses (by more than a sliver), one piece per part.
			local cuts = { hi }
			for _, plane in l[2] do
				if plane < hi - 0.04 and plane > lo + 0.04 then table.insert(cuts, plane) end
			end
			table.insert(cuts, lo)
			if #cuts > 2 then
				for i = 1, #cuts - 1 do
					local a, b = cuts[i], cuts[i + 1]
					self:add(partFor(seg, (a + b) / 2), name, V(size.X, a - b, size.Z), V(pos.X, (a + b) / 2, pos.Z), color, opt)
				end
				return
			end
		end
		seg = partFor(seg, pos.Y)
	end
	local rig = Art.Rig[seg]
	assert(rig, 'SkinArt: unknown part ' .. tostring(seg))
	local local_ = CF(pos - rig[2]) * (rot or CFrame.identity)
	table.insert(self.pieces, {
		seg = seg, name = name, size = size, cf = local_, color = color, mat = opt.mat or 'cloth', shape = opt.shape,
		face = opt.face, transp = opt.transp,
	})
end
function Builder:box(seg, name, size, pos, color, opt) self:add(seg, name, size, pos, color, opt) end
function Builder:ball(seg, name, d, pos, color, opt)
	opt = table.clone(opt or {})
	opt.shape = 'Ball'
	self:add(seg, name, V(d, d, d), pos, color, opt)
end
-- Cylinder along axis 'x', 'y' or 'z' (Roblox cylinders run along local X).
local AXIS = { x = CFrame.identity, y = ANG(0, 0, math.pi / 2), z = ANG(0, math.pi / 2, 0) }
function Builder:cyl(seg, name, length, d, pos, color, axis, opt)
	opt = table.clone(opt or {})
	opt.shape = 'Cylinder'
	opt.rot = (opt.rot or CFrame.identity) * AXIS[axis or 'x']
	self:add(seg, name, V(length, d, d), pos, color, opt)
end
function Builder:wedge(seg, name, size, pos, color, opt)
	opt = table.clone(opt or {})
	opt.shape = 'Wedge'
	opt.rot = opt.rot or CFrame.identity
	self:add(seg, name, size, pos, color, opt)
end
-- Body part colours: keys Head, UpperTorso, LowerTorso, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot
-- (both sides) or a full part name (LeftHand) for one side.
function Builder:paint(t)
	for k, v in t do self.body[k] = v end
end

---------------------------------------------------------------------------------------------- shared pieces
local HC, HT, HF = 4.76, 5.51, -0.625 -- head centre y, head top y, face plane z
local function FZ(layer) return -(0.48 + 0.04 * layer) end -- torso front, layer 1.. (pieces 0.04 deep)
local function BZ(layer) return 0.48 + 0.04 * layer end
local function sides(f) f(-1, 'Left') f(1, 'Right') end

-- Face: eyes (black with a glint), brows, mouth. kind = s.Expression.
local function face(W, s, kind, opt)
	opt = opt or {}
	local brow = s.Brow or s.Hair or K.ink
	local eyeY = HC + 0.06
	local mouthY = HC - 0.32
	local fz = function(d, layer) return HF - d / 2 - 0.02 * (layer or 0) end
	if not opt.noEyes then
		sides(function(sx)
			-- White, a black pupil looking slightly to the side, a glint; sly looks get a lid.
			local h = (kind == 'sly' or kind == 'smug') and 0.17 or 0.27
			W:box('Head', 'EyeWhite', V(0.24, h, 0.03), V(sx * 0.3, eyeY - (0.27 - h) / 2, fz(0.03)), K.white, { face = true })
			W:box('Head', 'Eye', V(0.13, h - 0.06, 0.03), V(sx * 0.3 - 0.03, eyeY - (0.27 - h) / 2 - 0.02, fz(0.03, 1.5)), K.ink, { face = true })
			W:box('Head', 'EyeGlint', V(0.05, 0.05, 0.02), V(sx * 0.3 - 0.0, eyeY - (0.27 - h) / 2 + 0.03, fz(0.02, 3)), K.white, { face = true })
		end)
	end
	if not opt.noBrows then
		sides(function(sx)
			local tilt = ({ angry = -16, worried = 14, happy = 6, sly = -6, smug = -8, wise = 4, cool = -10 })[kind] or 0
			local y = eyeY + ((kind == 'worried' or kind == 'happy') and 0.27 or 0.23)
			W:box('Head', 'Brow', V(0.3, 0.07, 0.04), V(sx * 0.31, y, fz(0.04)), brow, { face = true, rot = ANG(0, 0, rad(-sx * tilt)) })
		end)
	end
	if opt.noMouth then return end
	if kind == 'happy' or kind == 'grin' then
		W:box('Head', 'Mouth', V(0.46, 0.14, 0.04), V(0, mouthY + 0.02, fz(0.04)), K.ink, { face = true })
		W:box('Head', 'Teeth', V(0.38, 0.05, 0.02), V(0, mouthY + 0.06, fz(0.02, 2)), K.white, { face = true })
		sides(function(sx)
			W:box('Head', 'MouthCorner', V(0.12, 0.06, 0.04), V(sx * 0.27, mouthY + 0.1, fz(0.04)), K.ink, { face = true, rot = ANG(0, 0, rad(sx * 35)) })
		end)
	elseif kind == 'worried' then
		W:box('Head', 'Mouth', V(0.14, 0.16, 0.04), V(0, mouthY, fz(0.04)), K.ink, { face = true })
	elseif kind == 'smirk' or kind == 'smug' or kind == 'cool' or kind == 'sly' then
		W:box('Head', 'Mouth', V(0.36, 0.07, 0.04), V(-0.04, mouthY, fz(0.04)), K.ink, { face = true, rot = ANG(0, 0, rad(-8)) })
		W:box('Head', 'MouthCorner', V(0.1, 0.06, 0.04), V(-0.24, mouthY + 0.04, fz(0.04)), K.ink, { face = true, rot = ANG(0, 0, rad(-40)) })
	elseif kind == 'angry' then
		W:box('Head', 'Mouth', V(0.34, 0.07, 0.04), V(0, mouthY - 0.02, fz(0.04)), K.ink, { face = true })
		sides(function(sx)
			W:box('Head', 'MouthCorner', V(0.08, 0.06, 0.04), V(sx * 0.19, mouthY - 0.05, fz(0.04)), K.ink, { face = true, rot = ANG(0, 0, rad(sx * 35)) })
		end)
	else -- serious, wise
		W:box('Head', 'Mouth', V(0.32, 0.06, 0.04), V(0, mouthY, fz(0.04)), K.ink, { face = true })
	end
	if opt.cheeks then
		sides(function(sx) W:box('Head', 'Cheek', V(0.16, 0.08, 0.02), V(sx * 0.46, HC - 0.16, fz(0.02)), s.Skin:Lerp(C(255, 90, 90), 0.35), { face = true }) end)
	end
end

-- Glasses on the face. kind: shades | aviators | round
local function glasses(W, kind, frame, lens)
	local y = HC + 0.06
	local z = HF - 0.05
	if kind == 'shades' then
		W:box('Head', 'ShadesBar', V(1.3, 0.09, 0.06), V(0, y + 0.13, z - 0.01), frame, { face = 'front', mat = 'shiny' })
		sides(function(sx)
			W:box('Head', 'ShadesLens', V(0.46, 0.3, 0.05), V(sx * 0.3, y - 0.02, z), lens, { face = 'front', mat = 'shiny' })
			W:box('Head', 'ShadesGlint', V(0.06, 0.2, 0.02), V(sx * 0.3 + 0.1, y, z - 0.035), C(170, 200, 230), { face = 'front', rot = ANG(0, 0, rad(25)) })
		end)
	elseif kind == 'aviators' then
		W:box('Head', 'AviatorBar', V(1.2, 0.05, 0.05), V(0, y + 0.13, z - 0.01), frame, { face = 'front', mat = 'gold' })
		sides(function(sx)
			W:box('Head', 'AviatorRim', V(0.5, 0.34, 0.03), V(sx * 0.3, y - 0.02, z + 0.005), frame, { face = 'front', mat = 'gold' })
			W:box('Head', 'AviatorLens', V(0.42, 0.27, 0.04), V(sx * 0.3, y - 0.03, z - 0.02), lens, { face = 'front', mat = 'shiny' })
			W:box('Head', 'AviatorGlint', V(0.05, 0.18, 0.02), V(sx * 0.3 + 0.1, y - 0.01, z - 0.045), C(220, 255, 255), { face = 'front', rot = ANG(0, 0, rad(25)) })
		end)
	elseif kind == 'round' then
		W:box('Head', 'SpecsBridge', V(0.22, 0.05, 0.04), V(0, y + 0.04, z), frame, { face = 'front', mat = 'gold' })
		sides(function(sx)
			W:cyl('Head', 'SpecsRim', 0.03, 0.4, V(sx * 0.3, y, z + 0.005), frame, 'z', { face = 'front', mat = 'gold' })
			W:cyl('Head', 'SpecsLens', 0.03, 0.32, V(sx * 0.3, y, z - 0.02), lens, 'z', { face = 'front', mat = 'glass' })
		end)
	end
end

-- Hair (s.Hair). kind: hatted | short | flattop | balding | pompadour | slick
local function hair(W, s, kind)
	local h = s.Hair or K.ink
	-- The shell: one block over the back and the back half of the sides (ear line back).
	local function shell(mat, height)
		W:box('Head', 'HairShell', V(1.58, height or 0.66, 0.9), V(0, HT - (height or 0.66) / 2 + 0.04, 0.22), h, { mat = mat })
	end
	if kind == 'hatted' then -- under a hat only the shell shows
		shell()
	elseif kind == 'short' or kind == 'fade' then
		shell()
		W:box('Head', 'HairTop', V(1.56, 0.2, 1.31), V(0, HT + 0.06, 0.0), h)
		W:box('Head', 'Fringe', V(1.3, 0.16, 0.08), V(0, HT - 0.06, -0.66), h)
	elseif kind == 'flattop' then
		shell()
		W:box('Head', 'HairTop', V(1.52, 0.6, 1.24), V(0, HT + 0.29, 0.0), h)
		W:box('Head', 'HairLine', V(1.36, 0.1, 0.06), V(0, HT - 0.02, -0.65), h)
		W:box('Head', 'HairPart', V(0.05, 0.3, 1.26), V(0.42, HT + 0.2, 0.0), h:Lerp(K.white, 0.3))
	elseif kind == 'balding' then
		W:box('Head', 'HairShell', V(1.58, 0.62, 0.86), V(0, HC + 0.12, 0.22), h)
		sides(function(sx) W:box('Head', 'HairTuft', V(0.16, 0.26, 0.5), V(sx * 0.82, HC + 0.5, 0.16), h) end)
		W:box('Head', 'BaldShine', V(0.4, 0.04, 0.3), V(0.2, HT + 0.02, -0.15), W.s.Skin:Lerp(K.white, 0.45))
	elseif kind == 'pompadour' then
		shell('shiny')
		W:box('Head', 'HairTop', V(1.56, 0.2, 1.31), V(0, HT + 0.06, 0.02), h, { mat = 'shiny' })
		W:box('Head', 'Quiff', V(1.3, 0.42, 0.62), V(0, HT + 0.24, -0.34), h, { mat = 'shiny', rot = ANG(rad(-14), 0, 0) })
		W:box('Head', 'QuiffShine', V(0.7, 0.05, 0.3), V(0.12, HT + 0.47, -0.42), h:Lerp(K.white, 0.45), { rot = ANG(rad(-14), 0, 0) })
	elseif kind == 'slick' then
		shell('shiny')
		W:box('Head', 'HairTop', V(1.56, 0.16, 1.31), V(0, HT + 0.06, 0.02), h, { mat = 'shiny' })
		W:box('Head', 'Hairline', V(1.4, 0.1, 0.08), V(0, HT - 0.03, -0.66), h, { mat = 'shiny' })
		for i = -1, 1 do W:box('Head', 'CombLine', V(0.05, 0.03, 1.1), V(i * 0.34, HT + 0.15, 0.03), h:Lerp(K.white, 0.35)) end
	end
end

-- A shoe on one foot. kind: sneaker | hightop | boot | dress | spectator
local function shoe(W, sx, kind, main, sole, extra)
	local leg = sx < 0 and 'LeftFoot' or 'RightFoot'
	local W0 = W
	W = setmetatable({}, { __index = function(_, k)
		local f = W0[k]
		if type(f) ~= 'function' then return f end
		-- Shift each piece out by most of its extra width so left and right pieces never overlap.
		return function(_, seg, name, size, pos, ...)
			if typeof(size) == 'Vector3' and typeof(pos) == 'Vector3' and size.X > 1 then
				pos = pos + V(sx * ((size.X - 1) * 0.4 + 0.01), 0, 0)
			end
			return f(W0, seg, name, size, pos, ...)
		end
	end })
	local x = sx * 0.5
	if kind == 'sneaker' or kind == 'hightop' then
		W:box(leg, 'Sole', V(1.08, 0.12, 1.34), V(x, 0.06, -0.14), sole)
		W:box(leg, 'Shoe', V(1.05, 0.28, 1.24), V(x, 0.25, -0.1), main)
		W:box(leg, 'ToeCap', V(1.06, 0.13, 0.3), V(x, 0.185, -0.58), sole)
		W:box(leg, 'Swoosh', V(1.07, 0.07, 0.5), V(x, 0.26, 0.05), extra or sole)
		if kind == 'hightop' then
			W:box(sx < 0 and 'LeftLowerLeg' or 'RightLowerLeg', 'HighTop', V(1.07, 0.3, 1.07), V(x, 0.5, 0), main)
		end
	elseif kind == 'boot' then
		W:box(leg, 'Sole', V(1.1, 0.14, 1.3), V(x, 0.07, -0.12), sole)
		W:box(leg, 'Boot', V(1.06, 0.3, 1.2), V(x, 0.29, -0.07), main)
		W:box(sx < 0 and 'LeftLowerLeg' or 'RightLowerLeg', 'BootShaft', V(1.07, 0.36, 1.07), V(x, 0.56, 0), main)
		W:box(leg, 'BootLace', V(0.3, 0.04, 0.4), V(x, 0.45, -0.38), extra or sole)
	else -- dress, spectator
		W:box(leg, 'Sole', V(1.06, 0.1, 1.32), V(x, 0.05, -0.14), sole)
		W:box(leg, 'Shoe', V(1.04, 0.24, 1.2), V(x, 0.22, -0.08), main, { mat = 'shiny' })
		W:wedge(leg, 'ShoeToe', V(1.04, 0.2, 0.22), V(x, 0.2, -0.77), main, { mat = 'shiny', rot = CFrame.identity })
		if kind == 'spectator' then
			W:box(leg, 'Wingtip', V(1.05, 0.25, 0.42), V(x, 0.23, -0.42), extra)
		end
	end
end

-- A ring around a limb / the torso: seg, name, centre x, y, height, width (x), depth (z), colour.
local function band(W, seg, name, x, y, h, w, d, color, opt)
	W:box(seg, name, V(w, h, d), V(x, y, 0), color, opt)
end

-- Gold chain hanging on the chest: a V of links ending in a pendant. size = link thickness.
local function chain(W, name, y0, depth, thick, color, layer, pendant)
	local z = FZ(layer)
	sides(function(sx)
		W:box('UpperTorso', name, V(thick, 0.62, thick * 0.8), V(sx * 0.3, y0 - 0.26, z), color, { mat = 'gold', rot = ANG(0, 0, rad(sx * 36)) })
		W:box('UpperTorso', name, V(thick, 0.3, thick * 0.8), V(sx * 0.12, y0 - depth + 0.08, z), color, { mat = 'gold', rot = ANG(0, 0, rad(sx * 70)) })
	end)
	if pendant then pendant(y0 - depth - 0.05, z - 0.02) end
end

-- Suit front: shirt V, collar points, lapels (notch), tie or bow tie, pocket square, buttons.
local function suitFront(W, s, o)
	local shirt, lapel = o.shirt or K.white, o.lapel or s.Color:Lerp(K.ink, 0.15)
	local vw = o.vWidth or 0.5
	W:box('UpperTorso', 'Shirt', V(vw, 0.95, 0.04), V(0, 3.52, FZ(1)), shirt)
	sides(function(sx)
		W:wedge('UpperTorso', 'Collar', V(0.04, 0.2, 0.18), V(sx * 0.14, 3.9, FZ(2)), o.collar or shirt, { rot = ANG(0, sx * math.pi / 2, 0) * ANG(rad(sx * 20), 0, 0) })
		W:box('UpperTorso', 'Lapel', V(0.2, 0.92, 0.04), V(sx * (vw / 2 + 0.02), 3.5, FZ(2)), lapel, { mat = o.lapelMat, rot = ANG(0, 0, rad(-sx * 16)) })
		W:box('UpperTorso', 'LapelNotch', V(0.22, 0.12, 0.04), V(sx * (vw / 2 + 0.17), 3.84, FZ(2)), lapel, { mat = o.lapelMat, rot = ANG(0, 0, rad(sx * 30)) })
	end)
	if o.tie == 'bow' then
		W:box('UpperTorso', 'BowKnot', V(0.1, 0.1, 0.05), V(0, 3.86, FZ(3)), o.tieColor)
		sides(function(sx) W:wedge('UpperTorso', 'BowWing', V(0.05, 0.16, 0.16), V(sx * 0.12, 3.86, FZ(3)), o.tieColor, { rot = ANG(0, sx * math.pi / 2, 0) }) end)
	elseif o.tie then
		W:box('UpperTorso', 'TieKnot', V(0.14, 0.12, 0.05), V(0, 3.86, FZ(3)), o.tieColor)
		W:box('UpperTorso', 'Tie', V(0.16, 0.66, 0.04), V(0, 3.45, FZ(3)), o.tieColor)
		W:wedge('UpperTorso', 'TieTip', V(0.16, 0.12, 0.04), V(0, 3.06, FZ(3)), o.tieColor, { rot = ANG(math.pi / 2, 0, 0) * ANG(0, 0, 0) })
		if o.tieStripe then
			for i = 0, 2 do W:box('UpperTorso', 'TieStripe', V(0.17, 0.03, 0.02), V(0, 3.68 - i * 0.18, FZ(3) - 0.03), o.tieStripe, { rot = ANG(0, 0, rad(-25)) }) end
		end
	end
	if o.pocketSquare then
		W:box('UpperTorso', 'PocketSquare', V(0.22, 0.12, 0.04), V(0.58, 3.48, FZ(2)), o.pocketSquare)
		W:wedge('UpperTorso', 'PocketSquareTip', V(0.1, 0.1, 0.03), V(0.58, 3.59, FZ(2)), o.pocketSquare)
	end
	for i, y in o.buttons or { 2.86, 2.62 } do
		W:box('UpperTorso', 'Button', V(0.09, 0.09, 0.04), V(o.buttonX or 0, y, FZ(1)), o.buttonColor or s.Color:Lerp(K.ink, 0.5), { mat = o.buttonMat })
		local _ = i
	end
end

-- Pinstripes on a part's front (and outer sides for limbs).
local function pinstripes(W, seg, x0, x1, y, h, z, color, step)
	local x = x0
	while x <= x1 + 1e-6 do
		W:box(seg, 'Pinstripe', V(0.03, h, 0.02), V(x, y, z), color)
		x += step
	end
end

-- Block numbers and letters (seven segments) for jersey backs and patches. x0 is the centre of the text,
-- +X reads left to right as seen from behind (where back prints are read).
local SEG7 = { ['0'] = 'abcdef', ['1'] = 'bc', ['2'] = 'abged', ['3'] = 'abgcd', ['4'] = 'fgbc', ['5'] = 'afgcd',
	['6'] = 'afgedc', ['7'] = 'abc', ['8'] = 'abcdefg', ['9'] = 'abcdfg', O = 'abcdef', G = 'afedc' }
local function print7(W, seg, text, x0, y0, z, h, w, t, color, name)
	local gap = w * 0.35
	local total = #text * w + (#text - 1) * gap
	for i = 1, #text do
		local ch = text:sub(i, i)
		local x = x0 - total / 2 + (i - 1) * (w + gap) + w / 2
		local function bar(sx, sy, px, py) W:box(seg, name or 'Print', V(sx, sy, 0.04), V(px, py, z), color) end
		if ch == '1' then
			bar(t, h, x + w * 0.15, y0)
			bar(w * 0.45, t, x - w * 0.05, y0 + h / 2 - t / 2)
			bar(w * 0.8, t, x + w * 0.1, y0 - h / 2 + t / 2)
		else
			local segs = SEG7[ch] or ''
			-- Two stacked side segments are one full-height bar (fewer parts).
			if segs:find('e') and segs:find('f') then segs = segs:gsub('[ef]', '') .. 'L' end
			if segs:find('b') and segs:find('c') then segs = segs:gsub('[bc]', '') .. 'R' end
			for c in segs:gmatch('.') do
				if c == 'L' then bar(t, h, x - w / 2 + t / 2, y0)
				elseif c == 'R' then bar(t, h, x + w / 2 - t / 2, y0)
				elseif c == 'a' then bar(w, t, x, y0 + h / 2 - t / 2)
				elseif c == 'd' then bar(w, t, x, y0 - h / 2 + t / 2)
				elseif c == 'g' then bar(w, t, x, y0)
				elseif c == 'b' then bar(t, h / 2, x + w / 2 - t / 2, y0 + h / 4)
				elseif c == 'c' then bar(t, h / 2, x + w / 2 - t / 2, y0 - h / 4)
				elseif c == 'e' then bar(t, h / 2, x - w / 2 + t / 2, y0 - h / 4)
				elseif c == 'f' then bar(t, h / 2, x - w / 2 + t / 2, y0 + h / 4) end
			end
			if ch == 'G' then bar(w / 2, t, x + w / 4, y0) end
		end
	end
end

-- A block "$": an S (the 5 shape) with a bar through it. facing = -1 for a front face, 1 for a back face.
local function dollar(W, seg, x, y, z, h, color)
	print7(W, seg, '5', x, y, z, h, h * 0.6, h * 0.17, color, 'Dollar')
	W:box(seg, 'DollarBar', V(h * 0.14, h * 1.3, 0.04), V(x, y, z + (z > 0 and 0.02 or -0.02)), color, { mat = 'gold' })
end

-- A back vent (a dark seam up from the hem) and an optional half-belt with two buttons across the back.
local function backVent(W, seg, y0, y1, z, color)
	W:box(seg, 'BackVent', V(0.05, y1 - y0, 0.03), V(0, (y0 + y1) / 2, z), color)
end
local function halfBelt(W, y, z, color, button)
	W:box('LowerTorso', 'HalfBelt', V(1.3, 0.18, 0.05), V(0, y, z), color)
	sides(function(sx) W:box('LowerTorso', 'HalfBeltButton', V(0.12, 0.12, 0.04), V(sx * 0.5, y, z + 0.04), button, { mat = 'gold' }) end)
end

---------------------------------------------------------------------------------------------- the looks
local Looks = {}
Art.Looks = Looks

-- 1. Corner Kid: white tee with a ball print and a red jersey "1" on the back, backwards red cap, blue
-- hoops shorts, tube socks, high-tops, a basketball at the hip.
function Looks.CornerKid(W, s)
	local tee, red, shorts, ball = s.Color, s.Accent, s.Pants, s.Trim or C(255, 140, 30)
	W:paint({ Head = s.Skin, UpperTorso = tee, LowerTorso = tee, UpperArm = s.Skin, LowerArm = s.Skin, Hand = s.Skin, UpperLeg = shorts, LowerLeg = s.Skin, Foot = K.white })
	-- Tee: wide short sleeves with red rims, red crew neck, hem, ball print, number on the back.
	sides(function(sx, side)
		band(W, side .. 'UpperArm', 'Sleeve', sx * 1.52, 3.69, 0.66, 1.12, 1.12, tee)
		band(W, side .. 'UpperArm', 'SleeveRim', sx * 1.52, 3.38, 0.08, 1.13, 1.13, red)
	end)
	W:box('UpperTorso', 'NeckRim', V(0.7, 0.1, 0.04), V(0, 3.93, FZ(1)), red)
	W:box('UpperTorso', 'NeckRimBack', V(0.9, 0.1, 0.04), V(0, 3.93, BZ(1)), red)
	band(W, 'LowerTorso', 'TeeHem', 0, 2.08, 0.18, 2.06, 1.06, tee)
	W:cyl('UpperTorso', 'BallPrint', 0.04, 0.72, V(0, 3.25, FZ(1)), ball, 'z')
	W:box('UpperTorso', 'BallPrintSeam', V(0.72, 0.05, 0.02), V(0, 3.25, FZ(1) - 0.03), K.ink)
	W:box('UpperTorso', 'BallPrintSeam', V(0.05, 0.72, 0.02), V(0, 3.25, FZ(1) - 0.03), K.ink)
	print7(W, 'UpperTorso', '1', 0, 3.2, BZ(1), 1.0, 0.56, 0.2, red, 'BackPrint')
	-- Shorts: wide hem, white side stripe; tube socks; red high-tops.
	sides(function(sx, side)
		band(W, side .. 'UpperLeg', 'ShortsHem', sx * 0.5, 0.88, 0.2, 1.1, 1.1, shorts)
		W:box(side .. 'UpperLeg', 'ShortsStripe', V(0.04, 1.1, 0.16), V(sx * 1.04, 1.4, 0), K.white)
		band(W, side .. 'LowerLeg', 'Sock', sx * 0.5, 0.62, 0.36, 1.03, 1.03, K.white)
		band(W, side .. 'LowerLeg', 'SockStripe', sx * 0.5, 0.74, 0.06, 1.04, 1.04, red)
		shoe(W, sx, 'hightop', red, K.white, K.white)
	end)
	band(W, 'RightLowerArm', 'Wristband', 1.5, 2.42, 0.16, 1.08, 1.08, red)
	-- Backwards cap, a stud for the button, hair peeking out at the front strap.
	hair(W, s, 'hatted')
	W:box('Head', 'Cap', V(1.6, 0.42, 1.36), V(0, HT + 0.12, 0.02), red)
	W:box('Head', 'CapBrim', V(1.1, 0.08, 0.6), V(0, HT - 0.03, 0.9), red:Lerp(K.ink, 0.15))
	W:cyl('Head', 'CapButton', 0.1, 0.24, V(0, HT + 0.37, 0.02), K.white, 'y')
	W:box('Head', 'CapStrap', V(0.5, 0.06, 0.04), V(0, HT - 0.02, -0.7), K.white)
	face(W, s, s.Expression, { cheeks = true })
	-- The basketball, palmed at the left hip, with its seams.
	local bp = V(-1.66, 1.86, -0.5)
	W:ball('LeftHand', 'Basketball', 1.1, bp, ball)
	W:cyl('LeftHand', 'BallSeam', 0.05, 1.12, bp, K.ink, 'x')
	W:cyl('LeftHand', 'BallSeam', 0.05, 1.12, bp, K.ink, 'y')
end

-- 2. Runner: lime track jacket (white sleeve stripes, black yoke and collar), joggers, headphones, an orange
-- backpack.
function Looks.Pickpocket(W, s)
	local jacket, dark, pack = s.Color, s.Accent, s.Trim or C(255, 130, 40)
	W:paint({ Head = s.Skin, UpperTorso = jacket, LowerTorso = jacket, UpperArm = jacket, LowerArm = jacket, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.white })
	W:box('UpperTorso', 'Yoke', V(2.04, 0.42, 1.04), V(0, 3.8, 0), dark)
	W:box('UpperTorso', 'StandCollar', V(1.0, 0.2, 0.9), V(0, 4.06, 0.0), dark)
	W:box('Torso', 'Zip', V(0.06, 1.95, 0.04), V(0, 3.0, FZ(1)), K.silver, { mat = 'metal' })
	W:box('UpperTorso', 'ZipPull', V(0.1, 0.16, 0.04), V(0, 3.76, FZ(2)), K.silver, { mat = 'metal' })
	band(W, 'LowerTorso', 'Waistband', 0, 2.08, 0.16, 2.04, 1.04, dark)
	sides(function(sx, side)
		for i = 0, 1 do
			W:box(side .. 'Arm', 'SleeveStripe', V(0.04, 1.62, 0.1), V(sx * 2.02, 3.15, -0.1 + i * 0.2), K.white)
		end
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.16, 1.06, 1.06, dark)
		W:box(side .. 'Leg', 'JoggerStripe', V(0.04, 1.7, 0.12), V(sx * 1.02, 1.15, 0), jacket)
		band(W, side .. 'LowerLeg', 'JoggerCuff', sx * 0.5, 0.37, 0.14, 1.07, 1.07, s.Pants:Lerp(K.ink, 0.3))
		shoe(W, sx, 'sneaker', jacket, K.white, dark)
		-- Backpack straps over the shoulders.
		W:box('UpperTorso', 'Strap', V(0.18, 1.3, 0.04), V(sx * 0.62, 3.35, FZ(2)), pack:Lerp(K.ink, 0.35))
	end)
	W:box('UpperTorso', 'Backpack', V(1.5, 1.45, 0.62), V(0, 3.15, 0.84), pack)
	W:box('UpperTorso', 'BackpackPocket', V(1.1, 0.6, 0.2), V(0, 2.82, 1.24), pack:Lerp(K.ink, 0.2))
	W:box('UpperTorso', 'BackpackFlap', V(1.54, 0.22, 0.66), V(0, 3.85, 0.85), pack:Lerp(K.ink, 0.2))
	W:box('UpperTorso', 'BackpackPatch', V(0.5, 0.18, 0.04), V(0, 3.4, 1.17), jacket)
	for i = -1, 1 do W:cyl('UpperTorso', 'Stud', 0.08, 0.26, V(i * 0.45, 4.0, 0.85), pack:Lerp(K.ink, 0.2), 'y') end
	-- Hair and headphones (band over the top, big cups on the ears).
	hair(W, s, 'flattop')
	W:box('Head', 'HeadphoneBand', V(1.94, 0.14, 0.26), V(0, HT + 0.65, 0.05), dark)
	sides(function(sx)
		W:box('Head', 'HeadphoneArm', V(0.14, 1.0, 0.26), V(sx * 0.9, HT + 0.12, 0.05), dark)
		W:cyl('Head', 'HeadphoneCup', 0.26, 0.62, V(sx * 0.88, HC + 0.12, 0.05), jacket, 'x')
		W:cyl('Head', 'HeadphonePad', 0.06, 0.66, V(sx * 1.04, HC + 0.12, 0.05), dark, 'x')
	end)
	face(W, s, s.Expression)
end

-- 3. Lookout: puffy orange jacket zipped to the chin with a fur-trimmed hood down the back, teal beanie with
-- a pompom, binoculars on the chest, a walkie-talkie, cargo pants, tan boots.
function Looks.Lookout(W, s)
	local puff, beanie, boot = s.Color, s.Accent, s.Trim or C(210, 150, 70)
	local seam = puff:Lerp(K.ink, 0.3)
	W:paint({ Head = s.Skin, UpperTorso = seam, LowerTorso = seam, UpperArm = seam, LowerArm = seam, Hand = K.ink, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = boot })
	-- Puffer baffles: fat bands over torso and arms, the darker jacket showing in the seams.
	for _, y in { 3.74, 3.24, 2.74, 2.24 } do
		band(W, 'Torso', 'Baffle', 0, y, 0.44, 2.26, 1.24, puff)
	end
	sides(function(sx, side)
		for _, y in { 3.74, 3.25, 2.76 } do
			band(W, side .. 'Arm', 'ArmBaffle', sx * 1.56, y, 0.42, 1.2, 1.2, puff)
		end
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.16, 1.08, 1.08, K.ink)
		W:box(side .. 'UpperLeg', 'CargoPocket', V(0.06, 0.42, 0.5), V(sx * 1.03, 1.3, 0), s.Pants:Lerp(K.ink, 0.2))
		shoe(W, sx, 'boot', boot, K.brown, K.white)
	end)
	W:box('UpperTorso', 'PufferCollar', V(1.4, 0.3, 1.2), V(0, 4.08, 0), puff)
	W:box('Torso', 'Zip', V(0.06, 2.05, 0.04), V(0, 3.05, -0.63), K.ink)
	-- Hood down the back with a white fur trim, and a teal reflective stripe across the back.
	W:box('UpperTorso', 'Hood', V(1.5, 0.62, 0.36), V(0, 3.9, 0.76), puff)
	W:box('UpperTorso', 'HoodTrim', V(1.56, 0.2, 0.42), V(0, 4.24, 0.78), K.white, { mat = 'knit' })
	W:box('UpperTorso', 'BackStripe', V(2.27, 0.14, 0.04), V(0, 3.24, 0.64), beanie)
	-- Binoculars on a strap.
	sides(function(sx)
		W:box('UpperTorso', 'BinoStrap', V(0.06, 0.6, 0.04), V(sx * 0.42, 3.7, -0.64), K.ink, { rot = ANG(0, 0, rad(sx * 30)) })
		W:cyl('UpperTorso', 'Binocular', 0.42, 0.34, V(sx * 0.2, 3.25, -0.82), K.ink, 'z')
		W:cyl('UpperTorso', 'BinoLens', 0.04, 0.26, V(sx * 0.2, 3.25, -1.04), K.teal, 'z', { mat = 'glass' })
	end)
	W:box('UpperTorso', 'BinoBridge', V(0.2, 0.14, 0.2), V(0, 3.25, -0.78), K.grey)
	-- Walkie-talkie on the chest strap, antenna up.
	W:box('UpperTorso', 'Walkie', V(0.26, 0.42, 0.16), V(0.68, 3.66, -0.7), K.ink)
	W:box('UpperTorso', 'WalkieAntenna', V(0.06, 0.4, 0.06), V(0.74, 4.06, -0.7), K.ink)
	W:box('UpperTorso', 'WalkieLight', V(0.08, 0.06, 0.02), V(0.62, 3.8, -0.79), C(255, 60, 60), { mat = 'neon' })
	-- Beanie with a folded cuff and pompom.
	W:box('Head', 'Beanie', V(1.6, 0.5, 1.36), V(0, HT + 0.08, 0.02), beanie, { mat = 'knit' })
	W:box('Head', 'BeanieCuff', V(1.64, 0.24, 1.4), V(0, HT - 0.2, 0.02), beanie:Lerp(K.ink, 0.15), { mat = 'knit' })
	W:ball('Head', 'Pompom', 0.5, V(0, HT + 0.44, 0.02), K.white, { mat = 'knit' })
	W:box('Head', 'BeaniePatch', V(0.3, 0.14, 0.03), V(0.4, HT - 0.2, -0.72), puff)
	hair(W, s, 'hatted')
	face(W, s, s.Expression)
end

-- 4. Bandit: purple hoodie with the hood up, a dotted bandana over nose and mouth, gloves, jeans, a money
-- sack over the left shoulder (behind the arm, so the arm can swing).
function Looks.Bandit(W, s)
	local hood, mask, sack = s.Color, s.Accent, s.Trim or C(214, 178, 120)
	local dark = hood:Lerp(K.ink, 0.25)
	W:paint({ Head = s.Skin, UpperTorso = hood, LowerTorso = hood, UpperArm = hood, LowerArm = hood, Hand = K.ink, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.white })
	-- Hood up: back, sides, top and a front rim around the face.
	W:box('Head', 'HoodBack', V(1.72, 1.62, 0.18), V(0, HC + 0.08, 0.74), hood)
	W:box('Head', 'HoodTop', V(1.72, 0.18, 1.5), V(0, HT + 0.1, 0.02), hood)
	sides(function(sx)
		W:box('Head', 'HoodSide', V(0.16, 1.4, 1.5), V(sx * 0.86, HC + 0.02, 0.02), hood)
		W:box('Head', 'HoodRim', V(0.14, 1.36, 0.1), V(sx * 0.72, HC + 0.04, -0.74), dark)
	end)
	W:box('Head', 'HoodRimTop', V(1.58, 0.14, 0.1), V(0, HT + 0.06, -0.74), dark)
	-- Bandana mask: covers below the eyes, a point under the chin, white dots.
	W:box('Head', 'Bandana', V(1.56, 0.62, 1.32), V(0, HC - 0.38, 0.0), mask)
	W:wedge('Head', 'BandanaPoint', V(0.8, 0.34, 0.08), V(0, HC - 0.84, -0.64), mask, { rot = ANG(0, 0, math.pi) })
	for _, p in { { -0.42, -0.2 }, { 0, -0.24 }, { 0.42, -0.2 }, { -0.22, -0.46 }, { 0.22, -0.46 } } do
		W:box('Head', 'BandanaDot', V(0.09, 0.09, 0.02), V(p[1], HC + p[2], -0.67), K.white, { face = true })
	end
	face(W, s, s.Expression, { noMouth = true })
	-- Hoodie details: pocket, drawstrings, ribbed hem and cuffs, a dark band across the back.
	W:box('Torso', 'Pocket', V(1.2, 0.5, 0.04), V(0, 2.62, FZ(1)), dark)
	sides(function(sx, side)
		W:box('UpperTorso', 'Drawstring', V(0.05, 0.45, 0.04), V(sx * 0.18, 3.72, FZ(1)), K.white)
		W:ball('UpperTorso', 'Aglet', 0.09, V(sx * 0.18, 3.47, FZ(1)), K.white)
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.18, 1.06, 1.06, dark)
		band(W, side .. 'LowerLeg', 'JeanCuff', sx * 0.5, 0.38, 0.12, 1.04, 1.04, s.Pants:Lerp(K.white, 0.25))
		shoe(W, sx, 'sneaker', K.white, K.ink, hood)
	end)
	band(W, 'LowerTorso', 'Hem', 0, 2.08, 0.18, 2.04, 1.04, dark)
	-- Money sack slung over the left shoulder behind the arm, the rope down the front, bills poking out of
	-- the neck, a gold $ on its face and on its back.
	local k = V(-1.5, 4.36, 0.98)
	W:box('UpperTorso', 'Sack', V(1.3, 1.2, 0.9), k, sack, { rot = ANG(0, 0, rad(-10)) })
	W:box('UpperTorso', 'SackNeck', V(0.5, 0.3, 0.5), k + V(0.1, 0.72, 0), sack:Lerp(K.ink, 0.15))
	W:box('UpperTorso', 'SackTie', V(0.56, 0.1, 0.56), k + V(0.1, 0.62, 0), K.brown)
	W:box('UpperTorso', 'SackCash', V(0.36, 0.3, 0.1), k + V(0.04, 0.95, -0.08), K.cash, { rot = ANG(0, 0, rad(12)) })
	W:box('UpperTorso', 'SackCash', V(0.36, 0.3, 0.1), k + V(0.18, 0.95, 0.1), K.cashDark, { rot = ANG(0, 0, rad(-14)) })
	dollar(W, 'UpperTorso', k.X, k.Y - 0.05, k.Z + 0.47, 0.5, K.gold)
	W:box('UpperTorso', 'SackRope', V(0.1, 1.5, 0.1), V(-1.0, 3.3, -0.56), K.brown, { rot = ANG(0, 0, rad(12)) })
end

-- 5. Hustler: teal velour tracksuit with white stripes (a white yoke and a gold $ on the back), bucket hat,
-- shades, the first gold chain ($ pendant), a cross-body bag and a stack of cash.
function Looks.Hustler(W, s)
	local suit, hat, gold = s.Color, s.Accent, K.gold
	W:paint({ Head = s.Skin, UpperTorso = K.white, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.white })
	-- Open track top over a white tee.
	sides(function(sx, side)
		W:box('Torso', 'JacketFront', V(0.66, 1.92, 1.04), V(sx * 0.68, 3.05, 0), suit)
		W:box('Torso', 'JacketPiping', V(0.05, 1.9, 0.04), V(sx * 0.36, 3.05, -0.54), K.white)
		W:box('UpperTorso', 'JacketCollar', V(0.36, 0.16, 0.9), V(sx * 0.62, 4.06, 0.02), suit)
		W:box(side .. 'Arm', 'SleeveStripe', V(0.04, 1.62, 0.16), V(sx * 2.02, 3.15, 0), K.white)
		W:box(side .. 'Leg', 'PantStripe', V(0.04, 1.75, 0.16), V(sx * 1.02, 1.1, 0), K.white)
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.14, 1.06, 1.06, K.white)
		shoe(W, sx, 'sneaker', K.white, K.white, gold)
	end)
	W:box('UpperTorso', 'JacketBack', V(1.3, 1.6, 0.04), V(0, 3.2, 0.52), suit)
	W:box('UpperTorso', 'BackYoke', V(2.06, 0.14, 1.06), V(0, 3.7, 0), K.white)
	dollar(W, 'UpperTorso', 0, 3.1, 0.56, 0.72, gold)
	-- Gold rope chain with a $ medallion.
	chain(W, 'GoldChain', 4.0, 0.85, 0.09, gold, 2, function(y, z)
		W:cyl('UpperTorso', 'Medallion', 0.06, 0.4, V(0, y, z), gold, 'z', { mat = 'gold' })
		W:box('UpperTorso', 'MedallionMark', V(0.06, 0.24, 0.03), V(0, y, z - 0.04), K.goldDark, { mat = 'gold' })
	end)
	-- Cross-body bag on a strap (right shoulder to left hip), front and back below the shoulder line.
	W:box('UpperTorso', 'BagStrap', V(0.14, 1.85, 0.04), V(0.0, 3.08, FZ(3)), K.ink, { rot = ANG(0, 0, rad(-38)) })
	W:box('UpperTorso', 'BagStrapBack', V(0.14, 1.85, 0.04), V(0.0, 3.08, BZ(2)), K.ink, { rot = ANG(0, 0, rad(-38)) })
	W:box('LowerTorso', 'HipBag', V(0.8, 0.4, 0.3), V(-0.58, 2.35, -0.66), K.ink)
	W:box('LowerTorso', 'HipBagZip', V(0.72, 0.04, 0.02), V(-0.58, 2.46, -0.82), gold, { mat = 'gold' })
	-- Bucket hat, shades.
	hair(W, s, 'hatted')
	W:box('Head', 'BucketCrown', V(1.52, 0.5, 1.3), V(0, HT + 0.18, 0.02), hat)
	W:box('Head', 'BucketBrim', V(2.0, 0.08, 1.78), V(0, HT - 0.08, 0.02), hat, { rot = ANG(rad(-4), 0, 0) })
	W:cyl('Head', 'Stud', 0.08, 0.26, V(0, HT + 0.47, 0.02), hat, 'y')
	W:box('Head', 'BucketBand', V(1.54, 0.1, 1.32), V(0, HT + 0.0, 0.02), suit)
	glasses(W, 'shades', K.ink, K.ink)
	face(W, s, s.Expression, { noEyes = true })
	-- A stack of cash in the left hand.
	W:box('LeftHand', 'CashStack', V(0.5, 0.36, 0.92), V(-1.56, 1.98, -0.45), K.cash)
	W:box('LeftHand', 'CashBand', V(0.52, 0.38, 0.16), V(-1.56, 1.98, -0.45), K.gold, { mat = 'gold' })
	W:box('LeftHand', 'CashEdge', V(0.46, 0.05, 0.9), V(-1.56, 2.17, -0.45), K.cashDark)
end

-- 6. Crook: black leather biker jacket (asymmetric zip, wide collar, silver studs, a red winged-wheel patch and
-- a stud row on the back), red tee, red bandana tied round the head, a boombox riding the left shoulder.
function Looks.Crook(W, s)
	local leather, red, box = s.Color, s.Accent, s.Trim or K.silver
	local hide = leather:Lerp(K.white, 0.08)
	W:paint({ Head = s.Skin, UpperTorso = leather, LowerTorso = leather, UpperArm = leather, LowerArm = leather, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	W:box('UpperTorso', 'Tee', V(0.5, 0.7, 0.04), V(-0.18, 3.6, FZ(1)), red)
	-- Wide collar lapels and the slanted zip; epaulettes and studs ride the upper arms.
	sides(function(sx, side)
		W:box('UpperTorso', 'BikerLapel', V(0.4, 0.62, 0.05), V(sx * 0.42, 3.68, FZ(2)), hide, { mat = 'shiny', rot = ANG(0, 0, rad(-sx * 22)) })
		W:box(side .. 'UpperArm', 'Epaulette', V(0.8, 0.08, 0.5), V(sx * 1.5, 4.04, 0), hide, { mat = 'shiny' })
		W:ball(side .. 'UpperArm', 'Stud', 0.1, V(sx * 1.78, 4.09, 0), K.silver, { mat = 'metal' })
		W:box(side .. 'LowerArm', 'ArmZip', V(0.04, 0.5, 0.04), V(sx * 1.5, 2.65, -0.53), K.silver, { mat = 'metal' })
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.14, 1.06, 1.06, hide, { mat = 'shiny' })
		shoe(W, sx, 'boot', K.ink, K.ink, K.silver)
	end)
	W:box('Torso', 'Zip', V(0.06, 1.7, 0.04), V(0.22, 2.95, FZ(2)), K.silver, { mat = 'metal', rot = ANG(0, 0, rad(-8)) })
	band(W, 'LowerTorso', 'JacketBelt', 0, 2.1, 0.2, 2.06, 1.06, hide, { mat = 'shiny' })
	W:box('LowerTorso', 'BeltBuckle', V(0.24, 0.2, 0.04), V(-0.6, 2.1, -0.56), K.silver, { mat = 'metal' })
	for i = 0, 2 do W:ball('UpperTorso', 'CollarStud', 0.08, V(-0.55 + i * 0.12, 3.55 - i * 0.1, FZ(3)), K.silver, { mat = 'metal' }) end
	-- The back: a red winged wheel and a row of silver studs across the yoke.
	W:cyl('UpperTorso', 'BackPatch', 0.04, 0.86, V(0, 3.12, BZ(1)), red, 'z')
	W:cyl('UpperTorso', 'BackPatchRing', 0.04, 0.52, V(0, 3.12, BZ(2)), K.white, 'z')
	W:cyl('UpperTorso', 'BackPatchHub', 0.04, 0.22, V(0, 3.12, BZ(3)), red, 'z')
	sides(function(sx) W:box('UpperTorso', 'BackPatchWing', V(0.5, 0.2, 0.04), V(sx * 0.62, 3.2, BZ(1)), K.white, { rot = ANG(0, 0, rad(sx * 14)) }) end)
	for i = -1, 1 do W:box('UpperTorso', 'BackStud', V(0.12, 0.12, 0.04), V(i * 0.5, 3.84, BZ(1)), K.silver, { mat = 'metal' }) end
	-- Wallet chain on the right hip.
	W:box('LowerTorso', 'WalletChain', V(0.06, 0.06, 0.6), V(0.92, 2.0, -0.2), K.silver, { mat = 'metal', rot = ANG(rad(-30), 0, 0) })
	-- Bandana tied round the head (knot and tails at the side), slick hair, shades.
	hair(W, s, 'slick')
	W:box('Head', 'Bandana', V(1.6, 0.36, 1.36), V(0, HT - 0.06, 0.02), red)
	W:box('Head', 'BandanaKnot', V(0.2, 0.26, 0.3), V(0.86, HT - 0.06, 0.2), red)
	W:box('Head', 'BandanaTail', V(0.06, 0.55, 0.2), V(0.9, HT - 0.4, 0.34), red, { rot = ANG(rad(-20), 0, rad(8)) })
	W:box('Head', 'BandanaTail', V(0.06, 0.45, 0.2), V(0.9, HT - 0.36, 0.08), red, { rot = ANG(rad(15), 0, rad(8)) })
	for i = -2, 2 do W:box('Head', 'BandanaPrint', V(0.08, 0.08, 0.02), V(i * 0.3, HT - 0.06, -0.69), K.white) end
	glasses(W, 'shades', K.ink, C(60, 30, 40))
	face(W, s, s.Expression, { noEyes = true })
	-- Boombox riding the left shoulder (it moves with the arm), speakers to the front.
	local b = V(-1.68, 4.5, 0.02)
	W:box('LeftUpperArm', 'Boombox', V(1.72, 0.96, 0.56), b, box, { mat = 'metal' })
	for _, dx in { -0.5, 0.5 } do
		W:cyl('LeftUpperArm', 'Speaker', 0.06, 0.7, b + V(dx, -0.04, -0.3), K.ink, 'z')
		W:cyl('LeftUpperArm', 'SpeakerCone', 0.06, 0.3, b + V(dx, -0.04, -0.34), red, 'z')
	end
	W:box('LeftUpperArm', 'TapeDeck', V(0.3, 0.36, 0.06), b + V(0, 0.08, -0.3), K.ink)
	W:box('LeftUpperArm', 'BoomboxHandle', V(1.3, 0.12, 0.14), b + V(0, 0.62, 0), K.ink)
	sides(function(sx) W:box('LeftUpperArm', 'HandlePost', V(0.1, 0.18, 0.1), b + V(sx * 0.6, 0.52, 0), K.ink) end)
end

-- 7. Getaway Driver: yellow racing jacket (black stripes, checker panel, a big "7" roundel and a checker band
-- on the back), driving gloves, aviators, a pompadour, a racing helmet in hand.
function Looks.GetawayDriver(W, s)
	local jacket, stripe, helmet = s.Color, s.Accent, s.Trim or C(232, 44, 52)
	W:paint({ Head = s.Skin, UpperTorso = jacket, LowerTorso = jacket, UpperArm = jacket, LowerArm = jacket, Hand = K.ink, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	-- Two racing stripes, shoulder stripes on the arms, a checker block, a high collar, patches.
	sides(function(sx, side)
		W:box('Torso', 'RacingStripe', V(0.14, 1.95, 0.04), V(sx * 0.62, 3.0, FZ(1)), stripe)
		W:box(side .. 'UpperArm', 'ShoulderStripe', V(1.04, 0.05, 0.14), V(sx * 1.5, 4.025, 0), stripe)
		W:box(side .. 'Arm', 'SleeveStripe', V(0.04, 1.62, 0.14), V(sx * 2.02, 3.15, 0), stripe)
		band(W, side .. 'LowerArm', 'Cuff', sx * 1.5, 2.38, 0.14, 1.06, 1.06, stripe)
		W:box(side .. 'Hand', 'GloveKnuckle', V(1.04, 0.1, 1.04), V(sx * 1.5, 2.26, 0), helmet)
		shoe(W, sx, 'boot', K.ink, K.ink, jacket)
	end)
	for i = 0, 3 do
		for j = 0, 1 do
			W:box('UpperTorso', 'Checker', V(0.16, 0.16, 0.04), V(-0.12 + (i % 2 == j and 0 or 0.16) - 0.16, 3.6 - i * 0.16, FZ(1)), (i + j) % 2 == 0 and K.ink or K.white)
		end
	end
	W:box('UpperTorso', 'Patch', V(0.42, 0.24, 0.04), V(0.28, 3.45, FZ(1)), helmet)
	W:box('UpperTorso', 'PatchText', V(0.3, 0.06, 0.02), V(0.28, 3.45, FZ(1) - 0.03), K.white)
	W:box('UpperTorso', 'HighCollar', V(1.1, 0.22, 1.0), V(0, 4.08, 0.02), stripe)
	W:box('Torso', 'Zip', V(0.05, 1.95, 0.04), V(0, 3.0, FZ(1)), K.ink)
	band(W, 'LowerTorso', 'Waistband', 0, 2.08, 0.16, 2.04, 1.04, stripe)
	-- The back: a white roundel with a black 7 and a checker band above the waist.
	W:cyl('UpperTorso', 'Roundel', 0.04, 1.12, V(0, 3.3, BZ(1)), K.white, 'z')
	print7(W, 'UpperTorso', '7', 0, 3.3, BZ(2), 0.72, 0.46, 0.16, K.ink, 'RoundelNumber')
	for i = 0, 5 do W:box('UpperTorso', 'BackChecker', V(0.3, 0.2, 0.04), V(-0.83 + i * 0.332, 2.56, BZ(1)), i % 2 == 0 and K.ink or K.white) end
	-- Gold watch.
	band(W, 'LeftLowerArm', 'Watch', -1.5, 2.5, 0.1, 1.08, 1.08, K.gold, { mat = 'gold' })
	hair(W, s, 'pompadour')
	glasses(W, 'aviators', K.gold, C(40, 170, 200))
	face(W, s, s.Expression, { noEyes = true })
	-- Racing helmet held by the chin bar: shell, visor, stripe.
	local h = V(-1.68, 1.5, -0.2)
	W:box('LeftHand', 'Helmet', V(1.2, 1.15, 1.25), h, helmet, { mat = 'shiny' })
	W:box('LeftHand', 'HelmetTop', V(1.0, 0.18, 1.05), h + V(0, 0.66, 0), helmet, { mat = 'shiny' })
	W:cyl('LeftHand', 'Stud', 0.08, 0.34, h + V(0, 0.79, 0), helmet, 'y', { mat = 'shiny' })
	W:box('LeftHand', 'HelmetStripe', V(0.26, 1.36, 1.28), h + V(0, 0.08, 0), K.white)
	W:box('LeftHand', 'Visor', V(0.9, 0.42, 0.06), h + V(0, 0.1, -0.64), K.ink, { mat = 'shiny' })
end

-- 8. Enforcer: red leather sleeveless vest with gold studs over a white tank top, a black-and-red flat cap,
-- big arms with tattoos, beard and shades, a shoulder holster, a heavy gold rope chain, gold rings.
function Looks.Enforcer(W, s)
	local vest, tank, holster = s.Color, s.Accent, s.Trim or K.brown
	local vestDark = vest:Lerp(K.ink, 0.3)
	W:paint({ Head = s.Skin, UpperTorso = tank, LowerTorso = s.Pants, UpperArm = s.Skin, LowerArm = s.Skin, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	-- The vest: two front panels, a back panel, shoulder straps; gold studs down the front edges and a gold
	-- diamond of studs on the back.
	sides(function(sx, side)
		W:box('Torso', 'VestFront', V(0.66, 1.9, 1.08), V(sx * 0.69, 3.02, 0), vest, { mat = 'shiny' })
		W:box('UpperTorso', 'VestStrap', V(0.5, 0.1, 1.08), V(sx * 0.6, 4.02, 0), vest, { mat = 'shiny' })
		for i = 0, 2 do W:box('UpperTorso', 'VestStud', V(0.08, 0.08, 0.04), V(sx * 0.42, 3.6 - i * 0.42, -0.565), K.gold, { mat = 'gold' }) end
		-- Big arms: a bicep block, a tattoo band and a star, gold rings.
		W:box(side .. 'UpperArm', 'Bicep', V(1.14, 0.62, 1.1), V(sx * 1.52, 3.48, 0), s.Skin)
		band(W, side .. 'UpperArm', 'Tattoo', sx * 1.52, 3.66, 0.1, 1.15, 1.12, C(40, 60, 110))
		W:box(side .. 'UpperArm', 'TattooStar', V(0.04, 0.2, 0.2), V(sx * 2.1, 3.38, 0), C(40, 60, 110), { rot = ANG(rad(45), 0, 0) })
		band(W, side .. 'Hand', 'Ring', sx * 1.5, 2.2, 0.08, 1.04, 1.04, K.gold, { mat = 'gold' })
		shoe(W, sx, 'boot', K.ink, K.ink, K.ink)
	end)
	W:box('Torso', 'VestBack', V(0.8, 1.9, 0.06), V(0, 3.02, BZ(1)), vest, { mat = 'shiny' })
	for _, p in { { 0, 0.3 }, { -0.2, 0 }, { 0.2, 0 }, { 0, -0.3 }, { 0, 0 } } do
		W:box('UpperTorso', 'BackStud', V(0.14, 0.14, 0.04), V(p[1] * 2.2, 3.3 + p[2], BZ(2)), K.gold, { mat = 'gold', rot = ANG(0, 0, math.pi / 4) })
	end
	band(W, 'LowerTorso', 'Belt', 0, 2.3, 0.16, 2.04, 1.04, K.ink)
	W:box('LowerTorso', 'BeltBuckle', V(0.3, 0.2, 0.04), V(0, 2.3, -0.54), K.gold, { mat = 'gold' })
	-- Shoulder holster: harness strap and a holster under the left arm with a grip.
	W:box('UpperTorso', 'HarnessStrap', V(0.14, 1.5, 0.04), V(-0.66, 3.3, -0.57), holster, { rot = ANG(0, 0, rad(-12)) })
	W:box('UpperTorso', 'Holster', V(0.3, 0.7, 0.42), V(-1.13, 3.0, -0.18), holster)
	W:box('UpperTorso', 'HolsterGrip', V(0.22, 0.32, 0.22), V(-1.13, 3.42, -0.3), K.ink, { rot = ANG(rad(-20), 0, 0) })
	-- Heavy gold rope chain with a padlock pendant.
	chain(W, 'GoldRope', 4.0, 0.95, 0.16, K.gold, 3, function(y, z)
		W:box('UpperTorso', 'LockPendant', V(0.4, 0.36, 0.06), V(0, y, z), K.gold, { mat = 'gold' })
		W:box('UpperTorso', 'LockShackle', V(0.26, 0.18, 0.05), V(0, y + 0.24, z), K.gold, { mat = 'gold' })
	end)
	-- Flat cap (black wool, red band, a short peak), full beard, shades, an earpiece.
	W:box('Head', 'FlatCap', V(1.62, 0.3, 1.44), V(0, HT + 0.1, 0.05), vestDark:Lerp(K.ink, 0.6))
	W:box('Head', 'FlatCapBand', V(1.64, 0.1, 1.46), V(0, HT - 0.0, 0.05), vest)
	W:wedge('Head', 'FlatCapPeak', V(1.4, 0.16, 0.5), V(0, HT + 0.02, -0.88), vestDark:Lerp(K.ink, 0.6))
	W:cyl('Head', 'Stud', 0.08, 0.24, V(0, HT + 0.29, 0.05), vest, 'y')
	hair(W, s, 'hatted')
	local beard = s.Hair
	W:box('Head', 'Beard', V(1.3, 0.5, 0.2), V(0, HC - 0.48, -0.6), beard)
	W:box('Head', 'BeardChin', V(0.9, 0.24, 0.5), V(0, HC - 0.78, -0.42), beard)
	sides(function(sx) W:box('Head', 'BeardSide', V(0.1, 0.8, 0.6), V(sx * 0.77, HC - 0.2, -0.18), beard) end)
	W:box('Head', 'Moustache', V(0.7, 0.14, 0.08), V(0, HC - 0.2, -0.7), beard, { face = true })
	glasses(W, 'shades', K.ink, K.ink)
	W:box('Head', 'Earpiece', V(0.1, 0.16, 0.14), V(0.8, HC + 0.0, 0.0), K.ink)
	face(W, s, s.Expression, { noEyes = true, noMouth = true })
	W:box('Head', 'Mouth', V(0.36, 0.06, 0.04), V(0, HC - 0.36, -0.73), K.ink, { face = true })
end

-- 9. OG: long emerald coat with a white fur collar and cuffs and varsity "OG" letters on the back, burgundy
-- turtleneck and kangol, round gold shades, two gold chains and a gold microphone pendant, gold rings.
function Looks.StreetBoss(W, s)
	local coat, fur, kangol = s.Color, s.Accent, s.Trim or K.white
	local turtle = s.Shirt or C(150, 30, 60)
	W:paint({ Head = s.Skin, UpperTorso = turtle, LowerTorso = turtle, UpperArm = coat, LowerArm = coat, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	-- Long open coat: front panels down to the knees, sides and back.
	sides(function(sx, side)
		W:box('Torso', 'CoatFront', V(0.66, 2.0, 1.08), V(sx * 0.69, 3.0, 0), coat)
		W:box('LowerTorso', 'CoatSkirt', V(0.74, 1.3, 0.12), V(sx * 0.66, 1.38, -0.56), coat)
		W:box('LowerTorso', 'CoatSkirtSide', V(0.12, 1.3, 1.1), V(sx * 1.04, 1.38, 0), coat)
		W:box('LowerTorso', 'CoatHem', V(0.78, 0.14, 0.16), V(sx * 0.66, 0.78, -0.58), fur)
		band(W, side .. 'LowerArm', 'FurCuff', sx * 1.5, 2.48, 0.4, 1.24, 1.24, fur)
		W:box(side .. 'Hand', 'Ring', V(1.04, 0.08, 1.04), V(sx * 1.5, 2.2, 0), K.gold, { mat = 'gold' })
		shoe(W, sx, 'dress', K.ink, K.ink)
		-- Fur shawl collar: a thick roll over each shoulder and down each lapel, a tufted outer edge.
		W:box('UpperTorso', 'FurShoulder', V(0.95, 0.42, 1.3), V(sx * 0.55, 4.08, 0.02), fur)
		W:box('Torso', 'FurLapel', V(0.4, 1.55, 0.28), V(sx * 0.42, 3.22, -0.6), fur, { rot = ANG(0, 0, rad(-sx * 7)) })
		for i = 0, 2 do
			W:box('Torso', 'FurTuft', V(0.16, 0.34, 0.2), V(sx * (0.68 - i * 0.05), 3.62 - i * 0.48, -0.62), fur)
		end
	end)
	W:box('LowerTorso', 'CoatBack', V(2.12, 1.3, 0.12), V(0, 1.38, 0.56), coat)
	W:box('LowerTorso', 'CoatBackHem', V(2.16, 0.14, 0.16), V(0, 0.78, 0.58), fur)
	backVent(W, 'LowerTorso', 0.85, 1.9, 0.635, coat:Lerp(K.ink, 0.4))
	W:box('Torso', 'CoatBackUpper', V(0.8, 1.9, 0.06), V(0, 3.0, BZ(1)), coat)
	-- Varsity letters on the back in fur white with a gold outline bar.
	print7(W, 'UpperTorso', 'OG', 0, 3.2, BZ(2), 0.78, 0.5, 0.16, fur, 'VarsityLetter')
	W:box('UpperTorso', 'VarsityBar', V(1.5, 0.08, 0.04), V(0, 2.68, BZ(2)), K.gold, { mat = 'gold' })
	W:box('UpperTorso', 'FurCollar', V(2.0, 0.6, 0.5), V(0, 4.12, 0.46), fur)
	W:box('UpperTorso', 'Turtleneck', V(0.9, 0.24, 0.8), V(0, 4.06, 0), turtle)
	-- Two gold chains, the long one with a gold microphone.
	chain(W, 'GoldChain', 3.98, 0.7, 0.08, K.gold, 2)
	chain(W, 'GoldChainLong', 4.0, 1.1, 0.12, K.gold, 3, function(y, z)
		W:box('UpperTorso', 'MicHandle', V(0.14, 0.36, 0.14), V(0, y - 0.1, z), K.gold, { mat = 'gold' })
		W:ball('UpperTorso', 'MicHead', 0.3, V(0, y + 0.18, z), K.gold, { mat = 'gold' })
		W:box('UpperTorso', 'MicBand', V(0.31, 0.06, 0.31), V(0, y + 0.12, z), K.ink)
	end)
	-- Kangol: brim, round crown, a stud and a gold logo; round gold shades.
	hair(W, s, 'hatted')
	W:cyl('Head', 'KangolBrim', 0.12, 2.0, V(0, HT - 0.02, 0.0), kangol, 'y', { mat = 'knit' })
	W:cyl('Head', 'Kangol', 0.52, 1.66, V(0, HT + 0.27, 0.0), kangol, 'y', { mat = 'knit' })
	W:cyl('Head', 'KangolTop', 0.12, 1.36, V(0, HT + 0.58, 0.0), kangol, 'y', { mat = 'knit' })
	W:cyl('Head', 'Stud', 0.08, 0.26, V(0, HT + 0.68, 0), kangol, 'y')
	W:box('Head', 'KangolLogo', V(0.04, 0.16, 0.22), V(-0.84, HT + 0.27, -0.1), K.gold, { mat = 'gold' })
	glasses(W, 'round', K.gold, C(60, 20, 30))
	face(W, s, s.Expression, { noEyes = true })
	W:box('Head', 'Goatee', V(0.3, 0.22, 0.08), V(0, HC - 0.5, -0.66), s.Hair, { face = true })
end

-- 10. Shot Caller: royal blue zoot suit (white pinstripes, padded shoulders on the arms, long jacket with a
-- half-belt at the back), wide-brim white hat with a red feather, a long gold watch chain, spectator shoes,
-- a violin case.
function Looks.Gangster(W, s)
	local suit, hat, red = s.Color, s.Accent, s.Trim or K.red
	local stripe = suit:Lerp(K.white, 0.55)
	W:paint({ Head = s.Skin, UpperTorso = suit, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = s.Skin, UpperLeg = suit, LowerLeg = suit, Foot = K.white })
	suitFront(W, s, { shirt = K.white, tie = true, tieColor = red, pocketSquare = K.white, buttons = { 2.62 }, lapel = suit:Lerp(K.white, 0.12) })
	-- Padded shoulders (on the arms, so they lift with them) and the long drape jacket, pinstripes.
	sides(function(sx, side)
		W:box(side .. 'UpperArm', 'ShoulderPad', V(1.2, 0.28, 1.14), V(sx * 1.55, 3.99, 0), suit)
		W:box('LowerTorso', 'JacketSkirt', V(1.04, 1.0, 1.1), V(sx * 0.5, 1.75, 0), suit)
		band(W, side .. 'LowerArm', 'ShirtCuff', sx * 1.5, 2.36, 0.1, 1.04, 1.04, K.white)
		band(W, side .. 'LowerLeg', 'PegCuff', sx * 0.5, 0.36, 0.12, 0.96, 0.96, suit:Lerp(K.ink, 0.3))
		shoe(W, sx, 'spectator', K.white, K.ink, K.ink)
	end)
	pinstripes(W, 'UpperTorso', -0.85, -0.55, 3.2, 1.6, FZ(1), stripe, 0.3)
	pinstripes(W, 'UpperTorso', 0.55, 0.85, 3.2, 1.6, FZ(1), stripe, 0.3)
	sides(function(sx) W:box('LowerTorso', 'Pinstripe', V(0.03, 0.98, 0.02), V(sx * 0.7, 1.75, -0.565), stripe) end)
	-- The back: pinstripes, a half-belt with gold buttons, a centre vent.
	pinstripes(W, 'UpperTorso', -0.75, 0.75, 3.2, 1.6, BZ(1) - 0.01, stripe, 0.5)
	halfBelt(W, 2.2, 0.57, suit:Lerp(K.ink, 0.2), K.gold)
	backVent(W, 'LowerTorso', 1.25, 2.1, 0.565, suit:Lerp(K.ink, 0.45))
	-- Long gold watch chain looping from the belt to the knee and back.
	W:box('LowerTorso', 'WatchChain', V(0.06, 1.25, 0.06), V(0.86, 1.62, -0.6), K.gold, { mat = 'gold', rot = ANG(0, 0, rad(4)) })
	W:box('LowerTorso', 'WatchChain', V(0.06, 1.1, 0.06), V(1.06, 1.55, -0.3), K.gold, { mat = 'gold', rot = ANG(rad(-14), 0, 0) })
	W:box('LowerTorso', 'WatchChainLoop', V(0.06, 0.06, 0.36), V(1.02, 1.0, -0.47), K.gold, { mat = 'gold' })
	-- Wide-brim hat with a band and a feather.
	hair(W, s, 'hatted')
	W:box('Head', 'HatBrim', V(2.5, 0.08, 2.1), V(0, HT + 0.0, 0.02), hat)
	W:box('Head', 'HatCrown', V(1.5, 0.6, 1.26), V(0, HT + 0.33, 0.04), hat)
	W:box('Head', 'HatPinch', V(0.5, 0.12, 0.7), V(0, HT + 0.62, -0.1), hat:Lerp(K.ink, 0.12))
	W:box('Head', 'HatBand', V(1.52, 0.16, 1.28), V(0, HT + 0.12, 0.04), suit)
	W:box('Head', 'Feather', V(0.08, 0.95, 0.22), V(0.76, HT + 0.5, 0.3), red, { rot = ANG(rad(-25), 0, rad(-25)) })
	W:box('Head', 'FeatherTip', V(0.06, 0.4, 0.16), V(0.95, HT + 0.92, 0.5), red:Lerp(K.white, 0.3), { rot = ANG(rad(-35), 0, rad(-40)) })
	face(W, s, s.Expression)
	-- Violin case in the left hand, turned so its lid faces forward: body, waist, handle, gold clasps.
	local turn = ANG(0, rad(-32), 0)
	local v = V(-1.78, 1.3, -0.15)
	W:box('LeftHand', 'ViolinCase', V(0.42, 1.8, 0.8), v, K.ink, { mat = 'shiny', rot = turn })
	W:box('LeftHand', 'ViolinCaseBody', V(0.44, 0.8, 1.0), v + turn * V(0, -0.38, 0), K.ink, { mat = 'shiny', rot = turn })
	W:box('LeftHand', 'ViolinHandle', V(0.1, 0.12, 0.4), v + turn * V(0, 0.95, 0), K.gold, { mat = 'gold', rot = turn })
	W:box('LeftHand', 'ViolinLid', V(0.04, 1.6, 0.6), v + turn * V(-0.23, 0.05, 0), suit:Lerp(K.ink, 0.5), { rot = turn })
	W:box('LeftHand', 'ViolinClasp', V(0.06, 0.14, 0.2), v + turn * V(-0.26, 0.3, 0), K.gold, { mat = 'gold', rot = turn })
	W:box('LeftHand', 'ViolinClasp', V(0.06, 0.14, 0.2), v + turn * V(-0.27, -0.5, 0), K.gold, { mat = 'gold', rot = turn })
end

-- 11. Capo: silver sharkskin suit (charcoal satin lapels, black shirt, red tie and pocket square), black
-- fedora with a red band, gold tie clip, cufflinks and watch, a gold briefcase.
function Looks.Capo(W, s)
	local suit, red, hat = s.Color, s.Accent, s.Trim or K.ink
	local lapel = C(58, 62, 74)
	W:paint({ Head = s.Skin, UpperTorso = suit, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = s.Skin, UpperLeg = suit, LowerLeg = suit, Foot = K.ink })
	suitFront(W, s, { shirt = K.ink, collar = K.ink, tie = true, tieColor = red, pocketSquare = red, buttons = { 2.75 }, vWidth = 0.62, lapel = lapel, lapelMat = 'shiny', buttonColor = lapel })
	W:box('UpperTorso', 'TieClip', V(0.26, 0.05, 0.03), V(0, 3.4, FZ(3) - 0.035), K.gold, { mat = 'gold' })
	sides(function(sx, side)
		W:box('LowerTorso', 'JacketSkirt', V(1.04, 0.5, 1.08), V(sx * 0.5, 1.95, 0), suit, { mat = 'shiny' })
		W:box(side .. 'Leg', 'Crease', V(0.03, 1.5, 0.03), V(sx * 0.5, 1.05, -0.515), suit:Lerp(K.white, 0.5))
		band(W, side .. 'LowerArm', 'ShirtCuff', sx * 1.5, 2.36, 0.1, 1.04, 1.04, K.white)
		W:box(side .. 'LowerArm', 'Cufflink', V(0.12, 0.12, 0.04), V(sx * 1.5, 2.36, -0.54), K.gold, { mat = 'gold' })
		shoe(W, sx, 'dress', K.ink, K.ink)
	end)
	band(W, 'LeftLowerArm', 'Watch', -1.5, 2.5, 0.1, 1.08, 1.08, K.gold, { mat = 'gold' })
	-- Sharkskin sheen: a few lighter stripes; the back has a centre vent and charcoal pinstripes.
	pinstripes(W, 'UpperTorso', -0.85, -0.55, 3.2, 1.6, FZ(1), suit:Lerp(K.white, 0.45), 0.3)
	pinstripes(W, 'UpperTorso', 0.55, 0.85, 3.2, 1.6, FZ(1), suit:Lerp(K.white, 0.45), 0.3)
	for _, x in { -0.75, -0.25, 0.25, 0.75 } do W:box('UpperTorso', 'BackStripe', V(0.06, 1.3, 0.03), V(x, 3.3, BZ(1) - 0.01), lapel) end
	halfBelt(W, 2.22, 0.57, lapel, K.gold)
	backVent(W, 'LowerTorso', 1.72, 2.1, 0.555, lapel)
	W:box('UpperTorso', 'BackCollar', V(1.2, 0.16, 0.04), V(0, 3.92, BZ(1)), lapel)
	-- Black fedora with a red band.
	hair(W, s, 'hatted')
	W:box('Head', 'FedoraBrim', V(2.0, 0.08, 1.74), V(0, HT + 0.0, 0.02), hat, { rot = ANG(rad(-5), 0, 0) })
	W:box('Head', 'FedoraCrown', V(1.42, 0.54, 1.2), V(0, HT + 0.31, 0.06), hat)
	W:wedge('Head', 'FedoraPinch', V(1.0, 0.16, 0.5), V(0, HT + 0.62, -0.24), hat:Lerp(K.white, 0.12))
	W:box('Head', 'FedoraBand', V(1.44, 0.16, 1.22), V(0, HT + 0.12, 0.06), red)
	face(W, s, s.Expression)
	-- Gold briefcase turned so its face shows, black handle and seam, a lock.
	local turn = ANG(0, rad(-30), 0)
	local b = V(-1.8, 1.35, -0.1)
	W:box('LeftHand', 'Briefcase', V(0.4, 1.1, 1.5), b, K.gold, { mat = 'gold', rot = turn })
	W:box('LeftHand', 'BriefcaseSeam', V(0.42, 0.06, 1.52), b + turn * V(0, 0.3, 0), K.goldDark, { mat = 'gold', rot = turn })
	W:box('LeftHand', 'BriefcaseHandle', V(0.12, 0.14, 0.5), b + turn * V(0, 0.62, 0), K.ink, { rot = turn })
	W:box('LeftHand', 'BriefcaseLock', V(0.06, 0.18, 0.26), b + turn * V(-0.22, 0.2, 0), K.ink, { rot = turn })
	W:box('LeftHand', 'BriefcaseMark', V(0.04, 0.3, 0.3), b + turn * V(-0.21, -0.18, 0), K.white, { rot = turn * ANG(rad(45), 0, 0) })
end

-- 12. Consigliere: wine double-breasted suit with gold buttons and gold-piped lapels, gold bow tie, a black
-- homburg with a gold band over silver hair, round gold specs, a pocket watch, a ledger with its pages out.
function Looks.Consigliere(W, s)
	local suit, gold, ledger = s.Color, K.gold, s.Trim or C(110, 66, 40)
	W:paint({ Head = s.Skin, UpperTorso = suit, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	suitFront(W, s, { shirt = s.Shirt or C(255, 240, 210), tie = 'bow', tieColor = gold, buttons = {}, vWidth = 0.4, lapel = suit:Lerp(K.ink, 0.25), lapelMat = 'shiny' })
	sides(function(sx) W:box('UpperTorso', 'LapelPiping', V(0.04, 0.92, 0.03), V(sx * 0.32, 3.5, FZ(2) - 0.03), gold, { mat = 'gold', rot = ANG(0, 0, rad(-sx * 16)) }) end)
	-- Double-breasted front: overlap panel and six gold buttons.
	W:box('UpperTorso', 'DoubleBreast', V(0.9, 0.88, 0.04), V(0.15, 2.86, FZ(1) - 0.012), suit:Lerp(K.white, 0.06))
	for _, x in { -0.18, 0.42 } do
		for _, y in { 3.0, 2.72, 2.44 } do W:box('Torso', 'Button', V(0.12, 0.12, 0.04), V(x, y, FZ(2)), gold, { mat = 'gold' }) end
	end
	sides(function(sx, side)
		W:box('LowerTorso', 'JacketSkirt', V(1.04, 0.55, 1.08), V(sx * 0.5, 1.92, 0), suit)
		band(W, side .. 'LowerArm', 'ShirtCuff', sx * 1.5, 2.36, 0.1, 1.04, 1.04, s.Shirt or C(255, 240, 210))
		band(W, side .. 'LowerArm', 'GoldCuffBand', sx * 1.5, 2.48, 0.06, 1.05, 1.05, gold, { mat = 'gold' })
		shoe(W, sx, 'dress', C(90, 40, 30), K.ink)
	end)
	-- The back: a centre vent and two gold buttons at the waist.
	backVent(W, 'LowerTorso', 1.66, 2.2, 0.555, suit:Lerp(K.ink, 0.45))
	sides(function(sx) W:box('LowerTorso', 'BackButton', V(0.18, 0.18, 0.04), V(sx * 0.34, 2.25, BZ(1)), gold, { mat = 'gold' }) end)
	W:box('UpperTorso', 'BackSeam', V(0.05, 1.2, 0.03), V(0, 3.0, BZ(1) - 0.005), suit:Lerp(K.ink, 0.35))
	W:box('UpperTorso', 'BackYoke', V(1.96, 0.08, 0.04), V(0, 3.66, BZ(1)), gold, { mat = 'gold' })
	-- Pocket watch chain across the waistcoat.
	W:box('LowerTorso', 'WatchChain', V(0.8, 0.05, 0.04), V(-0.45, 2.3, FZ(2)), gold, { mat = 'gold', rot = ANG(0, 0, rad(-12)) })
	W:cyl('LowerTorso', 'PocketWatch', 0.06, 0.3, V(-0.82, 2.18, FZ(2)), gold, 'z', { mat = 'gold' })
	-- Homburg: rolled brim, tall creased crown, gold band; silver hair under it, a neat beard, gold specs.
	hair(W, s, 'hatted')
	W:box('Head', 'HomburgBrim', V(1.9, 0.1, 1.66), V(0, HT + 0.0, 0.03), K.ink)
	sides(function(sx) W:box('Head', 'HomburgRoll', V(0.12, 0.16, 1.66), V(sx * 0.92, HT + 0.08, 0.03), K.ink) end)
	W:box('Head', 'HomburgCrown', V(1.4, 0.66, 1.18), V(0, HT + 0.38, 0.05), K.ink)
	W:box('Head', 'HomburgCrease', V(0.1, 0.1, 0.9), V(0, HT + 0.72, 0.05), C(60, 60, 70))
	W:box('Head', 'HomburgBand', V(1.42, 0.16, 1.2), V(0, HT + 0.14, 0.05), gold, { mat = 'gold' })
	W:box('Head', 'Beard', V(0.8, 0.26, 0.12), V(0, HC - 0.6, -0.62), s.Hair)
	W:box('Head', 'Moustache', V(0.56, 0.1, 0.08), V(0, HC - 0.22, -0.68), s.Hair, { face = true })
	glasses(W, 'round', gold, C(200, 230, 255))
	face(W, s, s.Expression, { noMouth = true })
	W:box('Head', 'Mouth', V(0.28, 0.06, 0.04), V(0, HC - 0.34, -0.66), K.ink, { face = true })
	-- Ledger in the left hand, fore-edge forward: two leather covers, a thick cream page block showing at
	-- the front and the top, a red ribbon, gold corners at the bottom.
	local turn = ANG(0, rad(-20), 0)
	local l = V(-1.74, 1.62, -0.25)
	W:box('LeftHand', 'LedgerPages', V(0.44, 1.02, 0.86), l + turn * V(0, -0.02, -0.02), C(250, 240, 210), { rot = turn })
	sides(function(sx) W:box('LeftHand', 'LedgerCover', V(0.07, 1.12, 0.94), l + turn * V(sx * 0.255, 0, 0), ledger, { mat = 'shiny', rot = turn }) end)
	W:box('LeftHand', 'LedgerSpine', V(0.58, 1.12, 0.1), l + turn * V(0, 0, 0.47), ledger, { mat = 'shiny', rot = turn })
	W:box('LeftHand', 'LedgerRibbon', V(0.06, 0.4, 0.04), l + turn * V(0.05, -0.6, -0.3), C(200, 30, 50), { rot = turn })
	sides(function(sx) W:box('LeftHand', 'LedgerCorner', V(0.08, 0.18, 0.18), l + turn * V(sx * 0.27, -0.48, -0.4), gold, { mat = 'gold', rot = turn }) end)
end

-- 13. Underboss: black suit, black shirt, white tie and gold tie bar, a long camel overcoat over the
-- shoulders (tapered back with a vent and a buttoned half-belt, empty sleeves hanging outside the arms, collar
-- turned up), camel fedora, black gloves, a black cane with a gold knob.
function Looks.Underboss(W, s)
	local suit, coat, tie = s.Color, s.Accent, s.Trim or K.white
	local light = coat:Lerp(K.white, 0.25)
	local dark = coat:Lerp(K.ink, 0.25)
	W:paint({ Head = s.Skin, UpperTorso = suit, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = K.ink, UpperLeg = suit, LowerLeg = suit, Foot = K.ink })
	suitFront(W, s, { shirt = K.ink, collar = K.ink, tie = true, tieColor = tie, buttons = { 2.75 }, vWidth = 0.56, lapel = suit:Lerp(K.white, 0.08), lapelMat = 'shiny' })
	W:box('UpperTorso', 'TieBar', V(0.26, 0.06, 0.03), V(0, 3.45, FZ(3) - 0.035), K.gold, { mat = 'gold' })
	-- The coat: the yoke over the torso, shoulder caps on the arms, a tapered back (wide upper, narrower
	-- skirt), front edges with wide lapels, empty sleeves hanging outside the arms, the collar up.
	W:box('UpperTorso', 'CoatYoke', V(2.12, 0.3, 1.36), V(0, 4.02, 0.06), coat)
	W:box('UpperTorso', 'CoatBackUpper', V(3.1, 1.5, 0.14), V(0, 3.35, 0.74), coat)
	W:box('UpperTorso', 'CoatBackLower', V(2.5, 1.9, 0.14), V(0, 1.75, 0.74), coat)
	sides(function(sx, side)
		W:box(side .. 'UpperArm', 'CoatShoulder', V(1.16, 0.3, 1.36), V(sx * 1.55, 4.02, 0.06), coat)
		W:box('Torso', 'CoatFront', V(0.34, 3.2, 0.12), V(sx * 0.86, 2.45, -0.62), coat)
		W:box('UpperTorso', 'CoatLapel', V(0.3, 1.0, 0.06), V(sx * 0.7, 3.55, -0.7), dark, { rot = ANG(0, 0, rad(sx * 12)) })
		W:box('UpperTorso', 'CoatButton', V(0.12, 0.12, 0.04), V(sx * 0.86, 2.75, -0.7), K.ink)
		W:box(side .. 'UpperArm', 'CoatSleeve', V(0.26, 1.7, 0.8), V(sx * 2.15, 3.12, 0.12), coat)
		W:box(side .. 'UpperArm', 'CoatSleeveCuff', V(0.28, 0.2, 0.82), V(sx * 2.15, 2.35, 0.12), dark)
		band(W, side .. 'LowerArm', 'ShirtCuff', sx * 1.5, 2.36, 0.1, 1.04, 1.04, K.white)
		shoe(W, sx, 'dress', K.ink, K.ink)
	end)
	W:box('UpperTorso', 'CoatCollar', V(2.2, 0.42, 0.3), V(0, 4.26, 0.62), light)
	backVent(W, 'UpperTorso', 0.85, 1.9, 0.82, dark)
	W:box('UpperTorso', 'CoatHalfBelt', V(1.5, 0.22, 0.06), V(0, 2.3, 0.84), dark)
	sides(function(sx) W:box('UpperTorso', 'CoatBeltButton', V(0.14, 0.14, 0.04), V(sx * 0.6, 2.3, 0.88), K.ink) end)
	-- Camel fedora with a black band, shades.
	hair(W, s, 'hatted')
	W:box('Head', 'FedoraBrim', V(2.05, 0.08, 1.78), V(0, HT + 0.0, 0.02), coat, { rot = ANG(rad(-6), 0, 0) })
	W:box('Head', 'FedoraCrown', V(1.44, 0.56, 1.22), V(0, HT + 0.32, 0.06), coat)
	W:wedge('Head', 'FedoraPinch', V(1.0, 0.16, 0.5), V(0, HT + 0.64, -0.24), light)
	W:box('Head', 'FedoraBand', V(1.46, 0.16, 1.24), V(0, HT + 0.13, 0.06), K.ink)
	glasses(W, 'shades', K.ink, K.ink)
	face(W, s, s.Expression, { noEyes = true })
	-- Black cane with a gold knob and tip in the left hand, a gold signet ring on the right.
	local c = V(-1.62, 1.15, -0.32)
	W:cyl('LeftHand', 'Cane', 2.2, 0.14, c, K.ink, 'y', { mat = 'shiny' })
	W:ball('LeftHand', 'CaneKnob', 0.3, c + V(0, 1.15, 0), K.gold, { mat = 'gold' })
	W:box('LeftHand', 'CaneTip', V(0.16, 0.12, 0.16), c + V(0, -1.08, 0), K.gold, { mat = 'gold' })
	W:box('RightHand', 'SignetRing', V(0.18, 0.12, 0.12), V(1.5, 2.12, -0.52), K.gold, { mat = 'gold' })
end

-- 14. The Don: ivory dinner jacket with black satin lapels and a black collar and vent at the back, black bow
-- tie, a red rose, silver hair and moustache, gold rings, and his black cat on his shoulder.
function Looks.TheDon(W, s)
	local jacket, rose, cat = s.Color, s.Accent, s.Trim or K.ink
	W:paint({ Head = s.Skin, UpperTorso = jacket, LowerTorso = jacket, UpperArm = jacket, LowerArm = jacket, Hand = s.Skin, UpperLeg = s.Pants, LowerLeg = s.Pants, Foot = K.ink })
	suitFront(W, s, { shirt = K.white, tie = 'bow', tieColor = K.ink, buttons = { 2.7 }, vWidth = 0.5, lapel = K.ink, lapelMat = 'shiny', buttonColor = K.ink })
	-- Red rose on the lapel.
	W:box('UpperTorso', 'RoseStem', V(0.05, 0.3, 0.04), V(-0.62, 3.42, FZ(3)), C(40, 140, 60), { rot = ANG(0, 0, rad(-15)) })
	W:box('UpperTorso', 'Rose', V(0.24, 0.22, 0.12), V(-0.58, 3.62, FZ(3) - 0.04), rose)
	W:box('UpperTorso', 'RoseTop', V(0.16, 0.12, 0.14), V(-0.58, 3.74, FZ(3) - 0.04), rose:Lerp(K.white, 0.2))
	W:box('UpperTorso', 'RoseLeaf', V(0.16, 0.06, 0.04), V(-0.72, 3.5, FZ(3)), C(40, 140, 60), { rot = ANG(0, 0, rad(30)) })
	sides(function(sx, side)
		W:box('LowerTorso', 'JacketSkirt', V(1.04, 0.5, 1.08), V(sx * 0.5, 1.95, 0), jacket)
		band(W, side .. 'LowerArm', 'ShirtCuff', sx * 1.5, 2.36, 0.1, 1.04, 1.04, K.white)
		W:box(side .. 'Hand', 'Ring', V(1.04, 0.08, 1.04), V(sx * 1.5, 2.2, 0), K.gold, { mat = 'gold' })
		W:box(side .. 'Leg', 'TrouserStripe', V(0.04, 1.75, 0.12), V(sx * 1.02, 1.1, 0), K.ink, { mat = 'shiny' })
		shoe(W, sx, 'dress', K.ink, K.ink)
	end)
	W:box('UpperTorso', 'Cummerbund', V(2.04, 0.3, 1.04), V(0, 2.55, 0), rose:Lerp(K.ink, 0.3))
	-- The back: black satin collar band, a centre seam and vent.
	W:box('UpperTorso', 'BackCollar', V(1.3, 0.2, 0.04), V(0, 3.9, BZ(1)), K.ink, { mat = 'shiny' })
	W:box('UpperTorso', 'BackSeam', V(0.04, 1.0, 0.03), V(0, 3.2, BZ(1) - 0.005), jacket:Lerp(K.ink, 0.3))
	backVent(W, 'LowerTorso', 1.72, 2.2, 0.555, jacket:Lerp(K.ink, 0.35))
	-- Silver hair, big moustache, eyebrows.
	hair(W, s, 'slick')
	W:box('Head', 'Moustache', V(0.8, 0.16, 0.1), V(0, HC - 0.2, -0.68), s.Hair, { face = true })
	sides(function(sx) W:box('Head', 'MoustacheEnd', V(0.2, 0.12, 0.1), V(sx * 0.44, HC - 0.26, -0.68), s.Hair, { face = true, rot = ANG(0, 0, rad(sx * 25)) }) end)
	face(W, s, s.Expression, { noMouth = true })
	-- His black cat, sitting on his left shoulder (it rides the arm): body, head with ears and green eyes, a
	-- red collar with a gold bell, the tail hanging down his back.
	local c = V(-1.42, 4.36, 0.12)
	local arm = 'LeftUpperArm'
	W:box(arm, 'CatBody', V(0.62, 0.62, 0.95), c, cat)
	W:box(arm, 'CatHaunch', V(0.66, 0.4, 0.5), c + V(0, -0.1, 0.25), cat)
	W:box(arm, 'CatHead', V(0.58, 0.5, 0.5), c + V(0, 0.42, -0.4), cat)
	sides(function(sx)
		W:wedge(arm, 'CatEar', V(0.16, 0.2, 0.14), c + V(sx * 0.18, 0.77, -0.45), cat, { rot = ANG(0, math.pi, 0) })
		W:box(arm, 'CatEye', V(0.12, 0.12, 0.03), c + V(sx * 0.13, 0.46, -0.66), C(120, 255, 90), { mat = 'neon' })
	end)
	W:box(arm, 'CatNose', V(0.08, 0.06, 0.03), c + V(0, 0.34, -0.66), C(255, 140, 170))
	W:box(arm, 'CatCollar', V(0.6, 0.08, 0.52), c + V(0, 0.16, -0.4), C(220, 30, 50))
	W:ball(arm, 'CatBell', 0.12, c + V(0, 0.1, -0.68), K.gold, { mat = 'gold' })
	W:box(arm, 'CatTail', V(0.14, 0.9, 0.14), c + V(0.08, -0.55, 0.52), cat, { rot = ANG(rad(-12), 0, rad(-10)) })
end

-- 15. Kingpin: royal purple suit with gold lapels and gold pinstripes, a gold waistcoat, a red royal cape with
-- a gold crown on its back and an ermine collar (rolls on the arms), a jewelled gold crown with glowing tips,
-- a diamond chain, gold rings and a gold sceptre.
function Looks.Kingpin(W, s)
	local suit, gold, cape = s.Color, K.gold, s.Accent
	local ermine = K.white
	W:paint({ Head = s.Skin, UpperTorso = suit, LowerTorso = suit, UpperArm = suit, LowerArm = suit, Hand = s.Skin, UpperLeg = suit, LowerLeg = suit, Foot = K.ink })
	suitFront(W, s, { shirt = K.ink, collar = K.ink, tie = true, tieColor = gold, buttons = {}, vWidth = 0.66, lapel = gold, lapelMat = 'gold' })
	W:box('UpperTorso', 'Waistcoat', V(0.7, 0.55, 0.04), V(0, 2.9, FZ(1) - 0.012), gold, { mat = 'gold' })
	sides(function(sx, side)
		W:box('LowerTorso', 'JacketSkirt', V(1.04, 0.5, 1.08), V(sx * 0.5, 1.95, 0), suit)
		W:box(side .. 'UpperArm', 'ArmStripe', V(0.03, 0.9, 0.03), V(sx * 1.5, 3.4, -0.515), gold)
		band(W, side .. 'LowerArm', 'GoldCuff', sx * 1.5, 2.38, 0.14, 1.06, 1.06, gold, { mat = 'gold' })
		W:box(side .. 'Hand', 'Ring', V(1.04, 0.08, 1.04), V(sx * 1.5, 2.2, 0), gold, { mat = 'gold' })
		shoe(W, sx, 'dress', gold, K.ink)
		W:box('UpperTorso', 'Pinstripe', V(0.03, 1.6, 0.02), V(sx * 0.72, 3.2, FZ(1)), gold)
		-- Ermine rolls on the shoulders ride the arms.
		W:box(side .. 'UpperArm', 'ErmineShoulder', V(1.2, 0.42, 1.4), V(sx * 1.56, 4.08, 0.04), ermine)
		W:box(side .. 'UpperArm', 'ErmineTail', V(0.12, 0.24, 0.04), V(sx * 1.56, 4.08, -0.76), K.ink)
	end)
	-- Royal cape (red velvet, gold lining, a gold crown on the back) and the ermine collar on the torso.
	W:box('UpperTorso', 'Cape', V(3.2, 3.6, 0.14), V(0, 2.25, 0.82), cape)
	W:box('UpperTorso', 'CapeLining', V(3.0, 3.4, 0.04), V(0, 2.3, 0.73), gold, { mat = 'gold' })
	W:box('UpperTorso', 'CapeCrownBand', V(1.0, 0.24, 0.04), V(0, 2.9, 0.91), gold, { mat = 'gold' })
	for i = -1, 1 do W:box('UpperTorso', 'CapeCrownPoint', V(0.22, i == 0 and 0.46 or 0.34, 0.04), V(i * 0.39, 3.1 + (i == 0 and 0.12 or 0.06), 0.91), gold, { mat = 'gold' }) end
	W:box('UpperTorso', 'Ermine', V(2.1, 0.44, 1.46), V(0, 4.12, 0.04), ermine)
	W:box('UpperTorso', 'ErmineBack', V(2.0, 0.5, 0.4), V(0, 4.4, 0.62), ermine)
	sides(function(sx)
		W:box('UpperTorso', 'ErmineLapel', V(0.42, 1.3, 0.26), V(sx * 0.55, 3.4, -0.62), ermine, { rot = ANG(0, 0, rad(-sx * 6)) })
		W:box('UpperTorso', 'ErmineTail', V(0.12, 0.24, 0.04), V(sx * 0.57, 3.15, -0.77), K.ink)
	end)
	-- Diamond chain.
	chain(W, 'GoldChain', 3.98, 0.95, 0.12, gold, 3, function(y, z)
		W:box('UpperTorso', 'Diamond', V(0.4, 0.4, 0.12), V(0, y, z), C(150, 235, 255), { mat = 'glass', rot = ANG(0, 0, math.pi / 4) })
	end)
	-- Crown: gold band, a red velvet cap, points all round with glowing gem tips, gems on the band.
	hair(W, s, 'hatted')
	W:box('Head', 'CrownBand', V(1.66, 0.34, 1.42), V(0, HT + 0.12, 0.02), gold, { mat = 'gold' })
	W:box('Head', 'CrownVelvet', V(1.4, 0.5, 1.16), V(0, HT + 0.4, 0.02), cape)
	for i = -1, 1 do
		W:box('Head', 'CrownPoint', V(0.24, 0.5, 0.08), V(i * 0.6, HT + 0.5, -0.69), gold, { mat = 'gold' })
		W:ball('Head', 'CrownTip', 0.2, V(i * 0.6, HT + 0.8, -0.69), i == 0 and K.ruby or K.sapphire, { mat = 'neon' })
		W:box('Head', 'CrownPoint', V(0.24, 0.5, 0.08), V(i * 0.6, HT + 0.5, 0.73), gold, { mat = 'gold' })
	end
	sides(function(sx)
		W:box('Head', 'CrownPoint', V(0.08, 0.5, 0.24), V(sx * 0.81, HT + 0.5, 0.02), gold, { mat = 'gold' })
		W:ball('Head', 'CrownTip', 0.2, V(sx * 0.81, HT + 0.8, 0.02), K.emerald, { mat = 'neon' })
	end)
	W:box('Head', 'CrownGem', V(0.24, 0.24, 0.06), V(0, HT + 0.12, -0.75), K.ruby, { mat = 'glass', rot = ANG(0, 0, math.pi / 4) })
	face(W, s, s.Expression)
	-- Sceptre in the left hand: gold staff, orb, cross.
	local p = V(-1.66, 1.75, -0.3)
	W:cyl('LeftHand', 'SceptreStaff', 2.2, 0.16, p, gold, 'y', { mat = 'gold' })
	W:ball('LeftHand', 'SceptreOrb', 0.5, p + V(0, 1.25, 0), K.sapphire, { mat = 'glass' })
	W:box('LeftHand', 'SceptreCrossV', V(0.1, 0.36, 0.1), p + V(0, 1.66, 0), gold, { mat = 'gold' })
	W:box('LeftHand', 'SceptreCrossH', V(0.26, 0.1, 0.1), p + V(0, 1.66, 0), gold, { mat = 'gold' })
end

-- The recipe for a look: { pieces, body } (body = rig part -> colour).
function Art.recipe(s)
	local fn = Looks[s.Look or s.Id] or Looks.CornerKid
	local W = newBuilder(s)
	fn(W, s)
	local body = {}
	for seg in Art.Rig do
		local short = seg:gsub('^Left', ''):gsub('^Right', '')
		body[seg] = W.body[seg] or W.body[short] or s.Color
	end
	return { pieces = W.pieces, body = body }
end

---------------------------------------------------------------------------------------------- building
local function makePart(parent, name, size, cf, color, mat, shape, anchored)
	local p
	if shape == 'Wedge' then
		p = Instance.new('WedgePart')
	else
		p = Instance.new('Part')
		if shape == 'Ball' then p.Shape = Enum.PartType.Ball elseif shape == 'Cylinder' then p.Shape = Enum.PartType.Cylinder end
	end
	p.Name = name
	p.Size = V(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.CFrame = cf
	p.Color = color
	p.Material = MAT[mat] or Enum.Material.SmoothPlastic
	p.Reflectance = REFL[mat] or 0
	p.Anchored = anchored
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Scale a part-local CFrame by a per-axis factor (rig part -> real part size), keeping its rotation, and
-- the piece size by the same factor seen along the piece's own axes.
local function scaled(cf, size, f)
	if f == V(1, 1, 1) then return cf, size end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local sx = math.abs(r00) * f.X + math.abs(r10) * f.Y + math.abs(r20) * f.Z
	local sy = math.abs(r01) * f.X + math.abs(r11) * f.Y + math.abs(r21) * f.Z
	local sz = math.abs(r02) * f.X + math.abs(r12) * f.Y + math.abs(r22) * f.Z
	return CFrame.new(x * f.X, y * f.Y, z * f.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22), V(size.X * sx, size.Y * sy, size.Z * sz)
end

-- Pose angles (degrees) per limb: {out, forward, bend, twist}; Head = yaw. Old two-value poses still work.
Art.Poses = {
	stand = {},
	easy = { LeftArm = { 5, 0 }, RightArm = { 5, 0 }, LeftLeg = { 2, 0 }, RightLeg = { 2, 0 } },
	hips = { LeftArm = { 30, -10, 70, 80 }, RightArm = { 30, -10, 70, 80 }, LeftLeg = { 5, 0 }, RightLeg = { 5, 0 } },
	wave = { LeftArm = { 5, 0 }, RightArm = { 150, 8, 20 }, LeftLeg = { 3, 0 }, RightLeg = { 3, 0 }, Head = -8 },
	point = { LeftArm = { 5, 0 }, RightArm = { 75, 25 }, LeftLeg = { 3, 0 }, RightLeg = { 3, 0 }, Head = -15 },
	cheer = { LeftArm = { 155, 6 }, RightArm = { 155, 6 }, LeftLeg = { 6, 0 }, RightLeg = { 6, 0 } },
	swagger = { LeftArm = { 4, 16 }, RightArm = { 4, -12 }, LeftLeg = { 1, 8 }, RightLeg = { 1, -8 }, Head = 12 },
	boss = { LeftArm = { 14, -4 }, RightArm = { 14, -4 }, LeftLeg = { 7, 0 }, RightLeg = { 7, 0 } },
	flex = { LeftArm = { 10, 0 }, RightArm = { 165, 0 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 }, Head = 10 },
	-- Poses for the looks' props (left hand carries the prop; the right stays free for a held gun).
	carry = { LeftArm = { 8, 4, 10 }, RightArm = { 10, -6, 20 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 } },
	peace = { LeftArm = { 8, 4, 10 }, RightArm = { 40, 30, 110, 40 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 }, Head = -8 },
	cross = { LeftArm = { 8, 30, 105, 70 }, RightArm = { 8, 32, 105, 70 }, LeftLeg = { 8, 0 }, RightLeg = { 8, 0 } },
	salute = { LeftArm = { 8, 4, 10 }, RightArm = { 70, 20, 120, 30 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 }, Head = 6 },
	holdCat = { LeftArm = { 4, 32, 70, 30 }, RightArm = { 12, -4, 25 }, LeftLeg = { 4, 0 }, RightLeg = { 4, 0 }, Head = 8 },
	royal = { LeftArm = { 14, 6, 20 }, RightArm = { 16, -4, 12 }, LeftLeg = { 7, 0 }, RightLeg = { 7, 0 }, Head = -6 },
	flexBoth = { LeftArm = { 92, 0, 100, -90 }, RightArm = { 92, 0, 100, -90 }, LeftLeg = { 8, 0 }, RightLeg = { 8, 0 }, Head = 6 },
	boombox = { LeftArm = { 95, 0, 95, -90 }, RightArm = { 8, -6, 15 }, LeftLeg = { 5, 0 }, RightLeg = { 5, 0 }, Head = 10 },
}

-- Rig part CFrames (rig space, scale 1) for a pose.
local function posedRig(pose)
	if type(pose) == 'string' then pose = Art.Poses[pose] end
	pose = pose or {}
	local out = {}
	for seg, r in Art.Rig do out[seg] = CF(r[2]) end
	local function about(p, rot) return CF(p) * rot * CF(-p) end
	local yaw = type(pose.Head) == 'number' and pose.Head or 0
	out.Head = about(JOINT.Neck, ANG(0, rad(yaw), 0)) * out.Head
	for _, limb in { 'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg' } do
		local q = pose[limb]
		if type(q) == 'table' then
			local side = limb:sub(1, 1) == 'L' and -1 or 1
			local arm = limb:find('Arm') ~= nil
			local prefix = side < 0 and 'Left' or 'Right'
			local j1 = arm and JOINT[prefix .. 'Shoulder'] or JOINT[prefix .. 'Hip']
			local j2 = arm and JOINT[prefix .. 'Elbow'] or JOINT[prefix .. 'Knee']
			local upper = about(j1, ANG(0, 0, side * rad(q[1] or 0)) * ANG(rad(q[2] or 0), 0, 0) * ANG(0, side * rad(q[4] or 0), 0))
			local bend = (q[3] or 0) * (arm and 1 or -1)
			local lower = upper * about(j2, ANG(rad(bend), 0, 0))
			local names = arm and { 'UpperArm', 'LowerArm', 'Hand' } or { 'UpperLeg', 'LowerLeg', 'Foot' }
			out[prefix .. names[1]] = upper * out[prefix .. names[1]]
			out[prefix .. names[2]] = lower * out[prefix .. names[2]]
			out[prefix .. names[3]] = lower * out[prefix .. names[3]]
		end
	end
	return out
end

-- The display figure's body: block parts, a rounded block head (core, side slab, four corner cylinders).
local function buildBody(m, at, recipe, k)
	local parts = {}
	for seg, r in Art.Rig do
		local size = r[1]
		if seg:find('LowerArm') or seg:find('LowerLeg') then size = V(0.98, size.Y, 0.98) end
		local cf = at(seg)
		if seg == 'Head' then
			local hs = r[1]
			local rr = 0.22
			local core = makePart(m, 'Head', V(hs.X - 2 * rr, hs.Y, hs.Z) * k, cf, recipe.body.Head, 'cloth', nil, true)
			makePart(m, 'HeadSide', V(hs.X, hs.Y, hs.Z - 2 * rr) * k, cf, recipe.body.Head, 'cloth', nil, true)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					makePart(m, 'HeadCorner', V(hs.Y, 2 * rr, 2 * rr) * k, cf * CF(sx * (hs.X / 2 - rr) * k, 0, sz * (hs.Z / 2 - rr) * k) * AXIS.y, recipe.body.Head, 'cloth', 'Cylinder', true)
				end
			end
			parts[seg] = core
		else
			parts[seg] = makePart(m, seg, size * k, cf, recipe.body[seg], 'cloth', nil, true)
		end
		parts[seg].CastShadow = true
	end
	return parts
end

-- A posed display figure (anchored), feet at cf, facing cf's -Z. scale: 1 = player size.
function Art.posed(parent, cf, s, scale, pose)
	local k = scale or 1
	local recipe = Art.recipe(s)
	local spec = pose == nil and s.Pose or pose
	spec = type(spec) == 'string' and Art.Poses[spec] or spec or {}
	local rig = posedRig(spec)
	local m = Instance.new('Model')
	m.Name = s.Id .. 'Display'
	local function at(seg)
		local c = rig[seg]
		return cf * (c - c.Position + c.Position * k)
	end
	local parts = buildBody(m, at, recipe, k)
	-- Bent elbows and knees get a round joint so the two boxes don't open a gap.
	for limb, q in spec do
		if type(q) == 'table' and (q[3] or 0) ~= 0 then
			local prefix = limb:sub(1, 1) == 'L' and 'Left' or 'Right'
			local arm = limb:find('Arm') ~= nil
			local lower = prefix .. (arm and 'LowerArm' or 'LowerLeg')
			local j = JOINT[prefix .. (arm and 'Elbow' or 'Knee')]
			local world = rig[lower] * CF(Art.Rig[lower][2]):Inverse() * CF(j)
			makePart(m, 'Joint', V(0.96, 0.98, 0.98) * k, cf * (world - world.Position + world.Position * k), recipe.body[lower], 'cloth', 'Cylinder', true)
		end
	end
	for _, pc in recipe.pieces do
		local world = rig[pc.seg] * pc.cf
		local p = makePart(m, pc.name, pc.size * k, cf * (world - world.Position + world.Position * k), pc.color, pc.mat, pc.shape, true)
		if pc.transp then p.Transparency = pc.transp end
	end
	m.PrimaryPart = parts.LowerTorso
	m:SetAttribute('Look', s.Look or s.Id)
	m.Parent = parent
	return m
end

-- Standing figure, arms down (HUD faces and portraits).
function Art.mannequin(parent, cf, s, scale)
	return Art.posed(parent, cf, s, scale, 'stand')
end

-- Real characters --------------------------------------------------------------------------------------
-- The head's visible box: a classic R6 head is a 2x1x1 part with a Head mesh (~1.2 studs round).
local function headBox(head)
	local mesh = head:FindFirstChildOfClass('SpecialMesh')
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		local d = head.Size.Y * mesh.Scale.Y
		return V(d, d, d)
	end
	return head.Size
end

-- What a character wore before its first look, so Art.unequip can give it back: removed instances (and
-- where they were), body part colours and MeshPart textures. Weak keys: a respawned character starts clean.
local stashes = setmetatable({}, { __mode = 'k' })
local function stashFor(character)
	local st = stashes[character]
	if st then return st end
	st = { items = {}, colors = {}, textures = {} }
	stashes[character] = st
	for _, p in character:GetChildren() do
		if p:IsA('BasePart') then st.colors[p] = p.Color end
	end
	return st
end
local function stashAway(st, inst)
	table.insert(st.items, { inst, inst.Parent })
	inst.Parent = nil
end

-- The player's own skin tone: kept on the character the first time (the costume repaints the head).
local function skinTone(character, head)
	local saved = character:GetAttribute('AvatarSkin')
	if typeof(saved) == 'Color3' then return saved end
	local colors = character:FindFirstChildOfClass('BodyColors')
	local tone = colors and colors.HeadColor3 or head.Color
	character:SetAttribute('AvatarSkin', tone)
	return tone
end

-- Dress a character (R15 or R6) in the look, keeping the player's own skin tone: avatar clothing, accessories,
-- the face (decal, dynamic-head FaceControls and SurfaceAppearance) and body textures are put away (see
-- Art.unequip), the body is painted, then every piece is welded to its part. Re-equipping replaces the old
-- costume. Looks with a Glow colour (the top tiers) get one small sparkle emitter.
function Art.equip(character, s)
	local head = character:FindFirstChild('Head')
	if not head then return end
	local st = stashFor(character)
	local old = character:FindFirstChild('BlockCostume')
	if old then old:Destroy() end
	local look = table.clone(s)
	look.Skin = skinTone(character, head)
	for _, v in character:GetChildren() do
		if v:IsA('Accessory') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('ShirtGraphic') or v:IsA('BodyColors') then stashAway(st, v) end
	end
	for _, p in character:GetChildren() do
		if p:IsA('BasePart') and p.Name ~= 'HumanoidRootPart' then
			for _, v in p:GetChildren() do
				if v:IsA('SurfaceAppearance') or v:IsA('FaceControls') or (p == head and v:IsA('Decal')) then stashAway(st, v) end
			end
			-- Textured mesh bodies ignore Color: blank the texture on every part the look paints.
			if p:IsA('MeshPart') and p.TextureID ~= '' then
				if st.textures[p] == nil then st.textures[p] = p.TextureID end
				p.TextureID = ''
			end
		end
	end
	local recipe = Art.recipe(look)
	local r15 = character:FindFirstChild('UpperTorso') ~= nil
	local m = Instance.new('Model')
	m.Name = 'BlockCostume'
	-- Where a rig part lives on this character: the real part and the rig part's frame inside it.
	local function host(seg)
		if r15 then
			local p = character:FindFirstChild(seg)
			if not p then return nil end
			local f = seg == 'Head' and headBox(p) / Art.Rig.Head[1] or p.Size / Art.Rig[seg][1]
			return p, CFrame.identity, f
		end
		local name = R6PART[seg]
		local p = character:FindFirstChild(name)
		if not p then return nil end
		local box = R6BOX[name]
		local f = name == 'Head' and headBox(p) / box[1] or p.Size / box[1]
		return p, CF(Art.Rig[seg][2] - box[2]), f
	end
	local function weld(p, part, c0)
		p.CFrame = part.CFrame * c0
		local w = Instance.new('Weld')
		w.Name = 'CostumeWeld'
		w.Part0 = part
		w.Part1 = p
		w.C0 = c0
		w.Parent = p
	end
	-- Body colours (R15: every part; R6: the main colour plus covers for differently coloured lower bands).
	if r15 then
		for seg in Art.Rig do
			local p = character:FindFirstChild(seg)
			if p and p:IsA('BasePart') then p.Color = recipe.body[seg] end
		end
	else
		for seg, name in R6PART do
			local p = character:FindFirstChild(name)
			if p and p:IsA('BasePart') then
				local main = name == 'Head' and 'Head' or name == 'Torso' and 'UpperTorso' or name:gsub(' Arm', 'UpperArm'):gsub(' Leg', 'UpperLeg')
				p.Color = recipe.body[main]
				local band_ = R6COVER[seg]
				if band_ and recipe.body[seg] ~= recipe.body[main] then
					local box = R6BOX[name]
					local f = p.Size / box[1]
					local rest = Art.Rig[seg][2]
					local c0 = CF(V(rest.X, (band_[1] + band_[2]) / 2, rest.Z) - box[2])
					local cf, size = scaled(c0, V(box[1].X + 0.03, band_[2] - band_[1], box[1].Z + 0.03), f)
					weld(makePart(m, seg .. 'Cover', size, p.CFrame * cf, recipe.body[seg], 'cloth', nil, false), p, cf)
				end
			end
		end
	end
	for _, pc in recipe.pieces do
		local part, inner, f = host(pc.seg)
		if part then
			local c0, size = scaled(inner * pc.cf, pc.size, f)
			if pc.face and pc.seg == 'Head' then
				-- Real heads are round where the display head is flat: move face pieces from the flat face plane
				-- onto the curve at their x (glasses: onto the front), keeping their layering.
				local r = headBox(part).X / 2
				local xr = pc.face == 'front' and 0 or math.min(math.abs(c0.X), r * 0.9)
				local surface = -math.sqrt(r * r - xr * xr)
				c0 = c0 + V(0, 0, surface - HF * f.Z - 0.01)
			end
			local p = makePart(m, pc.name, size, part.CFrame * c0, pc.color, pc.mat, pc.shape, false)
			if pc.transp then p.Transparency = pc.transp end
			weld(p, part, c0)
		end
	end
	-- Top-tier sparkle: one invisible box round the body with a slow emitter in the look's band colour.
	local torso = character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso')
	if typeof(s.Glow) == 'Color3' and torso then
		local k = torso.Size.X / 2
		local c0 = CF(0, -0.15 * k * 2, 0.1)
		local glow = makePart(m, 'TierGlow', V(3.2, 4.6, 1.8) * k, torso.CFrame * c0, s.Glow, 'cloth', nil, false)
		glow.Transparency = 1
		weld(glow, torso, c0)
		local e = Instance.new('ParticleEmitter')
		e.Name = 'TierSparkle'
		e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
		e.Color = ColorSequence.new(s.Glow:Lerp(Color3.new(1, 1, 1), 0.35), s.Glow)
		e.LightEmission = 1
		e.Rate = 4
		e.Lifetime = NumberRange.new(0.7, 1.2)
		e.Speed = NumberRange.new(0.2, 0.6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.55 * k), NumberSequenceKeypoint.new(1, 0) })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.ZOffset = 0.5
		e.Parent = glow
	end
	m.Parent = character
	return m
end

-- Take the costume off and give back what the character wore before its first look (accessories, clothing,
-- face, SurfaceAppearances, textures and body colours). Respawned characters never need this.
function Art.unequip(character)
	local old = character:FindFirstChild('BlockCostume')
	if old then old:Destroy() end
	local st = stashes[character]
	if not st then return end
	for part, color in st.colors do
		part.Color = color
	end
	for part, texture in st.textures do
		part.TextureID = texture
	end
	for _, item in st.items do
		-- (pcall: the old parent may have been destroyed since)
		pcall(function() item[1].Parent = item[2] end)
	end
	stashes[character] = nil
	character:SetAttribute('AvatarSkin', nil)
end

return Art
