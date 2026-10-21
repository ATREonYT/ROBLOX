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

-- an R15 body
local char = Instance.new("Model"); char.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.CFrame = CFrame.new(0, 3, 0); root.Position = Vector3.new(0, 3, 0); root.Parent = char
local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R15; hum.HipHeight = 2; hum.Parent = char
local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}
local order = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
for _, name in order do
	local p = Instance.new("Part"); p.Name = name; p.Size = Vector3.new(1, 1, 1); p.Parent = char
	local m = Instance.new("Motor6D")
	m.Name = if name == "LowerTorso" then "Root" else name
	m.Part0 = char:FindFirstChild(PARENT[name]) :: BasePart
	m.Part1 = p
	m.C0 = CFrame.new(0, 0.5, 0)
	m.Parent = p
end
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
	local h = m and m:FindFirstChild("RightHand")
	return h and h.CFrame
end
local a = #dancing > 0 and handOf(dancing[1])
beat(12)
local b = #dancing > 0 and handOf(dancing[1])
check("your copy really dances (the hand moves)", a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude > 0.01)

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
