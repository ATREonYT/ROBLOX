-- [Treadmills] King's Endgame: the top tier. Navy-and-gold: navy rails with gold trim and big glowing gold roller caps
-- at the entry, two tall navy pillars (angled top on the left, gold crystal on the right), a navy console bar with a
-- gold diamond and a glowing grille, gold pegs, and a floating gold crown ring with a cross on top, hung on chains.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("KingsEndgame")
local rgb, P, SP, NEON, METAL, GLASS = T.rgb, T.part, T.SP, T.NEON, T.METAL, T.GLASS
local NAVY, NAVY_D, NAVY_L = rgb(38, 50, 96), rgb(24, 32, 64), rgb(60, 76, 134)
local GOLD, GOLD_D, GLOW = rgb(236, 178, 44), rgb(190, 130, 28), rgb(255, 196, 56)
local BLACK, BELT, CHAIN = rgb(22, 22, 28), rgb(28, 28, 34), rgb(70, 72, 82)
local RX = 3.8

local function diamond(group, pos: Vector3, size: number, glow: boolean?)
	P(B, group, "DiamondFrame", "Block", Vector3.new(size, size, 0.1), pos, GOLD, METAL, Vector3.new(0, 0, 45))
	P(B, group, "DiamondCore", "Block", Vector3.new(size * 0.55, size * 0.55, 0.14), pos + Vector3.new(0, 0, 0.04), if glow then GLOW else NAVY_D, if glow then NEON else SP, Vector3.new(0, 0, 45), if glow then { Accent = true } else nil)
end

-- belt and the big glowing gold roller caps at the entry
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.0, 1.0), Vector3.new(0, 0.5, 5.15), BELT)
T.beltLines(B, rgb(46, 48, 62), 5.6, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- navy rail with gold trim lines, navy studs and a gold glow on the inner edge
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.8, 1.6, 8.2), Vector3.new(x, 0.8, 0.6), NAVY, SP, nil, { CanCollide = true })
	P(B, "Trim", "RailTop", "Block", Vector3.new(1.8, 0.16, 8.2), Vector3.new(x, 1.68, 0.6), NAVY_L)
	P(B, "Trim", "RailFoot", "Block", Vector3.new(1.86, 0.24, 8.2), Vector3.new(x, 0.12, 0.6), NAVY_D)
	P(B, "Trim", "GoldLine", "Block", Vector3.new(0.08, 0.16, 7.4), Vector3.new(x + s * 0.92, 1.2, 0.5), GOLD, METAL)
	P(B, "Trim", "GoldLineLow", "Block", Vector3.new(0.08, 0.1, 7.4), Vector3.new(x + s * 0.92, 0.5, 0.5), GOLD, METAL)
	P(B, "Trim", "InnerGlow", "Block", Vector3.new(0.08, 0.12, 7.8), Vector3.new(x - s * 0.92, 1.5, 0.7), GLOW, NEON, nil, { Accent = true })
	for i = 0, 4 do
		P(B, "Trim", "Stud", "Block", Vector3.new(0.48, 0.24, 0.48), Vector3.new(x + s * 0.2, 1.88, -1.6 + i * 1.2), NAVY_L)
	end
	-- entry: navy bracket around a big faceted gold roller cap that glows
	P(B, "Chassis", "Bracket", "Block", Vector3.new(0.5, 2.0, 2.0), Vector3.new(x + s * 0.75, 1.0, 5.4), NAVY, SP, nil, { CanCollide = true })
	P(B, "Trim", "BracketGold", "Block", Vector3.new(0.54, 0.16, 2.04), Vector3.new(x + s * 0.75, 2.0, 5.4), GOLD, METAL)
	P(B, "BeltVisual", "RollerCap", "Cylinder", Vector3.new(1.1, 1.75, 1.75), Vector3.new(x - s * 0.1, 0.95, 5.4), GOLD, METAL)
	P(B, "BeltVisual", "RollerGlow", "Cylinder", Vector3.new(1.14, 1.3, 1.3), Vector3.new(x - s * 0.1, 0.95, 5.4), GLOW, NEON, nil, { Accent = true })
	for k = 0, 3 do
		local ring = P(B, "BeltVisual", "RollerFacet", "Block", Vector3.new(1.16, 0.2, 1.8), Vector3.zero, GOLD_D, METAL)
		ring.CFrame = T.cf(B, Vector3.new(x - s * 0.1, 0.95, 5.4)) * CFrame.Angles(math.rad(k * 45), 0, 0)
	end
	P(B, "Trim", "Hub", "Cylinder", Vector3.new(0.2, 0.5, 0.5), Vector3.new(x + s * 1.02, 1.0, 5.4), CHAIN, METAL)

	-- tall navy pillar with gold edging and a gold diamond emblem
	local px, pz = s * 3.95, -4.0
	P(B, "Chassis", "PillarBase", "Block", Vector3.new(2.5, 1.6, 2.5), Vector3.new(px, 0.8, pz), NAVY_D, SP, nil, { CanCollide = true })
	P(B, "Trim", "PillarBaseGold", "Block", Vector3.new(2.56, 0.2, 2.56), Vector3.new(px, 1.62, pz), GOLD, METAL)
	P(B, "Chassis", "Pillar", "Block", Vector3.new(2.0, 5.0, 2.0), Vector3.new(px, 4.2, pz), NAVY, SP, nil, { CanCollide = true })
	P(B, "Trim", "PillarInset", "Block", Vector3.new(1.3, 3.6, 0.1), Vector3.new(px, 4.1, pz + 1.02), NAVY_D)
	P(B, "Trim", "PillarGoldEdge", "Block", Vector3.new(0.12, 4.6, 0.12), Vector3.new(px - s * 0.62, 4.2, pz + 1.04), GOLD, METAL)
	P(B, "Trim", "PillarGoldEdge2", "Block", Vector3.new(0.12, 4.6, 0.12), Vector3.new(px + s * 0.62, 4.2, pz + 1.04), GOLD, METAL)
	diamond("Trim", Vector3.new(px, 4.9, pz + 1.08), 0.75, true)
	for i = 0, 1 do
		P(B, "Trim", "PillarSlot", "Block", Vector3.new(0.5, 0.14, 0.08), Vector3.new(px, 3.4 + i * 0.35, pz + 1.08), GOLD, METAL)
	end
	P(B, "Trim", "PillarCap", "Block", Vector3.new(2.2, 0.3, 2.2), Vector3.new(px, 6.85, pz), GOLD, METAL)
	if s < 0 then
		-- left: stepped, angled top
		P(B, "Trim", "TopBlock", "Block", Vector3.new(1.6, 1.2, 1.6), Vector3.new(px, 7.6, pz), NAVY)
		P(B, "Trim", "TopSlope", "Wedge", Vector3.new(1.6, 1.4, 1.6), Vector3.new(px, 8.9, pz), NAVY, SP, Vector3.new(0, 90, 0))
		P(B, "Trim", "TopEdge", "Block", Vector3.new(0.1, 1.9, 0.1), Vector3.new(px + 0.82, 8.0, pz + 0.82), GOLD, METAL)
		P(B, "Trim", "TopWindow", "Block", Vector3.new(0.3, 0.3, 0.08), Vector3.new(px, 7.7, pz + 0.82), GOLD, METAL)
	else
		-- right: a tall gold crystal
		P(B, "Trim", "CrystalBase", "Block", Vector3.new(1.4, 0.4, 1.4), Vector3.new(px, 7.2, pz), GOLD_D, METAL)
		P(B, "Trim", "Crystal", "Block", Vector3.new(0.9, 1.9, 0.9), Vector3.new(px, 8.35, pz), GLOW, GLASS, Vector3.new(0, 45, 0), { Accent = true, Transparency = 0.05 })
		P(B, "Trim", "CrystalCore", "Block", Vector3.new(0.45, 1.6, 0.45), Vector3.new(px, 8.35, pz), GLOW, NEON, Vector3.new(0, 45, 0), { Accent = true })
		local tip = P(B, "Trim", "CrystalTip", "Block", Vector3.new(0.64, 0.64, 0.64), Vector3.zero, GLOW, GLASS, nil, { Accent = true, Transparency = 0.05 })
		tip.CFrame = T.cf(B, Vector3.new(px, 9.3, pz)) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, math.rad(35))
	end
	-- gold peg into the console bar
	P(B, "Trim", "Peg", "Cylinder", Vector3.new(0.6, 0.5, 0.5), Vector3.new(s * 2.75, 6.2, pz), GOLD, METAL)
end)

-- navy console bar with a raised trapezoid plate, gold diamond and a glowing grille
local CY, CZ = 5.5, -4.0
P(B, "Console", "Bar", "Block", Vector3.new(5.6, 1.0, 1.2), Vector3.new(0, CY, CZ), NAVY, SP, nil, { CanCollide = true })
P(B, "Console", "BarGoldTop", "Block", Vector3.new(5.6, 0.12, 1.24), Vector3.new(0, CY + 0.56, CZ), GOLD, METAL)
P(B, "Console", "BarGoldBottom", "Block", Vector3.new(5.6, 0.12, 1.24), Vector3.new(0, CY - 0.56, CZ), GOLD, METAL)
P(B, "Console", "Plate", "Block", Vector3.new(2.6, 0.8, 0.5), Vector3.new(0, CY + 0.95, CZ), NAVY_L)
T.pair(function(s)
	P(B, "Console", "PlateSlope", "Wedge", Vector3.new(0.5, 0.8, 0.8), Vector3.new(s * 1.7, CY + 0.95, CZ), NAVY_L, SP, Vector3.new(0, s * 90, 0))
end)
P(B, "Console", "PlateGold", "Block", Vector3.new(3.4, 0.1, 0.54), Vector3.new(0, CY + 1.38, CZ), GOLD, METAL)
diamond("Console", Vector3.new(0, CY + 0.95, CZ + 0.28), 0.6, true)
T.styleAnchors(B, BELT, Vector3.new(2.6, 0.62, 0.1), Vector3.new(0, CY, CZ + 0.62), nil, NAVY_D)
for i = -2, 2 do
	P(B, "Console", "Grille", "Block", Vector3.new(0.14, 0.42, 0.06), Vector3.new(i * 0.4, CY, CZ + 0.69), GLOW, NEON, nil, { Accent = true })
end

-- floating gold crown ring with a cross on top, hung on short chains from the pillar tops
local RY = 8.0
local N = 16
for i = 1, N do
	local a = (i / N) * math.pi * 2
	local seg = P(B, "Trim", "CrownRing", "Block", Vector3.new(0.95, 0.8, 0.45), Vector3.zero, GOLD, METAL)
	seg.CFrame = T.cf(B, Vector3.new(0, RY, -4.0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.15)
	if i % 2 == 0 then
		local spike = P(B, "Trim", "CrownSpike", "Block", Vector3.new(0.42, 0.42, 0.2), Vector3.zero, GOLD_D, METAL)
		spike.CFrame = T.cf(B, Vector3.new(0, RY + 0.45, -4.0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.15) * CFrame.Angles(0, 0, math.rad(45))
	end
end
T.vcyl(B, "Trim", "CrownRingGlow", 0.08, 4.1, Vector3.new(0, RY - 0.44, -4.0), GLOW, NEON, { Accent = true })
P(B, "Trim", "CrossStem", "Block", Vector3.new(0.55, 1.5, 0.45), Vector3.new(0, RY + 1.0, -4.0), GOLD, METAL)
local CX = RY + 2.5
P(B, "Trim", "CrossV", "Block", Vector3.new(0.85, 2.9, 0.55), Vector3.new(0, CX, -4.0), GOLD, METAL)
P(B, "Trim", "CrossH", "Block", Vector3.new(2.8, 0.85, 0.55), Vector3.new(0, CX + 0.3, -4.0), GOLD, METAL)
for _, e in ipairs({ Vector3.new(0, 1.5, 0), Vector3.new(-1.43, 0.3, 0), Vector3.new(1.43, 0.3, 0) }) do
	local vertical = e.X == 0
	P(B, "Trim", "CrossFlare", "Block", if vertical then Vector3.new(1.25, 0.32, 0.6) else Vector3.new(0.32, 1.25, 0.6), Vector3.new(0, CX, -4.0) + e, GOLD_D, METAL)
end
P(B, "Trim", "CrossGem", "Block", Vector3.new(0.6, 0.6, 0.66), Vector3.new(0, CX + 0.3, -4.0), GLOW, NEON, Vector3.new(0, 0, 45), { Accent = true })
T.pair(function(s)
	for k = 0, 3 do
		local t = k / 3
		local pos = Vector3.new(s * (3.6 - 1.45 * t), 7.0 + 1.0 * t, -4.0)
		P(B, "Trim", "ChainLink", "Block", Vector3.new(0.34, 0.2, 0.14), pos, CHAIN, METAL, Vector3.new(0, if k % 2 == 0 then 0 else 90, s * -30))
	end
end)

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.9, 0.6))
T.attach(B, "RailR", Vector3.new(RX, 1.9, 0.6))
T.attach(B, "Console", Vector3.new(0, CY, CZ + 1.0))
T.attach(B, "Cross", Vector3.new(0, CX + 0.3, -3.6))
T.attach(B, "OuterRing", Vector3.new(0, 2.6, 0.6))
B.visual:SetAttribute("Accent", GLOW)
B.visual:SetAttribute("Style", "king")
T.finish(B)
