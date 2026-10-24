-- An anime girl's picture: her still model (ReplicatedStorage.HuzzGirls, from GirlService.publish) in a
-- ViewportFrame. Used by the Index, the Tiers page and the Combine window. grade (optional): her Combine grade
-- (Silver, Gold, Diamond: Shared/GirlGrade dresses the picture's copy; no effects in a picture). ViewportFrames don't draw inside a CanvasGroup, so the
-- windows that use this are Flat (Kit.window).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GirlGrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GirlGrade"))

local GirlPicture = {}

local folder: Instance? = nil
function GirlPicture.folder(): Instance?
	folder = folder or ReplicatedStorage:FindFirstChild("HuzzGirls")
	return folder
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
	if isOwned and grade then pcall(GirlGrade.apply, model, grade) end
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
