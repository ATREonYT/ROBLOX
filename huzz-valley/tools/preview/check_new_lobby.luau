-- Check: the owner's new lobby (Oct 18: "I made it the lobby for all of the maps, please add all of these
-- leaderboards, all of the gamepass things to the new lobby") works end to end offline, the way it does in his own
-- Rojo-synced place, where nothing of ours is saved: a Workspace > StartingPoint like his (the 124 x 136 plaza with a
-- grey slab under it, three grey Podiums along one side, five small round pads at the front, three on one side and
-- two on the other, a low terrace step each side behind the plaza, the house floor in the middle behind), and his old
-- lobby island (Maps > Spawn > SpawnBaseplate with a grey block by a spin wheel) still lying off to the side.
-- The plaza is the lobby (spawn on it), not the old island; the five boards stand on the podiums and the steps,
-- facing the plaza; an invisible stand on each pad (3 VIP, 2 Dance Pack, one Game Pass knife each) gets your copy
-- standing on the pad; his old grey block stays a block.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_new_lobby.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local function part(parent, name, size, at, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = at
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- his new lobby (one copy; positions as in his place's Base copy)
local sp = Instance.new("Folder"); sp.Name = "StartingPoint"; sp.Parent = workspace
local plaza = part(sp, "Baseplate", Vector3.new(124, 8, 136), CFrame.new(-131, 8.5, 49))
part(sp, "Baseplate", Vector3.new(124, 1, 136), CFrame.new(-131, 4, 49)) -- (the grey slab under it)
part(sp, "Baseplate", Vector3.new(101.5, 8, 145.5), CFrame.new(-127, 8.5, 162)) -- (the house floor behind)
part(sp, "Baseplate", Vector3.new(30, 8, 34), CFrame.new(-51, 19.5, 126)) -- low terrace step, one side
part(sp, "Baseplate", Vector3.new(30, 8, 40), CFrame.new(-194, 19.5, 126)) -- and the other
for _, z in { 31, 50, 69 } do
	local podium = Instance.new("Model"); podium.Name = "Podium"; podium.Parent = sp
	part(podium, "Part", Vector3.new(8, 3, 17), CFrame.new(-71, 14, z))
end
local pads = {}
for _, x in { -90, -97, -104, -159, -168 } do
	local pad = Instance.new("Model"); pad.Name = "Model"; pad.Parent = sp
	local turned = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder lies along X: turned so it stands up, flat)
	part(pad, "Part", Vector3.new(0.4, 6, 6), CFrame.new(x, 12.7, -6) * turned, Enum.PartType.Cylinder)
	part(pad, "Part", Vector3.new(0.4, 5.5, 5.5), CFrame.new(x, 13.1, -6) * turned, Enum.PartType.Cylinder)
	table.insert(pads, pad)
end
local spawnAt = Instance.new("SpawnLocation"); spawnAt.Anchored = true; spawnAt.Size = Vector3.new(12, 1, 12)
spawnAt.CFrame = CFrame.new(-158, 12.7, 50)
-- his old island, moved off to the side (Maps > Spawn), with a grey block by its spin wheel
local maps = Instance.new("Folder"); maps.Name = "Maps"; maps.Parent = workspace
local old = Instance.new("Folder"); old.Name = "Spawn"; old.Parent = maps
spawnAt.Parent = old
part(old, "SpawnBaseplate", Vector3.new(100, 13, 100), CFrame.new(-416, 10.4, 172))
local block = part(old, "Part", Vector3.new(4, 7.5, 4.5), CFrame.new(-458, 20.7, 168))
local wheel = Instance.new("Model"); wheel.Name = "SpinWheel"; wheel.Parent = workspace
part(wheel, "Part", Vector3.new(2, 2, 2), CFrame.new(-459, 18, 186))
part(wheel, "Part", Vector3.new(2, 2, 2), CFrame.new(-459, 31, 186))

__roblox.implementMethod("HttpService", "JSONEncode", function(_, v) return __serde.encode("json", v) end)
__roblox.implementMethod("HttpService", "JSONDecode", function(_, s) return __serde.decode("json", s) end)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)

-- the lobby: the plaza (players spawn there), not his old island
local MapService = require(game.ServerScriptService.HuzzServer.MapService)
MapService.init() -- (RoundService.server does this in the game; it isn't run here)
check("the lobby is the new plaza", MapService.lobby == plaza)
local at = MapService.lobbySpawn()
check("players wait on the plaza", at ~= nil and math.abs(at.X - -131) < 62 and math.abs(at.Z - 49) < 68 and at.Y > 12)

-- the boards: three on the podiums, two on the terrace steps, all facing the plaza
local holder = workspace:FindFirstChild("HuzzLeaderboards")
local boards = holder and holder:GetChildren() or {}
check("five boards (" .. #boards .. ")", #boards == 5)
local onPodium, onStep = 0, 0
for _, b in boards do
	local slab = b:FindFirstChild("Board")
	if slab then
		local p = slab.CFrame.Position
		local bottom = p.Y - slab.Size.Y / 2
		if math.abs(p.X - -71) < 3 then onPodium += 1 elseif bottom > 23 then onStep += 1 end
		local toPlaza = (Vector3.new(-131, p.Y, 49) - p).Unit
		check(b:GetAttribute("Stat") .. " faces the plaza", slab.CFrame.LookVector:Dot(toPlaza) > 0.5)
		check(b:GetAttribute("Stat") .. " off the house door (middle of the back)", math.abs(p.X - -131) > 30 or p.Z < 90)
	end
end
check("three on his podiums (" .. onPodium .. ")", onPodium == 3)
check("two on the terrace steps (" .. onStep .. ")", onStep == 2)

-- the stands: one invisible stand on each pad, his old block left alone
local standFolder = workspace:FindFirstChild("HuzzAvatarStands")
local stands = standFolder and standFolder:GetChildren() or {}
check("five stands on the pads (" .. #stands .. ")", #stands == 5)
local vip, dance, knives = 0, 0, {}
for _, s in stands do
	check("stand tagged", s:HasTag("HuzzAvatarStand"))
	check("stand invisible, walk-through", s.Transparency == 1 and s.CanCollide == false)
	knives[s:GetAttribute("Knife") or "?"] = true
	local item = require(game.ReplicatedStorage.Shared.Config.CoinShop).get(s:GetAttribute("Knife") or "")
	if item and item.Pass == s:GetAttribute("Pass") then vip += 1 end -- (each stand sells its own knife's Game Pass)
	local p = s.CFrame.Position
	local onPad = false
	for _, x in { -90, -97, -104, -159, -168 } do
		if math.abs(p.X - x) < 0.6 and math.abs(p.Z - -6) < 0.6 and p.Y > 13.2 and p.Y < 14 then onPad = true end
	end
	check("on a pad", onPad)
	check("faces into the plaza", s.CFrame.LookVector.Z > 0.9)
end
check("each stand sells its knife's own Game Pass (owner Oct 18: one pass per knife)", vip == 5)
local five = 0
for _, k in { "CelestialSeraph", "CrimsonRequiem", "HollowEclipse", "DragonsMaw", "FrostboundOath" } do
	if knives[k] then five += 1 end
end
check("each Game Pass knife once (" .. five .. ")", five == 5)
check("the three-pad side shows Hunter, Moonlit and Sunrise (his card order)", (function()
	local first = { HunterKnifePass = true, MoonlitKnifePass = true, SunriseKnifePass = true }
	for _, s in stands do
		if (first[s:GetAttribute("Pass")] == true) ~= (s.CFrame.Position.X > -131) then return false end
	end
	return true
end)())
check("his old grey block stays a block", not block:HasTag("HuzzAvatarStand") and block.Name == "Part" and block:GetAttribute("Pass") == nil)

-- your copy on a pad
local function character()
	local c = Instance.new("Model"); c.Name = "Tester"
	local hum = Instance.new("Humanoid"); hum.Parent = c
	local r = Instance.new("Part"); r.Name = "HumanoidRootPart"; r.Size = Vector3.new(2, 2, 1); r.CFrame = CFrame.new(-131, 16, 20); r.Parent = c
	local h = Instance.new("Part"); h.Name = "Head"; h.Size = Vector3.new(2, 1, 1); h.CFrame = CFrame.new(-131, 18, 20); h.Parent = c
	local hand = Instance.new("Part"); hand.Name = "RightHand"; hand.Size = Vector3.new(0.6, 0.6, 0.6); hand.CFrame = CFrame.new(-129.5, 15, 20); hand.Parent = c
	c.Parent = workspace
	return c
end
me.Character = character()
local Gameplay = game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay
for _, name in { "Leaderboards", "AvatarStands" } do
	local okS, err = pcall(function() require(Gameplay[name]).start() end)
	check(name .. " starts: " .. tostring(err), okS)
end
task.wait(0.3)
local copies = workspace:FindFirstChild("HuzzStandAvatars")
local count, onTop = 0, 0
for _, c in (copies and copies:GetChildren() or {}) do
	if c.Name == "StandAvatar" then
		count += 1
		local root = c:FindFirstChild("HumanoidRootPart")
		if root and root.CFrame.Position.Y > 13.5 and root.CFrame.Position.Y < 13.5 + 6 then onTop += 1 end
	end
end
check("your copy on every pad (" .. count .. ")", count == 5)
check("standing on top of the pads", onTop == 5)

print(string.format("new lobby: %d ok, %d failed", ok, fails))
