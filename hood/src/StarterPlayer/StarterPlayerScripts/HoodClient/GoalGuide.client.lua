-- GoalGuide: the ONE guide arrow, from the first step of the tutorial to the last goal (Oct 28, the owner after playing
-- in Studio: "the arrow isn't good ... make the arrows float ... more cartoony"; research pattern 9: one colour, one
-- style, from spawn to the end of the first loop). Its look and its rules are Shared/GuideArrow:
--   * a chunky gold 3D arrow with a thick ink outline, a light cap and a soft shine, floating over where to go with an
--     eased bob and a gentle pulse, growing with the distance, kept clear of walls and ceilings, popping in with a
--     small overshoot when it has somewhere new to point;
--   * a trail of chunky gold chevrons (ink-edged) on the floor from a few studs ahead of you toward it, drifting on;
--   * the edge pointer: while the arrow is off screen, a round badge at the screen's edge with a gold chevron points
--     the way, bobbing toward it.
-- Where it points: while the tutorial runs, what HoodClient/Tutorial publishes (PlayerGui GuideAt, and GuideVia when a
-- lane or a wall is in the way of the straight line: the trail goes there first); after it, the current goal's place
-- (Shared/GuideRules for the goal the server publishes in GoalStep: a lane, the next gate ahead of you, the yellow pad,
-- the ARMORY, the shoe boxes, the World 2 portal).
-- It stays out of the way while a window, a card, the unboxing, the welcome or the loading cover is up, in a fight,
-- while you are down, and once you are there (GuideRules.Near; in the lane's box). Local parts only (no collisions, no
-- shadows, not hit by rays), one Heartbeat loop, each tick pcall'd and an error reported once. Nothing flashes.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local GoalRules = require(RS.Shared.GoalRules)
local GuideRules = require(RS.Shared.GuideRules)
local GuideArrow = require(RS.Shared.GuideArrow)
local TutorialRules = require(RS.Shared.TutorialRules)
local ActiveMap = require(RS.Shared.ActiveMap)
local Kit = require(RS.Shared.UIKit)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local function attr(name) return player:GetAttribute(name) end
local function num(v) return type(v) == 'number' and v == v and v or 0 end

local COL = GuideArrow.Colors
local UP = Vector3.new(0, 1, 0)
-- (the trail: up to 12 chevrons from 4 studs ahead of you to 4 short of its end, 3.4 apart, drifting on at 2 studs a
-- second; the far ones are clear of your own body in the camera behind you)
local TRAIL = { Count = 12, From = 4, Gap = 3.4, Speed = 2, Short = 4 }
local APPEAR = 0.35 -- seconds: the arrow's pop-in (0.45 -> a little over 1 -> 1)

---------------------------------------------------------------------------------------------- the parts
local folder = Instance.new('Model') -- (a Model, so its Highlight outlines the arrow)
folder.Name = 'HoodGoalGuide'
local arrow = GuideArrow.build(folder)
local trail = Instance.new('Model') -- (the chevrons: their own ink, no Highlight, so a fading one never shows a hard outline)
trail.Name = 'HoodGoalTrail'
local function bar(name, size, color)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	pcall(function() p.CanQuery, p.CanTouch = false, false end)
	p.Size, p.Color, p.Material = size, color, Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.Parent = trail
	return p
end
-- the chevrons: a "^" of two chunky gold bars each, on a slightly bigger ink "^" (its outline)
local chevrons = {}
for i = 1, TRAIL.Count do
	chevrons[i] = {
		L = bar('ChevronL' .. i, Vector3.new(0.62, 0.08, 1.8), COL.Fill),
		R = bar('ChevronR' .. i, Vector3.new(0.62, 0.08, 1.8), COL.Fill),
		InkL = bar('ChevronInkL' .. i, Vector3.new(0.98, 0.06, 2.16), COL.Ink),
		InkR = bar('ChevronInkR' .. i, Vector3.new(0.98, 0.06, 2.16), COL.Ink),
	}
end
local outline = nil
pcall(function()
	local hl = Instance.new('Highlight')
	hl.Name = 'Outline'
	hl.FillTransparency = 1
	hl.OutlineColor = COL.Ink
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = folder
	hl.Enabled = false
	hl.Parent = folder
	outline = hl
end)
folder.Parent = workspace
trail.Parent = workspace

local shownAlpha = -1
local function setArrowAlpha(a)
	shownAlpha = GuideArrow.setAlpha(arrow, a, shownAlpha)
	if outline then
		local on = shownAlpha > 0
		if outline.Enabled ~= on then outline.Enabled = on end
		outline.OutlineTransparency = 1 - shownAlpha
	end
end
local function hideChevrons()
	for _, c in chevrons do
		if c.L.Transparency < 1 then c.L.Transparency, c.R.Transparency, c.InkL.Transparency, c.InkR.Transparency = 1, 1, 1, 1 end
	end
end

---------------------------------------------------------------------------------------------- the edge pointer
local edgeGui = Instance.new('ScreenGui')
edgeGui.Name = 'HoodGuideEdge'
edgeGui.ResetOnSpawn, edgeGui.IgnoreGuiInset, edgeGui.DisplayOrder = false, true, 4
edgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() edgeGui.ScreenInsets = Enum.ScreenInsets.None end)
local E = GuideArrow.Edge
local pointer = Kit.new('Frame', { Name = 'Pointer', AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(E.Size, E.Size), BackgroundTransparency = 1, Visible = false, Parent = edgeGui })
local pointerPop = Kit.new('UIScale', { Name = 'Pop', Scale = 1, Parent = pointer })
-- the badge: the UI's navy card face in a circle, a thick ink ring and a light rim (the mockup windows' look)
local badge = Kit.new('Frame', { Name = 'Badge', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 2, Parent = pointer })
Kit.corner(UDim.new(0.5, 0)).Parent = badge
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.Skin.bodyTop, Kit.Skin.bodyBase), Parent = badge })
Kit.stroke(Kit.Skin.outline, 4, true).Parent = badge
local rim = Kit.new('Frame', { Name = 'Rim', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 3, Parent = badge })
Kit.corner(UDim.new(0.5, 0)).Parent = rim
Kit.stroke(Kit.Skin.rim, 2, true, 0.1).Parent = rim
-- the chevron ">" (two chunky gold bars, ink-edged), turned to point the way; the badge itself stays upright
local needle = Kit.new('Frame', { Name = 'Needle', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = pointer })
for side = -1, 1, 2 do
	local b = Kit.new('Frame', { Name = 'Chevron', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 2, 0.5, side * 7), Size = UDim2.fromOffset(28, 11), Rotation = side * 42, BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 5, Parent = needle })
	Kit.corner(UDim.new(0.5, 0)).Parent = b
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(COL.Top, COL.Fill), Parent = b })
	Kit.stroke(COL.Ink, 2.5, true).Parent = b
end
edgeGui.Parent = playerGui
local edgeOn, edgeSince = false, 0
local function hideEdge()
	if edgeOn then edgeOn = false; pointer.Visible = false end
end

-- (Oct 27, flow: one guide at a time) PlayerGui HoodGoalGuide is true while this guide is up: the lobby's
-- "TRAIN xN HERE" pointer steps aside for it.
local up = nil
local function setUp(on)
	if up == on then return end
	up = on
	playerGui:SetAttribute('HoodGoalGuide', on)
end
local shownKey = nil
local function hideAll()
	setArrowAlpha(0)
	hideChevrons()
	hideEdge()
	shownKey = nil
	setUp(false)
end

---------------------------------------------------------------------------------------------- the floor, the walls
local rayParams = (function()
	local ok, r = pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { folder, trail }
		pcall(function() p.RespectCanCollide = true end)
		return p
	end)
	return ok and r or nil
end)()
local wallParams = (function() -- (walls and signs: anything you'd see the arrow cut into, CanCollide or not)
	local ok, r = pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { folder }
		return p
	end)
	return ok and r or nil
end)()
local function floorAt(p, feetY)
	if not rayParams then return feetY end
	local ok, hit = pcall(function()
		local list = { folder, trail }
		if player.Character then table.insert(list, player.Character) end
		rayParams.FilterDescendantsInstances = list
		return workspace:Raycast(Vector3.new(p.X, feetY + 3, p.Z), Vector3.new(0, -8, 0), rayParams)
	end)
	if ok and hit and math.abs(hit.Position.Y - feetY) <= 2.5 then return hit.Position.Y end
	return feetY
end
-- The distance to the first solid, visible thing along dir from origin (nil: none), for GuideArrow.clear. See-through
-- parts (trigger boxes, the labels' anchors, glass a kid sees through) are looked past.
local function castFor()
	if not wallParams then return nil end
	return function(origin, dir)
		local skip = { folder, trail }
		if player.Character then table.insert(skip, player.Character) end
		local goons = workspace:FindFirstChild('HoodGoons')
		if goons then table.insert(skip, goons) end
		for _ = 1, 4 do
			local ok, hit = pcall(function()
				wallParams.FilterDescendantsInstances = skip
				return workspace:Raycast(origin, dir, wallParams)
			end)
			if not ok or not hit then return nil end
			local inst = hit.Instance
			if inst and inst:IsA('BasePart') and inst.Transparency < 0.6 then return (hit.Position - origin).Magnitude end
			table.insert(skip, inst)
		end
		return nil
	end
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
-- A small model (a shoe box): the arrow's tip 2.5 studs over its top.
local function overTop(m, key)
	local b = boxOf(m, key)
	if not b then return pivotOf(m) end
	return Vector3.new(b.CFrame.Position.X, b.CFrame.Position.Y + b.Size.Y / 2 + 2.5 - GuideArrow.Up, b.CFrame.Position.Z)
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
	if playerGui:GetAttribute('HoodWelcome') == true then return true end -- (Oct 27, flow)
	if num(attr('WaveLeft')) > 0 or attr('Downed') == true or attr('WorldBossFight') == true then return true end
	return false
end
local function inside(zone, p)
	local local_ = zone.CFrame:PointToObjectSpace(p)
	return math.abs(local_.X) <= zone.Size.X / 2 + 1 and math.abs(local_.Z) <= zone.Size.Z / 2 + 1
end
-- What to point at now: the floor point, where the trail goes first (nil: straight there), and a key that changes
-- when the place does. nil: nothing to point at (or you are there).
local function want(you)
	if playerGui:GetAttribute('HoodGuide') == 'Tutorial' then
		local at, via = playerGui:GetAttribute('GuideAt'), playerGui:GetAttribute('GuideVia')
		if typeof(at) ~= 'Vector3' then return nil end
		return at, typeof(via) == 'Vector3' and via or nil, 'Tutorial:' .. tostring(playerGui:GetAttribute('GuideKind'))
	end
	if TutorialRules.step(attr('OnboardingStep')) then return nil end -- (the tutorial's step with nothing to walk to: the fight)
	local step = attr('GoalStep')
	if type(step) ~= 'number' then return nil end
	local goal = GoalRules.at(step)
	local t = GuideRules.target(goal, { Rebirths = attr('Rebirths'), RunCleared = attr('RunCleared'), World = GoalRules.World })
	if not t or not find[t.Kind] then return nil end
	local at, zone = find[t.Kind](t, you)
	if not at then return nil end
	local dist = Vector3.new(at.X - you.X, 0, at.Z - you.Z).Magnitude
	if (zone and inside(zone, you)) or (not zone and dist <= (GuideRules.Near[t.Kind] or 8)) then return nil end
	return at, nil, t.Kind .. tostring(t.Stage or t.Station or '')
end

---------------------------------------------------------------------------------------------- every frame
local clock = 0
local warned = false
local appear = 0 -- seconds since the arrow last popped in
local clearAt, clearFor, clearTip = -1, nil, nil -- (the clearance is looked at twice a second per place)
local function backOut(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local HudBoxes = require(RS.Shared.HudBoxes)
local hudBoxes, boxesAt = {}, -1
local function edgeStep(dt, mid)
	local cam = workspace.CurrentCamera
	if not cam then hideEdge(); return end
	local view = cam.ViewportSize
	local sp = GuideArrow.project(cam.CFrame, cam.FieldOfView, view, mid)
	local e = sp and GuideArrow.edge(sp, view) or nil
	if not e then hideEdge(); return end
	-- (off the HUD's buttons: their boxes looked at twice a second)
	if clock - boxesAt >= 0.5 or clock < boxesAt then
		boxesAt = clock
		local okB, boxes = pcall(HudBoxes.get, playerGui, 4)
		hudBoxes = okB and boxes or {}
	end
	e.X, e.Y = GuideArrow.clearOf(e.X, e.Y, E.Size / 2 + E.Push, hudBoxes, view)
	if not edgeOn then edgeOn, edgeSince = true, clock; pointer.Visible = true end
	local still = attr('ReducedMotion') == true
	local push = still and 0 or E.Push * (0.5 + 0.5 * math.sin((clock - edgeSince) * 2 * math.pi / E.Period))
	local a = math.rad(e.Angle)
	pointer.Position = UDim2.fromOffset(e.X + math.cos(a) * push, e.Y + math.sin(a) * push)
	needle.Rotation = e.Angle
	local s = math.clamp((clock - edgeSince) / 0.3, 0, 1)
	pointerPop.Scale = still and 1 or (0.5 + 0.5 * backOut(s))
end
local function tick(dt)
	clock += dt
	local char = player.Character
	local root = char and char:FindFirstChild('HumanoidRootPart')
	if not root or busy() then hideAll(); return end
	local you = root.CFrame.Position
	local at, via, key = want(you)
	if not at then hideAll(); return end
	-- (a gate: the arrow floats a few studs on your side of its line, never inside its barrier or its frame)
	if key == 'Tutorial:Gate' or key:sub(1, 4) == 'Gate' then
		local back = Vector3.new(you.X - at.X, 0, you.Z - at.Z)
		if back.Magnitude > 4 then at += back.Unit * 3 end
	end
	local flat = Vector3.new(at.X - you.X, 0, at.Z - you.Z)
	local dist = flat.Magnitude
	if dist <= 4 then hideAll(); return end -- (never on top of you)
	if key ~= shownKey then shownKey, appear, clearFor = key, 0, nil end
	appear += dt
	-- the arrow: floating over the target, turned to the camera, clear of walls and ceilings
	local cam = workspace.CurrentCamera
	local face = cam and (cam.CFrame.Position - at) or -flat
	face = Vector3.new(face.X, 0, face.Z)
	if face.Magnitude < 0.01 then face = Vector3.new(0, 0, 1) end
	face = face.Unit
	local still = attr('ReducedMotion') == true
	local bob, pulse = GuideArrow.motion(clock, still)
	local base = GuideArrow.scaleFor(dist)
	if clearFor ~= key or clock - clearAt >= 0.5 then
		clearAt, clearFor = clock, key
		clearTip = GuideArrow.clear(at, base, face, castFor())
	end
	local pop = still and 1 or (0.45 + 0.55 * backOut(math.clamp(appear / APPEAR, 0, 1)))
	local k = base * pulse * pop
	local tip = (clearTip or (at + UP * GuideArrow.Up)) + UP * bob
	GuideArrow.lay(arrow, tip, face, k)
	setArrowAlpha(math.clamp(appear / 0.2, 0, 1))
	setUp(true)
	edgeStep(dt, tip + UP * (GuideArrow.height(k) * 0.5))
	-- the trail: chevrons on the floor along the straight line to it (to the waypoint first), drifting on, fading in by
	-- you and out at its end
	local goal = via or at
	local gflat = Vector3.new(goal.X - you.X, 0, goal.Z - you.Z)
	local gdist = gflat.Magnitude
	local feetY = you.Y - 3
	local dir = gdist > 0.01 and gflat.Unit or Vector3.new(0, 0, -1)
	local right = dir:Cross(UP).Unit
	local shift = still and 0 or (clock * TRAIL.Speed) % TRAIL.Gap
	local stop = gdist - (via and 0 or TRAIL.Short)
	for i, c in chevrons do
		local d = TRAIL.From + (i - 2) * TRAIL.Gap + shift -- (the first one is coming in from behind the start)
		local a = math.min((d - TRAIL.From) / TRAIL.Gap, (stop - d) / TRAIL.Gap, 1)
		a = math.clamp(a, 0, 1) * (0.95 - 0.3 * math.clamp(d / 44, 0, 1))
		if a <= 0.02 then
			c.L.Transparency, c.R.Transparency, c.InkL.Transparency, c.InkR.Transparency = 1, 1, 1, 1
		else
			local p = Vector3.new(you.X, 0, you.Z) + dir * d
			local y = floorAt(p, feetY) + 0.16 -- (clear of the floor's painted paths and tiles)
			local tipAt = Vector3.new(p.X, y, p.Z)
			for side, pair in { [1] = { c.L, c.InkL }, [-1] = { c.R, c.InkR } } do
				local arm = (-dir + right * side * 0.85).Unit
				local mid = tipAt + arm * 0.7
				pair[1].CFrame = CFrame.lookAt(mid, mid + arm)
				pair[2].CFrame = CFrame.lookAt(mid - UP * 0.04, mid - UP * 0.04 + arm)
				pair[1].Transparency = 1 - a
				pair[2].Transparency = 1 - a * 0.9
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
