--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the World 1 training stations (7 + 1 gamepass) along the left side of the lobby,
	each in a coloured booth like the carnival shooting booths Alex sent (Oct 30): floor with a
	white start mat, caution stripe, side rails, a framed back wall behind the target with a
	"+N Power" header and two lamp posts. Plain colours, no neon.
	the Grand Cannon LaunchPoint and Launch Zone, and moves the SpawnLocation into the lobby.
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations.

	Cannon models: put the imported cannons in ReplicatedStorage > Cannons,
	named exactly as in GameConfig (Cannon01_Starter, ...). Any that are missing
	get a simple placeholder cannon so the station still works.
]]

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.GameConfig)

local SIDE = -1 -- -1 = stations on the -Z side of the lobby, 1 = +Z side
local CANNON_HEIGHT = 5 -- studs; a default character is ~5
local TARGET_DISTANCE = 12 -- muzzle to target

local map = workspace.map1b.StoneSkipMap
local lobbyCf, lobbySize = map.Lobby:GetBoundingBox()
local lobbyPos = lobbyCf.Position

-- floor height of the lobby
local hit = workspace:Raycast(lobbyPos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
local floorY = hit and hit.Position.Y or lobbyPos.Y - lobbySize.Y / 2

-- Stations sit in a row along the lobby's long (X) axis, firing towards the side wall
local fireDir = Vector3.new(0, 0, SIDE)
local rowZ = lobbyPos.Z + SIDE * 8 -- stand points, just off the centre path
local spacing = (lobbySize.X - 40) / (#Config.Stations - 1)
local startX = lobbyPos.X - (lobbySize.X - 40) / 2

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

local function makeTarget(cf)
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
	for _, x in ipairs({ -1.6, 1.6 }) do
		part({
			Size = Vector3.new(0.5, cf.Position.Y - floorY, 0.5),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			CFrame = cf * CFrame.new(x, -(cf.Position.Y - floorY) / 2, 0.5),
			Parent = m,
		}).Name = "Leg"
	end
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

-- booth colours per station Id, taken from Alex's booth pictures; plain colours, no neon
local THEMES = {
	[1] = { Main = Color3.fromRGB(45, 95, 200), Accent = Color3.fromRGB(150, 95, 55) }, -- blue + wood
	[2] = { Main = Color3.fromRGB(30, 40, 100), Accent = Color3.fromRGB(215, 50, 50) }, -- navy + red
	[3] = { Main = Color3.fromRGB(95, 185, 235), Accent = Color3.fromRGB(235, 245, 255) }, -- light blue + white
	[4] = { Main = Color3.fromRGB(235, 135, 35), Accent = Color3.fromRGB(255, 205, 70) }, -- orange
	[5] = { Main = Color3.fromRGB(210, 65, 190), Accent = Color3.fromRGB(140, 60, 220) }, -- pink
	[6] = { Main = Color3.fromRGB(235, 190, 45), Accent = Color3.fromRGB(255, 240, 200) }, -- gold
	[7] = { Main = Color3.fromRGB(105, 50, 195), Accent = Color3.fromRGB(210, 70, 210) }, -- purple (VIP)
	[8] = { Main = Color3.fromRGB(75, 190, 75), Accent = Color3.fromRGB(35, 70, 45) }, -- green
}
local function dark(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a or 0.3)
end

-- the booth around one station. at(x, y, z): x right, y up from the floor, z forward
-- from the stand point towards the target.
local function makeBooth(standCf, width, targetZ, theme, info)
	local m = Instance.new("Model")
	m.Name = "Booth"
	local function at(x, y, z)
		return standCf * CFrame.new(x, y, -z)
	end
	local function block(name, size, cf, color, collide)
		return part({ Name = name, Size = size, CFrame = cf, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = collide ~= false, CastShadow = true, Parent = m })
	end
	local back, front = targetZ + 3, -6
	local length = back - front
	local mid = (back + front) / 2
	-- floor: darker rim, coloured inner floor
	block("Floor", Vector3.new(width, 0.5, length), at(0, 0.25, mid), dark(theme.Main, 0.35))
	block("FloorInner", Vector3.new(width - 2, 0.56, length - 2), at(0, 0.28, mid), theme.Main)
	-- white start mat outline and two marks where the player stands
	local white = Color3.fromRGB(245, 245, 250)
	for _, side in ipairs({ -1, 1 }) do
		block("Mat", Vector3.new(0.35, 0.6, 7), at(side * 3.5, 0.3, -1), white, false)
		block("Mat", Vector3.new(7.35, 0.6, 0.35), at(0, 0.3, -1 + side * 3.5), white, false)
		block("Mark", Vector3.new(0.7, 0.6, 2), at(side * 0.7, 0.3, -3.2), white, false)
	end
	-- caution stripe between the mat and the cannon
	block("Stripe", Vector3.new(width - 2, 0.62, 0.7), at(0, 0.31, 2.2), Color3.fromRGB(250, 205, 40), false)
	-- low side rails
	for _, side in ipairs({ -1, 1 }) do
		block("Rail", Vector3.new(0.9, 1.6, back - 2.2), at(side * (width / 2 - 0.45), 0.8, (back + 2.2) / 2), dark(theme.Main, 0.2))
		block("RailTop", Vector3.new(1.1, 0.3, back - 2.2), at(side * (width / 2 - 0.45), 1.75, (back + 2.2) / 2), theme.Accent, false).Material = Enum.Material.Neon
	end
	-- framed back wall behind the target
	block("BackWall", Vector3.new(width, 10, 1), at(0, 5, back - 0.5), dark(theme.Main, 0.25))
	local panel = block("BackPanel", Vector3.new(width - 3, 7.5, 0.3), at(0, 4.9, back - 1.1), theme.Accent, false)
	for _, side in ipairs({ -1, 1 }) do
		block("Pillar", Vector3.new(1.5, 11.5, 1.5), at(side * (width / 2 - 0.75), 5.75, back - 0.75), theme.Main)
	end
	local header = block("Header", Vector3.new(width + 1, 2.2, 2), at(0, 11.4, back - 1), theme.Main)
	block("HeaderTrim", Vector3.new(width + 1.2, 0.4, 2.2), at(0, 10.2, back - 1), theme.Accent, false).Material = Enum.Material.Neon
	block("Crest", Vector3.new(width * 0.4, 1.2, 1.4), at(0, 13.1, back - 1), theme.Accent, false)
	-- slow sparkles drifting up in front of the target, in the booth's accent colour
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Sparkles"
	fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fx.Color = ColorSequence.new(theme.Accent:Lerp(Color3.new(1, 1, 1), 0.3))
	fx.LightEmission = 1
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fx.Lifetime = NumberRange.new(1.5, 2.5)
	fx.Rate = 4
	fx.Speed = NumberRange.new(1, 2)
	fx.SpreadAngle = Vector2.new(40, 40)
	fx.EmissionDirection = Enum.NormalId.Back -- out of the panel, towards the player
	fx.Parent = panel
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- faces the stand point
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0.3
	sg.Parent = header
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.9, 0.8)
	t.Position = UDim2.fromScale(0.05, 0.1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = "+" .. Config.Format(info.Gain) .. " Power"
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Parent = t
	t.Parent = sg
	-- two lamp posts at the front corners, soft warm light
	for _, side in ipairs({ -1, 1 }) do
		block("LampPost", Vector3.new(0.9, 3.6, 0.9), at(side * (width / 2 + 0.8), 1.8, front + 0.5), Color3.fromRGB(200, 205, 225))
		local cap = block("LampCap", Vector3.new(1.3, 0.7, 1.3), at(side * (width / 2 + 0.8), 3.95, front + 0.5), theme.Accent:Lerp(Color3.new(1, 1, 1), 0.5), false)
		cap.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4)
		light.Brightness = 1.2
		light.Range = 10
		light.Parent = cap
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
local boothWidth = math.min(11, spacing - 5) -- grass shows between booths

for i, info in ipairs(order) do
	local station = Instance.new("Model")
	station.Name = "Station_" .. info.Id
	station:SetAttribute("StationId", info.Id)

	local standPos = Vector3.new(startX + (i - 1) * spacing, floorY, rowZ)
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
	local cannonPos = standPos + fireDir * (2.5 + size.Z / 2)
	-- imported cannons point their barrel along +Z, so face +Z at the target
	cannon:PivotTo(CFrame.lookAt(cannonPos, cannonPos - fireDir))
	local cf, sz = cannon:GetBoundingBox()
	cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, floorY - (cf.Position.Y - sz.Y / 2), 0))
	cannon.Parent = station

	local muzzlePos = cannonPos + fireDir * (size.Z / 2) + Vector3.new(0, floorY + size.Y * 0.62 - cannonPos.Y, 0)
	part({ Name = "Muzzle", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CFrame = CFrame.lookAt(muzzlePos, muzzlePos + fireDir), Parent = station })

	local targetPos = muzzlePos + fireDir * TARGET_DISTANCE
	makeTarget(CFrame.lookAt(targetPos, targetPos - fireDir)).Parent = station
	local targetZ = (targetPos - standPos):Dot(fireDir)
	makeBooth(CFrame.lookAt(Vector3.new(standPos.X, floorY, standPos.Z), Vector3.new(standPos.X, floorY, standPos.Z) + fireDir), boothWidth, targetZ, THEMES[info.Id] or THEMES[1], info).Parent = station

	makeSign(CFrame.new(standPos + fireDir * 4 + Vector3.new(0, CANNON_HEIGHT + 4, 0)), info).Parent = station
	station.PrimaryPart = pad
	station.Parent = folder
end
folder.Parent = workspace

-- Grand Cannon launch point
local grand = map.Grand_Cannon
local gcf, gsize = grand:GetBoundingBox()
local lp = workspace:FindFirstChild("LaunchPoint") or part({ Name = "LaunchPoint" })
lp.Size = Vector3.new(6, 1, 6)
lp.Transparency = 1
lp.CanCollide = false
lp.Position = gcf.Position + Vector3.new(0, gsize.Y / 2 + 4, 0)
lp.Parent = workspace
local oldPrompt = lp:FindFirstChildOfClass("ProximityPrompt")
if oldPrompt then
	oldPrompt:Destroy()
end

-- Launch Zone: walk in and the Grand Cannon fires you (like Stone Skipping's Throw Zone)
local old = workspace:FindFirstChild("LaunchZone")
if old then
	old:Destroy()
end
local zonePos = Vector3.new(gcf.Position.X - gsize.X / 2 - 14, floorY + 0.1, gcf.Position.Z)
local zone = part({
	Name = "LaunchZone",
	Size = Vector3.new(16, 0.2, 26),
	CFrame = CFrame.new(zonePos),
	Color = Color3.fromRGB(255, 200, 40),
	Material = Enum.Material.Neon,
	Transparency = 0.15,
	CanCollide = false,
	Parent = workspace,
})
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Top
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 30
surface.LightInfluence = 0
surface.Parent = zone
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Rotation = 90
label.Font = Enum.Font.FredokaOne
label.Text = "LAUNCH ZONE"
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = surface
local stroke = Instance.new("UIStroke")
stroke.Thickness = 6
stroke.Color = Color3.fromRGB(120, 60, 0)
stroke.Parent = label
local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(260, 70)
board.StudsOffset = Vector3.new(0, 9, 0)
board.LightInfluence = 0
board.MaxDistance = 250
board.Parent = zone
local boardText = label:Clone()
boardText.Rotation = 0
boardText.Text = "WALK IN TO LAUNCH!"
boardText.TextColor3 = Color3.fromRGB(255, 230, 90)
boardText.Parent = board
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
sparkle.Rate = 12
sparkle.Speed = NumberRange.new(3, 6)
sparkle.Lifetime = NumberRange.new(1, 1.6)
sparkle.EmissionDirection = Enum.NormalId.Top
sparkle.Size = NumberSequence.new(0.8, 0)
sparkle.Parent = zone

-- Spawn in the lobby, on the centre path, facing the Grand Cannon
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local p = Vector3.new(lobbyPos.X - lobbySize.X * 0.3, floorY + 0.5, lobbyPos.Z)
	spawn.CFrame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
	spawn.Anchored = true
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
