-- Builds huzz-valley/places/ServerAuthorityTest.rbxl: the Server Authority test place (owner, Oct 21). A flat field
-- with posts every 8 studs (so two windows can be compared by eye), the shared simulation and its two loaders, and
-- the real game's Config/Round and Config/Run, so the huss and the dive use the game's own numbers.
-- Run from the repo root: lune run huzz-valley/sa-test/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local UDim2, UDim = roblox.UDim2, roblox.UDim

local HERE = "huzz-valley/sa-test/"
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/Config/"
local OUT = "huzz-valley/places/ServerAuthorityTest.rbxl"

local game = Instance.new("DataModel")
local ws = game:GetService("Workspace")
-- Server Authority and what it needs (Studio sets the last five itself when AuthorityMode is Server)
local settings = {
	{ "AuthorityMode", Enum.AuthorityMode.Server },
	{ "NextGenerationReplication", Enum.RolloutState.Enabled },
	{ "PlayerScriptsUseInputActionSystem", Enum.RolloutState.Enabled },
	{ "SignalBehavior", Enum.SignalBehavior.Deferred },
	{ "UseFixedSimulation", Enum.RolloutState.Enabled },
	{ "StreamingEnabled", true },
}
for _, kv in settings do
	local ok, err = pcall(function() ws[kv[1]] = kv[2] end)
	print(if ok then "  " .. kv[1] .. " = " .. tostring(kv[2]) else "  couldn't set " .. kv[1] .. ": " .. tostring(err))
end

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or ws
	return p
end
part("Baseplate", Vector3.new(400, 20, 400), CFrame.new(0, -10, 0), Color3.fromRGB(91, 154, 76), Enum.Material.Grass)
local marks = Instance.new("Folder")
marks.Name = "Markers"
marks.Parent = ws
-- a white line down the middle and posts every 8 studs either side of it: stand on a post on one window and see
-- whether the other window puts you on the same one
part("MiddleLine", Vector3.new(2, 0.2, 200), CFrame.new(0, 0.1, 0), Color3.fromRGB(255, 255, 255), nil, marks)
for i = -12, 12 do
	local tall = i % 4 == 0
	part("Post" .. i, Vector3.new(1, if tall then 6 else 3, 1), CFrame.new(i * 8, if tall then 3 else 1.5, -20),
		if tall then Color3.fromRGB(255, 196, 60) else Color3.fromRGB(240, 240, 240), Enum.Material.Neon, marks)
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = CFrame.new(0, 0.5, 20)
spawn.Transparency = 1
spawn.Neutral = true
spawn.Parent = ws

local sp = game:GetService("StarterPlayer")
sp.CharacterUseJumpPower = false
sp.CharacterJumpHeight = 0 -- Space is the huss

local function module(name, path, parent)
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = fs.readFile(path)
	m.Parent = parent
	return m
end
local rs = game:GetService("ReplicatedStorage")
local cfg = Instance.new("Folder")
cfg.Name = "SATestConfig"
cfg.Parent = rs
module("Round", SHARED .. "Round.lua", cfg)
module("Run", SHARED .. "Run.lua", cfg)
module("HussSim", HERE .. "src/HussSim.luau", rs)

local server = Instance.new("Script")
server.Name = "SATestServer"
server.Source = fs.readFile(HERE .. "src/SATestServer.server.luau")
server.Parent = game:GetService("ServerScriptService")
local client = Instance.new("LocalScript")
client.Name = "SATestClient"
client.Source = fs.readFile(HERE .. "src/SATestClient.client.luau")
client.Parent = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts") or (function()
	local s = Instance.new("StarterPlayerScripts")
	s.Parent = sp
	return s
end)()

-- the status line, as a real UI part in StarterGui (the client only writes its text)
local gui = Instance.new("ScreenGui")
gui.Name = "SATest"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.Name = "Status"
label.BackgroundTransparency = 0.4
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.TextColor3 = Color3.new(1, 1, 1)
label.FontFace = roblox.Font.fromEnum(Enum.Font.GothamBold)
label.TextSize = 14
label.Size = UDim2.fromOffset(420, 26)
label.Position = UDim2.new(0, 12, 1, -38)
label.TextXAlignment = Enum.TextXAlignment.Left
label.Text = "Space huss · E dive"
label.Parent = gui
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.Parent = label
gui.Parent = game:GetService("StarterGui")

fs.writeFile(OUT, roblox.serializePlace(game))
print("saved " .. OUT)
