-- Shooting at the ranges: step into a lane's shooter's box and your gun (the gun tool GunService gives you)
-- comes out; click (or tap SHOOT, or R2) to fire. Each shot is worth a tenth of your per-second gain times your
-- gun's multiplier (ShotRules; the server checks and pays in LobbyService). Everything you see is local and
-- cheap: a layered shot sound, a muzzle flash, a tracer to the target, sparks, a hit sound and a "+N" where it
-- lands, the target knocked back (a can flying off, a bottle shattering, a plate swinging, a disc spinning, a
-- balloon popping into confetti), a shell casing and a little recoil. Hold the button (or the mouse, or R2) to
-- keep firing. Leaving the lane puts the gun away again (and the hip holster comes back: Armory.client).
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local RS = game:GetService('ReplicatedStorage')
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)
local Guns = require(RS.Shared.Config.Guns)
local ShotRules = require(RS.Shared.ShotRules)
local GunTool = require(RS.Shared.GunTool)

local player = Players.LocalPlayer

---------------------------------------------------------------------------------------------- sounds
-- Roblox ships no gunshot, so each sound is a few client built-ins layered and pitched (none of them the UI
-- click, button.wav, so a shot never sounds like a menu): a shot is a crack (paintball.wav, or clickfast pitched
-- well down) over a short low boom (electronicpingshort far down) and a dull tick, with a faint bullet zing on
-- top (swoosh.wav, or a very high, very quiet ping). A hit depends on the target's Hit attribute: Ding (steel
-- plates, gongs, the spinner) is electronicpingshort pitched by the lane's tier (always well under the stage
-- chime's pitch) with a metal tick, Tock (boards) a low click and a low ping, Glass and Tin a high ping and
-- click, Pop a snap, Ice a bright ping, Barrel a dull thud. paintball.wav, glassbreak.wav, snap.wav and
-- swoosh.wav may not exist in every client (check in Studio: content/sounds); they are tried first and
-- replaced by their fallback when they fail to load. Paste uploaded ids into SOUNDS to replace a whole sound.
-- Every sound plays through the 'Shots' SoundGroup under SoundService (a settings menu can mute or balance it
-- there), from a little pool per layer, so a new shot never restarts the one still playing (all-Ding lanes ring
-- a Ding every 0.15 s: their pools are deeper). Volumes stay modest (shots come 7 a second).
local SOUNDS = { Shot = '', Ding = '', Tock = '', Glass = '', Tin = '', Pop = '', Ice = '', Barrel = '' }
local BUILTIN = 'rbxasset://sounds/'
-- { file, volume, playback speed, fallback = { file, volume, speed } }
local LAYERS = {
	Shot = {
		{ 'paintball.wav', 0.3, 0.9, fallback = { 'clickfast.wav', 0.4, 0.6 } },
		{ 'electronicpingshort.wav', 0.16, 0.32 },
		{ 'clickfast.wav', 0.18, 0.42 },
		{ 'swoosh.wav', 0.08, 1.8, fallback = { 'electronicpingshort.wav', 0.04, 2.6 } },
	},
	Ding = { { 'electronicpingshort.wav', 0.45, 0.5 }, { 'clickfast.wav', 0.18, 1.3 } },
	Tock = { { 'clickfast.wav', 0.4, 0.55 }, { 'electronicpingshort.wav', 0.12, 0.4 } },
	Glass = { { 'glassbreak.wav', 0.4, 1.1, fallback = { 'electronicpingshort.wav', 0.3, 1.7 } }, { 'clickfast.wav', 0.25, 1.4 } },
	Tin = { { 'electronicpingshort.wav', 0.3, 1.25 }, { 'clickfast.wav', 0.3, 1.1 } },
	Pop = { { 'snap.wav', 0.45, 1.0, fallback = { 'clickfast.wav', 0.5, 1.6 } }, { 'swoosh.wav', 0.15, 2.0, fallback = { 'electronicpingshort.wav', 0.08, 2.2 } } },
	Ice = { { 'electronicpingshort.wav', 0.35, 1.45 }, { 'clickfast.wav', 0.2, 1.3 } },
	Barrel = { { 'clickfast.wav', 0.45, 0.38 }, { 'electronicpingshort.wav', 0.2, 0.45 } },
}
local POOL = { Ding = 6 } -- Sounds per layer (default 4)
local group = SoundService:FindFirstChild('Shots')
if not (group and group:IsA('SoundGroup')) then
	group = Instance.new('SoundGroup')
	group.Name = 'Shots'
	group.Volume = 1
	group.Parent = SoundService
end
local function newSound(id, volume)
	local sound = Instance.new('Sound')
	sound.SoundId = id
	sound.Volume = volume
	sound.SoundGroup = group
	sound.Parent = group
	return sound
end
local function resetPool(layer)
	for _, sound in layer.pool or {} do sound:Destroy() end
	layer.pool, layer.next = {}, 1
end
-- Each layer starts on its known-good file and switches to the first-choice file once that has loaded.
for kind, layers in LAYERS do
	for _, layer in layers do
		local spec = layer.fallback or layer
		layer.use = { BUILTIN .. spec[1], spec[2], spec[3] }
		layer.size = POOL[kind] or 4
		resetPool(layer)
		if layer.fallback then
			task.spawn(function()
				local probe = newSound(BUILTIN .. layer[1], 0)
				local ok = pcall(function() ContentProvider:PreloadAsync({ probe }) end)
				local loaded = ok and pcall(function() return probe.IsLoaded end) and probe.IsLoaded and probe.TimeLength > 0
				probe:Destroy()
				if loaded then
					layer.use = { BUILTIN .. layer[1], layer[2], layer[3] }
					resetPool(layer)
				end
			end)
		end
	end
end
local overrides = {}
local function play(kind, pitch)
	local uploaded = SOUNDS[kind]
	local layers = LAYERS[kind]
	if uploaded and uploaded ~= '' then
		overrides[kind] = overrides[kind] or { { use = { uploaded, 0.45, 1 }, pool = {}, next = 1, size = POOL[kind] or 4 } }
		layers = overrides[kind]
	end
	for _, layer in layers or {} do
		local id, volume, speed = layer.use[1], layer.use[2], layer.use[3]
		local sound = layer.pool[layer.next]
		if not sound or sound.SoundId ~= id then
			if sound then sound:Destroy() end
			sound = newSound(id, volume)
			layer.pool[layer.next] = sound
		end
		layer.next = layer.next % layer.size + 1
		sound.PlaybackSpeed = speed * (pitch or 1) * (0.95 + math.random() * 0.1)
		sound:Play()
	end
end
-- An attachment's world frame (the same as WorldCFrame, spelled out so offline checks can run this file).
local function worldOf(att) return att.Parent.CFrame * att.CFrame end
local active = ActiveMap.wait(20)
if not active then return end
local remote = Net.get('Shoot')

---------------------------------------------------------------------------------------------- stations
-- Each range's targets, read once per station model (and again if the model is rebuilt or streams back in).
local stations, missing = {}, {}
local function station(id)
	local s = stations[id]
	if s and s.Model.Parent then return s end
	if (missing[id] or 0) > os.clock() then return nil end
	local model = active.Lobby:FindFirstChild('Training_' .. id, true)
	if not model then
		missing[id] = os.clock() + 5 -- (not built or streamed out: look again in a while)
		return nil
	end
	s = { Model = model, Targets = {}, Main = nil, Turn = 0, Tier = model:GetAttribute('Tier') or (id == 'Ring' and 9) or 1 }
	local equipment = model:FindFirstChild('Equipment')
	for _, d in (equipment and equipment:GetDescendants() or {}) do
		if d:IsA('Model') and d:GetAttribute('Knock') then
			local entry = { Model = d, Aim = d:GetAttribute('Aim'), Knocker = Juice.knocker(d) }
			if typeof(entry.Aim) ~= 'Vector3' then entry.Aim = d:GetPivot().Position end
			table.insert(s.Targets, entry)
			if d:GetAttribute('Main') then s.Main = entry end
		end
	end
	-- Older stations (no targets): aim at the HitPoint, or the middle of the equipment.
	if #s.Targets == 0 then
		local hit = model:GetAttribute('HitPoint')
		if typeof(hit) ~= 'Vector3' then hit = equipment and equipment:GetPivot().Position or model:GetPivot().Position end
		s.Main = { Model = equipment or model, Aim = hit }
		s.Targets = { s.Main }
	end
	s.Main = s.Main or s.Targets[1]
	stations[id] = s
	return s
end
-- Every other shot goes to the main target, the others take turns, and a target that is away (popped, shattered,
-- flown off: it grows back in a moment) is skipped (ShotRules.pick).
local function present(t) return not t.Knocker or t.Knocker:present() end
local function nextTarget(s) return ShotRules.pick(s, s.Targets, s.Main, present) end

---------------------------------------------------------------------------------------------- the gun
local function training()
	local id = player:GetAttribute('TrainingStation') or ''
	return ShotRules.counts(id) and id or nil
end
local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass('Humanoid')
end
local function heldGun()
	return player.Character and GunTool.held(player.Character) or nil
end
-- On a range the gun comes out by itself; when you leave, it goes back if it was us who took it out.
local autoEquipped = false
local function refreshEquip()
	local h = humanoid()
	if not h or h.Health <= 0 then return end
	if training() then
		local tool = GunTool.find(player)
		if tool and tool.Parent ~= player.Character then
			h:EquipTool(tool)
			autoEquipped = true
		end
	elseif autoEquipped then
		autoEquipped = false
		if heldGun() then h:UnequipTools() end
	end
end
player:GetAttributeChangedSignal('TrainingStation'):Connect(refreshEquip)
-- The tool can arrive after you step on (GunService gives it on spawn and swaps it when you change guns).
player.DescendantAdded:Connect(function(d)
	if d:IsA('Tool') then task.defer(refreshEquip) end -- (its GunId attribute is set before it is parented)
end)
player.CharacterAdded:Connect(function() task.defer(refreshEquip) end)

-- Recoil: the gun kicks up and back in the hand (Tool.Grip) and springs home.
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

-- Idle life on every lane near the camera (everyone sees it): plates sway, spinners turn, balloons bob.
local Skins = require(RS.Shared.Config.Skins)
local IDLE_RANGE = 90
local idleCheck, near = 0, {}
RunService.PreRender:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	if os.clock() > idleCheck then
		-- (Which lanes are near is re-checked twice a second.)
		idleCheck = os.clock() + 0.5
		table.clear(near)
		for _, row in Skins.Stations do
			local s = station(row.Id)
			if s and (s.Model:GetPivot().Position - camera.CFrame.Position).Magnitude < IDLE_RANGE then table.insert(near, s) end
		end
	end
	for _, s in near do
		for _, t in s.Targets do
			if t.Knocker and t.Knocker.idle then t.Knocker:pose() end
		end
	end
end)

---------------------------------------------------------------------------------------------- shooting
local last = 0
local function shoot()
	if os.clock() - last < ShotRules.Cooldown then return end
	local id = training()
	local tool = heldGun()
	if not id and not tool then return end
	last = os.clock()
	if id then remote:FireServer() end
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not root then return end
	local gun = Guns.ById[tool and tool:GetAttribute('GunId') or player:GetAttribute('EquippedGun') or ''] or Guns.List[1]
	local gunPower = 0.9 + gun.Tier * 0.1
	local rig = tool and Juice.gunRig(tool)
	local from = rig and worldOf(rig.muzzle).Position or (root.Position + Vector3.new(0, 1.2, 0))
	local s = id and station(id)
	local target, there
	if s then target, there = nextTarget(s) end
	local to
	if target then
		to = target.Aim + Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
		-- Turn to face what you shoot (only while standing still, so walking is never fought).
		local h = humanoid()
		if h and h.MoveDirection.Magnitude < 0.1 then
			local look = Vector3.new(to.X, root.Position.Y, to.Z)
			if (look - root.Position).Magnitude > 0.5 then root.CFrame = CFrame.lookAt(root.Position, look) end
		end
		if rig then from = worldOf(rig.muzzle).Position end
	else
		-- Off a range: a dry shot straight ahead (nothing is paid).
		to = from + root.CFrame.LookVector * 30
	end
	-- (Bigger guns sound a little deeper.)
	play('Shot', 1.1 - gun.Tier * 0.04)
	Juice.muzzle(rig, gun.Color, gunPower)
	Juice.tracer(from, to, gun.Color, 0.18 + gun.Tier * 0.015)
	if rig and rig.eject then Juice.casing(worldOf(rig.eject)) end
	if tool then kick(tool, 0.8 + gun.Tier * 0.05) end
	Juice.kick(0.08 + gun.Tier * 0.015)
	if target and s then
		local color = s.Model:GetAttribute('HitColor') or gun.Color
		Juice.burst(to, color, 0.7 + s.Tier * 0.07)
		if there then
			if target.Knocker then target.Knocker:hit(1) end
			local hit = target.Model:GetAttribute('Hit') or 'Ding'
			-- A steel ding rises in pitch lane by lane (0.53 to 0.78 of the stage chime's).
			play(hit, hit == 'Ding' and (1 + 0.07 * s.Tier) or 1)
			Juice.flash(target.Model)
		end
		local gain = ShotRules.pay(player:GetAttribute('PowerRate'), player:GetAttribute('GunMultiplier'))
		-- White numbers outlined in a dark shade of the lane's colour read on every lane (a yellow "+N" vanished on
		-- the gold lane); top lanes get bigger ones.
		Juice.popNumber(to + Vector3.new((math.random() - 0.5) * 1.5, 1.4, 0), '+' .. Format.compact(gain), color, nil, {
			fill = Color3.new(1, 1, 1), stroke = color:Lerp(Color3.new(0, 0, 0), 0.65), thickness = 3, size = s.Tier >= 5 and Vector2.new(5, 2) or nil,
		})
	end
end

-- Hold to fire: while the mouse, R2 or the SHOOT button is held, shots keep coming at the client cooldown
-- (the server's rate limit matches it).
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
	if processed then return end
	local source = sourceOf(input)
	if source then startFiring(source) end
end)
UserInputService.InputEnded:Connect(function(input)
	local source = sourceOf(input)
	if source then stopFiring(source) end
end)

-- A big round SHOOT button while you're on a range (the only way to shoot on a phone), where PUNCH used to be.
local gui = Instance.new('ScreenGui')
gui.Name = 'ShootButton'
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild('PlayerGui')
local button = Instance.new('TextButton')
button.Name = 'Shoot'
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -150, 1, -40)
button.Size = UDim2.fromOffset(112, 112)
button.BackgroundColor3 = Color3.fromRGB(255, 71, 87)
button.Text = 'SHOOT'
button.FontFace = Font.new('rbxasset://fonts/families/LuckiestGuy.json')
button.TextSize = 24
button.TextColor3 = Color3.new(1, 1, 1)
button.TextYAlignment = Enum.TextYAlignment.Bottom
button.AutoButtonColor = false
button.Visible = false
button.Parent = gui
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = button
local pad = Instance.new('UIPadding')
pad.PaddingBottom = UDim.new(0, 22)
pad.Parent = button
local stroke = Instance.new('UIStroke')
stroke.Color = Color3.fromRGB(74, 11, 22)
stroke.Thickness = 4
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button
-- A white crosshair ring over the word.
local ring = Instance.new('Frame')
ring.Name = 'Crosshair'
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.new(0.5, 0, 0, 34)
ring.Size = UDim2.fromOffset(26, 26)
ring.BackgroundTransparency = 1
ring.Parent = button
local ringCorner = Instance.new('UICorner')
ringCorner.CornerRadius = UDim.new(0.5, 0)
ringCorner.Parent = ring
local ringStroke = Instance.new('UIStroke')
ringStroke.Color = Color3.new(1, 1, 1)
ringStroke.Thickness = 3
ringStroke.Parent = ring
for _, bar in { { 2, 34 }, { 34, 2 } } do
	local b = Instance.new('Frame')
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.5)
	b.Size = UDim2.fromOffset(bar[1] + 1, bar[2] + 1)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Parent = ring
end
local scale = Instance.new('UIScale')
scale.Parent = button
-- The press that started it (a touch keeps its InputObject until the finger lifts, wherever it lifts).
local pressing = nil
button.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	pressing = input
	startFiring('button')
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)
local function release(input)
	if not held.button then return end
	-- Mouse: any left-button release. Touch: only the finger that pressed (another finger on the thumbstick
	-- lifting must not stop the fire).
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == pressing then
		pressing = nil
		stopFiring('button')
	end
end
button.InputEnded:Connect(release)
UserInputService.InputEnded:Connect(release) -- (released off the button, the button never hears it; touches too)
local function refresh()
	button.Visible = training() ~= nil
	if not button.Visible then stopFiring('button') end
end
player:GetAttributeChangedSignal('TrainingStation'):Connect(refresh)
refresh()
