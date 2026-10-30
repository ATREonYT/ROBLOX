-- lune run tests/Cape.spec.luau   (from huzz-valley/)
-- The Midnight Outfit's cape (HuzzServer/CosmeticsService) stays on the body (owner, Oct 20: "fix the little thing
-- near the chaaracter floating ( black block)"): the cape was welded to the torso at spawn; Roblox then swapped in
-- the avatar's own torso, the weld died with the old one and the dark cape fell away loose. Now a cape that isn't
-- held by the current torso is made again on it, and a torso arriving later puts the cape on it.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local data = { Cosmetics = { MidnightOutfit = true }, Wear = { Outfit = "MidnightOutfit" } }
local shared = {
	DataService = { get = function() return { Data = data } end, waitFor = function() return true end },
	CoinShop = CoinShop,
	FxTexture = { get = function() return "rbxasset://textures/particles/sparkles_main.dds" end, flipbook = function(e) e.Texture = "rbxasset://textures/particles/sparkles_main.dds" end },
}
local fakeRS = { Shared = { Config = { CoinShop = "CoinShop" }, FxTexture = "FxTexture" } }
local env = {
	game = { GetService = function(_, name) return if name == "ReplicatedStorage" then fakeRS else {} end },
	script = { Parent = { DataService = "DataService" } },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	task = { defer = function(f, ...) f(...) end, spawn = function(f, ...) f(...) end },
}
local Cosmetics = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/CosmeticsService.lua"), { debugName = "CosmeticsService", environment = env })()

local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name, root.Size, root.Parent = "HumanoidRootPart", Vector3.new(2, 2, 1), character
local function torso()
	local t = Instance.new("Part")
	t.Name, t.Size, t.CFrame = "UpperTorso", Vector3.new(2, 1.6, 1), CFrame.new(0, 0.6, 0)
	t.Parent = character
	return t
end
local first = torso()
local player = { Character = character }

local function capeHeld()
	local cape = character:FindFirstChild("MidnightCape")
	local w = cape and cape:FindFirstChildOfClass("WeldConstraint")
	return cape, w and w.Part0
end

Cosmetics.refresh(player)
local cape, held = capeHeld()
check("the cape is made, held by the torso", cape ~= nil and held == first)
Cosmetics.refresh(player)
check("refreshing again keeps the same cape", (capeHeld()) == cape)

-- Roblox swaps in the avatar's own torso after spawn
first:Destroy()
local second = torso()
Cosmetics.refresh(player)
local cape2, held2 = capeHeld()
local count = 0
for _, c in character:GetChildren() do
	if c.Name == "MidnightCape" then count += 1 end
end
check("the avatar's own torso arrives: the cape moves onto it", cape2 ~= nil and held2 == second)
check("one cape, the old loose one gone", count == 1 and cape2 ~= cape)
check("it hangs behind the new torso, not left where the old one was",
	cape2 ~= nil and second.CFrame:PointToObjectSpace(cape2.CFrame.Position).Z > 0.4)

print(string.format("Cape: %d ok, %d failed", passed, failed))
if failed > 0 then error("Cape spec failed") end
