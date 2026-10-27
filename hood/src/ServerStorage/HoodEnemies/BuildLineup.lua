--!strict
--[[
	BuildLineup: a Studio tool. It puts every World 1 enemy into Workspace as a real, finished model you can see,
	move, copy into ServerStorage, or save with the place.

	Paste into the Studio COMMAND BAR (View > Command Bar), with HoodEnemies in ServerStorage:
		require(game.ServerStorage.HoodEnemies.BuildLineup)()

	It builds Workspace.World1_Enemies: one row per crew (stages 1-2 at the front, 15-16 at the back), the boss
	at the end of each row, every model anchored and standing on y = 0 near the world origin. Running it again
	replaces the folder. The game itself does not need this module.
]]

local EnemyLooks = require(script.Parent.EnemyLooks)
local Roster = require(script.Parent.EnemyRoster)

local SPACING_X = 10 -- studs between enemies in a row
local SPACING_Z = 16 -- studs between crews

return function(): Folder
	local old = workspace:FindFirstChild("World1_Enemies")
	if old then
		old:Destroy()
	end
	local out = Instance.new("Folder")
	out.Name = "World1_Enemies"
	out.Parent = workspace
	local count = 0
	for ci, crew in ipairs(Roster.Crews) do
		local row = Instance.new("Folder")
		row.Name = ("%02d-%02d %s"):format(crew.Stages[1], crew.Stages[2], crew.Name)
		row.Parent = out
		for i, c in ipairs(crew.Characters) do
			local model = EnemyLooks.build(c.key, CFrame.new(i * SPACING_X, 10, ci * SPACING_Z))
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			-- stand on y = 0: lift or drop the model so its lowest point touches the ground
			local box, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(0, size.Y / 2 - box.Position.Y, 0))
			model.Parent = row
			count += 1
		end
	end
	print(("BuildLineup: %d enemies are in Workspace.World1_Enemies"):format(count))
	return out
end
