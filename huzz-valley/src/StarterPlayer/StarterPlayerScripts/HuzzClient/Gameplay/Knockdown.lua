--[[
	Plays a caught player's fall and keeps them lying flat (Shared/DownMotion)
	while their character has the DownedAt attribute (set by the server's
	KnockdownService). Runs after Roblox's animations each frame, so the limbs
	blend from whatever animation was playing into the sprawl.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local DownMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DownMotion"))
	local active = {} -- character -> DownMotion record

	local function jointsOf(character)
		local list = {}
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") or d.ClassName == "AnimationConstraint" then
				table.insert(list, d)
			end
		end
		return list
	end

	require(script.Parent.Frame).on(40, function()
		local now = Workspace:GetServerTimeNow()
		local seen = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local at = character and character:GetAttribute("DownedAt")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if at and root then
				seen[character] = true
				local rec = active[character]
				if not rec then
					rec = DownMotion.new(jointsOf(character))
					active[character] = rec
				end
				local feet, height = character:GetAttribute("DownedFeet"), character:GetAttribute("DownedHeight")
				if feet and height then
					root.CFrame = DownMotion.rootCFrame(feet, height, now - at)
				end
				DownMotion.step(rec, now - at)
			end
		end
		for character, rec in active do
			if not seen[character] then
				active[character] = nil
				DownMotion.release(rec)
			end
		end
	end)
end

return M
