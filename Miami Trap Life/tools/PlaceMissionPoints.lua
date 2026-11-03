-- [MTL Missions] Run ONCE in Studio's Command Bar (Edit mode) after tools/Install.lua.
-- Creates Workspace.MTL_Stations.FirstMission.<Point>: one small glowing part per robbery spot, at the default
-- (placeholder) spots from Config/Missions.FirstMission.Points:
--   Car      the getaway car (start of the mission + where you escape to). The part's front (-Z) = the car's front.
--   Door     just inside the Food Mart front door ("Walk into Liberty Food Mart")
--   Clerk    where Kev the night clerk stands, behind the counter. The part's front = the way he faces.
--   Register the till you grab the cash from
-- Drag/rotate each part to where it belongs in the map; MissionService uses these over the config. Attribute
-- Radius = how close the player must be. The parts are invisible in game (JobService hides MTL_Stations).
-- Meet spots: tag a part MTL_MeetSpot with attribute Id = "CanalBridge" | "Motel" | "Garage" (Config/Locations)
-- and point its front at where the player should stand; StoryCrew uses it over the placeholder.
-- Re-running never moves or deletes a part you already placed; it only adds missing ones.
local Missions = require(game.ReplicatedStorage.MTL.Config.Missions)
local Locations = require(game.ReplicatedStorage.MTL.Config.Locations)

local root = workspace:FindFirstChild("MTL_Stations")
if not root then
	root = Instance.new("Folder")
	root.Name = "MTL_Stations"
	root.Parent = workspace
end
local folder = root:FindFirstChild("FirstMission")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "FirstMission"
	folder.Parent = root
end

local params = RaycastParams.new()
params.FilterDescendantsInstances = { root }
params.FilterType = Enum.RaycastFilterType.Exclude

local made = 0
for name, cfg in Missions.FirstMission.Points do
	if not folder:FindFirstChild(name) then
		local pos = Locations.FoodMart.Inside + (cfg.offset or Vector3.zero)
		local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
		local y = if hit then hit.Position.Y + 2.5 else pos.Y
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(1.5, 5, 1.5)
		p.Material = Enum.Material.Neon
		p.Color = if name == "Car" then Color3.fromRGB(255, 160, 40) else Color3.fromRGB(255, 96, 96)
		p.Transparency = 0.4
		p.CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.rad(cfg.yaw or 0), 0)
		p:SetAttribute("Radius", cfg.radius or 8)
		p.Parent = folder
		made += 1
	end
end
print("[MTL Missions] robbery points placed:", made, "(drag them into place, then save)")
