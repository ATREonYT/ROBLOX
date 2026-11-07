-- [Treadmills] Knight Sprint: fast, angular. Cobalt wedge chassis with silver edge plates and frosted cyan channels,
-- two blue knight heads as the console supports, sloped black console with three cyan indicators, swept side arms.
local T = require(game.ServerStorage.TreadmillTools.Lib)
local B = T.begin("KnightSprint")
local rgb, P, SP, NEON, METAL = T.rgb, T.part, T.SP, T.NEON, T.METAL
local COBALT, COBALT_D, COBALT_L = rgb(38, 92, 222), rgb(26, 60, 160), rgb(78, 140, 250)
local SILVER, SILVER_D = rgb(176, 184, 198), rgb(120, 128, 144)
local BLACK, CHAR, BELT = rgb(22, 24, 30), rgb(52, 56, 66), rgb(30, 31, 37)
local CYAN = rgb(70, 225, 255)
local RX = 3.8

-- belt
P(B, "Chassis", "BeltBed", "Block", Vector3.new(5.8, 0.5, 10.6), Vector3.new(0, 0.25, 0.3), BLACK)
P(B, "BeltVisual", "EntryRoller", "Cylinder", Vector3.new(5.7, 1.0, 1.0), Vector3.new(0, 0.5, 5.15), BELT)
T.pair(function(s)
	P(B, "BeltVisual", "RollerEnd", "Cylinder", Vector3.new(0.12, 0.72, 0.72), Vector3.new(s * 2.9, 0.5, 5.15), SILVER, METAL)
	-- frosted cyan channel along the belt edge
	P(B, "Trim", "BeltEdge", "Block", Vector3.new(0.16, 0.06, 9.0), Vector3.new(s * 2.78, 0.83, 0.5), CYAN, NEON, nil, { Accent = true, Transparency = 0.2 })
end)
P(B, "Trim", "BeltEdgeEnd", "Block", Vector3.new(5.4, 0.06, 0.16), Vector3.new(0, 0.83, -3.95), CYAN, NEON, nil, { Accent = true, Transparency = 0.2 })
T.beltLines(B, rgb(46, 48, 58), 5.4, -4.1, 5.0, 0.9)

T.pair(function(s)
	local x = s * RX
	-- low rail, then a swept wedge rising to the console end
	P(B, "Chassis", "Rail", "Block", Vector3.new(1.8, 1.1, 10.2), Vector3.new(x, 0.55, 0.6), COBALT, SP, nil, { CanCollide = true })
	P(B, "Chassis", "Sweep", "Wedge", Vector3.new(1.8, 1.9, 6.4), Vector3.new(x, 2.05, -1.0), COBALT, SP, Vector3.new(0, 180, 0), { CanCollide = true })
	-- silver edge plates along the foot and at the top of the low rail
	P(B, "Trim", "EdgePlate", "Block", Vector3.new(1.86, 0.3, 10.2), Vector3.new(x, 0.15, 0.6), SILVER_D, METAL)
	P(B, "Trim", "EdgePlateTop", "Block", Vector3.new(1.84, 0.16, 3.8), Vector3.new(x, 1.18, 3.8), SILVER, METAL)
	-- studs on the low rail
	for i = 0, 2 do
		P(B, "Trim", "Stud", "Block", Vector3.new(0.5, 0.26, 0.5), Vector3.new(x, 1.38, 2.6 + i * 1.0), COBALT_L)
	end
	-- frosted cyan channel framing the outer face of the sweep
	local ox = x + s * 0.92
	P(B, "Trim", "Channel", "Block", Vector3.new(0.06, 0.14, 3.6), Vector3.new(ox, 0.75, 0.4), CYAN, NEON, nil, { Accent = true, Transparency = 0.25 })
	P(B, "Trim", "Channel", "Block", Vector3.new(0.06, 0.14, 2.2), Vector3.new(ox, 1.85, -2.1), CYAN, NEON, nil, { Accent = true, Transparency = 0.25 })
	P(B, "Trim", "Channel", "Block", Vector3.new(0.06, 1.24, 0.14), Vector3.new(ox, 1.3, -3.2), CYAN, NEON, nil, { Accent = true, Transparency = 0.25 })
	P(B, "Trim", "Channel", "Block", Vector3.new(0.06, 0.9, 0.14), Vector3.new(ox, 1.25, -1.0), CYAN, NEON, nil, { Accent = true, Transparency = 0.25 })
	-- vent grille on the outer face near the console end
	for i = 0, 3 do
		P(B, "Trim", "Vent", "Block", Vector3.new(0.08, 0.12, 1.1), Vector3.new(ox, 0.5 + i * 0.22, -3.6 + 1.6), CHAR)
	end
	-- angular entry cap: silver face plate with a cyan bracket and screws
	P(B, "Chassis", "EntryCap", "Block", Vector3.new(1.9, 1.5, 0.9), Vector3.new(x, 0.75, 5.95), COBALT, SP, nil, { CanCollide = true })
	P(B, "Chassis", "EntryCapTop", "Wedge", Vector3.new(1.9, 0.5, 0.9), Vector3.new(x, 1.75, 5.95), COBALT, SP)
	P(B, "Trim", "EntryPlate", "Block", Vector3.new(1.5, 1.1, 0.1), Vector3.new(x, 0.8, 6.42), COBALT_D)
	P(B, "Trim", "Bracket", "Block", Vector3.new(0.12, 0.62, 0.06), Vector3.new(x - 0.3, 0.8, 6.48), CYAN, NEON, nil, { Accent = true })
	P(B, "Trim", "Bracket", "Block", Vector3.new(0.42, 0.12, 0.06), Vector3.new(x - 0.15, 1.1, 6.48), CYAN, NEON, nil, { Accent = true })
	P(B, "Trim", "Bracket", "Block", Vector3.new(0.42, 0.12, 0.06), Vector3.new(x - 0.15, 0.5, 6.48), CYAN, NEON, nil, { Accent = true })
	for _, d in ipairs({ { 0.5, 0.4 }, { 0.5, 1.2 } }) do
		T.zcyl(B, "Trim", "Screw", 0.08, 0.26, Vector3.new(x + d[1], d[2], 6.48), SILVER, METAL)
	end

	-- knight head support: pedestal, silver collar, then the head (muzzle turned out and toward the entry)
	P(B, "Chassis", "Pedestal", "Block", Vector3.new(2.0, 3.3, 2.2), Vector3.new(x, 1.65, -4.1), COBALT, SP, nil, { CanCollide = true })
	P(B, "Trim", "PedestalBand", "Block", Vector3.new(2.1, 0.45, 2.3), Vector3.new(x, 3.35, -4.1), SILVER, METAL)
	local yaw = 210 -- both heads look the same way, toward the left and the entry (as in the art)
	local base = T.cf(B, Vector3.new(x, 3.55, -4.1), Vector3.new(0, yaw, 0))
	local K = 1.3 -- head scale
	local function H(name, shape, size, pos, color, mat, rot, opts)
		local p = P(B, "Trim", name, shape, size * K, Vector3.zero, color, mat, nil, opts)
		local r = rot or Vector3.zero
		p.CFrame = base * CFrame.new(pos * K) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		return p
	end
	-- local head frame: +X = muzzle direction, Y up
	H("KnightChest", "Block", Vector3.new(1.9, 0.9, 1.7), Vector3.new(0.1, 0.45, 0), COBALT_D)
	H("KnightNeck", "Block", Vector3.new(1.45, 2.3, 1.35), Vector3.new(0.05, 1.85, 0), COBALT, SP, Vector3.new(0, 0, -12))
	H("KnightHead", "Block", Vector3.new(2.3, 1.15, 1.3), Vector3.new(0.75, 3.05, 0), COBALT, SP, Vector3.new(0, 0, -24))
	H("KnightMuzzle", "Block", Vector3.new(0.95, 0.85, 1.2), Vector3.new(1.75, 2.48, 0), COBALT, SP, Vector3.new(0, 0, -24))
	H("KnightNose", "Block", Vector3.new(0.12, 0.5, 1.22), Vector3.new(2.22, 2.3, 0), COBALT_D, SP, Vector3.new(0, 0, -24))
	H("KnightJaw", "Wedge", Vector3.new(1.2, 0.7, 1.4), Vector3.new(0.85, 2.05, 0), COBALT_D, SP, Vector3.new(0, -90, 0))
	H("KnightBrow", "Block", Vector3.new(1.3, 0.75, 1.25), Vector3.new(-0.05, 3.55, 0), COBALT, SP, Vector3.new(0, 0, -10))
	for _, z in ipairs({ -0.35, 0.35 }) do
		H("KnightEar", "Wedge", Vector3.new(0.3, 0.75, 0.4), Vector3.new(-0.3, 4.2, z), COBALT_L, SP, Vector3.new(0, 90, 0))
		H("KnightEye", "Block", Vector3.new(0.42, 0.16, 0.06), Vector3.new(0.75, 3.2, z * 1.9), CYAN, NEON, Vector3.new(0, 0, -18), { Accent = true })
		H("KnightCheekLine", "Block", Vector3.new(0.08, 1.5, 0.05), Vector3.new(-0.15, 1.9, z * 1.97), CYAN, NEON, Vector3.new(0, 0, -12), { Accent = true, Transparency = 0.2 })
	end
	-- stepped mane down the back of the neck
	for i = 0, 4 do
		H("KnightMane", "Block", Vector3.new(0.6, 0.62, 0.8), Vector3.new(-0.85 - i * 0.08, 3.75 - i * 0.62, 0), if i % 2 == 0 then COBALT_D else COBALT_L, SP, Vector3.new(0, 0, -12))
	end
	H("KnightCollar", "Block", Vector3.new(2.0, 0.3, 1.8), Vector3.new(0.1, 0.95, 0), SILVER, METAL)
end)

-- crossbar under the console with a cyan line
P(B, "Chassis", "Crossbar", "Block", Vector3.new(5.8, 0.9, 1.1), Vector3.new(0, 3.1, -4.2), COBALT_D)
P(B, "Trim", "CrossbarLine", "Block", Vector3.new(5.0, 0.12, 0.06), Vector3.new(0, 3.1, -3.62), CYAN, NEON, nil, { Accent = true })
for i = 0, 2 do
	P(B, "Trim", "CrossbarStud", "Block", Vector3.new(0.6, 0.3, 0.6), Vector3.new(-1.2 + i * 1.2, 3.7, -4.2), SILVER, METAL)
end

-- sloped black console between the heads, three cyan slashes
local CY, CZ, TILT = 5.0, -4.05, -22
local c = T.cf(B, Vector3.new(0, CY, CZ), Vector3.new(TILT, 0, 0))
local function C(name, size, off, color, mat, rotZ, opts)
	local p = P(B, "Console", name, "Block", size, Vector3.zero, color, mat, nil, opts)
	p.CFrame = c * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(rotZ or 0))
	return p
end
C("Housing", Vector3.new(4.4, 1.9, 1.0), Vector3.new(0, 0, 0), CHAR)
C("TopFrame", Vector3.new(4.6, 0.4, 1.15), Vector3.new(0, 1.1, 0), COBALT)
C("BottomFrame", Vector3.new(4.6, 0.3, 1.15), Vector3.new(0, -1.05, 0), COBALT_D)
for _, sx in ipairs({ -1.85, 1.85 }) do
	for _, sy in ipairs({ -0.62, 0.62 }) do
		local sc = P(B, "Console", "Screw", "Cylinder", Vector3.new(0.08, 0.26, 0.26), Vector3.zero, SILVER, METAL)
		sc.CFrame = c * CFrame.new(sx, sy, 0.52) * CFrame.Angles(0, math.rad(90), 0)
	end
end
local screen = B.station:FindFirstChild("Screen") :: BasePart
T.styleAnchors(B, BELT, Vector3.new(3.1, 1.15, 0.1), Vector3.new(0, CY, CZ), Vector3.new(TILT, 0, 0), BLACK)
screen.CFrame = c * CFrame.new(0, 0, 0.5)
for i = -1, 1 do
	C("Light", Vector3.new(0.22, 0.62, 0.06), Vector3.new(i * 0.62, 0, 0.57), CYAN, NEON, -28, { Accent = true })
end

T.attach(B, "DeckCentre", Vector3.new(0, 0.85, 0.4))
T.attach(B, "BeltStart", Vector3.new(0, 0.86, -3.9))
T.attach(B, "BeltEnd", Vector3.new(0, 0.86, 5.0))
T.attach(B, "RailL", Vector3.new(-RX, 1.4, 1.0))
T.attach(B, "RailR", Vector3.new(RX, 1.4, 1.0))
T.attach(B, "Console", Vector3.new(0, CY, CZ + 0.9))
T.attach(B, "HeadL", Vector3.new(-RX, 6.0, -4.1))
T.attach(B, "HeadR", Vector3.new(RX, 6.0, -4.1))
T.attach(B, "OuterRing", Vector3.new(0, 0.3, 0.6))
B.visual:SetAttribute("Accent", CYAN)
B.visual:SetAttribute("Style", "knight")
T.finish(B)
