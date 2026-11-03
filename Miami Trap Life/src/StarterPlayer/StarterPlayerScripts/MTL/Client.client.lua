--!strict
-- Boots every client controller in order. Each starts on its own (pcall), so one failure can't stop the rest,
-- and errors go to Output on "[MTL Client]" lines (no red box on screen).
-- New controllers: add them here in dependency order.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"ClientData",
	"UIState",
	"CarController", -- tyre smoke on every live car (needs nothing)
	"AudioMixer", -- HUD: Music / Effects / Interface / City volume groups (Settings sliders)
	"MovementController", -- sprint, speed easing, camera feel, lean, jump cooldown (the only WalkSpeed writer)
	"Stamina", -- quality: sprinting costs breath (bar above the hotbar; MovementController.sprintGate)
	"StrideController", -- walk/run blend + stride sync (planted feet don't slide); Animate keeps everything else
	"HUDController",
	"WayfindingController",
	"PhoneController",
	"JobController", -- Piece 2 (helpers JobFX + JobMinigames are required by it, not booted here)
	"SplitAim", -- quality: while aiming, hips + legs turn toward the way you move, chest stays on target (before GunController)
	"Crouch", -- quality: C / D-pad down / touch CROUCH, procedural crouch + crouch-walk on every character (before GunController)
	"GunController", -- Piece 5 (helpers GunFX + GunPose are required by it)
	"ActionPose", -- quality: carry poses (box hug, tray, bag at the side) + looping job tool actions (mop, wipe...)
	"SwingDoors", -- quality: tagged MTL_SwingDoor leaves swing open as you walk up (the Food Mart stockroom door)
	"MenuController", -- HUD: the icon menu + Store / Emotes (needs PhoneController)
	"KeyHints", -- HUD: context keybind hints above the minimap
	"HotbarController", -- HUD: bottom slots (needs GunController)
	"MapMarkers", -- HUD: emoji markers over places
	"MinimapController", -- HUD: round radar (bottom-left) + GPS route along the roads + full-screen map (N)
	"PromptController", -- HUD: every ProximityPrompt in the game's own style
	"InteractFX", -- feel: prompt pop sound + burst + camera nod, short holds become taps (helper Juice is required)
	"DeathController", -- feel: dropped state (grade, push-in, MTL_Dropped card + respawn countdown)
	"CutsceneController", -- Piece 3 (helper Actors is required by it)
	"MissionController", -- Piece 3 (needs CutsceneController)
	"CrimeController", -- crime loop: heat stars, dirty cash, crime prompts + minigames, wash, Marcus, BOOKED (needs UIState, JobMinigames, PromptController)
	"PropertyController", -- Piece 4: the flat (needs CutsceneController, PhoneController, WayfindingController)
	"QualityController", -- adaptive graphics tier (player attribute MTL_QualityTier; read by Lighting, MoodFX)
	"LightingController", -- time of day + street lights (needs CutsceneController for the story holds)
	"TutorialController", -- the new-player coach card (needs HUD, Phone, Menu, Cutscene)
	"LiveController", -- quality: 2x job pay + supply drop chips, the pawn card (Net LiveState)
	"AmbientLife", -- the living neighbourhood: people, traffic, birds, world sound, night windows (helpers Ambient*; needs Lighting, Cutscene)
}

-- Wait for the saved screens (StarterGui/MTL_*) to be copied into PlayerGui first, otherwise a controller that
-- starts before the first spawn builds its own copy and the player ends up with two of every screen.
do
	local StarterGui = game:GetService("StarterGui")
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, g in StarterGui:GetChildren() do
		if g:IsA("ScreenGui") and string.sub(g.Name, 1, 4) == "MTL_" then
			pg:WaitForChild(g.Name, 10)
		end
	end
end

local MTL = {}
for _, name in order do
	local module = Controllers:WaitForChild(name, 10)
	if not module then
		warn("[MTL Client] missing controller", name)
		continue
	end
	local ok, ctrl = pcall(require, module)
	if not ok then
		warn("[MTL Client] require failed:", name, ctrl)
		continue
	end
	MTL[name] = ctrl
	if type(ctrl) == "table" and ctrl.init then
		local initOk, err = pcall(ctrl.init)
		if not initOk then
			warn("[MTL Client] init failed:", name, err)
		end
	end
end

-- Tell the server we're listening (it re-sends waypoints). Again after every respawn.
Net.get("ClientReady"):FireServer()
Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	Net.get("ClientReady"):FireServer()
end)

print("[MTL Client] ready")
