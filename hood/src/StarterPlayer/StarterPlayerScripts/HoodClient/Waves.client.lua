-- Stage target waves on your screen. The server decides everything (WaveService, Shared/WaveRules); this shows it.
--   Targets: each stage's little plywood range (map: TheBlockV2 Waves.build, Models tagged HoodWaveTarget with a
--     Hinge + Swing like the ranges' targets and a WaveTag billboard: Name, Bar, Fill, HP). Your own wave's HP is
--     painted on their tags, which show only in the stage you stand in. A target you knock down tips back, bursts
--     into confetti and is gone for you only (other players see their own waves); a wave you come back to after
--     clearing it stands up again.
--   Shooting: while you stand in a stage with targets up (the server's WaveLeft), your gun comes out by itself and
--     click / R2 / the SHOOT button fires at the target nearest the middle of your screen (it keeps the trigger
--     while it stands), with the ranges' feel: muzzle flash, tracer, sparks, a knock, the running "+N" by the target.
--     Shoot.client stands down while you're in a wave (its dry shot would double these).
--   HUD: "N LEFT" with a target icon at the top centre (the HUD's hint line gives way), and "WAVE CLEARED!" with
--     the Cash a first clear paid.
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)
local Guns = require(RS.Shared.Config.Guns)
local Skins = require(RS.Shared.Config.Skins)
local ShotRules = require(RS.Shared.ShotRules)
local WaveRules = require(RS.Shared.WaveRules)
local GunTool = require(RS.Shared.GunTool)
local Kit = require(RS.Shared.UIKit)
local ShotSounds = require(RS.Shared.ShotSounds)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
ShotSounds.init()
local play = ShotSounds.play
local remote = Net.get('WaveShot')
local function worldOf(att) return att.Parent.CFrame * att.CFrame end -- (an attachment's WorldCFrame, spelled out)

---------------------------------------------------------------------------------------------- the targets
local targets = {} -- [stage][index] = entry
local known = {} -- [stage] = { HP = {}, Max = {} }: the last the server told us
local current = 0 -- the stage you stand in (with targets), WaveStage
local pending = {} -- [index] = { { damage, time }, ... }: your shots in this stage the server hasn't answered yet
local PENDING_FOR = 1.2 -- seconds an unanswered shot still counts (a dropped one is forgotten after this)

local function pendingSum(index)
	local list, sum = pending[index], 0
	if not list then return 0 end
	local now = os.clock()
	for i = #list, 1, -1 do
		if now - list[i][2] > PENDING_FOR then table.remove(list, i) else sum += list[i][1] end
	end
	return sum
end
local function maxOf(e)
	local k = known[e.Stage]
	return k and k.Max[e.Index] or WaveRules.maxHp(e.Stage, e.Kind)
end
local function hpOf(e)
	local k = known[e.Stage]
	local hp = k and k.HP[e.Index]
	if hp == nil then hp = maxOf(e) end
	return hp
end
-- What the tag shows: your HP with your own shots in flight taken off, so the bar moves when you fire.
local function shownOf(e)
	local hp = hpOf(e)
	if e.Stage == current then hp -= pendingSum(e.Index) end
	return math.max(0, hp)
end

local function setHidden(e, hidden)
	for part, t in e.Parts do
		if part.Parent then part.Transparency = hidden and 1 or t end
	end
end
-- A tag shows only on a standing target in the stage you stand in (the next stage's would show through its gate's
-- haze, between the gate's text lines).
local function showTag(e)
	if e.Gui then e.Gui.Enabled = not e.Down and e.Stage == current end
end
-- Down for good (until the wave respawns): a big tip back, then confetti and gone.
local function knockDown(e, animate)
	e.Down = true
	showTag(e)
	if not animate then
		setHidden(e, true)
		return
	end
	if e.Knocker then e.Knocker:hit(2.4) end
	task.delay(0.16, function()
		if not e.Down then return end
		Juice.shards(e.Aim, e.Shard, 'confetti')
		Juice.burst(e.Aim, e.Shard or Color3.new(1, 1, 1), 1.6)
		play('Pop', 0.9)
		setHidden(e, true)
	end)
end
local function standUp(e, animate)
	e.Down = false
	setHidden(e, false)
	showTag(e)
	if animate then Juice.burst(e.Aim, Color3.new(1, 1, 1), 0.9) end
end

local function paint(e, animate)
	local max, hp = maxOf(e), hpOf(e)
	local shown = shownOf(e)
	if e.HP then e.HP.Text = Format.compact(math.ceil(shown)) .. '/' .. Format.compact(max) end
	if e.Fill then e.Fill.Size = UDim2.fromScale(e.BarW * math.clamp(shown / math.max(1, max), 0, 1), e.Fill.Size.Y.Scale) end
	if hp <= 0 and not e.Down then knockDown(e, animate)
	elseif hp > 0 and e.Down then standUp(e, animate) end
	showTag(e)
end
local function paintStage(stage, animate)
	for _, e in targets[stage] or {} do paint(e, animate) end
end

local function track(model)
	if not model:IsA('Model') or not model:IsDescendantOf(active.Root) then return end
	local stage, index, aim = model:GetAttribute('Stage'), model:GetAttribute('Index'), model:GetAttribute('Aim')
	if type(stage) ~= 'number' or type(index) ~= 'number' or typeof(aim) ~= 'Vector3' then return end
	local gui = model:FindFirstChild('WaveTag', true)
	local e = {
		Model = model, Stage = stage, Index = index, Kind = model:GetAttribute('Kind'), Aim = aim,
		Hit = model:GetAttribute('Hit') or 'Tock', Shard = model:GetAttribute('ShardColor'),
		Knocker = Juice.knocker(model), Gui = gui, Fill = gui and gui:FindFirstChild('Fill'), HP = gui and gui:FindFirstChild('HP'),
		BarW = gui and gui:GetAttribute('BarW') or 0.84, Parts = {}, Down = false,
	}
	local swing = model:FindFirstChild('Swing')
	for _, p in (swing and swing:GetDescendants() or {}) do
		if p:IsA('BasePart') then e.Parts[p] = p.Transparency end
	end
	targets[stage] = targets[stage] or {}
	targets[stage][index] = e
	paint(e, false)
end
local function untrack(model)
	for _, list in targets do
		for index, e in list do
			if e.Model == model then list[index] = nil end
		end
	end
end
for _, m in CollectionService:GetTagged('HoodWaveTarget') do track(m) end
CollectionService:GetInstanceAddedSignal('HoodWaveTarget'):Connect(track)
CollectionService:GetInstanceRemovedSignal('HoodWaveTarget'):Connect(untrack)

---------------------------------------------------------------------------------------------- the HUD
local gui, root, fit = Kit.screen('HoodWaves', nil, 6)
-- "N LEFT" at the top centre, in the HUD's ink-outlined sticker style, a red-and-white target as its icon.
local pill = Kit.new('Frame', { Name = 'WaveLeft', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(196, 46), BackgroundColor3 = Kit.Color.asphalt, BorderSizePixel = 0, Visible = false, Parent = root })
Kit.corner(8).Parent = pill -- (brief 17: the HUD's block style)
Kit.stroke(Kit.Color.ink, 3.5, true).Parent = pill
Kit.gradient(Kit.hex('3B3F5C'), Kit.Color.asphalt, 0.5).Parent = pill
local pillScale = Kit.new('UIScale', { Parent = pill })
local icon = Kit.new('Frame', { Name = 'Target', AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Parent = pill })
for k, ring in { { 34, Kit.Color.white }, { 26, Kit.hex('E23A3A') }, { 17, Kit.Color.white }, { 8, Kit.hex('E23A3A') } } do
	local r = Kit.new('Frame', { Name = 'Ring' .. k, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(ring[1], ring[1]), BackgroundColor3 = ring[2], BorderSizePixel = 0, ZIndex = 1 + k, Parent = icon })
	Kit.corner(UDim.new(0.5, 0)).Parent = r
	if k == 1 then Kit.stroke(Kit.Color.ink, 2.5, true).Parent = r end
end
local leftText = Kit.text({ Name = 'Count', Text = '3 LEFT', TextSize = 32, Stroke = Kit.Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(50, 2), Size = UDim2.new(1, -56, 1, 0), ZIndex = 3, Parent = pill })

local function showLeft()
	local left = player:GetAttribute('WaveLeft')
	local on = type(left) == 'number' and left > 0
	if on then
		local text = left .. ' LEFT'
		if leftText.Text ~= text and pill.Visible then
			pillScale.Scale = 1.22
			TweenService:Create(pillScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		leftText.Text = text
	end
	pill.Visible = on
end

-- The big centred banner (the same pop-hold-float as the STAGE CLEARED one).
local chime = Instance.new('Sound')
chime.SoundId = 'rbxasset://sounds/electronicpingshort.wav'
chime.Volume = 0.6
chime.Parent = gui
local banner
local function showBanner(title, detail, color)
	if banner then banner:Destroy() end
	local holder = Kit.new('Frame', { Name = 'WaveBanner', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(640, 150), Parent = root })
	banner = holder
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	local t = Kit.text({ Name = 'Title', Text = title, TextSize = 80, Stroke = Kit.Color.ink, Size = UDim2.new(1, 0, 0, 92), Parent = holder })
	t.TextScaled = true
	t:FindFirstChildOfClass('UIStroke').Thickness = 5
	Kit.gradient(Color3.new(1, 1, 1), color, 0.5).Parent = t
	local d = Kit.text({ Name = 'Detail', Text = detail, TextSize = 40, Stroke = Kit.Color.ink, TextColor3 = Kit.Tone.green.top, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 44), Parent = holder })
	d.TextScaled = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if banner ~= holder then return end
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.24) }):Play()
		for _, x in { t, d } do
			TweenService:Create(x, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(x:FindFirstChildOfClass('UIStroke'), fade, { Transparency = 1 }):Play()
		end
		task.delay(0.45, function() if banner == holder then holder:Destroy(); banner = nil end end)
	end)
end

---------------------------------------------------------------------------------------------- the gun
local function training() return ShotRules.counts(player:GetAttribute('TrainingStation')) end
local function inWave()
	local left = player:GetAttribute('WaveLeft')
	return current > 0 and type(left) == 'number' and left > 0 and not training()
end
local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass('Humanoid')
end
local function heldGun() return player.Character and GunTool.held(player.Character) or nil end
-- In a wave the gun comes out by itself; it goes back a moment after the wave is down, if it was us who took it out.
local autoEquipped = false
local function refreshEquip()
	local h = humanoid()
	if not h or h.Health <= 0 then return end
	if inWave() then
		local tool = GunTool.find(player)
		if tool and tool.Parent ~= player.Character then
			h:EquipTool(tool)
			autoEquipped = true
		end
	elseif autoEquipped then
		autoEquipped = false
		if heldGun() and not training() then h:UnequipTools() end
	end
end
player.DescendantAdded:Connect(function(d)
	if d:IsA('Tool') then task.defer(refreshEquip) end
end)
player.CharacterAdded:Connect(function() task.defer(refreshEquip) end)

-- Recoil: the gun kicks up and back in the hand (Tool.Grip) and springs home (as on the ranges).
local recoil = { angle = 0, vel = 0, tool = nil, base = nil, conn = nil }
local function kick(tool, strength)
	if recoil.tool ~= tool then
		if recoil.tool and recoil.tool.Parent and recoil.base then recoil.tool.Grip = recoil.base end
		recoil.tool, recoil.base, recoil.angle, recoil.vel = tool, tool.Grip, 0, 0
	end
	recoil.vel += 9 * strength
	if recoil.conn then return end
	recoil.conn = RunService.PreRender:Connect(function(dt)
		recoil.angle, recoil.vel = Juice.springStep(recoil.angle, recoil.vel, 0, 6, 0.55, dt)
		local t = recoil.tool
		if t and t.Parent then t.Grip = recoil.base * CFrame.Angles(-recoil.angle, 0, 0) * CFrame.new(0, 0, -recoil.angle * 0.5) end
		if math.abs(recoil.angle) < 1e-3 and math.abs(recoil.vel) < 1e-3 then
			if t and t.Parent then t.Grip = recoil.base end
			recoil.conn:Disconnect()
			recoil.conn = nil
		end
	end)
end

---------------------------------------------------------------------------------------------- shooting
local sticky -- the target you're on
local function pick(rootPos)
	local list = {}
	for index, e in targets[current] or {} do
		if not e.Down and shownOf(e) > 0 then list[index] = { Pos = e.Aim, Up = true } end
	end
	local cam = workspace.CurrentCamera
	local eye, look = cam and cam.CFrame.Position or rootPos, cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	sticky = WaveRules.pick(list, eye, look, rootPos, sticky)
	return sticky and targets[current][sticky]
end
-- What a hit will deal (the server's own sum: ShotRules.pay of the x1 ShotBase the server keeps on you off the
-- ranges (rebirth multiplier and boosts), times your gun and shoes).
local shoeCarry = {}
local function expected()
	return ShotRules.pay(player:GetAttribute('ShotBase'), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry)
end
-- The running "+N" sits beside the target on your screen's right, clear of its tag.
local function comboAt(e)
	local cam = workspace.CurrentCamera
	local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
	return e.Aim + right * 2.8 + Vector3.new(0, 0.8, 0)
end

local last = 0
local function shoot()
	if os.clock() - last < ShotRules.Cooldown or not inWave() then return end
	local c = player.Character
	local rootPart = c and c:FindFirstChild('HumanoidRootPart')
	if not rootPart then return end
	local e = pick(rootPart.Position)
	if not e then return end
	last = os.clock()
	remote:FireServer(e.Stage, e.Index)
	local damage = expected()
	pending[e.Index] = pending[e.Index] or {}
	table.insert(pending[e.Index], { damage, os.clock() })
	local tool = heldGun()
	local gun = Guns.ById[tool and tool:GetAttribute('GunId') or player:GetAttribute('EquippedGun') or ''] or Guns.List[1]
	local rig = tool and Juice.gunRig(tool)
	local to = e.Aim + Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
	-- Turn to face what you shoot (only while standing still, so walking is never fought).
	local h = humanoid()
	if h and h.MoveDirection.Magnitude < 0.1 then
		local look = Vector3.new(to.X, rootPart.Position.Y, to.Z)
		if (look - rootPart.Position).Magnitude > 0.5 then rootPart.CFrame = CFrame.lookAt(rootPart.Position, look) end
	end
	local from = rig and worldOf(rig.muzzle).Position or (rootPart.Position + Vector3.new(0, 1.2, 0))
	play('Shot', 1.1 - gun.Tier * 0.04)
	Juice.muzzle(rig, gun.Color, 0.9 + gun.Tier * 0.1)
	Juice.tracer(from, to, gun.Color, 0.18 + gun.Tier * 0.015)
	if rig and rig.eject then Juice.casing(worldOf(rig.eject)) end
	if tool then kick(tool, 0.8 + gun.Tier * 0.05) end
	Juice.kick(0.08 + gun.Tier * 0.015)
	local color = e.Shard or gun.Color
	Juice.burst(to, color, 0.9)
	if e.Knocker then e.Knocker:hit(0.6) end
	play(e.Hit, 1)
	Juice.flash(e.Model)
	Juice.combo(e.Model, comboAt(e), damage, { color = color, format = Format.compact })
	paint(e, false)
end

-- Hold to fire: while the mouse, R2 or the SHOOT button is held, shots keep coming at the client cooldown.
local held, firing = {}, false
local function startFiring(source)
	held[source] = true
	shoot()
	if firing then return end
	firing = true
	task.spawn(function()
		while next(held) do
			task.wait(ShotRules.Cooldown)
			if next(held) then shoot() end
		end
		firing = false
	end)
end
local function stopFiring(source) held[source] = nil end
local function sourceOf(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then return 'mouse' end
	if input.KeyCode == Enum.KeyCode.ButtonR2 then return 'r2' end
	return nil
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inWave() then return end
	local source = sourceOf(input)
	if source then startFiring(source) end
end)
UserInputService.InputEnded:Connect(function(input)
	local source = sourceOf(input)
	if source then stopFiring(source) end
end)

-- The round SHOOT button (Shoot.client's twin, same place; the two never show at once: ranges vs streets).
local shootGui = Instance.new('ScreenGui')
shootGui.Name = 'WaveShootButton'
shootGui.ResetOnSpawn = false
shootGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
shootGui.Parent = player:WaitForChild('PlayerGui')
local button = Instance.new('TextButton')
button.Name = 'Shoot'
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -150, 1, -40)
button.Size = UDim2.fromOffset(112, 112)
button.BackgroundColor3 = Color3.fromRGB(255, 71, 87)
button.Text = 'SHOOT'
button.FontFace = Kit.Font.display
button.TextSize = 24
button.TextColor3 = Color3.new(1, 1, 1)
button.TextYAlignment = Enum.TextYAlignment.Bottom
button.AutoButtonColor = false
button.Visible = false
button.Parent = shootGui
Kit.corner(UDim.new(0.5, 0)).Parent = button
Kit.new('UIPadding', { PaddingBottom = UDim.new(0, 22), Parent = button })
local buttonStroke = Kit.stroke(Color3.fromRGB(74, 11, 22), 4, true)
buttonStroke.Parent = button
local ring = Kit.new('Frame', { Name = 'Crosshair', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = button })
Kit.corner(UDim.new(0.5, 0)).Parent = ring
Kit.stroke(Color3.new(1, 1, 1), 3).Parent = ring
for _, bar in { { 2, 34 }, { 34, 2 } } do
	Kit.new('Frame', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(bar[1] + 1, bar[2] + 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ring })
end
local buttonScale = Kit.new('UIScale', { Parent = button })
local pressing = nil
button.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	pressing = input
	startFiring('button')
	buttonScale.Scale = 0.88
	TweenService:Create(buttonScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)
local function release(input)
	if not held.button then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == pressing then
		pressing = nil
		stopFiring('button')
	end
end
button.InputEnded:Connect(release)
UserInputService.InputEnded:Connect(release)

---------------------------------------------------------------------------------------------- the server's word
local wasOn = false
local function refresh()
	local stage = player:GetAttribute('WaveStage')
	stage = type(stage) == 'number' and stage or 0
	if stage ~= current then
		local old = current
		current = stage
		table.clear(pending)
		sticky = nil
		paintStage(old, false)
		paintStage(current, false)
	end
	showLeft()
	local on = inWave()
	button.Visible = on
	if on then
		refreshEquip()
	elseif wasOn then
		table.clear(held)
		-- (a moment after the last target falls, so the kill shot's flash and casing play out in your hand)
		task.delay(1.2, refreshEquip)
	end
	wasOn = on
end
for _, name in { 'WaveStage', 'WaveLeft', 'TrainingStation' } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end

Net.get('WaveState').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or type(info.Stage) ~= 'number' then return end
	local stage = info.Stage
	if info.Kind == 'Wave' and type(info.HP) == 'table' and type(info.Max) == 'table' then
		known[stage] = { HP = table.clone(info.HP), Max = table.clone(info.Max) }
		if stage == current then table.clear(pending) end
		paintStage(stage, true)
	elseif info.Kind == 'Hit' and type(info.Index) == 'number' and type(info.HP) == 'number' then
		local k = known[stage]
		if not k then
			k = { HP = {}, Max = {} }
			known[stage] = k
		end
		k.HP[info.Index] = info.HP
		local list = pending[info.Index]
		if list and #list > 0 and stage == current then table.remove(list, 1) end
		local e = targets[stage] and targets[stage][info.Index]
		if e then paint(e, true) end
	elseif info.Kind == 'Cleared' then
		local reward = type(info.Reward) == 'number' and info.Reward or 0
		showBanner('WAVE CLEARED!', reward > 0 and ('+' .. Format.compact(reward) .. ' CASH') or 'NICE SHOOTING!', Kit.hex('FFC21A'))
		chime.PlaybackSpeed = 1.25
		chime:Play()
		local c = player.Character
		local rootPart = c and c:FindFirstChild('HumanoidRootPart')
		if rootPart then Juice.shards(rootPart.Position + Vector3.new(0, 3, 0), Kit.hex('FFC21A'), 'confetti') end
	end
end)

gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
gui.Parent = player:WaitForChild('PlayerGui')
fit(gui.AbsoluteSize)
refresh()
