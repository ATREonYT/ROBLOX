--[[
	The Secret cutscene's camera on each of the owner's maps (owner, Oct 19: "fix the secret girl animations in
	different maps, they are sometimes very off with the camera angle"; "its still choppy sometimes"). On his real
	place (places/HUSSANIME.rbxl, each map where he built it, beside its own lobby copy), with tools/world/geometry
	standing in for Roblox's rays (meshes as their boxes, no terrain):
	  before: the shot looked from the lobby (where everyone stands), and a ray each frame snapped the camera in front of
	          whatever was in the way (see-through zone boxes too), easing back out at 5 per second;
	  after:  Gameplay/SecretReveal's plan: the clearest of 16 sides (Shared/SecretReveal.pickDirection), pulled in ahead
	          of time (planReach / reachAt) with a wider lens (wideFov).
	Prints per map: the side picked, how far in the camera came and its biggest move in one frame (30 fps), before and
	after. Then films, per map, the moment the old camera was pulled in furthest, before and after (2 frames a map)
	for docs/previews/secret-maps.jpg (secret_maps_sheet.py).
	From the repo root:  sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/secret_maps_scene.luau out.mp4
	(NUMBERS=1: print the numbers only, no film)
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local Geometry = require("../../world/geometry")
local Scene = require("./scene")

local function load(path, name)
	local env = setmetatable({ Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3 }, { __index = _G })
	return luau.load(fs.readFile(path), { debugName = name, environment = env })()
end
local SRC = "huzz-valley/src/ReplicatedStorage/Shared/"
local T = load(SRC .. "SecretReveal.lua", "SecretReveal")
local Round = load(SRC .. "Config/Round.lua", "Round")
local Carry = load(SRC .. "Config/Carry.lua", "Carry")
local numbersOnly = process.env.NUMBERS == "1"

local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HUSSANIME.rbxl"))
local ws = place:GetService("Workspace")

local function key(n) return (string.gsub(n, "[%s_%-]", "")):lower() end
local maps = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and key(d.Name) == "middle" then
		local box = d.Parent
		while box and box.Parent ~= ws and not (box.Parent and box.Parent.Name == "Maps") do box = box.Parent end
		if box and box.Name:find("_Map") then
			table.insert(maps, { name = box.Name, box = box, middle = d })
		end
	end
end
table.sort(maps, function(a, b) return a.name < b.name end)
local spawns = {}
for _, d in ws:GetDescendants() do
	if d.ClassName == "SpawnLocation" then table.insert(spawns, d.CFrame.Position) end
end

local geo = Geometry.new(ws, { skip = function(p)
	-- (the girls in his ANIME GIRLS folder aren't in the game's world)
	return p:FindFirstAncestor("ANIME GIRLS") ~= nil
end })

local k = (Round.Showcase.Scale or 3) / 3
local mid = Carry.GirlLength * (Round.Showcase.Scale or 3) / 2
local TOP = Round.Showcase.Height
local FR = 1 / 30
local times, dirs = T.sampleTimes(), T.directions()

local scene = Scene.new()
local shots = {}
for _, m in maps do
	local c = m.middle.CFrame.Position
	local top = c.Y + m.middle.Size.Y / 2 + 6
	local floorY = geo.floor(c.X, c.Z, top, top - 80) or (c.Y - m.middle.Size.Y / 2)
	local ground = Vector3.new(c.X, floorY, c.Z)
	-- where everyone stands: the lobby copy he built this map beside
	local lobby, best = nil, math.huge
	for _, s in spawns do
		local d = (s - c).Magnitude
		if d < best then lobby, best = s, d end
	end
	local from = (lobby or (c + Vector3.new(0, 0, 50))) - ground
	local prefer = Vector3.new(from.X, 0, from.Z).Unit

	local function eyeAt(t, d)
		local eye, look = T.camera(math.min(t, T.LENGTH), ground + Vector3.new(0, 0.5, 0), d, T.height(t, TOP) or TOP, k, mid)
		return Vector3.new(eye.X, math.max(eye.Y, ground.Y + 1.5), eye.Z), look
	end
	local function reachOf(eye, look, hidden)
		local v = eye - look
		local hit = geo.ray(look, v, hidden)
		if hit then return math.clamp((hit - 1) / v.Magnitude, 0.05, 1) end
		return 1
	end

	-- before: from the lobby, a ray every frame (see-through parts too), snapped in, eased out at 5/s
	local old = { low = 1, jump = 0, pulled = 0, worstT = 0 }
	local reach, pe = 1, nil
	for i = 0, math.floor(T.RETURN * 30) do
		local t = i * FR
		local eye, look = eyeAt(t, prefer)
		local want = reachOf(eye, look, true)
		local cut = false
		for _, cc in T.CUTS do if t - FR < cc and t >= cc then cut = true end end
		if cut then reach = want end
		reach = if want < reach then want else reach + (want - reach) * math.min(1, FR * 5)
		local e = look + (eye - look) * reach
		if reach < old.low then old.low, old.worstT = reach, t end
		if reach < 0.6 then old.pulled += FR end
		if pe and not cut then old.jump = math.max(old.jump, (e - pe).Magnitude) end
		pe = e
	end

	-- after: the clearest side, planned once
	local reaches = {}
	for i, d in dirs do
		reaches[i] = {}
		for j, t in times do reaches[i][j] = reachOf(eyeAt(t, d)) end
	end
	local pick = T.pickDirection(dirs, reaches, prefer)
	local dir = dirs[pick]
	local plan = T.planReach(times, reaches[pick])
	local new = { low = 1, jump = 0, pulled = 0, fov = 0 }
	pe = nil
	for i = 0, math.floor(T.RETURN * 30) do
		local t = i * FR
		local eye, look = eyeAt(t, dir)
		local r = T.reachAt(times, plan, t)
		local e = look + (eye - look) * r
		local cut = false
		for _, cc in T.CUTS do if t - FR < cc and t >= cc then cut = true end end
		new.low = math.min(new.low, r)
		if r < 0.6 then new.pulled += FR end
		new.fov = math.max(new.fov, T.wideFov(T.fov(t, false), r))
		if pe and not cut then new.jump = math.max(new.jump, (e - pe).Magnitude) end
		pe = e
	end
	local turn = math.deg(math.acos(math.clamp(dir:Dot(prefer), -1, 1)))
	print(string.format("%-15s before: from the lobby, pulled in to %3d%% (%.1f s under 60%%), biggest jump %4.1f studs a frame | after: %3.0f deg round from the lobby side, in to %3d%% (%.1f s under 60%%), biggest move %.1f studs a frame, lens up to %.0f deg",
		m.name, math.floor(old.low * 100), old.pulled, old.jump, turn, math.floor(new.low * 100), new.pulled, new.jump, new.fov))

	-- the film: the moment the old camera was pulled in furthest (else her name), before and after
	local t = if old.low < 0.95 then old.worstT else 5.2
	do
		local eye, look = eyeAt(t, prefer)
		local _, part = geo.ray(look, eye - look, true)
		if part then
			print(string.format("    before, at %.1f s the camera was stopped by %s (%s, see-through %s)", t, part:GetFullName(), part.ClassName, tostring(part.Transparency >= 0.9)))
		end
	end
	local eyeO, lookO = eyeAt(t, prefer)
	local rO = reachOf(eyeO, lookO, true)
	local eyeN, lookN = eyeAt(t, dir)
	local rN = T.reachAt(times, plan, t)
	table.insert(shots, { map = m, ground = ground, t = t,
		{ dir = prefer, eye = lookO + (eyeO - lookO) * rO, look = lookO, fov = T.fov(t, false), label = "before" },
		{ dir = dir, eye = lookN + (eyeN - lookN) * rN, look = lookN, fov = T.wideFov(T.fov(t, false), rN), label = "after" } })
end
if numbersOnly then return end

-- His map near the spot as boxes (within 160 studs), and a pink stand-in girl at her 3x size where she is at t.
local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
for _, s in shots do
	local frameBoxes = {}
	for _, rec in geo.parts do
		local p = rec.part
		local pos = p.CFrame.Position
		if rec.visible and (pos - s.ground).Magnitude < 160 and p.Size.Magnitude < 600 then
			table.insert(frameBoxes, scene:addBox(p.CFrame, p.Size, hex(p.Color)))
		end
	end
	for _, view in { s[1], s[2] } do
		local h = (T.height(s.t, TOP) or TOP) * k
		local face = CFrame.lookAt(Vector3.zero, view.dir).Rotation
		local base = CFrame.new(s.ground + Vector3.new(0, h, 0)) * face
		local girl = {}
		local f = Carry.GirlLength * (Round.Showcase.Scale or 3) / 5.25 -- (a 5.25-stud R6 body at her showcase size)
		for _, b in {
			{ Vector3.new(-0.5, 1, 0), Vector3.new(0.9, 2, 0.9), "#f0c8d8" }, { Vector3.new(0.5, 1, 0), Vector3.new(0.9, 2, 0.9), "#f0c8d8" },
			{ Vector3.new(0, 3, 0), Vector3.new(2, 2, 1), "#ff7ab0" }, { Vector3.new(-1.5, 3, 0), Vector3.new(0.9, 2, 0.9), "#ffd9c4" },
			{ Vector3.new(1.5, 3, 0), Vector3.new(0.9, 2, 0.9), "#ffd9c4" }, { Vector3.new(0, 4.6, 0), Vector3.new(1.2, 1.2, 1.2), "#ffd9c4" },
			{ Vector3.new(0, 4.9, 0.25), Vector3.new(1.5, 1.4, 1.1), "#7be0a0" },
		} do
			table.insert(girl, scene:addBox(base * CFrame.new(b[1] * f), b[2] * f, b[3]))
		end
		scene:frame(view.eye, view.look, { fov = view.fov, caption = string.format("%s  %s  %.1f s", s.map.name, view.label, s.t) })
		for _, b in girl do b.Hidden = true end
	end
	for _, b in frameBoxes do b.Hidden = true end
end
scene:save(nil, 1, 960, 540, { sky = "#9fc4e8", ground = "#5d7a4a", grid = false })
