-- Starts the round gameplay on this client: the carry animation, the round HUD and custom walk animations.
-- Runs beside Main (the UI); each part reports errors in the same red box on screen.
local Gameplay = script.Parent:WaitForChild("Gameplay")
local Report = require(script.Parent:WaitForChild("UI"):WaitForChild("Report"))

for _, name in { "AvatarAnimations", "Dash", "RunAnimator", "CarryAnimator", "Knockdown", "RoundHud", "Actions", "PowerEffects", "Cinematic", "ShiftLock", "Auras", "Feel", "Sprint" } do
	task.spawn(Report.run, name, function()
		require(Gameplay:WaitForChild(name)).start()
	end)
end
