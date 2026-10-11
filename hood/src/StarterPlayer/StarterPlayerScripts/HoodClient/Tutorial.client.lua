-- The quick tutorial on your screen (brief 29, P4; the rules are Shared/TutorialRules, the step comes from HoodServer/
-- OnboardingService's player attribute OnboardingStep). The user's words: a white box over what the player has to press or
-- walk to that moves smoothly to the next thing, actual white arrows on the ground pointing exactly at the goal for the
-- tutorial only, no cutscenes, straight to the point.
--   * The WHITE BOX: a rounded white outline (3 px, the reference's) that slides (about 0.4 s) to the next target on your
--     screen; off screen it rests on the screen's edge toward the target.
--   * The HINT BOX at the bottom centre: a dark rounded box, bold white words with the key word yellow, typed in at 24
--     characters a second (the reference), and three dots for the three basics.
--   * The WHITE ARROWS on the ground: a row of flat white arrows along the STRAIGHT line from your feet to the target, all
--     pointing exactly at it, flowing toward it; none within a few studs of it.
--   Steps: BAY 1, the gate and the crew, the cash pad (and the gift by the spawn). When the server moves on (Gun, Run, Done)
--   everything fades away for good: the goal tracker (Goals.client) takes over, and the old yellow trails no longer exist.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local UserInputService = game:GetService('UserInputService')
local Kit = require(RS.Shared.UIKit)
local Rules = require(RS.Shared.TutorialRules)
local ActiveMap = require(RS.Shared.ActiveMap)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local playerGui = player:WaitForChild('PlayerGui')
local frameCF = active.Frame
local px, hex, BLACK, WHITE = UDim2.fromOffset, Kit.hex, Kit.Color.black, Kit.Color.white
local function attr(name) return player:GetAttribute(name) end

local gui, root, fit = Kit.screen('HoodTutorial', nil, 8)

---------------------------------------------------------------------------------------------- the screen
local box = Kit.new('Frame', { Name = 'WhiteBox', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(140, 100), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = root })
Kit.corner(10).Parent = box
local boxStroke = Kit.stroke(WHITE, 3, true)
boxStroke.Parent = box
local badge = Kit.new('Frame', { Name = 'Badge', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = px(26, 26), BackgroundColor3 = hex('2F9BFF'), BorderSizePixel = 0, ZIndex = 5, Parent = box })
Kit.corner(13).Parent = badge
Kit.stroke(BLACK, 2.5).Parent = badge
local badgeText = Kit.text({ Name = 'N', Text = '1', TextSize = 17, Stroke = BLACK, StrokeThickness = 2, ZIndex = 6, Parent = badge })

local HINT_W, HINT_H = 450, 64
local hint = Kit.new('Frame', { Name = 'Hint', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = px(HINT_W, HINT_H), BackgroundColor3 = hex('14161F'), BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = root })
Kit.corner(12).Parent = hint
Kit.stroke(hex('5A5F70'), 1.5, true).Parent = hint
local hintText = Kit.text({ Name = 'Text', Text = '', TextSize = 25, Stroke = BLACK, StrokeThickness = 3, RichText = true, Position = px(0, 4), Size = UDim2.new(1, 0, 0, 40), ZIndex = 5, Parent = hint })
hintText.TextWrapped = false
local dots = {}
for i = 1, Rules.Total do
	local d = Kit.new('Frame', { Name = 'Dot' .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(HINT_W / 2 + (i - 2) * 16, HINT_H - 12), Size = px(8, 8), BackgroundColor3 = hex('5A5F70'), BorderSizePixel = 0, ZIndex = 5, Parent = hint })
	Kit.corner(4).Parent = d
	dots[i] = d
end

---------------------------------------------------------------------------------------------- the white arrows on the ground
local world = Instance.new('Folder')
world.Name = 'HoodTutorialLocal'
world.Parent = workspace
local MAX_ARROWS = 9
local arrows = {}
local function part(parent, name, size, color, transparency, material)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Transparency, p.Material = size, color, transparency, material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
local HEAD_A = math.rad(40)
for i = 1, MAX_ARROWS do
	local m = Instance.new('Model')
	m.Name = 'GroundArrow'
	local shaft = part(m, 'Shaft', Vector3.new(0.75, 0.1, 2.2), Color3.new(1, 1, 1), 0.04, Enum.Material.Neon)
	local left = part(m, 'HeadL', Vector3.new(0.75, 0.1, 1.7), Color3.new(1, 1, 1), 0.04, Enum.Material.Neon)
	local right = part(m, 'HeadR', Vector3.new(0.75, 0.1, 1.7), Color3.new(1, 1, 1), 0.04, Enum.Material.Neon)
	local ink = part(m, 'Ink', Vector3.new(1.35, 0.06, 3.9), Color3.new(0, 0, 0), 0.55)
	m.PrimaryPart = shaft
	arrows[i] = { Model = m, Shaft = shaft, Left = left, Right = right, Ink = ink }
end
local function layArrow(a, at, dir, y)
	local base = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X + dir.X, y, at.Z + dir.Z))
	a.Shaft.CFrame = base * CFrame.new(0, 0, 0.35)
	a.Ink.CFrame = base * CFrame.new(0, -0.03, -0.1)
	local tipZ = -0.75
	a.Left.CFrame = base * CFrame.new(-math.sin(HEAD_A) * 0.85, 0, tipZ + math.cos(HEAD_A) * 0.85) * CFrame.Angles(0, -HEAD_A, 0)
	a.Right.CFrame = base * CFrame.new(math.sin(HEAD_A) * 0.85, 0, tipZ + math.cos(HEAD_A) * 0.85) * CFrame.Angles(0, HEAD_A, 0)
end
local function showArrows(n)
	for i, a in arrows do
		local parent = i <= n and world or nil
		if a.Model.Parent ~= parent then a.Model.Parent = parent end
	end
end
local okRay, rayParams = pcall(function()
	local r = RaycastParams.new()
	r.FilterType = Enum.RaycastFilterType.Exclude
	return r
end)
if not okRay then rayParams = nil end
local function floorAt(p, fallback)
	if not rayParams then return fallback + 0.07 end
	local ok, hit = pcall(function() return workspace:Raycast(Vector3.new(p.X, fallback + 4, p.Z), Vector3.new(0, -14, 0), rayParams) end)
	return (ok and hit and hit.Position.Y or fallback) + 0.07
end

---------------------------------------------------------------------------------------------- targets (world points)
local function tagged(tag)
	local ok, list = pcall(function() return CollectionService:GetTagged(tag) end)
	local out = {}
	for _, x in ok and list or {} do
		if x:IsDescendantOf(active.Root) then table.insert(out, x) end
	end
	return out
end
local function topOf(p) return (p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position end
local Target = {}
function Target.lane()
	local m = active.Root:FindFirstChild('Training_Starter', true)
	local z = m and m:FindFirstChild('TrainingZone', true)
	return z and topOf(z) or nil, 3
end
function Target.door()
	for _, g in tagged('HoodStageGate') do
		if g:GetAttribute('Stage') == 1 then
			local barrier = g:FindFirstChild('Barrier', true)
			local at = barrier and frameCF:PointToObjectSpace(barrier.CFrame.Position) or frameCF:PointToObjectSpace(g:GetPivot().Position)
			local floor = barrier and at.Y - barrier.Size.Y / 2 or 0
			local line = g:GetAttribute('LineZ') or at.Z
			return frameCF * Vector3.new(at.X, floor, line - 4), 5
		end
	end
	return nil
end
function Target.goon()
	local f = workspace:FindFirstChild('HoodGoons')
	local c = player.Character
	local root_ = c and c:FindFirstChild('HumanoidRootPart')
	if not (f and root_) then return Target.door() end
	local best, bestD
	for _, m in f:GetChildren() do
		local ok, cf = pcall(function() return m:GetPivot() end)
		if ok and cf then
			local d = (cf.Position - root_.Position).Magnitude
			if d < 90 and (not bestD or d < bestD) then best, bestD = cf.Position, d end
		end
	end
	return best or Target.door(), 2
end
function Target.pad()
	local stage = tonumber(attr('RunCleared')) or 0
	for _, p in tagged('HoodStagePad') do
		if p:IsA('BasePart') and p:GetAttribute('Kind') == 'Return' and p:GetAttribute('Stage') == stage then return topOf(p), 3 end
	end
	return nil
end
function Target.gift()
	local at = attr('OnboardingGiftAt')
	return typeof(at) == 'Vector3' and at or nil, 3
end

---------------------------------------------------------------------------------------------- state
local step, stepAt, targetCache, cacheAt, shown = nil, 0, nil, -1, false
local pos, size = Vector2.new(640, 360), Vector2.new(140, 100)
local function windowOpen()
	local w = playerGui:GetAttribute('HoodWindow')
	return (type(w) == 'string' and w ~= '') or playerGui:GetAttribute('Unboxing') == true
end
local function inLane()
	local s = attr('TrainingStation')
	return type(s) == 'string' and s ~= '' and not s:find('Locked:')
end
local function touchOnly()
	local ok, v = pcall(function() return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end)
	return ok and v == true
end
local function onStep()
	local now = attr('OnboardingStep')
	local info = Rules.step(now)
	local name = info and now or nil
	if name == step then return end
	step, stepAt, targetCache, cacheAt = name, os.clock(), nil, -1
	gui:SetAttribute('Step', name or '') -- (for the checks)
	if info then
		badgeText.Text = tostring(info.Part)
		for i, d in dots do d.BackgroundColor3 = i <= info.Part and hex('FFD21F') or hex('5A5F70') end
		hint.Visible, box.Visible = true, true
	end
end
player:GetAttributeChangedSignal('OnboardingStep'):Connect(onStep)

local function screenOf(world_)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local ok, v, on = pcall(function() return cam:WorldToViewportPoint(world_) end)
	if not ok or typeof(v) ~= 'Vector3' then return nil end
	return v, on
end

RunService.Heartbeat:Connect(function(dt)
	local info = Rules.step(step)
	local c = player.Character
	local rootPart = c and c:FindFirstChild('HumanoidRootPart')
	local hum = c and c:FindFirstChildOfClass('Humanoid')
	local on = info ~= nil and rootPart ~= nil and not windowOpen()
	if not on then
		if shown then
			shown = false
			showArrows(0)
			box.Visible, hint.Visible = false, false
		end
		return
	end
	shown = true
	hint.Visible, box.Visible = true, true
	local now = os.clock()
	local lane = step == 'Train' and inLane()
	-- the hint: typed in, the key word yellow
	local text = (touchOnly() and info.Touch) or info.Text
	if lane then text = 'Stay in <BAY 1>: it shoots by itself!' end
	local t = now - stepAt
	hintText.Text = Rules.rich(text, Rules.typed(t))
	hint.BackgroundTransparency = math.clamp(0.1 + (1 - math.min(t / 0.25, 1)) * 0.9, 0.1, 1)
	hint.Position = UDim2.fromScale(0.5, 0.64 + 0.02 * (1 - math.min(t / 0.25, 1)))
	-- the target, looked up twice a second
	if now - cacheAt > 0.5 then
		cacheAt = now
		local find = Target[info.Target]
		local a, b = find()
		targetCache = a and { At = a, Lift = b or 3 } or nil
	end
	local feet = rootPart.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + rootPart.Size.Y / 2, 0)
	if rayParams then rayParams.FilterDescendantsInstances = { c, world } end
	local target = (not lane) and targetCache and targetCache.At or nil
	-- the white arrows: the straight line from your feet to the target (not once you are in the fight with the goon near)
	local flat = target and Vector3.new(target.X - feet.X, 0, target.Z - feet.Z).Magnitude or 0
	if target and (info.Target ~= 'goon' or flat > 14) then
		local points, dir = Rules.arrows(feet, target, (now * 0.9) % 1, 4, MAX_ARROWS, 3, 3)
		for i, p in points do layArrow(arrows[i], p, dir, floorAt(p, feet.Y)) end
		showArrows(#points)
	else
		showArrows(0)
	end
	-- the white box: on the target when it is on screen, else on the screen's edge toward it
	local goal, goalSize = Vector2.new(640, 360), Vector2.new(120, 90)
	local visible = target ~= nil
	if target then
		local v, onScreen = screenOf(target + Vector3.new(0, targetCache.Lift * 0.5, 0))
		if v then
			local k = Kit.scaleFor(gui.AbsoluteSize)
			local vp = workspace.CurrentCamera.ViewportSize
			local x, y, edge = Rules.boxAt(v.X / k, (v.Y - 36) / k, onScreen and v.Z > 0, vp.X / k, vp.Y / k, 70)
			goal = Vector2.new(x, y)
			local d = math.max(v.Z, 6)
			goalSize = edge and Vector2.new(70, 70) or Vector2.new(math.clamp(2600 / d, 78, 230), math.clamp(1900 / d, 62, 170))
		end
	end
	box.Visible = visible
	local a = 1 - math.exp(-dt * 9) -- (about 0.4 s to settle)
	pos, size = pos:Lerp(goal, a), size:Lerp(goalSize, a)
	box.Position, box.Size = px(pos.X, pos.Y), px(size.X, size.Y)
	boxStroke.Thickness = 3 + 1.2 * math.sin(now * 5) -- (a slow breath, not a flash)
end)

player.CharacterAdded:Connect(function() showArrows(0) end)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function() gui.Enabled = not windowOpen() end)
gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)
onStep()
