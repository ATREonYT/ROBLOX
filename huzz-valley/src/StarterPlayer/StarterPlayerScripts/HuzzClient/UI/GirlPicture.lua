-- An anime girl's picture: her still model (ReplicatedStorage.HuzzGirls, from GirlService.publish) in a
-- ViewportFrame. Used by the Index, the Tiers page and the Combine window. grade (optional): her Combine grade
-- (Silver, Gold, Diamond: her own look, with her grade's aura drawn behind her: a glow in its colour, a soft ring and
-- a few sparkles, stronger Silver > Gold > Diamond; owner, Oct 26 15:42: "just have a different aura"). ViewportFrames don't draw inside a CanvasGroup, so the
-- windows that use this are Flat (Kit.window).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GirlGrade = require(Shared:WaitForChild("GirlGrade"))
local Combine = require(Shared:WaitForChild("Config"):WaitForChild("Combine"))
local Kit = require(script.Parent.Kit)
local Effects = require(script.Parent.Effects)

local GirlPicture = {}

local folder: Instance? = nil
function GirlPicture.folder(): Instance?
	folder = folder or ReplicatedStorage:FindFirstChild("HuzzGirls")
	return folder
end

-- Her grade's aura behind her picture (a ViewportFrame draws no particles): the glow picture in the grade's colour,
-- a soft ring and sparkles; more of each per grade. Made at run time, never saved.
local AURA = { Silver = { glow = 0.25, ring = 0.55, dots = 4 }, Gold = { glow = 0.1, ring = 0.4, dots = 6 }, Diamond = { glow = 0, ring = 0.25, dots = 8 } }
local DOTS = { { 0.18, 0.3 }, { 0.82, 0.26 }, { 0.12, 0.62 }, { 0.88, 0.58 }, { 0.3, 0.12 }, { 0.7, 0.1 }, { 0.22, 0.86 }, { 0.78, 0.84 } }
local function aura(parent: Instance, grade: string)
	local a, look = AURA[grade], Combine.Grades[grade]
	if not (a and look and look.Sheen) then return end
	local colour = look.Sheen.Color
	local box = Instance.new("Frame")
	box.Name = "GradeAura"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = 0
	box:SetAttribute("RuntimeOnly", true)
	local glow = Kit.art("DanceFxGlow", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.1, 1.1), ScaleType = Enum.ScaleType.Fit, ImageColor3 = colour, ImageTransparency = a.glow, ZIndex = 0, Parent = box })
	pcall(Effects.breathe, glow, { scale = 1.06, seconds = 2.2 })
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint, ring.Position, ring.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.82, 0.82)
	ring.BackgroundTransparency, ring.ZIndex = 1, 0
	ring.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local rim = Instance.new("UIStroke")
	rim.Color, rim.Thickness, rim.Transparency = colour, 2, a.ring
	rim.Parent = ring
	for i = 1, a.dots do
		local d = DOTS[i]
		local dot = Instance.new("Frame")
		dot.Name = "Sparkle" .. i
		dot.AnchorPoint, dot.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(d[1], d[2])
		dot.Size = UDim2.fromOffset(if i % 2 == 0 then 4 else 6, if i % 2 == 0 then 4 else 6)
		dot.BackgroundColor3, dot.BorderSizePixel, dot.ZIndex = colour:Lerp(Color3.new(1, 1, 1), 0.5), 0, 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = dot
		dot.Parent = box
		pcall(Effects.breathe, dot, { scale = 1.5, seconds = 1.4 + (i % 3) * 0.4 })
	end
	box.Parent = parent
end

-- key: her model's name in HuzzGirls. whole = head to toe (a big preview), else head and shoulders (a card).
-- Girls you don't own are drawn unlit, as a dark silhouette. Returns nil when her model isn't there.
function GirlPicture.draw(parent: Instance, key: string?, isOwned: boolean, whole: boolean, grade: string?): ViewportFrame?
	local f = GirlPicture.folder()
	local source = f and key and f:FindFirstChild(key)
	if not (source and source:IsA("Model")) then return nil end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Model"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp:SetAttribute("RuntimeOnly", true)
	if isOwned then
		vp.Ambient, vp.LightColor, vp.LightDirection = Color3.fromRGB(170, 170, 185), Color3.new(1, 1, 1), Vector3.new(-0.4, -1, -0.6)
	else
		vp.Ambient, vp.LightColor, vp.ImageColor3 = Color3.new(0, 0, 0), Color3.new(0, 0, 0), Color3.fromHex("0B1426")
	end
	local model = source:Clone()
	local old = parent:FindFirstChild("GradeAura") -- (a picture drawn again: the last one's aura goes with it)
	if old then old:Destroy() end
	if isOwned and grade then
		pcall(GirlGrade.apply, model, grade)
		pcall(aura, parent, grade)
	end
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local head = model:FindFirstChild("Head", true)
	local look = if head and head:IsA("BasePart") then head.CFrame.LookVector else model:GetPivot().LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	if whole or not (head and head:IsA("BasePart")) then
		local okBox, cf, size = pcall(model.GetBoundingBox, model)
		if not okBox then cf, size = model:GetPivot(), Vector3.new(2, 5, 1) end
		local dist = (size.Y / 2) / math.tan(math.rad(15)) * 1.12
		cam.CFrame = CFrame.lookAt(cf.Position + look * dist + Vector3.new(0, size.Y * 0.04, 0), cf.Position)
	else
		local at = head.CFrame.Position - Vector3.new(0, 0.55, 0)
		cam.CFrame = CFrame.lookAt(at + look * 6.4 + Vector3.new(0, 0.6, 0), at)
	end
	vp.Parent = parent
	return vp
end

return GirlPicture
