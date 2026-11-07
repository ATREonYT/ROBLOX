-- [Treadmills] Bishop Run: tall ivory-and-plum arch. Plum chassis, ivory angled supports with bishop finials,
-- a split-mitre arch with two open windows, a faceted amethyst at its centre, crystals in the supports,
-- warm gold trim where ivory meets plum.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("BishopRun")
local rgb, P, SP, NEON, METAL, GLASS = T.rgb, T.part, T.SP, T.NEON, T.METAL, T.GLASS
local PLUM, PLUM_D, PLUM_L = rgb(118, 48, 168), rgb(78, 28, 118), rgb(158, 88, 212)
local IVORY, IVORY_D, GOLD = rgb(242, 230, 204), rgb(214, 198, 166), rgb(228, 176, 58)
local BLACK, BELT = rgb(24, 22, 30), rgb(30, 29, 37)
local AMETHYST, VIOLET = rgb(176, 96, 255), rgb(200, 120, 255)
local RX = 3.8

local function gem(group, name, size: number, pos: Vector3, rotX: number?)
	-- faceted crystal: a cube turned 45 degrees, with a smaller brighter core
	P(B, group, name, "Block", Vector3.new(size, size, size * 0.6), pos, AMETHYST, GLASS, Vector3.new(rotX or 0, 0, 45), { Accent = true, Transparency = 0.1 })
	P(B, group, name .. "Core", "Block", Vector3.new(size * 0.55, size * 0.55, size * 0.65), pos, VIOLET, NEON, Vector3.new(rotX or 0, 0, 45), { Accent = true })
end

-- belt
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.0, 1.0), Vector3.new(0, 0.5, 5.15), BELT)
T.pair(function(s)
	P(B, "BeltVisual", "RollerEnd", "Cylinder", Vector3.new(0.12, 0.72, 0.72), Vector3.new(s * 2.9, 0.5, 5.15), GOLD, METAL)
end)
T.beltLines(B, rgb(48, 44, 60), 5.6, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- plum rail with studs and a gold foot line
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.8, 1.45, 9.0), Vector3.new(x, 0.72, 0.6), PLUM, SP, nil, { CanCollide = true })
	P(B, "Trim", "RailTop", "Block", Vector3.new(1.8, 0.2, 9.0), Vector3.new(x, 1.55, 0.6), PLUM_L)
	P(B, "Trim", "GoldFoot", "Block", Vector3.new(1.84, 0.16, 9.0), Vector3.new(x, 0.1, 0.6), GOLD, METAL)
	for i = 0, 3 do
		P(B, "Trim", "Stud", "Block", Vector3.new(0.5, 0.26, 0.5), Vector3.new(x, 1.78, -1.4 + i * 1.3), PLUM_D)
	end
	P(B, "Trim", "SideLine", "Block", Vector3.new(0.06, 0.14, 7.0), Vector3.new(x + s * 0.91, 1.0, 0.6), VIOLET, NEON, nil, { Accent = true, Transparency = 0.2 })
	-- entry corner block with a gold-framed gem
	P(B, "Chassis", "Corner", "Block", Vector3.new(2.0, 1.9, 1.5), Vector3.new(x, 0.95, 5.75), PLUM, SP, nil, { CanCollide = true })
	P(B, "Trim", "CornerTop", "Block", Vector3.new(2.04, 0.2, 1.54), Vector3.new(x, 1.95, 5.75), PLUM_L)
	P(B, "Trim", "GemFrame", "Block", Vector3.new(1.25, 1.25, 0.1), Vector3.new(x, 0.95, 6.52), GOLD, METAL)
	P(B, "Trim", "GemBack", "Block", Vector3.new(0.95, 0.95, 0.1), Vector3.new(x, 0.95, 6.55), PLUM_D)
	gem("Trim", "CornerGem", 0.62, Vector3.new(x, 0.95, 6.62))

	-- ivory angled support, leaning in toward the arch, gold band where it meets the plum
	local lean = s * 7
	P(B, "Chassis", "SupportFoot", "Block", Vector3.new(2.2, 1.6, 2.0), Vector3.new(x, 0.8, -3.9), PLUM, SP, nil, { CanCollide = true })
	P(B, "Trim", "GoldBand", "Block", Vector3.new(2.3, 0.35, 2.1), Vector3.new(x, 1.7, -3.9), GOLD, METAL)
	local sup = T.cf(B, Vector3.new(x, 1.85, -3.9)) * CFrame.Angles(0, 0, math.rad(lean)) * CFrame.new(0, 2.6, 0)
	local function S(name, size, off, color, mat, rot, opts)
		local p = P(B, "Trim", name, "Block", size, Vector3.zero, color, mat, nil, opts)
		local r = rot or Vector3.zero
		p.CFrame = sup * CFrame.new(off) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		return p
	end
	S("Support", Vector3.new(1.7, 5.2, 1.6), Vector3.zero, IVORY, SP, nil, { CanCollide = true })
	S("SupportEdge", Vector3.new(0.2, 5.2, 1.62), Vector3.new(-s * 0.85, 0, 0), IVORY_D)
	S("CrystalFrame", Vector3.new(0.95, 0.95, 0.1), Vector3.new(0, 0.2, 0.82), GOLD, METAL, Vector3.new(0, 0, 45))
	local cr = S("SupportCrystal", Vector3.new(0.62, 0.62, 0.36), Vector3.new(0, 0.2, 0.9), AMETHYST, GLASS, Vector3.new(0, 0, 45), { Accent = true, Transparency = 0.1 })
	local _ = cr
	S("SupportCrystalTip", Vector3.new(0.3, 1.2, 0.2), Vector3.new(0, -0.95, 0.86), AMETHYST, GLASS, nil, { Accent = true, Transparency = 0.15 })
	S("GoldCap", Vector3.new(1.9, 0.3, 1.8), Vector3.new(0, 2.7, 0), GOLD, METAL)
	-- bishop finial: collar, onion dome with the mitre slit, tip
	local top = sup * CFrame.new(0, 2.85, 0)
	local function F(name, shape, size, off, color, mat, rot, opts)
		local p = P(B, "Trim", name, shape, size, Vector3.zero, color, mat, nil, opts)
		local r = rot or Vector3.zero
		p.CFrame = top * CFrame.new(off) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		return p
	end
	F("FinialNeck", "Cylinder", Vector3.new(0.5, 1.0, 1.0), Vector3.new(0, 0.25, 0), IVORY, SP, Vector3.new(0, 0, 90))
	F("FinialCollar", "Cylinder", Vector3.new(0.2, 1.35, 1.35), Vector3.new(0, 0.55, 0), GOLD, METAL, Vector3.new(0, 0, 90))
	F("FinialDome", "Ball", Vector3.new(1.55, 1.75, 1.55), Vector3.new(0, 1.45, 0), IVORY)
	F("FinialPoint", "Ball", Vector3.new(0.7, 0.9, 0.7), Vector3.new(0, 2.3, 0), IVORY)
	F("FinialTip", "Ball", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, 2.8, 0), GOLD, METAL)
	F("MitreSlit", "Block", Vector3.new(0.14, 1.0, 1.7), Vector3.new(s * 0.18, 1.7, 0), PLUM_D, SP, Vector3.new(0, 0, -s * 35))
end)

-- the split-mitre arch: two window openings under a pointed ivory roof, gold trim, amethyst at the centre
local AZ = -3.9
P(B, "Console", "ArchSill", "Block", Vector3.new(6.2, 0.5, 1.1), Vector3.new(0, 4.65, AZ), PLUM)
P(B, "Console", "ArchSillGold", "Block", Vector3.new(6.24, 0.14, 1.14), Vector3.new(0, 4.95, AZ), GOLD, METAL)
P(B, "Console", "ArchBeam", "Block", Vector3.new(6.0, 0.6, 1.0), Vector3.new(0, 6.95, AZ), IVORY)
P(B, "Console", "ArchMullion", "Block", Vector3.new(0.9, 2.0, 1.0), Vector3.new(0, 5.95, AZ), IVORY)
T.pair(function(s)
	P(B, "Console", "ArchJamb", "Block", Vector3.new(0.55, 2.0, 1.0), Vector3.new(s * 2.72, 5.95, AZ), IVORY)
	-- pointed window heads: a wedge each side of the window tops
	P(B, "Console", "WindowPoint", "Wedge", Vector3.new(1.0, 0.7, 0.9), Vector3.new(s * 1.9, 6.3, AZ), IVORY, SP, Vector3.new(0, s * 90, 0))
	P(B, "Console", "WindowPoint", "Wedge", Vector3.new(1.0, 0.7, 0.9), Vector3.new(s * 0.95, 6.3, AZ), IVORY, SP, Vector3.new(0, -s * 90, 0))
	-- the mitre roof, two halves rising to the centre, plum trim on the slope
	P(B, "Console", "MitreRoof", "Wedge", Vector3.new(1.0, 1.6, 3.0), Vector3.new(s * 1.5, 8.05, AZ), IVORY, SP, Vector3.new(0, s * 90, 0))
	local trim = P(B, "Console", "RoofTrim", "Block", Vector3.new(3.45, 0.22, 1.06), Vector3.zero, PLUM_L)
	trim.CFrame = T.cf(B, Vector3.new(s * 1.5, 8.12, AZ)) * CFrame.Angles(0, 0, math.rad(-s * 28))
	local gtrim = P(B, "Console", "RoofGold", "Block", Vector3.new(3.45, 0.08, 1.08), Vector3.zero, GOLD, METAL)
	gtrim.CFrame = T.cf(B, Vector3.new(s * 1.5, 8.0, AZ)) * CFrame.Angles(0, 0, math.rad(-s * 28))
end)
-- the screen sits on the mullion, under the gem
T.styleAnchors(B, BELT, Vector3.new(0.6, 1.3, 0.1), Vector3.new(0, 5.85, AZ + 0.52), nil, PLUM_D)
P(B, "Console", "GemSetting", "Block", Vector3.new(1.55, 1.55, 0.2), Vector3.new(0, 7.75, AZ + 0.45), GOLD, METAL, Vector3.new(0, 0, 45))
gem("Console", "Amethyst", 1.15, Vector3.new(0, 7.75, AZ + 0.62))
P(B, "Console", "GemTop", "Block", Vector3.new(0.3, 0.6, 0.3), Vector3.new(0, 9.0, AZ), GOLD, METAL, Vector3.new(0, 45, 0))

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.6, 0.6))
T.attach(B, "RailR", Vector3.new(RX, 1.6, 0.6))
T.attach(B, "Console", Vector3.new(0, 6.0, AZ + 0.9))
T.attach(B, "ArchL", Vector3.new(-2.6, 7.8, AZ + 0.8))
T.attach(B, "ArchR", Vector3.new(2.6, 7.8, AZ + 0.8))
T.attach(B, "OuterRing", Vector3.new(0, 0.3, 0.6))
B.visual:SetAttribute("Accent", VIOLET)
B.visual:SetAttribute("Style", "bishop")
T.finish(B)
