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
local EGG_COLORS = {
	Starter = Color3.fromRGB(120, 220, 120),
	Woodland = Color3.fromRGB(150, 110, 60),
	Nature = Color3.fromRGB(80, 200, 90),
	Ocean = Color3.fromRGB(60, 160, 255),
}
local EGGS = { "Starter", "Woodland", "Nature", "Ocean" } -- the exclusive egg goes 5th
for i, id in ipairs(EGGS) do
	local egg = Config.GetEgg(id)
	local pos = Vector3.new(-34 - (#EGGS - i) * 16, floorY, -108)
	local stand = Instance.new("Model")
	stand.Name = id .. "Egg"
	stand:SetAttribute("EggId", id)
	local base = part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 9, 9), CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.SmoothPlastic, Parent = stand })
	part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 9.6, 9.6), CFrame = base.CFrame * CFrame.new(-0.05, 0, 0), Color = EGG_COLORS[id], Material = Enum.Material.Neon, CanCollide = false, Parent = stand })
	part({ Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = EGG_COLORS[id], Material = Enum.Material.SmoothPlastic, Parent = stand })

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
	eggModel:PivotTo(CFrame.new(pos + Vector3.new(0, 2.2 + eggSize.Y / 2, 0)))
	eggModel.Parent = stand

	local glow = Instance.new("PointLight")
	glow.Color = EGG_COLORS[id]
	glow.Range = 14
	glow.Brightness = 1.2
	glow.Parent = base
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(7, 2.6) -- sized in studs, so neighbouring signs never overlap from afar
	board.StudsOffsetWorldSpace = Vector3.new(0, 11.5, 0)
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

local signPos = Vector3.new(-58, floorY + 17, -100)
local sign = part({ Name = "EggSign", Size = Vector3.new(30, 6, 0.6), CFrame = CFrame.lookAt(signPos, signPos + Vector3.new(0, 0, -1)), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = workspace })
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 25
signGui.Parent = sign
label(signGui, "🥚 EGGS 🥚", Color3.new(1, 1, 1))

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
		local pos = Vector3.new(entry.X, WATER_Y + HEIGHT / 2, -145)
		local props = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
		local b = part({ Name = areaName, Size = Vector3.new(0.4, HEIGHT, WIDTH), CFrame = CFrame.new(pos), Color = t[2], Material = Enum.Material.SmoothPlastic, Transparency = 0.35 })
		for k, v in pairs(props) do
			b[k] = v
		end
		b:SetAttribute("AreaName", areaName)
		borderFace(b, Enum.NormalId.Right, areaName)
		borderFace(b, Enum.NormalId.Left, areaName)
		b.Parent = borders
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
