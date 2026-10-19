--[[
	Applies Config/Look to Lighting when the server starts: the lighting settings, a colour grade, bloom, sun
	rays, a light haze, the Sky's settings and Terrain Clouds (Oct 19 sky: real 3D clouds, no upload) (each is found
	by class or made). Lighting and Terrain replicate, so every player sees it.
	Effects the place already has are reused, not doubled; Config/Look.Enabled = false leaves Lighting alone.
]]
local Lighting = game:GetService("Lighting")
local Look = require(game:GetService("ReplicatedStorage").Shared.Config.Look)

local LookService = {}

local function effect(class: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(class)
	if existing then return existing end
	local e = Instance.new(class)
	e.Name = name
	e.Parent = Lighting
	return e
end

local function set(inst: Instance, props: { [string]: any })
	for k, v in props do
		local ok, err = pcall(function() (inst :: any)[k] = v end)
		if not ok then warn(`[HuzzLook] couldn't set {inst.ClassName}.{k}: {err}`) end
	end
end

function LookService.apply()
	if not Look.Enabled then return end
	set(Lighting, Look.Lighting)
	set(effect("ColorCorrectionEffect", "HuzzGrade"), Look.ColorCorrection)
	set(effect("BloomEffect", "HuzzBloom"), Look.Bloom)
	set(effect("SunRaysEffect", "HuzzSunRays"), Look.SunRays)
	set(effect("Atmosphere", "HuzzAtmosphere"), Look.Atmosphere)
	if Look.Sky then set(effect("Sky", "HuzzSky"), Look.Sky) end
	if Look.Clouds then
		local terrain = workspace.Terrain
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Name = "HuzzClouds"
			clouds.Parent = terrain
		end
		set(clouds, Look.Clouds)
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof and Look.DepthOfField == false then (dof :: DepthOfFieldEffect).Enabled = false end
end

return LookService
