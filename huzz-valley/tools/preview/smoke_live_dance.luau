-- Smoke test: dances work in the live game with nothing published (owner, Oct 20 15:13: "inside the actual roblox
-- game, not studio, make it so that dances are available, right now they arent"). The harness runs as the live game
-- (RunService:IsStudio() is false, Config/Dances and Config/AnimationIds empty), so before the fix every dance said
-- it wasn't published. Checks: an owned dance is ready and starts; the server shares its moves
-- (ReplicatedStorage.HuzzDanceMoves) and puts HuzzDance on your character; Gameplay/DanceSync poses your own R15
-- joints from them; stopping lets the joints go; a dance you don't own still can't start.
-- From tools/preview: lune run harness.luau ../../src - @smoke_live_dance.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

_G.__isStudio = false -- (the live game: setup_ui makes the harness Studio)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)

-- an R15 body: the 15 parts DanceSync drives, each held by a Motor6D
local char = Instance.new("Model"); char.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.CFrame = CFrame.new(0, 3, 0); root.Position = Vector3.new(0, 3, 0); root.Parent = char
local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R15; hum.HipHeight = 2; hum.Parent = char
Instance.new("Animator").Parent = hum
local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}
local order = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
local motors = {}
for _, name in order do
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(1, 1, 1); p.Parent = char
	local m = Instance.new("Motor6D")
	m.Name = if name == "LowerTorso" then "Root" else name
	m.Part0 = char:FindFirstChild(PARENT[name]) :: BasePart
	m.Part1 = p
	m.Transform = CFrame.identity
	m.Parent = p
	motors[name] = m
end
char.Parent = workspace
me.Character = char
__fireOn(me, "CharacterAdded", char)

__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.5)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local Gameplay = game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay
local DancePlayer = require(UI.DancePlayer)
require(Gameplay.DanceSync).start()

check("the live game: no published IDs here", not RunService:IsStudio())
local ready, why = DancePlayer.ready("Floss")
check("an owned dance is ready live, unpublished (" .. tostring(why) .. ")", ready == true)
local started, msg = DancePlayer.play("Floss")
check("it starts (" .. tostring(msg) .. ")", started == true and DancePlayer.current() == "Floss")
check("drawn by hand (no track to play)", DancePlayer.handBeat() ~= nil)
task.wait(0.3)
local moves = RS:FindFirstChild("HuzzDanceMoves")
check("the server shared its moves (HuzzDanceMoves.Dance_Floss)", moves ~= nil and moves:FindFirstChild("Dance_Floss") ~= nil)
check("only that dance was shared", moves ~= nil and #moves:GetChildren() == 1)
check("your character says which dance (HuzzDance)", char:GetAttribute("HuzzDance") == "Floss")

local function frames(n)
	for _ = 1, n do
		__fireOn(RunService, "PreSimulation", 1 / 30)
		task.wait()
	end
end
frames(20)
local moved = 0
for _, m in motors do
	if m.Transform ~= CFrame.identity then moved += 1 end
end
check(string.format("your own joints dance (%d of 15 posed)", moved), moved >= 8)
local pos = DancePlayer.position()
check("your girl gets the dance's time (" .. tostring(pos) .. ")", type(pos) == "number" and pos >= 0)

DancePlayer.stop()
task.wait(0.3)
frames(20)
local still = 0
for _, m in motors do
	if m.Transform == CFrame.identity then still += 1 end
end
check(string.format("stopping lets the joints go (%d of 15 back)", still), still == 15 and char:GetAttribute("HuzzDance") == nil)

local locked = nil
for _, d in require(RS.Shared.Config.Dances).List do
	if not DancePlayer.owned(d.Id) then locked = d.Id break end
end
check("a dance you don't own can't start (" .. tostring(locked) .. ")", locked ~= nil and DancePlayer.play(locked) == false)
print(string.format("live dance smoke: %d ok, %d failed", ok, fails))
