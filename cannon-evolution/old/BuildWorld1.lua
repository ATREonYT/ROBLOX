--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the World 1 training stations (6 + 1 gamepass) along the left side of the lobby,
	the Grand Cannon LaunchPoint, and moves the SpawnLocation into the lobby.
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations.

	Cannon models: put the imported cannons in ServerStorage > TrainingCannons,
	named exactly as in GameConfig (Cannon01_Starter, ...). Any that are missing
	get a simple placeholder cannon so the station still works.
]]

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.GameConfig)

local SIDE = -1 -- -1 = stations on the -Z side of the lobby, 1 = +Z side
local CANNON_HEIGHT = 6 -- studs; a default character is ~5
local TARGET_DISTANCE = 16 -- muzzle to target

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
			Material = Enum.Material.SmoothPlastic,
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
	line("+" .. Config.Format(info.Gain) .. " 💪 per shot", 0.4, 0.32, Color3.fromRGB(255, 215, 70))
	local req
	if info.GamePass then
		req = "⭐ GAMEPASS ⭐"
	elseif info.Rebirths > 0 then
		req = "Requires " .. info.Rebirths .. " Rebirths 🔄"
	else
		req = "FREE"
	end
	line(req, 0.72, 0.28, info.GamePass and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(140, 255, 150))
	return sign
end

local PAD_COLORS = {
	Color3.fromRGB(120, 220, 120), Color3.fromRGB(150, 160, 175), Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(190, 80, 255), -- gamepass
}

local templates = ServerStorage:FindFirstChild("TrainingCannons")

for i, info in ipairs(Config.Stations) do
	local station = Instance.new("Model")
	station.Name = "Station_" .. info.Id
	station:SetAttribute("StationId", info.Id)

	local standPos = Vector3.new(startX + (i - 1) * spacing, floorY, rowZ)
	local standCf = CFrame.lookAt(standPos, standPos + fireDir)

	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		Color = PAD_COLORS[i],
		Material = Enum.Material.Neon,
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
		warn("[BuildWorld1] Missing " .. info.Model .. " in ServerStorage.TrainingCannons, using placeholder")
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
local prompt = lp:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
prompt.ActionText = "LAUNCH!"
prompt.ObjectText = "Grand Cannon"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 40
prompt.RequiresLineOfSight = false
prompt.Parent = lp

-- Spawn in the lobby, on the centre path, facing the Grand Cannon
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local p = Vector3.new(lobbyPos.X - lobbySize.X * 0.3, floorY + 0.5, lobbyPos.Z)
	spawn.CFrame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
	spawn.Anchored = true
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
