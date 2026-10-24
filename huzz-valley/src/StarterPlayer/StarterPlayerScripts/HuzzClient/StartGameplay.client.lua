-- Starts the round gameplay on this client: the carry animation, the round HUD and custom walk animations.
-- Runs beside Main (the UI); each part reports errors in the same red box on screen.
local Gameplay = script.Parent:WaitForChild("Gameplay")
local Report = require(script.Parent:WaitForChild("UI"):WaitForChild("Report"))

for _, name in { "OthersAhead", "MotionSend", "AvatarAnimations", "PlayerMoves", "Dash", "RunAnimator", "CarryAnimator", "DanceSync", "Knockdown", "RoundHud", "Actions", "PowerEffects", "Heartbeat", "Cinematic", "ShiftLock", "Auras", "Feel", "SpeedFX", "R6Huss", "Sprint", "AuraStars", "Juice", "CrownPose", "SecretReveal", "Music", "Leaderboards", "AvatarStands", "LobbyProps", "KnifeDress", "KnifeMeshCheck", "KnifeFxRange", "KnifeGuard", "FollowGuard", "PlaceSelf", "AfkRejoin", "FavouritePrompt", "HeadAim", "CombineMachine" } do
	task.spawn(Report.run, name, function()
		require(Gameplay:WaitForChild(name)).start()
	end)
end
