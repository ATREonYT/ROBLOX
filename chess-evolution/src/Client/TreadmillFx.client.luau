--!strict
-- [TreadmillFx] Life for the chess treadmills (Alex's reference machines, Nov 7).
-- Four states per station, driven by the server's replicated signals only (no game code touched):
--   Idle      nobody training: console lights and accents dim, belt still.
--   Training  a player's "Training" attribute names this station: belt moves, directional accents run,
--             and each accepted tap (that player's leaderstats Power going up) gives a small response.
--   Streak    training for STREAK_AFTER seconds with taps still coming: the machine's expanded effect
--             (start -> peak -> hold), bursts capped by a cooldown however fast the taps are.
--   Stop      training ends (left the deck, reset, stopped): effects fade, then idle.
-- Each machine's look comes from Map.Stations.<id>.Visual (attribute Style, Accent, RingRadius and the
-- attachments on Visual.Chassis.Root). Nothing here flashes faster than once a second.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Stations = workspace:WaitForChild("Map"):WaitForChild("Stations")
local camera = workspace.CurrentCamera

local STREAK_AFTER = 3 -- seconds of training before the streak effect
local TAP_GRACE = 1.3 -- a streak holds while taps keep coming within this window
local CULL = 160 -- studs from the camera

local fxFolder = Instance.new("Folder")
fxFolder.Name = "TreadmillFx"
fxFolder.Parent = workspace

local function log(...)
	print("[TreadmillFx]", ...)
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function neonPart(size: Vector3, color: Color3, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Transparency = transparency or 0
	return p
end

-- a hollow cube: 12 thin neon edges in a model
local function hollowCube(size: number, edge: number, color: Color3): Model
	local m = Instance.new("Model")
	local h = size / 2
	local center = Instance.new("Part")
	center.Name = "Center"
	center.Anchored, center.CanCollide, center.CanQuery, center.CanTouch = true, false, false, false
	center.Transparency = 1
	center.Size = Vector3.new(0.1, 0.1, 0.1)
	center.Parent = m
	m.PrimaryPart = center
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			local e1 = neonPart(Vector3.new(size + edge, edge, edge), color)
			e1.CFrame = CFrame.new(0, a * h, b * h)
			local e2 = neonPart(Vector3.new(edge, size + edge, edge), color)
			e2.CFrame = CFrame.new(a * h, 0, b * h)
			local e3 = neonPart(Vector3.new(edge, edge, size + edge), color)
			e3.CFrame = CFrame.new(a * h, b * h, 0)
			e1.Parent, e2.Parent, e3.Parent = m, m, m
		end
	end
	return m
end

local function setModelTransparency(m: Instance, t: number)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Center" then
			d.Transparency = t
		end
	end
end

---------------------------------------------------------------------------
-- per-station state
---------------------------------------------------------------------------
type Station = {
	id: string,
	model: Model,
	visual: Model,
	root: BasePart,
	style: string,
	accent: Color3,
	lights: { BasePart },
	lightSize: { [BasePart]: Vector3 },
	slats: { BasePart },
	slatZ: { number },
	z0: number,
	z1: number,
	beltOffset: number,
	beltSpeed: number,
	glow: number,
	consoleLight: PointLight?,
	trainingSince: number?,
	lastTap: number,
	lastTapFx: number,
	streakOn: boolean,
	nextAccent: number,
	nextBurst: number,
	data: { [string]: any },
}

local stations: { [string]: Station } = {}

local function att(st: Station, name: string): CFrame
	local a = st.root:FindFirstChild(name) :: Attachment?
	return if a then a.WorldCFrame else st.root.CFrame
end

local function localCF(st: Station, pos: Vector3): CFrame
	return st.root.CFrame * CFrame.new(pos)
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local visual = model:FindFirstChild("Visual")
	local chassis = visual and visual:FindFirstChild("Chassis")
	local root = chassis and chassis:FindFirstChild("Root") :: BasePart?
	if not visual or not root or not visual:GetAttribute("Style") then
		return
	end
	local st: Station = {
		id = model.Name,
		model = model,
		visual = visual :: Model,
		root = root,
		style = visual:GetAttribute("Style") :: string,
		accent = (visual:GetAttribute("Accent") :: Color3?) or Color3.new(1, 1, 1),
		lights = {},
		lightSize = {},
		slats = {},
		slatZ = {},
		z0 = (visual:GetAttribute("BeltZ0") :: number?) or -4,
		z1 = (visual:GetAttribute("BeltZ1") :: number?) or 5,
		beltOffset = 0,
		beltSpeed = 0,
		glow = 0,
		consoleLight = nil,
		trainingSince = nil,
		lastTap = 0,
		lastTapFx = 0,
		streakOn = false,
		nextAccent = 0,
		nextBurst = 0,
		data = {},
	}
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Accent") then
			table.insert(st.lights, d)
			st.lightSize[d] = d.Size
		end
	end
	local belt = visual:FindFirstChild("BeltVisual")
	if belt then
		for _, s in ipairs(belt:GetChildren()) do
			if s:IsA("BasePart") and s.Name == "Slat" then
				table.insert(st.slats, s)
				table.insert(st.slatZ, root.CFrame:PointToObjectSpace(s.Position).Z)
			end
		end
	end
	local screen = model:FindFirstChild("Screen")
	st.consoleLight = screen and screen:FindFirstChildOfClass("PointLight") :: PointLight?
	if st.consoleLight then
		st.consoleLight.Color = st.accent
		st.consoleLight.Range = 7
	end
	stations[st.id] = st
	log(st.id, "ready (" .. st.style .. ")")
end

---------------------------------------------------------------------------
-- styles: training accents, tap response, streak start/step/stop
---------------------------------------------------------------------------
local Styles: { [string]: { [string]: (Station, number) -> () } } = {}

-- Pawn Mill: lime squares with short sharp tails run down the belt; streak = low segmented ring
-- around the chassis plus hollow cubes rising from the rear corners.
Styles.pawn = {
	accent = function(st, now)
		if now < st.nextAccent then
			return
		end
		st.nextAccent = now + 0.34
		local lanes = { -1.6, 0, 1.6 }
		st.data.lane = ((st.data.lane or 0) % 3) + 1
		local x = lanes[st.data.lane]
		local sq = neonPart(Vector3.new(0.72, 0.06, 0.72), st.accent, 0)
		local tail = neonPart(Vector3.new(0.24, 0.05, 1.1), st.accent, 0.35)
		local z0, z1 = -3.6, 4.6
		sq.CFrame = localCF(st, Vector3.new(x, 0.83, z0))
		tail.CFrame = localCF(st, Vector3.new(x, 0.825, z0 - 0.9))
		sq.Parent, tail.Parent = fxFolder, fxFolder
		local t = 0.95
		tween(sq, t, { CFrame = localCF(st, Vector3.new(x, 0.83, z1)) }, Enum.EasingStyle.Linear)
		tween(tail, t, { CFrame = localCF(st, Vector3.new(x, 0.825, z1 - 0.9)) }, Enum.EasingStyle.Linear)
		task.delay(t * 0.7, function()
			tween(sq, t * 0.3, { Transparency = 1 })
			tween(tail, t * 0.3, { Transparency = 1 })
		end)
		task.delay(t + 0.05, function()
			sq:Destroy()
			tail:Destroy()
		end)
	end,
	streakStart = function(st, _now)
		local R = (st.visual:GetAttribute("RingRadius") :: number?) or 7.5
		local ring = Instance.new("Model")
		ring.Name = st.id .. "_Ring"
		local centre = att(st, "OuterRing")
		local segs = {}
		local N = 20
		for i = 1, N do
			local a = (i / N) * math.pi * 2
			local seg = neonPart(Vector3.new(R * 2 * math.pi / N * 0.62, 0.3, 0.5), st.accent, 1)
			seg.CFrame = centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(R - 1.2))
			seg.Parent = ring
			segs[i] = { part = seg, a = a }
		end
		ring.Parent = fxFolder
		st.data.ring = ring
		st.data.segs = segs
		st.data.ringR = R - 1.2
		st.data.ringT = 0
		st.data.ringFade = nil
	end,
	streakStep = function(st, now)
		local d = st.data
		local segs = d.segs
		if not segs then
			return
		end
		local R = (st.visual:GetAttribute("RingRadius") :: number?) or 7.5
		local dt = d.dt or 0
		d.ringT += dt
		local t = d.ringT
		-- start (0-0.35 s): grow out and appear; peak (0.35-0.8 s): taller and brightest; hold: settle and turn
		local grow = math.clamp(t / 0.35, 0, 1)
		local r = (R - 1.2) + 1.2 * (1 - (1 - grow) ^ 3)
		local trans, height
		if d.ringFade then
			local f = math.clamp((now - d.ringFade) / 0.6, 0, 1)
			trans = 0.15 + 0.85 * f
			height = 0.3 * (1 - f) + 0.05
			r = R + 0.6 * f
		elseif t < 0.35 then
			trans = 1 - 0.95 * grow
			height = 0.3
		elseif t < 0.8 then
			local k = math.sin((t - 0.35) / 0.45 * math.pi)
			trans = 0.05 - 0.05 * k
			height = 0.32 + 0.35 * k
		else
			trans = 0.08
			height = 0.32
		end
		local spin = t * (2 * math.pi / 10)
		local centre = att(st, "OuterRing")
		for _, s in ipairs(segs) do
			s.part.Size = Vector3.new(s.part.Size.X, height, 0.5)
			s.part.Transparency = trans
			s.part.CFrame = centre * CFrame.Angles(0, s.a + spin, 0) * CFrame.new(0, height / 2 - 0.1, -r)
		end
		-- hollow cubes from the rear corners, at most one every 0.9 s and 3 alive
		if not d.ringFade and now >= st.nextBurst and (d.cubes or 0) < 3 then
			st.nextBurst = now + 0.9
			d.side = -(d.side or 1)
			local corner = att(st, if d.side < 0 then "RearCornerL" else "RearCornerR")
			local cube = hollowCube(1.1, 0.11, st.accent)
			setModelTransparency(cube, 1)
			cube:PivotTo(corner)
			cube.Parent = fxFolder
			d.cubes = (d.cubes or 0) + 1
			local start = now
			local out = st.root.CFrame:VectorToWorldSpace(Vector3.new(d.side * 0.9, 0, -0.3))
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local k = (os.clock() - start) / 1.7
				if k >= 1 then
					conn:Disconnect()
					cube:Destroy()
					d.cubes -= 1
					return
				end
				local rise = 4.2 * (1 - (1 - k) ^ 2)
				cube:PivotTo((corner + Vector3.new(0, rise, 0) + out * k) * CFrame.Angles(k * 2.2, k * 3.1, 0))
				setModelTransparency(cube, if k < 0.15 then 1 - k / 0.15 * 0.95 elseif k > 0.65 then 0.05 + (k - 0.65) / 0.35 * 0.95 else 0.05)
			end)
		end
	end,
	streakStop = function(st, now)
		local d = st.data
		if d.ring and not d.ringFade then
			d.ringFade = now
			local ring = d.ring
			task.delay(0.65, function()
				ring:Destroy()
				if d.ring == ring then
					d.ring, d.segs, d.ringFade = nil, nil, nil
				end
			end)
		end
	end,
}

---------------------------------------------------------------------------
-- signals: who is training where, and their accepted taps (Power going up)
---------------------------------------------------------------------------
local watched: { [Player]: boolean } = {}
local function watchPlayer(p: Player)
	if watched[p] then
		return
	end
	watched[p] = true
	local function hookPower(stats: Instance)
		local power = stats:WaitForChild("Power", 10) :: IntValue?
		if not power then
			return
		end
		local last = power.Value
		power.Changed:Connect(function(v)
			local id = p:GetAttribute("Training")
			if v > last and type(id) == "string" and stations[id] then
				stations[id].lastTap = os.clock()
			end
			last = v
		end)
	end
	local stats = p:FindFirstChild("leaderstats")
	if stats then
		task.spawn(hookPower, stats)
	end
	p.ChildAdded:Connect(function(c)
		if c.Name == "leaderstats" then
			hookPower(c)
		end
	end)
	p:GetAttributeChangedSignal("Training"):Connect(function()
		local id = p:GetAttribute("Training")
		if type(id) == "string" and stations[id] then
			stations[id].lastTap = os.clock()
		end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	watched[p] = nil
end)

local function activeSet(): { [string]: boolean }
	local set = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local id = p:GetAttribute("Training")
		if type(id) == "string" then
			set[id] = true
		end
	end
	return set
end

---------------------------------------------------------------------------
-- main loop
---------------------------------------------------------------------------
local function step(st: Station, training: boolean, now: number, dt: number)
	local style = Styles[st.style]
	st.data.dt = dt
	-- training clock
	if training then
		st.trainingSince = st.trainingSince or now
	else
		st.trainingSince = nil
	end
	local streak = training and st.trainingSince ~= nil and now - st.trainingSince >= STREAK_AFTER and now - st.lastTap <= TAP_GRACE
	-- belt: eases up while training, keeps rolling between taps, eases to a stop
	local target = if training then 7 else 0
	st.beltSpeed += (target - st.beltSpeed) * math.min(1, dt * (if target > st.beltSpeed then 3 else 1.6))
	if st.beltSpeed > 0.03 and #st.slats > 0 then
		st.beltOffset += st.beltSpeed * dt
		local span = st.z1 - st.z0
		for i, s in ipairs(st.slats) do
			local z = st.z0 + ((st.slatZ[i] - st.z0 + st.beltOffset) % span)
			local p = st.root.CFrame:PointToObjectSpace(s.Position)
			s.CFrame = st.root.CFrame * CFrame.new(p.X, p.Y, z)
		end
	end
	-- accents: dim at idle, steady while training; a tap gives a small size pop (not a flash)
	local glowTarget = if training then 1 else 0
	st.glow += (glowTarget - st.glow) * math.min(1, dt * (if glowTarget > st.glow then 5 else 2))
	local tapPop = math.clamp(1 - (now - st.lastTap) / 0.16, 0, 1)
	for _, l in ipairs(st.lights) do
		l.Transparency = 0.6 - 0.6 * st.glow
		local base = st.lightSize[l]
		l.Size = base * (1 + 0.18 * tapPop * st.glow)
	end
	if st.consoleLight then
		st.consoleLight.Brightness = 0.25 + 0.95 * st.glow
	end
	if style then
		if training and style.accent then
			style.accent(st, now)
		end
		if streak and not st.streakOn then
			st.streakOn = true
			if style.streakStart then
				style.streakStart(st, now)
			end
		elseif not streak and st.streakOn then
			st.streakOn = false
			if style.streakStop then
				style.streakStop(st, now)
			end
		end
		if style.streakStep and (st.streakOn or st.data.ring) then
			style.streakStep(st, now)
		end
	end
end

-- The place streams (StreamingEnabled), so a machine may arrive or leave later: keep trying to register
-- the ones we don't have, and drop one whose parts were streamed out.
local function scan()
	for id, st in pairs(stations) do
		if not st.root.Parent or not st.visual.Parent then
			stations[id] = nil
		end
	end
	for _, m in ipairs(Stations:GetChildren()) do
		if not stations[m.Name] then
			local ok, err = pcall(register, m)
			if not ok then
				warn("[TreadmillFx] register " .. m.Name .. ": " .. tostring(err))
			end
		end
	end
end
scan()
task.spawn(function()
	while true do
		task.wait(1)
		scan()
	end
end)

local last = os.clock()
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local dt = math.min(now - last, 0.1)
	last = now
	local active = activeSet()
	local camPos = camera.CFrame.Position
	for id, st in pairs(stations) do
		local near = (st.root.Position - camPos).Magnitude < CULL
		if near or st.streakOn or st.glow > 0.01 then
			local ok, err = pcall(step, st, active[id] == true and near, now, dt)
			if not ok then
				warn("[TreadmillFx] " .. id .. ": " .. tostring(err))
				stations[id] = nil
			end
		end
	end
end)
log("running")
