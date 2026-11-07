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

-- shared: a flat neon strip on the belt that grows from a start point toward an end point
local function beltStrip(st: Station, from: Vector3, to: Vector3, width: number, grow: number, color: Color3): Part
	local dir = to - from
	local len = dir.Magnitude
	local p = neonPart(Vector3.new(width, 0.05, 0.05), color, 0)
	local look = CFrame.lookAt(from, to)
	local function at(l: number)
		return st.root.CFrame * (look * CFrame.new(0, 0, -l / 2))
	end
	p.CFrame = at(0.05)
	p.Parent = fxFolder
	tween(p, grow, { Size = Vector3.new(width, 0.05, len), CFrame = at(len) }, Enum.EasingStyle.Quad)
	return p
end

local function fadeAndDestroy(parts: { BasePart }, after: number, t: number)
	task.delay(after, function()
		for _, p in ipairs(parts) do
			tween(p, t, { Transparency = 1 })
		end
		task.delay(t + 0.05, function()
			for _, p in ipairs(parts) do
				p:Destroy()
			end
		end)
	end)
end

-- Knight Sprint: a cyan L lights in two beats (straight, then the turn), then three short blue streaks
-- run to the open end. Streak = two thin speed ribbons sweeping behind the knight heads and a few
-- angular fragments thrown outside the chassis.
local KNIGHT_BLUE = Color3.fromRGB(60, 130, 255)
Styles.knight = {
	accent = function(st, now)
		if now < st.nextAccent then
			return
		end
		st.nextAccent = now + 1.15
		local d = st.data
		d.flip = -(d.flip or 1)
		local x0 = d.flip * 1.35
		local y = 0.84
		local corner = Vector3.new(x0, y, 0.4)
		local leg1 = beltStrip(st, Vector3.new(x0, y, -3.5), corner, 0.36, 0.2, st.accent)
		local parts = { leg1 }
		task.delay(0.3, function() -- beat two: the turn
			local leg2 = beltStrip(st, corner + Vector3.new(-d.flip * 0.13, 0, 0), Vector3.new(-x0, y, 0.4), 0.36, 0.16, st.accent)
			table.insert(parts, leg2)
			fadeAndDestroy({ leg2 }, 0.4, 0.25)
			task.delay(0.2, function() -- three short streaks to the open end
				for i = 0, 2 do
					task.delay(i * 0.07, function()
						local sx = -x0 + (i - 1) * 0.45
						local s = neonPart(Vector3.new(0.2, 0.05, 1.5), KNIGHT_BLUE, 0)
						s.CFrame = st.root.CFrame * CFrame.new(sx, y + 0.01, 1.0)
						s.Parent = fxFolder
						tween(s, 0.38, { CFrame = st.root.CFrame * CFrame.new(sx, y + 0.01, 4.7), Transparency = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						task.delay(0.4, function()
							s:Destroy()
						end)
					end)
				end
			end)
		end)
		fadeAndDestroy({ leg1 }, 0.7, 0.25)
	end,
	streakStart = function(st, _now)
		local d = st.data
		local m = Instance.new("Model")
		m.Name = st.id .. "_Ribbons"
		local ribbons = {}
		for _, name in ipairs({ "HeadL", "HeadR" }) do
			local segs = {}
			for i = 1, 14 do
				local seg = neonPart(Vector3.new(0.24, 0.2, 0.95), if i <= 3 then Color3.new(0.85, 0.97, 1) else st.accent, 1)
				seg.Parent = m
				segs[i] = seg
			end
			table.insert(ribbons, { att = name, segs = segs, phase = if name == "HeadL" then 0 else math.pi })
		end
		m.Parent = fxFolder
		d.ring = m
		d.ribbons = ribbons
		d.ringT = 0
		d.ringFade = nil
	end,
	streakStep = function(st, now)
		local d = st.data
		if not d.ribbons then
			return
		end
		d.ringT += d.dt or 0
		local t = d.ringT
		local grow = math.clamp(t / 0.3, 0, 1)
		local r = 2.2 + 1.0 * grow
		local fade = 0
		if d.ringFade then
			fade = math.clamp((now - d.ringFade) / 0.5, 0, 1)
		end
		local peak = if t > 0.3 and t < 0.75 then math.sin((t - 0.3) / 0.45 * math.pi) else 0
		r += 0.35 * peak
		for _, rb in ipairs(d.ribbons) do
			local centre = att(st, rb.att)
			local a0 = t * 4.2 + rb.phase
			for i, seg in ipairs(rb.segs) do
				local a = a0 - (i - 1) * 0.2
				local pos = Vector3.new(math.cos(a) * r, math.sin(a * 0.5) * 0.25, math.sin(a) * r)
				local nxt = Vector3.new(math.cos(a + 0.1) * r, math.sin((a + 0.1) * 0.5) * 0.25, math.sin(a + 0.1) * r)
				seg.CFrame = centre * CFrame.Angles(math.rad(18), 0, 0) * CFrame.lookAt(pos, nxt)
				local along = (i - 1) / 13
				seg.Transparency = math.clamp((1 - grow) + along * 0.85 + fade, 0.05 - 0.05 * peak, 1)
			end
		end
		-- angular fragments outside the chassis, one every 0.7 s, at most 6 alive
		if not d.ringFade and now >= st.nextBurst and (d.frags or 0) < 6 then
			st.nextBurst = now + 0.7
			d.side = -(d.side or 1)
			local rail = att(st, if d.side < 0 then "RailL" else "RailR")
			local f = Instance.new("WedgePart")
			f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch, f.CastShadow = true, false, false, false, false
			f.Material = Enum.Material.Glass
			f.Color = Color3.fromRGB(70, 150, 255)
			f.Size = Vector3.new(0.16, 0.75, 0.5)
			local out = st.root.CFrame:VectorToWorldSpace(Vector3.new(d.side, 0, 0))
			local start = rail + out * 1.2 + st.root.CFrame:VectorToWorldSpace(Vector3.new(0, 0, (math.random() - 0.5) * 6))
			f.CFrame = start
			f.Transparency = 0.1
			f.Parent = fxFolder
			d.frags = (d.frags or 0) + 1
			tween(f, 0.8, { CFrame = (start + out * 2.4 + Vector3.new(0, 1.3, 0)) * CFrame.Angles(math.random() * 4, math.random() * 4, 0), Transparency = 1 })
			task.delay(0.82, function()
				f:Destroy()
				d.frags -= 1
			end)
		end
	end,
	streakStop = function(st, now)
		local d = st.data
		if d.ring and not d.ringFade then
			d.ringFade = now
			local m = d.ring
			task.delay(0.55, function()
				m:Destroy()
				if d.ring == m then
					d.ring, d.ribbons, d.ringFade = nil, nil, nil
				end
			end)
		end
	end,
}

-- Bishop Run: two violet light slices travel diagonally across the belt, offset in time, with a small
-- diamond glint where each ends (diagonal, unlike Knight's right-angle L). Streak = one wide diagonal
-- ribbon sweeping outside the rails on a tilted orbit and two faceted diamonds lifting beside the arch.
local BISHOP_GLINT = Color3.fromRGB(240, 210, 255)
local BISHOP_SLICE = Color3.fromRGB(150, 70, 255)
local function bishopGlint(st: Station, pos: Vector3)
	local parts = {}
	for _, rz in ipairs({ 0, 90 }) do
		local bar = neonPart(Vector3.new(0.08, 0.05, 0.08), BISHOP_GLINT, 0)
		bar.CFrame = localCF(st, pos) * CFrame.Angles(0, math.rad(45 + rz), 0)
		bar.Parent = fxFolder
		tween(bar, 0.14, { Size = Vector3.new(0.09, 0.05, 1.1) }, Enum.EasingStyle.Back)
		table.insert(parts, bar)
	end
	local dia = neonPart(Vector3.new(0.05, 0.05, 0.05), st.accent, 0)
	dia.CFrame = localCF(st, pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	dia.Parent = fxFolder
	tween(dia, 0.14, { Size = Vector3.new(0.34, 0.34, 0.34) }, Enum.EasingStyle.Back)
	table.insert(parts, dia)
	fadeAndDestroy(parts, 0.22, 0.3)
end

local function bishopSlice(st: Station, from: Vector3, to: Vector3)
	local dir = (to - from).Unit
	local p = neonPart(Vector3.new(0.42, 0.05, 2.4), BISHOP_SLICE, 0)
	local function at(pos: Vector3)
		return st.root.CFrame * CFrame.lookAt(pos, pos + dir)
	end
	p.CFrame = at(from)
	p.Parent = fxFolder
	tween(p, 0.55, { CFrame = at(to) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.delay(0.55, function()
		bishopGlint(st, to + dir * 0.9)
		tween(p, 0.15, { Transparency = 1 })
		task.delay(0.16, function()
			p:Destroy()
		end)
	end)
end

Styles.bishop = {
	accent = function(st, now)
		if now < st.nextAccent then
			return
		end
		st.nextAccent = now + 1.0
		local y = 0.84
		bishopSlice(st, Vector3.new(-1.7, y, -3.2), Vector3.new(1.1, y, 0.0))
		task.delay(0.3, function()
			bishopSlice(st, Vector3.new(1.7, y, -0.6), Vector3.new(-1.1, y, 2.6))
		end)
	end,
	streakStart = function(st, _now)
		local d = st.data
		local m = Instance.new("Model")
		m.Name = st.id .. "_Ribbon"
		local segs = {}
		for i = 1, 30 do
			local seg = neonPart(Vector3.new(0.9, 0.1, 1.0), if i <= 4 then st.accent else BISHOP_SLICE, 1)
			seg.Parent = m
			segs[i] = seg
		end
		local diamonds = {}
		for _, name in ipairs({ "ArchL", "ArchR" }) do
			local g = Instance.new("Model")
			local shell = neonPart(Vector3.new(0.75, 0.75, 0.75), st.accent, 1)
			shell.Material = Enum.Material.Glass
			shell.Color = Color3.fromRGB(176, 96, 255)
			shell.Parent = g
			local core = neonPart(Vector3.new(0.38, 0.38, 0.38), BISHOP_GLINT, 1)
			core.Parent = g
			g.Parent = m
			table.insert(diamonds, { att = name, shell = shell, core = core, side = if name == "ArchL" then -1 else 1 })
		end
		m.Parent = fxFolder
		d.ring, d.segs, d.diamonds = m, segs, diamonds
		d.ringT, d.ringFade = 0, nil
	end,
	streakStep = function(st, now)
		local d = st.data
		if not d.segs then
			return
		end
		d.ringT += d.dt or 0
		local t = d.ringT
		local grow = math.clamp(t / 0.35, 0, 1)
		local peak = if t > 0.35 and t < 0.85 then math.sin((t - 0.35) / 0.5 * math.pi) else 0
		local fade = if d.ringFade then math.clamp((now - d.ringFade) / 0.55, 0, 1) else 0
		-- the ribbon: a tilted orbit (diagonal across the machine) just outside the rails
		local centre = att(st, "DeckCentre") * CFrame.new(0, 1.9, 0.6) * CFrame.Angles(0, 0, math.rad(17))
		local rx, rz = 6.4 + 0.5 * peak, 9.0 + 0.5 * peak
		local a0 = t * 3.2
		for i, seg in ipairs(d.segs) do
			local a = a0 - (i - 1) * 0.085
			local pos = Vector3.new(math.cos(a) * rx, 0, math.sin(a) * rz)
			local nxt = Vector3.new(math.cos(a + 0.05) * rx, 0, math.sin(a + 0.05) * rz)
			seg.CFrame = centre * CFrame.lookAt(pos, nxt)
			local along = (i - 1) / 29
			seg.Size = Vector3.new(0.9 * (1 - along * 0.65) * (1 + 0.35 * peak), 0.1, 0.95)
			seg.Transparency = math.clamp((1 - grow) + along * 0.75 + fade, 0, 1)
		end
		-- two faceted diamonds lift beside the arch, then hover and turn
		local lift = 1 - (1 - grow) ^ 3
		for _, g in ipairs(d.diamonds) do
			local base = att(st, g.att)
			local bob = math.sin(t * 2.4 + g.side) * 0.15
			local cf = base * CFrame.new(g.side * 0.9 * lift, 2.0 * lift + 0.35 * peak + bob, 0.2) * CFrame.Angles(0, t * 1.8 * g.side, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
			g.shell.CFrame = cf
			g.core.CFrame = cf
			local tr = math.clamp((1 - grow) + fade, 0, 1)
			g.shell.Transparency = math.max(tr, 0.15)
			g.core.Transparency = tr
		end
	end,
	streakStop = function(st, now)
		local d = st.data
		if d.ring and not d.ringFade then
			d.ringFade = now
			local m = d.ring
			task.delay(0.6, function()
				m:Destroy()
				if d.ring == m then
					d.ring, d.segs, d.diamonds, d.ringFade = nil, nil, nil, nil
				end
			end)
		end
	end,
}

-- Rook Rig: red square outlines march down the belt toward the open end. Streak = a glowing square outline
-- on the floor around the whole fortress with small spark bursts at its corners, and ember pixels rising
-- from the tower tops.
local ROOK_RED = Color3.fromRGB(255, 64, 36)
local ROOK_EMBER = Color3.fromRGB(255, 150, 40)
local function squareOutline(parent: Instance, w: number, d: number, bar: number, h: number, color: Color3, t: number): { BasePart }
	local bars = {}
	for _, spec in ipairs({
		{ Vector3.new(w, h, bar), Vector3.new(0, 0, -d / 2) },
		{ Vector3.new(w, h, bar), Vector3.new(0, 0, d / 2) },
		{ Vector3.new(bar, h, d), Vector3.new(-w / 2, 0, 0) },
		{ Vector3.new(bar, h, d), Vector3.new(w / 2, 0, 0) },
	}) do
		local b = neonPart(spec[1], color, t)
		b:SetAttribute("Off", spec[2])
		b.Parent = parent
		table.insert(bars, b)
	end
	return bars
end
local function placeOutline(bars: { BasePart }, cf: CFrame, w: number, d: number, bar: number, h: number)
	local offs = { Vector3.new(0, 0, -d / 2), Vector3.new(0, 0, d / 2), Vector3.new(-w / 2, 0, 0), Vector3.new(w / 2, 0, 0) }
	for i, b in ipairs(bars) do
		b.Size = if i <= 2 then Vector3.new(w + bar, h, bar) else Vector3.new(bar, h, d + bar)
		b.CFrame = cf * CFrame.new(offs[i] + Vector3.new(0, h / 2, 0))
	end
end

Styles.rook = {
	accent = function(st, now)
		if now < st.nextAccent then
			return
		end
		st.nextAccent = now + 0.75
		local m = Instance.new("Model")
		local bars = squareOutline(m, 2.6, 1.7, 0.16, 0.05, ROOK_RED, 0)
		local inner = squareOutline(m, 2.2, 1.3, 0.07, 0.05, ROOK_EMBER, 0.2)
		m.Parent = fxFolder
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - start) / 1.15
			if k >= 1 then
				conn:Disconnect()
				m:Destroy()
				return
			end
			local z = -2.8 + 7.0 * k
			local cf = localCF(st, Vector3.new(0, 0.8, z))
			placeOutline(bars, cf, 2.6, 1.7, 0.16, 0.05)
			placeOutline(inner, cf, 2.2, 1.3, 0.07, 0.06)
			local tr = if k < 0.12 then 1 - k / 0.12 elseif k > 0.7 then (k - 0.7) / 0.3 else 0
			for _, b in ipairs(bars) do
				b.Transparency = tr
			end
			for _, b in ipairs(inner) do
				b.Transparency = math.max(tr, 0.25)
			end
		end)
	end,
	streakStart = function(st, _now)
		local d = st.data
		local m = Instance.new("Model")
		m.Name = st.id .. "_Square"
		d.outer = squareOutline(m, 1, 1, 0.24, 0.12, ROOK_RED, 1)
		d.outerInner = squareOutline(m, 1, 1, 0.1, 0.12, ROOK_EMBER, 1)
		m.Parent = fxFolder
		d.ring, d.ringT, d.ringFade = m, 0, nil
		d.embers = d.embers or 0
	end,
	streakStep = function(st, now)
		local d = st.data
		if not d.outer then
			return
		end
		d.ringT += d.dt or 0
		local t = d.ringT
		local grow = 1 - (1 - math.clamp(t / 0.35, 0, 1)) ^ 3
		local peak = if t > 0.35 and t < 0.8 then math.sin((t - 0.35) / 0.45 * math.pi) else 0
		local fade = if d.ringFade then math.clamp((now - d.ringFade) / 0.55, 0, 1) else 0
		local W, D = 11.4 * (0.7 + 0.3 * grow) + 0.6 * peak, 14.2 * (0.7 + 0.3 * grow) + 0.6 * peak
		local cf = att(st, "OuterRing")
		local h = 0.12 + 0.25 * peak
		placeOutline(d.outer, cf, W, D, 0.24, h)
		placeOutline(d.outerInner, cf, W - 0.7, D - 0.7, 0.1, 0.1)
		local base = 1 - grow + fade
		for _, b in ipairs(d.outer) do
			b.Transparency = math.clamp(base, 0, 1)
		end
		for _, b in ipairs(d.outerInner) do
			b.Transparency = math.clamp(base + 0.35, 0, 1)
		end
		if d.ringFade then
			return
		end
		-- a small spark burst at one corner every 0.8 s (never a flash: short shards that fade)
		if now >= st.nextBurst then
			st.nextBurst = now + 0.8
			d.corner = ((d.corner or 0) % 4) + 1
			local cx = if d.corner == 1 or d.corner == 4 then -W / 2 else W / 2
			local cz = if d.corner <= 2 then -D / 2 else D / 2
			local origin = cf * CFrame.new(cx, 0.15, cz)
			for i = 1, 5 do
				local a = (i / 5) * math.pi * 2 + math.random() * 0.6
				local s = neonPart(Vector3.new(0.08, 0.08, 0.55), ROOK_EMBER, 0)
				local dir = Vector3.new(math.cos(a), 0.6 + math.random() * 0.5, math.sin(a)).Unit
				s.CFrame = CFrame.lookAt(origin.Position, origin.Position + dir)
				s.Parent = fxFolder
				tween(s, 0.35, { CFrame = CFrame.lookAt(origin.Position + dir * 1.3, origin.Position + dir * 2), Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.2) }, Enum.EasingStyle.Quad)
				task.delay(0.37, function()
					s:Destroy()
				end)
			end
		end
		-- ember pixels rising from the tower tops: one every 0.3 s, at most 8 alive
		if now >= (d.nextEmber or 0) and d.embers < 8 then
			d.nextEmber = now + 0.3
			d.side = -(d.side or 1)
			local top = att(st, if d.side < 0 then "TowerL" else "TowerR")
			local e = neonPart(Vector3.new(0.26, 0.26, 0.26), if math.random() < 0.5 then ROOK_RED else ROOK_EMBER, 0)
			local p0 = top.Position + Vector3.new((math.random() - 0.5) * 2.2, 0, (math.random() - 0.5) * 2.2)
			e.CFrame = CFrame.new(p0)
			e.Parent = fxFolder
			d.embers += 1
			local drift = Vector3.new((math.random() - 0.5) * 1.2, 3 + math.random(), (math.random() - 0.5) * 1.2)
			tween(e, 1.4, { CFrame = CFrame.new(p0 + drift), Transparency = 1, Size = Vector3.new(0.14, 0.14, 0.14) }, Enum.EasingStyle.Sine)
			task.delay(1.42, function()
				e:Destroy()
				d.embers -= 1
			end)
		end
	end,
	streakStop = function(st, now)
		local d = st.data
		if d.ring and not d.ringFade then
			d.ringFade = now
			local m = d.ring
			task.delay(0.6, function()
				m:Destroy()
				if d.ring == m then
					d.ring, d.outer, d.outerInner, d.ringFade = nil, nil, nil, nil
				end
			end)
		end
	end,
}

-- Queen Dash: gold four-point stars glide down the belt with two thin gold streaks beside them. Streak = a halo
-- ring turning around the floating crown, a wide halo ring around the whole machine at waist height, and small
-- star sparkles rising beside the rails.
local QUEEN_GOLD = Color3.fromRGB(255, 206, 70)
local QUEEN_WHITE = Color3.fromRGB(255, 244, 200)
local function queenStar(size: number, color: Color3): Model
	local m = Instance.new("Model")
	for _, ry in ipairs({ 0, 90 }) do
		local b = neonPart(Vector3.new(size * 0.14, 0.05, size), color, 0)
		b:SetAttribute("Ry", ry)
		b.Parent = m
	end
	local c = neonPart(Vector3.new(size * 0.3, 0.06, size * 0.3), QUEEN_WHITE, 0)
	c:SetAttribute("Ry", 45)
	c.Parent = m
	return m
end
local function placeStar(m: Model, cf: CFrame, spin: number, upright: boolean?)
	for _, b in ipairs(m:GetChildren()) do
		local ry = math.rad(b:GetAttribute("Ry") :: number)
		if upright then
			b.CFrame = cf * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, ry + spin, 0)
		else
			b.CFrame = cf * CFrame.Angles(0, ry + spin, 0)
		end
	end
end
local function starTransparency(m: Model, t: number)
	for _, b in ipairs(m:GetChildren()) do
		(b :: BasePart).Transparency = t
	end
end
local function segRing(parent: Instance, n: number, size: Vector3, color: Color3): { BasePart }
	local segs = {}
	for i = 1, n do
		local s = neonPart(size, color, 1)
		s.Parent = parent
		segs[i] = s
	end
	return segs
end
local function placeRing(segs: { BasePart }, centre: CFrame, rx: number, rz: number, spin: number, trans: number, gap: number)
	local n = #segs
	for i, s in ipairs(segs) do
		local a = (i / n) * math.pi * 2 + spin
		local pos = Vector3.new(math.cos(a) * rx, 0, math.sin(a) * rz)
		local nxt = Vector3.new(math.cos(a + 0.02) * rx, 0, math.sin(a + 0.02) * rz)
		s.CFrame = centre * CFrame.lookAt(pos, nxt)
		-- a few gaps make the halo read as a turning ring, like the reference
		s.Transparency = if (i % gap) == 0 then 1 else trans
	end
end

Styles.queen = {
	accent = function(st, now)
		if now < st.nextAccent then
			return
		end
		st.nextAccent = now + 0.5
		local star = queenStar(1.1, QUEEN_GOLD)
		star.Parent = fxFolder
		local side = st.data.qside or 1
		st.data.qside = -side
		local streaks = {}
		for _, sx in ipairs({ -1.75, 1.75 }) do
			local s = neonPart(Vector3.new(0.12, 0.05, 1.3), QUEEN_GOLD, 0.15)
			s:SetAttribute("X", sx)
			s.Parent = fxFolder
			table.insert(streaks, s)
		end
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - start) / 0.95
			if k >= 1 then
				conn:Disconnect()
				star:Destroy()
				for _, s in ipairs(streaks) do
					s:Destroy()
				end
				return
			end
			local z = -3.3 + 7.9 * k
			local x = side * 0.5 * math.sin(k * math.pi)
			placeStar(star, localCF(st, Vector3.new(x, 0.86, z)), k * 3)
			local tr = if k < 0.1 then 1 - k / 0.1 elseif k > 0.75 then (k - 0.75) / 0.25 else 0
			starTransparency(star, tr)
			for _, s in ipairs(streaks) do
				local sx = s:GetAttribute("X") :: number
				s.CFrame = localCF(st, Vector3.new(sx + (if sx < 0 then -0.3 else 0.3) * math.sin(k * math.pi), 0.85, z - 0.4))
				s.Transparency = math.max(tr, 0.15)
			end
		end)
	end,
	streakStart = function(st, _now)
		local d = st.data
		local m = Instance.new("Model")
		m.Name = st.id .. "_Halo"
		d.crownRing = segRing(m, 26, Vector3.new(0.16, 0.12, 0.8), QUEEN_GOLD)
		d.bigRing = segRing(m, 40, Vector3.new(0.2, 0.12, 1.1), QUEEN_GOLD)
		m.Parent = fxFolder
		d.ring, d.ringT, d.ringFade = m, 0, nil
		d.sparks = d.sparks or 0
	end,
	streakStep = function(st, now)
		local d = st.data
		if not d.crownRing then
			return
		end
		d.ringT += d.dt or 0
		local t = d.ringT
		local grow = 1 - (1 - math.clamp(t / 0.4, 0, 1)) ^ 3
		local peak = if t > 0.4 and t < 0.9 then math.sin((t - 0.4) / 0.5 * math.pi) else 0
		local fade = if d.ringFade then math.clamp((now - d.ringFade) / 0.55, 0, 1) else 0
		local trans = math.clamp(1 - grow + fade + 0.05 - 0.05 * peak, 0, 1)
		local crown = att(st, "Crown") * CFrame.Angles(math.rad(10), 0, math.rad(-6))
		placeRing(d.crownRing, crown, 2.6 + 0.6 * grow + 0.3 * peak, 2.6 + 0.6 * grow + 0.3 * peak, t * 1.6, trans, 7)
		local waist = att(st, "OuterRing") * CFrame.Angles(math.rad(4), 0, math.rad(5))
		local s = 0.75 + 0.25 * grow
		placeRing(d.bigRing, waist, (6.0 + 0.4 * peak) * s, (8.0 + 0.4 * peak) * s, -t * 0.9, trans, 9)
		if d.ringFade then
			return
		end
		-- small star sparkles rising beside the rails: one every 0.35 s, at most 6 alive
		if now >= st.nextBurst and d.sparks < 6 then
			st.nextBurst = now + 0.35
			d.side = -(d.side or 1)
			local p0 = localCF(st, Vector3.new(d.side * (5.0 + math.random() * 0.8), 1.2, -3 + math.random() * 8))
			local star = queenStar(0.7, QUEEN_GOLD)
			star.Parent = fxFolder
			d.sparks += 1
			local start = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local k = (os.clock() - start) / 1.1
				if k >= 1 then
					conn:Disconnect()
					star:Destroy()
					d.sparks -= 1
					return
				end
				placeStar(star, p0 * CFrame.new(0, 2.8 * (1 - (1 - k) ^ 2), 0), k * 2, true)
				starTransparency(star, if k < 0.15 then 1 - k / 0.15 elseif k > 0.6 then (k - 0.6) / 0.4 else 0)
			end)
		end
	end,
	streakStop = function(st, now)
		local d = st.data
		if d.ring and not d.ringFade then
			d.ringFade = now
			local m = d.ring
			task.delay(0.6, function()
				m:Destroy()
				if d.ring == m then
					d.ring, d.crownRing, d.bigRing, d.ringFade = nil, nil, nil, nil
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
