-- Smoke test: dances work in the live game with nothing published (owner, Oct 20 15:13: "inside the actual roblox
-- game, not studio, make it so that dances are available, right now they arent"). The harness runs as the live game
-- (RunService:IsStudio() is false, Config/Dances and Config/AnimationIds empty), so before the fix every dance said
-- it wasn't published. Checks: an owned dance is ready and starts; the server shares its moves
-- (ReplicatedStorage.HuzzDanceMoves) and puts HuzzDance on your character; Gameplay/DanceSync poses your own R6
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

-- an R6 body (the game is R6 since Oct 22, and so are the owner's dances): the 6 parts DanceSync drives, each held
-- by a Motor6D in the Torso (the RootJoint in the root)
local char = Instance.new("Model"); char.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.CFrame = CFrame.new(0, 3, 0); root.Position = Vector3.new(0, 3, 0); root.Parent = char
local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R6; hum.HipHeight = 0; hum.Parent = char
Instance.new("Animator").Parent = hum
local order = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local JOINT = { Torso = "RootJoint", Head = "Neck", ["Right Arm"] = "Right Shoulder", ["Left Arm"] = "Left Shoulder",
	["Right Leg"] = "Right Hip", ["Left Leg"] = "Left Hip" }
local motors = {}
for _, name in order do
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(1, 1, 1); p.Parent = char
end
for _, name in order do
	local m = Instance.new("Motor6D")
	m.Name = JOINT[name]
	m.Part0 = char:FindFirstChild(if name == "Torso" then "HumanoidRootPart" else "Torso") :: BasePart
	m.Part1 = char:FindFirstChild(name) :: BasePart
	m.Transform = CFrame.identity
	m.Parent = m.Part0
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
local ready, why = DancePlayer.ready("OrangeSwing")
check("an owned dance is ready live, unpublished (" .. tostring(why) .. ")", ready == true)
local started, msg = DancePlayer.play("OrangeSwing")
check("it starts (" .. tostring(msg) .. ")", started == true and DancePlayer.current() == "OrangeSwing")
check("drawn by hand (no track to play)", DancePlayer.handBeat() ~= nil)
task.wait(0.3)
local moves = RS:FindFirstChild("HuzzDanceMoves")
check("the server shared its moves (HuzzDanceMoves.Dance_OrangeSwing)", moves ~= nil and moves:FindFirstChild("Dance_OrangeSwing") ~= nil)
check("only that dance was shared", moves ~= nil and #moves:GetChildren() == 1)
check("your character says which dance (HuzzDance)", char:GetAttribute("HuzzDance") == "OrangeSwing")

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
check(string.format("your own joints dance (%d of 6 posed)", moved), moved >= 4)
local pos = DancePlayer.position()
check("your girl gets the dance's time (" .. tostring(pos) .. ")", type(pos) == "number" and pos >= 0)

DancePlayer.stop()
task.wait(0.3)
frames(20)
local still = 0
for _, m in motors do
	if m.Transform == CFrame.identity then still += 1 end
end
check(string.format("stopping lets the joints go (%d of 6 back)", still), still == 6 and char:GetAttribute("HuzzDance") == nil)

local locked = nil
for _, d in require(RS.Shared.Config.Dances).List do
	if not DancePlayer.owned(d.Id) then locked = d.Id break end
end
check("a dance you don't own can't start (" .. tostring(locked) .. ")", locked ~= nil and DancePlayer.play(locked) == false)

-- Roblox's newer joints (his avatar, Oct 20; owner, Oct 21 15:24: "make the dances work on the actual user, not only
-- on the girl"): AnimationConstraints between attachments, no Motor6D. These were skipped, so only the girl danced.
local char2 = Instance.new("Model"); char2.Name = "Tester"
local root2 = Instance.new("Part"); root2.Name = "HumanoidRootPart"; root2.Size = Vector3.new(2, 2, 1); root2.CFrame = CFrame.new(0, 3, 0); root2.Position = Vector3.new(0, 3, 0); root2.Parent = char2
local hum2 = Instance.new("Humanoid"); hum2.RigType = Enum.HumanoidRigType.R6; hum2.HipHeight = 0; hum2.Parent = char2
Instance.new("Animator").Parent = hum2
local joints = {}
for _, name in order do
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(1, 1, 1); p.Parent = char2
end
for _, name in order do
	local p = char2:FindFirstChild(name)
	local a0 = Instance.new("Attachment"); a0.Name = name .. "RigAttachment"; a0.Parent = char2:FindFirstChild(if name == "Torso" then "HumanoidRootPart" else "Torso")
	local a1 = Instance.new("Attachment"); a1.Name = name .. "RigAttachment"; a1.Parent = p
	local j = Instance.new("AnimationConstraint")
	j.Name = JOINT[name]
	j.Attachment0, j.Attachment1 = a0, a1
	j.Transform = CFrame.identity
	j.Parent = p
	joints[name] = j
end
char.Parent = nil
char2.Parent = workspace
me.Character = char2
__fireOn(me, "CharacterAdded", char2)
task.wait(0.2)
local again = DancePlayer.play("OrangeSwing")
task.wait(0.3)
frames(20)
local moved2 = 0
for _, j in joints do
	if j.Transform ~= CFrame.identity then moved2 += 1 end
end
check(string.format("on Roblox's newer joints too (%d of 6 posed)", moved2), again == true and moved2 >= 4)
DancePlayer.stop()
task.wait(0.3)
frames(20)
local still2 = 0
for _, j in joints do
	if j.Transform == CFrame.identity then still2 += 1 end
end
check(string.format("and let go after (%d of 6 back)", still2), still2 == 6)
-- The Dances window's cards (owner, Oct 22 19:09: "make all of the character placeholders your character not the ai
-- made one"): live, with no published IDs, the cards in view ask for their moves and show your avatar in the pose;
-- the drawn stand-in steps aside. A closed window asks for nothing.
local MM = require(UI.ModalManager)
local movesBefore = RS:FindFirstChild("HuzzDanceMoves") and #RS.HuzzDanceMoves:GetChildren() or 0
check("the closed Dances window asked for no moves", movesBefore <= 1)
MM.open("Dances")
task.wait(3)
local win = me.PlayerGui.HuzzUI:FindFirstChild("Dances")
local posed, standIns = 0, 0
for _, x in win:GetDescendants() do
	if x.Name == "Dancer" and x:IsA("ViewportFrame") and x:FindFirstChildOfClass("Model") then posed += 1 end
	if x.Name == "Figure" and x:IsA("ImageLabel") and x.Visible then standIns += 1 end
end
check(string.format("open: your avatar on the dance cards (%d posed, %d drawn stand-ins left)", posed, standIns), posed >= 4)
-- and they dance (owner, Oct 23 03:37: "make the characters in the ui showcasing the dances, dance, everywhere"): the
-- cards in view move from frame to frame; once the window closes they stop (nothing steps out of view)
local function cardArms(): { CFrame }
	local list = {}
	for _, x in win:GetDescendants() do
		if x.Name == "Dancer" and x:IsA("ViewportFrame") then
			local m = x:FindFirstChildOfClass("Model")
			local arm = m and m:FindFirstChild("Right Arm")
			if arm then table.insert(list, arm.CFrame) end
		end
	end
	return list
end
local function beats(n)
	for _ = 1, n do
		__fireOn(RunService, "Heartbeat", 1 / 30)
		task.wait(0.04)
	end
end
local function changed(a, b): number
	local n = 0
	for i, cf in a do
		if b[i] and (cf.Position - b[i].Position).Magnitude > 1e-3 then n += 1 end
	end
	return n
end
beats(10)
local a0 = cardArms()
beats(12)
local a1 = cardArms()
local moving = changed(a0, a1)
check(string.format("the cards in view dance (%d of %d moved)", moving, #a0), moving >= 4)
MM.close()
win.Visible = false -- (the close tween ends by hiding it: the harness's tweens don't run on their own)
beats(10)
local c0 = cardArms()
beats(12)
local still3 = changed(c0, cardArms())
check(string.format("closed: they stop (%d still moving)", still3), still3 == 0)
-- a dance picture is never blank (owner, Oct 26 10:47: "some of them have blank spaces"): your avatar stands there
-- while the moves are on the way, and stays if they can't come yet (asked again later)
local DancePose = require(UI.DancePose)
local holder = Instance.new("Frame"); holder.Parent = me.PlayerGui:FindFirstChild("HuzzUI") or me.PlayerGui
local vp = DancePose.picture(holder, "NotADance", { Size = UDim2.fromOffset(100, 100) }, false)
check("a dance picture shows your avatar standing at once", vp ~= nil and vp:FindFirstChild("Standing") ~= nil)
task.wait(1.5)
check("... and keeps it when the moves can't come yet", vp ~= nil and vp.Parent ~= nil and vp:FindFirstChild("Standing") ~= nil)
-- the trail and aura cards show your own avatar in the trail or aura (owner, Oct 26 10:47: "remove the placeholders and
-- make it actual user characters")
local MM = require(UI.ModalManager)
MM.open("Inventory", "Trail")
task.wait(0.6)
local inv = me.PlayerGui:FindFirstChild("Inventory", true)
local avatars, drawn = 0, 0
for _, d in (inv and inv:GetDescendants() or {}) do
	if d.Name == "Look" then
		drawn += 1
		local a = d:FindFirstChild("Avatar")
		if a and a:FindFirstChild("Standing") then avatars += 1 end
	end
end
check(`every trail card in the Inventory has your avatar ({avatars} of {drawn})`, drawn > 0 and avatars == drawn)
MM.close()
MM.open("Shop")
task.wait(0.6)
local shop = me.PlayerGui:FindFirstChild("Shop", true)
avatars, drawn = 0, 0
for _, d in (shop and shop:GetDescendants() or {}) do
	if d.Name == "Look" then
		drawn += 1
		local a = d:FindFirstChild("Avatar")
		if a and a:FindFirstChild("Standing") then avatars += 1 end
	end
end
check(`every trail and aura card in the Shop has your avatar ({avatars} of {drawn})`, drawn > 0 and avatars == drawn)
MM.close()
print(string.format("live dance smoke: %d ok, %d failed", ok, fails))
