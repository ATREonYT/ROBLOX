-- A board's face (Shared/LeaderboardLook, the game's own code) for the side-by-side with Huss Valley's MOST WINS
-- board (tools/preview/leaderboard_vs_ref.py). The slab and its studs are a part in the game, so here they are
-- drawn under the face: the colour the reference shows under its night light (113, 70, 97) and our stud tile
-- every 50 px (one stud). The rows hold the reference board's own names and numbers, for comparing only.
-- From tools/preview: lune run harness.luau ../../src <out.json> "$(cat leaderboard_preview.luau)" setup_ui.luau
local RS = game:GetService("ReplicatedStorage")
local Look = require(RS.Shared.LeaderboardLook)
local Rules = require(RS.Shared.LeaderboardRules)
local Config = require(RS.Shared.Config.Leaderboards)
_G.__screenSize = Vector2.new(Look.Canvas.W, Look.Canvas.H)
local gui = Instance.new("ScreenGui")
gui.Name = "BoardPreview"
gui.Parent = game:GetService("StarterGui")
local slab = Instance.new("Frame")
slab.Name = "Slab"
slab.BorderSizePixel = 0
slab.BackgroundColor3 = Color3.fromRGB(113, 70, 97)
slab.Size = UDim2.fromOffset(Look.Canvas.W, Look.Canvas.H)
slab.Parent = gui
local studs = Instance.new("ImageLabel")
studs.Name = "Studs"
studs.BackgroundTransparency = 1
studs.Size = UDim2.fromScale(1, 1)
studs.ScaleType = Enum.ScaleType.Tile
studs.TileSize = UDim2.fromOffset(50, 50)
studs.ImageTransparency = 0
studs:SetAttribute("Icon", "StudPattern")
studs:SetAttribute("PreviewFile", "assets/icons/stud-pattern.png")
studs.Parent = slab
local api = { Instance = Instance, UDim2 = UDim2, UDim = UDim, Color3 = Color3, Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, Enum = Enum, Font = Font }
local def
for _, d in Config.Boards do if d.Stat == (__previewStat or "Wins") then def = d end end
local canvas = Look.canvas(api, slab, def, Config.Subtitle)
local names = { "5_dmi", "TheMicrobloxGamer", "roblox_user_4802712065", "Jefferson6293", "hope_cakepop", "firhankhan", "noctyythegoat",
	"XXXStk_FamilyXXX", "Sk_jesse24", "lvhhaz", "imnotgau", "yaboihame" }
local values = { 2611, 2441, 2402, 2148, 1999, 1987, 1980, 1973, 1844, 1747, 1720, 1716 }
local entries = {}
for i, n in names do entries[i] = { u = i, n = n, v = values[i] } end
Look.fill(api, canvas, def, entries, Config.Shown, Rules.format, nil)
for _, d in canvas:GetDescendants() do
	if d.Name == "Avatar" then d:SetAttribute("Icon", "Avatar") end -- (offline: a stand-in head)
end
return gui
