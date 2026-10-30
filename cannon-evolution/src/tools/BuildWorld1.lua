--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the training stations (5 + 1 gamepass, GameConfig) round the lobby, each an open
	booth: a stepped floor in the booth's colours, white start mat, hazard stripe, the cannon on
	its plinth and a target on its own stand, with neon edges on the top tiers. No back wall,
	counter or lane props any more (Alex, Oct 30: "try removing the back wall of the training
	zones and just keep the target and the cannon"). Run BuildRebirthSigns and BuildCartoonyMap
	(the studs) after it. It also places the Grand Cannon LaunchPoint and Launch Zone, and
	moves the SpawnLocation into the lobby.
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations.

	Cannon models: put the imported cannons in ReplicatedStorage > Cannons,
	named exactly as in GameConfig (Cannon01_Starter, ...). Any that are missing
	get a simple placeholder cannon so the station still works.
]]

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.GameConfig)

local SIDE = 1 -- -1 = stations on the -Z side of the lobby, 1 = +Z side (Alex, Oct 30: training on your left as you face the water, the cannonball stand on your right)
local CANNON_HEIGHT = 6 -- studs; a default character is ~5
local PLINTH = 1.2 -- the cannon stands on a plinth in its booth's colours, so it shows above the counter (Alex, Oct 30)
local TARGET_DISTANCE = 12 -- muzzle to target

-- Alex's new map (Workspace.CannonMap, Oct 30) or the old one
local newMap = workspace:FindFirstChild(Config.Map.Root)
local lobbyPos, lobbySize
if newMap then
	lobbyPos, lobbySize = Config.Map.LobbyCenter, Config.Map.LobbySize
else
	local lobbyCf
	lobbyCf, lobbySize = workspace.map1b.StoneSkipMap.Lobby:GetBoundingBox()
	lobbyPos = lobbyCf.Position
end

-- floor height under a point (the map only, nothing we build; on the new map only its ground, never a palm or rock)
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { newMap or workspace.map1b }
if newMap then
	local ground = {}
	for _, p in ipairs(newMap:GetDescendants()) do
		if p:IsA("BasePart") and Config.Map.IsGround(p.Name) then
			table.insert(ground, p)
		end
	end
	floorParams.FilterDescendantsInstances = ground
end
local function floorAt(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), floorParams)
	return hit and hit.Position.Y or fallback
end
local floorY = floorAt(lobbyPos.X, lobbyPos.Z, lobbyPos.Y - lobbySize.Y / 2)

-- Stations sit in a row along the lobby's long (X) axis, firing towards the side wall
local fireDir = Vector3.new(0, 0, SIDE)
local rowZ = lobbyPos.Z + SIDE * 21 -- stand points, set back so the booth fronts clear the spawn and launch zone
-- booths stand side by side like Alex's pictures, the row centred in the lobby
-- booths are built full size, then each station is scaled down to BOOTH_SCALE so the row fits the lobby (Alex, Oct 30)
local BOOTH_SCALE = 0.8
-- spaced out with a walkway between booths like the Stone Skipping pads (Alex, Oct 30): the row now
-- runs from near the water's edge to where it used to end, by the side building at the far end
local ROW_END = lobbyPos.X - 10 + 15 * BOOTH_SCALE * 3.5 + 7 * BOOTH_SCALE -- far edge of the old row
local ROW_START = lobbyPos.X - lobbySize.X / 2 + 6
local spacing = (ROW_END - ROW_START - 14 * BOOTH_SCALE) / (#Config.Stations - 1)
local startX = ROW_START + 7 * BOOTH_SCALE
-- where booth i stands: { stand point, firing direction }
local function slot(i)
	return Vector3.new(startX + (i - 1) * spacing, floorY, rowZ), fireDir
end

if newMap then
	-- New map: six booths (Alex, Oct 30: "make like 5 or 6 so we can fit them better into the lobby") side by
	-- side in one block on the north side of the plaza, like the training lanes in his reference game
	-- ("put them into one spot and make them fit nicely like in the references"), all firing north towards
	-- the palisade, with a 2.5-stud strip of ground between neighbours. Booth 1 is at the east end, nearest
	-- the dock; the VIP booth is the west one. The block's middle is in the map file's units (Config.Map.At
	-- moves it out with the map); checked against every rock, palm and fence by tools/map/plan_check.py.
	-- Alex, Oct 30: "make the trainings a bit bigger, bring them close to the lobby, just a little".
	BOOTH_SCALE = 0.9
	local MIDDLE, PITCH = Config.Map.At(-61, 0, -22), 14 * BOOTH_SCALE + 2.5 -- the middle stand point; booth width + gap
	fireDir = Vector3.new(0, 0, -1)
	local function x(i)
		return MIDDLE.X - (i - (#Config.Stations + 1) / 2) * PITCH
	end
	-- one floor height for the whole block, so the booths line up: the highest ground under any of them
	local blockY = -math.huge
	for i = 1, #Config.Stations do
		for _, z in ipairs({ MIDDLE.Z + 5, MIDDLE.Z, MIDDLE.Z - 12, MIDDLE.Z - 22 }) do
			blockY = math.max(blockY, floorAt(x(i), z, floorY))
		end
	end
	slot = function(i)
		return Vector3.new(x(i), blockY, MIDDLE.Z), fireDir
	end
end

local old = workspace:FindFirstChild("TrainingStations")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "TrainingStations"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function placeholderCannon()
	local m = Instance.new("Model")
	local base = part({ Size = Vector3.new(4, 1.5, 5), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, Parent = m })
	base.Name = "Base"
	local barrel = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.4, 2.4),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, 2, 0.5) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(12)),
		Parent = m,
	})
	barrel.Name = "Barrel"
	m.PrimaryPart = base
	return m
end

-- the target on its own wooden stand: two legs down to ground (the booth's floor top) and a foot
local function makeTarget(cf, ground)
	local m = Instance.new("Model")
	m.Name = "Target"
	local rings = {
		{ 6, Color3.fromRGB(235, 60, 60) },
		{ 4.4, Color3.new(1, 1, 1) },
		{ 2.8, Color3.fromRGB(235, 60, 60) },
		{ 1.2, Color3.fromRGB(255, 210, 60) },
	}
	for i, r in ipairs(rings) do
		local disc = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, r[1], r[1]),
			Color = r[2],
			Material = i == #rings and Enum.Material.Neon or Enum.Material.SmoothPlastic, -- glowing bullseye
			CanCollide = false,
			CFrame = cf * CFrame.new(0, 0, -0.1 * i) * CFrame.Angles(0, math.rad(90), 0),
			Parent = m,
		})
		disc.Name = "Ring"
	end
	-- invisible aim point; its front faces the cannon
	part({ Name = "Center", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CFrame = cf * CFrame.new(0, 0, -0.5), Parent = m })
	local h = cf.Position.Y - ground
	for _, x in ipairs({ -1.6, 1.6 }) do
		part({
			Size = Vector3.new(0.6, h, 0.6),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			CFrame = cf * CFrame.new(x, -h / 2, 0.55),
			Parent = m,
		}).Name = "Leg"
	end
	part({ Name = "Foot", Size = Vector3.new(4.6, 0.5, 1.6), Color = Color3.fromRGB(85, 55, 35), Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0, 0.25 - h, 0.55), Parent = m })
	m.PrimaryPart = m.Center
	return m
end

local function makeSign(cf, info)
	local sign = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = cf, Name = "Sign" })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 4)
	bb.MaxDistance = 120
	bb.Parent = sign
	local function line(text, y, h, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, h)
		t.Position = UDim2.fromScale(0, y)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Parent = t
		t.Parent = bb
	end
	line(info.Name, 0, 0.4, Color3.new(1, 1, 1))
	line("+" .. Config.Format(info.Gain) .. " Power per shot", 0.4, 0.32, Color3.fromRGB(255, 215, 70))
	local req
	if info.Pass then
		req = "VIP GAMEPASS"
	elseif info.Rebirths > 0 then
		req = "Requires " .. info.Rebirths .. " Rebirths"
	else
		req = "FREE"
	end
	line(req, 0.72, 0.28, info.Pass and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(140, 255, 150))
	return sign
end

-- Booth looks, one per station Id (GameConfig), from Alex's two booth pictures (Oct 30): the low
-- tiers are matte, the high tiers glow with neon edges. Rim and Floor colour the booth, Counter the
-- cannon's plinth top, Rings the target.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local THEMES = {
	[1] = { Rim = rgb(35, 70, 170), Floor = rgb(65, 115, 215), Counter = rgb(150, 75, 45) }, -- Starter: blue fair
	[2] = { Rim = rgb(110, 190, 240), Floor = rgb(170, 225, 250), Counter = rgb(60, 140, 220), Neon = rgb(80, 190, 255), Rings = { rgb(60, 160, 240), rgb(255, 255, 255), rgb(60, 160, 240), rgb(255, 255, 255) } }, -- Steel: ice
	[3] = { Rim = rgb(235, 120, 20), Floor = rgb(250, 165, 40), Counter = rgb(240, 150, 40), Edge = rgb(255, 150, 40) }, -- Heavy: orange stage
	[4] = { Rim = rgb(235, 185, 25), Floor = rgb(255, 215, 60), Counter = rgb(240, 190, 40), Neon = rgb(255, 245, 210), Rings = { rgb(255, 200, 40), rgb(255, 225, 110), rgb(220, 40, 40), rgb(255, 200, 40) } }, -- Golden: gold
	[5] = { Rim = rgb(70, 215, 60), Floor = rgb(30, 110, 45), Counter = rgb(60, 190, 55), Neon = rgb(110, 255, 90), Rings = { rgb(110, 255, 90), rgb(20, 70, 35), rgb(110, 255, 90), rgb(255, 255, 255) } }, -- Plasma: toxic green
	[6] = { Rim = rgb(85, 30, 200), Floor = rgb(40, 20, 105), Counter = rgb(85, 30, 200), Neon = rgb(255, 60, 230), Rings = { rgb(255, 60, 230), rgb(45, 15, 95), rgb(255, 60, 230), rgb(45, 15, 95) } }, -- Dragon (VIP): neon purple
}
local function dark(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a or 0.3)
end
local WHITE = rgb(245, 245, 250)

-- the booth around one station. at(x, y, z): x right, y up from the floor, z forward
-- from the stand point towards the target.
local function makeBooth(standCf, width, targetZ, theme, info)
	local m = Instance.new("Model")
	m.Name = "Booth"
	local W = width
	local front, back = -6, targetZ + 2.2 -- room behind the target for its stand
	local L = back - front
	local function at(x, y, z)
		return standCf * CFrame.new(x, y, -z)
	end
	local function blk(name, size, x, y, z, color, collide)
		return part({ Name = name, Size = size, CFrame = at(x, y, z), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = collide == true, Parent = m })
	end
	local function glow(name, size, x, y, z, color)
		local p = blk(name, size, x, y, z, color)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		return p
	end
	-- floor: chunky stepped corners, a rim and the coloured floor on top
	blk("Rim", Vector3.new(W, 0.6, L - 2), 0, 0.3, (front + back) / 2, theme.Rim, true)
	blk("Rim", Vector3.new(W - 2, 0.6, L), 0, 0.3, (front + back) / 2, theme.Rim, true)
	blk("Floor", Vector3.new(W - 1.6, 0.7, L - 3.6), 0, 0.35, (front + back) / 2, theme.Floor, true)
	blk("Floor", Vector3.new(W - 3.6, 0.7, L - 1.6), 0, 0.35, (front + back) / 2, theme.Floor, true)
	do
		-- glowing outline: the front edge on every booth, the sides too from the stage booth up
		-- (glow grows with the tier, like the pictures: plain low booths, outlined high ones)
		local c = theme.Neon or theme.Edge or theme.Rim:Lerp(WHITE, 0.45)
		glow("Edge", Vector3.new(W - 2, 0.2, 0.3), 0, 0.62, front + 0.15, c)
		if theme.Neon or (theme.Edge and info.Rebirths >= 6) then
			for _, s in ipairs({ -1, 1 }) do
				glow("Edge", Vector3.new(0.3, 0.2, L - 2), s * (W / 2 - 0.15), 0.62, (front + back) / 2, c)
			end
		end
		if theme.Neon then
			-- the top tiers also glow on the floor itself: a neon line just inside the floor's edge
			local iw, il = W - 4.6, L - 4.6
			for _, s in ipairs({ -1, 1 }) do
				glow("FloorLine", Vector3.new(0.25, 0.08, il), s * iw / 2, 0.72, (front + back) / 2, c)
			end
			-- across the back only; the front already has its edge glow and the start mat
			glow("FloorLine", Vector3.new(iw + 0.25, 0.08, 0.25), 0, 0.72, (front + back) / 2 + il / 2, c)
		end
	end

	-- start mat: white outline and the two marks
	local matW, z0, z1 = W - 4.4, front + 1.6, 0.6
	blk("MatFill", Vector3.new(matW, 0.05, z1 - z0), 0, 0.72, (z0 + z1) / 2, dark(theme.Floor, 0.22))
	for _, s in ipairs({ -1, 1 }) do
		blk("Mat", Vector3.new(0.25, 0.08, z1 - z0), s * matW / 2, 0.74, (z0 + z1) / 2, WHITE)
		blk("Mat", Vector3.new(matW + 0.25, 0.08, 0.25), 0, 0.74, s == -1 and z0 or z1, WHITE)
		blk("Mark", Vector3.new(0.45, 0.08, 1.4), s * 0.45, 0.74, -0.5, WHITE)
	end
	-- black and yellow hazard stripe
	blk("Hazard", Vector3.new(W - 3.6, 0.1, 0.5), 0, 0.75, 1.0, rgb(25, 25, 30))
	for x = -(W - 4.6) / 2, (W - 4.6) / 2, 1 do
		blk("Hazard", Vector3.new(0.45, 0.12, 0.5), x, 0.76, 1.0, rgb(250, 200, 30))
	end

	-- the shot's lane: a darker strip from the cannon to the target's foot
	blk("Lane", Vector3.new(5, 0.05, back - 2.8), 0, 0.72, (1.6 + back - 1.2) / 2, dark(theme.Floor, 0.12))

	-- the rebirth sign over the booth (icon, rebirths, multiplier) comes from BuildRebirthSigns
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m
end

local templates = game.ReplicatedStorage:FindFirstChild("Cannons")

-- row order: by rebirths needed, the VIP booth last
local order = table.clone(Config.Stations)
table.sort(order, function(a, b)
	local ka = a.Pass and math.huge or a.Rebirths
	local kb = b.Pass and math.huge or b.Rebirths
	return ka < kb
end)
local boothWidth = 14

for i, info in ipairs(order) do
	local station = Instance.new("Model")
	station.Name = "Station_" .. info.Id
	station:SetAttribute("StationId", info.Id)

	local standPos, fireDir = slot(i)
	-- built at full size around this point, scaled to BOOTH_SCALE below
	local standCf = CFrame.lookAt(standPos, standPos + fireDir)

	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		Transparency = 1, -- the booth's start mat shows where to stand
		CanCollide = false,
		CFrame = CFrame.new(standPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = station,
	})
	part({ Name = "StandPoint", Size = Vector3.new(1, 0.2, 1), Transparency = 1, CanCollide = false, CanTouch = false, CFrame = standCf, Parent = station })

	-- Cannon, scaled to CANNON_HEIGHT and facing the target
	local cannon
	local template = templates and templates:FindFirstChild(info.Model)
	if template then
		cannon = template:Clone()
	else
		cannon = placeholderCannon()
		warn("[BuildWorld1] Missing " .. info.Model .. " in ReplicatedStorage.Cannons, using placeholder")
	end
	cannon.Name = "Cannon"
	for _, d in ipairs(cannon:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local _, size = cannon:GetBoundingBox()
	cannon:ScaleTo(cannon:GetScale() * CANNON_HEIGHT / size.Y)
	_, size = cannon:GetBoundingBox()
	local theme = THEMES[info.Id] or THEMES[1]
	local floorY = standPos.Y -- this booth's own floor
	local cannonPos = standPos + fireDir * (2.5 + size.Z / 2)
	local plinthCf = CFrame.lookAt(cannonPos, cannonPos + fireDir) + Vector3.new(0, floorY + PLINTH / 2 - cannonPos.Y, 0)
	part({ Name = "Plinth", Size = Vector3.new(size.X + 1, PLINTH, size.Z + 0.6), CFrame = plinthCf, Color = dark(theme.Rim, 0.15), CanCollide = false, Parent = station })
	part({ Name = "PlinthTop", Size = Vector3.new(size.X + 1.4, 0.3, size.Z + 1), CFrame = plinthCf + Vector3.new(0, PLINTH / 2 + 0.15, 0), Color = theme.Counter, CanCollide = false, Parent = station })
	local glow = theme.Neon or theme.Edge
	if glow then
		part({ Name = "PlinthGlow", Size = Vector3.new(size.X + 1.1, 0.15, size.Z + 0.7), CFrame = plinthCf + Vector3.new(0, PLINTH / 2 - 0.15, 0), Color = glow, Material = Enum.Material.Neon, CanCollide = false, Parent = station })
	end
	-- imported cannons point their barrel along +Z, so face +Z at the target
	cannon:PivotTo(CFrame.lookAt(cannonPos, cannonPos - fireDir))
	local cf, sz = cannon:GetBoundingBox()
	cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, floorY + PLINTH + 0.3 - (cf.Position.Y - sz.Y / 2), 0))
	cannon.Parent = station

	local muzzlePos = cannonPos + fireDir * (size.Z / 2) + Vector3.new(0, floorY + PLINTH + 0.3 + size.Y * 0.62 - cannonPos.Y, 0)
	part({ Name = "Muzzle", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CFrame = CFrame.lookAt(muzzlePos, muzzlePos + fireDir), Parent = station })

	local targetPos = muzzlePos + fireDir * TARGET_DISTANCE
	local target = makeTarget(CFrame.lookAt(targetPos, targetPos - fireDir), floorY + 0.7) -- stands on the booth floor
	-- themed ring colours
	local ring = 0
	for _, d in ipairs(target:GetChildren()) do
		if d.Name == "Ring" and theme.Rings then
			ring += 1
			d.Color = theme.Rings[ring] or d.Color
			if theme.Neon and ring % 2 == 1 then
				d.Material = Enum.Material.Neon
			end
		end
	end
	target.Parent = station
	local targetZ = (targetPos - standPos):Dot(fireDir)
	makeBooth(CFrame.lookAt(Vector3.new(standPos.X, floorY, standPos.Z), Vector3.new(standPos.X, floorY, standPos.Z) + fireDir), boothWidth, targetZ, THEMES[info.Id] or THEMES[1], info).Parent = station

	-- the booth's glow colour, used by the client for its shots and hit effects
	station:SetAttribute("Accent", theme.Neon or theme.Edge or theme.Rim:Lerp(WHITE, 0.3))
	station.PrimaryPart = pad
	station:ScaleTo(BOOTH_SCALE)
	station.Parent = folder
end
folder.Parent = workspace

-- Launch from the start of the water (Alex, Oct 30): your cannon stands at the lobby's
-- water edge, pointing down the long map, and the Launch Zone is right behind it so you
-- walk up to your cannon. LaunchPoint is where everyone's ball leaves from.
local dirL = Config.LAUNCH_DIRECTION.Unit
local edge = lobbyPos + dirL * (math.abs(dirL.X) * lobbySize.X / 2 + math.abs(dirL.Z) * lobbySize.Z / 2)
local trackZ = lobbyPos.Z -- the middle of the water strip
local cannonSpot = Vector3.new(edge.X, floorY, trackZ) - dirL * 8 -- your cannon's feet, nose at the water
if newMap then
	-- the end of the launch dock, nose over the river
	local d = Config.Map.DockEnd
	trackZ = d.Z
	cannonSpot = Vector3.new(d.X, floorAt(d.X, d.Z, d.Y), d.Z)
	floorY = cannonSpot.Y
end
local spotPart = workspace:FindFirstChild("MyCannonSpot") or part({ Name = "MyCannonSpot" })
spotPart.Size = Vector3.new(1, 0.2, 1)
spotPart.Transparency = 1
spotPart.CanCollide = false
spotPart.CanQuery = false
spotPart.CanTouch = false
spotPart.CFrame = CFrame.lookAt(cannonSpot, cannonSpot + dirL)
spotPart.Parent = workspace
local lp = workspace:FindFirstChild("LaunchPoint") or part({ Name = "LaunchPoint" })
lp.Size = Vector3.new(6, 1, 6)
lp.Transparency = 1
lp.CanCollide = false
lp.Position = cannonSpot + dirL * 8 + Vector3.new(0, 6, 0)
lp.Parent = workspace
local oldPrompt = lp:FindFirstChildOfClass("ProximityPrompt")
if oldPrompt then
	oldPrompt:Destroy()
end

-- Launch Zone: right behind your cannon; walk in and it fires you (like Stone Skipping's Throw Zone)
local old = workspace:FindFirstChild("LaunchZone")
if old then
	old:Destroy()
end
local zonePos = Vector3.new(cannonSpot.X, floorY + 0.1, trackZ) - dirL * (newMap and 11 or 17)
-- invisible now: no yellow floor (Alex, Oct 30); standing in it shows the LAUNCH button
local zone = part({
	Name = "LaunchZone",
	Size = newMap and Vector3.new(8, 0.2, 10 * Config.Map.Scale) or Vector3.new(16, 0.2, 26), -- new map: the dock is 11 wide in the file
	CFrame = CFrame.new(zonePos),
	Color = Color3.fromRGB(255, 200, 40),
	Transparency = 1,
	CanCollide = false,
	Parent = workspace,
})
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.FredokaOne
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(60, 30, 90)
stroke.Parent = label
local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(220, 50)
board.StudsOffset = Vector3.new(0, 3, 0) -- under the cannon's name tag, not on top of it
board.LightInfluence = 0
board.MaxDistance = 250
board.Parent = zone
local boardText = label:Clone()
boardText.Rotation = 0
boardText.Text = "LAUNCH ZONE" -- stand here and the LAUNCH button pops up (LaunchButton.lua)
boardText.Parent = board

-- Spawn in the lobby, a short walk behind the Launch Zone, facing your cannon and the water
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local p = Vector3.new(zonePos.X, floorY + 0.5, trackZ) - dirL * 30
	if newMap then
		-- on the compass plaza, facing the dock
		local sp = Config.Map.Spawn
		p = Vector3.new(sp.X, floorAt(sp.X, sp.Z, sp.Y) + 0.5, sp.Z)
	end
	spawn.CFrame = CFrame.lookAt(p, p + dirL)
	spawn.Anchored = true
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
