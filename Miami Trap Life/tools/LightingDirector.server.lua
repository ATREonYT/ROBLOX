-- MTL_LightingDirector (Script in ServerScriptService)
-- Sets up the Miami look: makes the MTL_ effects in Lighting, turns off the place's older post effects, sets the
-- static lighting settings, and flags workspace.MTL_LightingDirector = true. The keyframes live in
-- ReplicatedStorage.MTL.Config.MiamiLook. The client LightingController blends them every few frames against the
-- game clock (TimeService), so there's one writer and no flicker. Disable this script to go back to Config/DayNight.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiamiLook = require(ReplicatedStorage.MTL.Config.MiamiLook)

local function ensure(class, name)
	local inst = Lighting:FindFirstChild(name)
	if inst and inst.ClassName == class then return inst end
	if class == "Atmosphere" or class == "Sky" then
		inst = Lighting:FindFirstChildOfClass(class)
		if inst then return inst end
	end
	inst = Instance.new(class); inst.Name = name; inst.Parent = Lighting
	return inst
end

for _, d in Lighting:GetChildren() do
	if d:IsA("PostEffect") and not d.Name:match("^MTL_") then
		d.Enabled = false
		print("[MTL Lighting] disabled old effect", d:GetFullName())
	end
end

local sky = ensure("Sky", "MTL_Sky")
sky.CelestialBodiesShown = true; sky.SunAngularSize = 14; sky.MoonAngularSize = 9; sky.StarCount = 3000
local atm = ensure("Atmosphere", "MTL_Atmosphere")
local grade = ensure("ColorCorrectionEffect", "MTL_Grade")
local bloom = ensure("BloomEffect", "MTL_Bloom")
local rays = ensure("SunRaysEffect", "MTL_SunRays")
local dof = ensure("DepthOfFieldEffect", "MTL_DistanceBlur")
for k, v in MiamiLook.Blur do dof[k] = v end
for _, e in { grade, bloom, rays, dof } do e.Enabled = true end

Lighting.GlobalShadows = true; Lighting.GeographicLatitude = 25.8; Lighting.ShadowSoftness = 0.15
Lighting.EnvironmentDiffuseScale = 1; Lighting.EnvironmentSpecularScale = 1; Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)

-- the server's own copy (what a fresh client sees for its first frame); the clients drive it from here on
MiamiLook.apply(Lighting.ClockTime, { atmosphere = atm, grade = grade, bloom = bloom, rays = rays })
workspace:SetAttribute("MTL_LightingDirector", true)
print("[MTL Lighting] Miami director running")
