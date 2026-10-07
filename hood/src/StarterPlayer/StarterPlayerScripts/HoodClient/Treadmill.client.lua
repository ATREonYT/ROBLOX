-- SPEED treadmills on your screen (TreadmillService pays the Speed):
--   * belts scroll: every unlocked treadmill near the camera rolls its slats and chevrons back, faster each
--     tier; a locked one stands still
--   * screens: "UNLOCKED" (green) or "LOCKED: 150 POWER" (red) in each Screen's Detail line, and your walk
--     speed while you run on it
--   * you run: on an unlocked belt your character plays its run animation in place, quicker on Run and Sprint
--   * "+3 SPEED" pops over your head every time the server pays you
-- The belt pattern math is shared with the map builder (Config/Treadmills.chevron).
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Format = require(RS.Shared.Format)
local Treadmills = require(RS.Shared.Config.Treadmills)
local okJuice, Juice = pcall(require, RS.Shared.Juice)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end

local RANGE = 120 -- belts further than this from the camera stop scrolling
local GREEN, RED = Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 96, 96)

---------------------------------------------------------------------------------------------- treadmills
local list = {} -- model -> record
local function record(model)
	if list[model] or not model:IsA('Model') then return end
	local id = model:GetAttribute('TreadmillId') or string.match(model.Name, '^Treadmill_(.+)$')
	local row = id and Treadmills.ById[id]
	local belt = model:FindFirstChild('Belt', true)
	if not row or not belt then return end
	local r = {
		model = model, id = id, row = row, belt = belt, zone = model:FindFirstChild('TreadmillZone', true),
		screen = model:FindFirstChild('Screen', true), slats = {}, pieces = {}, parts = {}, cfs = {},
		travel = math.random() * 10, step = nil, locked = nil,
		spacing = belt:GetAttribute('SlatSpacing') or Treadmills.Pattern.Spacing,
		slatY = belt:GetAttribute('SlatY') or 0.16, chevY = belt:GetAttribute('ChevronY') or 0.18,
		hideY = belt:GetAttribute('HideY') or 0, scroll = belt:GetAttribute('ScrollSpeed') or Treadmills.Scroll[row.Tier] or 4,
	}
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') and type(d:GetAttribute('Z0')) == 'number' then
			if d.Name == 'Slat' then
				table.insert(r.slats, { part = d, z0 = d:GetAttribute('Z0') })
			elseif d.Name == 'Chevron' then
				table.insert(r.pieces, { part = d, z0 = d:GetAttribute('Z0'), side = d:GetAttribute('Side') or 1, width = d.Size.X })
			end
		end
	end
	for _, s in r.slats do table.insert(r.parts, s.part) end
	for _, p in r.pieces do table.insert(r.parts, p.part) end
	local gui = r.screen and r.screen:FindFirstChildWhichIsA('SurfaceGui')
	r.detail = gui and gui:FindFirstChild('Detail')
	list[model] = r
end
for _, m in CollectionService:GetTagged('HoodTreadmill') do record(m) end
CollectionService:GetInstanceAddedSignal('HoodTreadmill'):Connect(record)
for _, d in active.Root:GetDescendants() do
	if d:IsA('Model') and string.sub(d.Name, 1, 10) == 'Treadmill_' then record(d) end
end

-- Moves many anchored parts in one engine call where it exists (one CFrame write each otherwise).
local bulk = pcall(function() workspace:BulkMoveTo({}, {}, Enum.BulkMoveMode.FireCFrameChanged) end)
local function moveAll(parts, cfs)
	if bulk then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in parts do p.CFrame = cfs[i] end
	end
end

-- Rolls a belt `dt` seconds on. Slats slide back within one slat spacing and hop forward again; a hop hands
-- every slat the stretch of belt the slat in front of it carried, so the chevron pieces are recomputed only
-- then (Config/Treadmills.chevron) and the pattern runs smoothly.
local pattern = table.clone(Treadmills.Pattern)
local function roll(r, dt, speed)
	r.travel += speed * dt
	local step = math.floor(r.travel / r.spacing)
	local p = r.travel - step * r.spacing
	local base = r.belt.CFrame
	local n = 0
	for _, s in r.slats do
		n += 1
		r.cfs[n] = base * CFrame.new(0, r.slatY, s.z0 - p)
	end
	local restep = step ~= r.step
	r.step = step
	pattern.Spacing = r.spacing
	for _, piece in r.pieces do
		n += 1
		if restep then
			local x, w = Treadmills.chevron(piece.z0 + step * r.spacing, pattern)
			piece.x = x
			if x and math.abs(w - piece.width) > 1e-3 then
				piece.width = w
				local size = piece.part.Size
				piece.part.Size = Vector3.new(w, size.Y, size.Z)
			end
		end
		local x = piece.x
		r.cfs[n] = base * (x and CFrame.new(piece.side * x, r.chevY, piece.z0 - p) or CFrame.new(piece.side, r.hideY, piece.z0 - p))
	end
	moveAll(r.parts, r.cfs)
end

-- Is this position (a HumanoidRootPart) over the treadmill's belt? Same test as TreadmillService.
local function over(r, position)
	local zone = r.zone
	if not zone or not zone.Parent then return false end
	local rel = zone.CFrame:PointToObjectSpace(position)
	local up = rel.Y - zone.Size.Y / 2
	return math.abs(rel.X) <= zone.Size.X / 2 + 0.3 and math.abs(rel.Z) <= zone.Size.Z / 2 and up >= -0.5 and up <= 8
end

---------------------------------------------------------------------------------------------- screens
local function power() return player:GetAttribute('Power') or 0 end
local current -- the record of the unlocked treadmill you're running on
local function paint(r)
	local locked = not Treadmills.unlocked(power(), r.id)
	local running = current == r
	local key = (locked and 'L' or 'U') .. (running and tostring(player:GetAttribute('WalkSpeed')) or '')
	if key == r.locked then return end
	r.locked = key
	local d = r.detail
	if not d then return end
	if locked then
		d.Text = 'LOCKED: ' .. Format.compact(r.row.Required) .. ' POWER'
		d.TextColor3 = RED
	elseif running then
		d.Text = 'WALK SPEED ' .. tostring(player:GetAttribute('WalkSpeed') or Treadmills.walkSpeed(player:GetAttribute('Speed') or 0))
		d.TextColor3 = GREEN
	else
		d.Text = 'UNLOCKED'
		d.TextColor3 = GREEN
	end
end
local function paintAll() for _, r in list do paint(r) end end
for _, key in { 'Power', 'WalkSpeed' } do player:GetAttributeChangedSignal(key):Connect(paintAll) end

---------------------------------------------------------------------------------------------- running
-- The character's own run animation (the default Animate script's), or Roblox's stock one for its rig.
local STOCK_RUN = { R15 = 'rbxassetid://913376220', R6 = 'rbxassetid://180426354' }
local track, trackFor
local function runTrack(character)
	if trackFor == character and track then return track end
	trackFor, track = character, nil
	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass('Animator')
	if not animator then return nil end
	local animate = character:FindFirstChild('Animate')
	local run = animate and animate:FindFirstChild('run')
	local anim = run and run:FindFirstChildOfClass('Animation')
	if not anim then
		anim = Instance.new('Animation')
		anim.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R6 and STOCK_RUN.R6 or STOCK_RUN.R15
	end
	local ok, t = pcall(function() return animator:LoadAnimation(anim) end)
	if ok and t then
		t.Looped = true
		t.Priority = Enum.AnimationPriority.Movement -- over the idle pose, under emotes and tools
		track = t
	end
	return track
end
local function setRunning(r)
	if r == current then return end
	local before = current
	current = r
	local character = player.Character
	local t = character and runTrack(character)
	if t then
		if r then
			if not t.IsPlaying then t:Play(0.2) end
			t:AdjustSpeed(1 + (r.row.Tier - 1) * 0.3)
		else
			t:Stop(0.25)
		end
	end
	if before then paint(before) end
	if r then paint(r) end
end
player.CharacterAdded:Connect(function() trackFor, track, current = nil, nil, nil end)

-- "+3 SPEED" over your head each time the server pays you while you run.
local lastSpeed = player:GetAttribute('Speed')
player:GetAttributeChangedSignal('Speed'):Connect(function()
	local speed = player:GetAttribute('Speed') or 0
	local gained = lastSpeed and speed - lastSpeed or 0
	lastSpeed = speed
	local on = player:GetAttribute('Treadmill') or ''
	local character = player.Character
	local head = character and character:FindFirstChild('Head')
	if gained <= 0 or on == '' or not head or not okJuice then return end
	local row = Treadmills.ById[on]
	pcall(Juice.popNumber, head.CFrame.Position + Vector3.new((math.random() - 0.5) * 1.5, 2.2, 0), '+' .. Format.compact(gained) .. ' SPEED', row and row.Color)
end)

---------------------------------------------------------------------------------------------- every frame
local frame = (pcall(function() return RunService.PreRender end) and RunService.PreRender) or RunService.RenderStepped
frame:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	local alive = root and humanoid and humanoid.Health > 0
	local on
	for model, r in list do
		if not model.Parent or not r.belt.Parent then
			list[model] = nil
			continue
		end
		if r.locked == nil then paint(r) end
		local unlocked = Treadmills.unlocked(power(), r.id)
		if alive and unlocked and not on and over(r, root.CFrame.Position) then on = r end
		if unlocked and eye and (r.belt.CFrame.Position - eye).Magnitude <= RANGE then roll(r, dt, r.scroll) end
	end
	setRunning(on)
end)
