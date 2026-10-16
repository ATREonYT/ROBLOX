--[[
	Your avatar's walk, run, idle, jump, fall and climb become the owner's animations (the movement pack in
	ReplicatedStorage.HuzzAnimations, or their published IDs: Shared/AnimationLibrary). Roblox's Animate script
	plays them (and the tracks replicate, so everyone sees them): it blends Walk into Run as you speed up, which
	Gameplay/Sprint makes a smooth build-up while you hold a direction (owner: "slowly fade from walking into
	running"). With nothing to play (live game, not published yet) Roblox's defaults stay and Gameplay/RunAnimator
	draws the scripted Huss Valley run instead.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Library = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationLibrary"))
	if game:GetService("RunService"):IsStudio() then
		ReplicatedStorage:WaitForChild("HuzzAnimations", 5) -- (Bootstrap copies the raw ones over in Studio)
	end

	local SLOTS = {
		{ "walk", "WalkAnim", "Walk" },
		{ "run", "RunAnim", "Run" },
		{ "idle", "Animation1", "Idle" },
		{ "idle", "Animation2", "Idle" },
		{ "jump", "JumpAnim", "Jump" },
		{ "fall", "FallAnim", "Fall" },
		{ "climb", "ClimbAnim", "Climb" },
	}

	local function apply(character)
		local animate = character:WaitForChild("Animate", 10)
		if not animate then
			return
		end
		for _, slot in SLOTS do
			local id = Library.id(slot[3])
			if id ~= "" then
				local group = animate:WaitForChild(slot[1], 5)
				local animation = group and group:FindFirstChild(slot[2])
				if animation then
					animation.AnimationId = id
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
