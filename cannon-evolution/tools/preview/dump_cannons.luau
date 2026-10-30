-- Offline: runs src/tools/BuildBlockyCannons.lua in Lune's Roblox DOM and writes every
-- cannon's parts (shape, size, CFrame, colour, neon) to JSON for render_cannons.py.
-- lune run tools/preview/dump_cannons.luau <out.json>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local game = roblox.Instance.new("DataModel")
local rs = game:GetService("ReplicatedStorage")
local cannons = roblox.Instance.new("Folder")
cannons.Name = "Cannons"
cannons.Parent = rs
game:GetService("ServerStorage")

local env = setmetatable({
	game = game, Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame,
	Color3 = roblox.Color3, Enum = roblox.Enum, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
	Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, UDim = roblox.UDim,
}, { __index = _G })
local src = fs.readFile("src/tools/BuildBlockyCannons.lua")
luau.load(src, { debugName = "BuildBlockyCannons", environment = env })()

local out = {}
for _, m in cannons:GetChildren() do
	local parts = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local shape = p.ClassName == "WedgePart" and "Wedge" or (p.ClassName == "Part" and p.Shape.Name or "Block")
			table.insert(parts, {
				shape = shape,
				size = { p.Size.X, p.Size.Y, p.Size.Z },
				cf = { cf:GetComponents() },
				color = { p.Color.R, p.Color.G, p.Color.B },
				neon = p.Material == roblox.Enum.Material.Neon,
				alpha = p.Transparency,
			})
		end
	end
	local fx = 0
	for _, e in m:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			fx += e.Rate
		end
	end
	out[m.Name] = { parts = parts, particlesPerSecond = fx }
end
fs.writeFile(process.args[1], serde.encode("json", out))
print("dumped " .. #cannons:GetChildren() .. " cannons")
