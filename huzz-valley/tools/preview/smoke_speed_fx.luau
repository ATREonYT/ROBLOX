-- Smoke test: Gameplay/SpeedFX (owner, Oct 22 13:24: "add some effects when you are running and make it feel more
-- intense"): an R6 runner near flat out gets the thin white streaks on the arms, legs and feet and a blue glow round
-- the screen; walking, dancing or hidden gets neither; the glow eases (never pops) and the Reduced Motion setting
-- keeps it off.
-- From tools/preview: lune run harness.luau ../../src - @smoke_speed_fx.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 1; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
local c = Instance.new("Model"); c.Name = "Tester"
local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = CFrame.new(0, 3, 0); root.Parent = c
for _, n in { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
	local p = Instance.new("Part"); p.Name = n; p.Parent = c
end
local h = Instance.new("Humanoid"); h.WalkSpeed = 24; h.Health = 100; h.Parent = c
c.Parent = workspace
me.Character = c

local Gameplay = game:GetService("StarterPlayer").StarterPlayerScripts.HuzzClient.Gameplay
local mod = Gameplay.SpeedFX
local step
local box = { v = Vector3.zero, md = Vector3.zero }
-- (this harness can't move bodies: the test feeds the speed in through the root's velocity, read as `v` below)
local src = mod.Source:gsub("root%.AssemblyLinearVelocity", "__vel.v"):gsub("h%.MoveDirection", "__vel.md") -- (and the keys held)
local G = getfenv(1)
local env = setmetatable({ script = mod, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
	UDim2 = UDim2, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence,
	game = game, workspace = workspace, typeof = typeof, task = task, __vel = box,
	require = function(x)
		if x.Name == "Frame" then return { on = function(_, fn) step = fn end } end
		return require(x)
	end }, { __index = G })
local okS, err = pcall(function() __luau.load(src, { debugName = "SpeedFX", environment = env })().start() end)
check("starts: " .. tostring(err), okS and step ~= nil)
local function run(seconds)
	for _ = 1, math.floor(seconds * 60) do step(1 / 60) end
end
local function trails()
	local list = {}
	for _, d in c:GetDescendants() do if d:IsA("Trail") and d.Name == "HuzzSpeedTrail" then table.insert(list, d) end end
	return list
end
local function lit()
	local n = 0
	for _, t in trails() do if t.Enabled then n += 1 end end
	return n
end
local gui = me.PlayerGui:FindFirstChild("HuzzSpeedGlow")
check("the glow is on the screen", gui ~= nil)
local function edge() return gui and gui:FindFirstChild("Left") and (1 - gui.Left.BackgroundTransparency) or 0 end

box.md = Vector3.new(0, 0, -1) -- (W held)
box.v = Vector3.new(0, 0, -10) -- walking
run(1)
check("walking: no streaks", lit() == 0)
check("walking: no glow", edge() == 0 and not gui.Enabled)
box.v = Vector3.new(0, 0, -18) -- (owner, Oct 23: "appear only when he is running") the build-up, not yet the full run
run(1)
check("building up into the run: no streaks yet", lit() == 0)
box.v = Vector3.new(0, 0, -24) -- flat out
run(1 / 15)
local early = edge()
run(1.5)
check("flat out: eight streaks (feet, knees, hands, elbows)", #trails() == 8 and lit() == 8)
local hasArm = false
for _, t in trails() do if t.Parent and t.Parent.Name == "Right Arm" then hasArm = true end end
check("they come off the R6 limbs", hasArm)
local t1 = trails()[1]
check("thin, short and white", t1 and t1.Lifetime <= 0.3 and (t1.Attachment1.Position - t1.Attachment0.Position).Magnitude <= 0.2)
check("flat out: the blue glow round the edge", edge() > 0.4 and gui.Enabled)
check("eases in (no pop)", early > 0 and early < edge() * 0.5)
check("left, right and top; none at the bottom", gui:FindFirstChild("Top") ~= nil and gui:FindFirstChild("Bottom") == nil)
c:SetAttribute("HuzzDance", "OrangeSwing")
run(0.1)
check("dancing: streaks off", lit() == 0)
c:SetAttribute("HuzzDance", nil)
run(0.1)
check("back on after", lit() == 8)
box.md = Vector3.zero -- let go: a halt still slides at speed
run(0.1)
check("no key held (a halt's slide): streaks off", lit() == 0)
box.md = Vector3.new(0, 0, -1)
run(0.1)
box.v = Vector3.new(0, 0, -10)
run(2)
check("slowing down: streaks off", lit() == 0)
check("slowing down: the glow eases out", edge() < 0.05)

print(string.format("SpeedFX smoke: %d ok, %d failed", ok, fails))
if fails > 0 then error("SpeedFX smoke failed") end
