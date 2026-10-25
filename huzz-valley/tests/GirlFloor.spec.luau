--[[
	The won girl stands on the floor (owner, Oct 20 15:13: "make the girls always be on the floor after the game is
	won. make it for all of them"; his screenshot design/owner-oct20/1513-girl-floating-after-win.png: after
	CATCHERS WIN, Shaula stood in the air at head height behind the catcher).
	After the win she walks beside her winner (HuzzServer/RoundService: a runner's girl stops being carried
	too; tools/sim/round_sim.luau checks it every game) and each screen puts her feet on the ground under her
	(HuzzClient/Gameplay/CarryAnimator + Shared/FollowMotion). Her ground ray looked through characters and girls only,
	so it landed on the maps' zone boxes (ZoneA, ZoneB, Middle: invisible markers, CanCollide off, CanQuery on).
	On the owner's real place (places/HUSSANIME.rbxl) this checks:
	  - every girl (his R6 girls and C.C.'s R15): the height the server measures from her body (GirlService
	    .bodyBounds, her root above her lowest limb) is where her feet really are, within 0.1 stud;
	  - every map's zone footprints: the old ray (every part with CanQuery on, as a plain Roblox ray) lands up to
	    several studs over the floor; the ray she uses now (RespectCanCollide, as the companion's) lands on it;
	  - Shared/FollowMotion run for 3 s from the air (stolen off a runner's head) at each spot with the new ray: her
	    feet end within 0.1 stud of the floor, every girl's height;
	  - CarryAnimator's follower ray and Auras' companion ray both respect CanCollide.
	Run from huzz-valley/: lune run tests/GirlFloor.spec.luau
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local Geometry = require("../tools/world/geometry")
local Env = require("../tools/preview/motion3d/env")
local FollowMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/FollowMotion.lua")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

-- 1) the rays
local carry = fs.readFile("src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/CarryAnimator.lua")
local auras = fs.readFile("src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Auras.lua")
check("CarryAnimator: the follower's ground ray respects CanCollide (zone boxes aren't floor)",
	string.find(carry, "rayParams.RespectCanCollide = true", 1, true) ~= nil)
check("Auras: the companion's ground ray respects CanCollide", string.find(auras, "rayParams.RespectCanCollide = true", 1, true) ~= nil)

local place = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local ws = place:GetService("Workspace")

-- 2) every girl: the server's height for her root (GirlService.bodyBounds) against her real feet
local function bottomOf(p)
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position.Y - (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2
end
local FEET = { LeftFoot = true, RightFoot = true, ["Left Leg"] = true, ["Right Leg"] = true }
local girls, kinds, worstGirl = {}, {}, 0
local function collect(f)
	for _, c in f:GetChildren() do
		if c:IsA("Model") and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChildOfClass("Humanoid")) then
			table.insert(girls, c)
		elseif c:IsA("Folder") or c:IsA("Model") then
			collect(c)
		end
	end
end
collect(assert(ws:FindFirstChild("ANIME GIRLS"), "his ANIME GIRLS folder"))
local heights = {}
for _, m in girls do
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	local body, feet = math.huge, math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			if d.Transparency < 1 and not d:FindFirstAncestorWhichIsA("Accoutrement") then body = math.min(body, bottomOf(d)) end
			if FEET[d.Name] then feet = math.min(feet, bottomOf(d)) end
		end
	end
	local y = root.CFrame.Position.Y
	kinds[if m:FindFirstChild("UpperTorso") then "R15" else "R6"] = true
	worstGirl = math.max(worstGirl, math.abs((y - body) - (y - feet)))
	heights[string.format("%.2f", y - body)] = y - body
end
check(string.format("%d girls (R6 and R15): the server's root height is where her feet are (worst %.3f studs off)", #girls, worstGirl),
	#girls >= 30 and kinds.R6 and kinds.R15 and worstGirl <= 0.1)

-- 3) every map's zone footprints: old ray against new
local function zoneMarker(p)
	local k = (string.gsub(p.Name, "[%s_%-]", "")):lower()
	return k == "zonea" or k == "zoneb" or k == "middle"
end
local zones = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and zoneMarker(d) then
		d.CanCollide = false -- (HuzzServer/MapService.prepare: zones are markers, not solid)
		table.insert(zones, d)
	end
end
local geo = Geometry.new(ws, { skip = function(p) return string.sub(p.Name, 1, 4) == "Huzz" end })
local spots, worstOld, overOld, landedOn = {}, 0, 0, {}
for _, z in zones do
	for i = -2, 2 do
		for j = -2, 2 do
			local p = z.CFrame:PointToWorldSpace(Vector3.new(i / 2.5 * z.Size.X / 2, z.Size.Y / 2, j / 2.5 * z.Size.Z / 2))
			local top = p.Y + 6
			local floor = geo.floor(p.X, p.Z, top, top - 80) -- (RespectCanCollide: the first solid part)
			if floor then
				-- the old ray, from where the game starts it (6 studs over the catcher's root, him standing there): any
				-- CanQuery part (a ray starting inside a box doesn't hit that box, as in Roblox)
				local from = floor + 3 + 6
				local d, hitPart = geo.ray(Vector3.new(p.X, from, p.Z), Vector3.new(0, -80, 0), true)
				local old = d and (from - d) or floor
				worstOld = math.max(worstOld, old - floor)
				if old - floor > 0.1 then
					overOld += 1
					local n = hitPart and hitPart.Name or "?"
					landedOn[n] = (landedOn[n] or 0) + 1
				end
				table.insert(spots, { at = Vector3.new(p.X, floor, p.Z), zone = z:GetFullName() })
			end
		end
	end
end
print(string.format("  %d zone boxes, %d spots on their floors; the old ray stood her over the floor at %d of them, up to %.1f studs",
	#zones, #spots, overOld, worstOld))
local names = {}
for n, k in landedOn do table.insert(names, `{n} {k}`) end
table.sort(names)
print("  the old ray landed on: " .. table.concat(names, ", "))
check("his maps have zone boxes and floors under them", #zones >= 6 and #spots >= 100)
check("the old ray (CanQuery) lands on zone boxes: why she floated", overOld > 0 and worstOld > 1)

-- 4) FollowMotion with the new ray: she drops from the air and her feet end on the floor, at every spot
local function groundAt(pos, above)
	local top = math.max(pos.Y, above) + 6
	return (geo.floor(pos.X, pos.Z, top, top - 80))
end
local Carry = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Carry.lua")
local worstFeet, bad = 0, 0
for _, s in spots do
	for key, h in heights do
		local leader = CFrame.new(s.at + Vector3.new(0, 3, 0)) -- (the catcher standing there)
		local spot = (leader * CFrame.new(Carry.Follow.Offset)).Position
		local floor = groundAt(spot, leader.Position.Y)
		if floor then
			local rec = FollowMotion.new({ root = { CFrame = CFrame.identity }, motors = {}, from = s.at + Vector3.new(0, 7, 0), rootHeight = h, seed = 3 })
			for _ = 1, 180 do
				FollowMotion.step(rec, 1 / 60, 0, leader, function(p) return groundAt(p, leader.Position.Y) end, nil)
			end
			local feetY = rec.root.CFrame.Position.Y - h
			local under = groundAt(rec.root.CFrame.Position, leader.Position.Y) or floor
			-- (Oct 25: past an edge, a floor more than 10 studs under the catcher's feet doesn't count: she stays level
			-- with his feet instead of dropping off the map: Shared/FollowMotion MAX_DROP)
			if under < s.at.Y - 10 then under = s.at.Y end
			local off = math.abs(feetY - under)
			worstFeet = math.max(worstFeet, off)
			if off > 0.1 then bad += 1 end
		end
	end
end
check(string.format("after the win, every girl's feet on the floor (or level with his, past an edge) at every spot (worst %.3f studs, %d off)", worstFeet, bad), bad == 0 and worstFeet <= 0.1)

-- 5) off the map's edge (owner, Oct 25 13:03: "make the anime girls not fall off the map"): the only floor under her
-- is far below (the map under the lobby), or none at all. She stays level with the catcher's feet.
do
	local leader = CFrame.new(0, 103, 0) -- (his feet at 100)
	local worst = 0
	for _, under in { 0, 50, 88 } do
		local rec = FollowMotion.new({ root = { CFrame = CFrame.identity }, motors = {}, from = Vector3.new(0, 104, 0), rootHeight = 2, seed = 3 })
		for _ = 1, 180 do
			FollowMotion.step(rec, 1 / 60, 0, leader, function() return under end, nil)
		end
		worst = math.max(worst, math.abs(rec.root.CFrame.Position.Y - 2 - 100))
	end
	local rec = FollowMotion.new({ root = { CFrame = CFrame.identity }, motors = {}, from = Vector3.new(0, 104, 0), rootHeight = 2, seed = 3 })
	for _ = 1, 180 do
		FollowMotion.step(rec, 1 / 60, 0, leader, function() return nil end, nil)
	end
	worst = math.max(worst, math.abs(rec.root.CFrame.Position.Y - 2 - 100))
	check(string.format("past an edge (floor 12+ studs down, or none) she stays level with his feet (worst %.3f studs)", worst), worst <= 0.1)
end

print(string.format("GirlFloor: %d passed, %d failed", passed, failed))
if failed > 0 then error("GirlFloor spec failed") end
