-- The first-session guidance on your screen (HOOK, brief 23: hooked in 30 seconds; the design is
-- brief/out23/HOOK/first30.md). The server decides the step (HoodServer/OnboardingService: the player attribute
-- OnboardingStep, Shared/OnboardingRules); this shows it, with no reading needed:
--   * one-word callouts ("TRAIN!", "GO!", "FIGHT!", "CASH!", "GIFT!", "GUN!", "x2 POWER!"): big gold Gotham Black with a
--     thick black outline, just over your character; they pop, hold a beat and float away. Only one at a time, never
--     while a window, the unboxing or the GOAL DONE moment owns the screen.
--   * for the steps after LOBBY5's floor guide (Cash, Gift, Gun, Run; only while Lobby.client's GuidePhase is ''): the
--     same gold chevron trail from your feet to the target (the yellow pad, the present, the next gun's pad in the
--     ARMORY, the Stage 1 door), a bouncing arrow with the step's word over it (a LabelFade label), and a ">>" pointer
--     at the screen's edge while the target is off screen.
--   * the welcome present (OnboardingGiftAt, a world position): a glowing studded gift box that bobs and spins on the
--     walkway; walk into it and the server opens it (Shoes.client plays the unboxing).
--   * the timed hint, for the stuck only: no closer to the target for 6 s and the arrow bounces bigger and the word
--     pops again.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local CollectionService = game:GetService('CollectionService')
local Kit = require(RS.Shared.UIKit)
local Rules = require(RS.Shared.OnboardingRules)
local ActiveMap = require(RS.Shared.ActiveMap)
local Guns = require(RS.Shared.Config.Guns)
local okVfx, HoodVFX = pcall(require, RS.Shared.HoodVFX)
if not okVfx then HoodVFX = nil end
local okJuice, Juice = pcall(require, RS.Shared.Juice)
if not okJuice then Juice = nil end

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local playerGui = player:WaitForChild('PlayerGui')
local frameCF = active.Frame

local C = Color3.fromRGB
local GOLD = C(240, 186, 80) -- (LOBBY5's guide colour: one trail system to the eye)
local GOLD_TOP, GOLD_BOTTOM = Kit.hex('FFF27A'), Kit.hex('FFB020')
local INK = Kit.Color.black
local HOVER = 0.7 -- the trail's height over the floor
local function attr(name) return player:GetAttribute(name) end
local function num(v) return type(v) == 'number' and v == v and v or 0 end

---------------------------------------------------------------------------------------------- callouts
local gui, root, fit = Kit.screen('HoodOnboarding', nil, 6)
local function windowOpen()
	local w = playerGui:GetAttribute('HoodWindow')
	return type(w) == 'string' and w ~= ''
end
local function busy() -- something else owns the middle of the screen (the GOAL DONE moment sits at the top: no clash)
	return windowOpen() or playerGui:GetAttribute('Unboxing') == true
end
local function goldText(t)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM), Parent = t })
	return t
end
local shown -- the callout on screen
local guideTarget = nil -- (the guided target's world point while a trail is up: the callout flies to it)
local CALLOUT_Y = 0.35 -- (just over your character's head, under the goal line; the HUD's bottom block is far below)
-- Where on the root (design px) a world point shows, or nil off screen.
local function screenOf(world)
	local cam = workspace.CurrentCamera
	local ok, v, on = pcall(function() return cam:WorldToViewportPoint(world) end)
	if not ok or not on or typeof(v) ~= 'Vector3' or v.Z <= 0 then return nil end
	local k = Kit.scaleFor(gui.AbsoluteSize)
	return UDim2.fromOffset(v.X / k, (v.Y - 36) / k) -- (the root sits under Roblox's 36 px top bar)
end
-- opts: y (the screen height share, CALLOUT_Y by default) and fly (a function giving the world point to fly to, else
-- the guided target).
local function callout(word, opts)
	if type(word) ~= 'string' or word == '' then return false end
	opts = opts or {}
	local y = opts.y or CALLOUT_Y
	if shown then shown:Destroy() end
	local holder = Kit.new('Frame', { Name = 'Callout', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(640, 90), Parent = root })
	holder:SetAttribute('Word', word)
	holder:SetAttribute('Why', opts.why or 'step') -- (for the checks: a step's callout, or the timed hint)
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local t = goldText(Kit.text({ Name = 'Word', Text = word, TextSize = 60, Stroke = INK, StrokeThickness = 6, Parent = holder }))
	shown = holder
	TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.1, function()
		if shown ~= holder then return end
		-- it flies off to the arrow over the target when there is one on screen (the word "becomes" the arrow), else
		-- floats up; either way it fades
		local out = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local at = opts.fly and opts.fly() or (guideTarget and guideTarget + Vector3.new(0, 5, 0))
		local to = at and screenOf(at)
		TweenService:Create(holder, out, { Position = to or UDim2.new(0.5, 0, y, -36) }):Play()
		if to then TweenService:Create(scale, out, { Scale = 0.4 }):Play() end
		TweenService:Create(t, out, { TextTransparency = 1 }):Play()
		local s = t:FindFirstChildOfClass('UIStroke')
		if s then TweenService:Create(s, out, { Transparency = 1 }):Play() end
		task.delay(0.5, function()
			holder:Destroy()
			if shown == holder then shown = nil end
		end)
	end)
	return true
end
-- Stages.client's banners ("STAGE 2 OPEN!", the cash-out's "+10 Cash / Run banked!") sit just over the callout's spot:
-- a callout waits for them.
local function bannerUp()
	local fb = playerGui:FindFirstChild('StageFeedback')
	return fb ~= nil and (fb:FindFirstChild('Banner') ~= nil or fb:FindFirstChild('CashPop') ~= nil)
end
-- A callout after a delay, dropped if the step moved on meanwhile; it waits (up to 8 s) for a busy screen to clear.
local sayToken = 0
local function sayLater(word, delay, step, opts)
	sayToken += 1
	local mine = sayToken
	task.delay(delay or 0, function()
		local t0 = os.clock()
		while (busy() or bannerUp()) and os.clock() - t0 < 8 do task.wait(0.1) end
		if mine ~= sayToken or busy() then return end
		if step and attr('OnboardingStep') ~= step then return end
		if opts and opts.still and not opts.still() then return end -- (its moment has passed: say nothing)
		callout(word, opts)
	end)
end

---------------------------------------------------------------------------------------------- targets
local function tagged(tag)
	local ok, list = pcall(function() return CollectionService:GetTagged(tag) end)
	local out = {}
	for _, x in ok and list or {} do
		if x:IsDescendantOf(active.Root) then table.insert(out, x) end
	end
	return out
end
local function topOf(part) return (part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)).Position end
local Target = {}
-- The top (world Y) of a floating label: its anchor part, the BillboardGui's StudsOffset and half its height in studs.
local function labelTop(anchor)
	local bb = anchor and anchor:FindFirstChildWhichIsA('BillboardGui', true)
	if not (bb and anchor:IsA('BasePart')) then return nil end
	local h = bb.Size.Y.Scale > 0 and bb.Size.Y.Scale or 2
	return anchor.CFrame.Position.Y + bb.StudsOffset.Y + h / 2
end
-- Each target: its floor point, and how high the arrow floats over it (clear of the target's own label: the arrow's
-- "V" stands 0.4 studs over the label's top, CRITIC3 r1).
local ARROW_CLEAR = 1.7
function Target.pad() -- the yellow pad of the stage you just beat (its label: the sibling part <pad name>Label)
	local stage = num(attr('RunCleared'))
	for _, p in tagged('HoodStagePad') do
		if p:IsA('BasePart') and p:GetAttribute('Kind') == 'Return' and p:GetAttribute('Stage') == stage then
			local at = topOf(p)
			local best, bestD
			for _, c in p.Parent and p.Parent:GetChildren() or {} do
				if c.Name == p.Name .. 'Label' and c:IsA('BasePart') then
					local d = Vector3.new(c.CFrame.Position.X - at.X, 0, c.CFrame.Position.Z - at.Z).Magnitude
					if not bestD or d < bestD then best, bestD = c, d end
				end
			end
			local top = best and bestD < 8 and labelTop(best)
			return at, top and math.max(4, top - at.Y + ARROW_CLEAR) or 9
		end
	end
	return nil
end
function Target.gun() -- the next gun's pad in the ARMORY (its nameplate: GunLabel)
	local id = Rules.nextGun(Guns.List, Rules.ownedSet(attr('OwnedGuns')))
	local slot = id and active.Root:FindFirstChild('GunSlot_' .. id, true)
	if not slot then return nil end
	local mat = slot:FindFirstChild('StateMat', true) or slot:FindFirstChildWhichIsA('BasePart', true)
	if not mat then return nil end
	local at = topOf(mat)
	local plate = slot:FindFirstChild('GunLabel', true)
	local top = plate and plate.Parent and labelTop(plate.Parent)
	return at, top and math.max(4, top - at.Y + ARROW_CLEAR) or 9
end
function Target.gift()
	local at = attr('OnboardingGiftAt')
	return typeof(at) == 'Vector3' and at or nil, 6.5 -- (over the present's bow)
end
local function gateOne()
	for _, g in tagged('HoodStageGate') do
		if g:GetAttribute('Stage') == 1 then return g end
	end
	return nil
end
function Target.door() -- a few studs into Stage 1, on the floor (stages run toward -Z in the map frame)
	local g = gateOne()
	if not g then return nil end
	local barrier = g:FindFirstChild('Barrier', true)
	local at = barrier and frameCF:PointToObjectSpace(barrier.CFrame.Position) or frameCF:PointToObjectSpace(g:GetPivot().Position)
	local floor = barrier and at.Y - barrier.Size.Y / 2 or 0
	local line = g:GetAttribute('LineZ') or at.Z
	return frameCF * Vector3.new(at.X, floor, line - 4)
end
function Target.lane() -- BAY 1's box (the timed hint only: LOBBY5's guide draws this step)
	local m = active.Root:FindFirstChild('Training_Starter', true)
	local z = m and m:FindFirstChild('TrainingZone', true)
	return z and topOf(z) or nil
end
local STEP_TARGET = { Train = Target.lane, Door = Target.door, Cash = Target.pad, Gift = Target.gift, Gun = Target.gun, Run = Target.door }
-- The arrow's word per guided step. The pads and the guns carry their own big labels ("+10 Cash / Return", the gun's
-- nameplate), which are the call to action: there the arrow is the bouncing "V" alone, over the label.
local ARROW_WORD = { Gift = 'FREE GIFT!', Run = 'GO!' }

---------------------------------------------------------------------------------------------- the local world
local folder = Instance.new('Folder')
folder.Name = 'HoodOnboardingLocal'
folder.Parent = workspace
local function anchorPart(name, size)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency, p.Size = 1, size or Vector3.new(0.2, 0.2, 0.2)
	p.Parent = folder
	return p
end

-- The arrow: a word over a gold "V", bouncing over the target, readable through walls.
local arrow = {}
do
	local anchor = anchorPart('GuideArrowAnchor')
	anchor.CFrame = CFrame.new(0, -5000, 0)
	local bb = Instance.new('BillboardGui')
	bb.Name = 'WorldLabel'
	bb.Size = UDim2.new(6, 0, 3.6, 0) -- (studs: it clears the targets' labels the same at any distance)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Enabled = false
	bb:SetAttribute('FadeNear', 140)
	bb:SetAttribute('FadeFar', 260)
	bb:SetAttribute('FadeShrink', 14)
	bb:SetAttribute('FadeShrinkMin', 0.55)
	bb.Adornee = anchor
	bb.Parent = anchor
	-- (scale sizes only: LabelFade resizes the BillboardGui, and its children follow)
	local word = goldText(Kit.text({ Name = 'Title', Text = '', TextSize = 40, Stroke = INK, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.42), Parent = bb }))
	word.TextScaled = true
	local chevrons = {}
	for _, side in { -1, 1 } do -- the "V": two bars meeting at the bottom centre
		local bar = Kit.new('Frame', { Name = 'Chevron', AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = GOLD, BorderSizePixel = 0, Rotation = side * -38, Parent = bb })
		Kit.stroke(INK, 3, true).Parent = bar
		table.insert(chevrons, { Bar = bar, Side = side })
	end
	-- With a word the "V" sits small under it; alone (over a target's own label) it is big and centred.
	function arrow.layout(word)
		if arrow.Shown == word then return end
		arrow.Shown = word
		arrow.Word.Text = word
		local alone = word == ''
		for _, c in chevrons do
			c.Bar.Position = UDim2.fromScale(0.5 + c.Side * (alone and 0.1 or 0.068), alone and 0.5 or 0.68)
			c.Bar.Size = alone and UDim2.fromScale(0.31, 0.2) or UDim2.fromScale(0.21, 0.13)
		end
	end
	bb:AddTag('HoodFadeLabel')
	arrow.Anchor, arrow.Gui, arrow.Word = anchor, bb, word
	arrow.layout('')
	arrow.Boost = 0 -- (os.clock() until which the timed hint makes it bounce bigger)
end

-- The trail: one beam per leg, the first from your feet (an attachment on your root).
local trail = { Part = nil, From = nil, Points = nil, Key = nil, Near = nil, Planned = 0 }
local okPath, PathfindingService = pcall(function() return game:GetService('PathfindingService') end)
if not okPath then PathfindingService = nil end
local function beamOf(a0, a1, first)
	local beam = Instance.new('Beam')
	beam.Name = 'OnboardingGuide'
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 1.2, 1.2
	beam.Segments = 1
	beam.Color = ColorSequence.new(GOLD)
	beam.LightEmission, beam.LightInfluence, beam.Brightness = 0.4, 0, 1
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, first and 1 or 0.15), NumberSequenceKeypoint.new(0.08, 0.15), NumberSequenceKeypoint.new(1, 0.15) })
	if HoodVFX and HoodVFX.applyTexture then HoodVFX.applyTexture(beam, 'chevron') else beam.Texture = 'rbxasset://textures/glow.png' end
	beam.TextureMode, beam.TextureLength, beam.TextureSpeed = Enum.TextureMode.Wrap, 2, 1.5
	return beam
end
local function rootOf()
	local c = player.Character
	local r = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	return r, h
end
local function feet()
	local r, h = rootOf()
	if not r then return nil end
	return r.CFrame.Position - Vector3.new(0, (h and h.HipHeight or 2) + r.Size.Y / 2, 0)
end
local function clearTrail()
	if trail.Part then trail.Part:Destroy() end
	if trail.From then trail.From:Destroy() end
	trail.Part, trail.From, trail.Points, trail.Key, trail.Near = nil, nil, nil, nil, nil
end
local function drawTrail()
	if not (trail.Part and trail.From and trail.Points) then return end
	trail.Part:ClearAllChildren()
	local prev = trail.From
	for i, p in trail.Points do
		local a = Instance.new('Attachment')
		a.Name = 'GuidePoint'
		a.CFrame = CFrame.new(p + Vector3.new(0, HOVER, 0))
		a.Parent = trail.Part
		beamOf(prev, a, i == 1).Parent = trail.Part
		prev = a
	end
end
-- A walkable route (the engine's pathfinding, no jumps), else straight: floor points, the goal last.
local function route(from, to)
	if PathfindingService then
		local ok, points = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 6 })
			path:ComputeAsync(from, to)
			if path.Status ~= Enum.PathStatus.Success then return nil end
			local out = {}
			local w = path:GetWaypoints()
			for i = 2, #w, 2 do table.insert(out, w[i].Position) end
			table.insert(out, to)
			return out
		end)
		if ok and points then return points end
	end
	return { to }
end
local function plan(goal)
	local from = feet()
	if not from then return end
	trail.Planned = os.clock()
	local key = trail.Key
	task.spawn(function()
		local points = route(from, goal)
		if trail.Key ~= key or not trail.Part then return end
		trail.Points, trail.Near = points, nil
		drawTrail()
	end)
end
local function showTrail(key, goal)
	local r, h = rootOf()
	if not r then return clearTrail() end
	if trail.Key == key and trail.Part and trail.Part.Parent and trail.From and trail.From.Parent == r then return end
	clearTrail()
	trail.Key = key
	local p = anchorPart('GuideTrail')
	p.CFrame = CFrame.new()
	trail.Part = p
	local a = Instance.new('Attachment')
	a.Name = 'OnboardingFrom'
	a.CFrame = CFrame.new(0, HOVER - ((h and h.HipHeight or 2) + r.Size.Y / 2), 0)
	a.Parent = r
	trail.From = a
	trail.Points = { goal }
	drawTrail()
	plan(goal)
end
-- Every frame: drop the turns you have reached, plan again if you wander 12+ studs off (at most every 2 s).
local function followTrail(goal)
	local points, f = trail.Points, feet()
	if not (points and f) then return end
	local reached = false
	while #points > 1 do
		local d = points[1] - f
		if Vector3.new(d.X, 0, d.Z).Magnitude < 3 and math.abs(d.Y) < 3 then
			table.remove(points, 1)
			reached = true
		else
			break
		end
	end
	if reached then
		trail.Near = nil
		drawTrail()
	end
	local d = points[1] - f
	local flat = Vector3.new(d.X, 0, d.Z).Magnitude
	trail.Near = math.min(trail.Near or flat, flat)
	if flat > trail.Near + 12 and os.clock() - trail.Planned > 2 then plan(goal) end
end

-- The ">>" pointer at the screen's edge while the target is off screen.
local compass = Instance.new('ScreenGui')
compass.Name = 'HoodOnboardingCompass'
compass.ResetOnSpawn, compass.IgnoreGuiInset, compass.Enabled, compass.DisplayOrder = false, true, false, 2
local needle = Kit.new('Frame', { Name = 'Pointer', AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(110, 70), BackgroundTransparency = 1, Parent = compass })
local bars = {}
for _, ox in { -11, 11 } do
	for _, sy in { -1, 1 } do
		local bar = Kit.new('Frame', { Name = 'Chevron', AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 11), BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = needle })
		Kit.stroke(INK, 2, true).Parent = bar
		table.insert(bars, { bar = bar, x = ox - 5, y = sy * 10, r = -sy * 45 })
	end
end
local function pointAt(target)
	local cam = workspace.CurrentCamera
	local ok, vp = pcall(function() return cam.ViewportSize end)
	if not (cam and target and ok and vp and vp.X > 1) or busy() then compass.Enabled = false return end
	local rel = cam.CFrame:PointToObjectSpace(target + Vector3.new(0, 1, 0))
	local ty = math.tan(math.rad(cam.FieldOfView) / 2)
	local tx = ty * vp.X / vp.Y
	if rel.Z < 0 and math.abs(rel.X / rel.Z) < tx * 0.85 and math.abs(rel.Y / rel.Z) < ty * 0.85 then
		compass.Enabled = false
		return
	end
	local dx, dy = rel.X, -rel.Y
	if rel.Z > 0 then dy = math.max(dy, math.abs(dx) * 0.4 + 0.5) end -- (behind you: down and to its side)
	local a = math.atan2(dy, dx)
	needle.Position = UDim2.fromOffset(vp.X / 2 + math.cos(a) * vp.X * 0.27, vp.Y / 2 + math.sin(a) * vp.Y * 0.27)
	local ca, sa = math.cos(a), math.sin(a)
	for _, b in bars do
		b.bar.Position = UDim2.fromOffset(55 + b.x * ca - b.y * sa, 35 + b.x * sa + b.y * ca)
		b.bar.Rotation = math.deg(a) + b.r
	end
	compass.Enabled = true
end

---------------------------------------------------------------------------------------------- the present
local gift = { Model = nil, At = nil, Parts = nil }
local function giftPart(model, name, size, color, material, offset)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
	p.Size, p.Color, p.Material = size, color, material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	table.insert(gift.Parts, { Part = p, Offset = offset })
	return p
end
local function buildGift(at)
	gift.Parts = {}
	local m = Instance.new('Model')
	m.Name = 'WelcomeGift'
	local red, redDark, ribbon = C(232, 70, 56), C(176, 40, 40), C(255, 204, 60)
	-- (about 4.5 studs to the bow: a kid-size present, like LOBBY5's boxes)
	local body = giftPart(m, 'Box', Vector3.new(3.4, 2.9, 3.4), red, nil, CFrame.new(0, 1.45, 0))
	body.TopSurface = Enum.SurfaceType.Studs
	local lid = giftPart(m, 'Lid', Vector3.new(3.9, 0.75, 3.9), redDark, nil, CFrame.new(0, 3.25, 0))
	lid.TopSurface = Enum.SurfaceType.Studs
	giftPart(m, 'RibbonX', Vector3.new(3.96, 3.7, 0.6), ribbon, Enum.Material.Neon, CFrame.new(0, 1.86, 0))
	giftPart(m, 'RibbonZ', Vector3.new(0.6, 3.7, 3.96), ribbon, Enum.Material.Neon, CFrame.new(0, 1.86, 0))
	giftPart(m, 'BowL', Vector3.new(1.3, 0.9, 0.55), ribbon, Enum.Material.Neon, CFrame.new(-0.55, 3.95, 0) * CFrame.Angles(0, 0, math.rad(28)))
	giftPart(m, 'BowR', Vector3.new(1.3, 0.9, 0.55), ribbon, Enum.Material.Neon, CFrame.new(0.55, 3.95, 0) * CFrame.Angles(0, 0, math.rad(-28)))
	local ring = giftPart(m, 'Glow', Vector3.new(0.12, 6.6, 6.6), ribbon, Enum.Material.Neon, CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)))
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency, ring.CastShadow = 0.55, false
	local sparkles = Instance.new('ParticleEmitter')
	sparkles.Name = 'GiftSparkles'
	sparkles.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sparkles.Rate, sparkles.Lifetime, sparkles.Speed = 9, NumberRange.new(0.8, 1.4), NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), ribbon)
	sparkles.LightEmission, sparkles.LightInfluence = 0.7, 0
	sparkles.Parent = lid
	m.Parent = folder
	gift.Model, gift.At = m, at
end
local function placeGift(t)
	if not gift.Model then return end
	local base = CFrame.new(gift.At) * CFrame.new(0, 0.15 + 0.3 * math.sin(t * 2.2), 0) * CFrame.Angles(0, t * 0.9, 0)
	for _, e in gift.Parts do
		if e.Part.Name == 'Glow' then
			e.Part.CFrame = CFrame.new(gift.At) * e.Offset
		else
			e.Part.CFrame = base * e.Offset
		end
	end
end
local function dropGift(opened)
	if not gift.Model then return end
	if opened and Juice then pcall(Juice.burst, gift.At + Vector3.new(0, 2, 0), C(255, 204, 60), 2) end
	gift.Model:Destroy()
	gift.Model, gift.At, gift.Parts = nil, nil, nil
end
local function syncGift()
	local at = attr('OnboardingGiftAt')
	if typeof(at) == 'Vector3' then
		if not gift.Model then buildGift(at) end
	elseif gift.Model then
		local f = feet()
		local d = f and gift.At - f
		dropGift(d ~= nil and Vector3.new(d.X, 0, d.Z).Magnitude < Rules.GiftRange + 2) -- (opened: you walked into it)
	end
end

---------------------------------------------------------------------------------------------- the steps
local step = nil
local hint = {} -- the timed hint's track (OnboardingRules.stuck)
local hintsLeft = Rules.StuckRepeats
local function guideOn()
	local phase = attr('GuidePhase')
	return Rules.Guided[step] == true and (phase == nil or phase == '')
end
local function inBox()
	local s = attr('TrainingStation')
	return type(s) == 'string' and s ~= '' and not s:find('Locked:')
end
local lastGun = attr('EquippedGun')
-- The nearest goon (Waves.client draws them in workspace.HoodGoons), a little over its head: FIGHT! flies to it.
local function nearestGoon()
	local f, goons = feet(), workspace:FindFirstChild('HoodGoons')
	if not (f and goons) then return nil end
	local best, bestD
	for _, m in goons:GetChildren() do
		local ok, cf = pcall(function() return m:GetPivot() end)
		if ok and cf then
			local d = (cf.Position - f).Magnitude
			if d < 80 and (not bestD or d < bestD) then best, bestD = cf.Position, d end
		end
	end
	return best and best + Vector3.new(0, 4, 0) or nil
end
local function onStep()
	local now = attr('OnboardingStep')
	if type(now) ~= 'string' or now == step then return end
	local before = step
	step = now
	hint, hintsLeft = {}, Rules.StuckRepeats
	gui:SetAttribute('Step', step) -- (for the checks: what the screen is guiding to)
	if before == 'Run' and now == 'Done' then sayLater('FIGHT!', 0.2) return end
	local word = Rules.announce(before, now)
	if not word then return end
	if now == 'Train' then sayLater(word, 0.3, now)
	elseif now == 'Door' then sayLater(word, 1.0, now)
	elseif now == 'Fight' then sayLater(word, 0.15, now, { y = CALLOUT_Y + 0.06, fly = nearestGoon }) -- (under the gate sign, off to the crew)
	elseif now == 'Cash' then sayLater(word, 2.4, now) -- (after "STAGE 2 OPEN!")
	elseif now == 'Gift' then -- (after "+10 CASH!"; not once the present is open)
		sayLater(word, 0.9, now, { still = function() return typeof(attr('OnboardingGiftAt')) == 'Vector3' end })
	elseif now == 'Gun' then sayLater(word, 0.5, now) -- (sayLater waits for the unboxing to end)
	elseif now == 'Run' then
		if before ~= 'Gun' then sayLater(word, 0.5, now) end -- (after a purchase the gun's callout comes first)
	else
		sayLater(word, 0.3, now)
	end
end
local function onGun()
	local id = attr('EquippedGun')
	if id == lastGun then return end
	local was = lastGun
	lastGun = id
	if was == nil or step == nil or step == 'Done' then return end
	local gun = Guns.ById[id]
	if not gun or gun.Multiplier <= Guns.multiplier(was) then return end
	sayLater(Rules.gunWord(gun.Multiplier), 0.2)
	task.delay(2.1, function()
		if attr('OnboardingStep') == 'Run' then sayLater(Rules.Words.Run, 0, 'Run') end
	end)
end
for _, name in { 'OnboardingStep', 'GuidePhase' } do
	player:GetAttributeChangedSignal(name):Connect(onStep)
end
player:GetAttributeChangedSignal('OnboardingGiftAt'):Connect(syncGift)
player:GetAttributeChangedSignal('EquippedGun'):Connect(onGun)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function() gui.Enabled = not windowOpen() end)

-- Every frame: the arrow bounces over the target, the trail follows you, the pointer finds it off screen, the
-- present bobs, and the timed hint watches for a stuck kid.
local targetCache, liftCache, cacheAt = nil, nil, -1
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	placeGift(t)
	local find = step and STEP_TARGET[step]
	if t - cacheAt > 0.5 then
		cacheAt = t
		if find then targetCache, liftCache = find() else targetCache, liftCache = nil, nil end
	end
	local target = targetCache
	local guiding = target ~= nil and guideOn()
	guideTarget = guiding and target or nil
	if guiding then
		showTrail(step .. tostring(target), target)
		followTrail(target)
		arrow.Anchor.CFrame = CFrame.new(target)
		arrow.layout(ARROW_WORD[step] or '')
		local big = t < arrow.Boost
		arrow.Gui.StudsOffset = Vector3.new(0, (liftCache or 4) + math.abs(math.sin(t * (big and 7 or 4))) * (big and 2.4 or 1), 0)
		arrow.Gui.Enabled = true
		pointAt(target)
	else
		if trail.Part then clearTrail() end
		arrow.Gui.Enabled = false
		compass.Enabled = false
	end
	-- the timed hint: guided steps, and LOBBY5's two (not while you train in a box, fight, or something owns the screen)
	local f = feet()
	local flat = target and f and Vector3.new(target.X - f.X, 0, target.Z - f.Z).Magnitude
	if flat and flat > 3 and step ~= 'Fight' and not inBox() and not busy() then
		if hintsLeft > 0 and Rules.stuck(hint, flat, t) then
			hintsLeft -= 1 -- (a nudge, never nagging: at most StuckRepeats a step)
			arrow.Boost = t + 2
			callout(Rules.Words[step], { why = 'hint' })
		end
	else
		hint = {}
	end
end)

player.CharacterAdded:Connect(function() clearTrail() end)
compass.Parent = playerGui
gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)
gui.Enabled = not windowOpen()
syncGift()
onStep()
