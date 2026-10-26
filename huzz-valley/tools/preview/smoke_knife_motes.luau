-- Smoke test: Gameplay/KnifeFxRange makes a marked knife's ball motes on this screen (Shared/KnifeFx's Motes
-- attributes and "HuzzKnifeMotes" tag), moves and fades them every frame, keeps them harmless (no shadow, no
-- collide, no query, no touch), glints the gem on a fixed timer (never twice within 1.5 s), and takes them away while
-- the knife's player is Invisible.
-- From tools/preview: lune run harness.luau ../../src - @smoke_knife_motes.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera or Instance.new("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
camera.CFrame = CFrame.new(0, 3, 8)
-- a body wearing a marked knife
local body = Instance.new("Model")
body.Name = "Wearer"
local knife = Instance.new("Model")
knife.Name = "HuzzBackKnife"
local area = Instance.new("Part")
area.Name = "KnifeFxArea"
area.Size = Vector3.new(0.12, 2.2, 0.45)
area.CFrame = CFrame.new(0, 3, 0)
area.Transparency = 1
area.Parent = knife
knife:SetAttribute("Motes", 3)
knife:SetAttribute("MoteColor", Color3.fromRGB(58, 192, 255))
knife:SetAttribute("MoteSize", 0.16)
knife:SetAttribute("MoteDrift", 0.06)
knife:SetAttribute("MoteSeed", 2.5)
knife:SetAttribute("GlintEvery", 2)
local glint = Instance.new("ParticleEmitter")
glint.Name = "KnifeFx_glint"
glint.Rate = 0
glint.Parent = area

knife:AddTag("HuzzKnifeMotes")
knife.Parent = body
body.Parent = workspace

local Gameplay = game:GetService("StarterPlayer").StarterPlayerScripts.HuzzClient.Gameplay
local Range = require(Gameplay.KnifeFxRange)
local okS, err = pcall(Range.start)
check("KnifeFxRange starts: " .. tostring(err), okS)
local function frames(seconds)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		__fireOn(RunService, "RenderStepped", 1 / 30)
		task.wait(1 / 30)
	end
end
frames(1.2)
local folder = workspace:FindFirstChild("HuzzKnifeMotes")
local balls = folder and folder:GetChildren() or {}
check(string.format("three ball motes made (%d)", #balls), #balls == 3)
local harmless, showing, near = true, 0, true
for _, b in balls do
	harmless = harmless and b:IsA("Part") and b.Shape == Enum.PartType.Ball and b.Material == Enum.Material.Neon and not b.CastShadow
		and not b.CanCollide and not b.CanQuery and not b.CanTouch and b.Anchored
	if b.Transparency < 0.6 then showing += 1 end
	near = near and (b.CFrame.Position - area.CFrame.Position).Magnitude < 2
end
check("the balls are Neon balls with no shadow, collide, query or touch", harmless)
check(string.format("at least two showing at once (%d)", showing), showing >= 2)
check("the balls float by the blade", near)
-- moving: a ball's place changes between frames
local before = balls[1] and balls[1].CFrame.Position
frames(0.3)
check("the balls move", balls[1] ~= nil and (balls[1].CFrame.Position - before).Magnitude > 1e-3)
-- the glint: on its timer, never twice within 1.5 s
frames(5.5)
local glints = {}
for _, e in __emitted do if e[1] == "KnifeFx_glint" then table.insert(glints, e[3]) end end
local closest = 99
for i = 2, #glints do closest = math.min(closest, glints[i] - glints[i - 1]) end
check(string.format("the gem glints on its timer (%d in about 7 s, closest %.2f s apart)", #glints, closest), #glints >= 2 and #glints <= 4 and closest >= 1.5)
-- Invisible: gone
local okT, now = pcall(function() return workspace:GetServerTimeNow() end)
body:SetAttribute("InvisibleUntil", (if okT then now else os.clock()) + 30)
frames(1.0)
check(string.format("no balls while Invisible (%d)", #folder:GetChildren()), #folder:GetChildren() == 0)
body:SetAttribute("InvisibleUntil", nil)
frames(1.0)
check("back after Invisible", #folder:GetChildren() == 3)
-- far away: gone
area.CFrame = CFrame.new(0, 3, -200)
frames(1.0)
check("no balls past 70 studs", #folder:GetChildren() == 0)
print(string.format("knife motes smoke: %d ok, %d failed", ok, fails))
