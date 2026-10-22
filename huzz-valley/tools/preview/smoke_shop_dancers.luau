-- Smoke test: the Shop's dance cards show your own avatar dancing (owner, Oct 21: "make it your character dancing the
-- dance"), through UI/DancePose.live, as the live game (nothing published: the server shares a dance's moves when a
-- card asks, ActionService "SeeDance"). Checks: opening the Shop at DANCES puts a dancer (a ViewportFrame with a copy
-- of you) on the cards in view and hides their white stand-in; the copy really moves from frame to frame; only the
-- dances in view were shared; cards far down the page make nothing; closing the Shop stops them; the saved UI never
-- holds a dancer.
-- From tools/preview: lune run harness.luau ../../src - @smoke_shop_dancers.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

_G.__isStudio = false -- (the live game)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 79; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
check("the saved UI holds no dancer", (function()
	for _, d in game:GetService("StarterGui"):GetDescendants() do if d.Name == "Dancer" then return false end end
	return true
end)())
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)

-- an R6 body (the game and the owner's dances are R6 since Oct 22): each part held by a Motor6D in the Torso (the
-- RootJoint in the root)
local char = Instance.new("Model"); char.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.CFrame = CFrame.new(0, 3, 0); root.Position = Vector3.new(0, 3, 0); root.Parent = char
local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R6; hum.HipHeight = 0; hum.Parent = char
local order = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local JOINT = { Torso = "RootJoint", Head = "Neck", ["Right Arm"] = "Right Shoulder", ["Left Arm"] = "Left Shoulder",
	["Right Leg"] = "Right Hip", ["Left Leg"] = "Left Hip" }
for _, name in order do
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(1, 1, 1); p.Parent = char
end
for _, name in order do
	local m = Instance.new("Motor6D")
	m.Name = JOINT[name]
	m.Part0 = char:FindFirstChild(if name == "Torso" then "HumanoidRootPart" else "Torso") :: BasePart
	m.Part1 = char:FindFirstChild(name) :: BasePart
	m.C0 = CFrame.new(0, 0.5, 0)
	m.Parent = m.Part0
end
-- hair hung the way Roblox hangs an accessory (matching attachments, no joint the copy can follow) and glasses on a
-- RigidConstraint (owner, Oct 22: the hair and glasses stayed put while the head danced away)
local head = char:FindFirstChild("Head") :: BasePart
local hairOn = Instance.new("Attachment"); hairOn.Name = "HairAttachment"; hairOn.Position = Vector3.new(0, 0.6, 0); hairOn.Parent = head
local hair = Instance.new("Accessory"); hair.Name = "Hair"; hair.Parent = char
local hairPart = Instance.new("Part"); hairPart.Name = "Handle"; hairPart.Size = Vector3.new(1, 0.5, 1); hairPart.Parent = hair
local hairAt = Instance.new("Attachment"); hairAt.Name = "HairAttachment"; hairAt.Parent = hairPart
local okRigid = pcall(function()
	local glasses = Instance.new("Accessory"); glasses.Name = "Glasses"; glasses.Parent = char
	local gp = Instance.new("Part"); gp.Name = "Handle"; gp.Size = Vector3.new(1, 0.2, 0.2); gp.Parent = glasses
	local a0 = Instance.new("Attachment"); a0.Name = "FaceFrontAttachment"; a0.CFrame = CFrame.new(0, 0, -0.5); a0.Parent = head
	local a1 = Instance.new("Attachment"); a1.Name = "GlassesGrip"; a1.Parent = gp
	local rc = Instance.new("RigidConstraint"); rc.Attachment0, rc.Attachment1 = a0, a1; rc.Parent = gp
end)
char.Parent = workspace
me.Character = char
__fireOn(me, "CharacterAdded", char)

__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.5)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local function beat(n)
	for _ = 1, n do
		__fireOn(RunService, "Heartbeat", 1 / 30)
		task.wait(1 / 30)
	end
end

MM.open("Shop", "Dances")
task.wait(0.3)
beat(120)
local products = me.PlayerGui.HuzzUI.Shop.Group.Panel.Products
local view = products.CanvasPosition.Y
local inView, dancing, far, farDancers = 0, {}, 0, 0
for _, c in products:GetChildren() do
	if string.sub(c.Name, 1, 5) == "Dance" and c.Name ~= "DancePack" and c:IsA("Frame") and c:FindFirstChild("Buy") then
		local y = c.Position.Y.Offset
		local seen = y + c.Size.Y.Offset > view and y < view + 455
		local dancer = c:FindFirstChild("Dancer")
		if seen then
			inView += 1
			if dancer and dancer:FindFirstChildOfClass("Model") then table.insert(dancing, c) elseif _G.__debug then print("not dancing", c.Name, dancer) end
		elseif y > view + 900 then
			far += 1
			if dancer then farDancers += 1 end
		end
	end
end
check(string.format("the dance cards in view dance (%d of %d)", #dancing, inView), inView > 0 and #dancing == inView)
check("their white stand-in steps aside", #dancing > 0 and dancing[1]:FindFirstChild("Picture") and dancing[1].Picture.Visible == false)
check(string.format("cards far down make nothing (%d far)", far), farDancers == 0)
local moves = RS:FindFirstChild("HuzzDanceMoves")
local shared = moves and #moves:GetChildren() or 0
check(string.format("only the dances in view were shared (%d)", shared), shared > 0 and shared <= inView + 5)

-- it moves
local function handOf(c)
	local m = c.Dancer:FindFirstChildOfClass("Model")
	local h = m and m:FindFirstChild("Right Arm")
	return h and h.CFrame
end
local a = #dancing > 0 and handOf(dancing[1])
beat(12)
local b = #dancing > 0 and handOf(dancing[1])
check("your copy really dances (the hand moves)", a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude > 0.01)

-- the hair goes with the head: the same place on it in every frame
local function hairGap(c)
	local m = c.Dancer:FindFirstChildOfClass("Model")
	local h, hr = m and m:FindFirstChild("Head"), m and m:FindFirstChild("Hair")
	local hp = hr and hr:FindFirstChild("Handle")
	return h and hp and h.CFrame:ToObjectSpace(hp.CFrame)
end
local g1 = #dancing > 0 and hairGap(dancing[1])
beat(9)
local g2 = #dancing > 0 and hairGap(dancing[1])
check("the hair stays on the dancing head", g1 ~= nil and g2 ~= nil and (g1.Position - g2.Position).Magnitude < 1e-3 and g1.Position.Magnitude < 3)
if okRigid then
	local m = #dancing > 0 and dancing[1].Dancer:FindFirstChildOfClass("Model")
	local gl = m and m:FindFirstChild("Glasses") and m.Glasses:FindFirstChild("Handle")
	check("the glasses (RigidConstraint) sit on the face", gl ~= nil and (m.Head.CFrame:ToObjectSpace(gl.CFrame).Position - Vector3.new(0, 0, -0.5)).Magnitude < 1e-3)
end

-- closing stops it
MM.close()
task.wait(0.1)
beat(3)
local c1 = #dancing > 0 and handOf(dancing[1])
beat(12)
local c2 = #dancing > 0 and handOf(dancing[1])
check("closing the Shop stops them", c1 ~= nil and c2 ~= nil and (c1.Position - c2.Position).Magnitude < 1e-4)

print(string.format("shop dancers: %d ok, %d failed", ok, fails))
return nil
