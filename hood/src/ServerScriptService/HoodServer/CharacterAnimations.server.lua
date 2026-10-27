-- Every player moves with the owner's R15 pack (Config/Animations, Shared/AnimationRules): when a character spawns, its
-- Animate script's moves are pointed at the pack's (only the moves with an uploaded id; the rest stay Roblox's).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local AnimationRules = require(RS.Shared.AnimationRules)

local function onCharacter(character: Model)
	local ok, err = pcall(function()
		local animate = character:WaitForChild('Animate', 10)
		if animate then AnimationRules.apply(animate) end
	end)
	if not ok then warn('[CharacterAnimations] ' .. tostring(err)) end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do onPlayer(player) end
