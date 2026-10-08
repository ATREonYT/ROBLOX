-- Stage gates on your screen (lighting_and_gates.md, "States" and "Pass feedback").
--   Locked   Power below the number: the force field is solid for you, the padlock shows, and the bar on
--            the barrier fills toward the number. Walk into it and it flashes red and bumps you back.
--   Ready    You have enough: the field turns green and pulses, the padlock pops off, "GO!".
--   Cleared  Already passed once (the server's count): the field and its lasers are gone.
-- Breaking through shatters the field, bursts confetti, kicks the camera and plays a rising chime; the
-- first clear of each gate also gets the big "STAGE 3 CLEARED!" banner from the server.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local frame = active.Frame

local C = Color3.fromRGB
-- State colours match the armory's (GunRules): sage for go, soft red for denied; cream text; ink strokes.
local GO, DENIED = C(79, 179, 122), C(224, 112, 112)
local CREAM, INK, GOLD = C(240, 232, 216), C(36, 38, 44), C(227, 169, 63)
local gates = {}

local function track(model)
	if gates[model] or not model:IsDescendantOf(active.Root) then return end
	gates[model] = {
		Model = model, Stage = model:GetAttribute('Stage'), Required = model:GetAttribute('Required') or 0,
		Z = model:GetAttribute('LineZ'), HalfWidth = model:GetAttribute('HalfWidth') or 20,
		Color = model:GetAttribute('Color') or GOLD, Light = model:GetAttribute('Light') or CREAM,
	}
end
for _, m in CollectionService:GetTagged('HoodStageGate') do track(m) end
CollectionService:GetInstanceAddedSignal('HoodStageGate'):Connect(track)
CollectionService:GetInstanceRemovedSignal('HoodStageGate'):Connect(function(m) gates[m] = nil end)

-- Parts and labels, collected again while the gate is still streaming in.
local function collect(e)
	if e.Barrier and e.Barrier.Parent and e.Collected then return end
	e.Barrier = e.Model:FindFirstChild('Barrier', true)
	e.Locks, e.Status, e.Fill, e.Count, e.Guis, e.Lasers = {}, {}, {}, {}, {}, {}
	for _, d in e.Model:GetDescendants() do
		if d:IsA('BasePart') and (d.Name == 'Lock' or d.Name == 'LaserNub') then table.insert(e.Locks, d)
		elseif d:IsA('TextLabel') and d.Name == 'Status' then table.insert(e.Status, d)
		elseif d:IsA('TextLabel') and d.Name == 'Count' then table.insert(e.Count, d)
		elseif d:IsA('Frame') and d.Name == 'Fill' then table.insert(e.Fill, d)
		elseif d:IsA('Beam') and d.Name == 'Laser' then table.insert(e.Lasers, d)
		end
		if d:IsA('SurfaceGui') and d.Parent == e.Barrier then table.insert(e.Guis, d) end
	end
	e.Collected = e.Barrier ~= nil
end

local function stateOf(e, power)
	if e.Stage <= (player:GetAttribute('StagesCleared') or 0) then return 'Cleared' end
	return power >= e.Required and 'Ready' or 'Locked'
end

local function paint(e, power)
	collect(e)
	local state = stateOf(e, power)
	local r = math.clamp(power / math.max(e.Required, 1), 0, 1)
	for _, f in e.Fill do f.Size = UDim2.fromScale(0.62 * r, 0.09) end
	for _, t in e.Count do t.Text = Format.compact(math.min(power, e.Required)) .. ' / ' .. Format.compact(e.Required) end
	if e.State == state and e.Painted == e.Barrier then return end
	local was = e.State
	e.State, e.Painted = state, e.Barrier
	local b = e.Barrier
	if b then
		b.CanCollide = state == 'Locked' -- only for you: your own character's collisions run on your machine
		b.Color = state == 'Ready' and GO or e.Light
		b.Transparency = state == 'Cleared' and 1 or (b:GetAttribute('BaseTransparency') or 0.62) -- the street reads behind it
	end
	for _, g in e.Guis do g.Enabled = state ~= 'Cleared' end
	for _, l in e.Lasers do l.Enabled = state == 'Locked' end
	for _, lock in e.Locks do lock.Transparency = state == 'Locked' and 0 or 1 end
	for _, t in e.Status do
		t.Text = state == 'Ready' and 'GO! →' or ('NEED 💪 ' .. Format.compact(e.Required))
		t.TextColor3 = state == 'Ready' and GO or CREAM
	end
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
local function repaint()
	local power = player:GetAttribute('Power') or 0
	for _, e in gates do paint(e, power) end
end
player:GetAttributeChangedSignal('Power'):Connect(repaint)
player:GetAttributeChangedSignal('StagesCleared'):Connect(repaint)
task.spawn(function()
	while true do
		repaint()
		task.wait(1)
	end
end)

-- Ready gates breathe so they read as "go through me".
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, e in gates do
		if e.State == 'Ready' and e.Barrier then e.Barrier.Transparency = (e.Barrier:GetAttribute('BaseTransparency') or 0.62) - 0.12 + math.sin(t * math.pi / 0.6) * 0.12 end
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
	local tStroke = stroke(t, INK, 5)
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
	d.TextColor3 = GO
	d.Parent = holder
	local dStroke = stroke(d, INK, 4)
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

-- The field shatters into shards that fly forward and fade (only on your screen).
local function shatter(e)
	local b = e.Barrier
	if not b then return end
	local cf, size = b.CFrame, b.Size
	for k = 1, 14 do
		local shard = Instance.new('Part')
		shard.Name = 'Shard'
		shard.Size = Vector3.new(2, 2, 0.3)
		shard.Material = Enum.Material.Neon
		shard.Color = k % 3 == 0 and Color3.new(1, 1, 1) or e.Light
		shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow = false, false, false, false
		shard.CFrame = cf * CFrame.new((math.random() - 0.5) * size.X * 0.9, (math.random() - 0.5) * size.Y * 0.8, 0) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		shard.Parent = workspace
		shard.AssemblyLinearVelocity = cf:VectorToWorldSpace(Vector3.new((math.random() - 0.5) * 16, 10 + math.random() * 15, -(20 + math.random() * 20)))
		shard.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		task.delay(0.8, function()
			if shard.Parent then TweenService:Create(shard, TweenInfo.new(0.8), { Transparency = 1, Size = Vector3.new(0.6, 0.6, 0.1) }):Play() end
		end)
		Debris:AddItem(shard, 2)
	end
end

local function passed(e, rootPos)
	if e.State == 'Ready' then shatter(e) end
	Juice.burst(rootPos + Vector3.new(0, 2, 0), e.Light, 2.2)
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
	local color = GOLD
	for _, e in gates do if e.Stage == info.Stage then color = e.Color end end
	showBanner('STAGE ' .. tostring(info.Stage) .. ' CLEARED!', '+' .. Format.compact(info.Reward or 0) .. ' CASH', color)
end)

-- Watch your own character cross gate lines (stages run toward -Z in the map frame).
local lastZ
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	if not root then lastZ = nil; return end
	local p = frame:PointToObjectSpace(root.Position)
	for _, e in gates do
		if math.abs(p.X) <= e.HalfWidth then
			if lastZ and lastZ >= e.Z and p.Z < e.Z and e.State ~= 'Locked' then passed(e, root.Position) end
			if e.State == 'Locked' and p.Z > e.Z and p.Z < e.Z + 3 then bump(e, root) end
		end
	end
	lastZ = p.Z
end)
