-- Invisible and Smoke Bomb hide a runner completely on other screens (owner, Oct 21: "the invisible should be
-- completely invisible"), through the real Gameplay/PowerEffects: another runner with a name tag, team outline, worn
-- trail, sparkles, a knife, the girl they carry (HuzzCarried, Carrier) and a shield bubble (HuzzShields, welded).
-- Checks: while Invisible every part and decal is gone (LocalTransparencyModifier 1) and every tag, outline, trail
-- and effect is off; the carried girl and the bubble go too; Gameplay/Hidden says so (the aura and knife motes read
-- it); Radar's spot brings them back see-through; afterwards everything is back as it was. Your own body only fades
-- to Self. The same for a runner in a smoke cloud, and a catcher in the cloud stays seen.
-- From tools/preview: lune run harness.luau ../../src - @check_hidden.luau setup_ui.luau
-- Prints "hidden: N ok, M failed".
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 1; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
local master = Instance.new("SoundGroup"); master.Name = "Master"; master.Parent = game:GetService("SoundService")
local fxg = Instance.new("SoundGroup"); fxg.Name = "Effects"; fxg.Parent = master
pcall(function() __roblox.implementMethod("Workspace", "Raycast", function() return nil end) end)

local function part(name, parent, at)
	local p = Instance.new("Part"); p.Name = name
	p.CFrame = CFrame.new(at); p.Position = at
	p.Parent = parent
	return p
end
local function body(p, at)
	local c = Instance.new("Model"); c.Name = p.Name
	local root = part("HumanoidRootPart", c, at)
	local head = part("Head", c, at + Vector3.new(0, 1.5, 0))
	local face = Instance.new("Decal"); face.Name = "face"; face.Parent = head
	local tag = Instance.new("BillboardGui"); tag.Name = "HuzzTag"; tag.Parent = head
	local outline = Instance.new("Highlight"); outline.Name = "HuzzOutline"; outline.Parent = c
	local a0 = Instance.new("Attachment"); a0.Parent = root
	local a1 = Instance.new("Attachment"); a1.Parent = root
	local trail = Instance.new("Trail"); trail.Name = "WornTrail"; trail.Attachment0, trail.Attachment1 = a0, a1; trail.Parent = root
	local sparkle = Instance.new("ParticleEmitter"); sparkle.Parent = root
	local light = Instance.new("PointLight"); light.Parent = root
	local knife = Instance.new("Model"); knife.Name = "HuzzKnife"; knife.Parent = c
	part("Blade", knife, at + Vector3.new(1, 0, 0))
	c.Parent = Workspace
	p.Character = c
	return { c = c, root = root, switch = { tag, outline, trail, sparkle, light } }
end
local mine = body(me, Vector3.new(0, 3, 40))
local other = Instance.new("Player"); other.Name = "Runner"; other.UserId = 2; other.Parent = Players
local them = body(other, Vector3.new(0, 3, 0))
other:SetAttribute("HuzzRole", "Runner")
local catcher = Instance.new("Player"); catcher.Name = "Catcher"; catcher.UserId = 3; catcher.Parent = Players
local catcherBody = body(catcher, Vector3.new(2, 3, 0))
catcher:SetAttribute("HuzzRole", "Catcher")
-- the girl they carry and their shield bubble, outside the character
local carried = Instance.new("Folder"); carried.Name = "HuzzCarried"; carried.Parent = Workspace
local girl = Instance.new("Model"); girl.Name = "Girl"; girl:SetAttribute("Carrier", 2); girl.Parent = carried
local girlPart = part("Torso", girl, Vector3.new(0, 4, 1))
local shields = Instance.new("Folder"); shields.Name = "HuzzShields"; shields.Parent = Workspace
local bubble = part("HuzzShield", shields, Vector3.new(0, 3, 0))
local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1 = them.root, bubble; weld.Parent = bubble

local Gameplay = game:GetService("StarterPlayer").StarterPlayerScripts.HuzzClient.Gameplay
local G = getfenv(1)
local function loadFixed(mod) -- (as smoke_feel_fx: this harness reads .CFrame.Position for .Position)
	local src = mod.Source:gsub("(%w+)%.Position", function(n) if n ~= "root" and n ~= "head" and n ~= "copyRoot" then return nil end return n .. ".CFrame.Position" end)
	local env = setmetatable({ script = mod, require = require, Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame,
		Color3 = Color3, Enum = Enum, UDim2 = UDim2, Font = Font, typeof = typeof, task = task, warn = warn, game = game, workspace = workspace,
		NumberRange = NumberRange, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence,
		RaycastParams = { new = function() return {} end }, TweenInfo = TweenInfo }, { __index = G })
	return __luau.load(src, { debugName = mod.Name, environment = env })()
end
local okS, err = pcall(function() loadFixed(Gameplay.PowerEffects).start() end)
check("PowerEffects starts: " .. tostring(err), okS)
local Hidden = require(Gameplay.Hidden)
local Powers = require(game:GetService("ReplicatedStorage").Shared.Config.Powers)

-- (a virtual server clock near 1000: Lune keeps attributes in single precision, too coarse for real times)
local clock = 1000
_G.__serverClock = function() return clock end
local function frames(n)
	for _ = 1, n do
		clock += 1 / 30
		__fireOn(RunService, "Heartbeat", 1 / 30)
	end
end
local function ltm(c)
	local lo, hi = math.huge, -math.huge
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local okR, v = pcall(function() return d.LocalTransparencyModifier end) -- (Lune: unset reads fail, i.e. 0)
			v = if okR then v else 0
			lo, hi = math.min(lo, v), math.max(hi, v)
		end
	end
	return lo, hi
end
local function read(p)
	local okR, v = pcall(function() return p.LocalTransparencyModifier end)
	return if okR then v else 0
end
local function allOff(list)
	for _, d in list do if d.Enabled then return false end end
	return true
end
local function allOn(list)
	for _, d in list do if not d.Enabled then return false end end
	return true
end

-- 1. Invisible: gone on this screen; you see yourself at Self
local now = Workspace:GetServerTimeNow()
them.c:SetAttribute("InvisibleFrom", now - 1); them.c:SetAttribute("InvisibleUntil", now + 30)
mine.c:SetAttribute("InvisibleFrom", now - 1); mine.c:SetAttribute("InvisibleUntil", now + 30)
frames(3)
local lo = ltm(them.c)
check("an invisible runner's body, face and knife are gone (" .. lo .. ")", lo >= 0.999)
check("their name tag, outline, trail, sparkles and light are off", allOff(them.switch))
check("the girl they carry is gone too", read(girlPart) >= 0.999)
check("their shield bubble is gone too", read(bubble) >= 0.999)
check("Gameplay/Hidden says they're gone (aura, knife motes)", Hidden.gone(them.c))
local myLo, myHi = ltm(mine.c)
check("you see yourself at Self, not gone", math.abs(myLo - Powers.Invisible.Self) < 0.01 and math.abs(myHi - Powers.Invisible.Self) < 0.01)
check("your own tag and trail stay on", allOn(mine.switch) and not Hidden.gone(mine.c))

-- 2. Radar spots them: back, see-through, tag on
them.c:SetAttribute("SpottedUntil", Workspace:GetServerTimeNow() + 30)
frames(2)
local slo, shi = ltm(them.c)
check("a spotted invisible runner shows again at Reveal", math.abs(shi - Powers.Radar.Reveal) < 0.01)
check("a spotted runner's tag is back", allOn(them.switch))
check("Radar's glow is never switched off", them.c:FindFirstChild("HuzzSpotted") ~= nil and them.c.HuzzSpotted.Enabled)
them.c:SetAttribute("SpottedUntil", nil)
frames(12)

-- 3. it ends: everything back as it was
them.c:SetAttribute("InvisibleUntil", Workspace:GetServerTimeNow() - 0.01)
mine.c:SetAttribute("InvisibleUntil", Workspace:GetServerTimeNow() - 0.01)
frames(2)
local elo, ehi = ltm(them.c)
check("after Invisible the body is back", ehi <= 0.001)
check("after Invisible the tag, outline, trail and effects are back", allOn(them.switch))
check("after Invisible the girl and bubble are back", read(girlPart) <= 0.001 and read(bubble) <= 0.001)
check("after Invisible your own body is back", select(2, ltm(mine.c)) <= 0.001)

-- 4. a runner standing in a smoke cloud is hidden the same way; a catcher in it is not
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
Net.get("Round"):FireAllClients("Power", { name = "SmokeBomb", id = 2, at = Vector3.new(0, 0, 0), radius = 8, lasts = 30 })
task.wait(Powers.Fx.SmokeBomb.WindUp + Powers.Fx.Flash + 0.1)
frames(math.ceil((Powers.Fx.SmokeBomb.WindUp + Powers.Fx.Flash) * 30) + 10)
check("a runner in smoke is gone on other screens", ltm(them.c) >= 0.999 and allOff(them.switch) and Hidden.gone(them.c))
check("a catcher in the smoke stays seen", select(2, ltm(catcherBody.c)) <= 0.001 and allOn(catcherBody.switch))
them.root.CFrame = CFrame.new(0, 3, 30); them.root.Position = Vector3.new(0, 3, 30)
frames(10)
check("stepping out of the smoke brings them back", select(2, ltm(them.c)) <= 0.001 and allOn(them.switch) and not Hidden.gone(them.c))

print(string.format("hidden: %d ok, %d failed", ok, failed))
return nil
