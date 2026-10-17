-- lune run huzz-valley/tools/check_maps.luau [place.rbxl]   (from the repo root): finds the maps and lobbies in
-- places/HuzzValley-yours.rbxl (or the place given) the way the game will.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile(require("@lune/process").args[1] or "huzz-valley/places/HuzzValley-yours.rbxl"))
local ws = place:GetService("Workspace")
local Config = luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua"), { environment = { Color3 = roblox.Color3, Vector3 = roblox.Vector3 } })()
local fakeGame = {
	GetService = function(_, name)
		if name == "Workspace" then return ws end
		if name == "CollectionService" then return { GetTagged = function() return {} end } end
		if name == "ReplicatedStorage" then return place:GetService("ReplicatedStorage") end
		if name == "Players" then return { GetPlayers = function() return {} end } end
	end,
}
local env = setmetatable({
	game = fakeGame, workspace = ws, Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = roblox.Font, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence, RaycastParams = { new = function() return {} end },
	require = function() return Config end, task = { spawn = function() end },
}, { __index = _G })
env.game = { GetService = function(_, name) if name == "Workspace" then return ws end return fakeGame:GetService(name) end }
local MapService = luau.load(fs.readFile("huzz-valley/src/ServerScriptService/HuzzServer/MapService.lua"), { environment = env })()
MapService.init()
for _, m in MapService.maps do
	print(string.format("map %-15s shown as %-12s stored in %s", m.name, m.display, m.box:GetFullName()))
end
print("lobby:", MapService.lobby and MapService.lobby:GetFullName(), #MapService.lobbies, "lobbies")
local spawn = place:GetService("Workspace"):FindFirstChild("HuzzLobbySpawn")
print("lobby spawn made:", spawn ~= nil, spawn and spawn.CFrame.Position)
-- One lobby per map: each map's lobby, and after the vote only that lobby's spawn is on.
for _, m in MapService.maps do
	MapService.useLobbyFor(m)
	local on = {}
	for i, rec in MapService.lobbies do
		if rec.spawn and rec.spawn.Enabled then table.insert(on, i) end
	end
	local lp, sp = MapService.lobby.CFrame.Position, MapService.lobbySpawn()
	print(string.format("  %-15s lobby at (%.0f, %.0f), spawn at (%.0f, %.0f), spawns on: %s", m.name, lp.X, lp.Z, sp.X, sp.Z, table.concat(on, ",")))
	if #MapService.lobbies > 1 and #on ~= 1 then print("  PROBLEM: spawns on", #on) end
end
for i = 1, 4 do
	local a, b = MapService.candidates()
	print("vote " .. i .. ":", a.name, "vs", b.name, a ~= b and "" or "SAME MAP!")
end

-- Each map in front of the lobby: its safe lines sit on the zone edges that face the middle, the
-- SAFE ZONE sign follows the goal, and the start wall stands on the start line.
MapService.ground = function() return nil end -- Lune can't raycast: lines sit at the zone's bottom here
local problems = 0
-- Lune has no PivotTo, so the marks are checked on each stored map where it was built (they only
-- depend on the zones' shapes, which moving the map doesn't change).
local function key(n) return (string.gsub(n, "[%s_%-]", "")):lower() end
local function zonesIn(box)
	local found = {}
	for _, c in box:GetDescendants() do
		local k = key(c.Name)
		if c:IsA("BasePart") then
			if k == "zonea" then found.ZoneA = c elseif k == "zoneb" or k == "zoneb(mirrored)" then found.ZoneB = c elseif k == "middle" then found.Middle = c end
		end
	end
	return found
end
for _, m in MapService.maps do
	MapService.unload()
	local z = MapService.zones
	local found = zonesIn(m.box)
	z.ZoneA, z.ZoneB, z.Middle = found.ZoneA, found.ZoneB, found.Middle
	local mid = z.Middle.CFrame.Position
	for _, goal in { "ZoneB", "ZoneA" } do
		MapService.showGoal(goal)
		local marks = ws:FindFirstChild("HuzzSafeLines")		for _, name in { "ZoneA", "ZoneB" } do
			local line = marks:FindFirstChild("SafeLine" .. name)
			local zone = z[name]
			local p = line.CFrame.Position
			local inside = zone.CFrame:PointToObjectSpace(p)
			local half = zone.Size / 2
			local onEdge = math.abs(math.abs(inside.X) - half.X) < 0.01 or math.abs(math.abs(inside.Z) - half.Z) < 0.01
			local towardMiddle = (mid - zone.CFrame.Position).Magnitude > (mid - p).Magnitude
			local sign = marks:FindFirstChild("Sign" .. name).SafeZone.Enabled
			if goal == "ZoneB" then
				print(string.format("  %-10s %s line %.1f long at (%.1f, %.1f, %.1f): edge %s, faces middle %s", m.name, name, line.Size.X, p.X, p.Y, p.Z, tostring(onEdge), tostring(towardMiddle)))
			end
			if not (onEdge and towardMiddle) or sign ~= (name == goal) then
				problems += 1
				print("  PROBLEM", m.name, name, goal, onEdge, towardMiddle, sign)
			end
		end
	end
	MapService.holdStart("ZoneA", true)
	local wall = ws:FindFirstChild("HuzzStartWall").Block
	local inside = MapService.inZone(z.ZoneA, wall.CFrame.Position - wall.CFrame.LookVector * 0.6)
	print(string.format("  %-10s start wall %.1f wide, its zone side is in ZoneA: %s", m.name, wall.Size.X, tostring(not inside and "no (outside)" or "yes")))
	MapService.holdStart("ZoneA", false)
	if ws:FindFirstChild("HuzzStartWall") then problems += 1 print("  PROBLEM wall not removed") end
	local back = MapService.keepIn(z.ZoneA, mid)
	if not (back and MapService.inZone(z.ZoneA, back)) then problems += 1 print("  PROBLEM keepIn") end
end
-- Which side of each map faces the lobby (the open side; Halloween's Mausoleum on the far side).
for _, m in MapService.maps do
	local f = zonesIn(m.box)
	local a, b, mid = f.ZoneA.CFrame.Position, f.ZoneB.CFrame.Position, f.Middle.CFrame.Position
	local run = (b - a) * roblox.Vector3.new(1, 0, 1)
	local open = MapService.openSide(m.box, f.Middle, run.Unit, m.name)
	local asBuilt = (MapService.lobby.CFrame.Position - mid):Dot(open) > 0
	local note = ""
	local maus = m.box:FindFirstChild("Mausoleum", true)
	if maus then
		local sum, n = roblox.Vector3.new(0, 0, 0), 0
		for _, d in maus:GetDescendants() do if d:IsA("BasePart") then sum += d.CFrame.Position; n += 1 end end
		local far = ((sum / n) - mid):Dot(open) < 0
		note = if far then ", Mausoleum on the far side" else ", MAUSOLEUM FACES THE LOBBY"
		if not far then problems += 1 end
	end
	print(string.format("  %-15s faces the lobby with %s%s", m.name, if asBuilt then "the side that faced it as built" else "its other side (turned round)", note))
end
print(if problems == 0 then "map marks ok" else problems .. " problems")
