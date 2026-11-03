--!strict
-- Small screen filters that sit on top of the day-night look (LightingController owns the main grade, bloom,
-- sun rays and atmosphere; this only adds mood and never touches those):
--   * a warm/cool split grade (warm by day, cool blue-violet at night) on its own ColorCorrection
--   * soft depth of field that blurs the far city so the street reads closer and bigger
--   * a vignette: four soft dark edges behind the HUD
--   * floating dust motes around the camera that catch the sun and the street lamps
-- It follows LightingController.clock(), and steps aside while a cutscene runs (cutscenes bring their own DOF).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Cutscene = require(script.Parent.CutsceneController)
local Quality = require(game:GetService("ReplicatedStorage").MTL.Config.Quality)

local MoodFX = {}

local UPDATE_EVERY = 0.15

local Day = {
	Tint = Color3.fromRGB(255, 251, 244),
	Contrast = 0.02,
	Saturation = 0.015,
	FarBlur = 0,
	Vignette = 0.9, -- transparency at the very edge (1 = none)
	Dust = 6,
	Lift = 0, -- extra brightness
}
local Night = {
	Tint = Color3.fromRGB(248, 248, 255),
	Contrast = 0,
	Saturation = -0.01,
	FarBlur = 0,
	Vignette = 0.86,
	Dust = 3,
	Lift = 0.03, -- buildings stay readable at night
}

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 by day, 1 at night, smooth through dusk and dawn
local function nightness(clock: number): number
	local dusk = smooth(17.6, 19.8, clock)
	local dawn = 1 - smooth(5.4, 7.2, clock)
	return math.max(dusk, dawn)
end

local function vignette(parent: Instance): { Frame }
	local gui = Instance.new("ScreenGui")
	gui.Name = "MTL_Vignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10 -- under every HUD
	gui.Parent = parent
	local edges = {}
	local specs = {
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.22), rot = 90 }, -- top
		{ pos = UDim2.fromScale(0, 0.78), size = UDim2.fromScale(1, 0.22), rot = -90 }, -- bottom
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.16, 1), rot = 0 }, -- left
		{ pos = UDim2.fromScale(0.84, 0), size = UDim2.fromScale(0.16, 1), rot = 180 }, -- right
	}
	for _, s in specs do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
		f.Position = s.pos
		f.Size = s.size
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = s.rot
		g.Parent = f
		table.insert(edges, f)
	end
	return edges
end

local function setVignette(edges: { Frame }, edge: number)
	for _, f in edges do
		local g = f:FindFirstChildOfClass("UIGradient") :: UIGradient
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, edge),
			NumberSequenceKeypoint.new(0.55, math.min(1, edge + 0.3)),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function dust(): (BasePart, ParticleEmitter)
	local box = Instance.new("Part")
	box.Name = "MTL_DustBox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(70, 26, 70)
	box.Parent = workspace.CurrentCamera
	local e = Instance.new("ParticleEmitter")
	e.Name = "Motes"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 244, 222))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(0.1, 0.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.15, -0.05, 0.1)
	e.Drag = 0.4
	e.RotSpeed = NumberRange.new(-20, 20)
	e.LightEmission = 0.4
	e.LightInfluence = 1 -- only shows where light hits it (sun shafts, lamp pools)
	e.Rate = Day.Dust
	e.Parent = box
	return box, e
end

function MoodFX.init(lighting: { clock: () -> number })
	local player = Players.LocalPlayer

	local grade = Lighting:FindFirstChild("MTL_MoodGrade") :: ColorCorrectionEffect?
	if not grade then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "MTL_MoodGrade"
		g.Parent = Lighting
		grade = g
	end
	local dof = Lighting:FindFirstChild("MTL_MoodDOF") :: DepthOfFieldEffect?
	if not dof then
		local d = Instance.new("DepthOfFieldEffect")
		d.Name = "MTL_MoodDOF"
		d.Parent = Lighting
		dof = d
	end
	local g = grade :: ColorCorrectionEffect
	local d = dof :: DepthOfFieldEffect
	d.FocusDistance = 0
	d.InFocusRadius = 260 -- nearby blocks stay sharp; only the far skyline goes soft
	d.NearIntensity = 0

	-- cars: shinier paint, and head/tail lights at night
	require(script.Parent.CarGlow).init(function()
		return nightness(lighting.clock())
	end)

	local edges = vignette(player:WaitForChild("PlayerGui"))
	local box, motes = dust()

	local timer = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		box.CFrame = CFrame.new(cam.CFrame.Position)
		timer += dt
		if timer < UPDATE_EVERY then
			return
		end
		timer = 0
		local n = nightness(lighting.clock())
		-- with the Miami look on, MTL_Grade is the only colour grade: this one keeps just the night lift
		local neutral = workspace:GetAttribute("MTL_LightingDirector") == true
		g.TintColor = if neutral then Color3.new(1, 1, 1) else Day.Tint:Lerp(Night.Tint, n)
		g.Contrast = if neutral then 0 else Day.Contrast + (Night.Contrast - Day.Contrast) * n
		g.Saturation = if neutral then 0 else Day.Saturation + (Night.Saturation - Day.Saturation) * n
		g.Brightness = Day.Lift + (Night.Lift - Day.Lift) * n
		local cut = Cutscene.isPlaying()
		d.Enabled = not cut
		d.FarIntensity = Day.FarBlur + (Night.FarBlur - Day.FarBlur) * n
		setVignette(edges, Day.Vignette + (Night.Vignette - Day.Vignette) * n)
		-- dust scales with the graphics tier (QualityController: High full, Med half, Low off)
		local q = Quality.Tiers[player:GetAttribute("MTL_QualityTier") or "High"] or Quality.Tiers.High
		motes.Rate = if cut then 0 else (Day.Dust + (Night.Dust - Day.Dust) * n) * q.Dust
	end)
end

return MoodFX
