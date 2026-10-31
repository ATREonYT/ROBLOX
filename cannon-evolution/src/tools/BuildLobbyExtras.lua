--[[
	BuildLobbyExtras: paste into the Command Bar once (already run in the place).
	Builds the 4 egg stands by the Grand Cannon (walk up to one and the egg
	menu opens on it) and the see-through coloured borders between the areas
	along the track (the cannonball's flight shows each area's name).
	Safe to run again: it replaces EggStands, EggSign and AreaBorders.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local function part(props)
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function label(parent, text, color, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size or UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(30, 20, 40)
	s.Parent = l
	return l
end

---------------------------------------------------------------------------
-- Egg stands
---------------------------------------------------------------------------
for _, name in ipairs({ "EggStands", "EggSign" }) do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local folder = Instance.new("Folder")
folder.Name = "EggStands"
local floorY = 8.45
local newMap = workspace:FindFirstChild(Config.Map.Root)
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { newMap or workspace.map1b, workspace:FindFirstChild("LobbyWalkways") }
local function floorAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), floorParams)
	return hit and hit.Position.Y or floorY
end
local EGG_COLORS = {
	Starter = Color3.fromRGB(120, 220, 120),
	Woodland = Color3.fromRGB(150, 110, 60),
	Nature = Color3.fromRGB(80, 200, 90),
	Ocean = Color3.fromRGB(60, 160, 255),
}
local EGGS = { "Starter", "Woodland", "Nature", "Ocean" } -- the exclusive egg goes 5th
-- new map: a row on the grass along the south side of the west plank path, facing it, so walking the
-- path opens each egg's menu (Alex, Oct 31; the path is BuildLobbyWalkways'). Spot 0, nearest the spawn,
-- stays free for a Robux pet or egg (Alex decides). In the map file's units: Starter's spot and the step.
local ROW_START, ROW_STEP = Vector2.new(-77, 8.5), Vector2.new(-8, 0)
local function eggSpot(i) -- i = 0 is the free Robux spot
	return ROW_START + ROW_STEP * (i - 1)
end
for i, id in ipairs(EGGS) do
	local egg = Config.GetEgg(id)
	local pos = Vector3.new(-34 - (#EGGS - i) * 16, floorY, -108)
	if newMap then
		-- new map: in the row (eggSpot above); Config.Map.At moves it out with the map
		local spot = eggSpot(i)
		local p = Config.Map.At(spot.X, 0, spot.Y)
		pos = Vector3.new(p.X, floorAt(p.X, p.Z), p.Z)
	end
	local stand = Instance.new("Model")
	stand.Name = id .. "Egg"
	stand:SetAttribute("EggId", id)
	-- no pad or neon ring: the egg models bring their own stand (Alex, Oct 30)
	local template = game.ReplicatedStorage.Eggs:FindFirstChild(egg.Model)
	local eggModel
	if template then
		eggModel = template:Clone()
		if eggModel:IsA("BasePart") then
			local m = Instance.new("Model")
			eggModel.Parent = m
			eggModel = m
		end
		for _, d in ipairs(eggModel:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		local _, size = eggModel:GetBoundingBox()
		eggModel:ScaleTo(eggModel:GetScale() * 6.5 / math.max(size.Y, 0.1))
	else
		eggModel = Instance.new("Model")
		part({ Shape = Enum.PartType.Ball, Size = Vector3.new(5, 6.5, 5), Color = EGG_COLORS[id], CanCollide = false, Parent = eggModel })
	end
	eggModel.Name = "Egg"
	local _, eggSize = eggModel:GetBoundingBox()
	eggModel:PivotTo(CFrame.new(pos + Vector3.new(0, eggSize.Y / 2, 0)))
	-- then sit it on the ground: an egg model's pivot isn't always its middle (they floated 3 studs up, Oct 30)
	local box = eggModel:GetBoundingBox()
	eggModel:PivotTo(eggModel:GetPivot() + Vector3.new(0, pos.Y - (box.Y - eggSize.Y / 2), 0))
	eggModel.Parent = stand
	local base = eggModel:FindFirstChildWhichIsA("BasePart", true)

	-- no PointLight: it washed the eggs out (Alex, Oct 30)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(7, 2.6) -- sized in studs, so neighbouring signs never overlap from afar
	board.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	board.LightInfluence = 0
	board.MaxDistance = 120
	board.Adornee = base
	board.Parent = stand
	label(board, egg.Name, Color3.new(1, 1, 1), UDim2.fromScale(1, 0.55))
	local price = egg.Currency == "Cash" and ("$" .. Config.Format(egg.Price))
		or egg.Currency == "Gems" and (Config.Format(egg.Price) .. " Gems")
		or "R$"
	label(board, price, Color3.fromRGB(120, 255, 120), UDim2.fromScale(1, 0.45)).Position = UDim2.fromScale(0, 0.55)
	stand.PrimaryPart = base
	stand.WorldPivot = CFrame.new(pos)
	stand.Parent = folder
end
folder.Parent = workspace

-- the big EGGS sign: the old map only (Alex took it out of the new lobby, Oct 30)
if not newMap then
	local signPos = Vector3.new(-58, floorY + 17, -100)
	local sign = part({ Name = "EggSign", Size = Vector3.new(30, 6, 0.6), CFrame = CFrame.lookAt(signPos, signPos + Vector3.new(0, 0, -1)), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = workspace })
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 25
	signGui.Parent = sign
	label(signGui, "🥚 EGGS 🥚", Color3.new(1, 1, 1))
end

---------------------------------------------------------------------------
-- Area borders
---------------------------------------------------------------------------
local THEMES = {
	Training_Grounds = { "🌱", Color3.fromRGB(110, 220, 90), "Training Grounds" },
	Starter_Coast = { "🏖️", Color3.fromRGB(255, 215, 110), "Starter Coast" },
	Pirate_Cove = { "🏴‍☠️", Color3.fromRGB(70, 150, 230), "Pirate Cove" },
	Desert_Canyon = { "🌵", Color3.fromRGB(235, 150, 60), "Desert Canyon" },
	Autumn_Fortress = { "🍁", Color3.fromRGB(235, 100, 40), "Autumn Fortress" },
	Frozen_Valley = { "❄️", Color3.fromRGB(150, 220, 255), "Frozen Valley" },
	Volcanic_Island = { "🌋", Color3.fromRGB(240, 70, 40), "Volcanic Island" },
	Sky_Kingdom = { "☁️", Color3.fromRGB(255, 230, 140), "Sky Kingdom" },
}
local function titleCase(s)
	return (s:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b)
		return a:upper() .. b
	end))
end
-- one plain name per side, like the Stone Skipping area walls (Alex, Oct 30)
local function borderFace(p, normal, title)
	local sg = Instance.new("SurfaceGui")
	sg.Face = normal
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 8
	sg.Parent = p
	local l = label(sg, title, Color3.new(1, 1, 1), UDim2.fromScale(0.86, 0.3))
	l.Position = UDim2.fromScale(0.07, 0.3)
	l.UIStroke.Thickness = 6
end

local old = workspace:FindFirstChild("AreaBorders")
if old then
	old:Destroy()
end
local borders = Instance.new("Folder")
borders.Name = "AreaBorders"
local dir = Config.LAUNCH_DIRECTION.Unit
local WATER_Y = 5.5
local HEIGHT, WIDTH = 46, 104
local props = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local function addBorder(areaName, color, x, z)
	local pos = Vector3.new(x, WATER_Y + HEIGHT / 2, z)
	local b = part({ Name = areaName, Size = Vector3.new(0.4, HEIGHT, WIDTH), CFrame = CFrame.new(pos), Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 0.35 })
	for k, v in pairs(props) do
		b[k] = v
	end
	b:SetAttribute("AreaName", areaName)
	borderFace(b, Enum.NormalId.Right, areaName)
	borderFace(b, Enum.NormalId.Left, areaName)
	b.Parent = borders
end
if newMap then
	-- one wall where each of the map's stages starts along the river (Config.Map.StageStarts)
	WATER_Y, HEIGHT, WIDTH = Config.Map.WaterY, 34 * Config.Map.Scale, 84 * Config.Map.Scale
	local STAGE_COLORS = {
		["Meadow Pond"] = Color3.fromRGB(110, 220, 90), ["Mushroom Grove"] = Color3.fromRGB(230, 90, 110),
		["Sandy Shore"] = Color3.fromRGB(255, 215, 110), ["Lighthouse Point"] = Color3.fromRGB(240, 240, 255),
		["Shipwreck Bay"] = Color3.fromRGB(70, 150, 230), ["Skull Rock"] = Color3.fromRGB(150, 150, 170),
		["Red Mesa"] = Color3.fromRGB(235, 120, 60), ["Ancient Ruins"] = Color3.fromRGB(200, 180, 120),
		["Maple Woods"] = Color3.fromRGB(235, 100, 40), ["Fortress Walls"] = Color3.fromRGB(170, 160, 150),
		["Igloo Camp"] = Color3.fromRGB(180, 230, 255), ["Aurora Peaks"] = Color3.fromRGB(120, 230, 200),
		["Crystal Caverns"] = Color3.fromRGB(190, 120, 255), ["Volcano Core"] = Color3.fromRGB(240, 70, 40),
		["Sky Kingdom"] = Color3.fromRGB(255, 230, 140),
	}
	for _, st in ipairs(Config.Map.StageStarts) do
		addBorder(st[1], STAGE_COLORS[st[1]] or Color3.new(1, 1, 1), st[2], 0)
	end
else
	for _, area in ipairs(workspace.map1b.StoneSkipMap:GetChildren()) do
		local key, rest
		for k in pairs(THEMES) do
			if area.Name:sub(1, #k) == k then
				key, rest = k, area.Name:sub(#k + 2)
			end
		end
		if key then
			local t = THEMES[key]
			local sub = rest and rest:match("^%d+_(.+)$")
			local areaName = sub and titleCase(sub) or t[3]
			local cf, size = area:GetBoundingBox()
			local half = math.abs(cf.RightVector:Dot(dir)) * size.X / 2 + math.abs(cf.UpVector:Dot(dir)) * size.Y / 2 + math.abs(cf.LookVector:Dot(dir)) * size.Z / 2
			local entry = cf.Position - dir * half -- the side the ball comes in from
			addBorder(areaName, t[2], entry.X, -145)
		end
	end
end
-- no wall at the start: drop the one nearest the launch (Alex, Oct 30)
local first
for _, b in ipairs(borders:GetChildren()) do
	if not first or b.Position:Dot(dir) < first.Position:Dot(dir) then
		first = b
	end
end
if first then
	first:Destroy()
end
borders.Parent = workspace
print("[BuildLobbyExtras] " .. #folder:GetChildren() .. " egg stands, " .. #borders:GetChildren() .. " area borders")
