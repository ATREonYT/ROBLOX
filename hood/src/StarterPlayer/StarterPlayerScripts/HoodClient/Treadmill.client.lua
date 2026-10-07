-- SPEED treadmills on your screen (TreadmillService pays the Speed):
--   * belts scroll: every unlocked treadmill near the camera rolls its slats and chevrons back, faster each
--     tier; a locked one stands still and its screen dims
--   * labels: one line "x1 Speed" over a treadmill you have unlocked, like the reference; the price chip and
--     "Locked" over it while it is locked (Config/Treadmills.layoutLabel). The screen's faint LCD Detail says
--     UNLOCKED / LOCKED, or your walk speed while you run on it
--   * alive: idle screens breathe (+-12% at 0.5 Hz); while anyone runs on a treadmill its screen holds bright,
--     its light doubles and its mist thickens
--   * the x999 (Sprint) sways its smoke lines (Beams SmokeLine1..98) within 70 studs of the camera, and its
--     storm flashes: every 2.5-5 s its StormFlash light jumps to 3-4 for 0.08 s and two or three lines light up
--   * you run: on an unlocked belt your character plays its run animation in place, quicker on Run and Sprint,
--     and "+3 Speed" pops over the screen every time the server pays you
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

local RANGE = 120 -- belts further than this from the camera stop scrolling and breathing
local UNLOCKED, LOCKED = Color3.fromRGB(20, 235, 70), Color3.fromRGB(235, 25, 50) -- as the bag labels (Lobby.client)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local POP_FONT = Font.new('rbxasset://fonts/families/FredokaOne.json')

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
		screen = model:FindFirstChild('Screen', true), slats = {}, pieces = {}, parts = {}, cfs = {}, panels = {},
		travel = math.random() * 10, step = nil, painted = nil, phase = math.random() * 2, occupied = false,
		spacing = belt:GetAttribute('SlatSpacing') or Treadmills.Pattern.Spacing,
		slatY = belt:GetAttribute('SlatY') or 0.15, chevY = belt:GetAttribute('ChevronY') or 0.155,
		hideY = belt:GetAttribute('HideY') or 0, scroll = belt:GetAttribute('ScrollSpeed') or Treadmills.Scroll[row.Tier] or 4,
	}
	-- The belt's own pattern (tiers differ: Sprint has two big V's), as the map builder wrote it.
	local pat = table.clone(Treadmills.Pattern)
	pat.Spacing = r.spacing
	pat.Period = belt:GetAttribute('ChevronPeriod') or pat.Period
	pat.Stroke = belt:GetAttribute('ChevronStroke') or pat.Stroke
	pat.Slope = belt:GetAttribute('ChevronSlope') or pat.Slope
	pat.HalfWidth = belt:GetAttribute('HalfWidth') or pat.HalfWidth
	r.pattern = pat
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') and type(d:GetAttribute('Z0')) == 'number' then
			if d.Name == 'Slat' then
				table.insert(r.slats, { part = d, z0 = d:GetAttribute('Z0') })
			elseif d.Name == 'Chevron' then
				table.insert(r.pieces, { part = d, z0 = d:GetAttribute('Z0'), side = d:GetAttribute('Side') or 1, width = d.Size.X, lift = d:GetAttribute('Lift') or 0 })
			end
		elseif d:IsA('BasePart') and (d.Name == 'Screen' or d.Name == 'ScreenSide') then
			table.insert(r.panels, { part = d, color = d.Color })
		elseif d:IsA('ParticleEmitter') and d.Name == 'BeltMist' then
			r.mist, r.mistRate = d, d:GetAttribute('BaseRate') or d.Rate
		elseif d:IsA('PointLight') and d.Name == 'ScreenLight' then
			r.light, r.lightBase = d, d.Brightness
		elseif d:IsA('PointLight') and d.Name == 'StormFlash' then
			r.flash = d
		elseif d:IsA('Beam') and string.sub(d.Name, 1, 9) == 'SmokeLine' and d.Attachment1 then
			r.lines = r.lines or {}
			local a1 = d.Attachment1
			table.insert(r.lines, {
				beam = d, tip = a1, base = a1.CFrame, baseY = a1:GetAttribute('BaseY') or a1.CFrame.Position.Y,
				c0 = d:GetAttribute('BaseCurve0') or d.CurveSize0, c1 = d:GetAttribute('BaseCurve1') or d.CurveSize1,
				period = d:GetAttribute('Period') or 3, phase = d:GetAttribute('Phase') or 0, amp = d:GetAttribute('Sway') or 1.2,
			})
		end
	end
	for _, s in r.slats do table.insert(r.parts, s.part) end
	for _, p in r.pieces do table.insert(r.parts, p.part) end
	local gui = r.screen and r.screen:FindFirstChildWhichIsA('SurfaceGui')
	r.detail = gui and gui:FindFirstChild('Detail')
	local sign = model:FindFirstChild('Sign', true)
	r.labelGui = sign and sign:FindFirstChildWhichIsA('BillboardGui')
	r.label = r.labelGui and r.labelGui:FindFirstChild('Detail')
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
	for _, piece in r.pieces do
		n += 1
		if restep then
			local x, w = Treadmills.chevron(piece.z0 + step * r.spacing, r.pattern)
			piece.x = x
			if x and math.abs(w - piece.width) > 1e-3 then
				piece.width = w
				local size = piece.part.Size
				piece.part.Size = Vector3.new(w, size.Y, size.Z)
			end
		end
		local x = piece.x
		r.cfs[n] = base * (x and CFrame.new(piece.side * x, r.chevY + piece.lift, piece.z0 - p) or CFrame.new(piece.side, r.hideY, piece.z0 - p))
	end
	moveAll(r.parts, r.cfs)
end

-- Is this position (a HumanoidRootPart) over the treadmill's belt? Same test as TreadmillService.
local function over(r, position)
	local zone = r.zone
	if not zone or not zone.Parent then return false end
	local rel = zone.CFrame:PointToObjectSpace(position)
	local up = rel.Y - zone.Size.Y / 2
	return math.abs(rel.X) <= zone.Size.X / 2 + 0.15 and math.abs(rel.Z) <= zone.Size.Z / 2 and up >= -0.5 and up <= 8
end

---------------------------------------------------------------------------------------------- screens
local function power() return player:GetAttribute('Power') or 0 end
local current -- the record of the unlocked treadmill you're running on
local function walkText()
	return 'WALK SPEED ' .. tostring(player:GetAttribute('WalkSpeed') or Treadmills.walkSpeed(player:GetAttribute('Speed') or 0))
end
-- The label (one line once unlocked, chip + Locked while locked) and the screen's LCD line. Screens of locked
-- treadmills dim.
local function paint(r)
	local locked = not Treadmills.unlocked(power(), r.id)
	local running = current == r
	local key = (locked and 'L' or 'U') .. (running and walkText() or '')
	if key == r.painted then return end
	local wasLocked = r.painted and r.painted:sub(1, 1) == 'L'
	r.painted = key
	if r.label then
		r.label.Text = locked and 'Locked' or 'Unlocked'
		r.label.TextColor3 = locked and LOCKED or UNLOCKED
	end
	if r.labelGui then Treadmills.layoutLabel(r.labelGui, locked) end
	if r.detail then
		r.detail.Text = locked and ('LOCKED: ' .. Format.compact(r.row.Required) .. ' POWER') or (running and walkText() or 'UNLOCKED')
	end
	if locked or wasLocked then
		for _, panel in r.panels do panel.part.Color = locked and panel.color:Lerp(BLACK, 0.45) or panel.color end
	end
end
local function paintAll() for _, r in list do paint(r) end end
for _, key in { 'Power', 'WalkSpeed' } do player:GetAttributeChangedSignal(key):Connect(paintAll) end

-- Unlocked screens breathe while nobody runs on them, and hold bright (light doubled, mist thicker) while
-- someone does.
local function glow(r, t)
	local busy = r.occupied
	if r.light then r.light.Brightness = busy and 2.5 or r.lightBase end
	if r.mist then r.mist.Rate = busy and r.mistRate * 2 or r.mistRate end
	local f = busy and 0 or 0.12 * math.sin((t + r.phase) * math.pi) -- 0.5 Hz
	for _, panel in r.panels do
		panel.part.Color = f >= 0 and panel.color:Lerp(WHITE, f) or panel.color:Lerp(BLACK, -f)
	end
end

-- The x999's smoke lines: each curve breathes (CurveSize0 +-Sway over Period, CurveSize1 +-Sway/1.2 over 1.3
-- Period) and its tip bobs +-Sway/3 stud (Sway 1.2 on the long post lines, 0.35 on the short arcs).
local TAU = 2 * math.pi
local function sway(r, t)
	for _, l in r.lines do
		local w = TAU * t / l.period + l.phase
		l.beam.CurveSize0 = l.c0 + l.amp * math.sin(w)
		l.beam.CurveSize1 = l.c1 + l.amp / 1.2 * math.sin(w / 1.3 + 1.7)
		local p = l.base.Position
		l.tip.CFrame = l.base - p + Vector3.new(p.X, l.baseY + l.amp / 3 * math.sin(w * 0.8 + 0.6), p.Z)
	end
end

-- The x999's storm beat: every 2.5-5 s (random) the cloud's StormFlash light jumps to 3-4 for 0.08 s and two
-- or three smoke lines light up at full strength with it (a lightning crawl); then all drops back. Only near the
-- camera; a flash in progress still ends when the camera leaves.
local CRAWL = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0),
	NumberSequenceKeypoint.new(0.9, 0), NumberSequenceKeypoint.new(1, 1) })
local rng = Random.new()
local function storm(r, t, near)
	if r.flashEnd then
		if near and t < r.flashEnd then return end
		r.flash.Brightness = 0
		for beam, tr in r.lit do beam.Transparency = tr end
		r.flashEnd, r.lit = nil, nil
		return
	end
	if not near then return end
	r.nextFlash = r.nextFlash or t + rng:NextNumber(2.5, 5)
	if t < r.nextFlash then return end
	r.flash.Brightness = rng:NextNumber(3, 4)
	r.lit = {}
	local lines = r.lines or {}
	for _ = 1, math.min(#lines, rng:NextInteger(2, 3)) do
		local beam = lines[rng:NextInteger(1, #lines)].beam
		if not r.lit[beam] then
			r.lit[beam] = beam.Transparency
			beam.Transparency = CRAWL
		end
	end
	r.flashEnd, r.nextFlash = t + 0.08, t + rng:NextNumber(2.5, 5)
end

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

-- "+3 Speed" over the screen of the treadmill you run on, each time the server pays you.
local lastSpeed = player:GetAttribute('Speed')
player:GetAttributeChangedSignal('Speed'):Connect(function()
	local speed = player:GetAttribute('Speed') or 0
	local gained = lastSpeed and speed - lastSpeed or 0
	lastSpeed = speed
	local on = player:GetAttribute('Treadmill') or ''
	local r = current
	if not r or r.id ~= on then
		for _, other in list do if other.id == on and other.occupied then r = other end end
	end
	if gained <= 0 or on == '' or not okJuice or not r or not r.screen then return end
	local at = r.screen.CFrame.Position + Vector3.new((math.random() - 0.5) * 1.5, 2, 0)
	pcall(Juice.popNumber, at, '+' .. Format.compact(gained) .. ' Speed', r.row.Color, POP_FONT)
end)

---------------------------------------------------------------------------------------------- every frame
local frame = (pcall(function() return RunService.PreRender end) and RunService.PreRender) or RunService.RenderStepped
local clock, lastScan = 0, -1
frame:Connect(function(dt)
	dt = math.min(dt, 0.1)
	clock += dt
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	local alive = root and humanoid and humanoid.Health > 0
	-- Who stands on which belt (everyone, five times a second): busy treadmills glow brighter.
	local scan = clock - lastScan >= 0.2
	local roots
	if scan then
		lastScan = clock
		roots = {}
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local h = c and c:FindFirstChildOfClass('Humanoid')
			local rp = c and c:FindFirstChild('HumanoidRootPart')
			if rp and h and h.Health > 0 then table.insert(roots, rp.CFrame.Position) end
		end
	end
	local on
	for model, r in list do
		if not model.Parent or not r.belt.Parent then
			list[model] = nil
			continue
		end
		if r.painted == nil then paint(r) end
		local unlocked = Treadmills.unlocked(power(), r.id)
		if alive and unlocked and not on and over(r, root.CFrame.Position) then on = r end
		if scan then
			local busy = false
			for _, pos in roots do if over(r, pos) then busy = true break end end
			r.occupied = busy and unlocked
		end
		local near = eye and (r.belt.CFrame.Position - eye).Magnitude
		if unlocked and near and near <= RANGE then
			roll(r, dt, r.scroll)
			glow(r, clock)
		end
		if r.lines and near and near <= 70 then sway(r, clock) end
		if r.flash then storm(r, clock, near ~= nil and near <= 70) end
	end
	setRunning(on)
end)
