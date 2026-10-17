-- Smoke test: Gameplay/PowerEffects, Juice and AuraStars take every message they handle (4 powers, ShieldPop, TrapSprung,
-- Caught, Rescued, Win, AuraCollected) and Gameplay/Burst cleans up after itself.
-- From tools/preview: lune run harness.luau ../../src - @smoke_feel_fx.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 1; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
local master = Instance.new("SoundGroup"); master.Name = "Master"; master.Parent = game:GetService("SoundService")
local fxg = Instance.new("SoundGroup"); fxg.Name = "Effects"; fxg.Parent = master -- (Lune can't set SoundGroup = nil)
local function character(p)
	local c = Instance.new("Model")
	local r = Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.CFrame = CFrame.new(0, 3, 0)
	r.Parent = c
	c.Parent = workspace
	return c, r
end
local myChar = character(me)
me.Character = myChar
local Gameplay = game:GetService("StarterPlayer").StarterPlayerScripts.HuzzClient.Gameplay
local errors = {}
-- (this harness can't read BasePart.Position, so the test copies read .CFrame.Position instead; nothing else changes)
local G = getfenv(1)
pcall(function() __roblox.implementMethod("Workspace", "Raycast", function() return nil end) end)
local function loadFixed(mod)
	local src = mod.Source:gsub("(%w+)%.Position", function(n) if n ~= "root" and n ~= "b" and n ~= "sign" and n ~= "r" and n ~= "me" then return nil end return n .. ".CFrame.Position" end)
	local env = setmetatable({ script = mod, require = require, Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame,
		Color3 = Color3, Enum = Enum, UDim2 = UDim2, Font = Font, typeof = typeof, task = task, warn = warn, game = game, workspace = workspace,
		NumberRange = NumberRange, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence,
		RaycastParams = { new = function() return {} end }, TweenInfo = TweenInfo }, { __index = G })
	return __luau.load(src, { debugName = mod.Name, environment = env })()
end
for _, name in { "PowerEffects", "Juice", "AuraStars" } do
	local okS, err = pcall(function() loadFixed(Gameplay[name]).start() end)
	check(name .. " starts: " .. tostring(err), okS)
end
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Round = Net.get("Round")
local id = me.UserId
local function fire(kind, data)
	local okF, err = pcall(function() Round:FireAllClients(kind, data) end)
	check(kind .. " " .. tostring(data.name or "") .. ": " .. tostring(err), okF)
end
fire("Power", { name = "HeartShield", id = id })
fire("Power", { name = "RizzRush", id = id })
fire("Power", { name = "LoveTrap", id = id, at = Vector3.new(0, 0, 0) })
fire("Power", { name = "CharmWave", id = id, radius = 16 })
fire("Power", { name = "ShieldPop", id = id, by = 5, at = Vector3.new(0, 3, 0) })
fire("Power", { name = "TrapSprung", id = id, by = 5, at = Vector3.new(0, 0, 0) })
fire("Caught", { runner = id, catcher = 5 })
fire("Rescued", { runner = id, by = 5 })
fire("Win", { winner = id, rarity = "Legendary", girl = "Mikasa" })
fire("AuraCollected", { value = 5, kind = "Pink", at = Vector3.new(0, 3, -4), id = id })
fire("AuraCollected", { value = 1, kind = "Blue", at = Vector3.new(0, 3, -4), id = 777 })
-- run the effects to the end (the delays are real time in Lune: wait them out, stepping Heartbeat)
local task = task
local bursts = workspace:FindFirstChild("HuzzBursts")
check("effects made", bursts ~= nil and #bursts:GetChildren() > 0)
local peak = bursts and #bursts:GetChildren() or 0
for _ = 1, 90 do
	__fireOn(RunService, "Heartbeat", 1 / 30)
	task.wait(1 / 60)
end
for _ = 1, 30 do __fireOn(RunService, "Heartbeat", 1 / 30) end
local left = 0
for _, d in (bursts and bursts:GetChildren() or {}) do
	if d.Name ~= "HuzzSparks" then left += 1 end
end
check(string.format("everything cleaned up (peak %d, left %d)", peak, left), left == 0)
print(string.format("client smoke: %d ok, %d failed", ok, fails))
