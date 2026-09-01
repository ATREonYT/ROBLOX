--!strict
-- Draws the stage enemies from StageState. Everything here is client-side:
-- the server replicates positions once and health at 5 Hz, and this builds the
-- bodies, the name plates and the health bars.

local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)

local stageStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StageState") :: RemoteEvent

local EnemyRenderer = {}

local trove = Trove.new()
local container: Folder? = nil

type Visual = {
	Id: string,
	Stage: number,
	Model: Model,
	Torso: BasePart,
	RestCf: CFrame,
	Fill: Frame,
	HealthLabel: TextLabel,
	Position: Vector3,
	Phase: number, -- so no two enemies breathe in sync
	Max: number,
	Health: number,
	Shown: number, -- interpolated health, so the bar slides instead of jumping
	Dead: boolean,
}

local visuals: { [string]: Visual } = {}

local function decor(parent: Instance, cf: CFrame, size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Each stage's enemies get their own suit colour, so a Junior Broker never
-- looks like a Dock Foreman.
local function suitFor(stageNumber: number): (Color3, Color3, Color3)
	local palette = {
		{ Color3.fromRGB(228, 232, 238), Color3.fromRGB(80, 96, 128), Color3.fromRGB(220, 88, 88) },
		{ Color3.fromRGB(96, 108, 132), Color3.fromRGB(52, 58, 74), Color3.fromRGB(255, 176, 64) },
		{ Color3.fromRGB(48, 56, 78), Color3.fromRGB(32, 38, 54), Color3.fromRGB(64, 220, 160) },
		{ Color3.fromRGB(212, 128, 60), Color3.fromRGB(76, 62, 52), Color3.fromRGB(255, 232, 120) },
		{ Color3.fromRGB(96, 200, 190), Color3.fromRGB(48, 66, 78), Color3.fromRGB(150, 100, 255) },
		{ Color3.fromRGB(60, 70, 96), Color3.fromRGB(36, 42, 60), Color3.fromRGB(255, 210, 90) },
		{ Color3.fromRGB(84, 60, 44), Color3.fromRGB(44, 34, 28), Color3.fromRGB(226, 178, 66) },
		{ Color3.fromRGB(40, 48, 68), Color3.fromRGB(26, 32, 46), Color3.fromRGB(60, 232, 255) },
	}
	local entry = palette[((stageNumber - 1) % #palette) + 1]
	return entry[1], entry[2], entry[3]
end

local function buildVisual(id: string, stageNumber: number, position: Vector3, max: number, health: number): Visual?
	local parent = container
	if not parent then
		return nil
	end
	local stage = Stages.byNumber(stageNumber)
	local model = Instance.new("Model")
	model.Name = "Enemy_" .. id
	model.Parent = parent

	local shirt, trousers, tie = suitFor(stageNumber)
	local skin = Color3.fromRGB(234, 190, 152)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(-90), 0)

	local torso = decor(model, cf * CFrame.new(0, 4.6, 0), Vector3.new(3.4, 3.6, 1.8), shirt)
	torso.Name = "Torso"
	local restCf = torso.CFrame
	decor(model, cf * CFrame.new(-0.9, 1.5, 0), Vector3.new(1.4, 3.4, 1.6), trousers)
	decor(model, cf * CFrame.new(0.9, 1.5, 0), Vector3.new(1.4, 3.4, 1.6), trousers)
	decor(model, cf * CFrame.new(-2.3, 4.6, 0), Vector3.new(1.2, 3.4, 1.6), shirt)
	decor(model, cf * CFrame.new(2.3, 4.6, 0), Vector3.new(1.2, 3.4, 1.6), shirt)
	decor(model, cf * CFrame.new(0, 7.4, 0), Vector3.new(2, 2, 2), skin)
	decor(model, cf * CFrame.new(0, 4.9, -0.95), Vector3.new(0.5, 2.6, 0.2), tie)

	-- Clicks must land on the body, so the torso answers raycasts and carries
	-- the id ClickController reads.
	torso.CanQuery = true
	model:SetAttribute("EnemyId", id)
	torso:SetAttribute("EnemyId", id)
	CollectionService:AddTag(model, "EnemyModel")

	-- Name plate + health bar.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Plate"
	billboard.Size = UDim2.fromScale(11, 3.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0)
	billboard.MaxDistance = 260
	billboard.LightInfluence = 0
	billboard.Adornee = torso
	billboard.Parent = torso

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.45)
	name.Font = Enum.Font.FredokaOne
	name.Text = if stage then stage.EnemyName else "Rival"
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextScaled = true
	name.TextStrokeTransparency = 0
	name.Parent = billboard

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromScale(0.06, 0.5)
	barBack.Size = UDim2.fromScale(0.88, 0.34)
	barBack.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	barBack.BorderSizePixel = 0
	barBack.Parent = billboard
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.4, 0)
	backCorner.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(86, 214, 96)
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.4, 0)
	fillCorner.Parent = fill

	local healthLabel = Instance.new("TextLabel")
	healthLabel.BackgroundTransparency = 1
	healthLabel.Size = UDim2.fromScale(1, 1)
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.Text = ""
	healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthLabel.TextScaled = true
	healthLabel.TextStrokeTransparency = 0.4
	healthLabel.Parent = barBack

	return {
		Id = id,
		Stage = stageNumber,
		Phase = (position.X * 0.37 + position.Z * 0.11) % (math.pi * 2),
		Model = model,
		Torso = torso,
		RestCf = restCf,
		Fill = fill,
		HealthLabel = healthLabel,
		Position = position,
		Max = max,
		Health = health,
		Shown = health,
		Dead = health <= 0,
	}
end

local function setDead(visual: Visual, dead: boolean)
	if visual.Dead == dead then
		return
	end
	visual.Dead = dead
	for _, part in visual.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if dead then 1 else 0
			-- A defeated body must stop swallowing clicks aimed at live ones.
			part.CanQuery = not dead
		end
	end
	local plate = visual.Torso:FindFirstChild("Plate")
	if plate and plate:IsA("BillboardGui") then
		plate.Enabled = not dead
	end
end

local function applyFull(list: { any })
	for _, visual in visuals do
		visual.Model:Destroy()
	end
	table.clear(visuals)
	for _, row in list do
		local pos = Vector3.new(row.Pos[1], row.Pos[2], row.Pos[3])
		local visual = buildVisual(row.Id, row.Stage, pos, row.Max, row.Health)
		if visual then
			visuals[row.Id] = visual
			setDead(visual, row.RespawnAt > 0 or row.Health <= 0)
		end
	end
end

local function applyDelta(list: { any })
	for _, row in list do
		local visual = visuals[row.Id]
		if visual then
			visual.Health = row.Health
			setDead(visual, row.RespawnAt > 0 or row.Health <= 0)
			if not visual.Dead and row.Health >= visual.Max then
				visual.Shown = row.Health -- a fresh respawn shows full instantly
			end
		end
	end
end

function EnemyRenderer:Init()
	local folder = Instance.new("Folder")
	folder.Name = "EnemyVisuals"
	folder.Parent = workspace
	container = folder
	trove:Add(folder)

	trove:Connect(stageStateRemote.OnClientEvent, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.Full then
			applyFull(payload.Full)
		elseif payload.Delta then
			applyDelta(payload.Delta)
		end
	end)
end

function EnemyRenderer:Start()
	-- Health bars slide toward their true value rather than snapping, which
	-- reads as a hit landing instead of a number changing.
	trove:Add(RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, visual in visuals do
			if visual.Dead then
				continue
			end
			local distance = (visual.Position - eye).Magnitude
			if distance > 300 then
				continue -- far enough that nobody can read the bar anyway
			end

			-- Idle motion. A static NPC reads as a prop; these breathe and
			-- shift their weight. Procedural rather than an Animation track
			-- because these models have no Humanoid by design.
			if distance < 140 then
				local t = now * 1.6 + visual.Phase
				local breathe = math.sin(t) * 0.06
				local sway = math.sin(t * 0.5) * 0.04
				visual.Torso.CFrame = visual.RestCf
					* CFrame.new(0, breathe, 0)
					* CFrame.Angles(0, sway, math.sin(t * 0.33) * 0.02)
			end
			if math.abs(visual.Shown - visual.Health) > 0.01 then
				visual.Shown += (visual.Health - visual.Shown) * math.min(1, dt * 9)
				local ratio = math.clamp(visual.Shown / math.max(visual.Max, 1), 0, 1)
				visual.Fill.Size = UDim2.fromScale(ratio, 1)
				visual.Fill.BackgroundColor3 = if ratio > 0.5
					then Color3.fromRGB(86, 214, 96)
					elseif ratio > 0.2 then Color3.fromRGB(240, 176, 64)
					else Color3.fromRGB(232, 76, 76)
				visual.HealthLabel.Text = ("%s / %s"):format(
					Format.abbreviate(math.max(visual.Shown, 0)),
					Format.abbreviate(visual.Max)
				)
			end
		end
	end))
end

return EnemyRenderer
