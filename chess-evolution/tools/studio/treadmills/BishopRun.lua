-- [Treadmills] Bishop Run: tall ivory-and-plum arch. Plum chassis, ivory angled supports with bishop finials,
-- a split-mitre arch with two open windows, a faceted amethyst at its centre, crystals in the supports,
-- warm gold trim where ivory meets plum.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("BishopRun")
local rgb, P, SP, NEON, METAL, GLASS = T.rgb, T.part, T.SP, T.NEON, T.METAL, T.GLASS
local PLUM, PLUM_D, PLUM_L = rgb(118, 48, 168), rgb(78, 28, 118), rgb(140, 66, 194)
local IVORY, IVORY_D, GOLD = rgb(242, 230, 204), rgb(214, 198, 166), rgb(228, 176, 58)
local BLACK, BELT = rgb(24, 22, 30), rgb(30, 29, 37)
local AMETHYST, VIOLET = rgb(176, 96, 255), rgb(200, 120, 255)
local RX = 3.8

local function gem(group, name, size, pos, rotX)
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
	P(B, "Trim", "CornerGem", "Block", Vector3.new(0.7, 0.7, 0.16), Vector3.new(x, 0.95, 6.62), AMETHYST, GLASS, nil, { Accent = true, Transparency = 0.05 })
	P(B, "Trim", "CornerGemCore", "Block", Vector3.new(0.36, 0.36, 0.2), Vector3.new(x, 0.95, 6.66), VIOLET, NEON, nil, { Accent = true })

	-- ivory angled support: upright column with a sloped front buttress, crystal on the slope,
	-- gold band where it meets the plum foot, bishop finial on top
	P(B, "Chassis", "SupportFoot", "Block", Vector3.new(2.2, 1.6, 2.0), Vector3.new(x, 0.8, -3.9), PLUM, SP, nil, { CanCollide = true })
	P(B, "Trim", "GoldBand", "Block", Vector3.new(2.3, 0.3, 2.1), Vector3.new(x, 1.72, -3.9), GOLD, METAL)
	P(B, "Chassis", "Support", "Block", Vector3.new(1.7, 4.6, 1.6), Vector3.new(x, 4.1, -3.9), IVORY, SP, nil, { CanCollide = true })
	P(B, "Trim", "SupportEdge", "Block", Vector3.new(0.18, 4.6, 1.62), Vector3.new(x + s * 0.78, 4.1, -3.9), IVORY_D)
	P(B, "Trim", "Buttress", "Wedge", Vector3.new(1.7, 3.6, 1.3), Vector3.new(x, 3.67, -2.45), IVORY, SP, Vector3.new(0, 180, 0))
	local slope = math.atan(1.3 / 3.6)
	local n = Vector3.new(0, math.sin(slope), math.cos(slope))
	local mid = Vector3.new(x, 3.67, -2.45)
	local function onSlope(name, size, out, color, mat, rz, opts)
		local p = P(B, "Trim", name, "Block", size, Vector3.zero, color, mat, nil, opts)
		p.CFrame = T.cf(B, mid + n * out) * CFrame.Angles(-slope, 0, math.rad(rz or 0))
		return p
	end
	onSlope("CrystalFrame", Vector3.new(0.85, 1.75, 0.1), 0.05, GOLD, METAL)
	onSlope("CrystalBack", Vector3.new(0.65, 1.55, 0.1), 0.08, PLUM_D)
	onSlope("SupportCrystal", Vector3.new(0.42, 0.9, 0.22), 0.16, AMETHYST, GLASS, 0, { Accent = true, Transparency = 0.05 })
	for _, dy in ipairs({ -0.45, 0.45 }) do
		local p = P(B, "Trim", "SupportCrystalTip", "Block", Vector3.new(0.3, 0.3, 0.22), Vector3.zero, AMETHYST, GLASS, nil, { Accent = true, Transparency = 0.05 })
		p.CFrame = T.cf(B, mid + n * 0.16) * CFrame.Angles(-slope, 0, 0) * CFrame.new(0, dy, 0) * CFrame.Angles(0, 0, math.rad(45))
	end
	onSlope("SupportCrystalCore", Vector3.new(0.2, 0.7, 0.26), 0.17, VIOLET, NEON, 0, { Accent = true })
	P(B, "Trim", "GoldCap", "Block", Vector3.new(1.95, 0.3, 1.85), Vector3.new(x, 6.55, -3.9), GOLD, METAL)
	local top = T.cf(B, Vector3.new(x, 6.7, -3.9))
	local function F(name, shape, size, off, color, mat, rot, opts)
		local p = P(B, "Trim", name, shape, size, Vector3.zero, color, mat, nil, opts)
		local r = rot or Vector3.zero
		p.CFrame = top * CFrame.new(off) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		return p
	end
	F("FinialNeck", "Cylinder", Vector3.new(0.5, 1.1, 1.1), Vector3.new(0, 0.25, 0), IVORY, SP, Vector3.new(0, 0, 90))
	F("FinialCollar", "Cylinder", Vector3.new(0.22, 1.45, 1.45), Vector3.new(0, 0.6, 0), GOLD, METAL, Vector3.new(0, 0, 90))
	F("FinialDome", "Ball", Vector3.new(1.6, 1.8, 1.6), Vector3.new(0, 1.5, 0), IVORY)
	F("FinialPoint", "Ball", Vector3.new(0.7, 0.95, 0.7), Vector3.new(0, 2.4, 0), IVORY)
	F("FinialTip", "Ball", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, 2.92, 0), GOLD, METAL)
	F("MitreSlit", "Block", Vector3.new(0.16, 1.05, 1.7), Vector3.new(s * 0.2, 1.75, 0), PLUM_D, SP, Vector3.new(0, 0, -s * 35))
end)

-- purple studded crossbar between the supports (like the reference, below the arch)
P(B, "Chassis", "Crossbar", "Block", Vector3.new(5.9, 1.1, 1.2), Vector3.new(0, 4.0, -4.0), PLUM)
P(B, "Trim", "CrossbarTop", "Block", Vector3.new(5.9, 0.16, 1.2), Vector3.new(0, 4.6, -4.0), PLUM_L)
for i = 0, 5 do
	P(B, "Trim", "Stud", "Block", Vector3.new(0.55, 0.26, 0.55), Vector3.new(-2.3 + i * 0.92, 4.8, -4.0), PLUM_D)
	P(B, "Trim", "Stud", "Block", Vector3.new(0.55, 0.5, 0.14), Vector3.new(-2.3 + i * 0.92, 3.95, -3.36), PLUM_D)
end

-- the split-mitre arch above the supports: ivory base beam, two rising ivory beams with purple outer trim,
-- a central mullion, so it reads as two pointed windows. Faceted amethyst at the peak.
local AZ, AY, PEAK = -3.9, 6.6, 9.3
P(B, "Console", "ArchBase", "Block", Vector3.new(6.0, 0.5, 0.95), Vector3.new(0, AY, AZ), IVORY)
P(B, "Console", "ArchBaseGold", "Block", Vector3.new(6.04, 0.12, 0.99), Vector3.new(0, AY - 0.28, AZ), GOLD, METAL)
P(B, "Console", "ArchMullion", "Block", Vector3.new(0.55, PEAK - AY, 0.9), Vector3.new(0, (AY + PEAK) / 2, AZ), IVORY)
T.pair(function(s)
	local x0, y0 = s * 2.95, AY
	local dx, dy = -s * 2.95, PEAK - AY
	local len = math.sqrt(dx * dx + dy * dy)
	local ang = math.atan2(dy, math.abs(dx)) * -s
	local c = Vector3.new(x0 + dx / 2, y0 + dy / 2, AZ)
	local beam = P(B, "Console", "ArchBeam", "Block", Vector3.new(len + 0.4, 0.75, 0.95), Vector3.zero, IVORY)
	beam.CFrame = T.cf(B, c) * CFrame.Angles(0, 0, ang)
	local trim = P(B, "Console", "ArchTrim", "Block", Vector3.new(len + 0.6, 0.38, 1.05), Vector3.zero, PLUM)
	trim.CFrame = T.cf(B, c) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.5, 0)
	local gold = P(B, "Console", "ArchGold", "Block", Vector3.new(len + 0.5, 0.1, 1.07), Vector3.zero, GOLD, METAL)
	gold.CFrame = T.cf(B, c) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.33, 0)
	-- purple window lining inside each opening
	local lin = P(B, "Console", "WindowLining", "Block", Vector3.new(len * 0.55, 0.14, 0.97), Vector3.zero, PLUM_D)
	lin.CFrame = T.cf(B, c) * CFrame.Angles(0, 0, ang) * CFrame.new(-s * 0.2, -0.43, 0)
end)
-- console screen: small plum panel on the crossbar face
T.styleAnchors(B, BELT, Vector3.new(1.4, 0.5, 0.1), Vector3.new(0, 3.5, -3.34), nil, PLUM_D)
P(B, "Console", "GemSetting", "Block", Vector3.new(1.5, 1.5, 0.2), Vector3.new(0, PEAK - 0.35, AZ + 0.5), GOLD, METAL, Vector3.new(0, 0, 45))
gem("Console", "Amethyst", 1.1, Vector3.new(0, PEAK - 0.35, AZ + 0.65))
P(B, "Console", "GemTop", "Block", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, PEAK + 0.65, AZ), GOLD, METAL, Vector3.new(0, 0, 45))

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.6, 0.6))
T.attach(B, "RailR", Vector3.new(RX, 1.6, 0.6))
T.attach(B, "Console", Vector3.new(0, PEAK - 0.35, AZ + 0.9))
T.attach(B, "ArchL", Vector3.new(-1.6, 8.3, AZ + 0.8))
T.attach(B, "ArchR", Vector3.new(1.6, 8.3, AZ + 0.8))
T.attach(B, "OuterRing", Vector3.new(0, 0.3, 0.6))
B.visual:SetAttribute("Accent", VIOLET)
B.visual:SetAttribute("Style", "bishop")
T.finish(B)
