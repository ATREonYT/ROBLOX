-- The lobby finder and where the boards, stands and his props go (Shared/LobbyLayout), on the owner's own place
-- (places/HUSSANIME.rbxl, his new Halloween lobby of Oct 18: "I made it the lobby for all of the maps, please add all
-- of these leaderboards, all of the gamepass things to the new lobby"; then "implementing these objects into the lobby
-- on top of the already placed circles": his props on the pads, the stands in a row along the side), plus the pure
-- rules on made-up numbers.
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

-- pure: which prop on which pad (the side with three pads gets the three-list, each side from the middle outwards)
do
	local pads = {
		{ Pass = "VIP", along = 41 }, { Pass = "VIP", along = 27 }, { Pass = "VIP", along = 34 },
		{ Pass = "DancePack", along = -37 }, { Pass = "DancePack", along = -28 },
	}
	local got = {}
	for _, s in Layout.pickProps(pads, { "Chest", "Coffin", "Cauldron" }, { "Shop", "Gift" }) do got[s.Prop] = s.pad.along end
	check("props: one per pad", got.Chest and got.Coffin and got.Cauldron and got.Shop and got.Gift)
	check("props: the first of each list nearest the middle", got.Chest == 27 and got.Coffin == 34 and got.Cauldron == 41 and got.Shop == -28 and got.Gift == -37)
end

-- pure: the stands' row along a side (clear of things on the floor, nothing tall hidden behind them)
do
	local function box(x, z, top, hx, hz)
		return { X = x, Z = z, top = top, bottom = 12.5, hx = hx, hz = hz }
	end
	-- a plaza 136 (x) by 124 (z), centre 0,0, top 12.5; the front edge at z = -62; the stands' side is -x (edge -68)
	local rows = {
		box(-64, -10, 27, 7, 7), -- a tall wheel at the edge
		box(-60, 20, 19, 5, 3.5), -- a grave on the line
		box(-60, 30, 12.8, 3, 3), -- bones (low: fine)
	}
	local o = { cx = 0, cz = 0, top = 12.5, ix = 0, iz = 1, sx = -1, sz = 0, across = 68, depth = 62 }
	local row = Layout.pickRow(o, rows, 5)
	check("row: five spots", #row == 5)
	local ok, spaced, behind = true, true, false
	for i, r in row do
		for _, b in rows do
			if b.top > 13.5 and math.abs(r.x - b.X) < b.hx + 3 and math.abs(r.z - b.Z) < b.hz + 3 then ok = false end
		end
		if math.abs(r.z + 10) < 7 + 3 then behind = true end
		if i > 1 and r.z - row[i - 1].z < 8 then spaced = false end
		if r.z + 62 < Layout.ROW.FRONT then ok = false end
	end
	check("row: nothing in the way of a stand", ok)
	check("row: none hides the tall wheel", not behind)
	check("row: at least 8 studs apart, front to back", spaced)
	check("row: facing into the plaza (+x)", row[1] and math.abs(row[1].yaw - Layout.yawTo(0, 0, 1, 0)) < 1e-6)
	check("row: on the stands' side", row[1] and row[1].x < -40)
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
	local pads = Layout.pads(api, ws, floor)
	local podiumSide = 0
	local inward = floor.CFrame:VectorToWorldSpace(roblox.Vector3.new(pads[1].nx, 0, pads[1].nz))
	local across = roblox.Vector3.new(-inward.Z, 0, inward.X) -- (the plaza's width, from one side to the other)
	local vip, dance = 0, 0
	-- what stands on this plaza (for "nothing in the way")
	local f = Layout.facts(floor)
	local things = {}
	for _, d in ws:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") and d ~= floor then
			local q = d.CFrame.Position
			if math.abs(q.X - c.X) < f.hx + 5 and math.abs(q.Z - c.Z) < f.hz + 5 then
				local r = Layout.facts(d)
				if r.top > top + 1 and r.bottom < top + 6 and r.hx < 30 and r.hz < 30 then table.insert(things, r) end
			end
		end
	end
	local boardsHere = Layout.boardSpots(api, Rules, ws, floor, 5)
	for _, b in boardsHere do
		if b.podium then podiumSide += (b.at.Position - c):Dot(across) end
	end
	for i, s in stands do
		if s.Pass == "VIP" then vip += 1 else dance += 1 end
		local p, l = s.at.Position, s.at.LookVector
		local toCentre = (c - p) * roblox.Vector3.new(1, 0, 1)
		if show then print(string.format("  %s stand %s %d at (%.1f, %.1f, %.1f)", name, s.Pass, s.Turn, p.X, p.Y, p.Z)) end
		check(name .. ": stand faces into the plaza", l:Dot(toCentre.Unit) > 0.5)
		check(name .. ": stand on the floor", p.Y > top and p.Y < top + 1)
		local offPads = true
		for _, pad in pads do
			if math.abs(pad.wx - p.X) < 6 and math.abs(pad.wz - p.Z) < 6 then offPads = false end
		end
		check(name .. ": stand off the pads (his props are there)", offPads)
		local clear = true
		for _, r in things do
			if math.abs(r.X - p.X) < r.hx + 2.5 and math.abs(r.Z - p.Z) < r.hz + 2.5 then clear = false end
		end
		check(name .. ": nothing in the way of stand " .. i, clear)
		local side = (p - c):Dot(across)
		check(name .. ": stand " .. i .. " on the side opposite the podium boards", side * podiumSide < 0)
		for j = 1, i - 1 do
			check(name .. ": stands " .. j .. " and " .. i .. " apart", (stands[j].at.Position - p).Magnitude >= 8)
		end
	end
	check(name .. ": five stands, 3 VIP + 2 Dance Pack (one per Game Pass knife)", #stands == 5 and vip == 3 and dance == 2)
	local props = Layout.propSpots(api, ws, floor, { "Pumpkin_Patch_Chest", "Sweets_Treats_Coffin", "Witch_Brew_Cauldron" }, { "Shop_Stall", "Like_Reward_Gift" })
	local used, byName = {}, {}
	for _, s in props do
		local p = s.at.Position
		byName[s.Prop] = s
		if show then print(string.format("  %s prop %s at (%.1f, %.1f, %.1f)", name, s.Prop, p.X, p.Y, p.Z)) end
		used[s.pad] = true
		check(name .. ": " .. s.Prop .. " on its pad's top", math.abs(p.Y - 13.3) < 0.3)
		check(name .. ": " .. s.Prop .. " faces into the plaza", s.at.LookVector:Dot(((c - p) * roblox.Vector3.new(1, 0, 1)).Unit) > 0.3)
	end
	local n = 0
	for _ in used do n += 1 end
	check(name .. ": five props on five different pads", #props == 5 and n == 5)
	local shop = byName.Shop_Stall
	check(name .. ": the shop on the two-pad side (by the spawn and the stands)", shop ~= nil
		and (shop.at.Position - c):Dot(across) * podiumSide < 0)
	local boards = boardsHere
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
