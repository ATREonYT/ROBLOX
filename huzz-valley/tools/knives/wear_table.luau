-- lune run tools/knives/wear_table.luau   (from huzz-valley/)
-- Measures every knife the game can wear (his 30 models in assets/knives/HuzzKnives.rbxm, and the stand-ins cut from
-- his Game Pass and Halloween .glb files: Shared/KnifeShapes) and prints where each goes by the measured rule
-- (Shared/KnifeLook.wearOf: long or two-handed = Back, else Side) next to what Config/CoinShop's Wear table says.
-- The table is the owner's to change; this is how its first values were picked (Oct 19 evening).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Env = require("../preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
local folder = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
folder.Parent = ServerStorage
local shared = { KnifeLook = KnifeLook, FxTexture = { get = function() return "" end }, KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua") }
local env = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes" } } end },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	warn = function() end,
	Instance = Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
}
local KnifeService = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = env })()

local rows = {}
for _, item in CoinShop.Items do
	if item.Slot == "Knife" then
		local m = KnifeService.template(item)
		local s = KnifeService.shapeOf(m)
		table.insert(rows, { item = item, s = s, measured = KnifeLook.wearOf(nil, s) })
	end
end
table.sort(rows, function(a, b) return a.s.length < b.s.length end)
local differ = 0
for _, r in rows do
	local s = r.s
	print(string.format("%-18s %-22s %5.2f studs  grip %+5.2f..%+5.2f  z %+5.2f..%+5.2f  blade %4.2f x %4.2f  %s%s  table %s", r.item.Key, r.item.Name,
		s.length, s.yMin, s.yMax, s.zMin, s.zMax, s.bladeLength, s.bladeWidth, r.measured, if KnifeLook.twoHanded(s) then " (two-handed)" else "",
		tostring(r.item.Wear)))
	if r.item.Wear ~= r.measured then differ += 1 end
end
print(string.format("%d knives, %d where the table differs from the measured rule", #rows, differ))
