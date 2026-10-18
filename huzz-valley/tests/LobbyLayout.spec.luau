-- The lobby finder and where the boards and stands go (Shared/LobbyLayout), on the owner's own place
-- (places/HUSSANIME.rbxl, his new Halloween lobby of Oct 18: "I made it the lobby for all of the maps, please add all
-- of these leaderboards, all of the gamepass things to the new lobby"), plus the pure rules on made-up numbers.
-- Run from huzz-valley/: lune run tests/LobbyLayout.spec.luau   (PRINT=1 lists every spot)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Layout = require("../src/ReplicatedStorage/Shared/LobbyLayout")
local Rules = require("../src/ReplicatedStorage/Shared/LeaderboardRules")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end
local show = process.env.PRINT == "1"
local api = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame }

-- pure: floors (biggest per lobby copy, copies on top of each other once, the plaza over the grey slab under it)
do
	local function row(x, y, z, sx, sy, sz)
		return { ref = x .. "," .. z .. "," .. y, X = x, Y = y, Z = z, SX = sx, SY = sy, SZ = sz, flat = true, top = y + sy / 2 }
	end
	local picked = Layout.pickFloors({
		row(0, 8.5, 0, 124, 8, 136), row(0, 4, 0, 124, 1, 136), row(4, 8.5, 113, 101.5, 8, 145.5), -- one copy
		row(600, 8.5, 0, 124, 8, 136), row(600, 8.5, 0, 124, 8, 136), -- pasted twice
		row(0, 30, 300, 40, 8, 40), -- a small terrace
	})
	check("two lobby copies (one pasted twice counts once)", #picked == 2)
	check("the plaza, not the grey slab under it or the house floor", picked[1] and picked[1].top == 12.5 and picked[1].SX == 124 and picked[1].Z == 0)
end

-- pure: pads (three on one side = VIP, two = Dance Pack, facing away from the front edge)
do
	local rows = {}
	for _, x in { 41, 34, 27, -28, -37 } do
		table.insert(rows, { ref = x, x = x, z = -55, wx = x, wz = -55, top = 13.3, w = 6, d = 6.5 })
	end
	table.insert(rows, { ref = "dup", x = 41.3, z = -55, wx = 41.3, wz = -55, top = 13.3, w = 6, d = 6.5 }) -- (a second copy)
	table.insert(rows, { ref = "bone", x = 0, z = 0, top = 13, w = 5, d = 1.5 }) -- (a bone on the carpet)
	table.insert(rows, { ref = "high", x = 0, z = 20, top = 40, w = 6, d = 6 }) -- (not on the floor)
	local pads = Layout.pickPads(62, 68, 12.5, rows)
	local vip, dance = 0, 0
	for _, p in pads do
		if p.Pass == "VIP" then vip += 1 else dance += 1 end
	end
	check("five pads (copies, bones and high parts left out)", #pads == 5)
	check("three-pad side is VIP, two-pad side Dance Pack", vip == 3 and dance == 2)
	check("they face into the plaza (away from the front edge)", pads[1] and pads[1].nz == 1 and pads[1].nx == 0)
	local turns = {}
	for _, p in pads do turns[p.Pass .. p.Turn] = true end
	check("each pass's knives in turn", turns.VIP1 and turns.VIP2 and turns.VIP3 and turns.DancePack1 and turns.DancePack2 and not turns.VIP4)
end

-- pure: terrace steps (behind the plaza, clear, one each side)
do
	local function box(x, z, top, hx, hz, bottom)
		return { X = x, Z = z, top = top, bottom = bottom or (top - 8), hx = hx, hz = hz, flat = true }
	end
	local rows = {
		box(0, 0, 12.5, 62, 68, 4.5), -- the plaza
		box(-80, 77, 23.5, 15, 17), box(80, 77, 23.5, 15, 17), -- a low step each side behind it
		box(0, 100, 23.5, 15, 15), -- one right behind the middle...
		box(0, 100, 60, 20, 20, 13), -- ...under the house
		box(-80, -80, 23.5, 15, 15), -- in front: never
	}
	local steps = Layout.pickSteps(0, 0, 12.5, 62, 68, 0, 1, rows, 2)
	check("two steps, one each side", #steps == 2 and steps[1].side ~= steps[2].side)
	local underHouse = false
	for _, s in steps do if math.abs(s.x) < 20 then underHouse = true end end
	check("not under the house", not underHouse)
	check("facing the front, like the stands", steps[1] and math.abs(steps[1].yaw - Layout.yawTo(0, 0, 0, -1)) < 1e-6)
end

-- his place
local game = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local ws = game:GetService("Workspace")
local floors = Layout.floors(ws)
check("three lobbies: his new lobby in front of each map (" .. #floors .. ")", #floors == 3)
local allInFolder = true
for _, f in floors do
	if not f:IsDescendantOf(ws:FindFirstChild("StartingPoint")) then allInFolder = false end
end
check("all in StartingPoint (not the old islands in Maps > Spawn)", allInFolder)

for _, floor in floors do
	local c = floor.CFrame.Position
	local top = Layout.facts(floor).top
	local name = string.format("lobby at (%d, %d)", math.round(c.X), math.round(c.Z))
	check(name .. ": the 124 x 136 plaza, top 12.5", math.abs(top - 12.5) < 0.01 and math.abs(floor.Size.X * floor.Size.Z - 124 * 136) < 1)
	local stands = Layout.standSpots(api, ws, floor)
	local vip, dance = 0, 0
	for _, s in stands do
		if s.Pass == "VIP" then vip += 1 else dance += 1 end
		local p, l = s.at.Position, s.at.LookVector
		local toCentre = (c - p) * roblox.Vector3.new(1, 0, 1)
		if show then print(string.format("  %s stand %s %d at (%.1f, %.1f, %.1f)", name, s.Pass, s.Turn, p.X, p.Y, p.Z)) end
		check(name .. ": stand faces into the plaza", l:Dot(toCentre.Unit) > 0.5)
		check(name .. ": stand on its pad (just over the floor)", p.Y > top and p.Y < top + 2)
	end
	check(name .. ": five stands, 3 VIP + 2 Dance Pack (one per Game Pass knife)", #stands == 5 and vip == 3 and dance == 2)
	local boards = Layout.boardSpots(api, Rules, ws, floor, 5)
	local onPodium, onStep = 0, 0
	for i, b in boards do
		local p, l = b.at.Position, b.at.LookVector
		if show then print(string.format("  %s board %d %s at (%.1f, %.1f, %.1f) look (%.2f, %.2f)", name, i, b.podium and "podium" or "step", p.X, p.Y, p.Z, l.X, l.Z)) end
		if b.podium then onPodium += 1 elseif p.Y > top + 5 then onStep += 1 end
		local toCentre = ((c - p) * roblox.Vector3.new(1, 0, 1)).Unit
		check(name .. ": board " .. i .. " faces the plaza", l:Dot(toCentre) > 0.5)
		-- clear of the stands, the girl display and the house entrance (the middle of the back edge)
		for _, s in stands do
			check(name .. ": board " .. i .. " away from the stands", (s.at.Position - p).Magnitude > 12)
		end
		local r = floor.CFrame:PointToObjectSpace(p)
		check(name .. ": board " .. i .. " off the middle (girl display, house door)", math.abs(r.Z) > 25 or math.abs(r.X) > 25)
	end
	check(name .. ": five boards: 3 on his podiums, 2 on the terrace steps", #boards == 5 and onPodium == 3 and onStep == 2)
end

print(string.format("LobbyLayout: %d ok, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
