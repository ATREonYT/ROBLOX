-- Check: the lobby leaderboards and avatar stands run end to end offline (HuzzServer/LeaderboardService,
-- Gameplay/Leaderboards, Gameplay/AvatarStands). With no boards in the place, five are made round the lobby floor,
-- tagged, filled with this server's players (Studio: no DataStores), drawn on this screen and turned to face you;
-- a block named AvatarStand gets your copy, its sign, and a button that never opens a purchase for a pass that
-- isn't ready ("coming soon").
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_lobby_boards.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- a lobby floor like the owner's (Maps > Spawn > SpawnBaseplate, 100 x 13 x 100, top at 19.6) and one of his 4 x 8 x 4 blocks
local floor = Instance.new("Part")
floor.Name = "SpawnBaseplate"
floor.Anchored = true
floor.Size = Vector3.new(100, 13, 100)
floor.CFrame = CFrame.new(-227, 13.1, -706)
floor.Parent = workspace
local block = Instance.new("Part")
block.Name = "AvatarStand"
block.Anchored = true
block.Size = Vector3.new(4, 8, 4)
block.CFrame = CFrame.new(-269, 23.6, -726)
block:SetAttribute("Pass", "VIP")
block.Parent = workspace

-- (Lune has no HttpService JSON: the same thing through serde)
__roblox.implementMethod("HttpService", "JSONEncode", function(_, v) return __serde.encode("json", v) end)
__roblox.implementMethod("HttpService", "JSONDecode", function(_, s) return __serde.decode("json", s) end)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)

-- boards made round the floor
local holder = workspace:FindFirstChild("HuzzLeaderboards")
check("default boards made", holder ~= nil)
local boards = holder and holder:GetChildren() or {}
check("five boards", #boards == 5)
local stats = {}
for _, b in boards do
	stats[b:GetAttribute("Stat") or "?"] = b
	check(b.Name .. " tagged", b:HasTag("HuzzLeaderboard"))
	local board = b:FindFirstChild("Board")
	check("board part", board ~= nil and board:IsA("BasePart"))
	if board then
		local p = board.CFrame.Position
		check("on the floor (x)", math.abs(p.X - -227) + 7 <= 50)
		check("on the floor (z)", math.abs(p.Z - -706) + 1 <= 50)
		check("stands on the floor top", math.abs((p.Y - board.Size.Y / 2) - (19.6 + 1.2)) < 0.05)
		check("saved face", board:FindFirstChild("LeaderboardFace") ~= nil)
		check("no collisions on the slab", board.CanCollide == false)
	end
end
for _, s in { "Level", "Wins", "Catches", "Rescues", "Girls" } do check("board " .. s, stats[s] ~= nil) end

-- the character, then the screens
local function character()
	local c = Instance.new("Model"); c.Name = "Tester"
	local hum = Instance.new("Humanoid"); hum.Parent = c
	local r = Instance.new("Part"); r.Name = "HumanoidRootPart"; r.Size = Vector3.new(2, 2, 1); r.CFrame = CFrame.new(-227, 23, -690); r.Parent = c
	local h = Instance.new("Part"); h.Name = "Head"; h.Size = Vector3.new(2, 1, 1); h.CFrame = CFrame.new(-227, 25, -690); h.Parent = c
	c.Parent = workspace
	return c
end
me.Character = character()
local errors = {}
local Gameplay = game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay
for _, name in { "Leaderboards", "AvatarStands" } do
	local okS, err = pcall(function() require(Gameplay[name]).start() end)
	check(name .. " starts: " .. tostring(err), okS)
end
task.wait(0.3)

-- server data: this server's player on every board
local data = RS:FindFirstChild("HuzzLeaderboards")
check("data folder", data ~= nil)
local json = data and data:GetAttribute("Level")
check("level board data", type(json) == "string" and string.find(json, "Tester") ~= nil)
check("wins board data", data and type(data:GetAttribute("Wins")) == "string")

-- drawn on this screen
local guis = {}
for _, g in me.PlayerGui:GetChildren() do
	if string.sub(g.Name, 1, 12) == "Leaderboard_" then table.insert(guis, g) end
end
check("five faces in PlayerGui", #guis == 5)
local levelGui = me.PlayerGui:FindFirstChild("Leaderboard_Level")
check("adorned to its board", levelGui and levelGui.Adornee ~= nil)
local row1 = levelGui and levelGui.Canvas.List:FindFirstChild("Row1")
check("row 1 filled: " .. tostring(row1 and row1.PlayerName.Text), row1 and row1.PlayerName.Text == "#1 Tester")
check("row 1 value", row1 and row1.Value.Text == "LEVEL 1")
check("headshot", row1 and string.find(row1.Avatar.Image, "AvatarHeadShot&id=77", 1, true) ~= nil)
check("12 bands shown", levelGui and levelGui.Canvas.List:FindFirstChild("Row12") ~= nil)
check("saved face switched off", levelGui and levelGui.Adornee:FindFirstChild("LeaderboardFace").Enabled == false)
local winsRow = me.PlayerGui.Leaderboard_Wins.Canvas.List.Row1
check("wins trophy", winsRow:FindFirstChild("Trophy") ~= nil and winsRow.Trophy.Visible)
check("wins number", winsRow.Value.Text == "0")
check("title", me.PlayerGui.Leaderboard_Catches.Canvas.Title.Text == "MOST CATCHES")
check("subtitle", me.PlayerGui.Leaderboard_Catches.Canvas.Subtitle.Text == "GLOBAL · ALL TIME · TOP 50")

-- turning towards you (yaw only, a little behind)
local board = levelGui.Adornee
local before = board.CFrame
for _ = 1, 3 do __fireOn(RunService, "RenderStepped", 1 / 30) end
local after = board.CFrame
check("board turned", (after.LookVector - before.LookVector).Magnitude > 1e-4)
check("stays upright", math.abs(after.LookVector.Y) < 1e-6 and math.abs(after.UpVector.Y - 1) < 1e-6)
check("stays in place", (after.Position - before.Position).Magnitude < 1e-6)
for _ = 1, 400 do __fireOn(RunService, "RenderStepped", 1 / 30) end
local toMe = (me.Character.HumanoidRootPart.CFrame.Position - board.CFrame.Position) * Vector3.new(1, 0, 1)
check("faces you in the end", board.CFrame.LookVector:Dot(toMe.Unit) > 0.99)

-- the avatar stand
local copies = workspace:FindFirstChild("HuzzStandAvatars")
local copy = copies and copies:FindFirstChild("StandAvatar")
check("your copy stands there", copy ~= nil)
if copy then
	local root = copy.HumanoidRootPart
	check("copy anchored by its root", root.Anchored)
	check("copy where the block was", math.abs(root.CFrame.Position.X - -269) < 0.01 and math.abs(root.CFrame.Position.Z - -726) < 0.01)
	check("feet on the floor (tall block turns into you)", root.CFrame.Position.Y > 19.6 and root.CFrame.Position.Y < 19.6 + 6)
	check("no name tag on the copy", copy:FindFirstChildWhichIsA("BillboardGui", true) == nil)
end
check("block hidden on this screen", block.LocalTransparencyModifier == 1)
check("calm glow", copies and copies:FindFirstChild("StandGlow") ~= nil)
local sign = me.PlayerGui:FindFirstChild("StandSign")
check("sign", sign ~= nil and sign.Plate.Title.Text == "VIP")
check("tag", sign and sign.Tag.Text == "GAME PASS")
local button = me.PlayerGui:FindFirstChild("StandButton")
local text = button and button.View.Text or ""
check("button says soon (VIP has no ID yet): " .. text, string.find(text, "SOON", 1, true) ~= nil)
for _, w in { "LIMITED", "ENDS" } do
	check("no " .. w, not string.find(text .. (sign and sign.Tag.Text or ""), w, 1, true))
end
_G.__prompts = {}
if button then __fireOn(button.View, "Activated") end
task.wait(0.05)
check("tapping never opens a purchase", #_G.__prompts == 0)

print(string.format("lobby boards: %d ok, %d failed", ok, fails))
return nil
