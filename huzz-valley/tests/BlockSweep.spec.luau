-- lune run tests/BlockSweep.spec.luau   (from huzz-valley/)
-- HuzzServer/BlockSweep (owner, Oct 21: "don't try to hide it, remove it"): on the server, a loose grip-sized block
-- inside a player's character (where his Studio close-up shows it) is destroyed with one [HuzzBlock] line; his body,
-- his worn knife at the hip and a small accessory on him stay; the same rules as each screen (Shared/LooseParts, (c)
-- in tests/FollowGuard.spec).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local LP = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/LooseParts.lua"), { debugName = "LooseParts" })()
local Shared = { LooseParts = LP }
local fakeRS = { Shared = Shared }
local S = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/BlockSweep.lua"), { debugName = "BlockSweep",
	environment = { game = { GetService = function(_, n) return if n == "ReplicatedStorage" then fakeRS else {} end }, require = function(x) return x end } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local m = Instance.new("Model")
m.Name = "alex"
local function part(name, parent, at, size)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, CFrame.new(at)
	p.Parent = parent
	return p
end
part("HumanoidRootPart", m, Vector3.new(0, 3, 0), Vector3.new(2, 2, 1)).Transparency = 1
local lower = part("LowerTorso", m, Vector3.new(0, 2, 0), Vector3.new(2, 0.4, 1))
part("UpperTorso", m, Vector3.new(0, 3, 0), Vector3.new(2, 1.6, 1))
part("LeftLowerLeg", m, Vector3.new(-0.5, 0.5, 0), Vector3.new(1, 0.9, 1))
part("RightLowerLeg", m, Vector3.new(0.5, 0.5, 0), Vector3.new(1, 0.9, 1))
local knife = Instance.new("Model"); knife.Name = "HuzzBackKnife"; knife.Parent = m
local grip = part("Handle", knife, Vector3.new(1.2, 2, 0.8), Vector3.new(0.22, 0.75, 0.26))
local block = part("Handle", m, Vector3.new(-2.8, 0.5, -1.4), Vector3.new(0.22, 0.75, 0.26))
local acc = Instance.new("Accessory"); acc.Parent = m
local bag = part("Handle", acc, Vector3.new(-1, 2, -0.7), Vector3.new(0.7, 0.8, 0.4))

local lines = {}
local n = S.sweep({ { name = "alex", character = m } }, function(s) table.insert(lines, s) end, { n = 0 })
check("the loose block is removed", n == 1 and block.Parent == nil)
check("one [HuzzBlock] line naming it", #lines == 1 and string.find(lines[1], "[HuzzBlock] removed (server)", 1, true) ~= nil and string.find(lines[1], "alex", 1, true) ~= nil)
check("his body, worn knife and bag stay", lower.Parent == m and grip.Parent == knife and bag.Parent == acc)
check("a second pass removes nothing", S.sweep({ { name = "alex", character = m } }, function() end, { n = 0 }) == 0)

print(string.format("BlockSweep: %d passed, %d failed", passed, failed))
if failed > 0 then error("BlockSweep spec failed") end
