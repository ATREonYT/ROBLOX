-- Can every lobby leaderboard be read from where players stand, and does a board ever cut into the owner's build as
-- it turns? (owner, Oct 19: "please check the leaderboards over again"). For each lobby copy in a place file:
--   * from the spawn and from the plaza's middle (eye 5 studs up): distance, how far round from the board's front
--     you are before and after its turn (Config/Leaderboards TurnMax / TurnBehind / TurnRange), how much of the face
--     is hidden by his parts (rays to a 5 x 5 grid on the face), and how tall the title and a row's letters are on a
--     900 px tall window at Roblox's 70 degree field of view;
--   * how far it may turn each way before the slab (a hair smaller) cuts into his parts nearby (LeaderboardRules.room,
--     every TurnStep degrees; blocks, wedges, balls, cylinders; meshes as their boxes), as each screen measures it
--     in the game with GetPartsInPart, and what stops it.
-- Run from the repo root:  lune run huzz-valley/tools/world/board_sight.luau [place.rbxl]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Layout = require("../../src/ReplicatedStorage/Shared/LobbyLayout")
local Config = require("../../src/ReplicatedStorage/Shared/Config/Leaderboards")
local Rules = require("../../src/ReplicatedStorage/Shared/LeaderboardRules")
local Look = require("../../src/ReplicatedStorage/Shared/LeaderboardLook")

local placeFile = process.args[1] or "huzz-valley/places/HuzzValley-yours.rbxl"
local game = roblox.deserializePlace(fs.readFile(placeFile))
local ws = game:GetService("Workspace")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local WINDOW, FOV = 900, math.rad(70)
local CAP_TITLE = 33 / Look.Canvas.H * Config.Size.Y -- studs (cap 27 to 60 of 900)
local CAP_ROW = 29 / Look.Canvas.H * Config.Size.Y -- a row name below the top three
local function px(cap, d) return cap / (2 * d * math.tan(FOV / 2)) * WINDOW end

local function under(d, name)
	local p = d.Parent
	while p and p ~= ws do
		if p.Name == name then return true end
		p = p.Parent
	end
	return false
end

-- every visible solid-looking part (not ours: boards, stands, props are checked separately)
local solids = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.9
		and not under(d, "HuzzLeaderboards") and not under(d, "HuzzAvatarStands") then
		table.insert(solids, { part = d, cf = d.CFrame, s = d.Size, inv = d.CFrame:Inverse(), class = d.ClassName,
			shape = if d:IsA("Part") then d.Shape.Name else "Block", r = d.Size.Magnitude / 2, pos = d.CFrame.Position })
	end
end

local function inside(sol, p, grow)
	local l = sol.inv * p
	local s = sol.s
	local hx, hy, hz = s.X / 2 + grow, s.Y / 2 + grow, s.Z / 2 + grow
	if math.abs(l.X) > hx or math.abs(l.Y) > hy or math.abs(l.Z) > hz then return false end
	if sol.class == "WedgePart" then
		-- the slope rises from the front (-Z, height 0) to the back (+Z, full height)
		return (l.Y + s.Y / 2) / s.Y <= (l.Z + s.Z / 2) / s.Z + 1e-6
	elseif sol.shape == "Ball" then
		return l.Magnitude <= math.min(s.X, s.Y, s.Z) / 2 + grow
	elseif sol.shape == "Cylinder" then
		return math.sqrt(l.Y * l.Y + l.Z * l.Z) <= math.min(s.Y, s.Z) / 2 + grow
	end
	return true
end

-- does the segment a -> b pass through the part? (slab test on its box; wedges, balls and cylinders by sampling)
local function blocks(sol, a, b)
	local la, lb = sol.inv * a, sol.inv * b
	local d = lb - la
	local t0, t1 = 0, 1
	for _, ax in { "X", "Y", "Z" } do
		local h = sol.s[ax] / 2
		local o, v = la[ax], d[ax]
		if math.abs(v) < 1e-9 then
			if math.abs(o) > h then return false end
		else
			local ta, tb = (-h - o) / v, (h - o) / v
			if ta > tb then ta, tb = tb, ta end
			t0, t1 = math.max(t0, ta), math.min(t1, tb)
			if t0 > t1 then return false end
		end
	end
	if sol.class == "WedgePart" or sol.shape ~= "Block" then
		for i = 0, 8 do
			local t = t0 + (t1 - t0) * i / 8
			if inside(sol, a + (b - a) * t, 0) then return true end
		end
		return false
	end
	return true
end

local boards = {}
local holder = ws:FindFirstChild("HuzzLeaderboards")
assert(holder, "no Workspace.HuzzLeaderboards in " .. placeFile)
for _, m in holder:GetDescendants() do
	if m:IsA("Model") and m:GetAttribute("Stat") then
		local b = m:FindFirstChild("Board")
		if b then table.insert(boards, { model = m, part = b, stat = m:GetAttribute("Stat"), cf = b.CFrame, base = m:FindFirstChild("Base") }) end
	end
end

local spawns = {}
for _, d in ws:GetDescendants() do
	if d:IsA("SpawnLocation") then table.insert(spawns, d) end
end

local VERBOSE = process.args[2] == "why"
local blockers = {}
local floors = Layout.floors(ws)
print(string.format("%s: %d lobby floors, %d boards, %d spawns, %d parts", placeFile, #floors, #boards, #spawns, #solids))
local worstHidden, worstClip = 0, 0
for li, floor in floors do
	local fc, fs_ = floor.CFrame, floor.Size
	local top = fc.Position.Y + fs_.Y / 2
	local function onFloor(p, pad)
		local l = fc:PointToObjectSpace(p)
		return math.abs(l.X) <= fs_.X / 2 + pad and math.abs(l.Z) <= fs_.Z / 2 + pad
	end
	-- (the plaza's very middle is inside his girls' display, so the plaza views are 40 studs in front of and behind it)
	local views = {
		{ name = "plaza front", at = fc * Vector3.new(0, fs_.Y / 2 + 5, 40) },
		{ name = "plaza back", at = fc * Vector3.new(0, fs_.Y / 2 + 5, -40) },
	}
	for _, s in spawns do
		if onFloor(s.CFrame.Position, 2) then
			table.insert(views, { name = "spawn", at = s.CFrame.Position + Vector3.new(0, 5, 0) })
			table.insert(views, { name = "spawn +12", at = s.CFrame.Position + Vector3.new(0, 5, 12) })
			table.insert(views, { name = "spawn -12", at = s.CFrame.Position + Vector3.new(0, 5, -12) })
		end
	end
	print(string.format("\nlobby %d (floor %.0f, %.0f)", li, fc.Position.X, fc.Position.Z))
	for _, bd in boards do
		local c = bd.cf.Position
		if (Vector3.new(c.X, 0, c.Z) - Vector3.new(fc.Position.X, 0, fc.Position.Z)).Magnitude < 150 then
			local home = Rules.yawTo(0, 0, bd.cf.LookVector.X, bd.cf.LookVector.Z)
			-- how far it may turn each way before the slab cuts into his build (what each screen measures in the game)
			local near = {}
			for _, sol in solids do
				if (sol.pos - c).Magnitude <= sol.r + 13 and not (bd.base and sol.part == bd.base) then table.insert(near, sol) end
			end
			local hits = {}
			local function cutsAt(yaw)
				local cf = CFrame.new(c) * CFrame.Angles(0, yaw, 0)
				local any = false
				for i = 0, 14 do
					for j = 0, 18 do
						for k = 0, 1 do
							local p = cf * Vector3.new((i / 14 - 0.5) * (Config.Size.X - 0.3), (j / 18 - 0.5) * (Config.Size.Y - 0.3), (k - 0.5) * (Config.Size.Z - 0.1))
							for _, sol in near do
								if inside(sol, p, 0) then
									any = true
									hits[sol.part:GetFullName() .. (if sol.class == "MeshPart" or sol.class == "UnionOperation" then " (a mesh: its box)" else "")] = true
								end
							end
						end
					end
				end
				return any
			end
			local lo, hi = Rules.room(home, math.rad(Config.TurnMax), math.rad(Config.TurnStep), cutsAt)
			local line = string.format("  %-8s turns %2.0f / %2.0f deg", bd.stat, math.deg(lo), math.deg(hi))
			for _, v in views do
				local dx, dz = v.at.X - c.X, v.at.Z - c.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				local off = math.deg(math.abs(Rules.wrap(Rules.yawTo(c.X, c.Z, v.at.X, v.at.Z) - home)))
				local aim = Rules.aimSmooth(home, c.X, c.Z, v.at.X, v.at.Z, math.rad(Config.TurnMax), math.rad(Config.TurnBehind), Config.TurnRange, Config.TurnFade, lo, hi)
				local cf = CFrame.new(c) * CFrame.Angles(0, aim, 0)
				local after = math.deg(math.abs(Rules.wrap(Rules.yawTo(c.X, c.Z, v.at.X, v.at.Z) - aim)))
				local hidden, n = 0, 0
				for i = -2, 2 do
					for j = -2, 2 do
						local p = cf * Vector3.new(i * Config.Size.X / 5, j * Config.Size.Y / 5, -Config.Size.Z / 2 - 0.05)
						n += 1
						for _, sol in solids do
							if (sol.pos - (p + v.at) / 2).Magnitude <= sol.r + (p - v.at).Magnitude / 2 and blocks(sol, v.at, p) then
								hidden += 1
								local key = sol.part:GetFullName()
								blockers[key] = (blockers[key] or 0) + 1
								break
							end
						end
					end
				end
				local slant = math.cos(math.rad(math.min(after, 89)))
				worstHidden = math.max(worstHidden, hidden / n)
				line ..= string.format("\n      %-11s %3.0f studs, %3.0f deg round -> %2.0f after its turn, %3.0f%% hidden, title %.1f px, row %.1f px",
					v.name, dist, off, after, hidden / n * 100, px(CAP_TITLE, dist), px(CAP_ROW, dist))
			end
			print(line)
			if VERBOSE then
				for key, n in blockers do print(string.format("      in the way: %s (%d rays)", key, n)) end
			end
			table.clear(blockers)
			local stopped = {}
			for key in hits do table.insert(stopped, key) end
			if #stopped > 0 then
				worstClip += 1
				print("      stops short of: " .. table.concat(stopped, ", "))
			end
		end
	end
end
print(string.format("\nworst hidden %.0f%%, %d boards turn less than the full limit one way (they stop before his build)", worstHidden * 100, worstClip))
