-- Smoke test: HuzzServer/GirlService.showcase builds the prize girl on her stand (stand inside her Aura box, lights,
-- title, only the root anchored, Base kept). From tools/preview: lune run harness.luau ../../src - @smoke_showcase.luau
local roblox = __roblox
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
roblox.implementMethod("Model", "GetScale", function() return 1 end)
pcall(function() roblox.implementMethod("CollectionService", "AddTag", function() end) end)
roblox.implementMethod("Model", "ScaleTo", function(self, k)
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then d.Size = d.Size * k end
	end
end)

-- a fake girl: root, torso, head joined by Motor6Ds
local m = Instance.new("Model")
m.Name = "G1"
local function part(n, size, y)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = n, size, CFrame.new(0, y, 0)
	p.Parent = m
	return p
end
local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), 3)
root.Transparency = 1
local torso = part("Torso", Vector3.new(2, 2, 1), 3)
local head = part("Head", Vector3.new(1.2, 1.2, 1.2), 4.6)
local legs = part("Left Leg", Vector3.new(1, 2, 1), 1)
for _, p in { torso, head, legs } do
	local j = Instance.new("Motor6D")
	j.Part0, j.Part1 = root, p
	j.C0 = root.CFrame:ToObjectSpace(p.CFrame)
	j.Parent = p
end
m.PrimaryPart = root
local mod = game:GetService("ServerScriptService").HuzzServer.GirlService
local realGame = game
local fakeCS = { AddTag = function(_, inst, tag) inst:AddTag(tag) end }
local proxy = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, n) if n == "CollectionService" then return fakeCS end return realGame:GetService(n) end
	end
	return realGame[k]
end })
local env = setmetatable({ game = proxy, script = mod, require = require, Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3, Enum = Enum, UDim2 = UDim2, Font = Font, typeof = typeof, task = task, warn = warn, Random = Random }, { __index = getfenv(1) })
local GirlService = __luau.load(mod.Source, { debugName = "GirlService", environment = env })()
local girl = { id = "G1", name = "Mikasa", rarity = "Legendary", template = m }
local okS, show = pcall(GirlService.showcase, girl, Vector3.new(0, 40, 0), workspace)
check("showcase builds: " .. tostring(show), okS)
if okS then
	for _, n in { "Aura", "StandTop", "StandBand", "StandGlow", "KeyLight", "RimLight" } do
		check("has " .. n, show:FindFirstChild(n) ~= nil)
	end
	local aura = show:FindFirstChild("Aura")
	local top = show:FindFirstChild("StandTop")
	-- the stand stays inside the Aura box (so the cutscene's bounding box doesn't change)
	local rel = aura.CFrame:PointToObjectSpace(top.CFrame.Position)
	check("stand inside the aura box (y)", math.abs(rel.Y) + 0.25 <= aura.Size.Y / 2 + 1e-3)
	check("stand no wider than her (x)", top.Size.Y <= aura.Size.X)
	local hrp = show.PrimaryPart
	check("root anchored", hrp.Anchored == true)
	check("body unanchored", show:FindFirstChild("Torso").Anchored == false)
	check("stand anchored", top.Anchored == true)
	local gui = aura:FindFirstChild("Rating")
	check("title board", gui ~= nil and gui.SizeOffset.Y == 0.5)
	local name = gui and gui:FindFirstChildOfClass("TextLabel")
	check("title text is her name", name ~= nil and name.Text == "MIKASA")
	check("Base attribute kept", typeof(show:GetAttribute("Base")) == "CFrame")
end
print(string.format("smoke: %d ok, %d failed", ok, fails))
