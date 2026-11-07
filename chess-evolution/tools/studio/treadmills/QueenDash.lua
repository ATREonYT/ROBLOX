-- [Treadmills] Queen Dash: regal ivory-and-gold machine. Ivory rails with gold bands and studs, ivory entry blocks
-- with gold diamond plates, two ivory pillars with glowing gold flame insets, swept ivory-and-gold wings on the
-- pillars, a gold console bar with an ivory plate, and a large floating crown (ivory body, gold band, six points
-- with gold balls, red gem at the front).
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("QueenDash")
local rgb, P, SP, NEON, METAL, GLASS = T.rgb, T.part, T.SP, T.NEON, T.METAL, T.GLASS
local IVORY, IVORY_D, IVORY_L = rgb(244, 234, 212), rgb(220, 204, 172), rgb(252, 246, 232)
local GOLD, GOLD_D, GLOW = rgb(234, 178, 46), rgb(196, 138, 30), rgb(255, 204, 64)
local BLACK, BELT, RUBY = rgb(24, 24, 28), rgb(30, 30, 34), rgb(222, 28, 44)
local RX = 3.8

local function goldDiamond(group, pos: Vector3, size: number)
	P(B, group, "DiamondFrame", "Block", Vector3.new(size, size, 0.1), pos, GOLD, METAL, Vector3.new(0, 0, 45))
	P(B, group, "DiamondCore", "Block", Vector3.new(size * 0.55, size * 0.55, 0.14), pos + Vector3.new(0, 0, 0.04), GLOW, NEON, Vector3.new(0, 0, 45), { Accent = true })
end

-- belt and entry roller
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.0, 1.0), Vector3.new(0, 0.5, 5.15), BELT)
T.pair(function(s)
	P(B, "BeltVisual", "RollerEnd", "Cylinder", Vector3.new(0.14, 0.78, 0.78), Vector3.new(s * 2.9, 0.5, 5.15), GOLD, METAL)
end)
T.beltLines(B, rgb(52, 48, 44), 5.6, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- ivory rail, gold foot band, ivory studs, gold glow line on the inner edge
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.8, 1.6, 8.6), Vector3.new(x, 0.8, 0.8), IVORY, SP, nil, { CanCollide = true })
	P(B, "Trim", "RailFoot", "Block", Vector3.new(1.86, 0.3, 8.6), Vector3.new(x, 0.15, 0.8), GOLD, METAL)
	P(B, "Trim", "RailTop", "Block", Vector3.new(1.8, 0.16, 8.6), Vector3.new(x, 1.68, 0.8), IVORY_L)
	for i = 0, 5 do
		P(B, "Trim", "Stud", "Block", Vector3.new(0.48, 0.24, 0.48), Vector3.new(x + s * 0.25, 1.88, -2.0 + i * 1.15), IVORY_D)
	end
	P(B, "Trim", "InnerGlow", "Block", Vector3.new(0.08, 0.12, 8.0), Vector3.new(x - s * 0.92, 1.5, 0.9), GLOW, NEON, nil, { Accent = true })
	P(B, "Trim", "SideBand", "Block", Vector3.new(0.08, 0.2, 6.6), Vector3.new(x + s * 0.92, 1.1, 0.6), GOLD, METAL)
	-- entry block: ivory with a gold base and a gold diamond plate facing the entry
	P(B, "Chassis", "EndBlock", "Block", Vector3.new(2.1, 2.3, 1.5), Vector3.new(x, 1.15, 5.8), IVORY, SP, nil, { CanCollide = true })
	P(B, "Trim", "EndBase", "Block", Vector3.new(2.16, 0.5, 1.56), Vector3.new(x, 0.25, 5.8), GOLD, METAL)
	P(B, "Trim", "EndTop", "Block", Vector3.new(2.16, 0.22, 1.56), Vector3.new(x, 2.36, 5.8), GOLD, METAL)
	P(B, "Trim", "EndPanel", "Block", Vector3.new(1.4, 1.3, 0.08), Vector3.new(x, 1.3, 6.57), IVORY_D)
	goldDiamond("Trim", Vector3.new(x, 1.3, 6.63), 0.8)

	-- ivory pillar with a glowing gold flame inset and gold collars
	local px, pz = s * 3.9, -4.0
	P(B, "Chassis", "PillarBase", "Block", Vector3.new(2.4, 1.4, 2.4), Vector3.new(px, 0.7, pz), IVORY, SP, nil, { CanCollide = true })
	P(B, "Trim", "PillarBaseGold", "Block", Vector3.new(2.46, 0.24, 2.46), Vector3.new(px, 1.45, pz), GOLD, METAL)
	P(B, "Chassis", "Pillar", "Block", Vector3.new(2.0, 3.6, 2.0), Vector3.new(px, 3.35, pz), IVORY, SP, nil, { CanCollide = true })
	P(B, "Trim", "PillarEdge", "Block", Vector3.new(0.16, 3.6, 2.02), Vector3.new(px + s * 0.94, 3.35, pz), IVORY_D)
	P(B, "Trim", "FlameFrame", "Block", Vector3.new(0.95, 2.6, 0.1), Vector3.new(px, 3.3, pz + 1.02), GOLD, METAL)
	P(B, "Trim", "Flame", "Block", Vector3.new(0.55, 2.1, 0.12), Vector3.new(px, 3.25, pz + 1.05), GLOW, NEON, nil, { Accent = true })
	P(B, "Trim", "FlameTip", "Block", Vector3.new(0.39, 0.39, 0.12), Vector3.new(px, 4.35, pz + 1.05), GLOW, NEON, Vector3.new(0, 0, 45), { Accent = true })
	P(B, "Trim", "PillarCap", "Block", Vector3.new(2.3, 0.4, 2.3), Vector3.new(px, 5.35, pz), GOLD, METAL)
	P(B, "Trim", "PillarCrown", "Block", Vector3.new(1.8, 0.3, 1.8), Vector3.new(px, 5.7, pz), IVORY)

	-- swept wing: three ivory feathers rising and leaning outward, gold quills
	local wingRoot = T.cf(B, Vector3.new(px + s * 0.2, 5.8, pz))
	local feathers = {
		{ len = 3.7, w = 1.7, lean = 6, off = 0.0 },
		{ len = 3.4, w = 1.65, lean = 16, off = 0.15 },
		{ len = 3.0, w = 1.6, lean = 26, off = 0.3 },
		{ len = 2.6, w = 1.5, lean = 36, off = 0.45 },
		{ len = 2.1, w = 1.4, lean = 46, off = 0.6 },
	}
	for i, f in ipairs(feathers) do
		local cf = wingRoot * CFrame.new(s * f.off, 0, 0) * CFrame.Angles(0, 0, math.rad(-s * f.lean)) * CFrame.new(0, f.len / 2, 0)
		local fe = P(B, "Trim", "Feather", "Block", Vector3.new(0.62, f.len, f.w), Vector3.zero, if i % 2 == 1 then IVORY_L else IVORY)
		fe.CFrame = cf
		local tip = P(B, "Trim", "FeatherTip", "Wedge", Vector3.new(0.62, 0.9, f.w), Vector3.zero, if i % 2 == 1 then IVORY_L else IVORY)
		tip.CFrame = cf * CFrame.new(0, f.len / 2 + 0.45, 0) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0)
		if i % 2 == 1 then
			local quill = P(B, "Trim", "Quill", "Block", Vector3.new(0.5, f.len * 0.85, 0.16), Vector3.zero, GOLD, METAL)
			quill.CFrame = cf * CFrame.new(0, -0.05, f.w / 2 - 0.05)
		end
	end
end)

-- gold console bar between the pillars with an ivory plate (the Screen)
local CY, CZ = 4.9, -4.0
P(B, "Console", "Bar", "Block", Vector3.new(5.6, 0.9, 1.2), Vector3.new(0, CY, CZ), GOLD, METAL, nil, { CanCollide = true })
P(B, "Console", "BarTop", "Block", Vector3.new(3.4, 0.4, 1.0), Vector3.new(0, CY + 0.62, CZ), GOLD, METAL)
P(B, "Console", "BarTopStep", "Block", Vector3.new(1.6, 0.3, 0.9), Vector3.new(0, CY + 0.95, CZ), GOLD_D, METAL)
T.pair(function(s)
	P(B, "Console", "PlateWing", "Block", Vector3.new(0.8, 0.8, 0.12), Vector3.new(s * 1.35, CY, CZ + 0.62), GOLD_D, METAL, Vector3.new(0, 0, 45))
end)
P(B, "Console", "PlateFrame", "Block", Vector3.new(2.7, 0.95, 0.1), Vector3.new(0, CY, CZ + 0.62), GOLD_D, METAL)
T.styleAnchors(B, BELT, Vector3.new(2.4, 0.72, 0.1), Vector3.new(0, CY, CZ + 0.66), nil, IVORY)
for i = -1, 1 do
	P(B, "Console", "Light", "Block", Vector3.new(0.5, 0.16, 0.06), Vector3.new(i * 0.7, CY, CZ + 0.73), GLOW, NEON, nil, { Accent = true })
end

-- the floating crown
local K = Vector3.new(0, 7.75, -4.0)
local CS = 1.3 -- crown scale
T.vcyl(B, "Trim", "CrownBand", 0.6 * CS, 3.7 * CS, K, GOLD, METAL)
T.vcyl(B, "Trim", "CrownBody", 0.9 * CS, 3.4 * CS, K + Vector3.new(0, 0.7 * CS, 0), IVORY)
T.vcyl(B, "Trim", "CrownRim", 0.16 * CS, 3.5 * CS, K + Vector3.new(0, 1.18 * CS, 0), GOLD, METAL)
T.vcyl(B, "Trim", "CrownGlow", 0.08, 3.3 * CS, K + Vector3.new(0, -0.32 * CS, 0), GLOW, NEON, { Accent = true })
for i = 0, 5 do
	local a = math.rad(90 + i * 60) -- i = 0 faces the entry
	local big = (i == 0)
	local r = 1.55 * CS
	local h = (if big then 1.25 else 0.95) * CS
	local base = K + Vector3.new(math.cos(a) * r, 1.25 * CS, math.sin(a) * r)
	local pt = P(B, "Trim", "CrownPoint", "Block", Vector3.new(h, h, 0.3), Vector3.zero, IVORY)
	pt.CFrame = T.cf(B, base + Vector3.new(0, h * 0.25, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(45))
	local edge = P(B, "Trim", "CrownPointGold", "Block", Vector3.new(h + 0.14, h + 0.14, 0.2), Vector3.zero, GOLD, METAL)
	edge.CFrame = pt.CFrame * CFrame.new(0, 0, -0.06)
	P(B, "Trim", "CrownBall", "Ball", Vector3.new(0.55, 0.55, 0.55) * CS, base + Vector3.new(0, h * 0.25 + h * 0.72, 0), GOLD, METAL)
end
P(B, "Trim", "RubySetting", "Block", Vector3.new(1.2, 1.2, 0.12), K + Vector3.new(0, 0.8, 1.72 * CS), GOLD, METAL, Vector3.new(0, 0, 45))
P(B, "Trim", "Ruby", "Block", Vector3.new(0.85, 0.85, 0.28), K + Vector3.new(0, 0.8, 1.72 * CS + 0.06), RUBY, GLASS, Vector3.new(0, 0, 45), { Transparency = 0.05 })
P(B, "Trim", "RubyCore", "Block", Vector3.new(0.4, 0.4, 0.32), K + Vector3.new(0, 0.8, 1.72 * CS + 0.08), rgb(255, 90, 90), NEON, Vector3.new(0, 0, 45))
P(B, "Trim", "CrownTop", "Ball", Vector3.new(0.9, 0.9, 0.9), K + Vector3.new(0, 1.55 * CS + 0.2, 0), GOLD, METAL)

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.9, 0.8))
T.attach(B, "RailR", Vector3.new(RX, 1.9, 0.8))
T.attach(B, "Console", Vector3.new(0, CY, CZ + 1.0))
T.attach(B, "Crown", K + Vector3.new(0, 0.8, 0))
T.attach(B, "OuterRing", Vector3.new(0, 3.0, 0.6))
B.visual:SetAttribute("Accent", GLOW)
B.visual:SetAttribute("Style", "queen")
T.finish(B)
