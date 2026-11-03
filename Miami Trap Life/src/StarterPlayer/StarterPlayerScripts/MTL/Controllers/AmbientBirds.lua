--!strict
-- Birds (client only). Required by AmbientLife, which calls step() from its one Heartbeat.
--   pigeons   flocks of 5-9 at the nearest AmbientMap "Pigeons" spots: peck-bob, little hops. They scatter up to a
--             wire / roof when you come within 12 studs, sprint or shoot, and drift back 20-40 s later.
--   wires     a row of birds on the nearest power lines ("Wire" spots), shuffling now and then
--   gulls     a few gulls wheeling over the canal ("Gulls" spot)
-- Every bird is 2 parts (gulls 3) from one shared look, at most 60 parts in all, all anchored and moved by CFrame.
local AmbientBirds = {}

type Bird = {
	body: BasePart,
	head: BasePart,
	meshed: boolean?,
	wing: Part?,
	home: Vector3, -- where it pecks
	pos: Vector3,
	yaw: number,
	state: string, -- "ground" | "fly" | "away" | "wire" | "gull"
	t0: number,
	from: Vector3,
	to: Vector3,
	dur: number,
	nextHop: number,
	phase: number,
}

type Flock = { spot: any, birds: { Bird }, scaredUntil: number, roost: Vector3 }

local cfg: any
local R: any
local folder: Folder
local rng = Random.new()
local flocks: { Flock } = {}
local wire: { Bird } = {}
local gulls: { Bird } = {}
local spare: { Bird } = {}
local parts = 0
local wireSpot: any = nil
local lastSprint = false

-- Real pigeon meshes (ReplicatedStorage.MTL_Assets.Birds: Pigeon / Pigeon2 standing, PigeonFly wings out).
-- When they are there a pigeon is 2 mesh parts, the standing bird ("body") and the flying bird ("head" slot),
-- and only one of them shows at a time. Without them the old ball pigeons are used.
local meshes: any = nil
local function birdMeshes(): any
	if meshes == nil then
		local A = game:GetService("ReplicatedStorage"):FindFirstChild("MTL_Assets")
		local B = A and A:FindFirstChild("Birds")
		if B and B:FindFirstChild("Pigeon") and B:FindFirstChild("PigeonFly") then
			meshes = { stand = { B:FindFirstChild("Pigeon"), B:FindFirstChild("Pigeon2") or B:FindFirstChild("Pigeon") }, fly = B:FindFirstChild("PigeonFly") }
		else
			meshes = false
		end
	end
	return meshes
end

local function part(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function newBird(gull: boolean): Bird?
	local need = if gull then 3 else 2
	if parts + need > cfg.Birds.MaxParts then
		return nil
	end
	parts += need
	local color = if gull then cfg.Birds.GullColor else cfg.Birds.Colors[rng:NextInteger(1, #cfg.Birds.Colors)]
	local s = if gull then 1.8 else 1
	local M = if gull then false else birdMeshes()
	local body: BasePart, head: BasePart
	if M then
		body = M.stand[rng:NextInteger(1, #M.stand)]:Clone()
		head = M.fly:Clone()
		local k = rng:NextNumber(0.9, 1.1)
		body.Size *= k
		head.Size *= k * 1.2
		head.Transparency = 1
		body.Parent = folder
		head.Parent = folder
	else
		body = part(Vector3.new(0.55, 0.5, 0.95) * s, color)
		head = part(Vector3.new(0.34, 0.34, 0.34) * s, color:Lerp(Color3.fromRGB(70, 90, 96), if gull then 0 else 0.35), Enum.PartType.Ball)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
	end
	local wing: Part? = nil
	if gull then
		wing = part(Vector3.new(3.4, 0.08, 0.7), color)
	end
	return {
		body = body,
		head = head,
		wing = wing,
		home = Vector3.zero,
		pos = Vector3.new(0, 2000, 0),
		yaw = 0,
		state = "away",
		t0 = 0,
		from = Vector3.zero,
		to = Vector3.zero,
		dur = 1,
		nextHop = 0,
		phase = rng:NextNumber(0, 6.28),
		meshed = if M then true else false,
	}
end

local function getBird(): Bird?
	local b = table.remove(spare)
	return b or newBird(false)
end

local function hide(b: Bird)
	b.state = "away"
	b.pos = Vector3.new(b.pos.X, 2000, b.pos.Z)
	b.body.CFrame = CFrame.new(b.pos)
	b.head.CFrame = CFrame.new(b.pos)
end

-- draws a bird: bob = peck amount (0..1), flap = wing phase
local function draw(b: Bird, bob: number, flying: boolean, now: number)
	if b.meshed then
		local base = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0)
		if flying then
			local flap = math.sin(now * 22 + b.phase)
			b.body.Transparency = 1
			b.head.Transparency = 0
			b.head.CFrame = base * CFrame.new(0, b.head.Size.Y / 2 + 0.06 * flap, 0) * CFrame.Angles(math.rad(-6), 0, math.rad(10 * flap))
		else
			b.body.Transparency = 0
			b.head.Transparency = 1
			-- peck: the whole bird tips forward about its feet
			b.body.CFrame = base * CFrame.Angles(math.rad(-28 * bob), 0, 0) * CFrame.new(0, b.body.Size.Y / 2, 0)
		end
		return
	end
	local base = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0)
	local s = b.body.Size.Z / 0.95
	if flying then
		local flap = math.sin(now * 22 + b.phase)
		b.body.CFrame = base * CFrame.new(0, 0.25 * s, 0) * CFrame.Angles(math.rad(-10), 0, 0)
		b.head.CFrame = base * CFrame.new(0, 0.38 * s, -0.5 * s)
		-- pigeons have no wing part: a flutter of the body reads as flapping from the street
		b.body.CFrame *= CFrame.Angles(0, 0, math.rad(12 * flap))
	else
		b.body.CFrame = base * CFrame.new(0, 0.25 * s, 0) * CFrame.Angles(math.rad(-8 - 20 * bob), 0, 0)
		b.head.CFrame = base * CFrame.new(0, (0.55 - 0.35 * bob) * s, (-0.42 - 0.12 * bob) * s)
	end
end

local function drawGull(b: Bird, now: number)
	local base = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0) * CFrame.Angles(0, 0, math.rad(-18))
	b.body.CFrame = base
	b.head.CFrame = base * CFrame.new(0, 0.2, -1.0)
	if b.wing then
		local flap = math.sin(now * 3 + b.phase) * 0.35
		b.wing.CFrame = base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, flap)
	end
end

local function arc(from: Vector3, to: Vector3, t: number, lift: number): Vector3
	local p = from:Lerp(to, t)
	return p + Vector3.new(0, math.sin(t * math.pi) * lift, 0)
end

---------------------------------------------------------------- flocks

local function releaseFlock(f: Flock)
	for _, b in f.birds do
		hide(b)
		table.insert(spare, b)
	end
	table.clear(f.birds)
end

local function landFlock(ctx: any, f: Flock, fromSky: boolean)
	local n = rng:NextInteger(cfg.Birds.Flock[1], cfg.Birds.Flock[2])
	for _ = 1, n do
		local b = getBird()
		if not b then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.5, 3.2)
		b.home = f.spot.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		b.yaw = rng:NextNumber(0, math.pi * 2)
		b.nextHop = ctx.now + rng:NextNumber(0.5, 4)
		if fromSky then
			b.state = "fly"
			b.from = f.roost + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(0, 3), rng:NextNumber(-4, 4))
			b.to = b.home
			b.t0 = ctx.now + rng:NextNumber(0, 1.2)
			b.dur = rng:NextNumber(1.6, 2.6)
			b.pos = b.from
		else
			b.state = "ground"
			b.pos = b.home
		end
		table.insert(f.birds, b)
	end
end

local function scatter(ctx: any, f: Flock)
	if f.scaredUntil > ctx.now then
		return
	end
	f.scaredUntil = ctx.now + rng:NextNumber(cfg.Birds.ReturnAfter[1], cfg.Birds.ReturnAfter[2])
	for _, b in f.birds do
		if b.state == "ground" then
			b.state = "fly"
			b.from = b.pos
			b.to = f.roost + Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(0, 4), rng:NextNumber(-5, 5))
			b.t0 = ctx.now + rng:NextNumber(0, 0.25)
			b.dur = rng:NextNumber(1.2, 2)
		end
	end
	if ctx.sound then
		ctx.sound.oneShot("Flap", f.spot.pos)
	end
end

-- a roost above the flock: the nearest wire spot, else straight up onto a roof line
local function roostFor(ctx: any, spot: any): Vector3
	local best, bestD = nil, 70
	for _, w in ctx.spotsByKind.Wire or {} do
		local d = (w.pos - spot.pos).Magnitude
		if d < bestD then
			best, bestD = w, d
		end
	end
	if best then
		return best.pos
	end
	return spot.pos + Vector3.new(rng:NextNumber(-10, 10), 26, rng:NextNumber(-10, 10))
end

local function updateFlock(ctx: any, f: Flock, dt: number)
	local now = ctx.now
	if #f.birds == 0 and now >= f.scaredUntil then
		landFlock(ctx, f, f.scaredUntil > 0)
	end
	-- danger: the player close, sprinting nearby, or a fresh threat
	local danger = false
	if ctx.playerPos then
		local d = (ctx.playerPos - f.spot.pos).Magnitude
		danger = d < cfg.Birds.ScareRadius or (ctx.sprinting and d < cfg.Birds.ScareRadius * 2)
	end
	if ctx.lastThreat and now - ctx.lastThreat.t < 0.5 and (ctx.lastThreat.pos - f.spot.pos).Magnitude < 60 then
		danger = true
	end
	if danger then
		scatter(ctx, f)
	end
	local allAway = #f.birds > 0
	for _, b in f.birds do
		if b.state == "ground" then
			allAway = false
			if now >= b.nextHop then
				-- hop to a new peck spot near home
				b.nextHop = now + rng:NextNumber(1.5, 5)
				b.state = "hop"
				b.from = b.pos
				local a = rng:NextNumber(0, math.pi * 2)
				b.to = b.home + Vector3.new(math.cos(a) * rng:NextNumber(0, 1.5), 0, math.sin(a) * rng:NextNumber(0, 1.5))
				b.t0 = now
				b.dur = 0.35
				local dir = b.to - b.from
				if dir.Magnitude > 0.05 then
					b.yaw = math.atan2(-dir.X, -dir.Z)
				end
			end
			local bob = math.max(0, math.sin((now + b.phase) * 5)) ^ 3
			draw(b, bob, false, now)
		elseif b.state == "hop" then
			allAway = false
			local t = math.clamp((now - b.t0) / b.dur, 0, 1)
			b.pos = arc(b.from, b.to, t, 0.35)
			draw(b, 0, false, now)
			if t >= 1 then
				b.state = "ground"
			end
		elseif b.state == "fly" then
			allAway = false
			local t = math.clamp((now - b.t0) / b.dur, 0, 1)
			b.pos = arc(b.from, b.to, t, 4)
			local dir = b.to - b.from
			if dir.Magnitude > 0.1 then
				b.yaw = math.atan2(-dir.X, -dir.Z)
			end
			draw(b, 0, true, now)
			if t >= 1 then
				if (b.to - b.home).Magnitude < 0.5 then
					b.state = "ground"
				else
					hide(b) -- reached the roost: out of the scene until the flock comes back
				end
			end
		end
	end
	if allAway and now < f.scaredUntil then
		releaseFlock(f)
	end
end

---------------------------------------------------------------- wires + gulls

local function fillWire(ctx: any, spot: any)
	for _, b in wire do
		hide(b)
		table.insert(spare, b)
	end
	table.clear(wire)
	wireSpot = spot
	if not spot then
		return
	end
	local dir = spot.cf.LookVector
	for i = 1, cfg.Birds.WireBirds do
		local b = getBird()
		if not b then
			break
		end
		b.state = "wire"
		b.pos = spot.pos + dir * ((i - cfg.Birds.WireBirds / 2) * rng:NextNumber(0.9, 1.6)) + Vector3.new(0, 0.1, 0)
		b.yaw = math.atan2(-dir.Z, dir.X) + (if rng:NextNumber() < 0.5 then 0 else math.pi)
		b.nextHop = ctx.now + rng:NextNumber(2, 10)
		draw(b, 0, false, ctx.now)
		table.insert(wire, b)
	end
end

local function updateWire(ctx: any)
	for _, b in wire do
		if ctx.now >= b.nextHop then
			b.nextHop = ctx.now + rng:NextNumber(3, 12)
			b.yaw += math.pi -- turn round on the wire
			draw(b, 0, false, ctx.now)
		end
	end
end

local function initGulls(ctx: any)
	local spot = (ctx.spotsByKind.Gulls or {})[1]
	if not spot then
		return
	end
	for _ = 1, cfg.Birds.Gulls do
		local g = newBird(true)
		if not g then
			break
		end
		g.state = "gull"
		g.home = spot.pos + Vector3.new(0, cfg.Birds.GullHeight, 0)
		g.dur = rng:NextNumber(18, 30) -- seconds per circle
		g.from = Vector3.new(rng:NextNumber(18, 40), rng:NextNumber(-6, 6), 0) -- radius, height jitter
		table.insert(gulls, g)
	end
end

local function updateGulls(ctx: any)
	for _, g in gulls do
		local a = (ctx.now / g.dur) * math.pi * 2 + g.phase
		local r = g.from.X
		g.pos = g.home + Vector3.new(math.cos(a) * r, g.from.Y + math.sin(a * 2) * 3, math.sin(a) * r)
		g.yaw = -a - math.pi -- tangent to the circle
		drawGull(g, ctx.now)
	end
end

---------------------------------------------------------------- loop

function AmbientBirds.init(ctx: any)
	cfg = ctx.cfg
	R = ctx.R
	folder = Instance.new("Folder")
	folder.Name = "Birds"
	folder.Parent = ctx.folder
	initGulls(ctx)
end

-- the threat hook from AmbientLife (gunshots): every flock in range scatters
function AmbientBirds.threat(ctx: any, pos: Vector3)
	for _, f in flocks do
		if (f.spot.pos - pos).Magnitude < 80 then
			scatter(ctx, f)
		end
	end
end

function AmbientBirds.step(ctx: any, dt: number, far: boolean)
	if far then
		-- keep flocks on the 2 nearest pigeon spots within range
		local spots = ctx.spotsByKind.Pigeons or {}
		local dists = {}
		for i, s in spots do
			local d = (s.pos - ctx.camPos).Magnitude
			dists[i] = if d < cfg.Birds.Radius then d else nil
		end
		local want = {}
		for _, i in R.nearestN(dists, 2, #spots) do
			want[spots[i]] = true
		end
		for i = #flocks, 1, -1 do
			local f = flocks[i]
			if not want[f.spot] then
				releaseFlock(f)
				if ctx.sound then
					ctx.sound.remove("Coo" .. tostring(f.spot.i))
				end
				table.remove(flocks, i)
			else
				want[f.spot] = nil
			end
		end
		for s in want do
			local f: Flock = { spot = s, birds = {}, scaredUntil = 0, roost = roostFor(ctx, s) }
			table.insert(flocks, f)
			-- appear already on the ground only if out of view; else they fly in
			local off = s.pos - ctx.camPos
			local hidden = R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, 90, ctx.cfg.People.BehindDot)
			landFlock(ctx, f, not hidden)
			if ctx.sound then
				ctx.sound.emitter("Coo" .. tostring(s.i), "Coo", s.pos)
			end
		end
		-- the nearest wire
		local wires = ctx.spotsByKind.Wire or {}
		local wd = {}
		for i, s in wires do
			local d = (s.pos - ctx.camPos).Magnitude
			wd[i] = if d < cfg.Birds.Radius then d else nil
		end
		local nearestWire = R.nearestN(wd, 1, #wires)[1]
		local spot = if nearestWire then wires[nearestWire] else nil
		if spot ~= wireSpot then
			local off = if spot then spot.pos - ctx.camPos else Vector3.zero
			if spot == nil or R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, 90, ctx.cfg.People.BehindDot) then
				fillWire(ctx, spot)
			end
		end
		updateWire(ctx)
		updateGulls(ctx)
	end
	lastSprint = ctx.sprinting
	for _, f in flocks do
		if (f.spot.pos - ctx.camPos).Magnitude < ctx.cfg.NearRadius or far then
			updateFlock(ctx, f, dt)
		end
	end
end

function AmbientBirds.stats(): number
	return parts
end

return AmbientBirds
