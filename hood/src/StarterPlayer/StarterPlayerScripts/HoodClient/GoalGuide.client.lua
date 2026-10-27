-- GoalGuide (Oct 27, the core loop: "make the core loop done well"): after the tutorial, a lasting and quiet guide to the
-- current goal, like the soldier game's: a chunky gold arrow bobbing over where to go (a lane, the next gate ahead of
-- you, the yellow pad, the ARMORY, the shoe boxes, the World 2 portal; Shared/GuideRules says which for the goal the
-- server publishes in GoalStep) and a trail of soft chevrons on the floor from just ahead of you to it, drifting on.
-- It stays out of the way: nothing during the tutorial (its own white arrows), while a window, a card, the unboxing or
-- the loading cover is up, in a fight, while you are down, or once you are there (GuideRules.Near; in the lane's box).
-- Local parts only (no collisions, no shadows, not hit by rays), one Heartbeat loop, each tick pcall'd and an error
-- reported once. Nothing flashes: the chevrons fade in and out over a second, the arrow only bobs.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local GoalRules = require(RS.Shared.GoalRules)
local GuideRules = require(RS.Shared.GuideRules)
local TutorialRules = require(RS.Shared.TutorialRules)
local ActiveMap = require(RS.Shared.ActiveMap)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local function attr(name) return player:GetAttribute(name) end
local function num(v) return type(v) == 'number' and v == v and v or 0 end

local GOLD, GOLD_TOP, INK = Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 236, 140), Color3.fromRGB(60, 34, 6)
local ARROW_UP = 7 -- (studs over the target's floor point: clear of the stations' own labels)
-- (the trail: up to 12 chevrons from 4 studs ahead of you to 4 short of the target, 3.2 apart, drifting on at 2 studs a
-- second; the far ones are clear of your own body in the camera behind you)
local TRAIL = { Count = 12, From = 4, Gap = 3.2, Speed = 2, Short = 4 }

---------------------------------------------------------------------------------------------- the parts
local folder = Instance.new('Folder')
folder.Name = 'HoodGoalGuide'
local function part(class, name, size, color)
	local p = Instance.new(class)
	p.Name = name
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	pcall(function() p.CanQuery, p.CanTouch = false, false end)
	p.Size, p.Color, p.Material = size, color, Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.Parent = folder
	return p
end
-- the arrow: a block shaft over a head of two wedges, pointing down, with a dark back plate a hair behind (its outline)
local arrow = {
	Shaft = part('Part', 'ArrowShaft', Vector3.new(1.3, 1.9, 0.5), GOLD),
	HeadL = part('WedgePart', 'ArrowHeadL', Vector3.new(0.5, 1.9, 1.6), GOLD),
	HeadR = part('WedgePart', 'ArrowHeadR', Vector3.new(0.5, 1.9, 1.6), GOLD),
	Cap = part('Part', 'ArrowCap', Vector3.new(1.3, 0.25, 0.52), GOLD_TOP),
	BackShaft = part('Part', 'ArrowBackShaft', Vector3.new(1.65, 2.2, 0.3), INK),
	BackL = part('WedgePart', 'ArrowBackL', Vector3.new(0.3, 2.35, 2.0), INK),
	BackR = part('WedgePart', 'ArrowBackR', Vector3.new(0.3, 2.35, 2.0), INK),
}
-- the chevrons: two flat bars each, a "^" pointing the way
local chevrons = {}
for i = 1, TRAIL.Count do
	chevrons[i] = {
		L = part('Part', 'ChevronL' .. i, Vector3.new(0.5, 0.06, 1.6), GOLD),
		R = part('Part', 'ChevronR' .. i, Vector3.new(0.5, 0.06, 1.6), GOLD),
	}
end
folder.Parent = workspace

local shownAlpha = -1
local function setArrowAlpha(a)
	a = math.floor(a * 20 + 0.5) / 20
	if a == shownAlpha then return end
	shownAlpha = a
	for name, p in arrow do
		p.Transparency = 1 - a * ((name:sub(1, 4) == 'Back') and 0.85 or 1)
	end
end
local UP = Vector3.new(0, 1, 0)
-- Lays the arrow with its tip at `tip`, its face turned to `face` (a flat unit vector toward the camera). A wedge's
-- right angle sits at its local (-Y, +Z) corner: each half of the head has it at the top of the centre line, local +Y
-- pointing down to the tip and local -Z out to its side.
local function wedge(pos, y, z) return CFrame.fromMatrix(pos, y:Cross(z), y, z) end
local function layArrow(tip, face)
	local right = UP:Cross(face).Unit
	local function box(pos) return CFrame.fromMatrix(pos, right, UP) end
	local headMid = tip + UP * 0.95
	arrow.HeadL.CFrame = wedge(headMid - right * 0.8, -UP, right)
	arrow.HeadR.CFrame = wedge(headMid + right * 0.8, -UP, -right)
	arrow.Shaft.CFrame = box(tip + UP * 2.85)
	arrow.Cap.CFrame = box(tip + UP * 3.92)
	local back = -face * 0.42
	arrow.BackShaft.CFrame = box(tip + UP * 2.85 + back)
	arrow.BackL.CFrame = wedge(headMid - UP * 0.075 - right * 1.0 + back, -UP, right)
	arrow.BackR.CFrame = wedge(headMid - UP * 0.075 + right * 1.0 + back, -UP, -right)
end
-- (Oct 27, flow: one guide at a time) PlayerGui HoodGoalGuide is true while this guide is up: the lobby's
-- "TRAIN xN HERE" pointer steps aside for it.
local up = nil
local function setUp(on)
	if up == on then return end
	up = on
	playerGui:SetAttribute('HoodGoalGuide', on)
end
local function hideAll()
	setArrowAlpha(0)
	for _, c in chevrons do c.L.Transparency, c.R.Transparency = 1, 1 end
	setUp(false)
end

---------------------------------------------------------------------------------------------- the floor
local rayParams = (function()
	local ok, r = pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { folder }
		pcall(function() p.RespectCanCollide = true end)
		return p
	end)
	return ok and r or nil
end)()
local function floorAt(p, feetY)
	if not rayParams then return feetY end
	local ok, hit = pcall(function()
		local list = { folder }
		if player.Character then table.insert(list, player.Character) end
		rayParams.FilterDescendantsInstances = list
		return workspace:Raycast(Vector3.new(p.X, feetY + 3, p.Z), Vector3.new(0, -8, 0), rayParams)
	end)
	if ok and hit and math.abs(hit.Position.Y - feetY) <= 2.5 then return hit.Position.Y end
	return feetY
end

---------------------------------------------------------------------------------------------- finding the target
local active
local function map() active = active or ActiveMap.get(); return active end
local function tagged(tag)
	local ok, list = pcall(function() return CollectionService:GetTagged(tag) end)
	local out, m = {}, map()
	for _, x in ok and list or {} do
		if not m or x:IsDescendantOf(m.Root) then table.insert(out, x) end
	end
	return out
end
local cache = {} -- [key] = { Value, At }: a thing found once and kept while it is in the game; a miss is retried every 2 s
local function lookup(key, find)
	local c = cache[key]
	local v = c and c.Value
	if v and v.Parent ~= nil then return v end
	if c and v == false and os.clock() - c.At < 2 then return nil end
	local ok, found = pcall(find)
	v = ok and found or nil
	cache[key] = { Value = v or false, At = os.clock() }
	return v
end
local function centreTop(p) return (p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position end
local function pivotOf(m)
	local ok, cf = pcall(function() return m:GetPivot() end)
	return ok and cf.Position or nil
end
-- A model's box (worked out once per key, again if the model is replaced: the stations don't move).
local boxes = {} -- [key] = { Model, CFrame, Size }
local function boxOf(m, key)
	local c = boxes[key]
	if c and c.Model == m then return c end
	local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
	if not ok then return nil end
	c = { Model = m, CFrame = cf, Size = size }
	boxes[key] = c
	return c
end
-- A small model (a shoe box): the arrow 2.5 studs over its top.
local function overTop(m, key)
	local b = boxOf(m, key)
	if not b then return pivotOf(m) end
	return Vector3.new(b.CFrame.Position.X, b.CFrame.Position.Y + b.Size.Y / 2 + 2.5 - ARROW_UP, b.CFrame.Position.Z)
end
-- A big station (the ARMORY, the portal): the floor point on its edge nearest you, where you walk up to it, so the
-- arrow stands at eye height in front of it, not high over its sign.
local function frontOf(m, key, you)
	local b = boxOf(m, key)
	if not b then return pivotOf(m) end
	local p = b.CFrame:PointToObjectSpace(you)
	local hx, hz = b.Size.X / 2, b.Size.Z / 2
	return b.CFrame:PointToWorldSpace(Vector3.new(math.clamp(p.X, -hx, hx), -b.Size.Y / 2, math.clamp(p.Z, -hz, hz)))
end

-- Returns the target's floor point and, for a lane, its box part (you are there when inside it).
local find = {}
function find.Lane(t)
	local zone = lookup('Lane' .. tostring(t.Station), function()
		local m = map()
		local lane = m and m.Root:FindFirstChild('Training_' .. tostring(t.Station), true)
		return lane and lane:FindFirstChild('TrainingZone', true)
	end)
	return zone and centreTop(zone) or nil, zone
end
function find.Gate(t, you)
	-- the next gate ahead of you (the street runs toward -Z in the map's frame) up to the goal's stage
	local m = map()
	local frame = m and m.Frame or CFrame.new()
	local youZ = frame:PointToObjectSpace(you).Z
	local best, bestZ
	for _, g in tagged('HoodStageGate') do
		local stage = g:GetAttribute('Stage')
		local line = g:GetAttribute('LineZ')
		if type(stage) == 'number' and stage <= (t.Stage or 1) and type(line) == 'number' and line < youZ - 1 and (not bestZ or line > bestZ) then
			best, bestZ = g, line
		end
	end
	if not best then return nil end
	local barrier = best:FindFirstChild('Barrier', true)
	local at = barrier and barrier:IsA('BasePart') and barrier.CFrame.Position or pivotOf(best)
	if not at then return nil end
	local floor = barrier and barrier:IsA('BasePart') and (barrier.CFrame.Position.Y - barrier.Size.Y / 2) or at.Y
	return Vector3.new(at.X, floor, at.Z)
end
function find.Pad(t, you)
	local best, bestD
	for _, x in tagged('HoodStagePad') do
		if x:IsA('BasePart') and x:GetAttribute('Kind') == 'Return' and x:GetAttribute('Stage') == t.Stage then
			local d = (x.CFrame.Position - you).Magnitude
			if not bestD or d < bestD then best, bestD = x, d end
		end
	end
	return best and centreTop(best) or nil
end
function find.Armory(_, you)
	local a = lookup('Armory', function() return tagged('HoodArmory')[1] end)
	return a and frontOf(a, 'Armory', you) or nil
end
function find.Boxes(_, you)
	local best, bestD
	for _, dais in tagged('HoodShoeBoxes') do
		for _, b in dais:GetChildren() do
			if b:IsA('Model') and b:GetAttribute('BoxId') then
				local at = overTop(b, 'Box:' .. tostring(b:GetAttribute('BoxId')))
				local d = at and (at - you).Magnitude
				if d and (not bestD or d < bestD) then best, bestD = at, d end
			end
		end
	end
	return best
end
function find.Portal(_, you)
	local p = lookup('Portal', function()
		local m = map()
		return m and m.Root:FindFirstChild('World2Portal', true)
	end)
	return p and frontOf(p, 'Portal', you) or nil
end

---------------------------------------------------------------------------------------------- when it shows
local function busy()
	local w, card = playerGui:GetAttribute('HoodWindow'), playerGui:GetAttribute('HoodCard')
	if (type(w) == 'string' and w ~= '') or (type(card) == 'string' and card ~= '') then return true end
	if playerGui:GetAttribute('Unboxing') == true or playerGui:FindFirstChild('HoodLoading') then return true end
	if TutorialRules.step(attr('OnboardingStep')) then return true end -- (the tutorial's own arrows)
	if playerGui:GetAttribute('HoodGuide') == 'Tutorial' or playerGui:GetAttribute('HoodWelcome') == true then return true end -- (Oct 27, flow)
	if num(attr('WaveLeft')) > 0 or attr('Downed') == true or attr('WorldBossFight') == true then return true end
	return false
end
local function inside(zone, p)
	local local_ = zone.CFrame:PointToObjectSpace(p)
	return math.abs(local_.X) <= zone.Size.X / 2 + 1 and math.abs(local_.Z) <= zone.Size.Z / 2 + 1
end

---------------------------------------------------------------------------------------------- every frame
local clock = 0
local warned = false
local function tick(dt)
	clock += dt
	local char = player.Character
	local root = char and char:FindFirstChild('HumanoidRootPart')
	local step = attr('GoalStep')
	if not root or type(step) ~= 'number' or busy() then hideAll(); return end
	local goal = GoalRules.at(step)
	local t = GuideRules.target(goal, { Rebirths = attr('Rebirths'), RunCleared = attr('RunCleared'), World = GoalRules.World })
	if not t or not find[t.Kind] then hideAll(); return end
	local you = root.CFrame.Position
	local at, zone = find[t.Kind](t, you)
	if not at then hideAll(); return end
	local flat = Vector3.new(at.X - you.X, 0, at.Z - you.Z)
	local dist = flat.Magnitude
	local there = (zone and inside(zone, you)) or (not zone and dist <= (GuideRules.Near[t.Kind] or 8))
	if there then hideAll(); return end
	-- the arrow: bobbing over the target, turned to the camera
	local cam = workspace.CurrentCamera
	local face = cam and (cam.CFrame.Position - at) or -flat
	face = Vector3.new(face.X, 0, face.Z)
	if face.Magnitude < 0.01 then face = Vector3.new(0, 0, 1) end
	local still = attr('ReducedMotion') == true
	local bob = still and 0 or 0.5 * math.sin(clock * 2 * math.pi / 1.3)
	layArrow(at + UP * (ARROW_UP + bob), face.Unit)
	setArrowAlpha(1)
	setUp(true)
	-- the trail: chevrons on the floor along the straight line to it, drifting on, fading in by you and out by it
	local feetY = you.Y - 3
	local dir = dist > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local right = dir:Cross(UP).Unit
	local shift = still and 0 or (clock * TRAIL.Speed) % TRAIL.Gap
	local stop = dist - TRAIL.Short
	for i, c in chevrons do
		local d = TRAIL.From + (i - 2) * TRAIL.Gap + shift -- (the first one is coming in from behind the start)
		local a = math.min((d - TRAIL.From) / TRAIL.Gap, (stop - d) / TRAIL.Gap, 1)
		a = math.clamp(a, 0, 1) * (0.85 - 0.3 * math.clamp(d / 40, 0, 1))
		if a <= 0.02 then
			c.L.Transparency, c.R.Transparency = 1, 1
		else
			local p = Vector3.new(you.X, 0, you.Z) + dir * d
			local y = floorAt(p, feetY) + 0.16 -- (clear of the floor's painted paths and tiles)
			local tip = Vector3.new(p.X, y, p.Z)
			for side, bar in { [1] = c.L, [-1] = c.R } do
				local arm = (-dir + right * side * 0.85).Unit
				local mid = tip + arm * 0.62
				bar.CFrame = CFrame.lookAt(mid, mid + arm)
				bar.Transparency = 1 - a
			end
		end
	end
end
hideAll()
RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(tick, math.clamp(type(dt) == 'number' and dt or 1 / 60, 0, 0.1))
	if not ok and not warned then
		warned = true
		warn('[GoalGuide] ' .. tostring(err))
	end
end)
