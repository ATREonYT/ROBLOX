-- Stage gates on your screen (Brief 9: one plain checkpoint per gate, the same for all 16).
--   Locked   Power below the number: the sliding gate stays shut with its chain and padlock. The plaque on it
--            shows the number and your progress bar ("🎯 TRAIN AT THE RANGE" before your first Power). The field
--            (Barrier) is solid for you and shows only while you stand near the gate. Walk into it and it flashes
--            red and bumps you back.
--   Ready    You have enough: the chain and padlock drop away, the gate slides open behind the railing, and its
--            plaque turns green ("GO!").
--   Cleared  Already passed once (the server's count): the gate stands open.
-- Walking through bursts confetti, kicks the camera and plays a rising chime. The first clear of each gate also gets
-- the big "STAGE 3 CLEARED!" banner from the server.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local frame = active.Frame

local C = Color3.fromRGB
local DENIED = C(236, 76, 100) -- the field's flash when you bump it (a notch softer than pure neon red)
local PLAQUE_GO = C(46, 138, 84) -- the plaque's face once you can pass
local NEAR, FAR = 10, 26 -- the field shows fully within NEAR studs of a gate you can't pass yet, and not past FAR
local gates = {}

local function track(model)
	if gates[model] or not model:IsDescendantOf(active.Root) then return end
	gates[model] = {
		Model = model, Stage = model:GetAttribute('Stage'), Required = model:GetAttribute('Required') or 0,
		Z = model:GetAttribute('LineZ'), HalfWidth = model:GetAttribute('HalfWidth') or 20,
		Color = model:GetAttribute('Color') or C(255, 210, 60), Light = model:GetAttribute('Light') or C(206, 222, 240),
	}
end
for _, m in CollectionService:GetTagged('HoodStageGate') do track(m) end
CollectionService:GetInstanceAddedSignal('HoodStageGate'):Connect(track)
CollectionService:GetInstanceRemovedSignal('HoodStageGate'):Connect(function(m) gates[m] = nil end)

-- Parts and labels, collected again if the gate streams out and back in (it streams whole: Atomic).
local function collect(e)
	if e.Barrier and e.Barrier.Parent and e.Collected then return end
	e.Barrier = e.Model:FindFirstChild('Barrier', true)
	e.Locks, e.Status, e.Fill, e.Count, e.Tracks, e.Plaques, e.Slides = {}, {}, {}, {}, {}, {}, {}
	for _, d in e.Model:GetDescendants() do
		if d:IsA('BasePart') and d.Name == 'Lock' then table.insert(e.Locks, d)
		elseif d:IsA('TextLabel') and d.Name == 'Status' then table.insert(e.Status, d)
		elseif d:IsA('TextLabel') and d.Name == 'Count' then table.insert(e.Count, d)
		elseif d:IsA('Frame') and d.Name == 'Fill' then table.insert(e.Fill, d)
		elseif d:IsA('Frame') and d.Name == 'Track' then table.insert(e.Tracks, d)
		end
		if d:IsA('BasePart') and d.Name == 'GatePlaque' then table.insert(e.Plaques, d) end
		-- the sliding gate's parts, with where they stand shut
		if d:IsA('BasePart') and d.Parent and d.Parent.Name == 'GateSlide' then table.insert(e.Slides, { Part = d, Home = d.CFrame }) end
	end
	e.Collected = e.Barrier ~= nil
end

local function stateOf(e, power)
	if e.Stage <= (player:GetAttribute('StagesCleared') or 0) then return 'Cleared' end
	return power >= e.Required and 'Ready' or 'Locked'
end

-- Shut or open the sliding gate (by the gate's SlideOffset, map frame), sliding when it changes in front of you.
local function slide(e, open, animate)
	local offset = e.Model:GetAttribute('SlideOffset')
	if typeof(offset) ~= 'Vector3' then return end
	local shift = frame:VectorToWorldSpace(offset)
	for _, s in e.Slides do
		local goal = open and s.Home + shift or s.Home
		if animate then
			TweenService:Create(s.Part, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
		else
			s.Part.CFrame = goal
		end
	end
end

local function paint(e, power)
	collect(e)
	local state = stateOf(e, power)
	local r = math.clamp(power / math.max(e.Required, 1), 0, 1)
	-- The plaque: the big number always; under it the bar and count while you're short, or one status line: where to
	-- start (a new player, no Power yet), GO! once you can pass, a tick once you have.
	local bar = state == 'Locked' and power > 0
	for _, f in e.Fill do
		local full = f.Parent and f.Parent:FindFirstChild('Track')
		f.Size = UDim2.fromScale((full and full.Size.X.Scale or 0.76) * r, full and full.Size.Y.Scale or 0.24)
		f.Visible = bar
	end
	for _, f in e.Tracks do f.Visible = bar end
	for _, t in e.Count do
		t.Text = Format.compact(math.min(power, e.Required)) .. ' / ' .. Format.compact(e.Required)
		t.Visible = bar
	end
	for _, t in e.Status do
		t.Text = state == 'Ready' and 'GO! →' or state == 'Cleared' and '✓ OPEN' or '🎯 TRAIN AT THE RANGE'
		t.Visible = not bar
	end
	-- The chain and padlock show while you're short.
	for _, lock in e.Locks do lock.Transparency = state == 'Locked' and 0 or 1 end
	if e.State == state and e.Painted == e.Barrier then return end
	local was = e.State
	e.State, e.Painted = state, e.Barrier
	local b = e.Barrier
	if b then
		b.CanCollide = state == 'Locked' -- only for you: your own character's collisions run on your machine
		b.Color = e.Light
		if state ~= 'Locked' then b.Transparency = 1 end -- (while locked, the walk-up fade below sets it)
	end
	for _, p in e.Plaques do
		if p:GetAttribute('BaseColor') == nil then p:SetAttribute('BaseColor', p.Color) end
		p.Color = state == 'Ready' and PLAQUE_GO or p:GetAttribute('BaseColor')
	end
	-- Open once you can pass; it slides if you watch it happen, and is simply set on a first paint.
	slide(e, state ~= 'Locked', was ~= nil and (was == 'Locked') ~= (state == 'Locked'))
	-- The moment a gate opens for you: a quick pop of the status text.
	if was == 'Locked' and state == 'Ready' then
		for _, t in e.Status do
			local s = t:FindFirstChildOfClass('UIScale') or Instance.new('UIScale')
			s.Parent = t
			s.Scale = 1.4
			TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
end
-- The lobby's exit monitor follows gate 1: train first / you can go / cleared (its label ExitStatus; the map's
-- own text is the locked line).
local exitLabel, exitLook = nil, 0
local function paintExit()
	if not (exitLabel and exitLabel.Parent) then
		if os.clock() - exitLook < 5 then return end
		exitLook = os.clock()
		local monitor = active.Root:FindFirstChild('ExitMonitor', true)
		exitLabel = monitor and monitor:FindFirstChild('ExitStatus', true)
		if not exitLabel then return end
		exitLabel:SetAttribute('BaseText', exitLabel.Text)
		exitLabel:SetAttribute('BaseColor', exitLabel.TextColor3)
	end
	local state
	for _, e in gates do if e.Stage == 1 then state = e.State end end
	if not state then return end
	exitLabel.Text = state == 'Ready' and '✅ YOU CAN GO! WALK IN' or state == 'Cleared' and '🏁 STAGE 1 CLEARED' or exitLabel:GetAttribute('BaseText')
	exitLabel.TextColor3 = state == 'Ready' and C(150, 236, 160) or state == 'Cleared' and Color3.new(1, 1, 1) or exitLabel:GetAttribute('BaseColor')
end
local function repaint()
	local power = player:GetAttribute('Power') or 0
	for _, e in gates do paint(e, power) end
	paintExit()
end
player:GetAttributeChangedSignal('Power'):Connect(repaint)
player:GetAttributeChangedSignal('StagesCleared'):Connect(repaint)
task.spawn(function()
	while true do
		repaint()
		task.wait(1)
	end
end)

-- The field of a gate you can't pass yet fades in as you walk up to it (invisible from down the street).
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local p = root and frame:PointToObjectSpace(root.CFrame.Position)
	for _, e in gates do
		local b = e.Barrier
		if e.State == 'Locked' and b and b.Parent then
			local d = p and math.abs(p.Z - e.Z) + math.max(0, math.abs(p.X) - e.HalfWidth) or FAR
			local k = math.clamp((FAR - d) / (FAR - NEAR), 0, 1)
			b.Transparency = 1 - k * (1 - (b:GetAttribute('BaseTransparency') or 0.8))
		end
	end
end)

---------------------------------------------------------------------------------------------- feedback
local gui = Instance.new('ScreenGui')
gui.Name = 'StageFeedback'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild('PlayerGui')

local function sound(id, volume)
	local s = Instance.new('Sound')
	s.SoundId = id
	s.Volume = volume
	s.Parent = gui
	return s
end
local chime = sound('rbxasset://sounds/electronicpingshort.wav', 0.6)
local buzz = sound('rbxasset://sounds/button.wav', 0.5)

local function stroke(parent, color, thickness)
	local s = Instance.new('UIStroke')
	s.Color = color
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- Big centred banner: pops in with an overshoot, holds, then floats up and fades.
local banner
local function showBanner(title, detail, color)
	if banner then banner:Destroy() end
	local holder = Instance.new('Frame')
	holder.Name = 'Banner'
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromOffset(640, 150)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	banner = holder
	local scale = Instance.new('UIScale')
	scale.Scale = 0.3
	scale.Parent = holder
	local t = Instance.new('TextLabel')
	t.Name = 'Title'
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 92)
	t.FontFace = Font.new('rbxasset://fonts/families/LuckiestGuy.json')
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = holder
	local tStroke = stroke(t, C(28, 24, 48), 5)
	local g = Instance.new('UIGradient')
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	g.Rotation = 90
	g.Parent = t
	local d = Instance.new('TextLabel')
	d.Name = 'Detail'
	d.BackgroundTransparency = 1
	d.Position = UDim2.fromOffset(0, 94)
	d.Size = UDim2.new(1, 0, 0, 44)
	d.FontFace = Font.new('rbxasset://fonts/families/LuckiestGuy.json')
	d.TextScaled = true
	d.Text = detail
	d.TextColor3 = C(90, 255, 120)
	d.Parent = holder
	local dStroke = stroke(d, C(28, 24, 48), 4)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if banner ~= holder then return end
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.24) }):Play()
		for _, x in { t, d } do TweenService:Create(x, fade, { TextTransparency = 1 }):Play() end
		for _, x in { tStroke, dStroke } do TweenService:Create(x, fade, { Transparency = 1 }):Play() end
		task.delay(0.45, function() if banner == holder then holder:Destroy(); banner = nil end end)
	end)
end

-- Short field-of-view punch for the break-through.
local function fovKick()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local base = cam.FieldOfView
	local out = TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + 8 })
	out.Completed:Once(function()
		TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FieldOfView = base }):Play()
	end)
	out:Play()
end

local function passed(e, rootPos)
	Juice.burst(rootPos + Vector3.new(0, 2, 0), e.Color, 2.2)
	Juice.kick(0.45)
	fovKick()
	chime.PlaybackSpeed = 1 + math.min(e.Stage, 10) * 0.03
	chime:Play()
	local fx = e.Model:FindFirstChild('PassFX', true)
	if fx and fx:IsA('ParticleEmitter') then fx:Emit(60) end
end

-- Walking into a locked gate: red flash, a bump back toward the lobby, and how much more you need.
local lastBump = 0
local function bump(e, root)
	if os.clock() - lastBump < 0.8 then return end
	lastBump = os.clock()
	local b = e.Barrier
	if b then
		b.Color = DENIED
		task.delay(0.2, function() if e.State == 'Locked' and b.Parent then b.Color = e.Light end end)
	end
	root.AssemblyLinearVelocity = frame:VectorToWorldSpace(Vector3.new(0, 15, 40))
	buzz:Play()
	local power = player:GetAttribute('Power') or 0
	Juice.popNumber(root.Position + Vector3.new(0, 4, 0), 'NEED ' .. Format.compact(math.max(0, e.Required - power)) .. ' MORE 💪', DENIED)
end

Net.get('Cinematic').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or info.Kind ~= 'StageClear' then return end
	local color = C(255, 210, 60)
	for _, e in gates do if e.Stage == info.Stage then color = e.Color end end
	showBanner('STAGE ' .. tostring(info.Stage) .. ' CLEARED!', '+' .. Format.compact(info.Reward or 0) .. ' CASH', color)
end)

-- Watch your own character cross gate lines (stages run toward -Z in the map frame).
local lastZ
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	if not root then lastZ = nil; return end
	local p = frame:PointToObjectSpace(root.CFrame.Position)
	for _, e in gates do
		if math.abs(p.X) <= e.HalfWidth then
			if lastZ and lastZ >= e.Z and p.Z < e.Z and e.State ~= 'Locked' then passed(e, root.Position) end
			if e.State == 'Locked' and p.Z > e.Z and p.Z < e.Z + 3 then bump(e, root) end
		end
	end
	lastZ = p.Z
end)
