-- [Treadmills] Rook Rig: low, heavy red-and-charcoal fortress. A squat crenellated tower on each console-end corner,
-- joined by an armoured horizontal console with a gunmetal grille and a small inset red gem. Layered red side panels,
-- dark vents, riveted gunmetal plates, broad black roller caps, flat rook banners on the towers.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("RookRig")
local rgb, P, SP, NEON, METAL, GLASS = T.rgb, T.part, T.SP, T.NEON, T.METAL, T.GLASS
local RED, RED_D, RED_L = rgb(204, 42, 38), rgb(142, 24, 26), rgb(232, 74, 60)
local CHAR, CHAR_D, STONE = rgb(66, 68, 76), rgb(42, 44, 50), rgb(104, 106, 116)
local GUN, BLACK, BELT = rgb(120, 124, 134), rgb(24, 24, 28), rgb(30, 30, 34)
local GLOW, GOLD, GEM = rgb(255, 176, 48), rgb(236, 180, 54), rgb(235, 30, 48)
local RX = 3.8

local function rivet(group, pos: Vector3, face: Vector3?)
	P(B, group, "Rivet", "Ball", Vector3.new(0.26, 0.26, 0.26), pos + (face or Vector3.zero) * 0.04, GUN, METAL)
end

-- belt and the broad black entry roller
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.1, 1.1), Vector3.new(0, 0.55, 5.2), BELT)
T.pair(function(s)
	P(B, "BeltVisual", "RollerCap", "Cylinder", Vector3.new(0.5, 1.45, 1.45), Vector3.new(s * 2.65, 0.72, 5.2), BLACK)
	P(B, "BeltVisual", "RollerHub", "Cylinder", Vector3.new(0.54, 0.6, 0.6), Vector3.new(s * 2.65, 0.72, 5.2), CHAR_D, METAL)
end)
T.beltLines(B, rgb(48, 46, 50), 5.6, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- layered side rail: red body, darker outer panel with vents and glowing slots, studs on top
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.9, 1.7, 8.4), Vector3.new(x, 0.85, 0.9), RED, SP, nil, { CanCollide = true })
	P(B, "Trim", "RailTop", "Block", Vector3.new(1.9, 0.18, 8.4), Vector3.new(x, 1.79, 0.9), RED_L)
	P(B, "Trim", "RailFoot", "Block", Vector3.new(1.96, 0.24, 8.4), Vector3.new(x, 0.12, 0.9), CHAR_D)
	P(B, "Trim", "OuterPanel", "Block", Vector3.new(0.14, 1.1, 6.0), Vector3.new(x + s * 1.0, 0.9, 0.4), RED_D)
	for i = 0, 3 do
		P(B, "Trim", "Vent", "Block", Vector3.new(0.1, 0.12, 1.5), Vector3.new(x + s * 1.08, 0.55 + i * 0.24, -1.2), CHAR_D)
	end
	for i = 0, 1 do
		P(B, "Trim", "GlowSlot", "Block", Vector3.new(0.08, 0.5, 0.32), Vector3.new(x + s * 1.08, 0.9, 1.4 + i * 0.6), GLOW, NEON, nil, { Accent = true })
	end
	for i = 0, 4 do
		P(B, "Trim", "Stud", "Block", Vector3.new(0.5, 0.26, 0.5), Vector3.new(x + s * 0.3, 2.0, -1.6 + i * 1.25), RED_L)
	end
	P(B, "Trim", "InnerGlow", "Block", Vector3.new(0.08, 0.1, 7.6), Vector3.new(x - s * 0.96, 1.72, 1.0), GLOW, NEON, nil, { Accent = true })
	-- riveted gunmetal plates on the rail top
	P(B, "Trim", "Plate", "Block", Vector3.new(1.5, 0.12, 1.0), Vector3.new(x, 1.93, -2.6), GUN, METAL)
	-- entry end block: armoured, red, riveted plate facing the entry
	P(B, "Chassis", "EndBlock", "Block", Vector3.new(2.1, 2.2, 1.5), Vector3.new(x, 1.1, 5.8), RED, SP, nil, { CanCollide = true })
	P(B, "Trim", "EndTop", "Block", Vector3.new(2.14, 0.2, 1.54), Vector3.new(x, 2.25, 5.8), RED_L)
	P(B, "Trim", "EndPlate", "Block", Vector3.new(1.6, 1.6, 0.12), Vector3.new(x, 1.1, 6.6), CHAR, METAL)
	for _, o in ipairs({ Vector2.new(-0.55, -0.55), Vector2.new(0.55, -0.55), Vector2.new(-0.55, 0.55), Vector2.new(0.55, 0.55) }) do
		rivet("Trim", Vector3.new(x + o.X, 1.1 + o.Y, 6.66))
	end
	P(B, "Trim", "EndSideGlow", "Block", Vector3.new(0.08, 0.9, 0.36), Vector3.new(x + s * 1.08, 1.1, 5.8), GLOW, NEON, nil, { Accent = true })

	-- the squat crenellated tower
	local tx, tz = s * 3.95, -4.0
	P(B, "Chassis", "TowerBase", "Block", Vector3.new(2.7, 2.9, 2.6), Vector3.new(tx, 1.45, tz), RED, SP, nil, { CanCollide = true })
	P(B, "Trim", "TowerBaseTop", "Block", Vector3.new(2.8, 0.22, 2.7), Vector3.new(tx, 2.95, tz), RED_D)
	for _, ox in ipairs({ -0.75, 0.75 }) do
		P(B, "Trim", "BasePanel", "Block", Vector3.new(1.0, 1.7, 0.1), Vector3.new(tx + ox, 1.45, tz + 1.32), RED_D)
	end
	rivet("Trim", Vector3.new(tx - 1.15, 2.6, tz + 1.33))
	rivet("Trim", Vector3.new(tx + 1.15, 2.6, tz + 1.33))
	P(B, "Chassis", "Tower", "Block", Vector3.new(2.3, 3.6, 2.3), Vector3.new(tx, 4.85, tz), CHAR, SP, nil, { CanCollide = true })
	P(B, "Trim", "TowerBand", "Block", Vector3.new(2.38, 0.95, 2.38), Vector3.new(tx, 5.95, tz), RED)
	for i = -1, 1 do
		P(B, "Trim", "Slit", "Block", Vector3.new(0.2, 0.6, 0.1), Vector3.new(tx + i * 0.45, 5.95, tz + 1.2), GLOW, NEON, nil, { Accent = true })
	end
	P(B, "Trim", "TowerCap", "Block", Vector3.new(2.9, 0.75, 2.9), Vector3.new(tx, 7.0, tz), STONE)
	for _, o in ipairs({ { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }) do
		P(B, "Trim", "Merlon", "Block", Vector3.new(0.78, 0.8, 0.78), Vector3.new(tx + o[1] * 1.06, 7.77, tz + o[2] * 1.06), STONE)
	end
	P(B, "Trim", "MerlonFloor", "Block", Vector3.new(1.4, 0.1, 1.4), Vector3.new(tx, 7.42, tz), CHAR_D)

	-- flat rook banner on the tower front (gold border, pointed bottom, gold rook)
	local bz = tz + 1.2
	P(B, "Trim", "BannerBack", "Block", Vector3.new(1.2, 1.55, 0.06), Vector3.new(tx, 4.35, bz + 0.02), GOLD, METAL)
	P(B, "Trim", "BannerPointBack", "Block", Vector3.new(0.85, 0.85, 0.06), Vector3.new(tx, 3.58, bz + 0.02), GOLD, METAL, Vector3.new(0, 0, 45))
	P(B, "Trim", "Banner", "Block", Vector3.new(1.0, 1.42, 0.08), Vector3.new(tx, 4.38, bz + 0.05), RED)
	P(B, "Trim", "BannerPoint", "Block", Vector3.new(0.7, 0.7, 0.08), Vector3.new(tx, 3.66, bz + 0.05), RED, SP, Vector3.new(0, 0, 45))
	P(B, "Trim", "BannerRod", "Block", Vector3.new(1.4, 0.14, 0.14), Vector3.new(tx, 5.18, bz + 0.08), GOLD, METAL)
	-- gold rook on the banner
	local gz = bz + 0.1
	P(B, "Trim", "RookBase", "Block", Vector3.new(0.56, 0.12, 0.04), Vector3.new(tx, 3.92, gz), GOLD, METAL)
	P(B, "Trim", "RookBody", "Block", Vector3.new(0.3, 0.5, 0.04), Vector3.new(tx, 4.25, gz), GOLD, METAL)
	P(B, "Trim", "RookTop", "Block", Vector3.new(0.48, 0.14, 0.04), Vector3.new(tx, 4.56, gz), GOLD, METAL)
	for i = -1, 1 do
		P(B, "Trim", "RookMerlon", "Block", Vector3.new(0.11, 0.13, 0.04), Vector3.new(tx + i * 0.18, 4.69, gz), GOLD, METAL)
	end
end)

-- armoured horizontal console between the towers
local CY, CZ = 5.35, -4.0
P(B, "Console", "Beam", "Block", Vector3.new(5.6, 1.5, 1.5), Vector3.new(0, CY, CZ), RED, SP, nil, { CanCollide = true })
P(B, "Console", "BeamTop", "Block", Vector3.new(5.6, 0.2, 1.5), Vector3.new(0, CY + 0.85, CZ), RED_L)
P(B, "Console", "BeamUnder", "Block", Vector3.new(5.6, 0.22, 1.56), Vector3.new(0, CY - 0.82, CZ), CHAR_D)
T.pair(function(s)
	-- braces under the beam (gives the gateway its arch corners)
	P(B, "Console", "Brace", "Wedge", Vector3.new(0.9, 0.9, 1.3), Vector3.new(s * 2.35, CY - 1.38, CZ), RED_D, SP, Vector3.new(0, s * 90, 180))
end)
-- gunmetal armour plate with angled corners and the dark grille
P(B, "Console", "ArmourPlate", "Block", Vector3.new(3.3, 1.25, 0.18), Vector3.new(0, CY, CZ + 0.8), GUN, METAL)
T.pair(function(s)
	P(B, "Console", "ArmourWing", "Block", Vector3.new(0.9, 0.9, 0.18), Vector3.new(s * 1.65, CY, CZ + 0.8), GUN, METAL, Vector3.new(0, 0, 45))
	rivet("Console", Vector3.new(s * 1.3, CY + 0.42, CZ + 0.9))
	rivet("Console", Vector3.new(s * 1.3, CY - 0.42, CZ + 0.9))
end)
T.styleAnchors(B, BELT, Vector3.new(2.2, 0.85, 0.1), Vector3.new(0, CY, CZ + 0.9), nil, CHAR_D)
for i = -1, 1 do
	P(B, "Console", "GrilleSlot", "Block", Vector3.new(1.6, 0.12, 0.06), Vector3.new(0, CY + i * 0.24, CZ + 0.97), GLOW, NEON, nil, { Accent = true })
end
-- raised crown with the small inset red gem
P(B, "Console", "GemMount", "Block", Vector3.new(1.7, 0.6, 1.3), Vector3.new(0, CY + 1.2, CZ), RED_D)
P(B, "Console", "GemMountTop", "Block", Vector3.new(1.2, 0.2, 1.0), Vector3.new(0, CY + 1.6, CZ), RED)
P(B, "Console", "GemSetting", "Block", Vector3.new(0.95, 0.95, 0.14), Vector3.new(0, CY + 1.25, CZ + 0.66), CHAR, METAL, Vector3.new(0, 0, 45))
P(B, "Console", "Gem", "Block", Vector3.new(0.68, 0.68, 0.3), Vector3.new(0, CY + 1.25, CZ + 0.72), GEM, GLASS, Vector3.new(0, 0, 45), { Accent = true, Transparency = 0.05 })
P(B, "Console", "GemCore", "Block", Vector3.new(0.34, 0.34, 0.36), Vector3.new(0, CY + 1.25, CZ + 0.72), rgb(255, 90, 80), NEON, Vector3.new(0, 0, 45), { Accent = true })

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.9, 0.9))
T.attach(B, "RailR", Vector3.new(RX, 1.9, 0.9))
T.attach(B, "Console", Vector3.new(0, CY, CZ + 1.0))
T.attach(B, "TowerL", Vector3.new(-3.95, 8.2, -4.0))
T.attach(B, "TowerR", Vector3.new(3.95, 8.2, -4.0))
T.attach(B, "OuterRing", Vector3.new(0, 0.08, 0.8))
B.visual:SetAttribute("Accent", GLOW)
B.visual:SetAttribute("Style", "rook")
T.finish(B)
