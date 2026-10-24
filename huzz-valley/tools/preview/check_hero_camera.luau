-- The HERO / CHICKEN camera (owner, Oct 21: "when the hero or chicken animation is there, make the camera not be
-- locked onto you moving with your characters movements, just keep it focused in one place, then zoom in and out"),
-- through the real Gameplay/Cinematic: once the shot lands on the picked runner it stays put while their head and
-- body move, and Chosen is a smooth zoom in. Run: lune run harness.luau ../../src - "$(cat check_hero_camera.luau)"
-- Prints "hero camera: N ok, M failed".
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 128
Players.LocalPlayer = player
local pg = Instance.new("PlayerGui"); pg.Parent = player
local m = Instance.new("Model"); m.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = m
local head = Instance.new("Part"); head.Name = "Head"; head.Parent = m
local function place(p, cf) p.CFrame = cf; p.Position = cf.Position end -- (Lune keeps the two apart)
place(root, CFrame.new(0, 3, 0)); place(head, CFrame.new(0, 4.5, 0))
m.Parent = workspace
player.Character = m

local clock = 1000
_G.__serverClock = function() return clock end
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
local Config = require(game.ReplicatedStorage.Shared.Config.Round)
local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
round:SetAttribute("LineCF", CFrame.new(0, 0, 0))
round:SetAttribute("LineLength", 20)
round:SetAttribute("PickId", 1)
round:SetAttribute("PickAt", clock - Config.Pick.Roulette - 0.5) -- (the roulette is over: the face shot)
round:SetAttribute("Stage", "Picking")
player:SetAttribute("HuzzRole", "Runner")
require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.Cinematic).start()
local step = _G.__bound.HuzzCinematic
check("the round camera is bound", step ~= nil)
local cam = workspace.CurrentCamera
local function run(seconds)
	local t0 = os.clock()
	repeat step(); task.wait(1 / 60) until os.clock() - t0 >= seconds
	step()
end
run(0.4) -- (the swing over to the shot)
local held = cam.CFrame
-- their pose moves the head and the body (the HERO / CHICKEN animation, the head following their mouse)
place(head, CFrame.new(0.8, 4.3, -0.5) * CFrame.Angles(0.2, 0.9, 0.1))
place(root, CFrame.new(0.6, 3, -0.4) * CFrame.Angles(0, 0.7, 0))
run(0.2)
local moved = (cam.CFrame.Position - held.Position).Magnitude
local _, turned = (held.Rotation:Inverse() * cam.CFrame.Rotation):ToAxisAngle()
check(string.format("the camera stays put while they move (moved %.3f studs, turned %.2f degrees)", moved, math.deg(turned)),
	moved < 0.01 and math.deg(math.abs(turned)) < 0.1)

-- Chosen: a smooth zoom in, aimed at the same spot
round:SetAttribute("Stage", "Chosen")
local lookAt = held.Position + held.LookVector * 11
-- (the speed per real second, as the harness's frames are not evenly spaced; 30 fps = a 30th of it a frame)
local biggest, last, lastAt = 0, cam.CFrame.Position, os.clock()
local t0 = os.clock()
repeat
	task.wait(1 / 60)
	step()
	local now = os.clock()
	biggest = math.max(biggest, (cam.CFrame.Position - last).Magnitude / math.max(now - lastAt, 1e-3) / 30)
	last, lastAt = cam.CFrame.Position, now
until os.clock() - t0 > 0.9
local inBy = (held.Position - cam.CFrame.Position).Magnitude
check(string.format("Chosen zooms in (%.1f studs closer)", inBy), inBy > 1.5)
check(string.format("smoothly (at most %.2f studs a frame at 30 fps)", biggest), biggest < 0.6)
local _, off = (held.Rotation:Inverse() * cam.CFrame.Rotation):ToAxisAngle()
check(string.format("still facing the same spot (%.1f degrees)", math.deg(math.abs(off))), math.deg(math.abs(off)) < 6)
print(string.format("hero camera: %d ok, %d failed", ok, failed))
