-- The lobby leaderboards turning to you, in his real lobby (lobby copy 1 of places/HuzzValley-yours.rbxl: the boards
-- where the place build saved them, his podiums, terrace and the slope behind it), for the Oct 19 re-check (owner:
-- "please check the leaderboards over again"; earlier "make it follow me in real time, not adjust after i move").
-- The turn is the game's own maths (Shared/LeaderboardRules aimSmooth + turn with Config/Leaderboards, the room each
-- way measured against his parts the way Gameplay/Leaderboards does with GetPartsInPart). A red body walks this path:
--   0-1.5 s at the spawn; 1.5-5 s runs across the plaza to the podium boards (16 -> 28 studs/s); 5-7 s two husses
--   (12 studs sideways in 0.3 s each way, like Gameplay/Dash); 7-10 s runs to the MOST CATCHES terrace board and
--   round its side (past its room on the slope side, then past 120 degrees round); 10-10.5 s no body (respawning);
--   10.5-13 s back at the spawn.
-- Each board's face shows white bars for its rows (the preview can't draw text) and a label with its turn in degrees.
-- It also prints, for 30 and 60 fps, the biggest turn in one frame and how often a board turned back on itself.
-- sh video.sh board_turn_scene.luau out.mp4    (from huzz-valley/tools/preview/motion3d)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Rules = Env.load(SHARED .. "LeaderboardRules.lua")
local Config = Env.load(SHARED .. "Config/Leaderboards.lua")
local Layout = Env.load(SHARED .. "LobbyLayout.lua")

local game = roblox.deserializePlace(fs.readFile(Env.root .. "/huzz-valley/places/HuzzValley-yours.rbxl"))
local ws = game:GetService("Workspace")
local floor = Layout.floors(ws)[1]
local fc = floor.CFrame
local FX, FZ = fc.Position.X, fc.Position.Z

local boards = {}
for _, m in ws.HuzzLeaderboards:GetDescendants() do
	if m:IsA("Model") and m:GetAttribute("Stat") then
		local b = m:FindFirstChild("Board")
		local p = b and b.CFrame.Position
		if p and math.abs(p.X - FX) < 120 and math.abs(p.Z - FZ) < 120 then
			table.insert(boards, { stat = m:GetAttribute("Stat"), cf = b.CFrame, base = m:FindFirstChild("Base"), size = b.Size })
		end
	end
end
local spawn
for _, d in ws:GetDescendants() do
	if d:IsA("SpawnLocation") then
		local l = fc:PointToObjectSpace(d.CFrame.Position)
		if math.abs(l.X) < floor.Size.X / 2 and math.abs(l.Z) < floor.Size.Z / 2 then spawn = d.CFrame.Position end
	end
end
assert(spawn and #boards == 5, "lobby 1: spawn and five boards")

-- his parts near the boards (drawn, and tested for the room each way) and the plaza floor
local function under(d, name)
	local p = d.Parent
	while p and p ~= ws do
		if p.Name == name then return true end
		p = p.Parent
	end
	return false
end
local scene = Scene.new()
local near = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.9 and not under(d, "HuzzLeaderboards")
		and not under(d, "HuzzAvatarStands") then
		local p = d.CFrame.Position
		for _, bd in boards do
			if (p - bd.cf.Position).Magnitude <= d.Size.Magnitude / 2 + 14 then
				table.insert(near, { part = d, cf = d.CFrame, inv = d.CFrame:Inverse(), s = d.Size, class = d.ClassName, pos = p, r = d.Size.Magnitude / 2 })
				local c = d.Color
				scene:addBox(d.CFrame, d.Size, string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)))
				break
			end
		end
	end
end
scene:addBox(floor.CFrame, floor.Size, "#5a2a26")
print(#near .. " of his parts near the boards")

local function inside(sol, p)
	local l = sol.inv * p
	local s = sol.s
	if math.abs(l.X) > s.X / 2 or math.abs(l.Y) > s.Y / 2 or math.abs(l.Z) > s.Z / 2 then return false end
	if sol.class == "WedgePart" then return (l.Y + s.Y / 2) / s.Y <= (l.Z + s.Z / 2) / s.Z + 1e-6 end
	return true
end

local SLATE, ROW = "#68768a", "#f2f4f8"
for _, bd in boards do
	local c = bd.cf.Position
	bd.centre = c
	bd.home = Rules.yawTo(0, 0, bd.cf.LookVector.X, bd.cf.LookVector.Z)
	bd.yaw = bd.home
	local mine = {}
	for _, sol in near do
		if (sol.pos - c).Magnitude <= sol.r + 13 and not (bd.base and sol.part == bd.base) then table.insert(mine, sol) end
	end
	bd.lo, bd.hi = Rules.room(bd.home, math.rad(Config.TurnMax), math.rad(Config.TurnStep), function(yaw)
		local cf = CFrame.new(c) * CFrame.Angles(0, yaw, 0)
		for i = 0, 14 do
			for j = 0, 18 do
				for k = 0, 1 do
					local p = cf * Vector3.new((i / 14 - 0.5) * (bd.size.X - 0.3), (j / 18 - 0.5) * (bd.size.Y - 0.3), (k - 0.5) * (bd.size.Z - 0.1))
					for _, sol in mine do
						if inside(sol, p) then return true end
					end
				end
			end
		end
		return false
	end)
	print(string.format("%-8s room %2.0f / %2.0f deg", bd.stat, math.deg(bd.lo), math.deg(bd.hi)))
	bd.slab = scene:addBox(bd.cf, bd.size, SLATE)
	bd.bars = {}
	table.insert(bd.bars, { box = scene:addBox(bd.cf, Vector3.new(9, 1, 0.1), ROW), at = CFrame.new(-1.8, bd.size.Y / 2 - 1.3, -bd.size.Z / 2 - 0.06) })
	for r = 0, 11 do
		local y = bd.size.Y / 2 - 3.2 - r * 1.3
		table.insert(bd.bars, { box = scene:addBox(bd.cf, Vector3.new(7.5, 0.55, 0.1), ROW), at = CFrame.new(-0.3, y, -bd.size.Z / 2 - 0.06) })
		table.insert(bd.bars, { box = scene:addBox(bd.cf, Vector3.new(0.9, 0.9, 0.1), "#c9ced8"), at = CFrame.new(bd.size.X / 2 - 1.2, y, -bd.size.Z / 2 - 0.06) })
	end
	bd.pumpkin = scene:addBox(bd.cf, Vector3.new(1.6, 1.6, 1.6), "#ec781c")
	bd.pumpkin.Shape = "ball"
end

-- the path
local girls = boards[1]
for _, bd in boards do if bd.stat == "Girls" then girls = bd end end
local catches = boards[1]
for _, bd in boards do if bd.stat == "Catches" then catches = bd end end
local gLook, gRight = girls.cf.LookVector, girls.cf.RightVector
local frontOfGirls = girls.centre + Vector3.new(gLook.X, 0, gLook.Z) * 24
local mid = spawn:Lerp(frontOfGirls, 0.5) + fc.LookVector * -0 + Vector3.new(0, 0, 0)
local cLook, cRight = catches.cf.LookVector, catches.cf.RightVector
local beforeCatches = catches.centre + Vector3.new(cLook.X, 0, cLook.Z) * 22
local sideCatches = catches.centre + Vector3.new(cRight.X, 0, cRight.Z) * -16 + Vector3.new(cLook.X, 0, cLook.Z) * 4
local behindCatches = catches.centre + Vector3.new(cRight.X, 0, cRight.Z) * -12 + Vector3.new(cLook.X, 0, cLook.Z) * -8
local function flat(v, y) return Vector3.new(v.X, y, v.Z) end
local Y = spawn.Y + 3
local function lerpPath(pts, u) -- u 0..1 along a polyline, by length
	local total, seg = 0, {}
	for i = 1, #pts - 1 do
		local l = (pts[i + 1] - pts[i]).Magnitude
		table.insert(seg, l)
		total += l
	end
	local want = u * total
	for i, l in seg do
		if want <= l or i == #seg then return pts[i]:Lerp(pts[i + 1], math.clamp(want / math.max(l, 1e-6), 0, 1)) end
		want -= l
	end
	return pts[#pts]
end
local function ease(t) return t * t * (3 - 2 * t) end
local function body(t: number): Vector3?
	if t < 1.5 then return flat(spawn, Y) end
	if t < 5 then return flat(lerpPath({ spawn, mid, frontOfGirls }, ease((t - 1.5) / 3.5)), Y) end
	if t < 7 then
		local base = flat(frontOfGirls, Y)
		local side = Vector3.new(gRight.X, 0, gRight.Z)
		local function huss(t0) return math.clamp((t - t0) / 0.3, 0, 1) end
		local s = 12 * (1 - (1 - huss(5.3)) ^ 2) - 12 * (1 - (1 - huss(6.2)) ^ 2)
		return base + side * s
	end
	if t < 10 then
		return flat(lerpPath({ frontOfGirls, beforeCatches, sideCatches, behindCatches }, ease((t - 7) / 3)), Y)
	end
	if t < 10.5 then return nil end
	return flat(spawn, Y)
end

local runner = scene:addBox(CFrame.new(spawn), Vector3.new(2, 5, 1), "#e0453a")
local head = scene:addBox(CFrame.new(spawn), Vector3.new(1.2, 1.2, 1.2), "#f1c9a5")
-- two cameras: on the podium boards (and you running up), then on MOST CATCHES while you go round it
local eyeA = girls.centre + Vector3.new(gLook.X, 0, gLook.Z) * 48 + Vector3.new(0, 16, 0)
local lookA = girls.centre - Vector3.new(0, 3, 0)
local eyeB = catches.centre + Vector3.new(cLook.X, 0, cLook.Z) * 34 + Vector3.new(cRight.X, 0, cRight.Z) * 10 + Vector3.new(0, 12, 0)
local lookB = catches.centre + Vector3.new(cRight.X, 0, cRight.Z) * -4 - Vector3.new(0, 3, 0)

-- the maths at 30 and 60 fps (the numbers), then the 30 fps film
local function run(fps, record)
	for _, bd in boards do bd.yaw = bd.home; bd.last = 0; bd.flips = 0; bd.most = 0 end
	local dt = 1 / fps
	for f = 0, math.floor(13 * fps) do
		local t = f * dt
		local at = body(t)
		for _, bd in boards do
			local c = bd.centre
			local want = if at then Rules.aimSmooth(bd.home, c.X, c.Z, at.X, at.Z, math.rad(Config.TurnMax), math.rad(Config.TurnBehind),
				Config.TurnRange, Config.TurnFade, bd.lo, bd.hi) else bd.yaw
			local before = bd.yaw
			bd.yaw = Rules.turn(bd.yaw, want, dt, Config.TurnRate, math.rad(Config.TurnSpeedMax))
			if math.abs(Rules.wrap(bd.yaw - before)) > bd.most then bd.mostAt = t end
			local step = Rules.wrap(bd.yaw - before)
			bd.most = math.max(bd.most, math.abs(step))
			if math.abs(step) > 1e-4 then
				if step * bd.last < 0 and math.abs(step) > math.rad(0.05) then bd.flips += 1 end
				bd.last = step
			end
		end
		if record then
			if at then
				runner.Hidden, head.Hidden = false, false
				runner.CFrame = CFrame.new(at)
				head.CFrame = CFrame.new(at + Vector3.new(0, 3.1, 0))
			else
				runner.Hidden, head.Hidden = true, true
			end
			local labels = {}
			for _, bd in boards do
				local cf = CFrame.new(bd.centre) * CFrame.Angles(0, bd.yaw, 0)
				bd.slab.CFrame = cf
				for _, b in bd.bars do b.box.CFrame = cf * b.at end
				bd.pumpkin.CFrame = cf * CFrame.new(-(bd.size.X / 2 - 1.1), bd.size.Y / 2 + 0.7, 0)
				table.insert(labels, { p = { bd.centre.X, bd.centre.Y + bd.size.Y / 2 + 3, bd.centre.Z }, text = string.format("%s %+.0f", string.upper(bd.stat), math.deg(Rules.wrap(bd.yaw - bd.home))), h = 1.4, c = "#ffffff", o = "#000000" })
			end
			local phase = if t < 1.5 then "at the spawn" elseif t < 5 then "running to the podium boards" elseif t < 7 then "two husses sideways"
				elseif t < 10 then "to MOST CATCHES and round its side" elseif t < 10.5 then "respawning (no body): boards hold" else "back at the spawn"
			local onB = t >= 7.6 and t < 10.5
			scene:frame(if onB then eyeB else eyeA, if onB then lookB else lookA, { caption = string.format("Leaderboards turning to you (game maths)  t = %.1f s  %s", t, phase), labels = labels })
		end
	end
	local worst, flips = 0, 0
	for _, bd in boards do worst = math.max(worst, bd.most); flips += bd.flips end
	print(string.format("%d fps: biggest turn in one frame %.1f deg, %d turn-backs (a board reversing while you move one way)", fps, math.deg(worst), flips))
	for _, bd in boards do print(string.format("   %-8s biggest %.1f deg a frame (at %.2f s), %d turn-backs", bd.stat, math.deg(bd.most), bd.mostAt or 0, bd.flips)) end
end
run(60, false)
run(30, true)
scene:save(nil, 30, 1280, 720, { sky = "#87b8f0", ground = "#3c6e3a", grid = false })
