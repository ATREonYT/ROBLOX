-- The Block V2: "+1 Hood Evolution", World 1, copied from the user's reference pictures:
--   the lobby hall (spawn, the 8 shooting ranges, the ARMORY)
--   stages 1-15, each the reference street (ref1_street.png): a studded asphalt road with a yellow dashed line,
--     studded sidewalks and grass, plank fences, stacked-cube trees, tall navy lamps, two-storey red brick
--     buildings, and end buildings that close in round the next stage's wall
--   the boss yard (Champ Ring, the BOSS pad)
-- Every stage starts with a gate that needs more power than the last (V2.StagePower); every range trains in
-- the lobby. A ring road with trees and parked cars runs round the outside.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on and applies
-- the bright, slightly softened lighting (HoodLighting HoodSoft) (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Hooks: gates are HoodStageGate (StageService/HoodClient.Stages). Each stage's pad is tagged HoodFightPad
-- (Fight = stage, 16 = the boss) for the fight system to come. The lobby's Morphs stand is where looks are
-- equipped; Training_<Id> stations (8 in the lobby, the Ring in the boss yard) train.
--
-- Layout (local studs, floor top at y = 0, players walk toward -Z):
--   lobby         x -67..67, z 6..157 (a warehouse; its north door opens onto stage 1)
--   stage i       x -36..36, z -(i-1)*64 .. -i*64, gate on its first line; buildings x ±36..±64 (±22 for the
--                 last 8 studs, round the next gate)
--   boss yard     x -36..36, z -960..-1056
--   ring road     outside a low wall at x ±70 (and past both ends)
local V2 = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local S = Enum.SurfaceType
local Props, PROPS_KIT, SKINS -- HoodProps (the Champ Ring), the helpers it borrows, Config.Skins: set in Build

V2.Origin = CFrame.new(2400, 0, 0)

-- Palette, taken from the concept: bold, simple, one look per district.
local P = {
	-- Ground.
	tileA = C(206, 208, 213), tileB = C(193, 196, 202), band = C(146, 149, 156), bandLine = C(236, 236, 238),
	kerb = C(222, 222, 226), wall = C(214, 214, 218), grass = C(104, 178, 72), asphalt = C(70, 72, 78), roadLine = C(240, 240, 240),
	court = C(236, 142, 58), courtLine = C(250, 246, 236),
	-- Buildings.
	brick = C(176, 74, 58), brickDark = C(150, 64, 52), brickPink = C(198, 112, 92), slate = C(62, 68, 84), stone = C(158, 158, 164),
	tan = C(224, 184, 128), tanLight = C(238, 208, 160), tanDark = C(178, 150, 112),
	glass = C(48, 68, 100), frame = C(214, 214, 220), door = C(42, 118, 78), doorDark = C(48, 52, 62),
	barberBlue = C(38, 72, 168), groceryGreen = C(38, 148, 62), groceryYellow = C(250, 204, 48), shopBlue = C(52, 92, 196),
	warehouse = C(40, 90, 190), warehouseDark = C(30, 66, 146), rollDoor = C(72, 76, 84),
	-- Props.
	leaf = C(112, 192, 62), leafDark = C(96, 176, 52), hedge = C(80, 168, 62), trunk = C(122, 82, 52), planter = C(196, 196, 202),
	iron = C(36, 38, 44), lampGlow = C(255, 214, 120), wood = C(196, 128, 68), woodDark = C(150, 96, 52), crate = C(206, 148, 76),
	dumpster = C(44, 132, 72), black = C(28, 30, 34), white = C(250, 250, 250),
	containerRed = C(196, 52, 42), containerBlue = C(44, 96, 186),
	-- Fight pads and banners.
	padRed = C(230, 52, 52), padBlue = C(40, 104, 232), padGreen = C(44, 192, 82), bossRing = C(80, 255, 120),
	spawnBlue = C(60, 190, 255), evolveBlue = C(40, 88, 210), evolveYellow = C(252, 206, 52),
	district = { C(222, 52, 52), C(132, 62, 212), C(240, 132, 30), C(214, 116, 40), C(42, 104, 222) },
	-- The stage street, sampled from ref1_street.png (lit faces; every surface studded like the picture), then set so
	-- a render13 preview (Roblox's light model) under the game's HoodSun lighting reads the picture's RGB on the sunlit
	-- ground and facades (HoodSun v4: sun (0.50, 0.80, 0.33); vertical faces are lifted more than the picture's own
	-- Color3s would be, since this sun is higher than the picture's).
	st = {
		road = C(58, 74, 96), dash = C(255, 243, 50), walk = C(160, 172, 190), grass = C(38, 212, 92),
		brick = C(203, 118, 85), trim = C(199, 177, 175), band = C(182, 196, 222), roof = C(102, 136, 180),
		glassA = C(162, 204, 250), glassB = C(190, 218, 243), mullion = C(44, 86, 142),
		fence = { C(229, 122, 63), C(143, 79, 71), C(192, 100, 64), C(143, 79, 71) }, -- light, dark, mid, dark
		lamp = C(13, 44, 78), lampGlow = C(255, 244, 196),
		leaf = C(32, 250, 56), trunk = C(97, 90, 103), hedge = C(26, 196, 70), dumpster = C(14, 190, 78),
		petal = C(30, 70, 156), petalEye = C(250, 232, 70), stem = C(40, 180, 82), garbage = C(230, 130, 46),
		-- Second and third tones (developer-level shading: every surface in 2-3 shades of its colour).
		brickDark = C(166, 97, 71), brickDeep = C(187, 102, 71), brickLight = C(217, 136, 95), sill = C(233, 210, 200),
		trimDark = C(159, 141, 142), roofDark = C(76, 100, 138),
		gutter = C(70, 80, 100), roadDark = C(48, 62, 82), kerbStone = C(184, 192, 206), walkJoint = C(132, 142, 160),
		grassDark = C(28, 176, 76), grassEdge = C(24, 160, 70), leafDark = C(26, 214, 48), lampDark = C(8, 30, 55),
		lampLight = C(40, 75, 118), plankDark = C(104, 56, 48), dumpsterDark = C(10, 150, 60), manhole = C(70, 74, 84),
	},
	-- Its cross-section, measured from the picture (studs from the centre line, heights from the road top):
	-- road |x| < road, sidewalk to road + walk (top at kerb), grass to front, the plank fence at fence, building
	-- fronts at front; the last SLEN - endZ studs of each stage narrow to |x| = open, framing the next gate's wall.
	street = { road = 8.5, walk = 8, kerb = 0.6, front = 36, open = 22, fence = 34.5, endZ = 56, eave = 30, band = 15, sills = { 4, 19 }, winH = 8.5 },
}
---------------------------------------------------------------------------------------------- build context
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, cf) return setmetatable({ parent = parent, cf = cf }, Ctx) end
function Ctx:at(cf) return newCtx(self.parent, self.cf * cf) end
function Ctx:into(parent) return newCtx(parent, self.cf) end
function Ctx:group(name, class)
	local g = Instance.new(class or 'Model')
	g.Name = name
	g.Parent = self.parent
	return newCtx(g, self.cf), g
end
function Ctx:world(cf) return V2.Origin * self.cf * cf end
local function smooth(p)
	for _, face in { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' } do p[face] = S.Smooth end
end
function Ctx:part(name, size, cf, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	if shape then p.Shape = shape end
	p.Parent = self.parent
	return p
end
-- Axis-aligned box between two corners (in this context's frame).
function Ctx:box(name, a, b, color, material)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end
-- Upright cylinder standing on pos.
function Ctx:post(name, radius, height, pos, color, material)
	return self:part(name, V(height, radius * 2, radius * 2), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Cylinder lying along the X axis of cf.
function Ctx:rod(name, radius, length, cf, color, material)
	return self:part(name, V(length, radius * 2, radius * 2), cf, color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Square bar from a to b.
function Ctx:bar(name, a, b, width, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	return self:part(name, V(width, width, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material or M.Metal)
end
function Ctx:blob(name, size, pos, color, material)
	local p = self:part(name, size, CFrame.new(pos), color, material)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Ctx:wedge(name, size, cf, color, material)
	local p = Instance.new('WedgePart')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	p.Parent = self.parent
	return p
end

-- Classic Roblox studs on the top (and optionally the sides) of a part.
local function studs(p, sides)
	p.Material = M.Plastic
	p.TopSurface = S.Studs
	if sides then
		p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = S.Studs, S.Studs, S.Studs, S.Studs
	end
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end
local function ghost(p)
	decor(p).Transparency = 1
	return p
end
local function light(p, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
	return l
end

---------------------------------------------------------------------------------------------- text
local FONT = { title = Enum.Font.FredokaOne, loud = Enum.Font.LuckiestGuy, body = Enum.Font.GothamBlack, tag = Enum.Font.PermanentMarker }
local function surface(p, face, ppS)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 0
	g.Parent = p
	return g
end
-- One line of text in a band of the gui (y and h are 0-1), with a clean outline.
local function line(gui, name, value, color, font, y, h, outline, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Font = font
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextStrokeTransparency = 1
	if outline then
		local s = Instance.new('UIStroke')
		s.Color = outline
		s.Thickness = thickness or 2
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	t.Parent = gui
	return t
end
local function billboard(ctx, pos, w, h, rows)
	local a = ghost(ctx:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.Parent = a
	for _, r in rows do line(g, r[1], r[2], r[3], r[4], r[5], r[6], P.black, 2) end
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

---------------------------------------------------------------------------------------------- layout
local FRONT = 36 -- building fronts at x = ±36, facing the middle
local DEPTH = 28 -- buildings run back to x = ±64
local WALL_X = 124 -- the low boundary wall (round the lobby hall, x +-74, and the stage districts, which reach x +-92..111)
local SLEN = 64 -- one stage
local STAGES = 15
local SPAWN_W, SPAWN_TOP = 74, 136 -- the lobby hall's outside walls: x -74..74, z 5..136 (Lobby, e2_lobby: interior 146 x 129)
local BOSS_TOP = -STAGES * SLEN -- -960
local BOSS_END = BOSS_TOP - 96 -- the boss yard runs to -1056
local SPAWN = V(0, 0, 55) -- the spawn on the hall's cross, where the spine meets the cross arm (on the floor), facing north
local function stageTop(i) return -(i - 1) * SLEN end
local function lookOf(i) return (i - 1) // 3 + 1 end -- 1..5: three stages share a look
local function trioOf(i) return (i - 1) % 3 + 1 end -- 1..3: place within the look
local function gateZ(i) return stageTop(i) end -- gate i opens stage i (16 opens the boss yard)
local function padZ(i) return stageTop(i) - 32 end
local PAD_SIZE = 12

-- Power to get into each stage, and into the boss yard (16). Each step is harder than the last. Every lane trains
-- in the lobby (the Champ Ring is in the boss yard), so players come back between pushes. The numbers are the
-- economy's (Config/Balance.StagePower, paced with the rebirths); the list here is only a fallback without it.
local STAGE_POWER = { 10, 60, 250, 800, 1600, 6000, 17000, 40000, 95000, 210000, 440000, 950000, 2000000, 4000000, 8000000, 34000000 }
do
	local ok, Balance = pcall(function() return require(ReplicatedStorage.Shared.Config.Balance) end)
	if ok and type(Balance) == 'table' and type(Balance.StagePower) == 'table' and #Balance.StagePower == 16 then STAGE_POWER = table.clone(Balance.StagePower) end
end
V2.StagePower = STAGE_POWER
V2.StageLength = SLEN
V2.StageTop = stageTop

-- Every stage's pad in walking order, then the boss: the fight system can read them straight from here.
V2.Fights = {}
for i = 1, STAGES do table.insert(V2.Fights, { Fight = i, Stage = i, Look = lookOf(i), X = 0, Z = padZ(i) }) end
table.insert(V2.Fights, { Fight = 16, Stage = 16, Look = 6, X = 0, Z = BOSS_END + 22, Boss = true })
---------------------------------------------------------------------------------------------- asset kit
-- The concept's "Asset Kit (simple Roblox parts)". All positions are in the given context's frame.
local function plank(c, name, a, b, width, thick, color, material)
	return c:part(name, V(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or M.SmoothPlastic)
end

-- The reference street's props (ref1_street.png): chunky blocks, studded on every face, sized from the picture.
-- A studded box between two corners (the street kit's only brick).
local function sbox(c, name, a, b, color, isDecor)
	local p = studs(c:box(name, a, b, color, M.Plastic), true)
	if isDecor then decor(p) end
	return p
end
-- Tree of stacked green cubes on a short grey trunk, measured from the picture (top ~15.8 above the grass, crown
-- ~7 wide and ~12 tall, trunk ~3 wide and ~3.8 tall): three tiers that step in and wander a little, darker below and
-- lighter toward the sunlit top, a cap, a thin side block, and a soil pit round the trunk. seed varies it; yaw
-- (degrees) turns it (the picture's trees stand at an angle to the street).
local function tree(c, pos, seed, scale, yaw, simple)
	local r = Random.new(seed)
	local s = scale or 1
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or r:NextInteger(0, 3) * 90), 0)):group('Tree')
	local leaf, dark = P.st.leaf, P.st.leafDark
	local function B(name, a, b, col) return sbox(t, name, a * s, b * s, col) end
	local function off() return r:NextInteger(-1, 1) * 0.5 end
	if not simple then -- (simple: the ring road's trees behind the buildings skip the small parts)
		decor(sbox(t, 'TreePit', V(-2.4, -0.05, -2.4) * s, V(2.4, 0.15, 2.4) * s, C(110, 84, 64)))
		B('TrunkRing', V(-1.7, 0, -1.7), V(1.7, 0.7, 1.7), P.st.trunk:Lerp(P.black, 0.2))
	end
	B('Trunk', V(-1.5, 0, -1.5), V(1.5, 3.8, 1.5), P.st.trunk)
	B('Crown', V(-3.5, 3.8, -3.5), V(3.5, 8.6, 3.5), dark)
	local x2, z2 = off(), off()
	B('Crown', V(-3 + x2, 8.6, -3 + z2), V(3 + x2, 12.4, 3 + z2), leaf)
	local x3, z3 = x2 + off(), z2 + off()
	B('Crown', V(-2.2 + x3, 12.4, -2.2 + z3), V(2.2 + x3, 14.8, 2.2 + z3), leaf:Lerp(P.white, 0.1))
	B('CrownTop', V(-1.3 + x3, 14.8, -1.3 + z3), V(1.3 + x3, 15.8, 1.3 + z3), leaf:Lerp(P.white, 0.16))
	if not simple then B('CrownSide', V(3.5, 6.6, -1.5), V(4.3, 10.6, 1.5), dark:Lerp(P.black, 0.08)) end
	return t
end
-- Low hedge of two stacked green blocks (the ones on the reference's grass), long along Z: a darker lower block on a
-- dark green foot, a lighter top block.
local function hedge(c, pos, len)
	len = len or 6
	local h = c:at(CFrame.new(pos)):group('Hedge')
	decor(sbox(h, 'HedgeFoot', V(-1.8, -0.05, -len / 2 - 0.2), V(1.8, 0.3, len / 2 + 0.2), P.st.grassEdge))
	sbox(h, 'Hedge', V(-1.6, 0, -len / 2), V(1.6, 2.2, len / 2), P.st.hedge:Lerp(P.black, 0.08))
	sbox(h, 'Hedge', V(-1.2, 2.2, -len / 2), V(1.2, 3.8, len / 2 - 2), P.st.hedge:Lerp(P.st.leaf, 0.5):Lerp(P.white, 0.06))
	return h
end
-- Wooden plank fence along Z at x from z0 to z1 (the picture's front-yard fence, ~8 tall): 2-stud planks, 1 thick,
-- alternating light / dark wood (the light ones in two tones), every other plank stepped toward the street (side = the
-- street's direction, +1 or -1), each capped with a steep wedge that slopes down toward the street, heights jittered;
-- a dark post with a light cap every four planks. gaps = { { za, zb } } (world z) leave gateways: a tall post either
-- side and a plank gate standing open into the yard.
local function fence(c, x, z0, z1, side, h, gaps)
	h = h or 6.8
	local f = c:group('Fence')
	local n = math.max(1, math.floor(math.abs(z1 - z0) / 2 + 0.5))
	local w = (z1 - z0) / n
	local function inGap(za, zb)
		for _, g in gaps or {} do
			if math.max(za, zb) > math.min(g[1], g[2]) + 0.05 and math.min(za, zb) < math.max(g[1], g[2]) - 0.05 then return true end
		end
		return false
	end
	for k = 0, n - 1 do
		local za, zb = z0 + k * w, z0 + (k + 1) * w
		if not inGap(za, zb) then
			local col = P.st.fence[k % #P.st.fence + 1]
			local xm = x + (k % 2 == 1 and side * 0.5 or 0)
			local hk = h + ((k * 7) % 3 - 1) * 0.4
			sbox(f, 'FencePlank', V(xm - 0.5, 0, za), V(xm + 0.5, hk, zb), col)
			-- (a wedge rises toward its local +Z: turn that away from the street)
			studs(f:wedge('FencePlankTop', V(math.abs(w), 1.8, 1), CFrame.new(xm, hk + 0.9, (za + zb) / 2) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0), col, M.Plastic), true)
			if k % 4 == 0 and k > 0 and not inGap(za - 1, za + 1) then
				local p0, p1 = x - 0.7 + math.min(0, side * 0.5), x + 0.7 + math.max(0, side * 0.5)
				sbox(f, 'FencePost', V(p0, 0, za - 0.7), V(p1, h + 2.2, za + 0.7), P.st.plankDark)
				sbox(f, 'FencePostCap', V(p0 - 0.2, h + 2.2, za - 0.9), V(p1 + 0.2, h + 2.7, za + 0.9), P.st.fence[1], true)
			end
		end
	end
	for _, g in gaps or {} do
		local ga, gb = math.min(g[1], g[2]), math.max(g[1], g[2])
		for _, zp in { ga, gb } do
			sbox(f, 'GatePost', V(x - 0.8, 0, zp - 0.8), V(x + 0.8, h + 3, zp + 0.8), P.st.plankDark)
			sbox(f, 'GatePostCap', V(x - 1.0, h + 3, zp - 1.0), V(x + 1.0, h + 3.6, zp + 1.0), P.st.fence[1], true)
		end
		-- the gate leaf, hinged on the far post and swung ~70 degrees into the yard
		local leaf = f:at(CFrame.new(x, 0, gb - 0.8) * CFrame.Angles(0, side * math.rad(70), 0))
		local len = gb - ga - 1.8
		sbox(leaf, 'GateLeaf', V(-0.3, 0.8, -len), V(0.3, h - 0.4, 0), P.st.fence[3], true)
		for _, y in { 2, h - 1.8 } do sbox(leaf, 'GateBatten', V(-0.45, y, -len + 0.2), V(0.45, y + 0.6, -0.2), P.st.plankDark, true) end
	end
	return f
end
-- Low white picket fence along Z (a front-garden boundary): pointed pickets on two rails, square posts with caps every
-- ~6 studs; gaps = { { za, zb } } leave gateways between posts. side = the street's direction.
local function picketFence(c, x, z0, z1, side, gaps)
	local f = c:group('PicketFence')
	local white, rail = C(240, 240, 234), C(206, 206, 200)
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local function inGap(z)
		for _, g in gaps or {} do if z > math.min(g[1], g[2]) - 0.6 and z < math.max(g[1], g[2]) + 0.6 then return true end end
		return false
	end
	-- rails run between gaps
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			for _, y in { 1.4, 3.2 } do decor(f:box('PicketRail', V(x - side * 0.25 - 0.2, y, a), V(x - side * 0.25 + 0.2, y + 0.4, b), rail, M.Plastic)) end
			for z = a, b + 0.01, math.max(1, (b - a) / math.max(1, math.floor((b - a) / 6 + 0.5))) do
				sbox(f, 'PicketPost', V(x - 0.5, 0, z - 0.5), V(x + 0.5, 4.8, z + 0.5), white)
				sbox(f, 'PicketPostCap', V(x - 0.65, 4.8, z - 0.65), V(x + 0.65, 5.2, z + 0.65), rail, true)
			end
		end
	end
	for z = za + 0.9, zb - 0.6, 1.25 do
		if not inGap(z) then
			sbox(f, 'Picket', V(x - 0.2, 0, z - 0.35), V(x + 0.2, 3.9, z + 0.35), white)
			f:wedge('PicketTip', V(0.4, 0.6, 0.7), CFrame.new(x, 4.2, z) * CFrame.Angles(0, math.pi / 2, 0), white, M.SmoothPlastic)
		end
	end
	return f
end
-- Low brick garden wall along Z with a stone coping and an iron railing on top; brick piers with stone caps and ball
-- finials at its ends and either side of each gateway (gaps = { { za, zb } }). side = the street's direction.
local function gardenWall(c, x, z0, z1, side, gaps)
	local f = c:group('GardenWall')
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local cuts = { za }
	for _, g in gaps or {} do table.insert(cuts, math.min(g[1], g[2])); table.insert(cuts, math.max(g[1], g[2])) end
	table.insert(cuts, zb)
	table.sort(cuts)
	for k = 1, #cuts - 1, 2 do
		local a, b = cuts[k], cuts[k + 1]
		if b - a > 0.5 then
			sbox(f, 'GardenWall', V(x - 0.6, 0, a), V(x + 0.6, 3.0, b), P.st.brickDark)
			sbox(f, 'GardenCoping', V(x - 0.85, 3.0, a), V(x + 0.85, 3.45, b), P.st.trim)
			for z = a + 1, b - 0.9, 1.6 do decor(f:box('GardenRailBar', V(x - 0.1, 3.45, z - 0.1), V(x + 0.1, 5.4, z + 0.1), P.iron, M.Plastic)) end
			decor(f:box('GardenRail', V(x - 0.15, 5.2, a), V(x + 0.15, 5.5, b), P.iron, M.Plastic))
		end
	end
	for _, z in cuts do
		sbox(f, 'GardenPier', V(x - 1.0, 0, z - 1.0), V(x + 1.0, 4.4, z + 1.0), P.st.brick)
		sbox(f, 'GardenPierCap', V(x - 1.2, 4.4, z - 1.2), V(x + 1.2, 4.9, z + 1.2), P.st.trim, true)
		decor(f:part('GardenFinial', V(1.1, 1.1, 1.1), CFrame.new(x, 5.45, z), P.st.trim, M.Plastic, Enum.PartType.Ball))
	end
	return f
end
-- Tall street lamp (~27 studs) in three navy tones: a dark plinth, a studded base block with a lighter service
-- door, a square pole with two dark collars, a cap and finial, and a 1-stud arm out over the sidewalk (a rising strut,
-- then level) ending in a small head with a lighter rim and a thin warm light under its tip. dir points at the road.
local function lantern(c, pos, dir)
	dir = dir or V(1, 0, 0)
	local l = c:at(CFrame.lookAt(pos, pos - dir)):group('Lamp') -- (lookAt's -Z points away from the road: the arm runs along local +Z)
	local col, dark, lite = P.st.lamp, P.st.lampDark, P.st.lampLight
	sbox(l, 'LampPlinth', V(-2.1, -0.2, -2.1), V(2.1, 0.7, 2.1), dark)
	sbox(l, 'LampBase', V(-1.7, 0.7, -1.7), V(1.7, 2.8, 1.7), col)
	sbox(l, 'LampDoor', V(-0.7, 1.0, 1.7), V(0.7, 2.4, 1.85), lite, true)
	sbox(l, 'LampPole', V(-0.9, 2.8, -0.9), V(0.9, 26.4, 0.9), col)
	for _, y in { 6, 21.6 } do sbox(l, 'LampCollar', V(-1.15, y, -1.15), V(1.15, y + 0.6, 1.15), dark, true) end
	sbox(l, 'LampCap', V(-1.2, 26.4, -1.2), V(1.2, 27.4, 1.2), dark)
	sbox(l, 'LampFinial', V(-0.5, 27.4, -0.5), V(0.5, 28.2, 0.5), col, true)
	studs(decor(l:bar('LampStrut', V(0, 22.4, 0.6), V(0, 25.2, 4), 1, col, M.Plastic)), true)
	sbox(l, 'LampArm', V(-0.5, 24.7, 3.4), V(0.5, 25.7, 10.4), col, true)
	sbox(l, 'LampHead', V(-0.7, 24.6, 8.2), V(0.7, 25.9, 10.9), col, true)
	sbox(l, 'LampHeadRim', V(-0.8, 24.25, 8.0), V(0.8, 24.6, 11.1), lite, true)
	decor(l:box('LampGlow', V(-0.45, 24.1, 9.4), V(0.45, 24.25, 10.7), P.st.lampGlow, M.Neon)).CastShadow = false
	return l
end
-- Small flower: a green stem and four dark blue petals round a yellow eye (~2 wide, 2.6 tall).
local function flower(c, pos, seed)
	local r = Random.new(seed or 1)
	local f = c:at(CFrame.new(pos) * CFrame.Angles(math.rad(r:NextNumber(-8, 8)), math.rad(r:NextNumber(0, 90)), math.rad(r:NextNumber(-8, 8)))):group('Flower')
	decor(f:box('Stem', V(-0.25, 0, -0.25), V(0.25, 2.1, 0.25), P.st.stem, M.Plastic))
	decor(f:box('Leaf', V(0.25, 0.7, -0.2), V(0.9, 1.0, 0.2), P.st.stem, M.Plastic))
	decor(f:box('Petal', V(-1.1, 2.1, -0.4), V(1.1, 2.5, 0.4), P.st.petal, M.Plastic))
	decor(f:box('Petal', V(-0.4, 2.1, -1.1), V(0.4, 2.5, 1.1), P.st.petal, M.Plastic))
	decor(f:box('Eye', V(-0.3, 2.5, -0.3), V(0.3, 2.7, 0.3), P.st.petalEye, M.Plastic))
	return f
end
-- Tuft of grass blades (three thin green sticks).
local function tuft(c, pos, seed)
	local r = Random.new(seed or 1)
	local t = c:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(r:NextNumber(0, 180)), 0)):group('Tuft')
	for k, d in { V(-0.5, 0, 0), V(0.1, 0, 0.3), V(0.6, 0, -0.2) } do
		local hgt = 1.0 + k * 0.25
		decor(t:part('Blade', V(0.28, hgt, 0.28), CFrame.new(d + V(0, hgt / 2, 0)) * CFrame.Angles(math.rad(r:NextNumber(-12, 12)), 0, math.rad(r:NextNumber(-12, 12))), P.st.grass:Lerp(P.black, 0.18), M.Plastic))
	end
	return t
end
-- The reference's big green dumpster (8 long along Z, 5 deep, 6 tall), studded, in three greens: the body, two
-- darker ribs down the front and a darker rim; side bars, black wheels, rubbish heaped over it in small orange, brown
-- and dark bits, and its lid flung open from the back (+X) edge, leaning out over the street side. The front, the
-- street side, faces local -X.
local function dumpster(c, cf)
	local d = c:at(cf):group('Dumpster')
	local col, dark = P.st.dumpster, P.st.dumpsterDark
	sbox(d, 'DumpsterBody', V(-2.5, 0.7, -4), V(2.5, 5.6, 4), col)
	sbox(d, 'DumpsterRim', V(-2.8, 5.2, -4.3), V(2.8, 6.0, 4.3), dark, true)
	for _, z in { -1.6, 1.6 } do sbox(d, 'DumpsterRib', V(-2.75, 0.9, z - 0.4), V(-2.5, 5.2, z + 0.4), dark, true) end
	for _, z in { -4.25, 4.0 } do sbox(d, 'DumpsterBar', V(-1.6, 3.6, z), V(1.6, 4.1, z + 0.25), P.st.gutter, true) end
	for _, x in { -1.8, 1.8 } do
		for _, z in { -3.2, 3.2 } do decor(d:part('DumpsterWheel', V(0.6, 1.1, 1.1), CFrame.new(x, 0.55, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	decor(d:box('DumpsterInside', V(-2.3, 5.5, -3.8), V(2.3, 5.9, 3.8), C(52, 44, 40), M.Plastic))
	local r = Random.new(7)
	local bits = { P.st.garbage, P.st.garbage, C(120, 76, 46), C(60, 56, 54), C(250, 170, 60) }
	for k = 1, 14 do
		local x, z, sz = r:NextNumber(-1.9, 1.6), r:NextNumber(-3.3, 3.0), r:NextNumber(0.6, 1.1)
		decor(d:box('Rubbish', V(x, 5.8, z), V(x + sz, 5.9 + r:NextNumber(0.3, 0.9), z + sz), bits[k % #bits + 1], M.Plastic)).CastShadow = false
	end
	-- the lid, hinged on the back top edge, leaning ~25 degrees past upright toward the street
	local lid = d:at(CFrame.new(2.8, 6.0, 0) * CFrame.Angles(0, 0, math.rad(-65)))
	sbox(lid, 'DumpsterLid', V(-5.4, 0, -4.3), V(0, 0.5, 4.3), dark, true)
	sbox(lid, 'DumpsterLidRib', V(-4.6, 0.5, -3.6), V(-0.6, 0.8, 3.6), col, true)
	return d
end
-- Hood street furniture, in the same chunky studded style. Fire hydrant: red barrel on a darker foot, collar and cap,
-- side nozzles and a silver front cap.
local function hydrant(c, pos)
	local h = c:at(CFrame.new(pos)):group('Hydrant')
	local red, dark = C(226, 56, 48), C(168, 36, 34)
	sbox(h, 'HydrantFoot', V(-1, 0, -1), V(1, 0.5, 1), dark)
	sbox(h, 'HydrantBody', V(-0.7, 0.5, -0.7), V(0.7, 2.6, 0.7), red)
	sbox(h, 'HydrantCollar', V(-0.85, 2.6, -0.85), V(0.85, 2.9, 0.85), dark)
	sbox(h, 'HydrantCap', V(-0.5, 2.9, -0.5), V(0.5, 3.5, 0.5), red)
	sbox(h, 'HydrantNozzles', V(-1.1, 1.5, -0.35), V(1.1, 2.1, 0.35), dark, true)
	sbox(h, 'HydrantFront', V(-0.35, 1.45, -1.05), V(0.35, 2.15, -0.7), C(206, 208, 214), true)
	return h
end
-- A heap of black trash bags: lumpy studded blocks, each tied off with a small knot.
local function trashBags(c, cf, n)
	local t = c:at(cf):group('TrashBags')
	local spots = { { 0, 0, 0, 2.2, 1.8 }, { 1.7, 0, 0.9, 1.8, 1.5 }, { 0.6, 1.6, 0.4, 1.7, 1.4 }, { -1.5, 0, 0.6, 1.6, 1.4 } }
	for k = 1, n or 3 do
		local s = spots[k]
		local b = t:at(CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, k * 0.7, (k % 2 - 0.5) * 0.25))
		sbox(b, 'TrashBag', V(-s[4] / 2, 0, -s[4] / 2), V(s[4] / 2, s[5], s[4] / 2), C(44, 46, 54))
		sbox(b, 'TrashBagKnot', V(-0.3, s[5], -0.3), V(0.3, s[5] + 0.5, 0.3), C(30, 32, 38), true)
	end
	return t
end
-- Wheelie bin: a dark green studded body on two wheels with a darker lid and handle (front = local -X).
local function wheelieBin(c, cf, color)
	local b = c:at(cf):group('WheelieBin')
	color = color or C(40, 120, 70)
	sbox(b, 'BinBody', V(-1.2, 0.5, -1.3), V(1.2, 3.8, 1.3), color)
	sbox(b, 'BinLid', V(-1.4, 3.8, -1.4), V(1.5, 4.2, 1.4), color:Lerp(P.black, 0.25))
	sbox(b, 'BinHandle', V(1.2, 3.4, -1.0), V(1.6, 3.8, 1.0), C(30, 32, 36), true)
	for _, z in { -0.9, 0.9 } do decor(b:part('BinWheel', V(0.5, 1, 1), CFrame.new(1.0, 0.5, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	return b
end
-- A boombox (the hood touch on a crate): black case, two silver-rimmed speakers, a handle on top (front = local -Z).
local function boombox(c, cf)
	local b = c:at(cf):group('Boombox')
	sbox(b, 'BoomboxCase', V(-1.5, 0, -0.5), V(1.5, 1.5, 0.5), C(36, 38, 44))
	for _, x in { -0.8, 0.8 } do
		decor(b:part('BoomboxSpeaker', V(0.12, 1.0, 1.0), CFrame.new(x, 0.75, -0.55) * CFrame.Angles(0, math.pi / 2, 0), C(190, 194, 202), M.Plastic, Enum.PartType.Cylinder))
		decor(b:part('BoomboxCone', V(0.14, 0.6, 0.6), CFrame.new(x, 0.75, -0.6) * CFrame.Angles(0, math.pi / 2, 0), C(60, 62, 70), M.Plastic, Enum.PartType.Cylinder))
	end
	sbox(b, 'BoomboxHandle', V(-1.1, 1.5, -0.15), V(1.1, 1.9, 0.15), C(190, 194, 202), true)
	return b
end
-- Wooden crate with darker edge planks; pallets for under them.
local function crate(c, cf, size)
	size = size or 3
	local h = size / 2
	local k = c:at(cf):group('Crate')
	k:box('Crate', V(-h, 0, -h), V(h, size, h), P.crate, M.WoodPlanks)
	for _, y in { 0.15, size - 0.45 } do k:box('CrateBand', V(-h - 0.05, y, -h - 0.05), V(h + 0.05, y + 0.3, h + 0.05), P.woodDark, M.Wood) end
	for _, x in { -h - 0.05, h - 0.25 } do k:box('CrateEdge', V(x, 0, -h - 0.05), V(x + 0.3, size, -h + 0.25), P.woodDark, M.Wood) end
	return k
end
local function pallet(c, cf)
	local p = c:at(cf):group('Pallet')
	for _, x in { -1.6, 0, 1.6 } do p:box('PalletBlock', V(x - 0.3, 0, -1.6), V(x + 0.3, 0.5, 1.6), P.woodDark, M.Wood) end
	for z = -1.6, 1.6, 0.8 do p:box('PalletSlat', V(-2, 0.5, z - 0.3), V(2, 0.8, z + 0.3), P.crate, M.WoodPlanks) end
	return p
end
-- A parked bike leaning on its stand (along local Z): black wheels with silver hubs, a coloured frame (two tubes and
-- the fork), a black seat and silver handlebar.
local function bike(c, cf, color)
	local k = c:at(cf * CFrame.Angles(0, 0, math.rad(8))):group('Bike')
	color = color or C(230, 60, 60)
	for _, z in { -1.7, 1.7 } do
		decor(k:part('BikeWheel', V(0.3, 2.3, 2.3), CFrame.new(0, 1.15, z), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder))
		decor(k:part('BikeHub', V(0.36, 0.6, 0.6), CFrame.new(0, 1.15, z), C(200, 204, 210), M.Plastic, Enum.PartType.Cylinder))
	end
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.4, -0.2), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 2.4, -0.2), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, -1.7), V(0, 2.5, -1.3), 0.3, color, M.Plastic))
	decor(k:bar('BikeFrame', V(0, 1.15, 1.7), V(0, 2.9, 1.2), 0.25, color, M.Plastic))
	decor(k:box('BikeSeat', V(-0.3, 2.5, 1.0), V(0.3, 2.75, 1.7), C(30, 30, 34), M.Plastic))
	decor(k:box('BikeBars', V(-0.9, 2.9, -1.45), V(0.9, 3.1, -1.25), C(200, 204, 210), M.Plastic))
	decor(k:bar('BikeStem', V(0, 2.5, -1.3), V(0, 2.95, -1.35), 0.25, C(200, 204, 210), M.Plastic))
	return k
end
-- Corner-store produce crates on a pallet: open wooden crates (studded, darker rims) heaped with fruit blocks.
local function storeCrates(c, cf, n)
	local k = c:at(cf):group('StoreCrates')
	pallet(k, CFrame.new())
	local fruit = { C(236, 64, 52), C(255, 170, 40), C(130, 210, 60), C(255, 222, 70) }
	local spots = { { -1.1, 0.8, -0.2 }, { 1.1, 0.8, 0.1 }, { 0, 2.4, 0 } }
	for j = 1, n or 3 do
		local p = spots[j]
		local b = k:at(CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, (j - 2) * 0.12, 0))
		sbox(b, 'Crate', V(-1.0, 0, -1.3), V(1.0, 1.6, 1.3), P.crate)
		sbox(b, 'CrateRim', V(-1.05, 1.3, -1.35), V(1.05, 1.65, 1.35), P.woodDark, true)
		for q = 0, 3 do
			local fx, fz = (q % 2) * 0.9 - 0.45, (q // 2) * 1.1 - 0.55
			decor(b:box('Fruit', V(fx - 0.4, 1.55, fz - 0.45), V(fx + 0.4, 2.1, fz + 0.45), fruit[(j + q) % #fruit + 1], M.Plastic))
		end
	end
	return k
end
-- A plywood board with a spray-painted tag, leaning back against whatever is behind it (front = local -Z):
-- the board, two darker battens and the tag.
local function graffitiBoard(c, cf, text, color)
	local k = c:at(cf * CFrame.Angles(math.rad(-10), 0, 0)):group('GraffitiBoard')
	local board = sbox(k, 'Board', V(-3, 0, -0.15), V(3, 4.6, 0.15), C(214, 172, 116))
	for _, y in { 0.8, 3.8 } do sbox(k, 'Batten', V(-3.1, y - 0.25, 0.15), V(3.1, y + 0.25, 0.4), C(160, 118, 72), true) end
	local g = surface(board, Enum.NormalId.Front, 20)
	line(g, 'Tag', text, color, FONT.tag, 0.12, 0.76, P.black, 3).Rotation = -8
	return k
end
-- Shipping container (19.6 long along local Z) with ridges down both long sides and door bars at one end.
local function container(c, cf, color)
	local k = c:at(cf):group('Container')
	k:box('ContainerBody', V(-4, 0, -9.8), V(4, 8.6, 9.8), color, M.SmoothPlastic)
	for z = -8, 8.1, 3.2 do
		for _, x in { -4.15, 4 } do k:box('ContainerRidge', V(x, 0.4, z - 0.4), V(x + 0.15, 8.2, z + 0.4), color:Lerp(P.black, 0.15), M.SmoothPlastic) end
	end
	k:box('ContainerTopRim', V(-4.1, 8.4, -9.85), V(4.1, 8.7, 9.85), color:Lerp(P.black, 0.2), M.SmoothPlastic)
	for _, x in { -1.4, 1.4 } do k:box('ContainerDoorBar', V(x - 0.12, 0.6, 9.8), V(x + 0.12, 8, 9.95), color:Lerp(P.black, 0.3), M.SmoothPlastic) end
	return k
end
-- Low-poly sedan (front toward -Z).
local function car(c, cf, color)
	local k = c:at(cf):group('Car')
	for _, x in { -2.1, 2.1 } do
		for _, z in { -3.3, 3.3 } do
			k:part('Wheel', V(0.8, 2, 2), CFrame.new(x, 1, z), P.black, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(k:part('Hubcap', V(0.84, 1, 1), CFrame.new(x, 1, z), P.frame, M.Metal, Enum.PartType.Cylinder))
		end
	end
	k:box('CarBody', V(-2.3, 1, -5.2), V(2.3, 2.9, 5.2), color, M.SmoothPlastic)
	k:box('CarCabin', V(-2.0, 2.9, -2.0), V(2.0, 4.6, 2.8), color, M.SmoothPlastic)
	decor(k:box('CarGlass', V(-2.05, 3.1, -2.05), V(2.05, 4.4, 2.85), P.glass, M.SmoothPlastic))
	for _, z in { -5.4, 5.1 } do k:box('Bumper', V(-2.35, 0.9, z), V(2.35, 1.6, z + 0.3), P.frame, M.Metal) end
	for _, x in { -1.9, 1.0 } do
		decor(k:box('Headlight', V(x, 2.1, -5.25), V(x + 0.9, 2.6, -5.2), C(255, 244, 200), M.Neon))
		decor(k:box('TailLight', V(x, 2.1, 5.2), V(x + 0.9, 2.6, 5.25), C(220, 40, 40), M.SmoothPlastic))
	end
	return k
end
-- Chain-link fence along a straight line, with optional gaps { from, to } (distance along the line).
local function chainLink(c, a, b, h, gaps)
	local dir = b - a
	local len = dir.Magnitude
	local u = dir.Unit
	local n = math.max(1, math.ceil(len / 8))
	local posts = {}
	for k = 0, n do
		local t = len * k / n
		local open = false
		for _, g in gaps or {} do if t > g[1] - 1 and t < g[2] + 1 then open = true end end
		if not open then table.insert(posts, t) end
	end
	for _, g in gaps or {} do table.insert(posts, g[1]); table.insert(posts, g[2]) end
	for _, t in posts do c:post('FencePost', 0.25, h + 0.2, a + u * t, P.iron, M.Metal) end
	local pieces = { { 0, len } }
	for _, g in gaps or {} do
		local nextPieces = {}
		for _, p in pieces do
			if g[2] <= p[1] or g[1] >= p[2] then table.insert(nextPieces, p)
			else
				if g[1] > p[1] then table.insert(nextPieces, { p[1], g[1] }) end
				if g[2] < p[2] then table.insert(nextPieces, { g[2], p[2] }) end
			end
		end
		pieces = nextPieces
	end
	for _, p in pieces do
		if p[2] - p[1] > 0.3 then
			local p0, p1 = a + u * p[1], a + u * p[2]
			local mid, up = (p0 + p1) / 2, V(0, (h - 0.4) / 2 + 0.2, 0)
			local mesh = c:part('ChainLink', V(0.1, h - 0.4, (p1 - p0).Magnitude), CFrame.lookAt(mid + up, p1 + up), C(70, 74, 82), M.DiamondPlate)
		mesh.Name = 'ChainLink'
			mesh.Transparency = 0.45
			mesh.CastShadow = false
			decor(plank(c, 'FenceRail', p0 + V(0, h, 0), p1 + V(0, h, 0), 0.25, 0.25, P.iron, M.Metal))
		end
	end
end

-- Fight pad: a glowing coloured square with a white border and its number painted on top. hidden: only an
-- invisible marker with the same model, tag and attributes (the reference street's road has no pad on it).
local function fightPad(c, n, pos, color, district, size, label, hidden)
	size = size or PAD_SIZE
	local h = size / 2
	local pad, model = c:at(CFrame.new(pos)):group('FightPad_' .. n)
	model:SetAttribute('Fight', n)
	model:SetAttribute('District', district)
	model:AddTag('HoodFightPad')
	if hidden then
		local marker = ghost(pad:box('PadMarker', V(-h, 0, -h), V(h, 0.2, h), color, M.SmoothPlastic))
		marker.CastShadow = false
		return model, pad
	end
	pad:box('PadBorder', V(-h - 0.5, 0, -h - 0.5), V(h + 0.5, 0.3, h + 0.5), P.white, M.SmoothPlastic)
	local top = pad:box('Pad', V(-h + 0.3, 0, -h + 0.3), V(h - 0.3, 0.36, h - 0.3), color, M.SmoothPlastic)
	decor(pad:box('PadGlow', V(-h, 0.3, -h), V(h, 0.33, h), color:Lerp(P.white, 0.35), M.Neon)).CastShadow = false
	local g = surface(top, Enum.NormalId.Top, 20)
	line(g, 'Number', label or tostring(n), P.white, FONT.loud, 0.18, 0.64, C(20, 24, 40), 6)
	local glow = Instance.new('SurfaceLight')
	glow.Face, glow.Color, glow.Brightness, glow.Range, glow.Angle = Enum.NormalId.Top, color, 1.2, 10, 120
	glow.Parent = top
	return model, pad
end
-- District banner: a solid coloured sign floating over the walk, readable from both sides.
local function banner(c, text, pos, color, w)
	w = w or 24
	local b = c:at(CFrame.new(pos)):group('DistrictBanner')
	local sign = b:box('Banner', V(-w / 2, 0, -0.8), V(w / 2, 7, 0.8), color, M.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local g = surface(sign, face, 20)
		pcall(function() g.MaxDistance = 80 end) -- (a stage ahead at most, so banners don't stack through the lobby door)
		line(g, 'Title', text, P.white, FONT.loud, 0.1, 0.8, color:Lerp(P.black, 0.55), 5)
	end
	return b
end

-- Teleport pad, as on the reference street: a flat slab with a prompt (StageService handles targets 'Lobby' and
-- 'Furthest'). opts: w, d (size; default 7 x 4), y (the floor it sits on), h (thickness), material (default Neon),
-- base (colour of a thin dark plate under it, showing as a rim), shade + rim (the slab's sides take the darker
-- shade and the top gets a neon edge in rim around an inset top in the pad's colour), sparkle (a few rising
-- sparkles), arrow (+1/-1: two glowing chevrons on the top pointing along Z), title + sub (a floating label read up
-- close, sub in labelColor, both in font), bare (no floating label).
-- Every part but the prompt's slab is decor; each carries BaseTransparency for HoodClient/Stages, which hides a
-- cleared gate's pads.
local function teleportPad(g, name, x, z, color, target, label, opts)
	opts = opts or {}
	local w, d, y, h = opts.w or 7, opts.d or 4, opts.y or 0, opts.h or 0.42
	local parts = {}
	if opts.base then
		table.insert(parts, decor(g:box(name .. 'Base', V(x - w / 2 - 0.3, y, z - d / 2 - 0.3), V(x + w / 2 + 0.3, y + 0.15, z + d / 2 + 0.3), opts.base, M.SmoothPlastic)))
		y += 0.15
	end
	local pad = g:box(name, V(x - w / 2, y, z - d / 2), V(x + w / 2, y + h, z + d / 2), opts.shade or color, opts.material or M.Neon)
	table.insert(parts, pad)
	if opts.rim then
		local rim = decor(g:box(name .. 'Rim', V(x - w / 2, y + h, z - d / 2), V(x + w / 2, y + h + 0.05, z + d / 2), opts.rim, M.Neon))
		rim.CastShadow = false
		local top = decor(g:box(name .. 'Top', V(x - w / 2 + 0.35, y + h + 0.05, z - d / 2 + 0.35), V(x + w / 2 - 0.35, y + h + 0.1, z + d / 2 - 0.35), color, opts.material or M.Neon))
		table.insert(parts, rim)
		table.insert(parts, top)
		-- Two glowing chevrons on the top pointing where the pad sends you (opts.arrow: +1 toward +Z, -1 toward -Z).
		if opts.arrow then
			local f = opts.arrow
			for _, za in { z + f * 0.4, z + f * 2.2 } do
				for _, sx in { -1, 1 } do
					local c = V(x + sx * 0.5, y + h + 0.12, za - f * 0.5)
					local bar = decor(g:part(name .. 'Chevron', V(0.4, 0.05, 1.5), CFrame.lookAt(c, c + V(sx, 0, -f)), opts.rim, M.Neon))
					bar.CastShadow = false
					table.insert(parts, bar)
				end
			end
		end
		if opts.sparkle then
			local sp = Instance.new('ParticleEmitter')
			sp.Name = 'PadSparkles'
			sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
			sp.Rate = 5
			sp.Lifetime, sp.Speed = NumberRange.new(0.8, 1.4), NumberRange.new(1.5, 3)
			sp.SpreadAngle = Vector2.new(12, 12)
			sp.EmissionDirection = Enum.NormalId.Top
			sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			sp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			sp.Color = ColorSequence.new(opts.rim)
			sp.LightEmission = 1
			sp.Parent = top
		end
	end
	for _, p in parts do p:SetAttribute('BaseTransparency', 0) end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'Teleport'
	prompt.ActionText = 'Teleport'
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', target)
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	if opts.title then
		-- Read up close only (hidden from down the street, where the reference shows the bare pads): HoodClient/LabelFade
		-- fades it out from 26 to 44 studs (kind Pad) and sets MaxDistance itself.
		local anchor = ghost(g:part(name .. 'Label', V(0.2, 0.2, 0.2), CFrame.new(x, y + h + 4.6, z), P.white))
		anchor:SetAttribute('BaseTransparency', 1)
		local gui = Instance.new('BillboardGui')
		gui.Name = 'WorldLabel'
		gui.Size = UDim2.fromScale(9.5, 3.1)
		gui.MaxDistance = 45
		gui.LightInfluence = 0
		gui.Parent = anchor
		-- (the game's text face, UI2's Gotham Black, with a near-black outline)
		line(gui, 'Title', opts.title, C(240, 242, 248), opts.font or Enum.Font.GothamBlack, 0, 0.58, C(16, 18, 30), 3)
		line(gui, 'Sub', opts.sub or '', opts.labelColor or color, opts.font or Enum.Font.GothamBlack, 0.6, 0.36, C(16, 18, 30), 2)
	elseif not opts.bare then
		billboard(g, V(x, y + 3.2, z), 6, 1.4, { { 'Title', label, P.white, opts.font or Enum.Font.GothamBlack, 0, 1 } }).WorldLabel.MaxDistance = 50
	end
	return pad
end
---------------------------------------------------------------------------------------------- training stations
-- Shooting-range lanes (the game trains with guns). Each lane keeps the bag stations' frame and themes: a long
-- flat studded mat (7 x 18) in a low two-tone rim with stepped pixel corners and a stamped row of X's on the
-- aisle face. The aisle end of the mat is the shooter's box (the TrainingZone); a waist-high bench marks the
-- firing line; the targets stand in the far half in front of a backstop at the outer end, and from tier 3 a
-- grooved truss gantry (the old gallows' truss) spans the lane over them. Every tier keeps its theme and its
-- effects and adds one new thing, so each lane reads as better than the last:
--   1 stone   soda bottles and cans on a plank shelf, a plank backstop with a painted bullseye, bunting
--   2 red     three bullseye boards on easels, a navy board with red trim (rain behind the boards)
--   3 lava    hot plates swinging from a truss gantry, burning barrels, a basalt berm with lava cracks (fire)
--   4 arcane  a spinner disc, balloons to pop, a violet starburst wall (comets above the targets)
--   5 shadow  dark plates with violet neon rims, neon on the gantry, an obsidian wall with a neon ring
--   6 frost   ice blocks and an ice bullseye, an ice-block wall with icicles, ice-blue neon (snow, sparkles)
--   7 toxic   a toxic barrel stack with a target face, green bottles, a container wall with hazard stripes
--   8 gold    a big gold gong on crimson velvet, golden neon, a turning crown, a velvet VIP bench (glints)
-- Every main target's centre sits ~5.8 over the mat, above the shooter's head from the follow camera.
-- Cartoon targets only: bottles, cans, bullseyes, plates, balloons, ice, barrels. Nothing human-shaped.
-- Local frame: origin = mat centre on the deck, footprint x -4.5..4.5, z -10..10 (rim included). The front
-- (-Z) faces the aisle: players walk on from -Z, stand in the box and shoot toward +Z. Parts reach y ~11.5,
-- labels float to ~16. opts.vfx = false skips effects, opts.tier overrides the tier, opts.labelLift raises the
-- label stack (the lobby staggers neighbouring stacks); opts.side is ignored.
-- Contract (Lobby.client, Shoot.client, LobbyRules): Training_<Id> > TrainingZone (the shooter's box,
-- invisible), Equipment > Targets > Target<i> (Hinge = the pivot part, Swing = the parts that move; attributes
-- Knock = Tip | Swing | Spin | Pop | Shatter | Fly, Hit = the sound it makes, ShardColor, Aim = world centre
-- where shots land, Main on the HitPoint target),
-- Equipment > Gear (stands, fence, gantry), Sign (BillboardGui with Chip + TextLabels Cost, Detail, Power),
-- attributes Tier, HitPoint (the main target's centre), HitColor. Equipment has no Hinge of its own, so
-- nothing sways while you stand there: Shoot.client knocks each target back when a shot lands on it.
local Stations = {}

-- Per tier (Skins.Stations order). rim/rimTop: the base ring (stamped band, studded lip; rimTopMat Neon = a
-- glowing lip without studs); mat: the inset surface; frame (+frameMat): bench, gantry and stands; groove:
-- the stamped X's colour (nil = a darker shade of the face); text: the "xN Power" colour; glow: hit sparks;
-- edge: a thin neon line inside the rim (shadow); labelLift: the label stack sits this much higher (gold's crown). Colours from the bag stations the critics signed off.
-- Tiers 5-7 follow the reference's right row: shadow (x8), frost (x12), toxic (x18).
Stations.Themes = {
	{ name = 'stone', rim = C(62, 78, 118), rimTop = C(82, 104, 150), mat = C(115, 132, 172), frame = C(165, 95, 78),
		text = C(255, 255, 255), glow = C(255, 236, 200) },
	{ name = 'red', rim = C(26, 30, 70), rimTop = C(40, 46, 92), mat = C(250, 45, 85), frame = C(36, 42, 86), trim = C(240, 40, 70),
		text = C(255, 70, 100), glow = C(255, 70, 100) },
	{ name = 'lava', rim = C(225, 100, 35), rimTop = C(255, 150, 50), mat = C(255, 140, 20), frame = C(250, 140, 36), groove = C(215, 90, 10),
		text = C(255, 170, 48), glow = C(255, 150, 40) },
	{ name = 'arcane', rim = C(150, 40, 130), rimTop = C(240, 80, 190), mat = C(190, 70, 208), frame = C(170, 80, 220),
		text = C(214, 120, 255), glow = C(230, 120, 255) },
	{ name = 'shadow', rim = C(70, 40, 110), rimTop = C(92, 56, 140), mat = C(44, 24, 70), frame = C(22, 18, 32),
		text = C(198, 164, 255), glow = C(176, 120, 255), edge = C(150, 70, 255) },
	{ name = 'frost', rim = C(30, 110, 210), rimTop = C(160, 244, 255), mat = C(132, 246, 248), matMat = M.SmoothPlastic, frame = C(30, 110, 210),
		groove = C(60, 190, 235), text = C(120, 236, 255), glow = C(150, 236, 255) },
	{ name = 'toxic', rim = C(10, 170, 44), rimTop = C(20, 255, 60), rimTopMat = M.Neon, mat = C(0, 60, 60), frame = C(16, 150, 52), wallCap = C(255, 214, 30),
		groove = C(5, 150, 35), text = C(130, 255, 90), glow = C(120, 255, 80) },
	{ name = 'gold', rim = C(230, 180, 0), rimTop = C(255, 236, 60), mat = C(252, 242, 88), frame = C(245, 192, 0), groove = C(205, 140, 0),
		trim = C(175, 18, 48), wallCap = C(255, 244, 200), text = C(255, 222, 50), glow = C(255, 222, 80), labelLift = 0.3 },
}

Stations.HALF_X, Stations.HALF_Z = 4.5, 10 -- rim outer half sizes (the mat is inset 1 stud)
Stations.MAT_Y = 0.4 -- mat top (where players stand)
Stations.RIM_Y = 0.6 -- rim top
Stations.BOX_Z = -3.2 -- the shooter's box runs from the aisle end to here
Stations.BENCH_Z = -2.75 -- the bench's centre line (it is 0.9 deep)
Stations.BENCH_H = 2.3 -- bench top over the mat: waist height, under the held gun
Stations.FIELD_Z0, Stations.FIELD_Z1 = -1.9, 8.4 -- the target field (effects fill it)
Stations.BACK_Z = 8.5 -- the backstop's front face
Stations.GANTRY_Z = 6.4 -- the gantry's centre line (hanging targets hang from it)
Stations.GANTRY_Y = 8.6 -- underside of the gantry beam
Stations.LABEL = V(0, 14.4, 3.6) -- the label stack, over the target field
Stations.StampId = '' -- set from HoodVFX.Textures.stamp at build time ('' until the PNG is uploaded)

---------------------------------------------------------------------------------------------- stamp and X
-- The groove colour on a face: the theme's own, or the face colour darkened (critic: grooves keep the face's
-- hue, so gold stays lemon and never turns olive).
function Stations.grooveFor(t, base) return t.groove or base:Lerp(C(0, 0, 0), 0.45) end

-- The reference's embossed X on a block face: a Texture tiled every su x sv studs (one X per panel). stamp.png
-- draws the groove in white and Color3 tints it. With no uploaded id the Texture draws nothing in Studio; the
-- offline renderer draws hood/art/vfx/stamp.png (PreviewTexture), and barX cuts the X in geometry meanwhile.
function Stations.stamp(part, faces, su, sv, tint, alpha)
	for _, face in faces do
		local t = Instance.new('Texture')
		t.Name = 'Stamp'
		t.Face = face
		t.Texture = Stations.StampId
		t.StudsPerTileU, t.StudsPerTileV = su or 2, sv or 2
		t.Transparency = 1 - (alpha or 1)
		t.Color3 = tint or part.Color:Lerp(C(0, 0, 0), 0.45)
		t:SetAttribute('PreviewTexture', 'stamp')
		t.Parent = part
	end
end
Stations.SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Before stamp.png is uploaded a Texture draws nothing, so the X is cut in geometry on the faces players see
-- most (the rim's aisle face, the bench front, the backstop front): two thin bars per X, 0.02 proud, in the
-- groove colour. Skipped once the id is set. `cf` is the face centre with -Z out of the face; w x h is one X.
function Stations.barX(c, cf, w, h, color)
	local ang, L = math.atan2(w, h), math.sqrt(w * w + h * h) - 0.08
	for _, dir in { -1, 1 } do
		decor(c:part('StampBar', V(0.12, L, 0.04), cf * CFrame.new(0, 0, -0.01) * CFrame.Angles(0, 0, dir * ang), color, M.SmoothPlastic)).CastShadow = false
	end
end
-- n X's side by side across a face `w` wide and `h` tall centred on `cf` (stamp + geometry fallback).
function Stations.panelX(c, part, cf, w, h, n, tint)
	Stations.stamp(part, { Enum.NormalId.Front }, w / n, h, tint)
	if Stations.StampId == '' then
		for k = 0, n - 1 do Stations.barX(c, cf * CFrame.new(-w / 2 + (k + 0.5) * w / n, 0, 0), w / n - 0.12, h - 0.12, tint) end
	end
end

-- A truss beam along the local +Y of `cf` (cf = centre of the base), len long, w x d thick: a solid beam in the
-- frame colour with thin grooves 0.02 proud (a tie line every `cell` studs and an X in every cell) on the faces
-- listed ('-x', '+x', '-z', '+z' in cf's frame), so from a distance it reads as one solid block.
function Stations.truss(c, name, cf, len, w, d, color, groove, cell, faces, material)
	c:part(name .. 'Core', V(w, len, d), cf * CFrame.new(0, len / 2, 0), color, material)
	local n = math.max(1, math.floor(len / cell + 0.5))
	local seg, g = len / n, 0.16
	for _, f in faces do
		local onX = f:sub(2) == 'x'
		local s = f:sub(1, 1) == '-' and -1 or 1
		local span = (onX and d or w) - 0.24 -- grooves stop short of the corners
		local off = (onX and w or d) / 2 + 0.01
		local L = math.sqrt(span * span + seg * seg)
		local ang = math.atan2(span, seg)
		for k = 0, n do
			local y = math.clamp(k * seg, g / 2 + 0.05, len - g / 2 - 0.05)
			c:part(name .. 'Tie', onX and V(0.04, g, span) or V(span, g, 0.04), cf * CFrame.new(onX and s * off or 0, y, onX and 0 or s * off), groove)
		end
		for k = 0, n - 1 do
			for _, dir in { -1, 1 } do
				local at = CFrame.new(onX and s * off or 0, (k + 0.5) * seg, onX and 0 or s * off)
				local turn = onX and CFrame.Angles(dir * ang, 0, 0) or CFrame.Angles(0, 0, dir * ang)
				c:part(name .. 'Groove', onX and V(0.04, L, g) or V(g, L, 0.04), cf * at * turn, groove)
			end
		end
	end
end

---------------------------------------------------------------------------------------------- shapes
-- Round disc facing -Z (a cylinder lying along the frame's Z): centre `cf`, radius r, thickness th.
function Stations.disc(c, name, cf, r, th, color, material)
	return c:part(name, V(th, 2 * r, 2 * r), cf * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Upright cylinder standing on `pos`.
function Stations.can(c, name, pos, r, h, color, material)
	return c:part(name, V(h, 2 * r, 2 * r), CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
end
-- Bullseye whose back sits on the plane z = 0 of `cf` (facing -Z): rings outer to inner from `colors`, each a
-- little prouder than the last so no two share a face. Returns the outer ring.
function Stations.bullseye(c, cf, r, colors, material)
	local n, outer = #colors, nil
	for i, col in colors do
		local th = 0.08 + 0.035 * i
		local p = Stations.disc(c, 'Ring', cf * CFrame.new(0, 0, 0.02 - th / 2), r * (n - i + 1) / n, th, col, type(material) == 'table' and material[i] or material)
		outer = outer or p
	end
	return outer
end
-- Two squares turned 45 degrees: an eight-point starburst facing -Z, centred on `cf`.
function Stations.starburst(c, cf, s, th, color, material)
	c:part('Burst', V(s, s, th), cf, color, material)
	c:part('Burst', V(s, s, th + 0.02), cf * CFrame.Angles(0, 0, math.pi / 4), color, material)
end
-- Soda bottle (a body with a white label and a coloured stripe, a shoulder, a neck and a cap) standing on `pos`,
-- scale s (1.5 tall). opts: label, stripe, cap colours and the body material.
function Stations.bottle(c, pos, s, color, opts)
	opts = opts or {}
	Stations.can(c, 'Bottle', pos, 0.3 * s, 0.9 * s, color, opts.material)
	Stations.can(c, 'BottleLabel', pos + V(0, 0.22 * s, 0), 0.315 * s, 0.36 * s, opts.label or C(255, 255, 255))
	Stations.can(c, 'BottleStripe', pos + V(0, 0.36 * s, 0), 0.325 * s, 0.07 * s, opts.stripe or color)
	Stations.can(c, 'BottleShoulder', pos + V(0, 0.9 * s, 0), 0.22 * s, 0.16 * s, color, opts.material)
	Stations.can(c, 'BottleNeck', pos + V(0, 1.06 * s, 0), 0.11 * s, 0.34 * s, color, opts.material)
	Stations.can(c, 'BottleCap', pos + V(0, 1.4 * s, 0), 0.14 * s, 0.1 * s, opts.cap or C(255, 255, 255))
	return 1.5 * s
end
-- Soda can (silver lips, a wide white label band) standing on `pos`; r wide, h tall. face: radius of a red and
-- white bullseye sticker on its front (-Z), for the can you are meant to hit.
function Stations.tin(c, pos, r, h, color, band, face)
	Stations.can(c, 'Can', pos, r, h, color)
	Stations.can(c, 'CanLabel', pos + V(0, h * 0.3, 0), r + 0.015, h * 0.4, band or C(255, 255, 255))
	for _, y in { 0, h - 0.07 } do Stations.can(c, 'CanLip', pos + V(0, y, 0), r + 0.03, 0.07, C(214, 220, 230), M.Metal) end
	if face then Stations.bullseye(c, CFrame.new(pos + V(0, h * 0.5, -r - 0.04)), face, { C(230, 50, 50), C(255, 255, 255), C(230, 50, 50) }) end
end
-- Drum (two proud bands and a lid) standing on `pos`.
function Stations.drum(c, pos, r, h, color, band, lid, material)
	Stations.can(c, 'Drum', pos, r, h, color, material)
	for _, y in { 0.22, 0.7 } do Stations.can(c, 'DrumBand', pos + V(0, h * y - 0.09, 0), r + 0.05, 0.18, band) end
	Stations.can(c, 'DrumLid', pos + V(0, h, 0), r - 0.06, 0.06, lid or band)
end
-- Party balloon (an egg, a knot, a shine) with its string down to `foot`.
function Stations.balloon(c, pos, r, color, foot)
	c:blob('Balloon', V(2 * r, 2.3 * r, 2 * r), pos, color, M.SmoothPlastic)
	c:blob('BalloonShine', V(0.5 * r, 0.7 * r, 0.3 * r), pos + V(0.45 * r, 0.5 * r, -0.85 * r), C(255, 255, 255), M.SmoothPlastic)
	c:part('BalloonKnot', V(0.25 * r, 0.25 * r, 0.25 * r), CFrame.new(pos - V(0, 1.2 * r, 0)) * CFrame.Angles(0, 0, math.pi / 4), color)
	if foot then c:bar('BalloonString', pos - V(0, 1.25 * r, 0), foot, 0.06, C(250, 250, 250), M.SmoothPlastic) end
end
-- Easel: two chunky front legs and a back leg on darker feet, under a ledge `y` up that a board stands on.
function Stations.easel(c, x, z, y, w, color)
	local Y = Stations.MAT_Y
	local foot = color:Lerp(C(0, 0, 0), 0.35)
	for _, sx in { -1, 1 } do
		local a = V(x + sx * (w / 2 + 0.3), Y + 0.25, z + 0.2)
		c:bar('EaselLeg', a, V(x + sx * w / 3, y + 0.1, z + 0.12), 0.4, color, M.SmoothPlastic)
		c:box('EaselFoot', a - V(0.32, 0.25, 0.32), a + V(0.32, 0.05, 0.32), foot)
	end
	local back = V(x, Y + 0.25, z + 1.2 + (y - Y) * 0.12)
	c:bar('EaselLeg', back, V(x, y + 0.35, z + 0.2), 0.36, color, M.SmoothPlastic)
	c:box('EaselFoot', back - V(0.3, 0.25, 0.3), back + V(0.3, 0.05, 0.3), foot)
	c:box('EaselLedge', V(x - w / 2 - 0.15, y - 0.25, z - 0.15), V(x + w / 2 + 0.15, y, z + 0.35), color)
end
-- Ice cube: pale glassy block, a snow cap and a white diagonal shine on its front.
function Stations.ice(c, name, cf, s, color)
	local p = c:part(name, V(s, s, s), cf, color or C(170, 236, 255), M.SmoothPlastic)
	p.Transparency, p.Reflectance = 0.12, 0.15
	c:part('IceCap', V(s - 0.12, 0.1, s - 0.12), cf * CFrame.new(0, s / 2 + 0.04, 0), C(250, 254, 255))
	c:part('IceShine', V(0.12, s * 0.7, 0.04), cf * CFrame.new(-s * 0.18, 0, -s / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	return p
end
-- Icicle hanging from `top` (the centre of its top edge): a wedge turned so its triangle faces -Z, wide at
-- the top, its point at the bottom.
function Stations.icicle(c, top, len, w, color)
	return decor(c:wedge('Icicle', V(0.2, len, w), CFrame.new(top - V(0, len / 2, 0)) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), color or C(205, 246, 255)))
end
-- Steel plate (square, a hot or neon border and a centre spot) facing -Z, centred on `cf`.
function Stations.plate(c, cf, w, face, edge, edgeMat, spot)
	c:part('Plate', V(w, w, 0.22), cf, face, M.Metal)
	for _, e in { { 0, w / 2 - 0.08, w, 0.16 }, { 0, -w / 2 + 0.08, w, 0.16 }, { w / 2 - 0.08, 0, 0.16, w - 0.32 }, { -w / 2 + 0.08, 0, 0.16, w - 0.32 } } do
		c:part('PlateEdge', V(e[3], e[4], 0.26), cf * CFrame.new(e[1], e[2], -0.03), edge, edgeMat)
	end
	if spot then Stations.disc(c, 'PlateSpot', cf * CFrame.new(0, 0, -0.1), w * 0.2, 0.1, spot, edgeMat) end
end
-- Gold nugget like the reference's: a flat bevelled slab (a low core with sloping wedges round it) with a
-- smaller centred lump on top, lemon gold, never an amber pile.
function Stations.nugget(c, x, z, s, turn)
	local Y, col = Stations.MAT_Y, C(255, 228, 0)
	local cf = CFrame.new(x, Y, z) * CFrame.Angles(0, turn or 0, 0)
	local function lump(at, w, h, d, slope)
		c:part('Nugget', V(w, h, d), at * CFrame.new(0, h / 2, 0), col)
		for k = 0, 3 do
			local len = (k % 2 == 0) and w or d
			local out = (k % 2 == 0) and d / 2 or w / 2
			c:wedge('NuggetSlope', V(len, h, slope), at * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h / 2, -(out + slope / 2)), col)
		end
	end
	lump(cf, 1.3 * s, 0.32 * s, 1.0 * s, 0.4 * s)
	lump(cf * CFrame.new(0, 0.32 * s, 0), 0.75 * s, 0.18 * s, 0.55 * s, 0.25 * s)
end
-- A ring of eight slabs (outer apothem a, slab thickness th, height h) standing on `cf` (the base centre).
function Stations.ring8(c, name, cf, a, th, h, color, material)
	local w = 2 * a * math.tan(math.pi / 8) + 0.02
	for k = 0, 7 do c:part(name, V(w, h, th), cf * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, h / 2, -a + th / 2), color, material) end
end
-- The gold lane's crown on the gantry: a deep-gold band of eight slabs on a white rim, tall and short points
-- (white tips on the tall ones), ruby and sapphire gems round the band; ~2.8 wide, ~1.9 tall. It turns slowly.
function Stations.crown(g, at)
	local cc, crown = g:group('Crown')
	local body, deep, white = C(245, 190, 0), C(222, 150, 0), C(255, 252, 235)
	Stations.ring8(cc, 'CrownRim', at, 1.42, 0.3, 0.22, white)
	Stations.ring8(cc, 'CrownBand', at * CFrame.new(0, 0.2, 0), 1.35, 0.3, 0.75, body)
	for k = 0, 7 do
		local face = at * CFrame.Angles(0, k * math.pi / 4, 0)
		local tall = k % 2 == 0
		local s = tall and 0.78 or 0.52
		local cy = 0.95 + s * 0.25
		cc:part('CrownPoint', V(s, s, 0.24), face * CFrame.new(0, cy, -1.22) * CFrame.Angles(0, 0, math.pi / 4), tall and body or deep)
		if tall then cc:part('CrownTip', V(0.3, 0.3, 0.3), face * CFrame.new(0, cy + s * 0.71, -1.22), white, M.SmoothPlastic, Enum.PartType.Ball) end
		cc:part('CrownGem', V(0.3, 0.3, 0.16), face * CFrame.new(0, 0.58, -1.36) * CFrame.Angles(0, 0, math.pi / 4), tall and C(235, 30, 70) or C(50, 110, 255), M.Glass)
	end
	for _, p in crown:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	crown.WorldPivot = cc:world(at)
	crown:SetAttribute('Spin', 40)
	crown:AddTag('HoodMotion')
	return crown
end
-- A blocky painted digit (seven segments, 1.3 x h) lying on the mat at `z0` (its foot, nearest the aisle),
-- readable from the aisle end: its top points down the lane.
Stations.DIGITS = { [1] = 'bc', [2] = 'abged', [3] = 'abgcd', [4] = 'fgbc', [5] = 'afgcd', [6] = 'afgedc', [7] = 'abc', [8] = 'abcdefg', [9] = 'abcdfg' }
function Stations.digit(c, n, z0, h, color)
	local Y, W, t = Stations.MAT_Y, 1.3, 0.34
	local seg = {
		a = { -W / 2, W / 2, h - t, h }, g = { -W / 2, W / 2, h / 2 - t / 2, h / 2 + t / 2 }, d = { -W / 2, W / 2, 0, t },
		f = { -W / 2, -W / 2 + t, h / 2, h }, e = { -W / 2, -W / 2 + t, 0, h / 2 }, b = { W / 2 - t, W / 2, h / 2, h }, c = { W / 2 - t, W / 2, 0, h / 2 },
	}
	for ch in string.gmatch(Stations.DIGITS[n] or '', '.') do
		local s = seg[ch]
		-- Digit space (u right, v up) seen from the aisle: u = -x, v = z - z0.
		local p = decor(c:box('LaneDigit', V(-s[2], Y, z0 + s[3]), V(-s[1], Y + 0.03, z0 + s[4]), color, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.15
	end
end

---------------------------------------------------------------------------------------------- targets
-- A target the client can knock: Equipment > Targets > Target<i> with a Hinge (the pivot, a ghost part at
-- `pivot`) and a Swing model (build the visible target into the returned context). knock: 'Tip' (tips back about
-- the hinge's X axis with a little hop), 'Swing' (swings on its hanger), 'Spin' (spins about the hinge's Y axis),
-- 'Pop' (bursts into confetti and grows back), 'Shatter' (bursts into shards and grows back), 'Fly' (flies off
-- spinning and pops back). `aim` is where shots land (local), `main` marks the HitPoint target, `hit` names the
-- sound it makes (Ding steel, Tock wood, Glass, Tin, Pop, Ice, Barrel), `shard` colours its shards/confetti.
function Stations.target(k, pivot, aim, knock, main, hit, shard)
	local n = #k.list + 1
	local tc, model = k.targets:group('Target' .. n)
	ghost(tc:part('Hinge', V(0.2, 0.2, 0.2), pivot, P.white))
	local sw = tc:group('Swing')
	model:SetAttribute('Knock', knock)
	model:SetAttribute('Hit', hit or 'Ding')
	if shard then model:SetAttribute('ShardColor', shard) end
	model:SetAttribute('Aim', tc:world(CFrame.new(aim)).Position)
	if main then
		model:SetAttribute('Main', true)
		k.main = model
		k.mainAim = aim
	end
	table.insert(k.list, model)
	return sw, model
end

---------------------------------------------------------------------------------------------- frame pieces
-- The ring the mat sits in: a lower band (its aisle face stamped with a row of X's) under a lighter studded lip
-- (a glowing neon lip on toxic), both with two-step pixel corners.
function Stations.rim(st, t)
	local MX, MZ = Stations.HALF_X - 1, Stations.HALF_Z - 1
	local function ring(name, y0, y1, inset, color, top, material)
		local X, Z = Stations.HALF_X - inset, Stations.HALF_Z - inset
		local bars = {
			{ V(-MX, y0, -Z), V(MX, y1, -MZ), Enum.NormalId.Front }, { V(-MX, y0, MZ), V(MX, y1, Z), Enum.NormalId.Back },
			{ V(-X, y0, -MZ), V(-MX, y1, MZ), Enum.NormalId.Left }, { V(MX, y0, -MZ), V(X, y1, MZ), Enum.NormalId.Right },
		}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do table.insert(bars, { V(sx * MX, y0, sz * MZ), V(sx * (X - 0.5), y1, sz * (Z - 0.5)) }) end
		end
		for _, b in bars do
			local p = st:box(name, b[1], b[2], color, material)
			if top and not material then studs(p) elseif not top and b[3] then Stations.stamp(p, { b[3] }, (y1 - y0) * 2.4, y1 - y0, Stations.grooveFor(t, color)) end
		end
	end
	ring('RimBase', 0, 0.45, 0, t.rim, false)
	ring('Rim', 0.45, Stations.RIM_Y, 0.12, t.rimTop, true, t.rimTopMat)
	-- a glowing strip along the lip's aisle face in the lane's hit colour: the lane's interactive outline, where you
	-- step on (toxic's lip glows already)
	if t.rimTopMat ~= M.Neon then
		decor(st:box('RimGlow', V(-MX + 0.1, 0.47, -Stations.HALF_Z + 0.07), V(MX - 0.1, 0.57, -Stations.HALF_Z + 0.14), t.edge or t.glow, M.Neon)).CastShadow = false
	end
end

-- The shooter's end: a waist-high bench across the lane (a dark kick plate, a stamped front with four X's, a
-- band in the theme's trim colour, a studded top in the lip colour) with an ammo box, a few shells and ear
-- muffs on it; in front of it a yellow and black hazard stripe (the firing line); in the box two shoe prints and
-- the lane's number in big blocky digits, readable from the aisle.
function Stations.bench(st, t, tier)
	local Y, z, h = Stations.MAT_Y, Stations.BENCH_Z, Stations.BENCH_H
	local g = st:group('Bench')
	local body = t.frame
	local mat = t.frameMat == M.Neon and M.SmoothPlastic or (t.frameMat or M.SmoothPlastic)
	if t.frameMat == M.Neon then body = t.rim end -- a neon bench would glare: toxic gets its rim green
	local kick = body:Lerp(C(0, 0, 0), 0.35)
	g:box('BenchKick', V(-3.45, Y, z - 0.47), V(3.45, Y + 0.32, z + 0.4), kick)
	local front = g:box('BenchFront', V(-3.4, Y + 0.32, z - 0.42), V(3.4, Y + h - 0.62, z + 0.42), body, mat)
	Stations.panelX(g, front, CFrame.new(0, Y + 0.32 + (h - 0.94) / 2, z - 0.42), 6.8, h - 0.94, 3, Stations.grooveFor(t, body))
	g:box('BenchBand', V(-3.42, Y + h - 0.62, z - 0.46), V(3.42, Y + h - 0.3, z + 0.3), t.trim or t.rimTop, t.trim and M.SmoothPlastic or t.rimTopMat)
	local top = g:box('BenchTop', V(-3.6, Y + h - 0.3, z - 0.62), V(3.6, Y + h, z + 0.5), t.rimTop, t.rimTopMat)
	if not t.rimTopMat then studs(top) end
	local d = st:group('BenchProps')
	local y = Y + h
	-- Ammo box (olive, a yellow stripe and a handle).
	decor(d:box('AmmoBox', V(2.15, y, z - 0.3), V(3.05, y + 0.48, z + 0.22), C(86, 104, 58)))
	decor(d:box('AmmoStripe', V(2.13, y + 0.3, z - 0.32), V(3.07, y + 0.38, z + 0.24), C(250, 200, 40)))
	decor(d:box('AmmoHandle', V(2.45, y + 0.48, z - 0.08), V(2.75, y + 0.56, z), C(40, 44, 40)))
	-- A few brass shells lying about.
	for i, s in { { 1.45, -0.15, 0.3 }, { 1.7, 0.08, 1.4 } } do
		decor(d:part('Shell', V(0.32, 0.14, 0.14), CFrame.new(s[1], y + 0.07, z + s[2]) * CFrame.Angles(0, s[3], 0), i == 2 and C(232, 176, 72) or C(244, 194, 80), M.Metal, Enum.PartType.Cylinder))
	end
	-- Ear muffs: two dark cups joined by a yellow band.
	local yellow = C(255, 210, 50)
	for _, sx in { -1, 1 } do
		decor(d:blob('EarCup', V(0.5, 0.55, 0.55), V(-2.6 + sx * 0.42, y + 0.28, z - 0.05), C(50, 52, 60), M.SmoothPlastic))
	end
	decor(d:box('EarArch', V(-3.0, y + 0.5, z - 0.12), V(-2.2, y + 0.64, z + 0.02), yellow)) -- (resting on the cups)
	-- Painted on the mat: the box outline (white on dark mats, the groove colour on pale ones), the hazard
	-- stripe, two shoe prints and the lane number.
	local m = t.mat
	local pale = 0.299 * m.R + 0.587 * m.G + 0.114 * m.B > 0.7
	local edge = pale and Stations.grooveFor(t, m) or C(250, 250, 245)
	local x0, x1, b0, b1, w = -3.25, 3.25, -8.75, -3.9, 0.14
	for _, b in { { V(x0, Y, b0), V(x1, Y + 0.03, b0 + w) }, { V(x0, Y, b0), V(x0 + w, Y + 0.03, b1) }, { V(x1 - w, Y, b0), V(x1, Y + 0.03, b1) } } do
		local p = decor(st:box('BoxLine', b[1], b[2], edge, M.SmoothPlastic))
		p.CastShadow, p.Transparency = false, 0.2
	end
	local fire = decor(st:box('FiringLine', V(-3.5, Y, -3.9), V(3.5, Y + 0.03, -3.5), C(255, 214, 30), M.SmoothPlastic))
	fire.CastShadow = false
	local fg = surface(fire, Enum.NormalId.Top, 20)
	for i = 0, 8 do
		local f = Instance.new('Frame')
		f.Name = 'FiringStripe'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = C(30, 30, 36)
		f.Position, f.Size = UDim2.fromScale((i + 0.2) / 9, 0), UDim2.fromScale(0.5 / 9, 1)
		f.Parent = fg
	end
	for _, sx in { -1, 1 } do
		local x = sx * 0.45
		local sole = decor(st:box('ShoePrint', V(x - 0.3, Y, -5.1), V(x + 0.3, Y + 0.03, -4.0), edge, M.SmoothPlastic))
		sole.CastShadow, sole.Transparency = false, 0.25
	end
	Stations.digit(st, tier, -8.5, 2.3, edge)
end

-- The lane's side walls, like the video's lanes walled at the sides (ours hood walls, not sandbags): a low wall on
-- each long side of the rim from just inside the aisle end to the backstop, a dark plinth, the body and a pale
-- studded cap (base, body, cap), a gate pier with a taller cap at the aisle end. Each theme its own wall: brick
-- with a concrete cap (stone), navy block (red), basalt (lava), painted block (arcane), obsidian (shadow), ice with
-- snow (frost), a container's teal steel with a hazard cap (toxic), cream stone on velvet with gold (gold).
-- Walls break round the gantry feet (lanes with a gantry).
Stations.Walls = {
	stone = { body = C(178, 86, 68), base = C(118, 58, 48), cap = C(216, 212, 204), course = C(214, 200, 188), courses = 2 },
	red = { body = C(48, 54, 100), base = C(26, 30, 66), cap = C(240, 62, 86) },
	lava = { body = C(78, 56, 60), base = C(48, 34, 38), cap = C(255, 150, 50) },
	arcane = { body = C(124, 52, 172), base = C(80, 30, 112), cap = C(240, 124, 212) },
	shadow = { body = C(44, 32, 62), base = C(22, 16, 34), cap = C(96, 60, 146) },
	frost = { body = C(150, 222, 248), base = C(30, 110, 210), cap = C(248, 252, 255) },
	toxic = { body = C(26, 72, 66), base = C(14, 42, 40), cap = C(255, 214, 30) },
	gold = { body = C(255, 244, 216), base = C(150, 15, 40), cap = C(255, 214, 40) },
}
Stations.WALL_TOP = 2.55 -- the walls' top over the deck (the bench is 2.7)
function Stations.walls(st, t)
	local w = Stations.Walls[t.name] or Stations.Walls.stone
	local g = st:group('Walls')
	local top, z0, z1 = Stations.WALL_TOP, -8.5, Stations.BACK_Z
	local runs = { { z0 + 0.9, z1 } }
	if t.name ~= 'stone' and t.name ~= 'red' then
		runs = { { z0 + 0.9, Stations.GANTRY_Z - 0.62 }, { Stations.GANTRY_Z + 0.62, z1 } }
	end
	for _, sx in { -1, 1 } do
		local function X(a, b) return math.min(sx * a, sx * b), math.max(sx * a, sx * b) end
		for _, r in runs do
			local a0, a1 = X(3.66, 4.5)
			local b0, b1 = X(3.76, 4.42)
			g:box('WallBase', V(a0, Stations.RIM_Y, r[1]), V(a1, 1.0, r[2]), w.base)
			g:box('Wall', V(b0, 1.0, r[1]), V(b1, top - 0.3, r[2]), w.body)
			-- a course line half way up (mortar on brick, a seam on the rest)
			local nc = w.courses or 1
			for k = 1, nc do
				local my = 1.0 + (top - 1.3) * k / (nc + 1)
				decor(g:box('WallCourse', V(b0 - 0.04, my - 0.07, r[1] + 0.05), V(b1 + 0.04, my + 0.07, r[2] - 0.05), w.course or w.base)).CastShadow = false
			end
			studs(g:box('WallCap', V(a0, top - 0.3, r[1]), V(a1, top, r[2]), w.cap))
		end
		-- the gate pier at the aisle end
		local p0, p1 = X(3.62, 4.5)
		g:box('WallPier', V(p0, Stations.RIM_Y, z0), V(p1, top + 0.35, z0 + 0.9), w.base)
		studs(g:box('WallPierCap', V(p0, top + 0.35, z0 - 0.06), V(p1, top + 0.7, z0 + 0.96), w.cap))
	end
	-- a hood prop on the left pier's cap, the lane's own
	local prop = Stations.Hood[t.name]
	if prop then prop(g, CFrame.new(-4.08, top + 0.7, z0 + 0.45)) end
end

-- Small hood props (chunky, a few parts each) standing on `cf` (its top centre of the surface they sit on, -Z out
-- toward the aisle): a traffic cone, a boombox, a milk crate of sodas, a sneaker box, spray cans, a cooler.
Stations.Hood = {}
function Stations.cone(g, cf, color)
	color = color or C(255, 120, 30)
	g:part('ConeFoot', V(0.85, 0.12, 0.85), cf * CFrame.new(0, 0.06, 0), C(40, 40, 46))
	for i, e in { { 0.62, 0.35, color }, { 0.46, 0.3, C(250, 250, 245) }, { 0.32, 0.32, color }, { 0.18, 0.16, color } } do
		local y = 0.12 + (i == 1 and 0 or i == 2 and 0.35 or i == 3 and 0.65 or 0.97)
		g:part('Cone', V(e[1], e[2], e[1]), cf * CFrame.new(0, y + e[2] / 2, 0), e[3])
	end
end
function Stations.boombox(g, cf, body, trim)
	body, trim = body or C(40, 42, 50), trim or C(235, 50, 60)
	g:part('Boombox', V(1.05, 0.55, 0.5), cf * CFrame.new(0, 0.3, 0), body)
	g:part('BoomboxBand', V(1.07, 0.12, 0.52), cf * CFrame.new(0, 0.5, 0), trim)
	local face = CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's axis turned to face -Z, the aisle)
	for _, dx in { -0.27, 0.27 } do
		g:part('BoomboxSpeaker', V(0.06, 0.4, 0.4), cf * CFrame.new(dx, 0.27, -0.26) * face, C(20, 20, 24), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('BoomboxCone', V(0.08, 0.18, 0.18), cf * CFrame.new(dx, 0.27, -0.27) * face, C(150, 156, 170), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	g:part('BoomboxHandle', V(0.8, 0.12, 0.12), cf * CFrame.new(0, 0.72, 0), C(20, 20, 24))
end
function Stations.milkcrate(g, cf, color, sodas)
	g:part('MilkCrate', V(0.86, 0.6, 0.86), cf * CFrame.new(0, 0.3, 0), color)
	g:part('MilkCrateRim', V(0.9, 0.12, 0.9), cf * CFrame.new(0, 0.6, 0), color:Lerp(C(255, 255, 255), 0.25))
	for i, c in sodas or {} do
		local x = (i - (#sodas + 1) / 2) * 0.3
		g:part('Soda', V(0.18, 0.42, 0.18), cf * CFrame.new(x, 0.75, 0.05 * i), c)
		g:part('SodaCap', V(0.1, 0.08, 0.1), cf * CFrame.new(x, 1.0, 0.05 * i), C(250, 250, 245))
	end
end
function Stations.sneakerBox(g, cf, color)
	g:part('ShoeBox', V(0.62, 0.42, 0.98), cf * CFrame.new(0, 0.21, 0), color)
	g:part('ShoeBoxLid', V(0.66, 0.12, 1.02), cf * CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(-8)), C(250, 250, 245))
	g:part('Sneaker', V(0.36, 0.22, 0.8), cf * CFrame.new(0.05, 0.65, 0), C(250, 250, 245))
	g:part('SneakerSole', V(0.38, 0.08, 0.82), cf * CFrame.new(0.05, 0.52, 0), color:Lerp(C(0, 0, 0), 0.3))
	g:part('SneakerSwoosh', V(0.37, 0.07, 0.42), cf * CFrame.new(0.05, 0.66, 0.08), color)
end
function Stations.sprayCans(g, cf, colors)
	for i, c in colors do
		local at = cf * CFrame.new((i - 2) * 0.27, 0, (i % 2) * 0.18 - 0.09)
		g:part('SprayCan', V(0.48, 0.24, 0.24), at * CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.pi / 2), c, M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('SprayCap', V(0.12, 0.2, 0.2), at * CFrame.new(0, 0.54, 0) * CFrame.Angles(0, 0, math.pi / 2), C(250, 250, 245), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
end
function Stations.cooler(g, cf, color)
	g:part('Cooler', V(0.8, 0.5, 1.0), cf * CFrame.new(0, 0.25, 0), color)
	g:part('CoolerLid', V(0.84, 0.14, 1.04), cf * CFrame.new(0, 0.57, 0), C(250, 250, 245))
	g:part('CoolerHandle', V(0.12, 0.1, 0.6), cf * CFrame.new(0, 0.69, 0), C(40, 44, 54))
end
Stations.Hood.stone = function(g, cf) Stations.cone(g, cf) end
Stations.Hood.red = function(g, cf) Stations.boombox(g, cf) end
Stations.Hood.lava = function(g, cf) Stations.milkcrate(g, cf, C(240, 110, 30), { C(235, 55, 60), C(60, 140, 240) }) end
Stations.Hood.arcane = function(g, cf) Stations.sneakerBox(g, cf, C(240, 90, 180)) end
Stations.Hood.shadow = function(g, cf) Stations.sprayCans(g, cf, { C(160, 80, 255), C(30, 28, 40), C(255, 90, 200) }) end
Stations.Hood.frost = function(g, cf) Stations.cooler(g, cf, C(40, 130, 230)) end
Stations.Hood.toxic = function(g, cf) Stations.milkcrate(g, cf, C(30, 160, 60), { C(60, 220, 90), C(60, 220, 90) }) end
Stations.Hood.gold = function(g, cf) Stations.boombox(g, cf, C(245, 196, 30), C(150, 15, 40)) end

-- The backstop's body: a wall across the outer end with a stepped top (two steps each side, like the rim's
-- pixel corners), its front stamped with X's. Returns the three blocks (base, step, top).
function Stations.wall(c, t, color, material, h, groove)
	local Y, z0, z1 = Stations.MAT_Y, Stations.BACK_Z, Stations.HALF_Z - 0.1
	h = h or 5.6
	groove = groove or Stations.grooveFor(t, color)
	local base = c:box('Backstop', V(-4.3, 0, z0), V(4.3, Y + h, z1), color, material)
	local step = c:box('BackstopStep', V(-2.9, Y + h, z0 + 0.15), V(2.9, Y + h + 0.8, z1), color, material)
	local top = c:box('BackstopTop', V(-1.5, Y + h + 0.8, z0 + 0.3), V(1.5, Y + h + 1.4, z1), color, material)
	if material ~= M.Neon then
		Stations.panelX(c, base, CFrame.new(0, (Y + h) / 2, z0), 8.6, Y + h, 3, groove)
		-- caps over every exposed top, a lighter tone a little proud of the front (finished edges)
		local cap = t.wallCap or t.trim or t.rimTop
		for _, b in { { -4.36, -2.9, Y + h, z0 - 0.08 }, { 2.9, 4.36, Y + h, z0 - 0.08 }, { -2.96, -1.5, Y + h + 0.8, z0 + 0.07 },
			{ 1.5, 2.96, Y + h + 0.8, z0 + 0.07 }, { -1.56, 1.56, Y + h + 1.4, z0 + 0.22 } } do
			c:box('BackstopCap', V(b[1], b[3], b[4]), V(b[2], b[3] + 0.16, z1 + 0.02), cap, M.SmoothPlastic)
		end
	end
	return base, step, top
end
-- Thin lines along the wall's front: up both sides and along the top edge of each step (trim or neon).
function Stations.wallLines(c, h, color, material, th)
	local Y, z = Stations.MAT_Y, Stations.BACK_Z
	th = th or 0.14
	local lines = {
		{ V(-4.3, 0.6, z - 0.06), V(-4.3 + th, Y + h, z + 0.05) }, { V(4.3 - th, 0.6, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-4.3, Y + h - th, z - 0.06), V(-2.9, Y + h, z + 0.05) }, { V(2.9, Y + h - th, z - 0.06), V(4.3, Y + h, z + 0.05) },
		{ V(-2.9, Y + h + 0.8 - th, z + 0.09), V(-1.5, Y + h + 0.8, z + 0.2) }, { V(1.5, Y + h + 0.8 - th, z + 0.09), V(2.9, Y + h + 0.8, z + 0.2) },
		{ V(-1.5, Y + h + 1.4 - th, z + 0.24), V(1.5, Y + h + 1.4, z + 0.35) },
	}
	for _, b in lines do
		local p = decor(c:box('WallLine', b[1], b[2], color, material))
		if material == M.Neon then p.CastShadow = false end
	end
end

-- The truss gantry over the targets: two grooved truss posts on stamped feet at the lane's edges and a grooved
-- truss beam across, capped. Hanging targets hang from its underside (GANTRY_Y) on its centre line. neon: lines
-- on the posts' front edges and under the beam (shadow, gold, frost); look.width (default 0.14) and look.backing
-- (a dark strip 0.34 wide just behind each line, so it reads without bloom on a bright frame).
function Stations.gantry(g, t, neon, look)
	look = look or {}
	local nw, back = look.width or 0.14, look.backing
	local nz0, nz1 = back and 0.49 or 0.47, back and 0.35 or 0.33
	local Y, z, y0 = Stations.MAT_Y, Stations.GANTRY_Z, Stations.GANTRY_Y
	local W = 0.8
	local frame, fm = t.frame, t.frameMat or M.SmoothPlastic
	local groove = Stations.grooveFor(t, frame)
	local foot = frame:Lerp(C(0, 0, 0), 0.12)
	for _, sx in { -1, 1 } do
		local x = sx * 3.9
		Stations.stamp(g:box('GantryFoot', V(x - 0.55, 0.05, z - 0.6), V(x + 0.55, Y + 0.75, z + 0.6), fm == M.Neon and t.rim or foot), Stations.SIDES, 1.1, Y + 0.7, groove)
		Stations.truss(g, 'GantryPost', CFrame.new(x, Y + 0.75, z), y0 - Y - 0.75, W, W, frame, groove, 3.9, { '-z' }, fm)
		g:box('GantryCap', V(x - 0.55, y0 + W, z - 0.55), V(x + 0.55, y0 + W + 0.25, z + 0.55), fm == M.Neon and t.rim or frame)
		-- A small gusset under each end of the beam.
		g:wedge('GantryGusset', V(0.5, 0.8, 0.8), CFrame.new(x - sx * 0.8, y0 - 0.4, z) * CFrame.Angles(0, sx * math.pi / 2, 0), frame, fm)
		if neon then
			for _, ex in { 3.5, 4.3 } do
				if back then decor(g:box('GantryNeonBack', V(sx * ex - 0.17, Y + 0.76, z - 0.47), V(sx * ex + 0.17, y0 + 0.79, z - 0.31), back)).CastShadow = false end
				decor(g:box('GantryNeon', V(sx * ex - nw / 2, Y + 0.8, z - nz0), V(sx * ex + nw / 2, y0 + 0.75, z - nz1), neon, M.Neon)).CastShadow = false
			end
		end
	end
	Stations.truss(g, 'GantryBeam', CFrame.new(-4.35, y0 + W / 2, z) * CFrame.Angles(0, 0, -math.pi / 2), 8.7, W, W, frame, groove, 4.35, { '-z' }, fm)
	if neon then
		if back then decor(g:box('GantryNeonBack', V(-3.55, y0 - 0.17, z - 0.47), V(3.55, y0 + 0.17, z - 0.31), back)).CastShadow = false end
		decor(g:box('GantryNeon', V(-3.5, y0 - nw / 2, z - nz0), V(3.5, y0 + nw / 2, z - nz1), neon, M.Neon)).CastShadow = false
	end
end

-- Hang a target from the gantry's underside at x: two short chains down to the target's top `top`.
function Stations.chains(c, x, top, span)
	local y0 = Stations.GANTRY_Y
	for _, sx in { -1, 1 } do
		c:box('Chain', V(x + sx * span - 0.08, top - 0.05, Stations.GANTRY_Z - 0.08), V(x + sx * span + 0.08, y0 + 0.02, Stations.GANTRY_Z + 0.08), C(52, 54, 66))
	end
	c:box('Hook', V(x - span - 0.15, y0 - 0.14, Stations.GANTRY_Z - 0.15), V(x + span + 0.15, y0, Stations.GANTRY_Z + 0.15), C(52, 54, 66))
end

---------------------------------------------------------------------------------------------- lanes
-- One builder per theme: the backstop's dressing, the stands and the targets. `k` holds st (the station),
-- gear (Equipment > Gear), targets (Equipment > Targets), list, t, tier and burners (parts that get flames).
-- Every main target's centre sits ~5.8 over the mat (local y ~6.2): above the shooter's head from the follow
-- camera, so the thing you shoot is never hidden behind your own avatar.
Stations.Lanes = {}
Stations.SODA = { red = C(235, 55, 60), orange = C(255, 150, 30), blue = C(60, 140, 240), lime = C(130, 220, 60) }

-- 1 Stone: soda bottles and cans on a tall plank shelf; a rough plank backstop with a painted bullseye high up,
-- sandbags, bunting that flutters; a crate of spare sodas and a tyre stack.
function Stations.Lanes.stone(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local wood, soda = t.frame, Stations.SODA
	local z0 = Stations.BACK_Z
	local back = k.st:group('Backstop')
	for i, h in { 7.4, 7.9, 8.25, 8.45, 8.3, 7.95, 7.3 } do
		local x = -4.2 + (i - 0.5) * 1.2
		local p = back:box('Plank', V(x - 0.58, 0, z0 + (i % 2) * 0.05), V(x + 0.58, Y + h, z0 + 0.45), i % 2 == 0 and wood:Lerp(C(0, 0, 0), 0.12) or wood)
		Stations.stamp(p, { Enum.NormalId.Front }, 1.16, Y + h, Stations.grooveFor(t, wood), 0.35)
	end
	for _, y in { 1.2, 6.6 } do back:box('Batten', V(-4.3, Y + y, z0 + 0.5), V(4.3, Y + y + 0.45, z0 + 0.85), wood:Lerp(C(0, 0, 0), 0.2)) end
	Stations.bullseye(back, CFrame.new(0, Y + 6.8, z0 - 0.02), 1.15, { C(250, 250, 245), C(230, 50, 50), C(250, 250, 245), C(230, 50, 50) })
	for i, s in { { -2.9, 0, 1.9 }, { -0.95, 0, 1.9 }, { 0.95, 0, 1.9 }, { 2.9, 0, 1.9 }, { -1.9, 0.62, 1.8 }, { 1.95, 0.62, 1.8 } } do
		back:blob('Sandbag', V(s[3], 0.72, 1.05), V(s[1], Y + 0.34 + s[2], z0 - 0.6), i % 2 == 0 and C(158, 146, 120) or C(140, 130, 106), M.Fabric)
	end
	-- Bunting between two poles over the planks: two strands of little flags (red, yellow, blue, white), each on
	-- its own string, bobbing at different rates, so the pair ripples and no flag ever leaves its line.
	for _, sx in { -1, 1 } do back:box('BuntingPole', V(sx * 4.1 - 0.13, Y, z0 - 0.45), V(sx * 4.1 + 0.13, Y + 9.15, z0 - 0.19), wood:Lerp(C(0, 0, 0), 0.25)) end
	local flags = { C(235, 55, 60), C(255, 210, 50), C(60, 140, 240), C(250, 250, 245) }
	for strand, at in { { 8.95, 1.3, -0.33 }, { 8.62, 1.7, -0.27 } } do
		local bc, bunting = back:group('Bunting')
		local y, period, dz = at[1], at[2], at[3]
		bc:box('BuntingLine', V(-4.0, Y + y - 0.03, z0 + dz - 0.03), V(4.0, Y + y + 0.03, z0 + dz + 0.03), C(250, 250, 245))
		for i = strand - 1, 9, 2 do
			local sag = 0.15 * math.sin((i + 0.5) / 10 * math.pi)
			bc:wedge('Flag', V(0.06, 0.55, 0.62), CFrame.new(-3.6 + i * 0.8, Y + y - 0.3 - sag, z0 + dz) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), flags[i % 4 + 1])
			bc:box('FlagTie', V(-3.6 + i * 0.8 - 0.025, Y + y - 0.05 - sag, z0 + dz - 0.02), V(-3.6 + i * 0.8 + 0.025, Y + y, z0 + dz + 0.02), C(250, 250, 245))
		end
		for _, p in bunting:GetDescendants() do if p:IsA('BasePart') then decor(p).CastShadow = false end end
		bunting.WorldPivot = bc:world(CFrame.new(0, Y + y, z0 + dz))
		bunting:SetAttribute('Bob', 0.13)
		bunting:SetAttribute('BobPeriod', period)
		bunting:AddTag('HoodMotion')
	end
	-- The shelf: two posts, two rails and a deep top rail at chest height the targets stand on.
	local fz, top = 5.0, Y + 4.4
	for _, sx in { -1, 1 } do g:box('FencePost', V(sx * 3.05 - 0.28, Y, fz - 0.28), V(sx * 3.05 + 0.28, top + 0.15, fz + 0.28), wood:Lerp(C(0, 0, 0), 0.15)) end
	for _, ry in { 1.3, 2.9 } do g:box('FenceRail', V(-3.45, Y + ry, fz - 0.15), V(3.45, Y + ry + 0.35, fz + 0.15), wood) end
	g:box('FenceShelf', V(-3.5, top - 0.25, fz - 0.95), V(3.5, top, fz + 0.95), wood:Lerp(C(255, 255, 255), 0.08))
	-- Targets, left to right: soda bottle, can, the big cola can with a bullseye (main), can, bottle. Bottles
	-- shatter, small cans fly off; the big can rocks back on its back edge and stays (it is the one you shoot
	-- every other shot, so it is always there).
	local items = {
		{ -2.75, 'bottle', soda.orange, 1.25, nil, C(255, 255, 255) }, { -1.5, 'tin', soda.blue, 0.55, 1.25 }, { 0, 'tin', soda.red, 0.88, 2.0, true },
		{ 1.5, 'tin', soda.lime, 0.55, 1.25 }, { 2.75, 'bottle', soda.blue, 1.25, nil, C(255, 214, 40) },
	}
	for _, it in items do
		local base = V(it[1], top, fz)
		local h = it[2] == 'bottle' and 1.5 * it[4] or it[5]
		local bottle = it[2] == 'bottle'
		local main = it[6] == true
		local hinge = main and V(0, 0, it[4]) or V(0, 0, 0.2)
		local sw, model = Stations.target(k, CFrame.new(base + hinge), base + V(0, h / 2, 0), bottle and 'Shatter' or (main and 'Tip' or 'Fly'), main, bottle and 'Glass' or 'Tin', it[3])
		if main then model:SetAttribute('TipMin', 0) end
		if bottle then Stations.bottle(sw, base, it[4], it[3], { stripe = it[3], cap = it[6] })
		else Stations.tin(sw, base, it[4], it[5], it[3], C(255, 255, 255), it[6] and 0.75 or nil) end
	end
	-- Story props: a crate of spare sodas, a stack of old tyres, a can that already fell.
	local crate = g:box('Crate', V(-3.3, Y, 1.3), V(-1.7, Y + 1.1, 2.7), C(196, 140, 80))
	Stations.stamp(crate, Stations.SIDES, 1.6, 1.1, C(150, 98, 52))
	local colors = { soda.red, soda.orange, soda.blue, soda.lime, soda.blue, soda.red }
	local n = 0
	for _, x in { -2.95, -2.5, -2.05 } do
		for _, z in { 1.7, 2.3 } do
			n += 1
			Stations.bottle(g, V(x, Y + 1.1, z), 0.55, colors[n])
		end
	end
	for i, y in { 0, 0.5 } do
		local at = CFrame.new(2.55 + i * 0.12, Y + y + 0.25, 1.9) * CFrame.Angles(0, 0, math.pi / 2)
		g:part('Tyre', V(0.5, 1.7, 1.7), at, C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		g:part('TyreHub', V(0.52, 0.8, 0.8), at, C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
	end
	g:part('FallenCan', V(0.95, 0.84, 0.84), CFrame.new(1.2, Y + 0.42, 3.2) * CFrame.Angles(0, 0.6, 0), soda.blue, M.SmoothPlastic, Enum.PartType.Cylinder)
end

-- 2 Red: three bullseye boards on navy easels (the main one up high); a navy board backstop with red trim and a
-- little target sign.
function Stations.Lanes.red(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local back = k.st:group('Backstop')
	local h = 6.6
	Stations.wall(back, t, t.frame, M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.trim, M.SmoothPlastic, 0.3)
	Stations.bullseye(back, CFrame.new(0, Y + h + 1.1, Stations.BACK_Z + 0.28), 0.45, { C(250, 250, 245), t.trim, C(250, 250, 245) })
	local rings = { C(250, 250, 245), C(235, 35, 60), C(250, 250, 245), C(235, 35, 60), C(255, 214, 40) }
	-- Boards: big centre (main), two small at the sides, at different depths and heights.
	for _, b in { { 0, 6.0, 4.0, 1.78, true }, { -2.55, 4.5, 1.5, 1.0 }, { 2.6, 4.1, 2.15, 1.0 } } do
		local x, bz, ledge, r = b[1], b[2], Y + b[3], b[4]
		Stations.easel(g, x, bz, ledge, r * 1.6, t.frame)
		local sw = Stations.target(k, CFrame.new(x, ledge, bz + 0.1), V(x, ledge + r, bz), 'Tip', b[5], 'Tock')
		Stations.disc(sw, 'Board', CFrame.new(x, ledge + r, bz + 0.12), r + 0.12, 0.18, t.frame)
		Stations.bullseye(sw, CFrame.new(x, ledge + r, bz + 0.03), r, rings)
	end
	-- A spare board leaning on the backstop.
	local lean = CFrame.new(3.35, Y + 1.05, Stations.BACK_Z - 0.45) * CFrame.Angles(math.rad(-12), math.rad(-8), 0)
	Stations.disc(g, 'Board', lean, 0.95, 0.15, t.frame)
	Stations.bullseye(g, lean * CFrame.new(0, 0, -0.08), 0.85, { C(250, 250, 245), C(235, 35, 60), C(250, 250, 245) })
end

-- 3 Lava: hot plates swinging from the gantry (a big gong is the main), burning barrels at the sides, a basalt
-- berm with lava cracks and a hot pool on top, nearly as tall as the gantry.
function Stations.Lanes.lava(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local rock, rock2, hot = C(62, 44, 48), C(84, 58, 58), C(255, 110, 20)
	local z0 = Stations.BACK_Z
	local blocks = {
		{ -4.3, -1.5, 0, 3.1, 0.0, rock, 3 }, { -1.6, 1.5, 0, 3.5, -0.15, rock2, -2 }, { 1.4, 4.3, 0, 2.9, 0.05, rock, 4 },
		{ -3.9, -0.1, 3.0, 6.0, 0.1, rock2, -3 }, { -0.2, 4.0, 2.8, 6.3, -0.05, rock, 2 }, { -2.0, 1.8, 5.9, 7.6, 0.2, rock2, -4 },
	}
	for _, b in blocks do
		local cx, cy = (b[1] + b[2]) / 2, (b[3] + b[4]) / 2 + Y / 2
		back:part('Basalt', V(b[2] - b[1], b[4] - b[3] + (b[3] == 0 and Y or 0), Stations.HALF_Z - 0.1 - z0 - b[5]),
			CFrame.new(cx, cy, (z0 + b[5] + Stations.HALF_Z - 0.1) / 2) * CFrame.Angles(0, 0, math.rad(b[7])), b[6], M.Slate)
	end
	-- Glowing cracks along the joints and a hot pool on top.
	for _, c in { { -4.2, 4.2, Y + 3.05 }, { -3.6, 3.8, Y + 6.0 } } do
		decor(back:box('LavaCrack', V(c[1], c[3] - 0.08, z0 - 0.3), V(c[2], c[3] + 0.08, z0 + 0.4), hot, M.Neon)).CastShadow = false
	end
	for _, x in { -1.5, 1.4 } do decor(back:box('LavaCrack', V(x - 0.08, 0.5, z0 - 0.25), V(x + 0.08, Y + 3.05, z0 + 0.4), hot, M.Neon)).CastShadow = false end
	decor(back:box('LavaPool', V(-1.8, Y + 7.38, z0 + 0.4), V(1.7, Y + 7.5, Stations.HALF_Z - 0.3), C(255, 170, 30), M.Neon)).CastShadow = false
	-- Plates: a big round gong (main) between two square plates, all hanging from the beam.
	local function gong(sw, x, cy, r)
		Stations.disc(sw, 'GongRim', CFrame.new(x, cy, Stations.GANTRY_Z), r, 0.25, C(70, 66, 76), M.Metal)
		Stations.disc(sw, 'GongHot', CFrame.new(x, cy, Stations.GANTRY_Z - 0.05), r * 0.8, 0.3, C(255, 120, 20), M.Neon)
		Stations.disc(sw, 'GongCore', CFrame.new(x, cy, Stations.GANTRY_Z - 0.1), r * 0.42, 0.34, C(255, 225, 90), M.Neon)
		Stations.chains(sw, x, cy + r - 0.1, r * 0.45)
	end
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, 6.2, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	gong(sw, 0, 6.2, 1.62)
	for _, p in { { -2.65, 4.3, 1.4 }, { 2.65, 4.9, 1.35 } } do
		local s2 = Stations.target(k, CFrame.new(p[1], Stations.GANTRY_Y, Stations.GANTRY_Z), V(p[1], p[2], Stations.GANTRY_Z), 'Swing', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], p[2], Stations.GANTRY_Z), p[3], C(64, 60, 70), C(255, 120, 20), M.Neon, C(255, 220, 80))
		Stations.chains(s2, p[1], p[2] + p[3] / 2, p[3] * 0.32)
	end
	-- Burning barrels (flames come from HoodVFX on their open tops).
	for _, b in { { -2.85, 1.9 }, { 2.9, 3.1 } } do
		local pos = V(b[1], Y, b[2])
		Stations.drum(g, pos, 0.62, 1.7, C(150, 50, 32), C(70, 34, 28), C(40, 24, 22), M.Metal)
		local coal = decor(g:part('Coals', V(0.08, 1.0, 1.0), CFrame.new(pos + V(0, 1.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(255, 150, 30), M.Neon, Enum.PartType.Cylinder))
		table.insert(k.burners, coal)
	end
end

-- 4 Arcane: a big spinner disc up high (main), two balloons to pop, balloon bunches bobbing on the gantry posts,
-- a deep violet wall with a pink starburst behind the spinner and white sparkle diamonds.
function Stations.Lanes.arcane(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	Stations.gantry(g, t)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(90, 30, 140), M.SmoothPlastic, h)
	Stations.wallLines(back, h, t.rimTop, M.SmoothPlastic, 0.18)
	local z = Stations.BACK_Z
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 3.7, 0.16, t.rimTop)
	for _, s in { { -3.3, 6.6 }, { 3.2, 2.0 }, { -3.1, 1.6 }, { 3.35, 6.4 }, { -2.6, 4.0 }, { 2.8, 4.6 } } do
		decor(back:part('Sparkle', V(0.42, 0.42, 0.1), CFrame.new(s[1], Y + s[2], z - 0.06) * CFrame.Angles(0, 0, math.pi / 4), C(255, 240, 255), M.Neon)).CastShadow = false
	end
	-- Spinner: a chunky post with a big ringed disc on a hub; it turns slowly and spins when hit.
	local sz = 6.0
	g:box('SpinnerPost', V(-0.2, Y, sz + 0.3), V(0.2, Y + 5.8, sz + 0.7), t.frame)
	g:box('SpinnerFoot', V(-0.75, Y, sz - 0.2), V(0.75, Y + 0.35, sz + 1.2), t.frame:Lerp(C(0, 0, 0), 0.25))
	local sw = Stations.target(k, CFrame.new(0, Y + 5.8, sz), V(0, Y + 5.8, sz), 'Spin', true, 'Ding')
	Stations.disc(sw, 'SpinnerBack', CFrame.new(0, Y + 5.8, sz + 0.12), 1.72, 0.16, t.frame)
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, sz + 0.03), 1.62, { C(255, 255, 255), C(255, 100, 200), C(255, 255, 255), C(150, 60, 220), C(255, 220, 60) })
	-- Balloons to pop, tied to little weights.
	for _, b in { { -2.6, 4.4, Y + 4.2, C(255, 90, 170) }, { 2.65, 5.1, Y + 4.9, C(80, 200, 255) } } do
		local pos = V(b[1], b[3], b[2])
		g:box('BalloonWeight', V(b[1] - 0.22, Y, b[2] - 0.22), V(b[1] + 0.22, Y + 0.35, b[2] + 0.22), C(255, 214, 60))
		local s2 = Stations.target(k, CFrame.new(pos), pos, 'Pop', false, 'Pop', b[4])
		Stations.balloon(s2, pos, 0.62, b[4], V(b[1], Y + 0.35, b[2]))
	end
	-- Bunches of three on each gantry post (they bob; not targets).
	for _, sx in { -1, 1 } do
		local bc, bunch = g:group('BalloonBunch')
		local foot = V(sx * 3.9, Stations.GANTRY_Y + 1.05, Stations.GANTRY_Z) -- (on the post's cap)
		for i, c in { C(255, 90, 170), C(255, 220, 60), C(120, 220, 255) } do
			local a = (i - 2) * 0.6
			Stations.balloon(bc, foot + V(math.sin(a) * 1.0 - sx * 0.15, 0.95 + math.cos(a) * 0.35, -0.2 * i), 0.6, c, foot)
		end
		for _, p in bunch:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
		bunch.WorldPivot = bc:world(CFrame.new(foot))
		bunch:SetAttribute('Bob', 0.14)
		bunch:SetAttribute('BobPeriod', 2.6 + sx * 0.3)
		bunch:AddTag('HoodMotion')
	end
end

-- 5 Shadow: dark plates with violet neon rims (a big hanging one is the main, haloed by a neon ring on the
-- obsidian wall), violet neon on the gantry and along the wall's steps.
function Stations.Lanes.shadow(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local violet, dark = C(160, 80, 255), C(40, 30, 60)
	Stations.gantry(g, t, violet)
	local back = k.st:group('Backstop')
	local h = 7.0
	Stations.wall(back, t, C(30, 20, 44), M.SmoothPlastic, h)
	Stations.wallLines(back, h, violet, M.Neon, 0.12)
	local z = Stations.BACK_Z
	Stations.bullseye(back, CFrame.new(0, Y + 5.8, z - 0.02), 2.5, { violet, C(20, 14, 30), violet, C(20, 14, 30), violet }, { M.Neon, M.SmoothPlastic, M.Neon, M.SmoothPlastic, M.Neon })
	-- Main: a round dark plate with neon rings, hanging from the beam.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	Stations.disc(sw, 'PlateRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.04), 1.72, 0.2, violet, M.Neon)
	Stations.disc(sw, 'Plate', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.5, 0.26, dark, M.Metal)
	Stations.disc(sw, 'PlateRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 0.95, 0.3, violet, M.Neon)
	Stations.disc(sw, 'PlateInner', CFrame.new(0, cy, Stations.GANTRY_Z - 0.1), 0.8, 0.34, dark, M.Metal)
	Stations.disc(sw, 'PlateSpot', CFrame.new(0, cy, Stations.GANTRY_Z - 0.14), 0.32, 0.38, violet, M.Neon)
	Stations.chains(sw, 0, cy + 1.62, 0.65)
	-- Two square plates on chunky posts at the sides.
	for _, p in { { -2.6, 4.6, 2.6, 1.3 }, { 2.6, 4.1, 3.2, 1.2 } } do
		g:box('PlatePost', V(p[1] - 0.2, Y, p[2] + 0.12), V(p[1] + 0.2, Y + p[3], p[2] + 0.52), t.frame)
		local s2 = Stations.target(k, CFrame.new(p[1], Y + p[3], p[2] + 0.1), V(p[1], Y + p[3] + p[4] / 2, p[2]), 'Tip', false, 'Ding')
		Stations.plate(s2, CFrame.new(p[1], Y + p[3] + p[4] / 2, p[2]), p[4], dark, violet, M.Neon, violet)
	end
end

-- 6 Frost: an ice bullseye on a tall ice pillar (main), small ice blocks on ice pedestals, a four-course ice
-- wall with a snow top, icicles and a deep-blue neon line, and a deep-blue gantry with deep-blue neon on navy
-- strips: pale ice in a dark frame, as rich as shadow's neon on black.
function Stations.Lanes.frost(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local snow, iceA, iceB, deep = C(248, 252, 255), C(150, 225, 250), C(120, 205, 240), C(25, 120, 235)
	local glow, navy = C(40, 150, 255), C(12, 40, 100) -- deep-blue neon on navy strips (reads without bloom)
	Stations.gantry(g, t, glow, { width = 0.22, backing = navy })
	g:box('BeamSnow', V(-4.4, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.45), V(4.4, Stations.GANTRY_Y + 1.0, Stations.GANTRY_Z + 0.45), snow)
	for i = 0, 6 do
		local len = 0.5 + ((i * 37) % 5) * 0.12
		Stations.icicle(g, V(-3.1 + i * 1.05, Stations.GANTRY_Y - 0.06, Stations.GANTRY_Z - 0.2), len, 0.3)
	end
	-- Wall: four courses of ice blocks, offset like bricks, a snow top with drifts and icicles along its front.
	local back = k.st:group('Backstop')
	local z0, z1 = Stations.BACK_Z, Stations.HALF_Z - 0.1
	for row = 0, 3 do
		local y0, y1 = row == 0 and 0 or Y + row * 1.9, Y + (row + 1) * 1.9
		local xs = row % 2 == 0 and { -4.3, -2.2, -0.1, 2.0, 4.3 } or { -4.3, -3.2, -1.1, 1.0, 3.1, 4.3 }
		for i = 1, #xs - 1 do
			local p = back:box('IceWall', V(xs[i] + 0.03, y0, z0 + ((i + row) % 2) * 0.08), V(xs[i + 1] - 0.03, y1 - 0.04, z1), (i + row) % 2 == 0 and iceA or iceB)
			p.Reflectance = 0.15
		end
	end
	local top = Y + 7.6
	studs(back:box('SnowTop', V(-4.4, top, z0 - 0.1), V(4.4, top + 0.4, z1), snow))
	decor(back:box('SnowGlowBack', V(-4.4, top - 0.34, z0 - 0.18), V(4.4, top, z0 - 0.06), navy)).CastShadow = false
	decor(back:box('SnowGlow', V(-4.4, top - 0.28, z0 - 0.22), V(4.4, top - 0.06, z0 - 0.1), glow, M.Neon)).CastShadow = false
	for _, d in { { -2.6, 1.6, 0.5 }, { 0.6, 2.0, 0.7 }, { 2.9, 1.2, 0.4 } } do back:box('SnowDrift', V(d[1] - d[2] / 2, top + 0.4, z0 + 0.1), V(d[1] + d[2] / 2, top + 0.4 + d[3], z1 - 0.1), snow) end
	for i = 0, 9 do
		local len = 0.45 + ((i * 53) % 7) * 0.1
		Stations.icicle(back, V(-3.9 + i * 0.86, top - 0.1, z0 - 0.12), len, 0.34)
	end
	-- Two deep-blue neon snowflakes high on the wall either side of the main target (six arms with twin branches;
	-- clear of the bullseye, the gantry posts and the icicles), and neon lines up the wall's edges: the lane's dark
	-- graphic, like shadow's rings.
	for _, sx0 in { -1, 1 } do
		local fc = CFrame.new(sx0 * 2.66, Y + 6.5, z0 - 0.08) * CFrame.Angles(0, 0, math.rad(15))
		for a = 0, 2 do
			local arm = fc * CFrame.Angles(0, 0, a * math.pi / 3)
			decor(back:part('Snowflake', V(1.6, 0.3, 0.1), arm, glow, M.Neon)).CastShadow = false
			for _, sx in { -1, 1 } do
				for _, sb in { (a % 2 == 0) and 1 or -1 } do
					local at = arm * CFrame.new(sx * 0.48, 0, -0.01) * CFrame.Angles(0, 0, sx * sb * math.pi / 3) * CFrame.new(sx * 0.17, 0, 0)
					decor(back:part('Snowflake', V(0.36, 0.2, 0.1), at, glow, M.Neon)).CastShadow = false
				end
			end
		end
	end
	for _, sx in { -1, 1 } do
		decor(back:box('WallNeon', V(sx * 4.3 - 0.11, 0.6, z0 - 0.07), V(sx * 4.3 + 0.11, top - 0.34, z0 + 0.04), glow, M.Neon)).CastShadow = false
	end
	-- Main: an ice bullseye (deep blue rings) on a tall ice pillar.
	local mz = 6.0
	local pillar = g:box('IcePillar', V(-0.55, Y, mz - 0.3), V(0.55, Y + 4.1, mz + 0.8), iceA)
	pillar.Reflectance = 0.15
	g:box('IcePillarFoot', V(-0.8, Y, mz - 0.55), V(0.8, Y + 0.4, mz + 1.05), t.frame)
	g:part('IceShine', V(0.12, 2.4, 0.04), CFrame.new(-0.2, Y + 2.2, mz - 0.32) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255)).Transparency = 0.25
	local sw = Stations.target(k, CFrame.new(0, Y + 4.1, mz), V(0, Y + 5.8, mz), 'Tip', true, 'Ice')
	Stations.disc(sw, 'IceBoard', CFrame.new(0, Y + 5.8, mz + 0.12), 1.82, 0.18, C(90, 200, 245))
	Stations.bullseye(sw, CFrame.new(0, Y + 5.8, mz + 0.03), 1.72, { snow, deep, snow, deep, C(255, 255, 255) })
	-- Ice blocks on pedestals at the sides.
	for _, b in { { -2.6, 4.5, 2.6, 0.95 }, { 2.6, 5.0, 3.2, 0.9 } } do
		-- (Deep-blue pedestals under pale ice: the field's dark-light structure.)
		g:box('IcePedestal', V(b[1] - 0.55, Y, b[2] - 0.55), V(b[1] + 0.55, Y + b[3], b[2] + 0.55), t.frame)
		g:box('IcePedestalCap', V(b[1] - 0.62, Y + b[3] - 0.14, b[2] - 0.62), V(b[1] + 0.62, Y + b[3], b[2] + 0.62), snow)
		local cy = Y + b[3] + b[4] / 2
		-- (Hinged on the block's back edge and never rocking forward, so it tips off its cap, never into it.)
		local s2, block = Stations.target(k, CFrame.new(b[1], Y + b[3], b[2] + 0.6), V(b[1], cy, b[2]), 'Tip', false, 'Ice')
		block:SetAttribute('TipMin', 0)
		Stations.ice(s2, 'IceBlock', CFrame.new(b[1], cy, b[2]) * CFrame.Angles(0, math.rad(b[1] > 0 and 20 or -15), 0), b[4])
	end
end

-- 7 Toxic: a big toxic barrel with a target face on a pallet and two crates (main), green bottles on a shelf
-- under a hanging hazard sign, a second barrel, glowing puddles, a dark container wall with ribs, a hazard
-- stripe and a neon drip sign.
function Stations.Lanes.toxic(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local neon, dark, navy = C(60, 255, 90), C(20, 64, 58), C(24, 30, 70)
	Stations.gantry(g, t, neon, { width = 0.22, backing = C(8, 56, 28) })
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.0
	Stations.wall(back, t, dark, M.SmoothPlastic, h)
	for i = 0, 7 do
		local x = -3.7 + i * 1.06
		back:box('Rib', V(x - 0.14, 0.6, z - 0.12), V(x + 0.14, Y + h - 0.75, z + 0.1), dark:Lerp(C(255, 255, 255), 0.12))
	end
	-- Hazard band: yellow with black slanted bars.
	back:box('HazardBand', V(-4.3, Y + h - 0.7, z - 0.16), V(4.3, Y + h - 0.1, z + 0.1), C(255, 214, 30))
	for i = 0, 7 do
		decor(back:part('HazardBar', V(0.35, 0.82, 0.05), CFrame.new(-3.75 + i * 1.07, Y + h - 0.4, z - 0.18) * CFrame.Angles(0, 0, math.rad(40)), C(30, 30, 36)))
	end
	-- The drip sign (a neon drop on a dark plate), off to the right of the barrel stack.
	local sx, sy = 2.45, Y + 4.4
	Stations.disc(back, 'SignPlate', CFrame.new(sx, sy, z - 0.2), 1.25, 0.14, navy)
	Stations.disc(back, 'Drip', CFrame.new(sx, sy - 0.25, z - 0.32), 0.75, 0.14, neon, M.Neon)
	decor(back:part('DripTip', V(1.06, 1.06, 0.14), CFrame.new(sx, sy + 0.18, z - 0.32) * CFrame.Angles(0, 0, math.pi / 4), neon, M.Neon))
	Stations.disc(back, 'DripShine', CFrame.new(sx - 0.24, sy - 0.05, z - 0.42), 0.18, 0.08, C(220, 255, 220), M.Neon)
	-- Hazard diamond hanging from the beam over the bottle shelf (decor).
	local hx = -2.6
	for _, ox in { -0.5, 0.5 } do g:box('SignChain', V(hx + ox - 0.08, Stations.GANTRY_Y - 0.8, Stations.GANTRY_Z - 0.08), V(hx + ox + 0.08, Stations.GANTRY_Y, Stations.GANTRY_Z + 0.08), C(52, 54, 66)) end
	g:part('HazardSign', V(1.25, 1.25, 0.12), CFrame.new(hx, Stations.GANTRY_Y - 1.5, Stations.GANTRY_Z) * CFrame.Angles(0, 0, math.pi / 4), C(255, 214, 30))
	g:part('HazardSignMark', V(0.22, 0.6, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.4, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	g:part('HazardSignDot', V(0.22, 0.22, 0.06), CFrame.new(hx, Stations.GANTRY_Y - 1.9, Stations.GANTRY_Z - 0.08), C(30, 30, 36))
	-- Main: a big toxic barrel with a target face, on a pallet and two stamped crates.
	local mz = 6.0
	g:box('Pallet', V(-1.05, Y, mz - 1.05), V(1.05, Y + 0.35, mz + 1.05), C(150, 105, 60))
	local crate = g:box('Crate', V(-0.95, Y + 0.35, mz - 0.95), V(0.95, Y + 2.35, mz + 0.95), navy)
	Stations.stamp(crate, Stations.SIDES, 1.9, 2.0, C(5, 150, 35))
	local crate2 = g:part('Crate', V(1.6, 1.8, 1.6), CFrame.new(0.05, Y + 3.25, mz) * CFrame.Angles(0, math.rad(8), 0), dark)
	Stations.stamp(crate2, Stations.SIDES, 1.6, 1.8, C(5, 150, 35))
	local base = Y + 4.15
	local sw, drum = Stations.target(k, CFrame.new(0, base, mz + 0.95), V(0, base + 1.25, mz - 1.0), 'Tip', true, 'Barrel')
	drum:SetAttribute('TipMin', 0) -- (rocks back on its back edge, never into the crate)
	Stations.drum(sw, V(0, base, mz), 0.95, 2.5, neon, navy, C(10, 90, 30), M.Neon)
	Stations.bullseye(sw, CFrame.new(0, base + 1.25, mz - 1.02), 0.75, { C(255, 255, 255), navy, neon }, { M.SmoothPlastic, M.SmoothPlastic, M.Neon })
	-- Green bottles on a little shelf (they shatter), and a barrel on the floor.
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), navy) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), navy)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', neon)
		Stations.bottle(s2, b, 0.95, C(60, 220, 90), { label = navy, stripe = neon, material = M.Neon })
	end
	local s3, floorDrum = Stations.target(k, CFrame.new(2.7, Y, 5.26), V(2.7, Y + 0.95, 4.6), 'Tip', false, 'Barrel')
	floorDrum:SetAttribute('TipMin', 0)
	Stations.drum(s3, V(2.7, Y, 4.6), 0.66, 1.9, neon, navy, C(10, 90, 30), M.Neon)
	-- Glowing puddles on the dark mat.
	for _, p in { { -1.4, 2.0, 1.1 }, { 1.9, 1.1, 0.75 }, { -0.4, 7.6, 0.8 } } do
		decor(g:part('Puddle', V(0.05, 2 * p[3], 2 * p[3] * 1.3), CFrame.new(p[1], Y + 0.025, p[2]) * CFrame.Angles(0, 0, math.pi / 2), neon, M.Neon, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- 8 Gold, the top lane: a big gold gong with a crimson ring (main) in a gold ring on a velvet-faced gold backstop with cream trim
-- and gold rays (the gold pops off the dark velvet the way toxic's neon pops off its container), white-hot neon
-- on crimson strips up the gantry, a turning crown on the beam, gold bottles on a gold shelf, a gold plate on
-- a post, lemon nuggets on the sand and a velvet band on the bench (a VIP counter).
function Stations.Lanes.gold(k)
	local t, Y, g = k.t, Stations.MAT_Y, k.gear
	local gold, deep, white, ruby, cream = C(255, 222, 40), C(245, 190, 0), C(255, 252, 235), C(235, 30, 70), C(255, 248, 220)
	local velvet, rays = C(150, 15, 40), C(255, 200, 40)
	Stations.gantry(g, t, C(255, 255, 235), { width = 0.22, backing = velvet })
	g:box('CrownPlinth', V(-0.5, Stations.GANTRY_Y + 0.8, Stations.GANTRY_Z - 0.4), V(0.5, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z + 0.4), velvet)
	Stations.crown(g, CFrame.new(0, Stations.GANTRY_Y + 0.86, Stations.GANTRY_Z))
	-- Wall: a gold body (its sides, back and top read gold from the aisle) with a crimson velvet field framed in
	-- gold on the shooter's face, cream trim, gold rays behind a gold ring round a darker velvet disc, two gems.
	local back = k.st:group('Backstop')
	local z = Stations.BACK_Z
	local h = 7.4
	Stations.wall(back, t, C(235, 170, 0), M.SmoothPlastic, h)
	local groove = C(112, 8, 30)
	for _, f in { { 4.05, 0.6, Y + h - 0.25, 0.04 }, { 2.65, Y + h + 0.12, Y + h + 0.62, -0.11 }, { 1.25, Y + h + 0.92, Y + h + 1.22, -0.26 } } do
		local face = back:box('Velvet', V(-f[1], f[2], z - f[4]), V(f[1], f[3], z - f[4] + 0.1), velvet, M.Fabric)
		Stations.panelX(back, face, CFrame.new(0, (f[2] + f[3]) / 2, z - f[4]), 2 * f[1], f[3] - f[2], f[1] > 3 and 5 or 4, groove)
	end
	Stations.wallLines(back, h, cream, M.SmoothPlastic, 0.3)
	Stations.starburst(back, CFrame.new(0, Y + 5.8, z - 0.1), 4.2, 0.12, rays)
	local ring = Stations.disc(back, 'VelvetRim', CFrame.new(0, Y + 5.8, z - 0.22), 2.62, 0.14, rays)
	ring.Reflectance = 0.2
	Stations.disc(back, 'Velvet', CFrame.new(0, Y + 5.8, z - 0.28), 2.4, 0.14, C(105, 8, 30), M.Fabric)
	for _, s in { { -3.45, 1.2, C(60, 140, 255) }, { 3.45, 1.2, C(60, 220, 120) } } do
		back:part('Gem', V(0.42, 0.42, 0.25), CFrame.new(s[1], Y + s[2], z - 0.08) * CFrame.Angles(0, 0, math.pi / 4), s[3], M.Glass)
	end
	-- Main: the gong.
	local cy = 6.2
	local sw = Stations.target(k, CFrame.new(0, Stations.GANTRY_Y, Stations.GANTRY_Z), V(0, cy, Stations.GANTRY_Z), 'Swing', true, 'Ding')
	-- (A little reflectance on the gold rim: a metal glint in Studio light; the crimson ring ties it to the velvet.)
	Stations.disc(sw, 'GongRim', CFrame.new(0, cy, Stations.GANTRY_Z + 0.03), 2.0, 0.22, deep).Reflectance = 0.2
	Stations.disc(sw, 'Gong', CFrame.new(0, cy, Stations.GANTRY_Z - 0.02), 1.75, 0.28, gold)
	Stations.disc(sw, 'GongRing', CFrame.new(0, cy, Stations.GANTRY_Z - 0.06), 1.08, 0.32, velvet)
	Stations.disc(sw, 'GongBoss', CFrame.new(0, cy, Stations.GANTRY_Z - 0.1), 0.78, 0.36, gold)
	sw:part('GongRuby', V(0.52, 0.52, 0.3), CFrame.new(0, cy, Stations.GANTRY_Z - 0.3) * CFrame.Angles(0, 0, math.pi / 4), ruby, M.Glass)
	Stations.chains(sw, 0, cy + 1.9, 0.8)
	-- Gold bottles on a gold shelf (left) and a gold plate on a post (right).
	local shelf = Y + 3.0
	for _, ox in { -1, 1 } do g:box('ShelfLeg', V(-2.6 + ox * 0.85 - 0.18, Y, 4.5 - 0.18), V(-2.6 + ox * 0.85 + 0.18, shelf, 4.5 + 0.18), deep) end
	g:box('Shelf', V(-3.7, shelf - 0.25, 4.1), V(-1.5, shelf, 4.9), deep)
	for _, x in { -3.1, -2.1 } do
		local b = V(x, shelf, 4.5)
		local s2 = Stations.target(k, CFrame.new(b + V(0, 0, 0.2)), b + V(0, 0.7, 0), 'Shatter', false, 'Glass', gold)
		Stations.bottle(s2, b, 0.95, gold, { label = white, stripe = ruby, cap = ruby })
	end
	g:box('PlatePost', V(2.4, Y, 5.15), V(2.8, Y + 3.0, 5.55), deep)
	local s3 = Stations.target(k, CFrame.new(2.6, Y + 3.0, 5.15), V(2.6, Y + 3.65, 5.05), 'Tip', false, 'Ding')
	Stations.plate(s3, CFrame.new(2.6, Y + 3.65, 5.05), 1.3, gold, deep, M.SmoothPlastic, white)
	-- An amber rug with a velvet border over the target field (so the lemon nuggets read), and the nuggets on it.
	local rug = studs(g:box('Rug', V(-3.3, Y, 0.4), V(3.3, Y + 0.04, 8.2), C(210, 140, 0)))
	rug.CanCollide = false
	for _, b in { { V(-3.3, Y, 0.4), V(3.3, Y + 0.05, 0.6) }, { V(-3.3, Y, 8.0), V(3.3, Y + 0.05, 8.2) }, { V(-3.3, Y, 0.4), V(-3.1, Y + 0.05, 8.2) }, { V(3.1, Y, 0.4), V(3.3, Y + 0.05, 8.2) } } do
		decor(g:box('RugBorder', b[1], b[2], velvet, M.Fabric)).CastShadow = false
	end
	local d = g:group('Nuggets')
	Stations.nugget(d, -1.9, 1.6, 1.0, 0.4)
	Stations.nugget(d, 1.3, 2.9, 0.9, 1.3)
	Stations.nugget(d, -0.9, 7.7, 0.85, 2.2)
	Stations.nugget(d, 2.9, 7.4, 0.8, 0.9)
end

-- Floating labels over the targets, the video's three rows: Unlocked/Locked small on top, the rebirths the lane needs
-- in a dark chip (the rebirth icon and the number, "FREE" for BAY 1), and the big "xN Power" in the tier's colour.
-- The client rewrites Detail as you rebirth, and Cost and Power from the config (Lobby.client).
function Stations.labels(st, s, t, at)
	local sign = ghost(st:part('Sign', V(0.2, 0.2, 0.2), CFrame.new(at), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'Label'
	g.Size = UDim2.fromScale(12, 7.2) -- (a lane pitch wide: the row's labels read from the hall's spine)
	g.MaxDistance = 100 -- (LABELS: HoodClient/LabelFade fades it out from 45 to 75 studs, the next lane to open from 65 to
	-- 105, and sets MaxDistance to the band's end plus a margin itself; 100 is the plain lane's)
	g.LightInfluence = 0
	g.Parent = sign
	local ink = C(15, 15, 25)
	local function text(name, value, color, x, y, w, h, stroke)
		local l = Instance.new('TextLabel')
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		l.Font = FONT.title
		l.Text = value
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 1
		local u = Instance.new('UIStroke')
		u.Color, u.Thickness, u.LineJoinMode = ink, stroke, Enum.LineJoinMode.Round
		u.Parent = l
		l.Parent = g
		return l
	end
	-- Chip: a see-through dark pill with a black outline and the rebirths in white (FREE for the starter).
	local chip = Instance.new('Frame')
	chip.Name = 'Chip'
	chip.Position, chip.Size = UDim2.fromScale(0.25, 0.27), UDim2.fromScale(0.5, 0.27)
	chip.BackgroundColor3, chip.BackgroundTransparency = C(20, 22, 34), 0.55
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = chip
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = C(0, 0, 0), 2
	edge.Parent = chip
	chip.Parent = g
	local need = s.Rebirths or 0
	text('Cost', need == 0 and 'FREE' or ('🔄 ' .. need), P.white, 0.27, 0.305, 0.46, 0.2, 2)
	local open = need == 0
	text('Detail', open and 'Unlocked' or 'Locked', open and C(40, 235, 90) or C(240, 40, 60), 0.15, 0, 0.7, 0.25, 3)
	text('Power', 'x' .. s.Multiplier .. ' Power', t.text, 0, 0.56, 1, 0.44, 3)
	return sign
end

-- Build station `stationId` (a Skins.Stations id; not Ring) in ctx (see the frame above). Returns the model.
function Stations.build(ctx, stationId, opts)
	opts = opts or {}
	local skins = SKINS or require(ReplicatedStorage.Shared.Config.Skins)
	local s = assert(skins.StationById[stationId], 'unknown station ' .. tostring(stationId))
	local tier = opts.tier
	if not tier then
		for i, row in skins.Stations do if row.Id == stationId then tier = i end end
	end
	tier = math.clamp(tier, 1, #Stations.Themes)
	local t = Stations.Themes[tier]
	local vfxModule = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('HoodVFX')
	local okVfx, VFX = pcall(require, vfxModule)
	if not okVfx then VFX = nil end
	Stations.StampId = VFX and VFX.Textures and VFX.Textures.stamp or ''
	local st, model = ctx:group('Training_' .. stationId)
	model:SetAttribute('Theme', t.name)
	model:SetAttribute('Silhouette', true) -- (Lobby.client blacks the whole lane out while it is locked)

	-- Base: the rim, the flat inset mat, a thin neon line inside the rim on shadow.
	Stations.rim(st, t)
	local Y, MX, MZ = Stations.MAT_Y, Stations.HALF_X - 1, Stations.HALF_Z - 1
	local mat = st:box('Mat', V(-MX + 0.45, 0, -MZ + 0.45), V(MX - 0.45, Y, MZ - 0.45), t.mat, t.matMat or M.Plastic)
	if mat.Material == M.Plastic then studs(mat) end
	-- (a border ring a shade darker round the mat, flush with it: two tones on the lane's biggest surface)
	local ring = t.mat:Lerp(C(0, 0, 0), 0.2)
	for _, b in { { V(-MX, 0, -MZ), V(MX, Y, -MZ + 0.45) }, { V(-MX, 0, MZ - 0.45), V(MX, Y, MZ) },
		{ V(-MX, 0, -MZ + 0.45), V(-MX + 0.45, Y, MZ - 0.45) }, { V(MX - 0.45, 0, -MZ + 0.45), V(MX, Y, MZ - 0.45) } } do
		local p = st:box('MatBorder', b[1], b[2], ring, t.matMat or M.Plastic)
		if p.Material == M.Plastic then studs(p) end
	end
	if t.edge then
		for _, b in { { V(-MX, Y, -MZ), V(MX, Y + 0.14, -MZ + 0.08) }, { V(-MX, Y, MZ - 0.08), V(MX, Y + 0.14, MZ) }, { V(-MX, Y, -MZ), V(-MX + 0.08, Y + 0.14, MZ) }, { V(MX - 0.08, Y, -MZ), V(MX, Y + 0.14, MZ) } } do
			decor(st:box('EdgeGlow', b[1], b[2], t.edge, M.Neon)).CastShadow = false
		end
	end
	-- Where the player stands to train: the shooter's box, from the aisle edge to just short of the bench.
	local zone = st:box('TrainingZone', V(-MX, Y - 0.06, -Stations.HALF_Z), V(MX, Y, Stations.BOX_Z), P.white)
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
	Stations.bench(st, t, tier)
	Stations.walls(st, t)

	-- Equipment: the stands and gantry (Gear) and the knockable targets (Targets).
	local eq = st:group('Equipment')
	local gear = eq:group('Gear')
	local k = { st = st, gear = gear, targets = eq:group('Targets'), list = {}, t = t, tier = tier, burners = {} }
	local lane = Stations.Lanes[t.name] or Stations.Lanes.stone
	lane(k)
	-- Small things on the gear and every target never block players or rays.
	for _, p in eq.parent:GetDescendants() do
		if p:IsA('BasePart') and (p:FindFirstAncestor('Targets') or p.Size.Magnitude < 1.6) then decor(p) end
	end

	Stations.labels(st, s, t, Stations.LABEL + V(0, (t.labelLift or 0) + (opts.labelLift or 0), 0))
	model:SetAttribute('Tier', tier)
	model:SetAttribute('TextColor', t.text) -- (the HUD hint shows the range's multiplier in it)
	model:SetAttribute('HitPoint', st:world(CFrame.new(k.mainAim or V(0, 4.2, 6))).Position)
	model:SetAttribute('HitColor', t.glow)
	if opts.vfx ~= false and VFX then
		-- The theme's effects fill the target field (not the shooter's box), from the bench to the backstop.
		local z0, z1 = Stations.FIELD_Z0, Stations.FIELD_Z1
		local field = ghost(st:box('Field', V(-MX, Y - 0.05, z0), V(MX, Y, z1), P.white))
		field.CanCollide = false
		local mainPart = k.main and k.main:FindFirstChild('Swing') and k.main.Swing:FindFirstChildWhichIsA('BasePart', true)
		if VFX.theme then
			VFX.theme(field, t.name, V(2 * MX, 10, z1 - z0), { parent = model, tier = tier, color = t.glow, bag = mainPart, burners = k.burners })
		else
			VFX.station(field, tier, t.glow, V(2 * MX, 10, z1 - z0), { parent = model })
		end
	end
	return model
end
---------------------------------------------------------------------------------------------- armory
-- The ARMORY, after the user's item-shop reference (brief/ref_armory.png), run like the soldier game's gun stand
-- (brief/video1/notes.md section 4): the gun ladder as big guns floating in profile over big glowing hexagonal pads,
-- two rows stepping up toward the back. Guns 1-5 stand on the front deck (a light studded plinth with a dark studded
-- step along its front), guns 6-10 on a raised studded terrace behind it, reached by a stair at each end; a back wall
-- with a raised centre and corner posts closes it. Built like a shop wall: every gun has a framed display bay behind
-- it (a light studded pegboard panel set back in a frame, a roller-shutter box over it, a sill), bays parted by
-- pilasters with bases and caps; finished edges everywhere (light nosings and copings on top edges, dark kick bands at
-- the foot, a dark band under every cap). A till and a stack of gun cases stand on the terrace's ends.
-- Each pad is layered: a dark plinth, a pale body with a state-coloured line round it, a light bevelled lip, and the
-- face (a dark rim, the glowing state colour, a light core); a plate on its front says LOCKED / BUY / OWNED /
-- EQUIPPED. Step onto the pad's front half for the Buy / Equip prompt. Over each gun a three-line nameplate: the
-- name, a big "xN Power", the price (red locked, yellow BUY) or the state (OWNED blue, EQUIPPED green).
-- Neon only on the pad faces; saturated colour only on the pads, the guns and their nameplates.
-- State colours (GunRules.Colors; Armory.client repaints): pink locked, blue owned, green equipped.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun with attributes GunId, Tier,
-- Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part on the pad's front half: prompt anchor and buy-distance point
--   StateTop           parts in the state colour (the pad face and its side line)
--   StateGlow          the face's light core, with the pad's PointLight under it
--   StateShade         the face's dark rim (the state's dark tone)
--   StateMat           the slot's studded mat under the pad (the state's soft tone)
--   StateStrip         the front plate, with SurfaceGui > TextLabel State; StateHaze (ParticleEmitter)
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Bob) with the gun inside, horizontal, in profile to the hall
-- The Armory model is tagged HoodArmory; each slot streams Atomic.
-- Local frame: origin at the centre of the front step's foot on the hall floor, front faces -Z (players stand
-- at -Z looking +Z), footprint x -39.2..39.2, z 0..24.2 (Armory.HalfWidth, Armory.Depth) plus the back block to
-- opts.backTo, at most 15.2 tall (nameplates float to about 19).
-- Sized after the user's first playtest ("a bit smaller, it's too massive"): about 70% of the first east stand
-- (110 long, 31.2 deep, 20.6 tall) in length, depth and height, with the same parts, tones and labels.
local Armory = {}

Armory.HalfWidth, Armory.Depth = 39.2, 24.2
Armory.Floor = 1.6 -- front deck top (one 0.8 step up from the hall floor)
Armory.Step = 9.0 -- back terrace top: high enough that the front row's nameplates sit on its wall, under the back row
Armory.TerraceZ = 13.2 -- where the terrace's front wall stands
Armory.Rows = { { z = 7.6, y = 1.6, label = 0.7, scale = 1 }, { z = 18.8, y = 9.0, label = 0.9, scale = 1.1 } }
Armory.Spacing = 13.5 -- the pitch along the row
Armory.Radius = 3.4 -- pad apothem (centre to a flat side); flats face -Z
Armory.PadHeight = 0.9
Armory.MaxLength = 6.0
Armory.GunK = 3.2 -- display length = GunK x sqrt(natural length), +3% a tier, up to MaxLength
Armory.Tilt = 17 -- degrees the muzzle points up
Armory.DisplayH = 4.2 -- the tallest a tilted gun may stand (taller ones are scaled down; nameplates sit over it)
Armory.Bob, Armory.BobPeriod = 0.3, 2.6
Armory.StairW = 4.2 -- the stairs at each end, x +-(35..39.2)
Armory.StairRun = 1.15 -- tread depth (the stair fits the deck's depth)
Armory.BackWall = 5.0 -- the terrace's back wall, above the terrace top
Armory.BayW = 10 -- display bay width (pilasters stand between bays)
Armory.MatW = 9.2 -- the slot's mat along the row
Armory.MatZ = { -5.0, 4.0 } -- the mat's front and back edge from the pad centre
Armory.Label = 0.88 -- nameplate size (1 = the first stand's 3.8-stud plates)
-- Tones, two or three per surface: a lit body, a darker band at the foot and under every cap, a light trim on
-- every top edge. The stand stands where the hall picture has its stepped terrace, so it takes that terrace's
-- lavender greys (tread 186,189,228, riser 146,150,192, dark riser 104,110,156, nosing 228,232,250).
Armory.Tone = {
	deck = C(190, 193, 228), tread = C(196, 199, 232), trim = C(228, 232, 250), face = C(124, 130, 174),
	kick = C(100, 106, 150), riser = C(146, 150, 192), wall = C(150, 154, 196), band = C(112, 116, 160),
	pilaster = C(196, 200, 232), pad = C(214, 216, 234), padLip = C(238, 240, 250), plinth = C(104, 110, 156),
	frame = C(214, 218, 240), panel = C(184, 188, 222), bolt = C(150, 154, 184),
	case = C(58, 62, 80), caseRim = C(132, 136, 156), metal = C(176, 180, 196), crate = C(70, 104, 160),
	matRim = C(240, 242, 252),
}

-- Optional modules made by other builders (Shared.HoodVFX, Shared.Models.GunModels / IconModels): nil when
-- they are not there yet or fail to load.
function Armory.optional(name)
	local shared = ReplicatedStorage:FindFirstChild('Shared')
	local models = shared and shared:FindFirstChild('Models')
	local m = shared and (shared:FindFirstChild(name) or (models and models:FindFirstChild(name)))
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end

-- The dark tone of a state (GunRules.Colors[state].Shade, or the plate colour darkened when an older GunRules has none).
function Armory.shade(look)
	return look.Shade or look.Strip:Lerp(C(0, 0, 0), 0.35)
end

-- Hexagonal plinth: three boxes turned 60 degrees apart (flat sides face +-Z), each width 2r*tan(30).
function Armory.hex(c, name, x, z, r, y0, y1, color, material)
	local w = 2 * r * math.tan(math.pi / 6)
	local parts = {}
	for k = 0, 2 do
		table.insert(parts, c:part(name, V(w, y1 - y0, 2 * r), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, k * math.pi / 3, 0), color, material))
	end
	return parts
end

-- A chamfer round a hexagon's top edge: six wedges, each sloping from the inner ring (y1, r - w) down to the
-- outer edge (y0, r), so the pad's rim reads bevelled and catches the light on one side.
function Armory.bevel(c, name, x, z, r, w, y0, y1, color)
	local side = 2 * r * math.tan(math.pi / 6)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local out = V(math.sin(a), 0, -math.cos(a))
		local mid = V(x, (y0 + y1) / 2, z) + out * (r - w / 2)
		-- (a wedge's low side is its -Z: face it outward)
		c:wedge(name, V(side, y1 - y0, w), CFrame.lookAt(mid, mid + out), color, M.SmoothPlastic)
	end
end

-- Box of a model's visible parts in `frame` space: lo, hi corners.
function Armory.extents(model, frame)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, y, z, a, b, cc, d, e, f, g, h, i = frame:ToObjectSpace(p.CFrame):GetComponents()
			local s = p.Size
			local hx = (math.abs(a) * s.X + math.abs(b) * s.Y + math.abs(cc) * s.Z) / 2
			local hy = (math.abs(d) * s.X + math.abs(e) * s.Y + math.abs(f) * s.Z) / 2
			local hz = (math.abs(g) * s.X + math.abs(h) * s.Y + math.abs(i) * s.Z) / 2
			lo = V(math.min(lo.X, x - hx), math.min(lo.Y, y - hy), math.min(lo.Z, z - hz))
			hi = V(math.max(hi.X, x + hx), math.max(hi.Y, y + hy), math.max(hi.Z, z + hz))
		end
	end
	if lo.X == math.huge then return V(-0.5, -0.5, -0.5), V(0.5, 0.5, 0.5) end
	return lo, hi
end

-- A model's pivot without relying on GetPivot (works the same in Studio and the preview harness).
function Armory.pivotOf(model)
	local pp = model.PrimaryPart
	if pp then return pp.CFrame * pp.PivotOffset end
	local ok, pivot = pcall(function() return model.WorldPivot end)
	return ok and pivot or CFrame.new()
end
-- Moves every part so the model's pivot lands on `target`.
function Armory.place(model, target)
	local delta = target * Armory.pivotOf(model):Inverse()
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end
	end
	if not model.PrimaryPart then model.WorldPivot = target end
end

-- Stand-in gun while GunModels is missing: a chunky blocky gun in the contract's frame (grip at the origin,
-- muzzle toward -Z, up +Y; a pistol is about 1.6 long). Longer guns get a stock; the colour runs down a stripe.
function Armory.placeholder(gun, scale)
	local s = scale or 1
	local model = Instance.new('Model')
	model.Name = gun.Id
	local long = ({ Shotgun = 3.4, Tommy = 3.2, AK = 3.4, Minigun = 3.8, Blaster = 2.8, Diamond = 4 })[gun.Id]
	local len = long or (gun.Id == 'Uzi' and 2 or gun.Id == 'Deagle' and 1.9 or 1.6)
	local dark, metal = C(62, 66, 78), C(150, 156, 168)
	local function add(name, size, cf, color, material, shape)
		local p = Instance.new('Part')
		p.Name = name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Size = size * s
		p.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		p.Color = color
		p.Material = material or M.SmoothPlastic
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end
	local front = -len + 0.35
	local grip = add('Grip', V(0.3, 0.75, 0.42), CFrame.new(0, -0.22, 0.12) * CFrame.Angles(math.rad(-14), 0, 0), long and C(132, 82, 48) or dark, long and M.Wood or M.SmoothPlastic)
	add('Body', V(0.34, 0.44, len), CFrame.new(0, 0.32, front / 2 + 0.3), dark)
	add('Stripe', V(0.36, 0.12, len * 0.7), CFrame.new(0, 0.38, front / 2 + 0.2), gun.Color, M.Neon)
	add('Barrel', V(0.34, 0.2, 0.2), CFrame.new(0, 0.3, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0), metal, M.Metal, Enum.PartType.Cylinder)
	add('Guard', V(0.12, 0.22, 0.36), CFrame.new(0, -0.02, -0.22), dark)
	add('Sight', V(0.1, 0.1, 0.16), CFrame.new(0, 0.58, front + 0.12), metal, M.Metal)
	if long then
		add('Stock', V(0.3, 0.5, 0.9), CFrame.new(0, 0.18, 0.8), C(132, 82, 48), M.Wood)
		add('Mag', V(0.26, 0.6, 0.3), CFrame.new(0, -0.12, front / 2 + 0.2), dark)
	end
	model.PrimaryPart = grip
	grip.PivotOffset = grip.CFrame:Inverse() -- the model's pivot is the origin, as GunModels promises
	return model
end

-- The display gun: GunModels.build when it exists (else the stand-in), scaled up to read across the hall over its
-- pad. Small guns are blown up more than big ones (display length ~ natural length^0.5), so a pistol is about 4
-- studs and the long guns about 6, and each tier gets 3% more on top, up to MaxLength (the item is the hero of its
-- pad, as in the reference, and reads from the spawn across the hall).
function Armory.gun(gun, shrink)
	local models = Armory.optional('GunModels')
	local function make(scale)
		if models and models.build then
			local ok, model = pcall(models.build, gun.Id, scale)
			if ok and model then return model end
		end
		return Armory.placeholder(gun, scale)
	end
	local model = make(1)
	local lo, hi = Armory.extents(model, Armory.pivotOf(model))
	local size = hi - lo
	local longest = math.max(size.X, size.Y, size.Z, 0.1)
	local length = math.min(Armory.MaxLength, Armory.GunK * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- Effects that grow with tier (`part` is a box round the gun, which sizes them): a soft light for the front row,
-- then for the back row HoodVFX.item when the VFX module is there, otherwise a light, sparkles, rising glow and
-- big star glints for the last two.
function Armory.effects(part, tier, color)
	if tier < 2 then return end -- the free pistol stays plain, like the basic tool in the reference
	-- The front row (tiers 2-5) gets only a soft light: like the reference, effects are for the better items.
	if tier < 6 then
		light(part, color, 0.5 + tier * 0.12, 7 + tier * 0.4)
		return
	end
	local vfx = Armory.optional('HoodVFX')
	if vfx and vfx.item then
		local ok, made = pcall(vfx.item, part, tier, color)
		if ok then
			-- A shop display keeps only the small effects: no halo, rays, arcs or glitter (they white out the terrace,
			-- worst with built-in textures), the rest capped at 2 studs and rising slowly so they stay under the
			-- nameplate.
			local kill = { ItemGlow = true, ItemRays = true, ItemArcs = true, ItemGlitter = true }
			for _, e in (type(made) == 'table' and made or {}) do
				if typeof(e) == 'Instance' and kill[e.Name] then
					e:Destroy()
				elseif typeof(e) == 'Instance' and e:IsA('ParticleEmitter') then
					pcall(function()
						local most = 0
						for _, kp in e.Size.Keypoints do most = math.max(most, kp.Value + kp.Envelope) end
						if most > 2 then
							local f, keys = 2 / most, {}
							for _, kp in e.Size.Keypoints do table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * f, kp.Envelope * f)) end
							e.Size = NumberSequence.new(keys)
						end
						if e.Name == 'ItemWisps' or e.Name == 'ItemFlames' or e.Name == 'ItemMotes' then
							e.Speed = NumberRange.new(e.Speed.Min * 0.5, e.Speed.Max * 0.5)
							e.Acceleration = e.Acceleration * 0.4
						end
					end)
				end
			end
			return
		end
	end
	light(part, color, 0.5 + tier * 0.12, 7 + tier * 0.4)
	local function emitter(name, texture, rate, life, speed, size, transparency)
		local e = Instance.new('ParticleEmitter')
		e.Name = name
		e.Texture = texture
		e.Rate = rate
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Speed = NumberRange.new(speed[1], speed[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = size
		e.Transparency = transparency
		e.Color = ColorSequence.new(color:Lerp(P.white, 0.35), color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = part
		return e
	end
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	if tier >= 3 then
		emitter('Sparkles', 'rbxasset://textures/particles/sparkles_main.dds', 2 + tier * 1.5, { 0.8, 1.5 }, { 0.4, 1.4 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 + tier * 0.03), NumberSequenceKeypoint.new(1, 0) }), fade)
	end
	if tier >= 6 then
		local glow = emitter('Glow', 'rbxasset://textures/particles/fire_main.dds', 3 + tier, { 0.9, 1.6 }, { 0.6, 1.4 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 + tier * 0.06), NumberSequenceKeypoint.new(1, 0.1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }))
		glow.EmissionDirection = Enum.NormalId.Top
		glow.SpreadAngle = Vector2.new(25, 25)
		glow.Acceleration = V(0, 1.5, 0)
	end
	if tier >= 9 then
		local star = emitter('Glints', 'rbxasset://textures/particles/sparkles_main.dds', 3, { 1.2, 2 }, { 0.2, 0.6 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) }),
			NumberSequence.new(0.1))
		star:SetAttribute('PreviewTexture', 'star')
	end
end

-- The nameplate over a gun: one floating-text system, three lines, read like the reference's nameplates and the
-- soldier game's stand:
--   Name        the gun's name in its colour
--   Multiplier  big: "xN Power" with the Power icon
--   Price       the price with the Cash icon, or the state: EQUIPPED (green), OWNED (blue), BUY + price (yellow,
--               a locked gun you can afford), the price in red while it is locked (Armory.client repaints it)
-- Icons come from IconModels.Images when uploaded, else a text glyph kept in the label's Glyph attribute. Readable
-- from 30 studs; HoodClient/LabelFade keeps it whole to 38 studs and fades it out by 62 (Shared/LabelFade, kind Gun),
-- so the near guns read and the far shelf doesn't clutter the hall. (It sets MaxDistance itself: 80 is a fallback.)
function Armory.label(c, pos, gun, state, colors)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	-- as wide as the name needs, so every name (even Diamond Cannon) fills its row's full height: one name size
	g.Size = UDim2.fromScale(math.max(8.2, 0.68 * #gun.Name) * Armory.Label, 3.8 * Armory.Label)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Parent = anchor
	local ink = C(24, 22, 40)
	local look = colors[state] or {}
	-- (a grey gun's name would fade on the pale hall: it gets a rust orange instead)
	local _, sat = gun.Color:ToHSV()
	local nameColor = sat < 0.25 and C(240, 150, 90) or gun.Color:Lerp(P.white, 0.1)
	line(g, 'Name', gun.Name, nameColor, FONT.loud, 0, 0.3, ink, 3)
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y, h)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.loud, y, h, ink, 3)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = name == 'Price' and 'PriceIcon' or 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.22, y)
			i.Size = UDim2.fromScale(0.14, h)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.37, y)
			t.Size = UDim2.fromScale(0.6, h)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local a = Instance.new('UIAspectRatioConstraint')
			a.Parent = i
			i.Parent = g
			t:SetAttribute('Glyph', '')
		else
			t.Text = glyph .. ' ' .. text
			t:SetAttribute('Glyph', glyph)
		end
		return t
	end
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier .. ' Power', P.white, 0.3, 0.4)
	local price = row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), look.Word or C(255, 228, 92), 0.72, 0.28)
	if state == 'Equipped' or state == 'Owned' then price.Text = string.upper(state) end
	return anchor
end

-- A display bay on a wall whose face is at z = zf (facing -Z), centred on x, from y0 to y1: a studded pegboard
-- panel in a light neutral grey (the dark guns stand out on it; saturated colour stays on the pads) set back inside
-- a light frame (two jambs, a roller-shutter box over it, a deeper sill), so every gun has its own backdrop.
function Armory.bay(c, x, zf, y0, y1)
	local T, w = Armory.Tone, Armory.BayW / 2
	studs(c:box('BayPanel', V(x - w + 0.4, y0 + 0.3, zf - 0.12), V(x + w - 0.4, y1 - 0.5, zf), T.panel, M.Plastic), true)
	c:box('BayPanelBand', V(x - w + 0.4, y0 + 0.3, zf - 0.16), V(x + w - 0.4, y0 + 0.9, zf - 0.12), T.band, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		c:box('BayJamb', V(x + sx * w, y0, zf - 0.5), V(x + sx * (w - 0.45), y1, zf), T.frame, M.SmoothPlastic)
	end
	c:box('BaySill', V(x - w - 0.15, y0 - 0.1, zf - 0.75), V(x + w + 0.15, y0 + 0.32, zf), T.trim, M.SmoothPlastic)
	-- a roller-shutter box over the bay, the shutter drawn a little way down (a corner-store touch): a light housing
	-- with a dark lip, the ribbed shutter under it (both a little shorter on a short bay, so the pegboard still shows)
	local bh = math.min(0.75, (y1 - y0) * 0.19)
	local sh = math.min(1.0, (y1 - y0) * 0.22)
	c:box('ShutterBox', V(x - w - 0.15, y1 - bh, zf - 1.0), V(x + w + 0.15, y1, zf), T.trim, M.SmoothPlastic)
	c:box('ShutterLip', V(x - w - 0.15, y1 - bh - 0.2, zf - 1.05), V(x + w + 0.15, y1 - bh, zf - 0.6), T.band, M.SmoothPlastic)
	c:box('Shutter', V(x - w + 0.45, y1 - bh - sh, zf - 0.4), V(x + w - 0.45, y1 - bh, zf - 0.25), T.riser, M.SmoothPlastic)
	for k = 1, 2 do
		c:box('ShutterRib', V(x - w + 0.45, y1 - bh - k * sh * 0.34, zf - 0.47), V(x + w - 0.45, y1 - bh + 0.06 - k * sh * 0.34, zf - 0.25), T.band, M.SmoothPlastic)
	end
end

-- A pilaster on a wall face at z = zf (facing -Z): a dark base, a light shaft, a light cap.
function Armory.pilaster(c, x, zf, y0, y1, w)
	local T = Armory.Tone
	w = w or 1.3
	c:box('Pilaster', V(x - w / 2, y0, zf - 0.45), V(x + w / 2, y1, zf), T.pilaster, M.SmoothPlastic)
	c:box('PilasterBase', V(x - w / 2 - 0.2, y0, zf - 0.7), V(x + w / 2 + 0.2, y0 + 0.7, zf), T.kick, M.SmoothPlastic)
	c:box('PilasterCap', V(x - w / 2 - 0.2, y1 - 0.45, zf - 0.7), V(x + w / 2 + 0.2, y1, zf), T.trim, M.SmoothPlastic)
end

-- One gun on its pad. (x, z) is the pad centre, y the deck it stands on, wall the z of the wall face behind it.
function Armory.slot(c, gun, x, z, y, colors, lift, scale, wall)
	local T = Armory.Tone
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local r, ph = Armory.Radius, Armory.PadHeight
	-- The slot's mat under the pad (the soldier game's coloured pad tile with its white rim, so the long stand reads as
	-- a row of slots from across the hall): a studded tile in the state's soft tone inside a raised light kerb.
	local mw, m0, m1 = Armory.MatW / 2, z + Armory.MatZ[1], z + Armory.MatZ[2]
	studs(s:box('StateMat', V(x - mw + 0.5, y, m0 + 0.5), V(x + mw - 0.5, y + 0.2, m1 - 0.5), look.Mat or look.Glow, M.Plastic))
	for _, e in { { V(x - mw, y, m0), V(x + mw, y + 0.3, m0 + 0.5) }, { V(x - mw, y, m1 - 0.5), V(x + mw, y + 0.3, m1) },
		{ V(x - mw, y, m0 + 0.5), V(x - mw + 0.5, y + 0.3, m1 - 0.5) }, { V(x + mw - 0.5, y, m0 + 0.5), V(x + mw, y + 0.3, m1 - 0.5) } } do
		s:box('MatRim', e[1], e[2], T.matRim, M.SmoothPlastic)
	end
	y += 0.2
	-- The pad, bottom up: a dark plinth, the pale body with a state-coloured line round it, a light lip bevelled at
	-- its edge, and the face: a dark rim, the glowing state colour, a light core carrying the pad's light. Neon only
	-- on the face.
	Armory.hex(s, 'PadPlinth', x, z, r + 0.3, y, y + 0.3, T.plinth, M.SmoothPlastic)
	Armory.hex(s, 'PadBase', x, z, r, y + 0.3, y + ph - 0.3, T.pad, M.SmoothPlastic)
	for _, p in Armory.hex(s, 'StateTop', x, z, r + 0.04, y + 0.42, y + 0.54, look.Top, M.SmoothPlastic) do decor(p).CastShadow = false end
	Armory.hex(s, 'PadLip', x, z, r - 0.55, y + ph - 0.3, y + ph, T.padLip, M.SmoothPlastic)
	Armory.bevel(s, 'PadBevel', x, z, r, 0.55, y + ph - 0.3, y + ph, T.padLip)
	local top = y + ph
	for _, p in Armory.hex(s, 'StateShade', x, z, r - 0.65, top, top + 0.04, Armory.shade(look), M.SmoothPlastic) do decor(p).CastShadow = false end
	for _, p in Armory.hex(s, 'StateTop', x, z, r - 0.85, top, top + 0.07, look.Top, M.Neon) do decor(p).CastShadow = false end
	local core = Armory.hex(s, 'StateGlow', x, z, r - 2.3, top, top + 0.09, look.Glow, M.Neon)
	for _, p in core do decor(p).CastShadow = false end
	-- the face's glow on the deck round the pad (Armory.client recolours it with the face)
	light(core[1], look.Top, 2, 9)
	top += 0.09
	-- Soft haze rising off the face in the state colour, the reference's faint light column over each pad (the client
	-- recolours it with the pad).
	local hazeSource = ghost(s:part('StateHazeSource', V(r * 1.3, 0.2, r * 1.3), CFrame.new(x, top + 0.1, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 2.4
	haze.Lifetime = NumberRange.new(1.4, 2)
	haze.Speed = NumberRange.new(1, 1.6)
	haze.SpreadAngle = Vector2.new(6, 6)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.1), NumberSequenceKeypoint.new(1, 2.9) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.86), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	-- The plate on the pad's front: a chunky block standing on the plinth, with a light cap and two bolts.
	local strip = s:box('StateStrip', V(x - 1.65, y + 0.3, z - r - 0.3), V(x + 1.65, y + ph - 0.12, z - r + 0.05), look.Strip, M.SmoothPlastic)
	s:box('PlateCap', V(x - 1.75, y + ph - 0.12, z - r - 0.36), V(x + 1.75, y + ph, z - r + 0.05), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		s:part('PlateBolt', V(0.08, 0.2, 0.2), CFrame.new(x + sx * 1.45, y + 0.6, z - r - 0.32) * CFrame.Angles(0, math.pi / 2, 0), T.bolt, M.Metal, Enum.PartType.Cylinder)
	end
	local sg = surface(strip, Enum.NormalId.Front, 50)
	sg.Name = 'StateGui'
	line(sg, 'State', string.upper(state), P.white, FONT.loud, 0.06, 0.88, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun floating over the pad in profile to the hall (muzzle to the viewer's right), tilted up a little,
	-- bobbing; never turning, so it is never seen end-on.
	local d, display = s:group('Display')
	local tilt = math.rad(Armory.Tilt)
	local function measure(m)
		local lo, hi = Armory.extents(m, Armory.pivotOf(m))
		return lo, hi, (hi.Y - lo.Y) * math.cos(tilt) + (hi.Z - lo.Z) * math.sin(tilt)
	end
	local k = scale or 1 -- the back row a size bigger, so it reads as big as the front row from the hall
	local g = Armory.gun(gun, k)
	local lo, hi, tall = measure(g)
	if tall > Armory.DisplayH * k then
		-- a deep gun (an Uzi's long magazine) stands too tall tilted: a size smaller, under the nameplates
		g:Destroy()
		g = Armory.gun(gun, k * Armory.DisplayH * k / tall)
		lo, hi, tall = measure(g)
	end
	local mid = (lo + hi) / 2
	local length = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
	local centre = V(x, top + 0.8 + tall / 2, z + 0.55)
	local pose = CFrame.new(centre) * CFrame.Angles(0, 0, -tilt) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:SetAttribute('Bob', Armory.Bob)
	display:SetAttribute('BobPeriod', Armory.BobPeriod)
	display:AddTag('HoodMotion')
	local fx = ghost(s:part('FxCore', V(length * 0.5, math.max(tall * 0.7, length * 0.25), length * 0.2), CFrame.new(centre), gun.Color))
	fx.CastShadow = false
	Armory.effects(fx, gun.Tier, gun.Color)
	-- (every label in a row at one height, over the tallest gun, like the reference's nameplates)
	Armory.label(s, V(x, y + ph + 0.8 + Armory.DisplayH * k + (lift or 0.8) + 0.65, z), gun, state, colors)
	-- The display bay on the wall behind the gun: the front row's on the terrace wall (under its nameplate, which
	-- sits on the wall's studded band), the back row's on the back wall.
	if wall then
		local front = y < Armory.Step - 1
		Armory.bay(s, x, wall, y + 0.75, front and Armory.Step - 1.3 or y + Armory.BackWall - 1.1)
	end
	-- Where the prompt sits and the server measures buying distance from: on the pad's front half, so stepping onto
	-- the pad (in front of the floating gun) brings up Buy / Equip, like the soldier game's stand.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.6, top + 0.2, z - 0.48 * r - 0.6), V(x + 0.6, top + 1.6, z - 0.48 * r + 0.6), P.white))
	point.CastShadow = false
	return model
end

-- The deck: a step along the front, the studded front deck, the raised studded terrace behind it with its back
-- wall, a stair up at each end. Every surface in two or three tones: light nosings on the top edges, dark kick
-- bands at the foot, a dark band under every cap; pilasters part the display bays.
function Armory.base(c, backTo)
	local b = c:group('ArmoryBase')
	local T = Armory.Tone
	local X, Dp, F, H, TZ, SW = Armory.HalfWidth, Armory.Depth, Armory.Floor, Armory.Step, Armory.TerraceZ, Armory.StairW
	local BW = Armory.BackWall
	-- the front step and the deck, with their finished front edges
	studs(b:box('ArmoryStep', V(-X, 0, 0), V(X, F / 2, 1.2), T.face, M.Plastic), true)
	b:box('StepKick', V(-X - 0.06, 0, -0.06), V(X + 0.06, 0.24, 1.2), T.kick, M.SmoothPlastic)
	b:box('StepNosing', V(-X - 0.04, F / 2 - 0.18, -0.08), V(X + 0.04, F / 2 + 0.02, 0.35), T.riser, M.SmoothPlastic)
	studs(b:box('ArmoryFloor', V(-X, 0, 1.2), V(X, F, TZ), T.deck, M.Plastic))
	b:box('DeckFace', V(-X - 0.06, F / 2, 1.14), V(X + 0.06, F - 0.2, 1.2), T.face, M.SmoothPlastic)
	b:box('DeckNosing', V(-X - 0.06, F - 0.2, 1.08), V(X + 0.06, F + 0.02, 1.55), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		-- the deck's ends: a dark face and a light nosing too
		b:box('DeckFace', V(sx * X, 0.24, 0), V(sx * (X + 0.06), F - 0.2, TZ), T.face, M.SmoothPlastic)
		b:box('DeckKick', V(sx * X, 0, 0), V(sx * (X + 0.08), 0.24, Dp), T.kick, M.SmoothPlastic)
	end
	-- the terrace: studded wall body, a studded top, a dark skirting and a dark band under a light coping on its
	-- front wall, the same round its ends
	studs(b:box('ArmoryTerrace', V(-X, 0, TZ), V(X, H, Dp), T.wall, M.Plastic), true)
	studs(b:box('ArmoryTerraceTop', V(-X, H - 0.05, TZ), V(X, H, Dp), T.deck, M.Plastic))
	local x0, x1 = -X + SW, X - SW
	b:box('WallKick', V(x0, F, TZ - 0.14), V(x1, F + 0.55, TZ), T.kick, M.SmoothPlastic)
	b:box('WallBand', V(x0, H - 1.15, TZ - 0.12), V(x1, H - 0.35, TZ), T.band, M.SmoothPlastic)
	b:box('WallCap', V(-X - 0.1, H - 0.35, TZ - 0.45), V(X + 0.1, H + 0.03, TZ + 0.5), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		b:box('WallBand', V(sx * X, H - 1.15, TZ), V(sx * (X + 0.12), H - 0.35, Dp), T.band, M.SmoothPlastic)
		b:box('WallKick', V(sx * X, 0, TZ), V(sx * (X + 0.14), 0.6, Dp), T.kick, M.SmoothPlastic)
	end
	-- pilasters between the front row's bays and beside the stairs at the two ends
	for k = -3, 2 do
		Armory.pilaster(b, (k + 0.5) * Armory.Spacing, TZ, F, H - 1.15)
	end
	-- the back wall on the terrace: studded, a dark skirting, a dark band and a light coping; pilasters between
	-- the back row's bays and big corner posts at its ends, from the hall floor to above the coping
	studs(b:box('BackWall', V(-X, H, Dp - 1.2), V(X, H + BW, Dp), T.wall, M.Plastic), true)
	b:box('BackKick', V(-X, H, Dp - 1.34), V(X, H + 0.5, Dp - 1.2), T.kick, M.SmoothPlastic)
	b:box('BackBand', V(-X, H + BW - 1.0, Dp - 1.32), V(X, H + BW - 0.4, Dp - 1.2), T.band, M.SmoothPlastic)
	b:box('BackCap', V(-X - 0.3, H + BW - 0.4, Dp - 1.7), V(X + 0.3, H + BW, Dp + 0.3), T.trim, M.SmoothPlastic)
	-- the three middle bays' wall a step higher, with its own band and cap: the skyline steps up to the centre
	local cx = 1.5 * Armory.Spacing
	studs(b:box('BackCrown', V(-cx, H + BW, Dp - 1.2), V(cx, H + BW + 1.2, Dp), T.wall, M.Plastic), true)
	b:box('BackBand', V(-cx, H + BW + 0.35, Dp - 1.32), V(cx, H + BW + 0.85, Dp - 1.2), T.band, M.SmoothPlastic)
	b:box('BackCap', V(-cx - 0.3, H + BW + 0.85, Dp - 1.7), V(cx + 0.3, H + BW + 1.2, Dp + 0.3), T.trim, M.SmoothPlastic)
	for k = -3, 2 do
		Armory.pilaster(b, (k + 0.5) * Armory.Spacing, Dp - 1.2, H, H + BW - 1.0)
	end
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (X - 1.4), sx * (X + 0.3)
		b:box('CornerPost', V(xa, 0, Dp - 2.1), V(xb, H + BW + 0.6, Dp + 0.3), T.pilaster, M.SmoothPlastic)
		b:box('CornerBase', V(xa - sx * 0.2, 0, Dp - 2.3), V(xb + sx * 0.2, 1.0, Dp + 0.5), T.kick, M.SmoothPlastic)
		b:box('CornerCap', V(xa - sx * 0.2, H + BW + 0.6, Dp - 2.3), V(xb + sx * 0.2, H + BW + 1.1, Dp + 0.5), T.trim, M.SmoothPlastic)
		-- a low parapet along the terrace's open end, with a light cap
		studs(b:box('Parapet', V(sx * (X - 0.8), H, TZ + 0.5), V(sx * X, H + 1.3, Dp - 2.1), T.wall, M.Plastic), true)
		b:box('ParapetCap', V(sx * (X - 0.95), H + 1.3, TZ + 0.35), V(sx * (X + 0.15), H + 1.6, Dp - 2.1), T.trim, M.SmoothPlastic)
	end
	-- the back block: behind the back wall the stand runs on, solid and studded, to `backTo` (the hall wall), so it
	-- is built into the wall like the reference's stepped terrace; its two ends get the same kick, band and coping,
	-- with pilasters along them
	if backTo and backTo > Dp + 1 then
		local top = H + BW
		studs(b:box('BackBlock', V(-X, 0, Dp), V(X, top, backTo), T.wall, M.Plastic), true)
		for _, sx in { -1, 1 } do
			b:box('BlockKick', V(sx * X, 0, Dp + 0.3), V(sx * (X + 0.14), 0.6, backTo), T.kick, M.SmoothPlastic)
			b:box('BlockBand', V(sx * X, top - 1.0, Dp + 0.3), V(sx * (X + 0.12), top - 0.4, backTo), T.band, M.SmoothPlastic)
			b:box('BlockCap', V(sx * (X - 0.4), top - 0.4, Dp + 0.3), V(sx * (X + 0.3), top, backTo), T.trim, M.SmoothPlastic)
			local n = math.floor((backTo - Dp) / 11)
			for k = 1, n do
				local z = Dp + (backTo - Dp) * k / (n + 1)
				b:box('Pilaster', V(sx * X, 0.6, z - 0.65), V(sx * (X + 0.45), top - 1.0, z + 0.65), T.pilaster, M.SmoothPlastic)
				b:box('PilasterBase', V(sx * X, 0, z - 0.85), V(sx * (X + 0.7), 0.7, z + 0.85), T.kick, M.SmoothPlastic)
				b:box('PilasterCap', V(sx * X, top - 1.45, z - 0.85), V(sx * (X + 0.7), top - 1.0, z + 0.85), T.trim, M.SmoothPlastic)
			end
		end
	end
	-- a stair at each end, from the deck up to the terrace (rises of 0.9 at most on 1.15 treads, so the stair fits the
	-- deck's depth): a mid-tone riser body under a light studded tread with its nosing, between two stringers with
	-- light caps
	local n = math.ceil((H - F) / 0.9) - 1
	local rise, run = (H - F) / (n + 1), Armory.StairRun
	for _, sx in { -1, 1 } do
		local a, bx = sx * (X - SW), sx * X
		local lo, hi = math.min(a, bx), math.max(a, bx)
		for k = 1, n do
			local z0 = TZ - (n + 1 - k) * run
			local h = F + k * rise
			studs(b:box('ArmoryStair', V(lo, F, z0), V(hi, h - 0.2, TZ), T.riser, M.Plastic))
			studs(b:box('StairTread', V(lo, h - 0.2, z0 - 0.06), V(hi, h, z0 + run), T.tread, M.Plastic))
		end
		-- (the stringer's slope runs 0.7 above the treads' nosings, so it starts a little in front of the first step)
		local za, zb = TZ - (n + 1) * run - 0.7 * run / rise, TZ
		for _, xe in { a, bx - sx * 0.5 } do
			local xl, xr = math.min(xe, xe + sx * 0.5), math.max(xe, xe + sx * 0.5)
			local ht = H - F + 0.7
			b:wedge('Stringer', V(xr - xl, ht, zb - za), CFrame.new((xl + xr) / 2, F + ht / 2, (za + zb) / 2), T.riser, M.SmoothPlastic)
			local p0, p1 = V((xl + xr) / 2, F, za), V((xl + xr) / 2, F + ht, zb)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			b:part('StringerCap', V(0.8, 0.28, (p1 - p0).Magnitude), cf * CFrame.new(0, 0.12, 0), T.trim, M.SmoothPlastic)
		end
	end
	return b
end

-- The shop's props, one purposeful group on each terrace end beside the back row (clear of the stair landings):
-- the till (a counter on a dark kick with a light top, a register with its screen and drawer, a stool) at the
-- viewer's left, the stock (hard gun cases stacked and leaning, a milk crate) at the right. Neutral tones: the
-- saturated colour stays on the pads.
function Armory.props(c)
	local T = Armory.Tone
	local X, H, Dp = Armory.HalfWidth, Armory.Step, Armory.Depth
	local p = c:group('ArmoryProps')
	-- the till on the terrace's +X end, between the end pad and the stair, against the back wall
	local e = 2 * Armory.Spacing + Armory.MatW / 2 + 0.4 -- clear of the end slot's mat
	local x0, x1, z0, z1 = e + 0.1, X - Armory.StairW - 0.25, Dp - 6.0, Dp - 2.6
	p:box('CounterKick', V(x0 + 0.1, H, z0 + 0.1), V(x1 - 0.1, H + 0.35, z1 - 0.1), T.kick, M.SmoothPlastic)
	studs(p:box('Counter', V(x0 + 0.2, H + 0.35, z0 + 0.2), V(x1 - 0.2, H + 2.9, z1 - 0.2), T.riser, M.Plastic), true)
	p:box('CounterBand', V(x0 + 0.15, H + 2.3, z0 + 0.15), V(x1 - 0.15, H + 2.6, z1 - 0.15), T.band, M.SmoothPlastic)
	p:box('CounterTop', V(x0, H + 2.9, z0), V(x1, H + 3.2, z1), T.trim, M.SmoothPlastic)
	local rx, rz = (x0 + x1) / 2, z0 + 1.6
	p:box('RegisterBase', V(rx - 0.8, H + 3.2, rz - 0.7), V(rx + 0.8, H + 3.55, rz + 0.7), T.case, M.SmoothPlastic)
	p:box('RegisterDrawer', V(rx - 0.75, H + 3.25, rz - 0.75), V(rx + 0.75, H + 3.45, rz - 0.7), T.metal, M.SmoothPlastic)
	p:wedge('RegisterKeys', V(1.3, 0.5, 0.8), CFrame.new(rx, H + 3.8, rz - 0.25) * CFrame.Angles(0, math.pi, 0), T.caseRim, M.SmoothPlastic)
	p:box('RegisterBody', V(rx - 0.65, H + 3.55, rz + 0.15), V(rx + 0.65, H + 4.35, rz + 0.65), T.case, M.SmoothPlastic)
	p:box('RegisterScreen', V(rx - 0.45, H + 3.85, rz + 0.1), V(rx + 0.45, H + 4.2, rz + 0.15), C(110, 200, 150), M.SmoothPlastic)
	-- (the stool on the customer side, clear of the end pad)
	p:post('StoolLeg', 0.18, 1.7, V(x1 - 0.9, H, z0 - 0.9), T.case, M.Metal)
	p:post('StoolFoot', 0.6, 0.15, V(x1 - 0.9, H, z0 - 0.9), T.case, M.SmoothPlastic)
	p:post('StoolSeat', 0.62, 0.3, V(x1 - 0.9, H + 1.7, z0 - 0.9), C(150, 60, 70), M.SmoothPlastic)
	-- the stock, on the -X end: two hard cases stacked (a light seam band, two latches and a handle each), one
	-- leaning on the back wall, a milk crate
	local sx = -(e + X - Armory.StairW) / 2 -- the middle of the gap between the end mat and the stair
	local function case(cf, w, h, d)
		p:part('GunCase', V(w, h, d), cf, T.case, M.SmoothPlastic)
		p:part('CaseSeam', V(w + 0.06, 0.12, d + 0.06), cf, T.caseRim, M.SmoothPlastic)
		for _, s in { -1, 1 } do
			p:part('CaseLatch', V(0.3, 0.3, 0.12), cf * CFrame.new(s * w * 0.3, 0, -d / 2 - 0.05), T.metal, M.SmoothPlastic)
		end
		p:part('CaseHandle', V(0.9, 0.16, 0.16), cf * CFrame.new(0, 0, -d / 2 - 0.14), T.case, M.SmoothPlastic)
	end
	case(CFrame.new(sx, H + 0.45, Dp - 5.0) * CFrame.Angles(0, math.rad(4), 0), 2.4, 0.9, 1.4)
	case(CFrame.new(sx - 0.05, H + 1.3, Dp - 4.9) * CFrame.Angles(0, math.rad(-7), 0), 2.1, 0.8, 1.25)
	case(CFrame.new(sx + 0.3, H + 1.6, Dp - 2.4) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(80)), 3.0, 0.8, 1.4)
	local cx, cz = sx, Dp - 7.4
	p:box('CrateBase', V(cx - 0.8, H, cz - 0.8), V(cx + 0.8, H + 0.25, cz + 0.8), T.crate:Lerp(C(0, 0, 0), 0.3), M.SmoothPlastic)
	p:box('Crate', V(cx - 0.75, H + 0.25, cz - 0.75), V(cx + 0.75, H + 1.3, cz + 0.75), T.crate, M.SmoothPlastic)
	p:box('CrateRim', V(cx - 0.8, H + 1.3, cz - 0.8), V(cx + 0.8, H + 1.45, cz + 0.8), T.crate:Lerp(P.white, 0.25), M.SmoothPlastic)
	for _, dz in { -0.4, 0.4 } do
		p:box('CrateSlot', V(cx - 0.78, H + 0.7, cz + dz - 0.15), V(cx + 0.78, H + 0.95, cz + dz + 0.15), T.crate:Lerp(C(0, 0, 0), 0.45), M.SmoothPlastic)
	end
	return p
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
-- opts.backTo: how far back (local z) the stand's back block runs, e.g. to the hall wall (none when nil).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local colors = require(ReplicatedStorage.Shared.GunRules).Colors
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.base(a, opts.backTo)
	Armory.props(a)
	local walls = { Armory.TerraceZ, Armory.Depth - 1.2 }
	for i, gun in guns do
		local ri = (i - 1) // 5 + 1
		local row = Armory.Rows[ri]
		if not row then break end
		local col = (i - 1) % 5
		-- Gun 1 stands on the viewer's left: their left is +X when they look toward +Z.
		Armory.slot(a, gun, 2 * Armory.Spacing - col * Armory.Spacing, row.z, row.y, colors, row.label, row.scale, walls[ri])
	end
	return model
end
---------------------------------------------------------------------------------------------- buildings
-- The reference street's buildings (ref1_street.png, measured with a matched camera): studded red brick, two
-- storeys of ~15 studs, a slate-blue band between them, big grey-framed windows of four blue panes, a slate eave
-- and a low hip roof. Building frame: origin at the facade's left end on the ground, +X along the facade, +Z out
-- of it; the building runs back to z = -depth. One builder serves both sides of the street.
local function lotFrame(ctx, s, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-FRONT, 0, za), V(-FRONT - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(FRONT, 0, za - w), V(FRONT + 1, 0, za - w)))
end

-- Window: a studded grey stone frame standing proud of the wall, a lighter stone sill under it and a lintel over it
-- (each a step further out, so the frame reads in three shades and casts a shadow line), and, set back inside, four
-- studded panes (the two on the left a darker blue, like the reference's reflections) split by navy bars.
-- x = centre, y = frame bottom.
local function window(c, x, y, o)
	o = o or {}
	local w, h, t = o.w or 15, o.h or P.street.winH, 1.3
	local x0, x1, y1 = x - w / 2, x + w / 2, y + h
	local trim = P.st.trim
	-- (the frame stands 1 stud proud, so the glass sits in a 0.9-deep recess with a shadowed reveal)
	sbox(c, 'WindowFrame', V(x0, y, -0.2), V(x0 + t, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x1 - t, y, -0.2), V(x1, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y, -0.2), V(x1 - t, y + t, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y1 - t, -0.2), V(x1 - t, y1, 1.0), trim, true)
	sbox(c, 'WindowSill', V(x0 - 0.6, y - 0.8, -0.2), V(x1 + 0.6, y, 1.6), P.st.sill, true)
	sbox(c, 'WindowLintel', V(x0 - 0.3, y1, -0.2), V(x1 + 0.3, y1 + 0.9, 1.3), P.st.trimDark, true)
	-- the reveal: a darker strip inside the top and left of the frame, where the frame shades the glass (big windows
	-- only: on small ones it isn't seen and the parts add up on tall buildings)
	if w >= 8 then
		local rev = P.st.trimDark:Lerp(P.black, 0.3)
		sbox(c, 'WindowReveal', V(x0 + t, y1 - t - 0.45, -0.2), V(x1 - t, y1 - t, 0.5), rev, true)
		sbox(c, 'WindowReveal', V(x0 + t, y + t, -0.2), V(x0 + t + 0.45, y1 - t - 0.45, 0.5), rev, true)
	end
	local n = o.panes or (w >= 9 and 4 or 2)
	local bar = 0.7
	local g0, g1 = x0 + t, x1 - t
	local pw = (g1 - g0 - (n - 1) * bar) / n
	-- the glass: one darker pane across the opening, the right half lighter, navy bars in front
	sbox(c, 'Glass', V(g0, y + t, -0.2), V(g1, y1 - t, 0.1), P.st.glassA, true)
	sbox(c, 'Glass', V((g0 + g1) / 2, y + t, -0.2), V(g1, y1 - t, 0.12), P.st.glassB, true)
	for k = 1, n - 1 do
		local a = g0 + k * pw + (k - 1) * bar
		sbox(c, 'WindowBar', V(a, y + t, -0.2), V(a + bar, y1 - t, 0.25), P.st.mullion, true)
	end
end

-- Hip roof (45 degrees by default) in studded slate over the rectangle x0..x1, z0..z1 standing at y: a darker eave
-- slab overhanging the walls by one stud, wedge slopes on all four sides with corner wedges, and a flat top with a
-- darker rim round a lighter panel.
local function hipRoof(c, x0, z0, x1, z1, y, rise, run)
	rise, run = rise or 5, run or 5
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(x0 - 1, y, z0 - 1), V(x1 + 1, y + 1, z1 + 1), dark)
	y += 1
	local my = y + rise / 2
	local lx, lz = x1 - x0 - 2 * run, z1 - z0 - 2 * run
	local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
	-- (a wedge's slope rises toward its local +Z)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z1 - run / 2) * CFrame.Angles(0, math.pi, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z0 + run / 2), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x0 + run / 2, my, mz) * CFrame.Angles(0, math.pi / 2, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x1 - run / 2, my, mz) * CFrame.Angles(0, -math.pi / 2, 0), col, M.Plastic)
	-- corners: a corner wedge's peak stands over its local (+X, -Z) corner; turn it toward the roof's middle
	for _, k in { { x0, z1, 0 }, { x1, z1, 90 }, { x1, z0, 180 }, { x0, z0, -90 } } do
		local cx = k[1] + (k[1] == x0 and run / 2 or -run / 2)
		local cz = k[2] + (k[2] == z0 and run / 2 or -run / 2)
		local p = Instance.new('CornerWedgePart')
		p.Name = 'RoofCorner'
		p.Anchored = true
		p.Size = V(run, rise, run)
		p.CFrame = c:world(CFrame.new(cx, my, cz) * CFrame.Angles(0, math.rad(k[3]), 0))
		p.Color, p.Material = col, M.Plastic
		smooth(p)
		p.Parent = c.parent
	end
	sbox(c, 'RoofTop', V(x0 + run, y, z0 + run), V(x1 - run, y + rise + 0.3, z1 - run), dark)
	if lx > 2 and lz > 2 then sbox(c, 'RoofPanel', V(x0 + run + 1, y + rise + 0.3, z0 + run + 1), V(x1 - run - 1, y + rise + 0.5, z1 - run - 1), col, true) end
end

-- A face of a w x depth block as a facade frame (+Z out of it, +X along it as seen from outside), and its width.
local function faceFrame(c, face, w, depth)
	if face == 'left' then return c:at(CFrame.new(0, 0, -depth) * CFrame.Angles(0, -math.pi / 2, 0)), depth end
	if face == 'right' then return c:at(CFrame.new(w, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)), depth end
	if face == 'back' then return c:at(CFrame.new(w, 0, -depth) * CFrame.Angles(0, math.pi, 0)), w end
	return c, w
end

-- Gable roof, studded slate: the darker eave slab, two slopes up to a ridge cap, and brick gable triangles. along =
-- 'x': the ridge runs along the facade (eaves front and back); along = 'z': the ridge runs back from the street and
-- the gable (with a stone-trimmed pediment and a round vent) faces it.
local function gableRoof(c, w, d, H, rise, along, wall)
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(-1, H, -d - 1), V(w + 1, H + 1, 1), dark)
	local y = H + 1
	local function W(name, size, cf, color) studs(c:wedge(name, size, cf, color, M.Plastic), true) end
	if along == 'z' then
		-- slopes rising from the side eaves to a ridge over the middle; the gables front and back
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w / 4 - 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, math.pi / 2, 0), col)
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w * 3 / 4 + 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, -math.pi / 2, 0), col)
		for _, zf in { -0.5, -d + 0.5 } do
			W('Gable', V(1, rise, w / 2), CFrame.new(w / 4, y + rise / 2, zf) * CFrame.Angles(0, math.pi / 2, 0), wall)
			W('Gable', V(1, rise, w / 2), CFrame.new(w * 3 / 4, y + rise / 2, zf) * CFrame.Angles(0, -math.pi / 2, 0), wall)
		end
		sbox(c, 'RidgeCap', V(w / 2 - 0.6, y + rise - 0.3, -d - 1), V(w / 2 + 0.6, y + rise + 0.4, 1), dark, true)
		decor(c:part('GableVent', V(0.3, 2.2, 2.2), CFrame.new(w / 2, y + rise * 0.4, 0.1) * CFrame.Angles(0, math.pi / 2, 0), P.st.trim, M.Plastic, Enum.PartType.Cylinder))
		decor(c:part('GableVentHole', V(0.32, 1.4, 1.4), CFrame.new(w / 2, y + rise * 0.4, 0.12) * CFrame.Angles(0, math.pi / 2, 0), P.st.gutter, M.Plastic, Enum.PartType.Cylinder))
	else
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, 0.5 - d / 4) * CFrame.Angles(0, math.pi, 0), col)
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, -d * 3 / 4 - 0.5), col)
		for _, xf in { 0.5, w - 0.5 } do
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d * 3 / 4), wall)
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d / 4) * CFrame.Angles(0, math.pi, 0), wall)
		end
		sbox(c, 'RidgeCap', V(-1, y + rise - 0.3, -d / 2 - 0.6), V(w + 1, y + rise + 0.4, -d / 2 + 0.6), dark, true)
	end
end

-- Flat roof behind a brick parapet with a stone coping, a dark deck and rooftop clutter (air-con boxes, a vent).
local function flatRoof(c, w, d, H, wall)
	sbox(c, 'RoofDeck', V(0, H, -d), V(w, H + 0.4, 0), P.st.roofDark)
	for _, e in { { V(-0.3, H, -0.9), V(w + 0.3, H + 2.2, 0.3) }, { V(-0.3, H, -d - 0.3), V(w + 0.3, H + 2.2, -d + 0.9) },
		{ V(-0.3, H, -d), V(0.9, H + 2.2, 0) }, { V(w - 0.9, H, -d), V(w + 0.3, H + 2.2, 0) } } do
		sbox(c, 'Parapet', e[1], e[2], wall)
		sbox(c, 'Coping', V(e[1].X - 0.3, H + 2.2, e[1].Z - 0.3), V(e[2].X + 0.3, H + 2.8, e[2].Z + 0.3), P.st.trim, true)
	end
	for k, x in { w * 0.3, w * 0.62 } do
		sbox(c, 'RoofAirCon', V(x - 1.8, H + 0.4, -d * 0.55 - 1.5), V(x + 1.8, H + 2.6, -d * 0.55 + 1.5), C(206, 210, 216), true)
		decor(c:box('RoofAirConFan', V(x - 1.2, H + 2.6, -d * 0.55 - 1), V(x + 1.2, H + 2.75, -d * 0.55 + 1), C(110, 116, 126), M.Plastic))
		if k == 2 then decor(c:post('RoofVent', 0.5, 3.4, V(x + 4, H + 0.4, -d * 0.4), P.st.gutter, M.Plastic)) end
	end
end

-- Brick chimney stack on the roof: a stone cap and two pots.
local function chimney(c, x, z, y0, y1, wall)
	sbox(c, 'Chimney', V(x - 1.5, y0, z - 1.3), V(x + 1.5, y1, z + 1.3), wall)
	sbox(c, 'ChimneyCap', V(x - 1.8, y1, z - 1.6), V(x + 1.8, y1 + 0.6, z + 1.6), P.st.trim, true)
	for _, dx in { -0.7, 0.7 } do decor(c:post('ChimneyPot', 0.42, 1.0, V(x + dx, y1 + 0.6, z), P.st.trunk, M.Plastic)) end
end

-- An entrance in a facade frame at x: a stone surround standing proud of the wall, the door set back in it with a
-- glazed transom over it, a brass knob, a house number and a wall lamp. kind: 'stoop' (three steps up to a landing
-- between brick cheek walls with stone caps, a slate canopy on brackets), 'porch' (a deck across span = { x0, x1 }
-- with two steps, posts with bases and caps, a rail and a roof with a fascia) or 'door' (two steps and a canopy).
local function entrance(c, x, o)
	local kind, dw, number = o.kind or 'door', 3.8, o.number or '12'
	local rise = kind == 'stoop' and 1.8 or (kind == 'porch' and 1.0 or 0.9)
	local y0 = 0.6 + rise -- (the grass is at 0.6)
	local trim, dark = P.st.trim, P.st.trimDark
	-- surround, door, transom, knob, number, lamp
	sbox(c, 'DoorSurround', V(x - dw / 2 - 1.2, y0 - 0.2, -0.2), V(x - dw / 2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorSurround', V(x + dw / 2, y0 - 0.2, -0.2), V(x + dw / 2 + 1.2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorHead', V(x - dw / 2 - 1.5, y0 + 9.6, -0.2), V(x + dw / 2 + 1.5, y0 + 10.6, 1.0), dark, true)
	sbox(c, 'Door', V(x - dw / 2, y0, -0.2), V(x + dw / 2, y0 + 7.8, 0.15), o.door or C(40, 110, 76))
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 4.4, 0.15), V(x + dw / 2 - 0.5, y0 + 7.2, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 0.6, 0.15), V(x + dw / 2 - 0.5, y0 + 3.8, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'Transom', V(x - dw / 2, y0 + 7.8, -0.2), V(x + dw / 2, y0 + 9.6, 0.1), P.st.glassB, true)
	decor(c:box('DoorKnob', V(x + dw / 2 - 0.8, y0 + 3.9, 0.15), V(x + dw / 2 - 0.4, y0 + 4.3, 0.55), C(232, 188, 70), M.Plastic))
	local plate = sbox(c, 'HouseNumber', V(x + dw / 2 + 1.4, y0 + 6.2, -0.2), V(x + dw / 2 + 2.8, y0 + 7.4, 0.25), P.white, true)
	line(surface(plate, Enum.NormalId.Back, 30), 'Number', number, C(30, 40, 70), FONT.title, 0.05, 0.9)
	local lampBox = sbox(c, 'WallLamp', V(x - dw / 2 - 2.6, y0 + 6.4, 0), V(x - dw / 2 - 1.5, y0 + 8.0, 1.0), P.st.lamp, true)
	decor(c:box('WallLampGlow', V(x - dw / 2 - 2.45, y0 + 6.6, 1.0), V(x - dw / 2 - 1.65, y0 + 7.8, 1.1), P.st.lampGlow, M.Neon)).CastShadow = false
	light(lampBox, P.st.lampGlow, 0.6, 10)
	if kind == 'porch' then
		local x0, x1 = o.span[1], o.span[2]
		local dp = 3.6
		sbox(c, 'PorchDeck', V(x0, -1, 0), V(x1, y0, dp), C(176, 150, 120))
		sbox(c, 'PorchDeckEdge', V(x0 - 0.2, y0 - 0.5, dp - 0.4), V(x1 + 0.2, y0 + 0.1, dp + 0.2), C(150, 124, 96), true)
		for k = 1, 2 do sbox(c, 'PorchStep', V(x - 2.6, -1, dp + (k - 1) * 0.9), V(x + 2.6, y0 - k * 0.5, dp + k * 0.9), P.st.sill) end
		for _, px in { x0 + 0.5, x - 3.4, x + 3.4, x1 - 0.5 } do
			sbox(c, 'PorchPostBase', V(px - 0.7, y0, dp - 1.2), V(px + 0.7, y0 + 0.8, dp - 0.1), dark, true)
			sbox(c, 'PorchPost', V(px - 0.45, y0 + 0.8, dp - 0.95), V(px + 0.45, y0 + 8.6, dp - 0.35), P.white, true)
			sbox(c, 'PorchPostCap', V(px - 0.7, y0 + 8.6, dp - 1.2), V(px + 0.7, y0 + 9.1, dp - 0.1), dark, true)
		end
		for _, seg in { { x0 + 0.5, x - 3.4 }, { x + 3.4, x1 - 0.5 } } do
			sbox(c, 'PorchRail', V(seg[1], y0 + 2.6, dp - 0.8), V(seg[2], y0 + 3.0, dp - 0.5), P.white, true)
			for bx = seg[1] + 1, seg[2] - 0.5, 1.2 do decor(c:box('PorchBaluster', V(bx - 0.15, y0, dp - 0.75), V(bx + 0.15, y0 + 2.6, dp - 0.55), P.white, M.Plastic)) end
		end
		sbox(c, 'PorchRoof', V(x0 - 0.4, y0 + 9.1, -0.2), V(x1 + 0.4, y0 + 9.7, dp + 0.5), P.st.roofDark, true)
		sbox(c, 'PorchFascia', V(x0 - 0.5, y0 + 8.9, dp + 0.2), V(x1 + 0.5, y0 + 9.8, dp + 0.7), trim, true)
	else
		local steps = kind == 'stoop' and 3 or 2
		local land = kind == 'stoop' and 1.6 or 1.0
		local sw = dw + 2.4
		sbox(c, 'StoopLanding', V(x - sw / 2, -1, 0), V(x + sw / 2, y0, land), P.st.sill)
		for k = 1, steps do sbox(c, 'StoopStep', V(x - sw / 2, -1, land + (k - 1) * 0.9), V(x + sw / 2, y0 - k * rise / steps, land + k * 0.9), P.st.sill:Lerp(P.black, (k % 2) * 0.05)) end
		if kind == 'stoop' then
			local dz = land + steps * 0.9
			for _, sx in { -1, 1 } do
				local cx = x + sx * (sw / 2 + 0.5)
				sbox(c, 'CheekWall', V(cx - 0.5, -1, 0), V(cx + 0.5, y0 + 0.9, dz), P.st.brickDark)
				sbox(c, 'CheekCap', V(cx - 0.65, y0 + 0.9, 0), V(cx + 0.65, y0 + 1.3, dz + 0.15), trim, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, 0.3), V(cx + 0.12, y0 + 3.3, 0.6), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 3.0, 0.3), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, dz - 0.6), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
			end
		end
		sbox(c, 'Canopy', V(x - dw / 2 - 1.8, y0 + 10.8, -0.2), V(x + dw / 2 + 1.8, y0 + 11.3, 2.6), P.st.roofDark, true)
		sbox(c, 'CanopyFascia', V(x - dw / 2 - 1.9, y0 + 10.6, 2.4), V(x + dw / 2 + 1.9, y0 + 11.4, 2.8), trim, true)
		for _, sx in { -1, 1 } do decor(c:bar('CanopyBracket', V(x + sx * (dw / 2 + 1.2), y0 + 9.2, 0.2), V(x + sx * (dw / 2 + 1.2), y0 + 10.8, 2.2), 0.3, P.iron, M.Plastic)) end
	end
end

-- Shopfront on a facade frame (+Z out of the wall) between x0 and x1, the ground floor of a shop with flats above:
-- a stone stall riser, display glass in two tones split by dark mullions, a glazed door (sh.door = its centre, default
-- near x1), dark pilasters either side, a fascia board in the shop's colour carrying its name (sh.sign), and a striped
-- fabric awning (sh.stripes) sloping out over the pavement with a valance.
local function shopfront(c, sh)
	local x0, x1 = sh.x0, sh.x1
	local col = sh.color or C(40, 110, 76)
	local dark = col:Lerp(P.black, 0.35)
	local dx = sh.door or (x1 - 3)
	sbox(c, 'ShopPilaster', V(x0 - 0.8, 0.6, -0.2), V(x0, 10, 0.9), dark)
	sbox(c, 'ShopPilaster', V(x1, 0.6, -0.2), V(x1 + 0.8, 10, 0.9), dark)
	sbox(c, 'StallRiser', V(x0, 0.6, -0.2), V(x1, 2.4, 0.7), P.st.trim)
	sbox(c, 'StallSill', V(x0 - 0.2, 2.4, -0.2), V(x1 + 0.2, 2.8, 1.0), P.st.sill, true)
	-- the glass, the door's opening left out
	local spans = { { x0, dx - 2.2 }, { dx + 2.2, x1 } }
	for _, sp in spans do
		if sp[2] - sp[1] > 1 then
			sbox(c, 'ShopGlass', V(sp[1], 2.8, -0.2), V(sp[2], 9.2, 0.1), P.st.glassA, true)
			sbox(c, 'ShopGlass', V((sp[1] + sp[2]) / 2, 2.8, -0.2), V(sp[2], 9.2, 0.12), P.st.glassB, true)
			local n = math.max(1, math.floor((sp[2] - sp[1]) / 4.5 + 0.5))
			for k = 1, n - 1 do
				local mx = sp[1] + (sp[2] - sp[1]) * k / n
				sbox(c, 'ShopMullion', V(mx - 0.3, 2.8, -0.2), V(mx + 0.3, 9.2, 0.5), dark, true)
			end
			sbox(c, 'ShopTransom', V(sp[1], 9.2, -0.2), V(sp[2], 10, 0.6), dark, true)
		end
	end
	-- the door: frame, glass, push bar, a step
	sbox(c, 'ShopDoorFrame', V(dx - 2.2, 0.6, -0.2), V(dx + 2.2, 10, 0.6), dark)
	sbox(c, 'ShopDoor', V(dx - 1.6, 0.6, -0.2), V(dx + 1.6, 8.6, 0.75), P.st.glassB, true)
	sbox(c, 'ShopDoorBar', V(dx - 1.2, 4.2, 0.75), V(dx + 1.2, 4.6, 1.05), C(214, 216, 222), true)
	sbox(c, 'ShopStep', V(dx - 2.4, -0.5, 0), V(dx + 2.4, 0.9, 1.6), P.st.sill)
	-- fascia board with the shop's name
	local board = sbox(c, 'Fascia', V(x0 - 0.8, 10, -0.2), V(x1 + 0.8, 12.8, 1.1), col)
	sbox(c, 'FasciaCap', V(x0 - 1.0, 12.8, -0.2), V(x1 + 1.0, 13.3, 1.4), dark, true)
	if sh.sign then
		local g = surface(board, Enum.NormalId.Back, 20)
		line(g, 'Name', sh.sign, sh.text or P.white, FONT.loud, 0.12, 0.76, col:Lerp(P.black, 0.6), 3)
	end
	-- the awning: stripes sloping from under the fascia out to a valance (a wedge rises toward its local +Z)
	local stripes = sh.stripes or { col, P.white }
	local n = math.max(2, math.floor((x1 - x0) / 1.8))
	local depth = sh.awning or 3.4
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		local sc = stripes[k % #stripes + 1]
		decor(c:wedge('Awning', V(b - a, 1.8, depth), CFrame.new((a + b) / 2, 9.1, depth / 2 + 0.1) * CFrame.Angles(0, math.pi, 0), sc, M.SmoothPlastic))
		decor(c:box('AwningValance', V(a, 7.6, depth), V(b, 8.2, depth + 0.2), sc, M.SmoothPlastic))
	end
end

-- Fire escape on a facade frame at x (w wide): a dark iron landing under the windows of every upper floor, railings
-- with posts, a stair between each landing and the next, and a drop ladder under the lowest.
local function fireEscape(c, x, w, floors)
	local iron, rail = C(46, 50, 60), C(62, 66, 78)
	local x0, x1 = x - w / 2, x + w / 2
	local prev
	for f = 2, floors do
		local y = P.street.sills[2] + (f - 2) * 15 - 1.4
		sbox(c, 'EscapeLanding', V(x0, y - 0.4, 0), V(x1, y, 2.8), iron, true)
		decor(c:box('EscapeRail', V(x0, y + 3.2, 2.5), V(x1, y + 3.5, 2.8), rail, M.Plastic))
		for _, ex in { x0, x1 - 0.3 } do decor(c:box('EscapeRail', V(ex, y + 3.2, 0), V(ex + 0.3, y + 3.5, 2.8), rail, M.Plastic)) end
		for bx = x0, x1 + 0.01, w / math.max(2, math.floor(w / 2)) do
			decor(c:box('EscapePost', V(math.min(bx, x1 - 0.25), y, 2.5), V(math.min(bx, x1 - 0.25) + 0.25, y + 3.2, 2.75), rail, M.Plastic))
		end
		if prev then
			-- the stair from the landing below, rising along the facade
			decor(c:bar('EscapeStair', V(x0 + 1.5, prev + 0.2, 1.4), V(x1 - 2.5, y - 0.2, 1.4), 1.6, iron, M.Plastic))
			decor(c:bar('EscapeStringer', V(x0 + 1.5, prev + 1.4, 2.3), V(x1 - 2.5, y + 1.0, 2.3), 0.25, rail, M.Plastic))
		else
			-- the drop ladder, hooked up under the lowest landing
			for _, lx in { x1 - 2.2, x1 - 0.8 } do decor(c:box('EscapeLadder', V(lx - 0.12, y - 6, 2.3), V(lx + 0.12, y - 0.4, 2.5), rail, M.Plastic)) end
			for ly = y - 5.5, y - 1, 1.1 do decor(c:box('EscapeRung', V(x1 - 2.2, ly, 2.3), V(x1 - 0.8, ly + 0.15, 2.5), rail, M.Plastic)) end
		end
		prev = y
	end
end

-- Balcony on a facade frame at x (w wide) with its floor at y: a stone slab with a darker edge, an iron railing (top
-- rail, posts) and a door-height window behind it is the wall's own window.
local function balcony(c, x, y, w)
	sbox(c, 'BalconySlab', V(x - w / 2, y - 0.6, -0.2), V(x + w / 2, y, 2.8), P.st.trim, true)
	sbox(c, 'BalconyEdge', V(x - w / 2 - 0.1, y - 0.9, 2.5), V(x + w / 2 + 0.1, y - 0.3, 3.0), P.st.trimDark, true)
	decor(c:box('BalconyRail', V(x - w / 2, y + 3, 2.5), V(x + w / 2, y + 3.35, 2.85), P.iron, M.Plastic))
	for _, ex in { x - w / 2, x + w / 2 - 0.3 } do decor(c:box('BalconyRail', V(ex, y + 3, 0), V(ex + 0.3, y + 3.35, 2.85), P.iron, M.Plastic)) end
	for bx = x - w / 2 + 0.6, x + w / 2 - 0.5, 1.0 do decor(c:box('BalconyBar', V(bx - 0.1, y, 2.55), V(bx + 0.1, y + 3, 2.75), P.iron, M.Plastic)) end
end

-- Red brick house of the reference street, built as a family with real variety: w along the facade, o.depth deep,
-- eave at o.h, in three brick tones (the wall, a darker plinth and thin darker courses every 2.5 studs wrapped round
-- the block), a slate band between the storeys and a stone cornice. Options:
--   o.roof = 'hip' (default) | 'gable' (ridge along the street) | 'gableFront' (gable facing it) | 'flat' (parapet)
--   o.pilasters = n: brick piers with stone caps cut the front into n bays, one window per bay and floor
--   o.bays / o.winW: evenly spaced front windows without piers; o.windows = { { face, x, w } } instead
--   o.entrance = { x =, kind = 'stoop' | 'porch' | 'door', door = Color3, number =, span = { x0, x1 } }: the ground-floor
--     window in its bay is left out
--   o.chimney = { x, z } on the roof; o.gutters (faces with an eave gutter and downpipes, default front, none on a
--   flat roof); o.ac = { { face, x, y } } air-con boxes; o.tags = { { face, x, y, text, color } } spray-painted tags.
local function brickBuilding(ctx, w, o)
	o = o or {}
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local d, ST = o.depth or DEPTH, P.street
	-- storeys: 15 studs each (the picture's two); o.floors 3-4 for the taller districts
	local floors = o.floors or 2
	local H = o.h or (floors == 2 and ST.eave or floors * 15)
	local sills, bands = {}, {}
	for f = 1, floors do
		table.insert(sills, f == 1 and ST.sills[1] or ST.sills[2] + (f - 2) * 15)
		if f >= 2 then table.insert(bands, ST.band + (f - 2) * 15) end
	end
	local wall = o.wall or P.st.brick
	local dark = wall:Lerp(P.black, 0.18)
	local roof = o.roof or 'hip'
	sbox(c, 'Wall', V(0, -1, -d), V(w, H, 0), wall)
	sbox(c, 'Plinth', V(-0.3, -1, -d - 0.3), V(w + 0.3, 2.4, 0.3), dark)
	for y = 4.9, H - 2, floors > 2 and 5 or 2.5 do -- (tall blocks: every other course, read from further away)
		local nearBand = false
		for _, b in bands do if math.abs(y - b) <= 1.6 then nearBand = true end end
		if not nearBand then decor(c:box('BrickCourse', V(-0.06, y, -d - 0.06), V(w + 0.06, y + 0.35, 0.06), dark:Lerp(wall, 0.35), M.Plastic)) end
	end
	for _, b in bands do sbox(c, 'Band', V(-0.5, b, -d - 0.5), V(w + 0.5, b + 1.2, 0.5), P.st.band, true) end
	sbox(c, 'Cornice', V(-0.6, H - 1.2, -d - 0.6), V(w + 0.6, H, 0.6), P.st.trim, true)
	local top = H + 1
	if roof == 'flat' then flatRoof(c, w, d, H, wall); top = H + 2.8
	elseif roof == 'gable' or roof == 'gableFront' then
		local rise = o.rise or (roof == 'gable' and d * 0.32 or w * 0.36)
		gableRoof(c, w, d, H, rise, roof == 'gable' and 'x' or 'z', wall)
		top = H + 1 + rise
	else hipRoof(c, 0, -d, w, 0, H, o.rise, o.run); top = H + 1 + (o.rise or 5) end
	if o.chimney then chimney(c, o.chimney[1], o.chimney[2], H, top + 3, wall) end
	-- Bays: piers at the bay lines (corner piers included), one window per bay and floor.
	local list = o.windows
	if not list then
		list = {}
		local n = o.pilasters or o.bays or math.max(1, math.floor(w / 22 + 0.5))
		local bw = w / n
		for k = 1, n do table.insert(list, { face = 'front', x = bw * (k - 0.5), w = o.winW or (o.pilasters and bw - 4.6 or math.min(16, bw - 6)) }) end
		if o.pilasters then
			for k = 0, n do
				local px = math.clamp(bw * k, 0.8, w - 0.8)
				sbox(c, 'Pilaster', V(px - 0.8, 2.4, 0), V(px + 0.8, H - 1.2, 0.6), wall:Lerp(P.black, 0.06))
				sbox(c, 'PilasterBase', V(px - 1.0, 0.6, 0), V(px + 1.0, 2.4, 0.9), dark, true)
				sbox(c, 'PilasterCap', V(px - 1.0, H - 2.2, 0), V(px + 1.0, H - 1.2, 0.9), P.st.trim, true)
			end
		end
	end
	local ent = o.entrance
	local function inShop(face, x, half)
		for _, sh in o.shops or {} do
			if (sh.face or 'front') == face and x + half > sh.x0 - 0.5 and x - half < sh.x1 + 0.5 then return true end
		end
		return false
	end
	for _, win in list do
		local f = faceFrame(c, win.face, w, d)
		for fl, y in sills do
			local skip = fl == 1 and ((ent and win.face == 'front' and math.abs(win.x - ent.x) < win.w / 2 + 3.5) or inShop(win.face, win.x, win.w / 2) or o.noGround)
			if not skip then window(f, win.x, y, { w = win.w, h = o.winH }) end
		end
	end
	if ent then entrance(c, ent.x, ent) end
	for _, sh in o.shops or {} do shopfront(faceFrame(c, sh.face or 'front', w, d), sh) end
	for _, fe in o.fireEscapes or {} do fireEscape(faceFrame(c, fe.face or 'front', w, d), fe.x, fe.w or 10, floors) end
	for _, b in o.balconies or {} do
		local f = faceFrame(c, b.face or 'front', w, d)
		for fl = 2, floors do balcony(f, b.x, sills[fl] - 0.8, b.w or 10) end
	end
	-- Gutters along the eave and a downpipe at each end of the face, with a kick-out shoe at the foot.
	for _, face in o.gutters or (roof == 'flat' and {} or { 'front' }) do
		local f, fw = faceFrame(c, face, w, d)
		sbox(f, 'Gutter', V(-1, H - 0.2, 1.0), V(fw + 1, H + 0.5, 1.8), P.st.gutter, true)
		for _, xp in { 1.4, fw - 1.4 } do
			sbox(f, 'Downpipe', V(xp - 0.25, 1.2, 0.6), V(xp + 0.25, H - 0.2, 1.1), P.st.gutter, true)
			sbox(f, 'DownpipeShoe', V(xp - 0.3, 0.4, 0.6), V(xp + 0.3, 1.2, 1.7), P.st.gutter, true)
		end
	end
	for _, a in o.ac or {} do
		local f = faceFrame(c, a[1], w, d)
		sbox(f, 'AirCon', V(a[2] - 1.6, a[3], 0), V(a[2] + 1.6, a[3] + 2.2, 1.8), C(206, 210, 216), true)
		decor(f:box('AirConGrille', V(a[2] - 1.3, a[3] + 0.3, 1.8), V(a[2] + 1.3, a[3] + 1.9, 1.9), C(120, 126, 136), M.Plastic))
		sbox(f, 'AirConBracket', V(a[2] - 1.2, a[3] - 0.4, 0), V(a[2] + 1.2, a[3], 1.4), P.st.gutter, true)
	end
	for _, t in o.tags or {} do
		local f = faceFrame(c, t[1], w, d)
		local plate = ghost(f:box('Tag', V(t[2] - 4, t[3], 0.02), V(t[2] + 4, t[3] + 3, 0.08), P.white, M.SmoothPlastic))
		local g = surface(plate, Enum.NormalId.Back, 24) -- (the plate's back faces out of the wall)
		line(g, 'Tag', t[4], t[5], FONT.tag, 0.02, 0.96, P.black, 3).Rotation = -6
	end
	model:SetAttribute('Floors', floors)
	return c, model
end

-- Blue corrugated warehouse with a roll-up door, a light bar and a side door.
local function warehouse(ctx, w, color)
	color = color or P.warehouse
	local c, model = ctx:group('Warehouse')
	local h = 22
	c:box('Wall', V(0, -1, -DEPTH), V(w, h, 0), color, M.SmoothPlastic)
	for x = 1.2, w - 1, 2.4 do decor(c:box('Ridge', V(x - 0.35, 0.5, 0), V(x + 0.35, h - 0.6, 0.25), color:Lerp(P.white, 0.14), M.SmoothPlastic)) end
	local roofBlue = color:Lerp(P.white, 0.25)
	c:box('Roof', V(-0.6, h, -DEPTH - 0.6), V(w + 0.6, h + 1, 1.2), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH / 4 + 0.15) * CFrame.Angles(0, math.pi, 0), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH * 3 / 4 - 0.15), roofBlue, M.SmoothPlastic)
	local dx = w * 0.42
	c:box('DoorFrame', V(dx - 8, 0, 0), V(dx + 8, 15.2, 0.4), P.warehouseDark, M.Metal)
	c:box('RollDoor', V(dx - 7, 0, 0), V(dx + 7, 14, 0.5), P.rollDoor, M.Metal)
	for y = 1, 13.5, 1.1 do decor(c:box('DoorSlat', V(dx - 7, y, 0.5), V(dx + 7, y + 0.14, 0.58), P.rollDoor:Lerp(P.black, 0.35), M.Metal)) end
	decor(c:box('LightBar', V(dx - 3, 16, 0), V(dx + 3, 16.6, 0.6), C(255, 210, 60), M.Neon))
	c:box('SideDoorFrame', V(w - 8.6, 0, 0), V(w - 3.4, 9, 0.35), P.warehouseDark, M.Metal)
	c:box('SideDoor', V(w - 8, 0, 0), V(w - 4, 8.2, 0.45), C(30, 56, 120), M.Metal)
	local lampBox = c:box('WallLamp', V(w - 7, 10.6, 0), V(w - 5, 11.4, 1.2), P.iron, M.Metal)
	decor(c:box('WallLampGlow', V(w - 6.8, 10.4, 0.2), V(w - 5.2, 10.6, 1.1), C(255, 230, 160), M.Neon))
	light(lampBox, C(255, 230, 160), 1, 12)
	model:SetAttribute('Floors', 2)
	return c
end

-- A lot of stacked shipping containers behind a low wall, crates out front (the yards' side "buildings").
local function containerLot(ctx, w, seed)
	local c = ctx:group('ContainerLot')
	c:box('LotFloor', V(0, -1, -DEPTH), V(w, 0.06, 0), C(176, 178, 184), M.Concrete)
	c:box('LotWall', V(0, -1, -DEPTH), V(w, 6, -DEPTH + 2), P.wall, M.Concrete)
	local colors = { P.containerBlue, P.containerRed, C(60, 150, 90), P.containerRed }
	local n = math.floor(w / 20)
	for k = 0, n - 1 do
		local x = (w - n * 20) / 2 + 10 + k * 20
		local h = (seed or 0) + k
		container(c, CFrame.new(x, 0.06, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[h % 4 + 1])
		if h % 2 == 0 then container(c, CFrame.new(x, 8.66, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 1) % 4 + 1]) end
		container(c, CFrame.new(x, 0.06, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 2) % 4 + 1])
		container(c, CFrame.new(x, 8.66, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 3) % 4 + 1])
	end
	for k, x in { 4, w * 0.45, w - 5 } do
		pallet(c, CFrame.new(x, 0.06, -3))
		crate(c, CFrame.new(x, 0.86, -3), 3)
		if k == 2 then crate(c, CFrame.new(x + 0.3, 3.86, -3.2) * CFrame.Angles(0, 0.25, 0), 2.6) end
	end
	-- Chain-link along the front with a gap, so it reads as a yard and not a wall.
	chainLink(c, V(0.3, 0.06, 0.3), V(w - 0.3, 0.06, 0.3), 8, { { w * 0.5 - 3, w * 0.5 + 3 } })
	return c
end
---------------------------------------------------------------------------------------------- lobby
-- World 1's spawn: the warehouse hall, after the user's two hall pictures (brief/ref1_hall_a.png, ref1_hall_b.png: the
-- shell, the floor, the light) laid out like the user's top-down lobby (brief/ref_lobby.png: one spine from the spawn to
-- the exit, the activities on both sides of it at the same distance, the dais at the back). Sized to what it holds
-- (BRIEF18: "make the warehouse smaller", no purposeless floor): 146 x 129 x 52 (was 240 x 180 x 70).
-- Built to BRIEF13/15's bar: every big surface in 2-3 tones, finished edges, base + body + cap on every object.
-- LOBBY3 (BRIEF20, the user's +1 references user_33-37): no empty floor. The floor is the reference's two-tone system:
-- ONE connected sand path network (studded, a 4-stud checker, chevrons from the spawn to the next goals) raised on a
-- saturated court-blue fill, every path edge stepped down through a dark blue border with pixel corners; everything
-- off the paths is a decorated court zone (Lobby.floorPlan, Lobby.fill).
-- The plan, on one grid (map frame, studs; north = -Z):
--   Spine:  x -6..6 from the Stage 1 door (z 6) to the shoe dais (z 100). The spawn is on it at the cross (0, 55).
--   Cross:  the cross arm z 46..64 (18 wide), from the armory's front step west into the training plaza's aisle.
--   Band:   z 15.8..94.2 (the armory's length): the training plaza (west, x -68..-19) and the armory (east, step foot
--           x 19, back block to the wall, its stockroom on top) stand in it, both 13 studs off the spine.
--   Zones:  the four court zones between the spine and the two activities, x +-(6..19), the band's halves either side
--           of the cross arm: planters, benches, hood clusters, floor graffiti (low inside the spawn's view of the door).
--   North:  the north walk along the exit wall: the doorway (WORLD 2 east of it, the FURTHEST kiosk and pad west of it),
--           the group chest in the NW corner bay, the codes terminal in the NE one.
--   South:  the 6-wide south walk past the band's end, the SHOE BOXES dais at the back centre (z 100..129.5), a hood
--           half-court in the SW corner, the three leaderboards in a V at the end of a spur in the SE corner.
--   Shell:  teal studded walls in three tones between layered grey pillars (a shade-tone body, lit face plates round a
--           recessed navy channel with a white neon strip, kinked like the reference's), recessed windows, wall lamps,
--           dark lattice girders springing from the pillars, long light bars. The shell casts no shadows.
-- Builders from other files (Stations, Armory) fill the slots; a missing or failing one leaves a labelled placeholder
-- box of the slot's size. Lobby.Slots: name -> CFrame in the map frame, filled by Lobby.build.
local Lobby = {}

Lobby.W = SPAWN_W - 1 -- interior half width, 73 (walls x +-73..+-74; c_layout's SPAWN_W is the outside face)
Lobby.N, Lobby.S = 6, SPAWN_TOP - 1 -- interior north and south faces (z 6, 135)
Lobby.SouthWalk = 6 -- the walk across the hall between the band's end and the dais's front step
Lobby.H = 52 -- ceiling
Lobby.Deck = SPAWN.Y -- the floor (0): the spawn stands on it
Lobby.CrossZ = SPAWN.Z -- where the cross arm meets the spine (55)
Lobby.Walk = 9 -- the cross arm's half width (18 wide: the aisle's width; the spine is Lobby.Spine)
Lobby.Gap = 19 -- the activities start this far either side of the spine's centre line (a court zone between)
Lobby.Band = 39.2 -- the activity band's half length along z (the armory's half width): z CrossZ +-39.2
Lobby.Door, Lobby.DoorH = 21.5, 30 -- the doorway's half width and height (gate 1's pillars outside are at x +-18..22)
Lobby.ExitEdge = 46.4 -- the exit bay frame's outer edge (x +-), see Lobby.exitBay
Lobby.Slots = {}
Lobby.SlotSizes = {}
-- Colours sampled from the reference frames (lit faces), set so our renders land on them.
Lobby.Colors = {
	walk = C(186, 188, 224), panel = C(149, 153, 191), band = C(88, 98, 146), cyan = C(84, 226, 250),
	wall = C(126, 183, 193), wallDark = C(104, 158, 174), pillar = C(134, 134, 160), channel = C(22, 30, 64),
	neon = C(240, 246, 255), frame = C(146, 154, 188), winFrame = C(18, 34, 72), winGlass = C(214, 244, 255),
	-- (LOBBY3: the ceiling a light steel blue, not navy: it was the darkest band in every high frame)
	truss = C(84, 104, 134), barHousing = C(74, 82, 108), ceiling = C(112, 148, 184), lamp = C(255, 252, 236),
	standTread = C(184, 188, 224), standRiser = C(128, 132, 170), standNose = C(214, 218, 240),
	checkDark = C(44, 48, 62), checkLight = C(214, 218, 232), dais = C(176, 182, 218), shelfDark = C(84, 90, 124),
	shelfLight = C(150, 156, 192), eggPad = C(38, 58, 124), sign = C(222, 226, 238), signFrame = C(150, 156, 186),
	hazard = C(250, 196, 32), gold = C(255, 204, 48), green = C(30, 140, 60), vent = C(152, 176, 210),
	-- the shades (BRIEF13): every big surface gets a lit tone, a shade tone and a darker or paler trim
	panelLight = C(161, 165, 203), pillarSide = C(100, 100, 128), pillarBase = C(88, 90, 118), trim = C(200, 204, 228),
	wallBand = C(150, 202, 210), wallBase = C(86, 130, 152), ceilingPanel = C(150, 186, 216), trussDark = C(72, 88, 118),
	glassTop = C(176, 226, 250), lampBack = C(48, 56, 80), sill = C(184, 190, 220),
}

---------------------------------------------------------------------------------------------- small kit
-- Box between two corners with studs on top (and on the sides when sides is true).
function Lobby.slab(c, name, a, b, color, sides)
	return studs(c:box(name, a, b, color, M.Plastic), sides)
end
-- A ParticleEmitter with a built-in texture (the renderer reads PreviewTexture for the intended look).
function Lobby.fx(part, name, tex, props)
	local builtin = { dust = 'rbxasset://textures/particles/sparkles_main.dds', smoke = 'rbxasset://textures/particles/smoke_main.dds',
		mist = 'rbxasset://textures/particles/smoke_main.dds', glitter = 'rbxasset://textures/particles/sparkles_main.dds',
		sparkle = 'rbxasset://textures/particles/sparkles_main.dds', ray = 'rbxasset://textures/glow.png', softglow = 'rbxasset://textures/glow.png' }
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Texture = builtin[tex] or builtin.softglow
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do (e :: any)[k] = v end
	e:SetAttribute('PreviewTexture', tex)
	e.Parent = part
	return e
end
function Lobby.seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
-- Invisible box particles spawn in.
function Lobby.emitBox(c, name, a, b)
	local p = ghost(c:box(name, a, b, P.white))
	p.CastShadow = false
	return p
end
-- Spinning / bobbing decor for WorldMotion.client (tag HoodMotion): spins round pivot's Y axis.
function Lobby.motion(model, pivot, spin, bob, period)
	model.WorldPivot = V2.Origin * pivot
	if spin then model:SetAttribute('Spin', spin) end
	if bob then model:SetAttribute('Bob', bob) end
	if period then model:SetAttribute('BobPeriod', period) end
	model:AddTag('HoodMotion')
	return model
end
-- A flat board whose front faces cf's LookVector, with text lines { name, text, color, font, y, h, stroke, thickness }.
function Lobby.board(c, name, cf, w, h, color, rows, ppS, mat)
	local b = c:part(name, V(w, h, 0.3), cf, color, mat or M.SmoothPlastic)
	local g = surface(b, Enum.NormalId.Front, ppS or 16)
	for _, r in rows or {} do line(g, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] or 3) end
	return b, g
end
-- Shaded stripes painted on one face of a part: every `pitch` studs a stripe `width` wide, vertical or horizontal,
-- in color at transparency alpha. len and ht are the face's width and height in studs.
function Lobby.stripes(part, face, len, ht, pitch, width, vertical, alpha, color)
	local g = surface(part, face, 8)
	g.Name = 'Stripes'
	local span = vertical and len or ht
	for k = 0, math.floor(span / pitch) - 1 do
		local f = Instance.new('Frame')
		f.Name = 'Stripe'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color or P.black
		f.BackgroundTransparency = alpha or 0.8
		local a, w = (k * pitch + (pitch - width) / 2) / span, width / span
		if vertical then f.Position, f.Size = UDim2.fromScale(a, 0), UDim2.fromScale(w, 1)
		else f.Position, f.Size = UDim2.fromScale(0, a), UDim2.fromScale(1, w) end
		f.Parent = g
	end
	return g
end
-- A ComingSoon prompt (the HUD toasts "<object> is coming soon!").
function Lobby.prompt(part, action, object, dist)
	local p = Instance.new('ProximityPrompt')
	p.Name = 'ComingSoon'
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = dist or 12
	p.RequiresLineOfSight = false
	p:SetAttribute('ComingSoon', true)
	p.Parent = part
	return p
end
-- A part placed by a world CFrame (for pieces built round another builder's model).
function Lobby.worldPart(parent, name, size, cf, color, material)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- A TrussPart lattice beam from a to b (Roblox and the previewer both take its long axis on Y).
function Lobby.truss(c, name, a, b, color)
	local t = Instance.new('TrussPart')
	t.Name = name
	t.Anchored = true
	t.Size = V(2, (b - a).Magnitude, 2)
	local mid = (a + b) / 2
	t.CFrame = V2.Origin * c.cf * CFrame.lookAt(mid, b) * CFrame.Angles(-math.pi / 2, 0, 0)
	t.Color = color
	t.Material = M.SmoothPlastic
	t.CastShadow = false
	t.Parent = c.parent
	return t
end
-- A floating title in the reference's style (big cyan words with a dark outline, a white line under it).
function Lobby.title(c, pos, w, h, text, sub, color, maxDist)
	local a = billboard(c, pos, w, h, {
		{ 'Title', text, color or C(70, 236, 230), FONT.loud, 0, sub and 0.6 or 1 },
		sub and { 'Sub', sub, P.white, FONT.title, 0.62, 0.36 } or nil,
	})
	a.WorldLabel.MaxDistance = maxDist or 200
	for _, t in a.WorldLabel:GetChildren() do
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then s.Color, s.Thickness = C(12, 40, 52), 3 end
	end
	return a
end

---------------------------------------------------------------------------------------------- shell
-- A wall pillar standing at pos on the wall's inner face, its front along normal: light grey studded, deep below
-- and slimmer above with a slanted kink between, a navy channel down the middle of its front with a white neon
-- strip in it that follows the kink. y0: where it starts (the armory's back block under an east pillar).
-- (Scaled with the hall: 10 wide, 3.5 deep below the kink at 16..21, 2 above.)
Lobby.PillarW, Lobby.PillarKink, Lobby.PillarD = 10, { 16, 21 }, { 3.5, 2 }
function Lobby.wallPillar(c, pos, normal, y0, w)
	local K, H = Lobby.Colors, Lobby.H
	w = w or Lobby.PillarW
	local k0, k1 = table.unpack(Lobby.PillarKink)
	local d0, d1 = table.unpack(Lobby.PillarD)
	local f = CFrame.lookAt(pos, pos + normal) -- local -Z points into the hall
	local yb = math.min(y0 or 0, Lobby.PillarKink[1] - 4) -- (a deck higher than that just buries the plinth)
	local function B(name, x0, ya, z0, x1, yt, z1, color, mat)
		return c:part(name, V(x1 - x0, yt - ya, z1 - z0), f * CFrame.new((x0 + x1) / 2, (ya + yt) / 2, (z0 + z1) / 2), color, mat or M.SmoothPlastic)
	end
	-- a part lying on the kink's slope (from the lower front plane at k0 to the upper one at k1), lifted off it
	local function slope(name, width, thick, lift, color, mat)
		local a, b = V(0, k0, -d0), V(0, k1, -d1)
		local nrm = V(0, d0 - d1, -(k1 - k0)).Unit * lift
		return c:part(name, V(width, thick, (b - a).Magnitude + 0.3), f * CFrame.lookAt((a + b) / 2 + nrm, b + nrm), color, mat or M.SmoothPlastic)
	end
	-- the body in the shade tone: its sides, and a rim round the front, read a step darker than the face
	studs(B('Pillar', -w / 2, yb, -d0, w / 2, k0, 0, K.pillarSide), true)
	studs(B('Pillar', -w / 2, k0, -d1, w / 2, H, 0, K.pillarSide), true)
	-- the slant: a wedge whose slope runs from the lower part's front top edge up to the upper part's face
	studs(c:wedge('PillarKink', V(w, k1 - k0, d0 - d1), f * CFrame.new(0, (k0 + k1) / 2, -(d0 + d1) / 2), K.pillarSide, M.Plastic), true)
	-- the lit face: two plates standing 0.4 proud, in from each edge, following the kink, with the channel between
	-- them; the navy channel lies back on the body and its white neon strip sits inside it (recessed, not stuck on)
	local e, pt = math.min(0.8, w * 0.08), 0.4
	local fb, ft = yb + 3, Lobby.H - 3 -- above the plinth, under the capital
	local cw, nw = 2, 0.9
	local pw = (w - 2 * e - cw) / 2 -- each face plate's width
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (cw / 2), sx * (cw / 2 + pw)
		local x0, x1 = math.min(xa, xb), math.max(xa, xb)
		studs(B('PillarFace', x0, fb, -d0 - pt, x1, k0, -d0, K.pillar), true)
		local sp = slope('PillarFace', pw, pt, pt / 2, K.pillar, M.Plastic)
		sp.CFrame = sp.CFrame * CFrame.new(sx * (cw / 2 + pw / 2), 0, 0)
		studs(sp, true)
		studs(B('PillarFace', x0, k1, -d1 - pt, x1, ft, -d1, K.pillar), true)
	end
	for _, s in { { 'PillarChannel', cw, 0.08, K.channel, M.SmoothPlastic }, { 'PillarNeon', nw, 0.22, K.neon, M.Neon } } do
		decor(B(s[1], -s[2] / 2, fb, -d0 - s[3], s[2] / 2, k0, -d0, s[4], s[5])).CastShadow = false
		decor(B(s[1], -s[2] / 2, k1, -d1 - s[3], s[2] / 2, ft, -d1, s[4], s[5])).CastShadow = false
		decor(slope(s[1], s[2], s[3], s[3] / 2, s[4], s[5])).CastShadow = false
	end
	-- the plinth (darker, a pale lip on top) and the capital where it meets the ceiling
	studs(B('PillarBase', -w / 2 - 0.5, yb, -d0 - 0.9, w / 2 + 0.5, fb - 0.4, 0, K.pillarBase), true)
	B('PillarBaseLip', -w / 2 - 0.7, fb - 0.4, -d0 - 1.1, w / 2 + 0.7, fb, 0, K.trim)
	studs(B('PillarCap', -w / 2 - 0.5, ft + 0.4, -d1 - 0.9, w / 2 + 0.5, Lobby.H, 0, K.pillarBase), true)
	B('PillarCapLip', -w / 2 - 0.7, ft, -d1 - 1.1, w / 2 + 0.7, ft + 0.4, 0, K.trim)
end
-- A big window: a thick navy frame, pale blue glass with two white glints, a navy transom near the top. cf sits on
-- the wall face at the window's centre, -Z into the hall.
-- The window is recessed: a THICK navy frame of four bars standing 1.2 proud of the wall, the glass set back on the
-- wall plane inside it (pale below a navy transom, a deeper blue top pane above it, two soft glint strokes), a pale
-- studded sill under it and a darker head over it.
function Lobby.window(c, cf, w, h)
	local K = Lobby.Colors
	local fw, fd = 1.5, 1.2
	local gw, gh = w - 2 * fw, h - 2 * fw
	for _, b in { { 0, h / 2 - fw / 2, w, fw }, { 0, -h / 2 + fw / 2, w, fw }, { -w / 2 + fw / 2, 0, fw, gh }, { w / 2 - fw / 2, 0, fw, gh } } do
		c:part('WindowFrame', V(b[3], b[4], fd), cf * CFrame.new(b[1], b[2], -fd / 2), K.winFrame, M.SmoothPlastic)
	end
	c:part('WindowGlass', V(gw, gh, 0.2), cf * CFrame.new(0, 0, -0.12), K.winGlass, M.SmoothPlastic)
	c:part('WindowGlassTop', V(gw, gh * 0.3, 0.06), cf * CFrame.new(0, gh / 2 - gh * 0.15, -0.25), K.glassTop, M.SmoothPlastic)
	c:part('WindowTransom', V(gw, 1.0, 0.7), cf * CFrame.new(0, gh / 2 - gh * 0.3, -0.35), K.winFrame, M.SmoothPlastic)
	for _, g in { { -w * 0.16, 2.4, 0.5 }, { w * 0.1, 1.1, 0.4 } } do
		local s = decor(c:part('WindowGlint', V(g[2], h * g[3], 0.05), cf * CFrame.new(g[1], -h * 0.14, -0.28) * CFrame.Angles(0, 0, math.rad(-38)), P.white, M.SmoothPlastic))
		s.CastShadow, s.Transparency = false, 0.6
	end
	-- finished edges: a pale studded sill under it and a darker head over it
	studs(c:part('WindowSill', V(w + 1.6, 0.9, 1.9), cf * CFrame.new(0, -h / 2 - 0.4, -0.95), K.sill, M.Plastic))
	c:part('WindowHead', V(w + 1, 0.7, 1.5), cf * CFrame.new(0, h / 2 + 0.35, -0.75), K.winFrame:Lerp(P.black, 0.25), M.SmoothPlastic)
end
-- A small wall lamp: a dark back plate and a glowing lens tipped down a little.
function Lobby.wallLamp(c, cf)
	decor(c:part('WallLampBack', V(3.8, 1.6, 0.4), cf * CFrame.new(0, 0, -0.2), Lobby.Colors.lampBack, M.SmoothPlastic)).CastShadow = false
	decor(c:part('WallLamp', V(3, 0.9, 0.45), cf * CFrame.new(0, 0.05, -0.6) * CFrame.Angles(math.rad(-14), 0, 0), Lobby.Colors.lamp, M.Neon)).CastShadow = false
end
-- The hall: floor slab, the four walls (the north one with the doorway), pillars, windows, lamps, the ceiling,
-- the trusses and the light bars. The bays run on one rhythm: side-wall pillars every 26 studs either side of the
-- cross arm (the middle one on each side wall is on the cross arm's axis: the RANGES sign hangs on the west one, the
-- ARMORY title floats over the east one; none straddles an end of the armory's back block), back-wall pillars every 24 from the centre one (the SHOE BOXES sign's), the
-- north wall's corner bays either side of the exit bay; a window and two lamps in every bay; the cross girders span
-- from pillar to pillar, the long ones run north-south between the light-bar columns.
Lobby.SidePillars = { 29, 55, 81, 107 } -- along the side walls (z): CrossZ +-26, +52, plus the corners
Lobby.BackPillars = { -48, -24, 0, 24, 48 } -- along the back wall (x): three 14-wide bays a side
Lobby.BarRows = { 29, 55, 81, 107 } -- cross girders and light-bar rows (z), on the side pillars
Lobby.BarCols = { -37.5, -12.5, 12.5, 37.5 } -- long girders and light-bar centres (x)
Lobby.WinY, Lobby.WinH = 31, 18 -- windows y 22..40
function Lobby.hall(L)
	local K, W, N, S, H = Lobby.Colors, Lobby.W, Lobby.N, Lobby.S, Lobby.H
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local h = L:group('Hall')
	Lobby.slab(h, 'Floor', V(-W - 1, -1, N - 1), V(W + 1, 0, S + 1), Lobby.Floor.court) -- the court: the fill between the paths
	local function wall(a, b) return Lobby.slab(h, 'Wall', a, b, K.wall, true) end
	wall(V(-W - 1, 0, N - 1), V(-W, H, S + 1))
	wall(V(W, 0, N - 1), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, S), V(W + 1, H, S + 1))
	wall(V(-W - 1, 0, N - 1), V(-Dw, H, N))
	wall(V(Dw, 0, N - 1), V(W + 1, H, N))
	wall(V(-Dw, DH, N - 1), V(Dw, H, N))
	-- the walls' finish in three tones: a darker studded base band with a pale lip along the floor, the teal wall,
	-- and a lighter cap band under the ceiling over a pale cornice (the exit bay's panels keep the north band off the
	-- middle). strip() is a box on one wall's inner face, u along the wall.
	local function strip(name, side, u0, u1, y0, y1, depth, color, mat)
		local a, b
		if side == 'west' then a, b = V(-W, y0, u0), V(-W + depth, y1, u1)
		elseif side == 'east' then a, b = V(W - depth, y0, u0), V(W, y1, u1)
		elseif side == 'south' then a, b = V(u0, y0, S - depth), V(u1, y1, S)
		else a, b = V(u0, y0, N), V(u1, y1, N + depth) end
		return h:box(name, a, b, color, mat or M.SmoothPlastic)
	end
	local edge = Lobby.ExitEdge
	local runs = { { 'west', N, S }, { 'east', N, S }, { 'south', -W, W }, { 'north', -W, -edge }, { 'north', edge, W } }
	for _, r in runs do
		studs(strip('WallBase', r[1], r[2], r[3], 0, 4, 0.35, K.wallBase), true)
		strip('WallBaseLip', r[1], r[2], r[3], 4, 4.5, 0.65, K.trim)
		strip('WallKick', r[1], r[2], r[3], 0, 0.8, 0.5, K.pillarBase)
	end
	local bandY = 45
	for _, r in runs do
		studs(strip('WallBand', r[1], r[2], r[3], bandY, H, 0.2, K.wallBand), true)
		strip('WallCornice', r[1], r[2], r[3], bandY - 1, bandY, 0.75, K.trim)
	end
	-- wall frames: cf on the inner face at (u along the wall, y), -Z into the hall
	local function west(u, y) return CFrame.lookAt(V(-W, y, u), V(-W + 1, y, u)) end
	local function east(u, y) return CFrame.lookAt(V(W, y, u), V(W - 1, y, u)) end
	local function south(u, y) return CFrame.lookAt(V(u, y, S), V(u, y, S - 1)) end
	local function north(u, y) return CFrame.lookAt(V(u, y, N), V(u, y, N + 1)) end
	-- pillars: the side walls, the back wall, the four corners (half pillars, one on each wall). An east pillar that
	-- stands where the armory's back block meets the east wall starts on the block: Lobby.eastDeckTop(z) gives the
	-- block's top at z (nil where a pillar's plinth would not stand whole on it; the side pillars are spaced so none
	-- straddles one of its ends).
	for _, z in Lobby.SidePillars do
		Lobby.wallPillar(h, V(-W, 0, z), V(1, 0, 0))
		local ok, deck = pcall(function() return Lobby.eastDeckTop and Lobby.eastDeckTop(z) end)
		Lobby.wallPillar(h, V(W, 0, z), V(-1, 0, 0), ok and type(deck) == 'number' and deck > 0 and deck or nil)
	end
	for _, x in Lobby.BackPillars do Lobby.wallPillar(h, V(x, 0, S), V(0, 0, -1)) end
	for _, sx in { -1, 1 } do
		Lobby.wallPillar(h, V(sx * (W - 3), 0, S), V(0, 0, -1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, S - 3), V(-sx, 0, 0), nil, 6)
		Lobby.wallPillar(h, V(sx * (W - 3), 0, N), V(0, 0, 1), nil, 6)
		Lobby.wallPillar(h, V(sx * W, 0, N + 3), V(-sx, 0, 0), nil, 6)
	end
	-- a window in every bay between two pillars (centred in the bay), a lamp over it and one under it; the east wall's
	-- low lamps are left off where the armory's back block stands against it
	local wy, wh = Lobby.WinY, Lobby.WinH
	local function bay(f, u, w, low)
		Lobby.window(h, f(u, wy), w, wh)
		Lobby.wallLamp(h, f(u, wy + wh / 2 + 2))
		if low ~= false then Lobby.wallLamp(h, f(u, 14)) end
	end
	local sides = { N, table.unpack(Lobby.SidePillars) }
	table.insert(sides, S)
	for i = 1, #sides - 1 do
		local a = sides[i] + (i == 1 and 6 or Lobby.PillarW / 2)
		local b = sides[i + 1] - (i == #sides - 1 and 6 or Lobby.PillarW / 2)
		local u, w = (a + b) / 2, math.min(11, b - a - 3)
		bay(west, u, w)
		bay(east, u, w, math.abs(u - Lobby.CrossZ) > Lobby.Band + 2) -- (no low lamp behind the armory's back block)
	end
	-- the back wall: windows in the outer bays; the two bays beside the centre pillar carry its SHOE BOXES sign, so
	-- they get lamps only
	local backs = { -W, table.unpack(Lobby.BackPillars) }
	table.insert(backs, W)
	for i = 1, #backs - 1 do
		local a = backs[i] + (i == 1 and 6 or Lobby.PillarW / 2)
		local b = backs[i + 1] - (i == #backs - 1 and 6 or Lobby.PillarW / 2)
		local u = (a + b) / 2
		if math.abs(u) < 20 then
			Lobby.wallLamp(h, south(u, wy + wh / 2 + 2))
			Lobby.wallLamp(h, south(u, 14))
		else
			bay(south, u, math.min(11, b - a - 3))
		end
	end
	-- the north wall's corner bays, between the exit bay's frame and the corner pillars: their notice boards hang where
	-- a window would be (Lobby.northBays), a lamp over each
	for _, sx in { -1, 1 } do
		Lobby.wallLamp(h, north(sx * (Lobby.ExitEdge + W - 6) / 2, wy + wh / 2 + 2))
	end
	Lobby.exitBay(h)
	-- Roof: the ceiling, girders along and across the hall, long light bars hung on wires under the cross girders.
	-- Everything up here is named Roof* (the plan view hides it).
	local r = L:group('Roof')
	r:box('RoofCeiling', V(-W - 1, H, N - 1), V(W + 1, H + 1, S + 1), K.ceiling, M.SmoothPlastic).CastShadow = false
	-- paler ceiling panels between the girders (the ceiling reads in two tones, the girders dark against it)
	local xs, zs = { -W }, { N }
	for _, x in Lobby.BarCols do table.insert(xs, x) end
	for _, z in Lobby.BarRows do table.insert(zs, z) end
	table.insert(xs, W)
	table.insert(zs, S)
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local x0, x1 = xs[i] + (i > 1 and 3 or 1), xs[i + 1] - (i < #xs - 1 and 3 or 1)
			local z0, z1 = zs[j] + (j > 1 and 3 or 1), zs[j + 1] - (j < #zs - 1 and 3 or 1)
			r:box('RoofPanel', V(x0, H - 0.4, z0), V(x1, H, z1), K.ceilingPanel, M.SmoothPlastic).CastShadow = false
		end
	end
	local ty = H - 10
	-- deep see-through lattice girders: two TrussParts (2 x 2 each) stacked, the long ones under the cross ones, dark
	-- against the paler ceiling panels; the long ones end on mounting plates on the end walls, the cross ones spring
	-- from the side pillars' capitals
	for _, x in Lobby.BarCols do
		for _, o in { { 0, 1 }, { 0, 3 } } do
			Lobby.truss(r, 'RoofTruss', V(x + o[1], ty + o[2], N), V(x + o[1], ty + o[2], S), K.trussDark)
		end
		for _, z in { N, S } do
			local s = z == N and 1 or -1
			r:box('RoofMount', V(x - 3.5, ty - 1.5, z), V(x + 3.5, ty + 5.5, z + s * 1.2), K.pillarBase, M.SmoothPlastic).CastShadow = false
		end
	end
	for _, z in Lobby.BarRows do
		for _, o in { { 0, 5 }, { 0, 7 } } do
			Lobby.truss(r, 'RoofTruss', V(-W, ty + o[2], z + o[1]), V(W, ty + o[2], z + o[1]), K.trussDark)
		end
	end
	-- the light bars: a dark studded housing, a pale rim and the glowing tube under it, on two wires
	for _, z in Lobby.BarRows do
		for _, x in Lobby.BarCols do
			local y = ty - 6
			studs(r:box('RoofLampBar', V(x - 10, y, z - 1.6), V(x + 10, y + 1, z + 1.6), K.barHousing, M.Plastic), true).CastShadow = false
			decor(r:box('RoofLampRim', V(x - 10.3, y - 0.3, z - 1.9), V(x + 10.3, y, z + 1.9), K.trim, M.SmoothPlastic)).CastShadow = false
			local tube = decor(r:box('RoofLampTube', V(x - 9.7, y - 0.45, z - 1.3), V(x + 9.7, y - 0.3, z + 1.3), K.neon, M.Neon))
			tube.CastShadow = false
			-- a soft cool glow round each bar that lights the ceiling, the girders and the upper walls but stops well
			-- above the floor (light17: Studio washed the floor out to white when the bars reached it)
			light(tube, C(232, 240, 255), 0.6, 26)
			for _, dx in { -8.5, 8.5 } do decor(r:box('RoofLampWire', V(x + dx - 0.08, y + 1, z - 0.08), V(x + dx + 0.08, ty + 4, z + 0.08), C(40, 44, 56), M.SmoothPlastic)).CastShadow = false end
		end
	end
	-- The shell lets the sun in, like the reference's bright, nearly shadowless interior: the walls, their bands, the
	-- pillars and the whole roof cast no shadows (so the roof doesn't make the hall an indoor, Ambient-only space and
	-- the walls don't throw shade over the plaza); window frames, sills, the exit bay and the objects in the hall still
	-- cast, so their depth reads.
	-- (light17 kept this on purpose: Roblox clamps OutdoorAmbient to >= Ambient, so a sun-blocking roof would leave the
	-- hall at best as bright as the streets' shade. HoodSun's calibrated sun lights it like the reference.)
	for _, grp in { h.parent, r.parent } do
		for _, p in grp:GetDescendants() do
			if p:IsA('BasePart') and (grp == r.parent or string.find(p.Name, '^Wall') or string.find(p.Name, '^Pillar')) then p.CastShadow = false end
		end
	end
	return h
end

---------------------------------------------------------------------------------------------- exit bay
-- The north wall's centre: a grey framed recess (x +-43, 36 high) round the open doorway (x +-21.5, 30 high) onto the
-- Stage 1 street, two framed panels over the recess, white neon lines under and between them. Nothing in the doorway:
-- from the spawn you look straight down the street at gate 1 and the locked gates beyond it (GATES2's sightline), and
-- no text floats over it (gate 1's own sign is the goal). Inside the recess, east of the door: the WORLD 2 door.
function Lobby.exitBay(h)
	local K, N = Lobby.Colors, Lobby.N
	local Dw, DH = Lobby.Door, Lobby.DoorH
	local e = h:group('ExitBay')
	local RX, RH, fw = 43, 36, 3.4
	-- the recess's back is the wall, a shade darker inside the frame
	for _, seg in { { -RX, -Dw - 2 }, { Dw + 2, RX } } do e:box('ExitRecess', V(seg[1], 0, N), V(seg[2], RH, N + 0.12), K.wallDark, M.SmoothPlastic) end
	e:box('ExitRecess', V(-Dw - 2, DH + 2, N), V(Dw + 2, RH, N + 0.12), K.wallDark, M.SmoothPlastic)
	-- the frame (grey, standing 1.6 proud) and its white neon outline
	for _, sx in { -1, 1 } do
		local a, b = sx * RX, sx * (RX + fw)
		studs(e:box('ExitFrame', V(math.min(a, b), 0, N), V(math.max(a, b), RH + fw, N + 1.6), K.frame, M.Plastic), true)
	end
	studs(e:box('ExitFrame', V(-RX - fw, RH, N), V(RX + fw, RH + fw, N + 1.6), K.frame, M.Plastic), true)
	-- the doorway's own frame
	for _, sx in { -1, 1 } do
		local a, b = sx * Dw, sx * (Dw + 2)
		e:box('DoorJamb', V(math.min(a, b), 0, N), V(math.max(a, b), DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	end
	e:box('DoorHead', V(-Dw - 2, DH, N), V(Dw + 2, DH + 2, N + 0.9), K.frame, M.SmoothPlastic)
	-- (no glass in the doorway any more: Studio's Glass greyed the street and halved the gates' contrast. GATES2.)
	-- two framed panels over the recess
	local py0, py1 = RH + fw + 1.2, Lobby.H - 2.5
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * 1.6, sx * RX
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		e:box('ExitPanel', V(lo, py0, N), V(hi, py1, N + 0.12), K.wallDark, M.SmoothPlastic)
		for _, ed in { { V(lo, py0, N), V(hi, py0 + 1.6, N + 1.2) }, { V(lo, py1 - 1.6, N), V(hi, py1, N + 1.2) }, { V(lo, py0, N), V(lo + 1.6, py1, N + 1.2) }, { V(hi - 1.6, py0, N), V(hi, py1, N + 1.2) } } do
			studs(e:box('ExitPanelFrame', ed[1], ed[2], K.frame, M.Plastic), true)
		end
	end
	local function neon(a, b) decor(e:box('ExitNeon', a, b, K.neon, M.Neon)).CastShadow = false end
	neon(V(-RX - fw, RH + fw, N + 1.2), V(RX + fw, RH + fw + 0.7, N + 1.6)) -- under the panels
	neon(V(-0.4, RH + fw, N + 0.3), V(0.4, py1, N + 0.9)) -- between them
	for _, sx in { -1, 1 } do
		local a, b = sx * (RX + fw), sx * (RX + fw - 0.6)
		neon(V(math.min(a, b), 0.4, N + 1.6), V(math.max(a, b), RH + fw + 0.7, N + 1.9)) -- up the frame's outer edges
	end
	Lobby.world2(e, CFrame.lookAt(V(33.25, 0, N + 0.3), V(33.25, 0, N + 10)))
	return e
end
-- WORLD 2, the reference's green coming-soon door, built up in layers: a dark studded step with a pale nosing; black
-- arch posts on grey plinths with red caps; the red-and-black block arch with a gold keystone; a green door (a darker
-- frame round two paler panels, the lettering on them, a round top) behind a big gold padlock; a green glow round it.
-- In front, "closed" props: two traffic cones and a striped sawhorse. Front -Z of cf's frame faces the hall (cf: the
-- centre bottom of the door on the recess back).
function Lobby.world2(e, cf)
	local K = Lobby.Colors
	local p, model = e:at(cf):group('World2Portal')
	local dw, dh, ar, st = 6.4, 17, 9.2, 0.6 -- door half width, spring line, arch outer radius, step height
	local black, red, green = C(28, 30, 36), C(196, 24, 30), K.green
	-- the step
	Lobby.slab(p, 'World2Step', V(-dw - 2.8, 0, -4.6), V(dw + 2.8, st, 0), C(62, 66, 88), true)
	p:box('World2StepNosing', V(-dw - 2.8, st - 0.12, -4.75), V(dw + 2.8, st + 0.04, -4.2), K.trim, M.SmoothPlastic)
	-- the posts: a grey plinth, the black post, a red cap at the spring line
	for _, sx in { -1, 1 } do
		local x0, x1 = sx > 0 and dw or -dw - 2.8, sx > 0 and dw + 2.8 or -dw
		Lobby.slab(p, 'ArchPlinth', V(x0 - 0.2, st, -2.6), V(x1 + 0.2, st + 2.2, 0), K.pillarBase, true)
		p:box('ArchPost', V(x0, st + 2.2, -2.2), V(x1, dh, 0), black, M.SmoothPlastic)
		p:box('ArchCap', V(x0 - 0.2, dh - 0.9, -2.5), V(x1 + 0.2, dh, 0), red, M.SmoothPlastic)
	end
	local n = 11
	for k = 0, n - 1 do
		local a = math.pi * (k + 0.5) / n
		local r0 = (dw + ar) / 2
		local cfk = CFrame.new(math.cos(a) * r0, dh + math.sin(a) * r0, -1.1) * CFrame.Angles(0, 0, a)
		p:part('ArchBlock', V(ar - dw, 2.9, 2.2), cfk, k % 2 == 0 and red or C(26, 26, 30), M.SmoothPlastic)
	end
	p:box('ArchKeystone', V(-1.5, dh + ar - 1.2, -2.6), V(1.5, dh + ar + 0.6, 0), K.gold, M.SmoothPlastic)
	-- the green glow behind, the door with its round top in front of it
	local glow = decor(p:box('World2Glow', V(-dw - 3, 0, -0.5), V(dw + 3, dh + ar - 1, -0.2), C(90, 255, 140), M.Neon))
	glow.Transparency, glow.CastShadow = 0.55, false
	light(glow, C(120, 255, 150), 2, 22)
	p:box('World2Door', V(-dw, st, -1.8), V(dw, dh, -0.8), green:Lerp(P.black, 0.18), M.SmoothPlastic)
	p:part('World2DoorTop', V(1, 2 * dw, 2 * dw), CFrame.new(0, dh, -1.3) * CFrame.Angles(0, math.pi / 2, 0), green:Lerp(P.black, 0.18), M.SmoothPlastic, Enum.PartType.Cylinder)
	local top = p:box('World2Panel', V(-dw + 1, dh * 0.52, -1.95), V(dw - 1, dh - 0.4, -1.8), green, M.SmoothPlastic)
	local low = p:box('World2Panel', V(-dw + 1, st + 1, -1.95), V(dw - 1, dh * 0.5 - 0.6, -1.8), green, M.SmoothPlastic)
	local g = surface(top, Enum.NormalId.Front, 14)
	line(g, 'Soon', 'COMING SOON', C(255, 214, 60), FONT.loud, 0.08, 0.3, C(40, 30, 0), 2)
	line(g, 'World', 'WORLD 2', P.white, FONT.loud, 0.44, 0.44, C(10, 50, 20), 3)
	line(surface(low, Enum.NormalId.Front, 14), 'Detail', 'Beat the Boss Yard\nto unlock!', C(220, 255, 220), FONT.title, 0.62, 0.32, C(10, 50, 20), 1)
	-- the padlock over the panels' join: a gold body with a keyhole, a darker shackle
	p:box('World2Lock', V(-1.5, dh * 0.5 - 1.6, -2.6), V(1.5, dh * 0.5 + 0.8, -1.9), K.gold, M.SmoothPlastic)
	p:box('World2Keyhole', V(-0.25, dh * 0.5 - 1.0, -2.65), V(0.25, dh * 0.5 + 0.1, -2.58), C(60, 40, 10), M.SmoothPlastic)
	local sh = K.gold:Lerp(P.black, 0.3)
	for _, sx in { -1, 1 } do p:box('World2Shackle', V(sx * 0.95 - 0.3, dh * 0.5 + 0.8, -2.4), V(sx * 0.95 + 0.3, dh * 0.5 + 2.4, -2.0), sh, M.SmoothPlastic) end
	p:box('World2Shackle', V(-1.25, dh * 0.5 + 2.4, -2.4), V(1.25, dh * 0.5 + 2.9, -2.0), sh, M.SmoothPlastic)
	-- closed: two cones and a striped sawhorse in front of the step
	for _, sx in { -1, 1 } do
		local cc = p:at(CFrame.new(sx * (dw + 2.6), 0, -6.2))
		cc:box('ConeBase', V(-0.9, 0, -0.9), V(0.9, 0.3, 0.9), C(40, 42, 50), M.SmoothPlastic)
		cc:post('Cone', 0.7, 1.4, V(0, 0.3, 0), C(255, 120, 30), M.SmoothPlastic)
		cc:post('ConeBand', 0.55, 0.4, V(0, 1.7, 0), P.white, M.SmoothPlastic)
		cc:post('ConeTip', 0.38, 0.6, V(0, 2.1, 0), C(255, 120, 30), M.SmoothPlastic)
	end
	for _, sx in { -1, 1 } do
		p:part('SawhorseLeg', V(0.3, 2.4, 1.4), CFrame.new(sx * 3.2, 1.1, -6.6) * CFrame.Angles(math.rad(14), 0, 0), C(60, 62, 70), M.SmoothPlastic)
	end
	local bar = p:box('SawhorseBar', V(-4, 1.7, -6.85), V(4, 2.5, -6.45), P.white, M.SmoothPlastic)
	Lobby.stripes(bar, Enum.NormalId.Front, 8, 0.8, 1.6, 0.8, true, 0, C(220, 40, 40))
	local zone = p:box('World2Gate', V(-dw, 0, -6), V(dw, 6, -2), P.white)
	zone.Transparency, zone.CanCollide = 1, false
	Lobby.prompt(zone, 'Locked', 'World 2')
	Lobby.Slots.World2Portal = cf
	return model
end

---------------------------------------------------------------------------------------------- floor
-- LOBBY3 (BRIEF20, the user's +1 references user_33-37): the floor is two tones, like the reference's sand paths in
-- blue water. The hall slab is the FILL, a saturated studded court blue. On it, ONE connected PATH network in warm
-- sand, raised 0.3 and studded: the north walk along the exit wall (the door, FURTHEST,
-- WORLD 2, the chest, the codes), the spine (door -> spawn -> shoe dais), the cross arm (armory front -> spawn -> the
-- plaza's aisle -> every lane), the south walk (the dais front, both back corners) and a spur to the leaderboards.
-- The activity islands (plaza, armory, dais) count as path for the edges. Every edge where path meets court gets the
-- reference's darker stepped border: a dark blue band two studs wide and 0.15 high (sand 0.3 -> border 0.15 ->
-- court 0 reads as two steps), and every inside corner of a court zone is stepped in pixels (two 1-stud steps of sand
-- fill the corner) instead of a sharp right angle. Chevrons in a darker sand point from the spawn to the door, to
-- BAY 1, to the armory and to the shoe boxes. The court zones between the paths carry the fill (Lobby.fill).
-- The plan is rasterised on a 1-stud grid (cell i, j = x -W + i, z N + j); path and border cells are merged into
-- as few rectangles as possible.
Lobby.Spine = 6 -- the spine's half width (12 wide; the cross arm keeps the aisle's 18)
Lobby.Floor = {
	path = C(240, 216, 150), pathTile = C(228, 200, 130), chevron = C(214, 182, 108), sill = C(226, 200, 132),
	court = C(46, 150, 230), courtTile = C(62, 164, 240), border = C(22, 92, 182), courtLine = C(236, 246, 255), courtKey = C(84, 178, 246),
	H = 0.3, B = 0.15, -- the path's and the border's tops
}
-- The path network and the islands (x0, x1, z0, z1 in the map frame).
function Lobby.pathRects()
	local W, N, S, Z, wk = Lobby.W, Lobby.N, Lobby.S, Lobby.CrossZ, Lobby.Walk
	local b0, b1 = Z - Lobby.Band, Z + Lobby.Band
	local D, sp = Lobby.Dais, Lobby.Spine
	local front = D.Z0 - 1.3 -- the dais's front step
	local r = {
		{ -W, W, N, b0 }, -- the north walk, door to both corners
		{ -sp, sp, b0, front }, -- the spine
		{ -Lobby.Gap, Lobby.Gap, Z - wk, Z + wk }, -- the cross arm
		{ -W, W, b1, front }, -- the south walk
		{ -W, Lobby.Plaza.x0, b0, b1 }, -- along the west wall behind the plaza (the pillars' feet)
		{ -D.X, D.X, front, D.Z0 + 4.5 }, -- under the dais's chamfered front corners
		{ -D.X, D.X, D.Z1, S }, -- behind the dais
	}
	local B = Lobby.BoardSpur
	table.insert(r, { B.x0, B.x1, front, B.z1 })
	return r
end
function Lobby.islandRects()
	local Z, Pz, D = Lobby.CrossZ, Lobby.Plaza, Lobby.Dais
	return {
		{ Pz.x0, Pz.x1, Pz.z0, Pz.z1 }, -- the training plaza
		{ Lobby.Gap, Lobby.W, Z - Lobby.Band, Z + Lobby.Band }, -- the armory (front step to the east wall)
		{ -D.X, D.X, D.Z0 - 1.3, Lobby.S }, -- the shoe dais
	}
end
-- Merge the cells of a mask (set of j * nx + i) into rectangles { i0, i1, j0, j1 } (greedy: runs along x, grown in z).
function Lobby.mergeCells(mask, nx, nz)
	local used, out = {}, {}
	for j = 0, nz - 1 do
		local i = 0
		while i < nx do
			local k = j * nx + i
			if mask[k] and not used[k] then
				local i1 = i
				while i1 + 1 < nx and mask[k + i1 + 1 - i] and not used[k + i1 + 1 - i] do i1 += 1 end
				local j1 = j
				while j1 + 1 < nz do
					local ok = true
					for ii = i, i1 do
						local kk = (j1 + 1) * nx + ii
						if not mask[kk] or used[kk] then ok = false break end
					end
					if not ok then break end
					j1 += 1
				end
				for jj = j, j1 do for ii = i, i1 do used[jj * nx + ii] = true end end
				table.insert(out, { i, i1, j, j1 })
				i = i1 + 1
			else
				i += 1
			end
		end
	end
	return out
end
-- The plan as cell sets: path (sand to lay), walk (path + islands), border (the dark band). Cached per build.
function Lobby.floorCells()
	local W, N, S = Lobby.W, Lobby.N, Lobby.S
	local nx, nz = math.floor(2 * W + 0.5), math.floor(S - N + 0.5)
	local path, walk = {}, {}
	local function fill(rects, into)
		for _, r in rects do
			for j = 0, nz - 1 do
				local cz = N + j + 0.5
				if cz > r[3] and cz < r[4] then
					for i = 0, nx - 1 do
						local cx = -W + i + 0.5
						if cx > r[1] and cx < r[2] then into[j * nx + i] = true end
					end
				end
			end
		end
	end
	fill(Lobby.pathRects(), path)
	for k in path do walk[k] = true end
	fill(Lobby.islandRects(), walk)
	local function at(m, i, j) return i >= 0 and i < nx and j >= 0 and j < nz and m[j * nx + i] == true end
	-- step the court zones' inside corners: a court cell with walk on two sides becomes sand (twice: two 1-stud steps)
	for _ = 1, 2 do
		local add = {}
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				local k = j * nx + i
				if not walk[k] then
					local n, s, e, w = at(walk, i, j - 1), at(walk, i, j + 1), at(walk, i + 1, j), at(walk, i - 1, j)
					if (n or s) and (e or w) or (n and s) or (e and w) then table.insert(add, k) end
				end
			end
		end
		for _, k in add do walk[k], path[k] = true, true end
	end
	-- the border: court cells within two cells (any direction) of walk or of a wall
	local border = {}
	local function near(i, j, m)
		for dj = -1, 1 do
			for di = -1, 1 do
				local ii, jj = i + di, j + dj
				if ii < 0 or ii >= nx or jj < 0 or jj >= nz or m[jj * nx + ii] then return true end
			end
		end
		return false
	end
	local ring1 = {}
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local k = j * nx + i
			if not walk[k] and near(i, j, walk) then ring1[k] = true end
		end
	end
	local both = table.clone(walk)
	for k in ring1 do both[k] = true; border[k] = true end
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local k = j * nx + i
			if not both[k] and near(i, j, both) then border[k] = true end
		end
	end
	return { nx = nx, nz = nz, path = path, walk = walk, border = border }
end
-- A row of n chevrons on a path top, pointing along dir (a unit vector on XZ): the first tip (nearest the goal) at
-- `tip`, the next ones `gap` back, each `w` wide; two bars each in the darker sand, lying on the path.
function Lobby.chevrons(c, tip, dir, n, gap, w)
	local F = Lobby.Floor
	local side = V(-dir.Z, 0, dir.X)
	for k = 0, n - 1 do
		local t = tip - dir * (k * gap)
		for _, s in { -1, 1 } do
			local tail = t - dir * (w * 0.42) + side * (s * w / 2)
			local a = t + (tail - t).Unit * 0.5
			decor(c:part('PathChevron', V(1.1, 0.12, (a - tail).Magnitude + 1.1), CFrame.lookAt((a + tail) / 2, a), F.chevron, M.SmoothPlastic)).CastShadow = false
		end
	end
end
function Lobby.floorPlan(L)
	local F, W, N = Lobby.Floor, Lobby.W, Lobby.N
	local f = L:group('FloorPlan')
	local cells = Lobby.floorCells()
	Lobby.Cells = cells
	local nx, nz = cells.nx, cells.nz
	for _, r in Lobby.mergeCells(cells.path, nx, nz) do
		local x0, x1, z0, z1 = -W + r[1], -W + r[2] + 1, N + r[3], N + r[4] + 1
		local p = Lobby.slab(f, 'Path', V(x0, 0, z0), V(x1, F.H, z1), F.path)
		p.CastShadow = false
	end
	-- the reference's two-tone sand: a 4-stud checker, every other tile a shade darker, laid on the path (whole cells
	-- of path only, not under the islands), 0.05 thick and studded like the path
	local tiles = {}
	local island = {}
	for _, r in Lobby.islandRects() do
		for j = 0, nz - 1 do
			local cz = N + j + 0.5
			if cz > r[3] and cz < r[4] then
				for i = 0, nx - 1 do
					local cx = -W + i + 0.5
					if cx > r[1] and cx < r[2] then island[j * nx + i] = true end
				end
			end
		end
	end
	for k in cells.path do
		local i, j = k % nx, k // nx
		local x, z = -W + i, N + j
		if not island[k] and (x // 4 + z // 4) % 2 == 0 then tiles[k] = true end
	end
	-- one part per tile (its cells' row runs when a path edge cuts it), so the checker keeps its squares
	local done = {}
	for k in tiles do
		if not done[k] then
			local x, z = -W + k % nx, N + k // nx
			local tx0, tz0 = (x // 4) * 4, (z // 4) * 4
			local rows = {}
			for zz = tz0, tz0 + 3 do
				local a, b
				for xx = tx0, tx0 + 3 do
					local kk = (zz - N) * nx + (xx + W)
					if xx + W >= 0 and xx + W < nx and zz - N >= 0 and zz - N < nz and tiles[kk] then
						done[kk] = true
						a, b = a or xx, xx + 1
					end
				end
				if a then
					local last = rows[#rows]
					if last and last[1] == a and last[2] == b and last[4] == zz then last[4] = zz + 1 else table.insert(rows, { a, b, zz, zz + 1 }) end
				end
			end
			for _, r in rows do decor(Lobby.slab(f, 'PathTile', V(r[1], F.H, r[3]), V(r[2], F.H + 0.05, r[4]), F.pathTile)).CastShadow = false end
		end
	end
	-- the court's own faint checker (user_34's water has one too), a shade lighter, not on the half-court
	local D = Lobby.Dais
	local cdone = {}
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local k = j * nx + i
			local x, z = -W + i, N + j
			if not cdone[k] and not cells.walk[k] and not cells.border[k] and not (x < -D.X and z >= D.Z0 - 1.3) and (x // 4 + z // 4) % 2 == 0 then
				local tx0, tz0 = (x // 4) * 4, (z // 4) * 4
				local rows = {}
				for zz = tz0, tz0 + 3 do
					local a, b
					for xx = tx0, tx0 + 3 do
						local ii, jj = xx + W, zz - N
						local kk = jj * nx + ii
						if ii >= 0 and ii < nx and jj >= 0 and jj < nz and not cells.walk[kk] and not cells.border[kk] then
							cdone[kk] = true
							a, b = a or xx, xx + 1
						end
					end
					if a then
						local last = rows[#rows]
						if last and last[1] == a and last[2] == b and last[4] == zz then last[4] = zz + 1 else table.insert(rows, { a, b, zz, zz + 1 }) end
					end
				end
				for _, r in rows do decor(Lobby.slab(f, 'CourtTile', V(r[1], 0, r[3]), V(r[2], 0.05, r[4]), F.courtTile)).CastShadow = false end
			end
		end
	end
	for _, r in Lobby.mergeCells(cells.border, nx, nz) do
		local x0, x1, z0, z1 = -W + r[1], -W + r[2] + 1, N + r[3], N + r[4] + 1
		Lobby.slab(f, 'PathBorder', V(x0, 0, z0), V(x1, F.B, z1), F.border).CastShadow = false
	end
	-- the doorway's sill (the wall's thickness) in the path's sand, so the street runs straight onto the north walk
	Lobby.slab(f, 'DoorSill', V(-Lobby.Door, 0, N - 1), V(Lobby.Door, F.H, N), F.sill)
	-- chevrons from the spawn: up the spine to the door, west to BAY 1, east to the armory, south to the shoe boxes
	local y, Z = F.H + 0.06, Lobby.CrossZ -- (the bars 0.12 thick: their feet in the path and its checker tiles)
	Lobby.chevrons(f, V(0, y, N + 14), V(0, 0, -1), 6, 3.2, 5.2)
	Lobby.chevrons(f, V(-Lobby.Gap + 1.5, y, Z), V(-1, 0, 0), 3, 3.2, 6)
	Lobby.chevrons(f, V(Lobby.Gap - 1.5, y, Z), V(1, 0, 0), 3, 3.2, 6)
	Lobby.chevrons(f, V(0, y, Lobby.Dais.Z0 - 4), V(0, 0, 1), 5, 3.2, 5.2)
	return f
end

---------------------------------------------------------------------------------------------- range stand
-- The TRAINING plaza on the west side of the spine, laid out like the training platform in the user's lobby reference
-- (brief/ref_lobby.png; the stations on both sides of a path in ref_bags.png): a low studded plaza 10 studs off the
-- spine, as long as the armory opposite, the hall's cross arm running on into it as the aisle, and the eight themed
-- shooting lanes (Stations.build in code5/d2_stations.lua) standing on both sides of the aisle facing it in two rows of
-- four, pairs opposite each other at a 12-stud pitch.
-- Every lane's shooter end is at the aisle edge: you stand with your back to the aisle and shoot away from it into the
-- lane's own backstop (north or south), so nobody aims across the aisle or at anyone.
-- Reading order: each step west down the aisle is the next pair, north before south (north 1, south 2, north 3 ...
-- south 8): Starter (FREE) is the north row's east end, the first lane off the spine; Gold, the finale, is the south
-- row's west end, its entrance marked by two gold-capped posts at the aisle's end.
--   Plaza: a pale grey studded deck 0.4 high with a darker raised kerb round it (open at the aisle mouth), studded
--     corner blocks, pale nosings; the aisle in the walkway's own lavender with darker edge lines, a red runner down
--     its middle to the west wall; lamp posts along both aisle edges between the lanes, two posts at the mouth.
--   Ends: the deck runs on 10 studs past the rows' backstops to the band's ends (the armory's length), where a hood
--     hangout (a bench, crates and a boombox, tyres) and a drum pallet stand off the walk.
--   The wall: the RANGES sign on the pillar at the aisle's end, graffiti murals in the bays either side of it.
-- Lobby.Plaza = the deck's rectangle (map frame) and the aisle's z run. Lobby.Stand.Lanes[i] = { x, z, look } for
-- Lobby.Ranges[i]; Slots[i] = its frame (origin on the deck at the lane's centre, -Z = the front, toward the aisle).
Lobby.Ranges = { 'Starter', 'Tape', 'Street', 'Heavy', 'Speed', 'DoubleEnd', 'Pro', 'Gold' }
Lobby.Plaza = { x0 = -68, x1 = -Lobby.Gap, z0 = Lobby.CrossZ - Lobby.Band, z1 = Lobby.CrossZ + Lobby.Band, aisle = { Lobby.CrossZ - Lobby.Walk, Lobby.CrossZ + Lobby.Walk }, deck = 0.4 }
Lobby.Stand = {
	-- lane centres: the north row 19.5 north of the cross (shooter end 0.5 off the aisle), the south row 19.5 south;
	-- x from 6.5 inside the mouth's kerb, 12 apart (3-stud gaps for the lamp posts)
	Place = (function()
		local zn, zs = Lobby.CrossZ - 19.5, Lobby.CrossZ + 19.5
		local list = {}
		for k = 0, 3 do
			local x = -Lobby.Gap - 6.5 - 12 * k
			table.insert(list, { x, zn, 'S' })
			table.insert(list, { x, zs, 'N' })
		end
		return list
	end)(),
	LabelStep = 1.0, -- each tier's label stack a stud higher than the last: down a row (2 tiers) the stacks climb like a ladder
	Colors = {
		-- (LOBBY3: the plaza is part of the path network: a sand deck and aisle inside the paths' dark blue border, its
		-- two ends past the lanes' backstops court-blue zones with the hangouts on them)
		deck = C(240, 216, 150), kerb = C(22, 92, 182), kerbTop = C(58, 132, 214), nose = C(250, 236, 196),
		aisle = C(240, 216, 150), aisleEdge = C(212, 184, 112), court = C(46, 150, 230),
		post = C(232, 230, 236), cap = C(250, 236, 196), riserDark = C(56, 64, 92), gold = C(245, 192, 30), goldDark = C(190, 130, 10),
		wood = C(176, 112, 70), woodDark = C(124, 76, 46), metal = C(70, 76, 96),
	},
	Lanes = {}, Slots = {},
}
function Lobby.standLayout()
	local St = Lobby.Stand
	table.clear(St.Lanes)
	table.clear(St.Slots)
	local dirs = { S = V(0, 0, 1), N = V(0, 0, -1), E = V(1, 0, 0) } -- (the way each lane's front faces: to the aisle)
	for i, p in St.Place do
		local pos = V(p[1], Lobby.Plaza.deck, p[2])
		St.Lanes[i] = { x = p[1], z = p[2], look = dirs[p[3]] }
		St.Slots[i] = CFrame.lookAt(pos, pos + dirs[p[3]])
	end
	return St
end
-- Hood props in a small cluster (c in the map frame, at = the cluster's centre on the ground it stands on):
-- kind 1 a stack of tyres, a crate and a cone; 2 two drums on a pallet; 3 a crate stack, a milk crate and a boombox.
function Lobby.standProps(c, kind, at)
	local wood, woodDark = C(196, 140, 80), C(146, 96, 52)
	local function crate(pos, s)
		c:box('Crate', pos - V(s / 2, 0, s / 2), pos + V(s / 2, s, s / 2), wood, M.SmoothPlastic)
		c:box('CrateBand', pos - V(s / 2 + 0.06, -s * 0.42, s / 2 + 0.06), pos + V(s / 2 + 0.06, s * 0.58, s / 2 + 0.06), woodDark, M.SmoothPlastic)
	end
	if kind == 1 then
		for k = 0, 2 do
			local p = at + V(-1.6 + k * 0.08, 0.36 + k * 0.72, -1.2)
			c:part('Tyre', V(0.72, 2.3, 2.3), CFrame.new(p) * CFrame.Angles(0, k * 0.4, math.pi / 2), C(36, 36, 42), M.SmoothPlastic, Enum.PartType.Cylinder)
		end
		c:part('TyreHub', V(0.74, 1.1, 1.1), CFrame.new(at + V(-1.44, 1.8, -1.2)) * CFrame.Angles(0, 0, math.pi / 2), C(150, 156, 166), M.Metal, Enum.PartType.Cylinder)
		crate(at + V(1.0, 0, 1.0), 2.2)
		if Stations then Stations.cone(c, CFrame.new(at + V(-1.2, 0, 1.9)) * CFrame.Angles(0, 0.5, 0)) end
	elseif kind == 2 then
		c:box('Pallet', at + V(-1.6, 0, -1.6), at + V(1.6, 0.4, 1.6), C(176, 126, 72), M.SmoothPlastic)
		c:box('PalletSkid', at + V(-1.5, 0, -0.3), at + V(1.5, 0.41, 0.3), C(128, 86, 46), M.SmoothPlastic)
		if Stations then
			Stations.drum(c, at + V(-0.8, 0.4, -0.7), 0.7, 2.0, C(40, 100, 210), C(26, 66, 150), C(30, 60, 130), M.SmoothPlastic)
			Stations.drum(c, at + V(0.8, 0.4, 0.6), 0.7, 2.0, C(214, 50, 46), C(150, 30, 30), C(120, 26, 26), M.SmoothPlastic)
		end
	else
		crate(at + V(-1.0, 0, -0.8), 2.2)
		crate(at + V(-0.9, 2.2, -0.7), 1.7)
		if Stations then
			Stations.milkcrate(c, CFrame.new(at + V(1.2, 0, 0.9)), C(40, 120, 220), { C(235, 55, 60), C(255, 150, 30) })
			Stations.boombox(c, CFrame.new(at + V(1.3, 0, -1.2)) * CFrame.Angles(0, -math.pi / 2, 0))
		end
	end
end
-- A cartoon graffiti mural painted on the west wall over z za..zb, y ya..yb (kind 1 a big target on a magenta
-- splat, 2 a lightning bolt on a cyan splat, 3 a crown on a yellow splat): a stepped splat with a darker drop
-- shadow, drips under it, the motif, two sparkle stars. Flat parts 0.1-0.3 proud of the wall's face (x -120).
function Lobby.rangeMural(c, kind, za, zb, ya, yb)
	local x0 = -Lobby.W
	local cz, cy = (za + zb) / 2, (ya + yb) / 2
	local w, h = zb - za, yb - ya
	local pal = ({ { C(236, 64, 160), C(150, 30, 104), C(255, 214, 60) }, { C(40, 200, 236), C(20, 110, 160), C(255, 230, 70) },
		{ C(255, 206, 40), C(190, 120, 10), C(150, 15, 40) } })[kind]
	local function paint(name, z0, z1, y0, y1, color, d)
		local p = decor(c:box(name, V(x0, y0, z0), V(x0 + (d or 0.12), y1, z1), color, M.SmoothPlastic))
		p.CastShadow = false
		return p
	end
	-- the splat: a cross of three stepped boxes over a darker drop shadow a little down and along
	for _, r in { { 0.5, 0.18, 0.06 }, { 0.36, 0.5, 0.06 }, { 0.44, 0.36, 0.06 } } do
		paint('MuralShadow', cz - w * r[1] + 0.5, cz + w * r[1] + 0.5, cy - h * r[2] - 0.5, cy + h * r[2] - 0.5, pal[2], 0.1)
	end
	for _, r in { { 0.48, 0.2 }, { 0.34, 0.46 }, { 0.42, 0.34 } } do
		paint('MuralSplat', cz - w * r[1], cz + w * r[1], cy - h * r[2], cy + h * r[2], pal[1], 0.16)
	end
	for _, d in { { -0.3, 1.6 }, { 0.05, 2.4 }, { 0.32, 1.2 } } do
		local z = cz + w * d[1]
		paint('MuralDrip', z - 0.35, z + 0.35, cy - h * 0.46 - d[2], cy - h * 0.4, pal[1], 0.16)
	end
	if kind == 1 then
		for k, r in { 4.2, 3.2, 2.2, 1.2 } do
			decor(c:part('MuralTarget', V(0.2 + k * 0.04, 2 * r, 2 * r), CFrame.new(x0 + 0.1 + k * 0.02, cy, cz), k % 2 == 1 and P.white or C(230, 40, 50), M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		end
	elseif kind == 2 then
		local ys = math.min(h * 0.38, 4.5)
		for _, b in { { -1.2, ys * 0.55, 1.6, ys, -24 }, { 0.2, 0, 3.6, 1.1, 0 }, { 1.2, -ys * 0.55, 1.6, ys, -24 } } do
			decor(c:part('MuralBolt', V(0.3, b[4], b[3]), CFrame.new(x0 + 0.2, cy + b[2], cz + b[1]) * CFrame.Angles(math.rad(b[5]), 0, 0), pal[3], M.SmoothPlastic)).CastShadow = false
		end
	else
		local cw = math.min(w * 0.6, 7)
		paint('MuralCrown', cz - cw / 2, cz + cw / 2, cy - 2.2, cy + 0.2, pal[3], 0.3)
		for k = 0, 2 do
			local z = cz - cw / 2 + cw * (0.15 + 0.35 * k)
			paint('MuralCrown', z - 0.7, z + 0.7, cy + 0.2, cy + 2.4, pal[3], 0.3)
			paint('MuralGem', z - 0.35, z + 0.35, cy - 1.4, cy - 0.7, k == 1 and C(60, 140, 255) or C(220, 30, 60), 0.36)
		end
	end
	for _, st in { { -0.4, 0.3 }, { 0.42, -0.2 } } do
		decor(c:part('MuralStar', V(0.2, 1.1, 1.1), CFrame.new(x0 + 0.2, cy + h * st[2], cz + w * st[1]) * CFrame.Angles(math.pi / 4, 0, 0), P.white, M.SmoothPlastic)).CastShadow = false
	end
end
function Lobby.stand(L, skins)
	local St = Lobby.standLayout()
	local K, Pz = St.Colors, Lobby.Plaza
	local x0, x1, z0, z1, h = Pz.x0, Pz.x1, Pz.z0, Pz.z1, Pz.deck
	local a0, a1 = Pz.aisle[1], Pz.aisle[2]
	local training = Instance.new('Folder')
	training.Name = 'Training'
	training.Parent = L.parent
	local t = L:group('RangeStand')
	local function slab(name, a, b, color, sides) return Lobby.slab(t, name, a, b, color, sides) end
	local function flat(name, a, b, color, mat)
		local p = decor(t:box(name, a, b, color, mat or M.SmoothPlastic))
		p.CastShadow = false
		return p
	end

	-- The deck, the kerb round it (0.25 proud, studded, a paler top band) and studded corner blocks; the kerb is open
	-- across the aisle mouth on the east edge, where a pale nosing finishes the step up from the hall floor.
	-- LOBBY3: the deck under the lanes and the aisle is the paths' sand; its two ends past the lanes' backstops are
	-- court zones a step lower (0.25), edged toward the lanes with the paths' dark blue border (0.33), the hangouts on them.
	local kw = 1.2
	local nb, sb = St.Lanes[1].z - 10, St.Lanes[2].z + 10 -- the two rows' backstop lines
	local he, bw = h - 0.15, 1.6
	slab('PlazaDeck', V(x0 + kw, 0, nb), V(x1 - kw, h, sb), K.deck)
	for _, e in { { z0 + kw, nb - bw, nb - bw, nb }, { sb + bw, z1 - kw, sb, sb + bw } } do
		slab('PlazaEnd', V(x0 + kw, 0, e[1]), V(x1 - kw, he, e[2]), K.court)
		slab('PlazaEndBorder', V(x0 + kw, 0, e[3]), V(x1 - kw, h - 0.07, e[4]), K.kerb)
	end
	local ky = h + 0.25
	local kerbs = {
		{ V(x0, 0, z0), V(x1, ky, z0 + kw) }, { V(x0, 0, z1 - kw), V(x1, ky, z1) }, { V(x0, 0, z0 + kw), V(x0 + kw, ky, z1 - kw) },
		{ V(x1 - kw, 0, z0 + kw), V(x1, ky, a0) }, { V(x1 - kw, 0, a1), V(x1, ky, z1 - kw) },
	}
	for _, e in kerbs do
		slab('PlazaKerb', e[1], e[2], K.kerb, true)
		flat('PlazaKerbTop', V(e[1].X + 0.15, ky, e[1].Z + 0.15), e[2] + V(-0.15, 0.04, -0.15), K.kerbTop)
	end
	slab('PlazaDeck', V(x1 - kw, 0, a0), V(x1, h, a1), K.aisle) -- (the mouth: the aisle's own colour)
	flat('PlazaNosing', V(x1 - 0.06, h - 0.14, a0), V(x1 + 0.3, h + 0.03, a1), K.nose)
	for _, c in { { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } } do
		local cx, cz = c[1] + (c[1] == x0 and 0.9 or -0.9), c[2] + (c[2] == z0 and 0.9 or -0.9)
		slab('PlazaCorner', V(cx - 1.1, 0, cz - 1.1), V(cx + 1.1, 0.95, cz + 1.1), K.kerb, true)
		flat('PlazaCornerCap', V(cx - 1.2, 0.95, cz - 1.2), V(cx + 1.2, 1.12, cz + 1.2), K.cap)
	end

	-- The aisle: the cross arm's sand run on from the mouth to the west kerb (no runner: it is the path), darker sand
	-- edge lines along the lanes' shooter ends.
	local ax = x0 + kw
	for _, z in { a0, a1 - 0.35 } do flat('AisleEdge', V(ax, h, z), V(x1 - kw, h + 0.08, z + 0.35), K.aisleEdge) end
	-- the paths' 4-stud checker on the aisle (on the world grid, like the hall's paths)
	for tx = math.ceil(ax / 4), math.floor(x1 / 4) - 1 do
		for tz = math.floor(a0 / 4), math.ceil(a1 / 4) - 1 do
			if (tx + tz) % 2 == 0 then
				local za, zb = math.max(a0 + 0.35, tz * 4), math.min(a1 - 0.35, tz * 4 + 4)
				if zb > za then decor(slab('AisleTile', V(tx * 4, h, za), V(tx * 4 + 4, h + 0.05, zb), Lobby.Floor.pathTile)).CastShadow = false end
			end
		end
	end

	-- Lamp posts on both aisle edges in the gaps between the lanes, and one on each kerb end at the mouth: a dark foot,
	-- a light post with a band, a pale cap, a warm lamp under a dark lid.
	local function lamp(x, z)
		local y = h
		slab('LaneLampFoot', V(x - 0.65, y, z - 0.65), V(x + 0.65, y + 0.55, z + 0.65), K.riserDark)
		t:box('LaneLampPost', V(x - 0.42, y + 0.55, z - 0.42), V(x + 0.42, y + 4.4, z + 0.42), K.post, M.SmoothPlastic)
		t:box('LaneLampBand', V(x - 0.47, y + 2.1, z - 0.47), V(x + 0.47, y + 2.45, z + 0.47), K.riserDark, M.SmoothPlastic)
		t:box('LaneLampCap', V(x - 0.6, y + 4.4, z - 0.6), V(x + 0.6, y + 4.7, z + 0.6), K.cap, M.SmoothPlastic)
		decor(t:box('LaneLamp', V(x - 0.38, y + 4.7, z - 0.38), V(x + 0.38, y + 5.4, z + 0.38), C(255, 236, 196), M.Neon)).CastShadow = false
		t:box('LaneLampTop', V(x - 0.52, y + 5.4, z - 0.52), V(x + 0.52, y + 5.62, z + 0.52), K.riserDark, M.SmoothPlastic)
	end
	for k = 1, 3 do
		local x = (St.Lanes[2 * k - 1].x + St.Lanes[2 * k + 1].x) / 2 -- (the gap between two pairs)
		lamp(x, a0 - 1.4)
		lamp(x, a1 + 1.4)
	end
	for _, z in { a0 - 0.65, a1 + 0.65 } do lamp(x1 - 0.6, z) end
	-- Gold's gate: two taller gold-capped posts at the aisle's end, either side of the last pair's shooter ends.
	for _, z in { a0 + 1.6, a1 - 1.6 } do
		local x = ax + 1.2
		slab('GoldPostFoot', V(x - 0.9, h, z - 0.9), V(x + 0.9, h + 0.7, z + 0.9), K.riserDark)
		t:box('GoldPost', V(x - 0.6, h + 0.7, z - 0.6), V(x + 0.6, h + 6.2, z + 0.6), K.post, M.SmoothPlastic)
		t:box('GoldPostBand', V(x - 0.66, h + 3.0, z - 0.66), V(x + 0.66, h + 3.5, z + 0.66), K.goldDark, M.SmoothPlastic)
		t:box('GoldPostCap', V(x - 0.85, h + 6.2, z - 0.85), V(x + 0.85, h + 6.6, z + 0.85), K.gold, M.SmoothPlastic)
		decor(t:box('GoldPostLamp', V(x - 0.5, h + 6.6, z - 0.5), V(x + 0.5, h + 7.4, z + 0.5), C(255, 226, 120), M.Neon)).CastShadow = false
		t:box('GoldPostTop', V(x - 0.7, h + 7.4, z - 0.7), V(x + 0.7, h + 7.65, z + 0.7), K.goldDark, M.SmoothPlastic)
	end

	-- The ends past the rows' backstops: at the north end a hangout by the mouth (a bench facing the hall, crates with a
	-- milk crate and a boombox beside it) and tyres in the far corner; at the south end drums on a pallet in the far
	-- corner and a crate stack by the mouth.
	local nz, sz = (z0 + kw + nb - bw) / 2, (z1 - kw + sb + bw) / 2
	Lobby.bench(t:at(CFrame.lookAt(V(x1 - 6, he, nz), V(x1, he, nz)))) -- (sitting facing east, to the spine)
	Lobby.standProps(t, 3, V(x1 - 12, he, nz))
	Lobby.standProps(t, 1, V(x0 + 5, he, nz))
	Lobby.standProps(t, 2, V(x0 + 6, he, sz))
	Lobby.standProps(t, 3, V(x1 - 7, he, sz))
	-- a long low planter in the middle of each end (the fill's planters)
	Lobby.planter(t:at(CFrame.new((x0 + x1) / 2 - 3, he, nz)), 13, 3.6, 71)
	Lobby.planter(t:at(CFrame.new((x0 + x1) / 2 - 3, he, sz)), 13, 3.6, 72)

	-- Graffiti murals on the west wall in the bays either side of the RANGES sign's pillar, under the windows: a target,
	-- a lightning bolt, a crown in the bay south of them.
	local Z = Lobby.CrossZ
	Lobby.rangeMural(t, 1, Z - 19, Z - 6, 4.8, 16.5)
	Lobby.rangeMural(t, 2, Z + 6, Z + 19, 4.8, 16.5)
	Lobby.rangeMural(t, 3, Z + 31, Z + 44, 4.8, 16.5)

	-- The lanes (each label stack LabelStep higher than the tier before).
	for k, id in Lobby.Ranges do
		local s = skins.StationById[id]
		local lift = (k - 1) * St.LabelStep
		Lobby.place(L, training, 'Range_' .. id, St.Slots[k], { X = 9, Y = 12, Z0 = -10, Z1 = 10 }, string.upper(s and s.Name or id), C(90, 200, 120),
			Stations and function(c) Stations.build(c, id, { labelLift = lift }) end)
	end
	return t
end

---------------------------------------------------------------------------------------------- shoe box dais
-- The back wall's centre (the reference's PETS egg dais) holds the 10 SHOE BOXES, cheapest first, laid out the way
-- the user's videos show their eggs: every box big on its own round pad (the soldier game's egg pads: a dark foot, a
-- drum in the box's colour, a glowing ring, a pale top) over the reference's checkered shelf, its name and price
-- floating just over it. The ten make one row, left to right as seen from the hall, staggered: the odd ones on the low
-- deck, the even ones on the high deck behind, each between two of the front ones, so every box and label reads from
-- the spawn without a second row hiding behind the first; full-width steps run up between the two. Each box is
-- turned a little toward the spine. The dais: a darker studded rim round paler studded decks, chamfered
-- front corners, a full-width front step, pale nosings on every edge, a low studded rail at the back. The SHOE BOXES
-- sign is on the back wall's centre pillar (Lobby.signs).
-- Map contract (HoodServer/ShoeService, HoodClient/Shoes.client): a Model `ShoeBoxes` tagged HoodShoeBoxes holding
-- `ShoeBox_<Id>` Models (attributes BoxId, Order, Price), each with:
--   Box_<Id>         BoxModels.build (the closed box; its `Lid` sub-model can pop), on its pad
--   BoxPoint_<Id>    invisible part on the pad's front, about 3 studs over the deck you stand on: the prompt anchor and
--                    the point ShoeService measures to (ShoeRules.Range 12)
--   BoxLabel_<Id>    BillboardGui WorldLabel: TextLabels Title (the box name) and Price (the Cash price, Glyph attribute
--                    as the armory's); Shoes.client may repaint Price. An Attachment ChancesPoint over it marks where
--                    Shoes.client floats the chances board.
--   BoxCollider      an invisible solid block round the box (the box's own parts don't collide)
-- Prices and names come from Config.Shoes (Lobby.ShoeBoxStub until it loads). Lobby.Slots.ShoeBoxes (+ SlotSizes):
-- the dais's front centre on the floor; Lobby.Slots.ShoeBox<i>: box i's pad top, facing the hall.
-- (HALL2: the same dais, 8 studs shallower, its front step a 6-wide walk past the activity band's end.)
Lobby.Dais = (function()
	local z0 = Lobby.CrossZ + Lobby.Band + Lobby.SouthWalk + 1.3
	return {
		X = 33, Z0 = z0, Z1 = z0 + 28, Low = 1.6, High = 4.8, Riser = z0 + 10.5, Top = z0 + 14.5, Scale = 1.45, PadR = 4.3,
		-- box i stands at x = First - (i - 1) * Pitch (left to right from the hall), odd ones on row 1, even ones on row 2
		First = 27.6, Pitch = 6.13, Rows = { { deck = 'Low', z = z0 + 6 }, { deck = 'High', z = z0 + 21 } },
	}
end)()
Lobby.ShoeBoxStub = {
	{ Id = 'Street', Name = 'Street Box', Price = 25, Color = C(232, 70, 56) },
	{ Id = 'Graffiti', Name = 'Graffiti Box', Price = 75, Color = C(255, 110, 190) },
	{ Id = 'Frost', Name = 'Frost Box', Price = 200, Color = C(120, 200, 255) },
	{ Id = 'Lava', Name = 'Lava Box', Price = 450, Color = C(255, 110, 40) },
	{ Id = 'Toxic', Name = 'Toxic Box', Price = 900, Color = C(110, 230, 70) },
	{ Id = 'Candy', Name = 'Candy Box', Price = 1600, Color = C(250, 140, 180) },
	{ Id = 'Ocean', Name = 'Ocean Box', Price = 2800, Color = C(30, 140, 190) },
	{ Id = 'Gem', Name = 'Gem Box', Price = 4500, Color = C(40, 190, 100) },
	{ Id = 'Galaxy', Name = 'Galaxy Box', Price = 7000, Color = C(130, 110, 240) },
	{ Id = 'Gold', Name = 'Gold Box', Price = 10000, Color = C(250, 186, 40) },
}
-- A shared module by path under ReplicatedStorage.Shared ('Config', 'Shoes'), nil if missing or failing.
function Lobby.sharedModule(...)
	local m = ReplicatedStorage:FindFirstChild('Shared')
	for _, name in { ... } do m = m and m:FindFirstChild(name) end
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end
-- The boxes in price order: Config.Shoes.Boxes, or the stub.
function Lobby.shoeBoxList()
	local cfg = Lobby.sharedModule('Config', 'Shoes')
	local list = (cfg and type(cfg.Boxes) == 'table' and #cfg.Boxes > 0) and table.clone(cfg.Boxes) or table.clone(Lobby.ShoeBoxStub)
	table.sort(list, function(a, b) return (a.Price or 0) < (b.Price or 0) end)
	return list
end
-- One round pad (c: its centre on the deck, front -Z) in colour col, a pedestal like the hall reference's under the
-- video's round egg pad: a dark foot, a drum in the box's colour with a pale band, a glowing ring, a pale top; a tag
-- leaning on its front (the video's oval tags) with `tag` on it. Returns the height of its top.
function Lobby.boxPad(c, col, tag)
	local r = Lobby.Dais.PadR
	local drum = col:Lerp(C(20, 22, 44), 0.5)
	c:post('BoxPadFoot', r, 0.36, V(0, 0, 0), C(58, 64, 98), M.SmoothPlastic)
	c:post('BoxPadDrum', r - 0.3, 0.84, V(0, 0.34, 0), drum, M.SmoothPlastic)
	c:post('BoxPadBand', r - 0.26, 0.16, V(0, 0.56, 0), col:Lerp(P.white, 0.35), M.SmoothPlastic)
	decor(c:post('BoxPadRing', r - 0.14, 0.14, V(0, 1.16, 0), col:Lerp(P.black, 0.2), M.Neon)).CastShadow = false
	c:post('BoxPadTop', r - 0.45, 0.2, V(0, 1.22, 0), col:Lerp(P.white, 0.72), M.SmoothPlastic)
	if tag then
		local plate = c:part('BoxPadTag', V(2.6, 0.9, 0.14), CFrame.new(0, 0.8, -r + 0.12) * CFrame.Angles(-0.32, 0, 0), C(30, 32, 52), M.SmoothPlastic)
		c:part('BoxPadTagRim', V(2.8, 1.06, 0.1), CFrame.new(0, 0.8, -r + 0.2) * CFrame.Angles(-0.32, 0, 0), col:Lerp(P.white, 0.25), M.SmoothPlastic)
		line(surface(plate, Enum.NormalId.Front, 40), 'Tag', tag, P.white, FONT.loud, 0.1, 0.8, col:Lerp(P.black, 0.4), 2)
	end
	return 1.42
end
-- The floating name and price over a box (the video's egg labels), kept low so Shoes.client's chances board has the
-- space above it (at the ChancesPoint attachment).
function Lobby.boxLabel(c, id, pos, name, price, col)
	local a = ghost(c:part('BoxLabel_' .. id, V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(math.max(6.5, 0.52 * #name), 2.6)
	g.MaxDistance = 120
	g.LightInfluence = 0
	g.Parent = a
	local ink = C(24, 22, 40)
	local h, s, v = col:ToHSV()
	line(g, 'Title', name, Color3.fromHSV(h, math.min(s, 0.75), math.max(v, 0.95)), FONT.loud, 0, 0.56, ink, 3)
	local icons = Lobby.sharedModule('Models', 'IconModels')
	local image = icons and icons.Images and icons.Images.Cash
	local t = line(g, 'Price', compact(price), C(255, 228, 92), FONT.loud, 0.56, 0.44, ink, 3)
	if type(image) == 'string' and image ~= '' then
		local i = Instance.new('ImageLabel')
		i.Name = 'PriceIcon'
		i.BackgroundTransparency = 1
		i.Image = image
		i.Position = UDim2.fromScale(0.24, 0.56)
		i.Size = UDim2.fromScale(0.16, 0.44)
		local r = Instance.new('UIAspectRatioConstraint')
		r.Parent = i
		i.Parent = g
		t.Position, t.Size, t.TextXAlignment = UDim2.fromScale(0.41, 0.56), UDim2.fromScale(0.55, 0.44), Enum.TextXAlignment.Left
		t:SetAttribute('Glyph', '')
	else
		t.Text = '💵 ' .. compact(price)
		t:SetAttribute('Glyph', '💵')
	end
	local cp = Instance.new('Attachment')
	cp.Name = 'ChancesPoint'
	cp.CFrame = CFrame.new(0, 5.5, 0)
	cp.Parent = a
	return a
end
function Lobby.shoeDais(L)
	local K = Lobby.Colors
	local D = Lobby.Dais
	local X, z0, z1, lo, hi = D.X, D.Z0, D.Z1, D.Low, D.High
	local d = L:group('ShoeBoxDais')
	-- (LOBBY3: in the floor's language, a sand stand inside the paths' dark blue: sand decks, blue rims, pale nosings)
	local rim, deck, trim = Lobby.Floor.border, C(246, 226, 170), C(252, 242, 214)
	local shelfLight, shelfDark = C(236, 238, 246), C(40, 46, 70)
	-- the low deck: a darker body (its sides and a 0.6 rim show) under a paler studded top, chamfered front corners
	Lobby.slab(d, 'Dais', V(-X + 4, 0, z0), V(X - 4, lo - 0.25, z1), rim, true)
	Lobby.slab(d, 'Dais', V(-X, 0, z0 + 4), V(X, lo - 0.25, z1), rim, true)
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (X - 2), (lo - 0.25) / 2, z0 + 2) * CFrame.Angles(0, 0, sx > 0 and -math.pi / 2 or math.pi / 2)
		studs(d:wedge('DaisCorner', V(lo - 0.25, 4, 4), cf, rim, M.Plastic), true)
	end
	Lobby.slab(d, 'DaisTop', V(-X + 4.6, lo - 0.25, z0 + 0.6), V(X - 4.6, lo, z1 - 0.6), deck)
	Lobby.slab(d, 'DaisTop', V(-X + 0.6, lo - 0.25, z0 + 4.6), V(X - 0.6, lo, z1 - 0.6), deck)
	-- the full-width front step (a pale nosing on it and on the deck's front edge)
	Lobby.slab(d, 'DaisStep', V(-X + 4, 0, z0 - 1.3), V(X - 4, lo / 2, z0), deck, true)
	d:box('DaisNosing', V(-X + 4, lo / 2 - 0.1, z0 - 1.4), V(X - 4, lo / 2 + 0.02, z0 - 0.9), trim, M.SmoothPlastic)
	d:box('DaisNosing', V(-X + 4, lo - 0.1, z0 - 0.1), V(X - 4, lo + 0.02, z0 + 0.5), trim, M.SmoothPlastic)
	-- the high deck behind, narrower (its studded ends stand on the low deck), up four full-width steps
	local hx = X - 1
	Lobby.slab(d, 'DaisHigh', V(-hx, lo, D.Top), V(hx, hi - 0.25, z1), rim, true)
	Lobby.slab(d, 'DaisHighTop', V(-hx + 0.6, hi - 0.25, D.Top + 0.6), V(hx - 0.6, hi, z1 - 0.6), deck)
	-- each step: a darker studded riser block under a pale studded tread, a pale nosing on its edge
	local n = 4
	for k = 1, n do
		local y = lo + (hi - lo) * k / n
		local za, zb = D.Riser + (D.Top - D.Riser) * (k - 1) / n, D.Riser + (D.Top - D.Riser) * k / n
		Lobby.slab(d, 'DaisStair', V(-hx, lo, za), V(hx, y - 0.2, zb), rim, true)
		Lobby.slab(d, 'DaisStairTread', V(-hx + 0.3, y - 0.2, za + 0.3), V(hx - 0.3, y, zb + (k == n and 0.6 or 0)), deck)
		d:box('DaisNosing', V(-hx, y - 0.1, za - 0.1), V(hx, y + 0.02, za + 0.4), trim, M.SmoothPlastic)
	end
	-- a low studded rail finishes the high deck's back edge (a pale cap on it)
	Lobby.slab(d, 'DaisRail', V(-hx + 0.6, hi, z1 - 2), V(hx - 0.6, hi + 1.4, z1 - 0.6), rim, true)
	d:box('DaisRailCap', V(-hx + 0.4, hi + 1.4, z1 - 2.2), V(hx - 0.4, hi + 1.7, z1 - 0.4), trim, M.SmoothPlastic)
	-- a checkered shelf (2 tones, 4-stud checks) under each row of pads
	for _, row in D.Rows do
		local y, sx = D[row.deck], row.deck == 'Low' and X - 1 or hx - 1
		d:box('ShelfStrip', V(-sx, y, row.z - 4), V(sx, y + 0.05, row.z + 4), shelfLight, M.SmoothPlastic).CastShadow = false
		for i = 0, math.floor(2 * sx / 4) - 1 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					local xa = -sx + 4 * i
					d:box('ShelfTile', V(xa, y, row.z - 4 + 4 * j), V(math.min(xa + 4, sx), y + 0.1, row.z + 4 * j), shelfDark, M.SmoothPlastic).CastShadow = false
				end
			end
		end
	end
	-- the boxes, in price order along the rows
	local BoxModels = Lobby.sharedModule('Models', 'BoxModels')
	local holder, folder = L:group('ShoeBoxes')
	folder:AddTag('HoodShoeBoxes')
	local slots = {}
	for i = 1, 10 do
		local row = D.Rows[2 - i % 2]
		table.insert(slots, { x = D.First - (i - 1) * D.Pitch, z = row.z, y = D[row.deck] })
	end
	for i, b in Lobby.shoeBoxList() do
		local s = slots[i]
		if not s then break end
		local id = b.Id
		local col = b.Color or C(200, 200, 210)
		local base = V(s.x, s.y + 0.1, s.z)
		-- turned partly toward the spine, so the plates read from the walkway
		local face = CFrame.lookAt(base, base + V(-s.x * 0.45, 0, Lobby.CrossZ - 17 - s.z))
		local bc, model = holder:group('ShoeBox_' .. id)
		model:SetAttribute('BoxId', id)
		model:SetAttribute('Order', i)
		model:SetAttribute('Price', b.Price)
		-- (it streams in whole, so Shoes.client finds the box, its point and its label together)
		pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
		local best = 0
		local cfg = Lobby.sharedModule('Config', 'Shoes')
		for _, sid in (b.Shoes or {}) do
			local sh = cfg and cfg.ById and cfg.ById[sid]
			if sh and type(sh.Bonus) == 'number' then best = math.max(best, sh.Bonus) end
		end
		local top = Lobby.boxPad(bc:at(face), col, best > 0 and ('UP TO +' .. compact(best) .. '%') or ('#' .. i))
		local slot = face * CFrame.new(0, top, 0)
		Lobby.Slots['ShoeBox' .. i] = slot
		local sc = D.Scale
		local height = 6.6 * sc
		if BoxModels then
			local ok, box = pcall(BoxModels.build, id, sc, bc:world(slot))
			if ok and box then
				box.Name = 'Box_' .. id
				box.Parent = model
				-- its theme particles and glow, and its floating pieces moving (client-side idle motion)
				if BoxModels.fx then pcall(BoxModels.fx, box) end
				if BoxModels.animate then pcall(BoxModels.animate, box) end
				-- the label floats just over the box's highest visible part
				local yTop = -math.huge
				for _, p in box:GetDescendants() do
					if p:IsA('BasePart') and p.Transparency < 1 then
						local _, y, _, _, _, _, r10, r11, r12 = p.CFrame:GetComponents()
						yTop = math.max(yTop, y + (math.abs(r10) * p.Size.X + math.abs(r11) * p.Size.Y + math.abs(r12) * p.Size.Z) / 2)
					end
				end
				if yTop > -math.huge then height = yTop - bc:world(slot).Position.Y end
			else
				warn('[Lobby] BoxModels.build(' .. id .. ') failed: ' .. tostring(box))
			end
		end
		if not model:FindFirstChild('Box_' .. id) then
			-- a placeholder box in the box's colour when BoxModels is missing
			local ph = bc:at(slot):box('Box_' .. id, V(-3.2, 0, -2.45), V(3.2, 4.5, 2.45), col, M.SmoothPlastic)
			decor(ph)
		end
		-- a solid block round the box (its own parts don't collide), the prompt point on the pad's front
		local coll = bc:at(slot):box('BoxCollider', V(-3.3, 0, -2.6), V(3.3, 4.6, 2.6), P.white, M.SmoothPlastic)
		coll.Transparency, coll.CanQuery, coll.CanTouch, coll.CastShadow = 1, false, false, false
		local point = ghost(bc:at(face):box('BoxPoint_' .. id, V(-0.6, 2.3, -D.PadR - 1.2), V(0.6, 3.7, -D.PadR), P.white))
		point.CastShadow = false
		Lobby.boxLabel(bc, id, (slot * CFrame.new(0, height + (i % 2 == 0 and 1.7 or 1.2), 0)).Position, b.Name or (id .. ' Box'), b.Price or 0, col)
	end
	Lobby.Slots.ShoeBoxes = CFrame.new(0, 0, z0)
	Lobby.SlotSizes.ShoeBoxes = V(2 * X, 14, z1 - z0)
	return d
end

---------------------------------------------------------------------------------------------- signs
-- The reference's hall signs: a white-framed pale board with a faint diamond lattice and the name in big white
-- letters with a dark grey outline. cf faces the hall.
function Lobby.hallSign(c, name, cf, w, ht, text)
	local K = Lobby.Colors
	c:part(name .. 'Frame', V(w + 2.4, ht + 2.4, 0.6), cf * CFrame.new(0, 0, 0.35), K.signFrame, M.SmoothPlastic)
	c:part(name .. 'Rim', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, 0.05), P.white, M.SmoothPlastic)
	local b, g = Lobby.board(c, name, cf * CFrame.new(0, 0, -0.2), w, ht, K.sign, { { 'Title', text, P.white, FONT.loud, 0.18, 0.64, C(90, 96, 120), 5 } }, 10)
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, true, 0.88, C(150, 156, 186))
	Lobby.stripes(b, Enum.NormalId.Front, w, ht, 3, 1.4, false, 0.88, C(150, 156, 186))
	local _ = g
	return b
end
function Lobby.signs(L)
	local W, S, Z = Lobby.W, Lobby.S, Lobby.CrossZ
	local s = L:group('HallSigns')
	-- the dais's title on the back wall's centre pillar, the plaza's on the west wall's middle pillar at the aisle's end
	-- (both on the slim upper part of the pillar, over the kink)
	local y = Lobby.PillarKink[2] + 6
	Lobby.hallSign(s, 'ShoeBoxSign', CFrame.lookAt(V(0, y, S - Lobby.PillarD[2] - 0.8), V(0, y, 0)), 22, 7.6, 'SHOE BOXES')
	Lobby.hallSign(s, 'RangeSign', CFrame.lookAt(V(-W + Lobby.PillarD[2] + 0.8, y, Z), V(0, y, Z)), 18, 7.6, 'RANGES')
	-- the reference's big floating CLONE MACHINE words: the ARMORY's title, over its back block on the east wall's middle
	-- pillar's axis (clear of the guns and nameplates from the floor and the treads; Lobby.ArmoryTitle follows the stand)
	local t = Lobby.ArmoryTitle
	Lobby.title(s, t.Pos, t.W, t.H, 'ARMORY', 'Better guns, more Power per shot!', nil, 160)
	return s
end

---------------------------------------------------------------------------------------------- north bays
-- The video's "cliff foot" by the exit: what it shows on boards there (update, codes, like the game, the group
-- chest) stands in the north wall's two corner bays either side of the exit bay, seen from the spawn and all down the
-- spine. Each object keeps its own small floating label; the two notices are framed boards on the wall over them
-- (physical boards, like the reference's info boards by its exit), high enough to stay clear of the lanes' and the
-- guns' floating labels seen from the spawn: east, a CODES terminal under "UPDATE SOON!"; west, the group reward
-- chest under "LIKE THE GAME!". ComingSoon prompts where no system exists yet.
-- Floating outlined words (the reference's big area titles and the video's notices): rows { name, text, colour,
-- height share }, a thick dark outline.
function Lobby.notice(c, pos, w, h, rows, maxDist)
	local list, y = {}, 0
	for _, r in rows do
		table.insert(list, { r[1], r[2], r[3], r.font or FONT.loud, y, r[4] })
		y += r[4] + 0.02
	end
	local a = billboard(c, pos, w, h, list)
	a.WorldLabel.MaxDistance = maxDist or 160
	for _, t in a.WorldLabel:GetChildren() do
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then s.Color, s.Thickness = C(14, 18, 36), 3 end
	end
	return a
end
-- The group reward chest (c: on the floor, front -Z): a dark studded plinth with a pale lip, a red chest with gold
-- bands, a lid with a raised cap, a gold lock, a floating label and a ComingSoon prompt.
function Lobby.rewardChest(c)
	local K = Lobby.Colors
	local g, model = c:group('GroupRewardChest')
	local red, gold = C(200, 44, 52), K.gold
	Lobby.slab(g, 'ChestPlinth', V(-3.6, 0, -2.8), V(3.6, 1.2, 2.8), C(60, 64, 84), true)
	g:box('ChestPlinthLip', V(-3.8, 1.2, -3), V(3.8, 1.5, 3), K.trim, M.SmoothPlastic)
	g:box('ChestBody', V(-2.8, 1.5, -1.9), V(2.8, 4.1, 1.9), red, M.SmoothPlastic)
	g:box('ChestLid', V(-2.95, 4.1, -2.05), V(2.95, 5.2, 2.05), red:Lerp(P.white, 0.12), M.SmoothPlastic)
	g:box('ChestLidCap', V(-2.6, 5.2, -1.6), V(2.6, 5.8, 1.6), red:Lerp(P.white, 0.2), M.SmoothPlastic)
	for _, sx in { -1, 1 } do g:box('ChestBand', V(sx * 1.7 - 0.35, 1.5, -2.1), V(sx * 1.7 + 0.35, 5.9, 2.1), gold, M.SmoothPlastic) end
	g:box('ChestRim', V(-3, 4.0, -2.1), V(3, 4.25, 2.1), gold:Lerp(P.black, 0.15), M.SmoothPlastic)
	g:box('ChestLock', V(-0.6, 3.2, -2.25), V(0.6, 4.6, -1.9), gold, M.SmoothPlastic)
	local hit = ghost(g:box('ChestHit', V(-3, 0, -3.5), V(3, 6, 3), P.white))
	Lobby.prompt(hit, 'Claim', 'Group Reward', 10)
	Lobby.notice(g, V(0, 8.6, 0), 9, 2.4, { { 'Name', 'GROUP REWARD', C(255, 214, 60), 0.58 }, { 'Soon', 'Join the group!', P.white, 0.38, font = FONT.title } }, 120)
	return model
end
-- The codes terminal (c: on the floor, front -Z): a dark studded foot, a navy body with a yellow stripe, a sloped
-- top carrying a glowing screen, a keypad ledge; a floating CODES label and a ComingSoon prompt.
function Lobby.codeTerminal(c)
	local K = Lobby.Colors
	local g, model = c:group('CodesTerminal')
	local body = C(40, 52, 96)
	Lobby.slab(g, 'TerminalFoot', V(-2.4, 0, -2), V(2.4, 0.6, 2), C(60, 64, 84), true)
	g:box('TerminalBody', V(-2, 0.6, -1.4), V(2, 5, 1.6), body, M.SmoothPlastic)
	g:box('TerminalStripe', V(-2.05, 1.6, -1.45), V(2.05, 2.1, 1.65), C(250, 196, 32), M.SmoothPlastic)
	g:box('TerminalLedge', V(-2, 3.4, -2.2), V(2, 3.8, -1.4), K.trim, M.SmoothPlastic)
	g:wedge('TerminalTop', V(4, 1.6, 3), CFrame.new(0, 5.8, 0.1), body:Lerp(P.white, 0.12), M.SmoothPlastic)
	decor(g:part('TerminalScreen', V(3.2, 0.1, 2.4), CFrame.new(0, 5.86, 0.07) * CFrame.Angles(-math.atan2(1.6, 3), 0, 0), C(70, 230, 255), M.Neon)).CastShadow = false
	local hit = ghost(g:box('TerminalHit', V(-2.5, 0, -4), V(2.5, 6, 2), P.white))
	Lobby.prompt(hit, 'Redeem', 'Codes', 10)
	Lobby.notice(g, V(0, 9.2, 0), 7, 2.4, { { 'Name', 'CODES', C(255, 214, 60), 0.58 }, { 'Soon', 'New code at 1K likes!', P.white, 0.38, font = FONT.title } }, 120)
	return model
end
-- A framed notice board on a wall (cf on the wall face, -Z into the hall): the hall signs' grey frame and white rim round
-- a pale board, a big coloured title over a line of detail, both outlined dark.
function Lobby.noticeBoard(c, name, cf, w, ht, title, color, detail)
	local K = Lobby.Colors
	c:part(name .. 'Frame', V(w + 2.4, ht + 2.4, 0.6), cf * CFrame.new(0, 0, -0.3), K.signFrame, M.SmoothPlastic)
	c:part(name .. 'Rim', V(w + 1.2, ht + 1.2, 0.4), cf * CFrame.new(0, 0, -0.65), P.white, M.SmoothPlastic)
	Lobby.board(c, name, cf * CFrame.new(0, 0, -0.95), w, ht, K.sign, {
		{ 'Title', title, color, FONT.loud, 0.08, 0.52, C(30, 34, 56), 4 },
		{ 'Detail', detail, C(46, 52, 80), FONT.title, 0.64, 0.28 },
	}, 12)
end
function Lobby.northBays(L)
	local N, W, e = Lobby.N, Lobby.W, Lobby.ExitEdge
	local b = L:group('NorthBays')
	local x = (e + W - 6) / 2 -- the middle of the corner bay
	local function wall(sx) return CFrame.lookAt(V(sx * x, Lobby.WinY, N), V(sx * x, Lobby.WinY, N + 1)) end
	-- east bay: the codes terminal under the update notice
	Lobby.codeTerminal(b:at(CFrame.lookAt(V(x, 0, N + 5), V(x, 0, N + 20))))
	Lobby.noticeBoard(b, 'UpdateBoard', wall(1), 13, 7, 'UPDATE SOON!', C(255, 150, 60), 'Shoe Boxes and new stages')
	-- west bay: the group reward chest under the like-the-game notice
	Lobby.rewardChest(b:at(CFrame.lookAt(V(-x, 0, N + 5.5), V(-x, 0, N + 20))))
	Lobby.noticeBoard(b, 'LikeBoard', wall(-1), 13, 7, 'LIKE THE GAME!', C(80, 200, 100), 'Likes unlock new codes')
	return b
end

---------------------------------------------------------------------------------------------- hood props
-- Hood life off the walkways (BRIEF4/15): the plaza's ends carry the hangout and the drums (Lobby.stand); here, a drinks
-- corner at the west wall's foot in the SW corner beside the leaderboards (a vending machine and a bin). Chunky boxes,
-- 2-3 tones each.
function Lobby.hoodProps(L)
	local g = L:group('HoodProps')
	local W, S = Lobby.W, Lobby.S
	local z = (Lobby.SidePillars[#Lobby.SidePillars] + Lobby.PillarW / 2 + S - 6) / 2 -- the last west bay's middle
	local d = g:at(CFrame.lookAt(V(-W + 2.4, 0, z), V(0, 0, z)))
	Lobby.slab(d, 'VendingKick', V(-2.2, 0, -1.6), V(2.2, 0.6, 1.4), C(40, 42, 52), true)
	d:box('VendingBody', V(-2.1, 0.6, -1.5), V(2.1, 8, 1.4), C(210, 40, 52), M.SmoothPlastic)
	d:box('VendingCap', V(-2.2, 8, -1.6), V(2.2, 8.5, 1.5), C(170, 28, 40), M.SmoothPlastic)
	local glass = d:box('VendingGlass', V(-1.8, 2.4, -1.6), V(0.6, 7.4, -1.45), C(170, 220, 245), M.SmoothPlastic)
	local sg = surface(glass, Enum.NormalId.Front, 10)
	for k, col in { C(250, 190, 40), C(60, 170, 240), C(90, 210, 100), C(240, 90, 150) } do
		local f = Instance.new('Frame')
		f.BorderSizePixel, f.BackgroundColor3 = 0, col
		f.Position, f.Size = UDim2.fromScale(0.08, 0.06 + (k - 1) * 0.24), UDim2.fromScale(0.84, 0.13)
		f.Parent = sg
	end
	d:box('VendingPanel', V(0.8, 3.4, -1.58), V(1.8, 6.6, -1.45), C(44, 46, 58), M.SmoothPlastic)
	decor(d:box('VendingSlot', V(1.05, 5.4, -1.62), V(1.55, 6.2, -1.56), C(120, 255, 160), M.Neon)).CastShadow = false
	d:box('VendingTray', V(-1.8, 1.0, -1.62), V(0.6, 1.9, -1.45), C(30, 30, 36), M.SmoothPlastic)
	line(surface(d:box('VendingTop', V(-1.9, 7.5, -1.62), V(1.9, 7.95, -1.5), P.white, M.SmoothPlastic), Enum.NormalId.Front, 30), 'Brand', 'ICE COLD', C(210, 40, 52), FONT.loud, 0.05, 0.9, nil)
	local bin = d:at(CFrame.new(3.6, 0, -0.6))
	bin:post('BinBody', 1.1, 2.6, V(0, 0, 0), C(60, 120, 80), M.SmoothPlastic)
	bin:post('BinBand', 1.15, 0.3, V(0, 1.9, 0), C(40, 90, 60), M.SmoothPlastic)
	bin:post('BinLid', 1.2, 0.3, V(0, 2.6, 0), C(44, 46, 58), M.SmoothPlastic)
	return g
end

---------------------------------------------------------------------------------------------- fill
-- What stands on the court between the paths (the reference's coral, plants and bubbles, as hood-warehouse things):
-- brick planters with blocky shrubs (and a small tree where nothing needs to be seen past it), street benches facing
-- the paths, hood clusters (a hydrant, crates on a pallet, a bin and bags, a boombox on a milk crate), a basketball
-- half-court in the SW corner, the leaderboards in the SE. Everything stands on the court, never on a path. Inside the
-- spawn's view of the doorway (the cone from the spawn camera to the door's jambs) nothing stands taller than the
-- line to the door's foot, so gate 1 stays whole in view; BAY 1 and the first guns stay in view too.
Lobby.Fill = {
	brick = C(206, 102, 70), brickDark = C(156, 70, 50), cap = C(240, 226, 198), soil = C(98, 70, 50),
	greens = { C(52, 166, 66), C(80, 194, 78), C(124, 216, 96) }, blossoms = { C(255, 120, 170), C(255, 214, 70), C(250, 250, 255) },
	wood = C(198, 132, 78), woodDark = C(140, 88, 50), metal = C(66, 72, 92), seatLeg = C(58, 64, 88),
}
-- A planter, c at its centre on the floor, long along local X: a studded brick body on a darker kick, a pale cap rim,
-- dark soil, a row of blocky shrubs in three greens (a lighter block on each), a few blossoms. opts: low (shrubs at
-- most ~1.2 over the cap, for the view cone), tree (a small cube tree in the middle instead of the middle shrubs).
function Lobby.planter(c, len, dep, seed, opts)
	opts = opts or {}
	local F = Lobby.Fill
	local r = Random.new(seed)
	local hgt = 1.1
	local g = c:group('Planter')
	Lobby.slab(g, 'PlanterBody', V(-len / 2, 0.2, -dep / 2), V(len / 2, hgt, dep / 2), F.brick, true)
	g:box('PlanterKick', V(-len / 2 - 0.12, 0, -dep / 2 - 0.12), V(len / 2 + 0.12, 0.35, dep / 2 + 0.12), F.brickDark, M.SmoothPlastic)
	for _, e in { { -len / 2 - 0.2, len / 2 + 0.2, -dep / 2 - 0.2, -dep / 2 + 0.45 }, { -len / 2 - 0.2, len / 2 + 0.2, dep / 2 - 0.45, dep / 2 + 0.2 },
		{ -len / 2 - 0.2, -len / 2 + 0.45, -dep / 2 + 0.45, dep / 2 - 0.45 }, { len / 2 - 0.45, len / 2 + 0.2, -dep / 2 + 0.45, dep / 2 - 0.45 } } do
		g:box('PlanterCap', V(e[1], hgt, e[3]), V(e[2], hgt + 0.3, e[4]), F.cap, M.SmoothPlastic)
	end
	g:box('PlanterSoil', V(-len / 2 + 0.45, hgt - 0.2, -dep / 2 + 0.45), V(len / 2 - 0.45, hgt + 0.12, dep / 2 - 0.45), F.soil, M.SmoothPlastic)
	local n = math.max(1, math.floor((len - 0.9) / 2.3))
	local step = (len - 0.9) / n
	for k = 1, n do
		local x = -len / 2 + 0.45 + (k - 0.5) * step
		if not (opts.tree and math.abs(x) < 1.6) then
			local s = math.min(step - 0.1, r:NextNumber(1.7, 2.3))
			local d = math.min(dep - 1.1, s)
			local hh = opts.low and r:NextNumber(0.7, 1.1) or r:NextNumber(1.2, 2.2)
			local col = F.greens[r:NextInteger(1, 2)]
			local zo = r:NextNumber(-0.2, 0.2)
			Lobby.slab(g, 'Shrub', V(x - s / 2, hgt + 0.1, zo - d / 2), V(x + s / 2, hgt + 0.1 + hh, zo + d / 2), col, true)
			local t = s * 0.6
			Lobby.slab(g, 'ShrubTop', V(x - t / 2 + 0.15, hgt + 0.1 + hh, zo - math.min(t, d) / 2), V(x + t / 2 + 0.15, hgt + 0.6 + hh, zo + math.min(t, d) / 2), F.greens[3], true)
			if r:NextNumber() < 0.5 then
				local bc = F.blossoms[r:NextInteger(1, #F.blossoms)]
				g:box('Blossom', V(x - s / 2 + 0.2, hgt + hh - 0.2, zo - d / 2 - 0.12), V(x - s / 2 + 0.75, hgt + hh + 0.35, zo - d / 2 + 0.43), bc, M.SmoothPlastic)
			end
		end
	end
	if opts.tree then tree(g, V(0, hgt + 0.1, 0), seed, opts.tree, nil, true) end
	return g
end
-- A street bench (c on the floor; you sit facing local -Z): dark legs, a wooden seat with a darker edge, a back on posts.
function Lobby.bench(c)
	local F = Lobby.Fill
	local g = c:group('Bench')
	for _, dx in { -2.2, 2.2 } do Lobby.slab(g, 'BenchLeg', V(dx - 0.5, 0, -0.9), V(dx + 0.5, 1.4, 0.9), F.seatLeg) end
	g:box('BenchSeat', V(-3, 1.4, -1.1), V(3, 1.85, 1.1), F.wood, M.SmoothPlastic)
	g:box('BenchSeatEdge', V(-3.1, 1.25, -1.2), V(3.1, 1.45, 1.2), F.woodDark, M.SmoothPlastic)
	for _, dx in { -2.2, 2.2 } do g:box('BenchBackPost', V(dx - 0.25, 1.85, 0.6), V(dx + 0.25, 4.0, 1.1), F.metal, M.SmoothPlastic) end
	g:box('BenchBack', V(-3, 2.6, 0.75), V(3, 3.8, 1.15), F.wood, M.SmoothPlastic)
	return g
end
-- Crates on a pallet (c on the floor): the kit's pallet, two crates side by side, a smaller one on top when tall.
function Lobby.crateStack(c, tall)
	pallet(c, CFrame.new())
	crate(c, CFrame.new(-1.0, 0.8, 0) * CFrame.Angles(0, 0.08, 0), 2)
	crate(c, CFrame.new(1.05, 0.8, 0.1) * CFrame.Angles(0, -0.1, 0), 1.8)
	if tall then crate(c, CFrame.new(-0.8, 2.8, 0) * CFrame.Angles(0, 0.3, 0), 1.6) end
end
-- The basketball half-court in the SW corner (c: the middle of its baseline, front -Z toward the hall): a lighter
-- painted key, white lines (baseline, the key, the free-throw circle, the three-point arc in stepped segments), a hoop
-- on a padded pole with a white backboard and an orange rim and net, a ball rack beside it.
function Lobby.halfCourt(c)
	local F = Lobby.Floor
	local g = c:group('HalfCourt')
	local function paint(name, a, b, color, y)
		local p = decor(g:box(name, V(a.X, y or 0, a.Z), V(b.X, (y or 0) + 0.05, b.Z), color, M.SmoothPlastic))
		p.CastShadow = false
		return p
	end
	local lw = 0.35
	paint('CourtKey', V(-4.2, 0, -14), V(4.2, 0, 0), F.courtKey)
	local function seg(a, b) -- a line from a to b (on the floor)
		local p = decor(g:part('CourtLine', V(lw, 0.06, (b - a).Magnitude + lw), CFrame.lookAt((a + b) / 2 + V(0, 0.06, 0), b + V(0, 0.06, 0)), F.courtLine, M.SmoothPlastic))
		p.CastShadow = false
	end
	seg(V(-19, 0, 0), V(19, 0, 0)) -- the baseline
	seg(V(-4.2, 0, 0), V(-4.2, 0, -14))
	seg(V(4.2, 0, 0), V(4.2, 0, -14))
	seg(V(-4.2, 0, -14), V(4.2, 0, -14))
	local function arc(cz, r, a0, a1, n)
		local prev
		for k = 0, n do
			local a = math.rad(a0 + (a1 - a0) * k / n)
			local pnt = V(math.sin(a) * r, 0, cz - math.cos(a) * r)
			if prev then seg(prev, pnt) end
			prev = pnt
		end
	end
	arc(-14, 4.2, -90, 90, 6) -- the free-throw circle's top half
	-- the three-point line: straight from the baseline at x +-17, then the arc round the hoop (radius 18)
	local a3 = math.deg(math.asin(17 / 18))
	arc(-1.6, 18, -a3, a3, 12)
	local zc = -1.6 - math.sqrt(18 * 18 - 17 * 17)
	for _, sx in { -1, 1 } do seg(V(sx * 17, 0, 0), V(sx * 17, 0, zc)) end
	-- the hoop: a dark foot, a padded pole leaning out, the backboard (white, a red square), the orange rim, a white net
	local pole = C(52, 58, 80)
	Lobby.slab(g, 'HoopFoot', V(-1.4, 0, 1.2), V(1.4, 0.8, 3.6), C(60, 64, 84), true)
	g:box('HoopPole', V(-0.5, 0.8, 1.9), V(0.5, 11.4, 2.9), pole, M.SmoothPlastic)
	g:box('HoopPad', V(-0.7, 0.8, 1.7), V(0.7, 5.2, 3.1), C(214, 52, 52), M.SmoothPlastic)
	g:box('HoopArm', V(-0.4, 10.4, 0.2), V(0.4, 11.2, 2.9), pole, M.SmoothPlastic)
	g:box('Backboard', V(-3.6, 9.2, -0.1), V(3.6, 13.4, 0.3), P.white, M.SmoothPlastic)
	g:box('BackboardRim', V(-3.8, 9.0, 0.3), V(3.8, 13.6, 0.5), pole, M.SmoothPlastic)
	for _, e in { { -1.3, 10.1, -1.1, 11.9 }, { 1.1, 10.1, 1.3, 11.9 }, { -1.3, 10.1, 1.3, 10.3 }, { -1.3, 11.7, 1.3, 11.9 } } do
		g:box('BackboardSquare', V(e[1], e[2], -0.14), V(e[3], e[4], -0.1), C(214, 52, 52), M.SmoothPlastic)
	end
	local rim = C(255, 120, 30)
	g:box('HoopRim', V(-1.2, 10.0, -2.5), V(1.2, 10.25, -2.2), rim, M.SmoothPlastic)
	g:box('HoopRim', V(-1.2, 10.0, -0.4), V(1.2, 10.25, -0.1), rim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do g:box('HoopRim', V(sx * 1.2 - 0.15, 10.0, -2.5), V(sx * 1.2 + 0.15, 10.25, -0.1), rim, M.SmoothPlastic) end
	local net = g:box('HoopNet', V(-0.95, 8.9, -2.2), V(0.95, 10.0, -0.4), P.white, M.SmoothPlastic)
	net.Transparency = 0.35
	-- a ball rack: a dark frame with three orange balls
	local rack = g:at(CFrame.new(7, 0, 2.2))
	for _, sx in { -1.6, 1.6 } do rack:box('RackLeg', V(sx - 0.2, 0, -0.6), V(sx + 0.2, 2.2, 0.6), pole, M.SmoothPlastic) end
	rack:box('RackShelf', V(-1.8, 1.6, -0.7), V(1.8, 1.8, 0.7), pole, M.SmoothPlastic)
	for k = -1, 1 do rack:part('Ball', V(1.1, 1.1, 1.1), CFrame.new(k * 1.15, 2.35, 0), C(236, 112, 34), M.SmoothPlastic, Enum.PartType.Ball) end
	g:part('Ball', V(1.1, 1.1, 1.1), CFrame.new(-6, 0.55, -9), C(236, 112, 34), M.SmoothPlastic, Enum.PartType.Ball)
	return g
end
-- Graffiti painted on the court (c at its centre on the floor): a stepped splat over a darker drop shadow and a motif
-- (1 a crown, 2 a lightning bolt, 3 a star), flat paint 0.1 thick.
function Lobby.floorArt(c, kind, w, d)
	local pal = ({ { C(236, 64, 160), C(150, 30, 104), C(255, 214, 60) }, { C(255, 206, 40), C(190, 120, 10), C(40, 60, 160) },
		{ C(120, 226, 70), C(50, 140, 40), P.white } })[kind]
	local g = c:group('FloorArt')
	local function paint(name, x0, x1, z0, z1, color, y)
		decor(g:box(name, V(x0, 0, z0), V(x1, y or 0.1, z1), color, M.SmoothPlastic)).CastShadow = false
	end
	for _, r in { { 0.5, 0.18 }, { 0.36, 0.5 }, { 0.44, 0.36 } } do paint('ArtShadow', -w * r[1] + 0.5, w * r[1] + 0.5, -d * r[2] + 0.5, d * r[2] + 0.5, pal[2], 0.09) end
	for _, r in { { 0.48, 0.2 }, { 0.34, 0.46 }, { 0.42, 0.34 } } do paint('ArtSplat', -w * r[1], w * r[1], -d * r[2], d * r[2], pal[1], 0.1) end
	if kind == 1 then
		local cw = w * 0.52
		paint('ArtCrown', -cw / 2, cw / 2, 0.2, 1.8, pal[3], 0.14)
		for k = 0, 2 do
			local x = -cw / 2 + cw * (0.15 + 0.35 * k)
			paint('ArtCrown', x - 0.6, x + 0.6, -1.6, 0.2, pal[3], 0.14)
		end
	elseif kind == 2 then
		for _, b in { { -0.9, -0.9, 1.1, 2.6, -24 }, { 0.15, 0, 2.9, 0.9, 0 }, { 0.9, 0.9, 1.1, 2.6, -24 } } do
			decor(g:part('ArtBolt', V(b[3], 0.14, b[4]), CFrame.new(b[1], 0.07, b[2]) * CFrame.Angles(0, math.rad(b[5]), 0), pal[3], M.SmoothPlastic)).CastShadow = false
		end
	else
		for _, a in { 0, 72, 144, 216, 288 } do
			decor(g:part('ArtStar', V(0.9, 0.14, 2.4), CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0.07, -1.1), pal[3], M.SmoothPlastic)).CastShadow = false
		end
	end
	return g
end
function Lobby.fill(L)
	local g = L:group('Fill')
	local F = Lobby.Floor
	local sx = { -1, 1 }
	-- the four zones beside the spine (x +-(Spine..Gap)): north of the cross arm everything stays low (the door's view
	-- cone), south of it trees may stand
	local xm = (Lobby.Spine + Lobby.Gap) / 2 -- 13
	local Z = Lobby.CrossZ
	for k, s in sx do
		local at = function(x, z, yaw) return g:at(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)) end
		-- north: a low planter at each end, a hood cluster by the island side between them
		Lobby.planter(at(s * xm, Z - 34, 0), 7, 3.4, 10 + k, { low = true })
		Lobby.planter(at(s * xm, Z - 13.5, 0), 7, 3.4, 20 + k)
		Lobby.floorArt(at(s * 11.2, Z - 23.5, s * 8), s < 0 and 1 or 2, 6, 7)
		if s < 0 then
			hydrant(g, V(-16, 0, Z - 26))
			Lobby.crateStack(at(-15.6, Z - 20, 6))
		else
			bike(g, CFrame.new(16.2, 0, Z - 25) * CFrame.Angles(0, math.rad(8), 0), C(60, 170, 240))
			if Stations then
				Stations.cone(g, CFrame.new(15, 0, Z - 19.5) * CFrame.Angles(0, 0.4, 0))
				Stations.cone(g, CFrame.new(16.6, 0, Z - 18.4) * CFrame.Angles(0, -0.3, 0))
			end
		end
		-- south: a tree planter, a bench facing the spine, a hangout, a low planter at the end
		Lobby.planter(at(s * xm, Z + 15.5, 0), 5, 5, 30 + k, { tree = 0.5 })
		Lobby.bench(g:at(CFrame.lookAt(V(s * 16, 0, Z + 25), V(0, 0, Z + 25))))
		if s < 0 then
			storeCrates(g, CFrame.new(-13.5, 0, Z + 31.5) * CFrame.Angles(0, math.rad(84), 0), 3)
		else
			hydrant(g, V(10.5, 0, Z + 30.5))
			Lobby.crateStack(at(15.5, Z + 31.5, -8))
		end
		Lobby.planter(at(s * xm, Z + 35.5, 0), 7, 3.4, 40 + k, { low = true })
	end
	-- the SW corner: the half-court (its baseline near the back wall, facing the hall), a bench beside it
	local cz = Lobby.S - 4.5
	local cx = -(Lobby.Dais.X + Lobby.W) / 2
	Lobby.halfCourt(g:at(CFrame.new(cx, 0, cz)))
	Lobby.bench(g:at(CFrame.lookAt(V(cx + 16, 0, cz - 21.5), V(cx - 100, 0, cz - 21.5))))
	-- the SE corner: tall planters either side of the boards' spur (the east one clear of the wall pillar's plinth)
	local B = Lobby.BoardSpur
	local mz = (Lobby.Dais.Z0 + B.z1) / 2
	Lobby.planter(g:at(CFrame.new((Lobby.Dais.X + B.x0) / 2, 0, mz) * CFrame.Angles(0, math.pi / 2, 0)), 9, 4.2, 61, { tree = 0.55 })
	Lobby.planter(g:at(CFrame.new(B.x1 + 4.5, 0, mz) * CFrame.Angles(0, math.pi / 2, 0)), 9, 3.6, 62, { tree = 0.5 })
	return g
end

---------------------------------------------------------------------------------------------- leaderboards
-- The reference's boards (user_35), three in a row in the SE corner at the end of a sand spur off the south walk:
-- each a grey studded frame on two posts that run down to dark feet, an X joint at every corner of the frame, a dark
-- navy screen with the rows, a grey header plate with the board's name, a dark cap on each post; over each a big
-- floating title in its colour (TOP POWER orange, TOP REBIRTHS red, TOP CASH green), like "TOP 50 POWER".
-- `live` names the model LobbyService writes into (a TextLabel named TextLabel): PowerLeaderboard (top Power),
-- ServerLeaderboard (rebirths, then Power: the rebirth board), CashLeaderboard (top Cash).
-- cf: the board's foot centre on the floor, front -Z.
Lobby.BoardSpur = { x0 = 46, x1 = 59, z1 = 117 } -- the spur's sand, off the south walk, to the middle board
Lobby.Boards = {
	-- (left to right for a player facing them, i.e. facing south: POWER at the east end, CASH at the west end)
	{ x = 66.5, z = 119.5, yaw = 24, lift = 0, name = 'POWER', title = 'TOP POWER', color = C(255, 166, 40), live = 'PowerLeaderboard' },
	{ x = 53, z = 123.5, yaw = 0, lift = 1, name = 'REBIRTHS', title = 'TOP REBIRTHS', color = C(255, 70, 70), live = 'ServerLeaderboard' },
	{ x = 39.5, z = 119.5, yaw = -24, lift = 0, name = 'CASH', title = 'TOP CASH', color = C(120, 226, 70), live = 'CashLeaderboard' },
}
Lobby.BoardW, Lobby.BoardH, Lobby.BoardY = 7.5, 12, 3.2 -- the screen's width, height and its foot's height
function Lobby.leaderboard(L, cf, b)
	local root, model = L:at(cf):group(b.live)
	local grey, light, dark, navy, foot = C(140, 146, 166), C(178, 184, 202), C(96, 102, 124), C(26, 34, 68), C(30, 34, 46)
	local w, h, y0 = Lobby.BoardW, Lobby.BoardH, Lobby.BoardY
	local px = w / 2 + 1 -- the posts' centres
	local top = y0 + h -- the screen's top; the header plate sits over it
	local hy = top + 3.4 -- the frame's top
	-- the posts (studded on every side), running down to dark feet and up to dark caps
	for _, sx in { -1, 1 } do
		local x = sx * px
		Lobby.slab(root, 'BoardPost', V(x - 1, 0.7, -1), V(x + 1, hy, 1), grey, true)
		root:box('BoardFoot', V(x - 1.5, 0, -1.6), V(x + 1.5, 0.8, 1.6), foot, M.SmoothPlastic)
		root:box('BoardCap', V(x - 1.3, hy, -1.3), V(x + 1.3, hy + 0.7, 1.3), foot, M.SmoothPlastic)
	end
	-- the rails under and over the screen, and the header plate between the posts at the top
	Lobby.slab(root, 'BoardRail', V(-px, y0 - 1.3, -0.8), V(px, y0, 0.8), grey, true)
	Lobby.slab(root, 'BoardRail', V(-px, top, -0.8), V(px, top + 0.6, 0.8), grey, true)
	Lobby.slab(root, 'BoardHeader', V(-px + 1, top + 0.6, -0.9), V(px - 1, hy - 0.2, 0.9), light, true)
	local plate = root:box('BoardTitle', V(-px + 1.8, top + 1.1, -1.05), V(px - 1.8, hy - 0.7, -0.9), dark, M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 24), 'Title', b.name, P.white, Enum.Font.GothamBlack, 0.1, 0.8, C(20, 24, 40), 2)
	-- an X joint at each corner of the frame: a block on the post, two crossed bars and a short stub sticking out
	for _, sx in { -1, 1 } do
		for _, cy in { y0 - 0.65, top + 1.6 } do
			local c = root:at(CFrame.new(sx * px, cy, -1.05))
			c:box('BoardJoint', V(-1.15, -1.15, -0.25), V(1.15, 1.15, 0.25), dark, M.SmoothPlastic)
			for _, a in { 45, -45 } do c:part('BoardJointX', V(0.6, 2.8, 0.5), CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, math.rad(a)), light, M.SmoothPlastic) end
			c:box('BoardJointStub', V(sx * 1.1, -0.45, -0.1), V(sx * 1.9, 0.45, 0.7), grey, M.SmoothPlastic)
		end
	end
	-- the screen: a dark bezel, the navy face, pale row stripes behind the text LobbyService writes
	root:box('BoardBezel', V(-px + 1, y0, -0.5), V(px - 1, top, 0.5), dark, M.SmoothPlastic)
	local screen = root:box('BoardScreen', V(-w / 2 + 0.3, y0 + 0.3, -0.62), V(w / 2 - 0.3, top - 0.3, 0.3), navy, M.SmoothPlastic)
	local g = surface(screen, Enum.NormalId.Front, 20)
	for k = 0, 6 do
		local f = Instance.new('Frame')
		f.Name = 'Band'
		f.BorderSizePixel = 0
		f.BackgroundColor3 = C(60, 76, 140)
		f.BackgroundTransparency = 0.55
		f.Position, f.Size = UDim2.fromScale(0.04, 0.2 + k * 0.115), UDim2.fromScale(0.92, 0.075)
		f.ZIndex = 0
		f.Parent = g
	end
	local first = b.live == 'CashLeaderboard' and 'TOP CASH\nTHIS SERVER\nClear a gate to earn Cash!'
		or b.live == 'PowerLeaderboard' and 'TOP POWER\nTHIS SERVER\nBe the first to train!' or 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!'
	local t = line(g, 'TextLabel', first, C(214, 228, 255), Enum.Font.GothamBlack, 0.04, 0.92, C(10, 14, 34), 1)
	t.TextYAlignment = Enum.TextYAlignment.Top
	-- the floating title in the board's colour
	local a = Lobby.title(root, V(0, hy + 3.8 + (b.lift or 0), 0), 11.5, 3, b.title, nil, b.color, 200)
	-- (LabelFade: seen across the hall like the reference's "TOP 50" titles, gone from the streets)
	a.WorldLabel:SetAttribute('FadeNear', 110)
	a.WorldLabel:SetAttribute('FadeFar', 150)
	for _, l in a.WorldLabel:GetChildren() do
		if l:IsA('TextLabel') then
			l.Font = Enum.Font.GothamBlack
			local s = l:FindFirstChildOfClass('UIStroke')
			if s then s.Color, s.Thickness = C(40, 16, 6):Lerp(b.color, 0.15), 3.5 end
		end
	end
	return model
end
function Lobby.leaderboards(L)
	local g = L:group('Leaderboards')
	for k, b in Lobby.Boards do
		local cf = CFrame.new(b.x, 0, b.z) * CFrame.Angles(0, math.rad(b.yaw), 0)
		Lobby.Slots['Leaderboard' .. k] = cf
		Lobby.leaderboard(g, cf, b)
	end
	return g
end

---------------------------------------------------------------------------------------------- spawn & slots
-- The spawn point on the cross (StageService and SetActive use it), facing north up the spine to the Stage 1 door
-- (the video's rule: from the spawn you already see the next goal, gate 1's "STAGE 1 / Recommended Power", and the
-- locked gates beyond it down the street). No mark on the floor: you land on the walkway cross.
-- The FURTHEST STAGE pad stands west of the door inside the exit bay on a glowing orange patch beside a yellow kiosk
-- (the reference's yellow machine there).
function Lobby.spawn(L)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.4, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = L.parent
	Lobby.Slots.Spawn = CFrame.new(SPAWN)
	-- the kiosk stands in front of the exit frame's west jamb on the north walk, the pad just east of it: magenta like
	-- every gate's FURTHEST pad (GATES2's pads; the reference's magenta stage pad), on a dark rim, its label up close
	local k = L:group('FurthestKiosk')
	Lobby.slab(k, 'KioskBase', V(-51.6, 0, 8), V(-42.4, 0.8, 14), C(60, 64, 84), true)
	Lobby.slab(k, 'Kiosk', V(-51, 0.8, 8.5), V(-43, 5, 13.5), C(255, 210, 40), true)
	k:box('KioskStripe', V(-51.1, 1.4, 8.4), V(-42.9, 2, 13.6), C(214, 160, 20), M.SmoothPlastic)
	k:box('KioskTop', V(-50.4, 5, 9.1), V(-43.6, 6.4, 12.9), P.white, M.SmoothPlastic)
	k:box('KioskTopLip', V(-50.8, 5, 8.7), V(-43.2, 5.3, 13.3), C(200, 204, 214), M.SmoothPlastic)
	k:box('KioskScreenFrame', V(-50, 2.6, 13.5), V(-44, 4.6, 13.7), C(30, 34, 50), M.SmoothPlastic)
	k:box('KioskScreen', V(-49.6, 2.9, 13.7), V(-44.4, 4.3, 13.8), C(40, 200, 120), M.Neon)
	teleportPad(L, 'FurthestPad', -36.5, 11, C(255, 32, 255), 'Furthest', 'FURTHEST STAGE', { w = 7, d = 7, y = Lobby.Floor.H, h = 0.25,
		material = M.SmoothPlastic, base = C(58, 66, 98), shade = C(184, 16, 186), rim = C(255, 178, 255), sparkle = true,
		title = 'FURTHEST', sub = 'Best stage', labelColor = C(255, 178, 255), font = Enum.Font.GothamBlack, arrow = -1 })
	Lobby.Slots.FurthestPad = CFrame.new(-36.5, Lobby.Floor.H, 11)
end
-- Run a builder into its own folder; on a missing builder or an error, a labelled box of the slot's size.
function Lobby.place(L, parent, name, cf, size, label, color, build)
	Lobby.Slots[name] = cf
	local holder = Instance.new('Folder')
	holder.Name = name
	holder.Parent = parent
	local c = L:at(cf):into(holder)
	if build then
		local ok, err = pcall(build, c)
		if ok then return holder end
		warn('[Lobby] ' .. name .. ' builder failed, placeholder used: ' .. tostring(err))
		holder:ClearAllChildren()
	end
	local box = c:box('Placeholder', V(-size.X / 2, 0, size.Z0), V(size.X / 2, size.Y, size.Z1), color, M.SmoothPlastic)
	box.Transparency = 0.35
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front } do line(surface(box, face, 10), 'Text', label, P.white, FONT.loud, 0.2, 0.6, P.black, 2) end
	return holder
end
-- The ARMORY: the stepped gun stand on the east side of the spine (where the lobby reference has its podium and the
-- soldier game its gun stand), facing west to the spine: front step foot at x 19 (10 studs off the spine, like the
-- plaza opposite), centred on the cross arm (it ends at the stand's middle bay), two rows of five guns stepping up,
-- stairs at both ends, its back block running into the east wall (top 14: Armory.Step + Armory.BackWall). Its length
-- (78.4) is the activity band's.
Lobby.ArmoryAt = CFrame.lookAt(V(Lobby.Gap, 0, Lobby.CrossZ), V(0, 0, Lobby.CrossZ))
Lobby.ArmoryTitle = { Pos = V(Lobby.Gap + 38, 31, Lobby.CrossZ), W = 30, H = 6.8 } -- the floating ARMORY title, over the back block
-- LOBBY3: the stand's neutral tones in the floor's language (the paths' sand on its decks and walls, the border's
-- blues on its step, kicks and bands, pale trims), so the armory reads as one more sand island of the path network
-- instead of a lavender block. Only Armory.Tone's neutrals change, and only while it builds (the pads' state colours,
-- the cases and crates keep theirs). Lobby.ArmoryTone = nil keeps ARMORY's own tones.
Lobby.ArmoryTone = {
	deck = C(240, 222, 170), tread = C(246, 232, 186), trim = C(252, 246, 228), face = C(36, 112, 200),
	kick = C(26, 74, 150), riser = C(52, 128, 210), wall = C(232, 212, 162), band = C(22, 92, 182),
	pilaster = C(250, 240, 214), pad = C(238, 236, 244), plinth = C(40, 56, 100),
	frame = C(250, 244, 226), panel = C(238, 230, 210), bolt = C(184, 170, 140),
}
function Lobby.armory(L)
	local cf = Lobby.ArmoryAt
	local back = Lobby.W - Lobby.ArmoryAt.Position.X -- to the east wall
	local half = Armory and Armory.HalfWidth or 39.2
	local saved = {}
	if Armory and type(Armory.Tone) == 'table' and Lobby.ArmoryTone then
		for k, v in Lobby.ArmoryTone do saved[k] = Armory.Tone[k]; Armory.Tone[k] = v end
	end
	Lobby.place(L, L.parent, 'Armory', cf, { X = 2 * half, Y = 15, Z0 = 0, Z1 = back }, 'ARMORY', C(255, 90, 160),
		Armory and function(c) Armory.build(c, { backTo = back }) end)
	for k, v in saved do Armory.Tone[k] = v end
end
-- Where an east wall pillar (Lobby.hall) starts: on the armory's back block when the pillar's whole plinth stands on
-- it (the block's top), else on the floor (nil). The side pillars are spaced so no pillar straddles one of its ends.
function Lobby.eastDeckTop(z)
	if not Armory then return nil end
	local reach = math.abs(z - Lobby.ArmoryAt.Position.Z) + Lobby.PillarW / 2 + 0.7
	if reach <= Armory.HalfWidth then return Armory.Step + Armory.BackWall end
	return nil
end

-- The back block's top, behind the stand's back wall (seen from the high cameras and from above; LOBBY3: it read as
-- the hall's biggest bare slab from the top): the armory's stockroom. Pallet racks against the east wall in the two
-- bays between the east pillars that stand on the block (blue uprights, orange beams, two shelves of boxes, ammo crates
-- and gun cases), and in the open middle a forklift parked by rows of crate pallets. All of it is low enough (under
-- the line from the spawn's eye over the back wall's top) to stay out of every floor view, off every walk.
function Lobby.rack(c, len, dep, seed)
	local r = Random.new(seed)
	local up, beam, deck = C(40, 110, 200), C(255, 140, 30), C(170, 140, 100)
	local box = { C(200, 150, 92), C(184, 132, 80), C(104, 118, 78), C(58, 62, 74) }
	local hh = { 0.3, 1.9 } -- the two shelves
	for _, x in { -len / 2, len / 2 } do
		for _, z in { -dep / 2, dep / 2 } do c:box('RackUpright', V(x - 0.25, 0, z - 0.25), V(x + 0.25, 3.7, z + 0.25), up, M.SmoothPlastic) end
	end
	for _, y in hh do
		for _, z in { -dep / 2, dep / 2 } do c:box('RackBeam', V(-len / 2, y, z - 0.2), V(len / 2, y + 0.35, z + 0.2), beam, M.SmoothPlastic) end
		c:box('RackDeck', V(-len / 2 + 0.25, y + 0.1, -dep / 2 + 0.2), V(len / 2 - 0.25, y + 0.3, dep / 2 - 0.2), deck, M.SmoothPlastic)
		local x = -len / 2 + 0.5
		while x < len / 2 - 1.2 do
			local w = math.min(len / 2 - 0.4 - x, r:NextNumber(1.2, 2.1))
			local hgt = r:NextNumber(0.9, 1.35)
			c:box('RackBox', V(x, y + 0.3, -dep / 2 + 0.35), V(x + w, y + 0.3 + hgt, dep / 2 - 0.35), box[r:NextInteger(1, #box)], M.SmoothPlastic)
			x += w + r:NextNumber(0.15, 0.5)
		end
	end
end
function Lobby.forklift(c)
	local yel, dark, fork = C(255, 196, 40), C(46, 48, 58), C(120, 124, 136)
	c:box('ForkliftBody', V(-1.5, 0.6, -1.6), V(1.5, 2.2, 2.2), yel, M.SmoothPlastic)
	c:box('ForkliftWeight', V(-1.5, 0.6, 2.2), V(1.5, 2.6, 2.9), dark, M.SmoothPlastic)
	c:box('ForkliftSeat', V(-0.8, 2.2, 0.6), V(0.8, 2.7, 1.8), dark, M.SmoothPlastic)
	for _, x in { -1.3, 1.3 } do c:box('ForkliftPost', V(x - 0.15, 2.2, -1.2), V(x + 0.15, 4.6, -0.9), dark, M.SmoothPlastic) end
	for _, x in { -1.3, 1.3 } do c:box('ForkliftPost', V(x - 0.15, 2.2, 2.0), V(x + 0.15, 4.6, 2.3), dark, M.SmoothPlastic) end
	c:box('ForkliftRoof', V(-1.5, 4.6, -1.3), V(1.5, 4.85, 2.4), yel, M.SmoothPlastic)
	c:box('ForkliftMast', V(-1.1, 0.3, -2.1), V(1.1, 4.2, -1.6), dark, M.SmoothPlastic)
	for _, x in { -0.75, 0.75 } do c:box('ForkliftFork', V(x - 0.2, 0.25, -4.6), V(x + 0.2, 0.45, -2.1), fork, M.SmoothPlastic) end
	for _, x in { -1.55, 1.55 } do
		for _, z in { -1.0, 2.0 } do c:part('ForkliftWheel', V(0.5, 1.2, 1.2), CFrame.new(x, 0.6, z), C(30, 30, 34), M.SmoothPlastic, Enum.PartType.Cylinder) end
	end
end
function Lobby.stockroom(L)
	if not Armory then return end
	local W, Z = Lobby.W, Lobby.CrossZ
	local g = L:group('ArmoryStock')
	-- the block's top is fill like the hall floor: a studded court-blue deck inside the dark blue border ring
	local F = Lobby.Floor
	local b0, b1 = Z - Armory.HalfWidth, Z + Armory.HalfWidth
	local x0 = Lobby.Gap + Armory.Depth
	local y0 = Armory.Step + Armory.BackWall
	Lobby.slab(g, 'StockDeck', V(x0 + 1.6, y0 - 0.1, b0 + 1.6), V(W, y0 + 0.1, b1 - 1.6), F.court).CastShadow = false
	for _, e in { { x0, W, b0, b0 + 1.6 }, { x0, W, b1 - 1.6, b1 }, { x0, x0 + 1.6, b0 + 1.6, b1 - 1.6 } } do
		Lobby.slab(g, 'StockDeckBorder', V(e[1], y0 - 0.1, e[3]), V(e[2], y0 + 0.2, e[4]), F.border).CastShadow = false
	end
	local top = y0 + 0.1
	local x = W - Lobby.PillarD[1] - 0.9 - 2.2 -- the racks' centre line, clear of the pillars' plinths
	local k = 0
	for i = 1, #Lobby.SidePillars - 1 do
		local a, b = Lobby.SidePillars[i], Lobby.SidePillars[i + 1]
		local z = (a + b) / 2 -- (the bays between two pillars that stand on the block)
		if math.abs(z - Z) < Armory.HalfWidth - 6 then
			k += 1
			Lobby.rack(g:at(CFrame.new(x, top, z) * CFrame.Angles(0, math.pi / 2, 0)), b - a - Lobby.PillarW - 2.4, 3.2, 80 + k)
		end
	end
	-- the middle of the block: crate pallets in two rows and the forklift between them, gun cases by the back wall
	local mx = (Lobby.Gap + Armory.Depth + x - 2) / 2 + 1
	for _, z in { Z - 30, Z - 21, Z + 21, Z + 30 } do Lobby.crateStack(g:at(CFrame.new(mx, top, z) * CFrame.Angles(0, math.rad(z % 7 - 3), 0))) end
	Lobby.forklift(g:at(CFrame.new(mx + 0.5, top, Z - 6) * CFrame.Angles(0, math.rad(-12), 0)))
	for _, z in { Z + 6, Z + 9 } do
		g:part('GunCase', V(6, 1.1, 1.5), CFrame.new(mx, top + 0.55, z) * CFrame.Angles(0, math.rad(z - Z), 0), C(58, 62, 74), M.SmoothPlastic)
		g:part('GunCaseLatch', V(0.6, 0.3, 1.56), CFrame.new(mx, top + 0.7, z) * CFrame.Angles(0, math.rad(z - Z), 0), C(214, 186, 92), M.SmoothPlastic)
	end
	return g
end

---------------------------------------------------------------------------------------------- build
function Lobby.build(ctx, skins)
	table.clear(Lobby.Slots)
	local L, model = ctx:group('Lobby')
	model:SetAttribute('Area', 'Lobby')
	Lobby.hall(L)
	Lobby.floorPlan(L)
	Lobby.stand(L, skins)
	Lobby.shoeDais(L)
	Lobby.armory(L)
	Lobby.stockroom(L)
	Lobby.signs(L)
	Lobby.northBays(L)
	Lobby.hoodProps(L)
	Lobby.spawn(L)
	Lobby.Slots.NorthDoor = CFrame.new(0, 0, Lobby.N)
	Lobby.fill(L)
	-- the leaderboards in a row in the SE corner, at the end of their spur
	Lobby.leaderboards(L)
	return model
end
---------------------------------------------------------------------------------------------- ground
-- Light grey paving in 8-stud slabs over the whole walk, a darker cross-street band at every district
-- line, grass behind the buildings, the low boundary wall and the ring road with its cars and trees. The
-- warehouse lobby (e2_lobby) lays its own floor; out here there's only the forecourt between its door and
-- the Stage 1 gate, and grass round the building.
local function invisibleWall(c, a, b)
	local w = c:box('Boundary', a, b, P.white, M.SmoothPlastic)
	w.Transparency = 1
	w.CastShadow = false
	return w
end
local function buildGround(ctx)
	assert(Lobby, 'TheBlockV2: e2_lobby.lua (the warehouse lobby) is missing from the assembly')
	local g = ctx:group('Ground')
	-- Paving under the boss yard.
	local function pave(x0, x1, z0, z1)
		for x = x0, x1 - 1, 8 do
			for z = z0, z1 - 1, 16 do
				g:box('Paving', V(x, -1, z), V(math.min(x + 8, x1), 0, math.min(z + 16, z1)), ((x - x0) // 8 + (z - z0) // 16) % 2 == 0 and P.tileA or P.tileB, M.SmoothPlastic)
			end
		end
	end
	pave(-FRONT, FRONT, BOSS_END, BOSS_TOP)
	-- The stage street from the warehouse door to the boss yard, the reference's cross-section (P.street): studded
	-- dark asphalt with a yellow dashed centre line, raised studded sidewalks, studded grass out to the buildings.
	local ST = P.street
	local zA, zB = BOSS_TOP, Lobby.N - 1
	local road, walk = ST.road, ST.road + ST.walk
	sbox(g, 'Road', V(-road, -1, zA), V(road, 0, zB), P.st.road)
	for _, s in { -1, 1 } do
		sbox(g, 'Sidewalk', V(s * road, -1, zA), V(s * walk, ST.kerb, zB), P.st.walk)
		sbox(g, 'Grass', V(s * walk, -1, zA), V(s * FRONT, ST.kerb, zB), P.st.grass)
	end
	-- Centre dashes 1 x 4 every 16 studs, standing a little proud like the picture's (7..11 past each gate, ...).
	for z = -7, zA + 4, -16 do sbox(g, 'RoadDash', V(-0.5, 0, z - 4), V(0.5, 0.2, z), P.st.dash, true) end
	-- Second tones and finished edges: a darker gutter strip along each kerb, light kerb stones capping the sidewalk's
	-- road edge, darker slab joints across the sidewalk every 8 studs, and a darker green edging where the grass starts.
	for _, s in { -1, 1 } do
		sbox(g, 'RoadGutter', V(s * (road - 1.2), -0.5, zA), V(s * (road - 0.05), 0.03, zB), P.st.roadDark, true)
		sbox(g, 'KerbStone', V(s * (road - 0.05), -0.5, zA), V(s * (road + 1), ST.kerb + 0.08, zB), P.st.kerbStone, true)
		sbox(g, 'GrassEdge', V(s * walk, ST.kerb - 0.2, zA), V(s * (walk + 0.8), ST.kerb + 0.04, zB), P.st.grassEdge, true)
		local k = 0
		for z = zB - 8, zA + 1, -8 do
			decor(g:box('WalkJoint', V(s * (road + 1), ST.kerb - 0.1, z - 0.15), V(s * walk, ST.kerb + 0.02, z + 0.15), P.st.walkJoint, M.Plastic)).CastShadow = false
			-- every third slab a shade lighter, every fifth a shade darker (worn and newer paving)
			k += 1
			local tone = (k * (s > 0 and 2 or 1)) % 3 == 0 and P.st.walk:Lerp(P.white, 0.1) or (k % 5 == 0 and P.st.walk:Lerp(P.black, 0.07)) or nil
			if tone then decor(sbox(g, 'WalkSlab', V(s * (road + 1), ST.kerb - 0.1, z - 7.85), V(s * walk, ST.kerb + 0.025, z - 0.15), tone)).CastShadow = false end
		end
	end
	-- Grass behind the buildings and round the warehouse, inside the low boundary wall.
	local zIn0, zIn1 = BOSS_END - 6, SPAWN_TOP + 6
	for _, s in { -1, 1 } do
		g:box('Grass', V(s * (FRONT + DEPTH), -1, BOSS_END), V(s * WALL_X, 0.4, 0), P.grass, M.Grass)
		g:box('Grass', V(s * SPAWN_W, -1, 0), V(s * WALL_X, 0.4, SPAWN_TOP), P.grass, M.Grass)
		g:box('Grass', V(s * FRONT, -1, 0), V(s * SPAWN_W, 0.4, Lobby.N - 1), P.grass, M.Grass)
		g:box('Wall', V(s * WALL_X, -1, zIn0 - 1.4), V(s * (WALL_X + 1.4), 3, zIn1 + 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(s * (WALL_X - 0.2), 3, zIn0 - 1.6), V(s * (WALL_X + 1.6), 3.5, zIn1 + 1.6), P.kerb, M.Concrete)
	end
	g:box('Grass', V(-WALL_X, -1, SPAWN_TOP), V(WALL_X, 0.4, zIn1), P.grass, M.Grass)
	g:box('Grass', V(-FRONT - DEPTH, -1, zIn0), V(FRONT + DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(-WALL_X, -1, zIn0), V(-FRONT - DEPTH, 0.4, BOSS_END), P.grass, M.Grass)
	g:box('Grass', V(FRONT + DEPTH, -1, zIn0), V(WALL_X, 0.4, BOSS_END), P.grass, M.Grass)
	for _, e in { { zIn1, 1 }, { zIn0, -1 } } do
		g:box('Wall', V(-WALL_X, -1, e[1]), V(WALL_X, 3, e[1] + e[2] * 1.4), P.wall, M.Concrete)
		g:box('WallCap', V(-WALL_X + 0.2, 3, e[1] - e[2] * 0.2), V(WALL_X - 0.2, 3.5, e[1] + e[2] * 1.6), P.kerb, M.Concrete)
	end
	-- Ring road outside the wall: kerb, two lanes with a dashed centre line, kerb, a grass verge with
	-- trees. Each band runs down both long sides and across both ends; the ends take the corners.
	local road = ctx:group('RingRoad')
	local W0 = WALL_X + 1.4
	local zTop, zBot = zIn1 + 1.4, zIn0 - 1.4
	for _, band in { { 0, 4, P.kerb, M.Concrete, 0.4 }, { 4, 20, P.asphalt, M.Asphalt, 0 }, { 20, 24, P.kerb, M.Concrete, 0.4 }, { 24, 32, P.grass, M.Grass, 0.4 } } do
		local a, b, color, mat, top = band[1], band[2], band[3], band[4], band[5]
		for _, s in { -1, 1 } do road:box('Road', V(s * (W0 + a), -1, zBot - a), V(s * (W0 + b), top, zTop + a), color, mat) end
		road:box('Road', V(-(W0 + b), -1, zTop + a), V(W0 + b, top, zTop + b), color, mat)
		road:box('Road', V(-(W0 + b), -1, zBot - b), V(W0 + b, top, zBot - a), color, mat)
	end
	for _, s in { -1, 1 } do
		for z = zBot, zTop - 5, 10 do decor(road:box('RoadDash', V(s * (W0 + 11.8), 0, z), V(s * (W0 + 12.2), 0.04, z + 5), P.roadLine, M.SmoothPlastic)) end
	end
	for x = -(W0 + 8), W0 + 3, 10 do
		decor(road:box('RoadDash', V(x, 0, zTop + 11.8), V(x + 5, 0.04, zTop + 12.2), P.roadLine, M.SmoothPlastic))
		decor(road:box('RoadDash', V(x, 0, zBot - 12.2), V(x + 5, 0.04, zBot - 11.8), P.roadLine, M.SmoothPlastic))
	end
	-- Trees on the verge and behind the buildings, cars parked at the kerb.
	local seed = 900
	for _, s in { -1, 1 } do
		for z = zBot - 20, zTop + 20, 22 do
			seed += 1
			tree(road, V(s * (W0 + 28), 0.4, z), seed, 1.0, nil, true)
		end
		for z = BOSS_END + 20, -10, 30 do
			seed += 1
			tree(road, V(s * (FRONT + DEPTH + 3), 0.4, z), seed, 0.85, nil, true)
		end
	end
	for x = -(W0 + 20), W0 + 20, 22 do
		seed += 1
		tree(road, V(x, 0.4, zTop + 28), seed, 1.0, nil, true)
		tree(road, V(x, 0.4, zBot - 28), seed + 50, 1.0, nil, true)
	end
	local carColors = { C(252, 204, 40), P.white, C(214, 52, 52), C(52, 102, 214), C(252, 204, 40), C(230, 230, 232) }
	local spots = { { -1, 40 }, { -1, -110 }, { -1, -300 }, { -1, -520 }, { -1, -760 }, { -1, -980 }, { 1, 10 }, { 1, -190 }, { 1, -370 }, { 1, -610 }, { 1, -850 }, { 1, -1040 } }
	for k, sp in spots do
		car(road, CFrame.new(sp[1] * (W0 + 7.5), 0, sp[2]) * CFrame.Angles(0, sp[1] < 0 and math.pi or 0, 0), carColors[(k - 1) % #carColors + 1])
	end
	-- Keep players on the walk where no building closes it: round the warehouse (its walls already do, these
	-- go up past the eaves) and over the forecourt's wing walls.
	for _, s in { -1, 1 } do
		invisibleWall(g, V(s * SPAWN_W, 0, 0), V(s * (SPAWN_W + 1), 60, SPAWN_TOP))
		invisibleWall(g, V(s * 34.4, 0, 0.6), V(s * FRONT, 60, Lobby.N))
	end
	invisibleWall(g, V(-SPAWN_W, 0, SPAWN_TOP), V(SPAWN_W, 60, SPAWN_TOP + 1))
	invisibleWall(g, V(-FRONT, 0, BOSS_END - 1), V(FRONT, 30, BOSS_END))
	return g
end

---------------------------------------------------------------------------------------------- spawn
-- The spawn is the warehouse lobby (e2_lobby): shooting ranges, the EVOLUTIONS podium, the armory,
-- the spawn badge, FurthestPad and the leaderboards are all built there.
local function buildSpawn(ctx, skins)
	return Lobby.build(ctx, skins)
end
---------------------------------------------------------------------------------------------- stage gates
-- A gate at the start of every stage (and the boss yard), built to read from the lobby as LOCKED (BRIEF18): a
-- see-through red-tinted haze across the opening between the end buildings (deeper at the top, lighter at the foot,
-- so the street and the next gates show through it), two hazard-striped barrier bars across it and a big chunky
-- padlock hanging on the lower one (the video's locked gate), a lit lip and edges and a glowing emitter track along
-- its foot. Its frame follows the video game's gates: a sturdy studded pillar each side (plinth, a column of
-- recesses, banded cap) and a hazard-striped beam. The text is ONE floating sign in the opening (the video's): "STAGE
-- N" in white, "Recommended" / "Power: X" in cyan and a state line, in the game's heavy rounded font with a thick dark
-- outline; HoodClient/Stages shows it only on your next gate and grows it with distance, so it reads from the spawn.
-- Two pads stand on the sidewalks just before it, labelled up close: magenta on the left on to your furthest stage,
-- yellow on the right back to the lobby (the video's "+1 WIN / Return" pad); each a three-tone slab on a dark rim
-- with a neon edge and a few sparkles.
-- HoodClient/Stages keeps the wall solid and locked-looking while you're short (or the goons still stand), turns it
-- mint and drops the bars and padlock when you can pass, and clears it all once you have; StageService records the
-- clear and pays the reward.
local BOSS_RED = C(214, 44, 44)
local GATE = {
	H = 18.5, -- the wall's height (the reference's wall reaches the end buildings' second floor)
	pink = C(250, 160, 222), -- the gate's colour (attribute Color: the STAGE CLEARED banner)
	mint = C(150, 250, 190), -- what flies off when you break through (attribute Light: shards, burst)
	-- The locked haze from the top of the wall down: height above the street, colour, opacity. Deep crimson at the top
	-- (the "closed" read from far away), rose at eye level, where it is thin enough to see the street beyond.
	-- (The opacity only grows upward: the haze is drawn as stacked panes, each from the top down to its band.)
	haze = {
		{ 18.5, C(168, 24, 58), 0.78 }, { 16.5, C(186, 32, 68), 0.72 }, { 12.5, C(212, 54, 90), 0.62 },
		{ 8, C(230, 86, 120), 0.54 }, { 3, C(242, 122, 152), 0.5 }, { 0, C(246, 142, 168), 0.5 },
	},
	bands = 74, -- quarter-stud bands (5 px each at the haze's 20 pixels per stud)
	-- The game's text style (UI2's display face, the reference's Gotham Black): heavy letters with a thick near-black
	-- outline, colour by meaning: white STAGE N, cyan Recommended / Power (the video's #45E6FF), and the state line as a
	-- badge, white on red (locked, blocked) or green (open).
	font = Enum.Font.GothamBlack,
	title = C(255, 255, 255), titleInk = C(14, 16, 26),
	sub = C(69, 230, 255), subInk = C(8, 26, 46),
	status = C(255, 255, 255), statusInk = C(40, 6, 14), plate = C(214, 34, 58), plateInk = C(36, 8, 16),
	-- The sign: its size in studs where it stands and the height of its foot (just over the padlock; it grows upward
	-- from there, see HoodClient/Stages: GrowFrom studs, GrowPow, GrowMax, never past the openings in front of it), and
	-- its lines: name, top and height (0-1 of the sign) and outline thickness as a share of the line's height (UI2's:
	-- ~7% on titles, ~11% on small lines).
	signW = 26, signH = 9.6, signY = 7.4, grow = { 40, 1, 2.2 },
	lines = {
		{ 'Title', 0, 0.34, 0.075 }, { 'Sub', 0.355, 0.19, 0.11 }, { 'Power', 0.545, 0.19, 0.11 }, { 'Status', 0.79, 0.19, 0.11 },
	},
	plateBox = { 0.17, 0.765, 0.66, 0.235 }, -- the state badge behind the Status line: x, y, w, h (0-1 of the sign)
	magenta = C(255, 32, 255), yellow = C(250, 246, 70), padRim = C(58, 66, 98), -- the pads and the dark rim under them
	-- Each pad: its lit top, the darker sides, the neon edge between them.
	padLook = {
		magenta = { shade = C(184, 16, 186), rim = C(255, 178, 255) },
		yellow = { shade = C(204, 184, 24), rim = C(255, 255, 196) },
	},
	edge = C(255, 176, 196), -- the haze's lit lip along the top and its side edges
	-- The frame: studded concrete in three tones, dark recesses, a hazard beam with a darker lip.
	pillarW = 4, beamH = 3,
	stone = C(160, 162, 172), stoneDark = C(116, 118, 130), stoneLight = C(190, 192, 200), recess = C(62, 66, 80),
	hazard = C(250, 204, 40), hazardDark = C(36, 38, 46), hazardLip = C(196, 146, 28),
	steel = C(70, 74, 90), bolt = C(156, 160, 172), -- the plates clamping the beam to the pillars
	track = C(58, 66, 98), trackGlow = C(255, 96, 128), -- the emitter track along the foot and its glowing line
	-- The lock: two barrier rails low across the opening (bottom y, height; the stripes' width; the padlock hangs on
	-- the upper one) and the padlock (gold body in three tones, a dark keyhole, a steel shackle).
	bars = { { 1.6, 1.2 }, { 4.6, 1.3 } }, stripe = 1.5,
	gold = C(255, 196, 40), goldDark = C(206, 142, 18), goldLight = C(255, 232, 140), keyhole = C(64, 36, 8),
	shackle = C(196, 202, 216), shackleDark = C(132, 138, 156),
	titleShade = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 228, 240)), -- lighter top, deeper foot
}
-- Colour and opacity of the haze at height h (linear between the keys above).
function GATE.hazeAt(h)
	local k = GATE.haze
	for n = 1, #k - 1 do
		local a, b = k[n], k[n + 1]
		if h <= a[1] and h >= b[1] then
			local t = (a[1] - h) / (a[1] - b[1])
			return a[2]:Lerp(b[2], t), a[3] + (b[3] - a[3]) * t
		end
	end
	return k[#k][2], k[#k][3]
end
-- One line of the sign (y and h are 0-1 of its height), centred, outlined; HoodClient/Stages sets the outline's
-- thickness from the line's size on your screen (attribute Ink: the share of the line's height).
function GATE.text(gui, name, value, y, h, color, ink, share)
	local t = line(gui, name, value, color, GATE.font, y, h, ink, 3)
	t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
	t.TextWrapped = false
	t.ZIndex = 2
	t:SetAttribute('Ink', share)
	return t
end
-- One finished-edge frame over the haze (drawn above its bands).
function GATE.edgeFrame(gui, pos, size, transparency, z)
	local f = Instance.new('Frame')
	f.Name = 'Pane'
	f.BorderSizePixel = 0
	f.Position, f.Size = pos, size
	f.BackgroundColor3, f.BackgroundTransparency = GATE.edge, transparency
	f.ZIndex = z
	f:SetAttribute('BaseColor', GATE.edge)
	f:SetAttribute('BaseTransparency', transparency)
	f.Parent = gui
	return f
end
-- Black stripes slanting "/" across the approach face (at z) of a yellow bar from y to y + h, x -half..half: each
-- stripe two wedges, a parallelogram as wide as its slant (as on the beam).
function GATE.stripes(g, name, half, y, h, a, z)
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0))
	local n = math.floor((2 * half - 1.5) / (2 * a))
	local parts = {}
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a / 2, y + h / 2, z) * CFrame.Angles(0, math.pi, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a * 1.5, y + h / 2, z) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
	end
	return parts
end
-- The lock (only while the gate is shut for you; HoodClient/Stages hides every Lock* part once you can pass): two
-- hazard-striped barrier bars mounted across the haze's approach face, between the pillars, and a big padlock
-- hanging on the lower one in the middle, in front of everything (a gold body with a lighter lip, a darker foot and a
-- keyhole; a steel shackle over the bar).
function GATE.lock(g, inner)
	local parts = {}
	local function add(p) p.CastShadow = false; table.insert(parts, decor(p)); return p end
	for _, b in GATE.bars do
		local y, h = b[1], b[2]
		add(g:box('LockBar', V(-inner, y, 0.34), V(inner, y + h, 0.74), GATE.hazard, M.SmoothPlastic))
		add(g:box('LockBarLip', V(-inner, y - 0.12, 0.3), V(inner, y, 0.78), GATE.hazardLip, M.SmoothPlastic))
		for _, p in GATE.stripes(g, 'LockStripe', inner, y, h, GATE.stripe, 0.77) do add(p) end
	end
	local by = GATE.bars[2][1] -- the upper rail's foot: the body hangs under it, the shackle loops over it
	local x, y0, y1, z0, z1 = 2.3, by - 3.9, by - 0.1, 0.9, 2.3
	add(g:box('LockShackle', V(-1.75, by - 0.4, 1.3), V(-0.95, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(0.95, by - 0.4, 1.3), V(1.75, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(-1.75, by + 1.7, 1.3), V(1.75, by + 2.5, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackleShade', V(-1.75, by + 2.3, 1.25), V(1.75, by + 2.6, 1.95), GATE.shackleDark, M.SmoothPlastic))
	add(g:box('LockBody', V(-x, y0 + 0.6, z0), V(x, y1, z1), GATE.gold, M.SmoothPlastic))
	add(g:box('LockFoot', V(-x, y0, z0), V(x, y0 + 0.6, z1), GATE.goldDark, M.SmoothPlastic))
	add(g:box('LockLip', V(-x - 0.12, y1 - 0.45, z0 - 0.12), V(x + 0.12, y1, z1 + 0.12), GATE.goldLight, M.SmoothPlastic))
	local cy = (y0 + y1) / 2 + 0.15
	add(g:part('LockKeyhole', V(0.1, 1.1, 1.1), CFrame.new(0, cy + 0.25, z1 + 0.05) * CFrame.Angles(0, math.pi / 2, 0), GATE.keyhole, M.SmoothPlastic, Enum.PartType.Cylinder))
	add(g:box('LockKeyhole', V(-0.22, cy - 0.85, z1), V(0.22, cy + 0.2, z1 + 0.1), GATE.keyhole, M.SmoothPlastic))
	for _, p in parts do p:SetAttribute('BaseTransparency', p.Transparency) end
	return parts
end
-- The sign: one floating BillboardGui in the opening (the video's), on an invisible anchor at its foot, 5 studs in
-- front of the wall: a billboard is depth-tested as one flat card at its own depth, and from a player camera looking
-- down the beam and the pillar tops stand nearer than a card on the gate line (they would cut its title).
-- HoodClient/Stages shows it only on your next gate, writes the state line and grows it with the distance.
function GATE.sign(g, i, req)
	local anchor = ghost(g:part('SignAnchor', V(0.2, 0.2, 0.2), CFrame.new(0, GATE.signY, 5), P.white))
	local gui = Instance.new('BillboardGui')
	gui.Name = 'GateSign'
	gui.Size = UDim2.fromScale(GATE.signW, GATE.signH)
	gui.StudsOffsetWorldSpace = V(0, GATE.signH / 2, 0)
	gui.MaxDistance = 1000
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui:SetAttribute('BaseW', GATE.signW)
	gui:SetAttribute('BaseH', GATE.signH)
	gui:SetAttribute('GrowFrom', GATE.grow[1])
	gui:SetAttribute('GrowPow', GATE.grow[2])
	gui:SetAttribute('GrowMax', GATE.grow[3])
	gui.Parent = anchor
	local L = {}
	for _, l in GATE.lines do L[l[1]] = l end
	local function put(name, text, color, ink)
		return GATE.text(gui, name, text, L[name][2], L[name][3], color, ink, L[name][4])
	end
	local title = put('Title', i > STAGES and 'BOSS YARD' or ('STAGE ' .. i), GATE.title, GATE.titleInk)
	local grad = Instance.new('UIGradient')
	grad.Color, grad.Rotation = GATE.titleShade, 90
	grad.Parent = title
	put('Sub', 'Recommended', GATE.sub, GATE.subInk)
	put('Power', 'Power: ' .. compact(req), GATE.sub, GATE.subInk)
	-- The state line on its badge: locked (as built), "Defeat the goons first" while the stage before still has its
	-- goons (COMBAT's waves), "Open! Walk through" once you can pass (HoodClient/Stages writes it and the badge colour).
	-- (The badge and the line are siblings so every preview exporter places both in the sign's own frame.)
	local b = GATE.plateBox
	local plate = Instance.new('Frame')
	plate.Name = 'StatusPlate'
	plate.BorderSizePixel = 0
	plate.Position, plate.Size = UDim2.fromScale(b[1], b[2]), UDim2.fromScale(b[3], b[4])
	plate.BackgroundColor3, plate.BackgroundTransparency = GATE.plate, 0.08
	plate.ZIndex = 1
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = plate
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = GATE.plateInk, 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	plate.Parent = gui
	local status = put('Status', '🔒 Locked', GATE.status, GATE.statusInk)
	status.Position, status.Size = UDim2.fromScale(b[1] + 0.03, L.Status[2]), UDim2.fromScale(b[3] - 0.06, L.Status[3])
	return gui
end
-- The frame (stays up once you've cleared the gate): a pillar each side of the opening, standing on the gate line
-- in front of the end building's corner (inner face at x = +-inner, outer at +-outer), and the striped beam across
-- the top of the wall between them.
function GATE.frame(g, inner, outer, H)
	local top, half = H + GATE.beamH, 1.7
	for _, s in { -1, 1 } do
		local mid = s * (inner + outer) / 2
		g:box('GatePlinth', V(s * (inner - 0.3), 0, -half - 0.3), V(s * outer, 1.4, half + 0.3), GATE.stoneDark, M.Concrete)
		-- (The pillars rise a little over the beam, as in the video, so the gate reads as two posts and a lintel.)
		studs(g:box('GatePillar', V(s * inner, 1.4, -half), V(s * outer, top + 1.6, half), GATE.stone, M.Plastic), true)
		g:box('GateCapBand', V(s * (inner - 0.15), top + 1.6, -half - 0.15), V(s * outer, top + 2, half + 0.15), GATE.stoneDark, M.SmoothPlastic)
		studs(g:box('GateCap', V(s * (inner - 0.3), top + 2, -half - 0.3), V(s * outer, top + 2.7, half + 0.3), GATE.stoneLight, M.Plastic))
		-- A column of square recesses down the approach face, the back face and the face toward the road, each in a
		-- sunk channel: two lighter strips stand proud along its edges (the face reads as pilaster - channel - pilaster).
		for k = 0, 5 do
			local y = 3 + k * 2.55
			for _, f in { -1, 1 } do
				decor(g:box('GateRecess', V(mid - 0.6, y, f * half), V(mid + 0.6, y + 1.2, f * (half + 0.06)), GATE.recess, M.SmoothPlastic))
			end
			decor(g:box('GateRecess', V(s * (inner - 0.06), y, -0.6), V(s * inner, y + 1.2, 0.6), GATE.recess, M.SmoothPlastic))
		end
		for _, f in { -1, 1 } do
			for _, e in { inner, outer - 0.9 } do
				decor(g:box('GatePilaster', V(s * e, 1.4, f * half), V(s * (e + 0.9), H - 0.3, f * (half + 0.15)), GATE.stoneLight, M.SmoothPlastic))
			end
		end
		for _, zc in { -half + 0.6, half - 0.6 } do
			decor(g:box('GatePilaster', V(s * (inner - 0.15), 1.4, zc - 0.6), V(s * inner, H - 0.3, zc + 0.6), GATE.stoneLight, M.SmoothPlastic))
		end
	end
	-- The beam: yellow with a darker lip under and over it, black stripes slanting across its approach face (each
	-- stripe two wedges: a parallelogram as wide as its slant).
	g:box('GateBeam', V(-inner, H, -1.2), V(inner, top, 1.2), GATE.hazard, M.SmoothPlastic)
	for _, y in { H - 0.25, top } do
		g:box('GateBeamLip', V(-inner, y, -1.3), V(inner, y + 0.25, 1.3), GATE.hazardLip, M.SmoothPlastic)
	end
	-- A steel plate clamps each end of the beam to its pillar, front and back, with two bolts each.
	for _, s in { -1, 1 } do
		for _, f in { -1, 1 } do
			local z0, z1 = f * 1.2, f * 1.45
			g:box('GateClamp', V(s * (inner - 1.3), H - 0.3, z0), V(s * inner, top + 0.3, z1), GATE.steel, M.SmoothPlastic)
			for _, y in { H + 0.55, top - 0.95 } do
				decor(g:box('GateBolt', V(s * (inner - 0.85), y, z1), V(s * (inner - 0.45), y + 0.4, z1 + f * 0.12), GATE.bolt, M.SmoothPlastic))
			end
		end
	end
	local a, h = GATE.beamH, GATE.beamH
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0)) -- a wedge's triangle turned onto the XY plane
	local n = math.floor((2 * inner - 3) / (2 * a))
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		-- left half: right angle at the bottom right; right half: right angle at the top left (both slant "/"), on the
		-- approach face and (mirrored, so they read "/" from that side too) on the back
		for _, f in { 1, -1 } do
			local xa, xb = f * (x + a / 2), f * (x + a * 1.5)
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xa, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and math.pi or 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xb, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and 0 or math.pi, 0) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
		end
	end
end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local st = P.street or {}
	local road, walk, kerb, open, front = st.road or 8.5, st.walk or 8.5, st.kerb or 0.6, st.open or 22, st.front or FRONT
	local H = GATE.H
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	-- The pillars stand on the grass in front of the end buildings' corners; the wall spans the opening between them.
	local inner = open - GATE.pillarW
	GATE.frame(g, inner, open, H)
	-- The wall: an invisible collider across the opening (solid on the server; HoodClient/Stages lets you through
	-- once you have the Power), carrying the haze on its approach face.
	local barrier = g:box('Barrier', V(-inner, 0, -0.3), V(inner, H, 0.3), GATE.pink, M.SmoothPlastic)
	barrier.Transparency = 1
	barrier:SetAttribute('BaseTransparency', 1)
	barrier.CastShadow = false
	-- The haze: one pane per quarter-stud band, each running from the top of the wall down to its band, so band n
	-- shows panes n..last stacked (the haze is densest at the top). Each pane's colour and opacity are solved so the
	-- stack matches the band's colour exactly; no pane edge falls between two bands, so there are no seams.
	local haze = surface(barrier, Enum.NormalId.Back, 20)
	haze.Name = 'Haze'
	-- Finished edges: a brighter lip along the top and a soft lit edge down each side (above the bands; parented
	-- before them, see below).
	local side = 0.4 / (2 * inner)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3 / H), 0.5, GATE.bands + 1)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 2)
	GATE.edgeFrame(haze, UDim2.fromScale(1 - side, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 3)
	local pa, pc = 0, Vector3.zero -- the stack so far (the panes below this band's): opacity and premultiplied colour
	local panes = {}
	for n = GATE.bands - 1, 0, -1 do
		local color, alpha = GATE.hazeAt(H * (1 - (n + 0.5) / GATE.bands))
		-- (The boss yard's wall is denser: the Champ Ring's glow right behind it would drown it.)
		if i > STAGES then alpha = 1 - (1 - alpha) * 0.5 end
		alpha = math.max(alpha, pa)
		local a = pa < 1 and 1 - (1 - alpha) / (1 - pa) or 0
		local want = V(color.R, color.G, color.B) * alpha
		local c = a > 0.001 and (want - pc * (1 - a)) / a or V(color.R, color.G, color.B)
		c = V(math.clamp(c.X, 0, 1), math.clamp(c.Y, 0, 1), math.clamp(c.Z, 0, 1))
		pa, pc = alpha, c * a + pc * (1 - a)
		local paneColor = Color3.new(c.X, c.Y, c.Z)
		local f = Instance.new('Frame')
		f.Name = 'Pane'
		f.BorderSizePixel = 0
		f.Position, f.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, (n + 1) / GATE.bands)
		f.BackgroundColor3, f.BackgroundTransparency = paneColor, 1 - a
		f.ZIndex = GATE.bands - n
		f:SetAttribute('BaseColor', paneColor)
		f:SetAttribute('BaseTransparency', 1 - a)
		panes[n + 1] = f
	end
	-- (ZIndex sets the order in Roblox; parenting the top pane first also keeps preview exporters, which list frames
	-- in reverse, drawing them in the same order.)
	for n = 1, #panes do panes[n].Parent = haze end
	-- The lock: barrier bars and the padlock (Lock* parts).
	GATE.lock(g, inner)
	-- The sign (shown by HoodClient/Stages on your next gate only).
	GATE.sign(g, i, req)
	-- The field's foot: a dark emitter track along the ground on the approach side with a glowing line on top,
	-- stepping up onto the sidewalks (HoodClient/Stages tints and clears every Field* part with the haze).
	for _, seg in { { -inner, -road, kerb }, { -road, road, 0 }, { road, inner, kerb } } do
		local x0, x1, y = seg[1], seg[2], seg[3]
		local track = decor(g:box('FieldTrack', V(x0, y, 0.3), V(x1, y + 0.2, 0.95), GATE.track, M.SmoothPlastic))
		local glow = decor(g:box('FieldGlow', V(x0, y + 0.2, 0.54), V(x1, y + 0.27, 0.72), GATE.trackGlow, M.Neon))
		glow.CastShadow = false
		for _, p in { track, glow } do
			p:SetAttribute('BaseColor', p.Color)
			p:SetAttribute('BaseTransparency', 0)
		end
	end
	-- Pads on the sidewalks just before the wall (measured on the reference: ~6 x 11 with the dark rim, a 3-stud strip of
	-- pavement between them and the wall, 0.5 off the kerb): on to your furthest stage (magenta, left) and back to the
	-- lobby (yellow, right).
	local padW, padD = math.min(5.6, walk - 1.5), 11
	local padX, padZ = road + 0.5 + padW / 2, 3 + padD / 2
	if i > 1 then
		local function opts(look, title, sub, arrow)
			return { w = padW, d = padD, y = kerb, h = 0.25, material = M.SmoothPlastic, base = GATE.padRim, shade = look.shade,
				rim = look.rim, sparkle = true, title = title, sub = sub, labelColor = look.rim, font = GATE.font, arrow = arrow }
		end
		-- (Chevrons: on up the street for the furthest stage, back toward the hall for the lobby.)
		teleportPad(g, 'FurthestPad', -padX, padZ, GATE.magenta, 'Furthest', 'FURTHEST STAGE', opts(GATE.padLook.magenta, 'FURTHEST', 'Best stage', -1))
		teleportPad(g, 'LobbyPad', padX, padZ, GATE.yellow, 'Lobby', 'LOBBY', opts(GATE.padLook.yellow, 'LOBBY', 'Return', 1))
	end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-12, 16, -1), V(12, 17, 1), P.white))
	local fx = Instance.new('ParticleEmitter')
	fx.Name = 'PassFX'
	fx.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	fx:SetAttribute('PreviewTexture', 'confetti')
	fx.Enabled = false
	fx.Rate = 0
	fx.Lifetime, fx.Speed = NumberRange.new(1.6, 2.6), NumberRange.new(8, 18)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Acceleration = V(0, -18, 0)
	fx.Drag = 1.2
	fx.Size = NumberSequence.new(0.5)
	fx.RotSpeed, fx.Rotation = NumberRange.new(-260, 260), NumberRange.new(0, 360)
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GATE.magenta), ColorSequenceKeypoint.new(0.5, GATE.yellow), ColorSequenceKeypoint.new(1, P.white) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', 'HoodW1Stage' .. i)
	model:SetAttribute('Required', req)
	model:SetAttribute('Reward', math.max(10, math.floor(req * 0.2)))
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + padZ)
	model:SetAttribute('HalfWidth', front)
	model:SetAttribute('Color', GATE.pink)
	model:SetAttribute('Light', GATE.mint)
	-- The openings HoodClient/Stages fits a grown sign into: this gate's opening and frame outline, and (gate 1) the
	-- hall's doorway it is seen through from the lobby.
	model:SetAttribute('OpenHalf', inner)
	model:SetAttribute('OpenTop', H)
	model:SetAttribute('FrameHalf', open)
	model:SetAttribute('FrameTop', H + GATE.beamH + 2.7)
	if i == 1 and type(Lobby) == 'table' and type(Lobby.Door) == 'number' then
		model:SetAttribute('DoorHalf', Lobby.Door)
		model:SetAttribute('DoorTop', Lobby.DoorH or 30)
		model:SetAttribute('DoorZ', (Lobby.N or 6) + 0.9)
	end
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:AddTag('HoodStageGate')
	return model
end
---------------------------------------------------------------------------------------------- stages
-- Every stage is the reference street (ref1_street.png), copied 1:1 for now. buildGround lays the cross-section
-- (road, sidewalks, grass); each stage adds, measured from the picture (z' = studs past the stage's own gate):
--   z' 0..56   the open street: a plank fence along each front yard (|x| = 34.5) and a long two-storey brick
--              building behind it (fronts at |x| = 36);
--   z' 56..64  the end buildings come forward to |x| = 22 and run up to the next gate, whose wall fills the gap;
--   tall navy lamps (left at z' 19 and 53.5, right at 50), stacked-cube trees, low hedges, the green dumpster, blue
--   flowers and grass tufts, where the picture has them (P.street holds the numbers). The camera that matches the
--   picture stands at z' 2, 13.6 up, 1.1 right of the centre line, pitched 17.6 down, FOV 70. The picture's wall is
--   ~120 studs ahead and its narrowing starts ~85 out; ours are 62 and 54 (the stages are 64 long), so the far
--   things here sit closer together than in the picture while the near ones stand where the picture has them.
local function sideRow(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1])
		z -= lot[1]
	end
end
-- The end building on side s, from its front (z0, facing back up the street) to the next gate line (z1): solid from
-- |x| = open out to the back of the lots, windows on the strip of front that shows and on the side facing the road.
local function endBuilding(ctx, s, z0, z1, extra)
	local ST = P.street
	local w, d = FRONT + DEPTH - ST.open, z0 - z1
	local strip = FRONT - ST.open
	local inner = s < 0 and 'right' or 'left'
	-- A stone pillar on the inner front corner frames the narrowing: a darker base, a studded shaft, a darker cap.
	for _, zc in { z0 } do -- (GATES' own pillars frame the wall at the gate line)
		local f = zc == z0 and 1 or -1 -- (which way the corner's exposed face looks: back up the street, or on past the gate)
		local x0, x1 = s * (ST.open - 0.8), s * (ST.open + 1.2)
		local za, zb = zc - f * 1.2, zc + f * 0.8
		sbox(ctx, 'CornerPillarBase', V(x0 - s * 0.3, -0.5, za), V(x1, 2.8, zb + f * 0.3), P.st.trimDark)
		sbox(ctx, 'CornerPillar', V(x0, 2.8, za), V(x1, ST.eave + 2.4, zb), P.st.trim)
		sbox(ctx, 'CornerPillarCap', V(x0 - s * 0.3, ST.eave + 2.4, za), V(x1, ST.eave + 3.6, zb + f * 0.3), P.st.trimDark, true)
	end
	local o = { name = 'EndBuilding', depth = d, h = ST.eave + 2, run = math.min(5, d / 2 - 1), rise = 4, windows = {
		{ face = 'front', x = s < 0 and w - strip / 2 or strip / 2, w = 10 },
		{ face = inner, x = d / 2, w = math.min(10, d - 2) },
	}, gutters = { 'front', inner } }
	-- (extra: the district's own wall colour, storeys and roof)
	for k, v in extra or {} do o[k] = v end
	if o.floors and not (extra and extra.h) then o.h = nil end
	return brickBuilding(ctx:at(CFrame.new(s < 0 and -(FRONT + DEPTH) or ST.open, 0, z0)), w, o)
end
-- Stage plans. Stage 1 is the production section (art direction brief 15): a family of four brick houses that differ
-- in width, height, roofline, setback, entrance and window rhythm, with the fence opening onto paths at their doors.
-- Stages without a plan keep the measured reference street (one long block a side) until the districts are built.
-- A house: { w (along the street), front (|x| of its facade), options for brickBuilding }; rows run from z' 0.
local PLANS = {
	[1] = {
		L = {
			{ 24, 40, edge = 'wall', { name = 'House12', roof = 'gable', h = 27, bays = 3, winW = 5.6, wall = P.st.brickDeep, chimney = { 20.5, -9 },
				entrance = { x = 12, kind = 'stoop', door = C(40, 110, 76), number = '12' } } },
			{ 32, 36, { name = 'House14', roof = 'hip', h = 30, pilasters = 2, chimney = { 8, -15 }, ac = { { 'front', 26, 16.4 } } } },
		},
		R = {
			{ 22, 40, edge = 'picket', { name = 'House15', roof = 'gableFront', h = 26, bays = 3, winW = 4.4, wall = P.st.brickLight,
				entrance = { x = 11, kind = 'porch', span = { 1, 21 }, door = C(36, 60, 110), number = '15' } } },
			{ 34, 38, { name = 'House17', roof = 'flat', h = 31, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.5), ac = { { 'front', 5.7, 16.4 } },
				entrance = { x = 28.33, kind = 'door', door = C(170, 50, 50), number = '17' } } },
		},
		-- fence gateways (z' ranges) and the paver paths from the sidewalk to the steps (x end, z' centre)
		gates = { L = { { 10.5, 13.5 } }, R = { { 9.5, 12.5 }, { 26.2, 29.2 } } },
		paths = { { -35.7, 12 }, { 34.6, 11 }, { 35.2, 27.7 } },
	},
	-- Stage 2: a porch house and a long hip-roofed terrace on the left; a flat-roofed house, a side yard (shed, washing
	-- line) and a gabled stoop house on the right. (Paths stay out of MECHANICS' backstops: left z' 22..47, right 13..24.)
	[2] = {
		L = {
			{ 20, 40, edge = 'picket', { name = 'House22', roof = 'gableFront', h = 27, bays = 2, winW = 5.4, wall = P.st.brickLight,
				entrance = { x = 10, kind = 'porch', span = { 1, 19 }, door = C(170, 50, 50), number = '22' } } },
			{ 36, 36, { name = 'House24', roof = 'hip', h = 30, pilasters = 3, chimney = { 26, -12 }, ac = { { 'front', 6, 16.4 } } } },
		},
		R = {
			{ 24, 38, { name = 'House21', roof = 'flat', h = 29, bays = 2, winW = 7, wall = P.st.brickDeep,
				entrance = { x = 18, kind = 'door', door = C(36, 60, 110), number = '21' } } },
			{ 10, yard = true },
			{ 22, 41, edge = 'wall', { name = 'House25', roof = 'gable', h = 28, bays = 2, winW = 6, chimney = { 4, -8 },
				entrance = { x = 6, kind = 'stoop', door = C(40, 110, 76), number = '25' } } },
		},
		gates = { L = { { 8.5, 11.5 } }, R = { { 4.5, 7.5 }, { 48.5, 51.5 } } },
		paths = { { -34.6, 10 }, { 35.2, 6 }, { 36.7, 50 } },
	},
	-- Stage 3: a three-storey flat-roofed block and a chimneyed stoop house on the left; a front-gabled porch house, a
	-- side yard and a hip-roofed door house on the right.
	[3] = {
		L = {
			{ 28, 36, { name = 'House32', roof = 'flat', floors = 3, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.4), ac = { { 'front', 5, 31.4 } } } },
			{ 28, 41, edge = 'wall', { name = 'House34', roof = 'gable', h = 28, bays = 3, winW = 5, chimney = { 6, -9 }, wall = P.st.brickDeep,
				entrance = { x = 21, kind = 'stoop', door = C(130, 60, 160), number = '34' } } },
		},
		R = {
			{ 18, 40, edge = 'picket', { name = 'House31', roof = 'gableFront', h = 26, bays = 2, winW = 4.6, wall = P.st.brickLight,
				entrance = { x = 9, kind = 'porch', span = { 1, 17 }, door = C(40, 110, 76), number = '31' } } },
			{ 12, yard = true },
			{ 26, 38, { name = 'House35', roof = 'hip', h = 30, pilasters = 2, entrance = { x = 6, kind = 'door', door = C(200, 140, 40), number = '35' } } },
		},
		gates = { L = { { 47.5, 50.5 } }, R = { { 7.5, 10.5 }, { 48.5, 51.5 } } },
		paths = { { -36.7, 49 }, { 34.6, 9 }, { 35.2, 50 } },
	},
}
-- A side yard (between two houses, open to the street over a low picket fence): grass, a plank shed with a sloped
-- roof, a washing line with clothes, a small tree and a kettle grill, closed at the back by a tall wall.
local function sideYard(d, s, za, w, top, seed)
	local ST = P.street
	sbox(d, 'SideYard', V(s * FRONT, -1, za - w), V(s * 64, ST.kerb, za), P.st.grass)
	sbox(d, 'YardWall', V(s * 64, -1, za - w), V(s * 65.6, 14, za), P.st.brickDark)
	sbox(d, 'YardWallCoping', V(s * 63.7, 14, za - w), V(s * 65.9, 14.6, za), P.st.trim, true)
	local mz = za - w / 2
	local shed = d:at(CFrame.new(s * 58, ST.kerb, mz)):group('Shed')
	sbox(shed, 'ShedBody', V(-3.5, 0, -3), V(3.5, 6.4, 3), C(150, 110, 70))
	for z = -2.4, 2.5, 1.2 do decor(shed:box('ShedPlank', V(-s * 3.5 - 0.05, 0.2, z - 0.06), V(-s * 3.5 + s * 0.05, 6.2, z + 0.06), C(118, 84, 52), M.Plastic)) end
	sbox(shed, 'ShedDoor', V(-s * 3.5 - 0.1, 0, -1.2), V(-s * 3.5 + s * 0.1, 5.2, 1.2), C(110, 78, 48), true)
	studs(shed:wedge('ShedRoof', V(w - 3, 1.6, 8.4), CFrame.new(0, 7.2, 0) * CFrame.Angles(0, s > 0 and -math.pi / 2 or math.pi / 2, 0), P.st.roofDark, M.Plastic), true)
	for _, z in { za - 2, za - w + 2 } do
		sbox(d, 'LinePost', V(s * 44 - 0.25, ST.kerb, z - 0.25), V(s * 44 + 0.25, ST.kerb + 7, z + 0.25), C(200, 204, 210), true)
	end
	decor(d:box('WashLine', V(s * 44 - 0.06, ST.kerb + 6.6, za - w + 2), V(s * 44 + 0.06, ST.kerb + 6.72, za - 2), C(240, 240, 240), M.Plastic))
	local cloth = { C(240, 90, 90), C(80, 160, 240), P.white, C(250, 210, 60) }
	for k = 1, math.floor((w - 4) / 2.2) do
		local cz = za - 2 - k * 2.0
		decor(d:box('Laundry', V(s * 44 - 0.08, ST.kerb + 4.2 + (k % 2) * 0.6, cz - 0.8), V(s * 44 + 0.08, ST.kerb + 6.6, cz + 0.8), cloth[k % #cloth + 1], M.Plastic))
	end
	tree(d, V(s * 51, ST.kerb, za - w + 3), seed, 0.7)
	local grill = d:at(CFrame.new(s * 40, ST.kerb, mz)):group('Grill')
	for _, a in { 0, 2.1, 4.2 } do decor(grill:box('GrillLeg', V(math.cos(a) * 0.6 - 0.1, 0, math.sin(a) * 0.6 - 0.1), V(math.cos(a) * 0.6 + 0.1, 2.2, math.sin(a) * 0.6 + 0.1), C(30, 32, 36), M.Plastic)) end
	decor(grill:part('GrillBowl', V(1.8, 1.4, 1.8), CFrame.new(0, 2.7, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Ball))
end
-- A house frame like lotFrame, with the facade at |x| = front.
local function houseFrame(ctx, s, za, w, front)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-front, 0, za), V(-front - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(front, 0, za - w), V(front + 1, 0, za - w)))
end
-- A porch bench (seat, back, legs) and a terracotta pot with a cube plant, for doorsteps.
local function porchBench(c, cf)
	local b = c:at(cf):group('Bench')
	sbox(b, 'BenchSeat', V(-2.4, 1.4, -0.7), V(2.4, 1.8, 0.7), C(150, 104, 66))
	sbox(b, 'BenchBack', V(-2.4, 1.8, 0.4), V(2.4, 3.4, 0.7), C(150, 104, 66))
	for _, x in { -2.0, 2.0 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	return b
end
local function plantPot(c, pos, seed)
	local p = c:at(CFrame.new(pos)):group('PlantPot')
	sbox(p, 'Pot', V(-0.8, 0, -0.8), V(0.8, 1.3, 0.8), C(196, 104, 66))
	sbox(p, 'PotRim', V(-0.95, 1.1, -0.95), V(0.95, 1.4, 0.95), C(170, 86, 54), true)
	sbox(p, 'Plant', V(-0.7, 1.4, -0.7), V(0.7, 2.6 + (seed % 2) * 0.6, 0.7), P.st.leaf, true)
	return p
end

---------------------------------------------------------------------------------------------- districts
-- The district family (brief 15 section 5): every look keeps the street's cross-section, so the walk, GATES' gates
-- and MECHANICS' target bands (the sidewalks, and the grass strip |x| 16.5..19 at z' 13..47) work everywhere, and
-- changes what stands beside it, in the same studded kit: The Block (1-3, houses), Corner Shop (4-6, a T-junction
-- with a corner store), The Alley (7-9, tall walls, fire escapes, a sky bridge), The Courts (10-12, a fenced court on
-- the right), The Yards (13-15, a warehouse dock and a container yard). Open ground beside the street is closed by a
-- tall wall at |x| 64 so the walk can't go round a gate. z' = studs past the stage's gate (map z = gateZ - z').
local District = {}

-- The stage group with its (hidden) fight marker; at(x, z') is a point on the grass/sidewalk level.
function District.base(ctx, i)
	local top = stageTop(i)
	local d = ctx:group('Stage' .. i)
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	return d, top, function(x, zp) return V(x, P.street.kerb, top - zp) end
end
-- Flat studded ground (paving, a court, an apron) between |x| xa..xb on side s and z' za..zb, its top at y.
function District.floor(d, top, s, xa, xb, za, zb, y, color, name)
	return sbox(d, name or 'Paving', V(s * xa, y - 1.4, top - za), V(s * xb, y, top - zb), color)
end
-- A tall brick boundary wall along Z at |x| x (stone coping, darker plinth), closing open ground beside the street.
function District.backWall(d, top, s, x, za, zb, h)
	h = h or 14
	sbox(d, 'BackWall', V(s * x, -1, top - za), V(s * (x + 1.6), h, top - zb), P.st.brickDark)
	sbox(d, 'BackWallPlinth', V(s * (x - 0.3), -1, top - za), V(s * (x + 1.9), 1.6, top - zb), P.st.brickDark:Lerp(P.black, 0.15), true)
	sbox(d, 'BackWallCoping', V(s * (x - 0.3), h, top - za), V(s * (x + 1.9), h + 0.6, top - zb), P.st.trim, true)
end
-- Zebra stripes: n bars, each a x b studs, from p stepping by step (all in the stage frame), white studded paint.
function District.zebra(d, p, a, b, step, n)
	for k = 0, n - 1 do
		local q = p + step * k
		decor(sbox(d, 'Zebra', q - V(a / 2, 0.05, b / 2), q + V(a / 2, 0.14, b / 2), C(240, 240, 236))).CastShadow = false
	end
end
-- Traffic light: a navy pole with a collar, an arm over the road and a yellow three-lamp head facing +Z (the way the
-- player comes), red lit. dir = the arm's direction (+1 or -1 in x).
function District.trafficLight(d, pos, dir)
	local t = d:at(CFrame.new(pos)):group('TrafficLight')
	local col = P.st.lamp
	sbox(t, 'SignalBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), P.st.lampDark)
	sbox(t, 'SignalPole', V(-0.6, 1.2, -0.6), V(0.6, 17, 0.6), col)
	sbox(t, 'SignalArm', V(math.min(0, dir * 9), 15.6, -0.4), V(math.max(0, dir * 9), 16.4, 0.4), col, true)
	for _, hx in { dir * 1.6, dir * 8 } do
		local h = t:at(CFrame.new(hx, 0, 0))
		sbox(h, 'SignalHead', V(-0.9, 10.6 + (hx == dir * 1.6 and 0 or 2.6), -0.6), V(0.9, 15.4 + (hx == dir * 1.6 and 0 or 0.2), 0.6), C(240, 196, 40), true)
		local y0 = 10.6 + (hx == dir * 1.6 and 0 or 2.6)
		for k, c3 in { C(255, 60, 50), C(80, 70, 40), C(50, 70, 50) } do
			local lamp = decor(h:box('SignalLamp', V(-0.55, y0 + 4.8 - k * 1.5 - 0.15, 0.6), V(0.55, y0 + 4.8 - k * 1.5 + 0.95, 0.75), c3, k == 1 and M.Neon or M.Plastic))
			lamp.CastShadow = false
			decor(h:box('SignalHood', V(-0.65, y0 + 4.8 - k * 1.5 + 0.95, 0.6), V(0.65, y0 + 4.8 - k * 1.5 + 1.15, 1.2), C(30, 32, 38), M.Plastic))
		end
	end
	return t
end
-- Stop sign on a short pole: red octagon look (a square and a turned square), white border, facing +Z.
function District.stopSign(d, pos)
	local t = d:at(CFrame.new(pos)):group('StopSign')
	sbox(t, 'SignPole', V(-0.25, 0, -0.25), V(0.25, 8, 0.25), C(150, 154, 162))
	local face = sbox(t, 'StopFace', V(-1.3, 8, 0.25), V(1.3, 10.6, 0.5), C(220, 40, 40), true)
	decor(t:part('StopFace', V(2.6, 2.6, 0.24), CFrame.new(0, 9.3, 0.37) * CFrame.Angles(0, 0, math.rad(45)), C(220, 40, 40), M.Plastic))
	line(surface(face, Enum.NormalId.Back, 30), 'Stop', 'STOP', P.white, FONT.body, 0.28, 0.44)
	return t
end
-- Ice chest outside a shop: a white studded box with a blue lid and handle bar.
function District.iceBox(d, cf)
	local t = d:at(cf):group('IceBox')
	local body = sbox(t, 'IceBox', V(-2.4, 0, -1.2), V(2.4, 3.2, 1.2), C(236, 240, 246))
	sbox(t, 'IceLid', V(-2.5, 3.2, -1.3), V(2.5, 3.7, 1.3), C(40, 110, 220))
	sbox(t, 'IceHandle', V(-1, 3.7, -0.15), V(1, 4.0, 0.15), C(30, 60, 140), true)
	line(surface(body, Enum.NormalId.Front, 30), 'Ice', 'ICE', C(40, 110, 220), FONT.loud, 0.2, 0.6)
	return t
end
-- Bike rack: a low steel rail on feet with two loops, one or two bikes in it. Along local X.
function District.bikeRack(d, cf, bikes)
	local t = d:at(cf):group('BikeRack')
	sbox(t, 'RackRail', V(-3, 0, -0.2), V(3, 0.4, 0.2), C(150, 154, 162))
	for _, x in { -2.2, 0, 2.2 } do
		decor(t:box('RackLoop', V(x - 0.15, 0.4, -0.15), V(x + 0.15, 2.6, 0.15), C(170, 174, 182), M.Plastic))
		decor(t:box('RackLoopTop', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 2.9, 0.8), C(170, 174, 182), M.Plastic))
	end
	for k = 1, bikes or 1 do bike(t, CFrame.new(-1.1 + (k - 1) * 2.2, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0), ({ C(60, 140, 240), C(240, 90, 60) })[k]) end
	return t
end
-- Newspaper box: a small blue studded box on legs with a window.
function District.newsBox(d, cf, color)
	local t = d:at(cf):group('NewsBox')
	for _, x in { -0.8, 0.8 } do sbox(t, 'NewsLeg', V(x - 0.15, 0, -0.6), V(x + 0.15, 1.2, 0.6), P.iron, true) end
	sbox(t, 'NewsBody', V(-1.1, 1.2, -0.8), V(1.1, 4.2, 0.8), color or C(40, 90, 200))
	sbox(t, 'NewsWindow', V(-0.8, 2.6, -0.9), V(0.8, 3.8, -0.8), P.st.glassB, true)
	return t
end
-- A parked car in the studded kit: a two-tone body, glass band, darker skirt, four black wheels (front = local -Z).
function District.car(d, cf, color)
	local k = d:at(cf):group('ParkedCar')
	local dark = color:Lerp(P.black, 0.3)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -3.3, 3.3 } do decor(k:part('Wheel', V(0.9, 2.1, 2.1), CFrame.new(x, 1.05, z) * CFrame.Angles(0, 0, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	sbox(k, 'CarSkirt', V(-2.3, 0.7, -5.2), V(2.3, 1.6, 5.2), dark)
	sbox(k, 'CarBody', V(-2.3, 1.6, -5.2), V(2.3, 3.0, 5.2), color)
	sbox(k, 'CarCabin', V(-2.0, 3.0, -2.2), V(2.0, 4.8, 2.8), color)
	sbox(k, 'CarGlass', V(-2.05, 3.2, -2.25), V(2.05, 4.5, 2.85), P.st.glassA, true)
	sbox(k, 'CarRoof', V(-2.1, 4.8, -2.0), V(2.1, 5.1, 2.6), dark, true)
	for _, x in { -1.6, 1.6 } do
		decor(k:box('Headlight', V(x - 0.5, 2.0, -5.3), V(x + 0.5, 2.6, -5.2), C(255, 244, 200), M.Plastic))
		decor(k:box('TailLight', V(x - 0.5, 2.0, 5.2), V(x + 0.5, 2.6, 5.3), C(220, 40, 40), M.Plastic))
	end
	return k
end

-- Corner Shop (stages 4-6): a T-junction on the right with a corner store on one corner (shopfronts on both streets,
-- produce, an ice chest, a bike rack), shops with flats above down the left, zebra crossings, a traffic light and a
-- stop sign, the side street closing at a fence and a parked car.
District.SHOPS = {
	{ sign = 'BARBER', color = C(40, 80, 180), stripes = { C(220, 50, 50), P.white, C(40, 80, 180), P.white } },
	{ sign = 'PIZZA', color = C(200, 46, 40), stripes = { C(200, 46, 40), P.white }, text = C(255, 222, 80) },
	{ sign = 'LAUNDRY', color = C(60, 150, 200), stripes = { C(60, 150, 200), P.white } },
	{ sign = 'SNEAKERS', color = C(36, 36, 44), stripes = { C(36, 36, 44), C(240, 240, 240) } },
	{ sign = 'DELI', color = C(40, 130, 70), stripes = { C(40, 130, 70), C(250, 220, 90) } },
	{ sign = 'PHONES', color = C(130, 60, 200), stripes = { C(130, 60, 200), P.white } },
}
function District.corner(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local sa = ({ 28, 30, 27 })[t] -- the side street from z' sa to sa + 18, always on the right
	local sb = sa + 18
	local storeNear = t ~= 2
	-- Left: three shops with flats above, fronts at |x| 26 behind a paved forecourt.
	District.floor(d, top, -1, ST.road + ST.walk, 26, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	local lw = ({ { 20, 20, 16 }, { 16, 22, 18 }, { 22, 16, 18 } })[t]
	local z = top
	for k = 1, 3 do
		local sh = District.SHOPS[(i + k) % #District.SHOPS + 1]
		local w = lw[k]
		local floors = (k + t) % 3 == 0 and 3 or 2
		brickBuilding(houseFrame(d, -1, z, w, 26), w, { name = 'Shop' .. k, floors = floors, depth = 38, roof = ({ 'flat', 'gable', 'hip' })[(k + t) % 3 + 1],
			wall = ({ P.st.brick, P.st.brickDeep, P.st.brickLight })[(k + i) % 3 + 1], bays = 2, winW = w / 2 - 4.6,
			shops = { { x0 = 1.6, x1 = w - 1.6, door = w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } } })
		z -= w
	end
	-- Right: the corner store, the side street, the far corner shop.
	local function rightBuilding(z0, z1, store, corner)
		local w = z1 - z0 -- (z0 < z1: z' runs away from the gate)
		local sh = store and { sign = 'CORNER STORE', color = C(30, 120, 60), stripes = { C(30, 120, 60), C(250, 214, 60) } } or District.SHOPS[(i + 4) % #District.SHOPS + 1]
		-- (right side: local x runs back up the street, so the side street side is 'left' for the near corner, 'right'
		-- for the far one)
		local shops = { { x0 = 1.6, x1 = w - 1.6, door = corner == 'left' and 4 or w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } }
		-- (the side face's local x runs from the back to the street on the 'left' face, from the street back on 'right')
		local near = corner == 'left' and function(a) return 40 - a end or function(a) return a end
		if store then table.insert(shops, { face = corner, x0 = math.min(near(3), near(18)), x1 = math.max(near(3), near(18)), door = near(15), sign = '24/7', color = sh.color, stripes = sh.stripes }) end
		brickBuilding(houseFrame(d, 1, top - z0, w, 24), w, { name = store and 'CornerStore' or 'CornerShop', floors = store and 2 or 3, roof = 'flat',
			wall = store and P.st.brickLight or P.st.brick, bays = 2, winW = w / 2 - 4.6, shops = shops, depth = 40,
			windows = (function()
				local list = { { face = 'front', x = w * 0.25, w = w / 2 - 4.6 }, { face = 'front', x = w * 0.75, w = w / 2 - 4.6 } }
				if store then table.insert(list, { face = corner, x = near(10.5), w = 12 }); table.insert(list, { face = corner, x = near(29), w = 12 }) end
				return list
			end)() })
	end
	District.floor(d, top, 1, ST.road + ST.walk, 24, 0, sa, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	District.floor(d, top, 1, ST.road + ST.walk, 24, sb, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	rightBuilding(0, sa, storeNear, 'left')
	rightBuilding(sb, 56, not storeNear, 'right')
	-- The side street: asphalt at sidewalk level between two narrow sidewalks with kerb stones, a zebra across its
	-- mouth, a fence and barriers at its dead end, the back wall behind, a parked car.
	local rx = ST.road + ST.walk
	District.floor(d, top, 1, rx, 62, sa + 3.4, sb - 3.4, ST.kerb + 0.05, P.st.road, 'SideRoad')
	for _, e in { { sa, sa + 3 }, { sb - 3, sb } } do
		District.floor(d, top, 1, rx, 62, e[1], e[2], ST.kerb + 0.3, P.st.walk, 'SideWalk')
		local kz = e[1] == sa and sa + 3 or sb - 3.4
		District.floor(d, top, 1, rx, 62, kz, kz + 0.4, ST.kerb + 0.36, P.st.kerbStone, 'SideKerb')
	end
	District.zebra(d, V(19.6, ST.kerb + 0.05, top - (sa + 3.4) - 1.2), 4, 1, V(0, 0, -2), 5)
	District.zebra(d, V(-7, 0, top - (sa - 4)), 1.4, 5, V(2, 0, 0), 8)
	decor(sbox(d, 'StopLine', V(-8.4, -0.05, top - (sa - 7.3)), V(8.4, 0.14, top - (sa - 6.7)), C(240, 240, 236))).CastShadow = false
	chainLink(d, V(58, ST.kerb, top - sa), V(58, ST.kerb, top - sb), 12)
	for k = 0, 2 do
		local bz = top - (sa + 4.5 + k * 4.5)
		sbox(d, 'Barrier', V(54.6, ST.kerb, bz - 1.9), V(56.4, ST.kerb + 3, bz + 1.9), C(206, 208, 214))
		for q = 0, 1 do sbox(d, 'BarrierStripe', V(54.5, ST.kerb + 1.2 + q * 1.2, bz - 1.95), V(56.5, ST.kerb + 1.8 + q * 1.2, bz + 1.95), C(220, 50, 50), true) end
	end
	District.backWall(d, top, 1, 62.4, sa, sb)
	District.car(d, CFrame.new(at(38, sa + 6.6)) * CFrame.Angles(0, math.rad(storeNear and 90 or -90), 0), ({ C(250, 200, 40), C(230, 230, 236), C(52, 110, 220) })[t])
	-- Corner furniture: the traffic light on the near corner, a stop sign facing the side street, a lamp a side.
	District.trafficLight(d, at(17.2, sa - 1.2), -1)
	District.stopSign(d, at(19.8, sb + 1.2))
	lantern(d, at(-20.5, 12), V(1, 0, 0))
	lantern(d, at(21, 9), V(-1, 0, 0))
	hydrant(d, at(-20.2, 51))
	-- The store's front: produce on pallets under the awning, the ice chest, a bike rack, a news box (clear of the
	-- targets' backstop on the right grass, x 17.8..19, z' 13..23.5).
	storeCrates(d, CFrame.new(at(22.2, storeNear and 7 or sb + 9)) * CFrame.Angles(0, math.rad(90), 0), 2)
	District.iceBox(d, CFrame.lookAt(at(22, storeNear and 24.8 or sb + 4), at(10, storeNear and 24.8 or sb + 4)))
	District.bikeRack(d, CFrame.new(at(26, sa + 1.4)) * CFrame.Angles(0, 0, 0), 2)
	District.newsBox(d, CFrame.lookAt(at(21.6, storeNear and 3.6 or sb + 2.4), at(10, storeNear and 3.6 or sb + 2.4)))
	-- Left shop props: a bench and bins, out of the left target band (z' 22..48 by the sidewalk).
	trashBags(d, CFrame.new(at(-24, 8)) * CFrame.Angles(0, 0.6, 0), 2)
	wheelieBin(d, CFrame.new(at(-24.4, 16)) * CFrame.Angles(0, math.pi, 0), C(40, 90, 160))
	storeCrates(d, CFrame.new(at(-23, 51)) * CFrame.Angles(0, math.rad(90), 0), 1)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brick, roof = 'flat', floors = 3 })
	-- street: a manhole and a drain
	decor(sbox(d, 'Manhole', V(-3.4, -0.2, top - 14 - 1.2), V(-1.0, 0.08, top - 14 + 1.2), P.st.manhole)).CastShadow = false
	return d
end

-- The Alley (stages 7-9): tall brick walls close in to |x| 20 on both sides (three and four storeys, flat roofs),
-- fire escapes, a glazed sky bridge across the alley, cables strung with bulbs overhead, service recesses with a
-- dumpster and a back door, wall lamps, bins along a paved gutter strip, puddles on the asphalt.
function District.alley(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local F = 20 -- the facades
	District.floor(d, top, -1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	District.floor(d, top, 1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	for _, s in { -1, 1 } do
		decor(sbox(d, 'GutterChannel', V(s * (ST.road + ST.walk), ST.kerb + 0.02, top), V(s * (ST.road + ST.walk + 0.7), ST.kerb + 0.1, top - 56), P.st.roadDark)).CastShadow = false
	end
	-- Each side: a tall block, a service recess (a one-storey back building 10 further back), another block.
	local plan = ({
		{ L = { { 0, 14, 4 }, { 14, 24, 'recess' }, { 24, 56, 3 } }, R = { { 0, 30, 3 }, { 30, 40, 'recess' }, { 40, 56, 4 } }, esc = { L = 1, R = 3 } },
		{ L = { { 0, 20, 3 }, { 20, 30, 'recess' }, { 30, 56, 4 } }, R = { { 0, 26, 4 }, { 26, 36, 'recess' }, { 36, 56, 3 } }, esc = { L = 3, R = 1 } },
		{ L = { { 0, 12, 3 }, { 12, 22, 'recess' }, { 22, 56, 4 } }, R = { { 0, 34, 4 }, { 34, 44, 'recess' }, { 44, 56, 3 } }, esc = { L = 3, R = 1 } },
	})[t]
	local walls = { P.st.brickDeep, P.st.brickDark:Lerp(P.st.brick, 0.5), P.st.brick, P.st.brickLight }
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	for _, s in { -1, 1 } do
		local side = s < 0 and 'L' or 'R'
		for k, b in plan[side] do
			local z0, z1 = b[1], b[2]
			local w = z1 - z0
			local za = top - z0
			if b[3] == 'recess' then
				-- the recess: paved, a one-storey back building with a door, a dumpster and bags
				District.floor(d, top, s, F, F + 10.2, z0, z1, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.18), 'RecessFloor')
				brickBuilding(houseFrame(d, s, za, w, F + 10), w, { name = 'BackBuilding', floors = 1, h = 13, roof = 'flat', depth = 34, wall = P.st.brickDark,
					windows = {}, entrance = { x = w / 2, kind = 'door', door = C(70, 76, 90), number = tostring(20 + i) } })
				-- (turned to run along the back wall, its front toward the way the player comes)
				dumpster(d, CFrame.new(V(s * (F + 5.2), ST.kerb + 0.08, top - (z0 + 3.4))) * CFrame.Angles(0, math.rad(90), 0))
				trashBags(d, CFrame.new(V(s * (F + 5.6), ST.kerb + 0.08, top - (z0 + 7.8))), 3)
			else
				local floors = b[3]
				local esc = plan.esc[side] == k
				local wall = walls[(k + i + (s > 0 and 1 or 0)) % #walls + 1]
				local tag = TAGS[(i + k) % #TAGS + 1]
				local n = math.max(2, math.floor(w / 8))
				-- (local x runs down the street on the left, back up it on the right)
				local function lx(zp) return s < 0 and zp - z0 or z1 - zp end
				local doorZ = s < 0 and (z0 < 20 and z0 + 5 or z1 - 4) or (z1 > 26 and z1 - 4 or z0 + 4)
				local okDoor = not (s < 0 and doorZ > 21 and doorZ < 48) and not (s > 0 and doorZ > 12 and doorZ < 25)
				brickBuilding(houseFrame(d, s, za, w, F), w, { name = 'AlleyBlock', floors = floors, roof = 'flat', depth = 44, wall = wall, bays = n, winW = math.min(6, w / n - 3),
					fireEscapes = esc and { { x = w / 2, w = math.min(12, w - 4) } } or nil,
					entrance = okDoor and { x = lx(doorZ), kind = 'door', door = C(60, 66, 80), number = tostring(i * 10 + k) } or nil,
					ac = { { 'front', w * 0.3, 16.5 }, floors > 3 and { 'front', w * 0.7, 31.5 } or nil },
					tags = k == 1 and { { 'front', w * 0.5, 9.6, tag[1], tag[2] } } or nil })
			end
		end
	end
	-- The sky bridge: a glazed brick link across the alley at the second floor, a stone sill and slate roof.
	local bz = ({ 32, 22, 40 })[t]
	local bridge = d:group('SkyBridge')
	local y0, y1 = 21, 30
	sbox(bridge, 'BridgeFloor', V(-F, y0 - 1.2, top - bz), V(F, y0, top - (bz + 8)), P.st.trim)
	sbox(bridge, 'BridgeWall', V(-F, y0, top - bz - 0.2), V(F, y0 + 2.4, top - (bz + 7.8)), walls[(i % 4) + 1])
	sbox(bridge, 'BridgeWall', V(-F, y1 - 1.6, top - bz - 0.2), V(F, y1, top - (bz + 7.8)), walls[(i % 4) + 1])
	for _, zf in { bz + 0.25, bz + 7.75 } do
		sbox(bridge, 'BridgeGlass', V(-F, y0 + 2.4, top - zf - 0.15), V(F, y1 - 1.6, top - zf + 0.15), P.st.glassA, true)
		for x = -F + 4, F - 3, 4 do sbox(bridge, 'BridgeMullion', V(x - 0.35, y0 + 2.4, top - zf - 0.3), V(x + 0.35, y1 - 1.6, top - zf + 0.3), P.st.mullion, true) end
	end
	sbox(bridge, 'BridgeRoof', V(-F, y1, top - bz + 0.6), V(F, y1 + 0.8, top - (bz + 8.6)), P.st.roofDark)
	sbox(bridge, 'BridgeFascia', V(-F, y1 - 0.2, top - bz + 0.7), V(F, y1 + 1.0, top - bz + 0.3), P.st.trim, true)
	for _, s in { -1, 1 } do
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 1), V(s * (F - 4), y0 - 1.2, top - bz - 1), 0.6, C(46, 50, 60), M.Plastic))
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 7), V(s * (F - 4), y0 - 1.2, top - bz - 7), 0.6, C(46, 50, 60), M.Plastic))
	end
	-- Two pipes across at the top, on brackets.
	local pz = ({ 12, 46, 14 })[t]
	for k, py in { 41, 42.4 } do
		decor(d:rod('Pipe', 0.5, 2 * F, CFrame.new(0, py, top - pz - k * 1.3), k == 1 and C(150, 154, 162) or C(196, 120, 60), M.Plastic))
	end
	-- Cables with bulbs, sagging from wall to wall.
	for k, cz in ipairs(({ { 6, 10, 36 }, { 8, 34, 48 }, { 4, 26, 50 } })[t]) do
		local yA, yB, sag = 38 - k * 3, 37 - k * 3, 2.4
		local a, b = V(-F, yA, top - cz), V(F, yB, top - cz - 5)
		local mid = (a + b) / 2 - V(0, sag, 0)
		decor(d:bar('Cable', a, mid, 0.15, C(30, 32, 38), M.Plastic))
		decor(d:bar('Cable', mid, b, 0.15, C(30, 32, 38), M.Plastic))
		for q = 1, 9 do
			local u = q / 10
			local p = u < 0.5 and a:Lerp(mid, u * 2) or mid:Lerp(b, (u - 0.5) * 2)
			local bulb = decor(d:box('Bulb', p - V(0.3, 0.75, 0.3), p - V(-0.3, 0.15, -0.3), ({ C(255, 214, 120), C(255, 120, 160), C(120, 220, 255) })[q % 3 + 1], M.Neon))
			bulb.CastShadow = false
		end
	end
	-- Wall lamps on brackets, bins along the gutter strip (clear of the targets' backstops), puddles.
	for k, lp in ipairs({ { -1, 10 }, { 1, 8 }, { -1, 50 }, { 1, 44 } }) do
		local s, zp = lp[1], lp[2]
		local base = V(s * F, 13, top - zp)
		local arm = sbox(d, 'WallLampArm', base + V(-s * 0, 0, -0.2), base + V(-s * 1.8, 0.4, 0.2), C(46, 50, 60), true)
		sbox(d, 'WallLampHead', base + V(-s * 1.2, -1.0, -0.6), base + V(-s * 2.4, 0.2, 0.6), C(46, 50, 60), true)
		decor(d:box('WallLampGlow', base + V(-s * 1.35, -1.2, -0.45), base + V(-s * 2.25, -1.0, 0.45), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	for _, b in ipairs({ { -1, 4 }, { -1, 8 }, { 1, 30 }, { 1, 47 }, { -1, 51 } }) do
		wheelieBin(d, CFrame.new(V(b[1] * 18.4, ST.kerb + 0.08, top - b[2])) * CFrame.Angles(0, b[1] < 0 and math.pi or 0, 0), ({ C(40, 120, 70), C(40, 90, 160), C(70, 74, 84) })[(b[2] + i) % 3 + 1])
	end
	for _, pd in ipairs({ { -3, 18, 4, 3 }, { 4, 37, 3, 5 }, { -5, 50, 3, 2.5 } }) do
		decor(d:box('Puddle', V(pd[1] - pd[3] / 2, -0.05, top - pd[2] - pd[4] / 2), V(pd[1] + pd[3] / 2, 0.06, top - pd[2] + pd[4] / 2), C(70, 90, 120), M.Glass)).Transparency = 0.3
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDark:Lerp(P.st.brick, 0.5), roof = 'flat', floors = 4 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 4 })
	return d
end

-- Basketball hoop on a frame whose +Z faces the court: a padded post, an arm, a white backboard with a red square,
-- an orange rim and a white net.
function District.hoop(d, cf)
	local h = d:at(cf):group('Hoop')
	sbox(h, 'HoopBase', V(-1.2, 0, -1.2), V(1.2, 1, 1.2), C(46, 50, 60))
	sbox(h, 'HoopPost', V(-0.5, 1, -0.5), V(0.5, 11.5, 0.5), C(60, 66, 80))
	sbox(h, 'HoopPad', V(-0.8, 1, -0.8), V(0.8, 5, 0.8), C(40, 90, 200), true)
	sbox(h, 'HoopArm', V(-0.35, 10.6, 0), V(0.35, 11.2, 2.6), C(60, 66, 80), true)
	sbox(h, 'Backboard', V(-3, 9.2, 2.6), V(3, 13, 3), P.white, true)
	decor(h:box('BoardSquare', V(-1.1, 9.9, 3), V(1.1, 11.3, 3.1), C(220, 60, 50), M.Plastic))
	for q = 0, 7 do
		local a = q / 8 * math.pi * 2
		decor(h:part('Rim', V(0.8, 0.15, 0.18), CFrame.new(math.cos(a) * 0.95, 9.6, 4.1 + math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), C(240, 110, 40), M.Plastic))
		decor(h:bar('Net', V(math.cos(a) * 0.9, 9.55, 4.1 + math.sin(a) * 0.9), V(math.cos(a) * 0.5, 8.4, 4.1 + math.sin(a) * 0.5), 0.08, P.white, M.Plastic))
	end
	return h
end
-- Floodlight pole: a dark base, a tall pole and a head of four lamps turned toward the court (-Z of the frame, as
-- CFrame.lookAt aims it).
function District.floodlight(d, cf, h)
	h = h or 26
	local f = d:at(cf):group('Floodlight')
	sbox(f, 'FloodBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), C(46, 50, 60))
	sbox(f, 'FloodPole', V(-0.5, 1.2, -0.5), V(0.5, h, 0.5), C(150, 156, 166))
	sbox(f, 'FloodFrame', V(-2.6, h, -0.6), V(2.6, h + 3, 0.6), C(60, 66, 80), true)
	for _, x in { -1.3, 1.3 } do for _, y in { h + 0.75, h + 2.25 } do
		decor(f:box('FloodLamp', V(x - 1, y - 0.6, -0.8), V(x + 1, y + 0.6, -0.6), C(250, 248, 230), M.Neon)).CastShadow = false
	end end
	return f
end
-- Bleachers along Z on side s: three studded aluminium tiers stepping up away from the court (x0 = the front edge),
-- blue seat boards and a back rail.
function District.bleachers(d, top, s, x0, za, zb)
	local g = d:group('Bleachers')
	for k = 0, 2 do
		local xa, xb = x0 + k * 1.8, x0 + 6
		sbox(g, 'BleacherTier', V(s * xa, P.street.kerb, top - za), V(s * xb, P.street.kerb + 1.4 * (k + 1), top - zb), C(186, 192, 204))
		sbox(g, 'BleacherSeat', V(s * (xa + 0.2), P.street.kerb + 1.4 * (k + 1), top - za - 0.3), V(s * (xa + 1.2), P.street.kerb + 1.4 * (k + 1) + 0.4, top - zb + 0.3), C(40, 90, 200), true)
	end
	decor(g:box('BleacherRail', V(s * (x0 + 5.8), P.street.kerb + 6.6, top - za), V(s * (x0 + 6), P.street.kerb + 6.9, top - zb), C(150, 156, 166), M.Plastic))
	for z = za, zb, (zb - za) / 4 do decor(g:box('BleacherRailPost', V(s * (x0 + 5.8), P.street.kerb + 4.2, top - z - 0.1), V(s * (x0 + 6), P.street.kerb + 6.6, top - z + 0.1), C(150, 156, 166), M.Plastic)) end
	return g
end

-- The Courts (stages 10-12): the right side opens onto a fenced basketball court (hoops, lines, bleachers, benches,
-- floodlights, a mural wall behind), an apartment block with balconies on the left, trees on its grass.
District.COURTS = {
	{ court = C(226, 120, 52), key = C(196, 92, 40), ground = C(60, 128, 92) },
	{ court = C(52, 112, 210), key = C(36, 86, 170), ground = C(84, 92, 110) },
	{ court = C(196, 60, 60), key = C(160, 44, 44), ground = C(46, 70, 120) },
}
function District.courts(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local K = District.COURTS[t]
	-- Left: apartments with balconies (three storeys), a front garden strip with trees.
	local lw = ({ { 30, 26 }, { 24, 32 }, { 28, 28 } })[t]
	local z = top
	District.floor(d, top, -1, FRONT, 40, 0, 56, ST.kerb, P.st.grass, 'Yard')
	for k = 1, 2 do
		local w = lw[k]
		brickBuilding(houseFrame(d, -1, z, w, 40), w, { name = 'Apartments', floors = 3, roof = k == 1 and 'flat' or 'hip', pilasters = math.max(2, math.floor(w / 10)),
			wall = ({ P.st.brickLight, P.st.brick, P.st.brickDeep })[(k + t) % 3 + 1], depth = 24,
			balconies = { { x = w / 2, w = 8 } }, entrance = { x = k == 1 and 5 or w - 5, kind = 'stoop', door = ({ C(40, 110, 76), C(36, 60, 110), C(170, 50, 50) })[(k + t) % 3 + 1], number = tostring(100 + i * 2 + k) } })
		z -= w
	end
	-- the plank fence opens at both stoops, with paver paths across the grass
	fence(d, -ST.fence, top, top - ST.endZ, 1, nil, { { top - 3.2, top - 6.8 }, { top - 49.2, top - 52.8 } })
	for _, zc in { 5, 51 } do
		for x = ST.road + ST.walk, 34.4, 2 do sbox(d, 'Paver', V(-x, ST.kerb - 0.3, top - zc + 1.5), V(-math.min(x + 1.9, 34.5), ST.kerb + 0.07, top - zc - 1.5), (x // 2) % 2 == 0 and P.st.kerbStone or P.st.sill) end
	end
	for k, zp in ipairs({ 9, 30, 52 }) do tree(d, at(-26.5, zp), i * 100 + k, 0.95, 20 + k * 25) end
	lantern(d, at(-20.5, 15), V(1, 0, 0))
	-- Right: the court.
	local x0, x1, za, zb = 22, 62.4, 3, 55
	District.floor(d, top, 1, ST.road + ST.walk, x1, 0, 56, ST.kerb + 0.08, K.ground, 'CourtGround')
	District.floor(d, top, 1, 28, 56, 7, 51, ST.kerb + 0.14, K.court, 'Court')
	local y = ST.kerb + 0.14
	local function paint(a, b) decor(d:box('CourtLine', V(a.X, y, top - a.Z), V(b.X, y + 0.06, top - b.Z), P.white, M.Plastic)).CastShadow = false end
	paint(V(28, 0, 7), V(56, 0, 7.4)); paint(V(28, 0, 50.6), V(56, 0, 51)); paint(V(28, 0, 7), V(28.4, 0, 51)); paint(V(55.6, 0, 7), V(56, 0, 51))
	paint(V(28, 0, 28.8), V(56, 0, 29.2))
	for _, e in { { 7, 19 }, { 39, 51 } } do
		decor(sbox(d, 'CourtKey', V(36.4, y - 0.4, top - e[1]), V(47.6, y + 0.04, top - e[2]), K.key)).CastShadow = false
		paint(V(36, 0, e[1]), V(36.4, 0, e[2])); paint(V(47.6, 0, e[1]), V(48, 0, e[2]))
		local ez = e[1] == 7 and 19 or 39
		paint(V(36, 0, ez - 0.2), V(48, 0, ez + 0.2))
	end
	local function arc(cx, cz, r, a0, a1, n)
		for q = 0, n - 1 do
			local t0, t1 = a0 + (a1 - a0) * q / n, a0 + (a1 - a0) * (q + 1) / n
			local p0 = V(cx + math.cos(t0) * r, y + 0.03, top - (cz + math.sin(t0) * r))
			local p1 = V(cx + math.cos(t1) * r, y + 0.03, top - (cz + math.sin(t1) * r))
			decor(d:part('CourtArc', V(0.4, 0.06, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), P.white, M.Plastic)).CastShadow = false
		end
	end
	arc(42, 29, 3.6, 0, math.pi * 2, 12)
	arc(42, 9.2, 12, math.rad(10), math.rad(170), 10)
	arc(42, 48.8, 12, math.rad(190), math.rad(350), 10)
	District.hoop(d, CFrame.new(at(42, 4.4)) * CFrame.Angles(0, math.pi, 0))
	District.hoop(d, CFrame.new(at(42, 53.6)))
	-- The fence: chain-link round three sides with a gateway onto the grass, the back wall behind with a mural.
	chainLink(d, V(x0, ST.kerb, top - za), V(x0, ST.kerb, top - zb), 12, { { 23, 27.5 } })
	chainLink(d, V(x0, ST.kerb, top - za), V(x1 - 0.4, ST.kerb, top - za), 12)
	chainLink(d, V(x0, ST.kerb, top - zb), V(x1 - 0.4, ST.kerb, top - zb), 12)
	District.backWall(d, top, 1, x1, 0, 56, 16)
	local mural = ghost(d:box('Mural', V(x1 - 0.08, ST.kerb + 3, top - 14), V(x1 - 0.02, ST.kerb + 13, top - 42), P.white, M.SmoothPlastic))
	local g = surface(mural, Enum.NormalId.Left, 12)
	line(g, 'Mural', ({ 'HOOD BALLERS', 'GAME ON', 'NEXT UP' })[t], ({ C(255, 210, 60), C(255, 96, 206), C(70, 220, 255) })[t], FONT.tag, 0.1, 0.8, P.black, 4).Rotation = -4
	District.bleachers(d, top, 1, 56.6, 13, 45)
	for _, bz in { 11, 41 } do
		local b = d:at(CFrame.lookAt(at(24.6, bz), at(40, bz))):group('TeamBench')
		sbox(b, 'BenchSeat', V(-3.5, 1.4, -0.7), V(3.5, 1.8, 0.7), C(40, 90, 200))
		for _, x in { -3, 3 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	end
	for k, bp in ipairs({ { 25, 13.5 }, { 26.4, 15 }, { 40, 30.5 } }) do decor(d:part('Basketball', V(1.2, 1.2, 1.2), CFrame.new(at(bp[1], bp[2]) + V(0, 0.75, 0)), C(236, 112, 40), M.Plastic, Enum.PartType.Ball)) end
	sbox(d, 'WaterCooler', at(24.4, 44.4), at(25.8, 45.8) + V(0, 2.2, 0), C(40, 120, 220))
	for _, fl in { { 24, 4.6, 0.6 }, { 60, 4.6, -0.6 }, { 24, 53.4, 2.5 }, { 60, 53.4, -2.5 } } do
		District.floodlight(d, CFrame.lookAt(at(fl[1], fl[2]), at(42, 29)), 26)
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickLight, roof = 'hip', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { name = 'Clubhouse', wall = P.st.brickDeep, roof = 'flat', floors = 1, h = 14 })
	return d
end

-- Corrugated metal shed on a lot frame (+Z out of the front): a darker plinth, the wall with a lighter rib every 2.6
-- studs along the front, a dark sign band, a low gable roof along the street with a ridge cap.
function District.shed(c, w, dep, H, color, sign)
	local g = c:group('Warehouse')
	local dark = color:Lerp(P.black, 0.3)
	sbox(g, 'ShedWall', V(0, -1, -dep), V(w, H, 0), color)
	sbox(g, 'ShedPlinth', V(-0.3, -1, -dep - 0.3), V(w + 0.3, 2.2, 0.3), dark)
	for x = 1.3, w - 1, 2.6 do decor(g:box('ShedRib', V(x - 0.4, 2.2, 0), V(x + 0.4, H - 2.6, 0.3), color:Lerp(P.white, 0.14), M.Plastic)) end
	local band = sbox(g, 'ShedBand', V(-0.3, H - 2.6, -dep - 0.3), V(w + 0.3, H, 0.4), dark)
	if sign then line(surface(band, Enum.NormalId.Back, 16), 'Sign', sign, P.white, FONT.loud, 0.1, 0.8, P.black, 3) end
	gableRoof(g, w, dep, H, dep * 0.18, 'x', color:Lerp(P.white, 0.2))
	return g
end
-- Shipping container in the studded kit (8 wide, 20 long along local Z, 8.6 tall): body, darker corner posts and top
-- rim, door end with locking bars.
function District.container(d, cf, color)
	local k = d:at(cf):group('Container')
	local dark = color:Lerp(P.black, 0.28)
	sbox(k, 'ContainerBody', V(-4, 0, -10), V(4, 8.6, 10), color)
	for _, x in { -4.2, 3.6 } do for _, z in { -10.2, 9.6 } do sbox(k, 'ContainerPost', V(x, 0, z), V(x + 0.6, 8.6, z + 0.6), dark, true) end end
	sbox(k, 'ContainerRim', V(-4.2, 8.2, -10.2), V(4.2, 8.8, 10.2), dark, true)
	for z = -7.5, 7.6, 3 do for _, x in { -4.15, 4.0 } do decor(k:box('ContainerRib', V(x, 0.4, z - 0.45), V(x + 0.15, 8.2, z + 0.45), color:Lerp(P.white, 0.1), M.Plastic)) end end
	for _, x in { -1.6, 1.6 } do decor(k:box('ContainerBar', V(x - 0.15, 0.6, 10), V(x + 0.15, 8, 10.25), dark, M.Plastic)) end
	return k
end
-- Forklift (front = local -Z): yellow body, a dark counterweight, the cab frame, mast and forks.
function District.forklift(d, cf)
	local k = d:at(cf):group('Forklift')
	local y = C(250, 196, 40)
	for _, x in { -1.6, 1.6 } do for _, z in { -1.6, 1.8 } do decor(k:part('Wheel', V(0.8, 1.6, 1.6), CFrame.new(x, 0.8, z), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end end
	sbox(k, 'LiftBody', V(-1.6, 0.6, -2.2), V(1.6, 2.6, 2.6), y)
	sbox(k, 'LiftWeight', V(-1.7, 0.6, 2.2), V(1.7, 3.2, 3.2), C(46, 50, 60))
	sbox(k, 'LiftSeat', V(-0.8, 2.6, 0.4), V(0.8, 3.4, 1.8), C(30, 32, 36), true)
	for _, x in { -1.4, 1.4 } do
		decor(k:box('CabPost', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 6.4, -0.5), C(30, 32, 36), M.Plastic))
		decor(k:box('CabPost', V(x - 0.15, 2.6, 2.0), V(x + 0.15, 6.4, 2.3), C(30, 32, 36), M.Plastic))
	end
	sbox(k, 'CabRoof', V(-1.6, 6.4, -0.9), V(1.6, 6.7, 2.4), C(30, 32, 36), true)
	sbox(k, 'Mast', V(-1.2, 0.6, -2.8), V(1.2, 7.2, -2.3), C(60, 66, 80), true)
	for _, x in { -0.8, 0.8 } do sbox(k, 'Fork', V(x - 0.2, 0.5, -5.6), V(x + 0.2, 0.8, -2.8), C(60, 66, 80), true) end
	return k
end

-- The Yards (stages 13-15): concrete aprons; a corrugated warehouse with a loading dock (bumpers, roll-up doors, a
-- canopy, stairs) on one side; a container yard behind chain-link with a sliding gate, stacks two high, a forklift
-- and pallets on the other; floodlights, drums and barriers.
function District.yards(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local apron = C(196, 198, 202)
	for _, s in { -1, 1 } do District.floor(d, top, s, ST.road + ST.walk, 63, 0, 56, ST.kerb + 0.08, apron, 'Apron') end
	for _, st in ipairs({ { -22, 8, 3, 2 }, { -26, 32, 4, 3 }, { 20.5, 6, 2.5, 3 }, { 21, 40, 3, 2 }, { -21, 50, 2, 2.5 } }) do
		decor(sbox(d, 'OilStain', at(st[1] - st[3] / 2, st[2] - st[4] / 2) + V(0, 0.06, 0), at(st[1] + st[3] / 2, st[2] + st[4] / 2) + V(0, 0.11, 0), apron:Lerp(P.black, 0.35))).CastShadow = false
	end
	for _, s in { -1, 1 } do decor(sbox(d, 'LaneLine', V(s * 17.4, ST.kerb + 0.08, top), V(s * 17.9, ST.kerb + 0.13, top - 56), C(250, 204, 40))).CastShadow = false end
	-- Left: the warehouse and its dock.
	local wcol = ({ C(84, 118, 170), C(150, 156, 166), C(120, 140, 110) })[t]
	local wf = 30
	District.shed(houseFrame(d, -1, top - 2, 52, wf), 52, 34, 22, wcol, 'DEPOT ' .. i)
	District.floor(d, top, -1, wf - 0.2, 64, 0, 2, ST.kerb + 0.08, apron, 'Apron')
	District.backWall(d, top, -1, 64, 0, 2, 14)
	District.backWall(d, top, -1, 64, 54, 56, 14)
	local dz0, dz1 = 10, 44
	sbox(d, 'Dock', V(-wf, -1, top - dz0), V(-(wf - 5), 4.2, top - dz1), C(176, 178, 184))
	sbox(d, 'DockEdge', V(-(wf - 5) - 0.3, 3.8, top - dz0), V(-(wf - 5) + 0.3, 4.3, top - dz1), C(250, 204, 40), true)
	for zb = dz0 + 3, dz1 - 2, 6 do sbox(d, 'DockBumper', V(-(wf - 5) + 0.2, 1.4, top - zb - 0.7), V(-(wf - 5) - 0.6, 3.6, top - zb + 0.7), C(30, 32, 36), true) end
	for k, s in ipairs({ { dz1, dz1 + 1.1, 3.4 }, { dz1 + 1.1, dz1 + 2.2, 2.2 }, { dz1 + 2.2, dz1 + 3.3, 1.0 } }) do
		sbox(d, 'DockStep', V(-wf, -1, top - s[1]), V(-(wf - 3), s[3], top - s[2]), C(176, 178, 184))
	end
	for _, dzc in { 19, 35 } do
		sbox(d, 'RollDoorFrame', V(-wf + 0.2, 4.2, top - dzc - 6.6), V(-wf - 0.4, 16.6, top - dzc + 6.6), wcol:Lerp(P.black, 0.4))
		sbox(d, 'RollDoor', V(-wf + 0.35, 4.2, top - dzc - 5.8), V(-wf - 0.4, 15.8, top - dzc + 5.8), C(178, 184, 194))
		for yy = 5.4, 15, 1.2 do decor(d:box('DoorSlat', V(-wf + 0.45, yy, top - dzc - 5.8), V(-wf + 0.3, yy + 0.25, top - dzc + 5.8), C(130, 136, 148), M.Plastic)) end
	end
	-- a clerestory strip high on the front, lamps over the doors, an office door with its own canopy at the far end
	sbox(d, 'Clerestory', V(-wf + 0.15, 19.4, top - 4), V(-wf - 0.2, 22.2, top - 52), P.st.glassA, true)
	for zc = 4, 52, 4 do sbox(d, 'ClerestoryBar', V(-wf + 0.3, 19.4, top - zc - 0.3), V(-wf - 0.2, 22.2, top - zc + 0.3), wcol:Lerp(P.black, 0.4), true) end
	for _, dzc in { 19, 35 } do
		local lb = sbox(d, 'DoorLamp', V(-wf + 1.4, 17.0, top - dzc - 0.8), V(-wf, 17.4, top - dzc + 0.8), C(46, 50, 60), true)
		decor(d:box('DoorLampGlow', V(-wf + 1.3, 16.9, top - dzc - 0.6), V(-wf + 0.1, 17.0, top - dzc + 0.6), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	sbox(d, 'OfficeDoor', V(-wf + 0.3, ST.kerb, top - 47.5), V(-wf - 0.2, ST.kerb + 7.6, top - 50.5), C(70, 76, 90))
	sbox(d, 'OfficeDoorFrame', V(-wf + 0.2, ST.kerb, top - 47), V(-wf - 0.2, ST.kerb + 8.2, top - 51), wcol:Lerp(P.black, 0.4))
	sbox(d, 'OfficeCanopy', V(-wf, ST.kerb + 9, top - 46.2), V(-wf + 2.6, ST.kerb + 9.5, top - 51.8), C(46, 50, 60), true)
	sbox(d, 'OfficeWindow', V(-wf + 0.2, ST.kerb + 3.4, top - 52.4), V(-wf - 0.2, ST.kerb + 7.2, top - 53.6), P.st.glassB, true)
	sbox(d, 'DockCanopy', V(-wf, 17.4, top - dz0 + 1), V(-(wf - 6.5), 18.2, top - dz1 - 1), wcol:Lerp(P.black, 0.25))
	for zb = dz0 + 2, dz1 - 1, 10 do decor(d:bar('CanopyBrace', V(-wf, 13.4, top - zb), V(-(wf - 6), 17.4, top - zb), 0.4, C(46, 50, 60), M.Plastic)) end
	pallet(d, CFrame.new(V(-(wf - 2), 4.2, top - 26)))
	crate(d, CFrame.new(V(-(wf - 2), 5.0, top - 26)) * CFrame.Angles(0, 0.2, 0), 2.6)
	for k, dp in ipairs({ { -21.5, 6 }, { -22.6, 7.6 }, { -21, 8.8 } }) do
		local drum = d:post('Drum', 1.1, 3.4, at(dp[1], dp[2]), ({ C(40, 90, 200), C(200, 50, 40), C(40, 90, 200) })[k], M.Plastic)
		studs(drum)
		decor(d:post('DrumRim', 1.18, 0.3, at(dp[1], dp[2]) + V(0, 3.2, 0), C(30, 32, 36), M.Plastic))
	end
	-- Right: the container yard.
	local fx = 23
	chainLink(d, V(fx, ST.kerb, top - 2), V(fx, ST.kerb, top - 54), 12, { { 20, 34 } })
	chainLink(d, V(fx, ST.kerb, top - 2), V(63, ST.kerb, top - 2), 12)
	chainLink(d, V(fx, ST.kerb, top - 54), V(63, ST.kerb, top - 54), 12)
	District.backWall(d, top, 1, 63, 0, 56, 14)
	-- the sliding gate, shut: a framed chain-link leaf on wheels across the gap, a sign
	local gate = d:group('YardGate')
	sbox(gate, 'GateFrame', V(fx - 0.2, ST.kerb + 0.6, top - 22), V(fx + 0.3, ST.kerb + 11.4, top - 36), C(150, 156, 166))
	local mesh = gate:box('GateMesh', V(fx - 0.25, ST.kerb + 1.2, top - 22.6), V(fx + 0.35, ST.kerb + 10.8, top - 35.4), C(70, 74, 82), M.DiamondPlate)
	mesh.Transparency = 0.45
	for _, gz in { 23, 35 } do decor(gate:part('GateWheel', V(0.5, 1.2, 1.2), CFrame.new(fx + 0.05, ST.kerb + 0.6, top - gz), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	local sign = sbox(gate, 'YardSign', V(fx - 0.5, ST.kerb + 6, top - 26.5), V(fx - 0.3, ST.kerb + 8.6, top - 31.5), P.white, true)
	line(surface(sign, Enum.NormalId.Left, 30), 'Sign', 'YARD ' .. i, C(200, 40, 40), FONT.body, 0.12, 0.76)
	local colors = { C(196, 52, 42), C(44, 96, 186), C(46, 150, 90), C(232, 130, 40) }
	local rows = ({ { { 32, 3, 2 }, { 32, 30, 1 }, { 45, 5, 2 }, { 45, 31, 2 }, { 57, 4, 1 }, { 57, 30, 2 } },
		{ { 32, 4, 1 }, { 32, 30, 2 }, { 45, 4, 2 }, { 45, 30, 1 }, { 57, 4, 2 }, { 57, 30, 2 } },
		{ { 32, 3, 2 }, { 32, 30, 2 }, { 45, 5, 1 }, { 45, 31, 2 }, { 57, 4, 2 }, { 57, 30, 1 } } })[t]
	for k, r in ipairs(rows) do
		for lvl = 0, r[3] - 1 do
			District.container(d, CFrame.new(at(r[1], r[2] + 10.6) + V(0, -ST.kerb + ST.kerb + 0.08 + lvl * 8.7, 0)) * CFrame.Angles(0, math.rad((k * 3 + lvl * 2) % 5 - 2), 0), colors[(k + lvl + i) % #colors + 1])
		end
	end
	District.forklift(d, CFrame.new(at(38.5, 27.5) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(70), 0))
	-- the gatehouse by the gate (inside), a stack of tyres, a second pallet stack
	local booth = d:at(CFrame.new(at(26.6, 41) + V(0, 0.08, 0))):group('Gatehouse')
	sbox(booth, 'BoothBase', V(-2.4, 0, -2.6), V(2.4, 1, 2.6), C(150, 156, 166))
	sbox(booth, 'BoothWall', V(-2.2, 1, -2.4), V(2.2, 3.4, 2.4), C(236, 238, 242))
	sbox(booth, 'BoothGlass', V(-2.25, 3.4, -2.45), V(2.25, 6.2, 2.45), P.st.glassA, true)
	for _, x in { -2.2, 1.9 } do for _, z in { -2.4, 2.1 } do sbox(booth, 'BoothPost', V(x, 3.4, z), V(x + 0.3, 6.2, z + 0.3), C(236, 238, 242), true) end end
	sbox(booth, 'BoothRoof', V(-2.8, 6.2, -3), V(2.8, 6.9, 3), C(46, 96, 186))
	for k = 0, 2 do decor(d:part('Tyre', V(1, 2.4, 2.4), CFrame.new(at(26.2, 51.5) + V(0, 0.6 + k * 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder)) end
	for k = 0, 1 do
		pallet(d, CFrame.new(at(39, 52) + V(0, 0.08 + k * 0.8, 0)) * CFrame.Angles(0, k * 0.15, 0))
	end
	crate(d, CFrame.new(at(39, 52) + V(0, 1.68, 0)) * CFrame.Angles(0, 0.2, 0), 3)
	pallet(d, CFrame.new(at(25.6, 8) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	crate(d, CFrame.new(at(25.6, 8) + V(0, 0.88, 0)), 2.8)
	pallet(d, CFrame.new(at(25.6, 28) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	for k = 0, 2 do
		local bz = top - (4 + k * 4)
		sbox(d, 'Barrier', V(19.4, ST.kerb, bz - 1.8), V(21.2, ST.kerb + 3, bz + 1.8), C(206, 208, 214))
		sbox(d, 'BarrierStripe', V(19.3, ST.kerb + 1.6, bz - 1.85), V(21.3, ST.kerb + 2.2, bz + 1.85), C(250, 204, 40), true)
	end
	District.floodlight(d, CFrame.lookAt(at(-20.5, 14), at(0, 28)), 24)
	District.floodlight(d, CFrame.lookAt(at(26, 50), at(45, 28)), 26)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = C(150, 156, 166), roof = 'flat', floors = 2 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = wcol, roof = 'flat', floors = 2 })
	return d
end

local function streetStage(ctx, i)
	local top = stageTop(i)
	local ST = P.street
	local d = ctx:group('Stage' .. i)
	-- The fight hook stays (V2.Fights, HoodFightPad) as an invisible marker: the picture's road has no pad.
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	local zEnd = top - ST.endZ
	-- Hood touches on the long fronts: a window air-con box and a spray-painted tag above the fence, a different word
	-- each side and stage (kid-friendly ones).
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	local plan = PLANS[i]
	for _, s in { -1, 1 } do
		local tag = TAGS[(i * 2 + (s > 0 and 1 or 0)) % #TAGS + 1]
		local function lx(zp) return s < 0 and zp or ST.endZ - zp end -- (the lot runs along -Z on the left, +Z on the right)
		local gaps = {}
		if plan then
			local z = top
			for _, g in plan.gates[s < 0 and 'L' or 'R'] do table.insert(gaps, { top - g[1], top - g[2] }) end
			for _, h in plan[s < 0 and 'L' or 'R'] do
				if h.yard then
					sideYard(d, s, z, h[1], top, i * 100 + 77)
					picketFence(d, s * ST.fence, z, z - h[1], -s)
					z -= h[1]
					continue
				end
				brickBuilding(houseFrame(d, s, z, h[1], h[2]), h[1], h[3])
				-- the yard in front of a set-back house
				if h[2] > FRONT then sbox(d, 'Yard', V(s * FRONT, -1, z - h[1]), V(s * h[2], ST.kerb, z), P.st.grass) end
				-- its boundary: the tall plank fence of the picture, a low picket fence or a brick garden wall
				local mine = {}
				for _, g in gaps do if math.min(g[1], g[2]) < z and math.max(g[1], g[2]) > z - h[1] then table.insert(mine, g) end end
				if h.edge == 'picket' then picketFence(d, s * ST.fence, z, z - h[1], -s, mine)
				elseif h.edge == 'wall' then gardenWall(d, s * ST.fence, z, z - h[1], -s, mine)
				else fence(d, s * ST.fence, z, z - h[1], -s, nil, mine) end
				z -= h[1]
			end
		else
			sideRow(d, s, top, { { ST.endZ, function(f, w) brickBuilding(f, w, { bays = 2, ac = { { 'front', lx(s < 0 and 18 or 46), 16.4 } }, tags = { { 'front', lx(28), 9.9, tag[1], tag[2] } } }) end } })
		end
		endBuilding(d, s, zEnd, top - SLEN)
		if not plan then fence(d, s * ST.fence, top, zEnd, -s) end
	end
	-- Paver paths from the sidewalk to each gateway's steps: 3 wide, studded slabs in two stone tones.
	for _, pth in plan and plan.paths or {} do
		local s, x1, zc = math.sign(pth[1]), math.abs(pth[1]), top - pth[2]
		local k = 0
		for x = ST.road + ST.walk, x1 - 0.01, 2 do
			k += 1
			sbox(d, 'Paver', V(s * x, ST.kerb - 0.3, zc - 1.5), V(s * math.min(x + 1.9, x1), ST.kerb + 0.07, zc + 1.5), k % 2 == 0 and P.st.kerbStone or P.st.sill)
		end
	end
	local seed = i * 100
	local function at(x, zp) return V(x, ST.kerb, top - zp) end
	-- Dressing keeps off the paver paths (and their 1.5-stud margins): free(x, z', r) is false where an item of
	-- radius r would stand on one.
	local function free(x, zp, r)
		for _, pth in plan and plan.paths or {} do
			if math.sign(pth[1]) == math.sign(x) and math.abs(x) - r < math.abs(pth[1]) and math.abs(zp - pth[2]) < 1.5 + r + 0.5 then return false end
		end
		return true
	end
	-- Left, near to far: hedge, lamp, the big tree, the far tree, a hedge and the second lamp by the end building.
	if free(-27, 5, 3) then hedge(d, plan and at(-27, 5) or at(-25, 14), plan and 5 or 6) end
	lantern(d, at(-20, 19), V(1, 0, 0))
	tree(d, at(-24.5, 28.5), seed + 1, 1, 38)
	if free(-23.8, 45, 3.2) then tree(d, at(-23.8, 45), seed + 2, 0.85, 20) end
	if free(-23, 51, 2.2) then hedge(d, at(-23, 51), 4) end
	-- (the far lamps stand out at |x| 25.5, clear of the line from the street to GATES' gate pillars)
	lantern(d, at(-25.5, 53.5), V(1, 0, 0))
	-- Right: open grass with a flower, the low hedge, the lamp (with its street sign) and the dumpster behind it.
	if free(25.8, 34, 3.2) then hedge(d, at(25.8, 34), 6) end
	local lamp = lantern(d, at(25.5, 50), V(-1, 0, 0))
	local sign = sbox(lamp, 'StreetSign', V(0.9, 17.4, -2.4), V(1.2, 19.0, -0.2), C(40, 150, 70), true)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do line(surface(sign, face, 30), 'Street', 'HOOD ST', P.white, FONT.body, 0.18, 0.64) end
	if free(31, 50.5, 4.5) then dumpster(d, CFrame.new(at(31, 50.5)))
	elseif free(31, 41, 4.5) then dumpster(d, CFrame.new(at(31, 41))) end
	for k, f in { { 20.6, 17.5 }, { 24, 41 }, { -21, 40 }, { -20, 34 }, { -29.8, 24 }, { 20.8, 62.5 } } do if free(f[1], f[2], 1.2) then flower(d, at(f[1], f[2]), seed + 10 + k) end end
	for k, t in { { -33, 33.5 }, { -31.8, 35 }, { -32.5, 30 }, { 22.8, 38 }, { 21, 50 }, { -18, 57.5 } } do if free(t[1], t[2], 1) then tuft(d, at(t[1], t[2]), seed + 20 + k) end end
	-- The grass in two greens: darker clumps where the picture's grass is shaded or worn.
	for _, g in { { -28, plan and 18 or 10, 3, 5 }, { -30.5, 38, 2.5, 4 }, { -19.5, 44, 2, 3 }, { -31, 22, 2, 3 }, { 28, plan and 18 or 12, 4, 3 }, { 22, plan and 33 or 28, 2.5, 4 }, { 31, plan and 22 or 25, 2, 3 }, { 26.5, 44, 3, 2.5 } } do
		local p = at(g[1], g[2])
		if not free(g[1], g[2], math.max(g[3], g[4]) / 2) then continue end
		decor(sbox(d, 'GrassClump', p + V(-g[3] / 2, -0.2, -g[4] / 2), p + V(g[3] / 2, 0.05, g[4] / 2), P.st.grassDark)).CastShadow = false
	end
	-- Street furniture in the road: a manhole and two kerb drains (dark grates in lighter frames).
	local mh = V(3.6, 0, top - 31)
	decor(sbox(d, 'ManholeRim', mh + V(-1.5, -0.2, -1.5), mh + V(1.5, 0.05, 1.5), P.st.manhole)).CastShadow = false
	decor(sbox(d, 'Manhole', mh + V(-1.1, -0.2, -1.1), mh + V(1.1, 0.08, 1.1), P.st.manhole:Lerp(P.white, 0.12))).CastShadow = false
	for _, dr in { { -1, 15 }, { 1, 42 } } do
		local p = V(dr[1] * (ST.road - 0.65), 0, top - dr[2])
		decor(sbox(d, 'DrainFrame', p + V(-0.55, -0.2, -1.4), p + V(0.55, 0.06, 1.4), P.st.kerbStone:Lerp(P.black, 0.25))).CastShadow = false
		decor(sbox(d, 'DrainGrate', p + V(-0.35, -0.2, -1.15), p + V(0.35, 0.08, 1.15), C(34, 38, 46))).CastShadow = false
	end
	-- Hood prop clusters at the sides, never on the walk: bags and a wheelie bin by the dumpster; a crate with a
	-- boombox on it by the left end building; a hydrant on the right before the gate.
	if free(28.4, 44, 2.5) then trashBags(d, CFrame.new(at(28.4, 44)) * CFrame.Angles(0, 0.4, 0), 3) end
	if free(31.9, 41.4, 1.8) then wheelieBin(d, CFrame.new(at(31.9, 41.4))) end
	crate(d, CFrame.new(at(-19.8, 55)) * CFrame.Angles(0, 0.2, 0), 2.6)
	boombox(d, CFrame.new(at(-19.8, 55) + V(0, 2.6, 0)) * CFrame.Angles(0, math.rad(-70), 0))
	hydrant(d, at(19.6, 54.5))
	-- Right, by the near fence: a bike parked against it and corner-store produce crates on a pallet.
	local bz = plan and 16.5 or 13.5
	if not free(32.4, bz, 2.4) then bz = 30 end
	if free(32.4, bz, 2.4) then bike(d, CFrame.new(at(32.4, bz)) * CFrame.Angles(0, math.pi, 0), ({ C(230, 60, 60), C(60, 140, 240), C(250, 200, 40) })[i % 3 + 1]) end
	if i == 1 then
		-- The porch house: a bench on the porch and pots by its steps; pots on the stoop's cheek walls.
		porchBench(d, CFrame.lookAt(V(38.2, ST.kerb + 1.0, top - 18), V(30, ST.kerb + 1.0, top - 18)))
		for _, zp in { 7.4, 14.6 } do plantPot(d, V(37.2, ST.kerb + 1.0, top - zp), zp) end
		for _, zp in { 8.4, 15.6 } do plantPot(d, V(-36.4, ST.kerb + 3.1, top - zp), zp) end
		-- No. 12's front garden behind its wall: soil beds with flowers either side of the stoop, a clipped bush.
		for k, b in { { 1.5, 7.2 }, { 16.8, 22.5 } } do
			decor(sbox(d, 'FlowerBed', V(-39.9, ST.kerb - 0.2, top - b[1]), V(-37.4, ST.kerb + 0.25, top - b[2]), C(110, 84, 64))).CastShadow = false
			for q = 0, 2 do flower(d, V(-38.6, ST.kerb + 0.2, top - (b[1] + 1 + q * 2)), seed + 40 + k * 3 + q) end
		end
		hedge(d, V(-36.8, ST.kerb, top - 20), 3)
	elseif free(30.8, 20.5, 2.6) then
		storeCrates(d, CFrame.new(at(30.8, 20.5)) * CFrame.Angles(0, 0.1, 0), 3)
	end
	-- Left, by the fence between the trees: a junk corner of a chain-link panel, a tagged board leaning on it and a
	-- pallet with a crate.
	if free(-31, 40, 4) then
		chainLink(d, at(-32.9, 36.6), at(-32.9, 43.4), 7)
		local tag2 = TAGS[(i + 2) % #TAGS + 1]
		graffitiBoard(d, CFrame.lookAt(at(-31.7, 40), at(-31.7, 40) + V(1, 0, 0)), tag2[1], tag2[2])
		pallet(d, CFrame.new(at(-29.6, 42.8)) * CFrame.Angles(0, 0.3, 0))
		crate(d, CFrame.new(at(-29.6, 42.8) + V(0, 0.8, 0)) * CFrame.Angles(0, 0.5, 0), 2.4)
	end
	-- A darker repair patch in the asphalt.
	decor(sbox(d, 'RoadPatch', V(-5.6, -0.2, top - 47), V(-2.2, 0.03, top - 41.5), P.st.roadDark)).CastShadow = false
	-- Stage 1: brick wings between the warehouse wall and the gate line, so its wall is the only way through.
	if i == 1 then
		for _, s in { -1, 1 } do
			-- (out to |x| 40: the set-back houses' yards must not open onto the hall's grass)
			brickBuilding(d:at(CFrame.new(s < 0 and -40 or ST.open, 0, Lobby.N - 1)), 40 - ST.open, { name = 'GateWing', depth = Lobby.N - 1, h = ST.eave + 2, run = 1.5, rise = 1.5, windows = {}, gutters = {} })
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- boss yard
-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end.
local function bossYard(ctx)
	local b = ctx:group('BossYard')
	b:box('YardSlab', V(-FRONT, 0, BOSS_END), V(FRONT, 0.06, BOSS_TOP - 4), C(176, 178, 184), M.Concrete)
	sideRow(b, -1, BOSS_TOP, {
		{ 56, function(f, w) warehouse(f, w) end },
		{ 40, function(f, w) brickBuilding(f, w, { wall = P.warehouse:Lerp(P.black, 0.1), bays = 2 }) end },
	})
	sideRow(b, 1, BOSS_TOP, { { 96, function(f, w) containerLot(f, w, 3) end } })
	car(b, CFrame.new(-26, 0, BOSS_TOP - 70) * CFrame.Angles(0, math.rad(80), 0), P.white)
	local ring = SKINS.StationById.Ring
	local ringCtx, ringModel = b:at(CFrame.new(0, 0, BOSS_TOP - 34) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id)
	Props.ring(ringCtx, PROPS_KIT, ring, 7)
	-- The champion aura (tier 9) on the canvas, like the stations along the way.
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	if canvas and vfx then vfx.station(canvas, 9, nil, V(14, 12, 14)) end
	local bz = BOSS_END + 22
	local _, pad = fightPad(b, 16, V(0, 0, bz), P.padRed, 6, 14, 'BOSS')
	local model = pad.parent
	model.Name = 'BossPad'
	model:SetAttribute('Boss', true)
	local glow = decor(b:part('BossRing', V(0.1, 22, 22), CFrame.new(0, 0.05, bz) * CFrame.Angles(0, 0, math.pi / 2), P.bossRing, M.Neon, Enum.PartType.Cylinder))
	glow.Transparency, glow.CastShadow = 0.25, false
	decor(b:part('BossRingInner', V(0.11, 18.4, 18.4), CFrame.new(0, 0.06, bz) * CFrame.Angles(0, 0, math.pi / 2), C(176, 178, 184), M.Concrete, Enum.PartType.Cylinder)).CastShadow = false
	banner(b, 'BOSS', V(0, 13, bz - 4), BOSS_RED, 16)
	for x = -30, 30, 15 do tree(b, V(x, 0, BOSS_END + 4), 600 + x, 1) end
	return b
end

local function buildStages(ctx)
	local byLook = { streetStage, District.corner, District.alley, District.courts, District.yards }
	for i = 1, STAGES do (byLook[lookOf(i)] or streetStage)(ctx, i) end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do stageGate(gates, i) end
	bossYard(ctx)
end
---------------------------------------------------------------------------------------------- stage crews' hangouts
-- Brief 18: every stage holds a crew of cartoon rival goons (Shared/EnemyRules: who and where; each player's client draws
-- its own goons, Shared/GoonRig, and the server runs them, WaveService). The map only dresses the spot each crew hangs out
-- at, so the street reads as their turf: a milk crate with a boombox on it (two speaker cones, a cassette deck, a
-- stripe in the crew's colour), a second crate to sit on, a few soda cans, and a paint splat in the crew's colour on
-- the sidewalk. The Boss Yard gets the boss's big red armchair behind the BOSS pad. Nothing here blocks the street:
-- everything stands on the sidewalk beside the crew (|x| 10..16) or on the court, behind the goons' line.
-- (The old cartoon target waves are gone; HoodClient/Waves hides any a map built before brief 18 still carries.)
local Waves = {}
Waves.Ground = 0.6 -- the sidewalk top (P.street.kerb)
Waves.Crew = {
	Red = C(222, 58, 58), Green = C(64, 182, 96), Purple = C(140, 76, 214), Orange = C(255, 146, 44), Yellow = C(255, 214, 56), Boss = C(255, 202, 64),
}
Waves.Wood = { lit = C(232, 196, 140), dark = C(136, 86, 48) }

-- Parts: a cylinder lying along the frame's Z (a disc facing -Z), an upright cylinder standing on a point.
function Waves.disc(c, name, r, thick, centre, color, material)
	return decor(c:part(name, V(thick, 2 * r, 2 * r), CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.can(c, name, r, h, foot, color, material)
	return decor(c:part(name, V(h, 2 * r, 2 * r), CFrame.new(foot + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder))
end
function Waves.trim(c, name, a, b, color) return decor(c:box(name, a, b, color, M.SmoothPlastic)) end

-- A blue milk crate (slots on its sides, a darker rim), from y0, its footprint centred on the frame's origin.
function Waves.crate(c, y0, color)
	local blue = color or C(52, 98, 204)
	local rim = blue:Lerp(C(0, 0, 0), 0.3)
	local h = 1.5
	sbox(c, 'MilkCrate', V(-1.3, y0, -1.0), V(1.3, y0 + h, 1.0), blue)
	Waves.trim(c, 'MilkCrateRim', V(-1.36, y0 + h - 0.25, -1.06), V(1.36, y0 + h, 1.06), rim)
	for _, x in { -0.75, 0, 0.75 } do
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, -1.04), V(x + 0.24, y0 + 0.95, -1.0), rim:Lerp(C(0, 0, 0), 0.3))
		Waves.trim(c, 'MilkCrateSlot', V(x - 0.24, y0 + 0.35, 1.0), V(x + 0.24, y0 + 0.95, 1.04), rim:Lerp(C(0, 0, 0), 0.3))
	end
	return y0 + h
end

-- A big boombox (front -Z): charcoal case, a lighter face plate, two speaker cones in chrome rims, a cassette deck,
-- four coloured buttons, a chrome carry handle and a stripe in the crew's colour.
function Waves.boombox(c, y0, stripe)
	local y1 = y0 + 2.5
	decor(c:box('Case', V(-2.1, y0, -0.5), V(2.1, y1, 0.55), C(50, 52, 62), M.SmoothPlastic))
	Waves.trim(c, 'FacePlate', V(-1.98, y0 + 0.12, -0.58), V(1.98, y1 - 0.12, -0.5), C(74, 78, 92))
	Waves.trim(c, 'Stripe', V(-2.12, y0 + 0.18, -0.6), V(2.12, y0 + 0.42, 0.57), stripe)
	local cy = (y0 + y1) / 2 + 0.1
	for _, x in { -1.18, 1.18 } do
		Waves.disc(c, 'SpeakerRim', 0.98, 0.1, V(x, cy, -0.6), C(204, 208, 218))
		Waves.disc(c, 'Grille', 0.86, 0.1, V(x, cy, -0.63), C(34, 36, 44))
		Waves.disc(c, 'Cone', 0.5, 0.1, V(x, cy, -0.67), C(70, 72, 84))
		Waves.disc(c, 'DustCap', 0.2, 0.1, V(x, cy, -0.71), C(150, 154, 166))
	end
	Waves.trim(c, 'Deck', V(-0.5, cy - 0.05, -0.62), V(0.5, cy + 0.6, -0.56), C(30, 32, 40))
	Waves.trim(c, 'Cassette', V(-0.36, cy + 0.08, -0.66), V(0.36, cy + 0.46, -0.6), C(222, 222, 228))
	for k, col in { C(236, 64, 64), C(250, 206, 56), C(70, 200, 100), C(70, 140, 240) } do
		local x = -0.6 + (k - 1) * 0.4
		Waves.trim(c, 'Button', V(x - 0.13, y1, -0.35), V(x + 0.13, y1 + 0.16, -0.05), col)
	end
	local chrome = C(204, 208, 218)
	for _, x in { -1.4, 1.4 } do Waves.trim(c, 'HandlePost', V(x - 0.14, y1, -0.12), V(x + 0.14, y1 + 0.62, 0.16), chrome) end
	Waves.trim(c, 'Handle', V(-1.54, y1 + 0.5, -0.14), V(1.54, y1 + 0.78, 0.18), chrome)
end

-- A paint splat on the ground in the crew's colour (three overlapping blobs and two drips, a white rim), lying flat.
function Waves.splat(c, y, color)
	local rim = C(250, 250, 252)
	local blobs = { { 0, 0, 2.2 }, { 1.1, 0.6, 1.4 }, { -0.9, -0.7, 1.2 } }
	for k, b in blobs do
		decor(c:part('SplatRim', V(0.04, b[3] + 0.3, b[3] + 0.3), CFrame.new(b[1], y + 0.02, b[2]) * CFrame.Angles(0, 0, math.pi / 2), rim, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
		decor(c:part('Splat', V(0.05, b[3], b[3]), CFrame.new(b[1], y + 0.03 + k * 0.001, b[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
	for _, d in { { 1.9, 1.3, 0.5 }, { -1.8, 0.9, 0.4 } } do
		decor(c:part('Drip', V(0.05, d[3], d[3]), CFrame.new(d[1], y + 0.03, d[2]) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)).CastShadow = false
	end
end

-- One crew's hangout, at the frame `cf` (on the sidewalk; its -Z faces the street): the boombox on its crate, a crate to
-- sit on beside it, three soda cans, the splat in front.
function Waves.hangout(c, cf, crew)
	local h = c:at(cf)
	local color = Waves.Crew[crew] or Waves.Crew.Red
	local top = Waves.crate(h, Waves.Ground)
	Waves.boombox(h, top, color)
	local seat = h:at(CFrame.new(3.4, 0, 0.4) * CFrame.Angles(0, math.rad(12), 0))
	Waves.crate(seat, Waves.Ground, C(236, 120, 40))
	for k, col in { C(226, 54, 60), C(62, 188, 98), C(52, 118, 226) } do
		Waves.can(h, 'SodaCan', 0.24, 0.62, V(-2.0 + k * 0.42, Waves.Ground, -1.4 + (k % 2) * 0.3), col)
	end
	Waves.splat(h:at(CFrame.new(-3.4, 0, -0.3)), Waves.Ground, color)
end

-- The boss's armchair (front -Z): big red cushions, gold trim, on four stubby gold feet.
function Waves.throne(c, cf)
	local t = c:at(cf)
	local red, deep, gold = C(208, 40, 52), C(150, 24, 36), C(255, 202, 64)
	local y = 0.06
	for _, x in { -2.6, 2.6 } do for _, z in { -1.8, 1.8 } do sbox(t, 'Foot', V(x - 0.3, y, z - 0.3), V(x + 0.3, y + 0.6, z + 0.3), gold) end end
	sbox(t, 'Seat', V(-3, y + 0.6, -2.2), V(3, y + 2.2, 2.2), red)
	Waves.trim(t, 'SeatPiping', V(-3.05, y + 2.0, -2.25), V(3.05, y + 2.25, 2.25), gold)
	sbox(t, 'Back', V(-3, y + 2.2, 1.2), V(3, y + 7.2, 2.2), deep)
	Waves.trim(t, 'BackPiping', V(-3.05, y + 7.0, 1.15), V(3.05, y + 7.4, 2.25), gold)
	for _, x in { -3, 2.2 } do
		sbox(t, 'Arm', V(x, y + 2.2, -2.2), V(x + 0.8, y + 4.0, 1.2), red)
		Waves.trim(t, 'ArmPiping', V(x - 0.05, y + 3.85, -2.25), V(x + 0.85, y + 4.1, 1.25), gold)
	end
	Waves.trim(t, 'Cushion', V(-2.2, y + 2.2, -2.0), V(2.2, y + 2.7, 1.2), C(236, 70, 82))
	-- a gold crown badge on the backrest
	Waves.trim(t, 'CrownBase', V(-0.9, y + 5.2, 1.12), V(0.9, y + 5.6, 1.2), gold)
	for _, x in { -0.75, 0, 0.75 } do Waves.trim(t, 'CrownPoint', V(x - 0.18, y + 5.6, 1.12), V(x + 0.18, y + 6.3, 1.2), gold) end
end

-- Where each stage's hangout goes: on the sidewalk of the side most of the crew stands toward, a few steps in front of
-- the nearest of them (clear of the next gate's pads, which fill the sidewalks from z' ~48), or on the court where the
-- Courts' crews hang out.
function Waves.spotFor(spots, stage)
	local sx, near = 0, math.huge
	for _, s in spots do sx += s[1]; near = math.min(near, s[2]) end
	sx = sx / #spots
	if stage >= 10 and stage <= 12 then return 33, near - 5, 1 end -- (on the court, by the two there)
	local side = sx >= 0 and 1 or -1
	if stage >= 7 and stage <= 9 then return side * 12.9, near - 7, side end -- (the Alley: tight against the wall)
	return side * 12.8, near - 7, side
end

function Waves.build(ctx)
	-- (Optional: a place or src without Shared.EnemyRules builds without the hangouts instead of stopping the build.)
	local module = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('EnemyRules')
	local ok, rules = false, nil
	if module then ok, rules = pcall(require, module) end
	if not ok or type(rules) ~= 'table' then
		warn('[TheBlockV2] No Shared.EnemyRules: crew hangouts skipped')
		return nil
	end
	Waves.Rules = rules
	local all = ctx:group('Waves')
	for stage = 1, STAGES do
		local spots = rules.Spots[stage]
		if spots then
			local g = all:group('Hangout' .. stage)
			local x, zp, side = Waves.spotFor(spots, stage)
			local top = stageTop(stage)
			-- turned to face across the street (toward the crew), a few degrees off square
			local yaw = (side > 0 and math.pi / 2 or -math.pi / 2) + math.rad((stage * 7) % 9 - 4)
			Waves.hangout(g, CFrame.new(x, 0, top - zp) * CFrame.Angles(0, yaw, 0), rules.Crews[stage])
		end
	end
	-- The Boss Yard: the boss's armchair behind the BOSS pad, facing the way in.
	local boss = rules.Spots[STAGES + 1] and rules.Spots[STAGES + 1][1]
	if boss then Waves.throne(all:group('BossThrone'), CFrame.new(boss[1], 0, BOSS_TOP - boss[2] - 9.5) * CFrame.Angles(0, math.pi, 0)) end
	return all
end
V2.Waves = Waves -- (the unit tests and integ_waves read it)
---------------------------------------------------------------------------------------------- play here
-- Make The Block V2 the map the game runs on (players spawn here; gameplay services and the HUD use it),
-- or hand the game back to the original Block. Other spawn points are switched off, never deleted: each
-- remembers it was on (attribute HoodSpawnWasEnabled), and SetActive(false) switches it back on.
function V2.SetActive(on)
	local root = workspace:FindFirstChild('TheBlockV2')
	assert(root, 'Build The Block V2 first: require(game.ServerStorage.TheBlockV2).Build()')
	for _, d in workspace:GetDescendants() do
		if d:IsA('SpawnLocation') and not d:IsDescendantOf(root) then
			if on and d.Enabled then
				d:SetAttribute('HoodSpawnWasEnabled', true)
				d.Enabled = false
			elseif not on and d:GetAttribute('HoodSpawnWasEnabled') then
				d.Enabled = true
				d:SetAttribute('HoodSpawnWasEnabled', nil)
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA('SpawnLocation') then d.Enabled = on end
	end
	root:SetAttribute('Active', on)
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 active ' .. tostring(on)) end)
	print(on and '[TheBlockV2] Active: press Play to spawn here. SetActive(false) gives the game back to the original Block.'
		or '[TheBlockV2] Inactive: the original Block is the game map again.')
end
---------------------------------------------------------------------------------------------- build
-- The warehouse lobby's builder; V2.Lobby.Slots (name -> CFrame in the map frame) is filled by Build.
V2.Lobby = Lobby
function V2.Build()
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	SKINS = skins
	Props = require(game:GetService('ServerStorage').HoodProps)
	PROPS_KIT = { studs = studs, decor = decor, ghost = ghost, light = light, surface = surface, line = line, billboard = billboard, compact = compact, FONT = FONT }

	local old = workspace:FindFirstChild('TheBlockV2')
	if old then
		local backup = Instance.new('Folder')
		backup.Name = 'TheBlockV2_Before_' .. os.date('!%Y%m%d_%H%M%S')
		backup.Parent = game:GetService('ServerStorage')
		old.Parent = backup
	end
	local root = Instance.new('Model')
	root.Name = 'TheBlockV2'
	root:SetAttribute('BuildVersion', 'Hood Evolution W1 lobby LOBBY3 path network 146x129')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN)
	root:SetAttribute('LobbySpawnYaw', 0) -- facing north up the spine to the Stage 1 door (StageService's Lobby pads land you so)
	root:SetAttribute('MorphStand', false) -- no Morphs stands in the world any more: looks are equipped from the HUD's EVOLVE menu
	local ctx = newCtx(root, CFrame.new())

	buildGround(ctx)
	buildSpawn(ctx, skins)
	buildStages(ctx)
	if Waves then Waves.build(ctx) end -- each stage's target wave (f3_waves, MECHANICS)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('HoodSun') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn in the hood; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
