-- [MTL Jobs] Run ONCE in Studio's Command Bar (Edit mode) after tools/Install.lua.
-- Creates Workspace.MTL_Stations.<JobId>.<StationId>: one small glowing part per job station, at the default
-- (placeholder) spots from Config/Jobs. Then drag each part to where it belongs in the map (the shelf, the
-- dumpster out back, the car bay...). JobService uses these parts' positions over the config defaults.
-- Attributes: Radius (how close the player must be), Prop (the placeholder model the client draws there:
-- CLEAR it once a real object stands at that spot, e.g. a real shelf). JobService hides these parts in game.
-- Re-running never moves or deletes a part you already placed; it only adds missing ones.
local CollectionService = game:GetService("CollectionService")
local Jobs = require(game.ReplicatedStorage.MTL.Config.Jobs)
local Locations = require(game.ReplicatedStorage.MTL.Config.Locations)

local function normal(s)
	return (string.lower(s):gsub("[^%w]", ""))
end

-- same rule as JobService: a map JobSpot for the job wins over the placeholder site
local function siteCenter(def)
	if def.mapJob then
		for _, spot in CollectionService:GetTagged("JobSpot") do
			local name = spot:GetAttribute("Job")
			if type(name) == "string" then
				for _, n in def.mapJob do
					if normal(n) == normal(name) then
						local p = if spot:IsA("BasePart") then spot.Position else spot:GetPivot().Position
						return Vector3.new(p.X, p.Y + 1, p.Z)
					end
				end
			end
		end
	end
	local loc = Locations[def.site]
	return loc.Inside or loc.Door
end

local root = workspace:FindFirstChild("MTL_Stations")
if not root then
	root = Instance.new("Folder")
	root.Name = "MTL_Stations"
	root.Parent = workspace
end

local params = RaycastParams.new()
params.FilterDescendantsInstances = { root }
params.FilterType = Enum.RaycastFilterType.Exclude

local made = 0
for _, jobId in Jobs.Order do
	local def = Jobs.Defs[jobId]
	local folder = root:FindFirstChild(jobId)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = jobId
		folder.Parent = root
	end
	local center = siteCenter(def)
	for stationId, cfg in def.stations do
		if not folder:FindFirstChild(stationId) then
			local pos = cfg.pos or (center + (cfg.offset or Vector3.zero))
			local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
			local y = if hit then hit.Position.Y + 2.5 else pos.Y
			local p = Instance.new("Part")
			p.Name = stationId
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Size = Vector3.new(1.5, 5, 1.5)
			p.Material = Enum.Material.Neon
			p.Color = if stationId == "TimeClock" then Color3.fromRGB(64, 220, 160) else Color3.fromRGB(255, 205, 80)
			p.Transparency = 0.4
			p.Position = Vector3.new(pos.X, y, pos.Z)
			p:SetAttribute("Radius", cfg.radius or 6)
			p:SetAttribute("Prop", cfg.prop or "")
			p.Parent = folder
			made += 1
		end
	end
end
print("[MTL Jobs] stations placed:", made, "(drag them into place, then save)")
