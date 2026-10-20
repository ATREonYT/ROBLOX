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
	check(name .. ": three stands (owner, Oct 20 20:34: \"make 3 characters be there, not 5\")", #stands == 3 and vip == 3 and dance == 0)
	for j = 2, #stands do
		check(name .. ": stands " .. (j - 1) .. " and " .. j .. " spaced at least 10 apart (signs don't overlap)", (stands[j].at.Position - stands[j - 1].at.Position).Magnitude >= 10)
	end
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

-- The bigger Halloween stands (owner, Oct 20: "in general go make the halloween shop objects bigger so they stand out
-- more"): LobbyPropBuild.grow on his main lobby, then each stand built the way the game builds it (the stand-in), and
-- the same open-space rules as the stands above: his pads apart, each prop's turning circle on its pad and clear of
-- its neighbours, of the things on the plaza (the tree), the spawn pad, the stands and the plaza's edge, and each
-- title clear of everything over it (the tree's leaves) and of its neighbours' titles.
do
	local luau = require("@lune/luau")
	local Build = require("../src/ReplicatedStorage/Shared/LobbyPropBuild")
	local Shapes = require("../src/ServerScriptService/HuzzServer/LobbyPropShapes")
	local env = setmetatable({ Color3 = roblox.Color3 }, { __index = _G })
	local Props = luau.load(fs.readFile("src/ReplicatedStorage/Shared/Config/LobbyProps.lua"), { debugName = "LobbyProps", environment = env })()
	local floor = Layout.main(ws)
	local f = Layout.facts(floor)
	local top = f.top
	local stands = Layout.standSpots(api, ws, floor)
	local spawn = Layout.spawnPad(api, ws, floor)
	local spots = Layout.propSpots(api, ws, floor, Props.ThreePads, Props.TwoPads)
	local before = {}
	for _, s in spots do
		before[s.Prop] = { at = s.at, size = (s.pad:FindFirstChildWhichIsA("BasePart", true) :: BasePart).Size }
	end
	local padsBefore = Layout.pads(api, ws, floor)
	local standsBefore = stands
	local moves = Build.grow(Build.api(roblox), spots, Props)
	-- after the grow (as in the download, where the bigger pads are saved), everything that finds his pads at game
	-- start still finds all five, on the same sides, so the stands, boards and spawn pad stay where they were
	local padsAfter = Layout.pads(api, ws, floor)
	local sameSides = #padsAfter == #padsBefore
	for i, p in padsAfter do
		if not padsBefore[i] or padsBefore[i].ref ~= p.ref or padsBefore[i].Pass ~= p.Pass then sameSides = false end
	end
	check("bigger: his five pads still found, on the same sides", #padsAfter == 5 and sameSides)
	local standsAfter = Layout.standSpots(api, ws, floor)
	local sameStands = #standsAfter == #standsBefore
	for i, st in standsAfter do
		if not standsBefore[i] or (st.at.Position - standsBefore[i].at.Position).Magnitude > 0.01 then sameStands = false end
	end
	check("bigger: the stands where they were", sameStands)
	check("bigger: the spawn pad where it was", (Layout.spawnPad(api, ws, floor).centre - spawn.centre).Magnitude < 0.01)
	local function flat(v) return roblox.Vector3.new(v.X, 0, v.Z) end
	-- how far his pad Model reaches from `from` along the flat direction `dir`
	local function padReach(model, from, dir)
		local far = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local cf, sz = d.CFrame, d.Size
				local along = math.abs(cf.RightVector:Dot(dir)) * sz.X / 2 + math.abs(cf.UpVector:Dot(dir)) * sz.Y / 2
					+ math.abs(cf.LookVector:Dot(dir)) * sz.Z / 2
				far = math.max(far, (d.CFrame.Position - from):Dot(dir) + along)
			end
		end
		return far
	end
	local byName, info = {}, {}
	for _, s in spots do
		byName[s.Prop] = s
		local cfg = Props.Props[s.Prop]
		local shape = Shapes[s.Prop]
		local w, d = shape.size[1] * cfg.Scale, shape.size[3] * cfg.Scale
		local lp = Build.make(Build.api(roblox), s, Props, shape, nil, "")
		local pad = lp:FindFirstChild("Pad")
		local bb = pad:FindFirstChild("PropTitle")
		local mid = pad.CFrame.Position.Y + bb.StudsOffsetWorldSpace.Y
		local bbH = bb.Size.Y.Scale
		-- the title's letters: TextScaled fills each line's height; FredokaOne's capitals are about 0.62 of that wide
		local title = bb:FindFirstChild("Title")
		local lineH = title.Size.Y.Scale * bbH / #string.split(title.Text, "\n")
		local longest = 0
		for _, l in string.split(title.Text, "\n") do longest = math.max(longest, #l) end
		local halfText = math.min(bb.Size.X.Scale, longest * lineH * 0.62) / 2
		local padR = 0
		for _, a in { 0, 90, 180, 270 } do -- (along and across the row: his pads are round, their boxes are not)
			local dir = roblox.Vector3.new(math.cos(math.rad(a)), 0, math.sin(math.rad(a)))
			padR = math.max(padR, padReach(s.pad, s.at.Position, dir))
		end
		info[s.Prop] = {
			c = flat(s.at.Position), swept = math.sqrt(w * w + d * d) / 2, padR = padR,
			tLo = mid - bbH / 2, tHi = mid + bbH / 2, halfText = halfText, lp = lp,
		}
		if show then
			print(string.format("  grown %s at (%.1f, %.1f, %.1f) pad r %.2f swept r %.2f title %.2f-%.2f half %.2f", s.Prop,
				s.at.Position.X, s.at.Position.Y, s.at.Position.Z, padR, info[s.Prop].swept, info[s.Prop].tLo, info[s.Prop].tHi, halfText))
		end
	end
	local grown = {}
	for _, m in moves do
		grown[m.Prop] = m
		if show then print(string.format("  %s %.2gx, moved %.2f studs outward", m.Prop, m.Grow, m.Shift)) end
	end
	check("bigger: WITCH'S BREW and SWEETS & TREATS grown, nothing else", grown.Witch_Brew_Cauldron ~= nil
		and grown.Sweets_Treats_Coffin ~= nil and #moves == 2)
	for key, m in grown do
		local s = byName[key]
		local part = s.pad:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		check("bigger: " .. key .. "'s pad is his, scaled " .. m.Grow .. "x", (part.Size - before[key].size * m.Grow).Magnitude < 0.01)
		check("bigger: " .. key .. "'s prop scaled " .. m.Grow .. "x on its pad", math.abs(info[key].lp:GetAttribute("Scale") / (key == "Witch_Brew_Cauldron" and 2.5 or 2.3) - m.Grow) < 0.01)
		local moved = s.at.Position - before[key].at.Position
		check("bigger: " .. key .. " moved only along its row", math.abs(flat(moved):Dot(before[key].at.LookVector)) < 0.01)
		local padTop = -math.huge
		for _, d in s.pad:GetDescendants() do
			if d:IsA("BasePart") then padTop = math.max(padTop, d.CFrame.Position.Y + d.Size.X / 2) end
		end
		check("bigger: " .. key .. " stands on its bigger pad's top", math.abs(s.at.Position.Y - padTop) < 0.15)
	end
	for key, s in byName do
		if not grown[key] then
			check("bigger: " .. key .. " (his other prop) not moved", (s.at.Position - before[key].at.Position).Magnitude < 0.001)
		end
	end
	-- the things on the plaza, as the stand checks above see them (his pads aside)
	local things = {}
	for _, d in ws:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") and d ~= floor then
			local q = d.CFrame.Position
			local r = Layout.facts(d)
			local inPad = false
			for _, s in spots do
				if d:IsDescendantOf(s.pad) then inPad = true end
			end
			if not inPad and math.abs(q.X - floor.CFrame.Position.X) < f.hx + 5 and math.abs(q.Z - floor.CFrame.Position.Z) < f.hz + 5 then
				if r.top > top + 1 and r.bottom < top + 6 and r.hx < 30 and r.hz < 30 then table.insert(things, { r = r, part = d }) end
			end
		end
	end
	local spawnPart
	for _, d in ws:GetDescendants() do
		if d:IsA("SpawnLocation") and (flat(d.CFrame.Position) - flat(spawn.centre)).Magnitude < 20 then spawnPart = d end
	end
	local names = {}
	for key in byName do table.insert(names, key) end
	table.sort(names)
	for i, a in names do
		local A = info[a]
		for j = i + 1, #names do
			local b = names[j]
			local B = info[b]
			local dist = (A.c - B.c).Magnitude
			local dir = (B.c - A.c).Unit
			local gap = dist - padReach(byName[a].pad, byName[a].at.Position, dir) - padReach(byName[b].pad, byName[b].at.Position, -dir)
			check("bigger: pads " .. a .. " and " .. b .. " apart", gap >= 0.5)
			check("bigger: props " .. a .. " and " .. b .. " turn clear of each other", dist >= A.swept + B.swept + 1)
		end
	end
	for key in grown do
		local A = info[key]
		local r = math.max(A.padR, A.swept)
		check("bigger: " .. key .. " turns on its pad", A.swept <= A.padR + 0.25)
		local clear = true
		for _, t in things do
			if math.abs(t.r.X - A.c.X) < t.r.hx + r + 1 and math.abs(t.r.Z - A.c.Z) < t.r.hz + r + 1 then
				clear = false
				print("  in the way of " .. key .. ": " .. t.part:GetFullName())
			end
		end
		check("bigger: nothing on the plaza in the way of " .. key .. " (the tree)", clear)
		local sp = spawnPart and math.max(spawnPart.Size.X, spawnPart.Size.Z) / 2 or 3
		check("bigger: " .. key .. " clear of the spawn pad", (A.c - flat(spawn.centre)).Magnitude > r + sp + 4)
		for _, st in stands do
			check("bigger: " .. key .. " clear of the stands", (flat(st.at.Position) - A.c).Magnitude > r + 4)
		end
		local l = floor.CFrame:PointToObjectSpace(roblox.Vector3.new(A.c.X, top, A.c.Z))
		check("bigger: " .. key .. " on the plaza", math.abs(l.X) + r <= f.hx and math.abs(l.Z) + r <= f.hz)
		-- its title: nothing over the plaza (the tree's branches and leaves) where its letters are, nor 3 studs either side
		local row = (byName.Witch_Brew_Cauldron.at.Position - byName.Pumpkin_Patch_Chest.at.Position)
		row = flat(row).Unit
		local acrossRow = roblox.Vector3.new(-row.Z, 0, row.X)
		local free = true
		for _, d in ws:GetDescendants() do
			if d:IsA("BasePart") and not d:IsA("Terrain") and d ~= floor and d.Transparency < 1 then
				local q = d.CFrame.Position
				if (flat(q) - A.c).Magnitude < 40 then
					local r2 = Layout.facts(d)
					local rel = flat(q) - A.c
					local hA = math.abs(row.X) * r2.hx + math.abs(row.Z) * r2.hz
					local hC = math.abs(acrossRow.X) * r2.hx + math.abs(acrossRow.Z) * r2.hz
					if r2.bottom < A.tHi and r2.top > A.tLo and math.abs(rel:Dot(row)) < hA + A.halfText + 0.3
						and math.abs(rel:Dot(acrossRow)) < hC + 3 then -- (3: a branch just in front of the letters covers them too)
						free = false
						print("  over " .. key .. "'s title: " .. d:GetFullName())
					end
				end
			end
		end
		check("bigger: " .. key .. "'s title clear of the tree's leaves", free)
		for other, B in info do
			if other ~= key and B.tLo < A.tHi and B.tHi > A.tLo then
				local d = math.abs((B.c - A.c):Dot(row))
				check("bigger: titles " .. key .. " and " .. other .. " side by side, not over each other", d >= A.halfText + B.halfText + 0.3)
			end
		end
	end
end

-- Props saved before their Grow (critic, Oct 20: LobbyPropService only grew them when the place had no
-- HuzzLobbyProps, so a place saved earlier kept the small Halloween stands): his place with the five props built the
-- old way (no Grow, WITCH'S BREW at Scale 2.5, SWEETS & TREATS at 2.3, a Title he typed on one), then
-- LobbyPropBuild.growSaved as the game runs it: the two stands grown (his pad, the prop's pad, Scale), his typed
-- Title kept, the other three props untouched, and a second run changes nothing.
do
	local luau = require("@lune/luau")
	local Build = require("../src/ReplicatedStorage/Shared/LobbyPropBuild")
	local Shapes = require("../src/ServerScriptService/HuzzServer/LobbyPropShapes")
	local env = setmetatable({ Color3 = roblox.Color3 }, { __index = _G })
	local Props = luau.load(fs.readFile("src/ReplicatedStorage/Shared/Config/LobbyProps.lua"), { debugName = "LobbyProps", environment = env })()
	local ws2 = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl")):GetService("Workspace")
	local floor2 = Layout.main(ws2)
	local bapi = Build.api(roblox)
	local old = table.clone(Props)
	old.Props = {}
	for key, cfg in Props.Props do
		local c = table.clone(cfg)
		if c.Grow then c.Scale, c.Grow = c.Scale / c.Grow, nil end
		old.Props[key] = c
	end
	old.Props.Witch_Brew_Cauldron.Title = "BREW!" -- (one he typed)
	local folder = roblox.Instance.new("Folder")
	folder.Name = Props.Folder
	folder.Parent = ws2
	local hisPad = {}
	for _, s in Layout.propSpots(api, ws2, floor2, Props.ThreePads, Props.TwoPads) do
		local lp = Build.make(bapi, s, old, Shapes[s.Prop], nil, "")
		lp.Parent = folder
		hisPad[s.Prop] = { part = s.pad:FindFirstChildWhichIsA("BasePart", true), size = s.pad:FindFirstChildWhichIsA("BasePart", true).Size }
	end
	local before = {}
	for _, lp in folder:GetChildren() do
		before[lp:GetAttribute("Prop")] = { lp = lp, pivot = lp:FindFirstChild("Prop"):FindFirstChild("Root").CFrame, scale = lp:GetAttribute("Scale") }
	end
	local spots2 = Layout.propSpots(api, ws2, floor2, Props.ThreePads, Props.TwoPads)
	check("saved props: his five pads still found with the props on them", #spots2 == 5)
	local ok, grown = pcall(Build.growSaved, bapi, spots2, folder, Props, Shapes, nil, "")
	check("saved props: growSaved runs (" .. tostring(if ok then #grown else grown) .. ")", ok)
	grown = if ok then grown else {}
	local got = {}
	for _, g in grown do got[g.Prop] = g end
	check("saved props: WITCH'S BREW and SWEETS & TREATS grown, nothing else", #grown == 2 and got.Witch_Brew_Cauldron ~= nil and got.Sweets_Treats_Coffin ~= nil)
	local now = {}
	for _, lp in folder:GetChildren() do now[lp:GetAttribute("Prop")] = lp end
	check("saved props: still five", #folder:GetChildren() == 5)
	for key, want in { Witch_Brew_Cauldron = 3.75, Sweets_Treats_Coffin = 3.45 } do
		local lp = now[key]
		local pad = lp and lp:FindFirstChild("Pad")
		check("saved props: " .. key .. " at Config's Scale " .. want, lp ~= nil and math.abs(lp:GetAttribute("Scale") - want) < 1e-3 and lp:GetAttribute("Grow") == 1.5)
		check("saved props: " .. key .. "'s glow pad 1.5x", pad ~= nil and math.abs(pad.Size.X - 9) < 1e-3)
		check("saved props: " .. key .. "'s pad (his) 1.5x", (hisPad[key].part.Size - hisPad[key].size * 1.5).Magnitude < 0.01)
	end
	check("saved props: the Title he typed kept", now.Witch_Brew_Cauldron and now.Witch_Brew_Cauldron:GetAttribute("Title") == "BREW!")
	for _, key in { "Shop_Stall", "Like_Reward_Gift", "Pumpkin_Patch_Chest" } do
		local lp = now[key]
		check("saved props: " .. key .. " untouched (same prop, place, Scale, pad)", lp == before[key].lp
			and (lp:FindFirstChild("Prop"):FindFirstChild("Root").CFrame.Position - before[key].pivot.Position).Magnitude < 1e-4
			and lp:GetAttribute("Scale") == before[key].scale and (hisPad[key].part.Size - hisPad[key].size).Magnitude < 1e-4)
	end
	local again = Build.growSaved(bapi, Layout.propSpots(api, ws2, floor2, Props.ThreePads, Props.TwoPads), folder, Props, Shapes, nil, "")
	check("saved props: a second start grows nothing more", #again == 0
		and (hisPad.Witch_Brew_Cauldron.part.Size - hisPad.Witch_Brew_Cauldron.size * 1.5).Magnitude < 0.01)
	if show then
		for _, g in grown do print(string.format("  saved %s grown %.2gx, Scale %.3g, moved %.2f", g.Prop, g.Grow, g.Scale, g.Shift)) end
	end
end

print(string.format("LobbyLayout: %d ok, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
