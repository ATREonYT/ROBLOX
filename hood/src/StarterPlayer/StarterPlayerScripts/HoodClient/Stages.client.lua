-- Stage gates on your screen. Each gate is a see-through haze between two pillars under a hazard beam, built LOCKED
-- (a red-tinted haze, two hazard-striped barrier bars and a big padlock), with two pads on the sidewalks in front and
-- one floating sign in the opening: "STAGE N", "Recommended", "Power: X" and a state line (the video's gate).
--   Locked   Power below the number: the wall is solid for you and stays locked-looking; the sign reads "Locked".
--            Walk into it and it flashes red and bumps you back.
--   Wave     You have the Power but the goons in the stage before this gate still stand (the server's WaveCleared,
--            the highest stage whose wave you've cleared, is below the stage before this gate): still solid and
--            locked, the sign reads "Defeat the goons first". Maps or servers without waves leave WaveCleared unset.
--   Ready    You can pass: the bars and the padlock fade away, the haze turns mint and breathes, the Power line pops
--            and the sign's badge turns green: "Open! Walk through".
--   Cleared  Already passed once (the server's count): the wall, its lock, its sign and its pads are gone (the last
--            gate's pads stay, the boss yard's way back).
-- Only your next gate shows its sign, so signs never stack down the street; it grows with the distance (up to
-- GrowMax) so it stays readable from the lobby, through the hall's doorway, and its outline thickens to match.
-- Breaking through shatters the haze, bursts confetti, kicks the camera and plays a rising chime; the first clear
-- of each gate also gets the big "STAGE 3 CLEARED!" banner from the server.
-- Map contract (TheBlockV2 stageGate): a Model tagged HoodStageGate (attributes Stage, Required, LineZ, HalfWidth,
-- Color, Light) with a Barrier part carrying the haze SurfaceGui (Frames named Pane with attributes BaseColor and
-- BaseTransparency); Lock* parts (bars and padlock: BaseTransparency); a BillboardGui named GateSign (attributes
-- BaseW, BaseH, GrowFrom, GrowPow, GrowMax) with TextLabels Title, Sub, Power and Status (the state line); Field*
-- parts (the emitter track: BaseColor, BaseTransparency); and the pads, parts named LobbyPad*/FurthestPad*
-- (BaseTransparency; the prompt, sparkles and label hang off them).
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
local GO, DENIED = C(76, 214, 130), C(236, 76, 100) -- (a notch softer than pure neon green and red)
local MINT = C(120, 235, 160) -- the ready haze
-- The sign's state line: its words and its badge's colour per state (white letters, near-black outline).
local STATUS = {
	Locked = { '🔒 Locked', C(214, 34, 58) },
	Wave = { 'Defeat the goons first', C(214, 34, 58) },
	Ready = { 'Open! Walk through', C(36, 168, 80) },
}
local gates = {}
local door -- the hall's doorway (gate 1's attributes DoorHalf, DoorTop, DoorZ): a grown sign must fit through it
local lastStage = 0 -- the furthest gate on the map (its pads never hide)

local function track(model)
	if gates[model] or not model:IsDescendantOf(active.Root) then return end
	lastStage = math.max(lastStage, model:GetAttribute('Stage') or 0)
	gates[model] = {
		Model = model, Stage = model:GetAttribute('Stage'), Required = model:GetAttribute('Required') or 0,
		Z = model:GetAttribute('LineZ'), HalfWidth = model:GetAttribute('HalfWidth') or 20,
		Color = model:GetAttribute('Color') or C(255, 210, 60), Light = model:GetAttribute('Light') or C(255, 236, 160),
		OpenHalf = model:GetAttribute('OpenHalf') or 18, OpenTop = model:GetAttribute('OpenTop') or 18.5,
		FrameHalf = model:GetAttribute('FrameHalf') or 22, FrameTop = model:GetAttribute('FrameTop') or 24,
	}
	if model:GetAttribute('DoorHalf') then
		door = { Half = model:GetAttribute('DoorHalf'), Top = model:GetAttribute('DoorTop') or 30, Z = model:GetAttribute('DoorZ') or 7 }
	end
end
for _, m in CollectionService:GetTagged('HoodStageGate') do track(m) end
CollectionService:GetInstanceAddedSignal('HoodStageGate'):Connect(track)
CollectionService:GetInstanceRemovedSignal('HoodStageGate'):Connect(function(m) gates[m] = nil end)

-- Parts and labels, collected again while the gate is still streaming in.
local function collect(e)
	if e.Barrier and e.Barrier.Parent and e.Collected then return end
	e.Barrier = e.Model:FindFirstChild('Barrier', true)
	e.Sign = e.Model:FindFirstChild('GateSign', true)
	e.Plate = e.Sign and e.Sign:FindFirstChild('StatusPlate')
	e.Panes, e.Lines, e.Guis, e.Pads, e.Fields, e.Status, e.Locks, e.Strokes = {}, {}, {}, {}, {}, {}, {}, {}
	for _, d in e.Model:GetDescendants() do
		if d:IsA('Frame') and d.Name == 'Pane' then table.insert(e.Panes, d)
		elseif d:IsA('BasePart') and d.Name:sub(1, 5) == 'Field' then table.insert(e.Fields, d)
		elseif d:IsA('BasePart') and d.Name:sub(1, 4) == 'Lock' then table.insert(e.Locks, d)
		elseif d:IsA('TextLabel') and d.Name == 'Status' then table.insert(e.Status, d)
		elseif d:IsA('BasePart') and (d.Name:sub(1, 8) == 'LobbyPad' or d.Name:sub(1, 11) == 'FurthestPad') then table.insert(e.Pads, d)
		elseif d:IsA('TextLabel') and (d.Name == 'Power' or d.Name == 'Sub') then
			table.insert(e.Lines, d)
			if d:GetAttribute('BaseColor') == nil then d:SetAttribute('BaseColor', d.TextColor3) end
			local stroke = d:FindFirstChildOfClass('UIStroke')
			if stroke and stroke:GetAttribute('BaseColor') == nil then stroke:SetAttribute('BaseColor', stroke.Color) end
		end
		if d:IsA('SurfaceGui') and d.Parent == e.Barrier then table.insert(e.Guis, d) end
		-- (the sign's letter outlines: the share of the sign's height their line takes, times its Ink share, gives the
		-- thickness from the sign's height on screen)
		if d:IsA('UIStroke') and e.Sign and d:IsDescendantOf(e.Sign) and d.Parent:IsA('TextLabel') then
			table.insert(e.Strokes, { d, d.Parent.Size.Y.Scale * (d.Parent:GetAttribute('Ink') or 0.1) })
		end
	end
	e.Collected = e.Barrier ~= nil
end

local function stateOf(e, power)
	if e.Stage <= (player:GetAttribute('StagesCleared') or 0) then return 'Cleared' end
	if power < e.Required then return 'Locked' end
	local wave = player:GetAttribute('WaveCleared')
	if type(wave) == 'number' and e.Stage > 1 and wave < e.Stage - 1 then return 'Wave' end
	return 'Ready'
end
local function shut(state) return state == 'Locked' or state == 'Wave' end

-- The haze in a state: its own locked red bands, mint while ready, a red flash when it stops you.
local function tint(e, toward, amount)
	for _, f in e.Panes do
		local base = f:GetAttribute('BaseColor') or f.BackgroundColor3
		f.BackgroundColor3 = toward and base:Lerp(toward, amount) or base
	end
	for _, p in e.Fields do
		local base = p:GetAttribute('BaseColor') or p.Color
		p.Color = toward and base:Lerp(toward, amount) or base
	end
end
local function breathe(e, k)
	for _, f in e.Panes do f.BackgroundTransparency = math.clamp((f:GetAttribute('BaseTransparency') or 0.5) + k, 0, 1) end
end

local function paint(e, power, nextStage)
	collect(e)
	local state = stateOf(e, power)
	local signed = e.Stage == nextStage
	if e.State == state and e.Painted == e.Barrier and e.Last == lastStage and e.Signed == signed then return end
	local was = e.State
	e.State, e.Painted, e.Last, e.Signed = state, e.Barrier, lastStage, signed
	local b = e.Barrier
	if b then
		b.CanCollide = shut(state) -- only for you: your own character's collisions run on your machine
		b.Transparency = b:GetAttribute('BaseTransparency') or 1
	end
	for _, g in e.Guis do g.Enabled = state ~= 'Cleared' end
	-- Only your next gate shows its sign (HoodClient/Stages grows it with the distance, below).
	if e.Sign then e.Sign.Enabled = signed and state ~= 'Cleared' end
	for _, p in e.Fields do p.Transparency = state == 'Cleared' and 1 or (p:GetAttribute('BaseTransparency') or 0) end
	-- The lock (bars and padlock) stays while the gate is shut for you and fades away the moment it opens.
	for _, tween in e.Fades or {} do tween:Cancel() end
	e.Fades = {}
	for _, p in e.Locks do
		local base = p:GetAttribute('BaseTransparency') or 0
		if shut(state) then
			p.Transparency = base
		elseif shut(was) and state == 'Ready' then
			local tween = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			table.insert(e.Fades, tween)
			tween:Play()
		else
			p.Transparency = 1
		end
	end
	local padsOff = state == 'Cleared' and e.Stage < lastStage
	for _, pad in e.Pads do
		pad.Transparency = padsOff and 1 or (pad:GetAttribute('BaseTransparency') or 0)
		for _, x in pad:GetDescendants() do
			if x:IsA('ProximityPrompt') or x:IsA('ParticleEmitter') or x:IsA('BillboardGui') then x.Enabled = not padsOff end
		end
	end
	local look = STATUS[state]
	for _, t in e.Status do
		t.Visible = look ~= nil
		if look then t.Text = look[1] end
	end
	if e.Plate then
		e.Plate.Visible = look ~= nil
		if look then e.Plate.BackgroundColor3 = look[2] end
	end
	tint(e, state == 'Ready' and MINT or nil, 0.85)
	breathe(e, 0)
	-- (The lines keep their cyan in every state: the green badge says "open", and green on the mint haze would blur.)
	for _, t in e.Lines do
		t.TextColor3 = t:GetAttribute('BaseColor') or t.TextColor3
		local stroke = t:FindFirstChildOfClass('UIStroke')
		if stroke then stroke.Color = stroke:GetAttribute('BaseColor') or stroke.Color end
	end
	-- The moment a gate opens for you: a quick pop of the Power line.
	if shut(was) and state == 'Ready' then
		for _, t in e.Lines do
			if t.Name == 'Power' then
				local s = t:FindFirstChildOfClass('UIScale') or Instance.new('UIScale')
				s.Parent = t
				s.Scale = 1.4
				TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end
	end
end
local function repaint()
	local power = player:GetAttribute('Power') or 0
	local nextStage = (player:GetAttribute('StagesCleared') or 0) + 1
	for _, e in gates do paint(e, power, nextStage) end
end
player:GetAttributeChangedSignal('Power'):Connect(repaint)
player:GetAttributeChangedSignal('StagesCleared'):Connect(repaint)
player:GetAttributeChangedSignal('WaveCleared'):Connect(repaint)
task.spawn(function()
	while true do
		repaint()
		task.wait(1)
	end
end)

-- The sign grows with the distance so it reads from the lobby: base size x clamp((d / GrowFrom)^GrowPow, 1, GrowMax),
-- upward from its foot (it stays clear of the padlock under it), but never past what the openings in front of it leave
-- in view from the camera: the hall's doorway (when you're in the hall), the openings of the gates between you and it,
-- and its own gate's frame outline. Its outlines keep their share of each line's height on your screen (UI2's ~7-11%),
-- so the letters keep a thick dark edge near and far.
local MARGIN = 0.6
-- Does the sign at scale f stay inside every opening in front of it, as the camera sees it? The sign is a card facing
-- the camera, standing on its foot (map frame); an opening is a rectangle x -half..half, y 0..top in the plane z (map
-- frame) between the camera and the sign: the card's corners, in camera space over depth, must fall inside the
-- opening's corners (its bottom is the ground, which hides the card's foot anyway).
local function fits(cam, f, w, h, foot, windows)
	local center = cam:PointToObjectSpace(frame:PointToWorldSpace(foot + Vector3.new(0, h * f / 2, 0)))
	local depth = -center.Z
	if depth < 1 then return true end
	local x0, x1 = (center.X - w * f / 2) / depth, (center.X + w * f / 2) / depth
	local y1 = (center.Y + h * f / 2) / depth
	for _, o in windows do
		local half, top = o[1] - MARGIN, o[2] - MARGIN
		local lo, hi, roof = -math.huge, math.huge, math.huge
		for _, k in { { -half, 0 }, { -half, top }, { half, 0 }, { half, top } } do
			local p = cam:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(k[1], k[2], o[3])))
			if -p.Z < 0.5 then return true end -- (an opening beside or behind the camera hides nothing we can judge)
			local x, y = p.X / -p.Z, p.Y / -p.Z
			if k[1] < 0 then lo = math.max(lo, x) else hi = math.min(hi, x) end
			if k[2] > 0 then roof = math.min(roof, y) end
		end
		if x0 < lo or x1 > hi or y1 > roof then return false end
	end
	return true
end
-- The largest scale up to f that fits: the hall's doorway (when you're in the hall), the openings of the gates
-- between you and the sign, and its own gate's frame outline (never wider or taller than the frame it stands in).
local function fit(e, cam, f, w, h, foot)
	local c = frame:PointToObjectSpace(cam.Position)
	f = math.min(f, 2 * e.FrameHalf / w, (e.FrameTop - foot.Y) / h)
	local windows = {}
	if door and c.Z > door.Z and door.Z > foot.Z then table.insert(windows, { door.Half, door.Top, door.Z }) end
	for _, o in gates do
		local z = o.Z and o.Z + 1.5
		if o ~= e and z and c.Z > z and z > foot.Z then table.insert(windows, { o.OpenHalf, o.OpenTop, z }) end
	end
	if f <= 1 or fits(cam, f, w, h, foot, windows) then return math.max(1, f) end
	local lo, hi = 1, f -- (bisect: the card only gets bigger with f)
	for _ = 1, 8 do
		local mid = (lo + hi) / 2
		if fits(cam, mid, w, h, foot, windows) then lo = mid else hi = mid end
	end
	return lo
end
local function grow(e, cam)
	local sign = e.Sign
	local anchor = sign.Parent
	if not (anchor and anchor:IsA('BasePart')) then return end
	local at = anchor.CFrame.Position
	local d = math.max(1, (cam.CFrame.Position - at).Magnitude)
	local w, h = sign:GetAttribute('BaseW') or sign.Size.X.Scale, sign:GetAttribute('BaseH') or sign.Size.Y.Scale
	local f = math.clamp((d / (sign:GetAttribute('GrowFrom') or 80)) ^ (sign:GetAttribute('GrowPow') or 1), 1, sign:GetAttribute('GrowMax') or 1)
	if f > 1 then f = fit(e, cam.CFrame, f, w, h, frame:PointToObjectSpace(at)) end
	if math.abs(f - (e.Grown or 0)) > 0.01 then
		e.Grown = f
		sign.Size = UDim2.fromScale(w * f, h * f)
		sign.StudsOffsetWorldSpace = Vector3.new(0, h * f / 2, 0)
	end
	local vh = cam.ViewportSize.Y
	if vh < 100 then vh = 720 end -- (ViewportSize can read 1 x 1 for a frame at startup)
	local px = h * f / d * vh / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	for _, s in e.Strokes do s[1].Thickness = math.clamp(px * s[2], 1.5, 8) end
end

-- Ready gates breathe so they read as "go through me".
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	for _, e in gates do
		if e.State == 'Ready' then breathe(e, -0.08 + math.sin(t * math.pi / 0.6) * 0.08) end
		if cam and e.Sign and e.Sign.Enabled then grow(e, cam) end
	end
end)

---------------------------------------------------------------------------------------------- feedback
local gui = Instance.new('ScreenGui')
gui.Name = 'StageFeedback'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild('PlayerGui')

-- (COMBAT: every game sound is behind Config/Sound, off for now: these are nil while it is.)
local Sound = require(RS.Shared.Config.Sound)
local function sound(id, volume)
	return Sound.new(id, volume, gui)
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

-- The haze shatters into shards that fly forward and fade (only on your screen).
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
	Sound.play(chime, 1 + math.min(e.Stage, 10) * 0.03)
	local fx = e.Model:FindFirstChild('PassFX', true)
	if fx and fx:IsA('ParticleEmitter') then fx:Emit(60) end
end

-- Walking into a shut gate: red flash, a bump back toward the lobby, and what you still need.
local lastBump = 0
local function bump(e, root)
	if os.clock() - lastBump < 0.8 then return end
	lastBump = os.clock()
	tint(e, DENIED, 0.55)
	task.delay(0.2, function() if shut(e.State) then tint(e, nil) end end)
	root.AssemblyLinearVelocity = frame:VectorToWorldSpace(Vector3.new(0, 15, 40))
	Sound.play(buzz)
	local power = player:GetAttribute('Power') or 0
	local why = e.State == 'Wave' and 'DEFEAT THE GOONS FIRST!' or ('🔒 NEED ' .. Format.compact(math.max(0, e.Required - power)) .. ' MORE POWER')
	Juice.popNumber(root.Position + Vector3.new(0, 4, 0), why, DENIED)
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
	local p = frame:PointToObjectSpace(root.Position)
	for _, e in gates do
		if math.abs(p.X) <= e.HalfWidth then
			if lastZ and lastZ >= e.Z and p.Z < e.Z and not shut(e.State) then passed(e, root.Position) end
			if shut(e.State) and p.Z > e.Z and p.Z < e.Z + 3 then bump(e, root) end
		end
	end
	lastZ = p.Z
end)
