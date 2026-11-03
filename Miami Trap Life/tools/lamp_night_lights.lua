-- Gives every StreetLight / ParkLamp in Workspace its own saved night light (Edit-mode command bar, run once).
-- The light sits on the first Neon head, named and tagged "MTL_NightLight", Enabled=false; the client
-- LightingController switches it on near the camera after dusk (see Config/MiamiLook.NightLights).
local CS = game:GetService("CollectionService")
for i, m in workspace:GetDescendants() do
	if not (m:IsA("Model") and (m.Name == "StreetLight" or m.Name == "ParkLamp")) then continue end
	local head
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and (p.Material == Enum.Material.Neon or p:GetAttribute("MTL_LampHead")) then head = p break end
	end
	if not head or head:FindFirstChild("MTL_NightLight") then continue end
	local l
	if m.Name == "ParkLamp" then
		l = Instance.new("PointLight"); l.Range = 24; l.Brightness = 2; l.Color = Color3.fromRGB(255, 206, 150)
	else
		l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Range = 55; l.Angle = 110; l.Brightness = 5
		l.Color = Color3.fromRGB(255, 190, 120)
	end
	l.Name = "MTL_NightLight"; l.Shadows = false; l.Enabled = false
	CS:AddTag(l, "MTL_NightLight")
	l.Parent = head
	if i % 500 == 0 then task.wait() end
end
