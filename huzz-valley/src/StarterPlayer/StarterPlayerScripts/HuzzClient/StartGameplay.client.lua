-- Starts the round gameplay on this client: the carry animation, the round HUD and custom walk animations.
-- Runs beside Main (the UI); each part reports errors in the same red box on screen.
local Gameplay = script.Parent:WaitForChild("Gameplay")
local Report = require(script.Parent:WaitForChild("UI"):WaitForChild("Report"))

for _, name in { "OthersAhead", "MotionSend", "AvatarAnimations", "PlayerMoves", "Dash", "RunAnimator", "CarryAnimator", "DanceSync", "Knockdown", "RoundHud", "Actions", "PowerEffects", "Heartbeat", "Cinematic", "ShiftLock", "Auras", "Feel", "SpeedFX", "R6Huss", "Sprint", "AuraStars", "Juice", "CrownPose", "SecretReveal", "Music", "Leaderboards", "AvatarStands", "LobbyProps", "KnifeDress", "KnifeMeshCheck", "KnifeFxRange", "KnifeGuard", "FollowGuard", "PlaceSelf", "AfkRejoin", "FavouritePrompt", "HeadAim", "CombineMachine", "NoReset" } do
	task.spawn(Report.run, name, function()
		require(Gameplay:WaitForChild(name)).start()
	end)
end

-- Tell the server this screen has loaded (the world and your body): only then are you put in a game (owner, Oct 25
-- 16:01: "if someone doesnt load in and they are still in lobby, please make it so that he doesnt count into the
-- active game"; HuzzServer/RoundService loadedIn).
task.spawn(Report.run, "Ready", function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local player = game:GetService("Players").LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 60)
	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
	Net.get("ClientReady"):FireServer()
end)
