--[[
	Worn knives' effects only near the camera (owner, Oct 20: better knife effects; the coordinator: "keep it light on
	performance ... drop worn effects for far-away players"). Twice a second this screen switches the particles on
	each player's worn knife (HuzzServer/KnifeService "HuzzBackKnife", Shared/KnifeFx) on within RANGE studs of the
	camera and off past it. Only on this screen (Enabled is local); knives in hand and the stands are left alone.
]]
local M = {}

M.RANGE = 70 -- studs
M.EVERY = 0.5 -- seconds

function M.start()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	task.spawn(function()
		while true do
			task.wait(M.EVERY)
			local ok, err = pcall(function()
				local camera = Workspace.CurrentCamera
				if not camera then return end
				local eye = camera.CFrame.Position
				for _, player in Players:GetPlayers() do
					local knife = player.Character and player.Character:FindFirstChild("HuzzBackKnife")
					local area = knife and knife:FindFirstChild("KnifeFxArea", true)
					if area and area:IsA("BasePart") then
						local near = (area.Position - eye).Magnitude <= M.RANGE
						for _, d in knife:GetDescendants() do
							if d:IsA("ParticleEmitter") and string.find(d.Name, "^KnifeFx") and d.Enabled ~= near then
								d.Enabled = near
							end
						end
					end
				end
			end)
			if not ok then warn("[Huzz] KnifeFxRange: " .. tostring(err)) end
		end
	end)
end

return M
