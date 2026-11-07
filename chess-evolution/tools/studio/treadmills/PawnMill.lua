-- [Treadmills] Pawn Mill: friendly starter tier. Low green chassis, rounded entry roller housings with ivory caps,
-- two ivory pawns capping the console supports, warm wood console with a curved top, recessed black panel, 3 lime lights.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("PawnMill")
local rgb, P, SP, NEON, METAL = T.rgb, T.part, T.SP, T.NEON, T.METAL
local GREEN, GREEN_D, GREEN_L = rgb(64, 168, 72), rgb(40, 118, 52), rgb(120, 214, 110)
local IVORY, GOLD = rgb(242, 230, 204), rgb(222, 172, 62)
local WOOD, WOOD_D, WOOD_L = rgb(196, 108, 52), rgb(136, 68, 34), rgb(222, 138, 72)
local BLACK, BELT, STEEL = rgb(24, 25, 30), rgb(30, 31, 37), rgb(150, 154, 164)
local LIME = rgb(95, 255, 60)
local RX = 3.8 -- rail centre
local RH = 1.85 -- rail top

-- belt bed, entry roller and the dark belt (the gameplay Belt part is the running surface)
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.0, 1.0), Vector3.new(0, 0.5, 5.15), BELT)
T.pair(function(s)
	P(B, "BeltVisual", "RollerEnd", "Cylinder", Vector3.new(0.12, 0.7, 0.7), Vector3.new(s * 2.9, 0.5, 5.15), STEEL, METAL)
end)
T.beltLines(B, rgb(46, 48, 56), 5.6, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- side rail: green body, lighter top, dark grip pads, vent and an ivory band by the housing
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.8, RH - 0.25, 8.0), Vector3.new(x, (RH - 0.25) / 2, 1.3), GREEN, SP, nil, { CanCollide = true })
	P(B, "Trim", "RailTop", "Block", Vector3.new(1.8, 0.25, 8.0), Vector3.new(x, RH - 0.125, 1.3), GREEN_L)
	P(B, "Trim", "RailFoot", "Block", Vector3.new(1.86, 0.26, 8.0), Vector3.new(x, 0.13, 1.3), GREEN_D)
	for i = 0, 2 do
		P(B, "Trim", "GripPad", "Block", Vector3.new(0.9, 0.16, 0.9), Vector3.new(x, RH + 0.08, -0.4 + i * 1.2), rgb(44, 46, 52))
	end
	for i = 0, 2 do
		P(B, "Trim", "Vent", "Block", Vector3.new(0.08, 0.16, 1.8), Vector3.new(x + s * 0.91, 0.6 + i * 0.32, 1.6), GREEN_D)
	end
	P(B, "Trim", "IvoryBand", "Block", Vector3.new(1.84, 1.3, 0.6), Vector3.new(x, 0.85, 4.55), IVORY)
	-- rounded entry housing with an ivory cap facing the entry
	T.zcyl(B, "Chassis", "Housing", 1.5, 2.5, Vector3.new(x, 1.25, 5.55), GREEN)
	T.zcyl(B, "Trim", "HousingRim", 0.3, 2.56, Vector3.new(x, 1.25, 6.2), GREEN_D)
	T.zcyl(B, "Trim", "HousingCap", 0.24, 1.7, Vector3.new(x, 1.25, 6.4), IVORY)
	-- raised step toward the supports with a square inset facing the entry
	P(B, "Chassis", "Step", "Block", Vector3.new(1.8, 2.9, 2.4), Vector3.new(x, 1.45, -1.9), GREEN, SP, nil, { CanCollide = true })
	P(B, "Trim", "StepTop", "Block", Vector3.new(1.8, 0.24, 2.4), Vector3.new(x, 3.0, -1.9), GREEN_L)
	P(B, "Trim", "InsetRim", "Block", Vector3.new(1.2, 1.2, 0.08), Vector3.new(x, 1.75, -0.66), GREEN_D)
	P(B, "Trim", "Inset", "Block", Vector3.new(0.84, 0.84, 0.1), Vector3.new(x, 1.75, -0.65), GREEN_L)
	-- console support column, gold collar and the pawn cap
	P(B, "Chassis", "Support", "Block", Vector3.new(1.8, 4.3, 1.8), Vector3.new(x, 2.15, -3.95), GREEN, SP, nil, { CanCollide = true })
	P(B, "Trim", "SupportTop", "Block", Vector3.new(1.9, 0.26, 1.9), Vector3.new(x, 4.4, -3.95), GREEN_D)
	P(B, "Trim", "InsetRim", "Block", Vector3.new(1.05, 1.05, 0.08), Vector3.new(x, 3.55, -3.03), GREEN_D)
	P(B, "Trim", "Inset", "Block", Vector3.new(0.72, 0.72, 0.1), Vector3.new(x, 3.55, -3.02), GREEN_L)
	local px, pz, b = x, -3.95, 4.53
	T.vcyl(B, "Trim", "GoldCollar", 0.34, 1.95, Vector3.new(px, b + 0.17, pz), GOLD)
	T.vcyl(B, "Trim", "PawnBase", 0.42, 1.85, Vector3.new(px, b + 0.55, pz), IVORY)
	T.vcyl(B, "Trim", "PawnFoot", 0.3, 1.5, Vector3.new(px, b + 0.91, pz), IVORY)
	T.vcyl(B, "Trim", "PawnBody", 0.85, 1.18, Vector3.new(px, b + 1.48, pz), IVORY)
	T.vcyl(B, "Trim", "PawnCollar", 0.26, 1.55, Vector3.new(px, b + 2.0, pz), IVORY)
	P(B, "Trim", "PawnHead", "Ball", Vector3.new(1.8, 1.8, 1.8), Vector3.new(px, b + 2.85, pz), IVORY)
end)

-- crossbar between the supports, studded face
P(B, "Chassis", "Crossbar", "Block", Vector3.new(5.8, 1.2, 1.3), Vector3.new(0, 4.1, -4.1), GREEN)
P(B, "Trim", "CrossbarTop", "Block", Vector3.new(5.8, 0.22, 1.3), Vector3.new(0, 4.8, -4.1), GREEN_L)
for i = 0, 5 do
	P(B, "Trim", "Stud", "Block", Vector3.new(0.58, 0.52, 0.16), Vector3.new(-2.3 + i * 0.92, 4.06, -3.4), GREEN_D)
end

-- console: warm wood slab with a curved top, studs on top, recessed black panel, 3 lime lights
local CY, CZ, CW, CH = 6.2, -4.25, 6.0, 2.5
T.roundTop(B, "Console", "Body", CW, CH, 1.4, 0.95, Vector3.new(0, CY, CZ), WOOD)
P(B, "Console", "Base", "Block", Vector3.new(CW + 0.1, 0.26, 1.48), Vector3.new(0, CY - CH / 2 + 0.13, CZ), WOOD_D)
for i = 0, 3 do
	P(B, "Console", "TopStud", "Block", Vector3.new(0.78, 0.38, 0.8), Vector3.new(-1.65 + i * 1.1, CY + CH / 2 + 0.17, CZ), WOOD_L)
end
T.pair(function(s)
	T.zcyl(B, "Console", "Screw", 0.1, 0.34, Vector3.new(s * 2.45, CY - 0.1, CZ + 0.72), STEEL, METAL)
end)
P(B, "Console", "PanelFrame", "Block", Vector3.new(3.7, 1.3, 0.08), Vector3.new(0, CY - 0.1, CZ + 0.72), WOOD_D)
T.styleAnchors(B, BELT, Vector3.new(3.3, 0.98, 0.1), Vector3.new(0, CY - 0.1, CZ + 0.74), nil, BLACK)
for i = -1, 1 do
	P(B, "Console", "Light", "Block", Vector3.new(0.62, 0.22, 0.08), Vector3.new(i * 0.9, CY - 0.1, CZ + 0.82), LIME, NEON, nil, { Accent = true })
end

-- attachments the effects use
T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, RH + 0.1, 1.3))
T.attach(B, "RailR", Vector3.new(RX, RH + 0.1, 1.3))
T.attach(B, "Console", Vector3.new(0, CY, CZ + 0.9))
T.attach(B, "RearCornerL", Vector3.new(-RX - 0.7, 1.0, -4.7))
T.attach(B, "RearCornerR", Vector3.new(RX + 0.7, 1.0, -4.7))
T.attach(B, "OuterRing", Vector3.new(0, 0.3, 0.7))
B.visual:SetAttribute("Accent", LIME)
B.visual:SetAttribute("RingRadius", 7.6)
B.visual:SetAttribute("Style", "pawn")
T.finish(B)
