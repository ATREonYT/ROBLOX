-- The minimal world saved with the place file: a grass baseplate and a spawn point (the real map comes later).
local base = Instance.new("Part")
base.Name = "Baseplate"
base.Anchored = true
base.Size = Vector3.new(512, 20, 512)
base.CFrame = CFrame.new(0, -10, 0)
base.Color = Color3.fromRGB(91, 154, 76)
base.Material = Enum.Material.Grass
base.TopSurface = Enum.SurfaceType.Smooth
base.Parent = workspace
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = CFrame.new(0, 0.5, 0)
spawn.Transparency = 1
spawn.CanCollide = true
spawn.Parent = workspace
-- Roblox's newer replication (owner, Oct 21: the desync at the best possible performance; scripts can't set it)
pcall(function() workspace.NextGenerationReplication = Enum.RolloutState.Enabled end)
return nil
