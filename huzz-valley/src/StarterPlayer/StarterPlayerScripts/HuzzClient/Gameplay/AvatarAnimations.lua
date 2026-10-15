-- Swaps the default walk/run/idle/jump/fall animations for the IDs in
-- Config/Animations. Roblox's Animate script reloads when these change, and
-- the tracks replicate, so everyone sees your Huss Valley walk.
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Animations"))

	local SLOTS = {
		{ "walk", "WalkAnim", Animations.Walk },
		{ "run", "RunAnim", Animations.Run },
		{ "idle", "Animation1", Animations.Idle },
		{ "idle", "Animation2", Animations.Idle },
		{ "jump", "JumpAnim", Animations.Jump },
		{ "fall", "FallAnim", Animations.Fall },
	}

	local function apply(character)
		local animate = character:WaitForChild("Animate", 10)
		if not animate then
			return
		end
		for _, slot in SLOTS do
			if slot[3] ~= "" then
				local group = animate:WaitForChild(slot[1], 5)
				local animation = group and group:FindFirstChild(slot[2])
				if animation then
					animation.AnimationId = slot[3]
				end
			end
		end
	end

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(apply)
	if player.Character then
		task.spawn(apply, player.Character)
	end
end

return M
