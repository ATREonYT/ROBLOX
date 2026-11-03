--!strict
-- Street people (client only, nothing replicates). Required by AmbientLife, which calls step() from its one Heartbeat.
-- A fixed pool of rigs cloned from ReplicatedStorage.MTL_AmbientRigs (Services/AmbientRigService builds them from
-- Config/Outfits) is parked out of sight and handed out as people appear, so spawning never builds anything.
--   walkers    follow AmbientMap.Walks (sidewalk lines), turn round at the ends, step aside for the player
--   spot folk  Stoop / Bench sitters, Lean (walls, cars), Corner groups of 2-4 talking with their hands,
--              Vignette seats (domino table, BBQ, the mechanic, the hoop...)
-- They look at you inside 10 studs, 1 in 4 says a line, they put their hands up or run when shots go off nearby and
-- come back 30 s later. Fewer people 1-5 am; after dark they gather near street lights.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rig = require(ReplicatedStorage.MTL.Rig)
local Actors = require(script.Parent.Actors)

local player = Players.LocalPlayer

local AmbientPeople = {}

type Person = {
	actor: Actors.Actor,
	role: string,
	active: boolean,
	mode: string, -- "walk" | "spot" | "flee"
	state: Rig.State,
	pos: Vector3, -- feet on the ground
	fx: number, -- facing (unit, ground plane)
	fz: number,
	-- walking
	path: any?,
	d: number,
	dir: number,
	speed: number,
	side: number, -- lateral offset on the sidewalk
	pauseUntil: number,
	groundAt: number,
	-- spot
	spot: any?,
	group: { Person }?,
	nextGesture: number,
	-- talk
	near: boolean,
	talkedAt: number,
	bubble: BillboardGui?,
	-- scare
	scaredUntil: number,
	lastRender: number,
}

local cfg: any
local R: any
local pool: { Person } = {}
local folder: Folder
local rng = Random.new()
local blockedZones: { { pos: Vector3, untilT: number } } = {}
local groups: { { members: { Person }, spot: any, key: string } } = {}
local groupId = 0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- pool

local PARK = Vector3.new(0, 2000, 0) -- up in the sky, hidden (below FallenPartsDestroyHeight the limbs would be deleted)

local function park(p: Person)
	p.active = false
	p.mode = "parked"
	p.path = nil
	if p.spot then
		p.spot.taken = math.max(0, (p.spot.taken or 1) - 1)
	end
	p.spot = nil
	p.group = nil
	if p.bubble then
		p.bubble:Destroy()
		p.bubble = nil
	end
	for _, t in p.actor.tracks do
		t:Stop(0)
	end
	(p.actor :: any).base = nil
	Actors.setHidden(p.actor, true)
	p.actor.root.CFrame = CFrame.new(PARK + Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50)))
end

-- a rig can show up in MTL_AmbientRigs before all its parts have replicated; only clone it once it is whole
-- (the server stamps the descendant count as "Parts") and has the Humanoid + HumanoidRootPart Actors.adopt needs
local function complete(model: Model): boolean
	local want = model:GetAttribute("Parts")
	if type(want) == "number" and #model:GetDescendants() < want then
		return false
	end
	return model:FindFirstChildOfClass("Humanoid") ~= nil and model:FindFirstChild("HumanoidRootPart") ~= nil
end

local function addRig(model: Model): boolean
	local was = model.Archivable
	model.Archivable = true
	local clone = model:Clone()
	model.Archivable = was
	local actor = Actors.adopt(clone, "Ambient_" .. model.Name, folder)
	if not actor then
		return false
	end
	local p: Person = {
		actor = actor,
		role = (model:GetAttribute("Role") :: string?) or "Street",
		active = false,
		mode = "parked",
		state = { breath = true },
		pos = PARK,
		fx = 0,
		fz = -1,
		d = 0,
		dir = 1,
		speed = 5,
		side = 0,
		pauseUntil = 0,
		groundAt = 0,
		nextGesture = 0,
		near = false,
		talkedAt = -1e9,
		scaredUntil = 0,
		lastRender = 0,
	}
	park(p)
	table.insert(pool, p)
	return true
end

-- clone the server-built rigs once, round-robin over roles so every kind of person is in the pool
-- clone the server-built rigs into the pool as they arrive (the server can take a minute to build them all), keeping
-- the role mix street-heavy: Street counts x3, Crew x2, everyone else x1 when picking who joins next
local poolRoles: { [string]: number } = {}
local used: { [Instance]: boolean } = {}
local function nextRig(lib: Instance): Model?
	local weight = { Street = 3, Crew = 2 }
	local best: Model? = nil
	local bestScore = math.huge
	for _, m in lib:GetChildren() do
		if m:IsA("Model") and not used[m] and complete(m) then
			local role = (m:GetAttribute("Role") :: string?) or "Street"
			local score = (poolRoles[role] or 0) / (weight[role] or 1)
			if score < bestScore then
				best, bestScore = m, score
			end
		end
	end
	return best
end

-- still replicating (gives up on a rig that hasn't finished 15 s after we first saw it)
local firstSeen: { [Instance]: number } = {}
local function arriving(lib: Instance): boolean
	for _, m in lib:GetChildren() do
		if m:IsA("Model") and not used[m] and not complete(m) then
			firstSeen[m] = firstSeen[m] or os.clock()
			if os.clock() - firstSeen[m] < 15 then
				return true
			end
		end
	end
	return false
end

local function prebuild()
	local lib = ReplicatedStorage:WaitForChild("MTL_AmbientRigs") -- no timeout: the server makes it on boot
	local want = cfg.People.Prebuild
	local wake = Instance.new("BindableEvent")
	lib.ChildAdded:Connect(function()
		wake:Fire()
	end)
	while #pool < want do
		local m = nextRig(lib)
		if m then
			used[m] = true
			if addRig(m) then
				local role = (m:GetAttribute("Role") :: string?) or "Street"
				poolRoles[role] = (poolRoles[role] or 0) + 1
			end
			task.wait() -- one rig per frame, never a hitch
		elseif lib:GetAttribute("Ready") and not arriving(lib) then
			break -- the server is done and every rig is in
		else
			-- wait for the next rig (or check again in 2 s)
			task.delay(2, function()
				wake:Fire()
			end)
			wake.Event:Wait()
		end
	end
	wake:Destroy()
	print(("[MTL Ambient] people pool: %d rigs"):format(#pool))
end

local function take(role: string?): Person?
	local any: Person? = nil
	for _, p in pool do
		if not p.active then
			if role == nil or p.role == role then
				return p
			end
			if not any and p.role ~= "Kid" then
				any = p
			end
		end
	end
	return any
end

local function activeCount(): (number, number)
	local n, walkers = 0, 0
	for _, p in pool do
		if p.active then
			n += 1
			if p.mode == "walk" then
				walkers += 1
			end
		end
	end
	return n, walkers
end

---------------------------------------------------------------- placing

local function setFacing(p: Person, fx: number, fz: number)
	local m = math.sqrt(fx * fx + fz * fz)
	if m > 1e-4 then
		p.fx, p.fz = fx / m, fz / m
	end
end

local function rootCF(p: Person): CFrame
	local at = p.pos
	return CFrame.lookAt(at, at + Vector3.new(p.fx, 0, p.fz))
end

local function activate(p: Person, pos: Vector3, mode: string)
	p.active = true
	p.mode = mode
	p.pos = pos
	p.state = { breath = true, poseT0 = -10 }
	p.near = false
	p.scaredUntil = 0
	p.nextGesture = os.clock() + rng:NextNumber(1, 5)
	Actors.setHidden(p.actor, false)
end

local function blocked(pos: Vector3, now: number): boolean
	for _, z in blockedZones do
		if now < z.untilT and (z.pos - pos).Magnitude < cfg.People.ScareRadius then
			return true
		end
	end
	return false
end

local function poseFor(kind: string, spot: any): string
	if spot.pose then
		return spot.pose
	end
	local list = cfg.People.Poses[kind]
	return if list then pick(list) else "None"
end

local function roleFor(kind: string): string?
	local rf = cfg.People.RoleFor
	if rf[kind] then
		return rf[kind]
	end
	return nil
end

local function walkerRole(): string
	local total = 0
	for _, w in cfg.People.WalkerRoles do
		total += w
	end
	local r = rng:NextNumber(0, total)
	for role, w in cfg.People.WalkerRoles do
		r -= w
		if r <= 0 then
			return role
		end
	end
	return "Street"
end

local function spawnWalker(ctx: any): boolean
	local walks = ctx.walks
	if #walks == 0 then
		return false
	end
	for _ = 1, 4 do
		local w = pick(walks)
		local d = rng:NextNumber(0, w.path.total)
		local x, z = R.sample(w.path, d)
		local pos = Vector3.new(x, w.y, z)
		local off = flat(pos - ctx.camPos)
		if off.Magnitude < cfg.People.SpawnRadius and not blocked(pos, ctx.now)
			and R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, cfg.People.MinSpawnDist, cfg.People.BehindDot) then
			local p = take(walkerRole())
			if not p then
				return false
			end
			activate(p, pos, "walk")
			p.path = w.path
			p.d = d
			p.dir = if rng:NextNumber() < 0.5 then 1 else -1
			p.speed = rng:NextNumber(cfg.People.WalkSpeed[1], cfg.People.WalkSpeed[2])
			p.side = rng:NextNumber(-0.9, 0.9)
			p.groundAt = 0
			p.pos = Vector3.new(x, Actors.floor(pos), z)
			return true
		end
	end
	return false
end

local function spotOK(ctx: any, s: any): boolean
	if (s.taken or 0) > 0 then
		return false
	end
	local off = flat(s.pos - ctx.camPos)
	if off.Magnitude > cfg.People.SpawnRadius then
		return false
	end
	if blocked(s.pos, ctx.now) then
		return false
	end
	if ctx.night and s.kind ~= "Stoop" and not s.lit and string.sub(s.kind, 1, 9) ~= "Vignette:" then
		return false -- after dark people hang out under the lights
	end
	return R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, cfg.People.MinSpawnDist, cfg.People.BehindDot)
end

local function placeAtSpot(p: Person, s: any, cf: CFrame, kind: string)
	activate(p, cf.Position, "spot")
	p.spot = s
	s.taken = (s.taken or 0) + 1
	local look = cf.LookVector
	setFacing(p, look.X, look.Z)
	p.state.pose = poseFor(kind, s)
	p.pos = Vector3.new(cf.X, Actors.floor(cf.Position), cf.Z)
	if string.sub(p.state.pose or "", 1, 3) == "Sit" then
		p.pos = Vector3.new(cf.X, cf.Y, cf.Z) -- seats: trust the surveyed height (step / chair top)
	end
end

local function spawnCorner(ctx: any, s: any, free: number): boolean
	local n = R.groupSize(s.n or rng:NextInteger(2, 4), free)
	if n < 2 then
		return false
	end
	local members: { Person } = {}
	for i = 1, n do
		local p = take(if i == 1 then roleFor("Corner") else nil)
		if not p then
			break
		end
		-- a ring ~5 studs across (shoulders never overlap), everyone facing the middle
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local r = 2.6 + rng:NextNumber(-0.1, 0.4)
		local at = s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local cf = CFrame.lookAt(at, Vector3.new(s.pos.X, at.Y, s.pos.Z))
		placeAtSpot(p, s, cf, "Corner")
		table.insert(members, p)
	end
	if #members < 2 then
		for _, p in members do
			park(p)
		end
		return false
	end
	groupId += 1
	local g = { members = members, spot = s, key = "Group" .. groupId }
	for _, p in members do
		p.group = members
	end
	table.insert(groups, g)
	if ctx.sound then
		ctx.sound.emitter(g.key, "Murmur", s.pos + Vector3.new(0, 3, 0))
	end
	return true
end

local function spawnAtSpot(ctx: any, free: number): boolean
	local cands = {}
	for _, s in ctx.peopleSpots do
		if spotOK(ctx, s) then
			table.insert(cands, s)
		end
	end
	if #cands == 0 then
		return false
	end
	local s = pick(cands)
	if s.kind == "Corner" then
		return spawnCorner(ctx, s, free)
	end
	local p = take(roleFor(s.kind))
	if not p then
		return false
	end
	placeAtSpot(p, s, s.cf, s.kind)
	return true
end

---------------------------------------------------------------- talking

local function say(p: Person, text: string)
	if p.bubble then
		p.bubble:Destroy()
	end
	local head = p.actor.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "MTL_Speech"
	b.Size = UDim2.fromOffset(220, 44)
	b.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	b.MaxDistance = 45
	b.LightInfluence = 0
	b.Adornee = head
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, 30)
	frame.BackgroundColor3 = Color3.fromRGB(246, 244, 238)
	frame.BackgroundTransparency = 0.05
	frame.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(28, 28, 32)
	label.Text = text
	label.Parent = frame
	b.Parent = p.actor.model
	p.bubble = b
	local mine = b
	task.delay(cfg.People.BubbleSeconds, function()
		if p.bubble == mine then
			mine:Destroy()
			p.bubble = nil
		end
	end)
end

local function lineFor(ctx: any, p: Person): string
	if p.scaredUntil > ctx.now then
		return pick(cfg.Lines.Scared)
	end
	if p.role == "Elder" and p.spot and p.spot.kind == "Vignette:Domino" then
		return pick(cfg.Lines.Old)
	end
	return pick(cfg.Lines[R.lineSet(ctx.hour)])
end

---------------------------------------------------------------- scare

function AmbientPeople.threat(ctx: any, pos: Vector3)
	table.insert(blockedZones, { pos = pos, untilT = ctx.now + cfg.People.ScareSeconds })
	for _, p in pool do
		if p.active and (p.pos - pos).Magnitude < cfg.People.ScareRadius then
			local first = p.scaredUntil <= ctx.now
			p.scaredUntil = ctx.now + cfg.People.ScareSeconds
			if p.mode == "walk" and p.path then
				-- run off along the sidewalk, away from the noise
				local _, _, dx, dz = R.sample(p.path, p.d)
				local away = flat(p.pos - pos)
				p.dir = if (dx * away.X + dz * away.Z) >= 0 then 1 else -1
				p.mode = "flee"
				p.speed = cfg.People.RunSpeed
				p.pauseUntil = 0
			else
				p.state.prevPose = p.state.pose
				p.state.pose = "HandsUp"
				p.state.poseT0 = ctx.now
			end
			if first and rng:NextNumber() < 0.3 then
				say(p, pick(cfg.Lines.Scared))
			end
		end
	end
end

---------------------------------------------------------------- update

local function updateWalker(ctx: any, p: Person, dt: number)
	local path = p.path
	if not path then
		return
	end
	local speed = p.speed
	-- the player in the way: stop and look
	if ctx.playerPos and p.mode ~= "flee" then
		local to = flat(ctx.playerPos - p.pos)
		local ahead = to.X * p.fx + to.Z * p.fz
		if ahead > 0 and ahead < 3.5 and math.abs(to.X * p.fz - to.Z * p.fx) < 1.6 then
			p.pauseUntil = ctx.now + 0.6
		end
	end
	if ctx.now < p.pauseUntil then
		speed = 0
	end
	p.d += p.dir * speed * dt
	if not path.loop and (p.d <= 0 or p.d >= path.total) then
		p.d = math.clamp(p.d, 0, path.total)
		p.dir = -p.dir
		p.pauseUntil = ctx.now + rng:NextNumber(0.4, 1.6)
	end
	local x, z, dx, dz = R.sample(path, p.d)
	-- side offset: walkers keep to their side, not all on the centre line
	local sx, sz = -dz * p.side, dx * p.side
	local y = p.pos.Y
	if ctx.now - p.groundAt > 0.5 and (ctx.camPos - p.pos).Magnitude < 90 then
		p.groundAt = ctx.now
		y = Actors.floor(Vector3.new(x + sx, y, z + sz), { folder })
	end
	p.pos = Vector3.new(x + sx, y, z + sz)
	setFacing(p, dx * p.dir, dz * p.dir)
	local moving = if speed > 0 then 1 else 0
	p.state.walk = moving
	p.state.walkPhase = (p.state.walkPhase or 0) + speed * dt * 1.6
	if p.mode == "flee" and p.scaredUntil - ctx.now < cfg.People.ScareSeconds - 4 then
		-- ran far enough: gone until things calm down (parked once out of view)
		local off = flat(p.pos - ctx.camPos)
		if R.hiddenSpawn(off.X, off.Z, ctx.camLook.X, ctx.camLook.Z, 60, cfg.People.BehindDot) then
			park(p)
		end
	end
end

local function updateSpot(ctx: any, p: Person)
	-- scare over: hands down
	if p.state.pose == "HandsUp" and p.scaredUntil <= ctx.now then
		p.state.pose = p.state.prevPose or "None"
		p.state.prevPose = "HandsUp"
		p.state.poseT0 = ctx.now
	end
	-- corner groups and vignettes talk with their hands
	if (p.group or (p.spot and string.sub(p.spot.kind, 1, 9) == "Vignette:")) and ctx.now >= p.nextGesture
		and p.state.pose ~= "HandsUp" then
		p.nextGesture = ctx.now + rng:NextNumber(cfg.People.GestureEvery[1], cfg.People.GestureEvery[2])
		local held = p.state.pose
		if held == nil or held == "None" or held == "Cross" or held == "Lean" then
			p.state.gesture = pick(cfg.People.GroupGestures)
		else
			p.state.gesture = if rng:NextNumber() < 0.5 then "Nod" else "Laugh"
		end
		p.state.gestureT0 = ctx.now
		p.state.gestureDur = rng:NextNumber(1.2, 2.2)
		-- the others react
		if p.group then
			for _, o in p.group do
				if o ~= p and rng:NextNumber() < 0.4 then
					o.state.gesture = "Nod"
					o.state.gestureT0 = ctx.now + 0.3
					o.state.gestureDur = 1.2
				end
			end
		end
	end
end

local function updateLook(ctx: any, p: Person)
	if not ctx.playerPos then
		p.state.lookYaw = nil
		return
	end
	local to = flat(ctx.playerPos - p.pos)
	local dist = to.Magnitude
	local inside = dist < cfg.People.LookRadius
	if inside then
		p.state.lookYaw = R.lookYaw(p.fx, p.fz, to.X, to.Z)
		if not p.near then
			p.near = true
			if ctx.now - p.talkedAt > cfg.People.TalkCooldown then
				p.talkedAt = ctx.now
				if rng:NextNumber() < cfg.People.TalkChance then
					say(p, lineFor(ctx, p))
				end
			end
		end
	else
		p.state.lookYaw = nil
		p.near = false
	end
end

local function render(ctx: any, p: Person)
	local cf = rootCF(p)
	Actors.place(p.actor, cf, Rig.drop(p.state))
	Actors.render(p.actor, p.state, ctx.now)
	if p.state.gesture and ctx.now > (p.state.gestureT0 or 0) + (p.state.gestureDur or 1.2) then
		p.state.gesture = nil
	end
	p.lastRender = ctx.now
end

function AmbientPeople.init(ctx: any)
	cfg = ctx.cfg
	R = ctx.R
	folder = Instance.new("Folder")
	folder.Name = "People"
	folder.Parent = ctx.folder
	task.spawn(prebuild)
end

-- every frame. `far` = the 10 Hz tick (spawning, despawning, far people).
function AmbientPeople.step(ctx: any, dt: number, far: boolean)
	if #pool == 0 then
		return
	end
	if far then
		-- tidy blocked zones and groups
		for i = #blockedZones, 1, -1 do
			if blockedZones[i].untilT < ctx.now then
				table.remove(blockedZones, i)
			end
		end
		for i = #groups, 1, -1 do
			local g = groups[i]
			local alive = false
			for _, m in g.members do
				if m.active and m.group == g.members then
					alive = true
				end
			end
			if not alive then
				if ctx.sound then
					ctx.sound.remove(g.key)
				end
				table.remove(groups, i)
			end
		end
		-- despawn far people
		for _, p in pool do
			if p.active and (flat(p.pos - ctx.camPos)).Magnitude > cfg.People.DespawnRadius then
				park(p)
			end
		end
		-- spawn toward the crowd size for this hour (one try per tick keeps it smooth)
		local want = R.crowd(cfg.People.Max, ctx.hour, cfg.People.Crowd)
		local n, walkers = activeCount()
		if n < want and ctx.calm then
			local free = math.min(want - n, #pool - n)
			local wantWalkers = math.floor(want * cfg.People.WalkersShare + 0.5)
			if walkers < wantWalkers and rng:NextNumber() < 0.7 then
				spawnWalker(ctx)
			else
				if not spawnAtSpot(ctx, free) then
					spawnWalker(ctx)
				end
			end
		end
	end
	ctx.peds = ctx.peds or {}
	table.clear(ctx.peds)
	for _, p in pool do
		if p.active then
			local near = (p.pos - ctx.camPos).Magnitude < cfg.NearRadius
			if near or far then
				local step = if near then dt else ctx.now - p.lastRender
				if p.mode == "walk" or p.mode == "flee" then
					updateWalker(ctx, p, math.min(step, 0.25))
				else
					updateSpot(ctx, p)
				end
				if p.active then
					if far then
						updateLook(ctx, p)
					end
					render(ctx, p)
				end
			end
			if p.active then
				table.insert(ctx.peds, p.pos)
			end
		end
	end
end

function AmbientPeople.stats(): (number, number)
	local n = activeCount()
	return n, #pool
end

return AmbientPeople
